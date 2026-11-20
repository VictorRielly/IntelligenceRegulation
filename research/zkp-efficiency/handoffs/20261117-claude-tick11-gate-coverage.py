#!/usr/bin/env python3
"""Tick 11 (item 26): padded-pair skipping in the zero-check slots. Arithmetic only, reads no file.

Inputs are the measured per-slot phase times of results/zk60_slot18_14_breakdown_20261117/README.md
(solo block, ms, Arm B = unbatched useful GPU work, Arm A = batched) and the shape constants of
shape.rs (W16R2_8B / R13_SHIELD rows of the AccuracyProfile table).
"""

# (profile) -> dict(domain -> (live_cols, pad_cols)) ; rows t = 128 live, so only columns pad
PROFILES = {
    "W16R2_8B": {"width": 4096, "hidden": 14336, "layers": 32, "block_gpu": 117.285,
                 "slot18": dict(A=21.339, tab=1.701, r0=6.377, r14=9.020),
                 "slot14": dict(A=14.007, tab=0.995, r0=3.546, r14=5.345)},
    "R13_SHIELD": {"width": 3072, "hidden": 9216, "layers": 26, "block_gpu": 248.899,
                   "slot18": dict(A=34.754, tab=2.590, r0=11.564, r14=15.302),
                   "slot14": dict(A=27.950, tab=1.656, r0=9.010, r14=10.785)},
}


def pad_frac(live):
    pad = 1 << (live - 1).bit_length()
    return (pad - live) / pad, pad


for name, p in PROFILES.items():
    print(f"== {name}")
    dpad, dp = pad_frac(p["width"])
    fpad, fp = pad_frac(p["hidden"])
    print(f"  D: {p['width']} of {dp} live, gate-zero {dpad:.4f}; F: {p['hidden']} of {fp} live, gate-zero {fpad:.4f}")
    # round j (j = 0..6) binds a bit of t; pair (i, i + nhalf) keeps the column, so the
    # fully-padded pair fraction is exactly the pad-column fraction in rounds 0..6.
    # Rounds 7.. bind column bits: pair (f, f + half) has lo live whenever f < half <= live, so 0 fully padded
    # until the live prefix is shorter than half; count it exactly:
    for dom, live, padn in (("D", p["width"], dp), ("F", p["hidden"], fp)):
        out = []
        n = padn
        for j in range(7, 7 + (padn.bit_length() - 1)):
            half = n // 2
            both = sum(1 for f in range(half) if f >= live and f + half >= live)
            out.append(both)
            n = half
            live = min(live, n)  # live prefix after folding: a pair is live if either end is live
        print(f"  {dom}: fully padded pairs in column rounds 7..: {out[:6]} ...")
    for slot, dom_frac in (("slot14", dpad), ("slot18", fpad)):
        s = p[slot]
        bw_hi = s["tab"] + s["r0"] + s["r14"]          # bandwidth-bound phases incl. table build
        bw_lo = s["r0"] + s["r14"]                      # excluding table build
        hi = dom_frac * bw_hi
        lo = 0.6 * dom_frac * bw_lo                     # ASSUMED 60 % realised (compaction, tail imbalance)
        blk = p["layers"]
        print(f"  {slot}: saving {lo:.2f}-{hi:.2f} ms/block of {s['A']:.2f} batched "
              f"({100*lo/s['A']:.1f}-{100*hi/s['A']:.1f}%); of block GPU {100*lo/p['block_gpu']:.2f}-{100*hi/p['block_gpu']:.2f}%; "
              f"per request {lo*blk/1000:.3f}-{hi*blk/1000:.3f} s")
    tot_lo = sum(0.6 * (dpad if s == "slot14" else fpad) * (p[s]["r0"] + p[s]["r14"]) for s in ("slot14", "slot18"))
    tot_hi = sum((dpad if s == "slot14" else fpad) * (p[s]["tab"] + p[s]["r0"] + p[s]["r14"]) for s in ("slot14", "slot18"))
    print(f"  slots 14+18: {tot_lo:.2f}-{tot_hi:.2f} ms/block = {100*tot_lo/p['block_gpu']:.1f}-{100*tot_hi/p['block_gpu']:.1f}% of block GPU; "
          f"{tot_lo*p['layers']/1000:.2f}-{tot_hi*p['layers']/1000:.2f} s per request")
