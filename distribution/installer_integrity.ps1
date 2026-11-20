# Read-only build/publish gates. Never change an object's security descriptor.
if (-not ('AnomalyInstallerIntegrity' -as [type])) {
    Add-Type -Path (Join-Path $PSScriptRoot 'installer/IntegrityProbe.cs')
}
function Assert-InstallerOutputContext([string]$Directory) {
    if ([AnomalyInstallerIntegrity]::CurrentProcessIntegrity() -lt 8192) {
        throw 'Build/publish is running at Low integrity. Run from an ordinary non-elevated PowerShell session; no permissions will be changed.'
    }
    $full=[IO.Path]::GetFullPath($Directory)
    if ($full -notmatch '^[Ff]:\\') {throw 'Installer output must be on F:'}
    $parent=$full
    while (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        $previous=$parent
        $parent=[IO.Path]::GetDirectoryName($parent)
        if (-not $parent -or $parent -eq $previous) {throw 'No existing output parent directory'}
    }
    if ([AnomalyInstallerIntegrity]::FileIntegrity($parent) -lt 8192) {
        throw "Output parent inherits Low integrity and would produce a restricted installer: $parent. Choose an ordinary F: output directory; this build does not change its ACL or mandatory label."
    }
}
function Assert-InstallerArtifactIntegrity([string]$File) {
    if ([AnomalyInstallerIntegrity]::FileIntegrity($File) -lt 8192) {
        throw "Installer artifact has a Low integrity label and must not be handed to players directly: $File"
    }
}
