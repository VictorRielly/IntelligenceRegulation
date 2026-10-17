"""Canonical Goldilocks2 native-arithmetic model. Local code, no foreign imports."""
P = 2**64 - 2**32 + 1
ZERO, ONE = (0, 0), (1, 0)
REFUSAL = 'zero LogUp denominator; discard attempt'

def add(a, b):
    return ((a[0]+b[0]) % P, (a[1]+b[1]) % P)

def sub(a, b):
    return ((a[0]-b[0]) % P, (a[1]-b[1]) % P)

def mul(a, b):
    return ((a[0]*b[0]+7*a[1]*b[1]) % P,
            (a[0]*b[1]+a[1]*b[0]) % P)

def inv(a):
    if a == ZERO:
        raise ZeroDivisionError(REFUSAL)
    norm = (a[0]*a[0]-7*a[1]*a[1]) % P
    ni = pow(norm, P-2, P)
    return (a[0]*ni % P, -a[1]*ni % P)

def den(i, v, alpha, beta, tag):
    return sub(alpha, add(add((i % P, 0), mul(beta, (v % P, 0))), tag))

def counts():
    return dict(denominators=0, batch_elements=0, batch_mul=0, inversions=0,
                cache_hits=0, fallback=0, value_comparisons=0,
                destination_writes=0, chunks=0, fallback_chunks=0,
                max_fallback_words=0, cache_entries=0, short_bypass=0)

def batch(ds, c):
    # Native checked routine checks all zeros before allocating/mutating.
    if ZERO in ds:
        raise ZeroDivisionError(REFUSAL)
    if not ds:
        return []
    c['batch_elements'] += len(ds)
    c['batch_mul'] += 3*len(ds)
    c['inversions'] += 1
    prefix, acc = [], ONE
    for d in ds:
        prefix.append(acc)
        acc = mul(acc, d)
    acc = inv(acc)
    out = [ZERO]*len(ds)
    for j in range(len(ds)-1, -1, -1):
        out[j] = mul(acc, prefix[j])
        acc = mul(acc, ds[j])
    return out

def native_reference(pairs, alpha, beta, tag, c):
    c['denominators'] += len(pairs)
    return batch([den(i, v, alpha, beta, tag) for i, v in pairs], c)
