#!/usr/bin/env python3
"""Bounded synthetic original-cube checks and split-Eq preparation accounting."""
import copy,hashlib,json,os,platform,random,resource,time
from collections import Counter
from pathlib import Path
from field import F,P
from driver import Dense,Tables,interpolate,extend
from grouped import Group,Grouped
from cached_grouped import CachedGrouped
from suffix_cache import SuffixCache,accounting
from fixture import fixtures,original_partial,limits
from source_port import bracket
import full_oracle as o

HERE=Path(__file__).resolve().parent
RUN='20261012T222555Z-e2cb7a5e'
SEED=2026101241

def original_group_rounds(originals,ir,prefix,n,xs):
    out=[[] for _ in ir]
    for x in xs:
        vals=original_partial(originals,prefix+[(x,0)],n)
        for g,terms in enumerate(ir):
            value=o.Z
            for i in range(len(vals[0])):
                value=o.add(value,o.mul(vals[g][i],o.bracket(terms,[a[i] for a in vals])))
            out[g].append(F(*value))
    return out

def main():
    limits();begin=time.perf_counter();rng=random.Random(SEED)
    counts=Counter();controls=[];digest=hashlib.sha256();cost_rows=[];saved=None
    # Direct coordinate products, independent schoolbook tuple arithmetic:
    # check every Boolean suffix position, short/interior/empty supports.
    for n in range(9):
        specs={(0,0),(0,n),(n,0),(n//2,n-n//2),(0,n//2),(1,max(0,n-2))} if n else {(0,0)}
        specs={(s,l) for s,l in specs if s<=n and l<=n-s}
        for start,length in sorted(specs):
            for mode in ('full','base','boolean','zero'):
                point=[F(rng.randrange(P),rng.randrange(P)) if mode=='full' else
                       F(rng.randrange(P)) if mode=='base' else F(rng.randrange(2)) if mode=='boolean' else F()
                       for _ in range(length)]
                cache=SuffixCache(point,start,n);model=accounting(n,start,length)
                assert cache.counts['entries_built']==model['cache_entries_built']
                assert cache.counts['build_multiplications']==model['cache_build_multiplications']
                assert cache.retained()==model['cache_peak_entries']
                retained=[]
                for j in range(n):
                    left,right,suffix,trailing=cache.pair(j,point,start)
                    consumed=min(max(j+1-start,0),length)
                    for i in range(1<<(n-j-1)):
                        pos=(i>>trailing)&((1<<suffix)-1)
                        actual=left[pos//len(right)]*right[pos%len(right)]
                        expected=o.eq(list(map(o.tup,point[consumed:])),[(b,0) for b in o.bits(pos,suffix)])
                        assert actual==F(*expected),('suffix',n,start,length,j,i,mode)
                        counts['independent_suffix_weights']+=1
                    cache.finish_round(j);retained.append(cache.retained())
                assert cache.terminal()==1 and cache.retained()==2
                assert all(a>=b for a,b in zip(retained,retained[1:]))
                assert cache.counts['entries_released']==model['cache_entries_released']
                counts['suffix_fixtures']+=1;counts['cost_formula_checks']+=4
    # Full literal SC_SZC with three distinct equality groups and original
    # dense equality planes retained in the same final opening positions.
    for geom,n,cfg,const,ir,words,originals,entries,rhos,draw,mode,points in fixtures(rng):
        counts['szc_fixtures']+=1
        groups=[Group(p,0,d) for p,d in zip(points,(4,2,2))]
        fn=lambda g,v:bracket(g,v,cfg,const)[0]
        prefix=[];expected=[]
        for j,r in enumerate(rhos):
            expected.append(original_group_rounds(originals,ir,prefix,n,range(7)))
            counts['independent_group_samples']+=21;prefix.append(o.tup(r))
        finals=[F(*o.mle(v,list(map(o.tup,rhos)))) for v in originals]
        baseline=Grouped(Tables(n,copy.deepcopy(entries)),5,copy.deepcopy(groups),fn,3)
        candidates=[CachedGrouped(Tables(n,copy.deepcopy(entries)),5,copy.deepcopy(groups),fn,c,d)
                    for c,d in ((1,False),(7,True))]
        for j,r in enumerate(rhos):
            combined=[sum((row[x] for row in expected[j]),F()) for x in range(6)]
            assert baseline.round(j)==combined;baseline.bind(r)
            for ev in candidates:
                assert ev.round(j)==combined,('cached SC_SZC',mode,n,j)
                for g,row in enumerate(ev.pending):
                    assert row==expected[j][g][:6]
                    assert interpolate(row,F(6))==expected[j][g][6]
                    counts['cached_group_samples']+=7
                ev.bind(r)
                for g,claim in enumerate(ev.claims):
                    assert claim==interpolate(expected[j][g][:6],r)
                    counts['actual_claim_checks']+=1
                for value in combined:digest.update(value.wire())
        assert baseline.finals()==finals
        for ev in candidates:
            assert ev.finals()==finals
            counts['candidate_table_finals']+=len(finals)
            assert [ev.counts['bracket_calls_'+str(g)] for g in range(3)] == [baseline.counts['bracket_calls_'+str(g)] for g in range(3)] if not ev.debug else True
            for g,c in enumerate(ev.caches):
                model=accounting(n,groups[g].start,len(groups[g].point))
                assert c.counts['entries_built']==model['cache_entries_built']
                assert c.retained()==2
                counts['cache_entries_built']+=c.counts['entries_built']
                counts['cache_entries_released']+=c.counts['entries_released']
            counts['recoveries']+=ev.counts['group_recoveries']
            counts['zero_factor_fallbacks']+=ev.counts['zero_factor_explicit_fallbacks']
            counts['cached_schedules']+=1
            targets={name:draw() for name,private,_ in entries if private}
            for x in (F(),F(1),F(2,3)):
                vals=extend(finals,entries,targets,x)
                expected_ext=[o.add(o.tup(a),o.mul(o.tup(x),o.sub(o.tup(targets[name]) if private else o.Z,o.tup(a))))
                              for a,(name,private,_) in zip(finals,entries)]
                assert list(map(o.tup,vals))==expected_ext
                counts['extension_table_checks']+=len(vals)
        if n>=6 and mode=='full' and saved is None:
            saved=(n,cfg,const,entries,groups,expected)
    def refuse(name,fn):
        try:fn()
        except ValueError:controls.append(name)
        else:raise AssertionError('control failed '+name)
    # Check original-cube rounds with interior supports as well as endpoints.
    for start,length in ((0,0),(0,1),(1,1),(1,2),(2,2),(3,1),(0,4)):
        n_offset=4;point=[F(rng.randrange(P),rng.randrange(P)) for _ in range(length)]
        eq=[F(*o.eq(list(map(o.tup,point)),[(b,0) for b in o.bits(i,n_offset)[start:start+length]]))
            for i in range(1<<n_offset)]
        a=[F(rng.randrange(P),rng.randrange(P)) for _ in eq]
        original=[list(map(o.tup,eq)),list(map(o.tup,a))]
        ev=CachedGrouped(Tables(n_offset,[('eq',False,Dense(n_offset,eq)),('a',True,Dense(n_offset,a))]),
                         3,[Group(point,start,2)],lambda g,v:v[1]*v[1],3,True)
        prefix=[];draws=[F(),F(1),F(3,4),F(5,6)]
        for j,r in enumerate(draws):
            expected_offset=[]
            for x in range(4):
                vals=original_partial(original,prefix+[(x,0)],n_offset);acc=o.Z
                for z,w in zip(*vals):acc=o.add(acc,o.mul(z,o.mul(w,w)))
                expected_offset.append(F(*acc))
            assert ev.round(j)==expected_offset
            ev.bind(r);prefix.append(o.tup(r));counts['offset_round_samples']+=4
        assert ev.finals()==[F(*o.mle(v,list(map(o.tup,draws)))) for v in original]
        counts['offset_fixtures']+=1
    c=SuffixCache([F(2,3),F(4,5)],0,3)
    refuse('wrong_round',lambda:c.pair(1));refuse('early_terminal',c.terminal)
    refuse('bind_before_round',lambda:c.finish_round(0))
    refuse('stale_point',lambda:c.pair(0,[F(2,3),F(4,6)],0))
    refuse('stale_start',lambda:c.pair(0,list(c.point),1))
    c.pair(0);refuse('duplicate_pending',lambda:c.pair(0))
    refuse('wrong_bind',lambda:c.finish_round(1));c.finish_round(0)
    refuse('cross_proof_bound_cache',lambda:c.pair(0))
    for args in [([], -1,3),([F(1)]*4,0,3),([],4,3),([],0,-1)]:
        refuse('invalid_extent_'+str(args[1:]),lambda args=args:SuffixCache(*args))
    n,cfg,const,entries,groups,expected=saved
    fn=lambda g,v:bracket(g,v,cfg,const)[0]
    fresh=lambda:CachedGrouped(Tables(n,copy.deepcopy(entries)),5,copy.deepcopy(groups),fn,3)
    ev=fresh();ev.groups[0].point[1]+=F(1)
    refuse('mutation_after_cache_construction',lambda:ev.round(0))
    ev=fresh();ev.claims=[F()]*3;ev.debug=True
    refuse('asserted_combined_claim',lambda:ev.round(0))
    ev=fresh();c=ev.caches[0];level=min(c.right);v=list(c.right[level]);v[0]+=F(1);c.right[level]=tuple(v)
    assert ev.round(0)!=[sum((row[x] for row in expected[0]),F()) for x in range(6)]
    controls.append('corrupt_cached_cell')
    ev=fresh();ev.caches[0].right={k:tuple(reversed(v)) for k,v in ev.caches[0].right.items()}
    assert ev.round(0)!=[sum((row[x] for row in expected[0]),F()) for x in range(6)]
    controls.append('reversed_MSB_suffix')
    assert counts['recoveries'] and counts['zero_factor_fallbacks']
    for token_log in (9,10,11,12):
        # Conditional m125 head map: h_pad=16, T=2^token_log.
        # S data cube is head/i/j, Ht support is leading head/i.
        n=4+2*token_log;lengths=[n,4+token_log,n]
        rows=[accounting(n,0,l) for l in lengths]
        cost_rows.append({'context':1<<token_log,'head_pad':16,'n':n,'group_lengths':lengths,'groups':rows,
            'build_multiplications_before':sum(r['baseline_build_multiplications'] for r in rows),
            'build_multiplications_after':sum(r['cache_build_multiplications'] for r in rows),
            'cache_peak_bytes':sum(r['logical_cache_peak_bytes'] for r in rows),
            'weight_reads_unchanged':6*((1<<n)-1),
            'weight_multiplications_unchanged':3*((1<<n)-1),
            'removed_fraction_of_weight_plus_build_multiplications':
                sum(r['baseline_build_multiplications']-r['cache_build_multiplications'] for r in rows)/
                (sum(r['baseline_build_multiplications'] for r in rows)+3*((1<<n)-1)),
            'cache_extra_peak_bytes':sum(r['logical_extra_peak_bytes'] for r in rows)})
    result={'run_id':RUN,'cycle':'0041','status':'pass','seed':SEED,
        'counts':dict(counts),'controls':controls,'control_count':len(controls),
        'cost_rows':cost_rows,'digest_sha256':digest.hexdigest(),
        'elapsed_seconds':time.perf_counter()-begin,
        'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        'hardware':{'device':'CPU only','cpu':next(l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),
                    'threads':1,'affinity':sorted(os.sched_getaffinity(0)),'nice':os.nice(0),'python':platform.python_version()},
        'resource_limits':{'wall_seconds':59,'cpu_seconds':59,'address_space_mib':512,'estimated_memory_mib':64},
        'code_hashes':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in HERE.glob('*.py')},
        'proof_accounting':{'accepted_complete_private8b_proofs':0,'countable_tokens':0,'context_length':None,'passes':0,'device':'CPU only',
            'steady_state_tokens_per_s':None,'total_workload_tokens_per_s':None,'startup_seconds':None,'startup_fraction':None,
            'witness_seconds':None,'proof_seconds':None,'serialization_seconds':None,'independent_verification_seconds':None,
            'proof_latency_seconds':None,'proof_lag_seconds':None,'pipeline_drain_seconds':None,'prefill':'none','resident_passes':'none','decode':'none'},
        'limits':['Synthetic deliberately inconsistent SC_SZC planes; no honest witness or native proof',
                  'Independent tuple original-cube oracle; copied scheduling reference',
                  'No masks/RNG/transcript/native compiler/parallel/cache locality or GPU timing',
                  'Allocation and operation counts do not establish an end-to-end gain']}
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ['status','counts','control_count','elapsed_seconds','peak_rss_kib','digest_sha256']},sort_keys=True),flush=True)

if __name__=='__main__':main()
