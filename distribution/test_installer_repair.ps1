param(
    [Parameter(Mandatory=$true)][string]$Installer,
    [Parameter(Mandatory=$true)][string]$RuntimeDirectory,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [Parameter(Mandatory=$true)][string]$InstallDirectory
)
$ErrorActionPreference = 'Stop'

# This is deliberately confined to the previously isolated baseline, not a
# player's existing installation. Never override this check for a real install.
$allowedInstall = [IO.Path]::GetFullPath('F:\诡异事务局\验收\20261030_安装目录修复\原版安装对照').TrimEnd('\')
$target = [IO.Path]::GetFullPath($InstallDirectory).TrimEnd('\')
$runtime = [IO.Path]::GetFullPath($RuntimeDirectory).TrimEnd('\')
$out = [IO.Path]::GetFullPath($OutputDirectory).TrimEnd('\')
$setup = [IO.Path]::GetFullPath($Installer)
if (-not [String]::Equals($target, $allowedInstall, [StringComparison]::OrdinalIgnoreCase)) { throw 'InstallDirectory must be the isolated baseline directory' }
if (-not (Test-Path -LiteralPath $target -PathType Container)) { throw 'The isolated baseline directory must already exist' }
if ($out -notmatch '^[Ff]:\\' -or (Test-Path -LiteralPath $out)) { throw 'OutputDirectory must be a new directory on F:' }
if ($out.StartsWith($target + '\', [StringComparison]::OrdinalIgnoreCase) -or $target.StartsWith($out + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Output and install directories must be separate' }
if (-not (Test-Path -LiteralPath $setup -PathType Leaf) -or -not (Test-Path -LiteralPath $runtime -PathType Container)) { throw 'Installer or runtime directory is missing' }
$player = Join-Path $target '_玩家数据'
if (Test-Path -LiteralPath $player) { throw 'Player data already exists: refusing to use this directory' }

New-Item -ItemType Directory -Path $out, (Join-Path $out 'temp'), (Join-Path $out 'desktop') | Out-Null
$env:TEMP = Join-Path $out 'temp'
$env:TMP = $env:TEMP
New-Item -ItemType Directory -Path $player | Out-Null
$sentinels = @{'save_1.json'='repair-test-save-sentinel'; 'settings.cfg'='repair-test-settings-sentinel'}
foreach ($name in $sentinels.Keys) { [IO.File]::WriteAllText((Join-Path $player $name), $sentinels[$name]) }
function Assert-Sentinels {
    foreach ($name in $sentinels.Keys) {
        $file = Join-Path $player $name
        if (-not (Test-Path -LiteralPath $file -PathType Leaf) -or [IO.File]::ReadAllText($file) -ne $sentinels[$name]) { throw "Test sentinel not preserved: $name" }
    }
}
function Assert-SameFile([string]$relative) {
    $expected = Join-Path $runtime $relative
    $actual = Join-Path $target $relative
    if (-not (Test-Path -LiteralPath $expected -PathType Leaf) -or -not (Test-Path -LiteralPath $actual -PathType Leaf)) { throw "Missing runtime file: $relative" }
    if ((Get-FileHash -LiteralPath $expected -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $actual -Algorithm SHA256).Hash) { throw "Hash mismatch: $relative" }
}

$installLog = Join-Path $out 'repair-install.log'
$desktop = Join-Path $out 'desktop'
$args = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /DIR="' + $target + '" /DESKTOPDIR="' + $desktop + '" /TASKS=desktopicon /LOG="' + $installLog + '"'
$process = Start-Process -FilePath $setup -ArgumentList $args -WindowStyle Hidden -PassThru
if (-not $process.WaitForExit(240000)) { throw 'Installer timed out; no process was killed' }
if ($process.ExitCode -ne 0) { throw "Installer exited $($process.ExitCode); see $installLog" }
foreach ($relative in @('AnomalyBureau.exe','AnomalyBureau.Game.exe','AnomalyBureau.Game.pck','_运行文件\active.json')) { Assert-SameFile $relative }
$packs = @(Get-ChildItem -LiteralPath (Join-Path $runtime '_运行文件\packs') -File -Filter '*.zip')
if ($packs.Count -eq 0) { throw 'No runtime packs found for hash verification' }
foreach ($pack in $packs) { Assert-SameFile ('_运行文件\packs\' + $pack.Name) }
Assert-Sentinels
$shortcutPath = Join-Path $desktop '诡异事务局.lnk'
if (-not (Test-Path -LiteralPath $shortcutPath -PathType Leaf)) { throw 'Isolated desktop shortcut missing' }
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
if ($shortcut.TargetPath -ne (Join-Path $target 'AnomalyBureau.exe') -or $shortcut.WorkingDirectory -ne $target -or $shortcut.IconLocation -notmatch 'AnomalyBureau.ico') { throw 'Shortcut target, working directory or icon mismatch' }
Write-Output "PASS repair installed verified runtime and $($packs.Count) resource packs; preserved test data and created isolated shortcut"

$uninstaller = Join-Path $target 'AnomalyBureau.Uninstall.exe'
if (-not (Test-Path -LiteralPath $uninstaller -PathType Leaf)) { throw 'Uninstall wrapper missing' }
$uninstallLog = Join-Path $out 'repair-uninstall.log'
$uninstallArgs = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /LOG="' + $uninstallLog + '"'
$process = Start-Process -FilePath $uninstaller -ArgumentList $uninstallArgs -WindowStyle Hidden -PassThru
if (-not $process.WaitForExit(120000)) { throw 'Uninstall wrapper timed out; no process was killed' }
if ($process.ExitCode -ne 0) { throw "Uninstall wrapper exited $($process.ExitCode); see $uninstallLog" }
# The wrapper detaches into the temporary directory before running Inno.
$deadline = [DateTime]::UtcNow.AddSeconds(180)
$uninstallSucceeded = $false
do {
    if ((Test-Path -LiteralPath $uninstallLog -PathType Leaf) -and (Select-String -LiteralPath $uninstallLog -Pattern 'Uninstallation process succeeded\.' -Quiet)) { $uninstallSucceeded = $true; break }
    Start-Sleep -Milliseconds 500
} while ([DateTime]::UtcNow -lt $deadline)
if (-not $uninstallSucceeded) { throw 'Detached uninstall did not report success before timeout' }
if ((Test-Path -LiteralPath (Join-Path $target 'AnomalyBureau.exe')) -or (Test-Path -LiteralPath (Join-Path $target '_运行文件')) -or (Test-Path -LiteralPath $shortcutPath)) { throw 'Uninstall left runtime or isolated shortcut behind' }
Assert-Sentinels
Write-Output 'PASS uninstall removed launcher and preserved test save/settings'
[ordered]@{passed=2; failed=0; resource_packs=$packs.Count; all_hashes_match=$true; saves_preserved=$true; settings_preserved=$true; hidden_desktop_required=$true; acl_changed=$false} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'result.json') -Encoding utf8
