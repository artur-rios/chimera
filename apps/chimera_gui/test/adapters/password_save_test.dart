import 'dart:convert';
import 'dart:io';

import 'package:chimera_gui/password_page.dart';
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
    expect(options.suggestedName, 'chimera-password.txt');
    expect(acceptedTypeGroups!.single.extensions, ['txt']);
    return path == null ? null : FileSaveLocation(path!);
  }
}

void main() {
  late Directory directory;
  late FileSelectorPlatform previous;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('password-save-');
    previous = FileSelectorPlatform.instance;
  });
  tearDown(() async {
    FileSelectorPlatform.instance = previous;
    await directory.delete(recursive: true);
  });

  for (final existing in [false, true]) {
    test(
      'Given${existing}Target_WhenPasswordSaved_ThenExactBytesAndNoArtifacts',
      () async {
        final target = File('${directory.path}/password.txt');
        if (existing) await target.writeAsString('previous');
        FileSelectorPlatform.instance = _PathChooser(target.path);

        expect(
          await savePasswordFile(
            'chimera-password.txt',
            utf8.encode('aA0!'),
            'text/plain; charset=utf-8',
          ),
          isTrue,
        );
        expect(await target.readAsString(), 'aA0!');
        expect(directory.listSync(), hasLength(1));
      },
    );
  }

  test('GivenCanceledChooser_WhenPasswordSaved_ThenNoFileIsCreated', () async {
    FileSelectorPlatform.instance = _PathChooser(null);

    expect(
      await savePasswordFile(
        'chimera-password.txt',
        utf8.encode('aA0!'),
        'text/plain; charset=utf-8',
      ),
      isFalse,
    );
    expect(directory.listSync(), isEmpty);
  });
}
