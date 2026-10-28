"""F6 (public-prefix reuse) sketch count for Shieldstral-1.0-3B blocks (token lane, round 12).

Uses the design folder's layout replica (results/zk60_token_io_design_20261017/layout.py),
which is checked byte-exact against the native lane's Rust counted ladder: the native lane's
counting method. Shieldstral's text block: d 3072 (pads to 4096 = 32 x 128, so the replica's
d_pad == h_pad * hd rule holds), FFN 9216, 32 query heads over 8 KV heads, head_dim 128.
F2 (head_dim decoupled from d / heads) is the native lane's; its exact layout may differ, so
these are [COUNTED by the replica on Shieldstral's padded domains], not the final layout.

full     : the whole template + content + suffix proved, T = P0 + n + 1 rows
F6 lower : only content + suffix rows proved (n + 1), keys counted as n + 1 (a lower bound)
F6 S adj : the score domain re-sized to (n+1)_pad query rows x T_pad key rows (prefix keys stay
           as score entries with exp lookups), every other domain as F6 lower
"""
import json
import sys
sys.path.insert(0, "/home/victor/IntelligenceRegulation/results/zk60_token_io_design_20261017")
from layout import Shape, npow2  # noqa: E402

P0, SUF, L = 90, 1, 26


def shield(T, log_cols):
    return Shape(T, 3072, 9216, 32, 128, 8, log_cols)


def lc(T):
    # the native ladder's widths: 2^12 at T_pad 32, +1 per doubling, capped at 2^16 (r3 ladder)
    return min(16, max(12, 7 + npow2(T).bit_length()))


out = {}
for n in (32, 48, 64, 128, 200, 256):
    T = P0 + n + SUF
    full = shield(T, lc(T)).summary()
    low = shield(n + SUF, lc(n + SUF)).summary()
    s_full_rect = 32 * npow2(n + SUF) * npow2(T)
    s_low = low["sizes"]["S"]
    # adjust: the score domain's committed words and exp pairs scale with the S domain
    s_ratio = s_full_rect / s_low
    out[n] = {
        "T": T, "T_pad": npow2(T), "proved_rows_F6": n + SUF, "proved_pad_F6": npow2(n + SUF),
        "full": {"A_elems": full["A_elems"], "H_elems": full["H_elems"], "u8": full["u8"], "exp_pairs": full["exp_pairs"], "receipt_B": full["receipt"]},
        "F6_lower": {"A_elems": low["A_elems"], "H_elems": low["H_elems"], "u8": low["u8"], "exp_pairs": low["exp_pairs"], "receipt_B": low["receipt"]},
        "F6_S_rect_entries": s_full_rect, "F6_S_lower_entries": s_low, "S_ratio": s_ratio,
        "per_run_blocks": L,
    }
print(json.dumps(out, indent=1))
