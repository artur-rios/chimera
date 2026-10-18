import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _secret = '0123456789abcdef0123456789abcdef';

final class _Service
    implements OperationService<JwtCreateOperationRequest, JwtCreateOutput> {
  _Service(this.callback);

  final Future<ChimeraResult<JwtCreateOutput>> Function(
    JwtCreateOperationRequest,
  )
  callback;

  @override
  Future<ChimeraResult<JwtCreateOutput>> execute(
    JwtCreateOperationRequest request,
  ) => callback(request);
}

void main() {
  testWidgets('GivenHome_WhenJwtActionTapped_ThenCreateRouteOpens', (
    tester,
  ) async {
    await tester.pumpWidget(const ChimeraApp());
    await tester.ensureVisible(find.byKey(const Key('open-jwt-create')));
    await tester.tap(find.byKey(const Key('open-jwt-create')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('jwt-create-submit')), findsOneWidget);
  });

  testWidgets('GivenValidInputs_WhenCreated_ThenTokenReturnsAndSourcesClear', (
    tester,
  ) async {
    await tester.pumpWidget(const ChimeraApp(initialLocation: '/jwt/create'));
    await tester.enterText(
      find.byKey(const Key('jwt-create-claims')),
      '{"sub":"private-claims-marker"}',
    );
    await tester.enterText(find.byKey(const Key('jwt-create-key')), _secret);
    await tester.ensureVisible(find.byKey(const Key('jwt-create-submit')));
    await tester.tap(find.byKey(const Key('jwt-create-submit')));
    await tester.pumpAndSettle();

    final output = tester.widget<SelectableText>(
      find.byKey(const Key('jwt-create-output')),
    );
    expect(output.data!.split('.'), hasLength(3));
    final semantics = tester.widget<Semantics>(
      find.byKey(const Key('jwt-create-result')),
    );
    expect(semantics.properties.role, SemanticsRole.region);
    expect(semantics.excludeSemantics, isTrue);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('jwt-create-header')))
          .controller!
          .text,
      '{}',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('jwt-create-claims')))
          .controller!
          .text,
      '{}',
    );
    final keyField = tester.widget<TextField>(
      find.byKey(const Key('jwt-create-key')),
    );
    expect(keyField.controller!.text, isEmpty);
    expect(keyField.obscureText, isTrue);
    expect(find.text('private-claims-marker'), findsNothing);
    expect(find.textContaining(_secret), findsNothing);
  });

  testWidgets('GivenToken_WhenCopiedAndSaved_ThenExactPayloadIsHandedOff', (
    tester,
  ) async {
    String? copied;
    String? name;
    String? mime;
    Uint8List? saved;
    await tester.pumpWidget(
      ChimeraApp(
        initialLocation: '/jwt/create',
        localeTag: 'pt-BR',
        jwtCreateClipboardWriter: (value) async => copied = value,
        jwtCreateFileSaver: (fileName, bytes, mimeType) async {
          name = fileName;
          mime = mimeType;
          saved = Uint8List.fromList(bytes);
          return true;
        },
      ),
    );
    await tester.enterText(find.byKey(const Key('jwt-create-key')), _secret);
    await tester.ensureVisible(find.byKey(const Key('jwt-create-submit')));
    await tester.tap(find.byKey(const Key('jwt-create-submit')));
    await tester.pumpAndSettle();
    final token = tester
        .widget<SelectableText>(find.byKey(const Key('jwt-create-output')))
        .data!;

    await tester.ensureVisible(find.byKey(const Key('jwt-create-copy')));
    await tester.tap(find.byKey(const Key('jwt-create-copy')));
    await tester.pumpAndSettle();
    expect(copied, token);
    expect(find.text('JWT copiado.'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('jwt-create-save')));
    await tester.tap(find.byKey(const Key('jwt-create-save')));
    await tester.pumpAndSettle();
    expect(name, 'chimera-jwt.txt');
    expect(mime, 'application/jwt');
    expect(utf8.decode(saved!), token);
    expect(find.text('JWT salvo.'), findsOneWidget);
  });

  testWidgets('GivenFileAndClipboardSources_WhenLoaded_ThenTheyCanSign', (
    tester,
  ) async {
    final loaded = <String>[];
    await tester.pumpWidget(
      ChimeraApp(
        initialLocation: '/jwt/create',
        jwtCreateFilePicker: (field) async {
          loaded.add('file:$field');
          return utf8.encode(field == 'header' ? '{}' : _secret);
        },
        jwtCreateClipboardReader: (field) async {
          loaded.add('paste:$field');
          return field == 'claims' ? '{"source":"clipboard"}' : null;
        },
      ),
    );
    await tester.tap(find.byKey(const Key('jwt-create-header-file')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('jwt-create-claims-paste')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('jwt-create-key-file')));
    await tester.tap(find.byKey(const Key('jwt-create-key-file')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('jwt-create-submit')));
    await tester.tap(find.byKey(const Key('jwt-create-submit')));
    await tester.pumpAndSettle();

    expect(loaded, <String>['file:header', 'paste:claims', 'file:key']);
    expect(find.byKey(const Key('jwt-create-output')), findsOneWidget);
  });

  testWidgets('GivenInvalidKey_WhenCreated_ThenRedactedErrorReturns', (
    tester,
  ) async {
    await tester.pumpWidget(const ChimeraApp(initialLocation: '/jwt/create'));
    await tester.enterText(
      find.byKey(const Key('jwt-create-claims')),
      '{"secret":"private-claims-marker"}',
    );
    await tester.enterText(
      find.byKey(const Key('jwt-create-key')),
      'private-key-marker',
    );
    await tester.ensureVisible(find.byKey(const Key('jwt-create-submit')));
    await tester.tap(find.byKey(const Key('jwt-create-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('jwt-create-error')), findsOneWidget);
    expect(find.byKey(const Key('jwt-create-output')), findsNothing);
    expect(find.textContaining('private-claims-marker'), findsNothing);
    expect(find.textContaining('private-key-marker'), findsNothing);
  });

  testWidgets(
    'GivenCryptographicFailure_WhenCreated_ThenSafeErrorClearsSources',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/jwt/create',
          jwtCreateService: _Service(
            (_) async => const ChimeraFailure<JwtCreateOutput>(
              kind: FailureKind.processing,
              code: 'private-code-marker',
              messageKey: 'private-message-marker',
              details: <String, Object?>{'private': 'details-marker'},
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('jwt-create-claims')),
        '{"private":"claims-marker"}',
      );
      await tester.enterText(find.byKey(const Key('jwt-create-key')), _secret);
      await tester.ensureVisible(find.byKey(const Key('jwt-create-submit')));
      await tester.tap(find.byKey(const Key('jwt-create-submit')));
      await tester.pumpAndSettle();

      expect(find.text('The JWT could not be signed.'), findsOneWidget);
      expect(find.byKey(const Key('jwt-create-output')), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('jwt-create-claims')))
            .controller!
            .text,
        '{}',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('jwt-create-key')))
            .controller!
            .text,
        isEmpty,
      );
      expect(find.textContaining('private-code-marker'), findsNothing);
      expect(find.textContaining('details-marker'), findsNothing);
    },
  );

  for (final boundary in <String>['file', 'clipboard']) {
    testWidgets(
      'Given${boundary}AccessFailure_WhenLoaded_ThenSafeErrorClearsResult',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/jwt/create',
            jwtCreateFilePicker: (_) async => boundary == 'file'
                ? throw StateError('private-file-marker')
                : null,
            jwtCreateClipboardReader: (_) async => boundary == 'clipboard'
                ? throw StateError('private-clipboard-marker')
                : null,
          ),
        );
        await tester.enterText(
          find.byKey(const Key('jwt-create-key')),
          _secret,
        );
        await tester.ensureVisible(find.byKey(const Key('jwt-create-submit')));
        await tester.tap(find.byKey(const Key('jwt-create-submit')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('jwt-create-output')), findsOneWidget);

        final action = boundary == 'file'
            ? 'jwt-create-claims-file'
            : 'jwt-create-claims-paste';
        await tester.ensureVisible(find.byKey(Key(action)));
        await tester.tap(find.byKey(Key(action)));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('jwt-create-error')), findsOneWidget);
        expect(find.byKey(const Key('jwt-create-output')), findsNothing);
        expect(find.textContaining('private-$boundary-marker'), findsNothing);
      },
    );
  }

  for (final boundary in <String>['copy', 'save']) {
    testWidgets(
      'Given${boundary}Failure_WhenTokenExists_ThenSafeErrorClearsResult',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/jwt/create',
            jwtCreateClipboardWriter: (_) async => boundary == 'copy'
                ? throw StateError('private-copy-marker')
                : null,
            jwtCreateFileSaver: (_, _, _) async => boundary == 'save'
                ? throw StateError('private-save-marker')
                : true,
          ),
        );
        await tester.enterText(
          find.byKey(const Key('jwt-create-key')),
          _secret,
        );
        await tester.ensureVisible(find.byKey(const Key('jwt-create-submit')));
        await tester.tap(find.byKey(const Key('jwt-create-submit')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(Key('jwt-create-$boundary')));
        await tester.tap(find.byKey(Key('jwt-create-$boundary')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('jwt-create-error')), findsOneWidget);
        expect(find.byKey(const Key('jwt-create-output')), findsNothing);
        expect(find.textContaining('private-$boundary-marker'), findsNothing);
      },
    );
  }

  testWidgets(
    'GivenCanceledSourceReads_WhenSelected_ThenExistingResultRemains',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/jwt/create',
          jwtCreateFilePicker: (_) async => null,
          jwtCreateClipboardReader: (_) async => null,
        ),
      );
      await tester.enterText(find.byKey(const Key('jwt-create-key')), _secret);
      await tester.ensureVisible(find.byKey(const Key('jwt-create-submit')));
      await tester.tap(find.byKey(const Key('jwt-create-submit')));
      await tester.pumpAndSettle();
      final original = tester
          .widget<SelectableText>(find.byKey(const Key('jwt-create-output')))
          .data;

      for (final action in <String>[
        'jwt-create-claims-file',
        'jwt-create-claims-paste',
      ]) {
        await tester.ensureVisible(find.byKey(Key(action)));
        await tester.tap(find.byKey(Key(action)));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<SelectableText>(
                find.byKey(const Key('jwt-create-output')),
              )
              .data,
          original,
        );
      }
    },
  );

  testWidgets(
    'GivenPendingSigning_WhenPageDisposed_ThenLateCompletionCannotPublish',
    (tester) async {
      final pending = Completer<ChimeraResult<JwtCreateOutput>>();
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/jwt/create',
          jwtCreateService: _Service((_) => pending.future),
        ),
      );
      await tester.enterText(find.byKey(const Key('jwt-create-key')), _secret);
      await tester.ensureVisible(find.byKey(const Key('jwt-create-submit')));
      await tester.tap(find.byKey(const Key('jwt-create-submit')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      pending.complete(
        const ChimeraSuccess<JwtCreateOutput>(
          JwtCreateOutput(token: 'late.private.token'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('late.private.token'), findsNothing);
    },
  );
}
