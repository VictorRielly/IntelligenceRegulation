#!/usr/bin/env python3
"""Lane B3: write rotation_sign.bin (float64 LE, +-1, 2048) and rotation.json
next to a rotated export, checked against profile.json's sign_sha256
(profile.json itself is not modified). Usage: b3_export_rotation.py <export dir>"""
import hashlib, json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import b3calib as b3
root = Path(sys.argv[1])
prof = json.loads((root / "profile.json").read_text())
rot = prof["metadata_out_of_proof"]["rotation"]
R = b3.Rotation(2048, rot["seed"])
raw = R.sign.astype("<f8").tobytes()
assert hashlib.sha256(raw).hexdigest() == rot["sign_sha256"], "sign vector does not match profile.json"
(root / "rotation_sign.bin").write_bytes(raw)
(root / "rotation.json").write_text(json.dumps({
    "kind": "randomized Sylvester Hadamard", "n": 2048, "seed": rot["seed"],
    "definition": "R = H diag(sign) / sqrt(2048), H the Sylvester Hadamard matrix (H_1 = [1], H_2n = [[H, H], [H, -H]]); "
                  "sign = numpy.random.default_rng(seed).integers(0, 2, 2048) mapped 1 -> +1, 0 -> -1",
    "residual_basis": "x' = x R^T (row vectors): layer-0 input x_in_L00 = round(embedding[token] R^T / s_x); "
                      "the final residual maps back as x = x' R before the float final norm + LM head",
    "weights": "consumers W' = W diag(gamma) R^T (q, k, v, gate, up), writers W' = R W (o, down), norm gammas 1 "
               "(the int8 gain vectors carry the per-channel gains of the rotated norms)",
    "file": {"name": "rotation_sign.bin", "dtype": "float64 little-endian", "shape": [2048], "sha256": hashlib.sha256(raw).hexdigest()},
    "scope": "public-weight preparation; not part of any proved relation"}, indent=1))
print("ok", hashlib.sha256(raw).hexdigest())
