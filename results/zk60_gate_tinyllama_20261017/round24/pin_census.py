#!/usr/bin/env python3
"""[gate round 24, step 2] The gate's pin and census checks that read the TOKEN TREE, re-run against
token frozen-r19b (and r18 / r19 / r17), with the NEW tools (v24) and, as the control, the OLD (frozen v23).

    python3 pin_census.py --v24 <v24 scripts dir> --out <json>

Each tools version runs in its OWN process (the module names collide), `--worker <scripts dir>`:
* the capture pin rule (`classify_capture_pins`, each version's dispatcher) on the 72 source pins the
  recorder of frozen-r17 / r18 / r19 / r19b would write (the files hashed in each frozen tree), and on the
  capture manifests on disk (the round-24 r19b P-18 capture, round 20's r17 real capture, round 19's r16b real
  capture, round 18's r14 short capture);
* `zk60_native_rg_r13_pins.self_check()` (the reading chains, every digest re-hashed in the frozen trees, the
  terminal tables against their manifests);
* `zk60_native_rg_classpins.r17_self_check()` and, where present, `r19b_self_check()`;
* v24 only, the controls with the OLD pins in place of the new: the r19b readings removed (the rule and the
  self-check must then refuse r19b by name), and the r19b terminal of derive.rs set back to DERIVE_T16 (the
  r13 self-check must then fail).
And in this process, a READ census of the token tree (the C-R1 / hash-domain census of round 22, re-checked
at r19b): every C-R1 site's source file r17 vs r19b (unchanged -> the site and its length formula carry;
BlockPublic::digest's lines compared where its file moved); every changed PRODUCTION file's text (comment
lines dropped, above its `#[cfg(test)] mod tests {`) r17 vs r19b scanned for hash / transcript / generator
tokens; a control plants one such token in a copy and must be seen.  NOT a privacy result.
"""
import argparse
import hashlib
import json
import os
import re
import subprocess
import sys

REPO = "/home/victor/IntelligenceRegulation"
TOK = REPO + "/results/zk60_token_io_r1_20261017"
CAP = "/home/victor/zk60-artifacts/token-io/captures"
CAPTURES = ["classify-rc3-cli-p18-r19b-gate24", "classify-r13-shield-t128-cli-hate-r17-values",
            "classify-r13-shield-t128-cli-sexual-r16b", "classify-rc3-rung-L2-v1-short20"]
PB, DRV = "src/private_block.rs", "src/private_block/tied_tables/derive.rs"
TOKENS = ["blake3", "Hasher", "new_keyed", "derive_key", "hash_tag", "absorb", "squeeze", "transcript", "Transcript",
          "ZkRng", "from_os", "challenge", "Sha256", "sha256"]


