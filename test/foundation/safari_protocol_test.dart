import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:webdriver/async_io.dart' hide TimeoutException;

import '../../tests/web/safari_protocol.dart';

void main() {
  late HttpServer server;
  late SafariProtocol protocol;
  late List<Map<String, Object?>> events;
  late List<Map<String, dynamic>> bodies;
  late Future<void> Function(HttpRequest) respond;
  late WebDriver driver;

  Future<void> reply(
    HttpRequest request,
    Object? value, {
    int status = 200,
  }) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'value': value}));
    await request.response.close();
  }

  setUp(() async {
    events = [];
    bodies = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    respond = (request) => reply(request, 'exact result');
    server.listen((request) async {
      final body = await utf8.decodeStream(request);
      bodies.add(body.isEmpty ? {} : jsonDecode(body) as Map<String, dynamic>);
      if (request.uri.path == '/session') {
        await reply(request, {
          'sessionId': 'fixture',
          'capabilities': <String, Object?>{},
        });
      } else {
        await respond(request);
      }
    });
    protocol = SafariProtocol(
      record: events.add,
      commandTimeout: const Duration(seconds: 2),
    );
    driver = await protocol.connect(
      Uri.parse('http://127.0.0.1:${server.port}/'),
    );
  });

  tearDown(() async {
    protocol.close();
    await server.close(force: true);
  });

  test(
    'GivenLiveDriver_WhenScriptRuns_ThenExactTransportAndMetadataOnly',
    () async {
      const script = 'return "private fixture";';
      final value = await protocol.stage(
        'save setup',
        () => driver.execute(script, ['private argument']),
      );
      expect(value, 'exact result');
      expect(bodies.last, {
        'script': script,
        'args': ['private argument'],
      });
      expect(
        events.where((e) => e['kind'] == 'rpc-start').last,
        containsPair('stage', 'save setup'),
      );
      expect(
        events.where((e) => e['kind'] == 'rpc-end').last,
        containsPair('status', 200),
      );
      final trace = jsonEncode(events);
      for (final secret in [script, 'private argument', 'exact result']) {
        expect(trace, isNot(contains(secret)));
      }
      expect(protocol.failed, isFalse);
      await driver.quit();
    },
  );

  for (final partialBody in [false, true]) {
    test(
      'GivenStalled${partialBody ? 'Body' : 'Headers'}_WhenPollingDeadlineExpires_ThenAbortReapAndNoQueuedCleanup',
      () async {
        final received = Completer<void>();
        respond = (request) async {
          // Observe the close without leaving an unhandled response error.
          unawaited(
            request.response.done.then<void>((_) {}, onError: (Object _) {}),
          );
          if (partialBody) {
            request.response.headers.contentType = ContentType.json;
            request.response.write('{"value":');
            await request.response.flush();
          }
          received.complete();
          // The real HTTP response intentionally never finishes.
        };
        final deadline = DateTime.now().add(const Duration(milliseconds: 250));
        final pending = SafariProtocol.withinDeadline(
          deadline,
          () => protocol.stage(
            'save activation',
            () => driver.execute('fixture', []),
          ),
        );
        final assertion = expectLater(
          pending,
          throwsA(
            isA<TimeoutException>()
                .having(
                  (e) => e.duration,
                  'remaining polling budget',
                  lessThanOrEqualTo(const Duration(milliseconds: 250)),
                )
                .having((e) => e.message, 'stage', contains('save activation')),
          ),
        );
        await received.future;
        await assertion; // Includes reaping the original SDK operation after abort.
        expect(protocol.failed, isTrue);
        expect(bodies, hasLength(2)); // Session + one command; never a retry.
        expect(events.where((e) => e['kind'] == 'rpc-error'), hasLength(1));
        await expectLater(
          driver.execute('diagnostic', []),
          throwsA(isA<TimeoutException>()),
        );
        await expectLater(driver.quit(), throwsA(isA<TimeoutException>()));
        expect(bodies, hasLength(2));
        expect(events.where((e) => e['kind'] == 'rpc-start'), hasLength(2));
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );
  }

  test(
    'GivenStalledNavigation_WhenNoPollingBudget_ThenCommandDeadlineAborts',
    () async {
      respond = (request) async {
        unawaited(
          request.response.done.then<void>((_) {}, onError: (Object _) {}),
        );
      };
      await expectLater(
        driver.get('http://public-fixture.invalid/'),
        throwsA(
          isA<TimeoutException>().having(
            (e) => e.duration,
            'command budget',
            const Duration(seconds: 2),
          ),
        ),
      );
      expect(protocol.failed, isTrue);
      expect(bodies, hasLength(2));
      expect(events.last['endpoint'], 'url');
    },
    timeout: const Timeout(Duration(seconds: 5)),
  );

  test(
    'GivenDriverError_WhenCommandRejected_ThenNoRetryAndNextCommandWorks',
    () async {
      respond = (request) => reply(request, {
        'error': 'invalid argument',
        'message': 'fixture rejection',
        'stacktrace': '',
      }, status: 400);
      await expectLater(
        driver.execute('rejected', []),
        throwsA(isA<WebDriverException>()),
      );
      expect(protocol.failed, isFalse);
      expect(bodies, hasLength(2));
      respond = (request) => reply(request, 'recovered');
      expect(await driver.execute('next', []), 'recovered');
      expect(bodies, hasLength(3));
    },
  );
}
