param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
$out=[IO.Path]::GetFullPath($OutputDirectory)
if($out -notmatch '^[Ff]:\\') {throw 'Tests must be on F:'}
New-Item -ItemType Directory -Force -Path $out | Out-Null
$compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
& $compiler /nologo /target:exe /platform:x64 "/out:$out\HealthGame.exe" (Join-Path $PSScriptRoot 'updater/HealthGame.cs')
if($LASTEXITCODE -ne 0) {throw 'Fixture compilation failed'}
& $compiler /nologo /target:exe /platform:x64 /main:GroupedTests "/out:$out\GroupedTests.exe" /r:System.Web.Extensions.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll /r:System.Windows.Forms.dll (Join-Path $PSScriptRoot 'updater/Launcher.cs') (Join-Path $PSScriptRoot 'updater/Grouped.cs') (Join-Path $PSScriptRoot 'updater/Migration.cs') (Join-Path $PSScriptRoot 'updater/GroupedTests.cs')
if($LASTEXITCODE -ne 0) {throw 'Test compilation failed'}
& (Join-Path $out 'GroupedTests.exe') (Join-Path $out 'sandbox-中文 空格') (Join-Path $out 'HealthGame.exe')
if($LASTEXITCODE -ne 0) {throw 'Grouped update regression failed'}
