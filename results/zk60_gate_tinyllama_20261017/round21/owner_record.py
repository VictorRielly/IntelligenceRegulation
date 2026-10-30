#!/usr/bin/env python3
"""[gate round 21] The gate-side RECORD of the input-owner checks on the real Shieldstral classifier runs, made by
READING the existing evidence (brief: "read, don't re-prove"; no checkpoint stream, no verify, no prove).
Nothing private is read: no decommitment, no content file, no activation; only logs, guard records and the
published statements.  NOT a privacy result.

    python3 owner_record.py <out.json>

Records:
  (1) the HATE run (token round 16, binary e94cecf9...): the token lane's `input-owner` in a fresh process;
  (2) the gate's own `input-owner` on its real moderate-sexual re-prove (gate round 19, the named r16b binary);
  (3) the link of each to its published `/3` statement and, for the hate run, to the hate-values capture that
      gate round 20 passed (the same input endpoint root);
  (4) short items at n != 35: what exists (round 19's rung captures, made in-process by the H19-1 hook, keep the
      owner's decommitment in memory only) and what does not (no owner record);
  (5) Astra's 17-id app post, if its category workers have run (their `inowner` logs, read in place).
"""
import glob
import hashlib
import json
import os
import sys

TOK = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017"
EV = "/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017"
ART = "/home/victor/zk60-artifacts/token-io"
CAP_HATE = ART + "/captures/classify-r13-shield-t128-cli-hate-r17-values"
IDENTITY = "29aeba6c04a819cdbafde311f7c9d0c678d85aff22292ae6b9647761158a0bd1"
ASTRA_PUBLIC = "/home/victor/IntelligenceRegulation/results/zk60_astra_20261026/real_app_demo_1"


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as fh:
        for b in iter(lambda: fh.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def events(path):
    out = []
    for line in open(path):
        line = line.strip()
        if line.startswith("{"):
            try:
                out.append(json.loads(line))
            except ValueError:
                pass
    return out


def guard(path):
    g = json.load(open(path))
    return {k: g.get(k) for k in ("label", "ts_end", "exit", "child_rc", "child_wall_seconds", "peak_rss_gib",
                                  "need_gib", "cap_gib", "enforcement")} | {"cmd_head": g.get("cmd", [])[:4]}


def owner_case(name, log, done, gj, statement, rr_row=None, binary=None):
    ev = events(log)
    checked = [e for e in ev if e.get("event") == "content-checked"]
    st = json.load(open(statement))
    rec = {"case": name, "owner_log": log, "owner_log_sha256": sha(log), "done": open(done).read().strip(),
           "guard": guard(gj), "events": ev, "statement": statement, "statement_sha256": sha(statement),
           "statement_identity": st.get("trained_statement_identity"), "statement_policy": st.get("policy"),
           "statement_n": st.get("content_length_n"), "statement_verdict": st.get("verdict"),
           "statement_input_root": st.get("input_token_endpoint_root"), "binary": binary}
    if rr_row is not None:
        rec["token_lane_real_runs_row"] = rr_row
    rec["passed"] = (rec["done"] == "0" and rec["guard"]["exit"] == 0 and len(checked) == 1
                     and checked[0].get("content_total") == st.get("content_length_n")
                     and checked[0].get("range") == [0, st.get("content_length_n")]
                     and checked[0].get("verdict") == st.get("verdict")
                     and rec["statement_identity"] == IDENTITY)
    return rec


def main(out):
    rr = json.load(open(TOK + "/r16/real_runs.json"))
    hate_rows = [r for r in rr["rows"] if r.get("category") == "hate"]
    L = TOK + "/r16/logs"
    hate = owner_case("hate run, token round 16 (moderate-hate, n 35)", L + "/real-owner-hate.log",
                      L + "/real-owner-hate.done", L + "/real-owner-hate.guard.json",
                      ART + "/r16-runs/hate-run/statement/statement.json",
                      rr_row=[r for r in hate_rows if r.get("step") == "owner"],
                      binary={"reported_sha256": rr.get("binary_sha256"),
                              "note": "the token lane's working-copy build at the time (real_runs.json binary_sha256); "
                                      "the path was rebuilt later (now dae5abd7..., the frozen-r16 tree's), so the "
                                      "bytes that ran are named by the token lane's record, not re-hashed here"})
    # the capture gate round 20 passed belongs to this run: the same input root
    run = json.load(open(CAP_HATE + "/run.json"))
    root = run["classify"]["input_root"]
    root_hex = bytes(root).hex() if isinstance(root, list) else str(root)
    hate["capture_input_root"] = root_hex
    hate["capture_is_this_run"] = root_hex == hate["statement_input_root"]
    hate["round20_record"] = EV + "/round20/v23/v23-classify-r13-shield-t128-cli-hate-r17-values.json"
    hate["round20_record_sha256"] = sha(hate["round20_record"])
    hate["passed"] = hate["passed"] and hate["capture_is_this_run"]
    P = EV + "/round19/cap/real"
    sexual = owner_case("the gate's real re-prove, gate round 19 (moderate-sexual, n 35)", P + "/owner.log",
                        P + "/owner.done", P + "/owner.guard.json",
                        P + "/classify-r13-shield-t128-cli-sexual-r16b.statement.json",
                        binary={"sha256_now": sha(TOK + "/cli/zk60_classify.r16b.release.bin"),
                                "named": "dfb8025eb903b203f4b50371fdd0dd00659d46a9dbaad9d121d6a68343ebc70c"})
    sexual["binary"]["equal"] = sexual["binary"]["sha256_now"] == sexual["binary"]["named"]
    sexual["passed"] = sexual["passed"] and sexual["binary"]["equal"]
    # short items at other n: round 19's rung captures
    shorts = sorted(os.path.basename(p) for p in glob.glob(ART + "/captures/classify-r13-rung-L2-*-short*"))
    c13 = json.load(open(EV + "/round19/C13_PER_N.json"))
    short = {"captures": shorts,
             "owner_check_possible": False,
             "why": "made in-process by the gate's H19-1 hook (round19/cap/H19-1-2.gate19_capture_tests.patch: "
                    "`seal_input` then `prove_classify_run` return the owner's Decommitment `dec` to the test, which "
                    "only checks that the bundle holds none of its salts / pad words and then drops it); no input.dec "
                    "and no run directory exist for them, so no input-owner check can be run or recorded",
             "what_the_gate_checked_instead": "C-13 per n (round19/C13_PER_N.json): the input endpoint's known words "
                                              "(template + pads) and the public pad layout, C13-1..C13-4 firing at "
                                              "pad id 2, the verdict row; a statement about the PUBLIC side only",
             "c13_per_n_sha256": sha(EV + "/round19/C13_PER_N.json"),
             "c13_keys": sorted(c13.keys())[:20]}
    # Astra's app post (n 17): read its workers' inowner logs in place, if any
    astra = {"plan": ASTRA_PUBLIC + "/plan.json", "found": []}
    for log in sorted(glob.glob("/tmp/zk60-astra-real-app-demo-20261029-1/**/logs/inowner.log", recursive=True)):
        job = os.path.dirname(os.path.dirname(log))
        rec = {"inowner_log": log, "events": events(log)}
        for f in ("inowner.exit", "inowner.guard.json"):
            p = os.path.join(job, "logs", f)
            if os.path.exists(p):
                rec[f] = open(p).read().strip() if f.endswith(".exit") else guard(p)
        astra["found"].append(rec)
    astra["state"] = "recorded" if astra["found"] else "not run yet (no inowner log): owed"
    rec = {"what": "gate round 21: the gate-side record of the input-owner checks, by reading [READ]; NOT a privacy "
                   "result", "privacy_acceptance": False, "cases": [hate, sexual], "short_items_round19": short,
           "astra_app_post_n17": astra,
           "summary": {"hate_run_owner_check_passed": hate["passed"], "gate_r19_owner_check_passed": sexual["passed"],
                       "short_items_other_n_owner_record": ("Astra n=17: " + astra["state"]) if not astra["found"]
                       else "Astra n=17: see astra_app_post_n17",
                       "owner_checks_at_n_35_only_so_far": not astra["found"]}}
    with open(out, "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True)
        fh.write("\n")
    print(json.dumps(rec["summary"]))


if __name__ == "__main__":
    main(sys.argv[1])
