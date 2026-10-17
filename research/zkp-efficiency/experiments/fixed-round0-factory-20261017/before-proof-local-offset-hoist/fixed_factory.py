"""Public constructor dispatch, fixed row body, existing grouped round port."""
from collections import Counter
from cubic_factory import CubicPlan
from coefficients import Coeff
from field_support import F
from generate import build,emit

CACHE = {}


def compile_factory(cfg, active, recycled=True, mutation=None):
    # Cache keys are immutable PUBLIC layout only. Compiled function contains
    # no challenge, witness, mask, opening or private/model values.
    key = (cfg['ls'],cfg['lp'],tuple(cfg['lookups']),active,recycled,mutation)
    if key not in CACHE:
        g,out=build(cfg,active)
        source,stats,schedule=emit(g,out,recycled,mutation)
        scope={'F':F}
        exec(compile(source,'<locally-generated-fixed-factory>','exec'),scope)
        CACHE[key]=(scope['factory'],stats,source,g,out)
    return CACHE[key]


class FixedPlan(CubicPlan):
    def __init__(self,*args,recycled=True,fixed_mutation=None,**kwargs):
        super().__init__(*args,mode='cubic_round0',**kwargs)
        self.recycled=recycled
        self.fixed_mutation=fixed_mutation
        self.fixed_fn,self.fixed_stats,*_=compile_factory(self.cfg,0 in self.dependencies[self.cfg['index']['mask']],recycled,fixed_mutation)
        self.extra['public_constructor_factory_selection']+=1

    def begin(self,values,differences):
        if not self.coefficient_groups:
            return super().begin(values,differences)
        if self.round_index != 0:
            raise ValueError('fixed factory: round0 only')
        assert self.pending is None
        offsets=[x[0] for x in self.plan.plan.entries]
        out=self.fixed_fn(values,differences,self.const,offsets)
        self.pending=[Coeff(out),None,None]
        self.counts.update(self.fixed_stats['field_ops'])
        self.max_coefficient_words=max(self.max_coefficient_words,4)
        self.rows+=1
        self.t=0

