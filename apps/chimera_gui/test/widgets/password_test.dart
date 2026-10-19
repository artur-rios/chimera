import 'dart:async';
import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_gui/password_page.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PasswordService deterministic() =>
      PasswordService(generator: _coveringGenerator());

  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}Defaults_WhenGeneratedCopiedSaved_ThenExactEphemeralPassword',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          String? copied;
          List<int>? saved;
          await tester.pumpWidget(
            ChimeraApp(
              localeTag: locale,
              initialLocation: '/password/generate',
              passwordService: deterministic(),
              passwordClipboardWriter: (value) async {
                copied = value;
              },
              passwordFileSaver: (name, bytes, mime) async {
                expect(name, 'chimera-password.txt');
                expect(mime, 'text/plain; charset=utf-8');
                saved = bytes;
                return true;
              },
            ),
          );

          await tester.tap(find.byKey(const Key('password-generate')));
          await tester.pumpAndSettle();
          final password = tester
              .widget<SelectableText>(find.byKey(const Key('password-output')))
              .data!;
          expect(password, hasLength(16));
          expect(password, matches(RegExp('[a-z]')));
          expect(password, matches(RegExp('[A-Z]')));
          expect(password, matches(RegExp('[0-9]')));
          expect(
            tester
                .getSemantics(find.byKey(const Key('password-result')))
                .getSemanticsData()
                .label,
            locale == 'en' ? 'Generated password' : 'Senha gerada',
          );

          await tester.ensureVisible(find.byKey(const Key('password-copy')));
          await tester.tap(find.byKey(const Key('password-copy')));
          await tester.pumpAndSettle();
          expect(copied, password);
          await tester.ensureVisible(find.byKey(const Key('password-save')));
          await tester.tap(find.byKey(const Key('password-save')));
          await tester.pumpAndSettle();
          expect(saved, utf8.encode(password));

          await tester.enterText(
            find.byKey(const Key('password-length')),
            '20',
          );
          await tester.pump();
          expect(find.byKey(const Key('password-output')), findsNothing);
          expect(find.byKey(const Key('password-copy')), findsNothing);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets('GivenOnlyDigits_WhenGenerated_ThenSelectionIsHonored', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChimeraApp(
        initialLocation: '/password/generate',
        passwordService: deterministic(),
      ),
    );
    for (final key in ['lowercase', 'uppercase', 'symbols']) {
      await tester.tap(find.byKey(Key('password-$key')));
      await tester.pump();
    }
    await tester.enterText(find.byKey(const Key('password-length')), '4');
    await tester.tap(find.byKey(const Key('password-generate')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<SelectableText>(find.byKey(const Key('password-output')))
          .data,
      '0622',
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
      'Given${failure}Failure_WhenActionRuns_ThenNoPartialPasswordOrSecretDiagnostic',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/password/generate',
            passwordService: failure == 'processing'
                ? PasswordService(
                    generator: PasswordGenerator.forTesting(
                      randomInt: (_) => throw StateError('PRIVATE'),
                    ),
                  )
                : deterministic(),
            passwordClipboardWriter: (_) async => throw StateError('PRIVATE'),
            passwordFileSaver: (_, _, _) async => throw StateError('PRIVATE'),
            passwordOutputEncoder: failure == 'encode'
                ? (_) => throw OutOfMemoryError()
                : encodePasswordOutput,
          ),
        );
        if (failure == 'validation') {
          await tester.enterText(find.byKey(const Key('password-length')), '3');
        }
        await tester.tap(find.byKey(const Key('password-generate')));
        await tester.pumpAndSettle();
        if (failure == 'copy' || failure == 'save' || failure == 'encode') {
          final action = failure == 'copy' ? 'copy' : 'save';
          await tester.ensureVisible(find.byKey(Key('password-$action')));
          await tester.tap(find.byKey(Key('password-$action')));
          await tester.pumpAndSettle();
        }

        expect(find.byKey(const Key('password-error')), findsOneWidget);
        expect(find.byKey(const Key('password-output')), findsNothing);
        expect(find.textContaining('PRIVATE'), findsNothing);
      },
    );
  }

  testWidgets(
    'GivenPendingGeneration_WhenConfigurationChanges_ThenIgnoreCompletionAndPreventReentry',
    (tester) async {
      final service = _Pending();
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/password/generate',
          passwordService: service,
        ),
      );
      await tester.tap(find.byKey(const Key('password-generate')));
      await tester.pump();
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('password-generate')))
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byKey(const Key('password-length')), '20');
      service.pending.complete(
        const ChimeraSuccess(
          PasswordOutput(
            PasswordResult(
              password: 'STALE',
              length: 5,
              characterClasses: ['uppercase'],
            ),
          ),
        ),
      );
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
        initialLocation: '/password/generate',
        passwordService: deterministic(),
      ),
    );
    await tester.enterText(find.byKey(const Key('password-length')), '16');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('password-output')), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Password result');
  });

  testWidgets('GivenCanceledSave_WhenInvoked_ThenResultRemainsWithoutNotice', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChimeraApp(
        initialLocation: '/password/generate',
        passwordService: deterministic(),
        passwordFileSaver: (_, _, _) async => false,
      ),
    );
    await tester.tap(find.byKey(const Key('password-generate')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('password-save')));
    await tester.tap(find.byKey(const Key('password-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('password-output')), findsOneWidget);
    expect(find.byKey(const Key('password-notice')), findsNothing);
    expect(find.byKey(const Key('password-error')), findsNothing);
  });

  testWidgets(
    'GivenPendingGeneration_WhenDisposed_ThenLateCompletionIsIgnored',
    (tester) async {
      final service = _Pending();
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/password/generate',
          passwordService: service,
        ),
      );
      await tester.tap(find.byKey(const Key('password-generate')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      service.pending.complete(_success());
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
            initialLocation: '/password/generate',
            passwordService: deterministic(),
            passwordClipboardWriter: (_) => clipboard.future,
            passwordFileSaver: (_, _, _) => saver.future,
          ),
        );
        await tester.tap(find.byKey(const Key('password-generate')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(Key('password-$action')));
        await tester.tap(find.byKey(Key('password-$action')));
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
            initialLocation: '/password/generate',
            passwordService: deterministic(),
            passwordClipboardWriter: (_) => clipboard.future,
            passwordFileSaver: (_, _, _) => saver.future,
          ),
        );
        await tester.tap(find.byKey(const Key('password-generate')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(Key('password-$action')));
        await tester.tap(find.byKey(Key('password-$action')));
        await tester.pump();
        await tester.enterText(find.byKey(const Key('password-length')), '20');
        if (action == 'copy') {
          clipboard.complete();
        } else {
          saver.complete(true);
        }
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('password-output')), findsNothing);
        expect(find.byKey(const Key('password-notice')), findsNothing);
        expect(find.byKey(const Key('password-error')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('GivenHome_WhenOpened_ThenPasswordConfigurationIsAvailable', (
    tester,
  ) async {
    await tester.pumpWidget(const ChimeraApp());
    await tester.ensureVisible(find.byKey(const Key('open-password')));
    await tester.tap(find.byKey(const Key('open-password')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('password-length')), findsOneWidget);
    expect(find.byKey(const Key('password-lowercase')), findsOneWidget);
    expect(find.byKey(const Key('password-uppercase')), findsOneWidget);
    expect(find.byKey(const Key('password-digits')), findsOneWidget);
    expect(find.byKey(const Key('password-symbols')), findsOneWidget);
  });
}

const _passwordResult = PasswordResult(
  password: 'aA0!',
  length: 4,
  characterClasses: ['lowercase', 'uppercase', 'digits', 'symbols'],
);

ChimeraResult<PasswordOutput> _success() =>
    const ChimeraSuccess(PasswordOutput(_passwordResult));

PasswordGenerator _coveringGenerator() {
  const draws = <int>[0, 26, 52, 62];
  var index = 0;
  return PasswordGenerator.forTesting(
    randomInt: (upperBound) => draws[index++ % draws.length] % upperBound,
  );
}

final class _Pending
    implements OperationService<PasswordOperationRequest, PasswordOutput> {
  final pending = Completer<ChimeraResult<PasswordOutput>>();

  @override
  Future<ChimeraResult<PasswordOutput>> execute(
    PasswordOperationRequest request,
  ) => pending.future;
}
