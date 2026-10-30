"""D24 review round 11 (R12b fix check): the reviewer's own transcription of
the tied-table quantizer contract, written from SOL_REPORT_20261028.md
("Exact quantizer") and the coordinator's 21:35Z conditions, not from Sol's code.

Reads (read only): the pinned Shieldstral checkpoint, and a profile.json +
rotation_sign.bin pair (Sol's component fixture profile, copied byte for byte).
Writes: an honest fixture of my own (token_io tables + manifests) under OUT,
for the native attack tests, and a JSON report.

Independence choices: the signed block Hadamard runs with DECREASING strides
(512, 256, ..., 1); the native code runs increasing strides. Each chunk is also
rotated with increasing strides and the two float results are compared exactly:
zero mismatches means the rotation is exact on this tensor (all partial sums
representable), so the contract does not depend on the butterfly order.

Usage: python3 r12b_tied_reference.py <profile_dir> <out_fixture_dir> <report.json>
"""
import hashlib
import json
import math
import os
import shutil
import struct
import sys

import numpy as np

CKPT = "/home/victor/models/shieldstral-1.0-3b/snapshot-003ec7e2/model.safetensors"
CKPT_SHA = "87753e30c8c321da478b83bbabebcd813cc9b3d0cee5c5b3d64349a8ee4172f7"
TENSOR_SHA = "67a138c1c483b89874526ef523f5f0c30f161808076561730193d1de2093dd19"
TENSOR = "language_model.model.embed_tokens.weight"
NORM = "language_model.model.norm.weight"
V, D, B = 131072, 3072, 1024
CHUNK = 2048
MARGINS = [("fixture", 1, 2, 4.123279644327835e-06), ("policy", 13059, 2649, 4.08288030735373e-06)]

src, out, report = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(os.path.join(out, "token_io"), exist_ok=True)


def file_sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            b = f.read(1 << 22)
            if not b:
                break
            h.update(b)
    return h.hexdigest()


def widen(raw):
    u = np.frombuffer(raw, dtype="<u2").astype(np.uint32) << 16
    x = u.view(np.float32).astype(np.float64)
    assert np.isfinite(x).all(), "nonfinite BF16"
    return x


