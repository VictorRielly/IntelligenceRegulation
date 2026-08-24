#!/usr/bin/env python3
"""m8b_verify_125m.py — U-PERF3 lane R: validation of the m8b scripts on
hardware we have BEFORE the Mac 7B run (Grok's T12 gate).

Four steps, each PASS/FAIL, summary at the end (exit 1 on any FAIL):

  reader   The streaming per-tensor safetensors reader (TensorStore seek
           reads) reproduces the m125 whole-file reader EXACTLY on the
           real 125M checkpoint (every tensor byte-equal as fp32).
  synth    A synthetic SHARDED HuggingFace-format checkpoint (2 shards +
           model.safetensors.index.json, BF16, Mistral naming, GQA) is
           built from a seed and the FULL hf pipeline runs on it:
           calibration -> export -> rig-layout checks on digests.txt
           (per-layer X/WgT/WuT/WdT/z/shifts lines + the model/dims/exps
           rows). This is the only place the hf naming + index path is
           exercised off-Mac (no 7B checkpoint on this box).
  export   m8b_export_ffn --arch frugal on the REAL 125M checkpoint with
           the COMMITTED m125 calibration JSON: all 36 weight digests
           must be BYTE-IDENTICAL to results/m125_ffn_export_wsl (which
           equals the Mac export for weights), all 12 shifts lines
           identical; the X/z digests are compared and REPORTED (they
           are expected to differ at the few-int8-element level: the X
           walk's fp32 attention runs under numpy here vs mlx there —
           the same effect as the documented Mac-vs-WSL mlx delta); the
           export itself asserts 0 range-fact violations.
  cal      m8b_int8_calibration --arch frugal on the 125M: all 12x9
           calibrated exponents must equal the committed
           results/m125_int8_calibration.json table; the bf16 reference
           val loss must match within 0.02 nats; variant A must have 0
           range violations. (The A loss delta is compared loosely: the
           m8b chain uses the FROZEN SiLU table where the m125 study
           used np.round — a deliberate, documented difference.)

Outputs land under results/m8b_test/ (binaries gitignored; the reexport
digests.txt/manifest.json are the committable evidence).

Run: python3 scripts/m8b_verify_125m.py            (all steps, ~10 min)
     python3 scripts/m8b_verify_125m.py --skip-cal (skip the slow step)
"""

import argparse
import json
import os
import struct
import subprocess
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import m125_int8_calibration as m125  # noqa: E402
import m8b_int8_calibration as m8b    # noqa: E402

CKPT_125M = Path(os.environ.get(
    "M8B_TEST_CKPT",
    "/home/victor/models/125m-best-adamw-val3.0816/model.safetensors"))
TOKENS_125M = Path(os.environ.get("M8B_TEST_TOKENS",
                                  "/home/victor/shard-00000.npy"))
REF_EXPORT = ROOT / "results" / "m125_ffn_export_wsl"
REF_CAL = ROOT / "results" / "m125_int8_calibration.json"
OUT = ROOT / "results" / "m8b_test"

CHECKS = []


def check(name, ok, detail=""):
    CHECKS.append((name, ok, detail))
    print("  [%s] %s%s" % ("PASS" if ok else "FAIL", name,
                           (" — " + detail) if detail else ""),
          flush=True)


def run_script(script, args, log_name):
    OUT.mkdir(parents=True, exist_ok=True)
    log = OUT / log_name
    cmd = [sys.executable, str(ROOT / "scripts" / script)] + args
    with open(log, "w") as f:
        r = subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT)
    if r.returncode != 0:
        print("  --- %s failed; last lines of %s ---" % (script, log))
        print("\n".join(log.read_text().splitlines()[-15:]))
    return r.returncode, log


def read_sidecar(path):
    m = {}
    for line in Path(path).read_text().splitlines():
        parts = line.split()
        m[(int(parts[0]), parts[1])] = " ".join(parts[2:])
    return m


# --------------------------------------------------------------------------
# step 1 — reader equivalence on the real 125M file
# --------------------------------------------------------------------------

def step_reader():
    print("STEP reader — streaming seek reads == whole-file reader "
          "(125M, all tensors)")
    whole = m125.read_safetensors(CKPT_125M)
    store = m8b.TensorStore(CKPT_125M)
    bad = []
    for name, ref in whole.items():
        got = store.get(name)
        if got.shape != tuple(ref.shape) or not np.array_equal(
                got, ref.astype(np.float32)):
            bad.append(name)
    check("reader: %d tensors byte-equal as fp32" % len(whole),
          not bad, ("mismatches: %s" % bad[:5]) if bad else "")


# --------------------------------------------------------------------------
# step 2 — synthetic sharded HF checkpoint through the full hf pipeline
# --------------------------------------------------------------------------

SYNTH = dict(layers=2, d=64, f=128, heads=4, kv=2, vocab=256, t=32)


