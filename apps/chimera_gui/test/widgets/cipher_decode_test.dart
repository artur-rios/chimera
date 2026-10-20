import 'dart:async';
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
        initialLocation: '/cipher/decode',
        localeTag: locale,
        cipherDecodeFilePicker: filePicker,
        cipherDecodeClipboardReader: clipboardReader,
        cipherDecodeClipboardWriter: clipboardWriter,
        cipherDecodeFileSaver: fileSaver,
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
            locale == 'en' ? 'Decode with Cipher' : 'Decodificar com cifra',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('cipher-decode-input')), findsOneWidget);
        expect(find.byKey(const Key('cipher-decode-cipher')), findsOneWidget);
        expect(find.byKey(const Key('cipher-decode-policy')), findsOneWidget);
      }
    },
  );

  testWidgets(
    'GivenText_WhenAtbashDecodedCopiedAndSaved_ThenExactResultTransfers',
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
        find.byKey(const Key('cipher-decode-input')),
        'Zyx!',
      );
      await select(tester, 'cipher-decode-cipher', 'Atbash');
      await tester.tap(find.byKey(const Key('cipher-decode-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Abc!'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cipher-decode-copy')));
      await tester.pumpAndSettle();
      expect(copied, 'Abc!');
      await tester.tap(find.byKey(const Key('cipher-decode-save')));
      await tester.pumpAndSettle();
      expect(utf8.decode(saved!), 'Abc!');
      expect(find.text('Cipher decoded text saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenCipherSelection_WhenChanged_ThenOnlyMatchingParametersRender',
    (tester) async {
      await pumpCipher(tester);

      expect(find.byKey(const Key('cipher-decode-shift')), findsOneWidget);
      await select(tester, 'cipher-decode-cipher', 'Vigenere');
      expect(find.byKey(const Key('cipher-decode-key')), findsOneWidget);
      expect(find.byKey(const Key('cipher-decode-shift')), findsNothing);
      await select(tester, 'cipher-decode-cipher', 'Affine');
      expect(find.byKey(const Key('cipher-decode-a')), findsOneWidget);
      expect(find.byKey(const Key('cipher-decode-b')), findsOneWidget);
      await select(tester, 'cipher-decode-cipher', 'Rail Fence');
      expect(find.byKey(const Key('cipher-decode-rails')), findsOneWidget);
    },
  );

  testWidgets(
    'GivenFileWithRejectedSymbol_WhenDecoded_ThenLocalizedSafeErrorReturns',
    (tester) async {
      await pumpCipher(tester, filePicker: () async => utf8.encode('A🌍B'));
      await tester.tap(find.byKey(const Key('cipher-decode-file')));
      await tester.pumpAndSettle();
      await select(tester, 'cipher-decode-cipher', 'Atbash');
      await select(
        tester,
        'cipher-decode-policy',
        'Reject unsupported symbols',
      );
      await tester.tap(find.byKey(const Key('cipher-decode-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('The cipher decoding request is invalid.'),
        findsOneWidget,
      );
      expect(find.textContaining('🌍'), findsNothing);
      expect(find.byKey(const Key('cipher-decode-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenFileAndParameter_WhenCaesarDecoded_ThenFileSourceIsRetained',
    (tester) async {
      await pumpCipher(tester, filePicker: () async => utf8.encode('Bcd'));
      await tester.tap(find.byKey(const Key('cipher-decode-file')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cipher-decode-shift')), '1');
      await tester.tap(find.byKey(const Key('cipher-decode-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Abc'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenClipboardText_WhenPastedAndDecoded_ThenExactResultReturns',
    (tester) async {
      await pumpCipher(tester, clipboardReader: () async => 'Zyx!');
      await tester.tap(find.byKey(const Key('cipher-decode-paste')));
      await tester.pumpAndSettle();
      await select(tester, 'cipher-decode-cipher', 'Atbash');
      await tester.tap(find.byKey(const Key('cipher-decode-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Abc!'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenInvalidVigenereKey_WhenDecoded_ThenFailureIsRedactedAndStateCleared',
    (tester) async {
      await pumpCipher(tester);
      await tester.enterText(
        find.byKey(const Key('cipher-decode-input')),
        'Attack',
      );
      await select(tester, 'cipher-decode-cipher', 'Vigenere');
      await tester.enterText(find.byKey(const Key('cipher-decode-key')), 'K3Y');
      await tester.tap(find.byKey(const Key('cipher-decode-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('The cipher decoding request is invalid.'),
        findsOneWidget,
      );
      expect(find.textContaining('Attack'), findsNothing);
      expect(find.textContaining('K3Y'), findsNothing);
      expect(find.byKey(const Key('cipher-decode-result')), findsNothing);
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
      await tester.tap(find.byKey(const Key('cipher-decode-paste')));
      await tester.pumpAndSettle();
      expect(
        find.text('The clipboard text could not be read.'),
        findsOneWidget,
      );
      expect(find.textContaining('private'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('cipher-decode-input')),
        'Zyx',
      );
      await select(tester, 'cipher-decode-cipher', 'Atbash');
      await tester.tap(find.byKey(const Key('cipher-decode-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Abc'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cipher-decode-copy')));
      await tester.pumpAndSettle();
      expect(
        find.text('The clipboard text could not be written.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('cipher-decode-result')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('cipher-decode-input')),
        'Zyx',
      );
      await tester.tap(find.byKey(const Key('cipher-decode-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cipher-decode-save')));
      await tester.pumpAndSettle();
      expect(
        find.text('The cipher decoded text could not be saved.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('cipher-decode-result')), findsNothing);
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
      await tester.enterText(find.byKey(const Key('cipher-decode-shift')), '0');
      await tester.tap(find.byKey(const Key('cipher-decode-input')));
      for (final key in const [
        'cipher-decode-input',
        'cipher-decode-file',
        'cipher-decode-paste',
        'cipher-decode-cipher',
        'cipher-decode-policy',
        'cipher-decode-shift',
        'cipher-decode-submit',
      ]) {
        if (key != 'cipher-decode-input') {
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
        'Cipher decoding result',
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

  testWidgets(
    'GivenPendingFile_WhenPageIsDisposed_ThenLateCompletionIsIgnored',
    (tester) async {
      final pending = Completer<List<int>?>();
      await pumpCipher(tester, filePicker: () => pending.future);
      await tester.tap(find.byKey(const Key('cipher-decode-file')));
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete(utf8.encode('private'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('private'), findsNothing);
    },
  );

  testWidgets(
    'GivenPendingCopy_WhenPageIsDisposed_ThenLateCompletionIsIgnored',
    (tester) async {
      final pending = Completer<void>();
      await pumpCipher(tester, clipboardWriter: (_) => pending.future);
      await tester.enterText(
        find.byKey(const Key('cipher-decode-input')),
        'Zyx',
      );
      await select(tester, 'cipher-decode-cipher', 'Atbash');
      await tester.tap(find.byKey(const Key('cipher-decode-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cipher-decode-copy')));
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Abc'), findsNothing);
    },
  );

  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}NarrowLargeText_WhenDecoded_ThenLayoutAndAccessibilityPass',
      (tester) async {
        final semantics = tester.ensureSemantics();
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          ChimeraApp(initialLocation: '/cipher/decode', localeTag: locale),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('cipher-decode-input')),
          'Zyx',
        );
        await tester.enterText(
          find.byKey(const Key('cipher-decode-shift')),
          '0',
        );
        await tester.ensureVisible(
          find.byKey(const Key('cipher-decode-submit')),
        );
        await tester.tap(find.byKey(const Key('cipher-decode-submit')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('cipher-decode-save')));
        expect(tester.takeException(), isNull);
        for (final key in const [
          'cipher-decode-file',
          'cipher-decode-paste',
          'cipher-decode-cipher',
          'cipher-decode-policy',
          'cipher-decode-shift',
          'cipher-decode-submit',
          'cipher-decode-copy',
          'cipher-decode-save',
        ]) {
          final size = tester.getSize(find.byKey(Key(key)));
          expect(size.width, greaterThanOrEqualTo(48), reason: key);
          expect(size.height, greaterThanOrEqualTo(48), reason: key);
        }
        await tester.ensureVisible(
          find.byKey(const Key('cipher-decode-input')),
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
