#!/usr/bin/env python3
"""Independent check of the private block's LogUp soundness term.

Paper check, one thread, well under a second. Written from the native code
(ops/zkp-mvp/trained-1b/hashline/src/private_block/shape.rs, layout.rs), not
from the recount lane's scripts; it only compares against their printed
figures at the end.

Counts:
  * N per block = sum over the six U8 lookup domains of
    lookups_per_position(dom) * size(dom)  (shape.rs:1803-1821; size after the
    P-3 lift, shape.rs:1767-1772), plus the exp pairs |S| and the act pairs |F|.
  * the number of PAIRED helper positions (helper k covers lookups 2k, 2k+1,
    layout.rs:607-608, argument.rs:894-909).
Bounds per block (|F| = p^2):
  * derived     (N + 3*768 - 1)/|F|   (this check's derivation, CHECK.md §2)
  * naive       (2N + 3*768 - 1)/|F|  (every pole charged, no absorption)
  * R14         4N/|F|                (obligations doc R14, as the memo uses it)
  * zero-check  the sumcheck slots that enforce the helper / table / zero-sum
                relations (SC_LZC, SC_DZC, SC_QZC, SC_KVZC, SC_SZC, SC_FZC,
                SC_TAB, SC_ZS), generous form ((l+1)(d+1) + l + 64)/|F| per slot.
"""
import json
import math
import os
import sys

P = 2**64 - 2**32 + 1
LOG2_F = 2 * math.log2(P)
U8_LEN = 256
TAB_DISTINCT = 3 * U8_LEN          # U8, exp, act: 256 distinct compressed rows each
LIMBS_ISQRT = 3
F_P = 9


def clog2(v):
    return (v - 1).bit_length()


def lg(x):
    return math.log2(x)


class Shape:
    """The parts of shape.rs this count needs (trained profiles)."""

    def __init__(self, name, tokens, width, hidden, q_heads, head_dim, kv_heads, lc, f_e, norm_wrho, blocks):
        self.name, self.tokens, self.width, self.hidden = name, tokens, width, hidden
        self.q_heads, self.head_dim, self.kv_heads, self.lc = q_heads, head_dim, kv_heads, lc
        self.f_e, self.norm_wrho, self.blocks = f_e, norm_wrho, blocks
        self.t_pad = 1 << clog2(tokens)
        self.d_pad = 1 << clog2(width)
        self.h_pad = 1 << clog2(q_heads)
        self.f_pad = 1 << clog2(hidden)
        self.wrho_s = clog2(self.t_pad) + f_e          # shape.rs:126-132 rule

    def natural_log(self, dom):
        t, h = self.t_pad, self.h_pad
        return {
            "L": clog2(16 * t),
            "D": clog2(t * self.d_pad),
            "Q": clog2(t * h * self.head_dim),
            "Kv": clog2(t * self.kv_heads * self.head_dim),
            "S": clog2(h * t * t),
            "F": clog2(t * self.f_pad),
            "Tab": clog2(U8_LEN),
        }[dom]

    def log(self, dom):
        n = self.natural_log(dom)
        return max(n, self.lc)            # P-3 lift: every one of these domains carries H planes

    def size(self, dom):
        return 1 << self.log(dom)

    def limbs_norm(self):
        return (self.norm_wrho + 7) // 8

    def norm_top(self):
        return self.norm_wrho != 8 * self.limbs_norm()

    def limbs_sigma_s(self):
        return (self.wrho_s + 7) // 8

    def limbs_p(self):
        return (F_P + 1 + 7) // 8

    def per_position(self, dom):
        ln, top = self.limbs_norm(), int(self.norm_top())
        per_norm = 2 + 2 * (ln + top)
        return {
            "L": 2,
            "D": 2 + per_norm + 6 + per_norm + 2 + 4,
            "F": 9,
            "Q": 13,
            "Kv": 12,
            "S": 2 + 2 + (self.limbs_p() + 1) + 2 * (self.limbs_sigma_s() + 1),
        }[dom]


DOMS = ["L", "D", "Q", "Kv", "S", "F"]


