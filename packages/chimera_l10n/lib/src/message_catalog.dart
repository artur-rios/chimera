const List<String> supportedLocaleTags = <String>['en', 'pt-BR'];

const Map<String, Map<String, String>> _catalogs =
    <String, Map<String, String>>{
      'en': <String, String>{
        'app.name': 'Chimera',
        'app.description': 'Developer toolbox',
        'cli.noCommand': 'No command provided.',
        'error.unexpected': 'An unexpected error occurred.',
      },
      'pt-BR': <String, String>{
        'app.name': 'Chimera',
        'app.description': 'Caixa de ferramentas para desenvolvedores',
        'cli.noCommand': 'Nenhum comando foi informado.',
        'error.unexpected': 'Ocorreu um erro inesperado.',
      },
    };

final class MessageCatalog {
  const MessageCatalog();

  String lookup(String localeTag, String key) {
    final locale = _catalogs.containsKey(localeTag) ? localeTag : 'en';
    final localized = _catalogs[locale]![key];
    if (localized != null) {
      return localized;
    }

    final fallback = _catalogs['en']![key];
    if (fallback != null) {
      return fallback;
    }

    throw ArgumentError.value(key, 'key', 'Unknown message key');
  }

  Set<String> keysFor(String localeTag) {
    final locale = _catalogs.containsKey(localeTag) ? localeTag : 'en';
    return Set<String>.unmodifiable(_catalogs[locale]!.keys);
  }
}
