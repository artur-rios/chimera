// Compiled to JavaScript by lorem_web_boundary_test.dart and run in Node.
import 'dart:convert';
import 'dart:js_interop';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';

@JS('failAllocation')
external String failAllocation();

final class _AllocationFailureBuffer implements StringBuffer {
  _AllocationFailureBuffer(this.boundary);
  final String boundary;
  @override
  void write(Object? value) {
    if (boundary == 'append') failAllocation();
  }

  @override
  String toString() => boundary == 'finish' ? failAllocation() : 'unused';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _check(bool condition, String invariant) {
  if (!condition) throw StateError(invariant);
}

Future<void> main() async {
  var checks = 0;
  for (final boundary in ['append', 'finish']) {
    final service = LoremService(
      generator: LoremGenerator.forTesting(
        createBuffer: () => _AllocationFailureBuffer(boundary),
      ),
    );
    final result = await service.execute(const LoremOperationRequest());
    _check(
      result is ChimeraFailure<LoremOutput> &&
          result.kind == FailureKind.resource &&
          result.code == 'lorem.resource-limit',
      '$boundary must return resource',
    );
    checks++;
  }
  for (final raw in [
    '9007199254740993',
    '9223372036854775807',
    '999999999999999999999999999999999',
    '100000000000000000000000',
    '9' * 400,
  ]) {
    var allocations = 0;
    final service = LoremService(
      generator: LoremGenerator.forTesting(
        allocate: (_) {
          allocations++;
          return 'unused';
        },
      ),
    );
    final result = await service.execute(LoremOperationRequest(count: raw));
    _check(
      result is ChimeraFailure<LoremOutput> &&
          result.kind == FailureKind.validation &&
          result.code == 'lorem.invalid-count',
      'rounded or nonfinite count must be invalid',
    );
    _check(
      allocations == 0 && tryParsePositiveDecimalInteger(raw) == null,
      'invalid count must not allocate',
    );
    checks++;
  }
  for (final raw in [
    '1', '0002', '9007199254740991', '0009007199254740991',
    '9007199254740992', '9007199254740994', '18014398509481984',
    // 10^21 and 2^100 have exact binary values despite scientific display.
    '1000000000000000000000', '1267650600228229401496703205376',
  ]) {
    int? observed;
    final service = LoremService(
      generator: LoremGenerator.forTesting(
        allocate: (request) {
          observed = request.count;
          return 'test-only';
        },
      ),
    );
    final result = await service.execute(LoremOperationRequest(count: raw));
    _check(
      result is ChimeraSuccess<LoremOutput>,
      'exactly representable count must be accepted',
    );
    _check(
      observed != null && BigInt.from(observed!) == BigInt.parse(raw),
      'count must remain mathematically exact',
    );
    checks++;
  }
  for (final raw in ['9007199254740992', '9007199254740994']) {
    var allocations = 0;
    final generator = LoremGenerator.forTesting(
      allocate: (_) {
        allocations++;
        return 'unused';
      },
    );
    final result = generator.generate(LoremRequest(count: int.parse(raw)));
    _check(
      allocations == 1 && BigInt.from(result.count) == BigInt.parse(raw),
      'direct exactly representable count must be accepted',
    );
    checks++;
  }
  // Unrelated allocator/programmer errors must not become resource failures.
  try {
    LoremGenerator.forTesting(allocate: (_) => throw ArgumentError('PRIVATE'))
        .generate(const LoremRequest());
    throw StateError('unrelated argument error must propagate');
  } on ArgumentError {
    checks++;
  }
  // Test harness protocol: the VM test reads this one JSON stdout line.
  // ignore: avoid_print
  print(jsonEncode({'checks': checks, 'status': 'passed'}));
}
