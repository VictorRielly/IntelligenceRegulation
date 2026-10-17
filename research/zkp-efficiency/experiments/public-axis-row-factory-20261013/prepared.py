"""Proof-definition-local affine denominators; no cross-proof challenge cache."""
from collections import Counter
from field_support import F,P
from source_port import V,Terms,bracket


def generalize(cfg):
    return [([(i,c)], F(k)) for i,c,k in cfg['lookups']]


class Plan:
    def __init__(self, lookups, alpha, tag, mutation=None):
        self.preparation=Counter(); self.dispatch=Counter(); self.entries=[]
        for terms,cst in lookups:
            # Native lk_tables has already formed cst+tag before helper_sum.
            shifted=cst+tag
            offset=alpha-shifted
            self.preparation['add']+=1
            self.preparation['sub']+=1
            if mutation=='drop_tag': offset=alpha-cst
            if mutation=='reverse_offset': offset=shifted-alpha
            ops=[]
            for i,c in terms:
                c%=P
                kind='Unit' if c==1 else 'Neg' if c==P-1 else 'Scale'
                if mutation=='neg_is_unit' and kind=='Neg': kind='Unit'
                ops.append((i,kind,c)); self.preparation['tag_classifications']+=1
            self.entries.append((offset,tuple(ops)))

    def evaluate(self,j,values,cc):
        offset,ops=self.entries[j]; out=V(offset,cc)
        for i,kind,c in ops:
            self.dispatch[kind]+=1
            if kind=='Unit': out=out.sub(values[i])
            elif kind=='Neg': out=out.add(values[i])
            else: out=out.sub(values[i].mul_base(c))
        return out


def baseline_den(terms,cst,alpha,tag,values,cc):
    out=V(cst+tag,cc)
    for i,c in terms: out=out.add(values[i].mul_base(c%P))
    return V(alpha,cc).sub(out)


def helper(lookups,values,h0,alpha,tag,mu,plan=None,mutation=None):
    cc=Counter(); v=[V(x,cc) for x in values]; out=V(F(),cc)
    def den(j):
        return plan.evaluate(j,v,cc) if plan else baseline_den(*lookups[j],alpha,tag,v,cc)
    for j in range((len(lookups)+1)//2):
        d1=den(2*j); h=v[h0+j]
        if 2*j+1<len(lookups):
            d2=den(2*j+1); rel=h.mul(d1).mul(d2).sub(d1.add(d2))
        else:
            rel=h.mul(d1).sub(V(F(1),cc))
            if mutation=='drop_odd': rel=V(F(),cc)
        out=out.add(V(mu[j],cc).mul(rel))
    return out.value,cc


class PreparedTerms(Terms):
    def __init__(self,terms,group,cfg,const,plan):
        super().__init__(terms,group,cfg,const); self.plan=plan
    def evaluate(self,values):
        value,cc=bracket(self.group,values,self.cfg,self.const,den_eval=self.plan.evaluate)
        self.counts.update(cc); self.calls+=1
        return value
