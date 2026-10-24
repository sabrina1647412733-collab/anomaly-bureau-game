param(
    [Parameter(Mandatory=$true)][string]$Installer,
    [Parameter(Mandatory=$true)][string]$RuntimeDirectory,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [string]$LegacyRuntimeDirectory
)
$ErrorActionPreference='Stop'
$out=[IO.Path]::GetFullPath($OutputDirectory)
if($out -notmatch '^[Ff]:\\' -or (Test-Path -LiteralPath $out)) {throw 'Use a fresh F: output directory'}
New-Item -ItemType Directory -Path $out,(Join-Path $out 'temp'),(Join-Path $out 'desktop') | Out-Null
$env:TEMP=Join-Path $out 'temp'; $env:TMP=$env:TEMP
$passed=0
function Install([string]$target,[string]$label) {
    $arguments='/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /DIR="'+$target+'" /DESKTOPDIR="'+(Join-Path $out 'desktop')+'" /TASKS=desktopicon /LOG="'+(Join-Path $out ($label+'.log'))+'"'
    $p=Start-Process -FilePath $Installer -ArgumentList $arguments -WindowStyle Hidden -PassThru
    if(-not $p.WaitForExit(180000)) {throw 'Installer did not exit; no processes were killed'}
    if($p.ExitCode -ne 0) {throw "Installer exit $($p.ExitCode); see $label.log"}
    foreach($name in @('AnomalyBureau.exe','AnomalyBureau.Game.exe','AnomalyBureau.Game.pck','_运行文件/active.json')) {
        if((Get-FileHash -LiteralPath (Join-Path $target $name)).Hash -ne (Get-FileHash -LiteralPath (Join-Path $RuntimeDirectory $name)).Hash) {throw "Install hash mismatch: $name"}
    }
    'PASS '+$label+' deploys verified runtime and active resource manifest'
    $script:passed++
}
function Sentinels([string]$target) {
    $player=Join-Path $target '_玩家数据'
    New-Item -ItemType Directory -Force -Path $player | Out-Null
    [IO.File]::WriteAllText((Join-Path $player 'save_1.json'),'save-sentinel')
    [IO.File]::WriteAllText((Join-Path $player 'settings.cfg'),'settings-sentinel')
}
function Preserved([string]$target,[string]$label) {
    if([IO.File]::ReadAllText((Join-Path $target '_玩家数据/save_1.json')) -ne 'save-sentinel' -or [IO.File]::ReadAllText((Join-Path $target '_玩家数据/settings.cfg')) -ne 'settings-sentinel') {throw 'Player data changed'}
    'PASS '+$label+' preserves save/settings bytes'; $script:passed++
}
$sandbox=Join-Path $out 'sandbox-中文 空格'
Install $sandbox 'clean-install'
$shell=New-Object -ComObject WScript.Shell
$link=Join-Path $out 'desktop/诡异事务局.lnk'
if(-not (Test-Path -LiteralPath $link)) {throw 'Default desktop shortcut missing'}
$shortcut=$shell.CreateShortcut($link)
if($shortcut.TargetPath -ne (Join-Path $sandbox 'AnomalyBureau.exe') -or $shortcut.WorkingDirectory -ne $sandbox -or $shortcut.IconLocation -notmatch 'AnomalyBureau.ico') {throw 'Shortcut points at wrong launcher, folder or icon'}
'PASS default desktop shortcut uses the stable launcher and formal icon';$passed++
$gameLog=Join-Path $out 'installed-menu.log'
$launch=Start-Process -FilePath $shortcut.TargetPath -ArgumentList ('--headless --audio-driver Dummy --log-file "'+$gameLog+'" -- --verify --distribution-test-exit-seconds=12 --data-dir="'+(Join-Path $out 'menu-data')+'"') -WindowStyle Hidden -PassThru
$launch.WaitForExit()
$deadline=[DateTime]::UtcNow.AddSeconds(50)
do {
    Start-Sleep -Milliseconds 500
    $running=@(Get-CimInstance Win32_Process -Filter "Name='AnomalyBureau.Game.exe'" | Where-Object {$_.ExecutablePath -eq (Join-Path $sandbox 'AnomalyBureau.Game.exe')})
} while($running.Count -gt 0 -and [DateTime]::UtcNow -lt $deadline)
if($running.Count -gt 0 -or -not (Select-String -LiteralPath $gameLog -Pattern '就绪 · 三角' -Quiet) -or -not (Select-String -LiteralPath $gameLog -Pattern 'mounted_before_main=true' -Quiet)) {throw 'Installed main menu did not start/exit naturally'}
'PASS installed game mounts groups before real main scene and exits naturally';$passed++
Sentinels $sandbox
Install $sandbox 'repeat-install'
Preserved $sandbox 'repeat-install'
$uninstall=Start-Process -FilePath (Join-Path $sandbox 'unins000.exe') -ArgumentList ('/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /LOG="'+(Join-Path $out 'uninstall.log')+'"') -WindowStyle Hidden -PassThru
if(-not $uninstall.WaitForExit(90000) -or $uninstall.ExitCode -ne 0) {throw 'Uninstall failed'}
Preserved $sandbox 'uninstall'
if((Test-Path -LiteralPath (Join-Path $sandbox 'AnomalyBureau.exe')) -or (Test-Path -LiteralPath (Join-Path $sandbox '_运行文件')) -or (Test-Path -LiteralPath $link)) {throw 'Uninstall left program files or desktop shortcut'}
'PASS uninstall removes runtime and shortcut';$passed++
Install $sandbox 'reinstall'
Preserved $sandbox 'reinstall'
if($LegacyRuntimeDirectory) {
    $legacy=Join-Path $out 'sandbox-旧版 升级'
    New-Item -ItemType Directory -Path $legacy | Out-Null
    foreach($name in @('AnomalyBureau.exe','AnomalyBureau.Game.exe','AnomalyBureau.Game.pck')) {Copy-Item -LiteralPath (Join-Path $LegacyRuntimeDirectory $name) -Destination $legacy}
    if(Test-Path -LiteralPath (Join-Path $LegacyRuntimeDirectory '_运行文件/active.json')) {Copy-Item -LiteralPath (Join-Path $LegacyRuntimeDirectory '_运行文件') -Destination $legacy -Recurse}
    Sentinels $legacy
    Install $legacy 'old-version-upgrade'
    Preserved $legacy 'old-version-upgrade'
}
"RESULT installer $passed passed, 0 failed"
