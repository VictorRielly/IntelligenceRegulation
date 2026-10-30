#!/usr/bin/env python3
"""[gate round 20, dev, staging v23] MEASURE before declaring: on the REAL values bundle
(classify-r13-shield-t128-cli-hate-r17-values, arrays.bin 2.25 GB) run load, integrity
(streamed hash), replay, the per-commitment views (held, as the gate holds them), then the R13
block terminals WITH values on a small block subset (one call, controls on, as the gate calls
it), sampling RSS (VmRSS = RssAnon + RssFile + RssShmem) every 0.5 s with checkpoints.

    python3 real_values_dev.py <scripts> <bundle> <out.json> <blocks comma list>
"""
import json
import os
import sys
import threading
import time


def status():
    out = {}
    with open("/proc/self/status") as fh:
        for ln in fh:
            k, _, v = ln.partition(":")
            if k in ("VmRSS", "RssAnon", "RssFile", "RssShmem", "VmHWM"):
                out[k] = round(int(v.split()[0]) / 1048576, 3)
    return out


def main(scripts, bundle, path, blocks):
    sys.path.insert(0, scripts)
    import zk60_native_rg_classgate as CG
    import zk60_native_rg_r13blocks as RB
    rec = {"what": "gate round 20 dev measurement on the real values bundle; not a gate record, not a privacy result",
           "bundle": bundle, "scripts": scripts, "checkpoints": [], "samples_peak": {}}
    peak = {"VmRSS": 0.0, "RssAnon": 0.0, "RssFile": 0.0}
    stop = []

    def sampler():
        while not stop:
            s = status()
            for k in peak:
                peak[k] = max(peak[k], s.get(k, 0.0))
            time.sleep(0.5)
    th = threading.Thread(target=sampler, daemon=True)
    th.start()
    t0 = time.time()

    def cp(name, **kw):
        rec["checkpoints"].append(dict(name=name, t=round(time.time() - t0, 1), **status(), **kw))
        print(rec["checkpoints"][-1], flush=True)
    b = CG.load(bundle)
    cp("load", public_tables_included=b.public_tables_included)
    i = CG.class_integrity(b)
    cp("integrity", ok=i["ok"], findings=i["findings"][:3], pins=i["source_pins"]["pins"])
    rp = CG.ClassRunReplay(b).run()
    cp("replay", ok=rp.summary()["ok"])
    s3, views = CG.class_stage3(b, rp, pad_rank=True)
    cp("per_commitment", ok=s3.get("ok"), commitments=len(views))
    bl = [int(x) for x in blocks.split(",")]
    t = RB.r13_block_terminals(b, rp, controls=True, blocks=bl)
    cp("block_terminals", blocks=bl, per_stage=[{k: p.get(k) for k in ("block", "gate_shift", "ok", "slot_checks_equal",
       "slot_checks_expected", "open_by_capture_option", "checked_not_equal", "seconds", "captured_tables")}
       for p in t.get("per_stage", [])], controls={k: v.get("fires") for k, v in (t.get("controls") or {}).items()
       if isinstance(v, dict)}, refused=t.get("refused"))
    stop.append(1)
    th.join(2)
    rec["samples_peak"] = peak
    rec["total_seconds"] = round(time.time() - t0, 1)
    with open(path, "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True, default=str)
    print("peak", peak, "total", rec["total_seconds"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main(*sys.argv[1:5]))
