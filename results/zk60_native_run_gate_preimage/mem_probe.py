#!/usr/bin/env python3
"""ROUND 7's memory figure, isolated.

The gate's own `/usr/bin/time -v` peak (677-713 MB) is the whole PROCESS,
which holds FOUR bundles at once -- the one under test plus `--other`,
`--old` and `--cross-profile`, each ~40 MB of JSON parsed into Python
objects.  That is not the cost of the construction.  This probe loads ONE
bundle and runs the stage-11 arm over all ten PCS commitments, reporting the
resident set after the load and after the arm, so the arm's own cost is the
difference and is stated as such.

    /usr/bin/time -v python3 results/zk60_native_run_gate_preimage/mem_probe.py <bundle>
"""
import json
import os
import resource
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "scripts"))

from zk60_native_rg_ahpreimage import full_preimages  # noqa: E402
from zk60_native_rg_bundle import RunBundle  # noqa: E402
from zk60_native_rg_pcs import RunRoleView  # noqa: E402
from zk60_native_rg_replay import RunReplay  # noqa: E402


def mb():
    return round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024.0, 1)


path = sys.argv[1]
t0 = time.time()
b = RunBundle(path)
rep = RunReplay(b).run()
views = {}
for st in b.stages:
    for role in st.roles:
        k = st.key(role["role"])
        v = RunRoleView(st, role, rep.stages[st.index]["role_prox_rhos"][k],
                        b.shape, name=k)
        v.run(rep.stages[st.index]["role_lambdas"][k])
        views[k] = v
after_load = mb()
t1 = time.time()
out = full_preimages(b, views, names=list(views))
after_arm = mb()
print(json.dumps({
    "bundle": b.name,
    "peak_mb_after_one_bundle_and_its_views": after_load,
    "peak_mb_after_the_arm": after_arm,
    "the_arm_s_own_peak_mb": round(after_arm - after_load, 1),
    "load_and_views_seconds": round(t1 - t0, 1),
    "arm_seconds": out["seconds"],
    "commitments": len(out["exhibited"]),
    "view_entries_compared": out["view_entries_compared"],
    "view_entries_differing": out["view_entries_differing"],
    "salted_leaves_authenticated": out["salted_leaves_authenticated"],
    "ok": out["ok"],
    "note": "the gate's whole-process peak is larger because a gate run holds "
    "four bundles at once (--other, --old, --cross-profile); the arm's own "
    "cost is the difference reported here",
}, indent=1))
