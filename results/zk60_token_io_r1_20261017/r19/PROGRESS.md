# Token round 19 — REVIEW_R18's low fixes (R18-2, R18-3, R18-4) and the open release's E7 (checkpoint path) on frozen-r18

Lane: Claude token-I/O. Brief (coordinator, 2026-10-30): a small round on `frozen-r18`.
1. R18-2: the census scans' module follower fails closed on every module-line shape (failing-first fixture tests, one
   draw-hiding mutant per shape, each killed).
2. R18-3: the records (reload count 78 per job = 26 + 52 in `classify_r18_tests.rs`; a "limits of the byte-identity
   test" paragraph in the round-18 freeze note and the ledger).
3. R18-4: `classify_batch.rs` module text on refusals (argument refusals print no fail-closed line).
4. E7: `derive.rs` `DEFAULT_CHECKPOINT` -> `default_checkpoint()` (`$ZK60_MODELS/...` else `$HOME/models/...`; a
   declared `checkpoint_file` keeps precedence; no new `Sha256::new(`, no absorb label; unset on this box = today's).
5. Full suite (guard cpu, need 11 / cap 12), mutants as round 18, release build, real moderate-hate re-verify +
   rung cross-verify both ways against r18, receipt bytes unchanged.
6. Freeze `frozen-r19` (manifest + build note, round-18 form). 7. List the gate pins that move (no gate edits).

Inputs: `results/zk60_token_io_review_r1_20261017/REVIEW_R18.md` (ACCEPTED WITH FIXES), register entries "Token round 18
frozen" / "Token round 18 review", D46, D48; `results/zk60_open_release_20261030/prep/E2_NOTES.md` (derive.rs, E7).

Paths:
- durable tree: `ops/zkp-mvp/token-io-r19/` (hashline/ is the crate); init = frozen-r18 without target/
- tools: `r19/tools/` (freeze19.py = freeze18.py re-rooted, `stage`/`patch` dropped, `save` added)
- logs: `r19/logs/`; manifests: `r19/manifest_r19_*.sha256`; state copies: `r19/wip/{red,green}/`

Times are UTC from `date -u`. Labels: [MEASURED] a run happened (shared box, n=1), [COUNTED] exact arithmetic, [READ].

## Ledger

- 09:40 read CLAUDE.md, lane rules + addenda (D46 host-drive floor), resource protocol S9, REVIEW_R18, the register's
  round-18 entries and D48, r18/PROGRESS.md and r18 tools, E2_NOTES (E7). Guard status 09:45: 1.0 of 11.89 GiB
  (gate light job `gate23-c9b-real-block0-ts1`), heavy lock free, C: 121 GiB free.
- 09:51:39 **tree** `ops/zkp-mvp/token-io-r19/`: `freeze19.py init` copied exactly manifest_final_r18's 306 files from
  frozen-r18 (no target/), all re-hashed (`logs/init.log`); `manifest_r19_init.sha256` = 306 files, list sha256
  1ca1b2d7… = manifest_final_r18 (identical). 21 MB.
- 09:52-10:00 **RED tree** (failing first; copies `r19/wip/red/` with SOURCES.sha256; manifest `manifest_r19_red.sha256`
  306 files 68e953ea…, vs init: changed 2 = s25_tests.rs, tied_tables/derive.rs):
  * s25_tests.rs: `ModuleGraph`; RED `module_graph` / `module_children` = ROUND 18's reader behind the new interface
    (private_block.rs's `mod` / `pub mod` lines, one level of plain children with a missing file skipped, then
    `path_children` transitively); a `ModTree` fixture helper (public text, under HL_TIO_FIXTURE_DIR); two new tests:
    `r19_the_module_follower_finds_every_module_line_shape` (13 cases, each its own fixture tree: 3 controls, the 4
    shapes REVIEW_R18 §5 measured — one-line `#[path] mod`, a comment between `#[path]` and `mod`, `pub(in …)`,
    `pub(self)` — a plain `mod` in a module's own child (the token-io grandchild), a `mod.rs` file, a `#[path]` file's
    plain child (a sibling, rustc's rule), the `;` on the next line, `pub(crate) mod` in the root) and
    `r19_the_module_follower_fails_on_every_module_line_it_cannot_classify` (12 cases: `cfg_attr` path, a non-literal
    path, two paths, a file module in a function / a production inline module, a macro's `$v mod $n;`, no file, no
    `#[path]` file, two files, a `..` path, an unterminated comment, an unclosed brace: each must be an error naming
    m.rs).
  * derive.rs (E7): RED `default_checkpoint_from` = round 18's constant whatever the environment;
    `default_checkpoint`, `checkpoint_path_with` (declared `checkpoint_file` first, as round 18) wired at the one use;
    three tests: both branches (`r19_the_default_checkpoint_is_under_zk60_models_when_set_else_under_home_models`),
    precedence (`r19_a_declared_checkpoint_file_keeps_precedence_over_the_default`), unset on this box = round 18's
    path (`r19_with_zk60_models_unset_on_this_box_the_default_is_round_18s_path`).
- 10:00:40 `r19/tools/r19_red.sh` launched detached (marker `logs/r19_red.done`; guard build 2.9 / 4.2, label
  tio19-red). Predicted: exit 101; FAIL the two follower tests and the default-checkpoint test; PASS precedence and
  unset-on-this-box (both already true in round 18). It waits for the heavy lock (Sol's `sol-r14-final-suite-1`).
- 10:01-10:11 while it waits, the GREEN files are STAGED in `r19/wip/green/` (the tree is not touched while a cargo job
  of it is queued):
  * s25_tests.rs: the real follower — `rust_tokens` (comments dropped; string, raw, byte and C strings one token; char
    literals and lifetimes opaque), `mod_items` (every `mod` item from tokens, any visibility, attributes in any order,
    comments anywhere; FAIL-CLOSED on every item it cannot classify), `module_children` (rustc's resolution: `#[path]`
    beside the file; plain children under `<stem>/` or, in a mod-rs or `#[path]`-loaded file, beside it; an error for
    a missing / ambiguous file or a path leaving the directory), `module_graph` (transitive, one kind per file);
    `production_sources` = the graph from private_block.rs + private_seam.rs, asserting the COMPLETE edge list (45
    edges: 28 + 11 + 6) and 47 files (= round 18's set, checked by a Python mirror of the follower:
    `scratchpad/mirror.py`, new-only [] / old-only []); `path_children` removed; round 18's non-vacuity test now over
    `mod_items`.
  * hash_domain_tests.rs: the label lane 39 -> 47 files (+ mvp_driver, rope, timing, trained_block, trained_statement,
    token_io/classify_tied, token_io/cli, token_io/load: plain children of listed files it never read; each mentions
    `absorb` in comments only); every production module (plain or `#[path]`, any shape) of a listed file must be
    listed, except hash_domain.rs (checked separately to make no absorb); followed 4 -> 45.
  * derive.rs: `CHECKPOINT_IN_MODELS`; `default_checkpoint()` = `$ZK60_MODELS/<…>` when set and non-empty, else
    `$HOME/models/<…>`, else refused; production text: Sha256::new( count 5 (unchanged), no absorb, no owner path.
  * classify_r18_tests.rs (R18-3): the reload text says (L, 2L) per job, 78 at L = 26, (1, 1) at the rung because of
    the reader's one-block cache. classify_batch.rs (R18-4): an argument refusal (exit 2) prints no fail-closed line.
- 10:08-10:11 tools: `mutate19.py` (20 mutants: round 18's 7 on the r19 tree, fix2-revert re-targeted at the new
  follower; 10 R18-2 `hide-<shape>-{u,l}`: a seeded generator in a new file behind each of the five shapes, u =
  production change only, l = also listed in the census's edge list; 3 E7), `mutcheck.py` (a kill counts only if it
  compiled, exit 101, every named test FAILED and every named reason is in the log), `r19_chain.sh`, `r19_suite.sh`
  (cpu need 11 / cap 12), `r19_check.sh` (xbin vs r18; the real receipt verified with ZK60_MODELS unset / =
  /home/victor/models / = a missing dir (must refuse), hashed before and after; the job-0 receipt bytes at real scale
  vs round 18's digests), `r19_freeze.sh`, `r19_queue.sh`, `treehash.py`, `compare19.py`, `cleanup19.py`,
  `wait_turn.py` (gives way to astra* / pm-* only). Entropy: rung8.bin and job0.bin copied to
  `~/zk60-artifacts/token-io/r19/ent/` (= round 18's, and = their sha256 recipes; `logs/ent.sha256`).
- 10:11 R18-3 records written (main ledger section; dated insertion in `frozen-r18.FROZEN.txt`).
- 10:17:55 the RED job (tio19-red) started (the heavy lock freed after Sol's final-build); compiling from a clean target/.
- 10:17:55-10:21:19 **RED RUN** (`logs/red.log`, `red.guard.json`; guard build 2.9 / 4.2, waited 1022 s for the heavy
  lock, child 216.9 s incl. the clean build, peak RSS 2.3 GiB [MEASURED, shared box n=1]): exit 101, **2 passed, 3
  failed — exactly as predicted**:
  * FAIL `r19_the_module_follower_finds_every_module_line_shape`: round 18's reader gets 10 of 13 shapes wrong —
    MISSED the one-line `#[path] mod`, a line comment and a doc + block comment between `#[path]` and `mod`,
    `pub(in …)`, `pub(self)`, the plain `mod` in a module's own child (the token-io grandchild), a `mod.rs` file, a
    `#[path]` file's plain child, the `;` on the next line, `pub(crate) mod` in the root; the 3 controls pass (so the
    RED adapter reads what round 18 read);
  * FAIL `r19_the_module_follower_fails_on_every_module_line_it_cannot_classify`: 12 of 12 — 10 NOT REFUSED (a graph
    returned, silently without the module or with a wrong file: `cfg_attr` path, two paths, a module in a function /
    a production inline module, a macro's module, no file, two files, a `..` path, an unterminated comment, an
    unclosed brace) and 2 refused only by accident without naming m.rs (a non-literal path and a missing `#[path]`
    file: a read error of a made-up path, round 18's `source()` panic);
  * FAIL `r19_the_default_checkpoint_is_under_zk60_models_when_set_else_under_home_models` (left = round 18's
    /home/victor/models/… constant, right = /srv/zk60-models/…);
  * PASS precedence and unset-on-this-box (already true in round 18).
- 10:21:38-10:22 **GREEN tree**: the five staged files copied in (`wip-green.list`; `wip/green/SOURCES.sha256`:
  s25_tests.rs 4849de14…, derive.rs 4b53222b…, hash_domain_tests.rs a61f14bb…, classify_r18_tests.rs bc169eeb…,
  classify_batch.rs 707c8db2…); manifest `manifest_r19_green_src.sha256` 306 files 91585afe…, vs init: changed 5,
  added 0, removed 0. Dry run of all 20 mutants (apply + revert, no build; `logs/mut-dryrun.log`): each applies and
  reverts; tree after = before (0 / 0 / 0); dry-run records moved to `r19/mutants-dryrun/`.
- 10:22:56 `r19/tools/r19_queue.sh` launched detached (marker `logs/r19_queue.done`): chain (green, rung harness, 20
  mutants) -> suite (s24, cpu 11 / 12; CLI release build) -> checks (xbin vs r18, the real receipt x3, the job-0 bytes)
  -> freeze; each only after the previous ended 0.
- 10:22:55-10:28:36 **GREEN PASS** (`logs/green.log`; first compile, no fix needed): exit 0, **158 passed, 0 failed, 24
  ignored** (the focused batch + tied_tables; r18's green 149 / 0 / 23) [341 s, peak RSS 5.98 GiB, cgroup 6.16;
  MEASURED, shared box n=1]. All five r19 tests pass; the census tests (generator census, W-11 call sites, the r18
  census test) and the label scan pass over the module graph (47 files, 45 edges, = round 18's file set). Warnings: 28,
  as round 18's green; none in a round-19 file.
- 10:28:36-10:28:44 **RUNG BYTE-IDENTITY under fixed entropy: PASS** (`logs/rung-eq.log`; round 18's ignored test and
  run_fixed.sh on the green binary): exit 0, block_bytes 256, unread_bytes 0. 10:28:44 the mutants started.
- 10:32:37 **TOOL BUG (mine), caught on the first mutant:** mutcheck.py's "compiled" test counted cargo's own
  `error: test failed, to rerun pass --lib` (printed after ANY failing test) as a compile error, so it judged
  fix1-revert "not killed as named" although its test FAILED for the named reason ("A FAILED BATCH LEFT RUN /
  STATEMENT / OWNER DIRECTORIES BEHIND"). Fixed at 10:33 (a compile error = `error[E…]` or "could not compile"; the
  running chain script is not edited, it calls mutcheck.py afresh per mutant). Consequence: the chain's own verdict
  line keeps fix1-revert's wrong verdict, so the chain will end "mutations" and r19_queue.sh will stop there.
  Plan: `tools/rejudge19.sh` (the chain's TEST / WHY maps copied verbatim) re-judges every mutant from its log with
  the fixed checker; if all are killed as named and the tree check passed, `tools/r19_queue2.sh` runs suite ->
  checks -> freeze.
- 10:28:44-11:38 **MUTANTS: ALL 20 KILLED AS NAMED** (`logs/mut-*.log`; the chain's verdicts `logs/r19_mut.done` /
  `r19_mut.jsonl`, re-judged with the fixed checker: `logs/rejudge.log` = ALL-KILLED-AS-NAMED,
  `r19_mut_rejudged.done` / `.jsonl`). Each test-killed mutant compiled (no `error[`), exited 101, every named test
  FAILED and every named reason is in its log:
  * round 18's set on the r19 tree: fix1-revert ("A FAILED BATCH LEFT RUN / STATEMENT / OWNER DIRECTORIES BEHIND"),
    fix2-revert (re-targeted: the follower drops every `#[path]` child -> "the production module graph of the path
    moved"), rng-plant ("classify_batch.rs: the path constructs a generator with `ZkRng::new`"), label-plant
    ("classify_batch_plan.rs absorbs"), one-post-revert ("a repeated --content-file is refused as a bad argument"),
    job-order (harness, rc 101: "job 0: the batch's run directory is not the single prove's byte for byte"; unread 0),
    reused-draw (harness exit 97: the test passes, unread_bytes 224 of 256);
  * E7: e7-ignore-models ("ZK60_MODELS set: the checkpoint is under it"), e7-empty-is-set ("ZK60_MODELS set but EMPTY
    counts as unset"), e7-precedence ("a declared checkpoint_file wins over ZK60_MODELS");
  * **R18-2, a seeded generator behind each shape** (oneline, comment, pubin, pubself, grandchild):
    `hide-<shape>-u` (production change only) — BOTH the generator census ("the production module graph of the path
    moved") AND the label scan ("declares the production module src/private_block/token_io/…r19_plant.rs, which this
    label scan does not read") fail; `hide-<shape>-l` (the edge also listed, file count 48) — the census itself finds
    it: "src/private_block/token_io/[classify_cli/]r19_plant.rs: the path constructs a generator with `ZkRng::new`".
  20 mutant builds 187-215 s each, peak RSS <= 2.38 GiB, cgroup <= 2.41 [MEASURED, shared box n=1]. Tree after the mutants = before (`manifest_r19_postmut.sha256` vs premut:
  0 / 0 / 0). `r19_chain.done` = "mutations" ONLY because of the checker bug of 10:32 (fix1-revert's line); so
  r19_queue.sh stopped (`r19_queue.done` "chain mutations").
- 11:39:08 `r19/tools/r19_queue2.sh` launched detached (marker `logs/r19_queue2.done`): it checks rejudge.log, then
  suite -> checks -> freeze. Sol's `sol-r14-final-relation-non-dd-limb-ym-narrow-1` (cpu 7.5) holds the heavy slot.
- 11:39-11:54:38 **SUITE s24 PASS** (`logs/s24-suite.log`, `cargo test --release --offline --locked -j2 --no-fail-fast
  -- --test-threads=8`, guard cpu need 11 / cap 12 as the brief): exit 0, **966 passed, 0 failed, 71 ignored, 29 test
  binaries** (s23 / r18: 961 / 0 / 71; +5 = the round's five tests) [885 s after 45 s of waiting, peak RSS 7.78 GiB,
  cgroup 8.13; MEASURED, shared box n=1]. Manifest r19A = r19B (306 files, 91585afe…; 0 / 0 / 0).
- 11:54:38-11:56:47 CLI release build (14 s, 0.44 GiB): `target/release/examples/zk60_classify` sha256
  **841ba983cebaae65bbae6289d71f740d44c137fdc6cc98ed46410f2d33a09fd8**, copied to
  `~/zk60-artifacts/token-io/r19/bin/zk60_classify.r19-candidate` (`logs/b19-cand.sha256`); differs from r18's 110f0c53…
  (`b19-vs-r18.cmp`: derive.rs and classify_batch.rs's doc moved, and the tree path is baked in).
- 11:56:47-11:56:57 **RUNG CROSS-VERIFY, BOTH WAYS: PASS** (`logs/xbin-r19-r18.log`; round 15's two-binary test with
  HL_PB_CLI_BIN = the r19 candidate, HL_PB_CLI_BIN_OTHER = r18's 110f0c53…): the 23-id and 22-id items proved by r19
  verify with r18 (exit 0) and proved by r18 verify with r19 (exit 0); 1 passed. 11:56:57 the real receipt's first
  verify (ZK60_MODELS unset) started.
- 11:58 **item 7, the gate pins that move r18 -> r19** (`tools/pins_r18_r19.py` -> `logs/pins_r18_r19.json`; read only,
  no gate file edited) [MEASURED, the r19 tree = manifest r19A]:
  * of the capture writer's 72 source pins (OWN 38 + SHARED 29 + CLASSIFY 5, parsed from run_capture.rs; lists equal in
    both trees) exactly ONE moves: `src/private_block/tied_tables/derive.rs` (OWN_SOURCE_FILES)
    c5bec3c676e635aab1c609fdf2f541d003e14d7a50efc36d0fed42fc85b7d981 -> 4b53222b37820936821eea2fd506ff3dee991e2474d39a3b21f1c0c10d357d75.
    None of the other four changed files (s25_tests.rs, hash_domain_tests.rs, classify_r18_tests.rs, classify_batch.rs)
    is a capture pin.
  * the gate's v23 source-pin table (`ops/zkp-mvp/gate-tinyllama/{scripts,frozen_v23,staging_v23}/scripts/
    zk60_native_rg_r13_pins.py`, sha256 99418fb3… in all three): `DERIVE_T16` (line 195, used in TOKEN_R16B_DIGESTS
    line 230 and the chain entry line 482) = c5bec3c6… = r18's derive.rs; r19's is 4b53222b…. Of its 18 explicit
    entries this is the only one that moves r18 -> r19 (two others, private_block.rs and run_capture.rs, already
    differ at r18: the known r16b -> r17 / r17 -> r18 moves, re-pin owed since round 18).
  * `zk60_native_rg_classtied.py` (bf929b44… in scripts/, frozen_v22, frozen_v23, staging_v22, staging_v23):
    `SHIELD_DEFAULT_CHECKPOINT` (line 334, used at line 414 `decl.get("checkpoint_file") or …`) = the r18 constant;
    on this box (ZK60_MODELS unset, HOME=/home/victor) it still equals r19's resolved default, so nothing breaks here,
    but the mirror of the override (ZK60_MODELS, else $HOME/models) is the gate's. Its v22 reading notes derive.rs
    line ranges (DEFAULT_CHECKPOINT :5-10, Checkpoint::open :121-160, rotate :163-178, quantize :180-187,
    recompute_profile :227-276): in r19 the constant's line 10 became lines 10-48 and the call (244-245) became
    282-283, so every later range shifts by +38; the arithmetic and the authentication are unchanged.
- 11:56:57-12:01:59 **THE REAL MODERATE-HATE RECEIPT, three fresh processes with the r19 candidate** (r16-runs/hate-run,
  made by e94cecf9…; `logs/verify-hate*.log`, guard cpu 2.9 / 4.5) [MEASURED, shared box n=1]:
  * ZK60_MODELS unset (`env -u`): exit 0, `classified` not-flagged, identity 29aeba6c…, input root 4cf9e8ae… (= round
    16's), floor 96, published statement re-checked byte for byte (69 s, 2.28 GiB);
  * ZK60_MODELS=/home/victor/models: exit 0, the same line (67 s, 2.29 GiB);
  * ZK60_MODELS=~/zk60-artifacts/token-io/r19/no-models-here (missing): **refused**, exit 1 in 0.8 s, the error names
    `…/no-models-here/shieldstral-1.0-3b/snapshot-003ec7e2/model.safetensors: No such file or directory`, then
    `app-outcome` flagged — the variable is read, and a wrong one fails closed;
  * the receipt directory (29 files, 848,417,356 B) hashes to tree sha256 8a990fde… before and after each of the three
    (`logs/hate-tree-{0..3}.json`, `hate-tree-equal.log`): **its bytes did not change**.
- 12:02:01-12:10:41 **RECEIPT BYTES UNCHANGED AT REAL SCALE** (`logs/bytes/`): prepare `3 17` (Astra's helper, read
  only), activations exit 0 (69 s, 0.71 GiB), then the r19 candidate's single prove of job 0 (moderate sexual, chunk 0,
  ZK60_MODELS unset) under round 18's FIXED PUBLIC entropy job0.bin: exit 0, 28 segments, 848,412,096 B, not-flagged,
  floor 96, prove 341.3 s / total 449.7 s, peak RSS 8.18 GiB, cgroup 9.78; fixed-entropy block_bytes 64, unread 0
  [MEASURED, n=1]. `compare19.py` -> `bytes.json`: **ok true; all 30 files (28 segments, unverified statement.json,
  input.dec) equal round 18's recorded single-c0, batch-c0 AND r16b-c0 digests** (r18/logs/eq/digests.json). So the
  r16b, r18 and r19 binaries make the same job-0 receipt from the same entropy. Cleanup (`bytes/cleanup.json`):
  removed the test receipt (29 files, 848,417,277 B) and the owner tree (164 files, 122,802,501 B: content, requests,
  activations, the owner dir).
- 12:10:42 **FREEZE PASS** (`logs/r19_freeze.done` = 0; `r19_queue2.done` = 0): candidate pin OK; final-check manifest =
  r19A (0 / 0 / 0); target binary cmp = candidate; **`frozen-r19/`** = 306 files re-hashed, match, none missing /
  extra (20,768,624 B; no target/); **`manifest_final_r19.sha256`** = r19A (list sha256 91585afe…);
  `cli/zk60_classify.r19.release.bin` 841ba983… (`cli/binaries_r19.sha256`); vs frozen-r18: 5 changed, 0 added, 0
  removed (`r19A_vs_frozen_r18.txt`, `.diff` 996 lines).
- 12:11:40 **D46 cleanup** (`logs/cleanup-after-freeze.json`): removed the r19 tree's `target/` (306,627,341 B, 732
  files), the round's test fixture dir `~/zk60-artifacts/token-io/tmp-r19` (1,937,115,220 B apparent, 611 files; 64 MB
  on disk), the candidate copy (2,732,520 B); kept `~/zk60-artifacts/token-io/r19/ent` (2 public entropy files).
  NOT touched (outside this round's write set; for the coordinator): earlier lane trees' targets
  `ops/zkp-mvp/token-io{,-r12b,-r14,-r15,-r16,-r16b,-r17,-r18}/hashline/target` (468 + 250 x3 + 257 x3 + 258 MB) and
  `~/zk60-artifacts/token-io/tmp-r14..r18` (64 MB on disk each).
- 12:12 hand-written notes: `frozen-r19.FROZEN.txt` (cbc139bb…), `cli/zk60_classify.r19.BUILD.txt` (37c8167c…).
- **Round 19 state: frozen-r19 UNREVIEWED.** Nothing of this lane runs. Next: the coordinator routes a review of round 19
  (derive.rs is production code and a capture pin); the gate lane re-pins DERIVE_T16 and mirrors the checkpoint default.
