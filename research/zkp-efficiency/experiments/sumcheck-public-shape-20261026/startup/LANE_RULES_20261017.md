# Lane rules for agents, 2026-10-17 evening session

Written by the coordinating Claude session at about 18:28 UTC on 2026-10-17
(agent briefs of that time say "18:40"; the clock read 18:36 when checked). The box
shut down cleanly at 14:59:58 UTC (all guarded jobs got SIGTERM: exit 143, or
70 while queued) and booted again at 18:21 UTC. `/tmp` was wiped by the reboot;
`/tmp/zk-heavy.lock` is recreated by the guard. Evidence under `results/`,
`ops/` and `~/zk60-artifacts/` survived. Every agent reads this file first.

## Hard rules

1. **Resource guard on every heavy leaf command** (anything over 1.5 GiB RAM, a
   minute of several cores, or the GPU):
   `python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run --class {light,build,cpu,gpu} --need-gib N --cap-gib M --label L --wait-secs S --max-secs S --log F --done F --result-json F -- <cmd>`.
   `build`/`cpu`/`gpu` share ONE heavy lock. Declare measured `--need-gib`
   (see `results/zk60_resource_guard/history.jsonl`), not the 11 GiB `cpu`
   default, so lanes can share the 11.9 GiB budget. Single-threaded Python
   that needs > 1.5 GiB may use `light` with a declared need. Run
   `python3 .../zk60_resource_guard.py status` before any timing run and label
   timings "shared box, n=1" when anything else is live. Never SIGKILL a guard.
   Full rules: `docs/zkmatrix-poc/ZK60_RESOURCE_PROTOCOL.md`.
2. **Detach anything over ~5 minutes**:
   `setsid nohup bash -c '<guard run ...>; echo $? > <stem>.done' >/dev/null 2>&1 &`.
   Wait for a run with a Bash `run_in_background` loop on its `.done` file
   (`until [ -f X.done ]; do sleep 20; done`), never a `pgrep -f`/`ps | grep`
   watcher (it matches its own command line and never ends), never a
   foreground wait. **Do not hand back while a job you launched is pending**:
   wait for its `.done`, integrate the result, then report.
3. **Laptop GPU**: keep VRAM <= 4 GiB, one GPU pass per guarded command, never
   chain GPU passes in one script (VRAM exhaustion freezes the whole WSL box).
4. **Exclusive write set**: write only inside your lane's directories named in
   your brief. Everything else is read-only, in particular other lanes'
   copies, `src/manifest.rs`, `codex-audit-*`, `scripts/logup_*_spike.py`, the
   frozen review copies `ops/zkp-mvp/trained-1b-review-r*/`.
5. **No git writes** (the coordinator snapshots). Read git with
   `git --no-pager ...` from the repo root only if you must.
6. **Command style**: absolute paths, never a `cd X &&` prefix, never a `PATH=`
   prefix (use `/usr/bin/env VAR=...` inside the guard command), bare `python3`,
   no `sed -i` (edit with the Edit/Write tools), one simple command per call
   where possible. `kill` is refused by the session classifier: plan so you
   never need it.
7. **Ledger**: keep your lane's `PROGRESS.md` current after every step, with
   UTC times read from `date -u` (never guessed), so a successor can resume
   from it alone. Evidence goes under `results/...`, never `/tmp`.
8. **Claims**: label numbers [MEASURED] (a run happened; shared box, n=1),
   [COUNTED] (exact arithmetic), [MODEL] (fitted/assumed). A "proves and
   verifies" claim needs a generic honest witness (dense weights, heads that
   differ) and a fresh-process verify from bytes. No privacy acceptance is
   claimed by any lane; only the security review process can do that, and
   rulings are Victor's (`docs/zkmatrix-poc/ZK60_DECISIONS.md`).
9. **Final report** to the coordinator: what landed (with evidence paths),
   numbers with labels, what failed, what is still running (should be
   nothing), and the next concrete step.

## Heavy-lock priority this evening

