import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'cron_page.dart';
import 'date_page.dart';
import 'json_csv_page.dart';
import 'json_format_page.dart';
import 'json_table_page.dart';
import 'json_yaml_page.dart';
import 'sql_format_page.dart';

GoRouter buildRouter({
  required MessageCatalog catalog,
  required String localeTag,
  required CronService cronService,
  required DateService dateService,
  required JsonCsvService jsonCsvService,
  required JsonFormatService jsonFormatService,
  required JsonTableService jsonTableService,
  required JsonYamlService jsonYamlService,
  required SqlFormatService sqlFormatService,
  required DateTime Function() currentTime,
  required CronFilePicker cronFilePicker,
  required DateFilePicker dateFilePicker,
  required JsonCsvFilePicker jsonCsvFilePicker,
  required JsonCsvFileSaver jsonCsvFileSaver,
  required JsonFormatFilePicker jsonFormatFilePicker,
  required JsonFormatFileSaver jsonFormatFileSaver,
  required JsonFormatClipboardReader jsonFormatClipboardReader,
  required JsonFormatClipboardWriter jsonFormatClipboardWriter,
  required JsonTableFilePicker jsonTableFilePicker,
  required JsonYamlFilePicker jsonYamlFilePicker,
  required JsonYamlFileSaver jsonYamlFileSaver,
  required SqlFormatFilePicker sqlFormatFilePicker,
  required SqlFormatFileSaver sqlFormatFileSaver,
  required SqlFormatClipboardReader sqlFormatClipboardReader,
  required SqlFormatClipboardWriter sqlFormatClipboardWriter,
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
                        key: const Key('open-json-table'),
                        onPressed: () => context.go('/json/array-to-table'),
                        child: Text(
                          catalog.lookup(localeTag, 'jsonTable.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-json-csv'),
                        onPressed: () => context.go('/json/array-to-csv'),
                        child: Text(
                          catalog.lookup(localeTag, 'jsonCsv.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-json-yaml'),
                        onPressed: () => context.go('/json/to-yaml'),
                        child: Text(
                          catalog.lookup(localeTag, 'jsonYaml.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-json-format'),
                        onPressed: () => context.go('/json/format'),
                        child: Text(
                          catalog.lookup(localeTag, 'jsonFormat.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-sql-format'),
                        onPressed: () => context.go('/sql/format'),
                        child: Text(
                          catalog.lookup(localeTag, 'sqlFormat.openAction'),
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
      GoRoute(
        path: '/json/array-to-table',
        builder: (context, state) => JsonTablePage(
          catalog: catalog,
          localeTag: localeTag,
          service: jsonTableService,
          filePicker: jsonTableFilePicker,
        ),
      ),
      GoRoute(
        path: '/json/array-to-csv',
        builder: (context, state) => JsonCsvPage(
          catalog: catalog,
          localeTag: localeTag,
          service: jsonCsvService,
          filePicker: jsonCsvFilePicker,
          fileSaver: jsonCsvFileSaver,
        ),
      ),
      GoRoute(
        path: '/json/to-yaml',
        builder: (context, state) => JsonYamlPage(
          catalog: catalog,
          localeTag: localeTag,
          service: jsonYamlService,
          filePicker: jsonYamlFilePicker,
          fileSaver: jsonYamlFileSaver,
        ),
      ),
      GoRoute(
        path: '/json/format',
        builder: (context, state) => JsonFormatPage(
          catalog: catalog,
          localeTag: localeTag,
          service: jsonFormatService,
          filePicker: jsonFormatFilePicker,
          fileSaver: jsonFormatFileSaver,
          clipboardReader: jsonFormatClipboardReader,
          clipboardWriter: jsonFormatClipboardWriter,
        ),
      ),
      GoRoute(
        path: '/sql/format',
        builder: (context, state) => SqlFormatPage(
          catalog: catalog,
          localeTag: localeTag,
          service: sqlFormatService,
          filePicker: sqlFormatFilePicker,
          fileSaver: sqlFormatFileSaver,
          clipboardReader: sqlFormatClipboardReader,
          clipboardWriter: sqlFormatClipboardWriter,
        ),
      ),
    ],
  );
}
