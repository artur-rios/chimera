import 'dart:async';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/dotnet_test_page.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'GivenNativeTests_WhenSubmitted_ThenDefaultRequestAndCancellation',
    (tester) async {
      DotnetTestRequest? request;
      OperationCancellation? token;
      final done = Completer<ChimeraResult<DotnetTestOutput>>();
      await tester.pumpWidget(
        MaterialApp(
          home: DotnetTestPage(
            catalog: const MessageCatalog(),
            localeTag: 'en',
            supported: true,
            tester: (value, {cancellation, onDiagnostic}) {
              request = value;
              token = cancellation;
              onDiagnostic?.call('testing');
              return done.future;
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('dotnet-test')));
      await tester.pump();
      expect(request!.baseDirectory, isNull);
      expect(find.text('testing'), findsOneWidget);
      await tester.tap(find.byKey(const Key('dotnet-test-cancel')));
      expect(token!.isCancelled, true);
      done.complete(
        const ChimeraSuccess(
          DotnetTestOutput(
            resultsDirectory: '/tests/TestResults',
            reportDirectory: '/docs/coverage-report',
            projectsTested: 0,
            noTests: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('No test projects found. No external tools were invoked.'),
        findsOneWidget,
      );
    },
  );
  testWidgets('GivenWeb_WhenTestPage_ThenUnsupported', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DotnetTestPage(
          catalog: MessageCatalog(),
          localeTag: 'pt-BR',
          supported: false,
        ),
      ),
    );
    expect(find.textContaining('Indisponível na web'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const Key('dotnet-test')))
          .onPressed,
      isNull,
    );
  });
}
