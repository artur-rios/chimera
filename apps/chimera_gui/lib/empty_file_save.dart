import 'dart:typed_data';

import 'empty_file_save_stub.dart'
    if (dart.library.js_interop) 'empty_file_save_web.dart'
    as implementation;

Future<bool?> trySaveEmptyFile(String name, Uint8List bytes, String mimeType) =>
    implementation.trySaveEmptyFile(name, bytes, mimeType);
