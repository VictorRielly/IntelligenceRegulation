"""Local tagged storage prototype for the native SumcheckRounds seam.

Eq descriptors retain original indices. Pub/Priv tables keep ordinary MSB folds.
No transcript, RNG, masks, witness caching, extension or commitment code.
"""
from field_support import F, eq, bits, fold, lagrange

def eq_table(w):
    out=[F(1)]
    for a in w: out=[z*b for z in out for b in (1-a,a)]
    return out

def private_table(tab,n):
    coords=tab['coords']; log=len(coords); used=0
    moving=[k for role,k in coords if role!='Fixed']
    if len(moving)!=len(set(moving)): raise ValueError('duplicate moving coordinate')
    if any(k<0 or k>=n for k in moving): raise ValueError('coordinate bounds')
    fixed=[k for role,k in coords if role=='Fixed']; eqf=eq_table(fixed)
    for k in moving: used |= 1<<(n-1-k)
    lo_len=log//2; hi_len=log-lo_len
    def mapping(cs):
        out=[]
        for i in range(1<<len(cs)):
            x=z=0
            for b,(role,k) in zip(bits(i,len(cs)),cs):
                if role=='Fixed': z=(z<<1)|b
                elif role in ('Rho','Flip'): x |= (b if role=='Rho' else 1-b)<<(n-1-k)
                else: raise ValueError('coordinate role')
            out.append((x,z))
        return out
    high=mapping(coords[:hi_len]); low=mapping(coords[hi_len:])
    fixed_low=sum(role=='Fixed' for role,k in coords[hi_len:])
    out=[F() for _ in range(1<<n)]; source=tab['source']; size=1<<log
    if not tab['slices']: raise ValueError('empty slices')
    if any(off<0 or off+size>len(source) for off,c in tab['slices']): raise ValueError('slice bounds')
    for i in range(size):
        xh,zh=high[i>>lo_len]; xl,zl=low[i&((1<<lo_len)-1)]
        x=xh|xl; z=(zh<<fixed_low)|zl
        v=sum((coef*source[off+i] for off,coef in tab['slices']),F())
        out[x] += eqf[z]*v
    for x in range(len(out)):
        if x & ~used: out[x]=out[x&used]
    return out

def bracket(terms,values):
    if hasattr(terms, "evaluate"): return terms.evaluate(values)
    out=F()
    for coef,indices in terms:
        value=coef
        for i in indices: value *= values[i]
        out+=value
    return out

class SteppedRounds:
    def __init__(self,tabs,n,degree,groups,row_plan,chunk=3,debug=False,mutation=None):
        if chunk<1: raise ValueError("nonpositive chunk")
        self.row_plan=row_plan; self.chunk=chunk; self.debug=debug; self.mutation=mutation; self.chunks=0
        if n<0 or not tabs or degree<1: raise ValueError('shape')
        self.n,self.degree,self.groups=n,degree,groups
        self.j=0; self.pending=None; self.claims=[None]*len(groups)
        self.slots=[]; self.data_indices=[]; self.eq_indices=[]
        for i,tab in enumerate(tabs):
            if tab['kind']=='Eq':
                if tab['start']<0 or tab['start']+len(tab['point'])>n: raise ValueError('equality bounds')
                self.slots.append({'point':tuple(tab['point']),'start':tab['start'],'scalar':F(1)})
                self.eq_indices.append(i)
            else:
                words=list(tab['words']) if tab['kind']=='Pub' else private_table(tab,n)
                if len(words)!=1<<n: raise ValueError('table shape')
                self.slots.append(words); self.data_indices.append(i)
        if not groups: raise ValueError('empty groups')
        for i,terms in groups:
            if i not in self.eq_indices: raise ValueError('group Eq role')
            dependencies=[k for c,ix in terms for k in ix]
            if any(k not in self.data_indices for k in dependencies): raise ValueError('bracket must depend on data only')
            d=max((len(ix) for c,ix in terms),default=0)
            if d<1 or d+bool(self.slots[i]['point'])>degree: raise ValueError('degree')
        self.data_fold_ops=0; self.eq_scalar_ops=0; self.recoveries=0; self.zero_fallbacks=0
        self.initial_data_entries=len(self.data_indices)*(1<<n)

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
            d=max(len(ix) for c,ix in terms); hs=[F() for _ in range(d+1)]
            recover=self.claims[g] is not None and factors[1]!=0
            if self.claims[g] is not None:
                if recover: self.recoveries+=1
                else: self.zero_fallbacks+=1
            descriptors.append((factors,left,right,trailing,len(suffix),d,hs,recover,terms))
        # Preserve native's common data scan across groups. Equality slots are
        # absent from loads/differences/interpolation but retain their indices.
        max_degree=max(rg[5] for rg in descriptors)
        for row in self.row_order(half):
            values=[F() for _ in self.slots]; dif=[F() for _ in self.slots]
            for k in self.data_indices:
                values[k]=self.slots[k][row]; dif[k]=self.slots[k][row+half]-values[k]
            self.row_plan.begin(values,dif)
            weights=[]
            for factors,left,right,trailing,length,d,hs,recover,terms in descriptors:
                pos=(row>>trailing)&((1<<length)-1)
                weights.append(left[pos//len(right)]*right[pos%len(right)])
            for t in range(max_degree+1):
                for g,rg in enumerate(descriptors):
                    factors,left,right,trailing,length,d,hs,recover,terms=rg
                    if t<=d and (t!=1 or not recover or self.debug): hs[t]+=weights[g]*bracket(terms,values)
                if t!=max_degree:
                    for k in self.data_indices: values[k]+=dif[k]
                    if self.mutation!="skip_step_one" or t!=0 or not any(rg[7] for rg in descriptors): self.row_plan.advance()
            self.row_plan.end()
        all_groups=[]
        for g,rg in enumerate(descriptors):
            factors,left,right,trailing,length,d,hs,recover,terms=rg
            if recover: hs[1]=(self.claims[g]-factors[0]*hs[0])/factors[1]
            all_groups.append([factors[t]*(hs[t] if t<=d else lagrange(hs,F(t))) for t in range(self.degree+1)])
        self.pending=all_groups
        return [sum((a[t] for a in all_groups),F()) for t in range(self.degree+1)]

    def row_order(self,half):
        for start in range(0,half,self.chunk):
            self.chunks+=1
            stop=min(start+self.chunk,half)
            if self.mutation=="drop_ragged" and stop-start<self.chunk: continue
            yield from range(start,stop)

    def fold(self,r):
        if self.pending is None: raise ValueError('fold needs round')
        self.claims=[lagrange(a,r) for a in self.pending]
        for k in self.data_indices:
            self.data_fold_ops+=len(self.slots[k])//2
            self.slots[k]=fold(self.slots[k],r)
        for k in self.eq_indices:
            desc=self.slots[k]; s=desc['start']; w=desc['point']
            if s<=self.j<s+len(w): desc['scalar']*=eq([w[self.j-s]],[r]); self.eq_scalar_ops+=1
        self.j+=1; self.pending=None

    def finals(self):
        if self.j!=self.n or self.pending is not None: raise ValueError('unfinished finals')
        return [s['scalar'] if isinstance(s,dict) else s[0] for s in self.slots]
