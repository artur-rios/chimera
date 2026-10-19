import 'dart:async';
import 'dart:convert';
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_gui/qr_decode_page.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
// ignore: implementation_imports
import 'package:file_picker_web/src/file_picker_web_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GivenHomeAction_WhenActivated_ThenQrDecodeRouteOpens', (
    tester,
  ) async {
    await tester.pumpWidget(const ChimeraApp());
    final action = find.byKey(const Key('open-qr-decode'));
    expect(action, findsOneWidget);
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('qr-decode-file')), findsOneWidget);
  });

  test(
    'GivenWebPicker_WhenOpened_ThenUsesBoundedStreamWithoutPreloading',
    () async {
      FilePickerWebOptions? options;
      final bytes = await pickQrDecodeFile(
        pickPlatformFile: (value) async {
          options = value;
          return _ImageFile(
            chunks: [
              Uint8List.fromList([1, 2, 3]),
            ],
          );
        },
      );
      expect(bytes, [1, 2, 3]);
      // ignore: deprecated_member_use
      expect(options!.withData, isFalse);
      // ignore: deprecated_member_use
      expect(options!.withReadStream, isTrue);
    },
  );

  test('GivenKnownOversizedFile_WhenPicked_ThenNeverReadsImage', () async {
    final file = _ImageFile(knownLength: QrDecoder.defaultMaxInputBytes + 1);
    await expectLater(
      pickQrDecodeFile(pickPlatformFile: (_) async => file),
      throwsException,
    );
    expect(file.streamReads, 0);
  });

  test(
    'GivenUnknownLengthOversizedStream_WhenPicked_ThenStopsBeforeNextChunk',
    () async {
      final file = _ImageFile(
        chunks: [
          Uint8List(QrDecoder.defaultMaxInputBytes),
          Uint8List(1),
          Uint8List(1),
        ],
      );
      await expectLater(
        pickQrDecodeFile(pickPlatformFile: (_) async => file),
        throwsException,
      );
      expect(file.chunksRead, 2);
    },
  );

  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}Image_WhenDecoded_ThenLocalizedTextAndMetadataAppear',
      (tester) async {
        final bytes = _image();
        await tester.pumpWidget(
          _app(locale: locale, picker: () async => bytes),
        );
        await _decode(tester);
        expect(
          tester
              .widget<SelectableText>(find.byKey(const Key('qr-decode-result')))
              .data,
          'QR Olá 世界 🌍',
        );
        expect(find.textContaining('128 x 128'), findsOneWidget);
        expect(find.textContaining('png'), findsOneWidget);
        expect(
          find.text(locale == 'en' ? 'Copy text' : 'Copiar texto'),
          findsOneWidget,
        );
        expect(bytes.every((byte) => byte == 0), isTrue);
        expect(find.byKey(const Key('qr-decode-input-ready')), findsNothing);
        final region = tester.widget<Semantics>(
          find.byKey(const Key('qr-decode-result-semantics')),
        );
        expect(region.properties.role, SemanticsRole.region);
        expect(region.properties.liveRegion, isTrue);
        expect(
          tester.binding.focusManager.primaryFocus?.debugLabel,
          'QR decode result',
        );
      },
    );
  }

  testWidgets('GivenDecodedText_WhenCopiedAndSaved_ThenExactUnicodeIsUsed', (
    tester,
  ) async {
    String? copied;
    Uint8List? saved;
    Uint8List? transient;
    await tester.pumpWidget(
      _app(
        picker: () async => _image(),
        writer: (value) async => copied = value,
        saver: (name, bytes, mime) async {
          expect(name, 'chimera-qr-decoded.txt');
          expect(mime, 'text/plain');
          transient = bytes;
          saved = Uint8List.fromList(bytes);
          return true;
        },
      ),
    );
    await _decode(tester);
    await _tap(tester, 'copy');
    expect(copied, 'QR Olá 世界 🌍');
    expect(find.text('Decoded text copied.'), findsOneWidget);
    await _tap(tester, 'save');
    expect(utf8.decode(saved!), 'QR Olá 世界 🌍');
    expect(transient!.every((byte) => byte == 0), isTrue);
    expect(find.text('Decoded text saved.'), findsOneWidget);
  });

  testWidgets('GivenResult_WhenPickerCancelled_ThenResultAndNoticeRemain', (
    tester,
  ) async {
    var first = true;
    await tester.pumpWidget(
      _app(
        picker: () async {
          if (!first) return null;
          first = false;
          return _image();
        },
      ),
    );
    await _decode(tester);
    await _tap(tester, 'copy');
    await _tap(tester, 'file');
    expect(find.byKey(const Key('qr-decode-result')), findsOneWidget);
    expect(find.text('Decoded text copied.'), findsOneWidget);
  });

  testWidgets('GivenPendingImage_WhenPickerCancelled_ThenOriginalCanDecode', (
    tester,
  ) async {
    var picks = 0;
    await tester.pumpWidget(
      _app(picker: () async => picks++ == 0 ? _image() : null),
    );
    await _tap(tester, 'file');
    await _tap(tester, 'file');
    await _tap(tester, 'submit');
    expect(find.byKey(const Key('qr-decode-result')), findsOneWidget);
  });

  testWidgets('GivenResult_WhenNewInputChosen_ThenStaleTextClears', (
    tester,
  ) async {
    await tester.pumpWidget(_app(picker: () async => _image()));
    await _decode(tester);
    await _tap(tester, 'file');
    expect(find.byKey(const Key('qr-decode-result')), findsNothing);
    expect(find.byKey(const Key('qr-decode-input-ready')), findsOneWidget);
  });

  for (final failure in ['file', 'copy', 'save']) {
    testWidgets(
      'GivenResult_When${failure}Fails_ThenStaleTextClearsAndSafeErrorIsLive',
      (tester) async {
        var picks = 0;
        await tester.pumpWidget(
          _app(
            picker: () async {
              if (failure == 'file' && picks++ > 0) {
                throw StateError('private marker');
              }
              return _image();
            },
            writer: (_) async {
              if (failure == 'copy') throw StateError('private marker');
            },
            saver: (_, _, _) async {
              if (failure == 'save') throw StateError('private marker');
              return true;
            },
          ),
        );
        await _decode(tester);
        await _tap(tester, failure);
        expect(find.byKey(const Key('qr-decode-result')), findsNothing);
        expect(find.textContaining('private marker'), findsNothing);
        final error = find.byKey(const Key('qr-decode-error'));
        expect(error, findsOneWidget);
        expect(
          tester
              .widget<Semantics>(
                find
                    .ancestor(of: error, matching: find.byType(Semantics))
                    .first,
              )
              .properties
              .liveRegion,
          isTrue,
        );
      },
    );
  }

  testWidgets('GivenUnsupportedImage_WhenDecoded_ThenTypedFailureClearsBytes', (
    tester,
  ) async {
    final bytes = [1, 2, 3];
    await tester.pumpWidget(_app(picker: () async => bytes));
    await _decode(tester);
    expect(
      find.text('The image could not be decoded as a QR code.'),
      findsOneWidget,
    );
    expect(bytes, [0, 0, 0]);
    expect(find.byKey(const Key('qr-decode-result')), findsNothing);
  });

  testWidgets(
    'GivenImageOverConfiguredLimit_WhenDecoded_ThenResourceIsLocalized',
    (tester) async {
      final bytes = _image();
      await tester.pumpWidget(
        _app(
          locale: 'pt-BR',
          picker: () async => bytes,
          service: const QrDecodeService(decoder: QrDecoder(maxInputBytes: 3)),
        ),
      );
      await _decode(tester);
      expect(
        find.text('A decodificação QR excedeu seu limite de recursos.'),
        findsOneWidget,
      );
      expect(bytes.every((byte) => byte == 0), isTrue);
    },
  );

  testWidgets(
    'GivenOversizedPickedBytes_WhenLoaded_ThenResourcePrecedesDecode',
    (tester) async {
      final bytes = Uint8List(QrDecoder.defaultMaxInputBytes + 1)..[0] = 10;
      await tester.pumpWidget(_app(picker: () async => bytes));
      await _tap(tester, 'file');
      expect(
        find.text('QR decoding exceeded its resource limit.'),
        findsOneWidget,
      );
      expect(bytes.first, 0);
      expect(find.byKey(const Key('qr-decode-input-ready')), findsNothing);
    },
  );

  testWidgets('GivenPickerAllocationFailure_WhenLoaded_ThenResourceIsSafe', (
    tester,
  ) async {
    await tester.pumpWidget(_app(picker: () async => throw OutOfMemoryError()));
    await _tap(tester, 'file');
    expect(
      find.text('QR decoding exceeded its resource limit.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'GivenPendingDecode_WhenDisposed_ThenBytesClearAndLateResultIsIgnored',
    (tester) async {
      final bytes = _image();
      final pending = Completer<ChimeraResult<QrDecodeOutput>>();
      await tester.pumpWidget(
        _app(picker: () async => bytes, service: _PendingDecode(pending)),
      );
      await _tap(tester, 'file');
      await tester.tap(find.byKey(const Key('qr-decode-submit')));
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(bytes.every((byte) => byte == 0), isTrue);
      pending.complete(
        const ChimeraFailure(
          kind: FailureKind.processing,
          code: 'qr-decode.decoding',
          messageKey: 'error.qrDecode.decoding',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('qr-decode-result')), findsNothing);
    },
  );

  testWidgets('GivenPendingPicker_WhenDisposed_ThenLateBytesAreCleared', (
    tester,
  ) async {
    final pending = Completer<List<int>?>();
    final bytes = _image();
    await tester.pumpWidget(_app(picker: () => pending.future));
    await tester.tap(find.byKey(const Key('qr-decode-file')));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.complete(bytes);
    await tester.pumpAndSettle();
    expect(bytes.every((byte) => byte == 0), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'GivenKeyboardNavigation_WhenDecoding_ThenFocusFollowsActionsAndResult',
    (tester) async {
      await tester.pumpWidget(_app(picker: () async => _image()));
      await tester.pumpAndSettle();
      expect(_focusedKey(tester), const Key('qr-decode-file'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusedKey(tester), const Key('qr-decode-submit'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        'QR decode result',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusedKey(tester), const Key('qr-decode-copy'));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusedKey(tester), const Key('qr-decode-save'));
    },
  );

  testWidgets('GivenInvalidByte_WhenDecoded_ThenValidationIsLocalized', (
    tester,
  ) async {
    await tester.pumpWidget(_app(picker: () async => <int>[256]));
    await _decode(tester);
    expect(find.text('The QR decoding request is invalid.'), findsOneWidget);
  });

  testWidgets(
    'GivenResult_WhenSaveCancelled_ThenTextRemainsWithoutSuccessNotice',
    (tester) async {
      await tester.pumpWidget(
        _app(picker: () async => _image(), saver: (_, _, _) async => false),
      );
      await _decode(tester);
      await _tap(tester, 'save');
      expect(find.byKey(const Key('qr-decode-result')), findsOneWidget);
      expect(find.text('Decoded text saved.'), findsNothing);
      expect(find.byKey(const Key('qr-decode-error')), findsNothing);
    },
  );

  testWidgets(
    'GivenPendingImage_WhenReplacedOrDisposed_ThenAllOwnedImageBytesClear',
    (tester) async {
      final images = [_image(), _image()];
      var index = 0;
      await tester.pumpWidget(_app(picker: () async => images[index++]));
      await _tap(tester, 'file');
      await _tap(tester, 'file');
      expect(images.first.every((byte) => byte == 0), isTrue);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(images.last.every((byte) => byte == 0), isTrue);
      await tester.pumpWidget(_app());
      expect(find.byKey(const Key('qr-decode-result')), findsNothing);
      expect(find.byKey(const Key('qr-decode-input-ready')), findsNothing);
    },
  );

  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}NarrowLargeText_WhenDecoded_ThenActionsRemainAccessible',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          _app(locale: locale, picker: () async => _image()),
        );
        await _decode(tester);
        for (final name in ['file', 'submit', 'copy', 'save']) {
          final control = find.byKey(Key('qr-decode-$name'));
          await tester.ensureVisible(control);
          final size = tester.getSize(control);
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }

  testWidgets(
    'GivenLongMultilineQr_WhenDecoded_ThenTextScrollsWithinBoundedResult',
    (tester) async {
      final text = List.filled(80, 'line').join('\n');
      await tester.pumpWidget(
        _app(
          picker: () async =>
              Uint8List.fromList(const QrEncoder().encode(text).pngBytes),
        ),
      );
      await _decode(tester);
      final result = find.byKey(const Key('qr-decode-result'));
      final scroll = find
          .ancestor(of: result, matching: find.byType(SingleChildScrollView))
          .first;
      expect(tester.getSize(scroll).height, lessThanOrEqualTo(240));
      expect(tester.widget<SelectableText>(result).data, text);
    },
  );
}

Uint8List _image() => Uint8List.fromList(
  const QrEncoder().encode('QR Olá 世界 🌍', size: 128).pngBytes,
);

Widget _app({
  String locale = 'en',
  QrDecodeFilePicker? picker,
  QrDecodeClipboardWriter? writer,
  QrDecodeFileSaver? saver,
  QrDecodeOperationService service = const QrDecodeService(),
}) => MaterialApp(
  home: QrDecodePage(
    catalog: const MessageCatalog(),
    localeTag: locale,
    service: service,
    filePicker: picker ?? () async => null,
    clipboardWriter: writer ?? (_) async {},
    fileSaver: saver ?? (_, _, _) async => true,
  ),
);

Future<void> _tap(WidgetTester tester, String key) async {
  final control = find.byKey(Key('qr-decode-$key'));
  await tester.ensureVisible(control);
  await tester.tap(control);
  await tester.pumpAndSettle();
}

Future<void> _decode(WidgetTester tester) async {
  await _tap(tester, 'file');
  await _tap(tester, 'submit');
}

Key? _focusedKey(WidgetTester tester) {
  final context = tester.binding.focusManager.primaryFocus?.context;
  Key? key;
  context?.visitAncestorElements((element) {
    final candidate = element.widget.key;
    if (candidate is ValueKey<String> &&
        candidate.value.startsWith('qr-decode-')) {
      key = candidate;
    }
    return key == null;
  });
  return key;
}

final class _PendingDecode implements QrDecodeOperationService {
  _PendingDecode(this.pending);
  final Completer<ChimeraResult<QrDecodeOutput>> pending;
  @override
  Future<ChimeraResult<QrDecodeOutput>> execute(
    QrDecodeOperationRequest request,
  ) => pending.future;
}

final class _ImageFile extends PlatformFile {
  _ImageFile({this.knownLength, this.chunks = const []});
  final int? knownLength;
  final List<Uint8List> chunks;
  var streamReads = 0;
  var chunksRead = 0;
  @override
  String get name => 'qr.png';
  @override
  Uri get uri => Uri.file('/private/qr.png');
  @override
  XFile get xFile => throw UnimplementedError();
  @override
  int? lengthSync() => knownLength;
  @override
  Future<int?> length() async => knownLength;
  @override
  Future<Uint8List> readAsBytes() =>
      throw StateError('Eager reads are forbidden');
  @override
  Stream<Uint8List> readAsByteStream() async* {
    streamReads++;
    for (final chunk in chunks) {
      chunksRead++;
      yield chunk;
    }
  }
}
