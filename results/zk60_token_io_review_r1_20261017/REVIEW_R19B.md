# Token review, round 19b: REVIEW_R19's three fixes, and the zk.rs finding

Reviewer: independent code review of the frozen token tree `frozen-r19b/` (2026-10-30, 15:07–15:35 UTC, times from
`date -u`). Read-only, except for this file and scratch probes in my session scratchpad. **Not a privacy review and
not a classifier-fidelity review.**

Short names: `FR19B` = `results/zk60_token_io_r1_20261017/frozen-r19b/hashline`; `PB` = `FR19B/src/private_block`;
`TIO` = `PB/token_io`; `R19B` = `results/zk60_token_io_r1_20261017/r19b`; `ZK` = `FR19B/src/zk.rs`.

## Verdict: ACCEPTED WITH FIXES

R19-1, R19-2 and R19-3 are done. The zk.rs finding is right: the label it found is not on the block path, and no
earlier accepted conclusion changes. Every fix below is low. None touches a pinned file, so the gate can re-pin rounds
18, 19 and 19b now.

In plain words:

* **R19-1 is closed.** A file of exactly the checkpoint's size that is not the checkpoint is refused by the hash
  check, both in a test and on the real receipt. A symlinked model file is refused. Both new mutants fail for the
  stated reason. The real receipt's bytes did not change.
* **R19-2 is closed for what REVIEW_R19 asked.**
  * The scans read the whole file.
  * A cut the reader cannot place is refused.
  * A plainly written `include!` is refused.
  * All 121 files under `src/private_block/` are accounted for.

  Two gaps remain, and both need a deliberate disguise. First, renaming `include` (`use std::include as x;`), or
  passing it to a macro as a word, gets past the `include!` check. I compiled both forms, and both splice a file into
  production. Second, the directory check cannot see a second declaration of a listed test file. One build-side check
  closes both gaps (R19B-2).
* **The zk.rs claim holds.**
  * Nothing in zk.rs's unread region (lines 2037–4273, plus `pub mod fresh_poc` at 4672–4673) is reachable from the
    block path, the classifier's prove or verify, or the token-I/O stages.
  * The label scan's check on zk.rs was incomplete in every token tree from frozen-r7 to frozen-r19.
  * The list of labels the path actually uses was complete all along.
  * Even if `zk-mask-profile` were on the path, its 97-byte input could not collide with anything the length guard
    protects.
* **The claims match the logs.**
  * The suite: 971 passed / 0 failed / 71 ignored.
  * Mutants: 29 of 29 killed.
  * Receipt bytes: 30 of 30 files equal round 18's.
  * The rung receipts cross-verify both ways.
  * Exactly one capture pin moves, `derive.rs`.

### Fixes

