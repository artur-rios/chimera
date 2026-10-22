import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_platform/chimera_platform.dart';
import 'package:chimera_platform/native_updates.dart';
import 'package:chimera_platform/transactional_file_writer.dart'
    as native_output;
import 'package:chimera_platform/type_periodic_terminal.dart';
import 'package:chimera_utilities/chimera_utilities.dart';

import 'dotnet_build.dart';

import 'dotnet_clean_command.dart';
import 'output_sink.dart';
import 'project_commands.dart';

const String _defaultUpdateRepository = String.fromEnvironment(
  'CHIMERA_RELEASE_REPOSITORY',
  defaultValue: 'artur-rios/chimera',
);
const String _defaultInstalledVersion = String.fromEnvironment(
  'CHIMERA_VERSION',
  defaultValue: '0.1.0',
);

typedef TextReader = Future<String> Function();
typedef FileTextReader = Future<String> Function(String path);
typedef BytesReader = Future<List<int>> Function();
typedef FileBytesReader = Future<List<int>> Function(String path);
typedef FileBytesWriter = Future<void> Function(String path, List<int> bytes);
typedef JsonObjectEncoder = String Function(Object? value);
typedef TryReserveFile = Future<bool> Function(File candidate);
typedef CopyFile = Future<void> Function(File source, File destination);
typedef RenameFile = Future<void> Function(File source, String destinationPath);
typedef DeleteFile = Future<void> Function(File file);

// Preserve the public CLI test/injection contract while sharing native writes.
typedef TransactionalFileOperations = native_output.FileTransactionOperations;

Future<int> runChimera(
  List<String> args, {
  required String localeTag,
  required StringSink out,
  required StringSink err,
  TextReader? readStandardInput,
  FileTextReader? readFile,
  BytesReader? readStandardInputBytes,
  FileBytesReader? readFileBytes,
  FileBytesWriter? writeOutputFile,
  FileBytesWriter? writeOutputStage,
  TransactionalFileOperations outputFileOperations =
      const TransactionalFileOperations(),
  LoremService loremService = const LoremService(),
  JsonObjectEncoder? loremJsonEncoder,
  PasswordService passwordService = const PasswordService(),
  JsonObjectEncoder? passwordJsonEncoder,
  UuidService uuidService = const UuidService(),
  JsonObjectEncoder? uuidJsonEncoder,
  CardService cardService = const CardService(),
  JsonObjectEncoder? cardJsonEncoder,
  IdentityDocumentService identityDocumentService =
      const IdentityDocumentService(),
  JsonObjectEncoder? identityDocumentJsonEncoder,
  PersonService personService = const PersonService(),
  JsonObjectEncoder? personJsonEncoder,
  Base64EncodeService base64EncodeService = const Base64EncodeService(),
  Base64DecodeService base64DecodeService = const Base64DecodeService(),
  JsonObjectEncoder? base64DecodeJsonEncoder,
  GzipCompressService gzipCompressService = const GzipCompressService(),
  JsonObjectEncoder? gzipCompressJsonEncoder,
  GzipDecompressService gzipDecompressService = const GzipDecompressService(),
  JsonObjectEncoder? gzipDecompressJsonEncoder,
  UrlDecodeService urlDecodeService = const UrlDecodeService(),
  JsonObjectEncoder? urlDecodeJsonEncoder,
  HtmlDecodeService htmlDecodeService = const HtmlDecodeService(),
  JsonObjectEncoder? htmlDecodeJsonEncoder,
  HashGenerateService hashGenerateService = const HashGenerateService(),
  JsonObjectEncoder? hashGenerateJsonEncoder,
  HtmlEncodeService htmlEncodeService = const HtmlEncodeService(),
  JsonObjectEncoder? htmlEncodeJsonEncoder,
  UrlEncodeService urlEncodeService = const UrlEncodeService(),
  JsonObjectEncoder? urlEncodeJsonEncoder,
  CipherEncodeService cipherEncodeService = const CipherEncodeService(),
  JsonObjectEncoder? cipherEncodeJsonEncoder,
  AlphabetEncodeService alphabetEncodeService = const AlphabetEncodeService(),
  JsonObjectEncoder? alphabetEncodeJsonEncoder,
  AlphabetDecodeService alphabetDecodeService = const AlphabetDecodeService(),
  JsonObjectEncoder? alphabetDecodeJsonEncoder,
  CipherDecodeService cipherDecodeService = const CipherDecodeService(),
  JsonObjectEncoder? cipherDecodeJsonEncoder,
  CertificateInspectService certificateInspectService =
      const CertificateInspectService(),
  JsonObjectEncoder? certificateInspectJsonEncoder,
  CertificateConvertService certificateConvertService =
      const CertificateConvertService(),
  JsonObjectEncoder? certificateConvertJsonEncoder,
  JwtCreateService jwtCreateService = const JwtCreateService(),
  JsonObjectEncoder? jwtCreateJsonEncoder,
  JwtInspectService jwtInspectService = const JwtInspectService(),
  JsonObjectEncoder? jwtInspectJsonEncoder,
  QrEncodeService qrEncodeService = const QrEncodeService(),
  JsonObjectEncoder? qrEncodeJsonEncoder,
  QrDecodeService qrDecodeService = const QrDecodeService(),
  JsonObjectEncoder? qrDecodeJsonEncoder,
  ChecksumGenerateService checksumGenerateService =
      const ChecksumGenerateService(),
  JsonObjectEncoder? checksumGenerateJsonEncoder,
  CronService cronService = const CronService(),
  DateService dateService = const DateService(),
  JsonCsvService jsonCsvService = const JsonCsvService(),
  JsonFormatService jsonFormatService = const JsonFormatService(),
  JsonTableService jsonTableService = const JsonTableService(),
  JsonYamlService jsonYamlService = const JsonYamlService(),
  ListCompareService listCompareService = const ListCompareService(),
  NumberBaseService numberBaseService = const NumberBaseService(),
  TextAnalyzeService textAnalyzeService = const TextAnalyzeService(),
  TextCompareService textCompareService = const TextCompareService(),
  TextEscapeService textEscapeService = const TextEscapeService(),
  TextTransformService textTransformService = const TextTransformService(),
  TextUnescapeService textUnescapeService = const TextUnescapeService(),
  SqlFormatService sqlFormatService = const SqlFormatService(),
  XmlFormatService xmlFormatService = const XmlFormatService(),
  TypePeriodicService? typePeriodicService,
  PeriodicCancellation? periodicCancellation,
  UpdateCheckService? updateCheckService,
  UpdateApplyService? updateApplyService,
  ScaffoldOperationService? scaffoldService,
  DateTime Function()? currentTime,
}) async {
  if (args.isNotEmpty && args.first == 'project') {
    return runProjectCommand(
      args.sublist(1),
      localeTag: localeTag,
      out: out,
      err: err,
      service: scaffoldService,
    );
  }
  if (args.isNotEmpty && args.first == 'dotnet') {
    if (args.length >= 2 && args[1] == 'build') {
      return runDotnetBuild(
        args.sublist(2),
        localeTag: localeTag,
        out: out,
        err: err,
      );
    }
    err.writeln(
      const MessageCatalog().lookup(localeTag, 'cli.dotnetBuildUsage'),
    );
    return 64;
  }
  const catalog = MessageCatalog();
  if (args.length >= 2 && args[0] == 'dotnet' && args[1] == 'clean') {
    return runDotnetCleanCommand(
      args.sublist(2),
      localeTag: localeTag,
      out: out,
      err: err,
      readConfirmation: readStandardInput,
    );
  }
  final parser = _buildParser();

  try {
    final parsed = parser.parse(_normalizeMultilineListOptions(args));
    if (parsed.flag('help')) {
      final key = parsed.command?.name == 'terminal'
          ? 'cli.typePeriodicUsage'
          : parsed.command?.name == 'person'
          ? 'cli.personUsage'
          : parsed.command?.name == 'document'
          ? 'cli.documentUsage'
          : parsed.command?.name == 'card'
          ? 'cli.cardUsage'
          : parsed.command?.name == 'uuid'
          ? 'cli.uuidUsage'
          : parsed.command?.name == 'password'
          ? 'cli.passwordUsage'
          : parsed.command?.name == 'lorem'
          ? 'cli.loremUsage'
          : parsed.command?.name == 'checksum' &&
                parsed.command?.command?.name == 'generate'
          ? 'cli.checksumGenerateUsage'
          : parsed.command?.name == 'qr' &&
                parsed.command?.command?.name == 'encode'
          ? 'cli.qrEncodeUsage'
          : parsed.command?.name == 'qr' &&
                parsed.command?.command?.name == 'decode'
          ? 'cli.qrDecodeUsage'
          : parsed.command?.name == 'jwt' &&
                parsed.command?.command?.name == 'inspect'
          ? 'cli.jwtInspectUsage'
          : parsed.command?.name == 'jwt' &&
                parsed.command?.command?.name == 'create'
          ? 'cli.jwtCreateUsage'
          : parsed.command?.name == 'hash' &&
                parsed.command?.command?.name == 'generate'
          ? 'cli.hashGenerateUsage'
          : parsed.command?.name == 'url' &&
                parsed.command?.command?.name == 'decode'
          ? 'cli.urlDecodeUsage'
          : parsed.command?.name == 'html' &&
                parsed.command?.command?.name == 'decode'
          ? 'cli.htmlDecodeUsage'
          : parsed.command?.name == 'html' &&
                parsed.command?.command?.name == 'encode'
          ? 'cli.htmlEncodeUsage'
          : parsed.command?.name == 'url' &&
                parsed.command?.command?.name == 'encode'
          ? 'cli.urlEncodeUsage'
          : parsed.command?.name == 'cipher' &&
                parsed.command?.command?.name == 'encode'
          ? 'cli.cipherEncodeUsage'
          : parsed.command?.name == 'cipher' &&
                parsed.command?.command?.name == 'decode'
          ? 'cli.cipherDecodeUsage'
          : parsed.command?.name == 'alphabet' &&
                parsed.command?.command?.name == 'encode'
          ? 'cli.alphabetEncodeUsage'
          : parsed.command?.name == 'alphabet' &&
                parsed.command?.command?.name == 'decode'
          ? 'cli.alphabetDecodeUsage'
          : parsed.command?.name == 'gzip' &&
                parsed.command?.command?.name == 'compress'
          ? 'cli.gzipCompressUsage'
          : parsed.command?.name == 'gzip' &&
                parsed.command?.command?.name == 'decompress'
          ? 'cli.gzipDecompressUsage'
          : parsed.command?.name == 'certificate' &&
                parsed.command?.command?.name == 'convert'
          ? 'cli.certificateConvertUsage'
          : parsed.command?.name == 'update' &&
                parsed.command?.command?.name == 'check'
          ? 'cli.updateCheckUsage'
          : parsed.command?.name == 'update' &&
                parsed.command?.command?.name == 'apply'
          ? 'cli.updateApplyUsage'
          : 'cli.usage';
      out.writeln(catalog.lookup(localeTag, key));
      return 0;
    }
    if (parsed.command == null) {
      err.writeln(catalog.lookup(localeTag, 'cli.noCommand'));
      return 64;
    }
    if (parsed.command!.name == 'terminal' &&
        parsed.command!.command?.name == 'type-periodic') {
      final command = parsed.command!.command!;
      if (command.rest.isNotEmpty) {
        err.writeln(catalog.lookup(localeTag, 'cli.typePeriodicUsage'));
        return 64;
      }
      final cancellation = periodicCancellation ?? PeriodicCancellation();
      final signals = <StreamSubscription<ProcessSignal>>[];
      try {
        if (periodicCancellation == null) {
          signals.add(
            ProcessSignal.sigint.watch().listen((_) => cancellation.cancel()),
          );
          if (!Platform.isWindows) {
            signals.add(
              ProcessSignal.sigterm.watch().listen(
                (_) => cancellation.cancel(),
              ),
            );
          }
        }
        final result =
            await (typePeriodicService ??
                    TypePeriodicService(terminal: createPeriodicTerminal()))
                .run(
                  interval: command.option('interval'),
                  cancellation: cancellation,
                  onStarted: (seconds) => out.writeln(
                    catalog
                        .lookup(localeTag, 'typePeriodic.running')
                        .replaceAll('{seconds}', '$seconds'),
                  ),
                );
        return result.fold<int>(
          onSuccess: (value) {
            out.writeln(
              catalog
                  .lookup(localeTag, 'typePeriodic.stopped')
                  .replaceAll('{count}', '${value.sentCount}'),
            );
            return 0;
          },
          onFailure: (failure) {
            err.writeln(catalog.lookup(localeTag, failure.messageKey));
            return 1;
          },
        );
      } finally {
        for (final signal in signals) {
          await signal.cancel();
        }
      }
    }
    if (parsed.command!.name == 'update' &&
        parsed.command!.command?.name == 'check') {
      return await _runUpdateCheck(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        service:
            updateCheckService ??
            UpdateCheckService(GitHubReleaseMetadataSource()),
      );
    }
    if (parsed.command!.name == 'update' &&
        parsed.command!.command?.name == 'apply') {
      return await _runUpdateApply(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        checkService:
            updateCheckService ??
            UpdateCheckService(GitHubReleaseMetadataSource()),
        applyService: updateApplyService,
      );
    }
    if (parsed.command!.name == 'lorem' &&
        parsed.command!.command?.name == 'generate') {
      return await _runLorem(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        service: loremService,
        encodeJson: loremJsonEncoder ?? jsonEncode,
        writeOutputFile:
            writeOutputFile ??
            (path, bytes) => _writeFileTransactionally(
              path,
              bytes,
              writeStage: writeOutputStage ?? _writeFileStageExactly,
              operations: outputFileOperations,
            ),
      );
    }
    if (parsed.command!.name == 'password' &&
        parsed.command!.command?.name == 'generate') {
      return await _runPassword(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        service: passwordService,
        encodeJson: passwordJsonEncoder ?? jsonEncode,
        writeOutputFile:
            writeOutputFile ??
            (path, bytes) => _writeFileTransactionally(
              path,
              bytes,
              writeStage: writeOutputStage ?? _writeFileStageExactly,
              operations: outputFileOperations,
            ),
      );
    }
    if (parsed.command!.name == 'uuid' &&
        parsed.command!.command?.name == 'generate') {
      return await _runUuid(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        service: uuidService,
        encodeJson: uuidJsonEncoder ?? jsonEncode,
        writeOutputFile:
            writeOutputFile ??
            (path, bytes) => _writeFileTransactionally(
              path,
              bytes,
              writeStage: writeOutputStage ?? _writeFileStageExactly,
              operations: outputFileOperations,
            ),
      );
    }
    if (parsed.command!.name == 'card' &&
        parsed.command!.command?.name == 'generate') {
      return await _runCard(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        service: cardService,
        encodeJson: cardJsonEncoder ?? jsonEncode,
        writeOutputFile:
            writeOutputFile ??
            (path, bytes) => _writeFileTransactionally(
              path,
              bytes,
              writeStage: writeOutputStage ?? _writeFileStageExactly,
              operations: outputFileOperations,
            ),
      );
    }
    if (parsed.command!.name == 'document' &&
        parsed.command!.command?.name == 'generate') {
      return await _runIdentityDocument(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        service: identityDocumentService,
        encodeJson: identityDocumentJsonEncoder ?? jsonEncode,
        writeOutputFile:
            writeOutputFile ??
            (path, bytes) => _writeFileTransactionally(
              path,
              bytes,
              writeStage: writeOutputStage ?? _writeFileStageExactly,
              operations: outputFileOperations,
            ),
      );
    }
    if (parsed.command!.name == 'person' &&
        parsed.command!.command?.name == 'generate') {
      return await _runPerson(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        service: personService,
        encodeJson: personJsonEncoder ?? jsonEncode,
        writeOutputFile:
            writeOutputFile ??
            (path, bytes) => _writeFileTransactionally(
              path,
              bytes,
              writeStage: writeOutputStage ?? _writeFileStageExactly,
              operations: outputFileOperations,
            ),
      );
    }
    if (parsed.command!.name == 'checksum' &&
        parsed.command!.command?.name == 'generate') {
      return await _runChecksumGenerate(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInputBytes:
            readStandardInputBytes ?? _readStandardInputBytes,
        readFileBytes: readFileBytes ?? (path) => File(path).readAsBytes(),
        writeOutputFile:
            writeOutputFile ??
            (path, bytes) => _writeFileTransactionally(
              path,
              bytes,
              writeStage: writeOutputStage ?? _writeFileStageExactly,
              operations: outputFileOperations,
            ),
        service: checksumGenerateService,
        encodeJson: checksumGenerateJsonEncoder ?? jsonEncode,
      );
    }
    if (parsed.command!.name == 'qr' &&
        parsed.command!.command?.name == 'encode') {
      return await _runQrEncode(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInputBytes:
            readStandardInputBytes ?? _readQrEncodeStandardInputBytes,
        readFileBytes: readFileBytes ?? _readQrEncodeFileBytes,
        writeOutputFile:
            writeOutputFile ??
            (path, bytes) => _writeFileTransactionally(
              path,
              bytes,
              writeStage: writeOutputStage ?? _writeFileStageExactly,
              operations: outputFileOperations,
            ),
        service: qrEncodeService,
        encodeJson: qrEncodeJsonEncoder ?? jsonEncode,
      );
    }
    if (parsed.command!.name == 'qr' &&
        parsed.command!.command?.name == 'decode') {
      return await _runQrDecode(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInputBytes:
            readStandardInputBytes ?? _readQrDecodeStandardInputBytes,
        readFileBytes: readFileBytes ?? _readQrDecodeFileBytes,
        writeOutputFile:
            writeOutputFile ??
            (path, bytes) => _writeFileTransactionally(
              path,
              bytes,
              writeStage: writeOutputStage ?? _writeFileStageExactly,
              operations: outputFileOperations,
            ),
        service: qrDecodeService,
        encodeJson: qrDecodeJsonEncoder ?? jsonEncode,
      );
    }
    if (parsed.command!.name == 'jwt' &&
        parsed.command!.command?.name == 'create') {
      return await _runJwtCreate(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInputBytes:
            readStandardInputBytes ?? _readStandardInputBytes,
        readFileBytes: readFileBytes ?? (path) => File(path).readAsBytes(),
        writeOutputFile:
            writeOutputFile ??
            (path, bytes) => _writeFileTransactionally(
              path,
              bytes,
              writeStage: writeOutputStage ?? _writeFileStageExactly,
              operations: outputFileOperations,
            ),
        service: jwtCreateService,
        encodeJson: jwtCreateJsonEncoder ?? jsonEncode,
      );
    }
    if (parsed.command!.name == 'jwt' &&
        parsed.command!.command?.name == 'inspect') {
      return await _runJwtInspect(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInputBytes:
            readStandardInputBytes ?? _readJwtInspectStandardInputBytes,
        readFileBytes: readFileBytes ?? _readJwtInspectFileBytes,
        service: jwtInspectService,
        encodeJson: jwtInspectJsonEncoder ?? jsonEncode,
      );
    }
    if (parsed.command!.name == 'url' &&
        parsed.command!.command?.name == 'decode') {
      return await _runUrlDecode(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInputBytes:
            readStandardInputBytes ?? _readStandardInputBytes,
        readFileBytes: readFileBytes ?? (path) => File(path).readAsBytes(),
        writeOutputFile:
            writeOutputFile ??
            (path, bytes) => _writeFileTransactionally(
              path,
              bytes,
              writeStage: writeOutputStage ?? _writeFileStageExactly,
              operations: outputFileOperations,
            ),
        service: urlDecodeService,
        encodeJson: urlDecodeJsonEncoder ?? jsonEncode,
      );
    }
    if (parsed.command!.name == 'html' &&
        parsed.command!.command?.name == 'decode') {
      return await _runHtmlDecode(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInputBytes:
            readStandardInputBytes ?? _readStandardInputBytes,
        readFileBytes: readFileBytes ?? (path) => File(path).readAsBytes(),
        writeOutputFile:
            writeOutputFile ??
            (path, bytes) => _writeFileTransactionally(
              path,
              bytes,
              writeStage: writeOutputStage ?? _writeFileStageExactly,
              operations: outputFileOperations,
            ),
        service: htmlDecodeService,
        encodeJson: htmlDecodeJsonEncoder ?? jsonEncode,
      );
    }
    if (parsed.command!.name == 'hash' &&
        parsed.command!.command?.name == 'generate') {
      return await _runHashGenerate(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInputBytes:
            readStandardInputBytes ?? _readStandardInputBytes,
        readFileBytes: readFileBytes ?? (path) => File(path).readAsBytes(),
        writeOutputFile:
            writeOutputFile ??
            (path, bytes) => _writeFileTransactionally(
              path,
              bytes,
              writeStage: writeOutputStage ?? _writeFileStageExactly,
              operations: outputFileOperations,
            ),
        service: hashGenerateService,
        encodeJson: hashGenerateJsonEncoder ?? jsonEncode,
      );
    }
    if (parsed.command!.name == 'html' &&
        parsed.command!.command?.name == 'encode') {
      return await _runHtmlEncode(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInputBytes:
            readStandardInputBytes ?? _readStandardInputBytes,
        readFileBytes: readFileBytes ?? (path) => File(path).readAsBytes(),
        writeOutputFile:
            writeOutputFile ??
            (path, bytes) => _writeFileTransactionally(
              path,
              bytes,
              writeStage: writeOutputStage ?? _writeFileStageExactly,
              operations: outputFileOperations,
            ),
        service: htmlEncodeService,
        encodeJson: htmlEncodeJsonEncoder ?? jsonEncode,
      );
    }
    if (parsed.command!.name == 'url' &&
        parsed.command!.command?.name == 'encode') {
      return await _runUrlEncode(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInputBytes:
            readStandardInputBytes ?? _readStandardInputBytes,
        readFileBytes: readFileBytes ?? (path) => File(path).readAsBytes(),
        writeOutputFile:
            writeOutputFile ??
            (path, bytes) => _writeFileTransactionally(
              path,
              bytes,
              writeStage: writeOutputStage ?? _writeFileStageExactly,
              operations: outputFileOperations,
            ),
        service: urlEncodeService,
        encodeJson: urlEncodeJsonEncoder ?? jsonEncode,
      );
    }
    if (parsed.command!.name == 'cipher' &&
        parsed.command!.command?.name == 'encode') {
      return await _runCipherEncode(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInputBytes:
            readStandardInputBytes ?? _readStandardInputBytes,
        readFileBytes: readFileBytes ?? (path) => File(path).readAsBytes(),
        writeOutputFile:
            writeOutputFile ??
            (path, bytes) => _writeFileTransactionally(
              path,
              bytes,
              writeStage: writeOutputStage ?? _writeFileStageExactly,
              operations: outputFileOperations,
            ),
        service: cipherEncodeService,
        encodeJson: cipherEncodeJsonEncoder ?? jsonEncode,
      );
    }
    if (parsed.command!.name == 'cipher' &&
        parsed.command!.command?.name == 'decode') {
      return await _runCipherDecode(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInputBytes:
            readStandardInputBytes ?? _readStandardInputBytes,
        readFileBytes: readFileBytes ?? (path) => File(path).readAsBytes(),
        writeOutputFile:
            writeOutputFile ??
            (path, bytes) => _writeFileTransactionally(
              path,
              bytes,
              writeStage: writeOutputStage ?? _writeFileStageExactly,
              operations: outputFileOperations,
            ),
        service: cipherDecodeService,
        encodeJson: cipherDecodeJsonEncoder ?? jsonEncode,
      );
    }
    if (parsed.command!.name == 'alphabet' &&
        parsed.command!.command?.name == 'encode') {
      return await _runAlphabetEncode(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInputBytes:
            readStandardInputBytes ?? _readStandardInputBytes,
        readFileBytes: readFileBytes ?? (path) => File(path).readAsBytes(),
        writeOutputFile:
            writeOutputFile ??
            (path, bytes) => _writeFileTransactionally(
              path,
              bytes,
              writeStage: writeOutputStage ?? _writeFileStageExactly,
              operations: outputFileOperations,
            ),
        service: alphabetEncodeService,
        encodeJson: alphabetEncodeJsonEncoder ?? jsonEncode,
      );
    }
    if (parsed.command!.name == 'alphabet' &&
        parsed.command!.command?.name == 'decode') {
      return await _runAlphabetDecode(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInputBytes:
            readStandardInputBytes ?? _readStandardInputBytes,
        readFileBytes: readFileBytes ?? (path) => File(path).readAsBytes(),
        writeOutputFile:
            writeOutputFile ??
            (path, bytes) => _writeFileTransactionally(
              path,
              bytes,
              writeStage: writeOutputStage ?? _writeFileStageExactly,
              operations: outputFileOperations,
            ),
        service: alphabetDecodeService,
        encodeJson: alphabetDecodeJsonEncoder ?? jsonEncode,
      );
    }
    if (parsed.command!.name == 'gzip' &&
        parsed.command!.command?.name == 'compress') {
      return await _runGzipCompress(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInputBytes:
            readStandardInputBytes ?? _readStandardInputBytes,
        readFileBytes: readFileBytes ?? (path) => File(path).readAsBytes(),
        writeOutputFile:
            writeOutputFile ??
            (path, bytes) => _writeFileTransactionally(
              path,
              bytes,
              writeStage: writeOutputStage ?? _writeFileStageExactly,
              operations: outputFileOperations,
            ),
        service: gzipCompressService,
        encodeJson: gzipCompressJsonEncoder ?? jsonEncode,
      );
    }
    if (parsed.command!.name == 'gzip' &&
        parsed.command!.command?.name == 'decompress') {
      return await _runGzipDecompress(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInputBytes:
            readStandardInputBytes ?? _readStandardInputBytes,
        readFileBytes: readFileBytes ?? (path) => File(path).readAsBytes(),
        writeOutputFile:
            writeOutputFile ??
            (path, bytes) => _writeFileTransactionally(
              path,
              bytes,
              writeStage: writeOutputStage ?? _writeFileStageExactly,
              operations: outputFileOperations,
            ),
        service: gzipDecompressService,
        encodeJson: gzipDecompressJsonEncoder ?? jsonEncode,
      );
    }
    if (parsed.command!.name == 'certificate' &&
        parsed.command!.command?.name == 'convert') {
      return await _runCertificateConvert(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInputBytes:
            readStandardInputBytes ?? _readStandardInputBytes,
        readFileBytes: readFileBytes ?? (path) => File(path).readAsBytes(),
        writeOutputFile:
            writeOutputFile ??
            (path, bytes) => _writeFileTransactionally(
              path,
              bytes,
              writeStage: writeOutputStage ?? _writeFileStageExactly,
              operations: outputFileOperations,
            ),
        service: certificateConvertService,
        encodeJson: certificateConvertJsonEncoder ?? jsonEncode,
      );
    }
    if (parsed.command!.name == 'certificate' &&
        parsed.command!.command?.name == 'inspect') {
      return await _runCertificateInspect(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInputBytes:
            readStandardInputBytes ?? _readStandardInputBytes,
        readFileBytes: readFileBytes ?? (path) => File(path).readAsBytes(),
        service: certificateInspectService,
        encodeJson: certificateInspectJsonEncoder ?? jsonEncode,
      );
    }
    if (parsed.command!.name == 'base64' &&
        parsed.command!.command?.name == 'encode') {
      return await _runBase64Encode(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInputBytes:
            readStandardInputBytes ?? _readStandardInputBytes,
        readFileBytes: readFileBytes ?? (path) => File(path).readAsBytes(),
        writeOutputFile: writeOutputFile ?? _writeFileExactly,
        base64EncodeService: base64EncodeService,
      );
    }
    if (parsed.command!.name == 'base64' &&
        parsed.command!.command?.name == 'decode') {
      return await _runBase64Decode(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInputBytes:
            readStandardInputBytes ?? _readStandardInputBytes,
        readFileBytes: readFileBytes ?? (path) => File(path).readAsBytes(),
        writeOutputFile:
            writeOutputFile ??
            (path, bytes) => _writeFileTransactionally(
              path,
              bytes,
              writeStage: writeOutputStage ?? _writeFileStageExactly,
              operations: outputFileOperations,
            ),
        base64DecodeService: base64DecodeService,
        encodeJson: base64DecodeJsonEncoder ?? jsonEncode,
      );
    }
    if (parsed.command!.name == 'cron' &&
        parsed.command!.command?.name == 'parse') {
      return await _runCronParse(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        cronService: cronService,
        currentTime: currentTime ?? DateTime.now,
      );
    }
    if (parsed.command!.name == 'date' &&
        parsed.command!.command?.name == 'convert') {
      return await _runDateConvert(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        dateService: dateService,
      );
    }
    if (parsed.command!.name == 'number' &&
        parsed.command!.command?.name == 'convert-base') {
      return await _runNumberBaseConvert(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        writeOutputFile: writeOutputFile ?? _writeFileExactly,
        numberBaseService: numberBaseService,
      );
    }
    if (parsed.command!.name == 'text' &&
        parsed.command!.command?.name == 'analyze') {
      return await _runTextAnalyze(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        writeOutputFile: writeOutputFile ?? _writeFileExactly,
        textAnalyzeService: textAnalyzeService,
      );
    }
    if (parsed.command!.name == 'text' &&
        parsed.command!.command?.name == 'compare') {
      return await _runTextCompare(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        writeOutputFile: writeOutputFile ?? _writeFileExactly,
        textCompareService: textCompareService,
      );
    }
    if (parsed.command!.name == 'text' &&
        parsed.command!.command?.name == 'escape') {
      return await _runTextEscape(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        writeOutputFile: writeOutputFile ?? _writeFileExactly,
        textEscapeService: textEscapeService,
      );
    }
    if (parsed.command!.name == 'text' &&
        parsed.command!.command?.name == 'transform') {
      return await _runTextTransform(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        writeOutputFile: writeOutputFile ?? _writeFileExactly,
        textTransformService: textTransformService,
      );
    }
    if (parsed.command!.name == 'text' &&
        parsed.command!.command?.name == 'unescape') {
      return await _runTextUnescape(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        writeOutputFile: writeOutputFile ?? _writeFileExactly,
        textUnescapeService: textUnescapeService,
      );
    }
    if (parsed.command!.name == 'list' &&
        parsed.command!.command?.name == 'compare') {
      return await _runListCompare(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        writeOutputFile: writeOutputFile ?? _writeFileExactly,
        listCompareService: listCompareService,
      );
    }
    if (parsed.command!.name == 'json' &&
        parsed.command!.command?.name == 'array-to-table') {
      return await _runJsonArrayToTable(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        jsonTableService: jsonTableService,
      );
    }
    if (parsed.command!.name == 'json' &&
        parsed.command!.command?.name == 'array-to-csv') {
      return await _runJsonArrayToCsv(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        writeOutputFile: writeOutputFile ?? _writeFileExactly,
        jsonCsvService: jsonCsvService,
      );
    }
    if (parsed.command!.name == 'json' &&
        parsed.command!.command?.name == 'to-yaml') {
      return await _runJsonToYaml(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        writeOutputFile: writeOutputFile ?? _writeFileExactly,
        jsonYamlService: jsonYamlService,
      );
    }
    if (parsed.command!.name == 'json' &&
        parsed.command!.command?.name == 'format') {
      return await _runJsonFormat(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        writeOutputFile: writeOutputFile ?? _writeFileExactly,
        jsonFormatService: jsonFormatService,
      );
    }
    if (parsed.command!.name == 'sql' &&
        parsed.command!.command?.name == 'format') {
      return await _runSqlFormat(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        writeOutputFile: writeOutputFile ?? _writeFileExactly,
        sqlFormatService: sqlFormatService,
      );
    }
    if (parsed.command!.name == 'xml' &&
        parsed.command!.command?.name == 'format') {
      return await _runXmlFormat(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        writeOutputFile: writeOutputFile ?? _writeFileExactly,
        xmlFormatService: xmlFormatService,
      );
    }

    err.writeln(catalog.lookup(localeTag, 'error.unexpected'));
    return 64;
  } on FormatException {
    final isPerson =
        args.length >= 2 && args[0] == 'person' && args[1] == 'generate';
    final isIdentityDocument =
        args.length >= 2 && args[0] == 'document' && args[1] == 'generate';
    final isCard =
        args.length >= 2 && args[0] == 'card' && args[1] == 'generate';
    final isUuid =
        args.length >= 2 && args[0] == 'uuid' && args[1] == 'generate';
    final isPassword =
        args.length >= 2 && args[0] == 'password' && args[1] == 'generate';
    final isLorem =
        args.length >= 2 && args[0] == 'lorem' && args[1] == 'generate';
    final isChecksumGenerate =
        args.length >= 2 && args[0] == 'checksum' && args[1] == 'generate';
    final isQrDecode =
        args.length >= 2 && args[0] == 'qr' && args[1] == 'decode';
    final isQrEncode =
        args.length >= 2 && args[0] == 'qr' && args[1] == 'encode';
    final isJwtInspect =
        args.length >= 2 && args[0] == 'jwt' && args[1] == 'inspect';
    final isJwtCreate =
        args.length >= 2 && args[0] == 'jwt' && args[1] == 'create';
    final isUrlDecode =
        args.length >= 2 && args[0] == 'url' && args[1] == 'decode';
    final isHtmlDecode =
        args.length >= 2 && args[0] == 'html' && args[1] == 'decode';
    final isHashGenerate =
        args.length >= 2 && args[0] == 'hash' && args[1] == 'generate';
    final isUrlEncode =
        args.length >= 2 && args[0] == 'url' && args[1] == 'encode';
    final isCipherEncode =
        args.length >= 2 && args[0] == 'cipher' && args[1] == 'encode';
    final isCipherDecode =
        args.length >= 2 && args[0] == 'cipher' && args[1] == 'decode';
    final isAlphabetEncode =
        args.length >= 2 && args[0] == 'alphabet' && args[1] == 'encode';
    final isAlphabetDecode =
        args.length >= 2 && args[0] == 'alphabet' && args[1] == 'decode';
    final isHtmlEncode =
        args.length >= 2 && args[0] == 'html' && args[1] == 'encode';
    final isGzipCompress =
        args.length >= 2 && args[0] == 'gzip' && args[1] == 'compress';
    final isGzipDecompress =
        args.length >= 2 && args[0] == 'gzip' && args[1] == 'decompress';
    final isBase64Encode =
        args.length >= 2 && args[0] == 'base64' && args[1] == 'encode';
    final isCertificateInspect =
        args.length >= 2 && args[0] == 'certificate' && args[1] == 'inspect';
    final isCertificateConvert =
        args.length >= 2 && args[0] == 'certificate' && args[1] == 'convert';
    final isBase64Decode =
        args.length >= 2 && args[0] == 'base64' && args[1] == 'decode';
    final isCron = args.length >= 2 && args[0] == 'cron' && args[1] == 'parse';
    final isDate =
        args.length >= 2 && args[0] == 'date' && args[1] == 'convert';
    final isNumberBase =
        args.length >= 2 && args[0] == 'number' && args[1] == 'convert-base';
    final isTextEscape =
        args.length >= 2 && args[0] == 'text' && args[1] == 'escape';
    final isTextAnalyze =
        args.length >= 2 && args[0] == 'text' && args[1] == 'analyze';
    final isTextTransform =
        args.length >= 2 && args[0] == 'text' && args[1] == 'transform';
    final isTextCompare =
        args.length >= 2 && args[0] == 'text' && args[1] == 'compare';
    final isTextUnescape =
        args.length >= 2 && args[0] == 'text' && args[1] == 'unescape';
    final isListCompare =
        args.length >= 2 && args[0] == 'list' && args[1] == 'compare';
    final isJsonTable =
        args.length >= 2 && args[0] == 'json' && args[1] == 'array-to-table';
    final isJsonCsv =
        args.length >= 2 && args[0] == 'json' && args[1] == 'array-to-csv';
    final isJsonYaml =
        args.length >= 2 && args[0] == 'json' && args[1] == 'to-yaml';
    final isJsonFormat =
        args.length >= 2 && args[0] == 'json' && args[1] == 'format';
    final isSqlFormat =
        args.length >= 2 && args[0] == 'sql' && args[1] == 'format';
    final isXmlFormat =
        args.length >= 2 && args[0] == 'xml' && args[1] == 'format';
    final isUpdateCheck =
        args.length >= 2 && args[0] == 'update' && args[1] == 'check';
    final isUpdateApply =
        args.length >= 2 && args[0] == 'update' && args[1] == 'apply';
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json:
          (isPerson ||
              isIdentityDocument ||
              isCard ||
              isUuid ||
              isPassword ||
              isLorem ||
              isChecksumGenerate ||
              isQrDecode ||
              isQrEncode ||
              isJwtInspect ||
              isJwtCreate ||
              isUrlDecode ||
              isHtmlDecode ||
              isHashGenerate ||
              isHtmlEncode ||
              isUrlEncode ||
              isCipherEncode ||
              isCipherDecode ||
              isAlphabetEncode ||
              isAlphabetDecode ||
              isBase64Encode ||
              isGzipCompress ||
              isGzipDecompress ||
              isCertificateInspect ||
              isCertificateConvert ||
              isBase64Decode ||
              isCron ||
              isDate ||
              isNumberBase ||
              isTextAnalyze ||
              isTextTransform ||
              isTextCompare ||
              isTextEscape ||
              isTextUnescape ||
              isListCompare ||
              isJsonTable ||
              isJsonCsv ||
              isJsonYaml ||
              isJsonFormat ||
              isSqlFormat ||
              isXmlFormat ||
              isUpdateCheck ||
              isUpdateApply) &&
          args.contains('--json'),
      kind: 'validation',
      code: isPerson
          ? 'person.invalid-options'
          : isIdentityDocument
          ? 'document.invalid-options'
          : isCard
          ? 'card.invalid-options'
          : isUuid
          ? 'uuid.invalid-options'
          : isPassword
          ? 'password.invalid-options'
          : isLorem
          ? 'lorem.invalid-options'
          : isChecksumGenerate
          ? 'checksum-generate.invalid-options'
          : isQrDecode
          ? 'qr-decode.invalid-options'
          : isQrEncode
          ? 'qr-encode.invalid-options'
          : isJwtInspect
          ? 'jwt-inspect.invalid-options'
          : isJwtCreate
          ? 'jwt-create.invalid-options'
          : isUrlDecode
          ? 'url-decode.invalid-options'
          : isHtmlDecode
          ? 'html-decode.invalid-options'
          : isHashGenerate
          ? 'hash-generate.invalid-options'
          : isHtmlEncode
          ? 'html-encode.invalid-options'
          : isUrlEncode
          ? 'url-encode.invalid-options'
          : isCipherEncode
          ? 'cipher.invalid-options'
          : isCipherDecode
          ? 'cipher.invalid-options'
          : isAlphabetEncode
          ? 'alphabet.invalid-options'
          : isAlphabetDecode
          ? 'alphabet.invalid-options'
          : isGzipCompress
          ? 'gzip-compress.invalid-options'
          : isGzipDecompress
          ? 'gzip-decompress.invalid-options'
          : isCertificateConvert
          ? 'certificate-convert.invalid-options'
          : isCertificateInspect
          ? 'certificate-inspect.invalid-options'
          : isBase64Encode
          ? 'base64-encode.invalid-options'
          : isBase64Decode
          ? 'base64-decode.invalid-options'
          : isCron
          ? 'cron.invalid-options'
          : isDate
          ? 'date.invalid-options'
          : isNumberBase
          ? 'number-base.invalid-options'
          : isTextAnalyze
          ? 'text-analyze.invalid-options'
          : isTextTransform
          ? 'text-transform.invalid-options'
          : isTextCompare
          ? 'text-compare.invalid-options'
          : isTextEscape
          ? 'text-escape.invalid-options'
          : isTextUnescape
          ? 'text-unescape.invalid-options'
          : isListCompare
          ? 'list-compare.invalid-options'
          : isJsonTable
          ? 'json-table.invalid-options'
          : isJsonCsv
          ? 'json-csv.invalid-options'
          : isJsonYaml
          ? 'json-yaml.invalid-options'
          : isJsonFormat
          ? 'json-format.invalid-options'
          : isSqlFormat
          ? 'sql-format.invalid-options'
          : isXmlFormat
          ? 'xml-format.invalid-options'
          : isUpdateCheck
          ? 'update-invalid-options'
          : isUpdateApply
          ? 'update-invalid-options'
          : 'cli.invalid-options',
      messageKey: isPerson
          ? 'error.person.validation'
          : isIdentityDocument
          ? 'error.document.validation'
          : isCard
          ? 'error.card.validation'
          : isUuid
          ? 'error.uuid.validation'
          : isPassword
          ? 'error.password.validation'
          : isLorem
          ? 'error.lorem.validation'
          : isChecksumGenerate
          ? 'error.checksumGenerate.validation'
          : isQrDecode
          ? 'error.qrDecode.validation'
          : isQrEncode
          ? 'error.qrEncode.validation'
          : isJwtInspect
          ? 'error.jwtInspect.validation'
          : isJwtCreate
          ? 'error.jwtCreate.validation'
          : isUrlDecode
          ? 'error.urlDecode.validation'
          : isHtmlDecode
          ? 'error.htmlDecode.validation'
          : isHashGenerate
          ? 'error.hashGenerate.validation'
          : isHtmlEncode
          ? 'error.htmlEncode.validation'
          : isUrlEncode
          ? 'error.urlEncode.validation'
          : isCipherEncode
          ? 'error.cipherEncode.validation'
          : isCipherDecode
          ? 'error.cipherDecode.validation'
          : isAlphabetEncode
          ? 'error.alphabetEncode.validation'
          : isAlphabetDecode
          ? 'error.alphabetDecode.validation'
          : isGzipCompress
          ? 'error.gzipCompress.validation'
          : isGzipDecompress
          ? 'error.gzipDecompress.validation'
          : isCertificateConvert
          ? 'error.certificateConvert.validation'
          : isCertificateInspect
          ? 'error.certificateInspect.validation'
          : isBase64Encode
          ? 'error.base64Encode.validation'
          : isBase64Decode
          ? 'error.base64Decode.validation'
          : isCron
          ? 'error.cron.validation'
          : isDate
          ? 'error.date.validation'
          : isNumberBase
          ? 'error.numberBase.validation'
          : isTextAnalyze
          ? 'error.textAnalyze.validation'
          : isTextTransform
          ? 'error.textTransform.validation'
          : isTextCompare
          ? 'error.textCompare.validation'
          : isTextEscape
          ? 'error.textEscape.validation'
          : isTextUnescape
          ? 'error.textUnescape.validation'
          : isListCompare
          ? 'error.listCompare.validation'
          : isJsonTable
          ? 'error.jsonTable.validation'
          : isJsonCsv
          ? 'error.jsonCsv.validation'
          : isJsonYaml
          ? 'error.jsonYaml.validation'
          : isJsonFormat
          ? 'error.jsonFormat.validation'
          : isSqlFormat
          ? 'error.sqlFormat.validation'
          : isXmlFormat
          ? 'error.xmlFormat.validation'
          : isUpdateCheck
          ? 'cli.updateCheckUsage'
          : isUpdateApply
          ? 'cli.updateApplyUsage'
          : 'error.unexpected',
    );
    return 64;
  }
}

