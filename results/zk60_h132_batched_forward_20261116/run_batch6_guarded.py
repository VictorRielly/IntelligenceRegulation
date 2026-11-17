#!/usr/bin/env python3
"""Batch 6 Guarded Runner & Analyzer (HEAD hashline n>=5 medians for 1-block & 6-fork stream + HL_A27_GPU_TRACE GPU busy + Candidate A & E).

Strictly follows all guard & co-coordination rules:
  - Default guard poll (5.0 s, no fast-poll override)
  - Checks /tmp/HOLD before every guarded leaf
  - Checks `pgrep ds4-bench` quiet before and after every GPU timing leaf
  - 12-second polite inter-leaf gap
  - Guards leaf commands directly (never nested guards)
  - Runs Python with PYTHONDONTWRITEBYTECODE=1; cleans temporary .tsv traces from scratch
"""
from __future__ import annotations

import collections
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
HASHLINE_MANIFEST = ROOT / "ops/zkp-mvp/gpu-metal/hashline/Cargo.toml"
SCRATCH_TRACES = Path(
    os.environ.get("ZK60_TRACE_DIR", str(Path(tempfile.gettempdir()) / "zk60_batch6_traces"))
)


def check_hold() -> None:
    if Path("/tmp/HOLD").exists():
        raise SystemExit("ABORT: /tmp/HOLD exists; honoring hold immediately.")


def ds4_running() -> list[str]:
    cp = subprocess.run(["pgrep", "-fl", "ds4-bench"], capture_output=True, text=True)
    if cp.returncode != 0:
        return []
    lines = [
        ln.strip()
        for ln in cp.stdout.splitlines()
        if ln.strip() and "zk60_resource_guard.py" not in ln and "pgrep" not in ln
    ]
    return lines


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


def stats(vals: list[float]) -> dict:
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

    med = pct(0.50)
    p25 = pct(0.25)
    p75 = pct(0.75)
    return {
        "n": n,
        "median": round(med, 6),
        "iqr": round(p75 - p25, 6),
        "p25": round(p25, 6),
        "p75": round(p75, 6),
        "min": round(s[0], 6),
        "max": round(s[-1], 6),
        "mean": round(sum(s) / n, 6),
        "samples": [round(x, 6) for x in vals],
    }


def stats_ms(vals_s: list[float]) -> dict:
    st = stats([x * 1000.0 for x in vals_s])
    return {k: (round(v, 3) if isinstance(v, float) else ([round(x, 3) for x in v] if isinstance(v, list) else v)) for k, v in st.items()}


def run_guarded_leaf(
    label: str,
    cls: str,
    need_gib: float,
    cap_gib: float,
    max_secs: int,
    cmd: list[str],
    env_extra: dict[str, str] | None = None,
) -> dict:
    check_hold()
    log_path = OUT / f"{label}.log"
    done_path = OUT / f"{label}.done"
    res_path = OUT / f"{label}.guard.json"
    for p in (log_path, done_path, res_path):
        if p.exists():
            p.unlink()

    env = os.environ.copy()
    env.pop("ZK60_GUARD_POLL_SECS", None)  # Strictly default 5.0 s guard poll
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    if env_extra:
        env.update(env_extra)

    full_cmd = [
        "python3",
        "-B",
        str(GUARD),
        "run",
        "--class",
        cls,
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
        str(res_path),
        "--",
        *cmd,
    ]
    print(f"[{time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}] Launching guarded leaf {label} ...", flush=True)
    cp = subprocess.run(full_cmd, env=env)
    rec = json.loads(res_path.read_text()) if res_path.exists() else {"exit": cp.returncode}
    if done_path.exists():
        done_path.unlink()  # keep directory tidy; .guard.json + history.jsonl are retained
    print(f"[{time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}] Finished {label}: rc={cp.returncode}", flush=True)
    if cp.returncode != 0:
        tail = log_path.read_text()[-4000:] if log_path.exists() else ""
        raise RuntimeError(f"Leaf {label} failed (rc={cp.returncode}):\n{tail}")
    return rec


def load_trace_tsv(prefix: Path) -> list[dict]:
    matches = sorted(prefix.parent.glob(f"{prefix.name}.*.tsv"))
    if len(matches) != 1:
        raise RuntimeError(f"Expected exactly 1 trace TSV for {prefix}, found {matches}")
    rows = []
    with matches[0].open() as f:
        for idx, line in enumerate(f):
            if line.startswith("tag\t"):
                continue
            p = line.rstrip("\n").split("\t")
            if len(p) != 9:
                continue
            tag, detail = p[0], p[1]
            th, q = int(p[2]), int(p[3])
            begin, committed, gs, ge, done = (float(x) for x in p[4:9])
            kv = dict(re.findall(r"(\w+)=([\w.]+)", detail))
            rows.append(
                {
                    "idx": idx,
                    "tag": tag,
                    "detail": detail,
                    "kv": kv,
                    "thread": th,
                    "queue": q,
                    "begin": begin,
                    "committed": committed,
                    "gs": gs,
                    "ge": ge,
                    "done": done,
                    "gpu_dur": max(0.0, ge - gs) if (gs > 0 and ge >= gs) else 0.0,
                    "paired_rows": int(kv["rows"]) if "rows" in kv and kv["rows"].isdigit() else None,
                }
            )
    # Pair each devfold with the immediately following gather on the SAME thread (open_zk order: fold_rows_with_pads -> columns)
    by_th: dict[int, list[dict]] = collections.defaultdict(list)
    for r in rows:
        by_th[r["thread"]].append(r)
    for th, trows in by_th.items():
        pending_devfolds: list[dict] = []
        for r in trows:
            if r["tag"] == "devfold":
                pending_devfolds.append(r)
            elif r["tag"] == "gather" and r["paired_rows"] is not None:
                for df in pending_devfolds:
                    df["paired_rows"] = r["paired_rows"]
                pending_devfolds.clear()
    return rows


