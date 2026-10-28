# Independent review: guard fix (admission before the heavy lock, FIFO)

Reviewer: Claude (independent review lane), 2026-10-21T06:05Z. Read-only review.
Nothing was applied, no process was signalled, no git write was made. The only
command I ran was `test_guard_fix.py`, once, on private paths (see section 5).

## What was reviewed (hashes checked)

| File | sha256 | Check |
|---|---|---|
| `zk60_resource_guard.py.new` (candidate) | `f6d6660b7452efc8…aa842` | matches the brief and NOTES |
| live `scripts/zk60_resource_guard.py` | `f0b87668b9ad3bc4…e772` | equals `.orig`; this is the diff base |
| `zk60_resource_guard.diff` | `c91997c4…eb30` | **The brief's "f0b87668" is the base file's hash, not the diff's.** Applying the diff to the live file with `patch -o` gives exactly the candidate hash, and a fresh `diff -u` gives the same hunks. |

The diff has five hunks: the docstring, new constants, the admission/FIFO helpers,
the wait loop in `cmd_run`, and `cmd_check`. Everything from `# ---- launch ----`
onward is **byte-identical**: the systemd scope with `MemoryMax`, `Tracker`, the
watchdog, the straggler sweep, the VRAM drain, exit-code mapping, `terminal()`,
history, `status`/`snapshot`, `_live_jobs` and the job-file format are all
untouched.

## Verdict: APPLY WITH FIXES

I found **no code defect that could freeze the box or let jobs overlap**. Two
jobs cannot be admitted past the budget, two heavy jobs cannot overlap, the
locks cannot deadlock, and the heavy lock is released on every path. The fixes
are needed in the **swap procedure** (findings 3 and 4) and in **one policy
decision about how FIFO is rolled out** (finding 2). No code change is required
before applying. Findings 5–10 are optional low-severity follow-ups.

## Why the core is safe (what I checked)

1. **No admission past the budget.** The decision that admits a job and the
   write of its job file still happen in one critical section under
   `<state>/admit.lock` (`admit_once(final=True)`, `.new` lines 816–845). That is
   the same file, flock and registry format that old guards use. The lock-free
   pre-check only advises: it registers nothing and only decides whether to try
   for the locks. FIFO can only **add** reasons to refuse (`fifo-budget`,
   `fifo-heavy`, lines 504–545). It never removes one, so it cannot cause
   over-admission.
2. **One heavy job at a time.** A cpu/gpu/build job registers only on the second
   `admit_once` call. That call comes after the loop has taken every lock in
   `spec["locks"]`: it either appends all of them or returns a refusal. The
   verdict still refuses while another heavy job is registered. Old guards and
   `flock /tmp/zk-heavy.lock` wrappers take the same lock for real. The heavy
   lock is held, and inherited by the job, from before registration through the
   child run and the GPU drain, exactly as before.
3. **The locks are released on every path.**
   - A failed re-check calls `release_locks()`.
   - A `--wait-secs` timeout on either lock, `Stopped` (a signal) or an
     exception all end in the outer `finally`, which closes `lock_fds`.
   - Success, child failure, `--max-secs` and a signal while running use
     unchanged code.
   - If the guard is SIGKILLed between the pre-check and registration, the
     kernel drops the lock because no child holds it yet.
   - The ticket is removed in the inner `finally` and is never passed to the
     child.
4. **No lock-order deadlock.** The new code takes admit (released), then heavy,
   then build, then admit. Old code takes heavy, then build, then admit. Nothing
   waits on heavy or build while holding admit. Under admit the guard only reads
   meminfo, scans with non-blocking flocks, calls nvidia-smi (8 s timeout) and
   takes a blocking flock on a job file it just created.
5. **No wait-for cycle between waiters.** A waiter only counts tickets that sort
   strictly before its own name (zero-padded enqueue time plus run id, a total
   order). The oldest waiter therefore depends only on live jobs, memory and the
   GPU. A dead guard's ticket flock is dropped by the kernel, and the next reader
   deletes the ticket. A ticket is locked before it is renamed into `queue/`, so
   a live ticket can never look dead. No reader ever blocks on a ticket.
6. **Old and new guard processes can run together.** Old code globs only
   `jobs/*.json` and never reads `queue/`. Job files, `status --json`, history
   and `--result-json` keep their keys (the 9-scenario shape test confirms this).
   An old guard that holds the heavy lock while it waits for budget makes a new
   guard wait on the lock while holding nothing, so there is no deadlock. Once
   the old guards drain, FIFO applies fully.
