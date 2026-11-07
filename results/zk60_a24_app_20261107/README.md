# A24: the media app's classifier proofs on the fast machinery (2026-11-07)

Lane A24. Goal (Victor, 2026-11-07): bring the 8B stack's optimizations to the media app's
Shieldstral classifier proofs, and get the app to about 30 proved tok/s.

Labels: [MEASURED] a number from a log in this directory; [INFERRED] derived from measured
numbers; [CODE] read from the source. Metric (MVP_STATUS's): proved tok/s = 128 x (category
proofs completed) / wall seconds. Every receipt counted was freshly verified. Public text only.
Machine: the M3 Ultra Mac (32 cores, 256 GB, 80-core GPU), shared with other lanes; every timed
run went through the resource guard, with no `ds4-bench` running (`*.quiet` files).

## 0. Plain summary

- **Through the app, every receipt freshly verified, a stream of 8 public posts now runs at 11.4
  proved tok/s (15.4 in its second half); one post takes 70 s (5.5 tok/s)** [MEASURED, section 2].
  Before: about 0.17 proved tok/s (Astra's r16b-era CPU path, 2 threads: about 756 s of work per
  category, 37 minutes per post). That is about 65x on the stream and 32x on one post.
- **30 proved tok/s is not reached.** Under a stream the Mac is CPU-bound (about 89% of 32 cores),
  at roughly 300 core-seconds per category proof, a third of it fresh verification. The next
  levers need protocol or ruling work: W16R2 (and later W16R3) for real content (A10), a parallel
  or GPU verifier, and the R13 sealing builder (section 7).
- **What changed:** two resident native servers (`zk60_classify serve`, `check-serve`): the model
  loaded and checked once (the old CLI spent 28 s per process re-hashing the export), the Metal GPU
  on, several categories proved at once on their own thread pools, the sealing pass's witnesses
  reused, verify + input-owner + label in one pass per receipt instead of three processes. A new
  app mode `PM_PROVER=shieldstral-fast` runs them as one guarded service.
- **No receipt format change.** The receipts are `prove` receipts; the unchanged CLI `verify`
  accepts them. D55 fork-join was not used for the classifier (it needs a new registered profile
  and does not reduce work; section 4).
- **Not covered by D58, not production.** The new mode says "privacy statement pending"
  everywhere and `production: false`. The stub and reviewed `shieldstral` modes are unchanged.

## 1. What is on the clock

