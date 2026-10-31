import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_platform/chimera_platform.dart';
import 'package:flutter/foundation.dart';

enum LanguagePreferenceStatus { idle, saving, saved, notSaved }

typedef CatalogCompleteness = bool Function(String localeTag);

final class FlutterDiagnosticSink implements DiagnosticSink {
  const FlutterDiagnosticSink();

  @override
  void emit(DiagnosticEvent event) {
    debugPrint(
      jsonEncode(<String, Object?>{
        'timestamp': event.timestamp.toUtc().toIso8601String(),
        'severity': event.severity.name,
        'component': event.component,
        'code': event.code,
        'context': event.context,
      }),
    );
  }
}

final class LanguagePreferenceController extends ChangeNotifier {
  LanguagePreferenceController(
    this._gateway, {
    String initialLocaleTag = 'en',
    CatalogCompleteness? catalogIsComplete,
    DiagnosticSink? diagnosticSink,
    DateTime Function()? currentTime,
  }) : _catalogIsComplete = catalogIsComplete ?? _defaultCatalogIsComplete,
       _currentTime = currentTime ?? DateTime.now,
       diagnosticSink = diagnosticSink ?? const FlutterDiagnosticSink(),
       _localeTag = _isSupported(initialLocaleTag) ? initialLocaleTag : 'en';

  final PreferenceGateway _gateway;
  final CatalogCompleteness _catalogIsComplete;
  final DiagnosticSink diagnosticSink;
  final DateTime Function() _currentTime;

  String _localeTag;
  LanguagePreferenceStatus _status = LanguagePreferenceStatus.idle;
  Future<void> _pendingWrites = Future<void>.value();
  int _generation = 0;
  bool _disposed = false;

  String get localeTag => _localeTag;

  LanguagePreferenceStatus get status => _status;

  Future<void> restore() async {
    final generation = ++_generation;
    ChimeraResult<String?> result;
    try {
      result = await _gateway.read(PreferenceKey.language);
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
        if (stored == null) {
          if (!_catalogIsComplete(_localeTag)) {
            _useEnglishFallback();
          }
        } else if (!_isSupported(stored) || !_catalogIsComplete(stored)) {
          _useEnglishFallback();
        } else {
          _localeTag = stored;
        }
        _status = LanguagePreferenceStatus.idle;
      },
      onFailure: (_) {
        _localeTag = 'en';
        _status = LanguagePreferenceStatus.notSaved;
      },
    );
    notifyListeners();
  }

  Future<void> select(String localeTag) async {
    if (!_isSupported(localeTag)) {
      throw ArgumentError.value(localeTag, 'localeTag', 'must be en or pt-BR');
    }
    if (!_catalogIsComplete(localeTag)) {
      _useEnglishFallback();
      _status = LanguagePreferenceStatus.idle;
      notifyListeners();
      return;
    }

    final generation = ++_generation;
    _localeTag = localeTag;
    _status = LanguagePreferenceStatus.saving;
    notifyListeners();

    final write = _pendingWrites.then((_) => _write(localeTag));
    _pendingWrites = write.then<void>((_) {});
    final result = await write;
    if (_disposed || generation != _generation) return;

    _status = result.fold<LanguagePreferenceStatus>(
      onSuccess: (_) => LanguagePreferenceStatus.saved,
      onFailure: (_) => LanguagePreferenceStatus.notSaved,
    );
    notifyListeners();
  }

  Future<ChimeraResult<void>> _write(String value) async {
    try {
      return await _gateway.write(PreferenceKey.language, value);
    } on Object {
      return const ChimeraFailure<void>(
        kind: FailureKind.access,
        code: 'preference_write_failed',
        messageKey: 'error.preference.access',
      );
    }
  }

  void _useEnglishFallback() {
    _localeTag = 'en';
    diagnosticSink.emit(
      DiagnosticEvent.create(
        timestamp: _currentTime(),
        severity: DiagnosticSeverity.warning,
        component: DiagnosticComponent.gui,
        code: DiagnosticCode.localizationFallback,
        context: const <String, Object?>{
          'status': DiagnosticStatus.failed,
          'target': DiagnosticTarget.gui,
        },
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }

  static bool _isSupported(String localeTag) =>
      supportedLocaleTags.contains(localeTag);

  static bool _defaultCatalogIsComplete(String localeTag) {
    if (!_isSupported(localeTag)) return false;
    const catalog = MessageCatalog();
    final english = catalog.keysFor('en');
    final localized = catalog.keysFor(localeTag);
    return localized.length == english.length && localized.containsAll(english);
  }
}
