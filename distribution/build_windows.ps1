param(
    [Parameter(Mandatory=$true)][string]$GodotBinary,
    [Parameter(Mandatory=$true)][string]$InnoCompiler,
    [Parameter(Mandatory=$true)][string]$PythonBinary,
    [string]$OutputDirectory,
    [string]$Version='0.7.0',
    [string]$BaselineRuntime,
    [switch]$SkipExport
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'installer_integrity.ps1')
$projectRoot=Split-Path -Parent $PSScriptRoot
$version=$Version
if (-not $OutputDirectory) { $OutputDirectory=Join-Path $projectRoot "build\release-$version" }
$outputRoot=[IO.Path]::GetFullPath($OutputDirectory)
Assert-InstallerOutputContext $outputRoot
if(-not $SkipExport) {
    & (Join-Path $PSScriptRoot 'build_grouped.ps1') -GodotBinary $GodotBinary -PythonBinary $PythonBinary -OutputDirectory $outputRoot -Version $version -BaselineRuntime $BaselineRuntime
    if($LASTEXITCODE -ne 0) {throw 'Grouped build failed'}
} elseif(-not (Test-Path -LiteralPath (Join-Path $outputRoot 'Windows/_运行文件/active.json'))) {throw 'SkipExport requires an existing grouped runtime'}
& (Join-Path $PSScriptRoot 'build_installer.ps1') -RuntimeDirectory (Join-Path $outputRoot 'Windows') -OutputDirectory $outputRoot -InnoCompiler $InnoCompiler -Version $version
if(Test-Path -LiteralPath (Join-Path $outputRoot 'publish-plan.json')) {
    & $PythonBinary (Join-Path $PSScriptRoot 'delta_transport.py') --output $outputRoot
    if($LASTEXITCODE -ne 0) {throw 'Installer publication inventory failed'}
} else {
Get-ChildItem -LiteralPath $outputRoot -File | Where-Object {$_.Extension -in @('.exe','.zip')} | ForEach-Object {
    '{0}  {1}' -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(), $_.Name
} | Set-Content -LiteralPath (Join-Path $outputRoot 'SHA256SUMS.txt') -Encoding utf8
}
