import 'dart:convert';

/// Validation reports only stable field identifiers, never the supplied values.
final class DotnetParameterException implements Exception {
  DotnetParameterException(Iterable<String> fields)
    : fields = List.unmodifiable(fields);
  final List<String> fields;
}

final class DotnetRepositoryParameters {
  DotnetRepositoryParameters._(Map<String, String> values)
    : values = Map.unmodifiable(values);
  final Map<String, String> values;
  String get rootFolder => values['RootFolder']!;
  String get solutionName => values['SolutionName']!;
  String get projectName => values['ProjectName']!;
  String operator [](String field) => values[field] ?? '';
  static const commonFields = [
    'RootFolder',
    'SolutionName',
    'ProjectName',
    'Author',
    'Description',
  ];
  static const nugetFields = [
    'Company',
    'Version',
    'PackageId',
    'RepositoryUrl',
  ];

  factory DotnetRepositoryParameters.parse({
    Map<String, String> fields = const {},
    String? parametersJson,
    bool nuget = true,
  }) {
    if (parametersJson != null && fields.isNotEmpty) {
      throw DotnetParameterException(['inputMode']);
    }
    Map<String, String> values;
    if (parametersJson != null) {
      if (parametersJson.length > 65536) {
        throw DotnetParameterException(['parametersJson']);
      }
      Object? decoded;
      try {
        decoded = jsonDecode(parametersJson);
      } on FormatException {
        throw DotnetParameterException(['parametersJson']);
      }
      if (decoded is! Map<String, dynamic> ||
          decoded.values.any((value) => value is! String)) {
        throw DotnetParameterException(['parametersJson']);
      }
      values = decoded.cast<String, String>();
    } else {
      values = Map.of(fields);
    }
    final required = [...commonFields, if (nuget) ...nugetFields];
    final allowed = {...commonFields, ...nugetFields};
    final errors = <String>{};
    if (values.keys.any((field) => !allowed.contains(field))) {
      errors.add('parametersJson');
    }
    for (final field in required) {
      if (!_safeMetadata(values[field] ?? '')) errors.add(field);
    }
    final root = values['RootFolder'] ?? '';
    final leaf = root.split(RegExp(r'[/\\]')).last;
    if (root.isEmpty ||
        leaf.isEmpty ||
        leaf == '.' ||
        leaf == '..' ||
        RegExp(r'[<>:"|?*\x00-\x1f]').hasMatch(leaf) ||
        leaf.endsWith('.') ||
        leaf.endsWith(' ') ||
        _reserved(leaf)) {
      errors.add('RootFolder');
    }
    for (final field in ['SolutionName', 'ProjectName']) {
      final value = values[field] ?? '';
      if (field == 'ProjectName' && value.split('.').any(_keywords.contains)) {
        errors.add(field);
      }
      if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*$')
              .hasMatch(value) ||
          value.length > 100 ||
          _reserved(value)) {
        errors.add(field);
      }
    }
    if (nuget) {
      final version = values['Version'] ?? '';
      final match = RegExp(
        r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
      ).firstMatch(version);
      if (match == null ||
          [1, 2, 3].any(
            (index) =>
                (int.tryParse(match.group(index) ?? '') ?? 65535) > 65534,
          ) ||
          (match
                  .group(4)
                  ?.split('.')
                  .any(
                    (part) =>
                        RegExp(r'^[0-9]+$').hasMatch(part) &&
                        part.length > 1 &&
                        part.startsWith('0'),
                  ) ??
              false)) {
        errors.add('Version');
      }
      if (!RegExp(r'^[A-Za-z0-9_.-]{1,100}$')
          .hasMatch(values['PackageId'] ?? '')) {
        errors.add('PackageId');
      }
      final uri = Uri.tryParse(values['RepositoryUrl'] ?? '');
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.fragment.isNotEmpty ||
          uri.toString().contains(' ')) {
        errors.add('RepositoryUrl');
      }
    }
    if (errors.isNotEmpty) throw DotnetParameterException(errors);
    return DotnetRepositoryParameters._(values);
  }

  static const _keywords = {
    'abstract',
    'as',
    'base',
    'bool',
    'break',
    'byte',
    'case',
    'catch',
    'char',
    'checked',
    'class',
    'const',
    'continue',
    'decimal',
    'default',
    'delegate',
    'do',
    'double',
    'else',
    'enum',
    'event',
    'explicit',
    'extern',
    'false',
    'finally',
    'fixed',
    'float',
    'for',
    'foreach',
    'goto',
    'if',
    'implicit',
    'in',
    'int',
    'interface',
    'internal',
    'is',
    'lock',
    'long',
    'namespace',
    'new',
    'null',
    'object',
    'operator',
    'out',
    'override',
    'params',
    'private',
    'protected',
    'public',
    'readonly',
    'ref',
    'return',
    'sbyte',
    'sealed',
    'short',
    'sizeof',
    'stackalloc',
    'static',
    'string',
    'struct',
    'switch',
    'this',
    'throw',
    'true',
    'try',
    'typeof',
    'uint',
    'ulong',
    'unchecked',
    'unsafe',
    'ushort',
    'using',
    'virtual',
    'void',
    'volatile',
    'while',
  };

  static bool _safeMetadata(String value) =>
      value.trim().isNotEmpty &&
      value.length <= 4096 &&
      _validXml(value) &&
      !RegExp(r'[\x00-\x1f\x7f\u2028\u2029]').hasMatch(value) &&
      !RegExp(r'[$%@]\(|%[0-9A-Fa-f]{2}').hasMatch(value);
  static bool _validXml(String value) {
    final units = value.codeUnits;
    for (var index = 0; index < units.length; index++) {
      final unit = units[index];
      if (unit == 0xfffe || unit == 0xffff) return false;
      if (unit >= 0xd800 && unit <= 0xdbff) {
        if (++index >= units.length ||
            units[index] < 0xdc00 ||
            units[index] > 0xdfff) {
          return false;
        }
      } else if (unit >= 0xdc00 && unit <= 0xdfff) {
        return false;
      }
    }
    return true;
  }

  static bool _reserved(String name) => RegExp(
    r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$',
    caseSensitive: false,
  ).hasMatch(name.split('.').first);
}
