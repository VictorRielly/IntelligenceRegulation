#!/usr/bin/env python3
"""Projection arithmetic for the VC readiness note (2026-09-29).

Reads ONLY retained evidence (no prover, no GPU, no model):
  * the four non-warm phase logs of the dense 125M CPU/GPU A/B
    (results/zk60_sol_gpu_20260927/attempt-5-dense-ab/{a1,a2}-cpu.log, {b1,b2}-gpu.log),
    whose SHA-256 must equal the values recorded in that directory's report.json;
  * the layout constructors' committed-row counts
    (results/zk60_sol_model_20260927/layout_account.json: m125 control and the
    Mistral/Llama-3-8B block geometry probe at T512;
     results/zk60_1b_model_20260927/layout_ladder.json: TinyLlama T512 log_cols 14).

Every output number except the measured 125M inputs is a PROJECTION [MODEL].
Run:  python3 results/zk60_vc_readiness_20260929/extrapolate.py
Writes extrapolation.json next to this script and prints the tables.
"""
import hashlib
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
AB = REPO / "results/zk60_sol_gpu_20260927/attempt-5-dense-ab"
T = 512           # token positions per full-stack pass, counted once
TARGET = 50.0     # proved tokens/s

# ---- geometry -------------------------------------------------------------
lay = json.loads((REPO / "results/zk60_sol_model_20260927/layout_account.json").read_text())
lad = json.loads((REPO / "results/zk60_1b_model_20260927/layout_ladder.json").read_text())["cases"]
tiny = lad["tinyllama_t512_lc14_probe"]
GEOM = {
    # d, f (true), f_pad, H (query heads), KV, dh, layers, A rows, H rows, endpoint rows, receipt/block
    "m125": dict(d=768, d_pad=1024, f=2048, f_pad=2048, H=12, H_pad=16, KV=4, dh=64, L=12,
                 A=lay["m125"]["rows"]["A"], Hr=lay["m125"]["rows"]["Hrows"],
                 ep=lay["m125"]["rows"]["endpoint_rows"],
                 receipt=lay["m125"]["receipt_counted_bytes_per_block"]),
    "1B_tinyllama": dict(d=2048, d_pad=2048, f=5632, f_pad=8192, H=32, H_pad=32, KV=4, dh=64, L=22,
                         A=tiny["A_rows"], Hr=tiny["H_rows"], ep=tiny["endpoint_rows"],
                         receipt=tiny["receipt_bytes_per_block_counted"]),
    "8B_llama3": dict(d=4096, d_pad=4096, f=14336, f_pad=16384, H=32, H_pad=32, KV=8, dh=128, L=32,
                      A=lay["mistral_t512_probe"]["rows"]["A"], Hr=lay["mistral_t512_probe"]["rows"]["Hrows"],
                      ep=lay["mistral_t512_probe"]["rows"]["endpoint_rows"],
                      receipt=lay["mistral_t512_probe"]["receipt_counted_bytes_per_block"]),
}
assert GEOM["m125"]["A"] == 5681 and GEOM["m125"]["Hr"] == 7120, "m125 control rows moved"
assert GEOM["m125"]["receipt"] == 40783352, "m125 counted receipt moved"


def linear_macs(g):
    d, f, H, KV, dh = g["d"], g["f"], g["H"], g["KV"], g["dh"]
    return T * (d * H * dh + 2 * d * KV * dh + H * dh * d + 3 * d * f)


def pow2(n):
    p = 1
    while p < n:
        p *= 2
    return p


def factors(g, b):
    """Growth of each phase's domain from the 125M block b to geometry g."""
    return {
        "A": g["A"] / b["A"],
        "H": g["Hr"] / b["Hr"],
        "Td": g["d_pad"] / b["d_pad"],                    # T x d planes (norms, D zero-check, endpoints)
        "Tq": pow2(g["H"] * g["dh"]) / pow2(b["H"] * b["dh"]),  # T x (H*dh), padded (768 -> 1024)
        "Tkv": (g["KV"] * g["dh"]) / (b["KV"] * b["dh"]),
        "Tf": g["f_pad"] / b["f_pad"],
        "S": g["H_pad"] / b["H_pad"],                     # H_pad x T^2 attention domain
        "dh": g["dh"] / b["dh"],
        "ep": g["ep"] / b["ep"],
        "one": 1.0,
    }


