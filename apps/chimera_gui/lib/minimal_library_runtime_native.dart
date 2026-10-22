import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/native_scaffolding.dart';

bool get minimalLibrarySupported => Platform.isWindows || Platform.isLinux;
DotnetScaffoldOperationService createMinimalLibraryService() =>
    minimalLibrarySupported
    ? MinimalLibraryScaffoldService(const NativeScaffoldWriter())
    : const UnsupportedDotnetScaffoldService();
