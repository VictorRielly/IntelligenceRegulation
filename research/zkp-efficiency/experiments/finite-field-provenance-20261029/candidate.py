"""Research-only rules. Full operand guard is deliberately conservative."""
from fractions import Fraction
from math import ceil, floor

def window(p): return (-p//2+1, p//2)

def inside(a,b): return b[0] <= a[0] and a[1] <= b[1]

def product_hull(a,b):
    vals=[x*y for x in a for y in b]
    return min(vals),max(vals)

def integer_backward(b,c):
    if b[0] <= 0 <= b[1]: return None
    vals=[Fraction(-z,y) for y in b for z in c]
    return ceil(min(vals)),floor(max(vals))

def weak_backward(p,b,c):
    # Negative control: range of divisor/conclusion alone is insufficient.
    d=integer_backward(b,c)
    if d is None or not inside(b,window(p)) or not inside(c,window(p)):
        return window(p)
    return d if inside(d,window(p)) else window(p)

def guarded_backward(p,a,b,c):
    # a is an INDEPENDENT premise, never the conclusion being justified.
    if not inside(a,window(p)) or not inside(b,window(p)) or not inside(c,window(p)):
        raise ValueError('invalid signed premise')
    if not inside(product_hull(a,b),window(p)):
        return a
    d=integer_backward(b,c)
    if d is None: return a
    return max(a[0],d[0]),min(a[1],d[1])

def provable(rules, target, removed, stack=frozenset()):
    # Path-local cycle rejection; no false-result memo across search contexts.
    if target in stack: return False
    return any(source not in removed and all(provable(rules,p,removed,stack|{target})
        for p in premises) for source,f,premises in rules if f==target)

def remove_cumulative(rules, obligations, order):
    removed=set()
    for check in order:
        mask=removed|{check}
        if all(provable(rules,f,mask) for f in obligations[check]):
            removed=mask
    return removed
