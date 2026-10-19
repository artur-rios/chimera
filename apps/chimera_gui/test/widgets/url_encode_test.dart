import 'dart:async';
import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_gui/url_encode_page.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _control(String name) => find.byKey(Key('url-encode-$name'));

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
    implements OperationService<UrlEncodeOperationRequest, UrlEncodeOutput> {
  _Service({this.callback});
  final Future<ChimeraResult<UrlEncodeOutput>> Function(
    UrlEncodeOperationRequest,
  )?
  callback;
  int calls = 0;
  String? mode;
  @override
  Future<ChimeraResult<UrlEncodeOutput>> execute(
    UrlEncodeOperationRequest request,
  ) {
    calls++;
    mode = request.mode;
    return callback?.call(request) ?? const UrlEncodeService().execute(request);
  }
}

final class _SavePlatform extends FileSelectorPlatform {
  _SavePlatform(this.save);
  final Future<FileSaveLocation?> Function(String, List<String>) save;
  @override
  Future<FileSaveLocation?> getSaveLocation({
    SaveDialogOptions options = const SaveDialogOptions(),
    List<XTypeGroup>? acceptedTypeGroups,
  }) => save(options.suggestedName!, acceptedTypeGroups!.single.extensions!);
}

void _noSuccess() {
  expect(_control('result'), findsNothing);
  expect(_control('copy'), findsNothing);
  expect(_control('save'), findsNothing);
  expect(_control('notice'), findsNothing);
}

