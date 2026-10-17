import 'package:xml/xml.dart' as xml;
import 'package:xml/xml_events.dart' as events;

enum XmlFormatFailureKind { validation, resource }

final class XmlFormatException implements Exception {
  const XmlFormatException({
    required this.kind,
    required this.code,
    this.offset,
    this.line,
    this.column,
    this.reason,
  });

  final XmlFormatFailureKind kind;
  final String code;
  final int? offset;
  final int? line;
  final int? column;
  final String? reason;
}

final class XmlFormatRequest {
  const XmlFormatRequest({required this.source, required this.indent});

  final String source;
  final int indent;
}

final class XmlFormatResult {
  const XmlFormatResult({required this.formatted, required this.indent});

  final String formatted;
  final int indent;
}

final class XmlFormatter {
  static const _entityMapping = xml.XmlNullEntityMapping();
  static const _predefinedEntities = <String>{
    'amp',
    'apos',
    'gt',
    'lt',
    'quot',
  };
  static const _xmlNamespace = 'http://www.w3.org/XML/1998/namespace';
  static const _xmlnsNamespace = 'http://www.w3.org/2000/xmlns/';
  static final _encodingName = RegExp(r'^[A-Za-z][A-Za-z0-9._-]*$');

  const XmlFormatter({
    this.maxSourceChars = 4000000,
    this.maxNodes = 100000,
    this.maxDepth = 100,
    this.maxOutputChars = 4000000,
  }) : assert(maxSourceChars >= 0, 'maxSourceChars must not be negative'),
       assert(maxNodes >= 0, 'maxNodes must not be negative'),
       assert(maxDepth >= 0, 'maxDepth must not be negative'),
       assert(maxOutputChars >= 0, 'maxOutputChars must not be negative');

  final int maxSourceChars;
  final int maxNodes;
  final int maxDepth;
  final int maxOutputChars;

  XmlFormatResult format(XmlFormatRequest request) {
    if (request.indent != 2 && request.indent != 4) {
      throw const XmlFormatException(
        kind: XmlFormatFailureKind.validation,
        code: 'xml-format.invalid-indent',
      );
    }
    if (request.source.length > maxSourceChars) _throwResourceLimit();

    try {
      _validateBudgets(request.source);
      final document = xml.XmlDocument.parse(
        request.source,
        entityMapping: _entityMapping,
      );
      final declaration = document.declaration;
      if (declaration?.encoding != null) declaration!.encoding = 'UTF-8';
      if (document.doctypeElement case final doctype?) {
        if (doctype.name != document.rootElement.name.qualified) {
          _throwInvalidXml(request.source, request.source.indexOf('<!DOCTYPE'));
        }
      }
      final sink = _BoundedXmlStringSink(maxOutputChars);
      final writer = xml.XmlPrettyWriter(
        sink,
        entityMapping: _entityMapping,
        indent: ' ' * request.indent,
        preserveWhitespace: _preserveWhitespace,
      );
      writer.visit(document);
      return XmlFormatResult(
        formatted: sink.toString(),
        indent: request.indent,
      );
    } on XmlFormatException {
      rethrow;
    } on xml.XmlFormatException catch (error) {
      throw XmlFormatException(
        kind: XmlFormatFailureKind.validation,
        code: 'xml-format.invalid-xml',
        offset: error.offset,
        line: error.line == 0 ? null : error.line,
        column: error.column == 0 ? null : error.column,
        reason: 'malformed-xml',
      );
    } on xml.XmlException {
      throw const XmlFormatException(
        kind: XmlFormatFailureKind.validation,
        code: 'xml-format.invalid-xml',
        reason: 'malformed-xml',
      );
    }
  }

