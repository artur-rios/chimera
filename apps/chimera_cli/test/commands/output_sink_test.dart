import 'dart:async';
import 'dart:io';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:test/test.dart';

final class _FailingConsumer implements StreamConsumer<List<int>> {
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final _ in stream) {}
    await Future<void>.delayed(Duration.zero);
    throw const FileSystemException('PRIVATE');
  }

  @override
  Future<void> close() async {}
}

final class _ControlledSink implements IOSink {
  final doneCompletion = Completer<void>();
  final flushCompletion = Completer<void>();
  final payload = StringBuffer();
  @override
  Future<void> get done => doneCompletion.future;
  @override
  Future<void> flush() => flushCompletion.future;
  @override
  void write(Object? object) => payload.write(object);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final timing in ['prior', 'late']) {
    test(
      'Given${timing}DoneError_WhenFlushRemainsPending_ThenWriteRejectsWithoutUnhandledError',
      () async {
        final sink = _ControlledSink();
        const failure = FileSystemException('PRIVATE');
        if (timing == 'prior') {
          sink.doneCompletion.completeError(failure);
        }
        final writing = writeSinkAndFlush(sink, 'PRIVATE');
        final expectation = expectLater(
          writing.timeout(const Duration(seconds: 5)),
          throwsA(same(failure)),
        );
        if (timing == 'late') {
          sink.doneCompletion.completeError(failure);
        }
        await expectation;
        sink.flushCompletion.complete();
      },
    );
  }

  test('GivenFlushError_WhenDoneRemainsPending_ThenWriterRejectsWithoutWaitingForClose', () async {
    final sink = _ControlledSink();
    const failure = FileSystemException('PRIVATE');
    final writing = writeSinkAndFlush(sink, 'PRIVATE');
    final expectation = expectLater(
      writing.timeout(const Duration(seconds: 5)),
      throwsA(same(failure)),
    );
    sink.flushCompletion.completeError(failure);
    await expectation;
    sink.doneCompletion.complete();
  });

  test('GivenAsyncIoSinkFailure_WhenOutputFlushed_ThenErrorReturnedWithoutUnhandledDone', () async {
    final sink = IOSink(_FailingConsumer());
    await expectLater(
      writeSinkAndFlush(sink, 'PRIVATE'),
      throwsA(isA<FileSystemException>()),
    );
    try {
      await sink.close();
    } on FileSystemException {
      /* The shared writer already observed the sink's done error. */
    }
  });
  test('GivenStringBuffer_WhenAwaitedWriterRuns_ThenExactPayloadWithoutIoAssumptions', () async {
    final out = StringBuffer();
    await writeSinkAndFlush(out, 'exact\n');
    expect(out.toString(), 'exact\n');
  });
}
