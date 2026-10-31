import 'dart:io';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 3) {
    stderr.writeln(
      'Usage: dart run tool/check_branch_origin.dart '
      '<main-ref> <develop-ref> <head-ref>',
    );
    exitCode = 64;
    return;
  }

  final result = await checkBranchOrigin(
    mainRef: arguments[0],
    developRef: arguments[1],
    headRef: arguments[2],
  );
  if (!result.isValid) {
    stderr.writeln(result.message);
    exitCode = 1;
    return;
  }

  stdout.writeln(result.message);
}

Future<BranchOriginResult> checkBranchOrigin({
  required String mainRef,
  required String developRef,
  required String headRef,
}) async {
  final branchPoint = await _git(<String>['merge-base', headRef, developRef]);
  final developAhead = int.parse(
    await _git(<String>['rev-list', '--count', '$mainRef..$developRef']),
  );
  final branchPointAhead = int.parse(
    await _git(<String>['rev-list', '--count', '$mainRef..$branchPoint']),
  );

  if (developAhead > 0 && branchPointAhead == 0) {
    return const BranchOriginResult(
      isValid: false,
      message: 'Feature or fix branch was branched from main, not develop.',
    );
  }

  return BranchOriginResult(
    isValid: true,
    message: 'Branch point $branchPoint contains develop-only ancestry.',
  );
}

Future<String> _git(List<String> arguments) async {
  final result = await Process.run('git', arguments);
  if (result.exitCode != 0) {
    throw ProcessException(
      'git',
      arguments,
      (result.stderr as String).trim(),
      result.exitCode,
    );
  }
  return (result.stdout as String).trim();
}

final class BranchOriginResult {
  const BranchOriginResult({required this.isValid, required this.message});

  final bool isValid;
  final String message;
}
