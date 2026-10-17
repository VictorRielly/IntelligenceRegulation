"""Locally authored public-shape SC_SZC compiler. No foreign code used.

Every width, index and operation is fixed during generation. No CSE, constant
folding or witness-dependent pruning. This is an uncompiled Rust handoff plus
an executable Python arithmetic model, not a native protocol implementation.
"""
from collections import Counter
import json
from pathlib import Path


class Graph:
    def __init__(self):
        self.nodes = []
        self.counts = Counter()

    def op(self, kind, a, b):
        name = 'v' + str(len(self.nodes))
        self.nodes.append((kind, a, b))
        self.counts[kind] += 1
        return name

    def literal(self, x):
        return (f'F({x})',)

    def combine(self, a, b, kind):
        return tuple(self.op(kind, a[i] if i < len(a) else 'F()',
                             b[i] if i < len(b) else 'F()')
                     for i in range(max(len(a), len(b))))

    def add(self, a, b): return self.combine(a, b, 'add')
    def sub(self, a, b): return self.combine(a, b, 'sub')

    def mul(self, a, b):
        if len(a) == len(b) == 2:
            p0 = self.op('mul', a[0], b[0])
            p2 = self.op('mul', a[1], b[1])
            sa = self.op('add', a[0], a[1])
            sb = self.op('add', b[0], b[1])
            pm = self.op('mul', sa, sb)
            pm = self.op('sub', self.op('sub', pm, p0), p2)
            return p0, pm, p2
        out = [None] * (len(a) + len(b) - 1)
        for i, x in enumerate(a):
            for j, y in enumerate(b):
                z = self.op('mul', x, y)
                out[i+j] = z if out[i+j] is None else self.op('add', out[i+j], z)
        return tuple(out)

    def scale(self, a, x):
        return tuple(self.op('mul_base', z, str(x)) for z in a)


def build_original(cfg, mask_active):
    if cfg['padded'] or any(cfg['supports']):
        raise ValueError('fixed factory: unpadded only')
    g = Graph()
    at = {name: (f'values[{i}]', f'differences[{i}]')
          for name, i in cfg['index'].items()}
    if not mask_active:
        at['mask'] = at['mask'][:1]
    k = g.literal
    c = lambda n: (f'const[{n!r}]',)
    def lb(prefix, count):
        out = at[prefix+'0'] if count else k(0)
        for i in range(1, count):
            out = g.add(out, g.scale(at[prefix+str(i)], 256**i))
        return out
    sr, sg, pl = lb('sr', cfg['ls']), lb('sg', cfg['ls']), lb('pl', cfg['lp'])
    mask, s8, z, e, p, total = (at[x] for x in ('mask','s8','zsel','e','p','sum'))
    delta = g.add(g.sub(at['mx'], g.mul(mask, g.add(s8, k(127)))), k(127))
    clauses = [g.sub(g.mul(z,z),z), g.mul(z,delta),
               g.sub(g.sub(g.scale(g.mul(mask,e),512),g.mul(p,total)),sr),
               g.sub(g.add(g.add(sg,sr),k(1)),total), g.sub(p,pl)]
    cx = g.sub(g.mul(at['hx'],g.sub(c('alpha'),g.add(g.add(delta,g.mul(c('beta'),e)),c('gexp')))),k(1))
    mixed = k(0)
    for j, clause in enumerate(clauses):
        mixed = g.add(mixed, g.mul(c('mu'+str(j)),clause))
    def den(j):
        i, coef, cst = cfg['lookups'][j]
        value = at[cfg['names'][i]]
        off = (f'offsets[{j}]',)
        if coef == 1: return g.sub(off,value)
        if coef == -1: return g.add(off,value)
        return g.sub(off,g.scale(value,coef))
    helper = k(0)
    for j in range(cfg['helpers']):
        d1 = den(2*j)
        h = at['h'+str(j)]
        if 2*j+1 < len(cfg['lookups']):
            d2 = den(2*j+1)
            rel = g.sub(g.mul(g.mul(h,d1),d2),g.add(d1,d2))
        else:
            rel = g.sub(g.mul(h,d1),k(1))
        helper = g.add(helper,g.mul(c('mu'+str(5+j)),rel))
    pad = g.mul(k(0),k(0))
    out = g.add(g.add(g.add(helper,g.mul(c('mu'+str(5+cfg['helpers'])),cx)),pad),g.mul(k(1),mixed))
    assert len(out) <= 4
    return g, out + ('F()',)*(4-len(out))


