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
