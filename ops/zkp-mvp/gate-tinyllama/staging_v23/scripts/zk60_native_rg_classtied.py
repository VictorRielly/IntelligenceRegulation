#!/usr/bin/env python3
"""[GATE ROUND 18, tools v21, 2026-10-29] B-3 with the classifier's tables
DERIVED, not taken (rung R-C2, token frozen-r14): the gate re-derives the
development rung's embedding and margin row from the PINNED synthetic tied
tensor, exactly as the token lane's `classify_tied.rs::derive_dev` does, and
then (in `zk60_native_rg_classterminals`) rebuilds from them the two public
tables v20 still took from the capture: the IN-C table column `tau` (the
embedding folded at the replayed `r_emb`) and OUT-C's margin vector
`w_Delta`.

READ [token frozen-r14, list 0b4c429b...]:

* `token_io/classify_tied.rs` (401d38d4): `DEV_TIED_TENSOR_SHA256 =
  bba6d094...` (:72), `DEV_TIED_V = 300`, `DEV_TIED_D = 384` (:74-75); the
  tensor is `V x d` BF16 rows then the `d` final-norm weights, little-endian;
  its bytes are those of the pinned generator `dev_tied_tensor_bytes`
  (:509-520, an LCG seeded 0x74696564_2d646576; the pin IS those bytes);
  `derive_dev` (:292-324): `emb = q(f64(f32(x)) / residual_unit)` into
  [-32768, 32767] per row value, `w_i = q((E[yes][i] - E[no][i]) * g[i] /
  scale)` into [-32767, 32767], `q(x) = floor(x + 0.5)`, refusal (never a
  clamp) outside the class; no rotation at the rung.
* native R12b `tied_tables/derive.rs` (5cebeef0 in the token tree):
  `bf16` (:113-117, `f32::from_bits(u16 << 16) as f64`), `quantize`
  (:180-187, `(value / scale + 0.5).floor()`, refusal outside [low, high]).
* `token_io/classify.rs` (6c828db6): `ClassifierTables::emb_digest`
  (:313-322, BLAKE3 over "hashline/classify/embedding-int16/v1", V u64, d
  u64, the int16 words LE) and `emb_fold` (:337-344, `E~(v, r) = sum_{i < d}
  eq_msb(r)[i] E[v][i]`, exact field addition); `stage_in_c.rs::tau_table`
  (6a92da0e :158-164): `tau(v) = v + beta E~(v, r_emb) + beta^2 ctl(v) +
  g_emb` for v < V, padded rows repeat row 0's whole tuple.
* The residual unit (the export's `residual_scale_s_x`) is not in a
  capture: it is a constant of the rung's tiny export
  (`trained_block_tests.rs:177` at frozen-r14, 0.0053663705198366135),
  inside the profile digest the trained statement binds.  The gate takes it
  as a READ constant and CONFIRMS it: the embedding derived with it must hash
  to the statement's `embedding_digest`, and the IN-C tau rebuilt from that
  embedding must equal the captured table digest for digest.

The reviewer's independent reference (REVIEW_R13 §5,
`results/zk60_token_io_review_r1_20261017/r13/rv13_dev_tied_reference.json`)
gives the tensor sha256 bba6d094..., the int16 embedding's SHA-256
c0e816c9... and the dev policy's margin row SHA-256 24e6ff4c... (exact vs
binary64: 0 disagreements); `derive_dev` below reproduces all three (unit
test `ClassifierV21`).

NOTHING HERE IS A PRIVACY RESULT OR A PRIVACY ACCEPTANCE.
"""

from __future__ import annotations

import hashlib
import math
import os
import re
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from zk60_native_jv_field import P, eq_table_msb, f2_add, f2_mul, f2_mul_base  # noqa: E402

