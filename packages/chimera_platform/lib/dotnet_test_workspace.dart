/// Native-only scoped output/discovery adapter for .NET coverage workflows.
library;

import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:path/path.dart' as p;

import 'native_commands.dart';

final class NativeDotnetTestWorkspace implements DotnetTestWorkspace {
  const NativeDotnetTestWorkspace({
    this.currentDirectory,
    this.discovery = const NativeProjectDiscovery(),
  });
  final String? currentDirectory;
  final ProjectFileDiscovery discovery;
  ChimeraFailure<T> _failure<T>([String code = 'dotnet.unsafeOutput']) =>
      ChimeraFailure(
        kind: FailureKind.access,
        code: code,
        messageKey: 'error.$code',
      );

  @override
  Future<ChimeraResult<DotnetTestLayout>> resolve(
    DotnetTestRequest request,
  ) async {
    try {
      final cwd = await Directory(currentDirectory ?? Directory.current.path)
          .resolveSymbolicLinks();
      if (request.baseDirectory != null &&
          request.baseDirectory!.trim().isEmpty) {
        return _failure('dotnet.invalidPath');
      }
      final search = Directory(
        request.baseDirectory == null
            ? p.join(cwd, 'tests')
            : p.isAbsolute(request.baseDirectory!)
            ? request.baseDirectory!
            : p.join(cwd, request.baseDirectory!),
      );
      if (!await search.exists()) {
        return _failure('dotnet.invalidPath');
      }
      final resolvedSearch = await search.resolveSymbolicLinks();
      final scope = request.baseDirectory == null ? cwd : resolvedSearch;
      if (request.baseDirectory == null && !p.isWithin(scope, resolvedSearch)) {
        return _failure();
      }
      final layout = DotnetTestLayout(
        projectScope: scope,
        searchDirectory: resolvedSearch,
        resultsDirectory: p.join(resolvedSearch, 'TestResults'),
        reportDirectory: p.join(
          request.baseDirectory == null ? p.join(scope, 'docs') : scope,
          'coverage-report',
        ),
        projects: const [],
      );
      if (!await _validOutputs(layout)) {
        return _failure();
      }
      final discovered = await discovery.discover(
        resolvedSearch,
        extension: '.csproj',
        recursive: true,
        excludedDirectories: const {
          'setup',
          'testresults',
          'coverage-report',
          'bin',
          'obj',
        },
      );
      if (discovered is ChimeraFailure<List<String>>) {
        return ChimeraFailure(
          kind: discovered.kind,
          code: discovered.code,
          messageKey: discovered.messageKey,
          details: discovered.details,
        );
      }
      return ChimeraSuccess(
        DotnetTestLayout(
          projectScope: scope,
          searchDirectory: resolvedSearch,
          resultsDirectory: layout.resultsDirectory,
          reportDirectory: layout.reportDirectory,
          projects: (discovered as ChimeraSuccess<List<String>>).value,
        ),
      );
    } on FileSystemException {
      return _failure('dotnet.invalidPath');
    } on ArgumentError {
      return _failure('dotnet.invalidPath');
    }
  }

  Future<bool> _safeOutput(String scope, String output) async {
    if (!await Directory(scope).exists() ||
        await Directory(scope).resolveSymbolicLinks() != scope ||
        !p.isWithin(scope, p.normalize(output))) {
      return false;
    }
    var ancestor = scope;
    for (final segment in p.split(p.relative(output, from: scope))) {
      ancestor = p.join(ancestor, segment);
      final type = await FileSystemEntity.type(ancestor, followLinks: false);
      if (type == FileSystemEntityType.link ||
          type == FileSystemEntityType.file) {
        return false;
      }
      if (type == FileSystemEntityType.directory) {
        final real = await Directory(ancestor).resolveSymbolicLinks();
        if (!p.isWithin(scope, real)) {
          return false;
        }
      }
    }
    return true;
  }

  Future<bool> _validOutputs(DotnetTestLayout layout) async =>
      await _safeOutput(layout.projectScope, layout.resultsDirectory) &&
      await _safeOutput(layout.projectScope, layout.reportDirectory);

  @override
  Future<ChimeraResult<bool>> prepare(DotnetTestLayout layout) async {
    try {
      // Validate BOTH paths before deleting anything, then recheck each root.
      if (!await _validOutputs(layout)) {
        return _failure();
      }
      for (final path in [layout.resultsDirectory, layout.reportDirectory]) {
        if (!await _safeOutput(layout.projectScope, path)) {
          return _failure();
        }
        final directory = await Directory(path).create(recursive: true);
        await for (final child in directory.list(followLinks: false)) {
          // Directory.delete(recursive:true) does not follow links; links are
          // separate Link entries, including Windows directory junctions.
          await child.delete(recursive: child is Directory);
        }
      }
      return const ChimeraSuccess(true);
    } on FileSystemException {
      return _failure('dotnet.outputAccess');
    }
  }

  @override
  Future<DotnetCoverageSnapshot> coverageSnapshot(
    DotnetTestLayout layout,
  ) async {
    try {
      if (!await _safeOutput(layout.projectScope, layout.resultsDirectory)) {
        return const DotnetCoverageSnapshot();
      }
      final discovered = await discovery.discover(
        layout.resultsDirectory,
        extension: '.xml',
        recursive: true,
      );
      final json = await discovery.discover(
        layout.resultsDirectory,
        extension: '.json',
        recursive: true,
      );
      final lcov = await discovery.discover(
        layout.resultsDirectory,
        extension: '.info',
        recursive: true,
      );
      int count(ChimeraResult<List<String>> result, String name) =>
          result is ChimeraSuccess<List<String>>
          ? result.value
                .where((path) => p.basename(path).toLowerCase() == name)
                .length
          : 0;
      return DotnetCoverageSnapshot(
        cobertura: count(discovered, 'coverage.cobertura.xml'),
        json: count(json, 'coverage.json'),
        lcov: count(lcov, 'coverage.info'),
      );
    } on FileSystemException {
      return const DotnetCoverageSnapshot();
    }
  }

  @override
  Future<bool> hasHtmlReport(DotnetTestLayout layout) async {
    try {
      return await _safeOutput(layout.projectScope, layout.reportDirectory) &&
          await File(p.join(layout.reportDirectory, 'index.html')).exists();
    } on FileSystemException {
      return false;
    }
  }
}
