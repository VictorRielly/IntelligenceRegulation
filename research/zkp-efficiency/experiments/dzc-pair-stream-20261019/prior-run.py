#!/usr/bin/env python3
"""Synthetic D endpoint coefficients; original Rust body is an independent oracle.

No native proof, transcript, RNG, privacy, device or runtime speed claim.
"""
import ctypes
import hashlib
import importlib.util
import json
import os
import platform
import random
import resource
import signal
import subprocess
import sys
import time
from pathlib import Path

H = Path(__file__).resolve().parent
sys.path.insert(0, str(H / 'reference'))
import run as old
from reference_math import P, Z, O, add, sub, mul, scale, fold, cube

SEED = 2026101876
COUNTS = [0, 0, 0, 0]  # add, sub, extension multiply, base multiply

def reset():
    COUNTS[:] = [0, 0, 0, 0]

def fa(a, b):
    COUNTS[0] += 1
    return add(a, b)

def fs(a, b):
    COUNTS[1] += 1
    return sub(a, b)

def fm(a, b):
    COUNTS[2] += 1
    return mul(a, b)

def fb(a, b):
    COUNTS[3] += 1
    return scale(a, b)

def pa(a, b):
    return [fa(a[i], b[i]) if i < min(len(a), len(b)) else
            a[i] if i < len(a) else b[i] for i in range(max(len(a), len(b)))]

def ps(a, b):
    return [fs(a[i] if i < len(a) else Z, b[i]) if i < len(b) else a[i]
            for i in range(max(len(a), len(b)))]

def pw(a, w):
    return [fm(x, w) for x in a]

def pb(a, w):
    return [fb(x, w) for x in a]

def pm(a, b, karatsuba=True):
    # All dispatch uses public structural widths, never field values.
    if karatsuba and len(a) == len(b) == 2:
        lo, hi = fm(a[0], b[0]), fm(a[1], b[1])
        cross = fs(fs(fm(fa(a[0], a[1]), fa(b[0], b[1])), lo), hi)
        return [lo, cross, hi]
    out = []
    for k in range(len(a) + len(b) - 1):
        pairs = [(i, k-i) for i in range(len(a)) if 0 <= k-i < len(b)]
        v = fm(a[pairs[0][0]], b[pairs[0][1]])
        for i, j in pairs[1:]:
            v = fa(v, fm(a[i], b[j]))
        out.append(v)
    return out

def ev(a, x):
    out = a[-1]
    for v in reversed(a[:-1]):
        out = add(mul(out, x), v)
    return out

def convert(a, degree, recover=False, claim=None):
    # Convert only AFTER reducing coefficients; unchanged 0..=degree messages.
    out = [a[0]]
    for t in range(1, degree + 1):
        if t == 1 and recover:
            assert claim is not None
            out.append(fs(claim, a[0]))
        elif t == 1:
            v = a[0]
            for x in a[1:]:
                v = fa(v, x)
            out.append(v)
        else:
            v = a[-1]
            for x in reversed(a[:-1]):
                v = fa(fb(v, t), x)
            out.append(v)
    return out

