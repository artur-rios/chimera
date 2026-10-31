import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  group('HtmlEntityEncoder known answers', () {
    const encoder = HtmlEntityEncoder();
    const contexts = <String, List<String>>{
      'all': <String>['&amp;', '&lt;', '&gt;', '&quot;', '&#39;', '&#47;'],
      'element': <String>['&amp;', '&lt;', '&gt;', '"', "'", '/'],
      'double-quoted-attribute': <String>[
        '&amp;',
        '&lt;',
        '&gt;',
        '&quot;',
        "'",
        '/',
      ],
      'single-quoted-attribute': <String>[
        '&amp;',
        '&lt;',
        '&gt;',
        '"',
        '&#39;',
        '/',
      ],
    };
    const characters = <String>['&', '<', '>', '"', "'", '/'];
    for (final entry in contexts.entries) {
      for (var index = 0; index < characters.length; index++) {
        // Mutation: omit/change this entity or use another context's mode.
        test('Given${entry.key}AndCharacter$index'
            '_WhenTextEncodes_ThenExactEntityAndContextReturn', () {
          final result = encoder.encodeText(
            HtmlEntityEncodeRequest(
              input: characters[index],
              context: entry.key,
            ),
          );
          expect(result.encoded, entry.value[index]);
          expect(result.context, entry.key);
        });
      }
      // Mutation: trust entity-looking input, skip ampersands, or re-escape output.
      test('GivenExistingEntitiesIn${entry.key}'
          '_WhenTextEncodes_ThenEntitiesAreTreatedAsText', () {
        final result = encoder.encodeText(
          HtmlEntityEncodeRequest(
            input: '&amp; &lt; &quot; &#39; &#47;',
            context: entry.key,
          ),
        );
        expect(
          result.encoded,
          '&amp;amp; &amp;lt; &amp;quot; &amp;#39; &amp;#47;',
        );
      });
    }

    // Mutation: default to UC-10's HTML escaper, which leaves slash unchanged.
    test('GivenDefaultContext_WhenTextEncodes_ThenAllSixCharactersEncode', () {
      final result = encoder.encodeText(
        const HtmlEntityEncodeRequest(input: '&<>"\'/'),
      );
      expect(result.encoded, '&amp;&lt;&gt;&quot;&#39;&#47;');
      expect(result.context, 'all');
    });

    // Mutation: reject empty input or emit a placeholder instead of empty output.
    test('GivenEmptyInput_WhenEitherSourceEncodes_ThenOutputIsEmpty', () {
      expect(
        encoder.encodeText(const HtmlEntityEncodeRequest(input: '')).encoded,
        '',
      );
      final bytesResult = encoder.encodeUtf8(<int>[]);
      expect(bytesResult.encoded, '');
      expect(bytesResult.context, 'all');
    });

    // Mutation: trim, normalize, drop controls, or corrupt supplementary scalars.
    const preserved = <String, String>{
      'AsciiWhitespace': ' Plain ASCII 123 \t ',
      'UnicodeAndSupplementaryScalars': 'ação 東京 e\u0301 😀 𐐷',
      'BomNulAndLineEndings': '\uFEFF\u0000a\r\nb\n ',
    };
    for (final entry in preserved.entries) {
      test('Given${entry.key}_WhenTextEncodes_ThenTextIsUnchanged', () {
        expect(
          encoder
              .encodeText(HtmlEntityEncodeRequest(input: entry.value))
              .encoded,
          entry.value,
        );
      });
    }

    // Mutation: use byte-to-character decoding, omit context, or strip a BOM.
    test(
      'GivenUtf8WithBomControlsAndUnicode_WhenEncoded_ThenTextIsPreserved',
      () {
        final result = encoder.encodeUtf8(<int>[
          0xef,
          0xbb,
          0xbf,
          0x00,
          0x0d,
          0x0a,
          0xc3,
          0xa7,
          0xf0,
          0x9f,
          0x98,
          0x80,
          0x3c,
          0x27,
          0x2f,
        ], context: 'element');
        expect(result.encoded, '\uFEFF\u0000\r\nç😀&lt;\'/');
        expect(result.context, 'element');
      },
    );

    // Mutation: strip every BOM rather than only undoing SDK's leading removal.
    test('GivenTwoLeadingBoms_WhenUtf8Encodes_ThenBothArePreserved', () {
      expect(
        encoder.encodeUtf8(<int>[0xef, 0xbb, 0xbf, 0xef, 0xbb, 0xbf]).encoded,
        '\uFEFF\uFEFF',
      );
    });

    // Mutation: retain a prior source/result or mode between invocations.
    test(
      'GivenRepeatedCalls_WhenContextsChange_ThenEachResultIsIndependent',
      () {
        final first = encoder.encodeText(
          const HtmlEntityEncodeRequest(input: '/"', context: 'all'),
        );
        final second = encoder.encodeUtf8(<int>[
          0x2f,
          0x22,
        ], context: 'element');
        final third = encoder.encodeText(
          const HtmlEntityEncodeRequest(input: '/"', context: 'all'),
        );
        expect(first.encoded, '&#47;&quot;');
        expect(second.encoded, '/"');
        expect(third.encoded, '&#47;&quot;');
        expect(first.context, 'all');
        expect(second.context, 'element');
        expect(third.context, 'all');
      },
    );
  });

  group('HtmlEntityEncoder validation', () {
    const encoder = HtmlEntityEncoder();

    // Mutation: normalize context casing/whitespace or accept SDK/legacy aliases.
    for (final context in <String>[
      '',
      'ALL',
      'Element',
      ' all',
      'all ',
      'attribute',
      'sqAttribute',
      'unknown',
      'html',
      'private-source-marker',
    ]) {
      test(
        'GivenUnsupportedContext${context}_WhenEncoded_ThenValidationFails',
        () {
          for (final encode in <void Function()>[
            () => encoder.encodeText(
              HtmlEntityEncodeRequest(
                input: 'private-source-marker',
                context: context,
              ),
            ),
            () => encoder.encodeUtf8(<int>[0x26], context: context),
          ]) {
            expect(
              encode,
              _failure(
                kind: HtmlEntityEncodeFailureKind.validation,
                code: 'html-encode.invalid-context',
                field: 'context',
                reason: 'unsupported-context',
              ),
            );
          }
        },
      );
    }

    // Mutation: validate/decode input before rejecting an unsupported context.
    test('GivenInvalidContextAndSource_WhenEncoded_ThenContextFailsFirst', () {
      for (final encode in <void Function()>[
        () => encoder.encodeText(
          HtmlEntityEncodeRequest(
            input: String.fromCharCode(0xd800),
            context: 'bad',
          ),
        ),
        () => encoder.encodeUtf8(<int>[0xff], context: 'bad'),
      ]) {
        expect(
          encode,
          _failure(
            kind: HtmlEntityEncodeFailureKind.validation,
            code: 'html-encode.invalid-context',
            field: 'context',
            reason: 'unsupported-context',
          ),
        );
      }
    });

    // Mutation: omit one surrogate boundary, fail to check pairing, or replace it.
    const malformedUnits = <List<int>>[
      <int>[0xd800],
      <int>[0xdbff],
      <int>[0xdc00],
      <int>[0xdfff],
      <int>[0x61, 0xd800, 0x62],
      <int>[0x61, 0xdc00, 0x62],
      <int>[0xdc00, 0xd800],
      <int>[0xd800, 0xd800, 0xdc00],
      <int>[0xd800, 0xdc00, 0xdc00],
    ];
    for (var index = 0; index < malformedUnits.length; index++) {
      test(
        'GivenUnpairedSurrogate${index}_WhenTextEncodes_ThenValidationFails',
        () {
          expect(
            () => encoder.encodeText(
              HtmlEntityEncodeRequest(
                input: String.fromCharCodes(malformedUnits[index]),
              ),
            ),
            _failure(
              kind: HtmlEntityEncodeFailureKind.validation,
              code: 'html-encode.invalid-input',
              field: 'input',
              reason: 'invalid-unicode',
            ),
          );
        },
      );
    }

    // Mutation: allow replacement, accept non-scalars/overlong UTF-8, or mask bytes.
    const malformedBytes = <List<int>>[
      <int>[0xc3, 0x28],
      <int>[0xc0, 0xaf],
      <int>[0xf0, 0x9f, 0x98],
      <int>[0x80],
      <int>[0xff],
      <int>[0xed, 0xa0, 0x80],
      <int>[0xf4, 0x90, 0x80, 0x80],
      <int>[0xef, 0xbb],
      <int>[-1],
      <int>[256],
      <int>[0x13c],
    ];
    for (var index = 0; index < malformedBytes.length; index++) {
      test(
        'GivenMalformedUtf8${index}_WhenUtf8Encodes_ThenValidationFails',
        () {
          expect(
            () => encoder.encodeUtf8(malformedBytes[index]),
            _failure(
              kind: HtmlEntityEncodeFailureKind.validation,
              code: 'html-encode.invalid-input',
              field: 'input',
              reason: 'invalid-utf8',
            ),
          );
        },
      );
    }

    // Mutation: repair source text, retain source in errors, or leak SDK errors.
    test(
      'GivenSecretSource_WhenValidationFails_ThenDiagnosticsAreRedacted',
      () {
        try {
          encoder.encodeText(
            HtmlEntityEncodeRequest(
              input: 'private-source-marker${String.fromCharCode(0xd800)}',
            ),
          );
          fail('Expected typed Unicode validation failure');
        } on HtmlEntityEncodeException catch (error) {
          expect(error.kind, HtmlEntityEncodeFailureKind.validation);
          expect(error.code, 'html-encode.invalid-input');
          expect(error.field, 'input');
          expect(error.reason, 'invalid-unicode');
          expect(
            '${error.kind} ${error.code} ${error.field} ${error.reason} $error',
            isNot(contains('private-source-marker')),
          );
        }
      },
    );
  });

  group('HtmlEntityEncoder resource boundaries', () {
    // Mutation: count UTF-8 bytes/scalars instead of UTF-16 units, or reject equality.
    test('GivenInputBudget_WhenTextAtBoundary_ThenOnlyOverflowFails', () {
      const encoder = HtmlEntityEncoder(maxInputCharacters: 2);
      expect(
        encoder.encodeText(const HtmlEntityEncodeRequest(input: '😀')).encoded,
        '😀',
      );
      expect(
        () => encoder.encodeText(const HtmlEntityEncodeRequest(input: '😀x')),
        _failure(
          kind: HtmlEntityEncodeFailureKind.resource,
          code: 'html-encode.resource-limit',
          field: 'input',
          reason: 'input-limit',
        ),
      );
    });

    // Mutation: apply character budget to encoded bytes or omit restored BOM.
    test('GivenInputBudget_WhenUtf8AtBoundary_ThenDecodedUnitsAreCounted', () {
      const encoder = HtmlEntityEncoder(maxInputCharacters: 2);
      expect(encoder.encodeUtf8(<int>[0xf0, 0x9f, 0x98, 0x80]).encoded, '😀');
      expect(
        () => encoder.encodeUtf8(<int>[0xf0, 0x9f, 0x98, 0x80, 0x78]),
        _failure(
          kind: HtmlEntityEncodeFailureKind.resource,
          code: 'html-encode.resource-limit',
          field: 'input',
          reason: 'input-limit',
        ),
      );
      expect(
        const HtmlEntityEncoder(maxInputCharacters: 1)
            .encodeUtf8(<int>[0xef, 0xbb, 0xbf])
            .encoded,
        '\uFEFF',
      );
      expect(
        () =>
            const HtmlEntityEncoder(maxInputCharacters: 0)
                .encodeUtf8(<int>[0xef, 0xbb, 0xbf]),
        _failure(
          kind: HtmlEntityEncodeFailureKind.resource,
          code: 'html-encode.resource-limit',
          field: 'input',
          reason: 'input-limit',
        ),
      );
    });

    // Mutation: truncate output or check pre-escape length rather than full output.
    test('GivenOutputBudget_WhenAtBoundary_ThenOverflowReturnsNoResult', () {
      const encoder = HtmlEntityEncoder(maxOutputCharacters: 5);
      expect(
        encoder.encodeText(const HtmlEntityEncodeRequest(input: '&')).encoded,
        '&amp;',
      );
      expect(
        () => encoder.encodeUtf8(<int>[0x26, 0x78]),
        _failure(
          kind: HtmlEntityEncodeFailureKind.resource,
          code: 'html-encode.resource-limit',
          field: 'encoded',
          reason: 'output-limit',
        ),
      );
      expect(
        () => encoder.encodeText(const HtmlEntityEncodeRequest(input: '&x')),
        _failure(
          kind: HtmlEntityEncodeFailureKind.resource,
          code: 'html-encode.resource-limit',
          field: 'encoded',
          reason: 'output-limit',
        ),
      );
      expect(
        encoder.encodeText(const HtmlEntityEncodeRequest(input: '<')).encoded,
        '&lt;',
      );
    });

    // Mutation: count output Unicode scalars rather than String.length.
    test('GivenSupplementaryOutput_WhenBudgetIsOneUnit_ThenResourceFails', () {
      expect(
        const HtmlEntityEncoder(maxOutputCharacters: 2)
            .encodeText(const HtmlEntityEncodeRequest(input: '😀'))
            .encoded,
        '😀',
      );
      expect(
        () =>
            const HtmlEntityEncoder(maxOutputCharacters: 1)
                .encodeText(const HtmlEntityEncodeRequest(input: '😀')),
        _failure(
          kind: HtmlEntityEncodeFailureKind.resource,
          code: 'html-encode.resource-limit',
          field: 'encoded',
          reason: 'output-limit',
        ),
      );
    });

    // Mutation: treat a zero budget as disabled or reject valid empty input.
    test('GivenZeroBudgets_WhenEmptySourcesEncode_ThenEmptyOutputSucceeds', () {
      const encoder = HtmlEntityEncoder(
        maxInputCharacters: 0,
        maxOutputCharacters: 0,
      );
      expect(
        encoder.encodeText(const HtmlEntityEncodeRequest(input: '')).encoded,
        '',
      );
      expect(encoder.encodeUtf8(<int>[]).encoded, '');
      expect(
        () => encoder.encodeText(const HtmlEntityEncodeRequest(input: 'a')),
        _failure(
          kind: HtmlEntityEncodeFailureKind.resource,
          code: 'html-encode.resource-limit',
          field: 'input',
          reason: 'input-limit',
        ),
      );
      expect(
        () =>
            const HtmlEntityEncoder(maxOutputCharacters: 0)
                .encodeText(const HtmlEntityEncodeRequest(input: 'a')),
        _failure(
          kind: HtmlEntityEncodeFailureKind.resource,
          code: 'html-encode.resource-limit',
          field: 'encoded',
          reason: 'output-limit',
        ),
      );
    });

    // Mutation: perform conversion before checking input budget/Unicode validity.
    test('GivenInvalidInput_WhenEncoded_ThenConversionNeverRuns', () {
      final encoder = HtmlEntityEncoder.forTesting(
        maxInputCharacters: 1,
        convert: (_, _) => throw StateError('conversion should not run'),
      );
      expect(
        () => encoder.encodeText(const HtmlEntityEncodeRequest(input: 'aa')),
        _failure(
          kind: HtmlEntityEncodeFailureKind.resource,
          code: 'html-encode.resource-limit',
          field: 'input',
          reason: 'input-limit',
        ),
      );
      expect(
        () => encoder.encodeText(
          HtmlEntityEncodeRequest(input: String.fromCharCode(0xd800)),
        ),
        _failure(
          kind: HtmlEntityEncodeFailureKind.validation,
          code: 'html-encode.invalid-input',
          field: 'input',
          reason: 'invalid-unicode',
        ),
      );
      expect(
        () => encoder.encodeUtf8(<int>[0xff]),
        _failure(
          kind: HtmlEntityEncodeFailureKind.validation,
          code: 'html-encode.invalid-input',
          field: 'input',
          reason: 'invalid-utf8',
        ),
      );
    });

    // Mutation: leak allocation errors, return partial output, or use wrong field.
    test(
      'GivenConversionOutOfMemory_WhenEitherSourceEncodes_ThenResourceFails',
      () {
        final encoder = HtmlEntityEncoder.forTesting(
          convert: (_, _) => throw OutOfMemoryError(),
        );
        for (final encode in <void Function()>[
          () => encoder.encodeText(
            const HtmlEntityEncodeRequest(input: '<private-source-marker>'),
          ),
          () => encoder.encodeUtf8(<int>[0x26]),
        ]) {
          expect(
            encode,
            _failure(
              kind: HtmlEntityEncodeFailureKind.resource,
              code: 'html-encode.resource-limit',
              field: 'encoded',
              reason: 'allocation-limit',
            ),
          );
        }
      },
    );

    // Mutation: expose source or completed private output on resource failure.
    test('GivenPrivateOutputOverflow_WhenEncoded_ThenDiagnosticsAreRedacted', () {
      try {
        const HtmlEntityEncoder(maxOutputCharacters: 1).encodeText(
          const HtmlEntityEncodeRequest(input: '<private-source-marker>'),
        );
        fail('Expected typed output budget failure');
      } on HtmlEntityEncodeException catch (error) {
        expect(error.reason, 'output-limit');
        final diagnostics =
            '${error.kind} ${error.code} ${error.field} ${error.reason} $error';
        expect(diagnostics, isNot(contains('private-source-marker')));
        expect(diagnostics, isNot(contains('&lt;')));
      }
    });

    // Mutation: allow negative budgets to masquerade as resource failures.
    test('GivenNegativeBudgets_WhenConstructed_ThenAssertionsRejectThem', () {
      expect(
        () => HtmlEntityEncoder(maxInputCharacters: -1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => HtmlEntityEncoder(maxOutputCharacters: -1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => HtmlEntityEncoder.forTesting(maxInputCharacters: -1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => HtmlEntityEncoder.forTesting(maxOutputCharacters: -1),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}

Matcher _failure({
  required HtmlEntityEncodeFailureKind kind,
  required String code,
  required String field,
  required String reason,
}) => throwsA(
  isA<HtmlEntityEncodeException>()
      .having((error) => error.kind, 'kind', kind)
      .having((error) => error.code, 'code', code)
      .having((error) => error.field, 'field', field)
      .having((error) => error.reason, 'reason', reason),
);