def gpu_busy_interval(rows: list[dict], w0: float | None = None, w1: float | None = None) -> dict:
    valid = [r for r in rows if r["gs"] > 0 and r["ge"] >= r["gs"]]
    if not valid:
        return {"window_s": 0.0, "busy_s": 0.0, "busy_pct_of_window": 0.0, "sum_spans_s": 0.0, "mean_concurrency_while_busy": 0.0, "cb_count": 0}
    lo = min(r["gs"] for r in valid) if w0 is None else w0
    hi = max(r["ge"] for r in valid) if w1 is None else w1
    clipped = [r for r in valid if r["ge"] > lo and r["gs"] < hi]
    if not clipped or hi <= lo:
        return {"window_s": max(0.0, hi - lo), "busy_s": 0.0, "busy_pct_of_window": 0.0, "sum_spans_s": 0.0, "mean_concurrency_while_busy": 0.0, "cb_count": 0}
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
    """Detects exact (A_rows, H_rows) for block commitments (rows >= 1500, A_rows < H_rows)."""
    big_commit_rows = sorted({r["paired_rows"] for r in rows if r["tag"] == "commit" and (r["paired_rows"] or 0) >= 1500})
    if len(big_commit_rows) != 2:
        raise RuntimeError(f"Expected exactly 2 block commitment row counts (>=1500), got {big_commit_rows}")
    return big_commit_rows[0], big_commit_rows[1]


def classify_cb_bucket(r: dict, a_rows: int, h_rows: int) -> str:
    t = r["tag"]
    pr = r["paired_rows"]
    if t == "wprod":
        return "wprod_witness"
    if t == "commit":
        if pr == a_rows:
            return "commit_A"
        if pr == h_rows:
            return "commit_H"
        return "commit_boundary"
    if t in ("batch", "round", "fold", "tables"):
        return "slots_sumcheck"
    if t in ("devfold", "gather"):
        if pr == a_rows:
            return "open_A"
        if pr == h_rows:
            return "open_H"
        return "open_boundary"
    return "other"


def bucket_spans_s(rows: list[dict], a_rows: int, h_rows: int, w0: float | None = None, w1: float | None = None) -> dict[str, float]:
    out: dict[str, float] = collections.defaultdict(float)
    for r in rows:
        if r["gs"] <= 0 or r["ge"] < r["gs"]:
            continue
        a = r["gs"] if w0 is None else max(r["gs"], w0)
        b = r["ge"] if w1 is None else min(r["ge"], w1)
        if b > a:
            out[classify_cb_bucket(r, a_rows, h_rows)] += b - a
    return dict(out)


