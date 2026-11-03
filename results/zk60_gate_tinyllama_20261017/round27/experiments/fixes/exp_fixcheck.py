"""fr25 fixes review: independent checks of ec12ffb2's new constants and rules,
on in-memory copies only (the fixer's worktree and the bundles are read, never
written; -B, no bytecode).

  A  REGISTERED_WRITER_PINS / the test-only extras against run_capture.rs and
     w16_privacy_gate_tests.rs parsed here, independently of derive_pins.py
  B  every D55 manifest under zk60-artifacts/d60_20261102: pin set, PINS as the
     driver computes it, backend, PINS controls (families, not applicable)
  C  W16_READINGS: full digests, agreement with R26, twins
  D  pin_set_check bypass attempts
  E  d55_status probes
  F  load_rust / hash2_verdict refusals"""
import copy
import glob
import hashlib
import json
import os
import re
import sys
import types

sys.dont_write_bytecode = True
WT = "/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/fr25-fixes"
S = WT + "/ops/zkp-mvp/gate-tinyllama/staging_v25/scripts"
sys.path.insert(0, S)
import zk60_native_rg_d55 as D  # noqa: E402
import zk60_native_rg_w16 as W  # noqa: E402
import zk60_native_rg_r26readings as R26  # noqa: E402
import zk60_native_rg_terminals as T  # noqa: E402
import zk60_native_rg_d55hash as H  # noqa: E402

for m in (D, W, R26, H):
    assert os.path.realpath(m.__file__).startswith(os.path.realpath(S)), m.__file__
HL = "/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/gpu-metal/hashline"
r19b = W.default_r19b_manifest()
print("r19b manifest:", r19b)


def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


# ---------------------------------------------------------------- A
rc = HL + "/src/private_block/run_capture.rs"
print("\nA. run_capture.rs sha256", sha(rc)[:12], "== RUN_CAPTURE_RS_READ:", sha(rc) == D.RUN_CAPTURE_RS_READ)
src = open(rc).read()


def arr(name):
    m = re.search(r"const " + name + r": \[&str; (\d+)\] = \[(.*?)\];", src, re.S)
    body = re.sub(r"//[^\n]*", "", m.group(2))
    items = re.findall(r'"([^"]+)"', body)
    return int(m.group(1)), items


n_own, own = arr("OWN_SOURCE_FILES")
n_sh, shared = arr("SHARED_SOURCE_FILES")
print("   OWN declared", n_own, "parsed", len(own), "| SHARED declared", n_sh, "parsed", len(shared))
derived = own + shared
print("   derived == REGISTERED_WRITER_PINS (order too):", tuple(derived) == D.REGISTERED_WRITER_PINS,
      "| as sets:", set(derived) == set(D.REGISTERED_WRITER_PINS), "| distinct:", len(set(derived)))
w16t = open(HL + "/src/private_block/w16_privacy_gate_tests.rs").read()
m = re.search(r'for extra in \[(.*?)\]', w16t, re.S)
extras = re.findall(r'"([^"]+)"', m.group(1))
print("   test-only writer extras parsed:", extras, "== TEST_ONLY_EXTRA_PINS:", tuple(extras) == D.TEST_ONLY_EXTRA_PINS)
print("   expected sizes:", {k[:30]: len(v) for k, v in D.EXPECTED_PINS.items()})
for wname, ln in (("REGISTERED", 4469), ("TEST_ONLY", 1966)):
    pass
print("   writer strings in the Rust sources:", D.REGISTERED_WRITER in src, D.TEST_ONLY_WRITER in w16t)


# ---------------------------------------------------------------- B
def driver_pins(man):
    """d55_gate's PINS.ok at ec12ffb2 (:1132-1147) for an R13 bundle"""
    pins = W.classify_pins(types.SimpleNamespace(manifest=man), r19b)
    sp = T.check_source_pins(types.SimpleNamespace(manifest=man))
    refused = [x.split(":")[0].strip() for x in sp.get("pins_that_moved", []) + sp.get("pins_missing_from_the_bundle", [])]
    covered = set(pins["at_r19b_files"]) | set(pins["read_here"])
    nr = [f for f in refused if f not in covered]
    ps = D.pin_set_check(man)
    return pins, ps, bool(pins["ok"] and not nr and ps["ok"])


print("\nB. every D55 manifest in the artifacts")
mans = sorted(glob.glob("/Users/victorrielly/zk60-artifacts/d60_20261102/**/manifest.json", recursive=True))
for p in mans:
    man = json.load(open(p))
    if man.get("schema") != D.SCHEMA_D55:
        continue
    pins, ps, ok = driver_pins(man)
    pc = D.pin_controls(types.SimpleNamespace(manifest=man), r19b)
    fires = {k.split(" ")[0]: v["fires"] for k, v in pc["controls"].items()}
    print(f"   {os.path.relpath(os.path.dirname(p), '/Users/victorrielly/zk60-artifacts/d60_20261102')}: writer_known "
          f"{ps['writer_known']} set {ps['declared']}/{ps['expected']} ok {ps['ok']} | unread {len(pins['unread'])} "
          f"backend {pins['backend']['admissible']} self_read {pins['self_read_pending_independent_check']} | PINS.ok {ok} | "
          f"controls ok {pc['ok']} n/a {pc['not_applicable']} {fires}")

