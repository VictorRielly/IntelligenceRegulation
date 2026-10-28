# ZKP efficiency explorer — durable state

Cycle 0125 COMPLETE: `20261026T172925Z-dd337876`. Final checkpoint UTC: 2026-10-26T17:43:15.990147+00:00.
Started 17:29:26 UTC; hard deadline 17:49:26 UTC. Next cycle no earlier than
18:29:26 UTC. AGENDA and required durable memory are snapshotted in
`experiments/commitment-salted-merkle-20261026/startup/`. All 799 prior source
records, prior findings and 37 hypotheses are preserved. Eight source records
and hypothesis 38 were added; hypotheses 36/37 refined. Ten LIVE queries.

No proving gain measured. Salted-leaf/first-parent fusion matches installed
independent blake3 1.0.9: 19,952 checks, 120 cases, all 3,825 paths, 17 controls.
Separate interval/cost/source audit: 16,733 checks, 12 pins, five controls.
Model 1.197346 s / 16,240 KiB RSS; audit 0.025621 s / 16,164 KiB RSS. One core,
nice 19, 30 s CPU/alarm, 35 s parent timeout, 256 MiB AS, 64 MiB estimate.

The candidate removes one 32N-byte logical read per N encoded columns: 2/4 MiB
per frozen R9 T128/T512 A/H commitment. All N salted-leaf and N-1 node hashes
and all 32*(2N-1) retained tree bytes remain. Naive cleared outputs add 48N
writes and lose. The uncompiled, unapplied `salt-first-parent.patch` uses
indexed Rayon unzip and Vec::into_flattened; all native gates remain owed.
GPU full-tree construction adds 64N-32 transfer bytes relative to digest
download if today's host paths remain. Root-only timing omits openings.
Hash micro-optimizations are parked pending native exclusive/enclosing clocks.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context / accelerator: **none**. Device: one Intel Core Ultra 9
185H CPU worker. Witness, proof, serialization, verification, startup and
initial-prefill clocks; startup fraction; proof latency/bytes; steady-state
and total-workload rates: **unmeasured**. No long-context prefill, resident
proof series or decode ran. T128/T512 are R9 counts only; T512 unregistered,
LOW/HIGH excluded. Larger workloads remain allowed; attention can grow
quadratically. Private 8B >=50 proved tokens/s on RTX 5090 or a named high-end
GPU remains unachieved. D37–D41 application direction does not replace it.

Next local: rotate to sumcheck/GKR. Pin the five slot constructors and audit
public-shape preprocessing repeated per proof versus already resident. Read
prior metadata/cache/fraction-tree negatives first; preserve fresh CFS masks,
challenges, openings and refusals. Differential-test one narrow eligible seam.
Owner next: exposed column-hash/D2H/salt/first-level/upper-tree/path clocks;
then complete GPU clocks and independently verified fixed-context resident
1/2/4/8 workloads under shared build/heavy locks. Test this patch only if those
clocks show useful incidence. Main/Claude reviews and integrates; no merge.
Handoff: `handoffs/20261026-salted-merkle-fusion.md`.

Historical baseline, not rerun/reverified: nonDD 8B T128/L32, one 16-thread CPU
pass, GPU off, total 478.737 s = 0.267370 positions/s. prove_run 393.785 s includes
witness 98.348 s / load 17.595 s; seal 84.824 s overlaps, not additive. Receipt
922711264 B; fresh verify 42.709 s + load 13.681 s; recheck 34.395 s + load
10.739 s. Startup fraction, isolated serialization and steady slope unknown.
No GPU or 8B privacy acceptance follows. D33/D36 remain narrow CPU TinyLlama.

Only research outside runtime written. No native build, GPU, install, Git,
external message or production mutation. Saved reports do not establish
delivery/liveness. Final artifact audit: 1,477 checks PASS; 77 immutable
artifacts and 12 live source pins match; patch applies in memory only.
