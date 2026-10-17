#!/usr/bin/env python3
"""B6 task 3: what an 8B T=512 calibration would need (memory / time), laptop vs
Mac M3 Ultra (256 GB). ARITHMETIC ONLY: no T=512 run. Inputs are the lane's
measured T=32 / T=128 runs (logs/b5-pg_T32, b5-pg_T128, b5-b6_T128, guard
history); every output is [MODEL] unless marked [COUNTED].
Writes runs/b6_t512_estimate.json and prints a table."""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
D, F, H, L, VOCAB = 4096, 14336, 32, 32, 128256
GIB = 1 << 30

# ---- measured inputs [MEASURED, shared box n=1] (logs/*.log, *.guard.json)
meas = {
    "T32_full":  {"cal_tok": 54 * 32,  "ho_tok": 72 * 32,  "pass1_s": 865, "prepass_s": 2483, "pass2_layer_s": 54.0,
                  "wall_s": 5626, "peak_rss_gib": 3.45},
    "T128_full": {"cal_tok": 30 * 128, "ho_tok": 30 * 128, "pass1_s": 907, "prepass_s": 2244, "pass2_layer_s": 52.8,
                  "wall_s": 5278, "peak_rss_gib": 3.63},
    "T128_b6_export": {"ho_tok": 15 * 128, "pass2_layer_s": 51.0, "head_s": 213, "wall_s": 1874, "peak_rss_gib": 3.32},
}
FLOP_TOKEN_LAYER = 2 * (D * D + 2 * D * 1024 + D * D + 3 * D * F)   # [COUNTED] 436 MFLOP (q, k, v, o, gate, up, down)


def score_copy_bytes(chunk, T):           # one int64 tensor of the score volume (chunk seqs x H x T x T) [COUNTED]
    return chunk * H * T * T * 8


def plan(T=512, n_cal=30, n_ho=15, chunk=2, site=1, iso=4, copies=(8, 10), base_gib=3.3,
         f32_tflops=(0.3, 0.7), mix_tflops=(0.2, 0.5)):
    """memory: base (one layer's weight working set; T32 peak minus its tiny T-terms) + live score-volume
    copies in tlcalib.i_block (sacc, s8, masked, delta, E, num, p, rho, sigma, temporaries: 8-10) for a
    chunk, or the un-chunked site-error trace (site seqs, ~12 copies incl. float parts), whichever is larger
    + resident activations (held-out x float32 x2 + int64 x2 = 24 B/elt) + calibration float32 input."""
    sc = [score_copy_bytes(chunk, T) * k for k in copies]
    st = score_copy_bytes(site, T) * 12
    act = n_ho * T * D * 24
    cal = n_cal * T * D * 4
    mem = [base_gib + (max(s, st) + act + cal) / GIB for s in sc]
    # time: fixed parts measured flat in T (pass 1 ~0.9 ks, prepass ~2.2-2.5 ks, pass 2 ~51 s/layer);
    # token-proportional parts from the FLOP count at an assumed sustained throughput.
    cal_tok, ho_tok = n_cal * T, n_ho * T
    extra_p1 = [max(0, cal_tok - 3840) * FLOP_TOKEN_LAYER * L / (r * 1e12) for r in reversed(f32_tflops)]
    p1 = [900 + e for e in extra_p1]
    pre = [2244, 2483]
    # pass 2 per layer: int (f64 blocks) + float paths on held-out, int on iso, both on site; softmax elementwise
    p2_tok = (ho_tok - 1920) * 2 + iso * T + site * T * 2
    smx = [n_ho * H * T * T * 25 * c for c in (0.5e-9, 2e-9)]          # ~25 int64 numpy ops per score entry
    p2_layer = [51.0 + p2_tok * FLOP_TOKEN_LAYER / (r * 1e12) + s for r, s in zip(reversed(mix_tflops), smx)]
    p2 = [L * x for x in p2_layer]
    head = 213 * ho_tok / 1920                                          # 6 head-metric calls, linear in positions
    full = [60 + a + b + c + head for a, b, c in zip(p1, pre, p2)]
    reuse = [30 + c + head for c in p2]                                  # --profile-from a T128 calibration
    disk_chain = n_ho * T * D * 2 * (L + 1)
    return {"T": T, "calibration_seqs": n_cal, "heldout_seqs": n_ho, "chunk": chunk, "site_seqs": site,
            "peak_rss_gib_range": [round(m, 1) for m in mem],
            "score_copy_mib": round(score_copy_bytes(chunk, T) / 2**20), "site_trace_mib": round(st / 2**20),
            "activations_mib": round(act / 2**20), "calib_input_mib": round(cal / 2**20),
            "pass1_min": [round(x / 60) for x in p1], "prepass_min": [round(x / 60) for x in pre],
            "pass2_min": [round(x / 60) for x in p2], "head_min": round(head / 60),
            "full_calibration_h": [round(x / 3600, 1) for x in full],
            "export_only_profile_reuse_h": [round(x / 3600, 1) for x in reuse],
            "chain_spill_gib": round(disk_chain / GIB, 1)}


if __name__ == "__main__":
    cases = {
        "laptop_chunk2_site1 (fits a light job, need ~6 / cap ~7)": plan(chunk=2, site=1),
        "laptop_chunk8_site3 (B5 defaults: does NOT fit the shared budget)": plan(chunk=8, site=3),
        "mac_chunk8_site3_heldout72 (256 GB: memory no constraint)": plan(chunk=8, site=3, n_ho=72),
    }
    out = {"scope": "arithmetic only, no T=512 run; [MODEL] unless [COUNTED]", "measured_inputs": meas,
           "flop_per_token_layer_counted": FLOP_TOKEN_LAYER, "cases": cases}
    (HERE / "runs" / "b6_t512_estimate.json").write_text(json.dumps(out, indent=1))
    for k, v in cases.items():
        print(k)
        for kk, vv in v.items():
            print(f"   {kk}: {vv}")
