# A29: one calibration for all 26 Shieldstral layers (D77 (2), route (b)), the accuracy experiment

Lane A29 built the design and the export. The coordinator finished it: the census excerpts, the calibration
diagnostics, the held-out comparison and this README. That was done because the lane handed back before the
measurements ended. Every number here is MEASURED unless marked.

## In plain words, for Victor

**What was tested.** The media app's classifier runs in the R13 proof format. The faster W16R2 format (about 22–25
proved tok/s on the app's stream, against 16.9 now: lane A28's ESTIMATE) refused the real Shieldstral export. The
reason: its 26 layers use 17 different requantization-shift sets, and W16R2's layout depends on them. You chose
route (b): one shift set and one gate value for all 26 layers, if accuracy holds.

**The result: it works, and accuracy is as good as today's export.**
- **The format accepts every layer.** With the single calibration, the W16R2 acceptance check admits all 26 layers,
  with ONE layout (A 72, H 44). On today's export the same check refuses 8 layers and needs 3 layouts.
  (`census_uniform.txt`, `census_current.txt`.)
- **No refusals.** On the 4,872 held-out evaluation rows (12 policy groups, two decision heads), the single
  calibration refuses NO item. Today's export refuses 6 (at layer 12).
- **Agreement with the float model is unchanged.** On accepted rows it stays between 97.5% and 100% in every group,
  within a quarter of a percentage point of today's export, sometimes above and sometimes below. Compared with
  today's export, at most 3 decisions change in about 610 rows per group.
- **F1 against the float model is unchanged.** On the refusal-free head, two groups' integer F1 is about 3% below the
  float model's: openai_mod cat_violence (0.652 against 0.672) and mod_violence (0.648 against 0.668). Today's
  export is the same or worse there (0.640 and 0.648). Every other group is within about 1% of the float model or
  above it.

**Against D32 ("no performance degradation versus the float model").** D32 names no metric for the classifier, so it
is read two ways:
- **No worse than today's export:** PASS. The single calibration has zero refusals where today's has six, and its
  agreement and F1 are the same within noise.
- **Strictly within 2% of the float model's F1 in every group:** neither export passes. Both miss the same two groups
  on the refusal-free head. On the calibrated head both pass.

**Recommendation: treat route (b) as passing.** It is at least as faithful to the float model as the export the app
uses today, and it removes the refusals. Then the faster format needs, in order:
1. the profile for this export, with review;
2. the W16R2 privacy gate on GPU-made bundles (D55 / D60's conditions);
3. the Lean re-proof of the parts it touches. The per-block-shape Lean model (lane L40) already fits a calibration
   like this one;
4. the app's speed measured on it.

If you want the strict reading instead, the misses are on the refusal-free head only. The fix is a head question, not
a calibration question, and it applies to today's export as well.

## What was changed (`build_uniform.py`, `export_u1_build.json`)
- **The single calibration:** `sh_ao 7, sh_s 7, sh_z 8`, gate denominator 20, for all 26 layers. Each value is the
  most common one in the real model. The set was chosen to give one W16R2 layout equal to the run seed's (72, 44).
- **What stays per layer:** the norm constants `cn_a`, `cn_m` and `sh_h`. They do not enter the W16R2 layout
  (`range16::widths`, `NormCalibration`; reproduced against A25's measured census), so they remain per-layer
  coefficients.
- **How the layers were moved:** 8 layers are unchanged. 18 layers have 54 payloads changed: exact re-expressions
  first (a shift moved by one with its multiplier doubled or halved), and the pipeline's own re-fit rule from the
  float weights elsewhere.
- **Clipping:** 66 public weight words are clipped in the whole model.
- **Layer 12** is Astra's paired score candidate.
- **Where it lives:** outside the repository, `/Users/victorrielly/zk60-artifacts/a29-uniform-calibration/export_u1`,
  profile digest `9464388091d8095f8491f2990fde54e3b1f2b06f2a5c6ad1e72eff09cd4ce20a`.

## Evidence
- **`census_uniform.txt` / `census_current.txt`:** lane A25's W16R2 census test run on the new export and on today's
  export. It admits 26 of 26 with 1 layout, against 8 refused with 3 layouts. A25's last assertion ("layer 0 is
  refused") fails on the new export by design.
- **`diag_calibration_summary.json`:** the 192 CALIBRATION sequences only (design-time, not held out). Both exports
  have zero refusals and zero range violations in every layer. The per-layer error against float is slightly higher
  with one calibration (about 0.384 against 0.371 in the middle layers). Both classifier heads agree in sign with the
  float model on all 192 sequences.
- **`comparison.md` / `comparison.json`:** the held-out A1 evaluation, 4,872 rows and both heads, for today's export,
  Astra's L12 candidate and the single calibration.
- **`eval_uniform_fidelity.json`:** the export lane's unchanged `analyze_verdicts` on the single calibration, metrics
  only.
- **Held-out status.** The 4,872 rows played no part in A29's choices; the design used the calibration data only.
  They had been seen before by the export lane: its L12 candidate was chosen after them.

No protocol, profile, prover, receipt or app file changed; no privacy-gate run.
