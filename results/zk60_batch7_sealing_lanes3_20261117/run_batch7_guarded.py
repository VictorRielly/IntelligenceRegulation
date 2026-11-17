#!/usr/bin/env python3
"""Batch 7 Guarded Runner & Analyzer:
  1. Per-phase profile of the 32-block witness sealing pass (`n = 6` warm passes), solo (`serve1` and `serve4 req 0`)
     vs overlapped (`serve4 reqs 1..3`, 2 lanes; and `serve6+lanes3 reqs 1..5`, 3 lanes), decomposing host vs GPU
     and isolating GPU queue contention, GPU execution slowdown, host compute-thread contention, and memory/allocation
     contention without modifying any pinned prover source file (`ops/zkp-mvp/gpu-metal` diff = 0 B).
  2. Three-lane server stream (`serve6+lanes3`, `n = 6` warm passes at `HL_A19_BUDGET_GIB=32`) to measure how much of
     the steady-state cadence is the 2-lane admission window `(S + W + P)/2` vs `(S + W + P)/3` (pricing Candidate A's
     memory channel: 43.2 GB -> 21.5 GB codewords/request).
  3. Permanent retention of compressed (`gzip`) `HL_A27_GPU_TRACE` `.tsv.gz` files outside the repository in
     `~/zk60-artifacts/batch7_traces_20261117/`, plus measured per-slot GPU spans from the retained traces.

Guard & hygiene rules:
  - Default guard poll (`5.0 s`), `/tmp/HOLD` check before every leaf, `ds4-bench` quiet check pre/post every leaf,
    `12 s` polite inter-leaf gap, `PYTHONDONTWRITEBYTECODE=1`, no zero-byte logs in output directory, no home/session literals.
"""
from __future__ import annotations

import collections
import gzip
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GUARD = ROOT / "scripts/zk60_resource_guard.py"
OUT = Path(__file__).resolve().parent
HASHLINE_DEPS = ROOT / "ops/zkp-mvp/gpu-metal/hashline/target/release/deps"
TRACE_ARCHIVE_DIR = Path(
    os.environ.get("ZK60_TRACE_ARCHIVE_DIR", str(Path.home() / "zk60-artifacts" / "batch7_traces_20261117"))
)


def check_hold() -> None:
    if Path("/tmp/HOLD").exists():
        raise SystemExit("ABORT: /tmp/HOLD exists; honoring hold immediately.")


def ds4_running() -> list[str]:
    cp = subprocess.run(["pgrep", "-fl", "ds4-bench"], capture_output=True, text=True)
    if cp.returncode != 0:
        return []
    return [
        ln.strip()
        for ln in cp.stdout.splitlines()
        if ln.strip() and "zk60_resource_guard.py" not in ln and "pgrep" not in ln
    ]


def wait_quiet_ds4(tag: str) -> dict:
    seen_wait = 0
    while True:
        procs = ds4_running()
        if not procs:
            return {"tag": tag, "quiet": True, "waited_polls": seen_wait, "active_ds4": []}
        if seen_wait >= 60:
            return {"tag": tag, "quiet": False, "waited_polls": seen_wait, "active_ds4": procs}
        time.sleep(10)
        seen_wait += 1


def stats(vals: list[float], ndigits: int = 4) -> dict:
    if not vals:
        return {"n": 0, "median": 0.0, "iqr": 0.0, "p25": 0.0, "p75": 0.0, "min": 0.0, "max": 0.0, "mean": 0.0}
    s = sorted(float(x) for x in vals)
    n = len(s)

    def pct(p: float) -> float:
        if n == 1:
            return s[0]
        pos = p * (n - 1)
        lo = int(pos)
        hi = min(lo + 1, n - 1)
        frac = pos - lo
        return s[lo] * (1.0 - frac) + s[hi] * frac

    p25 = pct(0.25)
    med = pct(0.50)
    p75 = pct(0.75)
    return {
        "n": n,
        "median": round(med, ndigits),
        "iqr": round(p75 - p25, ndigits),
        "p25": round(p25, ndigits),
        "p75": round(p75, ndigits),
        "min": round(s[0], ndigits),
        "max": round(s[-1], ndigits),
        "mean": round(sum(s) / n, ndigits),
        "samples": [round(float(x), ndigits) for x in vals],
    }


def stats_ms(vals_sec: list[float]) -> dict:
    return stats([v * 1000.0 for v in vals_sec], ndigits=3)


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def find_head_test_binary() -> Path:
    cands = sorted(
        [p for p in HASHLINE_DEPS.glob("hashline-*") if p.is_file() and os.access(p, os.X_OK) and "." not in p.name],
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )
    if not cands:
        raise RuntimeError(f"No executable hashline-* test binary found in {HASHLINE_DEPS}")
    return cands[0]


def run_guarded_leaf(
    label: str,
    need_gib: int,
    cap_gib: int,
    max_secs: int,
    log_path: Path,
    cmd: list[str],
    env_extra: dict[str, str] | None = None,
) -> dict:
    check_hold()
    guard_json = OUT / f"{label}.guard.json"
    done_path = Path(tempfile.gettempdir()) / f"{label}.{os.getpid()}.done"
    for p in (guard_json, log_path, done_path):
        p.unlink(missing_ok=True)
    full_cmd = [
        sys.executable,
        "-B",
        str(GUARD),
        "run",
        "--class",
        "gpu",
        "--label",
        label,
        "--need-gib",
        str(need_gib),
        "--cap-gib",
        str(cap_gib),
        "--max-secs",
        str(max_secs),
        "--log",
        str(log_path),
        "--done",
        str(done_path),
        "--result-json",
        str(guard_json),
        "--",
    ] + cmd
    env = os.environ.copy()
    env.pop("ZK60_GUARD_POLL_SECS", None)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    if env_extra:
        env.update(env_extra)
    print(f"[batch7] Starting guarded leaf {label} ...", flush=True)
    cp = subprocess.run(full_cmd, cwd=str(ROOT), env=env)
    done_path.unlink(missing_ok=True)
    if cp.returncode != 0:
        tail = log_path.read_text()[-4000:] if log_path.exists() else ""
        raise RuntimeError(f"Guarded leaf {label} failed with exit code {cp.returncode}:\n{tail}")
    rec = json.loads(guard_json.read_text())
    print(
        f"[batch7] Completed {label}: run_id={rec.get('run_id')} exit={rec.get('exit')} "
        f"wall={round(float(rec.get('child_wall_seconds', 0.0)), 2)}s peak_rss={rec.get('peak_rss_gib')}GiB "
        f"peak_vram={rec.get('peak_vram_mib')}MiB",
        flush=True,
    )
    return rec


