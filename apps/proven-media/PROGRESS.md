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


## 2026-10-29T01:26:12.979427+00:00 — D45 enforcement and real text preparation

D45 app changes are implemented and validated. New private keyed item reservations exclude policy/threshold/author and persist across deletion; reservation, post and proof-job creation share a SQLite transaction. Changed policy/threshold cannot submit a second query, start a queued proof or collect its result. Only a pre-work failure can retry, under the original context. Retained legacy text is migrated; unknown/conflicting historical context refuses, and an earlier pre-work failure cannot hide a later proof. Already-erased historical content cannot be recovered or retrospectively reserved. No live user database was opened or migrated in this work; tests use temporary roots.

Missing/rejected chunk/category proofs now leave the post failed and outside every feed, with no new publication; native classifier modes also require bound verdicts. A later fresh verifier rejection withdraws the item. Existing chain history is retained. All109 app tests pass on host,3.658s (MEASURED,n=1 shared box), including HTTP flows, concurrent submissions, changed settings, deletion/restart and legacy controls. Original108-test run found three outdated test expectations for failed posts being visible; those tests now check the D45 behavior. Source snapshot and successful output: app_d45_test_result.json.

Text-only Shieldstral preparation now uses the pinned Tekken bytes and routes through prompting.build_prompt with an explicit category template. The legacy planner/count paths refuse Shieldstral instead of using TinyLlama. Each category has its own full-tail native chunk plan; short items remain refused pending round14. Actual check: all4,872 saved A1 inputs match, all1,006 literal-control/Unicode strings stay in the ordinary token class,7,474 category prompts are exact, and three empty/invalid Unicode inputs refuse. MEASURED2.03s/RSS0.2455GiB,n=1 shared box. Evidence shieldstral_text_check.json;9 focused text tests passed,8 existing prompting/chunk tests and19 classifier tests passed before the full109. Optional requirements match the installed calibration versions; no dependencies installed and no production policy selected or registered.

D45(3): R-C2 native verifier statements contain the sealed input root; the statement SHA enters the publication leaf/Merkle anchor, and the development adapter retains input-owner openings privately. Real Shieldstral publication remains unimplemented until native export/category profiles/adapter integration; no actual classifier batch published or broader privacy acceptance claimed.

Benchmark layer2 attempt1 ended normally at its ten-minute checkpoint (exit3),2,922/4,872 items,zero refusals,RSS2.23GiB,VRAM647MiB,successful drain. Updated next admission to2.8GiB (measured +25%, rounded up),cap4.5GiB unchanged. Sol's requested metadata gap was honored: metadata-gate-5 terminal0 at01:19:21Z before attempt2 launch. Layer2 attempt2 PID143440 is live; last host inspection4,170/4,872 with zero refusals. Do not duplicate it. Native loader-v2 remains under validation, not advertised as an accepted export interface.


## Astra continuation and app review — 2026-11-12T06:11:27.670126+00:00

A2 exact score candidate: all3 retained public category sequences prepared, zero range refusals; 156 arrays/78-layer numerical chain and first12 baseline layers checked. Pinned historical native checker ece0d17654012820b55a2a0643a63f201d1caa38+worktree.755ee522edf3 passes78 outputs+78 inputs; audit rehashes623pins. No current-main/A28/proof/privacy/adoption transfer. Original loader/browser jobs terminal0. Five historical screenshots visually inspected; detail/about findings retained as failed visual review. Current app fixes category-local chunk/anchor/label numbering, proof-job counts, publisher wording, explicit shieldstral-fast classifier/pending privacy handling; all3 frontend suites and diff check PASS. All3 own guarded sessions terminal0. Full A1-A8 remains; next current-native candidate proof gates and fresh browser capture. Handoff: results/zk60_astra_20261026/resume_20261111/HANDOFF.json.


## Astra current native/app review — 2026-11-12T07:59:46.596581+00:00

A2 exact score candidate now passes three complete classifier proofs on current app-pinned A28 binary80f2b704: candidate identity79915865 (baselinee4f97455), each26 layers+IN/OUT=28segments,84total. All3 fresh-process verify/input-owner/whole-item label gates PASS. Wrong content refused at owner binding; one flipped segment refused at block12 Merkle verification. Audit rehashes all receipt files and18 successful guarded leaves. These are public35-token fixture correctness runs, not performance/adoption/privacy claims.

