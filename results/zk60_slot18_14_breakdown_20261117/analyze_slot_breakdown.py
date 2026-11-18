#!/usr/bin/env python3
"""Parse externalized `HL_A27_GPU_TRACE` `.tsv.gz` files and census logs for slots 18 & 14."""

from __future__ import annotations

import gzip
import json
import pathlib
import re
import statistics
from collections import defaultdict
from typing import Dict, List, Tuple

REPO = pathlib.Path("/Users/victorrielly/IntelligenceRegulation")
OUT_DIR = REPO / "results/zk60_slot18_14_breakdown_20261117"
RAW_DIR = OUT_DIR / "raw"
EXT_DIR = pathlib.Path("/Users/victorrielly/zk60-artifacts/slot18_14_traces_20261117")


def median_iqr(vals: List[float]) -> Tuple[float, float, float, float, float]:
    if not vals:
        return (0.0, 0.0, 0.0, 0.0, 0.0)
    s = sorted(vals)
    med = statistics.median(s)
    if len(s) >= 4:
        q = statistics.quantiles(s, n=4, method="inclusive")
        p25, p75 = q[0], q[2]
    else:
        p25, p75 = s[0], s[-1]
    return (med, p25, p75, s[0], s[-1])


def parse_census(log_path: pathlib.Path) -> Dict[int, Dict[str, object]]:
    pat = re.compile(
        r"A27-CENSUS (\S+) slot (\d+) \((.+)\) cube 2\^(\d+) ext (\d+) tables (\d+) "
        r"\(base (\d+)\) nodes (\d+) \(affine (\d+), (\d+) terms\) terms (\d+) "
        r"degree (\d+) attained (\d+) coefs (\d+) \| later-round body products (\d+) "
        r"\(f2_mul (\d+), f2_mulb (\d+), gl_mul (\d+)\); line values ext (\d+) base (\d+)"
    )
    out: Dict[int, Dict[str, object]] = {}
    for line in log_path.read_text().splitlines():
        m = pat.search(line)
        if not m:
            continue
        slot = int(m.group(2))
        out[slot] = {
            "profile": m.group(1),
            "slot": slot,
            "name": m.group(3),
            "cube_log": int(m.group(4)),
            "ext": int(m.group(5)),
            "tables": int(m.group(6)),
            "base_tables": int(m.group(7)),
            "nodes": int(m.group(8)),
            "affine_nodes": int(m.group(9)),
            "affine_terms": int(m.group(10)),
            "terms": int(m.group(11)),
            "degree": int(m.group(12)),
            "attained_degree": int(m.group(13)),
            "coefs": int(m.group(14)),
            "later_body_prods": int(m.group(15)),
            "f2_mul": int(m.group(16)),
            "f2_mulb": int(m.group(17)),
            "gl_mul": int(m.group(18)),
            "ln_ext": int(m.group(19)),
            "ln_base": int(m.group(20)),
        }
    return out


def parse_m4_summary(log_path: pathlib.Path) -> List[Dict[str, object]]:
    pat = re.compile(
        r"M4-TRAINED (\S+) cpu ([\d.]+) s metal-(\w+) ([\d.]+) s "
        r"\(prove core cpu ([\d.]+) s metal ([\d.]+) s; kernel compile ([\d.]+) s, "
        r"device sumcheck rounds ([\d.]+) s; (\d+) slots without a matching IR; "
        r"buffer pool (\d+) reused / (\d+) new\) digest cpu ([0-9a-f]+) metal ([0-9a-f]+)"
    )
    rows = []
    for line in log_path.read_text().splitlines():
        m = pat.search(line)
        if m:
            rows.append(
                {
                    "profile": m.group(1),
                    "pass_kind": m.group(3),
                    "cpu_s": float(m.group(2)),
                    "metal_s": float(m.group(4)),
                    "cpu_core_s": float(m.group(5)),
                    "metal_core_s": float(m.group(6)),
                    "compile_s": float(m.group(7)),
                    "dev_sc_s": float(m.group(8)),
                    "cpu_digest": m.group(12),
                    "metal_digest": m.group(13),
                }
            )
    return rows