ArgParser _buildParser() {
  final person = ArgParser()
    ..addCommand(
      'generate',
      ArgParser()
        ..addOption('locale', defaultsTo: 'us')
        ..addOption('min-age', defaultsTo: '18')
        ..addOption('max-age', defaultsTo: '90')
        ..addOption('count', defaultsTo: '1')
        ..addOption('output', abbr: 'o')
        ..addFlag('json', negatable: false),
    );
  final document = ArgParser()
    ..addCommand(
      'generate',
      ArgParser()
        ..addOption('locale', defaultsTo: 'us')
        ..addOption('type', defaultsTo: 'ssn')
        ..addOption('cnpj-format')
        ..addOption('count', defaultsTo: '1')
        ..addOption('output', abbr: 'o')
        ..addFlag('json', negatable: false),
    );
  final card = ArgParser()
    ..addCommand(
      'generate',
      ArgParser()
        ..addOption('network', defaultsTo: 'visa')
        ..addOption('count', defaultsTo: '1')
        ..addOption('output', abbr: 'o')
        ..addFlag('json', negatable: false),
    );
  final uuid = ArgParser()
    ..addCommand(
      'generate',
      ArgParser()
        ..addOption('version', defaultsTo: 'v4')
        ..addOption('representation', defaultsTo: 'uuid')
        ..addOption('count', defaultsTo: '1')
        ..addOption('output', abbr: 'o')
        ..addFlag('json', negatable: false),
    );
  final password = ArgParser()
    ..addCommand(
      'generate',
      ArgParser()
        ..addOption('length', defaultsTo: '16')
        ..addFlag('lowercase', defaultsTo: true)
        ..addFlag('uppercase', defaultsTo: true)
        ..addFlag('digits', defaultsTo: true)
        ..addFlag('symbols', defaultsTo: true)
        ..addOption('output', abbr: 'o')
        ..addFlag('json', negatable: false),
    );
  final lorem = ArgParser()
    ..addCommand(
      'generate',
      ArgParser()
        ..addOption('unit', defaultsTo: 'paragraphs')
        ..addOption('count', defaultsTo: '1')
        ..addOption('output', abbr: 'o')
        ..addFlag('json', negatable: false),
    );
  final jwtCreate = ArgParser()
    ..addOption('algorithm', abbr: 'a')
    ..addOption('header')
    ..addOption('header-file')
    ..addOption('claims')
    ..addOption('claims-file')
    ..addFlag('stdin', negatable: false)
    ..addOption('key')
    ..addOption('key-file')
    ..addOption('output', abbr: 'o')
    ..addFlag('json', negatable: false);
  final jwtInspect = ArgParser()
    ..addOption('token')
    ..addOption('token-file')
    ..addFlag('stdin', negatable: false)
    ..addOption('key')
    ..addOption('key-file')
    ..addFlag('json', negatable: false);
  final jwt = ArgParser()
    ..addCommand('create', jwtCreate)
    ..addCommand('inspect', jwtInspect);
  final qrEncode = ArgParser()
    ..addOption('text')
    ..addFlag('stdin', negatable: false)
    ..addOption('file', abbr: 'f')
    ..addOption('error-correction', defaultsTo: 'medium')
    ..addOption('size', defaultsTo: '512')
    ..addOption('margin', defaultsTo: '4')
    ..addOption('foreground', defaultsTo: '#000000')
    ..addOption('background', defaultsTo: '#FFFFFF')
    ..addOption('output', abbr: 'o')
    ..addFlag('json', negatable: false);
  final checksumGenerate = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addFlag('stdin', negatable: false)
    ..addOption('file', abbr: 'f')
    ..addOption('algorithm', defaultsTo: 'crc32')
    ..addOption('output', abbr: 'o')
    ..addFlag('json', negatable: false);
  final checksum = ArgParser()..addCommand('generate', checksumGenerate);
  final qrDecode = ArgParser()
    ..addFlag('stdin', negatable: false)
    ..addOption('file', abbr: 'f')
    ..addOption('output', abbr: 'o')
    ..addFlag('json', negatable: false);
  final qr = ArgParser()
    ..addCommand('encode', qrEncode)
    ..addCommand('decode', qrDecode);
  final urlDecode = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addFlag('stdin', negatable: false)
    ..addOption('file', abbr: 'f')
    ..addOption('output', abbr: 'o')
    ..addFlag('json', negatable: false);
  final htmlDecode = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addFlag('stdin', negatable: false)
    ..addOption('file', abbr: 'f')
    ..addOption('output', abbr: 'o')
    ..addFlag('json', negatable: false);
  final hashGenerate = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addFlag('stdin', negatable: false)
    ..addOption('file', abbr: 'f')
    ..addOption('algorithm', defaultsTo: 'sha256')
    ..addOption('output', abbr: 'o')
    ..addFlag('json', negatable: false);
  final hash = ArgParser()..addCommand('generate', hashGenerate);
  final htmlEncode = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addFlag('stdin', negatable: false)
    ..addOption('file', abbr: 'f')
    ..addOption('context', defaultsTo: 'all')
    ..addOption('output', abbr: 'o')
    ..addFlag('json', negatable: false);
  final urlEncode = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addFlag('stdin', negatable: false)
    ..addOption('file', abbr: 'f')
    ..addOption('mode', defaultsTo: 'component')
    ..addOption('output', abbr: 'o')
    ..addFlag('json', negatable: false);
  final url = ArgParser()
    ..addCommand('encode', urlEncode)
    ..addCommand('decode', urlDecode);
  final cipherEncode = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addFlag('stdin', negatable: false)
    ..addOption('file', abbr: 'f')
    ..addOption('cipher')
    ..addOption('character-policy', defaultsTo: 'preserve')
    ..addOption('shift')
    ..addOption('key')
    ..addOption('a')
    ..addOption('b')
    ..addOption('rails')
    ..addOption('output', abbr: 'o')
    ..addFlag('json', negatable: false);
  final cipherDecode = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addFlag('stdin', negatable: false)
    ..addOption('file', abbr: 'f')
    ..addOption('cipher')
    ..addOption('character-policy', defaultsTo: 'preserve')
    ..addOption('shift')
    ..addOption('key')
    ..addOption('a')
    ..addOption('b')
    ..addOption('rails')
    ..addOption('output', abbr: 'o')
    ..addFlag('json', negatable: false);
  final cipher = ArgParser()
    ..addCommand('encode', cipherEncode)
    ..addCommand('decode', cipherDecode);
  final alphabetEncode = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addFlag('stdin', negatable: false)
    ..addOption('file', abbr: 'f')
    ..addOption('alphabet')
    ..addOption('output', abbr: 'o')
    ..addFlag('json', negatable: false);
  final alphabetDecode = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addFlag('stdin', negatable: false)
    ..addOption('file', abbr: 'f')
    ..addOption('alphabet')
    ..addOption('output', abbr: 'o')
    ..addFlag('json', negatable: false);
  final alphabet = ArgParser()
    ..addCommand('encode', alphabetEncode)
    ..addCommand('decode', alphabetDecode);
  final html = ArgParser()
    ..addCommand('decode', htmlDecode)
    ..addCommand('encode', htmlEncode);
  final gzipCompress = ArgParser()
    ..addOption('text')
    ..addFlag('stdin', negatable: false)
    ..addOption('file', abbr: 'f')
    ..addOption('level', defaultsTo: '6')
    ..addOption('output', abbr: 'o')
    ..addFlag('json', negatable: false);
  final gzipDecompress = ArgParser()
    ..addFlag('stdin', negatable: false)
    ..addOption('file', abbr: 'f')
    ..addOption('mode')
    ..addOption('output', abbr: 'o')
    ..addFlag('json', negatable: false);
  final gzip = ArgParser()
    ..addCommand('compress', gzipCompress)
    ..addCommand('decompress', gzipDecompress);
  final certificateInspect = ArgParser()
    ..addOption('text')
    ..addFlag('stdin', negatable: false)
    ..addOption('file', abbr: 'f')
    ..addOption('format', defaultsTo: 'auto')
    ..addFlag('json', negatable: false);
  final certificateConvert = ArgParser()
    ..addOption('text')
    ..addFlag('stdin', negatable: false)
    ..addOption('file', abbr: 'f')
    ..addOption('from', defaultsTo: 'auto')
    ..addOption('to')
    ..addOption('output', abbr: 'o')
    ..addFlag('json', negatable: false);
  final certificate = ArgParser()
    ..addCommand('inspect', certificateInspect)
    ..addCommand('convert', certificateConvert);
  final base64Encode = ArgParser()
    ..addOption('text')
    ..addFlag('stdin', negatable: false)
    ..addOption('file', abbr: 'f')
    ..addOption('output', abbr: 'o')
    ..addFlag('json', negatable: false);
  final base64Decode = ArgParser()
    ..addOption('text')
    ..addFlag('stdin', negatable: false)
    ..addOption('file', abbr: 'f')
    ..addOption('mode')
    ..addOption('output', abbr: 'o')
    ..addFlag('json', negatable: false);
  final base64 = ArgParser()
    ..addCommand('encode', base64Encode)
    ..addCommand('decode', base64Decode);
  final cronParse = ArgParser()
    ..addOption('expression', abbr: 'e')
    ..addOption('file', abbr: 'f')
    ..addOption('timezone', abbr: 'z', defaultsTo: 'UTC')
    ..addOption('count', abbr: 'n', defaultsTo: '5')
    ..addOption('at')
    ..addFlag('json', negatable: false);
  final cron = ArgParser()..addCommand('parse', cronParse);
  final dateConvert = ArgParser()
    ..addOption('value', abbr: 'v')
    ..addOption('file', abbr: 'f')
    ..addOption('from')
    ..addOption('to')
    ..addOption('source-timezone', defaultsTo: 'UTC')
    ..addOption('target-timezone', defaultsTo: 'UTC')
    ..addOption('source-pattern')
    ..addOption('target-pattern')
    ..addFlag('json', negatable: false);
  final date = ArgParser()..addCommand('convert', dateConvert);
  final numberConvertBase = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addOption('file', abbr: 'f')
    ..addOption('output', abbr: 'o')
    ..addOption('from')
    ..addOption('to')
    ..addFlag('json', negatable: false);
  final number = ArgParser()..addCommand('convert-base', numberConvertBase);
  final textEscape = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addOption('file', abbr: 'f')
    ..addOption('output', abbr: 'o')
    ..addOption('mode')
    ..addFlag('json', negatable: false);
  final textAnalyze = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addOption('file', abbr: 'f')
    ..addOption('output', abbr: 'o')
    ..addFlag('json', negatable: false);
  final textCompare = ArgParser()
    ..addOption('left')
    ..addOption('left-file')
    ..addFlag('left-stdin', negatable: false)
    ..addOption('right')
    ..addOption('right-file')
    ..addFlag('right-stdin', negatable: false)
    ..addOption('output', abbr: 'o')
    ..addOption('granularity')
    ..addFlag('json', negatable: false);
  final textUnescape = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addOption('file', abbr: 'f')
    ..addOption('output', abbr: 'o')
    ..addOption('mode')
    ..addFlag('json', negatable: false);
  final textTransform = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addOption('file', abbr: 'f')
    ..addOption('output', abbr: 'o')
    ..addOption('mode')
    ..addFlag('json', negatable: false);
  final text = ArgParser()
    ..addCommand('analyze', textAnalyze)
    ..addCommand('compare', textCompare)
    ..addCommand('escape', textEscape)
    ..addCommand('transform', textTransform)
    ..addCommand('unescape', textUnescape);
  final listCompare = ArgParser()
    ..addOption('left')
    ..addOption('left-file')
    ..addFlag('left-stdin', negatable: false)
    ..addOption('right')
    ..addOption('right-file')
    ..addFlag('right-stdin', negatable: false)
    ..addOption('output', abbr: 'o')
    ..addOption('case', defaultsTo: 'sensitive')
    ..addOption('whitespace', defaultsTo: 'preserve')
    ..addOption('duplicates', defaultsTo: 'preserve')
    ..addFlag('json', negatable: false);
  final list = ArgParser()..addCommand('compare', listCompare);
  final jsonArrayToTable = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addOption('file', abbr: 'f')
    ..addFlag('row-numbers', negatable: false)
    ..addFlag('json', negatable: false);
  final jsonArrayToCsv = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addOption('file', abbr: 'f')
    ..addOption('output', abbr: 'o')
    ..addOption('delimiter', defaultsTo: 'comma')
    ..addFlag('headers', defaultsTo: true)
    ..addFlag('json', negatable: false);
  final jsonToYaml = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addOption('file', abbr: 'f')
    ..addOption('output', abbr: 'o')
    ..addOption('indent', defaultsTo: '2')
    ..addFlag('quote-strings', negatable: false)
    ..addFlag('json', negatable: false);
  final jsonFormat = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addOption('file', abbr: 'f')
    ..addOption('output', abbr: 'o')
    ..addOption('indent', defaultsTo: '2')
    ..addFlag('json', negatable: false);
  final json = ArgParser()
    ..addCommand('array-to-table', jsonArrayToTable)
    ..addCommand('array-to-csv', jsonArrayToCsv)
    ..addCommand('to-yaml', jsonToYaml)
    ..addCommand('format', jsonFormat);
  final sqlFormat = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addOption('file', abbr: 'f')
    ..addOption('output', abbr: 'o')
    ..addOption('dialect', defaultsTo: 'postgresql')
    ..addOption('indent', defaultsTo: '2')
    ..addOption('keyword-case', defaultsTo: 'upper')
    ..addFlag('json', negatable: false);
  final sql = ArgParser()..addCommand('format', sqlFormat);
  final xmlFormat = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addOption('file', abbr: 'f')
    ..addOption('output', abbr: 'o')
    ..addOption('indent', defaultsTo: '2')
    ..addFlag('json', negatable: false);
  final xml = ArgParser()..addCommand('format', xmlFormat);
  final updateCheck = ArgParser()
    ..addOption('repository', defaultsTo: _defaultUpdateRepository)
    ..addOption('current-version', defaultsTo: _defaultInstalledVersion)
    ..addOption(
      'platform',
      defaultsTo: Platform.isWindows ? 'windows' : 'linux',
      allowed: <String>['windows', 'linux'],
    )
    ..addOption(
      'package-type',
      defaultsTo: 'installer',
      allowed: <String>['installer', 'portable'],
    )
    ..addFlag('json', negatable: false);
  final updateApply = ArgParser()
    ..addOption('repository', defaultsTo: _defaultUpdateRepository)
    ..addOption('current-version', defaultsTo: _defaultInstalledVersion)
    ..addOption(
      'platform',
      defaultsTo: Platform.isWindows ? 'windows' : 'linux',
      allowed: <String>['windows', 'linux'],
    )
    ..addOption(
      'package-type',
      defaultsTo: 'installer',
      allowed: const <String>['installer'],
    )
    ..addFlag('yes', negatable: false)
    ..addFlag('json', negatable: false);
  final update = ArgParser()
    ..addCommand('check', updateCheck)
    ..addCommand('apply', updateApply);
  return ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addCommand('alphabet', alphabet)
    ..addCommand('base64', base64)
    ..addCommand('card', card)
    ..addCommand('certificate', certificate)
    ..addCommand('cipher', cipher)
    ..addCommand('cron', cron)
    ..addCommand('date', date)
    ..addCommand('document', document)
    ..addCommand('gzip', gzip)
    ..addCommand('hash', hash)
    ..addCommand('url', url)
    ..addCommand('html', html)
    ..addCommand('json', json)
    ..addCommand('jwt', jwt)
    ..addCommand('list', list)
    ..addCommand('lorem', lorem)
    ..addCommand('number', number)
    ..addCommand('password', password)
    ..addCommand('person', person)
    ..addCommand('checksum', checksum)
    ..addCommand('qr', qr)
    ..addCommand('sql', sql)
    ..addCommand('text', text)
    ..addCommand('uuid', uuid)
    ..addCommand(
      'terminal',
      ArgParser()
        ..addCommand('type-periodic', ArgParser()..addOption('interval')),
    )
    ..addCommand('update', update)
    ..addCommand('xml', xml);
}