Current app:222 Python tests+3 frontend suites PASS. Real HTTP/browser submission produces4 category jobs with actual tokenizer; pending details remain owner-only, anonymous404/minor-feed exclusion pass. Desktop/mobile/about/historical-published views inspected. Fixed category-local labels, publisher/mode wording, stale verifier instruction pins (now record-bound; missing/conflicting pins withhold command), and mobile overflow (390/390/390px). Historical screenshot receipts were not re-proved/re-verified; no native inputs/source/profile changed by app fixes. Retained failed harness/visual attempts and exact source snapshots; final review PASS. Native queue stayed disabled in browser runs.

A5 reconciled against retained A24-A28 resident-model implementation and10 successful app phases; matched attributable savings/current candidate adoption still owed. Full A1-A8 remains active. All own jobs terminal, no commits/push/deployment/external publication. Victor input pacing saved: batch permissions, routine decisions autonomous, about10minutes minimum between requests. Evidence and continuation: results/zk60_astra_20261026/current_app_20261112/AUDIT.json and HANDOFF.json.


## Astra lifecycle forward-port — 2026-11-12T08:20:02.191714+00:00

Completed coordinator L2/L3/M3 in isolated results/zk60_astra_20261026/app_lifecycle_candidate_20261112/. Current app base eee3eb57 preserved (79 source inputs rehashed); no installed source/factory/native/model changes. L2 retains kernel app lock until queue shutdown. L3 commits author deletion before erasure and resumes after restart, preserves screening reservation, rejects pending rechecks/foreign paths and prevents deleted-post resurrection. M3 closes a real partial-publication gap: all category/chunk anchors and manifest entries required before published status; retries use persisted30/60/120/240s delays and park after5failures without recollection/reproof. Final236tests PASS (222 original +14new,0skips); actual synthetic receipt corruption refused; real process lock exclusion passes. Original failed r2 stale-deleted-job queue-head regression preserved and fixed. Five-file patch replays byte-identically on saved base; AUDIT.json/REPORT.md/lifecycle.patch ready for coordinator review. No host input requests, Git writes, production adoption or live owned jobs. Full A1–A8 remains active; next resident_writer_candidate_20261112 and requested A1 report tables.


## Astra resident writer results and lifecycle integration — 2026-11-12T09:27:40.216732+00:00

One approved immutable controller (89616) completed at 09:18:15Z. All five guarded leaves exited 0 without stragglers; there were no per-leaf, status or integration approval prompts. The four actual app trials used the same A28 binary 80f2b704, baseline profile 2ba468f9 and identity e4f97455. ABBA post times were 47.501, 40.386, 41.613 and 46.912 seconds: means 47.206 baseline versus 40.9995 resident, a 13.1485% reduction with two samples per arm. This is warm-service latency for one public 14-token post and three categories. All 12 category proofs passed separate verification, input-owner and label checks, plus signed local manifests; external anchors remain pending.

The corresponding writer-only comparison (two concurrent writers, then the third category) fell from 11.762 to 4.081 seconds, or 65.3%. The final audit rehashed 323 inputs, 2,184 generated activation files, 156 retained baseline arrays and 336 receipt segments totaling 10,180,945,152 bytes. Counted model storage is 26.903 GiB per resident worker. Sampled service RSS was 54.57–55.41 GiB baseline versus 115.10–115.42 GiB resident; the 196/220 GiB admission/cap remains the qualified setting. No cold-start, sustained-load, general-speed, earlier 26-second queue-saving, privacy or adoption claim. Evidence: `resident_writer_candidate_20261112/REPORT.md`, `AUDIT.json` and `RESULT.json`.

After the terminal record and source audit, applied the coordinator's 09:11-approved lifecycle patch to `apps/proven-media`. All five app source files match the candidate byte for byte; 14 tests were installed with a portable subprocess import path. The final 236 installed tests pass with zero skips (7.18 seconds). The initial missing-tokenizer/test-relocation failure and a preflight manifest-key failure remain in their logs; the final runner selects authenticated existing tokenizers. `app_lifecycle_candidate_20261112/INTEGRATION_FINAL.json` and `INTEGRATION_REPORT.md` record integration. The resident writer remains an isolated candidate; native/profile/Git/deployment state is unchanged.

A1 tables are complete: 18 sources and 4,872 stored float rows audited, with the historical missing-label convention separated from conservative known-label metrics. A4's fresh bounded cache/access review found no named local payloads or configured token; official VLGuard/UnsafeBench cards still require access conditions. No agreement, access request or download occurred. The coordinator can supply an already authorized pinned payload manifest, provenance and annotation/split review; no repeated questions were sent to Victor.

