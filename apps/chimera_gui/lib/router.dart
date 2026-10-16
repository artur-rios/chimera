import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'cron_page.dart';
import 'date_page.dart';

GoRouter buildRouter({
  required MessageCatalog catalog,
  required String localeTag,
  required CronService cronService,
  required DateService dateService,
  required DateTime Function() currentTime,
  required CronFilePicker cronFilePicker,
  required DateFilePicker dateFilePicker,
  String initialLocation = '/',
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Focus(
            autofocus: true,
            child: SingleChildScrollView(
              child: Center(
                child: Semantics(
                  header: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        catalog.lookup(localeTag, 'app.name'),
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(catalog.lookup(localeTag, 'app.description')),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        key: const Key('open-cron'),
                        onPressed: () => context.go('/cron/parse'),
                        child: Text(
                          catalog.lookup(localeTag, 'cron.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-date'),
                        onPressed: () => context.go('/date/convert'),
                        child: Text(
                          catalog.lookup(localeTag, 'date.openAction'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/cron/parse',
        builder: (context, state) => CronPage(
          catalog: catalog,
          localeTag: localeTag,
          service: cronService,
          currentTime: currentTime,
          filePicker: cronFilePicker,
        ),
      ),
      GoRoute(
        path: '/date/convert',
        builder: (context, state) => DatePage(
          catalog: catalog,
          localeTag: localeTag,
          service: dateService,
          filePicker: dateFilePicker,
        ),
      ),
    ],
  );
}
