import 'result.dart';

/// Platform boundary: native adapters must refuse links and revalidate scope at
/// deletion time. Discovery never mutates the filesystem.
abstract interface class DotnetCleanGateway {
  Future<String> resolveRoot(String? root);
  Future<List<String>> discover(String root);
  Future<void> validateRoot(String root);
  Future<void> deleteArtifact(String root, String path);
}

final class DotnetCleanPreview {
  DotnetCleanPreview._(this.root, List<String> paths)
    : paths = List.unmodifiable(paths);
  final String root;

  /// Topmost artifact directories; nested artifacts are included in their tree.
  final List<String> paths;
}

final class DotnetCleanReport {
  DotnetCleanReport(List<String> removed, Map<String, String> retained)
    : removed = List.unmodifiable(removed),
      retained = Map.unmodifiable(retained);
  final List<String> removed;
  final Map<String, String> retained;
  bool get isPartialFailure => retained.isNotEmpty;
}

/// Exact comparison deliberately rejects case aliases even on Windows. The
/// native boundary also checks canonical paths and every ancestor for links.
abstract final class DotnetCleanScope {
  static bool contains(String root, String path, {required String separator}) {
    if (path.split(separator).any((part) => part == '..' || part == '.')) {
      return false;
    }
    final prefix = root.endsWith(separator) ? root : '$root$separator';
    return path.startsWith(prefix) && path.length > prefix.length;
  }
}

final class DotnetCleanService {
  DotnetCleanService(this.gateway);
  final DotnetCleanGateway gateway;
  DotnetCleanPreview? _currentPreview;

  Future<ChimeraResult<DotnetCleanPreview>> preview({String? root}) async {
    _currentPreview = null;
    try {
      final resolved = await gateway.resolveRoot(root);
      final paths = await gateway.discover(resolved);
      final preview = DotnetCleanPreview._(resolved, paths..sort());
      _currentPreview = preview;
      return ChimeraSuccess(preview);
    } on Object {
      return const ChimeraFailure(
        kind: FailureKind.validation,
        code: 'dotnet-clean-invalid-root',
        messageKey: 'dotnetClean.invalidRoot',
      );
    }
  }

  Future<ChimeraResult<DotnetCleanReport>> clean(
    DotnetCleanPreview preview, {
    required bool confirmed,
  }) async {
    if (!confirmed) {
      return const ChimeraFailure(
        kind: FailureKind.validation,
        code: 'dotnet-clean-confirmation-required',
        messageKey: 'dotnetClean.confirmationRequired',
      );
    }
    if (!identical(_currentPreview, preview)) {
      return const ChimeraFailure(
        kind: FailureKind.validation,
        code: 'dotnet-clean-invalid-preview',
        messageKey: 'dotnetClean.invalidPreview',
      );
    }
    _currentPreview = null;
    try {
      await gateway.validateRoot(preview.root);
    } on Object {
      return const ChimeraFailure(
        kind: FailureKind.validation,
        code: 'dotnet-clean-invalid-root',
        messageKey: 'dotnetClean.invalidRoot',
      );
    }
    final removed = <String>[];
    final retained = <String, String>{};
    for (final path in preview.paths) {
      try {
        await gateway.validateRoot(preview.root);
        await gateway.deleteArtifact(preview.root, path);
        removed.add(path);
      } on Object {
        retained[path] = 'dotnetClean.retained';
      }
    }
    return ChimeraSuccess(DotnetCleanReport(removed, retained));
  }
}
