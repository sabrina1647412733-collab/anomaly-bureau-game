param(
    [Parameter(Mandatory=$true)][string]$GodotBinary,
    [string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $projectRoot 'build\windows-0.5.0' }
$outputRoot = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
& $GodotBinary --headless --log-file (Join-Path $outputRoot 'export.log') --path $projectRoot --export-release 'Windows Desktop' (Join-Path $outputRoot 'AnomalyBureau.exe')
if ($LASTEXITCODE -ne 0) { throw 'Godot Windows export failed.' }
foreach ($name in @('开始游玩说明.txt','兼容模式启动.bat','Godot-LICENSE.txt','Godot-COPYRIGHT.txt','NotoSansSC-LICENSE.txt')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $outputRoot -Force
}
foreach ($name in @('credits.txt','CC-BY-4.0.txt','CC0-1.0.txt')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot ('assets\audio\finish\'+$name)) -Destination $outputRoot -Force
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets\models\view_hands\SOURCES.md') -Destination (Join-Path $outputRoot '第一人称手部来源.md') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets\audio\polish\SOURCES.md') -Destination (Join-Path $outputRoot '新增音效来源.md') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets\town\renewal\README.md') -Destination (Join-Path $outputRoot '街道更新说明.md') -Force
Get-ChildItem -LiteralPath $outputRoot -File | Where-Object { $_.Extension -in @('.exe','.pck') } | ForEach-Object {
    $digest=Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256
    '{0}  {1}' -f $digest.Hash.ToLowerInvariant(),$_.Name
} | Set-Content -LiteralPath (Join-Path $outputRoot 'SHA256SUMS.txt') -Encoding utf8
Write-Host "Portable folder ready: $outputRoot"
