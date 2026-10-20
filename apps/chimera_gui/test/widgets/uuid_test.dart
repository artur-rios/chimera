import 'dart:async';
import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_gui/uuid_page.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}Defaults_WhenGeneratedCopiedSaved_ThenExactEphemeralUuid',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          String? copied;
          List<int>? saved;
          await tester.pumpWidget(
            ChimeraApp(
              localeTag: locale,
              initialLocation: '/uuid/generate',
              uuidService: _service(),
              uuidClipboardWriter: (value) async => copied = value,
              uuidFileSaver: (name, bytes, mime) async {
                expect(name, 'chimera-identifiers.txt');
                expect(mime, 'text/plain; charset=utf-8');
                saved = bytes;
                return true;
              },
            ),
          );

          await tester.tap(find.byKey(const Key('uuid-generate')));
          await tester.pumpAndSettle();
          const expected = '00000000-0000-4000-8000-000000000000';
          expect(
            tester
                .widget<SelectableText>(find.byKey(const Key('uuid-output')))
                .data,
            expected,
          );
          expect(
            tester
                .getSemantics(find.byKey(const Key('uuid-result')))
                .getSemanticsData()
                .label,
            locale == 'en'
                ? 'Generated identifiers'
                : 'Identificadores gerados',
          );

          await tester.ensureVisible(find.byKey(const Key('uuid-copy')));
          await tester.tap(find.byKey(const Key('uuid-copy')));
          await tester.pumpAndSettle();
          expect(copied, expected);
          await tester.ensureVisible(find.byKey(const Key('uuid-save')));
          await tester.tap(find.byKey(const Key('uuid-save')));
          await tester.pumpAndSettle();
          expect(saved, utf8.encode(expected));

          await tester.enterText(find.byKey(const Key('uuid-count')), '2');
          await tester.pump();
          expect(find.byKey(const Key('uuid-output')), findsNothing);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets('GivenV7GuidCountTwo_WhenGenerated_ThenSelectionIsHonored', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChimeraApp(initialLocation: '/uuid/generate', uuidService: _service()),
    );
    await tester.tap(find.byKey(const Key('uuid-version')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Version 7 (time ordered)').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('uuid-representation')));
    await tester.tap(find.byKey(const Key('uuid-representation')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GUID (uppercase braces)').last);
    await tester.enterText(find.byKey(const Key('uuid-count')), '2');
    await tester.tap(find.byKey(const Key('uuid-generate')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<SelectableText>(find.byKey(const Key('uuid-output'))).data,
      '{01234567-89AB-7000-8000-000000000000}\n{01234567-89AB-7101-8101-010101010101}',
    );
  });

  for (final failure in [
    'validation',
    'processing',
    'copy',
    'save',
    'encode',
  ]) {
    testWidgets(
      'Given${failure}Failure_WhenActionRuns_ThenNoPartialIdentifiersOrSecret',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/uuid/generate',
            uuidService: failure == 'processing'
                ? UuidService(
                    generator: UuidGenerator.forTesting(
                      randomBytes: () => throw StateError('PRIVATE'),
                      nowMilliseconds: () => 0,
                    ),
                  )
                : _service(),
            uuidClipboardWriter: (_) async => throw StateError('PRIVATE'),
            uuidFileSaver: (_, _, _) async => throw StateError('PRIVATE'),
            uuidOutputEncoder: failure == 'encode'
                ? (_) => throw OutOfMemoryError()
                : encodeUuidOutput,
          ),
        );
        if (failure == 'validation') {
          await tester.enterText(find.byKey(const Key('uuid-count')), '0');
        }
        await tester.tap(find.byKey(const Key('uuid-generate')));
        await tester.pumpAndSettle();
        if (failure == 'copy' || failure == 'save' || failure == 'encode') {
          final action = failure == 'copy' ? 'copy' : 'save';
          await tester.ensureVisible(find.byKey(Key('uuid-$action')));
          await tester.tap(find.byKey(Key('uuid-$action')));
          await tester.pumpAndSettle();
        }

        expect(find.byKey(const Key('uuid-error')), findsOneWidget);
        expect(find.byKey(const Key('uuid-output')), findsNothing);
        expect(find.textContaining('PRIVATE'), findsNothing);
      },
    );
  }

  testWidgets(
    'GivenPendingGeneration_WhenConfigurationChanges_ThenLateCompletionIsIgnored',
    (tester) async {
      final service = _Pending();
      await tester.pumpWidget(
        ChimeraApp(initialLocation: '/uuid/generate', uuidService: service),
      );
      await tester.tap(find.byKey(const Key('uuid-generate')));
      await tester.pump();
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('uuid-generate')))
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byKey(const Key('uuid-count')), '2');
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
      ChimeraApp(initialLocation: '/uuid/generate', uuidService: _service()),
    );
    await tester.enterText(find.byKey(const Key('uuid-count')), '1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('uuid-output')), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'UUID result');
  });

  testWidgets('GivenCanceledSave_WhenInvoked_ThenResultRemainsWithoutNotice', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChimeraApp(
        initialLocation: '/uuid/generate',
        uuidService: _service(),
        uuidFileSaver: (_, _, _) async => false,
      ),
    );
    await tester.tap(find.byKey(const Key('uuid-generate')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('uuid-save')));
    await tester.tap(find.byKey(const Key('uuid-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('uuid-output')), findsOneWidget);
    expect(find.byKey(const Key('uuid-notice')), findsNothing);
    expect(find.byKey(const Key('uuid-error')), findsNothing);
  });

  testWidgets(
    'GivenPendingGeneration_WhenDisposed_ThenLateCompletionIsIgnored',
    (tester) async {
      final service = _Pending();
      await tester.pumpWidget(
        ChimeraApp(initialLocation: '/uuid/generate', uuidService: service),
      );
      await tester.tap(find.byKey(const Key('uuid-generate')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      service.pending.complete(_success('STALE'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  for (final action in ['copy', 'save']) {
    testWidgets(
      'GivenPending${action}_WhenDisposed_ThenLateCompletionIsIgnored',
      (tester) async {
        final clipboard = Completer<void>();
        final saver = Completer<bool>();
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/uuid/generate',
            uuidService: _service(),
            uuidClipboardWriter: (_) => clipboard.future,
            uuidFileSaver: (_, _, _) => saver.future,
          ),
        );
        await tester.tap(find.byKey(const Key('uuid-generate')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(Key('uuid-$action')));
        await tester.tap(find.byKey(Key('uuid-$action')));
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
        if (action == 'copy') {
          clipboard.complete();
        } else {
          saver.complete(true);
        }
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'GivenPending${action}_WhenConfigurationChanges_ThenLateCompletionIsIgnored',
      (tester) async {
        final clipboard = Completer<void>();
        final saver = Completer<bool>();
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/uuid/generate',
            uuidService: _service(),
            uuidClipboardWriter: (_) => clipboard.future,
            uuidFileSaver: (_, _, _) => saver.future,
          ),
        );
        await tester.tap(find.byKey(const Key('uuid-generate')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(Key('uuid-$action')));
        await tester.tap(find.byKey(Key('uuid-$action')));
        await tester.pump();
        await tester.ensureVisible(find.byKey(const Key('uuid-count')));
        await tester.enterText(find.byKey(const Key('uuid-count')), '2');
        if (action == 'copy') {
          clipboard.complete();
        } else {
          saver.complete(true);
        }
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('uuid-output')), findsNothing);
        expect(find.byKey(const Key('uuid-notice')), findsNothing);
        expect(find.byKey(const Key('uuid-error')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final action in ['copy', 'save']) {
    for (final invalidation in ['dispose', 'configuration']) {
      testWidgets(
        'GivenPending${action}Failure_When${invalidation}Invalidates_ThenLateFailureIsIgnored',
        (tester) async {
          final clipboard = Completer<void>();
          final saver = Completer<bool>();
          await tester.pumpWidget(
            ChimeraApp(
              initialLocation: '/uuid/generate',
              uuidService: _service(),
              uuidClipboardWriter: (_) => clipboard.future,
              uuidFileSaver: (_, _, _) => saver.future,
            ),
          );
          await tester.tap(find.byKey(const Key('uuid-generate')));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(Key('uuid-$action')));
          await tester.tap(find.byKey(Key('uuid-$action')));
          await tester.pump();
          if (invalidation == 'dispose') {
            await tester.pumpWidget(const SizedBox());
          } else {
            await tester.ensureVisible(find.byKey(const Key('uuid-count')));
            await tester.enterText(find.byKey(const Key('uuid-count')), '2');
          }
          if (action == 'copy') {
            clipboard.completeError(StateError('PRIVATE'));
          } else {
            saver.completeError(StateError('PRIVATE'));
          }
          await tester.pumpAndSettle();

          if (invalidation == 'configuration') {
            expect(find.byKey(const Key('uuid-output')), findsNothing);
            expect(find.byKey(const Key('uuid-notice')), findsNothing);
            expect(find.byKey(const Key('uuid-error')), findsNothing);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('GivenHome_WhenOpened_ThenUuidConfigurationIsAvailable', (
    tester,
  ) async {
    await tester.pumpWidget(const ChimeraApp());
    await tester.ensureVisible(find.byKey(const Key('open-uuid')));
    await tester.tap(find.byKey(const Key('open-uuid')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('uuid-version')), findsOneWidget);
    expect(find.byKey(const Key('uuid-representation')), findsOneWidget);
    expect(find.byKey(const Key('uuid-count')), findsOneWidget);
  });
}

UuidService _service() {
  var call = 0;
  return UuidService(
    generator: UuidGenerator.forTesting(
      randomBytes: () => List<int>.filled(16, call++),
      nowMilliseconds: () => 0x0123456789ab,
    ),
  );
}

ChimeraResult<UuidOutput> _success(String value) => ChimeraSuccess(
  UuidOutput(
    UuidGenerationResult(
      values: [value],
      version: UuidVersion.v4,
      representation: UuidRepresentation.uuid,
    ),
  ),
);

final class _Pending
    implements OperationService<UuidOperationRequest, UuidOutput> {
  final pending = Completer<ChimeraResult<UuidOutput>>();

  @override
  Future<ChimeraResult<UuidOutput>> execute(UuidOperationRequest request) =>
      pending.future;
}
