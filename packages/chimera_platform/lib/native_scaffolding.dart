import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:chimera_core/chimera_core.dart';
import 'package:path/path.dart' as p;

import 'src/exclusive_directory.dart';

typedef ScaffoldFileWriter = Future<void> Function(File file, List<int> bytes);

final class NativeScaffoldWriter implements ScaffoldWriter {
  const NativeScaffoldWriter({this.writeFile});
  final ScaffoldFileWriter? writeFile;

  @override
  Future<ChimeraResult<ScaffoldOutput>> write(
    ScaffoldRequest request,
    TemplateBundle template,
  ) async {
    final files = template.files;
    final version = template.version;
    final destination = p.normalize(p.absolute(request.destination));
    final parent = Directory(p.dirname(destination));
    if (!await parent.exists() ||
        await FileSystemEntity.type(destination, followLinks: false) !=
            FileSystemEntityType.notFound) {
      return const ChimeraFailure(
        kind: FailureKind.access,
        code: 'scaffold-destination-conflict',
        messageKey: 'error.scaffold.access',
      );
    }
    var reserved = false;
    final created = <String>[];
    final ownedDirectories = <String>[];
    final marker = File(p.join(destination, '.chimera-scaffold-owner'));
    final random = Random.secure();
    final token = List.generate(32, (_) => random.nextInt(256)).join('-');
    try {
      createDirectoryExclusively(destination);
      reserved = true;
      await marker.create(exclusive: true);
      await marker.writeAsString(token, flush: true);
      for (final entry in files.entries) {
        final file = File(p.joinAll([destination, ...entry.key.split('/')]));
        final parents = <Directory>[];
        var directory = file.parent;
        while (directory.path != destination && !await directory.exists()) {
          parents.add(directory);
          directory = directory.parent;
        }
        for (final dir in parents.reversed) {
          if (!await _ownedParent(dir.path, destination, marker, token)) {
            throw const FileSystemException('Scaffold destination changed');
          }
          createDirectoryExclusively(dir.path);
          ownedDirectories.add(dir.path);
        }
        if (!await _ownedParent(file.path, destination, marker, token)) {
          throw const FileSystemException('Scaffold destination changed');
        }
        await file.create(exclusive: true);
        created.add(file.path);
        final bytes = utf8.encode(entry.value);
        await (writeFile ?? _write)(file, bytes);
        if (await file.readAsString() != entry.value) {
          throw const FileSystemException('Scaffold verification failed');
        }
      }
      await marker.delete();
      return ChimeraSuccess(
        ScaffoldOutput(
          destination: destination,
          templateVersion: version,
          createdPaths: List.unmodifiable(created),
        ),
      );
    } on Object {
      if (reserved) {
        try {
          if (await FileSystemEntity.type(destination, followLinks: false) ==
                  FileSystemEntityType.directory &&
              await FileSystemEntity.type(marker.path, followLinks: false) ==
                  FileSystemEntityType.file &&
              await marker.readAsString() == token) {
            for (final path in created.reversed) {
              if (await _ownedParent(path, destination, marker, token) &&
                  await FileSystemEntity.type(path, followLinks: false) ==
                      FileSystemEntityType.file) {
                await File(path).delete();
              }
            }
            for (final path in ownedDirectories.reversed) {
              try {
                if (await _ownedParent(path, destination, marker, token) &&
                    await FileSystemEntity.type(path, followLinks: false) ==
                        FileSystemEntityType.directory) {
                  await Directory(path).delete();
                }
              } on FileSystemException {
                /* Preserve any newly added content. */
              }
            }
            await marker.delete();
            await Directory(destination).delete();
          }
        } on FileSystemException {
          /* Retain evidence if rollback is unsafe or inaccessible. */
        }
      }
      return ChimeraFailure(
        kind: reserved ? FailureKind.processing : FailureKind.access,
        code: reserved
            ? 'scaffold-write-failed'
            : 'scaffold-destination-conflict',
        messageKey: reserved
            ? 'error.scaffold.failed'
            : 'error.scaffold.access',
        details: {
          if (await FileSystemEntity.type(destination, followLinks: false) !=
              FileSystemEntityType.notFound)
            'retainedPath': destination,
        },
      );
    }
  }
}

Future<void> _write(File file, List<int> bytes) async {
  await file.writeAsBytes(bytes, flush: true);
}

Future<bool> _ownedParent(
  String path,
  String destination,
  File marker,
  String token,
) async {
  if (!p.isWithin(destination, path) ||
      await FileSystemEntity.type(destination, followLinks: false) !=
          FileSystemEntityType.directory ||
      await FileSystemEntity.type(marker.path, followLinks: false) !=
          FileSystemEntityType.file ||
      await marker.readAsString() != token) {
    return false;
  }
  var parent = p.dirname(path);
  while (parent != destination) {
    if (!p.isWithin(destination, parent) ||
        await FileSystemEntity.type(parent, followLinks: false) !=
            FileSystemEntityType.directory) {
      return false;
    }
    parent = p.dirname(parent);
  }
  return true;
}
