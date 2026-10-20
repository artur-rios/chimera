import 'dart:convert';
import 'dart:typed_data';

import 'package:chimera_gui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpCipher(
    WidgetTester tester, {
    String locale = 'en',
    Future<List<int>?> Function()? filePicker,
    Future<String?> Function()? clipboardReader,
    Future<void> Function(String)? clipboardWriter,
    Future<bool> Function(String, Uint8List, String)? fileSaver,
  }) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChimeraApp(
        key: ValueKey(locale),
        initialLocation: '/cipher/encode',
        localeTag: locale,
        cipherEncodeFilePicker: filePicker,
        cipherEncodeClipboardReader: clipboardReader,
        cipherEncodeClipboardWriter: clipboardWriter,
        cipherEncodeFileSaver: fileSaver,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String key, String label) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'GivenBothLocales_WhenCipherRouteOpens_ThenLocalizedControlsRender',
    (tester) async {
      for (final locale in ['en', 'pt-BR']) {
        await pumpCipher(tester, locale: locale);
        expect(
          find.text(
            locale == 'en' ? 'Encode with Cipher' : 'Codificar com cifra',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('cipher-encode-input')), findsOneWidget);
        expect(find.byKey(const Key('cipher-encode-cipher')), findsOneWidget);
        expect(find.byKey(const Key('cipher-encode-policy')), findsOneWidget);
      }
    },
  );

  testWidgets(
    'GivenText_WhenAtbashEncodedCopiedAndSaved_ThenExactResultTransfers',
    (tester) async {
      String? copied;
      List<int>? saved;
      await pumpCipher(
        tester,
        clipboardWriter: (value) async => copied = value,
        fileSaver: (_, bytes, _) async {
          saved = bytes;
          return true;
        },
      );
      await tester.enterText(
        find.byKey(const Key('cipher-encode-input')),
        'Abc!',
      );
      await select(tester, 'cipher-encode-cipher', 'Atbash');
      await tester.tap(find.byKey(const Key('cipher-encode-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Zyx!'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cipher-encode-copy')));
      await tester.pumpAndSettle();
      expect(copied, 'Zyx!');
      await tester.tap(find.byKey(const Key('cipher-encode-save')));
      await tester.pumpAndSettle();
      expect(utf8.decode(saved!), 'Zyx!');
      expect(find.text('Cipher encoded text saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenCipherSelection_WhenChanged_ThenOnlyMatchingParametersRender',
    (tester) async {
      await pumpCipher(tester);

      expect(find.byKey(const Key('cipher-encode-shift')), findsOneWidget);
      await select(tester, 'cipher-encode-cipher', 'Vigenere');
      expect(find.byKey(const Key('cipher-encode-key')), findsOneWidget);
      expect(find.byKey(const Key('cipher-encode-shift')), findsNothing);
      await select(tester, 'cipher-encode-cipher', 'Affine');
      expect(find.byKey(const Key('cipher-encode-a')), findsOneWidget);
      expect(find.byKey(const Key('cipher-encode-b')), findsOneWidget);
      await select(tester, 'cipher-encode-cipher', 'Rail Fence');
      expect(find.byKey(const Key('cipher-encode-rails')), findsOneWidget);
    },
  );

  testWidgets(
    'GivenFileWithRejectedSymbol_WhenEncoded_ThenLocalizedSafeErrorReturns',
    (tester) async {
      await pumpCipher(tester, filePicker: () async => utf8.encode('A🌍B'));
      await tester.tap(find.byKey(const Key('cipher-encode-file')));
      await tester.pumpAndSettle();
      await select(tester, 'cipher-encode-cipher', 'Atbash');
      await select(
        tester,
        'cipher-encode-policy',
        'Reject unsupported symbols',
      );
      await tester.tap(find.byKey(const Key('cipher-encode-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('The cipher encoding request is invalid.'),
        findsOneWidget,
      );
      expect(find.textContaining('🌍'), findsNothing);
      expect(find.byKey(const Key('cipher-encode-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenFileAndParameter_WhenCaesarEncoded_ThenFileSourceIsRetained',
    (tester) async {
      await pumpCipher(tester, filePicker: () async => utf8.encode('Abc'));
      await tester.tap(find.byKey(const Key('cipher-encode-file')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cipher-encode-shift')), '1');
      await tester.tap(find.byKey(const Key('cipher-encode-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Bcd'), findsOneWidget);
    },
  );
}
