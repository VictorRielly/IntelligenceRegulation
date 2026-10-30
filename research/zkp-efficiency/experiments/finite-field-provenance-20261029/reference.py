"""Independent concrete finite-field oracle; no abstract transfer imports."""
from itertools import product

def signed(v, p):
    r = v % p
    return r if r <= p // 2 else r - p

def solutions(p, a, b, c):
    return [(x, y, z) for x, y, z in product(range(a[0], a[1]+1),
            range(b[0], b[1]+1), range(c[0], c[1]+1))
            if (x*y+z) % p == 0]

def equality_relation(p, k, removed):
    # Exhausts ALL field assignments, including coordinated changes of x,y.
    out = set()
    for x, y in product(range(p), repeat=2):
        if x != y:
            continue
        if 'Rx' not in removed and not 0 <= signed(x,p) <= k:
            continue
        if 'Ry' not in removed and not 0 <= signed(y,p) <= k:
            continue
        out.add((x,y))
    return out

def least_facts(rules, removed):
    facts=set()
    while True:
        old=facts.copy()
        for source, target, premises in rules:
            if source not in removed and set(premises) <= facts:
                facts.add(target)
        if facts == old:
            return facts
