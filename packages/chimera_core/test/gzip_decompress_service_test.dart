import 'dart:convert';
import 'dart:typed_data';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test(
    'GivenTextArchive_WhenDecompressed_ThenStableTextOutputReturns',
    () async {
      final output = _success(
        await const GzipDecompressService().execute(
          GzipDecompressOperationRequest.bytes(
            _helloGzip,
            mode: GzipDecompressMode.text,
          ),
        ),
      );

      expect(output.mode, GzipDecompressMode.text);
      expect(output.text, 'hello');
      expect(output.bytes, utf8.encode('hello'));
      expect(output.inputByteCount, 25);
      expect(output.outputByteCount, 5);
      expect(output.toJson().keys, <String>[
        'mode',
        'text',
        'bytes',
        'inputByteCount',
        'outputByteCount',
      ]);
      expect(
        jsonEncode(output.toJson()),
        '{"mode":"text","text":"hello","bytes":null,'
        '"inputByteCount":25,"outputByteCount":5}',
      );
    },
  );

  test(
    'GivenBinaryArchive_WhenDecompressed_ThenStableBinaryOutputReturns',
    () async {
      final output = _success(
        await const GzipDecompressService().execute(
          GzipDecompressOperationRequest.bytes(
            _binaryGzip,
            mode: GzipDecompressMode.binary,
          ),
        ),
      );

      expect(output.mode, GzipDecompressMode.binary);
      expect(output.text, isNull);
      expect(output.bytes, <int>[0, 255, 128, 1, 254, 0, 13, 10]);
      expect(output.inputByteCount, 28);
      expect(output.outputByteCount, 8);
      expect(output.toJson().keys, <String>[
        'mode',
        'text',
        'bytes',
        'inputByteCount',
        'outputByteCount',
      ]);
      expect(
        jsonEncode(output.toJson()),
        '{"mode":"binary","text":null,"bytes":[0,255,128,1,254,0,13,10],'
        '"inputByteCount":28,"outputByteCount":8}',
      );
    },
  );

  test(
    'GivenEmptyPayloadArchive_WhenDecompressed_ThenEmptyOutputReturns',
    () async {
      final output = _success(
        await const GzipDecompressService().execute(
          GzipDecompressOperationRequest.bytes(
            _emptyGzip,
            mode: GzipDecompressMode.binary,
          ),
        ),
      );

      expect(output.bytes, isEmpty);
      expect(output.inputByteCount, 20);
      expect(output.outputByteCount, 0);
    },
  );

  test('GivenBomTextArchive_WhenDecompressed_ThenBomIsPreserved', () async {
    final output = _success(
      await const GzipDecompressService().execute(
        GzipDecompressOperationRequest.bytes(
          _bomGzip,
          mode: GzipDecompressMode.text,
        ),
      ),
    );

    expect(output.text, '\uFEFFa\r\n ');
    expect(output.bytes, <int>[0xef, 0xbb, 0xbf, 0x61, 0x0d, 0x0a, 0x20]);
  });

  test('GivenMutableRequest_WhenDecompressed_ThenUtilityBytesAreOwnedWithoutAnotherRetainedCopy', () async {
    final input = List<int>.of(_helloGzip);
    final output = _success(
      await const GzipDecompressService().execute(
        GzipDecompressOperationRequest.bytes(
          input,
          mode: GzipDecompressMode.binary,
        ),
      ),
    );
    input.fillRange(0, input.length, 0);

    expect(output.bytes, same(output.result.bytes));
    expect(output.bytes, utf8.encode('hello'));
    expect(() => output.bytes[0] = 0, throwsUnsupportedError);
    final jsonBytes = output.toJson()['bytes']! as List<int>;
    expect(jsonBytes, isNot(same(output.bytes)));
    jsonBytes[0] = 0;
    expect(output.bytes, utf8.encode('hello'));
  });

  test(
    'GivenOneRequest_WhenDecompressed_ThenUtilityIsDelegatedExactlyOnce',
    () async {
      var copies = 0;
      final service = GzipDecompressService(
        decompressor: GzipDecompressor.forTesting(
          copyInput: (input) {
            copies++;
            return Uint8List.fromList(input);
          },
        ),
      );

      final output = _success(
        await service.execute(
          GzipDecompressOperationRequest.bytes(
            _helloGzip,
            mode: GzipDecompressMode.binary,
          ),
        ),
      );

      expect(copies, 1);
      expect(output.bytes, utf8.encode('hello'));
    },
  );

  group('GzipDecompressService failure mapping', () {
    test('GivenClassifiedValidationFailures_WhenDecompressed_ThenRedactedValidationReturns', () async {
      final unsupported = List<int>.of(_helloGzip)..[2] = 7;
      final corrupt = List<int>.of(_helloGzip)..[17] ^= 1;
      final cases =
          <
            ({
              String name,
              List<int> input,
              GzipDecompressMode mode,
              String code,
              String field,
              String reason,
            })
          >[
            (
              name: 'byte range',
              input: <int>[256],
              mode: GzipDecompressMode.binary,
              code: 'gzip-decompress.invalid-input',
              field: 'input',
              reason: 'byte-range',
            ),
            (
              name: 'malformed',
              input: const <int>[],
              mode: GzipDecompressMode.binary,
              code: 'gzip-decompress.invalid-archive',
              field: 'input',
              reason: 'malformed-gzip',
            ),
            (
              name: 'unsupported',
              input: unsupported,
              mode: GzipDecompressMode.binary,
              code: 'gzip-decompress.invalid-archive',
              field: 'input',
              reason: 'unsupported-gzip',
            ),
            (
              name: 'corrupt',
              input: corrupt,
              mode: GzipDecompressMode.binary,
              code: 'gzip-decompress.invalid-archive',
              field: 'input',
              reason: 'corrupt-gzip',
            ),
            (
              name: 'invalid text',
              input: _binaryGzip,
              mode: GzipDecompressMode.text,
              code: 'gzip-decompress.invalid-text',
              field: 'output',
              reason: 'invalid-utf8',
            ),
          ];

      for (final testCase in cases) {
        _expectFailure(
          await const GzipDecompressService().execute(
            GzipDecompressOperationRequest.bytes(
              testCase.input,
              mode: testCase.mode,
            ),
          ),
          kind: FailureKind.validation,
          code: testCase.code,
          field: testCase.field,
          reason: testCase.reason,
          name: testCase.name,
        );
      }
    });

    test(
      'GivenByteBudgets_WhenDecompressed_ThenRedactedResourceReturns',
      () async {
        final cases = <({GzipDecompressor decompressor, String field})>[
          (
            decompressor: const GzipDecompressor(maxInputBytes: 24),
            field: 'input',
          ),
          (
            decompressor: const GzipDecompressor(maxOutputBytes: 4),
            field: 'output',
          ),
        ];

        for (final testCase in cases) {
          _expectFailure(
            await GzipDecompressService(decompressor: testCase.decompressor)
                .execute(
                  GzipDecompressOperationRequest.bytes(
                    _helloGzip,
                    mode: GzipDecompressMode.binary,
                  ),
                ),
            kind: FailureKind.resource,
            code: 'gzip-decompress.resource-limit',
            field: testCase.field,
            reason: 'byte-limit',
            name: testCase.field,
          );
        }
      },
    );

    test(
      'GivenAllocationFailures_WhenDecompressed_ThenRedactedResourceReturns',
      () async {
        final cases = <({GzipDecompressor decompressor, String field})>[
          (
            decompressor: GzipDecompressor.forTesting(
              copyInput: (_) => throw OutOfMemoryError(),
            ),
            field: 'input',
          ),
          (
            decompressor: GzipDecompressor.forTesting(
              copyOutput: (_) => throw OutOfMemoryError(),
            ),
            field: 'output',
          ),
        ];

        for (final testCase in cases) {
          _expectFailure(
            await GzipDecompressService(decompressor: testCase.decompressor)
                .execute(
                  GzipDecompressOperationRequest.bytes(
                    _helloGzip,
                    mode: GzipDecompressMode.binary,
                  ),
                ),
            kind: FailureKind.resource,
            code: 'gzip-decompress.resource-limit',
            field: testCase.field,
            reason: 'allocation-limit',
            name: testCase.field,
          );
        }
      },
    );
  });

  test(
    'GivenUnexpectedDependencyError_WhenDecompressed_ThenErrorEscapesUnchanged',
    () async {
      final error = StateError(_sensitive);
      final service = GzipDecompressService(
        decompressor: GzipDecompressor.forTesting(
          copyInput: (_) => throw error,
        ),
      );

      await expectLater(
        service.execute(
          GzipDecompressOperationRequest.bytes(
            _helloGzip,
            mode: GzipDecompressMode.binary,
          ),
        ),
        throwsA(same(error)),
      );
    },
  );
}

