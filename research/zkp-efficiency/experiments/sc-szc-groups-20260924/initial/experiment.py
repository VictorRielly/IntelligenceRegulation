#!/usr/bin/env python3
"""Synthetic SC_SZC algebra experiment, never a proof/privacy benchmark.

Standard library only. Source-derived polynomial port; no native Rust execution.
Group claims come only from prior computed group rounds, never the host assertion.
"""
import copy
import hashlib
import itertools
import json
import os
from pathlib import Path
import platform
import random
import resource
import signal
import time

P = 2**64 - 2**32 + 1
HERE = Path(__file__).resolve().parent
SEED = 20260924


class F:
    __slots__ = ('a', 'b')
    def __init__(self, a=0, b=0):
        self.a, self.b = a % P, b % P
    def __add__(self, y):
        if not isinstance(y, F): y = F(y)
        return F(self.a+y.a, self.b+y.b)
    __radd__ = __add__
    def __neg__(self): return F(-self.a, -self.b)
    def __sub__(self, y): return self + (-y if isinstance(y, F) else -F(y))
    def __rsub__(self, y): return -self + y
    def __mul__(self, y):
        if not isinstance(y, F): return F(self.a*y, self.b*y)
        return F(self.a*y.a+7*self.b*y.b, self.a*y.b+self.b*y.a)
    __rmul__ = __mul__
    def __truediv__(self, y):
        if not isinstance(y, F): y = F(y)
        d = pow((y.a*y.a-7*y.b*y.b) % P, -1, P)
        return self * F(y.a*d, -y.b*d)
    def __eq__(self, y):
        if not isinstance(y, F): y = F(y)
        return self.a == y.a and self.b == y.b
    def wire(self): return self.a.to_bytes(8, 'little')+self.b.to_bytes(8, 'little')


def prod(xs):
    z = F(1)
    for x in xs: z = z*x
    return z


def eq(w, x): return prod((1-a)*(1-b)+a*b for a, b in zip(w, x))
def bits(i, n): return [(i >> (n-1-j)) & 1 for j in range(n)]
def fold(a, r):
    h = len(a)//2
    return [x+r*(y-x) for x, y in zip(a[:h], a[h:])]


def lagrange(ys, r):
    return sum((y * prod((r-j)/(i-j) for j in range(len(ys)) if i != j)
                for i, y in enumerate(ys)), F())


def mle_direct(a, x):
    # Original-cube definition, independent of reference/candidate folding.
    return sum((v*prod(q if b else 1-q for b, q in zip(bits(i, len(x)), x))
                for i, v in enumerate(a)), F())


