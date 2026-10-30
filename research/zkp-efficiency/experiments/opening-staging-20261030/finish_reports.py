import datetime,json,pathlib
D=pathlib.Path(__file__).resolve().parent;R=D.parent.parent
RUN='20261030T015649Z-fd1dbb78'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
metrics='''New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: none. The cost study models T128;
correctness work used one pinned Intel Core Ultra 9 185H CPU worker.
Witness, proof, serialization, verification, startup and initial-prefill
clocks, startup fraction, proof latency/bytes, steady-state rate and
total-workload rate: **unmeasured**. No long-context prefill, resident-model
series or decode ran. Larger workloads remain allowed; longer attention
can grow quadratically. Complete private 8B **>=50 proved tokens/s remains
unachieved**.
'''
summary='''**No measured proving improvement.** Opening-local serial scratch reuse
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
'''
next_action='''Next: test full challenge-vector staging with bounded max-four output
scratch, using a public byte budget and independent offset, overflow,
failure, pad and fresh-call controls. This hybrid is untested. Owner
measurements of exclusive allocation and transfer-submission costs take
precedence; if they are negligible, park staging work.
'''
owner='''Owner context, read only: MVP_STATUS at 01:54 UTC reports three verified
CPU classifier-policy receipts on one public 17-token post. This lane did
not reproduce or count them. The decisions register's concurrent 02:03
entry reports further gate-22 checks and draft-v2 progress, with a partial
real-block TS-1 check; it explicitly withholds privacy acceptance. These
updates do not amend the private 8B throughput target. Native source holds
remain in force; no supervisor or job liveness is inferred.
'''
limits='''Seed 202610300156; one CPU affinity, nice 19, one Rust codegen unit.
Each leaf has a 40-second CPU limit, 45-second alarm, 50-second parent
timeout and 384 MiB address-space cap. Estimated memory: 300 MiB for the
standalone compile, 96 MiB otherwise. Compiler auxiliary threads were not
individually measured. Final compile: 1.526 s / 169,476 KiB maximum RSS;
probe: 0.116 s / 8,908 KiB; audit: 0.116 s / 15,408 KiB. These shared-host
correctness clocks are not prover or GPU benchmarks.
'''
baseline='''Carried older CPU 8B baseline, not rerun, reverified or newly counted:
T128, 32 layers, one 16-thread pass, GPU off. Total 478.737 s, or 0.267370
positions/s. `prove_run` 393.785 s includes witness 98.348 s and load
17.595 s; preceding sealing is 84.824 s with overlapping load 27.151 s and
witness 80.897 s. Receipt: 922,711,264 bytes. Verification: 42.709 s plus
13.681 s load. Serialization, startup fraction and steady slope are unknown.
These nested clocks must not be added as exclusive phases.
'''
bound='''Global priorities remain: (1) owner-verified complete workloads on a
named high-end GPU, including resident-model 1/2/4/8-pass measurements;
(2) admitted context/DD/fidelity scaling; (3) exclusive phase/capacity
clocks. The complete-workload ceiling is
`N / (T - C_removed_exclusive + A_added)`. Free removal of an exclusive
fraction f is bounded by `1 / (1-f)`; f is unknown. No numerical 8B GPU
rate follows from the API counts.
'''
restrictions='''Only research files outside runtime were written. No production, Git,
receipt, calibration, instruction, safety-gate or reviewer files changed.
No GPU job, native build, install, downloaded-script execution, external
write/message, purchase, escalation or merge occurred. Main/Claude reviews
and integrates. Saved reports do not establish user delivery or supervisor
liveness.
'''
links='''[Experiment](experiments/opening-staging-20261030/README.md) ·
[Handoff](handoffs/20261030-opening-staging.md) ·
[Dated report](progress/20261030T015649Z-fd1dbb78.md).
'''
short='# ZKP efficiency progress\n\nCycle 0156 complete — `'+RUN+'`, October 30, 2026 UTC.\n\n'+summary+'\n'+next_action+'\nSix LIVE primary-source records saved; all 82 prior hypotheses retained.\nHypothesis 83 records this result; 84 proposes the hybrid.\n\n'+metrics+'\n'+links+'Saved reports do not establish user delivery or supervisor liveness.\n'
(R/'PROGRESS.md').write_text(short)
validation='''Validation scope: 436 Rust fixtures x three staging modes, with 175,772
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
'''
sources='''Sources searched with native LIVE web tools: CUDA's older 2012 overlap
article; September 2026 PyTorch lifetime guidance; NVIDIA CUDA Rust's
current repository, release notes and inspected changelog commit; SumCATS;
October 2026 zkLLMPoT; official CUDA allocator ordering. Six records append
sources.jsonl from 1,032 to 1,038. Eight response hashes cover eight of nine
request batches; the first exploratory response remains only in native tool
history. Exact dates/nulls, release/changelog date disagreement, license
scope, inspected commit and 404/Cache miss blockers are recorded. No author
performance was reproduced and no foreign code executed.
'''
dated='# Cycle 0156 — opening-local staging\n\nRun `'+RUN+'`; checkpoint '+now+'.\n\n'+summary+'\n'+validation+'\n'+bound+'\n'+next_action+'\n'+sources+'\n'+owner+'\n'+limits+'\n'
dated+='''Audit history: the first audit incorrectly assumed the copied scalar
field omitted its tests; the assertion now correctly checks the whole file.
A later audit stopped on the legitimate concurrent decisions-register
update. Its original snapshot remains pinned; the new documentation is
stored separately. Both failed logs are retained. Native output results
did not change.

'''+metrics+'\n'+baseline+'\n'+restrictions+'\n'+links.replace('(experiments/','(../experiments/').replace('(handoffs/','(../handoffs/').replace('(progress/','(../progress/')
(R/f'progress/{RUN}.md').write_text(dated)
state='# ZKP efficiency explorer — durable state\n\nCycle 0156 COMPLETE: `'+RUN+'`.\nStarted 2026-10-30T01:56:49Z; checkpoint '+now+'.\nDeadline 02:16:49Z; next cycle no earlier than 02:56:49Z.\nRead AGENDA.md every cycle.\n\n'+summary+'\n'
state+='''Prior STATE/PROGRESS/AGENDA, all 82 prior hypotheses, history prefix
hashes, required project docs and native/held-source snapshots are in
experiments/opening-staging-20261030/. All prior hypotheses remain exactly
preserved; 83 records the test and 84 is the new hybrid question.

'''+validation+'\n'+next_action+'\n'+bound+'\n'+sources+'\n'+owner+'\n'+limits+'\n'+metrics+'\n'+baseline+'\n'+links+'\n'+restrictions
(R/'STATE.md').write_text(state)
readme='''# Opening-local fold staging — cycle 0156

'''+summary+'\n'+validation+'\n'
readme+='''For B = ceil(k/4), requested device scratch is
`16 * min(k,4) * (rows+n)` bytes for baseline/serial reuse, and
`16 * k * (rows+n)` for full staging. All modes upload `16*k*rows` bytes,
download `16*k*n` bytes and launch B unchanged max-four kernels.

Conditional historical R14 T128/f_e9 standalone A/H counts, including the
fresh proximity vector; current full-run groups and 8B geometry are unknown:

| Role | Vectors / chunks | Allocation requests, baseline → serial | Baseline/serial scratch B | Full scratch B |
|---|---:|---:|---:|---:|
| A nonDD | 57 / 15 | 30 → 2 | 1,273,664 | 18,149,712 |
| H nonDD | 12 / 3 | 6 → 2 | 1,257,984 | 3,773,952 |
| A DD | 59 / 15 | 30 → 2 | 1,265,856 | 18,671,376 |
| H DD | 13 / 4 | 8 → 2 | 1,248,000 | 4,056,000 |

Full staging requests 14.25x/14.75x the current maximum A scratch. A two-slot
ring requests twice the serial scratch and still submits every transfer.
No overlap or time saving is established. Simulated output clones and
sentinels are correctness instrumentation, not predicted GPU operations.

The interface sketch is `opening-hook-review-only.patch`: add
`EncodedStore::fold_rows_opening` with an ordered chunks-of-four default,
and call it only from the ZK device wrapper. No optimized CUDA override is
implemented. Serial reuse would copy each chunk into two fresh opening-local
buffers. Full staging needs offset slices and longer buffer ownership.
The current kernel and max-four contract remain separate and unchanged.

The default hook retains call order and error propagation. Optimized
overrides may validate malformed shapes earlier, hold the GPU mutex longer,
and observe device errors later. Native refusal/error/publication gates
must check this. Never retry a failed launch as a fallback. All queued
uses must finish before resource release, including error/panic/cancel.
No private-derived contents, masks, openings or randomness may be retained
across proofs. Shape-only preflight selects a mode before device work.

Owner measurements required: actual role/rows/n/k/groups, allocated versus
requested capacity, host flat/download/conversion coexistence, GPU peak,
exclusive lock wait, flatten, allocation, H2D, kernel, D2H, conversion,
destruction/error drain and enclosing verified-workload time. Current
`secs_fold` starts after lock acquisition and conflates most other phases;
its local H2D byte counter omits rho uploads. Fewer API calls cannot locate
removable critical-path time. Falsify on negligible exclusive cost, excess
capacity, wider-lock/workload regression, early reuse/free or any native
limb/order/refusal/receipt/privacy mismatch.

Fixtures use rows 0/1/3/33, widths 1/7/17 and vector counts
0/1/4/5/9/12/13/57/59. The four actual row-count cases use width three,
not full matrices. Dense, boundary, protected-tail and pure-imaginary data
are synthetic. Source/body pins, public test vectors, commands, results,
costs and lifetime controls are retained alongside this report.

Reproduce one stage at a time from the research directory:

```sh
python3 experiments/opening-staging-20261030/run_bounded.py prepare
python3 experiments/opening-staging-20261030/run_bounded.py pin-held
python3 experiments/opening-staging-20261030/run_bounded.py compile
python3 experiments/opening-staging-20261030/run_bounded.py probe
python3 experiments/opening-staging-20261030/run_bounded.py audit
```

Use a fresh experiment copy before preparation: it snapshots current
evidence and writes the early STATE checkpoint. Do not rerun `record.py`;
it appends the cycle's source ledger. Review source drift first.

'''+limits+'\n'+sources+'\n'
readme+='''Primary links: [CUDA 2012](https://developer.nvidia.com/blog/how-overlap-data-transfers-cuda-cc/),
[PyTorch lifetime guidance](https://docs.pytorch.org/devlogs/eager/2026-09-29-cross-stream-memory-without-record-stream/),
[CUDA Rust changelog commit](https://github.com/NVIDIA/cuda-rust/commit/a6f1706cd832f0919b981cf61c86010c6c7c0c64),
[SumCATS](https://tanvirarafin.github.io/assets/pdf/DATE_2026.pdf),
[zkLLMPoT](https://arxiv.org/abs/2610.08258),
[CUDA allocator ordering](https://docs.nvidia.com/cuda/archive/13.1.0/cuda-programming-guide/04-special-topics/stream-ordered-memory-allocation.html).

'''+next_action+'\nA57 hybrid requested scratch would be 4,256,080 bytes; this is untested\ncapacity arithmetic only.\n\n'+bound+'\n'+owner+'\n'+metrics+'\n'+restrictions
(D/'README.md').write_text(readme)
handoff='''# Opening-local max-four staging — review only

'''+summary+'''
Interface: add `EncodedStore::fold_rows_opening(rhos)` with an ordered
chunks-of-four default; replace only the device arm of
`fold_rows_multi_zk`. CUDA may override using two fresh opening-local
buffers. Retain the current kernel, ordered weights, all mask/proximity
rows and the existing pad fold. The default hook alone has no performance
benefit. Do not apply while owner source holds persist.

Patch: [review-only diff](../experiments/opening-staging-20261030/opening-hook-review-only.patch).
Implementation model: [staging.rs](../experiments/opening-staging-20261030/staging.rs).
Validation: [result](../experiments/opening-staging-20261030/result.json),
[costs](../experiments/opening-staging-20261030/cost-study.json),
[lifetime model](../experiments/opening-staging-20261030/lifetime-study.json).
The exact additive native Sync trait compiles in the standalone harness.
No native crate or CUDA override was built; no production diff was applied.

'''+validation+'''
Before integration, measure actual public opening groups and exclusive
allocation/copy/lock/kernel/conversion/destruction costs, actual capacity
and enclosing verified workloads. Current `secs_fold` mixes most phases
and excludes lock wait; rho upload bytes are missing locally. Added
synchronization, startup and drain remain charged. Use current owner locks.

Copy-into-preallocated API/ABI and real asynchronous errors are untested.
Keep storage alive through all queued uses and error/panic/cancellation;
full staging changes error cadence and mutex scope. Publish nothing on
failure and never retry a failed launch. Mode selection uses public shape
and capacity before work. No cross-proof private contents or blinding reuse.
Exact proof bytes, refusals, soundness/privacy and independent receipt
verification must pass owner gates. Falsify on negligible exclusive savings,
capacity/lock/workload regression or any parity/lifetime failure.

'''+next_action+'\n'+bound
(R/'handoffs/20261030-opening-staging.md').write_text(handoff)
append='\n## Cycle 0156 — opening-local staging and scratch lifetime\n\n'+readme.split('\n',1)[1]
(D/'findings-append.md').write_text(append)
h=next(x for x in json.loads((D/'history-pins.json').read_text()) if x['path']=='FINDINGS.md')
p=R/'FINDINGS.md';old=p.read_bytes();assert old[h['prefix_bytes']:].startswith(b'\n## Cycle0156');p.write_bytes(old[:h['prefix_bytes']]+append.encode())
c=json.loads((D/'completion.json').read_text());c['final_report_checkpoint_utc']=now;(D/'completion.json').write_text(json.dumps(c,indent=2)+'\n')
print(json.dumps({'status':'reports readable and checkpointed','utc':now}))
