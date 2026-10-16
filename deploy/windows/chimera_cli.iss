#ifndef AppVersion
  #error AppVersion is required
#endif
#ifndef SourceExecutable
  #error SourceExecutable is required
#endif
#ifndef OutputDirectory
  #error OutputDirectory is required
#endif
#ifndef OutputBaseName
  #error OutputBaseName is required
#endif

[Setup]
AppId={{98CA82DC-2E3D-4E25-AFCD-257F4947C832}
AppName=Chimera CLI
AppVersion={#AppVersion}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
ChangesEnvironment=yes
Compression=lzma2
DefaultDirName={autopf}\Chimera CLI
OutputBaseFilename={#OutputBaseName}
OutputDir={#OutputDirectory}
PrivilegesRequired=admin
SolidCompression=yes

[Files]
Source: "{#SourceExecutable}"; DestDir: "{app}"; DestName: "chimera.exe"; Flags: ignoreversion

[Registry]
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}"; Check: NeedsPathUpdate(ExpandConstant('{app}'))

[Code]
function NeedsPathUpdate(Path: string): Boolean;
var
  ExistingPath: string;
begin
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'Path', ExistingPath) then
    ExistingPath := '';
  Result := Pos(';' + Uppercase(Path) + ';', ';' + Uppercase(ExistingPath) + ';') = 0;
end;
