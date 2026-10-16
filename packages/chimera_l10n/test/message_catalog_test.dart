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
      'cli.usage',
      'cron.countLabel',
      'cron.everyValue',
      'cron.explanationLabel',
      'cron.expressionLabel',
      'cron.fileAction',
      'cron.field.dayOfMonth',
      'cron.field.dayOfWeek',
      'cron.field.hour',
      'cron.field.minute',
      'cron.field.month',
      'cron.field.seconds',
      'cron.nextLabel',
      'cron.openAction',
      'cron.pageTitle',
      'cron.previousLabel',
      'cron.referenceHelp',
      'cron.referenceLabel',
      'cron.scheduleLabel',
      'cron.submitAction',
      'cron.timeZoneLabel',
      'date.resultLabel',
      'date.utcLabel',
      'date.fileAction',
      'date.openAction',
      'date.pageTitle',
      'date.representation.custom',
      'date.representation.iso8601',
      'date.representation.unix-milliseconds',
      'date.representation.unix-seconds',
      'date.sourcePatternLabel',
      'date.sourceRepresentationLabel',
      'date.sourceTimeZoneLabel',
      'date.submitAction',
      'date.targetPatternLabel',
      'date.targetRepresentationLabel',
      'date.targetTimeZoneLabel',
      'date.valueLabel',
      'jsonTable.emptyResult',
      'jsonTable.fileAction',
      'jsonTable.inputLabel',
      'jsonTable.locationLabel',
      'jsonTable.noColumnsResult',
      'jsonTable.openAction',
      'jsonTable.pageTitle',
      'jsonTable.rowNumberLabel',
      'jsonTable.rowCountLabel',
      'jsonTable.rowNumbersLabel',
      'jsonTable.submitAction',
      'jsonCsv.delimiter.comma',
      'jsonCsv.delimiter.pipe',
      'jsonCsv.delimiter.semicolon',
      'jsonCsv.delimiter.tab',
      'jsonCsv.delimiterLabel',
      'jsonCsv.emptyResult',
      'jsonCsv.fileAction',
      'jsonCsv.headersLabel',
      'jsonCsv.inputLabel',
      'jsonCsv.locationLabel',
      'jsonCsv.openAction',
      'jsonCsv.pageTitle',
      'jsonCsv.resultLabel',
      'jsonCsv.saveAction',
      'jsonCsv.savedResult',
      'jsonCsv.submitAction',
      'error.date.fileAccess',
      'error.date.inputAccess',
      'error.date.range',
      'error.date.validation',
      'error.cron.fileAccess',
      'error.cron.inputAccess',
      'error.cron.resource',
      'error.cron.validation',
      'error.jsonTable.fileAccess',
      'error.jsonTable.inputAccess',
      'error.jsonTable.resource',
      'error.jsonTable.validation',
      'error.jsonCsv.fileAccess',
      'error.jsonCsv.inputAccess',
      'error.jsonCsv.outputAccess',
      'error.jsonCsv.resource',
      'error.jsonCsv.validation',
      'error.unexpected',
    });
  });
}
