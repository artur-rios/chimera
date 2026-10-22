import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:test/test.dart';

void main() {
  const catalog = MessageCatalog();
  test('GivenThemeMessages_WhenLookedUp_ThenBothLocalesAreComplete', () {
    const keys = <String>{
      'theme.title',
      'theme.description',
      'theme.label',
      'theme.light',
      'theme.dark',
      'theme.saving',
      'theme.saved',
      'theme.notSaved',
    };
    for (final locale in supportedLocaleTags) {
      for (final key in keys) {
        expect(catalog.lookup(locale, key), isNotEmpty);
        expect(catalog.lookup(locale, key), isNot(key));
      }
    }
  });

  test('GivenLanguageMessages_WhenLookedUp_ThenBothLocalesAreComplete', () {
    const keys = <String>{
      'language.title',
      'language.description',
      'language.label',
      'language.en',
      'language.pt-BR',
      'language.saving',
      'language.saved',
      'language.notSaved',
    };
    for (final locale in supportedLocaleTags) {
      for (final key in keys) {
        expect(catalog.lookup(locale, key), isNotEmpty);
        expect(catalog.lookup(locale, key), isNot(key));
      }
    }
  });

  test('GivenCardMessages_WhenLookedUp_ThenBothLocalesAreComplete', () {
    const keys = <String>{
      'cli.cardUsage',
      'card.syntheticLabel',
      'card.pageTitle',
      'card.openAction',
      'card.networkLabel',
      'card.network.visa',
      'card.network.mastercard',
      'card.network.amex',
      'card.network.discover',
      'card.countLabel',
      'card.semantics',
      'card.generate',
      'card.resultLabel',
      'card.success',
      'card.copy',
      'card.save',
      'card.copied',
      'card.saved',
      'error.card.validation',
      'error.card.processing',
      'error.card.resource',
      'error.card.outputAccess',
      'error.card.clipboardWrite',
    };
    for (final locale in supportedLocaleTags) {
      for (final key in keys) {
        expect(catalog.lookup(locale, key), isNotEmpty);
        expect(catalog.lookup(locale, key), isNot(key));
      }
    }
  });

  test(
    'GivenIdentityDocumentMessages_WhenLookedUp_ThenBothLocalesAreComplete',
    () {
      const keys = <String>{
        'cli.documentUsage',
        'document.syntheticLabel',
        'document.pageTitle',
        'document.openAction',
        'document.localeLabel',
        'document.locale.us',
        'document.locale.br',
        'document.typeLabel',
        'document.type.ssn',
        'document.type.itin',
        'document.type.ein',
        'document.type.cpf',
        'document.type.cnpj',
        'document.type.cnh',
        'document.type.cin',
        'document.cnpjFormatLabel',
        'document.cnpjFormat.numeric',
        'document.cnpjFormat.alphanumeric',
        'document.countLabel',
        'document.semantics',
        'document.generate',
        'document.resultLabel',
        'document.success',
        'document.copy',
        'document.save',
        'document.copied',
        'document.saved',
        'error.document.validation',
        'error.document.processing',
        'error.document.resource',
        'error.document.outputAccess',
        'error.document.clipboardWrite',
      };
      for (final locale in supportedLocaleTags) {
        for (final key in keys) {
          expect(catalog.lookup(locale, key), isNotEmpty);
          expect(catalog.lookup(locale, key), isNot(key));
        }
      }
    },
  );

  test('GivenPersonMessages_WhenLookedUp_ThenBothLocalesAreComplete', () {
    const keys = <String>{
      'cli.personUsage',
      'person.syntheticLabel',
      'person.pageTitle',
      'person.openAction',
      'person.localeLabel',
      'person.locale.us',
      'person.locale.br',
      'person.minAgeLabel',
      'person.maxAgeLabel',
      'person.countLabel',
      'person.semantics',
      'person.generate',
      'person.resultLabel',
      'person.success',
      'person.entryLabel',
      'person.nameLabel',
      'person.birthDateLabel',
      'person.addressLabel',
      'person.phoneLabel',
      'person.emailLabel',
      'person.identifiersLabel',
      'person.copy',
      'person.save',
      'person.copied',
      'person.saved',
      'error.person.validation',
      'error.person.processing',
      'error.person.resource',
      'error.person.outputAccess',
      'error.person.clipboardWrite',
    };
    for (final locale in supportedLocaleTags) {
      for (final key in keys) {
        expect(catalog.lookup(locale, key), isNotEmpty);
        expect(catalog.lookup(locale, key), isNot(key));
      }
    }
  });

  test('GivenUuidMessages_WhenLookedUp_ThenBothLocalesAreComplete', () {
    const keys = <String>{
      'cli.uuidUsage',
      'uuid.pageTitle',
      'uuid.openAction',
      'uuid.versionLabel',
      'uuid.version4',
      'uuid.version7',
      'uuid.representationLabel',
      'uuid.uuidRepresentation',
      'uuid.guidRepresentation',
      'uuid.countLabel',
      'uuid.semantics',
      'uuid.generate',
      'uuid.resultLabel',
      'uuid.success',
      'uuid.copy',
      'uuid.save',
      'uuid.copied',
      'uuid.saved',
      'error.uuid.validation',
      'error.uuid.processing',
      'error.uuid.resource',
      'error.uuid.outputAccess',
      'error.uuid.clipboardWrite',
    };
    for (final locale in supportedLocaleTags) {
      for (final key in keys) {
        expect(catalog.lookup(locale, key), isNotEmpty);
        expect(catalog.lookup(locale, key), isNot(key));
      }
    }
  });

  test('GivenPasswordMessages_WhenLookedUp_ThenBothLocalesAreComplete', () {
    const keys = <String>{
      'cli.passwordUsage',
      'password.pageTitle',
      'password.openAction',
      'password.lengthLabel',
      'password.lowercase',
      'password.uppercase',
      'password.digits',
      'password.symbols',
      'password.semantics',
      'password.generate',
      'password.resultLabel',
      'password.success',
      'password.copy',
      'password.save',
      'password.copied',
      'password.saved',
      'error.password.validation',
      'error.password.processing',
      'error.password.resource',
      'error.password.outputAccess',
      'error.password.clipboardWrite',
    };
    for (final locale in supportedLocaleTags) {
      for (final key in keys) {
        expect(catalog.lookup(locale, key), isNotEmpty);
        expect(catalog.lookup(locale, key), isNot(key));
      }
    }
  });

  test('GivenHashMessages_WhenLookedUp_ThenBothLocalesDescribeLegacySecurityAndAdapters', () {
    for (final locale in supportedLocaleTags) {
      for (final key in const [
        'cli.hashGenerateUsage',
        'hashGenerate.pageTitle',
        'hashGenerate.openAction',
        'hashGenerate.inputLabel',
        'hashGenerate.fileAction',
        'hashGenerate.pasteAction',
        'hashGenerate.algorithmLabel',
        'hashGenerate.submitAction',
        'hashGenerate.outputLabel',
        'hashGenerate.resultSuccess',
        'hashGenerate.copyAction',
        'hashGenerate.saveAction',
        'hashGenerate.copiedResult',
        'hashGenerate.fileSaved',
        'hashGenerate.savedResult',
        'hashGenerate.legacyWarning',
        'error.hashGenerate.validation',
        'error.hashGenerate.resource',
        'error.hashGenerate.fileAccess',
        'error.hashGenerate.inputAccess',
        'error.hashGenerate.interactiveInputAccess',
        'error.hashGenerate.clipboardRead',
        'error.hashGenerate.clipboardWrite',
        'error.hashGenerate.outputAccess',
      ]) {
        expect(catalog.lookup(locale, key), isNotEmpty);
      }
      expect(
        catalog.lookup(locale, 'hashGenerate.legacyWarning'),
        contains(
          locale == 'en'
              ? 'unsuitable for security decisions'
              : 'inadequados para decisões de segurança',
        ),
      );
    }
  });

  test('GivenQrDecodeMessages_WhenLookedUp_ThenBothLocalesAreComplete', () {
    const keys = <String>{
      'cli.qrDecodeUsage',
      'qrDecode.pageTitle',
      'qrDecode.openAction',
      'qrDecode.fileAction',
      'qrDecode.inputReady',
      'qrDecode.submitAction',
      'qrDecode.resultLabel',
      'qrDecode.resultSuccess',
      'qrDecode.formatLabel',
      'qrDecode.dimensionsLabel',
      'qrDecode.inputByteCountLabel',
      'qrDecode.copyAction',
      'qrDecode.saveAction',
      'qrDecode.copied',
      'qrDecode.fileSaved',
      'error.qrDecode.validation',
      'error.qrDecode.decoding',
      'error.qrDecode.resource',
      'error.qrDecode.inputAccess',
      'error.qrDecode.fileAccess',
      'error.qrDecode.clipboardWrite',
      'error.qrDecode.outputAccess',
    };
    for (final locale in supportedLocaleTags) {
      for (final key in keys) {
        expect(catalog.lookup(locale, key), isNotEmpty);
        expect(catalog.lookup(locale, key), isNot(key));
      }
      for (final format in ['PNG', 'JPEG', 'BMP']) {
        expect(catalog.lookup(locale, 'cli.qrDecodeUsage'), contains(format));
      }
    }
  });

  test('GivenQrEncodeCliMessages_WhenLookedUp_ThenLocalesAreComplete', () {
    const keys = <String>{
      'cli.qrEncodeUsage',
      'qrEncode.savedResult',
      'qrEncode.pageTitle',
      'qrEncode.openAction',
      'qrEncode.inputLabel',
      'qrEncode.fileAction',
      'qrEncode.pasteAction',
      'qrEncode.correctionLabel',
      'qrEncode.correction.low',
      'qrEncode.correction.medium',
      'qrEncode.correction.quartile',
      'qrEncode.correction.high',
      'qrEncode.sizeLabel',
      'qrEncode.marginLabel',
      'qrEncode.foregroundLabel',
      'qrEncode.backgroundLabel',
      'qrEncode.submitAction',
      'qrEncode.resultLabel',
      'qrEncode.resultSuccess',
      'qrEncode.previewLabel',
      'qrEncode.versionLabel',
      'qrEncode.outputByteCountLabel',
      'qrEncode.saveAction',
      'qrEncode.fileSaved',
      'error.qrEncode.validation',
      'error.qrEncode.resource',
      'error.qrEncode.inputAccess',
      'error.qrEncode.fileAccess',
      'error.qrEncode.outputAccess',
      'error.qrEncode.clipboardRead',
    };
    for (final locale in supportedLocaleTags) {
      for (final key in keys) {
        expect(catalog.lookup(locale, key), isNotEmpty);
      }
      expect(
        catalog.lookup(locale, 'cli.qrEncodeUsage'),
        contains('chimera qr encode'),
      );
    }
  });

  test('GivenJwtMessages_WhenLookedUp_ThenBothLocalesAreComplete', () {
    const keys = <String>{
      'jwtInspect.headerLabel',
      'jwtInspect.claimsLabel',
      'jwtInspect.verificationLabel',
      'jwtInspect.statusNotRequested',
      'jwtInspect.statusVerified',
      'jwtInspect.statusFailed',
      'jwtInspect.pageTitle',
      'jwtInspect.openAction',
      'jwtInspect.tokenLabel',
      'jwtInspect.keyLabel',
      'jwtInspect.submitAction',
      'jwtInspect.outputLabel',
      'jwtInspect.resultSuccess',
      'jwtInspect.copyAction',
      'jwtInspect.copiedResult',
      'jwtInspect.tokenFileAction',
      'jwtInspect.keyFileAction',
      'jwtInspect.tokenPasteAction',
      'jwtInspect.keyPasteAction',
      'jwtInspect.untrustedWarning',
      'cli.jwtInspectUsage',
      'error.jwtInspect.validation',
      'error.jwtInspect.processing',
      'error.jwtInspect.resource',
      'error.jwtInspect.inputAccess',
      'error.jwtInspect.tokenAccess',
      'error.jwtInspect.keyAccess',
      'error.jwtInspect.clipboardRead',
      'error.jwtInspect.clipboardWrite',
      'error.jwtInspect.interactiveInputAccess',
      'jwtCreate.pageTitle',
      'jwtCreate.openAction',
      'jwtCreate.algorithmLabel',
      'jwtCreate.headerLabel',
      'jwtCreate.claimsLabel',
      'jwtCreate.keyLabel',
      'jwtCreate.submitAction',
      'jwtCreate.outputLabel',
      'jwtCreate.resultSuccess',
      'jwtCreate.copyAction',
      'jwtCreate.saveAction',
      'jwtCreate.copiedResult',
      'jwtCreate.fileSaved',
      'jwtCreate.headerFileAction',
      'jwtCreate.claimsFileAction',
      'jwtCreate.keyFileAction',
      'jwtCreate.headerPasteAction',
      'jwtCreate.claimsPasteAction',
      'jwtCreate.keyPasteAction',
      'cli.jwtCreateUsage',
      'jwtCreate.savedResult',
      'error.jwtCreate.validation',
      'error.jwtCreate.processing',
      'error.jwtCreate.resource',
      'error.jwtCreate.inputAccess',
      'error.jwtCreate.headerAccess',
      'error.jwtCreate.claimsAccess',
      'error.jwtCreate.keyAccess',
      'error.jwtCreate.outputAccess',
      'error.jwtCreate.clipboardRead',
      'error.jwtCreate.clipboardWrite',
      'error.jwtCreate.interactiveInputAccess',
    };
    expect(catalog.keysFor('en'), catalog.keysFor('pt-BR'));
    for (final locale in supportedLocaleTags) {
      expect(catalog.keysFor(locale), containsAll(keys));
      for (final key in keys) {
        expect(catalog.lookup(locale, key), isNot(key));
      }
    }
  });

  test(
    'GivenUrlInteractiveMessages_WhenLookedUp_ThenBothLocalesAreComplete',
    () {
      for (final locale in supportedLocaleTags) {
        for (final name in [
          'pageTitle',
          'openAction',
          'inputLabel',
          'fileAction',
          'pasteAction',
          'modeLabel',
          'modeComponent',
          'modeFull',
          'submitAction',
          'outputLabel',
          'resultSuccess',
          'copyAction',
          'saveAction',
          'copiedResult',
          'fileSaved',
        ]) {
          final key = 'urlEncode.$name';
          expect(catalog.lookup(locale, key), isNot(key));
        }
        for (final name in [
          'clipboardRead',
          'clipboardWrite',
          'interactiveInputAccess',
        ]) {
          final key = 'error.urlEncode.$name';
          expect(catalog.lookup(locale, key), isNot(key));
        }
      }
    },
  );

  test('GivenUrlEncodeCliMessages_WhenLookedUp_ThenBothLocalesAreComplete', () {
    const keys = {
      'cli.urlEncodeUsage',
      'urlEncode.savedResult',
      'error.urlEncode.validation',
      'error.urlEncode.inputAccess',
      'error.urlEncode.fileAccess',
      'error.urlEncode.outputAccess',
      'error.urlEncode.resource',
    };
    expect(catalog.keysFor('en'), catalog.keysFor('pt-BR'));
    for (final locale in supportedLocaleTags) {
      expect(catalog.keysFor(locale), containsAll(keys));
      for (final key in keys) {
        expect(catalog.lookup(locale, key), isNotEmpty);
        expect(catalog.lookup(locale, key), isNot(key));
      }
    }
    expect(
      catalog.lookup('pt-BR', 'error.urlEncode.resource'),
      'A codificação URL excedeu o limite de recursos.',
    );
  });

  test('GivenCipherEncodeMessages_WhenLookedUp_ThenBothLocalesAreComplete', () {
    const keys = {
      'cli.cipherEncodeUsage',
      'cipherEncode.savedResult',
      'error.cipherEncode.validation',
      'error.cipherEncode.inputAccess',
      'error.cipherEncode.fileAccess',
      'error.cipherEncode.outputAccess',
      'error.cipherEncode.resource',
      'error.cipherEncode.processing',
    };
    expect(catalog.keysFor('en'), catalog.keysFor('pt-BR'));
    for (final locale in supportedLocaleTags) {
      expect(catalog.keysFor(locale), containsAll(keys));
      for (final key in keys) {
        expect(catalog.lookup(locale, key), isNotEmpty);
        expect(catalog.lookup(locale, key), isNot(key));
      }
    }
  });

  test(
    'GivenAlphabetEncodeMessages_WhenLookedUp_ThenBothLocalesAreComplete',
    () {
      const keys = {
        'cli.alphabetEncodeUsage',
        'alphabetEncode.savedResult',
        'alphabetEncode.mappingLabel',
        'alphabetEncode.mappingSourcesLabel',
        'error.alphabetEncode.validation',
        'error.alphabetEncode.inputAccess',
        'error.alphabetEncode.fileAccess',
        'error.alphabetEncode.outputAccess',
        'error.alphabetEncode.resource',
        'error.alphabetEncode.processing',
        'alphabetEncode.pageTitle',
        'alphabetEncode.openAction',
        'alphabetEncode.inputLabel',
        'alphabetEncode.fileAction',
        'alphabetEncode.pasteAction',
        'alphabetEncode.alphabetLabel',
        'alphabetEncode.alphabet.morse',
        'alphabetEncode.alphabet.nato',
        'alphabetEncode.alphabet.braille',
        'alphabetEncode.submitAction',
        'alphabetEncode.outputLabel',
        'alphabetEncode.resultSuccess',
        'alphabetEncode.mappingIdLabel',
        'alphabetEncode.mappingEditionLabel',
        'alphabetEncode.mappingSymbolsLabel',
        'alphabetEncode.mappingRulesLabel',
        'alphabetEncode.copyAction',
        'alphabetEncode.saveAction',
        'alphabetEncode.copiedResult',
        'alphabetEncode.fileSaved',
        'error.alphabetEncode.clipboardRead',
        'error.alphabetEncode.clipboardWrite',
        'error.alphabetEncode.interactiveInputAccess',
      };
      expect(catalog.keysFor('en'), catalog.keysFor('pt-BR'));
      for (final locale in supportedLocaleTags) {
        expect(catalog.keysFor(locale), containsAll(keys));
        for (final key in keys) {
          expect(catalog.lookup(locale, key), isNotEmpty);
          expect(catalog.lookup(locale, key), isNot(key));
        }
      }
    },
  );

  test(
    'GivenAlphabetDecodeMessages_WhenLookedUp_ThenBothLocalesAreComplete',
    () {
      const keys = {
        'cli.alphabetDecodeUsage',
        'alphabetDecode.savedResult',
        'alphabetDecode.mappingLabel',
        'alphabetDecode.mappingSourcesLabel',
        'error.alphabetDecode.validation',
        'error.alphabetDecode.inputAccess',
        'error.alphabetDecode.fileAccess',
        'error.alphabetDecode.outputAccess',
        'error.alphabetDecode.resource',
        'error.alphabetDecode.processing',
        'alphabetDecode.pageTitle',
        'alphabetDecode.openAction',
        'alphabetDecode.inputLabel',
        'alphabetDecode.fileAction',
        'alphabetDecode.pasteAction',
        'alphabetDecode.alphabetLabel',
        'alphabetDecode.alphabet.morse',
        'alphabetDecode.alphabet.nato',
        'alphabetDecode.alphabet.braille',
        'alphabetDecode.submitAction',
        'alphabetDecode.outputLabel',
        'alphabetDecode.resultSuccess',
        'alphabetDecode.mappingIdLabel',
        'alphabetDecode.mappingEditionLabel',
        'alphabetDecode.mappingSymbolsLabel',
        'alphabetDecode.mappingRulesLabel',
        'alphabetDecode.copyAction',
        'alphabetDecode.saveAction',
        'alphabetDecode.copiedResult',
        'alphabetDecode.fileSaved',
        'error.alphabetDecode.clipboardRead',
        'error.alphabetDecode.clipboardWrite',
        'error.alphabetDecode.interactiveInputAccess',
      };
      expect(catalog.keysFor('en'), catalog.keysFor('pt-BR'));
      for (final locale in supportedLocaleTags) {
        expect(catalog.keysFor(locale), containsAll(keys));
        for (final key in keys) {
          expect(catalog.lookup(locale, key), isNotEmpty);
          expect(catalog.lookup(locale, key), isNot(key));
        }
      }
    },
  );

  test(
    'GivenCipherEncodeGuiMessages_WhenLookedUp_ThenBothLocalesAreComplete',
    () {
      const keys = <String>{
        'cipherEncode.pageTitle',
        'cipherEncode.openAction',
        'cipherEncode.inputLabel',
        'cipherEncode.fileAction',
        'cipherEncode.pasteAction',
        'cipherEncode.cipherLabel',
        'cipherEncode.cipher.caesar',
        'cipherEncode.cipher.rot13',
        'cipherEncode.cipher.vigenere',
        'cipherEncode.cipher.atbash',
        'cipherEncode.cipher.affine',
        'cipherEncode.cipher.bacon',
        'cipherEncode.cipher.rail-fence',
        'cipherEncode.policyLabel',
        'cipherEncode.policy.preserve',
        'cipherEncode.policy.reject',
        'cipherEncode.shiftLabel',
        'cipherEncode.keyLabel',
        'cipherEncode.aLabel',
        'cipherEncode.bLabel',
        'cipherEncode.railsLabel',
        'cipherEncode.submitAction',
        'cipherEncode.outputLabel',
        'cipherEncode.resultSuccess',
        'cipherEncode.copyAction',
        'cipherEncode.saveAction',
        'cipherEncode.copiedResult',
        'cipherEncode.fileSaved',
        'error.cipherEncode.clipboardRead',
        'error.cipherEncode.clipboardWrite',
        'error.cipherEncode.interactiveInputAccess',
      };

      expect(catalog.keysFor('en'), catalog.keysFor('pt-BR'));
      for (final locale in ['en', 'pt-BR']) {
        expect(catalog.keysFor(locale), containsAll(keys));
        for (final key in keys) {
          expect(catalog.lookup(locale, key), isNotEmpty);
          expect(catalog.lookup(locale, key), isNot(key));
        }
      }
    },
  );

  test('GivenCipherDecodeMessages_WhenLookedUp_ThenBothLocalesAreComplete', () {
    const keys = <String>{
      'cli.cipherDecodeUsage',
      'cipherDecode.savedResult',
      'error.cipherDecode.validation',
      'error.cipherDecode.inputAccess',
      'error.cipherDecode.fileAccess',
      'error.cipherDecode.outputAccess',
      'error.cipherDecode.resource',
      'error.cipherDecode.processing',
      'cipherDecode.pageTitle',
      'cipherDecode.openAction',
      'cipherDecode.inputLabel',
      'cipherDecode.fileAction',
      'cipherDecode.pasteAction',
      'cipherDecode.cipherLabel',
      'cipherDecode.cipher.caesar',
      'cipherDecode.cipher.rot13',
      'cipherDecode.cipher.vigenere',
      'cipherDecode.cipher.atbash',
      'cipherDecode.cipher.affine',
      'cipherDecode.cipher.bacon',
      'cipherDecode.cipher.rail-fence',
      'cipherDecode.policyLabel',
      'cipherDecode.policy.preserve',
      'cipherDecode.policy.reject',
      'cipherDecode.shiftLabel',
      'cipherDecode.keyLabel',
      'cipherDecode.aLabel',
      'cipherDecode.bLabel',
      'cipherDecode.railsLabel',
      'cipherDecode.submitAction',
      'cipherDecode.outputLabel',
      'cipherDecode.resultSuccess',
      'cipherDecode.copyAction',
      'cipherDecode.saveAction',
      'cipherDecode.copiedResult',
      'cipherDecode.fileSaved',
      'error.cipherDecode.clipboardRead',
      'error.cipherDecode.clipboardWrite',
      'error.cipherDecode.interactiveInputAccess',
    };
    expect(catalog.keysFor('en'), catalog.keysFor('pt-BR'));
    for (final locale in supportedLocaleTags) {
      expect(catalog.keysFor(locale), containsAll(keys));
      for (final key in keys) {
        expect(catalog.lookup(locale, key), isNotEmpty);
        expect(catalog.lookup(locale, key), isNot(key));
      }
    }
  });

  test(
    'GivenHtmlInteractiveMessages_WhenLookedUp_ThenBothLocalesAreComplete',
    () {
      for (final locale in supportedLocaleTags) {
        for (final name in [
          'pageTitle',
          'openAction',
          'inputLabel',
          'fileAction',
          'pasteAction',
          'contextLabel',
          'contextAll',
          'contextElement',
          'contextDoubleQuotedAttribute',
          'contextSingleQuotedAttribute',
          'submitAction',
          'outputLabel',
          'resultSuccess',
          'copyAction',
          'saveAction',
          'copiedResult',
          'fileSaved',
        ]) {
          final key = 'htmlEncode.$name';
          expect(catalog.lookup(locale, key), isNot(key));
        }
        for (final name in [
          'clipboardRead',
          'clipboardWrite',
          'interactiveInputAccess',
        ]) {
          final key = 'error.htmlEncode.$name';
          expect(catalog.lookup(locale, key), isNot(key));
        }
      }
    },
  );

  test(
    'GivenHtmlEncodeCliMessages_WhenLookedUp_ThenBothLocalesAreComplete',
    () {
      const keys = {
        'cli.htmlEncodeUsage',
        'htmlEncode.savedResult',
        'error.htmlEncode.validation',
        'error.htmlEncode.inputAccess',
        'error.htmlEncode.fileAccess',
        'error.htmlEncode.outputAccess',
        'error.htmlEncode.resource',
      };
      expect(catalog.keysFor('en'), catalog.keysFor('pt-BR'));
      for (final locale in supportedLocaleTags) {
        expect(catalog.keysFor(locale), containsAll(keys));
        for (final key in keys) {
          expect(catalog.lookup(locale, key), isNotEmpty);
          expect(catalog.lookup(locale, key), isNot(key));
        }
      }
      expect(
        catalog.lookup('pt-BR', 'error.htmlEncode.resource'),
        'A codificação HTML excedeu o limite de recursos.',
      );
    },
  );

  test(
    'GivenHtmlDecodeCliMessages_WhenLookedUp_ThenBothLocalesAreComplete',
    () {
      const keys = {
        'cli.htmlDecodeUsage',
        'htmlDecode.savedResult',
        'error.htmlDecode.validation',
        'error.htmlDecode.inputAccess',
        'error.htmlDecode.fileAccess',
        'error.htmlDecode.outputAccess',
        'error.htmlDecode.resource',
      };
      expect(catalog.keysFor('en'), catalog.keysFor('pt-BR'));
      for (final locale in supportedLocaleTags) {
        expect(catalog.keysFor(locale), containsAll(keys));
        for (final key in keys) {
          expect(catalog.lookup(locale, key), isNotEmpty);
          expect(catalog.lookup(locale, key), isNot(key));
        }
      }
      expect(
        catalog.lookup('pt-BR', 'error.htmlDecode.resource'),
        'A decodificação HTML excedeu o limite de recursos.',
      );
    },
  );

  test('GivenHtmlDecodeInteractiveMessages_WhenLookedUp_ThenBothLocalesAreComplete', () {
    for (final locale in supportedLocaleTags) {
      for (final name in [
        'pageTitle',
        'openAction',
        'inputLabel',
        'fileAction',
        'pasteAction',
        'submitAction',
        'outputLabel',
        'resultSuccess',
        'copyAction',
        'saveAction',
        'copiedResult',
        'fileSaved',
      ]) {
        final key = 'htmlDecode.$name';
        expect(catalog.lookup(locale, key), isNot(key));
      }
      for (final name in [
        'clipboardRead',
        'clipboardWrite',
        'interactiveInputAccess',
      ]) {
        final key = 'error.htmlDecode.$name';
        expect(catalog.lookup(locale, key), isNot(key));
      }
    }
  });

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

  test('GivenGzipDecompressInteractiveMessages_WhenLookedUp_ThenBothLocalesAreComplete', () {
    for (final locale in supportedLocaleTags) {
      for (final name in [
        'pageTitle',
        'openAction',
        'fileAction',
        'modeLabel',
        'textMode',
        'binaryMode',
        'submitAction',
        'copyAction',
        'saveAction',
        'copiedResult',
        'fileSaved',
        'outputLabel',
        'resultSuccess',
        'inputByteCountLabel',
        'outputByteCountLabel',
      ]) {
        final key = 'gzipDecompress.$name';
        expect(catalog.lookup(locale, key), isNot(key));
        expect(catalog.lookup(locale, key), isNotEmpty);
      }
      for (final name in ['interactiveInputAccess', 'clipboardWrite']) {
        final key = 'error.gzipDecompress.$name';
        expect(catalog.lookup(locale, key), isNot(key));
      }
    }
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
      'error.dotnetTag.access',
      "cli.dotnetBuildUsage",
      "cli.dotnetTagUsage",
      "dotnet.both",
      "dotnet.build",
      "dotnet.cancel",
      "dotnet.configuration",
      "dotnet.exitStatus",
      "dotnet.noRestore",
      "dotnet.running",
      "dotnet.solution",
      "dotnet.source",
      "dotnet.succeeded",
      "dotnet.title",
      "dotnetTag.busy",
      "dotnetTag.cancel",
      "dotnetTag.create",
      "dotnetTag.created",
      "dotnetTag.project",
      "dotnetTag.push",
      "dotnetTag.pushed",
      "dotnetTag.remote",
      "dotnetTag.title",
      "error.dotnet.ambiguousSolution",
      "error.dotnet.cancelled",
      "error.dotnet.commandFailed",
      "error.dotnet.invalidPath",
      "error.dotnet.noSolution",
      "error.dotnet.sdkUnavailable",
      "error.dotnet.unsupported",
      "error.dotnet.validation",
      "error.dotnetTag.cancelled",
      "error.dotnetTag.command",
      "error.dotnetTag.conflict",
      "error.dotnetTag.discovery",
      "error.dotnetTag.gitUnavailable",
      "error.dotnetTag.pushFailed",
      "error.dotnetTag.repository",
      "error.dotnetTag.unsupported",
      "error.dotnetTag.validation",
      "error.dotnetTag.version",
      "gzipCompress.fileAction",
      "gzipCompress.fileSaved",
      "gzipCompress.inputByteCountLabel",
      "gzipCompress.inputLabel",
      "gzipCompress.levelLabel",
      "gzipCompress.openAction",
      "gzipCompress.outputByteCountLabel",
      "gzipCompress.outputLabel",
      "gzipCompress.pageTitle",
      "gzipCompress.pasteAction",
      "gzipCompress.resultSuccess",
      "gzipCompress.saveAction",
      "gzipCompress.submitAction",
      "gzipDecompress.binaryMode",
      "gzipDecompress.copiedResult",
      "gzipDecompress.copyAction",
      "gzipDecompress.fileAction",
      "gzipDecompress.fileSaved",
      "gzipDecompress.inputByteCountLabel",
      "gzipDecompress.modeLabel",
      "gzipDecompress.openAction",
      "gzipDecompress.outputByteCountLabel",
      "gzipDecompress.outputLabel",
      "gzipDecompress.pageTitle",
      "gzipDecompress.resultSuccess",
      "gzipDecompress.saveAction",
      "gzipDecompress.submitAction",
      "gzipDecompress.textMode",

      'update.pageTitle',
      'update.openAction',
      'update.description',
      'update.checkAction',
      'update.checking',
      'cli.updateCheckUsage',
      'cli.updateApplyUsage',
      'update.current',
      'update.available',
      'update.applyAction',
      'update.applyConfirmTitle',
      'update.applyConfirmMessage',
      'update.applyCancel',
      'update.applying',
      'update.applied',
      'update.appliedRestart',
      'update.scheduled',
      'cli.updateApplied',
      'cli.updateAppliedRestart',
      'cli.updateScheduled',
      'error.update.checkFailed',
      'error.update.invalidMetadata',
      'error.update.invalidInstalledVersion',
      'error.update.approvalRequired',
      'error.update.unsupportedPackage',
      'error.update.downloadFailed',
      'error.update.checksumFailed',
      'error.update.installFailed',
      'error.update.elevationDenied',
      'error.update.cleanupFailed',
      'cli.personUsage',
      'person.syntheticLabel',
      'person.pageTitle',
      'person.openAction',
      'person.localeLabel',
      'person.locale.us',
      'person.locale.br',
      'person.minAgeLabel',
      'person.maxAgeLabel',
      'person.countLabel',
      'person.semantics',
      'person.generate',
      'person.resultLabel',
      'person.success',
      'person.entryLabel',
      'person.nameLabel',
      'person.birthDateLabel',
      'person.addressLabel',
      'person.phoneLabel',
      'person.emailLabel',
      'person.identifiersLabel',
      'person.copy',
      'person.save',
      'person.copied',
      'person.saved',
      'error.person.validation',
      'error.person.processing',
      'error.person.resource',
      'error.person.outputAccess',
      'error.person.clipboardWrite',
      'cli.loremUsage',
      'lorem.pageTitle',
      'lorem.openAction',
      'lorem.unitLabel',
      'lorem.words',
      'lorem.sentences',
      'lorem.paragraphs',
      'lorem.countLabel',
      'lorem.semantics',
      'lorem.generate',
      'lorem.resultLabel',
      'lorem.success',
      'lorem.copy',
      'lorem.save',
      'lorem.copied',
      'lorem.saved',
      'error.lorem.validation',
      'error.lorem.resource',
      'error.lorem.outputAccess',
      'error.lorem.clipboardWrite',
      'cli.passwordUsage',
      'password.pageTitle',
      'password.openAction',
      'password.lengthLabel',
      'password.lowercase',
      'password.uppercase',
      'password.digits',
      'password.symbols',
      'password.semantics',
      'password.generate',
      'password.resultLabel',
      'password.success',
      'password.copy',
      'password.save',
      'password.copied',
      'password.saved',
      'error.password.validation',
      'error.password.processing',
      'error.password.resource',
      'error.password.outputAccess',
      'error.password.clipboardWrite',
      'cli.cardUsage',
      'card.syntheticLabel',
      'card.pageTitle',
      'card.openAction',
      'card.networkLabel',
      'card.network.visa',
      'card.network.mastercard',
      'card.network.amex',
      'card.network.discover',
      'card.countLabel',
      'card.semantics',
      'card.generate',
      'card.resultLabel',
      'card.success',
      'card.copy',
      'card.save',
      'card.copied',
      'card.saved',
      'error.card.validation',
      'error.card.processing',
      'error.card.resource',
      'error.card.outputAccess',
      'error.card.clipboardWrite',
      'cli.documentUsage',
      'document.syntheticLabel',
      'document.pageTitle',
      'document.openAction',
      'document.localeLabel',
      'document.locale.us',
      'document.locale.br',
      'document.typeLabel',
      'document.type.ssn',
      'document.type.itin',
      'document.type.ein',
      'document.type.cpf',
      'document.type.cnpj',
      'document.type.cnh',
      'document.type.cin',
      'document.cnpjFormatLabel',
      'document.cnpjFormat.numeric',
      'document.cnpjFormat.alphanumeric',
      'document.countLabel',
      'document.semantics',
      'document.generate',
      'document.resultLabel',
      'document.success',
      'document.copy',
      'document.save',
      'document.copied',
      'document.saved',
      'error.document.validation',
      'error.document.processing',
      'error.document.resource',
      'error.document.outputAccess',
      'error.document.clipboardWrite',
      'cli.uuidUsage',
      'uuid.pageTitle',
      'uuid.openAction',
      'uuid.versionLabel',
      'uuid.version4',
      'uuid.version7',
      'uuid.representationLabel',
      'uuid.uuidRepresentation',
      'uuid.guidRepresentation',
      'uuid.countLabel',
      'uuid.semantics',
      'uuid.generate',
      'uuid.resultLabel',
      'uuid.success',
      'uuid.copy',
      'uuid.save',
      'uuid.copied',
      'uuid.saved',
      'error.uuid.validation',
      'error.uuid.processing',
      'error.uuid.resource',
      'error.uuid.outputAccess',
      'error.uuid.clipboardWrite',
      'cli.checksumGenerateUsage',
      'checksumGenerate.pageTitle',
      'checksumGenerate.openAction',
      'checksumGenerate.inputLabel',
      'checksumGenerate.fileAction',
      'checksumGenerate.pasteAction',
      'checksumGenerate.algorithmLabel',
      'checksumGenerate.submitAction',
      'checksumGenerate.outputLabel',
      'checksumGenerate.resultSuccess',
      'checksumGenerate.copyAction',
      'checksumGenerate.saveAction',
      'checksumGenerate.copiedResult',
      'checksumGenerate.fileSaved',
      'checksumGenerate.savedResult',
      'error.checksumGenerate.validation',
      'error.checksumGenerate.resource',
      'error.checksumGenerate.fileAccess',
      'error.checksumGenerate.inputAccess',
      'error.checksumGenerate.interactiveInputAccess',
      'error.checksumGenerate.clipboardRead',
      'error.checksumGenerate.clipboardWrite',
      'error.checksumGenerate.outputAccess',
      'cli.hashGenerateUsage',
      'hashGenerate.pageTitle',
      'hashGenerate.openAction',
      'hashGenerate.inputLabel',
      'hashGenerate.fileAction',
      'hashGenerate.pasteAction',
      'hashGenerate.algorithmLabel',
      'hashGenerate.submitAction',
      'hashGenerate.outputLabel',
      'hashGenerate.resultSuccess',
      'hashGenerate.copyAction',
      'hashGenerate.saveAction',
      'hashGenerate.copiedResult',
      'hashGenerate.fileSaved',
      'hashGenerate.savedResult',
      'hashGenerate.legacyWarning',
      'error.hashGenerate.validation',
      'error.hashGenerate.resource',
      'error.hashGenerate.fileAccess',
      'error.hashGenerate.inputAccess',
      'error.hashGenerate.interactiveInputAccess',
      'error.hashGenerate.clipboardRead',
      'error.hashGenerate.clipboardWrite',
      'error.hashGenerate.outputAccess',

      'cli.qrDecodeUsage',
      'qrDecode.pageTitle',
      'qrDecode.openAction',
      'qrDecode.fileAction',
      'qrDecode.inputReady',
      'qrDecode.submitAction',
      'qrDecode.resultLabel',
      'qrDecode.resultSuccess',
      'qrDecode.formatLabel',
      'qrDecode.dimensionsLabel',
      'qrDecode.inputByteCountLabel',
      'qrDecode.copyAction',
      'qrDecode.saveAction',
      'qrDecode.copied',
      'qrDecode.fileSaved',
      'error.qrDecode.validation',
      'error.qrDecode.decoding',
      'error.qrDecode.resource',
      'error.qrDecode.inputAccess',
      'error.qrDecode.fileAccess',
      'error.qrDecode.clipboardWrite',
      'error.qrDecode.outputAccess',
      'cli.qrEncodeUsage',
      'qrEncode.savedResult',
      'qrEncode.pageTitle',
      'qrEncode.openAction',
      'qrEncode.inputLabel',
      'qrEncode.fileAction',
      'qrEncode.pasteAction',
      'qrEncode.correctionLabel',
      'qrEncode.correction.low',
      'qrEncode.correction.medium',
      'qrEncode.correction.quartile',
      'qrEncode.correction.high',
      'qrEncode.sizeLabel',
      'qrEncode.marginLabel',
      'qrEncode.foregroundLabel',
      'qrEncode.backgroundLabel',
      'qrEncode.submitAction',
      'qrEncode.resultLabel',
      'qrEncode.resultSuccess',
      'qrEncode.previewLabel',
      'qrEncode.versionLabel',
      'qrEncode.outputByteCountLabel',
      'qrEncode.saveAction',
      'qrEncode.fileSaved',
      'error.qrEncode.validation',
      'error.qrEncode.resource',
      'error.qrEncode.inputAccess',
      'error.qrEncode.fileAccess',
      'error.qrEncode.outputAccess',
      'error.qrEncode.clipboardRead',
      'jwtInspect.headerLabel',
      'jwtInspect.claimsLabel',
      'jwtInspect.verificationLabel',
      'jwtInspect.statusNotRequested',
      'jwtInspect.statusVerified',
      'jwtInspect.statusFailed',
      'jwtInspect.pageTitle',
      'jwtInspect.openAction',
      'jwtInspect.tokenLabel',
      'jwtInspect.keyLabel',
      'jwtInspect.submitAction',
      'jwtInspect.outputLabel',
      'jwtInspect.resultSuccess',
      'jwtInspect.copyAction',
      'jwtInspect.copiedResult',
      'jwtInspect.tokenFileAction',
      'jwtInspect.keyFileAction',
      'jwtInspect.tokenPasteAction',
      'jwtInspect.keyPasteAction',
      'jwtInspect.untrustedWarning',
      'cli.jwtInspectUsage',
      'error.jwtInspect.validation',
      'error.jwtInspect.processing',
      'error.jwtInspect.resource',
      'error.jwtInspect.inputAccess',
      'error.jwtInspect.tokenAccess',
      'error.jwtInspect.keyAccess',
      'error.jwtInspect.clipboardRead',
      'error.jwtInspect.clipboardWrite',
      'error.jwtInspect.interactiveInputAccess',
      'jwtCreate.pageTitle',
      'jwtCreate.openAction',
      'jwtCreate.algorithmLabel',
      'jwtCreate.headerLabel',
      'jwtCreate.claimsLabel',
      'jwtCreate.keyLabel',
      'jwtCreate.submitAction',
      'jwtCreate.outputLabel',
      'jwtCreate.resultSuccess',
      'jwtCreate.copyAction',
      'jwtCreate.saveAction',
      'jwtCreate.copiedResult',
      'jwtCreate.fileSaved',
      'jwtCreate.headerFileAction',
      'jwtCreate.claimsFileAction',
      'jwtCreate.keyFileAction',
      'jwtCreate.headerPasteAction',
      'jwtCreate.claimsPasteAction',
      'jwtCreate.keyPasteAction',
      'cli.jwtCreateUsage',
      'jwtCreate.savedResult',
      'error.jwtCreate.validation',
      'error.jwtCreate.processing',
      'error.jwtCreate.resource',
      'error.jwtCreate.inputAccess',
      'error.jwtCreate.headerAccess',
      'error.jwtCreate.claimsAccess',
      'error.jwtCreate.keyAccess',
      'error.jwtCreate.outputAccess',
      'error.jwtCreate.clipboardRead',
      'error.jwtCreate.clipboardWrite',
      'error.jwtCreate.interactiveInputAccess',
      'urlEncode.pageTitle',
      'urlEncode.openAction',
      'urlEncode.inputLabel',
      'urlEncode.fileAction',
      'urlEncode.pasteAction',
      'urlEncode.modeLabel',
      'urlEncode.modeComponent',
      'urlEncode.modeFull',
      'urlEncode.submitAction',
      'urlEncode.outputLabel',
      'urlEncode.resultSuccess',
      'urlEncode.copyAction',
      'urlEncode.saveAction',
      'urlEncode.copiedResult',
      'urlEncode.fileSaved',
      'error.urlEncode.clipboardRead',
      'error.urlEncode.clipboardWrite',
      'error.urlEncode.interactiveInputAccess',
      'cli.urlEncodeUsage',
      'urlEncode.savedResult',
      'error.urlEncode.validation',
      'error.urlEncode.inputAccess',
      'error.urlEncode.fileAccess',
      'error.urlEncode.outputAccess',
      'error.urlEncode.resource',
      'cli.cipherEncodeUsage',
      'cipherEncode.savedResult',
      'error.cipherEncode.validation',
      'error.cipherEncode.inputAccess',
      'error.cipherEncode.fileAccess',
      'error.cipherEncode.outputAccess',
      'error.cipherEncode.resource',
      'error.cipherEncode.processing',
      'cli.alphabetEncodeUsage',
      'alphabetEncode.savedResult',
      'alphabetEncode.mappingLabel',
      'alphabetEncode.mappingSourcesLabel',
      'error.alphabetEncode.validation',
      'error.alphabetEncode.inputAccess',
      'error.alphabetEncode.fileAccess',
      'error.alphabetEncode.outputAccess',
      'error.alphabetEncode.resource',
      'error.alphabetEncode.processing',
      'alphabetEncode.pageTitle',
      'alphabetEncode.openAction',
      'alphabetEncode.inputLabel',
      'alphabetEncode.fileAction',
      'alphabetEncode.pasteAction',
      'alphabetEncode.alphabetLabel',
      'alphabetEncode.alphabet.morse',
      'alphabetEncode.alphabet.nato',
      'alphabetEncode.alphabet.braille',
      'alphabetEncode.submitAction',
      'alphabetEncode.outputLabel',
      'alphabetEncode.resultSuccess',
      'alphabetEncode.mappingIdLabel',
      'alphabetEncode.mappingEditionLabel',
      'alphabetEncode.mappingSymbolsLabel',
      'alphabetEncode.mappingRulesLabel',
      'alphabetEncode.copyAction',
      'alphabetEncode.saveAction',
      'alphabetEncode.copiedResult',
      'alphabetEncode.fileSaved',
      'error.alphabetEncode.clipboardRead',
      'error.alphabetEncode.clipboardWrite',
      'error.alphabetEncode.interactiveInputAccess',
      'cli.alphabetDecodeUsage',
      'alphabetDecode.savedResult',
      'alphabetDecode.mappingLabel',
      'alphabetDecode.mappingSourcesLabel',
      'error.alphabetDecode.validation',
      'error.alphabetDecode.inputAccess',
      'error.alphabetDecode.fileAccess',
      'error.alphabetDecode.outputAccess',
      'error.alphabetDecode.resource',
      'error.alphabetDecode.processing',
      'alphabetDecode.pageTitle',
      'alphabetDecode.openAction',
      'alphabetDecode.inputLabel',
      'alphabetDecode.fileAction',
      'alphabetDecode.pasteAction',
      'alphabetDecode.alphabetLabel',
      'alphabetDecode.alphabet.morse',
      'alphabetDecode.alphabet.nato',
      'alphabetDecode.alphabet.braille',
      'alphabetDecode.submitAction',
      'alphabetDecode.outputLabel',
      'alphabetDecode.resultSuccess',
      'alphabetDecode.mappingIdLabel',
      'alphabetDecode.mappingEditionLabel',
      'alphabetDecode.mappingSymbolsLabel',
      'alphabetDecode.mappingRulesLabel',
      'alphabetDecode.copyAction',
      'alphabetDecode.saveAction',
      'alphabetDecode.copiedResult',
      'alphabetDecode.fileSaved',
      'error.alphabetDecode.clipboardRead',
      'error.alphabetDecode.clipboardWrite',
      'error.alphabetDecode.interactiveInputAccess',
      'cipherEncode.pageTitle',
      'cipherEncode.openAction',
      'cipherEncode.inputLabel',
      'cipherEncode.fileAction',
      'cipherEncode.pasteAction',
      'cipherEncode.cipherLabel',
      'cipherEncode.cipher.caesar',
      'cipherEncode.cipher.rot13',
      'cipherEncode.cipher.vigenere',
      'cipherEncode.cipher.atbash',
      'cipherEncode.cipher.affine',
      'cipherEncode.cipher.bacon',
      'cipherEncode.cipher.rail-fence',
      'cipherEncode.policyLabel',
      'cipherEncode.policy.preserve',
      'cipherEncode.policy.reject',
      'cipherEncode.shiftLabel',
      'cipherEncode.keyLabel',
      'cipherEncode.aLabel',
      'cipherEncode.bLabel',
      'cipherEncode.railsLabel',
      'cipherEncode.submitAction',
      'cipherEncode.outputLabel',
      'cipherEncode.resultSuccess',
      'cipherEncode.copyAction',
      'cipherEncode.saveAction',
      'cipherEncode.copiedResult',
      'cipherEncode.fileSaved',
      'error.cipherEncode.clipboardRead',
      'error.cipherEncode.clipboardWrite',
      'error.cipherEncode.interactiveInputAccess',
      'cli.cipherDecodeUsage',
      'cipherDecode.savedResult',
      'error.cipherDecode.validation',
      'error.cipherDecode.inputAccess',
      'error.cipherDecode.fileAccess',
      'error.cipherDecode.outputAccess',
      'error.cipherDecode.resource',
      'error.cipherDecode.processing',
      'cipherDecode.pageTitle',
      'cipherDecode.openAction',
      'cipherDecode.inputLabel',
      'cipherDecode.fileAction',
      'cipherDecode.pasteAction',
      'cipherDecode.cipherLabel',
      'cipherDecode.cipher.caesar',
      'cipherDecode.cipher.rot13',
      'cipherDecode.cipher.vigenere',
      'cipherDecode.cipher.atbash',
      'cipherDecode.cipher.affine',
      'cipherDecode.cipher.bacon',
      'cipherDecode.cipher.rail-fence',
      'cipherDecode.policyLabel',
      'cipherDecode.policy.preserve',
      'cipherDecode.policy.reject',
      'cipherDecode.shiftLabel',
      'cipherDecode.keyLabel',
      'cipherDecode.aLabel',
      'cipherDecode.bLabel',
      'cipherDecode.railsLabel',
      'cipherDecode.submitAction',
      'cipherDecode.outputLabel',
      'cipherDecode.resultSuccess',
      'cipherDecode.copyAction',
      'cipherDecode.saveAction',
      'cipherDecode.copiedResult',
      'cipherDecode.fileSaved',
      'error.cipherDecode.clipboardRead',
      'error.cipherDecode.clipboardWrite',
      'error.cipherDecode.interactiveInputAccess',
      'htmlEncode.pageTitle',
      'htmlEncode.openAction',
      'htmlEncode.inputLabel',
      'htmlEncode.fileAction',
      'htmlEncode.pasteAction',
      'htmlEncode.contextLabel',
      'htmlEncode.contextAll',
      'htmlEncode.contextElement',
      'htmlEncode.contextDoubleQuotedAttribute',
      'htmlEncode.contextSingleQuotedAttribute',
      'htmlEncode.submitAction',
      'htmlEncode.outputLabel',
      'htmlEncode.resultSuccess',
      'htmlEncode.copyAction',
      'htmlEncode.saveAction',
      'htmlEncode.copiedResult',
      'htmlEncode.fileSaved',
      'error.htmlEncode.clipboardRead',
      'error.htmlEncode.clipboardWrite',
      'error.htmlEncode.interactiveInputAccess',
      'cli.htmlEncodeUsage',
      'htmlEncode.savedResult',
      'error.htmlEncode.validation',
      'error.htmlEncode.inputAccess',
      'error.htmlEncode.fileAccess',
      'error.htmlEncode.outputAccess',
      'error.htmlEncode.resource',
      'htmlDecode.pageTitle',
      'htmlDecode.openAction',
      'htmlDecode.inputLabel',
      'htmlDecode.fileAction',
      'htmlDecode.pasteAction',
      'htmlDecode.submitAction',
      'htmlDecode.outputLabel',
      'htmlDecode.resultSuccess',
      'htmlDecode.copyAction',
      'htmlDecode.saveAction',
      'htmlDecode.copiedResult',
      'htmlDecode.fileSaved',
      'error.htmlDecode.clipboardRead',
      'error.htmlDecode.clipboardWrite',
      'error.htmlDecode.interactiveInputAccess',
      'cli.htmlDecodeUsage',
      'htmlDecode.savedResult',
      'error.htmlDecode.validation',
      'error.htmlDecode.inputAccess',
      'error.htmlDecode.fileAccess',
      'error.htmlDecode.outputAccess',
      'error.htmlDecode.resource',
      'urlDecode.pageTitle',
      'urlDecode.openAction',
      'urlDecode.inputLabel',
      'urlDecode.fileAction',
      'urlDecode.pasteAction',
      'urlDecode.submitAction',
      'urlDecode.outputLabel',
      'urlDecode.resultSuccess',
      'urlDecode.copyAction',
      'urlDecode.saveAction',
      'urlDecode.copiedResult',
      'urlDecode.fileSaved',
      'error.urlDecode.clipboardRead',
      'error.urlDecode.clipboardWrite',
      'error.urlDecode.interactiveInputAccess',
      'cli.urlDecodeUsage',
      'urlDecode.savedResult',
      'error.urlDecode.validation',
      'error.urlDecode.inputAccess',
      'error.urlDecode.fileAccess',
      'error.urlDecode.outputAccess',
      'error.urlDecode.resource',
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
      for (final name in [
        'pageTitle',
        'openAction',
        'fileAction',
        'modeLabel',
        'textMode',
        'binaryMode',
        'submitAction',
        'copyAction',
        'saveAction',
        'copiedResult',
        'fileSaved',
        'outputLabel',
        'resultSuccess',
        'inputByteCountLabel',
        'outputByteCountLabel',
      ])
        'gzipDecompress.$name',
      'error.gzipDecompress.interactiveInputAccess',
      'error.gzipDecompress.clipboardWrite',
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
      'theme.title',
      'theme.description',
      'theme.label',
      'theme.light',
      'theme.dark',
      'theme.saving',
      'theme.saved',
      'theme.notSaved',
      'language.title',
      'language.description',
      'language.label',
      'language.en',
      'language.pt-BR',
      'language.saving',
      'language.saved',
      'language.notSaved',
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
