# PROGRESS — GPT nonlinear-ZKP conversation review (research review lane)

Lane: paper + one-thread Python (< few s). No builds, proofs, git writes.
Write set: `results/zk60_gpt_nonlinear_review_20261018/` only.
Input: `gpt_share_extracted.txt` (untrusted data, ~289 KB, 3306 lines).
Deliverable: `REVIEW.md` (plain answer first, per-technique table, details).

## Log (UTC from `date -u`)

- 2026-10-18 02:53 — started; read LANE_RULES_20261017.md. Next: read speed
  plan, native construction (layout.rs / argument.rs / protocol.rs), soundness
  recount, decisions, researcher FINDINGS; then the conversation.
- 2026-10-18 03:03 — read: speed plan (all), layout.rs (all), argument.rs
  helper_sum/SC_DZC/SC_FZC/SC_SZC/SC_TAB/SC_SS/PV/DMM, soundness RECOUNT §1,
  decisions D12–D27 headings, researcher FINDINGS (grep) + LogUp handoffs, and
  the WHOLE conversation (3306 lines; it is a gnark/Groth16 BN254 "expzk"
  exponential-gadget project, public IO, 200k-point exp grid, 8 CPU workers).
  Technique list drafted (~30 items). Applicable candidates found:
  (1) shared row reciprocal — made BIT-EXACT here with B >= fE + wrho_s
  (byte-aligned B = 32 at 8B T512) and a ONE-sided zr window; (2) attention
  output normalisation after PV ("fused normalisation", needs a numerical-
  contract ruling); (3) the "derive, don't store" rule applied to value planes
  that also carry full byte limbs (X, AO, X1, X2, Z16, U16, H16, P).
  Next: variants.py (counts at 8B T512 via the plan's layout replica, imported
  read-only with -B), exactness checks, then REVIEW.md. numpy not installed:
  pure-Python checks only.
- 2026-10-18 03:09 — `variants.py` written and run (1.5 s, one thread; output
  `variants.out.txt`, data `variants.json`; no __pycache__ left in the plan's
  folder). Results: EXR exact (0 mismatches in 140,708 exhaustive small cases
  and 485,744 sampled 8B cases at B = 27 and 32; B = 26 fails, so the bound
  bites); admissible at 8B T512 for fE <= 10 (wrap limit). 8B T512 counts:
  EXR -7.6% committed / -10.9% U8 / -5.0% zero-check element-terms; VPE -5.4 /
  0 / -7.2; FN -22.8 / -26.7 / -20.7; L7+FN+VPE ~= L7+L8 (54.5 vs 54.4
  positions/s at 25% roofline). Synthetic FN fidelity: o8 changes in 53% of
  outputs, error vs float 0.26 vs 0.64 units (indicative only). Plan anchors
  reproduced (today 37.1/57.3, L7 45.6/69.9, L7+L8 54.4/82.9; 34/28/23% bw).
  Next: REVIEW.md.
- 2026-10-18 03:12 — DONE. `REVIEW.md` written: plain answer (§1), 30-row
  technique table (§3), why most does not transfer (§4), EXR lemma + checks +
  admissibility (§5.1), FN (§5.2), VPE (§5.3), ranking vs the speed plan with
  an integrated sequence (§6), claims checked (§7). Speed-plan folder verified
  untouched. Nothing running. Next concrete step for the coordinator: put the
  FN-vs-L8 numerical-contract question to Victor; write VPE (and EXR if FN is
  declined) into the owed 8B T512 profile spec with a soundness review of the
  EXR lemma and a privacy-gate re-run; calibration lane to confirm fE <= 10 at
  T512 (EXR admissibility) or measure FN fidelity on real activations.
