#!/usr/bin/env python3
"""Bounded synthetic differential/census, not native proof performance."""
from pathlib import Path
import ctypes as C
import datetime, hashlib, json, math, os, random, resource, signal
import statistics, struct, subprocess, time

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
SEED=2026101760
os.nice(19)
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
resource.setrlimit(resource.RLIMIT_CPU,(59,59))
signal.alarm(59)
start=time.perf_counter()
rng=random.Random(SEED)
experiment_tmp=HERE/'compiler-tmp';experiment_tmp.mkdir(exist_ok=True)
compile_environment=dict(os.environ,TMPDIR=str(experiment_tmp))
command=['/usr/bin/gcc','-O3','-std=c11','-shared','-fPIC','-Wall','-Wextra','-Werror',str(HERE/'kernels.c'),'-o',str(HERE/'kernels.so')]
build=subprocess.run(command,capture_output=True,text=True,timeout=20,env=compile_environment)
(HERE/'compile.log').write_text(build.stdout+build.stderr)
assert build.returncode==0,build.stderr
lib=C.CDLL(str(HERE/'kernels.so')); mm=lib.mm
mm.argtypes=[C.c_int,C.c_int]+[C.c_size_t]*6+[C.POINTER(C.c_int64),C.POINTER(C.c_int8),C.POINTER(C.c_int8),C.POINTER(C.c_int64)]
mm.restype=C.c_int
counts={'fixtures':0,'raw_dot_reference_checks':0,'kernel_output_checks':0,'requant_reference_checks':0,'padding_checks':0}
digest=hashlib.sha256()

def arrays(x,w,rowcap,k,os_):
    return ((C.c_int64*len(x))(*x),(C.c_int8*len(w))(*w),(C.c_int8*max(1,rowcap*k))(),(C.c_int64*max(1,rowcap*os_))())

def call(v,ori,t,tp,k,n,xs,os_,a):
    ret=mm(v,ori,t,tp,k,n,xs,os_,*a)
    assert ret==0,ret
    return list(a[-1])[:tp*os_]

def oracle(x,w,t,tp,k,n,xs,os_,ori):
    out=[0]*(tp*os_)
    # Different loop order and mathematical unbounded integer accumulator.
    for i in range(k):
        for j in range(n):
            weight=w[i*n+j] if ori else w[j*k+i]
            for row in range(t): out[row*os_+j]+=int(x[row*xs+i])*int(weight)
    return out

def requant_oracle(acc,sh):
    if not sh:return acc,0
    den=2**sh; q,r=divmod(acc,den)
    q+=2*r>=den
    return q,acc-q*den+den//2

def native_requant_model(acc,sh):
    half=2**(sh-1) if sh else 0
    q=(acc+half)>>sh
    return q,acc-(q<<sh)+half

for ori in [0,1]:
    for case in range(100):
        t=rng.randrange(1,5);tp=1<<(t-1).bit_length()
        k=rng.choice([1,2,3,7,16,31,64,65,129])
        n=rng.choice([1,2,3,7,16,63,64,65,70])
        xs=k+rng.randrange(3);os_=n+rng.randrange(3)
        x=[rng.choice([-127,127,0,rng.randrange(-127,128)]) for _ in range(tp*xs)]
        w=[rng.choice([-128,127,0,rng.randrange(-128,128)]) for _ in range(k*n)]
        ref=oracle(x,w,t,tp,k,n,xs,os_,ori)
        counts['raw_dot_reference_checks']+=t*n
        a=arrays(x,w,tp,k,os_)
        for v in [0,1,2]:
            got=call(v,ori,t,tp,k,n,xs,os_,a)
            assert got==ref
            counts['kernel_output_checks']+=len(ref)
            for row in range(t):
                for j in range(n):
                    acc=got[row*os_+j]
                    for sh in [0,1,4,8,9,16]:
                        assert native_requant_model(acc,sh)==requant_oracle(acc,sh)
                        counts['requant_reference_checks']+=1
            for row in range(tp):
                for j in range(os_):
                    if row>=t or j>=n:
                        assert got[row*os_+j]==0
                        counts['padding_checks']+=1
        counts['fixtures']+=1
        digest.update(json.dumps(ref).encode())

