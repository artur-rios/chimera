import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'cron_page.dart';
import 'date_page.dart';
import 'json_csv_page.dart';
import 'json_table_page.dart';
import 'router.dart';

final class ChimeraApp extends StatelessWidget {
  const ChimeraApp({
    this.localeTag = 'en',
    this.cronService = const CronService(),
    this.dateService = const DateService(),
    this.jsonCsvService = const JsonCsvService(
      converter: JsonCsvConverter(maxCells: 10000),
    ),
    this.jsonTableService = const JsonTableService(
      converter: JsonTableConverter(maxCells: 10000),
    ),
    this.currentTime,
    this.cronFilePicker,
    this.dateFilePicker,
    this.jsonCsvFilePicker,
    this.jsonCsvFileSaver,
    this.jsonTableFilePicker,
    this.initialLocation = '/',
    super.key,
  });

  final String localeTag;
  final CronService cronService;
  final DateService dateService;
  final JsonCsvService jsonCsvService;
  final JsonTableService jsonTableService;
  final DateTime Function()? currentTime;
  final CronFilePicker? cronFilePicker;
  final DateFilePicker? dateFilePicker;
  final JsonCsvFilePicker? jsonCsvFilePicker;
  final JsonCsvFileSaver? jsonCsvFileSaver;
  final JsonTableFilePicker? jsonTableFilePicker;
  final String initialLocation;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: _RoutedChimeraApp(
        localeTag: localeTag,
        cronService: cronService,
        dateService: dateService,
        jsonCsvService: jsonCsvService,
        jsonTableService: jsonTableService,
        currentTime: currentTime,
        cronFilePicker: cronFilePicker,
        dateFilePicker: dateFilePicker,
        jsonCsvFilePicker: jsonCsvFilePicker,
        jsonCsvFileSaver: jsonCsvFileSaver,
        jsonTableFilePicker: jsonTableFilePicker,
        initialLocation: initialLocation,
      ),
    );
  }
}

final class _RoutedChimeraApp extends StatefulWidget {
  const _RoutedChimeraApp({
    required this.localeTag,
    required this.cronService,
    required this.dateService,
    required this.jsonCsvService,
    required this.jsonTableService,
    required this.currentTime,
    required this.cronFilePicker,
    required this.dateFilePicker,
    required this.jsonCsvFilePicker,
    required this.jsonCsvFileSaver,
    required this.jsonTableFilePicker,
    required this.initialLocation,
  });

  final String localeTag;
  final CronService cronService;
  final DateService dateService;
  final JsonCsvService jsonCsvService;
  final JsonTableService jsonTableService;
  final DateTime Function()? currentTime;
  final CronFilePicker? cronFilePicker;
  final DateFilePicker? dateFilePicker;
  final JsonCsvFilePicker? jsonCsvFilePicker;
  final JsonCsvFileSaver? jsonCsvFileSaver;
  final JsonTableFilePicker? jsonTableFilePicker;
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
      dateService: widget.dateService,
      jsonCsvService: widget.jsonCsvService,
      jsonTableService: widget.jsonTableService,
      currentTime: widget.currentTime ?? DateTime.now,
      cronFilePicker: widget.cronFilePicker ?? pickCronExpressionFile,
      dateFilePicker: widget.dateFilePicker ?? pickDateValueFile,
      jsonCsvFilePicker: widget.jsonCsvFilePicker ?? pickJsonCsvFile,
      jsonCsvFileSaver: widget.jsonCsvFileSaver ?? saveJsonCsvFile,
      jsonTableFilePicker: widget.jsonTableFilePicker ?? pickJsonTableFile,
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
