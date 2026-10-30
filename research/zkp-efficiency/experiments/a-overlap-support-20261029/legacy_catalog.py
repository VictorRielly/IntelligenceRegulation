"""Locally authored source-derived Priv metadata, not execution of native define.

Only synthetic/public geometry. All reservations are distinct, including repeated
plane accesses. This catalog models accepted metadata, not native refusals.
"""
from dataclasses import dataclass
from collections import Counter

NAMES = 'SS SSM TZC LZC RS QMM KMM VMM SCORE PV WO GMM UMM DMM DZC QZC KVZC SZC FZC TAB ZS IO_IN IO_OUT DD'.split()
def lg(x): return (x-1).bit_length()
def rh(n): return tuple(('rho', i) for i in range(n))
def fx(label, n): return tuple(('fixed', (label, i)) for i in range(n))

@dataclass(frozen=True)
class Geometry:
    name: str
    t: int
    d: int
    f: int
    h: int
    dh: int
    kv: int
    row: int
    endpoint: int
    ln: int = 4
    ls: int = 3
    lp: int = 2
    full_norm: bool = True
    dd: int = 0
    def domains(self):
        out = dict(T=lg(self.t), Ht=lg(self.h*self.t), L=lg(16*self.t),
                   D=lg(self.t*self.d), Q=lg(self.t*self.h*self.dh),
                   Kv=lg(self.t*self.kv*self.dh), S=lg(self.h*self.t*self.t),
                   F=lg(self.t*self.f), Tab=8, Dd=lg(self.h*self.t*max(1,self.dd)))
        # Dom::carries_h_planes excludes only T/Ht. P-3 lift.
        return {k:(v if k in ('T','Ht') else max(v,self.row)) for k,v in out.items()}
    def planes(self):
        return dict(T=4,Ht=2,L=2,D=19+4*self.ln,Q=7,Kv=6,
                    S=5 if self.dd else 5+self.lp+2*self.ls,F=11,Tab=3,
                    Dd=2+self.lp+2*self.ls if self.dd else 0)
    def helpers(self):
        pn=2+2*(self.ln+int(not self.full_norm))
        look=dict(L=2,D=14+2*pn,Q=13,Kv=12,F=9,
                  S=4 if self.dd else 5+self.lp+2*(self.ls+1),
                  Dd=(self.lp+1)+2*(self.ls+1) if self.dd else 0)
        return {k:(n+1)//2 for k,n in look.items()}

@dataclass(frozen=True)
class Site:
    slot: int
    cm: str
    log: int
    row: int
    coords: tuple
    c0: int
    pair: int
    ext: int
    label: str
    @property
    def tail(self):
        m=min(self.row,self.log)
        return self.coords[self.log-m:]

def catalog(g):
    ds,ps,hs=g.domains(),g.planes(),g.helpers()
    out=[[] for _ in range(24 if g.dd else 23)]
    pairs=Counter()
    def add(slot,cm,dom=None,coords=None,ext=0,label='',log=None,c0=0):
        log=ds[dom] if log is None else log
        coords=rh(log) if coords is None else tuple(coords)
        assert len(coords)==log
        row=g.endpoint if cm in ('In','Out') else g.row
        c0=(c0 % (1<<row)) if log<row else 0
        assert c0+(1<<min(log,row)) <= 1<<row
        p=pairs[cm];pairs[cm]+=1
        out[slot].append(Site(slot,cm,log,row,coords,c0,p,ext,label))
    def many(s,cm,dom,n):
        for j in range(n):add(s,cm,dom,label=f'{dom}:{j}')
    for s in (0,1):add(s,'A','D')
    # Source push order: D,DSQ, nine limb subslices, DM,DSQM,nine subslices.
    for norm in range(2):
        many(2,'A','T',2)
        for j in range(9):add(2,'A','T',c0=j*g.t,label=f'limb{norm}:{j}')
    many(3,'A','L',2);many(3,'H','L',hs['L'])
    many(4,'A','S',2)
    lt,lh,ldh,lkv=map(lg,(g.t,g.h,g.dh,g.kv))
    for s in (5,6,7,10,11,12,13):
        inner=lg(g.f if s==13 else g.h*g.dh if s==10 else g.d)
        add(s,'A',coords=fx('r_td' if s==13 else 'r_tf' if s in (11,12) else 'r_q',lt)+rh(inner),log=lt+inner)
    add(8,'A','Q',fx('r_t',lt)+rh(lkv)+fx('r_hj',lh-lkv)+tuple(('rho',i) for i in range(lkv,lkv+ldh)))
    add(8,'A','Kv',fx('r_j',lt)+rh(lkv)+tuple(('rho',i) for i in range(lkv,lkv+ldh)),ext=1)
    add(9,'A','S',rh(lkv)+fx('r_hj',lh-lkv)+fx('r_t',lt)+tuple(('rho',i) for i in range(lkv,lkv+lt)))
    add(9,'A','Kv',tuple(('rho',i) for i in range(lkv,lkv+lt))+rh(lkv)+fx('r_i',ldh),ext=1)
    many(14,'A','D',ps['D']);many(14,'A','T',2);many(14,'H','D',hs['D'])
    for s,dom in ((15,'Q'),(16,'Kv')):
        many(s,'A',dom,ps[dom])
        cs=list(rh(ds[dom]));i=ds[dom]-ldh;cs[i]=('flip',i)
        add(s,'A',dom,coords=cs,label='RoPE partner')
        many(s,'H',dom,hs[dom])
    many(17,'A','S',ps['S']);many(17,'A','Ht',2)
    many(17,'H','S',hs['S']+1+int(bool(g.dd)))
    many(18,'A','F',ps['F']);many(18,'H','F',hs['F']+1)
    for j in range(3):add(19,'A','Tab',label=str(j));add(19,'H','Tab',label=str(j))
    add(20,'H','Tab')
    for s,cm in ((21,'In'),(22,'Out')):add(s,'A','D');add(s,cm,'D')
    if g.dd:
        many(23,'A','Dd',ps['Dd']);add(23,'A','Ht');many(23,'H','Dd',hs['Dd']+1)
    return out

def schedule(sites):
    return [p for ext in range(2) for p in sites if p.ext==ext]

def census(g, capacity):
    rows=[]
    for s,sites in enumerate(catalog(g)):
        cache=[];builds=[];seq=schedule(sites)
        for p in seq:
            key=p.tail
            if key in cache:cache.remove(key)
            else:
                builds.append(key)
                if len(cache)==capacity:cache.pop(0)
            cache.append(key)
        n=sum(1<<len(p.tail) for p in seq)
        baseline=sum(2*((1<<len(p.tail))-1) for p in seq)
        candidate=sum(2*((1<<len(k))-1) for k in builds)
        rows.append(dict(slot=s,name=NAMES[s],sites=len(seq),
                         counts=dict(Counter(p.cm for p in seq)),tail_logs=dict(Counter(len(p.tail) for p in seq)),
                         distinct_symbolic_tails=len(set(p.tail for p in seq)),
                         builds=len(builds),hits=len(seq)-len(builds),
                         baseline_eq_mul=baseline,candidate_eq_mul=candidate,
                         removed_eq_mul=baseline-candidate,private_base_word_reads=2*n,
                         paired3_saved_variable_products=n,
                         paired3_public_sum_additions_baseline=n,
                         prepared_public_sum_additions=sum(1<<len(k) for k in builds),
                         max_entry_bytes=max(16*(1<<len(p.tail)) for p in seq)))
    total={k:sum(r[k] for r in rows) for k in ('sites','builds','hits','baseline_eq_mul','candidate_eq_mul','removed_eq_mul','private_base_word_reads','paired3_saved_variable_products','paired3_public_sum_additions_baseline','prepared_public_sum_additions')}
    return dict(geometry=g.__dict__,capacity=capacity,slots=rows,totals=total,
                note='Source-derived metadata and operation counts, not executed native define, physical traffic, model work, or proof time.')
