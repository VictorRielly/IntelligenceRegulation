"""Capacity, storage and cost arithmetic for ZK60_PROVING_SERVICE_SPEC.md (2026-10-30).

Run: python3 results/zk60_proving_service_20261030/capacity_cost.py
Writes capacity_cost.json next to this file and prints the same numbers.

Every input carries its label and source:
  MEASURED  a recorded run (file named)
  READ      a figure read from a project document (itself labelled there)
  INFERRED  an assumption made for this spec; change it and re-run
No network, no proof, no heavy work.
"""
import json
import math
from pathlib import Path

A = "results/zk60_astra_20261026/"
CHAIN = "results/zk60_chain_publication_20261021/REPORT.md (prices read 2026-10-21; [V]/[UNV] as marked there)"

INPUTS = {
    # --- measured, per (category, chunk) job, laptop Core Ultra 9 185H, shared box, n=1 each ---
    "prove_s_8_threads": {"v": [452.0, 456.3, 457.0], "label": "MEASURED",
                          "src": A + "real_app_demo_2/sexual.json; real_app_demo_1/violence.json, hate.json"},
    "pipeline_s_8_threads": {"v": [684.6, 687.5, 693.5], "label": "MEASURED",
                             "src": "same files: seqgen + prove + verify + inowner + label child wall seconds"},
    "prove_s_2_threads": {"v": 1031.16, "label": "MEASURED", "src": A + "real_app_demo_1/sexual.json"},
    "fresh_verify_s": {"v": [69.3, 69.2, 67.7, 80.8], "label": "MEASURED", "src": "same files, verify step"},
    "prove_peak_rss_gib": {"v": [7.99, 8.16, 8.24], "label": "MEASURED", "src": "same files"},
    "verify_peak_rss_gib": {"v": [2.13, 2.27, 2.3], "label": "MEASURED", "src": "same files"},
    "guard_prove_need_cap_gib": {"v": [10.4, 11.5], "label": "READ", "src": "apps/proven-media/deploy.json"},
    "receipt_bytes_per_job": {"v": 848_412_096, "label": "MEASURED", "src": A + "real_app_demo_1/RECOVERY_REPORT.md"},
    "receipt_segments_per_job": {"v": 28, "label": "MEASURED", "src": "same"},
    "disk_copies_today": {"v": 2, "label": "MEASURED",
                          "src": "public/runs 2,545,251,995 B and public/base-sepolia/bundle-store 2,545,266,296 B, "
                                 "separate inodes (link count 1), real_app_demo_1"},
    "batch_r18_vs_singles_s": {"v": [1418, 1453], "label": "MEASURED",
                               "src": "docs/zkmatrix-poc/ZK60_SOL_ASTRA_TODOS_20261026.md 2026-10-30T09:22Z"},
    "compress_ratio_zlib6_32MB_segment": {"v": 0.9976, "label": "MEASURED",
                                          "src": "this spec, segment-005.bin of the first post's c0 receipt; "
                                                 "segment-000 0.8706 (1.4 MB), segment-027 0.9475 (3.3 MB)"},
    "anchor_tx_gas_limit": {"v": 30_883, "label": "MEASURED",
                            "src": A + "real_app_demo_1/public/base-sepolia/chain/batches/batch-000000.json"},
    "gas_estimate_margin": {"v": 1.25, "label": "READ", "src": "apps/proven-media/proven_media/base_sepolia.py:169"},
    # --- geometry (D41, T128 moderate policies) ---
    "chunk_tokens": {"v": {"sexual": 55, "violence": 55, "hate": 49}, "label": "READ", "src": "deploy.json"},
    "overlap_tokens": {"v": 8, "label": "READ", "src": "deploy.json"},
    "max_content_tokens": {"v": 336, "label": "READ", "src": "deploy.json"},
    # --- prices (READ from the chain report; re-check before any spend) ---
    "eth_usd": {"v": 2447.24, "label": "READ", "src": CHAIN},
    "base_gas_gwei": {"v": 0.0060, "label": "READ", "src": CHAIN},
    "l1_gas_gwei_today_and_10": {"v": [0.040, 10.0], "label": "READ", "src": CHAIN},
    "r2_usd_per_gb_month": {"v": 0.015, "label": "READ (UNV in source)", "src": CHAIN},
    "s3_usd_per_gb_month_and_egress_gb": {"v": [0.023, 0.09], "label": "READ (UNV in source)", "src": CHAIN},
    "filecoin_usd_per_tib_month_per_copy": {"v": 2.50, "label": "READ", "src": CHAIN},
    "arweave_usd_per_gib": {"v": 55.21, "label": "READ", "src": CHAIN},
    "groth16_receipt_bytes": {"v": 785, "label": "MEASURED (toy zkVM block, not the classifier)",
                              "src": "docs/zkmatrix-poc/MVP_STATUS.md section 1"},
    "wrap_gpu_hours_per_classifier_proof": {"v": [6, 18], "label": "READ (estimate in source)", "src": CHAIN},
    "wrap_usd_per_post": {"v": [2, 18], "label": "READ (estimate in source)", "src": CHAIN},
    # --- assumptions for the pilot (INFERRED; replace with quotes) ---
    "desktop_slots": {"v": [1, 2, 4], "label": "INFERRED",
                      "src": "concurrent 8-thread jobs the 5090 desktop's CPU could run; its CPU and RAM are unknown "
                             "(docs/zkmatrix-poc/ZK60_HARDWARE_SETUP.md, 2026-10-17); the guard allows 1 today"},
    "slot_efficiency": {"v": {"1": 1.0, "2": 0.85, "4": 0.65}, "label": "INFERRED",
                        "src": "memory-bandwidth sharing; 2 -> 8 threads gave only 2.26x on the laptop"},
    "desktop_watts": {"v": [150, 400], "label": "INFERRED", "src": "CPU proving, GPU idle"},
    "usd_per_kwh": {"v": 0.35, "label": "INFERRED", "src": "residential, California-like rate"},
    "vps_usd_month": {"v": [20, 60], "label": "INFERRED", "src": "4 vCPU / 8 GB API + verify box, unquoted"},
    "rented_cpu_server_usd_month": {"v": [100, 250], "label": "INFERRED",
                                    "src": "dedicated 16+ cores, 64-128 GB, 2 TB NVMe, unquoted"},
    "pilot_posts_month": {"v": 300, "label": "INFERRED", "src": "3 invited customers x ~100 short posts"},
    "retention_months": {"v": [3, 12], "label": "INFERRED", "src": "options for Victor's retention ruling"},
}


