#!/usr/bin/env python3
"""Recomputation of every count in ZK60_SEALED_HANDLE_SCOPING.md.

Public arithmetic only: no repository-private material is written here beyond
the published figures already in the project's own documents.

Run:  python3 results/zk60_sealed_handle_check/recount.py
"""
from math import ceil, gcd, log2

OUT = []
def say(s=""):
    OUT.append(s)
    print(s)

# ---------------------------------------------------------------- field facts
p = 2**64 - 2**32 + 1
say("=== A. field / S-box arithmetic ===")
say(f"p              = {p}")
say(f"p-1            = {p-1} = 2^32 * (2^32-1)? {p-1 == 2**32 * (2**32 - 1)}")
say(f"2^32-1 factors = 3*5*17*257*65537 = {3*5*17*257*65537} "
    f"(equal: {3*5*17*257*65537 == 2**32-1})")
for d in (2, 3, 4, 5, 6, 7, 11):
    say(f"  gcd({d:2d}, p-1) = {gcd(d, p-1)}  -> x^{d} is a permutation: "
        f"{gcd(d, p-1) == 1}")
say(f"log2(p)        = {log2(p):.4f} bits per field element")

# 31-bit comparison fields (public constants)
for name, q in (("BabyBear 2^31-2^27+1", 2**31 - 2**27 + 1),
                ("KoalaBear 2^31-2^24+1", 2**31 - 2**24 + 1),
                ("Mersenne31 2^31-1", 2**31 - 1)):
    ds = [d for d in (3, 5, 7) if gcd(d, q - 1) == 1]
    say(f"  {name}: smallest permutation power in {{3,5,7}} = {ds[:1]}")
say()

# --------------------------------------------------- B. sponge capacity needs
say("=== B. capacity needed for a stated collision level ===")
for bits_field, label in ((log2(p), "Goldilocks 64-bit"), (31.0, "31-bit field")):
    for target in (94, 106, 128):
        c = ceil(2 * target / bits_field)
        say(f"  {label}: target {target:3d} bits -> capacity >= "
            f"{c} elements ({c*bits_field:.0f} capacity bits)")
say()

# ------------------------------------------------------- C. the draft's model
say("=== C. the draft's own model, reproduced (section 3.3) ===")
VALUES = {"A": 118, "C": 238, "B": 512}
SITES  = {"A": 128, "C": 128, "B": 12}
RATE = 8
BYTES_PER_ROW = 2048   # 256 opened columns x 8 B


def model(words, bytes_per_word, log_cols, layout, sites=None):
    n_abs = words * bytes_per_word // 4
    leaves = ceil(n_abs / RATE)
    perms = 2 * leaves - 1
    vals = VALUES[layout] * perms
    rows = ceil(vals / (1 << log_cols))
    s = SITES[layout] if sites is None else sites
    pbytes = (rows + 2 * s) * BYTES_PER_ROW
    return dict(n_abs=n_abs, leaves=leaves, perms=perms, values=vals,
                rows=rows, sites=s, proof_bytes=pbytes)


SHAPES = [("tiny (T32xd16)", 512, 2, 8),
          ("125M (512x768)", 512 * 768, 2, 14),
          ("Mistral (512x4096)", 512 * 4096, 2, 14),
          ("Mistral int8", 512 * 4096, 1, 14)]
