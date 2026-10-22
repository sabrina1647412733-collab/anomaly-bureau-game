param([string]$Only='')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Speech
$root=Join-Path $PSScriptRoot '..\..\assets\audio\performance'
$lines=Get-Content -LiteralPath (Join-Path $root 'lines.json') -Raw -Encoding utf8 | ConvertFrom-Json
foreach($entry in $lines.PSObject.Properties){
 if($Only -and $entry.Name -ne $Only){continue}
 $line=$entry.Value
 $speech=New-Object System.Speech.Synthesis.SpeechSynthesizer
 try {
  $speech.SelectVoice($line.voice)
  $speech.Rate=$line.rate
  $speech.Volume=$line.volume
  $format=New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(22050,[System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen,[System.Speech.AudioFormat.AudioChannel]::Mono)
  $speech.SetOutputToWaveFile((Join-Path $root ($entry.Name+'.wav')),$format)
  $parts=@($line.segments | ForEach-Object { [System.Security.SecurityElement]::Escape($_.text)+'<break time="'+$_.pause_ms+'ms"/>' })
  $ssml='<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="zh-CN"><prosody pitch="'+$line.pitch+'">'+($parts -join '')+'</prosody></speak>'
  $speech.SpeakSsml($ssml)
  Write-Output ('Generated '+$entry.Name)
 } finally {$speech.Dispose()}
}
