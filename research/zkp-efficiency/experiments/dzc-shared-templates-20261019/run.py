#!/usr/bin/env python3
"""Static scalar D kernels, runtime proof-local parameters, synthetic data only.

No native prover, GPU, mask, transcript, PCS, or private input is executed.
"""
import collections
import ctypes
import hashlib
import importlib.util
import json
import os
import platform
import random
import re
import resource
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True
H = Path(__file__).resolve().parent
PREV = H.parent / 'dzc-use-driven-affine-20261019'
SEED = 2026101982
sys.path.insert(0, str(PREV / 'reference'))
spec = importlib.util.spec_from_file_location('schedule79', PREV / 'run.py')
old = importlib.util.module_from_spec(spec)
spec.loader.exec_module(old)
prior = old.prior
from reference_math import P, Z, O, add, sub, mul, scale, fold, cube


class CaptureGraph(old.Graph):
    def node(self, values, deps=(), label='literal', external=False):
        n = super().node(values, deps, label, external)
        self.nodes[n.i]['values'] = list(n.values)
        return n

    def op(self, name, fn, *xs, scalar=None, label=None):
        n = super().op(name, fn, *xs, scalar=scalar, label=label)
        self.nodes[n.i]['operation'] = name
        self.nodes[n.i]['scalar'] = scalar
        return n


old.Graph = CaptureGraph


class Lower:
    """One SSA identifier per Fp2 value or base scalar; no value dispatch."""
    def __init__(self, ns, output):
        self.ops = []
        self.params = []
        self.bases = []
        self.v = {}
        def op(kind, deps=(), slot=None):
            i = len(self.ops)
            self.ops.append(dict(id=i, kind=kind, deps=list(deps), slot=slot,
                                 words=0.5 if kind == 'load_base' else 1))
            return i
        self.op = op
        for n in ns:
            ds = [self.v[d] for d in n['deps']]
            k = n.get('operation')
            if n['external']:
                j = n['source_index']
                lo, hi = op('load_raw', slot=2*j), op('load_raw', slot=2*j+1)
                v = [lo, op('sub', [hi, lo])]
            elif k is None:
                v = []
                for x in n['values']:
                    slot = len(self.params); self.params.append(tuple(x))
                    v.append(op('load_param', slot=slot))
            elif k in ('add', 'subtract'):
                a, b = ds
                if k == 'add':
                    v = [op('add', [a[i], b[i]]) if i < min(len(a), len(b)) else
                         a[i] if i < len(a) else b[i] for i in range(max(len(a), len(b)))]
                else:
                    v = []
                    for i in range(max(len(a), len(b))):
                        if i >= len(b): v.append(a[i]); continue
                        if i >= len(a):
                            # Explicit known structural zero, never inferred from a value.
                            slot=len(self.params); self.params.append(Z)
                            zero=op('load_param', slot=slot)
                        else: zero=a[i]
                        v.append(op('sub', [zero, b[i]]))
            elif k in ('extension_scale', 'base_scale'):
                if k == 'extension_scale':
                    slot=len(self.params); self.params.append(tuple(n['scalar']))
                    w=op('load_param', slot=slot); kind='mul'
                else:
                    slot=len(self.bases); self.bases.append(n['scalar'] % P)
                    w=op('load_base', slot=slot); kind='base'
                v=[op(kind, [a,w]) for a in ds[0]]
            elif k == 'multiply':
                a,b=ds
                if len(a)==len(b)==2:
                    lo=op('mul',[a[0],b[0]]); hi=op('mul',[a[1],b[1]])
                    cross=op('mul',[op('add',a),op('add',b)])
                    cross=op('sub',[op('sub',[cross,lo]),hi])
                    v=[lo,cross,hi]
                else:
                    v=[]
                    for q in range(len(a)+len(b)-1):
                        pairs=[(i,q-i) for i in range(len(a)) if 0<=q-i<len(b)]
                        terms=[op('mul',[a[i],b[j]]) for i,j in pairs]
                        x=terms[0]
                        for y in terms[1:]:x=op('add',[x,y])
                        v.append(x)
            else: raise AssertionError(k)
            assert len(v)==n['words']
            self.v[n['id']]=v
        self.output=self.v[output]
        assert len(self.output)==5

    def signature(self):
        return hashlib.sha256(json.dumps([self.ops,self.output],sort_keys=True).encode()).hexdigest()

    def emit(self, name):
        out=[f'#[no_mangle] pub unsafe extern "C" fn {name}(raw:*const Fp2, params:*const Fp2, bases:*const u64, out:*mut Fp2) {{']
        for n in self.ops:
            k=n['kind']; ds=n['deps']; i=n['id']
            if k.startswith('load_'):
                src={'load_raw':'raw','load_param':'params','load_base':'bases'}[k]
                rhs=f'*{src}.add({n["slot"]})'
            else:
                method={'add':'add','sub':'sub','mul':'mul','base':'mul_base'}[k]
                rhs=f's{ds[0]}.{method}(s{ds[1]})'
            out.append(f' let s{i} = {rhs};')
        out.extend(f' *out.add({i}) = s{j};' for i,j in enumerate(self.output))
        return '\n'.join(out+['}'])


