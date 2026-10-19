import 'dart:io';

typedef FileBytesWriter = Future<void> Function(String path, List<int> bytes);
typedef TryReserveFile = Future<bool> Function(File candidate);
typedef CopyFile = Future<void> Function(File source, File destination);
typedef RenameFile = Future<void> Function(File source, String destinationPath);
typedef DeleteFile = Future<void> Function(File file);

final class FileTransactionOperations {
  const FileTransactionOperations({
    this.tryReserve,
    this.copy,
    this.rename,
    this.delete,
  });

  final TryReserveFile? tryReserve;
  final CopyFile? copy;
  final RenameFile? rename;
  final DeleteFile? delete;
}

/// Native transactional bytes writer. Only sibling stages/backups are written
/// until the replacement is ready; failed replacement restores previous bytes.
final class TransactionalFileWriter {
  const TransactionalFileWriter({
    this.writeStage,
    this.operations = const FileTransactionOperations(),
  });
  final FileBytesWriter? writeStage;
  final FileTransactionOperations operations;
  Future<void> write(String path, List<int> bytes) => _writeFileTransactionally(
    path,
    bytes,
    writeStage: writeStage ?? writeFileStageExactly,
    operations: operations,
  );
}

var _transactionFileSequence = 0;

Future<void> _writeFileTransactionally(
  String path,
  List<int> bytes, {
  required FileBytesWriter writeStage,
  required FileTransactionOperations operations,
}) async {
  final target = File(path);
  final stage = await _reserveTransactionSibling(target, 'stage', operations);
  File? backup;
  try {
    await writeStage(stage.path, bytes);
    if (!await stage.exists()) {
      throw const FileSystemException('Output stage was not created');
    }

    final hadTarget = await target.exists();
    if (hadTarget) {
      backup = await _reserveTransactionSibling(target, 'backup', operations);
      await _copyTransactionFile(target, backup, operations);
      await _deleteTransactionFile(target, operations);
    }

    try {
      await _renameTransactionFile(stage, target.path, operations);
    } on Object catch (error, stackTrace) {
      await _restoreTransactionTarget(
        target,
        backup: backup,
        hadTarget: hadTarget,
        operations: operations,
      );
      backup = null;
      Error.throwWithStackTrace(error, stackTrace);
    }

    if (backup != null) {
      try {
        await _deleteTransactionFile(backup, operations);
        backup = null;
      } on Object catch (error, stackTrace) {
        await _restoreTransactionTarget(
          target,
          backup: backup,
          hadTarget: true,
          operations: operations,
        );
        backup = null;
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
  } on Object catch (error, stackTrace) {
    await _deleteTransactionFileIfPresent(stage, operations);
    if (backup != null) {
      if (await target.exists()) {
        await _deleteTransactionFileIfPresent(backup, operations);
      } else {
        await _renameTransactionFile(backup, target.path, operations);
      }
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
}

Future<File> _reserveTransactionSibling(
  File target,
  String role,
  FileTransactionOperations operations,
) async {
  while (true) {
    final sequence = _transactionFileSequence++;
    final candidate = File(
      '${target.parent.path}${Platform.pathSeparator}'
      '.chimera-$role-$pid-$sequence',
    );
    final reserved =
        await (operations.tryReserve ?? _tryReserveTransactionFile)(candidate);
    if (reserved) return candidate;
  }
}

Future<void> writeFileStageExactly(String path, List<int> bytes) async {
  final stage = File(path);
  await stage.writeAsBytes(bytes, flush: true);
}

Future<bool> _tryReserveTransactionFile(File candidate) async {
  try {
    await candidate.create(exclusive: true);
    return true;
  } on FileSystemException catch (error) {
    if (switch (error.osError?.errorCode) {
      17 || 80 || 183 => true,
      _ => false,
    }) {
      return false;
    }
    rethrow;
  }
}

Future<void> _copyTransactionFile(
  File source,
  File destination,
  FileTransactionOperations operations,
) => (operations.copy ?? _copyTransactionFileFlushed)(source, destination);

Future<void> _copyTransactionFileFlushed(File source, File destination) async {
  final input = await source.open();
  final output = await destination.open(mode: FileMode.write);
  try {
    while (true) {
      final chunk = await input.read(64 * 1024);
      if (chunk.isEmpty) break;
      await output.writeFrom(chunk);
    }
    await output.flush();
  } finally {
    await input.close();
    await output.close();
  }
}

Future<void> _renameTransactionFile(
  File source,
  String destinationPath,
  FileTransactionOperations operations,
) async {
  final rename = operations.rename;
  if (rename != null) {
    await rename(source, destinationPath);
  } else {
    await source.rename(destinationPath);
  }
}

Future<void> _deleteTransactionFile(
  File file,
  FileTransactionOperations operations,
) async {
  final delete = operations.delete;
  if (delete != null) {
    await delete(file);
  } else {
    await file.delete();
  }
}

Future<void> _deleteTransactionFileIfPresent(
  File file,
  FileTransactionOperations operations,
) async {
  if (await file.exists()) {
    await _deleteTransactionFile(file, operations);
  }
}

Future<void> _restoreTransactionTarget(
  File target, {
  required File? backup,
  required bool hadTarget,
  required FileTransactionOperations operations,
}) async {
  await _deleteTransactionFileIfPresent(target, operations);
  if (hadTarget) {
    if (backup == null || !await backup.exists()) {
      throw const FileSystemException('Output backup is unavailable');
    }
    await _renameTransactionFile(backup, target.path, operations);
  }
}