Future<int> _runUpdateApply(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required UpdateCheckService checkService,
  required UpdateApplyService? applyService,
}) async {
  final json = parsed.flag('json');
  if (parsed.rest.isNotEmpty) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: FailureKind.validation.name,
      code: 'update-invalid-options',
      messageKey: 'cli.updateApplyUsage',
    );
    return 64;
  }
  if (!parsed.flag('yes')) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: FailureKind.update.name,
      code: 'update-approval-required',
      messageKey: 'error.update.approvalRequired',
    );
    return _exitCodeFor(FailureKind.update);
  }

  final repository = parsed.option('repository') ?? '';
  final repositoryPattern = RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$');
  if (!repositoryPattern.hasMatch(repository)) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: FailureKind.validation.name,
      code: 'update-invalid-options',
      messageKey: 'cli.updateApplyUsage',
    );
    return 64;
  }
  final requestedPlatform = parsed.option('platform');
  final hostPlatform = Platform.isWindows
      ? 'windows'
      : Platform.isLinux
      ? 'linux'
      : null;
  if (hostPlatform == null || requestedPlatform != hostPlatform) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: FailureKind.validation.name,
      code: 'update-invalid-options',
      messageKey: 'cli.updateApplyUsage',
    );
    return 64;
  }
  final platform = parsed.option('platform') == 'windows'
      ? ReleasePlatform.windows
      : ReleasePlatform.linux;
  const packageType = ReleasePackageType.installer;
  final installedVersion = parsed.option('current-version') ?? '';
  final checked = await checkService.check(
    endpoint: Uri.https('api.github.com', '/repos/$repository/releases/latest'),
    installedVersion: installedVersion,
    target: UpdateTarget(
      platform: platform,
      application: ReleaseApplication.cli,
      packageType: packageType,
    ),
  );
  if (checked case ChimeraFailure<UpdateCheckResult>(
    :final kind,
    :final code,
    :final messageKey,
  )) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: kind.name,
      code: code,
      messageKey: messageKey,
    );
    return _exitCodeFor(kind);
  }

  final check = (checked as ChimeraSuccess<UpdateCheckResult>).value;
  final release = check.availableRelease;
  if (release == null) {
    if (json) {
      out.writeln(
        jsonEncode(<String, Object?>{
          'status': UpdateCheckStatus.current.name,
          'installedVersion': check.installedVersion.toString(),
        }),
      );
    } else {
      out.writeln(
        catalog
            .lookup(localeTag, 'update.current')
            .replaceAll('{version}', check.installedVersion.toString()),
      );
    }
    return 0;
  }

  final service =
      applyService ??
      UpdateApplyService(
        storage: NativeUpdateTemporaryStorage(),
        downloader: HttpUpdateArtifactDownloader(),
        verifier: const Sha256UpdateChecksumVerifier(),
        installer: NativeUpdateInstaller(platform: platform),
      );
  final applied = await service.apply(
    UpdateApplyRequest(release: release, accepted: true),
  );
  if (applied case ChimeraFailure<UpdateApplyResult>(
    :final kind,
    :final code,
    :final messageKey,
  )) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: kind.name,
      code: code,
      messageKey: messageKey,
    );
    return _exitCodeFor(kind);
  }

  final result = (applied as ChimeraSuccess<UpdateApplyResult>).value;
  if (json) {
    out.writeln(
      jsonEncode(<String, Object?>{
        'status': result.status.name,
        'installedVersion': check.installedVersion.toString(),
        'appliedVersion': result.release.releaseVersion.toString(),
        'restartRequired': result.restartRequired,
      }),
    );
  } else {
    out.writeln(
      catalog
          .lookup(
            localeTag,
            result.status == UpdateApplyStatus.scheduled
                ? 'cli.updateScheduled'
                : result.restartRequired
                ? 'cli.updateAppliedRestart'
                : 'cli.updateApplied',
          )
          .replaceAll('{installed}', check.installedVersion.toString())
          .replaceAll('{applied}', result.release.releaseVersion.toString()),
    );
  }
  return 0;
}

Future<int> _runUpdateCheck(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required UpdateCheckService service,
}) async {
  final json = parsed.flag('json');
  final repository = parsed.option('repository') ?? '';
  final repositoryPattern = RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$');
  if (!repositoryPattern.hasMatch(repository)) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'validation',
      code: 'update-invalid-options',
      messageKey: 'cli.updateCheckUsage',
    );
    return 64;
  }
  final platform = parsed.option('platform') == 'windows'
      ? ReleasePlatform.windows
      : ReleasePlatform.linux;
  final packageType = parsed.option('package-type') == 'portable'
      ? ReleasePackageType.portable
      : ReleasePackageType.installer;
  final result = await service.check(
    endpoint: Uri.https('api.github.com', '/repos/$repository/releases/latest'),
    installedVersion: parsed.option('current-version') ?? '',
    target: UpdateTarget(
      platform: platform,
      application: ReleaseApplication.cli,
      packageType: packageType,
    ),
  );
  return result.fold(
    onSuccess: (value) {
      final release = value.availableRelease;
      if (json) {
        out.writeln(
          jsonEncode(<String, Object?>{
            'status': value.status.name,
            'installedVersion': value.installedVersion.toString(),
            if (release != null) ...<String, Object?>{
              'availableVersion': release.releaseVersion.toString(),
              'platform': release.platform.name,
              'application': release.application.name,
              'packageType': release.packageType.name,
              'downloadUrl': release.downloadUrl.toString(),
              'checksum': release.checksum,
              'approvalRequired': true,
            },
          }),
        );
      } else if (release == null) {
        out.writeln(
          catalog
              .lookup(localeTag, 'update.current')
              .replaceFirst('{version}', value.installedVersion.toString()),
        );
      } else {
        out.writeln(
          catalog
              .lookup(localeTag, 'update.available')
              .replaceFirst('{available}', release.releaseVersion.toString())
              .replaceFirst('{installed}', value.installedVersion.toString())
              .replaceFirst('{package}', release.packageType.name)
              .replaceFirst('{checksum}', release.checksum),
        );
      }
      return 0;
    },
    onFailure: (failure) {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runQrDecode(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required BytesReader readStandardInputBytes,
  required FileBytesReader readFileBytes,
  required FileBytesWriter writeOutputFile,
  required QrDecodeService service,
  required JsonObjectEncoder encodeJson,
}) async {
  final file = parsed.option('file');
  final useStandardInput = parsed.flag('stdin');
  final json = parsed.flag('json');
  final outputPath = parsed.option('output');

  int fail({
    required int exitCode,
    required String kind,
    required String code,
    required String messageKey,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: kind,
      code: code,
      messageKey: messageKey,
      details: details,
    );
    return exitCode;
  }

  int resource(String field, String reason) => fail(
    exitCode: 75,
    kind: 'resource',
    code: 'qr-decode.resource-limit',
    messageKey: 'error.qrDecode.resource',
    details: <String, Object?>{'field': field, 'reason': reason},
  );

  final sourceCount = (file == null ? 0 : 1) + (useStandardInput ? 1 : 0);
  final invalid = parsed.rest.isNotEmpty || file == '' || outputPath == ''
      ? 'invalid-options'
      : sourceCount == 0
      ? 'missing-source'
      : sourceCount > 1
      ? 'conflicting-sources'
      : null;
  if (invalid != null) {
    return fail(
      exitCode: 64,
      kind: 'validation',
      code: 'qr-decode.$invalid',
      messageKey: 'error.qrDecode.validation',
    );
  }

  late final List<int> bytes;
  try {
    bytes = useStandardInput
        ? await readStandardInputBytes()
        : await readFileBytes(file!);
    if (bytes.length > QrDecoder.defaultMaxInputBytes) {
      _clearBytes(bytes);
      throw const _QrDecodeInputLimit();
    }
  } on _QrDecodeInputLimit {
    return resource('input', 'byte-limit');
  } on OutOfMemoryError {
    return resource('input', 'allocation-limit');
  } on Object {
    return fail(
      exitCode: 74,
      kind: 'access',
      code: useStandardInput
          ? 'qr-decode.input-access'
          : 'qr-decode.file-access',
      messageKey: useStandardInput
          ? 'error.qrDecode.inputAccess'
          : 'error.qrDecode.fileAccess',
    );
  }

  late final ChimeraResult<QrDecodeOutput> result;
  try {
    result = await service.execute(QrDecodeOperationRequest(bytes: bytes));
  } on OutOfMemoryError {
    return resource('input', 'allocation-limit');
  } on Object {
    return fail(
      exitCode: 70,
      kind: 'processing',
      code: 'qr-decode.decoding',
      messageKey: 'error.qrDecode.decoding',
    );
  } finally {
    _clearBytes(bytes);
  }

  return await result.fold(
    onSuccess: (value) async {
      late final String stdoutPayload;
      List<int>? outputBytes;
      try {
        stdoutPayload = json
            ? '${encodeJson(value.toJson())}\n'
            : '${value.text}\n';
        if (outputPath != null) outputBytes = utf8.encode(value.text);
      } on OutOfMemoryError {
        return resource('output', 'allocation-limit');
      } on Object {
        return fail(
          exitCode: 70,
          kind: 'processing',
          code: 'qr-decode.decoding',
          messageKey: 'error.qrDecode.decoding',
        );
      }
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, outputBytes!);
        } on OutOfMemoryError {
          return resource('output', 'allocation-limit');
        } on Object {
          return fail(
            exitCode: 74,
            kind: 'access',
            code: 'qr-decode.output-access',
            messageKey: 'error.qrDecode.outputAccess',
          );
        } finally {
          _clearBytes(outputBytes!);
        }
      }
      try {
        out.write(stdoutPayload);
      } on OutOfMemoryError {
        return resource('output', 'allocation-limit');
      } on Object {
        return fail(
          exitCode: 74,
          kind: 'access',
          code: 'qr-decode.output-access',
          messageKey: 'error.qrDecode.outputAccess',
        );
      }
      return 0;
    },
    onFailure: (failure) async => fail(
      exitCode: _exitCodeFor(failure.kind),
      kind: failure.kind.name,
      code: failure.code,
      messageKey: failure.messageKey,
      details: failure.details,
    ),
  );
}

Future<int> _runQrEncode(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required BytesReader readStandardInputBytes,
  required FileBytesReader readFileBytes,
  required FileBytesWriter writeOutputFile,
  required QrEncodeService service,
  required JsonObjectEncoder encodeJson,
}) async {
  final text = parsed.option('text');
  final file = parsed.option('file');
  final useStandardInput = parsed.flag('stdin');
  final json = parsed.flag('json');
  final outputPath = parsed.option('output');
  final correction = switch (parsed.option('error-correction')) {
    'low' => QrErrorCorrection.low,
    'medium' => QrErrorCorrection.medium,
    'quartile' => QrErrorCorrection.quartile,
    'high' => QrErrorCorrection.high,
    _ => null,
  };
  final sizeText = parsed.option('size')!;
  final marginText = parsed.option('margin')!;
  final size = RegExp(r'^[0-9]+$').hasMatch(sizeText)
      ? int.tryParse(sizeText)
      : null;
  final margin = RegExp(r'^[0-9]+$').hasMatch(marginText)
      ? int.tryParse(marginText)
      : null;
  final foreground = parsed.option('foreground')!;
  final background = parsed.option('background')!;
  final sourceCount =
      (text == null ? 0 : 1) +
      (file == null ? 0 : 1) +
      (useStandardInput ? 1 : 0);
  final invalid =
      parsed.rest.isNotEmpty ||
          outputPath == '' ||
          file == '' ||
          foreground.isEmpty ||
          background.isEmpty
      ? 'invalid-options'
      : sourceCount == 0
      ? 'missing-source'
      : sourceCount > 1
      ? 'conflicting-sources'
      : correction == null
      ? 'invalid-error-correction'
      : size == null
      ? 'invalid-size'
      : margin == null
      ? 'invalid-margin'
      : outputPath == null && !json
      ? 'output-required'
      : null;
  if (invalid != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'validation',
      code: 'qr-encode.$invalid',
      messageKey: 'error.qrEncode.validation',
    );
    return 64;
  }

  late final String input;
  if (text != null) {
    input = text;
  } else {
    try {
      final bytes = useStandardInput
          ? await readStandardInputBytes()
          : await readFileBytes(file!);
      if (bytes.length > QrEncoder.defaultMaxInputBytes) {
        _clearBytes(bytes);
        throw const _QrEncodeInputLimit();
      }
      input = utf8.decode(bytes, allowMalformed: false);
    } on _QrEncodeInputLimit {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        kind: 'resource',
        code: 'qr-encode.resource-limit',
        messageKey: 'error.qrEncode.resource',
        details: const <String, Object?>{
          'field': 'input',
          'reason': 'byte-limit',
        },
      );
      return 75;
    } on FormatException {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        kind: 'validation',
        code: 'qr-encode.invalid-input',
        messageKey: 'error.qrEncode.validation',
        details: const <String, Object?>{
          'field': 'input',
          'reason': 'invalid-utf8',
        },
      );
      return 64;
    } on OutOfMemoryError {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        kind: 'resource',
        code: 'qr-encode.resource-limit',
        messageKey: 'error.qrEncode.resource',
        details: const <String, Object?>{
          'field': 'input',
          'reason': 'allocation-limit',
        },
      );
      return 75;
    } on Object {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        kind: 'access',
        code: useStandardInput
            ? 'qr-encode.input-access'
            : 'qr-encode.file-access',
        messageKey: useStandardInput
            ? 'error.qrEncode.inputAccess'
            : 'error.qrEncode.fileAccess',
      );
      return 74;
    }
  }

  final result = await service.execute(
    QrEncodeOperationRequest(
      text: input,
      errorCorrection: correction!,
      size: size!,
      quietZoneModules: margin!,
      foreground: foreground,
      background: background,
    ),
  );
  return await result.fold(
    onSuccess: (value) async {
      late final String stdoutPayload;
      try {
        if (json) {
          stdoutPayload = '${encodeJson(value.toJson())}\n';
        } else {
          stdoutPayload =
              '${catalog.lookup(localeTag, 'qrEncode.savedResult').replaceAll('{size}', '${value.size}').replaceAll('{version}', '${value.version}').replaceAll('{errorCorrection}', catalog.lookup(localeTag, 'qrEncode.correction.${value.errorCorrection.name}')).replaceAll('{outputByteCount}', '${value.outputByteCount}')}\n';
        }
      } on OutOfMemoryError {
        _writeFailure(
          err,
          catalog: catalog,
          localeTag: localeTag,
          json: json,
          kind: 'resource',
          code: 'qr-encode.resource-limit',
          messageKey: 'error.qrEncode.resource',
          details: const <String, Object?>{
            'field': 'output',
            'reason': 'allocation-limit',
          },
        );
        return 75;
      }
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, value.pngBytes);
        } on OutOfMemoryError {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: json,
            kind: 'resource',
            code: 'qr-encode.resource-limit',
            messageKey: 'error.qrEncode.resource',
            details: const <String, Object?>{
              'field': 'output',
              'reason': 'allocation-limit',
            },
          );
          return 75;
        } on Object {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: json,
            kind: 'access',
            code: 'qr-encode.output-access',
            messageKey: 'error.qrEncode.outputAccess',
          );
          return 74;
        }
      }
      out.write(stdoutPayload);
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return switch (failure.kind) {
        FailureKind.validation || FailureKind.range => 64,
        FailureKind.resource => 75,
        _ => 70,
      };
    },
  );
}

