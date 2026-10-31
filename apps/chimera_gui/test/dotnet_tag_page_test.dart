import 'dart:async';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/dotnet_tag_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'GivenTagForm${locale}_WhenCreated_ThenPushDefaultsOffAndLocalResultShown',
      (tester) async {
        final service = _Service();
        await tester.pumpWidget(
          MaterialApp(
            home: DotnetTagPage(localeTag: locale, service: service),
          ),
        );
        await tester.enterText(
          find.byKey(const Key('dotnet-tag-project')),
          '/repo/src',
        );
        await tester.tap(find.byKey(const Key('dotnet-tag-create')));
        await tester.pumpAndSettle();
        expect(service.request!.push, isFalse);
        expect(service.request!.project, '/repo/src');
        expect(find.textContaining('v1.2.3'), findsOneWidget);
        final status = find.semantics.byLabel(RegExp(r'v1\.2\.3'));
        expect(status, findsOne);
        expect(
          status.evaluate().single,
          isSemantics(isLiveRegion: true, isTextField: false),
        );
      },
    );
    testWidgets(
      'GivenPushFailure${locale}_WhenTagCreated_ThenRetainedTagAndRemoteFailureAreVisible',
      (tester) async {
        final service = _Service(fail: true);
        await tester.pumpWidget(
          MaterialApp(
            home: DotnetTagPage(localeTag: locale, service: service),
          ),
        );
        await tester.tap(find.byKey(const Key('dotnet-tag-push')));
        await tester.tap(find.byKey(const Key('dotnet-tag-create')));
        await tester.pumpAndSettle();
        expect(service.request!.push, isTrue);
        expect(
          find.textContaining(locale == 'en' ? 'retained' : 'mantida'),
          findsOneWidget,
        );
        expect(find.textContaining('v1.2.3'), findsOneWidget);
      },
    );
  }
  testWidgets('GivenPendingOperation_WhenDisposed_ThenOperationIsCancelled', (
    tester,
  ) async {
    final service = _Service(pending: true);
    await tester.pumpWidget(MaterialApp(home: DotnetTagPage(service: service)));
    await tester.tap(find.byKey(const Key('dotnet-tag-create')));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(service.cancellation!.isCancelled, isTrue);
    service.completion.complete(
      const ChimeraFailure(
        kind: FailureKind.processing,
        code: 'dotnetTag.cancelled',
        messageKey: 'error.dotnetTag.cancelled',
      ),
    );
  });
}

final class _Service implements DotnetTagOperationService {
  _Service({this.fail = false, this.pending = false});
  final bool fail, pending;
  DotnetTagRequest? request;
  OperationCancellation? cancellation;
  final completion = Completer<ChimeraResult<DotnetTagOutput>>();
  @override
  Future<ChimeraResult<DotnetTagOutput>> execute(
    DotnetTagRequest value, {
    OperationCancellation? cancellation,
  }) async {
    request = value;
    this.cancellation = cancellation;
    if (pending) return completion.future;
    if (fail) {
      return const ChimeraFailure(
        kind: FailureKind.processing,
        code: 'dotnetTag.pushFailed',
        messageKey: 'error.dotnetTag.pushFailed',
        details: {'tag': 'v1.2.3', 'localCreated': true},
      );
    }
    return ChimeraSuccess(
      DotnetTagOutput(
        project: '/repo/src/Library.csproj',
        tag: 'v1.2.3',
        pushed: value.push,
        remote: value.remote,
      ),
    );
  }
}
