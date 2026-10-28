# Cycle0124 — public BLAKE3 frontier, keyed and unkeyed

Run `20261021T081854Z-3ffe311a`, checkpoint 2026-10-21T08:32:53.210179+00:00. **No proving gain measured.**
AGENDA, state/findings, all790prior sources, required project notes and latest results
read/snapshotted at startup. Early STATE checkpoint completed. Current D37–D41 application
directions do not amend the private8B research target. All37hypotheses retained;
36 and37 materially refined. Owner top4 remain completeGPU+verifiedresident1/2/4/8;
DD/fidelity larger-context; complete private phase/capacity clocks; all-elevenFZC A/B.

Baseline: root unkeyed stream plus activeGPU keyed/unkeyed stream. Each host tree has
three clearing entrypoints and193u32/column state. Native delayed merge means entry
length at public chunkc is0 ifc=0, otherwise popcount(c−1)+1. The usual eagerpopcount(c)
fails atc=2. Proposed alternatives remove the stored lane and its load/store plus all
state clears, preserving24CVlevels and every compression. Dynamic depth is modeled,
not part of either patch. Original no-memset work remains in prior cycle.

Default128-row launch, per A/H commitment (logical bytes; not DRAM transactions):

| Counted geometry | Launches A/H | Original count traffic A/H | Added popcounts A/H | Extra request saving |
|---|---:|---:|---:|---:|
| T128 nonDD |27/30|13.25/14.75MiB|1,703,936/1,900,544|0.25MiB each|
| T128 DD |26/29|12.75/14.25MiB|1,638,400/1,835,008|0.25MiB each|
| T512 nonDD |72/87|71.5/86.5MiB|9,306,112/11,272,192|0.5MiB each|
| T512 DD |58/69|57.5/68.5MiB|7,471,104/8,912,896|0.5MiB each|

Against prior first-launch initialization, subtract one nn*4 count read from original
traffic. Full-clearing removal was already modeled in cycle0123; do not double-count it.
Current clearing covers the full best-fit pooled backing, at least48.25MiB T128 or96.5MiB
T512 per commitment in these geometries; actual backing/critical-path time unmeasured.
Request reduction can save ZERO physical backing. Repeated count traffic may hit cache.
No CV traffic or hashing arithmetic is eliminated. Do not add sequentialA/H as peak.

Hash model: **1,528 checks, 30 unkeyed + 19 keyed shapes, 109 restarts,
26 control types PASS**. Independent labelled-interval/source/cost audit: **1,835,886
checks, 262,144 prefixes, 64 large boundaries, nine source pins PASS**. Both models were
authored by this researcher; the cryptographic reference is independently implemented in
installed blake31.0.9. Diagnostic wall/RSS: 8.168926s/23,628KiB
and 2.392768s/16,592KiB. Every leaf: one-core affinity,nice19,
30s CPU/alarm,35s parent timeout,256MiB AS,64MiB estimate. No native build/GPU/proof ran.

Three chunk plans per unkeyed shape include irregular valid launches; partial tails,
global chunk counters, ROOT/endian, public schedule gaps/reorder/duplicate, capacity,
fresh keys and arbitrary partial-CV poison on restart are checked. First keyed model
usedflag64 incorrectly; installed reference rejected it. Source-pinnedflag16 correction
passes, and wrongflag64 is retained as a control. Failure artifacts/logs remain under
initial-keyed-flag-failure. Initial unkeyed pass remains under initial-unkeyed. Model
plan validation is a precondition, not a new native refusal. Restart tests assume safe
prior retirement; they cannot establish CUDA completion after failures.

Integration: `hashline/src/gpu/cuda.rs` three chunked entrypoints and
`k_hash_cols_stream` / active `k_hash_cols_stream_keyed`. Two alternative unapplied,
uncompiled patches are source-pinned, not merged. Preserve active64-thread keyed launch,
keys, flags, pads,salts,masks,transcript/opening/RNG and original refusal domains.
Native poisoned hash,salted Merkle path/full receipt + fresh independent verification,
privacy,allocation/launch/download failures and safe retirement remain owner gates.

Ceiling: unknown truly removable elapsed fractionf gives only1/(1−f) before extra
popcount/index costs. No numeric complete-GPU speed forecast. Falsify on any hash,
trace,key,flag,root/path,refusal,RNG,receipt/privacy mismatch or stale read; demote if
cache/retained capacity removes savings or enclosing verified workload regresses.

SevenLIVEqueries/nine primary source records appended. Pinned BLAKE3 C lazy-merging,
eager reference and release inspected; Blaze3MIT body/newolder dynamic-parallelism
screen; cuPQC2026 mode distinction; ChimeraOct16 and zkLLMPoTOct11 revisions; two
known streaming-access papers. No author benchmark reproduced. BLAKE3 release year
and Blazepublication/update/commit unavailable, recorded unknown; copyright is not
publication. BlazeCUDA directory returned restrictedURL, not bypassed. One reference-ID
navigation batch resolved wrong pages; excluded and repeated exact primary URLs.

New completed, independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Device: one Intel Core Ultra 9 185H CPU worker.
Witness / proof / serialization / verification clocks: **unmeasured**. Startup and initial-prefill
duration, startup fraction, proof latency/bytes, steady-state and total-workload rates: **unmeasured**.
No long-context prefill, resident-model proof series or decode ran. T128/T512 are frozen R9
counted geometry only; T512 is unregistered and LOW/HIGH fidelity layouts are excluded.
Larger workloads remain allowed; increased context can increase attention quadratically.
The complete private8B >=50 proved tokens/s target on RTX5090 or a named high-end GPU remains unachieved.

Carried historical baseline, not rerun/reverified: nonDD8B T128/L32, one CPU pass
with16threads, GPUoff; total478.737s =0.267370positions/s; prove_run393.785s includes
witness98.348s/load17.595s. Seal84.824s overlaps and is not additive. Receipt922711264B;
freshverify42.709s+load13.681s; recheck34.395s+load10.739s. Startupfraction,
isolatedserialization and steady slope unknown. No high-endGPU or8B privacy acceptance follows.

Next local: pin active tagged PCS/Merkle sources, separately count salted-leaf and
internal-node compressions, all required retained paths, transfers and recomputation for
one complete commitment. Differential-test keyed roots/all paths before any scheduling
proposal; stop counter micro-optimization until owner supplies exposed native clocks.
Owner next: native poisoned-buffer/hash/receipt/privacy gates, actual clear/counter/capacity
clocks and complete verified fixed-context resident1/2/4/8 sweep under shared heavy/build locks.

Handoff: `handoffs/20261021-public-blake3-frontier.md`; main/Claude reviews and integrates.
Only research outside runtime written. No production/Git/receipt/calibration/instruction/
reviewer edits, build/GPU/install, externalwrite/message,purchase or escalation.
Saved reports do not establish delivered messages or supervisor liveness.

Reproduce each leaf (one at a time):

```sh
python3 experiments/commitment-public-frontier-20261021/run_bounded.py probe.py
python3 experiments/commitment-public-frontier-20261021/run_bounded.py audit.py
```