1. GPU zero-check lane (speed plan task 2, the go/no-go bandwidth number).
2. Native lane (R5 suite, task 1 acceptance, task 3 8B phase ladder).
3. Review lane r3 (production-CLI checks; small).
4. Privacy gate lane (controls arm, G-10).
5. Calibration lane (8B B6; `light` class at ~3.5-4 GiB declared).

Known guard gap (19:20 UTC): budget admission is not first-come-first-served,
so a job with a large declared need (the gate's 6 GiB pass) can starve while
smaller jobs keep fitting. Until the guard gets a fair queue, the coordinator
asks the light lanes to hold new launches until the starved job has started.
Second gap (20:30 UTC): a heavy job takes the heavy lock and only then waits
for budget admission, so while long light jobs hold the budget it blocks every
other heavy job, including smaller ones that would fit. Until fixed, light
lanes keep their declared needs and run lengths modest when a large heavy job
is queued.

Priority is a courtesy order for queuing, not a reason to wait idle: queue
your job through the guard and keep doing non-heavy work meanwhile. Keep any
single heavy job under ~30 minutes unless your brief says otherwise.

## Resume note (coordinator, 2026-10-17 ~23:10 UTC, usage limit reached)

All lane agents were stopped mid-work; detached guarded jobs may still finish
and write `.done` markers. A successor resumes each lane from its ledger:
- Native (`results/zk60_1b_native_20261017/PROGRESS.md`): was applying R5b =
  privacy review P-1/P-3/P-5/P-6/P-7 + review r4 r4_A/r4_B/N-r4-e in
  `ops/zkp-mvp/trained-1b/` (mid-edit of the array readers); then suite, freeze
  "R5b", announce. 8B T128 stack proved/verified (T128 profile unreviewed).
- Gate (`results/zk60_gate_tinyllama_20261017/PROGRESS.md`): tools v5 = P-2 pin
  enforcement + P-9..P-12 + draft §10/§11 edits (mid-edit); captures wait for R5b.
- Token I/O (`results/zk60_token_io_r1_20261017/PROGRESS.md`): fix the 6 census
  test failures, re-run suite green, then review fixes TR-1..TR-4, then R2.
- GPU (`results/zk60_gpu_zerocheck_20261017/REPORT.md`): next round K1–K4 on
  slot 18 (not started).
- Calibration (`results/zk60_8b_calibration_20261017/PROGRESS.md`): B6-2 runs
  done; B6_REPORT.md owed.
- Owed reviews: R5b re-check + 8B T64/T128 profiles; privacy acceptance path
  per `results/zk60_privacy_review_trained_t32_20261017/REVIEW.md`.

## Addendum 2026-10-19 20:25 UTC — declarations and holds (binding for new queues)

- Declare `--need-gib` from the job's MEASURED peak (guard history) plus a
  margin of ~25% or 0.5 GiB, not a round guess: an over-declared light job
  (6.5 GiB declared, ~2 GiB used) blocks an 8 GiB prove for its whole run.
- Every queue script checks a hold file before launching each job, e.g.
  `while [ -e "$LANE_DIR/HOLD" ]; do sleep 30; done`, so the coordinator can
  pause a lane by creating a file — no signals, no edits to a running script
  (both are refused). Lanes also honour a coordinator-named release marker.
- A running bash script reads its file lazily: never edit it in place.

## Addendum 2026-10-21 06:15 UTC — pre-check before every heavy launch (binding)

Until the guard fix (`results/zk60_guard_fix_20261021/`, reviewed "apply with
fixes") is swapped in, the guard still takes the heavy lock BEFORE budget
admission. Every cpu/build/gpu launch must therefore first poll
`python3 scripts/zk60_resource_guard.py check --class <c> --need-gib <n>` until
it prints "OK to start now" (as native `r8_stack.sh`'s `pre()` loop does), and
only then call `run`. A launch that waits inside `run` holding the lock blocks
every other heavy job on the box. Running scripts are not edited; new launches
follow this rule.
