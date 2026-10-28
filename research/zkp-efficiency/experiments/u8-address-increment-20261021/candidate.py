"""Synthetic witness contracts only. No commitment, transcript or private proof."""
P = 2**64 - 2**32 + 1


def field_ok(p):
    if p != P:
        raise ValueError('this diagnostic admits native Goldilocks only')


def source_ok(source, p=P):
    field_ok(p)
    keys = set()
    for site, value in source:
        if (not isinstance(site, tuple) or len(site) != 3 or
                site[0] not in ('D', 'F', 'S', 'Q', 'Kv', 'L', 'Dd') or
                any(type(x) is not int or x < 0 for x in site[1:]) or site in keys):
            raise ValueError('ordered source site')
        if type(value) is not int or not 0 <= value < p:
            raise ValueError('noncanonical source field')
        keys.add(site)


def make_factors(source, d, p=P):
    source_ok(source, p)
    if d not in (1, 2, 4, 8):
        raise ValueError('factor count')
    radix = 1 << (8 // d)
    result = []
    for site, q in source:
        if q >= 256:
            raise ValueError('U8')
        factors = []
        for k in range(d):
            digit = (q >> (k * (8 // d))) & (radix - 1)
            factors.append([int(j == digit) for j in range(radix)])
        result.append((site, factors))
    return result


def check_factors(source, witness, d, p=P):
    source_ok(source, p)
    if d not in (1, 2, 4, 8) or len(source) != len(witness):
        raise ValueError('geometry')
    radix = 1 << (8 // d)
    for (site, q), (wsite, factors) in zip(source, witness):
        if site != wsite or len(factors) != d:
            raise ValueError('site or shape')
        q_rebuilt = 0
        for k, factor in enumerate(factors):
            if len(factor) != radix:
                raise ValueError('radix')
            if any(type(v) is not int or not 0 <= v < p or v * (v - 1) % p for v in factor):
                raise ValueError('booleanity')
            if sum(factor) % p != 1:
                raise ValueError('one per digit')
            digit = sum(j * v for j, v in enumerate(factor)) % p
            q_rebuilt += digit * radix**k
        if q_rebuilt != q:
            raise ValueError('ordered original-source address')
    return True


def events(source, p=P):
    source_ok(source, p)
    counts = [0] * 256
    trace = []
    for site, q in source:
        if q >= 256:
            raise ValueError('U8')
        trace.append((site, q, counts[q], counts[q] + 1))
        counts[q] += 1
    return trace, counts


def check_events(source, trace, histogram, p=P):
    source_ok(source, p)
    if len(source) != len(trace) or len(histogram) != 256:
        raise ValueError('trace length')
    if any(type(x) is not int or not 0 <= x <= len(source) for x in histogram):
        raise ValueError('histogram range')
    state = [0] * 256
    for (site, q), (wsite, address, before, after) in zip(source, trace):
        if site != wsite or type(address) is not int or not 0 <= address < 256 or address != q:
            raise ValueError('ordered source link')
        if type(before) is not int or type(after) is not int or before != state[address] or after != before + 1:
            raise ValueError('ordered increment')
        state[address] = after
    if state != histogram:
        raise ValueError('final histogram')
    return True


def basis(index, point, p=P):
    value = 1
    for k, x in enumerate(point):
        value = value * (x if index >> k & 1 else 1 - x) % p
    return value


def sparse_mle(source, address_point, time_point, p=P):
    source_ok(source, p)
    if len(address_point) != 8 or len(source) != 1 << len(time_point):
        raise ValueError('MLE geometry')
    if any(q >= 256 for _, q in source):
        raise ValueError('U8')
    return sum(basis(i, time_point, p) * basis(q, address_point, p)
               for i, (_, q) in enumerate(source)) % p


def factored_mle(witness, d, address_point, time_point, p=P):
    radix = 1 << (8 // d)
    total = 0
    for t, (_, factors) in enumerate(witness):
        product = basis(t, time_point, p)
        for k, f in enumerate(factors):
            point = address_point[k * (8 // d):(k + 1) * (8 // d)]
            product = product * sum(v * basis(j, point, p) for j, v in enumerate(f)) % p
        total += product
    return total % p


def make_bits(source, p=P):
    source_ok(source, p)
    if any(q >= 256 for _, q in source):
        raise ValueError('U8')
    return [(site, [(q >> j) & 1 for j in range(8)]) for site, q in source]


def check_bits(source, witness, p=P):
    source_ok(source, p)
    if len(source) != len(witness):
        raise ValueError('bit geometry')
    for (site, q), (ws, bits) in zip(source, witness):
        if site != ws or len(bits) != 8:
            raise ValueError('bit site/shape')
        if any(type(v) is not int or not 0 <= v < p or v*(v-1) % p for v in bits):
            raise ValueError('bit booleanity')
        if sum(v*2**j for j, v in enumerate(bits)) != q:
            raise ValueError('bit source address')
    return True


def bits_mle(witness, ap, tp, p=P):
    # Virtual complementary entries: each length-two factor is [1-b, b].
    total = 0
    for t, (_, bits) in enumerate(witness):
        v = basis(t, tp, p)
        for b, x in zip(bits, ap):
            v = v * ((1-b)*(1-x)+b*x) % p
        total += v
    return total % p


def logical_cost(n, d, native_helper_bytes, rate=4):
    if d not in (1, 2, 4, 8):
        raise ValueError('d')
    radix = 1 << (8 // d)
    dense_words = n * d * radix
    return dict(d=d, radix=radix, queries=n, nonzero_entries=n*d,
                dense_base_words=dense_words, dense_data_bytes=8*dense_words,
                encoded_payload_bytes=8*dense_words*rate,
                versus_native_helper_data=8*dense_words/native_helper_bytes,
                virtual_complement_bit_base_words=8*n,
                virtual_complement_bit_data_bytes=64*n,
                bit_data_vs_native_helpers=64*n/native_helper_bytes,
                compact_event_scalar_words=3*n+256,
                optional_explicit_bit_event_words=11*n+256,
                new_private_commitments=None, new_mask_sites=None,
                fresh_mask_words=None, new_pcs_groups=None, proof_bytes=None,
                omitted='private binding/reductions, masks, padding, trees, scratch, all non-U8 owners')
