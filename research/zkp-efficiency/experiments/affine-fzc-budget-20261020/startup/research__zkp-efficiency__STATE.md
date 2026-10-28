# ZKP efficiency explorer — durable state

Cycle 0096 COMPLETE `20261020T041854Z-f70297a5`; checkpoint 2026-10-20 04:33 UTC.
Deadline 04:38:54 UTC. Next cycle no earlier than 2026-10-20 05:18:54 UTC.
Evidence: experiments/native-fzc-arena-20261020/.

No measured proving improvement. An authored Python model using the native
Goldilocks Fp2 definition and actual FZC polynomial passed 108 fixtures,
468 modeled rounds and 11 negative controls against separate original-MLE
and original-slot polynomial algorithms. This executes no Rust/CUDA, native
masking/transcript/PCS, receipt or independent verifier. Challenge recurrence
is synthetic; cube logs 3/4/6 are table dimensions, not token contexts.

NEW implicit GL/PL: reconstruct affine endpoints from staged A each round
instead of globally storing/folding derived tables. Constants belong in values,
not differences. At illustrative T128/F2^21/support, requests are 736 -> 464
-> 400 MiB (dense -> mixed -> implicit). The 72 partial allocation schedules
and separate interval oracle reject 72 capacity corruptions. Additional
backing saving is at most 64 MiB in selected chunked cases, ZERO in all 24
resident cases. Noncompact support/T128 slice: 1890.932186 -> 1618.932186
-> 1554.932186 MiB; resident stays 9097.779842 MiB. These are hypothetical
R8-geometry / different-GPU-allocator projections, excluding other slots,
openings, history, caches, driver and granularity. Actual peak/fit/time unknown.
Allocation repetitions 1/2/4/8 are not complete model passes.

Census: 107 selected lexical sites, 21 functions, 43 address/stride/allocation
sites. Constructor anchor corrected from another class's line 3225 to 4332;
earlier command hashes/logs retained. Complete compiled coverage is unproven.
Seam: DevFzcRounds new/try_round/try_fold; fzs_ld/fzs_impl/fzs_derived_at;
k_sc_fold, k_fzc_pack, k_fzc_finals. Every offset consumer and dense fallback
matters. Shared derivation adds operations, shared work and later barriers.

Ranked queue (full obligations in experiment's hypotheses.json):
1. Owner whole-GPU clocks and independently verified resident 1/2/4/8.
2. Exact DD owner prototype; no reproduced complete-stack timing.
3. Actual raw eligibility / whole-workload peak capacity telemetry.
4. REFINED mixed storage plus implicit GL/PL, conditional on real benefit.
5. Prior public-loader work; 6. OUT eviction demoted; 7. early release rejected;
8. NTT / public-constant simplification filter; 9. prepared public metadata.

Next local: coefficient-aware affine operation/shared/barrier budget versus
stored derived folds, including host-tail break-even. Owner first measures
actual raw eligibility and fresh backing at the full workload peak. A useful
native candidate must preserve shadow masked rounds and next challenge,
finals/tail/dense fallback, strict GPU/refusal/CS/H-1, exact full receipt bytes,
fresh independent verification and current privacy gates under shared locks.
Handoff: handoffs/20261020-implicit-affine-fzc.md. Explorer does not merge.

Carried owner CPU 8B T128/L32, one 16-thread pass, GPU off: total 478.737 s
(0.267370 positions/s); prove_run 393.785 s includes witness 98.348 and load
17.595 s. Sealing 84.824 s overlaps those phases. Receipt 922711264 bytes;
fresh verify 42.709 + 13.681 load s; recheck 34.395 + 10.739 load s.
Not rerun/reverified. Startup, steady slope and isolated serialization unknown.
Owner next-token 501.6/529.2 s totals are distinct workloads.

New full-stack proofs/passes/positions: 0/0/0. No actual model context or GPU.
New witness/proof/serialization/verification clocks, steady/total proved rates
and startup fraction: UNMEASURED. No long-context prefill, complete resident
passes or decode. Target remains complete private 8B >=50 proved tokens/s on
RTX 5090 or another named high-end GPU; larger workloads allowed; attention
may grow quadratically; no mask/opening reuse or privacy weakening.

LIVE sources 548 -> 557: new NTT-TensorCore field/FP64 incompatibility and
consumer large-N negative; SP1 October release and PR2993 public-constant
simplification / scratch fallback; ICICLE full release commit and scoped MIT
license; zkLLMPoT v2 operator/composition scope; zkIE public witness / forward
verifier limitations; older profiling work plus newly assessed NTTSuite (2024) and Theodosian (2025). Unverified dates/commits/licenses
and failed fetches are explicit. Linked October 17 RTX 5090 PR7 was a cache
miss. No author performance reproduced. Next rotation: memory/commitments,
batching/amortization, arithmetic, composition. D27/D30/D32 obligations,
D33 frozen R7 TinyLlama T32 scope and D34 accounting remain unchanged.
Only research excluding runtime was written; no production/Git/build/GPU/
install/external message or write/purchase/escalation. Saved reports do not
imply delivery.
