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

## ROUND 2 (coordinator request 2026-10-19: shares 2-4)

- 2026-10-19 09:24 — started round 2. Inputs share2/3/4 `extracted.txt`
  (untrusted). Native tree now R6; FN vs zkAttn not yet ruled; GPU slot 18 at
  25.9 ms (19.4% of 256 GB/s). Next: read share4 (division), share2, share3;
  classify; cost applicable items with variants.py; ROUND 2 section in REVIEW.md.
- 2026-10-19 09:32 — read all three shares. share4 (division): nothing new
  (multiplication-with-remainder = today's c2; derived residuals = done; FN =
  round-1 FN). share3: batch inversion (done), Groth16 orientation / MSM
  aggregation (n/a), compact tables + FFT boundaries (n/a), an exact ceil
  reciprocal (= round-1 EXR, two-sided so costlier) and an OBSERVED-PAIR
  QUOTIENT DICTIONARY (applicable). share2: separated dictionary + native
  assignment proof (= our architecture), non-ZK LogUp-GKR −15% (= D1, skips
  the privacy problem), Celer pointer (unverified). Key fact counted here: the
  8B exp tables (e_s 2/3/4, fE 9, hd 128) have 19/11/6 distinct outputs, so p
  takes <= 19 values per attention row -> per-row division dictionary "DD"
  with a PUBLIC capacity of 32 slots is privacy-safe and bit-exact.
  `variants_r2.py` (round-1 script untouched): 8B T512 DD −21.0% committed /
  −28.2% U8 / −20.1% terms (FN −22.8/−26.7/−20.7; EXR −7.6); L7+DD+VPE+IOR
  −34.0%, 23% bandwidth for 50/s = L7+L8. IOR (implied o8 range, sh_o = F_P)
  −0.6%. Next: ROUND 2 section in REVIEW.md.
- 2026-10-19 09:34 — ROUND 2 DONE. REVIEW.md: banner at the top pointing to
  the new section; "ROUND 2" section appended (R2.1 plain answer, R2.3
  21-row technique table for shares 2-4, R2.4 DD construction/exactness/
  privacy-shape/counts/robustness, R2.5 IOR, R2.6 direct answers, R2.7
  updated ranking + integrated sequence). Recommendation changed: DD replaces
  EXR and makes the FN-vs-zkAttn ruling optional; DD + VPE + IOR into the owed
  8B T512 profile; security owner's privacy note on a hidden table part in the
  LogUp identity is the gating review. Speed-plan folder untouched; nothing
  running.
