"""Factory specialization selected by immutable PUBLIC coordinate metadata.

The declared five-word output and original evaluation coordinates stay fixed.
No private value, coefficient, degree, or zero slope is inspected for dispatch.
"""
from collections import Counter
from candidate import RowPlan
from coefficients import Coeff
from polynomial_clause import bracket
from weighted_rounds import WeightedRounds


class AxisPlan(RowPlan):
    def __init__(self, cfg, const, plan, dependencies, mutation=None):
        super().__init__(cfg, const, plan)
        allowed = {cfg['index'][name] for name in ('mask', 'gs', 'ght') if name in cfg['index']}
        if set(dependencies) != allowed:
            raise ValueError('public-role metadata only')
        self.dependencies = {k: frozenset(v) for k,v in dependencies.items()}
        self.round_index = None
        self.axis_work = Counter()
        self.axis_mutation = mutation

    def begin(self, values, differences):
        assert self.pending is None and self.round_index is not None
        # All other carriers keep two coefficients, even if their values or
        # differences vanish. Three public tests are charged separately.
        vv = [Coeff([a,b]) for a,b in zip(values,differences)]
        for k, axes in self.dependencies.items():
            self.axis_work['public_axis_tests'] += 1
            independent = self.round_index not in axes
            if self.axis_mutation == 'force_mask_constant' and k == self.cfg['index']['mask']:
                independent = True
            if independent:
                vv[k] = Coeff([values[k]])
                self.axis_work['removed_public_slope_carriers'] += 1
        self.pending = [None]*3
        for g in self.coefficient_groups:
            poly, counts = bracket(g, vv, self.cfg, self.const, den_eval=self.plan.evaluate)
            width = (5,3,3)[g] if self.cfg['padded'] else (4,2,2)[g]
            assert len(poly.c) <= width
            self.axis_work['zero_output_assignments'] += width-len(poly.c)
            self.pending[g] = Coeff(list(poly.c)+[type(values[0])()]*(width-len(poly.c)))
            self.counts.update(counts)
        self.max_coefficient_words = max(self.max_coefficient_words,
            sum(len(p.c) for p in self.pending if p is not None))
        self.rows += 1
        self.t = 0


class AxisRounds(WeightedRounds):
    def round(self,j):
        self.row_plan.round_index = j
        return super().round(j)


def measured_dependencies(words,n):
    """TEST ONLY: independent exhaustive public-table dependency reference."""
    return frozenset(j for j in range(n)
        if any(words[x] != words[x ^ (1 << (n-1-j))] for x in range(1<<n)))


def prefix_bits(limit,pad):
    """Public BitForm conservative fallback; flat-index bits are LSB first."""
    assert pad > 0 and pad & (pad-1) == 0 and 0 < limit <= pad
    log = pad.bit_length()-1
    if limit == pad: return set()
    if limit & (limit-1) == 0: return set(range(limit.bit_length()-1,log))
    tail=pad-limit
    if tail & (tail-1) == 0: return set(range(tail.bit_length()-1,log))
    return set(range(log))


def shape_dependencies(cfg, hp, kv, qh, tp, tokens):
    """Public h,t,j axis mapping from the inspected native constructors."""
    assert hp & (hp-1)==0 and tp & (tp-1)==0 and hp%kv==0 and qh%kv==0
    hlog,tlog=hp.bit_length()-1,tp.bit_length()-1
    n=hlog+2*tlog
    hbits={2*tlog+b for b in prefix_bits(qh//kv,hp//kv)}
    tbits={tlog+b for b in prefix_bits(tokens,tp)}
    jbits=prefix_bits(tokens,tp)
    msb=lambda bs: frozenset(n-1-b for b in bs)
    deps={'mask': frozenset(range(hlog,n)), 'gs': msb(hbits|tbits|jbits), 'ght': msb(hbits|tbits)}
    # At tp=1 mask has no moving coordinate. Conservative dependencies may
    # contain genuinely inactive axes, which sacrifices savings only.
    return {cfg['index'][name]:axes for name,axes in deps.items() if name in cfg['index']}
