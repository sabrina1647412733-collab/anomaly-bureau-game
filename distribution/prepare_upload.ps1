param([Parameter(Mandatory=$true)][string]$ReleaseDirectory,[Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
$releaseRoot=[IO.Path]::GetFullPath($ReleaseDirectory)
$output=[IO.Path]::GetFullPath($OutputDirectory)
if($output -notmatch '^[Ff]:\\' -or $releaseRoot -notmatch '^[Ff]:\\' -or (Test-Path -LiteralPath $output)) {throw 'Use a fresh F: upload folder and F: release directory'}
$preview=& (Join-Path $PSScriptRoot 'publish_release.ps1') -ReleaseDirectory $releaseRoot -NotesFile 'unused-in-dry-run' -TargetCommit ('0'*40) -DryRun | Out-String | ConvertFrom-Json
New-Item -ItemType Directory -Path $output | Out-Null
foreach($entry in $preview.assets) {
    New-Item -ItemType HardLink -Path (Join-Path $output $entry.name) -Target (Join-Path $releaseRoot $entry.name) | Out-Null
}
[ordered]@{upload_folder=$output;file_count=$preview.assets.Count;upload_bytes=$preview.upload_bytes} | ConvertTo-Json
