import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_gui/gzip_compress_page.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _control(String name) => find.byKey(Key('gzip-compress-$name'));

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

final class _Service
    implements
        OperationService<GzipCompressOperationRequest, GzipCompressOutput> {
  _Service({this.callback});
  final Future<ChimeraResult<GzipCompressOutput>> Function(
    GzipCompressOperationRequest,
  )?
  callback;
  int calls = 0;
  GzipCompressOutput? output;
  @override
  Future<ChimeraResult<GzipCompressOutput>> execute(
    GzipCompressOperationRequest request,
  ) async {
    calls++;
    final result =
        await (callback?.call(request) ??
            const GzipCompressService().execute(request));
    result.fold(onSuccess: (value) => output = value, onFailure: (_) {});
    return result;
  }
}

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

Future<void> _settledText(WidgetTester tester, String text) async {
  // UndoHistory coalesces snapshots for 500ms; settle before and after editing.
  await tester.pump(const Duration(milliseconds: 600));
  await tester.enterText(_control('input'), text);
  await tester.pump(const Duration(milliseconds: 600));
}

void _noSuccess() {
  expect(_control('result'), findsNothing);
  expect(_control('save'), findsNothing);
  expect(_control('notice'), findsNothing);
}

void main() {
  for (final boundary in ['file', 'paste', 'save', 'service']) {
    for (final allocation in [false, true]) {
      testWidgets(
        'GivenSettledSensitiveHistory_When$boundary${allocation ? 'Allocation' : 'Access'}Fails_ThenUndoAndRedoCannotRestoreDiscardedSource',
        (tester) async {
          var fail = false;
          Object error() =>
              allocation ? OutOfMemoryError() : StateError('access');
          final service = _Service(
            callback: (request) async {
              if (fail && boundary == 'service') throw error();
              return const GzipCompressService().execute(request);
            },
          );
          await tester.pumpWidget(
            ChimeraApp(
              initialLocation: '/gzip/compress',
              gzipCompressService: service,
              gzipCompressFilePicker: () async {
                if (fail) throw error();
                return [1];
              },
              gzipCompressClipboardReader: () async {
                if (fail) throw error();
                return 'pasted';
              },
              gzipCompressFileSaver: (_, _, _) async {
                if (fail) throw error();
                return true;
              },
            ),
          );
          await tester.pumpAndSettle();
          await _settledText(tester, 'discarded sensitive source');
          await _tap(tester, 'submit');
          fail = true;
          await _tap(tester, boundary == 'service' ? 'submit' : boundary);
          expect(_control('error'), findsOneWidget);
          await tester.tap(_control('input'));
          await tester.pump(const Duration(milliseconds: 600));
          for (final redo in [false, true, false]) {
            await _historyShortcut(tester, redo: redo);
            expect(
              tester.widget<TextField>(_control('input')).controller!.text,
              isEmpty,
            );
          }
          _noSuccess();
        },
      );
    }
  }

  for (final replacement in ['file', 'paste']) {
    testWidgets(
      'GivenSettledSensitiveHistory_When${replacement}ReplacesText_ThenUndoAndRedoCannotRestoreDiscardedSource',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/gzip/compress',
            gzipCompressFilePicker: () async => [255],
            gzipCompressClipboardReader: () async => 'new clipboard',
          ),
        );
        await tester.pumpAndSettle();
        await _settledText(tester, 'discarded sensitive source');
        await _tap(tester, replacement);
        await tester.tap(_control('input'));
        await tester.pump(const Duration(milliseconds: 600));
        for (final redo in [false, true, false]) {
          await _historyShortcut(tester, redo: redo);
          final text = tester
              .widget<TextField>(_control('input'))
              .controller!
              .text;
          expect(text, isNot(contains('discarded sensitive source')));
          if (replacement == 'file') expect(text, isEmpty);
        }
      },
    );
  }

  for (final afterReset in [false, true]) {
    testWidgets(
      'GivenNormalEditing${afterReset ? 'AfterSourceReset' : ''}_WhenKeyboardUndoAndRedoRun_ThenEditingHistoryStillWorks',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/gzip/compress',
            gzipCompressFilePicker: () async => [255],
          ),
        );
        await tester.pumpAndSettle();
        if (afterReset) {
          await _settledText(tester, 'discarded sensitive source');
          await _tap(tester, 'file');
        }
        await _settledText(tester, 'first edit');
        await _settledText(tester, 'second edit');
        final controller = tester
            .widget<TextField>(_control('input'))
            .controller!;
        await _historyShortcut(tester);
        expect(controller.text, 'first edit');
        await _historyShortcut(tester, redo: true);
        expect(controller.text, 'second edit');
      },
    );
  }

  for (final replacement in ['file', 'paste', 'dispose']) {
    testWidgets(
      'GivenPendingUndoSnapshot_When${replacement}DiscardsEditor_ThenOldHistoryIsDisposedAndCannotRestoreSource',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/gzip/compress',
            gzipCompressFilePicker: () async => [255],
            gzipCompressClipboardReader: () async => 'new text',
          ),
        );
        await tester.pumpAndSettle();
        await _settledText(tester, 'settled sensitive source');
        await tester.enterText(_control('input'), 'pending sensitive source');
        final oldHistory = tester.state<UndoHistoryState<TextEditingValue>>(
          find.byType(UndoHistory<TextEditingValue>),
        );
        if (replacement == 'dispose') {
          await tester.pumpWidget(const SizedBox());
        } else {
          await _tap(tester, replacement);
        }
        expect(oldHistory.mounted, isFalse);
        expect(UndoManager.client, isNot(same(oldHistory)));
        // The previous editor's pending 500ms snapshot must not outlive its reset.
        await tester.pump(const Duration(milliseconds: 600));
        if (replacement != 'dispose') {
          await tester.tap(_control('input'));
          await tester.pump(const Duration(milliseconds: 600));
          for (final redo in [false, true, false]) {
            await _historyShortcut(tester, redo: redo);
            expect(
              tester.widget<TextField>(_control('input')).controller!.text,
              isNot(contains('sensitive source')),
            );
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'GivenFileButtonFocus_WhenKeyboardLoadDiscardsText_ThenFocusAndControllerListenersSurvive',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/gzip/compress',
          gzipCompressFilePicker: () async => [255],
        ),
      );
      await tester.pumpAndSettle();
      await _settledText(tester, 'discarded sensitive source');
      final controller = tester
          .widget<TextField>(_control('input'))
          .controller!;
      var notifications = 0;
      void changed() => notifications++;
      controller.addListener(changed);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        find.ancestor(
          of: find.byWidget(
            FocusManager.instance.primaryFocus!.context!.widget,
          ),
          matching: _control('file'),
        ),
        findsOneWidget,
      );
      expect(
        identical(
          tester.widget<TextField>(_control('input')).controller,
          controller,
        ),
        isTrue,
      );
      expect(notifications, greaterThan(0));
      controller.removeListener(changed);
      await tester.tap(_control('input'));
      await tester.pump(const Duration(milliseconds: 600));
      await _historyShortcut(tester);
      expect(controller.text, isEmpty);
    },
  );

  testWidgets(
    'GivenSensitiveText_WhenPageIsDisposed_ThenControllerDropsSource',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(initialLocation: '/gzip/compress'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(_control('input'), 'sensitive source');
      final controller = tester
          .widget<TextField>(_control('input'))
          .controller!;
      await tester.pumpWidget(const SizedBox());
      expect(controller.text, isEmpty);
    },
  );

  test('GivenImmutableOutput_WhenPlatformSaveRuns_ThenSamePayloadAndMimeReachFilePickerOnce', () async {
    final original = FilePickerPlatform.instance;
    addTearDown(() => FilePickerPlatform.instance = original);
    final bytes = const GzipCompressor().compressText('hello').bytes;
    var calls = 0;
    FilePickerPlatform.instance = _SavePlatform((name, payload, mime) async {
      calls++;
      expect(name, 'chimera-compressed.gz');
      expect(identical(payload, bytes), isTrue);
      expect(mime, 'application/gzip');
      return Uri.file('chimera-compressed.gz');
    });
    expect(
      await saveGzipCompressFile(
        'chimera-compressed.gz',
        bytes,
        'application/gzip',
      ),
      isTrue,
    );
    expect(calls, 1);
  });

  for (final source in ['empty-file', 'empty-clipboard', 'missing-clipboard']) {
    testWidgets(
      'Given${source}_WhenCompressed_ThenValidEmptyMemberIsProduced',
      (tester) async {
        final service = _Service();
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/gzip/compress',
            gzipCompressService: service,
            gzipCompressFilePicker: () async => [],
            gzipCompressClipboardReader: () async =>
                source == 'missing-clipboard' ? null : '',
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(_control('input'), 'superseded');
        await _tap(tester, source == 'empty-file' ? 'file' : 'paste');
        await _tap(tester, 'submit');
        expect(service.calls, 1);
        expect(service.output!.inputByteCount, 0);
        expect(gzip.decode(service.output!.bytes), isEmpty);
      },
    );
  }

  for (final locale in ['en', 'pt-BR']) {
    for (final level in [0, 6, 9]) {
      for (final source in ['empty', 'text', 'file', 'clipboard']) {
        testWidgets(
          'Given${locale}_${source}_WhenCompressedAt${level}_ThenExactImmutablePayloadIsSavedOnce',
          (tester) async {
            final service = _Service();
            var saves = 0;
            final expected = switch (source) {
              'empty' => <int>[],
              'file' => [0, 255, 128, 1],
              _ => utf8.encode('Olá 🌍'),
            };
            await tester.pumpWidget(
              ChimeraApp(
                initialLocation: '/gzip/compress',
                localeTag: locale,
                gzipCompressService: service,
                gzipCompressFilePicker: () async => [0, 255, 128, 1],
                gzipCompressClipboardReader: () async => 'Olá 🌍',
                gzipCompressFileSaver: (name, bytes, mime) async {
                  saves++;
                  expect(name, 'chimera-compressed.gz');
                  expect(mime, 'application/gzip');
                  expect(identical(bytes, service.output!.bytes), isTrue);
                  expect(() => bytes[0] = 0, throwsUnsupportedError);
                  expect(gzip.decode(bytes), expected);
                  return true;
                },
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<DropdownButtonFormField<int>>(_control('level'))
                  .initialValue,
              6,
            );
            expect(
              tester
                  .widget<DropdownButton<int>>(
                    find.descendant(
                      of: _control('level'),
                      matching: find.byType(DropdownButton<int>),
                    ),
                  )
                  .items!
                  .map((item) => item.value),
              [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
            );
            if (level != 6) {
              await tester.tap(_control('level'));
              await tester.pumpAndSettle();
              await tester.tap(find.text('$level').last);
              await tester.pumpAndSettle();
            }
            if (source == 'text') {
              await tester.enterText(_control('input'), 'Olá 🌍');
            }
            if (source == 'file') await _tap(tester, 'file');
            if (source == 'clipboard') await _tap(tester, 'paste');
            await _tap(tester, 'submit');
            expect(service.calls, 1);
            expect(service.output!.level, level);
            expect(service.output!.inputByteCount, expected.length);
            expect(_control('result'), findsOneWidget);
            final summary = tester
                .widget<Semantics>(_control('result'))
                .properties
                .value!;
            expect(
              summary,
              contains(
                '${locale == 'en' ? 'Compression level' : 'Nível de compressão'}: $level',
              ),
            );
            expect(
              summary,
              contains(
                '${locale == 'en' ? 'Input bytes' : 'Bytes de entrada'}: ${expected.length}',
              ),
            );
            expect(
              summary,
              contains(
                '${locale == 'en' ? 'Output bytes' : 'Bytes de saída'}: ${service.output!.outputByteCount}',
              ),
            );
            expect(find.byType(SelectableText), findsNothing);
            expect(_control('copy'), findsNothing);
            await _tap(tester, 'save');
            expect(saves, 1);
            expect(
              find.text(
                locale == 'en' ? 'GZIP file saved.' : 'Arquivo GZIP salvo.',
              ),
              findsOneWidget,
            );
          },
        );
      }
    }

    testWidgets(
      'Given${locale}Result_WhenAccessibilityChecked_ThenSafeLiveSummaryAndGuidelinesPass',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          ChimeraApp(initialLocation: '/gzip/compress', localeTag: locale),
        );
        await tester.pumpAndSettle();
        await tester.enterText(_control('input'), 'secret input');
        await _tap(tester, 'submit');
        final result = tester.widget<Semantics>(_control('result'));
        expect(result.properties.liveRegion, isTrue);
        expect(result.properties.value, contains('12'));
        expect(result.properties.value, isNot(contains('secret input')));
        expect(
          result.properties.value,
          contains(
            locale == 'en' ? 'Compression succeeded.' : 'Compressão concluída.',
          ),
        );
        for (final name in ['file', 'paste', 'level', 'submit', 'save']) {
          final size = tester.getSize(_control(name));
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      },
    );

    testWidgets(
      'Given${locale}NarrowLargeText_WhenCompressed_ThenControlsAndSaveRemainReachable',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          ChimeraApp(initialLocation: '/gzip/compress', localeTag: locale),
        );
        await tester.pumpAndSettle();
        await _tap(tester, 'submit');
        await tester.ensureVisible(_control('save'));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final replacement in ['text', 'file', 'clipboard', 'level']) {
    testWidgets(
      'GivenSuccess_When${replacement}Changes_ThenOldResultAndNoticeAreCleared',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/gzip/compress',
            gzipCompressFilePicker: () async => [255],
            gzipCompressClipboardReader: () async => 'pasted',
            gzipCompressFileSaver: (_, _, _) async => true,
          ),
        );
        await tester.pumpAndSettle();
        await _tap(tester, 'submit');
        await _tap(tester, 'save');
        if (replacement == 'text') {
          await tester.enterText(_control('input'), 'new');
        }
        if (replacement == 'file') await _tap(tester, 'file');
        if (replacement == 'clipboard') await _tap(tester, 'paste');
        if (replacement == 'level') {
          tester
              .widget<DropdownButtonFormField<int>>(_control('level'))
              .onChanged!(9);
        }
        await tester.pumpAndSettle();
        _noSuccess();
      },
    );
  }

  for (final replacement in ['text', 'clipboard']) {
    testWidgets(
      'GivenFileSource_When${replacement}ReplacesIt_ThenOnlyNewTextIsCompressed',
      (tester) async {
        final service = _Service();
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/gzip/compress',
            gzipCompressService: service,
            gzipCompressFilePicker: () async => [255],
            gzipCompressClipboardReader: () async => 'new',
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(_control('input'), 'old text');
        await _tap(tester, 'file');
        expect(
          tester.widget<TextField>(_control('input')).controller!.text,
          isEmpty,
        );
        if (replacement == 'text') {
          await tester.enterText(_control('input'), 'new');
        }
        if (replacement == 'clipboard') await _tap(tester, 'paste');
        await _tap(tester, 'submit');
        expect(_control('file-summary'), findsNothing);
        expect(gzip.decode(service.output!.bytes), [110, 101, 119]);
      },
    );
  }

  for (final boundary in ['file', 'save']) {
    testWidgets(
      'GivenResult_When${boundary}IsCanceled_ThenNoErrorOrSuccessNoticeIsAdded',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/gzip/compress',
            gzipCompressFilePicker: () async => null,
            gzipCompressFileSaver: (_, _, _) async => false,
          ),
        );
        await tester.pumpAndSettle();
        await _tap(tester, 'submit');
        await _tap(tester, boundary);
        expect(_control('result'), findsOneWidget);
        expect(_control('error'), findsNothing);
        expect(_control('notice'), findsNothing);
      },
    );
  }

  for (final locale in ['en', 'pt-BR']) {
    for (final boundary in ['file', 'paste', 'save', 'service']) {
      for (final allocation in [false, true]) {
        testWidgets(
          'Given${locale}Success_When$boundary${allocation ? 'Allocation' : 'Access'}Fails_ThenRedactedLiveErrorClearsSourceAndResult',
          (tester) async {
            var fail = false;
            Object error() => allocation
                ? OutOfMemoryError()
                : StateError('SECRET /private/source');
            final service = _Service(
              callback: (request) async {
                if (fail && boundary == 'service') throw error();
                return const GzipCompressService().execute(request);
              },
            );
            await tester.pumpWidget(
              ChimeraApp(
                initialLocation: '/gzip/compress',
                localeTag: locale,
                gzipCompressService: service,
                gzipCompressFilePicker: () async {
                  if (fail) throw error();
                  return [1];
                },
                gzipCompressClipboardReader: () async {
                  if (fail) throw error();
                  return 'text';
                },
                gzipCompressFileSaver: (_, _, _) async {
                  if (fail) throw error();
                  return true;
                },
              ),
            );
            await tester.pumpAndSettle();
            await _tap(tester, 'file');
            await _tap(tester, 'submit');
            fail = true;
            await _tap(tester, boundary == 'service' ? 'submit' : boundary);
            _noSuccess();
            expect(_control('file-summary'), findsNothing);
            expect(
              tester.widget<TextField>(_control('input')).controller!.text,
              isEmpty,
            );
            final errorText = tester.widget<Text>(_control('error')).data!;
            expect(errorText, isNot(contains('SECRET')));
            expect(errorText, isNot(contains('/private')));
            expect(errorText, isNot(contains('error.')));
            expect(
              errorText,
              allocation
                  ? (locale == 'en'
                        ? 'GZIP compression exceeded its resource limit.'
                        : 'A compressão GZIP excedeu o limite de recursos.')
                  : switch ((locale, boundary)) {
                      ('en', 'file') => 'The input file could not be read.',
                      ('en', 'paste') =>
                        'The clipboard text could not be read.',
                      ('en', 'save') => 'The GZIP bytes could not be saved.',
                      ('en', _) => 'The input could not be processed.',
                      (_, 'file') =>
                        'Não foi possível ler o arquivo de entrada.',
                      (_, 'paste') => 'Não foi possível ler o texto da área de transferência.',
                      (_, 'save') => 'Não foi possível salvar os bytes GZIP.',
                      _ => 'Não foi possível processar a entrada.',
                    },
            );
            expect(
              find.byWidgetPredicate(
                (w) =>
                    w is Semantics &&
                    w.properties.liveRegion == true &&
                    w.child is Text &&
                    (w.child! as Text).data == errorText,
              ),
              findsOneWidget,
            );
          },
        );
      }
    }
  }

  for (final invalid in [
    'unicode',
    'bytes',
    'input-limit',
    'output-limit',
    'level',
  ]) {
    testWidgets(
      'Given${invalid}_WhenSubmitted_ThenTypedFailureHasNoPartialOutput',
      (tester) async {
        final service = invalid == 'level'
            ? _Service(
                callback: (_) => const GzipCompressService().execute(
                  GzipCompressOperationRequest.text('', level: 10),
                ),
              )
            : _Service(
                callback: (request) => GzipCompressService(
                  compressor: GzipCompressor(
                    maxInputBytes: invalid == 'input-limit' ? 0 : null,
                    maxOutputBytes: invalid == 'output-limit' ? 0 : null,
                  ),
                ).execute(request),
              );
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/gzip/compress',
            gzipCompressService: service,
            gzipCompressFilePicker: () async =>
                invalid == 'bytes' ? [256] : [1],
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
        expect(_control('error'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final boundary in ['file', 'paste', 'submit', 'save']) {
    for (final invalidate in ['text', 'level', 'dispose']) {
      for (final lateFailure in [false, true]) {
        testWidgets(
          'GivenPending${boundary}_When${invalidate}_ThenLate${lateFailure ? 'Failure' : 'Success'}CannotPublish',
          (tester) async {
            final pending = Completer<Object?>();
            var wait = false;
            final service = _Service(
              callback: (request) async {
                if (wait && boundary == 'submit') await pending.future;
                return const GzipCompressService().execute(request);
              },
            );
            await tester.pumpWidget(
              ChimeraApp(
                initialLocation: '/gzip/compress',
                gzipCompressService: service,
                gzipCompressFilePicker: () async {
                  if (wait) await pending.future;
                  return [255];
                },
                gzipCompressClipboardReader: () async {
                  if (wait) await pending.future;
                  return 'late';
                },
                gzipCompressFileSaver: (_, _, _) async {
                  if (wait) await pending.future;
                  return true;
                },
              ),
            );
            await tester.pumpAndSettle();
            await _tap(tester, 'submit');
            final changeLevel = tester
                .widget<DropdownButtonFormField<int>>(_control('level'))
                .onChanged!;
            wait = true;
            await _tap(tester, boundary);
            expect(
              tester.widget<TextField>(_control('input')).enabled,
              isFalse,
            );
            for (final name in ['file', 'paste', 'submit']) {
              expect(
                tester.widget<ButtonStyleButton>(_control(name)).onPressed,
                isNull,
              );
            }
            final level = tester.widget<DropdownButtonFormField<int>>(
              _control('level'),
            );
            expect(level.onChanged, isNull);
            if (boundary == 'file' || boundary == 'save') {
              expect(
                tester.widget<ButtonStyleButton>(_control('save')).onPressed,
                isNull,
              );
            }
            if (invalidate == 'dispose') {
              await tester.pumpWidget(const SizedBox());
            } else if (invalidate == 'text') {
              tester.widget<TextField>(_control('input')).onChanged!('new');
            } else {
              changeLevel(9);
            }
            if (lateFailure) {
              pending.completeError(StateError('SECRET'));
            } else {
              pending.complete(null);
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

  testWidgets(
    'GivenKeyboardUser_WhenTraversingAndActivating_ThenLogicalOrderAndResultFocusWork',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(initialLocation: '/gzip/compress'),
      );
      await tester.pumpAndSettle();
      expect(
        find.ancestor(
          of: find.byWidget(
            FocusManager.instance.primaryFocus!.context!.widget,
          ),
          matching: _control('input'),
        ),
        findsOneWidget,
      );
      for (final name in ['file', 'paste', 'level', 'submit']) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
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
      expect(_control('result'), findsOneWidget);
      expect(
        FocusManager.instance.primaryFocus!.debugLabel,
        'GZIP compression result',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        find.ancestor(
          of: find.byWidget(
            FocusManager.instance.primaryFocus!.context!.widget,
          ),
          matching: _control('save'),
        ),
        findsOneWidget,
      );
    },
  );
}
