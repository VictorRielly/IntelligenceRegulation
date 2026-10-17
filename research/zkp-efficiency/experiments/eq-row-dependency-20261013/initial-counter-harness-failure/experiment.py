#!/usr/bin/env python3
"""Bounded synthetic Eq elision through current mixed grouped SC_SZC."""
import copy,hashlib,json,os,platform,random,resource,time
from pathlib import Path
from collections import Counter
from field import F,P
from driver import Dense,Tables,interpolate,extend
from grouped import Group,Grouped
from grouped_base import Grouped as Baseline
from fixture import fixtures,original_partial,literal_poly,limits
from original_groups import original_group_rounds
from source_port import bracket
from compact import Source,from_committed
from equality import Equality,derive,Dependencies,DEAD
import full_oracle as o

HERE=Path(__file__).resolve().parent
RUN='20261013T012555Z-12f897c1';SEED=2026101344
PIN=hashlib.sha256((HERE/'native/hashline__src__private_block__argument.rs').read_bytes()).hexdigest()

def mixed(entries,words,n,L,points,symbolic):
    out=copy.deepcopy(entries)
    for i,(name,private,_) in enumerate(entries):
        if symbolic and name.startswith('eq'):
            out[i]=(name,private,Equality(n,points[int(name[-1])]))
        if name in ('mx','sum'):
            s=Source('SC_SZC','A_MX' if name=='mx' else 'A_SUM','A',0,(1,0),L,
                     tuple(('rho',j) for j in range(L)),20+i*2,0)
            raw=[words[i][k<<(n-L)] for k in range(1<<L)]
            out[i]=(name,private,from_committed(n,s,raw,lambda:Dense(n,words[i])))
    return out

