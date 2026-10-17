#!/usr/bin/env python3
"""CPU-light arithmetic sensitivity experiment, NOT a prover or benchmark.

Reads existing public/synthetic source records. Produces no private data.
Models operation counts and hypothetical transfers; no native/GPU code runs.
"""
from fractions import Fraction
import hashlib
import json
import math
from pathlib import Path
import re
import resource
import time


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def matrix_macs(t, d, f, h, hkv, dh, layers, causal=False):
    assert d == h * dh and h % hkv == 0
    pairs = t * (t + 1) // 2 if causal else t * t
    ffn = layers * 3 * t * d * f
    projections = layers * t * (2 * d * d + 2 * d * hkv * dh)
    scores_and_values = layers * 2 * h * pairs * dh
    return {
        "ffn": ffn,
        "attention_projections": projections,
        "qk_and_pv": scores_and_values,
        "total": ffn + projections + scores_and_values,
    }


def explicit_small_macs(t, d, f, h, hkv, dh, causal):
    """Enumerate scalar multiply sites, independently of compact formulas."""
    ffn = sum(1 for _ in range(3) for _ in range(t)
              for _ in range(d) for _ in range(f))
    projections = sum(1 for out in (d, hkv * dh, hkv * dh, d)
                      for _ in range(t) for _ in range(d) for _ in range(out))
    attn = sum(1 for _ in range(2) for _ in range(h) for i in range(t)
               for j in range(t) for _ in range(dh) if not causal or j <= i)
    return ffn + projections + attn


def footprint(rows, n=16384, rate=4, layers=32):
    systematic = rows * n * 8
    encoded = systematic * rate
    return {
        "rows_per_block": rows,
        "systematic_bytes_per_block": systematic,
        "encoded_bytes_per_block": encoded,
        "resident_bytes_per_block": systematic + encoded,
        "systematic_bytes_pass": systematic * layers,
        "encoded_bytes_pass": encoded * layers,
        "resident_bytes_pass": (systematic + encoded) * layers,
    }


def ntt_offchip_bytes(rows, inv_passes, forward_passes, n=16384, rate=4, layers=32):
    # Each modeled pass reads and writes every 8-byte base-field element.
    return layers * rows * 2 * 8 * (n * inv_passes + n * rate * forward_passes)


def nearest_rank(values, quantile):
    assert values and 0 < quantile <= 1
    return sorted(values)[math.ceil(len(values) * quantile) - 1]


