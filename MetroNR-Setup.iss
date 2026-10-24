#define MyAppName "Metro Redux Next-Gen DLSS 5 RTX 40"
#define MyAppVersion "1.0.0-lastlight-preview1"
[Setup]
AppId={{3AE8A46A-BD3B-43DB-9E27-4BC7F50104B1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=JungleHam
AppPublisherURL=https://github.com/JungleHam/Metro-2033-NextGen-DLSS5-RTX40-enabler
AppSupportURL=https://github.com/JungleHam/Metro-2033-NextGen-DLSS5-RTX40-enabler/issues
DefaultDirName={localappdata}\Programs\Metro NR RTX40
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=build
OutputBaseFilename=Metro-NR-RTX40-Setup-v1.0.0-lastlight-preview1
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
Uninstallable=no
; The game mod is uninstalled from the graphical manager, with ownership checks.
[Files]
Source: "_release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion
[Run]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoLogo -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\MetroNR-Manager.ps1"""; Description: "Open Metro NR Setup (install or uninstall)"; Flags: postinstall nowait skipifsilent runhidden
[Icons]
Name: "{autoprograms}\Metro NR RTX40\Install or Uninstall"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoLogo -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\MetroNR-Manager.ps1"""
