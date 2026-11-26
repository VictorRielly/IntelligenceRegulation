#!/usr/bin/env python3
"""Batch 8: per-pass numbers of one guarded serve1 leaf: log (sealing pass, request, user/sys), GPU trace (the
Batch 7 phase decomposition P1..P9 by calling run_batch7_guarded's own functions, and the commit-to-GPUStart
gaps), and the polled task counters (page faults, user and system CPU) over each pass's sealing chain.

usage: analyze_runs.py <label> [<label> ...]   -> writes <label>.pass.json
The Batch 7 module is imported, not edited (bytecode writing off)."""
from __future__ import annotations

import bisect
import gzip
import importlib.util
import json
import re
import statistics as st
import sys
from pathlib import Path

sys.dont_write_bytecode = True
OUT = Path(__file__).resolve().parent
ART = Path("/Users/victorrielly/zk60-artifacts/batch8_traces_20261117")
B7 = Path("/Users/victorrielly/IntelligenceRegulation/results/zk60_batch7_sealing_lanes3_20261117/run_batch7_guarded.py")
spec = importlib.util.spec_from_file_location("b7", B7)
b7 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b7)

REQ = re.compile(
    r"A22-AB REQ \S+ L32 N6 \[serve1\] pass (\d+) request 0: arrived ([0-9.]+), sealing turn ([0-9.]+), sealing side done ([0-9.]+) \(sealing pass ([0-9.]+) s\), "
    r"prover ([0-9.]+)-([0-9.]+) \(waited ([0-9.]+) s; prove call ([0-9.]+) s: preflight ([0-9.]+), commit ([0-9.]+), forks ([0-9.]+), join ([0-9.]+)\), "
    r"receipt write ([0-9.]+) s \([^)]+\), result ([0-9.]+);"
)
STREAM = re.compile(r"A22-AB STREAM \S+ L32 N6 \[serve1\] pass (\d+): 1 requests in ([0-9.]+) s .*footprint start ([0-9.]+) GiB, peak ([0-9.]+) GiB, end ([0-9.]+) GiB; user ([0-9.]+) s \+ sys ([0-9.]+) s")


def load_trace(gz: Path) -> list[dict]:
    rows = []
    with gzip.open(gz, "rt") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line or line.startswith("tag\t"):
                continue
            p = line.split("\t")
            if len(p) != 9:
                continue
            tag, detail, th, q, b, c, gs, ge, done = p
            kv = dict(t.split("=", 1) for t in detail.split() if "=" in t)
            gs_f, ge_f, b_f, c_f, d_f = float(gs), float(ge), float(b), float(c), float(done)
            rows.append({
                "tag": tag, "detail": detail, "slot_label": detail.split(" | ", 1)[0] if " | " in detail else None, "kv": kv,
                "thread": int(th), "queue": int(q), "begin": b_f, "committed": c_f, "gs": gs_f, "ge": ge_f, "done": d_f,
                "gpu_dur": max(0.0, ge_f - gs_f) if (gs_f > 0 and ge_f >= gs_f) else 0.0,
                "queue_wait": max(0.0, gs_f - c_f) if (gs_f > 0 and c_f > 0) else 0.0,
                "encode_dur": max(0.0, c_f - b_f) if (c_f > 0 and b_f > 0) else 0.0,
                "wakeup_dur": max(0.0, d_f - ge_f) if (ge_f > 0 and d_f >= ge_f) else 0.0,
                "paired_rows": int(kv["rows"]) if "rows" in kv and kv["rows"].isdigit() else None,
            })
    return rows


