# ZKP efficiency explorer — durable state

Cycle 0126 COMPLETE: `20261026T182925Z-b116a67c`.
Final checkpoint UTC: 2026-10-26T18:46:18.351388+00:00. Started 18:29:25 UTC; deadline 18:49:25 UTC.
Next cycle no earlier than 19:29:25 UTC. Required memory, all prior findings
and 807 prior sources are snapshotted in
`experiments/sumcheck-public-shape-20261026/startup/`.
Seven source records appended (814 total). All 38 hypotheses retained;
1 and 14 refined, 39 added. Thirteen native LIVE result batches saved.

No proving gain measured. Exact finite-difference interpolation passes
6,244 checks: 108 fixtures / 1,836 points, 40 synthetic CFS-algebra chains /
120 rounds and ten control types. A separately authored Vandermonde/direct
cube oracle checks the results. SHA256 transcript mock only; no native
proof, CFS/PCS, receipt or privacy test. Model: 1.096540 s / 15,268 KiB RSS.
Source/count audit: 66 checks, 0.004663 s / 17,332 KiB RSS. One Core Ultra 9
185H core, nice 19, 30 s CPU/alarm, 35 s parent timeout, 256 MiB AS cap,
64 MiB estimated memory. These are diagnostic clocks.

At degree 5: source Fp2 products 36 -> 5 and base inversions 6 -> 0, adding
15 Fp2 subtractions, a 96 B scratch clear/copy, 48 B constants and dispatch.
No dense cube work disappears. Base R12 8B T128 honest block verifier:
370 interpolation calls nonDD, 388 DD32; selected R13 LOW+h24 excluded.
Uncompiled, unapplied `finite-difference.patch` is parked for native clocks.
Native R12 and the earlier GPU tree share the core function, but their GPU
paths differ: never transfer DevFzcRounds incidence. Two initial audit
failures are preserved: concurrent coordination-document update and an
incorrect cross-branch device assumption. Corrected audit passes; tested
code pins are stable. Five public constructors were inspected: finished
U8/exp/act encodings depend on fresh challenges; shape-only caching is stale.

New independently verified full-stack proofs / passes / positions: 0 / 0 / 0.
Actual model context / accelerator: none. Witness, proof, serialization,
verification, startup and prefill clocks; startup fraction; proof latency /
bytes; steady-state and total-workload rates: unmeasured. No long prefill,
resident-model proof series or decode ran. Larger workloads remain allowed;
attention can grow quadratically. Private 8B >=50 proved tokens/s on RTX5090
or a named high-end GPU remains unachieved. Owner R12 diagnostics, LOW+h24
fidelity choice and D37-D41 application direction do not change this target.

Next local: rotate to lookup/softmax. Read prior public-table/cache findings;
test `table_values_exp_at` / `table_values_act_at` building 256 fresh encoded
rows once within each proof and then tiling the lifted cube. Differentially
check every index/mod256, fresh beta/gamma, lengths and refusals; charge
scratch, copies and initialization. No cross-proof challenge or mask reuse.
Next owner: exclusive interpolation/constructor and enclosing proof clocks;
native gates if material, then independently verified fixed-context resident
1/2/4/8 workloads under shared build/heavy locks.
Handoff: `handoffs/20261026-finite-difference-interpolation.md`.

Historical baseline, not rerun/reverified: nonDD 8B T128/L32, one 16-thread
CPU pass, GPU off, total 478.737 s = 0.267370 positions/s. prove_run 393.785 s
includes witness 98.348 s / load 17.595 s; seal 84.824 s overlaps, not additive.
Receipt 922711264 B; fresh verify 42.709 s + load 13.681 s; recheck 34.395 s +
load 10.739 s. Startup fraction, isolated serialization and steady slope
unknown. No GPU or 8B privacy acceptance follows.

Final integrity audit: 721 checks PASS, 78 immutable artifacts and
15 tested code pins match; patch applies in memory only. Prior findings,
sources and hypotheses preserved. Only research outside runtime written.
No native build, GPU, install, Git, external message or production mutation.
Saved reports do not establish delivery or supervisor liveness.
