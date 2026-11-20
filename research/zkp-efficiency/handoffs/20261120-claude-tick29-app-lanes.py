#!/usr/bin/env python3
"""Tick 29 arithmetic: what the retained lane records say about 6 x 5 against 8 x 4 at the W16R2 classifier.

Reads only the retained prover logs of the 2026-11-13 benchmark (the `served` lines) and uses figures
copied from READMEs (cited in the handoff). Standard library, under a second, no run.
"""
import glob
import json
import os
import statistics

ROOT = "/Users/victorrielly/IntelligenceRegulation/results/zk60_coord_batch2_20261112/bench_logs"


def served(trial):
    out = []
    with open(os.path.join(ROOT, trial, "prover.log"), errors="replace") as f:
        for line in f:
            if '"event":"served"' in line:
                try:
                    out.append(json.loads(line)["seconds"])
                except Exception:
                    pass
    return out


def med(trials):
    xs = [x for t in trials for x in served(t)]
    return statistics.median(xs), len(xs)


# --- 1. a request's time with 3 lanes x 10 threads (one post, three at once) and 6 x 5 (the stream)
one_B, n1 = med(["one_1_B", "one_2_B"])
s8_B, n2 = med(["s8_1_B", "s8_2_B", "s8_defer_0_B"])
one_A, n3 = med(["one_0_A", "one_3_A"])
s8_A, n4 = med(["s8_0_A", "s8_3_A", "s8_defer_1_A"])
print(f"W16R2 (arm B): request median {one_B:.2f} s at 3 x 10 (n={n1}); {s8_B:.2f} s at 6 x 5 (n={n2}); stretch x{s8_B/one_B:.2f}")
print(f"R13   (arm A): request median {one_A:.2f} s at 3 x 10 (n={n3}); {s8_A:.2f} s at 6 x 5 (n={n4}); stretch x{s8_A/one_A:.2f}")


# --- 2. requests per second at 3 and 6 lanes, a two-point linear model c(N) = a + b N, and its prediction at 8
def model(c3, c6, label, measured8_over_6=None):
    r3, r6 = 3 / c3, 6 / c6
    b = (c6 - c3) / 3
    a = c3 - 3 * b
    r8 = 8 / (a + 8 * b)
    rinf = 1 / b
    print(f"{label}: 3 lanes {r3:.4f} req/s, 6 lanes {r6:.4f} req/s (x{r6/r3:.2f}); model c(N)=a+bN a={a:.2f} b={b:.2f}; "
          f"predicted 8 lanes {r8:.4f} req/s = x{r8/r6:.3f} over 6; N->inf bound {rinf:.4f} req/s = {rinf*128:.1f} tok/s")
    return r8 / r6


g_w = model(one_B, s8_B, "W16R2")
g_r = model(one_A, s8_A, "R13  ")
print("R13: model predicts x%.3f at 8 lanes; MEASURED at R13 (A27 8 x 4 against 6 x 5, ABBA): 16.51 / 16.49 = x%.3f" % (g_r, 16.51 / 16.49))
print("model overpredicts at R13 by %.1f points; same bias applied to W16R2: x%.3f" % (100 * (g_r - 16.51 / 16.49), g_w - (g_r - 16.51 / 16.49)))

# --- 3. what the stagger can and cannot do (figures from Astra's REVIEW.md and the coordination file)
stagger = 0.300
print(f"5 stagger steps = {5*stagger:.2f} s: the completion groups are 1.37 to 1.60 s wide (Astra), i.e. the first wave's spacing is carried unchanged")
outside = 3.4
print(f"outside-block part of a request {outside} s (coordinator 22:11:24Z): six starts {5*stagger:.2f} s apart overlap it for {outside-5*stagger:.2f} s with all six")
print(f"spacing six lanes evenly over the 19.405 s lane period needs {19.405/6:.2f} s per start; a constant stagger of that size caps the rate at {128/(19.405/6):.1f} tok/s")
lanes_full = 6 * 128 / 19.405
print(f"lanes-full rate {lanes_full:.2f} tok/s (6 x 128 / 19.405 s); cap by a constant stagger s: 128/s tok/s; s=3.2 s gives 40.0")
for s in (0.6, 1.0, 2.5, 2.8, 3.2):
    print(f"  stagger {s} s: ceiling {128/s:.1f} tok/s, {'binds' if 128/s < lanes_full else 'does not bind'} at the lanes-full rate")

# --- 4. GPU time per request against the lanes (coordinator / Astra figures)
gpu_per_req = 2.304
print(f"GPU union busy {gpu_per_req} s per request: 6 lanes at 19.405 s -> {6*gpu_per_req/19.405*100:.1f}% busy (Astra 72.7% from first commit A); ceiling {128/gpu_per_req:.1f} tok/s")
print(f"if the lane period stayed 19.405 s at 8 lanes: {8*128/19.405:.1f} tok/s, GPU {8*gpu_per_req/19.405*100:.1f}% busy (an upper bound, not a forecast: the period grows with lanes)")
