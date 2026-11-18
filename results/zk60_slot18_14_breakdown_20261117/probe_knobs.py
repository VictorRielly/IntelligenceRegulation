#!/usr/bin/env python3
"""Zero-edit probe of `HL_METAL_BATCH_TAIL_US` and `HL_METAL_SC_TG` on unmodified `BIN_U`."""

from __future__ import annotations

import json
import pathlib
import time

from analyze_slot_breakdown import (
    EXT_DIR,
    OUT_DIR,
    RAW_DIR,
    median_iqr,
    parse_m4_summary,
    parse_trace_passes,
    summarize_batched_arm,
)
from run_slot_breakdown import BIN_U, INTER_LEAF_SLEEP_S, WARM_PASSES, run_guarded_leaf


def main() -> None:
    knobs = [
        ("knob_tail250", {"HL_METAL_BATCH": "1", "HL_METAL_BATCH_TAIL_US": "250"}),
        ("knob_tail500", {"HL_METAL_BATCH": "1", "HL_METAL_BATCH_TAIL_US": "500"}),
        ("knob_tg256_th18", {"HL_METAL_BATCH": "1", "HL_METAL_SC_TG": "256", "HL_METAL_SC_THREADS": "18"}),
    ]
    results = {}
    for kname, kenv in knobs:
        label = f"w16r2_8b_{kname}"
        trace_prefix = str(EXT_DIR / label)
        res = run_guarded_leaf(
            label=label,
            guard_class="gpu",
            need_gib=12,
            cap_gib=24,
            max_secs=300,
            cmd=[
                str(BIN_U),
                "--exact",
                "private_block::slot_ir::accuracy::tests::m4_trained_accuracy_block_cpu_and_metal_digests_and_times",
                "--ignored",
                "--nocapture",
            ],
            extra_env={
                "HL_GPU_REQUIRED": "1",
                "HL_M4_PROFILES": "W16R2_8B_T128_H24",
                "HL_M4_WARM_PASSES": str(WARM_PASSES),
                "HL_A27_GPU_TRACE": trace_prefix,
                "HL_METAL_TIMING": "1",
                **kenv,
            },
        )
        m4_rows = parse_m4_summary(RAW_DIR / f"{label}.guard.txt")
        warm_m4 = [r for r in m4_rows if r["pass_kind"] == "warm"]
        assert all(r["cpu_digest"] == r["metal_digest"] for r in m4_rows)
        all_passes = parse_trace_passes(pathlib.Path(res["trace_gz_files"][0]))
        warm_passes = all_passes[1:]
        bat = summarize_batched_arm(warm_passes)
        guard_lines = [ln for ln in str(res["guard_stderr"]).splitlines() if ln.startswith("[zk60-guard")]
        results[label] = {
            "guard_lines": guard_lines,
            "pre_ds4_bench": res["pre_ds4_bench"],
            "post_ds4_bench": res["post_ds4_bench"],
            "digest": m4_rows[0]["metal_digest"],
            "metal_wall_median_s": round(median_iqr([r["metal_s"] for r in warm_m4])[0], 4),
            "metal_core_median_s": round(median_iqr([r["metal_core_s"] for r in warm_m4])[0], 4),
            "dev_sc_median_s": round(median_iqr([r["dev_sc_s"] for r in warm_m4])[0], 4),
            "categories_ms": bat["categories_ms"],
            "top_slots_ms": bat["slots_sorted_ms"][:6],
        }
        print(f"[DONE] {label}: core={results[label]['metal_core_median_s']}s gpu_slots={bat['categories_ms'].get('all_slots_gpu_ms')}ms", flush=True)
        time.sleep(INTER_LEAF_SLEEP_S)

    (OUT_DIR / "knob_probe.json").write_text(json.dumps(results, indent=2) + "\n")
    print("Wrote knob_probe.json", flush=True)


if __name__ == "__main__":
    main()
