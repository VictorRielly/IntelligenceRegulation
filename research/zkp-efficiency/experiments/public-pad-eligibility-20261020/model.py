"""Public descriptor/gate model translated from the pinned Rust source.

No device calls, masks, private tables, native transcript or proof execution.
"""
P = 2**64 - 2**32 + 1
Z = (0, 0)
ONE = (1, 0)

def add(x, y):
    return ((x[0] + y[0]) % P, (x[1] + y[1]) % P)

def mul(x, y):
    # Karatsuba, as opposed to the schoolbook quotient-ring reference.
    ac = x[0] * y[0] % P
    bd = x[1] * y[1] % P
    return ((ac + 7*bd) % P,
            ((x[0]+x[1])*(y[0]+y[1])-ac-bd) % P)

def descriptor(padded, frozen_toy, zeta):
    # SC_FZC's sole hosted padded domain is F; all eleven F A planes
    # are ZERO-rule. A_E, the only exemption, is in S.
    if frozen_toy or not padded:
        return []
    if zeta == Z:
        raise ValueError('zero batching challenge; discard attempt')
    out = []
    w = ONE
    for t in range(3, 14):
        out.append((t, w))
        w = mul(w, zeta)
    return out

def params(desc, supp, mu_pad):
    # Only the 84-word block's relevant fields; all other words inert here.
    if desc and not supp:
        raise ValueError('pad term without support')
    seen = set()
    p = [0] * 84
    p[28:30] = mu_pad if desc else Z
    for t, w in desc:
        if not 3 <= t < 14 or t in seen:
            raise ValueError('pad plane not a distinct A plane')
        seen.add(t)
        off = 62 + 2*(t-3)
        p[off:off+2] = w
    return p

def pad_derived(p, values):
    s = Z
    for j in range(11):
        w = tuple(p[62+2*j:64+2*j])
        if w != Z:
            s = add(s, mul(w, values[j]))
    return mul(tuple(p[28:30]), s)

def gates(srcs, *, supp, split, fused, raw_switch, n, tail_log, next_round):
    # src: (Base/Pair/Eq/Host/Public, device-resident, all-base metadata).
    # Host/Public metadata stands for synthetic entries / the existing
    # constructor check. Do not add a scan of real private values for telemetry.
    base = split
    for t, (kind, dev, is_base) in enumerate(srcs):
        needs_base = 3 <= t <= 13 or supp and t == 20
        if needs_base:
            if kind in ('Pair', 'Eq'):
                base = False
            elif kind in ('Host', 'Public') and not is_base:
                base = False
    raw = (split and fused and raw_switch and n >= 3 and n-1 > tail_log)
    for t, (kind, dev, _) in enumerate(srcs):
        if 3 <= t <= 19 and (kind not in ('Base', 'Pair') or not dev):
            raw = False
    # Adapter's phase1b is round0/raw/!FOLD; next==0 is the caller gate.
    return dict(base=bool(base), raw=bool(raw),
                adapter=bool(base and raw and next_round == 0))

def geometry(tokens, hidden, log_cols):
    tpad = 1 << (tokens-1).bit_length()
    fpad = 1 << (hidden-1).bit_length()
    entries = max(tpad*fpad, 1 << log_cols)  # Dom F carries H planes.
    return entries, entries != tokens*hidden