DEV_TIED_TENSOR_FILE = "dev_tied_tensor_bf16.bin"
DEV_TIED_TENSOR_SHA256 = "bba6d094831861aa0b207ae5ca46938e2115e02c81215ba95e27e2bad1cc1dd6"
DEV_TIED_V, DEV_TIED_D = 300, 384
# [READ] frozen-r14 trained_block_tests.rs:177 (`write_export`'s
# metadata_out_of_proof.residual_scale_s_x for the "tiny" rung export)
DEV_RESIDUAL_UNIT = 0.0053663705198366135
# [READ] REVIEW_R13 §5 reference digests (SHA-256 of the int16 LE tables)
REF_EMB_SHA256 = "c0e816c9f41a251df8560c5532d3f24c3b753ceb6ad712adcc7a893f71bfa475"
REF_DEV_MARGIN_SHA256 = "24e6ff4ca67bac45c810f78b72d967894b6806615206c5571842055ce20ef3c1"
# [READ] stage_in_c.rs / token_io.rs:259 TAG_EMB
TAG_EMB = 135
# the profile text's tied-source sentence for the rung (classify_tied.rs:114-116)
TIED_SOURCE_DEV = ("tied-source=dev-rung-synthetic-bf16 file=dev_tied_tensor_bf16.bin V=300 d=384 "
                   f"sha256={DEV_TIED_TENSOR_SHA256} "
                   "derivation=R12b-quantize(floor(x/scale+0.5),refuse-outside-int16,no-clip,no-rotation)")

_CACHE = {}


def dev_tied_tensor_bytes() -> bytes:
    """`classify_tied.rs::dev_tied_tensor_bytes` (:509-520), transcribed"""
    if "tensor" in _CACHE:
        return _CACHE["tensor"]
    s = 0x7469_6564_2D64_6576
    n = DEV_TIED_V * DEV_TIED_D
    out = bytearray()
    m = 1 << 64
    for kk in range(n + DEV_TIED_D):
        s = (s * 6364136223846793005 + 1442695040888963407) % m
        r = s >> 33
        if kk < n:
            bits = ((r & 1) << 15) | ((120 + (r >> 1) % 12) << 7) | ((r >> 5) & 0x7F)
        else:
            bits = ((126 + (r & 1)) << 7) | ((r >> 1) & 0x7F)
        out += struct.pack("<H", bits & 0xFFFF)
    _CACHE["tensor"] = bytes(out)
    return _CACHE["tensor"]


def bf16(raw: bytes) -> list:
    """native R12b `tied_tables::bf16`: each BF16 word widened exactly"""
    vals = [struct.unpack("<f", struct.pack("<I", w << 16))[0] for (w,) in struct.iter_unpack("<H", raw)]
    if any(not math.isfinite(x) for x in vals):
        raise ValueError("nonfinite BF16 tensor value")
    return vals


def quantize(values, scale: float, low: int, high: int) -> list:
    """native R12b `tied_tables::quantize`: floor(x / scale + 0.5), refused
    (never clipped) outside [low, high]"""
    if not (scale > 0 and math.isfinite(scale)):
        raise ValueError("the quantization scale is not a positive finite number")
    out = []
    for x in values:
        q = math.floor(x / scale + 0.5)
        if q < low or q > high:
            raise ValueError(f"quantization overflow at {x!r} / {scale!r} (no clipping is permitted)")
        out.append(int(q))
    return out


def derive_dev(yes: int, no: int, scale: float, residual_unit: float = DEV_RESIDUAL_UNIT) -> dict:
    """`classify_tied.rs::derive_dev` (:292-324) on the pinned dev tensor"""
    key = (yes, no, scale, residual_unit)
    if key in _CACHE:
        return _CACHE[key]
    v, d = DEV_TIED_V, DEV_TIED_D
    if yes == no or not (0 <= yes < v) or not (0 <= no < v):
        raise ValueError("invalid yes / no ids for the tied tensor")
    raw = dev_tied_tensor_bytes()
    t_sha = hashlib.sha256(raw).hexdigest()
    if t_sha != DEV_TIED_TENSOR_SHA256:
        raise ValueError(f"the regenerated development tensor hashes to {t_sha[:12]}, not the pin {DEV_TIED_TENSOR_SHA256[:12]}")
    vals = bf16(raw)
    rows, g = vals[:v * d], vals[v * d:]
    emb = quantize(rows, residual_unit, -32768, 32767)
    diff = [(rows[yes * d + i] - rows[no * d + i]) * g[i] for i in range(d)]
    w = quantize(diff, scale, -32767, 32767)
    out = {"tensor_sha256": t_sha, "emb": emb, "w": w,
           "emb_sha256": hashlib.sha256(struct.pack(f"<{len(emb)}h", *emb)).hexdigest(),
           "w_sha256": hashlib.sha256(struct.pack(f"<{d}h", *w)).hexdigest(),
           "yes": yes, "no": no, "scale": scale, "residual_unit": residual_unit}
    _CACHE[key] = out
    return out


