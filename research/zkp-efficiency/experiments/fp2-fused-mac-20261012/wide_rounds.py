"""Copied local grouped schedule with only the weighted accumulator replaced."""
from field_support import F, lagrange
from baseline import TaggedRounds, eq_table, bracket
from accumulator import WideDot
from collections import Counter

class AccumRounds(TaggedRounds):
    def __init__(self,tabs,n,degree,groups,kind=WideDot,chunk=1024,debug=False):
        super().__init__(tabs,n,degree,groups)
        self.kind,self.chunk,self.debug=kind,chunk,debug; self.counts=Counter()
    def round(self,j):
        if j!=self.j or j>=self.n or self.pending is not None: raise ValueError('round order')
        half=1<<(self.n-j-1); descriptors=[]
        for g,(index,terms) in enumerate(self.groups):
            desc=self.slots[index]; w,s,scalar=desc['point'],desc['start'],desc['scalar']
            active=s<=j<s+len(w)
            factors=[scalar*((1-w[j-s])+(2*w[j-s]-1)*t) if active else scalar for t in range(self.degree+1)]
            consumed=min(max(j+1-s,0),len(w)); suffix=w[consumed:]; split=len(suffix)//2
            left,right=eq_table(suffix[:split]),eq_table(suffix[split:])
            trailing=self.n-s-len(w) if suffix else 0
            d=max(len(ix) for c,ix in terms)
            recover=self.claims[g] is not None and factors[1]!=0
            if self.claims[g] is not None:
                if recover: self.recoveries+=1
                else: self.zero_fallbacks+=1
            accum=[self.kind(self.chunk) for _ in range(d+1)]
            descriptors.append((factors,left,right,trailing,len(suffix),d,accum,recover,terms))
        max_degree=max(rg[5] for rg in descriptors)
        for row in range(half):
            values=[F() for _ in self.slots]; dif=[F() for _ in self.slots]
            for k in self.data_indices:
                values[k]=self.slots[k][row]; dif[k]=self.slots[k][row+half]-values[k]
            weights=[]
            for factors,left,right,trailing,length,d,accum,recover,terms in descriptors:
                pos=(row>>trailing)&((1<<length)-1)
                weights.append(left[pos//len(right)]*right[pos%len(right)])
            for t in range(max_degree+1):
                for g,rg in enumerate(descriptors):
                    factors,left,right,trailing,length,d,accum,recover,terms=rg
                    if t<=d and (t!=1 or not recover or self.debug):
                        accum[t].push(weights[g],bracket(terms,values))
                if t!=max_degree:
                    for k in self.data_indices: values[k]+=dif[k]
        all_groups=[]
        for g,rg in enumerate(descriptors):
            factors,left,right,trailing,length,d,accum,recover,terms=rg
            hs=[a.finish() for a in accum]
            for a in accum: self.counts.update(a.counts)
            if recover:
                recovered=(self.claims[g]-factors[0]*hs[0])/factors[1]
                if self.debug: assert recovered==hs[1]
                hs[1]=recovered
            all_groups.append([factors[t]*(hs[t] if t<=d else lagrange(hs,F(t))) for t in range(self.degree+1)])
        self.pending=all_groups
        return [sum((a[t] for a in all_groups),F()) for t in range(self.degree+1)]
