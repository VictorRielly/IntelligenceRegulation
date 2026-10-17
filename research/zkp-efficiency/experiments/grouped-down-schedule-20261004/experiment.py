#!/usr/bin/env python3
"""Public FFN-down schedule/ownership model, synthetic data, CPU only."""
import collections
from dataclasses import dataclass, replace
import hashlib
import json
import os
from pathlib import Path
import random
import resource
import signal
import time

ROOT = Path(__file__).resolve().parent
RUN = '20261004T060146Z-96d1ccac'
SEED = 2026100424


def checked(v, bits):
    assert -(1 << (bits-1)) <= v < (1 << (bits-1)), ('overflow', bits)
    return v


def reference(x, w, m, kp, n, mp, np, mode, shift=6, x1=None):
    """Direct wide dots and independent divmod rounding, no descriptors/packing."""
    raw, y, rem = {}, [0]*(mp*np), [0]*(mp*np)
    failures = []
    divisor, half = 2**shift, 0 if shift == 0 else 2**(shift-1)
    for t in range(m):
        for j in range(n):
            z = 0
            for k in range(kp):
                wi = k*np+j if mode == 'in_out' else j*kp+k
                z = checked(z + checked(x[t*kp+k]*w[wi], 64), 64)
            ix = t*np+j
            raw[ix] = z
            q, r = divmod(z+half, divisor)
            y[ix], rem[ix] = q, r
            if not -32768 <= q <= 32767:
                failures.append(ix)
    if failures:
        return raw, {'refusal':'FFN down', 'first_index':min(failures)}
    if x1 is not None:
        out = [0]*(mp*np)
        for t in range(m):
            for j in range(n):
                ix = t*np+j
                out[ix] = x1[ix]+y[ix]
                if not -32768 <= out[ix] <= 32767:
                    return raw, {'refusal':'residual 2', 'first_index':ix}
        return raw, {'y':y,'rem':rem,'x2':out}
    return raw, {'y':y,'rem':rem}


@dataclass(frozen=True)
class Descriptor:
    t0: int
    rows: int
    j0: int
    cols: int
    k0: int
    width: int
    epoch: int
    slot: int
    c_offset: int


def validate_batch(ds, live_epoch, max_words):
    assert ds and len({(2*d.rows,d.cols,d.width) for d in ds}) == 1, 'mixed shape'
    seen, outputs = set(), set()
    for d in ds:
        assert d.epoch == live_epoch, 'stale packed input'
        assert d.slot not in seen, 'duplicate slot'
        seen.add(d.slot)
        addresses = set(range(d.c_offset, d.c_offset+2*d.rows*d.cols))
        assert not addresses & outputs, 'overlap'
        outputs |= addresses
        assert 0 <= d.c_offset and max(addresses) < max_words, 'bounds'


def pack_input(x, t0, rows, k0, width, kp):
    low, high = [], []
    for t in range(t0,t0+rows):
        for k in range(k0,k0+width):
            value = checked(x[t*kp+k],16)
            low.append((value & 255)-128)
            high.append(value >> 8)
    return low+high


def gemm(packed, w, d, kp, np, mode):
    # Row-major model. Native mapping must swap operands/dimensions or use
    # explicit column-major leading dimensions; this is NOT a cuBLAS call.
    partials = [0]*(2*d.rows*d.cols)
    for r in range(2*d.rows):
        for j in range(d.cols):
            z = 0
            for k in range(d.width):
                wi = (d.k0+k)*np+d.j0+j if mode == 'in_out' else (d.j0+j)*kp+d.k0+k
                z = checked(z + packed[r*d.width+k]*w[wi],32)
            partials[r*d.cols+j] = z
    return partials


