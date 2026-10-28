#!/usr/bin/env python3
"""Gate round 9: the residual terms of a TOKEN-I/O run (public-row variant,
mode (i)), counted.  NOT a privacy result.

    python3 token_run_counts.py <out.json> <capture_dir> ...

Method -- the trained statement's (D33 section 4) applied to the token run:

* Every `fp()` draw is counted with the formulas of the frozen counting
  script (`ops/zkp-mvp/gate-tinyllama/counts/run_hash_counts.py`, the copy
  D33's figures come from), each re-read for the token stages:
    - a hiding PCS commitment: (rows - data) * n + rows * Q
      (mask rows `rng.fp()` from the mask base, then the PCS pads):
      block A / H (protocol.rs, as counted for D33), stage IN A_in / H_in
      (`token_io/stage_in.rs:314-317, 350-362`), stage OUT A_out / H_out
      (`token_io/stage_out.rs:672-674, 716-727`);
    - an H commitment's zero-sum pair re-drawn: 2 (n - 1)
      (`stage_in.rs:353-360`, `stage_out.rs:719-726`; the block's at
      protocol.rs, D33);
    - a masking commitment: 2 sum L_s + 2 N_slots Q + 4 * 1024 with
      L_s = rounds_s * d_s + 2 (`zk.rs` `mask_commit_tagged`:
      `CfsMask::random` per slot, `MASK_Q` pads per row half, b_re / b_im /
      u_re / u_im of 2 * 512 each);
    - a boundary (`boundary::prepare`) or a token endpoint
      (`endpoint_g::prepare`): (rows - data) * n + rows * Q.
  The GEOMETRY (rows, data rows, row width, the slots' (rounds, degree))
  is read from the capture's own files, and the block stage's count must
  reproduce D33's 2,329,764 (control K-1 at TinyLlama) and a boundary's
  30,208 (K-2).
* Salts: one per encoded column of every commitment (2^log_n * inv_rate;
  the masking commitment 4,096).
* The transcript queries are MEASURED by re-deriving the run: the gate's
  token replay with the transcript classes' `absorb` and `_squeeze` counted
  (every instance, clones included, so the count can only be high: the
  bound is conservative), plus the position tags' clone squeezes.
* The input-dependent refusal (S-4), at D33's convention (two-world
  2 * C / p^2): C = 768 per block (D33), plus stage IN's at most T distinct
  table rows (`stage_in.rs:336-346`: only the prompt's positions and the
  table entries with non-zero multiplicity are inverted), plus stage OUT's
  at most 256 byte-table arguments (`stage_out.rs:566-577, 700-711`: only
  the occurring limbs and the table entries with non-zero histogram).
"""

import importlib.util
import json
import math
import os
import sys
from fractions import Fraction

GATE = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama"
spec = importlib.util.spec_from_file_location("rhc", os.path.join(GATE, "counts", "run_hash_counts.py"))
C = importlib.util.module_from_spec(spec)
spec.loader.exec_module(C)
sys.path.insert(0, os.path.join(GATE, "frozen_v11", "scripts"))

P, P2, Q = C.P, C.P2, C.OPENED
MASK_DOM, MASK_VEC = C.MASK_DOM, C.MASK_VEC


def hiding(rows, data, n, q=Q):
    return (rows - data) * n + rows * q


def mask_draws(specs, q=Q):
    sl = sum(r * d + 2 for r, d in specs)
    return 2 * sl + 2 * len(specs) * q + 4 * MASK_VEC, sl


def load(path):
    with open(path) as fh:
        return json.load(fh)


def role(stage, name):
    return next(r for r in stage["roles"] if r["role"] == name)


