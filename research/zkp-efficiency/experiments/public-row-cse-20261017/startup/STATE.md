# ZKP efficiency explorer — durable state

Cycle 0051 COMPLETE: `20261017T012624Z-ea61e714`; checkpoint 2026-10-17 01:33 UTC.
AGENDA/current target, durable/project memory and latest three results were
inspected and snapshotted. All ten native/measurement pins match cycle 50.
Sources grew from 257 to 261 records. Checkpoint audit: 44 checks passed.

Tested public multiplication plans and blocked 3×2 multiplication against
cycle 50's fixed 2×2 Karatsuba factory. 100 fixtures / 600 schedules pass
5,832 round samples, 16,272 final values, 400 convolution and 40 full-clause
extension values, 600 executed counter checks and eight value-independent
schemas. Five mutation detections plus the schedule assertion pass. Final
run: 12.121455 seconds, 23,164 KiB RSS, one nice-19 Core Ultra 9 CPU thread.
Synthetic only; Rust sketch uncompiled. No native/GPU proof or native gain.

Illustrative T=512 / three limbs: base products −3.1541%, field API +1.9542%
versus cycle 50. 226,492,362 width tests become equal cursor reads plus
4,194,303 pattern lookups and 1,042,546,425 interpreter operations. Charge
three public traces, 1,296 pointer + 512 IR logical bytes and unknown native
scratch/code/spills. Break even needs saved multiplication time to exceed
one add, two subs and net plan/dispatch/scratch cost per blocked product.
Historical entire-SC_SZC removal caps one 4070 block's wall saving at 28.317%;
this is not an 8B rate estimate. Preserve the slower native fusion negative.

Ranked hypotheses:
1. Owner: dominant SC_SZC on GPU plus both recurring witness paths.
2. Conditional fixed-array factory, weighting and 2×2/3×2 helper chain.
3. NEW local: whole-row reuse by public expression identity and structural squares.
4. Owner: exact full-K split-int16 down projection.
5. Fresh complete resident-pass startup and recurring slope.
6. GKR/lookup/PCS composition with separate hiding and state-binding obligations.
Costs, prerequisites and falsifiers are in FINDINGS.md.

Next LOCAL: share affine sums / specialize structural squares using public
expression identity, never private-value equality. Check tuple/cube/final
oracles and value-independent schedules; charge graph setup and liveness.
Next OWNER: native fixed arrays; masking/frozen/refusal/final/RNG/PCS/fresh
verification gates; then guarded subphase, both-witness, peak and enclosing
A/B. Handoff: handoffs/20261017-static-polynomial-plan.md. No heavy job queued.

LIVE primary sources: new older Roche July 24, 2009 static code/scratch;
Plonky3 October 16 rc.2 and September 22 immutable-plan PR; new StateSync-GKR
October 10 paper/repository; Expander's January 21, 2026 test-data date filter.
License scope, unknown commits and exact fetch failures retained. Author
performance/formal/security claims unreproduced. Rotation: lookup/softmax,
memory reuse, quantization, GPU commitments, proof composition.

Accepted complete private 8B proofs / passes / tokens: 0 / 0 / 0. Proof context
null; CPU only this cycle. Steady/total rates, startup duration/fraction,
witness/proof/serialization/independent-verification clocks, latency, lag and
drain unmeasured. No long-prefill, resident-pass or decode proof. ≥50/s remains
unchanged; larger workloads allowed with quadratic attention, fresh masks,
complete coverage and privacy. No production/runtime/Git writes or build/GPU/
installation/external action. Do not start another cycle before
2026-10-17T02:26:24Z. Reports do not establish delivery or supervisor/job liveness.