Future<int> _runCertificateConvert(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required BytesReader readStandardInputBytes,
  required FileBytesReader readFileBytes,
  required FileBytesWriter writeOutputFile,
  required CertificateConvertService service,
  required JsonObjectEncoder encodeJson,
}) async {
  final text = parsed.option('text');
  final file = parsed.option('file');
  final useStandardInput = parsed.flag('stdin');
  final json = parsed.flag('json');
  final outputPath = parsed.option('output');
  final sourceCount =
      (text == null ? 0 : 1) +
      (file == null ? 0 : 1) +
      (useStandardInput ? 1 : 0);
  final source = switch (parsed.option('from')) {
    'auto' => CertificateInputRepresentation.auto,
    'pem' => CertificateInputRepresentation.pem,
    'der' => CertificateInputRepresentation.der,
    'base64' => CertificateInputRepresentation.base64,
    _ => null,
  };
  final target = switch (parsed.option('to')) {
    'pem' => CertificateOutputRepresentation.pem,
    'der' => CertificateOutputRepresentation.der,
    'base64' => CertificateOutputRepresentation.base64,
    _ => null,
  };
  String? invalidCode;
  if (parsed.rest.isNotEmpty) {
    invalidCode = 'invalid-options';
  } else if (sourceCount != 1) {
    invalidCode = sourceCount == 0 ? 'missing-source' : 'conflicting-sources';
  } else if (source == null) {
    invalidCode = 'invalid-from';
  } else if (target == null) {
    invalidCode = 'invalid-to';
  } else if (target == CertificateOutputRepresentation.der &&
      outputPath == null &&
      !json) {
    invalidCode = 'output-required';
  }
  if (invalidCode != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'validation',
      code: 'certificate-convert.$invalidCode',
      messageKey: 'error.certificateConvert.validation',
    );
    return 64;
  }

  void resourceFailure(String field, {String reason = 'allocation-limit'}) =>
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        kind: 'resource',
        code: 'certificate-convert.resource-limit',
        messageKey: 'error.certificateConvert.resource',
        details: {'field': field, 'reason': reason},
      );

  late CertificateConvertOperationRequest request;
  if (text != null) {
    request = CertificateConvertOperationRequest.fromText(
      text,
      source: source!,
      target: target!,
    );
  } else {
    try {
      final bytes = useStandardInput
          ? await readStandardInputBytes()
          : await readFileBytes(file!);
      request = CertificateConvertOperationRequest.fromBytes(
        bytes,
        source: source!,
        target: target!,
      );
    } on OutOfMemoryError {
      resourceFailure('input');
      return 75;
    } on Object {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        kind: 'access',
        code:
            'certificate-convert.${useStandardInput ? 'input' : 'file'}-access',
        messageKey: useStandardInput
            ? 'error.certificateConvert.inputAccess'
            : 'error.certificateConvert.fileAccess',
      );
      return 74;
    }
  }

  try {
    final result = await service.execute(request);
    return await result.fold(
      onSuccess: (value) async {
        final payload = json
            ? '${encodeJson(value.toJson())}\n'
            : outputPath == null
            ? value.text!
            : '${catalog.lookup(localeTag, 'certificateConvert.savedResult')}\n';
        if (outputPath != null) {
          try {
            await writeOutputFile(outputPath, value.bytes);
          } on OutOfMemoryError {
            rethrow;
          } on Object {
            _writeFailure(
              err,
              catalog: catalog,
              localeTag: localeTag,
              json: json,
              kind: 'access',
              code: 'certificate-convert.output-access',
              messageKey: 'error.certificateConvert.outputAccess',
            );
            return 74;
          }
        }
        out.write(payload);
        return 0;
      },
      onFailure: (failure) async {
        _writeFailure(
          err,
          catalog: catalog,
          localeTag: localeTag,
          json: json,
          kind: failure.kind.name,
          code: failure.code,
          messageKey: failure.messageKey,
          details: failure.details,
        );
        return _exitCodeFor(failure.kind);
      },
    );
  } on CertificateConversionResourceException catch (error) {
    resourceFailure(error.field, reason: error.reason);
    return 75;
  } on OutOfMemoryError {
    resourceFailure('output');
    return 75;
  }
}