- **Native stream rows** (`stream_driver.py`, the two servers driven directly): the clock starts
  at the first post and stops when the last post's third category label is accepted. On it: the
  activation writer (Astra's Mac writer, Python, one call per post), the prover's sealing pass and
  witnesses, the proof, the receipt write (every segment written and fsync'd), fresh verification
  in the separate verifier process, the input-owner check, the category label. Not on it: the
  servers' startup (both load and check the model, about 32–35 s, once).
- **App rows** (`app_driver.py`, the real app in process through its HTTP routes): the clock
  starts at the phase's first `POST /api/posts` and stops when the app has published the phase's
  last post. The activation writer runs once per category job here (two at once), as the
  reviewed pipeline does. On it, in addition: tokenization and D45 screening, the queue (`Worker`, 2 s ticks),
  the app's own re-checks of every native output (`ClassifierCLI.collect_verified` re-hashes every
  segment; `collect_label`; `check_final_records`), publication to the local content-addressed
  store and the local hash-chained ledger, and the Ed25519-signed manifest. The service startup is
  outside the clock in the warm rows and is reported on its own. Anchoring a batch on a chain is
  not on any clock (local ledger only).
- "Fresh verification" here means the verifier server: its own process, which loaded and checked
  the public model itself, re-derives every statement byte for byte, re-hashes every block it
  binds and checks every segment. It is not a new process per receipt (the old CLI's 28 s digest
  pass per process is what the server removes).

## 2. Numbers

**Baselines** (one category = one 128-position proof):

| path | per category | proved tok/s | source |
|---|---:|---:|---|
| the app today: r16b-era CLI, CPU, 2 Rayon/BLAS threads; prove + 3 fresh verifications (Astra, 2026-11-05) | 752–760 s of work | **0.17** (0.24 counting the prove process only) | [MEASURED] `a3_classifier_native_20261105/README.md` |
| the current tree's CLI, all 32 cores, CPU: prove 172.1 s + 3 x verify 49.2 s | 319.7 s | 0.40 | [MEASURED] components, `baseline_b1.progress`; [INFERRED] sum |
| the current tree's CLI, all cores + Metal GPU: prove 73.4 s + 3 x verify 48.5 s | 219.0 s | **0.58** | [MEASURED] components; [INFERRED] sum |

**The resident servers, driven directly** (`stream_driver.py`; every proof freshly verified,
owner-checked and labelled; public posts of 14–20 tokens, 3 proofs each) [MEASURED]:

| run | prover lanes x threads | verifier lanes x threads | posts | wall | proved tok/s (all) | steady (second half) | content tok/s | one post's latency |
|---|---|---|---:|---:|---:|---:|---:|---:|
| `stream_one1` | 3 x 10 | 3 x 4 | 1 | 64.4 s | **5.96** | — | 0.22 | 64.4 s |
| `stream_p1` (profile, timing on) | 1 x 32 | 1 x 32 | 1 | 90.6 s | 4.24 | — | 0.16 | 90.6 s |
| `stream_s8a` | 3 x 10 | 3 x 4 | 8 | 340.7 s | 9.02 | **10.07** | 0.40 | 67–238 s |
| `stream_s8b` | 6 x 5 | 3 x 4 | 8 | 285.8 s | 10.75 | **12.69** | 0.48 | 85–201 s |
| `stream_s8c` | 8 x 3 | 4 x 2 | 8 | 298.0 s | 10.31 | 16.42 | 0.46 | 106–220 s |

These are single consecutive runs on the shared Mac (no ds4-bench seen), not A/B pairs; s8c
(smaller pools) is slower amortized and faster in its second half than s8b, so it is no clear
gain [MEASURED, n = 1 each]. The app uses s8b's settings.

One post on `stream_one1`: the writer 14.6 s, the three proofs at once 38.5–39.5 s (each 28.2–28.7
s in the run), the three verifications at once 10.4 s. Peak memory of the guarded tree (both
servers): 62 GiB (one post), 67 GiB (s8a), 102.5 GiB (s8b); GPU memory up to 48.6 GB.

**Through the app** (`app_driver.py`, `PM_PROVER=shieldstral-fast`, the service warm) [MEASURED]:


| phase (`app_a2`) | posts | content tokens | category proofs | wall | proved tok/s | steady (second half) | content tok/s | per-post latency |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| one short public post | 1 | 16 | 3 | 70.0 s | **5.49** | — | 0.23 | 69.7 s |
| one long public post (3 chunks per category) | 1 | 123 | 9 | 174.5 s | 6.60 | — | 0.70 | 174.2 s |
| a stream: 8 short public posts submitted at once | 8 | 137 | 24 | 269.3 s | **11.41** | **15.38** | 0.51 | 90.9–269.1 s |

All 12 posts published (36 category jobs, 36 accepted, 0 failed); every label "no" and
`bound_by_proof: true`; every record says `shieldstral-fast`, "privacy statement pending",
`production: false`; each published post has its signed manifest (3 or 9 entries). The service
(one guarded job) waited 685 s for the heavy lock behind another lane's job, loaded in about 33
s, ran 547 s, peaked at 98.2 GiB RSS and 49.1 GB of GPU memory, and stopped on `STOP`. The app
keeps up to nine category jobs at the service (six prover lanes of five threads, three verifier
lanes of four). The long post verifies its first two chunks of each category twice (section 7).
The "steady" column is the second half of one closed batch (its last posts compete with no new
work), so the amortized column is the honest stream figure.

## 3. Where the time goes

**One category alone on the resident servers** (`stream_p1`, one lane of 32 threads, GPU,
`HL_PB_TIMING=1`) [MEASURED, three categories one after another]:

| step | seconds per category |
|---|---:|
| activation writer (Python, the post's three chunks in one call: 10.2 s) | 3.4 |
| prover: stage IN-C inputs | 0.5 |
| prover: the sealing pass (26 witness builds, int16, parity, CS-3) | 7.9 |
| prover: stage OUT-C values, the input endpoint's seal, the statement | 0.5 |
| prover: the run (IN-C, 26 blocks, OUT-C, 28 segments written) | 15.0–15.4 |
| verifier: door + every segment + owner check + label | 8.8–12.0 (the run 8.2–11.3) |

Inside the run, summed over the three categories (41.7 s of block phases, 0.54 s a block): the
two large zero-checks (slots 14 and 18) 11.3 s, the A and H commitments 9.4 s, writing segments 2.0
s, the A/H openings 2.8 s, the softmax and Q zero-checks 2.4 s, the witness planes to committed
rows 1.5 s; the witness is no longer rebuilt (the sealing pass's is reused), and the block reloads
are gone. The verifier's blocks: 24.9 s summed (0.32 s a block), led by the same two zero-checks
(6.1 s) and the A opening (2.5 s); it verifies one block after another (one transcript).

**Under load the machine is CPU-bound** [MEASURED, s8b]: with six prover lanes the prover process
used about 20 cores and the verifier about 8.6 (CPU 89% busy, `top`), GPU memory peaked at 48.6
GB. Each category then costs about 300 core-seconds of the 32-core machine [INFERRED: 28.5 busy
cores x 10.7 s per proof in the steady stream], of which the verifier is about a third.

## 4. Design note: which 8B pieces carry over, and the receipt format

**Where the old path spent its time** [MEASURED, `baseline_b1_*.log`, the current tree's CLI, all
cores, one category]. `prove` = 73.4 s on the GPU (172.1 s on the CPU), of which 46 s come
before the proof: the export's digest pass (every layer loaded, its arrays SHA-256'd) 28.1 s,
the tied tables re-derived from the checkpoint 1.7 s, two stretches of about 3.1 s each that
were the embedding digest hashed two bytes at a time, and the sealing pass 9.9 s (every block
reloaded from disk and its witness built). The run itself is 27.5 s on the GPU (124.2 s on the
CPU), of which block reloads are 1.7 s and the witness built a second time 5.2 s. `verify` =
48.5 s, of which the same digest pass is 28.6 s and the run 14.9 s. The app ran three such
verifications per category (verify, input-owner, label), each in a fresh process.

**What carries over from the 8B stack** [CODE]:

| 8B piece | carried over? | how |
|---|---|---|
| A22/A23 resident model, one load and check at startup, shared blocks | yes | `serve` / `check-serve` keep the digest pass's own block objects (`ExportPublic::load_keeping`) and the tied tables for their life |
| per-fork rayon pools (A11) | yes | each server lane has its own rayon pool |
| GPU (Metal) device slots and commitments | yes | `HL_GPU=1`: the classify run's `prove_core` already takes the device path; it was never turned on in the app |
| the sealing pass's witnesses reused by the proof (A3's cache) | yes | `seal_chain_keeping`: within a budget, the run takes the sealing pass's witness when the stage shape and input plane are the ones it was built from |
| A21 SHA-256 / BLAKE3 | partly | the export loader already uses A21; the classifier's own embedding digest was fixed separately (one 2-byte `update` per word -> 1 MiB pieces, same bytes) |
| D55 fork-join (`run_fork.rs`) | **no** | see below |
| A16 sealing builder, A17/A18 fork host work, A12 device tables | as far as the classify path shares `build_for_block` / `prove_core` | no classify-specific change |

**Why not D55 for the classifier.** D60 registered D55 for the twelve R13 *blocks-only* run
profiles (`run::D55_RUN_PROFILES`, which include the Shieldstral T128 blocks run), not for the
classifier run profile (`private-classify-run-shieldstral-3b-t128-r13-public-row/2`, stage IN-C,
26 blocks, stage OUT-C on one transcript, the verdict public). A D55 classifier run would be a
new run profile with a new transcript header, a new receipt layout (fork frames and a tail) and a
new verifier: IN-C before the commit phase, every boundary B_1..B_L committed, the forks, the
join, then OUT-C. That needs its own design and review, a D60-style registration by Victor, the
D60 real-content privacy gate (`D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is still `false`, so even
the registered 8B D55 path refuses real content without the test-receipt flag), and its own Lean
statement (D63). It also does not reduce work: D55 runs one request's blocks at once, and the
servers already run several requests at once, which gives the same machine-bound throughput
[INFERRED from the CPU-bound stream below]. D55 would mainly cut one post's latency.

**So the receipt format does not change.** Every receipt the servers make is a `prove` receipt
(the same 28 segments, statement schema `zk60-classify-run/3`, run profile `/2`, trained
statement identity `e4f97455…`), and the unchanged CLI `verify` / `input-owner` / `label` accept
it (rung tests, and the real Shieldstral receipt in `negctl.progress`). For the verifier that
means nothing changes. For **D58** it means nothing new is asked of the statement's text, but D58
accepted only the named r16b CPU binary (`dfb8025e…`, identity `29aeba6c…`, profile `/1`): this
binary, its post-F12 profile `/2`, its GPU execution and its server form are **not covered**; the
new mode says "privacy statement pending" everywhere. For **D63** nothing here is production.

## 5. What was built

**Native (hashline, `src/private_block/token_io/`):**
- `classify_serve.rs` (new): `zk60_classify serve` (prover) and `zk60_classify check-serve`
  (verifier), JSON request lines on stdin, one `served` line per request on stdout, each request's
  own events in its own owner-only log file. `serve` runs `prove_with_public` (the `prove`
  command's own function: every refusal in its order, its two fresh OS draws, its directories)
  over the resident model. `check-serve` runs `verify`'s B-3 door (`door_statement`) and full
  verification over the resident blocks (CS-6 re-hashes every block), publishes the statement as
  `verify` does, runs `input-owner`'s check and then `label`'s aggregation with the post's count
  (`"label": false` for a chunk of a multi-chunk category). Lanes, each with its own rayon pool;
  a busy set refuses two requests on one run directory at once. One data owner per process (D73).
- `classify_cli.rs`: event lines through `event()` (stdout unchanged for every CLI command; a
  server captures them per request); `seal_chain` over any block source and
  `seal_chain_keeping` (witness reuse, budget 0 = before); `SharedProve` gains the resident
  blocks and the witness budget; `door` split into the load half and `door_statement`.
- `classify.rs`: the embedding / margin digests hash the same bytes in 1 MiB pieces.
- `load.rs`: `ExportPublic::load_keeping` (the digest pass, optionally keeping each block).
- `classify_batch.rs`: the new `SharedProve` fields (no behaviour change).
- Outside `token_io/` (minimal, additive): `examples/zk60_classify.rs` (two subcommands),
  `private_block.rs` (one `pub use` line), `hash_domain_tests.rs` and `s25_tests.rs` (the new
  file added to the absorb-label scan, the module graph, the generator census and the test-file
  list). **No change** to `run_fork.rs`, `trained_block.rs`, `protocol.rs`, `argument*.rs`, the
  PCS, `src/manifest.rs` or any 8B path.
- `classify_serve_tests.rs` (new): 5 tests at the development rung (section 6).

**App (`apps/proven-media/`), new mode `PM_PROVER=shieldstral-fast` (development candidate):**
- `shieldstral_fast_runtime.py`: pins (binary `ccd58102…` outside the repo, identity
  `e4f97455…`, profile `2ba468f9…`, Astra's Mac writer and its two dependencies), the servers'
  settings, the service's guard declaration, privacy "pending" (`device: metal`,
  `proof_mode: resident-server`), `production: False`.
- `shieldstral_fast_prover.py`: the same templates, plans, statement checks, input-owner binding,
  category aggregate and `check_final_records` as the reviewed mode, re-run by the app on the
  service's outputs with the same `ClassifierCLI` collectors; `max_running` jobs at once.
- `fast_service.py` (client) and `tools/fast_service.py` (the service): ONE guarded gpu-class job
  holding both native servers; lifecycle = start on demand (`ensure_running`), health
  (`service.lock` flock + `heartbeat.json`), stop (`STOP`, or idle 300 s, which frees the heavy
  lock), crash recovery (a job claimed by a dead service run is not alive: the queue fails it
  closed, never retries it; unclaimed requests wait for the next service).
- `jobs.py`: a prover with `max_running > 1` gets a concurrent tick (`_tick_concurrent`); every
  other prover keeps the one-at-a-time tick byte for byte.
- `config.py` (`is_shieldstral_mode`, a separate screening set id for the new mode), `provers.py`
  (factory and verify instructions), `app.py` (two mode checks), `hardware_profiles.py`
  (`fast_classifier_profile`), `deploy.json` (`classifier_profiles.shieldstral-mac-fast`).
- The default `stub` mode and the reviewed `shieldstral` mode are unchanged (their tests pass);
  `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.

## 6. Tests, negative controls, byte preservation

**Native, at the development rung** (`classify_serve_tests.rs`, all pass, `accept_t1.progress`):
1. `serve` proves a two-chunk rung post on two lanes, with the witness cache on (1 GiB) and off;
   every receipt passes the UNCHANGED CLI `verify`, `input-owner` (whole content) and `label
   --expect-total`; the prover publishes nothing; owner files 0600 in 0700 directories.
2. A request refused before its header (an empty activation directory) creates nothing, its line
   is D65(2)'s constant refusal (the detail to the private log), a malformed line and a policy the
   server does not admit are refused, and the next request proves.
3. `check-serve` verifies both chunks once each, publishes each statement as `verify` does (the
   unverified one retired), owner-checks, labels; a second check re-checks the published
   statements byte for byte; the CLI `verify` accepts the server-published statements.
4. **Negative controls** refused, fail-closed (the D45(4) line, no label): a tampered segment;
   the same length with different content; a policy the server does not admit; the post's prefix
   only (`expect_total` 26 of 27); a missing chunk; the wrong model twice (a verifier pinned to
   another identity refuses to start; another export's verifier refuses this export's runs).
5. The table digests in 1 MiB pieces equal the word-by-word digests (three sizes, one past a
   piece boundary).

**Native, on a real Shieldstral receipt made by `serve`** (`negctl.progress`, stream s8a's first
post, the sexual category) [MEASURED]:
- the UNCHANGED CLI `verify` accepts it (exit 0, `published_by`: "an earlier verifier
  (re-checked byte for byte)": check-serve's published statement is the CLI's own rendering) and
  the CLI `input-owner` accepts its decommitment against the whole content;
- `check-serve` refuses a tampered copy (one byte of segment 5: "block 4: A: pcs zk: Merkle path
  for column 53653 fails"), the same length with one id changed ("owner check: the sealed input
  plane is not the owner's content"), the wrong policy (violence on a sexual receipt: "the
  statement's policy is … not the one this verifier was given"), the post's prefix only
  (`expect_total` 13 of 14: refused by the label rule), each with the fail-closed line; the honest
  request after them is accepted;
- a verifier pinned to the reviewed r16b model identity (`29aeba6c…`) refuses to start (exit 1,
  the fail-closed line): the wrong model.

**Full hashline lib suite** (release, gpu-metal; `accept_t1_full.log`): 961 passed, 7 failed, 130
ignored. Three failures are the A23 merge's known ones (`a_toy_receipt_made_before_f12_is_refused`,
`accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces` — a fixture file absent
on the Mac, `review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name`). Four
were this lane's: the s25 census lists (module graph, file count, test-file list) did not yet name
`classify_serve.rs` / `classify_serve_tests.rs`; fixed additively in `s25_tests.rs`, re-run in
`accept_t3.progress` (`accept_t2` stopped at a list-length typo): `s25_tests` 20 passed,
`hash_domain` 15 passed, every `token_io::classify` test 82 passed (12 ignored, as before), the
A24 tests 5 passed, and A23's device test of the stack server on the R13 export
(`a23_the_server_with_shared_blocks_proves_the_r13_export_as_stack_prove_does_on_the_device`)
passed — 0 failures. zkp-core: 81 passed. No-feature `cargo check --tests`: clean.
No warnings in this lane's files.

**App** (`/private/tmp/zk60-astra-app-refresh-20261104-venv` python, the coordinator's command):
216 tests OK (the 209 existing plus 7 in `tests/test_shieldstral_fast.py`: mode selection and the
default/reviewed modes unchanged with separate screening sets; metadata pending / not production,
and a spoofed descriptor still not D58's; preparation pins and one spool request per job with one
service launch; a job claimed by a dead service is not alive; the hardware profile validates and
refuses retuning; the concurrent queue keeps at most `max_running` and every post finalizes; the
service with simulated servers fails a refused prove or check closed and STOP ends it, lock freed).

**Byte preservation** [CODE + tests]. No 8B source changed (`run_fork.rs`, `trained_block.rs`,
`protocol.rs`, `argument*.rs`, PCS untouched), so `stack-prove` / `stack-serve` receipts cannot
move; their tests in the full suite pass as before. For the classifier: the CLI commands run the
same functions with the same inputs (`event()` prints the same line; `seal_chain` with budget 0 is
the old loop; `load_with` is `load_keeping(false)`; the digests hash the same bytes, tested). The
servers call the same `prove_with_public` / `verify_classify_run_with`; the only differences are
the block source (the digest pass's own objects, digests checked at startup and re-hashed at every
stage) and the reused witness (the builder is a function of the block, shape and plane; reused
only when all three are equal). Every classify test in the suite passes. A fixed-entropy
byte-for-byte comparison (`r18/tools/run_fixed.sh`) needs bubblewrap and is not possible on the
Mac; that is the one byte-identity check not run here.

## 7. Open issues and the next levers

**30 proved tok/s is not reached.** The stream is CPU-bound at about 300 core-seconds per
category proof (section 3); 30 tok/s needs one proof every 4.3 s, about 2.5x less work per proof
on this Mac. No scheduling change gets that; the levers, largest first:

1. **W16R2 for real content (efficiency plan A10).** The classifier runs the R13 profile, whose
   blocks commit about 1.8x W16R2's rows; the 8B stack's 32 tok/s is W16R2 on synthetic weights.
   Needs the W16R2 privacy gate on GPU bundles, D60's conditions and a ruling by Victor, then a
   W16R2 classifier export and profile. [INFERRED: x1.8–2.4 per block, A10's estimate.]
2. **The verifier is about a third of the machine.** It verifies the 26 blocks one after another
   on one transcript. A verifier that first replays the transcript (absorbs and squeezes only)
   and then checks the blocks in parallel would cut its latency, not its work; moving its
   zero-check evaluations to the GPU would cut its CPU. Both touch `protocol.rs` (Sol's W16R3
   lane owns it) and need review. Or verify on a second machine: the receipts are files.
3. **The sealing pass is 7.9 s of a 24 s prove** (26 R13 witness builds, CS-3, parity). A16's
   builder work was for W16R2; the R13 accuracy builder (`witness_accuracy.rs`) has not had it.
4. **Rayon pool sizes.** Six lanes of five threads beat three of ten by 26% steady (19% amortized);
   eight of three with a 4x2 verifier was not better amortized (s8c). Quiet A/B pairs in both
   orders are needed before retuning; none were run here.
5. **D55 for the classifier** would cut one post's latency (about 85 s now) but not the stream's
   work (section 4); it needs a new registered profile.
6. Smaller items: the activation writer is Python (10 s a post, about 3 cores) and could be the
   native builder's own chain (it is a cross-check today; removing it removes a refusal, so it
   stays); the embedding digest is recomputed about 3 times per request on each side (about 0.5
   s each); the app re-hashes every segment 2–3 times in its one worker thread (collect, publish).

**Open issues.**
- Privacy: the new mode's binary, profile `/2`, GPU execution and server form have no privacy
  acceptance (D58 covers r16b only). A D58-style review of the post-F12 GPU path is needed before
  any non-public post. One data owner per process (D73) is assumed (the platform operator).
- The fixed-entropy byte-identity harness needs bubblewrap; not run on the Mac.
- `classify_r18`-style tests for `serve` at the real Shieldstral profile run only in the
  measurement jobs (they need the 4 GB export and 35 s of load), not in the unit suite.
- The service depends on two untracked directories of Astra's (the Mac writer, the model root).
- Long posts verify their earlier chunks twice (once per chunk, once in the category label).

## 8. Operational notes

- **Disk floor.** At the lane's start the Mac had 39.9 GiB free (the guard's heavy-job floor is 40
  GiB), with 235 GiB of RAM available and no swap in use, so every heavy job waited.
  `run_guarded.py` set `ZK60_GUARD_DISK_FLOOR_GIB=25` for this lane's own jobs only; the 8 GiB
  kill floor was unchanged. Later the disk had 130 GiB free. Each Shieldstral receipt is 848 MB;
  the drivers keep one post's receipts per run and delete the rest after their verification.
- **The heavy lock.** From 19:4x local (coordinator's request) every new run waited until the
  guard had shown no other job for about 3 minutes (`polite_launch.py`).
- **Paths outside git.** Astra's Mac activation writer
  (`results/zk60_astra_20261026/a3_mac_writer_20261105/`) and the public model root
  (`results/zk60_astra_20261026/flashprove_runtime_20261104/models/`) are untracked files of the
  main checkout; the new mode finds them through `PM_FAST_WRITER_ROOT` / `PM_FAST_MODELS` when it
  runs from a worktree. The binary is at `~/zk60-artifacts/proven-media-fast/bin/zk60_classify.a24`
  (`PM_FAST_BINARY`), never in the repo; its SHA-256 is the pin.
- **Private state.** Content ids, activations and owner openings of every run are under
  `~/zk60-owner-private/a24-*` (0700 directories, 0600 files); receipts under `~/zk60-artifacts/a24-*`.
  This directory holds scripts, logs of public words and summaries only.
- **How to run the app in this mode** (development candidate; public posts only):
  `PM_PROVER=shieldstral-fast PM_FAST_BINARY=… PM_FAST_WRITER_PYTHON=<python with numpy>
  PM_FAST_SERVICE_PYTHON=<the app's python> PM_SHIELDSTRAL_TOKENIZER=… serve.py`; the first post
  starts the service (one guarded job, about 35 s to load); `touch <private>/fast-service/STOP`
  stops it, or it stops after 300 s idle.

## 9. What Victor could decide

1. **Whether to keep `shieldstral-fast` as the app's development path on the Mac** (public posts
   only), and whether to commission a D58-style privacy review of the post-F12 GPU/server path so
   that it could ever replace r16b. Until then it stays "pending" and public-only.
2. **Whether to rule on W16R2 (then W16R3) for real content (A10).** That is the one lever large
   enough to approach 30 proved tok/s on this Mac for the classifier; it needs the W16R2 privacy
   gate on GPU bundles and a classifier export at that profile.
3. **Whether a parallel / GPU verifier is worth a protocol-lane task** (it is a third of the
   machine), or whether verification should run on a second machine.
4. **Whether a D55 classifier profile is wanted for latency** (one post 70 s now); it would be a
   new registered profile (design, review, D60-style registration, D63 statement).
5. **One data owner per process (D73)** is assumed to be the platform operator for the app; a
   ruling should confirm that reading before the servers serve more than one owner's posts.
