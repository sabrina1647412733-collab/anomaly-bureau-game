param(
    [Parameter(Mandatory=$true)][string]$GodotBinary,
    [Parameter(Mandatory=$true)][string]$PythonBinary,
    [Parameter(Mandatory=$true)][string]$ReleaseDirectory
)
$ErrorActionPreference='Stop'
$out=[IO.Path]::GetFullPath($ReleaseDirectory)
if($out -notmatch '^[Ff]:\\') {throw 'Output must be on F:'}
$runtime=Join-Path $out 'Windows'
$manifest=Get-Content -LiteralPath (Join-Path $runtime '_运行文件/active.json') -Raw | ConvertFrom-Json
$version=$manifest.version
$portable=Join-Path $out "AnomalyBureau-Windows-$version.zip"
if(-not (Test-Path -LiteralPath $portable)) {throw 'Build the complete portable package first'}
$boot=Join-Path $out 'bridge-project'
$bridge=Join-Path $out 'bridge-runtime'
New-Item -ItemType Directory -Force -Path $boot,$bridge | Out-Null
$env:TEMP=Join-Path $out 'temp'; $env:TMP=$env:TEMP
$utf8=New-Object Text.UTF8Encoding($false)
Copy-Item -LiteralPath $portable -Destination (Join-Path $boot 'payload.zip') -Force
$driver=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'bootstrap/bridge.gd')).Replace('@PAYLOAD_SHA@',(Get-FileHash -LiteralPath $portable).Hash.ToLowerInvariant())
[IO.File]::WriteAllText((Join-Path $boot 'bridge.gd'),$driver,$utf8)
[IO.File]::WriteAllText((Join-Path $boot 'project.godot'),"config_version=5`n[application]`nconfig/name=`"诡异事务局`"`nconfig/version=`"$version`"`nrun/main_scene=`"res://bridge.tscn`"`n[debug]`nfile_logging/enable_file_logging=false`n",$utf8)
[IO.File]::WriteAllText((Join-Path $boot 'bridge.tscn'),"[gd_scene load_steps=2 format=3]`n[ext_resource type=`"Script`" path=`"res://bridge.gd`" id=`"1`"]`n[node name=`"Migration`" type=`"Node`"]`nscript=ExtResource(`"1`")`n",$utf8)
[IO.File]::WriteAllText((Join-Path $boot 'export_presets.cfg'),"[preset.0]`nname=`"Windows Desktop`"`nplatform=`"Windows Desktop`"`nexport_filter=`"all_resources`"`ninclude_filter=`"payload.zip`"`nexclude_filter=`"`"`nscript_export_mode=2`n[preset.0.options]`nbinary_format/architecture=`"x86_64`"`nbinary_format/embed_pck=false`ndebug/export_console_wrapper=0`napplication/modify_resources=false`n",$utf8)
& $GodotBinary --headless --audio-driver Dummy --path $boot --export-release 'Windows Desktop' (Join-Path $bridge 'AnomalyBureau.Game.exe') --log-file (Join-Path $out 'bridge-export.log') > (Join-Path $out 'bridge-export.out') 2> (Join-Path $out 'bridge-export.err')
if($LASTEXITCODE -ne 0) {throw 'Legacy bridge export failed'}
$records=@(@('AnomalyBureau.Game.exe','AnomalyBureau.Game.pck') | ForEach-Object {
    $p=Join-Path $bridge $_; @{path=$_;size=(Get-Item -LiteralPath $p).Length;sha256=(Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant()}
})
[IO.File]::WriteAllText((Join-Path $out 'manifest.json'),(@{protocol=1;version=$version;files=$records}|ConvertTo-Json -Depth 5),$utf8)
Add-Type -AssemblyName System.IO.Compression.FileSystem
$update=Join-Path $out 'AnomalyBureau-update-win64.zip'
if(Test-Path -LiteralPath $update) {throw 'Use a fresh release directory; do not replace reviewed update packages'}
$zip=[IO.Compression.ZipFile]::Open($update,[IO.Compression.ZipArchiveMode]::Create)
try {
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,(Join-Path $out 'manifest.json'),'manifest.json') | Out-Null
    foreach($f in $records) {[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,(Join-Path $bridge $f.path),$f.path) | Out-Null}
} finally {$zip.Dispose()}
Get-ChildItem -LiteralPath $out -File | Where-Object {$_.Name -match '^AnomalyBureau-.*\.(exe|zip|json|bin)$'} | ForEach-Object {'{0}  {1}' -f (Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant(),$_.Name} | Set-Content -LiteralPath (Join-Path $out 'SHA256SUMS.txt') -Encoding utf8
'Legacy protocol-1 migration package built; no Release was published.'
