#!/usr/bin/env python3
"""Token round 19, item 7: which privacy-gate capture or source pins move from frozen-r18 to the r19 tree (read only).

usage: pins_r18_r19.py OLD_TREE NEW_TREE OUT.json

1. The capture writer's source pins: every path in run_capture.rs's OWN_SOURCE_FILES (38), SHARED_SOURCE_FILES (29)
   and CLASSIFY_SOURCE_FILES (5), parsed from the NEW tree's run_capture.rs (and checked equal to the OLD tree's
   lists), each hashed in both trees.
2. The gate's frozen v23 source-pin table (ops/zkp-mvp/gate-tinyllama/frozen_v23/scripts/zk60_native_rg_r13_pins.py,
   TOKEN_R16B_DIGESTS: the files and the digests it pins for the capture tree) - each pinned file hashed in both trees,
   and its pinned digest compared with each.
3. The gate's checkpoint default (zk60_native_rg_classtied.py SHIELD_DEFAULT_CHECKPOINT) against derive.rs's new
   default on this box.
Nothing here edits a gate file: the gate lane re-pins.
"""
import ast, hashlib, json, os, re, sys

OLD, NEW, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
GATE = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/frozen_v23/scripts"


def h(p):
    try:
        return hashlib.sha256(open(p, "rb").read()).hexdigest()
    except FileNotFoundError:
        return None


def lists(tree):
    s = open(os.path.join(tree, "hashline/src/private_block/run_capture.rs")).read()
    out = {}
    for name in ("OWN_SOURCE_FILES", "SHARED_SOURCE_FILES", "CLASSIFY_SOURCE_FILES"):
        m = re.search(r"const " + name + r": \[&str; (\d+)\] = \[(.*?)\];", s, re.S)
        body = "\n".join(l.split("//", 1)[0] for l in m.group(2).splitlines())  # drop line comments
        items = re.findall(r'"([^"]+)"', body)
        assert len(items) == int(m.group(1)), name
        out[name] = items
    return out


lo, ln = lists(OLD), lists(NEW)
assert lo == ln, "the capture pin lists themselves moved"
capture = []
for name, items in ln.items():
    for rel in items:
        a, b = h(os.path.join(OLD, "hashline", rel)), h(os.path.join(NEW, "hashline", rel))
        capture.append({"list": name, "file": rel, "r18": a, "r19": b, "moves": a != b})

# the gate's v23 pin table, evaluated with its own constants (only assignments of string literals and the table)
src = open(os.path.join(GATE, "zk60_native_rg_r13_pins.py")).read()
tree = ast.parse(src)
env = {}
for node in tree.body:
    if isinstance(node, ast.Assign):
        try:
            val = ast.literal_eval(node.value)
        except Exception:
            continue
        for t in node.targets:
            if isinstance(t, ast.Name):
                env[t.id] = val
            elif isinstance(t, ast.Tuple) and isinstance(val, tuple):
                for n, v in zip(t.elts, val):
                    env[n.id] = v
gate = []
derive_pin = env.get("DERIVE_T16")
m = re.search(r"TOKEN_R16B_DIGESTS = \{(.*?)\n\}", src, re.S)
for key, const in re.findall(r"(\w+): (\w+),", m.group(1)):
    rel = env.get(key)
    pin = env.get(const)
    if not isinstance(rel, str) or not isinstance(pin, str):
        continue
    a, b = h(os.path.join(OLD, "hashline", rel)), h(os.path.join(NEW, "hashline", rel))
    gate.append({"file": rel, "pin_name": const, "pin": pin, "r18": a, "r19": b, "r18_equals_pin": a == pin,
                 "r19_equals_pin": b == pin, "moves_r18_to_r19": a != b})
ct = open(os.path.join(GATE, "zk60_native_rg_classtied.py")).read()
shield = re.search(r'^SHIELD_DEFAULT_CHECKPOINT = "([^"]+)"', ct, re.M).group(1)
home = os.environ.get("HOME", "")
models = os.environ.get("ZK60_MODELS") or os.path.join(home, "models")
derive_default_here = os.path.join(models, "shieldstral-1.0-3b/snapshot-003ec7e2/model.safetensors")
rec = {
    "old": OLD, "new": NEW,
    "capture_pins": {"count": len(capture), "moving": [c for c in capture if c["moves"]]},
    "gate_v23_pin_table": {"checked": len(gate), "moving_r18_to_r19": [g for g in gate if g["moves_r18_to_r19"]],
                           "r18_files_not_equal_to_their_v23_pin": [g["file"] for g in gate if not g["r18_equals_pin"]]},
    "gate_DERIVE_T16": derive_pin,
    "gate_SHIELD_DEFAULT_CHECKPOINT": shield,
    "derive_default_on_this_box": derive_default_here,
    "checkpoint_default_equal_on_this_box": shield == derive_default_here,
    "gate_scripts_sha256": {f: h(os.path.join(GATE, f)) for f in ("zk60_native_rg_r13_pins.py", "zk60_native_rg_classtied.py")},
}
json.dump(rec, open(OUT, "w"), indent=1, sort_keys=True)
print(json.dumps({"capture_pins_moving": [c["file"] for c in rec["capture_pins"]["moving"]],
                  "gate_table_moving": [g["file"] for g in rec["gate_v23_pin_table"]["moving_r18_to_r19"]],
                  "gate_table_r18_not_at_pin": rec["gate_v23_pin_table"]["r18_files_not_equal_to_their_v23_pin"],
                  "DERIVE_T16": derive_pin, "checkpoint_default_equal_on_this_box": rec["checkpoint_default_equal_on_this_box"]}, indent=1))