def geometry(cap):
    run = load(os.path.join(cap, "run.json"))
    tio = run["token_io"]
    tier = tio["tier"]
    stages = [load(os.path.join(cap, f)) for f in run["stage_files"]] if "stage_files" in run else None
    if stages is None or not stages:
        n_st = run["stages"]
        stages = [load(os.path.join(cap, f"stage-{k:02d}.json")) for k in range(n_st)]
    out = {"stages": [], "boundaries": [], "endpoints": []}
    for s in stages:
        kind = s["stage_kind"]
        n = 1 << s["log_cols"]
        inv = tier["stage_inv_rate"] if kind != "BLOCK" else run["shape"].get("inv_rate", 4)
        a_name, h_name = {"IN": ("A-in", "H-in"), "BLOCK": ("A", "H"), "OUT": ("A-out", "H-out")}[kind]
        a_data = role(s, a_name)["data_rows"]
        h_data = role(s, h_name)["data_rows"]
        md, sl = mask_draws(s["mask"]["specs"])
        rec = {"stage": s["stage"], "kind": kind, "n": n, "inv_rate": inv,
               "A": {"rows": s["a_rows"], "data": a_data, "draws": hiding(s["a_rows"], a_data, n)},
               "H": {"rows": s["h_rows"], "data": h_data,
                     "draws": hiding(s["h_rows"], h_data, n) + 2 * (n - 1)},
               "M": {"slots": len(s["mask"]["specs"]), "sum_L": sl, "draws": md}}
        rec["draws"] = rec["A"]["draws"] + rec["H"]["draws"] + rec["M"]["draws"]
        rec["salts"] = 2 * n * inv + MASK_DOM
        out["stages"].append(rec)
    for b in run["token_boundaries"]:
        f = b["facts"]
        n = 1 << f["log_n"]
        out["boundaries"].append({"name": b["name"], "rows": f["rows"], "data": f["data_rows"], "n": n,
                                  "draws": hiding(f["rows"], f["data_rows"], n),
                                  "salts": n * f["inv_rate"]})
    for nm in ("input_endpoint", "output_endpoint"):
        e = tio[nm]
        n = 1 << e["log_n"]
        out["endpoints"].append({"name": nm, "rows": e["rows"], "data": e["data_rows"], "n": n,
                                 "q": e["checks"], "draws": hiding(e["rows"], e["data_rows"], n, e["checks"]),
                                 "salts": n * e["inv_rate"]})
    out["T"] = tio["T"]
    out["L"] = run["blocks"]
    out["V"], out["V_pad"] = tio["V"], tio["V_pad"]
    return out


def measured_transcript(cap):
    """absorbs and squeezes of a full re-derivation (counted on every
    transcript instance, so an over-count, never an under-count)"""
    import zk60_native_jv_field as F
    import zk60_native_rg_hashrule as HR
    import zk60_native_rg_tokengate as TG
    counts = {"absorb": 0, "squeeze": 0}
    classes = {F.Transcript, HR.KeyedTranscript}
    saved = {}
    for cls in classes:
        saved[(cls, "absorb")] = cls.__dict__.get("absorb")
        saved[(cls, "_squeeze")] = cls.__dict__.get("_squeeze")
    base_abs, base_sq = F.Transcript.absorb, F.Transcript._squeeze

    def wrap(fn, key):
        def w(self, *a, **k):
            counts[key] += 1
            return fn(self, *a, **k)
        return w
    try:
        for cls in classes:
            if saved[(cls, "absorb")] is not None:
                cls.absorb = wrap(saved[(cls, "absorb")], "absorb")
            if saved[(cls, "_squeeze")] is not None:
                cls._squeeze = wrap(saved[(cls, "_squeeze")], "squeeze")
        b = TG.load(cap)
        rp = TG.TokenRunReplay(b).run()
        s = rp.summary()
    finally:
        for (cls, name), fn in saved.items():
            if fn is not None:
                setattr(cls, name, fn)
    return {"replay_ok": s["ok"], "challenges_checked": s["challenges_checked"],
            "final_counter": s.get("final_counter"), "absorbs_counted": counts["absorb"],
            "squeezes_counted_all_instances": counts["squeeze"],
            "stages": s.get("stages")}


