"""Bounded optional-support conformance and bracket-only cost correction."""
import hashlib,itertools,json,os,random,resource,signal,time
from collections import Counter
from pathlib import Path
from field_support import F,P
from fixtures import constants
from source_port import bracket as scalar
from polynomial_ir import expanded
from polynomial_clause import bracket as coefficient
from coefficients import Coeff
from prepared import Plan,generalize
from candidate import CoefficientTerms
from axis_factory import AxisRounds,measured_dependencies,shape_dependencies
from static_plan import StaticRowPlan
from row_graph import CSERowPlan,compile_row
from support_model import config,policy,padding_setup,construction_check,natural_tables
import oracle as o

HERE=Path(__file__).resolve().parent
SEED=2026101753


def build(cfg,con,ir,tabs,n,chunk,debug,cse=False,mutation=None):
    deps={cfg['index'][name]:measured_dependencies(tabs[cfg['index'][name]]['words'],n)
          for name in ('mask','ght','gs') if name in cfg['index']}
    args=(cfg,con,Plan(generalize(cfg),con['alpha'],con['gu8']),deps)
    rp=CSERowPlan(*args,mutation=mutation) if cse else StaticRowPlan(*args)
    groups=[(g,CoefficientTerms(ts,g,cfg,con,rp)) for g,ts in enumerate(ir)]
    return AxisRounds(tabs,n,5,groups,rp,chunk,debug),rp


