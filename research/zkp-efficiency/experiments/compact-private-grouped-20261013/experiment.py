#!/usr/bin/env python3
"""CPU-light compact PRIVATE planes in complete mixed/grouped SZC algebra."""
import copy,hashlib,json,os,platform,random,resource,time
from collections import Counter
from dataclasses import replace
from pathlib import Path
from field import F,P,fold
from driver import Dense,Tables,interpolate,extend
from grouped import Group,Grouped
from fixture import fixtures,original_partial,literal_poly,limits
from original_groups import original_group_rounds
from source_port import bracket
from compact import Source,Leading,eligible,from_committed
import full_oracle as o

HERE=Path(__file__).resolve().parent
RUN='20261013T002555Z-f0cb53eb'; SEED=2026101343

def compact_entries(entries,words,n,L):
    out=copy.deepcopy(entries)
    for i,(name,private,_) in enumerate(entries):
        if name not in ('mx','sum'):continue
        s=Source('SC_SZC','A_MX' if name=='mx' else 'A_SUM','A',2,(1,0),L,
                 tuple(('rho',j) for j in range(L)),20+i*2,0)
        # Synthetic source plane. Native sketch reads its contiguous committed
        # plane directly, never derives it from an asserted dense lift.
        raw=[F(9),F(10)]+[words[i][k << (n-L)] for k in range(1 << L)]+[F(11)]
        tab=from_committed(n,s,raw,lambda:Dense(n,words[i]))
        out[i]=(name,private,tab)
    return out

