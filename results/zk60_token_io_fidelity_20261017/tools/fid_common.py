#!/usr/bin/env python3
"""Token-head fidelity lane: shared helpers (loads the copied calibration tools).

Calibration data, not a proof, not a privacy claim.
"""

from __future__ import annotations

import sys

sys.dont_write_bytecode = True   # never write __pycache__ into read-only trees (importer dir)

import hashlib  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import time  # noqa: E402
from pathlib import Path  # noqa: E402

for _k in ("OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS", "MKL_NUM_THREADS", "NUMEXPR_NUM_THREADS"):
    os.environ.setdefault(_k, "2")

TOOLS = Path(__file__).resolve().parent
LANE = TOOLS.parent
DATA = LANE / "data"
sys.path.insert(0, str(TOOLS))
# tlcalib derives its importer path from its own location (two levels up = the repo); the copies live one
# level deeper here, so put the (read-only) checkpoint importer on the path explicitly
sys.path.insert(0, "/home/victor/IntelligenceRegulation/results/zk60_1b_checkpoint_20260927")

import numpy as np  # noqa: E402

import tlcalib as tc  # noqa: E402
import b3calib as b3  # noqa: E402

REPO = Path("/home/victor/IntelligenceRegulation")
CAL = REPO / "results" / "zk60_1b_calibration_20260929"
EXPORTS = {128: CAL / "export" / "pg_rot1_b4_T128", 64: CAL / "export" / "pg_rot1_b4_T64_cal128",
           32: CAL / "export" / "pg_rot1_b4_T32_cal128"}
DT = {"int8": "<i1", "int16": "<i2", "int64": "<i8"}


def log(msg: str):
    print(f"[{time.strftime('%H:%M:%S', time.gmtime())}Z] {msg}", flush=True)


def sha_bytes(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def export_profile(T: int) -> dict:
    return json.loads((EXPORTS[T] / "profile.json").read_text())


def export_scales(T: int):
    meta = export_profile(T)["metadata_out_of_proof"]
    return float(meta["residual_scales_in"][0]), float(meta["residual_scales_out"][-1])


def export_rotation(T: int) -> np.ndarray:
    root = EXPORTS[T]
    meta = export_profile(T)["metadata_out_of_proof"]
    raw = (root / "rotation_sign.bin").read_bytes()
    assert sha_bytes(raw) == meta["rotation"]["sign_sha256"], "rotation_sign.bin sha256 mismatch"
    sign = np.frombuffer(raw, dtype="<f8").copy()
    R = b3.Rotation(tc.GEO.d, int(meta["rotation"]["seed"]))
    assert np.array_equal(R.sign, sign), "rotation seed does not reproduce rotation_sign.bin"
    return sign


def load_layer(T: int, l: int) -> tuple:
    """(LayerInt, rope (cos, sin)) of layer l from the export binaries, every sha256 checked
    (the b3_verify_export.py loading rule)."""
    root = EXPORTS[T]
    prof = export_profile(T)
    ent = prof["layers"][l]
    d = root / ent["dir"]
    mb = (d / "manifest.json").read_bytes()
    assert sha_bytes(mb) == ent["manifest_sha256"], f"{ent['dir']}: manifest sha256 differs from profile.json"
    man = json.loads(mb)
    c = man["constants"]
    A = {}
    for name, spec in man["arrays"].items():
        raw = (d / spec["file"]).read_bytes()
        assert sha_bytes(raw) == spec["sha256"], f"{ent['dir']}/{name}: sha256 mismatch"
        A[name] = np.frombuffer(raw, dtype=DT[spec["dtype"]]).reshape(spec["shape"])
    g = tc.GEO
    rc, rs = b3.rope_generate(T, g.dh, c["rope_theta"], c["f_ro"])
    assert np.array_equal(A["rope_cos"], rc) and np.array_equal(A["rope_sin"], rs), "rope tables differ"
    P = tc.LayerInt(wq=A["wq"], wk=A["wk"], wv=A["wv"], wo=A["wo"], gamma_a=A["gamma_a"], gamma_m=A["gamma_m"],
                    wg_t=A["wg_t"], wu_t=A["wu_t"], wd_t=A["wd_t"], exp=A["exp"].astype(np.int64), act=A["act"],
                    cn_a=c["norm_cn_a"], cn_m=c["norm_cn_m"], tn=c["norm_tn"], ceps=c["norm_ceps"],
                    norm_wrho=tc.norm_window(g.d, c["norm_tn"]), sh_qkv=c["sh_qkv"], sh_rope=c["sh_rope"],
                    sh_s=c["sh_s"], sh_o=c["sh_o"], sh_ao=c["sh_ao"], sh_g=c["sh_g"], sh_u=c["sh_u"], sh_h=c["sh_h"],
                    sh_z=c["sh_z"], f_e=c["f_e"], f_p=c["f_p"], f_ro=c["f_ro"], sh_r2=c["sh_r2"])
    return P, (rc, rs), c


def embedding_table(T: int) -> np.ndarray:
    root = EXPORTS[T]
    tio = json.loads((root / "token_io.json").read_text())
    spec = tio["embedding_table"]
    raw = (root / spec["file"]).read_bytes()
    assert sha_bytes(raw) == spec["sha256"], "embedding table sha256 mismatch"
    return np.frombuffer(raw, dtype="<i2").reshape(spec["shape"])


def exported_sequences(T: int) -> dict:
    """{name: (heldout_index, token_ids, x_in_L00, x_out_L21)} of the export."""
    root = EXPORTS[T]
    out = {}
    for sname in export_profile(T)["sequences"]:
        sm = json.loads((root / sname / "manifest.json").read_text())
        x_in = np.frombuffer((root / sname / "x_in_L00.bin").read_bytes(), dtype="<i2").reshape(T, -1)
        x_out = np.frombuffer((root / sname / "x_out_L21.bin").read_bytes(), dtype="<i2").reshape(T, -1)
        out[sname] = (int(sm["heldout_index"]), np.array(sm["token_ids"], dtype=np.int64), x_in, x_out)
    return out


def int_stack(ids: np.ndarray, T: int, chunk: int = 6, keep_layers: bool = False, progress: bool = True):
    """The exact integer stack (tlcalib.i_block, the native relations) on token ids (N, T), layer by layer
    from the export binaries. Returns (x_out_L21 int16 (N, T, d), per-sequence first refusal or None,
    per-layer site summaries[, list of per-layer outputs])."""
    table = embedding_table(T)
    x = table[ids].astype(np.int64)
    N = ids.shape[0]
    first = [None] * N
    summaries = []
    layers = [] if keep_layers else None
    n_layers = len(export_profile(T)["layers"])
    for l in range(n_layers):
        t0 = time.time()
        P, rope, _ = load_layer(T, l)
        rec = tc.Rec(N)
        x = np.concatenate([tc.i_block(x[s:s + chunk], P, rope, rec, seq0=s) for s in range(0, N, chunk)])
        for i, f in enumerate(rec.first):
            if f is not None and first[i] is None:
                first[i] = {"layer": l, "site": f}
        summaries.append(rec.summary())
        if keep_layers:
            layers.append(x.astype(np.int16))
        del P
        if progress:
            log(f"  int stack T{T} L{l:02d}: {N} seqs, refused so far {sum(f is not None for f in first)} ({time.time() - t0:.0f}s)")
    return x.astype(np.int16), first, summaries, layers


def jdump(obj) -> str:
    return tc.jdump(obj)
