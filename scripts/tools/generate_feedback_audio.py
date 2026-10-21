"""生成可循环的排水泵低频运转声及短促断路器音效，无外部依赖。"""
import math,random,struct,wave
from pathlib import Path
root=Path(__file__).resolve().parents[2]/'assets/audio/field'
rate=22050
rng=random.Random(184)
def save(name,values):
    with wave.open(str(root/(name+'.wav')),'wb') as out:
        out.setnchannels(1);out.setsampwidth(2);out.setframerate(rate)
        out.writeframes(b''.join(struct.pack('<h',int(max(-1,min(1,v))*32767)) for v in values))
pump=[]
for i in range(rate*4):
    t=i/rate
    motor=math.sin(2*math.pi*55*t)+.4*math.sin(2*math.pi*110*t)+.15*math.sin(2*math.pi*220*t)
    pump.append(.22*motor*(.78+.22*math.sin(2*math.pi*7*t)))
save('pump_motor',pump)
click=[]
for i in range(int(rate*.28)):
    t=i/rate
    snap=rng.uniform(-1,1)*math.exp(-t*110)
    body=math.sin(2*math.pi*145*t)*math.exp(-t*30)
    click.append(.5*snap+.25*body)
save('breaker',click)
