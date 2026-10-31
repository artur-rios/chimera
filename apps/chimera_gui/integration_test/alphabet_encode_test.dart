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
      'Given${locale}Text_WhenAlphabetEncodedCopiedAndSaved_ThenExactResultTransfersOffline',
      (tester) async {
        final network = _Offline();
        final previous = HttpOverrides.current;
        HttpOverrides.global = network;
        addTearDown(() => HttpOverrides.global = previous);
        final directory = await Directory.systemTemp.createTemp(
          'chimera-alphabet-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final saved = File('${directory.path}/chimera-alphabet-encoded.txt');
        String? copied;
        Future<bool>? saveOperation;
        await tester.pumpWidget(
          ChimeraApp(
            localeTag: locale,
            initialLocation: '/alphabet/encode',
            alphabetEncodeClipboardWriter: (value) async => copied = value,
            alphabetEncodeFileSaver: (name, bytes, mime) {
              expect(name, 'chimera-alphabet-encoded.txt');
              expect(mime, 'text/plain; charset=utf-8');
              return saveOperation = saved
                  .writeAsBytes(bytes, flush: true)
                  .then((_) => true);
            },
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('alphabet-encode-input')),
          'SOS 2',
        );
        await tester.tap(find.byKey(const Key('alphabet-encode-submit')));
        await tester.pumpAndSettle();

        expect(find.text('... --- ... / ..---'), findsOneWidget);
        expect(find.text('itu-r-m.1677-1'), findsOneWidget);
        expect(find.text('10/2009'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('alphabet-encode-input')))
              .controller!
              .text,
          isEmpty,
        );
        await tester.ensureVisible(
          find.byKey(const Key('alphabet-encode-copy')),
        );
        await tester.tap(find.byKey(const Key('alphabet-encode-copy')));
        await tester.pumpAndSettle();
        expect(copied, '... --- ... / ..---');
        await tester.ensureVisible(
          find.byKey(const Key('alphabet-encode-save')),
        );
        await tester.tap(find.byKey(const Key('alphabet-encode-save')));
        expect(saveOperation, isNotNull);
        expect(await saveOperation!, isTrue);
        await tester.pumpAndSettle();
        expect(await saved.readAsString(), '... --- ... / ..---');
        expect(network.attempts, 0);
      },
    );
  }

  testWidgets('GivenFileAndClipboard_WhenEncoded_ThenAlternativeFlowsWork', (
    tester,
  ) async {
    final network = _Offline();
    final previous = HttpOverrides.current;
    HttpOverrides.global = network;
    addTearDown(() => HttpOverrides.global = previous);
    await tester.pumpWidget(
      ChimeraApp(
        initialLocation: '/alphabet/encode',
        alphabetEncodeFilePicker: () async => utf8.encode('AZ'),
        alphabetEncodeClipboardReader: () async => 'SOS',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('alphabet-encode-file')));
    await tester.pumpAndSettle();
    await _select(tester, 'NATO/ICAO phonetic');
    await tester.tap(find.byKey(const Key('alphabet-encode-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Alfa Zulu'), findsOneWidget);

    await tester.tap(find.byKey(const Key('alphabet-encode-paste')));
    await tester.pumpAndSettle();
    await _select(tester, 'Morse');
    await tester.tap(find.byKey(const Key('alphabet-encode-submit')));
    await tester.pumpAndSettle();
    expect(find.text('... --- ...'), findsOneWidget);
    expect(network.attempts, 0);
  });

  testWidgets('GivenUnsupportedSymbol_WhenEncoded_ThenSafeFailureReturns', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChimeraApp(
        initialLocation: '/alphabet/encode',
        alphabetEncodeFilePicker: () async => utf8.encode('A??B'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('alphabet-encode-file')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('alphabet-encode-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('The alphabet encoding request is invalid.'),
      findsOneWidget,
    );
    expect(find.textContaining('??'), findsNothing);
    expect(find.byKey(const Key('alphabet-encode-result')), findsNothing);
  });
}

Future<void> _select(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('alphabet-encode-alphabet')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

final class _Offline extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Network access is prohibited during alphabet encoding.');
  }
}
