import 'dart:convert';
import 'dart:io';

import 'package:chimera_gui/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GivenGuiStartup_WhenShellSettles_ThenAcceptanceThresholdIsMet', (
    tester,
  ) async {
    final rootThresholds = File('tests/performance/acceptance_thresholds.json');
    final thresholdsFile = rootThresholds.existsSync()
        ? rootThresholds
        : File('../../tests/performance/acceptance_thresholds.json');
    final thresholds =
        jsonDecode(thresholdsFile.readAsStringSync()) as Map<String, Object?>;
    final workload = thresholds['guiStartup']! as Map<String, Object?>;
    final maxMilliseconds = workload['maxMilliseconds']! as int;
    final stopwatch = Stopwatch()..start();

    await tester.pumpWidget(const ChimeraApp());
    await tester.pumpAndSettle();
    stopwatch.stop();

    expect(find.text('Developer toolbox'), findsOneWidget);
    expect(stopwatch.elapsedMilliseconds, lessThan(maxMilliseconds));
  });
}
