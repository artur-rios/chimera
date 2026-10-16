import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:test/test.dart';

void main() {
  const catalog = MessageCatalog();

  test('GivenEnglishLocale_WhenMessageLookedUp_ThenEnglishTextIsReturned', () {
    expect(catalog.lookup('en', 'app.description'), 'Developer toolbox');
  });

  test('GivenBrazilianPortugueseLocale_WhenMessageLookedUp_ThenPortugueseTextIsReturned', () {
    expect(
      catalog.lookup('pt-BR', 'cli.noCommand'),
      'Nenhum comando foi informado.',
    );
  });

  test('GivenUnsupportedLocale_WhenMessageLookedUp_ThenEnglishIsUsed', () {
    expect(catalog.lookup('es', 'cli.noCommand'), 'No command provided.');
  });

  test('GivenSupportedCatalogs_WhenKeysCompared_ThenTheyHaveExactParity', () {
    expect(supportedLocaleTags, <String>['en', 'pt-BR']);
    expect(catalog.keysFor('pt-BR'), catalog.keysFor('en'));
    expect(catalog.keysFor('en'), <String>{
      'app.name',
      'app.description',
      'cli.noCommand',
      'error.unexpected',
    });
  });
}
