import 'package:chimera_cli/chimera_cli.dart';
import 'package:test/test.dart';

void main() {
  for (final command in [
    ['project', 'from-template'],
    ['terminal', 'type-periodic'],
    ['dotnet', 'build'],
    ['dotnet', 'clean'],
  ]) {
    test(
      'GivenComposedBranches_WhenHelpFor${command.join('_')}_ThenReachAdapter',
      () async {
        final out = StringBuffer();
        final err = StringBuffer();
        expect(
          await runChimera(
            [...command, '--help'],
            localeTag: 'en',
            out: out,
            err: err,
          ),
          0,
          reason: err.toString(),
        );
        expect(out.toString(), contains(command.join(' ')));
      },
    );
  }
}
