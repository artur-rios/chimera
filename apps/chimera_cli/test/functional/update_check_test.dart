import 'dart:convert';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'GivenUpdateCheckHelp_WhenRequested_ThenSpecificUsageIsPrinted',
    () async {
      final out = StringBuffer();

      final exitCode = await runChimera(
        const <String>['update', 'check', '--help'],
        localeTag: 'en',
        out: out,
        err: StringBuffer(),
      );

      expect(exitCode, 0);
      expect(out.toString(), contains('chimera update check'));
    },
  );

  test(
    'GivenNewerRelease_WhenUpdateCheckedAsJson_ThenStableResultIsWritten',
    () async {
      final source = _Source(<Map<String, Object?>>[_metadata('1.2.0')]);
      final out = StringBuffer();
      final exitCode = await runChimera(
        <String>[
          'update',
          'check',
          '--current-version=1.0.0',
          '--platform=windows',
          '--json',
        ],
        localeTag: 'en',
        out: out,
        err: StringBuffer(),
        updateCheckService: UpdateCheckService(source),
      );

      expect(exitCode, 0);
      expect(jsonDecode(out.toString()), <String, Object?>{
        'status': 'available',
        'installedVersion': '1.0.0',
        'availableVersion': '1.2.0',
        'platform': 'windows',
        'application': 'cli',
        'packageType': 'installer',
        'downloadUrl': 'https://github.com/example/chimera/releases/download/v1.2.0/chimera.zip',
        'checksum':
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        'approvalRequired': true,
      });
      expect(source.requested, hasLength(1));
    },
  );

  for (final locale in <String>['en', 'pt-BR']) {
    test(
      'GivenCurrentRelease_WhenUpdateCheckedIn${locale}_ThenCurrentIsLocalized',
      () async {
        final out = StringBuffer();
        final exitCode = await runChimera(
          <String>[
            'update',
            'check',
            '--current-version=1.2.0',
            '--platform=windows',
          ],
          localeTag: locale,
          out: out,
          err: StringBuffer(),
          updateCheckService: UpdateCheckService(
            _Source(<Map<String, Object?>>[_metadata('1.2.0')]),
          ),
        );
        expect(exitCode, 0);
        expect(out.toString(), contains('1.2.0'));
        expect(
          out.toString(),
          contains(locale == 'en' ? 'current' : 'atualizado'),
        );
      },
    );

    test(
      'GivenAvailableRelease_WhenUpdateCheckedIn${locale}_ThenChecksumIsDescribed',
      () async {
        final out = StringBuffer();
        final exitCode = await runChimera(
          <String>[
            'update',
            'check',
            '--current-version=1.0.0',
            '--platform=windows',
          ],
          localeTag: locale,
          out: out,
          err: StringBuffer(),
          updateCheckService: UpdateCheckService(
            _Source(<Map<String, Object?>>[_metadata('1.2.0')]),
          ),
        );

        expect(exitCode, 0);
        expect(
          out.toString(),
          contains(
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ),
        );
      },
    );
  }

  test(
    'GivenSourceFailure_WhenUpdateChecked_ThenSafeExit69IsReturned',
    () async {
      final err = StringBuffer();
      final exitCode = await runChimera(
        <String>['update', 'check', '--current-version=1.0.0', '--json'],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
        updateCheckService: UpdateCheckService(const _FailingSource()),
      );
      expect(exitCode, 69);
      final value = jsonDecode(err.toString()) as Map<String, dynamic>;
      expect((value['error'] as Map<String, dynamic>)['kind'], 'update');
      expect(err.toString(), isNot(contains('PRIVATE')));
    },
  );

  test(
    'GivenInvalidPlatform_WhenUpdateCheckedAsJson_ThenTypedValidationIsWritten',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>['update', 'check', '--platform=macos', '--json'],
        localeTag: 'en',
        out: out,
        err: err,
      );

      expect(exitCode, 64);
      expect(out, isEmpty);
      final value = jsonDecode(err.toString()) as Map<String, dynamic>;
      final error = value['error'] as Map<String, dynamic>;
      expect(error, containsPair('kind', 'validation'));
      expect(error, containsPair('code', 'update-invalid-options'));
    },
  );
}

Map<String, Object?> _metadata(String version) => <String, Object?>{
  'releaseVersion': version,
  'platform': 'windows',
  'application': 'cli',
  'packageType': 'installer',
  'downloadUrl':
      'https://github.com/example/chimera/releases/download/v$version/chimera.zip',
  'checksum':
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
};

final class _Source implements ReleaseMetadataSource {
  _Source(this.values);
  final List<Map<String, Object?>> values;
  final List<Uri> requested = <Uri>[];
  @override
  Future<ChimeraResult<List<Map<String, Object?>>>> fetch(Uri endpoint) async {
    requested.add(endpoint);
    return ChimeraSuccess<List<Map<String, Object?>>>(values);
  }
}

final class _FailingSource implements ReleaseMetadataSource {
  const _FailingSource();
  @override
  Future<ChimeraResult<List<Map<String, Object?>>>> fetch(Uri endpoint) async =>
      const ChimeraFailure<List<Map<String, Object?>>>(
        kind: FailureKind.update,
        code: 'transport',
        messageKey: 'error.update.checkFailed',
        details: <String, Object?>{'body': 'PRIVATE'},
      );
}
