param(
    [Parameter(Mandatory=$true)][string]$Installer,
    [Parameter(Mandatory=$true)][string]$RuntimeDirectory,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)
# Run this driver through updater/HiddenDesktop.cs. It never launches Godot.
$ErrorActionPreference='Stop'
$out=[IO.Path]::GetFullPath($OutputDirectory)
if($out -notmatch '^[Ff]:\\' -or (Test-Path -LiteralPath $out)) {throw 'Use a fresh F: test directory'}
New-Item -ItemType Directory -Path $out,(Join-Path $out 'desktop'),(Join-Path $out 'driver-temp') | Out-Null
$env:TEMP=Join-Path $out 'driver-temp'; $env:TMP=$env:TEMP
$passed=0
$results=[Collections.Generic.List[string]]::new()
function Check([bool]$condition,[string]$message) {
    if(-not $condition) {throw $message}
    $script:passed++; $script:results.Add($message)
    Add-Content -LiteralPath (Join-Path $out 'progress.txt') -Value ('PASS '+$message)
}
function Run([string]$file,[string]$arguments,[string]$parentTemp) {
    $info=[Diagnostics.ProcessStartInfo]::new($file,$arguments)
    $info.UseShellExecute=$false; $info.WorkingDirectory=$out
    $info.EnvironmentVariables['TEMP']=$parentTemp; $info.EnvironmentVariables['TMP']=$parentTemp
    $process=[Diagnostics.Process]::Start($info)
    if(-not $process.WaitForExit(180000)) {throw 'Isolated installer did not exit; no processes killed'}
    $exit=$process.ExitCode; $process.Dispose(); return $exit
}
function Install([string]$label,[string]$parentTemp) {
    $arguments='/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /DIR="'+$sandbox+'" /DESKTOPDIR="'+(Join-Path $out 'desktop')+'" /TASKS=desktopicon /LOG="'+(Join-Path $out ($label+'.log'))+'"'
    Check ((Run $Installer $arguments $parentTemp) -eq 0) ($label+' exits successfully')
    foreach($name in @('AnomalyBureau.exe','AnomalyBureau.Game.exe','AnomalyBureau.Game.pck','_运行文件/active.json')) {
        Check ((Get-FileHash -LiteralPath (Join-Path $sandbox $name)).Hash -eq (Get-FileHash -LiteralPath (Join-Path $RuntimeDirectory $name)).Hash) ($label+' exact runtime '+$name)
    }
    $log=Get-Content -LiteralPath (Join-Path $out ($label+'.log')) -Raw
    Check ($log -match 'Created temporary directory: F:\\') ($label+' Inno temporary directory is on F:')
}
$sandbox=Join-Path $out '安装测试 中文 空格'
$originalUserTemp=[Environment]::GetEnvironmentVariable('TEMP','User')
$originalUserTmp=[Environment]::GetEnvironmentVariable('TMP','User')
Install 'default-user-temp' $originalUserTemp
$shell=New-Object -ComObject WScript.Shell
$shortcut=$shell.CreateShortcut((Join-Path $out 'desktop/诡异事务局.lnk'))
Check ($shortcut.TargetPath -eq (Join-Path $sandbox 'AnomalyBureau.exe')) 'desktop shortcut targets stable launcher'
$uninstallLink=$shell.CreateShortcut((Join-Path $sandbox '卸载诡异事务局.lnk'))
Check ($uninstallLink.TargetPath -eq (Join-Path $sandbox 'AnomalyBureau.Uninstall.exe')) 'uninstall shortcut uses temp-safe host'
$player=Join-Path $sandbox '_玩家数据'
New-Item -ItemType Directory -Path $player | Out-Null
[IO.File]::WriteAllText((Join-Path $player 'save_1.json'),'untouched-save')
[IO.File]::WriteAllText((Join-Path $player 'settings.cfg'),'untouched-settings')
$denied=Join-Path $out 'denied-temp'
New-Item -ItemType Directory -Path $denied | Out-Null
$originalAcl=Get-Acl -LiteralPath $denied
try {
    $acl=Get-Acl -LiteralPath $denied
    $deny=[Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.WindowsIdentity]::GetCurrent().User,[Security.AccessControl.FileSystemRights]::Write,[Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit',[Security.AccessControl.PropagationFlags]::None,[Security.AccessControl.AccessControlType]::Deny)
    $acl.AddAccessRule($deny); Set-Acl -LiteralPath $denied -AclObject $acl
    $blocked=$false
    try {[IO.File]::WriteAllText((Join-Path $denied 'probe'),'no')} catch [UnauthorizedAccessException] {$blocked=$true} catch [System.Management.Automation.MethodInvocationException] {if($_.Exception.InnerException -is [UnauthorizedAccessException]) {$blocked=$true} else {throw}}
    Check $blocked 'test parent TEMP genuinely rejects writes with access denied'
    Install 'denied-parent-temp' $denied
    $uninstaller=Join-Path $sandbox 'AnomalyBureau.Uninstall.exe'
    Check ((Run $uninstaller ('/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /LOG="'+(Join-Path $out 'uninstall.log')+'"') $denied) -eq 0) 'uninstall host detaches successfully with denied parent TEMP'
    $deadline=[DateTime]::UtcNow.AddSeconds(120)
    while((Test-Path -LiteralPath (Join-Path $sandbox 'unins000.exe')) -and [DateTime]::UtcNow -lt $deadline) {Start-Sleep -Milliseconds 500}
    Check (-not (Test-Path -LiteralPath (Join-Path $sandbox 'AnomalyBureau.exe'))) 'uninstall removes game executable'
    Check (-not (Test-Path -LiteralPath $uninstaller)) 'uninstall removes installed temp host without a file lock'
    Check (-not (Test-Path -LiteralPath (Join-Path $out 'desktop/诡异事务局.lnk'))) 'uninstall removes isolated desktop shortcut'
    Check ([IO.File]::ReadAllText((Join-Path $player 'save_1.json')) -eq 'untouched-save') 'uninstall preserves save bytes'
    Check ([IO.File]::ReadAllText((Join-Path $player 'settings.cfg')) -eq 'untouched-settings') 'uninstall preserves settings bytes'
    Install 'reinstall-denied-parent' $denied
    Check ([IO.File]::ReadAllText((Join-Path $player 'save_1.json')) -eq 'untouched-save') 'reinstall preserves save bytes'
    Check ([IO.File]::ReadAllText((Join-Path $player 'settings.cfg')) -eq 'untouched-settings') 'reinstall preserves settings bytes'
} finally {Set-Acl -LiteralPath $denied -AclObject $originalAcl}
Check ([Environment]::GetEnvironmentVariable('TEMP','User') -eq $originalUserTemp -and [Environment]::GetEnvironmentVariable('TMP','User') -eq $originalUserTmp) 'user TEMP and TMP are unchanged'
[ordered]@{passed=$passed;failed=0;godot_started=$false;results=@($results)} | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $out 'result.json') -Encoding utf8
