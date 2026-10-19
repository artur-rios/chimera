import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'empty_file_save.dart';
import 'local_file_save_contract.dart';

Future<bool> saveLocalFile(
  String name,
  Uint8List bytes,
  String mimeType, {
  List<String> extensions = const [],
  LocalSaveLocationChooser? chooseLocation,
  LocalFileTransactionWriter? writeTransaction,
}) async {
  final emptyWebSave = await trySaveEmptyFile(name, bytes, mimeType);
  if (emptyWebSave != null) return emptyWebSave;
  await FilePicker.saveFile(
    fileName: name,
    bytes: bytes,
    mimeType: mimeType,
    type: extensions.isEmpty ? FileType.any : FileType.custom,
    allowedExtensions: extensions.isEmpty ? null : extensions,
  );
  return true;
}
