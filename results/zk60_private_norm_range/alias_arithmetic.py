#!/usr/bin/env python3
"""Exact arithmetic for ZK60_PRIVATE_NORM_RANGE_OBLIGATION.md.

The half-p isqrt alias of obligation R09, transposed to the PRIVATE module's
byte-limb encoding (hashline/src/private_block/{layout,argument,witness}.rs).

Field: the 64-bit Goldilocks prime p = 2^64 - 2^32 + 1 (p = 1 mod 4).

The private block's norm relations at one row t (norm_a; norm_m identical with
xres1 / gamma_m / the A_DM family):

  (R1) dsq = d * d                                    argument.rs:587 mu[0]
  (R2) d   = l0 + 256 l1 + 65536 l2                   argument.rs:587 mu[1]
  (R3) 2d  = a1 + a2                                  argument.rs:587 mu[2]
  (R4) dsq + a1 - Ceps = SS(r_t)                      argument.rs:591 nu[0]
  every l_k in [0, 256) by the U8 lookup byte(A_LIMB) layout.rs:314

and the division at each element (t, i):

  (C0) 2 Cn g x + 2^tn d - 2^(tn+1) y d - rho = 0      argument.rs:726
  (C1) sigma + rho + 1 - 2^(tn+1) d = 0                argument.rs:727
  rho, sigma in [0, 2^29) EXACTLY: four byte limbs whose top limb is also
  looked up as 8*l3, so l3 < 32                        layout.rs:320-323

Run: python3 alias_arithmetic.py
"""

P = (1 << 64) - (1 << 32) + 1
TN = 11
CN = 1024
CEPS = 1
WRHO = 29
WRHO_S = 14
LIMBS = 3          # byte limbs on each of d, a1, a2
RLIMBS = 4         # byte limbs on each of rho, sigma (top one exact-windowed)


def isqrt(n):
    return __import__("math").isqrt(n)


def out(s=""):
    print(s)