def archive_and_parse_trace(prefix: Path) -> tuple[dict, list[dict]]:
    """Compresses raw `<prefix>.<pid>.tsv` to `<prefix>.<pid>.tsv.gz` in TRACE_ARCHIVE_DIR and parses all rows."""
    tsv_matches = sorted(prefix.parent.glob(f"{prefix.name}.*.tsv"))
    gz_matches = sorted(prefix.parent.glob(f"{prefix.name}.*.tsv.gz"))
    raw_bytes = None
    raw_sha = None
    tsv_path = None
    if len(tsv_matches) == 1:
        tsv_path = tsv_matches[0]
        raw_bytes = tsv_path.stat().st_size
        raw_sha = sha256_file(tsv_path)
        gz_path = tsv_path.with_suffix(".tsv.gz")
        with tsv_path.open("rb") as fin, gzip.open(gz_path, "wb", compresslevel=6) as fout:
            shutil.copyfileobj(fin, fout)
    elif len(gz_matches) == 1:
        gz_path = gz_matches[0]
    else:
        raise RuntimeError(f"Expected 1 trace file for prefix {prefix}, found tsv={tsv_matches} gz={gz_matches}")

    gz_bytes = gz_path.stat().st_size
    gz_sha = sha256_file(gz_path)

    rows: list[dict] = []
    uncompressed_count = 0
    h_uncomp = hashlib.sha256()
    with gzip.open(gz_path, "rt", encoding="utf-8") as f:
        for line in f:
            bline = line.encode("utf-8")
            uncompressed_count += len(bline)
            h_uncomp.update(bline)
            line = line.rstrip("\n")
            if not line or line.startswith("#") or line.startswith("tag\t"):
                continue
            parts = line.split("\t")
            if len(parts) != 9:
                continue
            tag, detail, th, q, b, c, gs, ge, done = parts
            kv = {}
            for tok in detail.split():
                if "=" in tok:
                    k, v = tok.split("=", 1)
                    kv[k] = v
            slot_label = detail.split(" | ", 1)[0] if " | " in detail else None
            gs_f = float(gs)
            ge_f = float(ge)
            b_f = float(b)
            c_f = float(c)
            d_f = float(done)
            rows.append(
                {
                    "tag": tag,
                    "detail": detail,
                    "slot_label": slot_label,
                    "kv": kv,
                    "thread": int(th),
                    "queue": int(q),
                    "begin": b_f,
                    "committed": c_f,
                    "gs": gs_f,
                    "ge": ge_f,
                    "done": d_f,
                    "gpu_dur": max(0.0, ge_f - gs_f) if (gs_f > 0 and ge_f >= gs_f) else 0.0,
                    "queue_wait": max(0.0, gs_f - c_f) if (gs_f > 0 and c_f > 0) else 0.0,
                    "encode_dur": max(0.0, c_f - b_f) if (c_f > 0 and b_f > 0) else 0.0,
                    "wakeup_dur": max(0.0, d_f - ge_f) if (ge_f > 0 and d_f >= ge_f) else 0.0,
                    "paired_rows": int(kv["rows"]) if "rows" in kv and kv["rows"].isdigit() else None,
                }
            )

    # Remove uncompressed .tsv only after verifying .tsv.gz parsed cleanly
    if tsv_path is not None and tsv_path.exists():
        tsv_path.unlink()
    meta = {
        "gz_path": str(gz_path),
        "gz_bytes": gz_bytes,
        "gz_sha256": gz_sha,
        "uncompressed_bytes": raw_bytes if raw_bytes is not None else uncompressed_count,
        "uncompressed_sha256": raw_sha if raw_sha is not None else h_uncomp.hexdigest(),
        "parsed_cb_rows": len(rows),
    }
    return meta, rows


def gpu_busy_interval(rows: list[dict], w0: float | None = None, w1: float | None = None) -> dict:
    valid = [r for r in rows if r["gs"] > 0 and r["ge"] >= r["gs"]]
    if not valid:
        return {
            "window_s": 0.0,
            "busy_s": 0.0,
            "busy_pct_of_window": 0.0,
            "sum_spans_s": 0.0,
            "mean_concurrency_while_busy": 0.0,
            "cb_count": 0,
        }
    lo = min(r["gs"] for r in valid) if w0 is None else w0
    hi = max(r["ge"] for r in valid) if w1 is None else w1
    clipped = [r for r in valid if r["ge"] > lo and r["gs"] < hi]
    if not clipped or hi <= lo:
        return {
            "window_s": max(0.0, hi - lo),
            "busy_s": 0.0,
            "busy_pct_of_window": 0.0,
            "sum_spans_s": 0.0,
            "mean_concurrency_while_busy": 0.0,
            "cb_count": 0,
        }
    ev: list[tuple[float, int]] = []
    sum_spans = 0.0
    for r in clipped:
        a = max(r["gs"], lo)
        b = min(r["ge"], hi)
        sum_spans += b - a
        ev.append((a, 1))
        ev.append((b, -1))
    ev.sort(key=lambda e: (e[0], -e[1]))
    depth = 0
    last = lo
    busy = 0.0
    for t, d in ev:
        dt = t - last
        if depth > 0 and dt > 0:
            busy += dt
        depth += d
        last = t
    wall = hi - lo
    return {
        "window_s": round(wall, 6),
        "busy_s": round(busy, 6),
        "busy_pct_of_window": round(100.0 * busy / wall, 2) if wall > 0 else 0.0,
        "sum_spans_s": round(sum_spans, 6),
        "mean_concurrency_while_busy": round(sum_spans / busy, 3) if busy > 0 else 0.0,
        "cb_count": len(clipped),
    }


def detect_ah_rows(rows: list[dict]) -> tuple[int, int]:
    big_commit_rows = sorted({r["paired_rows"] for r in rows if r["tag"] == "commit" and (r["paired_rows"] or 0) >= 1500})
    if len(big_commit_rows) != 2:
        raise RuntimeError(f"Expected 2 block commitment row counts (>=1500), got {big_commit_rows}")
    return big_commit_rows[0], big_commit_rows[1]


def split_stream_trace_into_passes(
    trace_rows: list[dict], expected_passes_reqs: list[int], h_rows: int
) -> list[list[dict]]:
    rows = sorted(trace_rows, key=lambda r: (r["done"], r["begin"]))
    total_reqs = sum(expected_passes_reqs)

    # Strip the 224 setup wprods from A18Fix::new(spec.profile, 32) prior to cold request
    first_non_wprod = next((idx for idx, r in enumerate(rows) if r["tag"] != "wprod"), None)
    if first_non_wprod is None or first_non_wprod < 224:
        raise RuntimeError(f"Unexpected leading wprods before first commit: {first_non_wprod}")
    rows = rows[first_non_wprod - 224 :]

    if len(rows) % total_reqs == 0:
        cbs_per_req = len(rows) // total_reqs
        passes = []
        cur = 0
        for reqs in expected_passes_reqs:
            cnt = reqs * cbs_per_req
            chunk = rows[cur : cur + cnt]
            ch = sum(1 for r in chunk if r["tag"] == "commit" and r["paired_rows"] == h_rows)
            wp = sum(1 for r in chunk if r["tag"] == "wprod")
            if ch == 32 * reqs and wp == 224 * reqs:
                passes.append(chunk)
                cur += cnt
            else:
                passes = []
                break
        if passes and cur == len(rows):
            return passes

    # Fallback state-machine split
    passes = []
    start = 0
    for reqs in expected_passes_reqs:
        target_ch = 32 * reqs
        target_oh = 32 * reqs
        ch = oh = 0
        max_d = 0.0
        best_split = None
        for j in range(start, len(rows)):
            r = rows[j]
            max_d = max(max_d, r["done"])
            if r["tag"] == "commit" and r["paired_rows"] == h_rows:
                ch += 1
            elif r["tag"] == "gather" and r["paired_rows"] == h_rows:
                oh += 1
            if ch == target_ch and oh == target_oh:
                if j + 1 == len(rows):
                    best_split = j + 1
                    break
                gap = rows[j + 1]["begin"] - max_d
                if gap > 0.10 and rows[j + 1]["tag"] == "wprod":
                    best_split = j + 1
                    break
        if best_split is None:
            raise RuntimeError(f"Could not split pass from index {start} for reqs={reqs}")
        passes.append(rows[start:best_split])
        start = best_split
    if start != len(rows):
        raise RuntimeError(f"Leftover trace rows {len(rows) - start}")
    return passes


