# Guard fix: admission before the heavy lock, optional FIFO for the budget

Lane: GUARD FIX, 2026-10-21 UTC. This is a candidate only: **the live guard
was not touched.** Independent review: `REVIEW.md`, verdict "apply with fixes"
(no code defect found). Revision 2 (this one) answers the coordinator's four
items from that review:

1. FIFO is **off by default**.
2. The 5 signal cases have been run on private paths.
3. The swap-procedure items are in §7.
4. The new tests are staged for `tests/`.

**The swap waits for Victor**, because Codex-owned harnesses pin the guard's
hash.

| File | What it is |
|---|---|
| `zk60_resource_guard.py.new` | the candidate guard (hash in §6) |
| `zk60_resource_guard.py.orig` | byte-identical copy of the live guard (diff base, rollback copy, old version for the mixed tests) |
| `zk60_resource_guard.diff` | `diff -u scripts/zk60_resource_guard.py zk60_resource_guard.py.new` |
| `tests/test_zk60_guard_fix.py` | **staged** new tests (31), to be copied into `tests/` at swap time |
| `test_guard_fix.py` | lane shim: runs the staged tests against `.new` / `.orig` before the swap |
| `test_existing_suite_on_copy.py` (+ `.diff`) | the live 45-case suite pointed at a copy; signal cases opt-in (`RUN_SIGNAL_CASES=1`) |
| `run_tests.sh`, `test_logs/` | runner and logs (current evidence: `final2.*`; earlier: `final1.*`, `run1`) |
| `REVIEW.md` | independent review (read-only reviewer) |
| `PROGRESS.md` | lane ledger |

Base: the live `scripts/zk60_resource_guard.py` at lane start (2026-10-21T05:36Z),
`f0b87668b9ad3bc42683d95a16314b54973b8e36be576b25183302287168e772`.

## 1. The two gaps, in plain words

**(a) Waiting while holding the lock.** The live guard takes `/tmp/zk-heavy.lock`
first and only then waits for memory admission. While light jobs hold the
budget, a waiting cpu/gpu/build job sits on the heavy lock, so every other heavy
job is blocked, even a small one that would fit. Shown on the base code by
`test_base_version_holds_the_heavy_lock_while_waiting`.

**(b) No queue order.** Every waiter re-tries admission every 5 s on its own. A
job with a large declared need waits for a moment when its whole need is free,
while small jobs fit into every gap and keep that moment from coming.

## 2. What changed

**(a), the core fix: always on.** `run` now does, in a loop:

1. Decide admission (same rules) **holding no lock**. A `light` job (no locks)
   registers right here, as before.
2. If the verdict is "go", take the locks in the usual order (heavy, then build
   for `build`), with the same `--wait-secs` deadline.
3. Decide admission **again under the locks**, and register the job in the same
   critical section if it passes. If it fails (someone took the budget in
   between), **release the locks** and go back to step 1 after the usual poll.

The final decision and the job-file registration are still one critical
section under `<state>/admit.lock`, exactly as before.

Everything after admission is byte-identical: launch, systemd scope /
`MemoryMax`, watchdog, VRAM cap, GPU drain (the heavy lock is held until VRAM is
idle), straggler kill, terminal record, history, `--done`, `--result-json`.

CLI: `run`/`status`/`check` and their flags are unchanged. Exit codes are
unchanged.

Refusal texts are unchanged, with one exception (review finding 5). A heavy job
whose `--wait-secs` runs out while a **guarded** heavy job runs now says "after
waiting: another heavy guarded job is live (one heavy job at a time)" instead
of "could not take /tmp/zk-heavy.lock within Ns". The exit code is still 70,
and nothing parses either text. When the lock is held by a raw `flock` wrapper
the text is still "could not take ...".

**(b), FIFO for the declared budget: OFF by default.** With FIFO off, the swap
changes only (a), and no ticket files are written. To switch it on:

