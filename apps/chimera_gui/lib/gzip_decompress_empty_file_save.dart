import 'dart:typed_data';

import 'gzip_decompress_empty_file_save_stub.dart'
    if (dart.library.js_interop) 'gzip_decompress_empty_file_save_web.dart'
    as implementation;

Future<bool?> trySaveEmptyGzipDecompressFile(
  String name,
  Uint8List bytes,
  String mimeType,
) => implementation.trySaveEmptyGzipDecompressFile(name, bytes, mimeType);
