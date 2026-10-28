#!/usr/bin/env python3
"""NATIVE R9 (DD, D30 / CHECK.md C-1 and B-7): the dictionary column count
n_col = |{0} U outputs of the layer's exp table| for every layer of every
current export, against cap 32. Reads only public files (profile.json,
layer_NN/manifest.json, layer_NN/exp.bin: int64 x 256). Exports are found
under the calibration lanes' export dirs, the fidelity lane's exports and
this lane's verifier copies; duplicates (same profile.json sha256) are
listed once. Writes r9_ncol.json beside this script."""
import glob
import hashlib
import json
import os
import struct

ROOT = "/home/victor/IntelligenceRegulation/results"
CAP = 32
dirs = []
for pat in ("zk60_1b_calibration_20260929/export/*", "zk60_8b_calibration_20261017/export/*", "zk60_fidelity_parity_20261019/exports/*",
            "zk60_1b_native_20261017/r5b/verifier-exports/*", "zk60_1b_native_20261017/r6/verifier-exports/*", "zk60_1b_native_20261017/r8/verifier-exports/*"):
    dirs += sorted(d for d in glob.glob(os.path.join(ROOT, pat)) if os.path.isfile(os.path.join(d, "profile.json")))
seen, out = {}, {"cap": CAP, "exports": []}
for d in dirs:
    pb = open(os.path.join(d, "profile.json"), "rb").read()
    h = hashlib.sha256(pb).hexdigest()
    if h in seen:
        seen[h].append(d)
        continue
    seen[h] = [d]
    p = json.loads(pb)
    rows = []
    for l in p["layers"]:
        i = l if isinstance(l, int) else l.get("index", l.get("layer"))
        ld = os.path.join(d, f"layer_{i:02d}")
        m = json.load(open(os.path.join(ld, "manifest.json")))
        e = m["arrays"]["exp"]
        b = open(os.path.join(ld, e["file"]), "rb").read()
        vals = struct.unpack("<%dq" % (len(b) // 8), b)
        col = sorted({0} | set(vals))
        rows.append({"layer": i, "exp_e_s": m["constants"].get("exp_e_s"), "f_e": m["constants"].get("f_e"), "n_col": len(col), "fits": len(col) <= CAP})
    worst = max(r["n_col"] for r in rows)
    out["exports"].append({"export": d, "profile_sha256": h, "T": p.get("T"), "layers": len(rows), "worst_n_col": worst, "fits_cap": worst <= CAP,
                           "n_col_per_layer": [r["n_col"] for r in rows], "e_s_per_layer": [r["exp_e_s"] for r in rows]})
for e in out["exports"]:
    e["copies"] = seen[e["profile_sha256"]][1:]
json.dump(out, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "r9_ncol.json"), "w"), indent=1)
for e in out["exports"]:
    print(f"{os.path.relpath(e['export'], ROOT)}: T{e['T']} {e['layers']} layers, worst n_col {e['worst_n_col']} ({'fits' if e['fits_cap'] else 'EXCEEDS'} cap {CAP}); n_col {sorted(set(e['n_col_per_layer']))} at e_s {sorted(set(x for x in e['e_s_per_layer'] if x is not None))}")
