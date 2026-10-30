# Token round 18 — A5 one-load batch (`zk60_classify prove-batch`) adopted onto frozen-r17

Lane: Claude token-I/O. Brief: adopt Astra's staged A5 patch onto frozen-r17, apply review fixes 1 and 2 (+ cheap
notes 3, 7, 9, 14), build + full suite, mutants, the byte-identity test (review §4.3), freeze `frozen-r18` UNREVIEWED.
Inputs: `r18/A5_PATCH_REVIEW.md` (READY WITH FIXES), register entry "A5 one-load batch" (rule 3 accepted for ONE post
in ONE process). Astra's candidate `results/zk60_astra_20261026/a5_batch_candidate/` is READ ONLY.

Paths:
- durable tree: `ops/zkp-mvp/token-io-r18/` (hashline/ is the crate)
- tools: `r18/tools/` (freeze18.py = r17's freeze17.py with root/init moved + a `stage` step)
- logs: `r18/logs/`; manifests: `r18/manifest_r18_*.sha256`
- byte-identity scratch (outside git, deleted after): `~/zk60-artifacts/token-io/r18-a5-eq`,
  `~/zk60-owner-private/token-io/r18-a5-eq` (0700)

Times are UTC from `date -u`.

## Ledger

- 22:24 read lane rules (guard 88af4c63, lean-memory rule), resource protocol, the review, the register entry, the
  r17 freeze note and tools, Astra's candidate. Guard status: idle (0 of 11.89 GiB, locks free, no guard process
  waiting). Astra's first real post: no guard process live or waiting (its last log says the waiter was withdrawn
  18:31 and re-queued state is "queued in the app"; nothing in `ps`). Re-check before every heavy step.
- 22:26 **Step A (tree)**: `python3 r18/tools/freeze18.py init` -> 303 files copied from frozen-r17, all re-hashed
  (log `r18/logs/init.log`); init manifest `r18/manifest_r18_init.sha256` = 303 files, list sha256 23a95876… =
  manifest_final_r17 (identical). `freeze18.py stage` (log `r18/logs/stage.log`): frozen-r17's three baseline files
  (and the tree's) = native_sources.json `baseline_sha256` (classify_cli.rs b3b661b5…, private_block.rs 2af1df7d…,
  examples/zk60_classify.rs af8cfd0e…); the five staged files copied and each = `staged_sha256` before and after.
  Staged manifest `r18/manifest_r18_staged.sha256`: 305 files, list sha256 7133cd77…; vs init: changed 3, added 2,
  removed 0. Diff `r18/r18stage_vs_frozen_r17.diff` (5 files).
- 22:35-22:38 **Step E.0 (the FIFO sanity check, review §4.3 step 0), run EARLY** because the harness decides the
  plan. Fixed public blocks written to `~/zk60-artifacts/token-io/r18-a5-eq/ent/{sanity,batch,job0,job1,job2}.bin`
  (block = sha256("a5-eq/" + tag)); harness `r18/tools/run_fixed.sh` (= the review's script byte for byte + one comment
  line). Try 1 with the review's exact command (`open('/dev/urandom','rb').read(32)` twice; no --max-secs) HUNG: Python's
  BUFFERED reader took both 32-byte blocks at the first open, so the second open blocked on the empty FIFO. Ended by
  writing 32 zero bytes into the FIFO (no signal); log `r18/logs/sanity-try1-buffered.log`: line 1 = sha256(a5-eq/s0)
  9e45038f…, line 2 = zeros (the fed bytes), unread 0. So the route works; the review's sanity COMMAND was wrong.
  Try 2, unbuffered (`buffering=0`), `--max-secs 60`: **PASS** (`r18/logs/sanity.log`): 9e45038f… and 5f902759… =
  sha256(a5-eq/s0), sha256(a5-eq/s1); unread_bytes 0; exit 0; bwrap 0.6.1 works inside the guard's systemd scope.
  Skip check (`r18/logs/sanity-skip.log`): one read of two blocks -> unread_bytes 32, exit 97 (the skipped-draw
  detector works). The prover reads its entropy as `File::open("/dev/urandom")` + `read_exact(32)` (unbuffered,
  zkp-core/src/rng.rs:28-47), so each `from_os` takes exactly one block.