| Switch | Effect |
|---|---|
| `touch /tmp/zk-guard/fifo.on` | FIFO on for every new-version guard, at its next poll; no edit, no restart. `rm` turns it off again at the next poll (waiters drop their tickets). `/tmp` is wiped on reboot, so FIFO turns **off** after a reboot. |
| `ZK60_GUARD_FIFO=1` | FIFO on for that one guard process (it reserves and honours reservations) |
| `ZK60_GUARD_FIFO=0` | that process stays out even when `fifo.on` exists |
| `ZK60_GUARD_FIFO_MAX_PRIORITY_SECS` (3600) | reservation time cap per waiter; the review suggests 1800 to match "heavy jobs under ~30 min" |
| `ZK60_GUARD_TICKET_STALE_SECS` (60) | heartbeat age after which a ticket is ignored |
| `ZK60_GUARD_POLL_SECS` (5) | admission re-check interval (tests use 0.5) |

When FIFO is on, every waiting guard keeps a ticket
`<state>/queue/<enqueue_ns>-<run_id>.ticket` (JSON, held under `flock` while it
waits). When a newer job is admitted, an older waiter that holds a
**reservation** counts as if it were already running: its need is added to the
committed budget, and a heavy waiter takes the one heavy slot. A waiter holds a
reservation only when:

- it is blocked by the **declared budget** (its own, or the reservations ahead
  of it), possibly together with low MemAvailable or swap. Live MemAvailable
  alone never reserves, nor does a busy GPU or a live heavy job;
- or its own verdict just said "go" and it is taking the heavy lock (5 s grace);
- its heartbeat is fresh (rewritten every poll, ignored after 60 s);
- it has reserved for less than 3600 s in total.

Waiters are ordered by enqueue time, so a waiter only ever waits for **older**
waiters, and there can be no cycle. While an older job is budget-blocked, no
newer job that does not fit beside it starts. This holds back `light` jobs too,
for up to the cap (review finding 2). That is why FIFO ships off.

`check` includes FIFO reasons when FIFO is on. `status` is unchanged and does
not list the queue.

## 3. Why it is safe

The review's hand check of these properties is in `REVIEW.md`, "Why the core is
safe".

- **No double admission.** The decision that admits a job and its job-file write
  happen together under `admit.lock`, the same file and `flock` as the live
  guard. The pre-check is advisory only. FIFO can only add reasons to refuse.
- **One heavy job at a time.** A cpu/gpu/build job registers only while it holds
  the heavy lock, and the verdict still refuses while another heavy job is
  registered. Old `flock /tmp/zk-heavy.lock cmd` wrappers still exclude guarded
  heavy jobs.
- **No new lock deadlock.** Lock order is heavy -> build -> admit everywhere. No
  one waits on heavy or build while holding admit, and admit is held for one
  decision only.
- **Locks are released on every path**: failed re-check, `--wait-secs` timeout,
  signal, exception, and SIGKILL before registration (the kernel drops them).
- **Waiting holds nothing** but the waiter's own ticket flock (FIFO on only),
  which no one ever waits on.
- **Dead waiters** (FIFO on). The kernel drops a dead guard's ticket flock, and
  the next reader deletes the ticket. A ticket is locked before it is renamed
  into place, so a live ticket never looks dead. PIDs are recorded as evidence
  only; they are not used for liveness, because PIDs are not comparable across
  pid namespaces.

FIFO risks (they apply only once FIFO is switched on):

1. A guarded job that waits on a newer queued job could stall until the
   reservation cap. The review found no instance (finding 11): nested calls are
   refused and every harness runs its steps one after another.
2. A big budget-blocked job holds back every newer job that does not fit beside
   it, light jobs included, for up to the cap. Callers with a short `--wait-secs`
   (the techweek demo uses 30 s) would get exit 70 where they used to run.
3. Ordering at a transition is best-effort: a ticket can be up to one poll out
   of date. Heavy-against-heavy order is first-to-poll (findings 3 and 12).

## 4. Old and new guard processes together

Running guards keep the old code in memory after the file is replaced. Every
state file both versions use keeps its format:

| State | Change | Evidence |
|---|---|---|
| `/tmp/zk-heavy.lock`, `/tmp/zk-build.lock` | none: same files, same flock, same order | mixed stress tests (FIFO off and on) |
| `<state>/admit.lock` | none | same |
| `<state>/jobs/<run_id>.json` (live registry) | none: same keys, same lock-for-life rule | `test_job_files_and_status_are_read_across_versions` |
| `history.jsonl`, `--result-json`, `--done` | none: same keys in 9 scenarios | `test_history_and_result_json_have_the_same_shape_in_both_versions` |
| `status --json` | none | `test_old_status_and_check_ignore_the_queue` |
| `<state>/queue/`, `<state>/fifo.on` | **new**, used only when FIFO is on; the old code never reads them | same test |

