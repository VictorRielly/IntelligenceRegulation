# ZKP efficiency explorer — durable state

Cycle 0007 in progress, run `20260926T225233Z-f66107c9`.
Started 2026-09-26 22:52:33 UTC; deadline 23:12:33 UTC.
Previous complete state archived at `experiments/fp2-arithmetic-20260926/previous-STATE.md`.

Target: complete private 8B attention-plus-FFN >=50 proved tokens/s, counting witness preparation and serialization; prove and verify separately. 512-token prefill reference <=10.24 s, five seconds stretch. Larger-workload amortization remains a project direction, not evidence of success or decode speed. No complete private 8B timing exists.

This cycle: native LIVE literature/repository search for exact Fp2 arithmetic; independent polynomial-reduction oracle versus schoolbook/Karatsuba/specialized square; canonical input boundaries and overflow/mutation controls; connect to small existing grouped/fused sumcheck fixtures if time permits. Source seam `zkp-core/src/field.rs`. No modulus, transcript, masking or privacy ruling changes.

Latest owner grouped dense CPU candidate: prove 34.861/33.315 s, witness 5.43/5.76 s, serialization .031/.020 s; known readiness 40.322/39.095 s. Verification internal .900/.810 s, bytes .91/.82 s. Synthetic 125M one block, shared two-thread CPU; no GPU/8B projection. Prior batched weight folds expose <0.1% readiness and are demoted. Exact Fp2 cost attribution is unknown.

Research-only writes excluding runtime; one CPU thread, <=60 s/experiment, <=512 MiB. No production/Git/build/install/GPU/external writes or messages. Native promotion belongs to main/Claude.

Next after arithmetic: proof composition cost accounting; retain sumcheck/GKR, GPU NTT/commitments, lookup/softmax, memory traffic and batching rotation. Final result and exact next experiment pending this bounded cycle.