def v(k):
    return INPUTS[k]["v"]


def chunks(n, c, o):
    """D41 split with an end-aligned last window: 1 chunk if n <= c, else 1 + ceil((n - c) / (c - o))."""
    return 1 if n <= c else 1 + math.ceil((n - c) / (c - o))


def jobs(n):
    return sum(chunks(n, c, v("overlap_tokens")) for c in v("chunk_tokens").values())


def main():
    out = {}
    day = 86_400
    t_job = sum(v("pipeline_s_8_threads")) / 3
    t_prove = sum(v("prove_s_8_threads")) / 3
    out["per_job_s"] = {"pipeline_mean": round(t_job, 1), "prove_mean": round(t_prove, 1)}

    sizes = [17, 49, 55, 100, 200, 336]
    out["jobs_per_post_by_tokens"] = {n: jobs(n) for n in sizes}

    rb = v("receipt_bytes_per_job")
    per_post = {}
    for n in sizes:
        j = jobs(n)
        per_post[n] = {
            "J": j,
            "work_s_one_slot": round(j * t_job),
            "work_h_one_slot": round(j * t_job / 3600, 2),
            "receipt_GB": round(j * rb / 1e9, 3),
            "disk_GB_today_two_copies": round(j * rb * v("disk_copies_today") / 1e9, 3),
        }
    out["per_post"] = per_post

    # posts per day, short post (n <= 49, J = 3)
    cap = {}
    for k in v("desktop_slots"):
        eff = v("slot_efficiency")[str(k)]
        cap[k] = {
            "short_posts_per_day": round(k * eff * day / (3 * t_job), 1),
            "max_posts_per_day_J22": round(k * eff * day / (22 * t_job), 1),
            "prove_only_bound_short": round(k * eff * day / (3 * t_prove), 1),
        }
    out["posts_per_day_by_slots"] = cap

    # verification capacity (registry), one verify slot
    tv = sum(v("fresh_verify_s")) / len(v("fresh_verify_s"))
    out["registry_verify"] = {"mean_s": round(tv, 1), "receipts_per_day_one_slot": round(day / tv),
                              "short_posts_per_day_one_slot": round(day / (3 * tv))}

    # storage per short post (J = 3)
    gb = 3 * rb / 1e9
    gib = 3 * rb / 2**30
    r2 = v("r2_usd_per_gb_month")
    s3, s3e = v("s3_usd_per_gb_month_and_egress_gb")
    fil = v("filecoin_usd_per_tib_month_per_copy") * 2 / 1024  # per GiB-month, two copies
    out["storage_short_post"] = {
        "GB": round(gb, 3), "GiB": round(gib, 3),
        "r2_usd_month": round(gb * r2, 4), "r2_usd_year": round(gb * r2 * 12, 3),
        "filecoin_2copies_usd_year": round(gib * fil * 12, 3),
        "s3_usd_year": round(gb * s3 * 12, 3), "s3_egress_usd_per_full_download": round(gb * s3e, 3),
        "arweave_usd_once": round(gib * v("arweave_usd_per_gib"), 2),
        "zlib_saving_fraction": round(1 - v("compress_ratio_zlib6_32MB_segment"), 4),
        "groth16_wrapped_bytes_3_categories": 3 * v("groth16_receipt_bytes"),
        "size_reduction_if_wrapped": round(gb * 1e9 / (3 * v("groth16_receipt_bytes"))),
    }
    # download time for a third party, 2.545 GB at 20 / 100 / 1000 Mbit/s
    out["download_minutes_short_post"] = {m: round(gb * 8e3 / m / 60, 1) for m in (20, 100, 1000)}

    # anchoring (Base mainnet), one batch transaction
    gas_used = v("anchor_tx_gas_limit") / v("gas_estimate_margin")
    eth = v("eth_usd")
    base_tx = gas_used * v("base_gas_gwei") * 1e-9 * eth
    l1_today, l1_10 = (60_000 * g * 1e-9 * eth for g in v("l1_gas_gwei_today_and_10"))
    out["anchoring"] = {
        "gas_used_inferred": round(gas_used),
        "base_usd_per_batch_tx": round(base_tx, 6),
        "base_usd_per_batch_tx_at_100x_gas": round(base_tx * 100, 4),
        "base_usd_per_post_batch_of_333_posts": round(base_tx / 333, 8),
        "base_usd_per_post_one_tx_each": round(base_tx, 6),
        "with_storage_write_gas_inferred": round(gas_used + 22_100),
        "l1_daily_checkpoint_usd_today_and_at_10_gwei": [round(l1_today, 4), round(l1_10, 2)],
    }

    # pilot monthly cost
    lo_w, hi_w = v("desktop_watts")
    kwh = [w / 1000 * 720 for w in (lo_w, hi_w)]
    elec = [round(x * v("usd_per_kwh")) for x in kwh]
    posts = v("pilot_posts_month")
    stor = {}
    for m in v("retention_months"):
        steady_gb = posts * m * gb
        stor[m] = {"steady_TB": round(steady_gb / 1e3, 2), "r2_usd_month": round(steady_gb * r2, 1)}
    vlo, vhi = v("vps_usd_month")
    slo, shi = v("rented_cpu_server_usd_month")
    out["pilot_month_usd"] = {
        "phase0_vps_plus_demo_storage": [vlo, vhi + 1],
        "phase1_desktop_electricity": elec,
        "phase1_storage_r2_by_retention_months": stor,
        "phase1_total_home_desktop_3mo_retention": [vlo + elec[0] + round(stor[3]["r2_usd_month"]),
                                                    vhi + elec[1] + round(stor[3]["r2_usd_month"])],
        "phase1_total_rented_server_12mo_retention": [vlo + slo + round(stor[12]["r2_usd_month"]),
                                                      vhi + shi + round(stor[12]["r2_usd_month"])],
        "slot_hours_needed_for_pilot": round(posts * 3 * t_job / 3600, 1),
        "slot_utilisation_of_one_slot": round(posts * 3 * t_job / (30 * day), 3),
    }

    # scale gap for a very large platform (order of magnitude only)
    out["slots_for_1e9_items_per_day"] = round(1e9 / (day / (3 * t_job)))

    res = {"inputs": INPUTS, "derived": out,
           "note": "Derived numbers inherit the labels of their inputs; any INFERRED input makes the result INFERRED."}
    path = Path(__file__).with_name("capacity_cost.json")
    path.write_text(json.dumps(res, indent=1, default=str) + "\n")
    print(json.dumps(out, indent=1, default=str))


if __name__ == "__main__":
    main()
