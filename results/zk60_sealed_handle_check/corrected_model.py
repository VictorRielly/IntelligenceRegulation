#!/usr/bin/env python3
"""The sealed-handle gadget recosted with the corrections this check makes.

Corrections applied, each justified in ZK60_SEALED_HANDLE_SCOPING_CHECK.md:

 (1) claim sites are per PLANE FAMILY per TREE LEVEL, not 128 flat.  The draft
     says so itself (sec 2.5: "the number of claim sites multiplies by the
     depth") and then prices 128 in sec 3.3.
 (2) a claim site's reserved mask PAIR is two rows of the DATA commitment
     (2^log_cols wide), not of M: layout.rs:523-526 gives A_ROWS = 455 =
     213 data + 2*120 site pairs + 2 proximity.  The draft counts site pairs
     in proof bytes only and omits them from committed volume.  (The separate
     per-slot CFS masks live on M, whose geometry is fixed at 512/4096/256 --
     zk.rs:373-375 -- and are 2 per SLOT, a much smaller term.)
 (3) the "forced factor of two" is not forced: unrolling k sequential
     absorptions per leaf needs only a fixed-variable split and gives 1 + 1/k.
 (4) per-absorbed-element committed values taken from Monolith Table 4 / rate
     (see sources.md), not from the draft's recollection.
"""
from math import ceil, log2

OUT = []
def say(s=""):
    OUT.append(s)
    print(s)

RATE = 8
BYTES_PER_ROW = 2048          # 256 opened columns x 8 B, data rows and mask rows
MASK_ROW_WORDS = 512          # zk.rs:373  MASK_LOG_MSG = 9
PASS_WORDS = 9.777e9
PASS_SECONDS = 58.40
WORDS_PER_SEC = 1.67e8
P125_WORDS = (585 + 486 + 288 + 16) * 16384 * 12
P125_SECONDS_GPU = 4.649
P125_SECONDS_HOST = 35.417
P125_BYTES = 88356464
MISTRAL_PRIV_BYTES = 1.286e9
TINY_RECEIPT = 2816472

# committed values per PERMUTATION, per the literature check (sources.md)
PERM_VALUES = {"Poseidon2 w12 r8": 118, "RescuePrimeOpt w12 r8": 96,
               "Monolith64 w12 r8": 480, "Tip5 w16 r10": 380}
PERM_RATE = {"Poseidon2 w12 r8": 8, "RescuePrimeOpt w12 r8": 8,
             "Monolith64 w12 r8": 8, "Tip5 w16 r10": 10}
PERM_LOOKUPS = {"Poseidon2 w12 r8": 0, "RescuePrimeOpt w12 r8": 0,
                "Monolith64 w12 r8": 192, "Tip5 w16 r10": 160}

say("=== 1. per absorbed field element, corrected against the literature ===")
say(f"{'design':24} {'perm vals':>10} {'rate':>5} {'vals/elt':>9} "
    f"{'lk/elt':>7}   draft sec 2.7 (tree-doubled)")
DRAFT27 = {"Poseidon2 w12 r8": (29.5, 0), "RescuePrimeOpt w12 r8": (42, 0),
           "Monolith64 w12 r8": (38, 24), "Tip5 w16 r10": (30, 16)}
for d, v in PERM_VALUES.items():
    r = PERM_RATE[d]
    say(f"{d:24} {v:>10} {r:>5} {v/r:>9.2f} {PERM_LOOKUPS[d]/r:>7.1f}   "
        f"{DRAFT27[d][0]} vals / {DRAFT27[d][1]} lk  "
        f"-> undoubled {DRAFT27[d][0]/2} vs {v/r:.2f}")
say()

say("=== 2. the tree factor is (1 + 1/k), not 2 ===")
for k in (1, 2, 4, 8, 16, 64):
    say(f"   k = {k:>3} permutations unrolled per leaf -> "
        f"overhead {1 + 1/k:.4f}   ({k} leaf plane families + one per level)")
say()


