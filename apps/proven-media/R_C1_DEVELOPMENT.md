# Classifier development adapter

`proven_media.classifier_prover.RungClassifierProver` implements the app's
`ClassifierProver` interface for the frozen **synthetic** R-C1 fixture. It
accepts `RungTokenItem`, not text or images. It is not exposed as a web-app
prover mode and its single `synthetic` category cannot be published as media
labels. The separate real `shieldstral_prover.ShieldstralProver` now integrates
the reviewed r16b CLI for the explicitly authorized testnet demo; see README.
Its first end-to-end run, full A2 benchmark and privacy acceptance remain pending.

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
`min_bits=93`, `development=True`. The binary, policy and statement schema must
match the frozen development version. Production deployments require at least
95 bits and cannot use either development binary listed here.

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

## R-C2 adapter preparation

The adapter also supports the frozen r13 development binary
`zk60_classify.r13.release.bin`, SHA256
`e320c2379bf765226c73e17ad5fe59dbd812e00980861102a1b9f727655feebb`, with explicit
`statement_schema="zk60-classify-run/2"`. A mismatched binary/schema pair is
refused; retained R-C1 jobs continue to use their original schema and binary.
R-C2 collection checks the reported yes/no IDs, threshold, margin scale, BOS and
final norm against the verifier export's profile, and checks the expected tied
source. Fresh native verification remains mandatory: these transport checks do
not substitute for the native tensor derivation or proof verification.

The independent token round-13 review accepted R-C2 on soundness for the
shipped CLI's scope; the coordinator recorded that acceptance at
2026-10-29T00:56:21Z. Retained r13 operations use the frozen CLI: its loader
binds the tables to the pinned model, while that release's library entry points
do not enforce the binding (N-r13-1). Round14 fixed the library binding; the
new r15 integration below also remains on the CLI.
See `results/zk60_token_io_review_r1_20261017/REVIEW_R13.md` from the repository
root. This acceptance does not establish privacy, classifier fidelity, or
availability of the real Shieldstral app path.

Nineteen adapter/orchestration tests pass, including schema downgrade, changed
classifier parameters, owner mismatch, altered receipt, missing chunks and
aggregate failures. `results/zk60_astra_20261026/classifier_c2_fixture/` contains
a separate synthetic fixture whose tensor, embedding and margin exactly match
the independent native-lane reference. The Python block matches a retained
native sequence. Its 327-input candidate search only observed verdict bit zero;
this fixture does not claim both native verdict branches. The fixed tensor and
registered policy were preserved.

`results/zk60_astra_20261026/classifier_c2_integration_1/complete.json` now
records successful native app integration: three public receipts, fresh
verification and input-owner checks, repeated rechecks and reversed multi-chunk
OR. Both a rehashed margin table and a changed verdict statement were refused
by the native verifier. `native_checks.json` retains the 20 guarded outcomes
(18 successes and two expected refusals), redacted events and log digests.
Peak sampled RSS was 0.16 GiB; these were watchdog-only runs on a shared box,
and sub-second verifiers can finish between samples. The fixture exercises
verdict bit zero only; both-bit transport tests are separate synthetic mocks.
The web app's Shieldstral mode remains unavailable pending the native R13
export, registered category profiles and review.

The r13 native split refused content shorter than one full chunk.
The exact A1 policies need 48–55 content tokens at T128 and 176–183 at T256.
`results/zk60_shieldstral_export_20261026/category_chunk_coverage.json` counts
the consequence across all 4,872 benchmark inputs: 32.5–77.0% of each
dataset/policy group is too short at T128, and 90–100% at T256 (unweighted).
The coordinator accepted this coverage file as the native round14 acceptance
set. The schema/3 integration below implements this route with explicit public
padding. Category prefix lengths differ, so each category keeps its own native
chunk plan. The app must not truncate or reuse the general card-unsafe policy.

## R-C3 short content and whole-post coverage

The adapter supports frozen r15 `zk60_classify.r15.release.bin`, SHA256
`5edb7241f3c6b788289fca4a03f4fd40649355cf016663ec9dadbdaaa66c9a8e`, with
`zk60-classify-run/3`. R14 was accepted on soundness at03:05:49Z; r15 is frozen
and was directed for app integration by the coordinator, with independent review
still separate. This app check is neither privacy nor real-model acceptance.

A short item is one range `[0,N)`. Its template is prefix, true content, suffix,
then public pads (development id2, Shieldstral id11). Collection checks the true
content length, padded context, item length, pad count and verdict row. The
original synthetic item is now required by `prepare_label` / `start_label`;
the expected total is never obtained from a receipt. The shared adapter checks
every statement's total, count, index and exact D41 range before launching an
aggregate, and r15 receives `--expect-total N`. The real-text coverage helper
derives N from the actual post using the pinned Tekken encoder and checks all
three category plans. Fresh proof verification and input-owner binding remain
mandatory; coverage alone establishes neither.

`results/zk60_astra_20261026/classifier_c3_integration_1/complete.json` records
five actual native cases: lengths1,11,22,23 and27, six receipts, a fresh short-item
recheck and reversed multi-chunk aggregation. Four truncated sets were refused
both before app job creation and by the native CLI. All29 guarded leaves ended:
25 successes and4 expected refusals. Peak sampled RSS0.16GiB, watchdog-only,
n=1 shared box; subsecond sampling can miss peaks. The registered synthetic
policy produced only verdict0, and the native reported floor was94 bits. The
production floor remains95, and the development binary cannot enable the web
Shieldstral mode. All130 app tests pass, including the new prefix controls.

## Category queue and current native handoff (2026-10-29)

`proof_plans.category_work_plan` preserves each category's native split and
assigns a distinct post-wide job index. The web routes use the prover's own
encoder/planner, and the worker recomputes the complete plan before starting,
collecting or publishing. Collection matches the record and schema/3 statement
to the category, policy, threshold, native chunk index, count, total and range.
Classifier jobs additionally require accepted verification, input binding and
a bound verdict. A changed plan after restart terminates as failed without
relaunching. Aggregation, manifests, publication addressing and the UI use only
the categories actually assigned to each job. Full suite:139 passed, including
nine queue tests with unbound local fixtures; no native proof in those tests.

The latest coordinator handoff supersedes the earlier native-registration wait:
R13 was accepted on soundness, and token round16 registered the real T128/T256
classifier and moderate policies. The app is directed to pin r16b binary
`dfb8025eb903b203f4b50371fdd0dd00659d46a9dbaad9d121d6a68343ebc70c`,
which removes the card-unsafe policy. The identity for the T128 export is
`29aeba6c04a819cdbafde311f7c9d0c678d85aff22292ae6b9647761158a0bd1`.
The prover-private per-item writer is implemented at
`results/zk60_shieldstral_export_20261026/write_item_activations.py`. It emits
`x_in_LXX.bin` / `x_out_LXX.bin`, little-endian int16 `[128,3072]` for all26
layers. All156 files for the retained35-token, three-category item match the
native writer byte for byte, with zero numerical refusals and75 checked layer
joins. Evidence: `results/zk60_astra_20261026/item_activations_check_2/complete.json`.
The guarded writer took66.15s/RSS0.71GiB, watchdog-only, n=1 shared box;
seven focused tests also pass. These are activation checks, not new proofs.
The next task is integrating this writer with the r16b adapter. The current
development adapter still pins r15; this handoff does not activate r16b.
Keep CLI-only, `--min-bits 95`, native `label --expect-total N`, the pinned
Tekken coverage check and input-owner verification. Strict versus moderate
remains a product ruling; real-classifier privacy acceptance is separate.
