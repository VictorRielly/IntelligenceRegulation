# Token review, round 19: E7 (where the checkpoint is read from) and REVIEW_R18's three low fixes

Reviewer: independent code review of the frozen token tree `frozen-r19/` (2026-10-30, 12:15–12:35 UTC, times from
`date -u`). Read-only, except for this file and a scratch probe in my session scratchpad. **Not a privacy review and
not a classifier-fidelity review.**

Short names: `FR19` = `results/zk60_token_io_r1_20261017/frozen-r19/hashline`; `PB` = `FR19/src/private_block`;
`TIO` = `PB/token_io`; `R19` = `results/zk60_token_io_r1_20261017/r19`; `GATE` = `ops/zkp-mvp/gate-tinyllama/scripts`.

## Verdict: ACCEPTED WITH FIXES

E7 is sound. An environment variable cannot make the verifier accept a receipt against the wrong tables. The fixes
are one missing test for that claim, one remaining gap in the module follower, and doc text.

In plain words:

* **The variable picks where the file is read from, not what is in it.** Whatever path `ZK60_MODELS` or `HOME`
  produces, the file must be a regular file of exactly 7,698,241,104 bytes. Its whole-file SHA-256 must equal the
  Shieldstral pin compiled into the binary. If not, it is refused before any table is derived. The tensor rows
  that are read a second time are hashed again against a second compiled-in pin.
* **No silent fallback.** If `ZK60_MODELS` is set and the file is not there, the verify is refused. It never falls
  back to `$HOME/models`. The lane measured this on the real receipt.
* **But no test proves the main claim.** No test or run gives the verifier a wrong file of the right size. The
  real-scale refusal used a missing directory, so it stopped at "No such file", before the hash. Nothing in the
  suite reaches the hash comparison with a file that is not the pinned one. This is R19-1.
* **E7 moves no receipt byte.** It adds no hash, no absorb and no transcript label, and the path never leaves the
  function. Round 18's job-0 digests are matched on all 30 files. I recomputed that equality.
* **The new module follower is a real improvement.** It closes the five shapes round 18 missed, and it fails closed
  on the hard cases. One placement still slips through: a module or a generator written *after* a file's
  `#[cfg(test)] mod tests { … }` block. So does an `include!`. Nothing on the path does either today. This is R19-2.
* **The claims match the logs.** The suite is 966 / 0 / 71 over 29 binaries. All 20 mutants are killed, each by its
  named test for its named reason. Exactly one capture pin moves, `derive.rs`.

### Fixes

| # | Severity | Where | Fix |
|---|---|---|---|
| R19-1 | **required before the gate re-pins `derive.rs` and before the open release relies on E7** (a test; I found no code defect) | `PB/tied_tables/derive.rs:160-198` (`Checkpoint::open`; the pin comparison at `:194`), E7 tests `:386-436` | Show that a wrong checkpoint is refused. Minimum: one more real-receipt verify in round 19's form, with `ZK60_MODELS` naming a directory that holds a **same-size wrong file**. It must exit 1 with "checkpoint SHA-256 differs from the pinned model", print the flagged app-outcome line, and leave the receipt tree hash unchanged. Recommended in addition: a test of `Checkpoint::open` on that file, plus a mutant that deletes the comparison at `:194`; the test must kill it. Detail in §2.4. |
| R19-2 | low (test hardening; R18-2 is not fully closed) | `PB/s25_tests.rs:1690-1693` (`production_text`), `:2072` (the follower reads only that text), `:2269` (so does the generator census); `PB/hash_domain_tests.rs:326, 443`; `PB/s25_tests.rs:1901-2011` (`mod_items` ignores `include!`) | Everything after a file's first `\n#[cfg(test)]\nmod tests {` goes unread, with no error: modules, functions and labels. Make the cut fail closed: what follows it must be `#[cfg(test)]` items only, or the scan panics naming the file. Refuse `include!` outside a `#[cfg(test)]` scope. Optionally, add REVIEW_R18's directory check: every `.rs` file under `src/private_block/` is in the graph or on a named list of test files. Add fixture cases and mutants for each. Detail in §4.3. |
| R19-3 | low (doc) | `PB/tied_tables/derive.rs:17-24`, and the open release's text on `ZK60_MODELS` | State four things for a stranger setting up a verifier. (1) The last component must be a regular file: a symlinked model file is refused, which includes the Hugging Face cache's snapshot layout. Directory symlinks are followed. (2) A relative `ZK60_MODELS` is resolved against the process's working directory. (3) With `HOME` unset and no `ZK60_MODELS`, the verify is refused, where round 18 used the fixed path. (4) A set variable naming a missing file is refused, never replaced by `HOME`. Each of these fails closed, so this is a usability fix, and usability for strangers is what E7 is for. |

