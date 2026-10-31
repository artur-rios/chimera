import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_gui/empty_file_save.dart';
import 'package:chimera_gui/gzip_decompress_page.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _control(String name) => find.byKey(Key('gzip-decompress-$name'));

final class _Service
    implements
        OperationService<GzipDecompressOperationRequest, GzipDecompressOutput> {
  _Service(this.callback);

  final Future<ChimeraResult<GzipDecompressOutput>> Function(
    GzipDecompressOperationRequest,
  )
  callback;
  int calls = 0;
  GzipDecompressOutput? output;

  @override
  Future<ChimeraResult<GzipDecompressOutput>> execute(
    GzipDecompressOperationRequest request,
  ) async {
    calls++;
    final result = await callback(request);
    result.fold(onSuccess: (value) => output = value, onFailure: (_) {});
    return result;
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

Future<void> _tap(WidgetTester tester, String name) async {
  await tester.ensureVisible(_control(name));
  await tester.tap(_control(name));
  await tester.pumpAndSettle();
}

Uint8List _gzip(List<int> bytes) => Uint8List.fromList(gzip.encode(bytes));

void main() {
  for (final payload in [
    Uint8List(0),
    Uint8List.fromList([0, 255]),
  ]) {
    test(
      'GivenNative${payload.isEmpty ? 'Empty' : 'NonEmpty'}Bytes_WhenGenericEmptySaveRuns_ThenNormalPickerCanHandlePayload',
      () async {
        expect(
          await trySaveEmptyFile(
            'generic-output.txt',
            payload,
            'text/plain; charset=utf-8',
          ),
          isNull,
        );
      },
    );
  }

  test('GivenImmutableTextOutput_WhenPlatformSaveRuns_ThenSamePayloadNameAndMimeReachPickerOnce', () async {
    final original = FilePickerPlatform.instance;
    addTearDown(() => FilePickerPlatform.instance = original);
    final bytes = const GzipDecompressor()
        .decompressBytes(
          _gzip(utf8.encode('exact')),
          mode: GzipDecompressMode.text,
        )
        .bytes;
    var calls = 0;
    FilePickerPlatform.instance = _SavePlatform((name, payload, mime) async {
      calls++;
      expect(name, 'chimera-decompressed.txt');
      expect(identical(payload, bytes), isTrue);
      expect(mime, 'text/plain; charset=utf-8');
      return Uri.file(name);
    });
    expect(
      await saveGzipDecompressFile(
        'chimera-decompressed.txt',
        bytes,
        'text/plain; charset=utf-8',
      ),
      isTrue,
    );
    expect(calls, 1);
  });

  test('GivenNativeSaveCancellation_WhenPickerReturnsNull_ThenAdapterReportsCancellation', () async {
    final original = FilePickerPlatform.instance;
    addTearDown(() => FilePickerPlatform.instance = original);
    var calls = 0;
    FilePickerPlatform.instance = _SavePlatform((name, bytes, mime) async {
      calls++;
      expect(name, 'chimera-decompressed.bin');
      expect(bytes, isEmpty);
      expect(mime, 'application/octet-stream');
      return null;
    });

    expect(
      await saveGzipDecompressFile(
        'chimera-decompressed.bin',
        Uint8List(0),
        'application/octet-stream',
      ),
      isFalse,
    );
    expect(calls, 1);
  });

  test(
    'GivenPlatformSaveFailure_WhenPickerThrows_ThenAdapterPropagatesFailure',
    () async {
      final original = FilePickerPlatform.instance;
      addTearDown(() => FilePickerPlatform.instance = original);
      final failure = StateError('save failed');
      FilePickerPlatform.instance = _SavePlatform((_, _, _) async {
        throw failure;
      });

      await expectLater(
        saveGzipDecompressFile(
          'chimera-decompressed.bin',
          Uint8List.fromList([0, 255]),
          'application/octet-stream',
        ),
        throwsA(same(failure)),
      );
    },
  );

  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}TextFile_WhenDecompressed_ThenExactTextCanBeCopiedAndSaved',
      (tester) async {
        final source = _gzip(utf8.encode('\uFEFFOlá'));
        String? copied;
        String? savedName;
        String? savedMime;
        Uint8List? savedBytes;

        await tester.pumpWidget(
          ChimeraApp(
            localeTag: locale,
            initialLocation: '/gzip/decompress',
            gzipDecompressFilePicker: () async => source,
            gzipDecompressClipboardWriter: (value) async => copied = value,
            gzipDecompressFileSaver: (name, bytes, mime) async {
              savedName = name;
              savedMime = mime;
              savedBytes = bytes;
              return true;
            },
          ),
        );
        await tester.pumpAndSettle();

        await _tap(tester, 'file');
        expect(find.textContaining('${source.length}'), findsOneWidget);
        await _tap(tester, 'submit');

        expect(_control('result'), findsOneWidget);
        expect(
          tester.widget<SelectableText>(_control('text')).data,
          '\uFEFFOlá',
        );
        expect(_control('file-summary'), findsNothing);
        await _tap(tester, 'copy');
        expect(copied, '\uFEFFOlá');
        await _tap(tester, 'save');
        expect(savedName, 'chimera-decompressed.txt');
        expect(savedMime, 'text/plain; charset=utf-8');
        expect(savedBytes, utf8.encode('\uFEFFOlá'));
        expect(
          find.textContaining(locale == 'en' ? 'saved' : 'salvos'),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets(
    'GivenExtensionIndependentBinaryFile_WhenBinaryModeSelected_ThenOnlyCountsAndExactSaveArePublished',
    (tester) async {
      final payload = Uint8List.fromList([0, 255, 128, 1]);
      final source = _gzip(payload);
      var saves = 0;
      Uint8List? handedOff;
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/gzip/decompress',
          gzipDecompressFilePicker: () async => source,
          gzipDecompressFileSaver: (name, bytes, mime) async {
            saves++;
            expect(name, 'chimera-decompressed.bin');
            expect(mime, 'application/octet-stream');
            handedOff = bytes;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await _tap(tester, 'file');
      await _tap(tester, 'mode-binary');
      await _tap(tester, 'submit');

      expect(_control('text'), findsNothing);
      expect(_control('copy'), findsNothing);
      expect(find.text('Output bytes: 4'), findsOneWidget);
      await _tap(tester, 'save');
      expect(saves, 1);
      expect(handedOff, payload);
    },
  );

  testWidgets(
    'GivenImmutableServiceOutput_WhenSaved_ThenOneExactPayloadIdentityIsHandedOff',
    (tester) async {
      final service = _Service(
        (request) => const GzipDecompressService().execute(request),
      );
      var saves = 0;
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/gzip/decompress',
          gzipDecompressService: service,
          gzipDecompressFilePicker: () async => _gzip(utf8.encode('identity')),
          gzipDecompressFileSaver: (_, bytes, _) async {
            saves++;
            expect(identical(bytes, service.output!.bytes), isTrue);
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'file');
      await _tap(tester, 'submit');
      await _tap(tester, 'save');
      expect(service.calls, 1);
      expect(saves, 1);
    },
  );

  testWidgets(
    'GivenInvalidUtf8Archive_WhenModeChangesToBinary_ThenStaleErrorClearsAndBytesSucceed',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/gzip/decompress',
          gzipDecompressFilePicker: () async => _gzip([255, 128]),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'file');
      await _tap(tester, 'submit');
      expect(_control('error'), findsOneWidget);
      await _tap(tester, 'mode-binary');
      expect(_control('error'), findsNothing);
      await _tap(tester, 'file');
      await _tap(tester, 'submit');
      expect(find.text('Output bytes: 2'), findsOneWidget);
      expect(_control('copy'), findsNothing);
    },
  );

  testWidgets(
    'GivenCompletedResult_WhenSaveIsCancelled_ThenResultRemainsWithoutNoticeOrError',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/gzip/decompress',
          gzipDecompressFilePicker: () async => _gzip(utf8.encode('kept')),
          gzipDecompressFileSaver: (_, _, _) async => false,
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'file');
      await _tap(tester, 'submit');
      await _tap(tester, 'save');
      expect(_control('result'), findsOneWidget);
      expect(_control('notice'), findsNothing);
      expect(_control('error'), findsNothing);
    },
  );

  testWidgets(
    'GivenEmptyPayloadMember_WhenTextModeDecompressed_ThenEmptySelectableTextSucceeds',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/gzip/decompress',
          gzipDecompressFilePicker: () async => _gzip(const []),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'file');
      await _tap(tester, 'submit');
      expect(tester.widget<SelectableText>(_control('text')).data, isEmpty);
      expect(find.text('Output bytes: 0'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenCancelledPicker_WhenResultExists_ThenCancellationIsNeutral',
    (tester) async {
      var cancel = false;
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/gzip/decompress',
          gzipDecompressFilePicker: () async =>
              cancel ? null : _gzip(utf8.encode('kept')),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'file');
      await _tap(tester, 'submit');
      cancel = true;
      await _tap(tester, 'file');
      expect(tester.widget<SelectableText>(_control('text')).data, 'kept');
    },
  );

  for (final failure in ['file', 'copy', 'save']) {
    testWidgets(
      'Given$failure AccessFailure_WhenActionRuns_ThenSafeLocalizedErrorClearsSourceAndResult',
      (tester) async {
        var fail = failure == 'file';
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/gzip/decompress',
            gzipDecompressFilePicker: () async {
              if (fail) throw StateError('secret path');
              return _gzip(utf8.encode('secret output'));
            },
            gzipDecompressClipboardWriter: (_) async {
              if (failure == 'copy') throw StateError('secret text');
            },
            gzipDecompressFileSaver: (_, _, _) async {
              if (failure == 'save') throw StateError('secret bytes');
              return true;
            },
          ),
        );
        await tester.pumpAndSettle();
        if (failure != 'file') {
          await _tap(tester, 'file');
          await _tap(tester, 'submit');
          fail = true;
        }
        await _tap(tester, failure);
        expect(_control('error'), findsOneWidget);
        expect(find.textContaining('secret'), findsNothing);
        expect(_control('result'), findsNothing);
        expect(_control('file-summary'), findsNothing);
      },
    );
  }

  testWidgets(
    'GivenCorruptArchive_WhenDecompressed_ThenTypedFailureIsRedactedAndNoPartialOutputAppears',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/gzip/decompress',
          gzipDecompressFilePicker: () async => [31, 139, 8, 0, 1],
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'file');
      await _tap(tester, 'submit');
      expect(
        find.text('The GZIP data could not be decompressed.'),
        findsOneWidget,
      );
      expect(_control('result'), findsNothing);
      expect(_control('file-summary'), findsNothing);
    },
  );

  testWidgets(
    'GivenOutputResourceLimit_WhenDecompressed_ThenResourceFailureIsLocalized',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/gzip/decompress',
          gzipDecompressService: GzipDecompressService(
            decompressor: const GzipDecompressor(maxOutputBytes: 1),
          ),
          gzipDecompressFilePicker: () async => _gzip(utf8.encode('large')),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'file');
      await _tap(tester, 'submit');
      expect(
        find.text('GZIP decompression exceeded its resource limit.'),
        findsOneWidget,
      );
      expect(_control('result'), findsNothing);
    },
  );

  testWidgets(
    'GivenPendingDecompression_WhenPageIsDisposed_ThenStaleCompletionIsIgnoredAndControlsRaceSafely',
    (tester) async {
      final completer = Completer<ChimeraResult<GzipDecompressOutput>>();
      final service = _Service((_) => completer.future);
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/gzip/decompress',
          gzipDecompressService: service,
          gzipDecompressFilePicker: () async => _gzip(utf8.encode('stale')),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'file');
      await tester.tap(_control('submit'));
      await tester.pump();
      expect(
        tester.widget<ButtonStyleButton>(_control('file')).onPressed,
        isNull,
      );
      expect(
        tester.widget<ButtonStyleButton>(_control('submit')).onPressed,
        isNull,
      );

      final segment = tester.widget<SegmentedButton<GzipDecompressMode>>(
        _control('mode'),
      );
      expect(segment.onSelectionChanged, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      completer.complete(
        await const GzipDecompressService().execute(
          GzipDecompressOperationRequest.bytes(
            _gzip(utf8.encode('stale')),
            mode: GzipDecompressMode.text,
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  for (final boundary in ['file', 'copy', 'save']) {
    testWidgets(
      'GivenPending${boundary}_WhenPageIsDisposed_ThenLateCompletionCannotPublish',
      (tester) async {
        final pending = Completer<void>();
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/gzip/decompress',
            gzipDecompressFilePicker: () async {
              if (boundary == 'file') await pending.future;
              return _gzip(utf8.encode('late'));
            },
            gzipDecompressClipboardWriter: (_) async {
              if (boundary == 'copy') await pending.future;
            },
            gzipDecompressFileSaver: (_, _, _) async {
              if (boundary == 'save') await pending.future;
              return true;
            },
          ),
        );
        await tester.pumpAndSettle();
        if (boundary != 'file') {
          await _tap(tester, 'file');
          await _tap(tester, 'submit');
        }
        await tester.tap(_control(boundary));
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());
        pending.complete();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'GivenSuccessfulResult_WhenKeyboardTraverses_ThenResultCopyAndSaveFollowSubmit',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/gzip/decompress',
          gzipDecompressFilePicker: () async => _gzip(utf8.encode('focus')),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus!.debugLabel,
        'GZIP decompression file',
      );
      await _tap(tester, 'file');
      await _tap(tester, 'submit');
      expect(
        FocusManager.instance.primaryFocus!.debugLabel,
        'GZIP decompression result',
      );
      expect(
        tester.widget<Semantics>(_control('result')).properties.liveRegion,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        find.ancestor(
          of: find.byWidget(
            FocusManager.instance.primaryFocus!.context!.widget,
          ),
          matching: _control('copy'),
        ),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
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

  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}CompletedPage_WhenAccessibilityAndLargeTextChecked_ThenGuidelinesAndLayoutPass',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          ChimeraApp(
            localeTag: locale,
            initialLocation: '/gzip/decompress',
            gzipDecompressFilePicker: () async =>
                _gzip(utf8.encode('accessible')),
          ),
        );
        await tester.pumpAndSettle();
        await _tap(tester, 'file');
        await _tap(tester, 'submit');
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      },
    );
  }
}
