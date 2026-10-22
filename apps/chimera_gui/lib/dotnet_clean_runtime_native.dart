import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/dotnet_clean.dart';

DotnetCleanService? createDotnetCleaner() =>
    Platform.isWindows || Platform.isLinux
    ? DotnetCleanService(NativeDotnetCleanGateway())
    : null;
