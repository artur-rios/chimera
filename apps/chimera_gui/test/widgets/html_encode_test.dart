import 'dart:async';
import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_gui/html_encode_page.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _control(String name) => find.byKey(Key('html-encode-$name'));

Future<void> _tap(WidgetTester tester, String name) async {
  await tester.ensureVisible(_control(name));
  await tester.tap(_control(name));
  await tester.pumpAndSettle();
}

Future<void> _historyShortcut(WidgetTester tester, {bool redo = false}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (redo) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
  if (redo) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

final class _Service
    implements OperationService<HtmlEncodeOperationRequest, HtmlEncodeOutput> {
  _Service({this.callback});
  final Future<ChimeraResult<HtmlEncodeOutput>> Function(
    HtmlEncodeOperationRequest,
  )?
  callback;
  int calls = 0;
  String? context;
  @override
  Future<ChimeraResult<HtmlEncodeOutput>> execute(
    HtmlEncodeOperationRequest request,
  ) {
    calls++;
    context = request.context;
    return callback?.call(request) ??
        const HtmlEncodeService().execute(request);
  }
}

final class _SavePlatform extends FilePickerPlatform {
  _SavePlatform(this.save);
  final Future<Uri?> Function(String, Uint8List, String) save;
  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    void Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) => save(fileName, bytes, mimeType);
}

void _noSuccess() {
  expect(_control('result'), findsNothing);
  expect(_control('copy'), findsNothing);
  expect(_control('save'), findsNothing);
  expect(_control('notice'), findsNothing);
}

