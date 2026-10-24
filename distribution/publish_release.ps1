param(
    [Parameter(Mandatory=$true)][string]$ReleaseDirectory,
    [Parameter(Mandatory=$true)][string]$NotesFile,
    [Parameter(Mandatory=$true)][string]$TargetCommit,
    [switch]$Publish,
    [switch]$DryRun,
    [switch]$CheckOnly
)
$ErrorActionPreference='Stop'
$releaseRoot=[IO.Path]::GetFullPath($ReleaseDirectory)
$planPath=Join-Path $releaseRoot 'publish-plan.json'
$plan=$null
if(Test-Path -LiteralPath $planPath) {
    $plan=Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json
    $version=[string]$plan.version
    if($plan.mode -notin @('incremental','base','complete') -or @($plan.assets).Count -lt 2 -or @($plan.assets).Count -gt $(if($plan.mode -eq 'incremental'){3}else{12})) {throw 'Invalid publication plan'}
    $assets=@()
    foreach($entry in $plan.assets) {
        $allowed=$entry.name -match '^(AnomalyBureau-manifest-v3\.json|AnomalyBureau-patch-[a-f0-9]{64}\.bin|SHA256SUMS\.txt)$'
        if($plan.mode -ne 'incremental' -and ($entry.name -match '^AnomalyBureau-resources-(base|code_ui|maps|case1|case2|characters_audio)\.bin$' -or $entry.name -eq "AnomalyBureau-Setup-$version.exe")) {$allowed=$true}
        if(-not $allowed) {throw 'Unsafe publication asset name'}
        $file=Join-Path $releaseRoot $entry.name
        if(-not(Test-Path -LiteralPath $file) -or (Get-Item -LiteralPath $file).Length -ne $entry.size -or (Get-FileHash -LiteralPath $file).Hash.ToLowerInvariant() -ne $entry.sha256) {throw ('Incremental asset changed: '+$entry.name)}
        $assets+=$file
    }
    $manifest=Get-Content -LiteralPath (Join-Path $releaseRoot 'AnomalyBureau-manifest-v3.json') -Raw | ConvertFrom-Json
    if($manifest.version -ne $version -or $manifest.protocol -ne 2 -or $manifest.transport -ne 3) {throw 'Incremental manifest mismatch'}
    if('AnomalyBureau-manifest-v3.json' -notin $plan.assets.name -or 'SHA256SUMS.txt' -notin $plan.assets.name) {throw 'Publication plan is incomplete'}
    $plan.dependencies=@($manifest.containers | Where-Object version -ne $version)
    if(@($plan.assets.name | Select-Object -Unique).Count -ne @($plan.assets).Count) {throw 'Duplicate publication asset'}
    foreach($container in @($manifest.containers | Where-Object version -eq $version)) {
        $entry=@($plan.assets | Where-Object name -eq $container.name)
        if($entry.Count -ne 1 -or $entry[0].size -ne $container.size -or $entry[0].sha256 -ne $container.sha256) {throw 'Current resource container missing from publication plan'}
    }
} else {
$manifest=Get-Content -LiteralPath (Join-Path $releaseRoot 'manifest.json') -Raw | ConvertFrom-Json
$version=[string]$manifest.version
if ($version -notmatch '^\d+\.\d+\.\d+$' -or $TargetCommit -notmatch '^[0-9a-fA-F]{40}$') {throw 'Require manifest version X.Y.Z and an explicit full source commit SHA.'}
$assets=@((Join-Path $releaseRoot 'AnomalyBureau-update-win64.zip'),(Join-Path $releaseRoot "AnomalyBureau-Windows-$version.zip"),(Join-Path $releaseRoot 'SHA256SUMS.txt'))
$groupManifest=Join-Path $releaseRoot 'AnomalyBureau-manifest-v2.json'
if(Test-Path -LiteralPath $groupManifest) {
    $grouped=Get-Content -LiteralPath $groupManifest -Raw | ConvertFrom-Json
    if($grouped.protocol -ne 2 -or $grouped.version -ne $version) {throw 'Grouped manifest version/protocol mismatch'}
    $assets+=$groupManifest
    $bundles=@($grouped.files | Select-Object -ExpandProperty bundle -Unique)
    foreach($bundle in $bundles) {
        if($bundle -notmatch '^AnomalyBureau-resources-(base|code_ui|maps|case1|case2|characters_audio)\.bin$') {throw 'Invalid resource bundle'}
        $assets+=(Join-Path $releaseRoot $bundle)
    }
}
$setup=Join-Path $releaseRoot "AnomalyBureau-Setup-$version.exe"
if (Test-Path -LiteralPath $setup) {$assets+=$setup}
}
if ($version -notmatch '^\d+\.\d+\.\d+$' -or $TargetCommit -notmatch '^[0-9a-fA-F]{40}$') {throw 'Require version X.Y.Z and explicit source SHA'}
foreach ($asset in $assets) { if (-not (Test-Path -LiteralPath $asset)) {throw "Missing release asset: $asset"} }
foreach($asset in $assets) {if((Get-Item -LiteralPath $asset).Length -ge 2GB) {throw 'GitHub release assets must be under 2 GiB; split the resource group first'}}
if($DryRun) {
    [ordered]@{version=$version;assets=@($assets | ForEach-Object {[ordered]@{name=[IO.Path]::GetFileName($_);bytes=(Get-Item -LiteralPath $_).Length}});upload_bytes=($assets | ForEach-Object {(Get-Item -LiteralPath $_).Length} | Measure-Object -Sum).Sum;dependencies=if($plan){$plan.dependencies}else{@()};network_access=$false;published=$false} | ConvertTo-Json -Depth 6
    return
}
# Credentials remain in the existing Git credential manager and process memory.
# They are never saved into release files, arguments, logs or the game.
$env:GIT_TERMINAL_PROMPT='0'
$env:GCM_INTERACTIVE='never'
if(-not $CheckOnly) {
$credentialLines="protocol=https`nhost=github.com`n`n" | git credential fill
if ($LASTEXITCODE -ne 0) {throw 'Authenticate Git for github.com on this developer machine first.'}
$passwordLine=$credentialLines | Where-Object {$_.StartsWith('password=')} | Select-Object -First 1
if (-not $passwordLine) {throw 'No authenticated GitHub credential is available.'}
$headers=@{Authorization=('Bearer '+$passwordLine.Substring(9));Accept='application/vnd.github+json';'User-Agent'='AnomalyBureau-Release';'X-GitHub-Api-Version'='2022-11-28'}
} else {$headers=@{Accept='application/vnd.github+json';'User-Agent'='AnomalyBureau-Release';'X-GitHub-Api-Version'='2022-11-28'}}
$api='https://api.github.com/repos/sabrina1647412733-collab/anomaly-bureau-game'
$remoteCommit=Invoke-RestMethod -Uri ($api+'/commits/'+$TargetCommit) -Headers $headers -TimeoutSec 90
if ($remoteCommit.sha -ne $TargetCommit) {throw 'Push and verify the source commit before publishing.'}
if($plan) {
    # A small patch must not be published with dangling historical references.
    foreach($dependencyGroup in ($plan.dependencies | Group-Object version)) {
        if($dependencyGroup.Name -notmatch '^\d+\.\d+\.\d+$') {throw 'Invalid historical version'}
        $historical=Invoke-RestMethod -Uri ($api+'/releases/tags/v'+$dependencyGroup.Name) -Headers $headers -TimeoutSec 90
        if($historical.draft -or $historical.prerelease) {throw 'Historical resource release must be public and stable'}
        foreach($dependency in $dependencyGroup.Group) {
            $found=@($historical.assets) | Where-Object name -eq $dependency.name | Select-Object -First 1
            if(-not $found -or $found.state -ne 'uploaded' -or $found.size -ne $dependency.size -or $found.digest -ne ('sha256:'+$dependency.sha256)) {throw ('Historical asset missing or changed: v'+$dependency.version+'/'+$dependency.name+'. Upload the base assets first; no draft was created.')}
        }
    }
}
if($CheckOnly) {Write-Output 'Source and historical asset dependencies verified; no Release created or changed.'; return}
$notes=[IO.File]::ReadAllText([IO.Path]::GetFullPath($NotesFile))
$metadata=@{tag_name="v$version";target_commitish=$TargetCommit;name="诡异事务局 v$version";body=$notes;draft=$true;prerelease=$false}
$releases=Invoke-RestMethod -Uri ($api+'/releases?per_page=100') -Headers $headers -TimeoutSec 90
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
        $remoteAssets=Invoke-RestMethod -Uri ($api+'/releases/'+$release.id+'/assets?per_page=100') -Headers $headers -TimeoutSec 90
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