Future<int> _runCertificateInspect(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required BytesReader readStandardInputBytes,
  required FileBytesReader readFileBytes,
  required CertificateInspectService service,
  required JsonObjectEncoder encodeJson,
}) async {
  final text = parsed.option('text');
  final file = parsed.option('file');
  final useStandardInput = parsed.flag('stdin');
  final json = parsed.flag('json');
  final sourceCount =
      (text == null ? 0 : 1) +
      (file == null ? 0 : 1) +
      (useStandardInput ? 1 : 0);
  final representation = switch (parsed.option('format')) {
    'auto' => CertificateInputRepresentation.auto,
    'pem' => CertificateInputRepresentation.pem,
    'der' => CertificateInputRepresentation.der,
    'base64' => CertificateInputRepresentation.base64,
    _ => null,
  };

  String? invalidCode;
  if (parsed.rest.isNotEmpty) {
    invalidCode = 'invalid-options';
  } else if (sourceCount != 1) {
    invalidCode = sourceCount == 0 ? 'missing-source' : 'conflicting-sources';
  } else if (representation == null) {
    invalidCode = 'invalid-format';
  }
  if (invalidCode != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'validation',
      code: 'certificate-inspect.$invalidCode',
      messageKey: 'error.certificateInspect.validation',
    );
    return 64;
  }

  void resourceFailure(String field) => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: 'resource',
    code: 'certificate-inspect.resource-limit',
    messageKey: 'error.certificateInspect.resource',
    details: {'field': field, 'reason': 'allocation-limit'},
  );

  late CertificateInspectOperationRequest request;
  if (text != null) {
    request = CertificateInspectOperationRequest.fromText(
      text,
      representation: representation!,
    );
  } else {
    try {
      final bytes = useStandardInput
          ? await readStandardInputBytes()
          : await readFileBytes(file!);
      request = CertificateInspectOperationRequest.fromBytes(
        bytes,
        representation: representation!,
      );
    } on OutOfMemoryError {
      resourceFailure('input');
      return 75;
    } on Object {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        kind: 'access',
        code:
            'certificate-inspect.${useStandardInput ? 'input' : 'file'}-access',
        messageKey: useStandardInput
            ? 'error.certificateInspect.inputAccess'
            : 'error.certificateInspect.fileAccess',
      );
      return 74;
    }
  }

  final result = await service.execute(request);
  return result.fold(
    onSuccess: (value) {
      try {
        final payload = json
            ? '${encodeJson(value.toJson())}\n'
            : _renderCertificateInspect(
                value,
                catalog: catalog,
                localeTag: localeTag,
              );
        out.write(payload);
      } on OutOfMemoryError {
        resourceFailure('output');
        return 75;
      }
      return 0;
    },
    onFailure: (failure) {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

String _renderCertificateInspect(
  CertificateInspectOutput output, {
  required MessageCatalog catalog,
  required String localeTag,
}) {
  final buffer = StringBuffer();
  String label(String key) =>
      catalog.lookup(localeTag, 'certificateInspect.$key');
  void field(String key, Object value) =>
      buffer.writeln('${label(key)}: $value');
  String identifier(String oid, String? name) =>
      name == null ? oid : '$name ($oid)';
  void attributes(String key, List<CertificateAttribute> values) {
    buffer.writeln('${label(key)}:');
    for (final attribute in values) {
      buffer.writeln(
        '  ${identifier(attribute.oid, attribute.name)}: ${jsonEncode(attribute.value)}',
      );
    }
  }

  final metadata = output.toJson();
  field(
    'representationLabel',
    label('representation.${output.representation.name}'),
  );
  field('versionLabel', output.version);
  field('serialNumberHexLabel', output.serialNumberHex);
  attributes('subjectLabel', output.subject);
  attributes('issuerLabel', output.issuer);
  field('notBeforeLabel', metadata['notBefore']!);
  field('notAfterLabel', metadata['notAfter']!);
  field(
    'signatureAlgorithmLabel',
    identifier(output.signatureAlgorithm.oid, output.signatureAlgorithm.name),
  );
  field(
    'publicKeyAlgorithmLabel',
    identifier(output.publicKeyAlgorithm.oid, output.publicKeyAlgorithm.name),
  );
  buffer.writeln('${label('extensionsLabel')}:');
  for (final extension in output.extensions) {
    buffer.writeln(
      '  ${identifier(extension.oid, extension.name)}, ${label('criticalLabel')}: ${label(extension.critical ? 'yes' : 'no')}',
    );
  }
  field('inputByteCountLabel', output.inputByteCount);
  field('derByteCountLabel', output.derByteCount);
  return buffer.toString();
}

Future<int> _runBase64Encode(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required BytesReader readStandardInputBytes,
  required FileBytesReader readFileBytes,
  required FileBytesWriter writeOutputFile,
  required Base64EncodeService base64EncodeService,
}) async {
  final text = parsed.option('text');
  final file = parsed.option('file');
  final useStandardInput = parsed.flag('stdin');
  final sourceCount =
      (text == null ? 0 : 1) +
      (file == null ? 0 : 1) +
      (useStandardInput ? 1 : 0);
  if (sourceCount != 1) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: sourceCount == 0
          ? 'base64-encode.missing-source'
          : 'base64-encode.conflicting-sources',
      messageKey: 'error.base64Encode.validation',
    );
    return 64;
  }

  late Base64EncodeOperationRequest request;
  if (text != null) {
    request = Base64EncodeOperationRequest.text(text);
  } else {
    try {
      final bytes = useStandardInput
          ? await readStandardInputBytes()
          : await readFileBytes(file!);
      request = useStandardInput
          ? Base64EncodeOperationRequest.utf8Bytes(bytes)
          : Base64EncodeOperationRequest.bytes(bytes);
    } on OutOfMemoryError {
      _writeBase64ResourceFailure(
        err,
        parsed: parsed,
        catalog: catalog,
        localeTag: localeTag,
        field: 'input',
      );
      return 75;
    } on Object {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: parsed.flag('json'),
        kind: 'access',
        code: useStandardInput
            ? 'base64-encode.input-access'
            : 'base64-encode.file-access',
        messageKey: useStandardInput
            ? 'error.base64Encode.inputAccess'
            : 'error.base64Encode.fileAccess',
      );
      return 74;
    }
  }

  final result = await base64EncodeService.execute(request);
  return await result.fold(
    onSuccess: (value) async {
      final json = parsed.flag('json');
      final outputPath = parsed.option('output');
      if (outputPath != null) {
        try {
          final payload = json ? jsonEncode(value.toJson()) : value.encoded;
          await writeOutputFile(outputPath, utf8.encode(payload));
        } on OutOfMemoryError {
          _writeBase64ResourceFailure(
            err,
            parsed: parsed,
            catalog: catalog,
            localeTag: localeTag,
            field: 'output',
          );
          return 75;
        } on Object {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: json,
            kind: 'access',
            code: 'base64-encode.output-access',
            messageKey: 'error.base64Encode.outputAccess',
          );
          return 74;
        }
        return 0;
      }

      try {
        final payload = json
            ? '${jsonEncode(value.toJson())}\n'
            : '${catalog.lookup(localeTag, 'base64Encode.outputLabel')}: '
                  '${value.encoded}\n'
                  '${catalog.lookup(localeTag, 'base64Encode.inputByteCountLabel')}: '
                  '${value.inputByteCount}\n'
                  '${catalog.lookup(localeTag, 'base64Encode.outputCharacterCountLabel')}: '
                  '${value.outputCharacterCount}\n';
        out.write(payload);
      } on OutOfMemoryError {
        _writeBase64ResourceFailure(
          err,
          parsed: parsed,
          catalog: catalog,
          localeTag: localeTag,
          field: 'output',
        );
        return 75;
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: parsed.flag('json'),
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runGzipDecompress(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required BytesReader readStandardInputBytes,
  required FileBytesReader readFileBytes,
  required FileBytesWriter writeOutputFile,
  required GzipDecompressService service,
  required JsonObjectEncoder encodeJson,
}) async {
  final file = parsed.option('file');
  final useStandardInput = parsed.flag('stdin');
  final json = parsed.flag('json');
  final outputPath = parsed.option('output');
  final sourceCount = (file == null ? 0 : 1) + (useStandardInput ? 1 : 0);
  final invalid = parsed.rest.isNotEmpty || outputPath == '' || file == ''
      ? 'invalid-options'
      : sourceCount == 0
      ? 'missing-source'
      : sourceCount > 1
      ? 'conflicting-sources'
      : null;
  if (invalid != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'validation',
      code: 'gzip-decompress.$invalid',
      messageKey: 'error.gzipDecompress.validation',
    );
    return 64;
  }

  final mode = switch (parsed.option('mode')) {
    'text' => GzipDecompressMode.text,
    'binary' => GzipDecompressMode.binary,
    _ => null,
  };
  if (mode == null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'validation',
      code: 'gzip-decompress.invalid-mode',
      messageKey: 'error.gzipDecompress.validation',
    );
    return 64;
  }
  if (mode == GzipDecompressMode.binary && outputPath == null && !json) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: false,
      kind: 'validation',
      code: 'gzip-decompress.binary-destination-required',
      messageKey: 'error.gzipDecompress.validation',
    );
    return 64;
  }

  void resourceFailure(String field) => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: 'resource',
    code: 'gzip-decompress.resource-limit',
    messageKey: 'error.gzipDecompress.resource',
    details: <String, Object?>{'field': field, 'reason': 'allocation-limit'},
  );

  late GzipDecompressOperationRequest request;
  try {
    final bytes = useStandardInput
        ? await readStandardInputBytes()
        : await readFileBytes(file!);
    request = GzipDecompressOperationRequest.bytes(bytes, mode: mode);
  } on OutOfMemoryError {
    resourceFailure('input');
    return 75;
  } on Object {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'access',
      code: useStandardInput
          ? 'gzip-decompress.input-access'
          : 'gzip-decompress.file-access',
      messageKey: useStandardInput
          ? 'error.gzipDecompress.inputAccess'
          : 'error.gzipDecompress.fileAccess',
    );
    return 74;
  }

  final result = await service.execute(request);
  return await result.fold(
    onSuccess: (value) async {
      late String stdoutPayload;
      try {
        if (json) {
          stdoutPayload = '${encodeJson(value.toJson())}\n';
        } else if (outputPath == null) {
          stdoutPayload = value.text!;
        } else {
          stdoutPayload =
              '${catalog.lookup(localeTag, 'gzipDecompress.savedResult')}\n';
        }
      } on OutOfMemoryError {
        resourceFailure('output');
        return 75;
      }

      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, value.bytes);
        } on OutOfMemoryError {
          resourceFailure('output');
          return 75;
        } on Object {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: json,
            kind: 'access',
            code: 'gzip-decompress.output-access',
            messageKey: 'error.gzipDecompress.outputAccess',
          );
          return 74;
        }
      }

      try {
        out.write(stdoutPayload);
      } on OutOfMemoryError {
        resourceFailure('output');
        return 75;
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runJwtInspect(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required BytesReader readStandardInputBytes,
  required FileBytesReader readFileBytes,
  required JwtInspectService service,
  required JsonObjectEncoder encodeJson,
}) async {
  final token = parsed.option('token');
  final tokenFile = parsed.option('token-file');
  final useStandardInput = parsed.flag('stdin');
  final key = parsed.option('key');
  final keyFile = parsed.option('key-file');
  final json = parsed.flag('json');
  final tokenCount =
      (token == null ? 0 : 1) +
      (tokenFile == null ? 0 : 1) +
      (useStandardInput ? 1 : 0);
  final keyCount = (key == null ? 0 : 1) + (keyFile == null ? 0 : 1);
  final invalid =
      parsed.rest.isNotEmpty ||
          token == '' ||
          tokenFile == '' ||
          key == '' ||
          keyFile == ''
      ? 'invalid-options'
      : tokenCount > 1 || keyCount > 1
      ? 'conflicting-sources'
      : tokenCount == 0
      ? 'missing-source'
      : null;
  if (invalid != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'validation',
      code: 'jwt-inspect.$invalid',
      messageKey: 'error.jwtInspect.validation',
    );
    return 64;
  }

  void writeAdapterFailure(_JwtInspectAdapterFailure failure) => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: failure.kind,
    code: failure.code,
    messageKey: failure.messageKey,
    details: failure.details,
  );

  Future<String> readUtf8(
    Future<List<int>> Function() read, {
    required String field,
    required String accessCode,
    required String accessMessageKey,
  }) async {
    try {
      final bytes = await read();
      try {
        if (bytes.length > JwtInspector.defaultMaxInputBytes) {
          throw const _JwtInspectInputLimit();
        }
        return utf8.decode(bytes, allowMalformed: false);
      } finally {
        try {
          bytes.fillRange(0, bytes.length, 0);
        } on Object {
          // Immutable collaborator bytes are released when this scope ends.
        }
      }
    } on _JwtInspectInputLimit {
      throw _JwtInspectAdapterFailure(
        exitCode: 75,
        kind: 'resource',
        code: 'jwt-inspect.resource-limit',
        messageKey: 'error.jwtInspect.resource',
        details: <String, Object?>{'field': field, 'reason': 'input-limit'},
      );
    } on FormatException {
      throw _JwtInspectAdapterFailure(
        exitCode: 64,
        kind: 'validation',
        code: 'jwt-inspect.invalid-utf8',
        messageKey: 'error.jwtInspect.validation',
        details: <String, Object?>{'field': field, 'reason': 'invalid-utf8'},
      );
    } on OutOfMemoryError {
      throw _JwtInspectAdapterFailure(
        exitCode: 75,
        kind: 'resource',
        code: 'jwt-inspect.resource-limit',
        messageKey: 'error.jwtInspect.resource',
        details: <String, Object?>{
          'field': field,
          'reason': 'allocation-limit',
        },
      );
    } on _JwtInspectAdapterFailure {
      rethrow;
    } on Object {
      throw _JwtInspectAdapterFailure(
        exitCode: 74,
        kind: 'access',
        code: accessCode,
        messageKey: accessMessageKey,
      );
    }
  }

  late String tokenText;
  String? keyText;
  try {
    tokenText =
        token ??
        await readUtf8(
          useStandardInput
              ? readStandardInputBytes
              : () => readFileBytes(tokenFile!),
          field: 'token',
          accessCode: useStandardInput
              ? 'jwt-inspect.input-access'
              : 'jwt-inspect.token-access',
          accessMessageKey: useStandardInput
              ? 'error.jwtInspect.inputAccess'
              : 'error.jwtInspect.tokenAccess',
        );
    keyText =
        key ??
        (keyFile == null
            ? null
            : await readUtf8(
                () => readFileBytes(keyFile),
                field: 'key',
                accessCode: 'jwt-inspect.key-access',
                accessMessageKey: 'error.jwtInspect.keyAccess',
              ));
  } on _JwtInspectAdapterFailure catch (failure) {
    writeAdapterFailure(failure);
    return failure.exitCode;
  }

  final result = await service.execute(
    JwtInspectOperationRequest(token: tokenText, key: keyText),
  );
  return result.fold(
    onSuccess: (value) {
      try {
        final output = json
            ? '${encodeJson(value.toJson())}\n'
            : '${catalog.lookup(localeTag, 'jwtInspect.headerLabel')}: '
                  '${jsonEncode(value.header)}\n'
                  '${catalog.lookup(localeTag, 'jwtInspect.claimsLabel')}: '
                  '${jsonEncode(value.claims)}\n'
                  '${catalog.lookup(localeTag, 'jwtInspect.verificationLabel')}: '
                  '${catalog.lookup(localeTag, switch (value.verification) {
                    JwtVerificationStatus.notRequested => 'jwtInspect.statusNotRequested',
                    JwtVerificationStatus.verified => 'jwtInspect.statusVerified',
                    JwtVerificationStatus.failed => 'jwtInspect.statusFailed',
                  })}\n';
        out.write(output);
        return 0;
      } on OutOfMemoryError {
        _writeFailure(
          err,
          catalog: catalog,
          localeTag: localeTag,
          json: json,
          kind: 'resource',
          code: 'jwt-inspect.resource-limit',
          messageKey: 'error.jwtInspect.resource',
          details: const <String, Object?>{
            'field': 'output',
            'reason': 'allocation-limit',
          },
        );
        return 75;
      }
    },
    onFailure: (failure) {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

final class _JwtInspectAdapterFailure implements Exception {
  const _JwtInspectAdapterFailure({
    required this.exitCode,
    required this.kind,
    required this.code,
    required this.messageKey,
    this.details = const <String, Object?>{},
  });

  final int exitCode;
  final String kind;
  final String code;
  final String messageKey;
  final Map<String, Object?> details;
}

Future<int> _runJwtCreate(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required BytesReader readStandardInputBytes,
  required FileBytesReader readFileBytes,
  required FileBytesWriter writeOutputFile,
  required JwtCreateService service,
  required JsonObjectEncoder encodeJson,
}) async {
  final algorithm = parsed.option('algorithm');
  final header = parsed.option('header');
  final headerFile = parsed.option('header-file');
  final claims = parsed.option('claims');
  final claimsFile = parsed.option('claims-file');
  final useStandardInput = parsed.flag('stdin');
  final key = parsed.option('key');
  final keyFile = parsed.option('key-file');
  final outputPath = parsed.option('output');
  final json = parsed.flag('json');
  final headerCount = (header == null ? 0 : 1) + (headerFile == null ? 0 : 1);
  final claimsCount =
      (claims == null ? 0 : 1) +
      (claimsFile == null ? 0 : 1) +
      (useStandardInput ? 1 : 0);
  final keyCount = (key == null ? 0 : 1) + (keyFile == null ? 0 : 1);
  final invalid =
      parsed.rest.isNotEmpty ||
          algorithm == null ||
          algorithm.isEmpty ||
          outputPath == '' ||
          headerFile == '' ||
          claimsFile == '' ||
          keyFile == ''
      ? 'invalid-options'
      : headerCount > 1 || claimsCount > 1 || keyCount > 1
      ? 'conflicting-sources'
      : claimsCount == 0 || keyCount == 0
      ? 'missing-source'
      : null;
  if (invalid != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'validation',
      code: 'jwt-create.$invalid',
      messageKey: 'error.jwtCreate.validation',
    );
    return 64;
  }

  void writeAdapterFailure({
    required String kind,
    required String code,
    required String messageKey,
    Map<String, Object?> details = const <String, Object?>{},
  }) => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: kind,
    code: code,
    messageKey: messageKey,
    details: details,
  );

  Future<String> readUtf8(
    Future<List<int>> Function() read, {
    required String field,
    required String accessCode,
    required String accessMessageKey,
  }) async {
    try {
      final bytes = await read();
      try {
        return utf8.decode(bytes, allowMalformed: false);
      } finally {
        try {
          bytes.fillRange(0, bytes.length, 0);
        } on Object {
          // Immutable collaborator bytes are released when this scope ends.
        }
      }
    } on FormatException {
      throw _JwtCreateAdapterFailure(
        exitCode: 64,
        kind: 'validation',
        code: 'jwt-create.invalid-utf8',
        messageKey: 'error.jwtCreate.validation',
        details: <String, Object?>{'field': field, 'reason': 'invalid-utf8'},
      );
    } on OutOfMemoryError {
      throw _JwtCreateAdapterFailure(
        exitCode: 75,
        kind: 'resource',
        code: 'jwt-create.resource-limit',
        messageKey: 'error.jwtCreate.resource',
        details: <String, Object?>{
          'field': field,
          'reason': 'allocation-limit',
        },
      );
    } on _JwtCreateAdapterFailure {
      rethrow;
    } on Object {
      throw _JwtCreateAdapterFailure(
        exitCode: 74,
        kind: 'access',
        code: accessCode,
        messageKey: accessMessageKey,
      );
    }
  }

  late String headerJson;
  late String claimsJson;
  late String keyText;
  try {
    headerJson =
        header ??
        (headerFile == null
            ? '{}'
            : await readUtf8(
                () => readFileBytes(headerFile),
                field: 'header',
                accessCode: 'jwt-create.header-access',
                accessMessageKey: 'error.jwtCreate.headerAccess',
              ));
    claimsJson =
        claims ??
        await readUtf8(
          useStandardInput
              ? readStandardInputBytes
              : () => readFileBytes(claimsFile!),
          field: 'claims',
          accessCode: useStandardInput
              ? 'jwt-create.input-access'
              : 'jwt-create.claims-access',
          accessMessageKey: useStandardInput
              ? 'error.jwtCreate.inputAccess'
              : 'error.jwtCreate.claimsAccess',
        );
    keyText =
        key ??
        await readUtf8(
          () => readFileBytes(keyFile!),
          field: 'key',
          accessCode: 'jwt-create.key-access',
          accessMessageKey: 'error.jwtCreate.keyAccess',
        );
  } on _JwtCreateAdapterFailure catch (failure) {
    writeAdapterFailure(
      kind: failure.kind,
      code: failure.code,
      messageKey: failure.messageKey,
      details: failure.details,
    );
    return failure.exitCode;
  }

  final result = await service.execute(
    JwtCreateOperationRequest(
      headerJson: headerJson,
      claimsJson: claimsJson,
      algorithm: algorithm!,
      key: keyText,
    ),
  );
  return await result.fold(
    onSuccess: (value) async {
      try {
        if (outputPath != null) {
          await writeOutputFile(outputPath, utf8.encode(value.token));
        }
        out.write(
          json
              ? '${encodeJson(value.toJson())}\n'
              : outputPath != null
              ? '${catalog.lookup(localeTag, 'jwtCreate.savedResult')}\n'
              : value.token,
        );
        return 0;
      } on OutOfMemoryError {
        writeAdapterFailure(
          kind: 'resource',
          code: 'jwt-create.resource-limit',
          messageKey: 'error.jwtCreate.resource',
          details: const <String, Object?>{
            'field': 'token',
            'reason': 'allocation-limit',
          },
        );
        return 75;
      } on Object {
        writeAdapterFailure(
          kind: 'access',
          code: 'jwt-create.output-access',
          messageKey: 'error.jwtCreate.outputAccess',
        );
        return 74;
      }
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

final class _JwtCreateAdapterFailure implements Exception {
  const _JwtCreateAdapterFailure({
    required this.exitCode,
    required this.kind,
    required this.code,
    required this.messageKey,
    this.details = const <String, Object?>{},
  });

  final int exitCode;
  final String kind;
  final String code;
  final String messageKey;
  final Map<String, Object?> details;
}

Future<int> _runUrlDecode(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required BytesReader readStandardInputBytes,
  required FileBytesReader readFileBytes,
  required FileBytesWriter writeOutputFile,
  required UrlDecodeService service,
  required JsonObjectEncoder encodeJson,
}) async {
  final text = parsed.option('input');
  final file = parsed.option('file');
  final useStandardInput = parsed.flag('stdin');
  final json = parsed.flag('json');
  final outputPath = parsed.option('output');
  final sourceCount =
      (text == null ? 0 : 1) +
      (file == null ? 0 : 1) +
      (useStandardInput ? 1 : 0);
  final invalid = parsed.rest.isNotEmpty || outputPath == '' || file == ''
      ? 'invalid-options'
      : sourceCount == 0
      ? 'missing-source'
      : sourceCount > 1
      ? 'conflicting-sources'
      : null;
  if (invalid != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'validation',
      code: 'url-decode.$invalid',
      messageKey: 'error.urlDecode.validation',
    );
    return 64;
  }

  void resourceFailure(String field) => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: 'resource',
    code: 'url-decode.resource-limit',
    messageKey: 'error.urlDecode.resource',
    details: {'field': field, 'reason': 'allocation-limit'},
  );

  void outputAccessFailure() => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: 'access',
    code: 'url-decode.output-access',
    messageKey: 'error.urlDecode.outputAccess',
  );

  late UrlDecodeOperationRequest request;
  try {
    request = text != null
        ? UrlDecodeOperationRequest.text(text)
        : UrlDecodeOperationRequest.utf8Bytes(
            useStandardInput
                ? await readStandardInputBytes()
                : await readFileBytes(file!),
          );
  } on OutOfMemoryError {
    resourceFailure('input');
    return 75;
  } on Object {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'access',
      code: useStandardInput
          ? 'url-decode.input-access'
          : 'url-decode.file-access',
      messageKey: useStandardInput
          ? 'error.urlDecode.inputAccess'
          : 'error.urlDecode.fileAccess',
    );
    return 74;
  }
  final result = await service.execute(request);
  return await result.fold(
    onSuccess: (value) async {
      late String stdoutPayload;
      try {
        stdoutPayload = json
            ? '${encodeJson(value.toJson())}\n'
            : outputPath != null
            ? '${catalog.lookup(localeTag, 'urlDecode.savedResult')}\n'
            : value.decoded;
      } on OutOfMemoryError {
        resourceFailure('decoded');
        return 75;
      } on Object {
        outputAccessFailure();
        return 74;
      }
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(value.decoded));
        } on OutOfMemoryError {
          resourceFailure('decoded');
          return 75;
        } on Object {
          outputAccessFailure();
          return 74;
        }
      }
      try {
        await writeSinkAndFlush(out, stdoutPayload);
      } on OutOfMemoryError {
        resourceFailure('decoded');
        return 75;
      } on Object {
        outputAccessFailure();
        return 74;
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runHtmlDecode(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required BytesReader readStandardInputBytes,
  required FileBytesReader readFileBytes,
  required FileBytesWriter writeOutputFile,
  required HtmlDecodeService service,
  required JsonObjectEncoder encodeJson,
}) async {
  final text = parsed.option('input');
  final file = parsed.option('file');
  final useStandardInput = parsed.flag('stdin');
  final json = parsed.flag('json');
  final outputPath = parsed.option('output');
  final sourceCount =
      (text == null ? 0 : 1) +
      (file == null ? 0 : 1) +
      (useStandardInput ? 1 : 0);
  final invalid = parsed.rest.isNotEmpty || outputPath == '' || file == ''
      ? 'invalid-options'
      : sourceCount == 0
      ? 'missing-source'
      : sourceCount > 1
      ? 'conflicting-sources'
      : null;
  if (invalid != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'validation',
      code: 'html-decode.$invalid',
      messageKey: 'error.htmlDecode.validation',
    );
    return 64;
  }

  void resourceFailure(String field) => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: 'resource',
    code: 'html-decode.resource-limit',
    messageKey: 'error.htmlDecode.resource',
    details: {'field': field, 'reason': 'allocation-limit'},
  );

  void outputAccessFailure() => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: 'access',
    code: 'html-decode.output-access',
    messageKey: 'error.htmlDecode.outputAccess',
  );

  late HtmlDecodeOperationRequest request;
  try {
    request = text != null
        ? HtmlDecodeOperationRequest.text(text)
        : HtmlDecodeOperationRequest.utf8Bytes(
            useStandardInput
                ? await readStandardInputBytes()
                : await readFileBytes(file!),
          );
  } on OutOfMemoryError {
    resourceFailure('input');
    return 75;
  } on Object {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'access',
      code: useStandardInput
          ? 'html-decode.input-access'
          : 'html-decode.file-access',
      messageKey: useStandardInput
          ? 'error.htmlDecode.inputAccess'
          : 'error.htmlDecode.fileAccess',
    );
    return 74;
  }
  final result = await service.execute(request);
  return await result.fold(
    onSuccess: (value) async {
      late String stdoutPayload;
      try {
        stdoutPayload = json
            ? '${encodeJson(value.toJson())}\n'
            : outputPath != null
            ? '${catalog.lookup(localeTag, 'htmlDecode.savedResult')}\n'
            : value.decoded;
      } on OutOfMemoryError {
        resourceFailure('decoded');
        return 75;
      } on Object {
        outputAccessFailure();
        return 74;
      }
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(value.decoded));
        } on OutOfMemoryError {
          resourceFailure('decoded');
          return 75;
        } on Object {
          outputAccessFailure();
          return 74;
        }
      }
      try {
        out.write(stdoutPayload);
      } on OutOfMemoryError {
        resourceFailure('decoded');
        return 75;
      } on Object {
        outputAccessFailure();
        return 74;
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runHashGenerate(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required BytesReader readStandardInputBytes,
  required FileBytesReader readFileBytes,
  required FileBytesWriter writeOutputFile,
  required HashGenerateService service,
  required JsonObjectEncoder encodeJson,
}) async {
  final text = parsed.option('input');
  final file = parsed.option('file');
  final useStandardInput = parsed.flag('stdin');
  final json = parsed.flag('json');
  final outputPath = parsed.option('output');
  final algorithm = parsed.option('algorithm')!;
  final sourceCount =
      (text == null ? 0 : 1) +
      (file == null ? 0 : 1) +
      (useStandardInput ? 1 : 0);
  final invalid = parsed.rest.isNotEmpty || outputPath == '' || file == ''
      ? 'invalid-options'
      : sourceCount == 0
      ? 'missing-source'
      : sourceCount > 1
      ? 'conflicting-sources'
      : !HashGenerator.algorithms.contains(algorithm)
      ? 'invalid-algorithm'
      : null;
  if (invalid != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'validation',
      code: 'hash-generate.$invalid',
      messageKey: 'error.hashGenerate.validation',
      details: invalid == 'invalid-algorithm'
          ? {'field': 'algorithm', 'reason': 'unsupported-algorithm'}
          : const {},
    );
    return 64;
  }

  void resourceFailure(String field) => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: 'resource',
    code: 'hash-generate.resource-limit',
    messageKey: 'error.hashGenerate.resource',
    details: {'field': field, 'reason': 'allocation-limit'},
  );

  void outputAccessFailure() => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: 'access',
    code: 'hash-generate.output-access',
    messageKey: 'error.hashGenerate.outputAccess',
  );

  late HashGenerateOperationRequest request;
  try {
    request = text != null
        ? HashGenerateOperationRequest.text(text, algorithm: algorithm)
        : HashGenerateOperationRequest.bytes(
            useStandardInput
                ? await readStandardInputBytes()
                : await readFileBytes(file!),
            algorithm: algorithm,
          );
  } on OutOfMemoryError {
    resourceFailure('input');
    return 75;
  } on Object {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'access',
      code: useStandardInput
          ? 'hash-generate.input-access'
          : 'hash-generate.file-access',
      messageKey: useStandardInput
          ? 'error.hashGenerate.inputAccess'
          : 'error.hashGenerate.fileAccess',
    );
    return 74;
  }
  final result = await service.execute(request);
  return await result.fold(
    onSuccess: (value) async {
      late String stdoutPayload;
      try {
        stdoutPayload = json
            ? '${encodeJson({'algorithm': value.algorithm, 'digest': value.digest, 'legacy': value.legacy, 'warning': value.warningKey == null ? null : catalog.lookup(localeTag, value.warningKey!)})}\n'
            : outputPath != null
            ? '${catalog.lookup(localeTag, 'hashGenerate.savedResult')}\n${value.warningKey == null ? '' : '${catalog.lookup(localeTag, value.warningKey!)}\n'}'
            : '${value.digest}\n${value.warningKey == null ? '' : '${catalog.lookup(localeTag, value.warningKey!)}\n'}';
      } on OutOfMemoryError {
        resourceFailure('encoded');
        return 75;
      } on Object {
        outputAccessFailure();
        return 74;
      }
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode('${value.digest}\n'));
        } on OutOfMemoryError {
          resourceFailure('encoded');
          return 75;
        } on Object {
          outputAccessFailure();
          return 74;
        }
      }
      try {
        await writeSinkAndFlush(out, stdoutPayload);
      } on OutOfMemoryError {
        resourceFailure('encoded');
        return 75;
      } on Object {
        outputAccessFailure();
        return 74;
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runHtmlEncode(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required BytesReader readStandardInputBytes,
  required FileBytesReader readFileBytes,
  required FileBytesWriter writeOutputFile,
  required HtmlEncodeService service,
  required JsonObjectEncoder encodeJson,
}) async {
  final text = parsed.option('input');
  final file = parsed.option('file');
  final useStandardInput = parsed.flag('stdin');
  final json = parsed.flag('json');
  final outputPath = parsed.option('output');
  final context = parsed.option('context')!;
  final sourceCount =
      (text == null ? 0 : 1) +
      (file == null ? 0 : 1) +
      (useStandardInput ? 1 : 0);
  final invalid = parsed.rest.isNotEmpty || outputPath == '' || file == ''
      ? 'invalid-options'
      : sourceCount == 0
      ? 'missing-source'
      : sourceCount > 1
      ? 'conflicting-sources'
      : !const [
          'all',
          'element',
          'double-quoted-attribute',
          'single-quoted-attribute',
        ].contains(context)
      ? 'invalid-context'
      : null;
  if (invalid != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'validation',
      code: 'html-encode.$invalid',
      messageKey: 'error.htmlEncode.validation',
      details: invalid == 'invalid-context'
          ? {'field': 'context', 'reason': 'unsupported-context'}
          : const {},
    );
    return 64;
  }

  void resourceFailure(String field) => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: 'resource',
    code: 'html-encode.resource-limit',
    messageKey: 'error.htmlEncode.resource',
    details: {'field': field, 'reason': 'allocation-limit'},
  );

  void outputAccessFailure() => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: 'access',
    code: 'html-encode.output-access',
    messageKey: 'error.htmlEncode.outputAccess',
  );

  late HtmlEncodeOperationRequest request;
  try {
    request = text != null
        ? HtmlEncodeOperationRequest.text(text, context: context)
        : HtmlEncodeOperationRequest.utf8Bytes(
            useStandardInput
                ? await readStandardInputBytes()
                : await readFileBytes(file!),
            context: context,
          );
  } on OutOfMemoryError {
    resourceFailure('input');
    return 75;
  } on Object {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'access',
      code: useStandardInput
          ? 'html-encode.input-access'
          : 'html-encode.file-access',
      messageKey: useStandardInput
          ? 'error.htmlEncode.inputAccess'
          : 'error.htmlEncode.fileAccess',
    );
    return 74;
  }
  final result = await service.execute(request);
  return await result.fold(
    onSuccess: (value) async {
      late String stdoutPayload;
      try {
        stdoutPayload = json
            ? '${encodeJson(value.toJson())}\n'
            : outputPath != null
            ? '${catalog.lookup(localeTag, 'htmlEncode.savedResult')}\n'
            : value.encoded;
      } on OutOfMemoryError {
        resourceFailure('encoded');
        return 75;
      } on Object {
        outputAccessFailure();
        return 74;
      }
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(value.encoded));
        } on OutOfMemoryError {
          resourceFailure('encoded');
          return 75;
        } on Object {
          outputAccessFailure();
          return 74;
        }
      }
      try {
        out.write(stdoutPayload);
      } on OutOfMemoryError {
        resourceFailure('encoded');
        return 75;
      } on Object {
        outputAccessFailure();
        return 74;
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runAlphabetEncode(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required BytesReader readStandardInputBytes,
  required FileBytesReader readFileBytes,
  required FileBytesWriter writeOutputFile,
  required AlphabetEncodeService service,
  required JsonObjectEncoder encodeJson,
}) async {
  final text = parsed.option('input');
  final file = parsed.option('file');
  final useStandardInput = parsed.flag('stdin');
  final json = parsed.flag('json');
  final outputPath = parsed.option('output');
  final alphabet = parsed.option('alphabet');
  final sourceCount =
      (text == null ? 0 : 1) +
      (file == null ? 0 : 1) +
      (useStandardInput ? 1 : 0);
  const supportedAlphabets = <String>{'morse', 'nato', 'braille'};
  final invalid = parsed.rest.isNotEmpty || outputPath == '' || file == ''
      ? 'invalid-options'
      : sourceCount == 0
      ? 'missing-source'
      : sourceCount > 1
      ? 'conflicting-sources'
      : alphabet == null || !supportedAlphabets.contains(alphabet)
      ? 'invalid-alphabet'
      : null;
  if (invalid != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'validation',
      code: 'alphabet.$invalid',
      messageKey: 'error.alphabetEncode.validation',
      details: invalid == 'invalid-alphabet'
          ? const {'field': 'alphabet', 'reason': 'unsupported-alphabet'}
          : const {},
    );
    return 64;
  }

  void resourceFailure(String field) => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: 'resource',
    code: 'alphabet.resource-limit',
    messageKey: 'error.alphabetEncode.resource',
    details: {'field': field, 'reason': 'allocation-limit'},
  );

  void outputAccessFailure() => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: 'access',
    code: 'alphabet.output-access',
    messageKey: 'error.alphabetEncode.outputAccess',
  );

  late AlphabetEncodeOperationRequest request;
  try {
    request = text != null
        ? AlphabetEncodeOperationRequest.text(text, alphabet: alphabet!)
        : AlphabetEncodeOperationRequest.utf8Bytes(
            useStandardInput
                ? await readStandardInputBytes()
                : await readFileBytes(file!),
            alphabet: alphabet!,
          );
  } on OutOfMemoryError {
    resourceFailure('input');
    return 75;
  } on Object {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'access',
      code: useStandardInput ? 'alphabet.input-access' : 'alphabet.file-access',
      messageKey: useStandardInput
          ? 'error.alphabetEncode.inputAccess'
          : 'error.alphabetEncode.fileAccess',
    );
    return 74;
  }

  final result = await service.execute(request);
  return await result.fold(
    onSuccess: (value) async {
      late String stdoutPayload;
      try {
        if (json) {
          stdoutPayload = '${encodeJson(value.toJson())}\n';
        } else {
          final mapping = value.mapping;
          final firstLine = outputPath == null
              ? value.encoded
              : catalog.lookup(localeTag, 'alphabetEncode.savedResult');
          stdoutPayload =
              '$firstLine\n'
              '${catalog.lookup(localeTag, 'alphabetEncode.mappingLabel')}: '
              '${mapping.id} (${mapping.edition})\n'
              '${catalog.lookup(localeTag, 'alphabetEncode.mappingSourcesLabel')}: '
              '${mapping.sources.join(', ')}\n';
        }
      } on OutOfMemoryError {
        resourceFailure('encoded');
        return 75;
      } on Object {
        outputAccessFailure();
        return 74;
      }
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(value.encoded));
        } on OutOfMemoryError {
          resourceFailure('encoded');
          return 75;
        } on Object {
          outputAccessFailure();
          return 74;
        }
      }
      try {
        await writeSinkAndFlush(out, stdoutPayload);
      } on OutOfMemoryError {
        resourceFailure('encoded');
        return 75;
      } on Object {
        outputAccessFailure();
        return 74;
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runAlphabetDecode(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required BytesReader readStandardInputBytes,
  required FileBytesReader readFileBytes,
  required FileBytesWriter writeOutputFile,
  required AlphabetDecodeService service,
  required JsonObjectEncoder encodeJson,
}) async {
  final text = parsed.option('input');
  final file = parsed.option('file');
  final useStandardInput = parsed.flag('stdin');
  final json = parsed.flag('json');
  final outputPath = parsed.option('output');
  final alphabet = parsed.option('alphabet');
  final sourceCount =
      (text == null ? 0 : 1) +
      (file == null ? 0 : 1) +
      (useStandardInput ? 1 : 0);
  const supportedAlphabets = <String>{'morse', 'nato', 'braille'};
  final invalid = parsed.rest.isNotEmpty || outputPath == '' || file == ''
      ? 'invalid-options'
      : sourceCount == 0
      ? 'missing-source'
      : sourceCount > 1
      ? 'conflicting-sources'
      : alphabet == null || !supportedAlphabets.contains(alphabet)
      ? 'invalid-alphabet'
      : null;
  if (invalid != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'validation',
      code: 'alphabet.$invalid',
      messageKey: 'error.alphabetDecode.validation',
      details: invalid == 'invalid-alphabet'
          ? const {'field': 'alphabet', 'reason': 'unsupported-alphabet'}
          : const {},
    );
    return 64;
  }

  void resourceFailure(String field) => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: 'resource',
    code: 'alphabet.resource-limit',
    messageKey: 'error.alphabetDecode.resource',
    details: {'field': field, 'reason': 'allocation-limit'},
  );

  void outputAccessFailure() => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: 'access',
    code: 'alphabet.output-access',
    messageKey: 'error.alphabetDecode.outputAccess',
  );

  late AlphabetDecodeOperationRequest request;
  try {
    request = text != null
        ? AlphabetDecodeOperationRequest.text(text, alphabet: alphabet!)
        : AlphabetDecodeOperationRequest.utf8Bytes(
            useStandardInput
                ? await readStandardInputBytes()
                : await readFileBytes(file!),
            alphabet: alphabet!,
          );
  } on OutOfMemoryError {
    resourceFailure('input');
    return 75;
  } on Object {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'access',
      code: useStandardInput ? 'alphabet.input-access' : 'alphabet.file-access',
      messageKey: useStandardInput
          ? 'error.alphabetDecode.inputAccess'
          : 'error.alphabetDecode.fileAccess',
    );
    return 74;
  }

  final result = await service.execute(request);
  return await result.fold(
    onSuccess: (value) async {
      late String stdoutPayload;
      try {
        if (json) {
          stdoutPayload = '${encodeJson(value.toJson())}\n';
        } else {
          final mapping = value.mapping;
          final firstLine = outputPath == null
              ? value.decoded
              : catalog.lookup(localeTag, 'alphabetDecode.savedResult');
          stdoutPayload =
              '$firstLine\n'
              '${catalog.lookup(localeTag, 'alphabetDecode.mappingLabel')}: '
              '${mapping.id} (${mapping.edition})\n'
              '${catalog.lookup(localeTag, 'alphabetDecode.mappingSourcesLabel')}: '
              '${mapping.sources.join(', ')}\n';
        }
      } on OutOfMemoryError {
        resourceFailure('decoded');
        return 75;
      } on Object {
        outputAccessFailure();
        return 74;
      }
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(value.decoded));
        } on OutOfMemoryError {
          resourceFailure('decoded');
          return 75;
        } on Object {
          outputAccessFailure();
          return 74;
        }
      }
      try {
        await writeSinkAndFlush(out, stdoutPayload);
      } on OutOfMemoryError {
        resourceFailure('decoded');
        return 75;
      } on Object {
        outputAccessFailure();
        return 74;
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runCipherEncode(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required BytesReader readStandardInputBytes,
  required FileBytesReader readFileBytes,
  required FileBytesWriter writeOutputFile,
  required CipherEncodeService service,
  required JsonObjectEncoder encodeJson,
}) async {
  final text = parsed.option('input');
  final file = parsed.option('file');
  final useStandardInput = parsed.flag('stdin');
  final json = parsed.flag('json');
  final outputPath = parsed.option('output');
  final cipher = parsed.option('cipher');
  final characterPolicy = parsed.option('character-policy')!;
  final sourceCount =
      (text == null ? 0 : 1) +
      (file == null ? 0 : 1) +
      (useStandardInput ? 1 : 0);
  const supportedCiphers = <String>{
    'caesar',
    'rot13',
    'vigenere',
    'atbash',
    'affine',
    'bacon',
    'rail-fence',
  };
  final invalid = parsed.rest.isNotEmpty || outputPath == '' || file == ''
      ? 'invalid-options'
      : sourceCount == 0
      ? 'missing-source'
      : sourceCount > 1
      ? 'conflicting-sources'
      : cipher == null || !supportedCiphers.contains(cipher)
      ? 'invalid-cipher'
      : !const {'preserve', 'reject'}.contains(characterPolicy)
      ? 'invalid-character-policy'
      : null;
  if (invalid != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'validation',
      code: 'cipher.$invalid',
      messageKey: 'error.cipherEncode.validation',
      details: invalid == 'invalid-cipher'
          ? const {'field': 'cipher', 'reason': 'unsupported-cipher'}
          : invalid == 'invalid-character-policy'
          ? const {'field': 'characterPolicy', 'reason': 'unsupported-policy'}
          : const {},
    );
    return 64;
  }

  void resourceFailure(String field) => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: 'resource',
    code: 'cipher.resource-limit',
    messageKey: 'error.cipherEncode.resource',
    details: {'field': field, 'reason': 'allocation-limit'},
  );

  void outputAccessFailure() => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: 'access',
    code: 'cipher.output-access',
    messageKey: 'error.cipherEncode.outputAccess',
  );

  late CipherEncodeOperationRequest request;
  try {
    request = text != null
        ? CipherEncodeOperationRequest.text(
            text,
            cipher: cipher!,
            characterPolicy: characterPolicy,
            shift: parsed.option('shift'),
            key: parsed.option('key'),
            affineA: parsed.option('a'),
            affineB: parsed.option('b'),
            rails: parsed.option('rails'),
          )
        : CipherEncodeOperationRequest.utf8Bytes(
            useStandardInput
                ? await readStandardInputBytes()
                : await readFileBytes(file!),
            cipher: cipher!,
            characterPolicy: characterPolicy,
            shift: parsed.option('shift'),
            key: parsed.option('key'),
            affineA: parsed.option('a'),
            affineB: parsed.option('b'),
            rails: parsed.option('rails'),
          );
  } on OutOfMemoryError {
    resourceFailure('input');
    return 75;
  } on Object {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'access',
      code: useStandardInput ? 'cipher.input-access' : 'cipher.file-access',
      messageKey: useStandardInput
          ? 'error.cipherEncode.inputAccess'
          : 'error.cipherEncode.fileAccess',
    );
    return 74;
  }

  final result = await service.execute(request);
  return await result.fold(
    onSuccess: (value) async {
      late String stdoutPayload;
      try {
        stdoutPayload = json
            ? '${encodeJson(value.toJson())}\n'
            : outputPath != null
            ? '${catalog.lookup(localeTag, 'cipherEncode.savedResult')}\n'
            : value.encoded;
      } on OutOfMemoryError {
        resourceFailure('encoded');
        return 75;
      } on Object {
        outputAccessFailure();
        return 74;
      }
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(value.encoded));
        } on OutOfMemoryError {
          resourceFailure('encoded');
          return 75;
        } on Object {
          outputAccessFailure();
          return 74;
        }
      }
      try {
        await writeSinkAndFlush(out, stdoutPayload);
      } on OutOfMemoryError {
        resourceFailure('encoded');
        return 75;
      } on Object {
        outputAccessFailure();
        return 74;
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runCipherDecode(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required BytesReader readStandardInputBytes,
  required FileBytesReader readFileBytes,
  required FileBytesWriter writeOutputFile,
  required CipherDecodeService service,
  required JsonObjectEncoder encodeJson,
}) async {
  final text = parsed.option('input');
  final file = parsed.option('file');
  final useStandardInput = parsed.flag('stdin');
  final json = parsed.flag('json');
  final outputPath = parsed.option('output');
  final cipher = parsed.option('cipher');
  final characterPolicy = parsed.option('character-policy')!;
  final sourceCount =
      (text == null ? 0 : 1) +
      (file == null ? 0 : 1) +
      (useStandardInput ? 1 : 0);
  const supportedCiphers = <String>{
    'caesar',
    'rot13',
    'vigenere',
    'atbash',
    'affine',
    'bacon',
    'rail-fence',
  };
  final invalid = parsed.rest.isNotEmpty || outputPath == '' || file == ''
      ? 'invalid-options'
      : sourceCount == 0
      ? 'missing-source'
      : sourceCount > 1
      ? 'conflicting-sources'
      : cipher == null || !supportedCiphers.contains(cipher)
      ? 'invalid-cipher'
      : !const {'preserve', 'reject'}.contains(characterPolicy)
      ? 'invalid-character-policy'
      : null;
  if (invalid != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'validation',
      code: 'cipher.$invalid',
      messageKey: 'error.cipherDecode.validation',
      details: invalid == 'invalid-cipher'
          ? const {'field': 'cipher', 'reason': 'unsupported-cipher'}
          : invalid == 'invalid-character-policy'
          ? const {'field': 'characterPolicy', 'reason': 'unsupported-policy'}
          : const {},
    );
    return 64;
  }

  void resourceFailure(String field) => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: 'resource',
    code: 'cipher.resource-limit',
    messageKey: 'error.cipherDecode.resource',
    details: {'field': field, 'reason': 'allocation-limit'},
  );

  void outputAccessFailure() => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: 'access',
    code: 'cipher.output-access',
    messageKey: 'error.cipherDecode.outputAccess',
  );

  late CipherDecodeOperationRequest request;
  try {
    request = text != null
        ? CipherDecodeOperationRequest.text(
            text,
            cipher: cipher!,
            characterPolicy: characterPolicy,
            shift: parsed.option('shift'),
            key: parsed.option('key'),
            affineA: parsed.option('a'),
            affineB: parsed.option('b'),
            rails: parsed.option('rails'),
          )
        : CipherDecodeOperationRequest.utf8Bytes(
            useStandardInput
                ? await readStandardInputBytes()
                : await readFileBytes(file!),
            cipher: cipher!,
            characterPolicy: characterPolicy,
            shift: parsed.option('shift'),
            key: parsed.option('key'),
            affineA: parsed.option('a'),
            affineB: parsed.option('b'),
            rails: parsed.option('rails'),
          );
  } on OutOfMemoryError {
    resourceFailure('input');
    return 75;
  } on Object {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'access',
      code: useStandardInput ? 'cipher.input-access' : 'cipher.file-access',
      messageKey: useStandardInput
          ? 'error.cipherDecode.inputAccess'
          : 'error.cipherDecode.fileAccess',
    );
    return 74;
  }

  final result = await service.execute(request);
  return await result.fold(
    onSuccess: (value) async {
      late String stdoutPayload;
      try {
        stdoutPayload = json
            ? '${encodeJson(value.toJson())}\n'
            : outputPath != null
            ? '${catalog.lookup(localeTag, 'cipherDecode.savedResult')}\n'
            : value.decoded;
      } on OutOfMemoryError {
        resourceFailure('decoded');
        return 75;
      } on Object {
        outputAccessFailure();
        return 74;
      }
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(value.decoded));
        } on OutOfMemoryError {
          resourceFailure('decoded');
          return 75;
        } on Object {
          outputAccessFailure();
          return 74;
        }
      }
      try {
        await writeSinkAndFlush(out, stdoutPayload);
      } on OutOfMemoryError {
        resourceFailure('decoded');
        return 75;
      } on Object {
        outputAccessFailure();
        return 74;
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runUrlEncode(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required BytesReader readStandardInputBytes,
  required FileBytesReader readFileBytes,
  required FileBytesWriter writeOutputFile,
  required UrlEncodeService service,
  required JsonObjectEncoder encodeJson,
}) async {
  final text = parsed.option('input');
  final file = parsed.option('file');
  final useStandardInput = parsed.flag('stdin');
  final json = parsed.flag('json');
  final outputPath = parsed.option('output');
  final mode = parsed.option('mode')!;
  final sourceCount =
      (text == null ? 0 : 1) +
      (file == null ? 0 : 1) +
      (useStandardInput ? 1 : 0);
  final invalid = parsed.rest.isNotEmpty || outputPath == '' || file == ''
      ? 'invalid-options'
      : sourceCount == 0
      ? 'missing-source'
      : sourceCount > 1
      ? 'conflicting-sources'
      : !const ['component', 'full'].contains(mode)
      ? 'invalid-mode'
      : null;
  if (invalid != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'validation',
      code: 'url-encode.$invalid',
      messageKey: 'error.urlEncode.validation',
      details: invalid == 'invalid-mode'
          ? {'field': 'mode', 'reason': 'unsupported-mode'}
          : const {},
    );
    return 64;
  }

  void resourceFailure(String field) => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: 'resource',
    code: 'url-encode.resource-limit',
    messageKey: 'error.urlEncode.resource',
    details: {'field': field, 'reason': 'allocation-limit'},
  );

  void outputAccessFailure() => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: 'access',
    code: 'url-encode.output-access',
    messageKey: 'error.urlEncode.outputAccess',
  );

  late UrlEncodeOperationRequest request;
  try {
    request = text != null
        ? UrlEncodeOperationRequest.text(text, mode: mode)
        : UrlEncodeOperationRequest.utf8Bytes(
            useStandardInput
                ? await readStandardInputBytes()
                : await readFileBytes(file!),
            mode: mode,
          );
  } on OutOfMemoryError {
    resourceFailure('input');
    return 75;
  } on Object {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'access',
      code: useStandardInput
          ? 'url-encode.input-access'
          : 'url-encode.file-access',
      messageKey: useStandardInput
          ? 'error.urlEncode.inputAccess'
          : 'error.urlEncode.fileAccess',
    );
    return 74;
  }
  final result = await service.execute(request);
  return await result.fold(
    onSuccess: (value) async {
      late String stdoutPayload;
      try {
        stdoutPayload = json
            ? '${encodeJson(value.toJson())}\n'
            : outputPath != null
            ? '${catalog.lookup(localeTag, 'urlEncode.savedResult')}\n'
            : value.encoded;
      } on OutOfMemoryError {
        resourceFailure('encoded');
        return 75;
      } on Object {
        outputAccessFailure();
        return 74;
      }
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(value.encoded));
        } on OutOfMemoryError {
          resourceFailure('encoded');
          return 75;
        } on Object {
          outputAccessFailure();
          return 74;
        }
      }
      try {
        await writeSinkAndFlush(out, stdoutPayload);
      } on OutOfMemoryError {
        resourceFailure('encoded');
        return 75;
      } on Object {
        outputAccessFailure();
        return 74;
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runGzipCompress(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required BytesReader readStandardInputBytes,
  required FileBytesReader readFileBytes,
  required FileBytesWriter writeOutputFile,
  required GzipCompressService service,
  required JsonObjectEncoder encodeJson,
}) async {
  final text = parsed.option('text');
  final file = parsed.option('file');
  final useStandardInput = parsed.flag('stdin');
  final json = parsed.flag('json');
  final outputPath = parsed.option('output');
  final sourceCount =
      (text == null ? 0 : 1) +
      (file == null ? 0 : 1) +
      (useStandardInput ? 1 : 0);
  final levelOption = parsed.option('level')!;
  final level = RegExp(r'^[0-9]$').hasMatch(levelOption)
      ? int.parse(levelOption)
      : null;
  final invalid = parsed.rest.isNotEmpty || outputPath == '' || file == ''
      ? 'invalid-options'
      : sourceCount == 0
      ? 'missing-source'
      : sourceCount > 1
      ? 'conflicting-sources'
      : level == null
      ? 'invalid-level'
      : outputPath == null && !json
      ? 'output-required'
      : null;
  if (invalid != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'validation',
      code: 'gzip-compress.$invalid',
      messageKey: 'error.gzipCompress.validation',
    );
    return 64;
  }

  void resourceFailure(String field) => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: 'resource',
    code: 'gzip-compress.resource-limit',
    messageKey: 'error.gzipCompress.resource',
    details: <String, Object?>{'field': field, 'reason': 'allocation-limit'},
  );

  late GzipCompressOperationRequest request;
  try {
    request = text != null
        ? GzipCompressOperationRequest.text(text, level: level!)
        : GzipCompressOperationRequest.bytes(
            useStandardInput
                ? await readStandardInputBytes()
                : await readFileBytes(file!),
            level: level!,
          );
  } on OutOfMemoryError {
    resourceFailure('input');
    return 75;
  } on Object {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'access',
      code: useStandardInput
          ? 'gzip-compress.input-access'
          : 'gzip-compress.file-access',
      messageKey: useStandardInput
          ? 'error.gzipCompress.inputAccess'
          : 'error.gzipCompress.fileAccess',
    );
    return 74;
  }

  final result = await service.execute(request);
  return await result.fold(
    onSuccess: (value) async {
      late String stdoutPayload;
      try {
        if (json) {
          stdoutPayload = '${encodeJson(value.toJson())}\n';
        } else {
          final summary = catalog
              .lookup(localeTag, 'gzipCompress.savedResult')
              .replaceAll('{level}', '${value.level}')
              .replaceAll('{inputByteCount}', '${value.inputByteCount}')
              .replaceAll('{outputByteCount}', '${value.outputByteCount}');
          stdoutPayload = '$summary\n';
        }
      } on OutOfMemoryError {
        resourceFailure('output');
        return 75;
      }
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, value.bytes);
        } on OutOfMemoryError {
          resourceFailure('output');
          return 75;
        } on Object {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: json,
            kind: 'access',
            code: 'gzip-compress.output-access',
            messageKey: 'error.gzipCompress.outputAccess',
          );
          return 74;
        }
      }
      try {
        out.write(stdoutPayload);
      } on OutOfMemoryError {
        resourceFailure('output');
        return 75;
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runBase64Decode(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required BytesReader readStandardInputBytes,
  required FileBytesReader readFileBytes,
  required FileBytesWriter writeOutputFile,
  required Base64DecodeService base64DecodeService,
  required JsonObjectEncoder encodeJson,
}) async {
  final text = parsed.option('text');
  final file = parsed.option('file');
  final useStandardInput = parsed.flag('stdin');
  final json = parsed.flag('json');
  final outputPath = parsed.option('output');
  final sourceCount =
      (text == null ? 0 : 1) +
      (file == null ? 0 : 1) +
      (useStandardInput ? 1 : 0);

  if (sourceCount != 1) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'validation',
      code: sourceCount == 0
          ? 'base64-decode.missing-source'
          : 'base64-decode.conflicting-sources',
      messageKey: 'error.base64Decode.validation',
    );
    return 64;
  }

  final mode = switch (parsed.option('mode')) {
    'text' => Base64DecodeMode.text,
    'binary' => Base64DecodeMode.binary,
    _ => null,
  };
  if (mode == null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'validation',
      code: 'base64-decode.invalid-mode',
      messageKey: 'error.base64Decode.validation',
    );
    return 64;
  }
  if (mode == Base64DecodeMode.binary && outputPath == null && !json) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: false,
      kind: 'validation',
      code: 'base64-decode.binary-destination-required',
      messageKey: 'error.base64Decode.validation',
    );
    return 64;
  }

  late Base64DecodeOperationRequest request;
  if (text != null) {
    request = Base64DecodeOperationRequest.text(text, mode: mode);
  } else {
    try {
      final bytes = useStandardInput
          ? await readStandardInputBytes()
          : await readFileBytes(file!);
      request = Base64DecodeOperationRequest.utf8Bytes(bytes, mode: mode);
    } on OutOfMemoryError {
      _writeBase64DecodeResourceFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        field: 'input',
      );
      return 75;
    } on Object {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        kind: 'access',
        code: useStandardInput
            ? 'base64-decode.input-access'
            : 'base64-decode.file-access',
        messageKey: useStandardInput
            ? 'error.base64Decode.inputAccess'
            : 'error.base64Decode.fileAccess',
      );
      return 74;
    }
  }

  final result = await base64DecodeService.execute(request);
  return await result.fold(
    onSuccess: (value) async {
      String? stdoutPayload;
      try {
        if (json) {
          stdoutPayload = '${encodeJson(value.toJson())}\n';
        } else if (outputPath == null) {
          stdoutPayload = value.text!;
        } else {
          stdoutPayload =
              '${catalog.lookup(localeTag, 'base64Decode.savedResult')}\n';
        }
      } on OutOfMemoryError {
        _writeBase64DecodeResourceFailure(
          err,
          catalog: catalog,
          localeTag: localeTag,
          json: json,
          field: 'output',
        );
        return 75;
      }

      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, value.bytes);
        } on OutOfMemoryError {
          _writeBase64DecodeResourceFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: json,
            field: 'output',
          );
          return 75;
        } on Object {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: json,
            kind: 'access',
            code: 'base64-decode.output-access',
            messageKey: 'error.base64Decode.outputAccess',
          );
          return 74;
        }
      }

      try {
        out.write(stdoutPayload);
      } on OutOfMemoryError {
        _writeBase64DecodeResourceFailure(
          err,
          catalog: catalog,
          localeTag: localeTag,
          json: json,
          field: 'output',
        );
        return 75;
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

void _writeBase64DecodeResourceFailure(
  StringSink err, {
  required MessageCatalog catalog,
  required String localeTag,
  required bool json,
  required String field,
}) {
  _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: 'resource',
    code: 'base64-decode.resource-limit',
    messageKey: 'error.base64Decode.resource',
    details: <String, Object?>{'field': field, 'reason': 'allocation-limit'},
  );
}

