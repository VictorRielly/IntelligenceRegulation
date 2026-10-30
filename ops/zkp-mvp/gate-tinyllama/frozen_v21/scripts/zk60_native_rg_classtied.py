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
    return out


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
    if not pf["tied_source_sentence_is_the_dev_rung"]:
        f.append("B-3: the profile text does not name the development rung's tied source (bba6d094...); "
                 "no other source is derived here")
        rec.update({"findings": f, "ok": False})
        return rec
    pol = cf["policy"]
    if (pf["yes"], pf["no"]) != (pol["yes"], pol["no"]):
        f.append("B-3: the profile text's yes / no are not the policy's")
    if pf["margin_scale"] is None:
        f.append("B-3: no margin-scale-bits in the profile text")
        rec.update({"findings": f, "ok": False})
        return rec
    try:
        dv = derive_dev(pol["yes"], pol["no"], pf["margin_scale"])
    except ValueError as exc:
        rec.update({"findings": [f"B-3: {exc}"], "ok": False})
        return rec
    d, v = cf["d"], cf["V"]
    if (v, d) != (DEV_TIED_V, DEV_TIED_D):
        f.append(f"B-3: the classifier facts give V x d = {v} x {d}, the dev tensor is {DEV_TIED_V} x {DEV_TIED_D}")
    w_dig = w_digest(d, dv["w"])
    want_w = bytes(cf["margin_vector"]["digest"]).hex()
    if w_dig != want_w:
        f.append(f"B-3: the derived margin row hashes to {w_dig[:12]}, the statement's digest is {want_w[:12]}")
    e_dig = emb_digest(v, d, dv["emb"])
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
    rec.update({"tensor_sha256": dv["tensor_sha256"], "tensor_pin": DEV_TIED_TENSOR_SHA256,
                "derived_margin_digest": w_dig, "statement_margin_digest": want_w,
                "derived_margin_sha256_int16": dv["w_sha256"], "derived_embedding_digest": e_dig,
                "statement_embedding_digest": want_e, "derived_embedding_sha256_int16": dv["emb_sha256"],
                "residual_unit": dv["residual_unit"], "recorded_vs_derived": cmp_,
                "findings": f, "ok": not f})
    return rec