def parse_one_block_7warm(m4_log: str, m4_trace_rows: list[dict], a4_log: str, a4_trace_rows: list[dict]) -> dict:
    # 1. Parse PB-TIMING blocks: 1 CPU pass + 1 Metal cold pass + 7 Metal warm passes = 9 total
    phase_re = re.compile(r"PB-TIMING (prove(?:-metal)?) \| ([^|]+?)\s+\|\s*([^|]*?)\s*\|\s*([0-9.]+)\s*\|")
    pb_passes: list[tuple[str, dict[str, float]]] = []
    cur: dict[str, float] = {}
    cur_kind = ""
    for m in phase_re.finditer(m4_log):
        kind, name, _half, sec = m.group(1), m.group(2).strip(), m.group(3).strip(), float(m.group(4))
        cur_kind = kind
        cur[name] = sec
        if name == "WALL CLOCK OF THE CALL":
            pb_passes.append((cur_kind, cur))
            cur = {}

    metal_pb = [d for k, d in pb_passes if k == "prove-metal"]
    if len(metal_pb) < 8:
        raise RuntimeError(f"Expected 1 cold + 7 warm prove-metal PB-TIMING passes, got {len(metal_pb)}")
    warm_pb_list = metal_pb[1:]  # passes 1..7 = 7 warm passes

    # 2. Parse M4-TRAINED summary lines (1 cold + 7 warm)
    m4_re = re.compile(
        r"M4-TRAINED W16R2_8B_T128_H24 cpu ([0-9.]+) s metal-(cold|warm) ([0-9.]+) s "
        r"\(prove core cpu ([0-9.]+) s metal ([0-9.]+) s; kernel compile ([0-9.]+) s, device sumcheck rounds ([0-9.]+) s.*digest cpu ([0-9a-f]+) metal ([0-9a-f]+)"
    )
    m4_matches = list(m4_re.finditer(m4_log))
    warm_m4 = [m for m in m4_matches if m.group(2) == "warm"]
    if len(warm_m4) != len(warm_pb_list):
        raise RuntimeError(f"Mismatch warm M4 lines ({len(warm_m4)}) vs warm PB-TIMING ({len(warm_pb_list)})")
    digests = {(m.group(8), m.group(9)) for m in warm_m4}

    # 3. Segment m4_trace_rows:
    # Note: m4_trained also runs `case()` + `input` search `build_accuracy` before CPU pass if HL_GPU=1 was set in env!
    # Specifically, before the CPU pass (which calls `remove_var("HL_GPU")`), line 1824 calls `build_accuracy` with initial env `HL_GPU=1`!
    # So each of the 8 Metal passes ends with `gather` (`rows == h_rows`, `open H`), and any `wprod` before pass 0's 7 `wprod` cbs is initial fixture setup!
    a_rows, h_rows = detect_ah_rows(m4_trace_rows)
    passes_rows_raw: list[list[dict]] = []
    cur_rows: list[dict] = []
    for r in m4_trace_rows:
        cur_rows.append(r)
        if r["tag"] == "gather" and r["paired_rows"] == h_rows:
            passes_rows_raw.append(cur_rows)
            cur_rows = []
    if len(passes_rows_raw) != 8 or cur_rows:
        raise RuntimeError(f"Expected 8 Metal trace passes in m4_trained, got {len(passes_rows_raw)} (leftover={len(cur_rows)})")
    # For pass 0 (cold), keep only its trailing 7 wprod cbs + prove cbs (dropping initial fixture admissibility check wprods before CPU pass)
    warm_trace_passes = passes_rows_raw[1:]  # passes 1..7 = 7 warm passes (each has 7 wprods from `let w = wit()` + prove cbs)

    # Per-warm-pass GPU & Host metrics
    prove_wall_s = [ float(m.group(5)) for m in warm_m4 ]  # LAST_CORE_NS exact nanosecond timer
    prove_pb_wall_s = [ d["WALL CLOCK OF THE CALL"] for d in warm_pb_list ]

    wit_wprod_gpu_busy_s = []
    prove_gpu_busy_s = []
    prove_gpu_spans_s = []
    commit_A_gpu_s = []
    commit_H_gpu_s = []
    slots_gpu_s = []
    open_A_gpu_s = []
    open_H_gpu_s = []

    for prows in warm_trace_passes:
        wprod_cbs = [r for r in prows if r["tag"] == "wprod"]
        prove_cbs = [r for r in prows if r["tag"] != "wprod"]
        if len(wprod_cbs) != 7:
            raise RuntimeError(f"Expected 7 wprod cbs per pass, got {len(wprod_cbs)}")
        wit_wprod_gpu_busy_s.append(gpu_busy_interval(wprod_cbs)["busy_s"])
        p_iv = gpu_busy_interval(prove_cbs)
        prove_gpu_busy_s.append(p_iv["busy_s"])
        prove_gpu_spans_s.append(p_iv["sum_spans_s"])
        bmap = bucket_spans_s(prove_cbs, a_rows, h_rows)
        commit_A_gpu_s.append(bmap.get("commit_A", 0.0))
        commit_H_gpu_s.append(bmap.get("commit_H", 0.0))
        slots_gpu_s.append(bmap.get("slots_sumcheck", 0.0))
        open_A_gpu_s.append(bmap.get("open_A", 0.0))
        open_H_gpu_s.append(bmap.get("open_H", 0.0))

    # Host components per warm pass (by subtracting exact CB GPU busy of that phase from that pass's phase wall!)
    a_prep_s = [
        d.get("A: allocate + witness planes -> committed rows", 0.0)
        + d.get("A: lookup values + the byte histogram", 0.0)
        + d.get("A: exp/act indices + their two histograms", 0.0)
        + d.get("A: mask + proximity rows (fresh randomness)", 0.0)
        for d in warm_pb_list
    ]
    commit_A_wall_s = [d.get("A: commit (pcs::commit_zk_owned: encode+Merkle, ONE call)", 0.0) for d in warm_pb_list]
    commit_A_host_s = [max(0.0, w - g) for w, g in zip(commit_A_wall_s, commit_A_gpu_s)]
    mask_M_s = [d.get("M: mask commit (zk::mask_commit, ONE call)", 0.0) for d in warm_pb_list]

    h_logup_inv_s = [d.get("H: LogUp helper inverses (six lookup domains)", 0.0) for d in warm_pb_list]
    h_exp_act_inv_s = [d.get("H: exp + activation helper inverses", 0.0) for d in warm_pb_list]
    h_tab_inv_s = [d.get("H: the three table helpers", 0.0) for d in warm_pb_list]
    h_masks_zerosum_s = [d.get("H: mask rows + the zero-sum rows", 0.0) for d in warm_pb_list]
    h_s2_drops_s = [d.get("H: release the four witness buffers (S2 drops)", 0.0) for d in warm_pb_list]
    h_inverses_all_s = [a + b + c for a, b, c in zip(h_logup_inv_s, h_exp_act_inv_s, h_tab_inv_s)]
    h_prep_with_masks_s = [inv + m for inv, m in zip(h_inverses_all_s, h_masks_zerosum_s)]

    commit_H_wall_s = [d.get("H: commit (pcs::commit_zk_owned: encode+Merkle, ONE call)", 0.0) for d in warm_pb_list]
    commit_H_host_s = [max(0.0, w - g) for w, g in zip(commit_H_wall_s, commit_H_gpu_s)]

    slots_wall_s = [sum(v for k, v in d.items() if k.startswith("slot ")) for d in warm_pb_list]
    slots_host_s = [max(0.0, w - g) for w, g in zip(slots_wall_s, slots_gpu_s)]

    open_M_wall_s = [d.get("open M (zk::mask_open, ONE call)", 0.0) for d in warm_pb_list]
    open_A_wall_s = [d.get("open A (schedule audit + pcs::open_zk)", 0.0) for d in warm_pb_list]
    open_H_wall_s = [d.get("open H (schedule audit + pcs::open_zk)", 0.0) for d in warm_pb_list]
    open_A_host_s = [max(0.0, w - g) for w, g in zip(open_A_wall_s, open_A_gpu_s)]
    open_H_host_s = [max(0.0, w - g) for w, g in zip(open_H_wall_s, open_H_gpu_s)]

    prove_host_s = [max(0.0, w - g) for w, g in zip(prove_wall_s, prove_gpu_busy_s)]
    prove_gpu_share_pct = [100.0 * g / w for w, g in zip(prove_wall_s, prove_gpu_busy_s)]

    # Candidate A gross removal per block (helper inverses + H masks + commit H host & GPU + open H host & GPU; excluding S2 buffer drops):
    cand_A_removed_total_s = [
        inv + hm + chw + ohw
        for inv, hm, chw, ohw in zip(h_inverses_all_s, h_masks_zerosum_s, commit_H_wall_s, open_H_wall_s)
    ]
    cand_A_removed_gpu_s = [chg + ohg for chg, ohg in zip(commit_H_gpu_s, open_H_gpu_s)]
    cand_A_removed_host_s = [tot - g for tot, g in zip(cand_A_removed_total_s, cand_A_removed_gpu_s)]

    # 4. Parse A4 30-rep witness log & trace (note: witness_speed_tests uses sh.hidden = 14336 BASE shape, 7 cbs per block)
    a4_lines = [ln.strip() for ln in a4_log.splitlines() if ln.strip().startswith("A4 ")]
    # Group A4 wprod cbs in chunks of 7 to get exact per-block GPU busy across all mapped/unmapped device blocks!
    a4_wprod = [r for r in a4_trace_rows if r["tag"] == "wprod"]
    a4_blocks_gpu_ms = []
    if len(a4_wprod) >= 210 and len(a4_wprod) % 7 == 0:
        # Last 30 blocks of 7 cbs are the mapped Simd2x4 30-rep loop (let's verify and also record all blocks)
        last30 = a4_wprod[-210:]
        for i in range(0, 210, 7):
            a4_blocks_gpu_ms.append(gpu_busy_interval(last30[i : i + 7])["busy_s"] * 1000.0)

    return {
        "n_warm_passes": len(warm_m4),
        "cpu_and_metal_digests_verified": [list(x) for x in sorted(digests)],
        "prove_core_wall_ms": stats_ms(prove_wall_s),
        "prove_core_pb_sum_wall_ms": stats_ms(prove_pb_wall_s),
        "prove_core_gpu_busy_from_cb_timestamps_ms": stats_ms(prove_gpu_busy_s),
        "prove_core_gpu_summed_spans_ms": stats_ms(prove_gpu_spans_s),
        "prove_core_host_between_cbs_ms": stats_ms(prove_host_s),
        "prove_core_gpu_busy_share_pct": stats(prove_gpu_share_pct),
        "wit_build_accuracy_7_wprod_gpu_busy_ms": stats_ms(wit_wprod_gpu_busy_s),
        "phases_ms": {
            "A_prep_planes_hist_masks_host_ms": stats_ms(a_prep_s),
            "A_commit_total_wall_ms": stats_ms(commit_A_wall_s),
            "A_commit_gpu_cb_ms": stats_ms(commit_A_gpu_s),
            "A_commit_host_setup_and_upper_merkle_ms": stats_ms(commit_A_host_s),
            "M_mask_commit_host_ms": stats_ms(mask_M_s),
            "H_logup_6dom_helper_inverses_host_ms": stats_ms(h_logup_inv_s),
            "H_exp_act_helper_inverses_host_ms": stats_ms(h_exp_act_inv_s),
            "H_three_table_helpers_host_ms": stats_ms(h_tab_inv_s),
            "H_all_helper_inverses_host_ms": stats_ms(h_inverses_all_s),
            "H_masks_and_zerosum_rows_host_ms": stats_ms(h_masks_zerosum_s),
            "H_s2_witness_buffer_drops_host_ms": stats_ms(h_s2_drops_s),
            "H_commit_total_wall_ms": stats_ms(commit_H_wall_s),
            "H_commit_gpu_cb_ms": stats_ms(commit_H_gpu_s),
            "H_commit_host_setup_and_upper_merkle_ms": stats_ms(commit_H_host_s),
            "slots_23_total_wall_ms": stats_ms(slots_wall_s),
            "slots_23_gpu_cb_ms": stats_ms(slots_gpu_s),
            "slots_23_host_ms": stats_ms(slots_host_s),
            "open_M_host_ms": stats_ms(open_M_wall_s),
            "open_A_total_wall_ms": stats_ms(open_A_wall_s),
            "open_A_gpu_gather_cb_ms": stats_ms(open_A_gpu_s),  # default host fold (~5.3 ms); GPU CB is gather unless HL_METAL_DEVICE_FOLD=1
            "open_A_host_fold_audit_and_merkle_ms": stats_ms(open_A_host_s),
            "open_H_total_wall_ms": stats_ms(open_H_wall_s),
            "open_H_gpu_gather_cb_ms": stats_ms(open_H_gpu_s),  # default host fold (~5.9 ms); GPU CB is gather unless HL_METAL_DEVICE_FOLD=1
            "open_H_host_fold_audit_and_merkle_ms": stats_ms(open_H_host_s),
        },
        "candidate_A_gross_removed_one_block_ms": {
            "note": (
                "Gross work removed if H is retired (helper inverses + H masks + commit H on host & GPU + open H on host & GPU; "
                "excludes S2 witness buffer drops which still occur, and BEFORE subtracting masked LogUp-GKR rounds + extra M mask rows that Candidate A adds)."
            ),
            "helper_inverses_host_ms": stats_ms(h_inverses_all_s),
            "h_masks_host_ms": stats_ms(h_masks_zerosum_s),
            "commit_H_gpu_ms": stats_ms(commit_H_gpu_s),
            "commit_H_host_ms": stats_ms(commit_H_host_s),
            "open_H_gpu_ms": stats_ms(open_H_gpu_s),
            "open_H_host_ms": stats_ms(open_H_host_s),
            "total_removed_wall_ms": stats_ms(cand_A_removed_total_s),
            "total_removed_gpu_ms": stats_ms(cand_A_removed_gpu_s),
            "total_removed_host_ms": stats_ms(cand_A_removed_host_s),
            "gross_share_of_prove_core_wall_pct": stats([100.0 * r / w for r, w in zip(cand_A_removed_total_s, prove_wall_s)]),
            "gross_share_of_prove_core_gpu_busy_pct": stats([100.0 * rg / g for rg, g in zip(cand_A_removed_gpu_s, prove_gpu_busy_s)]),
        },
        "head_a4_witness_30reps": {
            "raw_lines": a4_lines,
            "last30_blocks_wprod_gpu_busy_ms": stats(a4_blocks_gpu_ms) if a4_blocks_gpu_ms else {},
            "total_wprod_cbs_recorded": len(a4_wprod),
        },
    }


