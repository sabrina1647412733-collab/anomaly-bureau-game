param(
    [Parameter(Mandatory=$true)][string]$ReleaseDirectory,
    [Parameter(Mandatory=$true)][string]$NotesFile,
    [Parameter(Mandatory=$true)][string]$TargetCommit,
    [switch]$Publish
)
$ErrorActionPreference='Stop'
$releaseRoot=[IO.Path]::GetFullPath($ReleaseDirectory)
$manifest=Get-Content -LiteralPath (Join-Path $releaseRoot 'manifest.json') -Raw | ConvertFrom-Json
$version=[string]$manifest.version
if ($version -notmatch '^\d+\.\d+\.\d+$' -or $TargetCommit -notmatch '^[0-9a-fA-F]{40}$') {throw 'Require manifest version X.Y.Z and an explicit full source commit SHA.'}
$assets=@((Join-Path $releaseRoot 'AnomalyBureau-update-win64.zip'),(Join-Path $releaseRoot "AnomalyBureau-Windows-$version.zip"),(Join-Path $releaseRoot 'SHA256SUMS.txt'))
$setup=Join-Path $releaseRoot "AnomalyBureau-Setup-$version.exe"
if (Test-Path -LiteralPath $setup) {$assets+=$setup}
foreach ($asset in $assets) { if (-not (Test-Path -LiteralPath $asset)) {throw "Missing release asset: $asset"} }
# Credentials remain in the existing Git credential manager and process memory.
# They are never saved into release files, arguments, logs or the game.
$env:GIT_TERMINAL_PROMPT='0'
$env:GCM_INTERACTIVE='never'
$credentialLines="protocol=https`nhost=github.com`n`n" | git credential fill
if ($LASTEXITCODE -ne 0) {throw 'Authenticate Git for github.com on this developer machine first.'}
$passwordLine=$credentialLines | Where-Object {$_.StartsWith('password=')} | Select-Object -First 1
if (-not $passwordLine) {throw 'No authenticated GitHub credential is available.'}
$headers=@{Authorization=('Bearer '+$passwordLine.Substring(9));Accept='application/vnd.github+json';'User-Agent'='AnomalyBureau-Release';'X-GitHub-Api-Version'='2022-11-28'}
$api='https://api.github.com/repos/sabrina1647412733-collab/anomaly-bureau-game'
$remoteCommit=Invoke-RestMethod -Uri ($api+'/commits/'+$TargetCommit) -Headers $headers -TimeoutSec 90
if ($remoteCommit.sha -ne $TargetCommit) {throw 'Push and verify the source commit before publishing.'}
$notes=[IO.File]::ReadAllText([IO.Path]::GetFullPath($NotesFile))
$metadata=@{tag_name="v$version";target_commitish=$TargetCommit;name="诡异事务局 v$version";body=$notes;draft=$true;prerelease=$false}
$releases=@(Invoke-RestMethod -Uri ($api+'/releases?per_page=100') -Headers $headers -TimeoutSec 90)
$release=$releases | Where-Object {$_.tag_name -eq "v$version"} | Select-Object -First 1
if ($release -and -not $release.draft) {throw 'This version is already published. Never replace published assets; use a higher version.'}
if ($release -and $release.target_commitish -ne $TargetCommit) {throw 'Existing draft belongs to a different source commit.'}
if (-not $release) {
    $release=Invoke-RestMethod -Uri ($api+'/releases') -Headers $headers -Method Post -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes(($metadata | ConvertTo-Json))) -TimeoutSec 90
}
Write-Output ('DRAFT '+$release.html_url)
$uploadBase=($release.upload_url -split '\{')[0]
foreach ($file in $assets) {
    $name=[IO.Path]::GetFileName($file)
    $size=(Get-Item -LiteralPath $file).Length
    $digest='sha256:'+(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
    $verified=$false
    for ($attempt=1;$attempt -le 3;$attempt++) {
        $remoteAssets=@(Invoke-RestMethod -Uri ($api+'/releases/'+$release.id+'/assets?per_page=100') -Headers $headers -TimeoutSec 90)
        $asset=$remoteAssets | Where-Object {$_.name -eq $name} | Select-Object -First 1
        if ($asset -and $asset.state -eq 'uploaded' -and $asset.digest -eq $digest -and $asset.size -eq $size) {$verified=$true;break}
        if ($asset) {
            $latest=Invoke-RestMethod -Uri ($api+'/releases/'+$release.id) -Headers $headers -TimeoutSec 90
            if (-not $latest.draft) {throw 'Release was published during upload; refusing to modify it.'}
            Invoke-RestMethod -Uri ($api+'/releases/assets/'+$asset.id) -Headers $headers -Method Delete -TimeoutSec 90 | Out-Null
        }
        try {
            Write-Output ("Uploading $name bytes=$size attempt=$attempt")
            $mime=if ($name.EndsWith('.zip')) {'application/zip'} else {'application/octet-stream'}
            $asset=Invoke-RestMethod -Uri ($uploadBase+'?name='+[Uri]::EscapeDataString($name)) -Headers $headers -Method Post -ContentType $mime -InFile $file -TimeoutSec 1800
            if ($asset.digest -ne $digest -or $asset.size -ne $size -or $asset.state -ne 'uploaded') {throw 'Uploaded asset size or SHA256 does not match.'}
            $verified=$true;break
        } catch {
            Write-Output ("Upload attempt $attempt failed: "+$_.Exception.Message)
            if ($attempt -eq 3) {throw}
        }
    }
    if (-not $verified) {throw "Asset was not verified: $name"}
    Write-Output ('Verified '+$name+' '+$digest)
}
if ($Publish) {
    $metadata.draft=$false
    $metadata['make_latest']='true'
    $release=Invoke-RestMethod -Uri ($api+'/releases/'+$release.id) -Headers $headers -Method Patch -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes(($metadata | ConvertTo-Json))) -TimeoutSec 90
    if ($release.draft -or $release.tag_name -ne "v$version") {throw 'Release publication identity mismatch.'}
    Write-Output ('PUBLISHED '+$release.html_url)
} else {
    Write-Output ('READY DRAFT '+$release.html_url)
}