- **An old guard waiting with the lock, plus a new heavy guard.** The new guard
  waits on the lock, holding nothing, until the old one has run. There is no
  deadlock and no overlap. **Gap (a) is fully gone only once the old guards that
  were waiting at swap time have ended**, which is why §7 requires that no guard
  process exists at swap time.
- **Budget accounting is shared.** Both versions decide and register under the
  same `admit.lock`, against the same registry: 14 mixed jobs (7 per version)
  never overran the budget and never ran two heavy jobs at once, with FIFO off
  and with FIFO on.
- **With FIFO on, old guards ignore tickets** and can jump the queue, as today.

## 5. New behaviour, as tested

FIFO off (the swap configuration):

- A waiting big job leaves the heavy lock free (10 probes in 2 s), and no queue
  directory is written. The base version holds the lock in the same scenario.
- A 3 GiB build runs and finishes while an 8 GiB cpu job waits for the budget.
- The default is checked directly: a newer 5 GiB job still jumps an older 8 GiB
  one, as with the live guard.

In-process tests with scripted verdicts:

- The re-check runs under both locks, and a failed re-check releases them before
  the next pre-check.
- A termination while waiting for memory, or while blocked on the heavy lock,
  ends with exit 70 "terminated by signal", the ticket gone and the lock free.
- `--wait-secs` still bounds both waits.
- FIFO off writes no ticket, and `ZK60_GUARD_FIFO=0` beats the file.

