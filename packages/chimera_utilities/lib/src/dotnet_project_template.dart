import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'project_template.dart';

// dotnet-tools 7cd0a4867dbbd0301ddb5e6a207fbb0b29c56998; UTF-8 LF.
const minimalDotnetProjectTemplate = r'''<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <LangVersion>latest</LangVersion>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
</Project>
''';
const nugetDotnetProjectTemplate = r'''<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <LangVersion>latest</LangVersion>
    <Authors>__AUTHOR__</Authors>
    <Company>__AUTHOR__</Company>
    <Description>__DESCRIPTION__</Description>
    <DocumentationFile>bin\$(Configuration)\$(TargetFramework)\$(AssemblyName).xml</DocumentationFile>
    <EmitCompilerGeneratedFiles>true</EmitCompilerGeneratedFiles>
    <GenerateDocumentationFile>true</GenerateDocumentationFile>
    <GeneratePackageOnBuild>false</GeneratePackageOnBuild>
    <ImplicitUsings>enable</ImplicitUsings>
    <IncludeSymbols>false</IncludeSymbols>
    <Nullable>enable</Nullable>
    <PackageId>__PACKAGE_ID__</PackageId>
    <PackageLicenseFile>LICENSE</PackageLicenseFile>
    <PackageProjectUrl></PackageProjectUrl>
    <PackageReadmeFile>README.md</PackageReadmeFile>
    <PackageTags></PackageTags>
    <RepositoryUrl>__REPOSITORY_URL__</RepositoryUrl>
    <Version>__VERSION__</Version>
  </PropertyGroup>
  <ItemGroup>
    <None Include="..\README.md" Pack="true" PackagePath="" />
    <None Include="..\LICENSE" Pack="true" PackagePath="" />
  </ItemGroup>
</Project>
''';

TemplateBundle renderDotnetProject(String name, {required bool nuget}) {
  var content = nuget
      ? nugetDotnetProjectTemplate
      : minimalDotnetProjectTemplate;
  if (nuget) {
    content = content.replaceAll(RegExp(r'__[A-Z_]+__'), '');
    for (final tag in [
      'PackageLicenseFile',
      'PackageReadmeFile',
      'Authors',
      'Company',
      'Description',
      'PackageId',
      'Version',
      'RepositoryUrl',
    ]) {
      content = content.replaceAll(
        RegExp('<$tag>.*?</$tag>', dotAll: true),
        '<$tag></$tag>',
      );
    }
  }
  final path = '$name.csproj';
  return TemplateBundle(
    version: 'dotnet-tools@7cd0a4867dbbd0301ddb5e6a207fbb0b29c56998',
    files: {path: content},
    digests: {path: sha256.convert(utf8.encode(content)).toString()},
  );
}
