import 'dart:async';
import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_gui/card_page.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}Defaults_WhenGeneratedCopiedSaved_ThenExactLabeledData',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          String? copied;
          List<int>? saved;
          await tester.pumpWidget(
            ChimeraApp(
              localeTag: locale,
              initialLocation: '/card/generate',
              cardService: _service('4242424242424242'),
              cardClipboardWriter: (value) async => copied = value,
              cardFileSaver: (name, bytes, mime) async {
                expect(name, 'chimera-synthetic-cards.txt');
                expect(mime, 'text/plain; charset=utf-8');
                saved = bytes;
                return true;
              },
            ),
          );

          await tester.tap(find.byKey(const Key('card-generate')));
          await tester.pumpAndSettle();
          final label = locale == 'en'
              ? 'Synthetic test data - not for real transactions'
              : 'Dados sintéticos de teste - não usar em transações reais';
          expect(find.text(label), findsOneWidget);
          expect(
            tester
                .widget<SelectableText>(find.byKey(const Key('card-output')))
                .data,
            '4242424242424242',
          );
          expect(
            tester
                .getSemantics(find.byKey(const Key('card-result')))
                .getSemanticsData()
                .label,
            locale == 'en'
                ? 'Generated synthetic cards'
                : 'Cartões sintéticos gerados',
          );

          await tester.ensureVisible(find.byKey(const Key('card-copy')));
          await tester.tap(find.byKey(const Key('card-copy')));
          await tester.pumpAndSettle();
          expect(copied, '$label\n4242424242424242');
          await tester.ensureVisible(find.byKey(const Key('card-save')));
          await tester.tap(find.byKey(const Key('card-save')));
          await tester.pumpAndSettle();
          expect(saved, utf8.encode('$label\n4242424242424242'));

          await tester.enterText(find.byKey(const Key('card-count')), '2');
          await tester.pump();
          expect(find.byKey(const Key('card-output')), findsNothing);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  for (final entry in <String, String>{
    'Visa': '4242424242424242',
    'Mastercard': '5555555555554444',
    'American Express': '378282246310005',
    'Discover': '6011111111111117',
  }.entries) {
    testWidgets('Given${entry.key}_WhenGenerated_ThenSelectionIsHonored', (
      tester,
    ) async {
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/card/generate',
          cardService: _service(entry.value),
        ),
      );
      await tester.tap(find.byKey(const Key('card-network')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.key).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('card-generate')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<SelectableText>(find.byKey(const Key('card-output')))
            .data,
        entry.value,
      );
    });
  }

  for (final failure in [
    'validation',
    'processing',
    'copy',
    'save',
    'encode',
  ]) {
    testWidgets(
      'Given${failure}Failure_WhenActionRuns_ThenNoPartialPanOrSecret',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/card/generate',
            cardService: failure == 'processing'
                ? CardService(
                    generator: CardGenerator.forTesting(
                      candidate: (_) => throw StateError('PRIVATE PAN'),
                    ),
                  )
                : _service('4242424242424242'),
            cardClipboardWriter: (_) async => throw StateError('PRIVATE PAN'),
            cardFileSaver: (_, _, _) async => throw StateError('PRIVATE PAN'),
            cardOutputEncoder: failure == 'encode'
                ? (_) => throw OutOfMemoryError()
                : encodeCardOutput,
          ),
        );
        if (failure == 'validation') {
          await tester.enterText(find.byKey(const Key('card-count')), '0');
        }
        await tester.tap(find.byKey(const Key('card-generate')));
        await tester.pumpAndSettle();
        if (failure == 'copy' || failure == 'save' || failure == 'encode') {
          final action = failure == 'copy' ? 'copy' : 'save';
          await tester.ensureVisible(find.byKey(Key('card-$action')));
          await tester.tap(find.byKey(Key('card-$action')));
          await tester.pumpAndSettle();
        }

        expect(find.byKey(const Key('card-error')), findsOneWidget);
        expect(find.byKey(const Key('card-output')), findsNothing);
        expect(find.textContaining('PRIVATE'), findsNothing);
      },
    );
  }

  testWidgets(
    'GivenPendingGeneration_WhenConfigurationChanges_ThenLateCompletionIsIgnored',
    (tester) async {
      final service = _Pending();
      await tester.pumpWidget(
        ChimeraApp(initialLocation: '/card/generate', cardService: service),
      );
      await tester.tap(find.byKey(const Key('card-generate')));
      await tester.pump();
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('card-generate')))
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byKey(const Key('card-count')), '2');
      service.pending.complete(_success('STALE'));
      await tester.pumpAndSettle();
      expect(find.text('STALE'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('GivenKeyboardSubmission_WhenGenerated_ThenResultReceivesFocus', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChimeraApp(
        initialLocation: '/card/generate',
        cardService: _service('4242424242424242'),
      ),
    );
    await tester.enterText(find.byKey(const Key('card-count')), '1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('card-output')), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Card result');
  });

  testWidgets('GivenCanceledSave_WhenInvoked_ThenResultRemainsWithoutNotice', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChimeraApp(
        initialLocation: '/card/generate',
        cardService: _service('4242424242424242'),
        cardFileSaver: (_, _, _) async => false,
      ),
    );
    await tester.tap(find.byKey(const Key('card-generate')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('card-save')));
    await tester.tap(find.byKey(const Key('card-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card-output')), findsOneWidget);
    expect(find.byKey(const Key('card-notice')), findsNothing);
    expect(find.byKey(const Key('card-error')), findsNothing);
  });

  testWidgets(
    'GivenPendingGeneration_WhenDisposed_ThenLateCompletionIsIgnored',
    (tester) async {
      final service = _Pending();
      await tester.pumpWidget(
        ChimeraApp(initialLocation: '/card/generate', cardService: service),
      );
      await tester.tap(find.byKey(const Key('card-generate')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      service.pending.complete(_success('STALE'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('GivenHome_WhenOpened_ThenCardConfigurationIsAvailable', (
    tester,
  ) async {
    await tester.pumpWidget(const ChimeraApp());
    await tester.ensureVisible(find.byKey(const Key('open-card')));
    await tester.tap(find.byKey(const Key('open-card')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('card-network')), findsOneWidget);
    expect(find.byKey(const Key('card-count')), findsOneWidget);
  });
}

CardService _service(String value) =>
    CardService(generator: CardGenerator.forTesting(candidate: (_) => value));

ChimeraResult<CardOutput> _success(String value) => ChimeraSuccess(
  CardOutput(CardGenerationResult(values: [value], network: CardNetwork.visa)),
);

final class _Pending
    implements OperationService<CardOperationRequest, CardOutput> {
  final pending = Completer<ChimeraResult<CardOutput>>();

  @override
  Future<ChimeraResult<CardOutput>> execute(CardOperationRequest request) =>
      pending.future;
}
