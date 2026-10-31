import 'dart:async';
import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/language_preferences.dart';
import 'package:chimera_platform/chimera_platform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'GivenFallbackEvent_WhenDefaultSinkEmits_ThenStructuredDiagnosticIsLogged',
    () {
      final messages = <String>[];
      final previousDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) messages.add(message);
      };
      addTearDown(() => debugPrint = previousDebugPrint);
      final event = DiagnosticEvent.create(
        timestamp: DateTime.utc(2026, 10, 21),
        severity: DiagnosticSeverity.warning,
        component: DiagnosticComponent.gui,
        code: DiagnosticCode.localizationFallback,
        context: const <String, Object?>{
          'status': DiagnosticStatus.failed,
          'target': DiagnosticTarget.gui,
        },
      );

      const FlutterDiagnosticSink().emit(event);

      expect(jsonDecode(messages.single), <String, Object?>{
        'timestamp': '2026-10-21T00:00:00.000Z',
        'severity': 'warning',
        'component': 'gui',
        'code': 'localizationFallback',
        'context': <String, Object?>{'status': 'failed', 'target': 'gui'},
      });
    },
  );

  group('LanguagePreferenceController', () {
    test(
      'GivenMissingPreference_WhenRestored_ThenConfiguredEnglishDefaultRemains',
      () async {
        final controller = LanguagePreferenceController(
          _FakePreferenceGateway(),
        );

        await controller.restore();

        expect(controller.localeTag, 'en');
        expect(controller.status, LanguagePreferenceStatus.idle);
      },
    );

    test(
      'GivenCanonicalPreference_WhenRestored_ThenStoredLanguageIsApplied',
      () async {
        for (final locale in <String>['en', 'pt-BR']) {
          final controller = LanguagePreferenceController(
            _FakePreferenceGateway(stored: locale),
          );

          await controller.restore();

          expect(controller.localeTag, locale);
          expect(controller.status, LanguagePreferenceStatus.idle);
          controller.dispose();
        }
      },
    );

    test(
      'GivenInvalidStoredLanguage_WhenRestored_ThenEnglishAndDiagnosticAreUsed',
      () async {
        final diagnostics = _RecordingDiagnosticSink();
        final controller = LanguagePreferenceController(
          _FakePreferenceGateway(stored: 'fr'),
          diagnosticSink: diagnostics,
        );

        await controller.restore();

        expect(controller.localeTag, 'en');
        expect(diagnostics.events, hasLength(1));
        expect(diagnostics.events.single.code, 'localizationFallback');
        expect(diagnostics.events.single.context, <String, Object?>{
          'status': 'failed',
          'target': 'gui',
        });
      },
    );

    test('GivenIncompletePortugueseCatalog_WhenRestored_ThenEnglishAndDiagnosticAreUsed', () async {
      final diagnostics = _RecordingDiagnosticSink();
      final controller = LanguagePreferenceController(
        _FakePreferenceGateway(stored: 'pt-BR'),
        catalogIsComplete: (locale) => locale == 'en',
        diagnosticSink: diagnostics,
      );

      await controller.restore();

      expect(controller.localeTag, 'en');
      expect(diagnostics.events.single.code, 'localizationFallback');
    });

    test(
      'GivenReadFailure_WhenRestored_ThenEnglishAndUnavailableStatusRemain',
      () async {
        final controller = LanguagePreferenceController(
          _FakePreferenceGateway(readFails: true),
        );

        await controller.restore();

        expect(controller.localeTag, 'en');
        expect(controller.status, LanguagePreferenceStatus.notSaved);
      },
    );

    test('GivenSelection_WhenWritePending_ThenLanguageAppliesImmediatelyAndSavesCanonicalValue', () async {
      final pending = Completer<ChimeraResult<void>>();
      final gateway = _FakePreferenceGateway(pendingWrite: pending);
      final controller = LanguagePreferenceController(gateway);

      final selection = controller.select('pt-BR');

      expect(controller.localeTag, 'pt-BR');
      expect(controller.status, LanguagePreferenceStatus.saving);
      await Future<void>.delayed(Duration.zero);
      expect(gateway.writes, <String>['pt-BR']);

      pending.complete(const ChimeraSuccess<void>(null));
      await selection;
      expect(controller.status, LanguagePreferenceStatus.saved);
    });

    test('GivenWriteFailure_WhenSelected_ThenSessionLanguageRemainsAndNotSavedIsReported', () async {
      final controller = LanguagePreferenceController(
        _FakePreferenceGateway(writeFails: true),
      );

      await controller.select('pt-BR');

      expect(controller.localeTag, 'pt-BR');
      expect(controller.status, LanguagePreferenceStatus.notSaved);
    });

    test(
      'GivenRapidSelections_WhenOlderWriteCompletes_ThenLatestValuePersists',
      () async {
        final gateway = _OutOfOrderPreferenceGateway();
        final controller = LanguagePreferenceController(gateway);

        final portuguese = controller.select('pt-BR');
        final english = controller.select('en');
        await Future<void>.delayed(Duration.zero);
        gateway.firstWrite.complete();
        await Future.wait(<Future<void>>[portuguese, english]);

        expect(gateway.writes, <String>['pt-BR', 'en']);
        expect(gateway.stored, 'en');
        expect(controller.localeTag, 'en');
        expect(controller.status, LanguagePreferenceStatus.saved);
      },
    );

    test('GivenUnsupportedSelection_WhenSelected_ThenArgumentErrorIsThrownWithoutWrite', () async {
      final gateway = _FakePreferenceGateway();
      final controller = LanguagePreferenceController(gateway);

      await expectLater(controller.select('es'), throwsArgumentError);

      expect(controller.localeTag, 'en');
      expect(gateway.writes, isEmpty);
    });
  });
}

