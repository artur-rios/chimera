import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  const encoder = CipherEncoder();

  group('CipherEncoder known answers', () {
    final cases = <({CipherEncodeRequest request, String encoded})>[
      (
        request: const CipherEncodeRequest(
          input: 'Hello, World! 123',
          algorithm: CipherAlgorithm.caesar,
          shift: 3,
        ),
        encoded: 'Khoor, Zruog! 123',
      ),
      (
        request: const CipherEncodeRequest(
          input: 'Hello, World!',
          algorithm: CipherAlgorithm.rot13,
        ),
        encoded: 'Uryyb, Jbeyq!',
      ),
      (
        request: const CipherEncodeRequest(
          input: 'ATTACKATDAWN',
          algorithm: CipherAlgorithm.vigenere,
          key: 'LEMON',
        ),
        encoded: 'LXFOPVEFRNHR',
      ),
      (
        request: const CipherEncodeRequest(
          input: 'Abc Xyz!',
          algorithm: CipherAlgorithm.atbash,
        ),
        encoded: 'Zyx Cba!',
      ),
      (
        request: const CipherEncodeRequest(
          input: 'AFFINECIPHER',
          algorithm: CipherAlgorithm.affine,
          affineA: 5,
          affineB: 8,
        ),
        encoded: 'IHHWVCSWFRCP',
      ),
      (
        request: const CipherEncodeRequest(
          input: 'Abz!',
          algorithm: CipherAlgorithm.bacon,
        ),
        encoded: 'AAAAAaaaabbbaab!',
      ),
      (
        request: const CipherEncodeRequest(
          input: 'WEAREDISCOVEREDFLEEATONCE',
          algorithm: CipherAlgorithm.railFence,
          rails: 3,
        ),
        encoded: 'WECRLTEERDSOEEFEAOCAIVDEN',
      ),
      (
        request: const CipherEncodeRequest(
          input: 'WE ARE!',
          algorithm: CipherAlgorithm.railFence,
          rails: 3,
        ),
        encoded: 'WE ERA!',
      ),
    ];

    for (final fixture in cases) {
      test(
        'Given${fixture.request.algorithm.name}_WhenEncoded_ThenKnownAnswer',
        () {
          final result = encoder.encode(fixture.request);

          expect(result.encoded, fixture.encoded);
          expect(result.algorithm, fixture.request.algorithm);
          expect(result.characterPolicy, fixture.request.characterPolicy);
        },
      );
    }
  });

  test('GivenEmptyText_WhenEncoded_ThenEmptyResult', () {
    final result = encoder.encode(
      const CipherEncodeRequest(input: '', algorithm: CipherAlgorithm.atbash),
    );

    expect(result.encoded, isEmpty);
  });

  test('GivenUnicode_WhenPreserved_ThenEveryScalarRemainsExact', () {
    final result = encoder.encode(
      const CipherEncodeRequest(
        input: 'A😀é\r\nZ',
        algorithm: CipherAlgorithm.caesar,
        shift: 1,
      ),
    );

    expect(result.encoded, 'B😀é\r\nA');
  });

  test('GivenUnsupportedScalar_WhenRejected_ThenScalarIndexIsReported', () {
    expect(
      () => encoder.encode(
        const CipherEncodeRequest(
          input: 'A😀B',
          algorithm: CipherAlgorithm.atbash,
          characterPolicy: CipherCharacterPolicy.reject,
        ),
      ),
      throwsA(
        isA<CipherException>()
            .having((error) => error.code, 'code', 'cipher.unsupported-symbol')
            .having((error) => error.field, 'field', 'input')
            .having((error) => error.reason, 'reason', 'unsupported-symbol')
            .having((error) => error.position, 'position', 1),
      ),
    );
  });

  test('GivenMalformedUnicode_WhenEncoded_ThenTypedValidationFailure', () {
    expect(
      () => encoder.encode(
        const CipherEncodeRequest(
          input: '\uD800',
          algorithm: CipherAlgorithm.atbash,
        ),
      ),
      throwsA(
        isA<CipherException>()
            .having((error) => error.code, 'code', 'cipher.invalid-input')
            .having((error) => error.reason, 'reason', 'invalid-unicode'),
      ),
    );
  });

  group('CipherEncoder validation', () {
    final cases =
        <({CipherEncodeRequest request, String field, String reason})>[
          (
            request: const CipherEncodeRequest(
              input: 'text',
              algorithm: CipherAlgorithm.caesar,
            ),
            field: 'shift',
            reason: 'required',
          ),
          (
            request: const CipherEncodeRequest(
              input: 'text',
              algorithm: CipherAlgorithm.caesar,
              shift: 26,
            ),
            field: 'shift',
            reason: 'out-of-range',
          ),
          (
            request: const CipherEncodeRequest(
              input: 'text',
              algorithm: CipherAlgorithm.rot13,
              shift: 13,
            ),
            field: 'shift',
            reason: 'unexpected',
          ),
          (
            request: const CipherEncodeRequest(
              input: 'text',
              algorithm: CipherAlgorithm.vigenere,
              key: '',
            ),
            field: 'key',
            reason: 'required',
          ),
          (
            request: const CipherEncodeRequest(
              input: 'text',
              algorithm: CipherAlgorithm.vigenere,
              key: 'KEY-1',
            ),
            field: 'key',
            reason: 'ascii-letters-only',
          ),
          (
            request: const CipherEncodeRequest(
              input: 'text',
              algorithm: CipherAlgorithm.atbash,
              key: 'secret',
            ),
            field: 'key',
            reason: 'unexpected',
          ),
          (
            request: const CipherEncodeRequest(
              input: 'text',
              algorithm: CipherAlgorithm.affine,
              affineA: 2,
              affineB: 8,
            ),
            field: 'a',
            reason: 'not-coprime',
          ),
          (
            request: const CipherEncodeRequest(
              input: 'text',
              algorithm: CipherAlgorithm.affine,
              affineA: 5,
            ),
            field: 'b',
            reason: 'required',
          ),
          (
            request: const CipherEncodeRequest(
              input: 'text',
              algorithm: CipherAlgorithm.affine,
              affineA: 5,
              affineB: -1,
            ),
            field: 'b',
            reason: 'out-of-range',
          ),
          (
            request: const CipherEncodeRequest(
              input: 'text',
              algorithm: CipherAlgorithm.bacon,
              rails: 3,
            ),
            field: 'rails',
            reason: 'unexpected',
          ),
          (
            request: const CipherEncodeRequest(
              input: 'text',
              algorithm: CipherAlgorithm.railFence,
              rails: 1,
            ),
            field: 'rails',
            reason: 'out-of-range',
          ),
        ];

    for (final fixture in cases) {
      test('GivenInvalid${fixture.field}_WhenEncoded_ThenTypedFailure', () {
        expect(
          () => encoder.encode(fixture.request),
          throwsA(
            isA<CipherException>()
                .having(
                  (error) => error.kind,
                  'kind',
                  CipherFailureKind.validation,
                )
                .having((error) => error.field, 'field', fixture.field)
                .having((error) => error.reason, 'reason', fixture.reason),
          ),
        );
      });
    }
  });

  test('GivenMixedCaseAndPunctuation_WhenVigenereRuns_ThenKeySkipsSymbols', () {
    final result = encoder.encode(
      const CipherEncodeRequest(
        input: 'Attack at dawn!',
        algorithm: CipherAlgorithm.vigenere,
        key: 'LeMoN',
      ),
    );

    expect(result.encoded, 'Lxfopv ef rnhr!');
  });

  test(
    'GivenRailsAtLeastLetterCount_WhenEncoded_ThenNoOpWithoutAllocation',
    () {
      final result = encoder.encode(
        const CipherEncodeRequest(
          input: 'A😀b',
          algorithm: CipherAlgorithm.railFence,
          rails: 1000000000,
        ),
      );

      expect(result.encoded, 'A😀b');
    },
  );

  test('GivenOutputBudgetExceeded_WhenEncoded_ThenResourceFailure', () {
    const bounded = CipherEncoder(maxOutputCharacters: 4);

    expect(
      () => bounded.encode(
        const CipherEncodeRequest(input: 'A', algorithm: CipherAlgorithm.bacon),
      ),
      throwsA(
        isA<CipherException>()
            .having((error) => error.kind, 'kind', CipherFailureKind.resource)
            .having((error) => error.code, 'code', 'cipher.resource-limit'),
      ),
    );
  });
}
