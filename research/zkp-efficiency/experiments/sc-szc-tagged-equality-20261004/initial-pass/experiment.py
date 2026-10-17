#!/usr/bin/env python3
"""Seeded, CPU-light synthetic prerequisite. This does not produce a proof."""
import copy, hashlib, itertools, json, os, platform, random, resource, signal, time
from pathlib import Path
from field_support import F, P
from candidate import TaggedRounds, private_table, bracket
import oracle

HERE=Path(__file__).resolve().parent
SEED=2026100430

def fixture(n,mode,variant,rng):
    def draw():
        if mode=='zero': return F()
        return F(rng.randrange(-32768,32768),rng.randrange(P) if mode=='full' else 0)
    eqs=[]
    spans=[(0,n),(n,0),(n//2,n-n//2)]
    for s,length in spans:
        point=[F(rng.randrange(P),rng.randrange(P)) for _ in range(length)]
        if mode=='zero': point=[F(0) for _ in point]
        eqs.append({'kind':'Eq','start':s,'point':point})
    coords=[]
    if n:
        coords.append(('Flip',n-1))
        if n>1: coords.append(('Rho',0))
    coords.insert(0,('Fixed',F(0) if mode=='zero' else F(3,7)))
    coords.append(('Fixed',F(1) if mode=='zero' else F(9,11)))
    size=1<<len(coords)
    source=[F(rng.randrange(-32768,32768)) for _ in range(2*size+3)]
    priv={'kind':'Priv','source':source,'coords':coords,'slices':[(1,F(1)),(size+2,F(0,1))]}
    simple={'kind':'Priv','source':[F(rng.randrange(-32768,32768)) for _ in range(1<<n)],
            'coords':[('Rho',k) for k in reversed(range(n))],'slices':[(0,F(1))]}
    pub={'kind':'Pub','words':[draw() for _ in range(1<<n)]}
    tabs=eqs+[priv,simple,pub]
    if variant: rng.shuffle(tabs)
    data=[i for i,t in enumerate(tabs) if t['kind']!='Eq']; groups=[]
    for g,i in enumerate(i for i,t in enumerate(tabs) if t['kind']=='Eq'):
        d=1+(g+variant)%4
        terms=[(F(2+g,3+variant),tuple(data[(j+g)%len(data)] for j in range(d))),
               (F(-4-g),tuple([data[-1]])),(F(5),tuple())]
        groups.append((i,terms))
    challenges=[F(0) if mode=='zero' else F(rng.randrange(P),rng.randrange(P)) for _ in range(n)]
    return tabs,groups,challenges

def main():
    started=time.perf_counter(); signal.alarm(59)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59)); resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))}); os.nice(10)
    rng=random.Random(SEED); digest=hashlib.sha256(); cases=[]
    initial_checks=round_checks=final_checks=extension_checks=count_checks=0
    controls=[]
    for n,mode,variant in itertools.product((0,1,2,3,5),('base','full','zero'),(0,1)):
        tabs,groups,challenges=fixture(n,mode,variant,rng); degree=5
        original=[oracle.table(tab,n) for tab in tabs]
        cand=TaggedRounds(tabs,n,degree,groups)
        for i,slot in enumerate(cand.slots):
            if isinstance(slot,list):
                assert [oracle.tup(v) for v in slot]==original[i],('source map',n,mode,variant,i)
                initial_checks+=len(slot)
        prefix=[]
        for j,r in enumerate(challenges):
            got=cand.round(j)
            for t,v in enumerate(got):
                assert oracle.tup(v)==oracle.round_direct(original,groups,prefix,t,n),('original cube',n,mode,variant,j,t)
                round_checks+=1; digest.update(v.wire())
            cand.fold(r); prefix.append(oracle.tup(r))
        finals=cand.finals()
        assert list(map(oracle.tup,finals))==[oracle.mle(a,prefix) for a in original]
        final_checks+=len(finals)
        # Synthetic extension-polynomial compatibility at every degree sample.
        # Eq/Pub extensions are zero; private terminal perturbations remain.
        exts=[draw_extension(rng) if tab['kind']=='Priv' else F() for tab in tabs]
        for t in range(degree+1):
            words=[v+F(t)*(e-v) for v,e in zip(finals,exts)]
            expected=oracle.poly(groups,[oracle.add(v,oracle.mul((t,0),oracle.sub(oracle.tup(e),v)))
                                        for v,e in zip([oracle.mle(a,prefix) for a in original],exts)])
            value=sum((words[i]*bracket(terms,words) for i,terms in groups),F())
            assert oracle.tup(value)==expected; extension_checks+=1
        k=sum(tab['kind']!='Eq' for tab in tabs); q=len(tabs)-k
        assert cand.initial_data_entries==k*(1<<n)
        assert cand.data_fold_ops==k*((1<<n)-1)
        assert cand.eq_scalar_ops==sum(len(t['point']) for t in tabs if t['kind']=='Eq')
        count_checks+=3
        cases.append({'n':n,'mode':mode,'shuffled':bool(variant),'tables':len(tabs),'data_tables':k,'eq_tables':q,
                      'eq_spans':[{'start':t['start'],'length':len(t['point'])} for t in tabs if t['kind']=='Eq'],
                      'data_entries':cand.initial_data_entries,'data_fold_ops':cand.data_fold_ops,
                      'eq_scalar_ops':cand.eq_scalar_ops,'recoveries':cand.recoveries,'zero_fallbacks':cand.zero_fallbacks})

    def reject(name,fn):
        try: fn()
        except (ValueError,AssertionError,IndexError) as e: controls.append({'name':name,'detected':str(e)}); return
        raise AssertionError(('missing rejection',name))
    tabs,groups,ch=fixture(3,'full',1,rng)
    def altered(mutate):
        t,g=copy.deepcopy(tabs),copy.deepcopy(groups);mutate(t,g);return TaggedRounds(t,3,5,g)
    ei=next(i for i,t in enumerate(tabs) if t['kind']=='Eq' and t['point'])
    pi=next(i for i,t in enumerate(tabs) if t['kind']=='Priv' and len(t['coords'])<5)
    ui=next(i for i,t in enumerate(tabs) if t['kind']=='Pub')
    reject('equality span overflow',lambda:altered(lambda t,g:t[ei].update(start=4)))
    reject('negative equality start',lambda:altered(lambda t,g:t[ei].update(start=-1)))
    reject('short public table',lambda:altered(lambda t,g:t[ui].update(words=t[ui]['words'][:-1])))
    reject('short private source',lambda:altered(lambda t,g:t[pi].update(source=[])))
    reject('duplicate moving coords outside schedule',lambda:altered(lambda t,g:t[pi].update(coords=[('Rho',0),('Flip',0)])))
    reject('moving coordinate overflow',lambda:altered(lambda t,g:t[pi].update(coords=[('Rho',3)])))
    reject('Eq role in bracket',lambda:altered(lambda t,g:g[0][1].append((F(1),(ei,)))))
    reject('data role as group factor',lambda:altered(lambda t,g:g.__setitem__(0,(ui,g[0][1]))))
    reject('underdeclared degree',lambda:TaggedRounds(tabs,3,1,groups))
    fresh=TaggedRounds(tabs,3,5,groups)
    reject('finals before folds',fresh.finals)
    reject('fold before round',lambda:fresh.fold(ch[0]))
    reject('wrong round index',lambda:fresh.round(1))
    fresh.round(0); reject('second pending round',lambda:fresh.round(0))
    expected=[oracle.table(t,3) for t in tabs]
    ref_round=[oracle.round_direct(expected,groups,[],t,3) for t in range(6)]
    def mismatch(name,mutate):
        tt=copy.deepcopy(tabs); mutate(tt); got=TaggedRounds(tt,3,5,groups).round(0)
        assert list(map(oracle.tup,got))!=ref_round,name
        controls.append({'name':name,'detected':'independent original-cube mismatch'})
    mismatch('changed Eq point owner',lambda tt:tt[ei]['point'].__setitem__(0,tt[ei]['point'][0]+1))
    mismatch('changed private source owner',lambda tt:tt[pi]['source'].__setitem__(1,tt[pi]['source'][1]+1))
    mismatch('dirty public/padding value retained',lambda tt:tt[ui]['words'].__setitem__(-1,tt[ui]['words'][-1]+1))
    def reverse(tt): tt[ui]['words']=[tt[ui]['words'][int(f'{i:03b}'[::-1],2)] for i in range(8)]
    mismatch('LSB permutation instead of MSB',reverse)
    # Compaction preserving only relative data order loses original polynomial indices.
    bad=list(range(len(tabs)));bad[ei],bad[ui]=bad[ui],bad[ei]
    original_final=[oracle.mle(a,list(map(oracle.tup,ch))) for a in expected]
    assert [original_final[i] for i in bad]!=original_final
    controls.append({'name':'compacted/swapped final indices','detected':'direct MLE final-order mismatch'})
    projections=[]
    for n in (20,22,23,25):
        projections.append({'n':n,'illustrative_data_tables':23,'eq_tables':3,
                            'removed_eq_capacity_bytes':3*16*(1<<n),
                            'removed_eq_fold_mul_add_sub_each':3*((1<<n)-1),
                            'added_eq_scalar_multiplications_max':3*n,
                            'extra_data_source_scans':0,'capacity_fraction_of_K23_plus3':3/26,
                            'remaining_data_capacity_bytes':23*16*(1<<n),
                            'scope':'count only; sources/split scratch/metadata/PCS/masks/allocator/parent peak excluded'})
    result={'run_id':'20261004T120146Z-d7433b90','seed':SEED,'status':'pass','fixture_count':len(cases),
            'source_map_word_checks':initial_checks,'independent_original_cube_round_samples':round_checks,
            'independent_original_cube_final_values':final_checks,'synthetic_extension_degree_samples':extension_checks,
            'analytic_count_checks':count_checks,'controls':controls,'control_count':len(controls),'cases':cases,
            'count_only_projection':projections,'round_digest_sha256':digest.hexdigest(),
            'elapsed_seconds':time.perf_counter()-started,'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            'hardware':{'cpu':next((line.split(':',1)[1].strip() for line in Path('/proc/cpuinfo').read_text().splitlines() if line.startswith('model name')),'unknown'),
                        'device':'CPU only','threads':1,'affinity':sorted(os.sched_getaffinity(0)),'nice':os.getpriority(os.PRIO_PROCESS,0),'python':platform.python_version(),'platform':platform.platform()},
            'resources':{'wall_cap_seconds':59,'cpu_cap_seconds':59,'address_space_cap_mib':512,'estimated_memory_mib':64},
            'hashes':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in HERE.glob('*.py')},
            'proof_accounting':{'accepted_complete_private8b_proofs':0,'countable_tokens':0,'context_length':None,'passes':0,
                                'steady_state_tokens_per_s':None,'total_workload_tokens_per_s':None,'startup_fraction':None,
                                'startup_seconds':None,'witness_seconds':None,'proof_seconds':None,'serialization_seconds':None,
                                'independent_verification_seconds':None,'proof_latency_seconds':None,'proof_lag_seconds':None,
                                'pipeline_drain_seconds':None,'prefill':'none','resident_passes':'none','decode':'none'},
            'limits':['Synthetic tagged polynomial storage/reader gate, not native SC_SZC closure/IR execution',
                      'Tuple-field original-cube oracle independently evaluates all rounds/finals; shared candidate field helper is not an independent field library',
                      'Synthetic extension algebra only; actual native mask/RNG/transcript/extension/refusal/PCS/receipt/privacy not tested',
                      'Data vectors remain fully materialized; retained A/H/public gates are not removed; logical counts are not Rust/GPU peak/time',
                      'Duplicate moving coordinates rejected as outside native schedule prerequisite, not claimed to reproduce legacy malformed-reader behavior',
                      'No real private data, native build, GPU job, imported implementation or accepted proof']}
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ('cases','controls','count_only_projection')},indent=2))

def draw_extension(rng): return F(rng.randrange(P),rng.randrange(P))
if __name__=='__main__': main()
