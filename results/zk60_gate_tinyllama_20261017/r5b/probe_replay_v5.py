#!/usr/bin/env python3
"""Failing-first probe, second half: the frozen v5 tools' integrity pass and
transcript replay called DIRECTLY on an R5b bundle (the v5 driver suspends
them because the run-layer pins refuse -- P-2 working).  Shows whether the
transcript structure the gate transcribes still re-derives every challenge
BEFORE any R5b reading is added.   python3 probe_replay_v5.py <bundle> <out.json>"""
import json, sys
sys.path.insert(0, "/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/frozen_v5/scripts")
from zk60_native_rg_block import load_bundle
from zk60_native_rg_bundle import integrity
from zk60_native_rg_replay import RunReplay
b = load_bundle(sys.argv[1])
i = integrity(b)
s = RunReplay(b).run().summary()
out = {"bundle": b.name, "tools": "frozen v5", "integrity_ok": i["ok"], "integrity_findings": i["findings"],
       "replay_ok": s["ok"], "positions": s["positions_checked"], "challenges": s["challenges_checked"],
       "final_counter": s["final_counter"], "binding_reproduced": s["run_binding_reproduced"],
       "failures": s["failures"][:5]}
json.dump(out, open(sys.argv[2], "w"), indent=1, sort_keys=True)
print(json.dumps(out))