class Series:
    def __init__(self, path: Path):
        self.t, self.f, self.u, self.s = [], [], [], []
        with gzip.open(path, "rt") as fh:
            next(fh)
            prev_f = None
            wrap = 0
            for line in fh:
                p = line.split("\t")
                ff = int(p[1])
                if prev_f is not None and ff < prev_f - 2**31:
                    wrap += 2**32
                prev_f = ff
                self.t.append(float(p[0])); self.f.append(ff + wrap); self.u.append(float(p[4])); self.s.append(float(p[5]))

    def at(self, arr, t):
        i = bisect.bisect_left(self.t, t)
        if i <= 0:
            return arr[0]
        if i >= len(self.t):
            return arr[-1]
        t0, t1 = self.t[i - 1], self.t[i]
        w = (t - t0) / (t1 - t0) if t1 > t0 else 0.0
        return arr[i - 1] + w * (arr[i] - arr[i - 1])

    def delta(self, a, b):
        return (self.at(self.f, b) - self.at(self.f, a), self.at(self.u, b) - self.at(self.u, a), self.at(self.s, b) - self.at(self.s, a))


def analyze(label: str) -> dict:
    meta = json.loads((OUT / f"{label}.meta.json").read_text())
    text = (OUT / f"{label}.log").read_text()
    reqs = {}
    for m in REQ.finditer(text):
        g = m.groups()
        reqs[int(g[0])] = dict(arrived=float(g[1]), seal_turn=float(g[2]), seal_done=float(g[3]), seal_s=float(g[4]), prover_start=float(g[5]), prover_end=float(g[6]),
                              waited=float(g[7]), prove_call=float(g[8]), commit=float(g[10]), forks=float(g[11]), receipt_write=float(g[13]), result=float(g[14]))
    streams = {}
    for m in STREAM.finditer(text):
        g = m.groups()
        streams[int(g[0])] = dict(wall=float(g[1]), fp_start=float(g[2]), fp_peak=float(g[3]), fp_end=float(g[4]), user=float(g[5]), sys=float(g[6]))
    rows = load_trace(ART / f"{label}.trace.tsv.gz")
    a_rows, h_rows = b7.detect_ah_rows(rows)
    passes = b7.split_stream_trace_into_passes(rows, [1] + [1] * 6, h_rows)
    ser = Series(OUT / f"{label}.counters.tsv.gz")
    # line times for the request windows
    lt = {}
    for ln in (OUT / f"{label}.linetimes.tsv").read_text().splitlines():
        t, _, txt = ln.partition("\t")
        mm = re.search(r"\[serve1\] pass (\d+)( request 0| (?=:))", txt)
        if txt.startswith("A22-AB REQ") and "[serve1] pass" in txt:
            k = int(re.search(r"pass (\d+)", txt).group(1)); lt.setdefault(k, {})["req"] = float(t)
        if txt.startswith("A22-AB STREAM"):
            k = int(re.search(r"pass (\d+)", txt).group(1)); lt.setdefault(k, {})["stream"] = float(t)
    per = []
    for p in range(6):
        trows = passes[1 + p]
        wprods = sorted([r for r in trows if r["tag"] == "wprod"], key=lambda r: r["begin"])
        non_wp = [r for r in trows if r["tag"] != "wprod"]
        r = reqs[p]
        dec = b7.decompose_one_request_sealing({"seal_s": r["seal_s"], "seal_done": r["seal_done"], "seal_turn": r["seal_turn"]}, wprods, non_wp)
        # commit-to-GPUStart, per buffer, as recompute_wait.py: gs - committed
        waits = [max(0.0, w["gs"] - w["committed"]) for w in wprods]
        by_kind = {}
        for i, w in enumerate(wprods):
            by_kind.setdefault(i % 7, []).append(waits[i])
        chain_b = min(w["begin"] for w in wprods)
        chain_e = max(w["done"] for w in wprods)
        # sealing window = chain span, widened by half of the bookend residual on each side
        res = max(0.0, r["seal_s"] - (chain_e - chain_b))
        w0, w1 = chain_b - res / 2, chain_e + res / 2
        df, du, ds = ser.delta(w0, w1)
        # whole request window: previous STREAM line (request start) to this REQ line (request end)
        prev_stream = lt.get(p - 1, {}).get("stream") if p > 0 else None
        req_end = lt.get(p, {}).get("req")
        whole = ser.delta(prev_stream, req_end) if (prev_stream and req_end) else None
        st_ = streams[p]
        per.append({
            "pass": p,
            "seal_pass_s": r["seal_s"], "request_s": r["result"], "prove_call_s": r["prove_call"],
            "log_request_user_s": st_["user"], "log_request_sys_s": st_["sys"],
            "peak_footprint_gib": st_["fp_peak"],
            "chain_span_s": chain_e - chain_b, "bookend_residual_s": res,
            "sum_commit_to_start_224_s": sum(waits),
            "crit_commit_to_start_union_s": dec["wprod_crit_gpu_queue_wait_s"],
            "median_commit_to_start_ms_by_product_QKVWoWgWuWd": [1000 * st.median(by_kind[k]) for k in range(7)],
            "median_commit_to_start_ms_all": 1000 * st.median(waits),
            "gpu_busy_union_s": dec["wprod_gpu_busy_union_s"],
            "gpu_sum_spans_s": dec["wprod_gpu_summed_spans_s"],
            "p1_qkv_wall_s": dec["p1_qkv_wprod_wall_s"], "p2_s": dec["p2_attn_scores_softmax_pv_host_s"], "p3_wo_wall_s": dec["p3_wo_wprod_wall_s"],
            "p4_s": dec["p4_ao_res1_normm_host_s"], "p5_gu_wall_s": dec["p5_gu_wprod_wall_s"], "p6_s": dec["p6_swiglu_host_s"], "p7_wd_wall_s": dec["p7_wd_wprod_wall_s"],
            "p8_interblock_31_s": dec["p8_interblock_31_assign_cs3_norma_host_s"], "p8_bookends_s": dec["p8_bookends_blk0_norma_blk31_assign_stmt_host_s"],
            "p8_total_s": dec["p8_total_assign_cs3_norma_host_s"], "p9_s": dec["p9_endpoints_commit_and_door_host_s"],
            "wprod_host_inside_s": dec["wprod_host_encode_wakeup_overlapped_rope_s"],
            "chain_window_mono": [w0, w1],
            "chain_faults": df, "chain_user_s": du, "chain_sys_s": ds,
            "request_faults_prev_stream_to_req_line": whole[0] if whole else None,
            "request_user_s_polled": whole[1] if whole else None,
            "request_sys_s_polled": whole[2] if whole else None,
        })
    return {"label": label, "meta": {k: meta[k] for k in ("view", "sampled", "launch_utc", "guard_run_id", "guard_waited_s", "child_wall_seconds", "peak_rss_gib", "peak_vram_mib", "ds4_bench_pre", "ds4_bench_post", "trace")}, "passes": per}


if __name__ == "__main__":
    for lab in sys.argv[1:]:
        d = analyze(lab)
        (OUT / f"{lab}.pass.json").write_text(json.dumps(d, indent=1) + "\n")
        ps = d["passes"]
        med = lambda k: st.median([p[k] for p in ps])
        print(lab, "seal", [p["seal_pass_s"] for p in ps], "median", med("seal_pass_s"), "req", med("request_s"))
        print("  crit c2s", med("crit_commit_to_start_union_s"), "sum", med("sum_commit_to_start_224_s"), "p8", med("p8_total_s"), "gpu busy", med("gpu_busy_union_s"))
        print("  chain faults", [round(p["chain_faults"]) for p in ps], "sys", [round(p["chain_sys_s"], 3) for p in ps], "user", [round(p["chain_user_s"], 2) for p in ps])
        print("  request faults", [round(p["request_faults_prev_stream_to_req_line"] or 0) for p in ps], "sys polled", [round(p["request_sys_s_polled"] or 0, 2) for p in ps], "log sys", [p["log_request_sys_s"] for p in ps])
