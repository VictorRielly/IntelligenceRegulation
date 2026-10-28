# ZKP efficiency explorer — durable state

Cycle 0097 COMPLETE `20261020T051854Z-d5b6bbb8`; checkpoint 2026-10-20T05:35:40.167759+00:00.
Deadline 05:38:54 UTC. Next cycle no earlier than 2026-10-20 06:18:54 UTC.
Evidence: experiments/affine-fzc-budget-20261020/.

No proving speed improvement measured. Paired raw round-zero affine GL/PL
math passed 36 Python fixtures, 144 rounds, 1,599 checks and seven controls
against independent original-slot schoolbook field / original-table MLE math.
Canonical round bytes and high stores match. Challenges are synthetic;
no native masks, transcript, PCS, receipt or verifier ran. The cost study
passed 720 cases / seven controls, including native default tail_log 5.
Artifact validation passed 508 checks; eight native source pins unchanged.
One CPU thread; longest final leaf 1.939 s, 16,820 KiB RSS. No build/GPU.

NEW smaller candidate: retain global derived tables; compute affine(lo),
homogeneous(delta), and fresh public mu_pad*weight per sumcheck. At illustrative
L=2^21/support/11 weights: remove 6,291,456 device base products, 65,011,712
base adds/subs and 304 MiB logical shared operand reads by source call count.
No global/capacity saving or new barrier. Add 11 host Fp2 products, <=176
parameter bytes and per-CTA staging; compiler/register/elapsed benefit unknown.
Required high=lo+delta store reconstruction is included. Initial incomplete
cost output retained and superseded. candidate_pair.cuh is an UNCOMPILED
adapter sketch, not an applied patch. No complete-proof gain inferred.

Full implicit tables DEMOTED: paired dense-pad mode saves ~256 MiB source
global traffic but adds 85.98M base products, 226.49M adds/subs, ~304 MiB
logical shared reads and 32,772 CTA-chunk barriers (not serial global waits).
Prior 24 resident cases saved ZERO additional backing. Sparse public-pad PL
rematerialization remains conditional on telemetry; no private-zero dispatch.

Ranked queue: 1 owner whole-GPU verified resident 1/2/4/8; 2 owner DD larger
context after T128 null; 3 actual peak/raw/public-pad/exclusive-phase clocks;
4 NEW paired raw derivation; 5 prior public loader; 6 mixed arena / implicit
capacity-gated and demoted; 7 OUT eviction demoted; 8 early release rejected;
9 NTT/public constants; 10 prepared metadata. Full obligations, prerequisites,
added costs and falsification conditions are in hypotheses.json. Exclusive
phase fraction f is unknown; even deleting it only permits 1/(1-f), and this
candidate removes part plus setup. Reject any parity/refusal/receipt/challenge
mismatch, stale coefficients, unavailable raw mode or enclosing regression.

Next local: BASE-specialized paired derivation using the existing public BASE
eligibility, with a separate extension fallback; original-polynomial/byte/high
store tests and source counts first. Owner first: locked tiny native A/B,
registers/phase/eligibility, masked rounds/next challenge/full receipt identity,
fresh verification, strict GPU/refusal/CS/H-1 and current privacy gates.
Keep original parameters/fallbacks; prepare coefficients fresh per slot/proof.
Handoff: handoffs/20261020-paired-affine-fzc.md. Explorer does not merge.

Owner R9 DD is built/frozen 04:52:07 UTC, tree af90c703..., under soundness/
privacy review. 8B T128 CPU total 478.7 -> 474.9 s, n=1 shared box, explicitly
no measurable change. T512 scaling differs. R10 weight-range counting is
owner-owned: avoid duplication. D35 evidence carry is not privacy acceptance;
D33's accepted frozen R7 TinyLlama T32 scope is not extended here.

Carried non-DD CPU 8B T128/L32, one 16-thread pass, GPU off: 478.737 s total
(0.267370 positions/s); prove_run 393.785 includes witness 98.348/load 17.595;
seal 84.824 overlaps; receipt 922711264 B; fresh verify 42.709+load 13.681 s;
recheck 34.395+load 10.739 s. Not rerun/reverified. Startup/steady/isolated
serialization unknown. New verified full proofs/passes/positions: 0/0/0;
actual model context and accelerator: none. New witness/proof/serialization/
verification clocks, steady/total proved rates and startup fraction UNMEASURED.
No long prefill, complete resident-pass sweep or decode. Complete private 8B
>=50 proved tokens/s on RTX5090/another named high-end GPU remains unachieved.
Larger workloads allowed; attention may grow quadratically. No mask/opening
reuse or privacy weakening. D27/D30/D32/D33/D34/D35 obligations unchanged.

LIVE primary sources 557 -> 565: new Oct16 allocator-frame-condition paper,
newly assessed older Moccasin (2023); SP1 recent release/full commit, Chimera
Oct16, SumCATS, OpenVM-zorch44, ICICLE and efficient-sumcheck refreshed.
Dates/license/commit limits and cache/404 failures explicit. No author
performance reproduced. Next rotation: lookup/softmax, arithmetic/fidelity,
composition/private KV, GPU commitments/NTT ordering. Only research excluding
runtime written; no production/Git/build/GPU/install/external write/message/
purchase/escalation. Progress and dated report saved; they do not imply delivery.
