#!/usr/bin/env python3
"""Synthetic A-assembly oracle/count study; no native prover or secret data."""
from array import array
from collections import Counter
from pathlib import Path
import hashlib
import json
import os
import platform
import random
import re
import resource
import signal
import struct
import time

HERE = Path(__file__).resolve().parent
P = 2**64 - 2**32 + 1
SEED = 2026100420
RUN = '20261004T020146Z-c40246c9'


def pow2(x):
    return 1 << (x - 1).bit_length()


def source_domains(text, ln, ls, lp):
    """Restricted regex recognizes source data; no eval/foreign execution."""
    part = text.split('let segs:')[1].split('let mut map')[0]
    segs = re.findall(r'\((A_\w+), (\d+|LN_TOY|LS_TOY|LP_TOY), (\d+|ln|ls|lp), Dom::(\w+)\)', part)
    assert len(segs) == 18
    env = {'ln':ln, 'ls':ls, 'lp':lp}
    return [dom for _, _, count, dom in segs for _ in range(int(count) if count.isdigit() else env[count])]


def reference_domains(ln, ls, lp):
    # Independent family catalog, rather than source segment expansion.
    return (['T']*4 + ['Ht']*2 + ['L']*2 + ['D']*(19+4*ln)
            + ['Q']*7 + ['Kv']*6 + ['S']*(5+lp+2*ls) + ['F']*11 + ['Tab']*3)


def sizes(t, d, f, h, kv, dh, n):
    tp, dp, fp, hp = map(pow2, (t,d,f,h))
    natural = {'T':tp,'Ht':hp*tp,'L':16*tp,'D':tp*dp,'Q':tp*hp*dh,
               'Kv':tp*kv*dh,'S':hp*tp*tp,'F':tp*fp,'Tab':256}
    return {dom:(v if dom in ('T','Ht') else max(n,v)) for dom,v in natural.items()}