void main() {
  for (final source in ['text', 'file', 'paste']) {
    for (final settled in [false, true]) {
      testWidgets(
        'Given$source${settled ? 'Settled' : 'Pending'}History_WhenEncoded_ThenUndoCannotRestoreDiscardedSource',
        (tester) async {
          await tester.pumpWidget(
            ChimeraApp(
              initialLocation: '/html/encode',
              htmlEncodeFilePicker: () async => [60],
              htmlEncodeClipboardReader: () async => '<',
            ),
          );
          await tester.pumpAndSettle();
          await tester.enterText(_control('input'), 'sensitive history');
          await tester.pump(const Duration(milliseconds: 600));
          if (source != 'text') {
            await _tap(tester, source);
          } else {
            await tester.enterText(_control('input'), 'sensitive pending');
          }
          await tester.pump(Duration(milliseconds: settled ? 600 : 50));
          final oldHistory = tester.state<UndoHistoryState<TextEditingValue>>(
            find.byType(UndoHistory<TextEditingValue>),
          );
          await _tap(tester, 'submit');
          expect(oldHistory.mounted, isFalse);
          expect(UndoManager.client, isNot(same(oldHistory)));
          await tester.tap(_control('input'));
          await tester.pump(const Duration(milliseconds: 600));
          for (final redo in [false, true, false]) {
            await _historyShortcut(tester, redo: redo);
            expect(
              tester.widget<TextField>(_control('input')).controller!.text,
              isEmpty,
            );
            expect(_control('result'), findsOneWidget);
          }
        },
      );
    }
  }

  for (final action in ['file', 'paste', 'failure', 'dispose']) {
    testWidgets(
      'GivenSensitiveEditor_When${action}DiscardsSource_ThenControllerAndHistoryDropOldText',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/html/encode',
            htmlEncodeFilePicker: () async => [60],
            htmlEncodeClipboardReader: () async => 'replacement',
            htmlEncodeService: _Service(
              callback: (_) async => throw StateError('SECRET'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(_control('input'), 'sensitive settled');
        await tester.pump(const Duration(milliseconds: 600));
        await tester.enterText(_control('input'), 'sensitive pending');
        final controller = tester
            .widget<TextField>(_control('input'))
            .controller!;
        final oldHistory = tester.state<UndoHistoryState<TextEditingValue>>(
          find.byType(UndoHistory<TextEditingValue>),
        );
        if (action == 'dispose') {
          await tester.pumpWidget(const SizedBox());
        } else {
          await _tap(tester, action == 'failure' ? 'submit' : action);
        }
        expect(oldHistory.mounted, isFalse);
        expect(UndoManager.client, isNot(same(oldHistory)));
        await tester.pump(const Duration(milliseconds: 600));
        if (action == 'dispose') {
          expect(controller.text, isEmpty);
        } else {
          await tester.tap(_control('input'));
          for (final redo in [false, true, false]) {
            await _historyShortcut(tester, redo: redo);
            expect(controller.text, isNot(contains('sensitive')));
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'GivenNormalEditor_WhenUndoAndRedoRunAfterReset_ThenNormalEditingHistoryStillWorks',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/html/encode',
          htmlEncodeFilePicker: () async => [60],
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'file');
      await tester.enterText(_control('input'), 'first');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.enterText(_control('input'), 'second');
      await tester.pump(const Duration(milliseconds: 600));
      await _historyShortcut(tester);
      expect(
        tester.widget<TextField>(_control('input')).controller!.text,
        'first',
      );
      await _historyShortcut(tester, redo: true);
      expect(
        tester.widget<TextField>(_control('input')).controller!.text,
        'second',
      );
    },
  );

  testWidgets(
    'GivenBomControlsAndEntityLookingFile_WhenEncodedAndSaved_ThenExactUtf8IsPreserved',
    (tester) async {
      List<int>? saved;
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/html/encode',
          htmlEncodeFilePicker: () async => [
            239,
            187,
            191,
            38,
            97,
            109,
            112,
            59,
            13,
            10,
            0,
          ],
          htmlEncodeFileSaver: (_, bytes, _) async {
            saved = bytes;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'file');
      await _tap(tester, 'submit');
      await _tap(tester, 'save');
      expect(
        tester.widget<SelectableText>(_control('output')).data,
        '\uFEFF&amp;amp;\r\n\u0000',
      );
      expect(saved, [
        239,
        187,
        191,
        38,
        97,
        109,
        112,
        59,
        97,
        109,
        112,
        59,
        13,
        10,
        0,
      ]);
    },
  );

  for (final kind in FailureKind.values) {
    testWidgets(
      'GivenTyped${kind.name}Failure_WhenServiceCompletes_ThenSafeCategoryIgnoresUntrustedDetails',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/html/encode',
            htmlEncodeService: _Service(
              callback: (_) async => ChimeraFailure<HtmlEncodeOutput>(
                kind: kind,
                code: 'SECRET',
                messageKey: 'SECRET',
                details: const {'source': 'SECRET'},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _tap(tester, 'submit');
        expect(tester.widget<Text>(_control('error')).data, switch (kind) {
          FailureKind.validation ||
          FailureKind.range => 'The HTML encoding request is invalid.',
          FailureKind.resource => 'HTML encoding exceeded its resource limit.',
          _ => 'The input could not be processed.',
        });
        _noSuccess();
      },
    );
  }
  const outputs = {
    'all': '&amp;&lt;&gt;&quot;&#39;&#47; Olá 🌍\r\n',
    'element': '&amp;&lt;&gt;"\'/ Olá 🌍\r\n',
    'double-quoted-attribute': '&amp;&lt;&gt;&quot;\'/ Olá 🌍\r\n',
    'single-quoted-attribute': '&amp;&lt;&gt;"&#39;/ Olá 🌍\r\n',
  };
  for (final locale in ['en', 'pt-BR']) {
    for (final entry in outputs.entries) {
      for (final source in ['text', 'file', 'clipboard', 'empty']) {
        testWidgets(
          'Given${locale}_${source}_WhenEncodedFor${entry.key}_ThenExactTextCopiesAndSavesOnceAndSourceIsDiscarded',
          (tester) async {
            final service = _Service();
            final expected = source == 'empty' ? '' : entry.value;
            var copies = 0;
            var saves = 0;
            await tester.pumpWidget(
              ChimeraApp(
                initialLocation: '/html/encode',
                localeTag: locale,
                htmlEncodeService: service,
                htmlEncodeFilePicker: () async =>
                    utf8.encode('&<>"\'/ Olá 🌍\r\n'),
                htmlEncodeClipboardReader: () async => '&<>"\'/ Olá 🌍\r\n',
                htmlEncodeClipboardWriter: (text) async {
                  copies++;
                  expect(text, expected);
                },
                htmlEncodeFileSaver: (name, bytes, mime) async {
                  saves++;
                  expect(name, 'chimera-html-encoded.txt');
                  expect(mime, 'text/plain; charset=utf-8');
                  expect(bytes, utf8.encode(expected));
                  return true;
                },
              ),
            );
            await tester.pumpAndSettle();
            final selector = tester.widget<DropdownButtonFormField<String>>(
              _control('context'),
            );
            expect(selector.initialValue, 'all');
            expect(
              tester
                  .widget<DropdownButton<String>>(
                    find.descendant(
                      of: _control('context'),
                      matching: find.byType(DropdownButton<String>),
                    ),
                  )
                  .items!
                  .map((item) => item.value),
              outputs.keys,
            );
            selector.onChanged!(entry.key);
            await tester.pumpAndSettle();
            if (source == 'text') {
              await tester.enterText(_control('input'), '&<>"\'/ Olá 🌍\r\n');
            }
            if (source == 'file') await _tap(tester, 'file');
            if (source == 'clipboard') await _tap(tester, 'paste');
            await _tap(tester, 'submit');
            expect(service.calls, 1);
            expect(service.context, entry.key);
            expect(
              tester.widget<SelectableText>(_control('output')).data,
              expected,
            );
            expect(
              tester.widget<TextField>(_control('input')).controller!.text,
              isEmpty,
            );
            await _tap(tester, 'copy');
            expect(copies, 1);
            expect(
              find.text(
                locale == 'en'
                    ? 'HTML encoded text copied.'
                    : 'Texto codificado em HTML copiado.',
              ),
              findsOneWidget,
            );
            await _tap(tester, 'save');
            expect(saves, 1);
            expect(
              find.text(
                locale == 'en'
                    ? 'HTML encoded text saved.'
                    : 'Texto codificado em HTML salvo.',
              ),
              findsOneWidget,
            );
            await _tap(tester, 'submit');
            expect(
              tester.widget<SelectableText>(_control('output')).data,
              isEmpty,
            );
          },
        );
      }
    }
  }
  testWidgets(
    'GivenHtmlRoute_WhenOpened_ThenTypedInputAndContextAreAvailable',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(initialLocation: '/html/encode'),
      );
      await tester.pumpAndSettle();
      expect(_control('input'), findsOneWidget);
      expect(_control('context'), findsOneWidget);
      expect(_control('submit'), findsOneWidget);
    },
  );

  for (final boundary in ['file', 'paste', 'save']) {
    testWidgets(
      'GivenResult_When${boundary}Canceled_ThenSourceAndResultArePreserved',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/html/encode',
            htmlEncodeFilePicker: () async => null,
            htmlEncodeClipboardReader: () async => null,
            htmlEncodeFileSaver: (_, _, _) async => false,
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(_control('input'), '<old>');
        await _tap(tester, 'submit');
        await _tap(tester, boundary);
        expect(
          tester.widget<SelectableText>(_control('output')).data,
          '&lt;old&gt;',
        );
        expect(_control('error'), findsNothing);
        expect(_control('notice'), findsNothing);
        await tester.enterText(_control('input'), 'current');
        await _tap(tester, boundary == 'save' ? 'file' : boundary);
        expect(
          tester.widget<TextField>(_control('input')).controller!.text,
          'current',
        );
      },
    );
  }

  for (final source in ['file', 'clipboard']) {
    testWidgets('GivenEmpty${source}_WhenReplacingText_ThenEmptyInputIsValid', (
      tester,
    ) async {
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/html/encode',
          htmlEncodeFilePicker: () async => [],
          htmlEncodeClipboardReader: () async => '',
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(_control('input'), 'discarded');
      await _tap(tester, source == 'file' ? 'file' : 'paste');
      await _tap(tester, 'submit');
      expect(tester.widget<SelectableText>(_control('output')).data, '');
    });
  }

  for (final replacement in ['text', 'file', 'paste', 'context']) {
    testWidgets(
      'GivenSuccess_When${replacement}Changes_ThenStaleResultAndNoticeClear',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/html/encode',
            htmlEncodeFilePicker: () async => [60],
            htmlEncodeClipboardReader: () async => 'new',
            htmlEncodeClipboardWriter: (_) async {},
          ),
        );
        await tester.pumpAndSettle();
        await _tap(tester, 'submit');
        await _tap(tester, 'copy');
        if (replacement == 'context') {
          tester
              .widget<DropdownButtonFormField<String>>(_control('context'))
              .onChanged!('element');
        } else if (replacement == 'text') {
          await tester.enterText(_control('input'), 'new');
        } else {
          await _tap(tester, replacement);
        }
        await tester.pumpAndSettle();
        _noSuccess();
      },
    );
  }

  for (final replacement in ['text', 'paste']) {
    testWidgets(
      'GivenFileSource_When${replacement}ReplacesIt_ThenOnlyReplacementTextIsEncoded',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/html/encode',
            htmlEncodeFilePicker: () async => [60],
            htmlEncodeClipboardReader: () async => '&new',
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(_control('input'), 'old');
        await _tap(tester, 'file');
        expect(
          tester.widget<TextField>(_control('input')).controller!.text,
          isEmpty,
        );
        if (replacement == 'text') {
          await tester.enterText(_control('input'), '&new');
        } else {
          await _tap(tester, 'paste');
        }
        await _tap(tester, 'submit');
        expect(
          tester.widget<SelectableText>(_control('output')).data,
          '&amp;new',
        );
      },
    );
  }

  for (final bytes in [
    <int>[],
    [0xef, 0xbb, 0xbf, 60, 13, 10, 0],
  ]) {
    for (final canceled in [false, true]) {
      test(
        'GivenNative${bytes.length}Bytes_WhenDefaultSave${canceled ? 'Canceled' : 'Completes'}_ThenOneExactPickerHandoffOccurs',
        () async {
          final original = FilePickerPlatform.instance;
          addTearDown(() => FilePickerPlatform.instance = original);
          final payload = Uint8List.fromList(bytes);
          var calls = 0;
          FilePickerPlatform.instance = _SavePlatform((name, data, mime) async {
            calls++;
            expect(name, 'chimera-html-encoded.txt');
            expect(mime, 'text/plain; charset=utf-8');
            expect(identical(data, payload), isTrue);
            return canceled ? null : Uri.file('result.txt');
          });
          expect(
            await saveHtmlEncodeFile(
              'chimera-html-encoded.txt',
              payload,
              'text/plain; charset=utf-8',
            ),
            !canceled,
          );
          expect(calls, 1);
        },
      );
    }
  }

  for (final locale in ['en', 'pt-BR']) {
    for (final boundary in [
      'file',
      'paste',
      'copy',
      'save',
      'encoder',
      'service',
    ]) {
      for (final allocation in [false, true]) {
        testWidgets(
          'Given${locale}Result_When$boundary${allocation ? 'Allocation' : 'Access'}Fails_ThenOnlySafeLiveErrorRemains',
          (tester) async {
            var fail = false;
            Object error() => allocation
                ? OutOfMemoryError()
                : StateError('SECRET /private/source &output');
            final service = _Service(
              callback: (request) async {
                if (fail && boundary == 'service') throw error();
                return const HtmlEncodeService().execute(request);
              },
            );
            await tester.pumpWidget(
              ChimeraApp(
                initialLocation: '/html/encode',
                localeTag: locale,
                htmlEncodeService: service,
                htmlEncodeFilePicker: () async {
                  if (fail) throw error();
                  return [60];
                },
                htmlEncodeClipboardReader: () async {
                  if (fail) throw error();
                  return '<';
                },
                htmlEncodeClipboardWriter: (_) async {
                  if (fail) throw error();
                },
                htmlEncodeFileSaver: (_, _, _) async {
                  if (fail) throw error();
                  return true;
                },
                htmlEncodeOutputEncoder: (text) {
                  if (fail && boundary == 'encoder') throw error();
                  return utf8.encode(text);
                },
              ),
            );
            await tester.pumpAndSettle();
            await tester.enterText(_control('input'), 'SECRET');
            await _tap(tester, 'submit');
            await _tap(tester, 'copy');
            fail = true;
            await _tap(tester, switch (boundary) {
              'service' => 'submit',
              'encoder' => 'save',
              _ => boundary,
            });
            _noSuccess();
            expect(
              tester.widget<TextField>(_control('input')).controller!.text,
              isEmpty,
            );
            final text = tester.widget<Text>(_control('error')).data!;
            final expected = allocation
                ? (locale == 'en'
                      ? 'HTML encoding exceeded its resource limit.'
                      : 'A codificação HTML excedeu o limite de recursos.')
                : switch ((locale, boundary)) {
                    ('en', 'file') => 'The input file could not be read.',
                    ('en', 'paste') => 'The clipboard text could not be read.',
                    ('en', 'copy') =>
                      'The clipboard text could not be written.',
                    ('en', 'save') || ('en', 'encoder') =>
                      'The HTML encoded text could not be saved.',
                    ('en', _) => 'The input could not be processed.',
                    (_, 'file') => 'Não foi possível ler o arquivo de entrada.',
                    (_, 'paste') =>
                      'Não foi possível ler o texto da área de transferência.',
                    (_, 'copy') => 'Não foi possível gravar o texto na área de transferência.',
                    (_, 'save') || (_, 'encoder') =>
                      'Não foi possível salvar o texto codificado em HTML.',
                    _ => 'Não foi possível processar a entrada.',
                  };
            expect(text, expected);
            expect(text, isNot(contains('SECRET')));
            expect(
              find.byWidgetPredicate(
                (w) =>
                    w is Semantics &&
                    w.properties.liveRegion == true &&
                    w.child is Text &&
                    (w.child! as Text).data == expected,
              ),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final malformed in [
    String.fromCharCode(0xd800),
    String.fromCharCode(0xdc00),
    '${String.fromCharCode(0xd800)}x',
  ]) {
    testWidgets(
      'GivenMalformedClipboard${malformed.codeUnits}_WhenPasted_ThenEditorNeverRendersInvalidUnicode',
      (tester) async {
        final service = _Service();
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/html/encode',
            htmlEncodeService: service,
            htmlEncodeClipboardReader: () async => malformed,
          ),
        );
        await tester.pumpAndSettle();
        await _tap(tester, 'paste');
        expect(
          find.text('The HTML encoding request is invalid.'),
          findsOneWidget,
        );
        expect(
          tester.widget<TextField>(_control('input')).controller!.text,
          isEmpty,
        );
        expect(service.calls, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final invalid in [
    'unicode',
    'utf8',
    'input-limit',
    'output-limit',
    'context',
  ]) {
    testWidgets(
      'Given${invalid}_WhenSubmitted_ThenSafeTypedFailureClearsOutput',
      (tester) async {
        final service = _Service(
          callback: (request) =>
              HtmlEncodeService(
                encoder: HtmlEntityEncoder(
                  maxInputCharacters: invalid == 'input-limit' ? 0 : null,
                  maxOutputCharacters: invalid == 'output-limit' ? 0 : null,
                ),
              ).execute(
                invalid == 'context'
                    ? HtmlEncodeOperationRequest.text(
                        'private',
                        context: 'invalid',
                      )
                    : request,
              ),
        );
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/html/encode',
            htmlEncodeService: service,
            htmlEncodeFilePicker: () async =>
                invalid == 'utf8' ? [0xc0, 0xaf] : [60],
          ),
        );
        await tester.pumpAndSettle();
        if (invalid == 'unicode') {
          tester.widget<TextField>(_control('input')).controller!.text =
              String.fromCharCode(0xd800);
        } else {
          await _tap(tester, 'file');
        }
        await _tap(tester, 'submit');
        _noSuccess();
        expect(
          find.text(
            invalid.endsWith('limit')
                ? 'HTML encoding exceeded its resource limit.'
                : 'The HTML encoding request is invalid.',
          ),
          findsOneWidget,
        );
        expect(tester.widget<TextField>(_control('input')).enabled, isTrue);
      },
    );
  }

  for (final boundary in ['file', 'paste', 'submit', 'copy', 'save']) {
    for (final invalidate in ['text', 'context', 'dispose']) {
      for (final lateFailure in [false, true]) {
        testWidgets(
          'GivenPending${boundary}_When${invalidate}_ThenBusyActionsDisableAndLate${lateFailure ? 'Failure' : 'Success'}CannotPublish',
          (tester) async {
            final pending = Completer<void>();
            var wait = false;
            final service = _Service(
              callback: (request) async {
                if (wait && boundary == 'submit') await pending.future;
                return const HtmlEncodeService().execute(request);
              },
            );
            await tester.pumpWidget(
              ChimeraApp(
                initialLocation: '/html/encode',
                htmlEncodeService: service,
                htmlEncodeFilePicker: () async {
                  if (wait) await pending.future;
                  return [60];
                },
                htmlEncodeClipboardReader: () async {
                  if (wait) await pending.future;
                  return 'late';
                },
                htmlEncodeClipboardWriter: (_) async {
                  if (wait) await pending.future;
                },
                htmlEncodeFileSaver: (_, _, _) async {
                  if (wait) await pending.future;
                  return true;
                },
              ),
            );
            await tester.pumpAndSettle();
            await _tap(tester, 'submit');
            final contextChange = tester
                .widget<DropdownButtonFormField<String>>(_control('context'))
                .onChanged!;
            wait = true;
            await _tap(tester, boundary);
            expect(
              tester.widget<TextField>(_control('input')).enabled,
              isFalse,
            );
            for (final name in [
              'file',
              'paste',
              'submit',
              if (boundary != 'submit') ...['copy', 'save'],
            ]) {
              expect(
                tester.widget<ButtonStyleButton>(_control(name)).onPressed,
                isNull,
                reason: name,
              );
            }
            expect(
              tester
                  .widget<DropdownButtonFormField<String>>(_control('context'))
                  .onChanged,
              isNull,
            );
            if (invalidate == 'dispose') {
              await tester.pumpWidget(const SizedBox());
            } else if (invalidate == 'text') {
              tester.widget<TextField>(_control('input')).onChanged!('new');
            } else {
              contextChange('element');
            }
            if (lateFailure) {
              pending.completeError(StateError('SECRET'));
            } else {
              pending.complete();
            }
            await tester.pumpAndSettle();
            _noSuccess();
            expect(_control('error'), findsNothing);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}Result_WhenAccessibilityChecked_ThenSafeLiveSummaryFocusTargetsAndGuidelinesPass',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/html/encode',
            localeTag: locale,
            htmlEncodeClipboardWriter: (_) async {},
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(_control('input'), 'SECRET' * 500);
        await _tap(tester, 'submit');
        final result = tester.widget<Semantics>(_control('result'));
        expect(result.properties.liveRegion, isTrue);
        expect(
          result.properties.value,
          locale == 'en'
              ? 'HTML encoding succeeded.'
              : 'Codificação HTML concluída.',
        );
        expect(
          result.properties.label,
          locale == 'en'
              ? 'HTML encoded result'
              : 'Resultado codificado em HTML',
        );
        expect(result.properties.value, isNot(contains('SECRET')));
        expect(
          FocusManager.instance.primaryFocus!.debugLabel,
          'HTML encoding result',
        );
        expect(
          tester
              .getSize(
                find
                    .ancestor(
                      of: _control('output'),
                      matching: find.byType(SingleChildScrollView),
                    )
                    .first,
              )
              .height,
          lessThanOrEqualTo(240),
        );
        for (final name in [
          'file',
          'paste',
          'context',
          'submit',
          'copy',
          'save',
        ]) {
          final size = tester.getSize(_control(name));
          expect(size.width, greaterThanOrEqualTo(48), reason: name);
          expect(size.height, greaterThanOrEqualTo(48), reason: name);
        }
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await _tap(tester, 'copy');
        final notice = tester.widget<Text>(_control('notice'));
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.liveRegion == true &&
                w.child == notice,
          ),
          findsOneWidget,
        );
        semantics.dispose();
      },
    );

    testWidgets(
      'Given${locale}NarrowLargeText_WhenEveryContextSelected_ThenOutputCopySaveRemainReachable',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          ChimeraApp(initialLocation: '/html/encode', localeTag: locale),
        );
        await tester.pumpAndSettle();
        for (final context in outputs.keys) {
          final labels = locale == 'en'
              ? {
                  'all': 'All characters',
                  'element': 'Element text',
                  'double-quoted-attribute': 'Double-quoted attribute',
                  'single-quoted-attribute': 'Single-quoted attribute',
                }
              : {
                  'all': 'Todos os caracteres',
                  'element': 'Texto de elemento',
                  'double-quoted-attribute': 'Atributo com aspas duplas',
                  'single-quoted-attribute': 'Atributo com aspas simples',
                };
          await tester.ensureVisible(_control('context'));
          await tester.pumpAndSettle();
          await tester.tap(_control('context'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text(labels[context]!).last);
          await tester.pumpAndSettle();
          await tester.tap(find.text(labels[context]!).last);
          await tester.pumpAndSettle();
          expect(
            tester.state<FormFieldState<String>>(_control('context')).value,
            context,
          );
          await _tap(tester, 'submit');
          await tester.ensureVisible(_control('save'));
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets(
    'GivenKeyboardUser_WhenTraversingAndActivating_ThenContextResultCopySaveFollowInOrder',
    (tester) async {
      String? copied;
      var saves = 0;
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/html/encode',
          htmlEncodeClipboardWriter: (text) async => copied = text,
          htmlEncodeFileSaver: (_, _, _) async {
            saves++;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();
      for (final name in ['input', 'file', 'paste', 'context', 'submit']) {
        if (name != 'input') {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
        }
        expect(
          find.ancestor(
            of: find.byWidget(
              FocusManager.instance.primaryFocus!.context!.widget,
            ),
            matching: _control(name),
          ),
          findsOneWidget,
          reason: name,
        );
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus!.debugLabel,
        'HTML encoding result',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(copied, '');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(saves, 1);
    },
  );
}
