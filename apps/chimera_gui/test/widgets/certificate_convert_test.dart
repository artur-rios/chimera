import 'dart:async';
import 'dart:io';
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _control(String name) => find.byKey(Key('certificate-convert-$name'));
String _fixture(String extension) =>
    File('../../tests/fixtures/certificates/certificate.$extension')
        .readAsStringSync();
List<int> _der() =>
    File('../../tests/fixtures/certificates/certificate.der').readAsBytesSync();
String _expectedText(String target) =>
    target == 'base64' ? _fixture('base64').trimRight() : _fixture('pem');

final class _RecordingService
    implements
        OperationService<
          CertificateConvertOperationRequest,
          CertificateConvertOutput
        > {
  CertificateConvertOutput? output;

  @override
  Future<ChimeraResult<CertificateConvertOutput>> execute(
    CertificateConvertOperationRequest request,
  ) async {
    final result = await const CertificateConvertService().execute(request);
    result.fold(onSuccess: (value) => output = value, onFailure: (_) {});
    return result;
  }
}

final class _CallbackService
    implements
        OperationService<
          CertificateConvertOperationRequest,
          CertificateConvertOutput
        > {
  _CallbackService(this.callback);
  final Future<ChimeraResult<CertificateConvertOutput>> Function(
    CertificateConvertOperationRequest,
  )
  callback;
  @override
  Future<ChimeraResult<CertificateConvertOutput>> execute(
    CertificateConvertOperationRequest request,
  ) => callback(request);
}

void _noSuccess() {
  expect(_control('result-semantics'), findsNothing);
  expect(_control('result'), findsNothing);
  expect(_control('copy'), findsNothing);
  expect(_control('save'), findsNothing);
  expect(_control('notice'), findsNothing);
}

void _noSource(WidgetTester tester) {
  expect(tester.widget<TextField>(_control('input')).controller!.text, isEmpty);
  expect(_control('file-summary'), findsNothing);
}

Future<void> _convert(WidgetTester tester) async {
  await tester.enterText(_control('input'), _fixture('pem'));
  await _tap(tester, 'submit');
}

