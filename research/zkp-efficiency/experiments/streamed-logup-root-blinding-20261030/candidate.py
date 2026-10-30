"""Locally authored arithmetic only. No transcript, PCS, GKR or privacy claim."""
from array import array
from hashlib import sha256
from time import perf_counter

P = 2**64 - 2**32 + 1


class Field:
    def __init__(self, p=P, nr=7):
        self.p, self.nr = p, nr
        self.zero, self.one = (0, 0), (1, 0)

    def add(self, x, y):
        return ((x[0] + y[0]) % self.p, (x[1] + y[1]) % self.p)

    def neg(self, x):
        return (-x[0] % self.p, -x[1] % self.p)

    def mul(self, x, y):
        a, b = x; c, d = y; p = self.p
        return ((a*c + self.nr*b*d) % p, (a*d+b*c) % p)

    def power(self, x, k):
        out = self.one
        while k:
            if k & 1:
                out = self.mul(out, x)
            x = self.mul(x, x); k >>= 1
        return out

    def merge(self, left, right):
        n, d = left; m, e = right
        return self.add(self.mul(n, e), self.mul(m, d)), self.mul(d, e)


F = Field()


def check_alpha(alpha):
    # Every table denominator, including entries with zero multiplicity.
    if alpha[1] == 0 and 0 <= alpha[0] < 256:
        raise ValueError('zero denominator in the complete public table')


def pair_table(alpha):
    check_alpha(alpha)
    started = perf_counter()
    den = [((alpha[0]-a) % P, alpha[1]) for a in range(256)]
    out = array('Q')
    for a in range(256):
        for b in range(256):
            out.extend(F.mul(den[a], den[b]))
    return {'alpha': alpha, 'values': out, 'build_s': perf_counter()-started,
            'fp2_multiplies': 65536, 'logical_operand_bytes': 48*65536,
            'packed_bytes': len(out)*out.itemsize}


def reduce_layers(current, first_stats):
    layers = [first_stats]
    peak_buffers = len(current)*8
    while len(current) > 4:
        nxt = array('Q')
        nodes = len(current)//8
        for i in range(0, len(current), 8):
            left = ((current[i], current[i+1]), (current[i+2], current[i+3]))
            right = ((current[i+4], current[i+5]), (current[i+6], current[i+7]))
            n, d = F.merge(left, right)
            nxt.extend((*n, *d))
        peak_buffers = max(peak_buffers, 8*(len(current)+len(nxt)))
        layers.append({'nodes': nodes, 'fp2_multiplies': 3*nodes,
                       'logical_operand_bytes': 96*nodes,
                       'digest': sha256(nxt.tobytes()).hexdigest()})
        current = nxt
    return ((current[0], current[1]), (current[2], current[3])), {
        'layers': layers, 'peak_live_packed_layer_bytes': peak_buffers,
        'fp2_multiplies': sum(x['fp2_multiplies'] for x in layers),
        'logical_operand_bytes': sum(x['logical_operand_bytes'] for x in layers)}


def query_root(values, alpha, table=None):
    check_alpha(alpha)
    n = len(values)
    if n < 2 or n & (n-1):
        raise ValueError('query count must be a power of two >= 2')
    if any(not isinstance(v, int) or v < 0 or v > 255 for v in values):
        raise ValueError('not a byte')
    if table is not None and table['alpha'] != alpha:
        raise ValueError('stale alpha-dependent pair table')
    started = perf_counter(); buf = array('Q')
    for i in range(0, n, 2):
        a, b = values[i], values[i+1]
        num = ((2*alpha[0]-a-b) % P, 2*alpha[1] % P)
        if table is None:
            den = F.mul(((alpha[0]-a) % P, alpha[1]),
                        ((alpha[0]-b) % P, alpha[1]))
        else:
            j = 2*(256*a+b); t = table['values']
            den = (t[j], t[j+1])
        buf.extend((*num, *den))
    root, stats = reduce_layers(buf, {
        'nodes': n//2, 'fp2_multiplies': n//2 if table is None else 0,
        'logical_operand_bytes': n + 16*n + (8*n if table is not None else 0),
        'digest': sha256(buf.tobytes()).hexdigest()})
    stats['root_build_s'] = perf_counter()-started
    stats['ns_per_lookup_diagnostic'] = stats['root_build_s']*1e9/n
    return root, stats


def table_root(counts, alpha):
    check_alpha(alpha)
    if len(counts) != 256:
        raise ValueError('complete table required')
    buf = array('Q')
    for v, c in enumerate(counts):
        buf.extend((-c % P, 0, (alpha[0]-v) % P, alpha[1]))
    return reduce_layers(buf, {'nodes': 256, 'fp2_multiplies': 0,
                              'logical_operand_bytes': 32*256,
                              'digest': sha256(buf.tobytes()).hexdigest()})[0]


def cancelling_pair(field, s, r, mode):
    if r == field.zero:
        raise ValueError('mask denominator must be nonzero')
    if mode == 'equal_denominators':
        return field.merge((s, r), (field.neg(s), r))
    if mode == 'independent_scale':
        return field.merge((s, field.one), (field.neg(field.mul(s, r)), r))
    raise ValueError('unknown mode')
