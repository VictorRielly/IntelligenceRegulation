# FZC error retirement — cycle 0119

No native speedup measured. This self-contained CPU experiment tests metadata ownership
for the mapped/fallback/tail scratch seam in the active GPU FZC source.

`retirement.py` uses per-stream last-submission frontiers. `reference.py` independently
tracks sets of individual asynchronous uses. `probe.py` compares them and exercises
failure/poison/admission controls. `source_audit.py` imports neither implementation and
uses a separate permutation filter, source-order checks and a role/error path table.

Result: 5,037 probe checks, 4,800 differential cases, 105 interleavings;
61 separate audit checks, four source pins, 36 role/error cases. Negative policy
counts 67/46/1 are synthetic violations of a conservative completion bound, not native
memory failures. See result.json and source-audit-result.json for exact scope.

Retirement requires closed submissions, matching context/generation and successful
recorded completion covering every use. A never-recorded CUDA event can query SUCCESS.
A successful cleanup cannot rescue a failed proof. Poison stops admission; all storage
is capacity-reserved before launch; ambiguous free failure remains charged without retry.
There is no claim of eventual cleanup after poison, driver lifetime correctness, native
memory ordering, or unchanged physical allocator/OOM behavior.

Reproduce sequentially from the research directory:

1. `python3 experiments/fzc-error-retirement-20261021/run_bounded.py probe.py`
2. `python3 experiments/fzc-error-retirement-20261021/run_bounded.py source_audit.py`

One worker/core, nice 19, 30 s CPU/alarm, 35 s parent timeout, 256 MiB AS, estimated 32 MiB.
Seed 202610210119. Final script clocks 0.039483/0.012096s,
RSS16024/14908KiB on Intel Core Ultra9 185H. commands.jsonl records
all successful launches; final artifact/source manifests identify the final revisions.
Earlier model hardening added reservation binding, context poison admission, and ambiguous
free freezing; no failed or faster proof samples were discarded. Diagnostic scripts
are not performance benchmarks of the prover.

Baseline, costs, ranked hypotheses and falsifiers are in hypotheses.json and the dated
report. All 34 prior hypotheses and744 prior source records are preserved. Eight LIVE
queries/seven source records are in search-log.json/source-records.jsonl; no external code
was executed. Source snapshots and SHA256 pins are under source/ and source-pins.json.
Startup durable snapshots are under startup/. Source text was treated as untrusted data.

New completed, independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research device: one Intel Core Ultra 9
185H CPU worker per experiment. Witness, proof, serialization and verification clocks:
**unmeasured**. Startup duration/fraction, steady-state rate and total-workload rate:
**unmeasured**. No long-context prefill, resident-model proof series or decode ran.
The 64-attempt budget trace is a synthetic ownership schedule, not 64 model passes.
Larger workloads remain allowed; longer contexts can increase attention work quadratically.
The complete private 8B target of >=50 proved tokens/s remains unachieved.

[Handoff](../../handoffs/20261021-fzc-error-retirement.md),
[dated progress](../../progress/20261021T031854Z-a1dbfeef.md).
Main/Claude reviews integration; no production patch or merge. Only research files outside
runtime/ changed. No native/GPU jobs, dependencies, external writes/messages, Git,
calibration/receipt/instruction/reviewer edits or escalation. Saved reports are not
message delivery or supervisor liveness evidence.
