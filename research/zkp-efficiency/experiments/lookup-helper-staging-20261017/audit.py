#!/usr/bin/env python3
"""Independent interval/bit-packing/source audit; no native proof or device."""
import ctypes as C
import hashlib
import json
import os
from pathlib import Path
import random
import resource
import signal
import time
from catalog import source_catalog,reference_catalog

HERE=Path(__file__).resolve().parent
P=2**64-2**32+1;S=2**63
U=C.c_uint64;I=C.c_int64;Z=C.c_size_t

def times(a,b):return ((a[0]*b[0]+7*a[1]*b[1])%P,(a[0]*b[1]+a[1]*b[0])%P)
def power(a,k):
    r=(1,0)
    while k:
        if k&1:r=times(r,a)
        a=times(a,a);k>>=1
    return r

def main():
    t0=time.perf_counter();os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2));resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    checks=0;controls={};rng=random.Random(2026101766001)
    def check(ok):
        nonlocal checks
        assert ok;checks+=1
    # Derive the full preimage partition from the signed interval, not the codec.
    # Each residue can have representatives r and r-P; any others exceed i64.
    for r in [0,P-S-1,P-S,P-S+1,S-2,S-1,S,S+1,P-1]+[rng.randrange(P) for _ in range(2048)]:
        pre=[x for x in (r-P,r) if -S<=x<S]
        check(len(pre)==(2 if P-S<=r<S else 1))
        for x in pre:check(x%P==r)
    check(S-(P-S)==2**32-1)
    lib=C.CDLL(str(HERE/'isolated.so'))
    lib.codec.argtypes=[C.POINTER(I),Z,C.POINTER(U),C.POINTER(U),C.POINTER(I)]
    lib.lookup.argtypes=[C.POINTER(I),C.POINTER(U),C.POINTER(U),Z,Z,C.POINTER(Z),C.POINTER(I),Z,I,C.POINTER(U),C.c_uint32]
    lib.make_h.argtypes=[C.POINTER(I),Z,Z,C.POINTER(U),C.POINTER(U),Z];lib.make_h.restype=C.c_uint32
    n=129;raw=[0]*n
    for j in [0,1,63,64,65,127,128]:raw[j]=-S+j
    vv=(I*n)(*raw);aa=(U*n)();bits=(U*3)();out=(I*n)();lib.codec(vv,n,aa,bits,out)
    check(list(out)==raw);pidx=(Z*1)(0);coef=(I*1)(2)
    target=(U*n)();lib.lookup(vv,aa,bits,n,1,pidx,coef,1,0,target,1)
    expected=[C.c_int64(2*x).value%P for x in raw];check(list(target)==expected)
    wrong=(U*3)(bits[1],bits[2],bits[0]);mut=(U*n)();lib.lookup(vv,aa,wrong,n,1,pidx,coef,1,0,mut,1)
    controls['rotated sidecar word index is detected']=list(mut)!=expected;check(controls['rotated sidecar word index is detected'])
    wrong=(U*3)(*bits);wrong[1]^=1
    lib.lookup(vv,aa,wrong,n,1,pidx,coef,1,0,mut,1)
    controls['single private ambiguity bit mutation is detected']=list(mut)!=expected;check(controls['single private ambiguity bit mutation is detected'])
    # Independent full-extension exponent inverse versus actual captured helper code.
    ext_words=0
    for n in [1,3,31,65]:
        for nc in [1,2,3,5]:
            cols=[[rng.randrange(-S,S) for _ in range(n)] for _ in range(nc)]
            alpha=(rng.randrange(P),rng.randrange(1,P));tag=(31,0)
            nh=(nc+1)//2;hlen=6+nh*(2*n+2);h=(U*hlen)(*([P-19]*hlen));raw=(I*(n*nc))(*(x for col in cols for x in col));prm=(U*4)(*alpha,*tag)
            check(lib.make_h(raw,n,nc,prm,h,hlen)==0)
            expected=[P-19]*hlen
            for k in range(nh):
                for j in range(n):
                    z=(0,0)
                    for c in cols[2*k:2*k+2]:
                        d=((alpha[0]-c[j]-tag[0])%P,alpha[1]);iv=power(d,P*P-2)
                        check(times(d,iv)==(1,0));z=((z[0]+iv[0])%P,(z[1]+iv[1])%P)
                    expected[3+k*(2*n+2)+j]=z[0];expected[3+k*(2*n+2)+n+1+j]=z[1];ext_words+=1
            check(list(h)==expected)
    proto=(HERE/'native/protocol.rs').read_text();cuda=(HERE/'native/cuda.rs').read_text();pcs=(HERE/'native/pcs.rs').read_text()
    literal=next(x.strip() for x in proto.splitlines() if 'let col = |l: &Lk| -> Vec<i64>' in x)
    check(literal+'\n'==(HERE/'captured-literal.rs.txt').read_text())
    check('a.wrapping_add(c.wrapping_mul(wit.planes[*p][x]))' in literal)
    check('a_data[lay.a_off[*p] + i] = Fp::from_i64(*v);' in proto)
    check('let mut h_data = vec![Fp::ZERO; lay.h_rows * n];' in proto)
    check('write_h(&mut h_data, lay.h_off[first + k], &col);' in proto)
    check('let inv = inverses(tv.iter().map(|t| alpha.sub(*t)).collect())?;' in proto)
    check('Some(dc) => {' in cuda[cuda.index('impl DevFzcRounds'):])
    check('k_tab_from_fp2' in cuda[cuda.index('impl DevFzcRounds'):])
    check('host_data: Vec<Fp>' in pcs[pcs.index('pub fn commit_zk_device('):])
    check('crate::gpu::dev_commit_zk_from(params, d_data, rows' in pcs)
    # The pre-existing device-H committer is legacy, not a drop-in tagged call.
    sig=pcs.split('pub fn commit_zk_device(')[1].split('{',1)[0];check('tag:' not in sig)
    check('pcs::commit_zk_owned_tagged(&params, h_data' in proto)
    # Preserve source pins; record drift rather than requiring idle owner files.
    drift=[]
    for pin in json.loads((HERE/'native-pins.json').read_text()):
        cap=(HERE/pin['capture']).read_bytes();check(hashlib.sha256(cap).hexdigest()==pin['sha256'])
        live=Path(pin['source']).read_bytes()
        if hashlib.sha256(live).hexdigest()!=pin['sha256']:
            drift.append(dict(source=pin['source'],captured_sha256=pin['sha256'],current_sha256=hashlib.sha256(live).hexdigest()))
    # New cost accounting uses previous public geometry counts as illustrations.
    prior=HERE.parent/'lookup-borrow-catalog-20261017'
    shifts=json.loads((prior/'public-calibration.json').read_text())['shifts']
    prior_result=json.loads((prior/'result.json').read_text());rows=[];text=(HERE/'native/layout.rs').read_text()
    for row in prior_result['census']:
        t=row['context'];ls=row['ls'];cat=source_catalog(text,4,ls,2,32,t.bit_length()-1+9,shifts)
        check(cat==reference_catalog(4,ls,2,32,t.bit_length()-1+9,shifts))
        all_words=0;source_words=0;affine_source_words=0;helper_words=0
        for dom,lks in cat.items():
            n=row['domains'][dom]['padded_words'];check(row['domains'][dom]['columns']==len(lks))
            unique={p for terms,cst in lks for p,c in terms}
            # Identity field denominators need no integer lift. General affine columns do.
            lift={p for terms,cst in lks if not(cst==0 and len(terms)==1 and terms[0][1]==1) for p,c in terms}
            all_words+=len(lks)*n;source_words+=len(unique)*n;affine_source_words+=len(lift)*n;helper_words+=((len(lks)+1)//2)*n
        sidecar_bytes=sum(((len({p for terms,cst in lks if not(cst==0 and len(terms)==1 and terms[0][1]==1) for p,c in terms})*row['domains'][dom]['padded_words']+63)//64)*8 for dom,lks in cat.items())
        check(all_words*8==row['baseline_looked_bytes'])
        rows.append(dict(model=row['model'],context=t,looked_payload_bytes=8*all_words,prior_borrowed_remaining_bytes=row['remaining_owned_bytes'],H_u8_payload_bytes=16*helper_words,all_lookup_source_plane_words=source_words,affine_source_plane_words=affine_source_words,packed_ambiguity_sidecar_bytes=sidecar_bytes,scope='allocation-free illustrative payload counts using earlier TinyLlama public shifts; 8B shifts hypothetical. Not peak, traffic, speed, fit or profile admission. Sidecar is private, per-proof, never serialized.'))
    p3=HERE.parent/'lookup-borrow-catalog-20261017/retained'
    ceilings=[]
    for arm,elapsed in [('cpu',175.258632),('gpu',161.857226)]:
        data=json.loads((p3/f'r4-{arm}-phases.json').read_text());mark=data['phases']['H: LogUp helper inverses (six lookup domains)']
        ceilings.append(dict(arm=arm,elapsed_s=elapsed,whole_U8_H_parent_s=mark,ideal_whole_parent_deletion_speedup=elapsed/(elapsed-mark),note='22 trained 1.1B blocks, T128, one cold process per arm, shared 16-thread laptop; GPU RTX4070Laptop; reused prior owner clocks, no fresh verifier inspected for these phase samples. Candidate retains arithmetic/work; no native speed estimate.'))
    accounting=dict(rows=rows,ceilings=ceilings,eliminated_here='No production work or transfers eliminated by research experiment.',candidate_costs=['private ambiguity bitmap creation/packing/transfer/lifetime','wrapping u64 reconstruction and integer affine arithmetic','byte-cache/general-inverse fallback and whole-table refusal checks','device error/reduction and fallback handling','tagged device-owned H commitment API or D2H/H2D transfers','all currently CPU H readers and openings still need consistent host data'],limits='Only U8 producer assessed, not exp/activation helper migration or a full H implementation. Existing F device path already reads resident A/H; its scratch expansion is not a host-H upload.')
    (HERE/'accounting.json').write_text(json.dumps(accounting,indent=2)+'\n')
    result=dict(status='PASS',checks=checks,independent_extension_values=ext_words,negative_controls=controls,live_drift=drift,wall_seconds=time.perf_counter()-t0,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,scope='Independent interval/preimage proof, actual FFI sidecar mutations, full-extension exponent oracle, source/payload/parent-clock audit. No native receipt, GPU, privacy or speed acceptance.')
    (HERE/'audit-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2));print('T128 COUNTED',rows[2]);print('CEILINGS',ceilings)

if __name__=='__main__':main()