  void _validateBudgets(String source) {
    _validateCharacters(source);
    var nodes = 0;
    var depth = 0;
    for (final event in events.parseEvents(
      source,
      entityMapping: _entityMapping,
      validateNesting: true,
      validateNamespace: true,
      validateDocument: true,
      withBuffer: true,
      withLocation: true,
      withNamespace: true,
    )) {
      nodes++;
      if (event is events.XmlStartElementEvent) {
        nodes += event.attributes.length;
      } else if (event is events.XmlDeclarationEvent) {
        nodes += event.attributes.length;
      }
      if (nodes > maxNodes) _throwResourceLimit();
      if (event is events.XmlDeclarationEvent) {
        _validateDeclaration(
          source.substring(event.start!, event.stop!),
          source: source,
          sourceOffset: event.start!,
        );
      } else if (event is events.XmlDoctypeEvent) {
        if (event.externalId != null || event.internalSubset != null) {
          _throwInvalidXml(source, event.start);
        }
      } else if (event is events.XmlCommentEvent) {
        if (event.value.contains('--') || event.value.endsWith('-')) {
          _throwInvalidXml(source, event.start);
        }
      } else if (event is events.XmlProcessingEvent) {
        if (event.target.toLowerCase() == 'xml') {
          _throwInvalidXml(source, event.start);
        }
      } else if (event is events.XmlTextEvent) {
        final cdataEnd = event.value.indexOf(']]>');
        if (cdataEnd >= 0) {
          _throwInvalidXml(source, (event.start ?? 0) + cdataEnd);
        }
        if (depth == 0 && _containsNonXmlWhitespace(event.value)) {
          final firstContent = event.value.codeUnits.indexWhere(
            (codeUnit) => !_isWhitespace(codeUnit),
          );
          _throwInvalidXml(source, (event.start ?? 0) + firstContent);
        }
        _validateEntityReferences(
          event.value,
          source: source,
          sourceOffset: event.start ?? 0,
        );
      } else if (event is events.XmlCDATAEvent && depth == 0) {
        _throwInvalidXml(source, event.start);
      } else if (event is events.XmlStartElementEvent) {
        _validateStartTag(
          source.substring(event.start!, event.stop!),
          source: source,
          sourceOffset: event.start!,
        );
        _validateNamespaces(event, source);
        depth++;
        if (depth > maxDepth) _throwResourceLimit();
        if (event.isSelfClosing) depth--;
      } else if (event is events.XmlEndElementEvent) {
        depth--;
      }
    }
  }

  void _validateDeclaration(
    String declaration, {
    required String source,
    required int sourceOffset,
  }) {
    if (sourceOffset != 0 || !declaration.startsWith('<?xml')) {
      _throwInvalidXml(source, sourceOffset);
    }
    var index = 5;
    final attributes = <String, String>{};
    final order = <String>[];
    while (index < declaration.length) {
      final whitespaceStart = index;
      while (index < declaration.length &&
          _isWhitespace(declaration.codeUnitAt(index))) {
        index++;
      }
      if (index + 1 < declaration.length &&
          declaration.codeUnitAt(index) == 0x3F &&
          declaration.codeUnitAt(index + 1) == 0x3E) {
        break;
      }
      if (index == whitespaceStart) {
        _throwInvalidXml(source, sourceOffset + index);
      }

      final nameStart = index;
      while (index < declaration.length &&
          !_isWhitespace(declaration.codeUnitAt(index)) &&
          declaration.codeUnitAt(index) != 0x3D) {
        index++;
      }
      final name = declaration.substring(nameStart, index);
      while (index < declaration.length &&
          _isWhitespace(declaration.codeUnitAt(index))) {
        index++;
      }
      if (name.isEmpty ||
          attributes.containsKey(name) ||
          index >= declaration.length ||
          declaration.codeUnitAt(index) != 0x3D) {
        _throwInvalidXml(source, sourceOffset + nameStart);
      }
      index++;
      while (index < declaration.length &&
          _isWhitespace(declaration.codeUnitAt(index))) {
        index++;
      }
      if (index >= declaration.length ||
          (declaration.codeUnitAt(index) != 0x22 &&
              declaration.codeUnitAt(index) != 0x27)) {
        _throwInvalidXml(source, sourceOffset + index);
      }
      final quote = declaration.codeUnitAt(index++);
      final valueStart = index;
      while (index < declaration.length &&
          declaration.codeUnitAt(index) != quote) {
        index++;
      }
      if (index >= declaration.length) {
        _throwInvalidXml(source, sourceOffset + valueStart);
      }
      attributes[name] = declaration.substring(valueStart, index++);
      order.add(name);
    }

    final encoding = attributes['encoding'];
    final standalone = attributes['standalone'];
    if (attributes['version'] != '1.0' ||
        order.isEmpty ||
        order.first != 'version' ||
        order.any(
          (name) =>
              name != 'version' && name != 'encoding' && name != 'standalone',
        ) ||
        (order.contains('encoding') && order.indexOf('encoding') != 1) ||
        (order.contains('standalone') &&
            order.indexOf('standalone') != order.length - 1) ||
        encoding != null && !_encodingName.hasMatch(encoding) ||
        standalone != null && standalone != 'yes' && standalone != 'no') {
      _throwInvalidXml(source, sourceOffset);
    }
  }

