"""Original procedural feedback cues. Standard-library only, deterministic mono WAV.
No downloaded samples or speech; these cues route to SFX rather than Voice.
"""
from pathlib import Path
import math,random,wave,struct
out=Path(__file__).resolve().parents[2]/'assets/audio/polish';out.mkdir(parents=True,exist_ok=True)
rate=22050;rng=random.Random(18423)
def save(name,seconds,fn):
 samples=[];smooth=0.
 for i in range(int(seconds*rate)):
  t=i/rate;smooth=.90*smooth+.10*rng.uniform(-1,1)
  v=fn(t,i,smooth,rng.uniform(-1,1))
  samples.append(max(-.95,min(.95,v)))
 with wave.open(str(out/(name+'.wav')),'wb') as f:
  f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes(b''.join(struct.pack('<h',int(v*32767)) for v in samples))
save('paper_turn',.52,lambda t,i,l,n: (.32*n+.28*l)*math.sin(math.pi*t/.52)**2*(.55+.45*math.sin(t*93)**2))
save('phone_notice',.56,lambda t,i,l,n: .17*sum(math.sin(math.tau*hz*(t-start))*math.exp(-(t-start)*19) if t>=start else 0 for hz,start in [(660,0),(880,.15)])*(1-t/.56))
save('valve_turn',1.15,lambda t,i,l,n: .20*math.sin(t*math.pi/1.15)**2*(l+math.sin(math.tau*(145*t+8*t*t))*.25)+.07*n*math.exp(-((t-.88)/.04)**2))
save('water_recede',3.8,lambda t,i,l,n: (.6*l+.09*n)*min(1,t/.22)*max(0,1-t/3.8)**.7+.04*math.sin(math.tau*(65*t-3*t*t))*math.sin(t*3)**4*max(0,1-t/3.8))
print('Created four original feedback cues:',out)
