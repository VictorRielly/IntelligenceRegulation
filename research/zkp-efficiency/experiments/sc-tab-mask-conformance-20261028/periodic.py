"""Research public-only MSB periodic descriptor. No native integration."""
from field import F, fold

class Periodic:
    def __init__(self, n, words, declared_len=None):
        if type(n) is not int or not 8 <= n <= 30:
            raise ValueError('periodic cube')
        if len(words) != 256 or any(not isinstance(x, F) for x in words):
            raise ValueError('periodic 256 Fp2 rows')
        if declared_len is not None and declared_len != 1 << n:
            raise ValueError('public table length')
        self.n, self.bound, self.words = n, 0, list(words)
        self.lerps = self.noop_binds = self.reads = 0
    def at(self, index):
        if type(index) is not int or not 0 <= index < 1 << (self.n-self.bound):
            raise ValueError('periodic index')
        self.reads += 1
        return self.words[index & (len(self.words)-1)]
    def bind(self, r):
        if self.bound == self.n: raise ValueError('periodic overbind')
        if self.n-self.bound > 8:
            self.noop_binds += 1
        else:
            self.lerps += len(self.words)//2
            self.words = fold(self.words,r)
        self.bound += 1
    def terminal(self):
        if self.bound != self.n: raise ValueError('premature periodic terminal')
        return self.words[0]

def eval_public(n, words, rho, extensions=()):
    if len(rho) != n: raise ValueError('public terminal point')
    p=Periodic(n,words,1<<n)
    for r in rho: p.bind(r)
    value=p.terminal()
    for e in extensions: value *= 1-e
    return value

def encode(kind, raw, beta, gamma):
    if len(raw) != 256: raise ValueError('raw public table length')
    if kind not in ('u8','exp','act'): raise ValueError('table family')
    return [F(i)+gamma if kind=='u8' else F(i)+beta*F(raw[i])+gamma for i in range(256)]

def tab_poly(v, alpha, mu, zeta, padded):
    rel=sum((mu[k]*(v[2+3*k]*(alpha-v[3+3*k])-v[1+3*k]) for k in range(3)), F())
    if padded:
        power=F(1); inner=F()
        for idx in (1,4,7,2,5,8):
            inner += power*v[idx]; power *= zeta
        rel += mu[3]*(1-v[10])*inner
    return v[0]*rel