def emb_digest(v: int, d: int, emb) -> str:
    """`ClassifierTables::emb_digest` (classify.rs:313-322)"""
    import blake3
    h = blake3.blake3()
    h.update(b"hashline/classify/embedding-int16/v1")
    h.update(int(v).to_bytes(8, "little"))
    h.update(int(d).to_bytes(8, "little"))
    h.update(struct.pack(f"<{len(emb)}h", *emb))
    return h.hexdigest()


def emb_fold(emb, v: int, d: int, r_emb) -> list:
    """`ClassifierTables::emb_fold` (classify.rs:337-344): E~(v, r) for v < V"""
    e = eq_table_msb([tuple(x) for x in r_emb])
    out = []
    for row in range(v):
        acc = (0, 0)
        base = row * d
        for i in range(d):
            w = emb[base + i]
            if w:
                acc = f2_add(acc, f2_mul_base(e[i], w % P))
        out.append(acc)
    return out


def tau_table(emb, v: int, d: int, voc_log: int, num_special: int, r_emb, beta, g_emb) -> list:
    """`stage_in_c.rs::tau_table` (:158-164): v + beta E~(v, r) + beta^2
    ctl(v) + g_emb on the true rows; padded rows repeat row 0"""
    ef = emb_fold(emb, v, d, r_emb)
    b2 = f2_mul(beta, beta)

    def row(x):
        t = f2_add(((x % P), 0), f2_mul(beta, ef[x]))
        if x < num_special:
            t = f2_add(t, b2)
        return f2_add(t, g_emb)
    rows = [row(x) for x in range(v)]
    return [rows[x] if x < v else rows[0] for x in range(1 << voc_log)]


def profile_fields(text: str) -> dict:
    """the classifier profile text's R-C2 / R-C3 fields (classify.rs:578-622)"""
    out = {}
    for key, pat in (("n", r" n=(\d+) "), ("S", r" S=(\d+) "), ("P0", r" P0=(\d+) "), ("T", r" T=(\d+) "),
                     ("item_length", r" item-length=(\d+) "), ("pad_id", r" pad-id=(\d+) "),
                     ("pad_positions", r" pad-positions=(\d+) "), ("verdict_row", r" verdict-row=(\d+) "),
                     ("chunk_size", r" chunk-size=(\d+) "), ("chunk_overlap", r" chunk-overlap=(\d+) "),
                     ("margin_scale_bits", r" margin-scale-bits=(0x[0-9a-f]{16}) "),
                     ("yes", r" yes=(\d+) "), ("no", r" no=(\d+) ")):
        m = re.search(pat, text)
        out[key] = (m.group(1) if key == "margin_scale_bits" else int(m.group(1))) if m else None
    if out["margin_scale_bits"] is not None:
        out["margin_scale"] = struct.unpack("<d", struct.pack("<Q", int(out["margin_scale_bits"], 16)))[0]
    else:
        out["margin_scale"] = None
    m = re.search(r"tied-source=(\S+)", text)
    out["tied_source"] = m.group(1) if m else None
    out["tied_source_sentence_is_the_dev_rung"] = TIED_SOURCE_DEV in text
    # [v22] the real Shieldstral source (classify_tied.rs:119-125 at r16b)
    out["tied_source_sentence_is_shieldstral"] = TIED_SOURCE_SHIELDSTRAL in text
    return out


# [v22] the Shieldstral export the gate derives B-3 from (its profile.json,
# rotation signs and checkpoint declaration); set by the classifier gate's
# `--tied-export`.  Never a table file of the export is read.
SHIELD_EXPORT = None


