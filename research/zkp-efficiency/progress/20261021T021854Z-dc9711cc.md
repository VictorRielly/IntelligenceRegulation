# FZC scratch storage study — cycle 0118

Run `20261021T021854Z-dc9711cc`. Checkpoint UTC: 2026-10-21T02:33:40.559814+00:00.

**No proving speedup measured.** The active GPU FZC constructor allocates a
cached-read fallback host pin even when mapped output succeeds. A separate host
pin serves its CPU tail. Reusing these allocations can remove driver allocation,
free and mapping calls; it removes no proof arithmetic, transfer, device arena,
masking or serialization. Exact native incidence and exclusive time are unknown.

In a conditional fixed-shape sequence of 32 attempts (degree 5, support present,
tail_log 5, each reaching half=32), host allocation events fall from 96 to 3 and
mapping queries from 32 to 1, retaining 10,952 B. A changing-shape sequence agrees
with the independent audit: 96 -> 6 allocation events; cumulative allocated bytes
513,792 -> 32,112; idle retention 21,704 B. Growth raises transient host capacity
from a 21,704 B fresh baseline peak to 31,944 B. Driver page granularity is unknown.
This is a request-count opportunity, not a memory-peak saving or a runtime result.

The storage probe passes **1,418 checks**, 96 fixtures / 320 synthetic messages,
36 changed-shape cases and 17 negative-control types. Its independent reference
allocates fresh byte arrays and compares every returned word and synthetic hash
chain; it does not evaluate the FZC polynomial. The source/order census passes
24 checks over 120 event interleavings in 16 families. All eight cases
with the same stream and reset after successful synchronization are safe in this
logical model; pre-sync reset and foreign-stream writers expose stale observations.
The separate reviewer imports no candidate code and passes six checks with matching
changing-shape allocation counts. No native concurrency or memory ordering was tested.

Critical constraints: a retained seq=1 can satisfy a new attempt that restarts at
seq=0; changing degree moves the flag into prior payload. Clear the new active
range only after every prior writer completes. Cudarc 0.13.9's existing constructor
synchronize is stream-scoped; it may supply the fence without an added barrier
only for uses on that stream. Publication of mapped results is not final completion.
A generation plus last-submission completion event, bounded quarantine, and
requested-length views remain necessary. Copying a cached 12-word capacity from
a new 10-word d_sums would overread it. Never pass capacity as the active slice.

Keep fallback acquisition eager. Lazy fallback moves a resource failure into a
proof; cache hits also cannot reproduce every physical allocator refusal. Preserve
all mathematical refusals and process-wide mapped-broken behavior. Existing native
timeout drops the mapping before explicit fallback sync: this is a source-level
lifetime risk for review, not a confirmed native use-after-free. No native adapter
is justified by these tests alone.

Baseline: per-attempt FzcMapped + fallback PinBuf, and a separate tail PinBuf.
Eliminated work: conditional recurring host registration/map/free calls only.
Added costs: owner/lease management, exact-length views, fresh active clearing,
completion binding, growth capacity and failure quarantine. With unknown exclusive
allocation fraction f, free deletion is bounded by 1/(1-f); added costs reduce it.
No numeric end-to-end rate follows. Falsify on stale words, length/sequence/refusal
mismatch, unsafe cleanup, unbounded retention, negligible allocation cost or slower
enclosing complete-proof time.

Five native LIVE queries produced seven primary records (737 -> 744): current
Chimera's October 16 revision, ICICLE's latest v4.0.0 release and inspected commit,
CUDA 13.4 guidance, the October 14 Grace-Blackwell study, and older 2012/2021 CUDA
allocation/transfer methodology. The 2012 pinned-transfer article is newly assessed;
2021 device stream-ordered allocation is not a host-pinning replacement. ICICLE
commit 6c77775961b0e4dc2be359feec1ac11536c18043 and current MIT license body were
inspected; release year was not rendered, so none is guessed. NVIDIA sample paths
returned 404; its current BSD-style license body was inspected but not the sample.
No external code or author performance was executed/reproduced. Source dates,
licenses, exact URLs and access failures are in source-records.jsonl.