def emit(g, outputs, recycled=False, mutation=None):
    """Linear scan of exact last uses. Logical temporaries only, not GPU regs."""
    last = {}
    for i, (_, a, b) in enumerate(g.nodes):
        for x in (a,b):
            if x.startswith('v') and x[1:].isdigit(): last[x] = i
    for x in outputs:
        if x.startswith('v') and x[1:].isdigit(): last[x] = len(g.nodes)
    live = {}; free = []; slots = 0; peak = 0; lines = []
    schedule = []; mutated = False
    def operand(x): return live[x] if x in live else x
    for i, (op,a,b) in enumerate(g.nodes):
        av,bv = operand(a),operand(b)
        freed = []
        for x in set((a,b)):
            if x in live and last[x] == i:
                freed.append(live.pop(x))
        if recycled:
            free.extend(freed)
            target = free.pop() if free else 'r'+str(slots)
            if target == 'r'+str(slots): slots += 1
        else: target = 'v'+str(i)
        rhs = f'{av} {dict(add="+",sub="-",mul="*",mul_base="*")[op]} {bv}'
        if mutation == 'wrong_cross_sign' and op == 'sub' and not mutated:
            rhs = f'{av} + {bv}'; mutated = True
        lines.append(f'    {target} = {rhs}')
        live['v'+str(i)] = target
        # A temporary result with no consumer is still evaluated/charged.
        if 'v'+str(i) not in last:
            dead=live.pop('v'+str(i))
            if recycled: free.append(dead)
        peak = max(peak,len(live))
        schedule.append(dict(index=i,op=op,a=a,b=b,target=target,logical_live_after=len(live)))
    result=[operand(x) for x in outputs]
    if mutation == 'drop_cubic': result[-1]='F()'
    if mutation == 'reverse_coefficients': result.reverse()
    source = 'def factory(values, differences, const, offsets):\n'+'\n'.join(lines)+'\n    return ('+', '.join(result)+')\n'
    return source,dict(field_ops=dict(g.counts),instructions=len(g.nodes),peak_live_logical_temporaries=peak,
                       allocated_reusable_slots=slots if recycled else None,
                       temporary_logical_bytes=16*peak,output_words=4,output_logical_bytes=64,
                       runtime_width_tests=0,runtime_shape_tests=0,runtime_denominator_tag_tests=0,
                       public_schedule=getattr(g,"schedule_record",None),
                       excluded='Read-only inputs, offsets/constants, caller cur/dif, equality and accumulators; native registers, stack, occupancy and compiler spills unmeasured.'),schedule


def rust_source(g, outputs, function_name):
    """Review-only scalar SSA; actual candidate has different capture layout."""
    def cv(x):
        if x=='F()': return 'Fp2::ZERO'
        if x.startswith('F('): return 'Fp2::from_u64('+x[2:-1]+')'
        return x
    # Explicit struct fields avoid a runtime string/lookup interface.
    names=sorted({x[7:-2] for _,a,b in g.nodes for x in (a,b) if x.startswith('const[')})
    def rr(x):
        if x.startswith('const['): return 'constants.'+x[7:-2]
        return cv(x)
    lines=['// Research-only generated helper. NOT BUILT, not a native patch.',
           '// Caller must use immutable layout mapping and public round0/unpadded eligibility.',
           'use zkp_core::field::{Fp, Fp2};',
           'pub struct FactoryConstants {']
    lines += ['    pub '+n+': Fp2,' for n in names]
    lines += ['}', '#[inline]',f'pub fn {function_name}(values: &[Fp2], differences: &[Fp2], constants: &FactoryConstants, offsets: &[Fp2]) -> [Fp2; 4] {{']
    for i,(op,a,b) in enumerate(g.nodes):
        right='Fp::new('+b+')' if op=='mul_base' else rr(b)
        lines.append(f'    let v{i} = {rr(a)}.{op}({right});')
    lines += ['    ['+', '.join(rr(x) for x in outputs)+']','}']
    return '\n'.join(lines)+'\n'


def write_artifacts(cfg,active,directory):
    directory=Path(directory);directory.mkdir(parents=True,exist_ok=True)
    g,out=build(cfg,active)
    tag=f'ls{cfg["ls"]}-lk{len(cfg["lookups"])}-mask{int(active)}'
    record={}
    for recycle in (False,True):
        source,stats,schedule=emit(g,out,recycle)
        suffix='recycled' if recycle else 'ssa'
        (directory/(tag+'-'+suffix+'.py')).write_text(source)
        record[suffix]=stats
        (directory/(tag+'-'+suffix+'-liveness.json')).write_text(json.dumps(schedule,indent=2)+'\n')
    (directory/(tag+'.rs')).write_text(rust_source(g,out,'sc_szc_round0'))
    return g,out,record


def build(cfg, mask_active):
    from scheduler import schedule
    graph,out=build_original(cfg,mask_active)
    new,result,record=schedule(graph,out)
    new.schedule_record=record
    return new,result
