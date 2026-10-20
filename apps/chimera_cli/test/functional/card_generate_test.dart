import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  for (final locale in ['en', 'pt-BR']) {
    test(
      'Given${locale}Help_WhenRequested_ThenLocalizedContractWithoutGeneration',
      () async {
        final out = StringBuffer(), err = StringBuffer();
        final code = await runChimera(
          ['card', 'generate', '--help'],
          localeTag: locale,
          out: out,
          err: err,
          cardService: CardService(
            generator: CardGenerator.forTesting(
              candidate: (_) => throw StateError('must not generate'),
            ),
          ),
        );

        expect(code, 0);
        expect(
          out.toString(),
          '${const MessageCatalog().lookup(locale, 'cli.cardUsage')}\n',
        );
        expect(err.toString(), isEmpty);
      },
    );
  }

  test('GivenDefaults_WhenGenerated_ThenLabeledVisaReturns', () async {
    final out = StringBuffer(), err = StringBuffer();
    final code = await runChimera(
      ['card', 'generate'],
      localeTag: 'en',
      out: out,
      err: err,
      cardService: _service('4242424242424242'),
    );

    expect(code, 0);
    expect(
      out.toString(),
      'Synthetic test data - not for real transactions\n4242424242424242',
    );
    expect(err.toString(), isEmpty);
  });

  for (final entry in <String, String>{
    'visa': '4242424242424242',
    'mastercard': '5555555555554444',
    'amex': '378282246310005',
    'discover': '6011111111111117',
  }.entries) {
    test(
      'Given${entry.key}AndJson_WhenGenerated_ThenStableLabeledResult',
      () async {
        final out = StringBuffer(), err = StringBuffer();
        final code = await runChimera(
          ['card', 'generate', '--network=${entry.key}', '--count=2', '--json'],
          localeTag: 'en',
          out: out,
          err: err,
          cardService: _service(entry.value),
        );

        expect(code, 0);
        expect(err.toString(), isEmpty);
        expect(jsonDecode(out.toString()), {
          'network': entry.key,
          'count': 2,
          'synthetic': true,
          'label': 'synthetic-test-data',
          'values': [entry.value, entry.value],
        });
      },
    );
  }

  for (final locale in ['en', 'pt-BR']) {
    for (final args in [
      ['--network=diners-club'],
      ['--count=0'],
      ['unexpected'],
    ]) {
      test(
        'Given$locale${args}_WhenInvalid_Then64AndLocalizedFailure',
        () async {
          final out = StringBuffer(), err = StringBuffer();
          final code = await runChimera(
            ['card', 'generate', ...args],
            localeTag: locale,
            out: out,
            err: err,
            cardService: _service('4242424242424242'),
          );

          expect(code, 64);
          expect(out.toString(), isEmpty);
          expect(
            err.toString(),
            contains(
              const MessageCatalog().lookup(locale, 'error.card.validation'),
            ),
          );
        },
      );
    }
  }

  test(
    'GivenUnknownOptionAndJson_WhenParsed_ThenStableValidationJson',
    () async {
      final out = StringBuffer(), err = StringBuffer();
      final code = await runChimera(
        ['card', 'generate', '--private', '--json'],
        localeTag: 'en',
        out: out,
        err: err,
      );

      expect(code, 64);
      expect(out.toString(), isEmpty);
      final error =
          (jsonDecode(err.toString()) as Map<String, Object?>)['error']
              as Map<String, Object?>;
      expect(error['code'], 'card.invalid-options');
      expect(error['kind'], 'validation');
    },
  );

  test('GivenSourceFailure_WhenGenerated_Then70WithoutPanDiagnostic', () async {
    final out = StringBuffer(), err = StringBuffer();
    final code = await runChimera(
      ['card', 'generate', '--json'],
      localeTag: 'en',
      out: out,
      err: err,
      cardService: CardService(
        generator: CardGenerator.forTesting(
          candidate: (_) => throw StateError('PRIVATE PAN'),
        ),
      ),
    );

    expect(code, 70);
    expect(out.toString(), isEmpty);
    expect(err.toString(), contains('card.source-unavailable'));
    expect(err.toString(), isNot(contains('PRIVATE')));
  });

  test('GivenValidFirstCardThenRetryExhaustion_WhenGenerated_Then70WithoutPartialPan', () async {
    var attempts = 0;
    final out = StringBuffer(), err = StringBuffer();
    final code = await runChimera(
      ['card', 'generate', '--count=2', '--json'],
      localeTag: 'en',
      out: out,
      err: err,
      cardService: CardService(
        generator: CardGenerator.forTesting(
          candidate: (_) => ++attempts == 1
              ? '4242424242424242'
              : 'PRIVATE INVALID CANDIDATE',
        ),
      ),
    );

    expect(code, 70);
    expect(attempts, 33);
    expect(out.toString(), isEmpty);
    final error =
        (jsonDecode(err.toString()) as Map<String, Object?>)['error']
            as Map<String, Object?>;
    expect(error['code'], 'card.generation-failed');
    expect(error['kind'], 'processing');
    expect(err.toString(), isNot(contains('4242424242424242')));
    expect(err.toString(), isNot(contains('PRIVATE')));
  });

  test(
    'GivenOutputPath_WhenGenerated_ThenExactLabeledBatchAndNotice',
    () async {
      final out = StringBuffer(), err = StringBuffer();
      List<int>? written;
      final code = await runChimera(
        ['card', 'generate', '--count=2', '--output=result.txt'],
        localeTag: 'pt-BR',
        out: out,
        err: err,
        cardService: _service('4242424242424242'),
        writeOutputFile: (path, bytes) async {
          expect(path, 'result.txt');
          written = bytes;
        },
      );

      expect(code, 0);
      expect(err.toString(), isEmpty);
      expect(
        utf8.decode(written!),
        'Dados sintéticos de teste - não usar em transações reais\n'
        '4242424242424242\n4242424242424242',
      );
      expect(
        out.toString(),
        '${const MessageCatalog().lookup('pt-BR', 'card.saved')}\n',
      );
    },
  );

  test(
    'GivenOutputWriterFailure_WhenGenerated_Then74WithoutPanDiagnostic',
    () async {
      final out = StringBuffer(), err = StringBuffer();
      final code = await runChimera(
        ['card', 'generate', '--output=PRIVATE', '--json'],
        localeTag: 'en',
        out: out,
        err: err,
        cardService: _service('4242424242424242'),
        writeOutputFile: (_, _) async =>
            throw const FileSystemException('PRIVATE'),
      );

      expect(code, 74);
      expect(out.toString(), isEmpty);
      expect(err.toString(), isNot(contains('PRIVATE')));
      expect(err.toString(), isNot(contains('4242424242424242')));
    },
  );

  test('GivenStdoutFailure_WhenGenerated_Then74WithoutPanDiagnostic', () async {
    final err = StringBuffer();
    final code = await runChimera(
      ['card', 'generate'],
      localeTag: 'en',
      out: const _DeniedSink(),
      err: err,
      cardService: _service('4242424242424242'),
    );

    expect(code, 74);
    expect(
      err.toString(),
      contains(const MessageCatalog().lookup('en', 'error.card.outputAccess')),
    );
    expect(err.toString(), isNot(contains('4242424242424242')));
  });

  for (final resource in [false, true]) {
    test(
      'Given${resource}SerializationFailure_WhenJsonRequested_ThenTypedFailure',
      () async {
        final out = StringBuffer(), err = StringBuffer();
        final code = await runChimera(
          ['card', 'generate', '--json'],
          localeTag: 'en',
          out: out,
          err: err,
          cardService: _service('4242424242424242'),
          cardJsonEncoder: (_) {
            if (resource) throw OutOfMemoryError();
            throw StateError('PRIVATE');
          },
        );

        expect(code, resource ? 75 : 74);
        expect(out.toString(), isEmpty);
        expect(err.toString(), isNot(contains('PRIVATE')));
        expect(err.toString(), isNot(contains('4242424242424242')));
      },
    );
  }

  test(
    'GivenNativeExecutable_WhenCardCommandsRun_ThenProductionContractsHold',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'chimera-card-executable-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final library = (await Isolate.resolvePackageUri(
        Uri.parse('package:chimera_cli/chimera_cli.dart'),
      ))!;
      final entrypoint = File.fromUri(library.resolve('../bin/chimera.dart'));
      final executable =
          '${directory.path}/chimera-card${Platform.isWindows ? '.exe' : ''}';
      final compilation = await Process.run(Platform.resolvedExecutable, [
        'compile',
        'exe',
        entrypoint.path,
        '-o',
        executable,
      ]);
      expect(compilation.exitCode, 0, reason: compilation.stderr.toString());

      final result = await Process.run(executable, [
        'card',
        'generate',
        '--network=discover',
        '--count=2',
        '--json',
      ]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final json = jsonDecode(result.stdout.toString()) as Map<String, Object?>;
      expect(json['network'], 'discover');
      expect(json['synthetic'], isTrue);
      expect(json['label'], 'synthetic-test-data');
      expect(json['values'], hasLength(2));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

CardService _service(String value) =>
    CardService(generator: CardGenerator.forTesting(candidate: (_) => value));

final class _DeniedSink implements StringSink {
  const _DeniedSink();

  Never _fail() => throw StateError('PRIVATE stdout failure');

  @override
  void write(Object? object) => _fail();
  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) => _fail();
  @override
  void writeCharCode(int charCode) => _fail();
  @override
  void writeln([Object? object = '']) => _fail();
}