def fixture(n, padded, mode, rng, limbs=2, lookup_count=5):
    assert n >= 2
    ht = n-1  # one trailing j coordinate, repeated Ht planes
    def draw():
        if mode == 'zero': return F()
        if mode == 'base': return F(rng.randrange(-32768, 32768))
        return F(rng.randrange(P), rng.randrange(P))
    point = lambda m: [F(rng.randrange(P), rng.randrange(P)) for _ in range(m)]
    names = ['mask', 's8', 'zsel', 'e', 'p', 'rsl', 'mx', 'sum', 'hx']
    names += [f'{s}{k}' for s in ('sr', 'sg', 'pl') for k in range(limbs)]
    names += [f'h{k}' for k in range((lookup_count+1)//2)]
    tabs = {name: [draw() for _ in range(1 << n)] for name in names}
    for name in ('mx', 'sum'):
        tabs[name] = [v for v in [draw() for _ in range(1 << ht)] for _ in range(2)]
    tabs['mask'] = [F((i % 2) <= ((i//2) % 2)) for i in range(1 << n)]
    tabs['ght'] = [F(not padded or i//2 < (1 << ht)-1) for i in range(1 << n)]
    tabs['gs'] = [tabs['ght'][i]*F(not padded or i % 2 == 0) for i in range(1 << n)]
    lookups = []
    lookup_planes = ['s8', 'zsel', 'e', 'p', 'rsl']
    for k in range(lookup_count):
        lookups.append(([(lookup_planes[k % 5], (-1 if k % 2 else 1)),
                         (f'pl{k % limbs}', 256)], point(1)[0]))
    return dict(n=n, ht=ht, padded=padded, tabs=tabs, names=list(tabs),
                points=[point(n), point(ht), point(n)], limbs=limbs,
                lookup=lookups, mu=point(6+(lookup_count+1)//2+int(padded)),
                nu=point(2), alpha=point(1)[0], beta=point(1)[0],
                gexp=point(1)[0], lam=point(1)[0], zeta=point(1)[0],
                # Synthetic layout lists, preserving all three limb groups.
                pad_s=[s for s in names if s not in ('mx', 'sum', 'mask', 'hx') and not s.startswith('h')])


def inner(c, v, g):
    """The actual closure's three brackets, with synthetic layout wiring.

    Helpers use affine lookup values and both paired/odd-tail helper relations.
    Pad powers continue across Ht and S, as PadTerm::add requires.
    """
    if g == 1: return c['nu'][0]*v['ght']*(v['sum']+c['lam'])
    if g == 2: return c['nu'][1]*v['gs']*(64*v['s8']+v['rsl']-32)
    limb = lambda s: sum((256**k*v[f'{s}{k}'] for k in range(c['limbs'])), F())
    delta = v['mx']-v['mask']*(v['s8']+127)+127
    sr = limb('sr')
    clauses = [v['zsel']*v['zsel']-v['zsel'], v['zsel']*delta,
               512*v['mask']*v['e']-v['p']*v['sum']-sr,
               limb('sg')+sr+1-v['sum'], v['p']-limb('pl')]
    den = [c['alpha']-const-sum((coef*v[name] for name, coef in terms), F())
           for terms, const in c['lookup']]
    helpers = F()
    for k in range((len(den)+1)//2):
        d1 = den[2*k]
        rel = (v[f'h{k}']*d1*den[2*k+1]-d1-den[2*k+1]
               if 2*k+1 < len(den) else v[f'h{k}']*d1-1)
        helpers += c['mu'][5+k]*rel
    nh = (len(den)+1)//2
    cx = v['hx']*(c['alpha']-delta-c['beta']*v['e']-c['gexp'])-1
    pad = F()
    if c['padded']:
        power = F(1)
        for gate, names in [('ght', ['mx', 'sum']), ('gs', c['pad_s'])]:
            total = F()
            for name in names:
                total += power*v[name]
                power *= c['zeta']
            pad += (1-v[gate])*total
        pad *= c['mu'][6+nh]
    return helpers+c['mu'][5+nh]*cx+pad+v['gs']*sum((m*a for m, a in zip(c['mu'], clauses)), F())


def full(c, v, es): return sum((es[g]*inner(c, v, g) for g in range(3)), F())


class Reference:
    def __init__(self, c):
        self.c, self.j, self.claim = c, 0, None
        self.tabs = copy.deepcopy(c['tabs'])
        self.eq_tabs = [[eq(w, bits(i, c['n'])[:len(w)]) for i in range(1 << c['n'])]
                        for w in c['points']]
        self.degree = 5 if c['padded'] else 4
        self.counts = [0]*3
    def round(self):
        half = len(self.eq_tabs[0])//2
        out = []
        for t in range(self.degree+1):
            if t == 1 and self.claim is not None:
                out.append(self.claim-out[0]); continue
            value = F()
            for i in range(half):
                v = {name: a[i]+t*(a[i+half]-a[i]) for name, a in self.tabs.items()}
                es = [a[i]+t*(a[i+half]-a[i]) for a in self.eq_tabs]
                value += full(self.c, v, es)
                self.counts = [x+1 for x in self.counts]
            out.append(value)
        self.pending = out
        return out
    def bind(self, r):
        self.claim = lagrange(self.pending, r)
        self.tabs = {k: fold(v, r) for k, v in self.tabs.items()}
        self.eq_tabs = [fold(v, r) for v in self.eq_tabs]
        self.j += 1
    def finals(self): return [v[0] for v in self.eq_tabs]+[self.tabs[k][0] for k in self.c['names']]


class Grouped:
    def __init__(self, c, recover=True, bad_claim=False):
        self.c, self.j, self.recover, self.bad_claim = c, 0, recover, bad_claim
        self.tabs = copy.deepcopy(c['tabs'])
        self.degree = 5 if c['padded'] else 4
        self.prefix = [F(1)]*3
        self.claims = [None]*3
        self.counts = [0]*3
        self.fallbacks = self.eq_peak = 0
    def round(self):
        groups = []
        half = len(next(iter(self.tabs.values())))//2
        for g, w in enumerate(self.c['points']):
            d = (4 if self.c['padded'] else 3) if g == 0 else (2 if self.c['padded'] else 1)
            active = self.j < len(w)
            e = [self.prefix[g]*eq(w[self.j:self.j+1], [F(t)]) if active else self.prefix[g]
                 for t in range(self.degree+1)]
            suffix = w[self.j+1:]
            split = len(suffix)//2
            left = [eq(suffix[:split], bits(i, split)) for i in range(1 << split)]
            right = [eq(suffix[split:], bits(i, len(suffix)-split)) for i in range(1 << (len(suffix)-split))]
            self.eq_peak = max(self.eq_peak, len(left)+len(right))
            claim = self.claims[g]
            if self.bad_claim and claim is not None: claim = sum(self.claims, F())
            recover = self.recover and claim is not None and e[1] != 0
            if self.recover and claim is not None and e[1] == 0: self.fallbacks += 1
            hs = [F()]*(d+1)
            trailing = self.c['n']-self.j-1-len(suffix)
            for t in range(d+1):
                if t == 1 and recover: continue
                for i in range(half):
                    pos = i >> trailing
                    weight = left[pos//len(right)]*right[pos % len(right)]
                    v = {name: a[i]+t*(a[i+half]-a[i]) for name, a in self.tabs.items()}
                    hs[t] += weight*inner(self.c, v, g)
                    self.counts[g] += 1
            if recover: hs[1] = (claim-e[0]*hs[0])/e[1]
            groups.append([e[t]*(hs[t] if t <= d else lagrange(hs, F(t)))
                           for t in range(self.degree+1)])
        self.pending = groups
        return [sum((v[t] for v in groups), F()) for t in range(self.degree+1)]
    def bind(self, r):
        self.claims = [lagrange(v, r) for v in self.pending]
        for g, w in enumerate(self.c['points']):
            if self.j < len(w): self.prefix[g] *= eq(w[self.j:self.j+1], [r])
        self.tabs = {k: fold(v, r) for k, v in self.tabs.items()}
        self.j += 1
    def finals(self): return self.prefix+[self.tabs[k][0] for k in self.c['names']]


def oracle(c, prefix, t):
    out = F()
    for tail in itertools.product((0, 1), repeat=c['n']-len(prefix)-1):
        x = prefix+[F(t)]+[F(b) for b in tail]
        v = {k: mle_direct(a, x) for k, a in c['tabs'].items()}
        out += full(c, v, [eq(w, x[:len(w)]) for w in c['points']])
    return out


def run_case(c, direct=False, forced=None):
    ref, fast, noskip = Reference(c), Grouped(c), Grouped(c, recover=False)
    transcript, prefix, checked = b'sc-szc-toy-v1', [], 0
    for j in range(c['n']):
        a, b, z = ref.round(), fast.round(), noskip.round()
        assert a == b == z, ('round', j)
        if direct:
            for t, value in enumerate(a):
                assert value == oracle(c, prefix, t), ('direct', j, t)
                checked += 1
        # Same deterministic synthetic wrapper; no CFS/RNG/privacy claim.
        transcript += b''.join((v+F(11+j, 17+j)*(2*t-1)).wire() for t, v in enumerate(a))
        digest = hashlib.sha256(transcript).digest()
        r = (forced[j] if forced and j < len(forced) else
             F(int.from_bytes(digest[:16], 'little'), int.from_bytes(digest[16:], 'little')))
        prefix.append(r)
        for obj in (ref, fast, noskip): obj.bind(r)
    assert ref.finals() == fast.finals() == noskip.finals()
    assert ref.finals() == [eq(w, prefix[:len(w)]) for w in c['points']]+[mle_direct(c['tabs'][k], prefix) for k in c['names']]
    return dict(n=c['n'], padded=c['padded'], tables=len(c['tabs']), direct_points=checked,
                reference_group_evaluations=ref.counts, grouped_evaluations=fast.counts,
                grouped_without_claim_recovery=noskip.counts, zero_factor_fallbacks=fast.fallbacks,
                peak_group_split_eq_entries=fast.eq_peak, digest=hashlib.sha256(transcript).hexdigest())


def validate(c):
    if any(len(a) != 1 << c['n'] for a in c['tabs'].values()): raise ValueError('table length')
    if [len(w) for w in c['points']] != [c['n'], c['ht'], c['n']]: raise ValueError('point support')
    if c['ht'] >= c['n']: raise ValueError('Ht must have trailing broadcast coordinates')


def main():
    resource.setrlimit(resource.RLIMIT_AS, (512*1024*1024, 512*1024*1024))
    resource.setrlimit(resource.RLIMIT_CPU, (55, 55))
    signal.alarm(59)
    if hasattr(os, 'sched_getaffinity'):
        os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    start = time.perf_counter()
    rng = random.Random(SEED)
    rows = []
    for n, padded, mode in itertools.product((2, 3, 5), (False, True), ('base', 'extension', 'zero')):
        c = fixture(n, padded, mode, rng, limbs=3 if n == 5 else 2, lookup_count=4 if n == 3 else 5)
        validate(c)
        rows.append(run_case(c, direct=n <= 3))
    c = fixture(4, True, 'extension', rng)
    c['points'][0][0] = F(1)
    c['points'][1][1] = F(0)
    rows.append(run_case(c, direct=True, forced=[F(0)]))
    # Negative controls deliberately reproduce known-invalid shortcuts.
    controls = {}
    c = fixture(3, True, 'extension', rng)
    ref, bad = Reference(c), Grouped(c, bad_claim=True)
    assert ref.round() == bad.round()
    ref.bind(F(3, 9)); bad.bind(F(3, 9))
    controls['combined_claim_is_not_subgroup_claim'] = ref.round() != bad.round()
    v = {k: a[0] for k, a in c['tabs'].items()}
    v['ght'], v['gs'] = F(1), F(0)
    before = inner(c, v, 1)
    v['ght'] = v['gs']
    controls['score_gate_cannot_replace_lifted_ht_gate'] = before != inner(c, v, 1)
    good = Reference(c).round()
    mutated = copy.deepcopy(c)
    mutated['points'][1] += [F(5, 7)]
    controls['pht_is_not_full_coordinate_equality'] = good != Reference(mutated).round()
    changed = copy.deepcopy(c)
    changed['tabs']['sg1'][3] += F(1)
    controls['changed_limb_changes_round'] = good != Reference(changed).round()
    controls['wrong_single_equality_factor_detected'] = any(
        full(c, {k: a[i] for k, a in c['tabs'].items()},
             [eq(w, bits(i, c['n'])[:len(w)]) for w in c['points']]) !=
        eq(c['points'][0], bits(i, c['n']))*sum((inner(c, {k: a[i] for k, a in c['tabs'].items()}, g) for g in range(3)), F())
        for i in range(1 << c['n']))
    refusals = 0
    for kind in ('table', 'point'):
        badc = copy.deepcopy(c)
        if kind == 'table': badc['tabs']['s8'].pop()
        else: badc['points'][1].pop()
        try: validate(badc)
        except ValueError: refusals += 1
    assert all(controls.values()) and refusals == 2
    # Bounded cost counts on 256 synthetic score-cube rows, not native timings.
    counts = [run_case(fixture(8, p, 'extension', rng, limbs=3, lookup_count=5)) for p in (False, True)]
    pins = {}
    for name in ('hashline/src/private_block/argument.rs', 'hashline/src/private_block/slot_ir.rs',
                 'zkp-core/src/sumcheck/rounds.rs', 'zkp-core/src/field.rs', 'private-block-kernel/src/lib.rs'):
        f = Path('/tmp/zk60-rounds-20260922')/name
        pins[str(f)] = hashlib.sha256(f.read_bytes()).hexdigest() if f.exists() else None
    cpu = next((x.split(':', 1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')), 'unknown')
    result = dict(schema='zkp-efficiency/sc-szc-groups/v1', status='passed', seed=SEED,
                  run_identity='20260924T024433Z-0c043a75', source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  source_pins=pins, python=platform.python_version(), cpu=cpu, platform=platform.platform(),
                  threads=1, cpu_affinity=sorted(os.sched_getaffinity(0)), max_address_space_mib=512,
                  max_wall_seconds=59, max_cpu_seconds=55, estimated_memory_mib=32,
                  field='Goldilocks Fp2, u^2=7', cases=rows, counted_cases=counts,
                  differential_cases=len(rows)+len(counts), direct_round_points=sum(r['direct_points'] for r in rows),
                  negative_controls=controls, malformed_refusals=refusals,
                  elapsed_seconds=time.perf_counter()-start,
                  peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                  scope='Source-derived SC_SZC polynomial with synthetic lookup/plane maps; independent original-cube MLE oracle. No native closure/IR execution, CFS/RNG parity, honest model witness, receipt, GPU, privacy or model-speed result.')
    (HERE/'result.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({k: result[k] for k in ('status', 'differential_cases', 'direct_round_points', 'negative_controls', 'malformed_refusals', 'elapsed_seconds', 'peak_rss_kib')}))


if __name__ == '__main__': main()
