"""Independent destination-indexed bytes and closed-form lifetime audit.
Does not import experiment.py or compile any production implementation.
"""
import hashlib,json,os,re,resource,struct,time
from pathlib import Path
H=Path(__file__).resolve().parent;t0=time.perf_counter();checks=0;corruptions=0
def check(ok):
    global checks
    assert ok
    checks+=1
def digest(b):return hashlib.sha256(b).hexdigest()
cases=json.loads((H/'prior-input-cases.json').read_text())
artifacts=json.loads((H/'fixtures.json').read_text())
names=['wq','wk','wv','wo','gamma_a','gamma_m','wg','wu','wd']
for case,artifact in zip(cases,artifacts):
    s=case['shape'];d=s['qh']*s['hd'];dp=s['hp']*s['hd'];k=s['kv']*s['hd'];f=s['f'];fp=2**((f-1).bit_length())
    slots=[(g*(s['hp']//s['kv'])+j)*s['hd']+lane for g in range(s['kv']) for j in range(s['qh']//s['kv']) for lane in range(s['hd'])]
    shapes=[(d,d,dp,dp,slots,range(d)),(k,d,k,dp,range(k),range(d)),
      (k,d,k,dp,range(k),range(d)),(d,d,dp,dp,range(d),slots),
      (1,d,1,dp,[0],range(d)),(1,d,1,dp,[0],range(d)),
      (d,f,dp,fp,range(d),range(f)),(d,f,dp,fp,range(d),range(f)),(f,d,fp,dp,range(f),range(d))]
    sizes=[]
    for name,(nr,nc,pr,pc,rs,cs) in zip(names,shapes):
        raw=bytes.fromhex(case['arrays'][name]['hex']);sizes.append(len(raw))
        ri={v:i for i,v in enumerate(rs)};ci={v:i for i,v in enumerate(cs)}
        want=[]
        for r in range(pr):
            for c in range(pc):
                v=struct.unpack('b',raw[ri[r]*nc+ci[c]:ri[r]*nc+ci[c]+1])[0] if r in ri and c in ci else 0
                want.append(v)
        for mode in ['baseline','candidate','negative']:
            check(artifact[mode]['outputs'][name]==want)
        encoded=struct.pack('<'+'b'*len(want),*want)
        corrupted=bytearray(encoded);corrupted[-1]^=1
        check(digest(encoded)!=digest(corrupted));corruptions+=1
    bv=[sum(sizes[:i+1]) if i<5 else sum(sizes[5:i+1]) for i in range(9)]
    nv=[sum(sizes[:i+1]) for i in range(9)]
    check(artifact['baseline']['visits']==bv)
    check(artifact['candidate']['visits']==sizes)
    check(artifact['negative']['visits']==nv)
    check(artifact['baseline']['peak_decode_bytes']==max(bv))
    check(artifact['candidate']['peak_decode_bytes']==max(sizes))
    check(artifact['negative']['peak_decode_bytes']==sum(sizes))
    check(artifact['first_errors']==[dict(status='injected_pad:'+n,order=names[:i]) for i,n in enumerate(names)])

# Allocation-free closed-form target model independent of event accumulator.
d=4096;dp=4096;f=14336;fp=16384;kv=1024;rope=2*128*64*8;small=2560
raw=2*d*d+2*kv*d+2*d+3*d*f+small
pad=2*dp*dp+2*kv*dp+2*dp+3*dp*fp;public=pad+rope+small
maps=16*fp+8*d;support=8*fp
base=raw+pad+maps+2*rope+small
bp=base+(d+3*d*f);ap=base+d*f
ledger=json.loads((H/'payload-ledger.json').read_text())
check(ledger['before']['peak_bytes']==bp);check(ledger['after']['peak_bytes']==ap)
check(ledger['pad_saving_bytes']==2*d*f+d==117444608)
check(ledger['raw11_bytes']==raw);check(ledger['padded9_bytes']==pad);check(ledger['public_block_bytes']==public)
zero=positive=0
for row in ledger['rows']:
    copied=row['constructor']=='borrowed_copy'
    ctor=raw+pad+2*rope+public+small+support if copied else raw+public+rope+small+support
    scratch=(dp*fp if row['hash_workers']==1 else pad) if row['full'] else 0
    record=raw+public+(pad+rope if copied else 0)+scratch+rope+small
    if row['raw_release']=='post':record-=raw
    if row['raw_release']=='split':ctor-=raw-small;record-=raw
    before=[bp,ctor,record];after=[ap,ctor,record]
    check(row['before_phases']==before);check(row['after_phases']==after)
    check(row['saving_bytes']==max(before)-max(after))
    check(row['after_bytes']==max(after));check(row['before_bytes']==max(before))
    check(row['after_with_current_next_pins_gib']==(max(after)+(row['pins']+1)*public)/2**30)
    if row['saving_bytes']==0:
        zero+=1;check(row['limiting_phase']!='pad')
        check(max(after)!=max(before)-117444608)
    else:positive+=1
check(len(ledger['rows'])==48);check(zero>0 and positive>0)

# Restore just the edited Rust region; all surrounding checks remain identical.
native=(H/'native/hashline__src__private_block__trained_block.rs').read_text()
candidate=(H/'candidate-trained_block.rs').read_text()
lo=native.index('        let aw = [');hi=native.index('        let public = AttentionPublic',lo)
clo=candidate.index('        // Separate call statements');chi=candidate.index('        let public = AttentionPublic',clo)
calls=lambda x:re.findall(r'pad_matrix\(&\w+\.i8s\(\),[^)]*\)',x)
check(calls(native[lo:hi])==calls(candidate[clo:chi]));check(len(calls(candidate[clo:chi]))==9)
check(candidate[:clo]+native[lo:hi]+candidate[chi:]==native)
check(len(re.findall(r'let (?:aw|fw)\d = pad_matrix\(',candidate[clo:chi]))==9)
check('let aw = [aw0, aw1, aw2, aw3, aw4];' in candidate)
check('let fw = [fw0, fw1, fw2, fw3];' in candidate)
commands=json.loads((H/'commands.json').read_text())
probe=next(c for c in commands if c['argv']==[str(H/'drop_probe')])
probe_out=json.loads((H/probe['stdout']).read_text())
check(probe['exit_code']==0 and probe_out['outputs_equal'])
ps=[256,64,64,256,16,16,400,400,400]
check(probe_out['candidate_visits']==ps)
check(probe_out['baseline_peak_decode_bytes']==max(sum(ps[:5]),sum(ps[5:])))
check(probe_out['candidate_peak_decode_bytes']==max(ps))
check(probe_out['negative_peak_decode_bytes']==sum(ps))
out=dict(status='PASS',checks=checks,independent_corruption_controls=corruptions,
  independent_first_error_cases=48*9,byte_fixtures=len(artifacts),model_rows=len(ledger['rows']),
  zero_saving_rows=zero,positive_saving_rows=positive,
  wall_seconds=time.perf_counter()-t0,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
  threads=1,nice=os.nice(0),affinity=sorted(os.sched_getaffinity(0)),
  scope='Independent persisted synthetic byte/model/source/probe audit; no native loader or proof')
(H/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,sort_keys=True))
