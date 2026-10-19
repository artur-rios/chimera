import 'dart:convert';
import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_gui/hash_generate_page.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../../tests/fixtures/hashes/vectors.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final locale in ['en', 'pt-BR']) {
    for (final algorithm in ['sha256', 'sha384', 'sha512', 'md5', 'sha1']) {
      for (final source in ['text', 'file', 'clipboard', 'empty']) {
        testWidgets(
          'Given$locale$algorithm${source}_WhenHashGeneratedOffline_ThenExactCopyAndFileAndDiscard',
          (tester) async {
            final previous = HttpOverrides.current;
            final network = _HashOffline();
            HttpOverrides.global = network;
            addTearDown(() => HttpOverrides.global = previous);
            final directory = await Directory.systemTemp.createTemp(
              'chimera-hash-native-',
            );
            addTearDown(() => directory.delete(recursive: true));
            final inputFile = File('${directory.path}/input.bin');
            await inputFile.writeAsBytes([0, 255, 128, 239, 187, 191, 0, 10]);
            final outputFile = File('${directory.path}/result.txt');
            String? copied;
            Future<bool>? saveOperation;
            final expected =
                hashKnownVectors[source == 'empty'
                    ? 'empty'
                    : source == 'file'
                    ? 'binary'
                    : 'abc']![algorithm]!;
            await tester.pumpWidget(
              ChimeraApp(
                localeTag: locale,
                initialLocation: '/hash/generate',
                hashGenerateFilePicker: inputFile.readAsBytes,
                hashGenerateClipboardReader: () async => 'abc',
                hashGenerateClipboardWriter: (v) async => copied = v,
                hashGenerateFileSaver: (name, bytes, mime) =>
                    saveOperation = saveHashGenerateFile(
                      name,
                      bytes,
                      mime,
                      chooseLocation: (_, _) async => outputFile.path,
                    ),
              ),
            );
            await tester.pumpAndSettle();
            Finder control(String name) =>
                find.byKey(Key('hash-generate-$name'));
            Future<void> tap(String name) async {
              await tester.ensureVisible(control(name));
              await tester.tap(control(name));
              await tester.pumpAndSettle();
            }

            if (source == 'text') {
              await tester.enterText(control('input'), 'abc');
            }
            if (source == 'file' || source == 'clipboard') {
              await tap(source == 'file' ? 'file' : 'paste');
            }
            if (algorithm != 'sha256') {
              await tap('algorithm');
              await tester.tap(find.text(algorithm.toUpperCase()).last);
              await tester.pumpAndSettle();
            }
            await tap('submit');
            expect(
              tester.widget<SelectableText>(control('output')).data,
              expected,
            );
            expect(
              tester.widget<TextField>(control('input')).controller!.text,
              isEmpty,
            );
            expect(
              control('warning'),
              ['md5', 'sha1'].contains(algorithm)
                  ? findsOneWidget
                  : findsNothing,
            );
            await tap('copy');
            expect(copied, expected);
            await tap('save');
            // Frame settling does not wait for the native file transaction.
            expect(saveOperation, isNotNull);
            expect(await saveOperation!, isTrue);
            await tester.pumpAndSettle();
            expect(
              tester.widget<Text>(control('notice')).data,
              locale == 'en' ? 'Digest saved.' : 'Resumo salvo.',
            );
            expect(await outputFile.readAsBytes(), utf8.encode('$expected\n'));
            expect(
              directory.listSync().map((file) => file.uri),
              unorderedEquals([inputFile.uri, outputFile.uri]),
            );
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
            expect(find.text(expected), findsNothing);
            expect(network.attempts, 0);
          },
        );
      }
    }
    for (final failure in [
      'validation',
      'resource',
      'file',
      'clipboard',
      'copy',
      'save',
    ]) {
      testWidgets(
        'Given$locale${failure}Failure_WhenHashRequested_ThenNoPartialResultOffline',
        (tester) async {
          final previous = HttpOverrides.current;
          final network = _HashOffline();
          HttpOverrides.global = network;
          addTearDown(() => HttpOverrides.global = previous);
          Never fail() => throw StateError('SECRET');
          await tester.pumpWidget(
            ChimeraApp(
              localeTag: locale,
              initialLocation: '/hash/generate',
              hashGenerateService: failure == 'resource'
                  ? HashGenerateService(
                      generator: HashGenerator.forTesting(
                        hash: (_, _) => throw OutOfMemoryError(),
                      ),
                    )
                  : const HashGenerateService(),
              hashGenerateFilePicker: () async =>
                  failure == 'validation' ? [256] : fail(),
              hashGenerateClipboardReader: () async => fail(),
              hashGenerateClipboardWriter: (_) async => fail(),
              hashGenerateFileSaver: (_, _, _) async => fail(),
            ),
          );
          await tester.pumpAndSettle();
          Finder control(String name) => find.byKey(Key('hash-generate-$name'));
          Future<void> tap(String name) async {
            await tester.ensureVisible(control(name));
            await tester.tap(control(name));
            await tester.pumpAndSettle();
          }

          await tester.enterText(control('input'), 'SECRET');
          if (failure == 'copy' || failure == 'save') {
            await tap('submit');
            await tap(failure);
          } else if (failure == 'file' || failure == 'clipboard') {
            await tap(failure == 'file' ? 'file' : 'paste');
          } else {
            if (failure == 'validation') await tap('file');
            await tap('submit');
          }
          expect(control('error'), findsOneWidget);
          expect(control('result'), findsNothing);
          expect(control('copy'), findsNothing);
          expect(control('save'), findsNothing);
          expect(
            tester.widget<TextField>(control('input')).controller!.text,
            isEmpty,
          );
          expect(
            tester.widget<Text>(control('error')).data,
            isNot(contains('SECRET')),
          );
          expect(network.attempts, 0);
        },
      );
    }
  }
}

final class _HashOffline extends HttpOverrides {
  int attempts = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Hash must stay offline');
  }
}
