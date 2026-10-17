# ZKP efficiency explorer — durable state

Cycle 0062 COMPLETE: `20261017T122624Z-c30acfa0`; checkpoint 2026-10-17T12:39:34.547783+00:00.
AGENDA, current target and durable/project memory read. Startup snapshot:
experiments/lookup-borrow-catalog-20261017/startup/. Latest three research
results read/pinned. Read 315 sources; appended five LIVE records, 320 total.

Local result: 48 fixtures / 288 domains / 4,176 columns / 23,834 i64 words /
12,328 Fp2 checks, 11 controls and five generic fallbacks pass. 1.050006 s,
17,464 KiB; independent 235-check audit 0.011948 s / 14,904 KiB. Seed
2026101762, CPU0, one thread, nice19, 59-second/512-MiB caps.
Per-proof Cow borrows identity lookup slices, including public scaled-1 cases.
TinyLlama T128 source count: avoid 167.5 of 221.25 MiB lookup payload;
53.75 MiB remains owned. Final witness unchanged. All 22 public manifest
shift pins agree. Actual peak/traffic/native time unknown. Patch uncompiled,
unapplied: handoffs/20261017-borrowed-lookup-columns.md. Audit failure retained.

NEW owner R4 CPU/GPU-assisted phase diagnostics completed during this cycle:
trained 1.1B, 22 blocks, T128, one cold pass, 16 threads, n=1. Process
175.258632/161.857226 s; load 10.862/10.038; witness 13.236/15.899;
prove_run 153.072/135.809; prove-minus-witness 139.836/119.910 includes
boundary/serialization/sink. In-process verify 10.514/10.148; fresh verifier
not inspected, zero newly credited positions. Receipt 497665904 B. GPU:
RTX 4070 Laptop; guard VRAM peak 3105 MiB, RSS 3.07 GiB (CPU 4.81 GiB).
Startup/serialization/steady slope/lag/drain unisolated. Filtered public
phase lines and metadata hashes saved; no private payload retained.

GPU D/F zero-checks 25.353/19.484 s, softmax 11.834; D/F shared masked
sumchecks 19.860/16.457 s, extension rounds 4.871/1.583. Commit A/H
3.995/3.625. Lookup+histogram 0.748 s (CPU 0.517); conditional full-mark
deletion ceiling only 1.004643x GPU / 1.002959x CPU. Borrowing demoted for
speed, retained for capacity. Historical synthetic softmax share superseded
as a trained bottleneck assumption; this is no controlled speedup A/B.

Prior R3 T128 GPU fresh-verified diagnostic: 142.783399 s process,
12.872 witness, 107.079 prove-minus-witness including sink, 8.451 fresh
verify plus 11.307 verifier load, 0.896463 diagnostic positions/s. No 8B
credit. D24 conditions are not trained privacy acceptance; R2/R3 exports
differ, so the 529-to-56-second headline is not a controlled A/B.

Ranked hypotheses:
1 OWNER: D/F recurring GPU zero-checks; exact polynomial/final/RNG/PCS/
  transcript/byte/privacy/fresh-verifier gates; charge transfer and scratch.
2 OWNER: complete resident fixed-context fresh-proof slopes, public setup
  reuse only, count verification/lag/drain and fresh masks every pass.
3 TESTED: borrowed lookup capacity; native compiler/Rayon/peak/time gates
  owed, tiny direct time ceiling, final witness unchanged.
4 NEW NEXT LOCAL: capture exact current SC_FZC closure (argument.rs:1602)
  and census/differential public-base-constant mul_base specialization.
  It still uses extension p1/k_h/k_g multiplies; D/softmax Stage35 work is
  already present. Include pad/helper/host/full-extension controls; compiler
  may simplify already. Full F-slot deletion ceiling 1.136852x on this
  one GPU diagnostic; candidate can remove only a subset. No 8B estimate.
5 DEMOTED: duplicate Lk histogram scans, 8.36% of a tiny parent phase;
  retain previous witness/int8 candidates and all negative findings.
  HOBBIT/other architecture leads need PCS/streaming/privacy review.

Next owner: select D/F native opportunity from these clocks, then shared
guard builds/oracles/frozen bytes/fresh verification and enclosing workload.
Borrow patch only if measured capacity warrants it. Recompare pins first.
Next local: source-captured full F-polynomial reference and operation census;
never copy private witnesses/RNG. Search memory traffic then NTT/commitments.

Accepted independently verified complete private **8B** proofs / passes / positions: **0 / 0 / 0**. Context, steady-state and total-workload rates, startup seconds/fraction, witness/proof/serialization/independent-verification clocks, latency, lag and drain remain **unmeasured** for that target. Local experiment: one Intel Core Ultra 9 185H CPU thread, CPU0, nice 19; no GPU. No prefill proof, resident-pass sweep or decode ran here. Larger workloads remain allowed with fresh masks; dense attention grows approximately quadratically with context. The >=50 proved-token/s target is unchanged and unachieved.

Research only; no production/runtime/Git/calibration/receipts/gates/
instructions/reviewer-file changes, native build/proof/GPU/install/foreign
execution/external write/message/merge. No heavy job queued. Reports do not
establish delivery or supervisor liveness. Next cycle >=2026-10-17T13:26:24Z.

Final checkpoint 2026-10-17T12:41:41.342868+00:00: artifact/source audit passed 45 checks; 49 experiment artifacts pinned; historical findings/sources prefixes preserved; native pins stable. No native gates or independent verification of the new phase receipts ran here.
