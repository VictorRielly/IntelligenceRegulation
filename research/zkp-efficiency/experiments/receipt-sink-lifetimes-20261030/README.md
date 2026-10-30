# Cycle0166 — completed-proof owners and bounded wire emission

Run `20261030T144123Z-85c19624`, 2026-10-30 UTC. **No measured proving
improvement.** H99's proposed late commitment-owner retirement is rejected:
the active source already releases witness/lookup transients and M/A/H owners
before core return. The run also drops typed segments before the sink and
flushes each byte vector before the next stage. Prior findings that there is
no full-run receipt buffer are preserved.

New H100 tests a narrower opportunity: emit the same segment through a bounded
writer rather than allocate one additional contiguous segment-sized vector.
The code is a locally authored Python wire-shape projection, not the native
encoder or a proof. It uses the source's exact field order, Goldilocks u64
representation, Fp2 limb order, 23 slots, 1024-entry mask vectors, 12-node mask
paths, and first/interior/last segment schedules. The independent descriptor
encoder/strict reader imports no candidate code. No real prompt, activation,
weight, token or credential is used.

**3,012 checks PASS, including 861 negative controls**: 21 fixtures, 126
budget variants, 210 modeled sink-failure cases and 315 malformed shapes.
Synthetic row widths 8/16/32, endpoint widths 32/16/8, opened columns 2/4/8,
23 synthetic slot geometries, 1/2/4-stage schedules; these are not admitted
model layouts or complete proof passes. Frames are 41,528–58,616 bytes.
Budgets 1/7/64/1024/4096/B+1 cover scalar, digest and buffer splits. Short
writes, EINTR retry, zero progress, create/write/sync/rename failures, sink
index/range/existing-file refusals, shape/ceiling preflight and header/trailer/
payload/truncation/extension controls are retained. Raw noncanonical words
are preserved by both emitters and refused by the strict transport reader;
no proof acceptance follows.

A real tiny research-only file smoke emits one frame with a 1024-byte buffer,
fsyncs its file and renames it, and compares every byte with the contiguous
reference. Fault injection is an in-memory disk-state model, not real ENOSPC,
crash, race, permission or durability testing. A separate artifact/reference
audit passes **448 checks**, importing neither candidate nor experiment code.
Eight active native source pins and seven literal lifetime/ordering facts
are retained. No native Rust/CUDA encoder/prover/cryptographic verifier ran.

The selected logical payload formula changes S+B to S+K, where S is the
typed segment, B its wire bytes and K the buffer. Typed S remains live during
candidate I/O; the old path drops S before I/O. Logical buffer length is not
allocation capacity, RSS, page cache, VRAM, or whole-run peak. There is no
measured memory or speed improvement. One segment's wire ceiling is 256 MiB
for trained profiles, but its actual B comes from the layout and may be much
smaller. No commitment, fresh mask, field operation, proof coverage, written
byte, file sync or independent verification is removed.

Main process 6.636196 s / 19,260 KiB maximum RSS; audit 0.118988 s / 18,792 KiB.
These are process correctness-check clocks, not proof/serialization benchmarks.
One nice19 CPU affinity, Intel Core Ultra 9 185H, Python3.10.12; 30 s CPU,
40 s alarm, 45 s parent timeout, 256 MiB address space, 64 MiB estimate.
Initial fixture JSON byte-string failure and its exact code/logs are retained;
no failed proving result is hidden. The final run includes EINTR controls.

Reproduce sequentially from the research directory:

```text
python3 -B experiments/receipt-sink-lifetimes-20261030/run_bounded.py experiment
python3 -B experiments/receipt-sink-lifetimes-20261030/run_bounded.py audit
```

Rerunning the experiment refreshes source snapshots; audit saved historical
pins before using a later native tree. Code, seed20261030166, commands, limits,
dimensions, saved synthetic fixtures, raw logs and source hashes are retained.
[Integration seam and obligations](INTEGRATION.md). Main/Claude reviews any
port; no production patch or merge. Top3 hypotheses remain complete verified
high-end GPU resident workloads, admitted context/fidelity scaling and native
exclusive phase/capacity evidence. H99 rejected, H100 conditional, all previous
98 hypotheses retained verbatim in the new hypothesis ledger.

LIVE primary search newly assesses older
[Gemini](https://eprint.iacr.org/2022/420), received2022-04-06: the author's
proof is independent of time/memory configuration, but its R1CS architecture
is not a drop-in native hiding PCS. Both PDF routes return403; repository
history returns429; the license page returns navigation without its body.
MIT is a repository label only, no inspected commit/license body. Refreshed
[Scribe](https://www.usenix.org/conference/usenixsecurity26/presentation/baweja),
[Streaming ZK](https://arxiv.org/abs/2301.02161),
[zkLLMPoT](https://arxiv.org/abs/2610.08258),
[StateSync release](https://github.com/Oraclizer/statesync-gkr/releases) and
[zk-stream](https://github.com/nzengi/zk-stream). Public audit sequences,
external privacy wrappers and disk-backed private state remain distinct from
this target. No author result reproduced or foreign code executed. Rust
[Write](https://doc.rust-lang.org/std/io/trait.Write.html) and Linux
[fsync](https://man7.org/linux/man-pages/man2/fsync.2.html) constrain the
transport design. Exact access/date/license/commit limits are in source records.

For the target: new independently verified full-stack proofs / complete-model
passes / proved positions **0/0/0**. Actual model context **none**; device
**one CPU affinity, no GPU**. Witness/proof/serialization/verification/startup/
initial-prefill clocks, startup fraction, proof bytes/latency and steady-state/
total-workload proved-token rates **unmeasured**. No long-context prefill,
resident-model proof series or decode ran. Larger workloads remain allowed;
attention can grow quadratically. Private8B >=50 proved tokens/s on RTX5090
or another named high-end GPU remains unachieved.

Baseline is the real native contiguous segment encoder and synchronous sink.
Removed critical cost C, added cost A unknown; ceiling N/(T-C+A), free-removal
bound N/(T-C), necessary >=50/s T-C+A<=N/50. Owner needs encode/write/sync/
rename/hash exclusive clocks and actual capacities before a port. Stop toy
writer variants absent materiality. Next local: source-pin whether the newly
active split-width profile changes the dominant proof/fold/lookup geometry;
refresh only public metadata if current owner evidence is available. Do not
duplicate owner R14 implementation/review or launch heavy work.

Only research outside runtime written; no production/Git/receipt/calibration/
gate/instruction/reviewer changes, native builds/GPU/install/foreign execution,
external write/message, purchase, escalation or merge. Saved reports do not
establish user-message delivery or supervisor liveness.