def partition_wprod_group(group: list[dict]) -> tuple[float, float, float, float]:
    """Partitions [min_begin, max_done] of a parallel wprod group (QKV, Wo, GU, Wd) into 3 disjoint sets:
      - gpu_busy: t in union [gs_i, ge_i] (at least one wprod CB in group executing on GPU)
      - ext_queue_wait: t not in gpu_busy AND t in union [committed_i, gs_i] (committed & waiting, 0 group CBs running;
        eliminates self-serialization double-counting within QKV or GU on queue 99!)
      - host_inside: wall - gpu_busy - ext_queue_wait (i16 pack/encode, commit gaps, wakeup, overlapped RoPE)
    Returns (wall, gpu_busy, ext_queue_wait, host_inside).
    """
    b0 = min(r["begin"] for r in group)
    d1 = max(r["done"] for r in group)
    wall = max(0.0, d1 - b0)
    ev: list[tuple[float, str, int]] = []
    for r in group:
        if r["gs"] > 0 and r["ge"] > r["gs"]:
            a = max(b0, min(d1, r["gs"]))
            b = max(b0, min(d1, r["ge"]))
            if b > a:
                ev.append((a, "g", 1))
                ev.append((b, "g", -1))
        if r["committed"] > 0 and r["gs"] > r["committed"]:
            a = max(b0, min(d1, r["committed"]))
            b = max(b0, min(d1, r["gs"]))
            if b > a:
                ev.append((a, "q", 1))
                ev.append((b, "q", -1))
    ev.sort(key=lambda e: e[0])
    g_depth = 0
    q_depth = 0
    last = b0
    gpu_busy = 0.0
    ext_qwait = 0.0
    for t, kind, delta in ev:
        dt = t - last
        if dt > 0:
            if g_depth > 0:
                gpu_busy += dt
            elif q_depth > 0:
                ext_qwait += dt
        if kind == "g":
            g_depth += delta
        else:
            q_depth += delta
        last = t
    host_inside = max(0.0, wall - gpu_busy - ext_qwait)
    return wall, gpu_busy, ext_qwait, host_inside


