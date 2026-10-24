param(
    [Parameter(Mandatory=$true)][string]$GodotBinary,
    [Parameter(Mandatory=$true)][string]$InnoCompiler,
    [string]$OutputDirectory,
    [switch]$SkipExport
)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$version=[regex]::Match([IO.File]::ReadAllText((Join-Path $projectRoot 'project.godot')), 'config/version="(\d+\.\d+\.\d+)"').Groups[1].Value
if (-not $OutputDirectory) { $OutputDirectory=Join-Path $projectRoot "build\release-$version" }
$outputRoot=[IO.Path]::GetFullPath($OutputDirectory)
& (Join-Path $PSScriptRoot 'build_update.ps1') -GodotBinary $GodotBinary -OutputDirectory $outputRoot -SkipExport:$SkipExport
& $InnoCompiler "/DAppVersion=$version" "/DRuntimeDir=$outputRoot\Windows" "/DReleaseDir=$outputRoot" (Join-Path $PSScriptRoot 'windows_installer.iss')
if ($LASTEXITCODE -ne 0) { throw 'Inno Setup compilation failed.' }
Get-ChildItem -LiteralPath $outputRoot -File | Where-Object {$_.Extension -in @('.exe','.zip')} | ForEach-Object {
    '{0}  {1}' -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(), $_.Name
} | Set-Content -LiteralPath (Join-Path $outputRoot 'SHA256SUMS.txt') -Encoding utf8
