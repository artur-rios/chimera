import 'dart:async';
import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpAlphabet(
    WidgetTester tester, {
    String locale = 'en',
    OperationService<AlphabetEncodeOperationRequest, AlphabetEncodeOutput>
        service =
        const AlphabetEncodeService(),
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
        initialLocation: '/alphabet/encode',
        localeTag: locale,
        alphabetEncodeService: service,
        alphabetEncodeFilePicker: filePicker,
        alphabetEncodeClipboardReader: clipboardReader,
        alphabetEncodeClipboardWriter: clipboardWriter,
        alphabetEncodeFileSaver: fileSaver,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const Key('alphabet-encode-alphabet')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('GivenBothLocales_WhenRouteOpens_ThenLocalizedControlsRender', (
    tester,
  ) async {
    for (final locale in ['en', 'pt-BR']) {
      await pumpAlphabet(tester, locale: locale);
      expect(
        find.text(
          locale == 'en' ? 'Encode with Alphabet' : 'Codificar com alfabeto',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('alphabet-encode-input')), findsOneWidget);
      expect(find.byKey(const Key('alphabet-encode-alphabet')), findsOneWidget);
      expect(find.byKey(const Key('alphabet-encode-submit')), findsOneWidget);
    }
  });

  testWidgets('GivenEachAlphabet_WhenEncoded_ThenKnownResultAndMappingRender', (
    tester,
  ) async {
    final fixtures = <({String label, String input, String output, String id})>[
      (
        label: 'Morse',
        input: 'SOS',
        output: '... --- ...',
        id: 'itu-r-m.1677-1',
      ),
      (
        label: 'NATO/ICAO phonetic',
        input: 'AZ',
        output: 'Alfa Zulu',
        id: 'icao-radiotelephony-spelling-alphabet',
      ),
      (
        label: 'Braille (UEB)',
        input: 'A1',
        output: '\u2820\u2801\u283c\u2801',
        id: 'ueb-uncontracted-unicode',
      ),
    ];
    for (final fixture in fixtures) {
      await pumpAlphabet(tester);
      await tester.enterText(
        find.byKey(const Key('alphabet-encode-input')),
        fixture.input,
      );
      if (fixture.label != 'Morse') await select(tester, fixture.label);
      await tester.tap(find.byKey(const Key('alphabet-encode-submit')));
      await tester.pumpAndSettle();

      expect(find.text(fixture.output), findsOneWidget);
      expect(find.text(fixture.id), findsOneWidget);
      expect(find.byKey(const Key('alphabet-encode-mapping')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('alphabet-encode-input')))
            .controller!
            .text,
        isEmpty,
      );
    }
  });

  testWidgets('GivenText_WhenCopiedAndSaved_ThenExactEncodedTextTransfers', (
    tester,
  ) async {
    String? copied;
    List<int>? saved;
    await pumpAlphabet(
      tester,
      clipboardWriter: (value) async => copied = value,
      fileSaver: (name, bytes, mime) async {
        expect(name, 'chimera-alphabet-encoded.txt');
        expect(mime, 'text/plain; charset=utf-8');
        saved = bytes;
        return true;
      },
    );
    await tester.enterText(
      find.byKey(const Key('alphabet-encode-input')),
      'SOS',
    );
    await tester.tap(find.byKey(const Key('alphabet-encode-submit')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('alphabet-encode-copy')));
    await tester.tap(find.byKey(const Key('alphabet-encode-copy')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('alphabet-encode-save')));
    await tester.tap(find.byKey(const Key('alphabet-encode-save')));
    await tester.pumpAndSettle();

    expect(copied, '... --- ...');
    expect(utf8.decode(saved!), '... --- ...');
    expect(find.text('Alphabet-encoded text saved.'), findsOneWidget);
  });

  testWidgets('GivenFileAndClipboard_WhenEncoded_ThenAlternativeFlowsWork', (
    tester,
  ) async {
    await pumpAlphabet(
      tester,
      filePicker: () async => utf8.encode('AZ'),
      clipboardReader: () async => 'SOS',
    );
    await tester.tap(find.byKey(const Key('alphabet-encode-file')));
    await tester.pumpAndSettle();
    await select(tester, 'NATO/ICAO phonetic');
    await tester.tap(find.byKey(const Key('alphabet-encode-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Alfa Zulu'), findsOneWidget);

    await tester.tap(find.byKey(const Key('alphabet-encode-paste')));
    await tester.pumpAndSettle();
    await select(tester, 'Morse');
    await tester.tap(find.byKey(const Key('alphabet-encode-submit')));
    await tester.pumpAndSettle();
    expect(find.text('... --- ...'), findsOneWidget);
  });

  testWidgets('GivenUnsupportedSymbol_WhenEncoded_ThenSafeFailureClearsState', (
    tester,
  ) async {
    await pumpAlphabet(tester);
    await tester.enterText(
      find.byKey(const Key('alphabet-encode-input')),
      'A??B',
    );
    await tester.tap(find.byKey(const Key('alphabet-encode-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('The alphabet encoding request is invalid.'),
      findsOneWidget,
    );
    expect(find.textContaining('??'), findsNothing);
    expect(find.byKey(const Key('alphabet-encode-result')), findsNothing);
  });

  testWidgets('GivenAdapterFailures_WhenUsed_ThenLocalizedErrorsAreRedacted', (
    tester,
  ) async {
    await pumpAlphabet(
      tester,
      clipboardReader: () async => throw StateError('private clipboard'),
      clipboardWriter: (_) async => throw StateError('private clipboard'),
      fileSaver: (_, _, _) async => throw StateError('private file'),
    );
    await tester.tap(find.byKey(const Key('alphabet-encode-paste')));
    await tester.pumpAndSettle();
    expect(find.text('The clipboard text could not be read.'), findsOneWidget);
    expect(find.textContaining('private'), findsNothing);

    for (final key in ['alphabet-encode-copy', 'alphabet-encode-save']) {
      await tester.enterText(
        find.byKey(const Key('alphabet-encode-input')),
        'A',
      );
      await tester.tap(find.byKey(const Key('alphabet-encode-submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('alphabet-encode-result')), findsNothing);
    }
  });

  testWidgets(
    'GivenLateServiceCompletion_WhenPageDisposed_ThenStateIsIgnored',
    (tester) async {
      final service = _DeferredService();
      await pumpAlphabet(tester, service: service);
      await tester.enterText(
        find.byKey(const Key('alphabet-encode-input')),
        'SOS',
      );
      await tester.tap(find.byKey(const Key('alphabet-encode-submit')));
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      service.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}LargeText_WhenRendered_ThenTargetsAndLayoutPass',
      (tester) async {
        final semantics = tester.ensureSemantics();
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpAlphabet(tester, locale: locale);
        await tester.enterText(
          find.byKey(const Key('alphabet-encode-input')),
          'A',
        );
        await tester.tap(find.byKey(const Key('alphabet-encode-submit')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final key in [
          'alphabet-encode-file',
          'alphabet-encode-paste',
          'alphabet-encode-alphabet',
          'alphabet-encode-submit',
          'alphabet-encode-copy',
          'alphabet-encode-save',
        ]) {
          await tester.ensureVisible(find.byKey(Key(key)));
          final size = tester.getSize(find.byKey(Key(key)));
          expect(size.width, greaterThanOrEqualTo(48), reason: key);
          expect(size.height, greaterThanOrEqualTo(48), reason: key);
        }
        semantics.dispose();
      },
    );
  }
}

final class _DeferredService
    implements
        OperationService<AlphabetEncodeOperationRequest, AlphabetEncodeOutput> {
  final _completer = Completer<ChimeraResult<AlphabetEncodeOutput>>();

  @override
  Future<ChimeraResult<AlphabetEncodeOutput>> execute(
    AlphabetEncodeOperationRequest request,
  ) => _completer.future;

  void complete() async {
    final result = await const AlphabetEncodeService().execute(
      AlphabetEncodeOperationRequest.text('SOS', alphabet: 'morse'),
    );
    _completer.complete(result);
  }
}
