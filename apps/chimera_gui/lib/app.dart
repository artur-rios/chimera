import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'cron_page.dart';
import 'date_page.dart';
import 'json_csv_page.dart';
import 'json_format_page.dart';
import 'json_table_page.dart';
import 'json_yaml_page.dart';
import 'router.dart';
import 'sql_format_page.dart';
import 'xml_format_page.dart';

final class ChimeraApp extends StatelessWidget {
  const ChimeraApp({
    this.localeTag = 'en',
    this.cronService = const CronService(),
    this.dateService = const DateService(),
    this.jsonCsvService = const JsonCsvService(
      converter: JsonCsvConverter(maxCells: 10000),
    ),
    this.jsonFormatService = const JsonFormatService(),
    this.jsonTableService = const JsonTableService(
      converter: JsonTableConverter(maxCells: 10000),
    ),
    this.jsonYamlService = const JsonYamlService(
      converter: JsonYamlConverter(maxNodes: 10000),
    ),
    this.sqlFormatService = const SqlFormatService(),
    this.xmlFormatService = const XmlFormatService(),
    this.currentTime,
    this.cronFilePicker,
    this.dateFilePicker,
    this.jsonCsvFilePicker,
    this.jsonCsvFileSaver,
    this.jsonFormatFilePicker,
    this.jsonFormatFileSaver,
    this.jsonFormatClipboardReader,
    this.jsonFormatClipboardWriter,
    this.jsonTableFilePicker,
    this.jsonYamlFilePicker,
    this.jsonYamlFileSaver,
    this.sqlFormatFilePicker,
    this.sqlFormatFileSaver,
    this.sqlFormatClipboardReader,
    this.sqlFormatClipboardWriter,
    this.xmlFormatFilePicker,
    this.xmlFormatFileSaver,
    this.xmlFormatClipboardReader,
    this.xmlFormatClipboardWriter,
    this.initialLocation = '/',
    super.key,
  });

