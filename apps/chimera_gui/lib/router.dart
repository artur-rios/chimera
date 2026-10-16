import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

GoRouter buildRouter({
  required MessageCatalog catalog,
  required String localeTag,
}) {
  return GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Focus(
            autofocus: true,
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