def plan(m, lk, hids, mu, nu, c, ln, supp, zeta, pad_ids=None,
         alpha=(101,3), g_u8=(19,0)):
    # Proof-local coefficients. Accumulate collisions in returned table ids.
    terms = {}
    def put(n, w):
        j = m[n]
        terms[j] = fa(terms.get(j, Z), w)
    for n, w in [('A_X',fs(mu[2],mu[5])), ('A_AO',fs(mu[3],mu[5])),
                 ('A_X1',fs(fa(mu[4],mu[5]),mu[9])), ('A_X2',fa(mu[8],mu[9])),
                 ('A_Z16',fs(mu[10],mu[9])),
                 ('d',fs(fb(mu[0],c[2]),fb(mu[1],c[3]))),
                 ('dm',fs(fb(mu[6],c[2]),fb(mu[7],c[3])))]:
        put(n, w)
    for n, k in [('A_XL0',2),('A_AL0',3),('A_X1L0',4),('A_X2L0',8),('A_ZL0',10)]:
        put(n,fs(Z,mu[k])); put(n[:-1]+'1',fs(Z,fb(mu[k],256)))
    for pre, w in [('nr',fs(mu[1],mu[0])),('ns',mu[1]),
                   ('mr',fs(mu[7],mu[6])),('ms',mu[7])]:
        for k in range(ln):
            put(pre+str(k),fb(w,256**k))
    const = Z
    for i in [2,3,4,8,10]:
        const = fa(const,mu[i])
    const = fa(fb(const,32768),fa(mu[1],mu[7]))
    bil = [(m['ga'],m['A_X'],fb(mu[0],c[0])),
           (m['d'],m['A_Y'],fs(Z,fb(mu[0],c[3]))),
           (m['gm'],m['A_X1'],fb(mu[6],c[1])),
           (m['dm'],m['A_YM'],fs(Z,fb(mu[6],c[3])))]
    # Defaults match only the synthetic captured-reference fixture. A native
    # adapter supplies this proof's actual alpha and already-bound g_u8.
    ds = [(j,a,fs(alpha,fa((d%P,0),g_u8))) for j,a,d in lk]
    pads = []
    if supp is not None:
        w = O
        for j in (range(5,m['d']) if pad_ids is None else pad_ids):
            pads.append((j,w)); w=fm(w,zeta)
    return dict(m=m,terms=terms,const=const,bil=bil,ds=ds,hids=hids,
                mu=mu,nu=nu,c=c,supp=supp,pads=pads)

def row(v, p, karatsuba=True):
    m, c, mu = p['m'], p['c'], p['mu']
    M = lambda a,b: pm(a,b,karatsuba)
    clauses = [p['const'],Z]
    for j, w in p['terms'].items():
        clauses = pa(clauses,pw(v[j],w))
    for j,k,w in p['bil']:
        clauses = pa(clauses,pw(M(v[j],v[k]),w))
    ds = [ps([off],pb(v[j],a)) for j,a,off in p['ds']]
    helpers = [Z]
    for k, hid in enumerate(p['hids']):
        a = ds[2*k]
        rel = ps(M(v[hid],a),[O]) if 2*k+1 == len(ds) else \
              ps(M(M(v[hid],a),ds[2*k+1]),pa(a,ds[2*k+1]))
        helpers = pa(helpers,pw(rel,mu[11+k]))
    supp = p['supp']
    if supp is not None:
        inner = [Z,Z]
        for j,w in p['pads']:
            inner = pa(inner,pw(v[j],w))
        pad = pw(M(ps([O],v[supp]),inner),mu[11+len(p['hids'])])
        helpers = pa(helpers,pad)
        clauses = M(v[supp],clauses)
    out = M(v[m['eq']],pa(helpers,clauses))
    for j,n,r,sh,half,nu in [(m['ha'],'A_AO','A_RAL',c[4],c[5],p['nu'][0]),
                               (m['hz'],'A_Z16','A_RDL',c[6],c[7],p['nu'][1])]:
        host = ps(pa(pb(v[m[n]],sh),v[m[r]]),[(half,0)])
        hv = M(v[j],host)
        if supp is not None:
            hv = M(hv,v[supp])
        out = pa(out,pw(hv,nu))
    assert len(out) == 5  # Public structural width; never trim by coefficient.
    return out

