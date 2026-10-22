"""Original short mechanical feedback cues; standard-library only, fixed seed."""
import math, random, struct, wave
from pathlib import Path
rate=22050
root=Path(__file__).resolve().parents[2]/'assets/audio/finish'
rng=random.Random(18422)
for name,duration in [('lock_rattle',.36),('device_blocked',.24)]:
    samples=[]
    for i in range(int(rate*duration)):
        t=i/rate
        if name=='lock_rattle':
            value=0.
            for onset,amp in [(0.,.6),(.085,.42),(.185,.32)]:
                u=t-onset
                if u>=0:value+=amp*(.6*rng.uniform(-1,1)*math.exp(-u*115)+.4*math.sin(math.tau*730*u)*math.exp(-u*40))
        else:
            value=.34*math.sin(math.tau*185*t)*math.exp(-t*22)+.22*rng.uniform(-1,1)*math.exp(-t*90)
        samples.append(int(max(-.8,min(.8,value))*32767))
    with wave.open(str(root/(name+'.wav')),'wb') as out:
        out.setnchannels(1);out.setsampwidth(2);out.setframerate(rate)
        out.writeframes(struct.pack('<'+'h'*len(samples),*samples))
    print(name,duration)
