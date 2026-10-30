# Token round 19b — REVIEW_R19's fixes R19-1 (required), R19-2 (low), R19-3 (doc) on frozen-r19

Lane: Claude token-I/O. Brief (coordinator, 2026-10-30 ~12:35 UTC): a small fix round on `frozen-r19`.
1. R19-1: a `Checkpoint::open` test (a regular file of the pinned size but other content is refused with the pin
   message) and a second test (a symlink to a file is refused); a mutant deleting the SHA-256 comparison
   (`derive.rs:194`) that the new test must kill; at real scale, fresh-process verifies of the real moderate-hate
   receipt with `ZK60_MODELS` naming (a) a directory holding a same-size SPARSE wrong file at the expected relative
   path (exit 1, the pin message, the fail-closed line) and (b) a symlink to the real checkpoint (refused); the
   receipt's files hash the same before and after; the sparse file takes no blocks (`du`) and is deleted after.
2. R19-2: every census scan's production-text cut fails closed (here: a non-test item after the first
   `#[cfg(test)] mod tests {` fails, naming the file), `include!` outside test code is refused; failing-first fixture
   tests; mutants (a generator / an absorb label / a module after the tests block, one behind an `include!`), each
   killed. Optional: every `.rs` under `src/private_block/` is in the graph or on a named list of test files.
3. R19-3 (doc): `derive.rs:17-24` (symlinked model file refused, relative `ZK60_MODELS`, `HOME` unset, a set but missing
   path never falls back); `classify_cli.rs:84-86` "every refusal prints" (as round 18 / 19 did for classify_batch.rs).
