import 'dart:async';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/shared_preferences_gateway.dart';
import 'package:chimera_gui/theme_preferences.dart';
import 'package:chimera_platform/chimera_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SharedPreferencesPreferenceGateway', () {
    test(
      'GivenApprovedPreferenceKeys_WhenReadAndWritten_ThenExactKeysAreUsed',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'theme': 'dark',
          'language': 'pt-BR',
          'unrelated': 'preserved',
        });
        final gateway = SharedPreferencesPreferenceGateway();

        final read = await gateway.read(PreferenceKey.theme);
        final write = await gateway.write(PreferenceKey.theme, 'light');
        final preferences = await SharedPreferences.getInstance();

        expect(read, isA<ChimeraSuccess<String?>>());
        expect((read as ChimeraSuccess<String?>).value, 'dark');
        expect(write, isA<ChimeraSuccess<void>>());
        expect(preferences.getString('theme'), 'light');
        expect(preferences.getString('language'), 'pt-BR');
        expect(preferences.getString('unrelated'), 'preserved');
      },
    );

    test('GivenUnavailableStorage_WhenReadOrWritten_ThenRedactedAccessFailuresReturn', () async {
      final gateway = SharedPreferencesPreferenceGateway(
        load: () => Future<SharedPreferences>.error(StateError('secret')),
      );

      final read = await gateway.read(PreferenceKey.theme);
      final write = await gateway.write(PreferenceKey.theme, 'dark');

      expect(
        read,
        isA<ChimeraFailure<String?>>()
            .having((failure) => failure.kind, 'kind', FailureKind.access)
            .having((failure) => failure.code, 'code', 'preference_read_failed')
            .having((failure) => failure.details, 'details', isEmpty),
      );
      expect(
        write,
        isA<ChimeraFailure<void>>()
            .having((failure) => failure.kind, 'kind', FailureKind.access)
            .having(
              (failure) => failure.code,
              'code',
              'preference_write_failed',
            )
            .having((failure) => failure.details, 'details', isEmpty),
      );
    });
  });

  group('ThemePreferenceController', () {
    test(
      'GivenMissingOrInvalidPreference_WhenRestored_ThenLightDefaultRemains',
      () async {
        for (final stored in <String?>[null, '', 'system', 'DARK']) {
          final controller = ThemePreferenceController(
            gateway: _FakePreferenceGateway(stored: stored),
          );

          await controller.restore();

          expect(controller.mode, ThemeMode.light);
          expect(controller.status, ThemePreferenceStatus.idle);
          controller.dispose();
        }
      },
    );

    test(
      'GivenCanonicalPreference_WhenRestored_ThenStoredThemeIsApplied',
      () async {
        final dark = ThemePreferenceController(
          gateway: _FakePreferenceGateway(stored: 'dark'),
        );
        final light = ThemePreferenceController(
          gateway: _FakePreferenceGateway(stored: 'light'),
        );

        await dark.restore();
        await light.restore();

        expect(dark.mode, ThemeMode.dark);
        expect(light.mode, ThemeMode.light);
      },
    );

    test(
      'GivenReadFailure_WhenRestored_ThenLightAndUnavailableStatusRemain',
      () async {
        final controller = ThemePreferenceController(
          gateway: _FakePreferenceGateway(readFails: true),
        );

        await controller.restore();

        expect(controller.mode, ThemeMode.light);
        expect(controller.status, ThemePreferenceStatus.notSaved);
      },
    );

    test('GivenSelection_WhenWritePending_ThenThemeAppliesImmediatelyAndSavesCanonicalValue', () async {
      final pending = Completer<ChimeraResult<void>>();
      final gateway = _FakePreferenceGateway(pendingWrite: pending);
      final controller = ThemePreferenceController(gateway: gateway);

      final selection = controller.select(ThemeMode.dark);

      expect(controller.mode, ThemeMode.dark);
      expect(controller.status, ThemePreferenceStatus.saving);
      expect(gateway.writes, <String>['dark']);

      pending.complete(const ChimeraSuccess<void>(null));
      await selection;
      expect(controller.status, ThemePreferenceStatus.saved);
    });

    test('GivenWriteFailure_WhenSelected_ThenSessionThemeRemainsAndNotSavedIsReported', () async {
      final controller = ThemePreferenceController(
        gateway: _FakePreferenceGateway(writeFails: true),
      );

      await controller.select(ThemeMode.dark);

      expect(controller.mode, ThemeMode.dark);
      expect(controller.status, ThemePreferenceStatus.notSaved);
    });

    test(
      'GivenNewerSelection_WhenOlderReadOrWriteCompletes_ThenNewestStateWins',
      () async {
        final read = Completer<ChimeraResult<String?>>();
        final firstWrite = Completer<ChimeraResult<void>>();
        final gateway = _FakePreferenceGateway(
          pendingRead: read,
          pendingWrite: firstWrite,
        );
        final controller = ThemePreferenceController(gateway: gateway);

        final restore = controller.restore();
        final darkSelection = controller.select(ThemeMode.dark);
        gateway.pendingWrite = null;
        final lightSelection = controller.select(ThemeMode.light);
        await lightSelection;
        read.complete(const ChimeraSuccess<String?>('dark'));
        firstWrite.complete(
          const ChimeraFailure<void>(
            kind: FailureKind.access,
            code: 'late_failure',
            messageKey: 'error.preference.access',
          ),
        );
        await restore;
        await darkSelection;

        expect(controller.mode, ThemeMode.light);
        expect(controller.status, ThemePreferenceStatus.saved);
        expect(gateway.writes, <String>['dark', 'light']);
      },
    );

    test('GivenPendingRestore_WhenControllerDisposed_ThenCompletionIsIgnoredSafely', () async {
      final read = Completer<ChimeraResult<String?>>();
      final controller = ThemePreferenceController(
        gateway: _FakePreferenceGateway(pendingRead: read),
      );
      final restore = controller.restore();

      controller.dispose();
      read.complete(const ChimeraSuccess<String?>('dark'));

      await expectLater(restore, completes);
    });
  });
}

final class _FakePreferenceGateway implements PreferenceGateway {
  _FakePreferenceGateway({
    this.stored,
    this.readFails = false,
    this.writeFails = false,
    this.pendingRead,
    this.pendingWrite,
  });

  final String? stored;
  final bool readFails;
  final bool writeFails;
  final Completer<ChimeraResult<String?>>? pendingRead;
  Completer<ChimeraResult<void>>? pendingWrite;
  final List<String> writes = <String>[];

  @override
  Future<ChimeraResult<String?>> read(PreferenceKey key) async {
    expect(key, PreferenceKey.theme);
    if (pendingRead case final pending?) return pending.future;
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
    expect(key, PreferenceKey.theme);
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
