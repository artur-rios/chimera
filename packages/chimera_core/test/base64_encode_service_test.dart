import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test(
    'GivenTextSource_WhenBase64EncodeExecutes_ThenStableJsonReturns',
    () async {
      final result = await const Base64EncodeService().execute(
        Base64EncodeOperationRequest.text('Hello'),
      );

      result.fold(
        onSuccess: (value) {
          expect(value.encoded, 'SGVsbG8=');
          expect(value.inputByteCount, 5);
          expect(value.outputCharacterCount, 8);
          expect(value.toJson(), <String, Object?>{
            'encoded': 'SGVsbG8=',
            'inputByteCount': 5,
            'outputCharacterCount': 8,
          });
        },
        onFailure: (failure) => fail(failure.code),
      );
    },
  );

  test(
    'GivenBinaryBytes_WhenBase64EncodeExecutes_ThenExactBytesAreEncoded',
    () async {
      final result = await const Base64EncodeService().execute(
        Base64EncodeOperationRequest.bytes(<int>[0x00, 0xFF]),
      );

      result.fold(
        onSuccess: (value) => expect(value.encoded, 'AP8='),
        onFailure: (failure) => fail(failure.code),
      );
    },
  );

  test(
    'GivenStrictUtf8Bytes_WhenBase64EncodeExecutes_ThenOriginalBytesAreEncoded',
    () async {
      final result = await const Base64EncodeService().execute(
        Base64EncodeOperationRequest.utf8Bytes(<int>[0xC3, 0xA9]),
      );

      result.fold(
        onSuccess: (value) => expect(value.encoded, 'w6k='),
        onFailure: (failure) => fail(failure.code),
      );
    },
  );

  test(
    'GivenInvalidByte_WhenBase64EncodeExecutes_ThenRedactedValidationReturns',
    () async {
      final result = await const Base64EncodeService().execute(
        Base64EncodeOperationRequest.bytes(<int>[-1]),
      );

      result.fold(
        onSuccess: (_) => fail('Expected failure'),
        onFailure: (failure) {
          expect(failure.kind, FailureKind.validation);
          expect(failure.code, 'base64-encode.invalid-byte');
          expect(failure.messageKey, 'error.base64Encode.validation');
          expect(failure.details, <String, Object?>{
            'field': 'input',
            'reason': 'byte-range',
          });
          expect(failure.details.keys, isNot(contains('encoded')));
          expect(failure.details.toString(), isNot(contains('-1')));
        },
      );
    },
  );

  test('GivenIsolatedSurrogate_WhenBase64EncodeExecutes_ThenUnicodeValidationReturns', () async {
    final result = await const Base64EncodeService().execute(
      Base64EncodeOperationRequest.text(String.fromCharCode(0xD800)),
    );

    result.fold(
      onSuccess: (_) => fail('Expected failure'),
      onFailure: (failure) {
        expect(failure.kind, FailureKind.validation);
        expect(failure.code, 'base64-encode.invalid-text');
        expect(failure.messageKey, 'error.base64Encode.validation');
        expect(failure.details, <String, Object?>{
          'field': 'input',
          'reason': 'invalid-unicode',
        });
        expect(failure.details.keys, isNot(contains('encoded')));
      },
    );
  });

  test(
    'GivenMalformedUtf8_WhenBase64EncodeExecutes_ThenUtf8ValidationReturns',
    () async {
      final result = await const Base64EncodeService().execute(
        Base64EncodeOperationRequest.utf8Bytes(<int>[0xC3, 0x28]),
      );

      result.fold(
        onSuccess: (_) => fail('Expected failure'),
        onFailure: (failure) {
          expect(failure.kind, FailureKind.validation);
          expect(failure.code, 'base64-encode.invalid-text');
          expect(failure.messageKey, 'error.base64Encode.validation');
          expect(failure.details, <String, Object?>{
            'field': 'input',
            'reason': 'invalid-utf8',
          });
          expect(failure.details.keys, isNot(contains('encoded')));
        },
      );
    },
  );

  test(
    'GivenResourceBudget_WhenBase64EncodeExecutes_ThenNoPartialOutputReturns',
    () async {
      final result = await const Base64EncodeService(
        encoder: Base64ByteEncoder(maxOutputCharacters: 3),
      ).execute(Base64EncodeOperationRequest.text('sensitive'));

      result.fold(
        onSuccess: (_) => fail('Expected failure'),
        onFailure: (failure) {
          expect(failure.kind, FailureKind.resource);
          expect(failure.code, 'base64-encode.resource-limit');
          expect(failure.messageKey, 'error.base64Encode.resource');
          expect(failure.details, <String, Object?>{
            'field': 'output',
            'reason': 'character-limit',
          });
          expect(failure.details.keys, isNot(contains('encoded')));
          expect(failure.details.toString(), isNot(contains('sensitive')));
        },
      );
    },
  );
}
