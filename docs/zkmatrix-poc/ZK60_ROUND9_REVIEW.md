# Round 9 — reviewed lane closure and next Fable queue

Codex, 2026-09-07. Victor requested the next Fable tasks and the reviews
needed to proceed, then added a lower-priority minimal ZKP subproject.
Integrator source: `44d72ffa5cb28d69bbedfa19d5f2a5026d9aa87a`.
Fetched lane pin: `3ad4d97ce4cb47b9eeeb76647a5a9159d15d2357`.
Lane source was read-only; no merge, production-code edit or GPU launch was
performed for this review. No subagents were launched.

The deliverable is [Fable's next queue](ZK60_FABLE_QUEUE.md), with matching
[task records](zk60_fable_tasks.json): CL12–CL20 and the expanded FA1–FA5.
The [zkp-core design scaffold](../../zkp-core/README.md) makes CL20 concrete;
it is not an extracted or runnable library yet.

## What the latest push actually adds

Since the prior `a1aa2b7` review, `82314a1` fixes the floor script's shell
JSON default: `${SUMMARY:-{}}` appended an extra closing brace to valid JSON.
The fixed `${SUMMARY:-"{}"}` form and its self-test parse the same expansion.
Codex independently ran `bash -n` and parser controls: a valid 49-case
summary passes; zero-case and missing-field summaries refuse.

`3ad4d97` archives a successful floor run at **`82314a1`**. Codex checked
the committed log/marker and all twelve retained individual prover logs:

- All four frozen profiles in CPU, GPU and forced hiding chunking match
  their full SHA-256 and exact length: **12 distinct matching cases**.
- The retained prover logs contain ACCEPT and the matching proof identity;
  the eight GPU-labelled cases also contain the device header.
- The oracle summary records **49 executed cases**, required/enabled GPU,
  and an RTX 4070 Laptop GPU. Both missing-feature controls are recorded.
- The committed marker is 0 and the log has twenty successful Rust result
  lines. The runner deleted proof files; this review checked recorded full
  hashes and retained logs, not independently retained proof artifacts.

This is useful archived hardware evidence and supersedes the old suggestion
that the lane never completed its floor run. It is **not final combined-tree
validation**: H1/FFN diagnostic commit `3ff8d5f` was merged afterward as
`c84668f`, and the round-8 cache fix `44d72ff` is not on the reviewed lane.
The lane report acknowledges that chronology but also calls the gates green
on the merged tree; CL12 asks for that wording to be corrected.

## Findings retained after review

All six pinned CPU suites were rerun successfully: planner 27, profile 34,
chunk sweep 24, pending memory 42, artifact profile 27, preflight 61 —
**215 tests**. GPU/PCS source and these tool/test files are unchanged since
`a1aa2b7`; the earlier findings were not fixed by the closure-only push.

| Finding | Current evidence | Next task |
|---|---|---|
| Preflight accepts absent/wrong binary digest, zero expected/executed cases, and flag-only full/target eligibility | All four synthetic mutations still return `go=true`, with no failed checks | CL13 |
| Floor runner remains tied to a checkout and eight prover threads; parser self-test is after the hardware oracle | Read directly from pinned `results/cl1_floors.sh`; its minimum-20 oracle threshold also does not bind the current case set | CL13 |
| Chunk sweep accepts negative prove time followed by failed exit | `parse_measured_log` + `reconcile` still report `prove_s=-1` and byte-identical comparison after `exit 1` | CL14 |
| Hiding fused/pruned opening assumes a nonempty query list | Source still reaches `qs.last().unwrap()` without an empty guard; not GPU-reproduced by Codex | CL15 |
| Successful resident outcome retains raw pads/powers in the planner's return event | Reproduced 12,359,168 live bytes versus declared 12,288,000, a 71,168-byte overcount | CL16 |
| The combined source needs its own validated gate | Archived run predates H1 merge and atomic cache pickup | CL17 |

The new queue preserves already accepted work: CL3's earlier capacity/reuse
fixes, CL5 validation, CL8 units/lifetimes and CL10 P1/P3 accounting. It does
not invalidate the archived CL6 sweep merely because its parser accepts bad
synthetic input. CL14 must establish whether the archived rows satisfy the
stronger evidence contract. No selector or timing claim is promoted here.

## Disposition of the lane's suggestions

- Integration remains Codex's responsibility after the remaining fixes and
  exact combined-source gate. The successful archived device tests are credited.
- Keep H1's validated process isolation. A new global configuration lock or
  scoped configuration refactor is not necessary to advance this queue.
- The requested ZK cache summary and concurrent publication fix are already
  completed by `44d72ff`; CL12 adopts them.
- CL19 turns the size-breakdown idea into a specific serializer/API handoff
  for Codex-owned code; no telemetry implementation is claimed yet.
- CL18 evaluates compact `n+q` pad/scale output after baseline correctness.
  Its proposed traffic savings remain a hypothesis until measured.
- The proposed 32-layer laptop P3 run is not queued for execution. Existing
  component evidence does not close full-relation or privacy obligations.

## Privacy and refactoring review scope

Codex read the actual FFN diagnostic, its observer/extractor boundary,
opening inventory and the substitute-weight identity test. No independent
Fable privacy closure was found in the reviewed lane handoff. FA1–FA5 now
specify exact reproduction, joint-observation, repair, model-identity and
arithmetic/security deliverables, including controls and shared-file owners.
They do not treat a repeat of Codex's tests as an independent review by itself.

For CL20, `hashline/Cargo.toml`, `lib.rs` and core imports expose concrete
extraction boundaries: PCS/sumcheck depend on randomness defined in `zk.rs`,
PCS embeds GPU dispatch, and layer code mixes compact PCS and cache concerns.
The new subproject must extract a maintained implementation with explicit
support and compatibility, preserving the other paths. The task is priority
3; a README-only scaffold or whole-application wrapper does not satisfy it.

## Evidence and limits

[Machine-readable review evidence](../../results/zk60_round9_review.json)
records pins, CPU commands/log hashes, the reproduced failures, parser checks,
source hashes, archive identity and retained per-case log hashes. Review
copies and the bounded CPU probe runner are under `/tmp/zk60-round9-review`.
An initial reviewer probe addressed `pool_simulation.events`, but events are
exposed as top-level `stages`; correcting that harness lookup yielded the
recorded completed run. No lane source was changed to make a check pass.

This round changes task/documentation records only. It does not repeat the
full Rust/native suite from round 8, implement a privacy repair, merge the
GPU lane, create a completed minimal ZKP library or establish throughput.
