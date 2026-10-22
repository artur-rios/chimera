import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/dotnet_test_workspace.dart';
import 'package:chimera_platform/native_commands.dart';

bool get dotnetBuildSupported => Platform.isLinux || Platform.isWindows;
DotnetBuildService createDotnetBuildService() => const DotnetBuildService(
  runner: NativeProcessRunner(),
  discovery: NativeProjectDiscovery(),
);

DotnetTestService createDotnetTestService() => const DotnetTestService(
  runner: NativeProcessRunner(),
  workspace: NativeDotnetTestWorkspace(),
);
