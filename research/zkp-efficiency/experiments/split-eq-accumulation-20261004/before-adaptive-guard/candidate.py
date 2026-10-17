"""Exact two-layer equality accumulation with a common MSB data scan.

Prover-local synthetic prototype, no transcript/RNG/PCS or native proof execution.
Each contiguous chunk owns one bracket-degree accumulator per group. Flushing
on the group's outer-index change preserves delayed/short/broadcast Eq spans.
"""
from baseline import TaggedRounds, eq_table, bracket
from field_support import F, lagrange


class SplitRounds(TaggedRounds):
    def __init__(self, tabs, n, degree, groups, chunk=1024, mutation=None):
        super().__init__(tabs, n, degree, groups)
        if chunk < 1: raise ValueError('chunk must be positive')
        self.chunk = chunk
        self.mutation = mutation  # Deliberately broken variants for controls.
        self.counts = []

    def round(self, j):
        if j != self.j or j >= self.n or self.pending is not None:
            raise ValueError('round order')
        half = 1 << (self.n-j-1)
        ds = []
        counts = dict(rows=0, data_loads=0, bracket_calls=0,
                      baseline_literal_weight_mul=0, baseline_unit_aware_weight_mul=0,
                      candidate_weight_mul=0, baseline_weight_add=0,
                      candidate_weight_add=0, flushes=0,
                      scratch_field_elements=0, group_records=[])
        for g, (index, terms) in enumerate(self.groups):
            desc = self.slots[index]
            w, start, scalar = desc['point'], desc['start'], desc['scalar']
            active = start <= j < start+len(w)
            factors = [scalar*((1-w[j-start])+(2*w[j-start]-1)*t)
                       if active else scalar for t in range(self.degree+1)]
            consumed = min(max(j+1-start, 0), len(w))
            suffix = w[consumed:]
            split = len(suffix)//2
            left, right = eq_table(suffix[:split]), eq_table(suffix[split:])
            trailing = self.n-start-len(w) if suffix else 0
            if self.mutation == 'omit_trailing': trailing = 0
            d = max(len(ix) for coef, ix in terms)
            recover = self.claims[g] is not None and factors[1] != 0
            if self.claims[g] is not None:
                if recover: self.recoveries += 1
                else: self.zero_fallbacks += 1
            samples = [t for t in range(d+1) if t != 1 or not recover]
            rec = dict(suffix=len(suffix), trailing=trailing, left=len(left),
                       right=len(right), samples=len(samples), flushes=0,
                       candidate_weight_mul=0)
            counts['group_records'].append(rec)
            counts['baseline_literal_weight_mul'] += half*(1+len(samples))
            counts['baseline_unit_aware_weight_mul'] += half*(int(len(left)>1 and len(right)>1)
                                                            +len(samples)*int(bool(suffix)))
            counts['baseline_weight_add'] += half*len(samples)
            ds.append(dict(factors=factors, left=left, right=right, trailing=trailing,
                           length=len(suffix), d=d, sums=[F() for _ in range(d+1)],
                           recover=recover, samples=samples, terms=terms, rec=rec))
        max_degree = max(rg['d'] for rg in ds)
        # Additional live scratch compared with ordinary subgroup sum vectors.
        counts['scratch_field_elements'] = sum(rg['d']+1 for rg in ds)

        def flush(rg, outer, acc):
            if outer is None: return
            for t in rg['samples']:
                v = acc[t]
                if len(rg['left']) > 1:
                    idx = (outer+1) % len(rg['left']) if self.mutation == 'wrong_outer' else outer
                    v = rg['left'][idx]*v
                    counts['candidate_weight_mul'] += 1
                    rg['rec']['candidate_weight_mul'] += 1
                rg['sums'][t] += v
                counts['candidate_weight_add'] += 1
            counts['flushes'] += 1
            rg['rec']['flushes'] += 1

        for lo in range(0, half, self.chunk):
            hi = min(lo+self.chunk, half)
            accs = [[F() for _ in range(rg['d']+1)] for rg in ds]
            outers = [None]*len(ds)
            for row in range(lo, hi):
                counts['rows'] += 1
                values = [F() for _ in self.slots]
                dif = [F() for _ in self.slots]
                for k in self.data_indices:
                    values[k] = self.slots[k][row]
                    dif[k] = self.slots[k][row+half]-values[k]
                    counts['data_loads'] += 2
                inners = []
                for g, rg in enumerate(ds):
                    pos = (row >> rg['trailing']) & ((1 << rg['length'])-1)
                    outer, inner = divmod(pos, len(rg['right']))
                    if outers[g] is not None and outers[g] != outer:
                        flush(rg, outers[g], accs[g])
                        accs[g] = [F() for _ in range(rg['d']+1)]
                    outers[g] = outer
                    inners.append(inner)
                for t in range(max_degree+1):
                    for g, rg in enumerate(ds):
                        if t in rg['samples']:
                            v = bracket(rg['terms'], values)
                            counts['bracket_calls'] += 1
                            if len(rg['right']) > 1:
                                v = rg['right'][inners[g]]*v
                                counts['candidate_weight_mul'] += 1
                                rg['rec']['candidate_weight_mul'] += 1
                            accs[g][t] += v
                            counts['candidate_weight_add'] += 1
                    if t != max_degree:
                        for k in self.data_indices: values[k] += dif[k]
            if self.mutation != 'omit_chunk_flush':
                for g, rg in enumerate(ds): flush(rg, outers[g], accs[g])
        all_groups = []
        for g, rg in enumerate(ds):
            f, hs, d = rg['factors'], rg['sums'], rg['d']
            if rg['recover']: hs[1] = (self.claims[g]-f[0]*hs[0])/f[1]
            all_groups.append([f[t]*(hs[t] if t <= d else lagrange(hs, F(t)))
                               for t in range(self.degree+1)])
        self.pending = all_groups
        self.counts.append(counts)
        return [sum((a[t] for a in all_groups), F()) for t in range(self.degree+1)]


def analytic_counts(n, j, start, length, samples, chunk):
    """Allocation-free equality-only cost; excludes bracket/fold/setup work."""
    half = 1 << (n-j-1)
    consumed = min(max(j+1-start, 0), length)
    suffix = length-consumed
    left, right = 1 << (suffix//2), 1 << (suffix-suffix//2)
    trailing = n-start-length if suffix else 0
    block = right << trailing
    flushes = 0
    for lo in range(0, half, chunk):
        hi = min(lo+chunk, half)
        flushes += 1+(hi-1)//block-lo//block if left > 1 else 1
    return dict(flushes=flushes,
                literal_mul=half*(1+samples),
                unit_aware_mul=half*(int(left>1 and right>1)+samples*int(bool(suffix))),
                candidate_mul=half*samples*int(right>1)+flushes*samples*int(left>1),
                baseline_add=half*samples, candidate_add=(half+flushes)*samples,
                scratch_elements=samples)
