param(
    [Parameter(Mandatory=$true)][string]$GodotBinary,
    [string]$OutputDirectory,
    [switch]$SkipExport
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$versionMatch = [regex]::Match([IO.File]::ReadAllText((Join-Path $projectRoot 'project.godot')), 'config/version="(\d+\.\d+\.\d+)"')
if (-not $versionMatch.Success) { throw 'Set application/config/version to a stable X.Y.Z first.' }
$version = $versionMatch.Groups[1].Value
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $projectRoot "build\release-$version" }
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
$runtime = Join-Path $outputRoot 'Windows'
New-Item -ItemType Directory -Force -Path $runtime | Out-Null
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw 'Windows .NET Framework 4.x C# compiler was not found.' }
& $compiler /nologo /target:winexe /optimize+ /platform:x64 "/out:$runtime\AnomalyBureau.exe" /r:System.Web.Extensions.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll /r:System.Windows.Forms.dll (Join-Path $PSScriptRoot 'updater\Launcher.cs')
if ($LASTEXITCODE -ne 0) { throw 'Launcher compilation failed.' }
if (-not $SkipExport) {
    & $GodotBinary --headless --audio-driver Dummy --log-file (Join-Path $outputRoot 'export.log') --path $projectRoot --export-release 'Windows Desktop' (Join-Path $runtime 'AnomalyBureau.Game.exe')
    if ($LASTEXITCODE -ne 0) { throw 'Godot Windows export failed.' }
    [IO.File]::WriteAllText((Join-Path $outputRoot 'export-version.txt'), $version)
} elseif (-not (Test-Path -LiteralPath (Join-Path $outputRoot 'export-version.txt')) -or [IO.File]::ReadAllText((Join-Path $outputRoot 'export-version.txt')).Trim() -ne $version) {
    throw 'SkipExport requires an existing export of exactly this version from build_update.ps1.'
}
$payload = @('AnomalyBureau.Game.exe', 'AnomalyBureau.Game.pck')
$records = @($payload | ForEach-Object {
    $path = Join-Path $runtime $_
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing runtime file: $path" }
    @{path=$_; size=(Get-Item -LiteralPath $path).Length; sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()}
})
$manifestPath = Join-Path $outputRoot 'manifest.json'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($manifestPath, (@{protocol=1; version=$version; files=$records} | ConvertTo-Json -Depth 5), $utf8)
Add-Type -AssemblyName System.IO.Compression.FileSystem
$updatePath = Join-Path $outputRoot 'AnomalyBureau-update-win64.zip'
if (Test-Path -LiteralPath $updatePath) { Remove-Item -LiteralPath $updatePath }
$archive = [IO.Compression.ZipFile]::Open($updatePath, [IO.Compression.ZipArchiveMode]::Create)
try {
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $manifestPath, 'manifest.json', [IO.Compression.CompressionLevel]::Optimal) | Out-Null
    foreach ($name in $payload) {
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Join-Path $runtime $name), $name, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally { $archive.Dispose() }
foreach ($name in @('开始游玩说明.txt','兼容模式启动.bat','Godot-LICENSE.txt','Godot-COPYRIGHT.txt','NotoSansSC-LICENSE.txt')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $runtime -Force
}
foreach ($name in @('credits.txt','CC-BY-4.0.txt','CC0-1.0.txt')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot ('assets\audio\finish\'+$name)) -Destination $runtime -Force
}
[IO.File]::WriteAllText((Join-Path $runtime '自动更新说明.txt'), "双击 AnomalyBureau.exe 启动。其余 EXE/PCK 必须一起保留。`r`n游戏会自动检查 GitHub Releases，主菜单可查看更新日志。`r`n存档和设置位于 _玩家数据；_更新缓存 用于下载、备份和故障恢复。`r`n更新中请勿移动文件夹。若更新中断，重新启动 AnomalyBureau.exe 自动恢复。`r`n兼容模式启动.bat 可用于不支持 Vulkan 的显卡。`r`n", $utf8)
$portable = Join-Path $outputRoot "AnomalyBureau-Windows-$version.zip"
if (Test-Path -LiteralPath $portable) { Remove-Item -LiteralPath $portable }
$zip = [IO.Compression.ZipFile]::Open($portable, [IO.Compression.ZipArchiveMode]::Create)
try {
    # Explicit allowlist: never ship player data/cache from a previously played folder.
    foreach ($name in @('AnomalyBureau.exe') + $payload + @('开始游玩说明.txt','兼容模式启动.bat','Godot-LICENSE.txt','Godot-COPYRIGHT.txt','NotoSansSC-LICENSE.txt','credits.txt','CC-BY-4.0.txt','CC0-1.0.txt','自动更新说明.txt')) {
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $runtime $name), $name, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally { $zip.Dispose() }
@($updatePath, $portable) | ForEach-Object { '{0}  {1}' -f (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant(), [IO.Path]::GetFileName($_) } | Set-Content -LiteralPath (Join-Path $outputRoot 'SHA256SUMS.txt') -Encoding utf8
Write-Host "Release $version ready: $outputRoot"
