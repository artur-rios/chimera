import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'base64_decode_page.dart';
import 'base64_encode_page.dart';
import 'cron_page.dart';
import 'date_page.dart';
import 'json_csv_page.dart';
import 'json_format_page.dart';
import 'json_table_page.dart';
import 'json_yaml_page.dart';
import 'list_compare_page.dart';
import 'number_base_page.dart';
import 'sql_format_page.dart';
import 'text_analyze_page.dart';
import 'text_compare_page.dart';
import 'text_escape_page.dart';
import 'text_transform_page.dart';
import 'text_unescape_page.dart';
import 'xml_format_page.dart';

GoRouter buildRouter({
  required MessageCatalog catalog,
  required String localeTag,
  required Base64DecodeService base64DecodeService,
  required Base64EncodeService base64EncodeService,
  required CronService cronService,
  required DateService dateService,
  required JsonCsvService jsonCsvService,
  required JsonFormatService jsonFormatService,
  required JsonTableService jsonTableService,
  required JsonYamlService jsonYamlService,
  required ListCompareService listCompareService,
  required NumberBaseService numberBaseService,
  required TextAnalyzeService textAnalyzeService,
  required TextCompareService textCompareService,
  required TextEscapeService textEscapeService,
  required TextTransformService textTransformService,
  required TextUnescapeService textUnescapeService,
  required SqlFormatService sqlFormatService,
  required XmlFormatService xmlFormatService,
  required DateTime Function() currentTime,
  required Base64DecodeFilePicker base64DecodeFilePicker,
  required Base64DecodeFileSaver base64DecodeFileSaver,
  required Base64DecodeClipboardReader base64DecodeClipboardReader,
  required Base64DecodeClipboardWriter base64DecodeClipboardWriter,
  required Base64DecodePreviewDecoder base64DecodePreviewDecoder,
  required Base64EncodeFilePicker base64EncodeFilePicker,
  required Base64EncodeFileSaver base64EncodeFileSaver,
  required Base64EncodeClipboardReader base64EncodeClipboardReader,
  required Base64EncodeClipboardWriter base64EncodeClipboardWriter,
  required Base64EncodeOutputEncoder base64EncodeOutputEncoder,
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
  required ListCompareFilePicker listCompareLeftFilePicker,
  required ListCompareFilePicker listCompareRightFilePicker,
  required ListCompareFileSaver listCompareFileSaver,
  required ListCompareClipboardReader listCompareLeftClipboardReader,
  required ListCompareClipboardReader listCompareRightClipboardReader,
  required ListCompareClipboardWriter listCompareClipboardWriter,
  required NumberBaseFilePicker numberBaseFilePicker,
  required NumberBaseFileSaver numberBaseFileSaver,
  required NumberBaseClipboardReader numberBaseClipboardReader,
  required NumberBaseClipboardWriter numberBaseClipboardWriter,
  required TextAnalyzeFilePicker textAnalyzeFilePicker,
  required TextAnalyzeFileSaver textAnalyzeFileSaver,
  required TextAnalyzeClipboardReader textAnalyzeClipboardReader,
  required TextAnalyzeClipboardWriter textAnalyzeClipboardWriter,
  required TextCompareFilePicker textCompareLeftFilePicker,
  required TextCompareFilePicker textCompareRightFilePicker,
  required TextCompareFileSaver textCompareFileSaver,
  required TextCompareClipboardReader textCompareLeftClipboardReader,
  required TextCompareClipboardReader textCompareRightClipboardReader,
  required TextCompareClipboardWriter textCompareClipboardWriter,
  required TextEscapeFilePicker textEscapeFilePicker,
  required TextEscapeFileSaver textEscapeFileSaver,
  required TextEscapeClipboardReader textEscapeClipboardReader,
  required TextEscapeClipboardWriter textEscapeClipboardWriter,
  required TextTransformFilePicker textTransformFilePicker,
  required TextTransformFileSaver textTransformFileSaver,
  required TextTransformClipboardReader textTransformClipboardReader,
  required TextTransformClipboardWriter textTransformClipboardWriter,
  required TextUnescapeFilePicker textUnescapeFilePicker,
  required TextUnescapeFileSaver textUnescapeFileSaver,
  required TextUnescapeClipboardReader textUnescapeClipboardReader,
  required TextUnescapeClipboardWriter textUnescapeClipboardWriter,
  required SqlFormatFilePicker sqlFormatFilePicker,
  required SqlFormatFileSaver sqlFormatFileSaver,
  required SqlFormatClipboardReader sqlFormatClipboardReader,
  required SqlFormatClipboardWriter sqlFormatClipboardWriter,
  required XmlFormatFilePicker xmlFormatFilePicker,
  required XmlFormatFileSaver xmlFormatFileSaver,
  required XmlFormatClipboardReader xmlFormatClipboardReader,
  required XmlFormatClipboardWriter xmlFormatClipboardWriter,
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
                        key: const Key('open-xml-format'),
                        onPressed: () => context.go('/xml/format'),
                        child: Text(
                          catalog.lookup(localeTag, 'xmlFormat.openAction'),
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
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-number-base'),
                        onPressed: () => context.go('/number/convert-base'),
                        child: Text(
                          catalog.lookup(localeTag, 'numberBase.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-base64-decode'),
                        onPressed: () => context.go('/base64/decode'),
                        child: Text(
                          catalog.lookup(localeTag, 'base64Decode.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-base64-encode'),
                        onPressed: () => context.go('/base64/encode'),
                        child: Text(
                          catalog.lookup(localeTag, 'base64Encode.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-text-escape'),
                        onPressed: () => context.go('/text/escape'),
                        child: Text(
                          catalog.lookup(localeTag, 'textEscape.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-text-unescape'),
                        onPressed: () => context.go('/text/unescape'),
                        child: Text(
                          catalog.lookup(localeTag, 'textUnescape.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-text-transform'),
                        onPressed: () => context.go('/text/transform'),
                        child: Text(
                          catalog.lookup(localeTag, 'textTransform.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-text-compare'),
                        onPressed: () => context.go('/text/compare'),
                        child: Text(
                          catalog.lookup(localeTag, 'textCompare.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-list-compare'),
                        onPressed: () => context.go('/list/compare'),
                        child: Text(
                          catalog.lookup(localeTag, 'listCompare.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-text-analyze'),
                        onPressed: () => context.go('/text/analyze'),
                        child: Text(
                          catalog.lookup(localeTag, 'textAnalyze.openAction'),
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
        path: '/number/convert-base',
        builder: (context, state) => NumberBasePage(
          catalog: catalog,
          localeTag: localeTag,
          service: numberBaseService,
          filePicker: numberBaseFilePicker,
          fileSaver: numberBaseFileSaver,
          clipboardReader: numberBaseClipboardReader,
          clipboardWriter: numberBaseClipboardWriter,
        ),
      ),
      GoRoute(
        path: '/base64/decode',
        builder: (context, state) => Base64DecodePage(
          catalog: catalog,
          localeTag: localeTag,
          service: base64DecodeService,
          filePicker: base64DecodeFilePicker,
          fileSaver: base64DecodeFileSaver,
          clipboardReader: base64DecodeClipboardReader,
          clipboardWriter: base64DecodeClipboardWriter,
          previewDecoder: base64DecodePreviewDecoder,
        ),
      ),
      GoRoute(
        path: '/base64/encode',
        builder: (context, state) => Base64EncodePage(
          catalog: catalog,
          localeTag: localeTag,
          service: base64EncodeService,
          filePicker: base64EncodeFilePicker,
          fileSaver: base64EncodeFileSaver,
          clipboardReader: base64EncodeClipboardReader,
          clipboardWriter: base64EncodeClipboardWriter,
          outputEncoder: base64EncodeOutputEncoder,
        ),
      ),
      GoRoute(
        path: '/text/escape',
        builder: (context, state) => TextEscapePage(
          catalog: catalog,
          localeTag: localeTag,
          service: textEscapeService,
          filePicker: textEscapeFilePicker,
          fileSaver: textEscapeFileSaver,
          clipboardReader: textEscapeClipboardReader,
          clipboardWriter: textEscapeClipboardWriter,
        ),
      ),
      GoRoute(
        path: '/text/unescape',
        builder: (context, state) => TextUnescapePage(
          catalog: catalog,
          localeTag: localeTag,
          service: textUnescapeService,
          filePicker: textUnescapeFilePicker,
          fileSaver: textUnescapeFileSaver,
          clipboardReader: textUnescapeClipboardReader,
          clipboardWriter: textUnescapeClipboardWriter,
        ),
      ),
      GoRoute(
        path: '/text/transform',
        builder: (context, state) => TextTransformPage(
          catalog: catalog,
          localeTag: localeTag,
          service: textTransformService,
          filePicker: textTransformFilePicker,
          fileSaver: textTransformFileSaver,
          clipboardReader: textTransformClipboardReader,
          clipboardWriter: textTransformClipboardWriter,
        ),
      ),
      GoRoute(
        path: '/text/analyze',
        builder: (context, state) => TextAnalyzePage(
          catalog: catalog,
          localeTag: localeTag,
          service: textAnalyzeService,
          filePicker: textAnalyzeFilePicker,
          fileSaver: textAnalyzeFileSaver,
          clipboardReader: textAnalyzeClipboardReader,
          clipboardWriter: textAnalyzeClipboardWriter,
        ),
      ),
      GoRoute(
        path: '/text/compare',
        builder: (context, state) => TextComparePage(
          catalog: catalog,
          localeTag: localeTag,
          service: textCompareService,
          leftFilePicker: textCompareLeftFilePicker,
          rightFilePicker: textCompareRightFilePicker,
          fileSaver: textCompareFileSaver,
          leftClipboardReader: textCompareLeftClipboardReader,
          rightClipboardReader: textCompareRightClipboardReader,
          clipboardWriter: textCompareClipboardWriter,
        ),
      ),
      GoRoute(
        path: '/list/compare',
        builder: (context, state) => ListComparePage(
          catalog: catalog,
          localeTag: localeTag,
          service: listCompareService,
          leftFilePicker: listCompareLeftFilePicker,
          rightFilePicker: listCompareRightFilePicker,
          fileSaver: listCompareFileSaver,
          leftClipboardReader: listCompareLeftClipboardReader,
          rightClipboardReader: listCompareRightClipboardReader,
          clipboardWriter: listCompareClipboardWriter,
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
      GoRoute(
        path: '/xml/format',
        builder: (context, state) => XmlFormatPage(
          catalog: catalog,
          localeTag: localeTag,
          service: xmlFormatService,
          filePicker: xmlFormatFilePicker,
          fileSaver: xmlFormatFileSaver,
          clipboardReader: xmlFormatClipboardReader,
          clipboardWriter: xmlFormatClipboardWriter,
        ),
      ),
    ],
  );
}
