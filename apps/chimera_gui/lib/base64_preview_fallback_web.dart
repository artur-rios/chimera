import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

Future<ui.Image?> decodeBase64PreviewFallback(
  Uint8List bytes,
  String mediaType,
) async {
  final image = web.document.createElement('img') as web.HTMLImageElement;
  image.src = Uri.dataFromBytes(bytes, mimeType: mediaType).toString();
  await image.decode().toDart;
  final bitmap = await web.window.createImageBitmap(image).toDart;
  try {
    return await Future<ui.Image>.value(
      ui_web.createImageFromImageBitmap(bitmap),
    );
  } on Object {
    bitmap.close();
    rethrow;
  }
}