DRAFT = {  # (shape, layout) -> (values, rows, proof_bytes) as printed in the draft
    ("tiny (T32xd16)", "A"): (7434, 30, 585728),
    ("tiny (T32xd16)", "C"): (14994, 59, 645120),
    ("tiny (T32xd16)", "B"): (32256, 126, 307200),
    ("125M (512x768)", "A"): (5799818, 354, 1249280),
    ("125M (512x768)", "C"): (11697938, 714, 1986560),
    ("125M (512x768)", "B"): (25165312, 1536, 3194880),
    ("Mistral (512x4096)", "A"): (30932874, 1888, 4390912),
    ("Mistral (512x4096)", "C"): (62390034, 3808, 8323072),
    ("Mistral (512x4096)", "B"): (134217216, 8192, 16826368),
    ("Mistral int8", "A"): (15466378, 944, 2457600),
}
allok = True
for name, w, b, lc in SHAPES:
    for layout in ("A", "C", "B"):
        if (name, layout) not in DRAFT:
            continue
        m = model(w, b, lc, layout)
        d = DRAFT[(name, layout)]
        ok = (m["values"], m["rows"], m["proof_bytes"]) == d
        allok &= ok
        say(f"  {name:20s} {layout}: perms={m['perms']:>7d} "
            f"values={m['values']:>10d} rows={m['rows']:>5d} "
            f"bytes={m['proof_bytes']:>10d}  matches draft: {ok}")
say(f"  ALL section-3.3 cells reproduce exactly: {allok}")
say()

# ------------------------------------- D. the claim-site error (level-wise)
say("=== D. claim sites under LEVEL-WISE plane families (section 2.5 says "
    "section 3 prices this form) ===")
for name, w, b, lc in SHAPES[:3]:
    m = model(w, b, lc, "A")
    depth_levels = int(log2(m["leaves"])) + 1     # leaf level + internal levels
    sites_lw = 118 * depth_levels
    rows_lw = 2 * sites_lw
    bytes_lw = (m["rows"] + rows_lw) * BYTES_PER_ROW
    say(f"  {name:20s}: leaves={m['leaves']:>7d} levels={depth_levels:>2d} "
        f"sites 128 -> {sites_lw}  proof bytes {m['proof_bytes']:>10d} -> "
        f"{bytes_lw:>11d}  (x{bytes_lw/m['proof_bytes']:.2f})")
say()

# ---------------------------- E. the "forced tree doubling" is not forced
say("=== E. unrolled-leaf sponge: k permutations per leaf, no shift needed ===")
say("  leaves L = n_abs/(8k); leaf perms = k*L = n_abs/8; tree nodes = L-1")
say("  total/linear-sponge ratio = 1 + 1/k  (k=1 is the draft's binary tree)")
for k in (1, 2, 4, 8, 16, 64):
    say(f"    k={k:3d} permutations per leaf -> overhead factor "
        f"{1 + 1/k:.4f}   plane families {k}+1")
n_abs_mistral = 512 * 4096 * 2 // 4
for k in (1, 4, 8):
    L = ceil(n_abs_mistral / (8 * k))
    perms = k * L + (L - 1)
    vals = 118 * perms
    rows = ceil(vals / 16384)
    sites = 118 * (k + 1)
    say(f"    Mistral int16, k={k:2d}: perms={perms:>8d} values={vals:>10d} "
        f"rows={rows:>5d} sites={sites:>5d} "
        f"proof={(rows + 2*sites)*BYTES_PER_ROW:>10d} B")
say()

# -------------------------------------------- F. SHA-256 / D18 recomputation
say("=== F. D18's SHA-256 figure, and what the draft proposes to do to it ===")
PASS_WORDS = 9.777e9
PASS_LOOKUPS = 2.296e9
PASS_SECONDS = 58.40
HELPER_SECONDS = 5.555
WORDS_PER_SEC = 1.67e8
endpoint_bytes = (512 * 4096) * 2
compressions = endpoint_bytes // 64
say(f"  one Mistral int16 endpoint = {endpoint_bytes} B = "
    f"{compressions} SHA-256 compressions")


def sha_cost(lookups_per_comp, words_per_comp, n_endpoints=2, tree_factor=1.0):
    lk = compressions * lookups_per_comp * n_endpoints * tree_factor
    wd = compressions * words_per_comp * n_endpoints * tree_factor
    secs = HELPER_SECONDS * (lk / PASS_LOOKUPS) + wd / WORDS_PER_SEC
    return lk, wd, secs, secs / PASS_SECONDS


