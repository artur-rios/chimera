import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/dotnet_bump_page.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Service
    implements OperationService<DotnetBumpRequest, DotnetBumpOutput> {
  DotnetBumpRequest? request;
  ChimeraResult<DotnetBumpOutput> result = const ChimeraSuccess(
    DotnetBumpOutput(
      project: '/src/App.csproj',
      previousVersion: '1.2.3',
      version: '2.0.0',
    ),
  );
  @override
  Future<ChimeraResult<DotnetBumpOutput>> execute(
    DotnetBumpRequest request,
  ) async {
    this.request = request;
    return result;
  }
}

void main() {
  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given$locale explicit version_WhenApplied_ThenSharedRequestAndOldNewDisplayed',
      (tester) async {
        final service = _Service();
        await tester.pumpWidget(
          MaterialApp(
            home: DotnetBumpPage(
              catalog: const MessageCatalog(),
              localeTag: locale,
              service: service,
            ),
          ),
        );
        await tester.enterText(
          find.byKey(const Key('dotnet-bump-project')),
          '/src/App.csproj',
        );
        await tester.enterText(
          find.byKey(const Key('dotnet-bump-version')),
          '2.0.0',
        );
        await tester.tap(find.byKey(const Key('dotnet-bump-apply')));
        await tester.pumpAndSettle();
        expect(service.request?.project, '/src/App.csproj');
        expect(service.request?.version, '2.0.0');
        expect(service.request?.increment, isNull);
        expect(find.textContaining('1.2.3'), findsOneWidget);
        expect(find.textContaining('1.2.3 → 2.0.0'), findsOneWidget);
      },
    );
  }
  testWidgets('GivenIncrementMode_WhenApplied_ThenMutuallyExclusiveRequest', (
    tester,
  ) async {
    final service = _Service();
    await tester.pumpWidget(
      MaterialApp(
        home: DotnetBumpPage(
          catalog: const MessageCatalog(),
          localeTag: 'en',
          service: service,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('dotnet-bump-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Increment patch').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dotnet-bump-apply')));
    await tester.pumpAndSettle();
    expect(service.request?.increment, 'patch');
    expect(service.request?.version, isNull);
  });
  testWidgets(
    'GivenTransactionFailure_WhenApplied_ThenBackupAndRecoveryStatusVisible',
    (tester) async {
      final service = _Service()
        ..result = const ChimeraFailure(
          kind: FailureKind.access,
          code: 'dotnet-bump-transaction-failed',
          messageKey: 'dotnetBump.transactionFailed',
          details: {'backupPath': '/src/backup', 'restored': false},
        );
      await tester.pumpWidget(
        MaterialApp(
          home: DotnetBumpPage(
            catalog: const MessageCatalog(),
            localeTag: 'en',
            service: service,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('dotnet-bump-apply')));
      await tester.pumpAndSettle();
      expect(find.textContaining('/src/backup'), findsOneWidget);
      expect(find.textContaining('Recover the original'), findsOneWidget);
    },
  );
  testWidgets(
    'GivenUnsupportedTarget_WhenOpened_ThenNativeOnlyMessageAndNoWriteAction',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DotnetBumpPage(
            catalog: MessageCatalog(),
            localeTag: 'en',
            supported: false,
          ),
        ),
      );
      expect(find.textContaining('Windows and Linux'), findsOneWidget);
      expect(find.byKey(const Key('dotnet-bump-apply')), findsNothing);
    },
  );
}
