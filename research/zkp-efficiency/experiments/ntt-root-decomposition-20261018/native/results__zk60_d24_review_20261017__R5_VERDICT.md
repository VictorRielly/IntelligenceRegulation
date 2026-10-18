# D24 review, round 5: verdict on the native R5b tree

Written 2026-10-18 (00:3x UTC) by the independent review lane. This is not a
privacy review: only Victor rules on privacy.

**What I reviewed**

- **Source.** My frozen copy `ops/zkp-mvp/trained-1b-review-r5/` of the
  R5b freeze. The freeze was taken at 2026-10-18T00:06:31Z and has tree
  hash 44013397....
- **Integrity of the copy.** `ops/zkp-mvp/trained-1b-review-r5.sha256` has
  218 entries. It matches `r5b/manifest_frozen.json` file for file, and the
  tree hash recomputes.
- **Diff.** I read every hunk of `r4-vs-r5.patch` (2,099 lines, 14 files)
  against round 4's copy.
- **Binary.** I built my own CLI from the untouched frozen copy:
  `r5/zk60_trained_block.review-r5.release.bin`, sha256 2dcf76d0....
- **Log.** `PROGRESS.md`, section ROUND 5.

All measurements below come from a shared box, one run each [MEASURED].

## Verdict

1. **R5b is ACCEPTED on soundness.** Nothing in it lets a verifier accept
   something false.
   - My CLI verifies tonight's 32-block Llama-3-8B T128 stack in a fresh
     process. The statement is rebuilt from my own copy of the calibration
     lane's original export, with no `seq_*` directories.
   - The rebuilt identity is 6aba46fb..., which equals the pin. The receipt
     is 922,711,264 B, and all 11 run-level controls refuse.
2. **The Llama-3-8B T64 and T128 profiles are ACCEPTED.**
   - **No-wrap clauses:** every T-dependent clause stays far below p/2 at
     every f_e in 9..=16. At T128 with f_e = 16:
     - c2 is 2^33, c3 is 2^24, and the PV host relation is 2^24.6.
     - The honest row sum fits its window.
   - **Layouts:** the counted layouts match.
   - **Registries:** every registry covers the new profiles. Each profile
     string names exactly one shape (D17).
   - **Door:** the door classes are the same as at T32: the width-4096
     norm, RoPE base 500000, and the pinned checkpoint.
3. **r4_A and r4_B are CLOSED.**
   - Every fat-export, FIFO, `/dev/zero` and swap-race probe is refused by
     name before a read. The fat export now peaks at about 4 MiB; in round 4
     it reached 1.43 GiB at the cap until killed.
   - Under 5.8 M swaps, the export reader never returned bytes other than
     the regular file's.
4. **The P-1 fix.**
   - **H-1 (refuse before the run header) holds.**
   - **M-9 / D12b(1) holds for the honest prover:** no `statement/` is
     written without a verification, and a failed verify promotes nothing.
   - **But the promotion is not bound to what was verified (finding
     r5_A).** Any of the following ends up promoted into `<run>/statement/`:
     - a segment swapped after the verify (the race);
     - a forged `statement.json`;
     - extra prover files;
     - a symlinked directory.

   r5_A does not affect verification soundness, because `stack-verify` never
   trusts `statement.json`. It does affect the meaning of `statement/` as a
   publication marker. Fix it before `statement/` is relied on for runs whose
   directories other parties can write.
5. **C-R4, P-5, P-6 and P-7 are as described.** I found no bypass, with the
   limits given in the notes.

## 1. The r4_A and r4_B fixes

All probes ran under the guard with the review CLI, against a verifier copy
of the round-3 two-layer rung stack (no `seq_*`).

