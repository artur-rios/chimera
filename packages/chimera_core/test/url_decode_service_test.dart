import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  for (final bytes in [false, true]) {
    test('Given${bytes}Source_WhenDecoded_ThenExactFreshJsonReturns', () async {
      const input = '\uFEFFOlá+%20%F0%9F%99%82%2520\u0000\r\n';
      final request = bytes
          ? UrlDecodeOperationRequest.utf8Bytes(utf8.encode(input))
          : UrlDecodeOperationRequest.text(input);
      final output = (await const UrlDecodeService().execute(
        request,
      ) as ChimeraSuccess<UrlDecodeOutput>).value;
      expect(output.decoded, '\uFEFFOlá+ 🙂%20\u0000\r\n');
      expect(output.toJson(), {'decoded': output.decoded});
      output.toJson()['decoded'] = 'changed';
      expect(output.decoded, isNot('changed'));
      expect(request.toString(), isNot(contains(input)));
    });
  }
  for (final input in ['', 'second', '%41']) {
    test(
      'GivenIndependent${input}_WhenDecoded_ThenNoPreviousRequestIsRetained',
      () async {
        const service = UrlDecodeService();
        await service.execute(UrlDecodeOperationRequest.text('private'));
        final output = (await service.execute(
          UrlDecodeOperationRequest.text(input),
        ) as ChimeraSuccess<UrlDecodeOutput>).value;
        expect(output.decoded, Uri.decodeComponent(input));
      },
    );
  }
  for (final fixture
      in <(UrlDecodeOperationRequest, UrlDecoder, FailureKind, String, String)>[
        (
          UrlDecodeOperationRequest.text('private-%'),
          const UrlDecoder(),
          FailureKind.validation,
          'input',
          'malformed-percent',
        ),
        (
          UrlDecodeOperationRequest.text('private-%C0%AF'),
          const UrlDecoder(),
          FailureKind.validation,
          'input',
          'invalid-percent-utf8',
        ),
        (
          UrlDecodeOperationRequest.utf8Bytes([0xc3, 0x28]),
          const UrlDecoder(),
          FailureKind.validation,
          'input',
          'invalid-utf8',
        ),
        (
          UrlDecodeOperationRequest.text('private'),
          const UrlDecoder(maxInputCharacters: 1),
          FailureKind.resource,
          'input',
          'input-limit',
        ),
        (
          UrlDecodeOperationRequest.text('private'),
          const UrlDecoder(maxOutputCharacters: 1),
          FailureKind.resource,
          'decoded',
          'output-limit',
        ),
        (
          UrlDecodeOperationRequest.text('private'),
          UrlDecoder.forTesting(convert: (_) => throw OutOfMemoryError()),
          FailureKind.resource,
          'decoded',
          'allocation-limit',
        ),
      ]) {
    test(
      'Given${fixture.$5}_WhenDecoded_ThenTypedRedactedFailureReturns',
      () async {
        final failure = await UrlDecodeService(
          decoder: fixture.$2,
        ).execute(fixture.$1) as ChimeraFailure<UrlDecodeOutput>;
        expect(failure.kind, fixture.$3);
        expect(
          failure.code,
          fixture.$3 == FailureKind.validation
              ? 'url-decode.malformed-input'
              : 'url-decode.resource-limit',
        );
        expect(
          failure.messageKey,
          fixture.$3 == FailureKind.validation
              ? 'error.urlDecode.validation'
              : 'error.urlDecode.resource',
        );
        expect(failure.details['field'], fixture.$4);
        expect(failure.details['reason'], fixture.$5);
        expect('${failure.details} $failure', isNot(contains('private')));
      },
    );
  }
}
