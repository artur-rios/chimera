enum FailureKind {
  validation,
  range,
  processing,
  resource,
  access,
  update,
  unexpected,
}

sealed class ChimeraResult<T> {
  const ChimeraResult();

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(ChimeraFailure<T> failure) onFailure,
  });
}

final class ChimeraSuccess<T> extends ChimeraResult<T> {
  const ChimeraSuccess(this.value);

  final T value;

  @override
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(ChimeraFailure<T> failure) onFailure,
  }) => onSuccess(value);
}

final class ChimeraFailure<T> extends ChimeraResult<T> {
  const ChimeraFailure({
    required this.kind,
    required this.code,
    required this.messageKey,
    this.details = const <String, Object?>{},
  });

  final FailureKind kind;
  final String code;
  final String messageKey;
  final Map<String, Object?> details;

  @override
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(ChimeraFailure<T> failure) onFailure,
  }) => onFailure(this);
}
