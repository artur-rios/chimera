import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:path/path.dart' as p;

import 'dotnet_bump.dart';

final class NativeDotnetTagProjectGateway implements DotnetTagProjectGateway {
  NativeDotnetTagProjectGateway({String? workingDirectory})
    : workingDirectory = p.normalize(
        p.absolute(workingDirectory ?? Directory.current.path),
      );
  final String workingDirectory;

  @override
  Future<DotnetTagProject> resolve(String? selection) async {
    final raw = selection ?? 'src';
    if (raw.trim().isEmpty || raw.contains('\u0000')) {
      throw const DotnetBumpBoundaryException('discovery');
    }
    final selected = p.normalize(
      p.isAbsolute(raw) ? raw : p.join(workingDirectory, raw),
    );
    final reader = NativeDotnetBumpGateway(workingDirectory: workingDirectory);
    var path = selected;
    if (await FileSystemEntity.type(selected, followLinks: false) ==
        FileSystemEntityType.directory) {
      final files = <String>[];
      Future<void> scan(Directory directory) async {
        if (!p.equals(await directory.resolveSymbolicLinks(), directory.path)) {
          throw const DotnetBumpBoundaryException('discovery');
        }
        await for (final entity in directory.list(followLinks: false)) {
          final type = await FileSystemEntity.type(
            entity.path,
            followLinks: false,
          );
          if (type == FileSystemEntityType.directory &&
              p.basename(entity.path) != '.git') {
            await scan(Directory(entity.path));
          } else if (type == FileSystemEntityType.file &&
              p.extension(entity.path).toLowerCase() == '.csproj') {
            files.add(entity.path);
          }
        }
      }

      await scan(Directory(selected));
      files.sort();
      if (files.length != 1) {
        throw DotnetBumpBoundaryException(
          'discovery',
          details: {'candidates': files},
        );
      }
      path = files.single;
    }
    path = await reader.resolveProject(path);
    return DotnetTagProject(
      path: path,
      directory: p.dirname(path),
      bytes: await reader.read(path),
    );
  }
}
