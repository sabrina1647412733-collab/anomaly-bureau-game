"""Check authored dialogue PCM without playback; this is not a listening review."""
import argparse, array, json, math, wave
from pathlib import Path

parser=argparse.ArgumentParser()
parser.add_argument('--report', required=True)
args=parser.parse_args()
audio=Path(__file__).resolve().parents[2]/'assets'/'audio'/'case2'
manifest=json.loads((audio/'dialogue_manifest.json').read_text(encoding='utf-8-sig'))
rows=[]
failures=[]
for entry in manifest['lines']:
    path=audio/entry['file']
    if not path.exists():
        failures.append(entry['id']+': missing WAV');continue
    with wave.open(str(path),'rb') as stream:
        channels, width, rate, count=stream.getnchannels(),stream.getsampwidth(),stream.getframerate(),stream.getnframes()
        samples=array.array('h',stream.readframes(count))
    peak=max((abs(v) for v in samples),default=0)
    clipping=sum(abs(v)>=32767 for v in samples)
    rms=math.sqrt(sum(v*v for v in samples)/max(1,len(samples)))
    row={**entry,'seconds':count/rate,'sample_rate':rate,'channels':channels,'bits':width*8,'peak_dbfs':20*math.log10(max(peak,1)/32768),'rms_dbfs':20*math.log10(max(rms,1)/32768),'clipped_samples':clipping}
    rows.append(row)
    if channels!=1 or width!=2 or rate!=22050 or count<rate*.2 or peak<100 or clipping:
        failures.append(entry['id']+': invalid PCM, silence or clipping')
report={'kind':'objective PCM validation, not subjective voice acting acceptance','case_id':'00201','lines':rows,'total_seconds':sum(r['seconds'] for r in rows),'failures':failures}
Path(args.report).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'lines':len(rows),'seconds':report['total_seconds'],'failures':failures},ensure_ascii=False))
raise SystemExit(bool(failures))
