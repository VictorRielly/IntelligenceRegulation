#!/usr/bin/env python3
"""G-10 IS INERT ON EVERY HONEST BUNDLE: the v4 run integrity pass and the
frozen v3 pass, on every run bundle on disk, give the SAME record (the whole
dict, compared as sorted JSON), and the v4 pass carries no G-10 finding.

    python3 integrity_inert.py <out.json>

Bundles: the sixteen frozen development runs
(`wt-zk60-block125m/results/zk60_run_captures_20260920/run-*`) and every run
bundle under `/home/victor/zk60-artifacts/` (125M L = 2 / 12, the joint-view
lane's rungs, the six trained TinyLlama captures).  One bundle in memory at a
time.  Nothing is written but <out.json>.
"""
import gc
import glob
import json
import os
import resource
import sys
import time

GATE = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama"
sys.path.insert(0, os.path.join(GATE, "scripts"))

from zk60_native_rg_block import load_bundle  # noqa: E402
from zk60_native_rg_bundle import integrity  # noqa: E402
from zk60_native_rg_g10controls import _legacy_integrity  # noqa: E402


def bundles():
    out = sorted(glob.glob(
        "/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920/run-*"))
    for d in sorted(glob.glob("/home/victor/zk60-artifacts/*")):
        if os.path.isdir(d) and os.path.exists(os.path.join(d, "run.json")):
            out.append(d)
    return out


def main():
    legacy, legacy_sha = _legacy_integrity(os.path.join(GATE, "frozen_v3", "scripts"))
    rows = []
    for d in bundles():
        t0 = time.time()
        b = load_bundle(d)
        if getattr(b, "standalone", False):
            rows.append({"bundle": d, "skipped": "a standalone block bundle"})
            continue
        new = integrity(b)
        old = legacy(b)
        same = (json.dumps(new, sort_keys=True, default=str)
                == json.dumps(old, sort_keys=True, default=str))
        rows.append({
            "bundle": d,
            "blocks": b.blocks,
            "schema": b.schema,
            "v4_ok": new["ok"],
            "v3_ok": old["ok"],
            "v4_findings": new["findings"],
            "g10_findings": [x for x in new["findings"] if "(finding G-10)" in x],
            "records_identical": same,
            "seconds": round(time.time() - t0, 1),
        })
        print(f"{os.path.basename(d):42s} L={b.blocks:2d} v4 ok={new['ok']} "
              f"v3 ok={old['ok']} identical={same}", flush=True)
        del b, new, old
        gc.collect()
    checked = [r for r in rows if "skipped" not in r]
    out = {
        "what": __doc__.strip().splitlines()[0],
        "legacy_integrity_sha256": legacy_sha,
        "bundles_checked": len(checked),
        "all_identical": all(r["records_identical"] for r in checked),
        "no_g10_finding": all(not r["g10_findings"] for r in checked),
        "all_ok": all(r["v4_ok"] for r in checked),
        "peak_rss_mb": round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024),
        "rows": rows,
    }
    out["ok"] = bool(checked and out["all_identical"] and out["no_g10_finding"])
    with open(sys.argv[1], "w") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)
        fh.write("\n")
    print(f"checked {len(checked)}; identical {out['all_identical']}; "
          f"no G-10 finding {out['no_g10_finding']}; all ok {out['all_ok']}")
    return 0 if out["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
