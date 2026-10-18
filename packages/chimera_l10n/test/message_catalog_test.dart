import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:test/test.dart';

void main() {
  const catalog = MessageCatalog();

  test('GivenGzipInteractiveMessages_WhenLookedUp_ThenBothLocalesHaveCompleteLabels', () {
    for (final locale in supportedLocaleTags) {
      for (final name in [
        'pageTitle',
        'openAction',
        'inputLabel',
        'fileAction',
        'pasteAction',
        'levelLabel',
        'submitAction',
        'saveAction',
        'fileSaved',
        'outputLabel',
        'resultSuccess',
        'inputByteCountLabel',
        'outputByteCountLabel',
      ]) {
        final key = 'gzipCompress.$name';
        expect(catalog.lookup(locale, key), isNot(key));
      }
      expect(
        catalog.lookup(locale, 'error.gzipCompress.clipboardRead'),
        isNot('error.gzipCompress.clipboardRead'),
      );
      expect(
        catalog.lookup(locale, 'error.gzipCompress.interactiveInputAccess'),
        isNot('error.gzipCompress.interactiveInputAccess'),
      );
    }
  });

  test('GivenGzipCliMessages_WhenLookedUp_ThenBothLocalesHaveExactParity', () {
    final keys = <String>{
      'cli.gzipCompressUsage',
      'gzipCompress.savedResult',
      'error.gzipCompress.validation',
      'error.gzipCompress.inputAccess',
      'error.gzipCompress.fileAccess',
      'error.gzipCompress.outputAccess',
      'error.gzipCompress.resource',
    };
    expect(catalog.keysFor('en'), catalog.keysFor('pt-BR'));
    for (final locale in supportedLocaleTags) {
      expect(catalog.keysFor(locale), containsAll(keys));
      for (final key in keys) {
        expect(catalog.lookup(locale, key), isNotEmpty);
      }
      expect(
        catalog.lookup(locale, 'gzipCompress.savedResult'),
        contains('{level}'),
      );
      expect(
        catalog.lookup(locale, 'gzipCompress.savedResult'),
        contains('{inputByteCount}'),
      );
      expect(
        catalog.lookup(locale, 'gzipCompress.savedResult'),
        contains('{outputByteCount}'),
      );
      expect(
        catalog.lookup(locale, 'cli.gzipCompressUsage'),
        contains('--level=<0..9>'),
      );
    }
    expect(
      catalog.lookup('pt-BR', 'error.gzipCompress.resource'),
      'A compressão GZIP excedeu o limite de recursos.',
    );
  });

  test('GivenGzipDecompressCliMessages_WhenLookedUp_ThenBothLocalesHaveExactParity', () {
    final keys = <String>{
      'cli.gzipDecompressUsage',
      'gzipDecompress.savedResult',
      'error.gzipDecompress.validation',
      'error.gzipDecompress.inputAccess',
      'error.gzipDecompress.fileAccess',
      'error.gzipDecompress.outputAccess',
      'error.gzipDecompress.resource',
    };
    expect(catalog.keysFor('en'), catalog.keysFor('pt-BR'));
    for (final locale in supportedLocaleTags) {
      expect(catalog.keysFor(locale), containsAll(keys));
      for (final key in keys) {
        expect(catalog.lookup(locale, key), isNotEmpty);
        expect(catalog.lookup(locale, key), isNot(key));
      }
      expect(
        catalog.lookup(locale, 'cli.gzipDecompressUsage'),
        contains('--mode=text|binary'),
      );
    }
    expect(
      catalog.lookup('en', 'gzipDecompress.savedResult'),
      'Decompressed bytes saved.',
    );
    expect(
      catalog.lookup('pt-BR', 'gzipDecompress.savedResult'),
      'Bytes descomprimidos salvos.',
    );
    expect(
      catalog.lookup('pt-BR', 'error.gzipDecompress.resource'),
      'A descompressão GZIP excedeu o limite de recursos.',
    );
  });

  test(
    'GivenCertificateConvertMessages_WhenLookedUp_ThenBothLocalesAreComplete',
    () {
      for (final locale in supportedLocaleTags) {
        for (final key in [
          'cli.certificateConvertUsage',
          'certificateConvert.savedResult',
          for (final name in [
            'pageTitle',
            'openAction',
            'inputLabel',
            'fileAction',
            'pasteAction',
            'sourceLabel',
            'targetLabel',
            'submitAction',
            'copyAction',
            'saveAction',
            'copiedResult',
            'outputLabel',
            'resultSuccess',
            'inputByteCountLabel',
            'derByteCountLabel',
            'outputByteCountLabel',
            'representation.auto',
            'representation.pem',
            'representation.der',
            'representation.base64',
          ])
            'certificateConvert.$name',
          'error.certificateConvert.clipboardRead',
          'error.certificateConvert.clipboardWrite',
          'error.certificateConvert.validation',
          'error.certificateConvert.inputAccess',
          'error.certificateConvert.fileAccess',
          'error.certificateConvert.outputAccess',
          'error.certificateConvert.resource',
        ]) {
          expect(catalog.lookup(locale, key), isNot(key));
        }
        expect(
          catalog.lookup(locale, 'cli.certificateConvertUsage'),
          contains('--to=pem|der|base64'),
        );
      }
    },
  );

  test(
    'GivenCertificateInspectMessages_WhenLookedUp_ThenBothLocalesAreComplete',
    () {
      for (final locale in supportedLocaleTags) {
        for (final key in [
          'pageTitle',
          'openAction',
          'inputLabel',
          'fileAction',
          'pasteAction',
          'submitAction',
          'copyAction',
          'copiedResult',
          'outputLabel',
          'resultSuccess',
          'subjectCountLabel',
          'issuerCountLabel',
          'extensionCountLabel',
          'representation.auto',
          'representationLabel',
          'versionLabel',
          'serialNumberHexLabel',
          'subjectLabel',
          'issuerLabel',
          'notBeforeLabel',
          'notAfterLabel',
          'signatureAlgorithmLabel',
          'publicKeyAlgorithmLabel',
          'extensionsLabel',
          'criticalLabel',
          'yes',
          'no',
          'inputByteCountLabel',
          'derByteCountLabel',
          'representation.pem',
          'representation.der',
          'representation.base64',
        ]) {
          expect(
            catalog.lookup(locale, 'certificateInspect.$key'),
            isNot('certificateInspect.$key'),
          );
        }
        for (final key in [
          'validation',
          'fileAccess',
          'clipboardRead',
          'clipboardWrite',
          'inputAccess',
          'resource',
        ]) {
          expect(
            catalog.lookup(locale, 'error.certificateInspect.$key'),
            isNot('error.certificateInspect.$key'),
          );
        }
      }
      expect(
        catalog.lookup('en', 'certificateInspect.subjectLabel'),
        'Subject',
      );
      expect(
        catalog.lookup('pt-BR', 'certificateInspect.subjectLabel'),
        'Titular',
      );
    },
  );

  test('GivenEnglishLocale_WhenMessageLookedUp_ThenEnglishTextIsReturned', () {
    expect(catalog.lookup('en', 'app.description'), 'Developer toolbox');
  });

  test('GivenBrazilianPortugueseLocale_WhenMessageLookedUp_ThenPortugueseTextIsReturned', () {
    expect(
      catalog.lookup('pt-BR', 'cli.noCommand'),
      'Nenhum comando foi informado.',
    );
  });

  test('GivenNumberBaseMessages_WhenLookedUp_ThenBothLocalesAreComplete', () {
    expect(catalog.lookup('en', 'numberBase.resultLabel'), 'Converted value');
    expect(
      catalog.lookup('pt-BR', 'numberBase.resultLabel'),
      'Valor convertido',
    );
    expect(
      catalog.lookup('pt-BR', 'error.numberBase.resource'),
      'A conversão numérica excedeu o limite de recursos.',
    );
  });

  test('GivenTextEscapeMessages_WhenLookedUp_ThenBothLocalesAreComplete', () {
    expect(catalog.lookup('en', 'textEscape.resultLabel'), 'Escaped text');
    expect(catalog.lookup('pt-BR', 'textEscape.resultLabel'), 'Texto escapado');
    expect(
      catalog.lookup('pt-BR', 'error.textEscape.resource'),
      'O escape de texto excedeu o limite de recursos.',
    );
  });

  test('GivenTextUnescapeMessages_WhenLookedUp_ThenBothLocalesAreComplete', () {
    expect(catalog.lookup('en', 'textUnescape.resultLabel'), 'Unescaped text');
    expect(
      catalog.lookup('pt-BR', 'textUnescape.resultLabel'),
      'Texto não escapado',
    );
    expect(
      catalog.lookup('pt-BR', 'error.textUnescape.resource'),
      'A remoção de escape de texto excedeu o limite de recursos.',
    );
  });

  test('GivenListCompareMessages_WhenLookedUp_ThenBothLocalesAreComplete', () {
    expect(catalog.lookup('en', 'listCompare.leftOnlyLabel'), 'Left only');
    expect(
      catalog.lookup('pt-BR', 'listCompare.leftOnlyLabel'),
      'Somente à esquerda',
    );
    expect(
      catalog.lookup('pt-BR', 'error.listCompare.resource'),
      'A comparação de listas excedeu o limite de recursos.',
    );
  });

  test('GivenTextAnalyzeMessages_WhenLookedUp_ThenBothLocalesAreComplete', () {
    expect(catalog.lookup('en', 'textAnalyze.wordCountLabel'), 'Words');
    expect(catalog.lookup('pt-BR', 'textAnalyze.wordCountLabel'), 'Palavras');
    expect(
      catalog.lookup('pt-BR', 'error.textAnalyze.resource'),
      'A análise de texto excedeu o limite de recursos.',
    );
  });

  test(
    'GivenTextTransformMessages_WhenLookedUp_ThenBothLocalesAreComplete',
    () {
      expect(
        catalog.lookup('en', 'textTransform.mode.normalize-whitespace'),
        'Normalize whitespace',
      );
      expect(
        catalog.lookup('pt-BR', 'textTransform.savedResult'),
        'Texto transformado salvo.',
      );
      expect(
        catalog.lookup('pt-BR', 'error.textTransform.resource'),
        'A transformação de texto excedeu o limite de recursos.',
      );
    },
  );

  test('GivenTextCompareMessages_WhenLookedUp_ThenBothLocalesAreComplete', () {
    expect(catalog.lookup('en', 'textCompare.kind.added'), 'Added');
    expect(catalog.lookup('pt-BR', 'textCompare.kind.unchanged'), 'Inalterado');
    expect(
      catalog.lookup('pt-BR', 'error.textCompare.resource'),
      'A comparação de textos excedeu o limite de recursos.',
    );
  });

  test('GivenBase64EncodeMessages_WhenLookedUp_ThenBothLocalesAreComplete', () {
    expect(
      catalog.lookup('en', 'base64Encode.resultSuccess'),
      'Base64 encoding succeeded.',
    );
    expect(
      catalog.lookup('pt-BR', 'base64Encode.resultSuccess'),
      'Codificação Base64 concluída.',
    );
    expect(
      catalog.lookup('en', 'base64Encode.inputByteCountLabel'),
      'Input bytes',
    );
    expect(
      catalog.lookup('pt-BR', 'base64Encode.outputCharacterCountLabel'),
      'Caracteres de saída',
    );
    expect(
      catalog.lookup('pt-BR', 'error.base64Encode.resource'),
      'A codificação Base64 excedeu o limite de recursos.',
    );
  });

  test('GivenBase64DecodeMessages_WhenLookedUp_ThenBothLocalesAreComplete', () {
    expect(
      catalog.lookup('en', 'base64Decode.resultSuccess'),
      'Base64 decoding succeeded.',
    );
    expect(
      catalog.lookup('pt-BR', 'base64Decode.resultSuccess'),
      'Decodificação Base64 concluída.',
    );
    expect(
      catalog.lookup('en', 'base64Decode.savedResult'),
      'Decoded bytes saved.',
    );
    expect(
      catalog.lookup('pt-BR', 'base64Decode.savedResult'),
      'Bytes decodificados salvos.',
    );
    expect(catalog.lookup('en', 'base64Decode.mode.binary'), 'Binary');
    expect(catalog.lookup('pt-BR', 'base64Decode.mode.text'), 'Texto');
    expect(
      catalog.lookup('en', 'error.base64Decode.validation'),
      'The Base64 decoding request is invalid.',
    );
    expect(
      catalog.lookup('pt-BR', 'error.base64Decode.resource'),
      'A decodificação Base64 excedeu o limite de recursos.',
    );
  });

  test('GivenUnsupportedLocale_WhenMessageLookedUp_ThenEnglishIsUsed', () {
    expect(catalog.lookup('es', 'cli.noCommand'), 'No command provided.');
  });

  test('GivenSupportedCatalogs_WhenKeysCompared_ThenTheyHaveExactParity', () {
    expect(supportedLocaleTags, <String>['en', 'pt-BR']);
    expect(catalog.keysFor('pt-BR'), catalog.keysFor('en'));
    expect(catalog.keysFor('en'), <String>{
      for (final name in [
        'pageTitle',
        'openAction',
        'inputLabel',
        'fileAction',
        'pasteAction',
        'levelLabel',
        'submitAction',
        'saveAction',
        'fileSaved',
        'outputLabel',
        'resultSuccess',
        'inputByteCountLabel',
        'outputByteCountLabel',
      ])
        'gzipCompress.$name',
      'error.gzipCompress.clipboardRead',
      'error.gzipCompress.interactiveInputAccess',
      'cli.gzipCompressUsage',
      'gzipCompress.savedResult',
      'error.gzipCompress.validation',
      'error.gzipCompress.inputAccess',
      'error.gzipCompress.fileAccess',
      'error.gzipCompress.outputAccess',
      'error.gzipCompress.resource',
      'cli.gzipDecompressUsage',
      'gzipDecompress.savedResult',
      'error.gzipDecompress.validation',
      'error.gzipDecompress.inputAccess',
      'error.gzipDecompress.fileAccess',
      'error.gzipDecompress.outputAccess',
      'error.gzipDecompress.resource',
      'cli.certificateConvertUsage',
      'certificateConvert.savedResult',
      'certificateConvert.pageTitle',
      'certificateConvert.openAction',
      'certificateConvert.inputLabel',
      'certificateConvert.fileAction',
      'certificateConvert.pasteAction',
      'certificateConvert.sourceLabel',
      'certificateConvert.targetLabel',
      'certificateConvert.submitAction',
      'certificateConvert.copyAction',
      'certificateConvert.saveAction',
      'certificateConvert.copiedResult',
      'certificateConvert.outputLabel',
      'certificateConvert.resultSuccess',
      'certificateConvert.inputByteCountLabel',
      'certificateConvert.derByteCountLabel',
      'certificateConvert.outputByteCountLabel',
      'certificateConvert.representation.auto',
      'certificateConvert.representation.pem',
      'certificateConvert.representation.der',
      'certificateConvert.representation.base64',
      'error.certificateConvert.clipboardRead',
      'error.certificateConvert.clipboardWrite',
      'error.certificateConvert.validation',
      'error.certificateConvert.inputAccess',
      'error.certificateConvert.fileAccess',
      'error.certificateConvert.outputAccess',
      'error.certificateConvert.resource',
      'app.name',
      'app.description',
      'certificateInspect.representationLabel',
      'certificateInspect.pageTitle',
      'certificateInspect.openAction',
      'certificateInspect.inputLabel',
      'certificateInspect.fileAction',
      'certificateInspect.pasteAction',
      'certificateInspect.submitAction',
      'certificateInspect.copyAction',
      'certificateInspect.copiedResult',
      'certificateInspect.outputLabel',
      'certificateInspect.resultSuccess',
      'certificateInspect.subjectCountLabel',
      'certificateInspect.issuerCountLabel',
      'certificateInspect.extensionCountLabel',
      'certificateInspect.representation.auto',
      'error.certificateInspect.clipboardRead',
      'error.certificateInspect.clipboardWrite',
      'certificateInspect.versionLabel',
      'certificateInspect.serialNumberHexLabel',
      'certificateInspect.subjectLabel',
      'certificateInspect.issuerLabel',
      'certificateInspect.notBeforeLabel',
      'certificateInspect.notAfterLabel',
      'certificateInspect.signatureAlgorithmLabel',
      'certificateInspect.publicKeyAlgorithmLabel',
      'certificateInspect.extensionsLabel',
      'certificateInspect.criticalLabel',
      'certificateInspect.yes',
      'certificateInspect.no',
      'certificateInspect.inputByteCountLabel',
      'certificateInspect.derByteCountLabel',
      'certificateInspect.representation.pem',
      'certificateInspect.representation.der',
      'certificateInspect.representation.base64',
      'error.certificateInspect.validation',
      'error.certificateInspect.fileAccess',
      'error.certificateInspect.inputAccess',
      'error.certificateInspect.resource',
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
      'base64Encode.copiedResult',
      'base64Encode.copyAction',
      'base64Encode.fileAction',
      'base64Encode.inputByteCountLabel',
      'base64Encode.inputLabel',
      'base64Encode.openAction',
      'base64Encode.outputCharacterCountLabel',
      'base64Encode.outputLabel',
      'base64Encode.pageTitle',
      'base64Encode.pasteAction',
      'base64Encode.resultSuccess',
      'base64Encode.saveAction',
      'base64Encode.savedResult',
      'base64Encode.submitAction',
      'base64Decode.copiedResult',
      'base64Decode.copyAction',
      'base64Decode.fileAction',
      'base64Decode.imageAvailable',
      'base64Decode.imageUnavailable',
      'base64Decode.inputCharacterCountLabel',
      'base64Decode.inputLabel',
      'base64Decode.mode.binary',
      'base64Decode.mode.text',
      'base64Decode.modeLabel',
      'base64Decode.openAction',
      'base64Decode.outputByteCountLabel',
      'base64Decode.outputLabel',
      'base64Decode.pageTitle',
      'base64Decode.pasteAction',
      'base64Decode.resultSuccess',
      'base64Decode.saveAction',
      'base64Decode.savedResult',
      'base64Decode.submitAction',
      'numberBase.copiedResult',
      'numberBase.copyAction',
      'numberBase.fileAction',
      'numberBase.inputLabel',
      'numberBase.openAction',
      'numberBase.pageTitle',
      'numberBase.pasteAction',
      'numberBase.resultLabel',
      'numberBase.saveAction',
      'numberBase.savedResult',
      'numberBase.sourceBaseLabel',
      'numberBase.submitAction',
      'numberBase.targetBaseLabel',
      'textAnalyze.byteCountLabel',
      'textAnalyze.characterCountLabel',
      'textAnalyze.copiedResult',
      'textAnalyze.copyAction',
      'textAnalyze.fileAction',
      'textAnalyze.inputLabel',
      'textAnalyze.lineCountLabel',
      'textAnalyze.openAction',
      'textAnalyze.pageTitle',
      'textAnalyze.pasteAction',
      'textAnalyze.saveAction',
      'textAnalyze.savedResult',
      'textAnalyze.submitAction',
      'textAnalyze.wordCountLabel',
      'textTransform.copiedResult',
      'textTransform.copyAction',
      'textTransform.fileAction',
      'textTransform.inputLabel',
      'textTransform.mode.deduplicate-lines',
      'textTransform.mode.lowercase',
      'textTransform.mode.normalize-whitespace',
      'textTransform.mode.sort-lines',
      'textTransform.mode.uppercase',
      'textTransform.modeLabel',
      'textTransform.openAction',
      'textTransform.outputLabel',
      'textTransform.pageTitle',
      'textTransform.pasteAction',
      'textTransform.saveAction',
      'textTransform.savedResult',
      'textTransform.submitAction',
      'textCompare.addedCountLabel',
      'textCompare.copiedResult',
      'textCompare.copyAction',
      'textCompare.fileAction.left',
      'textCompare.fileAction.right',
      'textCompare.granularity.character',
      'textCompare.granularity.line',
      'textCompare.granularity.word',
      'textCompare.granularityLabel',
      'textCompare.kind.added',
      'textCompare.kind.removed',
      'textCompare.kind.unchanged',
      'textCompare.leftInputLabel',
      'textCompare.openAction',
      'textCompare.outputLabel',
      'textCompare.pageTitle',
      'textCompare.pasteAction.left',
      'textCompare.pasteAction.right',
      'textCompare.removedCountLabel',
      'textCompare.rightInputLabel',
      'textCompare.saveAction',
      'textCompare.savedResult',
      'textCompare.submitAction',
      'textCompare.unchangedCountLabel',
      'textEscape.copiedResult',
      'textEscape.copyAction',
      'textEscape.fileAction',
      'textEscape.inputLabel',
      'textEscape.mode.c',
      'textEscape.mode.html',
      'textEscape.mode.json',
      'textEscape.mode.unicode',
      'textEscape.mode.url',
      'textEscape.modeLabel',
      'textEscape.openAction',
      'textEscape.pageTitle',
      'textEscape.pasteAction',
      'textEscape.resultLabel',
      'textEscape.saveAction',
      'textEscape.savedResult',
      'textEscape.submitAction',
      'textUnescape.copiedResult',
      'textUnescape.copyAction',
      'textUnescape.fileAction',
      'textUnescape.inputLabel',
      'textUnescape.mode.c',
      'textUnescape.mode.html',
      'textUnescape.mode.json',
      'textUnescape.mode.unicode',
      'textUnescape.mode.url',
      'textUnescape.modeLabel',
      'textUnescape.openAction',
      'textUnescape.pageTitle',
      'textUnescape.pasteAction',
      'textUnescape.resultLabel',
      'textUnescape.saveAction',
      'textUnescape.savedResult',
      'textUnescape.submitAction',
      'listCompare.case.insensitive',
      'listCompare.case.sensitive',
      'listCompare.caseLabel',
      'listCompare.copiedResult',
      'listCompare.copyAction',
      'listCompare.duplicate.distinct',
      'listCompare.duplicate.preserve',
      'listCompare.duplicateLabel',
      'listCompare.equalLabel',
      'listCompare.fileAction.left',
      'listCompare.fileAction.right',
      'listCompare.intersectionLabel',
      'listCompare.itemCountLabel',
      'listCompare.leftInputLabel',
      'listCompare.leftOnlyLabel',
      'listCompare.noValue',
      'listCompare.openAction',
      'listCompare.pageTitle',
      'listCompare.pasteAction.left',
      'listCompare.pasteAction.right',
      'listCompare.rightInputLabel',
      'listCompare.rightOnlyLabel',
      'listCompare.saveAction',
      'listCompare.savedResult',
      'listCompare.submitAction',
      'listCompare.whitespace.preserve',
      'listCompare.whitespace.trim',
      'listCompare.whitespaceLabel',
      'listCompare.yesValue',
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
      'jsonYaml.fileAction',
      'jsonYaml.indent.2',
      'jsonYaml.indent.4',
      'jsonYaml.indentLabel',
      'jsonYaml.inputLabel',
      'jsonYaml.locationLabel',
      'jsonYaml.openAction',
      'jsonYaml.pageTitle',
      'jsonYaml.quoteStringsLabel',
      'jsonYaml.resultLabel',
      'jsonYaml.saveAction',
      'jsonYaml.savedResult',
      'jsonYaml.submitAction',
      'jsonFormat.copiedResult',
      'jsonFormat.copyAction',
      'jsonFormat.fileAction',
      'jsonFormat.indent.2',
      'jsonFormat.indent.4',
      'jsonFormat.indentLabel',
      'jsonFormat.inputLabel',
      'jsonFormat.locationLabel',
      'jsonFormat.openAction',
      'jsonFormat.pageTitle',
      'jsonFormat.pasteAction',
      'jsonFormat.reasonLabel',
      'jsonFormat.reason.malformed-json',
      'jsonFormat.reason.unexpected-character',
      'jsonFormat.reason.unexpected-end-of-input',
      'jsonFormat.reason.unrecognized-token',
      'jsonFormat.resultLabel',
      'jsonFormat.saveAction',
      'jsonFormat.savedResult',
      'jsonFormat.submitAction',
      'sqlFormat.copiedResult',
      'sqlFormat.copyAction',
      'sqlFormat.dialect.mysql',
      'sqlFormat.dialect.postgresql',
      'sqlFormat.dialect.sqlserver',
      'sqlFormat.dialect.sqlite',
      'sqlFormat.dialectLabel',
      'sqlFormat.fileAction',
      'sqlFormat.indent.2',
      'sqlFormat.indent.4',
      'sqlFormat.indentLabel',
      'sqlFormat.inputLabel',
      'sqlFormat.keywordCase.lower',
      'sqlFormat.keywordCase.preserve',
      'sqlFormat.keywordCase.upper',
      'sqlFormat.keywordCaseLabel',
      'sqlFormat.locationLabel',
      'sqlFormat.openAction',
      'sqlFormat.pageTitle',
      'sqlFormat.pasteAction',
      'sqlFormat.reasonLabel',
      'sqlFormat.reason.empty-input',
      'sqlFormat.reason.invalid-number',
      'sqlFormat.reason.invalid-parameter',
      'sqlFormat.reason.incomplete-statement',
      'sqlFormat.reason.missing-expression',
      'sqlFormat.reason.missing-relation',
      'sqlFormat.reason.unclosed-parenthesis',
      'sqlFormat.reason.unclosed-bracket',
      'sqlFormat.reason.unexpected-character',
      'sqlFormat.reason.unexpected-closing-parenthesis',
      'sqlFormat.reason.unexpected-closing-bracket',
      'sqlFormat.reason.unsupported-dialect-syntax',
      'sqlFormat.reason.unsupported-statement',
      'sqlFormat.reason.unterminated-comment',
      'sqlFormat.reason.unterminated-identifier',
      'sqlFormat.reason.unterminated-literal',
      'sqlFormat.resultLabel',
      'sqlFormat.saveAction',
      'sqlFormat.savedResult',
      'sqlFormat.submitAction',
      'xmlFormat.copiedResult',
      'xmlFormat.copyAction',
      'xmlFormat.fileAction',
      'xmlFormat.indent.2',
      'xmlFormat.indent.4',
      'xmlFormat.indentLabel',
      'xmlFormat.inputLabel',
      'xmlFormat.locationLabel',
      'xmlFormat.lineLabel',
      'xmlFormat.columnLabel',
      'xmlFormat.offsetLabel',
      'xmlFormat.openAction',
      'xmlFormat.pageTitle',
      'xmlFormat.pasteAction',
      'xmlFormat.reasonLabel',
      'xmlFormat.reason.malformed-xml',
      'xmlFormat.resultLabel',
      'xmlFormat.saveAction',
      'xmlFormat.savedResult',
      'xmlFormat.submitAction',
      'error.date.fileAccess',
      'error.date.inputAccess',
      'error.date.range',
      'error.date.validation',
      'error.base64Encode.clipboardRead',
      'error.base64Encode.clipboardWrite',
      'error.base64Encode.fileAccess',
      'error.base64Encode.inputAccess',
      'error.base64Encode.outputAccess',
      'error.base64Encode.resource',
      'error.base64Encode.validation',
      'error.base64Decode.clipboardRead',
      'error.base64Decode.clipboardWrite',
      'error.base64Decode.fileAccess',
      'error.base64Decode.inputAccess',
      'error.base64Decode.outputAccess',
      'error.base64Decode.resource',
      'error.base64Decode.validation',
      'error.numberBase.clipboardRead',
      'error.numberBase.clipboardWrite',
      'error.numberBase.fileAccess',
      'error.numberBase.inputAccess',
      'error.numberBase.outputAccess',
      'error.numberBase.resource',
      'error.numberBase.validation',
      'error.textAnalyze.clipboardRead',
      'error.textAnalyze.clipboardWrite',
      'error.textAnalyze.fileAccess',
      'error.textAnalyze.inputAccess',
      'error.textAnalyze.outputAccess',
      'error.textAnalyze.resource',
      'error.textAnalyze.validation',
      'error.textTransform.clipboardRead',
      'error.textTransform.clipboardWrite',
      'error.textTransform.fileAccess',
      'error.textTransform.inputAccess',
      'error.textTransform.outputAccess',
      'error.textTransform.resource',
      'error.textTransform.validation',
      'error.textCompare.clipboardRead',
      'error.textCompare.clipboardWrite',
      'error.textCompare.fileAccess',
      'error.textCompare.inputAccess',
      'error.textCompare.outputAccess',
      'error.textCompare.resource',
      'error.textCompare.validation',
      'error.textEscape.clipboardRead',
      'error.textEscape.clipboardWrite',
      'error.textEscape.fileAccess',
      'error.textEscape.inputAccess',
      'error.textEscape.outputAccess',
      'error.textEscape.resource',
      'error.textEscape.validation',
      'error.textUnescape.clipboardRead',
      'error.textUnescape.clipboardWrite',
      'error.textUnescape.fileAccess',
      'error.textUnescape.inputAccess',
      'error.textUnescape.outputAccess',
      'error.textUnescape.resource',
      'error.textUnescape.validation',
      'error.listCompare.clipboardRead',
      'error.listCompare.clipboardWrite',
      'error.listCompare.fileAccess',
      'error.listCompare.inputAccess',
      'error.listCompare.outputAccess',
      'error.listCompare.resource',
      'error.listCompare.validation',
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
      'error.jsonYaml.fileAccess',
      'error.jsonYaml.inputAccess',
      'error.jsonYaml.outputAccess',
      'error.jsonYaml.resource',
      'error.jsonYaml.validation',
      'error.jsonFormat.clipboardRead',
      'error.jsonFormat.clipboardWrite',
      'error.jsonFormat.fileAccess',
      'error.jsonFormat.inputAccess',
      'error.jsonFormat.outputAccess',
      'error.jsonFormat.resource',
      'error.jsonFormat.validation',
      'error.sqlFormat.clipboardRead',
      'error.sqlFormat.clipboardWrite',
      'error.sqlFormat.fileAccess',
      'error.sqlFormat.inputAccess',
      'error.sqlFormat.outputAccess',
      'error.sqlFormat.resource',
      'error.sqlFormat.validation',
      'error.xmlFormat.clipboardRead',
      'error.xmlFormat.clipboardWrite',
      'error.xmlFormat.fileAccess',
      'error.xmlFormat.inputAccess',
      'error.xmlFormat.outputAccess',
      'error.xmlFormat.resource',
      'error.xmlFormat.validation',
      'error.unexpected',
    });
  });
}
