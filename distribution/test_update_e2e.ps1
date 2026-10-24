param(
    [Parameter(Mandatory=$true)][string]$ReleaseDirectory,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [Parameter(Mandatory=$true)][string]$GodotBinary,
    [Parameter(Mandatory=$true)][string]$PythonBinary
)
$ErrorActionPreference='Stop'
$releaseRoot=[IO.Path]::GetFullPath($ReleaseDirectory)
$outputRoot=[IO.Path]::GetFullPath($OutputDirectory)
$sandbox=Join-Path $outputRoot 'sandbox-e2e'
New-Item -ItemType Directory -Force -Path $sandbox | Out-Null
if (Test-Path -LiteralPath (Join-Path $sandbox '_更新缓存/transaction.json')) { throw 'Use a fresh E2E output directory.' }
Copy-Item -LiteralPath (Join-Path $releaseRoot 'Windows/AnomalyBureau.exe') -Destination $sandbox
# Release templates disable external --script overrides. Export a tiny old probe
# whose updater is copied byte-for-byte from production, then update to the game.
$probeProject=Join-Path $outputRoot 'probe-project'
New-Item -ItemType Directory -Force -Path (Join-Path $probeProject 'scripts') | Out-Null
$projectRoot=Split-Path -Parent $PSScriptRoot
foreach ($name in @('update_service.gd','storage_paths.gd')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot ('scripts/'+$name)) -Destination (Join-Path $probeProject 'scripts')
}
$driver=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'updater/UpdateProbe.gd')).Replace('extends SceneTree','extends Node').Replace('func _initialize()','func _ready()').Replace('root.add_child(','get_tree().root.add_child(').Replace('quit(', 'get_tree().quit(')
[IO.File]::WriteAllText((Join-Path $probeProject 'probe.gd'),$driver)
[IO.File]::WriteAllText((Join-Path $probeProject 'project.godot'), "config_version=5`n[application]`nconfig/name=`"Update acceptance`"`nconfig/version=`"0.5.99`"`nrun/main_scene=`"res://main.tscn`"`n[debug]`nfile_logging/enable_file_logging=false`n")
[IO.File]::WriteAllText((Join-Path $probeProject 'main.tscn'), "[gd_scene load_steps=2 format=3]`n[ext_resource type=`"Script`" path=`"res://probe.gd`" id=`"1`"]`n[node name=`"Probe`" type=`"Node`"]`nscript=ExtResource(`"1`")`n")
[IO.File]::WriteAllText((Join-Path $probeProject 'export_presets.cfg'), "[preset.0]`nname=`"Windows Desktop`"`nplatform=`"Windows Desktop`"`nexport_filter=`"all_resources`"`ninclude_filter=`"`"`nexclude_filter=`"`"`nscript_export_mode=2`n[preset.0.options]`nbinary_format/architecture=`"x86_64`"`nbinary_format/embed_pck=false`ndebug/export_console_wrapper=0`n")
& $GodotBinary --headless --audio-driver Dummy --path $probeProject --export-release 'Windows Desktop' (Join-Path $sandbox 'AnomalyBureau.Game.exe') > (Join-Path $outputRoot 'probe-export.out') 2> (Join-Path $outputRoot 'probe-export.err')
if ($LASTEXITCODE -ne 0) {throw 'Probe export failed'}
$player=Join-Path $sandbox '_玩家数据'
New-Item -ItemType Directory -Force -Path $player | Out-Null
[IO.File]::WriteAllText((Join-Path $player 'save_1.json'), '{}')
[IO.File]::WriteAllText((Join-Path $player 'settings.cfg'), "[audio]`r`nmusic=0.25`r`n")
$saveHash=(Get-FileHash -LiteralPath (Join-Path $player 'save_1.json')).Hash
$settingsHash=(Get-FileHash -LiteralPath (Join-Path $player 'settings.cfg')).Hash
$listener=New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback,0)
$listener.Start(); $port=$listener.LocalEndpoint.Port; $listener.Stop()
$server=Start-Process -FilePath $PythonBinary -ArgumentList @('-m','http.server',"$port",'--bind','127.0.0.1','--directory',('"'+$releaseRoot+'"')) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $outputRoot 'http.out') -RedirectStandardError (Join-Path $outputRoot 'http.err') -PassThru
$game=$null; $child=$null
try {
    $zip=Join-Path $releaseRoot 'AnomalyBureau-update-win64.zip'
    $manifest=Get-Content -LiteralPath (Join-Path $releaseRoot 'manifest.json') -Raw | ConvertFrom-Json
    $inputFile=Join-Path $outputRoot 'probe.json'
    @{url="http://127.0.0.1:$port/AnomalyBureau-update-win64.zip";sha256=(Get-FileHash -LiteralPath $zip).Hash.ToLowerInvariant();size=(Get-Item -LiteralPath $zip).Length;version=$manifest.version;child_log=(Join-Path $outputRoot 'child.log')} | ConvertTo-Json | Set-Content -LiteralPath $inputFile -Encoding utf8

    $game=Start-Process -FilePath (Join-Path $sandbox 'AnomalyBureau.Game.exe') -ArgumentList @('--headless','--audio-driver','Dummy','--log-file',('"'+(Join-Path $outputRoot 'probe.log')+'"'),'--',('--probe-config="'+$inputFile+'"')) -WorkingDirectory $sandbox -WindowStyle Hidden -RedirectStandardOutput (Join-Path $outputRoot 'probe.out') -RedirectStandardError (Join-Path $outputRoot 'probe.err') -PassThru
    $deadline=[DateTime]::UtcNow.AddSeconds(180)
    $journalPath=Join-Path $sandbox '_更新缓存/transaction.json'
    $committed=$false
    while ([DateTime]::UtcNow -lt $deadline) {
        if (Test-Path -LiteralPath $journalPath) {
            try {
                $journal=Get-Content -LiteralPath $journalPath -Raw | ConvertFrom-Json
                if ($journal.child_pid -gt 0) { $child=Get-Process -Id $journal.child_pid -ErrorAction SilentlyContinue }
                if ($journal.state -eq 'committed') { $committed=$true; break }
                if ($journal.state -eq 'rolled_back') { throw 'Real exported game failed its health check.' }
            } catch [System.ArgumentException] { }
        }
		$ready=@(Get-ChildItem -LiteralPath (Join-Path $sandbox '_更新缓存') -Filter 'ready-*.txt' -ErrorAction SilentlyContinue)
		if ($game.HasExited -and -not (Test-Path -LiteralPath $journalPath) -and $ready.Count -eq 0) { throw 'Probe exited before updater readiness; inspect probe.out and probe.err.' }
        Start-Sleep -Milliseconds 500
    }
    if (-not $committed) {throw 'E2E update did not commit before deadline. Inspect probe.err / child.log.'}
    if ((Get-FileHash -LiteralPath (Join-Path $player 'save_1.json')).Hash -ne $saveHash -or (Get-FileHash -LiteralPath (Join-Path $player 'settings.cfg')).Hash -ne $settingsHash) {throw 'Player data changed during E2E update'}
    foreach ($record in $manifest.files) {
        if ((Get-FileHash -LiteralPath (Join-Path $sandbox $record.path)).Hash.ToLowerInvariant() -ne $record.sha256) {throw 'Installed payload hash mismatch'}
    }
    'PASS exported game downloaded and verified the full release package'
    'PASS game exited only after independent updater readiness handshake'
    'PASS updater replaced runtime and restarted the actual exported main menu'
    'PASS new game health receipt committed the transaction'
    'PASS save and settings bytes unchanged'
    'RESULT E2E 5 passed, 0 failed'
} finally {
    # Stop only processes created by this isolated acceptance run.
    if ($child -and -not $child.HasExited -and $child.Path -eq (Join-Path $sandbox 'AnomalyBureau.Game.exe')) { Stop-Process -Id $child.Id }
    if ($game -and -not $game.HasExited) { Stop-Process -Id $game.Id }
    if (-not $server.HasExited) { Stop-Process -Id $server.Id }
}
