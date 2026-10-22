import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/minimal_library_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class Service implements DotnetScaffoldOperationService {
  DotnetScaffoldRequest? request;
  @override
  Future<ChimeraResult<ScaffoldOutput>> execute(
    DotnetScaffoldRequest value,
  ) async {
    request = value;
    return const ChimeraSuccess(
      ScaffoldOutput(
        destination: '/new',
        templateVersion: 'pinned',
        createdPaths: ['/new/README.md'],
      ),
    );
  }
}

void main() {
  testWidgets(
    'GivenFailedReplacementJson_WhenCreate_ThenCannotSubmitPreviousParameters',
    (tester) async {
      var selections = 0;
      final service = Service();
      await tester.pumpWidget(
        MaterialApp(
          home: MinimalLibraryPage(
            service: service,
            supported: true,
            parametersPicker: () async {
              if (++selections == 1) {
                return '{"RootFolder":"/old-destination"}';
              }
              throw const FormatException('Unreadable replacement');
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('dotnet-minimal-json-mode')));
      await tester.pumpAndSettle();
      final load = find.byKey(const Key('dotnet-minimal-load-parameters'));
      await tester.tap(load);
      await tester.pumpAndSettle();
      await tester.tap(load);
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be read'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('dotnet-minimal-create')),
            )
            .onPressed,
        isNull,
      );
      expect(service.request, isNull);
    },
  );
  testWidgets('GivenFields_WhenCreate_ThenSharedRequestAndLocalizedResult', (
    tester,
  ) async {
    final service = Service();
    await tester.pumpWidget(
      MaterialApp(
        home: MinimalLibraryPage(
          service: service,
          supported: true,
          localeTag: 'pt-BR',
        ),
      ),
    );
    for (final entry in {
      'RootFolder': '/new',
      'SolutionName': 'Example',
      'ProjectName': 'Example.Library',
      'Author': 'Jane Doe',
      'Description': 'Library',
    }.entries) {
      await tester.enterText(
        find.byKey(Key('dotnet-minimal-${entry.key}')),
        entry.value,
      );
    }
    await tester.ensureVisible(find.byKey(const Key('dotnet-minimal-create')));
    await tester.tap(find.byKey(const Key('dotnet-minimal-create')));
    await tester.pumpAndSettle();
    expect(service.request!.fields['ProjectName'], 'Example.Library');
    expect(service.request!.parametersJson, isNull);
    expect(find.textContaining('Repositório mínimo criado'), findsOneWidget);
  });
  testWidgets('GivenJsonFileMode_WhenCreate_ThenOnlyJsonIsPassed', (
    tester,
  ) async {
    final service = Service();
    final json = jsonEncode({'RootFolder': '/new'});
    await tester.pumpWidget(
      MaterialApp(
        home: MinimalLibraryPage(
          service: service,
          supported: true,
          parametersPicker: () async => json,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('dotnet-minimal-json-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dotnet-minimal-load-parameters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dotnet-minimal-create')));
    await tester.pumpAndSettle();
    expect(service.request!.fields, isEmpty);
    expect(service.request!.parametersJson, json);
  });
  testWidgets('GivenWeb_WhenPageOpened_ThenExplicitUnsupportedAndDisabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: MinimalLibraryPage(supported: false)),
    );
    expect(find.textContaining('web'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('dotnet-minimal-create')))
          .onPressed,
      isNull,
    );
  });
}
