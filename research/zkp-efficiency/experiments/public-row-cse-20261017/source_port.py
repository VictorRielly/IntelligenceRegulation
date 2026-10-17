"""Literal source-derived SC_SZC bracket; synthetic values, no native execution.

Count API operations, including literal unit/zero multiplies. Optimizing LLVM
may remove some; counts do not claim instructions, bandwidth or runtime.
"""
from collections import Counter
from field_support import F


class V:
    def __init__(self, value, counts): self.value, self.counts = value, counts
    def op(self, kind, rhs):
        self.counts[kind] += 1
        y = rhs.value if isinstance(rhs, V) else rhs
        if kind == 'mul': z = self.value*y
        elif kind == 'mul_base': z = self.value*y
        elif kind == 'add': z = self.value+y
        elif kind == 'sub': z = self.value-y
        else: raise AssertionError(kind)
        return V(z, self.counts)
    def mul(self, rhs): return self.op('mul', rhs)
    def mul_base(self, rhs): return self.op('mul_base', rhs)
    def add(self, rhs): return self.op('add', rhs)
    def sub(self, rhs): return self.op('sub', rhs)


def layout(ls=3, lp=2, padded=True, lookup_count=None):
    names = ['eq0', 'eq1', 'eq2', 'mask', 's8', 'rsl', 'zsel', 'e', 'p']
    names += [f'pl{i}' for i in range(lp)]
    names += [f'sr{i}' for i in range(ls)] + [f'sg{i}' for i in range(ls)]
    names += ['mx', 'sum']
    lk = [('s8', 1, 127), ('s8', -1, 127), ('rsl', 1, 0), ('rsl', 4, 0)]
    lk += [(f'pl{i}', 1, 0) for i in range(lp)] + [(f'pl{lp-1}', 64, 0)]
    # Synthetic exact limb count; 18/17-bit window represented explicitly.
    scale = 1 << (8*ls - (18 if ls == 3 else 15))
    lk += [(f'sr{i}', 1, 0) for i in range(ls)] + [(f'sr{ls-1}', scale, 0)]
    lk += [(f'sg{i}', 1, 0) for i in range(ls)] + [(f'sg{ls-1}', scale, 0)]
    if lookup_count is not None: lk = lk[:lookup_count]
    nh = (len(lk)+1)//2
    names += [f'h{i}' for i in range(nh)] + ['hx']
    if padded: names += ['ght', 'gs']
    index = {name: i for i, name in enumerate(names)}
    return dict(names=names, index=index, ls=ls, lp=lp, padded=padded,
                lookups=[(index[n], coef, cst) for n, coef, cst in lk], helpers=nh,
                # pad.rs a_rule exempts A_E; preserve numeric A-plane order.
                splanes=[index[n] for n in names if n in ('s8','rsl','zsel','p')
                         or n.startswith(('pl','sr','sg'))])


def bracket(group, values, cfg, const, mutation=None, den_eval=None):
    cc = Counter(); v = [V(x,cc) for x in values]; ix = cfg['index']
    k = lambda x: V(F(x),cc)
    c = lambda name: V(const[name],cc)
    at = lambda name: v[ix[name]]
    gs = at('gs') if cfg['padded'] else k(1)
    ght = at('ght') if cfg['padded'] else k(1)
    if mutation == 'ht_uses_s': ght = gs
    if group == 1: return c('nu0').mul(ght).mul(at('sum').add(c('lam'))).value, cc
    if group == 2:
        host = at('s8').mul_base(64).add(at('rsl')).sub(k(32))
        return c('nu1').mul(gs).mul(host).value, cc
    assert group == 0
    def lb(prefix, count):
        if count == 0: return k(0)
        out = at(prefix+'0')
        for i in range(1,count): out = out.add(at(prefix+str(i)).mul_base(256**i))
        return out
    sr = lb('sr',cfg['ls']); sg = lb('sg',cfg['ls']); pl = lb('pl',cfg['lp'])
    mask,s8,z,e,p,total = (at(n) for n in ('mask','s8','zsel','e','p','sum'))
    delta = at('mx').sub(mask.mul(s8.add(k(127)))).add(k(127))
    clauses = [z.mul(z).sub(z), z.mul(delta),
               mask.mul(e).mul_base(512).sub(p.mul(total)).sub(sr),
               sg.add(sr).add(k(1)).sub(total), p.sub(pl)]
    cx = at('hx').mul(c('alpha').sub(delta.add(c('beta').mul(e)).add(c('gexp')))).sub(k(1))
    mixed = k(0)
    for j, clause in enumerate(clauses):
        if mutation == 'drop_c2' and j == 2: continue
        mixed = mixed.add(c('mu'+str(j)).mul(clause))
    helper = k(0)
    def den(l):
        i,coef,cst = l
        value = V(F(cst)+const['gu8'],cc).add(v[i].mul_base(coef))
        return c('alpha').sub(value)
    lks = cfg['lookups']
    for j in range(cfg['helpers']):
        d1 = den_eval(2*j, v, cc) if den_eval else den(lks[2*j]); h = at('h'+str(j))
        if 2*j+1 < len(lks):
            d2 = den_eval(2*j+1, v, cc) if den_eval else den(lks[2*j+1]); rel = h.mul(d1).mul(d2).sub(d1.add(d2))
        else:
            rel = h.mul(d1).sub(k(1))
            if mutation == 'drop_odd': rel = k(0)
        helper = helper.add(c('mu'+str(5+j)).mul(rel))
    if mutation == 'gate_helpers': helper = gs.mul(helper)
    pad = k(0)
    if cfg['padded']:
        # Powers continue across Ht then S groups, as PadTerm::add specifies.
        exponent = 0
        for support, planes in [('ght',[ix['mx'],ix['sum']]),('gs',cfg['splanes'])]:
            if mutation == 'restart_zeta': exponent = 0
            inner = k(0)
            for i in planes:
                weight = F(1)
                for _ in range(exponent): weight *= const['zeta']
                inner = inner.add(V(weight,cc).mul(v[i])); exponent += 1
            pad = pad.add(k(1).sub(at(support)).mul(inner))
        pad = c('mupad').mul(pad)
    else:
        # PadTerm::none().eval still calls ZERO.mul(ZERO) in literal source.
        pad = k(0).mul(pad)
    out = helper.add(c('mu'+str(5+cfg['helpers'])).mul(cx)).add(pad).add(gs.mul(mixed))
    return out.value, cc


class Terms(list):
    def __init__(self, terms, group, cfg, const, mutation=None):
        super().__init__(terms)
        # Preserve the source-declared degree even if zero fixture coefficients
        # cancel every monomial. This zero sentinel is evaluator metadata only.
        declared = ([4,2,2] if cfg['padded'] else [3,1,1])[group]
        if max((len(ix) for coef,ix in self),default=0) < declared:
            self.append((F(),(cfg['index']['s8'],)*declared))
        self.group,self.cfg,self.const,self.mutation = group,cfg,const,mutation
        self.counts=Counter(); self.calls=0
    def evaluate(self, values):
        value, cc = bracket(self.group, values, self.cfg, self.const, self.mutation)
        self.counts.update(cc); self.calls += 1
        return value
