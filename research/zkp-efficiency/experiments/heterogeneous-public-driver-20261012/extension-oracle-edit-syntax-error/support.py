"""Synthetic public support reader. No masks, private data or native execution.

Threshold factors occupy DISJOINT MSB coordinate intervals. Completed factors
are absorbed into two endpoint values for the current threshold. Boolean tail
reads perform only integer tests and select an Fp2 value; no per-read field MAC.
"""
from dataclasses import dataclass
from field import F

@dataclass(frozen=True)
class Axis:
    start: int
    bits: int
    limit: int

class Support:
    def __init__(self, n, axes):
        if not isinstance(n, int) or n < 0: raise ValueError('dimension')
        self.n = n; self.next = 0
        occupied = set(); kept = []
        for a in axes:
            if any(not isinstance(x, int) for x in (a.start, a.bits, a.limit)):
                raise ValueError('axis type')
            if a.start < 0 or a.bits < 0 or a.start+a.bits > n or not 0 <= a.limit <= 1 << a.bits:
                raise ValueError('axis extent')
            scope = set(range(a.start, a.start+a.bits))
            if occupied & scope: raise ValueError('overlapping axes')
            occupied |= scope
            if a.limit != 1 << a.bits: kept.append(a)
        self.axes = sorted(kept, key=lambda a: a.start)
        self.cursor = 0; self.prefix = F(1); self.lo = F(); self.hi = F(1)
        self.bind_lerps = 0; self.integer_tests = 0; self.reads = 0
        self._normalize()

    def _normalize(self):
        while self.cursor < len(self.axes):
            a = self.axes[self.cursor]
            if self.next < a.start+a.bits: break
            self.prefix = self.lo
            self.cursor += 1
            self.lo = F(); self.hi = self.prefix

    def at(self, index):
        if not isinstance(index, int) or not 0 <= index < 1 << (self.n-self.next):
            raise ValueError('index')
        self.reads += 1
        if self.cursor == len(self.axes): return self.prefix
        active = self.axes[self.cursor]
        # Later factors are still Boolean. They must vanish before selecting
        # active values, so no field product is required for a tail endpoint.
        for a in self.axes[self.cursor+1:]:
            shift = self.n-a.start-a.bits
            x = (index >> shift) & ((1 << a.bits)-1)
            self.integer_tests += 1
            if x >= a.limit: return F()
        remaining = active.start+active.bits-max(self.next, active.start)
        shift = self.n-active.start-active.bits
        x = (index >> shift) & ((1 << remaining)-1)
        bound = active.limit & ((1 << remaining)-1)
        self.integer_tests += 1
        return self.hi if x < bound else self.lo

    def bind(self, r):
        if self.next >= self.n: raise ValueError('overbind')
        if self.cursor < len(self.axes):
            a = self.axes[self.cursor]
            if a.start <= self.next < a.start+a.bits:
                pos = a.start+a.bits-self.next-1
                if (a.limit >> pos) & 1:
                    self.lo = self.hi+r*(self.lo-self.hi)
                else:
                    self.hi = self.lo+(1-r)*(self.hi-self.lo)
                self.bind_lerps += 1
        self.next += 1
        self._normalize()

    def terminal(self):
        if self.next != self.n: raise ValueError('premature terminal')
        return self.prefix

def lg(x):
    if not isinstance(x, int) or x <= 0 or x & (x-1): raise ValueError('power of two')
    return x.bit_length()-1

def geometry(tokens, q_heads, kv_heads, head_dim=8, hidden=16, row_log=8):
    for x in (tokens,q_heads,kv_heads,head_dim,hidden):
        if not isinstance(x,int) or x <= 0: raise ValueError('positive extent')
    lg(kv_heads);lg(head_dim)
    if q_heads % kv_heads: raise ValueError('head groups')
    tp = 1 << (tokens-1).bit_length();hp = 1 << (q_heads-1).bit_length()
    if hp % kv_heads: raise ValueError('padded groups')
    return dict(tokens=tokens,q_heads=q_heads,kv_heads=kv_heads,head_dim=head_dim,
                hidden=hidden,t_pad=tp,h_pad=hp,d_pad=hp*head_dim,
                width=q_heads*head_dim,f_pad=1 << (hidden-1).bit_length(),row_log=row_log)

def spec(g, dom, cube_log=None):
    """Exact native domain support and B::supp prefix tiling, not admission.

    Lifted Q/Kv/S are refused by native Shape::new and are refused here too.
    L uses 9 subplanes (3 * fixed LIMBS_ISQRT). Tab is the fixed byte table.
    """
    t,h,d,dh,f,kv = [lg(g[k]) for k in ('t_pad','h_pad','d_pad','head_dim','f_pad','kv_heads')]
    low = h-kv;group = g['q_heads']//g['kv_heads']
    shape = {
      'T': (t, [Axis(0,t,g['tokens'])]),
      'Ht': (h+t, [Axis(kv,low,group),Axis(h,t,g['tokens'])]),
      'S': (h+2*t, [Axis(kv,low,group),Axis(h,t,g['tokens']),Axis(h+t,t,g['tokens'])]),
      'D': (t+d, [Axis(0,t,g['tokens']),Axis(t,d,g['width'])]),
      'Q': (t+d, [Axis(0,t,g['tokens']),Axis(t+kv,low,group)]),
      'Kv': (t+kv+dh, [Axis(0,t,g['tokens'])]),
      'F': (t+f, [Axis(0,t,g['tokens']),Axis(t,f,g['hidden'])]),
      'L': (4+t, [Axis(0,4,9),Axis(4,t,g['tokens'])]),
      'Tab': (8, [])}
    if dom not in shape: raise ValueError('domain')
    natural, axes = shape[dom]
    lift = 0 if dom in ('T','Ht') else max(0,g['row_log']-natural)
    if dom in ('S','Q','Kv') and lift: raise ValueError('native P-3 bilinear lift refusal')
    own = natural+lift
    axes = ([Axis(0,lift,1)] if lift else [])+[Axis(a.start+lift,a.bits,a.limit) for a in axes]
    if cube_log is None: cube_log=own
    if cube_log < own: raise ValueError('indicator does not tile')
    return cube_log, axes, own, natural, lift

def make(g,dom,cube_log=None):
    n,axes,*_ = spec(g,dom,cube_log)
    return Support(n,axes)