def column_major_oracle(packed,w,d,kp,np,mode,mutant=None):
    """Independently emulate BLAS C^T=W^T*packed^T by physical addresses.

    For in_out: opA=N, lda=np, A0=k0*np+j0. For out_in:
    opA=T, lda=kp, A0=j0*kp+k0. opB=N, ldb=width.
    BLAS m=cols, n=2*rows, k=width, ldc=cols; alpha i32=1,beta=0.
    This addresses oracle does not establish device algorithm support.
    """
    lda = np if mode=='in_out' else kp
    base = d.k0*np+d.j0 if mode=='in_out' else d.j0*kp+d.k0
    ldb,ldc = d.width,d.cols
    if mutant=='wrong_lda': lda = d.cols if mode=='in_out' else d.width
    out=[0]*(ldc*2*d.rows)
    for col in range(2*d.rows):
        for row in range(d.cols):
            value=0
            for inner in range(d.width):
                a=base+row+inner*lda if mode=='in_out' else base+inner+row*lda
                value += w[a]*packed[inner+col*ldb]
            out[row+col*ldc]=checked(value,32)
    return out


def necessary_integer_api_layout(d,kp,np,mode):
    # Current documented hard conditions only; NOT sufficient for IMMA or
    # a particular device/algorithm. Unsupported public geometry -> fallback.
    lda=np if mode=='in_out' else kp
    base=d.k0*np+d.j0 if mode=='in_out' else d.j0*kp+d.k0
    return base%4==0 and lda%4==0 and d.width%4==0


class Ownership:
    def __init__(self):
        self.epoch = 0
        self.pending = set()
        self.pack_live = False

    def pack(self):
        assert not self.pending and not self.pack_live, 'repack before consumers drain'
        self.epoch += 1
        self.pack_live = True

    def launch(self, ds):
        assert self.pack_live and not self.pending, 'pool reused while live'
        self.pending = {d.slot for d in ds}

    def consume(self, d):
        assert d.epoch == self.epoch and d.slot in self.pending, 'duplicate/stale completion'
        self.pending.remove(d.slot)

    def release_pack(self):
        assert self.pack_live and not self.pending, 'release before drain'
        self.pack_live = False


