import 'dart:async';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'alphabet_decode_page.dart';
import 'alphabet_encode_page.dart';
import 'base64_decode_page.dart';
import 'base64_encode_page.dart';
import 'card_page.dart';
import 'certificate_convert_page.dart';
import 'certificate_inspect_page.dart';
import 'checksum_generate_page.dart';
import 'cipher_decode_page.dart';
import 'cipher_encode_page.dart';
import 'cron_page.dart';
import 'date_page.dart';
import 'dotnet_project_page.dart';
import 'gzip_compress_page.dart';
import 'gzip_decompress_page.dart';
import 'hash_generate_page.dart';
import 'html_decode_page.dart';
import 'html_encode_page.dart';
import 'identity_document_page.dart';
import 'json_csv_page.dart';
import 'json_format_page.dart';
import 'json_table_page.dart';
import 'json_yaml_page.dart';
import 'jwt_create_page.dart';
import 'jwt_inspect_page.dart';
import 'language_preferences.dart';
import 'list_compare_page.dart';
import 'lorem_page.dart';
import 'number_base_page.dart';
import 'password_page.dart';
import 'person_page.dart';
import 'project_template_page.dart';
import 'qr_decode_page.dart';
import 'qr_encode_page.dart';
import 'sql_format_page.dart';
import 'text_analyze_page.dart';
import 'text_compare_page.dart';
import 'text_escape_page.dart';
import 'text_transform_page.dart';
import 'text_unescape_page.dart';
import 'theme_preferences.dart';
import 'update_page.dart';
import 'url_decode_page.dart';
import 'url_encode_page.dart';
import 'uuid_page.dart';
import 'xml_format_page.dart';

