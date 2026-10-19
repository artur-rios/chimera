import 'dart:typed_data';

import 'package:chimera_platform/transactional_file_writer.dart';
import 'package:file_selector/file_selector.dart';

import 'local_file_save_contract.dart';

Future<bool> saveLocalFile(
  String name,
  Uint8List bytes,
  String mimeType, {
  List<String> extensions = const [],
  LocalSaveLocationChooser? chooseLocation,
  LocalFileTransactionWriter? writeTransaction,
}) async {
  final path = await (chooseLocation ?? _chooseSaveLocation)(name, extensions);
  if (path == null) return false;
  await (writeTransaction ?? const TransactionalFileWriter().write)(
    path,
    bytes,
  );
  return true;
}

Future<String?> _chooseSaveLocation(
  String name,
  List<String> extensions,
) async => (await getSaveLocation(
  suggestedName: name,
  acceptedTypeGroups: extensions.isEmpty
      ? const []
      : [XTypeGroup(extensions: extensions)],
))?.path;
