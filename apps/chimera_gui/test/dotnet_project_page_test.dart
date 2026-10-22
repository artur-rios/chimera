import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/dotnet_project_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'GivenProjectForm${locale}_WhenSubmitted_ThenSharedServiceAndSelectedModeAreUsed',
      (tester) async {
        final service = _Service();
        await tester.pumpWidget(
          MaterialApp(
            home: DotnetProjectPage(localeTag: locale, service: service),
          ),
        );
        await tester.enterText(
          find.byKey(const Key('dotnet-project-name')),
          'Example',
        );
        await tester.enterText(
          find.byKey(const Key('dotnet-project-parent')),
          '/tmp',
        );
        await tester.tap(find.byKey(const Key('dotnet-project-nuget')));
        await tester.tap(find.byKey(const Key('dotnet-project-create')));
        await tester.pumpAndSettle();
        expect(service.request!.name, 'Example');
        expect(service.request!.nuget, isTrue);
        if (locale == 'pt-BR') {
          expect(
            find.textContaining('\nProjeto NuGet (metadados vazios)'),
            findsOneWidget,
          );
        }
        expect(
          find.textContaining('/tmp/Example/Example.csproj'),
          findsOneWidget,
        );
      },
    );
    testWidgets(
      'GivenUnsupportedTarget${locale}_WhenSubmitted_ThenLocalizedExplanation',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: DotnetProjectPage(
              localeTag: locale,
              service: const UnsupportedDotnetProjectService(),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('dotnet-project-create')));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(locale == 'en' ? 'available in' : 'disponível'),
          findsOneWidget,
        );
      },
    );
  }
}

final class _Service implements DotnetProjectOperationService {
  DotnetProjectRequest? request;
  @override
  Future<ChimeraResult<DotnetProjectOutput>> execute(
    DotnetProjectRequest value,
  ) async {
    request = value;
    return const ChimeraSuccess(
      DotnetProjectOutput(
        mode: 'nuget',
        scaffold: ScaffoldOutput(
          destination: '/tmp/Example',
          templateVersion: 'v1',
          createdPaths: ['/tmp/Example/Example.csproj'],
        ),
      ),
    );
  }
}