Future<void> _tap(WidgetTester tester, String name) async {
  await tester.ensureVisible(_control(name));
  await tester.tap(_control(name));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'GivenConversionRoute_WhenPemTextSubmitted_ThenAutoToPemShowsExactSelectableText',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(initialLocation: '/certificate/convert'),
      );
      await tester.pumpAndSettle();
      expect(_control('input'), findsOneWidget);
      expect(
        tester.widget<ChoiceChip>(_control('source-auto')).selected,
        isTrue,
      );
      expect(
        tester.widget<ChoiceChip>(_control('target-pem')).selected,
        isTrue,
      );
      await tester.enterText(_control('input'), _fixture('pem'));
      await _tap(tester, 'submit');
      expect(
        tester.widget<SelectableText>(_control('result')).data,
        _fixture('pem'),
      );
      expect(_control('copy'), findsOneWidget);
      expect(_control('save'), findsOneWidget);
    },
  );

  for (final source in CertificateInputRepresentation.values) {
    for (final target in CertificateOutputRepresentation.values) {
      testWidgets(
        'Given${source.name}File_WhenConvertedTo${target.name}_ThenExactBytesAreSavedOnce',
        (tester) async {
          final service = _RecordingService();
          final input = switch (source) {
            CertificateInputRepresentation.pem => _fixture('pem').codeUnits,
            CertificateInputRepresentation.base64 => _fixture(
              'base64',
            ).codeUnits,
            _ => _der(),
          };
          var saves = 0;
          await tester.pumpWidget(
            ChimeraApp(
              initialLocation: '/certificate/convert',
              certificateConvertService: service,
              certificateConvertFilePicker: () async => input,
              certificateConvertFileSaver: (name, bytes) async {
                saves++;
                expect(name, 'chimera-certificate.${target.name}');
                expect(identical(bytes, service.output!.bytes), isTrue);
                expect(() => bytes[0] = 0, throwsUnsupportedError);
                expect(
                  bytes,
                  target == CertificateOutputRepresentation.der
                      ? _der()
                      : _expectedText(target.name).codeUnits,
                );
                return true;
              },
            ),
          );
          await tester.pumpAndSettle();
          await tester.enterText(_control('input'), 'superseded text');
          await _tap(tester, 'file');
          expect(
            tester.widget<TextField>(_control('input')).controller!.text,
            '',
          );
          await _tap(tester, 'source-${source.name}');
          await _tap(tester, 'target-${target.name}');
          await _tap(tester, 'submit');
          if (target == CertificateOutputRepresentation.der) {
            expect(_control('copy'), findsNothing);
            expect(find.byType(SelectableText), findsNothing);
            expect(find.text('Output bytes: 534'), findsOneWidget);
          } else {
            expect(
              tester.widget<SelectableText>(_control('result')).data,
              _expectedText(target.name),
            );
          }
          await _tap(tester, 'save');
          expect(saves, 1);
          expect(find.text('Converted certificate saved.'), findsOneWidget);
        },
      );
    }
  }

  for (final locale in ['en', 'pt-BR']) {
    for (final source in ['text', 'clipboard']) {
      for (final target in ['pem', 'base64']) {
        testWidgets(
          'Given${locale}_${source}_WhenConvertedTo${target}_ThenExactTextIsCopied',
          (tester) async {
            String? copied;
            await tester.pumpWidget(
              ChimeraApp(
                initialLocation: '/certificate/convert',
                localeTag: locale,
                certificateConvertFilePicker: () async => _der(),
                certificateConvertClipboardReader: () async =>
                    _fixture('base64'),
                certificateConvertClipboardWriter: (value) async =>
                    copied = value,
              ),
            );
            await tester.pumpAndSettle();
            await _tap(tester, 'file');
            if (source == 'clipboard') {
              await _tap(tester, 'paste');
            } else {
              await tester.enterText(_control('input'), _fixture('base64'));
              await tester.pump();
            }
            expect(_control('file-summary'), findsNothing);
            await _tap(tester, 'target-$target');
            await _tap(tester, 'submit');
            expect(
              tester.widget<SelectableText>(_control('result')).data,
              _expectedText(target),
            );
            await _tap(tester, 'copy');
            expect(copied, _expectedText(target));
            expect(
              find.text(
                locale == 'en'
                    ? 'Converted certificate copied.'
                    : 'Certificado convertido copiado.',
              ),
              findsOneWidget,
            );
          },
        );
      }
    }
  }

  for (final locale in ['en', 'pt-BR']) {
    for (final action in ['file', 'paste', 'submit', 'copy', 'save']) {
      for (final allocation in [false, true]) {
        testWidgets(
          'Given${locale}_${action}_${allocation}Failure_WhenInvoked_ThenSafeLiveErrorClearsAllData',
          (tester) async {
            var fail = false;
            Object error() => allocation
                ? OutOfMemoryError()
                : StateError('SENSITIVE certificate /secret/path');
            await tester.pumpWidget(
              ChimeraApp(
                initialLocation: '/certificate/convert',
                localeTag: locale,
                certificateConvertService: _CallbackService((request) async {
                  if (fail) throw error();
                  return const CertificateConvertService().execute(request);
                }),
                certificateConvertFilePicker: () async =>
                    fail ? throw error() : _der(),
                certificateConvertClipboardReader: () async => throw error(),
                certificateConvertClipboardWriter: (_) async {
                  if (fail) throw error();
                },
                certificateConvertFileSaver: (_, _) async => throw error(),
              ),
            );
            await tester.pumpAndSettle();
            await _tap(tester, 'file');
            await _tap(tester, 'submit');
            await _tap(tester, 'copy');
            fail = true;
            await _tap(tester, action);
            _noSuccess();
            _noSource(tester);
            final key = allocation
                ? 'resource'
                : switch (action) {
                    'file' => 'fileAccess',
                    'paste' => 'clipboardRead',
                    'copy' => 'clipboardWrite',
                    'save' => 'outputAccess',
                    _ => 'inputAccess',
                  };
            expect(
              tester.widget<Text>(_control('error')).data,
              const MessageCatalog().lookup(
                locale,
                'error.certificateConvert.$key',
              ),
            );
            expect(
              find.ancestor(
                of: _control('error'),
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Semantics &&
                      widget.properties.liveRegion == true,
                ),
              ),
              findsOneWidget,
            );
            expect(find.textContaining('SENSITIVE'), findsNothing);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final source in [
    '',
    'not a certificate',
    '-----BEGIN PRIVATE KEY-----\nAAA=\n-----END PRIVATE KEY-----',
    'multiple',
    'der-text',
    'pem-mismatch',
    'byte-range',
  ]) {
    testWidgets(
      'Given${source}InvalidInput_WhenConverted_ThenValidationClearsSourceAndResult',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/certificate/convert',
            certificateConvertFilePicker: () async => [256],
          ),
        );
        await tester.pumpAndSettle();
        await _convert(tester);
        switch (source) {
          case 'multiple':
            await tester.enterText(
              _control('input'),
              '${_fixture('pem')}${_fixture('pem')}',
            );
          case 'der-text':
            await _tap(tester, 'source-der');
          case 'pem-mismatch':
            await tester.enterText(_control('input'), _fixture('base64'));
            await _tap(tester, 'source-pem');
          case 'byte-range':
            await _tap(tester, 'file');
          default:
            await tester.enterText(_control('input'), source);
        }
        await _tap(tester, 'submit');
        _noSuccess();
        _noSource(tester);
        expect(
          tester.widget<Text>(_control('error')).data,
          const MessageCatalog().lookup(
            'en',
            'error.certificateConvert.validation',
          ),
        );
      },
    );
  }

  testWidgets(
    'GivenTypedSelectors_WhenRendered_ThenOnlySupportedValuesExistAndInjectedTargetFailureIsSafe',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/certificate/convert',
          certificateConvertService: _CallbackService(
            (_) async => const ChimeraFailure(
              kind: FailureKind.validation,
              code: 'certificate-convert.invalid-input',
              messageKey: 'SENSITIVE injected key',
              details: {
                'field': 'target',
                'reason': 'unsupported-representation',
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNWidgets(7));
      expect(_control('target-auto'), findsNothing);
      expect(find.byType(DropdownButton<String>), findsNothing);
      await _convert(tester);
      _noSuccess();
      _noSource(tester);
      expect(
        tester.widget<Text>(_control('error')).data,
        const MessageCatalog().lookup(
          'en',
          'error.certificateConvert.validation',
        ),
      );
    },
  );

  for (final thrown in ['execute-typed', 'deferred-text']) {
    testWidgets(
      'Given${thrown}ResourceFailure_WhenConverted_ThenNoPartialResultRemains',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/certificate/convert',
            certificateConvertService: thrown == 'execute-typed'
                ? _CallbackService(
                    (_) async =>
                        throw const CertificateConversionResourceException(
                          field: 'output',
                          reason: 'allocation-limit',
                        ),
                  )
                : CertificateConvertService(
                    converter: CertificateConverter.forTesting(
                      decodeText: (_) => throw OutOfMemoryError(),
                    ),
                  ),
          ),
        );
        await tester.pumpAndSettle();
        await _convert(tester);
        _noSource(tester);
        _noSuccess();
        expect(
          tester.widget<Text>(_control('error')).data,
          const MessageCatalog().lookup(
            'en',
            'error.certificateConvert.resource',
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final action in ['file', 'save']) {
    testWidgets(
      'GivenCompletedResult_When${action}Canceled_ThenResultAndSourceArePreserved',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/certificate/convert',
            certificateConvertFilePicker: () async => null,
            certificateConvertFileSaver: (_, _) async => false,
          ),
        );
        await tester.pumpAndSettle();
        await _convert(tester);
        await _tap(tester, action);
        expect(
          tester.widget<SelectableText>(_control('result')).data,
          _fixture('pem'),
        );
        expect(
          tester.widget<TextField>(_control('input')).controller!.text,
          _fixture('pem'),
        );
        expect(_control('error'), findsNothing);
        expect(_control('notice'), findsNothing);
        expect(
          tester.widget<OutlinedButton>(_control('save')).onPressed,
          isNotNull,
        );
      },
    );
  }

  for (final change in [
    'text',
    'file',
    'paste',
    'source-base64',
    'target-der',
  ]) {
    testWidgets(
      'GivenCompletedResultAndNotice_When${change}Changes_ThenStaleActionsAreCleared',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/certificate/convert',
            certificateConvertFilePicker: () async => _der(),
            certificateConvertClipboardReader: () async => _fixture('base64'),
            certificateConvertClipboardWriter: (_) async {},
          ),
        );
        await tester.pumpAndSettle();
        await _convert(tester);
        await _tap(tester, 'copy');
        if (change == 'text') {
          await tester.enterText(_control('input'), 'new input');
          await tester.pump();
        } else {
          await _tap(tester, change);
        }
        _noSuccess();
        expect(_control('error'), findsNothing);
      },
    );
  }

  for (final action in ['file', 'paste', 'submit', 'copy', 'save']) {
    for (final failed in [false, true]) {
      for (final supersede in ['source', 'target', 'dispose']) {
        testWidgets(
          'GivenPending${action}_${failed}_When${supersede}SupersedesIt_ThenLateCompletionIsIgnored',
          (tester) async {
            final bytes = Completer<List<int>?>();
            final text = Completer<String?>();
            final copied = Completer<void>();
            final saved = Completer<bool>();
            final converted =
                Completer<ChimeraResult<CertificateConvertOutput>>();
            await tester.pumpWidget(
              ChimeraApp(
                initialLocation: '/certificate/convert',
                certificateConvertService: action == 'submit'
                    ? _CallbackService((_) => converted.future)
                    : const CertificateConvertService(),
                certificateConvertFilePicker: () => bytes.future,
                certificateConvertClipboardReader: () => text.future,
                certificateConvertClipboardWriter: (_) => copied.future,
                certificateConvertFileSaver: (_, _) => saved.future,
              ),
            );
            await tester.pumpAndSettle();
            if (action == 'copy' || action == 'save') await _convert(tester);
            final edit = tester.widget<TextField>(_control('input')).onChanged!;
            final selectSource = tester
                .widget<ChoiceChip>(_control('source-base64'))
                .onSelected!;
            final selectTarget = tester
                .widget<ChoiceChip>(_control('target-der'))
                .onSelected!;
            await tester.ensureVisible(_control(action));
            await tester.tap(_control(action));
            await tester.pump();
            expect(
              tester.widget<TextField>(_control('input')).enabled,
              isFalse,
            );
            for (final name in ['file', 'paste']) {
              expect(
                tester.widget<OutlinedButton>(_control(name)).onPressed,
                isNull,
              );
            }
            expect(
              tester.widget<ElevatedButton>(_control('submit')).onPressed,
              isNull,
            );
            for (final chip in tester.widgetList<ChoiceChip>(
              find.byType(ChoiceChip),
            )) {
              expect(chip.onSelected, isNull);
            }
            if (action == 'copy' || action == 'save') {
              expect(
                tester.widget<OutlinedButton>(_control('copy')).onPressed,
                isNull,
              );
              expect(
                tester.widget<OutlinedButton>(_control('save')).onPressed,
                isNull,
              );
            }
            if (supersede == 'dispose') {
              await tester.pumpWidget(const SizedBox.shrink());
            } else {
              // A callback queued before the busy frame must invalidate its generation.
              edit('');
              if (supersede == 'source') {
                selectSource(true);
              } else {
                selectTarget(true);
              }
              await tester.pump();
              await tester.enterText(_control('input'), '');
            }
            if (failed) {
              final error = StateError('SENSITIVE stale completion');
              switch (action) {
                case 'file':
                  bytes.completeError(error);
                case 'paste':
                  text.completeError(error);
                case 'copy':
                  copied.completeError(error);
                case 'save':
                  saved.completeError(error);
                case 'submit':
                  converted.completeError(error);
              }
            } else {
              switch (action) {
                case 'file':
                  bytes.complete(_der());
                case 'paste':
                  text.complete(_fixture('pem'));
                case 'copy':
                  copied.complete();
                case 'save':
                  saved.complete(true);
                case 'submit':
                  converted.complete(
                    await const CertificateConvertService().execute(
                      CertificateConvertOperationRequest.fromText(
                        _fixture('pem'),
                        target: CertificateOutputRepresentation.pem,
                      ),
                    ),
                  );
              }
            }
            await tester.pumpAndSettle();
            if (supersede != 'dispose') {
              _noSource(tester);
              _noSuccess();
              expect(_control('error'), findsNothing);
            } else {
              await tester.pumpWidget(
                const ChimeraApp(initialLocation: '/certificate/convert'),
              );
              await tester.pumpAndSettle();
              _noSource(tester);
              _noSuccess();
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}Result_WhenAccessible_ThenSafeSemanticsAndTargetGuidelinesPass',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/certificate/convert',
            localeTag: locale,
          ),
        );
        await tester.pumpAndSettle();
        final sourceLabel = locale == 'en'
            ? 'Source representation: PEM'
            : 'Representação de origem: PEM';
        final targetLabel = locale == 'en'
            ? 'Target representation: PEM'
            : 'Representação de destino: PEM';
        expect(find.bySemanticsLabel(sourceLabel), findsOneWidget);
        expect(find.bySemanticsLabel(targetLabel), findsOneWidget);
        for (final name in [
          'file',
          'paste',
          'submit',
          'source-auto',
          'source-pem',
          'source-der',
          'source-base64',
          'target-pem',
          'target-der',
          'target-base64',
        ]) {
          final size = tester.getSize(_control(name));
          expect(size.height, greaterThanOrEqualTo(48), reason: name);
          expect(size.width, greaterThanOrEqualTo(48), reason: name);
        }
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await _convert(tester);
        final semantics = tester.widget<Semantics>(
          _control('result-semantics'),
        );
        expect(semantics.properties.role, SemanticsRole.region);
        expect(semantics.properties.liveRegion, isTrue);
        expect(semantics.excludeSemantics, isTrue);
        expect(semantics.properties.value, contains('534'));
        expect(semantics.properties.value, contains('778'));
        expect(semantics.properties.value, contains(sourceLabel));
        expect(semantics.properties.value, contains(targetLabel));
        for (final secret in [
          'BEGIN CERTIFICATE',
          'MIICEj',
          'example.test',
          '48, 130',
        ]) {
          expect(semantics.properties.value, isNot(contains(secret)));
          expect(semantics.properties.label, isNot(contains(secret)));
        }
        expect(
          tester.getSize(_control('text-scroll')).height,
          lessThanOrEqualTo(320),
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
      'Given${locale}NarrowScreen_WhenTextIs200Percent_ThenConversionAndActionsDoNotOverflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/certificate/convert',
            localeTag: locale,
          ),
        );
        await tester.pumpAndSettle();
        await _convert(tester);
        await tester.ensureVisible(_control('copy'));
        await tester.ensureVisible(_control('save'));
        await tester.pumpAndSettle();
        expect(_control('save'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('GivenSensitiveSource_WhenDisposed_ThenControllerDropsItsText', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ChimeraApp(initialLocation: '/certificate/convert'),
    );
    await tester.pumpAndSettle();
    await _convert(tester);
    final controller = tester.widget<TextField>(_control('input')).controller!;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(controller.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'GivenKeyboardTraversal_WhenConverted_ThenResultCopyAndSaveReceiveFocusInOrder',
    (tester) async {
      String? copied;
      var saves = 0;
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/certificate/convert',
          certificateConvertFilePicker: () async => _der(),
          certificateConvertClipboardReader: () async => _fixture('pem'),
          certificateConvertClipboardWriter: (value) async => copied = value,
          certificateConvertFileSaver: (_, _) async {
            saves++;
            return true;
          },
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
      for (var i = 0; i < 8; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'Certificate conversion result',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(copied, _fixture('pem'));
      expect(
        find.ancestor(
          of: _control('notice'),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.liveRegion == true,
          ),
        ),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(saves, 1);
    },
  );
}
