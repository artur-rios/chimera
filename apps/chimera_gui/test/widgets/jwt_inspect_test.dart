import 'dart:async';
import 'dart:convert';
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Service
    implements OperationService<JwtInspectOperationRequest, JwtInspectOutput> {
  _Service(this.callback);

  final Future<ChimeraResult<JwtInspectOutput>> Function(
    JwtInspectOperationRequest,
  )
  callback;

  @override
  Future<ChimeraResult<JwtInspectOutput>> execute(
    JwtInspectOperationRequest request,
  ) => callback(request);
}

JwtInspectOutput _output([
  JwtVerificationStatus status = JwtVerificationStatus.verified,
]) => JwtInspectOutput(
  header: const <String, Object?>{'alg': 'HS256'},
  claims: const <String, Object?>{'sub': 'alice'},
  verification: status,
);

void main() {
  testWidgets('GivenHome_WhenJwtInspectActionTapped_ThenRouteOpens', (
    tester,
  ) async {
    await tester.pumpWidget(const ChimeraApp());
    await tester.ensureVisible(find.byKey(const Key('open-jwt-inspect')));
    await tester.tap(find.byKey(const Key('open-jwt-inspect')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('jwt-inspect-submit')), findsOneWidget);
  });

  testWidgets(
    'GivenTokenAndKey_WhenInspected_ThenSourcesClearAndResultIsAccessible',
    (tester) async {
      JwtInspectOperationRequest? received;
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/jwt/inspect',
          jwtInspectService: _Service((request) async {
            received = request;
            return ChimeraSuccess<JwtInspectOutput>(_output());
          }),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('jwt-inspect-token')),
        'private.token.marker',
      );
      await tester.enterText(
        find.byKey(const Key('jwt-inspect-key')),
        'private-key-marker',
      );
      await tester.tap(find.byKey(const Key('jwt-inspect-submit')));
      await tester.pumpAndSettle();

      expect(received, isNotNull);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('jwt-inspect-token')))
            .controller!
            .text,
        isEmpty,
      );
      final key = tester.widget<TextField>(
        find.byKey(const Key('jwt-inspect-key')),
      );
      expect(key.controller!.text, isEmpty);
      expect(key.obscureText, isTrue);
      expect(find.textContaining('private.token.marker'), findsNothing);
      expect(find.textContaining('private-key-marker'), findsNothing);
      final semantics = tester.widget<Semantics>(
        find.byKey(const Key('jwt-inspect-result')),
      );
      expect(semantics.properties.role, SemanticsRole.region);
      expect(semantics.properties.liveRegion, isTrue);
      expect(find.textContaining('"sub":"alice"'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenSignatureMismatch_WhenInspected_ThenDecodedDataIsExplicitlyUntrusted',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/jwt/inspect',
          jwtInspectService: _Service(
            (_) async => ChimeraSuccess<JwtInspectOutput>(
              _output(JwtVerificationStatus.failed),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('jwt-inspect-token')),
        'mismatch.token.value',
      );
      await tester.tap(find.byKey(const Key('jwt-inspect-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('jwt-inspect-output')), findsOneWidget);
      expect(find.text('Failed — decoded data is untrusted'), findsOneWidget);
      expect(find.byKey(const Key('jwt-inspect-untrusted')), findsOneWidget);
    },
  );

  testWidgets('GivenFileAndClipboardSources_WhenLoaded_ThenTheyCanInspect', (
    tester,
  ) async {
    final loaded = <String>[];
    await tester.pumpWidget(
      ChimeraApp(
        initialLocation: '/jwt/inspect',
        jwtInspectService: _Service(
          (_) async => ChimeraSuccess<JwtInspectOutput>(_output()),
        ),
        jwtInspectFilePicker: (field) async {
          loaded.add('file:$field');
          return utf8.encode(
            field == 'token' ? 'file.token.value' : 'file-key-value',
          );
        },
        jwtInspectClipboardReader: (field) async {
          loaded.add('paste:$field');
          return field == 'token' ? 'clipboard.token.value' : null;
        },
      ),
    );
    await tester.tap(find.byKey(const Key('jwt-inspect-token-file')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('jwt-inspect-token-paste')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('jwt-inspect-key-file')));
    await tester.tap(find.byKey(const Key('jwt-inspect-key-file')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('jwt-inspect-submit')));
    await tester.pumpAndSettle();

    expect(loaded, <String>['file:token', 'paste:token', 'file:key']);
    expect(find.byKey(const Key('jwt-inspect-output')), findsOneWidget);
  });

  testWidgets('GivenResult_WhenCopied_ThenStableJsonIsHandedOff', (
    tester,
  ) async {
    String? copied;
    await tester.pumpWidget(
      ChimeraApp(
        initialLocation: '/jwt/inspect',
        localeTag: 'pt-BR',
        jwtInspectService: _Service(
          (_) async => ChimeraSuccess<JwtInspectOutput>(_output()),
        ),
        jwtInspectClipboardWriter: (value) async => copied = value,
      ),
    );
    await tester.enterText(
      find.byKey(const Key('jwt-inspect-token')),
      'copy.token.value',
    );
    await tester.tap(find.byKey(const Key('jwt-inspect-submit')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('jwt-inspect-copy')));
    await tester.tap(find.byKey(const Key('jwt-inspect-copy')));
    await tester.pumpAndSettle();

    expect(
      copied,
      '{"header":{"alg":"HS256"},"claims":{"sub":"alice"},'
      '"verification":"verified"}',
    );
    expect(find.text('Resultado da inspeção copiado.'), findsOneWidget);
  });

  testWidgets(
    'GivenBoundaryFailure_WhenTriggered_ThenSafeErrorClearsSensitiveState',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/jwt/inspect',
          jwtInspectService: _Service(
            (_) async => const ChimeraFailure<JwtInspectOutput>(
              kind: FailureKind.processing,
              code: 'private-code-marker',
              messageKey: 'private-message-marker',
              details: <String, Object?>{'private': 'details-marker'},
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('jwt-inspect-token')),
        'private-token-marker',
      );
      await tester.enterText(
        find.byKey(const Key('jwt-inspect-key')),
        'private-key-marker',
      );
      await tester.tap(find.byKey(const Key('jwt-inspect-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('The JWT signature could not be verified.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('jwt-inspect-output')), findsNothing);
      expect(find.textContaining('private-code-marker'), findsNothing);
      expect(find.textContaining('details-marker'), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('jwt-inspect-token')))
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  for (final boundary in <String, String>{
    'File': 'file',
    'Clipboard': 'clipboard',
  }.entries) {
    testWidgets(
      'Given${boundary.key}AccessFailure_WhenLoaded_ThenSafeErrorClearsResult',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/jwt/inspect',
            jwtInspectService: _Service(
              (_) async => ChimeraSuccess<JwtInspectOutput>(_output()),
            ),
            jwtInspectFilePicker: (_) async => boundary.value == 'file'
                ? throw StateError('private-file-marker')
                : null,
            jwtInspectClipboardReader: (_) async =>
                boundary.value == 'clipboard'
                ? throw StateError('private-clipboard-marker')
                : null,
          ),
        );
        await tester.enterText(
          find.byKey(const Key('jwt-inspect-token')),
          'valid.token.value',
        );
        await tester.tap(find.byKey(const Key('jwt-inspect-submit')));
        await tester.pumpAndSettle();
        final action = boundary.value == 'file'
            ? 'jwt-inspect-token-file'
            : 'jwt-inspect-token-paste';
        await tester.ensureVisible(find.byKey(Key(action)));
        await tester.tap(find.byKey(Key(action)));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('jwt-inspect-error')), findsOneWidget);
        expect(find.byKey(const Key('jwt-inspect-output')), findsNothing);
        expect(
          find.textContaining('private-${boundary.value}-marker'),
          findsNothing,
        );
      },
    );
  }

  testWidgets('GivenCopyFailure_WhenResultExists_ThenSafeErrorClearsResult', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChimeraApp(
        initialLocation: '/jwt/inspect',
        jwtInspectService: _Service(
          (_) async => ChimeraSuccess<JwtInspectOutput>(_output()),
        ),
        jwtInspectClipboardWriter: (_) async =>
            throw StateError('private-copy-marker'),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('jwt-inspect-token')),
      'valid.token.value',
    );
    await tester.tap(find.byKey(const Key('jwt-inspect-submit')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('jwt-inspect-copy')));
    await tester.tap(find.byKey(const Key('jwt-inspect-copy')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('jwt-inspect-error')), findsOneWidget);
    expect(find.byKey(const Key('jwt-inspect-output')), findsNothing);
    expect(find.textContaining('private-copy-marker'), findsNothing);
  });

  testWidgets(
    'GivenCanceledSourceReads_WhenSelected_ThenExistingResultRemains',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/jwt/inspect',
          jwtInspectService: _Service(
            (_) async => ChimeraSuccess<JwtInspectOutput>(_output()),
          ),
          jwtInspectFilePicker: (_) async => null,
          jwtInspectClipboardReader: (_) async => null,
        ),
      );
      await tester.enterText(
        find.byKey(const Key('jwt-inspect-token')),
        'valid.token.value',
      );
      await tester.tap(find.byKey(const Key('jwt-inspect-submit')));
      await tester.pumpAndSettle();

      for (final action in <String>[
        'jwt-inspect-token-file',
        'jwt-inspect-token-paste',
      ]) {
        await tester.ensureVisible(find.byKey(Key(action)));
        await tester.tap(find.byKey(Key(action)));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('jwt-inspect-output')), findsOneWidget);
      }
    },
  );

  testWidgets('GivenExistingResult_WhenSourceChanges_ThenResultIsDiscarded', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChimeraApp(
        initialLocation: '/jwt/inspect',
        jwtInspectService: _Service(
          (_) async => ChimeraSuccess<JwtInspectOutput>(_output()),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('jwt-inspect-token')),
      'valid.token.value',
    );
    await tester.tap(find.byKey(const Key('jwt-inspect-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('jwt-inspect-output')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('jwt-inspect-token')),
      'changed.token.value',
    );
    await tester.pump();
    expect(find.byKey(const Key('jwt-inspect-output')), findsNothing);
  });

  for (final locale in <String, String>{
    'English': 'en',
    'BrazilianPortuguese': 'pt-BR',
  }.entries) {
    testWidgets(
      'Given${locale.key}NarrowLargeText_WhenInspected_ThenControlsRemainAccessible',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/jwt/inspect',
            localeTag: locale.value,
            jwtInspectService: _Service(
              (_) async => ChimeraSuccess<JwtInspectOutput>(_output()),
            ),
            jwtInspectClipboardWriter: (_) async {},
          ),
        );
        await tester.enterText(
          find.byKey(const Key('jwt-inspect-token')),
          'valid.token.value',
        );
        await tester.ensureVisible(find.byKey(const Key('jwt-inspect-submit')));
        await tester.tap(find.byKey(const Key('jwt-inspect-submit')));
        await tester.pumpAndSettle();

        for (final name in <String>[
          'token-file',
          'token-paste',
          'key-file',
          'key-paste',
          'submit',
          'copy',
        ]) {
          final control = find.byKey(Key('jwt-inspect-$name'));
          await tester.ensureVisible(control);
          final size = tester.getSize(control);
          expect(size.width, greaterThanOrEqualTo(48), reason: name);
          expect(size.height, greaterThanOrEqualTo(48), reason: name);
        }
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      },
    );
  }

  testWidgets(
    'GivenPendingInspection_WhenPageDisposed_ThenLateCompletionCannotPublish',
    (tester) async {
      final pending = Completer<ChimeraResult<JwtInspectOutput>>();
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/jwt/inspect',
          jwtInspectService: _Service((_) => pending.future),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('jwt-inspect-token')),
        'late.token.value',
      );
      await tester.tap(find.byKey(const Key('jwt-inspect-submit')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      pending.complete(ChimeraSuccess<JwtInspectOutput>(_output()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('alice'), findsNothing);
    },
  );
}
