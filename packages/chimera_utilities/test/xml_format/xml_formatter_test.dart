import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart' as xml;

void main() {
  group('XmlFormatter', () {
    test('GivenNestedDocument_WhenFormatted_ThenIndentationIsStable', () {
      final result = const XmlFormatter().format(
        const XmlFormatRequest(
          source: '<root><person id="1"><name>Ada</name></person></root>',
          indent: 2,
        ),
      );

      expect(
        result.formatted,
        '<root>\n'
        '  <person id="1">\n'
        '    <name>Ada</name>\n'
        '  </person>\n'
        '</root>',
      );
      expect(result.indent, 2);
    });

    test('GivenFourSpaceIndent_WhenFormatted_ThenFourSpacesAreUsed', () {
      final result = const XmlFormatter().format(
        const XmlFormatRequest(source: '<a><b><c/></b></a>', indent: 4),
      );

      expect(result.formatted, contains('\n        <c/>'));
    });

    test('GivenXmlFeatures_WhenFormatted_ThenDocumentMeaningIsPreserved', () {
      const source =
          '<?xml version="1.0"?><!DOCTYPE root><root xmlns:x="urn:x">'
          '<!--note--><?work now?><x:item a="&amp;"><![CDATA[a < b]]></x:item>'
          '</root>';

      final result = const XmlFormatter().format(
        const XmlFormatRequest(source: source, indent: 2),
      );

      final reparsed = xml.XmlDocument.parse(result.formatted);
      expect(reparsed.rootElement.name.qualified, 'root');
      expect(reparsed.rootElement.getAttribute('xmlns:x'), 'urn:x');
      expect(result.formatted, contains('<!--note-->'));
      expect(result.formatted, contains('<?work now?>'));
      expect(result.formatted, contains('<x:item a="&amp;">'));
      expect(result.formatted, contains('<![CDATA[a < b]]>'));
    });

    test('GivenMixedContent_WhenFormatted_ThenTextWhitespaceIsPreserved', () {
      const source = '<p>Hello <b>bold</b> and <i>italic</i>.</p>';

      final result = const XmlFormatter().format(
        const XmlFormatRequest(source: source, indent: 2),
      );

      expect(result.formatted, source);
    });

    test('GivenNonXmlWhitespace_WhenFormatted_ThenTextIsPreserved', () {
      const source = '<root>\u00a0<child/>\ufeff</root>';

      final result = const XmlFormatter().format(
        const XmlFormatRequest(source: source, indent: 2),
      );

      expect(result.formatted, source);
    });

    test('GivenCdataContent_WhenFormatted_ThenNoTextIsAdded', () {
      const source = '<root><![CDATA[a < b]]></root>';

      final result = const XmlFormatter().format(
        const XmlFormatRequest(source: source, indent: 2),
      );

      expect(result.formatted, source);
    });

    test('GivenDoctypeSubset_WhenFormatted_ThenItIsRejectedSafely', () {
      for (final source in <String>[
        '<!DOCTYPE root [<!ENTITY author "Ada">]><root>&author;</root>',
        '<!DOCTYPE root SYSTEM "https://example.test/root.dtd"><root/>',
        '<!DOCTYPE root [<!-- <!ENTITY ghost "x"> -->]><root>&ghost;</root>',
      ]) {
        expect(
          () => const XmlFormatter().format(
            XmlFormatRequest(source: source, indent: 2),
          ),
          throwsA(
            isA<XmlFormatException>().having(
              (error) => error.code,
              'code',
              'xml-format.invalid-xml',
            ),
          ),
          reason: source,
        );
      }
    });

    test('GivenXmlSpacePreserve_WhenFormatted_ThenSubtreeIsUnchanged', () {
      const source = '<root><pre xml:space="preserve"> a\n  b </pre></root>';

      final result = const XmlFormatter().format(
        const XmlFormatRequest(source: source, indent: 2),
      );

      expect(
        result.formatted,
        '<root>\n  <pre xml:space="preserve"> a\n  b </pre>\n</root>',
      );
    });

    test('GivenEncodedXmlSpace_WhenFormatted_ThenSubtreeIsUnchanged', () {
      const source =
          '<root><pre xml:space="&#112;reserve"> a\n  b </pre></root>';

      final result = const XmlFormatter().format(
        const XmlFormatRequest(source: source, indent: 2),
      );

      expect(
        result.formatted,
        '<root>\n  <pre xml:space="&#112;reserve"> a\n  b </pre>\n</root>',
      );
    });

    test('GivenNonUtf8Declaration_WhenFormatted_ThenUtf8IsDeclared', () {
      final result = const XmlFormatter().format(
        const XmlFormatRequest(
          source: '<?xml version="1.0" encoding="UTF-16"?><root/>',
          indent: 2,
        ),
      );

      expect(
        result.formatted,
        startsWith('<?xml version="1.0" encoding="UTF-8"?>'),
      );
    });

    test('GivenMalformedLexicalForms_WhenFormatted_ThenTheyAreRejected', () {
      for (final source in <String>[
        'payload<root/>',
        '<root/>payload',
        '<root>bad ]]> text</root>',
        '<root>AT&T</root>',
        '<root value=test/>',
        '<root value/>',
        '<root value="a" value="b"/>',
        '<root><!-- bad -- comment --></root>',
        '<root>&unknown;</root>',
        '<root>&#0;</root>',
        '<root>&#X41;</root>',
        '<root>&#+65;</root>',
        '<root>&#x+41;</root>',
        '\u00a0<root/>',
        '<root/>\ufeff',
      ]) {
        expect(
          () => const XmlFormatter().format(
            XmlFormatRequest(source: source, indent: 2),
          ),
          throwsA(
            isA<XmlFormatException>().having(
              (error) => error.code,
              'code',
              'xml-format.invalid-xml',
            ),
          ),
          reason: source,
        );
      }
    });

    test('GivenMalformedDeclaration_WhenFormatted_ThenItIsRejected', () {
      for (final source in <String>[
        '<?xml?><root/>',
        '<?xml foo="bar"?><root/>',
        '<?xml version="1.0" version="1.0"?><root/>',
        '<?xml version=1.0?><root/>',
        '<?xml version="2.0"?><root/>',
        '<?xml version="1.0" standalone="maybe"?><root/>',
        '<?xml encoding="UTF-8" version="1.0"?><root/>',
        '<!--before--><?xml version="1.0"?><root/>',
      ]) {
        expect(
          () => const XmlFormatter().format(
            XmlFormatRequest(source: source, indent: 2),
          ),
          throwsA(
            isA<XmlFormatException>().having(
              (error) => error.code,
              'code',
              'xml-format.invalid-xml',
            ),
          ),
          reason: source,
        );
      }
    });

    test('GivenInvalidNamespaces_WhenFormatted_ThenTheyAreRejected', () {
      for (final source in <String>[
        '<root xmlns:a="urn:x" xmlns:b="urn:x" a:id="1" b:id="2"/>',
        '<root xmlns:xml="urn:wrong"/>',
        '<root xmlns:p="http://www.w3.org/XML/1998/namespace"/>',
        '<root xmlns="http://www.w3.org/2000/xmlns/"/>',
        '<root xmlns:xmlns="urn:x"/>',
        '<root xmlns:1bad="urn:x"/>',
        '<root xmlns:a:b="urn:x"/>',
        '<root xmlns:a="urn:x"><a:b:c/></root>',
        '<root xmlns:a="urn:x"><a:1/></root>',
        '<root xmlns:a="urn:x" a:.value="1"/>',
        '<xmlns:root/>',
        '<root xmlns:p="http://www.w3.org/XML/1998/name&#115;pace"/>',
        '<root xmlns:a="urn:x" xmlns:b="urn:&#x78;" a:id="1" b:id="2"/>',
      ]) {
        expect(
          () => const XmlFormatter().format(
            XmlFormatRequest(source: source, indent: 2),
          ),
          throwsA(
            isA<XmlFormatException>().having(
              (error) => error.code,
              'code',
              'xml-format.invalid-xml',
            ),
          ),
          reason: source,
        );
      }
    });

    test('GivenEncodedXmlNamespace_WhenFormatted_ThenItIsAccepted', () {
      const source =
          '<root xmlns:xml="http://www.w3.org/XML/1998/name&#115;pace" '
          'xml:lang="en"/>';

      final result = const XmlFormatter().format(
        const XmlFormatRequest(source: source, indent: 2),
      );

      expect(result.formatted, source);
    });

    test(
      'GivenDefaultNamespaceAndUnprefixedAttribute_WhenFormatted_ThenItIsValid',
      () {
        const source = '<r xmlns="urn:x" xmlns:p="urn:x" id="1" p:id="2"/>';

        final result = const XmlFormatter().format(
          const XmlFormatRequest(source: source, indent: 2),
        );

        expect(result.formatted, source);
      },
    );

    test('GivenCarriageReturn_WhenInvalidXml_ThenLocationUsesNextLine', () {
      expect(
        () => const XmlFormatter().format(
          const XmlFormatRequest(
            source: '<root>\r<child value=test/></root>',
            indent: 2,
          ),
        ),
        throwsA(
          isA<XmlFormatException>()
              .having((error) => error.line, 'line', 2)
              .having((error) => error.column, 'column', 14),
        ),
      );
    });

    test('GivenInvalidIndent_WhenFormatted_ThenValidationFailureIsThrown', () {
      expect(
        () => const XmlFormatter().format(
          const XmlFormatRequest(source: '<root/>', indent: 3),
        ),
        throwsA(
          isA<XmlFormatException>().having(
            (error) => error.code,
            'code',
            'xml-format.invalid-indent',
          ),
        ),
      );
    });

    test('GivenMalformedXml_WhenFormatted_ThenSafeLocationIsReturned', () {
      expect(
        () => const XmlFormatter().format(
          const XmlFormatRequest(source: '<root>\n<secret></root>', indent: 2),
        ),
        throwsA(
          isA<XmlFormatException>()
              .having((error) => error.code, 'code', 'xml-format.invalid-xml')
              .having((error) => error.offset, 'offset', isNotNull)
              .having((error) => error.line, 'line', 2)
              .having((error) => error.column, 'column', isNotNull)
              .having((error) => error.reason, 'reason', 'malformed-xml'),
        ),
      );
    });

    test(
      'GivenResourceBudgetExceeded_WhenFormatted_ThenNoResultIsReturned',
      () {
        final cases = <XmlFormatter, String>{
          const XmlFormatter(maxSourceChars: 1): '<root/>',
          const XmlFormatter(maxNodes: 1): '<root><child/></root>',
          const XmlFormatter(maxDepth: 1): '<root><child/></root>',
          const XmlFormatter(maxOutputChars: 1): '<root/>',
        };

        for (final entry in cases.entries) {
          expect(
            () => entry.key.format(
              XmlFormatRequest(source: entry.value, indent: 2),
            ),
            throwsA(
              isA<XmlFormatException>()
                  .having(
                    (error) => error.kind,
                    'kind',
                    XmlFormatFailureKind.resource,
                  )
                  .having(
                    (error) => error.code,
                    'code',
                    'xml-format.resource-limit',
                  ),
            ),
          );
        }
      },
    );

    test('GivenManyAttributes_WhenNodeBudgetReached_ThenParsingStops', () {
      expect(
        () => const XmlFormatter(maxNodes: 2).format(
          const XmlFormatRequest(source: '<root a="1" b="2"/>', indent: 2),
        ),
        throwsA(
          isA<XmlFormatException>().having(
            (error) => error.code,
            'code',
            'xml-format.resource-limit',
          ),
        ),
      );
    });

    test('GivenDeepInput_WhenDepthBudgetReached_ThenParsingStops', () {
      final source = '${'<a>' * 1000}${'</a>' * 1000}';

      expect(
        () =>
            const XmlFormatter(maxDepth: 10)
                .format(XmlFormatRequest(source: source, indent: 2)),
        throwsA(
          isA<XmlFormatException>().having(
            (error) => error.code,
            'code',
            'xml-format.resource-limit',
          ),
        ),
      );
    });
  });
}
