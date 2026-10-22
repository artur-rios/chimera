import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

/// Reserve a new directory atomically. Directory.create accepts an existing
/// directory, which cannot enforce the scaffold's no-overwrite contract.
void createDirectoryExclusively(String path) {
  final library = Platform.isWindows
      ? DynamicLibrary.open('msvcrt.dll')
      : DynamicLibrary.process();
  final allocate = library
      .lookupFunction<
        Pointer<Void> Function(IntPtr),
        Pointer<Void> Function(int)
      >('malloc');
  final release = library
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('free');
  final bytes = Platform.isWindows ? path.codeUnits : utf8.encode(path);
  final buffer = allocate((bytes.length + 1) * (Platform.isWindows ? 2 : 1));
  if (buffer == nullptr) {
    throw const FileSystemException('Cannot allocate destination path');
  }
  try {
    late int result;
    if (Platform.isWindows) {
      final chars = buffer.cast<Uint16>().asTypedList(bytes.length + 1);
      chars.setRange(0, bytes.length, bytes);
      chars[bytes.length] = 0;
      final mkdir = library
          .lookupFunction<
            Int32 Function(Pointer<Uint16>),
            int Function(Pointer<Uint16>)
          >('_wmkdir');
      result = mkdir(buffer.cast<Uint16>());
    } else {
      final chars = buffer.cast<Uint8>().asTypedList(bytes.length + 1);
      chars.setRange(0, bytes.length, bytes);
      chars[bytes.length] = 0;
      final mkdir = library
          .lookupFunction<
            Int32 Function(Pointer<Uint8>, Uint32),
            int Function(Pointer<Uint8>, int)
          >('mkdir');
      result = mkdir(buffer.cast<Uint8>(), 448);
    }
    if (result != 0) {
      throw FileSystemException(
        'Cannot reserve a new destination directory',
        path,
      );
    }
  } finally {
    release(buffer);
  }
}
