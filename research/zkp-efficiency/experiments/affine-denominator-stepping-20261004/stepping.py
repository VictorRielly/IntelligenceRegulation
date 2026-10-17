"""Row-local affine denominator stepping; synthetic, no native/proof execution."""
from collections import Counter
from field_support import F
from source_port import V, Terms, bracket
from prepared import Plan


class RowPlan:
    def __init__(self, plan, mutation=None):
        self.plan=plan; self.mutation=mutation; self.counts=Counter()
        self.current=None; self.delta=None; self.sample=None

    def begin(self, values, differences):
        if self.current is not None: raise ValueError('unfinished row')
        cc=self.counts; vv=[V(x,cc) for x in values]
        dd=[V(x,cc) for x in differences]
        self.current=[]; self.delta=[]; self.sample=0
        for j,(offset,ops) in enumerate(self.plan.entries):
            self.current.append(self.plan.evaluate(j,vv,cc).value)
            # Constant offset contributes zero to the slope, including tag.
            out=V(F(),cc)
            for i,kind,c in ops:
                cc['coefficient_dispatch']+=1
                if kind=='Unit': out=out.sub(dd[i])
                elif kind=='Neg': out=out.add(dd[i])
                else: out=out.sub(dd[i].mul_base(c))
            self.delta.append(-out.value if self.mutation=='reverse_delta' else out.value)
        cc['row_begins']+=1; cc['origin_dispatch']+=sum(len(x[1]) for x in self.plan.entries)

    def advance(self):
        if self.current is None: raise ValueError('step outside row')
        self.current=[a+b for a,b in zip(self.current,self.delta)]
        self.counts['add']+=len(self.current); self.counts['steps']+=1
        self.sample+=1

    def evaluate(self,j,values,cc):
        if self.current is None: raise ValueError('denominator outside row')
        self.counts['scratch_reads']+=1
        return V(self.current[j],cc)

    def end(self):
        if self.current is None: raise ValueError('end outside row')
        self.current=None; self.delta=None; self.sample=None; self.counts['row_ends']+=1


class SteppedTerms(Terms):
    def __init__(self,terms,group,cfg,const,row):
        super().__init__(terms,group,cfg,const); self.row=row
    def evaluate(self,values):
        value,cc=bracket(self.group,values,self.cfg,self.const,
                         den_eval=self.row.evaluate if self.group==0 else None)
        self.counts.update(cc); self.calls+=1
        return value
