param(
    [Parameter(Mandatory=$true)][string]$Installer,
    [Parameter(Mandatory=$true)][string]$RuntimeDirectory,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)
$ErrorActionPreference='Stop'
$appId='{8E86F0AA-FE1C-4DDD-AD31-6239674835D9}_is1'
foreach ($hive in @('HKCU:/Software/Microsoft/Windows/CurrentVersion/Uninstall','HKLM:/Software/Microsoft/Windows/CurrentVersion/Uninstall','HKLM:/Software/WOW6432Node/Microsoft/Windows/CurrentVersion/Uninstall')) {
    if (Test-Path -LiteralPath (Join-Path $hive $appId)) {throw 'An existing registered installation was found. Test on a clean Windows account/VM to avoid changing its registration.'}
}
$outputRoot=[IO.Path]::GetFullPath($OutputDirectory)
$sandbox=[IO.Path]::GetFullPath((Join-Path $outputRoot 'sandbox-install'))
if (-not $sandbox.StartsWith($outputRoot.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) {throw 'Unsafe installation test path'}
if (Test-Path -LiteralPath (Join-Path $sandbox 'AnomalyBureau.exe')) {throw 'Use a fresh test output directory'}
New-Item -ItemType Directory -Force -Path (Join-Path $sandbox '_玩家数据') | Out-Null
$save=Join-Path $sandbox '_玩家数据/save_1.json'
$settings=Join-Path $sandbox '_玩家数据/settings.cfg'
[IO.File]::WriteAllText($save,'{}')
[IO.File]::WriteAllText($settings,"[audio]`nmusic=0.25`n")
$saveHash=(Get-FileHash -LiteralPath $save).Hash
$settingsHash=(Get-FileHash -LiteralPath $settings).Hash
$installLog=Join-Path $outputRoot 'install.log'
$process=Start-Process -FilePath $Installer -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-',('/DIR="'+$sandbox+'"'),'/GROUP=诡异事务局_自动更新隔离验收','/MERGETASKS=!desktopicon',('/LOG="'+$installLog+'"')) -WindowStyle Hidden -PassThru
$process.WaitForExit()
foreach ($name in @('AnomalyBureau.exe','AnomalyBureau.Game.exe','AnomalyBureau.Game.pck')) {
    if ((Get-FileHash -LiteralPath (Join-Path $sandbox $name)).Hash -ne (Get-FileHash -LiteralPath (Join-Path $RuntimeDirectory $name)).Hash) {throw 'Installed file hash mismatch'}
}
'PASS installer deploys all three runtime files with correct hashes'
if ((Get-FileHash -LiteralPath $save).Hash -ne $saveHash -or (Get-FileHash -LiteralPath $settings).Hash -ne $settingsHash) {throw 'Installer changed player data'}
'PASS installation preserves preexisting player data'
$gameLog=Join-Path $outputRoot 'installed-game.log'
$launcher=Start-Process -FilePath (Join-Path $sandbox 'AnomalyBureau.exe') -ArgumentList @('--headless','--audio-driver','Dummy','--quit-after','45','--log-file',('"'+$gameLog+'"'),'--','--verify') -WindowStyle Hidden -PassThru
$launcher.WaitForExit()
$deadline=[DateTime]::UtcNow.AddSeconds(45)
do {
    Start-Sleep -Milliseconds 500
    $running=@(Get-CimInstance Win32_Process | Where-Object {$_.ExecutablePath -eq (Join-Path $sandbox 'AnomalyBureau.Game.exe')})
} while ($running.Count -gt 0 -and [DateTime]::UtcNow -lt $deadline)
if ($running.Count -gt 0 -or -not (Select-String -LiteralPath $gameLog -Pattern '就绪 · 三角' -Quiet)) {throw 'Installed game did not enter main menu and exit normally'}
'PASS installed stable launcher starts the full game main menu'
$uninstallLog=Join-Path $outputRoot 'uninstall.log'
$uninstall=Start-Process -FilePath (Join-Path $sandbox 'unins000.exe') -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',('/LOG="'+$uninstallLog+'"')) -WindowStyle Hidden -PassThru
$uninstall.WaitForExit()
if ((Get-FileHash -LiteralPath $save).Hash -ne $saveHash -or (Get-FileHash -LiteralPath $settings).Hash -ne $settingsHash -or (Test-Path -LiteralPath (Join-Path $sandbox 'AnomalyBureau.exe'))) {throw 'Uninstall did not remove runtime while preserving data'}
'PASS uninstallation removes program and preserves save/settings bytes'
'RESULT installer 4 passed, 0 failed'
