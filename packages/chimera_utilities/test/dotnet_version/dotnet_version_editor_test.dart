import 'dart:convert';

import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  const editor = DotnetVersionEditor();
  List<int> bytes(String xml) => utf8.encode(xml);
  test('GivenExplicitVersion_WhenEdited_ThenOnlyNumericContentChanges', () {
    const xml =
        '<?xml version="1.0" encoding="utf-8"?>\r\n<Project Sdk="Microsoft.NET.Sdk">\r\n  <!-- keep -->\r\n  <PropertyGroup Label="one"><Version Condition="true"> 1.2.3 </Version><Description>Olá &amp; hello</Description></PropertyGroup>\r\n</Project>\r\n';
    final result = editor.edit(bytes(xml), version: '9.8.7');
    expect(utf8.decode(result.bytes), xml.replaceFirst('1.2.3', '9.8.7'));
    expect(result.previousVersion, '1.2.3');
    expect(result.version, '9.8.7');
  });
  for (final entry in {
    'major': '2.0.0',
    'minor': '1.3.0',
    'patch': '1.2.4',
  }.entries) {
    test('GivenExistingVersion_When${entry.key}Increment_ThenCorrectReset', () {
      final result = editor.edit(
        bytes(
          '<Project><PropertyGroup><Version>1.2.3</Version></PropertyGroup></Project>',
        ),
        increment: entry.key,
      );
      expect(result.version, entry.value);
    });
  }
  test('GivenAbsentVersion_WhenExplicit_ThenInsertAfterPackageIdPreservingRest', () {
    const xml =
        '<Project>\n  <PropertyGroup>\n    <PackageId>Package</PackageId>\n    <!-- keep -->\n  </PropertyGroup>\n</Project>';
    final result = editor.edit(bytes(xml), version: '1.0.0');
    expect(
      utf8.decode(result.bytes),
      xml.replaceFirst(
        '</PackageId>',
        '</PackageId>\n    <Version>1.0.0</Version>',
      ),
    );
    expect(result.previousVersion, isNull);
  });
  test(
    'GivenNoGroupOrSelfClosingNodes_WhenExplicit_ThenValidVersionInserted',
    () {
      for (final xml in [
        '<Project/>',
        '<Project><ItemGroup /></Project>',
        '<Project><PropertyGroup Label="keep" /></Project>',
        '<Project><PropertyGroup><Version /></PropertyGroup></Project>',
      ]) {
        final result = editor.edit(bytes(xml), version: '3.2.1');
        expect(editor.readVersion(result.bytes), '3.2.1');
      }
    },
  );
  test('GivenNamespacesCommentsAndCdata_WhenEdited_ThenUnrelatedMarkupPreserved', () {
    const xml =
        '<p:Project xmlns:p="http://schemas.microsoft.com/developer/msbuild/2003"><p:PropertyGroup><p:Version><!--keep--><![CDATA[1.2.3]]></p:Version></p:PropertyGroup></p:Project>';
    expect(
      utf8.decode(editor.edit(bytes(xml), increment: 'patch').bytes),
      xml.replaceFirst('1.2.3', '1.2.4'),
    );
  });
  test('GivenInvalidVersionOrIncrement_WhenEdited_ThenRejectWithoutOutput', () {
    const xml =
        '<Project><PropertyGroup><Version>1.2.3</Version></PropertyGroup></Project>';
    for (final version in [
      '',
      '1.2',
      '1.2.3-preview',
      '-1.2.3',
      '1.2.3.4',
      ' 1.2.3',
    ]) {
      expect(
        () => editor.edit(bytes(xml), version: version),
        throwsA(isA<DotnetVersionException>()),
      );
    }
    expect(
      () => editor.edit(bytes(xml), version: '1.0.0', increment: 'major'),
      throwsA(isA<DotnetVersionException>()),
    );
    expect(
      () => editor.edit(bytes(xml)),
      throwsA(isA<DotnetVersionException>()),
    );
    expect(
      () => editor.edit(bytes('<Project/>'), increment: 'patch'),
      throwsA(isA<DotnetVersionException>()),
    );
    expect(
      () => editor.edit(bytes(xml), increment: 'unknown'),
      throwsA(isA<DotnetVersionException>()),
    );
  });
  test('GivenMalformedOrAmbiguousXml_WhenEdited_ThenRejected', () {
    for (final xml in [
      '<Project>',
      '<Other/>',
      '<Project><PropertyGroup><Version>1.0.0</Version><Version>2.0.0</Version></PropertyGroup></Project>',
      '<!DOCTYPE Project SYSTEM "file:///etc/passwd"><Project/>',
      '<Project><PropertyGroup><Version><Value>1.0.0</Value></Version></PropertyGroup></Project>',
    ]) {
      expect(
        () => editor.edit(bytes(xml), version: '1.0.0'),
        throwsA(isA<DotnetVersionException>()),
      );
    }
  });
  test('GivenUtf8Bom_WhenEdited_ThenBomAndUnicodePreserved', () {
    const xml =
        '<Project><PropertyGroup><Version>1.2.3</Version><Description>Olá 😀</Description></PropertyGroup></Project>';
    final original = [0xef, 0xbb, 0xbf, ...bytes(xml)];
    expect(editor.edit(original, increment: 'patch').bytes, [
      0xef,
      0xbb,
      0xbf,
      ...bytes(xml.replaceFirst('1.2.3', '1.2.4')),
    ]);
  });
  for (final little in [true, false]) {
    test('GivenUtf16${little}_WhenEdited_ThenEncodingAndDeclarationPreserved', () {
      const xml =
          '<?xml version="1.0" encoding="utf-16"?><Project><PropertyGroup><Version>1.2.3</Version><Description>Olá 😀</Description></PropertyGroup></Project>';
      final original = encodeUtf16(xml, little);
      expect(
        editor.edit(original, increment: 'patch').bytes,
        encodeUtf16(xml.replaceFirst('1.2.3', '1.2.4'), little),
      );
    });
  }
  test('GivenUnsupportedEncodingOrCorruptBytes_WhenEdited_ThenRejected', () {
    expect(
      () => editor.edit(
        bytes('<?xml version="1.0" encoding="iso-8859-1"?><Project/>'),
        version: '1.0.0',
      ),
      throwsA(isA<DotnetVersionException>()),
    );
    expect(
      () => editor.edit([0xff, 0xfe, 0x41], version: '1.0.0'),
      throwsA(isA<DotnetVersionException>()),
    );
  });
}

List<int> encodeUtf16(String source, bool little) => [
  if (little) ...[0xff, 0xfe] else ...[0xfe, 0xff],
  for (final unit in source.codeUnits) ...[
    if (little) ...[unit & 0xff, unit >> 8] else ...[unit >> 8, unit & 0xff],
  ],
];
