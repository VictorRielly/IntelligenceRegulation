"""Definition-local row factory for the existing grouped sample interface."""
from collections import Counter
from coefficients import Coeff,LiftedPlan
from polynomial_clause import bracket
from source_port import Terms

class RowPlan:
    def __init__(self,cfg,const,plan,mutation=None):
        self.cfg,self.const,self.plan,self.mutation=cfg,const,LiftedPlan(plan),mutation
        self.counts=Counter(); self.eval_counts=Counter(); self.rows=0; self.pending=None
        self.max_coefficient_words=0
    def begin(self,values,differences):
        assert self.pending is None
        vv=[Coeff([a,b]) for a,b in zip(values,differences)]
        # polynomial_clause bracket owns the granular coefficient Counter.
        self.pending=[]
        for g in range(3):
            poly,counts=bracket(g,vv,self.cfg,self.const,den_eval=self.plan.evaluate)
            self.pending.append(poly); self.counts.update(counts)
        if self.mutation=='drop_high':
            self.pending=[Coeff(p.c[:-1]) if len(p.c)>1 else p for p in self.pending]
        if self.mutation=='swap_support': self.pending[1],self.pending[2]=self.pending[2],self.pending[1]
        self.max_coefficient_words=max(self.max_coefficient_words,sum(len(p.c) for p in self.pending))
        self.rows+=1; self.t=0
    def advance(self): self.t+=1
    def end(self):
        assert self.pending is not None
        if self.mutation!='stale_row': self.pending=None
    def evaluate(self,g):
        assert self.pending is not None
        t=self.t+(1 if self.mutation=='shift_sample' else 0)
        return self.pending[g].evaluate(t,self.eval_counts)

class CoefficientTerms(Terms):
    def __init__(self,terms,g,cfg,const,row):
        super().__init__(terms,g,cfg,const); self.row=row
    def evaluate(self,values):
        self.calls+=1
        return self.row.evaluate(self.group)