final class _RecordingDiagnosticSink implements DiagnosticSink {
  final List<DiagnosticEvent> events = <DiagnosticEvent>[];

  @override
  void emit(DiagnosticEvent event) => events.add(event);
}

final class _OutOfOrderPreferenceGateway implements PreferenceGateway {
  final Completer<void> firstWrite = Completer<void>();
  final List<String> writes = <String>[];
  String? stored;

  @override
  Future<ChimeraResult<String?>> read(PreferenceKey key) async =>
      ChimeraSuccess<String?>(stored);

  @override
  Future<ChimeraResult<void>> write(PreferenceKey key, String value) async {
    expect(key, PreferenceKey.language);
    writes.add(value);
    if (writes.length == 1) await firstWrite.future;
    stored = value;
    return const ChimeraSuccess<void>(null);
  }
}

final class _FakePreferenceGateway implements PreferenceGateway {
  _FakePreferenceGateway({
    this.stored,
    this.readFails = false,
    this.writeFails = false,
    this.pendingWrite,
  });

  final String? stored;
  final bool readFails;
  final bool writeFails;
  final Completer<ChimeraResult<void>>? pendingWrite;
  final List<String> writes = <String>[];

  @override
  Future<ChimeraResult<String?>> read(PreferenceKey key) async {
    expect(key, PreferenceKey.language);
    if (readFails) {
      return const ChimeraFailure<String?>(
        kind: FailureKind.access,
        code: 'read_failed',
        messageKey: 'error.preference.access',
      );
    }
    return ChimeraSuccess<String?>(stored);
  }

  @override
  Future<ChimeraResult<void>> write(PreferenceKey key, String value) async {
    expect(key, PreferenceKey.language);
    writes.add(value);
    if (pendingWrite case final pending?) return pending.future;
    if (writeFails) {
      return const ChimeraFailure<void>(
        kind: FailureKind.access,
        code: 'write_failed',
        messageKey: 'error.preference.access',
      );
    }
    return const ChimeraSuccess<void>(null);
  }
}
