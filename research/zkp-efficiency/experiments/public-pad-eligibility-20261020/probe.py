"""Differential public-constructor, pad-polynomial and dispatch experiment."""
from pathlib import Path
import itertools, json, os, random, resource, struct, time
import model as m
import reference as r

H=Path(__file__).resolve().parent
SEED=20261020100

def enc(v): return b''.join(struct.pack('<Q',x) for x in v)

def main():
    start=time.perf_counter(); rng=random.Random(SEED)
    checks=0; refused=0; pad_cases=0; gate_cases=0; negative=[]
    assert pow(7,(m.P-1)//2,m.P)==m.P-1;checks+=1
    shapes=[('frozen toy',32,16,8,True,'gpu+r9'),
            ('125M',512,2048,14,False,'gpu+r9'),
            ('development rung',24,192,10,False,'gpu+r9')]
    shapes += [('TinyLlama T'+str(t),t,5632,{32:12,64:13,128:14}[t],False,'gpu+r9')
               for t in (32,64,128)]
    shapes += [('8B T'+str(t),t,14336,{32:13,64:13,128:14}[t],False,'gpu+r9' if t==32 else 'r9 only')
               for t in (32,64,128)]
    shapes += [('synthetic P3 lift',1,1,8,False,'synthetic geometry only')]
    zs=[m.Z,m.ONE,(m.P-1,0),(0,1),(1,1),(m.P-1,m.P-1)]
    zs += [(rng.randrange(m.P),rng.randrange(m.P)) for _ in range(58)]
    census=[]
    for name,t,f,lc,toy,lane in shapes:
        entries,padded=m.geometry(t,f,lc)
        assert (entries,padded)==r.geometry(t,f,lc);checks+=1
        seen=set();accepted=0
        for z in zs:
            pad_cases+=1
            try: d=m.descriptor(padded,toy,z)
            except ValueError:
                try:r.descriptor(padded,toy,z)
                except ValueError:refused+=1;continue
                raise AssertionError('one-sided refusal')
            assert d==r.descriptor(padded,toy,z);checks+=1
            seen.add(sum(w!=m.Z for _,w in d));accepted+=1
            # Zero mu is allowed by the existing caller; zero zeta is not.
            for mu in [m.Z,(17,29),(m.P-1,m.P-1)]:
                p=m.params(d,padded and not toy,mu)
                refp=[0]*84
                if d:
                    refp[28:30]=mu
                    for j in range(11):refp[62+2*j:64+2*j]=(r.F(*z)**j).v
                assert enc(p)==enc(refp);checks+=1
                vals=[(rng.randrange(m.P),rng.randrange(m.P)) for _ in range(11)]
                expected=r.pad_value(z,mu,vals) if d else m.Z
                assert m.pad_derived(p,vals)==expected;checks+=1
        census.append(dict(name=name,context_tokens=t,hidden=f,log_cols=lc,
                           cube_entries=entries,support=padded and not toy,
                           reachable_nonzero_pad_counts=sorted(seen),
                           accepted_challenges=accepted,source_scope=lane))
    # Every source-kind and relevant table index, both synthetic base statuses
    # and residency statuses. Independent formulas must agree on each gate.
    base_src=[('Eq',False,False)]*3+[('Base',True,True)]*11+[
              ('Pair',True,False)]*6+[('Public',False,True)]
    defaults=dict(supp=True,split=True,fused=True,raw_switch=True,n=18,tail_log=5,next_round=0)
    gate_grid=[]
    for supp in (False,True):
     src=base_src[:20+supp]
     for t in range(len(src)):
      for kind,dev,bs in itertools.product(('Base','Pair','Eq','Host','Public'),(False,True),(False,True)):
       v=list(src);v[t]=(kind,dev,bs)
       for next_round in (0,1,2):
        kw=dict(defaults,supp=supp,next_round=next_round)
        a=m.gates(v,**kw);b=r.gates(v,**kw)
        assert a==b;checks+=1;gate_cases+=1
    for split,fused,raw_switch,n,tail_log,next_round in itertools.product(
            (False,True),(False,True),(False,True),(2,3,5,6,7,18,21),(0,2,5,20),(0,1,2)):
        kw=dict(defaults,split=split,fused=fused,raw_switch=raw_switch,n=n,tail_log=tail_log,next_round=next_round)
        got=m.gates(base_src,**kw)
        assert got==r.gates(base_src,**kw);checks+=1;gate_cases+=1
        gate_grid.append(dict(**kw,**got))
    def catches(name, bad, good):
        nonlocal checks
        assert bad != good,name
        checks+=1;negative.append(name)
    # Wrong sparse weighting, wrong exponent origin, stale public preparation.
    z=(7,11);mu=(17,29);v=[(j+1,2*j+1) for j in range(11)]
    d=m.descriptor(True,False,z);good=m.pad_derived(m.params(d,True,mu),v)
    for k in (1,3,8):
        catches('drop_pad_planes_'+str(k),m.pad_derived(m.params(d[:k],True,mu),v),good)
    wrong=[(t,m.mul(w,z)) for t,w in d]
    catches('powers_start_at_one',m.pad_derived(m.params(wrong,True,mu),v),good)
    catches('stale_zeta',m.pad_derived(m.params(m.descriptor(True,False,(13,19)),True,mu),v),good)
    catches('stale_mu',m.pad_derived(m.params(d,True,(17,30)),v),good)
    catches('truncate_extension_pad_weights',m.pad_derived(m.params([(t,(w[0],0)) for t,w in d],True,mu),v),good)
    for desc,supp,label in [(d,False,'missing_support'),(d+[d[0]],True,'duplicate_plane'),([(14,m.ONE)],True,'outside_A')]:
        try:m.params(desc,supp,mu)
        except ValueError:negative.append(label);checks+=1
        else:raise AssertionError(label)
    # Fp2 field has no zero divisors, so accepted nonzero zeta powers cannot
    # produce k=1/3/8. Forcing zero bypasses the caller's refusal.
    sparse_zero=[(3,m.ONE)]+[(t,m.Z) for t in range(4,14)]
    catches('accept_zero_zeta_as_sparse',sparse_zero,d)
    assert all(x['reachable_nonzero_pad_counts'] in ([0],[11]) for x in census);checks+=1
    # Remove one dispatch guard at a time: every mutant must be caught.
    assert m.gates(base_src,**defaults)['adapter'];checks+=1
    cases=[('split_off',dict(split=False)),('fused_off',dict(fused=False)),
           ('raw_off',dict(raw_switch=False)),('n_under_three',dict(n=2,tail_log=0)),
           ('tail_boundary',dict(n=6,tail_log=5)),('after_first_fold',dict(next_round=1))]
    for label,kw in cases:
        catches('wrong_adapter_'+label,True,m.gates(base_src,**dict(defaults,**kw))['adapter'])
    for t in range(3,20):
        a=list(base_src);kind,_,bs=a[t];a[t]=(kind,False,bs)
        catches('ignore_residency_table_'+str(t),True,m.gates(a,**defaults)['adapter'])
    for t in list(range(3,14))+[20]:
        a=list(base_src);a[t]=('Public' if t==20 else 'Host',False,False)
        catches('ignore_BASE_table_'+str(t),True,m.gates(a,**defaults)['base'])
    # Helpers are extension-valued by design; BASE must not require them base.
    assert m.gates(base_src,**defaults)['base'];checks+=1
    result=dict(status='PASS_PUBLIC_DESCRIPTOR_AND_GATE_MODEL_ONLY',seed=SEED,
                checks=checks,pad_cases=pad_cases,refused_zero_zeta=refused,
                gate_cases=gate_cases,negative_controls=len(negative),
                reachable_native_pad_counts=[0,11],
                wall_seconds=time.perf_counter()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                threads=1,affinity=sorted(os.sched_getaffinity(0)),
                full_stack=dict(proofs=0,passes=0,positions=0,context_length=None,device=None,
                  witness_s=None,proof_s=None,serialization_s=None,verification_s=None,
                  startup_fraction=None,steady_rate=None,total_rate=None),
                scope='Source-backed structural census plus synthetic public coefficients/gates; no native or GPU execution, private witness/masks/transcript/PCS/receipt/verifier')
    (H/'census.json').write_text(json.dumps(census,indent=2)+'\n')
    (H/'gate-grid.json').write_text(json.dumps(gate_grid,indent=2)+'\n')
    (H/'negative-controls.json').write_text(json.dumps(negative,indent=2)+'\n')
    (H/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