def split_stream_trace_into_passes(rows: list[dict], expected_passes_reqs: list[int], a_rows: int, h_rows: int) -> list[list[dict]]:
    """Splits an a22_stream_ab trace into passes where pass i serves `expected_passes_reqs[i]` 32-layer requests.
    First strips A18Fix::new's initial fixture-building wprod cbs (before Resident::start's >=0.3s CPU hashing gap).
    """
    # Strip A18Fix::new setup wprods: walk leading wprod cbs until the Resident::start gap before cold's 224 wprods!
    total_reqs = sum(expected_passes_reqs)
    # Count total commit_H cbs across the whole trace: must equal 32 * total_reqs!
    total_ch = sum(1 for r in rows if r["tag"] == "commit" and r["paired_rows"] == h_rows)
    if total_ch != 32 * total_reqs:
        raise RuntimeError(f"Expected {32 * total_reqs} commit_H cbs across stream trace, got {total_ch}")

    # Find index where cold request begins: A18Fix::new runs >=224 wprods (32 layers + admissibility retries), then Resident::start (~0.5-0.9s CPU gap),
    # then cold request runs 224 wprods before its first boundary/block commit!
    first_non_wprod = next(i for i, r in enumerate(rows) if r["tag"] != "wprod")
    if first_non_wprod < 224:
        raise RuntimeError(f"Expected at least 224 wprods before first commit, got {first_non_wprod}")
    stream_start = first_non_wprod - 224
    rows = rows[stream_start:]

    if len(rows) % total_reqs == 0:
        cbs_per_req = len(rows) // total_reqs
        passes = []
        cur = 0
        for reqs in expected_passes_reqs:
            cnt = reqs * cbs_per_req
            chunk = rows[cur : cur + cnt]
            ch = sum(1 for r in chunk if r["tag"] == "commit" and r["paired_rows"] == h_rows)
            if ch == 32 * reqs:
                passes.append(chunk)
                cur += cnt
            else:
                passes = []
                break
        if passes and cur == len(rows):
            return passes

    # Exact state-machine fallback using inter-pass receipt_write / verify gap after seeing 32*reqs open_H gathers
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
                if gap > 0.12 and rows[j + 1]["tag"] == "wprod":
                    best_split = j + 1
                    break
        if best_split is None:
            raise RuntimeError(f"Could not find clean pass boundary from index {start} for reqs={reqs}")
        passes.append(rows[start:best_split])
        start = best_split
    if start != len(rows):
        raise RuntimeError(f"Leftover trace rows {len(rows) - start}")
    return passes


