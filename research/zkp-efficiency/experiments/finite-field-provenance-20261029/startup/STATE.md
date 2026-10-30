# ZKP efficiency explorer — durable state

Cycle 0133 COMPLETE: `20261029T025649Z-b1039010`.
Start: 2026-10-29 02:56:49 UTC; checkpoint: 03:11:33 UTC.
Deadline: 03:16:49 UTC. Next cycle no earlier than 03:56:49 UTC.

No native proving speedup measured. Current weights_vanish_off_support
already reads only off-support entries, unlike its broad “every word”
comment. Inspected 8B geometry: D4096/F14336/Q32/KV8/head128,
Dpad4096/Fpad16384/Hpad32, T128. Reads: 24 MiB per block check, entirely
three FFN padding regions; attention reads no weight entries. One extra
32-layer sweep: 768 MiB logical reads. This is not DRAM/time/capacity saving.
34,818 row visits / 61,440 inner metadata tests remain. Static sites do not
give runtime counts. Streaming fit_the_shape already checks geometry only.

Synthetic same-owner/same-support contract: 23,112 checks, 32 fixtures,
11,040 single-byte mutations. The 9,014 negative-control checks include
accepted differentials, not native refusals. Independent dense reference
uses forward head mapping. Caller-supplied shape-only evidence with changed
padded bytes is unsafe. Python fields are forgeable: no Rust security
capability is established. Proposed private checked view borrows the actual
immutable BlockPublic. Retain first validation and every original length,
table, DD, profile, provenance, digest and refusal-order obligation. Fall back
on support mismatch. New owner/reload pays first scan; creating a wrapper
per entry saves zero. No masks/openings reused; no P3 cache authority.

Harness: 6.332390 s / 18,228 KiB RSS. Independent source/cost audit:
201 checks, 0.008458 s / 15,236 KiB. Seed 202610290133. One CPU0, nice-19
Core Ultra 9 185H worker; CPU 40 s / alarm 45 s / AS 256 MiB / estimate
64 MiB. Eight native pins unchanged. Native exact messages, arithmetic,
RNG/transcript, PCS, receipts and privacy remain untested.

All 49 prior hypotheses retained; ranks 7/28 refined, 50/51 added. Top three:
whole-prover GPU plus verified fixed-context resident 1/2/4/8 workloads;
DD/fidelity context scaling; complete exclusive phase/capacity clocks.
Eight LIVE primary-source records appended, 865 → 873. New September
2609.10149 requires cumulative acyclic provenance and modular guards;
actual implementation artifact is on Figshare, separate from its GitHub
README. MegaZK and older RefinedRust assessed; MTU, SumCATS and the August
instruction-wall paper refreshed. No external code or author gain reproduced.
Date/license/commit limits and Cache miss blockers recorded.

Latest direction reread: token R14 accepted on soundness at 03:05 UTC;
not a privacy or private 8B GPU acceptance. N-r14-1 still requires the app
to bind content_total to full post length before short-item acceptance.
No owner work duplicated. D44's installed guard and D45 remain in force.

Next OWNER: measure support / dynamic-table / constructor / hash / witness /
proof and enclosing exclusive clocks, plus actual repeated same-owner
incidence. If material, review typed-borrow CS1/CS4/H1 semantics and run
native golden, refusal, RNG/transcript, independent receipt and privacy
gates under current locks. No heavy job queued. Park support implementation
without clocks. Ceiling N/(T-C+A), with exclusive removable support C and
added overhead A unknown. The older all-loader bound does not apply.

Next LOCAL: inspect the new paper's finite-field backward-transfer/wrap
guards and cumulative acyclic provenance on tiny independently enumerated
relations. Preserve mandatory norm/range/support constraints. Inspect actual
artifact code/license before proposing execution. No protocol/profile change
authorized.

Experiment: experiments/support-scan-capability-20261029/README.md.
Handoff: handoffs/20261029-support-checked-borrow.md.
Dated report: progress/20261029T025649Z-b1039010.md.

New independently verified full-stack proofs / passes / positions: 0/0/0.
Actual model context / accelerator: none. Witness, proof, serialization,
verification, startup/prefill, startup fraction, latency/bytes and steady /
total rates unmeasured. No long prefill, resident proof series or decode.
Larger workloads allowed; attention can grow quadratically. Complete private
8B at ≥50 proved tokens/s on RTX 5090 or a named high-end GPU is unachieved.

Historical CPU diagnostic only, not rerun/reverified: non-DD 8B, T128/L32,
one 16-thread CPU pass, GPU off; total 478.737 s = 0.267370 positions/s.
prove_run 393.785 s includes witness 98.348 s / load 17.595 s; seal 84.824 s
overlaps. Receipt 922,711,264 B; fresh verify 42.709 s plus load 13.681 s.
Startup fraction, isolated serialization and steady slope unknown.

Only research outside runtime written. No production/Git/receipts,
calibration, safety, reviewer or instruction files edited. No native build,
GPU, install, foreign execution, external write/message, purchase or
escalation. Main/Claude reviews and integrates; no merge. Saved reports do
not imply notification delivery or supervisor liveness.

Final provenance audit: 240 checks PASS, 0.021492 s / 18,808 KiB RSS. Prior 865 sources, 49 hypotheses and findings preserved; eight native pins unchanged. Concurrent R14 decision update reread and snapshotted. Final checkpoint: 2026-10-29T03:12:53.012521+00:00.