Notes that need no fix in this round: N-1 to N-7 in §7.

## 1. What changed (items 4 and 5, first part)

* **5 paths.** I ran `diff -rq` on frozen-r18 against frozen-r19: exactly 5 paths changed, none added or removed
  [MEASURED].
* **The freeze copy is exact.** frozen-r19 re-hashes to `manifest_final_r19.sha256`: 306 of 306 files, none missing,
  none extra [MEASURED].
* **One manifest throughout.** The list digest is `91585afe…` in all of these: `manifest_final_r19`, r19A, r19B,
  green-src, postmut and final-check [MEASURED].

| File | Class | Change |
|---|---|---|
| `PB/tied_tables/derive.rs` | **production** | E7: lines 10-48 (the old line 10), and the call at `:282-283` (the old `:244-245`). Three tests at `:386-436`. |
| `TIO/classify_batch.rs` | production, **doc only** | `//!` lines 21-29 (R18-4). No code line changed. |
| `PB/s25_tests.rs` | test (`#[cfg(test)] mod s25_tests;`, `private_block.rs:308-309`) | the token follower, `production_sources` over the graph, two fixture tests |
| `PB/hash_domain_tests.rs` | test (`#[cfg(test)] #[path]`, `hash_domain.rs:746-747`) | label lane 39 → 47 files; the module check through the follower |
| `TIO/classify_r18_tests.rs` | test (`#[cfg(test)] #[path]`, `classify_batch.rs:254-255`) | one doc comment and one assertion message (R18-3) |

I checked R18-4's new sentence against the code, `classify_batch.rs:138-156`:
* `--content`, an unknown flag and a repeated flag each print one stderr line and return 2;
* every later error goes through `refused`.

The sentence is true.

## 2. E7: can the environment make the verifier accept against wrong tables? (item 1)

### 2.1 What the variable decides

* **`default_checkpoint_from`** (`derive.rs:31-38`):
  * `ZK60_MODELS`, if set and non-empty, else `HOME/models`, else an error;
  * then joins the relative constant `CHECKPOINT_IN_MODELS` (`:15`).
* **`checkpoint_path_with`** (`:43-48`): a declared `tied_embeddings.checkpoint_file` wins. The default is an
  `FnOnce`, called only when there is no declaration.
* **Its one use** is `recompute_profile` (`:282`). The resulting path goes only to `Checkpoint::open(&path)` and is
  dropped. `RecomputedTiedTables` (`:72-78`) has no path field.

### 2.2 What the verifier does with the file it opens [READ]

1. **`regular(path, CHECKPOINT_BYTES, true)`** (`derive.rs:161`; `PB/tied_tables.rs:21-46`):
   * `symlink_metadata` must show a regular file, so a symlink in the last component is refused;
   * the length must be exactly 7,698,241,104;
   * the open uses `O_NOFOLLOW | O_NONBLOCK`;
   * the opened descriptor must still be a regular file of the same length, device and inode.
2. **The header** is parsed, and the tensor and norm extents are checked; an `lm_head` is refused (`:163-171`).
3. **The whole file is hashed in one pass** (`:175-192`). In the same pass:
   * the header bytes are compared with the bytes being hashed (`:184-187`);
   * the norm weights are copied out of those same buffers (`:188-190`).

   The digest must equal `ModelSource::shieldstral_1_0_3b().weights_sha256` (`:194`). That is a compiled-in
   constant, `87753e30…` (`trained_statement.rs:157-167`). The length is checked once more (`:195`).
4. **`recompute_profile` re-reads the tensor rows** from the same descriptor. It hashes them as it consumes them,
   and the digest must equal the compiled-in `SHIELDSTRAL_TIED_TENSOR_SHA256`, `67a138c1…` (`derive.rs:303`;
   `trained_statement.rs:601`). So a file rewritten between step 3 and step 4 is refused as well.
5. **The profile cannot loosen the pins.** Its declarations must equal them: model repo, revision and sha256
   (`derive.rs:109`), and tensor name and sha256 (`:281`).