def parse_a22_stream(log_text: str, trace_rows: list[dict], arm_label: str, reqs_per_pass: int, n_passes: int) -> dict:
    # Parse A22-AB REQ lines
    req_re = re.compile(
        r"A22-AB REQ \S+ L32 N6 \[" + re.escape(arm_label) + r"\] pass (\d+) request (\d+): "
        r"arrived ([0-9.]+), sealing turn ([0-9.]+), sealing side done ([0-9.]+) \(sealing pass ([0-9.]+) s\), "
        r"prover ([0-9.]+)-([0-9.]+) \(waited ([0-9.]+) s; prove call ([0-9.]+) s: "
        r"preflight ([0-9.]+), commit ([0-9.]+), forks ([0-9.]+), join ([0-9.]+)\), "
        r"receipt write ([0-9.]+) s \([^)]+\), result ([0-9.]+);"
    )
    stream_re = re.compile(
        r"A22-AB STREAM \S+ L32 N6 \[" + re.escape(arm_label) + r"\] pass (\d+): "
        r"(\d+) requests in ([0-9.]+) s \([^)]+\); steady ([0-9.NaN]+) tok/s; amortized ([0-9.]+) tok/s;.*"
        r"footprint start ([0-9.]+) GiB, peak ([0-9.]+) GiB, end ([0-9.]+) GiB; user ([0-9.]+) s \+ sys ([0-9.]+) s"
    )

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
                "waited_s": float(m.group(9)),
                "prove_call_s": float(m.group(10)),
                "preflight_s": float(m.group(11)),
                "commit_s": float(m.group(12)),
                "forks_s": float(m.group(13)),
                "join_s": float(m.group(14)),
                "write_s": float(m.group(15)),
                "done_s": float(m.group(16)),
            }
        )

    streams_by_pass: dict[int, dict] = {}
    for m in stream_re.finditer(log_text):
        p = int(m.group(1))
        st_val = float(m.group(4)) if m.group(4) != "NaN" else 0.0
        streams_by_pass[p] = {
            "wall_s": float(m.group(3)),
            "steady_tok_s": st_val,
            "amortized_tok_s": float(m.group(5)),
            "peak_footprint_gib": float(m.group(7)),
            "cpu_user_s": float(m.group(9)),
            "cpu_sys_s": float(m.group(10)),
        }

    if len(streams_by_pass) != n_passes:
        raise RuntimeError(f"Expected {n_passes} passes for {arm_label}, got {len(streams_by_pass)}")

    # Split trace into [1 cold request] + [reqs_per_pass] * n_passes
    a_rows, h_rows = detect_ah_rows(trace_rows)
    expected = [1] + [reqs_per_pass] * n_passes
    pass_traces = split_stream_trace_into_passes(trace_rows, expected, a_rows, h_rows)
    warm_traces = pass_traces[1:]

    # Per-pass aggregates (divided by reqs_per_pass for per-request amortized; plus steady-state window for reqs_per_pass >= 4!)
    amort_req_wall_s = []
    steady_req_cadence_s = []
    steady_tok_s = []
    amort_tok_s = []

    seal_pass_s = []
    prove_call_s = []
    preflight_s = []
    bnd_commit_s = []
    forks_s = []
    join_s = []
    write_s = []
    uncontended_last_forks_s = []
    contended_mid_forks_s = []

    gpu_busy_per_req_s = []
    gpu_spans_per_req_s = []
    gpu_busy_pct_of_stream_wall = []
    gpu_mean_conc = []

    wprod_gpu_per_req_s = []
    commit_A_gpu_per_req_s = []
    commit_H_gpu_per_req_s = []
    commit_bnd_gpu_per_req_s = []
    slots_gpu_per_req_s = []
    open_A_gpu_per_req_s = []
    open_H_gpu_per_req_s = []
    open_bnd_gpu_per_req_s = []

    steady_window_gpu_busy_per_req_s = []
    steady_window_gpu_busy_pct = []

    for p in range(n_passes):
        st = streams_by_pass[p]
        rlist = sorted(reqs_by_pass[p], key=lambda x: x["q"])
        trows = warm_traces[p]

        amort_req_wall_s.append(st["wall_s"] / reqs_per_pass)
        amort_tok_s.append(st["amortized_tok_s"])
        if reqs_per_pass > 1:
            steady_req_cadence_s.append((rlist[-1]["done_s"] - rlist[0]["done_s"]) / (reqs_per_pass - 1))
            steady_tok_s.append(st["steady_tok_s"])

        seal_pass_s.append(sum(x["seal_s"] for x in rlist) / reqs_per_pass)
        prove_call_s.append(sum(x["prove_call_s"] for x in rlist) / reqs_per_pass)
        preflight_s.append(sum(x["preflight_s"] for x in rlist) / reqs_per_pass)
        bnd_commit_s.append(sum(x["commit_s"] for x in rlist) / reqs_per_pass)
        forks_s.append(sum(x["forks_s"] for x in rlist) / reqs_per_pass)
        join_s.append(sum(x["join_s"] for x in rlist) / reqs_per_pass)
        write_s.append(sum(x["write_s"] for x in rlist) / reqs_per_pass)
        if reqs_per_pass >= 4:
            contended_mid_forks_s.append((rlist[1]["forks_s"] + rlist[2]["forks_s"]) / 2.0)
            uncontended_last_forks_s.append(rlist[3]["forks_s"])

        # Anchor pass t=0 in host_time_s(): last GPU cb (`done`) of request (R-1)'s `join` ends right at `rlist[-1]["prover_end"]`!
        last_cb_done = max(r["done"] for r in trows)
        t0_host = last_cb_done - rlist[-1]["prover_end"]
        w0_pass = min(r["gs"] for r in trows if r["gs"] > 0)
        w1_pass = t0_host + st["wall_s"]

        iv = gpu_busy_interval(trows, w0=w0_pass, w1=max(w1_pass, max(r["ge"] for r in trows)))
        gpu_busy_per_req_s.append(iv["busy_s"] / reqs_per_pass)
        gpu_spans_per_req_s.append(iv["sum_spans_s"] / reqs_per_pass)
        gpu_busy_pct_of_stream_wall.append(100.0 * iv["busy_s"] / st["wall_s"])
        gpu_mean_conc.append(iv["mean_concurrency_while_busy"])

        bmap = bucket_spans_s(trows, a_rows, h_rows)
        wprod_gpu_per_req_s.append(bmap.get("wprod_witness", 0.0) / reqs_per_pass)
        commit_A_gpu_per_req_s.append(bmap.get("commit_A", 0.0) / reqs_per_pass)
        commit_H_gpu_per_req_s.append(bmap.get("commit_H", 0.0) / reqs_per_pass)
        commit_bnd_gpu_per_req_s.append(bmap.get("commit_boundary", 0.0) / reqs_per_pass)
        slots_gpu_per_req_s.append(bmap.get("slots_sumcheck", 0.0) / reqs_per_pass)
        open_A_gpu_per_req_s.append(bmap.get("open_A", 0.0) / reqs_per_pass)
        open_H_gpu_per_req_s.append(bmap.get("open_H", 0.0) / reqs_per_pass)
        open_bnd_gpu_per_req_s.append(bmap.get("open_boundary", 0.0) / reqs_per_pass)

        if reqs_per_pass > 1:
            sw0 = t0_host + rlist[0]["done_s"]
            sw1 = t0_host + rlist[-1]["done_s"]
            siv = gpu_busy_interval(trows, w0=sw0, w1=sw1)
            steady_window_gpu_busy_per_req_s.append(siv["busy_s"] / (reqs_per_pass - 1))
            steady_window_gpu_busy_pct.append(siv["busy_pct_of_window"])

    out = {
        "arm": arm_label,
        "requests_per_pass": reqs_per_pass,
        "n_warm_passes": n_passes,
        "amortized_per_request_wall_s": stats(amort_req_wall_s),
        "amortized_tok_s": stats(amort_tok_s),
        "per_request_host_phases_s": {
            "sealing_pass_witness_chain_s": stats(seal_pass_s),
            "prove_call_total_s": stats(prove_call_s),
            "preflight_s": stats(preflight_s),
            "boundary_commit_33_s": stats(bnd_commit_s),
            "forks_32_blocks_6_workers_s": stats(forks_s),
            "join_33_openings_s": stats(join_s),
            "receipt_write_s": stats(write_s),
        },
        "per_request_gpu_from_cb_timestamps_s": {
            "gpu_busy_union_s": stats(gpu_busy_per_req_s),
            "gpu_summed_spans_s": stats(gpu_spans_per_req_s),
            "gpu_busy_pct_of_pass_wall": stats(gpu_busy_pct_of_stream_wall),
            "mean_concurrent_cbs_while_busy": stats(gpu_mean_conc),
            "by_bucket_summed_spans_s": {
                "wprod_witness_224_cbs_s": stats(wprod_gpu_per_req_s),
                "commit_A_32_cbs_s": stats(commit_A_gpu_per_req_s),
                "commit_H_32_cbs_s": stats(commit_H_gpu_per_req_s),
                "commit_boundary_33_cbs_s": stats(commit_bnd_gpu_per_req_s),
                "slots_sumcheck_s": stats(slots_gpu_per_req_s),
                "open_A_32_blocks_s": stats(open_A_gpu_per_req_s),
                "open_H_32_blocks_s": stats(open_H_gpu_per_req_s),
                "open_boundary_33_s": stats(open_bnd_gpu_per_req_s),
            },
        },
    }
    if reqs_per_pass > 1:
        # Check how many steady-state requests (q >= 1) had prover wait > 0 vs sealing finishing BEFORE prior prover ended!
        prover_waited_on_seal = [
            max(0.0, r["seal_done"] - rlist_p[r["q"] - 1]["prover_end"])
            for p_idx, rlist_p in reqs_by_pass.items()
            for r in sorted(rlist_p, key=lambda x: x["q"])
            if r["q"] >= 1
        ]
        out["steady_state_cadence"] = {
            "per_request_cadence_s": stats(steady_req_cadence_s),
            "steady_tok_s": stats(steady_tok_s),
            "steady_window_gpu_busy_union_per_req_s": stats(steady_window_gpu_busy_per_req_s),
            "steady_window_gpu_busy_pct_of_wall": stats(steady_window_gpu_busy_pct),
            "witness_unhidden_critical_path_wait_s": stats(prover_waited_on_seal),
            "forks_contended_with_next_sealing_req1_2_s": stats(contended_mid_forks_s),
            "forks_uncontended_last_req3_s": stats(uncontended_last_forks_s),
            "sealing_overlap_contention_on_forks_s": stats([c - u for c, u in zip(contended_mid_forks_s, uncontended_last_forks_s)]),
        }
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    if SCRATCH_TRACES.exists():
        shutil.rmtree(SCRATCH_TRACES)
    SCRATCH_TRACES.mkdir(parents=True, exist_ok=True)

    head_sha = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip()
    gpu_metal_dirty = subprocess.check_output(
        ["git", "-C", str(ROOT), "status", "--short", "ops/zkp-mvp/gpu-metal/"], text=True
    ).strip()

    # Leaf 1: Build hashline test binary freshly from HEAD
    rec_build = run_guarded_leaf(
        label="agy-batch6-head-build",
        cls="build",
        need_gib=8,
        cap_gib=14,
        max_secs=600,
        cmd=[
            "/opt/homebrew/bin/cargo",
            "test",
            "--release",
            "--offline",
            "--locked",
            "-j",
            "2",
            "--features",
            "gpu-metal",
            "--manifest-path",
            str(HASHLINE_MANIFEST),
            "--lib",
            "--no-run",
            "--message-format=json",
        ],
    )
    build_log = (OUT / "agy-batch6-head-build.log").read_text()
    test_bin: Path | None = None
    for ln in build_log.splitlines():
        if not ln.startswith("{"):
            continue
        try:
            obj = json.loads(ln)
        except json.JSONDecodeError:
            continue
        if (
            obj.get("reason") == "compiler-artifact"
            and obj.get("target", {}).get("name") == "hashline"
            and "lib" in obj.get("target", {}).get("kind", [])
            and obj.get("profile", {}).get("test") is True
            and obj.get("executable")
        ):
            test_bin = Path(obj["executable"])
    if test_bin is None or not test_bin.exists():
        raise RuntimeError("Could not locate freshly built HEAD hashline lib test binary!")

    bin_sha256 = hashlib.sha256(test_bin.read_bytes()).hexdigest()
    bin_stat = test_bin.stat()
    print(f"[HEAD BINARY] {test_bin} size={bin_stat.st_size} sha256={bin_sha256}", flush=True)

    print("Sleeping 12s polite inter-leaf gap...", flush=True)
    time.sleep(12)

    # Leaf 2: 1-Block HEAD profile (7 warm passes + A4 30 reps) with HL_A27_GPU_TRACE
    q_1blk_pre = wait_quiet_ds4("leaf2_1blk_pre")
    p_1blk = SCRATCH_TRACES / "b6_1blk"
    p_a4 = SCRATCH_TRACES / "b6_a4"
    log_m4 = OUT / "batch6_1block_m4_7warm.log"
    log_a4 = OUT / "batch6_1block_a4_30reps.log"
    leaf2_sh = (
        f"set -e\n"
        f"env HL_GPU=1 HL_GPU_REQUIRED=1 HL_PB_ORACLE=0 HL_PB_TIMING=1 HL_METAL_TIMING=0 "
        f"HL_M4_PHASES=1 HL_M4_WARM_PASSES=7 HL_M4_PROFILES=W16R2_8B_T128_H24 HL_A27_GPU_TRACE={p_1blk} "
        f"{test_bin} private_block::slot_ir::accuracy::tests::m4_trained_accuracy_block_cpu_and_metal_digests_and_times "
        f"--ignored --exact --nocapture --test-threads=1 > {log_m4} 2>&1\n"
        f"env HL_GPU=1 HL_GPU_REQUIRED=1 HL_A4_REPS=30 HL_A27_GPU_TRACE={p_a4} "
        f"{test_bin} private_block::witness_speed_tests::a4::a4_witness_time_per_block_cpu_against_the_device "
        f"--ignored --exact --nocapture --test-threads=1 > {log_a4} 2>&1\n"
    )
    rec_1blk = run_guarded_leaf(
        label="agy-batch6-head-1block",
        cls="gpu",
        need_gib=14,
        cap_gib=28,
        max_secs=900,
        cmd=["/bin/zsh", "-c", leaf2_sh],
    )
    q_1blk_post = {"tag": "leaf2_1blk_post", "quiet": len(ds4_running()) == 0, "active_ds4": ds4_running()}

    print("Sleeping 12s polite inter-leaf gap...", flush=True)
    time.sleep(12)

    # Leaf 3: 6-Fork Stream Request HEAD profile (serve1 x 6 warm passes + serve4 x 6 warm passes) with HL_A27_GPU_TRACE
    q_stream_pre = wait_quiet_ds4("leaf3_stream_pre")
    p_s1 = SCRATCH_TRACES / "b6_serve1"
    p_s4 = SCRATCH_TRACES / "b6_serve4"
    log_s1 = OUT / "batch6_stream_serve1_6warm.log"
    log_s4 = OUT / "batch6_stream_serve4_6warm.log"
    common_stream_env = (
        "HL_GPU=1 HL_GPU_REQUIRED=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 "
        "HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_A19_BUDGET_GIB=32"
    )
    leaf3_sh = (
        f"set -e\n"
        f"env {common_stream_env} HL_A22_AB_PASSES=6 HL_A22_AB=serve1 HL_A27_GPU_TRACE={p_s1} "
        f"{test_bin} private_block::run::fork::tests::a22::a22_stream_ab "
        f"--ignored --exact --nocapture --test-threads=1 > {log_s1} 2>&1\n"
        f"env {common_stream_env} HL_A22_AB_PASSES=6 HL_A22_AB=serve4 HL_A27_GPU_TRACE={p_s4} "
        f"{test_bin} private_block::run::fork::tests::a22::a22_stream_ab "
        f"--ignored --exact --nocapture --test-threads=1 > {log_s4} 2>&1\n"
    )
    rec_stream = run_guarded_leaf(
        label="agy-batch6-head-stream",
        cls="gpu",
        need_gib=52,
        cap_gib=68,
        max_secs=1200,
        cmd=["/bin/zsh", "-c", leaf3_sh],
    )
    q_stream_post = {"tag": "leaf3_stream_post", "quiet": len(ds4_running()) == 0, "active_ds4": ds4_running()}

    # Parse all traces and logs
    one_blk = parse_one_block_7warm(
        log_m4.read_text(),
        load_trace_tsv(p_1blk),
        log_a4.read_text(),
        load_trace_tsv(p_a4),
    )
    serve1 = parse_a22_stream(log_s1.read_text(), load_trace_tsv(p_s1), "serve1", 1, 6)
    serve4 = parse_a22_stream(log_s4.read_text(), load_trace_tsv(p_s4), "serve4", 4, 6)

    # Candidate A stream-level expected ceiling calculation:
    # In serve4 steady state, cadence is set by prove_call (~forks + commit + join) + prover handoff/write.
    # Across 32 blocks on 6 fork workers:
    # - Direct GPU work removed per 32-block request = commit_H_32_cbs + open_H_32_blocks (measured directly in stream trace!)
    # - Host work removed across 32 blocks (summed over 6 fork threads) = 32 * (helper_inverses + H_masks + commit_H_host + open_H_host);
    #   divided by 6 workers gives its uncontended wall equivalent, or scaled by forks_wall / (32 * solo_prove_core / 6) under 6-fork contention!
    s4_cad_med = serve4["steady_state_cadence"]["per_request_cadence_s"]["median"]
    s4_forks_med = serve4["per_request_host_phases_s"]["forks_32_blocks_6_workers_s"]["median"]
    s4_gpu_busy_med = serve4["steady_state_cadence"]["steady_window_gpu_busy_union_per_req_s"]["median"]
    s4_commit_h_gpu = serve4["per_request_gpu_from_cb_timestamps_s"]["by_bucket_summed_spans_s"]["commit_H_32_cbs_s"]["median"]
    s4_open_h_gpu = serve4["per_request_gpu_from_cb_timestamps_s"]["by_bucket_summed_spans_s"]["open_H_32_blocks_s"]["median"]
    s4_h_gpu_spans = s4_commit_h_gpu + s4_open_h_gpu
    s4_all_prove_gpu_spans = (
        serve4["per_request_gpu_from_cb_timestamps_s"]["gpu_summed_spans_s"]["median"]
        - serve4["per_request_gpu_from_cb_timestamps_s"]["by_bucket_summed_spans_s"]["wprod_witness_224_cbs_s"]["median"]
    )

    solo_prove_med_s = one_blk["prove_core_wall_ms"]["median"] / 1000.0
    solo_cand_a_rem_s = one_blk["candidate_A_gross_removed_one_block_ms"]["total_removed_wall_ms"]["median"] / 1000.0
    solo_cand_a_frac = solo_cand_a_rem_s / solo_prove_med_s if solo_prove_med_s > 0 else 0.0
    est_forks_gross_saved_s = s4_forks_med * solo_cand_a_frac

    cand_a_stream_summary = {
        "serve4_steady_cadence_median_s": round(s4_cad_med, 4),
        "serve4_forks_wall_median_s": round(s4_forks_med, 4),
        "serve4_steady_gpu_busy_union_per_req_s": round(s4_gpu_busy_med, 4),
        "h_gpu_summed_spans_per_req_s": {
            "commit_H_32_cbs_s": round(s4_commit_h_gpu, 4),
            "open_H_32_blocks_s": round(s4_open_h_gpu, 4),
            "total_H_gpu_spans_s": round(s4_h_gpu_spans, 4),
            "share_of_non_witness_gpu_spans_pct": round(100.0 * s4_h_gpu_spans / max(1e-9, s4_all_prove_gpu_spans), 2),
        },
        "one_block_gross_removed_fraction_of_prove_core": round(solo_cand_a_frac, 4),
        "proportional_forks_gross_wall_saved_s": round(est_forks_gross_saved_s, 4),
        "gross_ceiling_speedup_on_serve4_cadence_before_gkr_cost_x": round(
            s4_cad_med / max(1e-9, s4_cad_med - est_forks_gross_saved_s), 3
        ),
        "note": (
            "Gross upper bound if H is deleted for free (before adding masked LogUp-GKR rounds and extra M mask rows, "
            "and noting that if forks shrinks below ~3.55 s, the overlapped ~3.55 s witness sealing pass becomes the new stream cadence floor unless witness host work is also cut)."
        ),
    }

    summary = {
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "git_head": head_sha,
        "ops_zkp_mvp_gpu_metal_git_status": gpu_metal_dirty,
        "head_test_binary": {
            "path": str(test_bin),
            "size_bytes": bin_stat.st_size,
            "mtime_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(bin_stat.st_mtime)),
            "sha256": bin_sha256,
        },
        "quiet_gpu_checks": {
            "leaf2_1blk_pre": q_1blk_pre,
            "leaf2_1blk_post": q_1blk_post,
            "leaf3_stream_pre": q_stream_pre,
            "leaf3_stream_post": q_stream_post,
        },
        "guard_records": {
            "leaf1_build": rec_build,
            "leaf2_one_block": rec_1blk,
            "leaf3_stream": rec_stream,
        },
        "item1_one_block_w16r2_8b_t128_7warm": one_blk,
        "item1_six_fork_stream_serve1_solo_6warm": serve1,
        "item1_six_fork_stream_serve4_pipelined_6warm": serve4,
        "item1_candidate_A_stream_expected_gain_ceiling": cand_a_stream_summary,
        "item2_candidate_E_fold": (
            "No exact-integer fold kernel exists in the repository (microbench_metal_gpu.mm T1 was an inexact FP32 mock already withdrawn, "
            "and metal_int_gemm.mm / metal_batched_llama8b.mm implement exact GEMMs only); Candidate E's fold half is dropped."
        ),
    }

    # Clean up temporary build log (large cargo JSON) and scratch TSV traces so 0 B scratch bloat remains!
    build_json_log = OUT / "agy-batch6-head-build.log"
    if build_json_log.exists():
        # Keep only the last 30 lines of build summary so the repo stays lightweight
        lines = build_json_log.read_text().splitlines()
        build_json_log.write_text("\n".join(lines[-30:]) + "\n")
    shutil.rmtree(SCRATCH_TRACES, ignore_errors=True)

    out_json = OUT / "BATCH6_HEAD_PROFILE_METRICS.json"
    out_json.write_text(json.dumps(summary, indent=2) + "\n")
    print(f"[BATCH 6 COMPLETE] Wrote {out_json}", flush=True)


if __name__ == "__main__":
    main()
