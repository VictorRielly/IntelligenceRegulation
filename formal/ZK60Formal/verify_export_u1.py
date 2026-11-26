#!/usr/bin/env python3
"""Verify RunShapeShieldU1.lean typed export_u1 constants against export_u1/layer_{00..25}/manifest.json.

Usage:
    python3 -B formal/ZK60Formal/verify_export_u1.py \
        /Users/victorrielly/zk60-artifacts/a29-uniform-calibration/export_u1 \
        formal/ZK60Formal/RunShapeShieldU1.lean
"""
import hashlib
import json
import re
import sys
from pathlib import Path

EXPECTED_PROFILE_SHA = "9464388091d8095f8491f2990fde54e3b1f2b06f2a5c6ad1e72eff09cd4ce20a"
DEFAULT_EXPORT = Path("/Users/victorrielly/zk60-artifacts/a29-uniform-calibration/export_u1")
DEFAULT_LEAN = Path(__file__).resolve().with_name("RunShapeShieldU1.lean")


def read_export_u1(export_dir: Path):
    prof_path = export_dir / "profile.json"
    prof_bytes = prof_path.read_bytes()
    prof_sha = hashlib.sha256(prof_bytes).hexdigest()
    assert prof_sha == EXPECTED_PROFILE_SHA, f"profile.json sha256 mismatch: {prof_sha} != {EXPECTED_PROFILE_SHA}"
    prof = json.loads(prof_bytes)
    assert prof["T"] == 128 and prof["accuracy_stack"] == "low-h24-v1" and prof["geometry"] == "shieldstral-3b-t128"
    assert len(prof["layers"]) == 26

    rows = []
    for i, entry in enumerate(prof["layers"]):
        assert entry["layer"] == i
        mpath = export_dir / entry["dir"] / "manifest.json"
        mbytes = mpath.read_bytes()
        msha = hashlib.sha256(mbytes).hexdigest()
        assert msha == entry["manifest_sha256"], f"layer {i} manifest sha256 mismatch"
        m = json.loads(mbytes)
        c = m["constants"]
        assert (c["norm_tn"], c["norm_ceps"], c["sh_qkv"], c["sh_o"], c["sh_g"], c["sh_u"], c["f_e"], c["f_p"], c["sh_rope"]) == (
            9, 2439, 8, 9, 8, 0, 9, 12, 7
        ), f"layer {i} unexpected profile constant: {c}"
        gm = m["tables"]["act"]["group_members"]
        base_e_in = c["silu_member"][0]
        # accuracy_groups.rs:48-50: gate_shift = max(max_g(base_sh_g + 10 + (e_in - base_e_in)), 17)
        gate_shift = max(max(c["sh_g"] + 10 + (g[0] - base_e_in) for g in gm), 17)
        assert m["arrays"]["act"]["shape"] == [len(gm), 4096]
        rows.append((c["sh_ao"], c["sh_s"], c["sh_h"], c["sh_z"], gate_shift, c["norm_cn_a"], c["norm_cn_m"], len(gm)))
    return rows


def main():
    export_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_EXPORT
    lean_file = Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_LEAN
    rows = read_export_u1(export_dir)
    txt = lean_file.read_text()
    m = re.search(r"def shieldExportU1\s*:\s*List ShieldLayer\s*:=\s*\[([^\]]+)\]", txt, re.S)
    assert m, f"shieldExportU1 definition not found in {lean_file}"
    parsed = [
        tuple(int(x) for x in t)
        for t in re.findall(
            r"⟨\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*⟩",
            m.group(1),
        )
    ]
    assert parsed == rows, f"MISMATCH between {lean_file} ({len(parsed)} rows) and {export_dir} ({len(rows)} rows)"
    print(f"OK: all 26 layers of shieldExportU1 in {lean_file.name} match {export_dir} (profile sha256 {EXPECTED_PROFILE_SHA})")


if __name__ == "__main__":
    main()
