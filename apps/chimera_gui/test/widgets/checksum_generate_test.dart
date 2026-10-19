import 'dart:async';
import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../tests/fixtures/checksums/vectors.dart';

Finder _control(String value) => find.byKey(Key('checksum-generate-$value'));
Future<void> _tap(WidgetTester tester, String value) async {
  await tester.ensureVisible(_control(value));
  await tester.tap(_control(value));
  await tester.pumpAndSettle();
}

final class _FakeService
    implements
        OperationService<
          ChecksumGenerateOperationRequest,
          ChecksumGenerateOutput
        > {
  _FakeService(this.callback);
  final Future<ChimeraResult<ChecksumGenerateOutput>> Function(
    ChecksumGenerateOperationRequest,
  )
  callback;
  @override
  Future<ChimeraResult<ChecksumGenerateOutput>> execute(
    ChecksumGenerateOperationRequest request,
  ) => callback(request);
}

void main() {
  for (final locale in ['en', 'pt-BR']) {
    for (final algorithm in ['crc32', 'adler32']) {
      for (final source in ['text', 'file', 'paste']) {
        testWidgets(
          'Given$locale$algorithm${source}_WhenGeneratedCopiedSaved_ThenExactChecksumAndDiscard',
          (tester) async {
            String? copied;
            String? saved;
            await tester.pumpWidget(
              ChimeraApp(
                localeTag: locale,
                initialLocation: '/checksum/generate',
                checksumGenerateFilePicker: () async => [97, 98, 99],
                checksumGenerateClipboardReader: () async => 'abc',
                checksumGenerateClipboardWriter: (v) async => copied = v,
                checksumGenerateFileSaver: (name, bytes, mime) async {
                  expect(name, 'chimera-checksum.txt');
                  expect(mime, 'text/plain; charset=utf-8');
                  saved = utf8.decode(bytes);
                  return true;
                },
              ),
            );
            await tester.pumpAndSettle();
            if (source == 'text') {
              await tester.enterText(_control('input'), 'abc');
            } else {
              await _tap(tester, source);
            }
            if (algorithm != 'crc32') {
              await tester.ensureVisible(_control('algorithm'));
              await tester.tap(_control('algorithm'));
              await tester.pumpAndSettle();
              await tester.tap(find.text(algorithm.toUpperCase()).last);
              await tester.pumpAndSettle();
            }
            await _tap(tester, 'submit');
            expect(
              tester.widget<TextField>(_control('input')).controller!.text,
              isEmpty,
            );
            expect(_control('output'), findsOneWidget);
            final checksum = tester
                .widget<SelectableText>(_control('output'))
                .data!;
            expect(checksum, checksumKnownVectors['abc']![algorithm]);
            await _tap(tester, 'copy');
            expect(copied, checksum);
            await _tap(tester, 'save');
            expect(saved, '$checksum\n');
            await tester.enterText(_control('input'), 'replacement');
            await tester.pumpAndSettle();
            expect(_control('result'), findsNothing);
            expect(_control('copy'), findsNothing);
          },
        );
      }
    }
    for (final action in ['file', 'paste', 'submit', 'copy', 'save']) {
      for (final resource in [false, true]) {
        testWidgets(
          'Given$locale$action${resource ? 'Resource' : 'Access'}Failure_WhenInvoked_ThenLocalizedAndClean',
          (tester) async {
            Never fail() => resource
                ? throw OutOfMemoryError()
                : throw StateError('SECRET');
            await tester.pumpWidget(
              ChimeraApp(
                localeTag: locale,
                initialLocation: '/checksum/generate',
                checksumGenerateFilePicker: () async => fail(),
                checksumGenerateClipboardReader: () async => fail(),
                checksumGenerateClipboardWriter: (_) async => fail(),
                checksumGenerateFileSaver: (_, _, _) async => fail(),
                checksumGenerateService: action == 'submit'
                    ? _FakeService((_) async => fail())
                    : const ChecksumGenerateService(),
              ),
            );
            await tester.pumpAndSettle();
            await tester.enterText(_control('input'), 'SECRET');
            if (action == 'copy' || action == 'save') {
              await _tap(tester, 'submit');
            }
            await _tap(tester, action);
            expect(_control('error'), findsOneWidget);
            expect(_control('result'), findsNothing);
            expect(_control('copy'), findsNothing);
            expect(_control('save'), findsNothing);
            expect(
              tester.widget<TextField>(_control('input')).controller!.text,
              isEmpty,
            );
            final error = tester.widget<Text>(_control('error')).data!;
            expect(error, isNot(contains('SECRET')));
            expect(
              error.toLowerCase(),
              contains(
                locale == 'en'
                    ? (resource ? 'resources' : 'could not')
                    : (resource ? 'recursos' : 'não foi possível'),
              ),
            );
          },
        );
      }
    }
  }
  for (final source in ['text', 'file', 'paste']) {
    testWidgets(
      'GivenSensitive${source}History_WhenGenerated_ThenUndoCannotRestoreSource',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/checksum/generate',
            checksumGenerateFilePicker: () async => [0, 255],
            checksumGenerateClipboardReader: () async => 'replacement',
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(_control('input'), 'sensitive settled');
        await tester.pump(const Duration(milliseconds: 600));
        await tester.enterText(_control('input'), 'sensitive pending');
        final old = tester.state<UndoHistoryState<TextEditingValue>>(
          find.byType(UndoHistory<TextEditingValue>),
        );
        if (source != 'text') await _tap(tester, source);
        await _tap(tester, 'submit');
        expect(old.mounted, isFalse);
        await tester.tap(_control('input'));
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        expect(
          tester.widget<TextField>(_control('input')).controller!.text,
          isEmpty,
        );
      },
    );
  }
  testWidgets(
    'GivenPendingOperation_WhenDisposed_ThenLateCompletionIsIgnored',
    (tester) async {
      final pending = Completer<ChimeraResult<ChecksumGenerateOutput>>();
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/checksum/generate',
          checksumGenerateService: _FakeService((_) => pending.future),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(_control('input'), 'secret');
      await tester.tap(_control('submit'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      pending.complete(
        await const ChecksumGenerateService().execute(
          ChecksumGenerateOperationRequest.text('abc'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'GivenCanceledFileAndClipboard_WhenInvoked_ThenPriorResultPreserved',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/checksum/generate',
          checksumGenerateFilePicker: () async => null,
          checksumGenerateClipboardReader: () async => null,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(_control('input'), 'abc');
      await _tap(tester, 'submit');
      await _tap(tester, 'file');
      await _tap(tester, 'paste');
      expect(_control('result'), findsOneWidget);
    },
  );
  testWidgets(
    'GivenNarrowPage_WhenRendered_ThenLabeledControlsFitAndNavigate',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const ChimeraApp(initialLocation: '/checksum/generate'),
      );
      await tester.pumpAndSettle();
      expect(_control('algorithm'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}Home_WhenChecksumOpened_ThenLocalizedRouteAvailable',
      (tester) async {
        await tester.pumpWidget(ChimeraApp(localeTag: locale));
        await tester.pumpAndSettle();
        final action = find.byKey(const Key('open-checksum-generate'));
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(_control('input'), findsOneWidget);
        expect(
          find.text(
            locale == 'en'
                ? 'Checksum algorithm'
                : 'Algoritmo da soma de verificação',
          ),
          findsOneWidget,
        );
      },
    );
    testWidgets(
      'Given${locale}Result_WhenAccessibilityChecked_ThenChecksumIsLabeledFocusedAndTargetsMeetGuidelines',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            ChimeraApp(
              localeTag: locale,
              initialLocation: '/checksum/generate',
            ),
          );
          await tester.pumpAndSettle();
          await tester.enterText(_control('input'), 'SECRET');
          await _tap(tester, 'submit');
          final result = tester.widget<Semantics>(_control('result'));
          expect(result.properties.liveRegion, isTrue);
          expect(
            result.properties.label,
            locale == 'en'
                ? 'Checksum result'
                : 'Resultado da soma de verificação',
          );
          expect(
            result.properties.value,
            contains(tester.widget<SelectableText>(_control('output')).data!),
          );
          expect(result.properties.value, isNot(contains('SECRET')));
          expect(
            FocusManager.instance.primaryFocus!.debugLabel,
            'Checksum generation result',
          );
          for (final name in [
            'file',
            'paste',
            'algorithm',
            'submit',
            'copy',
            'save',
          ]) {
            final size = tester.getSize(_control(name));
            expect(size.width, greaterThanOrEqualTo(48), reason: name);
            expect(size.height, greaterThanOrEqualTo(48), reason: name);
          }
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        } finally {
          semantics.dispose();
        }
      },
    );
  }
  testWidgets(
    'GivenKeyboardUser_WhenChecksumActivated_ThenInputAlgorithmResultCopyAndSaveFollowOrder',
    (tester) async {
      String? copied;
      var saves = 0;
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/checksum/generate',
          checksumGenerateClipboardWriter: (value) async => copied = value,
          checksumGenerateFileSaver: (_, _, _) async {
            saves++;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();
      for (final name in ['input', 'file', 'paste', 'algorithm', 'submit']) {
        if (name != 'input') {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
        }
        expect(
          find.ancestor(
            of: find.byWidget(
              FocusManager.instance.primaryFocus!.context!.widget,
            ),
            matching: _control(name),
          ),
          findsOneWidget,
          reason: name,
        );
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus!.debugLabel,
        'Checksum generation result',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(copied, checksumKnownVectors['empty']!['crc32']);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(saves, 1);
    },
  );
  testWidgets(
    'GivenPendingChecksum_WhenBusy_ThenInputAndDuplicateActionsDisabledUntilCompletion',
    (tester) async {
      final pending = Completer<ChimeraResult<ChecksumGenerateOutput>>();
      var calls = 0;
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/checksum/generate',
          checksumGenerateService: _FakeService((_) {
            calls++;
            return pending.future;
          }),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(_control('input'), 'PRIVATE');
      await tester.tap(_control('submit'));
      await tester.pump();
      expect(tester.widget<TextField>(_control('input')).enabled, isFalse);
      for (final name in ['file', 'paste']) {
        expect(tester.widget<OutlinedButton>(_control(name)).onPressed, isNull);
      }
      expect(
        tester.widget<ElevatedButton>(_control('submit')).onPressed,
        isNull,
      );
      expect(calls, 1);
      pending.complete(
        await const ChecksumGenerateService().execute(
          ChecksumGenerateOperationRequest.text('abc'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_control('input')).enabled, isTrue);
      expect(
        tester.widget<TextField>(_control('input')).controller!.text,
        isEmpty,
      );
      expect(
        tester.widget<SelectableText>(_control('output')).data,
        '352441c2',
      );
    },
  );
  for (final action in ['file', 'paste', 'copy', 'save']) {
    testWidgets(
      'GivenPending${action}Action_WhenDisposed_ThenLateCompletionCannotRestorePrivateState',
      (tester) async {
        final file = Completer<List<int>?>();
        final clipboard = Completer<String?>();
        final copy = Completer<void>();
        final save = Completer<bool>();
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/checksum/generate',
            checksumGenerateFilePicker: () => file.future,
            checksumGenerateClipboardReader: () => clipboard.future,
            checksumGenerateClipboardWriter: (_) => copy.future,
            checksumGenerateFileSaver: (_, _, _) => save.future,
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(_control('input'), 'PRIVATE');
        if (action == 'copy' || action == 'save') await _tap(tester, 'submit');
        await tester.ensureVisible(_control(action));
        await tester.tap(_control(action));
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
        switch (action) {
          case 'file':
            file.complete([0, 255]);
          case 'paste':
            clipboard.complete('PRIVATE');
          case 'copy':
            copy.complete();
          case 'save':
            save.complete(true);
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('PRIVATE'), findsNothing);
        expect(_control('result'), findsNothing);
      },
    );
  }
}
