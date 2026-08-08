#!/usr/bin/env python3
"""m125_int8_calibration.py — U-AG-B1 Agent BC: the frugal-lm 125M int8
calibration study (LLM_POC_ROADMAP.md risk 5 de-risk).

Reads the frugal-lm 125M checkpoint READ-ONLY
(/Users/victorrielly/frugal-lm/runs/125m-baseline/ckpt-00009536,
completed 2.5e9-token run) and studies, per TARGET_CONTRACT.md
Section 2 semantics (int8 symmetric, power-of-two scales, floor
requantization x = 2^shift * y + r with r in [0, 2^shift)):

  1. WEIGHTS: quantize the 12 layers' FFN tensors (w_gate, w_up,
     w_down) — ranges, chosen power-of-two scales, saturation counts,
     quantization error.
  2. ACTIVATIONS (MLX inference, read-only; frugal-lm's venv): sample
     the FFN chain on a small seeded fineweb-edu-val batch — X (the
     mlp_norm output), gate, up, a = SiLU(gate), h = a o up, z (the
     down output) — ranges, scales, clipping.
  3. ACCUMULATORS: honest widths at the 125M inner dims 768/2048
     (the contract's 27/29-bit rows are for 4096/11008), measured
     max |acc| vs worst case.
  4. INT8 SIMULATION: the quantized FFN forward per contract
     semantics vs the bf16 reference — per-layer error, end-to-end
     val-loss delta, range-fact verdict.

Outputs: printed tables + results/m125_int8_calibration.json.
Verdict + exports land in docs/zkmatrix-poc/M125_CALIBRATION_STUDY.md.

Run with frugal-lm's venv (mlx + safetensors + numpy):
  /Users/victorrielly/frugal-lm/.venv/bin/python \
      scripts/m125_int8_calibration.py
Weights-only mode (no mlx available): falls back automatically.
Seeded; single run < ~2 min on the Mac box; never writes under
/Users/victorrielly/frugal-lm.
"""

# (implementation lands in the next commits)

if __name__ == "__main__":
    raise SystemExit("skeleton — implementation lands in the next commits")
