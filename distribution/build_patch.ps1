param(
    [Parameter(Mandatory=$true)][string]$GodotBinary,
    [Parameter(Mandatory=$true)][string]$PythonBinary,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [Parameter(Mandatory=$true)][string]$Version,
    [Parameter(Mandatory=$true)][string]$PreviousManifest,
    [Parameter(Mandatory=$true)][string]$BaselineRuntime,
    [string]$ExportZip
)
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'build_grouped.ps1') -GodotBinary $GodotBinary -PythonBinary $PythonBinary -OutputDirectory $OutputDirectory -Version $Version -PreviousManifest $PreviousManifest -BaselineRuntime $BaselineRuntime -ExportZip $ExportZip -SkipArchives
$plan=Get-Content -LiteralPath (Join-Path $OutputDirectory 'publish-plan.json') -Raw | ConvertFrom-Json
'Only upload the files listed below; runtime, exports and caches stay local:'
$plan.assets | Select-Object name,size
'Total upload bytes: '+$plan.upload_bytes
& (Join-Path $PSScriptRoot 'prepare_upload.ps1') -ReleaseDirectory $OutputDirectory -OutputDirectory (Join-Path $OutputDirectory '上传这些')
