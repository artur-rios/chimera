import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  group('GzipDecompressor fixtures', () {
    const decompressor = GzipDecompressor();

    for (final fixture in <String>[
      'empty',
      'ascii',
      'unicode',
      'bom',
      'binary',
      'optional',
      'concat',
      'compressible',
    ]) {
      test(
        'Given${_title(fixture)}Fixture_WhenBinaryDecoded_ThenExactBytesReturn',
        () {
          final input = _fixture('$fixture.gzip.hex');
          final expected = _source(fixture);

          final result = decompressor.decompressBytes(
            input,
            mode: GzipDecompressMode.binary,
          );

          expect(result.mode, GzipDecompressMode.binary);
          expect(result.bytes, expected);
          expect(result.text, isNull);
          expect(result.inputByteCount, input.length);
          expect(result.outputByteCount, expected.length);
        },
      );
    }

    test('GivenStrictUtf8Fixtures_WhenTextDecoded_ThenExactTextReturns', () {
      const expected = <String, String>{
        'empty': '',
        'ascii': 'hello',
        'unicode': 'Olá 😀 é\r\n',
        'bom': '\uFEFFa\r\n ',
        'concat': 'helloOlá 😀 é\r\n',
      };

      for (final entry in expected.entries) {
        final input = _fixture('${entry.key}.gzip.hex');
        final result = decompressor.decompressBytes(
          input,
          mode: GzipDecompressMode.text,
        );

        expect(result.text, entry.value, reason: entry.key);
        expect(result.bytes, _source(entry.key), reason: entry.key);
      }
    });

    test('GivenMutableSource_WhenDecoded_ThenResultOwnsImmutableBytes', () {
      final input = _fixture('ascii.gzip.hex');
      final result = decompressor.decompressBytes(
        input,
        mode: GzipDecompressMode.binary,
      );
      input.fillRange(0, input.length, 0);

      expect(result.bytes, utf8.encode('hello'));
      expect(identical(result.bytes, result.bytes), isTrue);
      expect(() => result.bytes[0] = 0, throwsUnsupportedError);
      expect(
        () => result.bytes.buffer.asUint8List()[0] = 0,
        throwsUnsupportedError,
      );
    });

    test('GivenRepeatedCalls_WhenDecoded_ThenNoPriorStateIsRetained', () {
      final first = decompressor.decompressBytes(
        _fixture('ascii.gzip.hex'),
        mode: GzipDecompressMode.text,
      );
      final second = decompressor.decompressBytes(
        _fixture('binary.gzip.hex'),
        mode: GzipDecompressMode.binary,
      );
      final third = decompressor.decompressBytes(
        _fixture('ascii.gzip.hex'),
        mode: GzipDecompressMode.text,
      );

      expect(first.text, 'hello');
      expect(second.bytes, <int>[0, 255, 128, 1, 254, 0, 13, 10]);
      expect(third.text, 'hello');
      expect(third.bytes, first.bytes);
    });
  });

  group('GzipDecompressor validation', () {
    const decompressor = GzipDecompressor();

    test('GivenMalformedFraming_WhenDecoded_ThenMalformedFailureReturns', () {
      final valid = _fixture('ascii.gzip.hex');
      final optional = _fixture('optional.gzip.hex');
      final cases = <String, List<int>>{
        'empty input': <int>[],
        'short fixed header': valid.sublist(0, 9),
        'bad magic': <int>[0, ...valid.skip(1)],
        'leading junk': <int>[0, ...valid],
        'truncated deflate or trailer': valid.sublist(0, valid.length - 7),
        'trailing nul': <int>[...valid, 0],
        'trailing junk': <int>[...valid, 1, 2, 3],
        'truncated extra length': <int>[...optional.take(11)],
        'truncated extra bytes': <int>[
          ...optional.take(10),
          255,
          255,
          ...optional.skip(12).take(2),
        ],
        'unterminated name': <int>[0x1f, 0x8b, 8, 0x08, 0, 0, 0, 0, 0, 255, 65],
        'unterminated comment': <int>[
          0x1f,
          0x8b,
          8,
          0x10,
          0,
          0,
          0,
          0,
          0,
          255,
          65,
        ],
        'missing header crc': <int>[0x1f, 0x8b, 8, 0x02, 0, 0, 0, 0, 0, 255],
        'raw deflate': _hex('cb48cdc9c90700'),
        'zlib': _hex('789ccb48cdc9c90700062c0215'),
        'zip': _hex('504b030414000000'),
      };

      for (final entry in cases.entries) {
        expect(
          () => decompressor.decompressBytes(
            entry.value,
            mode: GzipDecompressMode.binary,
          ),
          _failure(
            GzipDecompressFailureKind.validation,
            'gzip-decompress.invalid-archive',
            'input',
            'malformed-gzip',
          ),
          reason: entry.key,
        );
      }
    });

    test('GivenStoredBlockPayloadEndsEarly_WhenDecoded_ThenMalformedFailureReturns', () {
      final truncatedStoredBlock = _hex('1f8b08000000000000ff010500faff6869');

      expect(
        () => decompressor.decompressBytes(
          truncatedStoredBlock,
          mode: GzipDecompressMode.binary,
        ),
        _failure(
          GzipDecompressFailureKind.validation,
          'gzip-decompress.invalid-archive',
          'input',
          'malformed-gzip',
        ),
      );
    });

    test('GivenUnsupportedMethodOrFlags_WhenDecoded_ThenUnsupportedFails', () {
      final valid = _fixture('ascii.gzip.hex');
      final method = List<int>.of(valid)..[2] = 7;
      final reserved = List<int>.of(valid)..[3] = 0x20;

      for (final input in <List<int>>[method, reserved]) {
        expect(
          () => decompressor.decompressBytes(
            input,
            mode: GzipDecompressMode.binary,
          ),
          _failure(
            GzipDecompressFailureKind.validation,
            'gzip-decompress.invalid-archive',
            'input',
            'unsupported-gzip',
          ),
        );
      }
    });

    test('GivenCorruptPayloadOrChecksums_WhenDecoded_ThenCorruptFails', () {
      final valid = _fixture('ascii.gzip.hex');
      final optional = _fixture('optional.gzip.hex');
      final invalidHuffman = _fixture('compressible.gzip.hex')..[11] = 0xff;
      final cases = <String, List<int>>{
        'invalid block type': <int>[
          ...valid.take(10),
          0x07,
          ...List<int>.filled(8, 0),
        ],
        'invalid stored LEN NLEN': <int>[
          ...valid.take(10),
          1,
          1,
          0,
          1,
          0,
          65,
          ...List<int>.filled(8, 0),
        ],
        'zero stored LEN with invalid NLEN': _hex(
          '1f8b08000000000000ff01000000000000000000000000',
        ),
        'invalid dynamic Huffman': invalidHuffman,
        'payload crc mismatch': List<int>.of(valid)..[valid.length - 8] ^= 1,
        'payload size mismatch': List<int>.of(valid)..[valid.length - 4] ^= 1,
        'header crc mismatch': List<int>.of(optional)..[33] ^= 1,
      };

      for (final entry in cases.entries) {
        expect(
          () => decompressor.decompressBytes(
            entry.value,
            mode: GzipDecompressMode.binary,
          ),
          _failure(
            GzipDecompressFailureKind.validation,
            'gzip-decompress.invalid-archive',
            'input',
            'corrupt-gzip',
          ),
          reason: entry.key,
        );
      }
    });

    test(
      'GivenMalformedLaterMember_WhenDecoded_ThenNoPartialResultReturns',
      () {
        final first = _fixture('ascii.gzip.hex');
        final later = _fixture('unicode.gzip.hex')..last ^= 1;
        GzipDecompressionResult? published;

        expect(
          () => published = decompressor.decompressBytes(<int>[
            ...first,
            ...later,
          ], mode: GzipDecompressMode.binary),
          _failure(
            GzipDecompressFailureKind.validation,
            'gzip-decompress.invalid-archive',
            'input',
            'corrupt-gzip',
          ),
        );
        expect(published, isNull);
      },
    );

    test('GivenLaterMemberStartsWithBackReference_WhenDecoded_ThenPriorHistoryIsUnavailable', () {
      final first = _fixture('ascii.gzip.hex');
      // Fixed-Huffman length 3, distance 1, then end-of-block. This would
      // decode to "ooo" if the preceding member's dictionary leaked.
      final invalidMember = _hex('1f8b08000000000000ff030200ae5ea28303000000');

      expect(
        () => decompressor.decompressBytes(<int>[
          ...first,
          ...invalidMember,
        ], mode: GzipDecompressMode.binary),
        _failure(
          GzipDecompressFailureKind.validation,
          'gzip-decompress.invalid-archive',
          'input',
          'corrupt-gzip',
        ),
      );
    });

    test('GivenFtextHeader_WhenDecoded_ThenModeStillControlsOutput', () {
      final optional = _fixture('optional.gzip.hex');
      optional[3] |= 1;
      final headerCrc = _crc32(optional.sublist(0, 33)) & 0xffff;
      optional[33] = headerCrc & 0xff;
      optional[34] = headerCrc >> 8;

      final result = decompressor.decompressBytes(
        optional,
        mode: GzipDecompressMode.binary,
      );

      expect(result.mode, GzipDecompressMode.binary);
      expect(result.text, isNull);
      expect(result.bytes, <int>[0, 255, 128, 1, 254, 0, 13, 10]);
    });

    test('GivenOutOfRangeSourceByte_WhenDecoded_ThenByteRangeFails', () {
      for (final byte in <int>[-1, 256]) {
        expect(
          () => decompressor.decompressBytes(<int>[
            0x1f,
            byte,
          ], mode: GzipDecompressMode.binary),
          _failure(
            GzipDecompressFailureKind.validation,
            'gzip-decompress.invalid-input',
            'input',
            'byte-range',
          ),
        );
      }
    });

    test('GivenInvalidUtf8_WhenModeChanges_ThenOnlyTextModeFails', () {
      final input = _fixture('binary.gzip.hex');

      expect(
        decompressor
            .decompressBytes(input, mode: GzipDecompressMode.binary)
            .bytes,
        <int>[0, 255, 128, 1, 254, 0, 13, 10],
      );
      expect(
        () =>
            decompressor.decompressBytes(input, mode: GzipDecompressMode.text),
        _failure(
          GzipDecompressFailureKind.validation,
          'gzip-decompress.invalid-text',
          'output',
          'invalid-utf8',
        ),
      );
    });
  });

  group('GzipDecompressor resources', () {
    test('GivenInputBudget_WhenAtBoundary_ThenOnlyOversizedInputFails', () {
      final input = _fixture('ascii.gzip.hex');
      expect(
        GzipDecompressor(maxInputBytes: input.length)
            .decompressBytes(input, mode: GzipDecompressMode.binary)
            .bytes,
        utf8.encode('hello'),
      );
      expect(
        () =>
            GzipDecompressor(maxInputBytes: input.length - 1)
                .decompressBytes(input, mode: GzipDecompressMode.binary),
        _failure(
          GzipDecompressFailureKind.resource,
          'gzip-decompress.resource-limit',
          'input',
          'byte-limit',
        ),
      );
    });

    test('GivenOutputBudget_WhenAtBoundary_ThenEveryWriteIsBounded', () {
      final empty = _fixture('empty.gzip.hex');
      final ascii = _fixture('ascii.gzip.hex');
      final compressible = _fixture('compressible.gzip.hex');

      expect(
        const GzipDecompressor(maxOutputBytes: 0)
            .decompressBytes(empty, mode: GzipDecompressMode.binary)
            .bytes,
        isEmpty,
      );
      expect(
        const GzipDecompressor(maxOutputBytes: 5)
            .decompressBytes(ascii, mode: GzipDecompressMode.binary)
            .bytes,
        utf8.encode('hello'),
      );
      expect(
        () =>
            const GzipDecompressor(maxOutputBytes: 4)
                .decompressBytes(ascii, mode: GzipDecompressMode.binary),
        _failure(
          GzipDecompressFailureKind.resource,
          'gzip-decompress.resource-limit',
          'output',
          'byte-limit',
        ),
      );
      expect(
        const GzipDecompressor(maxOutputBytes: 4096)
            .decompressBytes(compressible, mode: GzipDecompressMode.binary)
            .outputByteCount,
        4096,
      );
      expect(
        () =>
            const GzipDecompressor(maxOutputBytes: 4095)
                .decompressBytes(compressible, mode: GzipDecompressMode.binary),
        _failure(
          GzipDecompressFailureKind.resource,
          'gzip-decompress.resource-limit',
          'output',
          'byte-limit',
        ),
      );
    });

    test('GivenStoredBlock_WhenWriteBytesExceedsBudget_ThenNoBytesEscape', () {
      final storedHello = _hex(
        '1f8b08000000000000ff010500faff68656c6c6f86a6103605000000',
      );

      expect(
        const GzipDecompressor(maxOutputBytes: 5)
            .decompressBytes(storedHello, mode: GzipDecompressMode.binary)
            .bytes,
        utf8.encode('hello'),
      );
      GzipDecompressionResult? published;
      expect(
        () =>
            published = const GzipDecompressor(maxOutputBytes: 4)
                .decompressBytes(storedHello, mode: GzipDecompressMode.binary),
        _failure(
          GzipDecompressFailureKind.resource,
          'gzip-decompress.resource-limit',
          'output',
          'byte-limit',
        ),
      );
      expect(published, isNull);
    });

    test('GivenConcatenatedMembers_WhenBounded_ThenLimitIsAggregate', () {
      final input = _fixture('concat.gzip.hex');
      expect(
        const GzipDecompressor(maxOutputBytes: 20)
            .decompressBytes(input, mode: GzipDecompressMode.binary)
            .outputByteCount,
        20,
      );
      expect(
        () =>
            const GzipDecompressor(maxOutputBytes: 19)
                .decompressBytes(input, mode: GzipDecompressMode.binary),
        _failure(
          GzipDecompressFailureKind.resource,
          'gzip-decompress.resource-limit',
          'output',
          'byte-limit',
        ),
      );
    });

    test('GivenInputCopyExhaustion_WhenDecoded_ThenInputAllocationFails', () {
      final decompressor = GzipDecompressor.forTesting(
        copyInput: (_) => throw OutOfMemoryError(),
      );

      expect(
        () => decompressor.decompressBytes(
          _fixture('ascii.gzip.hex'),
          mode: GzipDecompressMode.binary,
        ),
        _failure(
          GzipDecompressFailureKind.resource,
          'gzip-decompress.resource-limit',
          'input',
          'allocation-limit',
        ),
      );
    });

    test('GivenResultCopyExhaustion_WhenDecoded_ThenNoResultEscapes', () {
      final decompressor = GzipDecompressor.forTesting(
        copyOutput: (_) => throw OutOfMemoryError(),
      );
      GzipDecompressionResult? published;

      expect(
        () => published = decompressor.decompressBytes(
          _fixture('ascii.gzip.hex'),
          mode: GzipDecompressMode.binary,
        ),
        _failure(
          GzipDecompressFailureKind.resource,
          'gzip-decompress.resource-limit',
          'output',
          'allocation-limit',
        ),
      );
      expect(published, isNull);
    });

    test('GivenTextAllocationExhaustion_WhenDecoded_ThenNoResultEscapes', () {
      final decompressor = GzipDecompressor.forTesting(
        decodeUtf8: (_) => throw OutOfMemoryError(),
      );

      expect(
        () => decompressor.decompressBytes(
          _fixture('ascii.gzip.hex'),
          mode: GzipDecompressMode.text,
        ),
        _failure(
          GzipDecompressFailureKind.resource,
          'gzip-decompress.resource-limit',
          'output',
          'allocation-limit',
        ),
      );
    });

    test(
      'GivenAggregateGrowthRangeError_WhenDecoded_ThenAllocationLimitReturns',
      () {
        final decompressor = GzipDecompressor.forTesting(
          createOutput: _RangeFailingOutput.new,
        );

        expect(
          () => decompressor.decompressBytes(
            _fixture('ascii.gzip.hex'),
            mode: GzipDecompressMode.binary,
          ),
          _failure(
            GzipDecompressFailureKind.resource,
            'gzip-decompress.resource-limit',
            'output',
            'allocation-limit',
          ),
        );
      },
    );
  });
}