GoRouter buildRouter({
  required LoremOperationService loremService,
  required LoremClipboardWriter loremClipboardWriter,
  required LoremFileSaver loremFileSaver,
  required LoremOutputEncoder loremOutputEncoder,
  required PasswordOperationService passwordService,
  required PasswordClipboardWriter passwordClipboardWriter,
  required PasswordFileSaver passwordFileSaver,
  required PasswordOutputEncoder passwordOutputEncoder,
  required UuidOperationService uuidService,
  required UuidClipboardWriter uuidClipboardWriter,
  required UuidFileSaver uuidFileSaver,
  required UuidOutputEncoder uuidOutputEncoder,
  required CardOperationService cardService,
  required CardClipboardWriter cardClipboardWriter,
  required CardFileSaver cardFileSaver,
  required CardOutputEncoder cardOutputEncoder,
  required IdentityDocumentOperationService identityDocumentService,
  required IdentityDocumentClipboardWriter identityDocumentClipboardWriter,
  required IdentityDocumentFileSaver identityDocumentFileSaver,
  required IdentityDocumentOutputEncoder identityDocumentOutputEncoder,
  required PersonOperationService personService,
  required PersonClipboardWriter personClipboardWriter,
  required PersonFileSaver personFileSaver,
  required PersonOutputEncoder personOutputEncoder,
  required JwtCreateOperationService jwtCreateService,
  required JwtCreateFilePicker jwtCreateFilePicker,
  required JwtCreateClipboardReader jwtCreateClipboardReader,
  required JwtCreateClipboardWriter jwtCreateClipboardWriter,
  required JwtCreateFileSaver jwtCreateFileSaver,
  required JwtInspectOperationService jwtInspectService,
  required JwtInspectFilePicker jwtInspectFilePicker,
  required JwtInspectClipboardReader jwtInspectClipboardReader,
  required JwtInspectClipboardWriter jwtInspectClipboardWriter,
  required QrDecodeOperationService qrDecodeService,
  required QrDecodeFilePicker qrDecodeFilePicker,
  required QrDecodeClipboardWriter qrDecodeClipboardWriter,
  required QrDecodeFileSaver qrDecodeFileSaver,
  required QrEncodeOperationService qrEncodeService,
  required QrEncodeFilePicker qrEncodeFilePicker,
  required QrEncodeClipboardReader qrEncodeClipboardReader,
  required QrEncodeFileSaver qrEncodeFileSaver,
  required UrlDecodeOperationService urlDecodeService,
  required UrlDecodeFilePicker urlDecodeFilePicker,
  required UrlDecodeClipboardReader urlDecodeClipboardReader,
  required UrlDecodeClipboardWriter urlDecodeClipboardWriter,
  required UrlDecodeFileSaver urlDecodeFileSaver,
  required UrlDecodeOutputEncoder urlDecodeOutputEncoder,
  required HtmlDecodeOperationService htmlDecodeService,
  required HtmlDecodeFilePicker htmlDecodeFilePicker,
  required HtmlDecodeClipboardReader htmlDecodeClipboardReader,
  required HtmlDecodeClipboardWriter htmlDecodeClipboardWriter,
  required HtmlDecodeFileSaver htmlDecodeFileSaver,
  required HtmlDecodeOutputEncoder htmlDecodeOutputEncoder,
  required ChecksumGenerateOperationService checksumGenerateService,
  required ChecksumGenerateFilePicker checksumGenerateFilePicker,
  required ChecksumGenerateClipboardReader checksumGenerateClipboardReader,
  required ChecksumGenerateClipboardWriter checksumGenerateClipboardWriter,
  required ChecksumGenerateFileSaver checksumGenerateFileSaver,
  required ChecksumGenerateOutputEncoder checksumGenerateOutputEncoder,
  required HashGenerateOperationService hashGenerateService,
  required HashGenerateFilePicker hashGenerateFilePicker,
  required HashGenerateClipboardReader hashGenerateClipboardReader,
  required HashGenerateClipboardWriter hashGenerateClipboardWriter,
  required HashGenerateFileSaver hashGenerateFileSaver,
  required HashGenerateOutputEncoder hashGenerateOutputEncoder,
  required HtmlEncodeOperationService htmlEncodeService,
  required HtmlEncodeFilePicker htmlEncodeFilePicker,
  required HtmlEncodeClipboardReader htmlEncodeClipboardReader,
  required HtmlEncodeClipboardWriter htmlEncodeClipboardWriter,
  required HtmlEncodeFileSaver htmlEncodeFileSaver,
  required HtmlEncodeOutputEncoder htmlEncodeOutputEncoder,
  required UrlEncodeOperationService urlEncodeService,
  required UrlEncodeFilePicker urlEncodeFilePicker,
  required UrlEncodeClipboardReader urlEncodeClipboardReader,
  required UrlEncodeClipboardWriter urlEncodeClipboardWriter,
  required UrlEncodeFileSaver urlEncodeFileSaver,
  required UrlEncodeOutputEncoder urlEncodeOutputEncoder,
  required CipherEncodeOperationService cipherEncodeService,
  required CipherEncodeFilePicker cipherEncodeFilePicker,
  required CipherEncodeClipboardReader cipherEncodeClipboardReader,
  required CipherEncodeClipboardWriter cipherEncodeClipboardWriter,
  required CipherEncodeFileSaver cipherEncodeFileSaver,
  required CipherEncodeOutputEncoder cipherEncodeOutputEncoder,
  required AlphabetEncodeOperationService alphabetEncodeService,
  required AlphabetEncodeFilePicker alphabetEncodeFilePicker,
  required AlphabetEncodeClipboardReader alphabetEncodeClipboardReader,
  required AlphabetEncodeClipboardWriter alphabetEncodeClipboardWriter,
  required AlphabetEncodeFileSaver alphabetEncodeFileSaver,
  required AlphabetEncodeOutputEncoder alphabetEncodeOutputEncoder,
  required AlphabetDecodeOperationService alphabetDecodeService,
  required AlphabetDecodeFilePicker alphabetDecodeFilePicker,
  required AlphabetDecodeClipboardReader alphabetDecodeClipboardReader,
  required AlphabetDecodeClipboardWriter alphabetDecodeClipboardWriter,
  required AlphabetDecodeFileSaver alphabetDecodeFileSaver,
  required AlphabetDecodeOutputEncoder alphabetDecodeOutputEncoder,
  required CipherDecodeOperationService cipherDecodeService,
  required CipherDecodeFilePicker cipherDecodeFilePicker,
  required CipherDecodeClipboardReader cipherDecodeClipboardReader,
  required CipherDecodeClipboardWriter cipherDecodeClipboardWriter,
  required CipherDecodeFileSaver cipherDecodeFileSaver,
  required CipherDecodeOutputEncoder cipherDecodeOutputEncoder,
  required GzipCompressOperationService gzipCompressService,
  required GzipCompressFilePicker gzipCompressFilePicker,
  required GzipCompressClipboardReader gzipCompressClipboardReader,
  required GzipCompressFileSaver gzipCompressFileSaver,
  required GzipDecompressOperationService gzipDecompressService,
  required GzipDecompressFilePicker gzipDecompressFilePicker,
  required GzipDecompressClipboardWriter gzipDecompressClipboardWriter,
  required GzipDecompressFileSaver gzipDecompressFileSaver,
  required CertificateConvertOperationService certificateConvertService,
  required CertificateConvertFilePicker certificateConvertFilePicker,
  required CertificateConvertFileSaver certificateConvertFileSaver,
  required CertificateConvertClipboardReader certificateConvertClipboardReader,
  required CertificateConvertClipboardWriter certificateConvertClipboardWriter,
  required CertificateInspectOperationService certificateInspectService,
  required CertificateInspectFilePicker certificateInspectFilePicker,
  required CertificateInspectClipboardReader certificateInspectClipboardReader,
  required CertificateInspectClipboardWriter certificateInspectClipboardWriter,
  required bool updateChecksEnabled,
  required UpdateCheckCallback? updateChecker,
  required UpdateApplyCallback? updateApplier,
  required MessageCatalog catalog,
  required LanguagePreferenceController languageController,
  required ThemePreferenceController themeController,
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
  String localeTag() => languageController.localeTag;

  return GoRouter(
    refreshListenable: languageController,
    initialLocation: initialLocation,
    routes: <RouteBase>[
      if (updateChecksEnabled && updateChecker != null)
        GoRoute(
          path: '/update/check',
          builder: (context, state) => UpdatePage(
            catalog: catalog,
            localeTag: localeTag(),
            checker: updateChecker,
            applier: updateApplier,
          ),
        ),
      GoRoute(
        path: '/card/generate',
        builder: (context, state) => CardPage(
          catalog: catalog,
          localeTag: localeTag(),
          service: cardService,
          clipboardWriter: cardClipboardWriter,
          fileSaver: cardFileSaver,
          outputEncoder: cardOutputEncoder,
        ),
      ),
      GoRoute(
        path: '/document/generate',
        builder: (context, state) => IdentityDocumentPage(
          catalog: catalog,
          localeTag: localeTag(),
          service: identityDocumentService,
          clipboardWriter: identityDocumentClipboardWriter,
          fileSaver: identityDocumentFileSaver,
          outputEncoder: identityDocumentOutputEncoder,
        ),
      ),
      GoRoute(
        path: '/person/generate',
        builder: (context, state) => PersonPage(
          catalog: catalog,
          localeTag: localeTag(),
          service: personService,
          clipboardWriter: personClipboardWriter,
          fileSaver: personFileSaver,
          outputEncoder: personOutputEncoder,
        ),
      ),
      GoRoute(
        path: '/uuid/generate',
        builder: (context, state) => UuidPage(
          catalog: catalog,
          localeTag: localeTag(),
          service: uuidService,
          clipboardWriter: uuidClipboardWriter,
          fileSaver: uuidFileSaver,
          outputEncoder: uuidOutputEncoder,
        ),
      ),
      GoRoute(
        path: '/password/generate',
        builder: (context, state) => PasswordPage(
          catalog: catalog,
          localeTag: localeTag(),
          service: passwordService,
          clipboardWriter: passwordClipboardWriter,
          fileSaver: passwordFileSaver,
          outputEncoder: passwordOutputEncoder,
        ),
      ),
      GoRoute(
        path: '/lorem/generate',
        builder: (context, state) => LoremPage(
          catalog: catalog,
          localeTag: localeTag(),
          service: loremService,
          clipboardWriter: loremClipboardWriter,
          fileSaver: loremFileSaver,
          outputEncoder: loremOutputEncoder,
        ),
      ),
      GoRoute(
        path: '/checksum/generate',
        builder: (context, state) => ChecksumGeneratePage(
          catalog: catalog,
          localeTag: localeTag(),
          service: checksumGenerateService,
          filePicker: checksumGenerateFilePicker,
          clipboardReader: checksumGenerateClipboardReader,
          clipboardWriter: checksumGenerateClipboardWriter,
          fileSaver: checksumGenerateFileSaver,
          outputEncoder: checksumGenerateOutputEncoder,
        ),
      ),
      GoRoute(
        path: '/jwt/create',
        builder: (context, state) => JwtCreatePage(
          catalog: catalog,
          localeTag: localeTag(),
          service: jwtCreateService,
          filePicker: jwtCreateFilePicker,
          clipboardReader: jwtCreateClipboardReader,
          clipboardWriter: jwtCreateClipboardWriter,
          fileSaver: jwtCreateFileSaver,
        ),
      ),
      GoRoute(
        path: '/jwt/inspect',
        builder: (context, state) => JwtInspectPage(
          catalog: catalog,
          localeTag: localeTag(),
          service: jwtInspectService,
          filePicker: jwtInspectFilePicker,
          clipboardReader: jwtInspectClipboardReader,
          clipboardWriter: jwtInspectClipboardWriter,
        ),
      ),
      GoRoute(
        path: '/qr/decode',
        builder: (context, state) => QrDecodePage(
          catalog: catalog,
          localeTag: localeTag(),
          service: qrDecodeService,
          filePicker: qrDecodeFilePicker,
          clipboardWriter: qrDecodeClipboardWriter,
          fileSaver: qrDecodeFileSaver,
        ),
      ),
      GoRoute(
        path: '/qr/encode',
        builder: (context, state) => QrEncodePage(
          catalog: catalog,
          localeTag: localeTag(),
          service: qrEncodeService,
          filePicker: qrEncodeFilePicker,
          clipboardReader: qrEncodeClipboardReader,
          fileSaver: qrEncodeFileSaver,
        ),
      ),
      GoRoute(
        path: '/url/decode',
        builder: (context, state) => UrlDecodePage(
          catalog: catalog,
          localeTag: localeTag(),
          service: urlDecodeService,
          filePicker: urlDecodeFilePicker,
          clipboardReader: urlDecodeClipboardReader,
          clipboardWriter: urlDecodeClipboardWriter,
          fileSaver: urlDecodeFileSaver,
          outputEncoder: urlDecodeOutputEncoder,
        ),
      ),
      GoRoute(
        path: '/html/decode',
        builder: (context, state) => HtmlDecodePage(
          catalog: catalog,
          localeTag: localeTag(),
          service: htmlDecodeService,
          filePicker: htmlDecodeFilePicker,
          clipboardReader: htmlDecodeClipboardReader,
          clipboardWriter: htmlDecodeClipboardWriter,
          fileSaver: htmlDecodeFileSaver,
          outputEncoder: htmlDecodeOutputEncoder,
        ),
      ),
      GoRoute(
        path: '/hash/generate',
        builder: (context, state) => HashGeneratePage(
          catalog: catalog,
          localeTag: localeTag(),
          service: hashGenerateService,
          filePicker: hashGenerateFilePicker,
          clipboardReader: hashGenerateClipboardReader,
          clipboardWriter: hashGenerateClipboardWriter,
          fileSaver: hashGenerateFileSaver,
          outputEncoder: hashGenerateOutputEncoder,
        ),
      ),
      GoRoute(
        path: '/html/encode',
        builder: (context, state) => HtmlEncodePage(
          catalog: catalog,
          localeTag: localeTag(),
          service: htmlEncodeService,
          filePicker: htmlEncodeFilePicker,
          clipboardReader: htmlEncodeClipboardReader,
          clipboardWriter: htmlEncodeClipboardWriter,
          fileSaver: htmlEncodeFileSaver,
          outputEncoder: htmlEncodeOutputEncoder,
        ),
      ),
      GoRoute(
        path: '/url/encode',
        builder: (context, state) => UrlEncodePage(
          catalog: catalog,
          localeTag: localeTag(),
          service: urlEncodeService,
          filePicker: urlEncodeFilePicker,
          clipboardReader: urlEncodeClipboardReader,
          clipboardWriter: urlEncodeClipboardWriter,
          fileSaver: urlEncodeFileSaver,
          outputEncoder: urlEncodeOutputEncoder,
        ),
      ),
      GoRoute(
        path: '/cipher/encode',
        builder: (context, state) => CipherEncodePage(
          catalog: catalog,
          localeTag: localeTag(),
          service: cipherEncodeService,
          filePicker: cipherEncodeFilePicker,
          clipboardReader: cipherEncodeClipboardReader,
          clipboardWriter: cipherEncodeClipboardWriter,
          fileSaver: cipherEncodeFileSaver,
          outputEncoder: cipherEncodeOutputEncoder,
        ),
      ),
      GoRoute(
        path: '/cipher/decode',
        builder: (context, state) => CipherDecodePage(
          catalog: catalog,
          localeTag: localeTag(),
          service: cipherDecodeService,
          filePicker: cipherDecodeFilePicker,
          clipboardReader: cipherDecodeClipboardReader,
          clipboardWriter: cipherDecodeClipboardWriter,
          fileSaver: cipherDecodeFileSaver,
          outputEncoder: cipherDecodeOutputEncoder,
        ),
      ),
      GoRoute(
        path: '/alphabet/encode',
        builder: (context, state) => AlphabetEncodePage(
          catalog: catalog,
          localeTag: localeTag(),
          service: alphabetEncodeService,
          filePicker: alphabetEncodeFilePicker,
          clipboardReader: alphabetEncodeClipboardReader,
          clipboardWriter: alphabetEncodeClipboardWriter,
          fileSaver: alphabetEncodeFileSaver,
          outputEncoder: alphabetEncodeOutputEncoder,
        ),
      ),
      GoRoute(
        path: '/alphabet/decode',
        builder: (context, state) => AlphabetDecodePage(
          catalog: catalog,
          localeTag: localeTag(),
          service: alphabetDecodeService,
          filePicker: alphabetDecodeFilePicker,
          clipboardReader: alphabetDecodeClipboardReader,
          clipboardWriter: alphabetDecodeClipboardWriter,
          fileSaver: alphabetDecodeFileSaver,
          outputEncoder: alphabetDecodeOutputEncoder,
        ),
      ),
      GoRoute(
        path: '/gzip/compress',
        builder: (context, state) => GzipCompressPage(
          catalog: catalog,
          localeTag: localeTag(),
          service: gzipCompressService,
          filePicker: gzipCompressFilePicker,
          clipboardReader: gzipCompressClipboardReader,
          fileSaver: gzipCompressFileSaver,
        ),
      ),
      GoRoute(
        path: '/gzip/decompress',
        builder: (context, state) => GzipDecompressPage(
          catalog: catalog,
          localeTag: localeTag(),
          service: gzipDecompressService,
          filePicker: gzipDecompressFilePicker,
          clipboardWriter: gzipDecompressClipboardWriter,
          fileSaver: gzipDecompressFileSaver,
        ),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => AnimatedBuilder(
          animation: languageController,
          builder: (context, _) => Scaffold(
            body: Focus(
              autofocus: true,
              child: SingleChildScrollView(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Semantics(
                        key: const Key('app-title-heading'),
                        header: true,
                        child: Text(
                          catalog.lookup(localeTag(), 'app.name'),
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(catalog.lookup(localeTag(), 'app.description')),
                      const SizedBox(height: 24),
                      if (updateChecksEnabled &&
                          updateChecker != null) ...<Widget>[
                        ElevatedButton(
                          key: const Key('open-update-check'),
                          onPressed: () => context.go('/update/check'),
                          child: Text(
                            catalog.lookup(localeTag(), 'update.openAction'),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      ElevatedButton(
                        key: const Key('open-checksum-generate'),
                        onPressed: () => context.go('/checksum/generate'),
                        child: Text(
                          catalog.lookup(
                            localeTag(),
                            'checksumGenerate.openAction',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-cron'),
                        onPressed: () => context.go('/cron/parse'),
                        child: Text(
                          catalog.lookup(localeTag(), 'cron.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-json-table'),
                        onPressed: () => context.go('/json/array-to-table'),
                        child: Text(
                          catalog.lookup(localeTag(), 'jsonTable.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-json-csv'),
                        onPressed: () => context.go('/json/array-to-csv'),
                        child: Text(
                          catalog.lookup(localeTag(), 'jsonCsv.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-json-yaml'),
                        onPressed: () => context.go('/json/to-yaml'),
                        child: Text(
                          catalog.lookup(localeTag(), 'jsonYaml.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-json-format'),
                        onPressed: () => context.go('/json/format'),
                        child: Text(
                          catalog.lookup(localeTag(), 'jsonFormat.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-sql-format'),
                        onPressed: () => context.go('/sql/format'),
                        child: Text(
                          catalog.lookup(localeTag(), 'sqlFormat.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-xml-format'),
                        onPressed: () => context.go('/xml/format'),
                        child: Text(
                          catalog.lookup(localeTag(), 'xmlFormat.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-date'),
                        onPressed: () => context.go('/date/convert'),
                        child: Text(
                          catalog.lookup(localeTag(), 'date.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-number-base'),
                        onPressed: () => context.go('/number/convert-base'),
                        child: Text(
                          catalog.lookup(localeTag(), 'numberBase.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-base64-decode'),
                        onPressed: () => context.go('/base64/decode'),
                        child: Text(
                          catalog.lookup(
                            localeTag(),
                            'base64Decode.openAction',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-base64-encode'),
                        onPressed: () => context.go('/base64/encode'),
                        child: Text(
                          catalog.lookup(
                            localeTag(),
                            'base64Encode.openAction',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-text-escape'),
                        onPressed: () => context.go('/text/escape'),
                        child: Text(
                          catalog.lookup(localeTag(), 'textEscape.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-text-unescape'),
                        onPressed: () => context.go('/text/unescape'),
                        child: Text(
                          catalog.lookup(
                            localeTag(),
                            'textUnescape.openAction',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-text-transform'),
                        onPressed: () => context.go('/text/transform'),
                        child: Text(
                          catalog.lookup(
                            localeTag(),
                            'textTransform.openAction',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-text-compare'),
                        onPressed: () => context.go('/text/compare'),
                        child: Text(
                          catalog.lookup(localeTag(), 'textCompare.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-list-compare'),
                        onPressed: () => context.go('/list/compare'),
                        child: Text(
                          catalog.lookup(localeTag(), 'listCompare.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-text-analyze'),
                        onPressed: () => context.go('/text/analyze'),
                        child: Text(
                          catalog.lookup(localeTag(), 'textAnalyze.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-certificate-inspect'),
                        onPressed: () => context.go('/certificate/inspect'),
                        child: Text(
                          catalog.lookup(
                            localeTag(),
                            'certificateInspect.openAction',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-certificate-convert'),
                        onPressed: () => context.go('/certificate/convert'),
                        child: Text(
                          catalog.lookup(
                            localeTag(),
                            'certificateConvert.openAction',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-gzip-compress'),
                        onPressed: () => context.go('/gzip/compress'),
                        child: Text(
                          catalog.lookup(
                            localeTag(),
                            'gzipCompress.openAction',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-gzip-decompress'),
                        onPressed: () => context.go('/gzip/decompress'),
                        child: Text(
                          catalog.lookup(
                            localeTag(),
                            'gzipDecompress.openAction',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-lorem'),
                        onPressed: () => context.go('/lorem/generate'),
                        child: Text(
                          catalog.lookup(localeTag(), 'lorem.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-password'),
                        onPressed: () => context.go('/password/generate'),
                        child: Text(
                          catalog.lookup(localeTag(), 'password.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-uuid'),
                        onPressed: () => context.go('/uuid/generate'),
                        child: Text(
                          catalog.lookup(localeTag(), 'uuid.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-card'),
                        onPressed: () => context.go('/card/generate'),
                        child: Text(
                          catalog.lookup(localeTag(), 'card.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-identity-document'),
                        onPressed: () => context.go('/document/generate'),
                        child: Text(
                          catalog.lookup(localeTag(), 'document.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-person'),
                        onPressed: () => context.go('/person/generate'),
                        child: Text(
                          catalog.lookup(localeTag(), 'person.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-hash-generate'),
                        onPressed: () => context.go('/hash/generate'),
                        child: Text(
                          catalog.lookup(
                            localeTag(),
                            'hashGenerate.openAction',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-html-encode'),
                        onPressed: () => context.go('/html/encode'),
                        child: Text(
                          catalog.lookup(localeTag(), 'htmlEncode.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-url-encode'),
                        onPressed: () => context.go('/url/encode'),
                        child: Text(
                          catalog.lookup(localeTag(), 'urlEncode.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-cipher-encode'),
                        onPressed: () => context.go('/cipher/encode'),
                        child: Text(
                          catalog.lookup(
                            localeTag(),
                            'cipherEncode.openAction',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-cipher-decode'),
                        onPressed: () => context.go('/cipher/decode'),
                        child: Text(
                          catalog.lookup(
                            localeTag(),
                            'cipherDecode.openAction',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-alphabet-encode'),
                        onPressed: () => context.go('/alphabet/encode'),
                        child: Text(
                          catalog.lookup(
                            localeTag(),
                            'alphabetEncode.openAction',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-alphabet-decode'),
                        onPressed: () => context.go('/alphabet/decode'),
                        child: Text(
                          catalog.lookup(
                            localeTag(),
                            'alphabetDecode.openAction',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-url-decode'),
                        onPressed: () => context.go('/url/decode'),
                        child: Text(
                          catalog.lookup(localeTag(), 'urlDecode.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-html-decode'),
                        onPressed: () => context.go('/html/decode'),
                        child: Text(
                          catalog.lookup(localeTag(), 'htmlDecode.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-jwt-create'),
                        onPressed: () => context.go('/jwt/create'),
                        child: Text(
                          catalog.lookup(localeTag(), 'jwtCreate.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-jwt-inspect'),
                        onPressed: () => context.go('/jwt/inspect'),
                        child: Text(
                          catalog.lookup(localeTag(), 'jwtInspect.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-qr-encode'),
                        onPressed: () => context.go('/qr/encode'),
                        child: Text(
                          catalog.lookup(localeTag(), 'qrEncode.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-qr-decode'),
                        onPressed: () => context.go('/qr/decode'),
                        child: Text(
                          catalog.lookup(localeTag(), 'qrDecode.openAction'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-project-template'),
                        onPressed: () => context.go('/project/from-template'),
                        child: Text(
                          catalog.lookup(localeTag(), 'scaffold.title'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('open-dotnet-project'),
                        onPressed: () => context.go('/dotnet/init-project'),
                        child: Text(
                          catalog.lookup(localeTag(), 'dotnetProject.title'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _ThemePreferencePanel(
                        controller: themeController,
                        catalog: catalog,
                        localeTag: localeTag(),
                      ),
                      const SizedBox(height: 12),
                      _LanguagePreferencePanel(
                        controller: languageController,
                        catalog: catalog,
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
        path: '/project/from-template',
        builder: (context, state) =>
            ProjectTemplatePage(localeTag: localeTag()),
      ),
      GoRoute(
        path: '/dotnet/init-project',
        builder: (context, state) => DotnetProjectPage(localeTag: localeTag()),
      ),
      GoRoute(
        path: '/cron/parse',
        builder: (context, state) => CronPage(
          catalog: catalog,
          localeTag: localeTag(),
          service: cronService,
          currentTime: currentTime,
          filePicker: cronFilePicker,
        ),
      ),
      GoRoute(
        path: '/date/convert',
        builder: (context, state) => DatePage(
          catalog: catalog,
          localeTag: localeTag(),
          service: dateService,
          filePicker: dateFilePicker,
        ),
      ),
      GoRoute(
        path: '/json/array-to-table',
        builder: (context, state) => JsonTablePage(
          catalog: catalog,
          localeTag: localeTag(),
          service: jsonTableService,
          filePicker: jsonTableFilePicker,
        ),
      ),
      GoRoute(
        path: '/json/array-to-csv',
        builder: (context, state) => JsonCsvPage(
          catalog: catalog,
          localeTag: localeTag(),
          service: jsonCsvService,
          filePicker: jsonCsvFilePicker,
          fileSaver: jsonCsvFileSaver,
        ),
      ),
      GoRoute(
        path: '/json/to-yaml',
        builder: (context, state) => JsonYamlPage(
          catalog: catalog,
          localeTag: localeTag(),
          service: jsonYamlService,
          filePicker: jsonYamlFilePicker,
          fileSaver: jsonYamlFileSaver,
        ),
      ),
      GoRoute(
        path: '/json/format',
        builder: (context, state) => JsonFormatPage(
          catalog: catalog,
          localeTag: localeTag(),
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
          localeTag: localeTag(),
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
          localeTag: localeTag(),
          service: base64DecodeService,
          filePicker: base64DecodeFilePicker,
          fileSaver: base64DecodeFileSaver,
          clipboardReader: base64DecodeClipboardReader,
          clipboardWriter: base64DecodeClipboardWriter,
          previewDecoder: base64DecodePreviewDecoder,
        ),
      ),
      GoRoute(
        path: '/certificate/inspect',
        builder: (context, state) => CertificateInspectPage(
          catalog: catalog,
          localeTag: localeTag(),
          service: certificateInspectService,
          filePicker: certificateInspectFilePicker,
          clipboardReader: certificateInspectClipboardReader,
          clipboardWriter: certificateInspectClipboardWriter,
        ),
      ),
      GoRoute(
        path: '/certificate/convert',
        builder: (context, state) => CertificateConvertPage(
          catalog: catalog,
          localeTag: localeTag(),
          service: certificateConvertService,
          filePicker: certificateConvertFilePicker,
          fileSaver: certificateConvertFileSaver,
          clipboardReader: certificateConvertClipboardReader,
          clipboardWriter: certificateConvertClipboardWriter,
        ),
      ),
      GoRoute(
        path: '/base64/encode',
        builder: (context, state) => Base64EncodePage(
          catalog: catalog,
          localeTag: localeTag(),
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
          localeTag: localeTag(),
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
          localeTag: localeTag(),
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
          localeTag: localeTag(),
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
          localeTag: localeTag(),
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
          localeTag: localeTag(),
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
          localeTag: localeTag(),
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
          localeTag: localeTag(),
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
          localeTag: localeTag(),
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

final class _ThemePreferencePanel extends StatelessWidget {
  const _ThemePreferencePanel({
    required this.controller,
    required this.catalog,
    required this.localeTag,
  });

  final ThemePreferenceController controller;
  final MessageCatalog catalog;
  final String localeTag;

  String _message(String key) => catalog.lookup(localeTag, 'theme.$key');

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final selectedLabel = controller.mode == ThemeMode.dark
            ? _message('dark')
            : _message('light');
        final statusTheme = localeTag == 'pt-BR'
            ? selectedLabel.toLowerCase()
            : selectedLabel;
        final status = switch (controller.status) {
          ThemePreferenceStatus.idle => null,
          ThemePreferenceStatus.saving => _message('saving'),
          ThemePreferenceStatus.saved => _message(
            'saved',
          ).replaceFirst('{theme}', statusTheme),
          ThemePreferenceStatus.notSaved => _message(
            'notSaved',
          ).replaceFirst('{theme}', statusTheme),
        };

        return Semantics(
          container: true,
          explicitChildNodes: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        _message('title'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_message('description')),
                    const SizedBox(height: 16),
                    Text(
                      _message('label'),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<ThemeMode>(
                      key: const Key('theme-selector'),
                      direction: Axis.vertical,
                      showSelectedIcon: true,
                      segments: [
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text(_message('light')),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text(_message('dark')),
                        ),
                      ],
                      selected: {controller.mode},
                      onSelectionChanged: (selection) {
                        unawaited(controller.select(selection.single));
                      },
                    ),
                    if (status != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        key: const Key('theme-status'),
                        liveRegion: true,
                        container: true,
                        child: Text(status),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

final class _LanguagePreferencePanel extends StatelessWidget {
  const _LanguagePreferencePanel({
    required this.controller,
    required this.catalog,
  });

  final LanguagePreferenceController controller;
  final MessageCatalog catalog;

  String _message(String key) =>
      catalog.lookup(controller.localeTag, 'language.$key');

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final selectedLabel = _message(controller.localeTag);
        final status = switch (controller.status) {
          LanguagePreferenceStatus.idle => null,
          LanguagePreferenceStatus.saving => _message('saving'),
          LanguagePreferenceStatus.saved => _message(
            'saved',
          ).replaceFirst('{language}', selectedLabel),
          LanguagePreferenceStatus.notSaved => _message(
            'notSaved',
          ).replaceFirst('{language}', selectedLabel),
        };

        return Semantics(
          container: true,
          explicitChildNodes: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        _message('title'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_message('description')),
                    const SizedBox(height: 16),
                    Text(
                      _message('label'),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      key: const Key('language-selector'),
                      direction: Axis.vertical,
                      showSelectedIcon: true,
                      segments: [
                        ButtonSegment(value: 'en', label: Text(_message('en'))),
                        ButtonSegment(
                          value: 'pt-BR',
                          label: Text(_message('pt-BR')),
                        ),
                      ],
                      selected: {controller.localeTag},
                      onSelectionChanged: (selection) {
                        unawaited(controller.select(selection.single));
                      },
                    ),
                    if (status != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        key: const Key('language-status'),
                        liveRegion: true,
                        container: true,
                        child: Text(status),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
