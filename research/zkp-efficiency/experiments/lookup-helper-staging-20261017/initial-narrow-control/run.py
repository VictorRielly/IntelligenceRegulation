#!/usr/bin/env python3
"""One-thread source-captured resident lookup boundary differential."""
import collections
import ctypes as C
import hashlib
import json
import os
from pathlib import Path
import random
import resource
import signal
import subprocess
import time
from catalog import source_catalog,reference_catalog

HERE=Path(__file__).resolve().parent
P=2**64-2**32+1
SIGN=2**63
SEED=2026101766
U=C.c_uint64; I=C.c_int64; Z=C.c_size_t

def add(a,b): return ((a[0]+b[0])%P,(a[1]+b[1])%P)
def sub(a,b): return ((a[0]-b[0])%P,(a[1]-b[1])%P)
def inv(z):
    d=(z[0]*z[0]-7*z[1]*z[1])%P
    if d==0: return None
    t=pow(d,P-2,P)
    return (z[0]*t%P,-z[1]*t%P)
def wrap(v): return C.c_int64(v).value
def signed_lift(r): return r if r<SIGN else r-P
def ref_values(lk,planes):
    terms,cst=lk
    n=len(planes[0]);out=[]
    for j in range(n):
        a=C.c_int64(cst)
        for p,c in terms: a=C.c_int64(a.value+C.c_int64(c*planes[p][j]).value)
        out.append(a.value)
    return out