| probe | round 4 (R5 CLI) | round 5 (R5b CLI) |
|---|---|---|
| exp-fat: all 22 arrays 255 MiB sparse (verifier) | no refusal; at the 1.5 GiB cap until killed at 60 s | refused at layer 0, `wq`, from metadata: "267386880 bytes on disk, the expected length is 147456; refused before it is read". 0.00 s, 4.0 MiB |
| exp-fat40: 40 MiB arrays | 471 MB, then refused | refused the same way, 3.7 MiB |
| exp-fat on the PROVER (`stack-prove`) | (not run) | refused in the sealing pass before any read. 3.8 MiB, no run directory |
| wq is a `/dev/zero` symlink, or a FIFO | refused by the lstat check (old race open) | "layer 1: array `wq`: ... not a regular file ... refused before it is opened" |
| wq 300 MiB / profile.json a FIFO / a manifest a `/dev/zero` symlink | partly refused | each refused by name from metadata |
| wk misdeclared `[384, 384]` (same dtype) | read, then refused | "the manifest declares I8 [384, 384], expected one of [(I8, [128, 384])] (refused before it is read: review r4_A)" |
| `statement/expected.bin` is a FIFO | (read through the racy reader) | "not a regular file ... refused before it is opened" |
| export reader under a concurrent swap (r5_1) | 340 reads past the bound (64 MiB); 171 calls stuck in a FIFO open | 5,841,763 calls in 10 s, 0 returns other than the regular file's bytes. Refused: 3,022,981 by the lstat type check, 969,872 by the lstat length check, 197,729 by the `O_NOFOLLOW` open, 178,479 by the post-open `fstat`. Slowest call 4.9 ms |

The round-3 segment probes still pass on R5b:

- `/dev/zero`, 512 MiB sparse, FIFO, 1 B short or long, a directory,
  `/dev/null`, a symlink to the honest segment, and segment 1 as a FIFO with
  and without `--controls` are each refused by name, in 0.02–0.26 s at
  10–30 MiB.
- The hard-link control verifies, and the honest run verifies with all 11
  controls refused.

### Code checked

- **r4_A.** `load_array_checked` now does three things before any byte is
  read:
  - checks the manifest's dtype and shape against the code's expected
    alternatives;
  - checks `n <= MAX_ARRAY_BYTES`;
  - reads with the exact length `n` through `run::read_regular_file_bounded(.., exact = true)`.

  This applies to the digest, reload, RoPE and sequence paths.
- **r4_B.** `read_regular_file_bounded` follows the same discipline as
  `read_segment_bounded`:
  1. checks file type and length with lstat before opening;
  2. opens with `O_NOFOLLOW | O_NONBLOCK`;
  3. re-checks with `fstat` after opening;
  4. reads through `take(max + 1)`;
  5. re-checks the length.

  It now backs `trained_block::read_bounded` (every export and artifact
  file) and the MVP driver's reader and segment scan.

## 2. The privacy review's P-1 fix

### H-1: refusal before the run header — holds

`seal_and_record` runs before `prepare_endpoints`, the run statement and
`create_dir(&out)`. For every layer, in order, it does:

- the full checked load and digest;
- the witness built by the witness builder from the previous block's
  output, with the builder's own refusals;
- parity against the export's `x_out`;
- for block 0 only, a check that the input plane is the export's `x_in`.

The endpoints committed afterwards are the builder's own planes. In the
proving pass:

- a witness that was not kept (`--witness-cache-gib`) is rebuilt and refused
  unless its output equals the sealed output;
- a failure after `out` exists goes through `fail_run`, which reports a
  failed removal instead of ignoring it.

**Evidence:**

- the author's test "an inadmissible chain (layer-1 parity) refused with NO
  run directory and no statement" passes in my run of the author's tests
  (64 passed);
- my probes:
  - a label refused by C-R4, and the fat export refused in the sealing
    pass: in both cases no run directory and no unverified statement exist;
  - builder refusal texts name the check only.

See note N-r5-a for the one place where H-1 rests on an argument rather
than on code.

### M-9 / D12b(1): a statement only after a verification

**What holds** (r5_3 (a) and code):

- By default `stack-prove` writes only `<run>.unverified-statement/`, with an
  `UNVERIFIED.txt` marker.
- With `--verify-in-process`, `statement/` is written only after the
  in-process verify passes. A failed in-process verify goes through
  `fail_run`.
- The lie control writes no statement.
- A FAILED fresh verify promotes nothing; the unverified directory stays
  where it is.

**What does not hold: finding r5_A.** It is shown below.

