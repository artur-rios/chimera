import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:crypto/crypto.dart';
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
    String? lastValue;

    for (var index = 0; index < iterations; index += 1) {
      lastValue = catalog.lookup('pt-BR', 'app.name');
    }
    stopwatch.stop();

    expect(lastValue, 'Chimera');
    expect(stopwatch.elapsedMilliseconds, lessThan(maxMilliseconds));
  });

  test('GivenOneMegabyteWorkload_WhenHashed_ThenAcceptanceThresholdIsMet', () {
    final thresholds = jsonDecode(
      File('tests/performance/acceptance_thresholds.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final workload =
        thresholds['oneMegabyteOperation']! as Map<String, Object?>;
    final maxMilliseconds = workload['maxMilliseconds']! as int;
    final input = Uint8List(1024 * 1024);
    final stopwatch = Stopwatch()..start();

    final digest = sha256.convert(input);
    stopwatch.stop();

    expect(digest.bytes, hasLength(32));
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
