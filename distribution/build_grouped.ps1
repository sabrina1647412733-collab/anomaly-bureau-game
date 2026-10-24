param(
    [Parameter(Mandatory=$true)][string]$GodotBinary,
    [Parameter(Mandatory=$true)][string]$PythonBinary,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [string]$Version='0.7.0',
    [string]$ExportZip,
    [string]$BaselineRuntime,
    [switch]$SkipArchives
)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$out=[IO.Path]::GetFullPath($OutputDirectory)
if ($out -notmatch '^[Ff]:\\') {throw 'Builds, logs and caches must be on F:.'}
New-Item -ItemType Directory -Force -Path $out,(Join-Path $out 'temp'),(Join-Path $out 'Windows') | Out-Null
$env:TEMP=Join-Path $out 'temp'; $env:TMP=$env:TEMP
$runtime=Join-Path $out 'Windows'
if (-not $ExportZip) {
    $ExportZip=Join-Path $out 'export.zip'
    & $GodotBinary --headless --audio-driver Dummy --path $projectRoot --export-pack 'Windows Desktop' $ExportZip --log-file (Join-Path $out 'export.log') > (Join-Path $out 'export.out') 2> (Join-Path $out 'export.err')
    if($LASTEXITCODE -ne 0) {throw 'Windows resource export failed'}
}
$boot=Join-Path $out 'bootstrap-project'
New-Item -ItemType Directory -Force -Path $boot | Out-Null
$utf8=New-Object Text.UTF8Encoding($false)
$settings=[IO.File]::ReadAllText((Join-Path $projectRoot 'project.godot'))
$settings=$settings.Replace('res://scenes/main.tscn','res://bootstrap.tscn') -replace 'config/version="[^"]+"','config/version="0.0.0"'
[IO.File]::WriteAllText((Join-Path $boot 'project.godot'),$settings,$utf8)
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'bootstrap/bootstrap.gd') -Destination $boot -Force
[IO.File]::WriteAllText((Join-Path $boot 'bootstrap.tscn'),"[gd_scene load_steps=2 format=3]`n[ext_resource type=`"Script`" path=`"res://bootstrap.gd`" id=`"1`"]`n[node name=`"Bootstrap`" type=`"Node`"]`nscript=ExtResource(`"1`")`n",$utf8)
$preset="[preset.0]`nname=`"Windows Desktop`"`nplatform=`"Windows Desktop`"`nexport_filter=`"all_resources`"`ninclude_filter=`"`"`nexclude_filter=`"`"`nscript_export_mode=2`n[preset.0.options]`nbinary_format/architecture=`"x86_64`"`nbinary_format/embed_pck=false`ndebug/export_console_wrapper=0`napplication/modify_resources=false`n"
[IO.File]::WriteAllText((Join-Path $boot 'export_presets.cfg'),$preset,$utf8)
if($BaselineRuntime) {
    foreach($name in @('AnomalyBureau.Game.exe','AnomalyBureau.Game.pck')) {Copy-Item -LiteralPath (Join-Path $BaselineRuntime $name) -Destination $runtime -Force}
} else {
    & $GodotBinary --headless --audio-driver Dummy --path $boot --export-release 'Windows Desktop' (Join-Path $runtime 'AnomalyBureau.Game.exe') --log-file (Join-Path $out 'bootstrap-export.log') > (Join-Path $out 'bootstrap-export.out') 2> (Join-Path $out 'bootstrap-export.err')
    if($LASTEXITCODE -ne 0) {throw 'Bootstrap export failed'}
}
& $PythonBinary (Join-Path $PSScriptRoot 'make_icon.py') --source (Join-Path $projectRoot 'source_art/branding/anomaly_bureau_shortcut_reference_v1.png') --output (Join-Path $runtime 'AnomalyBureau.ico')
if($LASTEXITCODE -ne 0) {throw 'ICO conversion failed'}
$compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
& $compiler /nologo /target:winexe /optimize+ /platform:x64 "/win32icon:$runtime\AnomalyBureau.ico" "/out:$runtime\AnomalyBureau.exe" /r:System.Web.Extensions.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll /r:System.Windows.Forms.dll (Join-Path $PSScriptRoot 'updater/Launcher.cs') (Join-Path $PSScriptRoot 'updater/Grouped.cs') (Join-Path $PSScriptRoot 'updater/Migration.cs')
if($LASTEXITCODE -ne 0) {throw 'Launcher compilation failed'}
& $PythonBinary (Join-Path $PSScriptRoot 'build_groups.py') --export $ExportZip --runtime $runtime --output $out --version $Version
if($LASTEXITCODE -ne 0) {throw 'Resource grouping failed'}
foreach($name in @('开始游玩说明.txt','兼容模式启动.bat','Godot-LICENSE.txt','Godot-COPYRIGHT.txt','NotoSansSC-LICENSE.txt')) {Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $runtime -Force}
foreach($name in @('credits.txt','CC-BY-4.0.txt','CC0-1.0.txt')) {Copy-Item -LiteralPath (Join-Path $projectRoot ('assets/audio/finish/'+$name)) -Destination $runtime -Force}
[IO.File]::WriteAllText((Join-Path $runtime '自动更新说明.txt'),"从 AnomalyBureau.exe 或快捷方式启动。`r`n存档和设置仍在 _玩家数据；卸载默认保留。`r`n更新只下载变化或损坏的资源，失败后可重试，已校验文件会复用。`r`n安装目录内运行 unins000.exe 可卸载。建议安装在F盘。`r`n",$utf8)
if(-not $SkipArchives) {
    & $PythonBinary (Join-Path $PSScriptRoot 'layout_manifest.py') $runtime
    if($LASTEXITCODE -ne 0) {throw 'Layout manifest failed'}
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $portable=Join-Path $out "AnomalyBureau-Windows-$Version.zip"
    if(Test-Path -LiteralPath $portable) {throw 'Use a fresh output directory to avoid replacing a reviewed package.'}
    & $PythonBinary (Join-Path $PSScriptRoot 'package_portable.py') --runtime $runtime --output $portable
    if($LASTEXITCODE -ne 0) {throw 'Portable packaging failed'}
}
Write-Output "Grouped local build $Version ready: $out"
