import 'dart:async';
import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../tests/fixtures/hashes/vectors.dart';

Finder _control(String value) => find.byKey(Key('hash-generate-$value'));
Future<void> _tap(WidgetTester tester, String value) async {
  await tester.ensureVisible(_control(value));
  await tester.tap(_control(value));
  await tester.pumpAndSettle();
}

final class _FakeService
    implements
        OperationService<HashGenerateOperationRequest, HashGenerateOutput> {
  _FakeService(this.callback);
  final Future<ChimeraResult<HashGenerateOutput>> Function(
    HashGenerateOperationRequest,
  )
  callback;
  @override
  Future<ChimeraResult<HashGenerateOutput>> execute(
    HashGenerateOperationRequest request,
  ) => callback(request);
}

void main() {
  for (final locale in ['en', 'pt-BR']) {
    for (final algorithm in ['sha256', 'sha384', 'sha512', 'md5', 'sha1']) {
      for (final source in ['text', 'file', 'paste']) {
        testWidgets(
          'Given$locale$algorithm${source}_WhenGeneratedCopiedSaved_ThenExactDigestAndWarning',
          (tester) async {
            String? copied;
            String? saved;
            await tester.pumpWidget(
              ChimeraApp(
                localeTag: locale,
                initialLocation: '/hash/generate',
                hashGenerateFilePicker: () async => [97, 98, 99],
                hashGenerateClipboardReader: () async => 'abc',
                hashGenerateClipboardWriter: (v) async => copied = v,
                hashGenerateFileSaver: (name, bytes, mime) async {
                  expect(name, 'chimera-hash.txt');
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
            if (algorithm != 'sha256') {
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
            final legacy = ['md5', 'sha1'].contains(algorithm);
            expect(_control('warning'), legacy ? findsOneWidget : findsNothing);
            if (legacy) {
              expect(
                find.textContaining(
                  locale == 'en'
                      ? 'unsuitable for security decisions'
                      : 'inadequados para decisões de segurança',
                ),
                findsOneWidget,
              );
            }
            final digest = tester
                .widget<SelectableText>(_control('output'))
                .data!;
            expect(digest, hashKnownVectors['abc']![algorithm]);
            await _tap(tester, 'copy');
            expect(copied, digest);
            await _tap(tester, 'save');
            expect(saved, '$digest\n');
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
                initialLocation: '/hash/generate',
                hashGenerateFilePicker: () async => fail(),
                hashGenerateClipboardReader: () async => fail(),
                hashGenerateClipboardWriter: (_) async => fail(),
                hashGenerateFileSaver: (_, _, _) async => fail(),
                hashGenerateService: action == 'submit'
                    ? _FakeService((_) async => fail())
                    : const HashGenerateService(),
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
            initialLocation: '/hash/generate',
            hashGenerateFilePicker: () async => [0, 255],
            hashGenerateClipboardReader: () async => 'replacement',
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
      final pending = Completer<ChimeraResult<HashGenerateOutput>>();
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/hash/generate',
          hashGenerateService: _FakeService((_) => pending.future),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(_control('input'), 'secret');
      await tester.tap(_control('submit'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      pending.complete(
        await const HashGenerateService().execute(
          HashGenerateOperationRequest.text('abc'),
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
          initialLocation: '/hash/generate',
          hashGenerateFilePicker: () async => null,
          hashGenerateClipboardReader: () async => null,
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
        const ChimeraApp(initialLocation: '/hash/generate'),
      );
      await tester.pumpAndSettle();
      expect(_control('algorithm'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}Home_WhenHashOpened_ThenLocalizedRouteAvailable',
      (tester) async {
        await tester.pumpWidget(ChimeraApp(localeTag: locale));
        await tester.pumpAndSettle();
        final action = find.byKey(const Key('open-hash-generate'));
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(_control('input'), findsOneWidget);
        expect(
          find.text(locale == 'en' ? 'Hash algorithm' : 'Algoritmo de hash'),
          findsOneWidget,
        );
      },
    );
    testWidgets(
      'Given${locale}Result_WhenAccessibilityChecked_ThenDigestIsLabeledFocusedAndTargetsMeetGuidelines',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            ChimeraApp(localeTag: locale, initialLocation: '/hash/generate'),
          );
          await tester.pumpAndSettle();
          await tester.enterText(_control('input'), 'SECRET');
          await _tap(tester, 'submit');
          final result = tester.widget<Semantics>(_control('result'));
          expect(result.properties.liveRegion, isTrue);
          expect(
            result.properties.label,
            locale == 'en' ? 'Hash result' : 'Resultado do hash',
          );
          expect(
            result.properties.value,
            contains(tester.widget<SelectableText>(_control('output')).data!),
          );
          expect(result.properties.value, isNot(contains('SECRET')));
          expect(
            FocusManager.instance.primaryFocus!.debugLabel,
            'Hash generation result',
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
    'GivenKeyboardUser_WhenHashActivated_ThenInputAlgorithmResultCopyAndSaveFollowOrder',
    (tester) async {
      String? copied;
      var saves = 0;
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/hash/generate',
          hashGenerateClipboardWriter: (value) async => copied = value,
          hashGenerateFileSaver: (_, _, _) async {
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
        'Hash generation result',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(copied, hashKnownVectors['empty']!['sha256']);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(saves, 1);
    },
  );
}
