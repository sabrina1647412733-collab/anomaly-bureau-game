Add-Type -AssemblyName System.Speech
$dialogueRoot=Join-Path $PSScriptRoot '..\..\assets\audio\dialogue'
New-Item -ItemType Directory -Force -Path $dialogueRoot | Out-Null
$lines=@{
'lady_self'='秀兰啊，今天生意怎么样？'; 'zhou_greeting'='你不是来收房的。那你是来找人的。';
'xu_zhou_family'='周秀兰住过这里？'; 'zhou_family'='三楼。她男人跑的时候，带走了一摞纸。病历，证件。人没带。';
'xu_zhou_stay'='你怎么还住这儿？'; 'zhou_stay'='水表每个月得看。没人住，也会走。';
'lady_count'='一件，两件，三件，四件，五件。还差一件。'; 'lady_ask'='是不是洗好了？';
'lady_wait'='洗过了。得等他穿。'; 'xu_ask'='您是来取衣服的？';
'lady_job'='还行。还剩最后一单。衣服干了，他就能出门。';
'xu_missing'='我还没找到那件。您能让我看看后房吗？';
'lady_key'='钥匙别又放错地方。你找一找，我等着。';
'xu_tomorrow'='好。我明天再来，把那件衣服找回来。';
'lady_return'='你回来了。钥匙找着没有？这孩子的脸，我怎么想不清了。';
'xu_name'='他叫周小满。您看，这是他的接种证，还有医院寄来的出院小结。';
'lady_xiaoman'='小满。是，小满。这孩子，鞋怎么少了一只？';
'lady_water'='上面那件衣服，总也晾不干。你听，水还在往下走。';
'lady_copy'='不是这一回的。那一件，我一直没有取到。';
'xu_return'='这是七号机的原衣。您袋里有五件，加上这件，正好六件。';
'lady_complete'='齐了。终于齐了。';
'lady_thankyou'='谢谢你啊。你叫什么名字？';
'xu_myname'='许砚。'; 'lady_remember'='许砚，我记着。';
'zhou_intro'='新来的？那张洗衣单还在。三楼抽屉的钥匙，还有五零三的信箱钥匙，拿去。';
'zhou_warning'='信箱归信箱，房门归房门。你先弄清楚，她在等谁。';
'zhou_water'='她进去抱孩子。后房先冒烟。我们都盯着烟，谁也没看脚底下。出来的是水。';
'zhou_missing'='孩子？我没见着。没见着的事，你别替我写。管线图在这里，你自己去核实。';
'lady_wipe'='湿了就得擦。纸泡开，就认不出字了。'
}
foreach($item in $lines.GetEnumerator()){
 $speech=New-Object System.Speech.Synthesis.SpeechSynthesizer
 $female=$item.Key.StartsWith('lady_')
 $matchVoice=$speech.GetInstalledVoices() | Where-Object {$_.VoiceInfo.Culture.Name -eq 'zh-CN' -and $_.VoiceInfo.Gender.ToString() -eq $(if($female){'Female'}else{'Male'})} | Select-Object -First 1
 if($matchVoice){$speech.SelectVoice($matchVoice.VoiceInfo.Name)}
 $speech.Rate=$(if($female){-2}else{-1})
 $format=New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(22050,[System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen,[System.Speech.AudioFormat.AudioChannel]::Mono)
 $speech.SetOutputToWaveFile((Join-Path $dialogueRoot ($item.Key+'.wav')),$format)
 $speech.Speak($item.Value);$speech.Dispose()
}
Write-Output "Generated $($lines.Count) dialogue clips"
