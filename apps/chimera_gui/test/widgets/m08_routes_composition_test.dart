import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_gui/dotnet_build_page.dart';
import 'package:chimera_gui/dotnet_bump_page.dart';
import 'package:chimera_gui/dotnet_clean_page.dart';
import 'package:chimera_gui/dotnet_library_page.dart';
import 'package:chimera_gui/dotnet_project_page.dart';
import 'package:chimera_gui/dotnet_tag_page.dart';
import 'package:chimera_gui/dotnet_test_page.dart';
import 'package:chimera_gui/minimal_library_page.dart';
import 'package:chimera_gui/project_template_page.dart';
import 'package:chimera_gui/type_periodic_page.dart';
import 'package:chimera_platform/chimera_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GivenComposedBranches_WhenHomeOpened_ThenAllTenEntriesExist', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChimeraApp(localeTag: 'en', preferenceGateway: _MemoryGateway()),
    );
    await tester.pumpAndSettle();
    for (final key in <String>[
      'open-project-template',
      'open-type-periodic',
      'open-dotnet-build',
      'open-dotnet-clean',
      'open-dotnet-test',
      'open-dotnet-bump',
      'open-dotnet-tag',
      'open-dotnet-library',
      'open-dotnet-init-min',
      'open-dotnet-project',
    ]) {
      expect(find.byKey(Key(key), skipOffstage: false), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'GivenComposedBranches_WhenOpeningProjectTemplatePage_ThenRouteResolves',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/project/from-template',
          localeTag: 'en',
          preferenceGateway: _MemoryGateway(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProjectTemplatePage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'GivenComposedBranches_WhenOpeningTypePeriodicPage_ThenRouteResolves',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/terminal/type-periodic',
          localeTag: 'en',
          preferenceGateway: _MemoryGateway(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TypePeriodicPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'GivenComposedBranches_WhenOpeningDotnetBuildPage_ThenRouteResolves',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/dotnet/build',
          localeTag: 'en',
          preferenceGateway: _MemoryGateway(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DotnetBuildPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'GivenComposedBranches_WhenOpeningDotnetCleanPage_ThenRouteResolves',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/dotnet/clean',
          localeTag: 'en',
          preferenceGateway: _MemoryGateway(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DotnetCleanPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'GivenComposedBranches_WhenOpeningDotnetTestPage_ThenRouteResolves',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/dotnet/test',
          localeTag: 'en',
          preferenceGateway: _MemoryGateway(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DotnetTestPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'GivenComposedBranches_WhenOpeningDotnetBumpPage_ThenRouteResolves',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/dotnet/bump',
          localeTag: 'en',
          preferenceGateway: _MemoryGateway(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DotnetBumpPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'GivenComposedBranches_WhenOpeningDotnetTagPage_ThenRouteResolves',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/dotnet/tag',
          localeTag: 'en',
          preferenceGateway: _MemoryGateway(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DotnetTagPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'GivenComposedBranches_WhenOpeningDotnetLibraryPage_ThenRouteResolves',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/dotnet/init-lib',
          localeTag: 'en',
          preferenceGateway: _MemoryGateway(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DotnetLibraryPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'GivenComposedBranches_WhenOpeningMinimalLibraryPage_ThenRouteResolves',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/dotnet/init-min',
          localeTag: 'en',
          preferenceGateway: _MemoryGateway(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MinimalLibraryPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'GivenComposedBranches_WhenOpeningDotnetProjectPage_ThenRouteResolves',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/dotnet/init-project',
          localeTag: 'en',
          preferenceGateway: _MemoryGateway(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DotnetProjectPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

final class _MemoryGateway implements PreferenceGateway {
  @override
  Future<ChimeraResult<String?>> read(PreferenceKey key) async =>
      const ChimeraSuccess<String?>(null);
  @override
  Future<ChimeraResult<void>> write(PreferenceKey key, String value) async =>
      const ChimeraSuccess<void>(null);
}