  void _validateNamespaces(events.XmlStartElementEvent event, String source) {
    if (!_isValidQualifiedName(event.name) ||
        event.namespacePrefix == 'xmlns') {
      _throwInvalidXml(source, event.start);
    }
    final expandedNames = <String>{};
    for (final attribute in event.attributes) {
      if (!_isValidQualifiedName(attribute.name)) {
        _throwInvalidXml(source, event.start);
      }
      final isDefaultDeclaration = attribute.name == 'xmlns';
      final isPrefixedDeclaration = attribute.namespacePrefix == 'xmlns';
      if (isDefaultDeclaration || isPrefixedDeclaration) {
        final prefix = isDefaultDeclaration ? null : attribute.localName;
        final uri = _decodeReferences(attribute.value);
        if (prefix == 'xmlns' ||
            uri == _xmlnsNamespace ||
            uri == _xmlNamespace && prefix != 'xml' ||
            prefix == 'xml' && uri != _xmlNamespace ||
            prefix != null && uri.isEmpty) {
          _throwInvalidXml(source, event.start);
        }
        continue;
      }
      final namespaceUri = attribute.namespacePrefix == null
          ? ''
          : _decodeReferences(attribute.namespaceUri!);
      final expandedName =
          '$namespaceUri\u0000'
          '${attribute.localName}';
      if (!expandedNames.add(expandedName)) {
        _throwInvalidXml(source, event.start);
      }
    }
  }

  bool _isValidQualifiedName(String name) {
    final firstColon = name.indexOf(':');
    if (firstColon < 0) return _isValidNcName(name);
    return firstColon == name.lastIndexOf(':') &&
        _isValidNcName(name.substring(0, firstColon)) &&
        _isValidNcName(name.substring(firstColon + 1));
  }

  bool _isValidNcName(String name) {
    final iterator = name.runes.iterator;
    if (!iterator.moveNext() || !_isNcNameStart(iterator.current)) return false;
    while (iterator.moveNext()) {
      if (!_isNcNameCharacter(iterator.current)) return false;
    }
    return true;
  }

  bool _isNcNameStart(int codePoint) =>
      codePoint >= 0x41 && codePoint <= 0x5A ||
      codePoint == 0x5F ||
      codePoint >= 0x61 && codePoint <= 0x7A ||
      codePoint >= 0xC0 && codePoint <= 0xD6 ||
      codePoint >= 0xD8 && codePoint <= 0xF6 ||
      codePoint >= 0xF8 && codePoint <= 0x2FF ||
      codePoint >= 0x370 && codePoint <= 0x37D ||
      codePoint >= 0x37F && codePoint <= 0x1FFF ||
      codePoint >= 0x200C && codePoint <= 0x200D ||
      codePoint >= 0x2070 && codePoint <= 0x218F ||
      codePoint >= 0x2C00 && codePoint <= 0x2FEF ||
      codePoint >= 0x3001 && codePoint <= 0xD7FF ||
      codePoint >= 0xF900 && codePoint <= 0xFDCF ||
      codePoint >= 0xFDF0 && codePoint <= 0xFFFD ||
      codePoint >= 0x10000 && codePoint <= 0xEFFFF;

  bool _isNcNameCharacter(int codePoint) =>
      _isNcNameStart(codePoint) ||
      codePoint == 0x2D ||
      codePoint == 0x2E ||
      codePoint >= 0x30 && codePoint <= 0x39 ||
      codePoint == 0xB7 ||
      codePoint >= 0x300 && codePoint <= 0x36F ||
      codePoint >= 0x203F && codePoint <= 0x2040;

  String _decodeReferences(String value) =>
      xml.defaultEntityMapping.decode(value);