def parse_trace_passes(gz_path: pathlib.Path) -> List[List[Dict[str, object]]]:
    with gzip.open(gz_path, "rt") as f:
        lines = [ln.rstrip("\n") for ln in f if ln.strip()]
    if not lines:
        return []
    header = lines[0].split("\t")
    records = []
    for ln in lines[1:]:
        parts = ln.split("\t")
        if len(parts) < 9:
            continue
        tag, detail, th, queue, begin, committed, gpu_start, gpu_end, done = parts[:9]
        gs = float(gpu_start)
        ge = float(gpu_end)
        dur_ms = (ge - gs) * 1000.0 if (ge > gs and gs > 0.0) else (float(done) - float(committed)) * 1000.0
        host_wait_ms = (float(done) - float(begin)) * 1000.0
        records.append(
            {
                "tag": tag,
                "detail": detail,
                "gpu_ms": dur_ms,
                "host_ms": host_wait_ms,
                "gpu_start": gs,
                "gpu_end": ge,
            }
        )

    # Split passes at each A-commitment (`tag == "commit"` with `rows=2504` on W16R2_8B or `rows=4577` on R13_SHIELD)
    a_commit_indices = [
        idx
        for idx, r in enumerate(records)
        if r["tag"] == "commit" and (r["detail"].startswith("rows=2504 ") or r["detail"].startswith("rows=4577 "))
    ]
    passes: List[List[Dict[str, object]]] = []
    for p_i, start_idx in enumerate(a_commit_indices):
        end_idx = a_commit_indices[p_i + 1] if p_i + 1 < len(a_commit_indices) else len(records)
        # Keep only records inside prove_core (exclude next pass's witness `wprod` before next `commit`)
        chunk = [r for r in records[start_idx:end_idx] if r["tag"] != "wprod"]
        passes.append(chunk)
    return passes


def summarize_batched_arm(warm_passes: List[List[Dict[str, object]]]) -> Dict[str, object]:
    by_cat: Dict[str, List[float]] = defaultdict(list)
    by_slot: Dict[str, List[float]] = defaultdict(list)
    slot_meta: Dict[str, str] = {}

    for p in warm_passes:
        cat_sum: Dict[str, float] = defaultdict(float)
        slot_sum: Dict[str, float] = defaultdict(float)
        for r in p:
            tag = r["tag"]
            det = str(r["detail"])
            ms = float(r["gpu_ms"])
            cat_sum["total_prove_gpu_ms"] += ms
            if tag == "commit":
                if det.startswith("rows=2504") or det.startswith("rows=4577"):
                    cat_sum["commit_A_ms"] += ms
                else:
                    cat_sum["commit_H_ms"] += ms
            elif tag in ("batch", "round-batch", "round", "fold", "tables"):
                cat_sum["all_slots_gpu_ms"] += ms
                if " | " in det:
                    lbl, meta = det.split(" | ", 1)
                    slot_sum[lbl] += ms
                    if tag in ("batch", "round-batch"):
                        slot_meta[lbl] = meta
            else:
                cat_sum[f"other_{tag}_ms"] += ms
        for k, v in cat_sum.items():
            by_cat[k].append(v)
        for k, v in slot_sum.items():
            by_slot[k].append(v)

    return {
        "categories_ms": {k: round(median_iqr(v)[0], 3) for k, v in sorted(by_cat.items())},
        "slots_sorted_ms": sorted(
            [
                {
                    "slot_label": lbl,
                    "median_ms": round(median_iqr(vals)[0], 3),
                    "p25_ms": round(median_iqr(vals)[1], 3),
                    "p75_ms": round(median_iqr(vals)[2], 3),
                    "meta": slot_meta.get(lbl, ""),
                }
                for lbl, vals in by_slot.items()
            ],
            key=lambda x: -x["median_ms"],
        ),
    }