## 3. C-R4, P-5, P-6, P-7

- **C-R4.**
  - `label_of` guards all four CLI entries (`prove`, `verify`,
    `stack-prove`, `stack-verify`). The allow-list is the defaults only:
    `zk60-trained-block` and `zk60-trained-stack`.
  - `--label request-42` is refused by name on the verifier, and on the
    prover before anything exists.
  - `flags()` takes the FIRST of duplicate flags, so a second `--label`
    changes nothing.
  - No other code path derives a context.
  - C-R1: `c_r1` refuses a 40-byte context input. The real inputs are at
    least 61 B.
- **P-5.**
  - Both verifiers refuse an export with a top-level `seq_*` entry, by name
    ("privacy review P-5: ... holds the prover-private entry \"seq_s0\"").
  - `--seq-dir` gives the prover a private directory outside the export.
  - This is a name guard on the calibration layout, not a content check;
    see note N-r5-b.
- **P-6.**
  - The parity refusal is the constant `PARITY_REFUSAL`, with no count,
    position or value. The stack refusal names the layer only, which P-6
    permits.
  - Builder refusals name the check site only: "fixed oracle range
    refusal: <site>" and the relation-failure names.
  - Sequence-file errors are generic: no digest, size or value.
  - The author's parity test passes in my run.
- **P-7.**
  - `statement.json` records `backend`, `gpu_declines` and
    `prover_verified_in_process`.
  - These are prover self-reports. A CPU proof and a GPU proof have the same
    form, so no verifier can check them. Under r5_A they are promoted
    unchecked; r5_3 (c) promotes a forged `"backend"`.

## 4. The Llama-3-8B T64 / T128 profiles

