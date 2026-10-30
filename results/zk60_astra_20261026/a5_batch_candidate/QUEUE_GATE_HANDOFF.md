# R18-1 app integration candidate — shutdown checkpoint

Production remains r16b per-category. The app factory is unchanged; no native
batch proof was launched. The candidate is not yet submitted as a completed
app-half review packet: the existing app suite still needs a terminal pass.

`stage_app.py` assembles the actual Store, Worker, publishers and download route
under `integrated_app/proven_media`, with package-local batch helpers and the
original application dependencies. `integrated_app.patch` is the reviewable
installation delta; `integrated_app_sources.json` pins the base and candidate.
Nothing in this assembly changes the installed app.

The candidate now:

- Persists original input, plan, context and cleanup scope before atomically
  claiming every category in SQLite. The original D45 reservation survives
  failure; no category or partially completed batch is automatically retried.
- Runs one explicitly bounded, eight-thread r18 `prove-batch`, then separate
  r16b verify/input-owner checks for every job and whole-post category labels.
  Posts projected above 10 GB require an explicit D46 window reference.
- Routes known terminal outcomes through the collector before writing the
  terminal marker. A guard without matching cleanup evidence leaves the queue
  held. Only the owned guard is signaled and drained. A post-launch metadata
  failure preserves the whole claim for recovery.
- Runs startup recovery before publisher ticks or new work. Trusted cleanup
  scope is also retained in SQLite, so a missing cleanup file can be recovered.
  Reboot permits recovery; a missing same-boot PID is insufficient. Known
  nonzero terminal status remains a failure after reboot.
- Commits every verified category record together. Publication can resume
  without proving again after a storage error or a crash between publication
  and the final database transition. Shared proof time is counted once.
- Refuses lexical and resolved quarantine paths at local/testnet publication,
  CAS ingestion and bundle download. Rechecks use the batch's original shared
  content and private owner directory.

Evidence from `app-half-1/`: 71 lifecycle/publication controls and 17 integrated
queue controls pass. Lifecycle tests use tiny actual subprocesses with a
simulated guard. Queue tests exercise the real staged store/worker/adapter/
collector/publisher/manifest, but mock native execution and acceptance. The
transport fixture preserves retained r18 native events except destination
paths and the explicitly removed entropy-harness trailer. These results are
not a new native proof or an end-to-end native batch measurement.

The first integrated test attempt exposed missing chunk/authority fields in
the simulated checked-record fixture (5 failures); the fixture now includes
the public 17-token native statement authorities and keeps real category
coverage validation. No production verifier check was weakened. The final
17-test run passes. The former handoff is retained in
`QUEUE_GATE_HANDOFF.before-integration.md`.

Coordinator shutdown HOLD was posted at 2026-10-30T22:12:34Z and observed at
22:14:34Z. The bounded light suite had started at 22:14:11Z before that note was
read; no HOLD file existed at the three app/prep/export paths. No further job
is to launch during this hold. Terminal status and exact resume instructions
are in `shutdown-checkpoint.json` and the parent continuation ledger.

After restart and explicit release of the hold, inspect the new boot ID,
shared guard status/history and retained `.done`/guard records first. Complete
the existing app suite on the host if the sandbox run timed out, then review
and pin the final delta and announce it in the Astra log for coordinator
app-half review. Do not select this adapter or repin production before go.
Single-copy receipt storage and the staged admission correction remain separate
follow-ups. Benchmark resume is still L07 attempt2, 3209/4872 items retained.
