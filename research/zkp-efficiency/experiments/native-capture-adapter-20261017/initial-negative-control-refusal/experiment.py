"""Bounded CPU arithmetic/metadata differential; never complete proof tokens."""
import ast
from collections import Counter
from dataclasses import replace,FrozenInstanceError
import datetime,hashlib,itertools,json,os,platform,random,resource,signal,time
from pathlib import Path
from field_support import F,P
from adapter import carriers,config,eligible,compile_capture,proof_arguments,rust_artifact
from native_fixture import fixture
from reference import groups,old_full,cv,add,mul,scalar
from source_port import bracket

HERE=Path(__file__).resolve().parent
SEED=2026101757


def main():
    resource.setrlimit(resource.RLIMIT_AS,(512*1024*1024,512*1024*1024))
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    os.nice(19);allowed=os.sched_getaffinity(0);os.sched_setaffinity(0,{min(allowed)})
    start=time.perf_counter();rng=random.Random(SEED);counts=Counter();controls={};digest=hashlib.sha256()
    draw=lambda:F(rng.randrange(P),rng.randrange(P))
    generated=HERE/'generated';generated.mkdir(exist_ok=True);stats=[]
    pins=json.loads((HERE/'native-pins.json').read_text())
    for pin in pins:
        assert hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'],pin['path']
        counts['native_source_measurement_pins']+=1
    source=(HERE/'native/argument.rs').read_text();layout=(HERE/'native/layout.rs').read_text()
    # Static source assertions anchor the independent fixture model. They
    # complement hashes; they are not Rust compilation or native captures.
    markers=['b.eq(&tau, 0);','b.eq(&pts.p_ht, 0);','b.eq(&pts.p_s, 0);',
             'let im = b.public(causal_mask_at(sh));','let idx = b.a_range(ids.at(A_S8), ids.sg(ls - 1))?;',
             'let h0 = b.h(hids.first_helper(Dom::S))?;','let ihx = b.h(hids.sexp())?;',
             'let ght = Gate(b.supp(Dom::Ht, cube)?);','let gs = Gate(b.supp(Dom::S, cube)?);']
    arm=source[source.index('        SC_SZC => {'):source.index('        SC_TAB => {')]
    positions=[arm.index(x) for x in markers];assert positions==sorted(positions);counts['constructor_order_markers']=len(markers)
    for name,n in [('A_S8',56),('A_RSL',57),('A_ZSEL',58),('A_E',59),('A_P',60),('N_A',81),('LN_TOY',4),('LS_TOY',2),('LP_TOY',2)]:
        assert f'const {name}: usize = {n};' in layout;counts['layout_constants']+=1
    pairs_to_check=[];compile_cache={}
    # Both native-order and relocated frames; native formula with ls2/3,
    # lp2 plus a generic lp3 extension; odd/even and reduced-query controls.
    for ls,lp,subset,relocated in itertools.product((2,3),(2,3),(None,7,8),(False,True)):
        for pad_on,supports in [(False,(False,False)),(True,(False,False)),
                                (True,(True,False)),(True,(False,True)),(True,(True,True))]:
            cap,rawcst=fixture(ls,lp,pad_on,supports,subset,relocated,rng)
            cfg,native=config(cap);counts['capture_layouts']+=1
            assert tuple(native)==tuple(i for _,i in carriers(cap))
            assert len(set(native))==len(native);counts['mapping_bijections']+=1
            try:cap.im=0
            except FrozenInstanceError:counts['frozen_capture_controls']+=1
            else:raise AssertionError('mutable capture')
            # Select by public round/profile/dependency metadata only.
            assert not eligible(cap,1,False);counts['later_round_fallbacks']+=1
            if pad_on:
                assert not eligible(cap,0,False);counts['pad_profile_fallbacks']+=1
            for mode in ('full','base','zero','boolean'):
                dr=draw if mode=='full' else (lambda:F(rng.randrange(P))) if mode=='base' else (lambda:F()) if mode=='zero' else (lambda:F(rng.randrange(2)))
                params={n:dr() for n in ['alpha','beta','gexp','gu8','lam','nu0','nu1','zeta','mupad']+['mu'+str(j) for j in range(6+cap.n_help)]}
                for n in ('nu0','nu1','zeta'):
                    if params[n]==0:params[n]=F(1)
                params['lk_cst']=tuple(F(c)+params['gu8'] for c in rawcst)
                v=[dr() for _ in range(cap.n_tabs)];d=[dr() for _ in v]
                # Original source-port scalar is a third oracle with an
                # independent compact array; only the candidate avoids gather.
                scfg=dict(cfg);scfg['lookups']=[(i,c,rawcst[j]) for j,(i,c,_) in enumerate(cfg['lookups'])]
                compact=[v[i] for i in native]
                expected=groups(cap,v,params)
                for group in range(3):
                    got,_=bracket(group,compact,scfg,params)
                    assert cv(got)==expected[group],('scalar',ls,lp,subset,pad_on,supports,group)
                    counts['independent_scalar_group_checks']+=1
                # Group order and Eq multiplication agree with the old
                # ungrouped captured-index expression at arbitrary points.
                full=old_full(cap,v,params)
                assert full==add(add(mul(cv(v[0]),expected[0]),mul(cv(v[1]),expected[1])),mul(cv(v[2]),expected[2]))
                counts['full_polynomial_checks']+=1
                digest.update(b''.join(a.to_bytes(8,'little')+b.to_bytes(8,'little') for a,b in expected))
                if pad_on:continue
                const,offsets=proof_arguments(cap,params)
                for active in (False,True):
                    dif=list(d)
                    if not active:dif[cap.im]=F()
                    for scheduled in (False,True):
                        key=(cap,active,scheduled)
                        if key not in compile_cache:
                            compile_cache[key]=compile_capture(cap,active,scheduled)
                            fn,body,st,_,g,out=compile_cache[key]
                            tag=f'ls{ls}-lp{lp}-lk{len(cap.lks)}-reloc{int(relocated)}-mask{int(active)}-sched{int(scheduled)}'
                            (generated/(tag+'.py')).write_text(body)
                            # No comprehension/gather/loop/branch in row helper.
                            tree=ast.parse(body)
                            assert not any(isinstance(x,(ast.For,ast.While,ast.If,ast.ListComp,ast.GeneratorExp)) for x in ast.walk(tree))
                            counts['direct_branchless_helpers']+=1
                            if ls==3 and lp==2 and subset is None and not relocated and active and scheduled:
                                (generated/'native-capture-round0.rs').write_text(rust_artifact(g,out))
                                stats.append({'tag':tag,**st})
                        fn,*_=compile_cache[key]
                        co=fn(v,dif,const,offsets)
                        assert len(co)==4
                        for t in [F(0),F(1),F(2),F(3),draw(),F(0,1)]:
                            row=[a+t*b for a,b in zip(v,dif)]
                            want=groups(cap,row,params)[0]
                            value=sum((x*(t*t*t if i==3 else t*t if i==2 else t if i==1 else F(1)) for i,x in enumerate(co)),F())
                            assert cv(value)==want,('factory',ls,lp,subset,relocated,mode,active,scheduled,t.a,t.b)
                            counts['factory_extension_sample_checks']+=1
                            digest.update(value.wire())
                if mode=='full' and ls==3 and lp==2 and subset is None and not relocated:
                    pairs_to_check.append((cap,params,v,d))
    cap,params,v,d=pairs_to_check[0];const,offsets=proof_arguments(cap,params)
    fn,*_=compile_cache[(cap,True,True)]
    def ev(c,p= params):
        cc,oo=proof_arguments(c,p);ff,*_=compile_capture(c,True,False)
        return ff(v,d,cc,oo)
    want=fn(v,d,const,offsets)
    for name,bad in [('swap_max_sum',replace(cap,imx=cap.isum,isum=cap.imx)),
                     ('omit_third_sigma_limb',replace(cap,i_sr=cap.i_sr[:2],i_sg=cap.i_sg[:2])),
                     ('swap_lookup_order',replace(cap,lks=(cap.lks[1],cap.lks[0])+cap.lks[2:]))]:
        assert ev(bad)!=want,name;controls[name]='differential mismatch detected'
    stale=tuple(x+F(1) for x in offsets)
    assert fn(v,d,const,stale)!=want;controls['stale_proof_offsets']='detected'
    wrongmask,*_=compile_cache[(cap,False,True)]
    assert wrongmask(v,d,const,offsets)!=want;controls['false_public_mask_dependency']='detected; native dependency derivation still required'
    malformed=[('helper_off_by_one',replace(cap,h0=cap.h0+1)),
               ('out_of_bounds',replace(cap,im=cap.n_tabs)),
               ('helper_count',replace(cap,n_help=cap.n_help+1)),
               ('support_without_pad',replace(cap,gs=cap.im)),
               ('short_idx_sentinel',replace(cap,idx=tuple(None if i==56 else x for i,x in enumerate(cap.idx))))]
    for name,bad in malformed:
        try:carriers(bad)
        except (ValueError,IndexError):controls[name]='adapter metadata refusal'
        else:raise AssertionError(name)
    general=replace(cap,lks=(((cap.idx[56],1),(cap.idx[57],2)),)+cap.lks[1:])
    assert not eligible(general,0,True);controls['multi_term_lookup']='scalar fallback; no relation change'
    # Optional supports can be None independently. Mutations affect the
    # old scalar relation even though those cases never enter the fast path.
    padded,rc=fixture(3,2,True,(True,True))
    pp=dict(params);pp['lk_cst']=tuple(F(x)+pp['gu8'] for x in rc)
    vv=[draw() for _ in range(padded.n_tabs)]
    for mutation in ('ht_uses_s','restart_zeta'):
        assert groups(padded,vv,pp,mutation)!=groups(padded,vv,pp);controls[mutation]='detected'
    # Two proofs share only public code/capture key; fresh offsets/constants
    # change the result and never enter compile_cache's public-only key.
    pp=dict(params);pp['alpha']=draw();pp['gu8']=draw();pp['lk_cst']=tuple(F(c)+pp['gu8'] for c in (127,127)+tuple(0 for _ in range(len(cap.lks)-2)))
    cc,oo=proof_arguments(cap,pp);fresh=fn(v,d,cc,oo)
    assert fresh!=want;assert cv(fresh[0])==groups(cap,v,pp)[0]
    counts['proof_local_refresh_checks']+=1
    result={'status':'pass','cycle':'0057','run_id':'20261017T072624Z-c38c878c','seed':SEED,
            'counts':dict(counts),'controls':controls,'compiled_helpers':len(compile_cache),
            'full_head_stats':stats,'output_sha256':digest.hexdigest(),
            'wall_seconds':time.perf_counter()-start,'max_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            'hardware':{'cpu':platform.processor(),'affinity':sorted(os.sched_getaffinity(0)),'threads':1,'nice':os.nice(0),'gpu':None},
            'limits':{'wall_seconds':59,'memory_bytes':512*1024*1024,'estimated_bytes':96*1024*1024},
            'scope':'Synthetic native-shaped captures; source-derived tuple oracle and Python helpers. Rust emitted but uncompiled; no native constructor capture or transcript/RNG/proof/verifier executed.',
            'dimensions':{'ls':[2,3],'lp':[2,3],'lookup_count':'full or 7 or 8; subsets and lp3 synthetic','row_cells':2,'sample_points_per_row':6,'frame':'native-order and relocated; helpers contiguous','pad_profiles':'off; on with none/Ht/S/both optional supports'},
            'proof_accounting':{'completed_independently_verified_8b_proofs':0,'completed_passes':0,'proved_tokens':0,'context_length':None,'device':'Intel Core Ultra 9 185H CPU only','steady_state_tokens_per_second':None,'total_workload_tokens_per_second':None,'startup_seconds':None,'startup_fraction':None,'witness_seconds':None,'proof_seconds':None,'serialization_seconds':None,'verification_seconds':None,'proof_latency_seconds':None,'prefill_ran':False,'resident_pass_ran':False,'decode_ran':False}}
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))


if __name__=='__main__':main()
