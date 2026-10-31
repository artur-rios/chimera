import 'dart:io';

import 'package:yaml/yaml.dart';

final class BoundaryViolation {
  const BoundaryViolation({
    required this.code,
    required this.package,
    required this.dependency,
  });

  final String code;
  final String package;
  final String dependency;

  @override
  String toString() => '$code: $package -> $dependency';
}

const Map<String, Set<String>> _allowedInternalDependencies =
    <String, Set<String>>{
      'chimera_core': <String>{'chimera_utilities'},
      'chimera_l10n': <String>{},
      'chimera_platform': <String>{'chimera_core'},
      'chimera_utilities': <String>{},
      'chimera_cli': <String>{
        'chimera_core',
        'chimera_l10n',
        'chimera_platform',
        'chimera_utilities',
      },
      'chimera_gui': <String>{
        'chimera_core',
        'chimera_l10n',
        'chimera_platform',
        'chimera_utilities',
      },
    };

const Set<String> _databaseDependencies = <String>{
  'drift',
  'floor',
  'hive',
  'isar',
  'realm',
  'sembast',
  'sqflite',
  'sqlite3',
};

const Set<String> _analyticsDependencies = <String>{
  'amplitude_flutter',
  'firebase_analytics',
  'matomo_tracker',
  'mixpanel_flutter',
  'posthog_flutter',
  'sentry_flutter',
};

List<BoundaryViolation> checkDependencyMap(
  Map<String, Set<String>> dependenciesByPackage,
) {
  final violations = <BoundaryViolation>[];
  for (final packageEntry in dependenciesByPackage.entries) {
    final allowed =
        _allowedInternalDependencies[packageEntry.key] ?? const <String>{};
    for (final dependency in packageEntry.value) {
      if (dependency.startsWith('chimera_') && !allowed.contains(dependency)) {
        violations.add(
          BoundaryViolation(
            code: 'forbidden-internal-dependency',
            package: packageEntry.key,
            dependency: dependency,
          ),
        );
      }
      if (_databaseDependencies.contains(dependency)) {
        violations.add(
          BoundaryViolation(
            code: 'database-dependency',
            package: packageEntry.key,
            dependency: dependency,
          ),
        );
      }
      if (_analyticsDependencies.contains(dependency)) {
        violations.add(
          BoundaryViolation(
            code: 'analytics-dependency',
            package: packageEntry.key,
            dependency: dependency,
          ),
        );
      }
    }
  }
  return violations;
}

List<BoundaryViolation> checkWorkspaceBoundaries(Directory root) {
  const manifestPaths = <String>[
    'apps/chimera_cli/pubspec.yaml',
    'apps/chimera_gui/pubspec.yaml',
    'packages/chimera_core/pubspec.yaml',
    'packages/chimera_l10n/pubspec.yaml',
    'packages/chimera_platform/pubspec.yaml',
    'packages/chimera_utilities/pubspec.yaml',
  ];
  final dependencyMap = <String, Set<String>>{};

  for (final relativePath in manifestPaths) {
    final manifest = File('${root.path}/$relativePath');
    final yaml = loadYaml(manifest.readAsStringSync()) as YamlMap;
    final name = yaml['name']! as String;
    final dependencies = yaml['dependencies'] as YamlMap?;
    dependencyMap[name] =
        dependencies?.keys.cast<String>().toSet() ?? <String>{};
  }

  return checkDependencyMap(dependencyMap);
}

void main() {
  final violations = checkWorkspaceBoundaries(Directory.current);
  if (violations.isEmpty) {
    stdout.writeln('Dependency boundaries: OK');
    return;
  }

  for (final violation in violations) {
    stderr.writeln(violation);
  }
  exitCode = 1;
}