def lg(x):
    if isinstance(x, Fraction):
        return math.log2(x.numerator) - math.log2(x.denominator)
    return math.log2(x)


def residuals(g, tm, q_log2=128):
    L, T = g["L"], g["T"]
    draws = sum(s["draws"] for s in g["stages"]) + sum(b["draws"] for b in g["boundaries"]) \
        + sum(e["draws"] for e in g["endpoints"])
    salts = sum(s["salts"] for s in g["stages"]) + sum(b["salts"] for b in g["boundaries"]) \
        + sum(e["salts"] for e in g["endpoints"])
    tags = 2 * 2 * (L + 2)                     # two clone squeezes per position tag, a tag per stage end
    A = tm["absorbs_counted"] + tm["squeezes_counted_all_instances"] + tags
    q = Fraction(1 << q_log2)
    two256 = Fraction(1, 1 << 256)
    refusal_C = 768 * L + T + 256
    terms = {
        "sampler bias (D9): draws x 2^-96": Fraction(draws, 1 << 96),
        "input-dependent refusal, two-world: 2 (768 L + T + 256) / |Fp2|": Fraction(2 * refusal_C, P2),
        "salt guessing: q x N_leaf x 2^-256": q * salts * two256,
        "leaf-input collision: C(N_leaf,2) x 2^-256": Fraction(salts * (salts - 1) // 2) * two256,
        "transcript pre-query: q x A x 2^-256": q * A * two256,
        "transcript-input collision: C(A,2) x 2^-256": Fraction(A * (A - 1) // 2) * two256,
        "generator, in-model alternative: 6q x 2^-256 (ASSUMED)": 6 * q * two256,
        "generator-key row: 3 x 4 x 2^-256": Fraction(12) * two256,
        "constructor vs absorb (B10): (A + q) x 2^-256": (A + q) * two256,
    }
    total = sum(terms.values())
    openings = 3 * L + 3 + 4                   # per block A, H, incoming; IN: A, H, E-in; OUT: A, H, B_out, E-out
    return {"draws": draws, "salts": salts, "transcript_queries_A": A,
            "refusal_arguments_C": refusal_C,
            "terms_log2": {k: round(lg(v), 2) for k, v in terms.items()},
            "total_distance_log2": round(lg(total), 2),
            "liveness_degenerate_challenges_log2": round(lg(Fraction(openings, P)), 2),
            "runs_2^20_linear_log2": round(lg(total) + 20, 2),
            "runs_10^6_linear_log2": round(lg(total * 10 ** 6), 2)}


def main(argv):
    out_path, caps = argv[0], argv[1:]
    tl = C.SHAPES["tinyllama_t32_trained"]
    d33 = {L: C.residuals(tl, L) for L in (1, 2, 22)}
    rec = {"what": __doc__.strip().splitlines()[0], "privacy_acceptance": False,
           "D33_reference_blocks_only": {L: {"draws": v["draws"], "total_log2": round(v["total_log2"], 2)}
                                          for L, v in d33.items()},
           "runs": {}}
    for cap in caps:
        g = geometry(cap)
        tm = measured_transcript(cap)
        r = residuals(g, tm)
        blocks = [s for s in g["stages"] if s["kind"] == "BLOCK"]
        controls = {}
        if "tinyllama" in os.path.basename(cap):
            controls["K-1 block stage draws == D33's 2,329,764"] = all(s["draws"] == 2329764 for s in blocks)
            controls["K-2 boundary draws == D33's 30,208"] = all(b["draws"] == 30208 for b in g["boundaries"])
        rec["runs"][os.path.basename(cap)] = {"geometry": g, "transcript": tm, "residuals": r,
                                              "controls": controls}
        print(os.path.basename(cap), r["draws"], r["total_distance_log2"], controls)
    with open(out_path, "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True)
        fh.write("\n")


if __name__ == "__main__":
    main(sys.argv[1:])
