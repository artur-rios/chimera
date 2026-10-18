import 'dart:collection';
import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  const source = '&<>"\'/ ação 😀';
  const answers = <String, String>{
    'all': '&amp;&lt;&gt;&quot;&#39;&#47; ação 😀',
    'element': '&amp;&lt;&gt;"\'/ ação 😀',
    'double-quoted-attribute': '&amp;&lt;&gt;&quot;\'/ ação 😀',
    'single-quoted-attribute': '&amp;&lt;&gt;"&#39;/ ação 😀',
  };

  // Mutation: dispatch the wrong source or omit/change the selected context.
  for (final entry in answers.entries) {
    for (final bytes in <bool>[false, true]) {
      test('Given${bytes ? 'Utf8' : 'Text'}And${entry.key}'
          '_WhenEncoded_ThenExactOutputAndContextReturn', () async {
        final result = await const HtmlEncodeService().execute(
          bytes
              ? HtmlEncodeOperationRequest.utf8Bytes(
                  utf8.encode(source),
                  context: entry.key,
                )
              : HtmlEncodeOperationRequest.text(source, context: entry.key),
        );
        final output = _success(result);
        expect(output.encoded, entry.value);
        expect(output.context, entry.key);
      });
    }
  }

  // Mutation: change the default, reject empty source, or invent output.
  test(
    'GivenEmptySources_WhenEncoded_ThenEmptyAllContextOutputReturns',
    () async {
      for (final request in <HtmlEncodeOperationRequest>[
        HtmlEncodeOperationRequest.text(''),
        HtmlEncodeOperationRequest.utf8Bytes(<int>[]),
      ]) {
        final output = _success(
          await const HtmlEncodeService().execute(request),
        );
        expect(output.encoded, '');
        expect(output.context, 'all');
      }
    },
  );

  // Mutation: serialize source/extra fields, reorder keys, or reuse a mutable map.
  test(
    'GivenPrivateSource_WhenSerialized_ThenFreshOrderedJsonContainsOnlyOutput',
    () async {
      final request = HtmlEncodeOperationRequest.text(
        '<private-source-marker>',
        context: 'element',
      );
      final output = _success(await const HtmlEncodeService().execute(request));
      expect(request.context, 'element');
      expect(request.toString(), isNot(contains('private-source-marker')));
      expect(output.toString(), isNot(contains('private-source-marker')));
      expect(
        jsonEncode(output.toJson()),
        '{"encoded":"&lt;private-source-marker&gt;","context":"element"}',
      );
      final first = output.toJson()..['encoded'] = 'changed';
      expect(identical(first, output.toJson()), isFalse);
      expect(output.toJson().keys, <String>['encoded', 'context']);
      expect(output.encoded, '&lt;private-source-marker&gt;');
      expect(output.toJson()['encoded'], '&lt;private-source-marker&gt;');
    },
  );

  // Mutation: convert twice, replace the source, reuse a result, or lose the mode.
  test(
    'GivenRepeatedSources_WhenEncoded_ThenOneConversionPerIndependentCall',
    () async {
      final seen = <(String, HtmlEscapeMode)>[];
      final service = HtmlEncodeService(
        encoder: HtmlEntityEncoder.forTesting(
          convert: (input, mode) {
            seen.add((input, mode));
            return 'converted-${seen.length}';
          },
        ),
      );
      final first = _success(
        await service.execute(
          HtmlEncodeOperationRequest.text('first-private', context: 'element'),
        ),
      );
      final second = _success(
        await service.execute(
          HtmlEncodeOperationRequest.utf8Bytes(<int>[
            0xc3,
            0xa7,
            0x22,
          ], context: 'double-quoted-attribute'),
        ),
      );
      final third = _success(
        await service.execute(HtmlEncodeOperationRequest.text('third-private')),
      );
      expect(seen, <(String, HtmlEscapeMode)>[
        ('first-private', HtmlEscapeMode.element),
        ('ç"', HtmlEscapeMode.attribute),
        ('third-private', HtmlEscapeMode.unknown),
      ]);
      expect(first.encoded, 'converted-1');
      expect(first.context, 'element');
      expect(second.encoded, 'converted-2');
      expect(second.context, 'double-quoted-attribute');
      expect(third.encoded, 'converted-3');
      expect(third.context, 'all');
    },
  );

  group('Typed failure mapping and redaction', () {
    // Mutation: drop the utility code/field/reason or map a wrong failure kind.
    final fixtures =
        <
          ({
            String name,
            HtmlEncodeOperationRequest request,
            HtmlEntityEncoder encoder,
            FailureKind kind,
            String code,
            String field,
            String reason,
          })
        >[
          for (final bytes in <bool>[false, true])
            (
              name: '${bytes ? 'Utf8' : 'Text'}InvalidContext',
              request: bytes
                  ? HtmlEncodeOperationRequest.utf8Bytes(
                      utf8.encode('<private-source-marker>'),
                      context: 'private-context-marker',
                    )
                  : HtmlEncodeOperationRequest.text(
                      '<private-source-marker>',
                      context: 'private-context-marker',
                    ),
              encoder: const HtmlEntityEncoder(),
              kind: FailureKind.validation,
              code: 'html-encode.invalid-context',
              field: 'context',
              reason: 'unsupported-context',
            ),
          (
            name: 'InvalidUnicode',
            request: HtmlEncodeOperationRequest.text(
              'private-source-marker${String.fromCharCode(0xd800)}',
            ),
            encoder: const HtmlEntityEncoder(),
            kind: FailureKind.validation,
            code: 'html-encode.invalid-input',
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
              request: HtmlEncodeOperationRequest.utf8Bytes(bytes),
              encoder: const HtmlEntityEncoder(),
              kind: FailureKind.validation,
              code: 'html-encode.invalid-input',
              field: 'input',
              reason: 'invalid-utf8',
            ),
          for (final bytes in <bool>[false, true])
            for (final inputLimit in <bool>[true, false])
              (
                name:
                    '${bytes ? 'Utf8' : 'Text'}${inputLimit ? 'Input' : 'Output'}Limit',
                request: bytes
                    ? HtmlEncodeOperationRequest.utf8Bytes(
                        utf8.encode('<private-source-marker>'),
                      )
                    : HtmlEncodeOperationRequest.text(
                        '<private-source-marker>',
                      ),
                encoder: HtmlEntityEncoder(
                  maxInputCharacters: inputLimit ? 1 : null,
                  maxOutputCharacters: inputLimit ? null : 1,
                ),
                kind: FailureKind.resource,
                code: 'html-encode.resource-limit',
                field: inputLimit ? 'input' : 'encoded',
                reason: inputLimit ? 'input-limit' : 'output-limit',
              ),
          for (final bytes in <bool>[false, true])
            (
              name: '${bytes ? 'Utf8' : 'Text'}ConversionAllocation',
              request: bytes
                  ? HtmlEncodeOperationRequest.utf8Bytes(
                      utf8.encode('<private-source-marker>'),
                    )
                  : HtmlEncodeOperationRequest.text('<private-source-marker>'),
              encoder: HtmlEntityEncoder.forTesting(
                convert: (_, _) => throw OutOfMemoryError(),
              ),
              kind: FailureKind.resource,
              code: 'html-encode.resource-limit',
              field: 'encoded',
              reason: 'allocation-limit',
            ),
          (
            name: 'Utf8DecodeAllocation',
            request: HtmlEncodeOperationRequest.utf8Bytes(
              _AllocationFailingBytes(),
            ),
            encoder: const HtmlEntityEncoder(),
            kind: FailureKind.resource,
            code: 'html-encode.resource-limit',
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
            actual = await HtmlEncodeService(encoder: fixture.encoder)
                .execute(fixture.request);
          } on HtmlEntityEncodeException catch (error) {
            // Keep a missing mapping an assertion failure during the RED phase.
            actual = error;
          }
          expect(actual, isA<ChimeraFailure<HtmlEncodeOutput>>());
          final failure = actual as ChimeraFailure<HtmlEncodeOutput>;
          expect(failure.kind, fixture.kind);
          expect(failure.code, fixture.code);
          expect(
            failure.messageKey,
            fixture.kind == FailureKind.validation
                ? 'error.htmlEncode.validation'
                : 'error.htmlEncode.resource',
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
            'private-context-marker',
            '&lt;',
            'OutOfMemoryError',
            'HtmlEntityEncodeException',
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
      const service = HtmlEncodeService(
        encoder: HtmlEntityEncoder(maxOutputCharacters: 5),
      );
      expect(
        await service.execute(
          HtmlEncodeOperationRequest.text('private-source-marker'),
        ),
        isA<ChimeraFailure<HtmlEncodeOutput>>(),
      );
      final output = _success(
        await service.execute(
          HtmlEncodeOperationRequest.utf8Bytes(<int>[0x26]),
        ),
      );
      expect(output.toJson(), <String, Object?>{
        'encoded': '&amp;',
        'context': 'all',
      });
      expect(
        await service.execute(
          HtmlEncodeOperationRequest.text('', context: 'bad'),
        ),
        isA<ChimeraFailure<HtmlEncodeOutput>>(),
      );
      expect(
        _success(await service.execute(HtmlEncodeOperationRequest.text('<')))
            .encoded,
        '&lt;',
      );
      expect(output.encoded, '&amp;');
    },
  );

  // Mutation: catch all exceptions and silently turn programming bugs into failures.
  test(
    'GivenUnexpectedDependencyError_WhenEncoded_ThenSameErrorPropagates',
    () async {
      final error = StateError('private-dependency-marker');
      final service = HtmlEncodeService(
        encoder: HtmlEntityEncoder.forTesting(convert: (_, _) => throw error),
      );
      for (final request in <HtmlEncodeOperationRequest>[
        HtmlEncodeOperationRequest.text('private-source-marker'),
        HtmlEncodeOperationRequest.utf8Bytes(<int>[0x26]),
      ]) {
        await expectLater(service.execute(request), throwsA(same(error)));
      }
    },
  );
}

HtmlEncodeOutput _success(ChimeraResult<HtmlEncodeOutput> result) =>
    result.fold(
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