7. **Signals while waiting.** The handler only sets a flag, and every wait
   checks it: the poll sleep, `_flock_wait` for admit, heavy and build. The
   result is exit 70 "terminated by signal N while waiting to start", as before.

## Findings

**1. [Info] The core safety properties hold (see above).** Every exit code
is unchanged: 0/rc, 70, 71, 75, 76, 127 and 137.

**2. [Medium, operational/policy] FIFO now also holds back `light` jobs, for up
to an hour.** A budget-blocked older job reserves its need and the heavy slot.
Every newer job that does not fit beside it waits, including default 0.5 GiB
`light` jobs, which the live guard never held back. The cap is
`FIFO_MAX_PRIORITY_SECS`, 3600 s per waiter; the caps of the waiters behind it
run at the same time, so the stall is about 1 h and does not add up per waiter.
This is the case right now: `fp-L_e8_LOWh8v6_lam100` is a live `light` job
declaring 5 GiB, running since 05:05Z. A default `cpu` job (11 GiB) queued now
would not fit (5 + 11 > 11.9). With FIFO on, every new guarded job, light or
heavy, would wait up to an hour. A default cpu job is also budget-blocked by any
two live default light jobs (0.5 + 0.5 + 11 > 11.9). Callers with a short
`--wait-secs` will now get exit 70 where they used to run: the techweek demo
uses 30 s for both its `light` verify steps and its `cpu` proof step. None of
this endangers the box, because FIFO can only delay jobs. It is still a visible
change for every lane. It matches the coordinator's hand rule from 2026-10-17,
but that rule was announced.
*Fix (choose one, deliberately):*
- **(a)** Swap with `/tmp/zk-guard/fifo.off` already present. That gives only
  the gap (a) fix. Remove the file after announcing FIFO to the lanes. Note
  that `/tmp` is cleared on reboot, so FIFO turns on again after a reboot.
- **(b)** Ship FIFO on, but announce it first and consider a 1800 s cap, which
  matches the lane rule "keep any single heavy job under ~30 minutes".

Either way, tell the demo owner about `fifo.off`.

Related, by design: once a waiter's cap expires it never reserves again. If it
is still waiting, small jobs can starve it again, as with the old guard.

**3. [Medium, process] The rewritten queued-signal path was not run with real
signals before the swap.** The copy suite skipped 5 cases. One of them,
`test_sigterm_while_queued_publishes_a_refusal`, is exactly the code path this
change rewrites (SIGTERM while blocked on the heavy lock). Two in-process tests
stand in for it by calling the handler directly. From reading the code I
expect all 5 to pass on the candidate: the handler only sets a flag, which every
wait checks, and the other four cases run through unchanged code. NOTES §7
runs them only **after** the live file is replaced, which is too late to be a
gate. *Fix:* before the swap, run those 5 cases against `.new` on private
paths. They signal only the test's own guard processes, never the live locks.
For example, use a scratch copy of `test_existing_suite_on_copy.py` with the 5
`@unittest.skip(NO_SIGNALS)` lines removed, run with
`GUARD_UNDER_TEST=<.new>`.

**4. [Medium, swap procedure] NOTES §7 has gaps.**
- **(a) Waiting guards are invisible to `status`.** Old waiters write no
  tickets, and `status` lists only registered jobs. `zk60_guarded_command.py`
  re-checks the pin **after** its build, and `zk60_techweek_demo.py` re-checks
  it after every command. A run that was only *waiting* at swap time therefore
  fails after it finishes ("resource guard changed during the build"). Before
  the swap, also confirm that no guard process exists at all (read-only:
  `pgrep -af 'zk60_resource_guard.py run'`, plus the Codex sandboxes' own
  process views), and that the lane HOLD files are in place.
- **(b) A third hash consumer is missing.**
  `scripts/zk60_private_stack_benchmark.py` records the guard's sha at its
  first command and raises "guard source changed between commands" or "...
  during this command". A benchmark in progress fails, even between steps. Add
  it to the "no harness mid-run" check. It needs no pin edit afterwards.
- **(c)** A guarded run is live now (`be14e00be7ba`, the light run above). The
  protocol forbids editing the guard during a live guarded run, so wait for it
  to end.
