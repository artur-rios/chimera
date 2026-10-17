import 'dart:typed_data';
import 'dart:ui' as ui;

import 'base64_preview_fallback_stub.dart'
    if (dart.library.js_interop) 'base64_preview_fallback_web.dart'
    as implementation;

Future<ui.Image?> decodeBase64PreviewFallback(
  Uint8List bytes,
  String mediaType,
) => implementation.decodeBase64PreviewFallback(bytes, mediaType);