- 22:42-22:46 **RED tree** written (copies in `r18/wip/red/`, manifest `r18/manifest_r18_red.sha256` 306 files afdd86fe…):
  Astra's five files + a NEUTRAL test hook only (classify_batch.rs: `struct Spec {profile, tokens, policies}`, production
  `SHIELD_T128` = Astra's constants; `batch_command(args, spec)` / `batch_inner(f, spec)`; the expected plan's overlap
  from `chunk_overlap_of(spec.profile)` (= 8 at T128, so no behaviour change); classify_batch_plan.rs: `check_coverage`
  takes the caller's policy list, production passes POLICIES) + the round's tests (`token_io/classify_r18_tests.rs`, a
  `#[cfg(test)] #[path]` child of classify_batch.rs; s25 `r18_the_census_reads_the_batch_files_through_their_path_lines`)
  + a PLANTED `ZkRng::new` in classify_batch.rs. No Fix 1, no Fix 2, no one-post rule.
- 22:46:57-22:50:14 **RED RUN** (`r18/tools/r18_red.sh`; log `r18/logs/red.log`; guard build, need 2.9 / cap 4.2; 197 s,
  peak RSS 2.32 GiB, cgroup 2.79 [MEASURED, shared box n=1, nothing else live]): exit 101, **17 passed, 3 failed, 1
  ignored — exactly as predicted**:
  * FAIL `r18_a_failed_batch_leaves_no_receipt_statement_or_decommitment_behind`: left `r18f-c0`,
    `r18f-c0.unverified-statement`, `r18f-c0.owner-private` (= REVIEW finding 1 reproduced at the rung);
  * FAIL `r18_the_census_reads_the_batch_files_through_their_path_lines`: classify_batch.rs not scanned (finding 2);
  * PASS `no_profile_on_this_path_can_obtain_a_generator_other_than_from_the_operating_system` WITH the planted
    `ZkRng::new` in classify_batch.rs: **the planted seeded generator went unseen** (finding 2's consequence);
  * FAIL `r18_a_second_post_or_any_repeated_flag_is_refused_before_anything_is_read`: a second `--content-file` gave
    exit 0 (the staged code proved the FIRST content and ignored the second);
  * PASS: the 13 plan tests, the rung batch end to end (2 jobs prove, verify, owner-check, label), the production
    command refusing the rung post, the request reader (symlink / FIFO). So **finding 3 is closed: classify_batch.rs
    compiles, type-checks and runs** (its first compile).
- 22:50-22:56 **GREEN tree** (green batch file staged in `r18/wip/green/classify_batch.rs` first):
  * Fix 1: `BatchClaim` in classify_batch.rs (dirs + per-job reloads; Drop removes dirs latest first with a `removed`
    line each; `keep()` only just before `batch-proved`); `SharedProve.claim: &mut BatchClaim`; in
    `prove_with_public`, after the rename and BEFORE the job's own `claimed.keep()`, a batch job `hold`s [out,
    out.unverified-statement, owner dir] + (seal reloads, prove reloads). `shared = None` (the single prove) runs the
    same lines as before plus one counter read (`seal_blocks.loads`).
  * one post per process: `batch_command` refuses any repeated batch flag (exit 2) before anything is read.
  * note 7: `NOFOLLOW_NONBLOCK` = `Some(0o400000 | 0o4000)` (= 0x20800) on x86-64 Linux only; other targets refuse every
    request at run time (the crate still builds there; no compile_error, so the Mac build is not broken).
  * note 9: `model_loads` / `table_loads` counted where the loads happen; `batch-job-proved` adds `seal_block_loads`,
    `prove_block_loads`, `blocks` (Astra's router reads only index / name there; batch-loaded keeps its field names).
  * note 14: module text of classify_cli.rs, header of examples/zk60_classify.rs, classify_batch.rs module text.
  * note 5 (closed by construction): the expected plan uses `spec.tokens` (checked = the export's T) and the registered
    overlap, the same inputs as the native `chunk_plan`.
  * Fix 2: s25 `production_sources` follows every scanned file's PRODUCTION `#[path]` children (no `cfg(test)` among the
    attributes), transitively, deduplicated; FAIL-CLOSED edge list (5 edges: argument / witness / trained_block ->
    their accuracy children, classify_cli -> classify_batch -> classify_batch_plan); `path_children` + its non-vacuity
    test. hash_domain_tests' label list + classify_cli.rs, classify_batch.rs, classify_batch_plan.rs (36 -> 39) and a
    fail-closed check that every production `#[path]` child of a listed file is listed (4 followed).
  * the round's tests + note 9's test (`batch_inner` returns per-job reloads).
  Tools: `r18/tools/{mutate18.py, r18_chain.sh, r18_common.sh, wait_turn.py}`. Rung entropy
  `~/zk60-artifacts/token-io/r18-a5-eq/ent/rung8.bin` (sha256("a5-eq/rung/"+t) for e0 r0 e1 r1 e0 r0 e1 r1).
- 22:56:47 `r18/tools/r18_chain.sh` launched detached (marker `r18/logs/r18_chain.done`): green (need 6.5 / 7.5) ->
  rung byte-identity harness -> 5 test-killed mutants (fix1-revert, fix2-revert, rng-plant, label-plant,
  one-post-revert; expect 101) -> 2 harness-killed mutants (job-order expect 101, reused-draw expect 97) -> manifest
  pre = post.
- 22:56:47-23:02:07 **green try 1 FAILED on a TEST bug** (logs `r18/logs/try1.green.*`; 320 s, peak RSS 5.58 GiB,
  cgroup 6.58 [MEASURED, shared box n=1]): 148 passed, 1 failed, 23 ignored. The failure:
  `r18_a_second_post_or_any_repeated_flag_is_refused_before_anything_is_read`, case `--label`: the post's arguments
  carry no `--label`, so appending it ONCE is not a repeat; the batch ran (exit 0, the fixture removed it). Every other
  test passed, including Fix 1's control, the census / label scans with the follower, the plan tests. Test fixed (the
  `--label` case gives the flag twice). Chain stopped at `green` as designed.
