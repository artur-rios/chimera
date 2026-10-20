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
  PasswordService deterministic() => PasswordService(
    generator: PasswordGenerator.forTesting(randomInt: (_) => 0),
  );

  testWidgets(
    'GivenProductionService_WhenGeneratedNativelyOffline_ThenSecurePasswordContractHolds',
    (tester) async {
      final network = _Offline();
      final previous = HttpOverrides.current;
      HttpOverrides.global = network;
      addTearDown(() => HttpOverrides.global = previous);
      await tester.pumpWidget(
        const ChimeraApp(initialLocation: '/password/generate'),
      );
      await tester.tap(find.byKey(const Key('password-generate')));
      await tester.pumpAndSettle();

      final password = tester
          .widget<SelectableText>(find.byKey(const Key('password-output')))
          .data!;
      expect(password, hasLength(16));
      expect(password, matches(RegExp('[a-z]')));
      expect(password, matches(RegExp('[A-Z]')));
      expect(password, matches(RegExp('[0-9]')));
      expect(password, matches(RegExp(r'[!@#$%^&*()\-_=+\[\]{}:,.?]')));
      expect(network.attempts, 0);
    },
  );

  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}PasswordConstraints_WhenGeneratedOffline_ThenExactCopySaveAndDiscard',
      (tester) async {
        final network = _Offline();
        final previous = HttpOverrides.current;
        HttpOverrides.global = network;
        addTearDown(() => HttpOverrides.global = previous);
        final directory = await Directory.systemTemp.createTemp(
          'password-native-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final target = File('${directory.path}/password.txt');
        await target.writeAsString('previous');
        String? copied;
        await tester.pumpWidget(
          ChimeraApp(
            localeTag: locale,
            initialLocation: '/password/generate',
            passwordService: deterministic(),
            passwordClipboardWriter: (value) async {
              copied = value;
            },
            passwordFileSaver: (name, bytes, mime) => saveLocalFile(
              name,
              bytes,
              mime,
              extensions: const ['txt'],
              chooseLocation: (_, _) async => target.path,
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final key in ['lowercase', 'uppercase', 'symbols']) {
          await tester.ensureVisible(find.byKey(Key('password-$key')));
          await tester.tap(find.byKey(Key('password-$key')));
          await tester.pump();
        }
        await tester.enterText(find.byKey(const Key('password-length')), '8');
        await tester.tap(find.byKey(const Key('password-generate')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<SelectableText>(find.byKey(const Key('password-output')))
              .data,
          '00000000',
        );
        await tester.ensureVisible(find.byKey(const Key('password-copy')));
        await tester.tap(find.byKey(const Key('password-copy')));
        await tester.pumpAndSettle();
        expect(copied, '00000000');
        await tester.ensureVisible(find.byKey(const Key('password-save')));
        await tester.tap(find.byKey(const Key('password-save')));
        await tester.pumpAndSettle();
        expect(await target.readAsBytes(), utf8.encode('00000000'));
        expect(directory.listSync(), hasLength(1));
        final length = find.byKey(const Key('password-length'));
        await tester.ensureVisible(length);
        await tester.tap(length);
        await tester.pumpAndSettle();
        await tester.enterText(length, '9');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('password-output')), findsNothing);
        expect(network.attempts, 0);
      },
    );

    for (final failure in ['validation', 'processing']) {
      testWidgets(
        'Given$locale${failure}Failure_WhenGeneratedOffline_ThenLocalizedErrorWithoutPartialPassword',
        (tester) async {
          final network = _Offline();
          final previous = HttpOverrides.current;
          HttpOverrides.global = network;
          addTearDown(() => HttpOverrides.global = previous);
          await tester.pumpWidget(
            ChimeraApp(
              localeTag: locale,
              initialLocation: '/password/generate',
              passwordService: failure == 'processing'
                  ? PasswordService(
                      generator: PasswordGenerator.forTesting(
                        randomInt: (_) => throw StateError('PRIVATE'),
                      ),
                    )
                  : deterministic(),
            ),
          );
          await tester.pumpAndSettle();
          if (failure == 'validation') {
            await tester.enterText(
              find.byKey(const Key('password-length')),
              '3',
            );
          }
          await tester.tap(find.byKey(const Key('password-generate')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('password-error')), findsOneWidget);
          expect(find.byKey(const Key('password-output')), findsNothing);
          expect(find.textContaining('PRIVATE'), findsNothing);
          expect(network.attempts, 0);
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