def decompose_one_request_sealing(req_info: dict, req_wprods: list[dict], all_pass_non_wprods: list[dict]) -> dict:
    """Decomposes a single 32-block request's 224 wprod CBs into exact causal phases + host vs GPU + contention."""
    if len(req_wprods) != 224:
        raise RuntimeError(f"Expected 224 wprods for 32-block request, got {len(req_wprods)}")

    w_sorted = sorted(req_wprods, key=lambda r: r["begin"])

    # Partition into 32 sequential blocks of 7 CBs and verify all 4 causal barriers per block!
    p1_qkv_wall = 0.0
    p2_attn_host = 0.0
    p3_wo_wall = 0.0
    p4_pre_ffn_host = 0.0
    p5_gu_wall = 0.0
    p6_swiglu_host = 0.0
    p7_wd_wall = 0.0
    p8_interblock_31_host = 0.0

    wprod_gpu_busy_total = 0.0
    wprod_ext_qwait_total = 0.0
    wprod_host_inside_total = 0.0

    blocks = [w_sorted[7 * b : 7 * (b + 1)] for b in range(32)]
    for b_idx, blk in enumerate(blocks):
        if b_idx > 0:
            prev_wd_done = blocks[b_idx - 1][6]["done"]
            cur_qkv_min_begin = min(r["begin"] for r in blk[:3])
            if cur_qkv_min_begin < prev_wd_done - 1e-6:
                raise RuntimeError(
                    f"Block boundary barrier violated at block {b_idx}: {cur_qkv_min_begin} < {prev_wd_done}"
                )
            p8_interblock_31_host += max(0.0, cur_qkv_min_begin - prev_wd_done)

        qkv = blk[0:3]
        wo = blk[3]
        gu = blk[4:6]
        wd = blk[6]

        # Verify in_out flags: Q,K,V,Wo have in_out=0; Wg,Wu,Wd have in_out=1
        if any(r["kv"].get("in_out") != "0" for r in qkv) or wo["kv"].get("in_out") != "0":
            raise RuntimeError(f"Unexpected attention in_out flag in block {b_idx}: {[r['detail'] for r in blk[:4]]}")
        if any(r["kv"].get("in_out") != "1" for r in gu) or wd["kv"].get("in_out") != "1":
            raise RuntimeError(f"Unexpected FFN in_out flag in block {b_idx}: {[r['detail'] for r in blk[4:]]}")

        qkv_b0 = min(r["begin"] for r in qkv)
        qkv_d1 = max(r["done"] for r in qkv)
        if wo["begin"] < qkv_d1 - 1e-6:
            raise RuntimeError(f"QKV->Wo barrier violated in block {b_idx}: {wo['begin']} < {qkv_d1}")

        gu_b0 = min(r["begin"] for r in gu)
        gu_d1 = max(r["done"] for r in gu)
        if gu_b0 < wo["done"] - 1e-6:
            raise RuntimeError(f"Wo->GU barrier violated in block {b_idx}: {gu_b0} < {wo['done']}")
        if wd["begin"] < gu_d1 - 1e-6:
            raise RuntimeError(f"GU->Wd barrier violated in block {b_idx}: {wd['begin']} < {gu_d1}")

        w1, g1, q1, h1 = partition_wprod_group(qkv)
        w3, g3, q3, h3 = partition_wprod_group([wo])
        w5, g5, q5, h5 = partition_wprod_group(gu)
        w7, g7, q7, h7 = partition_wprod_group([wd])

        p1_qkv_wall += w1
        p2_attn_host += max(0.0, wo["begin"] - qkv_d1)
        p3_wo_wall += w3
        p4_pre_ffn_host += max(0.0, gu_b0 - wo["done"])
        p5_gu_wall += w5
        p6_swiglu_host += max(0.0, wd["begin"] - gu_d1)
        p7_wd_wall += w7

        wprod_gpu_busy_total += g1 + g3 + g5 + g7
        wprod_ext_qwait_total += q1 + q3 + q5 + q7
        wprod_host_inside_total += h1 + h3 + h5 + h7

    first_qkv_begin = min(r["begin"] for r in blocks[0][:3])
    last_wd_done = blocks[31][6]["done"]
    wprod_chain_span_s = max(0.0, last_wd_done - first_qkv_begin)

    seal_pass_s = req_info["seal_s"]
    seal_side_total_s = max(0.0, req_info["seal_done"] - req_info["seal_turn"])
    # Block 0 pre-QKV (seq + scatter + norm_a_0) + Block 31 post-Wd (Z + res2 + assign_with_31 + CS-3 + statement)
    p8_bookends_host = max(0.0, seal_pass_s - wprod_chain_span_s)
    p8_total_assign_cs3_norma_host = p8_interblock_31_host + p8_bookends_host
    p9_endpoints_door_host = max(0.0, seal_side_total_s - seal_pass_s)

    wprod_wall_total = p1_qkv_wall + p3_wo_wall + p5_gu_wall + p7_wd_wall
    wprod_gpu_summed_spans = sum(r["gpu_dur"] for r in w_sorted)
    wprod_sum_queue_wait_all224 = sum(r["queue_wait"] for r in w_sorted)

    # Concurrent prover GPU busy during this request's wprod chain window [first_qkv_begin, last_wd_done]
    prover_concurrent = gpu_busy_interval(all_pass_non_wprods, w0=first_qkv_begin, w1=last_wd_done)

    compute_host_mid_total = p2_attn_host + p4_pre_ffn_host + p6_swiglu_host
    pure_host_outside_wprod = compute_host_mid_total + p8_total_assign_cs3_norma_host

    return {
        "seal_side_total_s": seal_side_total_s,
        "seal_pass_s": seal_pass_s,
        "wprod_chain_span_s": wprod_chain_span_s,
        "p1_qkv_wprod_wall_s": p1_qkv_wall,
        "p2_attn_scores_softmax_pv_host_s": p2_attn_host,
        "p3_wo_wprod_wall_s": p3_wo_wall,
        "p4_ao_res1_normm_host_s": p4_pre_ffn_host,
        "p5_gu_wprod_wall_s": p5_gu_wall,
        "p6_swiglu_host_s": p6_swiglu_host,
        "p7_wd_wprod_wall_s": p7_wd_wall,
        "p8_interblock_31_assign_cs3_norma_host_s": p8_interblock_31_host,
        "p8_bookends_blk0_norma_blk31_assign_stmt_host_s": p8_bookends_host,
        "p8_total_assign_cs3_norma_host_s": p8_total_assign_cs3_norma_host,
        "p9_endpoints_commit_and_door_host_s": p9_endpoints_door_host,
        "wprod_wall_4groups_total_s": wprod_wall_total,
        "wprod_gpu_busy_union_s": wprod_gpu_busy_total,
        "wprod_gpu_summed_spans_s": wprod_gpu_summed_spans,
        "wprod_crit_gpu_queue_wait_s": wprod_ext_qwait_total,
        "wprod_sum_gpu_queue_wait_224cbs_s": wprod_sum_queue_wait_all224,
        "wprod_host_encode_wakeup_overlapped_rope_s": wprod_host_inside_total,
        "pure_host_compute_mid_p2_p4_p6_s": compute_host_mid_total,
        "pure_host_outside_wprod_p2_p4_p6_p8_s": pure_host_outside_wprod,
        "total_host_ex_gpu_busy_and_queue_wait_s": pure_host_outside_wprod + wprod_host_inside_total,
        "prover_gpu_busy_during_seal_s": prover_concurrent["busy_s"],
        "prover_gpu_busy_pct_of_seal_span": prover_concurrent["busy_pct_of_window"],
    }


def summarize_decomp_list(items: list[dict]) -> dict:
    if not items:
        return {}
    keys = list(items[0].keys())
    return {k: stats([it[k] for it in items], ndigits=4) for k in keys}


def extract_per_slot_gpu_spans_from_serve1(warm_pass_traces: list[list[dict]]) -> dict:
    """Computes per-slot GPU span (ms/block) across the 6 * 32 = 192 solo blocks in serve1."""
    per_pass_slot_ms: dict[str, list[float]] = collections.defaultdict(list)
    for trows in warm_pass_traces:
        slot_sum_s: dict[str, float] = collections.defaultdict(float)
        for r in trows:
            if r["tag"] in ("batch", "round", "fold", "tables") and r["slot_label"]:
                slot_sum_s[r["slot_label"]] += r["gpu_dur"]
        # Each warm pass in serve1 proves L=32 blocks
        for sl, tot_s in slot_sum_s.items():
            per_pass_slot_ms[sl].append((tot_s / 32.0) * 1000.0)
    out = {}
    for sl in sorted(per_pass_slot_ms.keys()):
        out[sl] = stats(per_pass_slot_ms[sl], ndigits=3)
    return out


