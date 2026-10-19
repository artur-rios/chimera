import 'dart:async';
import 'dart:io';

/// Await accepted output before reporting success, without closing caller sinks.
///
/// Observe done before writing and race its failure with flush: a sink may fail
/// while flush is still pending. Both futures map failures to data so the other
/// completion cannot emit an unhandled asynchronous error after this returns.
Future<void> writeSinkAndFlush(StringSink sink, String payload) async {
  if (sink is! IOSink) {
    sink.write(payload);
    return;
  }
  _SinkFailure? doneFailure;
  final done = sink.done.then<_SinkFailure?>(
    (_) => null,
    onError: (Object error, StackTrace stack) {
      doneFailure = _SinkFailure(error, stack);
      return doneFailure;
    },
  );
  sink.write(payload);
  final flushed = Future<void>.sync(sink.flush).then<_SinkFailure?>(
    (_) => null,
    onError: (Object error, StackTrace stack) => _SinkFailure(error, stack),
  );
  final first = await Future.any([done, flushed]);
  if (first != null) first.raise();
  // A normally completed done must not hide a pending/failed flush.
  final flushFailure = await flushed;
  if (flushFailure != null) flushFailure.raise();
  doneFailure?.raise();
}

final class _SinkFailure {
  const _SinkFailure(this.error, this.stack);
  final Object error;
  final StackTrace stack;
  Never raise() => Error.throwWithStackTrace(error, stack);
}
