#!/usr/bin/env python3
"""R-2 part 1: worst-case magnitude of every constrained integer expression of
the private attention relation, from the ENFORCED ranges only (the byte-limb
lookups of layout.rs plus the identities of argument.rs::define), against the
note's claim "< 2^52" and the Goldilocks modulus p = 2^64 - 2^32 + 1.

Every bound is the maximum of |expression| over the declared ranges, computed
term by term (a sum of |coefficient| * max|factor|), i.e. an upper bound that
holds for ANY witness the verifier accepts, honest or not.

Read-only.
"""

P = (1 << 64) - (1 << 32) + 1
CLAIM = 1 << 52

# ---- calibration (layout.rs:39-52, causal_oracle.rs:84-158, kernel calib) ----
T, D, H, DH, KV = 32, 16, 2, 8, 8
TN, CN, CEPS, WRHO = 11, 1024, 1, 29
SH_QKV, SH_ROPE, SH_S, SH_O, SH_AO = 7, 7, 6, 9, 7
F_E, F_P, F_RO, WRHO_S = 9, 9, 7, 14

# ---- enforced magnitudes -----------------------------------------------------
I8W = 128           # |w| for an i8 weight / gain (i8 spans -128..127)
I8N = 127           # |v| for the attention subset [-127,127]  (sym() lookup)
I16 = 32768         # |x|, |ao|, |xres1| for the int16 class    (two byte limbs)
D24 = (1 << 24) - 1  # D, a1, a2 < 2^24                          (three byte limbs)
RHO29 = (1 << 29) - 1  # norm rho, sigma < 2^29                  (4 limbs, 8*l3 in U8)
R7 = 64             # |requant remainder| at shift 7
R6 = 32             # |requant remainder| at shift 6
R9 = 256            # |requant remainder| at shift 9
PMAX = (1 << 10) - 1  # softmax p < 2^10                         (l0,l1,64*l1 in U8)
RS14 = (1 << 14) - 1  # softmax rho_s, sigma_s < 2^14            (l0,l1,4*l1 in U8)
SUMMAX = 2 * RS14 + 1  # Sum = sigma + rho + 1 <= 2^15 - 1       (c3 of SC_SZC)
EMAX = 1 << F_E     # exp table entries lie in [0, 2^9]          (public validation)
DELTA = 255         # delta in [0,256)                           (exp lookup key)
MXMAX = DELTA + I8N  # |row max| <= 382 (derived: MX = delta_j + masked_j)

rows = []


def add(name, where, bound, detail):
    rows.append((name, where, bound, detail))


# 1. RMSNorm: the sum of squares identity  D^2 + a1 - ceps = sum_i x_i^2
add("norm SS:  D^2 + a1 - ceps - sum_i x_i^2",
    "argument.rs:536-537 (zc), witness.rs:114-121",
    D24 * D24 + D24 + CEPS + D * I16 * I16,
    f"D^2<=({D24})^2, a1<2^24, sum of {D} squares of |x|<=2^15")

# 2. the three isqrt constraints
add("norm isqrt: Dsq - D*D", "argument.rs:536 (mu0)", D24 * D24 + D24 * D24, "both < 2^48")
add("norm isqrt: D - (l0+256l1+65536l2)", "argument.rs:536 (mu1)", D24 + D24, "")
add("norm isqrt: 2D - a1 - a2", "argument.rs:536 (mu2)", 2 * D24 + 2 * D24, "")

# 3. the rounded-division identity  2 cn g x + D 2^tn - y D 2^(tn+1) - rho = 0
add("norm div c0: 2*cn*g*x + 2^tn*D - 2^(tn+1)*y*D - rho",
    "argument.rs:632 (c0)",
    2 * CN * I8W * I16 + (1 << TN) * D24 + (1 << (TN + 1)) * I8N * D24 + RHO29,
    "|2 cn g x| <= 2^33; y in [-127,127]; D < 2^24")
add("norm div c1: sigma + rho + 1 - 2^(tn+1)*D",
    "argument.rs:633 (c1)", RHO29 + RHO29 + 1 + (1 << (TN + 1)) * D24, "")

# 4. int16 limb identities and the residual
add("c2/c3/c4: v + 32768 - (l0 + 256 l1)", "argument.rs:634-636",
    I16 + 32768 + 65535, "v is x, ao or xres1")
add("c5 residual 1: xres1 - x - ao", "argument.rs:637", 3 * I16, "all three shifts are 0")

# 5. Q/K/V matmul + requant (host relation of SC_QZC / SC_KVZC)
add("QKV matmul acc: sum_i y*W  (D terms)", "witness.rs:160-162",
    D * I8N * I8W, "")
add("QKV host: acc - (2^7*q8 + rql - 64)", "argument.rs:679 / 683 (host1)",
    D * I8N * I8W + (1 << SH_QKV) * I8N + R7, "")

# 6. RoPE
add("RoPE: C*x + S'*x_partner - 2^7*xr - r",
    "argument.rs:675 (rope)",
    2 * (1 << F_RO) * I8N + (1 << SH_ROPE) * I8N + R7,
    "|C|,|S'| <= 2^7 (public table validated in private_attention.rs:92-96)")