# Full native inner widths, only one synthetic output each; no model weights.
extremes=[]
for k in [2048,4096,8192,16384]:
    for xv,wv in [(-127,-128),(-127,127),(127,-128),(127,127)]:
        for ori in [0,1]:
            a=arrays([xv]*k,[wv]*k,1,k,1)
            got=call(2,ori,1,1,k,1,k,1,a)[0]
            assert got==k*xv*wv
            extremes.append({'k':k,'x':xv,'w':wv,'dot':got,'orientation':ori})
            counts['raw_dot_reference_checks']+=1

controls={}
def control(name,condition):
    assert condition,name
    controls[name]='detected'

a=arrays([128],[1],1,1,1)
control('unchecked narrow cast of128',mm(2,1,1,1,1,1,1,1,*a)==-2)
a=arrays([-128],[1],1,1,1)
control('norm class excludes minus128',mm(2,1,1,1,1,1,1,1,*a)==-2)
# Shape-only overflow check runs before reading undersized test arrays.
control('shape K above exact i32 bound',mm(2,1,1,1,2**31//(127*128)+1,1,2**31,1,*a)==-1)
x=[1,2]; w=[1,2,3,5];a=arrays(x,w,1,2,2)
control('transpose orientation',call(2,0,1,1,2,2,2,2,a)!=call(2,1,1,1,2,2,2,2,a))
a=arrays([0,11],[1,1],1,2,1)
control('drop supplied padded K coordinate',call(2,0,1,1,2,1,2,1,a)[0]!=0)
a=arrays([127],[-128],1,1,1)
control('unsigned weight conversion',call(2,0,1,1,1,1,1,1,a)[0]!=127*128)
control('ties to even changes native plus infinity',native_requant_model(1,1)[0]!=round(1/2))
control('negative tie ties-to-even changes quotient and remainder',native_requant_model(-3,1)!=(-2,2))
control('partial K requantization',native_requant_model(2,1)[0] != 2*native_requant_model(1,1)[0])
# FP32 reduction loses cancellation despite a small and valid FINAL quotient.
f32=lambda x:struct.unpack('f',struct.pack('f',x))[0]
terms=[127*127]*1041+[127*123]+[-127*127]*1041+[-127*123]+[1]
acc=0.
for term in terms:acc=f32(acc+term)
control('FP32 accumulation loses cancellation',int(acc)!=sum(terms))
# Down is int16; a wrapping int32 path can turn a refused result into zero.
target=2**32
term=32767*127; rep,rem=divmod(target,term)
xs=[32767]*rep;ws=[127]*rep
q,r=divmod(rem,32767)
if q:xs.append(32767);ws.append(q)
if r:xs.append(r);ws.append(1)
assert sum(a*b for a,b in zip(xs,ws))==target
wrap=lambda a:((a+2**31)%2**32)-2**31
control('wrongly route int16 down to direct i32',native_requant_model(target,8)[0]>32767 and native_requant_model(wrap(target),8)[0]==0)
# Both genuine matmuls fail; a fused schedule must still report gate first.
a=arrays([127]*3,[127]*3,1,3,1)
gate=call(2,1,1,1,3,1,3,1,a)[0]
up=call(2,1,1,1,3,1,3,1,a)[0]
def first_refusal(order):
    for site,acc,sh,lo,hi in order:
        q,_=native_requant_model(acc,sh)
        if not lo<=q<=hi:return site
    return None
stages=[('FFN gate',gate,1,-128,127),('FFN up',up,0,-32768,32767)]
control('up failure before gate refusal',first_refusal(stages)=='FFN gate' and first_refusal(stages[::-1])=='FFN up')

# Tiny public synthetic CPU timings: all arms include memset/packing/widening;
# common caller allocations excluded. C does not reproduce Rust compiler code.
benches=[]
for ori in [0,1]:
    for t,k,n in [(4,128,256),(8,256,512),(4,512,1024)]:
        x=[rng.randrange(-127,128) for _ in range(t*k)]
        w=[rng.randrange(-128,128) for _ in range(k*n)]
        a=arrays(x,w,t,k,n)
        baseline=call(0,ori,t,t,k,n,k,n,a)
        for v in [1,2]:assert call(v,ori,t,t,k,n,k,n,a)==baseline
        # Independent Python sample dots do not share the C baseline.
        for _ in range(12):
            row=rng.randrange(t);j=rng.randrange(n)
            ref=sum(x[row*k+i]*w[i*n+j if ori else j*k+i] for i in range(k))
            assert baseline[row*n+j]==ref
            counts['raw_dot_reference_checks']+=1
        times={v:[] for v in [0,1,2]}
        for trial in range(7):
            order=[0,1,2] if trial%2==0 else [2,1,0]
            for v in order:
                before=time.perf_counter()
                for _ in range(3):assert mm(v,ori,t,t,k,n,k,n,*a)==0
                times[v].append((time.perf_counter()-before)/3)
        med={v:statistics.median(z) for v,z in times.items()}
        benches.append({'orientation':'IO' if ori else 'OI','T':t,'K':k,'N':n,'macs':t*k*n,'seconds_samples':times,'median_seconds':med,'wide_over_narrow':med[0]/med[1],'wide_over_tiled':med[0]/med[2],'scope':'shared CPU synthetic C helper incl pack/zero/widen; common allocations excluded; not Rust/native/model proof'})

# Allocation-free census derived from the ACTUAL padded witness loops.
profiles=[]
for label,t,d,f,h,dh,kv,layers in [('TinyLlama-trained-T32',32,2048,5632,32,64,4,22),('Llama3-8B-hypothetical-T512',512,4096,14336,32,128,8,32)]:
    dp=1<<(d-1).bit_length();fp=1<<(f-1).bit_length();kvw=kv*dh
    sites=[('Q',dp,dp,'OI',127),('K',dp,kvw,'OI',127),('V',dp,kvw,'OI',127),('AO',dp,dp,'OI',127),('gate',dp,fp,'IO',127),('up',dp,fp,'IO',127),('down',fp,dp,'IO',32768)]
    entries=[{'name':name,'K':k,'N':n,'orientation':ori,'activation_abs_bound':bound,'acc_abs_bound':k*bound*128,'direct_i32_exact':k*bound*128<=2**31-1,'macs_one_build':t*k*n} for name,k,n,ori,bound in sites]
    total=sum(e['macs_one_build'] for e in entries);direct=sum(e['macs_one_build'] for e in entries if e['direct_i32_exact'])
    # Score/PV operation counts, distinct from seven projections.
    score=h*t*t*dh;pv=h*dh*t*(t+1)//2
    profiles.append({'name':label,'T':t,'D':d,'F':f,'Dpad':dp,'Fpad':fp,'kv_width':kvw,'layers':layers,'sites':entries,'projection_macs_one_build':total,'direct_i32_projection_mac_fraction':direct/total,'direct_i32_projection_macs':direct,'score_macs_all_future_pairs':score,'pv_macs_causal':pv,'double_build_projection_macs_whole_stack':2*layers*total,'split_down_extra_mac_fraction_if_two_products':entries[-1]['macs_one_build']/total,'scope':'allocation-free source-loop counts, no time, profiles beyond T32 not admitted'})

# Retained public log audit only: do not open any prompt/activation/weight data.
records=[]
native=ROOT/'results/zk60_1b_native_20261017/r2'
for device in ['cpu','gpu']:
    p=native/f'stack-pg_rot1-ho00-{device}'
    logs={name:(p/name).read_text() for name in ['prove.log','verify.log']}
    rows={name:[json.loads(line) for line in txt.splitlines() if line.startswith('{')] for name,txt in logs.items()}
    proved=next(x for x in rows['prove.log'] if x.get('event')=='proved')
    verified=next(x for x in rows['verify.log'] if x.get('event')=='verified')
    assert proved['blocks']==verified['blocks']==22
    assert proved['receipt_bytes']==verified['receipt_bytes']
    assert proved['statement_identity']==verified['statement_identity']
    witness=proved['sealing_pass_seconds']+proved['of_which_witness_rebuild_seconds']
    records.append({'device_label':device,'proved_log_event':proved,'fresh_verifier_log_event':verified,'two_witness_seconds':witness,'witness_fraction_of_reported_total':witness/proved['total_seconds'],'prove_run_excluding_witness_rebuild_inclusive_seconds':proved['prove_run_seconds']-proved['of_which_witness_rebuild_seconds'],'delete_all_witness_upper_bound_factor':proved['total_seconds']/(proved['total_seconds']-witness),'delete_sealing_only_upper_bound_factor':proved['total_seconds']/(proved['total_seconds']-proved['sealing_pass_seconds']),'reported_run_positions_per_second':32/proved['total_seconds'],'steady_rate':None,'startup_seconds':None,'startup_fraction':None,'serialization_seconds':None,'verification_scope':'owner-retained fresh-process log, not rerun by explorer; privacy acceptance at shape missing; no8B tokens','sha256':{name:hashlib.sha256(txt.encode()).hexdigest() for name,txt in logs.items()}})

cpu=next(x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name'))
result={'status':'pass','cycle':'0060','run_id':'20261017T102624Z-c13de864','seed':SEED,'counts':counts,'controls':controls,'extremes':extremes,'cpu_microbenchmarks':benches,'source_loop_census':profiles,'retained_linked_stack_accounting':records,'float_cancellation_control':{'exact_sum':sum(terms),'f32_sum':acc,'terms':len(terms)},'direct_i32_K_max':(2**31-1)//(127*128),'down_control_terms':len(xs),'output_sha256':digest.hexdigest(),'hardware':{'cpu':cpu,'threads':1,'affinity':sorted(os.sched_getaffinity(0)),'nice':19,'gpu':None},'compile_command':command,'compile_returncode':build.returncode,'compiler_version':subprocess.run(['/usr/bin/gcc','--version'],capture_output=True,text=True,timeout=2).stdout.splitlines()[0],'experiment_wall_seconds':time.perf_counter()-start,'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'compiler_child_peak_rss_kib':resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,'limits':{'wall_cpu_seconds':59,'AS_bytes':512*1024**2,'estimated_MiB':96},'scope':'synthetic C helpers and Python arbitrary-integer reference; native source-loop census and existing public logs only; no Rust/native build, proof, fresh verify, GPU or privacy gate','proof_accounting':{'accepted_complete_private_8b_proofs':0,'passes':0,'positions':0,'context_length':None,'steady_state_tokens_per_second':None,'total_workload_tokens_per_second':None,'startup_seconds':None,'startup_fraction':None,'witness_seconds':None,'proof_seconds':None,'serialization_seconds':None,'independent_verification_seconds':None,'proof_latency_seconds':None,'proof_lag_seconds':None,'pipeline_drain_seconds':None,'long_context_prefill_ran':False,'resident_passes_ran':False,'decode_ran':False}}
result['executed_source_sha256']={name:hashlib.sha256((HERE/name).read_bytes()).hexdigest() for name in ['run.py','kernels.c']}
result['compiler_TMPDIR']=str(experiment_tmp)
result['witness_related_clock_scope']='sealing includes sequence reads and parity; rebuild/source includes witness and boundary extraction; combined clocks are not isolated matrix or pure witness time'
(HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'status':'pass','counts':counts,'controls':len(controls),'wall_s':result['experiment_wall_seconds'],'rss_KiB':result['peak_rss_kib'],'compiler_RSS_KiB':result['compiler_child_peak_rss_kib'],'timing_ratios':[(b['orientation'],b['K'],b['N'],round(b['wide_over_narrow'],2),round(b['wide_over_tiled'],2)) for b in benches],'witness_fractions':[r['witness_fraction_of_reported_total'] for r in records]}))
