"""D24 review R14: audit the author's acceptance JSONs against their own logs.

Reads ONLY small JSON and log files (no frames, no arrays, no model data).
Every count printed here is recomputed from log text; the JSON is the claim.
"""
import glob
import hashlib
import json
import os
import re
import sys

R14 = "/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r14"
PACKET = R14 + "/review-author-1"
TEST_BIN = "29a8be1d08ad537b88db6261663e7af6f34adf004d9e7691e4fb71ff6cc28a1d"
CLI_BIN = "6625a7f224a44a523a477811d18feadc8b7654f9c9008b3372cf73eeda054896"
LEGACY_CLI = "260b66ebdc8887b49e75c8ae992e6489b788851f5ec5de840132c9d8f49f04ba"
SOURCE = "27b2a427491912cd54969b66f1d6ace29740ba8923dce6ba5ac4e23cfd992191"


def sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def text(path):
    return open(path, encoding="utf-8", errors="replace").read()


def receipts(log):
    return [json.loads(m) for m in re.findall(r"R14_MALICIOUS_RECEIPT (\{.*?\})\n", log)]


def one_test_ok(log):
    return bool(re.search(r"test result: ok\. 1 passed; 0 failed", log))


out = {}

# ---------------------------------------------------------------- packet
fz = json.load(open(PACKET + "/AUTHOR_FREEZE.json"))
out["packet_binaries"] = {k: (sha(f"{PACKET}/bin/{k}") == v) for k, v in fz["binaries"].items()}
out["packet_tools"] = {k: (sha(f"{PACKET}/tools/{k}") == v) for k, v in fz["helpers"].items()
                       if os.path.exists(f"{PACKET}/tools/{k}")}

# ---------------------------------------------------------------- relations battery
acc = json.load(open(R14 + "/final-relations-1/ACCEPTANCE.json"))
rel = {"cases_in_json": len(acc["cases"]), "rejected_by_log": 0, "problems": []}
for c in acc["cases"]:
    stem = ("dd-" if c["dd"] else "non-dd-") + c["case"]
    log = text(f"{R14}/final-relations-1/{stem}.log")
    cmd = json.load(open(f"{R14}/final-relations-1/{stem}.command.json"))
    g = json.load(open(f"{R14}/final-relations-1/{stem}.guard.json"))
    r = receipts(log)
    refusal = re.search(r"R14_ATTACK_REFUSAL " + re.escape(c["case"]) + r": (.*)\n", log)
    good = (one_test_ok(log) and len(r) == 1 and r[0]["expected_accept"] is False and r[0]["dd"] == c["dd"]
            and refusal is not None and "R14 wire" not in refusal.group(1) and "R14 run" not in refusal.group(1)
            and cmd["binary_sha256"] == TEST_BIN and cmd["source"] == SOURCE and g["exit"] == 0
            and r[0]["bytes"] == c["receipt"]["bytes"])
    if good:
        rel["rejected_by_log"] += 1
    else:
        rel["problems"].append(stem)
    c["_refusal"] = refusal.group(1) if refusal else None
rel["refusal_sites"] = sorted({re.sub(r"column \d+", "column N", c["_refusal"] or "") for c in acc["cases"]})
alias = acc["positive_equivalent_dictionary_rows"]
log = text(f"{R14}/final-relations-1/dd-dictionary-alias-counts.log")
r = receipts(log)
tup = re.search(r"R14_DICTIONARY_COUNT_TUPLES (.*)\n", log).group(1)
rel["alias"] = {"accepted_by_log": one_test_ok(log) and len(r) == 1 and r[0]["expected_accept"] is True
                and "R14_ATTACK_REFUSAL" not in log, "tuples": tup,
                "statement_txt": text(f"{R14}/final-relations-1/receipts/dd-dictionary-alias-counts/statement.txt")}
neg = text(f"{R14}/final-relations-1/dd-dictionary-counts.log")
rel["dictionary_negative"] = {"tuples": re.search(r"R14_DICTIONARY_COUNT_TUPLES (.*)\n", neg).group(1),
                              "refusal": re.search(r"R14_ATTACK_REFUSAL dictionary-counts: (.*)\n", neg).group(1)}
out["relations"] = rel

# ---------------------------------------------------------------- arithmetic / C3
logs = {}
for p in glob.glob(R14 + "/final-arithmetic-[12]/*.log"):
    logs[sha(p)] = p
ar = json.load(open(R14 + "/final-arithmetic-2/ACCEPTANCE.json"))
arith = {"malformed_rejected": 0, "honest_group_contexts": 0, "dense_ok": 0, "problems": [], "sites": {}}
for rec in ar["records"]:
    p = logs.get(rec["log_sha256"])
    if p is None:
        arith["problems"].append(rec["name"] + ": log not found by hash")
        continue
    log = text(p)
    if rec["guard"]["exit"] != 0:
        arith["problems"].append(rec["name"] + ": guard exit")
    if TEST_BIN not in json.dumps(rec["guard"]["cmd"]) and "final-build-1/hashline.test.bin" not in json.dumps(rec["guard"]["cmd"]):
        arith["problems"].append(rec["name"] + ": binary path")
    for r in receipts(log):
        if r["expected_accept"]:
            arith["honest_group_contexts"] += 1
        else:
            m = re.search(r"R14_ATTACK_REFUSAL " + re.escape(r["case"]) + r": (.*)\n", log)
            if m and one_test_ok(log):
                arith["malformed_rejected"] += 1
                arith["sites"][("dd-" if r["dd"] else "non-dd-") + r["case"]] = m.group(1)
            else:
                arith["problems"].append(rec["name"])
    if rec["name"].startswith("dense-") and rec["name"] != "dense-reference" and one_test_ok(log):
        arith["dense_ok"] += 1
