import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/chimera_platform.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef SharedPreferencesLoader = Future<SharedPreferences> Function();

final class SharedPreferencesPreferenceGateway implements PreferenceGateway {
  SharedPreferencesPreferenceGateway({SharedPreferencesLoader? load})
    : _load = load ?? SharedPreferences.getInstance;

  final SharedPreferencesLoader _load;

  @override
  Future<ChimeraResult<String?>> read(PreferenceKey key) async {
    try {
      final preferences = await _load();
      return ChimeraSuccess<String?>(preferences.getString(key.storageKey));
    } on Object {
      return const ChimeraFailure<String?>(
        kind: FailureKind.access,
        code: 'preference_read_failed',
        messageKey: 'error.preference.access',
      );
    }
  }

  @override
  Future<ChimeraResult<void>> write(PreferenceKey key, String value) async {
    try {
      final preferences = await _load();
      final saved = await preferences.setString(key.storageKey, value);
      if (!saved) {
        return const ChimeraFailure<void>(
          kind: FailureKind.access,
          code: 'preference_write_failed',
          messageKey: 'error.preference.access',
        );
      }
      return const ChimeraSuccess<void>(null);
    } on Object {
      return const ChimeraFailure<void>(
        kind: FailureKind.access,
        code: 'preference_write_failed',
        messageKey: 'error.preference.access',
      );
    }
  }
}
