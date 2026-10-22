import 'dart:async';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_gui/type_periodic_page.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GivenHome_WhenPeriodicActionSelected_ThenOpensLocalizedRoute', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChimeraApp(
        localeTag: 'pt-BR',
        typePeriodicServiceFactory: TypePeriodicService.new,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-type-periodic')));
    await tester.pumpAndSettle();
    expect(find.text('Digitar Comandos Periódicos'), findsOneWidget);
    expect(find.byKey(const Key('type-periodic-start')), findsOneWidget);
  });
  for (final locale in ['en', 'pt-BR']) {
    testWidgets('GivenUnsupportedTarget_WhenStartedIn$locale'
        '_ThenExplainsSupport', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TypePeriodicPage(
            catalog: const MessageCatalog(),
            localeTag: locale,
            serviceFactory: TypePeriodicService.new,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('type-periodic-start')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(locale == 'en' ? 'Linux and web' : 'Linux e web'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('type-periodic-start')))
            .onPressed,
        isNotNull,
      );
    });
  }
  testWidgets('GivenRunningOperation_WhenStopped_ThenClosesAndEnablesStart', (
    tester,
  ) async {
    final terminal = Terminal();
    final wait = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: TypePeriodicPage(
          catalog: const MessageCatalog(),
          localeTag: 'en',
          serviceFactory: () => TypePeriodicService(
            terminal: terminal,
            sleep: (_) => wait.future,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('type-periodic-start')));
    await tester.pump();
    expect(terminal.launched, isTrue);
    await tester.tap(find.byKey(const Key('type-periodic-stop')));
    await tester.pumpAndSettle();
    expect(terminal.closed, isTrue);
    expect(find.textContaining('Commands sent: 0'), findsOneWidget);
  });
  testWidgets('GivenRunningOperation_WhenPageDisposed_ThenCancelsAndCloses', (
    tester,
  ) async {
    final terminal = Terminal();
    await tester.pumpWidget(
      MaterialApp(
        home: TypePeriodicPage(
          catalog: const MessageCatalog(),
          localeTag: 'en',
          serviceFactory: () => TypePeriodicService(
            terminal: terminal,
            sleep: (_) => Completer<void>().future,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('type-periodic-start')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(terminal.closed, isTrue);
  });
}

class Terminal implements PeriodicTerminal {
  bool launched = false;
  bool closed = false;
  @override
  bool get supported => true;
  @override
  Future<void> launch() async {
    launched = true;
  }

  @override
  Future<void> activate() async {}
  @override
  Future<void> sendEcho(int counter) async {}
  @override
  Future<void> close() async {
    closed = true;
  }
}
