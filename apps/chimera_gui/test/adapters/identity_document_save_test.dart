import 'dart:convert';
import 'dart:io';

import 'package:chimera_gui/identity_document_page.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

final class _PathChooser extends FileSelectorPlatform {
  _PathChooser(this.path);
  final String? path;

  @override
  Future<FileSaveLocation?> getSaveLocation({
    SaveDialogOptions options = const SaveDialogOptions(),
    List<XTypeGroup>? acceptedTypeGroups,
  }) async {
    expect(options.suggestedName, 'chimera-synthetic-identity-documents.txt');
    expect(acceptedTypeGroups!.single.extensions, ['txt']);
    return path == null ? null : FileSaveLocation(path!);
  }
}

void main() {
  late Directory directory;
  late FileSelectorPlatform previous;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'identity-document-save-',
    );
    previous = FileSelectorPlatform.instance;
  });
  tearDown(() async {
    FileSelectorPlatform.instance = previous;
    await directory.delete(recursive: true);
  });

  for (final existing in [false, true]) {
    test(
      'Given${existing}Target_WhenIdentityDocumentsSaved_ThenExactBytesAndNoArtifacts',
      () async {
        final target = File('${directory.path}/documents.txt');
        if (existing) await target.writeAsString('previous');
        FileSelectorPlatform.instance = _PathChooser(target.path);
        const value =
            'Synthetic identity test data - not proof of issuance\n219-09-9999';

        expect(
          await saveIdentityDocumentFile(
            'chimera-synthetic-identity-documents.txt',
            utf8.encode(value),
            'text/plain; charset=utf-8',
          ),
          isTrue,
        );
        expect(await target.readAsString(), value);
        expect(directory.listSync(), hasLength(1));
      },
    );
  }

  test(
    'GivenCanceledChooser_WhenIdentityDocumentsSaved_ThenNoFileIsCreated',
    () async {
      FileSelectorPlatform.instance = _PathChooser(null);
      expect(
        await saveIdentityDocumentFile(
          'chimera-synthetic-identity-documents.txt',
          utf8.encode('value'),
          'text/plain; charset=utf-8',
        ),
        isFalse,
      );
      expect(directory.listSync(), isEmpty);
    },
  );
}
