import 'dart:collection';
import 'dart:convert';

import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  for (final fixture in <(String, String)>[
    ('', ''),
    ('abc+def', 'abc+def'),
    ('%2b%2B%20', '++ '),
    ('%21%2F%3F%23%5B%5D%40%3A%24%26%3D', '!/?#[]@:\$&='),
    ('%C3%A9%F0%9F%98%80', 'é😀'),
    ('Olá 日本語 e\u0301', 'Olá 日本語 e\u0301'),
    ('%2520', '%20'),
    ('\uFEFF%EF%BB%BF', '\uFEFF\uFEFF'),
    ('%00%0D%0A', '\u0000\r\n'),
    (
      '%7f%C2%80%DF%BF%E0%A0%80%F4%8F%BF%BF',
      '\u007f\u0080\u07ff\u0800\u{10ffff}',
    ),
    ('é%C3%A9😀%F0%9F%98%80', 'éé😀😀'),
  ]) {
    for (final bytes in [false, true]) {
      test(
        'GivenValid${fixture.$1.codeUnits}${bytes}_WhenDecoded_ThenExactTextReturns',
        () {
          const decoder = UrlDecoder();
          final output = bytes
              ? decoder.decodeUtf8(utf8.encode(fixture.$1))
              : decoder.decodeText(UrlDecodeRequest(input: fixture.$1));
          expect(output.decoded, fixture.$2);
        },
      );
    }
  }
  for (final input in ['%', '%0', '%GG', '%aZ', 'abc%1x']) {
    test(
      'GivenMalformed${input}_WhenDecoded_ThenTypedPercentFailureReturns',
      () {
        expect(
          () => const UrlDecoder().decodeText(UrlDecodeRequest(input: input)),
          throwsA(
            isA<UrlDecodeException>()
                .having((e) => e.reason, 'reason', 'malformed-percent')
                .having((e) => e.offset, 'offset', input.indexOf('%')),
          ),
        );
      },
    );
  }
  for (final input in [
    '%80',
    '%C0%AF',
    '%C1%BF',
    '%C2',
    '%C3%28',
    '%E0%80%80',
    '%ED%A0%80',
    '%F0%80%80%80',
    '%F4%90%80%80',
    '%F5%80%80%80',
    '%FF',
    '%E2%82',
    '%C3é',
  ]) {
    test(
      'GivenMalformedUtf8${input}_WhenDecoded_ThenTypedTextFailureReturns',
      () {
        expect(
          () => const UrlDecoder().decodeText(
            UrlDecodeRequest(input: 'ok$input'),
          ),
          throwsA(
            isA<UrlDecodeException>()
                .having((e) => e.reason, 'reason', 'invalid-percent-utf8')
                .having((e) => e.offset, 'offset', 2),
          ),
        );
      },
    );
  }
  for (final input in [
    String.fromCharCode(0xd800),
    String.fromCharCode(0xdc00),
    'a${String.fromCharCode(0xd800)}b',
  ]) {
    test(
      'GivenSurrogate${input.codeUnits}_WhenDecoded_ThenTypedFailureReturns',
      () {
        expect(
          () => const UrlDecoder().decodeText(UrlDecodeRequest(input: input)),
          throwsA(
            isA<UrlDecodeException>().having(
              (e) => e.reason,
              'reason',
              'surrogate-scalar',
            ),
          ),
        );
      },
    );
  }
  for (final input in <List<int>>[
    [256],
    [-1],
    [0xc3, 0x28],
    [0xed, 0xa0, 0x80],
    [0xf4, 0x90, 0x80, 0x80],
  ]) {
    test(
      'GivenInvalidBytes${input}_WhenDecoded_ThenTypedUtf8FailureReturns',
      () {
        expect(
          () => const UrlDecoder().decodeUtf8(input),
          throwsA(
            isA<UrlDecodeException>().having(
              (e) => e.reason,
              'reason',
              'invalid-utf8',
            ),
          ),
        );
      },
    );
  }
  for (final fixture in <(UrlDecoder, String, String)>[
    (const UrlDecoder(maxInputCharacters: 2), 'input', 'input-limit'),
    (const UrlDecoder(maxOutputCharacters: 2), 'decoded', 'output-limit'),
    (
      UrlDecoder.forTesting(convert: (_) => throw OutOfMemoryError()),
      'decoded',
      'allocation-limit',
    ),
  ]) {
    test('Given${fixture.$3}_WhenDecoded_ThenSafeResourceFailureReturns', () {
      expect(
        () => fixture.$1.decodeText(const UrlDecodeRequest(input: 'private')),
        throwsA(
          isA<UrlDecodeException>()
              .having((e) => e.kind, 'kind', UrlDecodeFailureKind.resource)
              .having((e) => e.field, 'field', fixture.$2)
              .having((e) => e.reason, 'reason', fixture.$3),
        ),
      );
    });
  }
  test('GivenAllocationFailureBytes_WhenDecoded_ThenTypedInputResourceFailureReturns', () {
    expect(
      () => const UrlDecoder().decodeUtf8(_FailingBytes()),
      throwsA(
        isA<UrlDecodeException>()
            .having((e) => e.field, 'field', 'input')
            .having((e) => e.reason, 'reason', 'allocation-limit'),
      ),
    );
  });
  test('GivenExactBudgets_WhenDecoded_ThenBoundariesAreInclusive', () {
    expect(
      const UrlDecoder(
        maxInputCharacters: 3,
        maxOutputCharacters: 1,
      ).decodeText(const UrlDecodeRequest(input: '%41')).decoded,
      'A',
    );
    expect(
      const UrlDecoder(
        maxInputCharacters: 0,
        maxOutputCharacters: 0,
      ).decodeText(const UrlDecodeRequest(input: '')).decoded,
      '',
    );
  });
}

final class _FailingBytes extends ListBase<int> {
  @override
  int get length => 1;
  @override
  set length(int value) => throw UnsupportedError('immutable');
  @override
  int operator [](int index) => throw OutOfMemoryError();
  @override
  void operator []=(int index, int value) =>
      throw UnsupportedError('immutable');
}
