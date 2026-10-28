"""Host-free raw-round-zero BASE GL-only model; PL and fallback literal.
The base flag is supplied by EXISTING eligibility, never inferred here.
Both coordinates of coefficients, GL/PL results, high stores remain.
Logical reads are source operand bytes after dead-code elimination only.
"""
from affine import Z,pair,pl
from base_pair import component

def derived(o,lo,delta,p,supp,base):
    if not base:
        return pair(o,lo,delta,p,supp,'literal')
    out=[(component(o,lo,p,False),component(o,delta,p,True))]
    reads=128
    if supp:
        inds=[j for j,w in enumerate(p['pad']) if w!=Z]
        low=[Z]*11;high=[Z]*11
        for j in inds:
            low[j]=lo[j];high[j]=o.a(lo[j],delta[j])
        v=pl(o,low,p);hi=pl(o,high,p)
        out.append((v,o.s(hi,v)))
        reads+=48*len(inds)
    return out,reads
