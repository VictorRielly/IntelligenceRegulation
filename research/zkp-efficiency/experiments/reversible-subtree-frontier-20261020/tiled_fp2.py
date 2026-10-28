"""Ordered-source, challenge-causal tiled prefix. Unmasked arithmetic only.

Four MLEs are folded separately before their quadratic product is evaluated.
One scan per early message, then one scan to materialize the known prefix.
No speculative challenges, retained original child array, or ZK protocol.
"""
from support import reduce_at, tensor, eq_at
from fp2 import E


def layer_source(read, n, depth, p, stats):
    """Every invocation revisits original leaves in exactly 0..n-1 order."""
    width = 1 << depth
    stats['scans'] += 1
    next_index = 0
    def checked(i):
        nonlocal next_index
        if i != next_index:
            raise ValueError('source order')
        next_index += 1
        return read(i)
    for j in range(width):
        yield reduce_at(checked, j*n//width, n//width, p, stats)
    if next_index != n:
        raise ValueError('incomplete source')


def rows(source):
    it = iter(source)
    while True:
        try:
            a, b = next(it)
        except StopIteration:
            return
        try:
            c, d = next(it)
        except StopIteration as e:
            raise ValueError('odd source') from e
        yield (a, b, c, d)


def fold_tile(tile, challenges, p, stats):
    active = len(tile)
    for r in challenges:
        for j in range(active//2):
            lo, hi = tile[2*j], tile[2*j+1]
            tile[j] = tuple((a+r*(b-a)) % p for a, b in zip(lo, hi))
            stats['fold_scalar_updates'] += 4
        active //= 2
    return active


def term(v, lam, p):
    a, b, c, d = v
    return (a*d+c*b+lam*b*d) % p


def equality(point, index, p, stats):
    value = 1
    for bit, r in enumerate(point):
        value = value*(r if (index >> bit) & 1 else 1-r) % p
        stats['stream_eq_products'] += 1
    return value


def round_pair(lo, hi, suffix_weight, current_point, prefix, lam, p):
    return [prefix*suffix_weight*((1-current_point)*(1-x)+current_point*x)*
            term(tuple((a+x*(b-a)) % p for a, b in zip(lo, hi)), lam, p) % p
            for x in range(4)]


def tiles(factory, row_count, chunk):
    it = rows(factory())
    for base in range(0, row_count, chunk):
        tile = [next(it) for _ in range(chunk)]
        yield base, tile
        # Generator must relinquish the previous tile before creating another.
        del tile
    try:
        next(it)
    except StopIteration:
        return
    raise ValueError('extra source rows')


def consumer(factory, row_count, point, prefix_rounds, lam, p, stats, eq_mode='factors'):
    """yield cubic row; send actual global challenge; return terminal + MLEs.

    The caller supplies challenges only after receiving the full row. The
    source is original ordered data, never a private opening or its reuse.
    All four resident capacities persist until completion. Temporary tiles
    have at most 2**(q+1) rows, with q <= 4 in this experiment.
    """
    k = row_count.bit_length()-1
    if row_count != 1 << k or len(point) != k or not 0 <= prefix_rounds <= k:
        raise ValueError('shape')
    if eq_mode not in ('direct', 'factors'):
        raise ValueError('equality mode')
    stats.setdefault('eq_table_entries', 0)
    stats.setdefault('eq_table_products', 0)
    known = []
    prefix = 1
    for t in range(prefix_rounds):
        row = [0]*4
        if eq_mode == 'factors':
            lo, hi, cut = tensor(point[t+1:], p)
            stats['eq_table_entries'] += len(lo)+len(hi)
            stats['eq_table_products'] += 2*(len(lo)+len(hi)-2)
        for base, tile in tiles(factory, row_count, 1 << (t+1)):
            assert fold_tile(tile, known, p, stats) == 2
            if eq_mode == 'factors':
                e = eq_at(lo, hi, cut, base >> (t+1), p)
                stats['stream_eq_products'] += 1
            else:
                e = equality(point[t+1:], base >> (t+1), p, stats)
            vals = round_pair(tile[0], tile[1], e, point[t], prefix, lam, p)
            row = [(a+b) % p for a, b in zip(row, vals)]
            del tile
        if eq_mode == 'factors':
            del lo, hi
        r = yield row
        if not isinstance(r, E):
            raise ValueError('challenge required after global message')
        known.append(r)
        prefix = prefix*((1-point[t])*(1-r)+point[t]*r) % p
    q = prefix_rounds
    active = row_count >> q
    resident = [[0]*active for _ in range(4)]
    for base, tile in tiles(factory, row_count, 1 << q):
        assert fold_tile(tile, known, p, stats) == 1
        for c in range(4):
            resident[c][base >> q] = tile[0][c]
        del tile
    for t in range(q, k):
        lo, hi, cut = tensor(point[t+1:], p)
        stats['eq_table_entries'] += len(lo)+len(hi)
        stats['eq_table_products'] += 2*(len(lo)+len(hi)-2)
        row = [0]*4
        for j in range(active//2):
            vals = round_pair(tuple(v[2*j] for v in resident),
                              tuple(v[2*j+1] for v in resident),
                              eq_at(lo, hi, cut, j, p), point[t], prefix, lam, p)
            row = [(a+b) % p for a, b in zip(row, vals)]
        del lo, hi
        r = yield row
        if not isinstance(r, E):
            raise ValueError('challenge required after global message')
        for v in resident:
            for j in range(active//2):
                v[j] = (v[2*j]+r*(v[2*j+1]-v[2*j])) % p
                stats['fold_scalar_updates'] += 1
        active //= 2
        prefix = prefix*((1-point[t])*(1-r)+point[t]*r) % p
    final = tuple(v[0] for v in resident)
    return prefix*term(final, lam, p) % p, final


def execute(read, n, depth, point, challenges, q, lam, p, eq_mode='factors'):
    stats = dict(scans=0, leaves=0, internal=0, fold_scalar_updates=0,
                 stream_eq_products=0)
    factory = lambda: layer_source(read, n, depth, p, stats)
    g = consumer(factory, 1 << (depth-1), point, q, lam, p, stats, eq_mode)
    sample_rows = []
    try:
        row = next(g)
        for r in challenges:
            sample_rows.append(row)
            row = g.send(r)
    except StopIteration as done:
        if len(sample_rows) != len(challenges):
            raise ValueError('challenge shape')
        return sample_rows, done.value[0], done.value[1], stats
    raise ValueError('too few challenges')

