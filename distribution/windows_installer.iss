; 从工程根目录编译：ISCC.exe distribution\windows_installer.iss
; 必须先按「Windows Desktop」预设导出 build\windows。
[Setup]
AppId={{8E86F0AA-FE1C-4DDD-AD31-6239674835D9}
AppName=诡异事务局 · 得利洗衣店
AppVersion=0.3.1
AppPublisher=诡异事务局项目组
AppPublisherURL=https://github.com/sabrina1647412733-collab/anomaly-bureau-game
DefaultDirName={localappdata}\Programs\AnomalyBureau
DefaultGroupName=诡异事务局
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir=..\build\release
OutputBaseFilename=AnomalyBureau-Setup-0.3.1
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\AnomalyBureau.exe
SetupLogging=yes
CloseApplications=yes
RestartApplications=no
InfoAfterFile=开始游玩说明.txt

[Languages]
Name: "chinesesimplified"; MessagesFile: "ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式 / Desktop shortcut"; Flags: checkedonce

[Files]
Source: "..\build\windows\AnomalyBureau.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\AnomalyBureau.pck"; DestDir: "{app}"; Flags: ignoreversion
Source: "开始游玩说明.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "兼容模式启动.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "Godot-LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "Godot-COPYRIGHT.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "NotoSansSC-LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\诡异事务局 · 得利洗衣店"; Filename: "{app}\AnomalyBureau.exe"; WorkingDir: "{app}"
Name: "{group}\得利洗衣店（兼容模式）"; Filename: "{app}\AnomalyBureau.exe"; Parameters: "--rendering-method gl_compatibility"; WorkingDir: "{app}"
Name: "{group}\开始游玩说明"; Filename: "{app}\开始游玩说明.txt"
Name: "{autodesktop}\诡异事务局 · 得利洗衣店"; Filename: "{app}\AnomalyBureau.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\AnomalyBureau.exe"; Description: "启动得利洗衣店 / Play"; Flags: nowait postinstall skipifsilent
