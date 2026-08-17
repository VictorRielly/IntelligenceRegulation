#!/usr/bin/env python3
"""m125_export_ffn.py — U-AG-B1 Agent BF: read-only export of the
frugal-lm 125M checkpoint's FFN tensors + per-layer X for the 12-layer
P0 pass proof (`ring_matmul m125-pass`).

READ-ONLY under /Users/victorrielly/frugal-lm (nothing there is
written). Exports land in results/m125_ffn_export/ in THIS repo:
raw little-endian .bin tensors (git-ignored via a local .gitignore)
plus manifest.json (committed) carrying shapes, the calibrated scale
table, SHA-256 digests of every exported tensor, the v2 SiLU family
digests, and per-layer z digests from a full Python witness-chain
replica (variant-A floor semantics) so the Rust-derived chain is
cross-checked end to end.

Sources of truth reused, not re-derived:
  - scripts/m125_int8_calibration.py (BC): safetensors reader,
    quantize/floor_requant/narrow primitives, model walk classes.
  - results/m125_int8_calibration.json (BC): the calibrated per-layer
    exponent table (weights 2^-9 uniform).
  - The silu-int8-table-v2 family (ring/lookup.rs, lane BF D1): the
    generation formula replicated here byte-identically; digests
    asserted against the frozen pins.

The X batch: the SAME seeded window construction as the calibration
study (seed 1337, disjoint (cal, val) windows); this export takes the
FIRST HELD-OUT sequence, so the pass witness lies inside the batch BC
measured at 0 range-fact violations. Run under frugal-lm's venv:
  /Users/victorrielly/frugal-lm/.venv/bin/python scripts/m125_export_ffn.py
"""

import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import m125_int8_calibration as cal  # noqa: E402  (BC's primitives)

OUT_DIR = ROOT / "results" / "m125_ffn_export"
# `--out <dir>` (2026-08-17): write a VARIANT export elsewhere (the WSL
# box's re-export; see M125_EXPORT_DIR in the Rust loader) so the frozen
# committed manifest/sidecar are never overwritten by a re-run.
if "--out" in sys.argv:
    OUT_DIR = Path(sys.argv[sys.argv.index("--out") + 1]).resolve()
CAL_JSON = ROOT / "results" / "m125_int8_calibration.json"

# The frozen v2 family digests (ring/lookup.rs UAGB1-BF-1a pins).
SILU_V2_PINS = {
    (-3, -3): "bdf8bc7129dc6ec8b002af51fd4dbef3d7c1240f65c4da01ce2db2a7c9bb6c50",
    (-4, -4): "063993481a8fc0087014b25357a22b95d88bda649cc6997e2fe27c5bacd17ada",
}


def silu_v2_generate(eg, ea):
    """The family generation formula, replicated byte-identically:
    S[g] = clamp(round_half_up(silu(g*2^eg)/2^ea), -127, 127)."""
    out = np.zeros(256, dtype=np.int8)
    for i in range(256):
        g = i - 128
        x = g * (2.0 ** eg)
        y = x / (1.0 + math.exp(-x))
        v = math.floor(y / (2.0 ** ea) + 0.5)
        out[i] = max(-127, min(127, v))
    return out


def silu_v2_digest(eg, ea, table):
    j = ('{"function":"silu-int8-table-v2",'
         '"input":{"width":8,"scale_exp":%d,"signed":true},'
         '"output":{"width":8,"scale_exp":%d,"signed":true},'
         '"rounding":"y = clamp(round_half_up(silu(x*2^in_exp)/2^out_exp), -127, 127)",'
         '"table":[' % (eg, ea))
    j += ','.join('[%d,%d]' % (i - 128, int(s)) for i, s in enumerate(table))
    j += ']}'
    return hashlib.sha256(j.encode()).hexdigest()