def native_library():
    # Original source COUNTS already counts Fp2 API calls. Reset immediately
    # before the captured closure, excluding its per-call C-ABI setup.
    s=(H/'reference/shim.rs').read_text()
    needle='let poly=include!("native-full-closure.rs.inc");let r=poly(v);'
    assert s.count(needle)==1
    s=s.replace(needle,'let poly=include!("native-full-closure.rs.inc"); COUNTS=[0;4]; let r=poly(v);')
    s+='\n#[no_mangle] pub unsafe extern "C" fn last_counts(out:*mut u64){for i in 0..4{*out.add(i)=COUNTS[i];}}\n'
    (H/'counted-shim.rs').write_text(s)
    (H/'native-full-closure.rs.inc').write_bytes((H/'reference/native-full-closure.rs.inc').read_bytes())
    argv=['rustc','--edition=2021','--crate-type=cdylib','-C','codegen-units=1',
          '-C','opt-level=0','counted-shim.rs','-o','counted-reference.so']
    cp=subprocess.run(argv,cwd=H,capture_output=True,text=True,timeout=25)
    (H/'compile.log').write_text(cp.stdout+cp.stderr)
    assert cp.returncode==0,cp.stderr
    U,I,S=ctypes.c_uint64,ctypes.c_int64,ctypes.c_size_t
    ptr=ctypes.POINTER(U);lib=ctypes.CDLL(str(H/'counted-reference.so'))
    lib.catalog.argtypes=[S,ctypes.c_uint32,S,ctypes.c_uint32,ctypes.c_uint32,ctypes.POINTER(S)];lib.catalog.restype=S
    lib.original.argtypes=[ptr,S,ptr,S,ptr,ptr,ctypes.POINTER(S),ctypes.POINTER(S),ctypes.POINTER(S),ctypes.POINTER(I),S,ptr,ptr]
    lib.last_counts.argtypes=[ptr]
    consts=json.loads((H/'reference/constants.json').read_text())
    def cat(ln,nw):
        a=(S*1024)();n=lib.catalog(ln,nw,3,3,4,a)
        return old.bind(ln,list(a[:n]),consts)
    def call(v,m,lk,idx,h0,ln,mu,nu,c,supp,zeta):
        vs=(U*(2*len(v)))(*(a for q in v for a in q));ms=(U*(2*len(mu)))(*(a for q in mu for a in q))
        ns=(U*4)(*(a for q in nu for a in q));cs=(U*8)(*c);ip=(S*81)(*idx)
        sp=(S*7)(m['ga'],m['gm'],m['d'],m['dm'],h0,ln,2**64-1 if supp is None else supp)
        wp=(S*(4*ln))(*(m[g+str(k)] for g in ['nr','ns','mr','ms'] for k in range(ln)))
        ls=(I*(3*len(lk)))(*(a for q in lk for a in q));zz=(U*2)(*zeta);out=(U*2)();cnt=(U*4)()
        lib.original(vs,len(v),ms,len(mu),ns,cs,ip,sp,wp,ls,len(lk),zz,out);lib.last_counts(cnt)
        return tuple(out),list(cnt)
    return cat,call,argv

