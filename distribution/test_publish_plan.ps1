param([Parameter(Mandatory=$true)][string]$ReleaseDirectory,[Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
if($OutputDirectory -notmatch '^[Ff]:\\') {throw 'F: output required'}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$testState=[pscustomobject]@{fixture=(Get-Content -LiteralPath (Join-Path $ReleaseDirectory 'AnomalyBureau-manifest-v3.json') -Raw | ConvertFrom-Json);requests=0;writes=0;mode='valid';passed=0}
$sourceCommit=git rev-parse HEAD
function Invoke-RestMethod {
    param($Uri,$Headers,$TimeoutSec,$Method='Get',$ContentType,$Body)
    $testState.requests++
    if($Method -ne 'Get') {$testState.writes++; throw 'Unexpected API mutation'}
    if($Uri -like '*/commits/*') {return [pscustomobject]@{sha=$sourceCommit}}
    if($Uri -match '/releases/tags/v([0-9.]+)$') {
        $version=$Matches[1]
        $items=@($testState.fixture.containers | Where-Object version -eq $version | ForEach-Object {[pscustomobject]@{name=$_.name;size=$_.size;state='uploaded';digest=('sha256:'+$(if($testState.mode -eq 'changed'){'0'*64}else{$_.sha256}))}})
        if($testState.mode -eq 'missing') {$items=@()}
        $response=[pscustomobject]@{draft=($testState.mode -eq 'draft');prerelease=$false;assets=$items}
        [IO.File]::AppendAllText((Join-Path $OutputDirectory 'mock-reads.jsonl'),($response | ConvertTo-Json -Depth 5 -Compress)+[Environment]::NewLine)
        return $response
    }
    throw ('Unexpected API read: '+$Uri)
}
function Check([bool]$value,[string]$label) {if(-not $value){throw $label};$testState.passed++;'PASS '+$label}
$publisher=Join-Path $PSScriptRoot 'publish_release.ps1'
$parameters=@{ReleaseDirectory=$ReleaseDirectory;NotesFile=(Join-Path $PSScriptRoot 'RELEASE-0.7.0.md');TargetCommit=$sourceCommit}
$testState.requests=0
$dry=(& $publisher @parameters -DryRun | Out-String | ConvertFrom-Json)
Check ($dry.assets.Count -eq 3 -and $dry.upload_bytes -lt 2MB) 'daily publication contains three small assets'
Check ($testState.requests -eq 0) 'dry run uses no network or credentials'
& $publisher @parameters -CheckOnly | Out-Null
Check ($testState.requests -gt 1 -and $testState.writes -eq 0) 'all historical resource assets checked before mutation'
foreach($mode in @('missing','changed','draft')) {
    $testState.mode=$mode; $rejected=$false
    try {& $publisher @parameters -CheckOnly | Out-Null} catch {$rejected=$true}
    Check $rejected ('reject historical asset mode '+$mode)
}
$copy=Join-Path $OutputDirectory 'damaged-plan'
New-Item -ItemType Directory -Path $copy -Force | Out-Null
$plan=Get-Content -LiteralPath (Join-Path $ReleaseDirectory 'publish-plan.json') -Raw | ConvertFrom-Json
Copy-Item -LiteralPath (Join-Path $ReleaseDirectory 'publish-plan.json') -Destination $copy
foreach($entry in $plan.assets) {Copy-Item -LiteralPath (Join-Path $ReleaseDirectory $entry.name) -Destination $copy}
[IO.File]::AppendAllText((Join-Path $copy 'AnomalyBureau-manifest-v3.json'),' ')
$parameters.ReleaseDirectory=$copy; $rejected=$false
try {& $publisher @parameters -DryRun | Out-Null} catch {$rejected=$true}
Check $rejected 'reject changed local payload before network upload'
Check ($testState.writes -eq 0) 'all publisher tests made zero API writes'
[ordered]@{passed=$testState.passed;failed=0;api_writes=$testState.writes} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutputDirectory 'result.json')
