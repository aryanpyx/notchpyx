; Inno Setup Script for Notchpyx (Native Release)
#define MyAppName "Notchpyx"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Aryan Pandey"
#define MyAppExeName "Notchpyx.exe"

[Setup]
AppId={{5D9E56C3-3298-4B85-802F-A2AE4BF59174}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
OutputDir=dist_installer
OutputBaseFilename=Notchpyx_Setup_v1.0.0
SetupIconFile=windows\runner\resources\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "autostart"; Description: "Launch Notchpyx automatically when Windows starts"; GroupDescription: "Startup:"

[Files]
Source: "c:\Users\aryan\Downloads\Notchpyx_Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "c:\Users\aryan\Downloads\Notchpyx_Release\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "c:\Users\aryan\Downloads\Notchpyx_Release\native_assets.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "c:\Users\aryan\Downloads\Notchpyx_Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\{#MyAppExeName}"
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: autostart; IconFilename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