  final String localeTag;
  final CronService cronService;
  final DateService dateService;
  final JsonCsvService jsonCsvService;
  final JsonFormatService jsonFormatService;
  final JsonTableService jsonTableService;
  final JsonYamlService jsonYamlService;
  final SqlFormatService sqlFormatService;
  final XmlFormatService xmlFormatService;
  final DateTime Function()? currentTime;
  final CronFilePicker? cronFilePicker;
  final DateFilePicker? dateFilePicker;
  final JsonCsvFilePicker? jsonCsvFilePicker;
  final JsonCsvFileSaver? jsonCsvFileSaver;
  final JsonFormatFilePicker? jsonFormatFilePicker;
  final JsonFormatFileSaver? jsonFormatFileSaver;
  final JsonFormatClipboardReader? jsonFormatClipboardReader;
  final JsonFormatClipboardWriter? jsonFormatClipboardWriter;
  final JsonTableFilePicker? jsonTableFilePicker;
  final JsonYamlFilePicker? jsonYamlFilePicker;
  final JsonYamlFileSaver? jsonYamlFileSaver;
  final SqlFormatFilePicker? sqlFormatFilePicker;
  final SqlFormatFileSaver? sqlFormatFileSaver;
  final SqlFormatClipboardReader? sqlFormatClipboardReader;
  final SqlFormatClipboardWriter? sqlFormatClipboardWriter;
  final XmlFormatFilePicker? xmlFormatFilePicker;
  final XmlFormatFileSaver? xmlFormatFileSaver;
  final XmlFormatClipboardReader? xmlFormatClipboardReader;
  final XmlFormatClipboardWriter? xmlFormatClipboardWriter;
  final String initialLocation;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: _RoutedChimeraApp(
        localeTag: localeTag,
        cronService: cronService,
        dateService: dateService,
        jsonCsvService: jsonCsvService,
        jsonFormatService: jsonFormatService,
        jsonTableService: jsonTableService,
        jsonYamlService: jsonYamlService,
        sqlFormatService: sqlFormatService,
        xmlFormatService: xmlFormatService,
        currentTime: currentTime,
        cronFilePicker: cronFilePicker,
        dateFilePicker: dateFilePicker,
        jsonCsvFilePicker: jsonCsvFilePicker,
        jsonCsvFileSaver: jsonCsvFileSaver,
        jsonFormatFilePicker: jsonFormatFilePicker,
        jsonFormatFileSaver: jsonFormatFileSaver,
        jsonFormatClipboardReader: jsonFormatClipboardReader,
        jsonFormatClipboardWriter: jsonFormatClipboardWriter,
        jsonTableFilePicker: jsonTableFilePicker,
        jsonYamlFilePicker: jsonYamlFilePicker,
        jsonYamlFileSaver: jsonYamlFileSaver,
        sqlFormatFilePicker: sqlFormatFilePicker,
        sqlFormatFileSaver: sqlFormatFileSaver,
        sqlFormatClipboardReader: sqlFormatClipboardReader,
        sqlFormatClipboardWriter: sqlFormatClipboardWriter,
        xmlFormatFilePicker: xmlFormatFilePicker,
        xmlFormatFileSaver: xmlFormatFileSaver,
        xmlFormatClipboardReader: xmlFormatClipboardReader,
        xmlFormatClipboardWriter: xmlFormatClipboardWriter,
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
    required this.jsonFormatService,
    required this.jsonTableService,
    required this.jsonYamlService,
    required this.sqlFormatService,
    required this.xmlFormatService,
    required this.currentTime,
    required this.cronFilePicker,
    required this.dateFilePicker,
    required this.jsonCsvFilePicker,
    required this.jsonCsvFileSaver,
    required this.jsonFormatFilePicker,
    required this.jsonFormatFileSaver,
    required this.jsonFormatClipboardReader,
    required this.jsonFormatClipboardWriter,
    required this.jsonTableFilePicker,
    required this.jsonYamlFilePicker,
    required this.jsonYamlFileSaver,
    required this.sqlFormatFilePicker,
    required this.sqlFormatFileSaver,
    required this.sqlFormatClipboardReader,
    required this.sqlFormatClipboardWriter,
    required this.xmlFormatFilePicker,
    required this.xmlFormatFileSaver,
    required this.xmlFormatClipboardReader,
    required this.xmlFormatClipboardWriter,
    required this.initialLocation,
  });

  final String localeTag;
  final CronService cronService;
  final DateService dateService;
  final JsonCsvService jsonCsvService;
  final JsonFormatService jsonFormatService;
  final JsonTableService jsonTableService;
  final JsonYamlService jsonYamlService;
  final SqlFormatService sqlFormatService;
  final XmlFormatService xmlFormatService;
  final DateTime Function()? currentTime;
  final CronFilePicker? cronFilePicker;
  final DateFilePicker? dateFilePicker;
  final JsonCsvFilePicker? jsonCsvFilePicker;
  final JsonCsvFileSaver? jsonCsvFileSaver;
  final JsonFormatFilePicker? jsonFormatFilePicker;
  final JsonFormatFileSaver? jsonFormatFileSaver;
  final JsonFormatClipboardReader? jsonFormatClipboardReader;
  final JsonFormatClipboardWriter? jsonFormatClipboardWriter;
  final JsonTableFilePicker? jsonTableFilePicker;
  final JsonYamlFilePicker? jsonYamlFilePicker;
  final JsonYamlFileSaver? jsonYamlFileSaver;
  final SqlFormatFilePicker? sqlFormatFilePicker;
  final SqlFormatFileSaver? sqlFormatFileSaver;
  final SqlFormatClipboardReader? sqlFormatClipboardReader;
  final SqlFormatClipboardWriter? sqlFormatClipboardWriter;
  final XmlFormatFilePicker? xmlFormatFilePicker;
  final XmlFormatFileSaver? xmlFormatFileSaver;
  final XmlFormatClipboardReader? xmlFormatClipboardReader;
  final XmlFormatClipboardWriter? xmlFormatClipboardWriter;
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
      jsonFormatService: widget.jsonFormatService,
      jsonTableService: widget.jsonTableService,
      jsonYamlService: widget.jsonYamlService,
      sqlFormatService: widget.sqlFormatService,
      xmlFormatService: widget.xmlFormatService,
      currentTime: widget.currentTime ?? DateTime.now,
      cronFilePicker: widget.cronFilePicker ?? pickCronExpressionFile,
      dateFilePicker: widget.dateFilePicker ?? pickDateValueFile,
      jsonCsvFilePicker: widget.jsonCsvFilePicker ?? pickJsonCsvFile,
      jsonCsvFileSaver: widget.jsonCsvFileSaver ?? saveJsonCsvFile,
      jsonFormatFilePicker: widget.jsonFormatFilePicker ?? pickJsonFormatFile,
      jsonFormatFileSaver: widget.jsonFormatFileSaver ?? saveJsonFormatFile,
      jsonFormatClipboardReader:
          widget.jsonFormatClipboardReader ?? readJsonFormatClipboard,
      jsonFormatClipboardWriter:
          widget.jsonFormatClipboardWriter ?? writeJsonFormatClipboard,
      jsonTableFilePicker: widget.jsonTableFilePicker ?? pickJsonTableFile,
      jsonYamlFilePicker: widget.jsonYamlFilePicker ?? pickJsonYamlFile,
      jsonYamlFileSaver: widget.jsonYamlFileSaver ?? saveJsonYamlFile,
      sqlFormatFilePicker: widget.sqlFormatFilePicker ?? pickSqlFormatFile,
      sqlFormatFileSaver: widget.sqlFormatFileSaver ?? saveSqlFormatFile,
      sqlFormatClipboardReader:
          widget.sqlFormatClipboardReader ?? readSqlFormatClipboard,
      sqlFormatClipboardWriter:
          widget.sqlFormatClipboardWriter ?? writeSqlFormatClipboard,
      xmlFormatFilePicker: widget.xmlFormatFilePicker ?? pickXmlFormatFile,
      xmlFormatFileSaver: widget.xmlFormatFileSaver ?? saveXmlFormatFile,
      xmlFormatClipboardReader:
          widget.xmlFormatClipboardReader ?? readXmlFormatClipboard,
      xmlFormatClipboardWriter:
          widget.xmlFormatClipboardWriter ?? writeXmlFormatClipboard,
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
