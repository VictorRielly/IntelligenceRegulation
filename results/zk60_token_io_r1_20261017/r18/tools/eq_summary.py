"""Token round 18: the step E numbers from the logs and guard JSONs (read only). usage: eq_summary.py OUT.json"""
import json, os, sys

LE = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r18/logs/eq"


def events(name):
    out = []
    p = os.path.join(LE, name + ".log")
    if not os.path.exists(p):
        return out
    for line in open(p):
        line = line.strip()
        if line.startswith('{"event"'):
            try:
                out.append(json.loads(line))
            except ValueError:
                pass
    return out


def guard(name):
    p = os.path.join(LE, name + ".guard.json")
    if not os.path.exists(p):
        return None
    g = json.load(open(p))
    return {k: g.get(k) for k in ("exit", "child_rc", "child_wall_seconds", "peak_rss_gib", "peak_cgroup_gib", "min_mem_available_gib", "enforcement", "guard_killed", "hard_killed", "refused", "note", "ts_end")}


def proof(e):
    return {k: e.get(k) for k in ("policy", "chunk", "verdict", "segments", "receipt_bytes", "prove_seconds", "total_seconds", "whole_run_floor_bits")}


def main():
    s = {"label": "[MEASURED, n=1, shared box]"}
    b = events("batch")
    s["batch"] = {
        "guard": guard("batch"),
        "loaded": next(({k: e.get(k) for k in ("jobs", "model_loads", "table_loads", "load_seconds")} for e in b if e.get("event") == "batch-loaded"), None),
        "jobs": [proof(e) for e in b if e.get("event") == "proved"],
        "job_reloads": [{k: e.get(k) for k in ("index", "seal_block_loads", "prove_block_loads", "blocks")} for e in b if e.get("event") == "batch-job-proved"],
        "proved": next(({k: e.get(k) for k in ("jobs", "total_seconds", "verified")} for e in b if e.get("event") == "batch-proved"), None),
        "fixed_entropy": next((e for e in b if e.get("event") == "fixed-entropy"), None),
    }
    for n in ("single-c0", "single-c1", "single-c2", "r16b-c0"):
        e = events(n)
        s[n] = {"guard": guard(n), "proved": next((proof(x) for x in e if x.get("event") == "proved"), None), "fixed_entropy": next((x for x in e if x.get("event") == "fixed-entropy"), None)}
    s["activations"] = guard("act")
    s["compare"] = guard("compare")
    fr = os.path.join(LE, "fresh_cmds.json")
    if os.path.exists(fr):
        s["fresh_checks"] = {n: guard(n) for n, _ in json.load(open(fr))}
    s["fail_control"] = guard("fail")
    singles = [s[n]["guard"]["child_wall_seconds"] for n in ("single-c0", "single-c1", "single-c2") if s[n]["guard"]]
    if s["batch"]["guard"] and len(singles) == 3:
        s["wall_batch_vs_three_singles"] = {"batch_s": s["batch"]["guard"]["child_wall_seconds"], "three_singles_s": sum(singles),
                                            "saved_s": sum(singles) - s["batch"]["guard"]["child_wall_seconds"]}
    json.dump(s, open(sys.argv[1], "w"), indent=1)
    print(json.dumps(s, indent=1))


if __name__ == "__main__":
    main()