- **(d) There is only one rollback copy.** The live guard, its tests and the
  pinning scripts are **untracked in git** on `perf/zk-batch-optimizations`.
  The only copy of `f0b87668…` is `.orig`, in an untracked results directory.
  Before the swap, commit the current live guard (or keep a second hashed copy
  outside `results/`). Then commit the candidate separately, so rollback and
  audit come from git.
- **(e) Agree the pins with their owners first.** `REVIEWED_GUARD_SHA256` in
  `zk60_guarded_command.py` carries the note "accepted by both independent
  Codex reviews; announce/review changes in RECOVERY_COORDINATION.md before
  updating this pin". Get the owners' review and acknowledgement of this
  change **before** the swap, so the window in which their harnesses refuse to
  run is short and planned. Failing closed is safe but blocks those lanes.
  Never swap during a demo.
- **(f) Move the 25 new tests into `tests/`.** Put them in, for example,
  `tests/test_zk60_resource_guard_fifo.py`, pointing at `scripts/` plus a
  retained base copy for the mixed-version cases. Otherwise the official suite
  stays green even if FIFO or admission-before-lock regresses. Then update the
  test count in `ZK60_RESOURCE_PROTOCOL.md`. Also update the sentence "the guard
  already queues on the lock": it now queues on admission.

The rest of §7 is sound: the base-hash check, the copy + chmod 644 + `mv -f`
rename on the same filesystem, the hash check afterwards, the docs and the
rollback. The live file is already mode 644. Running guards keep their old code
in memory. The persistent `zk60_resource_watch.py` imports the guard module but
uses only unchanged functions, so it needs no restart.

**5. [Low] One refusal text changes, which NOTES does not mention.** Take a
heavy job whose `--wait-secs` expires while a *guarded* heavy job runs. It now
says "after waiting: another heavy guarded job is live (one heavy job at a
time)" instead of "could not take /tmp/zk-heavy.lock within Ns". The pre-check
sees the registered job before any lock wait. The exit code (70) is the same.
No parser of either text exists in `scripts/`, `ops/`, `apps/` or `tests/`. The
text is unchanged when the lock is held by a raw `flock` wrapper, which is the
case the shape test covers. *Fix:* correct NOTES §2 "refusal texts unchanged".

**6. [Low] Wall-clock time drives FIFO.** `time.time()` sets the heartbeat,
`priority_until`, `priority_secs` and the enqueue order. If the WSL clock steps
backward, reservations last longer by the size of the step. This applies to a
stopped waiter and to a "ready" waiter stuck on the heavy lock. A forward step
expires reservations early or charges them against the cap. Order stays a total
order, so this cannot cause a cycle or any safety problem. *Optional:* use
`CLOCK_BOOTTIME` for the heartbeat, grace and accounting, and compare only
tickets with the same `boot_id`.

**7. [Low] The reservation timer is charged for time when the ticket was not
reserving.** `publish` (line 665) adds all the time since the last update
whenever the previous state reserved. That includes time blocked on the heavy
lock after a "ready" verdict (the reservation lapsed after 5 s) and time with
FIFO switched off. A job that waited more than 1 h on a lock held by a legacy
wrapper loses its FIFO priority for good. This only weakens FIFO for that job,
back toward the old behaviour.

**8. [Low] gpu waiters now call nvidia-smi every 5 s.** They do so while
another heavy job runs and while holding `admit.lock` (8 s timeout each).
Before, they sat on the heavy lock and did not poll. Several queued gpu jobs
plus a slow nvidia-smi on WSL make `admit.lock` holds longer for everyone, but
the delay is bounded. *Optional:* evaluate the cheap reasons first (a live heavy
job, the budget) and skip nvidia-smi when the job is already blocked.

**9. [Low] Some ticket errors are not caught.** Inside `_queue_ahead`, only
parse errors are caught (line 603). An `OSError` from `os.read` (line 595), a
flock error other than `BlockingIOError`, or a `RecursionError` from hostile
JSON would end the guard with exit 71 before launch. No job would run and the
locks would be released, so this is safe. It does contradict "ticket trouble
never stops a job". *Optional:* catch `Exception` per ticket and treat it as
not reserving.

**10. [Low, pre-existing, not introduced by this change] Job-file
registration races with lock-free readers.** `_live_jobs` deletes any job file
it can lock. It is called without `admit.lock` by `status`, `check` and the
persistent watcher (every 10 s). Registration does `os.open(O_CREAT)` and only
then `flock(LOCK_EX)` (live lines 630–631, unchanged in `.new`). A reader that
runs in that microsecond window can delete a fresh job file. That job then runs
without counting against the budget; the heavy lock still prevents heavy
overlap. The candidate's own ticket code already uses the correct pattern:
create under a temporary name, lock, then rename. *Follow-up:* apply the same
pattern to job files. This is not a blocker for this change.

