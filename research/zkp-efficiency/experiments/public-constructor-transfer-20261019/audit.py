"""Independent artifact audit. Does not import or execute candidate code."""
import hashlib
import json
import os
from pathlib import Path
import resource
import signal
import struct
import time

HERE=Path(__file__).resolve().parent
resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2)
resource.setrlimit(resource.RLIMIT_CPU,(59,59))
signal.alarm(59)
os.nice(19)
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
start=time.perf_counter()
checks=0


def check(ok):
    global checks
    assert ok
    checks+=1


def reconstruct(s, raw):
    d,f,dh=s['d'],s['f'],s['dh']
    dp,fp,kv=s['dp'],s['fp'],s['kv']*dh
    qaxis=[]
    for group in range(s['kv']):
        for head in range(s['qh']//s['kv']):
            for lane in range(dh):
                qaxis.append((group*(s['hp']//s['kv'])+head)*dh+lane)
    d_axis=list(range(d));f_axis=list(range(f));k_axis=list(range(kv))
    maps=[('wq',qaxis,d_axis,dp,dp),('wk',k_axis,d_axis,kv,dp),
          ('wv',k_axis,d_axis,kv,dp),('wo',d_axis,qaxis,dp,dp),
          ('gamma_a',[0],d_axis,1,dp),('gamma_m',[0],d_axis,1,dp),
          ('wg',d_axis,f_axis,dp,fp),('wu',d_axis,f_axis,dp,fp),
          ('wd',f_axis,d_axis,fp,dp)]
    out={}
    for n,rows,cols,nr,nc in maps:
        check(len(raw[n])==len(rows)*len(cols))
        a=[0]*(nr*nc)
        for index,value in enumerate(raw[n]):
            r,c=divmod(index,len(cols))
            a[rows[r]*nc+cols[c]]=value
        out[n]=a
    for n in ['rope_cos','rope_sin','exp','act']:
        out[n]=raw[n][:]
    return out


def digest(a):
    buf=bytearray()
    for n in ['wq','wk','wv','wo','gamma_a','gamma_m','wg','wu','wd','rope_cos','rope_sin','exp','act']:
        buf.extend(struct.pack('<Q',len(a[n])))
        kind='q' if n in ['rope_cos','rope_sin','exp'] else 'h' if n=='act' else 'b'
        buf.extend(struct.pack('<'+kind*len(a[n]),*a[n]))
    return hashlib.sha256(buf).hexdigest()


fixtures=json.loads((HERE/'fixtures.json').read_text())
corruptions=0
for row in fixtures:
    expected=reconstruct(row['shape'],row['raw'])
    check(expected==row['padded'])
    check(digest(expected)==row['serialized_sha256'])
    for n,values in expected.items():
        check(values==row['padded'][n])
        # Independent corrupted-output control, no candidate validation claim.
        original=values[0];values[0]=original^1
        check(digest(expected)!=row['serialized_sha256'])
        values[0]=original;corruptions+=1

ledger=json.loads((HERE/'payload-ledger.json').read_text())
prior=json.loads((HERE.parent/'public-setup-lifetimes-20261019/public-block-payload-components.json').read_text())['128']
public=sum(prior.values()); padded=sum(v for k,v in prior.items() if k not in ['rope_cos','rope_sin','exp','act'])
rope=prior['rope_cos']+prior['rope_sin']
raw=2*4096**2+2*1024*4096+3*4096*14336+2*4096+256*10
check(ledger['public_payload_bytes']==public==243411456)
check(ledger['raw11_bytes']==raw==218114560)
check(ledger['padded_i8_bytes']==padded==243277824)
check(ledger['avoided_to_vec_bytes_per_load']==public-512)
for row in ledger['rows']:
    maps=16*16384+8*4096
    pad=raw+padded+4096*14336+maps+2*rope+2560
    ctor=raw+public+rope+2560
    post=0
    if row['mode']=='borrowed_copy':
        ctor+=padded+rope
        post=padded+rope
    ctor += 8*16384
    scratch=4096*16384 if row['native_workers_accounted']==1 else padded
    record=raw+public+post+scratch+rope+2560
    check(row['pad_phase_bytes']==pad)
    check(row['constructor_phase_bytes']==ctor)
    check(row['record_phase_bytes']==record)
    check(row['loader_payload_envelope_bytes']==max(pad,ctor,record))
    check(row['current_next_with_pins_payload_envelope_bytes']==(row['pins']+1)*public+max(pad,ctor,record))

manifest=json.loads((HERE/'native/manifest_frozen.json').read_text())['files']
pins=json.loads((HERE/'source-pins.json').read_text())
matches=0
for pin in pins:
    check(hashlib.sha256(Path(pin['source']).read_bytes()).hexdigest()==pin['sha256'])
    check(hashlib.sha256((HERE/pin['snapshot']).read_bytes()).hexdigest()==pin['sha256'])
    root='/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r8/'
    if pin['source'].startswith(root):
        rel=pin['source'][len(root):]
        check(manifest[rel]==pin['sha256']); matches+=1
check(matches==14)
result=dict(status='PASS',checks=checks,fixtures=len(fixtures),independent_output_corruption_controls=corruptions,
            source_pins=len(pins),r8_manifest_matches=matches,wall_seconds=time.perf_counter()-start,
            rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,affinity=sorted(os.sched_getaffinity(0)),
            limits='59s wall/CPU,512MiB AS;estimated64MiB;one nice19 CPU',
            scope='Independent saved-layout/encoding/payload/source-pin audit; no import of candidate; no native proof or ownership safety claim.')
(HERE/'audit-result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,sort_keys=True))
