#!/usr/bin/env python3
"""Build a READER-COMPATIBILITY SHIM for the calibration lane's smoke export.

The smoke export (`export/a_smoke_T32_L3smoke/`) has layer directories but no
profile.json (the writer emits profile.json only after a full 22-layer run).
This script writes, in the NATIVE lane's own evidence directory, a variant
directory whose `profile.json` follows the writer's code (b3_ladder.py
`profile = {...}`) and whose `layer_NN` entries are SYMLINKS to the lane's
layer directories (read-only use). It copies nothing and writes nothing
outside the native evidence directory. No sequence data exists, so this is a
format / digest / table / constant compatibility check only, not parity.
"""
import hashlib, json, os, sys
from pathlib import Path

src = Path(sys.argv[1]).resolve()          # .../export/a_smoke_T32_L3smoke
dst = Path(sys.argv[2]).resolve()          # .../zk60_1b_native_20261017/smoke_shim/<name>
dst.mkdir(parents=True, exist_ok=True)
layers = sorted(int(p.name.split("_")[1]) for p in src.glob("layer_*") if p.is_dir())
mans = {}
for l in layers:
    mp = src / f"layer_{l:02d}" / "manifest.json"
    mans[l] = (json.loads(mp.read_text()), hashlib.sha256(mp.read_bytes()).hexdigest())
    link = dst / f"layer_{l:02d}"
    if not link.exists():
        os.symlink(src / f"layer_{l:02d}", link)
pc = mans[layers[0]][0]["constants"]
uniform = {k: pc[k] if all(mans[l][0]["constants"][k] == pc[k] for l in layers) else None for k in pc}
calib_dir = src.parents[1]
tool = {"path": str(calib_dir.relative_to(calib_dir.parents[1])), "sha256": {p: hashlib.sha256((calib_dir / p).read_bytes()).hexdigest()
        for p in ("tlcalib.py", "b3calib.py", "b3_ladder.py", "corpus.py", "spm_bpe.py") if (calib_dir / p).exists()}}
profile = {"schema": "zk60-trained-profile-export/1", "kind": "profile", "variant": src.name,
           "model": {"repo": "TinyLlama/TinyLlama-1.1B-Chat-v1.0", "revision": "fe8a4ea1ffedaf415f4da2f062534de366a451e6",
                     "sha256": "6e6001da2106d4757498752a021df6c2bdc332c650aae4bae6b0c004dcf14933", "file": "model.safetensors"},
           "calibration_tool": tool, "T": 32, "profile_constants": uniform,
           "per_layer_constants_differ": sorted(k for k, v in uniform.items() if v is None),
           "layers": [{"layer": l, "dir": f"layer_{l:02d}", "manifest_sha256": mans[l][1]} for l in layers],
           "sequences": [], "scope": "NATIVE-LANE READER SHIM over the calibration lane's smoke layers; not the lane's export; no sequences"}
(dst / "profile.json").write_text(json.dumps(profile, indent=1, sort_keys=True))
print(json.dumps({"shim": str(dst), "layers": layers, "per_layer_constants_differ": profile["per_layer_constants_differ"],
                  "uniform": {k: v for k, v in uniform.items() if v is not None}}))