RULES = [  # (substring of the phase name, factor key); first match wins
    ("A: ", "A"), ("M: ", "one"), ("H: ", "H"),
    ("slot 00", "Td"), ("slot 01", "Td"), ("slot 02", "one"), ("slot 03", "one"),
    ("slot 04", "S"), ("slot 05", "Td"), ("slot 06", "Td"), ("slot 07", "Td"),
    ("slot 08", "dh"), ("slot 09", "S"), ("slot 10", "Tq"), ("slot 11", "Td"),
    ("slot 12", "Td"), ("slot 13", "Tf"), ("slot 14", "Td"), ("slot 15", "Tq"),
    ("slot 16", "Tkv"), ("slot 17", "S"), ("slot 18", "Tf"), ("slot 19", "one"),
    ("slot 20", "one"), ("slot 21", "Td"), ("slot 22", "Td"),
    ("open M", "one"), ("verify M", "one"), ("open A", "A"), ("verify A", "A"),
    ("open H", "H"), ("verify H", "H"), ("endpoint", "ep"), ("setup", "one"),
    ("transcript header", "one"),
]
GPU_PHASES = ("A: commit", "H: commit")  # the only device phases in the measured GPU arm


def rule(name):
    for key, fac in RULES:
        if key in name:
            return fac
    raise KeyError(name)


# ---- measured inputs -------------------------------------------------------
report = json.loads((AB / "report.json").read_text())
want = {r["log"]: r["log_sha256"] for r in report["runs"]}
ROW = re.compile(r"^PB-TIMING (prove|verify) \| (.+?)\s+\| (\S+)\s+\|\s+([0-9.]+) \|")
arms = {"cpu": ["a1-cpu.log", "a2-cpu.log"], "gpu": ["b1-gpu.log", "b2-gpu.log"]}
measured = {}
for arm, logs in arms.items():
    acc = {"prove": {}, "verify": {}}
    wit = []
    for log in logs:
        body = (AB / log).read_bytes()
        assert hashlib.sha256(body).hexdigest() == want[log], f"{log} hash differs from report.json"
        for line in body.decode().splitlines():
            m = ROW.match(line)
            if m and m.group(2).strip() not in ("phase", "SUM OF PHASES", "WALL CLOCK OF THE CALL",
                                                "unaccounted (wall - sum)", "encode to bytes (wire::encode)",
                                                "decode from bytes (wire::decode)"):
                acc[m.group(1)].setdefault(m.group(2).strip(), []).append(float(m.group(4)))
            w = re.search(r"witness built in ([0-9.]+) s", line)
            if w:
                wit.append(float(w.group(1)))
    measured[arm] = {
        "prove": {k: sum(v) / len(v) for k, v in acc["prove"].items()},
        "verify": {k: sum(v) / len(v) for k, v in acc["verify"].items()},
        "witness": sum(wit) / len(wit),
        "residual_once": report["nonwarm_arm_means"][arm]["serialize_and_other_seconds"],
    }
for arm in arms:
    s = sum(measured[arm]["prove"].values())
    assert abs(s - report["nonwarm_arm_means"][arm]["prove_seconds"]) < 0.05, (arm, s)


def block(arm, gname):
    g, b = GEOM[gname], GEOM["m125"]
    fac = factors(g, b)
    ph = measured[arm]["prove"]
    prove = sum(v * fac[rule(k)] for k, v in ph.items())
    gpu_part = sum(v * fac[rule(k)] for k, v in ph.items() if arm == "gpu" and k.startswith(GPU_PHASES))
    verify = sum(v * fac[rule(k)] for k, v in measured[arm]["verify"].items())
    wit = measured[arm]["witness"]
    return {
        "prove_s": prove, "gpu_share_s": gpu_part, "cpu_share_s": prove - gpu_part,
        "verify_s": verify,
        "witness_rows_scaled_s": wit * (g["A"] / b["A"]),
        "witness_macs_scaled_s": wit * linear_macs(g) / linear_macs(b),
        "prove_growth_vs_125m": prove / sum(ph.values()),
        "rows_growth_vs_125m": (g["A"] + g["Hr"]) / (b["A"] + b["Hr"]),
        "receipt_bytes_counted": g["receipt"],
    }


out = {"inputs": {"T": T, "target_tokens_per_s": TARGET,
                  "log_sha256": want, "measured_arm_means": report["nonwarm_arm_means"]},
       "geometry": GEOM, "per_block": {}, "stack": {}, "scenarios": {}}
