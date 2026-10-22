import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/dotnet_bump.dart';

DotnetBumpService? createDotnetBumper() =>
    Platform.isLinux || Platform.isWindows
    ? DotnetBumpService(NativeDotnetBumpGateway())
    : null;
