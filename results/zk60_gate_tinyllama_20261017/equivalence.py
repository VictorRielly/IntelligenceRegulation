#!/usr/bin/env python3
"""THE PORT MOVES NO FROZEN FIGURE: run the ORIGINAL gate tools
(`ops/zkp-mvp/gate-tinyllama/original/`, byte-identical to the joint-view
worktree's) and the PORTED tools on the same FROZEN development bundle, the
same stages, with controls, and compare the two records leaf for leaf.

The only leaves allowed to differ are named here, each with its reason:
the tool digests (the tools differ, by design), the stage timings and peak
RSS (measurements), and the four record keys the port's driver now writes
from the bundle's shape name instead of the literal "125M"
(`gate`, `shape_name`, `what_this_is`, `what_it_does_not_show`).

    python3 equivalence.py <bundle> <other bundle> <evidence dir> <name>
"""

import json
import os
import subprocess
import sys

ROOT = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama"
ALLOWED = {"tool_sha256", "timings", "total_seconds", "peak_rss_mb", "gate",
           "shape_name", "what_this_is", "what_it_does_not_show"}
STAGES = "load,replay,hash,terminals,commitments,boundary,preimage,channels"


def run(tools, bundle, other, ev, name):
    cmd = [sys.executable, os.path.join(ROOT, tools, "zk60_native_rg_m125.py"),
           "--bundle", bundle, "--other", other, "--stages", STAGES,
           "--controls", "--evidence", ev, "--name", name]
    p = subprocess.run(cmd, cwd="/tmp", capture_output=True, text=True)
    return p.returncode, p.stdout[-2000:], p.stderr[-2000:]


def leaves(o, prefix=""):
    if isinstance(o, dict):
        for k, v in o.items():
            yield from leaves(v, f"{prefix}/{k}")
    elif isinstance(o, list):
        for i, v in enumerate(o):
            yield from leaves(v, f"{prefix}[{i}]")
    else:
        yield prefix, o


def main():
    bundle, other, ev, name = sys.argv[1:5]
    os.makedirs(ev, exist_ok=True)
    ro = run("original", bundle, other, ev, name + "-original")
    rp = run("scripts", bundle, other, ev, name + "-ported")
    a = json.load(open(os.path.join(ev, name + "-original.json")))
    b = json.load(open(os.path.join(ev, name + "-ported.json")))
    la = dict(leaves({k: v for k, v in a.items() if k not in ALLOWED}))
    lb = dict(leaves({k: v for k, v in b.items() if k not in ALLOWED}))
    only_a = sorted(set(la) - set(lb))
    only_b_all = sorted(set(lb) - set(la))
    differ_all = sorted(k for k in set(la) & set(lb) if la[k] != lb[k])
    # the three EXPLAINED classes, each named; nothing else may differ
    def explained(k):
        if k.endswith("/seconds"):
            return "a wall-clock measurement inside a stage"
        if "/argument_definitions_this_port_implements/9b26bda8105c" in k:
            return ("the port implements one more argument.rs digest (the "
                    "trained tree's, READ: zk60_native_rg_tinyllama_pins)")
        if k.endswith("/what") and "/stage8_plane_index_and_terminals/controls/" in k:
            return ("control CT-5's description now names the slot of the "
                    "padded domain it flips (still Dom::S, slot 17, here)")
        return None
    explained_leaves = [(k, explained(k)) for k in only_b_all + differ_all
                        if explained(k)]
    only_b = [k for k in only_b_all if not explained(k)]
    differ = [k for k in differ_all if not explained(k)]
    out = {
        "what": __doc__.strip().splitlines()[0],
        "bundle": os.path.basename(bundle),
        "stages": STAGES, "controls": True,
        "exit_codes": {"original": ro[0], "ported": rp[0]},
        "leaves_compared": len(set(la) & set(lb)),
        "leaves_only_in_the_original": only_a[:50],
        "leaves_only_in_the_port": only_b[:50],
        "leaves_that_differ": [(k, la[k], lb[k]) for k in differ[:50]],
        "counts": {"only_original": len(only_a), "only_port": len(only_b),
                   "differ": len(differ)},
        "allowed_to_differ": sorted(ALLOWED),
        "explained_differences": explained_leaves,
        "ok": not only_a and not only_b and not differ and ro[0] == rp[0],
    }
    with open(os.path.join(ev, name + ".json"), "w") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)
        fh.write("\n")
    print(json.dumps({k: out[k] for k in ("bundle", "exit_codes",
                                          "leaves_compared", "counts", "ok")}))
    return 0 if out["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
