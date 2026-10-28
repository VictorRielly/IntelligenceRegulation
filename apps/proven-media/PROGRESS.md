# Proven Media (media-app lane): progress ledger

Lane: MEDIA APP (coordinator brief 2026-10-21 ~02:30 UTC; D37, D38, D39 in
`docs/zkmatrix-poc/ZK60_DECISIONS.md`). Write set: `apps/proven-media/` and
`results/zk60_media_app_20261021/`. No git writes. Light work only, apart
from the stub proof runs, which go through the resource guard. Times are UTC
read from `date -u`.

## Ledger

- 02:37 start. Read CLAUDE.md, lane rules (+ 2026-10-19 addendum), D37/D38,
  the token-I/O presenter demo (`DEMO_PRESENTER.md`, `tools/demo_present.sh`,
  `cli/README.md`), the CLI module text (`frozen-r11/.../token_io/cli.rs`),
  the classifier survey. Guard status: heavy lock free, budget 9.6 of 11.89
  GiB committed by four light jobs (gate + fidelity lanes).
- 02:38 venv `apps/proven-media/.venv` (uv, CPython 3.10.12): fastapi
  0.115.6, uvicorn 0.32.1, python-multipart 0.0.20. Local `.gitignore`.
- Finding (shapes the stub): `zk60_token_io prove` needs, besides the 0600
  prompt file, the prompt's hidden activations (`--seq-dir`: x_in / x_out of
  every layer, bit-exact parity in the sealing pass). An arbitrary post
  therefore needs a prover-private sequence directory built by the integer
  reference first (`tlcalib.i_block`, the same route as the fidelity lane's
  `fp_export.py`). Tool: `tools/seqgen.py` (this lane), imports the
  calibration / fidelity code read-only. Acceptance: it must rebuild the
  export's `seq_ho00` byte for byte.
- Coordinator addition (D39, received ~02:40): text, image and video posts
  (typed items; one proof per image; video = public deterministic frame
  sampling, one proof per frame, any unsafe frame = unsafe; stub proves text
  only, image/video shown as "proof path in development"); a `Publisher`
  interface (`publish(record) -> anchor_ref`, `resolve(anchor_ref) ->
  record`) with a local stub (ledger file + content-addressed bundle store);
  an "anchored at ..." slot on the proof page. No network, wallet or chain.
- 02:49 seqgen acceptance [MEASURED, shared box, n=1]: `tools/seqgen.py --compare-seq`
  rebuilt the export's `seq_ho00` BYTE FOR BYTE (44 of 44 arrays) in 13.6 s; peak RSS
  0.53 GiB (cgroup 1.28 incl. page cache); guard waited 371 s for budget. Evidence:
  `results/zk60_media_app_20261021/seqgen_selftest_ho00.{log,guard.json,done}`.
- 02:51 the demo sample post ("Sunrise run along the river this morning. Cold air, warm
  coffee, and a great playlist. Who else is out early today?", 29 tokens + BOS + 2 "\n"
  pads) is accepted at every layer by the integer model (seqgen with `--crosscheck`:
  rx_block == i_block per layer; 18.5 s, peak 0.79 GiB). Files in the private self-test
  dir only.
- 02:55-03:00 app written: `proven_media/` (config, items [Text/Image/VideoItem, pm-vfs-1
  frame policy], records [ProofRecord, Verdict, policy, placeholder screen], prompting [the
  ONE encoding function], provers [ClassifierProver, StubProver, ShieldstralProver
  placeholder, FakeProver], publisher [Publisher, LocalLedgerPublisher], store [SQLite],
  jobs [queue worker, detached pipelines], app [FastAPI]), `tools/stub_pipeline.sh`,
  `static/` (index.html, app.css, app.js), `serve.py` (stop file
  `~/zk60-owner-private/proven-media/STOP-SERVER`), `tests/test_app.py`.
- Coordinator design rules from the classifier check (CHECK.md), received ~02:58, folded in:
  (1) fail closed: no accepted proof -> status "failed", shown "Could not be verified", never
  published; a re-check that the VERIFIER rejects withdraws the post (a re-check that merely
  did not run changes nothing); (2) one registered policy `pm-policy-v0`, digest pinned in
  config (the app refuses to start if the text changed), one threshold; the same content is
  screened once (private content key; 409 on a repeat; retry allowed only after "could not be
  verified"); (3) `prompting.build_prompt` is the only encoding path (stub: TinyLlama
  SentencePiece plain text, control strings stay plain text, tested; Shieldstral: template
  prefix ending at "<Document>:" + tekken plain-text ' ' + content + "[/INST]", raises until
  mistral_common lands); (4) content length in tokens shown as a public record field
  (pending Victor). Also: the ledger entry does NOT carry the endpoint roots (O-2 / D23;
  the D23 amendment for anchoring is pending, CHECK.md item 8).
