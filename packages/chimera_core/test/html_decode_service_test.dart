import 'dart:collection';
import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  const encoded = '&amp;&lt;&gt;&quot;&apos;&#39;&#xE9;&#X1F600;';
  const decoded = '&<>"\'\'é😀';

  for (final bytes in <bool>[false, true]) {
    test(
      'Given${bytes ? 'Utf8' : 'Text'}HtmlReferences_WhenDecoded_ThenExactOutputReturns',
      () async {
        final request = bytes
            ? HtmlDecodeOperationRequest.utf8Bytes(utf8.encode(encoded))
            : HtmlDecodeOperationRequest.text(encoded);

        final output = _success(
          await const HtmlDecodeService().execute(request),
        );

        expect(output.decoded, decoded);
      },
    );
  }

  test('GivenNestedEntityText_WhenDecoded_ThenItDecodesExactlyOnce', () async {
    final output = _success(
      await const HtmlDecodeService().execute(
        HtmlDecodeOperationRequest.text('&amp;lt;'),
      ),
    );

    expect(output.decoded, '&lt;');
  });

  test('GivenEmptySources_WhenDecoded_ThenEmptyOutputReturns', () async {
    for (final request in <HtmlDecodeOperationRequest>[
      HtmlDecodeOperationRequest.text(''),
      HtmlDecodeOperationRequest.utf8Bytes(<int>[]),
    ]) {
      expect(
        _success(await const HtmlDecodeService().execute(request)).decoded,
        '',
      );
    }
  });

  test(
    'GivenPrivateSource_WhenSerialized_ThenFreshOrderedJsonContainsOnlyOutput',
    () async {
      final request = HtmlDecodeOperationRequest.text(
        '&lt;private-source-marker&gt;',
      );

      final output = _success(await const HtmlDecodeService().execute(request));

      expect(request.toString(), isNot(contains('private-source-marker')));
      expect(output.toString(), isNot(contains('private-source-marker')));
      expect(
        jsonEncode(output.toJson()),
        '{"decoded":"<private-source-marker>"}',
      );
      final first = output.toJson()..['decoded'] = 'changed';
      expect(identical(first, output.toJson()), isFalse);
      expect(output.toJson().keys, <String>['decoded']);
      expect(output.decoded, '<private-source-marker>');
    },
  );

  test(
    'GivenRepeatedSources_WhenDecoded_ThenOneConversionPerIndependentCall',
    () async {
      final seen = <String>[];
      final service = HtmlDecodeService(
        decoder: HtmlEntityDecoder.forTesting(
          convert: (input) {
            seen.add(input);
            return 'decoded-${seen.length}';
          },
        ),
      );

      final first = _success(
        await service.execute(HtmlDecodeOperationRequest.text('first-private')),
      );
      final second = _success(
        await service.execute(
          HtmlDecodeOperationRequest.utf8Bytes(utf8.encode('second-private')),
        ),
      );
      final third = _success(
        await service.execute(HtmlDecodeOperationRequest.text('third-private')),
      );

      expect(seen, <String>[
        'first-private',
        'second-private',
        'third-private',
      ]);
      expect(first.decoded, 'decoded-1');
      expect(second.decoded, 'decoded-2');
      expect(third.decoded, 'decoded-3');
    },
  );

  group('Typed failure mapping and redaction', () {
    final fixtures =
        <
          ({
            String name,
            HtmlDecodeOperationRequest request,
            HtmlEntityDecoder decoder,
            FailureKind kind,
            String field,
            String reason,
            int? offset,
          })
        >[
          (
            name: 'UnknownEntity',
            request: HtmlDecodeOperationRequest.text('private-&marker;'),
            decoder: const HtmlEntityDecoder(),
            kind: FailureKind.validation,
            field: 'input',
            reason: 'unknown-entity',
            offset: 8,
          ),
          (
            name: 'UnterminatedEntity',
            request: HtmlDecodeOperationRequest.text('private-&amp'),
            decoder: const HtmlEntityDecoder(),
            kind: FailureKind.validation,
            field: 'input',
            reason: 'unterminated-entity',
            offset: 8,
          ),
          (
            name: 'InvalidNumber',
            request: HtmlDecodeOperationRequest.text('private-&#x+41;'),
            decoder: const HtmlEntityDecoder(),
            kind: FailureKind.validation,
            field: 'input',
            reason: 'invalid-number',
            offset: 8,
          ),
          (
            name: 'OutOfRange',
            request: HtmlDecodeOperationRequest.text('private-&#x110000;'),
            decoder: const HtmlEntityDecoder(),
            kind: FailureKind.validation,
            field: 'input',
            reason: 'out-of-range',
            offset: 8,
          ),
          (
            name: 'SurrogateScalar',
            request: HtmlDecodeOperationRequest.text('private-&#55296;'),
            decoder: const HtmlEntityDecoder(),
            kind: FailureKind.validation,
            field: 'input',
            reason: 'surrogate-scalar',
            offset: 8,
          ),
          (
            name: 'InvalidUtf8',
            request: HtmlDecodeOperationRequest.utf8Bytes(<int>[
              0x61,
              0xc3,
              0x28,
            ]),
            decoder: const HtmlEntityDecoder(),
            kind: FailureKind.validation,
            field: 'input',
            reason: 'invalid-utf8',
            offset: 1,
          ),
          (
            name: 'InputLimit',
            request: HtmlDecodeOperationRequest.text('private-source-marker'),
            decoder: const HtmlEntityDecoder(maxInputCharacters: 1),
            kind: FailureKind.resource,
            field: 'input',
            reason: 'input-limit',
            offset: null,
          ),
          (
            name: 'OutputLimit',
            request: HtmlDecodeOperationRequest.text('private-source-marker'),
            decoder: const HtmlEntityDecoder(maxOutputCharacters: 1),
            kind: FailureKind.resource,
            field: 'decoded',
            reason: 'output-limit',
            offset: null,
          ),
          (
            name: 'ConversionAllocation',
            request: HtmlDecodeOperationRequest.text('private-source-marker'),
            decoder: HtmlEntityDecoder.forTesting(
              convert: (_) => throw OutOfMemoryError(),
            ),
            kind: FailureKind.resource,
            field: 'decoded',
            reason: 'allocation-limit',
            offset: null,
          ),
          (
            name: 'Utf8Allocation',
            request: HtmlDecodeOperationRequest.utf8Bytes(
              _AllocationFailingBytes(),
            ),
            decoder: const HtmlEntityDecoder(),
            kind: FailureKind.resource,
            field: 'input',
            reason: 'allocation-limit',
            offset: null,
          ),
        ];

    for (final fixture in fixtures) {
      test(
        'Given${fixture.name}_WhenDecoded_ThenExactRedactedFailureReturns',
        () async {
          Object actual;
          try {
            actual = await HtmlDecodeService(decoder: fixture.decoder)
                .execute(fixture.request);
          } on HtmlEntityDecodeException catch (error) {
            actual = error;
          }

          expect(actual, isA<ChimeraFailure<HtmlDecodeOutput>>());
          final failure = actual as ChimeraFailure<HtmlDecodeOutput>;
          expect(failure.kind, fixture.kind);
          expect(
            failure.code,
            fixture.kind == FailureKind.validation
                ? 'html-decode.malformed-input'
                : 'html-decode.resource-limit',
          );
          expect(
            failure.messageKey,
            fixture.kind == FailureKind.validation
                ? 'error.htmlDecode.validation'
                : 'error.htmlDecode.resource',
          );
          expect(failure.details, <String, Object?>{
            'field': fixture.field,
            'reason': fixture.reason,
            if (fixture.offset != null) 'offset': fixture.offset,
          });
          expect(
            failure.details.keys,
            fixture.offset == null
                ? <String>['field', 'reason']
                : <String>['field', 'reason', 'offset'],
          );
          final diagnostics =
              '${failure.kind} ${failure.code} ${failure.messageKey} '
              '${failure.details} $failure';
          for (final forbidden in <String>[
            'private-source-marker',
            'private-&marker;',
            'OutOfMemoryError',
            'HtmlEntityDecodeException',
            '195',
            '40',
          ]) {
            expect(diagnostics, isNot(contains(forbidden)));
          }
        },
      );
    }
  });

  test(
    'GivenUnexpectedDependencyError_WhenDecoded_ThenSameErrorPropagates',
    () async {
      final error = StateError('private-dependency-marker');
      final service = HtmlDecodeService(
        decoder: HtmlEntityDecoder.forTesting(convert: (_) => throw error),
      );

      for (final request in <HtmlDecodeOperationRequest>[
        HtmlDecodeOperationRequest.text('private-source-marker'),
        HtmlDecodeOperationRequest.utf8Bytes(<int>[0x61]),
      ]) {
        await expectLater(service.execute(request), throwsA(same(error)));
      }
    },
  );
}

HtmlDecodeOutput _success(ChimeraResult<HtmlDecodeOutput> result) =>
    result.fold(
      onSuccess: (output) => output,
      onFailure: (failure) => fail('Unexpected ${failure.code}'),
    );

final class _AllocationFailingBytes extends ListBase<int> {
  @override
  int get length => 1;

  @override
  set length(int value) => throw UnsupportedError('immutable fixture');

  @override
  int operator [](int index) => throw OutOfMemoryError();

  @override
  void operator []=(int index, int value) =>
      throw UnsupportedError('immutable fixture');
}
