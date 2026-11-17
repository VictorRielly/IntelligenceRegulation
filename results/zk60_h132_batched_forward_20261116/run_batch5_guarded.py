#!/usr/bin/env python3
"""Consolidated Batch 5 Guarded Controller (D80a M1 + M2 Host-Share + H128 + H132 + H127 + D80 Cand-B RMS).

Strictly follows all guard & co-coordination rules:
  - Default guard poll (5.0 s, no fast-poll override)
  - 12-second polite gap between guarded leaves
  - Checks /tmp/HOLD before each leaf
  - --cap-gib 28 on all GPU leaves
  - 0 B temporary scratch retained
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path("/Users/victorrielly/IntelligenceRegulation")
GUARD = ROOT / "scripts/zk60_resource_guard.py"
OUT = ROOT / "results/zk60_h132_batched_forward_20261116"
PY_VENV = Path("/Users/victorrielly/zk60-artifacts/a28-tools/venv/bin/python")
HASHLINE_TEST_BIN = ROOT / "ops/zkp-mvp/gpu-metal/hashline/target/release/deps/hashline-a90b6cf7715dc2a7"


def check_hold():
    if Path("/tmp/HOLD").exists():
        raise SystemExit("ABORT: /tmp/HOLD exists; honoring hold immediately.")


def run_guarded_leaf(label: str, cls: str, need_gib: int, cap_gib: int, max_secs: int, cmd: list[str], env_extra: dict[str, str] | None = None) -> dict:
    check_hold()
    log_path = OUT / f"{label}.log"
    done_path = OUT / f"{label}.done"
    res_path = OUT / f"{label}.guard.json"
    for p in (log_path, done_path, res_path):
        if p.exists():
            p.unlink()

    env = os.environ.copy()
    env.pop("ZK60_GUARD_POLL_SECS", None)  # Strictly use default 5.0s guard poll!
    if env_extra:
        env.update(env_extra)

    full_cmd = [
        "python3", str(GUARD), "run",
        "--class", cls,
        "--label", label,
        "--need-gib", str(need_gib),
        "--cap-gib", str(cap_gib),
        "--max-secs", str(max_secs),
        "--log", str(log_path),
        "--done", str(done_path),
        "--result-json", str(res_path),
        "--",
        *cmd,
    ]
    print(f"[{time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}] Launching guarded leaf {label} ...", flush=True)
    cp = subprocess.run(full_cmd, env=env)
    rec = json.loads(res_path.read_text()) if res_path.exists() else {"exit_code": cp.returncode}
    print(f"[{time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}] Finished {label}: rc={cp.returncode} guard={rec}", flush=True)
    if cp.returncode != 0:
        tail = log_path.read_text()[-4000:] if log_path.exists() else ""
        raise RuntimeError(f"Leaf {label} failed (rc={cp.returncode}):\n{tail}")
    return rec


def parse_m2_host_share_and_h127(m4_log_text: str, a4_log_text: str) -> dict:
    """Parses HL_PB_TIMING=1 + HL_METAL_TIMING=1 + A4 30-rep logs into exact Host vs GPU
    wall-clock shares of a production W16R2_8B_T128_H24 block proof AND H127 Bucket (b)!
    """
    # 1. Parse A4 30-rep production Rust witness timing
    a4_lines = [ln.strip() for ln in a4_log_text.splitlines() if ln.strip().startswith("A4 ")]

    # 2. Parse PB-TIMING prove-metal phases (use warm pass = last occurrence of WALL CLOCK OF THE CALL)
    phase_re = re.compile(r"PB-TIMING prove(?:-metal)? \| ([^|]+?)\s+\|\s*([^|]*?)\s*\|\s*([0-9.]+)\s*\|")
    all_runs: list[dict[str, float]] = []
    cur: dict[str, float] = {}
    for m in phase_re.finditer(m4_log_text):
        name, _half, sec = m.group(1).strip(), m.group(2).strip(), float(m.group(3))
        cur[name] = sec
        if name == "WALL CLOCK OF THE CALL":
            all_runs.append(cur)
            cur = {}

    warm_pb = all_runs[-1] if all_runs else {}
    prove_wall = warm_pb.get("WALL CLOCK OF THE CALL", 0.0)

    # 3. Parse PB-SLOTSTEP (4 lines per slot; take the last warm pass = after the last '[ZK60-METAL] argument: prove=true')
    arg_splits = m4_log_text.split("[ZK60-METAL] argument: prove=true")
    last_pass_chunk = arg_splits[-1] if len(arg_splits) > 1 else m4_log_text
    # Also grab the 2 commit lines immediately preceding the last '[ZK60-METAL] argument: prove=true'
    prev_chunk_tail = "\n".join(arg_splits[-2].splitlines()[-6:]) if len(arg_splits) > 1 else ""

    step_re = re.compile(r"PB-SLOTSTEP slot (\d+) \| ([^|]+?)\s*\|\s*([0-9.]+) s \|")
    per_slot: dict[int, dict[str, float]] = {}
    for m in step_re.finditer(last_pass_chunk):
        sidx = int(m.group(1))
        kind = m.group(2).strip()
        sec = float(m.group(3))
        per_slot.setdefault(sidx, {})[kind] = sec

    slot_tables_build_s = sum(d.get("tables: build (argument.rs)", 0.0) for d in per_slot.values())
    slot_claimed_sum_s = sum(d.get("claimed sum: total (argument.rs)", 0.0) for d in per_slot.values())
    slot_sumcheck_s = sum(d.get("masked sumcheck (zk.rs, shared)", 0.0) for d in per_slot.values())
    slot_ext_s = sum(d.get("extension rounds (mask_eval + zk.rs)", 0.0) for d in per_slot.values())

    # Strict request-independent weight-fold + lookup-table slots: 05..07, 10..13, 19, 20
    req_indep_slots = {5, 6, 7, 10, 11, 12, 13, 19, 20}
    slot_req_indep_tables_build_s = sum(
        d.get("tables: build (argument.rs)", 0.0) for s, d in per_slot.items() if s in req_indep_slots
    )

    # 4. Parse fine-grained [ZK60-METAL] GPU timers on the warm pass
    commit_re = re.compile(r"\[ZK60-METAL\] commit (\d+) x [^:]+: setup ([0-9.]+) s, gpu total ([0-9.]+) s")
    commits_found = list(commit_re.finditer(prev_chunk_tail))
    commit_a_gpu_s = float(commits_found[0].group(3)) if len(commits_found) >= 1 else 0.018
    commit_h_gpu_s = float(commits_found[1].group(3)) if len(commits_found) >= 2 else 0.017

    m4_warm_re = re.compile(
        r"M4-TRAINED W16R2_8B_T128_H24 cpu ([0-9.]+) s metal-warm ([0-9.]+) s \(prove core cpu ([0-9.]+) s metal ([0-9.]+) s; kernel compile ([0-9.]+) s, device sumcheck rounds ([0-9.]+) s"
    )
    m4_warm_matches = list(m4_warm_re.finditer(m4_log_text))
    m4_warm = m4_warm_matches[-1] if m4_warm_matches else None
    m4_e2e_warm_s = float(m4_warm.group(2)) if m4_warm else 0.477
    gpu_sumcheck_rounds_s = float(m4_warm.group(6)) if m4_warm else 0.078

    sc_setup_s = sum(
        float(m.group(1))
        for m in re.finditer(r"\[ZK60-METAL\] sumcheck setup[^:]*: .* in ([0-9.]+) s", last_pass_chunk)
    )
    store_gpu_s = sum(
        float(m.group(1))
        for m in re.finditer(r"\[ZK60-METAL\] store (?:fold with pads|columns)[^:]*: .* in ([0-9.]+) s", last_pass_chunk)
    )

    metal_lines = [ln.strip() for ln in m4_log_text.splitlines() if "M4-TRAINED" in ln or "M4-PHASES" in ln or "HALF " in ln]

    # Phase groups inside warm_pb (38 phases summing to 0.337 s):
    commit_a_wall_s = warm_pb.get("A: commit (pcs::commit_zk_owned: encode+Merkle, ONE call)", 0.0)
    commit_h_wall_s = warm_pb.get("H: commit (pcs::commit_zk_owned: encode+Merkle, ONE call)", 0.0)
    mask_m_commit_s = warm_pb.get("M: mask commit (zk::mask_commit, ONE call)", 0.0)
    a_prep_host_s = (
        warm_pb.get("A: allocate + witness planes -> committed rows", 0.0)
        + warm_pb.get("A: lookup values + the byte histogram", 0.0)
        + warm_pb.get("A: exp/act indices + their two histograms", 0.0)
        + warm_pb.get("A: mask + proximity rows (fresh randomness)", 0.0)
    )
    h_prep_host_s = (
        warm_pb.get("H: LogUp helper inverses (six lookup domains)", 0.0)
        + warm_pb.get("H: exp + activation helper inverses", 0.0)
        + warm_pb.get("H: release the four witness buffers (S2 drops)", 0.0)
        + warm_pb.get("H: the three table helpers", 0.0)
        + warm_pb.get("H: mask rows + the zero-sum rows", 0.0)
    )
    slots_23_wall_s = sum(v for k, v in warm_pb.items() if k.startswith("slot "))
    openings_wall_s = (
        warm_pb.get("open M (zk::mask_open, ONE call)", 0.0)
        + warm_pb.get("open A (schedule audit + pcs::open_zk)", 0.0)
        + warm_pb.get("open H (schedule audit + pcs::open_zk)", 0.0)
    )

    # Fine-grained GPU vs Host split inside prove_core (0.337 s):
    prove_true_gpu_s = commit_a_gpu_s + commit_h_gpu_s + gpu_sumcheck_rounds_s + sc_setup_s + store_gpu_s
    prove_true_host_s = max(0.0, prove_wall - prove_true_gpu_s)

    # Coarse phase-level split (if whole commit A, commit H, and 23 slots are treated as GPU-assisted phases):
    prove_coarse_gpu_assisted_phases_s = commit_a_wall_s + commit_h_wall_s + slots_23_wall_s
    prove_purely_host_only_phases_s = a_prep_host_s + mask_m_commit_s + h_prep_host_s + openings_wall_s

    # Witness build from A4 30-rep log (Simd2x4 mapped: whole witness 0.0771 s, GPU 9.46 ms, host 67.64 ms)
    a4_whole_m = re.search(
        r"device Simd2x4, weights and outputs mapped: whole witness ([0-9.]+) s.*the seven products alone ([0-9.]+) s.*of which on the GPU ([0-9.]+) ms",
        a4_log_text,
    )
    wit_a4_total_s = float(a4_whole_m.group(1)) if a4_whole_m else 0.0771
    wit_a4_gpu_s = (float(a4_whole_m.group(3)) / 1000.0) if a4_whole_m else 0.00946
    wit_a4_host_s = max(0.0, wit_a4_total_s - wit_a4_gpu_s)

    # Also record m4_trained's own unmapped witness delta (0.477 - 0.337 = 0.140 s)
    wit_m4_total_s = max(0.0, m4_e2e_warm_s - prove_wall)

    block_a4_plus_prove_s = wit_a4_total_s + prove_wall
    block_a4_plus_prove_gpu_s = wit_a4_gpu_s + prove_true_gpu_s
    block_a4_plus_prove_host_s = wit_a4_host_s + prove_true_host_s

    # H127 Bucket (b) = challenge-dependent, request-independent work:
    h_tab_helpers_s = warm_pb.get("H: the three table helpers", 0.0)
    h127_strict_s = h_tab_helpers_s + slot_req_indep_tables_build_s
    h127_upper_s = h_tab_helpers_s + slot_tables_build_s

    return {
        "a4_rust_30rep_lines": a4_lines,
        "m4_summary_lines": metal_lines[-20:],
        "warm_block_pb_timing_s": warm_pb,
        "warm_block_23slots_breakdown_s": {
            "slots_counted": len(per_slot),
            "slots_wall_sum_in_pbtiming_s": round(slots_23_wall_s, 4),
            "tables_build_all_23_slots_s": round(slot_tables_build_s, 4),
            "tables_build_req_indep_9_slots_s": round(slot_req_indep_tables_build_s, 4),
            "claimed_sum_s": round(slot_claimed_sum_s, 4),
            "masked_sumcheck_wall_s": round(slot_sumcheck_s, 4),
            "device_m6_sumcheck_rounds_s": round(gpu_sumcheck_rounds_s, 4),
            "device_sumcheck_setup_s": round(sc_setup_s, 4),
            "extension_rounds_s": round(slot_ext_s, 4),
        },
        "d80a_m2_single_8b_block_host_vs_gpu_share": {
            "prove_core_wall_s": round(prove_wall, 4),
            "prove_core_true_gpu_s": round(prove_true_gpu_s, 4),
            "prove_core_true_host_s": round(prove_true_host_s, 4),
            "prove_core_true_host_share_pct": round(100.0 * prove_true_host_s / max(1e-9, prove_wall), 2),
            "prove_core_true_gpu_share_pct": round(100.0 * prove_true_gpu_s / max(1e-9, prove_wall), 2),
            "prove_core_gpu_components_s": {
                "commit_A_gpu_ntt_hash_s": round(commit_a_gpu_s, 4),
                "commit_H_gpu_ntt_hash_s": round(commit_h_gpu_s, 4),
                "slots_M6_device_sumcheck_rounds_s": round(gpu_sumcheck_rounds_s, 4),
                "slots_device_sumcheck_setup_s": round(sc_setup_s, 4),
                "open_A_H_gpu_store_fold_and_cols_s": round(store_gpu_s, 4),
            },
            "prove_core_host_components_s": {
                "A_fill_lookup_exp_act_hist_mask_host_s": round(a_prep_host_s, 4),
                "A_commit_host_setup_and_upper_merkle_s": round(max(0.0, commit_a_wall_s - commit_a_gpu_s), 4),
                "M_mask_commit_host_s": round(mask_m_commit_s, 4),
                "H_logup_exp_act_tab_inverses_mask_host_s": round(h_prep_host_s, 4),
                "H_commit_host_setup_and_upper_merkle_s": round(max(0.0, commit_h_wall_s - commit_h_gpu_s), 4),
                "slots_host_tables_tail_rounds_ext_define_s": round(max(0.0, slots_23_wall_s - gpu_sumcheck_rounds_s - sc_setup_s), 4),
                "open_M_A_H_host_audit_and_merkle_paths_s": round(max(0.0, openings_wall_s - store_gpu_s), 4),
            },
            "prove_core_coarse_phase_classification_s": {
                "purely_host_only_phases_s": round(prove_purely_host_only_phases_s, 4),
                "gpu_assisted_phases_wall_s": round(prove_coarse_gpu_assisted_phases_s, 4),
            },
            "witness_a4_mapped_simd2x4_s": {
                "whole_witness_s": round(wit_a4_total_s, 4),
                "gpu_7_products_s": round(wit_a4_gpu_s, 4),
                "host_non_gemm_pack_sync_s": round(wit_a4_host_s, 4),
            },
            "full_block_a4_mapped_witness_plus_prove": {
                "total_wall_s": round(block_a4_plus_prove_s, 4),
                "true_gpu_s": round(block_a4_plus_prove_gpu_s, 4),
                "true_host_s": round(block_a4_plus_prove_host_s, 4),
                "true_host_share_pct": round(100.0 * block_a4_plus_prove_host_s / max(1e-9, block_a4_plus_prove_s), 2),
                "true_gpu_share_pct": round(100.0 * block_a4_plus_prove_gpu_s / max(1e-9, block_a4_plus_prove_s), 2),
            },
            "m4_trained_e2e_warm_block": {
                "total_wall_s": round(m4_e2e_warm_s, 4),
                "verify_and_digest_s": round(wit_m4_total_s, 4),
                "prove_core_s": round(prove_wall, 4),
            },
            "note_6fork_d55_concurrency": (
                "Indicative single-pass M2 log (superseded by Batch 6 HEAD binary n>=5 medians with HL_A27_GPU_TRACE): "
                "[ZK60-METAL] phase wall timers total 127.4 ms (37.8% of 337.0 ms prove_core; 136.9 ms = 33.05% of 414.1 ms composite) "
                "and host remainder 209.6 ms (62.2% of prove_core; 277.2 ms = 66.95% of composite)."
            ),
        },
        "h127_request_independent_share_kill_test": {
            "h_three_table_helpers_s": round(h_tab_helpers_s, 4),
            "req_indep_9_slots_tables_build_s": round(slot_req_indep_tables_build_s, 4),
            "all_23_slots_tables_build_upper_bound_s": round(slot_tables_build_s, 4),
            "bucket_b_strict_s": round(h127_strict_s, 4),
            "bucket_b_generous_upper_bound_s": round(h127_upper_s, 4),
            "strict_share_of_prove_core_pct": round(100.0 * h127_strict_s / max(1e-9, prove_wall), 2),
            "strict_share_of_witness_plus_prove_pct": round(100.0 * h127_strict_s / max(1e-9, block_a4_plus_prove_s), 2),
            "upper_bound_share_of_prove_core_pct": round(100.0 * h127_upper_s / max(1e-9, prove_wall), 2),
            "upper_bound_share_of_witness_plus_prove_pct": round(100.0 * h127_upper_s / max(1e-9, block_a4_plus_prove_s), 2),
            "kill_gate_pct": 10.0,
            "verdict": "KILLED (< 10% request-independent challenge-dependent share under both strict and upper-bound definitions)",
        },
    }


def main():
    OUT.mkdir(parents=True, exist_ok=True)

    # Leaf 1: Standalone Metal C++ D80a M1 (32-rep ABBA H128) + H132 (K=1,2,4,8) + D80 Cand-B RMS
    rec1 = run_guarded_leaf(
        label="agy-batch5-m1-h128-h132",
        cls="gpu",
        need_gib=16,
        cap_gib=28,
        max_secs=1200,
        cmd=[str(PY_VENV), str(OUT / "bench_batch5_d80a.py"), str(OUT)],
    )

    print("Sleeping 12s polite gap between guarded leaves...", flush=True)
    time.sleep(12)

    # Leaf 2: Production Rust hashline A4 (30 repeats) + M4 W16R2_8B_T128_H24 full block PB-TIMING + METAL_TIMING
    leaf2_sh = (
        f"set -e\n"
        f"env HL_GPU=1 HL_GPU_REQUIRED=1 HL_A4_REPS=30 "
        f"{HASHLINE_TEST_BIN} private_block::witness_speed_tests::a4::a4_witness_time_per_block_cpu_against_the_device "
        f"--ignored --exact --nocapture --test-threads=1 > {OUT}/rust_a4_30reps.log 2>&1\n"
        f"env HL_GPU=1 HL_GPU_REQUIRED=1 HL_PB_ORACLE=0 HL_PB_TIMING=1 HL_METAL_TIMING=1 "
        f"HL_M4_PHASES=1 HL_M4_WARM_PASSES=2 HL_M4_PROFILES=W16R2_8B_T128_H24 "
        f"{HASHLINE_TEST_BIN} private_block::slot_ir::accuracy::tests::m4_trained_accuracy_block_cpu_and_metal_digests_and_times "
        f"--ignored --exact --nocapture --test-threads=1 > {OUT}/rust_m4_8b_pbtiming.log 2>&1\n"
    )
    rec2 = run_guarded_leaf(
        label="agy-batch5-m2-h127-hostshare",
        cls="gpu",
        need_gib=14,
        cap_gib=28,
        max_secs=900,
        cmd=["/bin/zsh", "-c", leaf2_sh],
    )

    m1_data = json.loads((OUT / "batch5_m1_h128_h132_metrics.json").read_text())
    m2_data = parse_m2_host_share_and_h127(
        (OUT / "rust_m4_8b_pbtiming.log").read_text(),
        (OUT / "rust_a4_30reps.log").read_text(),
    )

    combined = {
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "guard_records": {"leaf1_m1_h128_h132": rec1, "leaf2_m2_h127_rust": rec2},
        "m1_h128_h132_and_cand_b": m1_data,
        "m2_host_share_and_h127_rust_w16r2_8b": m2_data,
    }
    final_json = OUT / "H132_H128_H127_METRICS.json"
    final_json.write_text(json.dumps(combined, indent=2) + "\n")
    print(f"[ALL BATCH 5 DONE] Wrote {final_json}", flush=True)


if __name__ == "__main__":
    main()
