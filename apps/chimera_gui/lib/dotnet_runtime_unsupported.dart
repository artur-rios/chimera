import 'package:chimera_core/chimera_core.dart';

const bool dotnetBuildSupported = false;
DotnetBuildService createDotnetBuildService() =>
    throw UnsupportedError('Native .NET builds require Windows or Linux.');

DotnetTestService createDotnetTestService() =>
    throw UnsupportedError('Native .NET tests require Windows or Linux.');
