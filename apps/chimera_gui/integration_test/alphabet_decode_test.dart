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
      'Given${locale}Text_WhenAlphabetDecodedCopiedAndSaved_ThenExactResultTransfersOffline',
      (tester) async {
        final network = _Offline();
        final previous = HttpOverrides.current;
        HttpOverrides.global = network;
        addTearDown(() => HttpOverrides.global = previous);
        final directory = await Directory.systemTemp.createTemp(
          'chimera-alphabet-decode-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final saved = File('${directory.path}/chimera-alphabet-decoded.txt');
        String? copied;
        await tester.pumpWidget(
          ChimeraApp(
            localeTag: locale,
            initialLocation: '/alphabet/decode',
            alphabetDecodeClipboardWriter: (value) async => copied = value,
            alphabetDecodeFileSaver: (name, bytes, mime) async {
              expect(name, 'chimera-alphabet-decoded.txt');
              expect(mime, 'text/plain; charset=utf-8');
              await saved.writeAsBytes(bytes, flush: true);
              return true;
            },
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('alphabet-decode-input')),
          '... --- ... / ..---',
        );
        await tester.tap(find.byKey(const Key('alphabet-decode-submit')));
        await tester.pumpAndSettle();

        expect(find.text('SOS 2'), findsOneWidget);
        expect(find.text('itu-r-m.1677-1'), findsOneWidget);
        expect(find.text('10/2009'), findsOneWidget);
        expect(
          tester
              .getSemantics(find.byKey(const Key('alphabet-decode-result')))
              .getSemanticsData()
              .value,
          contains('SOS 2'),
        );
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('alphabet-decode-input')))
              .controller!
              .text,
          isEmpty,
        );
        await tester.ensureVisible(
          find.byKey(const Key('alphabet-decode-copy')),
        );
        await tester.tap(find.byKey(const Key('alphabet-decode-copy')));
        await tester.pumpAndSettle();
        expect(copied, 'SOS 2');
        await tester.ensureVisible(
          find.byKey(const Key('alphabet-decode-save')),
        );
        await tester.tap(find.byKey(const Key('alphabet-decode-save')));
        await tester.pumpAndSettle();
        expect(await saved.readAsString(), 'SOS 2');
        expect(network.attempts, 0);
      },
    );
  }

  testWidgets('GivenFileAndClipboard_WhenDecoded_ThenAlternativeFlowsWork', (
    tester,
  ) async {
    final network = _Offline();
    final previous = HttpOverrides.current;
    HttpOverrides.global = network;
    addTearDown(() => HttpOverrides.global = previous);
    await tester.pumpWidget(
      ChimeraApp(
        initialLocation: '/alphabet/decode',
        alphabetDecodeFilePicker: () async => utf8.encode('Alfa Zulu'),
        alphabetDecodeClipboardReader: () async => '... --- ...',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('alphabet-decode-file')));
    await tester.pumpAndSettle();
    await _select(tester, 'NATO/ICAO phonetic');
    await tester.tap(find.byKey(const Key('alphabet-decode-submit')));
    await tester.pumpAndSettle();
    expect(find.text('AZ'), findsOneWidget);

    await tester.tap(find.byKey(const Key('alphabet-decode-paste')));
    await tester.pumpAndSettle();
    await _select(tester, 'Morse');
    await tester.tap(find.byKey(const Key('alphabet-decode-submit')));
    await tester.pumpAndSettle();
    expect(find.text('SOS'), findsOneWidget);
    expect(network.attempts, 0);
  });

  testWidgets('GivenAmbiguousInput_WhenDecoded_ThenSafeFailureReturns', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChimeraApp(
        initialLocation: '/alphabet/decode',
        alphabetDecodeFilePicker: () async => utf8.encode('.-  -...'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('alphabet-decode-file')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('alphabet-decode-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('The alphabet decoding request is invalid.'),
      findsOneWidget,
    );
    expect(find.textContaining('.-'), findsNothing);
    expect(find.byKey(const Key('alphabet-decode-result')), findsNothing);
  });
}

Future<void> _select(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('alphabet-decode-alphabet')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

final class _Offline extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Network access is prohibited during alphabet decoding.');
  }
}
