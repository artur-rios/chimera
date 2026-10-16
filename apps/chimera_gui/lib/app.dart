import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'cron_page.dart';
import 'router.dart';

final class ChimeraApp extends StatelessWidget {
  const ChimeraApp({
    this.localeTag = 'en',
    this.cronService = const CronService(),
    this.currentTime,
    this.cronFilePicker,
    this.initialLocation = '/',
    super.key,
  });

  final String localeTag;
  final CronService cronService;
  final DateTime Function()? currentTime;
  final CronFilePicker? cronFilePicker;
  final String initialLocation;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: _RoutedChimeraApp(
        localeTag: localeTag,
        cronService: cronService,
        currentTime: currentTime,
        cronFilePicker: cronFilePicker,
        initialLocation: initialLocation,
      ),
    );
  }
}

final class _RoutedChimeraApp extends StatefulWidget {
  const _RoutedChimeraApp({
    required this.localeTag,
    required this.cronService,
    required this.currentTime,
    required this.cronFilePicker,
    required this.initialLocation,
  });

  final String localeTag;
  final CronService cronService;
  final DateTime Function()? currentTime;
  final CronFilePicker? cronFilePicker;
  final String initialLocation;

  @override
  State<_RoutedChimeraApp> createState() => _RoutedChimeraAppState();
}

final class _RoutedChimeraAppState extends State<_RoutedChimeraApp> {
  static const MessageCatalog _catalog = MessageCatalog();
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(
      catalog: _catalog,
      localeTag: widget.localeTag,
      cronService: widget.cronService,
      currentTime: widget.currentTime ?? DateTime.now,
      cronFilePicker: widget.cronFilePicker ?? pickCronExpressionFile,
      initialLocation: widget.initialLocation,
    );
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
