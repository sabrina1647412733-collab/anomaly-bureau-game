"""Build 50 Hz precomputed voice envelopes; playback stays aligned to real audio."""
import json,math,wave
from pathlib import Path
import numpy as np
root=Path(__file__).resolve().parents[2]/'assets/audio/performance'
lines=json.loads((root/'lines.json').read_text(encoding='utf-8'))
for key,line in lines.items():
    with wave.open(str(root/(key+'.wav')),'rb') as source:
        rate=source.getframerate();channels=source.getnchannels()
        samples=np.frombuffer(source.readframes(source.getnframes()),dtype='<i2').astype(float)/32768
        samples=samples.reshape(-1,channels).mean(axis=1)
    size=round(rate/50)
    rms=np.array([np.sqrt(np.mean(samples[i:i+size]**2)) for i in range(0,len(samples),size)])
    ref=max(.01,float(np.quantile(rms,.9)))
    values=np.clip((np.maximum(0,rms-.008)/ref)**.65,0,1)
    line.update(seconds=round(len(samples)/rate,3),hz=50,envelope=[round(float(x),3) for x in values],peak=round(float(np.max(np.abs(samples))),4))
(root/'performance.json').write_text(json.dumps(lines,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
print('Analyzed clips:',len(lines),'seconds:',round(sum(x['seconds'] for x in lines.values()),1))
