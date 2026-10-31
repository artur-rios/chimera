import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/dotnet_tag.dart';
import 'package:chimera_platform/native_commands.dart';

DotnetTagOperationService createDotnetTagService() => DotnetTagService(
  projects: NativeDotnetTagProjectGateway(),
  runner: const NativeProcessRunner(),
);
