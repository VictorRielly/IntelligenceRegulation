#!/usr/bin/env python3
"""Bounded original-cube differential check of lifted Ht host collapse."""
import copy,hashlib,json,os,platform,random,resource,time
from pathlib import Path
from collections import Counter
from field import F,P
from driver import Tables,Dense,extend,interpolate
from grouped import Group,Grouped
from collapsed import Collapsed,admit_plan,HostPlan
from fixture import fixtures,original_partial,literal_poly,limits
from source_port import bracket
import full_oracle as o

HERE=Path(__file__).resolve().parent
RUN='20261012T232555Z-fecd435a';SEED=2026101242

def original_groups(originals,ir,prefix,n):
    out=[[] for _ in ir]
    for x in range(7):
        vals=original_partial(originals,prefix+[(x,0)],n)
        for g,terms in enumerate(ir):
            total=o.Z
            for i in range(len(vals[0])):
                total=o.add(total,o.mul(vals[g][i],o.bracket(terms,[a[i] for a in vals])))
            out[g].append(F(*total))
    return out

def geometry_counts(context,leading_heads=4,debug=False):
    tb=(context-1).bit_length();l=leading_heads+tb;n=l+tb
    old=[0,0,0];new=[0,0,0];extra=0;scale=0;weights_old=0;weights_new=0
    for j in range(n):
        half=1 << (n-j-1); samples=[5,3,3] if j==0 or debug else [4,2,2]
        old=[a+half*s for a,s in zip(old,samples)]
        new[0]+=half*samples[0];new[2]+=half*samples[2]
        weights_old+=half
        if j<l:
            ch=1 << (l-j-1);new[1]+=ch*samples[1]
            extra+=4*ch;weights_new+=ch
        else:
            new[1]+=1;extra+=2
        scale+=3
    return dict(context=context,t_pad=1<<tb,h_pad=1<<leading_heads,cube_log=n,
                ht_log=l,debug=debug,conditional_nonzero_recovery=not debug,
                baseline_bracket_calls=old,collapsed_bracket_calls=new,
                host_calls_removed=old[1]-new[1],extra_host_endpoint_reads=extra,
                multiplicity_scalings=scale,host_weight_multiplications_before=weights_old,
                host_weight_multiplications_after=weights_new,
                other_group_calls_unchanged=True,full_row_scan_and_all_folds_unchanged=True,
                note='Counts, not time. Initial data rounds only; no extensions/masks/PCS. Zero-factor fallback changes release sample counts.')