def plan_for(doms, lengths, n, pairs):
    if n < 256 or n & (n-1) or pairs < 0:
        raise ValueError('public geometry')
    plan=[]; cursor=0
    for p,dom in enumerate(doms):
        length=lengths[dom]
        if length < 1 or length & (length-1):
            raise ValueError('public domain size')
        span=((length+n-1)//n)*n
        used=256 if dom=='Tab' else length
        kind='hist' if dom=='Tab' else 'plane'
        plan.append((cursor,used,kind,p)); cursor+=used
        if span>used:
            plan.append((cursor,span-used,'zero',p)); cursor+=span-used
    mask_base=cursor
    plan.append((cursor,(2*pairs+2)*n,'mask',None));cursor+=(2*pairs+2)*n
    validate(plan,cursor)
    return plan,mask_base,cursor


def validate(plan,total):
    cursor=0
    for start,count,kind,p in plan:
        if start!=cursor or count<=0 or kind not in ('plane','hist','zero','mask'):
            raise ValueError('coverage gap/overlap/kind')
        cursor+=count
    if cursor!=total:
        raise ValueError('coverage end')


def histograms(looked, exp_pairs, act_pairs, exp, act):
    u=[0]*256; e=[0]*256; a=[0]*256
    for v in looked:
        u[v if 0<=v<256 else 0]+=1
    for i,v in exp_pairs:
        e[i if 0<=i<256 and exp[i]==v else 0]+=1
    for i,v in act_pairs:
        a[i if 0<=i<256 and act[i]==v else 0]+=1
    return [u,e,a]


def hist_reference(looked, exp_pairs, act_pairs, exp, act):
    # Membership in independently constructed pair sets, plus Counter.
    exps={(i,v) for i,v in enumerate(exp)}; acts={(i,v) for i,v in enumerate(act)}
    counts=[Counter(v if v in range(256) else 0 for v in looked),
            Counter(i if (i,v) in exps else 0 for i,v in exp_pairs),
            Counter(i if (i,v) in acts else 0 for i,v in act_pairs)]
    return [[c.get(i,0) for i in range(256)] for c in counts]


def from_i64(v):
    # Mirrors native branch with an i128 negative magnitude.
    if not -(1<<63)<=v<(1<<63):
        raise ValueError('outside synthetic i64 fixture')
    return v if v>=0 else (P-((-v)%P))%P


def baseline(doms,lengths,n,pairs,raw,hists,seed):
    if len(raw)!=len(doms) or any(len(raw[p])!=lengths[dom] for p,dom in enumerate(doms) if dom!='Tab'):
        raise ValueError('private block: witness shape')
    offsets=[]; rows=0
    for dom in doms:
        offsets.append(rows*n);rows+=max(1,lengths[dom]//n)
    mask_base=rows*n;total=mask_base+(2*pairs+2)*n
    out=array('Q',[0])*total
    for p,dom in enumerate(doms):
        if dom=='Tab':continue
        for i,v in enumerate(raw[p]):out[offsets[p]+i]=from_i64(v)
    for p,hist in zip(range(len(doms)-3,len(doms)),hists):
        for i,v in enumerate(hist):out[offsets[p]+i]=v%P
    rng=random.Random(seed)
    for i in range(mask_base,total):out[i]=rng.getrandbits(128)%P
    return out,rng.getrandbits(128)


def candidate(plan,total,doms,lengths,raw,hists,seed):
    validate(plan,total)
    if len(raw)!=len(doms) or any(len(raw[p])!=lengths[dom] for p,dom in enumerate(doms) if dom!='Tab'):
        raise ValueError('private block: witness shape')
    out=array('Q');rng=random.Random(seed)
    for start,count,kind,p in plan:
        if len(out)!=start:raise ValueError('append position')
        if kind=='plane':out.extend(from_i64(v) for v in raw[p])
        elif kind=='hist':out.extend(v%P for v in hists[p-len(doms)+3])
        elif kind=='zero':out.extend([0]*count)
        else:out.extend(rng.getrandbits(128)%P for _ in range(count))
        if len(out)!=start+count:raise ValueError('append length')
    return out,rng.getrandbits(128)


def reference(doms,lengths,n,pairs,raw,hists,seed):
    # Row address decoder; no candidate write plan or source offsets.
    owners=[]
    for p,dom in enumerate(doms):
        owners.extend((p,j*n) for j in range(max(1,lengths[dom]//n)))
    out=array('Q')
    for p,base in owners:
        payload=hists[p-len(doms)+3] if doms[p]=='Tab' else raw[p]
        for c in range(n):
            i=base+c
            out.append(payload[i]%P if i<len(payload) else 0)
    rng=random.Random(seed)
    for _ in range((2*pairs+2)*n):out.append(rng.getrandbits(128)%P)
    return out,rng.getrandbits(128)


def digest(words):
    # Explicit little-endian wire-like encoding; this is NOT native proof serialization.
    h=hashlib.sha256()
    for x in words:h.update(struct.pack('<Q',x))
    return h.hexdigest()


def count_case(name,shape,ln,ls,lp,arows,adata,registered,domains):
    t,d,f,h,kv,dh,n=shape; lens=sizes(*shape)
    doms=domains(ln,ls,lp)
    datawords=sum(max(n,lens[dom]) for dom in doms)
    assert datawords==adata*n,(name,datawords,adata*n)
    plane=sum(lens[dom] for dom in doms if dom!='Tab')
    hist=3*256;mask=(arows-adata)*n
    zeros=adata*n-plane-hist
    total=arows*n
    assert total==plane+hist+mask+zeros
    return dict(name=name,shape=dict(T=t,d=d,f=f,H=h,KV=kv,dh=dh,cols=n),registered=registered,
                norm_limbs=ln,softmax_limbs=ls,p_limbs=lp,A_rows=arows,A_data_rows=adata,
                zero_then_scatter_initialization_bytes=8*total,required_zero_bytes=8*zeros,
                logical_overwritten_zero_bytes=8*(plane+hist+mask),witness_copy_bytes=8*plane,
                histogram_bytes=8*hist,fresh_mask_bytes=8*mask,
                final_matrix_bytes=8*total,peak_matrix_capacity_saving_bytes=0,
                actual_zero_store_traffic_bytes=None,actual_time_saved_s=None)


def main():
    signal.alarm(59)
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    os.nice(10)
    affinity=sorted(os.sched_getaffinity(0));os.sched_setaffinity(0,{affinity[0]})
    start=time.monotonic()
    pins=json.loads((HERE/'source-pins.json').read_text())
    for p in pins:
        assert hashlib.sha256((HERE/'snapshots'/p['snapshot']).read_bytes()).hexdigest()==p['sha256']
    layout=(HERE/'snapshots'/pins[1]['snapshot']).read_text()
    protocol=(HERE/'snapshots'/pins[0]['snapshot']).read_text()
    assert 'let mut a_data = vec![Fp::ZERO; lay.a_rows * n];' in protocol
    assert 'for i in 0..U8_LEN' in protocol
    assert 'for x in &mut a_data[lay.a_mask_base * n..]' in protocol
    prehist=protocol.split('let mut a_data = vec![Fp::ZERO; lay.a_rows * n];')[1].split('for x in &mut a_data')[0]
    assert 'rng.' not in prehist and 'tr.' not in prehist
    results=[];controls=[];checked_words=0;checked_zero_words=0;checked_mask_words=0
    fixture_shapes=[(1,4,8,1,1,4,256),(3,12,16,3,1,4,256),
                    (5,16,32,4,2,4,256),(8,24,64,3,1,8,512),
                    (3,12,16,3,1,4,1024),(32,16,16,2,1,8,256)]
    boundaries=[-(1<<63),-(1<<31),-32768,-128,-127,-1,0,1,127,128,255,256,32767,(1<<63)-1]
    for case,(shape,limbs) in enumerate((s,l) for s in fixture_shapes for l in [(4,2,2),(4,3,2),(5,3,2)]):
        ln,ls,lp=limbs;doms=source_domains(layout,ln,ls,lp)
        assert doms==reference_domains(ln,ls,lp)
        lens=sizes(*shape);n=shape[-1];pairs=case%5
        plan,maskbase,total=plan_for(doms,lens,n,pairs)
        rand=random.Random(SEED+case)
        raw=[]
        for p,dom in enumerate(doms):
            if dom=='Tab':raw.append([]);continue
            # Full supplied plane, including internal padding, copied literally.
            raw.append([boundaries[(i+p)%len(boundaries)] if i<28 else rand.randrange(-32768,32768) for i in range(lens[dom])])
        exp=[512-i for i in range(256)];act=[3*i-384 for i in range(256)]
        looked=[-1,0,1,255,256,n-1,-(1<<63),(1<<63)-1]+[rand.randrange(-4,260) for _ in range(300)]
        exp_pairs=[(i,exp[i]) for i in range(256)]+[(-1,0),(256,0),(n-1,0),(42,-999)]
        act_pairs=[(i,act[i]) for i in range(256)]+[(-1,0),(256,0),(n-1,0),(42,-999)]
        hists=histograms(looked,exp_pairs,act_pairs,exp,act)
        assert hists==hist_reference(looked,exp_pairs,act_pairs,exp,act)
        b,bc=baseline(doms,lens,n,pairs,raw,hists,SEED+case)
        c,cc=candidate(plan,total,doms,lens,raw,hists,SEED+case)
        r,rc=reference(reference_domains(ln,ls,lp),lens,n,pairs,raw,hists,SEED+case)
        assert b==c==r and bc==cc==rc
        assert digest(b)==digest(c)==digest(r)
        fresh,_=candidate(plan,total,doms,lens,raw,hists,SEED+case+1000)
        assert fresh[:maskbase]==c[:maskbase] and fresh[maskbase:]!=c[maskbase:]
        zero=sum(count for _,count,kind,_ in plan if kind=='zero')
        masks=total-maskbase
        checked_words+=total;checked_zero_words+=zero;checked_mask_words+=masks
        results.append(dict(case=case,shape=shape,limbs=limbs,pairs=pairs,words=total,
                            required_zero_words=zero,fresh_mask_words=masks,sha256=digest(c),
                            synthetic_rng_continuation=cc))
        # Mutation controls against independently produced reference.
        if case==13:
            def rejected(label,fn):
                try:fn()
                except (ValueError,AssertionError):controls.append(label);return
                raise AssertionError('control did not fail: '+label)
            rejected('missing interval',lambda:validate(plan[:-1],total))
            rejected('duplicate interval',lambda:validate([plan[0]]+plan,total))
            altered=list(plan);q=list(altered[0]);q[0]=1;altered[0]=tuple(q)
            rejected('gap/out-of-range start',lambda:validate(altered,total))
            altered=list(plan);q=list(altered[0]);q[1]=-1;altered[0]=tuple(q)
            rejected('negative count',lambda:validate(altered,total))
            altered=list(plan);q=list(altered[0]);q[2]='reuse-mask';altered[0]=tuple(q)
            rejected('unknown writer',lambda:validate(altered,total))
            bad=list(raw);bad[0]=bad[0][:-1]
            rejected('baseline shape refusal',lambda:baseline(doms,lens,n,pairs,bad,hists,SEED+case))
            rejected('candidate shape refusal',lambda:candidate(plan,total,doms,lens,bad,hists,SEED+case))
            badhist=[h[:-1] for h in hists]
            rejected('histogram length',lambda:candidate(plan,total,doms,lens,raw,badhist,SEED+case))
            for label,index in [('row-tail dirty',next(s for s,k,typ,_ in plan if typ=='zero')),
                                ('table-padding dirty',next(s for s,k,typ,p in plan if typ=='zero' and doms[p]=='Tab')),
                                ('histogram mismatch',next(s for s,k,typ,p in plan if typ=='hist')),
                                ('mask mismatch',maskbase),('proximity mismatch',total-1),
                                ('plane missing',0)]:
                mutated=array('Q',c);mutated[index]=(mutated[index]+1)%P
                rejected(label,lambda mutated=mutated:assert_equal(mutated,r))
            # Force a forbidden widened-table fallback, observable at the histogram row.
            wrong_hists=[list(h) for h in hists];wrong_hists[1][0]-=1;wrong_hists[1][255]+=1
            mutated,_=candidate(plan,total,doms,lens,raw,wrong_hists,SEED+case)
            rejected('widened-table fallback mutation',lambda:assert_equal(mutated,r))
            reused=array('Q',c);reused[maskbase:]=fresh[maskbase:]
            rejected('old-pass mask substitution',lambda:assert_equal(reused,r))
            rejected('RNG continuation mismatch',lambda:assert_equal(cc^1,rc))
    # Dirty storage shrink/grow: every current word must be replaced, capacity tail excluded.
    dirty=array('Q',[P-1])*(max(x['words'] for x in results)+16)
    for length in [len(c),len(c)//2,len(c)]:
        current=array('Q',c[:length]);dirty[:length]=current
        assert dirty[:length]==current
    controls.append('dirty storage shrink/grow current-length overwrite')
    table=json.loads((HERE/'snapshots'/pins[4]['snapshot']).read_text())
    counts=[]
    for name,ln,ls,lp in [('toy',4,2,2),('m125',4,3,2),('mistral_t512_probe',5,3,2),('mistral_t1024_probe',5,3,2)]:
        x=table[name];s=x['shape'];sh=(s['T'],s['d'],s['f'],s['Hheads'],s['KV'],s['dh'],s['cols'])
        counts.append(count_case(name,sh,ln,ls,lp,x['rows']['A'],x['rows']['Adata'],name in ('toy','m125'),lambda a,b,c:source_domains(layout,a,b,c)))
        assert counts[-1]['witness_copy_bytes']==x['witness_A_plane_i64_payload_bytes']
    baseline_report=json.loads((HERE/'snapshots'/pins[5]['snapshot']).read_text())
    phase=json.loads((HERE/'snapshots'/pins[7]['snapshot']).read_text())
    parent=phase['phases_s']['A: allocate + witness planes -> committed rows']
    wall=baseline_report['workload_wall_seconds']
    cpu='unknown'
    for line in Path('/proc/cpuinfo').read_text().splitlines():
        if line.startswith('model name'):cpu=line.split(':',1)[1].strip();break
    result=dict(run_identity=RUN,seed=SEED,status='pass',cases=len(results),checked_field_words=checked_words,
                checked_required_zero_words=checked_zero_words,checked_fresh_mask_words=checked_mask_words,
                controls=controls,control_count=len(controls),cases_detail=results,count_only=counts,
                baseline_parent_ceiling=dict(scope=baseline_report['scope'],independent_verification=False,
                    wall_s=wall,parent_s=parent,parent_fraction=parent/wall,
                    zero_cost_parent_deletion_wall_s=wall-parent,
                    diagnostic_arithmetic_positions_per_s_if_entire_parent_deleted=512/(wall-parent),
                    candidate_time_saved_s=None,note='Parent deletion is not zero-fill savings or counted throughput'),
                elapsed_s=time.monotonic()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                device='CPU only',cpu=cpu,python=platform.python_version(),threads=1,affinity=list(os.sched_getaffinity(0)),
                estimated_memory_mib=64,alarm_s=59,RLIMIT_AS_mib=512,
                script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                scope='Source-pinned synthetic A layout/field/histogram/write coverage; Python PRNG stand-in; no native mask/transcript/commitment/proof',
                full_stack=dict(countable_tokens=0,passes=0,context_length=None,steady_tokens_per_s=None,
                    total_tokens_per_s=None,startup_fraction=None,witness_s=None,proof_s=None,
                    serialization_s=None,verification_s=None,proof_lag_s=None,pipeline_drain_s=None))
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ['status','cases','checked_field_words','checked_required_zero_words','checked_fresh_mask_words','control_count','elapsed_s','peak_rss_kib']},indent=2))


def assert_equal(a,b):
    assert a==b,'differential mismatch'


if __name__=='__main__':main()
