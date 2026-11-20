param(
    [Parameter(Mandatory=$true)][string]$RuntimeDirectory,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [Parameter(Mandatory=$true)][string]$InnoCompiler,
    [string]$Version='0.7.0'
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'installer_integrity.ps1')
$runtime=[IO.Path]::GetFullPath($RuntimeDirectory)
$output=[IO.Path]::GetFullPath($OutputDirectory)
if($output -notmatch '^[Ff]:\\') {throw 'Installer build output must be on F:'}
Assert-InstallerOutputContext $output
$hostRoot=Join-Path $output 'installer-host'
$innerRoot=Join-Path $output 'installer-inner'
New-Item -ItemType Directory -Path $hostRoot,$innerRoot -Force | Out-Null
$env:TEMP=$hostRoot; $env:TMP=$hostRoot
$compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$source=Join-Path $PSScriptRoot 'installer/TempHost.cs'
$icon=Join-Path $runtime 'AnomalyBureau.ico'
$uninstall=Join-Path $hostRoot 'AnomalyBureau.Uninstall.exe'
$stub=Join-Path $hostRoot 'SetupHost.exe'
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    foreach($entry in @(@{file=$stub;define='SETUP'},@{file=$uninstall;define='UNINSTALL'})) {
        & $compiler /nologo /target:winexe /optimize+ /reference:System.Windows.Forms.dll ("/define:"+$entry.define) ("/win32icon:"+$icon) ("/out:"+$entry.file) $source
        if($LASTEXITCODE -ne 0) {throw 'Installer temp host compilation failed'}
        Assert-InstallerArtifactIntegrity $entry.file
    }
    & $InnoCompiler "/DAppVersion=$Version" "/DRuntimeDir=$runtime" "/DReleaseDir=$innerRoot" "/DTempHostDir=$hostRoot" (Join-Path $PSScriptRoot 'windows_installer.iss')
    if($LASTEXITCODE -ne 0) {throw 'Inno compilation failed'}
    $payload=Join-Path $innerRoot "AnomalyBureau-Setup-$Version.exe"
    Assert-InstallerArtifactIntegrity $payload
    $final=Join-Path $output "AnomalyBureau-Setup-$Version.exe"
    if(Test-Path -LiteralPath $final) {throw 'Refusing to replace an existing installer; choose a fresh output directory'}
    $target=[IO.File]::Open($final,[IO.FileMode]::CreateNew)
    try {
        $input=[IO.File]::OpenRead($stub)
        try {$input.CopyTo($target)} finally {$input.Dispose()}
        $input=[IO.File]::OpenRead($payload)
        try {
            $length=$input.Length
            $hasher=[Security.Cryptography.SHA256]::Create()
            try {$digest=$hasher.ComputeHash($input)} finally {$hasher.Dispose()}
            $input.Position=0; $input.CopyTo($target)
        } finally {$input.Dispose()}
        $writer=[IO.BinaryWriter]::new($target)
        $writer.Write([long]$length); $writer.Write([byte[]]$digest); $writer.Write([Text.Encoding]::ASCII.GetBytes('ABSETUPPAYLOAD1!')); $writer.Flush()
    } finally {$target.Dispose()}
    Assert-InstallerArtifactIntegrity $final
    $digest=(Get-FileHash -LiteralPath $final -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText((Join-Path $output 'SHA256SUMS-installer.txt'),$digest+'  '+[IO.Path]::GetFileName($final)+[Environment]::NewLine)
    [ordered]@{file=$final;version=$Version;sha256=$digest;file_integrity_rid=[AnomalyInstallerIntegrity]::FileIntegrity($final);process_integrity_rid=[AnomalyInstallerIntegrity]::CurrentProcessIntegrity();acl_changed=$false} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $output 'delivery-check.json') -Encoding utf8
    Get-FileHash -LiteralPath $final -Algorithm SHA256
} finally {Pop-Location}