def main():
    started=time.perf_counter();os.nice(19);cpu=min(os.sched_getaffinity(0));os.sched_setaffinity(0,{cpu})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    cat,native,argv=native_library();rng=random.Random(SEED)
    rf=lambda:(rng.randrange(P),rng.randrange(P))
    checks=dict(fixtures=0,native_values=0,round_messages=0,offgrid=0,original_finals=0,
                schoolbook_values=0,permutations=0,aliases=0,zero_censuses=0,final_relations=0)
    controls={k:False for k in ['leading_coefficient','stale_mu','helper_order','wrong_msb',
                'nonlinear_table_fold','missing_final','support_omission','toy_index','bad_binding',
                'wrong_recovered_claim','alias_overwrite']}
    census=[];digest=hashlib.sha256();profiles=json.loads((H/'reference/public-profile-scalars.json').read_text())
    desc=[(q['name'],4,32,q['public_scalars']) for q in profiles]
    desc += [('generic-four-top',4,31,profiles[0]['public_scalars']),('generic-five-top',5,39,profiles[0]['public_scalars'])]
    desc += [('generic-odd-helper',4,32,profiles[0]['public_scalars'])]
    for name,ln,nw,sc in desc:
      m,lk,idx,h0,na=cat(ln,nw)
      assert lk==old.reference_lookup(m,ln,nw)
      if name=='generic-odd-helper':lk=lk[:-1]  # Generic branch test, NOT an admitted catalog.
      nh=(len(lk)+1)//2
      c=[2*sc['norm_cn_a'],2*sc['norm_cn_m'],2**sc['norm_tn'],2**(sc['norm_tn']+1),
         2**sc['sh_ao'],2**(sc['sh_ao']-1),2**sc['sh_z'],2**(sc['sh_z']-1)]
      for padded in [False,True]:
        supp=h0+nh if padded else None;nt=h0+nh+int(padded);degree=5 if padded else 4
        mu=[rf() for _ in range(11+nh+int(padded))];nu=[rf(),rf()];zeta=rf()
        reset();p=plan(m,lk,list(range(h0,h0+nh)),mu,nu,c,ln,supp,zeta);prep_counts=COUNTS[:]
        rec=None
        for logn in [1,3,5]:
          N=1<<logn;tabs=[[rf() for _ in range(N)] for _ in range(nt)]
          # Boundary and zero slopes supplement arbitrary extension-field values.
          tabs[5][0]=(P-1,P-1);tabs[6][0]=Z;tabs[7][0]=O
          original=[t[:] for t in tabs];rs=[rf() for _ in range(logn)]
          previous_claim=None
          for ri,r in enumerate(rs):
            h=len(tabs[0])//2;coeff=[Z]*5;baseline=[Z]*(degree+1)
            for i in range(h):
              reset();v=[[t[i],fs(t[i+h],t[i])] for t in tabs];diff=COUNTS[:]
              reset();a=row(v,p);row_counts=COUNTS[:]
              reset();aa=row(v,p,False);school_counts=COUNTS[:];assert a==aa
              checks['schoolbook_values']+=5
              # Public structure fixes the census, even for all-zero data.
              reset();az=row([[Z,Z] for _ in tabs],p);assert COUNTS==row_counts
              checks['zero_censuses']+=1
              for k,x in enumerate(a):coeff[k]=add(coeff[k],x)
              for t in range(degree+1):
                values=[add(q[0],scale(q[1],t)) for q in v]
                want,ncounts=native(values,m,lk,idx,h0,ln,mu,nu,c,supp,zeta)
                independent=old.full(values,old.independent_clauses(values,m,mu,c,ln),m,lk,h0,mu,nu,c,supp,zeta)
                assert ev(a,(t,0))==want==independent
                baseline[t]=add(baseline[t],want);checks['native_values']+=1
                digest.update(str(want).encode())
              q=rf();values=[add(b[0],mul(q,b[1])) for b in v]
              want,_=native(values,m,lk,idx,h0,ln,mu,nu,c,supp,zeta)
              assert ev(a,q)==want;checks['offgrid']+=1
              controls['leading_coefficient'] |= ev(a[:-1],q)!=want
              if rec is None:
                rec=dict(descriptor=name,ln=ln,norm_w=nw,padded=padded,degree=degree,
                         tables=nt,lookups=len(lk),helpers=nh,prep=prep_counts,
                         differences=diff,coefficient_row=row_counts,schoolbook_row=school_counts,
                         native_point=ncounts,coefficient_accumulate=[5,0,0,0])
            reset();samples=convert(coeff,degree,ri>0,previous_claim)
            conv_counts=COUNTS[:];assert samples==baseline;checks['round_messages']+=1
            if ri>0:assert add(baseline[0],baseline[1])==previous_claim
            if ri>0:
                bad_claim=add(previous_claim,O)
                controls['wrong_recovered_claim'] |= convert(coeff,degree,True,bad_claim)!=baseline
            previous_claim=ev(coeff,r)
            # Each round keeps the original table fold and final ordering.
            tabs=fold(tabs,r)
          finals=[t[0] for t in tabs];assert finals==[cube(t,rs) for t in original]
          assert native(finals,m,lk,idx,h0,ln,mu,nu,c,supp,zeta)[0]==previous_claim
          checks['final_relations']+=1
          checks['original_finals']+=nt
          # Full expression permutation, including helpers/pad and host indices.
          lo=[t[0] for t in original];hi=[t[N//2] for t in original]
          v=[[a,sub(b,a)] for a,b in zip(lo,hi)];a=row(v,p);q=rf()
          perm=list(range(nt));rng.shuffle(perm);pv=[None]*nt
          for j,x in enumerate(v):pv[perm[j]]=x
          mm={n:perm[j] for n,j in m.items()}
          pp=plan(mm,[(perm[j],w,d) for j,w,d in lk],[perm[h0+k] for k in range(nh)],mu,nu,c,ln,
                  None if supp is None else perm[supp],zeta,[perm[j] for j in range(5,m['d'])])
          assert row(pv,pp)==a;checks['permutations']+=1
          am=m.copy();am['A_AO']=am['A_X'];ap=plan(am,lk,list(range(h0,h0+nh)),mu,nu,c,ln,supp,zeta)
          av=row(v,ap);val=[add(x[0],mul(q,x[1])) for x in v]
          assert ev(av,q)==old.full(val,old.independent_clauses(val,am,mu,c,ln),am,lk,h0,mu,nu,c,supp,zeta)
          checks['aliases']+=1
          bad_alias=dict(ap);bad_alias['terms']=ap['terms'].copy()
          bad_alias['terms'][am['A_X']]=sub(mu[3],mu[5])
          controls['alias_overwrite'] |= row(v,bad_alias)!=av
          stale=mu[:];stale[0]=add(stale[0],O)
          sp=plan(m,lk,list(range(h0,h0+nh)),stale,nu,c,ln,supp,zeta)
          controls['stale_mu'] |= row(v,sp)!=a
          hp=plan(m,list(reversed(lk)),list(range(h0,h0+nh)),mu,nu,c,ln,supp,zeta)
          controls['helper_order'] |= row(v,hp)!=a
          controls['wrong_msb'] |= logn>1 and cube(original[5],rs)!=cube(original[5],list(reversed(rs)))
          # Folding pointwise full-polynomial values is not the same polynomial.
          blo=native(lo,m,lk,idx,h0,ln,mu,nu,c,supp,zeta)[0]
          bhi=native(hi,m,lk,idx,h0,ln,mu,nu,c,supp,zeta)[0]
          controls['nonlinear_table_fold'] |= add(blo,mul(q,sub(bhi,blo)))!=ev(a,q)
          if padded:
            np=plan(m,lk,list(range(h0,h0+nh)),mu,nu,c,ln,None,zeta)
            controls['support_omission'] |= row(v,np)!=a
          controls['toy_index'] |= m['A_X']!=8
          try:
            if len(finals[:-1])!=nt:raise ValueError('retain original finals')
          except ValueError:controls['missing_final']=True
          try:
            bm=m.copy();bm['A_X']=nt
            if any(j>=nt for j in bm.values()):raise ValueError('out-of-range public binding')
          except ValueError:controls['bad_binding']=True
          checks['fixtures']+=1
        reset();convert([rf() for _ in range(5)],degree);rec['convert_full']=COUNTS[:]
        reset();convert([rf() for _ in range(5)],degree,True,rf());rec['convert_recovered']=COUNTS[:]
        census.append(rec)
    assert all(controls.values()),controls
    result=dict(status='PASS',run_id='20261018T052105Z-217b5106',seed=SEED,checks=checks,
                controls=controls,census=census,synthetic_digest=digest.hexdigest(),
                wall_seconds=time.perf_counter()-started,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                compiler_rss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,
                cpu_affinity=[cpu],threads=1,platform=platform.platform(),compiler_argv=argv,
                limits='59s wall/CPU, 512MiB AS; one nice19 CPU; no GPU/Cargo/install',
                scope='Synthetic endpoint-coefficient values and exact Fp2 API counts. Captured original Rust full D body/catalog with shape/layout/u128 field substitutes. No native proof, transcript, RNG, mask/privacy, device performance or target tokens.')
    (H/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='census'},indent=2))

if __name__=='__main__':
    main()