def main():
    limits();start=time.perf_counter();rng=random.Random(SEED);cc=Counter();controls=[];costs=[];digest=hashlib.sha256();saved=None
    for geometry,n,cfg,const,ir,words,originals,entries,rhos,draw,mode,points in fixtures(rng):
        cc['fixtures']+=1;groups=[Group(p,0,d) for p,d in zip(points,(4,2,2))]
        names=cfg['names'];l=len(points[1]);fn=lambda g,v:bracket(g,v,cfg,const)[0]
        plan=admit_plan(n,groups,names,l,tuple(('Rho',i) for i in range(l)),'Ht',0,'sum',const['nu0'],const['lam'])
        assert plan is not None
        prefix=[];messages=[]
        for j,r in enumerate(rhos):
            expected=original_groups(originals,ir,prefix,n)
            messages.append(expected);prefix.append(o.tup(r));cc['independent_group_samples']+=21
        finals=[F(*o.mle(a,list(map(o.tup,rhos)))) for a in originals]
        for chunk,debug in ((1,False),(7,True)):
            base=Grouped(Tables(n,copy.deepcopy(entries)),5,copy.deepcopy(groups),fn,chunk,debug)
            ev=Collapsed(Tables(n,copy.deepcopy(entries)),5,copy.deepcopy(groups),fn,chunk,debug,host=plan)
            assert ev.claims==[None]*3
            for j,r in enumerate(rhos):
                want=[sum((v[x] for v in messages[j]),F()) for x in range(6)]
                assert base.round(j)==want and ev.round(j)==want,(mode,n,j,chunk)
                assert ev.pending==base.pending
                for g in range(3):
                    assert ev.pending[g]==messages[j][g][:6]
                    assert interpolate(ev.pending[g],F(6))==messages[j][g][-1]
                    cc['candidate_group_samples']+=7
                for v in want:digest.update(v.wire())
                ev.bind(r);base.bind(r)
                assert ev.claims==base.claims
                cc['actual_claim_checks']+=3
            assert ev.finals()==base.finals()==finals
            cc['ordered_final_checks']+=len(finals)*2
            for g in range(3):
                if n:assert ev.claims[g]==finals[g]*fn(g,finals);cc['terminal_group_checks']+=1
            for g in (0,2):
                assert ev.counts['bracket_calls_'+str(g)]==base.counts['bracket_calls_'+str(g)]
                cc['other_group_call_invariance']+=1
            assert ev.counts['table_endpoint_reads']==base.counts['table_endpoint_reads']
            assert ev.tables.bind_calls==base.tables.bind_calls==n*len(entries)
            cc['scan_and_fold_invariance']+=1
            targets={name:draw() for name,private,_ in entries if private}
            for x in (F(),F(1),F(3,5)):
                vals=extend(finals,entries,targets,x)
                direct=[o.add(o.tup(a),o.mul(o.tup(x),o.sub(o.tup(targets[name]) if private else o.Z,o.tup(a)))) for a,(name,private,_) in zip(finals,entries)]
                assert list(map(o.tup,vals))==direct
                assert literal_poly(cfg,const)(vals)==F(*o.poly(list(enumerate(ir)),direct))
                cc['extension_table_checks']+=len(vals);cc['extension_polynomial_checks']+=1
            for k,v in ev.counts.items():cc[k]+=v
            costs.append(dict(context=geometry['tokens'],h_pad=geometry['h_pad'],cube_log=n,ht_log=l,mode=mode,debug=debug,
                baseline_calls=[base.counts['bracket_calls_'+str(g)] for g in range(3)],
                collapsed_calls=[ev.counts['bracket_calls_'+str(g)] for g in range(3)],
                extra_host_endpoint_reads=ev.counts['extra_host_endpoint_reads'],
                multiplicity_scalings=ev.counts['multiplicity_scalings']))
        if n>=6 and mode=='full' and saved is None:saved=(n,cfg,const,ir,words,originals,entries,rhos,groups,plan,messages)

    n,cfg,const,ir,words,originals,entries,rhos,groups,plan,messages=saved
    fn=lambda g,v:bracket(g,v,cfg,const)[0];names=cfg['names'];l=plan.leading
    good=dict(n=n,groups=groups,names=names,leading=l,coords=tuple(('Rho',i) for i in range(l)),support_domain='Ht',eq_start=0,sum_name='sum',nu=const['nu0'],lam=const['lam'])
    for name,change in [('trailing_private_coord',{'coords':tuple(('Rho',i) for i in range(l-1))+(('Rho',n-1),)}),
                         ('S_support_instead_of_Ht',{'support_domain':'S'}),('offset_equality',{'eq_start':1}),
                         ('wrong_plane_identity',{'sum_name':'s8'}),('wrong_ht_extent',{'leading':l-1})]:
        assert admit_plan(**{**good,**change}) is None;controls.append(name+'_fallback')
    ev=Collapsed(Tables(n,copy.deepcopy(entries)),5,groups,fn,host=None)
    for j,r in enumerate(rhos):
        want=[sum((v[x] for v in messages[j]),F()) for x in range(6)]
        assert ev.round(j)==want;ev.bind(r)
    assert ev.finals()==[F(*o.mle(a,list(map(o.tup,rhos)))) for a in originals]
    controls.append('unsupported_metadata_uses_original_grouped_path')
    # Deliberately bypass trusted construction: prove false invariance is fatal.
    for target,label in [(plan.sum_index,'arbitrary_sum_not_a_lift'),(plan.gate_index,'arbitrary_support_not_a_lift')]:
        changed=copy.deepcopy(entries);bad_words=copy.deepcopy(words);bad_words[target][1]+=F(1,2)
        changed[target]=(names[target],changed[target][1],Dense(n,bad_words[target]))
        bad_o=[list(map(o.tup,a)) for a in bad_words]
        true=original_groups(bad_o,ir,[],n)
        wrong=Collapsed(Tables(n,changed),5,groups,fn,host=plan).round(0)
        wanted=[sum((v[x] for v in true),F()) for x in range(6)]
        assert wrong!=wanted;controls.append(label+'_unsafe_attestation_detected')
    bad=HostPlan(l,plan.sum_index,cfg['index']['gs'],plan.nu,plan.lam)
    wrong=Collapsed(Tables(n,copy.deepcopy(entries)),5,groups,fn,host=bad).round(0)
    wanted=[sum((v[x] for v in messages[0]),F()) for x in range(6)]
    bad_ir=copy.deepcopy(ir)
    bad_ir[1]=[(coef,tuple(cfg['index']['gs'] if i==plan.gate_index else i for i in indices)) for coef,indices in bad_ir[1]]
    actual_s_group=original_groups(originals,bad_ir,[],n)
    actual_s_message=[sum((v[x] for v in actual_s_group),F()) for x in range(6)]
    assert actual_s_message!=wanted and wrong!=actual_s_message
    controls.append('S_support_substitution_full_cube_detected')
    bad=HostPlan(l,plan.sum_index,plan.gate_index,plan.nu+F(1),plan.lam)
    assert Collapsed(Tables(n,copy.deepcopy(entries)),5,groups,fn,host=bad).round(0)!=wanted
    controls.append('wrong_host_coefficient_detected')
    # Endpoints match while the product differs off-domain: retain full degree.
    q=lambda x:F(x)*(F(1)-F(x))
    assert q(0)==q(1)==0 and q(2)!=0;controls.append('quadratic_bracket_cannot_use_endpoint_only_interpolation')
    for label,action in [('round_order',lambda:Collapsed(Tables(n,copy.deepcopy(entries)),5,groups,fn,host=plan).round(1)),
                         ('early_final',lambda:Collapsed(Tables(n,copy.deepcopy(entries)),5,groups,fn,host=plan).finals())]:
        try:action()
        except ValueError:controls.append(label+'_refused')
        else:raise AssertionError(label)
    result=dict(run_id=RUN,cycle='0042',status='pass',seed=SEED,counts=dict(cc),controls=controls,control_count=len(controls),
        cost_rows=costs,geometry_counts=[geometry_counts(t,debug=d) for t in (512,1024,2048,4096) for d in (False,True)],
        digest_sha256=digest.hexdigest(),elapsed_seconds=time.perf_counter()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        hardware=dict(device='CPU only',cpu=next(l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),threads=1,affinity=sorted(os.sched_getaffinity(0)),nice=os.nice(0),python=platform.python_version()),
        resource_limits=dict(wall_seconds=59,cpu_seconds=59,address_space_mib=512,estimated_memory_mib=64),
        code_hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in HERE.glob('*.py')},
        proof_accounting=dict(accepted_complete_private8b_proofs=0,countable_tokens=0,context_length=None,passes=0,device='CPU only',
            steady_state_tokens_per_s=None,total_workload_tokens_per_s=None,startup_seconds=None,startup_fraction=None,witness_seconds=None,proof_seconds=None,serialization_seconds=None,independent_verification_seconds=None,proof_latency_seconds=None,proof_lag_seconds=None,pipeline_drain_seconds=None,prefill='none',resident_passes='none',decode='none'),
        limits=['Synthetic deliberately inconsistent SC_SZC planes, no honest witness/native proof',
                'Source-derived scheduling reference plus independent tuple original-cube/expanded polynomial oracle',
                'Provenance sketch is not integrated into native constructors; false attestations demonstrably unsound',
                'All original private/Eq folds and original final/extension equations retained',
                'No masked/transcript/RNG/PCS/refusal/native compiler/GPU/enclosing clocks tested'])
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ('status','counts','control_count','elapsed_seconds','peak_rss_kib','digest_sha256')},indent=2))

if __name__=='__main__':main()
