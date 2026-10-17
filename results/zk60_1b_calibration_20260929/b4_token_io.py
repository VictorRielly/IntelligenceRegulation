#!/usr/bin/env python3
"""Lane B4: reference implementation of export/TOKEN_IO_SPEC.md and its check.

  tokens -> x_in_L00   (table lookup, and the float recomputation it encodes)
  x_out_L21 -> logits  (unrotate, float32 RMSNorm, LM head)

Self-check on an export (reads the export + the pinned checkpoint):
  * embedding_int16.bin sha256 matches token_io.json, table[tokens] equals every
    exported sequence's x_in_L00, and the float recomputation equals the table
    on those tokens;
  * the logits from x_out_L21 vs the float model's logits on the same tokens:
    top-1 agreement per sequence (diagnostic, the model forward in float32).
Usage: b4_token_io.py <export dir>. Calibration data, not a proof.
"""

from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np  # noqa: E402

import tlcalib as tc  # noqa: E402


def butterfly(y: np.ndarray) -> np.ndarray:
    """In-place Sylvester butterfly along the last axis, h = 1, 2, 4, ... (float64)."""
    y = np.array(y, dtype=np.float64, copy=True)
    n = y.shape[-1]
    h = 1
    while h < n:
        for i in range(0, n, 2 * h):
            a = y[..., i:i + h].copy()
            b = y[..., i + h:i + 2 * h].copy()
            y[..., i:i + h] = a + b
            y[..., i + h:i + 2 * h] = a - b
        h *= 2
    return y


def rot_forward(x, sign):
    return butterfly(np.asarray(x, dtype=np.float64) * sign) / math.sqrt(sign.size)


def rot_inverse(xr, sign):
    return butterfly(np.asarray(xr, dtype=np.float64)) * sign / math.sqrt(sign.size)


def embed_int(tokens, E, s_in, sign=None):
    """steps 1-3 of the spec (float recomputation of the table rows)."""
    x = E[np.asarray(tokens)]
    if sign is not None:
        x = rot_forward(x, sign).astype(np.float32)
    q = np.floor(x.astype(np.float64) / s_in + 0.5)
    if np.abs(q).max() > 32767:
        raise ValueError("refusal: an input word leaves int16")
    return q.astype(np.int16)


def head_logits(x_out, s_out, norm_w, lm_head, sign=None, eps=1e-5):
    xr = np.asarray(x_out, dtype=np.float64) * s_out
    x = (rot_inverse(xr, sign) if sign is not None else xr).astype(np.float32)
    var = np.mean(x * x, axis=-1, keepdims=True, dtype=np.float32)
    h = (x / np.sqrt(var + np.float32(eps))).astype(np.float32) * norm_w
    return h @ lm_head.T


def main(root: Path):
    prof = json.loads((root / "profile.json").read_text())
    tio = json.loads((root / "token_io.json").read_text())
    meta = prof["metadata_out_of_proof"]
    s_in, s_out = meta["residual_scales_in"][0], meta["residual_scales_out"][-1]
    sign = None
    if meta.get("rotation"):
        raw = (root / "rotation_sign.bin").read_bytes()
        assert hashlib.sha256(raw).hexdigest() == meta["rotation"]["sign_sha256"]
        sign = np.frombuffer(raw, dtype="<f8")
    spec = tio["embedding_table"]
    raw = (root / spec["file"]).read_bytes()
    errs = []
    if hashlib.sha256(raw).hexdigest() != spec["sha256"]:
        errs.append("embedding table sha256 mismatch")
    table = np.frombuffer(raw, dtype="<i2").reshape(spec["shape"])
    ck = tc.open_checkpoint()
    E = tc.tensor_f32(ck.refs["model.embed_tokens.weight"])
    norm_w = tc.tensor_f32(ck.refs["model.norm.weight"])
    lm_head = tc.tensor_f32(ck.refs["lm_head.weight"])
    T = prof["T"]
    rope = tc.rope_f32(T)
    rep = {}
    for sname in prof["sequences"]:
        sm = json.loads((root / sname / "manifest.json").read_text())
        toks = np.array(sm["token_ids"])
        x_in = np.frombuffer((root / sname / "x_in_L00.bin").read_bytes(), dtype="<i2").reshape(T, -1)
        x_out = np.frombuffer((root / sname / "x_out_L21.bin").read_bytes(), dtype="<i2").reshape(T, -1)
        if not np.array_equal(table[toks], x_in):
            errs.append(f"{sname}: table[tokens] != x_in_L00")
        if not np.array_equal(embed_int(toks, E, s_in, sign), x_in):
            errs.append(f"{sname}: float recomputation != x_in_L00")
        # the float model on the same tokens (original basis)
        x = E[toks][None]
        for l in range(ck.config["layers"]):
            x = tc.f_block(x, tc.layer_f32(ck, l), *rope)
        lf = tc.f_head(x[0], norm_w, lm_head)
        li = head_logits(x_out, s_out, norm_w, lm_head, sign)
        rep[sname] = {"top1_agreement_with_float": float((lf.argmax(-1) == li.argmax(-1)).mean()),
                      "positions": int(T), "source": sm["source"].get("domain", sm["source"].get("source"))}
    out = {"export": str(root), "errors": errs, "ok": not errs, "sequences": rep}
    print(json.dumps(out, indent=1))
    return 0 if not errs else 1


if __name__ == "__main__":
    sys.exit(main(Path(sys.argv[1])))
