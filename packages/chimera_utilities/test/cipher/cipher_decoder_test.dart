import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  const decoder = CipherDecoder();

  group('CipherDecoder known answers', () {
    final cases = <({CipherDecodeRequest request, String decoded})>[
      (
        request: const CipherDecodeRequest(
          input: 'Khoor, Zruog! 123',
          algorithm: CipherAlgorithm.caesar,
          shift: 3,
        ),
        decoded: 'Hello, World! 123',
      ),
      (
        request: const CipherDecodeRequest(
          input: 'Uryyb, Jbeyq!',
          algorithm: CipherAlgorithm.rot13,
        ),
        decoded: 'Hello, World!',
      ),
      (
        request: const CipherDecodeRequest(
          input: 'LXFOPVEFRNHR',
          algorithm: CipherAlgorithm.vigenere,
          key: 'LEMON',
        ),
        decoded: 'ATTACKATDAWN',
      ),
      (
        request: const CipherDecodeRequest(
          input: 'Zyx Cba!',
          algorithm: CipherAlgorithm.atbash,
        ),
        decoded: 'Abc Xyz!',
      ),
      (
        request: const CipherDecodeRequest(
          input: 'IHHWVCSWFRCP',
          algorithm: CipherAlgorithm.affine,
          affineA: 5,
          affineB: 8,
        ),
        decoded: 'AFFINECIPHER',
      ),
      (
        request: const CipherDecodeRequest(
          input: 'AAAAAaaaabbbaab!',
          algorithm: CipherAlgorithm.bacon,
        ),
        decoded: 'Abz!',
      ),
      (
        request: const CipherDecodeRequest(
          input: 'WECRLTEERDSOEEFEAOCAIVDEN',
          algorithm: CipherAlgorithm.railFence,
          rails: 3,
        ),
        decoded: 'WEAREDISCOVEREDFLEEATONCE',
      ),
      (
        request: const CipherDecodeRequest(
          input: 'WE ERA!',
          algorithm: CipherAlgorithm.railFence,
          rails: 3,
        ),
        decoded: 'WE ARE!',
      ),
    ];

    for (final fixture in cases) {
      test(
        'Given${fixture.request.algorithm.name}_WhenDecoded_ThenKnownAnswer',
        () {
          final result = decoder.decode(fixture.request);

          expect(result.decoded, fixture.decoded);
          expect(result.algorithm, fixture.request.algorithm);
          expect(result.characterPolicy, fixture.request.characterPolicy);
        },
      );
    }
  });

  test('GivenEveryCipher_WhenEncodedThenDecoded_ThenOriginalReturns', () {
    const encoder = CipherEncoder();
    final requests = <CipherEncodeRequest>[
      const CipherEncodeRequest(
        input: 'Attack at dawn!',
        algorithm: CipherAlgorithm.caesar,
        shift: 25,
      ),
      const CipherEncodeRequest(
        input: 'Attack at dawn!',
        algorithm: CipherAlgorithm.rot13,
      ),
      const CipherEncodeRequest(
        input: 'Attack at dawn!',
        algorithm: CipherAlgorithm.vigenere,
        key: 'LeMoN',
      ),
      const CipherEncodeRequest(
        input: 'Attack at dawn!',
        algorithm: CipherAlgorithm.atbash,
      ),
      const CipherEncodeRequest(
        input: 'Attack at dawn!',
        algorithm: CipherAlgorithm.affine,
        affineA: 25,
        affineB: 25,
      ),
      const CipherEncodeRequest(
        input: 'Attack at dawn!',
        algorithm: CipherAlgorithm.bacon,
      ),
      const CipherEncodeRequest(
        input: 'Attack at dawn!',
        algorithm: CipherAlgorithm.railFence,
        rails: 4,
      ),
    ];

    for (final request in requests) {
      final encoded = encoder.encode(request).encoded;
      final decoded = decoder.decode(
        CipherDecodeRequest(
          input: encoded,
          algorithm: request.algorithm,
          characterPolicy: request.characterPolicy,
          shift: request.shift,
          key: request.key,
          affineA: request.affineA,
          affineB: request.affineB,
          rails: request.rails,
        ),
      );

      expect(decoded.decoded, request.input, reason: request.algorithm.name);
    }
  });

  test('GivenEmptyText_WhenDecoded_ThenEmptyResult', () {
    final result = decoder.decode(
      const CipherDecodeRequest(input: '', algorithm: CipherAlgorithm.atbash),
    );

    expect(result.decoded, isEmpty);
  });

  test('GivenUnicode_WhenPreserved_ThenEveryScalarRemainsExact', () {
    final result = decoder.decode(
      const CipherDecodeRequest(
        input: 'B🌍é\r\nA',
        algorithm: CipherAlgorithm.caesar,
        shift: 1,
      ),
    );

    expect(result.decoded, 'A🌍é\r\nZ');
  });

  test('GivenUnsupportedScalar_WhenRejected_ThenScalarIndexIsReported', () {
    expect(
      () => decoder.decode(
        const CipherDecodeRequest(
          input: 'Z🌍Y',
          algorithm: CipherAlgorithm.atbash,
          characterPolicy: CipherCharacterPolicy.reject,
        ),
      ),
      throwsA(
        isA<CipherException>()
            .having((error) => error.code, 'code', 'cipher.unsupported-symbol')
            .having((error) => error.field, 'field', 'input')
            .having((error) => error.position, 'position', 1),
      ),
    );
  });

  test('GivenMalformedUnicode_WhenDecoded_ThenTypedValidationFailure', () {
    expect(
      () => decoder.decode(
        const CipherDecodeRequest(
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

  group('CipherDecoder validation', () {
    final cases =
        <({CipherDecodeRequest request, String field, String reason})>[
          (
            request: const CipherDecodeRequest(
              input: 'text',
              algorithm: CipherAlgorithm.caesar,
            ),
            field: 'shift',
            reason: 'required',
          ),
          (
            request: const CipherDecodeRequest(
              input: 'text',
              algorithm: CipherAlgorithm.caesar,
              shift: -1,
            ),
            field: 'shift',
            reason: 'out-of-range',
          ),
          (
            request: const CipherDecodeRequest(
              input: 'text',
              algorithm: CipherAlgorithm.rot13,
              shift: 13,
            ),
            field: 'shift',
            reason: 'unexpected',
          ),
          (
            request: const CipherDecodeRequest(
              input: 'text',
              algorithm: CipherAlgorithm.vigenere,
              key: '',
            ),
            field: 'key',
            reason: 'required',
          ),
          (
            request: const CipherDecodeRequest(
              input: 'text',
              algorithm: CipherAlgorithm.vigenere,
              key: 'K3Y',
            ),
            field: 'key',
            reason: 'ascii-letters-only',
          ),
          (
            request: const CipherDecodeRequest(
              input: 'text',
              algorithm: CipherAlgorithm.atbash,
              key: 'secret',
            ),
            field: 'key',
            reason: 'unexpected',
          ),
          (
            request: const CipherDecodeRequest(
              input: 'text',
              algorithm: CipherAlgorithm.affine,
              affineA: 2,
              affineB: 8,
            ),
            field: 'a',
            reason: 'not-coprime',
          ),
          (
            request: const CipherDecodeRequest(
              input: 'text',
              algorithm: CipherAlgorithm.affine,
              affineA: 5,
            ),
            field: 'b',
            reason: 'required',
          ),
          (
            request: const CipherDecodeRequest(
              input: 'text',
              algorithm: CipherAlgorithm.bacon,
              rails: 3,
            ),
            field: 'rails',
            reason: 'unexpected',
          ),
          (
            request: const CipherDecodeRequest(
              input: 'text',
              algorithm: CipherAlgorithm.railFence,
              rails: 1,
            ),
            field: 'rails',
            reason: 'out-of-range',
          ),
        ];

    for (final fixture in cases) {
      test('GivenInvalid${fixture.field}_WhenDecoded_ThenTypedFailure', () {
        expect(
          () => decoder.decode(fixture.request),
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

  for (final fixture in <({String input, int position})>[
    (input: 'AAAA', position: 0),
    (input: 'AAaAA', position: 2),
    (input: 'BBBBB', position: 0),
    (input: 'AA!AAA', position: 2),
    (input: 'AAAAC', position: 4),
  ]) {
    test('Given${fixture.input}_WhenBaconDecoded_ThenAmbiguityIsTyped', () {
      expect(
        () => decoder.decode(
          CipherDecodeRequest(
            input: fixture.input,
            algorithm: CipherAlgorithm.bacon,
          ),
        ),
        throwsA(
          isA<CipherException>()
              .having((error) => error.code, 'code', 'cipher.invalid-input')
              .having(
                (error) => error.reason,
                'reason',
                'ambiguous-bacon-input',
              )
              .having((error) => error.position, 'position', fixture.position),
        ),
      );
    });
  }

  test('GivenSymbolsBetweenBaconGroups_WhenPreserved_ThenPositionReturns', () {
    final result = decoder.decode(
      const CipherDecodeRequest(
        input: 'AAAAA!aaaab',
        algorithm: CipherAlgorithm.bacon,
      ),
    );

    expect(result.decoded, 'A!b');
  });

  test('GivenMixedCaseAndPunctuation_WhenVigenereRuns_ThenKeySkipsSymbols', () {
    final result = decoder.decode(
      const CipherDecodeRequest(
        input: 'Lxfopv ef rnhr!',
        algorithm: CipherAlgorithm.vigenere,
        key: 'LeMoN',
      ),
    );

    expect(result.decoded, 'Attack at dawn!');
  });

  test(
    'GivenRailsAtLeastLetterCount_WhenDecoded_ThenNoOpWithoutAllocation',
    () {
      final result = decoder.decode(
        const CipherDecodeRequest(
          input: 'Z🌍y',
          algorithm: CipherAlgorithm.railFence,
          rails: 1000000000,
        ),
      );

      expect(result.decoded, 'Z🌍y');
    },
  );

  test('GivenOutputBudgetExceeded_WhenDecoded_ThenResourceFailure', () {
    const bounded = CipherDecoder(maxOutputCharacters: 0);

    expect(
      () => bounded.decode(
        const CipherDecodeRequest(
          input: 'Z',
          algorithm: CipherAlgorithm.atbash,
        ),
      ),
      throwsA(
        isA<CipherException>()
            .having((error) => error.kind, 'kind', CipherFailureKind.resource)
            .having((error) => error.code, 'code', 'cipher.resource-limit'),
      ),
    );
  });
}
