import 'dart:async';
import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_gui/lorem_page.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}Defaults_WhenGeneratedCopiedSaved_ThenExactTextAndAccessibleResult',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          String? copied;
          List<int>? saved;
          await tester.pumpWidget(
            ChimeraApp(
              localeTag: locale,
              initialLocation: '/lorem/generate',
              loremClipboardWriter: (v) async {
                copied = v;
              },
              loremFileSaver: (name, bytes, mime) async {
                expect(name, 'chimera-lorem.txt');
                expect(mime, 'text/plain; charset=utf-8');
                saved = bytes;
                return true;
              },
            ),
          );
          expect(find.byKey(const Key('lorem-count')), findsOneWidget);
          await tester.tap(find.byKey(const Key('lorem-generate')));
          await tester.pumpAndSettle();
          const text =
              'Lorem ipsum dolor sit amet. Consectetur adipiscing elit.';
          expect(
            tester
                .widget<SelectableText>(find.byKey(const Key('lorem-output')))
                .data,
            text,
          );
          expect(
            tester
                .getSemantics(find.byKey(const Key('lorem-result')))
                .getSemanticsData()
                .label,
            contains(
              locale == 'en' ? 'Generated Lorem Ipsum' : 'Lorem Ipsum gerado',
            ),
          );
          expect(
            tester
                .getSemantics(find.byKey(const Key('lorem-result')))
                .getSemanticsData()
                .value,
            contains(text),
          );
          await tester.ensureVisible(find.byKey(const Key('lorem-copy')));
          await tester.tap(find.byKey(const Key('lorem-copy')));
          await tester.pumpAndSettle();
          expect(copied, text);
          await tester.ensureVisible(find.byKey(const Key('lorem-save')));
          await tester.tap(find.byKey(const Key('lorem-save')));
          await tester.pumpAndSettle();
          expect(saved, utf8.encode(text));
          await tester.enterText(find.byKey(const Key('lorem-count')), '0');
          await tester.pump();
          expect(find.byKey(const Key('lorem-output')), findsNothing);
          await tester.ensureVisible(find.byKey(const Key('lorem-generate')));
          await tester.tap(find.byKey(const Key('lorem-generate')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('lorem-error')), findsOneWidget);
          expect(find.byKey(const Key('lorem-copy')), findsNothing);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
  for (final boundary in ['copy', 'save', 'encode', 'resource']) {
    testWidgets(
      'Given${boundary}Failure_WhenActionRuns_ThenClearResultAndTypedError',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/lorem/generate',
            loremService: boundary == 'resource'
                ? const LoremService(
                    generator: LoremGenerator(maxOutputCharacters: 1),
                  )
                : const LoremService(),
            loremClipboardWriter: (_) async => throw StateError('PRIVATE'),
            loremFileSaver: (_, _, _) async => throw StateError('PRIVATE'),
            loremOutputEncoder: boundary == 'encode'
                ? (_) => throw OutOfMemoryError()
                : encodeLoremOutput,
          ),
        );
        await tester.tap(find.byKey(const Key('lorem-generate')));
        await tester.pumpAndSettle();
        if (boundary != 'resource') {
          final key = Key(boundary == 'copy' ? 'lorem-copy' : 'lorem-save');
          await tester.ensureVisible(find.byKey(key));
          await tester.tap(find.byKey(key));
          await tester.pumpAndSettle();
        }
        expect(find.byKey(const Key('lorem-output')), findsNothing);
        expect(find.byKey(const Key('lorem-error')), findsOneWidget);
        expect(find.textContaining('PRIVATE'), findsNothing);
      },
    );
  }
  testWidgets(
    'GivenPendingGeneration_WhenChangedOrDisposed_ThenIgnoreStaleCompletionAndPreventReentry',
    (tester) async {
      final service = _Pending();
      await tester.pumpWidget(
        ChimeraApp(initialLocation: '/lorem/generate', loremService: service),
      );
      await tester.tap(find.byKey(const Key('lorem-generate')));
      await tester.pump();
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('lorem-generate')))
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byKey(const Key('lorem-count')), '2');
      await tester.pump();
      service.pending.complete(
        const ChimeraSuccess(
          LoremOutput(LoremResult(unit: 'words', count: 1, text: 'STALE')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('STALE'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  for (final change in ['count', 'unit', 'dispose']) {
    for (final fails in [false, true]) {
      if (change == 'count' && !fails) continue;
      testWidgets(
        'Given$change${fails}PendingGeneration_WhenInvalidated_ThenIgnoreSuccessAndFailureAfterCompletion',
        (tester) async {
          final service = _Pending();
          await tester.pumpWidget(
            ChimeraApp(
              initialLocation: '/lorem/generate',
              loremService: service,
            ),
          );
          await tester.tap(find.byKey(const Key('lorem-generate')));
          await tester.pump();
          expect(
            tester
                .widget<ElevatedButton>(find.byKey(const Key('lorem-generate')))
                .onPressed,
            isNull,
          );
          if (change == 'count') {
            await tester.enterText(find.byKey(const Key('lorem-count')), '2');
          }
          if (change == 'unit') {
            await tester.tap(find.byKey(const Key('lorem-unit')));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Words').last);
            await tester.pumpAndSettle();
          }
          if (change == 'dispose') {
            await tester.pumpWidget(const SizedBox());
          }
          if (fails) {
            service.pending.completeError(OutOfMemoryError());
          } else {
            service.pending.complete(
              const ChimeraSuccess(
                LoremOutput(
                  LoremResult(unit: 'words', count: 1, text: 'STALE'),
                ),
              ),
            );
          }
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('lorem-output')), findsNothing);
          expect(find.byKey(const Key('lorem-error')), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final action in ['copy', 'save']) {
    for (final change in ['count', 'unit', 'dispose']) {
      for (final fails in [false, true]) {
        testWidgets(
          'Given$action$change${fails}Pending_WhenConfigurationChanges_ThenIgnoreCompletionAndDisableReentry',
          (tester) async {
            final copy = Completer<void>();
            final save = Completer<bool>();
            var calls = 0;
            await tester.pumpWidget(
              ChimeraApp(
                initialLocation: '/lorem/generate',
                loremClipboardWriter: (_) {
                  calls++;
                  return copy.future;
                },
                loremFileSaver: (_, _, _) {
                  calls++;
                  return save.future;
                },
              ),
            );
            await tester.tap(find.byKey(const Key('lorem-generate')));
            await tester.pumpAndSettle();
            final button = find.byKey(Key('lorem-$action'));
            await tester.ensureVisible(button);
            await tester.tap(button);
            await tester.pump();
            expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
            expect(
              tester
                  .widget<ElevatedButton>(
                    find.byKey(const Key('lorem-generate')),
                  )
                  .onPressed,
              isNull,
            );
            if (change == 'count') {
              await tester.enterText(find.byKey(const Key('lorem-count')), '2');
            }
            if (change == 'unit') {
              await tester.ensureVisible(find.byKey(const Key('lorem-unit')));
              await tester.tap(find.byKey(const Key('lorem-unit')));
              await tester.pumpAndSettle();
              await tester.tap(find.text('Words').last);
              await tester.pumpAndSettle();
            }
            if (change == 'dispose') {
              await tester.pumpWidget(const SizedBox());
            }
            if (action == 'copy') {
              if (fails) {
                copy.completeError(StateError('PRIVATE'));
              } else {
                copy.complete();
              }
            } else {
              if (fails) {
                save.completeError(StateError('PRIVATE'));
              } else {
                save.complete(true);
              }
            }
            await tester.pumpAndSettle();
            expect(calls, 1);
            expect(find.byKey(const Key('lorem-notice')), findsNothing);
            expect(find.byKey(const Key('lorem-error')), findsNothing);
            expect(find.byKey(const Key('lorem-output')), findsNothing);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
  testWidgets('GivenCanceledSave_WhenReturned_ThenKeepResultAndAllowRetry', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChimeraApp(
        initialLocation: '/lorem/generate',
        loremFileSaver: (_, _, _) async => false,
      ),
    );
    await tester.tap(find.byKey(const Key('lorem-generate')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('lorem-save')));
    await tester.tap(find.byKey(const Key('lorem-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lorem-output')), findsOneWidget);
    expect(find.byKey(const Key('lorem-notice')), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('lorem-save')))
          .onPressed,
      isNotNull,
    );
  });
  for (final unit in ['words', 'sentences']) {
    testWidgets(
      'Given${unit}Unit_WhenSelected_ThenInvalidateOldResultAndGenerateExactCount',
      (tester) async {
        await tester.pumpWidget(
          const ChimeraApp(initialLocation: '/lorem/generate'),
        );
        await tester.tap(find.byKey(const Key('lorem-generate')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('lorem-unit')));
        await tester.tap(find.byKey(const Key('lorem-unit')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(unit == 'words' ? 'Words' : 'Sentences').last,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('lorem-output')), findsNothing);
        await tester.enterText(find.byKey(const Key('lorem-count')), '3');
        await tester.tap(find.byKey(const Key('lorem-generate')));
        await tester.pumpAndSettle();
        final text = tester
            .widget<SelectableText>(find.byKey(const Key('lorem-output')))
            .data!;
        expect(
          unit == 'words'
              ? RegExp(r'\b[A-Za-z]+\b').allMatches(text).length
              : RegExp(r'[A-Z][^.?!]*[.?!]').allMatches(text).length,
          3,
        );
      },
    );
  }
  testWidgets('GivenHome_WhenOpened_ThenGeneratorHasOnlyConfiguration', (
    tester,
  ) async {
    await tester.pumpWidget(const ChimeraApp());
    await tester.ensureVisible(find.byKey(const Key('open-lorem')));
    await tester.tap(find.byKey(const Key('open-lorem')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lorem-unit')), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}

final class _Pending
    implements OperationService<LoremOperationRequest, LoremOutput> {
  final pending = Completer<ChimeraResult<LoremOutput>>();
  @override
  Future<ChimeraResult<LoremOutput>> execute(LoremOperationRequest request) =>
      pending.future;
}
