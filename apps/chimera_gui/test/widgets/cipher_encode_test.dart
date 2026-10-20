import 'dart:convert';

import 'package:chimera_gui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets(
    'GivenClipboardText_WhenPastedAndEncoded_ThenExactResultReturns',
    (tester) async {
      await pumpCipher(tester, clipboardReader: () async => 'Abc!');
      await tester.tap(find.byKey(const Key('cipher-encode-paste')));
      await tester.pumpAndSettle();
      await select(tester, 'cipher-encode-cipher', 'Atbash');
      await tester.tap(find.byKey(const Key('cipher-encode-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Zyx!'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenInvalidVigenereKey_WhenEncoded_ThenFailureIsRedactedAndStateCleared',
    (tester) async {
      await pumpCipher(tester);
      await tester.enterText(
        find.byKey(const Key('cipher-encode-input')),
        'Attack',
      );
      await select(tester, 'cipher-encode-cipher', 'Vigenere');
      await tester.enterText(find.byKey(const Key('cipher-encode-key')), 'K3Y');
      await tester.tap(find.byKey(const Key('cipher-encode-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('The cipher encoding request is invalid.'),
        findsOneWidget,
      );
      expect(find.textContaining('Attack'), findsNothing);
      expect(find.textContaining('K3Y'), findsNothing);
      expect(find.byKey(const Key('cipher-encode-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenAdapterAccessFailures_WhenUsed_ThenStaleResultsAreCleared',
    (tester) async {
      await pumpCipher(
        tester,
        clipboardReader: () async => throw StateError('private clipboard'),
        clipboardWriter: (_) async => throw StateError('private clipboard'),
        fileSaver: (_, _, _) async => throw StateError('private file'),
      );
      await tester.tap(find.byKey(const Key('cipher-encode-paste')));
      await tester.pumpAndSettle();
      expect(
        find.text('The clipboard text could not be read.'),
        findsOneWidget,
      );
      expect(find.textContaining('private'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('cipher-encode-input')),
        'Abc',
      );
      await select(tester, 'cipher-encode-cipher', 'Atbash');
      await tester.tap(find.byKey(const Key('cipher-encode-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Zyx'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cipher-encode-copy')));
      await tester.pumpAndSettle();
      expect(
        find.text('The clipboard text could not be written.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('cipher-encode-result')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('cipher-encode-input')),
        'Abc',
      );
      await tester.tap(find.byKey(const Key('cipher-encode-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cipher-encode-save')));
      await tester.pumpAndSettle();
      expect(
        find.text('The cipher encoded text could not be saved.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('cipher-encode-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenKeyboardUser_WhenTraversing_ThenResultCopyAndSaveFollowInOrder',
    (tester) async {
      String? copied;
      var saves = 0;
      await pumpCipher(
        tester,
        clipboardWriter: (value) async => copied = value,
        fileSaver: (_, _, _) async {
          saves++;
          return true;
        },
      );
      await tester.enterText(find.byKey(const Key('cipher-encode-shift')), '0');
      await tester.tap(find.byKey(const Key('cipher-encode-input')));
      for (final key in const [
        'cipher-encode-input',
        'cipher-encode-file',
        'cipher-encode-paste',
        'cipher-encode-cipher',
        'cipher-encode-policy',
        'cipher-encode-shift',
        'cipher-encode-submit',
      ]) {
        if (key != 'cipher-encode-input') {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
        }
        expect(
          find.ancestor(
            of: find.byWidget(
              FocusManager.instance.primaryFocus!.context!.widget,
            ),
            matching: find.byKey(Key(key)),
          ),
          findsOneWidget,
          reason: key,
        );
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus!.debugLabel,
        'Cipher encoding result',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(copied, '');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(saves, 1);
    },
  );

  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}NarrowLargeText_WhenEncoded_ThenLayoutAndAccessibilityPass',
      (tester) async {
        final semantics = tester.ensureSemantics();
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          ChimeraApp(initialLocation: '/cipher/encode', localeTag: locale),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('cipher-encode-input')),
          'Abc',
        );
        await tester.enterText(
          find.byKey(const Key('cipher-encode-shift')),
          '0',
        );
        await tester.ensureVisible(
          find.byKey(const Key('cipher-encode-submit')),
        );
        await tester.tap(find.byKey(const Key('cipher-encode-submit')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('cipher-encode-save')));
        expect(tester.takeException(), isNull);
        for (final key in const [
          'cipher-encode-file',
          'cipher-encode-paste',
          'cipher-encode-cipher',
          'cipher-encode-policy',
          'cipher-encode-shift',
          'cipher-encode-submit',
          'cipher-encode-copy',
          'cipher-encode-save',
        ]) {
          final size = tester.getSize(find.byKey(Key(key)));
          expect(size.width, greaterThanOrEqualTo(48), reason: key);
          expect(size.height, greaterThanOrEqualTo(48), reason: key);
        }
        await tester.ensureVisible(
          find.byKey(const Key('cipher-encode-input')),
        );
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      },
    );
  }
}
