"""The DECLARED slot degree against the closure's ACTUAL total degree.

The memo reads `Shape::slots()`' declared `(main, ext, degree)` triple and
never asks whether `def.poly` has that degree.  It matters two ways:

  * declared < actual  -> the sumcheck is incomplete AND the CFS mask does not
    cover the channel (clause C3 fails).  This must never happen.
  * declared > actual  -> safe, but every round message carries one extra
    `Fp2` for nothing, and `L = N*d + 2` is larger than it needs to be.

Method: evaluate each slot's polynomial in the max-plus ("tropical") degree
semiring -- every table value (Eq, Pub or Priv alike) has degree 1, a field
constant has degree 0, `a + b` -> max, `a * b` -> sum.  This is an exact port
of the ARITHMETIC of each `define` arm at lane commit 8c5922b and gives an
UPPER bound on the true total degree (cancellation could only lower it).  So
`maxplus < declared` proves over-declaration; `maxplus <= declared` for every
slot proves there is no under-declaration.

The table index map is irrelevant here: every `v[i]` has degree 1 whatever it
is, so only the shape of the expression matters.
"""
import json
import os

LANE = "/home/victor/wt-zk60-block125m/results/zk60_block125m_lane"
NEG = -10 ** 9  # the degree of the zero polynomial


class D:
    __slots__ = ("d",)

    def __init__(self, d):
        self.d = d

    def __add__(self, o):
        return D(max(self.d, o.d))

    def __sub__(self, o):
        return D(max(self.d, o.d))

    def __mul__(self, o):
        return D(self.d + o.d)

    def __neg__(self):
        return D(self.d)


K = D(0)      # any field constant / challenge
V = D(1)      # any table value
Z = D(NEG)    # the identically-zero polynomial


def maybe(gate_present):
    """`Gate::at` -- v[i] (degree 1) when the indicator exists, else ONE."""
    return V if gate_present else K