def cost(words, bpw, log_cols, design, k, layout_values=None):
    """layout_values overrides committed values per permutation (draft layouts)."""
    n_abs = words * bpw // 4
    pv = layout_values if layout_values is not None else PERM_VALUES[design]
    rate = PERM_RATE[design]
    leaves = max(1, ceil(n_abs / (rate * k)))
    depth = max(0, ceil(log2(leaves)))
    perms = k * leaves + max(0, leaves - 1)
    values = pv * perms
    data_rows = ceil(values / (1 << log_cols))
    families = k + depth
    sites = pv * families                      # one plane per committed value
    mask_rows = 2 * sites
    committed = (data_rows + mask_rows) * (1 << log_cols)
    proof = (data_rows + mask_rows) * BYTES_PER_ROW
    return dict(n_abs=n_abs, leaves=leaves, depth=depth, perms=perms,
                values=values, data_rows=data_rows, families=families,
                sites=sites, mask_rows=mask_rows, committed=committed,
                proof=proof)


say("=== 3. Mistral int16 endpoint: k sweep, Poseidon2 layout A ===")
say(f"{'k':>3} {'leaves':>8} {'lvls':>5} {'perms':>8} {'dataRows':>9} "
    f"{'sites':>6} {'maskRows':>9} {'committed':>12} {'proofMB':>8}")
for k in (1, 2, 4, 8, 16, 32):
    c = cost(512 * 4096, 2, 14, "Poseidon2 w12 r8", k)
    say(f"{k:>3} {c['leaves']:>8} {c['depth']:>5} {c['perms']:>8} "
        f"{c['data_rows']:>9} {c['sites']:>6} {c['mask_rows']:>9} "
        f"{c['committed']:>12} {c['proof']/1e6:>8.2f}")
say()

say("=== 4. corrected table: TWO external endpoints ===")
say(f"{'shape':22} {'design':16} {'k':>3} {'%words':>7} {'sec':>7} "
    f"{'%sec':>7} {'proofMB':>9} {'%bytes':>8}   [draft]")
for shape, words, bpw, lc, dw, ds, db, draft in (
        ("Mistral 8B public", 512 * 4096, 2, 14, PASS_WORDS, PASS_SECONDS,
         MISTRAL_PRIV_BYTES, "0.63% / 0.37 s / 8.78 MB / 0.68%"),
        ("125M 12L private", 512 * 768, 2, 14, P125_WORDS, P125_SECONDS_GPU,
         P125_BYTES, "4.29% / 0.20 s / 2.50 MB / 2.83%")):
    for design in ("Poseidon2 w12 r8", "RescuePrimeOpt w12 r8"):
        for k in (1, 4):
            c = cost(words, bpw, lc, design, k)
            com, pb = 2 * c["committed"], 2 * c["proof"]
            secs = com / WORDS_PER_SEC if dw == PASS_WORDS else (com / dw) * ds
            say(f"{shape:22} {design:16} {k:>3} {com/dw*100:>6.2f}% "
                f"{secs:>7.2f} {secs/ds*100:>6.2f}% {pb/1e6:>9.2f} "
                f"{pb/db*100:>7.2f}%   {draft if k == 1 and design.startswith('Pos') else ''}")
say()

say("=== 4b. LOWER BOUND of the band: keep the draft's own 128 flat sites, "
    "but count their mask rows in committed volume too ===")
for shape, words, lc, dw, ds, db in (
        ("Mistral 8B public", 512 * 4096, 14, PASS_WORDS, PASS_SECONDS,
         MISTRAL_PRIV_BYTES),
        ("125M 12L private", 512 * 768, 14, P125_WORDS, P125_SECONDS_GPU,
         P125_BYTES)):
    c = cost(words, 2, lc, "Poseidon2 w12 r8", 1)
    rows = c["data_rows"] + 2 * 128
    com, pb = 2 * rows * (1 << lc), 2 * rows * BYTES_PER_ROW
    secs = com / WORDS_PER_SEC if dw == PASS_WORDS else (com / dw) * ds
    say(f"   {shape:20} rows={rows:>5} committed={com:>11} "
        f"({com/dw*100:5.2f}% of words) +{secs:5.2f} s  "
        f"proof {pb/1e6:6.2f} MB ({pb/db*100:5.2f}%)")
