import 'dart:io';

import 'package:path/path.dart' as p;

/// An OS short-name spelling of a real directory, without a filesystem link.
/// Directory.path retains the lexical spelling just as dart:io does on Windows.
final class NativeDirectoryAliasOverrides extends IOOverrides {
  NativeDirectoryAliasOverrides(
    this.alias,
    this.canonical, {
    this.sameObject = true,
  });
  final String alias;
  final String canonical;
  final bool sameObject;
  final List<String> directoryRequests = [];
  bool _isAlias(String path) => path == alias || p.isWithin(alias, path);
  String _map(String path) =>
      _isAlias(path) ? p.join(canonical, p.relative(path, from: alias)) : path;
  @override
  Directory createDirectory(String path) {
    directoryRequests.add(path);
    return _isAlias(path)
        ? _AliasDirectory(path, super.createDirectory(_map(path)))
        : super.createDirectory(path);
  }

  @override
  File createFile(String path) => super.createFile(_map(path));
  @override
  FileSystemEntityType fseGetTypeSync(String path, bool followLinks) =>
      super.fseGetTypeSync(_map(path), followLinks);
  @override
  Future<FileSystemEntityType> fseGetType(String path, bool followLinks) =>
      super.fseGetType(_map(path), followLinks);
  @override
  bool fseIdenticalSync(String first, String second) =>
      (!sameObject && (_isAlias(first) || _isAlias(second)))
      ? false
      : super.fseIdenticalSync(_map(first), _map(second));
}

final class _AliasDirectory implements Directory {
  _AliasDirectory(this.path, this.actual);
  @override
  final String path;
  final Directory actual;
  @override
  bool existsSync() => actual.existsSync();
  @override
  Future<bool> exists() => actual.exists();
  @override
  String resolveSymbolicLinksSync() => actual.resolveSymbolicLinksSync();
  @override
  Future<String> resolveSymbolicLinks() => actual.resolveSymbolicLinks();
  @override
  List<FileSystemEntity> listSync({
    bool recursive = false,
    bool followLinks = true,
  }) => actual.listSync(recursive: recursive, followLinks: followLinks);
  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) => actual.list(recursive: recursive, followLinks: followLinks);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Obtain a real Windows 8.3 spelling when the test volume supports it.
Future<String?> windowsShortDirectory(Directory directory) async {
  final canonical = await directory.resolveSymbolicLinks();
  if (!p.equals(directory.path, canonical)) return directory.path;
  final result = await Process.run('cmd', [
    '/d',
    '/c',
    'for %I in ("${directory.path}") do @echo %~sI',
  ]);
  if (result.exitCode != 0) {
    throw FileSystemException(
      'Could not query Windows short path',
      directory.path,
    );
  }
  final alias = p.normalize((result.stdout as String).trim());
  if (p.equals(alias, canonical)) return null;
  if (!FileSystemEntity.identicalSync(alias, canonical)) {
    throw FileSystemException('Short path is not the same directory', alias);
  }
  return alias;
}
