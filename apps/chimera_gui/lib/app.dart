import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';

final class ChimeraApp extends StatelessWidget {
  const ChimeraApp({this.localeTag = 'en', super.key});

  final String localeTag;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(child: _RoutedChimeraApp(localeTag: localeTag));
  }
}

final class _RoutedChimeraApp extends StatefulWidget {
  const _RoutedChimeraApp({required this.localeTag});

  final String localeTag;

  @override
  State<_RoutedChimeraApp> createState() => _RoutedChimeraAppState();
}

final class _RoutedChimeraAppState extends State<_RoutedChimeraApp> {
  static const MessageCatalog _catalog = MessageCatalog();
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(catalog: _catalog, localeTag: widget.localeTag);
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      title: _catalog.lookup(widget.localeTag, 'app.name'),
      theme: ThemeData(colorSchemeSeed: const Color(0xFF6750A4)),
    );
  }
}