def lifetime(ops, outputs):
    # Includes source loads, parameter loads and primitive Fp2 results before
    # releasing last-use operands. Base scalars are charged as eight bytes.
    ends={n['id']:n['id'] for n in ops}
    for n in ops:
        for d in n['deps']: ends[d]=n['id']
    for d in outputs:ends[d]=len(ops)
    live=set();peak=0;peak_at=0
    for n in ops:
        live.add(n['id']); now=sum(ops[j]['words'] for j in live)
        if now>peak:peak,peak_at=now,n['id']
        live={j for j in live if ends[j]>n['id']}
    return dict(row_scalar_peak_fp2_equivalents=peak,
                with_five_word_round_accumulator=peak+5,peak_at=peak_at,
                primitive_internal_base_arithmetic_and_physical_registers_excluded=True)


def load_reference():
    shutil.copyfile(PREV/'counted-reference.so',H/'captured-reference.so')
    U,I,S=ctypes.c_uint64,ctypes.c_int64,ctypes.c_size_t
    ptr=ctypes.POINTER(U);lib=ctypes.CDLL(str(H/'captured-reference.so'))
    lib.catalog.argtypes=[S,ctypes.c_uint32,S,ctypes.c_uint32,ctypes.c_uint32,ctypes.POINTER(S)]
    lib.catalog.restype=S
    lib.original.argtypes=[ptr,S,ptr,S,ptr,ptr,ctypes.POINTER(S),ctypes.POINTER(S),ctypes.POINTER(S),ctypes.POINTER(I),S,ptr,ptr]
    consts=json.loads((PREV/'reference/constants.json').read_text())
    def cat():
        a=(S*1024)();n=lib.catalog(4,32,3,3,4,a)
        return prior.old.bind(4,list(a[:n]),consts)
    def original(v,m,lk,idx,h0,mu,nu,c,zeta):
        vs=(U*(2*len(v)))(*(a for q in v for a in q))
        ms=(U*(2*len(mu)))(*(a for q in mu for a in q));ns=(U*4)(*(a for q in nu for a in q))
        cs=(U*8)(*c);ip=(S*81)(*idx)
        sp=(S*7)(m['ga'],m['gm'],m['d'],m['dm'],h0,4,2**64-1)
        wp=(S*16)(*(m[g+str(k)] for g in ['nr','ns','mr','ms'] for k in range(4)))
        ls=(I*(3*len(lk)))(*(a for q in lk for a in q));zz=(U*2)(*zeta);out=(U*2)()
        lib.original(vs,len(v),ms,len(mu),ns,cs,ip,sp,wp,ls,len(lk),zz,out)
        return tuple(out)
    return cat,original


def graph(raw,p,driven):
    out,ns,io=old.lazy_row(raw,p,trace=True,use_driven=driven)
    return out,Lower(ns,io['output'])