4. Then: full suite (guard cpu need 11 / cap 12), round 19's 20 mutants + the new ones, release build; rung receipts
   cross-verify with r19 both ways; the real receipt re-verified with the variable unset and set; receipt bytes
   unchanged (job-0 prove under round 18's fixed entropy vs the recorded digests; test receipt deleted); freeze
   `frozen-r19b` (manifest + build note); list the gate pins that move r19 -> r19b (no gate edits).

Inputs: `results/zk60_token_io_review_r1_20261017/REVIEW_R19.md` (ACCEPTED WITH FIXES); register entries "Token round 19
frozen" / "Token round 19 review"; D46; `r19/PROGRESS.md` and `r19/tools/`.

Paths:
- durable tree: `ops/zkp-mvp/token-io-r19b/` (hashline/ is the crate); init = frozen-r19 without target/
- tools: `r19b/tools/` (round 19's re-rooted); logs: `r19b/logs/`; manifests: `r19b/manifest_r19b_*.sha256`
- scratch (sparse file, test fixtures, entropy copies, candidate binary): `~/zk60-artifacts/token-io/r19b/`

Times are UTC from `date -u`. Labels: [MEASURED] a run happened (shared box, n=1), [COUNTED] exact arithmetic, [READ].

## Ledger

- 12:35 read CLAUDE.md, lane rules + addenda (D46), resource protocol S9, REVIEW_R19 in full, the register's round-19
  entries, the main ledger's round-19 section, r19/PROGRESS.md, r19/tools/. Guard status 12:37: 0 of 11.89 GiB, heavy
  lock free, C: 134 GiB free.
- 12:41:08 **tree** `ops/zkp-mvp/token-io-r19b/`: `freeze19b.py init` copied exactly manifest_final_r19's 306 files from
  frozen-r19 (no target/), all re-hashed (`logs/init.log`); `manifest_r19b_init.sha256` = 306 files, list sha256
  91585afe… = manifest_final_r19 (identical).
- 12:42-12:52 **design reads** (`tools/mirror19b.py`, a Python mirror run on the r19b tree before any Rust change; READ
  only): the graph is 47 files / 45 edges (= round 19); of every file a scan cuts, the four graph files REVIEW_R19 §4.3
  names have only `#[cfg(test)]` items after their tests module, and so do all other graph files and the extras
  (run_capture.rs, run_statement_file.rs, plane_index.rs, boundary.rs, zkp-core rng.rs, pcs.rs, sumcheck.rs); the only
  `include!` on the path is in private_block.rs's `#[cfg(test)] mod capture` (line 1338); 121 .rs files under
  src/private_block/, 76 not in the graph, every one declared `#[cfg(test)]` (checked by grep for the 10 without
  `_tests` in the name). **FINDING:** `hashline/src/zk.rs`, one of the label scan's three FOREIGN files, has ~2,600
  lines of PRODUCTION code after its tests module (lines 2037-4673: the v3 / mr1 feed-forward provers, 39 top-level
  items), which the label scan never read. Its labels there: all already in the table or on NOT_ON_THE_BLOCK_PATH
  (`gammaF`, `zcF-term`, `gammaD`, `zcD-term`, `gamma-pred`, `pred-term` were listed though unreadable) except ONE,
  `zk-mask-profile` (zk.rs:2662, :3937), absorbed only by `prove_layer_zk_v3_mr1` / `verify_layer_zk_v3_mr1`, which no
  file of the private block's path names (grep). So "fail if a non-test item follows the tests block" would break the
  label scan on zk.rs (a file this lane does not edit); R19-2 therefore takes the review's FIRST form: read the whole
  file and leave out exactly the `#[cfg(test)]` items after the tests module, by token structure.
- 12:45 checkpoint header (read only, 8 + 61,000 B of the real file): regular, 7,698,241,104 B, 1 link; the two tensors
  at [0, 805306368) and [6858006528, 6858012672). A probe (1 GiB sparse file under the scratch dir, deleted): reading
  holes fills page cache (+1,024 MiB) and the unlink frees it; so the 7.7 GB wrong-file reads are bounded by each
  guard's cgroup cap and freed when the fixture is deleted.
- 12:46-12:55 **GREEN sources written** (saved first: `wip/green/` + SOURCES.sha256; `wip-green.list`, 5 files):
  * derive.rs: R19-3 doc (the four rules, at `default_checkpoint`); R19-1 tests: `WrongCheckpoint` (a sparse
    regular file of exactly CHECKPOINT_BYTES with a well-formed two-tensor safetensors header, under
    HL_TIO_FIXTURE_DIR else ~/zk60-artifacts/token-io/test-fixtures, never /tmp; refused if the filesystem allocates
    over 1 MiB; removed on drop), `r19b_checkpoint_open_refuses_a_same_size_file_that_is_not_the_pinned_checkpoint`
    (through `default_checkpoint_from(ZK60_MODELS = its models dir)`; must be exactly "checkpoint SHA-256 differs from
    the pinned model"; one byte short: the size check), `r19b_checkpoint_open_refuses_a_symlinked_checkpoint_file`
    (a symlink to a checkpoint-sized regular file: exactly "<link>: not a regular file"; a symlinked models DIRECTORY
    is followed).
  * classify_cli.rs: R19-3 / N-5 module text (argument refusals exit 2 and print neither line).
  * s25_tests.rs: `rust_tokens_spanned` (char spans; `rust_tokens` wraps it); `production_text(file, src)` and
    `production_text_checked` = the text above the tests module as before, plus every top-level item after it that
    is not `#[cfg(test)]`, line numbers kept; fail-closed on a cut that is not the real header, unbalanced brackets,
    an item that never ends, untokenizable text; every caller passes the file name; `module_graph` uses it (so the
    follower follows modules after the tests block); `mod_items` refuses `include!` (any prefix, `r#include`, `()` /
    `[]` / `{}`) outside a `#[cfg(test)]` inline module; three tests: the production text (7 production items read on
    their own line, 3 test-item forms left out, 5 cuts refused, a `#[path]` module after the tests block followed),
    the include refusal (8 refused, 5 accepted), and the directory check (`TEST_ONLY_FILES`, 76 names).
  * hash_domain_tests.rs: `absorb_labels(name, src)` and the module check over s25's production text;
    NOT_ON_THE_BLOCK_PATH 24 -> 25 (`zk-mask-profile`, with the reason).
  * s26_tests.rs: its `production_text` delegates to s25's (consistency; not in the review's list).
- 12:55-12:56 **RED tree** = GREEN with s25's two new behaviours replaced by round 19's (the cut; no include check)
  behind the new interfaces (`wip/red/`, `wip-red.list`); manifest `manifest_r19b_red.sha256` (306 files, 959cb7f0…;
  vs init: changed 5). 12:56:37 `tools/r19b_red.sh` launched detached (marker `logs/r19b_red.done`; guard build 2.9 /
  4.2, label tio19b-red). Predicted: exit 101; FAIL the production-text and include tests; PASS the directory check and
  the two derive tests (true already; their mutants show what they catch).
- 12:56:37-12:59:52 **RED RUN** (`logs/red.log`, `red.guard.json`; guard build 2.9 / 4.2, no wait, child 195 s incl. the
  clean build, peak RSS 2.34 GiB, cgroup 4.2 = the cap: the sparse read's page cache [MEASURED, shared box n=1]): exit
  101, **3 passed, 2 failed, exactly as predicted**:
  * FAIL the production-text test: round 19's cut read NONE of the 7 production items after the tests module (each
    "NOT READ", and no line kept its place), refused NONE of the 5 cuts it cannot place (the cut's text in a raw
    string, an unbalanced brace, an item that never ends, an unclosed attribute, an unterminated comment), and the
    follower did NOT follow a `#[path]` module written after the tests module;
  * FAIL the include test: 8 of 8 production `include!` forms NOT REFUSED (top level, in a fn, `std::include!`, `{}`,
    `[]`, in a production inline module, `r#include!`, after the tests module);
  * PASS the directory check and the two derive tests (true already). 28 warnings, as round 19's; none in a round-19b
    file. The fixture dir was empty afterwards (each sparse file removed on drop).
- 13:00-13:02 GREEN restored (`wip/green/` copied back; all 5 SOURCES.sha256 equal); manifest
  `manifest_r19b_green_src.sha256` 306 files cfae2d1e…, vs init: changed 5, added 0, removed 0. Tools:
  `mutate19b.py` (round 19's 20 unchanged + 8 new: e7-no-pin-compare, e7-follow-symlink, after-tests-rng,
  after-tests-label, after-tests-mod-u / -l, include-u, macro-mod; an `append` op added), `mutcheck.py` (round 19's,
  fixed), `r19b_chain.sh`, `r19b_suite.sh`, `r19b_check.sh`, `r19b_freeze.sh`, `r19b_queue.sh`, `compare19b.py`,
  `cleanup19b.py`, `treehash.py`, `wait_turn.py` (gives way to astra* / pm-* only). Entropy rung8.bin / job0.bin
  copied to `~/zk60-artifacts/token-io/r19b/ent/` (= round 18's; `logs/ent.sha256`). A light rustc probe (scratchpad,
  0 s): a `#[macro_export]` macro in lib.rs expanding to `mod x;`, invoked in `a.rs`, loads `a/x.rs` (so macro-mod's
  file is `token_io/classify_cli/r19b_macro_plant.rs`). Dry run of all 28 mutants (apply + revert, no build;
  `logs/mut-dryrun.log`): each applies and reverts; tree after = before (0 / 0 / 0); records in `mutants-dryrun/`.
- 13:03:15 `tools/r19b_queue.sh` launched detached (marker `logs/r19b_queue.done`): chain (green, rung harness, 28
  mutants) -> suite (s24, cpu 11 / 12; CLI release build) -> checks (xbin vs r19; the real receipt x4: unset, set, the
  sparse wrong file, the symlink; the job-0 bytes) -> freeze; each only after the previous ended 0.
- 13:03:15-13:08:23 **GREEN PASS** (`logs/green.log`; first compile, no fix needed): exit 0, **171 passed, 0 failed, 24
  ignored** (round 19's focused batch + s26_tests: r19's green 158 / 0 / 24, + 5 round-19b tests + 8 s26 tests)
  [308 s, peak RSS 5.97 GiB, cgroup 7.5 = the cap (page cache of the sparse read); MEASURED, shared box n=1]. All five
  r19b tests pass; so do the census, the label scan (now over zk.rs's whole production text, `zk-mask-profile` listed),
  s26's generator-builder test, round 19's follower and E7 tests. Warnings: 28, as round 19's; none in a round-19b
  file.
- 13:08:23-13:08:30 **RUNG BYTE-IDENTITY under fixed entropy: PASS** (`logs/rung-eq.log`): exit 0, block_bytes 256,
  unread_bytes 0. 13:08:30 the mutants started (the 8 new ones first).
- 13:08-13:21 first four mutants [MEASURED]: e7-no-pin-compare KILLED as named (the same-size test panics "Checkpoint::open
  ACCEPTED a same-size file that is not the pinned checkpoint"); e7-follow-symlink KILLED as named (the link is
  followed, the sparse target hashed, and the refusal is the pin's, not "not a regular file"); after-tests-rng KILLED as
  named ("src/private_block/tied_tables/derive.rs: the path constructs a generator with `ZkRng::new`").
  **after-tests-label: killed by its named test (the label scan FAILED, exit 101, compiled), but NOT for the reason I
  named:** the scan reports the planted label as `, b` ("tied_tables/derive.rs absorbs `, b`, which the label table
  ... does not carry"), because its line extractor takes the first `b"` after the word `absorb` and the planted
  `("absorb", b"r19b-planted-label")` has one inside `absorb"` (round 18's label-plant has the same shape; that is why its
  named reason is only "classify_batch_plan.rs absorbs"). My WHY string was too specific, so mutcheck says
  NOT-KILLED-AS-NAMED and the chain will end "mutations"; r19b_queue.sh then stops before the suite (the chain itself
  goes on through all 28). Plan (`tools/r19b_queue2.sh`, launched 13:23:44, detached, waiting on
  `logs/r19b_queue.done`; marker `logs/r19b_queue2.done`): require the chain's stop to be exactly that one verdict
  (every other mutant killed, job-order 101, reused-draw 97, tree after = before), re-judge after-tests-label from its
  log with round 18's reason form ("tied_tables/derive.rs absorbs"), run ONE extra mutant `after-tests-label-2`
  (`tools/mutate19b_label2.py`: `const r19b_absorb_plant: &[u8] = b"r19b-planted-label";` after derive.rs's tests
  module, which the extractor reads exactly) that the label scan must report by its label, then suite -> checks ->
  freeze. A note for the review, not fixed here (outside R19-2): the extractor's first-`b"` rule mis-reads such a line,
  but it still fails (an unknown label), so it fails safe.
- 13:20-13:32 the other four new mutants KILLED as named [MEASURED; each compiled, exit 101]: after-tests-mod-u (the census:
  "the production module graph of the path moved"; the label scan: "declares the production module
  src/private_block/tied_tables/r19b_plant.rs, which this label scan does not read"); after-tests-mod-l (edge and count
  listed: the census reads the file: "src/private_block/tied_tables/r19b_plant.rs: the path constructs a generator with
  `ZkRng::new`"); include-u (both: "src/private_block/token_io/classify_cli.rs: line 544: `include!` outside a
  `#[cfg(test)]` module splices a file into production code without a `mod` item"); macro-mod (it COMPILED: rustc loaded
  the macro-expanded module; no scan sees a `mod`; only the directory check fails: "src/private_block/token_io/
  classify_cli/r19b_macro_plant.rs is neither on the path nor a named test file"). So 7 of the 8 new mutants are killed
  as named and the 8th (after-tests-label) by its named test with another message. 13:32:57 round 19's 20 started.
- 13:32:57-14:34:24 round 19's 20 mutants on the r19b tree: **all killed as named** [MEASURED]: the 18 test-killed each
  compiled, exited 101, the named test(s) FAILED for the named reason; job-order exit 101 (unread 0), reused-draw exit 97
  (unread 224 of 256). Each mutant build ~3 min. Tree after the 28 mutants = before (`manifest_r19b_postmut.sha256` =
  premut = green-src, cfae2d1e…; 0 / 0 / 0). The chain ended "mutations" only on after-tests-label's verdict (13:17), as
  planned; `r19b_queue.done` = "chain mutations".
- 14:34:43 queue2: the chain's 28 verdicts checked (27 killed / 101 / 97 + after-tests-label; `queue2-verdicts.log`);
  after-tests-label RE-JUDGED from its log with "tied_tables/derive.rs absorbs" = killed as named
  (`rejudge-after-tests-label.json`); the extra mutant after-tests-label-2 started.
- 14:34:43-14:37:49 **after-tests-label-2 KILLED as named** [MEASURED]: compiled, exit 101, the label scan FAILED with
  "tied_tables/derive.rs absorbs `r19b-planted-label`, which the label table of hash_domain.rs does not carry"; tree
  after = before (`manifest_r19b_postmut2` = premut2). **Mutants: 29 of 29 killed as named** (round 19's 20 + 9 new;
  after-tests-label by re-judge, after-tests-label-2 directly). 14:37:49 suite s24 started.
- 14:37:49-14:52:17 **SUITE s24 PASS** (`logs/s24-suite.log`, `cargo test --release --offline --locked -j2 --no-fail-fast --
  --test-threads=8`, guard cpu need 11 / cap 12): exit 0, **971 passed, 0 failed, 71 ignored, 29 test binaries**, no
  FAILED line (round 19: 966 / 0 / 71; +5 = the round's five tests) [867 s, no wait, peak RSS 7.73 GiB, cgroup 9.3
  (incl. the sparse read's page cache); MEASURED, shared box n=1]. Manifest r19bA = r19bB (306 files, cfae2d1e…; 0 / 0
  / 0).
- 14:52:17-14:52:31 CLI release build (14 s, 0.43 GiB): `target/release/examples/zk60_classify` sha256
  **6d65d32ea783e36db2458ccce2d459cb29a91bcb45a89c4e23e484914126d609**, copied to
  `~/zk60-artifacts/token-io/r19b/bin/zk60_classify.r19b-candidate` (`logs/b19b-cand.sha256`); differs from r19's
  841ba983… (`b19b-vs-r19.cmp`; the tree path is baked in). 14:52:31 the checks started (xbin).
- 14:52:31-14:52:50 **RUNG CROSS-VERIFY, BOTH WAYS: PASS** (`logs/xbin-r19b-r19.log`; round 15's two-binary test,
  HL_PB_CLI_BIN = the r19b candidate, HL_PB_CLI_BIN_OTHER = r19's 841ba983…): the 23-id and 22-id items proved by r19b
  verify with r19 (exit 0) and proved by r19 verify with r19b (exit 0); 1 passed.
- 14:52:50-14:55:12 **THE REAL MODERATE-HATE RECEIPT, four fresh processes with the r19b candidate** (r16-runs/hate-run,
  made by e94cecf9…; `logs/verify-hate*.log`, guard cpu 2.9 / 4.5) [MEASURED, shared box n=1]:
  * ZK60_MODELS unset (`env -u`): exit 0, `classified` not-flagged, identity 29aeba6c…, input root 4cf9e8ae…, floor 96,
    published statement re-checked byte for byte (70.8 s, 2.29 GiB);
  * ZK60_MODELS=/home/victor/models: exit 0, the same line (66.8 s, 2.28 GiB);
  * **R19-1, a same-size WRONG file:** `wrong-models/shieldstral-1.0-3b/snapshot-003ec7e2/model.safetensors` = the real
    file's 61,008-byte safetensors header (cmp-equal to the real file's first 61,008 bytes) then `truncate -s
    7698241104`: a regular file of 7,698,241,104 B apparent size taking 120 blocks = 61,440 B on disk (`du -B1`;
    `logs/wrong-file.log`). Verify with ZK60_MODELS = that dir: **exit 1 in 11.7 s**, `{"event":"refused",...,"error":
    "…/native_low_h24_t128/profile.json: checkpoint SHA-256 differs from the pinned model"}` then `{"event":
    "app-outcome","outcome":"flagged","why":"no accepted proof: fail-closed (ruling D45(4), …)"}` (the hash pass over
    7.7 GB of holes; peak RSS 0.01 GiB, cgroup 4.5 = the cap: page cache). The dir was deleted right after (73,728 B on
    disk incl. directories);
  * **R19-1, a SYMLINK to the real checkpoint:** `link-models/…/model.safetensors -> /home/victor/models/…/model.safetensors`
    (target a regular file of 7,698,241,104 B; `logs/symlink.log`). Verify: **exit 1 in 0.8 s**, error "…/profile.json:
    /home/victor/zk60-artifacts/token-io/r19b/link-models/shieldstral-1.0-3b/snapshot-003ec7e2/model.safetensors: not a
    regular file", then the same fail-closed app-outcome line. The link dir was deleted right after;
  * the receipt directory (29 files) hashes to tree sha256 8a990fde… before and after each of the four
    (`logs/hate-tree-{0..4}.json`, `hate-tree-equal.log`): **its bytes did not change** (= round 19's tree hash).
- 14:55:13 the receipt-bytes check started (prepare, activations, the job-0 prove under round 18's fixed entropy).
- 14:55:13-15:03:29 **RECEIPT BYTES UNCHANGED AT REAL SCALE** (`logs/bytes/`): prepare `3 17` (Astra's helper, read
  only), activations exit 0 (53 s, 0.71 GiB), then the r19b candidate's single prove of job 0 (moderate sexual, chunk
  0, ZK60_MODELS unset) under round 18's FIXED PUBLIC entropy job0.bin: exit 0, 28 segments, 848,412,096 B, not-flagged,
  floor 96, prove 337.7 s / child 443 s, peak RSS 8.18 GiB, cgroup 10.35; fixed-entropy block_bytes 64, unread 0
  [MEASURED, n=1]. `compare19b.py` -> `bytes.json`: **ok true; all 30 files equal round 18's recorded single-c0, batch-c0
  AND r16b-c0 digests**. Cleanup (`bytes/cleanup.json`): removed the test receipt (29 files, 848,417,277 B) and the
  owner tree (164 files, 122,802,518 B).
- 15:03:30 **FREEZE PASS** (`logs/r19b_freeze.done` = 0; `r19b_queue2.done` = 0): candidate pin OK; final-check manifest
  = r19bA (0 / 0 / 0); target binary cmp = candidate; **`frozen-r19b/`** = 306 files re-hashed, match, none missing /
  extra (20,800,333 B; no target/); **`manifest_final_r19b.sha256`** = r19bA (list sha256 cfae2d1e…);
  `cli/zk60_classify.r19b.release.bin` 6d65d32e… (`cli/binaries_r19b.sha256`); vs frozen-r19: 5 changed, 0 added, 0
  removed (`r19bA_vs_frozen_r19.txt`, `.diff` 765 lines). Production text of the two production files: doc comments
  only (derive.rs hunk 24a25,46 = 22 `///` lines; classify_cli.rs `//!` lines only; checked by diff).
- 15:04 **D46 cleanup** (`logs/cleanup-after-freeze.json`): removed the r19b tree's `target/` (306,615,386 B, 732 files),
  the round's fixture dir `~/zk60-artifacts/token-io/r19b/tmp` (611 files, 1,937,115,220 B apparent, 66 MB on disk; no
  sparse checkpoint left in it), the candidate copy (2,731,264 B; = the frozen binary, checked first), the entropy
  copies (320 B; the originals stay in r18-a5-eq/ent and r19/ent), and the scratchpad rustc probe; then the empty
  `~/zk60-artifacts/token-io/r19b/`. The sparse wrong file (61,440 B on disk) and the symlink dir went at 14:55. No
  owner dir left. C: 135 GiB free.
- 15:04 **gate pins r19 -> r19b** (`tools/pins_r19_r19b.py` -> `logs/pins_r19_r19b.json`; read only, no gate file
  edited) [MEASURED, frozen-r19 vs frozen-r19b]: of the 72 capture source pins exactly ONE moves,
  `src/private_block/tied_tables/derive.rs` 4b53222b… -> 1d6150100abb051d08e77d6c86e2cafed0915342203480ce73c8583170810fb7;
  in the gate's v23 table `DERIVE_T16` (r13_pins.py:195, used 230 / 482; still r18's c5bec3c6…) is the only entry that
  moves r19 -> r19b (private_block.rs and run_capture.rs still owe their round-17 / 18 re-pins); classtied.py's
  derive.rs line citations shift +22 after line 24 vs r19 (the pin comparison :194 -> :216); the CLI binary a capture
  records 841ba983… -> 6d65d32e…. classify_cli.rs (6e93e5d7… -> 616e33b9…) is not a capture pin (named only in the
  gate's historical classpins tables and r13_pins.py's "not pinned" notes); the three test files are not pins.
- 15:05 hand-written notes: `frozen-r19b.FROZEN.txt` (ae13b777…), `cli/zk60_classify.r19b.BUILD.txt` (0f970c90…).
- **Round 19b state: frozen-r19b UNREVIEWED.** Nothing of this lane runs. Notes for the review: (1) zk.rs's unread
  production tail (above); (2) the label extractor's first-`b"` rule reads `("absorb", b"x")` as label `, b` (fails
  safe, not fixed); (3) `examples/zk60_classify.rs:52` carries the same "Every refusal prints the fail-closed outcome
  line" sentence as classify_cli.rs did (outside the brief; not edited); (4) the directory check cannot see a file
  that is already on TEST_ONLY_FILES and is ALSO declared in production by a macro. Next: an independent review of
  round 19b; then the gate re-pins 18 + 19 + 19b together.