def derive_for_profile(cf: dict, pf: dict) -> dict:
    """[v22] the tables DERIVED from the pinned tensor the profile text names:
    the development rung's (`derive_dev`) or the real Shieldstral checkpoint's
    (`shieldstral_derive`, under `SHIELD_EXPORT`).  Raises ValueError when no
    source can be derived (the caller records it as a B-3 finding)."""
    pol = cf["policy"]
    if pf["margin_scale"] is None:
        raise ValueError("no margin-scale-bits in the profile text")
    if pf.get("tied_source_sentence_is_the_dev_rung"):
        dv = dict(derive_dev(pol["yes"], pol["no"], pf["margin_scale"]))
        dv.setdefault("emb_digest", emb_digest(DEV_TIED_V, DEV_TIED_D, dv["emb"]))
        dv["v"], dv["d"], dv["source"] = DEV_TIED_V, DEV_TIED_D, "dev-rung"
        return dv
    if pf.get("tied_source_sentence_is_shieldstral"):
        if SHIELD_EXPORT is None:
            raise ValueError("the profile names the Shieldstral checkpoint; give the gate --tied-export <export>")
        key = ("shield", SHIELD_EXPORT, pol["yes"], pol["no"], pf["margin_scale"])
        if key not in _CACHE:
            _CACHE[key] = shieldstral_derive(SHIELD_EXPORT, pol["yes"], pol["no"], pf["margin_scale"])
        dv = dict(_CACHE[key])
        dv["v"], dv["d"] = SHIELD_V, SHIELD_D
        return dv
    raise ValueError("the profile text names no tied source this gate derives")


def derived_tables_check(b, words_captured=None) -> dict:
    """B-3 v21 on a capture: the tables DERIVED from the pinned tensor under
    the profile's (yes, no, margin-scale) and the rung's residual unit, their
    digests against the statement's (`margin_vector.digest`,
    `embedding_digest`), and, when the PD slot's recorded margin vector is
    given, entry for entry against it."""
    from zk60_native_rg_classterminals import w_digest
    cf = b.run["classify"]
    pf = profile_fields(cf.get("profile_text", ""))
    f = []
    rec = {"what": "B-3 (v21): the margin row and the embedding DERIVED from the pinned tied tensor, not taken",
           "profile_fields": {k: pf[k] for k in ("yes", "no", "margin_scale_bits", "margin_scale", "tied_source",
                                                 "tied_source_sentence_is_the_dev_rung")}}
    rec["profile_fields"]["tied_source_sentence_is_shieldstral"] = pf.get("tied_source_sentence_is_shieldstral")
    pol = cf["policy"]
    if (pf["yes"], pf["no"]) != (pol["yes"], pol["no"]):
        f.append("B-3: the profile text's yes / no are not the policy's")
    try:
        dv = derive_for_profile(cf, pf)   # [v22] the dev rung's or the real Shieldstral source
    except ValueError as exc:
        rec.update({"findings": f + [f"B-3: {exc}"], "ok": False})
        return rec
    d, v = cf["d"], cf["V"]
    if (v, d) != (dv["v"], dv["d"]):
        f.append(f"B-3: the classifier facts give V x d = {v} x {d}, the tied tensor is {dv['v']} x {dv['d']}")
    w_dig = w_digest(d, dv["w"])
    want_w = bytes(cf["margin_vector"]["digest"]).hex()
    if w_dig != want_w:
        f.append(f"B-3: the derived margin row hashes to {w_dig[:12]}, the statement's digest is {want_w[:12]}")
    e_dig = dv["emb_digest"]
    want_e = bytes(cf["embedding_digest"]).hex()
    if e_dig != want_e:
        f.append(f"B-3: the derived embedding hashes to {e_dig[:12]}, the statement's embedding digest is {want_e[:12]}")
    for frag in (f"margin-vector=int16[-32767,32767] {w_dig} ", f"embedding={e_dig} "):
        if frag not in cf.get("profile_text", ""):
            f.append(f"B-3: the profile text does not carry {frag.strip()[:40]!r}")
    cmp_ = None
    if words_captured is not None:
        pad = list(dv["w"]) + [0] * (len(words_captured) - d)
        diff = [i for i, (a, c) in enumerate(zip(pad, words_captured)) if a != c]
        cmp_ = {"entries": len(words_captured), "differing": len(diff), "first_differing": diff[:4]}
        if diff or len(words_captured) < d:
            f.append(f"B-3: the recorded margin vector differs from the derived row at {len(diff)} entries")
    rec.update({"tied_source": dv.get("source"), "tensor_sha256": dv["tensor_sha256"],
                "tensor_pin": DEV_TIED_TENSOR_SHA256 if dv.get("source") == "dev-rung" else SHIELD_TENSOR_SHA256,
                "checkpoint_sha256_authenticated": dv.get("checkpoint_sha256"),
                "derived_margin_digest": w_dig, "statement_margin_digest": want_w,
                "derived_margin_sha256_int16": dv["w_sha256"], "derived_embedding_digest": e_dig,
                "statement_embedding_digest": want_e, "derived_embedding_sha256_int16": dv["emb_sha256"],
                "residual_unit": dv.get("residual_unit", dv.get("embedding_scale")), "recorded_vs_derived": cmp_,
                "findings": f, "ok": not f})
    return rec