def hadamard(x, decreasing):
    """x: (n, 3072) already sign-multiplied; returns H x / 32 per 1024 block."""
    n = x.shape[0]
    y = x.reshape(n * 3, B).copy()
    steps = [1 << k for k in range(10)]
    if decreasing:
        steps = steps[::-1]
    for s in steps:
        z = y.reshape(n * 3, B // (2 * s), 2, s)
        a = z[:, :, 0, :].copy()
        b = z[:, :, 1, :].copy()
        z[:, :, 0, :] = a + b
        z[:, :, 1, :] = a - b
    return (y / 32.0).reshape(n, D)


def rotate(x, signs, stats):
    xs = x * signs
    r = hadamard(xs, True)
    r2 = hadamard(xs, False)
    stats["order_mismatch"] += int(np.count_nonzero(r != r2))
    stats["rotated_values"] += r.size
    assert np.isfinite(r).all()
    return r


def quant(x, scale, lo, hi):
    q = np.floor(x / scale + 0.5)
    bad = (~np.isfinite(q)) | (q < lo) | (q > hi)
    return q, int(np.count_nonzero(bad))


profile_bytes = open(os.path.join(src, "profile.json"), "rb").read()
profile = json.loads(profile_bytes)
sign_bytes = open(os.path.join(src, "rotation_sign.bin"), "rb").read()
assert len(sign_bytes) == D * 8
assert hashlib.sha256(sign_bytes).hexdigest() == profile["metadata_out_of_proof"]["rotation"]["sign_sha256"]
signs = np.frombuffer(sign_bytes, dtype="<f8").copy()
assert set(np.unique(signs).tolist()) <= {1.0, -1.0}
emb_scale = float(profile["metadata_out_of_proof"]["residual_scales_in"][0])
assert math.isfinite(emb_scale) and emb_scale > 0

# copy the profile pair byte for byte into my fixture
shutil.copyfile(os.path.join(src, "profile.json"), os.path.join(out, "profile.json"))
shutil.copyfile(os.path.join(src, "rotation_sign.bin"), os.path.join(out, "rotation_sign.bin"))

size = os.path.getsize(CKPT)
with open(CKPT, "rb") as f:
    (hlen,) = struct.unpack("<Q", f.read(8))
    header = json.loads(f.read(hlen))
base = 8 + hlen
t, nm = header[TENSOR], header[NORM]
assert t["dtype"] == "BF16" and t["shape"] == [V, D], t
assert nm["dtype"] == "BF16" and nm["shape"] == [D], nm
assert "language_model.lm_head.weight" not in header
ckpt_sha = file_sha(CKPT)

stats = {"order_mismatch": 0, "rotated_values": 0}
emb_refused = head_refused = 0
tensor_h, emb_h, head_h = hashlib.sha256(), hashlib.sha256(), hashlib.sha256()
scales = np.zeros(V)
rows_wanted = {i for _, y, n, _ in MARGINS for i in (y, n)}
kept = {}
with open(CKPT, "rb") as f:
    f.seek(base + nm["data_offsets"][0])
    gamma = widen(f.read(D * 2))
    f.seek(base + t["data_offsets"][0])
    with open(os.path.join(out, "token_io", "embedding_int16.bin"), "wb") as ef, \
         open(os.path.join(out, "token_io", "head_int8_perrow.bin"), "wb") as hf:
        for r0 in range(0, V, CHUNK):
            raw = f.read(CHUNK * D * 2)
            assert len(raw) == CHUNK * D * 2
            tensor_h.update(raw)
            x = widen(raw).reshape(CHUNK, D)
            for i in rows_wanted:
                if r0 <= i < r0 + CHUNK:
                    kept[i] = x[i - r0].copy()
            e = rotate(x, signs, stats).astype(np.float32).astype(np.float64)
            qe, bad = quant(e, emb_scale, -32768, 32767)
            emb_refused += bad
            eb = qe.astype("<i2").tobytes()
            emb_h.update(eb)
            ef.write(eb)
            hv = rotate(x * gamma, signs, stats)
            s = np.abs(hv).max(axis=1) / 127.0
            qh, bad = quant(hv, np.where(s > 0, s, 1.0)[:, None], -127, 127)
            head_refused += bad
            hb = qh.astype("i1").tobytes()
            head_h.update(hb)
            hf.write(hb)
            scales[r0:r0 + CHUNK] = s
mx = scales.max()
m = np.maximum(np.floor(4096.0 * scales / mx + 0.5), 1.0)
assert m.min() >= 1 and m.max() <= 4096
mult_bytes = m.astype("<i8").tobytes()
open(os.path.join(out, "token_io", "head_mult12.bin"), "wb").write(mult_bytes)

margins = {}
for label, y, n, sc in MARGINS:
    diff = rotate(((kept[y] - kept[n]) * gamma)[None, :], signs, stats)[0]
    q, bad = quant(diff, sc, -32767, 32767)
    entry = {"yes": y, "no": n, "scale": sc, "refused_coordinates": bad,
             "min": int(q.min()), "max": int(q.max()),
             "at_plus_minus_32767": int(np.count_nonzero(np.abs(q) == 32767)),
             "max_abs_over_scale": float(np.abs(diff).max() / sc)}
    if bad == 0:
        mb = q.astype("<i2").tobytes()
        entry["sha256"] = hashlib.sha256(mb).hexdigest()
        open(os.path.join(out, "token_io", f"margin_{label}_int16.bin"), "wb").write(mb)
    # fail-closed probe: half the scale must refuse (never clamp)
    q2, bad2 = quant(diff, sc / 2, -32767, 32767)
    entry["half_scale_refused_coordinates"] = bad2
    margins[label] = entry

tensor_sha = tensor_h.hexdigest()
emb_sha, head_sha, mult_sha = emb_h.hexdigest(), head_h.hexdigest(), hashlib.sha256(mult_bytes).hexdigest()
src_t = {"name": TENSOR, "sha256": tensor_sha}
json.dump({"embedding_table": {"file": "embedding_int16.bin", "dtype": "int16", "shape": [V, D], "bytes": V * D * 2,
                               "sha256": emb_sha, "source_tensor": src_t}, "bos": 1},
          open(os.path.join(out, "token_io", "token_io.json"), "w"), indent=2)
json.dump({"source_tensor": src_t,
           "head_int8_perrow.bin": {"file": "head_int8_perrow.bin", "dtype": "int8", "shape": [V, D], "bytes": V * D, "sha256": head_sha},
           "head_mult12.bin": {"file": "head_mult12.bin", "dtype": "int64", "shape": [V], "bytes": V * 8, "sha256": mult_sha}},
          open(os.path.join(out, "token_io", "head_manifest.json"), "w"), indent=2)

sol_ref = json.load(open("/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r12b/reference_tables.json"))
sol_pol = json.load(open("/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r12b/policy_margin_reference.json"))
astra = "/home/victor/IntelligenceRegulation/results/zk60_shieldstral_export_20261026/dg_r12b_t256/token_io"
astra_decl = {}
try:
    ti = json.load(open(os.path.join(astra, "token_io.json")))
    hm = json.load(open(os.path.join(astra, "head_manifest.json")))
    astra_decl = {"embedding": ti["embedding_table"]["sha256"], "head": hm["head_int8_perrow.bin"]["sha256"],
                  "mult": hm["head_mult12.bin"]["sha256"]}
    mp = os.path.join(astra, "margin_int16.bin")
    if os.path.exists(mp):
        astra_decl["margin_file_sha256"] = file_sha(mp)
except Exception as exc:  # report, do not fail
    astra_decl = {"error": repr(exc)}
res = {
    "scope": "reviewer's independent transcription of the R12b quantizer contract; COUNTED digests; not a fidelity or privacy result",
    "profile_source": src, "profile_sha256": hashlib.sha256(profile_bytes).hexdigest(),
    "embedding_scale": emb_scale,
    "checkpoint": {"path": CKPT, "bytes": size, "sha256": ckpt_sha, "pinned": ckpt_sha == CKPT_SHA},
    "tensor_sha256": tensor_sha, "tensor_pinned": tensor_sha == TENSOR_SHA,
    "embedding_sha256": emb_sha, "head_sha256": head_sha, "multipliers_sha256": mult_sha,
    "embedding_refused": emb_refused, "head_refused": head_refused,
    "multiplier_min_max": [int(m.min()), int(m.max())],
    "zero_head_rows": int(np.count_nonzero(scales == 0)),
    "hadamard_order": stats,
    "margins": margins,
    "equal_to_sol_reference_tables": {
        "embedding": emb_sha == sol_ref["embedding_sha256"], "head": head_sha == sol_ref["head_sha256"],
        "multipliers": mult_sha == sol_ref["multipliers_sha256"],
        "fixture_margin": margins["fixture"].get("sha256") == sol_ref["margin_sha256"]},
    "equal_to_sol_policy_margin": margins["policy"].get("sha256") == sol_pol["margin_sha256"],
    "astra_dg_r12b_t256_declared": astra_decl,
    "equal_to_astra_declared": {k: astra_decl.get(k) == v for k, v in [("embedding", emb_sha), ("head", head_sha), ("mult", mult_sha)]}
                               | {"margin": astra_decl.get("margin_file_sha256") == margins["policy"].get("sha256")},
}
json.dump(res, open(report, "w"), indent=1)
print(json.dumps(res, indent=1))