def candidate(x,w,m,kp,n,mp,np,mode,mt,nt,kt,q,order,seed,shift=6,x1=None):
    assert min(mt,nt,kt,q)>0 and min(kt,kp)*16384 <= (1<<31)-1
    rng = random.Random(seed)
    y, rem, raw = [0]*(mp*np), [0]*(mp*np), {}
    failures, coverage, written, trace = [], collections.Counter(), set(), []
    sums = [sum(w[k*np+j if mode=='in_out' else j*kp+k] for k in range(kp)) for j in range(n)]
    row_starts = list(range(0,m,mt))
    if order == 'reverse': row_starts.reverse()
    if order == 'shuffle': rng.shuffle(row_starts)
    stats = dict(packed_values=0,gemm_problems=0,batch_calls=0,peak_local_bytes=0,
                 reduction_writes=0,completion_checks=0,column_major_words=0,
                 necessary_integer_api_layout_pass=0,necessary_integer_api_layout_fail=0)
    owner = Ownership()
    final_bytes = 16*mp*np
    for t0 in row_starts:
        rows = min(mt,m-t0)
        accum = [0]*(rows*n) if kt < kp else None
        # K-first permits ONE pack per row/K tile across ALL output batches.
        # Cost: split-K retains full-width row accumulation until all K drains.
        for k0 in range(0,kp,kt):
            width = min(kt,kp-k0)
            owner.pack()
            packed = pack_input(x,t0,rows,k0,width,kp)
            stats['packed_values'] += len(packed)
            by_size = collections.defaultdict(list)
            for j0 in range(0,n,nt): by_size[min(nt,n-j0)].append(j0)
            for cols, starts in by_size.items():
                if order == 'reverse': starts.reverse()
                if order == 'shuffle': rng.shuffle(starts)
                for begin in range(0,len(starts),q):
                    js = starts[begin:begin+q]
                    ds = [Descriptor(t0,rows,j0,cols,k0,width,owner.epoch,s,
                                     s*2*rows*cols) for s,j0 in enumerate(js)]
                    validate_batch(ds,owner.epoch,len(ds)*2*rows*cols)
                    owner.launch(ds)
                    # All output slots exist simultaneously before any completion.
                    pool = {d.slot:gemm(packed,w,d,kp,np,mode) for d in ds}
                    for d in ds:
                        assert pool[d.slot]==column_major_oracle(packed,w,d,kp,np,mode)
                        stats['column_major_words'] += len(pool[d.slot])
                        key='necessary_integer_api_layout_'+('pass' if necessary_integer_api_layout(d,kp,np,mode) else 'fail')
                        stats[key] += 1
                    local_bytes = final_bytes+len(packed)+sum(4*len(p) for p in pool.values())
                    if accum is not None: local_bytes += 8*len(accum)
                    stats['peak_local_bytes'] = max(stats['peak_local_bytes'],local_bytes)
                    stats['gemm_problems'] += len(ds)
                    stats['batch_calls'] += 1
                    completion = list(ds)
                    if order == 'reverse': completion.reverse()
                    if order == 'shuffle': rng.shuffle(completion)
                    for d in completion:
                        parts = pool.pop(d.slot)
                        for r in range(rows):
                            for j in range(cols):
                                loc, ix = r*n+d.j0+j, (t0+r)*np+d.j0+j
                                coverage[(ix,k0)] += 1
                                z = checked(parts[r*cols+j]+256*parts[(rows+r)*cols+j],64)
                                if accum is not None:
                                    accum[loc] = checked(accum[loc]+z,64)
                                    stats['reduction_writes'] += 1
                                    if k0+width < kp: continue
                                    z = accum[loc]
                                z = checked(z+128*sums[d.j0+j],64)
                                raw[ix] = z
                                half = 0 if shift==0 else 1<<(shift-1)
                                value = (z+half)>>shift
                                y[ix], rem[ix] = value, z-(value<<shift)+half
                                if not -32768<=value<=32767: failures.append(ix)
                                assert ix not in written, 'duplicate output'
                                written.add(ix)
                        owner.consume(d)
                        stats['completion_checks'] += 1
                    assert not pool and not owner.pending
                    trace.append([(d.t0,d.rows,d.j0,d.cols,d.k0,d.width,d.slot,d.c_offset) for d in ds])
            owner.release_pack()
    support = {t*np+j for t in range(m) for j in range(n)}
    assert written == support
    assert coverage == collections.Counter({(ix,k0):1 for ix in support for k0 in range(0,kp,kt)})
    assert stats['packed_values'] == 2*m*kp
    if failures:
        result = {'refusal':'FFN down','first_index':min(failures)}
    elif x1 is not None:
        out, bad = [0]*(mp*np), None
        for ix in sorted(support):
            out[ix] = x1[ix]+y[ix]
            if not -32768<=out[ix]<=32767 and bad is None: bad=ix
        result = {'refusal':'residual 2','first_index':bad} if bad is not None else {'y':y,'rem':rem,'x2':out}
    else: result={'y':y,'rem':rem}
    return raw,result,stats,trace


def reject(label, action, controls):
    try: action()
    except AssertionError as e:
        controls.append({'name':label,'detected':str(e)}); return
    raise AssertionError('nondiscriminating control: '+label)


