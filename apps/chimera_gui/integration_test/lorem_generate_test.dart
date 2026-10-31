import 'dart:convert';
import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_gui/local_file_save.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const paragraph = 'Lorem ipsum dolor sit amet. Consectetur adipiscing elit.';
  for (final locale in ['en', 'pt-BR']) {
    for (final unit in ['words', 'sentences', 'paragraphs']) {
      testWidgets(
        'Given$locale${unit}_WhenGeneratedOffline_ThenExactCopySaveAndConfigurationInvalidation',
        (tester) async {
          final network = _Offline();
          final previous = HttpOverrides.current;
          HttpOverrides.global = network;
          addTearDown(() => HttpOverrides.global = previous);
          final directory = await Directory.systemTemp.createTemp(
            'lorem-native-',
          );
          addTearDown(() => directory.delete(recursive: true));
          final saved = File('${directory.path}/lorem.txt');
          await saved.writeAsString('previous');
          String? copied;
          Future<bool>? saveOperation;
          await tester.pumpWidget(
            ChimeraApp(
              localeTag: locale,
              initialLocation: '/lorem/generate',
              loremClipboardWriter: (v) async {
                copied = v;
              },
              loremFileSaver: (name, bytes, mime) =>
                  saveOperation = saveLocalFile(
                    name,
                    bytes,
                    mime,
                    extensions: const ['txt'],
                    chooseLocation: (_, _) async => saved.path,
                  ),
            ),
          );
          await tester.pumpAndSettle();
          Future<void> tap(String name) async {
            final finder = find.byKey(Key('lorem-$name'));
            await tester.ensureVisible(finder);
            await tester.tap(finder);
            await tester.pumpAndSettle();
          }

          if (unit != 'paragraphs') {
            await tap('unit');
            await tester.tap(
              find
                  .text(
                    unit == 'words'
                        ? (locale == 'en' ? 'Words' : 'Palavras')
                        : (locale == 'en' ? 'Sentences' : 'Frases'),
                  )
                  .last,
            );
            await tester.pumpAndSettle();
          }
          await tester.enterText(find.byKey(const Key('lorem-count')), '2');
          await tap('generate');
          final expected = unit == 'words'
              ? 'Lorem ipsum'
              : unit == 'sentences'
              ? paragraph
              : '$paragraph\n\n$paragraph';
          expect(
            tester
                .widget<SelectableText>(find.byKey(const Key('lorem-output')))
                .data,
            expected,
          );
          await tap('copy');
          expect(copied, expected);
          await tap('save');
          expect(saveOperation, isNotNull);
          expect(await saveOperation!, isTrue);
          for (
            var turn = 0;
            turn < 100 &&
                find.byKey(const Key('lorem-notice')).evaluate().isEmpty;
            turn++
          ) {
            await tester.pump(const Duration(milliseconds: 20));
          }
          expect(await saved.readAsBytes(), utf8.encode(expected));
          expect(directory.listSync().length, 1);
          await tester.ensureVisible(find.byKey(const Key('lorem-count')));
          await tester.tap(find.byKey(const Key('lorem-count')));
          await tester.pumpAndSettle();
          await tester.enterText(find.byKey(const Key('lorem-count')), '3');
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('lorem-output')), findsNothing);
          expect(find.byKey(const Key('lorem-copy')), findsNothing);
          expect(network.attempts, 0);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
    for (final failure in ['validation', 'resource', 'copy', 'save']) {
      testWidgets(
        'Given$locale${failure}Failure_WhenGeneratedOffline_ThenLocalizedErrorWithoutPartialResult',
        (tester) async {
          final network = _Offline();
          final previous = HttpOverrides.current;
          HttpOverrides.global = network;
          addTearDown(() => HttpOverrides.global = previous);
          final directory = await Directory.systemTemp.createTemp(
            'lorem-native-failure-',
          );
          addTearDown(() => directory.delete(recursive: true));
          final sentinel = File('${directory.path}/sentinel.txt');
          await sentinel.writeAsString('original');
          await tester.pumpWidget(
            ChimeraApp(
              localeTag: locale,
              initialLocation: '/lorem/generate',
              loremService: failure == 'resource'
                  ? const LoremService(
                      generator: LoremGenerator(maxOutputCharacters: 1),
                    )
                  : const LoremService(),
              loremClipboardWriter: (_) async => throw StateError('PRIVATE'),
              loremFileSaver: (name, bytes, mime) => saveLocalFile(
                name,
                bytes,
                mime,
                chooseLocation: (_, _) async =>
                    '${directory.path}/missing/result.txt',
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (failure == 'validation') {
            await tester.enterText(find.byKey(const Key('lorem-count')), '0');
          }
          await tester.tap(find.byKey(const Key('lorem-generate')));
          await tester.pumpAndSettle();
          if (failure == 'copy' || failure == 'save') {
            final button = find.byKey(Key('lorem-$failure'));
            await tester.ensureVisible(button);
            await tester.tap(button);
            await tester.pumpAndSettle();
            for (
              var turn = 0;
              turn < 100 &&
                  find.byKey(const Key('lorem-error')).evaluate().isEmpty;
              turn++
            ) {
              await tester.pump(const Duration(milliseconds: 20));
            }
          }
          final expected = locale == 'en'
              ? switch (failure) {
                  'validation' => 'Choose words, sentences or paragraphs and a positive integer count.',
                  'resource' => 'Text generation exceeded available resources.',
                  'copy' => 'The generated text could not be copied.',
                  _ => 'The generated text could not be saved or written.',
                }
              : switch (failure) {
                  'validation' => 'Escolha palavras, frases ou parágrafos e uma quantidade inteira positiva.',
                  'resource' =>
                    'A geração de texto excedeu os recursos disponíveis.',
                  'copy' => 'Não foi possível copiar o texto gerado.',
                  _ => 'Não foi possível salvar ou escrever o texto gerado.',
                };
          expect(find.text(expected), findsOneWidget);
          expect(find.byKey(const Key('lorem-output')), findsNothing);
          expect(find.byKey(const Key('lorem-copy')), findsNothing);
          expect(find.textContaining('PRIVATE'), findsNothing);
          expect(await sentinel.readAsString(), 'original');
          expect(directory.listSync().length, 1);
          expect(network.attempts, 0);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }
}

final class _Offline extends HttpOverrides {
  int attempts = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Must stay offline');
  }
}
