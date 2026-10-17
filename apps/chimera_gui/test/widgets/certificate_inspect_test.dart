import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _prefix = 'certificate-inspect-';
Finder _control(String name) => find.byKey(Key('$_prefix$name'));
String _fixture(String extension) =>
    File('../../tests/fixtures/certificates/certificate.$extension')
        .readAsStringSync();
List<int> _der() =>
    File('../../tests/fixtures/certificates/certificate.der').readAsBytesSync();

Future<void> _tap(WidgetTester tester, String name) async {
  await tester.ensureVisible(_control(name));
  await tester.tap(_control(name));
  await tester.pumpAndSettle();
}

Future<void> _inspect(WidgetTester tester, [String? text]) async {
  if (text != null) await tester.enterText(_control('input'), text);
  await _tap(tester, 'submit');
}

void _noSuccess(WidgetTester tester) {
  expect(_control('result'), findsNothing);
  expect(_control('copy'), findsNothing);
  expect(_control('notice'), findsNothing);
}

void _noSource(WidgetTester tester) {
  expect(tester.widget<TextField>(_control('input')).controller!.text, isEmpty);
  expect(_control('file-summary'), findsNothing);
}

// This literal is pinned by the independently checked public fixture manifest.
const _pemJson =
    '{"representation":"pem","version":3,"serialNumberHex":"01AB",'
    '"subject":[{"oid":"2.5.4.3","name":"commonName","value":"example.test"},'
    '{"oid":"2.5.4.10","name":"organizationName","value":"Chimera fixtures"},'
    '{"oid":"1.2.3.4","name":null,"value":"Unknown attribute"}],'
    '"issuer":[{"oid":"2.5.4.3","name":"commonName","value":"Example CA"},'
    '{"oid":"2.5.4.10","name":"organizationName","value":"Chimera fixtures"}],'
    '"notBefore":"2024-01-01T00:00:00.000Z",'
    '"notAfter":"2034-01-01T00:00:00.000Z",'
    '"signatureAlgorithm":{"oid":"1.2.840.113549.1.1.11",'
    '"name":"sha256WithRSAEncryption"},'
    '"publicKeyAlgorithm":{"oid":"1.2.840.113549.1.1.1","name":"rsaEncryption"},'
    '"extensions":[{"oid":"2.5.29.19","name":"basicConstraints","critical":true},'
    '{"oid":"1.2.3.5","name":null,"critical":false}],'
    '"inputByteCount":778,"derByteCount":534}';

final class _DelayedInspection
    implements
        OperationService<
          CertificateInspectOperationRequest,
          CertificateInspectOutput
        > {
  final completer = Completer<ChimeraResult<CertificateInspectOutput>>();

  @override
  Future<ChimeraResult<CertificateInspectOutput>> execute(
    CertificateInspectOperationRequest request,
  ) => completer.future;
}

