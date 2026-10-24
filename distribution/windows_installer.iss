#ifndef AppVersion
  #define AppVersion "0.7.0"
#endif
#ifndef RuntimeDir
  #error RuntimeDir is required
#endif
#ifndef ReleaseDir
  #error ReleaseDir is required
#endif
#ifndef TempHostDir
  #error TempHostDir is required; use build_installer.ps1
#endif

[Setup]
AppId={{8E86F0AA-FE1C-4DDD-AD31-6239674835D9}
AppName=诡异事务局
AppVersion={#AppVersion}
AppPublisher=诡异事务局项目组
AppPublisherURL=https://github.com/sabrina1647412733-collab/anomaly-bureau-game
DefaultDirName={code:DefaultInstallDir}
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#ReleaseDir}
OutputBaseFilename=AnomalyBureau-Setup-{#AppVersion}
SetupIconFile={#RuntimeDir}\AnomalyBureau.ico
Compression=lzma2/fast
SolidCompression=no
WizardStyle=modern
DisableDirPage=no
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\AnomalyBureau.exe
; File-local uninstall works even when HKCU and Start Menu writes are denied.
CreateUninstallRegKey=no
UsePreviousAppDir=no
UsePreviousTasks=no
SetupLogging=yes
CloseApplications=no
RestartApplications=no
ExtraDiskSpaceRequired=1073741824

[Languages]
Name: "chinesesimplified"; MessagesFile: "ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; Flags: checkedonce

[Files]
Source: "{#RuntimeDir}\_运行文件\packs\*.zip"; DestDir: "{app}\_运行文件\packs"; Flags: ignoreversion
Source: "{#RuntimeDir}\AnomalyBureau.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RuntimeDir}\AnomalyBureau.Game.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RuntimeDir}\AnomalyBureau.Game.pck"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RuntimeDir}\AnomalyBureau.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#TempHostDir}\AnomalyBureau.Uninstall.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RuntimeDir}\*.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RuntimeDir}\兼容模式启动.bat"; DestDir: "{app}"; Flags: ignoreversion
; Activate the complete resource set only after all immutable packs are installed.
Source: "{#RuntimeDir}\_运行文件\active.json"; DestDir: "{app}\_运行文件"; Flags: ignoreversion

[Icons]
Name: "{app}\诡异事务局"; Filename: "{app}\AnomalyBureau.exe"; WorkingDir: "{app}"; IconFilename: "{app}\AnomalyBureau.ico"
Name: "{app}\卸载诡异事务局"; Filename: "{app}\AnomalyBureau.Uninstall.exe"; WorkingDir: "{app}"; IconFilename: "{app}\AnomalyBureau.ico"

[UninstallDelete]
Type: filesandordirs; Name: "{app}\_运行文件"
Type: filesandordirs; Name: "{app}\_更新缓存"
Type: files; Name: "{app}\desktop-shortcut.txt"

[Run]
Filename: "{app}\AnomalyBureau.exe"; Description: "启动诡异事务局"; Flags: nowait postinstall skipifsilent unchecked

[Code]
function DefaultInstallDir(Param: String): String;
begin
  if DirExists('F:\') then Result := 'F:\Games\AnomalyBureau'
  else Result := ExpandConstant('{userdocs}\AnomalyBureau');
end;

procedure InitializeWizard;
begin
  WizardForm.SelectDirLabel.Caption := '请选择诡异事务局的安装位置。建议F盘；升级时选择原目录。存档与设置会保留。';
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var Locator, Service, Processes, Process: Variant; I: Integer; Target: String;
begin
  Result := '';
  Target := Lowercase(ExpandConstant('{app}\AnomalyBureau.Game.exe'));
  try
    Locator := CreateOleObject('WbemScripting.SWbemLocator');
    Service := Locator.ConnectServer('', 'root\CIMV2');
    Processes := Service.ExecQuery('SELECT ExecutablePath FROM Win32_Process WHERE Name="AnomalyBureau.Game.exe"');
    for I := 0 to Processes.Count - 1 do begin
      Process := Processes.ItemIndex(I);
      if not VarIsNull(Process.ExecutablePath) then
        if Lowercase(String(Process.ExecutablePath)) = Target then begin
          Result := '请先正常退出此目录中的诡异事务局，再安装或升级。安装器不会关闭游戏。';
          Exit;
        end;
    end;
  except
    Log('Process inventory unavailable; Windows file locks remain enforced.');
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var DesktopDir, Shortcut, ErrorText: String;
begin
  if (CurStep = ssPostInstall) and WizardIsTaskSelected('desktopicon') then begin
    DesktopDir := ExpandConstant('{param:DESKTOPDIR|{userdesktop}}');
    Shortcut := AddBackslash(DesktopDir) + '诡异事务局.lnk';
    try
      ForceDirectories(DesktopDir);
      CreateShellLink(Shortcut, '诡异事务局', ExpandConstant('{app}\AnomalyBureau.exe'), '', ExpandConstant('{app}'), ExpandConstant('{app}\AnomalyBureau.ico'), 0, SW_SHOWNORMAL);
      SaveStringToFile(ExpandConstant('{app}\desktop-shortcut.txt'), Shortcut, False);
      Log('Desktop shortcut created: ' + Shortcut);
    except
      ErrorText := GetExceptionMessage;
      Log('Desktop shortcut could not be created: ' + ErrorText);
      if not WizardSilent then MsgBox('游戏已安装。桌面目录不允许写入，请使用安装目录内的“诡异事务局”快捷方式。' + #13#10 + ErrorText, mbInformation, MB_OK);
    end;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var Shortcut: AnsiString;
begin
  if CurUninstallStep = usUninstall then begin
    if LoadStringFromFile(ExpandConstant('{app}\desktop-shortcut.txt'), Shortcut) then begin
      if ExtractFileName(String(Shortcut)) = '诡异事务局.lnk' then DeleteFile(String(Shortcut));
    end;
  end;
end;
