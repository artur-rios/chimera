import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:path/path.dart' as p;

final class DotnetBumpFileOperations {
  const DotnetBumpFileOperations({
    this.writeStage,
    this.renameStage,
    this.restoreBackup,
    this.deleteBackup,
  });
  final Future<void> Function(String path, List<int> bytes)? writeStage;
  final Future<void> Function(String stage, String target)? renameStage;
  final Future<void> Function(String target, String backup)? restoreBackup;
  final Future<void> Function(String backup)? deleteBackup;
}

/// Local source discovery and backup-preserving transactional replacement.
final class NativeDotnetBumpGateway implements DotnetBumpGateway {
  NativeDotnetBumpGateway({
    String? workingDirectory,
    this.operations = const DotnetBumpFileOperations(),
  }) : workingDirectory = workingDirectory ?? Directory.current.path;
  final String workingDirectory;
  final DotnetBumpFileOperations operations;
  static int _sequence = 0;

  bool _equal(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  void _safePath(String path, {bool mayBeMissing = false}) {
    final parent = Directory(p.dirname(path));
    if (!parent.existsSync() ||
        !p.equals(parent.resolveSymbolicLinksSync(), parent.path)) {
      throw const DotnetBumpBoundaryException('access');
    }
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (mayBeMissing && type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.file ||
        !p.equals(File(path).resolveSymbolicLinksSync(), path)) {
      throw const DotnetBumpBoundaryException('access');
    }
  }

  @override
  Future<String> resolveProject(String? selection) async {
    final raw = selection ?? p.join(workingDirectory, 'src');
    if (raw.trim().isEmpty || raw.contains('\u0000')) {
      throw const DotnetBumpBoundaryException(
        'discovery',
        details: {'candidates': <String>[]},
      );
    }
    final selected = p.normalize(
      p.isAbsolute(raw) ? raw : p.join(workingDirectory, raw),
    );
    final type = FileSystemEntity.typeSync(selected, followLinks: false);
    if (type == FileSystemEntityType.file &&
        p.extension(selected).toLowerCase() == '.csproj') {
      _safePath(selected);
      return File(selected).resolveSymbolicLinksSync();
    }
    if (type != FileSystemEntityType.directory ||
        !p.equals(Directory(selected).resolveSymbolicLinksSync(), selected)) {
      throw const DotnetBumpBoundaryException(
        'discovery',
        details: {'candidates': <String>[]},
      );
    }
    final candidates =
        Directory(selected)
            .listSync(followLinks: false)
            .where(
              (entry) =>
                  p.extension(entry.path).toLowerCase() == '.csproj' &&
                  FileSystemEntity.typeSync(entry.path, followLinks: false) ==
                      FileSystemEntityType.file,
            )
            .map((entry) => entry.path)
            .toList()
          ..sort();
    if (candidates.length != 1) {
      throw DotnetBumpBoundaryException(
        'discovery',
        details: {'candidates': candidates},
      );
    }
    _safePath(candidates.single);
    return File(candidates.single).resolveSymbolicLinksSync();
  }

  @override
  Future<List<int>> read(String path) async {
    _safePath(path);
    return File(path).readAsBytes();
  }

  Future<File> _reserve(String target, String role) async {
    while (true) {
      final file = File(
        p.join(p.dirname(target), '.chimera-bump-$role-$pid-${_sequence++}'),
      );
      try {
        await file.create(exclusive: true);
        return file;
      } on FileSystemException {
        if (FileSystemEntity.typeSync(file.path, followLinks: false) ==
            FileSystemEntityType.notFound) {
          rethrow;
        }
      }
    }
  }

  @override
  Future<String> createBackup(String path, List<int> original) async {
    _safePath(path);
    if (!_equal(await File(path).readAsBytes(), original)) {
      throw const DotnetBumpBoundaryException('conflict');
    }
    final backup = await _reserve(path, 'backup');
    try {
      await backup.writeAsBytes(original, flush: true);
      if (!_equal(await backup.readAsBytes(), original)) {
        throw const FileSystemException('Backup verification failed');
      }
      return backup.path;
    } on Object {
      // The project has not been modified. A failed backup is never considered
      // recoverable, but its location is reported if cleanup is also denied.
      String? retained;
      try {
        await backup.delete();
      } on Object {
        retained = backup.path;
      }
      throw DotnetBumpBoundaryException(
        'access',
        details: {'backupPath': ?retained, 'recoverable': false},
      );
    }
  }

  Future<void> _replaceBytes(
    String target,
    List<int> bytes, {
    List<int>? expectedOriginal,
    bool inject = false,
  }) async {
    final stage = await _reserve(target, 'stage');
    try {
      if (inject && operations.writeStage != null) {
        await operations.writeStage!(stage.path, bytes);
      } else {
        await stage.writeAsBytes(bytes, flush: true);
      }
      _safePath(stage.path);
      if (!_equal(await stage.readAsBytes(), bytes)) {
        throw const FileSystemException('Stage verification failed');
      }
      _safePath(target, mayBeMissing: expectedOriginal == null);
      if (expectedOriginal != null &&
          !_equal(await File(target).readAsBytes(), expectedOriginal)) {
        throw const DotnetBumpBoundaryException('conflict');
      }
      if (inject && operations.renameStage != null) {
        await operations.renameStage!(stage.path, target);
      } else {
        await stage.rename(target);
      }
    } finally {
      if (await stage.exists()) await stage.delete();
    }
  }

  @override
  Future<void> replace(
    String path,
    List<int> expectedOriginal,
    List<int> updated,
  ) => _replaceBytes(
    path,
    updated,
    expectedOriginal: expectedOriginal,
    inject: true,
  );

  @override
  Future<void> restore(
    String path,
    String backupPath,
    List<int> original,
  ) async {
    _safePath(backupPath);
    final backup = await File(backupPath).readAsBytes();
    if (!_equal(backup, original)) {
      throw const FileSystemException('Backup verification failed');
    }
    if (operations.restoreBackup != null) {
      await operations.restoreBackup!(path, backupPath);
    } else {
      await _replaceBytes(path, backup);
    }
    _safePath(path);
    if (!_equal(await File(path).readAsBytes(), original)) {
      throw const FileSystemException('Restore verification failed');
    }
    // Failure backups are deliberately retained even after successful rollback.
  }

  @override
  Future<void> removeBackup(String path) async {
    _safePath(path);
    if (operations.deleteBackup != null) {
      await operations.deleteBackup!(path);
    } else {
      await File(path).delete();
    }
  }
}