# ---------------------------------------------------------------- C
print("\nC. W16_READINGS")
for f, (d, _t) in sorted(W.W16_READINGS.items()):
    r = R26.R26_READINGS.get((f, d[:12]))
    print(f"   {f}: 64-hex {bool(re.fullmatch(r'[0-9a-f]{64}', d))}, R26 at prefix {'yes, equal' if r and r[0] == d else ('yes, DIFFERS' if r else 'no')}")
base = json.load(open("/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_r26/d55-r13_rung_h24-s0/manifest.json"))


def cls(f, d):
    m = copy.deepcopy(base)
    for p in m["source_pins"]:
        if p["file"] == f:
            p["sha256"] = d
    return W.classify_pins(types.SimpleNamespace(manifest=m), r19b)


for f in ("src/private_block/run.rs", "src/private_block/run_capture.rs"):
    full = W.W16_READINGS[f][0]
    for label, d in (("full", full), ("prefix+52 zeros", full[:12] + "0" * 52), ("last hex flipped", full[:-1] + ("0" if full[-1] != "0" else "1"))):
        p = cls(f, d)
        print(f"   {f} @ {label}: read_here {f in p['read_here']}, unread {f in [u['file'] for u in p['unread']]}, classify ok {p['ok']}")

# ---------------------------------------------------------------- D
print("\nD. pin_set_check bypass attempts on the rung manifest")


def ps_of(mut):
    m = copy.deepcopy(base)
    mut(m)
    r = D.pin_set_check(m)
    return {k: r.get(k) for k in ("writer_known", "declared", "expected", "ok")} | {"missing": len(r.get("missing") or []), "unexpected": r.get("unexpected"), "dup": r.get("duplicates")}


tries = {
    "honest": lambda m: None,
    "writer with a trailing space": lambda m: m.__setitem__("writer", m["writer"] + " "),
    "writer absent": lambda m: m.pop("writer"),
    "writer = test-only string, 75 pins": lambda m: m.__setitem__("writer", D.TEST_ONLY_WRITER),
    "a path variant of run.rs": lambda m: [p.__setitem__("file", "src/private_block/./run.rs") for p in m["source_pins"] if p["file"] == "src/private_block/run.rs"],
    "one pin duplicated, one dropped": lambda m: m.__setitem__("source_pins", m["source_pins"][:-1] + [m["source_pins"][0]]),
    "pins reordered": lambda m: m.__setitem__("source_pins", list(reversed(m["source_pins"]))),
    "an entry without 'file'": lambda m: m["source_pins"].append({"sha256": "0" * 64}),
}
for k, mut in tries.items():
    print(f"   {k}: {ps_of(mut)}")

# ---------------------------------------------------------------- E
print("\nE. d55_status probes")
G = "G_k in the clear: recovered on SC_FZC, not read from a bound line"
P = {"a": True, "b": True}
probes = {
    "all true, R13, not_here [G_k]": (P, True, "R13", [G], True, True),
    "all true, R13, not_here []": (P, True, "R13", [], True, True),
    "pins not ok": (P, False, "R13", [G], True, True),
    "no controls": (P, True, "R13", [G], False, True),
    "no joint": (P, True, "R13", [G], True, False),
    "W16 family": (P, True, "W16", [], True, True),
    "unaccepted not_here": (P, True, "R13", [G, "full preimage"], True, True),
    "a part false": ({"a": True, "b": False}, True, "R13", [G], True, True),
    "no parts": ({}, True, "R13", [G], True, True),
    "a part None": ({"a": True, "b": None}, True, "R13", [G], True, True),
    "G_k string with a trailing space": (P, True, "R13", [G + " "], True, True),
}
for k, a in probes.items():
    r = D.d55_status(*a)
    print(f"   {k}: {r['status']}  reasons {len(r['status_reasons'])}")
print("   ACCEPTED_RESIDUALS:", D.ACCEPTED_RESIDUALS)
drv = open(S + "/zk60_native_rg_d55.py").read()
print("   places assigning rec['status'] in the driver:", [ln for ln in drv.splitlines() if re.search(r"""rec\[["']status["']\]\s*=|"status":\s*"(D55|NOT|REF)""", ln)])

# ---------------------------------------------------------------- F
print("\nF. load_rust")
for k, path in (("unset", ""), ("missing file", "/nonexistent/s25.log"), ("a directory", "/tmp"),
                ("an edited copy", None), ("the genuine printout", "/Users/victorrielly/zk60-artifacts/d60_20261102/s25_w2_printout_v2.log")):
    if path is None:
        scr = os.path.join(sys.argv[1], "s25_edited.log")
        raw = open("/Users/victorrielly/zk60-artifacts/d60_20261102/s25_w2_printout_v2.log", "rb").read()
        open(scr, "wb").write(raw + b"\n")
        path = scr
    os.environ.pop(H.S25_W2_PRINTOUT_ENV, None)
    rust, why = H.load_rust(base["profile"], path=path) if path else H.load_rust(base["profile"])
    hc = H.hash2_verdict({"ok": True, "findings": [], **({"rust_table": {"ok": True}} if rust else {})}, rust, why, True, True)
    print(f"   {k}: loaded {rust is not None}, kinds {len(rust['table']) if rust else None}, HASH-2 ok {hc['ok']}, "
          f"refused {(why or {}).get('refused', '')[:70]!r}")
