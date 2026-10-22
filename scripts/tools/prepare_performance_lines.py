"""Extract canonical captions and author modest SAPI prosody, without rewriting story."""
import json,re
from pathlib import Path
root=Path(__file__).resolve().parents[2]
text=(root/'scripts/laundry_campaign.gd').read_text(encoding='utf-8')
lines={}
for who,caption,key in re.findall(r'\["([^"\n]+)","([^"\n]+)","([a-z_0-9]+)"\]',text):
    if not key.startswith(('lady_','zhou_','xu_')):continue
    lines[key]={'speaker':who,'text':caption}
lines.update({
    'lady_count':{'speaker':'周秀兰','text':'一件……两件……三件……四件……五件……还差一件。'},
    'lady_ask':{'speaker':'周秀兰','text':'是不是洗好了？'},
    'lady_wipe':{'speaker':'周秀兰','text':'湿了就得擦。纸泡开，就认不出字了。'},
    'aqi_voice':{'speaker':'阿七','text':'你现在能看见我了？'},
})
for key,line in lines.items():
    who=line['speaker']
    voice,rate,pitch,volume=('Microsoft Kangkang',0,'0%',96)
    mood='neutral';gap=.38
    if who=='周秀兰':
        voice,rate,pitch,volume=('Microsoft Huihui',-2,'-6%',87)
        mood='concern';gap=.62
    elif who=='老周':
        voice,rate,pitch,volume=('Microsoft Kangkang',-2,'-7%',92)
        mood='guarded';gap=.55
    elif who=='秀兰':voice,rate,pitch,volume=('Microsoft Huihui',0,'+5%',91)
    elif who=='阿七':voice,rate,pitch,volume=('Microsoft Yaoyao',-1,'-2%',89)
    if key in ['lady_complete','lady_thankyou','lady_remember']:
        mood='relief';rate=-1;pitch='-3%';gap=.72
    if key in ['lady_xiaoman','zhou_missing']:gap=.85
    line.update(voice=voice,rate=rate,pitch=pitch,volume=volume,mood=mood,gap=gap)
    # Punctuation is retained. The extra pauses mark deliberate dramatic beats.
    segments=[]
    for chunk in re.findall(r'[^，。！？；…]+[，。！？；…]*',line['text']):
        pause=100 if chunk.endswith('，') else (520 if '…' in chunk else 250)
        if chunk.strip('。？，') in ['小满','是，小满','孩子','齐了']:pause=520
        segments.append({'text':chunk,'pause_ms':pause})
    line['segments']=segments
out=root/'assets/audio/performance';out.mkdir(parents=True,exist_ok=True)
(out/'lines.json').write_text(json.dumps(lines,ensure_ascii=False,indent=2),encoding='utf-8')
print('Authored lines:',len(lines))