def original_main():
    started=time.perf_counter();os.nice(19)
    cpu=min(os.sched_getaffinity(0));os.sched_setaffinity(0,{cpu})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    cat,native=load_reference();m,lk,idx,h0,na=cat();nh=(len(lk)+1)//2;nt=h0+nh
    assert (len(lk),nh,nt)==(34,17,59)
    rng=random.Random(SEED);rf=lambda:(rng.randrange(P),rng.randrange(P))
    profiles=json.loads((PREV/'reference/public-profile-scalars.json').read_text())
    sc=profiles[0]['public_scalars']
    def constants(sc):
        return [2*sc['norm_cn_a'],2*sc['norm_cn_m'],2**sc['norm_tn'],2**(sc['norm_tn']+1),
                2**sc['sh_ao'],2**(sc['sh_ao']-1),2**sc['sh_z'],2**(sc['sh_z']-1)]
    p=prior.plan(m,lk,list(range(h0,nt)),[rf() for _ in range(11+nh)],
                 [rf(),rf()],constants(sc),4,None,rf())
    raw=[(rf(),rf()) for _ in range(nt)]
    schedules={name:graph(raw,p,driven)[1] for name,driven in [('baseline',True),('driven',True)]}
    header=(PREV/'counted-shim.rs').read_text().split('fn k(i:i64)')[0]
    header=re.sub(r'unsafe\{COUNTS\[\d\]\+=1;\}', '', header)
    header=header.replace(' fn add(', ' #[inline(always)] fn add(').replace(' fn sub(', ' #[inline(always)] fn sub(')
    header=header.replace(' fn mul(', ' #[inline(always)] fn mul(').replace(' fn mul_base(', ' #[inline(always)] fn mul_base(')
    field_mode='native' if '--native-field' in sys.argv else 'u128'
    if field_mode=='native':
        field_path=Path('/home/victor/IntelligenceRegulation/ops/zkp-mvp/gpu-zerocheck/zkp-core/src/field.rs')
        shutil.copyfile(field_path,H/'native-field.rs')
        header='''#![allow(dead_code,private_interfaces)]
#[path="native-field.rs"] mod native;
#[repr(C)] #[derive(Clone,Copy)] struct Fp2 {a:u64,b:u64}
impl Fp2 {
 #[inline(always)] fn inner(self)->native::Fp2 {native::Fp2::new(native::Fp(self.a),native::Fp(self.b))}
 #[inline(always)] fn from(v:native::Fp2)->Self {Self{a:v.c0.0,b:v.c1.0}}
 #[inline(always)] fn add(self,o:Self)->Self {Self::from(self.inner().add(o.inner()))}
 #[inline(always)] fn sub(self,o:Self)->Self {Self::from(self.inner().sub(o.inner()))}
 #[inline(always)] fn mul(self,o:Self)->Self {Self::from(self.inner().mul(o.inner()))}
 #[inline(always)] fn mul_base(self,o:u64)->Self {Self::from(self.inner().mul_base(native::Fp(o)))}
}
'''
    if field_mode=='native':
        header=header.replace('#[inline(always)] fn add', '#[inline(never)] fn add').replace('#[inline(always)] fn sub', '#[inline(never)] fn sub').replace('#[inline(always)] fn mul', '#[inline(never)] fn mul')
    (H/'kernels.rs').write_text(header+'\n'+group_header+'\n'+'\n'.join(q.emit(n) for n,q in schedules.items())+'\n'+emit_unique(schedules['driven'],'unique'))
    argv=['rustc','--edition=2021','--crate-type=cdylib','-C','codegen-units=1','-C','opt-level=1',
          '--emit=link,asm,llvm-ir','kernels.rs','-o','kernels.so']
    ct=time.perf_counter();cp=subprocess.run(argv,cwd=H,capture_output=True,text=True,timeout=40)
    (H/'compile.log').write_text(cp.stdout+cp.stderr)
    assert cp.returncode==0,cp.stderr
    compile_s=time.perf_counter()-ct
    U=ctypes.c_uint64;ptr=ctypes.POINTER(U);lib=ctypes.CDLL(str(H/'libkernels.so'))
    for name in list(schedules)+["bad_map"]:getattr(lib,name).argtypes=[ptr,ptr,ptr,ptr]
    def run(name,raw,q):
        rr=(U*(4*len(raw)))(*(a for pair in raw for x in pair for a in x))
        pp=(U*(2*len(q.params)))(*(a for x in q.params for a in x))
        bb=(U*len(q.bases))(*q.bases);out=(U*10)()
        getattr(lib,name)(rr,pp,bb,out)
        return [tuple(out[2*i:2*i+2]) for i in range(5)]
    checks=collections.Counter();controls=collections.defaultdict(bool);digest=hashlib.sha256()
    for prof in profiles:
      c=constants(prof['public_scalars'])
      for logn in [1,3,5]:
        N=1<<logn;tabs=[[rf() for _ in range(N)] for _ in range(nt)]
        tabs[5][0]=(P-1,P-1);tabs[6][0]=Z;tabs[7][0]=O
        originals=[t[:] for t in tabs];rs=[rf() for _ in range(logn)]
        mu=[rf() for _ in range(11+nh)];nu=[rf(),rf()];zeta=rf()
        p=prior.plan(m,lk,list(range(h0,nt)),mu,nu,c,4,None,zeta)
        claim=None
        for ri,r in enumerate(rs):
          half=len(tabs[0])//2;coeff=[Z]*5;native_message=[Z]*5
          for i in range(half):
            raw=[(t[i],t[i+half]) for t in tabs]
            qlast=None
            for name,driven in [('baseline',True),('driven',True)]:
                want,q=graph(raw,p,driven);assert q.signature()==schedules[name].signature()
                got=run(name,raw,q);assert got==want
                assert got==prior.row([[lo,sub(hi,lo)] for lo,hi in raw],p)
                checks['compiled_coefficients']+=5;qlast=q
                if i==0:
                    # Runtime challenge parameters must refresh across proofs.
                    stale=run(name,raw,schedules[name]);controls['stale_runtime_parameters']|=stale!=want
                    zraw=[(Z,Z)]*nt;_,qzero=graph(zraw,p,driven)
                    assert qzero.signature()==q.signature() and qzero.params==q.params and qzero.bases==q.bases
                    assert run(name,zraw,qzero)==graph(zraw,p,driven)[0]
                    checks['value_independent_runtime_binding']+=1
            for k,x in enumerate(got):coeff[k]=add(coeff[k],x)
            for t in range(5):
                values=[add(lo,scale(sub(hi,lo),t)) for lo,hi in raw]
                nv=native(values,m,lk,idx,h0,mu,nu,c,zeta)
                iv=prior.old.full(values,prior.old.independent_clauses(values,m,mu,c,4),m,lk,h0,mu,nu,c,None,zeta)
                assert prior.ev(got,(t,0))==nv==iv
                native_message[t]=add(native_message[t],nv);checks['captured_rust_grid_values']+=1
            x=rf();values=[add(lo,mul(sub(hi,lo),x)) for lo,hi in raw]
            assert prior.ev(got,x)==native(values,m,lk,idx,h0,mu,nu,c,zeta)
            checks['captured_rust_offgrid_values']+=1
            if i==0:
                wrong=raw[:];wrong[5]=(wrong[5][1],wrong[5][0])
                controls['wrong_endpoint_order']|=run('driven',wrong,qlast)!=got
                controls['dropped_degree4']|=prior.ev(got[:-1],x)!=prior.ev(got,x)
                bad=qlast.params[:];bad[0]=add(bad[0],O)
                qbad=Lower.__new__(Lower);qbad.params=bad;qbad.bases=qlast.bases
                controls['parameter_corruption']|=run('driven',raw,qbad)!=got
                controls['compiled_wrong_map']|=run('bad_map',raw,qlast)!=got
                # Signed lookup multipliers must map through the field, not a u64 cast.
                qb=Lower.__new__(Lower);qb.params=qlast.params
                qb.bases=[2**64-1 if a==P-1 else a for a in qlast.bases]
                controls['signed_base_wrap']|=run('driven',raw,qb)!=got
            digest.update(str(got).encode())
          assert prior.convert(coeff,4,ri>0,claim)==native_message
          if claim is not None:
              controls['stale_recovered_claim']|=prior.convert(coeff,4,True,add(claim,O))!=native_message
          claim=prior.ev(coeff,r);tabs=fold(tabs,r);checks['round_messages']+=1
        finals=[t[0] for t in tabs];assert finals==[cube(t,rs) for t in originals]
        assert native(finals,m,lk,idx,h0,mu,nu,c,zeta)==claim
        assert len(finals)==nt
        bad_final=finals[:];bad_final[-1]=add(bad_final[-1],O)
        controls['tampered_original_final']|=native(bad_final,m,lk,idx,h0,mu,nu,c,zeta)!=claim
        checks['original_finals']+=nt;checks['final_relations']+=1;checks['fixtures']+=1
    assert all(controls.values()) and len(controls)==8,controls
    # Retain scalar DAGs without synthetic field values; no witness values exported.
    dag={n:dict(ops=q.ops,output=q.output,signature=q.signature(),
                params=len(q.params),base_params=len(q.bases),
                census=dict(collections.Counter(x['kind'] for x in q.ops)),
                lifetime=lifetime(q.ops,q.output)) for n,q in schedules.items()}
    (H/'scalar-dags.json').write_text(json.dumps(dag,indent=2)+'\n')
    pins=[]
    for q in json.loads((PREV/'source-pins.json').read_text()):
        b=Path(q['path']).read_bytes();sha=hashlib.sha256(b).hexdigest()
        assert sha==q['cycle77_sha256'];pins.append(dict(path=q['path'],sha256=sha))
    for pth in [PREV/'run.py',PREV/'prior-run.py',PREV/'counted-shim.rs',PREV/'counted-reference.so',PREV/'reference/reference_math.py']:
        pins.append(dict(path=str(pth),sha256=hashlib.sha256(pth.read_bytes()).hexdigest()))
    (H/'source-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
    out=dict(field_mode=field_mode,field_call_boundary='baseline noinline Fp2; candidate shared public-shape templates with runtime public index maps',status='PASS',run_id='20261019T141854Z-0a847d64',seed=SEED,checks=checks,controls=controls,
             profiles=[q['name'] for q in profiles],N=[2,8,32],tables=nt,lookups=len(lk),helpers=nh,
             compiled_kernels={n:{k:v for k,v in d.items() if k not in ('ops','output')} for n,d in dag.items()},
             synthetic_digest=digest.hexdigest(),wall_seconds=time.perf_counter()-started,
             compile_seconds=compile_s,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
             compiler_rss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,
             compiler_argv=argv,cpu_affinity=[cpu],threads=1,platform=platform.platform(),
             scope='Synthetic current unpadded complete D coefficients/messages/original finals; field mode recorded separately (native mode uses unchanged source field implementation). No native profile admission/RNG/transcript/mask/PCS/proof/device benchmark.',
             limits='One nice19 CPU;59s CPU/wall;512MiB address space;noCargo/GPU/install/foreign execution')
    (H/'result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))




# Both arms use the same use-driven graph; only call granularity changes.
from grouping import GROUP_HEADER, emit as group_emit, partition, shared_plan, emit_unique
group_header=GROUP_HEADER
scalar_emit=Lower.emit
def emit_arm(self,name):
    if name=='baseline':return scalar_emit(self,name)
    plan=shared_plan(self)
    (H/'group-plan.json').write_text(json.dumps(plan,indent=2)+'\n')
    return group_emit(self,name)
Lower.emit=emit_arm
if __name__=='__main__':
    assert '--native-field' in sys.argv
    original_main()
