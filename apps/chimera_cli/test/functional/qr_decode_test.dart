import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

List<int> _image([String text = 'Olá 😀\nsecond line']) =>
    List<int>.of(const QrEncoder().encode(text, size: 256).pngBytes);

void main() {
  test('GivenGlobalHelp_WhenRun_ThenQrDecodeIsDiscoverable', () async {
    for (final locale in ['en', 'pt-BR']) {
      final out = StringBuffer();
      final exitCode = await runChimera(
        ['--help'],
        localeTag: locale,
        out: out,
        err: StringBuffer(),
      );
      expect(exitCode, 0);
      expect(out.toString(), contains('chimera qr decode'));
    }
  });

  test('GivenBinaryFile_WhenDecoded_ThenExactUnicodeTextIsPrinted', () async {
    final out = StringBuffer();
    final err = StringBuffer();
    final bytes = _image();
    final exitCode = await runChimera(
      ['qr', 'decode', '--file=private.png'],
      localeTag: 'en',
      out: out,
      err: err,
      readFileBytes: (path) async {
        expect(path, 'private.png');
        return bytes;
      },
    );
    expect(exitCode, 0);
    expect(out.toString(), 'Olá 😀\nsecond line\n');
    expect(err.toString(), isEmpty);
    expect(bytes.every((byte) => byte == 0), isTrue);
  });

  test('GivenBinaryStdin_WhenDecodedAsJson_ThenMetadataIsStable', () async {
    final out = StringBuffer();
    final err = StringBuffer();
    final bytes = _image('plain');
    final count = bytes.length;
    final exitCode = await runChimera(
      ['qr', 'decode', '--stdin', '--json'],
      localeTag: 'pt-BR',
      out: out,
      err: err,
      readStandardInputBytes: () async => bytes,
    );
    expect(exitCode, 0);
    expect(jsonDecode(out.toString()), {
      'text': 'plain',
      'format': 'png',
      'width': 256,
      'height': 256,
      'inputByteCount': count,
    });
    expect((jsonDecode(out.toString()) as Map).keys, [
      'text',
      'format',
      'width',
      'height',
      'inputByteCount',
    ]);
    expect(out.toString(), endsWith('\n'));
    expect(err.toString(), isEmpty);
  });

  test(
    'GivenInvalidSourcesOrOptions_WhenRun_ThenValidationPrecedesIo',
    () async {
      final cases = <List<String>>[
        [],
        ['--file=image.png', '--stdin'],
        ['--file='],
        ['--stdin', '--output='],
        ['--stdin', 'private-extra'],
        ['--text=private-marker'],
        ['--stdin', '--size=private-marker'],
        ['--stdin=false'],
      ];
      for (final options in cases) {
        final out = StringBuffer();
        final err = StringBuffer();
        var reads = 0;
        final exitCode = await runChimera(
          ['qr', 'decode', ...options, '--json'],
          localeTag: 'pt-BR',
          out: out,
          err: err,
          readStandardInputBytes: () async {
            reads++;
            return _image();
          },
          readFileBytes: (_) async {
            reads++;
            return _image();
          },
        );
        expect(exitCode, 64, reason: '$options');
        expect(reads, 0, reason: '$options');
        expect(out.toString(), isEmpty);
        final failure = (jsonDecode(err.toString()) as Map)['error'] as Map;
        expect(failure['kind'], 'validation');
        expect(failure['code'], startsWith('qr-decode.'));
        expect(
          failure['message'],
          'A solicitação de decodificação QR é inválida.',
        );
        expect(err.toString(), isNot(contains('private-marker')));
        expect(err.toString(), isNot(contains('private-extra')));
      }
    },
  );

  test(
    'GivenMissingOptionValue_WhenParsed_ThenLocalizedJsonValidationReturns',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();
      final exitCode = await runChimera(
        ['qr', 'decode', '--json', '--file'],
        localeTag: 'en',
        out: out,
        err: err,
      );
      expect(exitCode, 64);
      expect(out.toString(), isEmpty);
      final error = (jsonDecode(err.toString()) as Map)['error'] as Map;
      expect(error['code'], 'qr-decode.invalid-options');
    },
  );

  test(
    'GivenUnsupportedBinary_WhenDecoded_ThenSafeProcessingErrorReturns',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();
      final bytes = utf8.encode('private-image-marker');
      final exitCode = await runChimera(
        ['qr', 'decode', '--stdin', '--json'],
        localeTag: 'en',
        out: out,
        err: err,
        readStandardInputBytes: () async => bytes,
      );
      expect(exitCode, 70);
      expect(out.toString(), isEmpty);
      expect(err.toString(), contains('qr-decode.decoding'));
      expect(err.toString(), isNot(contains('private-image-marker')));
      expect(bytes.every((byte) => byte == 0), isTrue);
    },
  );

  test(
    'GivenOversizedSource_WhenRead_ThenLimitPrecedesDecodingAndBytesClear',
    () async {
      final bytes = List<int>.filled(16 * 1024 * 1024 + 1, 255);
      final err = StringBuffer();
      final exitCode = await runChimera(
        ['qr', 'decode', '--stdin', '--json'],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
        readStandardInputBytes: () async => bytes,
      );
      expect(exitCode, 75);
      expect(err.toString(), contains('qr-decode.resource-limit'));
      expect(err.toString(), contains('byte-limit'));
      expect(bytes.every((byte) => byte == 0), isTrue);
    },
  );

  test('GivenInputFailures_WhenRun_ThenLocalizedAccessErrorIsSafe', () async {
    for (final useStdin in [false, true]) {
      final out = StringBuffer();
      final err = StringBuffer();
      final exitCode = await runChimera(
        ['qr', 'decode', if (useStdin) '--stdin' else '--file=private.png'],
        localeTag: 'pt-BR',
        out: out,
        err: err,
        readStandardInputBytes: () async => throw StateError('private-read'),
        readFileBytes: (_) async => throw StateError('private-read'),
      );
      expect(exitCode, 74);
      expect(out.toString(), isEmpty);
      expect(
        err.toString(),
        useStdin
            ? 'Não foi possível ler a entrada padrão.\n'
            : 'Não foi possível ler a imagem QR.\n',
      );
      expect(err.toString(), isNot(contains('private')));
    }
  });

  test('GivenUtf8Output_WhenSaved_ThenExactBytesHaveNoAddedNewline', () async {
    final temp = await Directory.systemTemp.createTemp('chimera-qr-decode-');
    addTearDown(() => temp.delete(recursive: true));
    final source = File('${temp.path}/source.png');
    final output = File('${temp.path}/output.txt');
    await source.writeAsBytes(_image('Olá 😀\n'));
    await output.writeAsString('old destination content');
    final out = StringBuffer();
    final err = StringBuffer();
    final exitCode = await runChimera(
      ['qr', 'decode', '--file=${source.path}', '--output=${output.path}'],
      localeTag: 'en',
      out: out,
      err: err,
    );
    expect(exitCode, 0);
    expect(await output.readAsBytes(), utf8.encode('Olá 😀\n'));
    expect(out.toString(), 'Olá 😀\n\n');
    expect(err.toString(), isEmpty);
    expect(await temp.list().length, 2);
  });

  test(
    'GivenFailedOutputStage_WhenSaving_ThenDestinationAndCleanupArePreserved',
    () async {
      final temp = await Directory.systemTemp.createTemp('chimera-qr-decode-');
      addTearDown(() => temp.delete(recursive: true));
      final output = File('${temp.path}/output.txt');
      await output.writeAsString('existing');
      final out = StringBuffer();
      final err = StringBuffer();
      final exitCode = await runChimera(
        ['qr', 'decode', '--stdin', '--output=${output.path}', '--json'],
        localeTag: 'en',
        out: out,
        err: err,
        readStandardInputBytes: () async => _image(),
        writeOutputStage: (path, bytes) async {
          await File(path).writeAsBytes(bytes.take(2).toList());
          throw StateError('private-write');
        },
      );
      expect(exitCode, 74);
      expect(await output.readAsString(), 'existing');
      expect(await temp.list().length, 1);
      expect(out.toString(), isEmpty);
      expect(err.toString(), contains('qr-decode.output-access'));
      expect(err.toString(), isNot(contains('private-write')));
      expect(err.toString(), isNot(contains('Olá')));
    },
  );

  test(
    'GivenConfiguredServiceLimits_WhenDecoded_ThenResourceFailureIsPreserved',
    () async {
      for (final decoder in [
        const QrDecoder(maxInputBytes: 1),
        const QrDecoder(maxPixels: 1),
        const QrDecoder(maxOutputBytes: 1),
      ]) {
        final bytes = _image('private decoded text');
        final out = StringBuffer();
        final err = StringBuffer();
        final exitCode = await runChimera(
          ['qr', 'decode', '--stdin', '--json'],
          localeTag: 'pt-BR',
          out: out,
          err: err,
          qrDecodeService: QrDecodeService(decoder: decoder),
          readStandardInputBytes: () async => bytes,
        );
        expect(exitCode, 75);
        expect(out.toString(), isEmpty);
        expect(err.toString(), contains('qr-decode.resource'));
        expect(
          err.toString(),
          contains('A decodificação QR excedeu seu limite de recursos.'),
        );
        expect(err.toString(), isNot(contains('private decoded text')));
        expect(bytes.every((byte) => byte == 0), isTrue);
      }
    },
  );

  test(
    'GivenAllocationFailures_WhenReadSerializedOrSaved_ThenResourceExitIsSafe',
    () async {
      for (final boundary in ['input', 'json', 'output']) {
        final out = StringBuffer();
        final err = StringBuffer();
        var writes = 0;
        final exitCode = await runChimera(
          ['qr', 'decode', '--stdin', '--output=private-path', '--json'],
          localeTag: 'en',
          out: out,
          err: err,
          readStandardInputBytes: () async => boundary == 'input'
              ? throw OutOfMemoryError()
              : _image('private content'),
          qrDecodeJsonEncoder: boundary == 'json'
              ? (_) => throw OutOfMemoryError()
              : null,
          writeOutputFile: (_, _) async {
            writes++;
            throw OutOfMemoryError();
          },
        );
        expect(exitCode, 75, reason: boundary);
        expect(writes, boundary == 'output' ? 1 : 0);
        expect(out.toString(), isEmpty);
        expect(err.toString(), contains('allocation-limit'));
        expect(err.toString(), isNot(contains('private')));
      }
    },
  );

  test(
    'GivenSerializerFailure_WhenJsonRequested_ThenNoFileOrContentIsPublished',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();
      var writes = 0;
      final exitCode = await runChimera(
        ['qr', 'decode', '--stdin', '--output=private-path', '--json'],
        localeTag: 'en',
        out: out,
        err: err,
        readStandardInputBytes: () async => _image('private content'),
        qrDecodeJsonEncoder: (_) => throw StateError('private serializer'),
        writeOutputFile: (_, _) async {
          writes++;
        },
      );
      expect(exitCode, 70);
      expect(writes, 0);
      expect(out.toString(), isEmpty);
      expect(err.toString(), contains('qr-decode.decoding'));
      expect(err.toString(), isNot(contains('private')));
    },
  );

  test(
    'GivenStdoutAllocationFailure_WhenPublishing_ThenResourceExitIsSafe',
    () async {
      final err = StringBuffer();
      final exitCode = await runChimera(
        ['qr', 'decode', '--stdin', '--json'],
        localeTag: 'en',
        out: _DeniedSink(OutOfMemoryError()),
        err: err,
        readStandardInputBytes: () async => _image('private content'),
      );
      expect(exitCode, 75);
      expect(err.toString(), contains('qr-decode.resource-limit'));
      expect(err.toString(), isNot(contains('private')));
    },
  );

  test('GivenDeniedStdout_WhenPublishing_ThenOutputAccessExitIsSafe', () async {
    final err = StringBuffer();
    final exitCode = await runChimera(
      ['qr', 'decode', '--stdin', '--json'],
      localeTag: 'en',
      out: _DeniedSink(StateError('private stdout')),
      err: err,
      readStandardInputBytes: () async => _image('private content'),
    );
    expect(exitCode, 74);
    expect(err.toString(), contains('qr-decode.output-access'));
    expect(err.toString(), isNot(contains('private')));
  });

  test(
    'GivenFailedReplacement_WhenSaving_ThenOriginalDestinationIsRestored',
    () async {
      final temp = await Directory.systemTemp.createTemp('chimera-qr-decode-');
      addTearDown(() => temp.delete(recursive: true));
      final output = File('${temp.path}/output.txt');
      await output.writeAsString('original');
      final out = StringBuffer();
      final err = StringBuffer();
      final exitCode = await runChimera(
        ['qr', 'decode', '--stdin', '--output=${output.path}', '--json'],
        localeTag: 'en',
        out: out,
        err: err,
        readStandardInputBytes: () async => _image(),
        outputFileOperations: TransactionalFileOperations(
          rename: (source, destination) async {
            if (source.path.contains('.chimera-stage-')) {
              throw StateError('private-rename');
            }
            await source.rename(destination);
          },
        ),
      );
      expect(exitCode, 74);
      expect(await output.readAsString(), 'original');
      expect(await temp.list().length, 1);
      expect(out.toString(), isEmpty);
      expect(err.toString(), contains('qr-decode.output-access'));
      expect(err.toString(), isNot(contains('private-rename')));
    },
  );

  test(
    'GivenOversizedFile_WhenRead_ThenBoundedReadReturnsResourceExit',
    () async {
      final temp = await Directory.systemTemp.createTemp('chimera-qr-decode-');
      addTearDown(() => temp.delete(recursive: true));
      final file = File('${temp.path}/oversized.png');
      final handle = await file.open(mode: FileMode.write);
      await handle.truncate(16 * 1024 * 1024 + 1);
      await handle.close();
      final out = StringBuffer();
      final err = StringBuffer();
      final exitCode = await runChimera(
        ['qr', 'decode', '--file=${file.path}', '--json'],
        localeTag: 'en',
        out: out,
        err: err,
      );
      expect(exitCode, 75);
      expect(out.toString(), isEmpty);
      expect(err.toString(), contains('byte-limit'));
    },
  );

  group('Native stdin', () {
    late Directory buildDirectory;
    late String executable;
    setUpAll(() async {
      buildDirectory = await Directory.systemTemp.createTemp('chimera-qr-cli-');
      addTearDown(() => buildDirectory.delete(recursive: true));
      executable =
          '${buildDirectory.path}/chimera${Platform.isWindows ? '.exe' : ''}';
      // Keep cold source compilation outside each test's deadline.
      final build = await Process.run(Platform.resolvedExecutable, [
        'compile',
        'exe',
        _cliEntrypoint(),
        '-o',
        executable,
      ]);
      expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');
    });
    test('GivenBinaryStdinStream_WhenInvoked_ThenPngBytesDecodeWithoutTextConversion', () async {
      final process = await Process.start(executable, [
        'qr',
        'decode',
        '--stdin',
        '--json',
      ]);
      final out = process.stdout.transform(utf8.decoder).join();
      final err = process.stderr.transform(utf8.decoder).join();
      process.stdin.add(_image('binary stdin'));
      await process.stdin.close();
      expect(await process.exitCode, 0);
      expect((jsonDecode(await out) as Map)['text'], 'binary stdin');
      expect(await err, isEmpty);
    });
    test('GivenOversizedOpenStdin_WhenRead_ThenLimitReturnsWithoutWaitingForEof', () async {
      final process = await Process.start(executable, [
        'qr',
        'decode',
        '--stdin',
        '--json',
      ]);
      final out = process.stdout.transform(utf8.decoder).join();
      final err = process.stderr.transform(utf8.decoder).join();
      // Observe early pipe closure without making producer flush a prerequisite
      // for the exit deadline. IOSink.add starts delivery while stdin stays open.
      final done = process.stdin.done.then<void>(
        (_) {},
        onError: (Object _) {},
      );
      try {
        process.stdin.add(Uint8List(16 * 1024 * 1024 + 1));
        expect(await process.exitCode.timeout(const Duration(seconds: 20)), 75);
        expect(await out, isEmpty);
        expect(jsonDecode(await err), {
          'error': {
            'kind': 'resource',
            'code': 'qr-decode.resource-limit',
            'message': 'QR decoding exceeded its resource limit.',
            'location': {'field': 'input', 'reason': 'byte-limit'},
          },
        });
      } finally {
        // Also reap a child that failed to reject input; never send EOF before
        // the assertion above has observed its exit with stdin still open.
        process.kill();
        final closed = process.stdin.close().then<void>(
          (_) {},
          onError: (Object _) {},
        );
        await Future.wait<void>([
          closed,
          done,
          process.exitCode.then<void>((_) {}),
          out.then<void>((_) {}),
          err.then<void>((_) {}),
        ]).timeout(const Duration(seconds: 5));
      }
    }, timeout: const Timeout(Duration(seconds: 30)));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
    'GivenHelp_WhenRunInBothLocales_ThenFormatsAndSourcesAreDocumented',
    () async {
      for (final locale in ['en', 'pt-BR']) {
        final out = StringBuffer();
        final err = StringBuffer();
        final exitCode = await runChimera(
          ['qr', 'decode', '--help'],
          localeTag: locale,
          out: out,
          err: err,
        );
        expect(exitCode, 0);
        for (final text in [
          'chimera qr decode',
          '--file=',
          '--stdin',
          '--output=',
          'PNG',
          'JPEG',
          'BMP',
        ]) {
          expect(out.toString(), contains(text));
        }
        expect(err.toString(), isEmpty);
      }
    },
  );
}

final class _DeniedSink implements StringSink {
  _DeniedSink(this.error);
  final Object error;
  @override
  void write(Object? object) => throw error;
  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      throw error;
  @override
  void writeCharCode(int charCode) => throw error;
  @override
  void writeln([Object? object = '']) => throw error;
}

String _cliEntrypoint() {
  var directory = Directory.current.absolute;
  while (true) {
    final entrypoint = File.fromUri(
      directory.uri.resolve('apps/chimera_cli/bin/chimera.dart'),
    );
    if (entrypoint.existsSync()) return entrypoint.path;
    if (directory.parent.path == directory.path) {
      throw StateError('CLI entrypoint not found');
    }
    directory = directory.parent;
  }
}
