"""FR25-17 control (a) for Shieldstral T256, done after the fact: the seven NL-1 slots of the
closing-run record against the merged 18-part gate record of the same bundle, with the tool's
own compare_seven (and its self-test: one reference S1 row's L + 1 must show up)."""
import copy, hashlib, json, os, sys
sys.dont_write_bytecode = True
REPO = "/Users/victorrielly/IntelligenceRegulation"
sys.path.insert(0, os.path.join(REPO, "results/zk60_d60_20261102/privacy_gate_fr25_17"))
import fr25_17_nl1_all23 as F  # noqa: E402

wide_p = os.path.join(REPO, "results/zk60_d60_20261102/privacy_gate_fr25_17/records/fr25_17-shield-t256-s0.json")
ref_p = sys.argv[1]
w = json.load(open(wide_p))
mr = json.load(open(ref_p))
nl = mr.get(F.NLX.PART)
fork = w["fork"]
print("wide bundle", w["bundle"], "ref bundle_dir", os.path.basename(os.path.normpath(mr.get("bundle_dir", ""))))
assert nl is not None, "no NL-1 part in the merged record"
assert os.path.basename(os.path.normpath(mr.get("bundle_dir", ""))) == w["bundle"], "another bundle"
c = F.compare_seven(w["NL-1 all 23 slots"], nl, fork, ref_p)
c["record_sha256"] = hashlib.sha256(open(ref_p, "rb").read()).hexdigest()
c["record_G"] = nl.get("gates", {}).get(str(fork))
c["G_equal"] = c["record_G"] == w["NL-1 all 23 slots"]["gates"][str(fork)]
c["reproduces"] = c["reproduces"] and c["G_equal"]
bad = copy.deepcopy(nl)
row = next(r for r in bad["per_challenge_mode"]["run"]["S1"] if r["name"].startswith(f"fork {fork} "))
row["L"] += 1
st = F.compare_seven(w["NL-1 all 23 slots"], bad, fork, "self-test")
out = {"control_a_record_file": c, "self_test": {"differences": st["differences"],
       "fires": (not st["reproduces"]) and bool(st["differences"])},
       "wide_record_sha256": hashlib.sha256(open(wide_p, "rb").read()).hexdigest()}
print(json.dumps(out, indent=1))
