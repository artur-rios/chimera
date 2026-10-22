import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/project_template_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'GivenNewDestination${locale}_WhenCreated_ThenSharedResultIsPresented',
      (tester) async {
        final service = _Service();
        await tester.pumpWidget(
          MaterialApp(
            home: ProjectTemplatePage(localeTag: locale, service: service),
          ),
        );
        await tester.enterText(
          find.byKey(const Key('scaffold-destination')),
          '/tmp/new-project',
        );
        await tester.tap(find.byKey(const Key('scaffold-create')));
        await tester.pumpAndSettle();
        expect(service.destination, '/tmp/new-project');
        expect(find.textContaining('/tmp/new-project'), findsWidgets);
        expect(find.textContaining('snapshot-v1'), findsOneWidget);
      },
    );
    testWidgets(
      'GivenUnsupportedTarget${locale}_WhenCreated_ThenLocalizedFailure',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            MaterialApp(
              home: ProjectTemplatePage(
                localeTag: locale,
                service: const UnsupportedScaffoldService(),
              ),
            ),
          );
          await tester.enterText(
            find.byKey(const Key('scaffold-destination')),
            'new',
          );
          await tester.tap(find.byKey(const Key('scaffold-create')));
          await tester.pumpAndSettle();
          expect(
            find.textContaining(locale == 'en' ? 'available in' : 'disponível'),
            findsOneWidget,
          );
          final status = find.semantics.byLabel(
            locale == 'en'
                ? 'Project creation is available in the Windows and Linux desktop and CLI applications.'
                : 'A criação de projetos está disponível nos aplicativos desktop e CLI para Windows e Linux.',
          );
          expect(status, findsOne);
          expect(
            status.evaluate().single,
            isSemantics(isLiveRegion: true, isTextField: false),
          );
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}

final class _Service implements ScaffoldOperationService {
  String? destination;
  @override
  Future<ChimeraResult<ScaffoldOutput>> execute(ScaffoldRequest request) async {
    destination = request.destination;
    return ChimeraSuccess(
      ScaffoldOutput(
        destination: request.destination,
        templateVersion: 'snapshot-v1',
        createdPaths: ['README.md'],
      ),
    );
  }
}
