# Token review, round 18: the A5 one-load batch (`zk60_classify prove-batch`)

Reviewer: independent code review of the frozen token tree `frozen-r18/` (2026-10-30, 09:21–09:40 UTC, times from
`date -u`). Read-only except this file and one scratch probe in my session scratchpad. **Not a privacy review and not a
classifier-fidelity review.**

Short names used below: `FR18` = `results/zk60_token_io_r1_20261017/frozen-r18/hashline`; `TIO` = `FR18/src/private_block/token_io`;
`R18` = `results/zk60_token_io_r1_20261017/r18`; `A5C` = `results/zk60_astra_20261026/a5_batch_candidate` (Astra's app half).

## Verdict: ACCEPTED WITH FIXES

The native code of round 18 is sound to adopt. I found no defect in the frozen tree that lets a batch make a receipt the
single proves would not make, or that shows a verifier more about the hidden content than a single prove does. One fix is
required before the app switches to `prove-batch`, and it is on the app side, outside the frozen tree. The other fixes
are low: tests and records.

In plain words:

* **Each proof in a batch is still its own proof.** Each job calls the same `prove_with_public` that a single `prove`
  calls. Each job makes its own two fresh draws from the operating system, its own seal, transcript, witness source and
  block readers. All of these are locals of the job and are dropped when it returns.
* **What the jobs share cannot be changed by a job.** They share three things, all lent read-only: the one digest pass,
  the one table derivation and the content. The only thing a job writes is the batch's list of directories to remove.
* **Every block reload is still checked against the digest pass:** 78 per job (26 in the CLI's sealing pass, 52 in the
  prover's two passes).
* **Verify, input-owner and label are byte-unchanged.** The single `prove` path changes only by one earlier, pure
  refusal check. The reviewed r16b binary gives the same bytes for job 0.
* **A refused batch now removes every earlier job's receipt, statement and `input.dec`** (A5 fix 1, native part). This
  works only when the batch returns an error. A kill, a panic (release builds abort), running out of memory, a
  disk-low kill or a crash skips it. The crash at 02:50 left two finished receipts on disk. So the app's quarantine is
  mandatory, and it is not yet in the app.
* **The randomness and label scans now read the two batch files** (A5 fix 2), and the planted mutants are killed. The
  new file follower misses some ways of writing a `mod` line; I confirmed this by running it.
* **The byte-identity test is a real test with clear limits.** It shows that for one public post (three jobs of one
  chunk each), given the same 64 bytes of entropy per job, each batch job writes the same 30 files as its single run. It
  is one input, not a proof that batch and single are the same function. The records do not yet state its limits.

### Fixes

| # | Severity | Where | Fix |
|---|---|---|---|
| R18-1 | **required before the app adopts `prove-batch`** (app side; not in `frozen-r18`) | native: `TIO/classify_batch.rs:19-20, 83-96`, `FR18/Cargo.toml:53` (`panic = "abort"`); app half: `A5C/batch_cleanup.py:63-103`, `A5C/batch_request.py:175-200`; target `apps/proven-media/` (no batch code there yet) | Wire Astra's terminal collector and quarantine into the app's batch path. The app must also run the quarantine on restart: a batch with no guard record and no `batch-proved` is quarantined before any retry or new post. Then review that app half. Detail in §4. |
| R18-2 | low (test hardening) | `FR18/src/private_block/s25_tests.rs:1695-1720` (`path_children`), `:1611-1625` (only one level of plain `mod` children); `FR18/src/private_block/hash_domain_tests.rs:419-428` | Make the module follower fail closed for every `mod x;` declaration, however the line is written. Detail in §5. |
| R18-3 | low (records) | `frozen-r18.FROZEN.txt` "bytes:" line; register entry "Token round 18 frozen"; `TIO/classify_r18_tests.rs:203-206, 215` | State the limits of the byte-identity test (§6). Correct the reload count: 26 + 52 = 78 per job, not "once in its proving pass" (true only at L = 1) and not the A5 review's "2 × 26 = 52". |
| R18-4 | low (doc) | `TIO/classify_batch.rs:21-23` vs `:133-146` | The module text says every refusal prints the fail-closed line. Argument refusals (exit 2: `--content`, unknown or repeated flag) print none. This matches single `prove`, and the router fails closed on any non-zero exit. Correct the sentence. |

Notes that need no fix in this round: N-1 to N-6 in §7.

## 1. What changed, file by file (item 1)

I diffed `frozen-r18` against `frozen-r17` and `frozen-r16b` (`diff -rq`, then `diff -u` of each file). `frozen-r18`
re-hashes to `manifest_final_r18.sha256`: 306 of 306 files, none missing or extra [MEASURED].

**r17 → r18** (5 changed, 3 added):

| File | Class | What it does |
|---|---|---|
| `examples/zk60_classify.rs` | production | header text, plus one `prove-batch` dispatch arm; the other four subcommands are unchanged |
| `src/private_block.rs` | production | one `pub use` gains `classify_prove_batch_command` (line 142); no behaviour change |
| `TIO/classify_cli.rs` | production | module text (lines 13-27); `#[path] mod batch` (536-538); `SharedProve` (544-549); `prove_inner` becomes `prove_with_public(f, None)` (551-553). Inside the prove path: `p`, `bound` and `whole` are borrowed in batch mode, otherwise loaded as before (571-595); one added `bound.check_for` (589); one counter read (612); `claim.hold` in batch mode only (652-654). All diff hunks end before line 660. |
| `TIO/classify_batch.rs` (new) | production | the command: request reader, preflight, one load, job loop, `BatchClaim` |
| `TIO/classify_batch_plan.rs` (new) | production, plus its own `#[cfg(test)] mod tests` (13 tests) | plan coverage and path checks; no proof code |
| `src/private_block/s25_tests.rs` | test | the `#[path]` follower, the edge list, two r18 tests |
| `src/private_block/hash_domain_tests.rs` | test | label lane 36 → 39 files, plus a `#[path]` follower check |
| `TIO/classify_r18_tests.rs` (new) | test | registered by `#[cfg(test)] #[path]` (`classify_batch.rs:248-250`) |

**r16b → r17, carried into r18:**
* `run_capture.rs` and `plane_index.rs` are both `#[cfg(test)]` modules (`private_block.rs:258-269`).
* `classify_capture_tests.rs` is `#[cfg(test)]`.
* `gate19_capture_tests.rs` and `classify_r17_tests.rs` are `#[path]` children of that test module (`classify_capture_tests.rs:853`, `gate19_capture_tests.rs:458`).
* `s25_tests.rs` is test code.

So r17's production code is r16b's, and the reviewed production baseline is r16b. The register records round 17 as
coordinator-checked (test-only).

**Staged → frozen.** I also diffed Astra's staged files against r18. The lane's changes match its ledger:
* `Spec` (a fixed profile, T and policy list; production passes `SHIELD_T128` only);
* the overlap taken from `chunk_overlap_of` (= 8 at T128, `classify.rs:279-290`);
* the repeated-flag refusal;
* the per-target `NOFOLLOW_NONBLOCK` (0o400000 | 0o4000 is O_NOFOLLOW | O_NONBLOCK on x86-64 Linux);
* the counted loads;
* `BatchClaim`.

## 2. Fresh randomness and shared state (item 2)

**Per job.** `batch_inner` calls `prove_with_public(jf, Some(SharedProve { p, bound, whole, claim }))` for each job
(`classify_batch.rs:232-239`). Inside, everything that carries randomness or private data is a local of that call:
* the job's own `Claimed` (`classify_cli.rs:564-567`);
* `seq` (569);
* the sealing reader `seal_blocks` (610), dropped at 613;
* the stage witnesses (605, 620-621);
* the seal: `seal_input` → `endpoint_g::prepare`, its own `ZkRng::from_os` (`classify.rs:821-825`);
* `disk` (629);
* `src: CliSource` (630);
* the proving reader `blocks` (631);
* the run prover's own generator and transcript (`classify_run.rs:146` `ZkRng::from_os`; `:149` `st.transcript()`).

`owner: CommittedZk` is moved into the prover. `CommittedZk` derives no `Clone` (`zkp-core/src/pcs.rs:591`), so a
seal cannot be used twice without new code. `ZkRng` is neither `Clone` nor `Copy`; that is a test with controls,
`s25_tests.rs:1905`. `from_os` opens `/dev/urandom` and `read_exact`s 32 new bytes on every call (`zkp-core/src/rng.rs:30-51`).

**Shared, and read-only.**
* `p: &ExportPublic`. Plain data (`load.rs:197-205`, `trained_block.rs:862-894`): no file handle, no cell.
* `bound: &BoundClassifierTables`. Private fields, no interior mutability (`classify_tied.rs:383-398`).
* `whole: &[u64]`, the content.
* `claim: &mut BatchClaim`, which holds only `PathBuf`s and reload counts (`classify_batch.rs:66-81`).

I swept the frozen tree's non-test sources (hashline and zkp-core) for `Cell`, `RefCell`, `Mutex`, `RwLock`,
`OnceLock`, `OnceCell`, `LazyLock`, `thread_local`, `static mut` and `Atomic*`. No hit is in a round-18 file.
* The private-block hits are `#[cfg(test)]`: `protocol.rs:548,600,837`, `witness.rs:94`, `argument.rs:84`, `timing.rs:49`.
* `parity.rs:61` caches a constant public table.
* No private-block file names `wcache::`, `pcs_compact::`, `phase_profile::` or `attention_schedule::`.
* For the `zk.rs` / `layer.rs` FFN pools I rely on the A5 review and the capture's own note (`run_capture.rs:212-213`).

**One table derivation for three policies is correct.**
* The derivation reads only the export profile's (yes, no, scale, c) (`classify_tied.rs:252-271`).
* `check_policy` requires every policy to equal those four values (`:193-200`).
* `check_for` repeats that check for each job: in the preflight (`classify_batch.rs:224`) and again in the job (`classify_cli.rs:589`).
* The statement constructor checks the binding as well.

**Every block reload is digest-checked.** `ExportTokenBlocks::block` compares each reload with `p.digests[k]` from the
one digest pass (`load.rs:269-288`). The readers are per job, so the one-block cache is per job too.

Measured per job: `seal_block_loads 26`, `prove_block_loads 52` (`R18/logs/eq/batch.log`). The 52 is the run prover's
own sealing pass plus its proving pass on the same reader (`classify_run.rs:135-140, 179`). At the rung (L = 1) the
second visit hits the one-block cache, which is why the round's test expects `(1, 1)` (R18-3).

**Not shared, never read again.** The tables are not re-read from disk per job, and the request and content are read
once. Rule 3 was ruled for one post in one process (register, "A5 one-load batch"). The command enforces it: one
request and one content, and a repeated flag is refused (`classify_batch.rs:141-146`). A library caller that calls
`classify_prove_batch_command` twice reloads everything, because `p` and `bound` are locals of `batch_inner`. No table
can cross posts even in one process.

## 3. Verifier, input-owner and label (item 3)

* **`classify_cli.rs`.** The r17 → r18 diff has six hunks, all at or before line 660, so all in the prove path or the
  module text. `check_run`, `door`, `classify_verify_command`, `verify_inner`, `classify_input_owner_command`,
  `classify_label_command`, `expect_total_of`, `label_inner` and `aggregate_label` (lines 699-914) are byte-unchanged.
  So are `render`, `found_statement` and the `Writer` rendering they share with prove.
* **Every other file of the verifier.** Unchanged, by `diff -rq`.
* **The single prove path.** It gains `bound.check_for` (589), which is pure: no randomness, no transcript, no output.
  It only moves a refusal that the statement constructor already makes ahead of the content read. Draw order and
  transcript order are unchanged.
* **Measured.** The reviewed r16b binary `dfb8025e…` and the candidate single, both fed job 0's 64 bytes, gave equal
  bytes across all 30 files (`R18/logs/eq/compare.log`, `digests.json` sha256 `2f173f1d…`; I re-read the digests).

## 4. A5 fix 1: no finished-looking output after a failure (item 4)

**Native part, by reading.**
* A job's three directories join the batch's claim right after the rename. The job's own claim is released only after
  that, at `classify_cli.rs:648-655`. Nothing fallible runs between the two.
* Any later `Err` returns from `batch_inner`. `BatchClaim` drops before `refused()` prints, and removes the paths
  latest first, with a `removed` line each (`classify_batch.rs:83-96`).
* The claim is released only after the last job (`:240-242`).
* Every path the claim removes was created atomically by this process (`Claimed::dir`, `classify_cli.rs:159-174`). So
  no rival's directory is removed. `remove_dir_all` does not follow a top-level symlink.

**Native part, measured.**
* Fail-closed control at real scale (`R18/logs/eq/fail.log`, `fail_check.json`; I read both): child_rc 1; job 0
  `proved`; job 1 `loaded`; six `removed` (job 1's three, then job 0's three); `refused`; `app-outcome` flagged; no
  `batch-proved`; nothing left in either directory.
* The rung control `r18_a_failed_batch_leaves_no_receipt_statement_or_decommitment_behind` passes in s23. The
  fix1-revert mutant is killed by it (`R18/logs/r18_mut.done`).

**What it cannot cover (R18-1).** The release profile is `panic = "abort"` (`FR18/Cargo.toml:53`). So the claim's
`Drop` does not run on:
* a panic, including a `println!` to a closed stdout;
* an allocation abort;
* the kernel memory cap;
* a guard kill, including D46's disk-low kill;
* a machine crash.

The crash at 02:50 shows it: the pre-crash run left `a5eq-c0` and `a5eq-c1`, each finished with its statement and
`input.dec`, plus `a5eq-c2.incomplete` (`R18/logs/eq.crash-20261030/precrash_cleanup.json`). The module text says so
(`classify_batch.rs:19-20`).

The app half exists only in Astra's candidate directory:
* `collect_batch_result` requires the guard record and quarantines on any failure (`A5C/batch_request.py:175-200`);
* `quarantine` renames every prepared path aside, under a lock, restartably (`A5C/batch_cleanup.py:63-103`).

`apps/proven-media` has no batch code yet (searched). The register says the app stays on the per-category path until
this review. Required for adoption:
* (a) the app's batch path goes through `collect_batch_result`;
* (b) at queue start-up, any batch whose `cleanup-scope.json` has no terminal record is quarantined before any retry;
* (c) that app code is reviewed.

For that review: quarantined receipts stay under the receipts root, in `<receipts>/.batch-quarantine/`, mode 0700
(`batch_cleanup.py:80-83`). They are still valid receipts. Check that nothing publishes, syncs or anchors that directory.

## 5. A5 fix 2: the randomness and label scans read the new files (item 5)

**What now holds** [READ; s23 passes them; the mutants are in `R18/logs/r18_mut.done`]:
* `production_sources` follows production `#[path]` children transitively and deduplicates them. It asserts the exact
  edge list of five edges (`s25_tests.rs:1655-1688`). Both batch files are scanned once, and the r18 test module is not
  (`:1874`).
* The generator census runs over them (`:1778-1860`):
  * any `ZkRng::` constructor other than `from_os` fails;
  * any mention of `ZkConfig` fails;
  * the `from_os` count must be exactly 7.

  So a seeded generator or an extra fresh one in either batch file fails the census. The rng-plant mutant is killed.
* Moving the run's generator out of `prove_classify_run_with` to share it across jobs breaks the one-construction-per-body check (`:1905-1960`).
* The label scan adds `classify_cli.rs`, `classify_batch.rs` and `classify_batch_plan.rs`. It checks that every
  production `#[path]` child of a listed file is listed (`hash_domain_tests.rs:368-428`). A literal label outside the
  table fails.

**Would they catch a reused draw?**
* A reuse made by a new or shared generator: yes (above).
* A reuse inside zkp-core (`from_os` caching its 32 bytes for the whole process): the census does not look at that.
  The lane killed that mutant with the fixed-entropy harness only (unread 224 of 256 bytes).
* By reading, the ordinary suite also catches it: `zero_witness_tests.rs:184`
  (`two_zero_witness_proofs_differ_in_their_bytes_and_both_verify`) makes two proofs of one witness in one process
  and asserts that their bytes and endpoint roots differ. I did not run that mutant.

**Would they catch a new unlabelled absorb?** A literal label not in the table, on the same line as the `absorb`, in
any of the 39 files: yes. Not caught, as before and as the test itself says:
* a computed label;
* a label on the next line;
* a label that is already in the table.

The label-plant mutant was killed through an artefact: the scan read `, b` out of the planted text
`("absorb", b"r18-...")`. A realistic `tr.absorb(b"r18-x", ..)` would extract `r18-x` and also fail. I read the
extractor (`hash_domain_tests.rs:325-339`).

**The gap (R18-2)** [MEASURED]. I copied `path_children` verbatim into a scratch program, compiled it under a light
guard (`review18-pathchildren`, 0.07 GiB, 1 s) and ran it on seven declaration shapes. Only the two-line control was
found. These were all missed:
* the one-line `#[path = "x.rs"] mod x;`;
* a doc or line comment between `#[path]` and `mod`;
* `pub(in …)` and `pub(self)`.

Also, a plain `mod x;` in a token-io file such as `classify_cli.rs` (file `token_io/classify_cli/x.rs`) is read by
neither scan. `production_sources` reads only one level of plain children (`:1611-1625`), and the label lane is an
explicit list.

The edge-list assertion compares only the edges the reader finds, so none of these shapes fails it. All are valid
Rust. Today's files use the two-line form, so nothing is missed now.

Fix: in every scanned production file, resolve every `mod <name>;` declaration of any shape to a scanned file, or
prove it test-only; otherwise fail. Or compare the scanned set with a directory listing of `src/private_block/**/*.rs`
minus a named list of test files.

## 6. The byte-identity evidence (item 6)

**Method.** The real release binaries ran under bubblewrap, with `/dev/urandom` bound to a FIFO of fixed public 32-byte
blocks (`R18/tools/run_fixed.sh`).

The method is sound for what it measures:
* every `from_os` reads exactly 32 bytes with `read_exact` on an unbuffered `File` (`rng.rs:33-47`);
* the harness reports unread bytes and exits 97 on any;
* an extra draw would block until the guard ends it.

The sanity runs show the route works inside the guard's scope (`R18/logs/sanity.log`). They also show that a skipped
draw is detected (`sanity-skip.log`). The review's original sanity command used a buffered reader and hung: a command
error, not a route error.

**What it shows** [READ the logs, guard JSONs and `digests.json`; I recomputed equality from `digests.json`]:
* For one post (Astra's public 17-id sentence: three jobs, one short chunk each, all not-flagged), each batch job's 28
  segments, unverified `statement.json` and `input.dec` equal the single prove's, given that job's 64 bytes.
* No segment is shared between jobs.
* The batch read exactly 192 bytes, and each single read 64; nothing was unread.
* The r16b binary equals the candidate for job 0.
* Every entropy byte was used, in job order. Nothing else that reads `/dev/urandom`, and no other randomness that
  reaches the bytes, enters the outputs. Otherwise the batch and the separate single processes would differ.
* The pre-crash c0 and c1 equal the rerun's (`crossrun_precrash_vs_rerun.json`).
* The receipts pass the reviewed binary's nine fresh checks (`fresh_result.json`: all 0).

Together with the reading in §2, which found the same `prove_with_public`, the same inputs and only borrowed values
equal to fresh loads, this supports "the batch computes what the single proves compute."

**What it does not show** (R18-3: the freeze note and the register entry state none of this):
* It is one input point, not a proof of function equality.
* At real scale there is one chunk per category. Multi-chunk posts (more than 3 jobs, up to 22) are untested; the rung
  test covers 2 chunks of one policy at L = 1.
* Only not-flagged verdicts were seen.
* The r16b control covers job 0 only.
* Nothing about the quality of production entropy is shown, only the draw count and order. A FIFO also cannot tell
  "open per draw" from "one descriptor, 32 bytes per draw"; both are fresh.
* Effects that grow over 22 jobs (allocator growth, time to the guard's limit) are not covered.
* Timings are n = 1 on a shared box.

## 7. Other ways a batch could differ from singles (item 7), and notes

**No path found to an accepted receipt that the singles would not produce.** The verifier is unchanged and decides from
the receipt and its own export copy, so a batch receipt is accepted exactly when the same bytes from a single would be.
Changes to files during a batch are refused or harmless:
* a block file changed mid-batch fails its reload digest check;
* a tables file changed mid-batch is not re-read, and the in-memory values are the authenticated ones;
* the content is read once, so every chunk of the post uses the same content (stricter than singles);
* activations are per job and parity-checked in the sealing pass.

**No extra disclosure found.** Stdout carries the same per-job events as single proves, plus `batch-loaded` and
`batch-job-*` with public values only: job count (a function of the public N), names, policy, chunk and reload counts.
The context label is the deployment constant, so it is the same for single and batch.

A failure at job k leaves jobs 0 to k-1's verdicts in the log. Singles would print the same verdicts. The router
returns nothing for an incomplete stream (`A5C/batch_request.py:270-277`).

D45(2) is preserved: one fixed list in D37 order, every chunk exactly once (`classify_batch_plan.rs:27-44`). A retry
re-proves the same items under the same policies. Its earlier receipts are removed natively, or quarantined by the app.
If both sets were ever published, a verifier would see two runs of each item. That is the app point in R18-1.

**Notes (no fix needed in this round).**
* **N-1.** The reused-draw mutant is very likely also killed by the ordinary suite (§5), by reading. A classifier-path
  test is worth adding: two proofs of the same item in one process must differ in bytes and in the input root. That
  property is what the batch now relies on.
* **N-2. A5 notes not addressed in r18.** All fail closed and are carried forward:
  * note 6: repeated or wrong `sequence_dir`s are found only at their own job. The fail control lost job 0's 7.6
    minutes; a 22-job post could lose about 2.7 hours.
  * note 8: content, request and sequence directories under a receipt parent are not refused natively. The app keeps
    them in the 0700 job directory.
  * note 7, second half: the request's owner uid is not checked.
  * note 12: memory and time over 22 jobs are unmeasured. At 3 jobs, peak RSS was 8.16 GiB against 8.13-8.21 GiB for
    the singles; cgroup 11.2 of the 11.5 GiB cap, page cache included.
* **N-3. Operations for a large post.** A 22-job batch is one guarded job of about 2.8 hours that writes about 18.7 GB
  of receipts: 22 × 848,412,096 B [COUNTED]. It therefore needs:
  * a `--max-secs` budget that covers it;
  * D46's announcement for jobs writing over 10 GB;
  * enough free space on C:.

  A disk-low or time-limit kill in the middle is the R18-1 path.
* **N-4.** The router checks `model_loads` and `table_loads`, not the per-job `seal_block_loads` / `prove_block_loads`
  (expected L and 2L; A5 note 9's suggestion). This is optional.
* **N-5.** `check_coverage` and the preflight (`classify_batch.rs:181-191`) now take the overlap and T from the same
  registry the native `chunk_plan` uses. `p.profile` and `p.sh.tokens` are checked equal to the spec after the load
  (`:214`). Note 5 is closed by construction.
* **N-6.** `Spec` is production code that can admit any profile, but production builds only `SHIELD_T128`. A test pins
  its values (`classify_r18_tests.rs:223-231`). It carries no randomness, so condition 6 is unaffected.

## 8. Gate-pin note (item 8)

* **Capture source pins.** The capture pins 72 source files: 38 `OWN_SOURCE_FILES` (`run_capture.rs:221`), 29
  `SHARED_SOURCE_FILES` (`:170`) and 5 `CLASSIFY_SOURCE_FILES` (`:3043`). I hashed each in r16b, r17 and r18
  [MEASURED]. From r17 to r18 exactly one moves:
  * `src/private_block.rs` `2af1df7d5bc222695c1d233050ff87a5f0981a26a5df1828678b67a6fe0a1cb3` →
    `96c1cd16270b087ab56d8fd4cf3777009e5000800ab2d65afc1342ae555c6ac4`. One `pub use` name; the run header absorbs
    `expected.to_bytes()`, not this text, so no other bundle byte moves with it.
* **The two files the gate's capture-pin rule names are unchanged from r17 to r18:**
  * `run_capture.rs` `cce0fc2a4062fcb4c92e771b8d7ac7f996c9ccfbc985bfb6decd79b29fba7ddf`;
  * `plane_index.rs` `ce79803c86a80dde832dc92a262a023efdd52bb95b9a15f128791978c306ffac`.

  They moved r16b → r17, from `cad25086…` and `13a7dd6f…`: the gate's own round-17 / H19 changes.
* **`classify_cli.rs`** `b3b661b5f609ac4195cbbbc0f56d7191458986baf7af0006c63c5aaa3d8a6e17` →
  `6e93e5d714cec7bfec3c65d7add62c33711caa9381521f10f191529944ac3370`.
  * It is not a capture source pin, although `token_io/cli.rs` is.
  * The gate's CLI-path captures (P-18, `classify_capture_tests.rs:686`; H19-2, `gate19_capture_tests.rs:382`) run
    `classify_cli::door`, whose code is byte-unchanged.
  * Whether to pin `classify_cli.rs` and the two batch files is the gate lane's choice. They are prove-side only and
    decide no verifier byte.
* **New production files, not pinned:**
  * `classify_batch.rs` `9efc66e7fb6726de7d83d5e9d04bdd7a97fb0dc6ab46c1833e534c699bd1b5ae`;
  * `classify_batch_plan.rs` `a814b7d616a72db68f750cfb82a7852ebc52a44f4fb5c1184920ab4248b4dd48`.
* **`examples/zk60_classify.rs`** `af8cfd0e…` → `01c88770ed1748bea6283ca627624a31ff66a7cd4c1d7f2a54ac4e6f5f7750e9`
  (not pinned).
* **Binary.** A P-18 capture records the CLI binary's SHA-256 (`HL_PB_CLI_BIN_SHA256`). The r18 binary is
  `110f0c53c56f691c301fe4f47d13afc1ccc9898efbaaf8506f1e0d5cde5f4496`, against r17's `81bd8624…` and r16b's
  `dfb8025e…`. I read these from `cli/binaries_r18.sha256`; I did not re-hash the binary.

## 9. Evidence I checked

* [MEASURED]
  * `frozen-r18` against `manifest_final_r18.sha256`: 306 of 306, list sha256 `1ca1b2d7…` (= `r18/manifest_r18A`);
  * `diff -rq` against r17 and r16b, and `diff -u` of every production file;
  * the 72 pin hashes;
  * equality recomputed from `digests.json` (3 × 30 files; r16b equal to the candidate for job 0; no segment shared between jobs);
  * the `path_children` probe.
* [READ]
  * `A5_PATCH_REVIEW.md` in full;
  * `r18/PROGRESS.md`;
  * the register entries D23, D24, D36, D45, D46, "A5 one-load batch" and "Token round 18 frozen";
  * every changed source file in full: the batch, plan, r18 tests, the cli prove path, and the s25 / hash_domain additions;
  * `load.rs` `ExportTokenBlocks`;
  * `classify_tied.rs` `BoundClassifierTables`, `check_for` and the derivation;
  * `classify_run.rs:103-190`;
  * `zkp-core/src/rng.rs:1-80`;
  * the capture pin lists;
  * `eq/{batch,fail,single-c*,r16b-c0}.log` and their guard JSONs, `compare.log`, `fail_check.json`, `fresh_result.json`, `router.log`, `crossrun_precrash_vs_rerun.json`;
  * the crash leftovers record;
  * `s23-suite.log` (961 passed, 0 failed, 71 ignored; the round's tests and the census tests pass; 13 `batch::plan::tests`);
  * `rung-eq.log`;
  * the tools `run_fixed.sh`, `compare.py`, `fail_check.py`, `make_fail_request.py`, `mutate18.py`, `r18_eq.sh`;
  * Astra's `batch_cleanup.py` and `batch_request.py:160-277`.

## 10. What I did not check

* No build of the tree, no test run, no proof, no verify, no mutant run. The one exception is the scratch
  `path_children` probe: a light guard job, 0.07 GiB.
* "The suite kills the reused-draw mutant" (N-1, §5) is a reading.
* I did not re-hash the release binaries.
* `prove_classify_run_with` past line 190, `stage_in_c` / `stage_out_c`, `endpoint_g`, and the `zk.rs` / `layer.rs`
  pools: for these I relied on the census, the A5 review and the reviewed r16b baseline.
* Astra's app half: I did not review it in depth or run its tests. I read the quarantine and the collector, not
  `test_batch_cleanup.py`, `prepare_text` or `cleanup_scope`'s callers.
* Not checked:
  * the GPU build;
  * non-x86-64 targets (by reading, they refuse every request);
  * a multi-chunk real post;
  * a flagged verdict;
  * memory and duration over 22 jobs;
  * `read_prompt_file`'s content-file checks (unchanged code).
* Not a privacy review: the Shieldstral T128 privacy statement is still a draft (register, gate round 21).