# =====================================================================
# [v22, gate round 19, 2026-10-29] B-3 at the REAL Shieldstral profile
# =====================================================================
# READ [token frozen-r16b, list 04d94bc0...]:
# * `tied_tables/derive.rs` (c5bec3c6): WIDTH 3072, VOCAB 131072, TENSOR
#   `language_model.model.embed_tokens.weight`, NORM
#   `language_model.model.norm.weight`, CHECKPOINT_BYTES 7698241104,
#   DEFAULT_CHECKPOINT (:5-10); `Checkpoint::open` (:121-160): the safetensors
#   header, the tensor [V, D] and norm [D] extents, no `lm_head`, the WHOLE
#   file's SHA-256 against `ModelSource::shieldstral_1_0_3b().weights_sha256`
#   (trained_statement.rs:162, 87753e30...), the consumed tensor bytes against
#   SHIELDSTRAL_TIED_TENSOR_SHA256 (67a138c1..., :601); `rotate` (:163-178):
#   x *= sign, then per 1024-block the in-place butterfly (a + b, a - b) for
#   step 1, 2, 4, ..., 512, then x /= sqrt(1024); `quantize` (:180-187);
#   `recompute_profile` (:227-276): the embedding row = rotate(raw), rounded
#   to f32, quantize(residual_scales_in[0], -32768, 32767); the margin row =
#   rotate((yes - no) * norm), quantize(public_scale, -32767, 32767) (the
#   difference BEFORE quantization); the rotation = block-hadamard, width
#   3072, block 1024, 3 blocks, signs = `rotation_sign.bin` (f64 LE) whose
#   SHA-256 is the profile's `sign_sha256`.
# * `token_io/classify_tied.rs` (a89acfab) `TiedSource::describe` (:119-125):
#   the profile text's Shieldstral sentence.
# * `token_io/classify.rs` (c180c83f) `emb_digest` (:476-485), `emb_fold`
#   (:500-507).
# The arithmetic below is numpy over the same IEEE binary64 operations in the
# same order per element (the butterfly is elementwise per step), so it is
# bit-for-bit the native result; the int16 tables' digests are then compared
# with the statement's (`embedding_digest`, `margin_vector.digest`).

SHIELD_V, SHIELD_D = 131072, 3072
SHIELD_TENSOR = "language_model.model.embed_tokens.weight"
SHIELD_NORM = "language_model.model.norm.weight"
SHIELD_TENSOR_SHA256 = "67a138c1c483b89874526ef523f5f0c30f161808076561730193d1de2093dd19"
SHIELD_WEIGHTS_SHA256 = "87753e30c8c321da478b83bbabebcd813cc9b3d0cee5c5b3d64349a8ee4172f7"
SHIELD_CHECKPOINT_BYTES = 7698241104
SHIELD_DEFAULT_CHECKPOINT = "/home/victor/models/shieldstral-1.0-3b/snapshot-003ec7e2/model.safetensors"
TIED_SOURCE_SHIELDSTRAL = ("tied-source=shieldstral-checkpoint tensor=language_model.model.embed_tokens.weight "
                           f"sha256={SHIELD_TENSOR_SHA256} "
                           "derivation=native-R12b-recompute_tied_tables(rotate-then-floor(x/scale+0.5),"
                           "refuse-outside-int16,no-clip)")