say()

say("=== 5. tiny shape, ONE endpoint, receipt is 2,816,472 B ===")
for design in ("Poseidon2 w12 r8", "RescuePrimeOpt w12 r8"):
    for k in (1, 4):
        c = cost(512, 2, 8, design, k)
        say(f"   {design:22} k={k}: perms={c['perms']:>4} "
            f"dataRows={c['data_rows']:>4} sites={c['sites']:>5} "
            f"proof={c['proof']:>9,} B = {c['proof']/TINY_RECEIPT*100:6.1f}% "
            f"of the receipt   [draft layout A: 585,728 B = 20.8%]")
say()

say("=== 6. what the '+0.37 s' headline leaves out ===")
say("  (a) the gadget's OWN degree-7 zero-check, per endpoint at Mistral:")


def sumcheck_ops(perms, sboxes, form_terms, total_degree):
    per_point = sboxes * (form_terms + 4)
    return 2 * perms * per_point * (total_degree + 1)


for name, sboxes, terms in (("layout A (~130-term forms)", 118, 130),
                            ("layout C (<=34-term forms)", 238, 34)):
    c = cost(512 * 4096, 2, 14, "Poseidon2 w12 r8", 4)
    ops = sumcheck_ops(c["perms"], sboxes, terms, 8)
    say(f"      {name}: {ops:.2e} Goldilocks mul-adds; at 1e10..1e11 op/s "
        f"= {ops/1e11:.2f}..{ops/1e10:.2f} s per endpoint")
say(f"  (b) no GPU kernel exists above degree 4 (kernels.cu:601 '#define "
    f"SC_DEG 4').")
say(f"      host/GPU ratio measured on the private feed-forward at 12x512: "
    f"{P125_SECONDS_HOST/P125_SECONDS_GPU:.2f}x")
for design in ("Poseidon2 w12 r8", "RescuePrimeOpt w12 r8"):
    c = cost(512 * 768, 2, 14, design, 4)
    frac = 2 * c["committed"] / P125_WORDS
    say(f"      125M, {design}: {frac*100:.2f}% of words -> "
        f"+{frac*P125_SECONDS_GPU:.2f} s if on GPU, "
        f"+{frac*P125_SECONDS_HOST:.2f} s if the slot runs on the host "
        f"({frac*P125_SECONDS_HOST/P125_SECONDS_GPU*100:.0f}% of the "
        f"{P125_SECONDS_GPU} s pass)")
say("  (c) mask-row host generation: the MR1 lane found host mask cost = 53% "
    "of the repaired profile's added cost; not modelled here.")
say()

say("=== 7. D18's SHA-256 figure under the corrected tree factor ===")
comp = (512 * 4096 * 2) // 64
for label, lk_c, wd_c, tf in (
        ("record central, linear chain  (D18 basis)", 4000, 2500, 1.0),
        ("record central, x2 tree       (draft SO-7)", 4000, 2500, 2.0),
        ("record central, k=8 unrolled  (correct)", 4000, 2500, 1.125),
        ("record central, k=64 unrolled (correct)", 4000, 2500, 1.015625),
        ("drafter's own 12,800 lk, linear chain", 12800, 2500, 1.0)):
    lk = comp * lk_c * 2 * tf
    wd = comp * wd_c * 2 * tf
    secs = 5.555 * (lk / 2.296e9) + wd / WORDS_PER_SEC
    say(f"   {label:44s} {secs:6.2f} s = {secs/PASS_SECONDS*100:5.1f}% "
        f"of the public pass")
say()

with open(__file__.replace("corrected_model.py", "corrected_model.out"),
          "w") as f:
    f.write("\n".join(OUT) + "\n")