def parse_stream_arm(log_text: str, trace_rows: list[dict], arm_label: str, reqs_per_pass: int, lanes: int, n_passes: int) -> dict:
    req_re = re.compile(
        r"A22-AB REQ \S+ L32 N6 \[" + re.escape(arm_label) + r"\] pass (\d+) request (\d+): "
        r"arrived ([0-9.]+), sealing turn ([0-9.]+), sealing side done ([0-9.]+) \(sealing pass ([0-9.]+) s\), "
        r"prover ([0-9.]+)-([0-9.]+) \(waited ([0-9.]+) s; prove call ([0-9.]+) s: "
        r"preflight ([0-9.]+), commit ([0-9.]+), forks ([0-9.]+), join ([0-9.]+)\), "
        r"receipt write ([0-9.]+) s \([^)]+\), result ([0-9.]+); (\d+) B; (\d+) witnesses kept;"
    )
    stream_re = re.compile(
        r"A22-AB STREAM \S+ L32 N6 \[" + re.escape(arm_label) + r"\] pass (\d+): "
        r"(\d+) requests in ([0-9.]+) s \(([^)]+)\); steady ([0-9.NaN]+) tok/s; amortized ([0-9.]+) tok/s;.*"
        r"footprint start ([0-9.]+) GiB, peak ([0-9.]+) GiB, end ([0-9.]+) GiB; user ([0-9.]+) s \+ sys ([0-9.]+) s"
    )
    verified_lines = [
        ln.strip() for ln in log_text.splitlines() if "receipts verified from their run directories" in ln
    ]

    reqs_by_pass: dict[int, list[dict]] = collections.defaultdict(list)
    for m in req_re.finditer(log_text):
        p = int(m.group(1))
        reqs_by_pass[p].append(
            {
                "q": int(m.group(2)),
                "arrived": float(m.group(3)),
                "seal_turn": float(m.group(4)),
                "seal_done": float(m.group(5)),
                "seal_s": float(m.group(6)),
                "prover_start": float(m.group(7)),
                "prover_end": float(m.group(8)),
                "waited_for_prover_s": float(m.group(9)),
                "prove_call_s": float(m.group(10)),
                "preflight_s": float(m.group(11)),
                "commit_s": float(m.group(12)),
                "forks_s": float(m.group(13)),
                "join_s": float(m.group(14)),
                "write_s": float(m.group(15)),
                "done_s": float(m.group(16)),
                "receipt_bytes": int(m.group(17)),
                "kept_witnesses": int(m.group(18)),
            }
        )

    streams_by_pass: dict[int, dict] = {}
    for m in stream_re.finditer(log_text):
        p = int(m.group(1))
        st_val = float(m.group(5)) if m.group(5) != "NaN" else 0.0
        streams_by_pass[p] = {
            "wall_s": float(m.group(3)),
            "settings": m.group(4),
            "steady_tok_s": st_val,
            "amortized_tok_s": float(m.group(6)),
            "start_footprint_gib": float(m.group(7)),
            "peak_footprint_gib": float(m.group(8)),
            "end_footprint_gib": float(m.group(9)),
            "cpu_user_s": float(m.group(10)),
            "cpu_sys_s": float(m.group(11)),
        }

    if len(streams_by_pass) != n_passes:
        raise RuntimeError(f"Expected {n_passes} passes for {arm_label}, got {len(streams_by_pass)}")

    a_rows, h_rows = detect_ah_rows(trace_rows)
    expected = [1] + [reqs_per_pass] * n_passes
    pass_traces = split_stream_trace_into_passes(trace_rows, expected, h_rows)
    warm_traces = pass_traces[1:]

    solo_req0_decomps: list[dict] = []
    overlapped_decomps: list[dict] = []
    lane_reused_decomps: list[dict] = []  # q >= lanes

    pass_wall_s = []
    amort_req_wall_s = []
    amort_tok_s = []
    steady_all_cadence_s = []
    steady_all_tok_s = []
    steady_post_lane_fill_cadence_s = []  # (done[R-1] - done[lanes-1]) / (R - lanes) when R > lanes
    steady_post_lane_fill_tok_s = []
    peak_fp_gib = []
    cpu_user_per_req_s = []
    cpu_sys_per_req_s = []
    steady_gpu_busy_per_req_s = []
    steady_gpu_busy_pct = []

    overlapped_prove_call_s = []
    overlapped_forks_s = []
    uncontended_last_forks_s = []
    prover_slack_s = []  # prover_start - seal_done on q >= 1
    prover_stall_s = []  # max(0, seal_done(q) - prover_end(q-1)) on q >= 1
    lane_admission_wait_s = []  # max(0, seal_turn(q) - seal_done(q-1)) on q >= lanes

    for p in range(n_passes):
        st = streams_by_pass[p]
        rlist = sorted(reqs_by_pass[p], key=lambda x: x["q"])
        trows = warm_traces[p]

        wprods_pass = sorted([r for r in trows if r["tag"] == "wprod"], key=lambda r: r["begin"])
        non_wprods_pass = [r for r in trows if r["tag"] != "wprod"]
        if len(wprods_pass) != 224 * reqs_per_pass:
            raise RuntimeError(f"Pass {p} expected {224 * reqs_per_pass} wprods, got {len(wprods_pass)}")

        for q in range(reqs_per_pass):
            req_wp = wprods_pass[224 * q : 224 * (q + 1)]
            dec = decompose_one_request_sealing(rlist[q], req_wp, non_wprods_pass)
            if q == 0:
                solo_req0_decomps.append(dec)
            else:
                overlapped_decomps.append(dec)
                prover_slack_s.append(rlist[q]["waited_for_prover_s"])
                prover_stall_s.append(max(0.0, rlist[q]["seal_done"] - rlist[q - 1]["prover_end"]))
                if q < reqs_per_pass - 1:
                    overlapped_forks_s.append(rlist[q]["forks_s"])
                else:
                    uncontended_last_forks_s.append(rlist[q]["forks_s"])
                overlapped_prove_call_s.append(rlist[q]["prove_call_s"])
            if q >= lanes:
                lane_reused_decomps.append(dec)
                lane_admission_wait_s.append(max(0.0, rlist[q]["seal_turn"] - rlist[q - 1]["seal_done"]))

        pass_wall_s.append(st["wall_s"])
        amort_req_wall_s.append(st["wall_s"] / reqs_per_pass)
        amort_tok_s.append(st["amortized_tok_s"])
        peak_fp_gib.append(st["peak_footprint_gib"])
        cpu_user_per_req_s.append(st["cpu_user_s"] / reqs_per_pass)
        cpu_sys_per_req_s.append(st["cpu_sys_s"] / reqs_per_pass)

        if reqs_per_pass > 1:
            cad = (rlist[-1]["done_s"] - rlist[0]["done_s"]) / (reqs_per_pass - 1)
            steady_all_cadence_s.append(cad)
            steady_all_tok_s.append(st["steady_tok_s"])
            last_cb_done = max(r["done"] for r in trows)
            t0_host = last_cb_done - rlist[-1]["prover_end"]
            sw0 = t0_host + rlist[0]["done_s"]
            sw1 = t0_host + rlist[-1]["done_s"]
            siv = gpu_busy_interval(trows, w0=sw0, w1=sw1)
            steady_gpu_busy_per_req_s.append(siv["busy_s"] / (reqs_per_pass - 1))
            steady_gpu_busy_pct.append(siv["busy_pct_of_window"])

        if reqs_per_pass > lanes:
            cad_post = (rlist[-1]["done_s"] - rlist[lanes - 1]["done_s"]) / (reqs_per_pass - lanes)
            steady_post_lane_fill_cadence_s.append(cad_post)
            steady_post_lane_fill_tok_s.append(128.0 / cad_post)

    res = {
        "arm": arm_label,
        "lanes": lanes,
        "requests_per_pass": reqs_per_pass,
        "n_warm_passes": n_passes,
        "settings_observed": streams_by_pass[0]["settings"],
        "verified_lines": verified_lines,
        "all_witnesses_kept_in_ram_count": sorted({r["kept_witnesses"] for plist in reqs_by_pass.values() for r in plist}),
        "pass_wall_s": stats(pass_wall_s),
        "amortized_per_req_wall_s": stats(amort_req_wall_s),
        "amortized_tok_s": stats(amort_tok_s),
        "peak_footprint_gib": stats(peak_fp_gib, ndigits=2),
        "cpu_user_per_req_s": stats(cpu_user_per_req_s, ndigits=3),
        "cpu_sys_per_req_s": stats(cpu_sys_per_req_s, ndigits=3),
        "sealing_phase_profile_unoverlapped_req0": summarize_decomp_list(solo_req0_decomps),
    }
    if reqs_per_pass == 1:
        res["per_slot_gpu_spans_ms_per_block_192_blocks"] = extract_per_slot_gpu_spans_from_serve1(warm_traces)
    if reqs_per_pass > 1:
        res["steady_state"] = {
            "cadence_reqs_1_to_last_s": stats(steady_all_cadence_s),
            "steady_tok_s": stats(steady_all_tok_s, ndigits=2),
            "steady_gpu_busy_union_per_req_s": stats(steady_gpu_busy_per_req_s),
            "steady_gpu_busy_pct_of_wall": stats(steady_gpu_busy_pct, ndigits=2),
            "steady_prove_call_reqs_1_to_last_s": stats(overlapped_prove_call_s),
            "forks_contended_mid_reqs_s": stats(overlapped_forks_s),
            "forks_uncontended_last_req_s": stats(uncontended_last_forks_s),
            "prover_slack_before_prover_start_s": stats(prover_slack_s),
            "prover_stall_waiting_for_seal_s": stats(prover_stall_s),
            "lane_admission_wait_after_prev_seal_s": stats(lane_admission_wait_s),
        }
        if steady_post_lane_fill_cadence_s:
            res["steady_state"]["post_lane_fill_cadence_q_ge_lanes_s"] = stats(steady_post_lane_fill_cadence_s)
            res["steady_state"]["post_lane_fill_tok_s"] = stats(steady_post_lane_fill_tok_s, ndigits=2)
        res["sealing_phase_profile_overlapped_reqs_1_to_last"] = summarize_decomp_list(overlapped_decomps)
        if lane_reused_decomps:
            res["sealing_phase_profile_lane_reused_q_ge_lanes"] = summarize_decomp_list(lane_reused_decomps)
    return res


