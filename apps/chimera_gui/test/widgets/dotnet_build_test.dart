import 'dart:async';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/dotnet_build_page.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'GivenNativeBuild${locale}_WhenSubmitted_ThenSharedDefaultsAndAccessibleDiagnostics',
      (tester) async {
        DotnetBuildRequest? request;
        final done = Completer<ChimeraResult<DotnetBuildOutput>>();
        OperationCancellation? token;
        await tester.pumpWidget(
          MaterialApp(
            home: DotnetBuildPage(
              catalog: const MessageCatalog(),
              localeTag: locale,
              supported: true,
              builder: (value, {cancellation, onDiagnostic}) {
                request = value;
                token = cancellation;
                onDiagnostic?.call('building\n');
                return done.future;
              },
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('dotnet-build')));
        await tester.pump();
        expect(request!.sourceDirectory, './src');
        expect(request!.configuration, isNull);
        expect(request!.noRestore, isFalse);
        expect(find.text('building\n'), findsOneWidget);
        await tester.tap(find.byKey(const Key('dotnet-cancel')));
        expect(token!.isCancelled, true);
        done.complete(
          const ChimeraFailure(
            kind: FailureKind.processing,
            code: 'dotnet.cancelled',
            messageKey: 'error.dotnet.cancelled',
          ),
        );
        await tester.pumpAndSettle();
        final cancellation = locale == 'en'
            ? 'The build was cancelled.'
            : 'A compilação foi cancelada.';
        expect(find.text(cancellation), findsOneWidget);
        final status = find.semantics.byLabel(cancellation);
        expect(status, findsOne);
        expect(
          status.evaluate().single,
          isSemantics(isLiveRegion: true, isTextField: false),
        );
        final diagnostics = find.semantics.byLabel('building\n');
        expect(diagnostics, findsOne);
        expect(diagnostics.evaluate().single, isSemantics(isTextField: false));
      },
    );
  }
  testWidgets('GivenWeb_WhenPage_ThenExplicitUnsupportedAndDisabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DotnetBuildPage(
          catalog: MessageCatalog(),
          localeTag: 'pt-BR',
          supported: false,
        ),
      ),
    );
    expect(find.textContaining('Indisponível na web'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const Key('dotnet-build')))
          .onPressed,
      isNull,
    );
  });
}
