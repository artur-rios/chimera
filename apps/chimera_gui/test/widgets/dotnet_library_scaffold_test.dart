import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_gui/dotnet_library_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'GivenHome_WhenNugetLibraryActionSelected_ThenOpensLocalizedRoute',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(localeTag: 'pt-BR', dotnetLibraryScaffoldService: Service()),
      );
      await tester.pumpAndSettle();
      final action = find.byKey(const Key('open-dotnet-library'));
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('Criar Biblioteca NuGet'), findsOneWidget);
      expect(find.byKey(const Key('dotnet-library-create')), findsOneWidget);
    },
  );
  testWidgets('GivenCompleteFields_WhenCreated_ThenSubmitsAllCanonicalValues', (
    tester,
  ) async {
    final service = Service();
    final fields = {
      'RootFolder': 'new',
      'SolutionName': 'Example',
      'ProjectName': 'Example.Library',
      'Author': 'Jane Doe',
      'Company': 'Example Co',
      'Description': 'Example library',
      'Version': '1.0.0',
      'PackageId': 'Example.Library',
      'RepositoryUrl': 'https://example.com/repository',
    };
    await tester.pumpWidget(
      MaterialApp(home: DotnetLibraryPage(service: service)),
    );
    for (final entry in fields.entries) {
      final field = find.byKey(Key('dotnet-library-${entry.key}'));
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.value);
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final create = find.byKey(const Key('dotnet-library-create'));
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(service.request!.fields, fields);
    expect(service.request!.parametersJson, isNull);
  });
  for (final locale in ['en', 'pt-BR']) {
    testWidgets('GivenIncompleteFields_WhenCreateIn$locale'
        '_ThenShowsFieldErrors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DotnetLibraryPage(
            localeTag: locale,
            service: NugetLibraryScaffoldService(Writer()),
          ),
        ),
      );
      final create = find.byKey(const Key('dotnet-library-create'));
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(
        find.text(
          locale == 'en'
              ? 'Review this required field.'
              : 'Revise este campo obrigatório.',
        ),
        findsWidgets,
      );
    });
  }
  testWidgets(
    'GivenParameterFile_WhenCreated_ThenSendsOnlyJsonAndReportsPaths',
    (tester) async {
      final service = Service();
      final json = jsonEncode({'RootFolder': 'new'});
      await tester.pumpWidget(
        MaterialApp(
          home: DotnetLibraryPage(
            service: service,
            parameterPicker: () async => json,
          ),
        ),
      );
      await tester.tap(find.text('JSON file'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dotnet-library-pick-json')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dotnet-library-create')));
      await tester.pumpAndSettle();
      expect(service.request!.parametersJson, json);
      expect(service.request!.fields, isEmpty);
      expect(find.textContaining('src/Example.sln'), findsOneWidget);
      await tester.ensureVisible(find.textContaining('src/Example.sln'));
      await tester.pumpAndSettle();
      final status = find.semantics.byLabel(RegExp(r'src/Example\.sln'));
      expect(status, findsOne);
      expect(
        status.evaluate().single,
        isSemantics(isLiveRegion: true, isTextField: false),
      );
    },
  );
  testWidgets(
    'GivenUnsupportedSurface_WhenCreating_ThenShowsTypedExplanation',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DotnetLibraryPage(service: UnsupportedDotnetScaffoldService()),
        ),
      );
      final create = find.byKey(const Key('dotnet-library-create'));
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(find.textContaining('native'), findsWidgets);
    },
  );
}

class Writer implements ScaffoldWriter {
  @override
  Future<ChimeraResult<ScaffoldOutput>> write(
    ScaffoldRequest request,
    TemplateBundle template,
  ) async => throw StateError('should not write invalid metadata');
}

class Service implements DotnetScaffoldOperationService {
  DotnetScaffoldRequest? request;
  @override
  Future<ChimeraResult<ScaffoldOutput>> execute(
    DotnetScaffoldRequest value,
  ) async {
    request = value;
    return const ChimeraSuccess(
      ScaffoldOutput(
        destination: 'new',
        templateVersion: 'v1',
        createdPaths: ['src/Example.sln'],
      ),
    );
  }
}