def main():
    limits();start=time.perf_counter();rng=random.Random(SEED)
    counts=Counter();costs=[];controls=[];digest=hashlib.sha256();saved=None
    for geometry,n,cfg,const,ir,words,originals,entries,rhos,draw,mode,points in fixtures(rng):
        counts['fixtures']+=1;L=len(points[1]);degree=5
        poly=literal_poly(cfg,const);fn=lambda g,v:bracket(g,v,cfg,const)[0]
        groups=[Group(p,0,d) for p,d in zip(points,(4,2,2))]
        prefix=[];gm=[];messages=[]
        for j,r in enumerate(rhos):
            expected=original_group_rounds(originals,ir,prefix,n,range(7))
            gm.append(expected);messages.append([sum((row[x] for row in expected),F()) for x in range(6)])
            counts['independent_group_samples']+=21;prefix.append(o.tup(r))
        finals=[F(*o.mle(a,list(map(o.tup,rhos)))) for a in originals]
        # Cube census includes arbitrary invalid/padded private values.
        total=F()
        for i in range(1 << n):
            total+=F(*o.poly(list(enumerate(ir)),[a[i] for a in originals]))
        baseline=Grouped(Tables(n,copy.deepcopy(entries)),5,copy.deepcopy(groups),fn,3)
        for j,r in enumerate(rhos):assert baseline.round(j)==messages[j];baseline.bind(r)
        assert baseline.finals()==finals;counts['baseline_schedules']+=1
        for chunk,debug in ((1,False),(3,False),(7,True)):
            tables=Tables(n,compact_entries(entries,words,n,L))
            compact=[t for name,_,t in tables.entries if name in ('mx','sum')]
            assert tables.total(poly,chunk)==total;counts['independent_total_checks']+=1
            ev=Grouped(tables,5,copy.deepcopy(groups),fn,chunk,debug)
            assert all(c is None for c in ev.claims)
            prefix=[]
            for j,r in enumerate(rhos):
                # Dense expanded original cube checks both readers BEFORE each
                # scan, independent of candidate binding or index formula.
                vals=original_partial(originals,prefix,n)
                for i,(name,_,tab) in enumerate(tables.entries):
                    if name in ('mx','sum'):
                        for k,value in enumerate(vals[i]):
                            assert tab.at(k)==F(*value),(name,j,k)
                            counts['private_reader_original_cube_checks']+=1
                actual=ev.round(j);assert actual==messages[j],(mode,n,j,chunk)
                for g,pending in enumerate(ev.pending):
                    assert pending==gm[j][g][:6]
                    assert interpolate(pending,F(6))==gm[j][g][-1]
                    counts['candidate_group_sample_degree_checks']+=7
                for v in actual:digest.update(v.wire())
                ev.bind(r);prefix.append(o.tup(r))
                for g,c in enumerate(ev.claims):
                    assert c==interpolate(gm[j][g][:6],r);counts['actual_claim_checks']+=1
            assert ev.finals()==finals;counts['ordered_final_checks']+=len(finals)
            assert tables.bind_calls==n*len(entries)
            for tab in compact:
                assert tab.lerps==(1 << L)-1
                assert tab.noop_binds==n-L
                assert len(tab.words)==1
                counts['private_fold_formula_checks']+=2
            if n:
                for g,c in enumerate(ev.claims):
                    assert c==finals[g]*fn(g,finals);counts['terminal_claim_checks']+=1
            # Two successive arbitrary private extension targets deliberately
            # differ for mx/sum; compressing them would underbind mask sites.
            cur=finals;oracle_cur=list(map(o.tup,finals))
            for stage in range(2):
                targets={name:draw() for name,p,_ in entries if p}
                for x in (F(),F(1),F(2,3)):
                    actual=extend(cur,entries,targets,x)
                    expected=[o.add(a,o.mul(o.tup(x),o.sub(o.tup(targets[name]) if p else o.Z,a)))
                              for a,(name,p,_) in zip(oracle_cur,entries)]
                    assert list(map(o.tup,actual))==expected
                    assert poly(actual)==F(*o.poly(list(enumerate(ir)),expected))
                    counts['extension_table_checks']+=len(actual);counts['extension_polynomial_checks']+=1
                x=F(3+stage,5+stage);cur=extend(cur,entries,targets,x)
                oracle_cur=[o.add(a,o.mul(o.tup(x),o.sub(o.tup(targets[name]) if p else o.Z,a)))
                            for a,(name,p,_) in zip(oracle_cur,entries)]
                assert list(map(o.tup,cur))==oracle_cur
            for key in ('group_recoveries','zero_factor_explicit_fallbacks'):
                counts[key]+=ev.counts[key]
            if not debug:
                for g in range(3):
                    assert ev.counts['bracket_calls_'+str(g)]==baseline.counts['bracket_calls_'+str(g)]
                    counts['bracket_count_invariance_checks']+=1
                assert ev.counts['table_endpoint_reads']==baseline.counts['table_endpoint_reads']
                counts['scan_count_invariance_checks']+=1
            if chunk==1:
                costs.append(dict(context=geometry['tokens'],h_pad=geometry['h_pad'],t_pad=geometry['t_pad'],
                    cube_log=n,leading_log=L,tables=len(entries),mode=mode,
                    dense_private_words=2*(1<<n),compact_private_words=2*(1<<L),
                    dense_private_lerps=2*((1<<n)-1),compact_private_lerps=sum(t.lerps for t in compact),
                    private_reads=sum(t.reads for t in compact),private_shifts=sum(t.shifts for t in compact),
                    noop_binds=sum(t.noop_binds for t in compact),
                    dense_other_folds_unchanged=True,all_grouped_bracket_calls_unchanged=True,
                    reader_counts_include_validation=True))
            counts['schedules']+=1
        if n>=6 and mode=='full' and saved is None:
            saved=(n,L,cfg,const,words,originals,entries,rhos,groups,ir,messages,finals)

    # Leading-length extremes 0 and n, plus multiple inactive axes; full
    # extension words/challenges and Boolean 0/1 challenges remain valid.
    for n in range(6):
        for L in range(n+1):
            source=[F(rng.randrange(P),rng.randrange(P)) for _ in range(1<<L)]
            s=Source('SC_SZC','A_SUM','A',1,(1,0),L,tuple(('rho',i) for i in range(L)),3,0)
            tab=from_committed(n,s,[F()]+source,lambda:None)
            original=[o.tup(source[k >> (n-L)]) for k in range(1<<n)]
            prefix=[]
            for j in range(n+1):
                expected=original_partial([original],prefix,n)[0]
                for k,v in enumerate(expected):assert tab.at(k)==F(*v);counts['edge_reader_checks']+=1
                if j<n:
                    r=[F(),F(1),F(3,5)][j%3];tab.bind(r);prefix.append(o.tup(r))
            assert tab.terminal()==F(*o.mle(original,prefix));counts['edge_fixtures']+=1
    n,L,cfg,const,words,originals,entries,rhos,groups,ir,messages,finals=saved
    fn=lambda g,v:bracket(g,v,cfg,const)[0]
    fresh=lambda:Grouped(Tables(n,compact_entries(entries,words,n,L)),5,copy.deepcopy(groups),fn,3)
    def refuse(name,action):
        try:action()
        except ValueError:controls.append(name)
        else:raise AssertionError('refusal control failed '+name)
    s=Source('SC_SZC','A_SUM','A',0,(1,0),L,tuple(('rho',j) for j in range(L)),17,0)
    changes=[('wrong_slot',{'slot':'SC_RS'}),('wrong_plane',{'plane':'A_E'}),
             ('wrong_cm',{'cm':'H'}),('wrong_coefficient',{'coefficient':(0,1)}),
             ('fixed_coordinate',{'coords':(('fixed',0),)+s.coords[1:]}),
             ('flip_coordinate',{'coords':(('flip',0),)+s.coords[1:]}),
             ('trailing_coordinate',{'coords':s.coords[:-1]+(('rho',n-1),)}),
             ('wrong_extension_round',{'ext_round':1}),('negative_offset',{'offset':-1})]
    for name,kw in changes:
        sentinel=object();assert from_committed(n,replace(s,**kw),[],lambda:sentinel) is sentinel
        controls.append(name+'_dense_fallback')
    refuse('source_length_refused',lambda:Leading(n,s,[F()]))
    refuse('source_bounds_refused',lambda:from_committed(n,s,[],lambda:None))
    tab=Leading(n,s,[F(k) for k in range(1<<L)])
    refuse('negative_index',lambda:tab.at(-1));refuse('past_cube_index',lambda:tab.at(1<<n))
    refuse('premature_terminal',tab.terminal)
    for r in rhos:tab.bind(r)
    refuse('overbind',lambda:tab.bind(F(1)))
    for name,mut in [('wrong_stride',lambda ev:setattr(next(t for name,p,t in ev.tables.entries if name=='sum'),'n',n-1)),
                     ('dropped_private_padded_word',lambda ev:next(t for name,p,t in ev.tables.entries if name=='sum').words.__setitem__(-1,F())),
                     ('wrong_private_source',lambda ev:next(t for name,p,t in ev.tables.entries if name=='mx').words.__setitem__(0,F()))]:
        ev=fresh();mut(ev)
        try:actual=ev.round(0)
        except ValueError:actual=None
        assert actual!=messages[0],name;controls.append(name+'_detected')
    # A false externally supplied compact-source attestation misses hidden
    # trailing changes. Constructor must use actual immutable native mapping.
    arbitrary=list(words[cfg['index']['sum']]);arbitrary[1]+=F(1)
    forged=Leading(n,s,[arbitrary[k << (n-L)] for k in range(1<<L)])
    assert any(forged.at(k)!=v for k,v in enumerate(arbitrary))
    controls.append('forged_lift_attestation_underbinding_detected')
    x=F(3,5);targets={name:F(7+i,11+i) for i,(name,p,_) in enumerate(entries) if p}
    actual=extend(finals,entries,targets,x);bad=list(actual);bad[cfg['index']['sum']]=finals[cfg['index']['sum']]
    assert literal_poly(cfg,const)(actual)!=literal_poly(cfg,const)(bad)
    controls.append('private_extension_target_dropped_detected')
    ev=fresh();refuse('early_finals',ev.finals);refuse('bind_before_round',lambda:ev.bind(F(1)))
    refuse('wrong_round_order',lambda:ev.round(1));ev.round(0)
    refuse('round_without_bind',lambda:ev.round(0))
    assert counts['group_recoveries'] and counts['zero_factor_explicit_fallbacks']
    result=dict(run_id=RUN,cycle='0043',status='pass',seed=SEED,counts=dict(counts),
      controls=controls,control_count=len(controls),cost_rows=costs,digest_sha256=digest.hexdigest(),
      elapsed_seconds=time.perf_counter()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
      hardware=dict(device='CPU only',cpu=next(l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),
                    threads=1,affinity=sorted(os.sched_getaffinity(0)),nice=os.getpriority(os.PRIO_PROCESS,0),python=platform.python_version()),
      resource_limits=dict(wall_seconds=59,cpu_seconds=59,address_space_mib=512,estimated_memory_mib=64),
      code_hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(HERE.glob('*.py'))},
      proof_accounting=dict(accepted_complete_private8b_proofs=0,countable_tokens=0,context_length=None,passes=0,device='CPU only',
          steady_state_tokens_per_s=None,total_workload_tokens_per_s=None,startup_seconds=None,startup_fraction=None,
          witness_seconds=None,proof_seconds=None,serialization_seconds=None,independent_verification_seconds=None,
          proof_latency_seconds=None,proof_lag_seconds=None,pipeline_drain_seconds=None,prefill='none',resident_passes='none',decode='none'),
      limits=['Synthetic deliberately inconsistent source planes; not an honest witness/native proof',
              'Independent tuple original cube/expanded polynomial reference; serial schedules only',
              'No private-value admission or compact masking: native site and arbitrary extension targets retained',
              'Native constructor/masks/RNG/transcript/PCS/refusal/compiler/GPU/enclosing checks remain unexecuted'])
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ('status','counts','control_count','elapsed_seconds','peak_rss_kib','digest_sha256')},indent=2))

if __name__=='__main__':main()
