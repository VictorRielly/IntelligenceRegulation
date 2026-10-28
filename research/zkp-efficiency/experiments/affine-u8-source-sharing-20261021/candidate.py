"""Research-only source-grouped contracts and public descriptor deduplication.

Dense bit cells are counted as base-field words, never as packed hardware bits.
No commitment, transcript, succinct verifier, masking or native integration.
"""
from collections import OrderedDict

P = 2**64 - 2**32 + 1


def catalog(T, dd):
    """Independent explicit frozen w32/fE9/fP9/shifts catalog."""
    out = {d: [] for d in ('L', 'D', 'Q', 'Kv', 'F', 'S', 'Dd')}
    def emit(d, name, c=1, b=0):
        out[d].append(dict(terms=[[name, c]], cst=b))
    def many(d, names):
        for n in names: emit(d, n)
    def signed(d, n):
        emit(d, n, 1, 127); emit(d, n, -1, 127)
    def bounded(d, n, k):
        emit(d, n); emit(d, n, k)
    many('L', ['A_LIMB', 'A_LIMBM'])
    many('D', ['A_XL0', 'A_XL1']); signed('D', 'A_Y')
    many('D', [f'{n}:{i}' for n in ('nr', 'ns') for i in range(4)])
    many('D', ['A_AL0', 'A_AL1']); bounded('D', 'A_RAL', 2)
    many('D', ['A_X1L0', 'A_X1L1']); signed('D', 'A_YM')
    many('D', [f'{n}:{i}' for n in ('mr', 'ms') for i in range(4)])
    many('D', ['A_X2L0', 'A_X2L1', 'A_ZL0', 'A_ZL1'])
    bounded('D', 'A_RDL', 4)
    bounded('F', 'A_RGL', 2)
    many('F', ['A_UL0', 'A_UL1', 'A_HL0', 'A_HL1', 'A_RH0'])
    bounded('F', 'A_RH1', 4)
    signed('Q', 'A_Q8'); bounded('Q', 'A_RQL', 2)
    signed('Q', 'A_QR8'); bounded('Q', 'A_RQRL', 2)
    signed('Q', 'A_O8'); emit('Q', 'A_RO0'); bounded('Q', 'A_RO1', 128)
    for n, r in [('A_K8', 'A_RKL'), ('A_V8', 'A_RVL'), ('A_KR8', 'A_RKRL')]:
        signed('Kv', n); bounded('Kv', r, 2)
    signed('S', 'A_S8'); bounded('S', 'A_RSL', 4)
    w = T.bit_length() - 1 + 9; ls = (w + 7)//8
    d = 'Dd' if dd else 'S'
    emit(d, 'pl:0'); bounded(d, 'pl:1', 64)
    for name in ('sr', 'sg'):
        many(d, [f'{name}:{i}' for i in range(ls - 1)])
        bounded(d, f'{name}:{ls-1}', 1 << (8*ls-w))
    return out


def groups(expressions):
    grouped = OrderedDict()
    for ordinal, e in enumerate(expressions):
        if len(e['terms']) != 1: raise ValueError('not a single source')
        name, coef = e['terms'][0]
        grouped.setdefault(name, []).append((ordinal, coef, e['cst']))
    result = []
    for name, terms in grouped.items():
        pairs = {(c,b) for _,c,b in terms}
        if pairs == {(1,127),(-1,127)}:
            width, offset, forbid255 = 8, 127, True
        elif (1,0) in pairs and all(b == 0 and c > 0 and c & (c-1) == 0 and c <= 256 for c,b in pairs):
            scale = max(c for c,_ in pairs)
            width, offset, forbid255 = 8-(scale.bit_length()-1), 0, False
        else: raise ValueError(('unreviewed family', pairs))
        result.append(dict(source=name, ordinals=[i for i,_,_ in terms],
                           width=width, offset=offset, forbid255=forbid255))
    return result


def bits_for(group, source_residue):
    u = (source_residue + group['offset']) % P
    return [(u >> j) & 1 for j in range(group['width'])]


def check_bits(group, source_residue, bits, *, boolean=True, endpoint=True, link=True):
    if len(bits) != group['width']: return False
    if boolean and any(b not in (0,1) for b in bits): return False
    value = sum((1 << j)*b for j,b in enumerate(bits)) % P
    if link and (value-group['offset']) % P != source_residue % P: return False
    if endpoint and group['forbid255'] and all(b == 1 for b in bits): return False
    return True


def dedup(expressions):
    """Only exact ordered-expression aliases within this one domain."""
    out, aliases, seen = [], [], {}
    for i,e in enumerate(expressions):
        key = (e['cst'], tuple(tuple(x) for x in e['terms']))
        if key in seen: aliases.append((i,seen[key]))
        else: seen[key] = i; out.append(e)
    return out, aliases


def check_bundle(expected_groups, source_values, bundles):
    if len(bundles) != len(expected_groups): return False
    for g, (name, bits) in zip(expected_groups, bundles):
        if name != g['source'] or name not in source_values: return False
        if not check_bits(g, source_values[name], bits): return False
    return True
