#!/usr/bin/env python3
"""[gate round 23, crash resume, 2026-10-30] Integrity check of every input that condition C-9 (`round23/c9.sh`) and
NL-1 on all 26 real blocks (`round23/nl26.sh`) read, after the hard crash of ~02:50 UTC (C: full).  A hard crash can
leave zero-byte or truncated files; each file below is compared, size and SHA-256, against the hash recorded BEFORE
the crash (the capture's own manifest, the frozen-v23 tool manifest, the in-code pins, the round-22 records).  Reads
only; writes one JSON record.  NOT a privacy result.

    python3 integrity_after_crash.py --out <json>
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time

sys.dont_write_bytecode = True
EV = "/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017"
REPO = "/home/victor/IntelligenceRegulation"
CAP = "/home/victor/zk60-artifacts/token-io/captures/classify-r13-shield-t128-cli-hate-r17-values"
FROZEN = f"{REPO}/ops/zkp-mvp/gate-tinyllama/frozen_v23"
ITEM3 = f"{REPO}/ops/zkp-mvp/gate-tinyllama/r22-item3"


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as fh:
        while True:
            b = fh.read(1 << 22)
            if not b:
                break
            h.update(b)
    return h.hexdigest()


def row(group, path, want_sha, want_bytes=None, source=""):
    r = {"group": group, "path": path, "source_of_expected": source, "expected_sha256": want_sha}
    if not os.path.isfile(path):
        r.update(exists=False, ok=False)
        return r
    n = os.path.getsize(path)
    got = sha(path)
    r.update(exists=True, bytes=n, sha256=got, zero_bytes=(n == 0))
    if want_bytes is not None:
        r["expected_bytes"] = want_bytes
    r["ok"] = (n > 0 and (got == want_sha if len(want_sha) == 64 else got.startswith(want_sha))
               and (want_bytes is None or n == want_bytes))
    return r


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    a = ap.parse_args(argv)
    t0 = time.time()
    rows = []
    # 1. the real hate-values capture: every file its manifest lists (run.json, 28 stage files, arrays.bin, README)
    man = json.load(open(os.path.join(CAP, "manifest.json")))
    for f in man["files"]:
        rows.append(row("capture", os.path.join(CAP, f["file"]), f["sha256"], f["bytes"], "capture manifest.json"))
    listed = {f["file"] for f in man["files"]} | {"manifest.json"}
    extra = sorted(set(os.listdir(CAP)) - listed)
    # the manifest itself: recorded by round 20 / 21 only implicitly (it names the other files); check it parses and
    # names 31 files of total_bytes
    man_ok = len(man["files"]) == 31 and sum(f["bytes"] for f in man["files"]) == man["total_bytes"]
    # 2. the frozen v23 tool tree against its manifest (gate-tinyllama.tools.frozen.v23.sha256)
    for line in open(os.path.join(EV, "gate-tinyllama.tools.frozen.v23.sha256")):
        h, p = line.split(None, 1)
        rows.append(row("frozen_v23", os.path.join(FROZEN, p.strip()), h, None, "gate-tinyllama.tools.frozen.v23.sha256"))
    # 3. the files the frozen tools pin in code (they refuse on a mismatch; checked here before launch)
    rows.append(row("pinned_in_code", os.path.join(EV, "g7", "ts_trained.py"),
                    "d6f6cf93ff1d5ad0dad6cb75671145b4e53bdd03be479841a72a0f2ae281f8bc", None,
                    "frozen_v23 zk60_native_rg_tokents.TS_TRAINED_PIN"))
    nl = f"{REPO}/results/zk60_nonlinear_channel_shaped"
    rows.append(row("pinned_in_code", os.path.join(nl, "nl_check.py"),
                    "e4db99a251ddde4f432675a53bd7e9149cdeb7c9edd61bbac87f50b87d0727c7", None,
                    "frozen_v23 zk60_native_rg_tokennl.NL_PINS"))
    rows.append(row("pinned_in_code", os.path.join(nl, "nl_field.py"),
                    "ea8ca39263213d88ef92c3f5d18fb8f86ed73471da027bf57348f94087dbb7e4", None,
                    "frozen_v23 zk60_native_rg_tokennl.NL_PINS"))
    # 4. the round-22 wrappers the two scripts run (full hashes from round 22's own records; ITEM3_REPORT §8)
    rows.append(row("r22_wrappers", os.path.join(ITEM3, "zk60_r22_classts2.py"),
                    "7a8e2649ce7a12c271007406ab62526cc50920cde5ffd2feb8fa30a337cfc836", None,
                    "round22/item3 ts2-real-hate-classifier-stages.json tool_sha256; ITEM3_REPORT §8"))
    rows.append(row("r22_wrappers", os.path.join(ITEM3, "zk60_r22_classnl.py"),
                    "4f0c2061b89ded2db81030f13150ddd4e7cdfbb343e706800ccd9c0d3003133d", None,
                    "round22/item3 nl-real-hate-blocks0-2.json tool_sha256; ITEM3_REPORT §8"))
    # 5. the live guard (read only; D46 pin 67e9478f...)
    rows.append(row("guard", f"{REPO}/scripts/zk60_resource_guard.py", "67e9478f", None,
                    "LANE_RULES addendum 2026-10-30 (D46, S9): live guard 67e9478f..."))
    # 6. the named binary that made the capture (provenance only; neither run executes it)
    rows.append(row("capture_provenance_binary",
                    f"{REPO}/results/zk60_token_io_r1_20261017/cli/zk60_classify.r17.release.bin",
                    "81bd86248e9f42393c9fe739e6794b7af155ad9a0a06874c89efb7a7bba18317", None, "capture README.md"))
    # 7. the gate's own drafts that must not change (v1, v2) and the round-22 / round-23 records v3 cites
    rows.append(row("drafts_readonly", f"{REPO}/docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_CLASSIFIER_SHIELDSTRAL_T128_DRAFT_v1.md",
                    "db89f427", None, "ledger round 22 (v1 kept)"))
    rows.append(row("drafts_readonly", f"{REPO}/docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_CLASSIFIER_SHIELDSTRAL_T128_DRAFT_v2.md",
                    "cfbfeafe", None, "ledger round 22 / 23 (v2 final for re-review)"))
    # 8. the scripts and helper the two runs execute (no pre-crash hash recorded: non-empty + compiles / parses)
    extra_checks = {}
    for p in (os.path.join(EV, "round20", "alone_check.py"), os.path.join(EV, "round23", "c9.sh"),
              os.path.join(EV, "round23", "nl26.sh")):
        n = os.path.getsize(p) if os.path.isfile(p) else -1
        ok = n > 0
        if p.endswith(".py") and ok:
            try:
                compile(open(p).read(), p, "exec")
            except SyntaxError as e:  # pragma: no cover
                ok = False
                extra_checks[p + ":error"] = str(e)
        extra_checks[p] = {"bytes": n, "sha256": sha(p) if n > 0 else None, "ok": ok,
                           "expected": "no pre-crash hash recorded: non-empty and (python) compiles"}
    bad = [r for r in rows if not r["ok"]]
    rec = {"what": "gate round 23 crash resume: integrity of C-9's and NL-1's inputs after the 2026-10-30 ~02:50 UTC "
                   "hard crash; NOT a privacy result", "privacy_acceptance": False,
           "rows": rows, "capture_manifest_consistent": man_ok, "capture_unlisted_files": extra,
           "unrecorded_hash_checks": extra_checks,
           "n_checked": len(rows), "n_ok": len(rows) - len(bad), "failed": [r["path"] for r in bad],
           "ok": not bad and man_ok and not extra and all(v["ok"] for k, v in extra_checks.items() if isinstance(v, dict)),
           "seconds": round(time.time() - t0, 1),
           "tool_sha256": sha(os.path.abspath(__file__))}
    with open(a.out, "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True)
        fh.write("\n")
    print(f"checked {rec['n_checked']}, ok {rec['n_ok']}, failed {rec['failed']}, manifest consistent {man_ok}, "
          f"unlisted {extra}, scripts {[(os.path.basename(k), v['ok']) for k, v in extra_checks.items() if isinstance(v, dict)]}"
          f" -> {'PASS' if rec['ok'] else 'NOT-OK'} ({rec['seconds']} s)")
    return 0 if rec["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
