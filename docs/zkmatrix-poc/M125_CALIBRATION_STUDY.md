# The frugal-lm 125M int8 Calibration Study (U-AG-B1, Agent BC)

Status: SKELETON (2026-08-08, lane BC). Section map:

- Section 1: the checkpoint (provenance, completeness, shapes) and
  the contract semantics applied (TARGET_CONTRACT Section 2 at 125M
  inner dims — honest accumulator re-derivation 768/2048)
- Section 2: weight quantization — per-layer/per-tensor ranges,
  power-of-two scale table, saturation, error
- Section 3: activation sampling — the batch, per-point ranges and
  scales, clipping rates
- Section 4: the int8-simulated FFN pass vs bf16 — error growth,
  val-loss delta, range facts
- Section 5: VERDICT row (does the model CALIBRATE under the
  contract's range-fact semantics) + the exports lane BB's statement
  needs (exact tensor dims, ranges, scale table)

(Content lands after scripts/m125_int8_calibration.py runs.)
