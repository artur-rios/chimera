import 'dart:io';

import 'package:chimera_gui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'GivenNativeProjectForm_WhenNugetScaffolded_ThenBlankMetadataIsWrittenOffline',
    (tester) async {
      final parent = await Directory.systemTemp.createTemp(
        'chimera-dotnet-native-',
      );
      addTearDown(() => parent.delete(recursive: true));
      await tester.pumpWidget(
        const ChimeraApp(initialLocation: '/dotnet/init-project'),
      );
      await tester.enterText(
        find.byKey(const Key('dotnet-project-name')),
        'NativeExample',
      );
      await tester.enterText(
        find.byKey(const Key('dotnet-project-parent')),
        parent.path,
      );
      await tester.tap(find.byKey(const Key('dotnet-project-nuget')));
      await tester.tap(find.byKey(const Key('dotnet-project-create')));
      final project = File.fromUri(
        parent.uri.resolve('NativeExample/NativeExample.csproj'),
      );
      await tester.runAsync(() async {
        for (
          var i = 0;
          i < 200 &&
              (!project.existsSync() || project.readAsStringSync().isEmpty);
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      });
      await tester.pumpAndSettle();
      expect(project.readAsStringSync(), contains('<PackageId></PackageId>'));
      expect(project.readAsStringSync(), contains('<Version></Version>'));
      expect(find.textContaining(project.path), findsOneWidget);
    },
  );
}
