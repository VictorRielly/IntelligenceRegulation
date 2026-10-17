# ZKP efficiency explorer — durable state

Cycle 0069 COMPLETE: `20261017T222105Z-d6d7aa4d`.
Checkpoint: 2026-10-17 22:34 UTC. Next cycle no earlier than 23:21:05 UTC.
AGENDA/target, durable/project memory, 357 prior sources and latest three results
read. Startup originals/hashes: experiments/ragged-logup-rounds-20261017/startup/.
Eight LIVE primary records appended; 365 total, original prefix preserved.
Report: progress/20261017T222105Z-d6d7aa4d.md. No proving speedup found.

Rust public-support MSB round oracle passes 94 fixtures, 1,424 round values,
282 final factors, 1,600 native CFS mask values and 23 controls. Independent
audit: 5,185 checks. Main 2.038018 s including compilation/oracles, 22,404 KiB;
compiler 134,544 KiB; audit 0.552043 s / 17,724 KiB. One Core Ultra 9 185H CPU0
thread, nice 19, seed 2026101769, each experiment <60 s / 512 MiB address space.
First passing revision retained. No native proof, GPU or real private data.
Public deterministic mask coefficients do not test entropy/privacy. Commands,
logs, source and fixture hashes retained.

NEW: under native MSB folding, column-first mixes dummy columns in round zero
and saves zero pair visits; row-first retains them through row rounds. Both
layouts match their own dense polynomials. Matched values/permuted terminal
coordinates preserve initial sum and all three finals; no native transcript/
PCS equivalence follows. Counted 8B T32 four groups: 17,842,172 -> 11,714,587
base pairs, 34.3433% fewer, ratio 1.523073. No kernel, end-to-end, traffic or
peak saving measured. The cubic is a probe, not a complete/minimal lookup.

Added costs: public equality/support generation, indices/allocations, distinct-
point reduction, original ordered A/wrapping links, GKR, full fresh masks,
extensions/terminal openings/PCS/serialization/transfers and soundness.
Naive indices plus three factors sum to 625.625 MiB across four groups BEFORE
tree scratch; this is not peak, sequential groups differ. Full public E array
alone: 178.75 MiB aggregate. Factorize public data before capacity promotion.
No extra query commitment saved (native looked arrays already uncommitted).
Prior H: U8 1,514 rows / 99,221,504 B; all H 1,758 rows / 115,212,288 B.

New negative: zero Boolean products can be nonzero off-cube, so retain factor-
support union and every terminal factor. S~ is not Boolean at random points.
Whole-cube masks cannot be sparse-summed over base support. Raw virtual values
still leak. Prior rank/repeated-coordinate, D/C, full-i64 wrapping, whole-table
zero refusal, joint-mask and endpoint-history negatives stand. Fixed public
shape padding only; hidden prompt length/selectors and private mask rows must
not become public support. Handoff: handoffs/20261017-ragged-logup-rounds.md.

Carried functional R5 cli3 CPU 8B T32: fresh verification, 11 controls/honest
recheck; one cold pass, 32 linked blocks, 16 CPU threads, GPU off, shared n=1.
App 171.578 s / process 171.641294 s; diagnostic 0.186504 / 0.186435 positions/s.
Witness 21.376 within inclusive prove 156.143; reload 15.993 within it;
remainder 118.774 includes proof/serialization/sink. Partial load+seal startup
15.345 s = 8.943454%. Full startup/prefill, steady slope, isolated serialization,
latency, lag and drain unknown. Fresh check 26.491 + initial load 13.165 s;
check reload 13.071 / crypto remainder 13.420. Verifier process 115.868762 s
includes controls. Receipt 465,815,776 B. Shape privacy acceptance still open.
Free deletion of the 19.5 s H commit/open/U8/exp-act phase set -> 1.128224x,
0.210418 diagnostic positions/s with other work fixed, BEFORE new costs. This
bounds that phase set only, not a whole architecture or GPU.

Current owner R5b moves checked witness/parity/sealing before header, uses a
witness cache, changes statement promotion/export separation and bounded reads.
Targeted tests passed; suite queued at captured checkpoint. R5 review r4 accepts
soundness but identifies further reader fixes delivered in R5b. Old R5 clocks
do not measure R5b; no new privacy acceptance. Owner generic 8B T64 GPU peak
4,417 MiB exceeded its 4 GiB lane cap; queued default T128 GPU prevented. This
is not a complete-stack result. Owner 1.1B T128 s4 slot-18 diagnostics: stack
159 s, slot 8.11 s, device body 6.25 s, fresh check 19 s. Spin probe finds
5–8x idle ramp; isolated also sits in P4, so isolation does not mean boosted
clocks. Charge warm-up costs. No duplicate owner job launched here.

Ranked hypotheses:
1. OWNER whole-prover GPU/residency and contiguous useful device work: remove
   CPU arithmetic/idle gaps, charge memory/launches/spills/transfers/drain.
   Exact transcript/privacy required; reject no enclosing gain or gate failure.
2. OWNER public-model residency after R5b sealing: remeasure full startup and
   complete-pass slopes, charging identity/invalidation and RAM. Reject stale
   identity, hidden work/backlog or >20 ms recurring/new position for a 50/s
   claim. No reuse of private masks/openings.
3. TESTED row-first private lookup batching: 34.3% fewer proxy pairs only.
   Add all 83 ordered links, GKR/masks/PCS and refusal/soundness work. Direct
   old-H deletion ceiling above; total architecture ceiling unknown.
4. NEW next local implicit per-column equality/support: remove expanded public
   E/index arrays, add per-column factors and terminal computation. Compare to
   saved oracle at independent points; reject mismatch, private disclosure,
   excessive representation or no eventual enclosing gain.
5. NEW older FLI/Deep Thought accumulation and power-circuit wiring leads:
   final proving/state binding/backend/privacy costs put them below bottlenecks.

Next local: factorized independent per-column equality rounds and public
selector terminals against saved dense/compact oracle, odd columns and all
final factors. Next owner: device diagnosis and R5b complete resident-workload
slopes with serialization/startup/drain clocks and independent verification.
Rotation: sumcheck/GKR + memory/batching tested; October 10 SP1 NTT/order and
zerocheck source follow-up retained; lookup/softmax, quantization/composition
queues preserve earlier negatives. Source dates/licenses/failed access explicit.

New target-compliant proofs/passes/positions: 0/0/0. Target steady/total rates
and clocks unmeasured. No resident repeats, long prefill or decode here. Larger
workloads allowed with fresh masks; attention can grow quadratically; decode
needs proved state. >=50/s private 8B on a named high-end GPU stands, unachieved.
D27 tiers authorize no mask/privacy weakening. Production, runtime, Git,
receipts, calibration, instructions and reviewer files untouched. No installs,
external messages or escalation. All local work complete; no heavy job queued.
Saved reports do not establish delivery.
