import 'dart:convert';

import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  const encoder = UrlEncoder();
  const answers = <String, (String, String)>{
    'empty': ('', ''),
    'unicode': (
      'ação 東京 😀 e\u0301',
      'a%C3%A7%C3%A3o%20%E6%9D%B1%E4%BA%AC%20%F0%9F%98%80%20e%CC%81',
    ),
    'controls': ('\uFEFF\u0000\r\n\t ', '%EF%BB%BF%00%0D%0A%09%20'),
    'alreadyEncoded': ('%2F%20', '%252F%2520'),
    'unreserved': ("AZaz09-_.!~*'()", "AZaz09-_.!~*'()"),
  };
  // Replacing UTF-8 encoding with code-unit escaping, trimming, normalization,
  // query encoding (+), or trusting existing escapes breaks these fixtures.
  for (final entry in answers.entries) {
    for (final mode in ['full', 'component']) {
      test(
        'Given${entry.key}${mode}_WhenEncoded_ThenExactPercentTextReturns',
        () {
          final text = encoder.encodeText(
            UrlEncodeRequest(input: entry.value.$1, mode: mode),
          );
          final bytes = encoder.encodeUtf8(
            utf8.encode(entry.value.$1),
            mode: mode,
          );
          expect(text.encoded, entry.value.$2);
          expect(bytes.encoded, entry.value.$2);
          expect(text.mode, mode);
          expect(bytes.mode, mode);
        },
      );
    }
  }
  test(
    'GivenReservedDelimiters_WhenModesChange_ThenOnlyFullPreservesStructure',
    () {
      const source = 'https://example.test/a b?q=ação&v=1#x';
      expect(
        encoder.encodeText(const UrlEncodeRequest(input: source)).encoded,
        'https%3A%2F%2Fexample.test%2Fa%20b%3Fq%3Da%C3%A7%C3%A3o%26v%3D1%23x',
      );
      final full = encoder.encodeText(
        const UrlEncodeRequest(input: source, mode: 'full'),
      );
      expect(full.encoded, 'https://example.test/a%20b?q=a%C3%A7%C3%A3o&v=1#x');
      expect(full.mode, 'full');
      expect(
        encoder
            .encodeText(
              const UrlEncodeRequest(
                input: ':/?#[]@!\$&\'()*+,;=',
                mode: 'full',
              ),
            )
            .encoded,
        ':/?#%5B%5D@!\$&\'()*+,;=',
      );
      expect(
        encoder
            .encodeText(const UrlEncodeRequest(input: ':/?#[]@!\$&\'()*+,;='))
            .encoded,
        '%3A%2F%3F%23%5B%5D%40!%24%26\'()*%2B%2C%3B%3D',
      );
    },
  );
  test('GivenRepeatedBom_WhenUtf8Encodes_ThenBothBomScalarsArePreserved', () {
    expect(
      encoder.encodeUtf8([239, 187, 191, 239, 187, 191]).encoded,
      '%EF%BB%BF%EF%BB%BF',
    );
  });
  for (final mode in [
    '',
    'FULL',
    'Component',
    ' full',
    'component ',
    'query',
    'secret-mode',
  ]) {
    test(
      'GivenInvalidMode${mode}_WhenEncoded_ThenSafeValidationPrecedesInput',
      () {
        for (final action in <void Function()>[
          () => encoder.encodeText(
            UrlEncodeRequest(input: String.fromCharCode(0xd800), mode: mode),
          ),
          () => encoder.encodeUtf8([255], mode: mode),
        ]) {
          expect(
            action,
            failure('validation', 'invalid-mode', 'mode', 'unsupported-mode'),
          );
        }
      },
    );
  }
  for (final units in [
    [0xd800],
    [0xdbff],
    [0xdc00],
    [0xdfff],
    [0xd800, 97],
    [0xdc00, 0xd800],
    [0xd800, 0xdc00, 0xdc00],
  ]) {
    test(
      'GivenMalformedUnicode${units}_WhenEncoded_ThenNoReplacementOutputReturns',
      () {
        expect(
          () => encoder.encodeText(
            UrlEncodeRequest(input: 'secret${String.fromCharCodes(units)}'),
          ),
          failure('validation', 'invalid-input', 'input', 'invalid-unicode'),
        );
      },
    );
  }
  for (final bytes in [
    [0xc3, 0x28],
    [0xc0, 0xaf],
    [0xf0, 0x9f, 0x98],
    [0x80],
    [255],
    [0xed, 0xa0, 0x80],
    [0xf4, 0x90, 0x80, 0x80],
    [0xef, 0xbb],
    [-1],
    [256],
  ]) {
    test(
      'GivenMalformedUtf8${bytes}_WhenEncoded_ThenNoReplacementOutputReturns',
      () {
        expect(
          () => encoder.encodeUtf8(bytes),
          failure('validation', 'invalid-input', 'input', 'invalid-utf8'),
        );
      },
    );
  }
  test('GivenBudgets_WhenBoundaryAndOverflowEncode_ThenOnlyOverflowFails', () {
    const encoder = UrlEncoder(maxInputCharacters: 2, maxOutputCharacters: 12);
    expect(
      encoder.encodeText(const UrlEncodeRequest(input: '😀')).encoded,
      '%F0%9F%98%80',
    );
    expect(
      () => encoder.encodeText(const UrlEncodeRequest(input: '😀x')),
      failure('resource', 'resource-limit', 'input', 'input-limit'),
    );
    expect(
      () =>
          const UrlEncoder(maxOutputCharacters: 11)
              .encodeUtf8(utf8.encode('😀')),
      failure('resource', 'resource-limit', 'encoded', 'output-limit'),
    );
    expect(
      const UrlEncoder(
        maxInputCharacters: 0,
        maxOutputCharacters: 0,
      ).encodeUtf8([]).encoded,
      '',
    );
  });
  test(
    'GivenAllocationFailure_WhenConverting_ThenSafeResourceFailureReturns',
    () {
      final encoder = UrlEncoder.forTesting(
        convert: (_, _) => throw OutOfMemoryError(),
      );
      expect(
        () => encoder.encodeText(const UrlEncodeRequest(input: 'secret')),
        failure('resource', 'resource-limit', 'encoded', 'allocation-limit'),
      );
    },
  );
  test('GivenInvalidInput_WhenEncoding_ThenConversionNeverRuns', () {
    final encoder = UrlEncoder.forTesting(
      maxInputCharacters: 1,
      convert: (_, _) => throw StateError('should not run'),
    );
    expect(
      () => encoder.encodeText(const UrlEncodeRequest(input: 'xx')),
      failure('resource', 'resource-limit', 'input', 'input-limit'),
    );
    expect(
      () => encoder.encodeText(
        UrlEncodeRequest(input: String.fromCharCode(0xd800)),
      ),
      failure('validation', 'invalid-input', 'input', 'invalid-unicode'),
    );
  });
}

Matcher failure(String kind, String code, String field, String reason) =>
    throwsA(
      isA<UrlEncodeException>()
          .having((e) => e.kind.name, 'kind', kind)
          .having((e) => e.code, 'code', 'url-encode.$code')
          .having((e) => e.field, 'field', field)
          .having((e) => e.reason, 'reason', reason)
          .having(
            (e) => e.toString(),
            'safe diagnostics',
            isNot(contains('secret')),
          ),
    );
