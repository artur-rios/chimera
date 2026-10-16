#ifndef AppVersion
  #error AppVersion is required
#endif
#ifndef SourceDirectory
  #error SourceDirectory is required
#endif
#ifndef OutputDirectory
  #error OutputDirectory is required
#endif
#ifndef OutputBaseName
  #error OutputBaseName is required
#endif

[Setup]
AppId={{58E29B14-AE05-4C06-9175-C0D17E681F51}
AppName=Chimera
AppVersion={#AppVersion}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma2
DefaultDirName={autopf}\Chimera
DefaultGroupName=Chimera
OutputBaseFilename={#OutputBaseName}
OutputDir={#OutputDirectory}
PrivilegesRequired=lowest
SolidCompression=yes
UninstallDisplayIcon={app}\chimera_gui.exe

[Files]
Source: "{#SourceDirectory}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Chimera"; Filename: "{app}\chimera_gui.exe"
Name: "{autodesktop}\Chimera"; Filename: "{app}\chimera_gui.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"

