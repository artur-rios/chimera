import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show SemanticsRole;

import 'package:chimera_gui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _secret = '0123456789abcdef0123456789abcdef';

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
}