GzipDecompressOutput _success(ChimeraResult<GzipDecompressOutput> result) =>
    result.fold(
      onSuccess: (output) => output,
      onFailure: (failure) => fail(failure.code),
    );

void _expectFailure(
  ChimeraResult<GzipDecompressOutput> result, {
  required FailureKind kind,
  required String code,
  required String field,
  required String reason,
  required String name,
}) {
  result.fold(
    onSuccess: (_) => fail('Expected failure without partial output: $name'),
    onFailure: (failure) {
      expect(failure.kind, kind, reason: name);
      expect(failure.code, code, reason: name);
      expect(
        failure.messageKey,
        kind == FailureKind.validation
            ? 'error.gzipDecompress.validation'
            : 'error.gzipDecompress.resource',
        reason: name,
      );
      expect(failure.details.keys, <String>['field', 'reason'], reason: name);
      expect(failure.details, <String, Object?>{
        'field': field,
        'reason': reason,
      }, reason: name);
      final serialized = jsonEncode(<String, Object?>{
        'code': failure.code,
        'messageKey': failure.messageKey,
        'details': failure.details,
      });
      expect(
        serialized,
        isNot(
          anyOf(
            contains(_sensitive),
            contains('256'),
            contains('OutOfMemory'),
            contains('StateError'),
            contains('ArchiveException'),
          ),
        ),
        reason: name,
      );
    },
  );
}

const _sensitive = 'private source C:/secrets/input.gzip';

const _emptyGzip = <int>[
  31,
  139,
  8,
  0,
  0,
  0,
  0,
  0,
  2,
  255,
  3,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
];

const _helloGzip = <int>[
  31,
  139,
  8,
  0,
  0,
  0,
  0,
  0,
  2,
  255,
  203,
  72,
  205,
  201,
  201,
  7,
  0,
  134,
  166,
  16,
  54,
  5,
  0,
  0,
  0,
];

const _bomGzip = <int>[
  31,
  139,
  8,
  0,
  0,
  0,
  0,
  0,
  2,
  255,
  123,
  191,
  123,
  127,
  34,
  47,
  151,
  2,
  0,
  132,
  190,
  221,
  192,
  7,
  0,
  0,
  0,
];

const _binaryGzip = <int>[
  31,
  139,
  8,
  0,
  0,
  0,
  0,
  0,
  2,
  255,
  99,
  248,
  223,
  192,
  248,
  143,
  129,
  151,
  11,
  0,
  246,
  94,
  6,
  231,
  8,
  0,
  0,
  0,
];
