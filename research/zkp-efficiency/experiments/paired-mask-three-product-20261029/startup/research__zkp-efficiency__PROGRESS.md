# ZKP efficiency progress

Cycle 0136 complete — `20261029T055649Z-74b83633`, 2026-10-29 UTC.

**No native proving improvement found.** A CPU model based on the native source shares one
public equality table across SC_TAB's six separate private mask pairs. At row
length 16,384, constructor multiplications fall from 196,596 to 32,766; private mask reads
are unchanged. Key handling and longer scratch lifetime add costs.

The model passes 1,042 checks across 102 synthetic fixtures and 13 deliberately
wrong control families. It took 1.528 seconds and 41,284 KiB on one Core Ultra 9
185H worker. A separate source, count and patch audit passes 75 checks.
An SC_TAB-only Rust patch is saved, uncompiled and unapplied. No native or GPU run.

The retained TinyLlama T128 GPU-assisted run spent 0.55 seconds of 135.809 seconds
in the entire affected extension phase. Even free whole-phase deletion gives
only about 0.41% speedup there; actual savings are smaller. This supplies no 8B forecast.
Whole-prover GPU and verified resident workloads remain higher priority.

Ten LIVE primary-source records added, 891 → 901. All 52 prior hypotheses remain,
with two additions. Owner next: measure equality preparation, mask-row evaluation
and enclosing proof time. Local next: review prior arithmetic negatives before
a paired-mask dot-product study.

New verified full-stack proofs / passes / positions: **0 / 0 / 0**. Actual model
context / accelerator: none. Witness, proof, serialization, verification,
startup / prefill duration and fraction, latency, bytes, steady-state and
total-workload rates: **unmeasured**. No long prefill, resident proof series
or decode. Private 8B at ≥50 proved tokens/s remains unachieved. Larger workloads are allowed; attention
can grow quadratically.

[Experiment](experiments/final-claim-lifetimes-20261029/README.md) ·
[Handoff](handoffs/20261029-sc-tab-mask-tail-weights.md) ·
[Dated report](progress/20261029T055649Z-74b83633.md).
Checkpoint: 2026-10-29T06:10:38.939293+00:00. Saved reports do not imply message delivery or liveness.