def main():
    t0=time.perf_counter();os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2));resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    rustc='/home/victor/.rustup/toolchains/1.97.0-x86_64-unknown-linux-gnu/bin/rustc'
    argv=[rustc,'--edition=2021','--crate-type=cdylib','-C','opt-level=2','-C','codegen-units=1','isolated.rs','-o','isolated.so']
    cp=subprocess.run(argv,cwd=HERE,capture_output=True,text=True,timeout=25)
    (HERE/'compile.log').write_text(cp.stdout+cp.stderr)
    assert cp.returncode==0,cp.stderr
    lib=C.CDLL(str(HERE/'isolated.so'))
    lib.codec.argtypes=[C.POINTER(I),Z,C.POINTER(U),C.POINTER(U),C.POINTER(I)]
    lib.lookup.argtypes=[C.POINTER(I),C.POINTER(U),C.POINTER(U),Z,Z,C.POINTER(Z),C.POINTER(I),Z,I,C.POINTER(U),C.c_uint32]
    lib.make_h.argtypes=[C.POINTER(I),Z,Z,C.POINTER(U),C.POINTER(U),Z];lib.make_h.restype=C.c_uint32
    rng=random.Random(SEED);counts=collections.Counter();controls={};digest=hashlib.sha256()
    def codec(vals):
        n=len(vals);v=(I*n)(*vals);a=(U*n)();b=(U*((n+63)//64))();o=(I*n)();lib.codec(v,n,a,b,o)
        assert list(a)==[w%P for w in vals] and list(o)==vals
        expected=[0]*len(b)
        for j,w in enumerate(vals):
            if w<0 and P-SIGN<=w%P<SIGN:expected[j//64] |= 1<<(j%64)
        assert list(b)==expected
        counts['codec_words']+=n;counts['sidecar_words']+=len(b)
        digest.update(bytes(a));digest.update(bytes(b));return v,a,b
    # Full int16, arbitrary i64, ambiguity boundaries, and both preimages.
    vals=list(range(-32768,32768))+[rng.randrange(-SIGN,SIGN) for _ in range(16384)]
    residues=[P-SIGN,SIGN-1]+[P-SIGN+rng.randrange(2**32-1) for _ in range(2048)]
    vals += [x for r in residues for x in [r,r-P]]
    vals += [-SIGN,-SIGN+1,SIGN-2,SIGN-1,-1,0,1,255,256]
    v,a,b=codec(vals)
    assert sum(int(w).bit_count() for w in b)>=2050
    controls['same A residue has two signed preimages']=P-SIGN==(-SIGN)%P and -SIGN != P-SIGN
    # Every packing edge is separately exercised, with nonzero padding bits forbidden.
    for n in [0,1,2,3,7,63,64,65,127,128,129]:codec(([P-SIGN,-SIGN,-1,0,255]*((n+4)//5))[:n])

    def lookup(planes,lk,mode):
        n=len(planes[0]);flat=[x for p in planes for x in p];v,a,b=codec(flat)
        terms,cst=lk;pp=(Z*len(terms))(*(p for p,c in terms));cc=(I*len(terms))(*(c for p,c in terms));out=(U*n)()
        lib.lookup(v,a,b,n,len(planes),pp,cc,len(terms),cst,out,mode)
        return list(out)
    text=(HERE/'native/layout.rs').read_text()
    palette=[-SIGN,P-SIGN,-SIGN+127,SIGN-1,SIGN-128,-32768,-128,-1,0,1,127,128,255,256,32767]
    for case in range(48):
        ln=4;ls=2+case%2;lp=2;nw=29+case%4;sw=8*ls-case%7
        shifts=dict(sh_ao=case%9,sh_qkv=1+case%8,sh_s=1+(case+1)%8,sh_g=1+(case+2)%8,sh_z=1+(case+3)%8,sh_o=9+case%8,sh_h=9+(case+1)%8)
        cat=source_catalog(text,ln,ls,lp,nw,sw,shifts)
        assert cat==reference_catalog(ln,ls,lp,nw,sw,shifts)
        n=[0,1,2,3,7,63,64,65][case%8]
        for dom,lks in cat.items():
            names=sorted({p for terms,cst in lks for p,c in terms});idx={p:i for i,p in enumerate(names)}
            planes=[[rng.choice(palette) if case%3 else rng.randrange(-127,256) for _ in range(n)] for p in names]
            for terms,cst in lks:
                lk=([(idx[p],c) for p,c in terms],cst);ref=ref_values(lk,planes);want=[x%P for x in ref]
                native=lookup(planes,lk,0);exact=lookup(planes,lk,1);naive=lookup(planes,lk,2);nobit=lookup(planes,lk,3)
                assert native==exact==want
                counts['lookup_columns']+=1;counts['lookup_residue_words']+=n
                counts['field_only_mismatches']+=sum(x!=y for x,y in zip(want,naive))
                counts['missing_sidecar_mismatches']+=sum(x!=y for x,y in zip(want,nobit))
                digest.update(bytes((U*n)(*exact)))
            counts['domains']+=1
        counts['catalogs']+=1
    # Generic fallbacks, including multi-term and constant expressions.
    gp=[[rng.choice(palette) for _ in range(65)] for _ in range(3)]
    for lk in [([],127),([(0,1),(1,-1)],127),([(0,256),(1,-128),(2,7)],-SIGN),([(1,-1)],SIGN-1)]:
        want=[v%P for v in ref_values(lk,gp)]
        assert lookup(gp,lk,0)==lookup(gp,lk,1)==want;counts['generic_columns']+=1
    controls['field-only affine evaluation changes wrapped values']=counts['field_only_mismatches']>0
    controls['discarding ambiguity bit changes wrapped values']=counts['missing_sidecar_mismatches']>0
    # A-only impossibility witness using the real catalog's coefficient-2 rotation pin.
    lo=-SIGN;hi=P-SIGN;expr=([(0,2)],0)
    x0=lookup([[lo]],expr,0)[0];x1=lookup([[hi]],expr,0)[0]
    assert lo%P==hi%P and x0!=x1
    collision=dict(raw=[lo,hi],A_residue=lo%P,coefficient=2,wrapped_i64=[wrap(2*lo),wrap(2*hi)],lookup_residue=[x0,x1])
    controls['identical A can require different scaled H denominator']=x0!=x1

    def h_native(columns,alpha,tag):
        nc=len(columns);n=len(columns[0]) if nc else 0;nh=(nc+1)//2;hlen=6+nh*(2*n+2)
        raw=(I*(nc*n))(*(v for c in columns for v in c));prm=(U*4)(*alpha,*tag);h=(U*hlen)(*([P-19]*hlen))
        code=lib.make_h(raw,n,nc,prm,h,hlen);return code,list(h)
    def h_reference(columns,alpha,tag):
        nc=len(columns);n=len(columns[0]) if nc else 0;nh=(nc+1)//2;out=[P-19]*(6+nh*(2*n+2))
        for k in range(nh):
            col=[]
            for j in range(n):
                z=inv(sub(alpha,add((columns[2*k][j]%P,0),tag)))
                if z is None:return 1,out
                if 2*k+1<nc:
                    y=inv(sub(alpha,add((columns[2*k+1][j]%P,0),tag)))
                    if y is None:return 1,out
                    z=add(z,y)
                col.append(z)
            for j,z in enumerate(col):out[3+k*(2*n+2)+j]=z[0];out[3+k*(2*n+2)+n+1+j]=z[1]
        if any(inv(sub(alpha,add((v,0),tag))) is None for v in range(256)):return 2,out
        return 0,out
    for n in [0,1,3,7,63,64,65]:
        for nc in [1,2,3,5,9]:
            # Values include signed/overflow/wrap outcomes and arbitrary padded tails.
            planes=[[rng.choice(palette) for _ in range(n)]];columns=[];resident=[]
            for k in range(nc):
                lk=([(0,[1,2,-1,128,256][k%5])],127 if k%3==0 else 0)
                columns.append(ref_values(lk,planes));resident.append([signed_lift(v) for v in lookup(planes,lk,1)])
            tag=(17,9);alpha=(1000,12)
            old=h_native(columns,alpha,tag);new=h_native(resident,alpha,tag);ref=h_reference(columns,alpha,tag)
            assert old==new==ref
            counts['H_fixtures']+=1;counts['H_fp2_values']+=((nc+1)//2)*n
            counts['H_sentinel_words_checked']+=len(old[1]);digest.update(bytes((U*len(old[1]))(*old[1])))
    # Same A, same kernel input, different literal native helper requirement.
    tag=(17,9);alpha=(1000,12)
    h0=h_native([[wrap(2*lo)]],alpha,tag);h1=h_native([[wrap(2*hi)]],alpha,tag)
    assert h0!=h1
    controls['same A collision reaches different canonical H']=h0!=h1
    # Present-byte zero, absent-byte zero, arbitrary signed-value zero, empty.
    refusal_rows=[]
    for cols,zero in [([[3,8]],3),([[3,8]],11),([[300,-1]],300),([[300,-1]],-1),([[]],11)]:
        a=add((zero%P,0),tag);old=h_native(cols,a,tag);ref=h_reference(cols,a,tag)
        assert old[0]==ref[0] and old[0]!=0
        # Harness commits no private output until every check succeeds.
        assert all(v==P-19 for v in old[1])
        refusal_rows.append(dict(columns=cols,zero=zero,stage=old[0]));counts['refusal_fixtures']+=1
    controls['unused public zero still refuses after helper stage']=refusal_rows[1]['stage']==2
    controls['zero-multiplicity table entry cannot be skipped']=refusal_rows[4]['stage']==2
    controls['invalid signed zero denominator not clamped']=refusal_rows[3]['stage']==1
    # A source-faithful wrapping-vs-field counterexample changes the refusal.
    v=2**62+256;oldv=wrap(2*v);fv=(2*(v%P))%P
    old=h_native([[oldv]],add((oldv%P,0),tag),tag)
    field=h_native([[signed_lift(fv)]],add((oldv%P,0),tag),tag)
    assert old[0]==1 and field[0]==0
    reverse_old=h_native([[oldv]],add((fv,0),tag),tag);reverse_field=h_native([[signed_lift(fv)]],add((fv,0),tag),tag)
    assert reverse_old[0]==0 and reverse_field[0]==1
    controls['field-only port can miss an original refusal']=True
    controls['field-only port can introduce a refusal']=True
    # Noncanonical output, signed decoding threshold and packing defects.
    controls['using u64 raw word directly as Fp is wrong']=((-1)&(2**64-1))%P != (-1)%P
    controls['sign threshold at P/2 is not an exact full-i64 inverse']=int((P-SIGN)>P//2)==False
    for name,ok in controls.items():assert ok,name
    result=dict(status='PASS',run_id='20261017T192105Z-c342a26b',cycle='0066',seed=SEED,counts=dict(counts),negative_controls=controls,collision=collision,
        refusal_counterexample=dict(raw=v,coefficient=2,literal_wrapped=oldv,field_only=fv,original_stage=old[0],field_only_stage=field[0],reverse_original_stage=reverse_old[0],reverse_field_stage=reverse_field[0]),
        refusal_rows=refusal_rows,output_sha256=digest.hexdigest(),wall_seconds=time.perf_counter()-t0,
        parent_peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,child_peak_rss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,
        compiler_argv=argv,cpu_affinity=sorted(os.sched_getaffinity(0)),nice=os.nice(0),threads=1,limits='59s CPU/wall;512MiB AS;estimated<96MiB Python/<192MiB compiler',
        scope='Source-captured Rust field, wrapping lookup closure, byte cache/helper_one/write_h; serial CPU harness plus independent Python arbitrary-integer oracle. Native orchestrator, Rayon, CUDA, transcript, RNG, PCS, proof, privacy and runtime speed not tested.')
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))

if __name__=='__main__':main()
