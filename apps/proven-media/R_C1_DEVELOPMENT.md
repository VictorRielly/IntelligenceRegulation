# R-C1 classifier adapter

`proven_media.classifier_prover.RungClassifierProver` implements the app's
`ClassifierProver` interface for the frozen **synthetic** R-C1 fixture. It
accepts `RungTokenItem`, not text or images. It is not exposed as a web-app
prover mode and its single `synthetic` category cannot be published as media
labels. The current `ShieldstralProver` remains unavailable until A2 and the
reviewed native R12/S2 classifier release arrive.

The worker executes one fresh CLI process per stage through the resource
guard: `prove`, `verify`, `input-owner`. It observes the app, prep and export
HOLD files before admission and after the resource precheck. It pins the
binary on every stage. A separate `label` job re-verifies every chunk before
returning their OR. Missing chunks, refusals, altered segments and mismatched
owner input do not produce accepted labels. Private content IDs appear only
in an owned 0600 file; owner openings stay outside Git and the public run's
parent directory.

Native R-C1 publishes only `statement/statement.json` plus numbered segments.
The app retains its segment hashes in the proof record. It must not create a
`segments.json` inside that native statement directory: native re-verification
rejects extra files.

For a retained fixture, construct the deployment with the frozen binary
`results/zk60_token_io_r1_20261017/cli/zk60_classify.r12.release.bin`, its SHA-256
`04036e269a5c0984c70dd2b391dc9e045156d87dfd9c41ccccad4088a204bb76`,
the fixture's prover export and a separate public export without `seq_*`, its
classifier tables and trained statement identity. Set
`policy="rung-tc-synthetic-policy-dev/1"`, `chunk_size=23`, `overlap=4`,
`min_bits=93`, `development=True`. This exact binary/policy pair is the only
93-bit exception. Production deployments require at least 95 bits and cannot
use this binary.

Pass the whole fixture's IDs and one private activation sequence directory
per registered chunk to `RungTokenItem`. `start` launches a detached worker;
`prepare` writes the same job without launching it, allowing the sandbox
runner to execute a bounded foreground worker:

```
apps/proven-media/.venv/bin/python apps/proven-media/tools/classifier_pipeline.py /tmp/private-rung/job
```

Do not put an outer resource guard around this worker: each native leaf is
already guarded. `pipeline.done` and per-step `.guard.json` files provide
terminal evidence. `collect` requires successful fresh verifier and owner
checks and compares the artifact to the inventory retained by the worker.
`start_recheck` / `collect_recheck` repeat those checks. For an item with
several chunks, call `start_label` / `collect_label` after collecting every
chunk; the native aggregate accepts runs in any order.

Validation: the 72-test app suite passes on the host (2026-10-28, 2.598 s,
n=1 shared host). The retained native fixture run completed on October 26:
both verdict bits, fresh verifier/owner checks, and the mixed two-chunk OR
all passed. Four public receipts were reverified in fresh guarded processes
on October 28; hashes and commands are in
`results/zk60_astra_20261026/classifier_reverify_20261028_retry1/complete.json`.
The original private owner artifacts were under `/tmp`, so the October 28
audit repeats public verification only. This is synthetic development
evidence, with no trained Shieldstral classifier or privacy acceptance.

The retained integration inputs and runner are now prepared under
`results/zk60_astra_20261026/`. The runner uses `prepare`, `prepare_recheck`
and `prepare_label` to execute foreground jobs through the same guarded worker.
Its cases cover both one-chunk verdicts and a two-chunk item with ranges
`[0,23)` and `[4,27)`, expected verdict bits `[1,0]`, and reversed run order
for aggregation. The independent Python integer kernel matches the retained
native sequence bit for bit. The mixed margin is deliberately constructed
test data and is never a trained classifier.

`run_classifier_integration.py` requires a completed bootstrap model pin.
Only its retained `classifier_integration/complete.json`, fresh verification
logs and public receipts can establish that the native integration ran.
The bootstrap and retained integration are complete; no rerun is queued.
