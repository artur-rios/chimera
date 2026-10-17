import 'dart:convert';
import 'dart:io';

import 'package:chimera_gui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../../tests/fixtures/certificates/algorithm_fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final locale in ['en', 'pt-BR']) {
    for (final source in ['pem', 'der']) {
      testWidgets(
        'Given${locale}Certificate${source}_WhenConvertedAndSaved_ThenExactFixtureAndSafeSemanticsTransferOffline',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            final network = _RejectConversionNetwork();
            final previous = HttpOverrides.current;
            HttpOverrides.global = network;
            addTearDown(() => HttpOverrides.global = previous);
            final der = base64.decode(
              _certificatePem
                  .split('\n')
                  .where((line) => !line.startsWith('-----'))
                  .join(),
            );
            final target = source == 'pem' ? 'der' : 'pem';
            final inputCount = source == 'pem' ? 778 : 534;
            final outputCount = target == 'pem' ? 778 : 534;
            String? savedName;
            List<int>? savedBytes;
            String? copied;
            var saves = 0;
            await tester.pumpWidget(
              ChimeraApp(
                localeTag: locale,
                initialLocation: '/certificate/convert',
                certificateConvertFilePicker: () async => der,
                certificateConvertClipboardWriter: (value) async =>
                    copied = value,
                certificateConvertFileSaver: (name, bytes) async {
                  saves++;
                  savedName = name;
                  savedBytes = List<int>.of(bytes);
                  return true;
                },
              ),
            );
            await tester.pumpAndSettle();
            if (source == 'pem') {
              await tester.enterText(
                find.byKey(const Key('certificate-convert-input')),
                _certificatePem,
              );
            } else {
              await tester.tap(
                find.byKey(const Key('certificate-convert-file')),
              );
              await tester.pumpAndSettle();
            }
            for (final key in ['source-$source', 'target-$target', 'submit']) {
              final control = find.byKey(Key('certificate-convert-$key'));
              await tester.ensureVisible(control);
              await tester.tap(control);
              await tester.pumpAndSettle();
            }
            final result = tester
                .getSemantics(
                  find.byKey(const Key('certificate-convert-result-semantics')),
                )
                .getSemanticsData();
            expect(
              result.label,
              locale == 'en'
                  ? 'Converted certificate'
                  : 'Certificado convertido',
            );
            expect(
              result.value,
              locale == 'en'
                  ? 'Certificate conversion succeeded.\n'
                        'Source representation: ${source.toUpperCase()}\n'
                        'Target representation: ${target.toUpperCase()}\n'
                        'Input bytes: $inputCount\nDER bytes: 534\nOutput bytes: $outputCount'
                  : 'Conversão do certificado concluída.\n'
                        'Representação de origem: ${source.toUpperCase()}\n'
                        'Representação de destino: ${target.toUpperCase()}\n'
                        'Bytes de entrada: $inputCount\nBytes DER: 534\nBytes de saída: $outputCount',
            );
            if (target == 'pem') {
              expect(
                tester
                    .widget<SelectableText>(
                      find.byKey(const Key('certificate-convert-result')),
                    )
                    .data,
                _certificatePem,
              );
              await tester.ensureVisible(
                find.byKey(const Key('certificate-convert-copy')),
              );
              await tester.tap(
                find.byKey(const Key('certificate-convert-copy')),
              );
              await tester.pumpAndSettle();
              expect(copied, _certificatePem);
            } else {
              expect(
                find.byKey(const Key('certificate-convert-result')),
                findsNothing,
              );
              expect(
                find.byKey(const Key('certificate-convert-copy')),
                findsNothing,
              );
            }
            await tester.ensureVisible(
              find.byKey(const Key('certificate-convert-save')),
            );
            await tester.tap(find.byKey(const Key('certificate-convert-save')));
            await tester.pumpAndSettle();
            expect(saves, 1);
            expect(savedName, 'chimera-certificate.$target');
            expect(
              savedBytes,
              target == 'der' ? der : utf8.encode(_certificatePem),
            );
            expect(
              find.text(
                locale == 'en'
                    ? 'Converted certificate saved.'
                    : 'Certificado convertido salvo.',
              ),
              findsOneWidget,
            );
            expect(network.attempts, 0);
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }

  testWidgets('GivenApplicationLaunch_WhenRootRouteLoads_ThenShellIsVisible', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChimeraApp(
        localeTag: 'en',
        currentTime: () => DateTime.utc(2026, 1, 5, 12),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chimera'), findsOneWidget);
    expect(find.text('Developer toolbox'), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-cron')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('cron-expression')),
      '0 9 * * MON-FRI',
    );
    await tester.enterText(find.byKey(const Key('cron-time-zone')), 'UTC');
    await tester.enterText(find.byKey(const Key('cron-count')), '1');
    await tester.enterText(
      find.byKey(const Key('cron-reference')),
      '2026-01-05T12:00:00Z',
    );
    await tester.tap(find.byKey(const Key('cron-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Cron schedule: 0 9 * * 1-5'), findsOneWidget);
    expect(
      find.textContaining('Next: 2026-01-06T09:00:00.000+00:00'),
      findsOneWidget,
    );
  });

  testWidgets('GivenDateRoute_WhenConversionRuns_ThenSharedResultIsVisible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ChimeraApp(localeTag: 'en', initialLocation: '/date/convert'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('date-value')),
      '2026-01-15T12:30:45Z',
    );
    await tester.enterText(
      find.byKey(const Key('date-target-time-zone')),
      'America/Sao_Paulo',
    );
    await tester.tap(find.byKey(const Key('date-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('Converted value: 2026-01-15T09:30:45.000-03:00'),
      findsOneWidget,
    );
  });

  testWidgets(
    'GivenNumberBaseRoute_WhenArbitraryPrecisionConversionRuns_ThenSharedResultIsVisible',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(
          localeTag: 'en',
          initialLocation: '/number/convert-base',
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('number-base-input')),
        '184467440737095516160',
      );
      await tester.tap(find.byKey(const Key('number-base-submit')));
      await tester.pumpAndSettle();

      expect(find.text('a0000000000000000'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTextEscapeRoute_WhenUnicodeContentEscapes_ThenSharedResultIsVisible',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'en', initialLocation: '/text/escape'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('text-escape-input')),
        'A"\\\né',
      );
      await tester.tap(find.byKey(const Key('text-escape-submit')));
      await tester.pumpAndSettle();

      expect(find.text(r'A\"\\\né'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTextUnescapeRoute_WhenUnicodeEscapesDecode_ThenSharedResultIsVisible',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'en', initialLocation: '/text/unescape'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('text-unescape-input')),
        r'A\"\\\né\u0021',
      );
      await tester.tap(find.byKey(const Key('text-unescape-submit')));
      await tester.pumpAndSettle();

      expect(find.text('A"\\\né!'), findsOneWidget);
    },
  );

  testWidgets('GivenJsonTableRoute_WhenConversionRuns_ThenTableIsVisible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ChimeraApp(
        localeTag: 'en',
        initialLocation: '/json/array-to-table',
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('json-table-input')),
      '[{"name":"Ada","languages":["Dart","C"]}]',
    );
    await tester.tap(find.byKey(const Key('json-table-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('["Dart","C"]'), findsOneWidget);
  });

  testWidgets('GivenJsonCsvRoute_WhenConversionRuns_ThenCsvIsVisible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ChimeraApp(localeTag: 'en', initialLocation: '/json/array-to-csv'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('json-csv-input')),
      '[{"name":"Ada","languages":["Dart","C"]}]',
    );
    await tester.tap(find.byKey(const Key('json-csv-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('name,languages\r\nAda,"[""Dart"",""C""]"'),
      findsOneWidget,
    );
  });

  testWidgets('GivenJsonYamlRoute_WhenConversionRuns_ThenYamlIsVisible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ChimeraApp(localeTag: 'en', initialLocation: '/json/to-yaml'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('json-yaml-input')),
      '{"name":"Ada","languages":["Dart","C"]}',
    );
    await tester.tap(find.byKey(const Key('json-yaml-submit')));
    await tester.pumpAndSettle();

    expect(find.text('name: Ada\nlanguages:\n  - Dart\n  - C'), findsOneWidget);
  });

  testWidgets('GivenJsonFormatRoute_WhenFormattingRuns_ThenJsonIsVisible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ChimeraApp(localeTag: 'en', initialLocation: '/json/format'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('json-format-input')),
      '{"name":"Ada","languages":["Dart","C"]}',
    );
    await tester.tap(find.byKey(const Key('json-format-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '{\n'
        '  "name": "Ada",\n'
        '  "languages": [\n'
        '    "Dart",\n'
        '    "C"\n'
        '  ]\n'
        '}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('GivenSqlFormatRoute_WhenFormattingRuns_ThenSqlIsVisible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ChimeraApp(localeTag: 'en', initialLocation: '/sql/format'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('sql-format-input')),
      'select name,language from developers where active=true',
    );
    await tester.tap(find.byKey(const Key('sql-format-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'SELECT\n'
        '  name,\n'
        '  language\n'
        'FROM developers\n'
        'WHERE active = TRUE',
      ),
      findsOneWidget,
    );
  });

  testWidgets('GivenXmlFormatRoute_WhenFormattingRuns_ThenXmlIsVisible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ChimeraApp(localeTag: 'en', initialLocation: '/xml/format'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('xml-format-input')),
      '<developers><developer name="Ada"/></developers>',
    );
    await tester.tap(find.byKey(const Key('xml-format-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '<developers>\n'
        '  <developer name="Ada"/>\n'
        '</developers>',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'GivenListCompareRoute_WhenListsCompared_ThenStableSetsAreVisible',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'en', initialLocation: '/list/compare'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('list-compare-left-input')),
        'alpha\nleft',
      );
      await tester.enterText(
        find.byKey(const Key('list-compare-right-input')),
        'alpha\nright',
      );
      await tester.tap(find.byKey(const Key('list-compare-submit')));
      await tester.pumpAndSettle();

      expect(find.text('left'), findsOneWidget);
      expect(find.text('right'), findsOneWidget);
      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('Equal: no'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTextAnalyzeRoute_WhenUnicodeAnalyzed_ThenStableCountsAreVisible',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'en', initialLocation: '/text/analyze'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('text-analyze-input')),
        'Cafe\u0301 👩🏽‍💻\nOlá',
      );
      await tester.tap(find.byKey(const Key('text-analyze-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Characters: 10'), findsOneWidget);
      expect(find.text('Words: 2'), findsOneWidget);
      expect(find.text('Lines: 2'), findsOneWidget);
      expect(find.text('UTF-8 bytes: 27'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTextTransformRoute_WhenLinesDeduplicated_ThenSharedResultIsVisible',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'en', initialLocation: '/text/transform'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('text-transform-input')),
        'beta\r\nalpha\nbeta\n',
      );
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('text-transform-mode')),
          )
          .onChanged!('deduplicate-lines');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('text-transform-submit')));
      await tester.pumpAndSettle();

      expect(find.text('beta\nalpha\n'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTextCompareRoute_WhenWordsCompared_ThenStructuredDiffIsVisible',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'en', initialLocation: '/text/compare'),
      );
      await tester.pumpAndSettle();

      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('text-compare-granularity')),
          )
          .onChanged!('word');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('text-compare-left-input')),
        'Hello world',
      );
      await tester.enterText(
        find.byKey(const Key('text-compare-right-input')),
        'Hello brave world',
      );
      await tester.tap(find.byKey(const Key('text-compare-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('text-compare-result')), findsOneWidget);
      expect(find.text('Added: 2'), findsOneWidget);
      expect(find.text('Removed: 0'), findsOneWidget);
      expect(find.text('Unchanged: 3'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenBase64Route_WhenUtf8TextEncodes_ThenCanonicalResultIsVisible',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'en', initialLocation: '/base64/encode'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('base64-encode-input')),
        'Olá 👋',
      );
      await tester.tap(find.byKey(const Key('base64-encode-submit')));
      await tester.pumpAndSettle();

      expect(find.text('T2zDoSDwn5GL'), findsOneWidget);
      expect(find.text('Input bytes: 9'), findsOneWidget);
      expect(find.text('Output characters: 12'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenBase64BinaryFile_WhenEncodedCopiedAndSaved_ThenExactPayloadTransfers',
    (tester) async {
      String? copied;
      String? savedName;
      List<int>? savedBytes;
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/base64/encode',
          base64EncodeFilePicker: () async => <int>[0x00, 0xff],
          base64EncodeClipboardWriter: (value) async => copied = value,
          base64EncodeFileSaver: (name, bytes) async {
            savedName = name;
            savedBytes = List<int>.of(bytes);
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('base64-encode-file')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('base64-encode-submit')));
      await tester.pumpAndSettle();

      expect(find.text('AP8='), findsOneWidget);
      await tester.tap(find.byKey(const Key('base64-encode-copy')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('base64-encode-save')));
      await tester.pumpAndSettle();

      expect(copied, 'AP8=');
      expect(savedName, 'chimera-base64.txt');
      expect(savedBytes, <int>[0x41, 0x50, 0x38, 0x3d]);
    },
  );

  testWidgets(
    'GivenBase64Utf8Text_WhenDecodedCopiedAndSaved_ThenExactPayloadTransfers',
    (tester) async {
      String? copied;
      String? savedName;
      List<int>? savedBytes;
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/base64/decode',
          base64DecodeClipboardWriter: (value) async => copied = value,
          base64DecodeFileSaver: (name, bytes) async {
            savedName = name;
            savedBytes = List<int>.of(bytes);
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('base64-decode-input')),
        'T2zDoSDwn5GL',
      );
      await tester.tap(find.byKey(const Key('base64-decode-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Olá 👋'), findsOneWidget);
      await tester.tap(find.byKey(const Key('base64-decode-copy')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('base64-decode-save')));
      await tester.pumpAndSettle();

      expect(copied, 'Olá 👋');
      expect(savedName, 'chimera-decoded.txt');
      expect(savedBytes, utf8.encode('Olá 👋'));
    },
  );

  testWidgets(
    'GivenBase64Png_WhenDecodedAndSaved_ThenPreviewAndExactBytesTransfer',
    (tester) async {
      String? savedName;
      List<int>? savedBytes;
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/base64/decode',
          base64DecodeFileSaver: (name, bytes) async {
            savedName = name;
            savedBytes = List<int>.of(bytes);
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('base64-decode-mode-binary')));
      await tester.enterText(
        find.byKey(const Key('base64-decode-input')),
        _validPngBase64,
      );
      await tester.tap(find.byKey(const Key('base64-decode-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('base64-decode-preview')), findsOneWidget);
      expect(find.text('Image preview available.'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('base64-decode-save')));
      await tester.tap(find.byKey(const Key('base64-decode-save')));
      await tester.pumpAndSettle();

      expect(savedName, 'chimera-decoded.png');
      expect(savedBytes, base64.decode(_validPngBase64));
    },
  );
  for (final (id, oid) in [
    ('ed25519', '1.3.101.112'),
    ('unknown-key', '2.999.5'),
  ]) {
    testWidgets(
      'GivenAlgorithmCertificate${id}_WhenInspectedAndCopied_ThenOriginalMetadataReturns',
      (tester) async {
        String? copied;
        await tester.pumpWidget(
          ChimeraApp(
            localeTag: 'en',
            initialLocation: '/certificate/inspect',
            certificateInspectFilePicker: () async =>
                base64.decode(certificateAlgorithmFixtures[id]!),
            certificateInspectClipboardWriter: (value) async => copied = value,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('certificate-inspect-file')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('certificate-inspect-submit')),
        );
        await tester.tap(find.byKey(const Key('certificate-inspect-submit')));
        await tester.pumpAndSettle();
        final metadata = tester
            .widget<SelectableText>(
              find.byKey(const Key('certificate-inspect-result')),
            )
            .data!;
        expect(metadata, contains('Public key algorithm: $oid\n'));
        expect(
          metadata,
          contains('Not before (UTC): 1950-01-01T00:00:00.000Z'),
        );
        expect(metadata, contains('Not after (UTC): 2049-12-31T23:59:59.000Z'));
        await tester.ensureVisible(
          find.byKey(const Key('certificate-inspect-copy')),
        );
        await tester.tap(find.byKey(const Key('certificate-inspect-copy')));
        await tester.pumpAndSettle();
        final result = jsonDecode(copied!) as Map<String, Object?>;
        expect(result['publicKeyAlgorithm'], {'oid': oid, 'name': null});
        expect(result['signatureAlgorithm'], {
          'oid': '1.3.101.112',
          'name': null,
        });
        expect(result['notBefore'], '1950-01-01T00:00:00.000Z');
        expect(result['notAfter'], '2049-12-31T23:59:59.000Z');
        expect(result['serialNumberHex'], '01AB');
        expect(result['inputByteCount'], 335);
        expect(result['derByteCount'], 335);
        expect(find.text('Certificate JSON copied.'), findsOneWidget);
      },
    );
  }
  for (final source in ['pem text', 'der file', 'base64 clipboard']) {
    testWidgets(
      'GivenCertificate${source}_WhenInspectedAndCopied_ThenExactMetadataTransfers',
      (tester) async {
        String? copied;
        final base64Text = _certificatePem
            .split('\n')
            .where((line) => !line.startsWith('-----') && line.isNotEmpty)
            .join();
        await tester.pumpWidget(
          ChimeraApp(
            localeTag: 'en',
            initialLocation: '/certificate/inspect',
            certificateInspectFilePicker: () async => base64.decode(base64Text),
            certificateInspectClipboardReader: () async => '$base64Text\n',
            certificateInspectClipboardWriter: (value) async => copied = value,
          ),
        );
        await tester.pumpAndSettle();
        if (source == 'pem text') {
          await tester.enterText(
            find.byKey(const Key('certificate-inspect-input')),
            _certificatePem,
          );
        } else {
          await tester.tap(
            find.byKey(
              Key(
                source == 'der file'
                    ? 'certificate-inspect-file'
                    : 'certificate-inspect-paste',
              ),
            ),
          );
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(
          find.byKey(const Key('certificate-inspect-submit')),
        );
        await tester.tap(find.byKey(const Key('certificate-inspect-submit')));
        await tester.pumpAndSettle();
        final representation = source.split(' ').first;
        final count = source == 'pem text'
            ? 778
            : source == 'der file'
            ? 534
            : 713;
        final metadata = tester
            .widget<SelectableText>(
              find.byKey(const Key('certificate-inspect-result')),
            )
            .data!;
        for (final value in [
          'Representation: ${representation == 'base64' ? 'Base64' : representation.toUpperCase()}',
          'Version: 3',
          'Serial number (hex): 01AB',
          'commonName (2.5.4.3): example.test',
          'commonName (2.5.4.3): Example CA',
          '1.2.3.4 (1.2.3.4): Unknown attribute',
          'Not before (UTC): 2024-01-01T00:00:00.000Z',
          'Not after (UTC): 2034-01-01T00:00:00.000Z',
          'sha256WithRSAEncryption (1.2.840.113549.1.1.11)',
          'rsaEncryption (1.2.840.113549.1.1.1)',
          'basicConstraints (2.5.29.19), critical: yes',
          '1.2.3.5 (1.2.3.5), critical: no',
          'Input bytes: $count',
          'DER bytes: 534',
        ]) {
          expect(metadata, contains(value));
        }
        await tester.ensureVisible(
          find.byKey(const Key('certificate-inspect-copy')),
        );
        await tester.tap(find.byKey(const Key('certificate-inspect-copy')));
        await tester.pumpAndSettle();
        expect(
          copied,
          '{"representation":"$representation",'
          '$_certificateJsonFields'
          '"inputByteCount":$count,"derByteCount":534}',
        );
        expect(find.text('Certificate JSON copied.'), findsOneWidget);
      },
    );
  }
}

// Public fixture pinned by tests/fixtures/certificates/manifest.json.
// Embedded so native runner working directories cannot alter the input.
const _certificatePem = '''-----BEGIN CERTIFICATE-----
MIICEjCCAXugAwIBAgICAaswDQYJKoZIhvcNAQELBQAwMDETMBEGA1UEAwwKRXhh
bXBsZSBDQTEZMBcGA1UECgwQQ2hpbWVyYSBmaXh0dXJlczAeFw0yNDAxMDEwMDAw
MDBaFw0zNDAxMDEwMDAwMDBaME4xFTATBgNVBAMMDGV4YW1wbGUudGVzdDEZMBcG
A1UECgwQQ2hpbWVyYSBmaXh0dXJlczEaMBgGAyoDBAwRVW5rbm93biBhdHRyaWJ1
dGUwgZ4wDQYJKoZIhvcNAQEBBQADgYwAMIGIAoGAAIAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAoMCAwEAAaMeMBwwDwYDVR0TAQH/BAUwAwEB/zAJBgMqAwUE
AgUAMA0GCSqGSIb3DQEBCwUAA4GBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAA
-----END CERTIFICATE-----
''';
// Literal public metadata, independent of the parser and serializer under test.
const _certificateJsonFields =
    '"version":3,"serialNumberHex":"01AB",'
    '"subject":[{"oid":"2.5.4.3","name":"commonName","value":"example.test"},'
    '{"oid":"2.5.4.10","name":"organizationName","value":"Chimera fixtures"},'
    '{"oid":"1.2.3.4","name":null,"value":"Unknown attribute"}],'
    '"issuer":[{"oid":"2.5.4.3","name":"commonName","value":"Example CA"},'
    '{"oid":"2.5.4.10","name":"organizationName","value":"Chimera fixtures"}],'
    '"notBefore":"2024-01-01T00:00:00.000Z",'
    '"notAfter":"2034-01-01T00:00:00.000Z",'
    '"signatureAlgorithm":{"oid":"1.2.840.113549.1.1.11",'
    '"name":"sha256WithRSAEncryption"},'
    '"publicKeyAlgorithm":{"oid":"1.2.840.113549.1.1.1","name":"rsaEncryption"},'
    '"extensions":[{"oid":"2.5.29.19","name":"basicConstraints","critical":true},'
    '{"oid":"1.2.3.5","name":null,"critical":false}],';

const _validPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

final class _RejectConversionNetwork extends HttpOverrides {
  var attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Certificate conversion must stay offline.');
  }
}