void _writeBase64ResourceFailure(
  StringSink err, {
  required ArgResults parsed,
  required MessageCatalog catalog,
  required String localeTag,
  required String field,
}) {
  _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: parsed.flag('json'),
    kind: 'resource',
    code: 'base64-encode.resource-limit',
    messageKey: 'error.base64Encode.resource',
    details: <String, Object?>{'field': field, 'reason': 'allocation-limit'},
  );
}

Future<List<int>> _readStandardInputBytes() =>
    stdin.fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));

final class _QrDecodeInputLimit implements Exception {
  const _QrDecodeInputLimit();
}

Future<List<int>> _readQrDecodeFileBytes(String path) async {
  final file = File(path);
  if (await file.length() > QrDecoder.defaultMaxInputBytes) {
    throw const _QrDecodeInputLimit();
  }
  return _readQrDecodeChunks(
    file.openRead(0, QrDecoder.defaultMaxInputBytes + 1),
  );
}

Future<List<int>> _readQrDecodeStandardInputBytes() =>
    _readQrDecodeChunks(stdin);

Future<List<int>> _readQrDecodeChunks(Stream<List<int>> chunks) async {
  final bytes = <int>[];
  try {
    await for (final chunk in chunks) {
      if (bytes.length + chunk.length > QrDecoder.defaultMaxInputBytes) {
        throw const _QrDecodeInputLimit();
      }
      bytes.addAll(chunk);
    }
    return bytes;
  } on Object {
    _clearBytes(bytes);
    rethrow;
  }
}

final class _QrEncodeInputLimit implements Exception {
  const _QrEncodeInputLimit();
}

Future<List<int>> _readQrEncodeFileBytes(String path) async {
  final file = File(path);
  if (await file.length() > QrEncoder.defaultMaxInputBytes) {
    throw const _QrEncodeInputLimit();
  }
  return _readQrEncodeChunks(
    file.openRead(0, QrEncoder.defaultMaxInputBytes + 1),
  );
}

Future<List<int>> _readQrEncodeStandardInputBytes() =>
    _readQrEncodeChunks(stdin);

Future<List<int>> _readQrEncodeChunks(Stream<List<int>> chunks) async {
  final bytes = <int>[];
  await for (final chunk in chunks) {
    if (bytes.length + chunk.length > QrEncoder.defaultMaxInputBytes) {
      _clearBytes(bytes);
      throw const _QrEncodeInputLimit();
    }
    bytes.addAll(chunk);
  }
  return bytes;
}

void _clearBytes(List<int> bytes) {
  try {
    bytes.fillRange(0, bytes.length, 0);
  } on Object {
    // Immutable collaborator bytes are released when this scope ends.
  }
}

final class _JwtInspectInputLimit implements Exception {
  const _JwtInspectInputLimit();
}

Future<List<int>> _readJwtInspectFileBytes(String path) async {
  final file = File(path);
  if (await file.length() > JwtInspector.defaultMaxInputBytes) {
    throw const _JwtInspectInputLimit();
  }
  final bytes = await file.readAsBytes();
  if (bytes.length <= JwtInspector.defaultMaxInputBytes) return bytes;
  bytes.fillRange(0, bytes.length, 0);
  throw const _JwtInspectInputLimit();
}

Future<List<int>> _readJwtInspectStandardInputBytes() async {
  final bytes = <int>[];
  await for (final chunk in stdin) {
    if (bytes.length + chunk.length > JwtInspector.defaultMaxInputBytes) {
      bytes.fillRange(0, bytes.length, 0);
      throw const _JwtInspectInputLimit();
    }
    bytes.addAll(chunk);
  }
  return bytes;
}

