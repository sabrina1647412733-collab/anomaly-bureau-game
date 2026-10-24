param([Parameter(Mandatory=$true)][string]$GodotBinary, [string]$OutputDirectory)
# All Windows entrypoints use the same tested updater-capable build pipeline.
& (Join-Path $PSScriptRoot 'build_update.ps1') -GodotBinary $GodotBinary -OutputDirectory $OutputDirectory
