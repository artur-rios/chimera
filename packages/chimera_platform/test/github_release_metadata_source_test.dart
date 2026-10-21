import 'dart:async';
import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/chimera_platform.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  final endpoint = Uri.parse(
    'https://api.github.com/repos/artur-rios/chimera/releases/latest',
  );
  final cliMetadataUri = Uri.parse(
    'https://github.com/artur-rios/chimera/releases/download/v1.2.0/'
    'chimera-cli-linux-x64.release.json',
  );
  final desktopMetadataUri = Uri.parse(
    'https://github.com/artur-rios/chimera/releases/download/v1.2.0/'
    'chimera-desktop-windows-x64.release.json',
  );
  final artifactUri = Uri.parse(
    'https://github.com/artur-rios/chimera/releases/download/v1.2.0/'
    'chimera-cli-linux-x64.tar.gz',
  );

  test(
    'GivenLatestRelease_WhenSidecarsExist_ThenFetchesEveryMetadataAssetOnly',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url == endpoint) {
          return http.Response(
            jsonEncode(
              _releasePayload(<Map<String, Object?>>[
                _asset('chimera-cli-linux-x64.release.json', cliMetadataUri),
                _asset(
                  'chimera-desktop-windows-x64.release.json',
                  desktopMetadataUri,
                ),
                _asset('chimera-cli-linux-x64.tar.gz', artifactUri),
              ]),
            ),
            200,
          );
        }
        if (request.url == cliMetadataUri) {
          return http.Response(jsonEncode(_cliMetadata), 200);
        }
        if (request.url == desktopMetadataUri) {
          return http.Response(jsonEncode(_desktopMetadata), 200);
        }
        return http.Response('artifact must not be requested', 500);
      });
      final source = GitHubReleaseMetadataSource(client: client);

      final result = await source.fetch(endpoint);

      expect(result, isA<ChimeraSuccess<List<Map<String, Object?>>>>());
      final values =
          (result as ChimeraSuccess<List<Map<String, Object?>>>).value;
      expect(values, <Map<String, Object?>>[_cliMetadata, _desktopMetadata]);
      expect(requests.map((request) => request.url), <Uri>[
        endpoint,
        cliMetadataUri,
        desktopMetadataUri,
      ]);
      for (final request in requests) {
        expect(request.headers['accept'], 'application/vnd.github+json');
        expect(request.headers['x-github-api-version'], '2022-11-28');
        expect(request.headers['user-agent'], 'Chimera-update-check');
      }
    },
  );

  test(
    'GivenTransportFailure_WhenChecking_ThenReturnsSafeUpdateFailure',
    () async {
      final source = GitHubReleaseMetadataSource(
        client: MockClient((request) => throw http.ClientException('secret')),
      );

      final result = await source.fetch(endpoint);

      _expectFailure(result, code: 'github-release-transport-failed');
    },
  );

  test(
    'GivenRequestTimeout_WhenChecking_ThenReturnsSafeUpdateFailure',
    () async {
      final client = _StallingClient();
      final source = GitHubReleaseMetadataSource(
        client: client,
        requestTimeout: const Duration(milliseconds: 10),
      );

      final result = await source.fetch(endpoint);

      _expectFailure(result, code: 'github-release-transport-failed');
      await expectLater(
        client.abortObserved.future.timeout(const Duration(seconds: 1)),
        completes,
      );
    },
  );

  test(
    'GivenNonSuccessStatus_WhenChecking_ThenReturnsSafeUpdateFailure',
    () async {
      final source = GitHubReleaseMetadataSource(
        client: MockClient(
          (request) async => http.Response('private body', 503),
        ),
      );

      final result = await source.fetch(endpoint);

      final failure = _expectFailure(
        result,
        code: 'github-release-request-failed',
      );
      expect(failure.details, <String, Object?>{'statusCode': 503});
      expect(failure.details.toString(), isNot(contains('private body')));
    },
  );

  for (final rejected in <({int statusCode, int? contentLength, String code})>[
    (
      statusCode: 503,
      contentLength: null,
      code: 'github-release-request-failed',
    ),
    (
      statusCode: 200,
      contentLength: 5,
      code: 'github-release-response-too-large',
    ),
  ]) {
    test(
      'GivenRejectedResponse${rejected.statusCode}_${rejected.contentLength}_WhenChecking_ThenResponseBodyIsCancelled',
      () async {
        final cancelled = Completer<void>();
        final controller = StreamController<List<int>>(
          onCancel: () {
            if (!cancelled.isCompleted) {
              cancelled.complete();
            }
          },
        );
        final source = GitHubReleaseMetadataSource(
          client: _SingleResponseClient(
            http.StreamedResponse(
              controller.stream,
              rejected.statusCode,
              contentLength: rejected.contentLength,
            ),
          ),
          maxReleaseResponseBytes: 4,
        );

        final result = await source.fetch(endpoint);

        _expectFailure(result, code: rejected.code);
        await expectLater(
          cancelled.future.timeout(const Duration(seconds: 1)),
          completes,
        );
      },
    );
  }

  test(
    'GivenMalformedReleaseJson_WhenChecking_ThenReturnsSafeUpdateFailure',
    () async {
      final source = GitHubReleaseMetadataSource(
        client: MockClient((request) async => http.Response('{', 200)),
      );

      final result = await source.fetch(endpoint);

      _expectFailure(result, code: 'invalid-github-release-payload');
    },
  );

  test(
    'GivenInvalidReleaseShape_WhenChecking_ThenReturnsSafeUpdateFailure',
    () async {
      final source = GitHubReleaseMetadataSource(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(<String, Object?>{
              'draft': false,
              'prerelease': false,
              'assets': 'not-a-list',
            }),
            200,
          ),
        ),
      );

      final result = await source.fetch(endpoint);

      _expectFailure(result, code: 'invalid-github-release-payload');
    },
  );

  test(
    'GivenMissingMetadataAssets_WhenChecking_ThenReturnsSafeUpdateFailure',
    () async {
      final source = GitHubReleaseMetadataSource(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(
              _releasePayload(<Map<String, Object?>>[
                _asset('chimera-cli-linux-x64.tar.gz', artifactUri),
              ]),
            ),
            200,
          ),
        ),
      );

      final result = await source.fetch(endpoint);

      _expectFailure(result, code: 'release-metadata-assets-missing');
    },
  );

  test(
    'GivenSidecarHttpFailure_WhenChecking_ThenReturnsSafeUpdateFailure',
    () async {
      final source = GitHubReleaseMetadataSource(
        client: MockClient((request) async {
          if (request.url == endpoint) {
            return http.Response(
              jsonEncode(
                _releasePayload(<Map<String, Object?>>[
                  _asset('chimera-cli-linux-x64.release.json', cliMetadataUri),
                ]),
              ),
              200,
            );
          }
          return http.Response('secret metadata error', 404);
        }),
      );

      final result = await source.fetch(endpoint);

      final failure = _expectFailure(
        result,
        code: 'release-metadata-request-failed',
      );
      expect(failure.details, <String, Object?>{'statusCode': 404});
      expect(
        failure.details.toString(),
        isNot(contains('secret metadata error')),
      );
    },
  );

  test(
    'GivenMalformedSidecar_WhenChecking_ThenReturnsSafeUpdateFailure',
    () async {
      final source = GitHubReleaseMetadataSource(
        client: MockClient((request) async {
          if (request.url == endpoint) {
            return http.Response(
              jsonEncode(
                _releasePayload(<Map<String, Object?>>[
                  _asset('chimera-cli-linux-x64.release.json', cliMetadataUri),
                ]),
              ),
              200,
            );
          }
          return http.Response(
            jsonEncode(<Object?>['not', 'an', 'object']),
            200,
          );
        }),
      );

      final result = await source.fetch(endpoint);

      _expectFailure(result, code: 'invalid-release-metadata-payload');
    },
  );

  test(
    'GivenOversizedRelease_WhenChecking_ThenReturnsSafeUpdateFailure',
    () async {
      final source = GitHubReleaseMetadataSource(
        client: MockClient((request) async => http.Response('12345', 200)),
        maxReleaseResponseBytes: 4,
      );

      final result = await source.fetch(endpoint);

      _expectFailure(result, code: 'github-release-response-too-large');
    },
  );

  test(
    'GivenOversizedSidecar_WhenChecking_ThenReturnsSafeUpdateFailure',
    () async {
      final source = GitHubReleaseMetadataSource(
        client: MockClient((request) async {
          if (request.url == endpoint) {
            return http.Response(
              jsonEncode(
                _releasePayload(<Map<String, Object?>>[
                  _asset('chimera-cli-linux-x64.release.json', cliMetadataUri),
                ]),
              ),
              200,
            );
          }
          return http.Response(jsonEncode(_cliMetadata), 200);
        }),
        maxMetadataResponseBytes: 4,
      );

      final result = await source.fetch(endpoint);

      _expectFailure(result, code: 'release-metadata-response-too-large');
    },
  );

  test(
    'GivenTooManySidecars_WhenChecking_ThenFailsBeforeFetchingAny',
    () async {
      final requests = <Uri>[];
      final source = GitHubReleaseMetadataSource(
        client: MockClient((request) async {
          requests.add(request.url);
          return http.Response(
            jsonEncode(
              _releasePayload(<Map<String, Object?>>[
                _asset('first.release.json', cliMetadataUri),
                _asset('second.release.json', desktopMetadataUri),
              ]),
            ),
            200,
          );
        }),
        maxMetadataAssets: 1,
      );

      final result = await source.fetch(endpoint);

      _expectFailure(result, code: 'too-many-release-metadata-assets');
      expect(requests, <Uri>[endpoint]);
    },
  );

  test('GivenNonGithubSidecarUrl_WhenChecking_ThenDoesNotRequestIt', () async {
    final requests = <Uri>[];
    final unsafeUri = Uri.parse('https://example.com/metadata.release.json');
    final source = GitHubReleaseMetadataSource(
      client: MockClient((request) async {
        requests.add(request.url);
        return http.Response(
          jsonEncode(
            _releasePayload(<Map<String, Object?>>[
              _asset('metadata.release.json', unsafeUri),
            ]),
          ),
          200,
        );
      }),
    );

    final result = await source.fetch(endpoint);

    _expectFailure(result, code: 'invalid-github-release-payload');
    expect(requests, <Uri>[endpoint]);
  });
}

