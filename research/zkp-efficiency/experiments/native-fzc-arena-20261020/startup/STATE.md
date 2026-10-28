# ZKP efficiency explorer — durable state

Cycle 0095 COMPLETE `20261020T031854Z-e03e28dc`; checkpoint 2026-10-20T03:33:04.456870+00:00.
Deadline 03:38:54 UTC. Next cycle no earlier than 2026-10-20 04:18:54 UTC.
Evidence: experiments/private-transient-capacity-20261020/.

No measured proving improvement. New mixed FZC arena: reserve half-length
storage for 17 raw tables (3..19); retain full Eq/public/derived tables.
Raw round 0 writes derived tables at full length; first fused fold writes
half length. Naive global half/quarter layouts fail. Thirty two-lane mod101 /
base-challenge fixtures pass 535848 checks and 121 controls. This does not
validate native Goldilocks Fp2, actual FZC polynomial, masks or proofs.

Illustrative T128, F=2^21, support, kd=23: request 736 -> 464 MiB (-272).
Partial chunked backing projection: 1890.932186 -> 1618.932186 MiB.
Resident backing: 9097.779842 MiB unchanged; suitable pool slabs already exist.
No observed VRAM, device fit or elapsed benefit. No native patch/build/GPU job.

72 partial private-owner + A/H commit + slot18 schedules, 23094 events.
Separate interval oracle: 646591 checks, 441 corruptions, 80 random traces,
oversize reuse and 64-idle limit. R8 T32/64/128 geometry and the active GPU
allocator are distinct revisions: this combination is hypothetical. Repetitions
1/2/4/8 are allocation slices, not complete passes. Other phases, opening and
H-helper scratch, seed history, retries, caches, driver/granularity and delayed
physical frees are omitted. Actual complete-GPU peak remains unknown. Active
private DZC has no device FZC descriptor; legacy CUDA zerocheck scratch must
not be counted as an observed private DZC device allocation.

Ranked hypotheses (full obligations in hypotheses.json):
1. Owner complete-GPU clocks and independently verified resident 1/2/4/8.
2. Exact owner DD prototype; counted benefit is not complete-proof timing.
3. NEW mixed raw arena, conditional on actual capacity value.
4. Actual phase/capacity telemetry; 5. prior public-loader work.
6. OUT eviction demoted; 7. early release rejected; 8. NTT/composition;
9. prepared public metadata from the new literature leads.

Next local: native Goldilocks Fp2 / actual-FZC toy plus an address census of
constructor, raw round0, first fused fold, later folds, finals, host tail and
dense fallback. Owner telemetry must establish raw eligibility and lower fresh
backing at the real peak before implementing. Require native shadow rounds,
next challenge, full receipt bytes, independent verification and current
privacy/refusal gates under owner/shared-lock control.
Handoff: handoffs/20261020-mixed-fzc-arena.md.

Carried owner CPU 8B T128, L32, one 16-thread pass, GPU off: total 478.737 s
(0.267370 positions/s); prove_run 393.785 s includes witness 98.348 / load
17.595 s. Sealing 84.824 s overlaps witness/load. Receipt 922711264 B;
fresh verify 42.709 + 13.681 load s; recheck 34.395 + 10.739 load s.
Not reverified. Startup, steady slope and isolated serialization unknown.
Owner next-token 501.6/529.2 s totals are distinct workloads.
New verified proofs/passes/positions 0/0/0; actual context/device none. New
witness/proof/serialization/verification clocks, steady/total rates and startup
fraction unmeasured. No long-context prefill, complete resident passes or
decode. Target remains complete private 8B >=50/s on RTX5090/high-end GPU;
larger workloads allowed, attention may grow T^2, no mask/opening reuse.

LIVE sources 538 -> 548: StateSync October papers/release, SP1 GKR PR/release,
older zorch55 and INT4 FFN, Sumcheck201 (2024-02-02), Bits Under ZK-LLM,
efficient-sumcheck. Dates, URLs, license scope and unresolved commits/failures
saved. No author performance reproduced. Next rotation: GPU NTT/commitments,
lookup/softmax, composition/amortization; retain memory and arithmetic leads.
D33 remains R7 TinyLlama T32 only; D34 is accounting, not acceptance.
D27/D30/D32 obligations persist. Only research excluding runtime was written;
no production, Git, build, GPU, install, external message/write or escalation.
Saved reports do not imply delivery.
