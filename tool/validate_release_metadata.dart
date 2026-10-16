import 'dart:convert';
import 'dart:io';

enum ReleasePlatform { windows, linux }

enum ReleaseApplication { desktop, cli }

enum ReleasePackageType { portable, installer }

final class ReleaseMetadata {
  const ReleaseMetadata({
    required this.releaseVersion,
    required this.platform,
    required this.application,
    required this.packageType,
    required this.downloadUrl,
    required this.checksum,
  });

  final String releaseVersion;
  final ReleasePlatform platform;
  final ReleaseApplication application;
  final ReleasePackageType packageType;
  final Uri downloadUrl;
  final String checksum;
}

final class ReleaseMetadataValidationResult {
  const ReleaseMetadataValidationResult({
    required this.metadata,
    required this.errors,
  });

  final ReleaseMetadata? metadata;
  final List<String> errors;
  bool get isValid => metadata != null && errors.isEmpty;
}

abstract final class ReleaseMetadataValidator {
  static final RegExp _semanticVersion = RegExp(
    r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
    r'(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?'
    r'(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
  );
  static final RegExp _sha256 = RegExp(r'^[0-9A-Fa-f]{64}$');

  static ReleaseMetadataValidationResult validate(Map<String, Object?> value) {
    final errors = <String>[];
    final releaseVersion = _validString(value, 'releaseVersion', errors);
    if (releaseVersion != null && !_semanticVersion.hasMatch(releaseVersion)) {
      errors.add('releaseVersion');
    }

    final platform = _parseEnum(
      value,
      'platform',
      ReleasePlatform.values,
      errors,
    );
    final application = _parseEnum(
      value,
      'application',
      ReleaseApplication.values,
      errors,
    );
    final packageType = _parseEnum(
      value,
      'packageType',
      ReleasePackageType.values,
      errors,
    );

    final downloadUrlValue = _validString(value, 'downloadUrl', errors);
    final downloadUrl = downloadUrlValue == null
        ? null
        : Uri.tryParse(downloadUrlValue);
    if (downloadUrlValue != null &&
        (downloadUrl == null ||
            downloadUrl.scheme != 'https' ||
            downloadUrl.host != 'github.com')) {
      errors.add('downloadUrl');
    }

    final checksum = _validString(value, 'checksum', errors);
    if (checksum != null && !_sha256.hasMatch(checksum)) {
      errors.add('checksum');
    }

    final uniqueErrors = errors.toSet().toList(growable: false);
    if (uniqueErrors.isNotEmpty) {
      return ReleaseMetadataValidationResult(
        metadata: null,
        errors: uniqueErrors,
      );
    }

    return ReleaseMetadataValidationResult(
      metadata: ReleaseMetadata(
        releaseVersion: releaseVersion!,
        platform: platform!,
        application: application!,
        packageType: packageType!,
        downloadUrl: downloadUrl!,
        checksum: checksum!,
      ),
      errors: const <String>[],
    );
  }

  static String? _validString(
    Map<String, Object?> value,
    String field,
    List<String> errors,
  ) {
    final candidate = value[field];
    if (candidate is! String || candidate.isEmpty) {
      errors.add(field);
      return null;
    }
    return candidate;
  }

  static T? _parseEnum<T extends Enum>(
    Map<String, Object?> value,
    String field,
    List<T> values,
    List<String> errors,
  ) {
    final candidate = _validString(value, field, errors);
    if (candidate == null) {
      return null;
    }
    for (final enumValue in values) {
      if (enumValue.name == candidate) {
        return enumValue;
      }
    }
    errors.add(field);
    return null;
  }
}

void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/validate_release_metadata.dart <file>',
    );
    exitCode = 64;
    return;
  }

  final decoded = jsonDecode(File(arguments.single).readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    stderr.writeln('Release metadata must be a JSON object.');
    exitCode = 1;
    return;
  }

  final result = ReleaseMetadataValidator.validate(decoded);
  if (!result.isValid) {
    stderr.writeln(
      'Invalid release metadata fields: ${result.errors.join(', ')}',
    );
    exitCode = 1;
    return;
  }

  stdout.writeln('Release metadata: OK');
}
