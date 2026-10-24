#define MyAppName "Metro 2033 Next-Gen DLSS 5 RTX 40"
#define MyAppVersion "1.0.0-rc1"
[Setup]
AppId={{3AE8A46A-BD3B-43DB-9E27-4BC7F50104B1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=JungleHam
AppPublisherURL=https://github.com/JungleHam/Metro-2033-NextGen-DLSS5-RTX40
AppSupportURL=https://github.com/JungleHam/Metro-2033-NextGen-DLSS5-RTX40/issues
DefaultDirName={localappdata}\Programs\Metro NR RTX40
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=build
OutputBaseFilename=Metro-NR-RTX40-Setup-v1.0.0-rc1
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
Uninstallable=no
[Files]
Source: "_release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion
[Run]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -STA -ExecutionPolicy Bypass -File ""{app}\Install.ps1"""; Description: "Configure Metro, verify or prepare the NR DLL, and install"; Flags: postinstall waituntilterminated skipifsilent
[Icons]
Name: "{autoprograms}\Metro NR RTX40\Uninstall game mod"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Uninstall.ps1"""
