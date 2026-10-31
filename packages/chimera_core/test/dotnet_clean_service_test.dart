import 'package:chimera_core/chimera_core.dart';
import 'package:test/test.dart';

final class _Gateway implements DotnetCleanGateway {
  bool invalidRoot = false;
  bool failDelete = false;
  int deleted = 0;
  @override
  Future<String> resolveRoot(String? root) async {
    if (invalidRoot) throw StateError('invalid');
    return '/src';
  }

  @override
  Future<List<String>> discover(String root) async => ['/src/bin', '/src/obj'];
  @override
  Future<void> validateRoot(String root) async {
    if (invalidRoot) throw StateError('changed');
  }

  @override
  Future<void> deleteArtifact(String root, String path) async {
    if (failDelete && path.endsWith('bin')) throw StateError('locked');
    deleted++;
  }
}

void main() {
  late _Gateway gateway;
  late DotnetCleanService service;
  setUp(() {
    gateway = _Gateway();
    service = DotnetCleanService(gateway);
  });
  Future<DotnetCleanPreview> preview() async =>
      (await service.preview() as ChimeraSuccess<DotnetCleanPreview>).value;
  test('GivenPreview_WhenUnconfirmed_ThenNoGatewayDeletion', () async {
    final result = await service.clean(await preview(), confirmed: false);
    expect(result, isA<ChimeraFailure<DotnetCleanReport>>());
    expect(gateway.deleted, 0);
  });
  test('GivenInvalidRoot_WhenPreviewed_ThenTypedValidation', () async {
    gateway.invalidRoot = true;
    final result =
        await service.preview() as ChimeraFailure<DotnetCleanPreview>;
    expect(result.kind, FailureKind.validation);
    expect(gateway.deleted, 0);
  });
  test('GivenRootChanged_WhenConfirmed_ThenNothingDeleted', () async {
    final value = await preview();
    gateway.invalidRoot = true;
    expect(
      await service.clean(value, confirmed: true),
      isA<ChimeraFailure<DotnetCleanReport>>(),
    );
    expect(gateway.deleted, 0);
  });
  test(
    'GivenAccessFailure_WhenConfirmed_ThenContinueAndIdentifyRetained',
    () async {
      gateway.failDelete = true;
      final result = (await service.clean(
        await preview(),
        confirmed: true,
      ) as ChimeraSuccess<DotnetCleanReport>).value;
      expect(result.removed, ['/src/obj']);
      expect(result.retained.keys, ['/src/bin']);
      expect(result.isPartialFailure, isTrue);
    },
  );
  test('GivenUsedPreview_WhenReused_ThenRejected', () async {
    final value = await preview();
    await service.clean(value, confirmed: true);
    expect(
      await service.clean(value, confirmed: true),
      isA<ChimeraFailure<DotnetCleanReport>>(),
    );
    expect(gateway.deleted, 2);
  });
  test('GivenNewPreview_WhenOldScopeConfirmed_ThenExpired', () async {
    final old = await preview();
    await preview();
    expect(
      await service.clean(old, confirmed: true),
      isA<ChimeraFailure<DotnetCleanReport>>(),
    );
    expect(gateway.deleted, 0);
  });
  test('GivenPreview_WhenMutationAttempted_ThenImmutable', () async {
    final value = await preview();
    expect(() => value.paths.clear(), throwsUnsupportedError);
  });
}
