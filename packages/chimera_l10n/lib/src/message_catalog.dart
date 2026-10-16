const List<String> supportedLocaleTags = <String>['en', 'pt-BR'];

const Map<String, Map<String, String>> _catalogs =
    <String, Map<String, String>>{
      'en': <String, String>{
        'app.name': 'Chimera',
        'app.description': 'Developer toolbox',
        'cli.noCommand': 'No command provided.',
        'cli.usage': 'Usage: chimera <command> [options]',
        'cron.everyValue': 'every value',
        'cron.countLabel': 'Occurrence count',
        'cron.explanationLabel': 'Explanation',
        'cron.expressionLabel': 'Cron expression',
        'cron.fileAction': 'Load expression from file',
        'cron.field.dayOfMonth': 'day of month',
        'cron.field.dayOfWeek': 'day of week',
        'cron.field.hour': 'hour',
        'cron.field.minute': 'minute',
        'cron.field.month': 'month',
        'cron.field.seconds': 'seconds',
        'cron.nextLabel': 'Next',
        'cron.openAction': 'Parse a cron expression',
        'cron.pageTitle': 'Parse cron expression',
        'cron.previousLabel': 'Previous',
        'cron.referenceHelp': 'ISO 8601 instant, including an offset',
        'cron.referenceLabel': 'Reference instant',
        'cron.scheduleLabel': 'Cron schedule',
        'cron.submitAction': 'Calculate occurrences',
        'cron.timeZoneLabel': 'Time zone',
        'date.resultLabel': 'Converted value',
        'date.utcLabel': 'UTC instant',
        'date.fileAction': 'Load value from file',
        'date.openAction': 'Convert a date',
        'date.pageTitle': 'Convert date',
        'date.representation.custom': 'Custom pattern',
        'date.representation.iso8601': 'ISO 8601',
        'date.representation.unix-milliseconds': 'Unix milliseconds',
        'date.representation.unix-seconds': 'Unix seconds',
        'date.sourcePatternLabel': 'Source pattern',
        'date.sourceRepresentationLabel': 'Source representation',
        'date.sourceTimeZoneLabel': 'Source time zone',
        'date.submitAction': 'Convert date',
        'date.targetPatternLabel': 'Target pattern',
        'date.targetRepresentationLabel': 'Target representation',
        'date.targetTimeZoneLabel': 'Target time zone',
        'date.valueLabel': 'Date value',
        'error.date.fileAccess': 'The input file could not be read.',
        'error.date.inputAccess': 'The input could not be read.',
        'error.date.range': 'The date is outside the supported range.',
        'error.date.validation': 'The date request is invalid.',
        'error.cron.fileAccess': 'The input file could not be read.',
        'error.cron.inputAccess': 'The input could not be read.',
        'error.cron.resource':
            'The cron calculation exceeded its resource limit.',
        'error.cron.validation': 'The cron request is invalid.',
        'error.unexpected': 'An unexpected error occurred.',
      },
      'pt-BR': <String, String>{
        'app.name': 'Chimera',
        'app.description': 'Caixa de ferramentas para desenvolvedores',
        'cli.noCommand': 'Nenhum comando foi informado.',
        'cli.usage': 'Uso: chimera <comando> [opções]',
        'cron.everyValue': 'qualquer valor',
        'cron.countLabel': 'Quantidade de ocorrências',
        'cron.explanationLabel': 'Explicação',
        'cron.expressionLabel': 'Expressão cron',
        'cron.fileAction': 'Carregar expressão de um arquivo',
        'cron.field.dayOfMonth': 'dia do mês',
        'cron.field.dayOfWeek': 'dia da semana',
        'cron.field.hour': 'hora',
        'cron.field.minute': 'minuto',
        'cron.field.month': 'mês',
        'cron.field.seconds': 'segundos',
        'cron.nextLabel': 'Próxima',
        'cron.openAction': 'Interpretar uma expressão cron',
        'cron.pageTitle': 'Interpretar expressão cron',
        'cron.previousLabel': 'Anterior',
        'cron.referenceHelp': 'Instante ISO 8601, incluindo um deslocamento',
        'cron.referenceLabel': 'Instante de referência',
        'cron.scheduleLabel': 'Agendamento cron',
        'cron.submitAction': 'Calcular ocorrências',
        'cron.timeZoneLabel': 'Fuso horário',
        'date.resultLabel': 'Valor convertido',
        'date.utcLabel': 'Instante UTC',
        'date.fileAction': 'Carregar valor de um arquivo',
        'date.openAction': 'Converter uma data',
        'date.pageTitle': 'Converter data',
        'date.representation.custom': 'Padrão personalizado',
        'date.representation.iso8601': 'ISO 8601',
        'date.representation.unix-milliseconds': 'Milissegundos Unix',
        'date.representation.unix-seconds': 'Segundos Unix',
        'date.sourcePatternLabel': 'Padrão de origem',
        'date.sourceRepresentationLabel': 'Representação de origem',
        'date.sourceTimeZoneLabel': 'Fuso horário de origem',
        'date.submitAction': 'Converter data',
        'date.targetPatternLabel': 'Padrão de destino',
        'date.targetRepresentationLabel': 'Representação de destino',
        'date.targetTimeZoneLabel': 'Fuso horário de destino',
        'date.valueLabel': 'Valor da data',
        'error.date.fileAccess': 'Não foi possível ler o arquivo de entrada.',
        'error.date.inputAccess': 'Não foi possível ler a entrada.',
        'error.date.range': 'A data está fora do intervalo suportado.',
        'error.date.validation': 'A solicitação de data é inválida.',
        'error.cron.fileAccess': 'Não foi possível ler o arquivo de entrada.',
        'error.cron.inputAccess': 'Não foi possível ler a entrada.',
        'error.cron.resource': 'O cálculo cron excedeu o limite de recursos.',
        'error.cron.validation': 'A solicitação cron é inválida.',
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
