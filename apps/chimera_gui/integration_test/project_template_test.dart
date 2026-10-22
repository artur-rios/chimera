import 'dart:io';

import 'package:chimera_gui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'GivenNativeDestination${locale}_WhenProjectCreated_ThenOfflineTreeAndConflictAreVisible',
      (tester) async {
        final parent = await Directory.systemTemp.createTemp(
          'chimera-template-native-',
        );
        addTearDown(() => parent.delete(recursive: true));
        final destination = '${parent.path}/new';
        await tester.pumpWidget(
          ChimeraApp(
            localeTag: locale,
            initialLocation: '/project/from-template',
          ),
        );
        await tester.enterText(
          find.byKey(const Key('scaffold-destination')),
          destination,
        );
        await tester.tap(find.byKey(const Key('scaffold-create')));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          for (
            var i = 0;
            i < 200 && !File('$destination/tests/.gitkeep').existsSync();
            i++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 25));
          }
        });
        await tester.pumpAndSettle();
        expect(File('$destination/.editorconfig').existsSync(), isTrue);
        expect(File('$destination/src/.gitkeep').existsSync(), isTrue);
        expect(find.textContaining('b4921f53'), findsOneWidget);
        await tester.tap(find.byKey(const Key('scaffold-create')));
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining(locale == 'en' ? 'already exists' : 'já existe'),
          findsOneWidget,
        );
        expect(File('$destination/.editorconfig').existsSync(), isTrue);
      },
    );
  }
}