Future<int> _runTextAnalyze(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required FileBytesWriter writeOutputFile,
  required TextAnalyzeService textAnalyzeService,
}) async {
  final inputOption = parsed.option('input');
  final fileOption = parsed.option('file');
  if (inputOption != null && fileOption != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'text-analyze.conflicting-inputs',
      messageKey: 'error.textAnalyze.validation',
    );
    return 64;
  }

  late String input;
  try {
    input = fileOption != null
        ? await readFile(fileOption)
        : inputOption ?? await readStandardInput();
  } on Object {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'access',
      code: fileOption == null
          ? 'text-analyze.input-access'
          : 'text-analyze.file-access',
      messageKey: fileOption == null
          ? 'error.textAnalyze.inputAccess'
          : 'error.textAnalyze.fileAccess',
    );
    return 74;
  }

  final result = await textAnalyzeService.execute(
    TextAnalyzeOperationRequest(input: input),
  );
  return await result.fold(
    onSuccess: (value) async {
      final json = parsed.flag('json');
      final payload = json
          ? jsonEncode(value.toJson())
          : _humanTextAnalyzeResult(
              value,
              localeTag: localeTag,
              catalog: catalog,
            );
      final outputPath = parsed.option('output');
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(payload));
        } on Object {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: json,
            kind: 'access',
            code: 'text-analyze.output-access',
            messageKey: 'error.textAnalyze.outputAccess',
          );
          return 74;
        }
        out.writeln(catalog.lookup(localeTag, 'textAnalyze.savedResult'));
      } else if (json) {
        out.writeln(payload);
      } else {
        out.write(payload);
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: parsed.flag('json'),
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

String _humanTextAnalyzeResult(
  TextAnalyzeOutput output, {
  required String localeTag,
  required MessageCatalog catalog,
}) {
  final buffer = StringBuffer()
    ..writeln(
      '${catalog.lookup(localeTag, 'textAnalyze.characterCountLabel')}: '
      '${output.characterCount}',
    )
    ..writeln(
      '${catalog.lookup(localeTag, 'textAnalyze.wordCountLabel')}: '
      '${output.wordCount}',
    )
    ..writeln(
      '${catalog.lookup(localeTag, 'textAnalyze.lineCountLabel')}: '
      '${output.lineCount}',
    )
    ..writeln(
      '${catalog.lookup(localeTag, 'textAnalyze.byteCountLabel')}: '
      '${output.byteCount}',
    );
  return buffer.toString();
}

Future<int> _runTextEscape(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required FileBytesWriter writeOutputFile,
  required TextEscapeService textEscapeService,
}) async {
  final inputOption = parsed.option('input');
  final fileOption = parsed.option('file');
  if (inputOption != null && fileOption != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'text-escape.conflicting-inputs',
      messageKey: 'error.textEscape.validation',
    );
    return 64;
  }

  late String input;
  try {
    input = fileOption != null
        ? await readFile(fileOption)
        : inputOption ?? await readStandardInput();
  } on Object {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'access',
      code: fileOption == null
          ? 'text-escape.input-access'
          : 'text-escape.file-access',
      messageKey: fileOption == null
          ? 'error.textEscape.inputAccess'
          : 'error.textEscape.fileAccess',
    );
    return 74;
  }

  final result = await textEscapeService.execute(
    TextEscapeOperationRequest(input: input, mode: parsed.option('mode') ?? ''),
  );
  return await result.fold(
    onSuccess: (output) async {
      final outputPath = parsed.option('output');
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(output.escaped));
        } on Object {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: parsed.flag('json'),
            kind: 'access',
            code: 'text-escape.output-access',
            messageKey: 'error.textEscape.outputAccess',
          );
          return 74;
        }
        if (!parsed.flag('json')) {
          out.writeln(catalog.lookup(localeTag, 'textEscape.savedResult'));
          return 0;
        }
      }
      if (parsed.flag('json')) {
        out.writeln(jsonEncode(output.toJson()));
      } else {
        out.writeln(
          '${catalog.lookup(localeTag, 'textEscape.resultLabel')}: '
          '${output.escaped}',
        );
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: parsed.flag('json'),
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runTextTransform(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required FileBytesWriter writeOutputFile,
  required TextTransformService textTransformService,
}) async {
  final inputOption = parsed.option('input');
  final fileOption = parsed.option('file');
  if (inputOption != null && fileOption != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'text-transform.conflicting-inputs',
      messageKey: 'error.textTransform.validation',
    );
    return 64;
  }

  final mode = parsed.option('mode') ?? '';
  try {
    parseTextTransformMode(mode);
  } on TextTransformException catch (error) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: error.kind.name,
      code: error.code,
      messageKey: 'error.textTransform.validation',
      details: <String, Object?>{
        'field': ?error.field,
        'reason': ?error.reason,
      },
    );
    return 64;
  }

  late String input;
  try {
    input = fileOption != null
        ? await readFile(fileOption)
        : inputOption ?? await readStandardInput();
  } on Object {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'access',
      code: fileOption == null
          ? 'text-transform.input-access'
          : 'text-transform.file-access',
      messageKey: fileOption == null
          ? 'error.textTransform.inputAccess'
          : 'error.textTransform.fileAccess',
    );
    return 74;
  }

  final result = await textTransformService.execute(
    TextTransformOperationRequest(input: input, mode: mode),
  );
  return await result.fold(
    onSuccess: (output) async {
      final json = parsed.flag('json');
      final payload = json ? jsonEncode(output.toJson()) : output.output;
      final outputPath = parsed.option('output');
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(payload));
        } on Object {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: json,
            kind: 'access',
            code: 'text-transform.output-access',
            messageKey: 'error.textTransform.outputAccess',
          );
          return 74;
        }
        out.writeln(catalog.lookup(localeTag, 'textTransform.savedResult'));
      } else if (json) {
        out.writeln(payload);
      } else {
        out.write(payload);
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: parsed.flag('json'),
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runTextUnescape(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required FileBytesWriter writeOutputFile,
  required TextUnescapeService textUnescapeService,
}) async {
  final inputOption = parsed.option('input');
  final fileOption = parsed.option('file');
  if (inputOption != null && fileOption != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'text-unescape.conflicting-inputs',
      messageKey: 'error.textUnescape.validation',
    );
    return 64;
  }

  late String input;
  try {
    input = fileOption != null
        ? await readFile(fileOption)
        : inputOption ?? await readStandardInput();
  } on Object {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'access',
      code: fileOption == null
          ? 'text-unescape.input-access'
          : 'text-unescape.file-access',
      messageKey: fileOption == null
          ? 'error.textUnescape.inputAccess'
          : 'error.textUnescape.fileAccess',
    );
    return 74;
  }

  final result = await textUnescapeService.execute(
    TextUnescapeOperationRequest(
      input: input,
      mode: parsed.option('mode') ?? '',
    ),
  );
  return await result.fold(
    onSuccess: (output) async {
      final outputPath = parsed.option('output');
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(output.unescaped));
        } on Object {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: parsed.flag('json'),
            kind: 'access',
            code: 'text-unescape.output-access',
            messageKey: 'error.textUnescape.outputAccess',
          );
          return 74;
        }
        if (!parsed.flag('json')) {
          out.writeln(catalog.lookup(localeTag, 'textUnescape.savedResult'));
          return 0;
        }
      }
      if (parsed.flag('json')) {
        out.writeln(jsonEncode(output.toJson()));
      } else {
        out.writeln(
          '${catalog.lookup(localeTag, 'textUnescape.resultLabel')}: '
          '${output.unescaped}',
        );
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: parsed.flag('json'),
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runListCompare(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required FileBytesWriter writeOutputFile,
  required ListCompareService listCompareService,
}) async {
  final leftSources = <Object?>[
    parsed.option('left'),
    parsed.option('left-file'),
    if (parsed.flag('left-stdin')) true,
  ].where((source) => source != null).length;
  final rightSources = <Object?>[
    parsed.option('right'),
    parsed.option('right-file'),
    if (parsed.flag('right-stdin')) true,
  ].where((source) => source != null).length;

  if (leftSources != 1 || rightSources != 1) {
    final side = leftSources != 1 ? 'left' : 'right';
    final count = leftSources != 1 ? leftSources : rightSources;
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: count == 0
          ? 'list-compare.missing-$side-source'
          : 'list-compare.conflicting-$side-sources',
      messageKey: 'error.listCompare.validation',
    );
    return 64;
  }
  if (parsed.flag('left-stdin') && parsed.flag('right-stdin')) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'list-compare.shared-stdin',
      messageKey: 'error.listCompare.validation',
    );
    return 64;
  }

  late String left;
  late String right;
  try {
    left = await _readListSource(
      literal: parsed.option('left'),
      file: parsed.option('left-file'),
      standardInput: parsed.flag('left-stdin'),
      readStandardInput: readStandardInput,
      readFile: readFile,
    );
  } on Object {
    _writeListSourceFailure(
      err,
      parsed: parsed,
      catalog: catalog,
      localeTag: localeTag,
      side: 'left',
      file: parsed.option('left-file') != null,
    );
    return 74;
  }
  try {
    right = await _readListSource(
      literal: parsed.option('right'),
      file: parsed.option('right-file'),
      standardInput: parsed.flag('right-stdin'),
      readStandardInput: readStandardInput,
      readFile: readFile,
    );
  } on Object {
    _writeListSourceFailure(
      err,
      parsed: parsed,
      catalog: catalog,
      localeTag: localeTag,
      side: 'right',
      file: parsed.option('right-file') != null,
    );
    return 74;
  }

  final result = await listCompareService.execute(
    ListCompareOperationRequest(
      left: left,
      right: right,
      caseMode: parsed.option('case') ?? '',
      whitespaceMode: parsed.option('whitespace') ?? '',
      duplicateMode: parsed.option('duplicates') ?? '',
    ),
  );
  return await result.fold(
    onSuccess: (value) async {
      final json = parsed.flag('json');
      final payload = json
          ? jsonEncode(value.toJson())
          : _humanListCompareResult(
              value,
              localeTag: localeTag,
              catalog: catalog,
            );
      final outputPath = parsed.option('output');
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(payload));
        } on Object {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: json,
            kind: 'access',
            code: 'list-compare.output-access',
            messageKey: 'error.listCompare.outputAccess',
          );
          return 74;
        }
        out.writeln(catalog.lookup(localeTag, 'listCompare.savedResult'));
      } else if (json) {
        out.writeln(payload);
      } else {
        out.write(payload);
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: parsed.flag('json'),
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runTextCompare(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required FileBytesWriter writeOutputFile,
  required TextCompareService textCompareService,
}) async {
  final granularity = parsed.option('granularity') ?? '';
  try {
    parseTextCompareGranularity(granularity);
  } on TextCompareException catch (error) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: error.kind.name,
      code: error.code,
      messageKey: 'error.textCompare.validation',
      details: <String, Object?>{
        'field': ?error.field,
        'reason': ?error.reason,
      },
    );
    return 64;
  }

  final leftSources = <Object?>[
    parsed.option('left'),
    parsed.option('left-file'),
    if (parsed.flag('left-stdin')) true,
  ].where((source) => source != null).length;
  final rightSources = <Object?>[
    parsed.option('right'),
    parsed.option('right-file'),
    if (parsed.flag('right-stdin')) true,
  ].where((source) => source != null).length;

  if (leftSources != 1 || rightSources != 1) {
    final side = leftSources != 1 ? 'left' : 'right';
    final count = leftSources != 1 ? leftSources : rightSources;
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: count == 0
          ? 'text-compare.missing-$side-source'
          : 'text-compare.conflicting-$side-sources',
      messageKey: 'error.textCompare.validation',
    );
    return 64;
  }
  if (parsed.flag('left-stdin') && parsed.flag('right-stdin')) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'text-compare.shared-stdin',
      messageKey: 'error.textCompare.validation',
    );
    return 64;
  }

  late String left;
  late String right;
  try {
    left = await _readListSource(
      literal: parsed.option('left'),
      file: parsed.option('left-file'),
      standardInput: parsed.flag('left-stdin'),
      readStandardInput: readStandardInput,
      readFile: readFile,
    );
  } on Object {
    _writeTextCompareSourceFailure(
      err,
      parsed: parsed,
      catalog: catalog,
      localeTag: localeTag,
      side: 'left',
      file: parsed.option('left-file') != null,
    );
    return 74;
  }
  try {
    right = await _readListSource(
      literal: parsed.option('right'),
      file: parsed.option('right-file'),
      standardInput: parsed.flag('right-stdin'),
      readStandardInput: readStandardInput,
      readFile: readFile,
    );
  } on Object {
    _writeTextCompareSourceFailure(
      err,
      parsed: parsed,
      catalog: catalog,
      localeTag: localeTag,
      side: 'right',
      file: parsed.option('right-file') != null,
    );
    return 74;
  }

  final result = await textCompareService.execute(
    TextCompareOperationRequest(
      left: left,
      right: right,
      granularity: granularity,
    ),
  );
  return await result.fold(
    onSuccess: (value) async {
      final json = parsed.flag('json');
      final payload = json
          ? jsonEncode(value.toJson())
          : _humanTextCompareResult(
              value,
              localeTag: localeTag,
              catalog: catalog,
            );
      final outputPath = parsed.option('output');
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(payload));
        } on Object {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: json,
            kind: 'access',
            code: 'text-compare.output-access',
            messageKey: 'error.textCompare.outputAccess',
          );
          return 74;
        }
        out.writeln(catalog.lookup(localeTag, 'textCompare.savedResult'));
      } else if (json) {
        out.writeln(payload);
      } else {
        out.write(payload);
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: parsed.flag('json'),
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

List<String> _normalizeMultilineListOptions(List<String> args) {
  final normalized = <String>[];
  for (final argument in args) {
    final isLiteral =
        argument.startsWith('--text=') ||
        argument.startsWith('--input=') ||
        argument.startsWith('--left=') ||
        argument.startsWith('--right=');
    if (isLiteral && (argument.contains('\n') || argument.contains('\r'))) {
      final separator = argument.indexOf('=');
      normalized
        ..add(argument.substring(0, separator))
        ..add(argument.substring(separator + 1));
    } else {
      normalized.add(argument);
    }
  }
  return normalized;
}

Future<String> _readListSource({
  required String? literal,
  required String? file,
  required bool standardInput,
  required TextReader readStandardInput,
  required FileTextReader readFile,
}) {
  if (literal != null) return Future.value(literal);
  if (file != null) return readFile(file);
  assert(standardInput, 'A validated source must use standard input');
  return readStandardInput();
}

void _writeListSourceFailure(
  StringSink err, {
  required ArgResults parsed,
  required MessageCatalog catalog,
  required String localeTag,
  required String side,
  required bool file,
}) {
  _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: parsed.flag('json'),
    kind: 'access',
    code: 'list-compare.$side-${file ? 'file' : 'input'}-access',
    messageKey: file
        ? 'error.listCompare.fileAccess'
        : 'error.listCompare.inputAccess',
  );
}

void _writeTextCompareSourceFailure(
  StringSink err, {
  required ArgResults parsed,
  required MessageCatalog catalog,
  required String localeTag,
  required String side,
  required bool file,
}) {
  _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: parsed.flag('json'),
    kind: 'access',
    code: 'text-compare.$side-${file ? 'file' : 'input'}-access',
    messageKey: file
        ? 'error.textCompare.fileAccess'
        : 'error.textCompare.inputAccess',
  );
}

String _humanTextCompareResult(
  TextCompareOutput output, {
  required String localeTag,
  required MessageCatalog catalog,
}) {
  final buffer = StringBuffer();
  for (final span in output.spans) {
    buffer.writeln(
      '${catalog.lookup(localeTag, 'textCompare.kind.${span.kind.slug}')}: '
      '${_jsonEncodeHumanDiffText(span.text)}',
    );
  }
  buffer
    ..writeln(
      '${catalog.lookup(localeTag, 'textCompare.addedCountLabel')}: '
      '${output.summary.added}',
    )
    ..writeln(
      '${catalog.lookup(localeTag, 'textCompare.removedCountLabel')}: '
      '${output.summary.removed}',
    )
    ..writeln(
      '${catalog.lookup(localeTag, 'textCompare.unchangedCountLabel')}: '
      '${output.summary.unchanged}',
    );
  return buffer.toString();
}

String _jsonEncodeHumanDiffText(String value) {
  final encoded = jsonEncode(value);
  final buffer = StringBuffer();
  for (final rune in encoded.runes) {
    if (_humanEscapedWhitespace.contains(rune)) {
      buffer.write('\\u${rune.toRadixString(16).padLeft(4, '0')}');
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

const Set<int> _humanEscapedWhitespace = <int>{
  0x0085,
  0x00A0,
  0x1680,
  0x2000,
  0x2001,
  0x2002,
  0x2003,
  0x2004,
  0x2005,
  0x2006,
  0x2007,
  0x2008,
  0x2009,
  0x200A,
  0x2028,
  0x2029,
  0x202F,
  0x205F,
  0x3000,
};

String _humanListCompareResult(
  ListCompareOutput output, {
  required String localeTag,
  required MessageCatalog catalog,
}) {
  final buffer = StringBuffer();
  void writeSection(String messageKey, List<String> values) {
    buffer.writeln('${catalog.lookup(localeTag, messageKey)}:');
    for (final value in values) {
      buffer.writeln(value);
    }
  }

  writeSection('listCompare.leftOnlyLabel', output.leftOnly);
  writeSection('listCompare.rightOnlyLabel', output.rightOnly);
  writeSection('listCompare.intersectionLabel', output.intersection);
  buffer.writeln(
    '${catalog.lookup(localeTag, 'listCompare.equalLabel')}: '
    '${catalog.lookup(localeTag, output.equal ? 'listCompare.yesValue' : 'listCompare.noValue')}',
  );
  return buffer.toString();
}

Future<int> _runNumberBaseConvert(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required FileBytesWriter writeOutputFile,
  required NumberBaseService numberBaseService,
}) async {
  final sourceBase = _parseNumberBase(
    parsed.option('from'),
    field: 'sourceBase',
    parsed: parsed,
    localeTag: localeTag,
    catalog: catalog,
    err: err,
  );
  if (sourceBase == null) return 64;
  final targetBase = _parseNumberBase(
    parsed.option('to'),
    field: 'targetBase',
    parsed: parsed,
    localeTag: localeTag,
    catalog: catalog,
    err: err,
  );
  if (targetBase == null) return 64;

  final inputOption = parsed.option('input');
  final fileOption = parsed.option('file');
  if (inputOption != null && fileOption != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'number-base.conflicting-inputs',
      messageKey: 'error.numberBase.validation',
    );
    return 64;
  }

  late String value;
  try {
    value = fileOption != null
        ? await readFile(fileOption)
        : inputOption ?? await readStandardInput();
  } on Object {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'access',
      code: fileOption == null
          ? 'number-base.input-access'
          : 'number-base.file-access',
      messageKey: fileOption == null
          ? 'error.numberBase.inputAccess'
          : 'error.numberBase.fileAccess',
    );
    return 74;
  }

  final result = await numberBaseService.execute(
    NumberBaseOperationRequest(
      value: value,
      sourceBase: sourceBase,
      targetBase: targetBase,
    ),
  );
  return await result.fold(
    onSuccess: (output) async {
      final outputPath = parsed.option('output');
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(output.converted));
        } on Object {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: parsed.flag('json'),
            kind: 'access',
            code: 'number-base.output-access',
            messageKey: 'error.numberBase.outputAccess',
          );
          return 74;
        }
        if (!parsed.flag('json')) {
          out.writeln(catalog.lookup(localeTag, 'numberBase.savedResult'));
          return 0;
        }
      }
      if (parsed.flag('json')) {
        out.writeln(jsonEncode(output.toJson()));
      } else {
        out.writeln(
          '${catalog.lookup(localeTag, 'numberBase.resultLabel')}: '
          '${output.converted}',
        );
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: parsed.flag('json'),
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

int? _parseNumberBase(
  String? raw, {
  required String field,
  required ArgResults parsed,
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink err,
}) {
  final parsedBase = raw == null ? null : int.tryParse(raw);
  final reason = raw == null
      ? 'missing-base'
      : parsedBase == null
      ? 'not-an-integer'
      : parsedBase < 2 || parsedBase > 36
      ? 'out-of-range-base'
      : null;
  if (reason == null) return parsedBase;
  _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: parsed.flag('json'),
    kind: 'validation',
    code: 'number-base.invalid-base',
    messageKey: 'error.numberBase.validation',
    details: <String, Object?>{'field': field, 'reason': reason},
  );
  return null;
}

