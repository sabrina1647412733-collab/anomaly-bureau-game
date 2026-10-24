param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
$out=[IO.Path]::GetFullPath($OutputDirectory)
if($out -notmatch '^[Ff]:\\') {throw 'F: test output required'}
New-Item -ItemType Directory -Force -Path $out | Out-Null
$c=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
& $c /nologo /target:winexe "/out:$out\HealthGame.exe" (Join-Path $PSScriptRoot 'updater/HealthGame.cs')
if($LASTEXITCODE -ne 0){throw 'fixture compile failed'}
& $c /nologo /target:exe /platform:x64 /main:MigrationTests "/out:$out\MigrationTests.exe" /r:System.Web.Extensions.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll /r:System.Windows.Forms.dll (Join-Path $PSScriptRoot 'updater/Launcher.cs') (Join-Path $PSScriptRoot 'updater/Grouped.cs') (Join-Path $PSScriptRoot 'updater/Migration.cs') (Join-Path $PSScriptRoot 'updater/MigrationTests.cs')
if($LASTEXITCODE -ne 0){throw 'test compile failed'}
& (Join-Path $out 'MigrationTests.exe') (Join-Path $out 'sandbox-migration') (Join-Path $out 'HealthGame.exe')
if($LASTEXITCODE -ne 0){throw 'migration tests failed'}
