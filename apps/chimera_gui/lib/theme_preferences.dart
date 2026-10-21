import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/chimera_platform.dart';
import 'package:flutter/material.dart';

enum ThemePreferenceStatus { idle, saving, saved, notSaved }

final class ThemePreferenceController extends ChangeNotifier {
  ThemePreferenceController({required PreferenceGateway gateway})
    : _gateway = gateway;

  final PreferenceGateway _gateway;

  ThemeMode _mode = ThemeMode.light;
  ThemePreferenceStatus _status = ThemePreferenceStatus.idle;
  int _generation = 0;
  bool _disposed = false;

  ThemeMode get mode => _mode;

  ThemePreferenceStatus get status => _status;

  Future<void> restore() async {
    final generation = ++_generation;
    ChimeraResult<String?> result;
    try {
      result = await _gateway.read(PreferenceKey.theme);
    } on Object {
      result = const ChimeraFailure<String?>(
        kind: FailureKind.access,
        code: 'preference_read_failed',
        messageKey: 'error.preference.access',
      );
    }
    if (_disposed || generation != _generation) return;

    result.fold<void>(
      onSuccess: (stored) {
        _mode = switch (stored) {
          'dark' => ThemeMode.dark,
          'light' || null => ThemeMode.light,
          _ => ThemeMode.light,
        };
        _status = ThemePreferenceStatus.idle;
      },
      onFailure: (_) {
        _mode = ThemeMode.light;
        _status = ThemePreferenceStatus.notSaved;
      },
    );
    notifyListeners();
  }

  Future<void> select(ThemeMode mode) async {
    if (mode != ThemeMode.light && mode != ThemeMode.dark) {
      throw ArgumentError.value(mode, 'mode', 'must be light or dark');
    }

    final generation = ++_generation;
    _mode = mode;
    _status = ThemePreferenceStatus.saving;
    notifyListeners();

    ChimeraResult<void> result;
    try {
      result = await _gateway.write(
        PreferenceKey.theme,
        mode == ThemeMode.dark ? 'dark' : 'light',
      );
    } on Object {
      result = const ChimeraFailure<void>(
        kind: FailureKind.access,
        code: 'preference_write_failed',
        messageKey: 'error.preference.access',
      );
    }
    if (_disposed || generation != _generation) return;

    _status = result.fold<ThemePreferenceStatus>(
      onSuccess: (_) => ThemePreferenceStatus.saved,
      onFailure: (_) => ThemePreferenceStatus.notSaved,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
