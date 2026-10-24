param([string]$OutputDirectory)
$ErrorActionPreference='Stop'
if (-not $OutputDirectory) { $OutputDirectory=Join-Path (Split-Path -Parent $PSScriptRoot) 'build\updater-tests' }
$outputRoot=[IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $compiler /nologo /target:exe /platform:x64 "/out:$outputRoot\HealthGame.exe" (Join-Path $PSScriptRoot 'updater\HealthGame.cs')
if ($LASTEXITCODE -ne 0) {throw 'Fixture compilation failed'}
& $compiler /nologo /target:exe /platform:x64 /main:UpdaterTests "/out:$outputRoot\UpdaterTests.exe" /r:System.Web.Extensions.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll /r:System.Windows.Forms.dll (Join-Path $PSScriptRoot 'updater\Launcher.cs') (Join-Path $PSScriptRoot 'updater\UpdaterTests.cs')
if ($LASTEXITCODE -ne 0) {throw 'Test compilation failed'}
& (Join-Path $outputRoot 'UpdaterTests.exe') (Join-Path $outputRoot 'sandbox-transaction') (Join-Path $outputRoot 'HealthGame.exe')
if ($LASTEXITCODE -ne 0) {throw 'Updater regression failed'}
