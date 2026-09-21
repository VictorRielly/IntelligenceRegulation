"""B-CHECK 1: the column keys of the four repaired bilinear claims, at the
REAL shaped layouts, symbolically and then numerically.

The memo (ZK60_GENERIC_RANK_LEMMA_SHAPED.md section 3.1) says shared
evaluation coordinates can merge two opening groups only by ACCIDENT, and
counts the tail positions that must coincide as 6/10 (rung-G SC_SCORE),
10/10 (rung-G SC_PV), 8/14 (125M SC_SCORE), 14/14 (125M SC_PV).

This script recomputes those counts from the coordinate lists as
`argument.rs:1126-1187` writes them and the key rule of
`zkp-core/src/pcs.rs:860-900` / `protocol.rs:186-192`, and adds the shape
`Shape::rung_k4` that the lane built AFTER the memo was drafted (the only
`lkv = 2` shape small enough for a capture).

It also tests the pairs the memo did NOT consider: the three feed-forward
matmul slots, which share a FIXED row point `r_tf` between SC_GMM and
SC_UMM and therefore also have structurally-equal tail positions.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from f2 import Rng, f2iszero  # noqa: E402

OUT = []


def say(s=""):
    print(s)
    OUT.append(s)


def clog2(x):
    n = 1
    k = 0
    while n < x:
        n <<= 1
        k += 1
    return k


class Shape:
    """Only the fields this check needs (shape.rs:531-568)."""

    def __init__(self, name, tokens, width, hidden, q_heads, head_dim, kv_heads, log_cols):
        self.name = name
        self.tokens, self.width, self.hidden = tokens, width, hidden
        self.q_heads, self.head_dim, self.kv_heads = q_heads, head_dim, kv_heads
        self.log_cols = log_cols
        self.t_pad = 1 << clog2(tokens)
        self.h_pad = 1 << clog2(q_heads)
        self.d_pad = self.h_pad * head_dim
        self.f_pad = 1 << clog2(hidden)
        self.lt = clog2(self.t_pad)
        self.lh = clog2(self.h_pad)
        self.ldh = clog2(head_dim)
        self.lkv = clog2(kv_heads)
        self.ld = clog2(self.d_pad)
        self.lf = clog2(self.f_pad)

    # natural logs, shape.rs:531-544 (no P-3 lift needed: none of the four
    # planes' domains is below the row width at any shape in scope, and
    # shape.rs:240-262 refuses the bilinear slots on a lifted domain)
    @property
    def log_q(self):
        return clog2(self.t_pad * self.h_pad * self.head_dim)

    @property
    def log_kv(self):
        return clog2(self.t_pad * self.kv_heads * self.head_dim)

    @property
    def log_s(self):
        return clog2(self.h_pad * self.t_pad * self.t_pad)

    @property
    def log_d(self):
        return clog2(self.t_pad * self.d_pad)

    @property
    def log_f(self):
        return clog2(self.t_pad * self.f_pad)


SHAPES = [
    Shape("toy", 32, 16, 16, 2, 8, 1, 8),
    Shape("rung-G", 24, 96, 192, 6, 16, 2, 10),
    Shape("rung-K4 (built after the memo)", 24, 96, 192, 12, 8, 4, 10),
    Shape("125M", 512, 768, 2048, 12, 64, 4, 14),
]


def coords(sh):
    """The four coordinate lists of the repaired slots, entry by entry, as
    `argument.rs:1126-1187` builds them.  Each entry is a SYMBOL:
      ('rho', slot, k)  a summed sumcheck challenge of that slot
      ('fix', name, k)  a fixed challenge drawn by that slot
    """
    lkv, ldh, lt, lh = sh.lkv, sh.ldh, sh.lt, sh.lh
    lhj = lh - lkv
    # SC_SCORE (slot 8): r_h (lh), r_t (lt), r_j (lt) then rho(0..lkv+ldh)
    r_g_s = [("rho", "SC_SCORE", k) for k in range(lkv)]
    r_hj_s = [("fix", "SCORE.r_h", lkv + k) for k in range(lhj)]
    r_t_s = [("fix", "SCORE.r_t", k) for k in range(lt)]
    r_j_s = [("fix", "SCORE.r_j", k) for k in range(lt)]
    tq = [("rho", "SC_SCORE", lkv + k) for k in range(ldh)]
    tk = [("rho", "SC_SCORE", lkv + k) for k in range(ldh)]
    cq = r_t_s + r_g_s + r_hj_s + tq              # A_QR8 on Dom::Q
    ck = r_j_s + r_g_s + tk                        # A_KR8 on Dom::Kv
    # SC_PV (slot 9)
    r_g_p = [("rho", "SC_PV", k) for k in range(lkv)]
    r_hj_p = [("fix", "PV.r_h", lkv + k) for k in range(lhj)]
    r_t_p = [("fix", "PV.r_t", k) for k in range(lt)]
    r_i_p = [("fix", "PV.r_i", k) for k in range(ldh)]
    tp = [("rho", "SC_PV", lkv + k) for k in range(lt)]
    cp = r_g_p + r_hj_p + r_t_p + tp               # A_P on Dom::S
    cv = tp + r_g_p + r_i_p                        # A_V8 on Dom::Kv
    return [
        ("SC_SCORE", "A_QR8", cq, sh.log_q),
        ("SC_SCORE", "A_KR8", ck, sh.log_kv),
        ("SC_PV", "A_P", cp, sh.log_s),
        ("SC_PV", "A_V8", cv, sh.log_kv),
    ]


def ff_coords(sh):
    """The three feed-forward matmuls (`argument.rs:1194-1210`): SC_GMM and
    SC_UMM SHARE the fixed row point `r_tf`; SC_DMM draws its own `r_td`."""
    out = []
    for slot, plane, log, inner in [
        ("SC_GMM", "A_YM", sh.log_d, sh.ld),
        ("SC_UMM", "A_YM", sh.log_d, sh.ld),
        ("SC_DMM", "A_H16", sh.log_f, sh.lf),
    ]:
        rowpt = "r_tf" if slot in ("SC_GMM", "SC_UMM") else "r_td"
        c = [("fix", rowpt, k) for k in range(sh.lt)] + [("rho", slot, k) for k in range(inner)]
        out.append((slot, plane, c, log))
    return out


def key_of(coordlist, log, log_cols):
    """`protocol.rs:186-192` / `pcs.rs:860-900`: (tail, c0, len)."""
    assert len(coordlist) == log, f"point arity {len(coordlist)} != plane log {log}"
    if log >= log_cols:
        return (tuple(coordlist[log - log_cols:]), 0, 1 << log_cols)
    # a sub-row plane: the whole point is the tail, at the plane's column offset
    return (tuple(coordlist), "c0(plane)", 1 << log)


def structural_report(sh, pairs, label):
    say(f"  {label}")
    for (sa, pa, ca, la), (sb, pb, cb, lb) in pairs:
        ka = key_of(ca, la, sh.log_cols)
        kb = key_of(cb, lb, sh.log_cols)
        if ka[1:] != kb[1:]:
            say(f"    {pa} vs {pb}: keys differ in (c0,len) -> NEVER collide")
            continue
        ta, tb = ka[0], kb[0]
        same = [i for i in range(len(ta)) if ta[i] == tb[i]]
        diff = [i for i in range(len(ta)) if ta[i] != tb[i]]
        verdict = "STRUCTURAL COLLISION" if not diff else f"{len(diff)} of {len(ta)} must coincide by accident -> 2^-{128*len(diff)}"
        say(f"    {pa}(log {la}) vs {pb}(log {lb}): tail len {len(ta)}, "
            f"{len(same)} positions equal by construction, {verdict}")
        if diff and len(diff) <= 4:
            for i in diff:
                say(f"        pos {i}: {ta[i]} vs {tb[i]}")


def numeric_check(sh, seeds=8):
    """Substitute GENERIC Fp2 values for every symbol and test key equality
    on real field elements, several seeds."""
    bad = 0
    for s in range(seeds):
        rng = Rng(hash((sh.name, s)) & 0xFFFFFFFF)
        env = {}

        def val(sym):
            if sym not in env:
                env[sym] = rng.f2()
            return env[sym]

        cl = coords(sh) + ff_coords(sh)
        keys = []
        for slot, plane, c, log in cl:
            k = key_of(c, log, sh.log_cols)
            keys.append(((slot, plane), (tuple(val(x) for x in k[0]), k[1], k[2])))
        for i in range(len(keys)):
            for j in range(i + 1, len(keys)):
                if keys[i][1] == keys[j][1] and keys[i][0][0] != keys[j][0][0]:
                    bad += 1
                    say(f"    !! numeric key collision at seed {s}: {keys[i][0]} == {keys[j][0]}")
    return bad


def main():
    say("B-CHECK 1  column keys of the repaired bilinear slots (and the FF pair)")
    say("=" * 78)
    for sh in SHAPES:
        say("")
        say(f"{sh.name}: log_cols {sh.log_cols}, lt {sh.lt}, lh {sh.lh}, lkv {sh.lkv}, "
            f"ldh {sh.ldh}, ld {sh.ld}; Dom::Q {sh.log_q}, Dom::Kv {sh.log_kv}, "
            f"Dom::S {sh.log_s}, Dom::D {sh.log_d}, Dom::F {sh.log_f}")
        c = coords(sh)
        structural_report(sh, [(c[0], c[1])], "SC_SCORE: A_QR8 vs A_KR8 (share rho_g)")
        structural_report(sh, [(c[2], c[3])], "SC_PV: A_P vs A_V8 (share rho_g AND rho_s)")
        f = ff_coords(sh)
        structural_report(sh, [(f[0], f[1])], "SC_GMM vs SC_UMM on A_YM (share the FIXED r_tf) [memo does not count this pair]")
        structural_report(sh, [(c[0], c[2]), (c[1], c[3])], "cross-slot spot checks")
        n = numeric_check(sh)
        say(f"    numeric: 8 seeds x generic Fp2 for every symbol -> {n} key collisions")

    say("")
    say("-" * 78)
    say("THE STRUCTURAL CONDITION (what would make SC_SCORE's two keys collide")
    say("BY CONSTRUCTION).  A_QR8's list ends with rho(lkv..lkv+ldh) and A_KR8's")
    say("ends with the SAME symbols.  If ldh >= log_cols both tails are the last")
    say("log_cols entries of that one shared segment and the keys are EQUAL on")
    say("every run: the two claims merge, `opening_groups_at` returns")
    say("a_groups - 1, and `check_opening` (protocol.rs:301-303) refuses EVERY")
    say("run at that shape.  Condition: head_dim >= 2^log_cols.")
    for sh in SHAPES:
        say(f"    {sh.name}: head_dim {sh.head_dim} vs row width {1 << sh.log_cols} -> "
            f"{'WOULD COLLIDE' if sh.ldh >= sh.log_cols else 'safe'}")
    say("SC_PV can never collide structurally: A_V8's tail always ends in the")
    say("fixed r_i and A_P's in rho_s.")
    say("")
    say("Also note: shape.rs:240-262 refuses the bilinear slots only when a")
    say("domain is LIFTED by P-3 (natural log BELOW the row width).  The")
    say("condition above is the opposite direction and is refused by nothing.")

    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "keys_bilinear.txt"), "w") as fh:
        fh.write("\n".join(OUT) + "\n")


if __name__ == "__main__":
    main()
