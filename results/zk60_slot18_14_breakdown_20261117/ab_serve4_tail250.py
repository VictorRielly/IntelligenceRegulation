#!/usr/bin/env python3
"""Interleaved A/B/A/B `serve4` stream test of `HL_METAL_BATCH_TAIL_US=250` vs default (`25`) on unmodified `BIN_U`."""

from __future__ import annotations

import json
import pathlib
import re
import time
from typing import Dict, List

from analyze_slot_breakdown import OUT_DIR, RAW_DIR, median_iqr
from run_slot_breakdown import BIN_U, INTER_LEAF_SLEEP_S, run_guarded_leaf


def parse_serve4_log(txt: str) -> Dict[str, object]:
    verified_lines = [ln.strip() for ln in txt.splitlines() if "receipts verified" in ln]
    req_pat = re.compile(
        r"A22-AB REQ .*? \[serve4\] pass (\d+) request (\d+): .*?"
        r"\(sealing pass ([\d.]+) s\), prover .*?\(waited ([\d.]+) s; prove call ([\d.]+) s: "
        r"preflight [\d.]+, commit [\d.]+, forks ([\d.]+), join [\d.]+\), .*?result ([\d.]+);"
    )
    stream_pat = re.compile(r"A22-AB STREAM .*? \[serve4\] pass (\d+): .*?steady ([\d.]+) tok/s")

    by_pass_res: Dict[int, Dict[int, float]] = {}
    prove_s: List[float] = []
    forks_s: List[float] = []
    wait_s: List[float] = []
    seal_ov_s: List[float] = []

    for m in req_pat.finditer(txt):
        p, r = int(m.group(1)), int(m.group(2))
        seal, wt, prv, frk, res_t = (
            float(m.group(3)),
            float(m.group(4)),
            float(m.group(5)),
            float(m.group(6)),
            float(m.group(7)),
        )
        by_pass_res.setdefault(p, {})[r] = res_t
        prove_s.append(prv)
        forks_s.append(frk)
        if r >= 1:
            seal_ov_s.append(seal)
            wait_s.append(wt)

    pass_cadences = [
        (rmap[3] - rmap[0]) / 3.0
        for _, rmap in sorted(by_pass_res.items())
        if 0 in rmap and 3 in rmap
    ]
    pass_toks = [float(m.group(2)) for m in stream_pat.finditer(txt)]

    return {
        "verified_lines": verified_lines,
        "warm_passes_parsed": len(pass_cadences),
        "cadences_s": [round(x, 4) for x in pass_cadences],
        "tok_s": [round(x, 2) for x in pass_toks],
        "cadence_median_s": round(median_iqr(pass_cadences)[0], 4),
        "tok_s_median": round(median_iqr(pass_toks)[0], 2),
        "prove_median_s": round(median_iqr(prove_s)[0], 4),
        "forks_median_s": round(median_iqr(forks_s)[0], 4),
        "seal_ov_median_s": round(median_iqr(seal_ov_s)[0], 4),
        "prover_wait_median_s": round(median_iqr(wait_s)[0], 4),
    }


def main() -> None:
    schedule = [
        ("serve4_1A_default25", {}),
        ("serve4_2B_tail250", {"HL_METAL_BATCH_TAIL_US": "250"}),
        ("serve4_3A_default25", {}),
        ("serve4_4B_tail250", {"HL_METAL_BATCH_TAIL_US": "250"}),
    ]
    base_env = {
        "HL_GPU": "1",
        "HL_GPU_REQUIRED": "1",
        "HL_PB_ORACLE": "0",
        "HL_METAL_TIMING": "0",
        "HL_D55_PROFILE": "W16R2_8B_T128_H24",
        "HL_D55_L": "32",
        "HL_D55_WORKERS": "6",
        "HL_A19_BUDGET_GIB": "32",
        "HL_A22_AB_PASSES": "6",
        "HL_A22_AB": "serve4",
    }

    runs = []
    for idx, (label, extra) in enumerate(schedule):
        if idx > 0:
            time.sleep(INTER_LEAF_SLEEP_S)
        res = run_guarded_leaf(
            label=label,
            guard_class="gpu",
            need_gib=40,
            cap_gib=52,
            max_secs=600,
            cmd=[
                str(BIN_U),
                "--ignored",
                "--exact",
                "--nocapture",
                "private_block::run::fork::tests::a22::a22_stream_ab",
            ],
            extra_env={**base_env, **extra},
        )
        combined_txt = (RAW_DIR / f"{label}.log").read_text() + "\n" + (RAW_DIR / f"{label}.guard.txt").read_text()
        parsed = parse_serve4_log(combined_txt)
        guard_lines = [ln for ln in str(res["guard_stderr"]).splitlines() if ln.startswith("[zk60-guard")]
        entry = {
            "label": label,
            "guard_lines": guard_lines,
            "pre_ds4_bench": res["pre_ds4_bench"],
            "post_ds4_bench": res["post_ds4_bench"],
            **parsed,
        }
        runs.append(entry)
        print(f"[DONE] {label}: cad={entry['cadence_median_s']}s tok/s={entry['tok_s_median']} verified={len(entry['verified_lines'])}", flush=True)

    (OUT_DIR / "ab_serve4_tail250.json").write_text(json.dumps(runs, indent=2) + "\n")
    print("ALL SERVE4 A/B RUNS COMPLETE!", flush=True)


if __name__ == "__main__":
    main()
