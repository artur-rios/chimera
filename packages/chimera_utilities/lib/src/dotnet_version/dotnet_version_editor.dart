import 'dart:convert';

import 'package:xml/xml.dart' as xml;
import 'package:xml/xml_events.dart' as events;

final class DotnetVersionException implements Exception {
  const DotnetVersionException(this.code);
  final String code;
}

final class DotnetVersionEdit {
  DotnetVersionEdit({
    required List<int> bytes,
    required this.previousVersion,
    required this.version,
  }) : bytes = List.unmodifiable(bytes);
  final List<int> bytes;
  final String? previousVersion;
  final String version;
}

/// Validates XML structurally, then changes only the selected source span. Never
/// serializes the document, preserving comments, attributes, whitespace and BOM.
final class DotnetVersionEditor {
  const DotnetVersionEditor();
  static final _numeric = RegExp(r'^[0-9]+\.[0-9]+\.[0-9]+$');

  DotnetVersionEdit edit(
    List<int> bytes, {
    String? version,
    String? increment,
  }) {
    if ((version == null) == (increment == null) ||
        (version != null && !_numeric.hasMatch(version)) ||
        (increment != null &&
            !{'major', 'minor', 'patch'}.contains(increment))) {
      throw const DotnetVersionException('invalid-version');
    }
    final input = _EncodedXml.decode(bytes);
    final parsed = _ProjectXml.parse(input.source);
    input.validateDeclaration(parsed.document.declaration?.encoding);
    final previous = parsed.currentVersion;
    final String target;
    if (version != null) {
      target = version;
    } else {
      if (previous == null || !_numeric.hasMatch(previous)) {
        throw const DotnetVersionException('invalid-version');
      }
      final parts = previous.split('.').map(BigInt.parse).toList();
      final position = {'major': 0, 'minor': 1, 'patch': 2}[increment]!;
      parts[position] += BigInt.one;
      for (var i = position + 1; i < 3; i++) {
        parts[i] = BigInt.zero;
      }
      target = parts.join('.');
    }
    final updated = parsed.withVersion(target);
    if (_ProjectXml.parse(updated).currentVersion != target) {
      throw const DotnetVersionException('invalid-xml');
    }
    return DotnetVersionEdit(
      bytes: input.encode(updated),
      previousVersion: previous,
      version: target,
    );
  }

  String? readVersion(List<int> bytes) {
    final input = _EncodedXml.decode(bytes);
    final parsed = _ProjectXml.parse(input.source);
    input.validateDeclaration(parsed.document.declaration?.encoding);
    return parsed.currentVersion;
  }
}

final class _EncodedXml {
  _EncodedXml(this.source, this.prefix, this.littleEndian);
  final String source;
  final List<int> prefix;
  final bool? littleEndian;

  factory _EncodedXml.decode(List<int> bytes) {
    try {
      List<int> prefix = [];
      bool? little;
      var offset = 0;
      if (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xfe) {
        little = true;
        prefix = [0xff, 0xfe];
        offset = 2;
      } else if (bytes.length >= 2 && bytes[0] == 0xfe && bytes[1] == 0xff) {
        little = false;
        prefix = [0xfe, 0xff];
        offset = 2;
      } else if (bytes.length >= 3 &&
          bytes[0] == 0xef &&
          bytes[1] == 0xbb &&
          bytes[2] == 0xbf) {
        prefix = [0xef, 0xbb, 0xbf];
        offset = 3;
      } else if (bytes.length >= 2 && bytes[0] == 0x3c && bytes[1] == 0) {
        little = true;
      } else if (bytes.length >= 2 && bytes[0] == 0 && bytes[1] == 0x3c) {
        little = false;
      }
      if (little == null) {
        return _EncodedXml(utf8.decode(bytes.sublist(offset)), prefix, null);
      }
      if ((bytes.length - offset).isOdd) throw const FormatException();
      final units = <int>[];
      for (var i = offset; i < bytes.length; i += 2) {
        units.add(
          little
              ? bytes[i] | (bytes[i + 1] << 8)
              : (bytes[i] << 8) | bytes[i + 1],
        );
      }
      for (var i = 0; i < units.length; i++) {
        if (units[i] >= 0xd800 && units[i] <= 0xdbff) {
          if (++i >= units.length || units[i] < 0xdc00 || units[i] > 0xdfff) {
            throw const FormatException();
          }
        } else if (units[i] >= 0xdc00 && units[i] <= 0xdfff) {
          throw const FormatException();
        }
      }
      return _EncodedXml(String.fromCharCodes(units), prefix, little);
    } on Object {
      throw const DotnetVersionException('unsupported-encoding');
    }
  }

  void validateDeclaration(String? declaration) {
    if (declaration == null) return;
    final encoding = declaration.toLowerCase();
    final accepted = littleEndian == null
        ? encoding == 'utf-8'
        : encoding == 'utf-16' ||
              encoding == (littleEndian! ? 'utf-16le' : 'utf-16be');
    if (!accepted) throw const DotnetVersionException('unsupported-encoding');
  }

  List<int> encode(String value) {
    if (littleEndian == null) return [...prefix, ...utf8.encode(value)];
    return [
      ...prefix,
      for (final unit in value.codeUnits) ...[
        if (littleEndian!) ...[
          unit & 0xff,
          unit >> 8,
        ] else ...[
          unit >> 8,
          unit & 0xff,
        ],
      ],
    ];
  }
}

