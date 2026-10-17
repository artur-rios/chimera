import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  group('GzipCompressor', () {
    const compressor = GzipCompressor();

    test('GivenAscii_WhenStored_ThenKnownRfc1952MemberReturns', () {
      final result = compressor.compressText('hello', level: 0);

      // RFC 1951 final stored block, RFC 1952 header, CRC32 and ISIZE.
      expect(result.bytes, <int>[
        0x1f,
        0x8b,
        8,
        0,
        0,
        0,
        0,
        0,
        0,
        255,
        1,
        5,
        0,
        250,
        255,
        104,
        101,
        108,
        108,
        111,
        0x86,
        0xa6,
        0x10,
        0x36,
        5,
        0,
        0,
        0,
      ]);
      expect(gzip.decode(result.bytes), utf8.encode('hello'));
      expect(result.level, 0);
      expect(result.inputByteCount, 5);
      expect(result.outputByteCount, 28);
    });

    test('GivenEmptyInput_WhenCompressed_ThenValidEmptyMemberReturns', () {
      final text = compressor.compressText('');
      final bytes = compressor.compressBytes(<int>[]);

      expect(text.bytes, bytes.bytes);
      expect(gzip.decode(bytes.bytes), isEmpty);
      expect(bytes.inputByteCount, 0);
      expect(bytes.outputByteCount, bytes.bytes.length);
      expect(
        bytes.bytes.sublist(bytes.bytes.length - 8),
        List<int>.filled(8, 0),
      );
    });

    test('GivenAscii_WhenDeflated_ThenKnownFixedHuffmanMemberReturns', () {
      // RFC 1951 fixed-Huffman literal block for "hello", independently
      // checked by dart:io's native GZIP decoder.
      const expected = <int>[
        31,
        139,
        8,
        0,
        0,
        0,
        0,
        0,
        0,
        255,
        0xcb,
        0x48,
        0xcd,
        0xc9,
        0xc9,
        7,
        0,
        0x86,
        0xa6,
        0x10,
        0x36,
        5,
        0,
        0,
        0,
      ];
      for (final level in <int>[1, 6, 9]) {
        expect(compressor.compressText('hello', level: level).bytes, expected);
      }
    });

    final random = Random(2042);
    final sources = <String, List<int>>{
      'ASCII': utf8.encode('hello'),
      'Unicode': utf8.encode('Olá 😀 e\u0301\r\n\uFEFF'),
      'arbitrary bytes': <int>[0, 255, 128, 1, 254, 0, 13, 10],
      'compressible': List<int>.filled(8192, 97),
      'incompressible': List<int>.generate(8192, (_) => random.nextInt(256)),
    };
    for (final entry in sources.entries) {
      for (final level in <int>[0, 1, 6, 9]) {
        test('Given${entry.key}_WhenLevel${level}_ThenExactBytesRoundTrip', () {
          final result = compressor.compressBytes(entry.value, level: level);

          expect(gzip.decode(result.bytes), entry.value);
          expect(result.level, level);
          expect(result.inputByteCount, entry.value.length);
          expect(result.outputByteCount, result.bytes.length);
          expect(result.bytes.sublist(0, 10), <int>[
            31,
            139,
            8,
            0,
            0,
            0,
            0,
            0,
            0,
            255,
          ]);
          expect(
            ByteData.sublistView(result.bytes)
                .getUint32(result.bytes.length - 4, Endian.little),
            entry.value.length,
          );
        });
      }
    }

    test('GivenUnicodeText_WhenCompressed_ThenStrictUtf8BytesAreUsed', () {
      const source = 'Olá 😀 e\u0301\r\n\uFEFF';
      final result = compressor.compressText(source);

      expect(gzip.decode(result.bytes), utf8.encode(source));
      expect(result.inputByteCount, utf8.encode(source).length);
    });

    test(
      'GivenDefaultLevel_WhenRepeated_ThenLevelSixBytesAreDeterministic',
      () {
        final first = compressor.compressText('hello');

        expect(first.level, 6);
        expect(first.bytes, compressor.compressText('hello', level: 6).bytes);
        expect(first.bytes, compressor.compressText('hello').bytes);
        expect(first.bytes.sublist(first.bytes.length - 8), <int>[
          0x86,
          0xa6,
          0x10,
          0x36,
          5,
          0,
          0,
          0,
        ]);
      },
    );

    test('GivenCompressibleBytes_WhenCompressed_ThenLevelZeroStores', () {
      final source = List<int>.filled(8192, 97);
      final stored = compressor.compressBytes(source, level: 0);
      final compressed = compressor.compressBytes(source);

      expect(stored.outputByteCount, greaterThan(source.length));
      expect(compressed.outputByteCount, lessThan(source.length ~/ 10));
    });

    test(
      'GivenMutableSource_WhenResultReturns_ThenPayloadIsOwnedAndImmutable',
      () {
        final source = <int>[0, 255, 128];
        final result = compressor.compressBytes(source);
        source.fillRange(0, source.length, 1);

        expect(gzip.decode(result.bytes), <int>[0, 255, 128]);
        expect(identical(result.bytes, result.bytes), isTrue);
        expect(() => result.bytes[0] = 0, throwsUnsupportedError);
        expect(
          () => result.bytes.buffer.asUint8List()[0] = 0,
          throwsUnsupportedError,
        );
      },
    );

    test(
      'GivenInvalidLevel_WhenCompressed_ThenValidationPrecedesInputAccess',
      () {
        for (final level in <int>[-1, 10]) {
          expect(
            () => compressor.compressBytes(_UnreadableBytes(), level: level),
            _failure(
              GzipCompressFailureKind.validation,
              'gzip-compress.invalid-level',
              'level',
              'outside-range',
            ),
          );
          expect(
            () => compressor.compressText('secret', level: level),
            _failure(
              GzipCompressFailureKind.validation,
              'gzip-compress.invalid-level',
              'level',
              'outside-range',
            ),
          );
        }
      },
    );

    test('GivenUnpairedSurrogates_WhenCompressed_ThenInvalidUnicodeFails', () {
      for (final source in <String>[
        '\uD800',
        '\uDC00',
        'secret\uD800x',
        '\uD800\uD800',
      ]) {
        expect(
          () => compressor.compressText(source),
          _failure(
            GzipCompressFailureKind.validation,
            'gzip-compress.invalid-input',
            'input',
            'invalid-unicode',
          ),
        );
      }
    });

    test('GivenOutOfRangeBytes_WhenCompressed_ThenNoCoercionOccurs', () {
      for (final byte in <int>[-1, 256]) {
        expect(
          () => compressor.compressBytes(<int>[0, byte, 255]),
          _failure(
            GzipCompressFailureKind.validation,
            'gzip-compress.invalid-input',
            'input',
            'byte-range',
          ),
        );
      }
    });

    test('GivenInputBudget_WhenAtBoundary_ThenOnlyOversizedBytesFail', () {
      expect(
        const GzipCompressor(maxInputBytes: 3)
            .compressBytes(<int>[0, 255, 128])
            .inputByteCount,
        3,
      );
      expect(
        () =>
            const GzipCompressor(maxInputBytes: 2)
                .compressBytes(<int>[0, 255, 128]),
        _failure(
          GzipCompressFailureKind.resource,
          'gzip-compress.resource-limit',
          'input',
          'byte-limit',
        ),
      );
      expect(
        const GzipCompressor(maxInputBytes: 0).compressText('').inputByteCount,
        0,
      );
    });

    test(
      'GivenTextBudget_WhenAtBoundary_ThenUtf8LengthIsCheckedBeforeEncoding',
      () {
        expect(
          const GzipCompressor(maxInputBytes: 4)
              .compressText('😀')
              .inputByteCount,
          4,
        );
        final bounded = GzipCompressor.forTesting(
          maxInputBytes: 3,
          encodeUtf8: (_) =>
              throw StateError('must not encode oversized input'),
        );
        expect(
          () => bounded.compressText('😀'),
          _failure(
            GzipCompressFailureKind.resource,
            'gzip-compress.resource-limit',
            'input',
            'byte-limit',
          ),
        );
      },
    );

    test('GivenOutputBudget_WhenAtBoundary_ThenNoPartialResultEscapes', () {
      expect(
        const GzipCompressor(maxOutputBytes: 28)
            .compressText('hello', level: 0)
            .outputByteCount,
        28,
      );
      GzipCompressionResult? published;
      expect(
        () =>
            published = const GzipCompressor(maxOutputBytes: 27)
                .compressText('hello', level: 0),
        _failure(
          GzipCompressFailureKind.resource,
          'gzip-compress.resource-limit',
          'output',
          'byte-limit',
        ),
      );
      expect(published, isNull);
      expect(
        () => const GzipCompressor(maxOutputBytes: 0).compressBytes(<int>[]),
        _failure(
          GzipCompressFailureKind.resource,
          'gzip-compress.resource-limit',
          'output',
          'byte-limit',
        ),
      );
    });

    test(
      'GivenInputCopyExhaustion_WhenCompressed_ThenRedactedResourceFails',
      () {
        final bounded = GzipCompressor.forTesting(
          copyBytes: (_) => throw OutOfMemoryError(),
        );
        expect(
          () => bounded.compressBytes(<int>[0, 255]),
          _failure(
            GzipCompressFailureKind.resource,
            'gzip-compress.resource-limit',
            'input',
            'allocation-limit',
          ),
        );
      },
    );

    test('GivenUtf8Exhaustion_WhenCompressed_ThenRedactedResourceFails', () {
      final bounded = GzipCompressor.forTesting(
        encodeUtf8: (_) => throw OutOfMemoryError(),
      );
      expect(
        () => bounded.compressText('secret'),
        _failure(
          GzipCompressFailureKind.resource,
          'gzip-compress.resource-limit',
          'input',
          'allocation-limit',
        ),
      );
    });

    test(
      'GivenEncoderExhaustion_WhenCompressed_ThenNoPartialResultEscapes',
      () {
        final bounded = GzipCompressor.forTesting(
          encode: (_, _) => throw OutOfMemoryError(),
        );
        GzipCompressionResult? published;
        expect(
          () => published = bounded.compressBytes(<int>[0, 255]),
          _failure(
            GzipCompressFailureKind.resource,
            'gzip-compress.resource-limit',
            'output',
            'allocation-limit',
          ),
        );
        expect(published, isNull);
      },
    );

    test(
      'GivenOwnershipExhaustion_WhenCompressed_ThenNoPartialResultEscapes',
      () {
        var copies = 0;
        final bounded = GzipCompressor.forTesting(
          copyBytes: (source) {
            if (++copies == 2) throw OutOfMemoryError();
            return Uint8List.fromList(source);
          },
        );
        GzipCompressionResult? published;
        expect(
          () => published = bounded.compressBytes(<int>[0, 255]),
          _failure(
            GzipCompressFailureKind.resource,
            'gzip-compress.resource-limit',
            'output',
            'allocation-limit',
          ),
        );
        expect(published, isNull);
      },
    );

    test(
      'GivenEncoderOwnedBuffer_WhenChanged_ThenResultRetainsIndependentCopy',
      () {
        final encoded = const GZipEncoderWeb().encodeBytes(<int>[0, 255]);
        final bounded = GzipCompressor.forTesting(encode: (_, _) => encoded);
        final result = bounded.compressBytes(<int>[0, 255]);
        encoded.fillRange(0, encoded.length, 0);

        expect(gzip.decode(result.bytes), <int>[0, 255]);
      },
    );
  });
}

Matcher _failure(
  GzipCompressFailureKind kind,
  String code,
  String field,
  String reason,
) => throwsA(
  isA<GzipCompressException>()
      .having((error) => error.kind, 'kind', kind)
      .having((error) => error.code, 'code', code)
      .having((error) => error.field, 'field', field)
      .having((error) => error.reason, 'reason', reason)
      .having(
        (error) => error.toString(),
        'redacted description',
        isNot(
          anyOf(contains('secret'), contains('OutOfMemory'), contains('255')),
        ),
      ),
);

final class _UnreadableBytes extends ListBase<int> {
  @override
  int get length => throw StateError('must not access invalid-level input');
  @override
  set length(int value) => throw UnsupportedError('immutable');
  @override
  int operator [](int index) => throw StateError('must not read input');
  @override
  void operator []=(int index, int value) =>
      throw UnsupportedError('immutable');
}
