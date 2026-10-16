import 'package:chimera_core/chimera_core.dart';

enum PreferenceKey {
  theme('theme'),
  language('language');

  const PreferenceKey(this.storageKey);

  final String storageKey;

  static PreferenceKey? fromStorageKey(String value) {
    for (final key in values) {
      if (key.storageKey == value) {
        return key;
      }
    }
    return null;
  }
}

abstract interface class FileGateway {
  Future<ChimeraResult<List<int>>> readBytes(String path);

  Future<ChimeraResult<void>> writeBytes(String path, List<int> bytes);
}

abstract interface class ClipboardGateway {
  Future<ChimeraResult<String>> readText();

  Future<ChimeraResult<void>> writeText(String value);
}

abstract interface class PreferenceGateway {
  Future<ChimeraResult<String?>> read(PreferenceKey key);

  Future<ChimeraResult<void>> write(PreferenceKey key, String value);
}

abstract interface class UpdateGateway {
  Future<ChimeraResult<String>> fetchReleaseMetadata(Uri endpoint);

  Future<ChimeraResult<List<int>>> downloadArtifact(Uri url);

  Future<ChimeraResult<void>> installArtifact(String path);
}
