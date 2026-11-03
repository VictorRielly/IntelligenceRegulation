"""fr25 experiment: does classify_pins / the D55 driver's PINS check notice an
INCOMPLETE source-pin list?  Reads one real bundle manifest (read-only), builds
doctored copies in memory only, and runs the gate's own functions on them."""
import copy
import json
import sys
import types

S = "/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/staging_v25/scripts"
sys.path.insert(0, S)
import zk60_native_rg_w16 as W  # noqa: E402
import zk60_native_rg_terminals as T  # noqa: E402

BUNDLE = sys.argv[1]
man = json.load(open(BUNDLE + "/manifest.json"))
r19b = W.default_r19b_manifest()


def driver_pins(m):
    """zk60_native_rg_d55.d55_gate lines 897-909, verbatim logic, on a manifest"""
    pins = W.classify_pins(types.SimpleNamespace(manifest=m), r19b)
    sp = T.check_source_pins(types.SimpleNamespace(manifest=m))
    refused = [x.split(":")[0].strip() for x in sp.get("pins_that_moved", []) + sp.get("pins_missing_from_the_bundle", [])]
    covered = set(pins["at_r19b_files"]) | set(pins["read_here"])
    not_read = [f for f in refused if f not in covered]
    return {"pins_declared": pins["pins"], "unread": [u["file"] for u in pins["unread"]],
            "backend_admissible": pins["backend"]["admissible"], "terminal_port_not_read": not_read,
            "PINS_ok": bool(pins["ok"] and not not_read)}


print("bundle", BUNDLE, "proved_on_gpu", man.get("proved_on_gpu"), "pins", len(man["source_pins"]))
print("honest            ", driver_pins(man))
keep = set(T.PORTED_FROM) | set(T.PINNED_IF_PRESENT)
m2 = copy.deepcopy(man)
m2["source_pins"] = [p for p in m2["source_pins"] if p["file"] in keep]
print("only the port's 4+2", driver_pins(m2), "kept", sorted(p["file"] for p in m2["source_pins"]))
dropped = sorted(p["file"] for p in man["source_pins"] if p["file"] not in keep)
print("dropped", len(dropped), "incl.", [f for f in dropped if f.endswith(("run_fork.rs", "run_fork_wire.rs", "run_capture.rs", "metal.rs", "metal_kernels.metal", "rng.rs", "pcs.rs"))])
m3 = copy.deepcopy(man)
m3["source_pins"] = []
print("no pins at all     ", driver_pins(m3), "(W16-family driver has no terminal-port floor:",
      W.classify_pins(types.SimpleNamespace(manifest=m3), r19b)["ok"], ")")
