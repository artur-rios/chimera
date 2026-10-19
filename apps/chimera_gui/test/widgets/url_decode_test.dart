import 'dart:async';
import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_gui/url_decode_page.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _control(String name) => find.byKey(Key('url-decode-$name'));

Future<void> _tap(WidgetTester tester, String name) async {
  await tester.ensureVisible(_control(name));
  await tester.tap(_control(name));
  await tester.pumpAndSettle();
}

void _expectNoSuccess() {
  expect(_control('result'), findsNothing);
  expect(_control('copy'), findsNothing);
  expect(_control('save'), findsNothing);
  expect(_control('notice'), findsNothing);
}

final class _Service
    implements OperationService<UrlDecodeOperationRequest, UrlDecodeOutput> {
  _Service({this.callback});

  final Future<ChimeraResult<UrlDecodeOutput>> Function(
    UrlDecodeOperationRequest,
  )?
  callback;
  int calls = 0;

  @override
  Future<ChimeraResult<UrlDecodeOutput>> execute(
    UrlDecodeOperationRequest request,
  ) {
    calls++;
    return callback?.call(request) ?? const UrlDecodeService().execute(request);
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

void main() {
  testWidgets(
    'GivenUrlDecodeRoute_WhenPercentEscapesSubmitted_ThenExactDecodedTextReturns',
    (tester) async {
      await tester.pumpWidget(const ChimeraApp(initialLocation: '/url/decode'));
      await tester.pumpAndSettle();
      await tester.enterText(_control('input'), '%3C%26%41%F0%9F%99%82%253C');
      await _tap(tester, 'submit');
      expect(
        tester.widget<SelectableText>(_control('output')).data,
        '<&A🙂%3C',
      );
      expect(
        tester.widget<TextField>(_control('input')).controller!.text,
        isEmpty,
      );
    },
  );

  for (final locale in ['en', 'pt-BR']) {
    for (final source in ['text', 'file', 'clipboard', 'empty']) {
      testWidgets('Given${locale}_$source'
          '_WhenDecoded_ThenExactTextCopiesAndSavesOnce', (tester) async {
        const encoded = '%22Olá%22%20%26%20%F0%9F%99%82';
        const decoded = '"Olá" & 🙂';
        final expected = source == 'empty' ? '' : decoded;
        var copies = 0;
        var saves = 0;
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/url/decode',
            localeTag: locale,
            urlDecodeFilePicker: () async => utf8.encode(encoded),
            urlDecodeClipboardReader: () async => encoded,
            urlDecodeClipboardWriter: (value) async {
              copies++;
              expect(value, expected);
            },
            urlDecodeFileSaver: (name, bytes, mime) async {
              saves++;
              expect(name, 'chimera-url-decoded.txt');
              expect(mime, 'text/plain; charset=utf-8');
              expect(bytes, utf8.encode(expected));
              return true;
            },
          ),
        );
        await tester.pumpAndSettle();
        if (source == 'text') {
          await tester.enterText(_control('input'), encoded);
        } else if (source == 'file') {
          await _tap(tester, 'file');
        } else if (source == 'clipboard') {
          await _tap(tester, 'paste');
        }
        await _tap(tester, 'submit');
        expect(
          tester.widget<SelectableText>(_control('output')).data,
          expected,
        );
        await _tap(tester, 'copy');
        expect(copies, 1);
        expect(
          find.text(
            locale == 'en'
                ? 'URL decoded text copied.'
                : 'Texto decodificado de URL copiado.',
          ),
          findsOneWidget,
        );
        await _tap(tester, 'save');
        expect(saves, 1);
        expect(
          find.text(
            locale == 'en'
                ? 'URL decoded text saved.'
                : 'Texto decodificado de URL salvo.',
          ),
          findsOneWidget,
        );
      });
    }
  }

  const invalidInputs = {
    '%': 'truncated-escape',
    '%G0': 'nonhex-escape',
    '%C3%28': 'invalid-percent-utf8',
    '%ED%A0%80': 'surrogate-percent-utf8',
    '%F4%90%80%80': 'out-of-range-percent-utf8',
  };
  for (final entry in invalidInputs.entries) {
    testWidgets(
      'Given${entry.value}_WhenDecoded_ThenSafeValidationClearsSourceAndResult',
      (tester) async {
        await tester.pumpWidget(
          const ChimeraApp(initialLocation: '/url/decode'),
        );
        await tester.pumpAndSettle();
        await tester.enterText(_control('input'), entry.key);
        await _tap(tester, 'submit');
        _expectNoSuccess();
        expect(
          tester.widget<Text>(_control('error')).data,
          'The URL decoding request is invalid.',
        );
        expect(find.text(entry.key), findsNothing);
      },
    );
  }

  testWidgets(
    'GivenInvalidUtf8File_WhenDecoded_ThenValidationIsSafeAndNoResultRemains',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/url/decode',
          urlDecodeFilePicker: () async => [0xc3, 0x28],
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'file');
      await _tap(tester, 'submit');
      _expectNoSuccess();
      expect(find.text('The URL decoding request is invalid.'), findsOneWidget);
    },
  );

  for (final kind in FailureKind.values) {
    testWidgets(
      'GivenTyped${kind.name}Failure_WhenServiceCompletes_ThenSafeCategoryIgnoresDetails',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/url/decode',
            urlDecodeService: _Service(
              callback: (_) async => ChimeraFailure<UrlDecodeOutput>(
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
          FailureKind.range => 'The URL decoding request is invalid.',
          FailureKind.resource => 'URL decoding exceeded its resource limit.',
          _ => 'The input could not be processed.',
        });
        _expectNoSuccess();
      },
    );
  }

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
        'GivenResult_When$boundary${allocation ? 'Allocation' : 'Access'}Fails_ThenOnlySafeLiveErrorRemains',
        (tester) async {
          var fail = false;
          Object error() => allocation
              ? OutOfMemoryError()
              : StateError('SECRET /private/input');
          final service = _Service(
            callback: (request) async {
              if (fail && boundary == 'service') throw error();
              return const UrlDecodeService().execute(request);
            },
          );
          await tester.pumpWidget(
            ChimeraApp(
              initialLocation: '/url/decode',
              urlDecodeService: service,
              urlDecodeFilePicker: () async {
                if (fail) throw error();
                return utf8.encode('%3C');
              },
              urlDecodeClipboardReader: () async {
                if (fail) throw error();
                return '%3C';
              },
              urlDecodeClipboardWriter: (_) async {
                if (fail) throw error();
              },
              urlDecodeFileSaver: (_, _, _) async {
                if (fail) throw error();
                return true;
              },
              urlDecodeOutputEncoder: (value) {
                if (fail && boundary == 'encoder') throw error();
                return utf8.encode(value);
              },
            ),
          );
          await tester.pumpAndSettle();
          await tester.enterText(_control('input'), '%3C');
          await _tap(tester, 'submit');
          await _tap(tester, 'copy');
          fail = true;
          await _tap(tester, switch (boundary) {
            'service' => 'submit',
            'encoder' => 'save',
            _ => boundary,
          });
          _expectNoSuccess();
          final message = tester.widget<Text>(_control('error')).data!;
          expect(message, isNot(contains('SECRET')));
          expect(
            message,
            allocation
                ? 'URL decoding exceeded its resource limit.'
                : switch (boundary) {
                    'file' => 'The input file could not be read.',
                    'paste' => 'The clipboard text could not be read.',
                    'copy' => 'The clipboard text could not be written.',
                    'save' ||
                    'encoder' => 'The URL decoded text could not be saved.',
                    _ => 'The input could not be processed.',
                  },
          );
        },
      );
    }
  }

  testWidgets(
    'GivenCanceledFileAndClipboard_WhenSelected_ThenExistingResultRemains',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/url/decode',
          urlDecodeFilePicker: () async => null,
          urlDecodeClipboardReader: () async => null,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(_control('input'), '%3Cold%3E');
      await _tap(tester, 'submit');
      for (final boundary in ['file', 'paste']) {
        await _tap(tester, boundary);
        expect(tester.widget<SelectableText>(_control('output')).data, '<old>');
      }
    },
  );

  testWidgets(
    'GivenPendingDecode_WhenPageDisposed_ThenLateCompletionCannotPublish',
    (tester) async {
      final pending = Completer<ChimeraResult<UrlDecodeOutput>>();
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/url/decode',
          urlDecodeService: _Service(callback: (_) => pending.future),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(_control('submit'));
      await tester.pump();
      expect(tester.widget<TextField>(_control('input')).enabled, isFalse);
      await tester.pumpWidget(const SizedBox());
      pending.complete(
        const ChimeraSuccess(UrlDecodeOutput(UrlDecodeResult(decoded: 'late'))),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('late'), findsNothing);
    },
  );

  testWidgets(
    'GivenSuccessfulDecode_WhenInputChanges_ThenStaleResultAndNoticeClear',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/url/decode',
          urlDecodeClipboardWriter: (_) async {},
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'submit');
      await _tap(tester, 'copy');
      await tester.enterText(_control('input'), '%26');
      await tester.pumpAndSettle();
      _expectNoSuccess();
    },
  );

  testWidgets(
    'GivenSensitiveEditor_WhenDecodeCompletes_ThenUndoHistoryCannotRestoreSource',
    (tester) async {
      await tester.pumpWidget(const ChimeraApp(initialLocation: '/url/decode'));
      await tester.pumpAndSettle();
      await tester.enterText(_control('input'), '%3Csensitive%3E');
      await tester.pump(const Duration(milliseconds: 600));
      final oldHistory = tester.state<UndoHistoryState<TextEditingValue>>(
        find.byType(UndoHistory<TextEditingValue>),
      );
      await _tap(tester, 'submit');
      expect(oldHistory.mounted, isFalse);
      expect(UndoManager.client, isNot(same(oldHistory)));
    },
  );

  testWidgets(
    'GivenKeyboardUser_WhenTraversingAndActivating_ThenResultCopySaveFollowInOrder',
    (tester) async {
      String? copied;
      var saves = 0;
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/url/decode',
          urlDecodeClipboardWriter: (value) async => copied = value,
          urlDecodeFileSaver: (_, _, _) async {
            saves++;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();
      for (final name in ['input', 'file', 'paste', 'submit']) {
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
        'URL decoding result',
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

  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}NarrowLargeText_WhenDecoded_ThenControlsRemainAccessible',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          ChimeraApp(initialLocation: '/url/decode', localeTag: locale),
        );
        await tester.pumpAndSettle();
        await _tap(tester, 'submit');
        for (final name in ['file', 'paste', 'submit', 'copy', 'save']) {
          await tester.ensureVisible(_control(name));
          final size = tester.getSize(_control(name));
          expect(size.width, greaterThanOrEqualTo(48), reason: name);
          expect(size.height, greaterThanOrEqualTo(48), reason: name);
        }
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      },
    );
  }

  test('GivenText_WhenOutputEncoded_ThenExactUtf8BytesReturn', () {
    expect(encodeUrlDecodeOutput('Olá 🙂'), utf8.encode('Olá 🙂'));
  });

  test('GivenZeroByteOutput_WhenSaved_ThenOneExactSaveHandoffOccurs', () async {
    final oldPlatform = FilePickerPlatform.instance;
    addTearDown(() => FilePickerPlatform.instance = oldPlatform);
    var calls = 0;
    FilePickerPlatform.instance = _SavePlatform((name, bytes, mime) async {
      calls++;
      expect(name, 'chimera-url-decoded.txt');
      expect(bytes, isEmpty);
      expect(mime, 'text/plain; charset=utf-8');
      return Uri.file('saved.txt');
    });
    expect(
      await saveUrlDecodeFile(
        'chimera-url-decoded.txt',
        Uint8List(0),
        'text/plain; charset=utf-8',
      ),
      isTrue,
    );
    expect(calls, 1);
  });
}