List<int> _fixture(String name) {
  final fromRepositoryRoot = File('tests/fixtures/encoded/gzip/$name');
  final file = fromRepositoryRoot.existsSync()
      ? fromRepositoryRoot
      : File('../../tests/fixtures/encoded/gzip/$name');
  return _hex(file.readAsStringSync());
}

List<int> _source(String name) {
  if (name == 'compressible') return List<int>.filled(4096, 97);
  if (name == 'optional') return _fixture('binary.source.hex');
  return _fixture('$name.source.hex');
}

List<int> _hex(String source) {
  final normalized = source.replaceAll(RegExp(r'\s'), '');
  return <int>[
    for (var index = 0; index < normalized.length; index += 2)
      int.parse(normalized.substring(index, index + 2), radix: 16),
  ];
}

String _title(String value) => '${value[0].toUpperCase()}${value.substring(1)}';

Matcher _failure(
  GzipDecompressFailureKind kind,
  String code,
  String field,
  String reason,
) => throwsA(
  isA<GzipDecompressException>()
      .having((error) => error.kind, 'kind', kind)
      .having((error) => error.code, 'code', code)
      .having((error) => error.field, 'field', field)
      .having((error) => error.reason, 'reason', reason)
      .having(
        (error) => error.toString(),
        'redacted description',
        isNot(
          anyOf(
            contains('OutOfMemory'),
            contains('ArchiveException'),
            contains('hello'),
            contains('255'),
          ),
        ),
      ),
);

// Independent table implementation for test-only FHCRC mutation.
int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = crc & 1 == 0 ? crc >> 1 : (crc >> 1) ^ 0xedb88320;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

final class _RangeFailingOutput extends OutputMemoryStream {
  _RangeFailingOutput() : super(size: 0);

  @override
  void writeByte(int value) => throw RangeError('secret allocation failure');
}
