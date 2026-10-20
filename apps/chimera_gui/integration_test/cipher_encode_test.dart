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
      'Given${locale}CipherText_WhenEncodedCopiedAndSaved_ThenExactResultTransfersOffline',
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
        final saved = File('${directory.path}/chimera-cipher-encoded.txt');
        String? copied;
        try {
          await tester.pumpWidget(
            ChimeraApp(
              localeTag: locale,
              initialLocation: '/cipher/encode',
              cipherEncodeClipboardWriter: (value) async => copied = value,
              cipherEncodeFileSaver: (name, bytes, mime) async {
                expect(name, 'chimera-cipher-encoded.txt');
                expect(mime, 'text/plain; charset=utf-8');
                await saved.writeAsBytes(bytes, flush: true);
                return true;
              },
            ),
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('cipher-encode-input')),
            'Attack!',
          );
          await _select(
            tester,
            const Key('cipher-encode-cipher'),
            locale == 'en' ? 'Vigenere' : 'Vigenère',
          );
          await tester.enterText(
            find.byKey(const Key('cipher-encode-key')),
            'LEMON',
          );
          await tester.tap(find.byKey(const Key('cipher-encode-submit')));
          await tester.pumpAndSettle();

          final result = find.byKey(const Key('cipher-encode-result'));
          final semanticsData = tester.getSemantics(result).getSemanticsData();
          expect(
            semanticsData.label,
            locale == 'en' ? 'Cipher encoded result' : 'Resultado cifrado',
          );
          expect(
            tester
                .widget<SelectableText>(
                  find.byKey(const Key('cipher-encode-output')),
                )
                .data,
            'Lxfopv!',
          );
          expect(
            tester
                .widget<TextField>(find.byKey(const Key('cipher-encode-input')))
                .controller!
                .text,
            isEmpty,
          );
          expect(
            tester
                .widget<TextField>(find.byKey(const Key('cipher-encode-key')))
                .controller!
                .text,
            isEmpty,
          );
          await tester.tap(find.byKey(const Key('cipher-encode-copy')));
          await tester.pumpAndSettle();
          expect(copied, 'Lxfopv!');
          await tester.tap(find.byKey(const Key('cipher-encode-save')));
          await tester.pumpAndSettle();
          expect(await saved.readAsBytes(), utf8.encode('Lxfopv!'));
          expect(network.attempts, 0);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'GivenInvalidVigenereKey_WhenEncoded_ThenLocalizedFailureHasNoResult',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(initialLocation: '/cipher/encode'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('cipher-encode-input')),
        'Attack',
      );
      await _select(tester, const Key('cipher-encode-cipher'), 'Vigenere');
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
    'GivenRejectedUnicode_WhenEncoded_ThenNoSensitiveSymbolOrResultRemains',
    (tester) async {
      final network = _Offline();
      final previous = HttpOverrides.current;
      HttpOverrides.global = network;
      addTearDown(() => HttpOverrides.global = previous);
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/cipher/encode',
          cipherEncodeFilePicker: () async => utf8.encode('A🌍B'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cipher-encode-file')));
      await tester.pumpAndSettle();
      await _select(tester, const Key('cipher-encode-cipher'), 'Atbash');
      await _select(
        tester,
        const Key('cipher-encode-policy'),
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
      expect(find.byKey(const Key('cipher-encode-copy')), findsNothing);
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
    throw StateError('Network access is prohibited during cipher encoding.');
  }
}
