import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'validate_release_metadata.dart';

final class ReleaseArtifactDescriptor {
  const ReleaseArtifactDescriptor({
    required this.fileName,
    required this.platform,
    required this.application,
    required this.packageType,
  });

  final String fileName;
  final String platform;
  final String application;
  final String packageType;
}

final class ReleaseBundleIssue {
  const ReleaseBundleIssue({
    required this.code,
    required this.path,
    required this.message,
  });

  final String code;
  final String path;
  final String message;

  @override
  String toString() => '$code: $path: $message';
}

List<String> expectedReleaseArtifactNames(String version) =>
    releaseArtifactDescriptors(version)
        .map((descriptor) => descriptor.fileName)
        .toList(growable: false);

List<ReleaseArtifactDescriptor> releaseArtifactDescriptors(String version) {
  final descriptors = <ReleaseArtifactDescriptor>[];
  for (final target in <({String platform, String extension})>[
    (platform: 'windows', extension: 'zip'),
    (platform: 'linux', extension: 'tar.gz'),
  ]) {
    for (final application in <({String fileToken, String metadata})>[
      (fileToken: 'gui', metadata: 'desktop'),
      (fileToken: 'cli', metadata: 'cli'),
    ]) {
      descriptors.add(
        ReleaseArtifactDescriptor(
          fileName:
              'chimera-${application.fileToken}-${target.platform}-x64-'
              '$version-portable.${target.extension}',
          platform: target.platform,
          application: application.metadata,
          packageType: 'portable',
        ),
      );
      descriptors.add(
        ReleaseArtifactDescriptor(
          fileName:
              'chimera-${application.fileToken}-${target.platform}-x64-'
              '$version-installer.${target.platform == 'windows' ? 'exe' : 'deb'}',
          platform: target.platform,
          application: application.metadata,
          packageType: 'installer',
        ),
      );
    }
  }
  return List<ReleaseArtifactDescriptor>.unmodifiable(descriptors);
}

