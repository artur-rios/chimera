import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'base64_decode_page.dart';
import 'base64_encode_page.dart';
import 'certificate_convert_page.dart';
import 'certificate_inspect_page.dart';
import 'cron_page.dart';
import 'date_page.dart';
import 'gzip_compress_page.dart';
import 'gzip_decompress_page.dart';
import 'html_decode_page.dart';
import 'html_encode_page.dart';
import 'json_csv_page.dart';
import 'json_format_page.dart';
import 'json_table_page.dart';
import 'json_yaml_page.dart';
import 'jwt_create_page.dart';
import 'jwt_inspect_page.dart';
import 'list_compare_page.dart';
import 'number_base_page.dart';
import 'qr_decode_page.dart';
import 'qr_encode_page.dart';
import 'router.dart';
import 'sql_format_page.dart';
import 'text_analyze_page.dart';
import 'text_compare_page.dart';
import 'text_escape_page.dart';
import 'text_transform_page.dart';
import 'text_unescape_page.dart';
import 'url_decode_page.dart';
import 'url_encode_page.dart';
import 'xml_format_page.dart';

final class ChimeraApp extends StatelessWidget {
  const ChimeraApp({
    this.jwtCreateService = const JwtCreateService(),
    this.jwtCreateFilePicker,
    this.jwtCreateClipboardReader,
    this.jwtCreateClipboardWriter,
    this.jwtCreateFileSaver,
    this.jwtInspectService = const JwtInspectService(),
    this.jwtInspectFilePicker,
    this.jwtInspectClipboardReader,
    this.jwtInspectClipboardWriter,
    this.qrDecodeService = const QrDecodeService(),
    this.qrDecodeFilePicker,
    this.qrDecodeClipboardWriter,
    this.qrDecodeFileSaver,
    this.qrEncodeService = const QrEncodeService(),
    this.qrEncodeFilePicker,
    this.qrEncodeClipboardReader,
    this.qrEncodeFileSaver,
    this.htmlDecodeService = const HtmlDecodeService(),
    this.htmlDecodeFilePicker,
    this.htmlDecodeClipboardReader,
    this.htmlDecodeClipboardWriter,
    this.htmlDecodeFileSaver,
    this.htmlDecodeOutputEncoder,
    this.urlDecodeService = const UrlDecodeService(),
    this.urlDecodeFilePicker,
    this.urlDecodeClipboardReader,
    this.urlDecodeClipboardWriter,
    this.urlDecodeFileSaver,
    this.urlDecodeOutputEncoder,
    this.htmlEncodeService = const HtmlEncodeService(),
    this.htmlEncodeFilePicker,
    this.htmlEncodeClipboardReader,
    this.htmlEncodeClipboardWriter,
    this.htmlEncodeFileSaver,
    this.htmlEncodeOutputEncoder,
    this.urlEncodeService = const UrlEncodeService(),
    this.urlEncodeFilePicker,
    this.urlEncodeClipboardReader,
    this.urlEncodeClipboardWriter,
    this.urlEncodeFileSaver,
    this.urlEncodeOutputEncoder,
    this.gzipCompressService = const GzipCompressService(),
    this.gzipCompressFilePicker,
    this.gzipCompressClipboardReader,
    this.gzipCompressFileSaver,
    this.gzipDecompressService = const GzipDecompressService(),
    this.gzipDecompressFilePicker,
    this.gzipDecompressClipboardWriter,
    this.gzipDecompressFileSaver,
    this.localeTag = 'en',
    this.certificateConvertService = const CertificateConvertService(),
    this.certificateConvertFilePicker,
    this.certificateConvertFileSaver,
    this.certificateConvertClipboardReader,
    this.certificateConvertClipboardWriter,
    this.certificateInspectService = const CertificateInspectService(),
    this.certificateInspectFilePicker,
    this.certificateInspectClipboardReader,
    this.certificateInspectClipboardWriter,
    this.base64DecodeService = const Base64DecodeService(),
    this.base64EncodeService = const Base64EncodeService(),
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
    this.listCompareService = const ListCompareService(),
    this.numberBaseService = const NumberBaseService(),
    this.textAnalyzeService = const TextAnalyzeService(),
    this.textCompareService = const TextCompareService(),
    this.textEscapeService = const TextEscapeService(),
    this.textTransformService = const TextTransformService(),
    this.textUnescapeService = const TextUnescapeService(),
    this.sqlFormatService = const SqlFormatService(),
    this.xmlFormatService = const XmlFormatService(),
    this.currentTime,
    this.base64DecodeFilePicker,
    this.base64DecodeFileSaver,
    this.base64DecodeClipboardReader,
    this.base64DecodeClipboardWriter,
    this.base64DecodePreviewDecoder,
    this.base64EncodeFilePicker,
    this.base64EncodeFileSaver,
    this.base64EncodeClipboardReader,
    this.base64EncodeClipboardWriter,
    this.base64EncodeOutputEncoder,
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
    this.listCompareLeftFilePicker,
    this.listCompareRightFilePicker,
    this.listCompareFileSaver,
    this.listCompareLeftClipboardReader,
    this.listCompareRightClipboardReader,
    this.listCompareClipboardWriter,
    this.numberBaseFilePicker,
    this.numberBaseFileSaver,
    this.numberBaseClipboardReader,
    this.numberBaseClipboardWriter,
    this.textAnalyzeFilePicker,
    this.textAnalyzeFileSaver,
    this.textAnalyzeClipboardReader,
    this.textAnalyzeClipboardWriter,
    this.textCompareLeftFilePicker,
    this.textCompareRightFilePicker,
    this.textCompareFileSaver,
    this.textCompareLeftClipboardReader,
    this.textCompareRightClipboardReader,
    this.textCompareClipboardWriter,
    this.textEscapeFilePicker,
    this.textEscapeFileSaver,
    this.textEscapeClipboardReader,
    this.textEscapeClipboardWriter,
    this.textTransformFilePicker,
    this.textTransformFileSaver,
    this.textTransformClipboardReader,
    this.textTransformClipboardWriter,
    this.textUnescapeFilePicker,
    this.textUnescapeFileSaver,
    this.textUnescapeClipboardReader,
    this.textUnescapeClipboardWriter,
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
  final JwtCreateOperationService jwtCreateService;
  final JwtCreateFilePicker? jwtCreateFilePicker;
  final JwtCreateClipboardReader? jwtCreateClipboardReader;
  final JwtCreateClipboardWriter? jwtCreateClipboardWriter;
  final JwtCreateFileSaver? jwtCreateFileSaver;
  final JwtInspectOperationService jwtInspectService;
  final JwtInspectFilePicker? jwtInspectFilePicker;
  final JwtInspectClipboardReader? jwtInspectClipboardReader;
  final JwtInspectClipboardWriter? jwtInspectClipboardWriter;
  final QrDecodeOperationService qrDecodeService;
  final QrDecodeFilePicker? qrDecodeFilePicker;
  final QrDecodeClipboardWriter? qrDecodeClipboardWriter;
  final QrDecodeFileSaver? qrDecodeFileSaver;
  final QrEncodeOperationService qrEncodeService;
  final QrEncodeFilePicker? qrEncodeFilePicker;
  final QrEncodeClipboardReader? qrEncodeClipboardReader;
  final QrEncodeFileSaver? qrEncodeFileSaver;
  final HtmlDecodeOperationService htmlDecodeService;
  final HtmlDecodeFilePicker? htmlDecodeFilePicker;
  final HtmlDecodeClipboardReader? htmlDecodeClipboardReader;
  final HtmlDecodeClipboardWriter? htmlDecodeClipboardWriter;
  final HtmlDecodeFileSaver? htmlDecodeFileSaver;
  final HtmlDecodeOutputEncoder? htmlDecodeOutputEncoder;
  final UrlDecodeOperationService urlDecodeService;
  final UrlDecodeFilePicker? urlDecodeFilePicker;
  final UrlDecodeClipboardReader? urlDecodeClipboardReader;
  final UrlDecodeClipboardWriter? urlDecodeClipboardWriter;
  final UrlDecodeFileSaver? urlDecodeFileSaver;
  final UrlDecodeOutputEncoder? urlDecodeOutputEncoder;
  final HtmlEncodeOperationService htmlEncodeService;
  final HtmlEncodeFilePicker? htmlEncodeFilePicker;
  final HtmlEncodeClipboardReader? htmlEncodeClipboardReader;
  final HtmlEncodeClipboardWriter? htmlEncodeClipboardWriter;
  final HtmlEncodeFileSaver? htmlEncodeFileSaver;
  final HtmlEncodeOutputEncoder? htmlEncodeOutputEncoder;
  final UrlEncodeOperationService urlEncodeService;
  final UrlEncodeFilePicker? urlEncodeFilePicker;
  final UrlEncodeClipboardReader? urlEncodeClipboardReader;
  final UrlEncodeClipboardWriter? urlEncodeClipboardWriter;
  final UrlEncodeFileSaver? urlEncodeFileSaver;
  final UrlEncodeOutputEncoder? urlEncodeOutputEncoder;
  final GzipCompressOperationService gzipCompressService;
  final GzipCompressFilePicker? gzipCompressFilePicker;
  final GzipCompressClipboardReader? gzipCompressClipboardReader;
  final GzipCompressFileSaver? gzipCompressFileSaver;
  final GzipDecompressOperationService gzipDecompressService;
  final GzipDecompressFilePicker? gzipDecompressFilePicker;
  final GzipDecompressClipboardWriter? gzipDecompressClipboardWriter;
  final GzipDecompressFileSaver? gzipDecompressFileSaver;
  final CertificateConvertOperationService certificateConvertService;
  final CertificateConvertFilePicker? certificateConvertFilePicker;
  final CertificateConvertFileSaver? certificateConvertFileSaver;
  final CertificateConvertClipboardReader? certificateConvertClipboardReader;
  final CertificateConvertClipboardWriter? certificateConvertClipboardWriter;
  final CertificateInspectOperationService certificateInspectService;
  final CertificateInspectFilePicker? certificateInspectFilePicker;
  final CertificateInspectClipboardReader? certificateInspectClipboardReader;
  final CertificateInspectClipboardWriter? certificateInspectClipboardWriter;
  final Base64DecodeService base64DecodeService;
  final Base64EncodeService base64EncodeService;
  final CronService cronService;
  final DateService dateService;
  final JsonCsvService jsonCsvService;
  final JsonFormatService jsonFormatService;
  final JsonTableService jsonTableService;
  final JsonYamlService jsonYamlService;
  final ListCompareService listCompareService;
  final NumberBaseService numberBaseService;
  final TextAnalyzeService textAnalyzeService;
  final TextCompareService textCompareService;
  final TextEscapeService textEscapeService;
  final TextTransformService textTransformService;
  final TextUnescapeService textUnescapeService;
  final SqlFormatService sqlFormatService;
  final XmlFormatService xmlFormatService;
  final DateTime Function()? currentTime;
  final Base64DecodeFilePicker? base64DecodeFilePicker;
  final Base64DecodeFileSaver? base64DecodeFileSaver;
  final Base64DecodeClipboardReader? base64DecodeClipboardReader;
  final Base64DecodeClipboardWriter? base64DecodeClipboardWriter;
  final Base64DecodePreviewDecoder? base64DecodePreviewDecoder;
  final Base64EncodeFilePicker? base64EncodeFilePicker;
  final Base64EncodeFileSaver? base64EncodeFileSaver;
  final Base64EncodeClipboardReader? base64EncodeClipboardReader;
  final Base64EncodeClipboardWriter? base64EncodeClipboardWriter;
  final Base64EncodeOutputEncoder? base64EncodeOutputEncoder;
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
  final ListCompareFilePicker? listCompareLeftFilePicker;
  final ListCompareFilePicker? listCompareRightFilePicker;
  final ListCompareFileSaver? listCompareFileSaver;
  final ListCompareClipboardReader? listCompareLeftClipboardReader;
  final ListCompareClipboardReader? listCompareRightClipboardReader;
  final ListCompareClipboardWriter? listCompareClipboardWriter;
  final NumberBaseFilePicker? numberBaseFilePicker;
  final NumberBaseFileSaver? numberBaseFileSaver;
  final NumberBaseClipboardReader? numberBaseClipboardReader;
  final NumberBaseClipboardWriter? numberBaseClipboardWriter;
  final TextAnalyzeFilePicker? textAnalyzeFilePicker;
  final TextAnalyzeFileSaver? textAnalyzeFileSaver;
  final TextAnalyzeClipboardReader? textAnalyzeClipboardReader;
  final TextAnalyzeClipboardWriter? textAnalyzeClipboardWriter;
  final TextCompareFilePicker? textCompareLeftFilePicker;
  final TextCompareFilePicker? textCompareRightFilePicker;
  final TextCompareFileSaver? textCompareFileSaver;
  final TextCompareClipboardReader? textCompareLeftClipboardReader;
  final TextCompareClipboardReader? textCompareRightClipboardReader;
  final TextCompareClipboardWriter? textCompareClipboardWriter;
  final TextEscapeFilePicker? textEscapeFilePicker;
  final TextEscapeFileSaver? textEscapeFileSaver;
  final TextEscapeClipboardReader? textEscapeClipboardReader;
  final TextEscapeClipboardWriter? textEscapeClipboardWriter;
  final TextTransformFilePicker? textTransformFilePicker;
  final TextTransformFileSaver? textTransformFileSaver;
  final TextTransformClipboardReader? textTransformClipboardReader;
  final TextTransformClipboardWriter? textTransformClipboardWriter;
  final TextUnescapeFilePicker? textUnescapeFilePicker;
  final TextUnescapeFileSaver? textUnescapeFileSaver;
  final TextUnescapeClipboardReader? textUnescapeClipboardReader;
  final TextUnescapeClipboardWriter? textUnescapeClipboardWriter;
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
        jwtCreateService: jwtCreateService,
        jwtCreateFilePicker: jwtCreateFilePicker,
        jwtCreateClipboardReader: jwtCreateClipboardReader,
        jwtCreateClipboardWriter: jwtCreateClipboardWriter,
        jwtCreateFileSaver: jwtCreateFileSaver,
        jwtInspectService: jwtInspectService,
        jwtInspectFilePicker: jwtInspectFilePicker,
        jwtInspectClipboardReader: jwtInspectClipboardReader,
        jwtInspectClipboardWriter: jwtInspectClipboardWriter,
        qrDecodeService: qrDecodeService,
        qrDecodeFilePicker: qrDecodeFilePicker,
        qrDecodeClipboardWriter: qrDecodeClipboardWriter,
        qrDecodeFileSaver: qrDecodeFileSaver,
        qrEncodeService: qrEncodeService,
        qrEncodeFilePicker: qrEncodeFilePicker,
        qrEncodeClipboardReader: qrEncodeClipboardReader,
        qrEncodeFileSaver: qrEncodeFileSaver,
        htmlDecodeService: htmlDecodeService,
        htmlDecodeFilePicker: htmlDecodeFilePicker,
        htmlDecodeClipboardReader: htmlDecodeClipboardReader,
        htmlDecodeClipboardWriter: htmlDecodeClipboardWriter,
        htmlDecodeFileSaver: htmlDecodeFileSaver,
        htmlDecodeOutputEncoder: htmlDecodeOutputEncoder,
        urlDecodeService: urlDecodeService,
        urlDecodeFilePicker: urlDecodeFilePicker,
        urlDecodeClipboardReader: urlDecodeClipboardReader,
        urlDecodeClipboardWriter: urlDecodeClipboardWriter,
        urlDecodeFileSaver: urlDecodeFileSaver,
        urlDecodeOutputEncoder: urlDecodeOutputEncoder,
        htmlEncodeService: htmlEncodeService,
        htmlEncodeFilePicker: htmlEncodeFilePicker,
        htmlEncodeClipboardReader: htmlEncodeClipboardReader,
        htmlEncodeClipboardWriter: htmlEncodeClipboardWriter,
        htmlEncodeFileSaver: htmlEncodeFileSaver,
        htmlEncodeOutputEncoder: htmlEncodeOutputEncoder,
        urlEncodeService: urlEncodeService,
        urlEncodeFilePicker: urlEncodeFilePicker,
        urlEncodeClipboardReader: urlEncodeClipboardReader,
        urlEncodeClipboardWriter: urlEncodeClipboardWriter,
        urlEncodeFileSaver: urlEncodeFileSaver,
        urlEncodeOutputEncoder: urlEncodeOutputEncoder,
        gzipCompressService: gzipCompressService,
        gzipCompressFilePicker: gzipCompressFilePicker,
        gzipCompressClipboardReader: gzipCompressClipboardReader,
        gzipCompressFileSaver: gzipCompressFileSaver,
        gzipDecompressService: gzipDecompressService,
        gzipDecompressFilePicker: gzipDecompressFilePicker,
        gzipDecompressClipboardWriter: gzipDecompressClipboardWriter,
        gzipDecompressFileSaver: gzipDecompressFileSaver,
        localeTag: localeTag,
        certificateConvertService: certificateConvertService,
        certificateConvertFilePicker: certificateConvertFilePicker,
        certificateConvertFileSaver: certificateConvertFileSaver,
        certificateConvertClipboardReader: certificateConvertClipboardReader,
        certificateConvertClipboardWriter: certificateConvertClipboardWriter,
        certificateInspectService: certificateInspectService,
        certificateInspectFilePicker: certificateInspectFilePicker,
        certificateInspectClipboardReader: certificateInspectClipboardReader,
        certificateInspectClipboardWriter: certificateInspectClipboardWriter,
        base64DecodeService: base64DecodeService,
        base64EncodeService: base64EncodeService,
        cronService: cronService,
        dateService: dateService,
        jsonCsvService: jsonCsvService,
        jsonFormatService: jsonFormatService,
        jsonTableService: jsonTableService,
        jsonYamlService: jsonYamlService,
        listCompareService: listCompareService,
        numberBaseService: numberBaseService,
        textAnalyzeService: textAnalyzeService,
        textCompareService: textCompareService,
        textEscapeService: textEscapeService,
        textTransformService: textTransformService,
        textUnescapeService: textUnescapeService,
        sqlFormatService: sqlFormatService,
        xmlFormatService: xmlFormatService,
        currentTime: currentTime,
        base64DecodeFilePicker: base64DecodeFilePicker,
        base64DecodeFileSaver: base64DecodeFileSaver,
        base64DecodeClipboardReader: base64DecodeClipboardReader,
        base64DecodeClipboardWriter: base64DecodeClipboardWriter,
        base64DecodePreviewDecoder: base64DecodePreviewDecoder,
        base64EncodeFilePicker: base64EncodeFilePicker,
        base64EncodeFileSaver: base64EncodeFileSaver,
        base64EncodeClipboardReader: base64EncodeClipboardReader,
        base64EncodeClipboardWriter: base64EncodeClipboardWriter,
        base64EncodeOutputEncoder: base64EncodeOutputEncoder,
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
        listCompareLeftFilePicker: listCompareLeftFilePicker,
        listCompareRightFilePicker: listCompareRightFilePicker,
        listCompareFileSaver: listCompareFileSaver,
        listCompareLeftClipboardReader: listCompareLeftClipboardReader,
        listCompareRightClipboardReader: listCompareRightClipboardReader,
        listCompareClipboardWriter: listCompareClipboardWriter,
        numberBaseFilePicker: numberBaseFilePicker,
        numberBaseFileSaver: numberBaseFileSaver,
        numberBaseClipboardReader: numberBaseClipboardReader,
        numberBaseClipboardWriter: numberBaseClipboardWriter,
        textAnalyzeFilePicker: textAnalyzeFilePicker,
        textAnalyzeFileSaver: textAnalyzeFileSaver,
        textAnalyzeClipboardReader: textAnalyzeClipboardReader,
        textAnalyzeClipboardWriter: textAnalyzeClipboardWriter,
        textCompareLeftFilePicker: textCompareLeftFilePicker,
        textCompareRightFilePicker: textCompareRightFilePicker,
        textCompareFileSaver: textCompareFileSaver,
        textCompareLeftClipboardReader: textCompareLeftClipboardReader,
        textCompareRightClipboardReader: textCompareRightClipboardReader,
        textCompareClipboardWriter: textCompareClipboardWriter,
        textEscapeFilePicker: textEscapeFilePicker,
        textEscapeFileSaver: textEscapeFileSaver,
        textEscapeClipboardReader: textEscapeClipboardReader,
        textEscapeClipboardWriter: textEscapeClipboardWriter,
        textTransformFilePicker: textTransformFilePicker,
        textTransformFileSaver: textTransformFileSaver,
        textTransformClipboardReader: textTransformClipboardReader,
        textTransformClipboardWriter: textTransformClipboardWriter,
        textUnescapeFilePicker: textUnescapeFilePicker,
        textUnescapeFileSaver: textUnescapeFileSaver,
        textUnescapeClipboardReader: textUnescapeClipboardReader,
        textUnescapeClipboardWriter: textUnescapeClipboardWriter,
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
    required this.jwtCreateService,
    required this.jwtCreateFilePicker,
    required this.jwtCreateClipboardReader,
    required this.jwtCreateClipboardWriter,
    required this.jwtCreateFileSaver,
    required this.jwtInspectService,
    required this.jwtInspectFilePicker,
    required this.jwtInspectClipboardReader,
    required this.jwtInspectClipboardWriter,
    required this.qrDecodeService,
    required this.qrDecodeFilePicker,
    required this.qrDecodeClipboardWriter,
    required this.qrDecodeFileSaver,
    required this.qrEncodeService,
    required this.qrEncodeFilePicker,
    required this.qrEncodeClipboardReader,
    required this.qrEncodeFileSaver,
    required this.htmlDecodeService,
    required this.htmlDecodeFilePicker,
    required this.htmlDecodeClipboardReader,
    required this.htmlDecodeClipboardWriter,
    required this.htmlDecodeFileSaver,
    required this.htmlDecodeOutputEncoder,
    required this.urlDecodeService,
    required this.urlDecodeFilePicker,
    required this.urlDecodeClipboardReader,
    required this.urlDecodeClipboardWriter,
    required this.urlDecodeFileSaver,
    required this.urlDecodeOutputEncoder,
    required this.htmlEncodeService,
    required this.htmlEncodeFilePicker,
    required this.htmlEncodeClipboardReader,
    required this.htmlEncodeClipboardWriter,
    required this.htmlEncodeFileSaver,
    required this.htmlEncodeOutputEncoder,
    required this.urlEncodeService,
    required this.urlEncodeFilePicker,
    required this.urlEncodeClipboardReader,
    required this.urlEncodeClipboardWriter,
    required this.urlEncodeFileSaver,
    required this.urlEncodeOutputEncoder,
    required this.gzipCompressService,
    required this.gzipCompressFilePicker,
    required this.gzipCompressClipboardReader,
    required this.gzipCompressFileSaver,
    required this.gzipDecompressService,
    required this.gzipDecompressFilePicker,
    required this.gzipDecompressClipboardWriter,
    required this.gzipDecompressFileSaver,
    required this.certificateConvertService,
    required this.certificateConvertFilePicker,
    required this.certificateConvertFileSaver,
    required this.certificateConvertClipboardReader,
    required this.certificateConvertClipboardWriter,
    required this.certificateInspectService,
    required this.certificateInspectFilePicker,
    required this.certificateInspectClipboardReader,
    required this.certificateInspectClipboardWriter,
    required this.localeTag,
    required this.base64DecodeService,
    required this.base64EncodeService,
    required this.cronService,
    required this.dateService,
    required this.jsonCsvService,
    required this.jsonFormatService,
    required this.jsonTableService,
    required this.jsonYamlService,
    required this.listCompareService,
    required this.numberBaseService,
    required this.textAnalyzeService,
    required this.textCompareService,
    required this.textEscapeService,
    required this.textTransformService,
    required this.textUnescapeService,
    required this.sqlFormatService,
    required this.xmlFormatService,
    required this.currentTime,
    required this.base64DecodeFilePicker,
    required this.base64DecodeFileSaver,
    required this.base64DecodeClipboardReader,
    required this.base64DecodeClipboardWriter,
    required this.base64DecodePreviewDecoder,
    required this.base64EncodeFilePicker,
    required this.base64EncodeFileSaver,
    required this.base64EncodeClipboardReader,
    required this.base64EncodeClipboardWriter,
    required this.base64EncodeOutputEncoder,
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
    required this.listCompareLeftFilePicker,
    required this.listCompareRightFilePicker,
    required this.listCompareFileSaver,
    required this.listCompareLeftClipboardReader,
    required this.listCompareRightClipboardReader,
    required this.listCompareClipboardWriter,
    required this.numberBaseFilePicker,
    required this.numberBaseFileSaver,
    required this.numberBaseClipboardReader,
    required this.numberBaseClipboardWriter,
    required this.textAnalyzeFilePicker,
    required this.textAnalyzeFileSaver,
    required this.textAnalyzeClipboardReader,
    required this.textAnalyzeClipboardWriter,
    required this.textCompareLeftFilePicker,
    required this.textCompareRightFilePicker,
    required this.textCompareFileSaver,
    required this.textCompareLeftClipboardReader,
    required this.textCompareRightClipboardReader,
    required this.textCompareClipboardWriter,
    required this.textEscapeFilePicker,
    required this.textEscapeFileSaver,
    required this.textEscapeClipboardReader,
    required this.textEscapeClipboardWriter,
    required this.textTransformFilePicker,
    required this.textTransformFileSaver,
    required this.textTransformClipboardReader,
    required this.textTransformClipboardWriter,
    required this.textUnescapeFilePicker,
    required this.textUnescapeFileSaver,
    required this.textUnescapeClipboardReader,
    required this.textUnescapeClipboardWriter,
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
  final JwtCreateOperationService jwtCreateService;
  final JwtCreateFilePicker? jwtCreateFilePicker;
  final JwtCreateClipboardReader? jwtCreateClipboardReader;
  final JwtCreateClipboardWriter? jwtCreateClipboardWriter;
  final JwtCreateFileSaver? jwtCreateFileSaver;
  final JwtInspectOperationService jwtInspectService;
  final JwtInspectFilePicker? jwtInspectFilePicker;
  final JwtInspectClipboardReader? jwtInspectClipboardReader;
  final JwtInspectClipboardWriter? jwtInspectClipboardWriter;
  final QrDecodeOperationService qrDecodeService;
  final QrDecodeFilePicker? qrDecodeFilePicker;
  final QrDecodeClipboardWriter? qrDecodeClipboardWriter;
  final QrDecodeFileSaver? qrDecodeFileSaver;
  final QrEncodeOperationService qrEncodeService;
  final QrEncodeFilePicker? qrEncodeFilePicker;
  final QrEncodeClipboardReader? qrEncodeClipboardReader;
  final QrEncodeFileSaver? qrEncodeFileSaver;
  final Base64DecodeService base64DecodeService;
  final CertificateConvertOperationService certificateConvertService;
  final CertificateConvertFilePicker? certificateConvertFilePicker;
  final CertificateConvertFileSaver? certificateConvertFileSaver;
  final CertificateConvertClipboardReader? certificateConvertClipboardReader;
  final CertificateConvertClipboardWriter? certificateConvertClipboardWriter;
  final CertificateInspectOperationService certificateInspectService;
  final CertificateInspectFilePicker? certificateInspectFilePicker;
  final CertificateInspectClipboardReader? certificateInspectClipboardReader;
  final CertificateInspectClipboardWriter? certificateInspectClipboardWriter;
  final Base64EncodeService base64EncodeService;
  final CronService cronService;
  final DateService dateService;
  final JsonCsvService jsonCsvService;
  final JsonFormatService jsonFormatService;
  final JsonTableService jsonTableService;
  final JsonYamlService jsonYamlService;
  final ListCompareService listCompareService;
  final NumberBaseService numberBaseService;
  final TextAnalyzeService textAnalyzeService;
  final TextCompareService textCompareService;
  final TextEscapeService textEscapeService;
  final TextTransformService textTransformService;
  final TextUnescapeService textUnescapeService;
  final SqlFormatService sqlFormatService;
  final XmlFormatService xmlFormatService;
  final DateTime Function()? currentTime;
  final Base64DecodeFilePicker? base64DecodeFilePicker;
  final Base64DecodeFileSaver? base64DecodeFileSaver;
  final Base64DecodeClipboardReader? base64DecodeClipboardReader;
  final Base64DecodeClipboardWriter? base64DecodeClipboardWriter;
  final Base64DecodePreviewDecoder? base64DecodePreviewDecoder;
  final Base64EncodeFilePicker? base64EncodeFilePicker;
  final Base64EncodeFileSaver? base64EncodeFileSaver;
  final Base64EncodeClipboardReader? base64EncodeClipboardReader;
  final Base64EncodeClipboardWriter? base64EncodeClipboardWriter;
  final Base64EncodeOutputEncoder? base64EncodeOutputEncoder;
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
  final ListCompareFilePicker? listCompareLeftFilePicker;
  final ListCompareFilePicker? listCompareRightFilePicker;
  final ListCompareFileSaver? listCompareFileSaver;
  final ListCompareClipboardReader? listCompareLeftClipboardReader;
  final ListCompareClipboardReader? listCompareRightClipboardReader;
  final ListCompareClipboardWriter? listCompareClipboardWriter;
  final NumberBaseFilePicker? numberBaseFilePicker;
  final NumberBaseFileSaver? numberBaseFileSaver;
  final NumberBaseClipboardReader? numberBaseClipboardReader;
  final NumberBaseClipboardWriter? numberBaseClipboardWriter;
  final TextAnalyzeFilePicker? textAnalyzeFilePicker;
  final TextAnalyzeFileSaver? textAnalyzeFileSaver;
  final TextAnalyzeClipboardReader? textAnalyzeClipboardReader;
  final TextAnalyzeClipboardWriter? textAnalyzeClipboardWriter;
  final TextCompareFilePicker? textCompareLeftFilePicker;
  final TextCompareFilePicker? textCompareRightFilePicker;
  final TextCompareFileSaver? textCompareFileSaver;
  final TextCompareClipboardReader? textCompareLeftClipboardReader;
  final TextCompareClipboardReader? textCompareRightClipboardReader;
  final TextCompareClipboardWriter? textCompareClipboardWriter;
  final TextEscapeFilePicker? textEscapeFilePicker;
  final TextEscapeFileSaver? textEscapeFileSaver;
  final TextEscapeClipboardReader? textEscapeClipboardReader;
  final TextEscapeClipboardWriter? textEscapeClipboardWriter;
  final TextTransformFilePicker? textTransformFilePicker;
  final TextTransformFileSaver? textTransformFileSaver;
  final TextTransformClipboardReader? textTransformClipboardReader;
  final TextTransformClipboardWriter? textTransformClipboardWriter;
  final TextUnescapeFilePicker? textUnescapeFilePicker;
  final TextUnescapeFileSaver? textUnescapeFileSaver;
  final TextUnescapeClipboardReader? textUnescapeClipboardReader;
  final TextUnescapeClipboardWriter? textUnescapeClipboardWriter;
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

  final HtmlDecodeOperationService htmlDecodeService;
  final HtmlDecodeFilePicker? htmlDecodeFilePicker;
  final HtmlDecodeClipboardReader? htmlDecodeClipboardReader;
  final HtmlDecodeClipboardWriter? htmlDecodeClipboardWriter;
  final HtmlDecodeFileSaver? htmlDecodeFileSaver;
  final HtmlDecodeOutputEncoder? htmlDecodeOutputEncoder;
  final UrlDecodeOperationService urlDecodeService;
  final UrlDecodeFilePicker? urlDecodeFilePicker;
  final UrlDecodeClipboardReader? urlDecodeClipboardReader;
  final UrlDecodeClipboardWriter? urlDecodeClipboardWriter;
  final UrlDecodeFileSaver? urlDecodeFileSaver;
  final UrlDecodeOutputEncoder? urlDecodeOutputEncoder;

  final HtmlEncodeOperationService htmlEncodeService;
  final HtmlEncodeFilePicker? htmlEncodeFilePicker;
  final HtmlEncodeClipboardReader? htmlEncodeClipboardReader;
  final HtmlEncodeClipboardWriter? htmlEncodeClipboardWriter;
  final HtmlEncodeFileSaver? htmlEncodeFileSaver;
  final HtmlEncodeOutputEncoder? htmlEncodeOutputEncoder;
  final UrlEncodeOperationService urlEncodeService;
  final UrlEncodeFilePicker? urlEncodeFilePicker;
  final UrlEncodeClipboardReader? urlEncodeClipboardReader;
  final UrlEncodeClipboardWriter? urlEncodeClipboardWriter;
  final UrlEncodeFileSaver? urlEncodeFileSaver;
  final UrlEncodeOutputEncoder? urlEncodeOutputEncoder;

  final GzipCompressOperationService gzipCompressService;
  final GzipCompressFilePicker? gzipCompressFilePicker;
  final GzipCompressClipboardReader? gzipCompressClipboardReader;
  final GzipCompressFileSaver? gzipCompressFileSaver;
  final GzipDecompressOperationService gzipDecompressService;
  final GzipDecompressFilePicker? gzipDecompressFilePicker;
  final GzipDecompressClipboardWriter? gzipDecompressClipboardWriter;
  final GzipDecompressFileSaver? gzipDecompressFileSaver;
}

final class _RoutedChimeraAppState extends State<_RoutedChimeraApp> {
  static const MessageCatalog _catalog = MessageCatalog();
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(
      jwtCreateService: widget.jwtCreateService,
      jwtCreateFilePicker: widget.jwtCreateFilePicker ?? pickJwtCreateFile,
      jwtCreateClipboardReader:
          widget.jwtCreateClipboardReader ?? readJwtCreateClipboard,
      jwtCreateClipboardWriter:
          widget.jwtCreateClipboardWriter ?? writeJwtCreateClipboard,
      jwtCreateFileSaver: widget.jwtCreateFileSaver ?? saveJwtCreateFile,
      jwtInspectService: widget.jwtInspectService,
      jwtInspectFilePicker: widget.jwtInspectFilePicker ?? pickJwtInspectFile,
      jwtInspectClipboardReader:
          widget.jwtInspectClipboardReader ?? readJwtInspectClipboard,
      jwtInspectClipboardWriter:
          widget.jwtInspectClipboardWriter ?? writeJwtInspectClipboard,
      qrDecodeService: widget.qrDecodeService,
      qrDecodeFilePicker: widget.qrDecodeFilePicker ?? pickQrDecodeFile,
      qrDecodeClipboardWriter:
          widget.qrDecodeClipboardWriter ?? writeQrDecodeClipboard,
      qrDecodeFileSaver: widget.qrDecodeFileSaver ?? saveQrDecodeFile,
      qrEncodeService: widget.qrEncodeService,
      qrEncodeFilePicker: widget.qrEncodeFilePicker ?? pickQrEncodeFile,
      qrEncodeClipboardReader:
          widget.qrEncodeClipboardReader ?? readQrEncodeClipboard,
      qrEncodeFileSaver: widget.qrEncodeFileSaver ?? saveQrEncodeFile,
      htmlDecodeService: widget.htmlDecodeService,
      htmlDecodeFilePicker: widget.htmlDecodeFilePicker ?? pickHtmlDecodeFile,
      htmlDecodeClipboardReader:
          widget.htmlDecodeClipboardReader ?? readHtmlDecodeClipboard,
      htmlDecodeClipboardWriter:
          widget.htmlDecodeClipboardWriter ?? writeHtmlDecodeClipboard,
      htmlDecodeFileSaver: widget.htmlDecodeFileSaver ?? saveHtmlDecodeFile,
      htmlDecodeOutputEncoder:
          widget.htmlDecodeOutputEncoder ?? encodeHtmlDecodeOutput,
      urlDecodeService: widget.urlDecodeService,
      urlDecodeFilePicker: widget.urlDecodeFilePicker ?? pickUrlDecodeFile,
      urlDecodeClipboardReader:
          widget.urlDecodeClipboardReader ?? readUrlDecodeClipboard,
      urlDecodeClipboardWriter:
          widget.urlDecodeClipboardWriter ?? writeUrlDecodeClipboard,
      urlDecodeFileSaver: widget.urlDecodeFileSaver ?? saveUrlDecodeFile,
      urlDecodeOutputEncoder:
          widget.urlDecodeOutputEncoder ?? encodeUrlDecodeOutput,
      htmlEncodeService: widget.htmlEncodeService,
      htmlEncodeFilePicker: widget.htmlEncodeFilePicker ?? pickHtmlEncodeFile,
      htmlEncodeClipboardReader:
          widget.htmlEncodeClipboardReader ?? readHtmlEncodeClipboard,
      htmlEncodeClipboardWriter:
          widget.htmlEncodeClipboardWriter ?? writeHtmlEncodeClipboard,
      htmlEncodeFileSaver: widget.htmlEncodeFileSaver ?? saveHtmlEncodeFile,
      htmlEncodeOutputEncoder:
          widget.htmlEncodeOutputEncoder ?? encodeHtmlEncodeOutput,
      urlEncodeService: widget.urlEncodeService,
      urlEncodeFilePicker: widget.urlEncodeFilePicker ?? pickUrlEncodeFile,
      urlEncodeClipboardReader:
          widget.urlEncodeClipboardReader ?? readUrlEncodeClipboard,
      urlEncodeClipboardWriter:
          widget.urlEncodeClipboardWriter ?? writeUrlEncodeClipboard,
      urlEncodeFileSaver: widget.urlEncodeFileSaver ?? saveUrlEncodeFile,
      urlEncodeOutputEncoder:
          widget.urlEncodeOutputEncoder ?? encodeUrlEncodeOutput,
      gzipCompressService: widget.gzipCompressService,
      gzipCompressFilePicker:
          widget.gzipCompressFilePicker ?? pickGzipCompressFile,
      gzipCompressClipboardReader:
          widget.gzipCompressClipboardReader ?? readGzipCompressClipboard,
      gzipCompressFileSaver:
          widget.gzipCompressFileSaver ?? saveGzipCompressFile,
      gzipDecompressService: widget.gzipDecompressService,
      gzipDecompressFilePicker:
          widget.gzipDecompressFilePicker ?? pickGzipDecompressFile,
      gzipDecompressClipboardWriter:
          widget.gzipDecompressClipboardWriter ?? writeGzipDecompressClipboard,
      gzipDecompressFileSaver:
          widget.gzipDecompressFileSaver ?? saveGzipDecompressFile,
      certificateConvertService: widget.certificateConvertService,
      certificateConvertFilePicker:
          widget.certificateConvertFilePicker ?? pickCertificateConvertFile,
      certificateConvertFileSaver:
          widget.certificateConvertFileSaver ?? saveCertificateConvertFile,
      certificateConvertClipboardReader:
          widget.certificateConvertClipboardReader ??
          readCertificateConvertClipboard,
      certificateConvertClipboardWriter:
          widget.certificateConvertClipboardWriter ??
          writeCertificateConvertClipboard,
      certificateInspectService: widget.certificateInspectService,
      certificateInspectFilePicker:
          widget.certificateInspectFilePicker ?? pickCertificateInspectFile,
      certificateInspectClipboardReader:
          widget.certificateInspectClipboardReader ??
          readCertificateInspectClipboard,
      certificateInspectClipboardWriter:
          widget.certificateInspectClipboardWriter ??
          writeCertificateInspectClipboard,
      catalog: _catalog,
      localeTag: widget.localeTag,
      base64DecodeService: widget.base64DecodeService,
      base64EncodeService: widget.base64EncodeService,
      cronService: widget.cronService,
      dateService: widget.dateService,
      jsonCsvService: widget.jsonCsvService,
      jsonFormatService: widget.jsonFormatService,
      jsonTableService: widget.jsonTableService,
      jsonYamlService: widget.jsonYamlService,
      listCompareService: widget.listCompareService,
      numberBaseService: widget.numberBaseService,
      textAnalyzeService: widget.textAnalyzeService,
      textCompareService: widget.textCompareService,
      textEscapeService: widget.textEscapeService,
      textTransformService: widget.textTransformService,
      textUnescapeService: widget.textUnescapeService,
      sqlFormatService: widget.sqlFormatService,
      xmlFormatService: widget.xmlFormatService,
      currentTime: widget.currentTime ?? DateTime.now,
      base64DecodeFilePicker:
          widget.base64DecodeFilePicker ?? pickBase64DecodeFile,
      base64DecodeFileSaver:
          widget.base64DecodeFileSaver ?? saveBase64DecodeFile,
      base64DecodeClipboardReader:
          widget.base64DecodeClipboardReader ?? readBase64DecodeClipboard,
      base64DecodeClipboardWriter:
          widget.base64DecodeClipboardWriter ?? writeBase64DecodeClipboard,
      base64DecodePreviewDecoder:
          widget.base64DecodePreviewDecoder ?? decodeBase64Preview,
      base64EncodeFilePicker:
          widget.base64EncodeFilePicker ?? pickBase64EncodeFile,
      base64EncodeFileSaver:
          widget.base64EncodeFileSaver ?? saveBase64EncodeFile,
      base64EncodeClipboardReader:
          widget.base64EncodeClipboardReader ?? readBase64EncodeClipboard,
      base64EncodeClipboardWriter:
          widget.base64EncodeClipboardWriter ?? writeBase64EncodeClipboard,
      base64EncodeOutputEncoder:
          widget.base64EncodeOutputEncoder ?? encodeBase64Output,
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
      listCompareLeftFilePicker:
          widget.listCompareLeftFilePicker ?? pickListCompareFile,
      listCompareRightFilePicker:
          widget.listCompareRightFilePicker ?? pickListCompareFile,
      listCompareFileSaver: widget.listCompareFileSaver ?? saveListCompareFile,
      listCompareLeftClipboardReader:
          widget.listCompareLeftClipboardReader ?? readListCompareClipboard,
      listCompareRightClipboardReader:
          widget.listCompareRightClipboardReader ?? readListCompareClipboard,
      listCompareClipboardWriter:
          widget.listCompareClipboardWriter ?? writeListCompareClipboard,
      numberBaseFilePicker: widget.numberBaseFilePicker ?? pickNumberBaseFile,
      numberBaseFileSaver: widget.numberBaseFileSaver ?? saveNumberBaseFile,
      numberBaseClipboardReader:
          widget.numberBaseClipboardReader ?? readNumberBaseClipboard,
      numberBaseClipboardWriter:
          widget.numberBaseClipboardWriter ?? writeNumberBaseClipboard,
      textAnalyzeFilePicker:
          widget.textAnalyzeFilePicker ?? pickTextAnalyzeFile,
      textAnalyzeFileSaver: widget.textAnalyzeFileSaver ?? saveTextAnalyzeFile,
      textAnalyzeClipboardReader:
          widget.textAnalyzeClipboardReader ?? readTextAnalyzeClipboard,
      textAnalyzeClipboardWriter:
          widget.textAnalyzeClipboardWriter ?? writeTextAnalyzeClipboard,
      textCompareLeftFilePicker:
          widget.textCompareLeftFilePicker ?? pickTextCompareFile,
      textCompareRightFilePicker:
          widget.textCompareRightFilePicker ?? pickTextCompareFile,
      textCompareFileSaver: widget.textCompareFileSaver ?? saveTextCompareFile,
      textCompareLeftClipboardReader:
          widget.textCompareLeftClipboardReader ?? readTextCompareClipboard,
      textCompareRightClipboardReader:
          widget.textCompareRightClipboardReader ?? readTextCompareClipboard,
      textCompareClipboardWriter:
          widget.textCompareClipboardWriter ?? writeTextCompareClipboard,
      textEscapeFilePicker: widget.textEscapeFilePicker ?? pickTextEscapeFile,
      textEscapeFileSaver: widget.textEscapeFileSaver ?? saveTextEscapeFile,
      textEscapeClipboardReader:
          widget.textEscapeClipboardReader ?? readTextEscapeClipboard,
      textEscapeClipboardWriter:
          widget.textEscapeClipboardWriter ?? writeTextEscapeClipboard,
      textTransformFilePicker:
          widget.textTransformFilePicker ?? pickTextTransformFile,
      textTransformFileSaver:
          widget.textTransformFileSaver ?? saveTextTransformFile,
      textTransformClipboardReader:
          widget.textTransformClipboardReader ?? readTextTransformClipboard,
      textTransformClipboardWriter:
          widget.textTransformClipboardWriter ?? writeTextTransformClipboard,
      textUnescapeFilePicker:
          widget.textUnescapeFilePicker ?? pickTextUnescapeFile,
      textUnescapeFileSaver:
          widget.textUnescapeFileSaver ?? saveTextUnescapeFile,
      textUnescapeClipboardReader:
          widget.textUnescapeClipboardReader ?? readTextUnescapeClipboard,
      textUnescapeClipboardWriter:
          widget.textUnescapeClipboardWriter ?? writeTextUnescapeClipboard,
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
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6750A4),
        // Preserve the web engine's Roboto fallback before emoji, including
        // when a platform/system or monospace font is unavailable. Both fonts
        // load before startup, so editing emoji never fetches a font.
        fontFamilyFallback: kIsWeb
            ? const ['Roboto', 'Noto Color Emoji']
            : null,
      ),
    );
  }
}
