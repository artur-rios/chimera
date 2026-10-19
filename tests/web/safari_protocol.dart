import 'dart:async';

import 'package:webdriver/async_core.dart' as core;
import 'package:webdriver/async_io.dart' hide TimeoutException;
// The exported AsyncIoRequestClient override uses these non-exported types.
// ignore: implementation_imports
import 'package:webdriver/src/common/request.dart';

/// Bounded transport and payload-free progress for the local Safari harness.
final class SafariProtocol {
  SafariProtocol({
    required this.record,
    this.commandTimeout = const Duration(seconds: 30),
  });

  final void Function(Map<String, Object?> event) record;
  final Duration commandTimeout;
  final _clients = <AsyncIoRequestClient>[];
  int _sequence = 0;
  String _stage = 'session creation';
  Object? _transportFailure;

  bool get failed => _transportFailure != null;

  static final _deadlineKey = Object();

  static Future<T> withinDeadline<T>(
    DateTime deadline,
    Future<T> Function() operation,
  ) => runZoned(operation, zoneValues: {_deadlineKey: deadline});

  Future<WebDriver> connect(Uri uri) => core.createDriver(
    (prefix) {
      final client = _SafariRequestClient(prefix, this);
      _clients.add(client);
      return client;
    },
    uri: uri,
    desired: <String, dynamic>{Capabilities.browserName: Browser.safari},
    spec: WebDriverSpec.W3c,
  );

  Future<T> stage<T>(String name, Future<T> Function() operation) async {
    final previous = _stage;
    _stage = name;
    final watch = Stopwatch()..start();
    record({'kind': 'stage-start', 'stage': name});
    try {
      final result = await operation();
      record({
        'kind': 'stage-end',
        'stage': name,
        'elapsedMs': watch.elapsedMilliseconds,
      });
      return result;
    } on Object catch (error) {
      record({
        'kind': 'stage-error',
        'stage': name,
        'elapsedMs': watch.elapsedMilliseconds,
        'errorType': '${error.runtimeType}',
      });
      rethrow;
    } finally {
      _stage = previous;
    }
  }

  void close() {
    for (final client in _clients) {
      client.close();
    }
  }

  void _failTransport(Object error) {
    _transportFailure ??= error;
    close();
  }
}

final class _SafariRequestClient extends AsyncIoRequestClient {
  _SafariRequestClient(super.prefix, this.protocol) {
    client.connectionTimeout = protocol.commandTimeout;
  }

  final SafariProtocol protocol;

  @override
  Future<WebDriverResponse> sendRaw(WebDriverRequest request) async {
    if (protocol._transportFailure case final failure?) throw failure;
    final id = ++protocol._sequence;
    final context = <String, Object?>{
      'id': id,
      'stage': protocol._stage,
      'method': request.method?.name,
      'endpoint': request.uri,
    };
    final watch = Stopwatch()..start();
    protocol.record({'kind': 'rpc-start', ...context});
    final deadline = Zone.current[SafariProtocol._deadlineKey] as DateTime?;
    final remaining = deadline?.difference(DateTime.now());
    final timeout = remaining != null && remaining < protocol.commandTimeout
        ? (remaining.isNegative ? Duration.zero : remaining)
        : protocol.commandTimeout;
    final pending = super.sendRaw(request);
    try {
      final response = await pending.timeout(timeout);
      protocol.record({
        'kind': 'rpc-end',
        ...context,
        'elapsedMs': watch.elapsedMilliseconds,
        'status': response.statusCode,
      });
      return response;
    } on Object catch (error) {
      final failure = error is TimeoutException
          ? TimeoutException(
              'Safari RPC $id ${request.method?.name} ${request.uri} '
              'during ${protocol._stage}',
              timeout,
            )
          : error;
      protocol.record({
        'kind': 'rpc-error',
        ...context,
        'elapsedMs': watch.elapsedMilliseconds,
        'errorType': '${failure.runtimeType}',
        'deadlineMs': timeout.inMilliseconds,
      });
      // Abort the socket, then reap the original operation. Do not leave an
      // unbounded SDK request alive behind Future.timeout or queue another RPC.
      protocol._failTransport(failure);
      try {
        await pending;
      } on Object {
        // The primary transport error above is the useful failure.
      }
      throw failure;
    }
  }
}
