import 'dart:typed_data';

import 'local_file_save_contract.dart';
import 'local_file_save_web.dart'
    if (dart.library.io) 'local_file_save_native.dart'
    as implementation;

export 'local_file_save_contract.dart';

/// Native: path-only dialog followed by a transactional write. Web: download.
Future<bool> saveLocalFile(
  String name,
  Uint8List bytes,
  String mimeType, {
  List<String> extensions = const [],
  LocalSaveLocationChooser? chooseLocation,
  LocalFileTransactionWriter? writeTransaction,
}) => implementation.saveLocalFile(
  name,
  bytes,
  mimeType,
  extensions: extensions,
  chooseLocation: chooseLocation,
  writeTransaction: writeTransaction,
);