def _np():
    import numpy as np
    return np


def _rotate_rows(x, signs, block=1024):
    """`derive.rs::rotate` on every row of `x` (float64, rows x width):
    x *= sign, then per block the butterfly, then / sqrt(block)"""
    np = _np()
    x = x * signs[None, :]
    rows, width = x.shape
    nb = width // block
    v = x.reshape(rows, nb, block)
    step = 1
    while step < block:
        w = v.reshape(rows, nb, block // (2 * step), 2, step)
        a = w[:, :, :, 0, :].copy()
        b = w[:, :, :, 1, :]
        w[:, :, :, 0, :] = a + b
        w[:, :, :, 1, :] = a - b
        step *= 2
    v = v / float(block) ** 0.5
    out = v.reshape(rows, width)
    if not np.all(np.isfinite(out)):
        raise ValueError("nonfinite rotated weight")
    return out


def _bf16_to_f64(u16):
    np = _np()
    f = (u16.astype(np.uint32) << 16).view(np.float32).astype(np.float64)
    if not np.all(np.isfinite(f)):
        raise ValueError("nonfinite BF16 tensor value")
    return f


def _quantize_np(x, scale, low, high):
    np = _np()
    if not (scale > 0 and math.isfinite(scale)):
        raise ValueError("the quantization scale is not a positive finite number")
    q = np.floor(x / scale + 0.5)
    if not np.all(np.isfinite(q)) or q.min() < low or q.max() > high:
        raise ValueError("quantization overflow (no clipping is permitted)")
    return q.astype(np.int64)


def _shield_stream(export_dir: str, authenticate: bool, chunk_rows: int, rows_wanted, on_chunk):
    """[v22] native R12b `recompute_profile` (derive.rs:227-276) as a STREAM over
    the pinned checkpoint: the profile's rotation and scale, the safetensors
    extents, the whole file's SHA-256 against the model pin (when
    `authenticate`), the final norm, then the tensor in chunks of `chunk_rows`
    rows: each chunk rotated, rounded to f32 and quantized to int16 and handed
    to `on_chunk(r0, q)`; the consumed tensor bytes are always checked against
    the tensor pin.  Returns the context and the raw rows in `rows_wanted`.
    Memory: one chunk (no 805 MB table is ever held)."""
    import json as _json
    np = _np()
    pbytes = open(os.path.join(export_dir, "profile.json"), "rb").read()
    profile = _json.loads(pbytes)
    meta = profile["metadata_out_of_proof"]
    emb_scale = float(meta["residual_scales_in"][0])
    rot = meta["rotation"]
    if (rot.get("kind"), rot.get("width"), rot.get("block_width"), rot.get("blocks")) != ("block-hadamard", SHIELD_D, 1024, 3):
        raise ValueError("tied tables: expected three 1024-wide Hadamard blocks")
    sign_bytes = open(os.path.join(export_dir, "rotation_sign.bin"), "rb").read()
    if hashlib.sha256(sign_bytes).hexdigest() != rot["sign_sha256"]:
        raise ValueError("rotation signs SHA-256 differs from profile")
    signs = np.frombuffer(sign_bytes, dtype="<f8").astype(np.float64)
    if signs.shape != (SHIELD_D,) or not np.all((signs == 1.0) | (signs == -1.0)):
        raise ValueError("rotation signs must be exactly +1 or -1, one per coordinate")
    decl = profile["tied_embeddings"]
    if decl.get("tensor") != SHIELD_TENSOR or decl.get("sha256") != SHIELD_TENSOR_SHA256:
        raise ValueError("tied tensor declaration differs from pin")
    path = decl.get("checkpoint_file") or SHIELD_DEFAULT_CHECKPOINT
    size = os.path.getsize(path)
    if size != SHIELD_CHECKPOINT_BYTES:
        raise ValueError(f"the checkpoint is {size} B, the pinned file is {SHIELD_CHECKPOINT_BYTES} B")
    with open(path, "rb") as fh:
        hlen = struct.unpack("<Q", fh.read(8))[0]
        if not (2 <= hlen <= 4 << 20):
            raise ValueError("checkpoint safetensors header length out of bounds")
        header = _json.loads(fh.read(hlen))
    base = 8 + hlen
    if "language_model.lm_head.weight" in header:
        raise ValueError("checkpoint has an independent LM head instead of a tied tensor")

    def extent(name, shape):
        e = header[name]
        if e.get("dtype") != "BF16" or list(e.get("shape")) != list(shape):
            raise ValueError(f"{name}: dtype / shape is not BF16 {shape}")
        a, b_ = e["data_offsets"]
        if b_ - a != 2 * int(np.prod(shape)) or base + b_ > size:
            raise ValueError(f"{name}: extent out of bounds")
        return base + a, b_ - a
    t_off, t_len = extent(SHIELD_TENSOR, [SHIELD_V, SHIELD_D])
    n_off, n_len = extent(SHIELD_NORM, [SHIELD_D])
    whole = None
    if authenticate:
        h = hashlib.sha256()
        with open(path, "rb") as fh:
            while True:
                blk = fh.read(64 << 20)
                if not blk:
                    break
                h.update(blk)
        whole = h.hexdigest()
        if whole != SHIELD_WEIGHTS_SHA256:
            raise ValueError("checkpoint SHA-256 differs from the pinned model")
    rows = {}
    with open(path, "rb") as fh:
        fh.seek(n_off)
        norm = _bf16_to_f64(np.frombuffer(fh.read(n_len), dtype="<u2"))
        fh.seek(t_off)
        th = hashlib.sha256()
        for r0 in range(0, SHIELD_V, chunk_rows):
            r1 = min(SHIELD_V, r0 + chunk_rows)
            raw_b = fh.read(2 * SHIELD_D * (r1 - r0))
            th.update(raw_b)
            raw = _bf16_to_f64(np.frombuffer(raw_b, dtype="<u2")).reshape(r1 - r0, SHIELD_D)
            for r in rows_wanted:
                if r0 <= r < r1:
                    rows[r] = raw[r - r0].copy()
            x = _rotate_rows(raw, signs).astype(np.float32).astype(np.float64)
            on_chunk(r0, _quantize_np(x, emb_scale, -32768, 32767).astype(np.int16))
    if th.hexdigest() != SHIELD_TENSOR_SHA256:
        raise ValueError("consumed tied tensor SHA-256 differs from pin")
    return {"path": path, "whole": whole, "pbytes": pbytes, "emb_scale": emb_scale, "signs": signs, "norm": norm,
            "rows": rows}


class ShieldEmb:
    """[v22] the derived Shieldstral embedding as a LAZY handle: its fold at a
    point is computed by streaming the pinned checkpoint again (the exact numpy
    fold per chunk); the 805 MB int16 table is never held in memory"""

    def __init__(self, export_dir: str, chunk_rows: int = 1024):
        self.export_dir, self.chunk_rows = export_dir, chunk_rows
        self.shape = (SHIELD_V, SHIELD_D)
        self.folds = 0

    def fold(self, r_emb, d: int) -> list:
        np = _np()
        lim = _limb_matrix(r_emb, d)
        out = []

        def on_chunk(r0, q):
            s = np.rint(q[:, :d].astype(np.float64) @ lim).astype(np.int64)
            for row in s.tolist():
                out.append((sum(int(row[k]) << (16 * k) for k in range(4)) % P,
                            sum(int(row[4 + k]) << (16 * k) for k in range(4)) % P))
        _shield_stream(self.export_dir, False, self.chunk_rows, (), on_chunk)
        self.folds += 1
        return out


def shieldstral_derive(export_dir: str, yes: int, no: int, margin_scale: float, authenticate: bool = True,
                       chunk_rows: int = 1024, keep_emb: bool = False) -> dict:
    """native R12b `recompute_profile` (derive.rs:227-276) on the pinned
    Shieldstral checkpoint, for the classifier: the int16 embedding's digests
    (SHA-256 of the LE table; the statement's BLAKE3 `emb_digest`) and the
    margin row for (yes, no, margin_scale), in ONE stream (`_shield_stream`).
    `emb` is a lazy `ShieldEmb` (its fold streams again), or the whole V x d
    table when `keep_emb` (805 MB; tests and dev only)."""
    np = _np()
    import blake3
    import time as _t
    t0 = _t.time()
    if yes == no or not (0 <= yes < SHIELD_V) or not (0 <= no < SHIELD_V):
        raise ValueError("invalid classifier yes/no token IDs")
    sh = hashlib.sha256()
    bh = blake3.blake3()
    bh.update(b"hashline/classify/embedding-int16/v1")
    bh.update(SHIELD_V.to_bytes(8, "little"))
    bh.update(SHIELD_D.to_bytes(8, "little"))
    kept = np.empty((SHIELD_V, SHIELD_D), dtype=np.int16) if keep_emb else None
    mm = {"min": 0, "max": 0}

    def on_chunk(r0, q):
        b_ = q.astype("<i2").tobytes()
        sh.update(b_)
        bh.update(b_)
        mm["min"], mm["max"] = min(mm["min"], int(q.min())), max(mm["max"], int(q.max()))
        if kept is not None:
            kept[r0:r0 + q.shape[0]] = q
    ctx = _shield_stream(export_dir, authenticate, chunk_rows, (yes, no), on_chunk)
    diff = ((ctx["rows"][yes] - ctx["rows"][no]) * ctx["norm"])[None, :]
    w = _quantize_np(_rotate_rows(diff, ctx["signs"]), margin_scale, -32767, 32767)[0]
    return {"source": "shieldstral-checkpoint", "checkpoint": ctx["path"], "checkpoint_sha256": ctx["whole"],
            "checkpoint_authenticated": authenticate, "tensor_sha256": SHIELD_TENSOR_SHA256,
            "profile_sha256": hashlib.sha256(ctx["pbytes"]).hexdigest(), "embedding_scale": ctx["emb_scale"],
            "emb": kept if keep_emb else ShieldEmb(export_dir, chunk_rows),
            "emb_sha256": sh.hexdigest(), "emb_digest": bh.hexdigest(), "emb_min_max": [mm["min"], mm["max"]],
            "w": [int(x) for x in w], "w_sha256": hashlib.sha256(np.asarray(w, dtype="<i2").tobytes()).hexdigest(),
            "yes": yes, "no": no, "scale": margin_scale, "seconds": round(_t.time() - t0, 1)}


def _limb_matrix(r_emb, d: int):
    np = _np()
    e = eq_table_msb([tuple(x) for x in r_emb])
    return np.array([[(int(e[i][c]) >> (16 * k)) & 0xFFFF for c in (0, 1) for k in range(4)] for i in range(d)],
                    dtype=np.float64)


def emb_fold_np(emb, d: int, r_emb) -> list:
    """`ClassifierTables::emb_fold` (classify.rs:500-507) with numpy:
    E~(v, r) = sum_{i < d} eq_msb(r)[i] E[v][i], exact.  Each eq entry's two
    base components are split into four 16-bit limbs; |E| <= 2^15, a limb <
    2^16 and d <= 2^12 keep every partial sum below 2^43, so the float64
    product is exact in any summation order."""
    np = _np()
    lim = _limb_matrix(r_emb, d)
    v = emb.shape[0]
    out = []
    for r0 in range(0, v, 8192):
        s = np.rint(emb[r0:r0 + 8192, :d].astype(np.float64) @ lim).astype(np.int64)
        for row in s.tolist():
            c0 = sum(int(row[k]) << (16 * k) for k in range(4)) % P
            c1 = sum(int(row[4 + k]) << (16 * k) for k in range(4)) % P
            out.append((c0, c1))
    return out


def tau_table_from_fold(ef: list, v: int, voc_log: int, num_special: int, beta, g_emb) -> list:
    """`stage_in_c.rs::tau_table` from an already folded embedding"""
    b2 = f2_mul(beta, beta)

    def row(x):
        t = f2_add(((x % P), 0), f2_mul(beta, ef[x]))
        if x < num_special:
            t = f2_add(t, b2)
        return f2_add(t, g_emb)
    rows = [row(x) for x in range(v)]
    return [rows[x] if x < v else rows[0] for x in range(1 << voc_log)]