**11. [Info] FIFO risk 1 has no instance.** That risk is a running guarded job
that waits on a newer queued job. The guarded-command client, the demo, the
benchmark runner, proven-media and the `ops/` launch scripts all run leaf steps
one after another, and nested calls are refused.

**12. [Info] Heavy-vs-heavy order is still "first to poll".** A heavy waiter
blocked by a live heavy job does not reserve the next slot, so a stream of
heavy jobs from several lanes can delay a big one (NOTES risk 3). With FIFO off,
the big job also loses the protection it had by holding the lock, so smaller
heavy jobs can now overtake it as well. *Optional follow-up:* let the oldest
heavy waiter reserve the heavy **slot**, but not budget, while a heavy job is
live. Lights could still backfill.

## Test assessment

- **What the tests cover well:** isolation, asserted in `setUp` (private state,
  locks, history, meminfo and nvidia-smi). They show directly that the base
  version holds the lock while waiting and the candidate does not. A scripted
  in-process test shows the re-check runs under both locks and releases them on
  failure. They cover FIFO order, the off switch, dead, unlocked, stale and
  non-reserving tickets, and the reservation cap. Two stress runs check the
  budget and single-heavy invariants: 12 new-version jobs, and 14 mixed
  old/new jobs. The record-shape test covers 9 scenarios in both versions.
- **What they do not prove:** the stress tests are probabilistic, so passing is
  evidence, not proof. The no-overlap guarantee rests on the code structure
  above, which I checked by hand. No test covers real signal delivery in the
  new queued path (finding 3), and none covers a "ready" waiter stuck on the
  heavy lock for more than 5 s (newer jobs slipping in, finding 7). No test
  covers old-guard light jobs jumping FIFO, clock steps, or long waits.
- **The 5 skipped cases:** one is a real gap for this change (the queued
  SIGTERM case). The other four use unchanged code but should still run
  before the swap (finding 3).
- **Independent rerun:** I ran `test_guard_fix.py` once (06:03Z) on private
  paths: **25/25 OK, 84.5 s**. Afterwards `/tmp/zk-guard` had no `queue/`
  directory and only the pre-existing job, the temp directories were cleaned,
  and the live `history.jsonl` had no new record (the last one is from 05:21Z).
  Log: `/tmp/claude-1000/-home-victor-IntelligenceRegulation/c08c4558-9df4-474f-a0b5-1bf1cd034626/scratchpad/review_rerun.test_guard_fix.log`.
  I did not rerun the copy suite: its cgroup cases create real systemd scopes,
  and the lane's `final1` logs show it passing on both `.new` and `.orig`.

## Swap-time checklist (required)

1. Decide the FIFO rollout (finding 2): start with `/tmp/zk-guard/fifo.off`
   present, or ship FIFO on with an announcement and a chosen cap.
2. Before the swap, run the 5 skipped signal cases against `.new` on private
   paths (finding 3).
3. Get the pin owners' review and acknowledgement in `RECOVERY_COORDINATION.md`
   (finding 4e), and announce the FIFO behaviour and `fifo.off` to the lanes.
4. Commit the live `f0b87668…` guard, or keep a second hashed copy, as the
   rollback copy (finding 4d).
5. At the swap, confirm all of the following:
   - `status` shows no live guarded job (the current light run has ended);
   - no `zk60_resource_guard.py run` process exists, so nothing is waiting;
   - no benchmark-runner, guarded-command or demo run is in progress;
   - the lane HOLD files are in place;
   - the live hash is still `f0b87668…`.
6. Replace the file as NOTES §7 step 4 describes, check the hash
   `f6d6660b…aa842`, then run the official suite and `test_guard_fix.py`
   against the live file.
7. The owners bump the two static pins. Record the new hash in
   `RECOVERY_COORDINATION.md`. Move the new tests into `tests/` and update
   `ZK60_RESOURCE_PROTOCOL.md` and the two "known guard gap" paragraphs in
   `ops/zkp-mvp/LANE_RULES_20261017.md`.
8. Rollback: the same copy-and-rename with the retained base file, then restore
   both pins. Leftover tickets in `queue/` are harmless to the old code.