| check | evidence | status |
|---|---|---|
| Block and run profile strings, one per shape (D17) | `...private-block-llama-3-8b-t{64,128}-trained/1` and `...private-run-llama-3-8b-t{64,128}-trained-statement/1`. All 14 trained block/run strings are pairwise distinct (r5_5). The s25 hash-length census and the s24 tests pass in my run (s33 was not in my subset; it passed in the author's `r5b-suite2` on this tree). | accepted |
| `Shape::llama3_8b_trained`, row widths 2^13 and 2^14, 37 endpoint rows | `llama3_8b_log_cols` gives 32→13, 64→13, 128→14. `trained_geometry` builds T·4096 over the row width, plus the mask rows: 37 endpoint rows at both T. Any other T is refused by name (r5_5: T 16, 33, 96, 256). | accepted |
| Door classes | The same door as T32: `with_trained_calibration`, the width-4096 norm (tn ≤ 9, window 32, D_max 2,097,152), `check_f_e_class(T, f_e)` (9..=16 and clog2(T) + f_e ≤ 24), RoPE 500000 and the pinned checkpoint. Every registry site uses the generic lists; no site names T32 alone. r5_5: every f_e in 9..=16 builds at two calibrations (the R4 test constants and the R5b export's), with wrho_s = log2(T) + f_e. f_e 8 and 17 are refused. | accepted |
| No-wrap clauses at T64 / T128 | **Source:** my own checker, `reviewer_nowrap_r5.py`, written from argument.rs `SC_SZC` and layout.rs. **Ranges used:** the softmax top-limb pins (`scaled(top, 2^(8·ls − wrho_s))` and `scaled(p_top, 64)`) give sr, sg < 2^wrho_s and p < 2^10. **Results at every f_e in 9..=16:** at T128, c2 ≤ 2^33, c3 ≤ 2^24, the PV accumulator ≤ 2^24 and the PV host relation at every sh_o ≤ 2^24.6; at T64 they are 2^32, 2^23 and 2^24.0. Sum − 1 < 2^wrho_s at every (T, f_e), so honest remainders fit. The hosts at width 4096 over their whole shift windows are ≤ 2^36 (down over f_pad 16384). The norm is independent of T (round 3: C0 2^48.039). **Consequence:** c2 and c3 hold over the integers, which forces p = ⌊e·2^F_P / Sum⌋ and Sum ≥ 1. | accepted |
| Counted layouts | r5_5 and the author's test: T64 at 2^13 gives A 3229 / H 3534 / 21,697,512 B; T128 at 2^14 gives A 3405 / H 3790 / 29,300,856 B. The author's measured one-block segments are these plus the 80 B frame. The T128 stack's per-segment lengths equal the verifier's counted lengths (the fresh verify reads each segment with its exact counted length). | accepted |
| CS-7 / CS-9 cross pairs | r5_5: every other trained run profile refuses each 8B shape (CS-7). Each block string at the other T's geometry is refused by CS-9 (checked as a release build) and by CS-8. A TinyLlama geometry under the 8B string is refused. | accepted |
| Export reader T mapping | `Geometry::Llama3_8B(T)`: for an 8B pin with T in {32, 64, 128}, or an explicit `llama-3-8b-t{32,64,128}`. `shape_for` refuses a geometry whose T is not the export's. The pinned source is enforced for every 8B T. | accepted |
| The real 32-block 8B T128 stack | Fresh verify, details above (`r5/r5-8b-T128-verify.log`): load 14.7 s, verify 38.5 s, wall 166.6 s, peak RSS 2.34 GiB. The f_e + 1 control is refused by the counted length, because the T128 layout moves with the sigma_s limbs. | verified |

## Findings

| id | what | severity | status |
|---|---|---|---|
| r4_A | export-side memory amplification | verifier DoS | **CLOSED** |
| r4_B | export reader's race between the lstat check and the read | verifier DoS | **CLOSED** |
| **r5_A** | **the statement promotion is not bound to what was verified** | **Medium for M-9 / D12b(1) publication integrity; not verification soundness** | **OPEN** |
| N-r5-a | H-1 relies on the builder's refusals covering `prove_core`'s CS-3 class | note | suggestion |
| N-r5-b | P-5 is a top-level name guard | note | as described |
| N-r5-c | P-7 fields are prover self-reports | note | label them |
| N-r5-d | wording | note | — |

### r5_A in detail

**Location.** `trained_block.rs`, `stack_verify_inner` and `promote_statement`
(line 2405 in the frozen copy).

**What the promotion does now.** After a successful verify, it:

1. checks that the prover's `statement.json` CONTAINS three substrings
   (identity, context, expected_io);
2. re-reads the segment files and compares them with the prover's
   `segments.json`;
3. removes the marker;
4. renames the prover's whole directory to `<run>/statement/`.

**Reproductions** (scratch test `review_r5_inner::r5_3`, the R5b
`stack-prove` / `stack-verify` on a two-layer rung stack, `r5/r5-fast.log`):

- **(b) The race, at its point.**
  - Setup: run A verified. Then segment 1 is replaced by run B's segment 1
    (the same counted length, another transcript), and A's unverified
    `segments.json` is rewritten to name it.
  - Result: `promote_statement` ACCEPTS, and A gets a `statement/`. A
    fresh `stack-verify` of A afterwards FAILS (exit 1).
  - Cause: the promotion compares `segments.json` with a re-read of the
    files, not with the bytes the verification consumed. The window between
    the verify and the promotion's re-read is real; with `--controls` it
    lasts the length of the controls.
- **(c) No race needed.**
  - Setup: the prover's `statement.json` carries a false `"scope"` ("a full
    Llama-3-8B model pass, privacy accepted"), `"backend"` and `"blocks":
    99`, plus a DUPLICATE `"trained_statement_identity"` of zeros after the
    real one. An extra file `EXTRA-prover-file.txt` sits in the directory.
  - Result: an ordinary `stack-verify` exits 0 and PROMOTES both.
  - A JSON reader that keeps the last duplicate key reads the forged
    identity.
- **(d) A symlinked unverified directory.**
  - Setup: `<run>.unverified-statement` is a SYMLINK to a directory
    elsewhere.
  - Result: `stack-verify` exits 0, and `<run>/statement` becomes that
    symlink, pointing at content that can change later. The marker inside
    the symlink's target is deleted.
- **Also by code.** When `<run>/statement/` already exists (written by
  anyone), `stack-verify` uses its `expected.bin` and never looks at its
  `statement.json`. So a `statement/` the verifier did not write itself
  never meant "verified".

**Minimal fix.** The verifier writes the published statement itself,
instead of promoting prover files:

1. Hash each segment in the same read that verifies it. For example,
   `verify_run_from_dir_with` returns, or a wrapper records, the length and
   SHA-256 of the bytes it handed to `step`.
2. Write a NEW directory, `<run>/statement.verifying-<pid>/`, opened with
   `create_dir` so that it fails if it exists. Put in it:
   - `expected.bin`: the bytes the verification used;
   - `statement.json`: rendered by the verifier from its own data
     (`render_stack_statement`), with the prover's backend fields copied
     under a `prover_reported_` prefix or left out;
   - `segments.json`: from step 1's hashes.
3. Rename it to `<run>/statement/` without replacing an existing entry:
   `renameat2(RENAME_NOREPLACE)`, or a check then a rename that refuses an
   existing non-empty target.
4. Then remove the prover's unverified directory. Check it with
   `symlink_metadata` and refuse a symlink. Never follow it.
5. When `<run>/statement/` already exists, compare its three files byte for
   byte with the verifier's own rendering, and refuse on a mismatch.

**Smaller patch, if the promotion is kept:**

- refuse unless `symlink_metadata(unverified)` is a real directory;
- refuse unless it holds exactly `UNVERIFIED.txt`, `expected.bin`,
  `statement.json` and `segments.json`, all regular files;
- require `statement.json` to equal the verifier's own rendering byte for
  byte, apart from the three prover-reported fields;
- bind `segments.json` to the verified bytes' hashes (step 1).

**Suggested regression tests:** r5_3 (b), (c) and (d).

**Effect on tonight's stack.** None. Its `statement/` was promoted by the
native lane's own verify of its own run, and my independent verify of the
directory passes.

### Notes

- **N-r5-a. One refusal still happens only inside the proving pass.** The
  honest prover's CS-3 refusal (a lookup miss) runs in `prove_core`, mid-run,
  not in the sealing pass. So "every refusal happens before the header"
  rests on the claim that a witness the builder admits never misses a
  lookup. The builder range-checks every looked-up limb, so this should
  hold, but it is an argument (the refusal census, P-13 / GN-1), not code.
  Suggestion: run the same miss count on each sealed witness in
  `seal_and_record`. It is cheap: the lookup values plus the three
  histograms.
- **N-r5-b. P-5 checks names, not contents.** It refuses top-level `seq_*`
  names, which is what the calibration layout and `--seq` use. An export
  copy that carries hidden planes under another name, or nested deeper, is
  not detected. The operating rule "the verifier's copy holds the public
  files only" stays.
- **N-r5-c. The P-7 fields are prover self-reports.** `backend`,
  `gpu_declines` and `prover_verified_in_process` are written by the prover
  and should be labelled that way in a verifier-written statement.
- **N-r5-d. Wording.**
  - `stack-prove` prints its stdout event `run_header` before the sealing
    pass. It is not the transcript header, but the name invites confusion.
  - `SCOPE_8B_LONGER` still says "PENDING INDEPENDENT REVIEW"; update it
    after this verdict.

## Evidence (this directory)

- **Logs:**
  - `PROGRESS.md` (ROUND 5), `r4-vs-r5.patch`;
  - `reviewer_nowrap_r5.py` / `.json`.
- **In `r5/`:**
  - scripts: `r5_queue.sh`, `make_fixtures_r5.py`;
  - `binaries.sha256`;
  - logs, guard records and done markers for every probe: `r5-p5-*`,
    `r5-cr4-*`, `r5-honest-verify`, `r5-seg-*`, `r5-exp-*`,
    `r5-8b-T128-verify`, `r5-test-build`, `r5-fast`, `r5-author-subset`,
    `r5-nowrap`.
- **Scratch:** `ops/zkp-mvp/trained-1b-review-r5-scratch/`:
  - the review modules `review_r5_tests.rs` and `review_r5_inner` in
    `trained_block.rs`;
  - the fixtures in `review_out/stack2/`. Some hold named pipes and sparse
    files.
  - `verifier-8b-T128/`: hard links into the calibration lane's export,
    read only.
