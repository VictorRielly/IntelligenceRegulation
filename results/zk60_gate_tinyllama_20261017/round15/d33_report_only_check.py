#!/usr/bin/env python3
"""[gate round 15] D33's part of the frozen-r11 re-pin, in memory: which
pinned files of a trained-block bundle the BLOCK gate enforces, and whether
frozen-r11 moves any of them.

A block bundle written from frozen-r9 (the tk9 captures) pins 52 files.
frozen-r11 moves two pinned files, both token files: `token_io.rs` and
`token_io/cli.rs`.  This script (frozen tools v18):

  1. lists every file the block gate's pin tables enforce (the terminal port's
     PORTED_FROM / PINNED_IF_PRESENT, the run-layer and shared tables, the
     mask layer) and checks that no token-I/O file is among them;
  2. takes the tk9 L = 1 dense bundle's manifest, replaces those two digests
     with frozen-r11's, and runs the terminal, run-layer and mask pin checks
     on both manifests: both must pass, with the same result;
  3. checks that each of the two digests is frozen-r11's file and that every
     OTHER pin of the tk9 bundle equals the frozen-r11 file of that name,
     except the capture writer `run_capture.rs`: the tk9 bundle pins the
     gate's test-only patched writer f47e28bf (the tk7 patch), whose base
     aaff4e6e must then be frozen-r11's file (so a block bundle written from
     a frozen-r11 gate copy with the same patch would differ from tk9's in
     exactly these two pins).

Nothing on disk is touched.  NOTHING HERE IS A PRIVACY STATEMENT.

    python3 d33_report_only_check.py <out.json>
"""
import copy
import hashlib
import json
import os
import sys
import types

V18 = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/frozen_v18/scripts"
sys.path.insert(0, V18)
sys.dont_write_bytecode = True

import zk60_native_rg_mask as MK  # noqa: E402
import zk60_native_rg_runpins as RP  # noqa: E402
import zk60_native_rg_terminals as T  # noqa: E402
import zk60_native_rg_tokenio_r11_pins as R11  # noqa: E402

B = "/home/victor/zk60-artifacts/tinyllama-trained-tk9-capture-dense-l1"
FR11 = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/frozen-r11/hashline"
# the tk7 / tk9 gate patch of the capture writer (tk9 re-pin note): patched
# f47e28bf..., base aaff4e6e... (frozen-r7 = frozen-r9)
WRITER_PATCHED = "f47e28bf"
WRITER_BASE = "aaff4e6e20c4deca7a0342f5b7dd2b9ac53a2837432af72f57c8a852e479db5e"


def sha(p):
    with open(p, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def main(out):
    enforced = set(T.PORTED_FROM) | set(T.PINNED_IF_PRESENT) | set(RP.RUN_LAYER_PINS) | set(MK.MASK_LAYER_PINS)
    for n in ("SHARED_G2_PINS", "SHARED_LAYER_PINS", "SHARED_NR4D_PINS", "PINNED_ELSEWHERE", "NEWLY_PINNED_OWN_FILES"):
        v = getattr(RP, n, None)
        if isinstance(v, dict):
            enforced |= set(v)
    token_enforced = sorted(f for f in enforced if "token_io" in f)
    man = json.load(open(os.path.join(B, "manifest.json")))
    r11 = {f: next(iter(rd)) for f, rd in R11.TOKEN_R11_READINGS.items()}
    m2 = copy.deepcopy(man)
    for p in m2["source_pins"]:
        if p["file"] in r11:
            p["sha256"] = r11[p["file"]]
    checks = {}
    for label, m in (("tk9 bundle as captured", man), ("the same with frozen-r11's two token digests", m2)):
        b = types.SimpleNamespace(manifest=m, name=os.path.basename(B), dir=B)
        t, r, k = T.check_source_pins(b), RP.check_run_layer_pins(b), MK.check_mask_layer_pins(b)
        checks[label] = {"terminal_pins_ok": t["ok"], "terminal_pins_moved": t.get("pins_that_moved"),
                         "run_layer_pins_ok": r.get("ok"), "mask_layer_pins_ok": k.get("ok")}
    pins = {p["file"]: p["sha256"] for p in man["source_pins"]}
    other_equal, other_differ = 0, []
    writer = {"file": "src/private_block/run_capture.rs", "tk9_pin": pins.get("src/private_block/run_capture.rs"),
              "gate_patch_base": WRITER_BASE,
              "frozen_r11": sha(os.path.join(FR11, "src/private_block/run_capture.rs"))}
    writer["ok"] = (writer["tk9_pin"] or "").startswith(WRITER_PATCHED) and writer["frozen_r11"] == WRITER_BASE
    for f, d in pins.items():
        if f in r11 or f == "src/private_block/run_capture.rs":
            continue
        if sha(os.path.join(FR11, f)) == d:
            other_equal += 1
        else:
            other_differ.append(f)
    r11_files_equal = {f: sha(os.path.join(FR11, f)) == d for f, d in r11.items()}
    ok = (not token_enforced and all(all(v for k, v in c.items() if k.endswith("_ok")) for c in checks.values())
          and not other_differ and all(r11_files_equal.values()) and writer["ok"])
    doc = {"what": __doc__.strip().splitlines()[0], "bundle": B, "tools": V18,
           "files_enforced_by_the_block_gate": len(enforced), "token_io_files_enforced": token_enforced,
           "pin_checks": checks, "tk9_pins": len(pins), "other_pins_equal_to_frozen_r11": other_equal,
           "other_pins_differing_from_frozen_r11": other_differ, "capture_writer": writer,
           "r11_token_digests_equal_frozen_r11_files": r11_files_equal, "ok": ok,
           "privacy_acceptance": False}
    with open(out, "w") as fh:
        json.dump(doc, fh, indent=1)
    print(json.dumps({k: doc[k] for k in ("files_enforced_by_the_block_gate", "token_io_files_enforced",
                                         "pin_checks", "tk9_pins", "other_pins_equal_to_frozen_r11",
                                         "other_pins_differing_from_frozen_r11", "capture_writer", "ok")}, indent=1))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1]))