6. **Downstream:**
   * the derived digests must equal the export's own table files (`trained_block.rs:644-648`);
   * the classifier's derivation must have read the profile the statement binds (`classify_tied.rs:274-276`);
   * the margin row used is the recomputed row.

**So it fails closed.** A file at `$ZK60_MODELS/…` that is not byte-for-byte the pinned checkpoint is refused at
step 1, 3 or 4, before any table exists. No path produces "different but accepted" tables: the tables are a
deterministic function of authenticated bytes and of the profile the statement binds. The gate's own v22 reading of
this file says the same (`GATE/zk60_native_rg_classtied.py:301-317`).

### 2.3 The edge cases the brief names

* **Precedence:** the declaration comes first, and the default is evaluated only without one (`:43-48`). The
  declared path sits in `profile.json`, whose digest the statement binds. Tested at `:406-417`; the
  `e7-precedence` mutant is killed. In the real export the field is absent: the missing-directory run read the
  default.
* **Empty strings:**
  * `ZK60_MODELS=""` counts as unset, and so does `HOME=""` (`:32`);
  * both empty, or both unset, is a refusal.

  Tested at `:387-400`; the `e7-empty-is-set` and `e7-ignore-models` mutants are killed.
* **Symlinks:**
  * a symlinked *directory* anywhere in the variable, or under it, is followed;
  * a symlinked *file* in the last component is refused as "not a regular file".

  Either way the content is authenticated. This is by reading; no test covers it (R19-3, for the docs).
* **A relative path** is resolved against the process's working directory, and the content is still
  authenticated. By reading; not tested (R19-3).
* **Unset equals round 18** when `HOME=/home/victor`:
  * the pure test at `:398`;
  * the measured verify under `env -u ZK60_MODELS`.

  It differs in two cases, both on purpose and both fail-closed when no authentic file is found:
  * `HOME` unset: round 19 refuses, where round 18 used the constant;
  * another `HOME`: a different path.

### 2.4 The tests, and why R19-1 is required

* **The three E7 tests check path selection only.** `:425-436` is box-dependent. Away from this box it asserts only
  `default_checkpoint() == default_checkpoint_from(env)`, a restatement of the code; the pure test at `:398` carries
  the real check.
* **No test anywhere in `FR19` opens a non-pinned file through `Checkpoint::open`.** I searched for the refusal texts,
  for `Checkpoint::open` and for `checkpoint_file` in every test file. The suite's Shieldstral derivations are
  stubbed (`classify_tied.rs:284-290`).
* **The rung cross-verify does not touch this path.** It uses the development rung's synthetic tensor (N-1).
* **The real-scale refusal stops before the hash.** It named a missing directory, so it stopped in
  `symlink_metadata` with ENOENT (`R19/logs/verify-hate-nomodels.log`).
* **So deleting `:194` would leave the suite green.** This is by reading; I did not run that mutant.

The round's main claim ("a wrong file is refused") is therefore true by reading only.

