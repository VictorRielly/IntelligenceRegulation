# ZKP efficiency progress

Cycle0036 — `20261012T172555Z-e8207bdf`, checkpoint 2026-10-12T17:45:06.160424+00:00.

**A four-reduction Fp2 candidate passed synthetic checks; no proving speed gain was measured.** 54,848 multiply-accumulate/product cases, matching CUDA limb emulations, 64 source-derived SC_SZC fixtures and 19 controls passed. The final experiment took 3.60 seconds and 17,736 KiB peak RSS on one pinned, low-priority Core Ultra9 185H thread, within the 59-second/512-MiB caps.

Canonical headroom permits four reductions instead of five. Global Fp2 replacement removes 18.79% of counted reductions in the illustrated scan/fold census; the weighted-only change removes 0.60% and is included in the global figure. Multiplications remain. Wider carry additions, compiler simplification and register costs could erase the benefit. Native performance and the complete-proof ceiling remain unknown.

[Evidence and unapplied Rust/CUDA sketches](experiments/fp2-fused-mac-20261012/README.md) and an [owner handoff](handoffs/20261012-fp2-four-reduction.md) are saved. Seams are Fp2 multiplication, grouped weighted samples and CUDA f2_mul. Native code is uncompiled; production is untouched. The interrupted wide-accumulation cycle's evidence and six original-date source records are recovered. Four current LIVE primary records cover Plonky2, gnark's October release, zkLLMPoT and older ZK sumcheck. Fetch failures are recorded; author performance was not reproduced.

Accepted independently verified complete private8B proofs/passes: **0**; countable tokens: **0**. Device: CPU only; proof context: null. Steady-state and total-workload rates, startup fraction, witness/proof/serialization/independent-verification clocks and proof lag/drain are unmeasured. No prefill, resident-model pass or decode proof occurred. The >=50-token/s target remains unachieved. Larger workloads are allowed; quadratic attention growth and fresh masks remain obligations.

Next owner action: canonical-caller/compiler audit, then guarded native correctness and complete-block A/B with independent verification. Next local cycle: padded causal-mask descriptors versus explicit MLE, charging evaluation/scratch costs and preserving future-score checks. No heavy job is queued. Saved reports do not establish external notification delivery.
