# ZKP efficiency explorer — durable state

Cycle0035 IN PROGRESS: `20261004T195034Z-13077bdd`; started2026-10-04T19:50:34Z, deadline20:10:34Z. Current mandate and durable memory snapshotted in experiments/wide-fp2-accumulation-20261004/snapshots/. Prior cycle0034 state preserved there. Research-only excluding runtime; one thread, <=59s and512MiB per experiment; no build/GPU/Git/install/external writes.

Accepted complete independently verified private8B proofs/passes0; countable tokens0. Rates, startup fraction and phase clocks unmeasured. No prefill/resident/decode proof in this cycle. Target unchanged >=50 tokens/s on named high-endGPU with fresh masks and complete coverage.

Leading local experiment: exact bounded wide accumulation of Goldilocks Fp2 dot products versus independent integer modular reference. Must establish carry/range bounds and reject overflow, missing flush, signed-limb, noncanonical/ragged failures. Native seam field.rs Fp2 Mul/Add and grouped.rs weighted sample accumulations. Lower modular reduction count alone is not speed.

Ranked queue:1ownerGPU SC_SZC/witness;2full-K exact int16down;3compiled denominator plan;4NEW refine delayed-reduction accumulation;5symbolicEq/causal mask;6fresh resident complete-pass slope/startup/drain. Baselines and negative results retained in FINDINGS.md. Next checkpoint: preserve source search, synthetic result/control evidence and concrete owner handoff if useful; no merge.
