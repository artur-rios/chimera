import 'package:chimera_core/chimera_core.dart';
import 'package:test/test.dart';

void main() {
  test('GivenSuccess_WhenFolded_ThenMapsTheValue', () {
    const result = ChimeraSuccess<int>(21);

    final mapped = result.fold(
      onSuccess: (value) => value * 2,
      onFailure: (_) => -1,
    );

    expect(mapped, 42);
  });

  test('GivenTypedFailure_WhenFolded_ThenMapsTheFailure', () {
    const result = ChimeraFailure<int>(
      kind: FailureKind.validation,
      code: 'invalid-input',
      messageKey: 'error.invalidInput',
    );

    final mapped = result.fold(
      onSuccess: (_) => 'success',
      onFailure: (failure) => '${failure.kind.name}:${failure.code}',
    );

    expect(mapped, 'validation:invalid-input');
  });

  test('GivenOperationService_WhenExecuted_ThenReturnsSharedResult', () async {
    const service = _LengthService();

    final result = await service.execute('chimera');

    expect(result, isA<ChimeraSuccess<int>>());
    expect((result as ChimeraSuccess<int>).value, 7);
  });
}

final class _LengthService implements OperationService<String, int> {
  const _LengthService();

  @override
  Future<ChimeraResult<int>> execute(String request) async {
    return ChimeraSuccess<int>(request.length);
  }
}
