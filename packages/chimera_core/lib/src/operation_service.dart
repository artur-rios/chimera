import 'result.dart';

abstract interface class OperationService<Request, Output> {
  Future<ChimeraResult<Output>> execute(Request request);
}
