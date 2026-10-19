import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:test/test.dart';

void main() {
  for (final locale in ['en', 'pt-BR']) {
    test(
      'Given${locale}UrlDecode_WhenMessagesLoaded_ThenAllAdapterMessagesExist',
      () {
        const catalog = MessageCatalog();
        for (final key in [
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
          'savedResult',
        ]) {
          expect(
            catalog.lookup(locale, 'urlDecode.$key'),
            isNot('urlDecode.$key'),
          );
        }
        for (final key in [
          'validation',
          'inputAccess',
          'fileAccess',
          'outputAccess',
          'resource',
          'clipboardRead',
          'clipboardWrite',
          'interactiveInputAccess',
        ]) {
          expect(
            catalog.lookup(locale, 'error.urlDecode.$key'),
            isNot('error.urlDecode.$key'),
          );
        }
        expect(
          catalog.lookup(locale, 'cli.urlDecodeUsage'),
          contains('chimera url decode'),
        );
      },
    );
  }
}
