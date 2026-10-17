"""Definition-local row factory for the existing grouped sample interface."""
from collections import Counter
from coefficients import Coeff,LiftedPlan
from polynomial_clause import bracket
from source_port import Terms

class RowPlan:
    def __init__(self,cfg,const,plan,mutation=None,policy='padded_zero'):
        self.cfg,self.const,self.plan,self.mutation=cfg,const,LiftedPlan(plan),mutation
        self.counts=Counter(); self.eval_counts=Counter(); self.rows=0; self.pending=None
        self.max_coefficient_words=0
        assert policy in ('padded_zero','all')
        self.coefficient_groups=set(range(3)) if policy=='all' else ({0} if cfg['padded'] else set())
    def begin(self,values,differences):
        assert self.pending is None
        vv=[Coeff([a,b]) for a,b in zip(values,differences)]
        # polynomial_clause bracket owns the granular coefficient Counter.
        self.pending=[None]*3
        for g in range(3):
            if g in self.coefficient_groups:
                poly,counts=bracket(g,vv,self.cfg,self.const,den_eval=self.plan.evaluate)
                self.pending[g]=poly; self.counts.update(counts)
        if self.mutation=='drop_high':
            self.pending=[Coeff(p.c[:-1]) if p is not None and len(p.c)>1 else p for p in self.pending]
        if self.mutation=='swap_support':
            self.pending[0]=bracket(0,vv,dict(self.cfg,index={**self.cfg['index'],'gs':self.cfg['index']['ght'],'ght':self.cfg['index']['gs']}),self.const,den_eval=self.plan.evaluate)[0]
        self.max_coefficient_words=max(self.max_coefficient_words,sum(len(p.c) for p in self.pending if p is not None))
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
        if self.group not in self.row.coefficient_groups:
            from source_port import bracket as direct
            value,counts=direct(self.group,values,self.cfg,self.const,den_eval=self.row.plan.plan.evaluate)
            self.row.eval_counts.update(counts)
            return value
        return self.row.evaluate(self.group)
