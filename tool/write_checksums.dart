import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

final class ReleaseSidecar {
  const ReleaseSidecar({
    required this.artifact,
    required this.checksum,
    required this.metadata,
  });

  final File artifact;
  final File checksum;
  final File metadata;
}

Future<List<ReleaseSidecar>> writeReleaseSidecars({
  required Directory directory,
  required String version,
  required String repository,
}) async {
  _validateVersion(version);
  _validateRepository(repository);

  final artifacts =
      directory
          .listSync()
          .whereType<File>()
          .where((file) => _classify(file, version) != null)
          .toList()
        ..sort((left, right) => left.path.compareTo(right.path));
  final outputs = <ReleaseSidecar>[];

  for (final artifact in artifacts) {
    final classification = _classify(artifact, version)!;
    final digest = (await sha256.bind(artifact.openRead()).first).toString();
    final fileName = artifact.uri.pathSegments.last;
    final checksum = File('${artifact.path}.sha256')
      ..writeAsStringSync('$digest  $fileName\n');
    final metadata = File('${artifact.path}.release.json')
      ..writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{'releaseVersion': version, 'platform': classification.platform, 'application': classification.application, 'packageType': classification.packageType, 'downloadUrl': 'https://github.com/$repository/releases/download/v$version/$fileName', 'checksum': digest})}\n',
      );
    outputs.add(
      ReleaseSidecar(
        artifact: artifact,
        checksum: checksum,
        metadata: metadata,
      ),
    );
  }

  return outputs;
}

({String platform, String application, String packageType})? _classify(
  File file,
  String version,
) {
  final name = file.uri.pathSegments.last;
  if (!name.startsWith('chimera-') || !name.contains('-$version-')) {
    return null;
  }

  final supportedExtension = <String>[
    '.zip',
    '.exe',
    '.tar.gz',
    '.deb',
  ].any(name.endsWith);
  if (!supportedExtension) {
    return null;
  }

  final platform = name.contains('-windows-')
      ? 'windows'
      : name.contains('-linux-')
      ? 'linux'
      : null;
  final application = name.contains('-gui-')
      ? 'desktop'
      : name.contains('-cli-')
      ? 'cli'
      : null;
  final packageType = name.contains('-portable.')
      ? 'portable'
      : name.contains('-installer.')
      ? 'installer'
      : null;
  if (platform == null || application == null || packageType == null) {
    return null;
  }

  return (
    platform: platform,
    application: application,
    packageType: packageType,
  );
}

void _validateVersion(String version) {
  if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) {
    throw ArgumentError.value(version, 'version', 'must be major.minor.patch');
  }
}

void _validateRepository(String repository) {
  if (!RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$').hasMatch(repository)) {
    throw ArgumentError.value(repository, 'repository', 'must be owner/name');
  }
}

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    _printUsage();
    exitCode = 64;
    return;
  }

  String? valueAfter(String option) {
    final index = arguments.indexOf(option);
    return index >= 0 && index + 1 < arguments.length
        ? arguments[index + 1]
        : null;
  }

  final directory = Directory(arguments.first);
  final version = valueAfter('--version');
  final repository = valueAfter('--repository');
  if (!directory.existsSync() || version == null || repository == null) {
    _printUsage();
    exitCode = 64;
    return;
  }

  try {
    final outputs = await writeReleaseSidecars(
      directory: directory,
      version: version,
      repository: repository,
    );
    for (final output in outputs) {
      stdout.writeln(output.checksum.path);
      stdout.writeln(output.metadata.path);
    }
  } on ArgumentError catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  }
}

void _printUsage() {
  stderr.writeln(
    'Usage: dart run tool/write_checksums.dart <directory> '
    '--version <major.minor.patch> --repository <owner/name>',
  );
}
