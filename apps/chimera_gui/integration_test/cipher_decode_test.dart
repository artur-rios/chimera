import 'dart:convert';
import 'dart:io';

import 'package:chimera_gui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}CipherText_WhenDecodedCopiedAndSaved_ThenExactResultTransfersOffline',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final network = _Offline();
        final previous = HttpOverrides.current;
        HttpOverrides.global = network;
        addTearDown(() => HttpOverrides.global = previous);
        final directory = await Directory.systemTemp.createTemp(
          'chimera-cipher-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final saved = File('${directory.path}/chimera-cipher-decoded.txt');
        String? copied;
        Future<bool>? saveOperation;
        try {
          await tester.pumpWidget(
            ChimeraApp(
              localeTag: locale,
              initialLocation: '/cipher/decode',
              cipherDecodeClipboardWriter: (value) async => copied = value,
              cipherDecodeFileSaver: (name, bytes, mime) {
                expect(name, 'chimera-cipher-decoded.txt');
                expect(mime, 'text/plain; charset=utf-8');
                return saveOperation = saved
                    .writeAsBytes(bytes, flush: true)
                    .then((_) => true);
              },
            ),
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('cipher-decode-input')),
            'Lxfopv!',
          );
          await _select(
            tester,
            const Key('cipher-decode-cipher'),
            locale == 'en' ? 'Vigenere' : 'Vigen\u00E8re',
          );
          await tester.enterText(
            find.byKey(const Key('cipher-decode-key')),
            'LEMON',
          );
          await tester.tap(find.byKey(const Key('cipher-decode-submit')));
          await tester.pumpAndSettle();

          final result = find.byKey(const Key('cipher-decode-result'));
          final semanticsData = tester.getSemantics(result).getSemanticsData();
          expect(
            semanticsData.label,
            locale == 'en' ? 'Cipher decoded result' : 'Resultado decifrado',
          );
          expect(
            tester
                .widget<SelectableText>(
                  find.byKey(const Key('cipher-decode-output')),
                )
                .data,
            'Attack!',
          );
          expect(
            tester
                .widget<TextField>(find.byKey(const Key('cipher-decode-input')))
                .controller!
                .text,
            isEmpty,
          );
          expect(
            tester
                .widget<TextField>(find.byKey(const Key('cipher-decode-key')))
                .controller!
                .text,
            isEmpty,
          );
          await tester.tap(find.byKey(const Key('cipher-decode-copy')));
          await tester.pumpAndSettle();
          expect(copied, 'Attack!');
          await tester.tap(find.byKey(const Key('cipher-decode-save')));
          expect(saveOperation, isNotNull);
          expect(await saveOperation!, isTrue);
          await tester.pumpAndSettle();
          expect(await saved.readAsBytes(), utf8.encode('Attack!'));
          expect(network.attempts, 0);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'GivenInvalidVigenereKey_WhenDecoded_ThenLocalizedFailureHasNoResult',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(initialLocation: '/cipher/decode'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('cipher-decode-input')),
        'Attack',
      );
      await _select(tester, const Key('cipher-decode-cipher'), 'Vigenere');
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
    'GivenRejectedUnicode_WhenDecoded_ThenNoSensitiveSymbolOrResultRemains',
    (tester) async {
      final network = _Offline();
      final previous = HttpOverrides.current;
      HttpOverrides.global = network;
      addTearDown(() => HttpOverrides.global = previous);
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/cipher/decode',
          cipherDecodeFilePicker: () async => utf8.encode('A🌍B'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cipher-decode-file')));
      await tester.pumpAndSettle();
      await _select(tester, const Key('cipher-decode-cipher'), 'Atbash');
      await _select(
        tester,
        const Key('cipher-decode-policy'),
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
      expect(find.byKey(const Key('cipher-decode-copy')), findsNothing);
      expect(network.attempts, 0);
    },
  );
}

Future<void> _select(WidgetTester tester, Key key, String label) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

final class _Offline extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Network access is prohibited during cipher decoding.');
  }
}
