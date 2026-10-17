import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test(
    'GivenTextRequest_WhenCompressed_ThenDefaultLevelAndUtf8CountsReturn',
    () async {
      final request = GzipCompressOperationRequest.text('Olá 😀');
      final output = _success(
        await const GzipCompressService().execute(request),
      );

      expect(request.level, 6);
      expect(output.level, 6);
      expect(gzip.decode(output.bytes), <int>[
        79,
        108,
        195,
        161,
        32,
        240,
        159,
        152,
        128,
      ]);
      expect(output.inputByteCount, 9);
      expect(output.outputByteCount, output.bytes.length);
    },
  );

  test(
    'GivenRawByteRequest_WhenCompressed_ThenDefaultLevelPreservesNonUtf8Bytes',
    () async {
      final request = GzipCompressOperationRequest.bytes(<int>[
        0,
        255,
        128,
        13,
        10,
      ]);
      final output = _success(
        await const GzipCompressService().execute(request),
      );

      expect(request.level, 6);
      expect(output.level, 6);
      expect(gzip.decode(output.bytes), <int>[0, 255, 128, 13, 10]);
      expect(output.inputByteCount, 5);
      expect(output.outputByteCount, output.bytes.length);
    },
  );

  for (final level in List<int>.generate(10, (index) => index)) {
    for (final isText in <bool>[true, false]) {
      final source = isText ? 'Text' : 'Bytes';
      test(
        'Given${source}Level${level}_WhenCompressed_ThenLevelIsDelegatedExactlyOnce',
        () async {
          var calls = 0;
          final compressor = GzipCompressor.forTesting(
            encode: (input, actualLevel) {
              calls++;
              expect(input, <int>[104, 101, 108, 108, 111]);
              expect(actualLevel, level);
              return Uint8List.fromList(_helloGzip);
            },
          );
          final request = isText
              ? GzipCompressOperationRequest.text('hello', level: level)
              : GzipCompressOperationRequest.bytes(<int>[
                  104,
                  101,
                  108,
                  108,
                  111,
                ], level: level);

          final output = _success(
            await GzipCompressService(compressor: compressor).execute(request),
          );

          expect(calls, 1);
          expect(request.level, level);
          expect(output.level, level);
          expect(output.bytes, _helloGzip);
          expect(output.inputByteCount, 5);
          expect(output.outputByteCount, 25);
        },
      );
    }
  }

  test(
    'GivenLevelZero_WhenCompressed_ThenStoredMemberAndUtilityCountsReturn',
    () async {
      final output = _success(
        await const GzipCompressService().execute(
          GzipCompressOperationRequest.text('hello', level: 0),
        ),
      );

      expect(output.level, 0);
      expect(output.bytes, <int>[
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
        134,
        166,
        16,
        54,
        5,
        0,
        0,
        0,
      ]);
      expect(output.inputByteCount, 5);
      expect(output.outputByteCount, 28);
    },
  );

  for (final isText in <bool>[true, false]) {
    final source = isText ? 'Text' : 'Bytes';
    test(
      'GivenEmpty${source}_WhenCompressed_ThenValidEmptyMemberReturns',
      () async {
        final output = _success(
          await const GzipCompressService().execute(
            isText
                ? GzipCompressOperationRequest.text('')
                : GzipCompressOperationRequest.bytes(<int>[]),
          ),
        );

        expect(gzip.decode(output.bytes), isEmpty);
        expect(output.level, 6);
        expect(output.inputByteCount, 0);
        expect(output.outputByteCount, output.bytes.length);
      },
    );
  }

  test('GivenMutableInput_WhenOutputReturns_ThenExactUtilityPayloadIsOwnedAndImmutable', () async {
    final input = <int>[0, 255, 128];
    final output = _success(
      await const GzipCompressService().execute(
        GzipCompressOperationRequest.bytes(input),
      ),
    );
    input.fillRange(0, input.length, 1);

    expect(output.bytes, same(output.result.bytes));
    expect(output.bytes, same(output.bytes));
    expect(output.level, output.result.level);
    expect(output.inputByteCount, output.result.inputByteCount);
    expect(output.outputByteCount, output.result.outputByteCount);
    expect(gzip.decode(output.bytes), <int>[0, 255, 128]);
    expect(() => output.bytes[0] = 0, throwsUnsupportedError);
    expect(
      () => output.bytes.buffer.asUint8List()[0] = 0,
      throwsUnsupportedError,
    );
  });

  test('GivenCompressedOutput_WhenSerialized_ThenOrderedJsonHasTransientIntegerBytes', () async {
    final output = _success(
      await const GzipCompressService().execute(
        GzipCompressOperationRequest.text('hello'),
      ),
    );
    final json = output.toJson();

    expect(json.keys, <String>[
      'level',
      'bytes',
      'inputByteCount',
      'outputByteCount',
    ]);
    expect(json['bytes'], isA<List<int>>());
    expect(
      jsonEncode(json),
      '{"level":6,"bytes":[31,139,8,0,0,0,0,0,0,255,203,72,205,201,201,7,0,134,166,16,54,5,0,0,0],"inputByteCount":5,"outputByteCount":25}',
    );
    final serializedBytes = json['bytes']! as List<int>;
    expect(serializedBytes, isNot(same(output.bytes)));
    serializedBytes[0] = 0;
    json['level'] = 9;

    expect(output.bytes, _helloGzip);
    expect(output.level, 6);
    expect(output.toJson()['bytes'], _helloGzip);
    expect(output.toJson()['bytes'], isNot(same(serializedBytes)));
  });

  for (final level in <int>[-1, 10]) {
    for (final isText in <bool>[true, false]) {
      final source = isText ? 'Text' : 'Bytes';
      test(
        'Given${source}Level${level}_WhenCompressed_ThenRedactedLevelValidationReturns',
        () async {
          final request = isText
              ? GzipCompressOperationRequest.text(_sensitive, level: level)
              : GzipCompressOperationRequest.bytes(
                  _UnreadableBytes(),
                  level: level,
                );

          _expectFailure(
            await const GzipCompressService().execute(request),
            kind: FailureKind.validation,
            code: 'gzip-compress.invalid-level',
            field: 'level',
            reason: 'outside-range',
          );
        },
      );
    }
  }

  test(
    'GivenInvalidUnicode_WhenCompressed_ThenRedactedInputValidationReturns',
    () async {
      _expectFailure(
        await const GzipCompressService().execute(
          GzipCompressOperationRequest.text('$_sensitive\uD800'),
        ),
        kind: FailureKind.validation,
        code: 'gzip-compress.invalid-input',
        field: 'input',
        reason: 'invalid-unicode',
      );
    },
  );

  for (final byte in <int>[-1, 256]) {
    test(
      'GivenByte${byte}_WhenCompressed_ThenRedactedByteValidationReturns',
      () async {
        _expectFailure(
          await const GzipCompressService().execute(
            GzipCompressOperationRequest.bytes(<int>[0, byte, 255]),
          ),
          kind: FailureKind.validation,
          code: 'gzip-compress.invalid-input',
          field: 'input',
          reason: 'byte-range',
        );
      },
    );
  }

  for (final isInput in <bool>[true, false]) {
    final field = isInput ? 'input' : 'output';
    test(
      'Given${field}Budget_WhenExceeded_ThenRedactedResourceFailureReturns',
      () async {
        final compressor = isInput
            ? const GzipCompressor(maxInputBytes: 1)
            : const GzipCompressor(maxOutputBytes: 1);

        _expectFailure(
          await GzipCompressService(compressor: compressor)
              .execute(GzipCompressOperationRequest.text(_sensitive)),
          kind: FailureKind.resource,
          code: 'gzip-compress.resource-limit',
          field: field,
          reason: 'byte-limit',
        );
      },
    );
  }

  test('GivenInputCopyExhaustion_WhenCompressed_ThenRedactedResourceFailureReturns', () async {
    _expectFailure(
      await GzipCompressService(
        compressor: GzipCompressor.forTesting(
          copyBytes: (_) => throw OutOfMemoryError(),
        ),
      ).execute(GzipCompressOperationRequest.bytes(<int>[0, 255])),
      kind: FailureKind.resource,
      code: 'gzip-compress.resource-limit',
      field: 'input',
      reason: 'allocation-limit',
    );
  });

  test(
    'GivenUtf8Exhaustion_WhenCompressed_ThenRedactedResourceFailureReturns',
    () async {
      _expectFailure(
        await GzipCompressService(
          compressor: GzipCompressor.forTesting(
            encodeUtf8: (_) => throw OutOfMemoryError(),
          ),
        ).execute(GzipCompressOperationRequest.text(_sensitive)),
        kind: FailureKind.resource,
        code: 'gzip-compress.resource-limit',
        field: 'input',
        reason: 'allocation-limit',
      );
    },
  );

  test(
    'GivenEncoderExhaustion_WhenCompressed_ThenRedactedResourceFailureReturns',
    () async {
      _expectFailure(
        await GzipCompressService(
          compressor: GzipCompressor.forTesting(
            encode: (_, _) => throw OutOfMemoryError(),
          ),
        ).execute(GzipCompressOperationRequest.text(_sensitive)),
        kind: FailureKind.resource,
        code: 'gzip-compress.resource-limit',
        field: 'output',
        reason: 'allocation-limit',
      );
    },
  );

  test('GivenOwnershipExhaustion_WhenCompressed_ThenRedactedResourceFailureReturns', () async {
    _expectFailure(
      await GzipCompressService(
        compressor: GzipCompressor.forTesting(
          copyBytes: (_) => throw OutOfMemoryError(),
        ),
      ).execute(GzipCompressOperationRequest.text(_sensitive)),
      kind: FailureKind.resource,
      code: 'gzip-compress.resource-limit',
      field: 'output',
      reason: 'allocation-limit',
    );
  });

  test('GivenUnexpectedDependencyError_WhenCompressed_ThenOnlyTypedFailuresAreMapped', () async {
    final error = StateError(_sensitive);
    final service = GzipCompressService(
      compressor: GzipCompressor.forTesting(encode: (_, _) => throw error),
    );

    await expectLater(
      service.execute(GzipCompressOperationRequest.text('hello')),
      throwsA(same(error)),
    );
  });
}

GzipCompressOutput _success(ChimeraResult<GzipCompressOutput> result) =>
    result.fold(
      onSuccess: (output) => output,
      onFailure: (failure) => fail(failure.code),
    );

void _expectFailure(
  ChimeraResult<GzipCompressOutput> result, {
  required FailureKind kind,
  required String code,
  required String field,
  required String reason,
}) {
  result.fold(
    onSuccess: (_) => fail('Expected failure without partial output'),
    onFailure: (failure) {
      expect(failure.kind, kind);
      expect(failure.code, code);
      expect(
        failure.messageKey,
        kind == FailureKind.validation
            ? 'error.gzipCompress.validation'
            : 'error.gzipCompress.resource',
      );
      expect(failure.details.keys, <String>['field', 'reason']);
      expect(failure.details, <String, Object?>{
        'field': field,
        'reason': reason,
      });
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
            contains('255'),
            contains('256'),
            contains('-1'),
            contains('OutOfMemory'),
            contains('StateError'),
          ),
        ),
      );
    },
  );
}

const _sensitive = 'private source C:/secrets/input.bin';
const _helloGzip = <int>[
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
