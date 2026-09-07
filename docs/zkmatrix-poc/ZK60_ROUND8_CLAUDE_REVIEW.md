# Claude follow-up review at `a1aa2b7`

Codex, 2026-09-06. Pinned source:
`a1aa2b7eb56a59c543c9ba9ca4f8f3430c122b96`. Lane source is reviewed read-only;
no GPU was executed by Codex and no lane source was merged. The
[evidence record](../../results/zk60_round8_claude_review.json) contains exact
pins, CPU test logs/hashes, reproductions and archived matrix checks.

## Resolved findings

**215 Python tests pass** across six pinned suites: component planner 27,
CL5 profile 34, CL6 sweep 24, CL8 pending memory 42, CL10 artifact profile 27,
and CL11 preflight 61. The initial temporary CL5 checkout omitted a required
sample log; copying that same pinned fixture resolves the setup error.

- **CL3:** `4cda3da` recognizes that a warm exact encoded buffer makes the
  forced late fallback unreachable, and simulates successful resident
  completion. The component planner enforces the 64-buffer pool cap.
  The old capacity double counting, chunked-return and warm-refusal findings
  are superseded. One smaller inconsistency remains: the new resident-outcome
  return snapshot includes 71,168 bytes of raw pads/powers at the 300-row
  probe, while its declared post-return live total correctly excludes them.
  Free those raw buffers in that snapshot too; this is an overcount, not
  evidence of an unsafe smaller peak.
- **CL4:** `de911a0` fixes the embedded Python parser. Independent CPU checks
  accept a valid 28-case summary and reject zero-case/missing summaries. The
  script records binary hashes and a tracked-source delta hash. Move its
  parser self-test before the hardware oracle (it currently follows it), and
  still supply successful final-source floor evidence.
- **CL5:** `64f3e54` rejects nonzero exits, contradictory metadata, impossible
  phase totals and invalid clocks before ranking. The new matrix runner checks
  exits, GPU/verification, full proof hashes and cache state. All **15**
  committed `cl5_r7` logs in `09742d8` pass the new parser's eligibility gate.
  These remain archived noisy diagnostics, not new Codex hardware measurements.
- **CL8:** `81abdda` reuses the shared shape/pool rules, rejects invalid numeric
  dimensions and bare FFN row counts, and distinguishes raw frees from pooled
  returns. The earlier negative-byte and 8,192-byte chunk-scratch results are
  superseded. Pending blocks still explicitly contain unimplemented dimensions.
- **CL10:** `ded8dc4` separates plain P1 and hiding P3 W rows/salts, counts
  declared group/proximity vectors and labels the remaining residual honestly.
  Its source-derived mode delta accounts for 45,056 data + 8,192 salts +
  12,288 vector + 96 extra sumcheck bytes. The earlier 53,248-byte column
  misattribution is superseded. This is byte accounting, not a serialization
  runtime improvement.
- **CL9:** `a1aa2b7` explicitly primes its cache-test namespace, adds actual
  process proof comparisons/P3 refusal and ties copied packing to a real
  prover cache entry. It also reproduces lost saves from shared `.wc.tmp`
  names and explicitly hands that production fix to Codex. Codex's round-8
  regression reproduces **65 lost saves out of 96** before the fix, and four
  new atomic-publication tests pass after it. See [round 8](ZK60_ROUND8.md).
  Codex also independently reruns the formerly order-dependent test alone
  and all ten fixture-free CL9 checks against the corrected CPU library.
  The two expensive fixture cases are covered separately by the recorded
  lane evidence and Codex's current two-thread cold/warm proof gate.

## New follow-ups

**CL6 measurement validation:** `parse_measured_log` / `reconcile` accepts a
fixture with `prove_s=-1` followed by `exit 1`, and reports it byte-identical
across choices. Reuse CL5's validated-row gate or its equivalent: require
known successful exit, actual accepted verification, finite nonnegative
clocks and consistent shape/mode. Do not treat the digest alone as evidence
that a timed invocation succeeded. The existing archived sweep is not
invalidated by this malformed-input reproduction; no selector is promoted.

**CL11 preflight evidence:** all four following changes to the test's
otherwise-ready facts still yield `go=true` with no failed checks:

1. Remove the binary SHA-256 entirely.
2. Change it to an unrelated digest without changing the floor evidence.
3. Set both executed and expected floor cases to zero.
4. Request `--coverage full --claim target` using only the existing FFN
   export and flags, without any implemented full-proof/security evidence.

The floor probe only looks for a green substring, matching counts and a
successful marker newer than the binary. Bind a nonzero expected case set,
the full verified artifact digests, device, binary and source identity to
the qualification evidence; timestamps alone are insufficient. Keep target
eligibility false until actual supported coverage and security gates close.
The generated campaign still invokes the FFN `pass` path; a flag cannot
change its relation. The existing `scripts/hashline_benchmark.py` collector
already restricts its CLI to `ffn-only` coverage and always reports
`goal_met=false`; preserve that distinction in the preflight instead of
granting a broader result from flags. Validate the emitted commands against the selected
repository, shape and resource budget as well (the reused floors script has
a hardcoded checkout path, and the campaign contains fixed 32-layer stages).
No hardware launch is authorized by these synthetic ready-fact tests.

**CL7 integration:** the new fused hiding opening reuses the existing final
NTT/gather kernels with duplicate-index expansion and a retained reference
switch. Source and archived local A/B evidence support continued review;
require the full CPU/GPU/forced-chunk floor and oracle suite at the final
combined source, including the published H1 test-isolation fix `3ff8d5f`.
Phase-only gains remain separate from proof-ready performance.
One source-derived boundary also needs an explicit test: the new helper
accepts `Some(&[])`, but the fused/pruned path calls `qs.last().unwrap()`
with an empty list. Reject an empty query list before device allocations or
return an empty result. This has not been executed on a GPU by Codex.

## Correct the deadlocked floor launch

The observed outer wrapper was:

```text
flock /tmp/zk-heavy.lock flock /tmp/zk-build.lock results/cl1_floors.sh <scratch>
```

`cl1_floors.sh` immediately requests `/tmp/zk-build.lock` again for its CPU
build. Host lock/process inspection confirmed the child waited on its own
ancestor for more than five hours; no compiler or GPU work had started.
With explicit execution approval, Codex sent TERM only to that blocked
waiter, PID 29033. The script recorded `FAILURE: CPU build` and exit marker
**1**, and both locks were released. Its logs are preserved. This is a
launcher deadlock, not a failed proof or compiler result.

Relaunch with the outer **heavy lock only**; the floor script already owns
its per-build lock acquisition. Preserve detached logs and the exit marker.
Do not queue the same nested-lock wrapper again. Codex's queued CPU validation
started once the locks were released. GPU integration remains held on a
successful final-source gate, not on the earlier superseded findings.

The same outer wrapper was relaunched and deadlocked again. The second
waiting child, PID 123888, was stopped with execution approval; its script
also recorded exit 1 before compilation. The second log and marker are
archived under `/tmp/zk60-round8/deadlocks`. The launcher reused the original
log path, so the first attempt's recorded hash is historical; do not confuse
the overwritten lane log with its earlier contents. The corrected command is
now also at the top of [the task board](TASK_BOARD.md).