def main():
    limits();start=time.perf_counter();rng=random.Random(SEED)
    counts=Counter();controls=[];rows=[];digest=hashlib.sha256();saved=None
    for geometry,n,cfg,const,ir,words,originals,entries,rhos,draw,mode,points in fixtures(rng):
        counts['fixtures']+=1;L=len(points[1]);fn=lambda g,v:bracket(g,v,cfg,const)[0]
        poly=literal_poly(cfg,const);groups=[Group(p,0,d) for p,d in zip(points,(4,2,2))]
        gm=[];messages=[];prefix=[]
        for j,r in enumerate(rhos):
            expected=original_group_rounds(originals,ir,prefix,n,range(7))
            gm.append(expected);messages.append([sum((a[x] for a in expected),F()) for x in range(6)])
            prefix.append(o.tup(r));counts['independent_group_samples']+=21
        finals=[F(*o.mle(a,list(map(o.tup,rhos)))) for a in originals]
        total=sum((F(*o.poly(list(enumerate(ir)),[a[i] for a in originals])) for i in range(1<<n)),F())
        base=Baseline(Tables(n,mixed(entries,words,n,L,points,False)),5,copy.deepcopy(groups),fn,3)
        for j,r in enumerate(rhos):assert base.round(j)==messages[j];base.bind(r)
        assert base.finals()==finals;counts['baseline_schedules']+=1
        for chunk,debug,elide in ((1,False,True),(3,False,True),(7,True,True),(3,False,False)):
            tabs=Tables(n,mixed(entries,words,n,L,points,True))
            deps=derive(tabs.entries,ir,PIN)
            assert deps.unused==(0,1,2)
            # Generic total and diagnostic census use exact symbolic readers.
            assert tabs.total(poly,chunk)==total;counts['generic_total_checks']+=1
            for i in range(1<<n):
                assert tabs.row(i)==[F(*a[i]) for a in originals]
                counts['original_census_cell_checks']+=len(entries)
            ev=Grouped(tabs,5,copy.deepcopy(groups),fn,chunk,debug,deps if elide else None)
            prefix=[];scan_reads=0
            for j,r in enumerate(rhos):
                vals=original_partial(originals,prefix,n)
                for k,(_,_,t) in enumerate(tabs.entries[:3]):
                    for i,v in enumerate(vals[k]):
                        assert t.at(i)==F(*v);counts['generic_partial_eq_checks']+=1
                before=sum(t.counts['generic_reads'] for _,_,t in tabs.entries[:3])
                actual=ev.round(j);assert actual==messages[j],(n,mode,j,chunk,elide)
                after=sum(t.counts['generic_reads'] for _,_,t in tabs.entries[:3])
                scan_reads+=after-before
                if elide:assert before==after;counts['zero_eq_scan_read_checks']+=1
                for g,pending in enumerate(ev.pending):
                    assert pending==gm[j][g][:6]
                    assert interpolate(pending,F(6))==gm[j][g][-1]
                    counts['candidate_group_sample_degree_checks']+=7
                for v in actual:digest.update(v.wire())
                ev.bind(r);prefix.append(o.tup(r))
                for g,c in enumerate(ev.claims):
                    assert c==interpolate(gm[j][g][:6],r);counts['actual_claim_checks']+=1
            assert ev.finals()==finals;counts['ordered_final_checks']+=len(entries)
            assert tabs.bind_calls==n*len(entries)
            if n:
                for g,c in enumerate(ev.claims):
                    assert c==finals[g]*fn(g,finals);counts['terminal_claim_checks']+=1
            if not debug:
                for g in range(3):
                    assert ev.counts['bracket_calls_'+str(g)]==base.counts['bracket_calls_'+str(g)]
                    counts['bracket_count_invariance_checks']+=1
            H=(1<<n)-1;top=4;k=len(entries)
            assert ev.counts['scan_pairs']==H
            assert ev.counts['row_differences']==(k-3*elide)*H
            assert ev.counts['sample_additions']==(k-3*elide)*top*H
            assert scan_reads==(0 if elide else 6*H)
            assert sum(t.counts['active_scalar_binds'] for _,_,t in tabs.entries[:3])==sum(map(len,points))
            assert sum(t.lerps for _,_,t in tabs.entries[3:])==sum(t.lerps for _,_,t in base.tables.entries[3:])
            counts['count_formula_checks']+=6
            cur=finals;oracle_cur=list(map(o.tup,finals));selector=F(1)
            for stage in range(2):
                targets={name:draw() for name,p,_ in entries if p}
                for x in (F(),F(1),F(2,3)):
                    actual=extend(cur,entries,targets,x)
                    expected=[o.add(a,o.mul(o.tup(x),o.sub(o.tup(targets[name]) if p else o.Z,a)))
                              for a,(name,p,_) in zip(oracle_cur,entries)]
                    assert list(map(o.tup,actual))==expected
                    assert poly(actual)==F(*o.poly(list(enumerate(ir)),expected))
                    counts['extension_table_checks']+=len(actual);counts['extension_polynomial_checks']+=1
                x=F(3+stage,5+stage);cur=extend(cur,entries,targets,x);selector*=1-x
                oracle_cur=[o.add(a,o.mul(o.tup(x),o.sub(o.tup(targets[name]) if p else o.Z,a)))
                            for a,(name,p,_) in zip(oracle_cur,entries)]
                for i in range(3):assert cur[i]==selector*finals[i];counts['public_eq_selector_checks']+=1
            for key in ('group_recoveries','zero_factor_explicit_fallbacks'):counts[key]+=ev.counts[key]
            if chunk==1:rows.append(dict(context=geometry['tokens'],h_pad=geometry['h_pad'],cube_log=n,
                tables=k,eq_fold_lerps_removed=3*H,eq_endpoint_reads_removed=6*H,
                eq_row_differences_removed=3*H,eq_sample_additions_removed=12*H,
                eq_active_scalar_binds_added=sum(map(len,points)),all_other_folds_brackets_scans_unchanged=True))
            counts['schedules']+=1
        if n>=6 and mode=='full' and saved is None:saved=(n,cfg,const,ir,words,originals,entries,rhos,groups,points,messages,finals)

    # Every legal bounded span, including n=0, shuffled table indices and empty
    # points. Direct original-cube tuple oracle, not descriptor self-comparison.
    for n in range(5):
        for span_start in range(n+1):
            for length in range(n-span_start+1):
                point=[F(rng.randrange(P),rng.randrange(P)) for _ in range(length)]
                rhos=[(F(),F(1),F(3,5))[j%3] for j in range(n)]
                original=[o.eq(list(map(o.tup,point)),[(b,0) for b in o.bits(i,n)[span_start:span_start+length]]) for i in range(1<<n)]
                t=Equality(n,point,span_start);prefix=[]
                for j in range(n+1):
                    expected=original_partial([original],prefix,n)[0]
                    for i,v in enumerate(expected):assert t.at(i)==F(*v);counts['span_reader_checks']+=1
                    if j<n:t.bind(rhos[j]);prefix.append(o.tup(rhos[j]))
                assert t.terminal()==F(*o.mle(original,prefix));counts['span_fixtures']+=1
                # Non-leading Eq index plus actual grouped round/bind/finals.
                data=[F(rng.randrange(P),rng.randrange(P)) for _ in range(1<<n)]
                tabs=Tables(n,[('a',True,Dense(n,data)),('eq',False,Equality(n,point,span_start)),('b',False,Dense(n,[F(2) for _ in data]))])
                terms=[[(F(1),(0,)),(F(1),(2,))]];deps=derive(tabs.entries,terms,PIN)
                ev=Grouped(tabs,2,[Group(point,span_start,1)],lambda g,v:v[0]+v[2],3,True,deps)
                original_all=[list(map(o.tup,data)),original,[(2,0) for _ in data]];prefix=[]
                for j,r in enumerate(rhos):
                    expected=[]
                    for x in range(3):
                        vals=original_partial(original_all,prefix+[(x,0)],n)
                        expected.append(F(*sum_tuple([o.mul(b,o.add(a,c)) for a,b,c in zip(*vals)])))
                    assert ev.round(j)==expected;ev.bind(r);prefix.append(o.tup(r));counts['span_round_samples']+=3
                assert ev.finals()==[F(*o.mle(a,prefix)) for a in original_all];counts['span_ordered_finals']+=3

    n,cfg,const,ir,words,originals,entries,rhos,groups,points,messages,finals=saved;L=len(points[1])
    fn=lambda g,v:bracket(g,v,cfg,const)[0]
    def fresh():
        tabs=Tables(n,mixed(entries,words,n,L,points,True));return Grouped(tabs,5,copy.deepcopy(groups),fn,3,False,derive(tabs.entries,ir,PIN))
    def refuse(name,action):
        try:action()
        except ValueError:controls.append(name)
        else:raise AssertionError(name)
    refuse('negative_span',lambda:Equality(n,points[0],-1));refuse('oversize_span',lambda:Equality(n,points[0],1))
    t=Equality(n,points[0]);refuse('premature_terminal',t.terminal)
    refuse('negative_index',lambda:t.at(-1));refuse('past_cube_index',lambda:t.at(1<<n))
    for r in rhos:t.bind(r)
    refuse('overbind',lambda:t.bind(F(1)))
    ev=fresh();refuse('bind_before_round',lambda:ev.bind(F(1)));refuse('wrong_round',lambda:ev.round(1))
    ev.round(0);refuse('round_without_bind',lambda:ev.round(0));refuse('early_finals',ev.finals)
    # An opaque altered closure consumes the trap; false metadata is not safe.
    ev=fresh();ev.bracket=lambda g,v:fn(g,v)+v[0]
    refuse('unproven_opaque_dependency_trapped',lambda:ev.round(0))
    modified=copy.deepcopy(ir);modified[0].append((F(1),(0,)))
    ev=fresh();assert 0 not in derive(ev.tables.entries,modified,PIN).unused
    controls.append('actual_IR_dependency_not_elided')
    ev=fresh();ev.dependencies=Dependencies((cfg['index']['sum'],),PIN)
    refuse('private_slot_not_elidable',lambda:ev.round(0))
    for label,change in [('wrong_point',lambda ev:setattr(ev.tables.entries[0][2],'point',tuple(F() for _ in points[0]))),
                         ('wrong_short_start',lambda ev:setattr(ev.tables.entries[1][2],'start',1))]:
        ev=fresh();change(ev)
        for j,r in enumerate(rhos):assert ev.round(j)==messages[j];ev.bind(r)
        assert ev.finals()!=finals;controls.append(label+'_ordered_final_detected')
    x=F(3,5);targets={name:F(9+i,11+i) for i,(name,p,_) in enumerate(entries) if p}
    actual=extend(finals,entries,targets,x);bad=list(actual);bad[0]=finals[0]
    assert literal_poly(cfg,const)(actual)!=literal_poly(cfg,const)(bad);controls.append('dropped_public_extension_selector_detected')
    bad=list(finals);bad[0],bad[1]=bad[1],bad[0]
    assert bad!=finals;controls.append('reordered_eq_finals_detected')
    assert counts['group_recoveries'] and counts['zero_factor_explicit_fallbacks']
    result=dict(run_id=RUN,cycle='0044',status='pass',seed=SEED,counts=dict(counts),controls=controls,
      control_count=len(controls),cost_rows=rows,digest_sha256=digest.hexdigest(),
      elapsed_seconds=time.perf_counter()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
      hardware=dict(device='CPU only',threads=1,cpu=next(l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),
                    affinity=sorted(os.sched_getaffinity(0)),nice=os.getpriority(os.PRIO_PROCESS,0),python=platform.python_version()),
      resource_limits=dict(wall_seconds=59,cpu_seconds=59,address_space_mib=512,estimated_memory_mib=64),
      code_hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(HERE.glob('*.py'))},
      native_argument_sha256=PIN,
      proof_accounting=dict(accepted_complete_private8b_proofs=0,countable_tokens=0,context_length=None,passes=0,device='CPU only',
        steady_state_tokens_per_s=None,total_workload_tokens_per_s=None,startup_seconds=None,startup_fraction=None,
        witness_seconds=None,proof_seconds=None,serialization_seconds=None,independent_verification_seconds=None,
        proof_latency_seconds=None,proof_lag_seconds=None,pipeline_drain_seconds=None,prefill='none',resident_passes='none',decode='none'),
      limits=['Synthetic inconsistent fixtures, no honest witness or native proof',
              'Serial schedules and source-derived IR; production opaque closure needs sealed dependency provenance',
              'All private extension targets and generic reads retained; no mask/RNG/transcript/PCS change tested',
              'Native compiler/parallel/frozen/refusal/privacy/enclosing/peak/GPU gates unexecuted'])
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ('status','counts','control_count','elapsed_seconds','peak_rss_kib','digest_sha256')},indent=2))

def sum_tuple(values):
    out=o.Z
    for v in values:out=o.add(out,v)
    return out

if __name__=='__main__':main()
