"""Summarize the logup-gkr-20261101 benchmark logs into results.json (medians, n per cell).

Reads logs/bench_*.log and logs/test3.log written by the guarded runs; writes
results.json next to this file. Pure parsing; no measurement happens here.
"""
import hashlib
import json
import pathlib
import re
import statistics

HERE = pathlib.Path(__file__).resolve().parent
LOGS = HERE / "logs"
RUNS = {
    "t32": "bench_t32.log",
    "t1": "bench_t1.log",
    "t8": "bench_t8.log",
    "t16": "bench_t16.log",
    "t16_n25": "bench_t16_n25.log",
    "t32_parmin_2^10": "bench_pm10.log",
    "t32_parmin_2^12": "bench_pm12.log",
    "t32_parmin_2^15": "bench_pm15.log",
}


def parse(path):
    gkr, hlp, wit = {}, {}, {}
    for line in path.read_text().splitlines():
        if line.startswith("WITNESS "):
            d = json.loads(line[len("WITNESS "):])
            wit[d["log_leaves"]] = d
        m = re.match(r"RESULT (gkr|helper) (.*)", line)
        if m:
            d = json.loads(m.group(2))
            (gkr if m.group(1) == "gkr" else hlp).setdefault(d["log_leaves"], []).append(d)
    return gkr, hlp, wit


def med(rows, key):
    return statistics.median(r[key] for r in rows)


def main():
    out = {"host": "M3 Ultra Mac Studio, 24P+8E cores, shared with Astra's detached replay (heavy lock held by us during each run)",
           "label": "MEASURED, diagnostic timing on a shared host; medians over n reps (rep 0 included)", "runs": {}}
    for name, fn in RUNS.items():
        p = LOGS / fn
        if not p.exists():
            continue
        gkr, hlp, wit = parse(p)
        run = {"log": f"logs/{fn}", "sha256": hashlib.sha256(p.read_bytes()).hexdigest(), "sizes": {}}
        for n in sorted(set(gkr) | set(hlp)):
            cell = {"witness": wit.get(n)}
            if n in gkr:
                g = gkr[n]
                cell["gkr"] = {
                    "n_reps": len(g),
                    "threads": g[0]["threads"],
                    "prove_s_median": med(g, "prove_s"),
                    "prove_s_min": min(r["prove_s"] for r in g),
                    "prove_s_max": max(r["prove_s"] for r in g),
                    "build_s_median": med(g, "build_s"),
                    "topdown_s_median": med(g, "topdown_s"),
                    "ns_per_leaf_median": med(g, "ns_per_leaf"),
                    "ns_per_query_median": med(g, "ns_per_query"),
                    "verify_rounds_s_median": med(g, "verify_rounds_s"),
                    "verify_oracle_s_median": med(g, "verify_oracle_s"),
                    "peak_heap_b_per_leaf": g[0]["peak_heap_b_per_leaf"],
                    "proof_bytes": g[0]["proof_bytes"],
                    "rounds": g[0]["rounds"],
                    "parallel_rounds": g[0]["parallel_rounds"],
                    "fp2_equiv_mul_per_leaf_COUNTED": g[0]["fp2_equiv_per_leaf"],
                    "build_fp2_equiv_per_leaf_COUNTED": g[0]["build_fp2_equiv_per_leaf"],
                    "top_fp2_equiv_per_leaf_COUNTED": g[0]["top_fp2_equiv_per_leaf"],
                    "bytes_rd_per_leaf_COUNTED": g[0]["bytes_rd_per_leaf"],
                    "bytes_wr_per_leaf_COUNTED": g[0]["bytes_wr_per_leaf"],
                    "direct_check_rep0": g[0]["direct"],
                    "last_layers_rep0_k_secs_parallel_rounds": g[0]["last_layers_k_secs_parrounds"],
                }
            if n in hlp:
                h = hlp[n]
                cell["helper"] = {
                    "n_reps": len(h),
                    "threads": h[0]["threads"],
                    "inverse_tables_s_median": med(h, "inverse_tables_s"),
                    "gather_write_s_median": med(h, "gather_write_s"),
                    "batchinv_write_s_median": med(h, "batchinv_write_s"),
                    "commit_s_median": med(h, "commit_s"),
                    "ns_per_word_gather_median": med(h, "ns_per_leaf_gather"),
                    "ns_per_word_batchinv_median": med(h, "ns_per_leaf_batchinv"),
                    "ns_per_word_commit_median": med(h, "ns_per_leaf_commit"),
                    "gather_equals_batchinv": all(r["gather_equals_batchinv"] for r in h),
                    "peak_heap_commit_bytes": h[0]["peak_heap_commit_bytes"],
                }
            run["sizes"][str(n)] = cell
        out["runs"][name] = run
    t = LOGS / "test3.log"
    if t.exists():
        txt = t.read_text()
        m = re.search(r"TESTS pass=(\d+) fail=(\d+)", txt)
        out["tests"] = {"log": "logs/test3.log", "pass": int(m.group(1)), "fail": int(m.group(2)),
                        "controls": [l for l in txt.splitlines() if re.search(r"/C\d", l)]}
    (HERE / "results.json").write_text(json.dumps(out, indent=1) + "\n")
    for name, run in out["runs"].items():
        for n, c in run["sizes"].items():
            g, h = c.get("gkr"), c.get("helper")
            s = f"{name:18s} 2^{n}: "
            if g:
                s += f"GKR {g['prove_s_median']:.4f}s ({g['ns_per_leaf_median']:.2f} ns/leaf, n={g['n_reps']}) "
            if h:
                s += f"| gather {h['gather_write_s_median']:.4f}s batchinv {h['batchinv_write_s_median']:.4f}s commit {h['commit_s_median']:.4f}s ({h['ns_per_word_commit_median']:.2f} ns/word)"
            print(s)


if __name__ == "__main__":
    main()