const Map<String, Object?> _cliMetadata = <String, Object?>{
  'releaseVersion': '1.2.0',
  'platform': 'linux',
  'application': 'cli',
  'packageType': 'installer',
  'downloadUrl':
      'https://github.com/artur-rios/chimera/releases/download/'
      'v1.2.0/chimera-cli-linux-x64.tar.gz',
  'checksum':
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
};

const Map<String, Object?> _desktopMetadata = <String, Object?>{
  'releaseVersion': '1.2.0',
  'platform': 'windows',
  'application': 'desktop',
  'packageType': 'installer',
  'downloadUrl':
      'https://github.com/artur-rios/chimera/releases/download/'
      'v1.2.0/chimera-desktop-windows-x64.zip',
  'checksum':
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
};

Map<String, Object?> _releasePayload(List<Map<String, Object?>> assets) =>
    <String, Object?>{
      'tag_name': 'v1.2.0',
      'draft': false,
      'prerelease': false,
      'assets': assets,
    };

Map<String, Object?> _asset(String name, Uri url) => <String, Object?>{
  'name': name,
  'browser_download_url': url.toString(),
};

ChimeraFailure<List<Map<String, Object?>>> _expectFailure(
  ChimeraResult<List<Map<String, Object?>>> result, {
  required String code,
}) {
  expect(result, isA<ChimeraFailure<List<Map<String, Object?>>>>());
  final failure = result as ChimeraFailure<List<Map<String, Object?>>>;
  expect(failure.kind, FailureKind.update);
  expect(failure.code, code);
  expect(failure.messageKey, 'error.update.checkFailed');
  return failure;
}

final class _StallingClient extends http.BaseClient {
  final Completer<void> abortObserved = Completer<void>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request case http.AbortableRequest(:final abortTrigger?)) {
      abortTrigger.then((_) {
        if (!abortObserved.isCompleted) {
          abortObserved.complete();
        }
      });
    }
    return Completer<http.StreamedResponse>().future;
  }
}

final class _SingleResponseClient extends http.BaseClient {
  _SingleResponseClient(this.response);

  final http.StreamedResponse response;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      response;
}