Future<List<ReleaseBundleIssue>> validateReleaseBundle({
  required Directory directory,
  required String version,
  required String repository,
}) async {
  final issues = <ReleaseBundleIssue>[];
  if (!RegExp(r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$')
      .hasMatch(version)) {
    return <ReleaseBundleIssue>[
      ReleaseBundleIssue(
        code: 'invalid-version',
        path: 'version',
        message: "'$version' must be canonical X.Y.Z",
      ),
    ];
  }
  if (!RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$').hasMatch(repository)) {
    return <ReleaseBundleIssue>[
      ReleaseBundleIssue(
        code: 'invalid-repository',
        path: 'repository',
        message: "'$repository' must be owner/name",
      ),
    ];
  }
  if (!directory.existsSync()) {
    return <ReleaseBundleIssue>[
      ReleaseBundleIssue(
        code: 'missing-directory',
        path: directory.path,
        message: 'release bundle directory does not exist',
      ),
    ];
  }

  final descriptors = releaseArtifactDescriptors(version);
  final expected = <String>{
    for (final descriptor in descriptors) ...<String>[
      descriptor.fileName,
      '${descriptor.fileName}.sha256',
      '${descriptor.fileName}.release.json',
    ],
  };
  final entities = directory.listSync(followLinks: false);
  final actual = <String>{};
  for (final entity in entities) {
    final name = entity.path.split(Platform.pathSeparator).last;
    actual.add(name);
    if (entity is! File || !expected.contains(name)) {
      issues.add(
        ReleaseBundleIssue(
          code: 'unexpected-file',
          path: name,
          message: 'not part of the native release bundle',
        ),
      );
    }
  }
  for (final name in expected.difference(actual)) {
    issues.add(
      ReleaseBundleIssue(
        code: 'missing-file',
        path: name,
        message: 'required native release file is missing',
      ),
    );
  }

  for (final descriptor in descriptors) {
    final artifact = File(
      '${directory.path}${Platform.pathSeparator}${descriptor.fileName}',
    );
    final checksumFile = File('${artifact.path}.sha256');
    final metadataFile = File('${artifact.path}.release.json');
    if (!artifact.existsSync() ||
        !checksumFile.existsSync() ||
        !metadataFile.existsSync()) {
      continue;
    }
    final digest = (await sha256.bind(artifact.openRead()).first).toString();
    final expectedChecksum = '$digest  ${descriptor.fileName}\n';
    if (checksumFile.readAsStringSync() != expectedChecksum) {
      issues.add(
        ReleaseBundleIssue(
          code: 'checksum-mismatch',
          path: '${descriptor.fileName}.sha256',
          message: 'checksum sidecar does not match artifact bytes and name',
        ),
      );
    }
    _validateMetadata(
      descriptor: descriptor,
      metadataFile: metadataFile,
      version: version,
      repository: repository,
      digest: digest,
      issues: issues,
    );
  }

  issues.sort((left, right) {
    final path = left.path.compareTo(right.path);
    return path == 0 ? left.code.compareTo(right.code) : path;
  });
  return List<ReleaseBundleIssue>.unmodifiable(issues);
}

void _validateMetadata({
  required ReleaseArtifactDescriptor descriptor,
  required File metadataFile,
  required String version,
  required String repository,
  required String digest,
  required List<ReleaseBundleIssue> issues,
}) {
  Map<String, Object?> value;
  try {
    final decoded = jsonDecode(metadataFile.readAsStringSync());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('metadata must be an object');
    }
    value = decoded;
  } on FormatException catch (error) {
    issues.add(
      ReleaseBundleIssue(
        code: 'invalid-metadata',
        path: '${descriptor.fileName}.release.json',
        message: error.message,
      ),
    );
    return;
  }

  const expectedFields = <String>{
    'releaseVersion',
    'platform',
    'application',
    'packageType',
    'downloadUrl',
    'checksum',
  };
  if (!value.keys.toSet().containsAll(expectedFields) ||
      value.length != expectedFields.length) {
    issues.add(
      ReleaseBundleIssue(
        code: 'metadata-fields',
        path: '${descriptor.fileName}.release.json',
        message: 'metadata must contain exactly the six documented fields',
      ),
    );
  }

  final validation = ReleaseMetadataValidator.validate(value);
  if (!validation.isValid) {
    issues.add(
      ReleaseBundleIssue(
        code: 'invalid-metadata',
        path: '${descriptor.fileName}.release.json',
        message: 'invalid fields: ${validation.errors.join(', ')}',
      ),
    );
    return;
  }
  final metadata = validation.metadata!;
  _expectMetadata(
    actual: metadata.releaseVersion,
    expected: version,
    code: 'metadata-version',
    field: 'releaseVersion',
    descriptor: descriptor,
    issues: issues,
  );
  _expectMetadata(
    actual: metadata.platform.name,
    expected: descriptor.platform,
    code: 'metadata-platform',
    field: 'platform',
    descriptor: descriptor,
    issues: issues,
  );
  _expectMetadata(
    actual: metadata.application.name,
    expected: descriptor.application,
    code: 'metadata-application',
    field: 'application',
    descriptor: descriptor,
    issues: issues,
  );
  _expectMetadata(
    actual: metadata.packageType.name,
    expected: descriptor.packageType,
    code: 'metadata-package-type',
    field: 'packageType',
    descriptor: descriptor,
    issues: issues,
  );
  _expectMetadata(
    actual: metadata.downloadUrl.toString(),
    expected:
        'https://github.com/$repository/releases/download/v$version/'
        '${descriptor.fileName}',
    code: 'metadata-url',
    field: 'downloadUrl',
    descriptor: descriptor,
    issues: issues,
  );
  _expectMetadata(
    actual: metadata.checksum,
    expected: digest,
    code: 'metadata-checksum',
    field: 'checksum',
    descriptor: descriptor,
    issues: issues,
  );
}

void _expectMetadata({
  required String actual,
  required String expected,
  required String code,
  required String field,
  required ReleaseArtifactDescriptor descriptor,
  required List<ReleaseBundleIssue> issues,
}) {
  if (actual == expected) {
    return;
  }
  issues.add(
    ReleaseBundleIssue(
      code: code,
      path: '${descriptor.fileName}.release.json',
      message: "$field '$actual' does not match '$expected'",
    ),
  );
}

Future<void> main(List<String> arguments) async {
  final directoryPath = arguments.isEmpty ? null : arguments.first;
  final version = _valueAfter(arguments, '--version');
  final repository = _valueAfter(arguments, '--repository');
  if (directoryPath == null ||
      directoryPath.startsWith('--') ||
      version == null ||
      repository == null ||
      _hasUnknownArguments(arguments.skip(1).toList(growable: false))) {
    stderr.writeln(
      'Usage: dart run tool/validate_release_bundle.dart <directory> '
      '--version <X.Y.Z> --repository <owner/name>',
    );
    exitCode = 64;
    return;
  }

  final issues = await validateReleaseBundle(
    directory: Directory(directoryPath),
    version: version,
    repository: repository,
  );
  if (issues.isNotEmpty) {
    for (final issue in issues) {
      stderr.writeln(issue);
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('Release $version native bundle: OK');
}

String? _valueAfter(List<String> arguments, String option) {
  final index = arguments.indexOf(option);
  if (index < 0 || index + 1 >= arguments.length) {
    return null;
  }
  return arguments[index + 1];
}

bool _hasUnknownArguments(List<String> arguments) {
  for (var index = 0; index < arguments.length; index += 2) {
    if (index + 1 >= arguments.length ||
        (arguments[index] != '--version' &&
            arguments[index] != '--repository')) {
      return true;
    }
  }
  return false;
}
