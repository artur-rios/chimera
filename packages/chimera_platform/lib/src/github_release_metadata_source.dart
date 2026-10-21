import 'dart:async';
import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:http/http.dart' as http;

final class GitHubReleaseMetadataSource implements ReleaseMetadataSource {
  GitHubReleaseMetadataSource({
    http.Client? client,
    this.maxReleaseResponseBytes = 1024 * 1024,
    this.maxMetadataResponseBytes = 256 * 1024,
    this.maxMetadataAssets = 64,
    this.requestTimeout = const Duration(seconds: 15),
  }) : assert(maxReleaseResponseBytes > 0),
       assert(maxMetadataResponseBytes > 0),
       assert(maxMetadataAssets > 0),
       assert(requestTimeout > Duration.zero),
       // Keep the injected client private while retaining a descriptive
       // public constructor parameter.
       // ignore: prefer_initializing_formals
       _client = client ?? http.Client();

  static const Map<String, String> _headers = <String, String>{
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'Chimera-update-check',
  };

  final http.Client _client;
  final int maxReleaseResponseBytes;
  final int maxMetadataResponseBytes;
  final int maxMetadataAssets;
  final Duration requestTimeout;

  @override
  Future<ChimeraResult<List<Map<String, Object?>>>> fetch(Uri endpoint) async {
    final releaseResponse = await _getJson(
      endpoint,
      maxBytes: maxReleaseResponseBytes,
      requestFailureCode: 'github-release-request-failed',
      transportFailureCode: 'github-release-transport-failed',
      oversizedFailureCode: 'github-release-response-too-large',
      invalidFailureCode: 'invalid-github-release-payload',
    );
    if (releaseResponse.failure case final failure?) {
      return _failure(failure.code, failure.details);
    }

    final metadataUris = _metadataUris(releaseResponse.value);
    if (metadataUris == null) {
      return _failure('invalid-github-release-payload');
    }
    if (metadataUris.isEmpty) {
      return _failure('release-metadata-assets-missing');
    }
    if (metadataUris.length > maxMetadataAssets) {
      return _failure('too-many-release-metadata-assets');
    }

    final metadata = <Map<String, Object?>>[];
    for (final uri in metadataUris) {
      final metadataResponse = await _getJson(
        uri,
        maxBytes: maxMetadataResponseBytes,
        requestFailureCode: 'release-metadata-request-failed',
        transportFailureCode: 'github-release-transport-failed',
        oversizedFailureCode: 'release-metadata-response-too-large',
        invalidFailureCode: 'invalid-release-metadata-payload',
      );
      if (metadataResponse.failure case final failure?) {
        return _failure(failure.code, failure.details);
      }
      final value = metadataResponse.value;
      if (value is! Map<String, Object?>) {
        return _failure('invalid-release-metadata-payload');
      }
      metadata.add(Map<String, Object?>.from(value));
    }
    return ChimeraSuccess<List<Map<String, Object?>>>(metadata);
  }

  List<Uri>? _metadataUris(Object? value) {
    if (value is! Map<String, Object?> ||
        value['tag_name'] is! String ||
        (value['tag_name']! as String).isEmpty ||
        value['draft'] != false ||
        value['prerelease'] != false ||
        value['assets'] is! List<Object?>) {
      return null;
    }
    final uris = <Uri>[];
    for (final asset in value['assets']! as List<Object?>) {
      if (asset is! Map<String, Object?> ||
          asset['name'] is! String ||
          asset['browser_download_url'] is! String) {
        return null;
      }
      final name = asset['name']! as String;
      final uri = Uri.tryParse(asset['browser_download_url']! as String);
      if (name.isEmpty ||
          uri == null ||
          uri.scheme != 'https' ||
          uri.host != 'github.com') {
        return null;
      }
      if (name.endsWith('.release.json')) {
        uris.add(uri);
      }
    }
    return uris;
  }

  Future<_JsonResponse> _getJson(
    Uri uri, {
    required int maxBytes,
    required String requestFailureCode,
    required String transportFailureCode,
    required String oversizedFailureCode,
    required String invalidFailureCode,
  }) {
    final abort = Completer<void>();
    return _getJsonWithoutTimeout(
      uri,
      abortTrigger: abort.future,
      maxBytes: maxBytes,
      requestFailureCode: requestFailureCode,
      transportFailureCode: transportFailureCode,
      oversizedFailureCode: oversizedFailureCode,
      invalidFailureCode: invalidFailureCode,
    ).timeout(
      requestTimeout,
      onTimeout: () {
        abort.complete();
        return _JsonResponse.failure(transportFailureCode);
      },
    );
  }

  Future<_JsonResponse> _getJsonWithoutTimeout(
    Uri uri, {
    required Future<void> abortTrigger,
    required int maxBytes,
    required String requestFailureCode,
    required String transportFailureCode,
    required String oversizedFailureCode,
    required String invalidFailureCode,
  }) async {
    final http.StreamedResponse response;
    try {
      final request = http.AbortableRequest(
        'GET',
        uri,
        abortTrigger: abortTrigger,
      )..headers.addAll(_headers);
      response = await _client.send(request);
    } on Object {
      return _JsonResponse.failure(transportFailureCode);
    }
    if (response.statusCode != 200) {
      await _cancelResponseBody(response);
      return _JsonResponse.failure(requestFailureCode, <String, Object?>{
        'statusCode': response.statusCode,
      });
    }
    if (response.contentLength case final contentLength?
        when contentLength > maxBytes) {
      await _cancelResponseBody(response);
      return _JsonResponse.failure(oversizedFailureCode);
    }

    final bytes = <int>[];
    try {
      await for (final chunk in response.stream) {
        if (bytes.length + chunk.length > maxBytes) {
          return _JsonResponse.failure(oversizedFailureCode);
        }
        bytes.addAll(chunk);
      }
    } on Object {
      return _JsonResponse.failure(transportFailureCode);
    }

    try {
      return _JsonResponse.success(
        jsonDecode(utf8.decode(bytes, allowMalformed: false)),
      );
    } on FormatException {
      return _JsonResponse.failure(invalidFailureCode);
    }
  }

  Future<void> _cancelResponseBody(http.StreamedResponse response) async {
    try {
      await response.stream.listen((_) {}).cancel();
    } on Object {
      // The rejection result is authoritative; cancellation failures must not
      // expose transport details or replace it.
    }
  }

  ChimeraFailure<List<Map<String, Object?>>> _failure(
    String code, [
    Map<String, Object?> details = const <String, Object?>{},
  ]) => ChimeraFailure<List<Map<String, Object?>>>(
    kind: FailureKind.update,
    code: code,
    messageKey: 'error.update.checkFailed',
    details: details,
  );
}

final class _JsonResponse {
  const _JsonResponse.success(this.value) : failure = null;

  const _JsonResponse.failure(
    String code, [
    Map<String, Object?> details = const <String, Object?>{},
  ]) : value = null,
       failure = (code: code, details: details);

  final Object? value;
  final ({String code, Map<String, Object?> details})? failure;
}