def write_safetensors(path, tensors):
    """Minimal safetensors writer (BF16 by truncation — synthetic only)."""
    hdr, blobs, off = {}, [], 0
    for name, arr in tensors.items():
        u32 = np.ascontiguousarray(arr.astype(np.float32)).view(np.uint32)
        bf = (u32 >> 16).astype("<u2").tobytes()
        hdr[name] = {"dtype": "BF16", "shape": list(arr.shape),
                     "data_offsets": [off, off + len(bf)]}
        blobs.append(bf)
        off += len(bf)
    hj = json.dumps(hdr).encode()
    with open(path, "wb") as f:
        f.write(struct.pack("<Q", len(hj)))
        f.write(hj)
        for b in blobs:
            f.write(b)


def build_synth_ckpt(dirp):
    s = SYNTH
    rng = np.random.default_rng(20260823)
    dirp.mkdir(parents=True, exist_ok=True)

    def w(shape, scale):
        return (rng.standard_normal(shape) * scale).astype(np.float32)

    d, f, hd = s["d"], s["f"], s["d"] // s["heads"]
    kvd = s["kv"] * hd
    shard1, shard2 = {}, {}
    shard1["model.embed_tokens.weight"] = w((s["vocab"], d), 0.5)
    for l in range(s["layers"]):
        t = shard1 if l == 0 else shard2
        pre = "model.layers.%d." % l
        t[pre + "input_layernorm.weight"] = np.ones(d, np.float32)
        t[pre + "self_attn.q_proj.weight"] = w((d, d), d ** -0.5)
        t[pre + "self_attn.k_proj.weight"] = w((kvd, d), d ** -0.5)
        t[pre + "self_attn.v_proj.weight"] = w((kvd, d), d ** -0.5)
        t[pre + "self_attn.o_proj.weight"] = w((d, d), d ** -0.5)
        t[pre + "post_attention_layernorm.weight"] = np.ones(d, np.float32)
        t[pre + "mlp.gate_proj.weight"] = w((f, d), d ** -0.5)
        t[pre + "mlp.up_proj.weight"] = w((f, d), d ** -0.5)
        t[pre + "mlp.down_proj.weight"] = w((d, f), f ** -0.5)
    shard2["model.norm.weight"] = np.ones(d, np.float32)
    shard2["lm_head.weight"] = w((s["vocab"], d), 0.5)
    fn1, fn2 = ("model-00001-of-00002.safetensors",
                "model-00002-of-00002.safetensors")
    write_safetensors(dirp / fn1, shard1)
    write_safetensors(dirp / fn2, shard2)
    wm = {k: fn1 for k in shard1}
    wm.update({k: fn2 for k in shard2})
    (dirp / "model.safetensors.index.json").write_text(
        json.dumps({"weight_map": wm}))
    (dirp / "config.json").write_text(json.dumps(dict(
        num_hidden_layers=s["layers"], hidden_size=d,
        intermediate_size=f, num_attention_heads=s["heads"],
        num_key_value_heads=s["kv"], vocab_size=s["vocab"],
        rms_norm_eps=1e-5, rope_theta=10000.0,
        tie_word_embeddings=False, sliding_window=4096,
        _name_or_path="synth-mistral-arch")))
    toks = rng.integers(0, s["vocab"], size=20000).astype(np.uint16)
    np.save(dirp / "tokens.npy", toks)


def step_synth():
    print("STEP synth — sharded HF-format checkpoint through the full "
          "hf pipeline")
    s = SYNTH
    ck = OUT / "synth_hf"
    build_synth_ckpt(ck)
    common = ["--ckpt", str(ck), "--arch", "hf",
              "--tokens", str(ck / "tokens.npy"),
              "--t", str(s["t"]), "--cal-seqs", "4", "--val-seqs", "4"]
    rc, _ = run_script("m8b_int8_calibration.py",
                       common + ["--out-json",
                                 str(OUT / "synth_cal.json")],
                       "synth_cal.log")
    check("synth: calibration runs (sharded index, hf naming)", rc == 0)
    if rc != 0:
        return
    rc, _ = run_script("m8b_export_ffn.py",
                       common + ["--cal-json",
                                 str(OUT / "synth_cal.json"),
                                 "--out", str(OUT / "synth_export"),
                                 "--no-ckpt-sha"],
                       "synth_export.log")
    check("synth: export runs (0 violations asserted inside)", rc == 0)
    if rc != 0:
        return
    side = read_sidecar(OUT / "synth_export" / "digests.txt")
    want_names = {"X", "WgT", "WuT", "WdT", "z", "shifts", "exps"}
    ok = all((l, n) in side for l in range(s["layers"])
             for n in want_names)
    ok = ok and (0, "dims") in side and (0, "model") in side
    ok = ok and side[(0, "dims")] == "%d %d %d %d" % (
        s["t"], s["d"], s["f"], s["layers"])
    check("synth: digests.txt has the rig rows + W-5 model/dims/exps "
          "rows", ok, side.get((0, "dims"), "MISSING"))
    sizes = dict(X=s["t"] * s["d"], WgT=s["d"] * s["f"],
                 WuT=s["d"] * s["f"], WdT=s["f"] * s["d"])
    ok = all((OUT / "synth_export" / ("layer%02d_%s.bin" % (l, n))
              ).stat().st_size == sz
             for l in range(s["layers"]) for n, sz in sizes.items())
    check("synth: bin sizes are the rig's expected T*d/d*f/f*d int8", ok)