Real signals (the live suite's 5 cases, run on `.new` on private paths):

- SIGTERM to a guard queued on the heavy lock (the rewritten path) gives exit 70
  with a refusal record.
- SIGTERM to a running guard whose child ignores SIGTERM kills the job and
  releases the lock.
- SIGKILL of the guard leaves the locks held by the job until the job dies, in
  both modes.
- A guard started inside a scope leaves that scope alone.

FIFO on:

- `ZK60_GUARD_FIFO=1` turns it on for those processes.
- An older budget-blocked 8 GiB job starts before a newer 5 GiB one, and a newer
  0.5 GiB job waits for the blocker to end.
- Removing `fifo.on` lets the held job start within one poll, and the waiters
  drop their tickets.
- A ticket whose holder dies stops blocking at once and is deleted. Unlocked
  tickets are deleted. Stale-heartbeat and non-reserving tickets are ignored.
- The reservation cap releases newer jobs.
- Waiters blocked only on live MemAvailable or on a busy GPU do not reserve.

Stress, with FIFO off and with FIFO on:

- 12 new-version jobs (8 light of 4 GiB, 3 build of 3 GiB, 1 cpu of 6 GiB) never
  went above the 12.5 GiB test budget and never ran two heavy jobs at once.

## 6. Test results

The current evidence is run `final2`, 2026-10-21T06:12:37Z to 06:17:01Z, made
with `run_tests.sh`. The file hashes are in `test_logs/final2.hashes.txt`:

| File | sha256 |
|---|---|
| candidate `zk60_resource_guard.py.new` | **`87138bda80ae4499a668e67a1c0e7706bb859eafb5e766020bcd59567c8ac59c`** |
| base `.orig` (= live) | `f0b87668b9ad3bc42683d95a16314b54973b8e36be576b25183302287168e772` |
| staged `tests/test_zk60_guard_fix.py` | `7814c8f43f8ab5fc337fbe1ffa1c1740f8eb812ca58e93bd90a59747cff512c9` |
| `zk60_resource_guard.diff` | `c5a6177f63c6cd4e0ebb38861002b9103155490d4bc406de39a437c7433949f7` |

Applying the diff to the live file reproduces the candidate hash exactly. This
was checked with `patch -o` into a scratch file; the live file was not touched.

| Suite | Target | Result | Log |
|---|---|---|---|
| staged `test_zk60_guard_fix.py`, 31 tests (via `test_guard_fix.py`) | `.new`, with `.orig` for the old/new cases | **OK**, 0 skipped, 120.0 s | `final2.test_guard_fix.log` |
| live 45-case suite (copy), signal cases on | `.new` | **OK**, all 45, 71.7 s | `final2.existing_on_new.log` |
| live 45-case suite (copy), signal cases on | `.orig` (baseline) | **OK**, all 45, 72.3 s | `final2.existing_on_orig.log` |

- **The 5 signal cases pass on `.new`.** They include
  `test_sigterm_while_queued_publishes_a_refusal`, the path this change
  rewrites (review finding 3).
  - They ran on private paths.
  - Every raw `os.kill` in the copy goes through `own_kill`, which signals a
    pid only if its command line contains the test's private temp directory
    (or the sentinel's unique `sleep 300.<tag>` argument).
  - `Popen.send_signal` reaches only the test's own unreaped children.
  - No other process was signalled.
  - The `ResourceWarning` lines in those cases come from the live suite's own
    unclosed pipes. They appear on `.orig` too.
- **Both cgroup cases ran with real systemd scopes**, on `.new` and `.orig`.
- **Record shapes:** in 9 scenarios both versions give the same exit codes
  (0, 0, 0, 70, 70, 70, 127, 75, 3) and the same key sets for history and
  `--result-json`; job-file keys are identical too.

Isolation after `final2`:
- `/tmp/zk-guard` has no `queue/` and no `fifo.on`.
- Its two job files belong to other lanes' live jobs (an `fp_eval` run and a
  `cargo test`), not to these tests.
- The live `history.jsonl` gained one record since 05:30Z: the pre-existing
  light job `fp-L_e8_LOWh8v6_lam100` ending normally at 06:16:23Z.
- No test process or scope was left behind.

Earlier runs, kept for the record:
- `final1` (05:48Z): the first candidate `f6d6660b…`, with FIFO on by default.
  25/25 passed, and the copy suite gave 40 OK + 5 skipped on both versions.
- `run1`: 21/25. The four failures were test bugs, since fixed.

The independent review reran `final1`'s tests (25/25) at 06:03Z (`REVIEW.md`).

## 7. Swap procedure (for the coordinator; the swap waits for Victor)

**Before the swap day**

1. **Agree the pins with their owners first.** Two scripts pin the guard hash
   statically and fail closed until they are updated:
   - `scripts/zk60_guarded_command.py` (`REVIEWED_GUARD_SHA256`, owned by Codex;
     its note says "announce/review changes in RECOVERY_COORDINATION.md before
     updating this pin");
   - `scripts/zk60_techweek_demo.py` (`GUARD_PIN`).

   Get the owners' review and acknowledgement in
   `ops/zkp-mvp/RECOVERY_COORDINATION.md` **before** the swap, so the window in
   which their harnesses refuse to run is short and planned. Never swap during
   a demo.
2. **Know the third hash consumer.** `scripts/zk60_private_stack_benchmark.py`
   records the guard hash at its first command and raises "guard source changed
   between commands" or "... during this command". A benchmark in progress
   fails, even between steps. It has no static pin to edit.
3. **Back up the base copy outside `/tmp`** and outside this one results
   directory. The live guard, its tests and the pinning scripts are untracked in
   git, so `.orig` is today the only copy of `f0b87668…`. Either commit the live
   guard as it is now (coordinator snapshot), or keep a second hashed copy, for
   example `~/zk60-artifacts/guard-backup/zk60_resource_guard.py.f0b87668`, and
   verify it with `sha256sum`. Commit the candidate separately afterwards, so
   that rollback and audit come from git.
4. Announce the change and the FIFO switch (`/tmp/zk-guard/fifo.on`, off by
   default) to the lanes in `RECOVERY_COORDINATION.md`.

**At the swap (all checks are read-only)**

5. `python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py status`:
   no live guarded job. The protocol forbids editing the guard during a live
   guarded run. At 06:17Z two other lanes' jobs were live (`fp_eval`
   tinyllama and a hashline `cargo test`).
6. **No guard process exists at all**, not even a waiting one: `status` lists
   only registered jobs, and old waiters write no tickets.
   `pgrep -af 'zk60_resource_guard.py run'` must print nothing. Also ask the
   Codex sessions to check their own sandbox process views, which this
   namespace may not see. Lane HOLD files must be in place, so that no queue
   script launches during the swap.
7. No benchmark-runner, guarded-command or demo run is in progress (items 1–2).
8. The live file is still the diff base:
   `sha256sum /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py`
   prints `f0b87668b9ad3bc42683d95a16314b54973b8e36be576b25183302287168e772`.
   If not, stop: the diff no longer applies.
9. Replace the file atomically. All files are on the same filesystem, so `mv`
   is a rename. Running guards keep their in-memory code.
   ```
   cp /home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/zk60_resource_guard.py.new /home/victor/IntelligenceRegulation/scripts/.zk60_resource_guard.py.tmp
   chmod 644 /home/victor/IntelligenceRegulation/scripts/.zk60_resource_guard.py.tmp
   mv -f /home/victor/IntelligenceRegulation/scripts/.zk60_resource_guard.py.tmp /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
   sha256sum /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
   ```
   The hash must equal the candidate hash in §6:
   `87138bda80ae4499a668e67a1c0e7706bb859eafb5e766020bcd59567c8ac59c`.
10. Install the staged tests and run both suites against the live file:
    ```
    cp /home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/tests/test_zk60_guard_fix.py /home/victor/IntelligenceRegulation/tests/test_zk60_guard_fix.py
    python3 -m unittest discover -s /home/victor/IntelligenceRegulation/tests -p test_zk60_resource_guard.py
    python3 -m unittest discover -s /home/victor/IntelligenceRegulation/tests -p test_zk60_guard_fix.py
    ```
    From `tests/`, the staged file tests `scripts/zk60_resource_guard.py`. Its
    old/new cases use the retained
    `results/zk60_guard_fix_20261021/zk60_resource_guard.py.orig`; they check
    its sha256 and skip if it is missing. Point `GUARD_FIX_OLD` at the backup
    from item 3 if `results/` ever moves.

**After the swap**

11. The owners bump the two static pins to the candidate hash. Record the new
    hash in `RECOVERY_COORDINATION.md`.
12. Docs:
    - `docs/zkmatrix-poc/ZK60_RESOURCE_PROTOCOL.md`: admission before the lock;
      the sentence "the guard already queues on the lock" becomes "queues on
      admission"; the FIFO switch; the test counts (45 + 31).
    - The two "known guard gap" paragraphs in
      `ops/zkp-mvp/LANE_RULES_20261017.md`: gap (a) fixed; gap (b) fixed but
      off until `fifo.on`.
13. Turning FIFO on later is a separate, announced decision:
    `touch /tmp/zk-guard/fifo.on`, re-created after every reboot if wanted. Tell
    the demo owner first, because of its 30 s waits.
14. Rollback: the same `cp` / `chmod` / `mv` with `.orig` (or the item 3
    backup), then restore both pins and remove the staged test from `tests/`.
    A leftover `/tmp/zk-guard/queue/` or `fifo.on` is ignored by the old code.

## 8. Limits and follow-ups (from the review, all optional, none blocking)

- `status` does not show the queue. With FIFO on:
  `cat /tmp/zk-guard/queue/*.ticket`.
- Finding 6: FIFO timing uses wall-clock time; a clock step stretches or
  shortens reservations. This affects FIFO only, never safety.
- Finding 7: the reservation timer is also charged for time spent stuck on the
  heavy lock after a "ready" verdict. This only weakens FIFO for that job.
- Finding 8: queued gpu jobs now run nvidia-smi on every poll (8 s timeout each)
  while holding `admit.lock`. Possible fix: skip it when the job is already
  blocked by a cheaper reason.
- Finding 9: an `OSError` while reading another waiter's ticket ends the guard
  with exit 71 before launch. Only possible with FIFO on (with FIFO off, the
  queue is never read). Possible fix: catch `Exception` per ticket.
- Finding 10 (pre-existing, not introduced here): job-file registration does
  `open` then `flock`, so a lock-free reader (`status`, `check`, the watcher)
  could delete a fresh job file in that window. Possible fix: use the ticket
  pattern (temporary name, lock, rename) for job files.
- Finding 12: with FIFO off, a big heavy job no longer keeps smaller heavy jobs
  out by holding the lock. That is gap (a)'s fix, but it also means smaller
  heavy jobs can overtake it. Possible follow-up: let the oldest heavy waiter
  reserve the heavy slot, but not budget.
- If the candidate file is run from outside `scripts/`, its default history
  path moves (it is derived from the file's location). The tests always set
  `ZK60_GUARD_HISTORY`.