- 03:01 unit tests: 23 of 23 OK (`.venv/bin/python -m unittest discover -s
  apps/proven-media/tests`; FakeProver, temp data roots, no proof run).
- Coordinator addition (~03:03): shape the Publisher to the chain-publication report §7
  (`results/zk60_chain_publication_20261021/REPORT.md`). Done: `PublicationRecord` /
  `AnchorRef` / `verify_publication`; publish only after the fresh-process verify accepted;
  manifest with per-segment {file, bytes, sha256}; leaf = SHA-256("zk60/anchor-leaf/v1" ||
  length-prefixed fields); sorted domain-separated Merkle batch every 10 min (PM_BATCH_SECS)
  or 1,000 leaves; one anchor(root, count, batchFileHash) per hash-chained block in a local
  "chain" file; local content-addressed store (local-cas://sha256/...); salted content
  commitment (per-post 256-bit salt, encrypted at rest under a local app key, served to
  viewers; crypto-shredding on delete); only accepted posts anchored; AnchorRef fields and a
  "Verify publication" action on the proof page; `tools/verify_publication.py` (third-party
  CLI, `--run-verifier` rebuilds the run from the store and runs the pinned verifier through
  the guard). Post ids are now 128-bit random. 28 of 28 unit tests OK.
- 03:08 bug found at first real start (not by the tests): `Worker.start(j)` shadowed
  `Thread.start`; renamed `start_job`, test added (worker thread starts and stops).
- 03:09 demo server started detached on 127.0.0.1:8765 (stub mode; log
  `~/zk60-owner-private/proven-media/server.log`). The sample post submitted through the API
  (text from a 0600 file, never on a command line): post `a72321cd7fb00a48664ccfc04eaedbd0`.
  seqgen admitted after a short guard wait; prove 103.9 s [MEASURED, shared box, n=1: four
  light jobs live]; then verify waited for the heavy lock (another lane's build
  `r12-golden-r9-build` held it). The queue panel showed "Waiting for the machine ..." live.
- 03:13 a FAKE-mode instance (port 8766, scratch data roots, red banner) used only for the
  screenshots of the "Not published" (author view) and "Could not be verified" pages:
  `results/zk60_media_app_20261021/screenshots/fake-*.png`.
- 03:14 image post (generated PNG) and video post (an MP4 container header with a 12.0 s
  `mvhd`, no frames: the app never decodes video) added to the stub server: both "proof path in
  development"; video plan = 6 frames under pm-vfs-1.
- 03:16-03:24 coordinator scope changes folded in: (a) text + image only (video/audio deferred,
  a "later" note in DESIGN.md); image upload = lossless master + canonical 224-px letterboxed
  canvas + patch-major tensor + salted commitment (multimodal design §2-§3), author-only
  canvas preview; (b) D37 operating model: proved once at creation, pending verification with
  queue position and ETA, visible only per proved outcome, no re-proving (resubmission only if
  nothing ever ran). Server restarts at 03:15 and 03:22 re-attached to the detached job (step
  state read from its files) as designed.
- 03:24 server STOPPED on purpose (stop file) so the pre-label code would not collect the job;
  the detached pipeline continued alone.
- 03:27 THE SAMPLE POST'S STUB PIPELINE FINISHED, exit 0 [MEASURED, shared box, n=1]:
  seqgen 18.3 s (peak 0.52 GiB); prove 103.9 s (129.4 s with loading; peak RSS 1.28 GiB;
  24 segments, 255,258,816 B, floor 97 bits); verify 18.9 s (30.3 s total, min 95 bits)
  after waiting 823 s for the heavy lock (another lane's build); owner 25.4 s (opened, kept
  private); input-owner 27.6 s ("input-checked", 32 tokens). The sequence directory was
  deleted after proving. Job files: `~/zk60-owner-private/proven-media/jobs/a72321cd.../prove/`.
- Coordinator (03:25-03:30): labels model (D37 latest): three confirmed categories (sexual /
  explicit, graphic violence, hate / harassment), each one fixed policy text + one threshold,
  3 proofs per item at creation, labels published yes or no, audience filtering (adult /
  minor), fail closed per category (unproved = most restrictive); plus a signed ProofManifest
  (zk60.manifest/1, Ed25519 local dev key) attached whenever an item is served. In progress.
- 03:30-03:44 labels model + signed manifest implemented: `records.py` (categories pinned,
  audiences, fail-closed visibility, aggregation), `manifest.py` (zk60.manifest/1, Ed25519
  over the canonical JSON; local dev key `~/zk60-owner-private/proven-media/publisher-dev-ed25519.key`,
  0600; `cryptography` 43.0.3 in the venv), publisher per (item, category), server-side
  audience filtering (hidden items served as placeholders with reasons, never content),
  `tools/verify_manifest.py`. 31 of 31 tests OK.
- 03:30 server restarted on the labels code: the finished sample job was collected (labels
  no / no / no, stub shared run), 3 publications pending, manifest signed; 03:34 batch-000000
  closed; verify-manifest and verify-publication accepted (all checks true).
- 03:35 re-verification of the sample queued (job 2; waited for the heavy lock, another lane's
  build); second sample submitted ("Movie night recap ... bloodbath, gore ...", 28 tokens,
  placeholder violence = yes) to show audience filtering.
- Coordinator D41 (~03:37): chunks per hardware profile. Implemented: `deploy.json` (laptop
  40/8/4, workstation 168/16/8, server 424/32/16; stub caps the chunk at 31), `chunk_plan`,
  one job per chunk, `chunk_proofs` table, finalize = aggregate (yes if any chunk yes; not
  proved if any chunk lacks a proof) + publish per (chunk, category) + signed manifest with one
  entry per (chunk, category) and token range; leaf v3; Status page; chunk x category grid,
  progress bars and per-item ETAs in the UI. 36 of 36 tests OK.
- 03:45 server restarted on the chunked code: the sample post was re-filed as chunk 0 and
  re-published under the chunked layout (3 new leaves; nothing re-proved; its earlier v2 leaves
  stay in block 0, unreferenced). The pending re-check re-attached.
- 03:46 third sample submitted (the "weekend plan" text, 50 tokens = 2 chunks = 6 proofs).
  Slip noted honestly: to preview its chunk plan I passed this PUBLIC sample text inside a curl
  command line once (the /api/tokenize call); the submission itself used `text=<file`. No
  user content was involved; later calls read from files only.
- 03:49-04:48 the queue stalled on the guard's known gap (lane rules, 2026-10-17 20:30 note):
  the token-I/O lane's `tio-r12-t1-classify` (cpu, need 4 GiB) held the heavy lock while
  waiting for budget admission behind long light jobs (fidelity 5 GiB, gate, Shieldstral bench),
  so this lane's 1.4 GiB verify waited 4,374 s. Nothing of ours was running meanwhile. Worker
  now also launches nothing new while `results/zk60_media_app_20261021/HOLD` exists.
- 04:49 RE-VERIFICATION of the sample post DONE [MEASURED, shared box, n=1]: fresh-process
  `zk60_token_io verify` over the published statement: event "statement-checked" (the
  statement re-checked byte for byte against every segment), 16.9 s (27.3 s total), min 95
  bits, peak 0.9 GiB; then input-owner "input-checked" (binding confirmed). The app first read
  only the "verified" event name and showed no seconds: fixed (accepts "statement-checked"),
  stored result refreshed from the job's log.
- 04:49 second sample (movie night, 1 chunk) started proving; third sample (2 chunks) queued.
- Fake-mode screenshots (red banner) for states the stub queue had not reached yet: feed as
  adult and as minor (hidden placeholders with reasons), two-chunk item page, fail-closed page,
  image pending (author view with the exact canonical canvas).

## 2026-10-26T19:29:21Z — Astra A3 continuation

Integer image preprocessing pm-img-area-v1 and Base Sepolia publisher are implemented and tested. Full app suite66/66 passed2.338s on host; network transactions have not been sent. Testnet contract compiler waits for shared heavy admission. Manual free faucet funding is pending for the public throwaway address recorded in TESTNET.md; no real spending. RungClassifierProver implements the actual frozen R-C1 command contract with a synthetic-only token item, fresh public verifier and private owner check, separate native aggregate-label job, and recheck. See R_C1_DEVELOPMENT.md. Eight contract/orchestration tests use mock leaves; a retained native fixture is now prepared for actual integration. The web app still runs its clearly marked next-token stub; Shieldstral export/native R13 production binary and privacy review remain pending. Current source manifests/diffs: results/zk60_astra_20261026/review/.
