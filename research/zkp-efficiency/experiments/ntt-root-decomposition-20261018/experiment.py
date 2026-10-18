#!/usr/bin/env python3
"""Synthetic exactness/cost probe, not native proving or a speed benchmark."""
from pathlib import Path
import ctypes as C
import datetime, hashlib, json, os, platform, random, resource, shutil, signal, subprocess, time

BASE=Path(__file__).resolve().parent
P=18446744069414584321
SEED=2026101872
COUNTS={}; CONTROLS={}; DIGEST=hashlib.sha256()
U=C.c_ulonglong; UI=C.c_uint; PTR=C.POINTER(U)

def same(a,b,name):
    assert a==b,(name,a,b)
    COUNTS[name]=COUNTS.get(name,0)+1
    DIGEST.update(str(a).encode())

def control(name,condition):
    assert condition,name
    CONTROLS[name]=True

def root(s,inv=False):
    w=pow(7,(P-1)//(1<<s),P)
    return pow(w,P-2,P) if inv else w

def arr(xs): return (U*len(xs))(*xs)

class Plan:
    """Public native generator/direction/capacity, immutable bytes per stage."""
    def __init__(self,lg,inv=False,generator=7):
        if type(lg)!=int or not 0<=lg<=16 or generator!=7: raise ValueError('public plan class')
        self.lg=lg; self.inv=inv
        full=[]; low=[]
        for s in range(1,lg+1):
            w=root(s,inv); stage=[1]
            for _ in range((1<<(s-1))-1): stage.append(stage[-1]*w%P)
            full.extend(stage)
            if s>6: low.extend(stage[:1<<(s-6)])
        self.full=tuple(full);self.low=tuple(low)
        self.cf=arr(full);self.cl=arr(low)
    def action(self,a,s,k):
        if not 0<=a<P or not 1<=s<=self.lg or not 0<=k<(1<<(s-1)): raise ValueError('action class')
        return int(LIB.action(a,self.cl,s,k,self.inv))
    def transform(self,source,lg=None,compressed=True,skip=0):
        lg=self.lg if lg is None else lg
        if not 0<=lg<=self.lg or not 1<=len(source)<=1<<lg: raise ValueError('transform class')
        if skip and (self.inv or len(source)>(1<<(lg-skip))): raise ValueError('pad skip premise')
        out=(U*(1<<lg))(); code=LIB.transform(arr(source),len(source),lg,self.cl if compressed else self.cf,out,self.inv,skip,compressed)
        if code: raise ValueError('host bounds')
        vals=list(out)
        if self.inv: vals=[x*pow(1<<lg,P-2,P)%P for x in vals]
        return vals

def dft(xs,inv=False):
    # Independent original-polynomial evaluation; no butterfly or compressed roots.
    n=len(xs);w=pow(7,(P-1)//n,P)
    if inv:w=pow(w,P-2,P)
    scale=pow(n,P-2,P) if inv else 1
    return [sum(v*pow(w,i*j,P) for j,v in enumerate(xs))*scale%P for i in range(n)]

def horner(xs,x):
    v=0
    for a in reversed(xs):v=(v*x+a)%P
    return v

def hiding_reference(msg,pads,nn):
    # Direct Lagrange interpolation plus (X^n-1) pad polynomial.
    n=len(msg); wn=pow(7,(P-1)//n,P);w=pow(7,(P-1)//nn,P);ni=pow(n,P-2,P)
    nodes=[pow(wn,j,P) for j in range(n)];out=[]
    for j in range(nn):
        x=7*pow(w,j,P)%P;z=(pow(x,n,P)-1)%P
        f=sum(v*y*z*ni*pow((x-y)%P,P-2,P) for v,y in zip(msg,nodes))%P
        out.append((f+z*horner(pads,x))%P)
    return out

def census(lg,first=1):
    n=1<<lg; g=sh=oldsh=words=0; stages=[]
    for s in range(first,lg+1):
        h=1<<(s-1);repeat=n//(2*h)
        if s<=6: sg=0; ss=(h-1)*repeat
        else:
            l=1<<(s-6);sg=32*(l-1)*repeat;ss=31*l*repeat;words+=l
        os=(min(h,32)-1)*repeat
        stages.append({'stage':s,'general':sg,'shifts':ss,'prior_sparse_shifts':os})
        g+=sg;sh+=ss;oldsh+=os
    return {'log_n':lg,'first_stage':first,'baseline_root_words_both_directions':2*((1<<lg)-1),
            'compressed_root_words_both_directions':2*((1<<(lg-5))-2) if lg>6 else 0,
            'full_butterfly_multiplications':(lg-first+1)*n//2,'general_multiplications':g,
            'shift_calls':sh,'extra_shifts_vs_prior':sh-oldsh,'logical_low_root_reads':g,'stages':stages}

def main():
    global LIB
    resource.setrlimit(resource.RLIMIT_AS,(512*1024*1024,)*2)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59)); signal.alarm(59)
    os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    started=time.monotonic(); rng=random.Random(SEED)
    compiler=shutil.which('c++');assert compiler,'existing C++ compiler required'
    cmd=[compiler,'-std=c++17','-O1','-fPIC','-shared','host.cpp','-o','host.so']
    run=subprocess.run(cmd,cwd=BASE,text=True,capture_output=True,timeout=20)
    (BASE/'compile.log').write_text(run.stdout+run.stderr)
    (BASE/'compile-command.json').write_text(json.dumps(cmd)+'\n')
    assert run.returncode==0,'local compilation failed; see compile.log'
    LIB=C.CDLL(str(BASE/'host.so'))
    LIB.action.argtypes=[U,PTR,UI,UI,C.c_int];LIB.action.restype=U
    LIB.shift_action.argtypes=[U,UI];LIB.shift_action.restype=U
    LIB.parts_action.argtypes=[U,U,C.c_int,UI,C.c_int];LIB.parts_action.restype=U
    LIB.transform.argtypes=[PTR,C.c_size_t,UI,PTR,PTR,C.c_int,UI,C.c_int];LIB.transform.restype=C.c_int
    LIB.counters.argtypes=[PTR,C.c_int]
    vals=[0,1,P-1,P-2,(1<<32)-1,1<<32,(1<<32)+1,(1<<63)-1,1<<63]+[rng.randrange(P) for _ in range(64)]
    for e in range(192):
        for a in vals:same(int(LIB.shift_action(a,e)),a*pow(2,e,P)%P,'shift_checks')
    same(root(6),pow(2,39,P),'native_root64')
    # Full stage-major/root/action checks through log16, both directions.
    for inv in (False,True):
        plan=Plan(16,inv)
        for s in range(1,17):
            for k in range(1<<(s-1)):
                native=plan.full[(1<<(s-1))-1+k]
                same(native,pow(root(s,inv),k,P),'full_native_root_checks')
                a=vals[(s+k)%len(vals)]
                same(plan.action(a,s,k),a*native%P,'full_native_action_checks')
        for lg in (0,1,5,6,7,10,13,15):
            small=Plan(lg,inv)
            same(plan.low[:len(small.low)],small.low,'monotonic_low_prefix')
            same(plan.full[:len(small.full)],small.full,'monotonic_native_prefix')
    # Large-stage arithmetic samples, not materialized tables/transforms.
    for s in range(17,33):
        d=s-6; length=1<<d
        for inv in (False,True):
            w=root(s,inv)
            for _ in range(128):
                k=rng.randrange(1<<(s-1));lo=k&(length-1);hi=k>>d;a=rng.randrange(P)
                factor=pow(w,lo,P)
                same(int(LIB.parts_action(a,factor,lo!=0,hi,inv)),a*pow(w,k,P)%P,'large_stage_sample_actions')
    for lg in range(0,12):
        n=1<<lg;src=[rng.randrange(P) for _ in range(n)]
        for inv in (False,True):
            p=Plan(lg,inv);y=p.transform(src)
            same(y,p.transform(src,compressed=False),'full_transform_parity')
            if lg<=6:same(y,dft(src,inv),'direct_dft_parity')
        same(Plan(lg,True).transform(Plan(lg).transform(src)),src,'round_trip')
    # Actual generated-loop counters independent of the algebraic census.
    for lg in range(1,13):
        p=Plan(lg);out=(U*3)();LIB.counters(out,1)
        p.transform([rng.randrange(P) for _ in range(1<<lg)])
        LIB.counters(out,1);c=census(lg)
        same(list(out),[c['general_multiplications'],c['shift_calls'],c['logical_low_root_reads']],'executed_counter_parity')
    # Zero-pad stage skip, frozen arithmetic premise; no numeric-zero pruning.
    for lg in (7,9,12):
        p=Plan(lg)
        for rb in (2,3):
            src=[rng.randrange(P) for _ in range((1<<lg)>>rb)]
            same(p.transform(src,skip=rb),p.transform(src),'pad_stage_skip_parity')
            out=(U*3)();LIB.counters(out,1);p.transform(src,skip=rb);LIB.counters(out,1);c=census(lg,rb+1)
            same(list(out),[c['general_multiplications'],c['shift_calls'],c['logical_low_root_reads']],'skipped_counter_parity')
    # Hiding rows include q>n overlap. Fresh SYNTHETIC pads for every case.
    for n,q,nn in [(1,3,8),(2,5,16),(4,9,32),(8,3,32),(16,17,64),(32,41,128)]:
        msg=[rng.randrange(P) for _ in range(n)];pads=[rng.randrange(P) for _ in range(q)]
        coeff=Plan(n.bit_length()-1,True).transform(msg);a=coeff+[0]*(nn-n)
        for j,v in enumerate(pads):a[j]=(a[j]-v)%P;a[n+j]=(a[n+j]+v)%P
        a=[x*pow(7,j,P)%P for j,x in enumerate(a)]
        same(Plan(nn.bit_length()-1).transform(a),hiding_reference(msg,pads,nn),'independent_hiding_row_parity')
    # Meaningful controls: changes which would silently preserve round trips.
    p=Plan(9);xs=[rng.randrange(P) for _ in range(512)];ys=p.transform(xs)
    control('wrong_inverse_sign_detected',p.action(123456789,9,85)!=Plan(9,True).action(123456789,9,85))
    control('wrong_upper_bits_detected',p.action(123456789,9,85)!=p.action(123456789,9,77))
    control('low_root_cannot_be_dropped',p.action(123456789,9,85)!=int(LIB.parts_action(123456789,1,False,85>>3,False)))
    poison=arr(p.low);poison[(1<<3)-2+(85&7)]^=1
    control('corrupt_low_root_detected',int(LIB.action(123456789,poison,9,85,False))!=p.action(123456789,9,85))
    control('table_provenance_still_required',int(LIB.action(123456789,poison,9,80,False))==p.action(123456789,9,80))
    bad=Plan(9);bad.cl=poison
    control('zero_only_oracle_misses_bad_root',bad.transform([0]*512)==p.transform([0]*512) and bad.transform(xs)!=ys)
    control('inverse_scale_cannot_be_omitted',[v*512%P for v in Plan(9,True).transform(ys)]!=xs)
    out=(U*3)();LIB.counters(out,1);p.transform(xs);LIB.counters(out,1);a=list(out)
    p.transform([0]*512);LIB.counters(out,1);same(list(out),a,'numeric_zero_schedule')
    control('zero_data_does_not_change_schedule',list(out)==a)
    def refused(fn):
        try:fn();return False
        except ValueError:return True
    for name,fn in [('wrong_generator',lambda:Plan(9,generator=3)),('oversized_plan',lambda:Plan(17)),('negative_plan',lambda:Plan(-1)),('wrong_stage',lambda:p.action(1,10,0)),('wrong_k',lambda:p.action(1,9,256)),('noncanonical_input',lambda:p.action(P,9,0)),('oversized_source',lambda:p.transform([1]*513)),('empty_source',lambda:p.transform([])),('bad_skip_premise',lambda:p.transform(xs,skip=2)),('inverse_skip',lambda:Plan(9,True).transform([1],skip=2))]:
        control(name+'_refuses',refused(fn))
    cases=[census(lg,first) for lg in (12,16,20,24) for first in (1,3,4)]
    (BASE/'census.json').write_text(json.dumps(cases,indent=2)+'\n')
    result={'status':'PASS','cycle':'0072','run_id':'20261018T012105Z-ac328993','seed':SEED,'counts':COUNTS,'negative_controls':CONTROLS,'fixture_sha256':DIGEST.hexdigest(),'wall_seconds':time.monotonic()-started,'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'compiler_peak_rss_kib':resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,'threads':1,'cpu_affinity':list(os.sched_getaffinity(0)),'nice':os.nice(0),'host':platform.platform(),'limits':'59s CPU/wall,512MiB AS per experiment','scope':'Host-compiled scalar CUDA-helper arithmetic and synthetic exact NTT/hiding rows; no CUDA compiler/PTX/device/native proof/speed/privacy theorem. Tables <=log16, transforms <=log12; larger stages sampled/counted only.','completed_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
    (BASE/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))

if __name__=='__main__':main()
