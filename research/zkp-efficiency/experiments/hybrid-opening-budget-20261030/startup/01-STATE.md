# ZKP efficiency explorer — durable state

Cycle 0156 COMPLETE: `20261030T015649Z-fd1dbb78`.
Started 2026-10-30T01:56:49Z; checkpoint 2026-10-30T02:09:21.272454+00:00.
Deadline 02:16:49Z; next cycle no earlier than 02:56:49Z.
Read AGENDA.md every cycle.

**No measured proving improvement.** Opening-local serial scratch reuse
passed 436 synthetic Rust fixtures in three modes, including ordered
outputs and synthetic pad columns. All 42 injected synchronous failures
released simulated scratch. Independent Python bigint and bounded
scheduling references passed.

In a conditional historical R14 T128 example with 57 row-weight vectors,
serial reuse reduces device scratch allocation requests from 30 to 2
while retaining 1,273,664 bytes of requested scratch. Full staging also
reduces upload/download submissions from 15 each to 1 each, but requests
18,149,712 bytes of scratch. Neither saves matrix scans, kernel launches,
arithmetic, transfer payload bytes, masks, pads or proximity work. These
are synthetic API/capacity counts, not native elapsed savings.

Prior STATE/PROGRESS/AGENDA, all 82 prior hypotheses, history prefix
hashes, required project docs and native/held-source snapshots are in
experiments/opening-staging-20261030/. All prior hypotheses remain exactly
preserved; 83 records the test and 84 is the new hybrid question.

Validation scope: 436 Rust fixtures x three staging modes, with 175,772
scalar limb outputs per mode including three synthetic pad columns.
There are 143 controls: 130 default-hook counts, one error-stop case, six
shape/overflow cases and six value/order/proximity-position/protected-row/
fresh-call controls. Sixteen exported synthetic vectors match 1,344
independent Python bigint limbs. The final Python audit has 130,564
assertions, mostly descriptor-bound checks.

The exact additive native `EncodedStore: Sync` trait compiles in a
standalone mock harness; its default retains max-four calls and first-error
propagation. The native crate and review-only patch were not built/applied.
The root and held R14 whole files differ, but the scalar field and extracted
host fold, ZK wrapper, device fold and kernel bodies match.

The abstract lifetime model enumerates four batches across three FIFO
engines. One guarded slot has one safe order; two guarded slots have 89.
Without the reuse dependency, 454/462 one-slot schedules and 225/462
two-slot schedules corrupt generation tags. Six error cutpoints require
queued uses to drain before release. This is a bounded scheduling model,
not a CUDA race or cancellation proof.

No real CUDA arithmetic, ABI, device memory, asynchronous error handling,
Fiat–Shamir transcript, generated PCS pads, receipt byte parity, native
refusal behavior or privacy acceptance was tested. References were authored
in this lane, not independently reviewed by an external party. Zero rows,
zero vector counts and odd widths are primitive edges, not admitted profiles.

Next: test full challenge-vector staging with bounded max-four output
scratch, using a public byte budget and independent offset, overflow,
failure, pad and fresh-call controls. This hybrid is untested. Owner
measurements of exclusive allocation and transfer-submission costs take
precedence; if they are negligible, park staging work.

Global priorities remain: (1) owner-verified complete workloads on a
named high-end GPU, including resident-model 1/2/4/8-pass measurements;
(2) admitted context/DD/fidelity scaling; (3) exclusive phase/capacity
clocks. The complete-workload ceiling is
`N / (T - C_removed_exclusive + A_added)`. Free removal of an exclusive
fraction f is bounded by `1 / (1-f)`; f is unknown. No numerical 8B GPU
rate follows from the API counts.

Sources searched with native LIVE web tools: CUDA's older 2012 overlap
article; September 2026 PyTorch lifetime guidance; NVIDIA CUDA Rust's
current repository, release notes and inspected changelog commit; SumCATS;
October 2026 zkLLMPoT; official CUDA allocator ordering. Six records append
sources.jsonl from 1,032 to 1,038. Eight response hashes cover eight of nine
request batches; the first exploratory response remains only in native tool
history. Exact dates/nulls, release/changelog date disagreement, license
scope, inspected commit and 404/Cache miss blockers are recorded. No author
performance was reproduced and no foreign code executed.

Owner context, read only: MVP_STATUS at 01:54 UTC reports three verified
CPU classifier-policy receipts on one public 17-token post. This lane did
not reproduce or count them. The decisions register's concurrent 02:03
entry reports further gate-22 checks and draft-v2 progress, with a partial
real-block TS-1 check; it explicitly withholds privacy acceptance. These
updates do not amend the private 8B throughput target. Native source holds
remain in force; no supervisor or job liveness is inferred.

Seed 202610300156; one CPU affinity, nice 19, one Rust codegen unit.
Each leaf has a 40-second CPU limit, 45-second alarm, 50-second parent
timeout and 384 MiB address-space cap. Estimated memory: 300 MiB for the
standalone compile, 96 MiB otherwise. Compiler auxiliary threads were not
individually measured. Final compile: 1.526 s / 169,476 KiB maximum RSS;
probe: 0.116 s / 8,908 KiB; audit: 0.116 s / 15,408 KiB. These shared-host
correctness clocks are not prover or GPU benchmarks.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: none. The cost study models T128;
correctness work used one pinned Intel Core Ultra 9 185H CPU worker.
Witness, proof, serialization, verification, startup and initial-prefill
clocks, startup fraction, proof latency/bytes, steady-state rate and
total-workload rate: **unmeasured**. No long-context prefill, resident-model
series or decode ran. Larger workloads remain allowed; longer attention
can grow quadratically. Complete private 8B **>=50 proved tokens/s remains
unachieved**.

Carried older CPU 8B baseline, not rerun, reverified or newly counted:
T128, 32 layers, one 16-thread pass, GPU off. Total 478.737 s, or 0.267370
positions/s. `prove_run` 393.785 s includes witness 98.348 s and load
17.595 s; preceding sealing is 84.824 s with overlapping load 27.151 s and
witness 80.897 s. Receipt: 922,711,264 bytes. Verification: 42.709 s plus
13.681 s load. Serialization, startup fraction and steady slope are unknown.
These nested clocks must not be added as exclusive phases.

[Experiment](experiments/opening-staging-20261030/README.md) ·
[Handoff](handoffs/20261030-opening-staging.md) ·
[Dated report](progress/20261030T015649Z-fd1dbb78.md).

Only research files outside runtime were written. No production, Git,
receipt, calibration, instruction, safety-gate or reviewer files changed.
No GPU job, native build, install, downloaded-script execution, external
write/message, purchase, escalation or merge occurred. Main/Claude reviews
and integrates. Saved reports do not establish user delivery or supervisor
liveness.
