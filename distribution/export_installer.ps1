param(
    [Parameter(Mandatory=$true)][string]$Installer,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)
# Reconstruct the transport bytes into a fresh file; copying/moving an existing
# NTFS object is not a reliable way to remove inherited build-folder metadata.
# Security labels and ACLs are never modified; the new file inherits its parent.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'installer_integrity.ps1')
$source=[IO.Path]::GetFullPath($Installer)
$out=[IO.Path]::GetFullPath($OutputDirectory)
Assert-InstallerOutputContext $out
if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {throw 'Installer file is missing'}
if (Test-Path -LiteralPath $out) {throw 'Use a fresh output directory; existing deliveries are never overwritten'}
[IO.Directory]::CreateDirectory($out) | Out-Null
$final=Join-Path $out ([IO.Path]::GetFileName($source))
$inputStream=[IO.File]::OpenRead($source)
try {
    $outputStream=[IO.File]::Open($final,[IO.FileMode]::CreateNew)
    try {$inputStream.CopyTo($outputStream)} finally {$outputStream.Dispose()}
} finally {$inputStream.Dispose()}
$digest=(Get-FileHash -LiteralPath $final -Algorithm SHA256).Hash
if ($digest -ne (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash) {throw 'Exported bytes failed SHA256 verification'}
Assert-InstallerArtifactIntegrity $final
[IO.File]::WriteAllText((Join-Path $out 'SHA256SUMS.txt'),$digest.ToLowerInvariant()+'  '+[IO.Path]::GetFileName($final)+[Environment]::NewLine)
[ordered]@{file=$final;sha256=$digest.ToLowerInvariant();file_integrity_rid=[AnomalyInstallerIntegrity]::FileIntegrity($final);process_integrity_rid=[AnomalyInstallerIntegrity]::CurrentProcessIntegrity();acl_changed=$false;source_bytes_preserved=$true} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'delivery-check.json') -Encoding utf8
Get-Item -LiteralPath $final
