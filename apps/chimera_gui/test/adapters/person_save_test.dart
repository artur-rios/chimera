import 'dart:convert';
import 'dart:io';

import 'package:chimera_gui/person_page.dart';
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
    expect(options.suggestedName, 'chimera-synthetic-people.txt');
    expect(acceptedTypeGroups!.single.extensions, ['txt']);
    return path == null ? null : FileSaveLocation(path!);
  }
}

void main() {
  late Directory directory;
  late FileSelectorPlatform previous;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('person-save-');
    previous = FileSelectorPlatform.instance;
  });
  tearDown(() async {
    FileSelectorPlatform.instance = previous;
    await directory.delete(recursive: true);
  });

  for (final existing in [false, true]) {
    test(
      'Given${existing}Target_WhenPeopleSaved_ThenExactBytesAndNoArtifacts',
      () async {
        final target = File('${directory.path}/people.txt');
        if (existing) await target.writeAsString('previous');
        FileSelectorPlatform.instance = _PathChooser(target.path);
        const value = 'Synthetic person test data\nPerson 1\nAvery Reed';

        expect(
          await savePersonFile(
            'chimera-synthetic-people.txt',
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

  test('GivenCanceledChooser_WhenPeopleSaved_ThenNoFileIsCreated', () async {
    FileSelectorPlatform.instance = _PathChooser(null);
    expect(
      await savePersonFile(
        'chimera-synthetic-people.txt',
        utf8.encode('value'),
        'text/plain; charset=utf-8',
      ),
      isFalse,
    );
    expect(directory.listSync(), isEmpty);
  });
}
