# R18-1 queue gate candidate

`batch_queue_gate.py` adds one recovery/terminal entry point around the existing collector. The queue supplies its original reservation, canonical private job directory, receipt root, and confirmed terminal state. Unknown/live state blocks without moving outputs. Missing terminal files, malformed requests, guard kills, or absence of `batch-proved` quarantine the original trusted scope. A completed quarantine cannot be resurrected by later success-looking logs. Even successful transport remains unverified and never allows retry or publication.

41 Python controls pass in `queue-gate-tests-2.log`, with watchdog-only light enforcement, sampled RSS0.18GiB, measured n=1 shared box. Eleven new controls include unchanged r18 native events (only fixture destinations remapped); the deterministic entropy harness trailer is explicitly excluded from native stdout and is a rejection control when present. The first fixture mistakenly paired17-token native output with a35-token reservation and correctly failed; original failed evidence retained.

This is STAGED. No app binary repin, runtime batch selection, new native proof, or claim that R18-1 is closed. `reject_quarantined_source` rejects lexical and symlink-resolved quarantine paths, but production publishers/downloads are not wired to it yet.

Required wiring before coordinator review:

1. Keep `cleanup-scope.json` before any native launch and register the one batch directory in the post's original queue reservation. Persist supervisor/guard process identity. A same-boot missing supervisor alone does not prove its child terminated; unknown state must block, while reboot makes the old child terminal.
2. At queue startup and before retry/anchor activity, inspect known batch scopes. Route confirmed terminal batches through `recover_batch`; preserve live/unknown jobs. Record post-level failure after quarantine without removing the D45 reservation. Never resubmit a partially proved batch.
3. Make the only batch pipeline terminal path call this collector. Route its unverified per-job logs through the existing fresh native verify/input-owner/whole-post label checks, matching the original token count and category plan.
4. Reject quarantine paths at both publication inventory ingestion and CAS `put_file`, and before download archive construction. Add integration tests proving no CAS object, pending leaf, RPC call or streamed byte can result from a quarantined source (including symlink aliases).
5. Run the production app suite at quiescence, prepare reviewed source diff/pins, report to the coordinator for the app-half review. Stay r16b per-category until go; r18/r19/r19b pins remain untouched.

## Publication exclusion follow-up

`publication_exclusion.patch` now stages all three boundaries in copies of the actual app sources: local/testnet publish before any inventory reads, CAS put_file before writing a temporary object, and bundle download before constructing a stream (including each segment/statement and again before opening). Six focused tests exercise the copied implementations: ordinary publication still works; direct and symlink quarantine sources create no object, pending leaf or RPC call; quarantined archive roots/segment/statement aliases are refused before a response stream is made. This source patch is still unapplied while the new public demo holds its source pins. Production queue wiring, subprocess-liveness integration and the combined app-half review remain outstanding.

## Queue startup follow-up, 2026-10-30

`queue_startup.patch` now stages a recovery hook in copies of the real `Store`
and `Worker.tick`. `batch_registry.py` atomically claims all original category
jobs in SQLite before a future batch launch. The worker invokes recovery before
its publisher tick, ordinary polling or any new launch. A reboot establishes
termination; a same-boot missing PID or absent terminal record holds the queue.
Same-boot completion requires the original launch/boot identity and an explicit
children-reaped terminal record. A failed supervisor quarantines even when native
stdout looks successful. All failed category jobs retain the D45 reservation and
cannot be automatically retried.

The combined 58 lightweight tests pass (`queue-startup-tests.log`, exact pins in
`queue-startup-evidence.json`), including 11 new tests against the staged real
SQLite store and queue worker. No native proof was launched. The staged hook
deliberately holds successful transport at `unverified`: it cannot publish or
claim fresh verification.

Still required: a batch supervisor that owns/reaps every guarded child and writes
the terminal contract; launch integration through this atomic registration;
fresh verify/input-owner/category-label collection into every queue record;
package-local imports when promoted; combined application tests and coordinator
review. These candidates are not installed and do not close R18-1. The running
demo remains pinned to the unchanged r16b per-category sources.

`batch_supervisor.py` additionally stages the guarded-child lifecycle. It holds
an exclusive supervisor lock, forwards termination only to its own guard and
waits for cleanup, and writes a children-reaped terminal record only when the
guard's matching boot/PID/completion evidence is present and cleanup is not
uncertain. A missing result, foreign PID, or failed straggler sweep keeps the
queue blocked. Nine tiny subprocess controls pass, including real SIGTERM
forwarding and competing-supervisor exclusion. The combined suite is now 67
tests (`lifecycle-evidence.json`). These use a simulated guard and launch no
native proof; they do not replace guarded native integration. The lifecycle
module still needs to be connected to the batch command plan and collector,
and cannot currently be selected by the app factory.
