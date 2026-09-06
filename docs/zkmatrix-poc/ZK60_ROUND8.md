# ZK60 round 8 — public-cache publication and follow-up review

Baseline `3ff8d5f`, published to `origin/perf/zk-batch-optimizations` on
2026-09-06. Victor requested commit/push and continued implementation.

Codex takes the explicit CL9 handoff in Claude's `a1aa2b7` report:
`hashline/src/wcache.rs` and dedicated atomic-publication tests, plus the
missing cache report in Codex-owned `hashline/src/bin/hashline.rs`.
Claude keeps GPU/PCS/planner/tool ownership. Codex reviews committed lane
source read-only, initially pinned at `a1aa2b7`; concurrent edits are excluded.
No subagents are used. Private protocol implementation still depends on the
independent joint-mask review; the cache fix does not change that gate.

## Implemented change

CL9 reproduced lost same-key saves caused by every writer truncating the
same `.wc.tmp` file. The fix uses exclusive, per-writer temporary
files in the entry's directory and publishes only complete files by rename.
Cache keys and serialized bytes stay compatible; interrupted cache writes
remain optional cache misses. A PID plus atomic counter names each temporary
file; `create_new` reserves it without truncating an existing file and retries
stale-name collisions. Only the owning writer cleans up its file on error.
An abrupt process death can leave a temporary file; no automatic directory
sweep is added because another writer may still own its files. Successful
publication is atomic within the same directory, without a new crash-durability
promise or changes to cache keys, entry format or proof transcripts.

The old code loses 65 of 96 saves in the dedicated regression. Four tests
pass after the fix: 96 simultaneous-thread saves, 96 saves across four
processes with concurrent authenticated reads and stale-name collisions,
interleaved partial writers with an already-open reader, and cleanup after
abandonment/failed rename. The existing corruption/shape/key tests remain.
The ZK v3 command now prints the existing cache summary after its timing row.

Review checks use pinned copies under `/tmp/zk60-round8/claude`. CPU-only
planner/profile/preflight unit tests do not authorize hardware execution.
Heavy validation uses the shared lock, two threads and detached logs with
an exit marker if expected to exceed five minutes. No GPU is launched here.

## Validation and review

All 151 integrated release Rust tests pass, and all 67 library tests also
pass with sixteen test threads. All four frozen proofs match their full
hashes and lengths. Separate cold and warm public-cache processes reproduce
the frozen 87,697,008-byte ZK v3 proof exactly: cold reports 12 misses, warm
reports 12 hits, neither rejects an entry or leaves temporary files. P3 with
a cache refuses with expected exit 2 before creating its directory. B4
receipt parity and separate-process B5 verification pass. The full
Python/native suite passes **144 tests with zero skips in 915.287 seconds**.
The full run completes under `/tmp/zk60-round8/validation` with exit marker 0.
A final cleanup correction disarms the temporary pathname after successful
publication; its extended reader test checks reuse by a new owner. Final
Rust/cache checks for that adjustment are running in
`/tmp/zk60-round8/final-cache`; Python/native code is unchanged.

The [pinned Claude review](ZK60_ROUND8_CLAUDE_REVIEW.md) runs 215 Python tool
tests and reviews all fifteen archived matrix rows. Several earlier findings
are resolved; new CL6/CL11 validation gaps remain with Claude, as does the
final GPU floor gate. Its launch held the build lock outside a script that
requested the same lock inside, deadlocking the shared queue for hours.
After inspecting the exact holder/waiter chain and obtaining execution
approval, Codex terminated only the waiting lock request. The script recorded
failure before any build/GPU work, released both locks, and Codex's queued
validation started. Relaunch the floor script with only the outer heavy lock.
The same wrapper was then launched again, deadlocking a second time before
compilation. Codex stopped only its new waiting request (PID 123888) with
approval, archived its failure log/marker under `/tmp/zk60-round8/deadlocks`,
and put the exact corrected command at the top of the shared task board.
