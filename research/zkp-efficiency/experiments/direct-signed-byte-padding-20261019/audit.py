"""Independent persisted-artifact oracle; imports no candidate or prior oracle."""
import hashlib
import json
import os
from pathlib import Path
import resource
import signal
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


def expected(raw, dims, rows, cols):
    nr,nc,pr,pc=dims
    check(len(raw)==nr*nc)
    out=[0]*(pr*pc)
    for k in range(len(raw)):
        r,c=divmod(k,nc)
        out[rows[r]*pc+cols[c]]=int.from_bytes(raw[k:k+1],'little',signed=True)
    return out


fixtures=json.loads((HERE/'fixtures.json').read_text())
corruptions=0
for case in fixtures:
    s=case['shape']
    qs=[]
    for group in range(s['kv']):
        for h in range(s['qh']//s['kv']):
            for lane in range(s['hd']):
                qs.append((group*(s['hp']//s['kv'])+h)*s['hd']+lane)
    d=s['qh']*s['hd'];f=s['f'];k=s['kv']*s['hd'];dp=s['hp']*s['hd'];fp=1<<(f-1).bit_length()
    # Explicit independent semantic matrix table: ignores artifact dims/axes.
    table={'wq':([d,d,dp,dp],qs,list(range(d))),
           'wk':([k,d,k,dp],list(range(k)),list(range(d))),
           'wv':([k,d,k,dp],list(range(k)),list(range(d))),
           'wo':([d,d,dp,dp],list(range(d)),qs),
           'gamma_a':([1,d,1,dp],[0],list(range(d))),
           'gamma_m':([1,d,1,dp],[0],list(range(d))),
           'wg':([d,f,dp,fp],list(range(d)),list(range(f))),
           'wu':([d,f,dp,fp],list(range(d)),list(range(f))),
           'wd':([f,d,fp,dp],list(range(f)),list(range(d)))}
    check(set(x['name'] for x in case['matrices'])==set(table))
    for m in case['matrices']:
        dims,rows,cols=table[m['name']]
        check(dims==m['dims'])
        out=expected(bytes.fromhex(m['raw_hex']),dims,rows,cols)
        check(out==m['signed'])
        encoded=bytes((v+256)%256 for v in out)
        check(hashlib.sha256(encoded).hexdigest()==m['encoded_sha256'])
        bad=bytearray(encoded);bad[0]^=1
        check(hashlib.sha256(bad).hexdigest()!=m['encoded_sha256'])
        corruptions+=1
        # Byte identity alone would miss unsigned interpretation: check values.
        if any(v<0 for v in out):
            check([v%256 for v in out]!=out)
            corruptions+=1
for sweep in json.loads((HERE/'byte-sweeps.json').read_text()):
    check(expected(bytes.fromhex(sweep['raw_hex']),sweep['dims'],sweep['om'],sweep['im'])==sweep['signed'])

prior=json.loads((HERE.parent/'public-constructor-transfer-20261019/payload-ledger.json').read_text())
new=json.loads((HERE/'payload-ledger.json').read_text())
raw8=2*4096**2+2*1024*4096+3*4096*14336+2*4096
check(new['removed_decode_allocations_per_load']==9)
check(new['removed_decoded_bytes_per_load']==raw8==218112000)
check(new['largest_removed_decode_buffer_bytes']==4096*14336==58720256)
for old,row in zip(prior['rows'],new['rows']):
    check(old['mode']==row['mode'] and old['pins']==row['pins'] and old['native_workers_accounted']==row['native_workers_accounted'])
    # Later phases do not contain decode scratch; envelope must be recomputed.
    pad=old['pad_phase_bytes']-58720256
    peak=max(pad,old['constructor_phase_bytes'],old['record_phase_bytes'])
    check(row['pad_phase_bytes']==pad)
    check(row['loader_payload_envelope_bytes']==peak==old['loader_payload_envelope_bytes'])
    check(row['full_envelope_saving_bytes']==0)
    check(row['current_next_with_pins_payload_envelope_bytes']==old['current_next_with_pins_payload_envelope_bytes'])

pins=json.loads((HERE/'source-pins.json').read_text())
for p in pins:
    check(hashlib.sha256(Path(p['source']).read_bytes()).hexdigest()==p['sha256'])
    check(hashlib.sha256((HERE/p['snapshot']).read_bytes()).hexdigest()==p['sha256'])

result=dict(status='PASS',checks=checks,output_corruption_controls=corruptions,
            wall_seconds=time.perf_counter()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            threads=1,affinity=sorted(os.sched_getaffinity(0)),source_pins=len(pins),
            scope='Independent reconstruction of synthetic artifacts and full-lifetime count. No native proof.')
(HERE/'audit-result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
