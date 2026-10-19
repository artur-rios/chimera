import 'dart:convert';
import 'dart:io';

import 'package:chimera_gui/app.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../../tests/fixtures/certificates/algorithm_fixtures.dart';
import '../../../tests/fixtures/jwt_signing_keys.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final locale in ['en', 'pt-BR']) {
    for (final (context, source, expected) in [
      ('all', 'typed', '&amp;&lt;&gt;&quot;&#39;&#47; &amp;amp; Olá 🌍'),
      ('element', 'file', '&amp;&lt;&gt;"\'/ &amp;amp; Olá 🌍'),
      (
        'double-quoted-attribute',
        'clipboard',
        '&amp;&lt;&gt;&quot;\'/ &amp;amp; Olá 🌍',
      ),
      (
        'single-quoted-attribute',
        'typed',
        '&amp;&lt;&gt;"&#39;/ &amp;amp; Olá 🌍',
      ),
      ('all', 'empty', ''),
    ]) {
      testWidgets(
        'Given${locale}Html$context${source}_WhenEncodedCopiedAndSaved_ThenExactEntitiesTransferOffline',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            final network = _RejectConversionNetwork();
            final previous = HttpOverrides.current;
            HttpOverrides.global = network;
            addTearDown(() => HttpOverrides.global = previous);
            final directory = await Directory.systemTemp.createTemp(
              'chimera-html-',
            );
            addTearDown(() => directory.delete(recursive: true));
            const input = '&<>"\'/ &amp; Olá 🌍';
            String? copied;
            var copies = 0;
            var saves = 0;
            final saved = File('${directory.path}/chimera-html-encoded.txt');
            await tester.pumpWidget(
              ChimeraApp(
                localeTag: locale,
                initialLocation: '/html/encode',
                htmlEncodeFilePicker: () async => utf8.encode(input),
                htmlEncodeClipboardReader: () async => input,
                htmlEncodeClipboardWriter: (value) async {
                  copies++;
                  copied = value;
                },
                htmlEncodeFileSaver: (name, bytes, mime) async {
                  saves++;
                  expect(name, 'chimera-html-encoded.txt');
                  expect(mime, 'text/plain; charset=utf-8');
                  await saved.writeAsBytes(bytes, flush: true);
                  return true;
                },
              ),
            );
            await tester.pumpAndSettle();
            final editor = find.byKey(const Key('html-encode-input'));
            if (source == 'typed') {
              await tester.enterText(editor, input);
            } else if (source != 'empty') {
              await tester.tap(
                find.byKey(
                  Key('html-encode-${source == 'file' ? 'file' : 'paste'}'),
                ),
              );
              await tester.pumpAndSettle();
            }
            final selector = find.byKey(const Key('html-encode-context'));
            if (context == 'all') {
              expect(
                find.text(
                  locale == 'en' ? 'All characters' : 'Todos os caracteres',
                ),
                findsOneWidget,
              );
            } else {
              await tester.tap(selector);
              await tester.pumpAndSettle();
              final label = switch (context) {
                'element' =>
                  locale == 'en' ? 'Element text' : 'Texto de elemento',
                'double-quoted-attribute' =>
                  locale == 'en'
                      ? 'Double-quoted attribute'
                      : 'Atributo com aspas duplas',
                _ =>
                  locale == 'en'
                      ? 'Single-quoted attribute'
                      : 'Atributo com aspas simples',
              };
              await tester.tap(find.text(label).last);
              await tester.pumpAndSettle();
            }
            // Traverse the native controls in their published keyboard order.
            await tester.tap(editor);
            await tester.pumpAndSettle();
            for (final name in ['file', 'paste', 'context', 'submit']) {
              await tester.sendKeyEvent(LogicalKeyboardKey.tab);
              await tester.pumpAndSettle();
              expect(
                find.ancestor(
                  of: find.byWidget(
                    FocusManager.instance.primaryFocus!.context!.widget,
                  ),
                  matching: find.byKey(Key('html-encode-$name')),
                ),
                findsOneWidget,
                reason: name,
              );
            }
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pumpAndSettle();
            expect(
              FocusManager.instance.primaryFocus!.debugLabel,
              'HTML encoding result',
            );
            final result = find.byKey(const Key('html-encode-result'));
            final data = tester.getSemantics(result).getSemanticsData();
            expect(
              data.label,
              locale == 'en'
                  ? 'HTML encoded result'
                  : 'Resultado codificado em HTML',
            );
            expect(
              data.value,
              locale == 'en'
                  ? 'HTML encoding succeeded.'
                  : 'Codificação HTML concluída.',
            );
            expect(
              tester.widget<Semantics>(result).properties.liveRegion,
              isTrue,
            );
            expect(
              tester
                  .widget<SelectableText>(
                    find.byKey(const Key('html-encode-output')),
                  )
                  .data,
              expected,
            );
            expect(tester.widget<TextField>(editor).controller!.text, '');
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pumpAndSettle();
            expect(copied, expected);
            expect(copies, 1);
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pumpAndSettle();
            expect(saves, 1);
            expect(await saved.readAsBytes(), utf8.encode(expected));
            expect(network.attempts, 0);
          } finally {
            semantics.dispose();
          }
        },
      );
    }
    for (final action in ['copy', 'save']) {
      testWidgets(
        'Given${locale}HtmlResult_When${action}FailsThenMalformedFileLoaded_ThenSourceAndResultAreDiscardedOffline',
        (tester) async {
          final network = _RejectConversionNetwork();
          final previous = HttpOverrides.current;
          HttpOverrides.global = network;
          addTearDown(() => HttpOverrides.global = previous);
          var handoffs = 0;
          await tester.pumpWidget(
            ChimeraApp(
              localeTag: locale,
              initialLocation: '/html/encode',
              htmlEncodeFilePicker: () async => [0xc3, 0x28],
              htmlEncodeClipboardWriter: (_) async {
                handoffs++;
                throw StateError('private output denial');
              },
              htmlEncodeFileSaver: (_, _, _) async {
                handoffs++;
                throw StateError('private output denial');
              },
            ),
          );
          await tester.pumpAndSettle();
          final editor = find.byKey(const Key('html-encode-input'));
          await tester.enterText(editor, '<private-source>');
          await tester.tap(find.byKey(const Key('html-encode-submit')));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(Key('html-encode-$action')));
          await tester.tap(find.byKey(Key('html-encode-$action')));
          await tester.pumpAndSettle();
          expect(handoffs, 1);
          expect(find.byKey(const Key('html-encode-result')), findsNothing);
          expect(find.byKey(const Key('html-encode-output')), findsNothing);
          expect(tester.widget<TextField>(editor).controller!.text, '');
          expect(
            find.text(
              action == 'copy'
                  ? (locale == 'en'
                        ? 'The clipboard text could not be written.'
                        : 'Não foi possível gravar o texto na área de transferência.')
                  : (locale == 'en'
                        ? 'The HTML encoded text could not be saved.'
                        : 'Não foi possível salvar o texto codificado em HTML.'),
            ),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const Key('html-encode-file')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('html-encode-submit')));
          await tester.pumpAndSettle();
          expect(
            find.text(
              locale == 'en'
                  ? 'The HTML encoding request is invalid.'
                  : 'A solicitação de codificação HTML é inválida.',
            ),
            findsOneWidget,
          );
          expect(find.byKey(const Key('html-encode-result')), findsNothing);
          expect(find.byKey(const Key('html-encode-copy')), findsNothing);
          expect(find.byKey(const Key('html-encode-save')), findsNothing);
          expect(find.textContaining('private'), findsNothing);
          expect(tester.widget<TextField>(editor).controller!.text, '');
          expect(network.attempts, 0);
        },
      );
    }
  }

  for (final locale in ['en', 'pt-BR']) {
    for (final (source, input, expected) in [
      ('typed', '&lt;&amp;&#65;&#x1F642;&amp;lt;', '<&A🙂&lt;'),
      ('file', '&#60;&#38;&#x41;&#x1F642;', '<&A🙂'),
      ('clipboard', '&quot;offline&quot;', '"offline"'),
      ('empty', '', ''),
    ]) {
      testWidgets('Given${locale}HtmlDecode$source'
          '_WhenActivatedCopiedAndSaved_ThenExactTextTransfersOffline', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          final network = _RejectConversionNetwork();
          final previous = HttpOverrides.current;
          HttpOverrides.global = network;
          addTearDown(() => HttpOverrides.global = previous);
          final directory = await Directory.systemTemp.createTemp(
            'chimera-html-decode-',
          );
          addTearDown(() => directory.delete(recursive: true));
          String? copied;
          var copies = 0;
          var saves = 0;
          final saved = File('${directory.path}/chimera-html-decoded.txt');
          await tester.pumpWidget(
            ChimeraApp(
              localeTag: locale,
              initialLocation: '/html/decode',
              htmlDecodeFilePicker: () async => utf8.encode(input),
              htmlDecodeClipboardReader: () async => input,
              htmlDecodeClipboardWriter: (value) async {
                copies++;
                copied = value;
              },
              htmlDecodeFileSaver: (name, bytes, mime) async {
                saves++;
                expect(name, 'chimera-html-decoded.txt');
                expect(mime, 'text/plain; charset=utf-8');
                await saved.writeAsBytes(bytes, flush: true);
                return true;
              },
            ),
          );
          await tester.pumpAndSettle();
          final editor = find.byKey(const Key('html-decode-input'));
          if (source == 'typed') {
            await tester.enterText(editor, input);
          } else if (source == 'file') {
            await tester.tap(find.byKey(const Key('html-decode-file')));
            await tester.pumpAndSettle();
          } else if (source == 'clipboard') {
            await tester.tap(find.byKey(const Key('html-decode-paste')));
            await tester.pumpAndSettle();
          }
          await tester.tap(editor);
          await tester.pumpAndSettle();
          for (final name in ['file', 'paste', 'submit']) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pumpAndSettle();
            expect(
              find.ancestor(
                of: find.byWidget(
                  FocusManager.instance.primaryFocus!.context!.widget,
                ),
                matching: find.byKey(Key('html-decode-$name')),
              ),
              findsOneWidget,
              reason: name,
            );
          }
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(
            FocusManager.instance.primaryFocus!.debugLabel,
            'HTML decoding result',
          );
          final result = find.byKey(const Key('html-decode-result'));
          final data = tester.getSemantics(result).getSemanticsData();
          expect(
            data.label,
            locale == 'en'
                ? 'HTML decoded result'
                : 'Resultado decodificado de HTML',
          );
          expect(
            data.value,
            locale == 'en'
                ? 'HTML decoding succeeded.'
                : 'Decodificação HTML concluída.',
          );
          expect(
            tester.widget<Semantics>(result).properties.liveRegion,
            isTrue,
          );
          expect(
            tester
                .widget<SelectableText>(
                  find.byKey(const Key('html-decode-output')),
                )
                .data,
            expected,
          );
          expect(tester.widget<TextField>(editor).controller!.text, '');
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(copied, expected);
          expect(copies, 1);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(saves, 1);
          expect(await saved.readAsBytes(), utf8.encode(expected));
          expect(network.attempts, 0);
        } finally {
          semantics.dispose();
        }
      });
    }

    testWidgets(
      'Given${locale}MalformedHtmlFile_WhenDecoded_ThenSourceAndResultAreDiscardedOffline',
      (tester) async {
        final network = _RejectConversionNetwork();
        final previous = HttpOverrides.current;
        HttpOverrides.global = network;
        addTearDown(() => HttpOverrides.global = previous);
        await tester.pumpWidget(
          ChimeraApp(
            localeTag: locale,
            initialLocation: '/html/decode',
            htmlDecodeFilePicker: () async => [0xc3, 0x28],
          ),
        );
        await tester.pumpAndSettle();
        final editor = find.byKey(const Key('html-decode-input'));
        await tester.enterText(editor, '&lt;private&gt;');
        await tester.tap(find.byKey(const Key('html-decode-file')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('html-decode-submit')));
        await tester.pumpAndSettle();
        expect(
          find.text(
            locale == 'en'
                ? 'The HTML decoding request is invalid.'
                : 'A solicitação de decodificação HTML é inválida.',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('html-decode-result')), findsNothing);
        expect(find.byKey(const Key('html-decode-copy')), findsNothing);
        expect(find.byKey(const Key('html-decode-save')), findsNothing);
        expect(find.textContaining('private'), findsNothing);
        expect(tester.widget<TextField>(editor).controller!.text, '');
        expect(network.attempts, 0);
      },
    );
  }

  for (final locale in ['en', 'pt-BR']) {
    for (final source in ['text', 'binary']) {
      testWidgets(
        'Given${locale}Gzip${source}_WhenLevelSelectedCompressedAndSaved_ThenExactMemberRoundTripsOffline',
        (tester) async {
          final semantics = tester.ensureSemantics();
          final network = _RejectConversionNetwork();
          final previous = HttpOverrides.current;
          HttpOverrides.global = network;
          addTearDown(() => HttpOverrides.global = previous);
          final directory = await Directory.systemTemp.createTemp(
            'chimera-gzip-',
          );
          addTearDown(() => directory.delete(recursive: true));
          final sourceBytes = source == 'text'
              ? utf8.encode('Olá 🌍')
              : [0, 255, 128, 1];
          final level = source == 'text' ? 0 : 9;
          final expectedHex = source == 'text'
              ? '1f8b08000000000000ff010900f6ff4f6cc3a120f09f8c8d65c404fa09000000'
              : '1f8b08000000000000ff63f8dfc008002c4358d304000000';
          final outputCount = source == 'text' ? 32 : 24;
          var saves = 0;
          final saved = File('${directory.path}/chimera-compressed.gz');
          try {
            await tester.pumpWidget(
              ChimeraApp(
                localeTag: locale,
                initialLocation: '/gzip/compress',
                gzipCompressFilePicker: () async => sourceBytes,
                gzipCompressFileSaver: (name, bytes, mime) async {
                  saves++;
                  expect(name, 'chimera-compressed.gz');
                  expect(mime, 'application/gzip');
                  await saved.writeAsBytes(bytes, flush: true);
                  return true;
                },
              ),
            );
            await tester.pumpAndSettle();
            if (source == 'text') {
              await tester.enterText(
                find.byKey(const Key('gzip-compress-input')),
                'Olá 🌍',
              );
            } else {
              await tester.tap(find.byKey(const Key('gzip-compress-file')));
              await tester.pumpAndSettle();
            }
            final selector = find.byKey(const Key('gzip-compress-level'));
            await tester.ensureVisible(selector);
            await tester.tap(selector);
            await tester.pumpAndSettle();
            await tester.tap(find.text('$level'));
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const Key('gzip-compress-submit')));
            await tester.pumpAndSettle();
            final result = tester
                .getSemantics(find.byKey(const Key('gzip-compress-result')))
                .getSemanticsData();
            expect(
              result.label,
              locale == 'en'
                  ? 'Compressed binary result'
                  : 'Resultado binário comprimido',
            );
            expect(
              result.value,
              locale == 'en'
                  ? 'Compression succeeded.\nCompression level: $level\nInput bytes: ${sourceBytes.length}\nOutput bytes: $outputCount'
                  : 'Compressão concluída.\nNível de compressão: $level\nBytes de entrada: ${sourceBytes.length}\nBytes de saída: $outputCount',
            );
            expect(
              tester
                  .widget<Semantics>(
                    find.byKey(const Key('gzip-compress-result')),
                  )
                  .properties
                  .liveRegion,
              isTrue,
            );
            expect(find.byType(SelectableText), findsNothing);
            final save = find.byKey(const Key('gzip-compress-save'));
            await tester.ensureVisible(save);
            await tester.tap(save);
            await tester.pumpAndSettle();
            expect(saves, 1);
            _assertGzipMember(
              await saved.readAsBytes(),
              expectedHex,
              sourceBytes,
            );
            expect(
              find.text(
                locale == 'en' ? 'GZIP file saved.' : 'Arquivo GZIP salvo.',
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

  for (final locale in ['en', 'pt-BR']) {
    for (final mode in ['text', 'binary']) {
      testWidgets(
        'Given${locale}Gzip${mode}_WhenDecompressedCopiedAndSaved_ThenExactPayloadTransfersOffline',
        (tester) async {
          final semantics = tester.ensureSemantics();
          final network = _RejectConversionNetwork();
          final previous = HttpOverrides.current;
          HttpOverrides.global = network;
          addTearDown(() => HttpOverrides.global = previous);
          final directory = await Directory.systemTemp.createTemp(
            'chimera-gzip-decompress-',
          );
          addTearDown(() => directory.delete(recursive: true));
          final textMode = mode == 'text';
          final source = _hex(
            textMode
                ? '1f8b08000000000002ff7bbf7b7f222f97020084beddc007000000'
                : '1f8b08000000000002ff63f8dfc0f88f81970b00f65e06e708000000',
          );
          final expected = _hex(
            textMode ? 'efbbbf610d0a20' : '00ff8001fe000d0a',
          );
          String? copied;
          var saves = 0;
          final saved = File(
            '${directory.path}/${textMode ? 'chimera-decompressed.txt' : 'chimera-decompressed.bin'}',
          );
          try {
            await tester.pumpWidget(
              ChimeraApp(
                localeTag: locale,
                initialLocation: '/gzip/decompress',
                gzipDecompressFilePicker: () async => source,
                gzipDecompressClipboardWriter: (value) async => copied = value,
                gzipDecompressFileSaver: (name, bytes, mime) async {
                  saves++;
                  expect(
                    name,
                    textMode
                        ? 'chimera-decompressed.txt'
                        : 'chimera-decompressed.bin',
                  );
                  expect(
                    mime,
                    textMode
                        ? 'text/plain; charset=utf-8'
                        : 'application/octet-stream',
                  );
                  await saved.writeAsBytes(bytes, flush: true);
                  return true;
                },
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const Key('gzip-decompress-file')));
            await tester.pumpAndSettle();
            if (!textMode) {
              await tester.tap(
                find.byKey(const Key('gzip-decompress-mode-binary')),
              );
              await tester.pumpAndSettle();
            }
            await tester.tap(find.byKey(const Key('gzip-decompress-submit')));
            await tester.pumpAndSettle();

            final result = tester
                .getSemantics(find.byKey(const Key('gzip-decompress-result')))
                .getSemanticsData();
            expect(
              result.label,
              locale == 'en'
                  ? 'Decompressed result'
                  : 'Resultado descomprimido',
            );
            expect(
              result.value,
              locale == 'en'
                  ? 'Decompression succeeded.\nInput bytes: ${source.length}\nOutput bytes: ${expected.length}'
                  : 'Descompressão concluída.\nBytes de entrada: ${source.length}\nBytes de saída: ${expected.length}',
            );
            expect(
              tester
                  .widget<Semantics>(
                    find.byKey(const Key('gzip-decompress-result')),
                  )
                  .properties
                  .liveRegion,
              isTrue,
            );
            expect(
              find.byKey(const Key('gzip-decompress-file-summary')),
              findsNothing,
            );
            if (textMode) {
              expect(
                tester
                    .widget<SelectableText>(
                      find.byKey(const Key('gzip-decompress-text')),
                    )
                    .data,
                '\uFEFFa\r\n ',
              );
              await tester.tap(find.byKey(const Key('gzip-decompress-copy')));
              await tester.pumpAndSettle();
              expect(copied, '\uFEFFa\r\n ');
            } else {
              expect(
                find.byKey(const Key('gzip-decompress-text')),
                findsNothing,
              );
              expect(
                find.byKey(const Key('gzip-decompress-copy')),
                findsNothing,
              );
            }
            await tester.ensureVisible(
              find.byKey(const Key('gzip-decompress-save')),
            );
            await tester.tap(find.byKey(const Key('gzip-decompress-save')));
            await tester.pumpAndSettle();
            expect(saves, 1);
            expect(await saved.readAsBytes(), expected);
            expect(network.attempts, 0);
          } finally {
            semantics.dispose();
          }
        },
      );
    }

    testWidgets(
      'Given${locale}CorruptGzip_WhenDecompressed_ThenRedactedFailureHasNoPartialOutputOffline',
      (tester) async {
        final network = _RejectConversionNetwork();
        final previous = HttpOverrides.current;
        HttpOverrides.global = network;
        addTearDown(() => HttpOverrides.global = previous);
        await tester.pumpWidget(
          ChimeraApp(
            localeTag: locale,
            initialLocation: '/gzip/decompress',
            gzipDecompressFilePicker: () async => [31, 139, 8, 0, 1],
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('gzip-decompress-file')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('gzip-decompress-submit')));
        await tester.pumpAndSettle();
        expect(
          find.text(
            locale == 'en'
                ? 'The GZIP data could not be decompressed.'
                : 'Não foi possível descomprimir os dados GZIP.',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('gzip-decompress-result')), findsNothing);
        expect(
          find.byKey(const Key('gzip-decompress-file-summary')),
          findsNothing,
        );
        expect(network.attempts, 0);
      },
    );
  }

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

  for (final locale in <String>['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}JwtAlgorithmFamilies_WhenSignedCopiedAndSaved_ThenExactTokenTransfersOffline',
      (tester) async {
        final network = _RejectConversionNetwork();
        final previous = HttpOverrides.current;
        HttpOverrides.global = network;
        addTearDown(() => HttpOverrides.global = previous);
        for (final (algorithm, key) in <(String, String)>[
          ('HS256', '0123456789abcdef0123456789abcdef'),
          ('RS256', rsaPrivateJwk),
          ('ES256', ecPrivateJwk),
        ]) {
          String? copied;
          List<int>? saved;
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          await tester.pumpWidget(
            ChimeraApp(
              localeTag: locale,
              initialLocation: '/jwt/create',
              jwtCreateClipboardWriter: (value) async => copied = value,
              jwtCreateFileSaver: (name, bytes, mime) async {
                expect(name, 'chimera-jwt.txt');
                expect(mime, 'application/jwt');
                saved = List<int>.of(bytes);
                return true;
              },
            ),
          );
          await tester.pumpAndSettle();
          tester
              .widget<DropdownButtonFormField<String>>(
                find.byKey(const Key('jwt-create-algorithm')),
              )
              .onChanged!(algorithm);
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('jwt-create-claims')),
            '{"native":true}',
          );
          await tester.enterText(find.byKey(const Key('jwt-create-key')), key);
          await tester.ensureVisible(
            find.byKey(const Key('jwt-create-submit')),
          );
          await tester.tap(find.byKey(const Key('jwt-create-submit')));
          await tester.pumpAndSettle();
          final token = tester
              .widget<SelectableText>(
                find.byKey(const Key('jwt-create-output')),
              )
              .data!;
          final segments = token.split('.');
          expect(segments, hasLength(3));
          expect(_jwtJson(segments[0])['alg'], algorithm);
          expect(_jwtJson(segments[1]), <String, Object?>{'native': true});
          await tester.ensureVisible(find.byKey(const Key('jwt-create-copy')));
          await tester.tap(find.byKey(const Key('jwt-create-copy')));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(const Key('jwt-create-save')));
          await tester.tap(find.byKey(const Key('jwt-create-save')));
          await tester.pumpAndSettle();
          expect(copied, token);
          expect(utf8.decode(saved!), token);
        }
        expect(network.attempts, 0);
      },
    );
  }

  for (final locale in <String>['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}JwtInspectionScenarios_WhenInspectedAndCopied_ThenStatusesTransferOffline',
      (tester) async {
        final network = _RejectConversionNetwork();
        final previous = HttpOverrides.current;
        HttpOverrides.global = network;
        addTearDown(() => HttpOverrides.global = previous);
        const hmacKey = '0123456789abcdef0123456789abcdef';
        final scenarios =
            <({String name, String token, String? key, String status})>[
              (
                name: 'decode-only',
                token: _jwtToken('HS256', hmacKey, 'decode-only'),
                key: null,
                status: 'not-requested',
              ),
              (
                name: 'hmac',
                token: _jwtToken('HS256', hmacKey, 'hmac'),
                key: hmacKey,
                status: 'verified',
              ),
              (
                name: 'rsa',
                token: _jwtToken('RS256', rsaPrivateJwk, 'rsa'),
                key: rsaPrivateJwk,
                status: 'verified',
              ),
              (
                name: 'ecdsa',
                token: _jwtToken('ES256', ecPrivateJwk, 'ecdsa'),
                key: ecPrivateJwk,
                status: 'verified',
              ),
              (
                name: 'failed',
                token: _jwtToken('HS256', hmacKey, 'failed'),
                key: 'fedcba9876543210fedcba9876543210',
                status: 'failed',
              ),
            ];
        for (final scenario in scenarios) {
          String? copied;
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          await tester.pumpWidget(
            ChimeraApp(
              localeTag: locale,
              initialLocation: '/jwt/inspect',
              jwtInspectClipboardWriter: (value) async => copied = value,
            ),
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('jwt-inspect-token')),
            scenario.token,
          );
          if (scenario.key case final key?) {
            await tester.enterText(
              find.byKey(const Key('jwt-inspect-key')),
              key,
            );
          }
          await tester.ensureVisible(
            find.byKey(const Key('jwt-inspect-submit')),
          );
          await tester.tap(find.byKey(const Key('jwt-inspect-submit')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('jwt-inspect-output')), findsOneWidget);
          if (scenario.status == 'failed') {
            expect(
              find.byKey(const Key('jwt-inspect-untrusted')),
              findsOneWidget,
            );
          }
          await tester.ensureVisible(find.byKey(const Key('jwt-inspect-copy')));
          await tester.tap(find.byKey(const Key('jwt-inspect-copy')));
          await tester.pumpAndSettle();
          expect(jsonDecode(copied!) as Map<String, dynamic>, <String, Object?>{
            'header': <String, Object?>{
              'alg': scenario.name == 'rsa'
                  ? 'RS256'
                  : scenario.name == 'ecdsa'
                  ? 'ES256'
                  : 'HS256',
              'typ': 'JWT',
            },
            'claims': <String, Object?>{'nativeInspect': scenario.name},
            'verification': scenario.status,
          });
          expect(
            tester
                .widget<TextField>(find.byKey(const Key('jwt-inspect-token')))
                .controller!
                .text,
            isEmpty,
          );
          expect(
            tester
                .widget<TextField>(find.byKey(const Key('jwt-inspect-key')))
                .controller!
                .text,
            isEmpty,
          );
        }
        expect(network.attempts, 0);
      },
    );
  }

  for (final locale in <String>['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}QrOptions_WhenGeneratedSavedThenInvalidated_ThenExactPngTransfersOffline',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final network = _RejectConversionNetwork();
          final previous = HttpOverrides.current;
          HttpOverrides.global = network;
          addTearDown(() => HttpOverrides.global = previous);
          List<int>? saved;
          await tester.pumpWidget(
            ChimeraApp(
              localeTag: locale,
              initialLocation: '/qr/encode',
              qrEncodeFileSaver: (name, bytes, mime) async {
                expect(name, 'chimera-qr.png');
                expect(mime, 'image/png');
                saved = List<int>.of(bytes);
                return true;
              },
            ),
          );
          await tester.pumpAndSettle();

          await tester.enterText(
            find.byKey(const Key('qr-encode-input')),
            'native Olá 🌍',
          );
          tester
              .widget<DropdownButtonFormField<QrErrorCorrection>>(
                find.byKey(const Key('qr-encode-correction')),
              )
              .onChanged!(QrErrorCorrection.high);
          await tester.enterText(
            find.byKey(const Key('qr-encode-size')),
            '256',
          );
          await tester.tap(find.byKey(const Key('qr-encode-submit')));
          await tester.pumpAndSettle();

          final preview = tester.widget<Image>(
            find.byKey(const Key('qr-encode-preview')),
          );
          final previewBytes = (preview.image as MemoryImage).bytes;
          expect(previewBytes.take(8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
          expect(
            tester
                .widget<TextField>(find.byKey(const Key('qr-encode-input')))
                .controller!
                .text,
            isEmpty,
          );
          await tester.ensureVisible(find.byKey(const Key('qr-encode-save')));
          await tester.tap(find.byKey(const Key('qr-encode-save')));
          await tester.pumpAndSettle();
          expect(saved, previewBytes);

          await tester.enterText(
            find.byKey(const Key('qr-encode-input')),
            'invalidated source',
          );
          await tester.enterText(find.byKey(const Key('qr-encode-size')), '10');
          await tester.ensureVisible(find.byKey(const Key('qr-encode-submit')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('qr-encode-submit')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('qr-encode-error')), findsOneWidget);
          expect(find.byKey(const Key('qr-encode-preview')), findsNothing);
          expect(find.textContaining('invalidated source'), findsNothing);
          expect(network.attempts, 0);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
  for (final locale in <String>['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}QrImage_WhenDecodedCopiedSavedThenCorrupt_ThenExactTextTransfersOffline',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final network = _RejectConversionNetwork();
          final previous = HttpOverrides.current;
          HttpOverrides.global = network;
          addTearDown(() => HttpOverrides.global = previous);
          const text = 'QR Olá 世界 🌍';
          List<int> source = List<int>.of(
            const QrEncoder().encode(text, size: 256).pngBytes,
          );
          String? copied;
          List<int>? saved;
          await tester.pumpWidget(
            ChimeraApp(
              localeTag: locale,
              initialLocation: '/qr/decode',
              qrDecodeFilePicker: () async => source,
              qrDecodeClipboardWriter: (value) async {
                copied = value;
              },
              qrDecodeFileSaver: (name, bytes, mime) async {
                expect(name, 'chimera-qr-decoded.txt');
                expect(mime, 'text/plain');
                saved = List<int>.of(bytes);
                return true;
              },
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('qr-decode-file')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('qr-decode-submit')));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<SelectableText>(
                  find.byKey(const Key('qr-decode-result')),
                )
                .data,
            text,
          );
          expect(find.byKey(const Key('qr-decode-input-ready')), findsNothing);
          await tester.ensureVisible(find.byKey(const Key('qr-decode-copy')));
          await tester.tap(find.byKey(const Key('qr-decode-copy')));
          await tester.pumpAndSettle();
          expect(copied, text);
          await tester.ensureVisible(find.byKey(const Key('qr-decode-save')));
          await tester.tap(find.byKey(const Key('qr-decode-save')));
          await tester.pumpAndSettle();
          expect(saved, utf8.encode(text));
          source = <int>[1, 2, 3];
          await tester.ensureVisible(find.byKey(const Key('qr-decode-file')));
          await tester.tap(find.byKey(const Key('qr-decode-file')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('qr-decode-submit')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('qr-decode-error')), findsOneWidget);
          expect(find.byKey(const Key('qr-decode-result')), findsNothing);
          expect(find.byKey(const Key('qr-decode-input-ready')), findsNothing);
          expect(network.attempts, 0);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}

String _jwtToken(String algorithm, String key, String scenario) =>
    const JwtCreator()
        .create(
          JwtCreateRequest(
            headerJson: '{}',
            claimsJson: jsonEncode(<String, Object?>{
              'nativeInspect': scenario,
            }),
            algorithm: algorithm,
            key: key,
          ),
        )
        .token;

Map<String, Object?> _jwtJson(String segment) => (jsonDecode(
  utf8.decode(base64Url.decode(base64Url.normalize(segment))),
) as Map<String, dynamic>).cast<String, Object?>();

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

void _assertGzipMember(List<int> actual, String expectedHex, List<int> source) {
  // Literal RFC 1952 members: zero MTIME, no metadata, CRC32 and ISIZE.
  expect(
    actual.map((value) => value.toRadixString(16).padLeft(2, '0')).join(),
    expectedHex,
  );
  // dart:io delegates to the platform zlib decoder, independent of archive.
  expect(gzip.decode(actual), source);
}

List<int> _hex(String value) => [
  for (var offset = 0; offset < value.length; offset += 2)
    int.parse(value.substring(offset, offset + 2), radix: 16),
];

final class _RejectConversionNetwork extends HttpOverrides {
  var attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Certificate conversion must stay offline.');
  }
}
