import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_gui/qr_encode_page.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GivenHomeAction_WhenActivated_ThenQrEncodeRouteOpens', (
    tester,
  ) async {
    await tester.pumpWidget(const ChimeraApp());
    final action = find.byKey(const Key('open-qr-encode'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(find.text('Encode QR code'), findsOneWidget);
    expect(find.byKey(const Key('qr-encode-input')), findsOneWidget);
  });

  testWidgets('GivenTextAndOptions_WhenGenerated_ThenExactPngIsPreviewed', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    await tester.enterText(find.byKey(const Key('qr-encode-input')), 'hello');
    await tester.tap(find.byKey(const Key('qr-encode-correction')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High').last);
    await tester.enterText(find.byKey(const Key('qr-encode-size')), '256');
    await tester.enterText(find.byKey(const Key('qr-encode-margin')), '6');
    await tester.enterText(
      find.byKey(const Key('qr-encode-foreground')),
      '#112233',
    );
    await tester.enterText(
      find.byKey(const Key('qr-encode-background')),
      '#F0F0F0',
    );
    await tester.tap(find.byKey(const Key('qr-encode-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('qr-encode-preview')), findsOneWidget);
    final preview = tester.widget<Image>(
      find.byKey(const Key('qr-encode-preview')),
    );
    final bytes = (preview.image as MemoryImage).bytes;
    expect(bytes.take(8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
    expect(find.textContaining('256 x 256'), findsOneWidget);
    expect(find.textContaining('High'), findsWidgets);
    final semantics = tester.widget<Semantics>(
      find.byKey(const Key('qr-encode-result-semantics')),
    );
    expect(semantics.properties.role, SemanticsRole.region);
    expect(semantics.properties.liveRegion, isTrue);
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'QR encode result',
    );
    expect(find.text('hello'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('qr-encode-input')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('GivenGeneratedQr_WhenSaved_ThenExactPreviewBytesAreSaved', (
    tester,
  ) async {
    Uint8List? saved;
    String? fileName;
    await tester.pumpWidget(
      _app(
        fileSaver: (name, bytes, mimeType) async {
          fileName = name;
          saved = Uint8List.fromList(bytes);
          expect(mimeType, 'image/png');
          return true;
        },
      ),
    );

    await tester.enterText(find.byKey(const Key('qr-encode-input')), 'save');
    await tester.tap(find.byKey(const Key('qr-encode-submit')));
    await tester.pumpAndSettle();
    final preview = tester.widget<Image>(
      find.byKey(const Key('qr-encode-preview')),
    );
    final previewBytes = (preview.image as MemoryImage).bytes;
    await tester.ensureVisible(find.byKey(const Key('qr-encode-save')));
    await tester.tap(find.byKey(const Key('qr-encode-save')));
    await tester.pumpAndSettle();

    expect(fileName, 'chimera-qr.png');
    expect(saved, previewBytes);
    expect(find.text('QR PNG saved.'), findsOneWidget);
  });

  testWidgets('GivenFileAndClipboard_WhenLoaded_ThenEachCanGenerate', (
    tester,
  ) async {
    var clipboardReads = 0;
    await tester.pumpWidget(
      _app(
        filePicker: () async => utf8.encode('from file'),
        clipboardReader: () async {
          clipboardReads++;
          return 'from clipboard';
        },
      ),
    );

    await tester.tap(find.byKey(const Key('qr-encode-file')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('qr-encode-input')))
          .controller!
          .text,
      'from file',
    );
    await tester.tap(find.byKey(const Key('qr-encode-paste')));
    await tester.pumpAndSettle();
    expect(clipboardReads, 1);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('qr-encode-input')))
          .controller!
          .text,
      'from clipboard',
    );
  });

  testWidgets('GivenInvalidOptions_WhenGenerated_ThenLocalizedErrorAppears', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.enterText(find.byKey(const Key('qr-encode-input')), 'x');
    await tester.enterText(find.byKey(const Key('qr-encode-size')), '10');
    await tester.tap(find.byKey(const Key('qr-encode-submit')));
    await tester.pumpAndSettle();

    expect(find.text('The QR encoding request is invalid.'), findsOneWidget);
    expect(find.byKey(const Key('qr-encode-preview')), findsNothing);
  });

  testWidgets('GivenSaveFailure_WhenSaving_ThenStaleResultIsCleared', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(fileSaver: (_, _, _) async => throw StateError('private marker')),
    );
    await tester.enterText(find.byKey(const Key('qr-encode-input')), 'x');
    await tester.tap(find.byKey(const Key('qr-encode-submit')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('qr-encode-save')));
    await tester.tap(find.byKey(const Key('qr-encode-save')));
    await tester.pumpAndSettle();

    expect(find.text('The QR PNG could not be saved.'), findsOneWidget);
    expect(find.byKey(const Key('qr-encode-preview')), findsNothing);
    expect(find.textContaining('private marker'), findsNothing);
  });

  testWidgets(
    'GivenClipboardFailure_WhenPasting_ThenSourceClearsAndErrorIsRedacted',
    (tester) async {
      await tester.pumpWidget(
        _app(clipboardReader: () async => throw StateError('private marker')),
      );
      await tester.enterText(
        find.byKey(const Key('qr-encode-input')),
        'existing private text',
      );
      await tester.tap(find.byKey(const Key('qr-encode-paste')));
      await tester.pumpAndSettle();

      expect(
        find.text('The clipboard text could not be read.'),
        findsOneWidget,
      );
      expect(find.textContaining('private marker'), findsNothing);
      expect(find.textContaining('existing private text'), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('qr-encode-input')))
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  testWidgets('GivenGeneratedQr_WhenSourceChanges_ThenResultIsInvalidated', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.enterText(find.byKey(const Key('qr-encode-input')), 'first');
    await tester.tap(find.byKey(const Key('qr-encode-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('qr-encode-preview')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('qr-encode-input')), 'second');
    await tester.pump();
    expect(find.byKey(const Key('qr-encode-preview')), findsNothing);
  });

  testWidgets('GivenPortugueseLocale_WhenOpened_ThenControlsAreLocalized', (
    tester,
  ) async {
    await tester.pumpWidget(_app(localeTag: 'pt-BR'));

    expect(find.text('Codificar código QR'), findsOneWidget);
    expect(find.text('Gerar QR'), findsOneWidget);
    expect(find.text('Carregar arquivo UTF-8'), findsOneWidget);
  });

  for (final locale in <String, String>{
    'English': 'en',
    'BrazilianPortuguese': 'pt-BR',
  }.entries) {
    testWidgets(
      'Given${locale.key}NarrowLargeText_WhenGenerated_ThenControlsRemainAccessible',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(_app(localeTag: locale.value));
        await tester.enterText(
          find.byKey(const Key('qr-encode-input')),
          'accessible',
        );
        await tester.enterText(find.byKey(const Key('qr-encode-size')), '128');
        await tester.ensureVisible(find.byKey(const Key('qr-encode-submit')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('qr-encode-submit')));
        await tester.pumpAndSettle();

        for (final name in <String>['file', 'paste', 'submit', 'save']) {
          final control = find.byKey(Key('qr-encode-$name'));
          await tester.ensureVisible(control);
          final size = tester.getSize(control);
          expect(size.width, greaterThanOrEqualTo(48), reason: name);
          expect(size.height, greaterThanOrEqualTo(48), reason: name);
        }
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      },
    );
  }
}

Widget _app({
  String localeTag = 'en',
  QrEncodeFilePicker? filePicker,
  QrEncodeClipboardReader? clipboardReader,
  QrEncodeFileSaver? fileSaver,
}) => MaterialApp(
  home: QrEncodePage(
    catalog: const MessageCatalog(),
    localeTag: localeTag,
    service: const QrEncodeService(),
    filePicker: filePicker ?? () async => null,
    clipboardReader: clipboardReader ?? () async => null,
    fileSaver: fileSaver ?? (_, _, _) async => true,
  ),
);
