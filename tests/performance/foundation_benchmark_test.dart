import 'dart:convert';
import 'dart:io';

import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:test/test.dart';

void main() {
  test('GivenCatalogWorkload_WhenMeasured_ThenAcceptanceThresholdIsMet', () {
    final thresholds = jsonDecode(
      File('tests/performance/acceptance_thresholds.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final workload = thresholds['catalogLookup']! as Map<String, Object?>;
    final iterations = workload['iterations']! as int;
    final maxMilliseconds = workload['maxMilliseconds']! as int;
    const catalog = MessageCatalog();
    final stopwatch = Stopwatch()..start();

    for (var index = 0; index < iterations; index += 1) {
      expect(catalog.lookup('pt-BR', 'app.name'), 'Chimera');
    }
    stopwatch.stop();

    expect(stopwatch.elapsedMilliseconds, lessThan(maxMilliseconds));
  });

  test('GivenAcceptanceContract_WhenLoaded_ThenRepresentativeLimitsExist', () {
    final thresholds = jsonDecode(
      File('tests/performance/acceptance_thresholds.json').readAsStringSync(),
    ) as Map<String, Object?>;

    expect(
      thresholds.keys,
      containsAll(<String>[
        'catalogLookup',
        'cliStartup',
        'guiStartup',
        'oneMegabyteOperation',
      ]),
    );
  });
}
