param(
    [Parameter(Mandatory=$true)][string]$ReleaseDirectory,
    [Parameter(Mandatory=$true)][string]$LegacyRuntimeDirectory,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)
$ErrorActionPreference='Stop'
$out=[IO.Path]::GetFullPath($OutputDirectory)
if($out -notmatch '^[Ff]:\\' -or (Test-Path -LiteralPath $out)) {throw 'Use a fresh F: test directory'}
$root=Join-Path $out 'sandbox-旧客户端 中文 空格'
$cache=Join-Path $root '_更新缓存'
New-Item -ItemType Directory -Path $root,$cache,(Join-Path $out 'temp'),(Join-Path $root '_玩家数据') | Out-Null
$env:TEMP=Join-Path $out 'temp';$env:TMP=$env:TEMP
foreach($name in @('AnomalyBureau.exe','AnomalyBureau.Game.exe','AnomalyBureau.Game.pck')) {Copy-Item -LiteralPath (Join-Path $LegacyRuntimeDirectory $name) -Destination $root}
$oldLauncherHash=(Get-FileHash -LiteralPath (Join-Path $root 'AnomalyBureau.exe')).Hash
$oldPckHash=(Get-FileHash -LiteralPath (Join-Path $root 'AnomalyBureau.Game.pck')).Hash
[IO.File]::WriteAllText((Join-Path $root '_玩家数据/save_1.json'),'legacy-save-sentinel')
[IO.File]::WriteAllText((Join-Path $root '_玩家数据/settings.cfg'),'legacy-settings-sentinel')
Copy-Item -LiteralPath (Join-Path $root 'AnomalyBureau.exe') -Destination (Join-Path $cache 'Updater.exe')
$zip=Join-Path $ReleaseDirectory 'AnomalyBureau-update-win64.zip'
$manifest=Get-Content -LiteralPath (Join-Path $ReleaseDirectory 'manifest.json') -Raw | ConvertFrom-Json
$job=@{install_dir=$root;archive=$zip;sha256=(Get-FileHash -LiteralPath $zip).Hash.ToLowerInvariant();version=$manifest.version;token=[Guid]::NewGuid().ToString('N');parent_pid=$PID;
    game_args=@('--headless','--audio-driver','Dummy','--max-fps','60','--quit-after','3600','--log-file',(Join-Path $out 'migration-game.log'),'--','--verify','--distribution-test-exit-seconds=12',('--data-dir='+(Join-Path $out 'isolated-data')))}
$jobPath=Join-Path $cache 'job.json'
[IO.File]::WriteAllText($jobPath,($job|ConvertTo-Json -Depth 5),(New-Object Text.UTF8Encoding($false)))
$oldHelper=Start-Process -FilePath (Join-Path $cache 'Updater.exe') -ArgumentList ('--apply "'+$jobPath+'"') -WindowStyle Hidden -PassThru
$deadline=[DateTime]::UtcNow.AddSeconds(300)
$committed=$false
while([DateTime]::UtcNow -lt $deadline) {
    $path=Join-Path $cache 'migration/transaction.json'
    if(Test-Path -LiteralPath $path) {
        $journal=Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        if($journal.state -eq 'committed') {$committed=$true;break}
        if($journal.state -eq 'rolled_back') {throw 'Migration rolled back; inspect migration/result.json and game log'}
    }
    if(Test-Path -LiteralPath (Join-Path $cache 'transaction.json')) {
        $legacy=Get-Content -LiteralPath (Join-Path $cache 'transaction.json') -Raw | ConvertFrom-Json
        if($legacy.state -eq 'rolled_back') {throw 'Original v0.6.1 launcher rejected bridge health'}
    }
    Start-Sleep -Milliseconds 400
}
if(-not $committed) {throw 'Legacy migration did not commit; processes were not forcibly stopped'}
if($legacy.state -ne 'committed') {throw 'Original protocol-1 transaction did not commit'}
foreach($name in @('AnomalyBureau.exe','AnomalyBureau.Game.exe','AnomalyBureau.Game.pck','_运行文件/active.json')) {
    if((Get-FileHash -LiteralPath (Join-Path $root $name)).Hash -ne (Get-FileHash -LiteralPath (Join-Path $ReleaseDirectory ('Windows/'+$name))).Hash) {throw "Migrated file mismatch: $name"}
}
if((Get-FileHash -LiteralPath (Join-Path $cache 'migration/backup/AnomalyBureau.exe')).Hash -ne $oldLauncherHash -or (Get-FileHash -LiteralPath (Join-Path $cache 'migration/backup/AnomalyBureau.Game.pck')).Hash -ne $oldPckHash) {throw 'Migration backup did not retain the actual old playable runtime'}
if([IO.File]::ReadAllText((Join-Path $root '_玩家数据/save_1.json')) -ne 'legacy-save-sentinel' -or [IO.File]::ReadAllText((Join-Path $root '_玩家数据/settings.cfg')) -ne 'legacy-settings-sentinel') {throw 'Legacy player data changed'}
$deadline=[DateTime]::UtcNow.AddSeconds(40)
do {
    Start-Sleep -Milliseconds 500
    $running=@(Get-CimInstance Win32_Process -Filter "Name='AnomalyBureau.Game.exe'" | Where-Object {$_.ExecutablePath -eq (Join-Path $root 'AnomalyBureau.Game.exe')})
} while($running.Count -gt 0 -and [DateTime]::UtcNow -lt $deadline)
if($running.Count -gt 0) {throw 'Test child did not exit naturally'}
'PASS original v0.6.1 fixed launcher accepts the actual protocol-1 bridge package'
'PASS bridge waits for legacy commit then replaces the fixed launcher and layout'
'PASS real grouped game enters its menu and commits migration health'
'PASS migration backups contain the original playable v0.6.1 runtime'
'PASS old save/settings bytes remain unchanged'
'RESULT legacy migration 5 passed, 0 failed'