  bool _containsNonXmlWhitespace(String value) =>
      value.codeUnits.any((codeUnit) => !_isWhitespace(codeUnit));

  bool _isDecimalDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

  bool _isHexDigit(int codeUnit) =>
      _isDecimalDigit(codeUnit) ||
      codeUnit >= 0x41 && codeUnit <= 0x46 ||
      codeUnit >= 0x61 && codeUnit <= 0x66;

  void _validateCharacters(String source) {
    for (var index = 0; index < source.length; index++) {
      final codeUnit = source.codeUnitAt(index);
      if (codeUnit == 0x09 || codeUnit == 0x0A || codeUnit == 0x0D) continue;
      if (codeUnit < 0x20 || codeUnit == 0xFFFE || codeUnit == 0xFFFF) {
        _throwInvalidXml(source, index);
      }
      if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF) {
        if (index + 1 >= source.length ||
            source.codeUnitAt(index + 1) < 0xDC00 ||
            source.codeUnitAt(index + 1) > 0xDFFF) {
          _throwInvalidXml(source, index);
        }
        index++;
      } else if (codeUnit >= 0xDC00 && codeUnit <= 0xDFFF) {
        _throwInvalidXml(source, index);
      }
    }
  }

  void _validateStartTag(
    String tag, {
    required String source,
    required int sourceOffset,
  }) {
    var index = 1;
    while (index < tag.length && !_isTagDelimiter(tag.codeUnitAt(index))) {
      index++;
    }
    final names = <String>{};
    while (index < tag.length) {
      final whitespaceStart = index;
      while (index < tag.length && _isWhitespace(tag.codeUnitAt(index))) {
        index++;
      }
      if (index >= tag.length) break;
      if (tag.codeUnitAt(index) == 0x3E) return;
      if (tag.codeUnitAt(index) == 0x2F &&
          index + 1 < tag.length &&
          tag.codeUnitAt(index + 1) == 0x3E) {
        return;
      }
      if (index == whitespaceStart) {
        _throwInvalidXml(source, sourceOffset + index);
      }

      final nameStart = index;
      while (index < tag.length &&
          !_isWhitespace(tag.codeUnitAt(index)) &&
          tag.codeUnitAt(index) != 0x3D &&
          tag.codeUnitAt(index) != 0x2F &&
          tag.codeUnitAt(index) != 0x3E) {
        index++;
      }
      final name = tag.substring(nameStart, index);
      if (name.isEmpty || !names.add(name)) {
        _throwInvalidXml(source, sourceOffset + nameStart);
      }
      while (index < tag.length && _isWhitespace(tag.codeUnitAt(index))) {
        index++;
      }
      if (index >= tag.length || tag.codeUnitAt(index) != 0x3D) {
        _throwInvalidXml(source, sourceOffset + index);
      }
      index++;
      while (index < tag.length && _isWhitespace(tag.codeUnitAt(index))) {
        index++;
      }
      if (index >= tag.length ||
          (tag.codeUnitAt(index) != 0x22 && tag.codeUnitAt(index) != 0x27)) {
        _throwInvalidXml(source, sourceOffset + index);
      }
      final quote = tag.codeUnitAt(index++);
      final valueStart = index;
      while (index < tag.length && tag.codeUnitAt(index) != quote) {
        if (tag.codeUnitAt(index) == 0x3C) {
          _throwInvalidXml(source, sourceOffset + index);
        }
        index++;
      }
      if (index >= tag.length) {
        _throwInvalidXml(source, sourceOffset + valueStart);
      }
      _validateEntityReferences(
        tag.substring(valueStart, index),
        source: source,
        sourceOffset: sourceOffset + valueStart,
      );
      index++;
    }
    _throwInvalidXml(source, sourceOffset + tag.length - 1);
  }

  void _validateEntityReferences(
    String value, {
    required String source,
    required int sourceOffset,
  }) {
    var index = value.indexOf('&');
    while (index >= 0) {
      final end = value.indexOf(';', index + 1);
      if (end < 0) _throwInvalidXml(source, sourceOffset + index);
      final entity = value.substring(index + 1, end);
      if (entity.startsWith('#')) {
        if (entity.startsWith('#X')) {
          _throwInvalidXml(source, sourceOffset + index);
        }
        final hexadecimal = entity.startsWith('#x');
        final digits = entity.substring(hexadecimal ? 2 : 1);
        final hasOnlyDigits = digits.codeUnits.every(
          hexadecimal ? _isHexDigit : _isDecimalDigit,
        );
        final codePoint = int.tryParse(digits, radix: hexadecimal ? 16 : 10);
        if (digits.isEmpty ||
            !hasOnlyDigits ||
            codePoint == null ||
            !_isXmlCodePoint(codePoint)) {
          _throwInvalidXml(source, sourceOffset + index);
        }
      } else if (!_predefinedEntities.contains(entity)) {
        _throwInvalidXml(source, sourceOffset + index);
      }
      index = value.indexOf('&', end + 1);
    }
  }

  bool _isXmlCodePoint(int value) =>
      value == 0x09 ||
      value == 0x0A ||
      value == 0x0D ||
      value >= 0x20 && value <= 0xD7FF ||
      value >= 0xE000 && value <= 0xFFFD ||
      value >= 0x10000 && value <= 0x10FFFF;

  bool _isWhitespace(int codeUnit) =>
      codeUnit == 0x20 ||
      codeUnit == 0x09 ||
      codeUnit == 0x0A ||
      codeUnit == 0x0D;

  bool _isTagDelimiter(int codeUnit) =>
      _isWhitespace(codeUnit) || codeUnit == 0x2F || codeUnit == 0x3E;

  bool _preserveWhitespace(xml.XmlNode node) {
    if (node is! xml.XmlElement) return false;
    if (_hasPreserveSpace(node)) return true;
    return node.children.any(
      (child) =>
          child is xml.XmlCDATA ||
          child is xml.XmlText && _containsNonXmlWhitespace(child.value),
    );
  }

  bool _hasPreserveSpace(xml.XmlElement element) {
    xml.XmlElement? current = element;
    while (current != null) {
      final rawValue = current.getAttribute(
        'space',
        namespaceUri: 'http://www.w3.org/XML/1998/namespace',
      );
      final value = rawValue == null
          ? null
          : xml.defaultEntityMapping.decode(rawValue);
      if (value == 'preserve') return true;
      if (value == 'default') return false;
      current = current.parentElement;
    }
    return false;
  }

  Never _throwResourceLimit() => throw const XmlFormatException(
    kind: XmlFormatFailureKind.resource,
    code: 'xml-format.resource-limit',
  );

  Never _throwInvalidXml(String source, int? offset) {
    int? line;
    int? column;
    if (offset != null && offset >= 0) {
      var calculatedLine = 1;
      var calculatedColumn = 1;
      for (var index = 0; index < offset && index < source.length; index++) {
        final codeUnit = source.codeUnitAt(index);
        if (codeUnit == 0x0D) {
          calculatedLine++;
          calculatedColumn = 1;
          if (index + 1 < offset && source.codeUnitAt(index + 1) == 0x0A) {
            index++;
          }
        } else if (codeUnit == 0x0A) {
          calculatedLine++;
          calculatedColumn = 1;
        } else {
          calculatedColumn++;
        }
      }
      line = calculatedLine;
      column = calculatedColumn;
    }
    throw XmlFormatException(
      kind: XmlFormatFailureKind.validation,
      code: 'xml-format.invalid-xml',
      offset: offset,
      line: line,
      column: column,
      reason: 'malformed-xml',
    );
  }
}

final class _BoundedXmlStringSink implements StringSink {
  _BoundedXmlStringSink(this.maximumLength);

  final int maximumLength;
  final _buffer = StringBuffer();
  var _length = 0;

  @override
  void write(Object? object) {
    final value = object.toString();
    _reserve(value.length);
    _buffer.write(value);
  }

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) {
    var first = true;
    for (final object in objects) {
      if (!first) write(separator);
      write(object);
      first = false;
    }
  }

  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));

  @override
  void writeln([Object? object = '']) {
    write(object);
    write('\n');
  }

  void _reserve(int length) {
    if (_length + length > maximumLength) {
      throw const XmlFormatException(
        kind: XmlFormatFailureKind.resource,
        code: 'xml-format.resource-limit',
      );
    }
    _length += length;
  }

  @override
  String toString() => _buffer.toString();
}
