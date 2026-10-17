"""Research-only MSB ClosureRounds with explicit cube and heterogeneous tables.

No transcript, masks, RNG, PCS or native execution. Readers stay immutable in
part scans; each table binds exactly once after all round parts reduce.
"""
from field import F, fold

def interpolate(values, r):
    out = F()
    for i, y in enumerate(values):
        weight = F(1)
        for j in range(len(values)):
            if i != j: weight = weight * ((r-j)/(i-j))
        out += y*weight
    return out

class Dense:
    def __init__(self, n, words):
        if len(words) != 1 << n: raise ValueError('dense extent')
        self.n, self.bound, self.words = n, 0, list(words)
        self.lerps = 0
    def at(self, index):
        if type(index) is not int or not 0 <= index < len(self.words):
            raise ValueError('dense index')
        return self.words[index]
    def bind(self, r):
        if self.bound == self.n: raise ValueError('dense overbind')
        self.lerps += len(self.words)//2
        self.words = fold(self.words, r); self.bound += 1
    def terminal(self):
        if self.bound != self.n: raise ValueError('dense premature terminal')
        return self.words[0]

def progress(t):
    return t.next if hasattr(t, 'next') else t.bound

class Tables:
    def __init__(self, n, entries):
        if type(n) is not int or n < 0: raise ValueError('cube dimension')
        if not entries: raise ValueError('empty tables')
        names = [name for name, _, _ in entries]
        if len(set(names)) != len(names): raise ValueError('duplicate table identity')
        if any(t.n != n or progress(t) != 0 for _, _, t in entries):
            raise ValueError('table cube or initial state')
        self.n, self.bound, self.entries = n, 0, list(entries)
        self.bind_calls = 0
    def row(self, index):
        if type(index) is not int or not 0 <= index < 1 << (self.n-self.bound):
            raise ValueError('cube index')
        return [t.at(index) for _, _, t in self.entries]
    def total(self, poly, chunk=1024):
        if self.bound: raise ValueError('total requires original cube')
        if type(chunk) is not int or chunk <= 0: raise ValueError('chunk')
        out = F(); length = 1 << self.n
        for lo in range(0, length, chunk):
            part = F()
            for index in range(lo, min(length,lo+chunk)): part += poly(self.row(index))
            out += part
        return out
    def bind(self, r):
        if self.bound == self.n: raise ValueError('table overbind')
        for _, _, t in self.entries:
            if progress(t) != self.bound: raise ValueError('table bind state')
            t.bind(r); self.bind_calls += 1
        self.bound += 1
    def finals(self):
        if self.bound != self.n: raise ValueError('table premature finals')
        return [t.terminal() for _, _, t in self.entries]

class Rounds:
    def __init__(self, tables, degree, poly, chunk=1024, recover=False, claim=None, debug=False):
        if type(degree) is not int or degree < 0: raise ValueError('degree')
        if chunk <= 0: raise ValueError('chunk')
        if recover and degree < 1: raise ValueError('recovery degree')
        self.tables, self.degree, self.poly = tables, degree, poly
        self.chunk, self.recover, self.claim, self.debug = chunk, recover, claim, debug
        self.next, self.pending = 0, None
        self.recoveries = self.poly_calls = self.endpoint_reads = 0
    def round(self, j):
        if j != self.next or j >= self.tables.n or self.pending is not None:
            raise ValueError('round schedule')
        half = 1 << (self.tables.n-j-1)
        sums = [F() for _ in range(self.degree+1)]
        use_claim = self.recover and self.claim is not None
        for lo in range(0, half, self.chunk):
            part = [F() for _ in sums]
            for i in range(lo, min(half,lo+self.chunk)):
                cur, high = self.tables.row(i), self.tables.row(i+half)
                self.endpoint_reads += 2*len(cur)
                diff = [b-a for a,b in zip(cur,high)]
                for x in range(self.degree+1):
                    if x != 1 or not use_claim or self.debug:
                        part[x] += self.poly(cur); self.poly_calls += 1
                    if x != self.degree: cur = [a+d for a,d in zip(cur,diff)]
            sums = [a+b for a,b in zip(sums,part)]
        if use_claim:
            if self.debug and sums[0]+sums[1] != self.claim:
                raise ValueError('unmasked recovery claim mismatch')
            sums[1] = self.claim-sums[0]; self.recoveries += 1
        self.pending = list(sums)
        return sums
    def bind(self, r):
        if self.pending is None: raise ValueError('bind needs round')
        if self.recover: self.claim = interpolate(self.pending,r)
        self.tables.bind(r); self.next += 1; self.pending = None
    def finals(self):
        if self.pending is not None: raise ValueError('finals pending round')
        return self.tables.finals()

def extend(finals, entries, private_exts, x):
    """Synthetic table extension: all public tables have target zero."""
    if len(finals) != len(entries): raise ValueError('extension arity')
    return [a+x*((private_exts.get(name,F()) if private else F())-a)
            for a,(name,private,_) in zip(finals,entries)]
