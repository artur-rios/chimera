import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/native_scaffolding.dart';

ScaffoldOperationService createScaffoldService() =>
    ScaffoldService(const NativeScaffoldWriter());
