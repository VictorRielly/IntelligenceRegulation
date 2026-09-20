#!/usr/bin/env python3
"""Independent recomputation of every number in ZK60_PRIVATE_BLOCK_125M_LAYOUT.md.

Exact integer arithmetic only (Python ints); floats used only to print log2.
Nothing here is run against the Rust code; every rule is transcribed from the
source with the file:line noted in a comment.
"""
import math
from fractions import Fraction

def lg(x):
    return math.log2(x) if x > 0 else float('-inf')

out = []
def p(*a):
    s = " ".join(str(x) for x in a)
    out.append(s)
    print(s)

def hdr(t):
    p("")
    p("=" * 72)
    p(t)
    p("=" * 72)

# ---------------------------------------------------------------- shapes
TOY = dict(T=32, D=16, H=2, HKV=1, DH=8, F=16, LOG_N=8, INV_RATE=8, Q=256)
# 125M: d 768 -> d_pad 1024, H 12 -> H_pad 16, HKV 4, dh 64, f 2048, T 512
M125 = dict(T=512, D=1024, Dtrue=768, H=16, Htrue=12, HKV=4, DH=64, F=2048,
            LOG_N=14, INV_RATE=4, Q=256)

hdr("1. Domain logs and rows (layout.rs:98-106, :537-539 rows_of)")

def domlogs(s):
    T, D, H, HKV, DH, F = s['T'], s['D'], s['H'], s['HKV'], s['DH'], s['F']
    KV = HKV * DH
    return {
        'T':   int(lg(T)),
        'Ht':  int(lg(H * T)),
        'L':   int(lg(16 * T)),
        'D':   int(lg(T * D)),
        'Q':   int(lg(T * H * DH)),
        'Kv':  int(lg(T * KV)),
        'S':   int(lg(H * T * T)),
        'F':   int(lg(T * F)),
        'Tab': 8,
    }

for name, s in (("toy", TOY), ("125M", M125)):
    dl = domlogs(s)
    p(name, dl)
    for k, v in dl.items():
        assert 1 << v == {'T': s['T'], 'Ht': s['H']*s['T'], 'L': 16*s['T'],
                          'D': s['T']*s['D'], 'Q': s['T']*s['H']*s['DH'],
                          'Kv': s['T']*s['HKV']*s['DH'], 'S': s['H']*s['T']*s['T'],
                          'F': s['T']*s['F'], 'Tab': 256}[k], (name, k)

p("125M padding waste (true/padded):")
p("  Ht 12*512=6144 -> 8192   x%.4f" % (8192/6144))
p("  L  9*512=4608  -> 8192   x%.4f" % (8192/4608))
p("  D  512*768=393216 -> 524288 x%.4f" % (524288/393216))
p("  Q  512*12*64=393216 -> 524288 x%.4f" % (524288/393216))
p("  S  12*512*512=3145728 -> 4194304 x%.4f" % (4194304/3145728))
p("  Kv 512*4*64=131072 -> 131072 x1.0000 (no pad)")
p("  F  512*2048=1048576 -> 1048576 x1.0000 (no pad)")

hdr("2. A / H row totals, the module's own rule")

# A plane counts per domain (layout.rs:114-214); +2 Dom::S planes at 125M (3rd
# limb of rho_s and sigma_s, section 3.4 of the draft)
A_PLANES_TOY = {'T': 4, 'Ht': 2, 'L': 2, 'D': 35, 'Q': 7, 'Kv': 6, 'S': 11, 'F': 11, 'Tab': 3}
A_PLANES_125 = dict(A_PLANES_TOY); A_PLANES_125['S'] = 13

