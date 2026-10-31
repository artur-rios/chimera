import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  late List<dynamic> vectors;
  setUpAll(() async {
    final library = (await Isolate.resolvePackageUri(
      Uri.parse('package:chimera_utilities/chimera_utilities.dart'),
    ))!;
    vectors = jsonDecode(
      File.fromUri(
        library.resolve('../../../tests/fixtures/checksums/vectors.json'),
      ).readAsStringSync(),
    ) as List<dynamic>;
  });
  for (final algorithm in ['crc32', 'adler32']) {
    test(
      'GivenPublished${algorithm}Vectors_WhenGenerated_ThenExactEightLowerHex',
      () {
        for (final raw in vectors) {
          final vector = raw as Map<String, dynamic>;
          final expected =
              (vector['checksums'] as Map<String, dynamic>)[algorithm];
          final result = const ChecksumGenerator().generateBytes(
            (vector['bytes'] as List<dynamic>).cast<int>(),
            algorithm: algorithm,
          );
          expect(result.checksum, expected, reason: vector['name'] as String);
          expect(result.algorithm, algorithm);
          if (vector['text'] case final String text) {
            expect(
              const ChecksumGenerator()
                  .generateText(text, algorithm: algorithm)
                  .checksum,
              expected,
            );
          }
        }
      },
    );
  }
  for (final byte in [-1, 256, 65536]) {
    test('GivenNonByte${byte}_WhenGenerated_ThenSafeValidation', () {
      expect(
        () => const ChecksumGenerator().generateBytes([byte]),
        throwsA(
          isA<ChecksumGenerateException>()
              .having(
                (e) => e.kind,
                'kind',
                ChecksumGenerateFailureKind.validation,
              )
              .having((e) => e.reason, 'reason', 'byte-range'),
        ),
      );
    });
  }
  test('GivenUnknownAlgorithm_WhenGenerated_ThenSafeValidation', () {
    expect(
      () => const ChecksumGenerator().generateText(
        'PRIVATE',
        algorithm: 'PRIVATE',
      ),
      throwsA(
        isA<ChecksumGenerateException>()
            .having((e) => e.field, 'field', 'algorithm')
            .having((e) => e.reason, 'reason', 'unsupported-algorithm'),
      ),
    );
  });
  for (final text in [
    String.fromCharCode(0xd800),
    String.fromCharCode(0xdc00),
    '${String.fromCharCode(0xd800)}a',
  ]) {
    test(
      'GivenMalformedUnicode${text.codeUnits}_WhenGenerated_ThenValidation',
      () {
        expect(
          () => const ChecksumGenerator().generateText(text),
          throwsA(
            isA<ChecksumGenerateException>().having(
              (e) => e.reason,
              'reason',
              'invalid-unicode',
            ),
          ),
        );
      },
    );
  }
  test('GivenUnicodeWhitespaceAndNewlines_WhenTextGenerated_ThenExactUtf8', () {
    const text = ' Olá 😀\r\n';
    for (final algorithm in ['crc32', 'adler32']) {
      expect(
        const ChecksumGenerator()
            .generateText(text, algorithm: algorithm)
            .checksum,
        const ChecksumGenerator()
            .generateBytes(utf8.encode(text), algorithm: algorithm)
            .checksum,
      );
    }
  });
  test('GivenUnicodeText_WhenGenerated_ThenIndependentUtf8Answers', () {
    const text = ' Olá 😀\r\n';
    expect(const ChecksumGenerator().generateText(text).checksum, '4fe11903');
    expect(
      const ChecksumGenerator()
          .generateText(text, algorithm: 'adler32')
          .checksum,
      '22ab051e',
    );
  });
  test('GivenAllBytes_WhenGenerated_ThenIndependentHighBitVectors', () {
    final bytes = List<int>.generate(256, (i) => i);
    expect(const ChecksumGenerator().generateBytes(bytes).checksum, '29058c73');
    expect(
      const ChecksumGenerator()
          .generateBytes(bytes, algorithm: 'adler32')
          .checksum,
      'adf67f81',
    );
  });
  test(
    'GivenMillionBytes_WhenGenerated_ThenIndependentVectorsWithoutSizeCap',
    () {
      final bytes = List<int>.filled(1000000, 97);
      expect(
        const ChecksumGenerator().generateBytes(bytes).checksum,
        'dc25bfbc',
      );
      expect(
        const ChecksumGenerator()
            .generateBytes(bytes, algorithm: 'adler32')
            .checksum,
        '15d870f9',
      );
    },
  );
  for (final phase in ['encode', 'checksum']) {
    test('Given${phase}AllocationFailure_WhenGenerated_ThenTypedResource', () {
      final generator = phase == 'encode'
          ? ChecksumGenerator.forTesting(
              encodeUtf8: (_) => throw OutOfMemoryError(),
            )
          : ChecksumGenerator.forTesting(
              checksum: (_, _) => throw OutOfMemoryError(),
            );
      expect(
        () => generator.generateText('PRIVATE'),
        throwsA(
          isA<ChecksumGenerateException>().having(
            (e) => e.kind,
            'kind',
            ChecksumGenerateFailureKind.resource,
          ),
        ),
      );
    });
  }
}
