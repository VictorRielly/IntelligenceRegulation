"""Single-thread bounded synthetic differential, never complete proof tokens."""
from pathlib import Path
import collections, dataclasses, hashlib, itertools, json, os, random, resource
import signal, sys, time
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE/'support'))
from field_support import F,P
from reference import cv,add,mul,sub,groups
from adapter import compile_capture,proof_arguments
from native_fixture import fixture
from selector import MaskLayout,dependency,round0_mask_active,mask_mle

SEED=2026101758


def fold(a,r):
    half=len(a)//2
    return [x+r*(y-x) for x,y in zip(a[:half],a[half:])]


def bits(i,n):
    return tuple((i>>(n-1-j))&1 for j in range(n))


def literal_table(layout):
    # Source-derived native index formula, independent of comparator recursion.
    t=layout.token_extent
    return [F(int(x%t <= (x//t)%t))
            for x in range(layout.head_slots*t*t)]


def independent_dense_eval(table,point):
    # Schoolbook original-cube sum using separate tuple field arithmetic.
    answer=(0,0)
    for i,value in enumerate(table):
        weight=(1,0)
        for b,x in zip(bits(i,len(point)),point):
            weight=mul(weight,cv(x) if b else sub((1,0),cv(x)))
        answer=add(answer,mul(cv(value),weight))
    return answer


def main():
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    started=time.perf_counter();rng=random.Random(SEED);counts=collections.Counter()
    controls={};digest=hashlib.sha256();summaries=[]
    draw=lambda:F(rng.randrange(P),rng.randrange(P))
    for pin in json.loads((HERE/'native-pins.json').read_text()):
        assert hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256']
        counts['source_measurement_pins']+=1
    source=(HERE/'native/argument.rs').read_text()
    for marker in ['x % t <= (x / t) % t','Tab::Pub(v) => sel.mul(eval_mle_ext(v, &rho))',
                   'rho_full.extend_from_slice(&es);','let mut prev = rho.clone();',
                   '_ => Fp2::ZERO,']:
        assert marker in source;counts['source_semantic_markers']+=1
    specs=[('degenerate',1,1,1,1),('one-head',1,4,1,4),
           ('two-head-small',2,4,2,4),('four-head',4,8,4,8),
           ('head-and-token-padded',8,8,6,6),('toy-dimensions',2,32,2,32),
           ('full-head-short-token-axis',32,8,32,8),('head-padded-only',16,8,12,8),
           ('one-head-token-padded',1,8,1,6)]
    for name,h,t,trueh,truet in specs:
        n=(h.bit_length()-1)+2*(t.bit_length()-1)
        layout=MaskLayout(h,t,trueh,truet,n)
        deps=dependency(layout);assert deps is not None
        table=literal_table(layout);assert len(table)==1<<n
        counts['layouts']+=1
        for mode in ('extension','base','boolean'):
            point=[draw() if mode=='extension' else F(rng.randrange(P)) if mode=='base'
                   else F(rng.randrange(2)) for _ in range(n)]
            exts=[draw() if mode=='extension' else F(rng.randrange(P)) if mode=='base'
                  else F(rng.randrange(2))]
            cur=table[:]
            # All pairs of every native MSB data-round split after an arbitrary
            # prefix, including a head prefix folded at non-Boolean challenges.
            for j in range(n):
                half=len(cur)//2;nonzero=0
                for i in range(half):
                    difference=cur[i+half]-cur[i]
                    if difference!=0:nonzero+=1
                    if not deps[j]:
                        assert difference==0;counts['constant_pair_differences']+=1
                    suffix=[F(x) for x in bits(i,n-j-1)]
                    for b,want in ((0,cur[i]),(1,cur[i+half])):
                        got=mask_mle(layout,point[:j]+[F(b)]+suffix,[F()],F(1))
                        assert got==want,(name,mode,j,i,b)
                        counts['descriptor_pair_endpoints']+=1
                if mode=='extension' and deps[j]:
                    assert nonzero>0,(name,j,'structural active axis unexercised')
                    counts['active_axis_witnesses']+=1
                cur=fold(cur,point[j]);counts['data_round_folds']+=1
            got=mask_mle(layout,point,exts,F(1))
            want=independent_dense_eval(table,point)
            want=mul(want,sub((1,0),cv(exts[0])))
            assert cv(got)==want
            counts['independent_full_extension_evaluations']+=1
            # Native terminal extension is a separate scalar interpolation to0.
            assert got==cur[0]+exts[0]*(F()-cur[0])
            counts['native_terminal_extension_models']+=1
            digest.update(got.wire())
        pad_on=trueh!=h or truet!=t
        chosen=round0_mask_active(layout,pad_on)
        assert chosen is (None if pad_on or n==0 else deps[0])
        summaries.append({'name':name,'h_pad':h,'t_pad':t,'true_heads':trueh,
                          'true_tokens':truet,'main_rounds':n,'extension_rounds':1,
                          'dependency':deps,'round0_dispatch':chosen})

    # Same-field arbitrary-row helper differential with actual literal mask
    # endpoints. The helper sees random synthetic rows, not real activations.
    compiled={};saved=None
    for name,h,t in [('one-head',1,4),('toy',2,32),('full-head',32,8)]:
        n=h.bit_length()-1+2*(t.bit_length()-1)
        layout=MaskLayout(h,t,h,t,n);table=literal_table(layout)
        active=round0_mask_active(layout,False);assert type(active) is bool
        for ls in (2,3):
            cap,cst=fixture(ls,2,False,(False,False))
            params={key:draw() for key in ['alpha','beta','gexp','gu8','lam','nu0','nu1','zeta','mupad']+
                    ['mu'+str(j) for j in range(6+cap.n_help)]}
            params['lk_cst']=tuple(F(c)+params['gu8'] for c in cst)
            key=(ls,active)
            if key not in compiled:
                compiled[key]=compile_capture(cap,active,True)
                counts['generated_helpers']+=1
            fn,body,stats,*_=compiled[key]
            const,offsets=proof_arguments(cap,params)
            # Cover every mask endpoint pair shape plus bounded row diversity.
            pairs={ (table[i].a,table[i+len(table)//2].a)
                    for i in range(len(table)//2) }
            for pair in sorted(pairs):
                for repeat in range(4):
                    values=[draw() for _ in range(cap.n_tabs)]
                    differences=[draw() for _ in values]
                    values[cap.im]=F(pair[0]);differences[cap.im]=F(pair[1]-pair[0])
                    coeffs=fn(values,differences,const,offsets)
                    for x in (F(),F(1),F(2),F(3),F(0,1),draw()):
                        actual=[v+x*d for v,d in zip(values,differences)]
                        want=groups(cap,actual,params)[0]
                        got=coeffs[0]+x*(coeffs[1]+x*(coeffs[2]+x*coeffs[3]))
                        assert cv(got)==want,(name,ls,pair,repeat)
                        counts['captured_helper_sample_checks']+=1;digest.update(got.wire())
                    if name=='one-head' and pair[0]!=pair[1] and saved is None:
                        saved=(cap,params,values,differences,layout)

    # Public metadata corruption always selects scalar fallback in the model.
    base=MaskLayout(8,8,6,6,9)
    mutations={'axes':{'axes':('t','head','j')},'lsb':{'split':'lsb'},
               'wrong_main':{'main_rounds':10},'wrong_extension_count':{'extension_rounds':2},
               'nonzero_public_endpoint':{'extension_endpoint':'one'},
               'support_fused_into_causal':{'mask_rule':'j_le_t_and_true_support'},
               'nonpower_heads':{'head_slots':6},'nonpower_tokens':{'token_extent':6},
               'zero_true_heads':{'true_heads':0},'too_many_tokens':{'true_tokens':9}}
    for label,delta in mutations.items():
        bad=dataclasses.replace(base,**delta)
        assert dependency(bad) is None and round0_mask_active(bad,False) is None
        controls[label]='scalar fallback'
    assert round0_mask_active(base,True) is None
    assert round0_mask_active(base,False,1) is None
    controls['padded_profile']='scalar fallback even when mask head differences are0'
    controls['later_round']='scalar fallback; no new later-round helper'
    # Using the true-head support in a causal table changes padded head slots.
    table=literal_table(base)
    assert table[6*64]==F(1)
    controls['true_head_zero_fill']='detected against native literal at padded head6,t0,j0'
    assert table[7*64+7*8+6]==F(1)
    controls['true_token_zero_fill']='detected against native literal at padded t7,j6'
    point=[draw() for _ in range(9)];ext=draw()
    correct=mask_mle(base,point,[ext],F(1));unextended=mask_mle(base,point,[F()],F(1))
    assert correct!=unextended
    controls['omit_terminal_zero_extension']='differential mismatch'
    assert mask_mle(base,point[:3]+list(reversed(point[3:])),[ext],F(1))!=correct
    controls['swap_t_j_points']='differential mismatch'
    # Head independence holds at arbitrary points, not just Boolean vertices.
    assert mask_mle(base,[draw() for _ in range(3)]+point[3:],[ext],F(1))==correct
    controls['change_head_point']='expected invariance, no arithmetic saving'
    cap,params,values,differences,layout=saved
    wrong,*_=compile_capture(cap,False,True)
    const,offsets=proof_arguments(cap,params);co=wrong(values,differences,const,offsets)
    x=draw();row=[v+x*d for v,d in zip(values,differences)]
    got=co[0]+x*(co[1]+x*(co[2]+x*co[3]))
    assert cv(got)!=groups(cap,row,params)[0]
    controls['false_head_axis_constant_flag']='helper differential mismatch'

    # Target-layout accounting only: never allocate an8B-sized score cube.
    accounting=[]
    for h,t in [(2,32),(16,512),(32,512),(32,1024),(32,4096)]:
        layout=MaskLayout(h,t,h,t,h.bit_length()-1+2*(t.bit_length()-1))
        q=[draw() for _ in range(layout.main_rounds)]
        a=mask_mle(layout,q,[draw()],F(1));digest.update(a.wire())
        accounting.append({'h_pad':h,'t_pad':t,'mask_field_elements':h*t*t,
             'materialized_mask_bytes':16*h*t*t,'comparator_bits':t.bit_length()-1,
             'avoided_vector_bytes_if_verifier_descriptor_integrated':16*h*t*t,
             'native_runtime_measured':False})
    result={'status':'pass','cycle':'0058','run_id':'20261017T082624Z-8668a63c',
            'seed':SEED,'counts':dict(counts),'controls':controls,'layouts':summaries,
            'allocation_free_accounting':accounting,'output_sha256':digest.hexdigest(),
            'wall_seconds':time.perf_counter()-started,
            'max_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            'hardware':{'cpu':'Intel Core Ultra9 185H','affinity':sorted(os.sched_getaffinity(0)),
                        'threads':1,'nice':os.getpriority(os.PRIO_PROCESS,0),'gpu':None},
            'limits':{'wall_seconds':59,'memory_bytes':512*1024**2,'estimated_bytes':96*1024**2},
            'scope':'Synthetic metadata and exact field differential; native source pinned, no native capture/Rust compile/transcript/RNG/proof/verifier run.',
            'proof_accounting':{'completed_independently_verified_private_8b_proofs':0,
               'passes':0,'tokens':0,'context_length':None,'steady_state_tokens_per_second':None,
               'total_workload_tokens_per_second':None,'startup_seconds':None,'startup_fraction':None,
               'witness_seconds':None,'proof_seconds':None,'serialization_seconds':None,
               'verification_seconds':None,'proof_latency_seconds':None,
               'prefill_ran':False,'resident_pass_ran':False,'decode_ran':False}}
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__':main()
