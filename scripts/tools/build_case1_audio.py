"""Reproducible first-case mix assets. Python numpy/miniaudio/soundfile; see SOURCES.md.
Run from project root. Downloads are intentionally separate and never implicit.
"""
from pathlib import Path
import sys,json,wave,subprocess
import numpy as np
sys.path.insert(0,str(Path('_tools/pydeps').resolve()))
import miniaudio,imageio_ffmpeg
SR=44100
OUT=Path('assets/audio/finish');OUT.mkdir(parents=True,exist_ok=True)
rng=np.random.default_rng(184)
report={}
def read(id):
    d=miniaudio.decode_file(str(Path('_tools/audio_sources')/(id+'.mp3')),output_format=miniaudio.SampleFormat.SIGNED16,nchannels=2,sample_rate=SR)
    return np.asarray(d.samples,dtype=np.float32).reshape(-1,2)/32768
def lowpass(x,cut):
    f=np.fft.rfftfreq(len(x),1/SR)
    return np.fft.irfft(np.fft.rfft(x,axis=0)/(1+(f[:,None]/cut)**4),n=len(x),axis=0).astype(np.float32)
def save(name,x,loop=False,peak=.75):
    if x.ndim==1:x=x[:,None]
    x=x-np.mean(x,axis=0)
    if loop:
        # Equal-power tail/head overlap, and a short cosine fade at the seam.
        n=min(int(SR*.5),len(x)//10);w=np.linspace(0,np.pi/2,n)[:,None]
        x=np.concatenate([x[n:-n],x[-n:]*np.cos(w)**2+x[:n]*np.sin(w)**2])
    else:
        n=min(int(SR*.012),len(x)//10);x[:n]*=np.linspace(0,1,n)[:,None];x[-n:]*=np.linspace(1,0,n)[:,None]
    x*=peak/max(float(np.max(np.abs(x))),.0001)
    ext='.ogg' if loop else '.wav'
    pcm=(x*32767).astype('<i2')
    path=OUT/(name+'.wav')
    with wave.open(str(path),'wb') as w:
        w.setnchannels(x.shape[1]);w.setsampwidth(2);w.setframerate(SR);w.writeframes(pcm.tobytes())
    if loop:
        subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-hide_banner','-loglevel','error','-y','-i',str(path),'-c:a','libvorbis','-q:a','4',str(OUT/(name+ext))],check=True)
        path.unlink()
    report[name]={'seconds':round(len(x)/SR,3),'peak':round(float(np.max(np.abs(x))),4),'rms':round(float(np.sqrt(np.mean(x*x))),4),'channels':x.shape[1]}

rain=read('640655')
rain=np.tanh(rain/max(.0001,float(np.quantile(np.abs(rain),.995))*2))
save('rain_outside',rain,True,.68);save('rain_inside',lowpass(rain,1300),True,.6)
washer=read('423210');save('washer_loop',lowpass(washer,2600),True,.65)
latch=read('11574').mean(axis=1);save('washer_latch',latch,False,.7)
knock=read('256513').mean(axis=1)
# Keep one complete first knock; story scripts already own the two-short/one-long rhythm.
env=np.convolve(np.abs(knock),np.ones(441)/441,mode='same');on=int(np.argmax(env>.12*env.max()))
save('knock',knock[max(0,on-220):min(len(knock),on+int(SR*.43))],False,.78)

def noise_hit(duration,kind,variant=0):
    n=int(SR*duration);t=np.arange(n)/SR
    noise=rng.normal(0,1,(n,1)).astype(np.float32)
    cut={'tile':2400,'wood':1350,'metal':3900,'cloth':850,'paper':4600}[kind]
    y=lowpass(noise,cut)[:,0]*np.exp(-t*(20 if kind!='paper' else 11))
    if kind in ('tile','wood','metal'):
        freq={'tile':165,'wood':105,'metal':510}[kind]*(1+.035*variant)
        y+=np.sin(2*np.pi*freq*t)*np.exp(-t*34)*.55
    if kind=='metal':y+=.22*np.sin(2*np.pi*1080*t)*np.exp(-t*19)
    return y
for kind in ('tile','wood','metal'):
    for i in range(4):save('step_'+kind+str(i),noise_hit(.22,kind,i),False,.62)
save('land',noise_hit(.32,'wood')+noise_hit(.32,'tile')*.4,False,.7)
save('cloth',noise_hit(.42,'cloth'),False,.45)
save('paper',noise_hit(.6,'paper'),False,.5)
door=noise_hit(.72,'wood');door[int(SR*.31):]+=noise_hit(.41,'metal')*.12
save('door',door,False,.7)
save('key',noise_hit(.38,'metal'),False,.55)
save('breaker',noise_hit(.14,'metal'),False,.65)

# Original restrained cues, all in D minor; no percussion under dialogue.
def cue(name,mode):
    length=64;n=SR*length;t=np.arange(n)/SR
    left=np.zeros(n);right=np.zeros(n)
    notes={'quiet':[50,57,60,65,57,62,60,53], 'memory':[62,65,69,67,65,62,60,57], 'depth':[38,45,41,38,43,41,36,38], 'suspense':[50,51,57,53,50,56,51,45]}[mode]
    for k,note in enumerate(notes*2):
        start=int((k*4+.2)*SR);dur=min(6*SR,n-start);tt=np.arange(dur)/SR
        f=440*2**((note-69)/12)
        wave=(np.sin(2*np.pi*f*tt)+.18*np.sin(2*np.pi*f*2*tt)+.045*np.sin(2*np.pi*f*3*tt))
        wave*=np.minimum(tt/.045,1)*np.exp(-tt/(1.9 if mode!='depth' else 3))*.19
        pan=.33 if k%2 else .67
        left[start:start+dur]+=wave*np.sqrt(pan);right[start:start+dur]+=wave*np.sqrt(1-pan)
    for f,amp in [(73.416,.07),(110,.035),(146.832,.025)]:
        drone=np.sin(2*np.pi*f*t+.4*np.sin(2*np.pi*.09*t))*(.7+.3*np.sin(2*np.pi*t/32))
        left+=drone*amp;right+=np.sin(2*np.pi*f*t+.45)*amp*.9
    mix=np.column_stack([left,right]);fade=np.minimum(t/2,1)*np.minimum((length-t)/3,1)
    mix*=fade[:,None];save(name,mix,True,.62)
for name,mode in [('room_theme','quiet'),('memory_theme','memory'),('depth_theme','depth'),('suspense_theme','suspense')]:cue(name,mode)
(OUT/'mix_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(report,ensure_ascii=False))