def fixture(n,ls,present,mode,rng,lookup_count=None):
    draw=lambda:F(rng.randrange(P),rng.randrange(P)) if mode=='full' else (
        F(rng.randrange(2)) if mode=='boolean' else F())
    cfg=config(present,ls=ls,lookup_count=lookup_count);con=constants(cfg,draw)
    for key in ('nu0','nu1','zeta'):
        if con[key]==0:con[key]=F(1)
    tabs=[dict(kind='Eq',start=0,point=[draw() for _ in range(n-int(n>0 and g==1))]) for g in range(3)]
    for name in cfg['names'][3:]:
        words=[draw() for _ in range(1<<n)]
        if name in ('mx','sum','ght') and n:
            lead=[draw() for _ in range(1<<(n-1))]
            words=[lead[i//2] for i in range(1<<n)]
        if name=='ght':words=[F(int((i//2 if n else i)%3!=1)) for i in range(1<<n)]
        if name=='gs':words=[F(int(i%3!=1)) for i in range(1<<n)]
        if name=='mask':words=[F(int(i%2==0)) for i in range(1<<n)]
        tabs.append(dict(kind='Pub',words=words))
    return cfg,con,expanded(cfg,con),tabs,[draw() for _ in range(n)]


def ev(coeff,t):
    out=o.Z
    for c in reversed(coeff):out=o.add(o.mul(out,o.tup(t)),o.tup(c))
    return out


def census(shape,ls,rng):
    hp,kv,qh,tp,tokens=shape
    pol=policy(hp,qh,tp,tokens)
    cfg=config(pol['supports'],ls=ls);legacy=config((True,True),ls=ls)
    con=constants(cfg,lambda:F(rng.randrange(P),rng.randrange(P)))
    n=(hp*tp*tp).bit_length()-1
    totals={};schedules={};details={}
    # Count literal native-shaped brackets, not full proving. Each of three
    # groups retains its own declared degree and running-claim recovery.
    for label,cf in [('legacy_always_padded_formula',legacy),('correct_optional_port',cfg)]:
        total=Counter();schedule=[]
        vals=[F(rng.randrange(P),rng.randrange(P)) for _ in cf['names']]
        per=[scalar(g,vals,cf,con)[1] for g in range(3)]
        degrees=(4,2,2) if cf['padded'] else (3,1,1)
        for j in range(n):
            rows=1<<(n-j-1);counts=Counter()
            for g,degree in enumerate(degrees):
                # Release, nonzero-factor h(1) recovery after round zero.
                samples=degree+1-int(j>0)
                for k,v in per[g].items():counts[k]+=v*rows*samples
            total.update(counts)
            schedule.append(dict(round=j,rows=rows,bracket_calls=[rows*(d+1-int(j>0)) for d in degrees]))
        totals[label]=dict(total);schedules[label]=schedule
        groups,weights,setup=padding_setup(cf,con['zeta'])
        details[label]=dict(supports=cf['supports'],pad_on=cf['padded'],tables=len(cf['names']),
            bracket_degrees=degrees,group0_coefficient_width=degrees[0]+1,
            scalar_per_group=[dict(x) for x in per],pad_group_planes=[len(g) for _,g in groups],
            pad_weight_words=len(weights),literal_native_pad_weight_setup_mul=setup,
            support_table_payload_bytes=sum(cf['supports'])*(1<<n)*16,
            support_fold_cells=sum(cf['supports'])*((1<<n)-1))
    # Construction cost of the same conditional factory policy as cycles49-52.
    # Full domains have no selected coefficient group under that policy.
    fac={};factory_meta={}
    for label,cf in [('legacy_always_padded_formula',legacy),('correct_optional_port',cfg)]:
        deps=shape_dependencies(cf,*shape)
        rp=CSERowPlan(cf,con,Plan(generalize(cf),con['alpha'],con['gu8']),deps)
        vals=[F(2,3) for _ in cf['names']];ds=[F(5,7) for _ in vals]
        total=Counter()
        for j in range(n):
            rp.round_index=j;rp.counts.clear();rp.begin(vals,ds)
            for k,v in rp.counts.items():total[k]+=v*(1<<(n-j-1))
            rp.end()
        fac[label]=dict(total)
        factory_meta[label]=dict(selected_groups=sorted(rp.coefficient_groups),
            graphs=[g.record() for g in rp.graphs.values()],
            max_coefficient_words=rp.max_coefficient_words)
    before=Counter(totals['legacy_always_padded_formula']);after=Counter(totals['correct_optional_port'])
    return dict(shape=dict(head_pad=hp,kv_heads=kv,query_heads=qh,token_pad=tp,tokens=tokens),
        limbs=ls,cube_log=n,policy=pol,bracket_only_totals=totals,details=details,schedules=schedules,
        corrected_api_fraction_below_legacy_formula=(sum(before.values())-sum(after.values()))/sum(before.values()),
        conditional_group0_factory_construction_only=fac,factory_metadata=factory_meta,
        native_speedup_claim=False,
        limits='No lift in these shapes. Source-derived scalar seam and arithmetic counts only; not exact full native slot layouts, proof clocks or a new native saving. Counts include literal unit/zero operations and assume release nonzero recovery.')


def main():
    start=time.perf_counter();signal.alarm(59)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
    rng=random.Random(SEED);cc=Counter();controls=[];digest=hashlib.sha256();recoveries=fallbacks=0
    declared={};presence_counts=Counter()
    fixtures=[fixture(n,ls,present,mode,rng,lookup_count=(7 if n%2 else 8))
        for n,ls,present,mode in itertools.product((0,1,2,3),(2,3),((False,False),(True,False),(False,True),(True,True)),('full','zero','boolean'))]
    # Natural public h,t,j tables: full, token-padded, head-padded, both.
    shapes=[(4,1,4,2,2),(4,1,4,2,1),(4,1,3,2,2),(4,1,3,2,1)]
    for sh in shapes:
        hp,kv,qh,tp,tok=sh;n=(hp*tp*tp).bit_length()-1
        cfg,con,ir,tabs,rs=fixture(n,3,policy(hp,qh,tp,tok)['supports'],'full',rng)
        for name,words in natural_tables(*sh).items():
            if name in cfg['index']:tabs[cfg['index'][name]]=dict(kind='Pub',words=words)
        fixtures.append((cfg,con,ir,tabs,rs))
    for cfg,con,ir,tabs,rs in fixtures:
        n=len(rs);original=[o.table(t,n) for t in tabs];prefix=[];want=[]
        for j,r in enumerate(rs):
            want.append([o.round_direct(original,list(enumerate(ir)),prefix,t,n) for t in range(6)])
            prefix.append(o.tup(r))
        finals=[o.mle(t,prefix) for t in original]
        for chunk,debug in itertools.product((1,3,7),(False,True)):
            base,bp=build(cfg,con,ir,tabs,n,chunk,debug)
            cand,cp=build(cfg,con,ir,tabs,n,chunk,debug,True)
            for j,r in enumerate(rs):
                a,b=cand.round(j),base.round(j)
                assert list(map(o.tup,a))==list(map(o.tup,b))==want[j]
                for group in cand.pending:
                    for x in group:digest.update(x.wire())
                cc['independent_round_samples']+=6;cand.fold(r);base.fold(r)
            assert list(map(o.tup,cand.finals()))==list(map(o.tup,base.finals()))==finals
            assert cand.work==base.work and cp.eval_counts==bp.eval_counts
            assert cand.recoveries==base.recoveries and cand.zero_fallbacks==base.zero_fallbacks
            assert cand.data_fold_ops==base.data_fold_ops
            cc['independent_final_values']+=len(finals);cc['full_schedules']+=1
            recoveries+=cand.recoveries;fallbacks+=cand.zero_fallbacks
        # Expanded zero values may cancel; Terms retains source-declared width.
        declared[str(cfg['supports'])]=(4,2,2) if cfg['padded'] else (3,1,1)
        presence_counts[str(cfg['supports'])]+=1;cc['fixtures']+=1
    # Arbitrary extension values for all support combinations, limb and lookup
    # boundaries, independent tuple expansion, scalar and polynomial paths.
    for present,ls,count in itertools.product(((False,False),(True,False),(False,True),(True,True)),(2,3),(1,2,7,8)):
        cfg=config(present,ls=ls,lookup_count=count)
        draw=lambda:F(rng.randrange(P),rng.randrange(P))
        con=constants(cfg,draw);ir=expanded(cfg,con)
        vals=[draw() for _ in cfg['names']];ds=[draw() for _ in vals]
        vv=[Coeff([a,b]) for a,b in zip(vals,ds)]
        groups,weights,setup=padding_setup(cfg,con['zeta'])
        assert len(groups)==sum(present)
        # Oracle powers start at zeta^0 across PRESENT groups only.
        power=o.O
        for w in weights:
            assert o.tup(w)==power;power=o.mul(power,o.tup(con['zeta']));cc['independent_padding_weights']+=1
        for g in range(3):
            poly,_=coefficient(g,vv,cfg,con,pad_weights=weights)
            for t in (F(),F(1),F(P-1,P-1),draw()):
                point=[a+t*b for a,b in zip(vals,ds)]
                expected=o.bracket(ir[g],list(map(o.tup,point)))
                assert ev(poly.c,t)==o.tup(scalar(g,point,cfg,con)[0])==expected
                cc['independent_extension_clause_values']+=1
        for active in itertools.product((False,True),repeat=1+sum(present)):
            pattern={cfg['index'][name]:flag for name,flag in zip([x for x in ('mask','ght','gs') if x in cfg['index']],active)}
            entries=Plan(generalize(cfg),con['alpha'],con['gu8']).entries
            graph=compile_row(cfg,pattern,sorted(con),entries)
            zero=compile_row(cfg,pattern,sorted(con),Plan(generalize(cfg),F(),F()).entries)
            assert graph.record()['schema_sha256']==zero.record()['schema_sha256']
            assert graph.counts==zero.counts
            cc['value_independent_graph_schema_checks']+=1
        try:construction_check(cfg)
        except ValueError:
            assert present==(False,True);cc['native_construction_refusals']+=1
        else:assert present!=(False,True);cc['native_construction_admissions']+=1
    controls.append('S-only-native-construction-refusal-preserved-algebra-tested-separately')
    # Material negative controls: each must disagree with independent equations.
    cfg,con,ir,tabs,rs=fixture(3,3,(True,True),'full',rng)
    vals=[F(rng.randrange(P),rng.randrange(P)) for _ in cfg['names']]
    for mut in ('restart_zeta','ht_uses_s','gate_helpers'):
        # Explicitly give Ht and S different extension values.
        vals[cfg['index']['ght']]=F(2,3);vals[cfg['index']['gs']]=F(5,7)
        assert o.tup(scalar(0,vals,cfg,con,mut)[0])!=o.bracket(ir[0],list(map(o.tup,vals))) or (
            mut=='ht_uses_s' and o.tup(scalar(1,vals,cfg,con,mut)[0])!=o.bracket(ir[1],list(map(o.tup,vals))))
        controls.append(mut+'-independent-equation-detected')
    # Incorrect deletion of a PRESENT support changes equations/refusal domain.
    bad=config((False,False),ls=3)
    badvals=[vals[cfg['index'][name]] for name in bad['names']]
    assert o.tup(scalar(0,badvals,bad,con)[0])!=o.bracket(ir[0],list(map(o.tup,vals)))
    controls.append('drop-present-support-detected')
    try:config((True,))
    except ValueError:controls.append('invalid-presence-metadata-refused')
    else:raise AssertionError('metadata')
    try:
        from source_port import layout
        layout(padded=False,supports=(True,False))
    except ValueError:controls.append('support-without-pad-on-refused')
    else:raise AssertionError('metadata')
    # Allocation-free P3 presence oracle: independent products, exact true sizes.
    for hp,tp,qh,tok,lc,frozen in itertools.product((1,2,4,8),(1,2,4),(1,2,3,4),range(1,5),range(6),(False,True)):
        if qh>hp or tok>tp:continue
        pol=policy(hp,qh,tp,tok,lc,frozen)
        ht=(1 << max((hp*tp).bit_length()-1,lc))!=qh*tok
        ss=(1 << max((hp*tp*tp).bit_length()-1,lc))!=qh*tok*tok
        assert pol['supports']==((ht and not frozen),(ss and not frozen))
        assert pol['supports']!=(False,True), 'S-only cannot occur under these public size rules'
        cc['allocation_free_shape_presence_checks']+=1
    controls.append('P3-lift-can-create-Ht-only-support-full-native-tables-not-ported')
    projections=[census(sh,ls,rng) for sh,ls in itertools.product([(16,4,12,512,512),(32,8,32,512,512),(32,8,24,1024,769)],(2,3))]
    prior=json.loads((HERE.parent/'public-row-cse-20261017/result.json').read_text())
    result=dict(status='passed',run_id='20261017T032624Z-1d6d29cb',cycle='0053',seed=SEED,
        counts=dict(cc),presence_fixture_counts=dict(presence_counts),declared_degrees=declared,controls=controls,
        recoveries=recoveries,zero_factor_fallbacks=fallbacks,output_sha256=digest.hexdigest(),projections=projections,
        wall_seconds=time.perf_counter()-start,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        hardware=dict(device='CPU only',threads=1,affinity=sorted(os.sched_getaffinity(0)),nice=os.nice(0),
            cpu_model=next(x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name'))),
        limits=dict(wall_seconds=59,cpu_seconds=59,address_space_bytes=512*1024**2,estimated_bytes=64*1024**2),
        proof_accounting=prior['proof_accounting'])
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='projections'},indent=2))
    for p in projections:print('CENSUS',json.dumps({k:v for k,v in p.items() if k not in ('schedules','factory_metadata')}))


if __name__=='__main__':main()