void main() {
  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}Home_WhenUrlEncodeSelected_ThenLocalizedRouteOpens',
      (tester) async {
        await tester.pumpWidget(ChimeraApp(localeTag: locale));
        await tester.pumpAndSettle();
        final entry = find.byKey(const Key('open-url-encode'));
        expect(
          find.descendant(
            of: entry,
            matching: find.text(
              locale == 'en' ? 'Encode URL' : 'Codificar URL',
            ),
          ),
          findsOneWidget,
        );
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(_control('input'), findsOneWidget);
        expect(_control('mode'), findsOneWidget);
      },
    );
  }
  for (final source in ['text', 'file', 'paste']) {
    for (final settled in [false, true]) {
      testWidgets(
        'Given$source${settled ? 'Settled' : 'Pending'}History_WhenEncoded_ThenUndoCannotRestoreDiscardedSource',
        (tester) async {
          await tester.pumpWidget(
            ChimeraApp(
              initialLocation: '/url/encode',
              urlEncodeFilePicker: () async => [60],
              urlEncodeClipboardReader: () async => '<',
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
            initialLocation: '/url/encode',
            urlEncodeFilePicker: () async => [60],
            urlEncodeClipboardReader: () async => 'replacement',
            urlEncodeService: _Service(
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
          initialLocation: '/url/encode',
          urlEncodeFilePicker: () async => [60],
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
          initialLocation: '/url/encode',
          urlEncodeFilePicker: () async => [
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
          urlEncodeFileSaver: (_, bytes, _) async {
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
        '%EF%BB%BF%26amp%3B%0D%0A%00',
      );
      expect(saved, utf8.encode('%EF%BB%BF%26amp%3B%0D%0A%00'));
    },
  );

  for (final kind in FailureKind.values) {
    testWidgets(
      'GivenTyped${kind.name}Failure_WhenServiceCompletes_ThenSafeCategoryIgnoresUntrustedDetails',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/url/encode',
            urlEncodeService: _Service(
              callback: (_) async => ChimeraFailure<UrlEncodeOutput>(
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
          FailureKind.range => 'The URL encoding request is invalid.',
          FailureKind.resource => 'URL encoding exceeded its resource limit.',
          _ => 'The input could not be processed.',
        });
        _noSuccess();
      },
    );
  }
  const outputs = {
    'component': '%26%3C%3E%22\'%2F%20Ol%C3%A1%20%F0%9F%8C%8D%0D%0A',
    'full': '&%3C%3E%22\'/%20Ol%C3%A1%20%F0%9F%8C%8D%0D%0A',
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
                initialLocation: '/url/encode',
                localeTag: locale,
                urlEncodeService: service,
                urlEncodeFilePicker: () async =>
                    utf8.encode('&<>"\'/ Olá 🌍\r\n'),
                urlEncodeClipboardReader: () async => '&<>"\'/ Olá 🌍\r\n',
                urlEncodeClipboardWriter: (text) async {
                  copies++;
                  expect(text, expected);
                },
                urlEncodeFileSaver: (name, bytes, mime) async {
                  saves++;
                  expect(name, 'chimera-url-encoded.txt');
                  expect(mime, 'text/plain; charset=utf-8');
                  expect(bytes, utf8.encode(expected));
                  return true;
                },
              ),
            );
            await tester.pumpAndSettle();
            final selector = tester.widget<DropdownButtonFormField<String>>(
              _control('mode'),
            );
            expect(selector.initialValue, 'component');
            expect(
              tester
                  .widget<DropdownButton<String>>(
                    find.descendant(
                      of: _control('mode'),
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
            expect(service.mode, entry.key);
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
                    ? 'URL encoded text copied.'
                    : 'Texto codificado em URL copiado.',
              ),
              findsOneWidget,
            );
            await _tap(tester, 'save');
            expect(saves, 1);
            expect(
              find.text(
                locale == 'en'
                    ? 'URL encoded text saved.'
                    : 'Texto codificado em URL salvo.',
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
  testWidgets('GivenUrlRoute_WhenOpened_ThenTypedInputAndModeAreAvailable', (
    tester,
  ) async {
    await tester.pumpWidget(const ChimeraApp(initialLocation: '/url/encode'));
    await tester.pumpAndSettle();
    expect(_control('input'), findsOneWidget);
    expect(_control('mode'), findsOneWidget);
    expect(_control('submit'), findsOneWidget);
  });

  for (final boundary in ['file', 'paste', 'save']) {
    testWidgets(
      'GivenResult_When${boundary}Canceled_ThenSourceAndResultArePreserved',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/url/encode',
            urlEncodeFilePicker: () async => null,
            urlEncodeClipboardReader: () async => null,
            urlEncodeFileSaver: (_, _, _) async => false,
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(_control('input'), '<old>');
        await _tap(tester, 'submit');
        await _tap(tester, boundary);
        expect(
          tester.widget<SelectableText>(_control('output')).data,
          '%3Cold%3E',
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
          initialLocation: '/url/encode',
          urlEncodeFilePicker: () async => [],
          urlEncodeClipboardReader: () async => '',
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(_control('input'), 'discarded');
      await _tap(tester, source == 'file' ? 'file' : 'paste');
      await _tap(tester, 'submit');
      expect(tester.widget<SelectableText>(_control('output')).data, '');
    });
  }

  for (final replacement in ['text', 'file', 'paste', 'mode']) {
    testWidgets(
      'GivenSuccess_When${replacement}Changes_ThenStaleResultAndNoticeClear',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/url/encode',
            urlEncodeFilePicker: () async => [60],
            urlEncodeClipboardReader: () async => 'new',
            urlEncodeClipboardWriter: (_) async {},
          ),
        );
        await tester.pumpAndSettle();
        await _tap(tester, 'submit');
        await _tap(tester, 'copy');
        if (replacement == 'mode') {
          tester
              .widget<DropdownButtonFormField<String>>(_control('mode'))
              .onChanged!('full');
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
            initialLocation: '/url/encode',
            urlEncodeFilePicker: () async => [60],
            urlEncodeClipboardReader: () async => '&new',
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
          '%26new',
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
        'GivenNative${bytes.length}Bytes_WhenDefaultSave${canceled ? 'Canceled' : 'Completes'}_ThenPathSelectionPrecedesExactTransactionalHandoff',
        () async {
          final original = FileSelectorPlatform.instance;
          addTearDown(() => FileSelectorPlatform.instance = original);
          final payload = Uint8List.fromList(bytes);
          var calls = 0;
          var writes = 0;
          FileSelectorPlatform.instance = _SavePlatform((
            name,
            extensions,
          ) async {
            calls++;
            expect(name, 'chimera-url-encoded.txt');
            expect(extensions, ['txt']);
            return canceled ? null : const FileSaveLocation('result.txt');
          });
          expect(
            await saveUrlEncodeFile(
              'chimera-url-encoded.txt',
              payload,
              'text/plain; charset=utf-8',
              writeTransaction: (path, data) async {
                writes++;
                expect(path, 'result.txt');
                expect(data, bytes);
              },
            ),
            !canceled,
          );
          expect(calls, 1);
          expect(writes, canceled ? 0 : 1);
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
                return const UrlEncodeService().execute(request);
              },
            );
            await tester.pumpWidget(
              ChimeraApp(
                initialLocation: '/url/encode',
                localeTag: locale,
                urlEncodeService: service,
                urlEncodeFilePicker: () async {
                  if (fail) throw error();
                  return [60];
                },
                urlEncodeClipboardReader: () async {
                  if (fail) throw error();
                  return '<';
                },
                urlEncodeClipboardWriter: (_) async {
                  if (fail) throw error();
                },
                urlEncodeFileSaver: (_, _, _) async {
                  if (fail) throw error();
                  return true;
                },
                urlEncodeOutputEncoder: (text) {
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
                      ? 'URL encoding exceeded its resource limit.'
                      : 'A codificação URL excedeu o limite de recursos.')
                : switch ((locale, boundary)) {
                    ('en', 'file') => 'The input file could not be read.',
                    ('en', 'paste') => 'The clipboard text could not be read.',
                    ('en', 'copy') =>
                      'The clipboard text could not be written.',
                    ('en', 'save') || ('en', 'encoder') =>
                      'The URL encoded text could not be saved.',
                    ('en', _) => 'The input could not be processed.',
                    (_, 'file') => 'Não foi possível ler o arquivo de entrada.',
                    (_, 'paste') =>
                      'Não foi possível ler o texto da área de transferência.',
                    (_, 'copy') => 'Não foi possível gravar o texto na área de transferência.',
                    (_, 'save') || (_, 'encoder') =>
                      'Não foi possível salvar o texto codificado em URL.',
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
            initialLocation: '/url/encode',
            urlEncodeService: service,
            urlEncodeClipboardReader: () async => malformed,
          ),
        );
        await tester.pumpAndSettle();
        await _tap(tester, 'paste');
        expect(
          find.text('The URL encoding request is invalid.'),
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
    'mode',
  ]) {
    testWidgets(
      'Given${invalid}_WhenSubmitted_ThenSafeTypedFailureClearsOutput',
      (tester) async {
        final service = _Service(
          callback: (request) =>
              UrlEncodeService(
                encoder: UrlEncoder(
                  maxInputCharacters: invalid == 'input-limit' ? 0 : null,
                  maxOutputCharacters: invalid == 'output-limit' ? 0 : null,
                ),
              ).execute(
                invalid == 'mode'
                    ? UrlEncodeOperationRequest.text('private', mode: 'invalid')
                    : request,
              ),
        );
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/url/encode',
            urlEncodeService: service,
            urlEncodeFilePicker: () async =>
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
                ? 'URL encoding exceeded its resource limit.'
                : 'The URL encoding request is invalid.',
          ),
          findsOneWidget,
        );
        expect(tester.widget<TextField>(_control('input')).enabled, isTrue);
      },
    );
  }

  for (final boundary in ['file', 'paste', 'submit', 'copy', 'save']) {
    for (final invalidate in ['text', 'mode', 'dispose']) {
      for (final lateFailure in [false, true]) {
        testWidgets(
          'GivenPending${boundary}_When${invalidate}_ThenBusyActionsDisableAndLate${lateFailure ? 'Failure' : 'Success'}CannotPublish',
          (tester) async {
            final pending = Completer<void>();
            var wait = false;
            final service = _Service(
              callback: (request) async {
                if (wait && boundary == 'submit') await pending.future;
                return const UrlEncodeService().execute(request);
              },
            );
            await tester.pumpWidget(
              ChimeraApp(
                initialLocation: '/url/encode',
                urlEncodeService: service,
                urlEncodeFilePicker: () async {
                  if (wait) await pending.future;
                  return [60];
                },
                urlEncodeClipboardReader: () async {
                  if (wait) await pending.future;
                  return 'late';
                },
                urlEncodeClipboardWriter: (_) async {
                  if (wait) await pending.future;
                },
                urlEncodeFileSaver: (_, _, _) async {
                  if (wait) await pending.future;
                  return true;
                },
              ),
            );
            await tester.pumpAndSettle();
            await _tap(tester, 'submit');
            final modeChange = tester
                .widget<DropdownButtonFormField<String>>(_control('mode'))
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
                  .widget<DropdownButtonFormField<String>>(_control('mode'))
                  .onChanged,
              isNull,
            );
            if (invalidate == 'dispose') {
              await tester.pumpWidget(const SizedBox());
            } else if (invalidate == 'text') {
              tester.widget<TextField>(_control('input')).onChanged!('new');
            } else {
              modeChange('full');
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
            initialLocation: '/url/encode',
            localeTag: locale,
            urlEncodeClipboardWriter: (_) async {},
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
              ? 'URL encoding succeeded.'
              : 'Codificação URL concluída.',
        );
        expect(
          result.properties.label,
          locale == 'en' ? 'URL encoded result' : 'Resultado codificado em URL',
        );
        expect(result.properties.value, isNot(contains('SECRET')));
        expect(
          FocusManager.instance.primaryFocus!.debugLabel,
          'URL encoding result',
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
          'mode',
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
      'Given${locale}NarrowLargeText_WhenEveryModeSelected_ThenOutputCopySaveRemainReachable',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          ChimeraApp(initialLocation: '/url/encode', localeTag: locale),
        );
        await tester.pumpAndSettle();
        for (final mode in outputs.keys) {
          final labels = locale == 'en'
              ? {'component': 'URL component', 'full': 'Full value'}
              : {'component': 'Componente de URL', 'full': 'Valor completo'};
          await tester.ensureVisible(_control('mode'));
          await tester.pumpAndSettle();
          await tester.tap(_control('mode'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text(labels[mode]!).last);
          await tester.pumpAndSettle();
          await tester.tap(find.text(labels[mode]!).last);
          await tester.pumpAndSettle();
          expect(
            tester.state<FormFieldState<String>>(_control('mode')).value,
            mode,
          );
          await _tap(tester, 'submit');
          await tester.ensureVisible(_control('save'));
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets(
    'GivenKeyboardUser_WhenTraversingAndActivating_ThenModeResultCopySaveFollowInOrder',
    (tester) async {
      String? copied;
      var saves = 0;
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/url/encode',
          urlEncodeClipboardWriter: (text) async => copied = text,
          urlEncodeFileSaver: (_, _, _) async {
            saves++;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();
      for (final name in ['input', 'file', 'paste', 'mode', 'submit']) {
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
        'URL encoding result',
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