for arm in arms:
    for gname in GEOM:
        pb = block(arm, gname)
        L = GEOM[gname]["L"]
        res = measured[arm]["residual_once"]
        prove_stack = L * pb["prove_s"]
        e2e_lo = L * (pb["prove_s"] + pb["witness_rows_scaled_s"]) + res
        e2e_hi = L * (pb["prove_s"] + pb["witness_macs_scaled_s"]) + res
        out["per_block"][f"{arm}/{gname}"] = pb
        out["stack"][f"{arm}/{gname}"] = {
            "blocks": L, "prove_only_s": prove_stack, "prove_only_tok_s": T / prove_stack,
            "gap_prove_only_x": TARGET / (T / prove_stack),
            "end_to_end_s_range": [e2e_lo, e2e_hi],
            "end_to_end_tok_s_range": [T / e2e_hi, T / e2e_lo],
            "verify_stack_s": L * pb["verify_s"],
            "receipt_stack_bytes_counted": L * pb["receipt_bytes_counted"],
        }

# ---- hardware / software scenarios (all factors are ASSUMPTIONS, none measured) ----
SCEN = {
    "S1_5090_box_todays_code": {
        "what": "commitments on the 5090 (4-6x the laptop GPU, START_HERE's recorded board factor, never measured); "
                "all other phases on a desktop host CPU with more threads (2-4x the 2-thread A/B, unmeasured)",
        "gpu_div": (4.0, 6.0), "cpu_div": (2.0, 4.0)},
    "S2_4070_all_sumchecks_on_device": {
        "what": "every CPU phase ported to the laptop GPU at 5-10x the 2-thread CPU (basis: the legacy public FFN line, "
                "285 s CPU 8-thread vs 38.6 s GPU activation side on this laptop = 7.4x); NOT BUILT",
        "gpu_div": (1.0, 1.0), "cpu_div": (5.0, 10.0)},
    "S3_5090_all_sumchecks_on_device": {
        "what": "S2 then the 5090 board factor 4-6x on everything; NOT BUILT, never measured",
        "gpu_div": (4.0, 6.0), "cpu_div": (20.0, 60.0)},
}
for sname, sc in SCEN.items():
    for gname in ("1B_tinyllama", "8B_llama3"):
        pb = out["per_block"][f"gpu/{gname}"]
        L = GEOM[gname]["L"]
        slow = pb["gpu_share_s"] / sc["gpu_div"][0] + pb["cpu_share_s"] / sc["cpu_div"][0]
        fast = pb["gpu_share_s"] / sc["gpu_div"][1] + pb["cpu_share_s"] / sc["cpu_div"][1]
        out["scenarios"][f"{sname}/{gname}"] = {
            "what": sc["what"], "per_block_prove_s_range": [fast, slow],
            "stack_prove_s_range": [L * fast, L * slow],
            "prove_only_tok_s_range": [T / (L * slow), T / (L * fast)],
            "gap_to_50_x_range": [TARGET / (T / (L * fast)), TARGET / (T / (L * slow))],
        }

(HERE / "extrapolation.json").write_text(json.dumps(out, indent=2) + "\n")


def f(x, n=1):
    return f"{x:,.{n}f}"


print("per-block prove [s]  (measured at m125; projected elsewhere)")
for k, v in out["per_block"].items():
    print(f"  {k:22s} prove {f(v['prove_s'],2):>7s}  gpu {f(v['gpu_share_s'],2):>6s}  growth x{v['prove_growth_vs_125m']:.2f}"
          f" (rows x{v['rows_growth_vs_125m']:.2f})  witness {f(v['witness_rows_scaled_s'],1)}-{f(v['witness_macs_scaled_s'],1)}"
          f"  verify {f(v['verify_s'],2)}  receipt {v['receipt_bytes_counted']/1e6:.1f} MB")
print("full stack at T=512")
for k, v in out["stack"].items():
    lo, hi = v["end_to_end_tok_s_range"]
    print(f"  {k:22s} L={v['blocks']:2d} prove-only {f(v['prove_only_s'],0):>6s} s = {v['prove_only_tok_s']:.2f} tok/s"
          f" (gap x{v['gap_prove_only_x']:.0f}); end-to-end {lo:.2f}-{hi:.2f} tok/s; verify {f(v['verify_stack_s'],0)} s;"
          f" receipt {v['receipt_stack_bytes_counted']/1e9:.2f} GB")
print("scenarios (prove-only, T=512)")
for k, v in out["scenarios"].items():
    a, b = v["prove_only_tok_s_range"]
    g1, g2 = v["gap_to_50_x_range"]
    s1, s2 = v["stack_prove_s_range"]
    print(f"  {k:45s} stack {f(s1,0)}-{f(s2,0)} s  {a:.2f}-{b:.2f} tok/s  gap x{g1:.1f}-{g2:.1f}")