def sha_bytes(arr):
    return hashlib.sha256(arr.tobytes()).hexdigest()


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / ".gitignore").write_text("*.bin\n")

    # --- family tables, digest-asserted against the frozen pins. ---------
    tables = {}
    for (eg, ea), pin in SILU_V2_PINS.items():
        t = silu_v2_generate(eg, ea)
        dg = silu_v2_digest(eg, ea, t)
        assert dg == pin, "family digest drift at (%d,%d): %s" % (eg, ea, dg)
        tables[(eg, ea)] = t
    print("silu-int8-table-v2 family digests match the frozen pins (2 members)")

    # --- the calibrated scale table (BC's JSON, authoritative). ----------
    caldata = json.loads(CAL_JSON.read_text())
    scales = caldata["calibration"]
    assert len(scales) == cal.N_LAYERS

    # --- weights: read-only tensor reads, int8 at 2^-9, matmul layout. ---
    wts = cal.read_safetensors(cal.CKPT)
    manifest = {
        "checkpoint": str(cal.CKPT),
        "seed": cal.SEED,
        "semantics": "TARGET_CONTRACT S2 floor requant (variant A); "
                     "int8 symmetric [-127,127]; silu-int8-table-v2 family",
        "shapes": {"X": [cal.T_TOKENS, cal.D_MODEL],
                   "WgT": [cal.D_MODEL, cal.MLP_HIDDEN],
                   "WuT": [cal.D_MODEL, cal.MLP_HIDDEN],
                   "WdT": [cal.MLP_HIDDEN, cal.D_MODEL]},
        "tables": {"%d,%d" % k: v for k, v in SILU_V2_PINS.items()},
        "layers": [],
    }
    wq_by_layer = []
    for li in range(cal.N_LAYERS):
        sc = scales[li]
        row = {"layer": li, "eX": sc["eX"], "eGate": sc["eGate"],
               "eA": sc["eA"], "eUp": sc["eUp"], "eH": sc["eH"],
               "eZ": sc["eZ"], "eW": -9, "files": {}, "digests": {}}
        assert sc["eWg"] == sc["eWu"] == sc["eWd"] == -9
        assert sc["eGate"] == sc["eA"], "family assumes eGate == eA"
        lw = {}
        for name, key, transpose in (("WgT", "w_gate", True),
                                     ("WuT", "w_up", True),
                                     ("WdT", "w_down", True)):
            W = wts["blocks.%d.mlp.%s.weight" % (li, key)].astype(np.float64)
            q, sat = cal.quantize(W, -9)
            assert sat == 0, (li, name, sat)
            qT = np.ascontiguousarray(q.T).astype(np.int8)  # matmul layout
            fn = "layer%02d_%s.bin" % (li, name)
            (OUT_DIR / fn).write_bytes(qT.tobytes())
            row["files"][name] = fn
            row["digests"][name] = sha_bytes(qT)
            lw[name] = qT.astype(np.int64)
        wq_by_layer.append(lw)
        manifest["layers"].append(row)
    print("36 weight tensors exported (int8 @ 2^-9, transposed to matmul layout)")

    # --- weights-only mode (2026-08-17): validate the checkpoint against
    # --- the COMMITTED manifest's weight digests and stop before the X
    # --- walk (which needs the val shard + mlx). Used on the WSL box.
    if "--weights-only" in sys.argv:
        committed = ROOT / "results" / "m125_ffn_export" / "manifest.json"
        prev = json.loads(committed.read_text()) if committed.exists() else None
        if prev is None:
            print("weights-only: no committed manifest to compare against")
            return
        bad = 0
        for li in range(cal.N_LAYERS):
            for name in ("WgT", "WuT", "WdT"):
                want = prev["layers"][li]["digests"][name]
                got = manifest["layers"][li]["digests"][name]
                if want != got:
                    bad += 1
                    print("  layer %2d %s: DIGEST MISMATCH %s != %s" % (li, name, got[:16], want[:16]))
        print("weights-only: %d/36 weight digests match the committed manifest"
              % (36 - bad))
        assert bad == 0, "checkpoint is not the frozen ckpt-00009536 export"
        return

    # --- X per layer: one held-out sequence through the QUANTIZED
    # --- end-to-end walk (BC's variant A construction — each layer's X
    # --- is the int8 model's own mlp_norm output; attention/norms fp32
    # --- per the contract scope). The witness chain runs INSIDE the
    # --- walk with the v2 family tables and floor semantics; the fp32
    # --- reference-walk X was tried first and FAILED its z facts on 2
    # --- layers (a hybrid neither calibrated nor claimed — recorded in
    # --- M125_PASS_REPORT.md; this construction is the actual int8
    # --- pass the statement claims). -------------------------------------
    if not cal.try_mlx():
        print("FATAL: mlx unavailable — run under the frugal venv")
        sys.exit(1)
    model, n_params = cal.build_model()
    print("model loaded (strict): %d params" % n_params)
    capw = cal.FfnCapture(model)
    cal_b, val_b = cal.token_batches()
    seq = val_b[:1]  # the FIRST HELD-OUT window (inside BC's measured set)
    viol = {"count": 0}

    def ffn(li, x):
        sc = scales[li]
        row = manifest["layers"][li]
        B, T, C = x.shape
        xf = x.reshape(-1, C).astype(np.float64)
        xq, xclip = cal.quantize(xf, sc["eX"])
        xq8 = xq.astype(np.int8)
        fn = "layer%02d_X.bin" % li
        (OUT_DIR / fn).write_bytes(xq8.tobytes())
        row["files"]["X"] = fn
        row["digests"]["X"] = sha_bytes(xq8)
        lw = wq_by_layer[li]
        x64 = xq.astype(np.int64)
        acc_g = x64 @ lw["WgT"]
        acc_u = x64 @ lw["WuT"]
        sh_g = sc["eGate"] - sc["eX"] + 9
        sh_u = sc["eUp"] - sc["eX"] + 9
        g8, vg = cal.narrow_int8(cal.floor_requant(acc_g.astype(np.float64), sh_g))
        u8, vu = cal.narrow_int8(cal.floor_requant(acc_u.astype(np.float64), sh_u))
        tab = tables[(sc["eGate"], sc["eA"])]
        a8 = tab[(g8.astype(np.int64) + 128)]
        hh = a8.astype(np.int64) * u8.astype(np.int64)
        sh_h = sc["eH"] - sc["eA"] - sc["eUp"]
        h8, vh = cal.narrow_int8(cal.floor_requant(hh.astype(np.float64), sh_h))
        acc_d = h8.astype(np.int64) @ lw["WdT"]
        sh_z = sc["eZ"] - sc["eH"] + 9
        z8, vz = cal.narrow_int8(cal.floor_requant(acc_d.astype(np.float64), sh_z))
        viol["count"] += xclip + vg + vu + vh + vz
        row["shifts"] = {"g": int(sh_g), "u": int(sh_u),
                         "h": int(sh_h), "z": int(sh_z)}
        row["digests"]["z"] = sha_bytes(z8.astype(np.int8))
        row["acc_max"] = {"gateup": int(max(np.abs(acc_g).max(),
                                            np.abs(acc_u).max())),
                          "down": int(np.abs(acc_d).max()),
                          "had": int(np.abs(hh).max())}
        print("  layer %2d: shifts g/u/h/z = %d/%d/%d/%d, viol X/g/u/h/z = "
              "%d/%d/%d/%d/%d, z digest %s"
              % (li, sh_g, sh_u, sh_h, sh_z, xclip, vg, vu, vh, vz,
                 row["digests"]["z"][:16]))
        # Feed the quantized z forward (variant A: the int8 model's pass).
        return (z8 * (2.0 ** sc["eZ"])).astype(np.float32).reshape(B, T, -1)

    capw.walk(seq[:, :-1], ffn_override=ffn)
    total_viol = viol["count"]
    print("range-fact violations across the pass: %d (0 required — the "
          "proof would reject BY DESIGN otherwise)" % total_viol)
    assert total_viol == 0, "witness does not satisfy the statement"

    manifest["range_violations"] = total_viol
    (OUT_DIR / "manifest.json").write_text(json.dumps(manifest, indent=1))
    # Flat sidecar for the Rust loader (JSON-free): per layer the tensor
    # digests + shifts, one line each.
    lines = []
    for r in manifest["layers"]:
        li = r["layer"]
        for name in ("X", "WgT", "WuT", "WdT", "z"):
            lines.append("%02d %s %s" % (li, name, r["digests"][name]))
        s = r["shifts"]
        lines.append("%02d shifts %d %d %d %d" % (li, s["g"], s["u"],
                                                  s["h"], s["z"]))
    (OUT_DIR / "digests.txt").write_text("\n".join(lines) + "\n")
    print("manifest -> %s (+ digests.txt sidecar)" % (OUT_DIR / "manifest.json"))


if __name__ == "__main__":
    main()
