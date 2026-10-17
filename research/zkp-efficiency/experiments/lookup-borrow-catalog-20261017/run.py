#!/usr/bin/env python3
"""Source-derived lookup catalog; synthetic borrow/materialize differential.

No native Rust execution, private fixture, actual proof or performance claim.
"""
import ast
import collections
import ctypes
import difflib
import hashlib
import json
import os
import random
import re
import resource
import signal
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
SEED = 2026101762
P = 2**64 - 2**32 + 1
DOMS = ['L', 'D', 'F', 'Q', 'Kv', 'S']

def wrap(x):
    return (x + 2**63) % 2**64 - 2**63

def split_args(s):
    out, start, depth = [], 0, 0
    for i, c in enumerate(s):
        depth += (c in '([') - (c in ')]')
        if c == ',' and depth == 0:
            out.append(s[start:i].strip()); start = i + 1
    if s[start:].strip(): out.append(s[start:].strip())
    return out

def scalar(expr, env):
    expr = expr.strip().replace('1i64', '1')
    if expr.startswith('one('): return 1 << (8 - env[expr[4:-1]])
    if expr.startswith('two('): return 1 << (16 - env[expr[4:-1]])
    for k in sorted(env, key=len, reverse=True): expr = expr.replace(k, str(env[k]))
    tree = ast.parse(expr, mode='eval')
    def rec(n):
        if isinstance(n, ast.Constant) and type(n.value) is int: return n.value
        if isinstance(n, ast.BinOp):
            a, b = rec(n.left), rec(n.right)
            if isinstance(n.op, ast.Sub): return a - b
            if isinstance(n.op, ast.LShift): return a << b
        raise ValueError('unsupported scalar: ' + expr)
    return rec(tree.body)

def source_catalog(text, ln, ls, lp, norm_w, soft_w, shifts):
    """Restricted fail-closed recognizer of current Rust constructor grammar."""
    body = text.split('pub(crate) fn lookups_at(')[1].split('\n    v\n}')[0]
    arms = re.findall(r'Dom::(\w+) => \{(.*?)\n        \}', body, re.S)
    assert [d for d, _ in arms] == DOMS
    env = dict(ln=ln, ls=ls, lp=lp, norm_scale=1 << (8*ln-norm_w),
               sigma_scale=1 << (8*ls-soft_w), p_scale=1 << (8*lp-10))
    env.update({'sh.'+k: v for k, v in shifts.items()})
    def plane(s, k=None):
        m = re.fullmatch(r'ids\.at\((A_\w+)\)', s)
        if m: return m[1]
        m = re.fullmatch(r'ids\.(nr|ns|mr|ms|pl|sr|sg)\((.*)\)', s)
        assert m, s
        ix = k if m[2] == 'k' else scalar(m[2], env)
        return m[1]+str(ix)
    def expr(s):
        if s.startswith('sym('):
            p = plane(s[4:-1]); return [([(p,1)],127), ([(p,-1)],127)]
        if s.startswith('byte('): return [([(plane(s[5:-1]),1)],0)]
        assert s.startswith('scaled('), s
        p, c = split_args(s[7:-1]); return [([(plane(p),scalar(c,env))],0)]
    out = {}
    for dom, arm in arms:
        lines = [l.split('//')[0].strip() for l in arm.splitlines()]
        cols, condition = [], False
        for line in lines:
            if not line: continue
            if line == 'if norm_top {': condition=True; continue
            if line == '}': condition=False; continue
            if condition and norm_w == 8*ln: continue
            m = re.fullmatch(r'v\.extend\(\(0\.\.(ln|ls|lp)\)\.map\(\|k\| byte\((.*?)\)\)\);', line)
            if m:
                cols.extend([([(plane(m[2],k),1)],0) for k in range(env[m[1]])]); continue
            m = re.fullmatch(r'v\.(push|extend)\((.*)\);',line)
            assert m, line
            s = m[2]
            if s.startswith('['):
                for item in split_args(s[1:-1]): cols.extend(expr(item))
            else: cols.extend(expr(s))
        out[dom]=cols
    return out

