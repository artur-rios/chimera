import 'dart:io';

import 'package:chimera_gui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'GivenNativeProject_WhenTagCreated_ThenAnnotatedLocalTagAndNoPush',
    (tester) async {
      final root = await Directory.systemTemp.createTemp('chimera-tag-native-');
      addTearDown(() => root.delete(recursive: true));
      Directory('${root.path}/src').createSync();
      File('${root.path}/src/Library.csproj').writeAsStringSync(
        '<Project><PropertyGroup><Version>1.2.3</Version></PropertyGroup></Project>',
      );
      await tester.runAsync(() async {
        for (final args in [
          ['init'],
          ['config', 'user.name', 'Chimera Tests'],
          ['config', 'user.email', 'chimera@example.invalid'],
          ['add', '.'],
          ['commit', '-m', 'initial'],
        ]) {
          final result = await Process.run(
            'git',
            args,
            workingDirectory: root.path,
          );
          expect(result.exitCode, 0, reason: result.stderr.toString());
        }
      });
      await tester.pumpWidget(const ChimeraApp(initialLocation: '/dotnet/tag'));
      await tester.enterText(
        find.byKey(const Key('dotnet-tag-project')),
        '${root.path}/src',
      );
      await tester.tap(find.byKey(const Key('dotnet-tag-create')));
      await tester.runAsync(() async {
        for (var i = 0; i < 200; i++) {
          final exists = await Process.run('git', [
            'show-ref',
            '--verify',
            '--quiet',
            'refs/tags/v1.2.3',
          ], workingDirectory: root.path);
          if (exists.exitCode == 0) break;
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('v1.2.3'), findsOneWidget);
      await tester.runAsync(() async {
        final type = await Process.run('git', [
          'cat-file',
          '-t',
          'refs/tags/v1.2.3',
        ], workingDirectory: root.path);
        expect(type.stdout.toString().trim(), 'tag');
      });
    },
  );
}
