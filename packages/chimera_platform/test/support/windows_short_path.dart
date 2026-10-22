import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _GetShortPathNative = Uint32 Function(
  Pointer<Utf16>,
  Pointer<Utf16>,
  Uint32,
);
typedef GetShortPath = int Function(Pointer<Utf16>, Pointer<Utf16>, int);

/// Use the wide-character API directly: cmd FOR output is shell syntax, not a
/// reliable filesystem path when Dart quotes an argument containing spaces.
String windowsShortPath(String path) {
  final kernel = DynamicLibrary.open('kernel32.dll');
  return queryWindowsShortPath(
    path,
    getShortPath: kernel.lookupFunction<_GetShortPathNative, GetShortPath>(
      'GetShortPathNameW',
    ),
    getLastError: kernel.lookupFunction<Uint32 Function(), int Function()>(
      'GetLastError',
    ),
  );
}

/// Follow GetShortPathNameW's buffer contract, including a growing required size.
/// Callbacks allow exercising its UTF-16/error handling on non-Windows hosts.
String queryWindowsShortPath(
  String path, {
  required GetShortPath getShortPath,
  required int Function() getLastError,
}) {
  final input = path.toNativeUtf16(allocator: calloc);
  try {
    var capacity = getShortPath(input, nullptr, 0);
    while (true) {
      if (capacity == 0) {
        throw FileSystemException(
          'GetShortPathNameW failed',
          path,
          OSError('Windows error', getLastError()),
        );
      }
      final output = calloc<Uint16>(capacity).cast<Utf16>();
      try {
        final length = getShortPath(input, output, capacity);
        if (length == 0) {
          throw FileSystemException(
            'GetShortPathNameW failed',
            path,
            OSError('Windows error', getLastError()),
          );
        }
        if (length < capacity) return output.toDartString(length: length);
        capacity = length;
      } finally {
        calloc.free(output);
      }
    }
  } finally {
    calloc.free(input);
  }
}
