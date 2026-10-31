import 'dart:io';

import 'package:test/test.dart';

void main() {
  late String dockerfile;
  late String nginxConfig;

  setUpAll(() {
    dockerfile = File('deploy/web/Dockerfile').readAsStringSync();
    nginxConfig = File('deploy/web/nginx.conf').readAsStringSync();
  });

  test('GivenWebImage_WhenBuilt_ThenFlutterAndRuntimeStagesArePinnedAndUnprivileged', () {
    expect(dockerfile, contains('ARG FLUTTER_VERSION=3.47.7'));
    expect(dockerfile, contains('ARG FLUTTER_SHA256='));
    expect(dockerfile, contains('nginxinc/nginx-unprivileged:'));
    expect(dockerfile, contains('USER 101'));
    expect(dockerfile, contains('EXPOSE 8080'));
    expect(dockerfile, contains(r'CMD test "$(wget -qO-'));
    expect(dockerfile, isNot(contains('CMD-SHELL')));
  });

  test(
    'GivenDeploymentEnvironment_WhenImageIsBuilt_ThenEnvironmentLabelIsPresent',
    () {
      expect(dockerfile, contains('ARG YGG_ENVIRONMENT=local'));
      expect(
        dockerfile,
        contains(r'LABEL io.chimera.environment=$YGG_ENVIRONMENT'),
      );
    },
  );

  test('GivenWebRuntime_WhenHealthIsRequested_ThenOnlyOkStatusIsReturned', () {
    expect(nginxConfig, contains('listen 8080'));
    expect(nginxConfig, contains('location = /healthz'));
    expect(nginxConfig, contains("return 200 '{\"status\":\"ok\"}'"));
    expect(nginxConfig, isNot(contains(r'$hostname')));
    expect(nginxConfig, isNot(contains(r'$nginx_version')));
  });

  test('GivenCompiledWebAssets_WhenServed_ThenSpaFallbackAndImmutableCachingAreConfigured', () {
    expect(nginxConfig, contains(r'try_files $uri $uri/ /index.html'));
    expect(nginxConfig, contains('Cache-Control'));
    expect(nginxConfig, contains('immutable'));
  });

  test('GivenContainerBuild_WhenInputsAreDeclared_ThenNoSecretInputsExist', () {
    final buildInput = RegExp(r'^\s*(?:ARG|ENV)\s+([^=\s]+)', multiLine: true);
    final forbidden = RegExp(
      r'(?:SECRET|TOKEN|PASSWORD|CREDENTIAL|PRIVATE_KEY|API_KEY)',
      caseSensitive: false,
    );
    final names = buildInput
        .allMatches(dockerfile)
        .map((match) => match.group(1)!)
        .where(forbidden.hasMatch);

    expect(names, isEmpty);
  });

  test(
    'GivenRepository_WhenContainerSmokeIsNeeded_ThenBothShellsAreSupported',
    () {
      expect(File('tool/smoke_container.ps1').existsSync(), isTrue);
      expect(File('tool/smoke_container.sh').existsSync(), isTrue);
    },
  );
}
