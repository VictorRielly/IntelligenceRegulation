# Guard fix lane — PROGRESS

Lane: GUARD FIX (admission before the heavy lock; optional FIFO). Write set:
this directory only. The live `scripts/zk60_resource_guard.py` is never edited
here; the coordinator reviews and applies the `.new` copy.

Base (live guard at lane start, 2026-10-21T05:36Z):
`f0b87668b9ad3bc42683d95a16314b54973b8e36be576b25183302287168e772`
(snapshot: `zk60_resource_guard.py.orig`, byte-identical). Live tests file
`tests/test_zk60_resource_guard.py`: `8f854a2d2786d18b7c7596e57d2efca4b917bdd95f9c42bd91e6e4b3ff91c9dc`.

## Log (UTC from `date -u`)

- 2026-10-21T05:37Z — read CLAUDE.md, ZK60_RESOURCE_PROTOCOL.md,
  RECOVERY_COORDINATION.md (guard sections), LANE_RULES_20261017.md (+ both
  addenda), the live guard and its 45-case test file. Guard already honours
  env overrides for state dir, heavy/build locks, history, meminfo and
  nvidia-smi, so all tests run on private paths (no test-only hook needed).
  Live box at start: one live light job (5 GiB declared), 11.1 GiB available.
  Snapshot `.orig` taken. Next: write `.new`.
- 2026-10-21T05:45Z — `.new` written: admission first (no lock held), then
  heavy -> build locks, then re-check under them; a failed re-check releases
  the locks. FIFO tickets under `<state>/queue/` (flock-held, heartbeat,
  reservation only when budget-blocked, 3600 s reservation cap, `fifo.off`
  switch / `ZK60_GUARD_FIFO=0`). `check` reports FIFO reasons; `status`,
  job files, history/result records unchanged. `test_guard_fix.py` written;
  its 6 in-process tests pass. Full subprocess suite running in background
  (`test_logs/test_guard_fix.run1.log`, marker `.done`). Regression copy of
  the live 45-case suite prepared (`test_existing_suite_on_copy.py`, diff in
  `.diff`): 64 MiB allocations, 5 self-signalling cases skipped.
- 2026-10-21T06:00Z — run1: 21/25 pass; the 4 failures were test bugs
  (comparing against a still-running job's end time x2, a 12+0.5 = 12.5 GiB
  check that fits exactly, NaN != NaN), fixed in the tests. Ticket reason
  strings capped at 300 chars (cosmetic `.new` edit, made mid-run1, so run1
  is not final evidence). Final run `final1` launched via `run_tests.sh`
  (new suite, live suite on `.new`, live suite on `.orig` baseline).
  Found hash pins that fail closed: `scripts/zk60_guarded_command.py`,
  `scripts/zk60_techweek_demo.py` (owners update after replacement).
  NOTES.md drafted.
- 2026-10-21T05:53Z — DONE. final1 (05:48-05:52Z) on candidate
  `f6d6660b7452efc8d68d61b73b1fe9b55ceae1988128fcdcdbf51ace4afaa842`:
  test_guard_fix 25/25 OK; live suite copy on `.new` 40 OK + 5 skipped
  (signal cases); same copy on `.orig` 40 OK + 5 skipped. Diff written
  (`zk60_resource_guard.diff`); applying it to the live file reproduces
  the candidate hash. Live guard still `f0b87668...` (untouched); no test
  leakage into `/tmp/zk-guard` or the live history. Nothing running.
  Next (coordinator): review, then NOTES.md section 7 (announce, swap
  atomically, official suite incl. signal cases, update the 2 hash pins,
  docs).
- 2026-10-21T06:07Z — Coordinator relayed REVIEW.md ("apply with fixes", no
  code defect) with 4 items: (1) FIFO off by default, (2) run the 5 signal
  cases on private paths (permission: only processes our own test spawned),
  (3) swap-procedure items in NOTES §7, (4) stage the tests for `tests/`.
- 2026-10-21T06:12Z — (1) `.new`: FIFO now needs `<state>/fifo.on` or
  `ZK60_GUARD_FIFO=1`; `=0` keeps a process out; no tickets written when off.
  (4) staged `tests/test_zk60_guard_fix.py` (31 tests: +6 for the switch
  semantics and FIFO-off variants; repo-root discovery, old-version cases
  check `.orig` sha256 and skip if absent); `test_guard_fix.py` is now a shim
  running it against `.new`/`.orig`. (2) copy suite: signal cases opt-in via
  `RUN_SIGNAL_CASES=1`, raw `os.kill` wrapped in `own_kill` (cmdline must
  contain the test's private temp dir / unique sentinel arg).
- 2026-10-21T06:17Z — DONE (rev 2). final2 on candidate
  `87138bda80ae4499a668e67a1c0e7706bb859eafb5e766020bcd59567c8ac59c`:
  staged tests 31/31 OK; live suite copy on `.new` 45/45 OK incl. the 5
  signal cases; same on `.orig` 45/45. Diff regenerated (`c5a6177f…`), it
  reproduces the candidate from the live file. (3) NOTES §7 rewritten (pin
  owners first, third consumer `zk60_private_stack_benchmark.py`, backup
  outside /tmp, no `zk60_resource_guard.py run` process at swap, staged
  tests install) + finding 5 text correction + follow-ups §8. Live guard
  still `f0b87668…`; no leakage; nothing running. Swap NOT applied (waits for
  Victor).
