#!/usr/bin/env python3
"""B7: check an export against the native R6 loader's per-layer sh_s format (coordinator, 2026-10-17 23:4xZ):
profile_constants.sh_s is null; per_layer_constants_differ == ["exp_e_s", "sh_s", "silu_member"]; every layer
manifest carries constants.sh_s in 1..=8 (layer 1 = 7, others 6); profile layers[].manifest_sha256 equal the
manifests' sha256; every key the profile declares uniform agrees across all layer manifests. Prints JSON, exit 1
on any failure. Usage: b7_check_format.py <export_dir>"""
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
prof = json.loads((root / "profile.json").read_text())
errs = []
pc = prof["profile_constants"]
if "sh_s" not in pc or pc["sh_s"] is not None:
    errs.append(f"profile_constants.sh_s is {pc.get('sh_s', 'absent')!r}, want null")
want = ["exp_e_s", "sh_s", "silu_member"]
if prof["per_layer_constants_differ"] != want:
    errs.append(f"per_layer_constants_differ {prof['per_layer_constants_differ']} != {want}")
nulls = sorted(k for k, v in pc.items() if v is None)
if nulls != prof["per_layer_constants_differ"]:
    errs.append(f"null profile keys {nulls} != per_layer_constants_differ")
shs = []
for ent in prof["layers"]:
    mb = (root / ent["dir"] / "manifest.json").read_bytes()
    if hashlib.sha256(mb).hexdigest() != ent["manifest_sha256"]:
        errs.append(f"{ent['dir']}: manifest sha256 != profile")
    c = json.loads(mb)["constants"]
    s = c.get("sh_s")
    shs.append(s)
    if not isinstance(s, int) or not 1 <= s <= 8:
        errs.append(f"{ent['dir']}: sh_s {s!r} not an integer in 1..=8")
    if s != (7 if ent["layer"] == 1 else 6):
        errs.append(f"{ent['dir']}: sh_s {s} (want {7 if ent['layer'] == 1 else 6})")
    for k, v in pc.items():
        if v is not None and c.get(k) != v:
            errs.append(f"{ent['dir']}: constant {k} {c.get(k)!r} != profile {v!r}")
rep = {"export": str(root), "layers": len(prof["layers"]), "sh_s_by_layer": shs, "T": prof["T"],
       "per_layer_constants_differ": prof["per_layer_constants_differ"], "errors": errs, "ok": not errs}
print(json.dumps(rep, indent=1))
sys.exit(0 if not errs else 1)
