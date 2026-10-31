import 'dart:async';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_gui/update_page.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'GivenNativeUpdatesEnabled_WhenHomeActionActivated_ThenUpdatePageOpens',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          updateChecksEnabled: true,
          updateChecker: () async => ChimeraSuccess<UpdateCheckResult>(
            UpdateCheckResult.current(SemanticVersion.parse('1.0.0')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final action = find.byKey(const Key('open-update-check'));
      expect(action, findsOneWidget);
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('update-check-action')), findsOneWidget);
      expect(find.text('Check for updates'), findsWidgets);
    },
  );

  testWidgets('GivenCurrentVersion_WhenChecked_ThenCurrentStatusIsAnnounced', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      checker: () async => ChimeraSuccess<UpdateCheckResult>(
        UpdateCheckResult.current(SemanticVersion.parse('1.2.3')),
      ),
    );

    await tester.tap(find.byKey(const Key('update-check-action')));
    await tester.pumpAndSettle();

    expect(find.text('Chimera 1.2.3 is current.'), findsOneWidget);
    final status = tester.widget<Semantics>(
      find.byKey(const Key('update-check-status')),
    );
    expect(status.properties.liveRegion, isTrue);
  });

  testWidgets(
    'GivenCompatibleNewerVersion_WhenChecked_ThenAvailableStatusRequiresApproval',
    (tester) async {
      await _pumpPage(
        tester,
        checker: () async => ChimeraSuccess<UpdateCheckResult>(
          UpdateCheckResult.available(
            SemanticVersion.parse('1.2.3'),
            _release('2.0.0'),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('update-check-action')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Chimera 2.0.0 is available (installed: 1.2.3, package: installer, '
          'SHA-256: ${'a' * 64}). Approval is required before downloading.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GivenUpdateFailure_WhenChecked_ThenSafeLocalizedFailureIsAnnounced',
    (tester) async {
      await _pumpPage(
        tester,
        checker: () async => const ChimeraFailure<UpdateCheckResult>(
          kind: FailureKind.update,
          code: 'release-metadata-source-failed',
          messageKey: 'error.update.checkFailed',
        ),
      );

      await tester.tap(find.byKey(const Key('update-check-action')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'The update check failed. The installed version can continue running.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GivenPreviousResult_WhenAnotherCheckStarts_ThenStaleStatusIsCleared',
    (tester) async {
      final second = Completer<ChimeraResult<UpdateCheckResult>>();
      var calls = 0;
      await _pumpPage(
        tester,
        checker: () {
          calls++;
          if (calls == 1) {
            return Future.value(
              ChimeraSuccess<UpdateCheckResult>(
                UpdateCheckResult.current(SemanticVersion.parse('1.2.3')),
              ),
            );
          }
          return second.future;
        },
      );
      final action = find.byKey(const Key('update-check-action'));
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('Chimera 1.2.3 is current.'), findsOneWidget);

      await tester.tap(action);
      await tester.pump();

      expect(find.text('Chimera 1.2.3 is current.'), findsNothing);
      expect(find.byKey(const Key('update-check-progress')), findsOneWidget);
      second.complete(
        ChimeraSuccess<UpdateCheckResult>(
          UpdateCheckResult.current(SemanticVersion.parse('1.2.3')),
        ),
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'GivenBrazilianPortuguese_WhenChecked_ThenPageAndResultAreLocalized',
    (tester) async {
      await _pumpPage(
        tester,
        localeTag: 'pt-BR',
        checker: () async => ChimeraSuccess<UpdateCheckResult>(
          UpdateCheckResult.current(SemanticVersion.parse('1.2.3')),
        ),
      );

      expect(find.text('Verificar atualizações'), findsWidgets);
      await tester.tap(find.byKey(const Key('update-check-action')));
      await tester.pumpAndSettle();

      expect(find.text('O Chimera 1.2.3 está atualizado.'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenAvailableUpdate_WhenApplyConfirmationIsCancelled_ThenNoApplyOccurs',
    (tester) async {
      var applyCalls = 0;
      await _pumpPage(
        tester,
        checker: () async => ChimeraSuccess<UpdateCheckResult>(
          UpdateCheckResult.available(
            SemanticVersion.parse('1.2.3'),
            _release('2.0.0'),
          ),
        ),
        applier: (release) async {
          applyCalls++;
          return ChimeraSuccess<UpdateApplyResult>(
            UpdateApplyResult(release: release, restartRequired: true),
          );
        },
      );
      await tester.tap(find.byKey(const Key('update-check-action')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('update-apply-action')));
      await tester.pumpAndSettle();
      expect(find.text('Install Chimera 2.0.0?'), findsOneWidget);
      expect(find.textContaining('installer package'), findsOneWidget);
      expect(find.textContaining('a' * 64), findsWidgets);
      await tester.tap(find.byKey(const Key('update-apply-cancel')));
      await tester.pumpAndSettle();

      expect(applyCalls, 0);
    },
  );

  testWidgets(
    'GivenConfirmedUpdate_WhenApplySucceeds_ThenRestartStatusIsAnnounced',
    (tester) async {
      final pending = Completer<ChimeraResult<UpdateApplyResult>>();
      await _pumpPage(
        tester,
        checker: () async => ChimeraSuccess<UpdateCheckResult>(
          UpdateCheckResult.available(
            SemanticVersion.parse('1.2.3'),
            _release('2.0.0'),
          ),
        ),
        applier: (_) => pending.future,
      );
      await tester.tap(find.byKey(const Key('update-check-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('update-apply-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('update-apply-confirm')));
      await tester.pump();

      expect(find.byKey(const Key('update-apply-progress')), findsOneWidget);
      pending.complete(
        ChimeraSuccess<UpdateApplyResult>(
          UpdateApplyResult(
            release: _release('2.0.0'),
            restartRequired: true,
            status: UpdateApplyStatus.scheduled,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Chimera 2.0.0 is ready to install. Exit and reopen the application '
          'to complete the update.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('update-apply-action')), findsNothing);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const Key('update-check-action')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'GivenConfirmedUpdate_WhenApplyFails_ThenInstalledVersionSafeStatusIsAnnounced',
    (tester) async {
      await _pumpPage(
        tester,
        localeTag: 'pt-BR',
        checker: () async => ChimeraSuccess<UpdateCheckResult>(
          UpdateCheckResult.available(
            SemanticVersion.parse('1.2.3'),
            _release('2.0.0'),
          ),
        ),
        applier: (_) async => const ChimeraFailure<UpdateApplyResult>(
          kind: FailureKind.update,
          code: 'update-install-failed',
          messageKey: 'error.update.installFailed',
        ),
      );
      await tester.tap(find.byKey(const Key('update-check-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('update-apply-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('update-apply-confirm')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Não foi possível instalar a atualização. A versão instalada continua disponível.',
        ),
        findsOneWidget,
      );
    },
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required UpdateCheckCallback checker,
  UpdateApplyCallback? applier,
  String localeTag = 'en',
}) => tester.pumpWidget(
  MaterialApp(
    home: UpdatePage(
      catalog: const MessageCatalog(),
      localeTag: localeTag,
      checker: checker,
      applier: applier,
    ),
  ),
);

ReleaseMetadata _release(String version) => ReleaseMetadata(
  releaseVersion: SemanticVersion.parse(version),
  platform: ReleasePlatform.windows,
  application: ReleaseApplication.desktop,
  packageType: ReleasePackageType.installer,
  downloadUrl: Uri.parse(
    'https://github.com/artur-rios/chimera/releases/download/v$version/'
    'chimera-desktop-windows-x64-installer.exe',
  ),
  checksum: 'a' * 64,
);
