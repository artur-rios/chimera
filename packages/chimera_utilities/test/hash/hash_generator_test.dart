import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

Future<void> main() async {
  final vectors = jsonDecode(
    File.fromUri(
      (await Isolate.resolvePackageUri(
        Uri.parse('package:chimera_utilities/chimera_utilities.dart'),
      ))!.resolve('../../../tests/fixtures/hashes/vectors.json'),
    ).readAsStringSync(),
  ) as List<dynamic>;
  for (final value in vectors.cast<Map<String, dynamic>>()) {
    for (final algorithm in ['sha256', 'sha384', 'sha512', 'md5', 'sha1']) {
      test(
        'Given${value['name']}${algorithm}_WhenGenerated_ThenMatchesIndependentDigest',
        () {
          final result = const HashGenerator().generateBytes(
            (value['bytes'] as List<dynamic>).cast<int>(),
            algorithm: algorithm,
          );
          expect(
            result.digest,
            (value['digests'] as Map<String, dynamic>)[algorithm],
          );
          expect(result.algorithm, algorithm);
          expect(result.legacy, ['md5', 'sha1'].contains(algorithm));
        },
      );
      if (value['name'] == 'empty' || value['name'] == 'abc') {
        test(
          'Given${value['name']}${algorithm}Text_WhenGenerated_ThenMatchesKnownDigest',
          () {
            expect(
              const HashGenerator()
                  .generateText(
                    value['name'] == 'empty' ? '' : 'abc',
                    algorithm: algorithm,
                  )
                  .digest,
              (value['digests'] as Map<String, dynamic>)[algorithm],
            );
          },
        );
      }
    }
  }
  final published = jsonDecode(
    File.fromUri(
      (await Isolate.resolvePackageUri(
        Uri.parse('package:chimera_utilities/chimera_utilities.dart'),
      ))!.resolve(
        '../../../tests/fixtures/hashes/published_binary_vectors.json',
      ),
    ).readAsStringSync(),
  ) as List<dynamic>;
  for (final vector in published.cast<Map<String, dynamic>>()) {
    test(
      'GivenPublished${vector['algorithm']}Binary_WhenGenerated_ThenMatchesExternalKnownAnswer',
      () {
        final hex = vector['hex'] as String;
        final bytes = [
          for (var index = 0; index < hex.length; index += 2)
            int.parse(hex.substring(index, index + 2), radix: 16),
        ];
        expect(
          const HashGenerator()
              .generateBytes(bytes, algorithm: vector['algorithm'] as String)
              .digest,
          vector['digest'],
        );
      },
    );
  }
  for (final algorithm in ['', 'SHA256', 'sha-256', 'sha224', 'secret']) {
    test(
      'GivenUnsupported${algorithm}Algorithm_WhenGenerated_ThenSafeValidationFailure',
      () {
        expect(
          () => const HashGenerator().generateBytes([], algorithm: algorithm),
          throwsA(
            isA<HashGenerateException>()
                .having(
                  (e) => e.code,
                  'code',
                  'hash-generate.invalid-algorithm',
                )
                .having((e) => e.field, 'field', 'algorithm'),
          ),
        );
      },
    );
  }
  for (final bytes in [
    [-1],
    [256],
  ]) {
    test(
      'GivenInvalid${bytes.first}Byte_WhenGenerated_ThenValidationFailure',
      () {
        expect(
          () => const HashGenerator().generateBytes(bytes),
          throwsA(
            isA<HashGenerateException>().having(
              (e) => e.kind,
              'kind',
              HashGenerateFailureKind.validation,
            ),
          ),
        );
      },
    );
  }
  for (final input in ['\ud800', '\udc00', 'x\ud800x']) {
    test(
      'GivenMalformed${input.codeUnits}Text_WhenGenerated_ThenValidationFailure',
      () {
        expect(
          () => const HashGenerator().generateText(input),
          throwsA(
            isA<HashGenerateException>().having(
              (e) => e.reason,
              'reason',
              'invalid-unicode',
            ),
          ),
        );
      },
    );
  }
  test('GivenUnicodeAndBom_WhenGenerated_ThenExactUtf8IsUsed', () {
    const generator = HashGenerator();
    expect(
      generator.generateText('\ufeffOlá 🌍\n').digest,
      generator.generateBytes(utf8.encode('\ufeffOlá 🌍\n')).digest,
    );
    expect(
      generator.generateText('abc').digest,
      isNot(generator.generateText('abc\n').digest),
    );
  });
  test(
    'GivenHashAllocationFailure_WhenGenerated_ThenResourceFailureWithoutSource',
    () {
      final generator = HashGenerator.forTesting(
        hash: (_, _) => throw OutOfMemoryError(),
      );
      expect(
        () => generator.generateText('secret'),
        throwsA(
          isA<HashGenerateException>()
              .having((e) => e.kind, 'kind', HashGenerateFailureKind.resource)
              .having((e) => e.reason, 'reason', 'allocation-limit'),
        ),
      );
    },
  );
  test('GivenUtf8AllocationFailure_WhenGenerated_ThenResourceFailure', () {
    final generator = HashGenerator.forTesting(
      encodeUtf8: (_) => throw OutOfMemoryError(),
    );
    expect(
      () => generator.generateText('secret'),
      throwsA(
        isA<HashGenerateException>().having(
          (e) => e.kind,
          'kind',
          HashGenerateFailureKind.resource,
        ),
      ),
    );
  });
}
