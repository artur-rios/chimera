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

  void _safePath(String path) {
    final parent = Directory(p.dirname(path));
    if (!parent.existsSync() ||
        !p.equals(parent.resolveSymbolicLinksSync(), parent.path)) {
      throw const DotnetBumpBoundaryException('access');
    }
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type != FileSystemEntityType.file ||
        !p.equals(File(path).resolveSymbolicLinksSync(), path)) {
      throw const DotnetBumpBoundaryException('access');
    }
  }

  /// Adopt the canonical spelling of one initial directory selection only after
  /// rejecting links/reparse escapes in every lexical ancestor. Recursive native
  /// consumers can share this initial boundary and retain strict later checks.
  String resolveDirectory(String selection) {
    if (selection.trim().isEmpty || selection.contains('\u0000')) {
      throw const DotnetBumpBoundaryException('discovery');
    }
    final selected = p.normalize(
      p.isAbsolute(selection) ? selection : p.join(workingDirectory, selection),
    );
    final ancestors = <String>[];
    var ancestor = selected;
    while (true) {
      if (FileSystemEntity.typeSync(ancestor, followLinks: false) !=
          FileSystemEntityType.directory) {
        throw const DotnetBumpBoundaryException('access');
      }
      ancestors.add(ancestor);
      final parent = p.dirname(ancestor);
      if (parent == ancestor) break;
      ancestor = parent;
    }
    // A short-name alias is the same object; a junction/link is not. Validate
    // parents before resolving descendants, even if a reparse point was reported
    // as a directory by a filesystem implementation.
    var resolved = selected;
    for (final ancestor in ancestors.reversed) {
      final canonical = Directory(ancestor).resolveSymbolicLinksSync();
      if (!FileSystemEntity.identicalSync(ancestor, canonical)) {
        throw const DotnetBumpBoundaryException('access');
      }
      resolved = canonical;
    }
    return resolved;
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
    if (type == FileSystemEntityType.file) {
      final directory = resolveDirectory(p.dirname(selected));
      final file = p.join(directory, p.basename(selected));
      if (FileSystemEntity.typeSync(file, followLinks: false) !=
          FileSystemEntityType.file) {
        throw const DotnetBumpBoundaryException('access');
      }
      final canonical = File(file).resolveSymbolicLinksSync();
      if (!FileSystemEntity.identicalSync(file, canonical)) {
        throw const DotnetBumpBoundaryException('access');
      }
      if (p.extension(canonical).toLowerCase() != '.csproj') {
        throw const DotnetBumpBoundaryException(
          'discovery',
          details: {'candidates': <String>[]},
        );
      }
      _safePath(canonical);
      return canonical;
    }
    if (type != FileSystemEntityType.directory) {
      throw const DotnetBumpBoundaryException(
        'discovery',
        details: {'candidates': <String>[]},
      );
    }
    final directory = resolveDirectory(selected);
    final candidates =
        Directory(directory)
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
    required List<int> expectedOriginal,
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
      _safePath(target);
      if (!_equal(await File(target).readAsBytes(), expectedOriginal)) {
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
    List<int> original, {
    required List<int> expectedCurrent,
  }) async {
    _safePath(backupPath);
    final backup = await File(backupPath).readAsBytes();
    if (!_equal(backup, original)) {
      throw const FileSystemException('Backup verification failed');
    }
    _safePath(path);
    final current = await File(path).readAsBytes();
    if (_equal(current, original)) return;
    if (!_equal(current, expectedCurrent)) {
      throw const DotnetBumpBoundaryException('conflict');
    }
    if (operations.restoreBackup != null) {
      await operations.restoreBackup!(path, backupPath);
    } else {
      // Check again after the restore stage has been written, immediately
      // before replacement, so a concurrent save during staging is preserved.
      await _replaceBytes(path, backup, expectedOriginal: expectedCurrent);
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
