import 'result.dart';

enum ReleasePlatform { windows, linux }

enum ReleaseApplication { desktop, cli }

enum ReleasePackageType { portable, installer }

final class SemanticVersion implements Comparable<SemanticVersion> {
  const SemanticVersion._({
    required this.major,
    required this.minor,
    required this.patch,
    required this.prerelease,
    required this.build,
  });

  static final RegExp _pattern = RegExp(
    r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
    r'(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?'
    r'(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$',
  );
  static final RegExp _numericIdentifier = RegExp(r'^\d+$');

  factory SemanticVersion.parse(String value) {
    final match = _pattern.firstMatch(value);
    if (match == null) {
      throw ArgumentError.value(value, 'value', 'must be a semantic version');
    }
    final prerelease = match.group(4)?.split('.') ?? const <String>[];
    if (prerelease.any(
      (identifier) =>
          identifier.length > 1 &&
          identifier.startsWith('0') &&
          _numericIdentifier.hasMatch(identifier),
    )) {
      throw ArgumentError.value(value, 'value', 'must be a semantic version');
    }
    return SemanticVersion._(
      major: BigInt.parse(match.group(1)!),
      minor: BigInt.parse(match.group(2)!),
      patch: BigInt.parse(match.group(3)!),
      prerelease: List<String>.unmodifiable(prerelease),
      build: List<String>.unmodifiable(
        match.group(5)?.split('.') ?? const <String>[],
      ),
    );
  }

  static SemanticVersion? tryParse(String value) {
    try {
      return SemanticVersion.parse(value);
    } on ArgumentError {
      return null;
    }
  }

  final BigInt major;
  final BigInt minor;
  final BigInt patch;
  final List<String> prerelease;
  final List<String> build;

  @override
  int compareTo(SemanticVersion other) {
    final core = _compareIntegers(
      <BigInt>[major, minor, patch],
      <BigInt>[other.major, other.minor, other.patch],
    );
    if (core != 0) {
      return core;
    }
    if (prerelease.isEmpty || other.prerelease.isEmpty) {
      if (prerelease.isEmpty && other.prerelease.isEmpty) {
        return 0;
      }
      return prerelease.isEmpty ? 1 : -1;
    }
    for (
      var index = 0;
      index < prerelease.length && index < other.prerelease.length;
      index++
    ) {
      final comparison = _compareIdentifier(
        prerelease[index],
        other.prerelease[index],
      );
      if (comparison != 0) {
        return comparison;
      }
    }
    return prerelease.length.compareTo(other.prerelease.length);
  }

  static int _compareIntegers(List<BigInt> left, List<BigInt> right) {
    for (var index = 0; index < left.length; index++) {
      final comparison = left[index].compareTo(right[index]);
      if (comparison != 0) {
        return comparison;
      }
    }
    return 0;
  }

  static int _compareIdentifier(String left, String right) {
    final leftNumeric = _numericIdentifier.hasMatch(left);
    final rightNumeric = _numericIdentifier.hasMatch(right);
    if (leftNumeric && rightNumeric) {
      final lengthComparison = left.length.compareTo(right.length);
      return lengthComparison == 0 ? left.compareTo(right) : lengthComparison;
    }
    if (leftNumeric) {
      return -1;
    }
    if (rightNumeric) {
      return 1;
    }
    return left.compareTo(right);
  }

  @override
  bool operator ==(Object other) =>
      other is SemanticVersion && compareTo(other) == 0;

  @override
  int get hashCode =>
      Object.hash(major, minor, patch, Object.hashAll(prerelease));

  @override
  String toString() {
    final prereleaseSuffix = prerelease.isEmpty
        ? ''
        : '-${prerelease.join('.')}';
    final buildSuffix = build.isEmpty ? '' : '+${build.join('.')}';
    return '$major.$minor.$patch$prereleaseSuffix$buildSuffix';
  }
}

final class ReleaseMetadata {
  const ReleaseMetadata({
    required this.releaseVersion,
    required this.platform,
    required this.application,
    required this.packageType,
    required this.downloadUrl,
    required this.checksum,
  });

  final SemanticVersion releaseVersion;
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
  static const Set<String> _fields = <String>{
    'releaseVersion',
    'platform',
    'application',
    'packageType',
    'downloadUrl',
    'checksum',
  };
  static final RegExp _sha256 = RegExp(r'^[0-9A-Fa-f]{64}$');