def sha_file(p):
    h = hashlib.sha256()
    with open(p, "rb") as fh:
        for c in iter(lambda: fh.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()


# ------------------------------------------------------------------ the worker (one tools version)
def tree_manifest(CP, tag):
    rel = f"results/zk60_token_io_r1_20261017/frozen-{tag}/hashline"
    pins = [{"file": f, "sha256": sha_file(os.path.normpath(os.path.join(REPO, rel, f)))} for f in CP._capture_pin_files(rel)]
    return {"source_pins": pins}


def capture_pin_files_v23(tag):
    """v23 has no `_capture_pin_files`: the same parse, here"""
    src = open(os.path.join(TOK, f"frozen-{tag}/hashline/src/private_block/run_capture.rs")).read()
    out = []
    for name in ("OWN_SOURCE_FILES", "SHARED_SOURCE_FILES", "CLASSIFY_SOURCE_FILES"):
        m = re.search(r"const " + name + r": \[&str; (\d+)\] = \[(.*?)\];", src, re.S)
        out += re.findall(r'"([^"]+)"', re.sub(r"//[^\n]*", "", m.group(2)))
    return out


def worker(scripts):
    sys.path.insert(0, scripts)
    import zk60_native_rg_classpins as CP
    import zk60_native_rg_r13_pins as R13
    if not hasattr(CP, "_capture_pin_files"):
        CP._capture_pin_files = lambda rel: capture_pin_files_v23(rel.split("frozen-")[1].split("/")[0])
    out = {"scripts": scripts, "pin_rule_on_the_trees": {}, "pin_rule_on_captures": {}}
    for tag in ("r17", "r18", "r19", "r19b"):
        v = CP.classify_capture_pins(tree_manifest(CP, tag))
        out["pin_rule_on_the_trees"][tag] = {"ok": v["ok"], "pins": v["pins"], "port": v["port"], "refusals": v["refusals"]}
    for name in CAPTURES:
        p = os.path.join(CAP, name, "manifest.json")
        if os.path.exists(p):
            v = CP.classify_capture_pins(json.load(open(p)))
            out["pin_rule_on_captures"][name] = {"ok": v["ok"], "pins": v["pins"], "refusals": v["refusals"][:6]}
        else:
            out["pin_rule_on_captures"][name] = "not on disk"
    # every pin TABLE the classifier gate consults (the classifier port, the block terminal port, the r13 terminal
    # table, the r17 / H19 readings, the report-only lists) against the paths that moved r17 -> r19b
    import zk60_native_rg_terminals as T

    def mm(tag):
        d = {}
        for ln in open(os.path.join(TOK, f"manifest_final_{tag}.sha256")):
            h, p = ln.rstrip("\n").split("  ", 1)
            d[p[len("hashline/"):] if p.startswith("hashline/") else p] = h
        return d
    a, b = mm("r17"), mm("r19b")
    moved = {p for p in set(a) | set(b) if a.get(p) != b.get(p)}
    tables = {"terminals.PORTED_FROM": T.PORTED_FROM, "terminals.ALSO_ACCEPTED": T.ALSO_ACCEPTED,
              "terminals.PINNED_IF_PRESENT": T.PINNED_IF_PRESENT, "classpins.CLASSIFY_PORTED_FROM_V22": CP.CLASSIFY_PORTED_FROM_V22,
              "r13_pins.TOKEN_R16B_DIGESTS": R13.TOKEN_R16B_DIGESTS, "classpins.TOKEN_R17_READINGS": CP.TOKEN_R17_READINGS,
              "classpins.GATE19_PATCH_READINGS": CP.GATE19_PATCH_READINGS,
              "classpins.CLASSIFY_REPORT_ONLY (v19, not consulted since v21)": CP.CLASSIFY_REPORT_ONLY,
              "classpins.CLASSIFY_REPORT_ONLY_V21 (not consulted)": CP.CLASSIFY_REPORT_ONLY_V21}
    out["pin_tables_vs_moved_r17_r19b"] = {k: sorted(set(v) & moved) for k, v in tables.items()}
    sc = R13.self_check()
    out["r13_self_check"] = {"ok": sc["ok"], "problems": sc["problems"][:8], "digests_rehashed": sc["digests_rehashed"]}
    s17 = CP.r17_self_check()
    out["r17_self_check"] = {"ok": s17["ok"], "findings": s17["findings"]}
    if hasattr(CP, "r19b_self_check"):
        s = CP.r19b_self_check()
        out["r19b_self_check"] = {"ok": s["ok"], "findings": s["findings"], "moved_and_pinned": s["moved_and_pinned"],
                                  "walk": s["walk"], "cli_binaries": s["cli_binaries"]}
        # controls: the OLD pins in place of the new
        keep = CP._r19b_tables
        CP._r19b_tables = lambda: {}
        try:
            v = CP.classify_capture_pins(tree_manifest(CP, "r19b"))
            s2 = CP.r19b_self_check()
        finally:
            CP._r19b_tables = keep
        out["control_readings_removed"] = {"pin_rule_ok": v["ok"], "pin_rule_refusals": v["refusals"],
                                           "r19b_self_check_ok": s2["ok"], "r19b_self_check_findings": s2["findings"][:6],
                                           "fires": (not v["ok"]) and (not s2["ok"])}
        old = R13.TOKEN_R19B_DIGESTS[DRV]
        R13.TOKEN_R19B_DIGESTS[DRV] = R13.DERIVE_T16
        try:
            s3 = R13.self_check()
        finally:
            R13.TOKEN_R19B_DIGESTS[DRV] = old
        out["control_r19b_terminal_at_the_old_pin"] = {"r13_self_check_ok": s3["ok"], "problems": s3["problems"][:4],
                                                       "fires": not s3["ok"]}
        # the mirrored E7 rule on the REAL export's declaration, in this process's environment (no stream)
        import stat as _st
        import zk60_native_rg_classtied as TD
        prof = json.load(open(REPO + "/results/zk60_shieldstral_export_20261026/native_low_h24_t128/profile.json"))
        path = TD.shield_checkpoint_path(prof["tied_embeddings"])
        st = os.lstat(path)
        out["e7_on_this_box"] = {"declared": prof["tied_embeddings"].get("checkpoint_file"),
                                 "ZK60_MODELS": os.environ.get("ZK60_MODELS"), "HOME": os.environ.get("HOME"),
                                 "path": path,
                                 "equals_v23_constant": path == "/home/victor/models/shieldstral-1.0-3b/snapshot-003ec7e2/model.safetensors",
                                 "regular_not_symlink": _st.S_ISREG(st.st_mode), "bytes": st.st_size,
                                 "size_is_the_pin": st.st_size == TD.SHIELD_CHECKPOINT_BYTES}
    print(json.dumps(out))
    return 0


# ------------------------------------------------------------------ the READ census (this process)
def man(tag):
    d = {}
    for ln in open(os.path.join(TOK, f"manifest_final_{tag}.sha256")):
        h, p = ln.rstrip("\n").split("  ", 1)
        d[p] = h
    return d


def production_text(path):
    t = open(path).read()
    i = t.find("\n#[cfg(test)]\nmod tests {")
    if i >= 0:
        t = t[:i]
    return [ln for ln in t.splitlines() if ln.strip() and not ln.strip().startswith("//")]


def counts(lines):
    return {k: sum(len(re.findall(r"\b" + re.escape(k) + r"\b", ln)) for ln in lines) for k in TOKENS}


def census():
    r17, r19b = man("r17"), man("r19b")
    moved = sorted(p for p in set(r17) | set(r19b) if r17.get(p) != r19b.get(p))
    c_r1 = json.load(open(REPO + "/results/zk60_gate_tinyllama_20261017/round22/census/C_R1_READ.json"))
    sites = []
    for s in c_r1["sites"]:
        src = s["source"].split(":")[0]
        path = ("zkp-core/" + src[len("zkp-core/"):]) if src.startswith("zkp-core/") else (
            "hashline/src/" + src if src == "private_block.rs" else "hashline/src/private_block/" + src)
        if src == "private_block.rs":
            path = "hashline/src/private_block.rs"
        row = {"site": s["site"], "source": s["source"], "file": path, "listed": path in r19b,
               "unchanged_r17_to_r19b": r17.get(path) == r19b.get(path) and path in r19b}
        if not row["unchanged_r17_to_r19b"] and path in r19b:
            m = re.search(r":(\d+)-(\d+)", s["source"])
            a, b = int(m.group(1)), int(m.group(2))
            la = open(os.path.join(TOK, "frozen-r17", path)).read().splitlines()[a - 1:b]
            lb = open(os.path.join(TOK, "frozen-r19b", path)).read().splitlines()[a - 1:b]
            row["site_lines_equal"] = la == lb
            row["site_lines_sha256"] = hashlib.sha256("\n".join(lb).encode()).hexdigest()
        sites.append(row)
    prod = []
    for p in moved:
        if not p.endswith(".rs") or "_tests" in p or p.endswith("tests.rs"):
            continue
        a = production_text(os.path.join(TOK, "frozen-r17", p)) if p in r17 else []
        b = production_text(os.path.join(TOK, "frozen-r19b", p))
        ca, cb = counts(a), counts(b)
        prod.append({"file": p, "new_in_r18_or_later": p not in r17, "tokens_r17": {k: v for k, v in ca.items() if v},
                     "tokens_r19b": {k: v for k, v in cb.items() if v},
                     "hash_or_transcript_tokens_added": {k: cb[k] - ca[k] for k in TOKENS if cb[k] > ca[k]}})
    # control: one planted BLAKE3 input in a copy of the new batch file's text is seen
    bt = production_text(os.path.join(TOK, "frozen-r19b", "hashline/src/private_block/token_io/classify_batch.rs"))
    planted = bt + ['    let _x = blake3::hash(b"planted");']
    ctl = counts(planted)["blake3"] - counts(bt)["blake3"]
    return {"moved_r17_to_r19b": moved, "c_r1_sites": sites,
            "c_r1_sites_all_unchanged_or_lines_equal": all(s["unchanged_r17_to_r19b"] or s.get("site_lines_equal") for s in sites),
            "changed_production_files": prod,
            "control_planted_blake3_seen": ctl == 1}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--worker")
    ap.add_argument("--v24")
    ap.add_argument("--v23", default=REPO + "/ops/zkp-mvp/gate-tinyllama/frozen_v23/scripts")
    ap.add_argument("--out")
    a = ap.parse_args()
    if a.worker:
        return worker(a.worker)
    rec = {"what": "gate round 24 step 2: the pin and census checks that read the token tree, against frozen-r19b, "
                   "with the new tools (v24) and the old (v23) as the control", "privacy_acceptance": False}
    for tag, d in (("v23", a.v23), ("v24", a.v24)):
        p = subprocess.run([sys.executable, "-B", os.path.abspath(__file__), "--worker", d], capture_output=True, text=True,
                           cwd="/tmp")
        if p.returncode:
            raise SystemExit(f"{tag} worker failed: {p.stderr[-2000:]}")
        rec[tag] = json.loads(p.stdout.strip().splitlines()[-1])
    rec["census"] = census()
    v23, v24 = rec["v23"], rec["v24"]
    rec["verdict"] = {
        "v24_accepts_r17_r18_r19_r19b_trees": all(v24["pin_rule_on_the_trees"][t]["ok"] for t in ("r17", "r18", "r19", "r19b")),
        "v23_refuses_r18_r19_r19b_trees_by_name": all(not v23["pin_rule_on_the_trees"][t]["ok"] for t in ("r18", "r19", "r19b"))
                                                  and v23["pin_rule_on_the_trees"]["r17"]["ok"],
        "v23_refusals_r19b": v23["pin_rule_on_the_trees"]["r19b"]["refusals"],
        "v24_self_checks_ok": v24["r13_self_check"]["ok"] and v24["r17_self_check"]["ok"] and v24["r19b_self_check"]["ok"],
        "v23_r13_self_check_ok_at_r16b": v23["r13_self_check"]["ok"],
        "controls_fire": v24["control_readings_removed"]["fires"] and v24["control_r19b_terminal_at_the_old_pin"]["fires"],
        "census_c_r1_carries": rec["census"]["c_r1_sites_all_unchanged_or_lines_equal"],
        "census_no_hash_token_added": not any(x["hash_or_transcript_tokens_added"] for x in rec["census"]["changed_production_files"]),
        "census_control_fires": rec["census"]["control_planted_blake3_seen"],
        "e7_on_this_box_is_the_v23_path": v24["e7_on_this_box"]["equals_v23_constant"]
                                          and v24["e7_on_this_box"]["size_is_the_pin"],
        # in v23's CONSULTED pin tables, the paths moved r17 -> r19b are exactly the two re-pinned files
        "v23_consulted_tables_moved_exactly_the_two": sorted({p for k, v in v23["pin_tables_vs_moved_r17_r19b"].items()
                                                              if "not consulted" not in k for p in v}) == [PB, DRV],
    }
    rec["ok"] = all(v for k, v in rec["verdict"].items() if isinstance(v, bool))
    with open(a.out, "w") as fh:
        json.dump(rec, fh, indent=1)
    print(json.dumps(rec["verdict"], indent=1))
    print(a.out, sha_file(a.out), "ok" if rec["ok"] else "NOT OK")
    return 0 if rec["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