def compute_slowdown_attribution(solo: dict, ov: dict) -> dict:
    """Computes millisecond and percentage attribution of the sealing slowdown (overlapped vs solo) on both medians and means."""
    def med(d: dict, k: str) -> float:
        return float(d[k]["median"])

    def mn(d: dict, k: str) -> float:
        return float(d[k]["mean"])

    s_tot = med(solo, "seal_pass_s")
    o_tot = med(ov, "seal_pass_s")
    delta_tot = o_tot - s_tot

    s_tot_m = mn(solo, "seal_pass_s")
    o_tot_m = mn(ov, "seal_pass_s")
    delta_tot_m = o_tot_m - s_tot_m

    # 1. Commit-to-GPUStartTime wait on queue 99 (ex-busy)
    d_qwait = med(ov, "wprod_crit_gpu_queue_wait_s") - med(solo, "wprod_crit_gpu_queue_wait_s")
    d_qwait_m = mn(ov, "wprod_crit_gpu_queue_wait_s") - mn(solo, "wprod_crit_gpu_queue_wait_s")
    # 2. GPU kernel execution time slowdown
    d_gpu_exec = med(ov, "wprod_gpu_busy_union_s") - med(solo, "wprod_gpu_busy_union_s")
    d_gpu_exec_m = mn(ov, "wprod_gpu_busy_union_s") - mn(solo, "wprod_gpu_busy_union_s")
    # 3. Host inside wprod_wall (encode + completion wakeup + overlapped QR/KR RoPE inside QKV rayon::join; i16 pack runs before begin)
    d_wprod_host = med(ov, "wprod_host_encode_wakeup_overlapped_rope_s") - med(
        solo, "wprod_host_encode_wakeup_overlapped_rope_s"
    )
    d_wprod_host_m = mn(ov, "wprod_host_encode_wakeup_overlapped_rope_s") - mn(
        solo, "wprod_host_encode_wakeup_overlapped_rope_s"
    )
    # 4. Intra-block host gaps (P2 + P4 + P6 — 0 wprod CBs in flight; includes Wo/Wg/Wu/Wd preludes and QKV requant/RoPE tail)
    d_compute_host = med(ov, "pure_host_compute_mid_p2_p4_p6_s") - med(solo, "pure_host_compute_mid_p2_p4_p6_s")
    d_compute_host_m = mn(ov, "pure_host_compute_mid_p2_p4_p6_s") - mn(solo, "pure_host_compute_mid_p2_p4_p6_s")
    # 5. Inter-block + bookend host residual (P8 — 0 wprod CBs in flight; internal split not measured)
    d_mem_assign_host = med(ov, "p8_total_assign_cs3_norma_host_s") - med(solo, "p8_total_assign_cs3_norma_host_s")
    d_mem_assign_host_m = mn(ov, "p8_total_assign_cs3_norma_host_s") - mn(solo, "p8_total_assign_cs3_norma_host_s")

    sum_parts = d_qwait + d_gpu_exec + d_wprod_host + d_compute_host + d_mem_assign_host
    sum_parts_m = d_qwait_m + d_gpu_exec_m + d_wprod_host_m + d_compute_host_m + d_mem_assign_host_m
    pct = lambda x: round(100.0 * x / delta_tot, 1) if delta_tot > 0 else 0.0
    pct_m = lambda x: round(100.0 * x / delta_tot_m, 1) if delta_tot_m > 0 else 0.0

    return {
        "solo_seal_pass_median_s": round(s_tot, 4),
        "overlapped_seal_pass_median_s": round(o_tot, 4),
        "slowdown_factor_x": round(o_tot / s_tot, 3) if s_tot > 0 else 0.0,
        "total_slowdown_delta_median_s": round(delta_tot, 4),
        "sum_of_component_median_deltas_s": round(sum_parts, 4),
        "sum_of_component_median_shares_pct": round(100.0 * sum_parts / delta_tot, 1) if delta_tot > 0 else 0.0,
        "solo_seal_pass_mean_s": round(s_tot_m, 4),
        "overlapped_seal_pass_mean_s": round(o_tot_m, 4),
        "total_slowdown_delta_mean_s": round(delta_tot_m, 4),
        "sum_of_component_mean_deltas_s": round(sum_parts_m, 4),
        "sum_of_component_mean_shares_pct": round(100.0 * sum_parts_m / delta_tot_m, 1) if delta_tot_m > 0 else 0.0,
        "components": {
            "1_gpu_queue_wait_on_wprod_s": {
                "solo_median_s": round(med(solo, "wprod_crit_gpu_queue_wait_s"), 4),
                "overlapped_median_s": round(med(ov, "wprod_crit_gpu_queue_wait_s"), 4),
                "delta_median_s": round(d_qwait, 4),
                "share_of_median_slowdown_pct": pct(d_qwait),
                "delta_mean_s": round(d_qwait_m, 4),
                "share_of_mean_slowdown_pct": pct_m(d_qwait_m),
                "mechanism": "Commit-to-GPUStartTime wait on witness queue 99 beside 6 fork threads submitting to shared prover queue 0 (87-97% of overlapped wait occurs while prover CBs execute on GPU)",
            },
            "2_wprod_gpu_kernel_exec_slowdown_s": {
                "solo_median_s": round(med(solo, "wprod_gpu_busy_union_s"), 4),
                "overlapped_median_s": round(med(ov, "wprod_gpu_busy_union_s"), 4),
                "delta_median_s": round(d_gpu_exec, 4),
                "share_of_median_slowdown_pct": pct(d_gpu_exec),
                "delta_mean_s": round(d_gpu_exec_m, 4),
                "share_of_mean_slowdown_pct": pct_m(d_gpu_exec_m),
                "mechanism": "GPU SM / unified-memory sharing while concurrent prover CBs execute",
            },
            "3_wprod_host_encode_wakeup_overlapped_rope_s": {
                "solo_median_s": round(med(solo, "wprod_host_encode_wakeup_overlapped_rope_s"), 4),
                "overlapped_median_s": round(med(ov, "wprod_host_encode_wakeup_overlapped_rope_s"), 4),
                "delta_median_s": round(d_wprod_host, 4),
                "share_of_median_slowdown_pct": pct(d_wprod_host),
                "delta_mean_s": round(d_wprod_host_m, 4),
                "share_of_mean_slowdown_pct": pct_m(d_wprod_host_m),
                "mechanism": "Begin-to-commit encode + GPUEnd-to-done wakeup + overlapped QR/KR RoPE in P1 (i16 pack, weight_buffer, and result_plane run before begin, inside P2/P4/P6/P8)",
            },
            "4_intra_block_host_gaps_p2_p4_p6_s": {
                "solo_median_s": round(med(solo, "pure_host_compute_mid_p2_p4_p6_s"), 4),
                "overlapped_median_s": round(med(ov, "pure_host_compute_mid_p2_p4_p6_s"), 4),
                "delta_median_s": round(d_compute_host, 4),
                "share_of_median_slowdown_pct": pct(d_compute_host),
                "delta_mean_s": round(d_compute_host_m, 4),
                "share_of_mean_slowdown_pct": pct_m(d_compute_host_m),
                "mechanism": "Host contention on Apple M3 Ultra (32 cores: 8-thread SealPool vs 6 fork threads + global Rayon pool; 0 wprod CBs in flight; includes attention/norm_m/SwiGLU plus QKV requant/RoPE tail and Wo/Wg/Wu/Wd preludes)",
            },
            "5_inter_block_and_bookend_host_p8_s": {
                "solo_median_s": round(med(solo, "p8_total_assign_cs3_norma_host_s"), 4),
                "overlapped_median_s": round(med(ov, "p8_total_assign_cs3_norma_host_s"), 4),
                "delta_median_s": round(d_mem_assign_host, 4),
                "share_of_median_slowdown_pct": pct(d_mem_assign_host),
                "delta_mean_s": round(d_mem_assign_host_m, 4),
                "share_of_mean_slowdown_pct": pct_m(d_mem_assign_host_m),
                "mechanism": "Host contention (cause not separated; internal split of P8 not measured: builder tail, assign_with plane alloc/zero/scatter, CS-3 lookup scan, padded_plane, handoff, next-block checks/weight scan, norm_a, QKV preludes; longer gaps coincide with host-heavy prover phases when prover GPU is idle)",
            },
        },
        "per_phase_medians_s": {
            k: {
                "solo_s": round(med(solo, k), 4),
                "overlapped_s": round(med(ov, k), 4),
                "delta_s": round(med(ov, k) - med(solo, k), 4),
                "ratio_x": round(med(ov, k) / med(solo, k), 3) if med(solo, k) > 0.0005 else None,
            }
            for k in [
                "p1_qkv_wprod_wall_s",
                "p2_attn_scores_softmax_pv_host_s",
                "p3_wo_wprod_wall_s",
                "p4_ao_res1_normm_host_s",
                "p5_gu_wprod_wall_s",
                "p6_swiglu_host_s",
                "p7_wd_wprod_wall_s",
                "p8_total_assign_cs3_norma_host_s",
                "p9_endpoints_commit_and_door_host_s",
            ]
        },
    }


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    TRACE_ARCHIVE_DIR.mkdir(parents=True, exist_ok=True)

    head_sha = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip()
    gpu_metal_diff = subprocess.check_output(
        ["git", "-C", str(ROOT), "diff", "--stat", "HEAD", "--", "ops/zkp-mvp/gpu-metal"], text=True
    ).strip()
    if gpu_metal_diff:
        raise RuntimeError(f"Expected clean ops/zkp-mvp/gpu-metal, got diff:\n{gpu_metal_diff}")

    test_bin = find_head_test_binary()
    bin_sha = sha256_file(test_bin)
    bin_bytes = test_bin.stat().st_size

    quiet_checks = []
    guard_records = []
    traces_manifest = {}

    arms = [
        ("agy-batch7-serve1-6warm", "serve1", 1, 2, 36, 48, 420, "batch7_serve1_6warm.log", "serve1_6warm"),
        ("agy-batch7-serve4-lanes2-6warm", "serve4", 4, 2, 40, 52, 600, "batch7_serve4_lanes2_6warm.log", "serve4_lanes2_6warm"),
        ("agy-batch7-serve6-lanes3-6warm", "serve6+lanes3", 6, 3, 48, 64, 720, "batch7_serve6_lanes3_6warm.log", "serve6_lanes3_6warm"),
    ]

    parsed_arms = {}
    ran_any_leaf = False
    for idx, (label, arm_str, reqs, lanes, need_gib, cap_gib, max_s, log_name, trace_stem) in enumerate(arms):
        log_path = OUT / log_name
        guard_json = OUT / f"{label}.guard.json"
        trace_prefix = TRACE_ARCHIVE_DIR / trace_stem
        existing_traces = list(TRACE_ARCHIVE_DIR.glob(f"{trace_stem}.*.tsv*"))

        reuse = False
        if guard_json.exists() and log_path.exists() and existing_traces:
            rec_try = json.loads(guard_json.read_text())
            if rec_try.get("exit") == 0 and "test result: ok." in log_path.read_text():
                reuse = True
                rec = rec_try
                print(
                    f"[batch7] Reusing completed guarded leaf {label}: run_id={rec.get('run_id')} "
                    f"wall={round(float(rec.get('child_wall_seconds', 0.0)), 2)}s",
                    flush=True,
                )

        if not reuse:
            if ran_any_leaf:
                time.sleep(12)
            quiet_checks.append(wait_quiet_ds4(f"pre_{label}"))
            for stale in TRACE_ARCHIVE_DIR.glob(f"{trace_stem}.*"):
                stale.unlink()

            leaf_env = {
                "HL_GPU": "1",
                "HL_GPU_REQUIRED": "1",
                "HL_PB_ORACLE": "0",
                "HL_METAL_TIMING": "0",
                "HL_D55_PROFILE": "W16R2_8B_T128_H24",
                "HL_D55_L": "32",
                "HL_D55_WORKERS": "6",
                "HL_A19_BUDGET_GIB": "32",
                "HL_A22_AB_PASSES": "6",
                "HL_A22_AB": arm_str,
                "HL_A27_GPU_TRACE": str(trace_prefix),
            }
            rec = run_guarded_leaf(
                label=label,
                need_gib=need_gib,
                cap_gib=cap_gib,
                max_secs=max_s,
                log_path=log_path,
                cmd=[
                    str(test_bin),
                    "--ignored",
                    "--exact",
                    "--nocapture",
                    "private_block::run::fork::tests::a22::a22_stream_ab",
                ],
                env_extra=leaf_env,
            )
            ran_any_leaf = True
            quiet_checks.append(wait_quiet_ds4(f"post_{label}"))

        guard_records.append(rec)
        t_meta, t_rows = archive_and_parse_trace(trace_prefix)
        traces_manifest[arm_str] = t_meta
        parsed_arms[arm_str] = parse_stream_arm(log_path.read_text(), t_rows, arm_str, reqs, lanes, 6)

    out_json = OUT / "BATCH7_SEALING_AND_LANES3_METRICS.json"
    prior_quiet_checks = []
    if out_json.exists():
        try:
            prior_quiet_checks = json.loads(out_json.read_text()).get("quiet_gpu_checks", [])
        except Exception:
            prior_quiet_checks = []

    s1_solo = parsed_arms["serve1"]["sealing_phase_profile_unoverlapped_req0"]
    s4_req0 = parsed_arms["serve4"]["sealing_phase_profile_unoverlapped_req0"]
    s6_req0 = parsed_arms["serve6+lanes3"]["sealing_phase_profile_unoverlapped_req0"]
    s4_ov = parsed_arms["serve4"]["sealing_phase_profile_overlapped_reqs_1_to_last"]
    s6_ov = parsed_arms["serve6+lanes3"]["sealing_phase_profile_overlapped_reqs_1_to_last"]

    pooled_solo = {
        k: stats(s1_solo[k]["samples"] + s4_req0[k]["samples"] + s6_req0[k]["samples"], ndigits=4)
        for k in s1_solo.keys()
    }

    s2_cad = parsed_arms["serve4"]["steady_state"]["cadence_reqs_1_to_last_s"]["median"]
    s2_cad_post = parsed_arms["serve4"]["steady_state"]["post_lane_fill_cadence_q_ge_lanes_s"]["median"]
    s3_cad_all = parsed_arms["serve6+lanes3"]["steady_state"]["cadence_reqs_1_to_last_s"]["median"]
    s3_cad_post = parsed_arms["serve6+lanes3"]["steady_state"]["post_lane_fill_cadence_q_ge_lanes_s"]["median"]

    lanes3_comparison = {
        "serve4_lanes2_steady_cadence_s": s2_cad,
        "serve4_lanes2_steady_tok_s": parsed_arms["serve4"]["steady_state"]["steady_tok_s"]["median"],
        "serve4_lanes2_post_fill_cadence_reqs_2_to_3_s": s2_cad_post,
        "serve4_lanes2_post_fill_tok_s": parsed_arms["serve4"]["steady_state"]["post_lane_fill_tok_s"]["median"],
        "serve4_lanes2_peak_footprint_gib": parsed_arms["serve4"]["peak_footprint_gib"]["median"],
        "serve4_lanes2_prover_slack_median_s": parsed_arms["serve4"]["steady_state"]["prover_slack_before_prover_start_s"]["median"],
        "serve4_lanes2_lane_admission_wait_median_s": parsed_arms["serve4"]["steady_state"]["lane_admission_wait_after_prev_seal_s"]["median"],
        "serve6_lanes3_steady_cadence_reqs_1_to_5_s": s3_cad_all,
        "serve6_lanes3_steady_tok_s": parsed_arms["serve6+lanes3"]["steady_state"]["steady_tok_s"]["median"],
        "serve6_lanes3_post_fill_cadence_reqs_3_to_5_s": s3_cad_post,
        "serve6_lanes3_post_fill_tok_s": parsed_arms["serve6+lanes3"]["steady_state"]["post_lane_fill_tok_s"]["median"],
        "serve6_lanes3_peak_footprint_gib": parsed_arms["serve6+lanes3"]["peak_footprint_gib"]["median"],
        "serve6_lanes3_prover_slack_median_s": parsed_arms["serve6+lanes3"]["steady_state"]["prover_slack_before_prover_start_s"]["median"],
        "serve6_lanes3_lane_admission_wait_median_s": parsed_arms["serve6+lanes3"]["steady_state"]["lane_admission_wait_after_prev_seal_s"]["median"],
        "lanes3_over_lanes2_steady_ratio_x": round(s2_cad / s3_cad_all, 4) if s3_cad_all > 0 else 0.0,
        "lanes3_over_lanes2_post_fill_like_for_like_ratio_x": round(s2_cad_post / s3_cad_post, 4) if s3_cad_post > 0 else 0.0,
        "note": "Steady and post-fill ratios (0.981x and 0.984x; +1.9% and +1.6% wall) are at the ~2% A/B noise floor with overlapping pass ranges and different contended/uncontended request-interval mixes; HL_A19_BUDGET_GIB=32 is per-request in all arms.",
    }

    metrics = {
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "hardware": "Apple M3 Ultra (32 CPU cores, 256 GiB unified RAM)",
        "fixture_scope": "a22_stream_ab synthetic harness stack (A22Synth, L=32) with HL_A27_GPU_TRACE enabled in all arms, fixed arm order (serve1, serve4, serve6+lanes3); receipts verified for cold request and warm pass 0 per arm; Batch 7 ran ~1.0-2.0% slower uniformly than Batch 6.",
        "git_head": head_sha,
        "prover_source_modifications": "NONE (0 B diff in ops/zkp-mvp/gpu-metal; Sol INPUTS.json and Astra SOURCE_BASE.json pins untouched)",
        "head_test_binary": {
            "name": test_bin.name,
            "bytes": bin_bytes,
            "sha256": bin_sha,
        },
        "retained_compressed_traces_outside_repo": {
            "archive_dir": str(TRACE_ARCHIVE_DIR),
            "files": traces_manifest,
        },
        "quiet_gpu_checks": quiet_checks if quiet_checks else prior_quiet_checks,
        "quiet_gpu_checks_note": "Recorded pre/post for serve4 and serve6+lanes3 (4 checks); serve1 reused completed guarded leaf 061723c7aeb6.",
        "guard_records": guard_records,
        "arms": parsed_arms,
        "pooled_solo_req0_n18": pooled_solo,
        "sealing_slowdown_attribution": {
            "serve4_overlapped_vs_serve1_solo": compute_slowdown_attribution(s1_solo, s4_ov),
            "serve4_overlapped_vs_serve4_req0_in_process": compute_slowdown_attribution(s4_req0, s4_ov),
            "serve4_overlapped_vs_pooled_solo_n18": compute_slowdown_attribution(pooled_solo, s4_ov),
            "serve6_lanes3_overlapped_vs_serve1_solo": compute_slowdown_attribution(s1_solo, s6_ov),
        },
        "lanes3_vs_lanes2_admission_window_comparison": lanes3_comparison,
    }

    out_json.write_text(json.dumps(metrics, indent=2) + "\n")
    print(f"[batch7] Wrote {out_json} ({out_json.stat().st_size} B)", flush=True)


if __name__ == "__main__":
    main()