- 23:02:49 `r18_chain.sh` relaunched (same script). A gate-lane light job (gate22-item3-ts-dev, 1 GiB) was live: allowed
  beside a >= 3 GiB step by the lean rule.
- 23:02:49-23:08:19 **GREEN PASS** (`r18/logs/green.log`): exit 0, **149 passed, 0 failed, 23 ignored** (the focused
  batch). Fix 1's control passes, the census reads the batch files, the planted-free census and label scans pass with
  the follower, the one-post test passes.
- 23:08:19-23:08:27 **RUNG BYTE-IDENTITY UNDER FIXED ENTROPY: PASS** (`r18/logs/rung-eq.log`; the green test binary run
  directly under `r18/tools/run_fixed.sh rung8.bin`, cpu 1.0 / 2.0): exit 0; `fixed-entropy` block_bytes 256,
  **unread_bytes 0** (so each rung proof draws exactly 2 blocks: 2 batch jobs + 2 singles = 8); job 0 and job 1: the
  batch's run directory (3 segment files at L = 1), unverified `statement.json` and `input.dec` equal the single
  prove's byte for byte; the two jobs' receipts differ from each other.
- 23:08:27-23:11:56 mutant fix1-revert: **KILLED** (101; compiled, the fail control ran and found `r18f-c0`,
  `.unverified-statement`, `.owner-private` left; reverted 9efc66e7…).
