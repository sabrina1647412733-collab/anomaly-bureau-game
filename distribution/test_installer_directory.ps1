param(
    [Parameter(Mandatory=$true)][string]$InnoCompiler,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [Parameter(Mandatory=$true)][string]$HiddenDesktop,
    [string]$BlockedDirectory
)
# Compile the exact production Pascal code with a tiny payload. This covers
# runtime/API errors before spending time recompressing the complete game.
$ErrorActionPreference='Stop'
$out=[IO.Path]::GetFullPath($OutputDirectory)
if ($out -notmatch '^[Ff]:\\' -or (Test-Path -LiteralPath $out)) {throw 'Use a fresh F: directory'}
New-Item -ItemType Directory -Path $out | Out-Null
$env:TEMP=$out; $env:TMP=$out
$source=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'windows_installer.iss') -Raw -Encoding UTF8
$code=$source.Substring($source.IndexOf('[Code]'))
$header=@"
[Setup]
AppName=AnomalyBureau Directory Test
AppVersion=0.0.0
DefaultDirName={code:DefaultInstallDir}
PrivilegesRequired=lowest
DisableDirPage=no
DisableProgramGroupPage=yes
CreateUninstallRegKey=no
OutputDir=$out
OutputBaseFilename=directory-test
Compression=none
CloseApplications=no
RestartApplications=no
[Tasks]
Name: desktopicon; Description: test
[Files]
Source: "$out\payload.txt"; DestDir: "{app}"
"@
[IO.File]::WriteAllText((Join-Path $out 'payload.txt'),'directory-test')
[IO.File]::WriteAllText((Join-Path $out 'test.iss'),$header+"`r`n"+$code,[Text.UTF8Encoding]::new($true))
& $InnoCompiler (Join-Path $out 'test.iss')
if ($LASTEXITCODE -ne 0) {throw 'Directory-test compile failed'}
$exe=Join-Path $out 'directory-test.exe'
function Run([string]$label,[string]$dir) {
    $args=@((Join-Path $out ($label+'-status.txt')),$exe,'/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-','/TASKS=',('/ABINSTALLSOURCE='+$out),('/LOG='+(Join-Path $out ($label+'.log'))))
    if ($dir) {$args+=('/DIR='+$dir)}
    & $HiddenDesktop @args
    return $LASTEXITCODE
}
$target=Join-Path $out 'selected 中文 空格'
if ((Run 'selected' $target) -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $target 'payload.txt'))) {throw 'Selected-directory install failed'}
if ((Run 'default' '') -ne 0) {throw 'Default-directory install failed'}
$defaultLog=Get-Content -LiteralPath (Join-Path $out 'default.log') -Raw
if ($defaultLog -match 'Creating directory: C:\\' -or $defaultLog -notmatch 'Installation process succeeded') {throw 'Default install did not succeed entirely on non-C drive'}
if ($BlockedDirectory) {
    if ((Run 'blocked' $BlockedDirectory) -ne 7) {throw 'Unwritable target was not rejected before installation'}
    $log=Get-Content -LiteralPath (Join-Path $out 'blocked.log') -Raw
    if ($log -notmatch 'Install directory preflight failed' -or $log -match 'Creating new uninstall log') {throw 'Blocked path reached destructive install stage'}
}
[ordered]@{passed=if($BlockedDirectory){3}else{2};failed=0;acl_changed=$false;godot_started=$false;hidden_desktop=$true} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'result.json') -Encoding utf8
