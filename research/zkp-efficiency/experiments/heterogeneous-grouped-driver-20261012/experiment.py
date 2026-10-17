#!/usr/bin/env python3
"""Bounded synthetic mixed-table/grouped-equality conformance experiment."""
import copy,hashlib,json,os,platform,random,resource,signal,time
from collections import Counter
from pathlib import Path
from field import F,P,fold
from driver import Dense,Tables,Rounds,interpolate,extend
from grouped import Group,Grouped
from fixture import fixtures,original_partial,original_round,literal_poly,limits
from source_port import bracket
import full_oracle as o

HERE=Path(__file__).resolve().parent
RUN='20261012T212555Z-0814839f'
SEED=2026101240

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
    limits();start=time.perf_counter();rng=random.Random(SEED)
    counts=Counter();digest=hashlib.sha256();costs=[];controls=[];saved=None
    for geometry,n,cfg,const,ir,words,originals,entries,rhos,draw,mode,points in fixtures(rng):
        counts['fixtures']+=1;degree=5
        poly=literal_poly(cfg,const); fn=lambda g,v:bracket(g,v,cfg,const)[0]
        groups=[Group(p,0,d) for p,d in zip(points,(4,2,2))]
        # Reference is all-original-cube evaluation in separate tuple arithmetic.
        messages=[];group_messages=[];prefix=[]
        reference=Rounds(Tables(n,[(name,private,Dense(n,v)) for (name,private,_),v in zip(entries,words)]),degree,poly)
        for j,r in enumerate(rhos):
            expected=original_group_rounds(originals,ir,prefix,n,range(degree+2))
            combined=[sum((row[x] for row in expected),F()) for x in range(degree+1)]
            assert reference.round(j)==combined,('original-vs-dense',mode,n,j)
            reference.bind(r)
            group_messages.append(expected);messages.append(combined)
            prefix.append(o.tup(r));counts['independent_group_samples']+=3*(degree+2)
            counts['dense_reference_samples']+=degree+1
        finals=[F(*o.mle(v,list(map(o.tup,rhos)))) for v in originals]
        assert reference.finals()==finals
        counts['independent_table_finals']+=len(finals)
        for chunk,debug in ((1,False),(3,False),(7,True)):
            tables=Tables(n,copy.deepcopy(entries))
            ev=Grouped(tables,degree,copy.deepcopy(groups),fn,chunk,debug)
            assert all(c is None for c in ev.claims)
            for j,r in enumerate(rhos):
                actual=ev.round(j); assert actual==messages[j],('mixed-grouped',mode,n,j,chunk)
                for g,pending in enumerate(ev.pending):
                    assert pending==group_messages[j][g][:degree+1],('subgroup',g,j)
                    assert interpolate(pending,F(degree+1))==group_messages[j][g][-1],('degree',g,j)
                    counts['candidate_group_samples']+=degree+2
                for v in actual:digest.update(v.wire())
                ev.bind(r)
                for g,claim in enumerate(ev.claims):
                    assert claim==interpolate(group_messages[j][g][:degree+1],r)
                    counts['actual_group_claim_checks']+=1
            assert ev.finals()==finals
            assert tables.bind_calls==n*len(entries)
            counts['candidate_table_finals']+=len(finals);counts['schedules']+=1
            if n:
                for g,claim in enumerate(ev.claims):
                    assert claim==finals[g]*fn(g,finals)
                    counts['terminal_group_claim_checks']+=1
            # Public zero targets retain the table-extension convention.
            targets={name:draw() for name,private,_ in entries if private}
            for x in (F(),F(1),F(2,3)):
                vals=extend(finals,entries,targets,x)
                expected=[o.add(o.tup(a),o.mul(o.tup(x),o.sub(o.tup(targets[name]) if private else o.Z,o.tup(a))))
                          for a,(name,private,_) in zip(finals,entries)]
                assert list(map(o.tup,vals))==expected
                assert poly(vals)==F(*o.poly(list(enumerate(ir)),expected))
                counts['extension_table_checks']+=len(vals);counts['extension_polynomial_checks']+=1
            for key,val in ev.counts.items():
                if key=='split_eq_peak_entries':counts[key]=max(counts[key],val)
                else:counts[key]+=val
            if chunk==1:
                descriptors=[t for name,_,t in tables.entries if name in ('mask','ght','gs')]
                cost=dict(context=geometry['tokens'],t_pad=geometry['t_pad'],h_pad=geometry['h_pad'],
                          cube_log=n,mode=mode,tables=len(entries),
                          dense_public_lerps_before=3*((1<<n)-1),
                          descriptor_bind_lerps=sum(getattr(t,'interpolations',getattr(t,'bind_lerps',0)) for t in descriptors),
                          descriptor_reads=sum(t.reads for t in descriptors),
                          integer_predicates=sum(getattr(t,'integer_tests',getattr(t,'predicates',0)) for t in descriptors),
                          grouped_calls=[ev.counts['bracket_calls_'+str(g)] for g in range(3)],
                          generic_explicit_group_calls=[6*((1<<n)-1)]*3,
                          grouped_counts_match_dense_representation=True)
                # Explicit same grouped driver on dense public tables validates
                # that representation does not consume the grouped call saving.
                dense=Grouped(Tables(n,[(name,p,Dense(n,v)) for (name,p,_),v in zip(entries,words)]),degree,copy.deepcopy(groups),fn,chunk)
                for j,r in enumerate(rhos):assert dense.round(j)==messages[j];dense.bind(r)
                assert dense.finals()==finals
                assert cost['grouped_calls']==[dense.counts['bracket_calls_'+str(g)] for g in range(3)]
                counts['dense_grouped_schedules']+=1;costs.append(cost)
        if n>=6 and mode=='full' and saved is None:
            saved=(n,cfg,const,words,originals,entries,rhos,groups,ir,messages,group_messages)

    # Generic supports exercise start>0, early-ended, empty and overlapping
    # independent equality domains, not only the native SZC leading subsets.
    offset_specs=[(0,0),(0,1),(1,1),(1,2),(2,2),(3,1),(0,4)]
    for start_at,length in offset_specs:
        n=4;point=[F(rng.randrange(P),rng.randrange(P)) for _ in range(length)]
        eq=[F(*o.eq(list(map(o.tup,point)),[(b,0) for b in o.bits(i,n)[start_at:start_at+length]])) for i in range(1<<n)]
        a=[F(rng.randrange(P),rng.randrange(P)) for _ in eq]
        entries=[('eq',False,Dense(n,eq)),('a',True,Dense(n,a))]
        fn=lambda g,v:v[1]*v[1]
        ev=Grouped(Tables(n,entries),3,[Group(point,start_at,2)],fn,3,True)
        originals=[list(map(o.tup,eq)),list(map(o.tup,a))];rhos=[F(0),F(1),F(3,4),F(5,6)]
        prefix=[]
        for j,r in enumerate(rhos):
            expected=[]
            for x in range(4):
                vals=original_partial(originals,prefix+[(x,0)],n)
                expected.append(F(*sum_tuples([o.mul(v,o.mul(w,w)) for v,w in zip(*vals)])))
            assert ev.round(j)==expected,('offset',start_at,length,j)
            ev.bind(r);prefix.append(o.tup(r));counts['offset_round_samples']+=4
        assert ev.finals()==[F(*o.mle(v,list(map(o.tup,rhos)))) for v in originals]
        counts['offset_fixtures']+=1

    n,cfg,const,words,originals,entries,rhos,groups,ir,messages,gm=saved
    fn=lambda g,v:bracket(g,v,cfg,const)[0]
    fresh=lambda debug=False:Grouped(Tables(n,copy.deepcopy(entries)),5,copy.deepcopy(groups),fn,3,debug)
    def refuse(name,action):
        try:action()
        except ValueError:controls.append(name)
        else:raise AssertionError('refusal control failed '+name)
    def mismatch(name,action):
        assert action()!=messages[0],name;controls.append(name)
    bad=fresh();bad.claims=[F()]*3
    mismatch('false_combined_host_seed',lambda:bad.round(0))
    bad=fresh(True);bad.claims=[F()]*3
    refuse('debug_false_group_seed',lambda:bad.round(0))
    bad=fresh();bad.groups[1].point[-1]+=F(1)
    mismatch('wrong_short_equality_point',lambda:bad.round(0))
    bad=fresh();bad.groups[0].bracket_degree=2
    mismatch('underdeclared_bracket_degree',lambda:bad.round(0))
    bad=fresh();bad.tables.entries[3]=('mask',False,Dense(n,[F()]*(1<<n)))
    mismatch('causal_zero_placeholder',lambda:bad.round(0))
    bad=fresh();i=cfg['index']['ght'];k=cfg['index']['gs']
    bad.tables.entries[i]=('ght',False,copy.deepcopy(entries[k][2]))
    mismatch('Ht_replaced_by_S',lambda:bad.round(0))
    bad=fresh();bad.tables.entries[3],bad.tables.entries[4]=bad.tables.entries[4],bad.tables.entries[3]
    mismatch('table_positions_swapped',lambda:bad.round(0))
    bad=fresh();bad.bracket=lambda g,v:bracket(g,v,cfg,const,'gate_helpers')[0]
    mismatch('lookup_helpers_wrongly_support_gated',lambda:bad.round(0))
    bad=fresh();refuse('early_finals',bad.finals)
    bad=fresh();refuse('bind_without_round',lambda:bad.bind(F(1)))
    bad=fresh();refuse('wrong_round_index',lambda:bad.round(1))
    bad=fresh();bad.round(0);refuse('duplicate_pending_round',lambda:bad.round(0))
    bad=fresh();bad.round(0);refuse('pending_finals',bad.finals)
    for name,gs,degree in (
        ('negative_start',[Group([F(1)],-1,1)],3),
        ('outside_group_extent',[Group([F(1)]*(n+1),0,1)],3),
        ('empty_groups',[],3),
        ('zero_bracket_degree',[Group([],0,0)],3),
        ('excess_degree',[Group([F(1)],0,3)],3)):
        refuse(name,lambda gs=gs,degree=degree:Grouped(Tables(n,copy.deepcopy(entries)),degree,gs,fn))
    assert counts['zero_factor_explicit_fallbacks']>0
    assert counts['group_recoveries']>0
    elapsed=time.perf_counter()-start
    result={'run_id':RUN,'cycle':'0040','status':'pass','seed':SEED,'counts':dict(counts),
            'control_count':len(controls),'controls':controls,'cost_rows':costs,
            'digest_sha256':digest.hexdigest(),'elapsed_seconds':elapsed,
            'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            'hardware':{'device':'CPU only','cpu':next((l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),'unknown'),
                        'threads':1,'affinity':sorted(os.sched_getaffinity(0)),'nice':os.getpriority(os.PRIO_PROCESS,0),'python':platform.python_version()},
            'resource_limits':{'wall_seconds':59,'cpu_seconds':59,'address_space_mib':512,'estimated_memory_mib':64},
            'code_hashes':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(HERE.glob('*.py'))},
            'proof_accounting':{'context_length':None,'passes':0,'device':'CPU only','countable_tokens':0,'accepted_complete_private8b_proofs':0,
             'steady_state_tokens_per_s':None,'total_workload_tokens_per_s':None,'startup_seconds':None,'startup_fraction':None,'witness_seconds':None,'proof_seconds':None,
             'serialization_seconds':None,'independent_verification_seconds':None,'proof_latency_seconds':None,'proof_lag_seconds':None,'pipeline_drain_seconds':None,
             'prefill':'none','resident_passes':'none','decode':'none'},
            'limits':['Source-derived synthetic inconsistent planes; not an honest witness or native proof',
                      'Native source, mask/RNG/transcript/refusal/PCS/receipt/device/privacy unchanged and unexecuted',
                      'Serial chunks; no native compiler/parallel/phase/peak performance tested']}
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ('run_id','status','seed','counts','control_count','elapsed_seconds','peak_rss_kib','digest_sha256')},sort_keys=True),flush=True)

def sum_tuples(vals):
    out=o.Z
    for v in vals:out=o.add(out,v)
    return out

if __name__=='__main__':main()
