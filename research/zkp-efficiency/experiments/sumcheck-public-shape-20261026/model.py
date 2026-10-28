"""Authored finite-difference candidate and literal native Lagrange port.

Only public sample count selects a path. No point-dependent division or cache.
This is an arithmetic model, not a native transcript/proof implementation.
"""
from collections import Counter

P = 0xFFFFFFFF00000001
OPS = Counter()
COUNT = False


def note(k, n=1):
    if COUNT:
        OPS[k] += n


class E:
    __slots__ = ('a', 'b')

    def __init__(self, a=0, b=0):
        self.a, self.b = a % P, b % P

    def add(self, v):
        note('ext_add')
        return E(self.a + v.a, self.b + v.b)

    def sub(self, v):
        note('ext_sub')
        return E(self.a - v.a, self.b - v.b)

    def sub_base(self, v):
        note('ext_sub_base')
        return E(self.a - v, self.b)

    def mul(self, v):
        note('ext_mul')
        return E(self.a * v.a + 7 * self.b * v.b,
                 self.a * v.b + self.b * v.a)

    def mul_base(self, v):
        note('ext_mul_base')
        return E(self.a * v, self.b * v)

    def __eq__(self, v):
        return isinstance(v, E) and (self.a, self.b) == (v.a, v.b)

    def pair(self):
        return self.a, self.b

    def wire(self):
        return self.a.to_bytes(8, 'little') + self.b.to_bytes(8, 'little')


def literal(vals, x):
    """mle.rs::interpolate_eval, with canonical Python modular arithmetic."""
    acc = E()
    for i in range(len(vals)):
        num, den = E(1), 1
        for j in range(len(vals)):
            if i == j:
                continue
            num = num.mul(x.sub_base(j))
            note('base_den_mul')
            den = den * (i - j) % P
        note('base_inv')
        acc = acc.add(vals[i].mul(num).mul_base(pow(den, P - 2, P)))
    return acc


# Public constants: inverses of 0!,1!,2!,3!,4!,5! in the native base field.
# No runtime cache, initialization, randomness, private material or x-dependence.
INVFACT = (1, 1, 9223372034707292161, 15372286724512153601,
           17678129733188976641, 18293021202169462785)


def prepared(vals, x, invfact=INVFACT):
    m = len(vals)
    if m < 2 or m > 6:
        return literal(vals, x)
    # Reverse update retains forward difference k at index k in one buffer.
    diff = list(vals)
    for k in range(1, m):
        for i in range(m - 1, k - 1, -1):
            diff[i] = diff[i].sub(diff[i - 1])
    for k in range(1,m):
        diff[k] = diff[k].mul_base(invfact[k])
    acc = diff[-1]
    for k in range(m - 2, -1, -1):
        acc = acc.mul(x.sub_base(k)).add(diff[k])
    return acc
