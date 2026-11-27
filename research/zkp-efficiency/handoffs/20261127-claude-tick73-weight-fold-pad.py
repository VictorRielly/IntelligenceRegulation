#!/usr/bin/env python3
"""Tick 73 (item 115): padded and live entries of the verifier's seven weight folds, and a priced live-only fold.

Standard library only; reads no file; under a second.

Shapes are COUNTED from the profile table (shape.rs:301-302) and the slot definitions (argument.rs:3230-3235,
3374-3378): d, f, q, kv width; d_pad = next power of two of d, f_pad likewise, q_pad = h_pad * head_dim.
Rates are ASSUMED or an anchor, labelled where used.
"""


def p2(n):
    return 1 << (n - 1).bit_length()


PROFILES = {
    # name: (width d, hidden f, q_heads, head_dim, kv_heads)
    "W16R2_SHIELD_T128_H24 (installed)": (3072, 9216, 32, 128, 8),
    "W16R2_8B_T128_H24": (4096, 14336, 32, 128, 8),
}

MEASURED_FOLD_ROWS_MS = 139.5  # rows of slots 5-7, 10-13, one thread, installed profile, median of 26 tables
MEASURED_BLOCK_PROOF_MS = 338.9
MEASURED_TABLE_WALL_MS = 740.0
PADDED_8B_TOTAL = 243_269_632  # tick 68 / the queue item

# per padded (zero) entry, ns.  LOOP: the zero-skip scalar loop visits it (anchor: 0.224 ns an entry over the three
# feed-forward folds on diagonal weights, A14/A18, tick 68 section on folds; the code path of that anchor, scalar or NEON,
# was not rechecked).  SCAN: the min-scan `contains(&i8::MIN)` over the padded matrix, 8 to 25 GB/s (tick 68's assumed band).
LOOP_LO, LOOP_HI = 0.22, 0.40
SCAN_LO, SCAN_HI = 1 / 25.0, 1 / 8.0  # ns per byte == ns per entry (i8)

rows_out = []
totals = {}
for name, (d, f, qh, hd, kvh) in PROFILES.items():
    d_pad, f_pad = p2(d), p2(f)
    h_pad = p2(qh)
    q = qh * hd
    q_pad = h_pad * hd
    kvw = kvh * hd
    # (slot, label, fold fn, axis, rows, cols, live rows, live cols)
    slots = [
        (5, "QMM  Wq", "fold_rows_i8", "Rows", q_pad, d_pad, q, d),
        (6, "KMM  Wk", "fold_rows_i8", "Rows", kvw, d_pad, kvw, d),
        (7, "VMM  Wv", "fold_rows_i8", "Rows", kvw, d_pad, kvw, d),
        (10, "WO   Wo", "fold_rows_i8", "Rows", d_pad, q_pad, d, q),
        (11, "GMM  Wg", "fold_cols_i8", "Cols", d_pad, f_pad, d, f),
        (12, "UMM  Wu", "fold_cols_i8", "Cols", d_pad, f_pad, d, f),
        (13, "DMM  Wd", "fold_cols_i8", "Cols", f_pad, d_pad, f, d),
    ]
    print(f"== {name}: d={d} d_pad={d_pad} f={f} f_pad={f_pad} q={q} q_pad={q_pad} kv width={kvw}")
    print(f"{'slot':>4} {'matrix':8} {'fn':13} {'shape (rows x cols)':>16} {'padded':>12} {'live':>12} {'pad':>12} {'pad %':>6}")
    tp = tl = 0
    for s, lab, fn, ax, r, c, lr, lc in slots:
        padded = r * c
        live = lr * lc
        tp += padded
        tl += live
        print(f"{s:>4} {lab:8} {fn:13} {r:>7} x {c:<7} {padded:>12,} {live:>12,} {padded - live:>12,} {100 * (padded - live) / padded:>6.1f}")
    pad = tp - tl
    print(f"     {'total':8} {'':13} {'':>16} {tp:>12,} {tl:>12,} {pad:>12,} {100 * pad / tp:>6.1f}")
    assert tp == PADDED_8B_TOTAL, tp
    totals[name] = (tp, tl, pad)

    lo = pad * (LOOP_LO + SCAN_LO) / 1e6  # ms (ns * entries / 1e6)
    mid = pad * ((LOOP_LO + LOOP_HI) / 2 + (SCAN_LO + SCAN_HI) / 2) / 1e6
    hi = pad * (LOOP_HI + SCAN_HI) / 1e6
    # the hard ceiling: a pad entry cannot cost more than the average entry (a live nonzero entry does two i128 multiply-adds)
    ceil_ms = pad * (MEASURED_FOLD_ROWS_MS * 1e6 / tp) / 1e6
    print(f"  live-only fold saving (loop + scan over the pad entries): low {lo:.1f}, mid {mid:.1f}, high {hi:.1f} ms a block;"
          f" hard ceiling at the measured average rate {ceil_ms:.1f} ms")
    if "installed" in name:
        for lab, v in (("low", lo), ("mid", mid), ("high", hi), ("ceiling", ceil_ms)):
            print(f"    {lab:8} {v:6.1f} ms = {100 * v / MEASURED_FOLD_ROWS_MS:5.1f}% of the 139.5 ms fold rows,"
                  f" {100 * v / MEASURED_BLOCK_PROOF_MS:4.1f}% of the 338.9 ms block proof check,"
                  f" {100 * v / MEASURED_TABLE_WALL_MS:4.1f}% of the 740.0 ms table wall,"
                  f" x26 blocks = {v * 26 / 1000:.2f} s")
        # implied live-entry rate if the pad costs z
        for z in (LOOP_LO + SCAN_LO, (LOOP_LO + LOOP_HI) / 2 + (SCAN_LO + SCAN_HI) / 2, LOOP_HI + SCAN_HI):
            live_ms = MEASURED_FOLD_ROWS_MS - pad * z / 1e6
            print(f"    if a pad entry costs {z:.2f} ns, a live entry costs {live_ms * 1e6 / tl:.2f} ns (average {MEASURED_FOLD_ROWS_MS * 1e6 / tp:.3f})")
    else:
        print(f"  at 8B the pad is only the feed-forward's f -> f_pad ({pad:,} entries); the 139.5 ms is not this profile's;"
              f" the same rates give {lo:.1f} to {hi:.1f} ms a block")
    print()

# bytes an unpadded fold avoids touching, for the cache-line reading: the pad of each row is contiguous at the row end
d, f, qh, hd, kvh = PROFILES["W16R2_SHIELD_T128_H24 (installed)"]
print("installed: where the pad sits (contiguous, whole cache lines; a live-only fold skips whole runs, not scattered bytes):")
print(f"  Wq/Wk/Wv: the last {p2(d) - d} of {p2(d)} bytes of every row; Wo: the last {p2(d) - d} of {p2(d)} rows, whole;")
print(f"  Wg/Wu: the last {p2(d) - d} rows whole, and the last {p2(f) - f} of {p2(f)} bytes of every live row;")
print(f"  Wd: the last {p2(f) - f} rows whole, and the last {p2(d) - d} of {p2(d)} bytes of every live row")