| # | Severity | Where | Fix |
|---|---|---|---|
| R19B-1 | low (test hardening) | `PB/s25_tests.rs:2060` (the `include!` check in `mod_items`) | The check matches only the word `include` directly followed by `!`. Two forms compile and splice a file into production, and `mod_items` accepts both (probe I1, I2, §2.3): `use std::include as splice; splice!("x");` and `macro_rules! m { ($i:ident) => { $i!("x"); } } m!(include);`. Fix: refuse every production `include` / `r#include` token outside a `#[cfg(test)]` scope, whatever follows it. The only production-text use of the word in the path's files today is `private_block.rs:1338`, inside the `#[cfg(test)] mod capture`, so nothing else breaks. Add both forms as fixture cases. The fixture case "a variable named `include`" (`:2451`) would then move to the refused list. Alternatively, rely on R19B-2. |
| R19B-2 | low, optional (the complete closure of R19-2's leftovers) | `PB/s25_tests.rs:2509-2547` (the directory check), or the round's check script | Ask the compiler which files it compiles. rustc's dep-info for a non-test build of the lib (`cargo rustc --lib --release -- --emit=dep-info,metadata`, or the `.d` file cargo already writes) lists every source file the production build read. That includes a macro-expanded module and an `include!`d file of any extension, however the macro is named (probe D, §2.3). Assert that the set of `src/private_block/**` files in it equals the module graph's 45, and that no `TEST_ONLY_FILES` entry is in it. This closes the macro-mod class, R19B-1's two forms and the lane's note (4) in one check. |
| R19B-3 | low (wording) | `PB/hash_domain_tests.rs:357-362` and `:483-488`; `PB/s25_tests.rs:1701-1702`; the register's 19b entry (`ZK60_DECISIONS.md:1668-1669`) | (a) "About 2,600 production lines (≈2037–4673)" is ~400 lines high. The production items are `ZK:2037-4273` (2,237 lines) plus the two-line `#[path] pub mod fresh_poc;` at `:4672-4673`. Lines 4274–4671 are three `#[cfg(test)]` modules. (b) The foreign-file text says "if one of those files grows a new label, this test fails". It reads the three files, not their production modules, and none of those modules is read by any scan: `zk.rs` → `zk_proof_size.rs`, `zk_ffn_fresh_poc.rs` (→ `zk_ffn_fresh_wire.rs`, `zk_ffn_fresh_io.rs`); `sumcheck.rs` → `sumcheck/rounds.rs`, `sumcheck/grouped.rs`; `pcs.rs` → `pcs/backend.rs`, `pcs/encode_buffer.rs`. Say so, or extend the foreign half through `module_children`. Leave the frozen freeze note as it is and put a dated correction in the ledger. |

Notes that need no fix in this round: N-1 to N-9 in §6.

## 3. The zk.rs finding (question 3)

### 3.1 What the unread region is [MEASURED]

* **The layout of `ZK`** (4,673 lines). The tests module is `:1947-1974`. A comment banner follows (`:1976-2035`).
  After that come 39 top-level items:
  * **35 production items:** `:2037-4273`, and `#[path = "zk_ffn_fresh_poc.rs"] pub mod fresh_poc;` at `:4672-4673`;
  * **4 test items:** the `#[cfg(test)] thread_local!` (`:2356`), `mask_diagnostic` (`:4274-4276`),
    `mr1_probe_tests` (`:4278-4280`) and `tests_v3` (`:4282-4669`).
* **No other file has this layout.** I wrote my own Rust lexer and item splitter, independent of the lane's mirror
  (`after_tests2.py` in my scratchpad). It covers comments, strings, raw strings, chars and lifetimes, and I ran it on
  every `.rs` file in `FR19B/src` and `frozen-r19b/zkp-core/src`. **zk.rs is the only file with production items after
  its first `#[cfg(test)]\nmod tests {`.** The four graph files REVIEW_R19 named, the other 43 graph files and
  zkp-core's `pcs.rs` and `sumcheck.rs` have only `#[cfg(test)]` items there. So the only region the old cut hid is
  zk.rs's, plus the `fresh_poc` files below it.
* **zk.rs never changed.** It is byte-identical (sha256 `66d11286…`) in every token tree: frozen-r7, r9, r11, r12, r13,
  r14, r15, r16, r16b, r17, r18, r19 and r19b. `NOT_ON_THE_BLOCK_PATH` had the same 24 entries in all of them up to
  r19. So the region went unread in every round, and nothing in it changed while it was unread.

### 3.2 Is anything in it reached from the block path? No [READ, grep]

* **What the region holds:**
  * the v3 feed-forward layer prover and verifier: `prove_layer_zk_v3`, `prove_layer_zk_v3_mr1`,
    `verify_layer_zk_v3`, `verify_layer_zk_v3_mr1` and `zk_v3_committed_rows`;
  * their layout and helpers: `ZkLayoutV3`, `mask_specs_v3`, `table_specs_v3`, `PendingV3` and others;
  * an inline `mod zkhostbuf`;
  * `fresh_poc` and its `wire` and `io` modules.

  Its only `impl` blocks are inherent ones on its own types (`ZkLayoutV3` at `:2121`, `PendingV3` at `:2685`). It has
  no trait impl and no macro. So code above the tests module could reach it only by naming an item.
* **No line above the tests module names any of them.** I checked each of the 26 names defined in the region, and the
  modules `zkhostbuf` and `fresh_poc`, against `ZK:1-1946`.
* **The path takes only items defined above the tests module.** I grepped every `zk::` reference in the 47 path files:
  `private_block.rs`, the 45 under `src/private_block/` and `private_seam.rs`. They resolve to:
  * `ZkRng` (the re-export at `:344`), `MaskFunctional` (`:395`), `MaskOpening` (`:401`);
  * `MASK_LOG_MSG`, `MASK_LOG_DOM`, `MASK_Q` (`:373-375`);
  * `mask_commit` (`:430`), `mask_commit_tagged` (`:481`), `mask_open` (`:563`), `mask_verify` (`:603`),
    `mask_verify_tagged` (`:648`);
  * `masked_prove` (`:1077`), `masked_prove_rounds` (`:1091`), `extension` (`:1108`).

  The callers include `protocol.rs`, `argument.rs`, `token_io.rs`, `stage_in(_c).rs`, `stage_out(_c).rs`,
  `run_capture.rs` and `private_seam.rs`.
* **Who names the region's items, outside zk.rs:**
  * `src/bin/hashline.rs` (the FFN CLI);
  * `src/model_identity.rs`;
  * the `zk_ffn_*` submodules;
  * `src/zk_mr1_probe_tests.rs` (`#[cfg(test)]`);
  * `examples/zk60_repaired_mask_probe.rs`;
  * one comment in `hash_domain_tests.rs`.

  The other crate modules the path calls name none of them: `field`, `ntt`, `merkle`, `transcript`, `mle`, `pcs`,
  `sumcheck`, `tables_attn`, `tables_v3`, `export_v3`, `gpu` and `causal_oracle`. No path file names
  `model_identity`, `layer` or `fresh_poc`.
* **The entry points.** `examples/zk60_classify.rs` calls only `hashline::private_block::classify_*_command`, and
  `examples/zk60_token_io.rs` only `private_block::token_*_command`.
* **So the lane's claim is right.** No function reachable from the block path, the classifier's prove or verify, or
  the token-I/O stages is defined in `ZK:2037-4673` or in the `fresh_poc` files. No other file region was skipped
  the same way (§3.1).

### 3.3 Labels and generators in the region [MEASURED: a Python mirror of `absorb_labels` over `ZK:2037-4273`]

* **20 labels:**
  * `A`, `H`, `M`, `W`, `zk`;
  * `gu-claim`, `gu-term`, `d-claim`, `d-term`;
  * `gammaF`, `zcF-term`, `gammaD`, `zcD-term`;
  * `gamma-tab`, `tab-term`, `gamma-zs`, `zs-term`;
  * `gamma-pred`, `pred-term`;
  * `zk-mask-profile`.

  `A`, `H` and `M` are in the table (the block absorbs those labels too). Every other one is in
  `NOT_ON_THE_BLOCK_PATH`, except `zk-mask-profile`. Six labels occur only in this region yet were already on the
  list: `gamma-pred`, `gammaD`, `gammaF`, `pred-term`, `zcD-term` and `zcF-term`. So whoever wrote the list read the
  whole file; the scan did not.
* **`zk-mask-profile`** is absorbed only at `ZK:2662` (`prove_layer_zk_v3_mr1`) and `ZK:3937`
  (`verify_layer_zk_v3_mr1`). Their only callers are `examples/zk60_repaired_mask_probe.rs:201, 223` and the test
  module `zk_mr1_probe_tests.rs`. **This confirms the lane's claim.**
* **Generators in the region:**
  * `:2605` `cfg.rng("layer-v3-{l}")`. That is `ZkConfig::rng`, `ZK:334-340`: seeded when `cfg.seed` is set, otherwise
    from the operating system;
  * `:2661` `ZkRng::from_os(MR1_PROBE_PROFILE)`;
  * the rest are `rng` parameters passed through to `pcs::commit_zk_*` and `mask_commit`.

  All of them are off the path. The generator census never read zk.rs, and it forbids any mention of `ZkConfig` in
  path files. So the region does not touch it.
* **The `fresh_poc` files.** No scan reads them, before or after 19b. They absorb:
  * `profile`, `request-context`, `table-values`, `weight-policy`, `expected-public-W`, `expected-IO`;
  * `io-terminals`, `io-mask-eval`, `io-side`, `io-gamma`;
  * `public-W`, `private-W`.

  They also call `ZkRng::from_os` (`zk_ffn_fresh_poc.rs:95`, `zk_ffn_fresh_io.rs:164`). All of this is off the path
  (§3.2).

### 3.4 Was the hash-domain census of earlier rounds incomplete in a way that matters? Incomplete: yes. Matters: no

**What relied on zk.rs being read in full.**
* **The label scan's foreign half.** It reads `zk.rs`, `zkp-core/src/pcs.rs` and `zkp-core/src/sumcheck.rs` against
  `NOT_ON_THE_BLOCK_PATH`. It was written on 2026-09-20 in the native lane, alongside rulings T-3 and T-4 of D19.
  * **Its text says** they "are scanned too … If one of those files grows a new label, this test fails"
    (`PB/hash_domain_tests.rs:357-362`).
  * **That was false** for `ZK:2037-4273` in every token tree from r7 to r19. It is still false for the production
    modules of all three files (R19B-3 (b)).
* **The rounds that relied on it.**
  * r13, r14, r15, r16, r16b, r17, r18 and r19 each ran that test green in their suite and relied on it as the
    tripwire.
  * r16 (the merge, 36 lane files), r18 (39 files, REVIEW_R18 §5) and r19 (47 files and the module check, REVIEW_R19
    §4) made reviewed claims about the label scan.

  Those reviewed claims are about the lane files, and they are true: by §3.1, no lane or graph file has production
  code after its tests module. No register entry or review from r13 to r19 states that the foreign half was complete.
  The reliance was implicit.
* **My predecessor's survey missed it.** REVIEW_R19 §4.3 checked only the 47 graph files for this placement and said
  "nothing is hidden now". It never looked at the three foreign files, so it missed this region. Its conclusion about
  the path still holds (N-1).
* **The path's own label set was complete.** That set is the table in `hash_domain.rs`, from which T-3 builds its
  length set. Every label it takes from zk.rs or zkp-core sits above its file's tests module, or in a file without
  one:
  * `mask-q` and `mask-prox` (`ZK:584-660`);
  * `sc-round` (`ZK:1118`; zkp-core `sumcheck.rs:114, 159`; `sumcheck/rounds.rs:41`; `gpu/cuda.rs:3287, 3415`);
  * `pcs-vec` and `pcs-prox` (zkp-core `pcs.rs:413-1210`, above its test modules at `:1265` and `:1466`).

  Each is also checked by name (`hash_domain_tests.rs:510`).

**No accepted conclusion changes:**
1. **The path never reaches the region** (§3.2). So the path's label set is what it was. So are T-3's refusal set,
   T-4, and D19's residual for the 47-byte challenge queries.
2. **zk.rs is byte-identical from r7 to r19b.** No round could have added a label behind the cut.
3. **Even if the label were on the path, nothing would change.** An absorb hashes
   `32 + 8 + |label| + 8 + |data|` bytes (`hash_domain.rs:54-57`). For `zk-mask-profile` that is
   `48 + 15 + 34 = 97` bytes.
   * 97 is not a multiple of 8, so no column, which hashes as `8 · rows` bytes, can have that length.
   * 97 is not 40 (the generator refill), 47 (the challenge squeeze) or 64 (a Merkle node or salted leaf).

   So T-3's refusals and D19's 2^-241 residual would be unchanged.
4. **The privacy acceptances are untouched.** D33 (R7, extended to r9 and r11) and D36 (r9) rest on D19b and these
   guards, and they are unaffected for the same reasons. I checked only the token lane's copies of zk.rs, not the
   native lane's R7 tree.
5. **The soundness acceptances are untouched.** REVIEW_R13, R14, R16, R18 and R19 do not depend on the foreign half.

**What is still uncovered.** Round 19b now reads zk.rs's whole text. The foreign half still does not follow the three
files' production modules (R19B-3 (b)). Today nothing on the path hides there:
* `sumcheck/rounds.rs` absorbs only `sc-round`, which the table carries;
* `pcs/backend.rs`, `pcs/encode_buffer.rs`, `sumcheck/grouped.rs` and `zk_proof_size.rs` absorb nothing.

But a new label in `rounds.rs` would go unseen. That is the scan's own stated limit: a label reached through "a call
chain into a fourth file".

## 1. R19-1: a wrong checkpoint is refused (question 1)

**The same-size test** (`PB/tied_tables/derive.rs:530-548`) [READ]:
* **The fixture.** `WrongCheckpoint` (`:470-520`) writes an 8-byte length, then a well-formed two-tensor safetensors
  header (the embedding at `[0, 805306368)` and the norm after it), then `set_len(CHECKPOINT_BYTES)`. It refuses to run
  if the filesystem allocates more than 1 MiB.
* **It asserts the fixture passes `regular(…, CHECKPOINT_BYTES, true)` first.** So the refusal is not the size or
  link check.
* **It reaches the file the way a verifier does.** The path comes from `default_checkpoint_from(Some(models), …)`,
  the E7 resolver, and the file is opened with `Checkpoint::open`. That is the verifier's own opener:
  `recompute_profile` calls it at `:304` through `checkpoint_path_with(…, default_checkpoint)`.
* **The error must be exactly** "checkpoint SHA-256 differs from the pinned model". So the file passed:
  * the header-length bound;
  * both `extent` checks;
  * the LM-head check (`:187-193`).

  The refusal is the comparison at `:216`.
* **One byte short:** `regular`'s "expected exactly 7698241104".

**The symlink test** (`:556-572`):
* the target is a regular file of the pinned size;
* `Checkpoint::open(&link)` must fail with exactly `"<link>: not a regular file"`;
* a symlinked models directory must pass `regular`.

**The mutants** [MEASURED: I re-read both logs]:
* **`e7-no-pin-compare`** deletes the line at `:216`. It compiled. Exit 101. The same-size test panicked at
  `derive.rs:538` with "Checkpoint::open ACCEPTED a same-size file that is not the pinned checkpoint". Without the
  comparison the zero-filled file opens: zero BF16 norm values are finite.
* **`e7-follow-symlink`** turns `symlink_metadata` into `metadata` and drops `O_NOFOLLOW` (`PB/tied_tables.rs:23, 33`).
  It compiled. Exit 101. The symlink test's assertion failed with left = "checkpoint SHA-256 differs from the pinned
  model": the link was followed, and the target was hashed.

  Either half alone would also be caught: `metadata` alone hits `ELOOP` on the `O_NOFOLLOW` open, which gives a
  different message. Dropping `O_NOFOLLOW` alone is the one change this test cannot see. It is the race-time defence
  behind `symlink_metadata`, so that is acceptable.

**At real scale** [MEASURED]. The r19b candidate (`6d65d32e…`, equal to the frozen binary) re-verified the real
moderate-hate receipt in four fresh processes, using the same `VERIFY` arguments (`R19B/tools/r19b_check.sh:40`):

| Run | Result |
|---|---|
| `ZK60_MODELS` unset | exit 0, not-flagged, identity `29aeba6c…` |
| `ZK60_MODELS=/home/victor/models` | exit 0, the same |
| a sparse wrong file | exit 1 in 11.7 s: `{"event":"refused",…"…/profile.json: checkpoint SHA-256 differs from the pinned model"}`, then the flagged `app-outcome` line |
| a symlink to the real checkpoint | exit 1 in 0.8 s: "…/model.safetensors: not a regular file", then the flagged line |

The sparse file was the real 61,008-byte header, cmp-equal to the real file's first bytes, then `truncate` to
7,698,241,104 B. It took 120 blocks (61,440 B) on disk and was deleted after the run (`wrong-file.log`).

The receipt tree hashes to `8a990fde…` all five times (`hate-tree-0..4.json`), the same as round 19.

**R19-1 is closed.**

## 2. R19-2: the scans read whole files (question 2)

### 2.1 The whole-file reader (`PB/s25_tests.rs:1717-1797`) [READ, and MEASURED by a probe]

* **How it works.**
  * The text above the first `\n#[cfg(test)]\nmod tests {` is kept verbatim. Any `#[cfg(test)]` items in it are
    over-read, which is safe.
  * After it, each top-level item is read with its outer attributes. Only an item carrying exactly `#[cfg(test)]` is
    dropped, and its line breaks are kept.
  * An item ends at a `;` outside every bracket, or at the brace that brings the depth back to 0.
* **It can only over-read.** A mis-split can only end an item early, and the leftover is then read as production
  text. In valid Rust no depth-0 `}` mid-item is followed by `#`. So a production item can never start a segment that
  begins with `#[cfg(test)]`.

  My probe ran the copied reader (P1–P14, §7). It kept, for example:
  * the `+ 2;` of a test `const C: u8 = { 1 } + 2;` (P2);
  * the `.min(2);` of a test `static` (P3);
  * the `>> X for T {}` of a test `impl<T: Tr<{ 1 }>>` (P4);

  and it read every production item after them.
* **It fails closed.** These are refused, naming `file:line`:
  * the cut's text inside a string (P12);
  * the cut's text inside a block comment (P13);
  * a tests module nested in an inline module (P9: "an unbalanced brace");
  * the round's five fixture cases.
* **No file stops being read.** A file with no cut, or a tests module written another way, is read whole. That
  over-reads, which is safe.
* **Every scan uses it** (grep: no other cut remains):
  * the follower (`:2191`);
  * the generator census (`:2606`);
  * the boundary and `rng.rs` checks;
  * the call-site census (`:2973`);
  * s26 (which delegates to it);
  * the label scan, lane files and foreign files alike (`hash_domain_tests.rs:330, 449`).

### 2.2 The four parts, judged

| Part | Complete? | Fail-closed? |
|---|---|---|
| Whole-file read | Yes, for every file the scans read (above). It does not follow the foreign files' modules (R19B-3 (b)). | Yes (P9, P12, P13, the 5 fixtures) |
| Unplaceable cut | Yes: the header must be the first token on the cut's line, and must be `#[cfg(test)] mod tests {` | Yes |
| `include!` outside test code | Only as spelled: `include!`, `std::` / `::core::include!`, `r#include!`, any delimiter (P-I4 refused). A renamed import or a macro argument passes (R19B-1). It is not applied to the three foreign files, which get no `mod_items` pass. | Fails open for those two disguises |
| The directory check (`:2509`, 76 listed) | For a new `.rs` file under `src/private_block/`: yes. It cannot see a non-`.rs` spliced file, a file outside the directory, or a second declaration of a listed file (R19B-2) | Yes, within that scope |

**The 121 files** [MEASURED, my own count]:
* 121 `.rs` files are under `PB`;
* `TEST_ONLY_FILES` holds 76 unique names;
* the graph holds 47 files, of which 45 are under `PB`.

So 121 = 45 + 76. I found each listed file's declaration:
* 72 are declared `#[cfg(test)]` directly;
* 4 are children of test-only parents: `classify_r16b_tests.rs` under `classify_r16_tests.rs`, `gate19_capture_tests.rs`
  under `classify_capture_tests.rs`, `classify_r17_tests.rs` under `gate19_capture_tests.rs`, and both `tests.rs`.

### 2.3 Probes [MEASURED; light guards]

* **The reader.** I copied `PB/s25_tests.rs:1692-2211` verbatim (copy sha256 `592bc879…`) into a scratch program
  (`r19b/probe/main.rs`, `05a1c259…`). The only change was `pub(super) ` → `pub `. Guarded builds:
  `review19b-scanner-build` (0.13 GiB, 1 s), then `review19b-scanner-probe` (under 0.01 GiB). Results as in §2.1, plus:
  * **I1** `use std::include as splice; splice!("p.rs");` → `mod_items` OK, nothing refused;
  * **I2** `macro_rules! m { ($i:ident) => { $i!("p.rs"); }; } m!(include);` → OK, nothing refused;
  * **I3** `m!(mod plant)` → refused ("`mod plant` followed by neither `;` nor `{`");
  * **I4** `::core::include!(…)` → refused.
* **D, the compiler.** A three-file crate (`r19b/crate/`, rustc 1.97.0, `--emit=dep-info,metadata`; guard
  `review19b-depinfo-probe`):
  * a `#[macro_export]` macro expanding to `mod macro_plant;`;
  * I1's renamed `include`;
  * I2's macro form;
  * with a `uses()` that calls all three.

  It type-checked. Its dep-info lists `a/macro_plant.rs`, `spliced_one.inc` and `spliced_two.inc`. So I1 and I2 really
  splice files into production, and the dep-info sees every disguise (R19B-2).

### 2.4 The nine new mutants [MEASURED: I re-read every log for exit code, compile errors and FAILED lines]

| Mutant | Exit | What failed, and why |
|---|---|---|
| e7-no-pin-compare / e7-follow-symlink | 101 / 101 | §1 |
| after-tests-rng | 101 | the census at `s25_tests.rs:2609`: "derive.rs: the path constructs a generator with `ZkRng::new`" |
| after-tests-label | 101 | the label scan: "derive.rs absorbs `, b`". The extractor takes the first `b"` after the word `absorb`, and `("absorb", b"…")` has one. Re-judged with round 18's reason form ("tied_tables/derive.rs absorbs"); that agrees with the log |
| after-tests-label-2 | 101 | the label scan: "derive.rs absorbs `r19b-planted-label`" (read through the identifier `r19b_absorb_plant`) |
| after-tests-mod-u | 101 | both: "the production module graph of the path moved", and "declares the production module …/r19b_plant.rs, which this label scan does not read" |
| after-tests-mod-l | 101 | the census reads the new file: "…/r19b_plant.rs: the path constructs a generator with `ZkRng::new`" |
| include-u | 101 | both scans: "classify_cli.rs: line 544: `include!` outside a `#[cfg(test)]` module …" |
| macro-mod | 101 | only the directory check: "…/classify_cli/r19b_macro_plant.rs is neither on the path nor a named test file". It compiled, so rustc loaded the macro's module |

None of the nine had `error[E` or "could not compile". Each ran only its named tests (the filter). So "no other scan sees
macro-mod" is by reading. I agree with it: `crate::r19b_plant_mod!();` contains no `mod` token.

**What the nine show.** Each placement R19-2 names is now read or refused on the real tree:
* a generator, a label or a module after a tests module;
* an `include!`;
* a macro's module.

The unplaceable-cut refusals are shown by the failing-first fixture test only. That is fine for a refusal path.

**On the lane's note (4)** (a listed test file also declared in production by a macro). The risk is real, but it needs
a deliberate double declaration.
* **Not only a macro.** A plain `#[path = "private_block/run_capture.rs"] mod x;` in any production module outside the
  graph, such as `lib.rs`, gets past the check the same way.
* **It matters only with a call.** Path code would also have to call into that module. That is the scans' standing
  limit: they are local to the graph and do not follow calls.

R19B-2 closes the declaration half.

## 4. R19-3, and what production code changed (question 4)

* **What changed [MEASURED].**
  * `diff -rq` frozen-r19 against frozen-r19b: 5 paths changed, none added or removed.
  * frozen-r19b re-hashes to `manifest_final_r19b.sha256`: 306 of 306 files, none extra. The list sha256 is
    `cfae2d1e…` in every manifest from green-src onward.
  * `derive.rs` production text, comments removed: 272 lines in both trees, identical. The only production hunk is
    22 `///` lines at `:25-46`. The test hunk sits inside `mod tests` (`:338`).
  * `classify_cli.rs` with `//!` and `///` lines removed: identical.
  * The three test files are `#[cfg(test)]` (s26 is on `TEST_ONLY_FILES`).
* **R19-3's four rules match the code** (`derive.rs:53-60`, `tied_tables.rs:21-46`):
  * the last component goes through `symlink_metadata`;
  * a relative `PathBuf` is resolved against the working directory;
  * `(None, None)` is an error, and an empty string counts as unset;
  * `(Some(m), _)` never consults `HOME`.

  The hard-link advice is correct, because `regular` does not check the link count. One nuance is in N-6.
* **The N-5 text** (`TIO/classify_cli.rs:84-92`) matches the code:
  * `--content`, an unknown flag and a flag without its value return 2, with one stderr line (`:524-534`, `:769-775`;
    `trained_block.rs:1632-1649`);
  * everything after that goes through `refused` (`:134-138`), which prints `refused`, then the line, then exits 1.

## 5. The claims against the logs (question 5) [MEASURED, recounted]

* **The suite** (`s24-suite.log`): 29 `test result` lines, all `ok`. **971 passed, 0 failed, 71 ignored**, no
  `FAILED`, exit 0. The guard record is `tio19b-s24-suite`, cpu 11 / 12, peak RSS 7.73 GiB. All five r19b tests are
  listed `ok`, and so are the census and the label scan.
* **Failing first, then passing.**
  * RED: exactly the production-text and include tests FAILED, 3 passed. Each item is "NOT READ" / "NOT REFUSED" as
    the ledger says.
  * GREEN: 171 / 0 / 24.
* **Mutants: 29 of 29.**
  * 26 records in `r19b_mut.jsonl`, all killed as named except after-tests-label;
  * job-order: exit 101, "job 0: the batch's run directory is not the single prove's byte for byte", unread 0;
  * reused-draw: exit 97, unread 224 of 256;
  * after-tests-label by the re-judge (`rejudge-after-tests-label.json`), and after-tests-label-2 directly;
  * the tree after the mutants equals the tree before (`premut` = `postmut` and `premut2` = `postmut2`, all
    `cfae2d1e…`).
* **Receipt bytes: 30 of 30.** I recomputed the equality of `bytes/bytes.json` against round 18's `digests.json`:
  * single-c0: 30 / 30;
  * batch-c0: 30 / 30;
  * r16b-c0: 30 / 30.

  The run itself: exit 0, 28 segments, 848,412,096 B, not-flagged, floor 96, fixed entropy 64 B with 0 unread, under
  `env -u ZK60_MODELS`.
* **Rung cross-verification** (`xbin-r19b-r19.log`): exit 0. The 23-id and 22-id items were proved by r19b and
  verified by r19 (`841ba983…`, pin re-checked), and the other way round.
* **The binary.** `cli/zk60_classify.r19b.release.bin` re-hashes to `6d65d32e…`, equal to the candidate the checks
  used.
* **The gate pins that move from r19 to r19b.**
  * Of the 72 capture pins, only `derive.rs` moves: `4b53222b…` → `1d615010…` (I recomputed both).
  * `run_capture.rs` names no other changed file.
  * In the gate:
    * `DERIVE_T16`: `r13_pins.py:195`, used at `:230` and `:482`, still r18's `c5bec3c6…`;
    * `classtied.py`'s `derive.rs` line citations: +22 after line 24, and the pin comparison is now `:216`;
    * the CLI binary a capture records: `841ba983…` → `6d65d32e…`.
  * `classify_cli.rs` (`6e93e5d7…` → `616e33b9…`) is not a capture pin.

## 6. Notes (no fix needed this round)

* **N-1. My predecessor's survey.** REVIEW_R19 §4.3 surveyed only the 47 graph files for the after-tests placement. It
  missed the label scan's three foreign files, and so zk.rs's tail. Its conclusion about the path is unaffected (§3).
* **N-2. The label extractor.** It reads one label per line, from the first `b"` after the word `absorb`. A second
  absorb on the same line would go unchecked, and so would a label on the next line. In the scanned files there is
  neither today (a heuristic sweep). This predates the round.
* **N-3. Stale line numbers in the label table.** `hash_domain.rs:396-404` cites `mask-q` and `mask-prox` at
  `zk.rs:533, :562 / :542, :565`, and `sc-round` at `sumcheck.rs:109, :154` and `zk.rs:994`. The actual lines are
  `zk.rs:584-660, 1118` and `sumcheck.rs:114, 159`. This is documentation only, and it predates the round.
* **N-4. The example's header.** `examples/zk60_classify.rs:52` still says "Every refusal prints the fail-closed
  outcome line" (the lane's note 3). Its `:57-58` gives the exit codes. Editing this file changes the binary's hash,
  so fold it into a round that rebuilds.
* **N-5. Hashing 7.7 GB of holes in every suite.** The same-size test does this in every suite run: about 5 s, with
  page cache up to the guard's cap, freed when the fixture is dropped. Its sparse check runs after `set_len`. On a
  filesystem without holes (for example, if `HL_TIO_FIXTURE_DIR` pointed at `/mnt/c`) the 7.7 GB would be allocated
  before the check fails. The default (`~/zk60-artifacts`, ext4) is fine. Consider probing sparseness with a small file
  first.
* **N-6. `O_NOFOLLOW` is not on every platform.** R19-3's text says the open uses `O_NOFOLLOW`, but that is set only
  on Linux x86-64 (`tied_tables.rs:30-34`). Elsewhere the protection is `symlink_metadata` plus the device / inode
  re-check. Put this in the open release's text. Do not edit `derive.rs` before the re-pin, because that would move
  the pin again.
* **N-7. The capture-pin census still uses the old line matcher.** `s24_tests.rs:441-454` parses `private_block.rs`
  with the `mod x;` / `pub mod x;` matcher of round 18's era. Nothing escapes it today: 28 modules plus the parent,
  equal to the graph. A future `pub(crate) mod` or a one-line `#[path] mod` in `private_block.rs` would escape the
  pin requirement, though s25's edge-list assertion would still flag the module. This is outside R19-2. Point it at
  `module_graph` in a later round.
* **N-8. No mutant covers zk.rs's tail.** No mutant shows that the foreign half now reads zk.rs's tail, for example by
  deleting `zk-mask-profile` from the list. By reading, and by my mirror (§3.3), the scan would fail.
* **N-9. The lane's deviation from the brief.** The coordinator's brief said "a non-test item after the tests module
  fails"; the lane read the item instead. That reads strictly more, and it keeps the fail-closed cases. It was needed
  because zk.rs would otherwise fail. I agree.

## 7. Evidence I checked

* **[MEASURED]**
  * `diff -rq` and `diff -u` of all 5 changed files, r19 against r19b;
  * the r19b manifest re-check (306 / 306);
  * the manifest list digests;
  * the production text without comments, for `derive.rs` and `classify_cli.rs`;
  * the suite totals recounted;
  * the RED and GREEN logs;
  * every new mutant log re-read, plus job-order and reused-draw;
  * `r19b_mut.jsonl`, `queue2-verdicts.log` and the rejudge files;
  * the four verify logs, their guard records and `r19b_check.sh`;
  * `wrong-file.log`, `symlink.log` and the five tree hashes;
  * the byte equality recomputed against `r18/logs/eq/digests.json`;
  * the xbin log and the binary pins;
  * the `derive.rs` and `classify_cli.rs` hashes in both trees;
  * `run_capture.rs`'s pin list, and the gate's `DERIVE_T16`;
  * `cleanup-after-freeze.json`, and that `~/zk60-artifacts/token-io/r19b` and the owner directory are gone;
  * zk.rs's sha256 in 13 frozen trees, and the size of `NOT_ON_THE_BLOCK_PATH` in each;
  * my token-level after-tests scan of every `.rs` file in hashline and zkp-core;
  * the label mirror over zk.rs's regions;
  * the call graph by grep (§3.2);
  * the 121 / 45 / 76 count, and each listed file's declaration;
  * the scanner probe (P1–P14, I1–I4);
  * the rustc dep-info probe.
* **[READ]**
  * `r19b/PROGRESS.md`, the ledger's 19b section, `frozen-r19b.FROZEN.txt`;
  * REVIEW_R19 and REVIEW_R18 (§5);
  * the register's round-19, 19-review and 19b entries, D19, D19b, D24 (19b touches neither the norm rule nor the
    loader), D33, D36 and D46;
  * `derive.rs` in full;
  * `tied_tables.rs:1-70`;
  * `s25_tests.rs:1601-1800, 2020-2070, 2340-2550`;
  * `hash_domain_tests.rs:320-512`;
  * `hash_domain.rs:1-80, 380-410`;
  * the s26 diff;
  * `classify_cli.rs:60-200, 520-560, 766-800`;
  * `trained_block.rs:1632-1660`;
  * zk.rs's item list, `:325-345`, `:1940-2040`, `:2600-2670`, `:3926-3960` and the region's labels;
  * `mutate19b.py`;
  * `examples/zk60_classify.rs`.

## 8. What I did not check

* **No build of the tree, no test, no mutant, no proof and no verify.** The only exceptions are the three light
  scratch probes: at most 0.13 GiB, and 1 s each.
* **Points that rest on reading.**
  * That the R19B-1 forms get past the real suite: I ran a verbatim copy of the reader and rustc, not the mutated tree.
  * That nothing in the region is reachable: a name-level grep with the no-trait-impl, no-macro argument (§3.2), not a
    compiler call graph.
* **The native lane's trees.** I did not check zk.rs in the native lane's trees (R7 and later), which D33 names. I
  compared only the token lane's frozen copies.
* **Not checked at all:**
  * the GPU build;
  * non-x86-64 targets;
  * a receipt proved with `ZK60_MODELS` set;
  * a flagged verdict;
  * multi-chunk posts;
  * the gate's own reading after the re-pin;
  * the second, consumed-tensor pin (`derive.rs:325`): it cannot be reached without a file that passes the
    whole-file pin, and no test does that;
  * Astra's app.
* **I did not read below the files named:** no receipt segments, export tables or checkpoint bytes.
* **Not a privacy review.**