def reference_catalog(ln,ls,lp,norm_w,soft_w,s):
    """Independently specified semantic families, no Rust parser calls."""
    def b(p): return ([(p,1)],0)
    def sc(p,c): return ([(p,c)],0)
    def sy(p): return [([(p,1)],127), ([(p,-1)],127)]
    def limbs(p,n): return [b(p+str(k)) for k in range(n)]
    d=[b('A_XL0'),b('A_XL1')]+sy('A_Y')
    for pre in ['nr','ns']:
        d+=limbs(pre,ln)
        if norm_w<8*ln: d+=[sc(pre+str(ln-1),1 << (8*ln-norm_w))]
    d += [b('A_AL0'),b('A_AL1'),b('A_RAL'),sc('A_RAL',1 << (8-s['sh_ao'])),b('A_X1L0'),b('A_X1L1')]+sy('A_YM')
    for pre in ['mr','ms']:
        d+=limbs(pre,ln)
        if norm_w<8*ln: d+=[sc(pre+str(ln-1),1 << (8*ln-norm_w))]
    d += [b('A_X2L0'),b('A_X2L1'),b('A_ZL0'),b('A_ZL1'),b('A_RDL'),sc('A_RDL',1 << (8-s['sh_z']))]
    f=[b('A_RGL'),sc('A_RGL',1 << (8-s['sh_g']))]+[b(p) for p in ['A_UL0','A_UL1','A_HL0','A_HL1','A_RH0','A_RH1']]+[sc('A_RH1',1 << (16-s['sh_h']))]
    q=sy('A_Q8')+[b('A_RQL'),sc('A_RQL',1 << (8-s['sh_qkv']))]+sy('A_QR8')+[b('A_RQRL'),sc('A_RQRL',2)]+sy('A_O8')+[b('A_RO0'),b('A_RO1'),sc('A_RO1',1 << (16-s['sh_o']))]
    kv=[]
    for p,r in [('A_K8','A_RKL'),('A_V8','A_RVL')]: kv+=sy(p)+[b(r),sc(r,1 << (8-s['sh_qkv']))]
    kv+=sy('A_KR8')+[b('A_RKRL'),sc('A_RKRL',2)]
    z=sy('A_S8')+[b('A_RSL'),sc('A_RSL',1 << (8-s['sh_s']))]+limbs('pl',lp)+[sc('pl'+str(lp-1),1 << (8*lp-10))]
    for pre in ['sr','sg']: z+=limbs(pre,ls)+[sc(pre+str(ls-1),1 << (8*ls-soft_w))]
    return dict(L=[b('A_LIMB'),b('A_LIMBM')],D=d,F=f,Q=q,Kv=kv,S=z)

def direct(lk):
    terms,cst=lk
    return cst==0 and len(terms)==1 and terms[0][1]==1

def materialize(lk,planes,n):
    terms,cst=lk
    return [wrap(cst+sum(wrap(c*planes[p][i]) for p,c in terms)) for i in range(n)]

class Borrowed:
    def __init__(self,plane,n):
        if len(plane)<n: raise IndexError('short plane')
        self.plane,self.n=plane,n
    def __len__(self): return self.n
    def __iter__(self): return (self.plane[i] for i in range(self.n))
    def __getitem__(self,i):
        if not 0<=i<self.n: raise IndexError(i)
        return self.plane[i]
    def __eq__(self,other): return list(self)==list(other)

def cow(lk,planes,n):
    if direct(lk):
        return Borrowed(planes[lk[0][0][0]],n)
    return materialize(lk,planes,n)

def independent_values(lk,planes,n):
    # Independent signed conversion and term-by-term accumulator implementation.
    ans=[]
    for i in range(n):
        a=ctypes.c_int64(lk[1]).value
        for p,c in lk[0]: a=ctypes.c_int64(a+ctypes.c_int64(c*planes[p][i]).value).value
        ans.append(a)
    return ans

def add(a,b): return ((a[0]+b[0])%P,(a[1]+b[1])%P)
def inv(z):
    x,y=z; den=(x*x-7*y*y)%P
    if den==0: raise ValueError('zero denominator')
    d=pow(den,P-2,P); return x*d%P,-y*d%P
def den(v,a,g): return ((a[0]-v-g[0])%P,(a[1]-g[1])%P)

def helpers(cols,alpha,g,cache):
    def one(v):
        if 0<=v<256:
            ans=cache[v]
            if ans is None: raise ValueError('zero denominator')
            return ans
        return inv(den(v,alpha,g))
    out=[]
    for k in range(0,len(cols),2):
        out.append([add(one(x),one(cols[k+1][i])) if k+1<len(cols) else one(x) for i,x in enumerate(cols[k])])
    return out

