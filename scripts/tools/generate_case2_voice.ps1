param([string]$Only='')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Speech
$audioRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\assets\audio\case2'))
$manifest=Get-Content -LiteralPath (Join-Path $audioRoot 'dialogue_manifest.json') -Raw -Encoding utf8 | ConvertFrom-Json
$profiles=@{
 '许砚'=@{voice='Microsoft Kangkang';rate=0;pitch='0%';volume=94}
 '阿七'=@{voice='Microsoft Yaoyao';rate=-1;pitch='-3%';volume=91}
 '何伯'=@{voice='Microsoft Kangkang';rate=-2;pitch='-8%';volume=91}
 '孙素琴'=@{voice='Microsoft Huihui';rate=-2;pitch='-5%';volume=88}
 '九楼住户'=@{voice='Microsoft Huihui';rate=0;pitch='1%';volume=90}
 '派遣科'=@{voice='Microsoft Huihui';rate=0;pitch='0%';volume=94}
}
foreach($entry in $manifest.lines){
 if($Only -and $entry.id -ne $Only){continue}
 $profile=$profiles[$entry.speaker]
 if(-not $profile){$profile=$profiles['派遣科']}
 $synth=New-Object System.Speech.Synthesis.SpeechSynthesizer
 try {
  $synth.SelectVoice($profile.voice);$synth.Rate=$profile.rate;$synth.Volume=$profile.volume
  $format=New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(22050,[System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen,[System.Speech.AudioFormat.AudioChannel]::Mono)
  $synth.SetOutputToWaveFile((Join-Path $audioRoot $entry.file),$format)
  $parts=[regex]::Matches($entry.text,'[^，。！？；：…]+[，。！？；：…]*') | ForEach-Object {
   $segment=$_.Value
   $pause=if($segment -match '[。！？]$'){260}elseif($segment -match '[…]$'){390}else{125}
   [Security.SecurityElement]::Escape($segment)+'<break time="'+$pause+'ms"/>'
  }
  $ssml='<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="zh-CN"><prosody pitch="'+$profile.pitch+'">'+($parts -join '')+'</prosody></speak>'
  $synth.SpeakSsml($ssml)
  Write-Output ('CASE2_VOICE '+$entry.id+' '+$entry.speaker)
 }finally{$synth.Dispose()}
}