out("p          = %d = 2^64 - 2^32 + 1" % P)
out("p mod 4    = %d" % (P % 4))
out("(p-1)/2    = %d = 2^63 - 2^31" % ((P - 1) // 2))
out("(p-1)/4    = %d = 2^62 - 2^30" % ((P - 1) // 4))
inv2 = pow(2, P - 2, P)
inv4 = pow(4, P - 2, P)
out("inv(2)     = %d" % inv2)
out("inv(4)     = %d   (= p - (p-1)/4: %s)" % (inv4, inv4 == P - (P - 1) // 4))
out()

# ---------------------------------------------------------------- 1. the alias family
out("=" * 78)
out("1. WHICH d SATISFY (R3) WITHOUT BEING SMALL")
out("=" * 78)
out("(R3) with a1, a2 in [0, 2^%d) gives 2d = s over Z for some s in [0, 2^%d)," % (8 * LIMBS, 8 * LIMBS + 1))
out("    so d = s/2 in F_p: s even -> d = s/2 < 2^%d; s odd -> d = (s+p)/2 = k + (p-1)/2" % (8 * LIMBS))
out("    with k = (s+1)/2 in [0, 2^%d). That odd branch IS the R09 half-p alias." % (8 * LIMBS))
out()

# the alias's square, symbolically and numerically
out("For d = k + (p-1)/2:  d^2 = k^2 - k + inv(4)  (mod p)")
bad = []
for k in [0, 1, 2, 3, 7, 1024, 131071, 131072, (1 << 24) - 1]:
    d = (k + (P - 1) // 2) % P
    lhs = d * d % P
    rhs = (k * k - k + inv4) % P
    if lhs != rhs:
        bad.append(k)
out("    checked for k in {0,1,2,3,7,1024,131071,131072,2^24-1}: %s" % ("ALL AGREE" if not bad else "MISMATCH %s" % bad))
out()
out("(R4) then forces a1 = SSe - d^2 = SSe - k^2 + k - inv(4) = SSe + (p-1)/4 + k - k^2  (mod p)")
out("     with SSe = Ceps + sum_i x_i^2.")
out()

# ---------------------------------------------------------------- 2. can a1 ever be a byte-limb value?
out("=" * 78)
out("2. CAN THE ALIAS'S a1 LIE IN THE BYTE-LIMB RANGE [0, 2^%d)?" % (8 * LIMBS))
out("=" * 78)


def alias_a1(k, sse):
    d = (k + (P - 1) // 2) % P
    return (sse - d * d) % P


# the honest SSe window of the fixed geometry: d = 16, x int16, Ceps = 1
SSE_MAX_FIXED = CEPS + 16 * 32768 ** 2
log2 = __import__("math").log2
out("fixed geometry (T32 d16, x int16): SSe <= %d = 2^%.3f" % (SSE_MAX_FIXED, log2(SSE_MAX_FIXED)))
out()
out("THE CONSTRAINT IS JOINT. (R3) with a1, a2 < 2^(8 na) bounds k: a1 + a2 = 2k - 1")
out("over Z, so k < 2^(8 na). (R4) then fixes a1, which must land in [0, 2^(8 na))")
out("as well. With na = %d (three byte limbs) k < 2^%d, and for every such k" % (LIMBS, 8 * LIMBS))
out("k^2 <= 2^%d is negligible against (p-1)/4 = 2^62 - 2^30:" % (2 * 8 * LIMBS))
kstar = isqrt((P - 1) // 4)
out()
kmax = 1 << (8 * LIMBS)
worst = None
for sse in [1, SSE_MAX_FIXED]:
    m = None
    for k in [0, 1, 2, kmax // 2, kmax - 2, kmax - 1]:
        v = alias_a1(k, sse)
        if m is None or v < m[1]:
            m = (k, v)
    out("   SSe = %-12d -> min a1 over k in [0, 2^%d) = %d = 2^%.3f  at k = %d" % (sse, 8 * LIMBS, m[1], log2(m[1]), m[0]))
    worst = m
out()
out("=> at the fixed profile the alias's a1 is never below 2^%.1f, so it has NO" % log2(worst[1]))
out("   three-byte-limb encoding (window 2^%d). The a1 / a2 limbs alone refuse the" % (8 * LIMBS))
out("   whole family here, independently of (R2) -- but see section 6: that is a")
out("   WIDTH argument (it depends on k < 2^24), while (R2) is not.")
out()

# ---------------------------------------------------------------- 3. the alias's division block
out("=" * 78)
out("3. WHAT THE ALIAS DOES TO THE DIVISION RELATIONS (C0), (C1)")
out("=" * 78)
k = 1234
d = (k + (P - 1) // 2) % P
den = (1 << (TN + 1)) * d % P
dv = (1 << TN) * d % P
out("k = %d, d = k + (p-1)/2" % k)
out("2^(tn+1) d mod p = %d  = 2^%d (2k - 1)  : %s" % (den, TN, den == (1 << TN) * (2 * k - 1)))
out("2^tn     d mod p = %d  = 2^%d (2k - 1)  : %s" % (dv, TN - 1, dv == (1 << (TN - 1)) * (2 * k - 1)))
out()
out("so (C0)/(C1) become an EXACT division by den' = 2^%d (2k-1) = 2^%d (k - 1/2)," % (TN, TN + 1))
out("with the correct rounding bias den'/2. The alias is a norm with a HALF-INTEGER")
out("denominator k - 1/2 in place of the integer k. rho, sigma stay in [0, den')," )
out("so the exact 29-bit remainder window does NOT refuse it: den' < den <= 2^29.")
out()
out("CONTRAST with attention.rs (R09): there tn = 11 forces k ~ 2^31 (a1 must fit")
out("2^32, not 2^24), den' ~ 2^42, y = 0 on every element, and the remainders ~2^42")
out("are what the two 16-bit limbs refuse. Here k is free to be small, so the")
out("remainder width is NOT the thing that excludes the alias.")
out()

# ---------------------------------------------------------------- 4. honest D and limb counts
out("=" * 78)
out("4. THE HONEST DENOMINATOR AT EACH GEOMETRY, AND THE LIMBS IT NEEDS")
out("=" * 78)
out("%-34s %-14s %-9s %-7s %-7s %s" % ("geometry", "max SSe", "max D", "log2 D", "limbs", "2^(tn+1) D"))
rows = [
    ("d=16   x int16 (FIXED PROFILE)", 16, 32768),
    ("d=4096 x int16", 4096, 32768),
    ("d=4096 x int24", 4096, 1 << 23),
    ("d=2048 x int24", 2048, 1 << 23),
    ("d=8192 x int24", 8192, 1 << 23),
]
for name, width, xmax in rows:
    sse = CEPS + width * xmax ** 2
    dmax = isqrt(sse)
    nl = max(1, (dmax.bit_length() + 7) // 8)
    den = dmax << (TN + 1)
    out("%-34s 2^%-12.2f %-9d 2^%-5.2f %-7d 2^%.2f" % (name, __import__("math").log2(sse), dmax, __import__("math").log2(dmax), nl, __import__("math").log2(den)))
out()
out("a1 <= 2D, so a1 needs the same limb count as 2D:")
for name, width, xmax in rows:
    sse = CEPS + width * xmax ** 2
    dmax = isqrt(sse)
    a1max = 2 * dmax
    nl = max(1, (a1max.bit_length() + 7) // 8)
    out("   %-34s a1 <= %d = 2^%.2f -> %d byte limbs" % (name, a1max, __import__("math").log2(a1max), nl))
out()

# ---------------------------------------------------------------- 5. the no-wrap boundary
out("=" * 78)
out("5. THE NO-WRAP BOUNDARY: HOW MANY LIMBS ON D ARE SAFE")
out("=" * 78)
out("(R4) is an identity over Z only if d^2 + a1 < p. With n byte limbs on d and")
out("on a1: d <= 2^(8n) - 1 and a1 <= 2^(8n) - 1, so the worst case is")
out("(2^(8n)-1)^2 + 2^(8n)-1:")
for n in [3, 4, 5]:
    m = (1 << (8 * n)) - 1
    worst = m * m + m
    out("   n = %d: (2^%d-1)^2 + (2^%d-1) = %d  vs p = %d  -> %s" % (n, 8 * n, 8 * n, worst, P, "SAFE" if worst < P else "WRAPS"))
out()
m = (1 << 32) - 1
out("n = 4 is exact at the boundary: (2^32-1)^2 = p - 2^32 and a1 <= 2^32 - 1,")
out("so d^2 + a1 <= p - 1. One more limb, or an a1 window wider than 2^32, wraps.")
out("(a1 <= 2d is the other bound, and at n = 4 it is the weaker one only for d > 2^31.)")
out()

# ---------------------------------------------------------------- 6. the general admission test
out("=" * 78)
out("6. GENERAL ADMISSION TEST FOR THE ALIAS (any limb counts)")
out("=" * 78)
out("With nd byte limbs on d and na on a1, a2, the alias needs BOTH:")
out("   (i)  d = k + (p-1)/2 in [0, 2^(8 nd))    -- (R2), the DIRECT range fact")
out("   (ii) k < 2^(8 na) and a1 = SSe + (p-1)/4 + k - k^2 mod p in [0, 2^(8 na))")
out()
out("(ii) alone, scanning every k that (R3) admits at that na (the minimum of a1")
out("     over k is attained at the k nearest isqrt((p-1)/4 + SSe) that (R3) allows):")
for na in [2, 3, 4, 5, 6, 7]:
    lim = 1 << (8 * na)
    kmx = lim  # (R3): a1 + a2 = 2k - 1 < 2^(8 na + 1)
    # a1(k) = SSe + (p-1)/4 + k - k^2 mod p is minimised (as a canonical residue)
    # by the admissible k closest to isqrt((p-1)/4 + SSe) from below.
    cands = [0, 1, kmx - 1]
    root = isqrt((P - 1) // 4 + SSE_MAX_FIXED)
    cands += [k for k in range(max(0, root - 3), root + 4) if k < kmx]
    best = min((alias_a1(k, SSE_MAX_FIXED), k) for k in cands)
    out("   na = %d: window 2^%-3d, k < 2^%-3d -> min a1 = 2^%-6.2f  %s"
        % (na, 8 * na, 8 * na, log2(best[0]) if best[0] else 0.0, "ADMITS (a1 fits)" if best[0] < lim else "refuses"))
out()
out("So (ii) stops refusing at na = 4: with FOUR byte limbs on a1 and a2 the")
out("alias's own a1 ~ 2^30 fits (at k in a narrow band around isqrt((p-1)/4) =")
out("2^31), and the isqrt WITNESS no longer excludes it. na = 4 is exactly what")
out("an int24 residual class at width 4096 needs (section 4).")
out()
out("(i) refuses at EVERY expressible nd: (p-1)/2 = 2^63 - 2^31, so d >= 2^62 for")
out("every k, while nd <= 7 gives a window of at most 2^56 (nd = 8 is not")
out("expressible: 2^64 > p, and the no-wrap bound of section 5 caps nd at 4).")
for nd in [3, 4, 5, 6, 7]:
    out("   nd = %d: window 2^%-3d -> %s" % (nd, 8 * nd, "refuses (d >= 2^62)"))
out()
out("=> (R2), the direct byte-limb range fact on d, is the STRUCTURAL exclusion:")
out("   it holds at every limb count the field admits. The a1 / a2 limbs are a")
out("   SECOND exclusion that holds at the FIXED profile (na = 3) and LAPSES at")
out("   na = 4, i.e. as soon as the geometry is widened to int24 / 4096.")
out()

out("-" * 78)
out("6b. THE THIRD EXCLUSION: THE EXACT REMAINDER WINDOW, AND ITS MARGIN")
out("-" * 78)
out("(C1) reads sigma + rho + 1 = 2^(tn+1) d. With rho, sigma in [0, 2^wrho)")
out("EXACTLY, the right side is an integer <= 2^(wrho+1) - 1, so the alias needs")
out("   2^tn (2k - 1) <= 2^(wrho+1) - 1,  i.e.  k <~ 2^(wrho - tn).")
out("The alias's k is pinned to a band around isqrt((p-1)/4 + SSe) ~ 2^31 by (ii),")
out("so (C1) refuses it whenever  wrho - tn < 31, i.e. wrho < tn + 31.")
out("An honest profile needs wrho = tn + 1 + ceil(log2 Dmax). So the remainder")
out("window excludes the alias iff  ceil(log2 Dmax) <= 29, i.e. Dmax <= 2^29.")
out()
out("%-34s %-12s %-9s %-9s %s" % ("geometry", "Dmax", "wrho_min", "alias k", "(C1) verdict"))
for name, width, xmax in rows:
    sse_g = CEPS + width * xmax ** 2
    dmax = isqrt(sse_g)
    wrho_min = TN + 1 + (dmax - 1).bit_length()
    kband = isqrt((P - 1) // 4 + sse_g)
    admits = (1 << TN) * (2 * kband - 1) <= (1 << (wrho_min + 1)) - 1
    out("%-34s 2^%-9.2f %-9d 2^%-7.3f %s" % (name, log2(dmax), wrho_min, log2(kband), "ADMITS the alias" if admits else "refuses (margin %.2f bits)" % (log2((1 << TN) * (2 * kband - 1)) - (wrho_min + 1))))
out()
out("=> at int24 / 4096 the remainder window still refuses, by about one bit.")
out("   Both secondary exclusions sit within one or two bits of lapsing there.")
out("   Only (R2) has real margin, and only (R2) is a fact about d itself.")
out()

# ---------------------------------------------------------------- 7. the widths that ARE coincidences
out("=" * 78)
out("7. THE WIDTH COINCIDENCES THAT REMAIN (completeness edges, zero margin)")
out("=" * 78)
dmax_fixed = isqrt(SSE_MAX_FIXED)
den_fixed = dmax_fixed << (TN + 1)
out("norm remainder: honest den = 2^(tn+1) D <= 2^%d * %d = %d = 2^%.0f," % (TN + 1, dmax_fixed, den_fixed, log2(den_fixed)))
out("   and rho <= den - 1 < 2^%d, the EXACT window of the four limbs. ZERO margin:" % WRHO)
out("   D = %d = 2^17 is attained on a saturated int16 row (SSe = 16*2^30 + 1)." % dmax_fixed)
den_4096_i16 = isqrt(CEPS + 4096 * 32768 ** 2) << (TN + 1)
out("   At d = 4096 / int16, den reaches 2^%.0f; at d = 4096 / int24, 2^%.0f." % (log2(den_4096_i16), log2(isqrt(CEPS + 4096 * (1 << 46)) << (TN + 1))))
out("   wrho = 29 would refuse HONEST rows at either: it must grow with the width.")
out("   (C1) is a BACKSTOP range fact on D, but only GIVEN (R2): with d already")
out("   an integer below 2^24, 2^(tn+1) d < 2^36 < p, so rho + sigma + 1 <=")
out("   2^(wrho+1) - 1 forces d < 2^%d here. WITHOUT (R2), (C1) alone admits the" % (WRHO + 1 - (TN + 1)))
out("   whole 12-adic family d = s/2^(tn+1) mod p, s < 2^(wrho+1); intersecting")
out("   it with (R3) leaves exactly {d small} union {the half-p family}.")
out()
sum_max = 32 * (1 << 9)
out("softmax denominator: Sum = sr + sg + 1 with sr, sg in [0, 2^%d) EXACTLY" % WRHO_S)
out("   (byte + 4*l1 lookups, layout.rs:362-363). Honest Sum <= T * 2^fE = %d = 2^%.0f," % (sum_max, log2(sum_max)))
out("   so sg = Sum - 1 - sr <= %d < 2^14. ZERO margin again." % (sum_max - 1))
sum_4096 = 4096 * 512
out("   At T = 4096, Sum reaches %d = 2^%.0f, so wrho_s must be >= %d." % (sum_4096, log2(sum_4096), int(log2(sum_4096))))
out("   No-wrap there: p_soft*Sum + sr <= 2^10 * 2^%.0f + 2^%d = 2^%.1f << p, safe." % (log2(sum_4096), int(log2(sum_4096)), 10 + log2(sum_4096) + 0.0))
out("   Sum itself is NEVER looked up: its only range fact is (C3). That is the")
out("   same shape as D's (R3) -- and Sum has no direct limb decomposition, so it")
out("   has the alias structure D would have without (R2). It is saved by the")
out("   coefficient being 1, not 2^(tn+1): Sum = sr + sg + 1 admits no halving.")
out()
out("requantisation remainders: every one is byte + scaled(byte, 2^(8-s)) = an")
out("   EXACT [0, 2^s) window, not a limb multiple (layout.rs:324,334,340,344-348,")
out("   :360-363). No R10-style slack exists in this module.")
out()

# ------------------------------------------------- 8. the concrete tamper witness
out("=" * 78)
out("8. THE CONCRETE ALIAS WITNESS THE RUST TAMPER WRITES (one row)")
out("=" * 78)
out("Plane values are i64 and reach the field through Fp::from_i64 (protocol.rs:286),")
out("so a field element v is written as v if v < 2^63 and as v - p otherwise.")
out("Every value the alias needs must be i64-representable:")


def to_plane(v):
    return v if v < (1 << 63) else v - P


k = 131072  # a saturated honest denominator, the largest the fixed profile reaches
sse = CEPS + 16 * 32768 ** 2
d = (k + (P - 1) // 2) % P
dsq = d * d % P
a1 = (sse - dsq) % P
a2 = (2 * d - a1) % P
for name, v in [("d", d), ("dsq", dsq), ("a1", a1), ("a2", a2)]:
    pl = to_plane(v)
    ok = -(1 << 63) <= pl < (1 << 63) and pl % P == v % P
    out("   %-4s = %-22d -> plane i64 %-22d %s" % (name, v, pl, "ok" if ok else "NOT REPRESENTABLE"))
out()
out("with the quotient y LEFT HONEST, (C0) fixes rho and (C1) fixes sigma:")
out("   rho   = 2 Cn g x + 2^tn d - 2^(tn+1) y d   (mod p)")
out("   sigma = 2^(tn+1) d - 1 - rho               (mod p)")
out("and 2^tn d = 2^(tn-1)(2k-1), 2^(tn+1) d = 2^tn (2k-1) are SMALL integers, so")
out("rho = rho_honest + 2^tn y - 2^(tn-1) and sigma = sigma_honest - 2^tn y - 2^(tn-1)")
out("stay i64-small. Worked example (k = %d, y = 7, rho_honest = 1000):" % k)
y, rho_h = 7, 1000
num_shift = (1 << TN) * (2 * k - 1)
rho = (rho_h + (1 << TN) * y - (1 << (TN - 1))) % P
sigma = (num_shift - 1 - rho) % P
out("   den' = 2^tn (2k-1) = %d ; rho = %d ; sigma = %d ; rho+sigma+1 = %d" % (num_shift, rho, sigma, rho + sigma + 1))
out("   (C1) holds: %s" % (rho + sigma + 1 == num_shift))
out()
out("NOTHING downstream of the norm changes: y, and therefore the whole rest of the")
out("block, is untouched. The alias witness differs from the honest one on exactly")
out("d, dsq, a1, a2, their limbs, rho and sigma.")
