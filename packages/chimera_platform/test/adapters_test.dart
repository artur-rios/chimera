import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/chimera_platform.dart';
import 'package:test/test.dart';

void main() {
  test(
    'GivenPreferenceStorage_WhenKeysEnumerated_ThenOnlyThemeAndLanguageExist',
    () {
      expect(PreferenceKey.values.map((key) => key.storageKey), <String>[
        'theme',
        'language',
      ]);
      expect(PreferenceKey.fromStorageKey('theme'), PreferenceKey.theme);
      expect(PreferenceKey.fromStorageKey('language'), PreferenceKey.language);
      expect(PreferenceKey.fromStorageKey('history'), isNull);
    },
  );

  test('GivenPlatformGateways_WhenFaked_ThenEveryBoundaryIsInjectable', () {
    const file = _FakeFileGateway();
    const clipboard = _FakeClipboardGateway();
    const preferences = _FakePreferenceGateway();
    const downloader = _FakeUpdateArtifactDownloader();
    const installer = _FakeUpdateInstaller();

    expect(file, isA<FileGateway>());
    expect(clipboard, isA<ClipboardGateway>());
    expect(preferences, isA<PreferenceGateway>());
    expect(downloader, isA<UpdateArtifactDownloader>());
    expect(installer, isA<UpdateInstaller>());
  });
}

final class _FakeFileGateway implements FileGateway {
  const _FakeFileGateway();

  @override
  Future<ChimeraResult<List<int>>> readBytes(String path) async =>
      const ChimeraSuccess<List<int>>(<int>[]);

  @override
  Future<ChimeraResult<void>> writeBytes(String path, List<int> bytes) async =>
      const ChimeraSuccess<void>(null);
}

final class _FakeClipboardGateway implements ClipboardGateway {
  const _FakeClipboardGateway();

  @override
  Future<ChimeraResult<String>> readText() async =>
      const ChimeraSuccess<String>('');

  @override
  Future<ChimeraResult<void>> writeText(String value) async =>
      const ChimeraSuccess<void>(null);
}

final class _FakePreferenceGateway implements PreferenceGateway {
  const _FakePreferenceGateway();

  @override
  Future<ChimeraResult<String?>> read(PreferenceKey key) async =>
      const ChimeraSuccess<String?>(null);

  @override
  Future<ChimeraResult<void>> write(PreferenceKey key, String value) async =>
      const ChimeraSuccess<void>(null);
}

final class _FakeUpdateArtifactDownloader implements UpdateArtifactDownloader {
  const _FakeUpdateArtifactDownloader();

  @override
  Future<ChimeraResult<List<int>>> downloadArtifact(Uri url) async =>
      const ChimeraSuccess<List<int>>(<int>[]);
}

final class _FakeUpdateInstaller implements UpdateInstaller {
  const _FakeUpdateInstaller();

  @override
  Future<ChimeraResult<void>> installArtifact(String path) async =>
      const ChimeraSuccess<void>(null);
}