def summarize_unbatched_arm(warm_passes: List[List[Dict[str, object]]]) -> Dict[str, object]:
    # Associate each `tables ... sync` with the immediately following `round ... j=0`
    slot_phase_samples: Dict[str, Dict[str, List[float]]] = defaultdict(lambda: defaultdict(list))
    slot_round_samples: Dict[str, Dict[int, List[float]]] = defaultdict(lambda: defaultdict(list))
    slot_meta: Dict[str, str] = {}

    for p in warm_passes:
        pending_tables_ms = 0.0
        per_slot_acc: Dict[str, Dict[str, float]] = defaultdict(lambda: defaultdict(float))
        for r in p:
            tag = r["tag"]
            det = str(r["detail"])
            ms = float(r["gpu_ms"])
            if tag == "tables" and "sync" in det:
                pending_tables_ms += ms
            elif tag == "round" and " | " in det:
                lbl, meta = det.split(" | ", 1)
                m_j = re.search(r"\bj=(\d+)\b", meta)
                j = int(m_j.group(1)) if m_j else -1
                if j == 0:
                    slot_meta[lbl] = meta
                    if pending_tables_ms > 0.0:
                        per_slot_acc[lbl]["tables_sync_ms"] += pending_tables_ms
                        per_slot_acc[lbl]["total_unbatched_with_tables_gpu_ms"] += pending_tables_ms
                        pending_tables_ms = 0.0
                    per_slot_acc[lbl]["round0_mat_plus_k0_ms"] += ms
                else:
                    per_slot_acc[lbl]["rounds_1_plus_fold_ms"] += ms
                slot_round_samples[lbl][j].append(ms)
                per_slot_acc[lbl]["total_unbatched_gpu_ms"] += ms
                per_slot_acc[lbl]["total_unbatched_with_tables_gpu_ms"] += ms
            elif tag == "fold" and " | " in det:
                lbl, _ = det.split(" | ", 1)
                per_slot_acc[lbl]["tail_fold_ms"] += ms
                per_slot_acc[lbl]["total_unbatched_gpu_ms"] += ms
                per_slot_acc[lbl]["total_unbatched_with_tables_gpu_ms"] += ms
        for lbl, d in per_slot_acc.items():
            for ph, val in d.items():
                slot_phase_samples[lbl][ph].append(val)

    out_slots = {}
    for lbl, ph_map in slot_phase_samples.items():
        out_slots[lbl] = {
            "meta": slot_meta.get(lbl, ""),
            "phases_median_ms": {ph: round(median_iqr(vals)[0], 3) for ph, vals in sorted(ph_map.items())},
            "per_round_median_ms": {
                f"j={j}": round(median_iqr(rvals)[0], 3)
                for j, rvals in sorted(slot_round_samples[lbl].items())
            },
        }
    return out_slots


def main() -> None:
    manifest = json.loads((OUT_DIR / "manifest.json").read_text())
    report: Dict[str, object] = {
        "census": {
            "r13_8b": parse_census(RAW_DIR / "census_r13_8b.guard.txt"),
            "r13_shield": parse_census(RAW_DIR / "census_r13_shield.guard.txt"),
        },
        "arms": {},
    }

    for item in manifest:
        lbl = str(item["label"])
        if lbl.startswith("census_"):
            continue
        m4_rows = parse_m4_summary(RAW_DIR / f"{lbl}.guard.txt")
        warm_m4 = [r for r in m4_rows if r["pass_kind"] == "warm"]
        assert all(r["cpu_digest"] == r["metal_digest"] for r in m4_rows), f"Digest mismatch in {lbl}"

        gz_files = [pathlib.Path(p) for p in item["trace_gz_files"]]
        assert len(gz_files) == 1, f"Expected 1 trace file for {lbl}, got {gz_files}"
        all_passes = parse_trace_passes(gz_files[0])
        warm_passes = all_passes[1:] if len(all_passes) > 1 else all_passes

        guard_lines = [
            ln for ln in str(item["guard_stderr"]).splitlines() if ln.startswith("[zk60-guard")
        ]
        entry: Dict[str, object] = {
            "guard_lines": guard_lines,
            "pre_ds4_bench": item["pre_ds4_bench"],
            "post_ds4_bench": item["post_ds4_bench"],
            "digest": m4_rows[0]["metal_digest"] if m4_rows else "",
            "warm_pass_count": len(warm_passes),
            "cpu_wall_s": round(m4_rows[0]["cpu_s"], 4) if m4_rows else 0.0,
            "cpu_core_s": round(m4_rows[0]["cpu_core_s"], 4) if m4_rows else 0.0,
            "metal_wall_median_s": round(median_iqr([r["metal_s"] for r in warm_m4])[0], 4),
            "metal_core_median_s": round(median_iqr([r["metal_core_s"] for r in warm_m4])[0], 4),
            "dev_sc_median_s": round(median_iqr([r["dev_sc_s"] for r in warm_m4])[0], 4),
        }
        if "armA" in lbl:
            entry["batched"] = summarize_batched_arm(warm_passes)
        else:
            entry["unbatched"] = summarize_unbatched_arm(warm_passes)
        report["arms"][lbl] = entry

    (OUT_DIR / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
    print("Wrote", OUT_DIR / "summary.json")


if __name__ == "__main__":
    main()
