import 'dart:convert';
import 'dart:io';

import 'package:chimera_gui/app.dart';
import 'package:chimera_gui/lorem_page.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _PathChooser extends FileSelectorPlatform {
  _PathChooser(this.path, {this.failure = false});
  final String? path;
  final bool failure;
  int calls = 0;
  @override
  Future<FileSaveLocation?> getSaveLocation({
    SaveDialogOptions options = const SaveDialogOptions(),
    List<XTypeGroup>? acceptedTypeGroups,
  }) async {
    calls++;
    expect(options.suggestedName, 'chimera-lorem.txt');
    expect(acceptedTypeGroups!.single.extensions, ['txt']);
    if (failure) throw const FileSystemException('PRIVATE');
    return path == null ? null : FileSaveLocation(path!);
  }
}

void main() {
  late Directory directory;
  late FileSelectorPlatform previous;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('lorem-native-save-');
    previous = FileSelectorPlatform.instance;
  });
  tearDown(() async {
    FileSelectorPlatform.instance = previous;
    await directory.delete(recursive: true);
  });
  for (final existing in [false, true]) {
    test(
      'Given${existing}Target_WhenDefaultSaverUsed_ThenExactBytesAndNoArtifacts',
      () async {
        final target = File('${directory.path}/lorem.txt');
        if (existing) await target.writeAsString('previous');
        final chooser = _PathChooser(target.path);
        FileSelectorPlatform.instance = chooser;
        expect(
          await saveLoremFile(
            'chimera-lorem.txt',
            utf8.encode('Lorem ipsum'),
            'text/plain; charset=utf-8',
          ),
          isTrue,
        );
        expect(await target.readAsBytes(), utf8.encode('Lorem ipsum'));
        expect(chooser.calls, 1);
        expect(directory.listSync().length, 1);
      },
    );
  }
  test('GivenCanceledNativeChooser_WhenDefaultSaverUsed_ThenNoFiles', () async {
    FileSelectorPlatform.instance = _PathChooser(null);
    expect(
      await saveLoremFile(
        'chimera-lorem.txt',
        utf8.encode('Lorem'),
        'text/plain',
      ),
      isFalse,
    );
    expect(directory.listSync(), isEmpty);
  });
  for (final mode in ['chooser', 'directory', 'missing-parent']) {
    testWidgets(
      'Given${mode}NativeFailure_WhenDefaultGuiSaverRuns_ThenLocalizedErrorAndNoPartialResult',
      (tester) async {
        await tester.runAsync(() async {
          final sentinel = File('${directory.path}/sentinel.txt');
          await sentinel.writeAsString('original');
          final path = mode == 'directory'
              ? directory.path
              : '${directory.path}/missing/output.txt';
          FileSelectorPlatform.instance = _PathChooser(
            path,
            failure: mode == 'chooser',
          );
          await tester.pumpWidget(
            const ChimeraApp(initialLocation: '/lorem/generate'),
          );
          await tester.tap(find.byKey(const Key('lorem-generate')));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(const Key('lorem-save')));
          await tester.tap(find.byKey(const Key('lorem-save')));
          for (
            var turn = 0;
            turn < 100 &&
                find.byKey(const Key('lorem-error')).evaluate().isEmpty;
            turn++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            await tester.pump();
          }
          expect(find.byKey(const Key('lorem-output')), findsNothing);
          expect(
            find.text('The generated text could not be saved or written.'),
            findsOneWidget,
          );
          expect(await sentinel.readAsString(), 'original');
          expect(directory.listSync().length, 1);
          expect(find.textContaining('PRIVATE'), findsNothing);
        });
      },
    );
  }
}
