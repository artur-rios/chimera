import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test('GivenStringSourceInTextMode_WhenBase64DecodeExecutes_ThenStableTextJsonReturns', () async {
    final result = await const Base64DecodeService().execute(
      Base64DecodeOperationRequest.text(
        'SGVsbG8=',
        mode: Base64DecodeMode.text,
      ),
    );

    result.fold(
      onSuccess: (value) {
        expect(value.mode, Base64DecodeMode.text);
        expect(value.text, 'Hello');
        expect(value.bytes, <int>[0x48, 0x65, 0x6C, 0x6C, 0x6F]);
        expect(value.inputCharacterCount, 8);
        expect(value.outputByteCount, 5);
        expect(value.imageCandidateMediaType, isNull);
        expect(value.toJson().keys, <String>[
          'mode',
          'text',
          'bytes',
          'inputCharacterCount',
          'outputByteCount',
          'imageCandidateMediaType',
        ]);
        expect(value.toJson(), <String, Object?>{
          'mode': 'text',
          'text': 'Hello',
          'bytes': null,
          'inputCharacterCount': 8,
          'outputByteCount': 5,
          'imageCandidateMediaType': null,
        });
      },
      onFailure: (failure) => fail(failure.code),
    );
  });

  test('GivenStrictUtf8SourceInBinaryMode_WhenBase64DecodeExecutes_ThenExactImageBytesReturn', () async {
    final result = await const Base64DecodeService().execute(
      Base64DecodeOperationRequest.utf8Bytes(<int>[
        0x69,
        0x56,
        0x42,
        0x4F,
        0x52,
        0x77,
        0x30,
        0x4B,
        0x47,
        0x67,
        0x6F,
        0x3D,
      ], mode: Base64DecodeMode.binary),
    );

    result.fold(
      onSuccess: (value) {
        expect(value.mode, Base64DecodeMode.binary);
        expect(value.text, isNull);
        expect(value.bytes, <int>[
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
        ]);
        expect(value.inputCharacterCount, 12);
        expect(value.outputByteCount, 8);
        expect(value.imageCandidateMediaType, 'image/png');
        expect(value.toJson(), <String, Object?>{
          'mode': 'binary',
          'text': null,
          'bytes': <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
          'inputCharacterCount': 12,
          'outputByteCount': 8,
          'imageCandidateMediaType': 'image/png',
        });
      },
      onFailure: (failure) => fail(failure.code),
    );
  });

  test('GivenDecodedBytes_WhenOutputReturns_ThenBytesAreImmutableWithoutASecondRetainedCopy', () async {
    final result = await const Base64DecodeService().execute(
      Base64DecodeOperationRequest.text('AP8=', mode: Base64DecodeMode.binary),
    );

    result.fold(
      onSuccess: (value) {
        expect(value.bytes, same(value.result.bytes));
        expect(() => value.bytes[0] = 1, throwsUnsupportedError);
      },
      onFailure: (failure) => fail(failure.code),
    );
  });

  test(
    'GivenMalformedBase64_WhenDecodeExecutes_ThenRedactedValidationReturns',
    () async {
      const sensitiveInput = 'not-base64';
      final result = await const Base64DecodeService().execute(
        Base64DecodeOperationRequest.text(
          sensitiveInput,
          mode: Base64DecodeMode.binary,
        ),
      );

      result.fold(
        onSuccess: (_) => fail('Expected failure'),
        onFailure: (failure) {
          expect(failure.kind, FailureKind.validation);
          expect(failure.code, 'base64-decode.invalid-input');
          expect(failure.messageKey, 'error.base64Decode.validation');
          expect(failure.details, <String, Object?>{
            'field': 'input',
            'reason': 'malformed-base64',
          });
          expect(failure.details.keys, isNot(contains('input')));
          expect(failure.details.toString(), isNot(contains(sensitiveInput)));
        },
      );
    },
  );

  test(
    'GivenNonUtf8DecodedText_WhenDecodeExecutes_ThenRedactedValidationReturns',
    () async {
      final result = await const Base64DecodeService().execute(
        Base64DecodeOperationRequest.text('/w==', mode: Base64DecodeMode.text),
      );

      result.fold(
        onSuccess: (_) => fail('Expected failure'),
        onFailure: (failure) {
          expect(failure.kind, FailureKind.validation);
          expect(failure.code, 'base64-decode.invalid-text');
          expect(failure.messageKey, 'error.base64Decode.validation');
          expect(failure.details, <String, Object?>{
            'field': 'output',
            'reason': 'invalid-utf8',
          });
          expect(failure.details.toString(), isNot(contains('/w==')));
        },
      );
    },
  );

  test('GivenInvalidStrictUtf8Source_WhenDecodeExecutes_ThenRedactedValidationReturns', () async {
    final result = await const Base64DecodeService().execute(
      Base64DecodeOperationRequest.utf8Bytes(<int>[
        0xC3,
        0x28,
      ], mode: Base64DecodeMode.binary),
    );

    result.fold(
      onSuccess: (_) => fail('Expected failure'),
      onFailure: (failure) {
        expect(failure.kind, FailureKind.validation);
        expect(failure.code, 'base64-decode.invalid-input');
        expect(failure.messageKey, 'error.base64Decode.validation');
        expect(failure.details, <String, Object?>{
          'field': 'input',
          'reason': 'invalid-utf8',
        });
        expect(failure.details.toString(), isNot(contains('195')));
      },
    );
  });

  test(
    'GivenOutputBudget_WhenDecodeExecutes_ThenRedactedResourceFailureReturns',
    () async {
      const sensitiveInput = 'c2Vuc2l0aXZl';
      final result =
          await const Base64DecodeService(
            decoder: Base64ByteDecoder(maxOutputBytes: 1),
          ).execute(
            Base64DecodeOperationRequest.text(
              sensitiveInput,
              mode: Base64DecodeMode.binary,
            ),
          );

      result.fold(
        onSuccess: (_) => fail('Expected failure'),
        onFailure: (failure) {
          expect(failure.kind, FailureKind.resource);
          expect(failure.code, 'base64-decode.resource-limit');
          expect(failure.messageKey, 'error.base64Decode.resource');
          expect(failure.details, <String, Object?>{
            'field': 'output',
            'reason': 'byte-limit',
          });
          expect(failure.details.toString(), isNot(contains(sensitiveInput)));
        },
      );
    },
  );
}