Disk review: about 63.14 GiB free. This study's external writer/app scratch totals 2.059 GiB, so even removing all of it cannot restore 75 GiB. The audited public receipt/CAS copies consume about 19 GiB. Evidence and other lanes were preserved. A larger archival/deduplication decision belongs in this coordination channel; bundle any external cleanup with a substantive future host launch. Updated full A1–A8 handoff: `current_app_20261112/HANDOFF.json`. All owned experiment workers are terminal, and the full goal remains active. Please reflect the scoped writer timing in coordinator-owned `MVP_STATUS.md` at its next update.


## Astra installed resident writer and opt-in W16R2 app — 2026-11-13T00:53:54.641757+00:00

Coordinator Batch2 authorization implemented in apps/proven-media:19app files plus4new test files, retaining baseline one-shot/R13 defaults. Actual W16R2 intake is still pending and launch refuses. Runtime/hardware/public verifier now explicitly bind HL_A30_B3PAR=1 with HL_A26_KEPT=1; no native identity inherited. All303 installed Python tests pass,zero skips (8.814s), and all4installed frontend suites pass. First system-Python attempt lacked app dependencies; existing a28-tools environment passes.93source/test/runner inputs pinned,94prior candidate inputs unchanged,23-file installation patch replays exactly against retained dirty pre-install bytes. AUDIT/PACKAGE/REPORT at w16r2_app_install_20261113. No Git/native/formal/production changes.

Isolated recovered A25 compile prepared but no native leaf started: sandbox guard sysctl denied; one approved host retry encountered the shared heavy lock. Fixed normal admission-wait handling,5cases pass; original attempts retained. New coordinator batch2 owns A30/A31, so no duplicate native build queued. Actual a30a31_pin.json absent at this checkpoint; native app/public-store qualification next after authenticated intake/export. All own workers terminal, full goal active. Continued app work instead of waiting on native build; no per-step/status questions or new approval request for installation.


Astra 2026-11-17T07:23:21.324482+00:00: A6 keyboard-recovery child72645 exited0 at07:19:50Z under original19215; all nine actual browser captures are byte-identical to the previously inspected images. Trusted Enter events, policy expansion, table accessibility roles, no overflow/errors/network requests and clean browser close pass. New a6_mobile_labels_integration_20261117 verifies the parent controller's completed-child record explicitly; it does not misreport the still-live original19215 as terminal. All153 source/runtime pins and six installed baseline files checked before atomically installing only app.js/app.css; all4 installed frontend suites PASS. Existing dirty baseline is retained in the candidate snapshot. Installation report bd5ee83c4d8c1caef244d2235ab13f78487b33aa000de42aa20f8e755695c735; visual review 6b7198463e55e35683c70f198f665848f242248e2449a148b9467f6fa9e515fb. Sealed browser/native candidates and original failed attempts unchanged. Parent advanced automatically to full_length_text at07:20:00Z; X follows serially. No new host request or user input needed. T retained/fresh receipts and assigned-plane follow-up remains independent work; full goal active.


Astra 2026-11-17T08:04:11.955710+00:00: Original19215 is observed terminal exit1; browser exited0, original fixedT256 text exited1, Ximage replay exited0. Xpasses all5guarded leaves,4units, saved102frame ordinary fresh verification and changed-frame rejection. Retained container2873106100B SHA61acab208f0f9bec8c1c590416cba5176157ea7a6ed8023305acf4cd30d8b837; peak13.79GiB, fresh replay98.2172s shared-host diagnostic. Full source/evidence and actual retained frame hashes rechecked before freezing452files/44549701B. RESULT f56699bcc16108320d2d9472c564c4be7357d9230ea768cb814489bce3751dc3; PACKAGE a1a0420973d1ce1f49067699902c22fd07dbee042af33e16b2ea41c85a4dcb11. Oneblack/refusal_free case only, no OSisolation or allTclosure claim. Do not poll/restart original19215 again.

A2 exact-real-length recovery is prepared in a2_real_length_review_20261117: six profiles174/180/181/234/240/241 with storage256, zeroextra padtokens, canonical registries/arithmetic/relations unchanged. Six independent exports authenticate all weight payloads and52RoPEprefixes each; six full162historical-array sequences and exact head margins are prepared. New373file source has8test-hook/validation edits and1newmodule. Fixed24leaf scope covers check/build/profile identity/policy/regression/admission, all6native26layer parity checks before proofs,6proofs and36fresh operations. Preflight passes, native compilation/parity/proofs pending. No new host request this checkpoint; T follow-up remains independent implementation. Resource rules re-read: oneheavylock,2threads,defaultpoll,10sgaps,55GiBfloor. Main native/formal/Git/profile adoption unchanged; full goal active.