- 23:11:56-23:21:57 mutants fix2-revert, rng-plant, label-plant: **all KILLED** (101 each; each compiled, its one test
  ran and failed for the named reason; reverted with sha256 checks):
  * fix2-revert -> `r18_the_census_reads_the_batch_files_through_their_path_lines`: classify_batch.rs not scanned;
  * rng-plant -> the generator census: "classify_batch.rs: the path constructs a generator with `ZkRng::new`" (the
    same plant the RED run's unfixed census did NOT see);
  * label-plant -> the absorb-label scan flags classify_batch_plan.rs (it extracted the label `, b`: the scan's `b"`
    search matched the end of the word `absorb"` in my planted line; the kill is real: the file is read now).
- 23:21:57-... the chain WAITS for the gate lane (gate22-item3-ts-rung-values light 1.1, gate22-item3-ts-real-classifier
  cpu 1.5 holding the heavy slot, gate22-gr4-build build 2.7 queued): other lanes go first (wait_turn.py).
- 23:37:21 `r18/tools/r18_queue.sh` launched detached (marker `r18/logs/r18_queue.done`): waits for the chain's
  marker; runs `r18_suite.sh` only if the chain ended 0, then `r18_eq.sh` only if the suite ended 0.
- 23:50 `wait_turn.py` refined (Python, read fresh at each call; the call already waiting keeps the old rule): another
  lane's heavy job (build / cpu / gpu, running or waiting) always goes first; another lane's LIGHT job blocks only our
  steps declaring >= 3 GiB and only if it declares > 1 GiB (the lean rule). Before: any light job > 1 GiB blocked all.
- 00:20 still yielding: gate22-item3-ts-real-block1 (cpu 2.0, max 5400 s, holding the slot since 00:04:38),
  gate22-gr4-build (build 2.7, queued; the gate's GR4 chain also yields to tio18), sol-r14-actual-build-2-recovery-1
  (build 2.6), **pm-classify-seqgen (cpu 1.5: Astra's first real post, PRIORITY)**, two gate light jobs. Design doc
  `classifier/DESIGN_CLASSIFIER.md` v2.8 §19 written (pre-edit copy `r18/DESIGN_CLASSIFIER.v2.7.md` 94b3e537…; README
  pre-edit copy `r18/README.r17.md` 45366a8b…).
- 00:23 COORDINATOR: Astra's first real post resumed (waiting for the heavy lock since 00:17; three categories ~7.5 min
  each plus verify; labels astra-* / pm-classify-*). Do not start the suite (s23) or step E until its three categories
  are done. 00:31:25 **`r18/HOLD` created** (every `turn` / wait_turn.py call honours it, including the waiter already
  running): the remaining mutants, the suite and step E all wait. No job of this lane was running. REMOVE `r18/HOLD`
  only when Astra's completion note is in `docs/zkmatrix-poc/ZK60_SOL_ASTRA_TODOS_20261026.md` or no astra-* /
  pm-classify-* job is running or waiting.
- 00:22-01:44 Astra's first real post ran (guard history: sexual prove 1031 s at 2 threads; violence 456 s and hate
  457 s at 8 threads; each verify ~69 s, input-owner ~67 s, label ~66 s; all exit 0). Astra also changed its app side
  (batch_request.py + batch_cleanup.py: findings 1 / 11 app halves; check-2): the five staged native files still hash
  to `staged_sha256` (= what this round adopted) and `split_unverified_log` / `fresh_check_commands` keep their
  signatures, so step E's commands still apply.
- 01:54:55 **`r18/HOLD` lifted** (moved to `r18/logs/HOLD.lifted-20261030T015455Z`): Astra's three categories are done
  (hate's label exit 0 at 01:43:58) and no astra-* / pm-* job ran or waited for 10 min. The waiter still yields to any
  later Astra job (stored verify, anchor). 01:55 wait_turn.py hardened: only a python process running the guard counts
  (my own watcher loop, whose command line mentioned the guard, had been read as a job "(astra|pm-)").
- 01:56 the gate lane keeps the slot with a series of short jobs (gate22-ts2-real-classifier cpu 1.0, ...); the chain
  starts at the next gap (the gate's GR4 chain also yields to tio18).
- 02:00:38-02:10:24 the rest of the chain, **all KILLED** (`r18/logs/r18_mut.done`: fix1-revert=101 fix2-revert=101
  rng-plant=101 label-plant=101 one-post-revert=101 job-order=101 reused-draw=97; each compiled, `^error[` count 0):
  * one-post-revert -> "a repeated --content-file is refused as a bad argument": left 0, right 2;
  * job-order (the jobs proved in REVERSE order; harness on its own test binary) -> the rung byte-identity test
    FAILS: "job 0: the batch's run directory is not the single prove's byte for byte"; unread 0, rc 101;
  * reused-draw (zkp-core `ZkRng::from_os` reads /dev/urandom once per process and reuses those 32 bytes) -> the
    test itself PASSES (every proof in the process, batch and singles alike, reuses the same key, so the bytes agree)
    but **unread_bytes 224 of 256: the harness exits 97**. So the harness's unread check, not the byte comparison,
    catches a process-wide reuse at the rung; at real scale the singles run in separate processes, so the byte
    comparison would catch it too.
  Tree after the mutants = before (`r18/manifest_r18_postmut.sha256` 306 files 1ca1b2d7…; 0 changed / added / removed).
  `r18_chain.done` = 0.
- 02:10:51 the queue started `r18_suite.sh`: s23 (cpu 9.9 / 11).
- 02:10:51-02:26:32 **SUITE s23 PASS** (`r18/logs/s23-suite.log`, `cargo test --release --offline --locked -j2
  --no-fail-fast -- --test-threads=8`): exit 0, **961 passed, 0 failed, 71 ignored, 29 test binaries** [941 s, peak
  RSS 7.76 GiB, cgroup 7.89, MemAvailable min 5.53; declared 9.9 / cap 11; MEASURED, shared box n=1: gate light jobs
  may have been live]. r17's s22: 940 / 0 / 70. Candidate manifest `r18/manifest_r18A.sha256` = r18B after the suite
  (306 files, list sha256 1ca1b2d7…; 0 changed / added / removed).
- 02:26:32-02:26:49 CLI release build (17 s, 0.44 GiB): `target/release/examples/zk60_classify` sha256
  **110f0c53c56f691c301fe4f47d13afc1ccc9898efbaaf8506f1e0d5cde5f4496**, copied to
  `~/zk60-artifacts/token-io/r18-a5-eq/bin/zk60_classify.r18-candidate` (= the bytes step E runs; `r18/logs/b18-cand.sha256`);
  differs from r17's 81bd8624… (`b18-vs-r17.cmp`; the production code moved).
- 02:26:49 the queue started `r18_eq.sh` (step E): pins OK (r16b dfb8025e…, the candidate); prepare `3 17` (Astra's
  updated helper also writes `cleanup-scope.json`); 02:26:51 activations running.
- 02:27:52 the batch (`tio18-a5-batch`, cpu 10.4 / 11.5, fixed entropy) started.

## Crash and resume (2026-10-30)

- ~02:50 **THE LAPTOP CRASHED** during step E's batch [READ: coordinator's brief]. Cause per the coordinator: Windows
  drive C: full (it holds the WSL disk file and the page file), not Linux memory (MemAvailable 5.3 GiB). New rule D46
  (guard `67e9478f…`: heavy jobs wait under 40 GiB free on C:, any job killed under 8 GiB; delete test-only receipts
  after use, clean `*.incomplete`, announce jobs writing > 10 GB). Lane rules addendum 2026-10-30 05:20 read.
- What step E had done before the crash [READ from `r18/logs/eq/` and the scratch dirs; times UTC = file mtime PDT + 7]:
  pins OK (`eq/pins.log`), prepare printed `3 17`, activations exit 0 (26 layers x 3 items, 60.9 s, 02:27:52); the
  batch's log `eq/batch.log` is cut at exactly 8192 bytes (02:49:41): `batch-loaded` (jobs 3, model_loads 1,
  table_loads 1, load_seconds 42.862), **job c0 proved** (28 segments, receipt_bytes 848412096, prove 374.016 s, total
  460.532 s, verdict not-flagged, floor 96 bits; seal_block_loads 26, prove_block_loads 52), **job c1 proved** (28
  segments, 848412096 B, prove 371.001 s, total 457.564 s, not-flagged), job c2 at segment 17 in the log [MEASURED, n=1,
  shared box; partial run, not a step E result]. No batch guard JSON, no `batch.exit`, no
  `r18_eq.done`, no `r18_eq.sh.done`, no `r18_queue.done`. Nothing of this lane runs now.
- Left on disk [READ]: `batch/a5eq-c0` and `a5eq-c1` (848416192 B each) + their `.unverified-statement` (5181 /
  5186 B); **`batch/a5eq-c2.incomplete` STILL EXISTS** (19 segments 000-018, 585522600 B, last 02:49:40; the brief said
  it was gone) + an EMPTY `a5eq-c2.unverified-statement`; owner side `batch/owners/c0`, `c1` (input.dec 90144 B each),
  `c2` (empty), `activations/` (122725421 B), the five prepare files; a stale FIFO `ent/fifo.48fuWt` from the killed
  `run_fixed.sh`. Single / r16b / fail dirs empty.
- 05:22-05:25 **integrity after the crash** [MEASURED]: tree re-hashed (`r18/manifest_r18_postcrash.sha256`, log
  `logs/postcrash-manifest.log`): 306 files, list sha256 1ca1b2d7… = manifest_r18A; 0 changed / added / removed.
  `sha256sum -c logs/b18-cand.sha256`: the tree's target binary, the candidate copy (110f0c53…), r17 (81bd8624…) and
  **r16b (dfb8025e…) all OK**. Manifest files r18A / r18B / postmut each hash 1ca1b2d7…. No zero-byte file in the tree,
  r18/, cli/, ent/, bin/. Entropy files = sha256("a5-eq/"+tag) blocks (sanity, batch, job0-2, rung8 all True). Every
  r18 tool parses (`bash -n`, Python `ast`). Astra's five staged files still = `staged_sha256`. Guard live =
  67e9478f…; status: Sol `sol-r14-corrected-dense-reference-1` (cpu 1.4) holds the heavy slot; C: 134.7 GiB free.
  Integrity PASSES: nothing to stop for.
- 05:25 pre-crash step-E logs moved to `r18/logs/eq.crash-20261030/` (the guard APPENDS to `--log`; the router reads
  every `{"event"` line of `eq/batch.log`, so a rerun must not append to the cut log). Before deleting, the two batch
  jobs that finished were hashed (`r18/tools/precrash_digests.py` -> `eq.crash-20261030/precrash_digests.json`: c0 and
  c1, 28 receipt files + statement + input.dec each), for a supplementary cross-run check against the rerun's batch
  digests (same fixed public entropy, a separate process after a reboot; not a 4.4 pass criterion).
- 05:26 **cleanup of the pre-crash outputs** (record `eq.crash-20261030/precrash_cleanup.json`) [MEASURED]: removed
  `EQ/batch` (77 files, 2282353063 B: c0, c1, their statements, `a5eq-c2.incomplete`, the empty c2 statement),
  `EQ/{single,r16b,fail}` (empty), `OWN/batch` (165 files, 122892747 B: content.ids, the requests, prepared.json,
  cleanup-scope.json, activations, owners c0-c2), `OWN/{fail,single-owner,r16b-owner}` (empty dirs), the stale FIFO
  `ent/fifo.48fuWt`; total 2405245810 B. Kept: `EQ/ent/` (the six entropy files), `EQ/bin/` (the candidate), the empty
  `EQ/logs/`. `OWN/` itself (0700) is empty. A fresh `r18_eq.sh` recreates every dir (`mkdir -p`); Astra's prepare
  refuses an existing job dir or any receipt path (`''`, `.incomplete`, `.unverified-statement`), so this was required.
  Disk for the rerun [COUNTED]: 7 receipts of 848412096 B (3 batch, 3 single, 1 r16b) = 5.94 GB + the fail control's
  transient job 0 (0.85 GB, removed by the batch) ~= 6.8 GB peak, under the 10 GB announcement threshold.
- 05:26:37 **step E relaunched from the start**, detached exactly as before (`setsid nohup bash -c 'bash
  r18/tools/r18_eq.sh; echo $? > logs/r18_eq.sh.done'`; marker `logs/r18_eq.done`; queue not re-run: chain and suite
  are done). Pins OK, prepare `3 17` again (05:26:37); 05:26:38 waiting its turn (`astra-gpu-benchmark-l06` gpu 2.8,
  `sol-r14-corrected-dense-reference-1` cpu 1.4).
- 05:41:09-05:42:08 activations (rerun): exit 0, child_rc 0, 59.4 s, peak RSS 0.71 GiB, cgroup 3.0 (cap 3; page
  cache) [MEASURED, shared box n=1]. 05:42:08 the batch waits for `astra-gpu-benchmark-l06` (gpu 2.8).
- 05:52:11 the batch (`tio18-a5-batch`, cpu 10.4 / 11.5, fixed entropy 192 B) started; a gate light job
  (`gate23-c9-real-block0-ts1`, 1 GiB) live beside it (allowed by the lean rule). C: 132.8 GiB free.
- 05:52:11-06:15:50 **BATCH PASS** (`r18/logs/eq/batch.log`, `batch.guard.json`) [MEASURED, shared box n=1: a 1 GiB gate
  light job was live]: guard exit 0, child_rc 0, wall 1418.4 s, peak RSS 8.16 GiB, cgroup 11.2 (incl. page cache),
  MemAvailable min 5.3. `batch-loaded` jobs 3, model_loads 1, table_loads 1, load_seconds 45.296; c0 sexual prove
  372.581 s / total 460.905 s; c1 violence 373.025 / 461.616; c2 hate 365.671 / 450.493; each 28 segments, 848412096 B,
  not-flagged, floor 96 bits, seal_block_loads 26, prove_block_loads 52; `batch-proved` jobs 3, total 1418.343 s,
  verified false; **fixed-entropy block_bytes 192, unread_bytes 0, rc 0**. 06:15:50 the singles wait for Sol
  (`sol-r14-native-capture-dd-3`, cpu 8.0).
- 06:17:50-06:25:54 single c0 (candidate, sexual): exit 0, child_rc 0, wall 483.8 s, prove 368.158 s, total 483.613 s,
  28 segments, 848412096 B, not-flagged; fixed-entropy 64 B, unread 0; peak RSS 8.21, cgroup 8.77 [MEASURED, n=1].
  06:25:54 c1 waits for Sol (`sol-r14-l25-non-dd-prove-2`, cpu 9.6).
- 06:25-08:21 c1 STARVED: the waiter gave way to every other lane's heavy job and Sol's back-to-back R14 regression
  chain plus the release prep (`irpub-*`) kept the queue full (queue.log 08:21:31: `sol-r14-cli-1-non-dd-prove`,
  `sol-r14-regression-dd-limb-q-whole-1`, ...).
- ~08:20 **COORDINATOR RULE CHANGE**: give way ONLY to Astra's app jobs (labels `astra*` / `pm-*`), not to Sol
  (`sol-*`) nor the release prep (`irpub-*`); otherwise take the heavy slot through the guard's normal admission as
  soon as the heavy lock is free; the lean-memory rule (a 10.4 GiB proof runs alone) is enforced by the guard. Do not
  restart anything running. 08:23 `r18/tools/wait_turn.py` edited accordingly (docstring keeps the old rule; `blocking`
  = Astra's app jobs only, any class, running or waiting; the waiter's own `live_big` lean check dropped; holds kept;
  `--need` still accepted). Test call (scratch log, `--need 10.4`) returned rc 0 at once (no Astra job live).
  **Limit**: the call already waiting for single-c1 (pid 50375, started 06:25:54, `--need 10.4`) loaded the OLD rule
  and is not restarted (no signals: lane rule 6 and the coordinator's "don't restart"); it returns at the next gap in
  other lanes' heavy queue. Every later `turn` (c2, r16b, each fresh check via fresh_checks.py, the fail control)
  uses the new rule. Reported to the coordinator.
- 08:24 COORDINATOR: will not end pid 50375 (the session's safety check refused the signal); asked Sol in the
  coordination file (08:24) to pause new heavy launches after its current leaf until a `tio18-a5-*` job is live, so
  the old waiter returns at that gap. This lane signals nothing; it keeps waiting on the `.done` markers.
- 08:25:02 the old waiter returned (Sol's gap); single c1 (candidate, violence) started.
- 08:25:02-08:33:11 single c1: exit 0, child_rc 0, wall 488.8 s, prove 367.697 s, total 488.689 s, 28 segments,
  848412096 B, not-flagged; fixed-entropy 64 B, unread 0; peak RSS 8.13, cgroup 11.04 [MEASURED, n=1]. 08:33:11
  single c2 started at once (new waiter rule).
- 08:33:11-08:41:12 single c2 (hate): exit 0, child_rc 0, wall 480.9 s, prove 367.494 s, total 480.779 s, 28
  segments, 848412096 B, not-flagged; fixed-entropy 64 B, unread 0; peak RSS 8.16, cgroup 8.87 [MEASURED, n=1].
  08:41:12 the r16b control (job 0, binary dfb8025e…) started.
- 08:41:12-08:49:18 r16b control c0: exit 0, child_rc 0, wall 486.2 s, prove 370.510 s, total 486.084 s, 28 segments,
  848412096 B, not-flagged; fixed-entropy 64 B, unread 0; peak RSS 8.19, cgroup 9.4 [MEASURED, n=1].
- 08:49:18-08:49:25 **COMPARE PASS** (`eq/compare.log`, exit 0; digests `eq/digests.json` sha256 2f173f1d…):
  `ok: true`; job 0, 1, 2: batch = single byte for byte (30 files each: 28 receipt segments, the unverified
  statement.json, the owner's input.dec); **r16b's job 0 = the candidate's single job 0**. Per-job tree digest
  (sha256 of the sorted `digest  part/file` lines) [MEASURED]: c0 c66ef77e… (statement.json e61cf348…, input.dec
  bea8e58d…), c1 fce60d33… (3d670867…, 8be7af37…), c2 8206cc36… (5c701542…, 5f65c4b9…); batch, single and (c0) r16b
  all equal; the three jobs differ from each other.
- 08:50 **cross-run check PASS** (`eq/crossrun_precrash_vs_rerun.json`): the pre-crash batch's c0 and c1 (02:36 /
  02:43, previous boot) = the rerun batch's c0 and c1 byte for byte (receipt, statement, owner; 30 files each). Same
  fixed public entropy, two processes, two boots: deterministic given the entropy; also shows the crash did not damage
  those files. Supplementary, not a 4.4 criterion.
- 08:49:25 **ROUTER PASS**: Astra's `split_unverified_log` on the batch log (fixed-entropy line removed) returned
  `unverified` (`eq/router.log`). 08:49:25 the fresh checks started (`fresh_checks.py run`, new waiter rule).
- 08:49:25-09:04:41 **FRESH CHECKS PASS** (`eq/fresh_result.json`, each its own fresh process through the guard, the
  reviewed r16b binary, the verifier export): c0/c1/c2 verify exit 0 (`classified` not-flagged, identity 29aeba6c…),
  c0/c1/c2 input-owner exit 0 (`content-checked` content_total 17, range [0, 17]), sexual / violence / hate label exit
  0 (`--expect-total 17`; label not-flagged, chunks 1, flagged_ranges []); 72.2-75.8 s and 2.25-2.31 GiB peak RSS
  each [MEASURED, n=1].
- 09:04:41-09:12:54 **FAIL-CLOSED CONTROL PASS** (`eq/fail.log`, `eq/fail_check.json`; normal entropy; job 1's
  activations empty): child_rc 1, wall 492.8 s, peak RSS 8.22; events: job 0 `proved`, `batch-job-proved`, job 1
  `loaded`, six `removed` (c1's owner / statement / `.incomplete`, then c0's owner / statement / run), `refused`
  ("the prover-private sequence files of layer 0 ... missing or fail their dtype / shape / SHA-256 check"; no digest
  printed, K-2), `app-outcome` flagged ("no accepted proof: fail-closed (ruling D45(4))"); no `batch-proved`, no
  REMOVAL-FAILED; nothing left in either fail directory. 09:12:54 **`logs/r18_eq.done` = 0** (`r18_eq.sh.done` 0).
- 09:13 `eq_summary.py` -> `eq/summary.json`: batch wall 1418.4 s vs the three singles 1453.4 s, saved 35.0 s (2.4 %)
  [MEASURED, n=1, shared box]; batch load once 45.3 s (model_loads 1, table_loads 1).
- 09:13:40 **CLEANUP** (`eq_cleanup.py` -> `eq/cleanup.json`) [MEASURED]: removed `EQ/batch` (87 files, 2545251995 B),
  `EQ/single` (87, 2545251869 B), `EQ/r16b` (29, 848417277 B), `EQ/fail` (0), the whole owner tree
  `~/zk60-owner-private/token-io/r18-a5-eq` (171 files, 123344592 B: content, requests, activations, every owner dir);
  total 6062265733 B. Left in EQ: `bin/` (the candidate, removed after the freeze), `ent/` (six public entropy files),
  the empty `logs/`. Kept under results: every log, guard JSON, compare output, `digests.json`.
- 09:13:51 `r18/tools/r18_freeze.sh` launched detached (marker `logs/r18_freeze.done`; `r18_freeze.sh.done`).
- 09:13:51-09:17:26 **FREEZE PASS** (`logs/r18_freeze.done` = 0): candidate pin OK (`freeze-pins.log`); xbin (rung
  receipts cross-verify r18 candidate <-> r16b dfb8025e… both ways, 1 passed, 9.3 s; `xbin-r18-r16b.log`); the REAL
  moderate-hate receipt (r16-runs/hate-run, made by e94cecf9…) re-verified by the candidate in a fresh process (exit 0,
  75.0 s, 2.3 GiB; published statement re-checked byte for byte, identity 29aeba6c…, not-flagged, floor 96, input root
  4cf9e8ae… = round 16's; `verify-hate.log`); final-check manifest = r18A (0 / 0 / 0); **`frozen-r18/`** = 306 files
  re-hashed, match, none missing / extra (20734597 B; no target/); **`manifest_final_r18.sha256`** = r18A (list sha256
  1ca1b2d7…); `cli/zk60_classify.r18.release.bin` 110f0c53… (`cli/binaries_r18.sha256`; cmp = the candidate);
  vs frozen-r17: 5 changed + 3 added (`r18/r18A_vs_frozen_r17.txt`, `.diff` 1084 lines).
- 09:18-09:19 the candidate copy `EQ/bin/zk60_classify.r18-candidate` removed after `cmp` = cli's r18 binary (per the
  plan); `~/zk60-artifacts/token-io/r18-a5-eq` now holds only `ent/` (6 public entropy files) and two empty dirs (17 KB).
  Hand-written notes: `frozen-r18.FROZEN.txt`, `cli/zk60_classify.r18.BUILD.txt`. Nothing of this lane runs.
- **Round 18 state: frozen-r18 UNREVIEWED.** Next: the coordinator integrates and routes a review of round 18 (the gate
  lane reads whether its capture pins move: classify_cli.rs and private_block.rs changed).
