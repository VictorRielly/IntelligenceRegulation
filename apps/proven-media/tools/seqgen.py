#!/usr/bin/env python3
"""Proven Media, stub prover helper: build the PROVER-PRIVATE sequence directory of one prompt.

`zk60_token_io prove` takes the hidden prompt (a 0600 token-id file) AND the prompt's hidden
activations (`--seq-dir`): x_in_LNN / x_out_LNN for every layer, against which its sealing pass
checks bit-exact parity. The export ships these only for its calibration hold-out sequences, so a
post written in the app needs them built first. This tool chains the prompt through the
calibration lane's integer reference `tlcalib.i_block` at the export's own layer words and
constants (the route of the fidelity lane's `fp_export.py`; all imports read-only), refuses a
prompt that leaves any integer range at any layer (the prover would refuse it too), and writes:

    OUT/x_in_LNN.bin, OUT/x_out_LNN.bin   int16 [T, d], mode 0600
    OUT/manifest.json                      arrays (file, dtype, shape, sha256), token_ids, T

OUT is created 0700 and must not exist. Nothing hidden is printed: one JSON line with counts and
seconds only (refusals name the layer and the integer site, never a value).

usage: seqgen.py --export DIR --prompt-file FILE --out DIR [--crosscheck]
       seqgen.py --export DIR --prompt-file FILE --compare-seq DIR      (self-test, writes nothing)

`--compare-seq` rebuilds and compares byte for byte with an existing sequence directory (the
acceptance test: the export's own seq_ho00). Exit 0 ok, 3 refused (range), 2 bad input.
Calibration code, not a proof and not a privacy claim. Run under the resource guard.
"""
from __future__ import annotations

import os

for _k in ("OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS", "MKL_NUM_THREADS", "NUMEXPR_NUM_THREADS"):
    os.environ.setdefault(_k, "1")

import argparse  # noqa: E402
import hashlib  # noqa: E402
import json  # noqa: E402
import stat  # noqa: E402
import sys  # noqa: E402
import time  # noqa: E402
from pathlib import Path  # noqa: E402

import numpy as np  # noqa: E402

FP = Path("/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019")
sys.path.insert(0, str(FP))
import fp_lib as fl  # noqa: E402
from fp_selfcheck import layerint  # noqa: E402

tc = fl.tc


def say(**kw):
    print(json.dumps(kw), flush=True)


def read_prompt(path: Path) -> list[int]:
    st = os.stat(path, follow_symlinks=False)
    if not stat.S_ISREG(st.st_mode) or st.st_mode & 0o077:
        raise SystemExit(f"{path}: not a regular file of mode 0600")
    return [int(x) for x in path.read_text().replace(",", " ").split()]


def write_bin(dirp: Path, name: str, arr: np.ndarray) -> dict:
    a = np.ascontiguousarray(arr).astype("<i2")
    raw = a.tobytes()
    p = dirp / f"{name}.bin"
    fd = os.open(p, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "wb") as f:
        f.write(raw)
    return {"file": p.name, "dtype": "int16", "shape": list(a.shape), "sha256": hashlib.sha256(raw).hexdigest()}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--export", required=True)
    ap.add_argument("--prompt-file", required=True)
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--out")
    g.add_argument("--compare-seq")
    ap.add_argument("--crosscheck", action="store_true", help="also check fp_lib.rx_block == i_block per layer")
    a = ap.parse_args()
    t0 = time.time()
    ex = fl.Export(Path(a.export))
    T, L = ex.T, ex.L
    ids = read_prompt(Path(a.prompt_file))
    if len(ids) != T:
        say(event="refused", stage="input", reason=f"the prompt holds {len(ids)} ids; this export proves exactly T = {T}")
        return 2
    if ids[0] != fl.BOS:
        say(event="refused", stage="input", reason=f"the prompt must start with BOS ({fl.BOS})")
        return 2
    tab = ex.embedding_table()
    if max(ids) >= tab.shape[0] or min(ids) < 0:
        say(event="refused", stage="input", reason="a token id is outside the vocabulary")
        return 2
    x = np.asarray(tab[np.array(ids, dtype=np.int64)], dtype=np.int64)[None]
    out = cmp_dir = None
    if a.out:
        out = Path(a.out)
        out.mkdir(mode=0o700)          # must not exist
        os.chmod(out, 0o700)
    else:
        cmp_dir = Path(a.compare_seq)
    files, mismatches = {}, []
    for l in range(L):
        Lw = ex.layer(l)                      # words sha256-checked against the layer manifest
        w = Lw["w"]
        P = layerint(Lw)
        rope = (w["rope_cos"].reshape(T, -1).astype(np.int64), w["rope_sin"].reshape(T, -1).astype(np.int64))
        rec = tc.Rec(1)
        y = tc.i_block(x, P, rope, rec)
        s = rec.summary()
        if s["sequences_refused"]:
            say(event="refused", stage="integer-range", layer=l, sites=s["first_refusal_sites"],
                reason=f"the integer model leaves a range at layer {l} ({', '.join(s['first_refusal_sites'])}); the prover would refuse this prompt",
                seconds=round(time.time() - t0, 1))
            return 3
        if a.crosscheck:
            yr = fl.rx_block(x.astype(np.float64), fl.LayerModel(Lw, T), frozenset(fl.SITES), None)
            if not np.array_equal(yr.astype(np.int64), y):
                say(event="refused", stage="crosscheck", layer=l, reason="rx_block != i_block")
                return 3
        if np.abs(y).max() > 32767:
            say(event="refused", stage="integer-range", layer=l, reason="a block output leaves int16")
            return 3
        if out is not None:
            files[f"x_in_L{l:02d}"] = write_bin(out, f"x_in_L{l:02d}", x[0])
            files[f"x_out_L{l:02d}"] = write_bin(out, f"x_out_L{l:02d}", y[0])
        else:
            for nm, arr in ((f"x_in_L{l:02d}", x[0]), (f"x_out_L{l:02d}", y[0])):
                ref = (cmp_dir / f"{nm}.bin").read_bytes()
                if np.ascontiguousarray(arr).astype("<i2").tobytes() != ref:
                    mismatches.append(nm)
        x = y
    if out is not None:
        man = {"schema": "zk60-trained-profile-export/1", "kind": "sequence", "id": "proven-media-post",
               "T": T, "token_ids": ids, "accepted_at_every_layer": True, "arrays": files,
               "basis": "rotated residual (the export's rotation)",
               "selection": "a Proven Media post (prover-private); chained through tlcalib.i_block at the export's words by apps/proven-media/tools/seqgen.py",
               "export": str(ex.root)}
        fd = os.open(out / "manifest.json", os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, "w") as f:
            json.dump(man, f, indent=1, sort_keys=True)
        say(event="seq-built", layers=L, T=T, accepted_at_every_layer=True, crosscheck=bool(a.crosscheck),
            seconds=round(time.time() - t0, 1))
        return 0
    ok = not mismatches
    say(event="seq-compared", layers=L, arrays=2 * L, byte_identical=ok, mismatched=mismatches,
        seconds=round(time.time() - t0, 1))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
