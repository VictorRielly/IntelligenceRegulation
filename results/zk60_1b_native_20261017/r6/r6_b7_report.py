#!/usr/bin/env python3
"""NATIVE R6: summarize a per-layer-sh_s stack run (prove -> verify with
controls -> byte re-check) and compare it with a run-wide baseline run.
Checks: the identity equals the expected pin (the review lane's probe gave
97c4acda... for b7 T128); parity bit-exact at every layer; the published
statement names layer 1's own sh_s; the verifier published and re-checked;
all 11 controls refused. Prints labelled numbers (shared box, n=1).
usage: r6_b7_report.py <run dir> [<baseline run dir>] [<expected identity>] [<out json>]
Writes <run dir>/report.json unless <out json> is given."""
import json
import os
import re
import sys


def events(path):
    out = []
    if not os.path.isfile(path):
        return out
    for line in open(path, errors="replace"):
        line = line.strip()
        if line.startswith("{") and '"event"' in line:
            try:
                out.append(json.loads(line))
            except Exception:
                pass
    return out


def guard(path):
    try:
        return json.load(open(path))
    except Exception:
        return {}


def main():
    r = sys.argv[1]
    base = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else None
    want = sys.argv[3] if len(sys.argv) > 3 else None
    rep = {"run": r, "checks": {}, "numbers": {}}
    pv = events(os.path.join(r, "prove.log"))
    byk = {e["event"]: e for e in pv}
    proved = byk.get("proved", {})
    parity = byk.get("parity", {})
    rep["checks"]["parity"] = parity.get("result")
    rep["checks"]["parity_bit_exact_every_layer"] = parity.get("result") == "bit-exact at every layer"
    rep["numbers"]["prove"] = {k: proved.get(k) for k in ("blocks", "receipt_bytes", "prove_run_seconds", "of_which_witness_seconds", "sealing_pass_seconds", "load_seconds", "total_seconds", "vmhwm_mib", "statement_identity")}
    g = guard(os.path.join(r, "prove.guard.json"))
    rep["numbers"]["prove"]["guard_wall_s"] = g.get("child_wall_seconds")
    rep["numbers"]["prove"]["guard_peak_rss_gib"] = g.get("peak_rss_gib")
    rep["numbers"]["prove"]["guard_peak_cgroup_gib"] = g.get("peak_cgroup_gib")
    ident = proved.get("statement_identity")
    rep["checks"]["identity"] = ident
    if want:
        rep["checks"]["identity_equals_expected"] = ident == want
    sj = os.path.join(r, "run", "statement", "statement.json")
    rep["checks"]["statement_published"] = os.path.isfile(sj)
    if os.path.isfile(sj):
        st = open(sj).read()
        rep["checks"]["statement_schema_2"] = '"schema": "zk60-trained-stack-run/2"' in st
        rep["checks"]["statement_written_by_verifier"] = '"statement_written_by": "stack-verify, after its fresh-process verification' in st
        own = re.findall(r'\{"layer": (\d+), [^}]*"sh_s": (\d+)\}', st)
        rep["checks"]["layers_with_own_sh_s"] = {int(a): int(b) for a, b in own}
        m = re.search(r'"sh_s": (\d+), "sh_o"', st)
        rep["checks"]["run_sh_s"] = int(m.group(1)) if m else None
        rep["checks"]["layer_1_own_sh_s_7"] = rep["checks"]["layers_with_own_sh_s"].get(1) == 7
    rep["checks"]["unverified_dir_removed"] = not os.path.exists(os.path.join(r, "run.unverified-statement"))
    for pas in ("verify", "recheck"):
        p = os.path.join(r, f"{pas}.log")
        if not os.path.isfile(p):
            rep["checks"][pas] = "missing"
            continue
        ev = events(p)
        names = [e["event"] for e in ev]
        v = next((e for e in ev if e["event"] == "verified"), {})
        rep["numbers"][pas] = {k: v.get(k) for k in ("blocks", "receipt_bytes", "load_seconds", "verify_seconds", "vmhwm_mib")}
        gg = guard(os.path.join(r, f"{pas}.guard.json"))
        rep["numbers"][pas]["guard_wall_s"] = gg.get("child_wall_seconds")
        rep["numbers"][pas]["exit"] = open(os.path.join(r, f"{pas}.done")).read().strip() if os.path.isfile(os.path.join(r, f"{pas}.done")) else None
        rep["checks"][pas] = {"verified": "verified" in names, "controls_refused": names.count("control-refused"), "published": "statement-published" in names, "checked": "statement-checked" in names, "rejected": [e.get("error", "")[:160] for e in ev if e["event"] == "rejected"]}
    if base:
        bp = {e["event"]: e for e in events(os.path.join(base, "prove.log"))}.get("proved", {})
        bg = guard(os.path.join(base, "prove.guard.json"))
        rep["baseline"] = {"run": base, "prove_run_seconds": bp.get("prove_run_seconds"), "total_seconds": bp.get("total_seconds"), "receipt_bytes": bp.get("receipt_bytes"), "vmhwm_mib": bp.get("vmhwm_mib"), "guard_peak_rss_gib": bg.get("peak_rss_gib"), "statement_identity": bp.get("statement_identity")}
        if proved.get("prove_run_seconds") and bp.get("prove_run_seconds"):
            rep["baseline"]["prove_ratio_run_over_base"] = round(proved["prove_run_seconds"] / bp["prove_run_seconds"], 3)
        rep["baseline"]["same_receipt_bytes"] = proved.get("receipt_bytes") == bp.get("receipt_bytes")
    out = sys.argv[4] if len(sys.argv) > 4 else os.path.join(r, "report.json")
    json.dump(rep, open(out, "w"), indent=1)
    print(json.dumps(rep, indent=1))


main()
