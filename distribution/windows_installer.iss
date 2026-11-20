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
function ProbeCreateFile(Name: String; Access, Share: Cardinal; Security: THandle;
  Creation, Flags: Cardinal; Template: THandle): THandle;
  external 'CreateFileW@kernel32.dll stdcall';
function ProbeCloseHandle(Handle: THandle): Boolean;
  external 'CloseHandle@kernel32.dll stdcall';
function InstallDriveType(Root: String): Integer;
  external 'GetDriveTypeW@kernel32.dll stdcall';

var WritableDefault: String;

function CheckInstallDirectory(Target: String; var Reason: String): Boolean;
var Probe: String; Handle: THandle; I, ErrorCode: Integer;
begin
  Result := False;
  Reason := '';
  if not ForceDirectories(Target) then begin
    Reason := '无法创建安装目录：' + Target;
    Log('Install directory preflight: create denied: ' + Target);
    Exit;
  end;
  { Check under Setup's actual token. An existing folder or a successful
    Directory.CreateDirectory in the outer process does not establish this. }
  for I := 1 to 32 do begin
    Probe := AddBackslash(Target) + '.ab-install-probe-' +
      GetDateTimeString('yyyymmddhhnnsszzz', '-', ':') + '-' + IntToStr(I) + '.tmp';
    { CREATE_NEW; never open/overwrite an existing file. Request write/delete
      rights, as installation needs both deployment and rollback to work. }
    Handle := ProbeCreateFile(Probe, $40010000, 7, 0, 1, $80, 0);
    if Handle <> THandle(-1) then begin
      ProbeCloseHandle(Handle);
      if not DeleteFile(Probe) then begin
        Reason := '安装目录不允许删除临时文件，无法安全升级或回滚：' + Target;
        Log('Install directory preflight: cleanup denied: ' + Probe);
        Exit;
      end;
      Log('Install directory preflight passed: ' + Target);
      Result := True;
      Exit;
    end;
    ErrorCode := DLLGetLastError;
    if ErrorCode <> 80 then begin
      Reason := '安装程序无法写入所选目录：' + Target + #13#10 +
        'Windows 错误 ' + IntToStr(ErrorCode) + '：' + SysErrorMessage(ErrorCode);
      Log('Install directory preflight failed: ' + Target + '; error=' + IntToStr(ErrorCode));
      Exit;
    end;
  end;
  Reason := '无法在安装目录创建唯一的验证文件：' + Target;
end;

function CheckDefaultParent(Candidate: String; var Reason: String): Boolean;
var ParentDir, Previous: String;
begin
  ParentDir := Candidate;
  while not DirExists(ParentDir) do begin
    Previous := ParentDir;
    ParentDir := ExtractFileDir(ParentDir);
    if (ParentDir = '') or (ParentDir = Previous) then begin Result := False; Exit; end;
  end;
  { Merely suggesting a default must not create unconfirmed install folders.
    The final selected target is checked separately before installation. }
  Result := CheckInstallDirectory(ParentDir, Reason);
end;

function DefaultInstallDir(Param: String): String;
var Candidate, SourceDir, Reason, ExplicitDir, DriveRoot, SystemRoot: String; Letter: Integer;
begin
  ExplicitDir := ExpandConstant('{param:DIR|}');
  if ExplicitDir <> '' then begin Result := ExplicitDir; Exit; end;
  if WritableDefault <> '' then begin Result := WritableDefault; Exit; end;
  SystemRoot := ExpandConstant('{sd}\');
  Candidate := 'F:\Games\AnomalyBureau';
  if (CompareText('F:\', SystemRoot) <> 0) and DirExists('F:\') and CheckDefaultParent(Candidate, Reason) then
    WritableDefault := Candidate
  else begin
    SourceDir := ExpandConstant('{param:ABINSTALLSOURCE|{src}}');
    Candidate := AddBackslash(SourceDir) + '游戏安装\AnomalyBureau';
    { Never silently fall back to the system drive. The wizard remains editable. }
    if (CompareText(Copy(Candidate, 1, 3), SystemRoot) <> 0) and
      CheckDefaultParent(Candidate, Reason) then WritableDefault := Candidate;
  end;
  { Other players may have no F drive. Prefer another writable fixed data drive. }
  if WritableDefault = '' then
    for Letter := 68 to 90 do begin
      DriveRoot := Chr(Letter) + ':\';
      if (CompareText(DriveRoot, SystemRoot) <> 0) and (InstallDriveType(DriveRoot) = 3) then begin
        Candidate := DriveRoot + 'Games\AnomalyBureau';
        if CheckDefaultParent(Candidate, Reason) then begin WritableDefault := Candidate; Break; end;
      end;
    end;
  if WritableDefault <> '' then Result := WritableDefault
  { The directory page always asks the player to confirm this per-user fallback.
    Do not create or probe it merely to display a suggestion. }
  else Result := ExpandConstant('{localappdata}\Programs\AnomalyBureau');
end;

procedure InitializeWizard;
begin
  WizardForm.SelectDirLabel.Caption := '请确认诡异事务局的安装位置。优先使用可写的数据盘；升级时选择原目录。存档与设置会保留。';
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var Reason: String;
begin
  Result := True;
  if (CurPageID = wpSelectDir) and not WizardSilent then begin
    Result := CheckInstallDirectory(WizardDirValue, Reason);
    if not Result then
      MsgBox(Reason + #13#10#13#10 +
        '请选择其他可写入目录。安装尚未开始，原游戏和存档未被修改。',
        mbError, MB_OK);
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var Locator, Service, Processes, Process: Variant; I: Integer; Target, Reason: String;
begin
  Result := '';
  if not CheckInstallDirectory(ExpandConstant('{app}'), Reason) then begin
    Result := Reason + #13#10 + '请返回目录选择页面，更换为可写入的位置。';
    Exit;
  end;
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
