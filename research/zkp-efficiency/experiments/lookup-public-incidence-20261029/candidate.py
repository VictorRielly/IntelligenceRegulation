"""Public exact-expression plan; private columns live only inside one invocation.

This is a synthetic Python model of a Rust interface, not a native proof path.
All logical descriptors, repetitions, helper positions and masks remain.
"""
from collections import Counter
from dataclasses import dataclass

def i64(x):
    return ((x + (1 << 63)) % (1 << 64)) - (1 << 63)

@dataclass(frozen=True)
class Expr:
    domain: str
    source: str
    coefficient: int = 1
    constant: int = 0

def catalog(h24, dd, wrho, p=None, gate=18):
    p = p or dict(q=15,k=15,v=16,score=18,pv=12,ao=21,down=20 if h24 else 12,up=12)
    ls=(wrho+7)//8
    result={d:[] for d in ('L','D','Q','Kv','S','F','Dd')}
    def group(d,g,n,bits=None):
        result[d].extend(Expr(d,f'{g}:{k}') for k in range(n))
        if bits is not None:
            if not 8*(n-1)<bits<=8*n: raise ValueError('window')
            result[d].append(Expr(d,f'{g}:{n-1}',1<<(8*n-bits)))
    for name in ('A_LIMB','A_LIMBM'): result['L'].append(Expr('L',name))
    for g,n,b in [('X',2,None),('Y',2,None),('Nr',3,None),('Ns',3,None),('Ao',2,None),
                  ('Rao',3,p['ao']),('X1',2,None),('Ym',2,None),('Mr',3,None),('Ms',3,None),
                  ('Z',2,None),('Rd',3 if h24 else 2,p['down']),('X2',2,None)]:group('D',g,n,b)
    for g,n,b in [('Q',2,None),('Rq',2,p['q']),('Qr',2,None),('Rqr',1,7),('O',2,None),('Ro',2,p['pv'])]:group('Q',g,n,b)
    for g,n,b in [('K',2,None),('Rk',2,p['k']),('V',2,None),('Rv',2,p['v']),('Kr',2,None),('Rkr',1,7)]:group('Kv',g,n,b)
    for g,n,b in [('Rg',3,gate),('Up',2,None),('Ru',2,p['up']),('H',3 if h24 else 2,None),('Rh',2 if h24 else 3,None)]:group('F',g,n,b)
    result['S']=[Expr('S','A_S8',1,127),Expr('S','A_S8',-1,127)]
    group('S','Rs',3,p['score'])
    for g,n,b in [('P',2,13),('Sr',ls,wrho),('Sg',ls,wrho)]:group('Dd' if dd else 'S',g,n,b)
    return result

class Plan:
    def __init__(self, expressions):
        self.unique=[]; self.order=[]; by_expr={}
        for e in expressions:
            if e not in by_expr:
                by_expr[e]=len(self.unique); self.unique.append(e)
            self.order.append(by_expr[e])
        self.multiplicities=Counter(self.order)

    def prepare(self, sources):
        # No state retained in Plan. New source values are read on every call.
        return Prepared(self,tuple(tuple(i64(e.constant+i64(e.coefficient*x))
                                        for x in sources[e.source]) for e in self.unique))

class Prepared:
    def __init__(self, plan, columns):
        self.plan=plan; self.columns=columns
    def logical(self):
        return tuple(self.columns[i] for i in self.plan.order)
    def histogram_and_misses(self):
        h=[0]*256; misses=0
        for i,multiplicity in self.plan.multiplicities.items():
            for v in self.columns[i]:
                if 0<=v<256:h[v]+=multiplicity
                else:h[0]+=multiplicity;misses+=multiplicity
        return h,misses

def geometry(t,width,hidden,qwidth,kvwidth,row,dd):
    up=lambda n:1<<(n-1).bit_length()
    return {d:max(row,n) for d,n in dict(L=16*up(t),D=up(t)*up(width),Q=up(t)*up(qwidth),
              Kv=up(t)*up(kvwidth),S=32*up(t)**2,F=up(t)*up(hidden),Dd=32*up(t)*32 if dd else 0).items()}

def cost(catalogue,sizes):
    rows=[]
    for d,es in catalogue.items():
        if not es:continue
        plan=Plan(es);n=sizes[d];aliases=len(es)-len(plan.unique)
        rows.append(dict(domain=d,logical_columns=len(es),unique_columns=len(plan.unique),
                         aliases=aliases,domain_positions=n,logical_bytes=len(es)*n*8,
                         prepared_bytes=len(plan.unique)*n*8,avoided_materialized_bytes=aliases*n*8,
                         retained_helper_planes=(len(es)+1)//2,
                         hypothetical_profile_removed_helpers=(len(es)+1)//2-(len(plan.unique)+1)//2))
    return rows

def helpers(prepared,alpha,tag):
    prime=2**64-2**32+1
    # Independently written inverse calculation; retain logical pair order.
    def inv(v):
        re=(alpha[0]-tag[0]-v)%prime;im=(alpha[1]-tag[1])%prime
        n=(re**2-7*im**2)%prime
        if n==0:return None
        u=pow(n,prime-2,prime)
        return re*u%prime,(-im*u)%prime
    out=[];order=prepared.plan.order
    for first in range(0,len(order),2):
        group=[]
        for x in range(len(prepared.columns[order[first]])):
            re=im=0
            for ordinal in range(first,min(len(order),first+2)):
                z=inv(prepared.columns[order[ordinal]][x])
                if z is None:return ('refused',first//2,ordinal,x)
                re=(re+z[0])%prime;im=(im+z[1])%prime
            group.append((re,im))
        out.append(tuple(group))
    return tuple(out)
