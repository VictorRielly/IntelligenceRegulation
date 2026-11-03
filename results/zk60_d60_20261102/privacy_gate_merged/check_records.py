#!/usr/bin/env python3
"""Post-hoc check of the merged-gate records against the conditions of the round-27 freeze review
(FREEZE_REVIEW_V25.md, bottom line): before a record made by the pre-fix tool state counts as freeze evidence, it must
show controls on, the joint rank on, the Rust s25 printout at its pinned digest, exactly the 75 expected pins of the
registered writer, and no pin read on a prefix alone. Read only; prints one line per record and exits 1 if any fails.

The expected pin set is OWN_SOURCE_FILES + SHARED_SOURCE_FILES of run_capture.rs at the read digest 10b6d3be...
(the digest is checked here; a different file refuses the whole check)."""
import glob
import hashlib
import json
import os
import re
import sys

R = "/Users/victorrielly/IntelligenceRegulation"
RC = R + "/ops/zkp-mvp/gpu-metal/hashline/src/private_block/run_capture.rs"
RC_SHA = "10b6d3be860c73cd257e4b6b040b0351f10b993d8b1d1fdb5775057b71ef21c7"
PRINTOUT_SHA = "bac4bbd6838b2a090b131dd003ec1f6962063e12e1bb1cff80fa7a35ab65dc53"
RECORDS = sys.argv[1] if len(sys.argv) > 1 else R + "/results/zk60_d60_20261102/privacy_gate_merged/records"
PARTS_18 = ["D55-0 integrity", "D55-1/2 facts", "D55-3 replay", "R13-H registered header", "R13-2 layout", "R13-3 terminals",
            "R13-6 per commitment", "R13-7 mask and CFS", "D55-IO joined claims from the forks", "D55-J joint rank",
            "D55-C replay controls", "PINS controls", "TS-1 terminal surjection and its pair-removed control",
            "CENSUS claim census", "HASH-1 hash layer", "HASH-2 hash census", "NL-1 R13 slots, every fork",
            "PRE full zero-data preimage"]


def expected_pins():
    src = open(RC, "rb").read()
    if hashlib.sha256(src).hexdigest() != RC_SHA:
        sys.exit(f"run_capture.rs is not at the read digest {RC_SHA[:8]}; refusing")
    txt = src.decode()
    out = []
    for name, n in (("SHARED_SOURCE_FILES", 31), ("OWN_SOURCE_FILES", 44)):
        m = re.search(name + r": \[&str; (\d+)\] = \[(.*?)\];", txt, re.S)
        body = "\n".join(ln.split("//", 1)[0] for ln in m.group(2).split("\n"))  # comments quote words too
        files = re.findall(r'"([^"]+)"', body)
        assert int(m.group(1)) == n == len(files), (name, m.group(1), len(files))
        out += files
    assert len(set(out)) == 75
    return set(out)


def check(path, want):
    d = json.load(open(path))
    parts = d.get("parts", {})
    pins = d.get("PINS", {})
    rt = d.get("HASH-2 hash census", {}).get("rust_table", {})
    declared = set(pins.get("at_r19b_files", [])) | set(pins.get("read_here", []))
    r26 = set(pins.get("readings_r26", {}))
    bad = []
    if d.get("status") != "D55-PASS":
        bad.append(f"status {d.get('status')}")
    missing_parts = [p for p in PARTS_18 if p not in parts]
    if missing_parts:
        bad.append(f"parts absent: {missing_parts}")
    if [k for k, v in parts.items() if not v]:
        bad.append("a part is false")
    if "D55-C replay controls" not in parts or "PINS controls" not in parts:
        bad.append("controls off")
    if "D55-J joint rank" not in parts:
        bad.append("joint rank off")
    if rt.get("printout_sha256") != PRINTOUT_SHA:
        bad.append(f"printout sha256 {str(rt.get('printout_sha256'))[:12]}")
    if pins.get("pins") != 75 or declared != want:
        bad.append(f"pins {pins.get('pins')}, missing {sorted(want - declared)[:3]}, extra {sorted(declared - want)[:3]}")
    if pins.get("readings"):
        bad.append(f"W16 prefix readings used: {sorted(pins['readings'])}")
    if set(pins.get("read_here", [])) - r26:
        bad.append(f"read without an R26 full-digest reading: {sorted(set(pins['read_here']) - r26)}")
    if pins.get("unread"):
        bad.append(f"unread {pins['unread']}")
    if not (pins.get("backend") or {}).get("admissible"):
        bad.append("backend not admissible")
    return bad


def main():
    want = expected_pins()
    fails = 0
    files = sorted(glob.glob(os.path.join(RECORDS, "*.json")))
    for f in files:
        bad = check(f, want)
        fails += bool(bad)
        print(("OK   " if not bad else "FAIL ") + os.path.basename(f) + ("" if not bad else "  " + "; ".join(bad)))
    print(f"{len(files) - fails}/{len(files)} records meet the round-27 conditions")
    return 1 if fails or not files else 0


if __name__ == "__main__":
    sys.exit(main())
