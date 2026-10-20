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
    OperationService<AlphabetDecodeOperationRequest, AlphabetDecodeOutput>
        service =
        const AlphabetDecodeService(),
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
        initialLocation: '/alphabet/decode',
        localeTag: locale,
        alphabetDecodeService: service,
        alphabetDecodeFilePicker: filePicker,
        alphabetDecodeClipboardReader: clipboardReader,
        alphabetDecodeClipboardWriter: clipboardWriter,
        alphabetDecodeFileSaver: fileSaver,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const Key('alphabet-decode-alphabet')));
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
        find.text(locale == 'en' ? 'Decode Alphabet' : 'Decodificar alfabeto'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('alphabet-decode-input')), findsOneWidget);
      expect(find.byKey(const Key('alphabet-decode-submit')), findsOneWidget);
    }
  });

  testWidgets(
    'GivenEachAlphabet_WhenDecoded_ThenResultMappingAndSemanticsRender',
    (tester) async {
      final fixtures =
          <({String label, String input, String output, String id})>[
            (
              label: 'Morse',
              input: '... --- ...',
              output: 'SOS',
              id: 'itu-r-m.1677-1',
            ),
            (
              label: 'NATO/ICAO phonetic',
              input: 'alfa ZULU',
              output: 'AZ',
              id: 'icao-radiotelephony-spelling-alphabet',
            ),
            (
              label: 'Braille (UEB)',
              input: '\u2820\u2801\u283c\u2801',
              output: 'A1',
              id: 'ueb-uncontracted-unicode',
            ),
          ];
      for (final fixture in fixtures) {
        await pumpAlphabet(tester);
        await tester.enterText(
          find.byKey(const Key('alphabet-decode-input')),
          fixture.input,
        );
        if (fixture.label != 'Morse') await select(tester, fixture.label);
        await tester.tap(find.byKey(const Key('alphabet-decode-submit')));
        await tester.pumpAndSettle();

        expect(find.text(fixture.output), findsOneWidget);
        expect(find.text(fixture.id), findsOneWidget);
        expect(
          tester
              .getSemantics(find.byKey(const Key('alphabet-decode-result')))
              .getSemanticsData()
              .value,
          contains(fixture.output),
        );
        expect(
          tester
              .getSemantics(find.byKey(const Key('alphabet-decode-mapping')))
              .getSemanticsData()
              .value,
          contains(fixture.id),
        );
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('alphabet-decode-input')))
              .controller!
              .text,
          isEmpty,
        );
      }
    },
  );

  testWidgets('GivenDecodedText_WhenCopiedAndSaved_ThenExactTextTransfers', (
    tester,
  ) async {
    String? copied;
    List<int>? saved;
    await pumpAlphabet(
      tester,
      clipboardWriter: (value) async => copied = value,
      fileSaver: (name, bytes, mime) async {
        expect(name, 'chimera-alphabet-decoded.txt');
        expect(mime, 'text/plain; charset=utf-8');
        saved = bytes;
        return true;
      },
    );
    await tester.enterText(
      find.byKey(const Key('alphabet-decode-input')),
      '... --- ...',
    );
    await tester.tap(find.byKey(const Key('alphabet-decode-submit')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('alphabet-decode-copy')));
    await tester.tap(find.byKey(const Key('alphabet-decode-copy')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('alphabet-decode-save')));
    await tester.tap(find.byKey(const Key('alphabet-decode-save')));
    await tester.pumpAndSettle();

    expect(copied, 'SOS');
    expect(utf8.decode(saved!), 'SOS');
    expect(find.text('Alphabet-decoded text saved.'), findsOneWidget);
  });

  testWidgets('GivenFileAndClipboard_WhenDecoded_ThenAlternativeFlowsWork', (
    tester,
  ) async {
    await pumpAlphabet(
      tester,
      filePicker: () async => utf8.encode('Alfa Zulu'),
      clipboardReader: () async => '... --- ...',
    );
    await tester.tap(find.byKey(const Key('alphabet-decode-file')));
    await tester.pumpAndSettle();
    await select(tester, 'NATO/ICAO phonetic');
    await tester.tap(find.byKey(const Key('alphabet-decode-submit')));
    await tester.pumpAndSettle();
    expect(find.text('AZ'), findsOneWidget);

    await tester.tap(find.byKey(const Key('alphabet-decode-paste')));
    await tester.pumpAndSettle();
    await select(tester, 'Morse');
    await tester.tap(find.byKey(const Key('alphabet-decode-submit')));
    await tester.pumpAndSettle();
    expect(find.text('SOS'), findsOneWidget);
  });

  testWidgets(
    'GivenAmbiguousInput_WhenDecoded_ThenFailureClearsSourceAndResult',
    (tester) async {
      await pumpAlphabet(tester);
      await tester.enterText(
        find.byKey(const Key('alphabet-decode-input')),
        '.-  -...',
      );
      await tester.tap(find.byKey(const Key('alphabet-decode-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('The alphabet decoding request is invalid.'),
        findsOneWidget,
      );
      expect(find.textContaining('.-'), findsNothing);
      expect(find.byKey(const Key('alphabet-decode-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenLateServiceCompletion_WhenPageDisposed_ThenStateIsIgnored',
    (tester) async {
      final service = _DeferredService();
      await pumpAlphabet(tester, service: service);
      await tester.enterText(
        find.byKey(const Key('alphabet-decode-input')),
        '... --- ...',
      );
      await tester.tap(find.byKey(const Key('alphabet-decode-submit')));
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
          find.byKey(const Key('alphabet-decode-input')),
          '.-',
        );
        await tester.tap(find.byKey(const Key('alphabet-decode-submit')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final key in [
          'alphabet-decode-file',
          'alphabet-decode-paste',
          'alphabet-decode-alphabet',
          'alphabet-decode-submit',
          'alphabet-decode-copy',
          'alphabet-decode-save',
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
        OperationService<AlphabetDecodeOperationRequest, AlphabetDecodeOutput> {
  final _completer = Completer<ChimeraResult<AlphabetDecodeOutput>>();

  @override
  Future<ChimeraResult<AlphabetDecodeOutput>> execute(
    AlphabetDecodeOperationRequest request,
  ) => _completer.future;

  void complete() async {
    final result = await const AlphabetDecodeService().execute(
      AlphabetDecodeOperationRequest.text('... --- ...', alphabet: 'morse'),
    );
    _completer.complete(result);
  }
}