Thirty-four ranked hypotheses are retained. Rank 34 is materially refined with
this tested storage protocol and the question of reusing the existing constructor
stream fence. The top four owner priorities stay unchanged: complete high-end GPU
phase/capacity clocks; DD at larger supported contexts; actual private lifetime
telemetry; all-eleven FZC native A/B. D32's new <=1.02x perplexity amendment is
recorded; D33/D36 remain narrow TinyLlama CPU acceptances. D37's classifier
application does not replace the private 8B research target.

## Reproduce and scope

From the research directory, run sequentially:

1. `nice -n 19 python3 experiments/fzc-scratch-leases-20261021/audit/independent_audit.py`
2. `python3 experiments/fzc-scratch-leases-20261021/run_bounded.py probe.py`
3. `python3 experiments/fzc-scratch-leases-20261021/run_bounded.py census.py`

The probe checks the independently generated audit counts. commands.jsonl preserves
all local probe/census launches and successful refinements. Seed: 202610210118.
Probe/census clocks: 0.021853 / 0.019860 s;
RSS: 16,340 / 14,712 KiB. One worker/core, nice 19,
59 s CPU/alarm, 60 s parent timeout, 512 MiB address space; estimated <=64 MiB.
Independent audit: one worker/core, nice 19, 30 s CPU/alarm, 256 MiB address space,
under one second as reported by the reviewer. These are diagnostic script clocks.
No build, GPU, native FZC, CFS masker, PCS, receipt or verifier ran. Storage payloads
include arbitrary u64 bit patterns; they are not claims of canonical field inputs.

New completed, independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research device: one Intel Core Ultra 9
185H CPU worker per experiment. Witness, proof, serialization and verification clocks:
**unmeasured**. Startup duration/fraction, steady-state rate and total-workload rate:
**unmeasured**. No long-context prefill, resident-model proof series or decode ran.
The 32-attempt traces are synthetic allocation schedules, not 32 model passes.
Larger workloads remain allowed; longer contexts can increase attention work quadratically.
The complete private 8B target of >=50 proved tokens/s remains unachieved.

Next local experiment: model mapped timeout/error cleanup with a pinned last-use
oracle across copy/sync failure, context poison and other-stream access; distinguish
known-safe retirement from quarantine without assuming cuMemFreeHost synchronizes.
Native owner first needs allocation incidence and exclusive/enclosing phase clocks.
Keep GPU/native work under shared heavy/build locks; do not launch it in this lane.

Integration seam, interface and validation gate:
[handoff](../../handoffs/20261021-fzc-scratch-leases.md). Main/Claude reviews and
integrates; no merge here. Only research files outside runtime/ were written.
No production, reviewer, instruction, calibration, Git or receipt changes; no GPU,
installation, downloaded-code execution, external writes/messages or escalation.
Saved reports do not establish delivery or supervisor liveness.

Checkpoint update, read at 2026-10-21 02:34 UTC: production status and decisions
changed during this cycle. Their complete new text and diffs are preserved under
startup/checkpoint__*. D33 and D36 now extend to frozen-r11 by the register's
02:27 ruling; they remain scoped to named TinyLlama CPU artifacts. D38 records
Shieldstral-1.0-3B text classification and a public-threshold yes/no logit statement,
with only verdict/model/policy disclosed. This application direction does not
replace this lane's private 8B throughput target. The status also reports the first
eight DD gate captures passing (gate evidence, not a new privacy acceptance) and
LOW + 12-bit-score 8B fidelity at 1.011x/1.010x with zero refusals. These are owner
reports, not reproduced here; new profile/gate and complete GPU clocks remain owed.
The status heading labels 02:40 UTC; the actual read time above is retained.

Evidence integrity: 145 checks PASS; 50 artifact hashes and 10 live/source-copy pins match. All 737 prior source records, the prior findings prefix and all 34 hypothesis entries are retained. Concurrent owner updates were read and snapshotted. Finalized UTC: 2026-10-21T02:36:20.454182+00:00.
