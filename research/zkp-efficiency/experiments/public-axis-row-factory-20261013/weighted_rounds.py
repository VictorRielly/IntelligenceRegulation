"""Reduce suffix-weighted row coefficients, then evaluate original samples.

No protocol/degree/challenge change. Five part outputs replace the five
group-0 sample slots. Other groups and all data interpolation are retained.
Public half>=2 policy retains baseline for a final one-row round.
"""
from collections import Counter
from field_support import F, lagrange
from row_rounds import SteppedRounds, eq_table, bracket
from coefficients import Coeff

class WeightedRounds(SteppedRounds):
    def __init__(self,*args,policy='public_half',reduction='forward',**kw):
        super().__init__(*args,**kw)
        assert policy in ('public_half','always','rows')
        assert reduction in ('forward','reverse')
        self.policy,self.reduction=policy,reduction
        self.work=Counter(); self.weighted_rounds=0; self.baseline_rounds=0

    def round(self,j):
        if j!=self.j or j>=self.n or self.pending is not None: raise ValueError('round order')
        half=1<<(self.n-j-1); descriptors=[]
        selected=self.row_plan.coefficient_groups if self.policy!='rows' and (half>=2 or self.policy=='always') else set()
        if selected: self.weighted_rounds+=1
        else: self.baseline_rounds+=1
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
            descriptors.append((factors,left,right,trailing,len(suffix),d,recover,terms))
        max_degree=max(rg[5] for rg in descriptors); parts=[]
        for start in range(0,half,self.chunk):
            self.chunks+=1; stop=min(start+self.chunk,half)
            if self.mutation=='drop_ragged' and stop-start<self.chunk: continue
            sums=[[F() for _ in range(rg[5]+1)] for rg in descriptors]
            for row in range(start,stop):
                values=[F() for _ in self.slots]; dif=[F() for _ in self.slots]
                for k in self.data_indices:
                    values[k]=self.slots[k][row]; dif[k]=self.slots[k][row+half]-values[k]
                self.row_plan.begin(values,dif)
                weights=[]
                for factors,left,right,trailing,length,d,recover,terms in descriptors:
                    pos=(row>>trailing)&((1<<length)-1)
                    weights.append(left[pos//len(right)]*right[pos%len(right)])
                for g in selected:
                    co=self.row_plan.pending[g].c
                    assert len(co)==len(sums[g]), 'fixed public coefficient width'
                    for i,c in enumerate(co):
                        weight=F(1) if self.mutation=='omit_suffix_weight' else weights[g]
                        sums[g][i]+=weight*c
                        self.work.update(mul=1,add=1)
                for t in range(max_degree+1):
                    for g,rg in enumerate(descriptors):
                        factors,left,right,trailing,length,d,recover,terms=rg
                        if g not in selected and t<=d and (t!=1 or not recover or self.debug):
                            sums[g][t]+=weights[g]*bracket(terms,values)
                            self.work.update(mul=1,add=1)
                    if t!=max_degree:
                        for k in self.data_indices: values[k]+=dif[k]
                        self.row_plan.advance()
                self.row_plan.end()
            parts.append(sums)
        if self.mutation=='drop_part' and len(parts)>1: parts=parts[:-1]
        if self.reduction=='reverse': parts.reverse()
        hs=parts[0]
        for part in parts[1:]:
            for g in range(len(hs)):
                for t in range(len(hs[g])):
                    hs[g][t]+=part[g][t]; self.work['add']+=1
        for g in selected:
            coeff=hs[g]
            if self.mutation=='reverse_coefficients': coeff=list(reversed(coeff))
            c=Coeff(coeff); d=descriptors[g][5]; recover=descriptors[g][6]
            hs[g]=[c.evaluate(t,self.work) if t!=1 or not recover or self.debug else F() for t in range(d+1)]
        all_groups=[]
        for g,rg in enumerate(descriptors):
            factors,left,right,trailing,length,d,recover,terms=rg
            if recover:
                recovered=(self.claims[g]-factors[0]*hs[g][0])/factors[1]
                if self.debug: assert recovered==hs[g][1], 'computed/recovered sample1'
                hs[g][1]=recovered
            all_groups.append([factors[t]*(hs[g][t] if t<=d else lagrange(hs[g],F(t))) for t in range(self.degree+1)])
        self.pending=all_groups
        return [sum((a[t] for a in all_groups),F()) for t in range(self.degree+1)]
