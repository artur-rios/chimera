import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

final class ReleaseUploadIssue {
  const ReleaseUploadIssue({
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

Future<List<ReleaseUploadIssue>> validateReleaseUpload({
  required Directory directory,
  required List<Object?> assets,
}) async {
  final issues = <ReleaseUploadIssue>[];
  if (!directory.existsSync()) {
    return <ReleaseUploadIssue>[
      ReleaseUploadIssue(
        code: 'missing-directory',
        path: directory.path,
        message: 'validated release bundle directory does not exist',
      ),
    ];
  }

  final localFiles = <String, File>{};
  for (final entity in directory.listSync(followLinks: false)) {
    final name = entity.path.split(Platform.pathSeparator).last;
    if (entity is! File) {
      issues.add(
        ReleaseUploadIssue(
          code: 'invalid-local-entry',
          path: name,
          message: 'release bundle entries must be regular files',
        ),
      );
      continue;
    }
    localFiles[name] = entity;
  }

  final remoteAssets = <String, Map<String, Object?>>{};
  for (var index = 0; index < assets.length; index++) {
    final candidate = assets[index];
    if (candidate is! Map<String, Object?> ||
        candidate['name'] is! String ||
        (candidate['name']! as String).isEmpty) {
      issues.add(
        ReleaseUploadIssue(
          code: 'invalid-remote-asset',
          path: 'assets[$index]',
          message: 'remote asset must be an object with a non-empty name',
        ),
      );
      continue;
    }
    final name = candidate['name']! as String;
    if (remoteAssets.containsKey(name)) {
      issues.add(
        ReleaseUploadIssue(
          code: 'duplicate-remote-asset',
          path: name,
          message: 'remote release contains the asset more than once',
        ),
      );
      continue;
    }
    remoteAssets[name] = candidate;
  }

  for (final name in localFiles.keys.toSet().difference(
    remoteAssets.keys.toSet(),
  )) {
    issues.add(
      ReleaseUploadIssue(
        code: 'missing-remote-asset',
        path: name,
        message: 'validated local file was not uploaded',
      ),
    );
  }
  for (final name in remoteAssets.keys.toSet().difference(
    localFiles.keys.toSet(),
  )) {
    issues.add(
      ReleaseUploadIssue(
        code: 'unexpected-remote-asset',
        path: name,
        message: 'remote release contains a file outside the validated bundle',
      ),
    );
  }

  for (final entry in localFiles.entries) {
    final remote = remoteAssets[entry.key];
    if (remote == null) {
      continue;
    }
    if (remote['state'] != 'uploaded') {
      issues.add(
        ReleaseUploadIssue(
          code: 'remote-state',
          path: entry.key,
          message: "asset state '${remote['state']}' is not uploaded",
        ),
      );
    }
    final length = entry.value.lengthSync();
    if (remote['size'] != length) {
      issues.add(
        ReleaseUploadIssue(
          code: 'remote-size',
          path: entry.key,
          message: "remote size '${remote['size']}' does not match $length",
        ),
      );
    }
    final digest = (await sha256.bind(entry.value.openRead()).first).toString();
    if (remote['digest'] != 'sha256:$digest') {
      issues.add(
        ReleaseUploadIssue(
          code: 'remote-digest',
          path: entry.key,
          message: 'remote SHA-256 digest does not match local bytes',
        ),
      );
    }
  }

  issues.sort((left, right) {
    final path = left.path.compareTo(right.path);
    return path == 0 ? left.code.compareTo(right.code) : path;
  });
  return List<ReleaseUploadIssue>.unmodifiable(issues);
}

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/validate_release_upload.dart '
      '<bundle-directory> <release-assets.json>',
    );
    exitCode = 64;
    return;
  }

  List<Object?> assets;
  try {
    final decoded = jsonDecode(File(arguments[1]).readAsStringSync());
    if (decoded is! List<Object?>) {
      throw const FormatException('release assets must be a JSON array');
    }
    assets = decoded;
  } on FileSystemException catch (error) {
    stderr.writeln('release-assets: ${error.message}');
    exitCode = 1;
    return;
  } on FormatException catch (error) {
    stderr.writeln('release-assets: ${error.message}');
    exitCode = 1;
    return;
  }

  final issues = await validateReleaseUpload(
    directory: Directory(arguments[0]),
    assets: assets,
  );
  if (issues.isNotEmpty) {
    for (final issue in issues) {
      stderr.writeln(issue);
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('Remote release assets match the validated bundle: OK');
}