out["arithmetic"] = arith

# ---------------------------------------------------------------- joint receipts / envelopes
jr = json.load(open(R14 + "/joint-receipts-2/ACCEPTANCE.json"))
jl = {}
for p in glob.glob(R14 + "/joint-receipts-[12]/*.log"):
    jl[sha(p)] = p
joint = {"honest_accept": 0, "merkle_reject": 0, "sumcheck_reject": 0, "other": []}
for c in jr["cases"]:
    p = jl.get(c["log_sha256"])
    log = text(p) if p else ""
    if c["category"] == "positive":
        joint["honest_accept"] += int(one_test_ok(log))
    elif "Merkle path for column" in log and "FAILED" in log:
        joint["merkle_reject"] += 1
    elif re.search(r"sumcheck round \d", log) and "FAILED" in log:
        joint["sumcheck_reject"] += 1
    else:
        joint["other"].append(c["case"])
out["joint_receipts"] = joint
je = json.load(open(R14 + "/joint-envelopes-1/ACCEPTANCE.json"))
env = {"honest_accept": 0, "refused": 0, "refusals": {}}
for c in je["cases"]:
    log = text(f"{R14}/joint-envelopes-1/{c['case']}.log")
    if c["case"].endswith("honest"):
        env["honest_accept"] += int(one_test_ok(log))
    else:
        m = re.search(r"Err` value: \"(.*?)\"", log)
        if "FAILED" in log and m:
            env["refused"] += 1
            env["refusals"][c["case"]] = m.group(1)
out["joint_envelopes"] = env

# ---------------------------------------------------------------- full 26 layers
f26 = {}
for mode in ("non-dd", "dd"):
    prove = text(f"{R14}/full26-native-1/{mode}-prove.log")
    ev = [json.loads(l) for l in prove.splitlines() if l.startswith("{")]
    segs = [e for e in ev if e["event"] == "segment"]
    proven = [e for e in ev if e["event"] == "proven"][0]
    sealed = [e for e in ev if e["event"] == "sealed"][0]
    fresh = text(f"{R14}/full26-native-1/{mode}-fresh.log")
    fg = json.load(open(f"{R14}/full26-native-1/{mode}-fresh.guard.json"))
    cg = json.load(open(f"{R14}/full26-native-1/{mode}-scalar-corrupt.guard.json"))
    pc = json.load(open(f"{R14}/full26-native-1/{mode}-prove.command.json"))
    f26[mode] = {
        "segments": len(segs), "bytes_sum": sum(s["bytes"] for s in segs),
        "prove_seconds": proven["prove_seconds"], "total_seconds": proven["total_seconds"],
        "seal_seconds": sealed["seconds"], "parity": sealed["parity"], "kept_witness_bytes": sealed["kept_witness_bytes"],
        "vmhwm_mib": proven["vmhwm_mib"], "identity": proven["statement_identity"], "binding": proven["binding"],
        "fresh_verified": '"event":"verified"' in fresh and '"statement_promoted":true' in fresh,
        "fresh_identity_matches": proven["statement_identity"] in fresh and proven["binding"] in fresh,
        "fresh_wall_seconds": round(fg["child_wall_seconds"], 2), "fresh_peak_rss_gib": fg["peak_rss_gib"],
        "corrupt": text(f"{R14}/full26-native-1/{mode}-scalar-corrupt.log").strip(), "corrupt_exit": cg["exit"],
        "prove_binary": pc.get("binary_sha256") == CLI_BIN,
    }
na = json.load(open(R14 + "/full26-native-1/ACCEPTANCE.json"))
for m in na["modes"]:
    key = "dd" if m["dd"] else "non-dd"
    f26[key]["acceptance_bytes"] = m["bytes"]
    f26[key]["acceptance_bytes_match_log"] = m["bytes"] == f26[key]["bytes_sum"]
out["full26"] = f26

# ---------------------------------------------------------------- suites
def suite(path):
    t = text(path)
    res = re.findall(r"test result: (\w+)\. (\d+) passed; (\d+) failed; (\d+) ignored", t)
    return {"targets": len(res), "passed": sum(int(r[1]) for r in res), "failed": sum(int(r[2]) for r in res),
            "ignored": sum(int(r[3]) for r in res), "all_ok": all(r[0] == "ok" for r in res)}
out["suite_legacy_compat_source_86301542"] = suite(R14 + "/sol-r14-legacy-full-suite-3.log")
out["suite_final_source_27b2a427"] = suite(R14 + "/final-validation-1/suite.log")
lc = json.load(open(R14 + "/LEGACY_COMPATIBILITY_ACCEPTANCE.json"))
out["legacy_acceptance_source"] = lc["source"]
fv = json.load(open(R14 + "/final-validation-1/ACCEPTANCE.json"))
out["final_validation_binaries"] = {"test": fv["test_binary_sha256"] == TEST_BIN, "cli": fv["cli_sha256"] == CLI_BIN,
                                    "legacy_cli": fv["legacy_cli_sha256"] == LEGACY_CLI}
gold = text(R14 + "/final-validation-1/goldens.log")
out["goldens"] = sorted(re.findall(r"R12-GOLDEN-DIGEST (\S+) ([0-9a-f]{64})", gold)) + \
    sorted(re.findall(r"R12-GOLDEN-IDENTITY (\S+) ([0-9a-f]{64})", gold))

json.dump(out, open(sys.argv[1], "w"), indent=1, default=str)
print(json.dumps({k: v for k, v in out.items() if k not in ("goldens",)}, indent=1, default=str)[:12000])
