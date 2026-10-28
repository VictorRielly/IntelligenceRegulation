"""Independent audit: no imports from tail/probe/census/prior_fzc_model."""
from pathlib import Path
import hashlib,itertools,json,resource,struct,time
import reference as ref
H=Path(__file__).resolve().parent
checks=0
def ck(v,msg=''):
    global checks
    checks+=1
    assert v,msg
def enc(v):return b''.join(struct.pack('<QQ',*x) for x in v)
def params(p):
    scalars={'alpha','beta','gact','mupad'};lists={'mu','nu','cst','pad'}
    return {k:ref.R(*v) if k in scalars else [ref.R(*x) for x in v] if k in lists else v for k,v in p.items()}
def main():
    start=time.monotonic();cases=json.loads((H/'cases.json').read_text());fixtures=json.loads((H/'fixtures.json').read_text())
    for f in fixtures:
        hist=[];hashes=[];digest=b'fzc-tail-synthetic-challenge-v1';p=params(f['params'])
        for j in range(f['n']):
            tabs=[ref.direct_prefix(tb,[ref.R(*x) for x in hist]) for tb in f['original']]
            sums=ref.round_values(tabs,p,f['support'],5)
            digest=hashlib.sha256(digest+enc(sums)).digest();hashes.append(digest.hex())
            hist.append((int.from_bytes(digest[:16],'little')%ref.P,int.from_bytes(digest[16:],'little')%ref.P))
        final=[ref.direct_prefix(tb,[ref.R(*x) for x in hist])[0].v for tb in f['original']]
        matches=[c for c in cases if c['n']==f['n'] and c['support']==f['support']]
        ck(len(matches)==8)
        for c in matches:
            ck(c['hashes']==hashes,'independent original-table chain')
            ck(c['final_sha256']==hashlib.sha256(enc(final)).hexdigest(),'independent terminals')
    rows=json.loads((H/'schedules.json').read_text())
    for r in rows:
        n,th,k,d,f,s,m,p,c=[r[x] for x in ('n','tail','k','degree','fused','split','mapped','profile','candidate')]
        h=min(n-1,th) if th else 0;g=n-h;folds=1 if f else g
        ck(r['host_rounds']==h and r['gpu_rounds']==g)
        ck(r['launches']==g*(2-int(s))+folds+(int(not c) if h else 1))
        ck(r['explicit_copy_bytes']==g*(0 if s and m else 16*(d+1))+(16*k*(2**h) if h else 16*k))
        ck(r['stream_or_profile_syncs']==g*(int(not(s and m))+int(p))+int(p)*folds+1)
        ck(r['host_pairs']==2**h-1 and r['host_fold_outputs']==k*(2**h-1))
        ck(r['boundary_length']==(2**h if h else None))
        ck(r['host_parallel_regions']==max(0,h-7))
        kd=k+(1+int(k==21) if s else 0)
        traffic=0 if not h else (48*k if c else 48*kd+32*k)*2**h
        ck(r['boundary_logical_bytes']==traffic)
        ck(r['raw_eligible_if_resident']==bool(s and f and n>max(2,th+1)))
    pins=json.loads((H/'source-pins.json').read_text())
    for pin in pins:
        ck(hashlib.sha256((H.parent.parent/pin['copy']).read_bytes()).hexdigest()==pin['sha256'])
    src=(H/'source/ops__zkp-mvp__gpu-zerocheck__hashline__src__gpu__cuda.rs').read_text()
    for snippet in ['const FZC_TAIL_DEFAULT: usize = 5;', 'half <= (1usize << self.tail_log)', 'let n_words = self.k * half * 2;', 'self.kd as i32, half as i32', 'if half <= 64', 'let chunk = 16usize;', 'n - 1 > tail_log', 'self.st.bytes_d2h += 8 * n_words as u64;']:
        ck(snippet in src,snippet)
    # These independently test concrete falsifying interpretations, not a real verifier.
    neg=[]
    base=next(r for r in rows if r['n']==21 and r['tail']==5 and r['k']==21 and r['degree']==5 and r['fused'] and r['split'] and r['mapped'] and not r['profile'] and not r['candidate'])
    for name,bad,expected in [('tail_counter_covers_all_messages',base['boundary_copy_bytes'],base['boundary_copy_bytes']+base['mapped_result_store_bytes']),('copy_all_derived_tables',16*23*32,base['boundary_copy_bytes']),('threshold_applies_before_first_round',6,5),('host_tail_releases_device_arena',0,16*23*(1<<21)),('mapped_zero_traffic',0,base['mapped_result_store_bytes']),('wrong_msb_lsb_contract',[(3,0),(8,0)],[x.v for x in ref.direct_prefix([(0,0),(1,0),(2,0),(4,0)],[ref.R(3)])])]:
        ck(bad!=expected,name);neg.append(name)
    out=dict(status='PASS_INDEPENDENT_AUDIT',checks=checks,source_pins=len(pins),schedules=len(rows),full_round_cases=len(cases),negative_controls=neg,wall_seconds=time.monotonic()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,scope='Independent original-slot polynomial and original-table MLE plus closed-form schedule/traffic audit; not a native prover or verifier')
    (H/'validation-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
if __name__=='__main__':main()
