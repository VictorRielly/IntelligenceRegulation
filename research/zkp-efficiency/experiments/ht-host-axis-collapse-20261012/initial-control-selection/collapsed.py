"""SC_SZC-only trailing-axis collapse. Research arithmetic, no proof execution.

Only the Ht host bracket is specialized. All tables and other groups remain.
Provenance must come from immutable native Tab/shape constructors, not values
or a witness assertion. Unsupported public mapping falls back to Grouped.
"""
from dataclasses import dataclass
from field import F
from grouped import Grouped, eq_table
from driver import interpolate

@dataclass(frozen=True)
class HostPlan:
    leading: int
    sum_index: int
    gate_index: int
    nu: F
    lam: F

def admit_plan(n, groups, names, leading, coords, support_domain, eq_start,
               sum_name, nu, lam):
    # These are public/source-description checks, never private-value scans.
    if (type(leading) is not int or not 0 <= leading <= n or
        coords != tuple(('Rho', i) for i in range(leading)) or
        support_domain != 'Ht' or eq_start != 0 or len(groups) != 3 or
        groups[1].start != 0 or len(groups[1].point) != leading or
        sum_name != 'sum' or 'sum' not in names or 'ght' not in names):
        return None
    return HostPlan(leading,names.index('sum'),names.index('ght'),nu,lam)

class Collapsed(Grouped):
    def __init__(self,*args,host=None,**kwargs):
        super().__init__(*args,**kwargs)
        self.host=host

    def round(self,j):
        if self.host is None:
            self.counts['fallback_rounds'] += 1
            return super().round(j)
        n=self.tables.n
        if j != self.tables.bound or j >= n or self.pending is not None:
            raise ValueError('grouped round schedule')
        plans=[]
        for g,desc in enumerate(self.groups):
            end=desc.start+len(desc.point);active=desc.start <= j < end
            factor=[self.prefix[g]*((1-desc.point[j-desc.start])+
                    (2*desc.point[j-desc.start]-1)*x) if active else self.prefix[g]
                    for x in range(self.degree+1)]
            consumed=min(max(j+1-desc.start,0),len(desc.point))
            suffix=desc.point[consumed:];split=len(suffix)//2
            left,right=eq_table(suffix[:split]),eq_table(suffix[split:])
            inv=F(1)/factor[1] if self.claims[g] is not None and factor[1]!=0 else None
            if self.claims[g] is not None and inv is None:
                self.counts['zero_factor_explicit_fallbacks']+=1
            self.counts['split_eq_entries_built']+=len(left)+len(right)
            plans.append((factor,left,right,len(suffix),n-end if suffix else 0,inv))
        half=1 << (n-j-1)
        hs=[[F() for _ in range(g.bracket_degree+1)] for g in self.groups]
        top=max(g.bracket_degree for g in self.groups)
        # Original dense scan still needed for g0/g2. No read/fold saving claimed.
        for lo in range(0,half,self.chunk):
            parts=[[F() for _ in row] for row in hs]
            for i in range(lo,min(half,lo+self.chunk)):
                cur,hi=self.tables.row(i),self.tables.row(i+half)
                self.counts['table_endpoint_reads']+=2*len(cur)
                diff=[b-a for a,b in zip(cur,hi)]
                weights={}
                for g in (0,2):
                    _,left,right,ns,trailing,_=plans[g]
                    pos=(i >> trailing)&((1 << ns)-1)
                    weights[g]=left[pos//len(right)]*right[pos%len(right)]
                    self.counts['weight_multiplications_'+str(g)]+=1
                for x in range(top+1):
                    for g in (0,2):
                        if x <= self.groups[g].bracket_degree and (x!=1 or plans[g][-1] is None or self.debug):
                            parts[g][x]+=weights[g]*self.bracket(g,cur)
                            self.counts['bracket_calls_'+str(g)]+=1
                    if x!=top:cur=[a+d for a,d in zip(cur,diff)]
            hs=[[a+b for a,b in zip(row,part)] for row,part in zip(hs,parts)]
        # Ht is constant in every trailing j coordinate, including off-cube
        # challenges, because sum and supp_Ht are multilinear leading lifts.
        plan=self.host; l=plan.leading
        st=self.tables.entries[plan.sum_index][2]
        gt=self.tables.entries[plan.gate_index][2]
        factor,left,right,ns,trailing,inv=plans[1]
        if j < l:
            rep=1 << (n-l); compact_half=1 << (l-j-1)
            for u in range(compact_half):
                i=u*rep; pos=(i >> trailing)&((1 << ns)-1)
                weight=left[pos//len(right)]*right[pos%len(right)]
                self.counts['weight_multiplications_1']+=1
                s0,s1=st.at(i),st.at(i+half)
                g0,g1=gt.at(i),gt.at(i+half)
                self.counts['extra_host_endpoint_reads']+=4
                for x in range(len(hs[1])):
                    if x!=1 or inv is None or self.debug:
                        value=plan.nu*(g0+F(x)*(g1-g0))*(s0+F(x)*(s1-s0)+plan.lam)
                        hs[1][x]+=weight*value
                        self.counts['bracket_calls_1']+=1
            hs[1]=[a*rep for a in hs[1]]
            self.counts['multiplicity_scalings']+=len(hs[1])
        else:
            value=plan.nu*gt.at(0)*(st.at(0)+plan.lam)
            self.counts['extra_host_endpoint_reads']+=2
            self.counts['bracket_calls_1']+=1
            hs[1]=[value*half for _ in hs[1]]
            self.counts['multiplicity_scalings']+=len(hs[1])
        pending=[];result=[F() for _ in range(self.degree+1)]
        for g,(factor,left,right,ns,trailing,inv) in enumerate(plans):
            if inv is not None:
                recovered=(self.claims[g]-factor[0]*hs[g][0])*inv
                if self.debug and recovered!=hs[g][1]:
                    raise ValueError('actual group running claim mismatch')
                hs[g][1]=recovered;self.counts['group_recoveries']+=1
            values=[factor[x]*(hs[g][x] if x<len(hs[g]) else interpolate(hs[g],F(x)))
                    for x in range(self.degree+1)]
            pending.append(values);result=[a+b for a,b in zip(result,values)]
        self.pending=pending
        return result
