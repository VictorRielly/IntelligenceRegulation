#!/usr/bin/env python3
"""m8b_export_ffn.py — U-PERF3 lane R: export of an 8B-class FFN witness
(weights + per-layer X) in the EXACT layout the rig reads
(`zkmatrix-rs/src/bin/ring_matmul.rs` bf_export_path / bf_sidecar /
bf_load_layer), generalized from scripts/m125_export_ffn.py (imported,
never edited).

Layout produced under --out (default results/m8b_ffn_export):
  layerNN_X.bin    int8 row-major (T x d)      the layer's quantized X
  layerNN_WgT.bin  int8 row-major (d x f)      gate weights, matmul layout
  layerNN_WuT.bin  int8 row-major (d x f)      up weights, matmul layout
  layerNN_WdT.bin  int8 row-major (f x d)      down weights, matmul layout
  digests.txt      the sidecar bf_sidecar() parses: per layer the lines
                     NN X|WgT|WuT|WdT|z <sha256>
                     NN shifts g u h z
                   exactly as m125, PLUS the lines the 8B loader (memo
                   Section 2 W-5, the BfModel fix) will read and today's
                   loader ignores (bf_sidecar keys on (layer, name);
                   extra names are inert):
                     00 model <tag>
                     00 dims <T> <d> <f> <layers>
                     NN exps eX eGate eA eUp eH eZ eWg eWu eWd
  manifest.json    shapes, exponents, shifts, per-tensor sha256 digests,
                   checkpoint shard sha256s (the model identity), SiLU
                   family member digests (frozen or W-6-new), acc maxima,
                   range-violation count
  .gitignore       (*.bin — the binaries stay out of git)

Semantics: TARGET_CONTRACT.md Section 2 exactly as the rig derives it —
per-tensor symmetric int8 weights at the calibration's power-of-two
exponents; X per layer is the QUANTIZED end-to-end model's own mlp_norm
output (variant A: the int8 chain feeds forward — the m125 lesson that
a fp-walk X is a hybrid that neither calibrates nor is claimed);
floor requantization; SiLU via the FROZEN v2 family formula. The chain
here carries exact integers in float64 BLAS (all values integers
<= f*127^2 = 2.31e8 << 2^53 — exact in any summation order); the chain
consumes the int8 weight BYTES just written to disk, so the export is
self-checking: the digests bind the very tensors the chain used.

Memory: weights are streamed per tensor (seek reads) and written per
layer; the X walk holds one layer's fp32 attention weights + one
tensor's float64 widening at a time — peak RSS < 4 GB at the 7B shape,
so EITHER box can run it (the 7B DOWNLOAD is the Mac task; memo
Section 5 has the RUN text).

Needs the calibration JSON first (scripts/m8b_int8_calibration.py; the
committed m125 JSON also works for the 125M validation since the row
keys match).

Typical runs:
  # the 7B export (Mac, after the calibration):
  python3 scripts/m8b_export_ffn.py --ckpt ~/models/Mistral-7B-v0.1 \
      --text fineweb_edu_sample.txt
  # the 125M validation on this box (byte-compare vs the m125 export):
  python3 scripts/m8b_export_ffn.py --arch frugal \
      --ckpt /home/victor/models/125m-best-adamw-val3.0816/model.safetensors \
      --cal-json results/m125_int8_calibration.json \
      --tokens /home/victor/shard-00000.npy \
      --out results/m8b_test/m125_reexport
  # re-validate an existing export's weight digests against a checkpoint:
  python3 scripts/m8b_export_ffn.py ... --weights-only
"""

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import m125_int8_calibration as m125  # noqa: E402  (primitives)
import m125_export_ffn as m125x       # noqa: E402  (frozen SiLU family)
import m8b_int8_calibration as m8b    # noqa: E402  (store/arch/walker)

p = m8b.p


def sha_bytes(arr):
    return hashlib.sha256(arr.tobytes()).hexdigest()