for label, lk_c, wd_c, tf in (
        ("record central, linear chain (the D18 basis)", 4000, 2500, 1.0),
        ("record central, x2 binary tree (draft SO-7)", 4000, 2500, 2.0),
        ("record central, x(1+1/8) unrolled leaves", 4000, 2500, 1.125),
        ("drafter's own SHA count, linear chain", 12800, 2500, 1.0),
        ("drafter's own SHA count, x2 tree", 12800, 2500, 2.0)):
    lk, wd, secs, frac = sha_cost(lk_c, wd_c, tree_factor=tf)
    say(f"  {label:46s}: lookups {lk/PASS_LOOKUPS*100:6.1f}%  "
        f"words {wd/PASS_WORDS*100:5.2f}%  {secs:6.2f} s = "
        f"{frac*100:5.1f}% of the public pass")
say()

# ---------------------------------------- G. the algebraic gadget's fractions
say("=== G. the algebraic gadget as a fraction (draft section 3.4) ===")
for layout in ("A", "C", "B"):
    m = model(512 * 4096, 2, 14, layout)
    vals2 = 2 * m["values"]
    secs = vals2 / WORDS_PER_SEC
    say(f"  Mistral 2 endpoints, layout {layout}: values {vals2:>11d} "
        f"= {vals2/PASS_WORDS*100:5.2f}% of the public pass, "
        f"{secs:5.2f} s = {secs/PASS_SECONDS*100:5.2f}%, "
        f"proof {2*m['proof_bytes']/1e6:6.2f} MB")
P125_WORDS = (585 + 486 + 288 + 16) * 16384 * 12
P125_SECONDS = 4.649
P125_BYTES = 88356464
say(f"  125M private pass: words {P125_WORDS:,} ({P125_WORDS:.3e}), "
    f"{P125_SECONDS} s, {P125_BYTES:,} B")
for layout in ("A", "C"):
    m = model(512 * 768, 2, 14, layout)
    vals2 = 2 * m["values"]
    frac = vals2 / P125_WORDS
    say(f"  125M 2 endpoints, layout {layout}: {frac*100:5.2f}% of words, "
        f"+{frac*P125_SECONDS:5.2f} s of {P125_SECONDS} s, "
        f"proof +{2*m['proof_bytes']/1e6:5.2f} MB "
        f"(+{2*m['proof_bytes']/P125_BYTES*100:5.2f}%)")
m = model(512, 2, 8, "B")
say(f"  tiny, layout B, ONE endpoint: {m['proof_bytes']} B of 2,816,472 B = "
    f"{m['proof_bytes']/2816472*100:.1f}%")
m = model(512, 2, 8, "A")
say(f"  tiny, layout A, ONE endpoint: {m['proof_bytes']} B of 2,816,472 B = "
    f"{m['proof_bytes']/2816472*100:.1f}%")
say()

# ------------------------------------- H. the gadget's own sumcheck, in ops
say("=== H. the gadget's OWN sumcheck arithmetic (omitted from the "
    "'+0.37 s' headline) ===")


def sumcheck_ops(perms, sboxes, form_terms, degree):
    """Rounds halve the domain; per surviving point we evaluate the relation at
    (degree+2) points (degree of relation x eq).  Sum over rounds ~ 2N."""
    n_points = perms
    per_point = sboxes * (form_terms + 4)   # linear form + 4 mults for x^7
    evals = degree + 2
    return 2 * n_points * per_point * evals


for layout, sboxes, terms in (("A", 118, 130), ("C", 238, 34), ("B", 512, 12)):
    m = model(512 * 4096, 2, 14, layout)
    ops = sumcheck_ops(m["perms"], sboxes, terms, 7)
    say(f"  Mistral, layout {layout}: {ops:.3e} Goldilocks mul-adds per "
        f"endpoint")
    for rate, rname in ((5e10, "5e10 op/s (optimistic GPU)"),
                        (1e10, "1e10 op/s (pessimistic GPU)")):
        say(f"      at {rname}: {ops/rate:6.2f} s per endpoint, "
            f"{2*ops/rate:6.2f} s for two")
say()

with open(__file__.replace("recount.py", "recount.out"), "w") as f:
    f.write("\n".join(OUT) + "\n")