def helper_sum(n_lookups):
    """`argument.rs:672-688` -- sum_k mu_k * (h * d1 * d2 - (d1 + d2)), with
    the odd tail `h * d1 - 1`."""
    acc = Z
    for k in range(-(-n_lookups // 2)):
        h = V
        d1 = K - V            # alpha - (cst + sum c v[i])
        if 2 * k + 1 < n_lookups:
            d2 = K - V
            rel = h * d1 * d2 - (d1 + d2)
        else:
            rel = h * d1 - K
        acc = acc + K * rel
    return acc


def pad_term(on):
    """`PadTerm::eval` -- mu * sum_groups (1 - supp) * sum_j zeta^j plane_j."""
    if not on:
        return Z
    return K * ((K - V) * (K * V))


def slot_degree(s, gate, pz, group_eq, n_lk):
    """The total degree of slot `s`'s closure, arm by arm."""
    g = maybe(gate)
    if s in (0, 1):                                   # SC_SS / SC_SSM
        return (g * V * V * V).d
    if s == 2:                                        # SC_TZC
        d_, dsq, dl, a1, a2 = V, V, V, V, V
        zc = K * (dsq - d_ * d_) + K * (d_ - dl) + K * (d_ - a1 - a2)
        zc = zc + K * (V - V * V) + K * (V - V) + K * (V - V - V)
        host = K * V * g * (dsq + a1 - K)
        return max((V * (zc + pad_term(pz))).d, host.d, (K * V * g * (V + V - K)).d)
    if s == 3:                                        # SC_LZC (Dom::L, 2 lookups)
        return (V * (helper_sum(2) + pad_term(pz))).d
    if s == 4:                                        # SC_RS
        return (g * V * (V * V + K * V)).d
    if s in (5, 6, 7, 10, 11, 12, 13):                # the seven matmuls
        return (V * V).d
    if s in (8, 9):                                   # SC_SCORE / SC_PV
        return (maybe(group_eq) * V * V).d
    if s == 14:                                       # SC_DZC
        x, y, ao, x1, d_ = V, V, V, V, V
        nm, x2, z16, dm = V, V, V, V
        nr, ns, mr, ms = V, V, V, V
        l2 = V
        c0 = K * V * x + K * d_ - K * y * d_ - nr
        c1 = ns + nr + K - K * d_
        c2 = x + K - l2
        c3 = ao + K - l2
        c4 = x1 + K - l2
        c5 = x1 - x - ao
        c6 = K * V * x1 + K * dm - K * nm * dm - mr
        c7 = ms + mr + K - K * dm
        c8 = x2 + K - l2
        c9 = x2 - x1 - z16
        c10 = z16 + K - l2
        zc = helper_sum(n_lk) + pad_term(pz)
        for c in (c0, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10):
            zc = zc + K * g * c
        host_wo = K * ao + V - K
        host_dmm = K * z16 + V - K
        return (V * zc + K * V * g * host_wo + K * V * g * host_dmm).d
    if s == 18:                                       # SC_FZC
        g8, a16, u16, h16 = V, V, V, V
        f0 = a16 * u16 - K * h16 - V + K
        f1 = u16 + K - V
        f2 = h16 + K - V
        f_act = V * (K - (g8 + K + K * a16 + K)) - K
        zc = helper_sum(n_lk) + K * f_act + pad_term(pz)
        for c in (f0, f1, f2):
            zc = zc + K * g * c
        host_g = K * g8 + V - K
        host_u = u16
        return (V * zc + K * V * g * host_g + K * V * g * host_u).d
    if s in (15, 16):                                 # SC_QZC / SC_KVZC
        rope = V * V + V * V - K * V - V + K
        zc = K * g * rope + helper_sum(n_lk) + pad_term(pz)
        host1 = K * V + V - K
        host2 = K * V + V + V * K - K
        return (V * zc + K * V * g * host1 + K * V * g * host2).d
    if s == 17:                                       # SC_SZC
        mask, s8, zsel, e, p, sm = V, V, V, V, V, V
        sr = V
        delta = V - mask * (s8 + K) + K
        c0 = zsel * zsel - zsel
        c1 = zsel * delta
        c2 = K * mask * e - p * sm - sr
        c3 = V + sr + K - sm
        c4 = p - V
        cx = V * (K - (delta + K * e + K)) - K
        zc = helper_sum(n_lk) + K * cx + pad_term(pz)
        for c in (c0, c1, c2, c3, c4):
            zc = zc + K * g * c
        host_rs = sm + K
        host_s = K * s8 + V - K
        # NOTE: host_rs is gated by supp_Ht (`ght`), host_s by supp_S (`gs`)
        return (V * zc + K * V * maybe(gate) * host_rs + K * V * g * host_s).d
    if s == 19:                                       # SC_TAB
        r = V * (K - V) - V
        return (V * (K * r + K * r + K * r + pad_term(pz))).d
    if s == 20:                                       # SC_ZS
        return (V * V).d
    if s in (21, 22):                                 # SC_IO_IN / SC_IO_OUT
        return (V * (V - V)).d
    raise AssertionError(s)


# which domain gates which slot (`INDICATOR_SLOT_DOMAIN`, shape.rs:65-66)
IND = {0: "D", 1: "D", 4: "S", 14: "D", 15: "Q", 16: "Kv", 17: "S", 18: "F"}
# which domain's pad-zero term each slot hosts (`pad.rs:pad_zero_host`)
PZ = {2: ["T"], 3: ["L"], 14: ["D"], 15: ["Q"], 16: ["Kv"], 17: ["Ht", "S"], 18: ["F"], 19: ["Tab"]}
# the LogUp domain each zero-check reads
HELPDOM = {3: "L", 14: "D", 15: "Q", 16: "Kv", 17: "S", 18: "F"}


def lookups_of(model, dom):
    """lookups PER POSITION of `dom` (`Shape::lookups_per_position`)."""
    return model["lookups"]["per_position"][dom]


def main():
    out = {}
    bad_under, bad_over = [], []
    for name in ("toy", "rung_g", "rung_k4", "m125"):
        m = json.load(open(f"{LANE}/model_{name}.json"))
        padded = set(m["padded_domains"]) if name != "toy" else set()  # toy: no pad rule
        rows = []
        for s, sl in enumerate(m["slots"]):
            declared = sl["degree"]
            gate = IND.get(s) in padded
            pz = any(d in padded for d in PZ.get(s, []))
            geq = sl["group_sumcheck_bits"] > 0
            nlk = lookups_of(m, HELPDOM[s]) if s in HELPDOM else 0
            actual = slot_degree(s, gate, pz, geq, nlk)
            rows.append({"slot": s, "name": sl["name"], "declared": declared,
                         "maxplus_upper_bound": actual, "gated": gate,
                         "pad_zero_term": pz, "slack": declared - actual})
            if actual > declared:
                bad_under.append((name, s, declared, actual))
            if actual < declared:
                bad_over.append((name, s, declared, actual, sl["main_rounds"] + sl["extension_rounds"]))
        out[name] = rows

    res = {"per_shape": out,
           "under_declared_SOUNDNESS": [{"shape": a, "slot": b, "declared": c, "actual_ub": d}
                                        for a, b, c, d in bad_under],
           "over_declared": [{"shape": a, "slot": b, "declared": c, "actual_ub": d,
                              "N": e, "wasted_fp2_words": e}
                             for a, b, c, d, e in bad_over]}
    waste = {}
    for a, b, c, d, e in bad_over:
        waste.setdefault(a, 0)
        waste[a] += e
    res["wasted_fp2_words_per_block"] = waste
    res["wasted_bytes_per_block"] = {k: v * 16 for k, v in waste.items()}
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "degree_maxplus.json")
    json.dump(res, open(p, "w"), indent=1)

    print(f"[COMPUTED] under-declared (soundness/C3 break): {len(bad_under)}")
    for r in bad_under:
        print("   ", r)
    print(f"[COMPUTED] over-declared (safe, but costs receipt bytes): {len(bad_over)}")
    for a, b, c, d, e in bad_over:
        print(f"    shape={a:7s} slot={b:02d} declared={c} actual<={d}  N={e}  wasted={e} Fp2 = {e*16} B")
    print("wasted per block:", res["wasted_bytes_per_block"])


if __name__ == "__main__":
    main()
