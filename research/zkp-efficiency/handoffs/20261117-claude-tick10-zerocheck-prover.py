#!/usr/bin/env python3
"""Tick 10 arithmetic for handoffs/20261117-claude-tick10-zerocheck-prover.md.
Standard library only, reads no file, prints its tables. Everything here is DERIVED.

Part 1: small-value sumcheck cost model of Bagad-Dao-Domb-Thaler Theorem 4.1 (as I read it from the PDF text:
 ss mults (d-1)((d+1)/2)^(l0-1) N, sl mults d N, ll mults d^2/2^(l0+1) N), N = cube size.
 Units: one base x base multiplication (gl_mul) = 1. sl (ext x base) = 2, ll (ext x ext, Karatsuba) = 3.
 `cheap` = how many times cheaper a small-integer product is than one gl_mul (1 = no gain from smallness).
Part 2: share of the later-round slot kernel that is line values (lo + d (hi - lo)), counted from the
 dumped kernels and the A27 README, and the saving if d * x becomes additions.
"""
def svo(d, l0, cheap):
    ss = (d - 1) * ((d + 1) / 2) ** (l0 - 1) / cheap
    sl = d * 2
    ll = d * d / 2 ** (l0 + 1) * 3
    return ss + sl + ll

print("Part 1: cost per cube point (gl_mul units) of one degree-d product of base tables, rounds after the first")
print("        baseline = l0 = 1 (round 1 in the base field, the rest in Fp2: what the slot kernels do today)")
for d in (3, 4, 5):
    for cheap in (1, 4, 16):
        costs = {l0: svo(d, l0, cheap) for l0 in range(1, 7)}
        best = min(costs, key=costs.get)
        print(f"d={d} cheap={cheap:2d}: " + "  ".join(f"l0={k}:{v:6.1f}" for k, v in costs.items()) +
              f"  -> best l0={best}, gain over l0=1: {100 * (1 - costs[best] / costs[1]):4.1f}%")

print()
print("Part 2: line values in the later-round kernel")
# k_sc_round of slot 14 (dump slot14_shieldstral_r13_a26.metal, pre-A27): 116 f2_mul, 77 f2_mulb  (COUNTED)
body_pre = 116 * 3 + 77 * 2
print("slot 14 later-round body, gl_mul per evaluation point, pre-A27 (116 f2_mul x3 + 77 f2_mulb x2):", body_pre)
tables = 64
points = 3          # d = 2, 3, 4 need a multiplication; d = 0 is lo, d = 1 is skipped (recovered from the claim)
line_mul = tables * 2 * points   # ln_ext: f2_mulb(h - l, dd) = 2 gl_mul per table per point
body_total_pre = body_pre * (points + 1)
print("line-value gl_mul per pair (64 ext tables, 3 points):", line_mul)
print("pre-A27 share of the multiplications: %.1f%%" % (100 * line_mul / (line_mul + body_total_pre)))
# A27: slot 14 later rounds 43 -> 16 ms (metal_slot.rs:159-161, README). If the removed 27 ms were all body and the
# line values/loads (about a fifth of 43 ms, M4g) stayed, the line+load part is 8.6 of 16 ms.
print("line values + loads after A27, if they stayed at one fifth of 43 ms: %.1f of 16 ms = %.0f%%" % (43 / 5, 100 * 43 / 5 / 16))
# alternative: scale the body by 16/43 and keep the line values
body_post = body_pre * 16 / 43
sh = line_mul / (line_mul + body_post * (points + 1))
print("post-A27 share of multiplications, body scaled by 16/43: %.0f%%" % (100 * sh))
print()
print("saving if the line value's d * x is done with additions (cost of a gl_mul = m gl_add equivalents)")
for m in (3, 4, 6):
    # per table-point: 2 sub + 2 mul + 2 add  ->  2 sub + (1.5 add avg per component) *2 + 2 add
    old = 2 + 2 * m + 2
    new = 2 + 2 * 1.5 + 2
    line_frac_of_kernel = {}
    # kernel cost in add-equivalents per pair: line part + body part (body: 1 mul ~ m adds plus ~0.85 add per mul, COUNTED 430/502)
    for label, bodymul in (("pre-A27", body_total_pre), ("post-A27 (scaled)", body_post * (points + 1))):
        body_cost = bodymul * (m + 0.85)
        line_cost = tables * points * old
        saved = tables * points * (old - new)
        print(f"  m={m} {label:18s}: kernel {line_cost + body_cost:8.0f} add-eq, line part {100 * line_cost / (line_cost + body_cost):4.1f}%, saved {100 * saved / (line_cost + body_cost):4.1f}%")