def rows_of(log, LOG_N):
    n = 1 << LOG_N
    return max(1, -((-(1 << log)) // n))   # div_ceil

def a_rows(shape, planes, sites):
    dl = domlogs(shape)
    data = sum(c * rows_of(dl[d], shape['LOG_N']) for d, c in planes.items())
    return data, data + 2 * sites + 2

d_toy, r_toy = a_rows(TOY, A_PLANES_TOY, 120)
p("toy  A: data", d_toy, "rows", r_toy, " (layout.rs:525,523 assert 213 / 455)")
assert (d_toy, r_toy) == (213, 455)
d125, r125 = a_rows(M125, A_PLANES_125, 122)
p("125M A: data", d125, "rows", r125, "   draft says 5,435 / 5,681")

# ---- lookups per domain, layout.rs:310-368, and the effect of NORM_WRHO ----
def dom_lookups(wrho, extra_class_lookups=0, sig_limbs=2):
    """count of Lk entries per domain; wrho selects whether the four
    scaled(rho_top, 1<<(32-wrho)) lookups are redundant (coefficient 1)."""
    redundant = 4 if wrho == 32 else 0
    D = 38 - redundant + extra_class_lookups
    S = 13 + (2 if sig_limbs == 3 else 0)
    return {'L': 2, 'D': D, 'F': 9, 'Q': 13, 'Kv': 12, 'S': S}

lk_toy = dom_lookups(29)
p("toy lookups per domain:", lk_toy, "(code: L2 D38 F9 Q13 Kv12 S13)")
assert lk_toy == {'L': 2, 'D': 38, 'F': 9, 'Q': 13, 'Kv': 12, 'S': 13}
dl_toy = domlogs(TOY)
per = [lk_toy[d] * (1 << dl_toy[d]) for d in ['L', 'D', 'F', 'Q', 'Kv', 'S']]
p("toy per-domain U8 totals:", per, "sum", sum(per),
  " (layout.rs:745 declares [1024,19456,4608,6656,3072,26624] = 61440)")
assert per == [1024, 19456, 4608, 6656, 3072, 26624] and sum(per) == 61440

def helpers(lk):
    return {d: -(-lk[d] // 2) for d in lk}

p("toy helpers:", helpers(lk_toy), "(layout.rs:371-381: L1 D19 F5 Q7 Kv6 S7)")
assert helpers(lk_toy) == {'L': 1, 'D': 19, 'F': 5, 'Q': 7, 'Kv': 6, 'S': 7}

hdr("2b. H rows at 125M, two scenarios")

def h_rows(shape, lk, sites_extra_exp_act=2):
    """H planes: one per U8 helper per domain, + H_SEXP (S), + H_FACT (F),
    + 3 table helpers + H_U on Dom::Tab. layout.rs:223-252."""
    hp = helpers(lk)
    planes = {'L': hp['L'], 'D': hp['D'], 'Q': hp['Q'], 'Kv': hp['Kv'],
              'S': hp['S'] + 1, 'F': hp['F'] + 1, 'Tab': 4}
    dl = domlogs(shape)
    data = sum(c * 2 * rows_of(dl[d], shape['LOG_N']) for d, c in planes.items())
    sites = sum(planes.values()) - 1        # H_U's slot has 1 site too...
    # sites, exactly as H_SITES: LZC 1, DZC hp['D'], QZC hp['Q'], KVZC hp['Kv'],
    # SZC hp['S']+1, FZC hp['F']+1, TAB 3, ZS 1
    sites = 1 + hp['D'] + hp['Q'] + hp['Kv'] + (hp['S'] + 1) + (hp['F'] + 1) + 3 + 1
    return planes, data, sites, data + 2 * sites + 2

pl, hd, hs, hr = h_rows(TOY, lk_toy)
p("toy  H planes", sum(pl.values()), "data", hd, "sites", hs, "rows", hr,
  " (layout.rs:526,524 assert 280 / 384; H_SITES sums to 51)")
assert (hd, hs, hr) == (280, 51, 384)

# scenario A: int16 input class kept -> NORM_WRHO 32 -> four lookups redundant
lkA = dom_lookups(32, 0, 3)
plA, hdA, hsA, hrA = h_rows(M125, lkA)
p("125M scenario A (int16 class, wrho 32): D lookups", lkA['D'],
  "helpers", helpers(lkA)['D'], "| H planes", sum(plA.values()),
  "data", hdA, "sites", hsA, "rows", hrA)
# scenario B: draft decision 2, class 2^12 -> wrho stays < 32, +2 class lookups
lkB = dom_lookups(29, 2, 3)
plB, hdB, hsB, hrB = h_rows(M125, lkB)
p("125M scenario B (class 2^12, wrho 29): D lookups", lkB['D'],
  "helpers", helpers(lkB)['D'], "| H planes", sum(plB.values()),
  "data", hdB, "sites", hsB, "rows", hrB)
p("draft claims: D lookups 36, helpers 18, H planes 51, data 7,082, rows 7,186")

hdr("3. Lookup totals at 125M")
dl125 = domlogs(M125)
for label, lk in (("A (wrho 32)", lkA), ("B (class 2^12)", lkB), ("draft", dom_lookups(29, -2, 3))):
    tot = sum(lk[d] * (1 << dl125[d]) for d in ['L', 'D', 'F', 'Q', 'Kv', 'S'])
    p(f"{label:16s} U8 lookups {tot:,}  (draft says 99,631,104)")
    for d in ['L', 'D', 'F', 'Q', 'Kv', 'S']:
        p(f"     {d:3s} {lk[d]:3d} x {1<<dl125[d]:>9,} = {lk[d]*(1<<dl125[d]):>12,}")
p("exp pairs", f"{1<<dl125['S']:,}", " act pairs", f"{1<<dl125['F']:,}")
p("largest histogram entry <= total; log2(99.6M) = %.2f, field 2^64 base / 2^128 ext" % lg(99631104))

hdr("4. The norm window, exact integers (witness.rs:157-208, layout.rs:321)")
def isqrt(n): return math.isqrt(n)
NORM_CEPS, NORM_CN, NORM_TN = 1, 1024, 11
def norm_case(d, xmax):
    ss = NORM_CEPS + d * xmax * xmax
    D = isqrt(ss)
    a1 = ss - D * D
    a2 = 2 * D - a1
    den = D << (NORM_TN + 1)
    wrho = max(1, (den - 1).bit_length())      # smallest s with rho <= den-1 < 2^s
    limbsD = max(1, -((-(D.bit_length())) // 8))
    return ss, D, a1, a2, den, wrho, limbsD

for label, d, xmax in (("toy d16 int16", 16, 32767),
                       ("toy d16 int16 (|x|<=32768)", 16, 32768),
                       ("125M d768 int16", 768, 32767),
                       ("125M d768 |x|<2^12", 768, 4095),
                       ("125M d768 |x|<2^11", 768, 2047),
                       ("125M d768 |x|<2^10", 768, 1023),
                       ("125M d768 int8 (127)", 768, 127),
                       ("125M d768 real (83)", 768, 83),
                       ("8B d4096 int16", 4096, 32767)):
    ss, D, a1, a2, den, wrho, nl = norm_case(d, xmax)
    p(f"{label:28s} ss=2^{lg(ss):5.2f} Dmax={D:>10,} (2^{lg(D):5.2f}, {nl} limbs) "
      f"a1max={a1:>10,} den={den:>14,} = 2^{lg(den):6.3f} -> wrho {wrho}")

ss, Dm, a1, a2, den, wrho, nl = norm_case(768, 32767)
p("")
p("125M int16: den = %d, 2^32 = %d" % (den, 1 << 32))
p("margin factor 2^32/den = %.6f  = %.4f bits" % ((1 << 32) / den, 32 - lg(den)))
p("D^2 + a1 = %d = 2^%.2f  (premise says < 2^49)" % (Dm*Dm + a1, lg(Dm*Dm + a1)))
p("witness.rs:174 refuses d >= 2^24: Dmax %d < %d -> %s" % (Dm, 1 << 24, Dm < (1 << 24)))
p("a1 < 2^24? %s   a2 = 2D - a1 = %d >= 0? %s" % (a1 < (1 << 24), a2, a2 >= 0))
p("rho/sigma limbs needed at wrho 32: %d bytes" % (-(-32 // 8)))
p("layout.rs:321 coefficient at wrho 32: 1 << (32-32) = 1  -> scaled() == byte(), redundant")
p("sites with that coefficient: layout.rs:321, :323, :329, :331 = FOUR (rho_a, sigma_a, rho_m, sigma_m)")

hdr("5. The softmax window (witness.rs:256-309)")
F_E, F_P = 9, 9
for label, T in (("toy T32", 32), ("125M T512", 512), ("8B T512", 512)):
    total_max = T << F_E
    p(f"{label:10s} Sum in [2^{F_E}, T*2^{F_E}] -> max {total_max:,} = 2^{lg(total_max):.2f}; "
      f"sigma < Sum -> wrho_s {max(1,(total_max-1).bit_length())}; limbs {-(-max(1,(total_max-1).bit_length())//8)}")
p("p proved bound: two limbs with scaled(l1,64) -> l1 < 4 -> p < 1024 = 2^10 (honest p <= 2^9)")
p("p*Sum + rho_s worst PROVED at 125M: %d = 2^%.2f (draft quotes the honest 2^27.00)"
  % (1023 * (512 << F_E) + ((512 << F_E) - 1), lg(1023 * (512 << F_E) + (512 << F_E) - 1)))
p("delta = mx - masked <= 127 + 127 = 254 < 256 at every T and d  -> exp table unchanged")

hdr("6. Accumulations (witness.rs:99-119, :250, :312, :317)")
for label, terms, a, b in (("QKV / Wo / gate / up (d=768)", 768, 127, 127),
                           ("down (f=2048, int16 x int8)", 2048, 32767, 127),
                           ("scores (dh=64)", 64, 127, 127),
                           ("PV (T=512, p<2^10 proved)", 512, 1023, 127),
                           ("PV (T=512, p<=2^9 honest)", 512, 512, 127),
                           ("a16*u16", 1, 32767, 32767)):
    v = terms * a * b
    p(f"{label:34s} {v:>16,} = 2^{lg(v):6.2f}   headroom to 2^49: 2^{49-lg(v):.2f}")
p("norm c0 terms at 125M: 2*Cn*gamma*x = %d = 2^%.2f ; y*D*2^(tn+1) = %d = 2^%.2f"
  % (2*1024*127*32767, lg(2*1024*127*32767), 127*Dm*4096, lg(127*Dm*4096)))

hdr("7. Slots: L = (main+ext)*degree + 2 (zkp-core/sumcheck.rs:197-198)")
# (name, toy main, 125M main, ext, degree, support-indicator degree bump)
SLOTS = [
 ("SC_SS",   9, 19, 1, 3, 1), ("SC_SSM",  9, 19, 1, 3, 1),
 ("SC_TZC",  5,  9, 1, 3, 0), ("SC_LZC",  9, 13, 1, 4, 0),
 ("SC_RS",  11, 22, 1, 3, 1), ("SC_QMM",  4, 10, 1, 2, 0),
 ("SC_KMM",  4, 10, 1, 2, 0), ("SC_VMM",  4, 10, 1, 2, 0),
 ("SC_SCORE",3,  6, 2, 2, 0), ("SC_PV",   5,  9, 2, 2, 0),
 ("SC_WO",   4, 10, 1, 2, 0), ("SC_GMM",  4, 10, 1, 2, 0),
 ("SC_UMM",  4, 10, 1, 2, 0), ("SC_DMM",  4, 11, 1, 2, 0),
 ("SC_DZC",  9, 19, 1, 4, 1), ("SC_QZC",  9, 19, 1, 4, 1),
 ("SC_KVZC", 8, 17, 1, 4, 0), ("SC_SZC", 11, 22, 1, 4, 1),
 ("SC_FZC",  9, 20, 1, 4, 0), ("SC_TAB",  8,  8, 1, 3, 0),
 ("SC_ZS",   8,  8, 1, 2, 0), ("SC_IO_IN", 9, 19, 1, 2, 0),
 ("SC_IO_OUT",9,19, 1, 2, 0)]
worst = (0, "")
worst_s = (0, "")
for nm, mt, m1, e, d, bump in SLOTS:
    Lt = (mt + e) * d + 2
    L1 = (m1 + e) * d + 2
    Ls = (m1 + e) * (d + bump) + 2
    if L1 > worst[0]: worst = (L1, nm)
    if Ls > worst_s[0]: worst_s = (Ls, nm)
    flag = "" if Ls + 256 <= 512 else "  <<< OVER BUDGET"
    p(f"{nm:10s} toy L {Lt:3d} | 125M L {L1:3d} (+256 = {L1+256:3d}) | with support {Ls:3d} (+256 = {Ls+256:3d}){flag}")
p("worst 125M L:", worst, " worst with support factor:", worst_s, " budget 512 (zk.rs:444)")
p("M rows n_base = 2*23 + 4 =", 2*23+4, " (zk.rs:435-ish `n_base = 2*masks.len() + 4`; independent of log_cols)")
p("M geometry fixed: MASK_LOG_MSG 9 (512), MASK_LOG_DOM 12 (4096), MASK_Q 256 -> 50*4096*8 = %d B" % (50*4096*8))

hdr("8. Receipt bytes (wire.rs:28-36)")
def opening_len(groups, rows, VEC, PATH, CHECKS=256):
    return (groups + 1) * VEC * 16 + CHECKS * (8 + rows * 8 + 32 + PATH * 32)

def slot_bytes(slots, a_sites, h_sites, io=2):
    tot = 0
    for i, (nm, mt, m1, e, d, bump) in enumerate(slots):
        terms = a_sites[i] + h_sites[i] + (1 if nm.startswith("SC_IO") else 0)
        tot += (1 + (m1 + e) * (d + 1) + terms) * 16
    return tot

A_SITES_125 = [1,1,22,2,2,1,1,1,2,2,1,1,1,1,37,8,7,15,11,3,0,1,1]
def hsites(hp):
    return [0,0,0,1,0,0,0,0,0,0,0,0,0,0,hp['D'],hp['Q'],hp['Kv'],hp['S']+1,hp['F']+1,3,1,0,0]

VEC125, PATH125 = 16384 + 256, 16
for label, ar, hr_, ag, hg, hp in (
        ("draft (A35/H9, H 7186)", 5681, 7186, 35, 9, helpers(dom_lookups(29, -2, 3))),
        ("checked A (A36/H9, wrho32)", 5681, hrA, 36, 9, helpers(lkA)),
        ("checked B (A36/H9, class 2^12)", 5681, hrB, 36, 9, helpers(lkB))):
    a_op = opening_len(ag, ar, VEC125, PATH125)
    h_op = opening_len(hg, hr_, VEC125, PATH125)
    ep = 2 * opening_len(1, 29, VEC125, PATH125)
    m_op = 2 * 1024 * 16 + 256 * (8 + 50 * 8 + 32 + 12 * 32)
    sl = slot_bytes(SLOTS, A_SITES_125, hsites(hp))
    tot = 8 + 32 + 3 * 32 + sl + m_op + a_op + h_op + ep
    p(f"{label:32s} A {a_op:>11,}  H {h_op:>11,}  EP {ep:>9,}  M {m_op:>8,}  slots {sl:>7,}  TOTAL {tot:>12,} B = {tot/2**20:.2f} MiB")
    if label.startswith("checked A"):
        totA = tot
p("12 blocks (checked A): %.1f MB / %.1f MiB" % (12*totA/1e6, 12*totA/2**20))
p("12 blocks (draft's own inputs): %.1f MB" % (12*40616200/1e6))
p("toy receipt for control: 2,816,472 B (measured, disposition section 3)")

hdr("9. Committed material, bytes")
def mat(rows, LOG_N, inv_rate):
    sysb = rows * (1 << LOG_N) * 8
    enc = rows * (1 << LOG_N) * inv_rate * 8
    return sysb, enc
for label, rows in (("A 5,681", 5681), ("H 7,186 (draft)", 7186), ("H %d (checked)" % hrA, hrA)):
    s, e = mat(rows, 14, 4)
    p(f"{label:18s} systematic {s:>14,} B = {s/2**20:8.1f} MiB   encoded {e:>14,} B = {e/2**20:8.1f} MiB")

hdr("10. Memory residency at the peak (protocol.rs allocation sites)")
wit_vals = sum(c * (1 << dl125[d]) for d, c in A_PLANES_125.items() if d != 'Tab')
p("witness planes (Vec<Vec<i64>>, protocol.rs:271 requires padded length):",
  f"{wit_vals:,} values = {wit_vals*8/1e6:.0f} MB")
looked_vals = sum(lkA[d] * (1 << dl125[d]) for d in ['L','D','F','Q','Kv','S'])
p("looked (protocol.rs:289, i64 per lookup):", f"{looked_vals:,} = {looked_vals*8/1e6:.0f} MB")
a_s, a_e = mat(5681, 14, 4); h_s, h_e = mat(hrA, 14, 4)
p("A systematic %.0f MB  A encoded %.0f MB" % (a_s/1e6, a_e/1e6))
p("H systematic %.0f MB  H encoded %.0f MB" % (h_s/1e6, h_e/1e6))
ep_b = 2 * (29 * 16384 * 8 * 5)
p("two endpoints (29 rows, sys+enc) %.0f MB ; M %.1f MB" % (ep_b/1e6, 50*4096*8/1e6))
p("per-commitment extras: pads rows*256*8, salts 65536*32, tree ~4 MB -> %.0f MB for A+H"
  % ((5681*256*8 + hrA*256*8 + 2*65536*32 + 8*2**20)/1e6))
# slot tables
def tables_per_slot():
    hp = helpers(lkA)
    return {
      'SC_SS': 2, 'SC_SSM': 2, 'SC_TZC': 3 + 22, 'SC_LZC': 1 + 2 + 1,
      'SC_RS': 4, 'SC_QMM': 2, 'SC_KMM': 2, 'SC_VMM': 2, 'SC_SCORE': 2,
      'SC_PV': 2, 'SC_WO': 2, 'SC_GMM': 2, 'SC_UMM': 2, 'SC_DMM': 2,
      'SC_DZC': 5 + 35 + 2 + hp['D'], 'SC_QZC': 5 + 7 + 1 + hp['Q'],
      'SC_KVZC': 5 + 6 + 1 + hp['Kv'], 'SC_SZC': 4 + 13 + 2 + hp['S'] + 1,
      'SC_FZC': 3 + 11 + hp['F'] + 1, 'SC_TAB': 10, 'SC_ZS': 2,
      'SC_IO_IN': 3, 'SC_IO_OUT': 3}
tps = tables_per_slot()
nvars = {nm: m1 + 0 for nm, mt, m1, e, d, b in SLOTS}
tp_total = 0
biggest = (0, "")
for nm, mt, m1, e, d, b in SLOTS:
    pts = tps[nm] * (1 << m1)
    tp_total += pts
    by = pts * 16
    if by > biggest[0]: biggest = (by, nm, tps[nm], m1)
    if by > 50e6:
        p(f"  {nm:9s} {tps[nm]:3d} tables x 2^{m1} = {pts:>12,} points = {by/1e6:8.0f} MB")
p("total table-points over 23 slots: %s (draft says 212.7M)" % f"{tp_total:,}")
p("largest slot's live tables: %s = %.0f MB (%d tables x 2^%d)" % (biggest[1], biggest[0]/1e6, biggest[2], biggest[3]))
peak = wit_vals*8 + looked_vals*8 + a_s + a_e + h_s + h_e + ep_b + 50*4096*8 + biggest[0]
p("PEAK (everything alive at the largest slot): %.2f GB = %.2f GiB" % (peak/1e9, peak/2**30))
peak2 = peak - wit_vals*8 - looked_vals*8
p("with the two drops of step S2:            %.2f GB = %.2f GiB" % (peak2/1e9, peak2/2**30))

hdr("11. Per-opening soundness (pcs.rs:16-19; hiding rows are n + Q)")
def per_opening(log_cols, inv_rate, Q=256, checks=256):
    n = 1 << log_cols
    msg = n + Q
    enc = n * inv_rate
    rate = Fraction(msg, enc)
    delta = 1 - rate
    base = 1 - delta / 3
    return float(rate), float(base), checks * math.log2(float(base))
for label, lc, ir in (("toy block  log_cols 8 / inv_rate 8", 8, 8),
                      ("125M       log_cols 14 / inv_rate 4", 14, 4),
                      ("(no hiding pad, inv_rate 8)", 8, 8),
                      ("(no hiding pad, inv_rate 4)", 14, 4)):
    r, b, e = per_opening(lc, ir)
    p(f"{label:38s} rate {r:.6f}  (1-delta/3) {b:.6f}  -> 2^{e:.2f} per opening")
# the non-hiding control from the obligations doc
b = 1 - (1 - Fraction(1, 8)) / 3
p("non-hiding inv_rate 8 control: (17/24)^256 = 2^%.2f (obligations doc line 376)" % (256*math.log2(float(b))))
r, b, e = per_opening(14, 4)
for nb, label in ((4, "one block: A, H, In, Out"), (48, "twelve blocks: 4 x 12")):
    p(f"{label:28s} union {nb} x 2^{e:.2f} = 2^{e + math.log2(nb):.2f}")
LK = looked_vals + (1 << dl125['S']) + (1 << dl125['F'])
p("LogUp Schwartz-Zippel term per block: N/|Fp2| with N = %s -> 2^%.2f" % (f"{LK:,}", lg(LK) - 128))
p("twelve blocks (independent alpha each): 2^%.2f" % (lg(LK) - 128 + math.log2(12)))
p("whole 12-block private 125M pass, dominant term: about 2^%.1f"
  % (-abs(min(e + math.log2(48), lg(LK) - 128 + math.log2(12))) - 0.5))

hdr("12. Time model, rebuilt from the measured mr1 phases")
# measured, quiet box, 12 layers x 512, log_cols 14 / inv_rate 4 / Q 256, repaired arm
meas = dict(prove=35.417, commitA=9.637, commitW=4.575, helpersH=10.769,
            zcF=6.865, open=1.741, maskcommit=0.032, tabzc=0.468)
rows = dict(A=585*12, W=288*12, H=486*12, M=16*12)
p("commit A rate %.4f ms/row ; commit W rate %.4f ms/row (control)"
  % (meas['commitA']/rows['A']*1e3, meas['commitW']/rows['W']*1e3))
commit_rate = (meas['commitA'] + meas['commitW']) / (rows['A'] + rows['W'])
p("blended commit rate %.4f ms/row" % (commit_rate*1e3))
commitH_model = commit_rate * rows['H']
helper_time = meas['helpersH'] - commitH_model
p("modelled commit H %.3f s -> helper phase %.3f s" % (commitH_model, helper_time))
ffn_helpers = 4 * 12 * 512 * 2048 / 2   # crude: ~4 helper columns over the f cube
p("(the helper rate needs the FFN's helper count, which this check did not derive)")
open_rate = meas['open'] / (rows['A'] + rows['H'] + rows['W'] + rows['M'])
p("opening rate over ALL opened rows %.4f ms/row (draft used A+H only: %.4f)"
  % (open_rate*1e3, meas['open']/(rows['A']+rows['H'])*1e3))
block_rows = 5681 + hrA + 58 + 50
p("one block row-equivalents: %d" % block_rows)
p("commit term %.1f s ; opening term %.1f s" % (commit_rate*block_rows, open_rate*(5681+hrA+58+50)))
crude = meas['prove'] / (rows['A'] + rows['H']) * (5681 + hrA)
p("crude all-in rate %.3f ms/row x %d rows = %.1f s" % (meas['prove']/(rows['A']+rows['H'])*1e3, 5681+hrA, crude))

hdr("13. The form-E split, by rows and by sumcheck table-points")
# attention half: Dom::S, Dom::Q, Dom::Kv, Dom::Ht, A_D/A_DSQ/A_LIMB and 19 of 35 Dom::D planes
att_A = (2*rows_of(dl125['T'],14) + 2*rows_of(dl125['Ht'],14) + 1*rows_of(dl125['L'],14)
         + 19*rows_of(dl125['D'],14) + 7*rows_of(dl125['Q'],14) + 6*rows_of(dl125['Kv'],14)
         + 13*rows_of(dl125['S'],14))
ff_A = (2*rows_of(dl125['T'],14) + 1*rows_of(dl125['L'],14) + 16*rows_of(dl125['D'],14)
        + 11*rows_of(dl125['F'],14))
hpA = helpers(lkA)
att_H = 2*(hpA['Q'] + hpA['Kv'] + hpA['S'] + 1) * 0  # filled below per domain
att_H = (2*rows_of(dl125['Q'],14)*hpA['Q'] + 2*rows_of(dl125['Kv'],14)*hpA['Kv']
         + 2*rows_of(dl125['S'],14)*(hpA['S']+1) + 2*rows_of(dl125['L'],14)*1
         + 2*rows_of(dl125['D'],14)*int(hpA['D']*19/35))
ff_H = (2*rows_of(dl125['F'],14)*(hpA['F']+1) + 2*rows_of(dl125['D'],14)*(hpA['D']-int(hpA['D']*19/35)))
tot = att_A + ff_A + att_H + ff_H
p("attention rows %d (A %d + H %d) = %.1f%%" % (att_A+att_H, att_A, att_H, 100*(att_A+att_H)/tot))
p("feed-forward rows %d (A %d + H %d) = %.1f%%" % (ff_A+ff_H, ff_A, ff_H, 100*(ff_A+ff_H)/tot))
ff_slots = {'SC_SSM','SC_GMM','SC_UMM','SC_DMM','SC_FZC'}
ff_tp = sum(tps[nm]*(1<<m1) for nm, mt, m1, e, d, b in SLOTS if nm in ff_slots)
p("feed-forward sumcheck table-points %s of %s = %.1f%%" % (f"{ff_tp:,}", f"{tp_total:,}", 100*ff_tp/tp_total))
for share in (0.205, 0.16, 0.25):
    for g in (7.62,):
        p("Amdahl: share %.3f moved to a %.2fx path -> saving %.1f%%" % (share, g, 100*share*(1-1/g)))

with open('/home/victor/IntelligenceRegulation/results/zk60_private_block_125m_check/recompute.out', 'w') as f:
    f.write("\n".join(out) + "\n")
