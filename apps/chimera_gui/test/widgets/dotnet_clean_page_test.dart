import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/dotnet_clean_page.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Gateway implements DotnetCleanGateway {
  final deleted = <String>[];
  @override
  Future<String> resolveRoot(String? root) async => '/selected/src';
  @override
  Future<List<String>> discover(String root) async => ['$root/Project/bin'];
  @override
  Future<void> validateRoot(String root) async {}
  @override
  Future<void> deleteArtifact(String root, String path) async {
    deleted.add(path);
  }
}

void main() {
  for (final locale in ['en', 'pt-BR']) {
    testWidgets('Given$locale scope_WhenPreviewAndCancel_ThenNoDeletion', (
      tester,
    ) async {
      final gateway = _Gateway();
      await tester.pumpWidget(
        MaterialApp(
          home: DotnetCleanPage(
            catalog: const MessageCatalog(),
            localeTag: locale,
            service: DotnetCleanService(gateway),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('dotnet-clean-preview')));
      await tester.pumpAndSettle();
      expect(find.textContaining('/selected/src/Project/bin'), findsOneWidget);
      expect(gateway.deleted, isEmpty);
      await tester.tap(find.byKey(const Key('dotnet-clean-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dotnet-clean-cancel')));
      await tester.pumpAndSettle();
      expect(gateway.deleted, isEmpty);
      await tester.tap(find.byKey(const Key('dotnet-clean-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dotnet-clean-confirm')));
      await tester.pumpAndSettle();
      expect(gateway.deleted, ['/selected/src/Project/bin']);
      expect(find.byKey(const Key('dotnet-clean-delete')), findsNothing);
    });
  }
  testWidgets(
    'GivenChangedRoot_WhenEdited_ThenPreviousPreviewCannotBeDeleted',
    (tester) async {
      final gateway = _Gateway();
      await tester.pumpWidget(
        MaterialApp(
          home: DotnetCleanPage(
            catalog: const MessageCatalog(),
            localeTag: 'en',
            service: DotnetCleanService(gateway),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('dotnet-clean-preview')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('dotnet-clean-root')),
        '/other',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dotnet-clean-delete')), findsNothing);
      expect(gateway.deleted, isEmpty);
    },
  );
  testWidgets('GivenUnsupportedTarget_WhenOpened_ThenNoFilesystemAction', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DotnetCleanPage(
          catalog: MessageCatalog(),
          localeTag: 'en',
          supported: false,
        ),
      ),
    );
    expect(find.textContaining('Windows and Linux'), findsOneWidget);
    expect(find.byKey(const Key('dotnet-clean-preview')), findsNothing);
  });
}