# --------------------------------------------------------------------------
# step 3 — the real 125M through the frugal adapter vs the committed export
# --------------------------------------------------------------------------

def step_export():
    print("STEP export — m8b export of the REAL 125M vs the committed "
          "m125 reference")
    out = OUT / "m125_reexport"
    rc, _ = run_script(
        "m8b_export_ffn.py",
        ["--ckpt", str(CKPT_125M), "--arch", "frugal",
         "--cal-json", str(REF_CAL),
         "--tokens", str(TOKENS_125M),
         "--out", str(out)],
        "m125_reexport.log")
    check("export: frugal-arch export runs (asserts 0 violations)",
          rc == 0)
    if rc != 0:
        return
    ref = read_sidecar(REF_EXPORT / "digests.txt")
    got = read_sidecar(out / "digests.txt")
    wbad = [(l, n) for l in range(12) for n in ("WgT", "WuT", "WdT")
            if ref[(l, n)] != got[(l, n)]]
    check("export: 36/36 weight digests BYTE-IDENTICAL to the reference",
          not wbad, str(wbad[:4]) if wbad else "")
    sbad = [l for l in range(12) if ref[(l, "shifts")] != got[(l, "shifts")]]
    check("export: 12/12 shifts lines identical", not sbad,
          str(sbad) if sbad else "")
    xmatch = sum(ref[(l, "X")] == got[(l, "X")] for l in range(12))
    zmatch = sum(ref[(l, "z")] == got[(l, "z")] for l in range(12))
    print("  [INFO] X digests matching the mlx reference: %d/12, z: "
          "%d/12 (differences at the few-int8-element level are the "
          "expected numpy-vs-mlx fp32 drift; NOT a failure — the m8b "
          "export is its own valid witness, like the wsl re-export)"
          % (xmatch, zmatch))


# --------------------------------------------------------------------------
# step 4 — the real 125M calibration vs the committed exponent table
# --------------------------------------------------------------------------

def step_cal():
    print("STEP cal — m8b calibration of the REAL 125M vs the committed "
          "study (the slow step)")
    outj = OUT / "m125_recal.json"
    rc, _ = run_script(
        "m8b_int8_calibration.py",
        ["--ckpt", str(CKPT_125M), "--arch", "frugal",
         "--tokens", str(TOKENS_125M), "--out-json", str(outj)],
        "m125_recal.log")
    check("cal: frugal-arch calibration runs", rc == 0)
    if rc != 0:
        return
    ref = json.loads(REF_CAL.read_text())
    got = json.loads(outj.read_text())
    keys = ("eX", "eGate", "eUp", "eA", "eH", "eZ", "eWg", "eWu", "eWd")
    bad = [(l, k) for l in range(12) for k in keys
           if ref["calibration"][l][k] != got["calibration"][l][k]]
    check("cal: 108/108 calibrated exponents equal the committed table",
          not bad, str(bad[:6]) if bad else "")
    dref = ref["verdict"]["loss_ref"]
    dgot = got["verdict"]["loss_ref"]
    check("cal: bf16 reference val loss within 0.02 nats",
          abs(dref - dgot) < 0.02,
          "committed %.4f vs m8b %.4f" % (dref, dgot))
    va = got["verdict"]["range_violations"]["A"]
    check("cal: variant A has 0 range violations", va == 0, str(va))
    aref = ref["verdict"]["loss_delta_nats"]["A"]
    agot = got["verdict"]["loss_delta_nats"]["A"]
    print("  [INFO] variant A loss delta: committed %+.4f vs m8b %+.4f "
          "(loose compare: m8b uses the FROZEN SiLU table, the study "
          "used np.round)" % (aref, agot))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--skip-reader", action="store_true")
    ap.add_argument("--skip-synth", action="store_true")
    ap.add_argument("--skip-export", action="store_true")
    ap.add_argument("--skip-cal", action="store_true")
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    # binaries + logs stay out of git; the m125_reexport digests.txt and
    # manifest.json are the committable evidence (its own .gitignore
    # already excludes the .bin files)
    (OUT / ".gitignore").write_text(
        "synth_hf/\nsynth_export/\n*.log\n/synth_cal.json\n"
        "/m125_recal.json\n")
    if not args.skip_reader:
        step_reader()
    if not args.skip_synth:
        step_synth()
    if not args.skip_export:
        step_export()
    if not args.skip_cal:
        step_cal()
    print()
    nbad = sum(1 for _, ok, _ in CHECKS if not ok)
    print("SUMMARY: %d checks, %d FAIL" % (len(CHECKS), nbad))
    for name, ok, detail in CHECKS:
        if not ok:
            print("  FAIL %s %s" % (name, detail))
    sys.exit(1 if nbad else 0)


if __name__ == "__main__":
    main()
