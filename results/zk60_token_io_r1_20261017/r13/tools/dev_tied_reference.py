#!/usr/bin/env python3
"""R-C2 dev rung: independent reference for the pinned synthetic tied tensor and its
derived classifier tables (embedding int16, margin row int16), written without the
Rust code. Rule = native R12b's quantizer without rotation (the rung has none):
x = BF16 widened exactly; embedding q = floor(x / s_x + 0.5) in [-32768, 32767];
margin w = floor(((E[yes] - E[no]) * g) / scale + 0.5) in [-32767, 32767], refused outside.
Usage: dev_tied_reference.py OUT.json"""
import hashlib, json, math, struct, sys

V, D = 300, 384
S_X = 0.0053663705198366135          # the rung export's residual_scale_s_x (native write_export)
POLICIES = {"rung-tc-synthetic-policy-dev/1": (40, 41, 2.0 ** -8)}
M = 2 ** 64

def tensor_bytes():
    s = 0x7469_6564_2d64_6576
    out = bytearray()
    for k in range(V * D + D):
        s = (s * 6364136223846793005 + 1442695040888963407) % M
        r = s >> 33
        if k < V * D:
            bits = ((r & 1) << 15) | ((120 + (r >> 1) % 12) << 7) | ((r >> 5) & 0x7F)
        else:
            bits = ((126 + (r & 1)) << 7) | ((r >> 1) & 0x7F)
        out += struct.pack("<H", bits)
    return bytes(out)

def bf16(b):
    return [struct.unpack("<f", struct.pack("<I", w << 16))[0] for (w,) in struct.iter_unpack("<H", b)]

def q(x, scale, lo, hi):
    v = math.floor(x / scale + 0.5)
    assert lo <= v <= hi, (x, scale, v)
    return v

t = tensor_bytes()
vals = bf16(t)
E = [vals[r * D:(r + 1) * D] for r in range(V)]
g = vals[V * D:]
emb = [q(float(struct.unpack("<f", struct.pack("<f", x))[0]), S_X, -32768, 32767) for row in E for x in row]
emb_b = struct.pack("<%dh" % len(emb), *emb)
out = {"tensor_file": "dev_tied_tensor_bf16.bin", "V": V, "d": D, "tensor_bytes": len(t),
       "tensor_sha256": hashlib.sha256(t).hexdigest(), "s_x": S_X,
       "embedding_sha256": hashlib.sha256(emb_b).hexdigest(), "embedding_absmax": max(abs(x) for x in emb),
       "margins": {}}
for pid, (y, n, sc) in POLICIES.items():
    w = [q((E[y][i] - E[n][i]) * g[i], sc, -32767, 32767) for i in range(D)]
    wb = struct.pack("<%dh" % D, *w)
    out["margins"][pid] = {"yes": y, "no": n, "scale": sc, "sha256": hashlib.sha256(wb).hexdigest(),
                           "absmax": max(abs(x) for x in w), "first8": w[:8]}
json.dump(out, open(sys.argv[1], "w"), indent=1)
print(json.dumps(out, indent=1))
