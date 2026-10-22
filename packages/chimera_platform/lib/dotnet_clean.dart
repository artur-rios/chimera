import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:path/path.dart' as p;

/// Nonrecursive entry deletion seam for deterministic locked/access-denied tests.
typedef DotnetCleanDeleteEntry = Future<void> Function(
  String path,
  bool directory,
);

final class NativeDotnetCleanGateway implements DotnetCleanGateway {
  NativeDotnetCleanGateway({String? workingDirectory, this.deleteEntry})
    : workingDirectory = workingDirectory ?? Directory.current.path;
  final String workingDirectory;
  final DotnetCleanDeleteEntry? deleteEntry;
  final Map<String, String> _rootSnapshots = {};
  final Map<String, String> _artifactSnapshots = {};

  String _snapshot(String path) {
    final stat = FileStat.statSync(path);
    return '${stat.type}:${stat.mode}:${stat.size}:${stat.modified.microsecondsSinceEpoch}:${stat.changed.microsecondsSinceEpoch}';
  }

  Never _reject(String path) =>
      throw FileSystemException('Unsafe cleanup scope', path);

  @override
  Future<String> resolveRoot(String? root) async {
    final raw = root ?? p.join(workingDirectory, 'src');
    if (raw.trim().isEmpty ||
        raw.contains('\u0000') ||
        p.split(raw).contains('..')) {
      _reject(raw);
    }
    final path = p.normalize(
      p.isAbsolute(raw) ? raw : p.join(workingDirectory, raw),
    );
    // Windows temp paths may contain an 8.3 spelling such as RUNNER~1.
    // Validate each lexical component before accepting its canonical spelling.
    // Identity alone follows intermediate links, so both checks are required
    // for every ancestor, including ancestors above the selected root.
    final ancestors = <String>[];
    var ancestor = path;
    while (true) {
      if (FileSystemEntity.typeSync(ancestor, followLinks: false) !=
          FileSystemEntityType.directory) {
        _reject(ancestor);
      }
      ancestors.add(ancestor);
      final parent = p.dirname(ancestor);
      if (parent == ancestor) break;
      ancestor = parent;
    }
    // Inspect parent identities before resolving their descendants. Even a
    // directory reparse point not classified as a link cannot hide an escape.
    for (final ancestor in ancestors.reversed) {
      final canonical = Directory(ancestor).resolveSymbolicLinksSync();
      if (!FileSystemEntity.identicalSync(ancestor, canonical)) {
        _reject(ancestor);
      }
    }
    final resolved = Directory(path).resolveSymbolicLinksSync();
    _validate(resolved, resolved, directory: true);
    // Never permit an entire volume as the selected cleanup scope.
    if (p.dirname(resolved) == resolved) _reject(resolved);
    return resolved;
  }

  void _validate(String root, String path, {required bool directory}) {
    if (path != root &&
        !DotnetCleanScope.contains(root, path, separator: p.separator)) {
      _reject(path);
    }
    // Check every lexical ancestor, including those above the selected root.
    // Junctions and symlinks are rejected by type OR canonical mismatch.
    var ancestor = path;
    while (true) {
      final type = FileSystemEntity.typeSync(ancestor, followLinks: false);
      if (type == FileSystemEntityType.link ||
          type == FileSystemEntityType.notFound) {
        _reject(ancestor);
      }
      if (ancestor == path) {
        if (directory && type != FileSystemEntityType.directory) _reject(path);
        if (!directory && type != FileSystemEntityType.file) _reject(path);
      } else if (type != FileSystemEntityType.directory) {
        _reject(ancestor);
      }
      final parent = p.dirname(ancestor);
      if (parent == ancestor) break;
      ancestor = parent;
    }
    final entity = directory ? Directory(path) : File(path);
    if (entity.resolveSymbolicLinksSync() != path) _reject(path);
    if (Directory(root).resolveSymbolicLinksSync() != root) _reject(root);
  }

  @override
  Future<void> validateRoot(String root) async {
    _validate(root, root, directory: true);
    if (_rootSnapshots[root] != _snapshot(root)) _reject(root);
  }

  @override
  Future<List<String>> discover(String root) async {
    _validate(root, root, directory: true);
    final artifacts = <String>[];
    void scan(String path) {
      _validate(root, path, directory: true);
      for (final entry in Directory(path).listSync(followLinks: false)) {
        if (FileSystemEntity.typeSync(entry.path, followLinks: false) !=
            FileSystemEntityType.directory) {
          continue;
        }
        if (entry.resolveSymbolicLinksSync() != entry.path) continue;
        _validate(root, entry.path, directory: true);
        final name = p.basename(entry.path);
        if (name == 'bin' || name == 'obj') {
          artifacts.add(entry.path);
        } else {
          scan(entry.path);
        }
      }
    }

    scan(root);
    _rootSnapshots[root] = _snapshot(root);
    for (final artifact in artifacts) {
      _artifactSnapshots[artifact] = _snapshot(artifact);
    }
    return artifacts;
  }

  @override
  Future<void> deleteArtifact(String root, String path) async {
    if (!DotnetCleanScope.contains(root, path, separator: p.separator) ||
        !{'bin', 'obj'}.contains(p.basename(path))) {
      _reject(path);
    }
    // Preflight the complete tree before deleting anything in this artifact.
    // No recursive delete is used: each entry is checked immediately before its
    // removal, and links/new contents cause conservative partial retention.
    final entries = <(String, bool)>[];
    void collect(String current) {
      _validate(root, current, directory: true);
      for (final child in Directory(current).listSync(followLinks: false)) {
        final type = FileSystemEntity.typeSync(child.path, followLinks: false);
        if (type == FileSystemEntityType.directory) {
          collect(child.path);
        } else if (type == FileSystemEntityType.file) {
          _validate(root, child.path, directory: false);
          entries.add((child.path, false));
        } else {
          _reject(child.path);
        }
      }
      entries.add((current, true));
    }

    if (_artifactSnapshots[path] != _snapshot(path)) _reject(path);
    collect(path);
    for (final (entry, directory) in entries) {
      _validate(root, root, directory: true);
      _validate(root, entry, directory: directory);
      if (deleteEntry case final delete?) {
        await delete(entry, directory);
      } else if (directory) {
        Directory(entry).deleteSync();
      } else {
        File(entry).deleteSync();
      }
    }
    if (FileSystemEntity.typeSync(path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      _reject(path);
    }
    _rootSnapshots[root] = _snapshot(root);
    _artifactSnapshots.remove(path);
  }
}