void main() {
  group('certificate inspect', () {
    for (final source in ['text', 'file', 'clipboard']) {
      for (final representation in CertificateInputRepresentation.values) {
        testWidgets(
          'Given${source}_${representation.name}_WhenInspected_ThenExactMetadataIsCopied',
          (tester) async {
            String? copied;
            final format = representation == CertificateInputRepresentation.der
                ? 'der'
                : representation == CertificateInputRepresentation.base64
                ? 'base64'
                : 'pem';
            await tester.pumpWidget(
              ChimeraApp(
                initialLocation: '/certificate/inspect',
                certificateInspectFilePicker: () async =>
                    format == 'der' ? _der() : utf8.encode(_fixture(format)),
                certificateInspectClipboardReader: () async =>
                    _fixture(format == 'der' ? 'pem' : format),
                certificateInspectClipboardWriter: (value) async =>
                    copied = value,
              ),
            );
            await tester.pumpAndSettle();
            await _tap(tester, 'representation-${representation.name}');
            if (source == 'text') {
              await tester.enterText(
                _control('input'),
                _fixture(format == 'der' ? 'pem' : format),
              );
            } else {
              await _tap(tester, source == 'file' ? 'file' : 'paste');
            }
            await _inspect(tester);
            if (format == 'der' && source != 'file') {
              expect(
                find.text('The certificate inspection request is invalid.'),
                findsOneWidget,
              );
              _noSuccess(tester);
              _noSource(tester);
              return;
            }
            final metadata = tester
                .widget<SelectableText>(_control('result'))
                .data!;
            for (final value in [
              '01AB',
              'example.test',
              'Example CA',
              '1.2.3.4',
              'Unknown attribute',
              '2024-01-01T00:00:00.000Z',
              '2034-01-01T00:00:00.000Z',
              'sha256WithRSAEncryption',
              'rsaEncryption',
              '1.2.3.5',
              '534',
            ]) {
              expect(metadata, contains(value));
            }
            await _tap(tester, 'copy');
            final byteCount = format == 'pem'
                ? 778
                : format == 'der'
                ? 534
                : 713;
            expect(
              copied,
              _pemJson
                  .replaceFirst('"pem"', '"$format"')
                  .replaceFirst(
                    '"inputByteCount":778',
                    '"inputByteCount":$byteCount',
                  ),
            );
            expect(find.byIcon(Icons.save_alt), findsNothing);
          },
        );
      }
    }

    testWidgets(
      'GivenSourcesAndRepresentation_WhenChanged_ThenOldSuccessIsCleared',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/certificate/inspect',
            certificateInspectFilePicker: () async => _der(),
            certificateInspectClipboardReader: () async => _fixture('pem'),
            certificateInspectClipboardWriter: (_) async {},
          ),
        );
        await tester.pumpAndSettle();
        await _inspect(tester, _fixture('pem'));
        await _tap(tester, 'copy');
        await _tap(tester, 'file');
        _noSuccess(tester);
        expect(
          tester.widget<TextField>(_control('input')).controller!.text,
          isEmpty,
        );
        expect(_control('file-summary'), findsOneWidget);
        await _inspect(tester);
        await _tap(tester, 'paste');
        _noSuccess(tester);
        expect(_control('file-summary'), findsNothing);
        expect(
          tester.widget<TextField>(_control('input')).controller!.text,
          _fixture('pem'),
        );
        await _inspect(tester);
        await tester.enterText(_control('input'), _fixture('base64'));
        await tester.pump();
        _noSuccess(tester);
        await _inspect(tester);
        await _tap(tester, 'representation-pem');
        _noSuccess(tester);
        await _inspect(tester);
        expect(
          find.text('The certificate inspection request is invalid.'),
          findsOneWidget,
        );
        _noSource(tester);
      },
    );

    for (final invalid in [
      '',
      'not a certificate',
      '-----BEGIN PRIVATE KEY-----\nsecret\n-----END PRIVATE KEY-----',
      '${_fixture('pem')}${_fixture('pem')}',
    ]) {
      final index = ['', 'not a certificate'].indexOf(invalid);
      testWidgets(
        'GivenMalformedOrUnsupported${invalid.length}_${index}_WhenInspected_ThenFailureClearsSuccess',
        (tester) async {
          await tester.pumpWidget(
            const ChimeraApp(initialLocation: '/certificate/inspect'),
          );
          await tester.pumpAndSettle();
          await _inspect(tester, _fixture('pem'));
          await _inspect(tester, invalid);
          _noSuccess(tester);
          _noSource(tester);
          expect(
            find.text('The certificate inspection request is invalid.'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final action in ['file', 'paste', 'copy']) {
      for (final allocation in [false, true]) {
        testWidgets(
          'Given${action}Failure_${allocation}_WhenActionRuns_ThenRedactedFailureClearsSourcesAndResult',
          (tester) async {
            Never fail() => allocation
                ? throw OutOfMemoryError()
                : throw StateError(
                    'SENSITIVE example.test /private/certificate.pem',
                  );
            await tester.pumpWidget(
              ChimeraApp(
                initialLocation: '/certificate/inspect',
                certificateInspectFilePicker: () async => fail(),
                certificateInspectClipboardReader: () async => fail(),
                certificateInspectClipboardWriter: (_) async => fail(),
              ),
            );
            await tester.pumpAndSettle();
            await _inspect(tester, _fixture('pem'));
            await _tap(tester, action);
            _noSuccess(tester);
            _noSource(tester);
            final message = tester.widget<Text>(_control('error')).data!;
            expect(
              message,
              allocation
                  ? 'Certificate inspection exceeded its resource limit.'
                  : action == 'file'
                  ? 'The input file could not be read.'
                  : action == 'paste'
                  ? 'The clipboard could not be read.'
                  : 'The certificate JSON could not be copied.',
            );
            final semantics = tester
                .getSemantics(_control('error'))
                .getSemanticsData();
            expect(
              '${semantics.label}${semantics.value}',
              isNot(contains('example.test')),
            );
            expect(message, isNot(contains('SENSITIVE')));
            expect(
              tester.widget<ElevatedButton>(_control('submit')).onPressed,
              isNotNull,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    for (final source in ['file', 'paste']) {
      testWidgets(
        'GivenCancelled${source}_WhenLoadedAfterSuccess_ThenOldSourceIsNotReusable',
        (tester) async {
          await tester.pumpWidget(
            ChimeraApp(
              initialLocation: '/certificate/inspect',
              certificateInspectFilePicker: () async => null,
              certificateInspectClipboardReader: () async => null,
            ),
          );
          await tester.pumpAndSettle();
          await _inspect(tester, _fixture('pem'));
          await _tap(tester, source);
          _noSuccess(tester);
          _noSource(tester);
          await _inspect(tester);
          expect(_control('error'), findsOneWidget);
        },
      );
    }

    testWidgets(
      'GivenResourceLimit_WhenInspected_ThenLocalizedFailureClearsSource',
      (tester) async {
        await tester.pumpWidget(
          const ChimeraApp(
            initialLocation: '/certificate/inspect',
            localeTag: 'pt-BR',
            certificateInspectService: CertificateInspectService(
              inspector: CertificateInspector(maxInputBytes: 1),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _inspect(tester, _fixture('pem'));
        expect(
          find.text('A inspeção do certificado excedeu o limite de recursos.'),
          findsOneWidget,
        );
        _noSuccess(tester);
        _noSource(tester);
      },
    );

    for (final action in ['file', 'paste', 'copy', 'submit']) {
      testWidgets(
        'GivenPending${action}_WhenPageDisposes_ThenCompletionIsIgnored',
        (tester) async {
          final bytes = Completer<List<int>?>();
          final text = Completer<String?>();
          final copied = Completer<void>();
          final service = _DelayedInspection();
          await tester.pumpWidget(
            ChimeraApp(
              initialLocation: '/certificate/inspect',
              certificateInspectFilePicker: () => bytes.future,
              certificateInspectClipboardReader: () => text.future,
              certificateInspectClipboardWriter: (_) => copied.future,
              certificateInspectService: action == 'submit'
                  ? service
                  : const CertificateInspectService(),
            ),
          );
          await tester.pumpAndSettle();
          if (action == 'copy') await _inspect(tester, _fixture('pem'));
          await tester.ensureVisible(_control(action));
          await tester.tap(_control(action));
          await tester.pump();
          expect(tester.widget<TextField>(_control('input')).enabled, isFalse);
          for (final button in ['file', 'paste']) {
            expect(
              tester.widget<OutlinedButton>(_control(button)).onPressed,
              isNull,
            );
          }
          expect(
            tester.widget<ElevatedButton>(_control('submit')).onPressed,
            isNull,
          );
          for (final representation in CertificateInputRepresentation.values) {
            expect(
              tester
                  .widget<ChoiceChip>(
                    _control('representation-${representation.name}'),
                  )
                  .onSelected,
              isNull,
            );
          }
          await tester.pumpWidget(const SizedBox());
          bytes.complete(_der());
          text.complete(_fixture('pem'));
          copied.complete();
          service.completer.complete(
            await const CertificateInspectService().execute(
              CertificateInspectOperationRequest.fromText(_fixture('pem')),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(_control('result'), findsNothing);
        },
      );
    }

    testWidgets(
      'GivenStaleSourceCompletion_WhenNewSourceSupersedesIt_ThenItCannotRestoreSuccess',
      (tester) async {
        final pending = Completer<List<int>?>();
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/certificate/inspect',
            certificateInspectFilePicker: () => pending.future,
          ),
        );
        await tester.pumpAndSettle();
        // Retain an event callback already queued before busy controls rebuild.
        final change = tester.widget<TextField>(_control('input')).onChanged!;
        await tester.tap(_control('file'));
        await tester.pump();
        change('');
        await tester.pump();
        await tester.enterText(_control('input'), _fixture('base64'));
        await _inspect(tester);
        pending.complete(_der());
        await tester.pumpAndSettle();
        expect(_control('file-summary'), findsNothing);
        expect(
          tester.widget<SelectableText>(_control('result')).data,
          contains('Representation: Base64'),
        );
      },
    );

    for (final action in ['file', 'paste', 'copy', 'submit']) {
      for (final failed in [false, true]) {
        testWidgets(
          'GivenStale${action}_${failed}_WhenRepresentationSupersedesIt_ThenResultAndSourceStayCleared',
          (tester) async {
            final bytes = Completer<List<int>?>();
            final text = Completer<String?>();
            final copied = Completer<void>();
            final service = _DelayedInspection();
            await tester.pumpWidget(
              ChimeraApp(
                initialLocation: '/certificate/inspect',
                certificateInspectFilePicker: () => bytes.future,
                certificateInspectClipboardReader: () => text.future,
                certificateInspectClipboardWriter: (_) => copied.future,
                certificateInspectService: action == 'submit'
                    ? service
                    : const CertificateInspectService(),
              ),
            );
            await tester.pumpAndSettle();
            if (action == 'copy') await _inspect(tester, _fixture('pem'));
            final changeSource = tester
                .widget<TextField>(_control('input'))
                .onChanged!;
            final changeRepresentation = tester
                .widget<ChoiceChip>(_control('representation-base64'))
                .onSelected!;
            await tester.ensureVisible(_control(action));
            await tester.tap(_control(action));
            await tester.pump();
            changeSource('');
            changeRepresentation(true);
            await tester.pump();
            // Simulate a queued edit that invalidated the in-flight operation.
            await tester.enterText(_control('input'), '');
            await tester.pump();
            if (failed) {
              final error = StateError('SENSITIVE stale certificate');
              switch (action) {
                case 'file':
                  bytes.completeError(error);
                case 'paste':
                  text.completeError(error);
                case 'copy':
                  copied.completeError(error);
                case 'submit':
                  service.completer.completeError(error);
              }
            } else {
              switch (action) {
                case 'file':
                  bytes.complete(_der());
                case 'paste':
                  text.complete(_fixture('pem'));
                case 'copy':
                  copied.complete();
                case 'submit':
                  service.completer.complete(
                    await const CertificateInspectService().execute(
                      CertificateInspectOperationRequest.fromText(
                        _fixture('pem'),
                      ),
                    ),
                  );
              }
            }
            await tester.pumpAndSettle();
            _noSuccess(tester);
            _noSource(tester);
            expect(_control('error'), findsNothing);
            expect(
              tester.widget<ElevatedButton>(_control('submit')).onPressed,
              isNotNull,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    for (final locale in ['en', 'pt-BR']) {
      testWidgets(
        'Given${locale}Metadata_WhenRendered_ThenLocalizedBoundedSemanticsAndGuidelinesPass',
        (tester) async {
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(
            ChimeraApp(
              initialLocation: '/certificate/inspect',
              localeTag: locale,
            ),
          );
          await tester.pumpAndSettle();
          for (final label
              in locale == 'en'
                  ? [
                      'Inspect certificate',
                      'Certificate (PEM or Base64)',
                      'Load certificate file',
                      'Paste certificate',
                      'Inspect',
                      'Auto',
                    ]
                  : [
                      'Inspecionar certificado',
                      'Certificado (PEM ou Base64)',
                      'Carregar arquivo de certificado',
                      'Colar certificado',
                      'Inspecionar',
                      'Automática',
                    ]) {
            expect(find.text(label), findsOneWidget);
          }
          await _inspect(tester, _fixture('pem'));
          final node = tester.widget<Semantics>(_control('result-semantics'));
          expect(node.properties.role, SemanticsRole.region);
          expect(node.excludeSemantics, isTrue);
          expect(node.properties.liveRegion, isTrue);
          expect(node.properties.value, contains('3'));
          expect(node.properties.value, contains('2'));
          for (final secret in [
            'example.test',
            '01AB',
            'Example CA',
            'Unknown attribute',
          ]) {
            expect(node.properties.value, isNot(contains(secret)));
            expect(node.properties.label, isNot(contains(secret)));
          }
          expect(
            tester.getSize(_control('metadata-scroll')).height,
            lessThanOrEqualTo(320),
          );
          final metadata = tester
              .widget<SelectableText>(_control('result'))
              .data!;
          expect(metadata, contains(locale == 'en' ? 'Subject' : 'Titular'));
          expect(
            metadata,
            contains(locale == 'en' ? 'critical: yes' : 'crítica: sim'),
          );
          expect(
            metadata,
            contains(locale == 'en' ? 'critical: no' : 'crítica: não'),
          );
          await tester.ensureVisible(_control('copy'));
          await tester.pumpAndSettle();
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          handle.dispose();
        },
      );

      testWidgets(
        'Given${locale}NarrowLayout_WhenTextIs200Percent_ThenControlsAndMetadataDoNotOverflow',
        (tester) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final dispatcher = tester.platformDispatcher;
          dispatcher.textScaleFactorTestValue = 2;
          addTearDown(dispatcher.clearTextScaleFactorTestValue);
          await tester.pumpWidget(
            ChimeraApp(
              initialLocation: '/certificate/inspect',
              localeTag: locale,
            ),
          );
          await tester.pumpAndSettle();
          await _inspect(tester, _fixture('pem'));
          await tester.ensureVisible(_control('copy'));
          await tester.pumpAndSettle();
          expect(_control('copy'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'GivenKeyboardTraversal_WhenInspected_ThenResultAndCopyReceiveFocusInOrder',
      (tester) async {
        String? copied;
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/certificate/inspect',
            certificateInspectFilePicker: () async => _der(),
            certificateInspectClipboardReader: () async => _fixture('pem'),
            certificateInspectClipboardWriter: (value) async => copied = value,
          ),
        );
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(_control('file-summary'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(_control('file-summary'), findsNothing);
        for (var index = 0; index < 5; index++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          'Certificate inspection result',
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(copied, _pemJson);
      },
    );

    test(
      'GivenGuiCatalog_WhenUsed_ThenBothLocalesContainEveryInteractionLabel',
      () {
        const catalog = MessageCatalog();
        for (final locale in supportedLocaleTags) {
          for (final key in [
            'pageTitle',
            'openAction',
            'inputLabel',
            'fileAction',
            'pasteAction',
            'submitAction',
            'copyAction',
            'copiedResult',
            'outputLabel',
            'resultSuccess',
            'subjectCountLabel',
            'issuerCountLabel',
            'extensionCountLabel',
            'representation.auto',
          ]) {
            expect(
              catalog.lookup(locale, 'certificateInspect.$key'),
              isNotEmpty,
            );
          }
        }
      },
    );
  });
}
