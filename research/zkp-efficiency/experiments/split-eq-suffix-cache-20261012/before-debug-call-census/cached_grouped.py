"""Serial source-derived GroupedEqRounds over an explicit heterogeneous cube.

Representation experiment only. No transcript, masks, RNG or proof messages.
The complete original table order, including dense equality planes, survives.
"""
from dataclasses import dataclass
from collections import Counter
from field import F
from driver import interpolate
from suffix_cache import SuffixCache

@dataclass
class Group:
    point: list
    start: int
    bracket_degree: int

def eq_table(point):
    out = [F(1)]
    for w in point:
        out = [v*x for v in out for x in (1-w,w)]
    return out

class CachedGrouped:
    def __init__(self, tables, degree, groups, bracket, chunk=1024, debug=False):
        if not groups or type(degree) is not int or degree < 1:
            raise ValueError('group or degree')
        if type(chunk) is not int or chunk < 1 or tables.bound:
            raise ValueError('chunk or initial state')
        for g in groups:
            if (type(g.start) is not int or g.start < 0 or
                g.start > tables.n or len(g.point) > tables.n-g.start or
                type(g.bracket_degree) is not int or g.bracket_degree < 1 or
                g.bracket_degree > degree-bool(g.point)):
                raise ValueError('equality group extent or degree')
        self.tables,self.degree,self.groups,self.bracket = tables,degree,groups,bracket
        self.chunk,self.debug = chunk,debug
        self.prefix = [F(1) for _ in groups]
        self.claims = [None for _ in groups]  # Never an asserted combined host.
        self.pending = None
        self.counts = Counter()
        self.caches = [SuffixCache(g.point,g.start,tables.n) for g in groups]

    def round(self,j):
        n = self.tables.n
        if j != self.tables.bound or j >= n or self.pending is not None:
            raise ValueError('grouped round schedule')
        plans = []
        for g,desc in enumerate(self.groups):
            end = desc.start+len(desc.point)
            active = desc.start <= j < end
            factor = [self.prefix[g]*((1-desc.point[j-desc.start])+
                        (2*desc.point[j-desc.start]-1)*x) if active else self.prefix[g]
                      for x in range(self.degree+1)]
            consumed = min(max(j+1-desc.start,0),len(desc.point))
            suffix = desc.point[consumed:]; split = len(suffix)//2
            left,right,ns,trailing = self.caches[g].pair(j,desc.point,desc.start)
            assert ns == len(suffix)
            inv = F(1)/factor[1] if self.claims[g] is not None and factor[1] != 0 else None
            if self.claims[g] is not None and inv is None:
                self.counts['zero_factor_explicit_fallbacks'] += 1
            self.counts['split_eq_view_entries'] += len(left)+len(right)
            self.counts['split_eq_peak_entries'] = max(self.counts['split_eq_peak_entries'],len(left)+len(right))
            plans.append((factor,left,right,len(suffix),trailing,inv))
        half=1 << (n-j-1)
        hs=[[F() for _ in range(g.bracket_degree+1)] for g in self.groups]
        top=max(g.bracket_degree for g in self.groups)
        for lo in range(0,half,self.chunk):
            parts=[[F() for _ in row] for row in hs]
            for i in range(lo,min(half,lo+self.chunk)):
                cur,hi=self.tables.row(i),self.tables.row(i+half)
                self.counts['table_endpoint_reads'] += 2*len(cur)
                diff=[b-a for a,b in zip(cur,hi)]
                weights=[]
                for factor,left,right,ns,trailing,inv in plans:
                    pos=(i >> trailing)&((1 << ns)-1)
                    weights.append(left[pos//len(right)]*right[pos%len(right)])
                for x in range(top+1):
                    for g,desc in enumerate(self.groups):
                        if x <= desc.bracket_degree and (x != 1 or plans[g][-1] is None or self.debug):
                            parts[g][x] += weights[g]*self.bracket(g,cur)
                            self.counts['bracket_calls_'+str(g)] += 1
                    if x != top: cur=[a+d for a,d in zip(cur,diff)]
            hs=[[a+b for a,b in zip(row,part)] for row,part in zip(hs,parts)]
        pending=[]; result=[F() for _ in range(self.degree+1)]
        for g,(factor,left,right,ns,trailing,inv) in enumerate(plans):
            if inv is not None:
                recovered=(self.claims[g]-factor[0]*hs[g][0])*inv
                if self.debug and recovered != hs[g][1]:
                    raise ValueError('actual group running claim mismatch')
                hs[g][1]=recovered; self.counts['group_recoveries'] += 1
            values=[factor[x]*(hs[g][x] if x < len(hs[g]) else interpolate(hs[g],F(x)))
                    for x in range(self.degree+1)]
            pending.append(values); result=[a+b for a,b in zip(result,values)]
        self.pending=pending
        return result

    def bind(self,r):
        if self.pending is None: raise ValueError('grouped bind needs round')
        j=self.tables.bound
        for g,desc in enumerate(self.groups):
            self.claims[g]=interpolate(self.pending[g],r)
            if desc.start <= j < desc.start+len(desc.point):
                w=desc.point[j-desc.start]
                self.prefix[g] *= (1-w)*(1-r)+w*r
        self.tables.bind(r); self.pending=None
        for cache in self.caches: cache.finish_round(j)

    def finals(self):
        if self.pending is not None: raise ValueError('grouped finals pending')
        for cache in self.caches: cache.terminal()
        return self.tables.finals()
