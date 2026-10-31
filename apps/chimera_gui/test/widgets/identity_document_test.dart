import 'dart:async';
import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_gui/identity_document_page.dart';
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
              initialLocation: '/document/generate',
              identityDocumentService: _service('219099999'),
              identityDocumentClipboardWriter: (value) async => copied = value,
              identityDocumentFileSaver: (name, bytes, mime) async {
                expect(name, 'chimera-synthetic-identity-documents.txt');
                expect(mime, 'text/plain; charset=utf-8');
                saved = bytes;
                return true;
              },
            ),
          );

          await tester.tap(find.byKey(const Key('identity-document-generate')));
          await tester.pumpAndSettle();
          final label = locale == 'en'
              ? 'Synthetic identity test data - not proof of issuance'
              : 'Dados sintéticos de identidade - não comprovam emissão oficial';
          expect(find.text(label), findsOneWidget);
          expect(
            tester
                .widget<SelectableText>(
                  find.byKey(const Key('identity-document-output')),
                )
                .data,
            '219-09-9999',
          );
          expect(
            tester
                .getSemantics(find.byKey(const Key('identity-document-result')))
                .getSemanticsData()
                .label,
            locale == 'en'
                ? 'Generated synthetic identity documents'
                : 'Documentos de identidade sintéticos gerados',
          );

          await tester.ensureVisible(
            find.byKey(const Key('identity-document-copy')),
          );
          await tester.tap(find.byKey(const Key('identity-document-copy')));
          await tester.pumpAndSettle();
          expect(copied, '$label\n219-09-9999');
          await tester.ensureVisible(
            find.byKey(const Key('identity-document-save')),
          );
          await tester.tap(find.byKey(const Key('identity-document-save')));
          await tester.pumpAndSettle();
          expect(saved, utf8.encode('$label\n219-09-9999'));
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'GivenLocaleAndTypeSelectors_WhenChanged_ThenCompatibleChoicesAndCnpjFormatAppear',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/document/generate',
          identityDocumentService: _service('12ABC34501DE35'),
        ),
      );
      expect(
        find.byKey(const Key('identity-document-cnpj-format')),
        findsNothing,
      );

      await _choose(tester, 'identity-document-locale', 'Brazil');
      await _choose(tester, 'identity-document-type', 'CNPJ');
      expect(
        find.byKey(const Key('identity-document-cnpj-format')),
        findsOneWidget,
      );
      await _choose(tester, 'identity-document-cnpj-format', 'Alphanumeric');
      await tester.tap(find.byKey(const Key('identity-document-generate')));
      await tester.pumpAndSettle();
      expect(find.text('12.ABC.345/01DE-35'), findsOneWidget);

      await tester.tap(find.byKey(const Key('identity-document-type')));
      await tester.pumpAndSettle();
      for (final value in ['CPF', 'CNPJ']) {
        expect(find.text(value), findsWidgets);
      }
      for (final value in [
        'Driver license number (CNH)',
        'National identity card number (CIN)',
      ]) {
        expect(find.text(value), findsWidgets);
      }
      expect(find.text('Social Security Number (SSN)'), findsNothing);
      await tester.tapAt(const Offset(1, 1));
      await tester.pumpAndSettle();

      await _choose(tester, 'identity-document-locale', 'United States');
      await tester.tap(find.byKey(const Key('identity-document-type')));
      await tester.pumpAndSettle();
      for (final value in [
        'Social Security Number (SSN)',
        'Individual Taxpayer Identification Number (ITIN)',
        'Employer Identification Number (EIN)',
      ]) {
        expect(find.text(value), findsWidgets);
      }
      expect(find.text('CPF'), findsNothing);
    },
  );

  testWidgets(
    'GivenConfigurationChanges_WhenResultExists_ThenEphemeralResultIsDiscarded',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/document/generate',
          identityDocumentService: _service('219099999'),
        ),
      );
      await tester.tap(find.byKey(const Key('identity-document-generate')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('identity-document-output')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('identity-document-count')),
        '2',
      );
      await tester.pump();
      expect(find.byKey(const Key('identity-document-output')), findsNothing);
    },
  );

  for (final failure in [
    'validation',
    'processing',
    'copy',
    'save',
    'encode',
  ]) {
    testWidgets(
      'Given${failure}Failure_WhenActionRuns_ThenNoPartialDocumentOrSecret',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/document/generate',
            identityDocumentService: failure == 'processing'
                ? IdentityDocumentService(
                    generator: IdentityDocumentGenerator.forTesting(
                      candidate: (_, _, _) =>
                          throw StateError('PRIVATE DOCUMENT'),
                    ),
                  )
                : _service('219099999'),
            identityDocumentClipboardWriter: (_) async =>
                throw StateError('PRIVATE DOCUMENT'),
            identityDocumentFileSaver: (_, _, _) async =>
                throw StateError('PRIVATE DOCUMENT'),
            identityDocumentOutputEncoder: failure == 'encode'
                ? (_) => throw OutOfMemoryError()
                : encodeIdentityDocumentOutput,
          ),
        );
        if (failure == 'validation') {
          await tester.enterText(
            find.byKey(const Key('identity-document-count')),
            '0',
          );
        }
        await tester.tap(find.byKey(const Key('identity-document-generate')));
        await tester.pumpAndSettle();
        if (failure == 'copy' || failure == 'save' || failure == 'encode') {
          final action = failure == 'copy' ? 'copy' : 'save';
          await tester.ensureVisible(
            find.byKey(Key('identity-document-$action')),
          );
          await tester.tap(find.byKey(Key('identity-document-$action')));
          await tester.pumpAndSettle();
        }
        expect(
          find.byKey(const Key('identity-document-error')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('identity-document-output')), findsNothing);
        expect(find.textContaining('PRIVATE'), findsNothing);
      },
    );
  }

  testWidgets(
    'GivenValidFirstDocumentThenRetryExhaustion_WhenGenerated_ThenNoPartialValue',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/document/generate',
          identityDocumentService: IdentityDocumentService(
            generator: IdentityDocumentGenerator.forTesting(
              candidate: (_, _, _) =>
                  ++attempts == 1 ? '219099999' : 'PRIVATE INVALID CANDIDATE',
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('identity-document-count')),
        '2',
      );
      await tester.tap(find.byKey(const Key('identity-document-generate')));
      await tester.pumpAndSettle();
      expect(attempts, 33);
      expect(find.byKey(const Key('identity-document-error')), findsOneWidget);
      expect(find.byKey(const Key('identity-document-output')), findsNothing);
      expect(find.textContaining('219-09-9999'), findsNothing);
      expect(find.textContaining('PRIVATE'), findsNothing);
    },
  );

  testWidgets(
    'GivenPendingGeneration_WhenConfigurationChanges_ThenLateCompletionIsIgnored',
    (tester) async {
      final service = _Pending();
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/document/generate',
          identityDocumentService: service,
        ),
      );
      await tester.tap(find.byKey(const Key('identity-document-generate')));
      await tester.pump();
      final button = tester.widget<ElevatedButton>(
        find.byKey(const Key('identity-document-generate')),
      );
      expect(button.onPressed, isNull);
      await tester.enterText(
        find.byKey(const Key('identity-document-count')),
        '2',
      );
      service.pending.complete(_success('219-09-9999'));
      await tester.pumpAndSettle();
      expect(find.text('219-09-9999'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('GivenKeyboardSubmission_WhenGenerated_ThenResultReceivesFocus', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChimeraApp(
        initialLocation: '/document/generate',
        identityDocumentService: _service('219099999'),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('identity-document-count')),
      '1',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('identity-document-output')), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'Identity document result',
    );
  });

  testWidgets('GivenCanceledSave_WhenInvoked_ThenResultRemainsWithoutNotice', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChimeraApp(
        initialLocation: '/document/generate',
        identityDocumentService: _service('219099999'),
        identityDocumentFileSaver: (_, _, _) async => false,
      ),
    );
    await tester.tap(find.byKey(const Key('identity-document-generate')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('identity-document-save')));
    await tester.tap(find.byKey(const Key('identity-document-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('identity-document-output')), findsOneWidget);
    expect(find.byKey(const Key('identity-document-notice')), findsNothing);
    expect(find.byKey(const Key('identity-document-error')), findsNothing);
  });

  testWidgets(
    'GivenNarrowViewport_WhenPageRendered_ThenContentRemainsScrollableWithoutOverflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/document/generate',
          identityDocumentService: _service('219099999'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GivenPendingGeneration_WhenDisposed_ThenLateCompletionIsIgnored',
    (tester) async {
      final service = _Pending();
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/document/generate',
          identityDocumentService: service,
        ),
      );
      await tester.tap(find.byKey(const Key('identity-document-generate')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      service.pending.complete(_success('219-09-9999'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final action in ['copy', 'save']) {
    for (final invalidation in ['dispose', 'configuration']) {
      testWidgets(
        'GivenPending${action}_When${invalidation}Invalidates_ThenLateCompletionIsIgnored',
        (tester) async {
          final clipboard = Completer<void>();
          final saver = Completer<bool>();
          await tester.pumpWidget(
            ChimeraApp(
              initialLocation: '/document/generate',
              identityDocumentService: _service('219099999'),
              identityDocumentClipboardWriter: (_) => clipboard.future,
              identityDocumentFileSaver: (_, _, _) => saver.future,
            ),
          );
          await tester.tap(find.byKey(const Key('identity-document-generate')));
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.byKey(Key('identity-document-$action')),
          );
          await tester.tap(find.byKey(Key('identity-document-$action')));
          await tester.pump();
          if (invalidation == 'dispose') {
            await tester.pumpWidget(const SizedBox());
          } else {
            await tester.ensureVisible(
              find.byKey(const Key('identity-document-count')),
            );
            await tester.enterText(
              find.byKey(const Key('identity-document-count')),
              '2',
            );
          }
          if (action == 'copy') {
            clipboard.complete();
          } else {
            saver.complete(true);
          }
          await tester.pumpAndSettle();

          if (invalidation == 'configuration') {
            expect(
              find.byKey(const Key('identity-document-output')),
              findsNothing,
            );
            expect(
              find.byKey(const Key('identity-document-notice')),
              findsNothing,
            );
            expect(
              find.byKey(const Key('identity-document-error')),
              findsNothing,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('GivenHome_WhenOpened_ThenDocumentConfigurationIsAvailable', (
    tester,
  ) async {
    await tester.pumpWidget(const ChimeraApp());
    await tester.ensureVisible(find.byKey(const Key('open-identity-document')));
    await tester.tap(find.byKey(const Key('open-identity-document')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('identity-document-locale')), findsOneWidget);
    expect(find.byKey(const Key('identity-document-type')), findsOneWidget);
    expect(find.byKey(const Key('identity-document-count')), findsOneWidget);
  });
}

Future<void> _choose(WidgetTester tester, String key, String label) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

IdentityDocumentService _service(String value) => IdentityDocumentService(
  generator: IdentityDocumentGenerator.forTesting(
    candidate: (_, _, _) => value,
  ),
);

ChimeraResult<IdentityDocumentOutput> _success(String value) => ChimeraSuccess(
  IdentityDocumentOutput(
    IdentityDocumentResult(
      values: [value],
      locale: IdentityLocale.us,
      type: IdentityDocumentType.ssn,
      cnpjFormat: CnpjFormat.alphanumeric,
    ),
  ),
);

final class _Pending
    implements
        OperationService<
          IdentityDocumentOperationRequest,
          IdentityDocumentOutput
        > {
  final pending = Completer<ChimeraResult<IdentityDocumentOutput>>();

  @override
  Future<ChimeraResult<IdentityDocumentOutput>> execute(
    IdentityDocumentOperationRequest request,
  ) => pending.future;
}
