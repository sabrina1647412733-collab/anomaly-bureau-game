param(
    [Parameter(Mandatory=$true)][string]$GodotBinary,
    [Parameter(Mandatory=$true)][string]$InnoCompiler
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$windowsDir = Join-Path $projectRoot 'build\windows'
$releaseDir = Join-Path $projectRoot 'build\release'
New-Item -ItemType Directory -Force -Path $windowsDir,$releaseDir | Out-Null
& $GodotBinary --headless --path $projectRoot --export-release 'Windows Desktop' (Join-Path $windowsDir 'AnomalyBureau.exe')
if ($LASTEXITCODE -ne 0) { throw 'Godot Windows export failed.' }
foreach ($name in @('开始游玩说明.txt','兼容模式启动.bat','Godot-LICENSE.txt','Godot-COPYRIGHT.txt','NotoSansSC-LICENSE.txt')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $windowsDir -Force
}
foreach ($name in @('credits.txt','CC-BY-4.0.txt','CC0-1.0.txt')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot ('assets\audio\finish\'+$name)) -Destination $windowsDir -Force
}
& $InnoCompiler (Join-Path $PSScriptRoot 'windows_installer.iss')
if ($LASTEXITCODE -ne 0) { throw 'Inno Setup compilation failed.' }
$portable = Join-Path $releaseDir 'AnomalyBureau-Windows-0.3.2.zip'
Compress-Archive -LiteralPath (Get-ChildItem -LiteralPath $windowsDir -File).FullName -DestinationPath $portable -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '开始游玩说明.txt') -Destination $releaseDir -Force
$hashLines = Get-ChildItem -LiteralPath $releaseDir -File | Where-Object { $_.Name -match '0\.3\.2\.(exe|zip)$' } | ForEach-Object {
    $digest = Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256
    '{0}  {1}' -f $digest.Hash.ToLowerInvariant(), $_.Name
}
$hashLines | Set-Content -LiteralPath (Join-Path $releaseDir 'SHA256SUMS.txt') -Encoding utf8
Write-Host "Ready: $releaseDir"
