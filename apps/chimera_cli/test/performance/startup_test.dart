import 'dart:convert';
import 'dart:io';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:test/test.dart';

void main() {
  test('GivenCliStartup_WhenHelpLoads_ThenAcceptanceThresholdIsMet', () async {
    final rootThresholds = File('tests/performance/acceptance_thresholds.json');
    final thresholdsFile = rootThresholds.existsSync()
        ? rootThresholds
        : File('../../tests/performance/acceptance_thresholds.json');
    final thresholds =
        jsonDecode(thresholdsFile.readAsStringSync()) as Map<String, Object?>;
    final workload = thresholds['cliStartup']! as Map<String, Object?>;
    final maxMilliseconds = workload['maxMilliseconds']! as int;
    final output = StringBuffer();
    final errorOutput = StringBuffer();
    final stopwatch = Stopwatch()..start();

    final exitCode = await runChimera(
      <String>['--help'],
      localeTag: 'en',
      out: output,
      err: errorOutput,
    );
    stopwatch.stop();

    expect(exitCode, 0);
    expect(output.toString(), contains('Usage: chimera'));
    expect(stopwatch.elapsedMilliseconds, lessThan(maxMilliseconds));
  });
}
