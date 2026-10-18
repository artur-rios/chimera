import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<bool?> trySaveEmptyFile(
  String name,
  Uint8List bytes,
  String mimeType,
) async {
  if (bytes.isNotEmpty) return null;

  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  try {
    web.HTMLAnchorElement()
      ..href = url
      ..target = 'blank'
      ..download = name
      ..click();
  } finally {
    web.URL.revokeObjectURL(url);
  }
  return true;
}
