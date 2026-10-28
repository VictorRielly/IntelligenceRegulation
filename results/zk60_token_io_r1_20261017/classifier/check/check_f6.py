"""Check of the F6 sketch count and the margin arithmetic (check lane; one thread, < 1 s).

Imports the layout replica read-only (no bytecode written). Writes check_f6.json beside itself.

1. Width ladder: f6_count.py's lc(T) = min(16, max(12, 7 + bit_length(npow2(T)))) gives 2^13 at T_pad 32,
   not the 2^12 its comment states; recount with the TinyLlama speed-plan ladder (12 at 32, +1 per doubling,
   cap 16) as well.
2. The design's F6 column uses the n + 1-row block as a LOWER bound (keys counted as n + 1). Here the
   score-domain planes (A and H) and their byte lookups are scaled to the rectangular score domain
   (n+1)_pad x T_pad x 32 heads, the "S adj" the counter's docstring names but does not compute.
3. Margin arithmetic: |w_delta|, B_delta, window, L, honest delta range, no-wrap.
"""
import json
import math
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, "/home/victor/IntelligenceRegulation/results/zk60_token_io_design_20261017")
from layout import Shape, npow2  # noqa: E402

P0, SUF = 90, 1
HERE = os.path.dirname(os.path.abspath(__file__))


def shield(T, lc):
    return Shape(T, 3072, 9216, 32, 128, 8, lc)


def lc_counter(T):
    return min(16, max(12, 7 + npow2(T).bit_length()))


def lc_ladder(T):
    return min(16, max(12, 12 + (npow2(T).bit_length() - 6)))


def elems(sh):
    s = sh.summary()
    return s["A_elems"] + s["H_elems"], s["u8"]


def s_adjusted(n, lcf):
    rows = n + SUF
    T = P0 + n + SUF
    low = shield(rows, lcf(rows))
    e_low, u_low = elems(low)
    S_low = low.size("S")
    S_rect = 32 * npow2(rows) * npow2(T)
    if S_rect == S_low:
        return e_low, u_low, S_low, S_rect
    nA = low.a_planes_on("S")
    nH = low.h_plane_doms().count("S")
    extra = (S_rect - S_low)
    e_adj = e_low + nA * extra + 2 * nH * extra          # H planes are Fp2 (two slices)
    u_adj = u_low + low.lookups_per_position("S") * extra
    return e_adj, u_adj, S_low, S_rect


out = {"ladder_check": {"T_pad 32": [lc_counter(32), lc_ladder(32)], "T_pad 64": [lc_counter(64), lc_ladder(64)],
                        "T_pad 128": [lc_counter(128), lc_ladder(128)], "T_pad 256": [lc_counter(256), lc_ladder(256)]},
       "rows": {}}
for n in (32, 48, 64, 128, 200, 256):
    T = P0 + n + SUF
    r = {}
    for name, lcf in (("counter_widths", lc_counter), ("ladder_widths", lc_ladder)):
        e_full, u_full = elems(shield(T, lcf(T)))
        e_low, u_low = elems(shield(n + SUF, lcf(n + SUF)))
        e_adj, u_adj, S_low, S_rect = s_adjusted(n, lcf)
        r[name] = dict(full_M=round(e_full / 1e6, 1), f6_lower_M=round(e_low / 1e6, 1), f6_S_adj_M=round(e_adj / 1e6, 1),
                       gain_lower=round(e_full / e_low, 2), gain_S_adj=round(e_full / e_adj, 2),
                       u8_full_M=round(u_full / 1e6, 1), u8_S_adj_M=round(u_adj / 1e6, 1), S_low=S_low, S_rect=S_rect)
    out["rows"][n] = r

# ---- margin arithmetic (DESIGN 4.1)
d, m_max, wmax, ymax = 3072, 1 << 12, 127, 127
w_delta_max = 2 * m_max * wmax
B = d * ymax * w_delta_max
c_max = 1 << 38
window = (B + c_max + 1).bit_length()
L = -(-window // 8)
P = (1 << 64) - (1 << 32) + 1
out["margin"] = dict(w_delta_max=w_delta_max, w_delta_log2=round(math.log2(w_delta_max), 3),
                     design_says_w_delta_log2=20.99, B_delta=B, B_delta_log2=round(math.log2(B), 3),
                     window_bits=window, L=L, honest_delta_max_log2=round(math.log2(B + c_max), 3),
                     identity_abs_max_log2=round(math.log2(B + (1 << (8 * L)) + c_max + 1), 3),
                     no_wrap=(B + (1 << (8 * L)) + c_max + 1) < P // 2,
                     product_term_log2=round(math.log2(ymax * w_delta_max), 3),
                     difference_row_int16_alt=dict(B=d * ymax * 32767, B_log2=round(math.log2(d * ymax * 32767), 3)))
# ---- final norm window at width 3072 (DESIGN 4.1 item 2), at the D24 class edge and at a calibrated Ceps
for ceps in (1 << 27, (1 << 40) - 1, 1 << 40):
    dm = math.isqrt(ceps + 3072 * 32768 * 32768)
    out.setdefault("final_norm_tn10", {})[str(ceps)] = dict(D_max=dm, bits=dm.bit_length(), window=10 + 1 + dm.bit_length())

with open(os.path.join(HERE, "check_f6.json"), "w") as fh:
    json.dump(out, fh, indent=1)
print(json.dumps(out, indent=1))