def ledger(mt,nt,kt,q,m=512,k=16384,n=4096):
    bm,bn,bk = (m+mt-1)//mt,(n+nt-1)//nt,(k+kt-1)//kt
    r,c,z = min(mt,m), min(nt,n), min(kt,k)
    slots=min(q,bn)
    parts=8*r*c*slots
    packing=2*r*z
    reduction=8*r*n if kt<k else 0
    return dict(tile=[mt,nt,kt],q=q,final_bytes=16*m*n,
                peak_payload_bytes=16*m*n+packing+parts+reduction,
                batch_calls=bm*bk*((bn+q-1)//q),gemm_problems=bm*bn*bk,
                pack_bytes=2*m*k,old_split_pack_bytes=2*m*k*bn if kt<k else 2*m*k,
                reduction_bytes=reduction,logical_weight_bytes=bm*k*n,
                byte_products=2*m*k*n,
                limits='one tier; no workspace, descriptors/status, transfers, pools, inputs/weights/other planes')


def main():
    signal.alarm(59)
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    resource.setrlimit(resource.RLIMIT_CPU,(59,59))
    os.nice(10)
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    start=time.monotonic(); rng=random.Random(SEED)
    schedules, dots, words, outcomes, digest = 0,0,0,collections.Counter(),hashlib.sha256()
    aggregate=collections.Counter()
    dims=[(1,1,1,2,4,4),(3,5,5,4,8,8),(5,17,7,8,32,8),(3,31,9,4,32,16)]
    for trial in range(24):
        m,k,n,mp,kp,np=dims[trial%len(dims)]
        x=[rng.choice((-32768,32767)) if trial%3==0 else rng.randint(-900,900) for _ in range(mp*kp)]
        w=[rng.choice((-128,127)) if trial%3==0 else rng.randint(-7,7) for _ in range(kp*np)]
        # Internal K padding is consumed; token padding is not.
        for t in range(m,mp): x[t*kp:(t+1)*kp]=[99999]*kp
        x1=[rng.choice((-32768,32767,0)) for _ in range(mp*np)]
        for mode in ('in_out','out_in'):
            wm=w if mode=='in_out' else [w[i*np+j] for j in range(np) for i in range(kp)]
            ref_raw,ref=reference(x,wm,m,kp,n,mp,np,mode,x1=x1)
            for mt,nt,kt,q in [(1,1,kp,1),(2,3,3,2),(3,4,7,4),(64,128,kp,32)]:
                traces=[]
                for order in ('forward','reverse','shuffle'):
                    raw,res,stats,trace=candidate(x,wm,m,kp,n,mp,np,mode,mt,nt,kt,q,order,SEED+trial,x1=x1)
                    assert raw==ref_raw and res==ref,(trial,mode,mt,nt,kt,q,order)
                    traces.append(trace)
                    schedules+=1; dots+=len(raw); outcomes[res.get('refusal','accepted')]+=1
                    if 'y' in res: words+=len(res['y'])+len(res['rem'])
                    for key,value in stats.items(): aggregate[key]+=value
                    digest.update(json.dumps([raw,res],sort_keys=True).encode())
                # Public descriptor plan is independent of changed private values.
                _,_,_,other=candidate([0]*(mp*kp),wm,m,kp,n,mp,np,mode,mt,nt,kt,q,'forward',SEED+trial)
                assert traces[0]==other
    controls=[]
    d=Descriptor(0,2,0,4,0,8,1,0,0); e=replace(d,slot=1,j0=4,c_offset=16)
    reject('overlapping output buffers',lambda:validate_batch([d,replace(e,c_offset=8)],1,32),controls)
    reject('duplicate output slot',lambda:validate_batch([d,replace(e,slot=0)],1,32),controls)
    reject('stale packed epoch',lambda:validate_batch([replace(d,epoch=0)],1,16),controls)
    reject('ragged shape mixed in uniform batch',lambda:validate_batch([d,replace(e,cols=3)],1,32),controls)
    reject('output exceeds pool',lambda:validate_batch([d,e],1,31),controls)
    owner=Ownership(); owner.pack(); owner.launch([d,e])
    reject('repack before outstanding completion',owner.pack,controls)
    reject('release pack before outstanding completion',owner.release_pack,controls)
    reject('reuse output pool before drain',lambda:owner.launch([d,e]),controls)
    owner.consume(e)
    reject('duplicate completion',lambda:owner.consume(e),controls)
    reject('stale completion',lambda:owner.consume(replace(d,epoch=0)),controls)
    owner.consume(d); owner.release_pack()
    # Numerical controls must change an independently computed answer.
    x,w=[128,128],[1,1]
    raw,ref=reference(x,w,1,2,1,1,1,'in_out')
    assert raw[0]==256 and ref['y']==[4]
    wrong=128*((x[0]>>8)+(x[1]>>8)) # dropped low and correction
    assert wrong!=raw[0]; controls.append({'name':'omit low/offset reconstruction','expected':raw[0],'wrong':wrong})
    failures=[5,1]; assert failures[0]!=min(failures)
    controls.append({'name':'first completed failure replaces support order','expected':1,'wrong':5})
    # A down failure outranks residual even if residual finishes earlier.
    _,ref=reference([64],[1,127],1,1,2,1,2,'in_out',shift=0,x1=[32767,0])
    assert ref['refusal']=='residual 2'
    _,ref2=reference([32767],[1,127],1,1,2,1,2,'in_out',shift=0,x1=[32767,0])
    assert ref2['refusal']=='FFN down'
    controls.append({'name':'early residual outranks later down','expected':ref2['refusal'],'wrong':'residual 2'})
    # Unique nonconstant weights make incorrect tile-local lda discriminate.
    dd=Descriptor(0,2,4,4,4,4,1,0,0)
    xx=list(range(-17,15)); ww=list(range(-64,64))
    pp=pack_input(xx,0,2,4,4,16)
    assert column_major_oracle(pp,ww,dd,16,8,'in_out')==gemm(pp,ww,dd,16,8,'in_out')
    assert column_major_oracle(pp,ww,dd,16,8,'in_out','wrong_lda')!=gemm(pp,ww,dd,16,8,'in_out')
    controls.append({'name':'tile width used as physical weight lda','detected':'different exact byte outputs'})
    assert necessary_integer_api_layout(dd,16,8,'in_out')
    assert not necessary_integer_api_layout(replace(dd,j0=3),16,8,'in_out')
    assert not necessary_integer_api_layout(replace(dd,width=3),16,8,'in_out')
    controls.extend([{'name':'unaligned weight view','detected':'public CPU fallback required'},
                     {'name':'nonmultiple-four packed leading dimension','detected':'public CPU fallback required'}])
    rows=[ledger(64,4096,16384,1),ledger(64,128,16384,1),ledger(64,128,16384,4),
          ledger(64,128,16384,32),ledger(128,4096,16384,1),ledger(256,4096,16384,1),
          ledger(512,4096,16384,1),ledger(64,128,1024,1),ledger(64,128,1024,4),ledger(64,128,1024,32)]
    assert rows[0]['peak_payload_bytes']==36*1024**2
    assert rows[3]['peak_payload_bytes']==rows[0]['peak_payload_bytes']
    assert rows[3]['batch_calls']==rows[0]['batch_calls']==8
    assert rows[8]['pack_bytes']*32==rows[8]['old_split_pack_bytes']
    out=dict(run_identity=RUN,seed=SEED,status='pass',schedules=schedules,
             independent_raw_dots=dots,accepted_plane_words=words,outcomes=dict(outcomes),
             controls=controls,control_count=len(controls),synthetic_counters=dict(aggregate),
             count_only_public_unadmitted_8b_T512=rows,digest=digest.hexdigest(),
             elapsed_s=time.monotonic()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
             threads=1,affinity=list(os.sched_getaffinity(0)),device='CPU only',
             estimated_memory_mib=64,RLIMIT_AS_mib=512,alarm_s=59,
             script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
             cpu=next(l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),
             scope='synthetic scheduling/ownership/arithmetic; no cuBLAS/CUDA/native witness/PCS/RNG/transcript/proof',
             actual_gpu_speedup=None,actual_end_to_end_saved_s=None,
             full_stack=dict(countable_tokens=0,passes=0,context_length=None,steady_tokens_per_s=None,
                 total_tokens_per_s=None,startup_fraction=None,witness_s=None,proof_s=None,serialization_s=None,
                 verification_s=None,proof_latency_s=None,proof_lag_s=None,pipeline_drain_s=None))
    (ROOT/'result.json').write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps({k:v for k,v in out.items() if k not in ('controls','count_only_public_unadmitted_8b_T512','full_stack')},indent=2))


if __name__=='__main__': main()