  static ReleaseMetadataValidationResult validate(Map<String, Object?> value) {
    final errors = <String>[
      for (final field in value.keys)
        if (!_fields.contains(field)) field,
    ];
    final releaseVersionValue = _validString(value, 'releaseVersion', errors);
    final releaseVersion = releaseVersionValue == null
        ? null
        : SemanticVersion.tryParse(releaseVersionValue);
    if (releaseVersionValue != null && releaseVersion == null) {
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

abstract interface class ReleaseMetadataSource {
  Future<ChimeraResult<List<Map<String, Object?>>>> fetch(Uri endpoint);
}

final class UpdateTarget {
  const UpdateTarget({
    required this.platform,
    required this.application,
    required this.packageType,
  });

  final ReleasePlatform platform;
  final ReleaseApplication application;
  final ReleasePackageType packageType;

  bool accepts(ReleaseMetadata metadata) =>
      metadata.platform == platform &&
      metadata.application == application &&
      metadata.packageType == packageType;
}

enum UpdateCheckStatus { current, available }

final class UpdateCheckResult {
  const UpdateCheckResult._({
    required this.status,
    required this.installedVersion,
    required this.availableRelease,
  });

  const UpdateCheckResult.current(SemanticVersion installedVersion)
    : this._(
        status: UpdateCheckStatus.current,
        installedVersion: installedVersion,
        availableRelease: null,
      );

  const UpdateCheckResult.available(
    SemanticVersion installedVersion,
    ReleaseMetadata availableRelease,
  ) : this._(
        status: UpdateCheckStatus.available,
        installedVersion: installedVersion,
        availableRelease: availableRelease,
      );

  final UpdateCheckStatus status;
  final SemanticVersion installedVersion;
  final ReleaseMetadata? availableRelease;
}

final class UpdateCheckService {
  const UpdateCheckService(this._source);

  final ReleaseMetadataSource _source;

  Future<ChimeraResult<UpdateCheckResult>> check({
    required Uri endpoint,
    required String installedVersion,
    required UpdateTarget target,
  }) async {
    final installed = SemanticVersion.tryParse(installedVersion);
    if (installed == null) {
      return const ChimeraFailure<UpdateCheckResult>(
        kind: FailureKind.update,
        code: 'invalid-installed-version',
        messageKey: 'error.update.invalidInstalledVersion',
      );
    }

    final ChimeraResult<List<Map<String, Object?>>> sourceResult;
    try {
      sourceResult = await _source.fetch(endpoint);
    } on Object {
      return const ChimeraFailure<UpdateCheckResult>(
        kind: FailureKind.update,
        code: 'release-metadata-source-failed',
        messageKey: 'error.update.checkFailed',
      );
    }
    return sourceResult.fold(
      onSuccess: (values) => _select(values, installed, target),
      onFailure: (failure) => ChimeraFailure<UpdateCheckResult>(
        kind: FailureKind.update,
        code: 'release-metadata-source-failed',
        messageKey: 'error.update.checkFailed',
        details: <String, Object?>{'sourceCode': failure.code},
      ),
    );
  }

  ChimeraResult<UpdateCheckResult> _select(
    List<Map<String, Object?>> values,
    SemanticVersion installed,
    UpdateTarget target,
  ) {
    final compatible = <ReleaseMetadata>[];
    for (var index = 0; index < values.length; index++) {
      final validation = ReleaseMetadataValidator.validate(values[index]);
      if (!validation.isValid) {
        return ChimeraFailure<UpdateCheckResult>(
          kind: FailureKind.update,
          code: 'invalid-release-metadata',
          messageKey: 'error.update.invalidMetadata',
          details: <String, Object?>{
            'index': index,
            'fields': validation.errors,
          },
        );
      }
      if (target.accepts(validation.metadata!)) {
        compatible.add(validation.metadata!);
      }
    }
    compatible.sort(
      (left, right) => right.releaseVersion.compareTo(left.releaseVersion),
    );
    final available = compatible.where(
      (metadata) => metadata.releaseVersion.compareTo(installed) > 0,
    );
    if (available.isEmpty) {
      return ChimeraSuccess<UpdateCheckResult>(
        UpdateCheckResult.current(installed),
      );
    }
    return ChimeraSuccess<UpdateCheckResult>(
      UpdateCheckResult.available(installed, available.first),
    );
  }
}

final class TemporaryUpdateArtifact {
  const TemporaryUpdateArtifact({
    required this.rootPath,
    required this.artifactPath,
  });

  final String rootPath;
  final String artifactPath;
}

abstract interface class UpdateTemporaryStorage {
  Future<ChimeraResult<TemporaryUpdateArtifact>> createFor(Uri source);

  Future<ChimeraResult<void>> cleanup(TemporaryUpdateArtifact artifact);
}

abstract interface class UpdateArtifactDownloader {
  Future<ChimeraResult<void>> download({
    required Uri source,
    required String destinationPath,
  });
}

abstract interface class UpdateChecksumVerifier {
  Future<ChimeraResult<bool>> verifySha256({
    required String path,
    required String expectedDigest,
  });
}

enum UpdateApplyStatus { applied, scheduled }

final class UpdateInstallResult {
  const UpdateInstallResult({
    required this.restartRequired,
    this.cleanupDeferred = false,
    this.status = UpdateApplyStatus.applied,
  });

  final bool restartRequired;
  final bool cleanupDeferred;
  final UpdateApplyStatus status;
}

abstract interface class UpdateInstaller {
  Future<ChimeraResult<UpdateInstallResult>> install({
    required ReleaseMetadata release,
    required String artifactPath,
  });
}

final class UpdateApplyRequest {
  const UpdateApplyRequest({required this.release, required this.accepted});

  final ReleaseMetadata release;
  final bool accepted;
}

final class UpdateApplyResult {
  const UpdateApplyResult({
    required this.release,
    required this.restartRequired,
    this.status = UpdateApplyStatus.applied,
  });

  final ReleaseMetadata release;
  final bool restartRequired;
  final UpdateApplyStatus status;
}

final class UpdateApplyService {
  const UpdateApplyService({
    required UpdateTemporaryStorage storage,
    required UpdateArtifactDownloader downloader,
    required UpdateChecksumVerifier verifier,
    required UpdateInstaller installer,
  }) : // Keep descriptive public constructor parameters while retaining
       // private dependencies.
       // ignore: prefer_initializing_formals
       _storage = storage,
       // ignore: prefer_initializing_formals
       _downloader = downloader,
       // ignore: prefer_initializing_formals
       _verifier = verifier,
       // ignore: prefer_initializing_formals
       _installer = installer;

  final UpdateTemporaryStorage _storage;
  final UpdateArtifactDownloader _downloader;
  final UpdateChecksumVerifier _verifier;
  final UpdateInstaller _installer;

  Future<ChimeraResult<UpdateApplyResult>> apply(
    UpdateApplyRequest request,
  ) async {
    if (!request.accepted) {
      return _failure(
        'update-approval-required',
        'error.update.approvalRequired',
      );
    }
    if (request.release.packageType != ReleasePackageType.installer) {
      return _failure(
        'unsupported-update-package',
        'error.update.unsupportedPackage',
      );
    }

    final ChimeraResult<TemporaryUpdateArtifact> staging;
    try {
      staging = await _storage.createFor(request.release.downloadUrl);
    } on Object {
      return _failure('update-download-failed', 'error.update.downloadFailed');
    }
    if (staging case ChimeraFailure<TemporaryUpdateArtifact>()) {
      return _failure('update-download-failed', 'error.update.downloadFailed');
    }
    final artifact = (staging as ChimeraSuccess<TemporaryUpdateArtifact>).value;

    var activeFailureCode = 'update-download-failed';
    var activeMessageKey = 'error.update.downloadFailed';
    var cleanupDeferred = false;
    ChimeraResult<UpdateApplyResult> outcome;
    try {
      final download = await _downloader.download(
        source: request.release.downloadUrl,
        destinationPath: artifact.artifactPath,
      );
      if (download case ChimeraFailure<void>()) {
        outcome = _failure(activeFailureCode, activeMessageKey);
      } else {
        activeFailureCode = 'update-checksum-failed';
        activeMessageKey = 'error.update.checksumFailed';
        final verification = await _verifier.verifySha256(
          path: artifact.artifactPath,
          expectedDigest: request.release.checksum,
        );
        if (verification case ChimeraFailure<bool>()) {
          outcome = _failure(activeFailureCode, activeMessageKey);
        } else if (!(verification as ChimeraSuccess<bool>).value) {
          outcome = _failure(activeFailureCode, activeMessageKey);
        } else {
          activeFailureCode = 'update-install-failed';
          activeMessageKey = 'error.update.installFailed';
          final installation = await _installer.install(
            release: request.release,
            artifactPath: artifact.artifactPath,
          );
          if (installation case ChimeraFailure<UpdateInstallResult>(
            :final code,
          )) {
            outcome = code == 'update-elevation-denied'
                ? _failure(
                    'update-elevation-denied',
                    'error.update.elevationDenied',
                  )
                : _failure(activeFailureCode, activeMessageKey);
          } else {
            final installed =
                (installation as ChimeraSuccess<UpdateInstallResult>).value;
            cleanupDeferred = installed.cleanupDeferred;
            outcome = ChimeraSuccess<UpdateApplyResult>(
              UpdateApplyResult(
                release: request.release,
                restartRequired: installed.restartRequired,
                status: installed.status,
              ),
            );
          }
        }
      }
    } on Object {
      outcome = _failure(activeFailureCode, activeMessageKey);
    }

    var cleanupSucceeded = cleanupDeferred;
    if (!cleanupDeferred) {
      try {
        final cleanup = await _storage.cleanup(artifact);
        cleanupSucceeded = cleanup is ChimeraSuccess<void>;
      } on Object {
        cleanupSucceeded = false;
      }
    }
    if (!cleanupSucceeded) {
      return _failure(
        'update-cleanup-failed',
        'error.update.cleanupFailed',
        details: <String, Object?>{
          if (outcome case ChimeraFailure<UpdateApplyResult>(:final code))
            'priorCode': code,
        },
      );
    }
    return outcome;
  }

  ChimeraFailure<UpdateApplyResult> _failure(
    String code,
    String messageKey, {
    Map<String, Object?> details = const <String, Object?>{},
  }) => ChimeraFailure<UpdateApplyResult>(
    kind: FailureKind.update,
    code: code,
    messageKey: messageKey,
    details: details,
  );
}