Future<int> _runXmlFormat(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required FileBytesWriter writeOutputFile,
  required XmlFormatService xmlFormatService,
}) async {
  final inputOption = parsed.option('input');
  final fileOption = parsed.option('file');
  if (inputOption != null && fileOption != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'xml-format.conflicting-inputs',
      messageKey: 'error.xmlFormat.validation',
    );
    return 64;
  }

  late String source;
  try {
    source = fileOption != null
        ? await readFile(fileOption)
        : inputOption ?? await readStandardInput();
  } on Object {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'access',
      code: fileOption == null
          ? 'xml-format.input-access'
          : 'xml-format.file-access',
      messageKey: fileOption == null
          ? 'error.xmlFormat.inputAccess'
          : 'error.xmlFormat.fileAccess',
    );
    return 74;
  }

  final indent = int.tryParse(parsed.option('indent') ?? '');
  if (indent == null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'xml-format.invalid-indent',
      messageKey: 'error.xmlFormat.validation',
    );
    return 64;
  }

  final result = await xmlFormatService.execute(
    XmlFormatOperationRequest(source: source, indent: indent),
  );
  return await result.fold(
    onSuccess: (value) async {
      final outputPath = parsed.option('output');
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(value.formatted));
        } on Object {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: parsed.flag('json'),
            kind: 'access',
            code: 'xml-format.output-access',
            messageKey: 'error.xmlFormat.outputAccess',
          );
          return 74;
        }
        if (!parsed.flag('json')) {
          out.writeln(catalog.lookup(localeTag, 'xmlFormat.savedResult'));
          return 0;
        }
      }
      if (parsed.flag('json')) {
        out.writeln(jsonEncode(value.toJson()));
      } else {
        out.write(value.formatted);
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: parsed.flag('json'),
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runSqlFormat(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required FileBytesWriter writeOutputFile,
  required SqlFormatService sqlFormatService,
}) async {
  final inputOption = parsed.option('input');
  final fileOption = parsed.option('file');
  if (inputOption != null && fileOption != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'sql-format.conflicting-inputs',
      messageKey: 'error.sqlFormat.validation',
    );
    return 64;
  }

  late String source;
  try {
    source = fileOption != null
        ? await readFile(fileOption)
        : inputOption ?? await readStandardInput();
  } on Object {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'access',
      code: fileOption == null
          ? 'sql-format.input-access'
          : 'sql-format.file-access',
      messageKey: fileOption == null
          ? 'error.sqlFormat.inputAccess'
          : 'error.sqlFormat.fileAccess',
    );
    return 74;
  }

  final dialect = parseSqlDialect(parsed.option('dialect') ?? '');
  final indent = int.tryParse(parsed.option('indent') ?? '');
  final keywordCase = parseSqlKeywordCase(parsed.option('keyword-case') ?? '');
  if (dialect == null || indent == null || keywordCase == null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: dialect == null
          ? 'sql-format.invalid-dialect'
          : indent == null
          ? 'sql-format.invalid-indent'
          : 'sql-format.invalid-keyword-case',
      messageKey: 'error.sqlFormat.validation',
    );
    return 64;
  }

  final result = await sqlFormatService.execute(
    SqlFormatOperationRequest(
      source: source,
      dialect: dialect,
      indent: indent,
      keywordCase: keywordCase,
    ),
  );
  return await result.fold(
    onSuccess: (value) async {
      final outputPath = parsed.option('output');
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(value.formatted));
        } on Object {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: parsed.flag('json'),
            kind: 'access',
            code: 'sql-format.output-access',
            messageKey: 'error.sqlFormat.outputAccess',
          );
          return 74;
        }
        if (!parsed.flag('json')) {
          out.writeln(catalog.lookup(localeTag, 'sqlFormat.savedResult'));
          return 0;
        }
      }
      if (parsed.flag('json')) {
        out.writeln(jsonEncode(value.toJson()));
      } else {
        out.write(value.formatted);
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: parsed.flag('json'),
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runJsonFormat(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required FileBytesWriter writeOutputFile,
  required JsonFormatService jsonFormatService,
}) async {
  final inputOption = parsed.option('input');
  final fileOption = parsed.option('file');
  if (inputOption != null && fileOption != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'json-format.conflicting-inputs',
      messageKey: 'error.jsonFormat.validation',
    );
    return 64;
  }

  late String source;
  try {
    source = fileOption != null
        ? await readFile(fileOption)
        : inputOption ?? await readStandardInput();
  } on Object {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'access',
      code: fileOption == null
          ? 'json-format.input-access'
          : 'json-format.file-access',
      messageKey: fileOption == null
          ? 'error.jsonFormat.inputAccess'
          : 'error.jsonFormat.fileAccess',
    );
    return 74;
  }

  final indent = int.tryParse(parsed.option('indent') ?? '');
  if (indent == null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'json-format.invalid-indent',
      messageKey: 'error.jsonFormat.validation',
    );
    return 64;
  }
  final result = await jsonFormatService.execute(
    JsonFormatOperationRequest(source: source, indent: indent),
  );
  return await result.fold(
    onSuccess: (value) async {
      final outputPath = parsed.option('output');
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(value.formatted));
        } on IOException {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: parsed.flag('json'),
            kind: 'access',
            code: 'json-format.output-access',
            messageKey: 'error.jsonFormat.outputAccess',
          );
          return 74;
        }
        if (!parsed.flag('json')) {
          out.writeln(catalog.lookup(localeTag, 'jsonFormat.savedResult'));
          return 0;
        }
      }
      if (parsed.flag('json')) {
        out.writeln(jsonEncode(value.toJson()));
      } else {
        out.write(value.formatted);
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: parsed.flag('json'),
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runJsonToYaml(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required FileBytesWriter writeOutputFile,
  required JsonYamlService jsonYamlService,
}) async {
  final inputOption = parsed.option('input');
  final fileOption = parsed.option('file');
  if (inputOption != null && fileOption != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'json-yaml.conflicting-inputs',
      messageKey: 'error.jsonYaml.validation',
    );
    return 64;
  }

  late String source;
  try {
    source = fileOption != null
        ? await readFile(fileOption)
        : inputOption ?? await readStandardInput();
  } on IOException {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'access',
      code: fileOption == null
          ? 'json-yaml.input-access'
          : 'json-yaml.file-access',
      messageKey: fileOption == null
          ? 'error.jsonYaml.inputAccess'
          : 'error.jsonYaml.fileAccess',
    );
    return 74;
  }

  final indent = int.tryParse(parsed.option('indent') ?? '');
  if (indent == null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'json-yaml.invalid-indent',
      messageKey: 'error.jsonYaml.validation',
    );
    return 64;
  }
  final result = await jsonYamlService.execute(
    JsonYamlOperationRequest(
      source: source,
      indent: indent,
      quoteStrings: parsed.flag('quote-strings'),
    ),
  );
  return await result.fold(
    onSuccess: (value) async {
      final outputPath = parsed.option('output');
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(value.yaml));
        } on IOException {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: parsed.flag('json'),
            kind: 'access',
            code: 'json-yaml.output-access',
            messageKey: 'error.jsonYaml.outputAccess',
          );
          return 74;
        }
        if (!parsed.flag('json')) {
          out.writeln(catalog.lookup(localeTag, 'jsonYaml.savedResult'));
          return 0;
        }
      }
      if (parsed.flag('json')) {
        out.writeln(jsonEncode(value.toJson()));
      } else {
        out.write(value.yaml);
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: parsed.flag('json'),
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runJsonArrayToCsv(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required FileBytesWriter writeOutputFile,
  required JsonCsvService jsonCsvService,
}) async {
  final inputOption = parsed.option('input');
  final fileOption = parsed.option('file');
  if (inputOption != null && fileOption != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'json-csv.conflicting-inputs',
      messageKey: 'error.jsonCsv.validation',
    );
    return 64;
  }

  late String source;
  try {
    source = fileOption != null
        ? await readFile(fileOption)
        : inputOption ?? await readStandardInput();
  } on IOException {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'access',
      code: fileOption == null
          ? 'json-csv.input-access'
          : 'json-csv.file-access',
      messageKey: fileOption == null
          ? 'error.jsonCsv.inputAccess'
          : 'error.jsonCsv.fileAccess',
    );
    return 74;
  }

  final result = await jsonCsvService.execute(
    JsonCsvOperationRequest(
      source: source,
      delimiter: parsed.option('delimiter') ?? 'comma',
      includeHeaders: parsed.flag('headers'),
    ),
  );
  return await result.fold(
    onSuccess: (value) async {
      final outputPath = parsed.option('output');
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(value.csv));
        } on IOException {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: parsed.flag('json'),
            kind: 'access',
            code: 'json-csv.output-access',
            messageKey: 'error.jsonCsv.outputAccess',
          );
          return 74;
        }
        if (!parsed.flag('json')) {
          out.writeln(catalog.lookup(localeTag, 'jsonCsv.savedResult'));
          return 0;
        }
      }
      if (parsed.flag('json')) {
        out.writeln(jsonEncode(value.toJson()));
      } else {
        out.write(value.csv);
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: parsed.flag('json'),
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<void> _writeFileExactly(String path, List<int> bytes) async {
  final target = File(path);
  try {
    await target.writeAsBytes(bytes, flush: true);
  } on Object {
    try {
      if (await target.exists()) await target.delete();
    } on IOException {
      // Preserve the original write failure as the actionable diagnostic.
    }
    rethrow;
  }
}

Future<void> _writeFileTransactionally(
  String path,
  List<int> bytes, {
  required FileBytesWriter writeStage,
  required TransactionalFileOperations operations,
}) => native_output.TransactionalFileWriter(
  writeStage: writeStage,
  operations: operations,
).write(path, bytes);

Future<void> _writeFileStageExactly(String path, List<int> bytes) =>
    native_output.writeFileStageExactly(path, bytes);

Future<int> _runJsonArrayToTable(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required JsonTableService jsonTableService,
}) async {
  final inputOption = parsed.option('input');
  final fileOption = parsed.option('file');
  if (inputOption != null && fileOption != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'json-table.conflicting-inputs',
      messageKey: 'error.jsonTable.validation',
    );
    return 64;
  }

  late String source;
  try {
    source = fileOption != null
        ? await readFile(fileOption)
        : inputOption ?? await readStandardInput();
  } on IOException {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'access',
      code: fileOption == null
          ? 'json-table.input-access'
          : 'json-table.file-access',
      messageKey: fileOption == null
          ? 'error.jsonTable.inputAccess'
          : 'error.jsonTable.fileAccess',
    );
    return 74;
  }

  final result = await jsonTableService.execute(
    JsonTableOperationRequest(
      source: source,
      includeRowNumbers: parsed.flag('row-numbers'),
    ),
  );
  return result.fold(
    onSuccess: (value) {
      if (parsed.flag('json')) {
        out.writeln(jsonEncode(value.toJson()));
      } else {
        _writeHumanJsonTable(
          value,
          localeTag: localeTag,
          catalog: catalog,
          out: out,
        );
      }
      return 0;
    },
    onFailure: (failure) {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: parsed.flag('json'),
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runDateConvert(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required DateService dateService,
}) async {
  final valueOption = parsed.option('value');
  final fileOption = parsed.option('file');
  if (valueOption != null && fileOption != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'date.conflicting-inputs',
      messageKey: 'error.date.validation',
    );
    return 64;
  }

  late String value;
  try {
    value = fileOption != null
        ? await readFile(fileOption)
        : valueOption ?? await readStandardInput();
  } on IOException {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'access',
      code: fileOption == null ? 'date.input-access' : 'date.file-access',
      messageKey: fileOption == null
          ? 'error.date.inputAccess'
          : 'error.date.fileAccess',
    );
    return 74;
  }

  final source = DateRepresentation.tryParse(parsed.option('from') ?? '');
  final target = DateRepresentation.tryParse(parsed.option('to') ?? '');
  if (source == null || target == null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'date.invalid-representation',
      messageKey: 'error.date.validation',
    );
    return 64;
  }

  final result = await dateService.execute(
    DateRequest(
      value: value.trim(),
      sourceRepresentation: source,
      targetRepresentation: target,
      sourceTimeZone: parsed.option('source-timezone') ?? 'UTC',
      targetTimeZone: parsed.option('target-timezone') ?? 'UTC',
      sourcePattern: parsed.option('source-pattern'),
      targetPattern: parsed.option('target-pattern'),
    ),
  );
  return result.fold(
    onSuccess: (value) {
      if (parsed.flag('json')) {
        out.writeln(jsonEncode(value.toJson()));
      } else {
        out.writeln(
          '${catalog.lookup(localeTag, 'date.resultLabel')}: '
          '${value.conversion.convertedValue}',
        );
        out.writeln(
          '${catalog.lookup(localeTag, 'date.utcLabel')}: '
          '${value.conversion.utcIso8601}',
        );
      }
      return 0;
    },
    onFailure: (failure) {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: parsed.flag('json'),
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runCronParse(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required CronService cronService,
  required DateTime Function() currentTime,
}) async {
  final expressionOption = parsed.option('expression');
  final fileOption = parsed.option('file');
  if (expressionOption != null && fileOption != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'cron.conflicting-inputs',
      messageKey: 'error.cron.validation',
    );
    return 64;
  }

  late String expression;
  if (fileOption != null) {
    try {
      expression = await readFile(fileOption);
    } on IOException {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: parsed.flag('json'),
        kind: 'access',
        code: 'cron.file-access',
        messageKey: 'error.cron.fileAccess',
      );
      return 74;
    }
  } else if (expressionOption != null) {
    expression = expressionOption;
  } else {
    try {
      expression = await readStandardInput();
    } on IOException {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: parsed.flag('json'),
        kind: 'access',
        code: 'cron.input-access',
        messageKey: 'error.cron.inputAccess',
      );
      return 74;
    }
  }

  final count = int.tryParse(parsed.option('count') ?? '');
  final atSource = parsed.option('at');
  final reference = atSource == null
      ? currentTime().toUtc()
      : parseCronReference(atSource);
  if (count == null || reference == null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: count == null ? 'cron.invalid-count' : 'cron.invalid-reference',
      messageKey: 'error.cron.validation',
    );
    return 64;
  }

  final result = await cronService.execute(
    CronRequest(
      expression: expression.trim(),
      timeZone: parsed.option('timezone') ?? 'UTC',
      occurrenceCount: count,
      referenceUtc: reference,
    ),
  );
  return result.fold(
    onSuccess: (value) {
      if (parsed.flag('json')) {
        out.writeln(jsonEncode(value.toJson()));
      } else {
        _writeHumanCronResult(
          value,
          localeTag: localeTag,
          catalog: catalog,
          out: out,
        );
      }
      return 0;
    },
    onFailure: (failure) {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: parsed.flag('json'),
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

int _exitCodeFor(FailureKind kind) => switch (kind) {
  FailureKind.validation => 64,
  FailureKind.range => 70,
  FailureKind.processing => 70,
  FailureKind.access => 74,
  FailureKind.resource => 75,
  FailureKind.update => 69,
  FailureKind.unexpected => 70,
};

void _writeFailure(
  StringSink err, {
  required MessageCatalog catalog,
  required String localeTag,
  required bool json,
  required String kind,
  required String code,
  required String messageKey,
  Map<String, Object?> details = const <String, Object?>{},
}) {
  final message = catalog.lookup(localeTag, messageKey);
  if (!json) {
    err.writeln(message);
    if (details.isNotEmpty) {
      final location = details['path'] ?? details['offset'];
      if (location != null) {
        err.writeln(
          '${catalog.lookup(localeTag, 'jsonTable.locationLabel')}: $location',
        );
      }
    }
    return;
  }
  err.writeln(
    jsonEncode(<String, Object?>{
      'error': <String, Object?>{
        'kind': kind,
        'code': code,
        'message': message,
        if (details.isNotEmpty) 'location': details,
      },
    }),
  );
}

void _writeHumanJsonTable(
  JsonTableOutput output, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
}) {
  final table = output.table;
  if (table.rows.isEmpty) {
    out.writeln(catalog.lookup(localeTag, 'jsonTable.emptyResult'));
    return;
  }
  if (table.columns.isEmpty && !table.includeRowNumbers) {
    out.writeln(catalog.lookup(localeTag, 'jsonTable.noColumnsResult'));
    out.writeln(
      '${catalog.lookup(localeTag, 'jsonTable.rowCountLabel')}: '
      '${table.rows.length}',
    );
    return;
  }

  final headings = <String>[
    if (table.includeRowNumbers)
      catalog.lookup(localeTag, 'jsonTable.rowNumberLabel'),
    ...table.columns,
  ];
  out.writeln('| ${headings.map(_escapeTableCell).join(' | ')} |');
  out.writeln('| ${headings.map((_) => '---').join(' | ')} |');
  for (var index = 0; index < table.rows.length; index++) {
    final cells = <String>[
      if (table.includeRowNumbers) '${index + 1}',
      ...table.rows[index],
    ];
    out.writeln('| ${cells.map(_escapeTableCell).join(' | ')} |');
  }
}

String _escapeTableCell(String value) => value
    .replaceAll('\\', r'\\')
    .replaceAll('|', r'\|')
    .replaceAll('\r\n', '<br>')
    .replaceAll('\r', '<br>')
    .replaceAll('\n', '<br>');

void _writeHumanCronResult(
  CronOutput output, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
}) {
  final evaluation = output.evaluation;
  out.writeln(
    '${catalog.lookup(localeTag, 'cron.scheduleLabel')}: '
    '${evaluation.normalizedExpression}',
  );
  out.writeln(
    '${catalog.lookup(localeTag, 'cron.timeZoneLabel')}: ${evaluation.timeZone}',
  );
  final descriptions = evaluation.fields.entries
      .map((entry) {
        final label = catalog.lookup(localeTag, 'cron.field.${entry.key}');
        final value = entry.value == '*'
            ? catalog.lookup(localeTag, 'cron.everyValue')
            : entry.value;
        return '$label $value';
      })
      .join('; ');
  out.writeln(
    '${catalog.lookup(localeTag, 'cron.explanationLabel')}: $descriptions',
  );
  for (final occurrence in evaluation.previous) {
    out.writeln(
      '${catalog.lookup(localeTag, 'cron.previousLabel')}: '
      '${occurrence.localIso8601}',
    );
  }
  for (final occurrence in evaluation.next) {
    out.writeln(
      '${catalog.lookup(localeTag, 'cron.nextLabel')}: '
      '${occurrence.localIso8601}',
    );
  }
}

Future<int> _runChecksumGenerate(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required BytesReader readStandardInputBytes,
  required FileBytesReader readFileBytes,
  required FileBytesWriter writeOutputFile,
  required ChecksumGenerateService service,
  required JsonObjectEncoder encodeJson,
}) async {
  final text = parsed.option('input');
  final file = parsed.option('file');
  final useStandardInput = parsed.flag('stdin');
  final json = parsed.flag('json');
  final outputPath = parsed.option('output');
  final algorithm = parsed.option('algorithm')!;
  final sourceCount =
      (text == null ? 0 : 1) +
      (file == null ? 0 : 1) +
      (useStandardInput ? 1 : 0);
  final invalid = parsed.rest.isNotEmpty || outputPath == '' || file == ''
      ? 'invalid-options'
      : sourceCount == 0
      ? 'missing-source'
      : sourceCount > 1
      ? 'conflicting-sources'
      : !ChecksumGenerator.algorithms.contains(algorithm)
      ? 'invalid-algorithm'
      : null;
  if (invalid != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'validation',
      code: 'checksum-generate.$invalid',
      messageKey: 'error.checksumGenerate.validation',
      details: invalid == 'invalid-algorithm'
          ? {'field': 'algorithm', 'reason': 'unsupported-algorithm'}
          : const {},
    );
    return 64;
  }

  void resourceFailure(String field) => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: 'resource',
    code: 'checksum-generate.resource-limit',
    messageKey: 'error.checksumGenerate.resource',
    details: {'field': field, 'reason': 'allocation-limit'},
  );

  void outputAccessFailure() => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: 'access',
    code: 'checksum-generate.output-access',
    messageKey: 'error.checksumGenerate.outputAccess',
  );

  late ChecksumGenerateOperationRequest request;
  try {
    request = text != null
        ? ChecksumGenerateOperationRequest.text(text, algorithm: algorithm)
        : ChecksumGenerateOperationRequest.bytes(
            useStandardInput
                ? await readStandardInputBytes()
                : await readFileBytes(file!),
            algorithm: algorithm,
          );
  } on OutOfMemoryError {
    resourceFailure('input');
    return 75;
  } on Object {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: json,
      kind: 'access',
      code: useStandardInput
          ? 'checksum-generate.input-access'
          : 'checksum-generate.file-access',
      messageKey: useStandardInput
          ? 'error.checksumGenerate.inputAccess'
          : 'error.checksumGenerate.fileAccess',
    );
    return 74;
  }
  final result = await service.execute(request);
  return await result.fold(
    onSuccess: (value) async {
      late String stdoutPayload;
      try {
        stdoutPayload = json
            ? '${encodeJson(value.toJson())}\n'
            : outputPath != null
            ? '${catalog.lookup(localeTag, 'checksumGenerate.savedResult')}\n'
            : '${value.checksum}\n';
      } on OutOfMemoryError {
        resourceFailure('encoded');
        return 75;
      } on Object {
        outputAccessFailure();
        return 74;
      }
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode('${value.checksum}\n'));
        } on OutOfMemoryError {
          resourceFailure('encoded');
          return 75;
        } on Object {
          outputAccessFailure();
          return 74;
        }
      }
      try {
        await writeSinkAndFlush(out, stdoutPayload);
      } on OutOfMemoryError {
        resourceFailure('encoded');
        return 75;
      } on Object {
        outputAccessFailure();
        return 74;
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: json,
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runCard(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required CardService service,
  required JsonObjectEncoder encodeJson,
  required FileBytesWriter writeOutputFile,
}) async {
  final json = parsed.flag('json');
  final path = parsed.option('output');
  void fail(
    String kind,
    String code,
    String messageKey, [
    Map<String, Object?> details = const {},
  ]) => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: kind,
    code: code,
    messageKey: messageKey,
    details: details,
  );
  if (parsed.rest.isNotEmpty || path == '') {
    fail('validation', 'card.invalid-options', 'error.card.validation');
    return 64;
  }
  final result = await service.execute(
    CardOperationRequest(
      network: parsed.option('network')!,
      count: parsed.option('count')!,
    ),
  );
  return await result.fold(
    onSuccess: (value) async {
      try {
        final human = [
          catalog.lookup(localeTag, 'card.syntheticLabel'),
          ...value.values,
        ].join('\n');
        final payload = json
            ? '${encodeJson(value.toJson())}\n'
            : path != null
            ? '${catalog.lookup(localeTag, 'card.saved')}\n'
            : human;
        if (path != null) {
          await writeOutputFile(path, utf8.encode(human));
        }
        await writeSinkAndFlush(out, payload);
        return 0;
      } on OutOfMemoryError {
        fail('resource', 'card.resource-limit', 'error.card.resource');
        return 75;
      } on Object {
        fail('access', 'card.output-access', 'error.card.outputAccess');
        return 74;
      }
    },
    onFailure: (failure) async {
      fail(
        failure.kind.name,
        failure.code,
        failure.messageKey,
        failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runIdentityDocument(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required IdentityDocumentService service,
  required JsonObjectEncoder encodeJson,
  required FileBytesWriter writeOutputFile,
}) async {
  final json = parsed.flag('json');
  final path = parsed.option('output');
  void fail(
    String kind,
    String code,
    String messageKey, [
    Map<String, Object?> details = const {},
  ]) => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: kind,
    code: code,
    messageKey: messageKey,
    details: details,
  );
  if (parsed.rest.isNotEmpty || path == '') {
    fail('validation', 'document.invalid-options', 'error.document.validation');
    return 64;
  }
  final result = await service.execute(
    IdentityDocumentOperationRequest(
      locale: parsed.option('locale')!,
      type: parsed.option('type')!,
      cnpjFormat: parsed.option('cnpj-format'),
      count: parsed.option('count')!,
    ),
  );
  return await result.fold(
    onSuccess: (value) async {
      try {
        final human = [
          catalog.lookup(localeTag, 'document.syntheticLabel'),
          ...value.values,
        ].join('\n');
        final payload = json
            ? '${encodeJson(value.toJson())}\n'
            : path != null
            ? '${catalog.lookup(localeTag, 'document.saved')}\n'
            : human;
        if (path != null) {
          await writeOutputFile(path, utf8.encode(human));
        }
        await writeSinkAndFlush(out, payload);
        return 0;
      } on OutOfMemoryError {
        fail('resource', 'document.resource-limit', 'error.document.resource');
        return 75;
      } on Object {
        fail('access', 'document.output-access', 'error.document.outputAccess');
        return 74;
      }
    },
    onFailure: (failure) async {
      fail(
        failure.kind.name,
        failure.code,
        failure.messageKey,
        failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runPerson(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required PersonService service,
  required JsonObjectEncoder encodeJson,
  required FileBytesWriter writeOutputFile,
}) async {
  final json = parsed.flag('json');
  final path = parsed.option('output');
  void fail(
    String kind,
    String code,
    String messageKey, [
    Map<String, Object?> details = const {},
  ]) => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: kind,
    code: code,
    messageKey: messageKey,
    details: details,
  );
  if (parsed.rest.isNotEmpty || path == '') {
    fail('validation', 'person.invalid-options', 'error.person.validation');
    return 64;
  }
  final result = await service.execute(
    PersonOperationRequest(
      locale: parsed.option('locale')!,
      minAge: parsed.option('min-age')!,
      maxAge: parsed.option('max-age')!,
      count: parsed.option('count')!,
    ),
  );
  return await result.fold(
    onSuccess: (value) async {
      try {
        final human = _personHuman(value, catalog, localeTag);
        final payload = json
            ? '${encodeJson(value.toJson())}\n'
            : path != null
            ? '${catalog.lookup(localeTag, 'person.saved')}\n'
            : human;
        if (path != null) {
          await writeOutputFile(path, utf8.encode(human));
        }
        await writeSinkAndFlush(out, payload);
        return 0;
      } on OutOfMemoryError {
        fail('resource', 'person.resource-limit', 'error.person.resource');
        return 75;
      } on Object {
        fail('access', 'person.output-access', 'error.person.outputAccess');
        return 74;
      }
    },
    onFailure: (failure) async {
      fail(
        failure.kind.name,
        failure.code,
        failure.messageKey,
        failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

String _personHuman(
  PersonOutput output,
  MessageCatalog catalog,
  String localeTag,
) {
  String label(String key) => catalog.lookup(localeTag, 'person.$key');
  final lines = <String>[label('syntheticLabel')];
  for (var index = 0; index < output.people.length; index++) {
    final person = output.people[index];
    lines
      ..add('')
      ..add('${label('entryLabel')} ${index + 1}')
      ..add('${label('nameLabel')}: ${person.givenName} ${person.familyName}')
      ..add('${label('birthDateLabel')}: ${_personDate(person.birthDate)}')
      ..add(
        '${label('addressLabel')}: ${person.address.street}, '
        '${person.address.city}, ${person.address.region} '
        '${person.address.postalCode}, ${person.address.countryCode}',
      )
      ..add('${label('phoneLabel')}: ${person.phone}')
      ..add('${label('emailLabel')}: ${person.email}')
      ..add('${label('identifiersLabel')}:');
    for (final identifier in person.identifiers) {
      lines.add('  ${identifier.type.name.toUpperCase()}: ${identifier.value}');
    }
  }
  return lines.join('\n');
}

String _personDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

Future<int> _runUuid(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required UuidService service,
  required JsonObjectEncoder encodeJson,
  required FileBytesWriter writeOutputFile,
}) async {
  final json = parsed.flag('json');
  final path = parsed.option('output');
  void fail(
    String kind,
    String code,
    String messageKey, [
    Map<String, Object?> details = const {},
  ]) => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: kind,
    code: code,
    messageKey: messageKey,
    details: details,
  );
  if (parsed.rest.isNotEmpty || path == '') {
    fail('validation', 'uuid.invalid-options', 'error.uuid.validation');
    return 64;
  }
  final result = await service.execute(
    UuidOperationRequest(
      version: parsed.option('version')!,
      representation: parsed.option('representation')!,
      count: parsed.option('count')!,
    ),
  );
  return await result.fold(
    onSuccess: (value) async {
      try {
        final identifiers = value.values.join('\n');
        final payload = json
            ? '${encodeJson(value.toJson())}\n'
            : path != null
            ? '${catalog.lookup(localeTag, 'uuid.saved')}\n'
            : identifiers;
        if (path != null) {
          await writeOutputFile(path, utf8.encode(identifiers));
        }
        await writeSinkAndFlush(out, payload);
        return 0;
      } on OutOfMemoryError {
        fail('resource', 'uuid.resource-limit', 'error.uuid.resource');
        return 75;
      } on Object {
        fail('access', 'uuid.output-access', 'error.uuid.outputAccess');
        return 74;
      }
    },
    onFailure: (failure) async {
      fail(
        failure.kind.name,
        failure.code,
        failure.messageKey,
        failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runPassword(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required PasswordService service,
  required JsonObjectEncoder encodeJson,
  required FileBytesWriter writeOutputFile,
}) async {
  final json = parsed.flag('json');
  final path = parsed.option('output');
  void fail(
    String kind,
    String code,
    String messageKey, [
    Map<String, Object?> details = const {},
  ]) => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: kind,
    code: code,
    messageKey: messageKey,
    details: details,
  );
  if (parsed.rest.isNotEmpty || path == '') {
    fail('validation', 'password.invalid-options', 'error.password.validation');
    return 64;
  }
  final result = await service.execute(
    PasswordOperationRequest(
      length: parsed.option('length')!,
      lowercase: parsed.flag('lowercase'),
      uppercase: parsed.flag('uppercase'),
      digits: parsed.flag('digits'),
      symbols: parsed.flag('symbols'),
    ),
  );
  return await result.fold(
    onSuccess: (value) async {
      try {
        final payload = json
            ? '${encodeJson(value.toJson())}\n'
            : path != null
            ? '${catalog.lookup(localeTag, 'password.saved')}\n'
            : value.password;
        if (path != null) {
          await writeOutputFile(path, utf8.encode(value.password));
        }
        await writeSinkAndFlush(out, payload);
        return 0;
      } on OutOfMemoryError {
        fail('resource', 'password.resource-limit', 'error.password.resource');
        return 75;
      } on Object {
        fail('access', 'password.output-access', 'error.password.outputAccess');
        return 74;
      }
    },
    onFailure: (failure) async {
      fail(
        failure.kind.name,
        failure.code,
        failure.messageKey,
        failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runLorem(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required LoremService service,
  required JsonObjectEncoder encodeJson,
  required FileBytesWriter writeOutputFile,
}) async {
  final json = parsed.flag('json');
  final path = parsed.option('output');
  void fail(
    String kind,
    String code,
    String messageKey, [
    Map<String, Object?> details = const {},
  ]) => _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: json,
    kind: kind,
    code: code,
    messageKey: messageKey,
    details: details,
  );
  if (parsed.rest.isNotEmpty || path == '') {
    fail('validation', 'lorem.invalid-options', 'error.lorem.validation');
    return 64;
  }
  final result = await service.execute(
    LoremOperationRequest(
      unit: parsed.option('unit')!,
      count: parsed.option('count')!,
    ),
  );
  return await result.fold(
    onSuccess: (value) async {
      try {
        final payload = json
            ? '${encodeJson(value.toJson())}\n'
            : path != null
            ? '${catalog.lookup(localeTag, 'lorem.saved')}\n'
            : value.text;
        if (path != null) await writeOutputFile(path, utf8.encode(value.text));
        await writeSinkAndFlush(out, payload);
        return 0;
      } on OutOfMemoryError {
        fail('resource', 'lorem.resource-limit', 'error.lorem.resource');
        return 75;
      } on Object {
        fail('access', 'lorem.output-access', 'error.lorem.outputAccess');
        return 74;
      }
    },
    onFailure: (failure) async {
      fail(
        failure.kind.name,
        failure.code,
        failure.messageKey,
        failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}