def main():
    started = time.perf_counter()
    shape_path = ROOT / "results/hashline_attn_cost_mistral.json"
    log_path = ROOT / "results/hashline_convert_r3.log"
    memory_path = ROOT / "docs/zkmatrix-poc/ZK60_PRIVATE_BLOCK_FORM_E.md"
    proto_path = ROOT / "docs/zkmatrix-poc/MEASUREMENT_PROTOCOL.md"
    source = json.loads(shape_path.read_text())
    s = source["shape"]
    t, d, f, h, hkv, dh = (s[k] for k in ("T", "d", "f", "H", "Hkv", "head_dim"))
    layers = 32
    budget = Fraction(t, 50)
    assert budget == Fraction(256, 25)
    assert budget / layers == Fraction(8, 25)

    checks = []
    for tiny_t in (1, 2, 3, 4):
        for causal in (False, True):
            counted = matrix_macs(tiny_t, 4, 6, 2, 1, 2, 1, causal)["total"]
            assert counted == explicit_small_macs(tiny_t, 4, 6, 2, 1, 2, causal)
            checks.append(f"explicit-macs-t{tiny_t}-causal{int(causal)}")
    assert nearest_rank(list(range(1, 21)), .5) == 10
    assert nearest_rank(list(range(1, 21)), .95) == 19
    checks.append("nearest-rank-20")

    pattern = re.compile(
        r"PASS-V3 ACCEPT: 32 x 512 \(d 4096 f 14336\): witness load\+chain "
        r"([0-9.]+) s \| PROVE ([0-9.]+) s \| VERIFY ([0-9.]+) s \| proof "
        r"([0-9]+) B .*?\| wall ([0-9.]+) s"
    )
    matches = list(pattern.finditer(log_path.read_text()))
    assert len(matches) == 2, "expected original before/after public FFN arms"
    load_s, prove_s, verify_s, proof_bytes, internal_s = matches[-1].groups()
    after_tail = log_path.read_text()[matches[-1].end():]
    assert "3:20.09" in after_tail
    historical = {
        "label": "MEASURED historical public FFN-only Mistral-7B, noisy shared laptop; not a target result",
        "witness_load_s": float(load_s), "prove_s": float(prove_s),
        "verify_s": float(verify_s), "proof_bytes": int(proof_bytes),
        "logged_internal_wall_s": float(internal_s), "process_elapsed_s": 200.09,
        "prove_tokens_per_s": t / float(prove_s),
        "internal_wall_tokens_per_s": t / float(internal_s),
        "process_elapsed_tokens_per_s": t / 200.09,
        "prove_over_target_budget_ratio": float(Fraction(prove_s) / budget),
        "full_private_target_gap": None,
    }

    # Exact arithmetic ON historical Form-E estimates. Not current emitted rows.
    # 17,471 FFN rows are source-counted; 26,676 attention rows are estimated.
    scenarios = []
    for multiplier in (Fraction(1, 2), Fraction(1), Fraction(2)):
        rows = 17471 + int(26676 * multiplier)
        fp = footprint(rows)
        enc = fp["encoded_bytes_pass"]
        # NVIDIA lists PCIe Gen5 x16 as 128 GB/s BIDIRECTIONAL: at most
        # 64 GB/s in one direction. Full encode egress is a scenario, not required.
        scenarios.append({
            "label": "MODEL Form-E row sensitivity, not a measured allocation",
            "attention_row_multiplier": float(multiplier), **fp,
            "one_encoded_copy_at_64GBps_s": enc / 64e9,
            "one_encoded_copy_at_32GBps_s": enc / 32e9,
            "required_one_way_encoded_copy_GBps_for_50tps": enc / float(budget) / 1e9,
            "copy_alone_exceeds_budget_at_64GBps": enc / 64e9 > float(budget),
            "nonweight_rows_per_block_if_10752_W_rows_preprocessed": rows - 10752,
            "nonweight_encoded_bytes_pass": footprint(rows - 10752)["encoded_bytes_pass"],
            "nonweight_copy_only_at_64GBps_s": footprint(rows - 10752)["encoded_bytes_pass"] / 64e9,
        })
    rows = scenarios[1]["rows_per_block"]
    ntt = []
    for inv_passes, forward_passes in ((14, 16), (2, 2), (1, 1)):
        traffic = ntt_offchip_bytes(rows, inv_passes, forward_passes)
        nonweight_traffic = ntt_offchip_bytes(rows - 10752, inv_passes, forward_passes)
        ntt.append({
            "label": "MODEL hypothetical global-memory pass count, not measured GPU traffic",
            "inverse_read_write_passes": inv_passes,
            "forward_read_write_passes": forward_passes,
            "traffic_bytes": traffic,
            "ideal_H100_HBM_3_35TBps_s": traffic / 3.35e12,
            "half_peak_HBM_1_675TBps_s": traffic / 1.675e12,
            "nonweight_commit_only_traffic_bytes": nonweight_traffic,
            "nonweight_commit_only_ideal_H100_HBM_s": nonweight_traffic / 3.35e12,
        })

    dense = matrix_macs(t, d, f, h, hkv, dh, layers)
    causal = matrix_macs(t, d, f, h, hkv, dh, layers, True)
    # Negative controls catch common unjustified shortcuts.
    assert causal["total"] != dense["total"] // 2
    assert ntt[0]["traffic_bytes"] > ntt[1]["traffic_bytes"]
    assert scenarios[1]["copy_alone_exceeds_budget_at_64GBps"]
    assert scenarios[1]["encoded_bytes_pass"] / 128e9 < float(budget)
    assert scenarios[1]["resident_bytes_pass"] > 80e9
    assert scenarios[1]["nonweight_copy_only_at_64GBps_s"] < float(budget)
    checks += ["causal-half-does-not-half-full-model", "fusion-changes-traffic",
               "one-way-not-bidirectional-bandwidth", "resident-pass-exceeds-80GB",
               "exclude-static-weight-commitments-before-warm-bound"]
    output = {
        "experiment": "20260926 forward-pass throughput budget and traffic sensitivity",
        "no_proof_or_gpu_benchmark_executed": True,
        "shape_origin": "historical Mistral-7B geometry; no 8B checkpoint identity inferred",
        "shape": {**s, "layers": layers},
        "target": {"workload": "512-token complete-private transformer-stack prefill",
                   "tokens_per_s": 50, "max_pass_s": float(budget),
                   "average_block_s_before_shared_overhead": float(budget / layers),
                   "five_second_stretch_tokens_per_s": t / 5,
                   "five_second_average_block_s": 5 / layers,
                   "decode_tokens_per_s": None},
        "historical_baseline": historical,
        "matrix_macs_counted_not_proof_operations": {"dense_attention": dense,
            "causal_attention_if_sparse_arithmetic": causal,
            "dense_MACs_per_s_at_target": dense["total"] / float(budget)},
        "memory_sensitivity": scenarios,
        "NTT_traffic_sensitivity": ntt,
        "self_checks_passed": checks,
        "sources_sha256": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                           for p in (shape_path, log_path, memory_path, proto_path, Path(__file__))},
        "experiment_wall_s_not_prover_timing": time.perf_counter() - started,
        "experiment_peak_rss_kib_linux": resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
    }
    (HERE / "result.json").write_text(json.dumps(output, indent=2) + "\n")
    print(json.dumps({"status": "PASS", "checks": len(checks),
        "target_s": float(budget), "form_E_central_rows": rows,
        "conditional_encoded_copy_floor_s": scenarios[1]["one_encoded_copy_at_64GBps_s"],
        "scenario_NTT_floors_s": [x["ideal_H100_HBM_3_35TBps_s"] for x in ntt],
        "experiment_wall_s": output["experiment_wall_s_not_prover_timing"],
        "rss_kib": output["experiment_peak_rss_kib_linux"]}, indent=2))


if __name__ == "__main__":
    main()