def sha_file(path, chunk=1 << 24):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            b = f.read(chunk)
            if not b:
                break
            h.update(b)
    return h.hexdigest()


def export_weights(store, walker, arch, scales, out_dir, manifest):
    """Streamed weight export: per layer, quantize gate/up/down at the
    calibrated per-tensor exponents, transpose to the matmul layout,
    write int8 bins + digests. Returns per-layer digest rows."""
    for li in range(arch.n_layers):
        sc = scales[li]
        row = {"layer": li, "eX": sc["eX"], "eGate": sc["eGate"],
               "eA": sc["eA"], "eUp": sc["eUp"], "eH": sc["eH"],
               "eZ": sc["eZ"], "eWg": sc["eWg"], "eWu": sc["eWu"],
               "eWd": sc["eWd"], "files": {}, "digests": {}}
        for name, key, ekey in (("WgT", "w_gate", "eWg"),
                                ("WuT", "w_up", "eWu"),
                                ("WdT", "w_down", "eWd")):
            W = store.get(walker._n(key, li)).astype(np.float64)
            q, sat = m125.quantize(W, sc[ekey])
            assert sat == 0, (li, name, sat)
            qT = np.ascontiguousarray(q.T).astype(np.int8)
            fn = "layer%02d_%s.bin" % (li, name)
            (out_dir / fn).write_bytes(qT.tobytes())
            row["files"][name] = fn
            row["digests"][name] = sha_bytes(qT)
            del W, q, qT
        manifest["layers"].append(row)
    p("%d weight tensors exported (per-tensor int8, transposed to the "
      "matmul layout)" % (3 * arch.n_layers))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ckpt", required=True)
    ap.add_argument("--arch", default="hf", choices=("hf", "frugal"))
    ap.add_argument("--cal-json",
                    default=str(ROOT / "results" /
                                "m8b_int8_calibration.json"))
    ap.add_argument("--out",
                    default=str(ROOT / "results" / "m8b_ffn_export"))
    ap.add_argument("--tokens", default=None)
    ap.add_argument("--text", default=None)
    ap.add_argument("--t", type=int, default=512)
    ap.add_argument("--cal-seqs", type=int, default=8)
    ap.add_argument("--val-seqs", type=int, default=8)
    ap.add_argument("--seed", type=int, default=1337)
    ap.add_argument("--max-layers", type=int, default=None,
                    help="truncate (SMOKE ONLY)")
    ap.add_argument("--weights-only", action="store_true",
                    help="compare weight digests against the manifest "
                         "already in --out and stop (no token data "
                         "needed)")
    ap.add_argument("--no-ckpt-sha", action="store_true",
                    help="skip hashing the checkpoint shards")
    args = ap.parse_args()

    arch = m8b.make_arch(args.arch, args.ckpt)
    if args.max_layers:
        arch.n_layers = min(arch.n_layers, args.max_layers)
    store = m8b.TensorStore(args.ckpt)
    walker = m8b.Walker(store, arch, args.t)
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / ".gitignore").write_text("*.bin\n")

    caldata = json.loads(Path(args.cal_json).read_text())
    scales = caldata["calibration"]
    assert len(scales) >= arch.n_layers, \
        "calibration JSON has %d layers, model needs %d" % (len(scales),
                                                            arch.n_layers)
    p("m8b_export_ffn — %s (%d layers, T %d, d %d, f %d) -> %s"
      % (arch.tag, arch.n_layers, args.t, arch.d, arch.f, out_dir))
    if args.max_layers:
        p("** TRUNCATED to %d layers — SMOKE RUN **" % arch.n_layers)

    # --- SiLU family: frozen formula; new members flagged (W-6). --------
    members = m8b.silu_members(scales[:arch.n_layers])
    fresh = m8b.report_members(members)

    manifest = {
        "checkpoint": str(args.ckpt),
        "model_tag": arch.tag,
        "arch": args.arch,
        "seed": args.seed,
        "semantics": "TARGET_CONTRACT S2 floor requant (variant A); "
                     "int8 symmetric [-127,127]; silu-int8-table-v2 "
                     "family (frozen formula)",
        "shapes": {"X": [args.t, arch.d],
                   "WgT": [arch.d, arch.f],
                   "WuT": [arch.d, arch.f],
                   "WdT": [arch.f, arch.d]},
        "dims": {"t": args.t, "d": arch.d, "f": arch.f,
                 "layers": arch.n_layers},
        "tables": {"%d,%d" % k: dict(digest=dg, frozen=fr)
                   for k, (t, dg, fr) in members.items()},
        "layers": [],
    }
    if not args.no_ckpt_sha:
        manifest["checkpoint_sha256"] = {
            Path(f).name: sha_file(f) for f in store.shard_paths()}
        p("checkpoint shard sha256s recorded (%d files)"
          % len(manifest["checkpoint_sha256"]))

    # --- weights (streamed). --------------------------------------------
    export_weights(store, walker, arch, scales, out_dir, manifest)

    if args.weights_only:
        committed = out_dir / "manifest.json"
        if not committed.exists():
            p("weights-only: no manifest at %s to compare against"
              % committed)
            return
        prev = json.loads(committed.read_text())
        bad = 0
        for li in range(arch.n_layers):
            for name in ("WgT", "WuT", "WdT"):
                want = prev["layers"][li]["digests"][name]
                got = manifest["layers"][li]["digests"][name]
                if want != got:
                    bad += 1
                    p("  layer %2d %s: DIGEST MISMATCH %s != %s"
                      % (li, name, got[:16], want[:16]))
        p("weights-only: %d/%d weight digests match the manifest"
          % (3 * arch.n_layers - bad, 3 * arch.n_layers))
        assert bad == 0, "checkpoint does not reproduce the export"
        return

    # --- X per layer: the QUANTIZED end-to-end walk on the first
    # --- held-out window; the chain reads back the int8 weight BYTES
    # --- just written (self-checking export). ---------------------------
    toks = m8b.load_token_stream(args, args.ckpt)
    cal_b, val_b = m8b.token_batches(toks, args.seed, args.cal_seqs,
                                     args.val_seqs, args.t)
    seq = val_b[:1]
    viol = {"count": 0}
    shift_band = []

    def ffn(li, x, lw):
        sc = scales[li]
        row = manifest["layers"][li]
        B, T, C = x.shape
        assert B == 1
        xf = x.reshape(-1, C).astype(np.float64)
        xq, xclip = m125.quantize(xf, sc["eX"])
        xq8 = xq.astype(np.int8)
        fn = "layer%02d_X.bin" % li
        (out_dir / fn).write_bytes(xq8.tobytes())
        row["files"]["X"] = fn
        row["digests"]["X"] = sha_bytes(xq8)
        # the chain consumes the just-written int8 weight bytes
        lwq = {}
        for name, shape in (("WgT", (arch.d, arch.f)),
                            ("WuT", (arch.d, arch.f)),
                            ("WdT", (arch.f, arch.d))):
            b = np.fromfile(out_dir / ("layer%02d_%s.bin" % (li, name)),
                            dtype=np.int8)
            lwq[name] = b.reshape(shape).astype(np.float64)
        tab = members[(sc["eGate"], sc["eA"])][0].astype(np.float64)
        sh_g = sc["eGate"] - sc["eX"] - sc["eWg"]
        sh_u = sc["eUp"] - sc["eX"] - sc["eWu"]
        sh_h = sc["eH"] - sc["eA"] - sc["eUp"]
        sh_z = sc["eZ"] - sc["eH"] - sc["eWd"]
        for s in (sh_g, sh_u, sh_h, sh_z):
            assert s >= 0, ("layer %d: NEGATIVE requant shift %d — the "
                            "contract chain cannot represent this "
                            "calibration" % (li, s))
        shift_band.extend([sh_g, sh_u, sh_h, sh_z])
        acc_g = xq @ lwq["WgT"]
        acc_u = xq @ lwq["WuT"]
        g8, vg = m125.narrow_int8(m125.floor_requant(acc_g, sh_g))
        u8, vu = m125.narrow_int8(m125.floor_requant(acc_u, sh_u))
        a8 = tab[(g8.astype(np.int64) + 128)]
        hh = a8 * u8
        h8, vh = m125.narrow_int8(m125.floor_requant(hh, sh_h))
        acc_d = h8 @ lwq["WdT"]
        z8, vz = m125.narrow_int8(m125.floor_requant(acc_d, sh_z))
        viol["count"] += xclip + vg + vu + vh + vz
        row["shifts"] = {"g": int(sh_g), "u": int(sh_u),
                         "h": int(sh_h), "z": int(sh_z)}
        row["digests"]["z"] = sha_bytes(z8.astype(np.int8))
        row["acc_max"] = {"gateup": int(max(np.abs(acc_g).max(),
                                            np.abs(acc_u).max())),
                          "down": int(np.abs(acc_d).max()),
                          "had": int(np.abs(hh).max())}
        p("  layer %2d: shifts g/u/h/z = %d/%d/%d/%d, viol X/g/u/h/z = "
          "%d/%d/%d/%d/%d, z digest %s"
          % (li, sh_g, sh_u, sh_h, sh_z, xclip, vg, vu, vh, vz,
             row["digests"]["z"][:16]))
        return (z8 * (2.0 ** sc["eZ"])).astype(np.float32).reshape(
            B, T, C)

    walker.walk(seq[:, :-1], ffn_override=ffn)
    total_viol = viol["count"]
    p("range-fact violations across the pass: %d (0 required — the "
      "proof would reject BY DESIGN otherwise)" % total_viol)
    outside = sorted(set(s for s in shift_band if not 5 <= s <= 10))
    if outside:
        p("** remainder widths outside the rig's asserted 5..=10 band: "
          "%s — memo Section 2 W-7 applies **" % outside)
    manifest["range_violations"] = total_viol
    manifest["shift_widths_outside_5_10"] = outside
    assert total_viol == 0, "witness does not satisfy the statement"

    (out_dir / "manifest.json").write_text(json.dumps(manifest,
                                                      indent=1))
    # The sidecar the rig parses (bf_sidecar: "<layer> <name> <rest>";
    # the model/dims/exps names are the W-5 loader's rows, inert today).
    lines = ["00 model %s" % arch.tag.replace(" ", "_"),
             "00 dims %d %d %d %d" % (args.t, arch.d, arch.f,
                                      arch.n_layers)]
    for r in manifest["layers"]:
        li = r["layer"]
        for name in ("X", "WgT", "WuT", "WdT", "z"):
            lines.append("%02d %s %s" % (li, name, r["digests"][name]))
        s = r["shifts"]
        lines.append("%02d shifts %d %d %d %d" % (li, s["g"], s["u"],
                                                  s["h"], s["z"]))
        lines.append("%02d exps %d %d %d %d %d %d %d %d %d"
                     % (li, r["eX"], r["eGate"], r["eA"], r["eUp"],
                        r["eH"], r["eZ"], r["eWg"], r["eWu"], r["eWd"]))
    (out_dir / "digests.txt").write_text("\n".join(lines) + "\n")
    p("manifest -> %s (+ digests.txt sidecar)"
      % (out_dir / "manifest.json"))
    if fresh:
        p("REMINDER: %d new SiLU member(s) need the W-6 freeze ruling "
          "before the rig can prove this export" % len(fresh))
    p("peak RSS %.2f GB" % m8b.rss_gb())


if __name__ == "__main__":
    main()
