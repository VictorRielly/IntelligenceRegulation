"""Research-only leading-axis private reader, no masks or transcript changes.

Factory admission uses immutable PUBLIC native construction metadata, never
the private values. Extension targets remain owned by the original Priv site.
"""
from dataclasses import dataclass
from field import F, fold

@dataclass(frozen=True)
class Source:
    slot: str
    plane: str
    cm: str
    offset: int
    coefficient: tuple
    log: int
    coords: tuple
    mask_row: int
    ext_round: int

def eligible(s, n):
    return (s.slot == 'SC_SZC' and s.plane in ('A_MX','A_SUM') and
            s.cm == 'A' and type(s.offset) is int and s.offset >= 0 and
            s.coefficient == (1,0) and type(s.log) is int and 0 <= s.log <= n and
            s.coords == tuple(('rho',j) for j in range(s.log)) and
            type(s.mask_row) is int and s.mask_row >= 0 and s.ext_round == 0)

class Leading:
    def __init__(self, n, s, source):
        if type(n) is not int or n < 0 or not eligible(s,n):
            raise ValueError('unsupported leading private mapping')
        if len(source) != 1 << s.log: raise ValueError('private plane extent')
        self.n, self.bound, self.source = n, 0, s
        self.words = list(source)
        self.lerps = self.reads = self.shifts = self.noop_binds = 0
    def at(self, index):
        if type(index) is not int or not 0 <= index < 1 << (self.n-self.bound):
            raise ValueError('private reader index')
        self.reads += 1
        if self.bound < self.source.log:
            self.shifts += 1
            return self.words[index >> (self.n-self.source.log)]
        return self.words[0]
    def bind(self,r):
        if self.bound == self.n: raise ValueError('private reader overbind')
        if self.bound < self.source.log:
            self.lerps += len(self.words)//2
            self.words = fold(self.words,r)
        else: self.noop_binds += 1
        self.bound += 1
    def terminal(self):
        if self.bound != self.n: raise ValueError('private reader premature terminal')
        return self.words[0]

def from_committed(n,s,data,dense_fallback):
    """The native port must take source from pd.data, not an external attestation.

    Public metadata validation precedes reading private words. Unsupported
    mappings route to the exact old priv_table; no private-value-based gate.
    """
    if not eligible(s,n): return dense_fallback()
    end=s.offset+(1 << s.log)
    if end > len(data): raise ValueError('private source bounds')
    return Leading(n,s,data[s.offset:end])