def hist(cols):
    a=[0]*256
    for c in cols:
        for x in c: a[x if 0<=x<256 else 0]+=1
    return a

def main():
    start=time.perf_counter(); os.nice(19); os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2)); resource.setrlimit(resource.RLIMIT_CPU,(59,59)); signal.alarm(59)
    text=(HERE/'native/layout.rs').read_text(); rng=random.Random(SEED)
    counts=collections.Counter(); digest=hashlib.sha256(); controls=[]
    def reject(label,fn):
        try: fn()
        except (AssertionError,ValueError,IndexError): controls.append(label); return
        raise AssertionError('control survived: '+label)
    def same(a,b): assert a==b
    for case in range(48):
        ln=4; ls=2+case%2; lp=2; nw=29+case%4; sw=8*ls-(case%7)
        shifts=dict(sh_ao=case%9,sh_qkv=1+case%8,sh_s=1+(case+1)%8,sh_g=1+(case+2)%8,sh_z=1+(case+3)%8,sh_o=9+case%8,sh_h=9+(case+1)%8)
        cat=source_catalog(text,ln,ls,lp,nw,sw,shifts); refcat=reference_catalog(ln,ls,lp,nw,sw,shifts); assert cat==refcat
        n=1+case%11; alpha=(1000+case,1+case); g=(17,9)
        cache=[inv(den(v,alpha,g)) for v in range(256)]
        for dom,lks in cat.items():
            # Real catalog evaluated on public synthetic planes; arbitrary pad words included.
            pnames={p for lk in lks for p,c in lk[0]}
            palette=[-2**63,2**63-1,-32768,-128,-1,0,1,127,128,255,256,32767]
            planes={p:[rng.choice(palette) if case%3 else rng.randrange(256) for _ in range(n)] for p in sorted(pnames)}
            base=[materialize(lk,planes,n) for lk in lks]; candidate=[cow(lk,planes,n) for lk in lks]; reference=[independent_values(lk,planes,n) for lk in refcat[dom]]
            assert base==candidate==reference; assert hist(base)==hist(candidate)
            hh=helpers(candidate,alpha,g,cache)
            rh=[]
            for k in range(0,len(reference),2):
                single=[[inv(den(v,alpha,g)) for v in col] for col in reference[k:k+2]]
                rh.append([add(single[0][i],single[1][i]) if len(single)==2 else single[0][i] for i in range(n)])
            assert hh==rh
            counts['domains']+=1; counts['columns']+=len(lks); counts['words']+=len(lks)*n; counts['helper_fp2_words']+=sum(map(len,hh)); counts['borrowed_columns']+=sum(map(direct,lks))
            assert all(isinstance(candidate[i],Borrowed)==direct(lk) for i,lk in enumerate(lks))
            assert all(not direct(lk) or candidate[i].plane is planes[lk[0][0][0]] for i,lk in enumerate(lks))
            digest.update(json.dumps([[list(c) for c in candidate],hist(candidate),hh],separators=(',',':')).encode())
        counts['fixtures']+=1
    # Future grammar / nonidentity negative controls and dishonest-input behavior.
    planes={'x':[-2**63,2**63-1,256,-1,17],'y':[7,-2**63,1,3,9]}; n=5
    extra=[([('x',1)],7),([('x',-1)],0),([('x',2)],0),([('x',1),('y',1)],0),([],5)]
    for lk in extra:
        assert not direct(lk); assert cow(lk,planes,n)==independent_values(lk,planes,n); counts['generic_columns']+=1
    reject('constant offset wrongly borrowed',lambda:same(planes['x'],independent_values(extra[0],planes,n)))
    reject('scaled column wrongly borrowed',lambda:same(planes['x'],independent_values(extra[2],planes,n)))
    reject('multiterm column wrongly borrowed',lambda:same(planes['x'],independent_values(extra[3],planes,n)))
    reject('truncated padded plane',lambda:cow(([('x',1)],0),planes,6))
    assert cow(([('x',1)],0),planes,4)==materialize(([('x',1)],0),planes,4)
    counts['oversized_prefix_checks']+=1
    reject('saturating instead of wrapping affine',lambda:same([min(2**63-1,max(-2**63,2*x)) for x in planes['x']],materialize(extra[2],planes,n)))
    reject('out-of-range value silently clamped',lambda:same(hist([planes['x']]),hist([[min(255,max(0,x)) for x in planes['x']]])))
    alpha=(29,0); g=(0,0); cache=[]
    for v in range(256):
        try: cache.append(inv(den(v,alpha,g)))
        except ValueError: cache.append(None)
    assert helpers([[1,2,3]],alpha,g,cache)
    reject('present-byte zero denominator',lambda:helpers([[1,29,3]],alpha,g,cache))
    # Actual table helpers visit every table row, even when histogram multiplicity is zero.
    reject('absent-byte still refuses at full-table helper',lambda:[inv(den(v,alpha,g)) for v in range(256)])
    reject('out-of-range zero denominator fallback',lambda:helpers([[256]],(256,0),g,[inv(den(v,(256,0),g)) for v in range(256)]))
    a=(1000,3); g=(17,9); cache=[inv(den(v,a,g)) for v in range(256)]
    reject('helper pair order changed',lambda:same(helpers([[1,2],[3,4],[5,6]],a,g,cache),helpers([[1,2],[5,6],[3,4]],a,g,cache)))
    reject('new source expression ignored',lambda:source_catalog(text.replace('v.push(byte(ids.at(A_LIMB)));','v.push(unknown(ids.at(A_LIMB)));'),4,2,2,32,16,shifts))
    # Count only public geometry; never allocate a model-sized plane.
    census=[]
    trained=json.loads((HERE/'public-calibration.json').read_text())['shifts']
    for model,d,f,h,kv,dh in [('TinyLlama1.1B',2048,5632,32,4,64),('Llama3-8B',4096,14336,32,8,128)]:
        for t in [32,64,128,256,512,1024]:
            ls=(t.bit_length()-1+9+7)//8; n=(4096 if d==2048 else 8192)*(t//32)
            lens=dict(L=max(n,16*t),D=max(n,t*d),F=max(n,t*(1<<(f-1).bit_length())),Q=max(n,t*h*dh),Kv=max(n,t*kv*dh),S=max(n,h*t*t))
            cat=source_catalog(text,4,ls,2,32,t.bit_length()-1+9,trained)
            dc={dom:dict(columns=len(lks),borrowable=sum(map(direct,lks)),padded_words=lens[dom]) for dom,lks in cat.items()}
            allbytes=sum(x['columns']*x['padded_words']*8 for x in dc.values()); saved=sum(x['borrowable']*x['padded_words']*8 for x in dc.values())
            duplicate_words=sum((len(lks)-len({(tuple(lk[0]),lk[1]) for lk in lks}))*lens[dom] for dom,lks in cat.items())
            census.append(dict(model=model,context=t,log_cols=n.bit_length()-1,ls=ls,domains=dc,baseline_looked_bytes=allbytes,borrowed_payload_bytes=saved,remaining_owned_bytes=allbytes-saved,fraction=saved/allbytes,duplicate_histogram_word_visits=duplicate_words,scope='allocation-free source count; same public shifts as TinyLlama export; 8B calibration hypothetical; not peak or traffic or admission; duplicate histogram optimization untested'))
    out=dict(status='pass',run_id='20261017T122624Z-c30acfa0',cycle='0062',seed=SEED,counts=dict(counts),controls=controls,output_sha256=digest.hexdigest(),census=census,experiment_wall_seconds=time.perf_counter()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,cpu_affinity=sorted(os.sched_getaffinity(0)),threads=1,nice=os.nice(0),limits='59s CPU/wall;512MiB AS; estimated<64MiB; no GPU',executed_source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),scope='synthetic Python differential; source-derived catalog equals independent semantic catalog; no native build/proof/performance/privacy acceptance',proof_accounting=dict(accepted_complete_private_8b_proofs=0,passes=0,positions=0,context=None,steady_rate=None,total_workload_rate=None,startup_s=None,startup_fraction=None,witness_s=None,proof_s=None,serialization_s=None,verification_s=None,lag_s=None,drain_s=None,prefill_ran=False,resident_passes_ran=False,decode_ran=False))
    (HERE/'result.json').write_text(json.dumps(out,indent=2)+'\n'); print(json.dumps({k:out[k] for k in ['status','counts','controls','experiment_wall_seconds','peak_rss_kib']}))

if __name__=='__main__': main()
