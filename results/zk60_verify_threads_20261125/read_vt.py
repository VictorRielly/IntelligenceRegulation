#!/usr/bin/env python3
"""Apply the reading posted in the coordination file (2026-11-25T16:09:40Z) to raw/<label>.results.json.

usage: read_vt.py <label>      (prints the reading; redirect it to READING_<label>.txt)
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent


def main() -> int:
    label = sys.argv[1]
    j = json.loads((HERE / "raw" / f"{label}.results.json").read_text())
    runs = j["runs"]
    L = j["blocks"]
    assert all(r["guard_exit"] == 0 and r["test_ok"] for r in runs) and len(runs) == len(j["order"]), "a process failed: the set is void"
    assert len({r["receipt_bytes"] for r in runs}) == 1
    print(f"set {label}: {L} blocks, binary sha256 {j['binary_sha256']}, order {','.join(j['order'])}, receipt {runs[0]['receipt_bytes']} B in every process")
    print("process  arm   serial verifier line, s   six-worker verifier line, s   started (UTC)")
    for r in runs:
        print(f"  {r['k']}      {r['arm']:<4}  {r['serial_verify_s']:>8.2f}                  {r['forks6_verify_s']:>8.2f}                     {r['started_utc']}")
    arm = {}
    forks = {}
    for r in runs:
        arm.setdefault(r["arm"], []).append(r["serial_verify_s"])
        forks.setdefault(r["arm"], []).append(r["forks6_verify_s"])
    assert all(len(v) == 2 for v in arm.values()), "two processes an arm"
    mean = {a: sum(v) / 2 for a, v in arm.items()}
    spread = {a: abs(v[0] - v[1]) / mean[a] for a, v in arm.items()}
    print()
    for a in ("p", "d", "t1", "t1d"):
        wide = "  (more than 10 percent: reported as a range)" if spread[a] > 0.10 else ""
        print(f"arm {a:<4} serial line: {arm[a][0]:.2f} and {arm[a][1]:.2f} s, mean {mean[a]:.3f} s, the two differ by {100 * spread[a]:.1f} percent of the mean{wide}; "
              f"six-worker line: {forks[a][0]:.2f} and {forks[a][1]:.2f} s")
    print()
    R = mean["t1"] / mean["p"]
    worst = min(arm["t1"]) / max(arm["p"])
    best = max(arm["t1"]) / min(arm["p"])
    use = worst if (spread["p"] > 0.10 or spread["t1"] > 0.10) else R
    print(f"Reading 1: R = mean(t1) / mean(p) = {R:.2f}; least favourable pair (smallest t1 over largest p) = {worst:.2f}; most favourable {best:.2f}")
    print(f"  the repeat rule {'applies (an arm differs by more than 10 percent)' if use == worst and use != R else 'does not apply'}: the figure read is {use:.2f}")
    if use >= 1.5:
        print("  at or above 1.5: the serial line is NOT a one-thread time; the split of 141.9 ms and the ranges built on it are withdrawn")
    elif use <= 1.15:
        print("  at or below 1.15: the serial line is a one-thread time; the split stands")
    else:
        print("  between 1.15 and 1.5: partly parallel; both figures reported, no range restated")
    print(f"  one-thread work a block (sparse loop on): mean(t1) / {L} = {1000 * mean['t1'] / L:.1f} ms ({1000 * min(arm['t1']) / L:.1f} to {1000 * max(arm['t1']) / L:.1f})")
    print(f"  one-thread work a block (dense loop):     mean(t1d) / {L} = {1000 * mean['t1d'] / L:.1f} ms ({1000 * min(arm['t1d']) / L:.1f} to {1000 * max(arm['t1d']) / L:.1f})")
    print(f"  default pool, serial verifier, a request: {min(arm['p']):.2f} to {max(arm['p']):.2f} s (sparse on); {min(arm['d']):.2f} to {max(arm['d']):.2f} s (dense)")
    print()
    s1 = mean["t1d"] - mean["t1"]
    sp = mean["d"] - mean["p"]
    print(f"Reading 2: one-thread saving of the sparse loop = mean(t1d) - mean(t1) = {s1:.3f} s a request = {1000 * s1 / L:.1f} ms a block "
          f"(pairs: {min(arm['t1d']) - max(arm['t1']):.2f} to {max(arm['t1d']) - min(arm['t1']):.2f} s)")
    print(f"  tick 60 bounded it at no more than 32 to 49 ms a block (1.0 to 1.6 s a request): the measured saving is {1000 * s1 / L / 49:.1f} to {1000 * s1 / L / 32:.1f} times that bound")
    print(f"  on the default pool: mean(d) - mean(p) = {sp:.3f} s a request (pairs: {min(arm['d']) - max(arm['p']):.2f} to {max(arm['d']) - min(arm['p']):.2f} s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