# 7. scores
add("score acc: sum_{i<8} qr8*kr8", "witness.rs:171", DH * I8N * I8N, "")
add("score host: acc - (2^6*s8 + rsl - 32)", "argument.rs:727 (host_s)",
    DH * I8N * I8N + (1 << SH_S) * I8N + R6, "")

# 8. softmax
add("softmax delta: MX - mask*(s8+127) + 127", "argument.rs:715 (delta)",
    MXMAX + 2 * I8N + 127, "MX bounded only via the exp lookup")
add("softmax c0: zsel^2 - zsel", "argument.rs:716", 2, "zsel is a field root of X^2-X")
add("softmax c1: zsel*delta", "argument.rs:717", DELTA, "")
add("softmax c2: 2^9*mask*E - p*Sum - rho_s", "argument.rs:718 (c2)",
    (1 << F_P) * EMAX + PMAX * SUMMAX + RS14, "THE tightest expression: see margin below")
add("softmax c3: sigma_s + rho_s + 1 - Sum", "argument.rs:719 (c3)",
    RS14 + RS14 + 1 + SUMMAX, "")
add("softmax c4: p - (l0 + 256 l1)", "argument.rs:720 (c4)", 2 * PMAX, "")

# 9. PV and the O requantisation
add("PV acc: sum_{j<32} p*v8", "witness.rs:233", T * PMAX * I8N, "")
add("PV host: acc - (2^9*o8 + ro - 256)", "argument.rs:680 (host2)",
    T * PMAX * I8N + (1 << SH_O) * I8N + R9, "")

# 10. output projection and the AO requantisation
add("Wo matmul acc: sum_i o8*Wo  (D terms)", "witness.rs:238", D * I8N * I8W, "")
add("Wo host: acc - (2^7*ao + ral - 64)", "argument.rs:642 (host)",
    D * I8N * I8W + (1 << SH_AO) * I16 + R7, "|2^7 ao| uses the a-priori int16 range")

# 11. endpoints
add("IO equality: x - endpoint word", "argument.rs:759", 2 * I16,
    "field equality; the integer content is A_X's own limb decomposition")

# 12. LogUp multiplicities (field-only, but must not wrap)
u8_lookups = 1 * 512 + 20 * 512 + 13 * 512 + 12 * 256 + 13 * 2048
add("LogUp U8 multiplicity (max possible)", "protocol.rs:275-282", u8_lookups,
    "every U8 lookup could land on one table entry")
add("LogUp exp multiplicity (max possible)", "protocol.rs:283-288", H * T * T, "")

print(f"p = 2^64 - 2^32 + 1 = {P}   (p/2 ~ 2^63)")
print(f"note's claim: every constrained integer expression < 2^52 = {CLAIM}")
print()
worst = 0
bad = []
for name, where, bound, detail in rows:
    lg = bound.bit_length()
    worst = max(worst, bound)
    flag = "OK " if bound < CLAIM else "OVER"
    if bound >= CLAIM:
        bad.append(name)
    print(f"{flag} |.| <= {bound:>22}  < 2^{lg:<3}  {name}")
    print(f"       {where}" + (f"   [{detail}]" if detail else ""))
print()
print(f"worst case over all expressions: {worst} < 2^{worst.bit_length()}"
      f"  ({'under' if worst < CLAIM else 'OVER'} the 2^52 claim, "
      f"ratio to p/2 = 2^{(P // 2).bit_length() - worst.bit_length()} headroom)")
print("expressions exceeding 2^52:", bad if bad else "none")
print()

# ---- the two tight spots, exactly -------------------------------------------
print("tight spot 1 - layout.rs:213 claims 'p Sum + rho < 2^25':")
tight = PMAX * SUMMAX + RS14
print(f"  with the ENFORCED bounds p <= {PMAX}, Sum = sigma+rho+1 <= {SUMMAX}, rho <= {RS14}:")
print(f"  p*Sum + rho <= {tight}   2^25 = {1 << 25}   margin {(1 << 25) - tight}"
      f"   -> {'holds' if tight < (1 << 25) else 'FAILS'}")
honest = PMAX * (T << F_E) + RS14
print(f"  with the comment's own 'Sum <= 2^14' (an honest-witness fact, Sum = sum of at most")
print(f"  {T} exp entries each <= 2^9): p*Sum + rho <= {honest} < 2^{honest.bit_length()}")
print()
print("tight spot 2 - layout.rs:206-207 claims 'D^2 + a1 < 2^49':")
dd = D24 * D24 + D24
print(f"  D,a1 < 2^24 -> D^2 + a1 <= {dd} < 2^{dd.bit_length()}  -> holds")
ss = D * I16 * I16 + CEPS
print(f"  and sum x^2 + ceps <= {ss} < 2^{ss.bit_length()} (the comment says < 2^35) -> holds")
print()
print("derived (not stated in the note): c1 forces sigma+rho+1 = D*2^(tn+1) <= 2^30-1,")
print(f"  so D <= {(2 * RHO29 + 1) // (1 << (TN + 1))} < 2^18, tighter than the 2^24 limb bound.")
print()
print(f"U8 lookups: {u8_lookups} (note says 47104 -> "
      f"{'matches' if u8_lookups == 47104 else 'MISMATCH'});"
      f" exp lookups: {H*T*T} (note says 2048 -> "
      f"{'matches' if H*T*T == 2048 else 'MISMATCH'})")
