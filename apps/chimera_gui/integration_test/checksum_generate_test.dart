import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_gui/checksum_generate_page.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../../tests/fixtures/checksums/vectors.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final locale in ['en', 'pt-BR']) {
    for (final algorithm in ['crc32', 'adler32']) {
      for (final source in ['text', 'file', 'clipboard', 'empty']) {
        testWidgets(
          'Given$locale$algorithm${source}_WhenChecksumGeneratedOffline_ThenExactCopyAndFileAndDiscard',
          (tester) async {
            final previous = HttpOverrides.current;
            final network = _ChecksumOffline();
            HttpOverrides.global = network;
            addTearDown(() => HttpOverrides.global = previous);
            final directory = await Directory.systemTemp.createTemp(
              'chimera-checksum-native-',
            );
            addTearDown(() => directory.delete(recursive: true));
            final inputFile = File('${directory.path}/input.bin');
            await inputFile.writeAsBytes([0, 255, 128, 13, 10]);
            final outputFile = File('${directory.path}/result.txt');
            String? copied;
            final expected =
                checksumKnownVectors[source == 'empty'
                    ? 'empty'
                    : source == 'file'
                    ? 'binary'
                    : 'abc']![algorithm]!;
            await tester.pumpWidget(
              ChimeraApp(
                localeTag: locale,
                initialLocation: '/checksum/generate',
                checksumGenerateFilePicker: inputFile.readAsBytes,
                checksumGenerateClipboardReader: () async => 'abc',
                checksumGenerateClipboardWriter: (v) async => copied = v,
                checksumGenerateFileSaver: (name, bytes, mime) =>
                    saveChecksumGenerateFile(
                      name,
                      bytes,
                      mime,
                      chooseLocation: (_, _) async => outputFile.path,
                    ),
              ),
            );
            await tester.pumpAndSettle();
            Finder control(String name) =>
                find.byKey(Key('checksum-generate-$name'));
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
            if (algorithm != 'crc32') {
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
            await tap('copy');
            expect(copied, expected);
            await tap('save');
            expect(await outputFile.readAsString(), '$expected\n');
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
        'Given$locale${failure}Failure_WhenChecksumRequested_ThenNoPartialResultOffline',
        (tester) async {
          final previous = HttpOverrides.current;
          final network = _ChecksumOffline();
          HttpOverrides.global = network;
          addTearDown(() => HttpOverrides.global = previous);
          Never fail() => throw StateError('SECRET');
          await tester.pumpWidget(
            ChimeraApp(
              localeTag: locale,
              initialLocation: '/checksum/generate',
              checksumGenerateService: failure == 'resource'
                  ? ChecksumGenerateService(
                      generator: ChecksumGenerator.forTesting(
                        checksum: (_, _) => throw OutOfMemoryError(),
                      ),
                    )
                  : const ChecksumGenerateService(),
              checksumGenerateFilePicker: () async =>
                  failure == 'validation' ? [256] : fail(),
              checksumGenerateClipboardReader: () async => fail(),
              checksumGenerateClipboardWriter: (_) async => fail(),
              checksumGenerateFileSaver: (_, _, _) async => fail(),
            ),
          );
          await tester.pumpAndSettle();
          Finder control(String name) =>
              find.byKey(Key('checksum-generate-$name'));
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

final class _ChecksumOffline extends HttpOverrides {
  int attempts = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Checksum must stay offline');
  }
}
