import 'dart:collection';
import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  const source = '&<>"\'/ ação 😀';
  const answers = <String, String>{
    'component': '%26%3C%3E%22\'%2F%20a%C3%A7%C3%A3o%20%F0%9F%98%80',
    'full': '&%3C%3E%22\'/%20a%C3%A7%C3%A3o%20%F0%9F%98%80',
  };

  // Mutation: dispatch the wrong source or omit/change the selected mode.
  for (final entry in answers.entries) {
    for (final bytes in <bool>[false, true]) {
      test('Given${bytes ? 'Utf8' : 'Text'}And${entry.key}'
          '_WhenEncoded_ThenExactOutputAndModeReturn', () async {
        final result = await const UrlEncodeService().execute(
          bytes
              ? UrlEncodeOperationRequest.utf8Bytes(
                  utf8.encode(source),
                  mode: entry.key,
                )
              : UrlEncodeOperationRequest.text(source, mode: entry.key),
        );
        final output = _success(result);
        expect(output.encoded, entry.value);
        expect(output.mode, entry.key);
      });
    }
  }

  // Mutation: change the default, reject empty source, or invent output.
  test('GivenEmptySources_WhenEncoded_ThenEmptyAllModeOutputReturns', () async {
    for (final request in <UrlEncodeOperationRequest>[
      UrlEncodeOperationRequest.text(''),
      UrlEncodeOperationRequest.utf8Bytes(<int>[]),
    ]) {
      final output = _success(await const UrlEncodeService().execute(request));
      expect(output.encoded, '');
      expect(output.mode, 'component');
    }
  });

  // Mutation: serialize source/extra fields, reorder keys, or reuse a mutable map.
  test(
    'GivenPrivateSource_WhenSerialized_ThenFreshOrderedJsonContainsOnlyOutput',
    () async {
      final request = UrlEncodeOperationRequest.text(
        '<private-source-marker>',
        mode: 'full',
      );
      final output = _success(await const UrlEncodeService().execute(request));
      expect(request.mode, 'full');
      expect(request.toString(), isNot(contains('private-source-marker')));
      expect(output.toString(), isNot(contains('private-source-marker')));
      expect(
        jsonEncode(output.toJson()),
        '{"encoded":"%3Cprivate-source-marker%3E","mode":"full"}',
      );
      final first = output.toJson()..['encoded'] = 'changed';
      expect(identical(first, output.toJson()), isFalse);
      expect(output.toJson().keys, <String>['encoded', 'mode']);
      expect(output.encoded, '%3Cprivate-source-marker%3E');
      expect(output.toJson()['encoded'], '%3Cprivate-source-marker%3E');
    },
  );

  // Mutation: convert twice, replace the source, reuse a result, or lose the mode.
  test(
    'GivenRepeatedSources_WhenEncoded_ThenOneConversionPerIndependentCall',
    () async {
      final seen = <(String, String)>[];
      final service = UrlEncodeService(
        encoder: UrlEncoder.forTesting(
          convert: (input, mode) {
            seen.add((input, mode));
            return 'converted-${seen.length}';
          },
        ),
      );
      final first = _success(
        await service.execute(
          UrlEncodeOperationRequest.text('first-private', mode: 'full'),
        ),
      );
      final second = _success(
        await service.execute(
          UrlEncodeOperationRequest.utf8Bytes(<int>[
            0xc3,
            0xa7,
            0x22,
          ], mode: 'component'),
        ),
      );
      final third = _success(
        await service.execute(UrlEncodeOperationRequest.text('third-private')),
      );
      expect(seen, <(String, String)>[
        ('first-private', 'full'),
        ('ç"', 'component'),
        ('third-private', 'component'),
      ]);
      expect(first.encoded, 'converted-1');
      expect(first.mode, 'full');
      expect(second.encoded, 'converted-2');
      expect(second.mode, 'component');
      expect(third.encoded, 'converted-3');
      expect(third.mode, 'component');
    },
  );

  group('Typed failure mapping and redaction', () {
    // Mutation: drop the utility code/field/reason or map a wrong failure kind.
    final fixtures =
        <
          ({
            String name,
            UrlEncodeOperationRequest request,
            UrlEncoder encoder,
            FailureKind kind,
            String code,
            String field,
            String reason,
          })
        >[
          for (final bytes in <bool>[false, true])
            (
              name: '${bytes ? 'Utf8' : 'Text'}InvalidMode',
              request: bytes
                  ? UrlEncodeOperationRequest.utf8Bytes(
                      utf8.encode('<private-source-marker>'),
                      mode: 'private-mode-marker',
                    )
                  : UrlEncodeOperationRequest.text(
                      '<private-source-marker>',
                      mode: 'private-mode-marker',
                    ),
              encoder: const UrlEncoder(),
              kind: FailureKind.validation,
              code: 'url-encode.invalid-mode',
              field: 'mode',
              reason: 'unsupported-mode',
            ),
          (
            name: 'InvalidUnicode',
            request: UrlEncodeOperationRequest.text(
              'private-source-marker${String.fromCharCode(0xd800)}',
            ),
            encoder: const UrlEncoder(),
            kind: FailureKind.validation,
            code: 'url-encode.invalid-input',
            field: 'input',
            reason: 'invalid-unicode',
          ),
          for (final bytes in <List<int>>[
            <int>[0xc3, 0x28],
            <int>[-1],
            <int>[256],
          ])
            (
              name: 'InvalidUtf8$bytes',
              request: UrlEncodeOperationRequest.utf8Bytes(bytes),
              encoder: const UrlEncoder(),
              kind: FailureKind.validation,
              code: 'url-encode.invalid-input',
              field: 'input',
              reason: 'invalid-utf8',
            ),
          for (final bytes in <bool>[false, true])
            for (final inputLimit in <bool>[true, false])
              (
                name:
                    '${bytes ? 'Utf8' : 'Text'}${inputLimit ? 'Input' : 'Output'}Limit',
                request: bytes
                    ? UrlEncodeOperationRequest.utf8Bytes(
                        utf8.encode('<private-source-marker>'),
                      )
                    : UrlEncodeOperationRequest.text('<private-source-marker>'),
                encoder: UrlEncoder(
                  maxInputCharacters: inputLimit ? 1 : null,
                  maxOutputCharacters: inputLimit ? null : 1,
                ),
                kind: FailureKind.resource,
                code: 'url-encode.resource-limit',
                field: inputLimit ? 'input' : 'encoded',
                reason: inputLimit ? 'input-limit' : 'output-limit',
              ),
          for (final bytes in <bool>[false, true])
            (
              name: '${bytes ? 'Utf8' : 'Text'}ConversionAllocation',
              request: bytes
                  ? UrlEncodeOperationRequest.utf8Bytes(
                      utf8.encode('<private-source-marker>'),
                    )
                  : UrlEncodeOperationRequest.text('<private-source-marker>'),
              encoder: UrlEncoder.forTesting(
                convert: (_, _) => throw OutOfMemoryError(),
              ),
              kind: FailureKind.resource,
              code: 'url-encode.resource-limit',
              field: 'encoded',
              reason: 'allocation-limit',
            ),
          (
            name: 'Utf8DecodeAllocation',
            request: UrlEncodeOperationRequest.utf8Bytes(
              _AllocationFailingBytes(),
            ),
            encoder: const UrlEncoder(),
            kind: FailureKind.resource,
            code: 'url-encode.resource-limit',
            field: 'input',
            reason: 'allocation-limit',
          ),
        ];
    for (final fixture in fixtures) {
      test(
        'Given${fixture.name}_WhenEncoded_ThenExactRedactedFailureReturns',
        () async {
          Object actual;
          try {
            actual = await UrlEncodeService(encoder: fixture.encoder)
                .execute(fixture.request);
          } on UrlEncodeException catch (error) {
            // Keep a missing mapping an assertion failure during the RED phase.
            actual = error;
          }
          expect(actual, isA<ChimeraFailure<UrlEncodeOutput>>());
          final failure = actual as ChimeraFailure<UrlEncodeOutput>;
          expect(failure.kind, fixture.kind);
          expect(failure.code, fixture.code);
          expect(
            failure.messageKey,
            fixture.kind == FailureKind.validation
                ? 'error.urlEncode.validation'
                : 'error.urlEncode.resource',
          );
          expect(failure.details, <String, Object?>{
            'field': fixture.field,
            'reason': fixture.reason,
          });
          expect(failure.details.keys, <String>['field', 'reason']);
          final diagnostics =
              '${failure.kind} ${failure.code} '
              '${failure.messageKey} ${failure.details} $failure';
          for (final forbidden in <String>[
            'private-source-marker',
            'private-mode-marker',
            '%3C',
            'OutOfMemoryError',
            'UrlEncodeException',
            '-1',
            '256',
            '195',
            '40',
          ]) {
            expect(diagnostics, isNot(contains(forbidden)));
          }
        },
      );
    }
  });

  // Mutation: retain an earlier failure/result/source between calls.
  test(
    'GivenFailureThenSuccess_WhenServiceReused_ThenOnlyCurrentOutputReturns',
    () async {
      const service = UrlEncodeService(
        encoder: UrlEncoder(maxOutputCharacters: 5),
      );
      expect(
        await service.execute(
          UrlEncodeOperationRequest.text('private-source-marker'),
        ),
        isA<ChimeraFailure<UrlEncodeOutput>>(),
      );
      final output = _success(
        await service.execute(UrlEncodeOperationRequest.utf8Bytes(<int>[0x26])),
      );
      expect(output.toJson(), <String, Object?>{
        'encoded': '%26',
        'mode': 'component',
      });
      expect(
        await service.execute(UrlEncodeOperationRequest.text('', mode: 'bad')),
        isA<ChimeraFailure<UrlEncodeOutput>>(),
      );
      expect(
        _success(await service.execute(UrlEncodeOperationRequest.text('<')))
            .encoded,
        '%3C',
      );
      expect(output.encoded, '%26');
    },
  );

  // Mutation: catch all exceptions and silently turn programming bugs into failures.
  test(
    'GivenUnexpectedDependencyError_WhenEncoded_ThenSameErrorPropagates',
    () async {
      final error = StateError('private-dependency-marker');
      final service = UrlEncodeService(
        encoder: UrlEncoder.forTesting(convert: (_, _) => throw error),
      );
      for (final request in <UrlEncodeOperationRequest>[
        UrlEncodeOperationRequest.text('private-source-marker'),
        UrlEncodeOperationRequest.utf8Bytes(<int>[0x26]),
      ]) {
        await expectLater(service.execute(request), throwsA(same(error)));
      }
    },
  );
}

UrlEncodeOutput _success(ChimeraResult<UrlEncodeOutput> result) => result.fold(
  onSuccess: (output) => output,
  onFailure: (failure) => fail('Unexpected ${failure.code}'),
);

// A source-read allocation failure exercises the utility's UTF-8 decode boundary.
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
