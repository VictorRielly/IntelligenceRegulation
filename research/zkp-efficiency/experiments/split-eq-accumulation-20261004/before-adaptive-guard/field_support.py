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