final class _ElementSpan {
  _ElementSpan(this.event, this.parent)
    : endStart = event.stop!,
      stop = event.stop!;
  final events.XmlStartElementEvent event;
  final _ElementSpan? parent;
  final List<events.XmlEvent> text = [];
  bool hasChildElements = false;
  int endStart;
  int stop;
  String get localName => event.localName;
}

final class _ProjectXml {
  _ProjectXml(this.source, this.document, this.elements);
  final String source;
  final xml.XmlDocument document;
  final List<_ElementSpan> elements;
  _ElementSpan get root => elements.first;
  List<_ElementSpan> get versions => elements
      .where(
        (element) =>
            element.localName == 'Version' &&
            element.parent?.localName == 'PropertyGroup' &&
            identical(element.parent?.parent, root),
      )
      .toList();
  List<_ElementSpan> get groups => elements
      .where(
        (element) =>
            element.localName == 'PropertyGroup' &&
            identical(element.parent, root),
      )
      .toList();

  factory _ProjectXml.parse(String source) {
    try {
      final document = xml.XmlDocument.parse(source);
      if (document.rootElement.name.local != 'Project' ||
          document.doctypeElement != null) {
        throw const FormatException();
      }
      final elements = <_ElementSpan>[];
      final stack = <_ElementSpan>[];
      for (final event in events.parseEvents(
        source,
        validateNesting: true,
        validateNamespace: true,
        validateDocument: true,
        withLocation: true,
      )) {
        if (event is events.XmlStartElementEvent) {
          final parent = stack.isEmpty ? null : stack.last;
          if (parent != null) parent.hasChildElements = true;
          final element = _ElementSpan(event, parent);
          elements.add(element);
          if (!event.isSelfClosing) stack.add(element);
        } else if (event is events.XmlEndElementEvent) {
          final element = stack.removeLast();
          element.endStart = event.start!;
          element.stop = event.stop!;
        } else if (stack.isNotEmpty &&
            (event is events.XmlTextEvent || event is events.XmlCDATAEvent)) {
          stack.last.text.add(event);
        }
      }
      final parsed = _ProjectXml(source, document, elements);
      if (parsed.versions.length > 1 ||
          parsed.versions.any((element) => element.hasChildElements)) {
        throw const DotnetVersionException('ambiguous-version');
      }
      return parsed;
    } on DotnetVersionException {
      rethrow;
    } on Object {
      throw const DotnetVersionException('invalid-xml');
    }
  }

  String _value(events.XmlEvent event) => switch (event) {
    events.XmlTextEvent(:final value) => value,
    events.XmlCDATAEvent(:final value) => value,
    _ => '',
  };

  String? get currentVersion {
    if (versions.isEmpty) return null;
    return versions.single.text.map(_value).join().trim();
  }

  String _indent(int offset) {
    final line = source.lastIndexOf('\n', offset - 1) + 1;
    final prefix = source.substring(line, offset);
    return prefix.trim().isEmpty ? prefix : '';
  }

  String get newline => source.contains('\r\n') ? '\r\n' : '\n';
  String _qualified(_ElementSpan element, String local) =>
      element.event.namespacePrefix == null
      ? local
      : '${element.event.namespacePrefix}:$local';
  String _expand(_ElementSpan element, String content) {
    final opening = source.substring(element.event.start!, element.event.stop!);
    return source.replaceRange(
      element.event.start!,
      element.event.stop!,
      '${opening.replaceFirst(RegExp(r'/\s*>$'), '>')}$content</${element.event.name}>',
    );
  }

  String withVersion(String target) {
    if (versions.isNotEmpty) {
      final version = versions.single;
      if (version.event.isSelfClosing) return _expand(version, target);
      final meaningful = version.text
          .where((event) => _value(event).trim().isNotEmpty)
          .toList();
      if (meaningful.length > 1) {
        throw const DotnetVersionException('ambiguous-version');
      }
      if (meaningful.isEmpty) {
        return source.replaceRange(version.endStart, version.endStart, target);
      }
      final event = meaningful.single;
      final start = event.start! + (event is events.XmlCDATAEvent ? 9 : 0);
      final stop = event.stop! - (event is events.XmlCDATAEvent ? 3 : 0);
      final raw = source.substring(start, stop);
      final prefix = RegExp(r'^\s*').stringMatch(raw)!;
      final suffix = RegExp(r'\s*$').firstMatch(raw)!.group(0)!;
      return source.replaceRange(start, stop, '$prefix$target$suffix');
    }
    if (groups.isNotEmpty) {
      final group = groups.first;
      final name = _qualified(group, 'Version');
      final packageIds = elements.where(
        (element) =>
            element.localName == 'PackageId' &&
            identical(element.parent, group),
      );
      if (packageIds.isNotEmpty) {
        final package = packageIds.first;
        return source.replaceRange(
          package.stop,
          package.stop,
          '$newline${_indent(package.event.start!)}<$name>$target</$name>',
        );
      }
      final childIndent = '${_indent(group.event.start!)}  ';
      final content = '$newline$childIndent<$name>$target</$name>';
      if (group.event.isSelfClosing) {
        return _expand(group, '$content$newline${_indent(group.event.start!)}');
      }
      return source.replaceRange(group.event.stop!, group.event.stop!, content);
    }
    final groupName = _qualified(root, 'PropertyGroup');
    final versionName = _qualified(root, 'Version');
    final content =
        '$newline  <$groupName>$newline    <$versionName>$target</$versionName>$newline  </$groupName>$newline';
    if (root.event.isSelfClosing) return _expand(root, content);
    return source.replaceRange(root.endStart, root.endStart, content);
  }
}