def counts(sh):
    u8 = sum(sh.per_position(d) * sh.size(d) for d in DOMS)
    exp_q, act_q = sh.size("S"), sh.size("F")
    pairs = sum((sh.per_position(d) // 2) * sh.size(d) for d in DOMS)
    singles = sum((sh.per_position(d) % 2) * sh.size(d) for d in DOMS) + exp_q + act_q
    return dict(u8=u8, exp=exp_q, act=act_q, N=u8 + exp_q + act_q, pair_positions=pairs, single_positions=singles,
                per_position={d: sh.per_position(d) for d in DOMS}, sizes_log={d: sh.log(d) for d in DOMS + ["Tab"]})


def equal_pair_strategy(sh):
    """|PP| an explicit cheating strategy reaches (a LOWER bound on the true error).

    Two limbs that enter the relations only through their weighted sum and sit
    in ONE helper pair can be set equal (value w, any field element) while the
    other limbs of the same remainder absorb the sum. If alpha lands on w, the
    pair relation h (a - w)(a - w) = (a - w) + (a - w) reads 0 = 0 and h is free,
    so the value-0 identity can be balanced whatever else is wrong.
    Counted only where the freedom is certain from the code:
      * Dom::D: the four norm remainders rho/sigma of norm_a and norm_m, four
        limbs each, pairs (0,1) and (2,3) (layout.rs:719-741, C-6 drops the
        scaled top at every trained profile); they enter only as
        sum 256^k l_k (argument.rs:1492-1493, :1559-1567). One free parameter
        per remainder, two equal pairs -> 8 distinct pole values per position.
      * Dom::S with three sigma_s limbs: pairs (sr1, sr2) and (sg1, sg2) of
        rho_s / sigma_s (layout.rs:769-778) -> 2 per position. Not counted at
        two limbs (the pair there is not free).
    """
    pp = 8 * sh.size("D")
    if sh.limbs_sigma_s() == 3:
        pp += 2 * sh.size("S")
    return pp


def zerocheck_bits(sh):
    """Generous per-block error of the eight slots that enforce the LogUp relations."""
    # (domain, structural degree before the pad indicator): shape.rs BASE_DEGREE
    slots = [("L", 4), ("D", 4), ("Q", 4), ("Kv", 4), ("S", 4), ("F", 4), ("Tab", 3), ("Tab", 2)]
    tot = 0
    for dom, d in slots:
        l = sh.log(dom)
        d1 = d + 1                        # +1 for the support indicator, charged everywhere
        tot += (l + 1) * d1 + l + 64      # rounds + one extension round, eq point, batching (mu, zeta, mu_pad)
    return tot


# trained profiles (shape.rs:345-378); norm_wrho = 32 at every trained profile
# (D-domain count 34 per position reproduces every Rust count below, i.e. the
# norm top limb is a full byte, C-6)
PROFILES = [
    Shape("TinyLlama-1.1B T32 (22 blocks, row 2^12)", 32, 2048, 5632, 32, 64, 4, 12, 9, 32, 22),
    Shape("TinyLlama-1.1B T64 (22 blocks, row 2^13)", 64, 2048, 5632, 32, 64, 4, 13, 9, 32, 22),
    Shape("TinyLlama-1.1B T128 (22 blocks, row 2^14)", 128, 2048, 5632, 32, 64, 4, 14, 9, 32, 22),
    Shape("Llama-3-8B T32 (32 blocks, row 2^13)", 32, 4096, 14336, 32, 128, 8, 13, 9, 32, 32),
    Shape("Llama-3-8B T512 (32 blocks, row 2^15; speed plan layout, unregistered)", 512, 4096, 14336, 32, 128, 8, 15, 9, 32, 32),
    Shape("Llama-3-8B T512 (32 blocks, row 2^16; recount projection, unregistered)", 512, 4096, 14336, 32, 128, 8, 16, 9, 32, 32),
]

# Rust-counted U8 lookups (results/zk60_1b_native_20261017/r3-ladder-count.log,
# r4-fast.log:131)
RUST_U8 = {
    ("TinyLlama", 32, 12): 5971968,
    ("TinyLlama", 64, 13): 12795904,
    ("TinyLlama", 128, 14): 28999680,
    ("TinyLlama", 512, 16): 214564864,
    ("Llama-3-8B", 32, 13): 11714560,
}


def main():
    out = {"log2_F": LOG2_F, "profiles": []}
    # cross-check the count against the Rust layout at every Rust-counted geometry
    print("== cross-check of the U8 lookup count against the Rust counts ==")
    checks = []
    for (fam, t, lc), want in RUST_U8.items():
        if fam == "TinyLlama":
            sh = Shape(fam, t, 2048, 5632, 32, 64, 4, lc, 9, 32, 22)
        else:
            sh = Shape(fam, t, 4096, 14336, 32, 128, 8, lc, 9, 32, 32)
        got = counts(sh)["u8"]
        ok = got == want
        checks.append(dict(family=fam, tokens=t, lc=lc, rust=want, here=got, ok=ok))
        print("  %-10s T%-4d row 2^%d: Rust %11d  here %11d  %s" % (fam, t, lc, want, got, "OK" if ok else "MISMATCH"))
    assert all(c["ok"] for c in checks), "lookup count disagrees with the Rust layout"
    out["rust_crosscheck"] = checks

    print("\n== per profile: N, pair positions, and the LogUp bounds (bits = -log2 of the error) ==")
    for sh in PROFILES:
        c = counts(sh)
        n, L = c["N"], sh.blocks
        der = n + 3 * TAB_DISTINCT - 1
        naive = 2 * n + 3 * TAB_DISTINCT - 1
        r14 = 4 * n
        zc = zerocheck_bits(sh)
        pp = equal_pair_strategy(sh)
        row = dict(
            name=sh.name, blocks=L, **c,
            wrho_s=sh.wrho_s, limbs_sigma_s=sh.limbs_sigma_s(), equal_pair_strategy_PP=pp,
            block_bits=dict(derived=LOG2_F - lg(der), N_only=LOG2_F - lg(n), naive=LOG2_F - lg(naive), r14=LOG2_F - lg(r14),
                            zerocheck=LOG2_F - lg(zc), strategy_lower=LOG2_F - lg(pp)),
            run_bits=dict(derived=LOG2_F - lg(L * der), N_only=LOG2_F - lg(L * n), naive=LOG2_F - lg(L * naive),
                          # the strategy needs its block to hit (its out-of-range limbs fail
                          # the lookup otherwise), and one cheating block suffices: the run
                          # figure is the best single block, not L times it
                          r14=LOG2_F - lg(L * r14), zerocheck=LOG2_F - lg(L * zc), strategy_lower=LOG2_F - lg(pp)),
            r14_minus_derived_bits=lg(r14) - lg(der),
            pair_share_of_N=c["pair_positions"] / n,
            p_over_N=P / n,
        )
        out["profiles"].append(row)
        b, r = row["block_bits"], row["run_bits"]
        print("\n  %s" % sh.name)
        print("    N = U8 %d + exp %d + act %d = %d   (wrho_s %d, %d sigma_s limbs; domain logs %s)" % (
            c["u8"], c["exp"], c["act"], n, sh.wrho_s, sh.limbs_sigma_s(), c["sizes_log"]))
        print("    paired-helper positions %d (%.3f N), single-helper positions %d; p/N = %.3g" % (
            c["pair_positions"], row["pair_share_of_N"], c["single_positions"], row["p_over_N"]))
        print("    per block : derived (N+2303) 2^-%.2f | N alone 2^-%.2f | naive (2N+2303) 2^-%.2f | R14 4N 2^-%.2f | helper zero-checks 2^-%.2f" % (
            b["derived"], b["N_only"], b["naive"], b["r14"], b["zerocheck"]))
        print("    per run   : derived 2^-%.2f | N alone 2^-%.2f | naive 2^-%.2f | R14 2^-%.2f | helper zero-checks 2^-%.2f   (x %d blocks)" % (
            r["derived"], r["N_only"], r["naive"], r["r14"], r["zerocheck"], L))
        print("    R14 is looser than the derived bound by %.3f bits" % row["r14_minus_derived_bits"])
        print("    explicit equal-pair strategy: |PP| = %d (%.3f N) -> success >= 2^-%.2f per block, 2^-%.2f per run (lower bound; derived bound is %.2f bits above it)" % (
            pp, pp / n, b["strategy_lower"], r["strategy_lower"], b["strategy_lower"] - b["derived"]))

    # compare with the recount lane's printed figures
    print("\n== against the recount lane's figures ==")
    here = {r["name"].split(" (")[0]: r for r in out["profiles"]}
    theirs = [
        ("TinyLlama-1.1B T32", 6266880, 98.96, 100.96),
        ("TinyLlama-1.1B T64", 13451264, 97.86, 99.86),
        ("TinyLlama-1.1B T128", 30572544, 96.67, 98.67),
        ("Llama-3-8B T32", 12271616, 97.45, 99.45),
    ]
    cmp_rows = []
    for name, n_t, r14_run, der_run in theirs:
        r = here[name]
        ok = r["N"] == n_t and abs(r["run_bits"]["r14"] - r14_run) < 0.006 and abs(r["run_bits"]["derived"] - der_run) < 0.006
        cmp_rows.append(dict(name=name, N_recount=n_t, N_here=r["N"], r14_run_recount=r14_run, r14_run_here=round(r["run_bits"]["r14"], 3),
                             derived_run_recount=der_run, derived_run_here=round(r["run_bits"]["derived"], 3), ok=ok))
        print("  %-20s N %d vs %d; run R14 2^-%.2f vs 2^-%.2f; run derived 2^-%.2f vs 2^-%.2f  %s" % (
            name, n_t, r["N"], r14_run, r["run_bits"]["r14"], der_run, r["run_bits"]["derived"], "OK" if ok else "DIFFERS"))
    t512 = [r for r in out["profiles"] if "2^15" in r["name"]][0]
    ok512 = t512["N"] == 323026944 and abs(t512["block_bits"]["derived"] - 99.73) < 0.006 and abs(t512["run_bits"]["derived"] - 94.73) < 0.006 \
        and abs(t512["run_bits"]["r14"] - 92.73) < 0.006
    print("  8B T512 (2^15) N %d vs memo 323026944; block derived 2^-%.2f vs 2^-99.73; run derived 2^-%.2f vs 2^-94.73; run R14 2^-%.2f vs 2^-92.73  %s" % (
        t512["N"], t512["block_bits"]["derived"], t512["run_bits"]["derived"], t512["run_bits"]["r14"], "OK" if ok512 else "DIFFERS"))
    cmp_rows.append(dict(name="Llama-3-8B T512 (2^15)", ok=ok512))
    out["against_recount"] = cmp_rows

    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "check_logup.json")
    with open(path, "w") as f:
        json.dump(out, f, indent=1)
    print("\nwrote", path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