Required:
* **(a) One more real-receipt verify** with `ZK60_MODELS` naming a directory whose
  `shieldstral-1.0-3b/snapshot-003ec7e2/model.safetensors` is a same-size wrong file. It must:
  * exit 1 with "checkpoint SHA-256 differs from the pinned model";
  * print the flagged `app-outcome` line;
  * leave the receipt tree hash unchanged.

  A **sparse** file works: exactly 7,698,241,104 bytes, a well-formed safetensors header for the two tensors (crafted,
  or copied from the real file's first bytes) and zeros after it. It takes a few KB on disk; reading 7.7 GB of holes
  costs one core for some seconds.

  In the same run, put a **symlink** to the real checkpoint at that place: it must be refused as "not a regular file".
* **(b) Recommended:** the same as a test of `Checkpoint::open` (`#[ignore]` plus a guarded run if it is slow), with a
  mutant that deletes the comparison at `:194`. If (b) lands in `derive.rs`, land it before the gate re-pins that
  file, so the gate pins it once.

## 3. E7 moves no receipt byte (item 2)

**By reading.** In `derive.rs`'s production text (above `#[cfg(test)]\nmod tests {`):
* `Sha256::new(` count: 5 in r18 and 5 in r19;
* `absorb`: 0; `transcript`: 0;
* `/home/`: 1 → 0;
* the only new calls are the two `std::env::var_os` reads [MEASURED, a count over both frozen copies].

The new code makes a path and an error string, nothing more. The path never reaches the tables, the statement or a
receipt.

**`bytes.json`** [READ, and recomputed by me from `R19/logs/bytes/bytes.json` and `r18/logs/eq/digests.json`]:
* r19's 30 files equal round 18's `single-c0`, `batch-c0` and `r16b-c0` trees exactly: 28 segments, the unverified
  `statement.json`, and `input.dec`;
* the run's own log: exit 0, 28 segments, 848,412,096 B, not-flagged, floor 96;
* fixed-entropy `block_bytes` 64, `unread_bytes` 0;
* the guard command shows `env -u ZK60_MODELS` and the r19 candidate.

**What it establishes:** for one input point, the r19 binary makes the same job-0 receipt as the r18 and r16b
binaries from the same 64 bytes of fixed public entropy. That point is:
* the moderate-sexual policy;
* chunk 0 of 1;
* Astra's public 17-id sentence;
* a not-flagged verdict;
* `ZK60_MODELS` unset, so the HOME branch, on the same path as round 18.

**Its limits.** These are round 18's limits, plus:
* **No receipt was made with `ZK60_MODELS` set.** It was only verified (accepted, exit 0).
* **It is n = 1, not a proof of equality.**
* **The other half is a reading.** That the set branch yields the same bytes rests on §2.2: the tables depend only
  on authenticated bytes.
* **It covers only the Shieldstral route.** `derive.rs` serves Shieldstral profiles alone
  (`tied_tensor_for_profile`, `trained_statement.rs:592-599`), so the TinyLlama and Llama routes are not on this path.
* **The binary differs anyway.** `841ba983…` against `110f0c53…`: source paths are baked in, and `derive.rs` moved.
  The equal receipts show that this difference does not reach receipt bytes on that point.

**The real receipt.** The real moderate-hate receipt (`r16-runs/hate-run`) hashes to tree `8a990fde…` before and after
all three verifies [READ, `hate-tree-*.json`]. The three verifies, by the guard command lines and
`R19/tools/r19_check.sh:43-57`, are the same command with different environments:
* unset: exit 0;
* `=/home/victor/models`: exit 0;
* a missing directory: exit 1, the path named, flagged.

## 4. The R18-2 module follower (item 3)

### 4.1 How I tested it [MEASURED]

* **The copy.** I copied `PB/s25_tests.rs:1688-2085` verbatim into a scratch program (copy sha256 `779244e4…`;
  probe `4eba3241…`, in my session scratchpad `r19probe/`).
* **The build and runs.** It was compiled with rustc 1.97.1 under light guards: `review19-follower-build`, 0.11 GiB,
  1 s; then `review19-follower-probe`, under 0.01 GiB and under 1 s, and its rerun `-2`.
* **On the real tree.** The copy finds **47 files and 45 edges** on frozen-r19, the census's asserted numbers.
* **On fixtures.** I then ran it on fixture trees of shapes the round's own tests do not contain.

### 4.2 Coverage

| Form | r19 reader | Evidence |
|---|---|---|
| `mod x;` with any visibility: `pub`, `pub(crate)`, `pub(super)`, `pub(self)`, `pub(in …)` | followed | round's fixture test; suite passes |
| one line or several, `;` on the next line, line / doc / block comments anywhere | followed | fixture test |
| `#[path]` in any attribute order, a raw-string path, a subdirectory path | followed | fixture; probe P5b, P5c |
| `#[path]` that is absolute, has `..` / `.` / an empty segment / a backslash, is not a literal, or appears twice | refused, naming the file | fixture |
| `path` inside `cfg_attr`, at any nesting | refused | fixture; P6a |
| `#[cfg(test)]` in any attribute order | test-only, skipped (correct) | fixture |
| `cfg(not(test))`, `cfg(any(test))`, `cfg_attr(…, cfg(test))` | followed (over-scan, safe) | P6b-d |
| inline `mod x { … }` | no file. A file module inside it is refused unless the inline module is `#[cfg(test)]`, so rustc's nested-`#[path]` rules are never needed | fixture; P8 (a `#[cfg(test)]` file module inside a production inline module is refused: over-strict, safe) |
| a file module in a function, block or macro body; `macro_rules!` with `mod` under `{}` / `()` / `[]`; `$v mod $n` | refused | fixture; P4a-d |
| `mod r#x;` / the identifier `r#mod` | followed as `x.rs` / not a keyword | P5a; read `s25_tests.rs:1845-1852` |
| rustc's mod-rs rules (`lib`, `main`, `mod.rs`, and any `#[path]`-loaded file keep their plain children beside them; other files under `<stem>/`); a module with two files | as rustc; two files refused | fixture; P11 |
| unterminated comment or literal, an unbalanced brace; the cut text inside a raw string or block comment | refused | fixture; P7a, P7b |
| `unsafe mod` (rustc rejects it) | refused | P9a |
| **a module after the file's `#[cfg(test)]\nmod tests { … }` block** | **not seen, no error** | **P1, P1b** |
| **`include!("file.rs")` in production text** | **not followed, no error** | **P2** |
| **a macro defined outside the scanned files that expands to `mod x;`; attribute or proc macros** | **not seen** (a token reader cannot expand them) | **P3** |

### 4.3 The gap (R19-2)

**`production_text` cuts the file.** It cuts at the first `\n#[cfg(test)]\nmod tests {` and drops the rest
(`s25_tests.rs:1690-1693`). Three readers use only the cut text:
* the follower (`:2072`);
* the generator census (`:2269`);
* the label scan's module check and label extractor (`hash_domain_tests.rs:443, 326`).

Rust allows items in any order. So each of these is compiled into production while every scan stays green:
* a `#[path = "plant.rs"] mod plant;` after a file's test module;
* a plain `fn` calling `ZkRng::new` after it;
* an `absorb(b"x", …)` after it.

**The layout already exists on the path.** Four graph files have items after their `tests` module today:
* `accuracy_tables.rs:100`;
* `accuracy_aligned.rs:114`;
* `accuracy_precision.rs:136`;
* `trained_accuracy.rs:416`.

My probe printed their top-level tokens, and all four are `#[cfg(test)] mod …_tests { … }`. So nothing is hidden
now [MEASURED].

**`include!` splices a file's code in without any `mod`.** Today the only `include!` on the path is inside the
`#[cfg(test)] mod capture` at `private_block.rs:1332-1339`, so a refusal outside test scopes would pass as is.

**Why the mutants did not find it.** The round's mutants hide the generator only behind the five shapes, all
placed before any test module (§4.4), so none probes these placements.

Fix: see the table. The cheapest complete form has two parts:
* the cut fails closed unless only `#[cfg(test)]` items follow it;
* `include!` is refused outside `#[cfg(test)]` scopes.

Add a fixture case and an `-u` / `-l` mutant pair for each:
* a module after `derive.rs`'s test module;
* a bare generator `fn` there;
* an `include!`.

For a macro that expands to a module, only REVIEW_R18's directory check closes the in-tree case.

### 4.4 The ten R18-2 mutants [MEASURED: I re-read every log with my own patterns]

* **The planted file.** Each mutant adds a new production file holding `crate::zk::ZkRng::new(7, b"r19-plant")`,
  declared from `TIO/classify_cli.rs` in one of the five shapes (`R19/tools/mutate19.py:57-63, 93-99`):
  * one-line `#[path]`;
  * a comment between `#[path]` and `mod`;
  * `pub(in …)`;
  * `pub(self)`;
  * a plain `mod` that resolves to `classify_cli/r19_plant.rs`.
* **`-u` (production change only):**
  * the census fails at its edge-list assertion (`s25_tests.rs:1651`, "the production module graph of the path
    moved");
  * the label scan fails at `hash_domain_tests.rs:450` ("declares the production module …r19_plant.rs").

  Two tests FAILED, exit 101, no compile error.
* **`-l` (the edge and the count 47 → 48 also added to s25):** the census itself reports
  "…r19_plant.rs: the path constructs a generator with `ZkRng::new`" (`s25_tests.rs:2271` in the frozen tree; `:2272` in the mutated file, one edge line longer). One test FAILED, exit 101.

So a generator hidden behind each of the five shapes is caught, whether or not someone lists the edge without
reading the file. They do not cover the placements in §4.3.

## 5. The suite and mutant claims (item 4)

**Suite** (`R19/logs/s24-suite.log`) [MEASURED, recounted]:
* 29 `test result` lines, all `ok`: **966 passed, 0 failed, 71 ignored**, 0 filtered, no `FAILED` line;
* the guard record: `tio19-s24-suite`, cpu need 11 / cap 12, exit 0, peak RSS 7.78 GiB.

These tests pass in it:
* the five r19 tests;
* the census (`no_profile_on_this_path_can_obtain_a_generator_other_than_from_the_operating_system`);
* the label scan;
* both r18 census tests.

**Mutants: 20 / 20 killed as named** [MEASURED]:
* **18 test-killed:** each compiled (no `error[E…]`, no "could not compile"), exited 101, and its named test(s)
  FAILED with the named reason in the log:
  * the E7 three: "ZK60_MODELS set: the checkpoint is under it", "… EMPTY counts as unset", "a declared
    checkpoint_file wins …";
  * round 18's five on the r19 tree;
  * the ten R18-2 mutants.
* **`job-order`:** exit 101, "job 0: the batch's run directory is not the single prove's byte for byte", unread 0.
* **`reused-draw`:** exit 97, `unread_bytes` 224 of 256.

**Other records:**
* The tree after the mutants equals the tree before (premut = postmut, `91585afe…`).
* The lane's checker bug (cargo's "error: test failed" counted as a compile error) was real. The re-judge
  (`rejudge19.sh`) copies the chain's test and reason maps and applies the fixed rule, and my independent re-read
  agrees with it.
* **RED** (`red.log`): exactly the three predicted tests FAILED, 2 passed.
* **GREEN** (`green.log`): 158 / 0 / 24.
* The release binary re-hashes to `841ba983…`, equal to `cli/binaries_r19.sha256` [MEASURED].

## 6. Gate pins that move r18 → r19 (item 5)

* **Capture source pins:** 72 = 38 `OWN` + 29 `SHARED` + 5 `CLASSIFY` (`run_capture.rs:221, 170, 3043`).
  `run_capture.rs` is unchanged, so the lists are equal in both trees. Of the five changed paths, only `derive.rs` is
  in any list [MEASURED, a parse of the three lists]. So exactly one pin moves:
  * `src/private_block/tied_tables/derive.rs`
    `c5bec3c676e635aab1c609fdf2f541d003e14d7a50efc36d0fed42fc85b7d981` →
    `4b53222b37820936821eea2fd506ff3dee991e2474d39a3b21f1c0c10d357d75`.
* **Gate v23 pin table:** `DERIVE_T16 = c5bec3c6…` at `GATE/zk60_native_rg_r13_pins.py:195`, used at `:230` and in
  the chain entry at `:482`. All three copies (`scripts`, `frozen_v23`, `staging_v23`) are `99418fb3…` [MEASURED].
* **`GATE/zk60_native_rg_classtied.py`** (`bf929b44…`):
  * `SHIELD_DEFAULT_CHECKPOINT` at `:334`, used at `:414`: to mirror E7. See N-2 on the empty-string rule;
  * the reading comment at `:303` cites `derive.rs (c5bec3c6)` and line ranges that shift by +38 after line 10.
* **The CLI binary a P-18 capture records:** `110f0c53…` → `841ba983…`.
* **Nothing else moves.** None of the other four changed files is named in any gate `*.py`, `*.json` or `*.sh`
  [MEASURED, grep]. `Cargo.toml`, `Cargo.lock`, `run_capture.rs`, `plane_index.rs` and every other file are
  byte-unchanged (`diff -rq`).
* **Already owed from round 18, not moved by r19:** `src/private_block.rs` (`96c1cd16…`) and `run_capture.rs` against
  their v23 pins. The gate re-pins 18 and 19 together, after R19-1 if (b) touches `derive.rs`.

## 7. Notes (no fix needed in this round)

* **N-1.** `xbin-r19-r18.log` (both ways, exit 0) runs on the development rung's tied source (`TiedSource::DevRung`).
  It does not pass through `derive.rs`. E7 at the verifier is exercised only by the three real-scale verifies.
* **N-2. Gate mirror.** `classtied.py:414` reads `decl.get("checkpoint_file") or SHIELD_DEFAULT_CHECKPOINT`, so Python
  treats `checkpoint_file: ""` as absent and uses the default. Rust refuses it: `PathBuf::from("")` fails in `regular`.
  When mirroring E7, also mirror:
  * `ZK60_MODELS=""` is unset;
  * `HOME=""` is unset;
  * neither set is a refusal;
  * set but missing is a refusal.

  This is not a soundness point, since both sides authenticate the bytes.
* **N-3.** `FR19/src/export.rs:42` still defaults to an owner path (`M125_EXPORT_DIR`, else
  `/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl`). It is not on the token path and not in E7. It
  belongs in the open release's path inventory.
* **N-4.** The register entry "Token round 19 frozen" shortens R18-3's limit to "≤ 22 jobs", which reads as covered.
  The freeze note says the reverse: nothing over 3 jobs at real scale, and effects up to 22 jobs unmeasured. This is
  register wording, the coordinator's.
* **N-5.** `TIO/classify_cli.rs:84-86` (single `prove`) still says "every refusal prints" the fail-closed line. That is
  the imprecision R18-4 fixed in `classify_batch.rs` (the lane's own note 1). Fold it into the next round.
* **N-6. The census's call pattern, before this round.** `zkrng_members` (`s25_tests.rs:2249-2266`) matches the text
  `ZkRng::`. These would not be seen:
  * a type alias or a renaming `use` (`type R = ZkRng; R::new(..)`);
  * `ZkRng ::new` with a space.

  This is the same class as the label scan's "computed label". It is outside R18-2.
* **N-7.** `results/zk60_open_release_20261030/prep/E2_NOTES.md:112-117` lists the bytes' authentication as the
  length, the declaration pin and the consumed-tensor compare. It omits the whole-file SHA-256 that the code also
  checks (`derive.rs:194`). The code is stronger than the note. `derive.rs:10-14` states it correctly.

## 8. Evidence I checked

* **[MEASURED]**
  * `diff -rq` frozen-r18 / frozen-r19, and `diff -u` of `derive.rs`;
  * frozen-r19 re-hashed against `manifest_final_r19.sha256` (306 / 306);
  * the six round manifests' digests;
  * byte equality recomputed from `bytes.json` against all three r18 trees;
  * suite totals recounted from `s24-suite.log`;
  * every `mut-*.log` re-read: exit codes, FAILED lines, reasons, compile errors;
  * the release binary re-hashed;
  * `derive.rs` production-text counts;
  * the capture-pin lists parsed;
  * gate script hashes, and a grep for the changed files;
  * the follower probe (§4);
  * `stat` of the checkpoint: a regular file, 7,698,241,104 B, 1 link.
* **[READ]**
  * `r19/PROGRESS.md`; the round-19 section of the main ledger; `frozen-r19.FROZEN.txt`; the R18-3 insertion in
    `frozen-r18.FROZEN.txt`;
  * the register's round-18 and round-19 entries, D24, D45, D46, D48;
  * REVIEW_R18 and REVIEW_R16 (for format);
  * E2_NOTES (E7);
  * all of `derive.rs`; `tied_tables.rs:1-70`;
  * the loader's tied-table checks (`trained_block.rs:600-648`);
  * `classify_tied.rs:1-140, 255-300`;
  * the `ModelSource` and tensor pins in `trained_statement.rs`;
  * the follower and both fixture tests in full; the census at `s25_tests.rs:2212-2330`;
  * the label scan at `hash_domain_tests.rs:318-460`;
  * `classify_batch.rs:1-30, 134-175`;
  * `mutate19.py`, `mutcheck.py`, `rejudge19.sh`, `r19_check.sh`;
  * the verify, bytes and guard records;
  * `pins_r18_r19.json`;
  * the gate's `r13_pins.py:190-200` and `classtied.py:298-336, 412-416`.

## 9. What I did not check

* **No build of the tree, no test run, no proof, no verify and no mutant run.** The only exception is the scratch
  follower probe: two light guarded jobs of at most 0.12 GiB.
* **"Deleting `derive.rs:194` survives the suite" is a reading** (R19-1). So is "the after-tests placements and
  `include!` survive the census" (R19-2), although the probe ran the verbatim follower on such fixtures.
* **I did not read the checkpoint's bytes.** Only `stat`. I did not build a wrong-checkpoint file.
* **I did not read below the files named:** the receipt's segments, the export's table files and `~/zk60-artifacts`.
* **Not checked:**
  * the GPU build;
  * non-x86-64 targets: there `regular` relies on the `lstat` and inode checks without `O_NOFOLLOW`, by reading;
  * a receipt proved with `ZK60_MODELS` set;
  * a flagged verdict;
  * multi-chunk posts;
  * the gate's own B-3 check under E7;
  * Astra's app.
* **Not a privacy review.** The Shieldstral T128 privacy statement is still a draft (register, privacy gate round
  23).
