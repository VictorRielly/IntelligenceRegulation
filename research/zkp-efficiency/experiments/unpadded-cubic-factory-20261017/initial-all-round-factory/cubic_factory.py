"""Public-only unpadded cubic factory; no protocol, mask or challenge changes."""
from axis_factory import AxisPlan, AxisRounds
from collections import Counter
from coefficients import Coeff
from polynomial_clause import bracket
import coefficients

class CubicPlan(AxisPlan):
    def __init__(self,*args,mode='cubic_schoolbook',mutation=None,**kwargs):
        super().__init__(*args,**kwargs)
        if self.cfg['padded'] or any(self.cfg['supports']):
            raise ValueError('unpadded factory requires no supports')
        if mode not in ('literal','prepared_scalar','cubic_schoolbook','cubic_karatsuba'):
            raise ValueError('factory mode')
        self.mode=mode; self.control=mutation; self.extra=Counter()
        self.coefficient_groups={0} if mode.startswith('cubic') else set()
    def begin(self,values,differences):
        prior=coefficients.ALGORITHM
        coefficients.ALGORITHM='karatsuba' if self.mode=='cubic_karatsuba' else 'schoolbook'
        coefficients.K_WORK.clear()
        try:super().begin(values,differences)
        finally:
            self.extra.update(coefficients.K_WORK); coefficients.ALGORITHM=prior
        if self.pending[0] is not None and self.control=='drop_cubic':
            self.pending[0]=Coeff(self.pending[0].c[:3]+(type(values[0])(),))
        if self.pending[0] is not None and self.control=='reverse_coefficients':
            self.pending[0]=Coeff(reversed(self.pending[0].c))
    def evaluate_scalar(self,g,values):
        from source_port import bracket
        den=self.plan.plan.evaluate if self.mode!='literal' else None
        value,counts=bracket(g,values,self.cfg,self.const,den_eval=den)
        self.eval_counts.update(counts)
        return value

class CubicTerms(list):
    def __init__(self,terms,g,cfg,const,row):
        from source_port import Terms
        super().__init__(Terms(terms,g,cfg,const)); self.row=row; self.group=g
    def evaluate(self,values):return self.row.evaluate_scalar(self.group,values)

class CubicRounds(AxisRounds):
    def __init__(self,*args,min_rows=2,**kwargs):
        super().__init__(*args,policy='always',**kwargs); self.min_rows=min_rows
    def round(self,j):
        half=1<<(self.n-j-1)
        self.row_plan.coefficient_groups={0} if self.row_plan.mode.startswith('cubic') and half>=self.min_rows else set()
        self.row_plan.extra['public_round_policy_tests']+=1
        return super().round(j)
