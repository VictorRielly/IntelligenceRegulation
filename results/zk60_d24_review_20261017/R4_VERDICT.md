# D24 review, round 4: verdict on the native Round-5 tree

Written 2026-10-17 (20:5x UTC onward) by the independent review lane. **Not a
privacy review**; only Victor rules on privacy.

- **Reviewed code:** my frozen copy `ops/zkp-mvp/trained-1b-review-r4/` of
  the native lane's Round-5 tree.
  - The tree was frozen at 2026-10-17T19:48:50Z (`results/zk60_1b_native_20261017/r5/FROZEN.txt`).
  - `ops/zkp-mvp/trained-1b-review-r4.sha256` has 217 entries. It equals
    `r5/manifest_frozen.json` file for file, and its tree hash recomputes to
    d67fae7e....
- **Diff reviewed:** every hunk of `r3-vs-r4.patch` (2,695 lines, 23 files,
  against round 3's frozen copy).
- **Binary:** a production CLI built from the PRISTINE frozen copy:
  `r4/zk60_trained_block.review-r4.release.bin`, sha256 bc627953....
- **Full log:** `PROGRESS.md`, section ROUND 4.

## Verdict

**The Round-5 changes are ACCEPTED on soundness.**

- My nine review tests pass (`r4/r4-fast.log`).
- The author's full release suite on my copy is green: 29 targets, 688
  passed, 0 failed, 29 ignored. These are the same counts as the author's
  `r5-suite2` (`r4/r4-suite.log`).

- **Nothing reviewed lets a verifier accept something false.**
  - The new CS refusals only add checks: they absorb nothing and draw
    nothing.
  - The proving-pass reload no longer re-hashes each array with SHA-256.
    Instead it compares the digest of the block it rebuilt with the digest
    pass's. The bytes proved are therefore the bytes the statement names.
  - The verifier still runs the full hash pass before its statement pin.
  - The byte counters cannot reach a transcript.
- **r3_3 is closed.**
- **r3_6 is closed.** Every round-3 reproduction is now refused by name in
  about 50 ms at about 11 MiB RSS.

**One new denial-of-service finding, r4_A.** Round 5's parallel array loads
let a crafted export push the verifier's memory to roughly 11 to 22 times
the old worst case before any length is compared.

- Sequential reads refused the bad export after one array, at 264 MB RSS.
- The R5 binary sat at a 1.5 GiB cap until a time limit killed it.
- It accepts nothing false, so it does not block the soundness acceptance.
- It should be fixed before the stack verifier is pointed at exports it did
  not produce itself.

**One minor finding, r4_B.** The export reader still has the race that the
segment reader had before R5's r3_6 fix: something can be swapped in
between the type/length check and the read. This is older than R5.

## Item by item

### 1. The CS port

| Ruling | Where it fires (prover / verifier) | Before anything is absorbed? | Status |
|---|---|---|---|
| CS-1 (feed-forward statement vs shape, incl. S38-F1(a)) | **Prover:** `prove_inner_at`, `prove_core` (every block), `witness::build_shaped`, `RunStatement::new` / `new_bound`, the run's `fit_the_shape`. **Verifier:** `verify_bytes_at`, `verify_inner_at`, `verify_core`, `RunVerifier::start` | Yes. In a run with a streaming source it fires in `prove_core` / `verify_core`, before that block's stage absorbs anything of the block. | holds |
| CS-3 (lookup miss) | Honest prover only, in `prove_core`, before the `A` mask rows are drawn (protocol.rs, `refuse_lookup_misses`). The verifier still has to reject at LogUp, and the tamper harnesses now prove with the test-only switch on, so the verifier speaks. | Yes | holds |
| CS-4 (attention half, `IoSpec` against the shape) | The same entries as CS-1. `IoSpec::check_for_shape` compares every field the shape derives (`t_pad`, `d_pad`, construction, endpoint log_n / rate / rows, opened columns, hash tag) plus the pinned scales. | Yes | holds |
| CS-6 (the blocks are the statement's) | **Prover:** `prove_run_with` (count, then digests; skipped only under the `#[cfg(test)]` cheating switch). **Verifier:** `RunVerifier::start`, which every verifier entry goes through and which never reads the switch. | Yes. The refusal comes before the run header, and before the directory is listed. | **r3_3 CLOSED** (r4_1, below) |
| CS-6, streaming `BlockCache` | `count()` is the layer count. `are_the_statements` compares the cache's digest list with `st.block_digests()` entry by entry. Every reload is compared with that list again. | Yes | holds (r4_4c: 0 witnesses asked, 0 segments sunk, 0 block loads) |
| CS-7 (run profile names one block shape) | `RunShape::new`, the only constructor. The `RunShape` fields are private. | construction | holds |
| CS-8 (written fields) | `Shape::check_constructed`, `Layout::check_is_for_shape` (all ten public row fields; the rest are private to layout.rs), and the `IoSpec` scale pin. Called first at every single-block entry and in `prove_core` / `verify_core`. | Yes | holds (r4_3: all 35 field writes refused at frozen rung-G and 125M; see N-r4-c for trained shapes) |
| CS-9 (profile string names one shape) | `Shape::new`. Release builds refuse unregistered strings. Every non-registered `Shape::new` caller is test-only (checked by grep). | construction | holds |
| G-2 pins | `SHARED_SOURCE_FILES` adds `zkp-core/src/pcs/encode_buffer.rs` and `sumcheck/{rounds,grouped}.rs`. All three exist. | n/a | holds (see note N-r4-d) |

The test-only switch:

- `CheatingProver`, its thread-local and `cheating_prover_is_on` are all
  `#[cfg(test)]`.
- The run prover's `cheating` is the literal `false` under
  `cfg(not(test))`.
- `refuse_lookup_misses` reads the switch only under `#[cfg(test)]`.
- Nothing in a release path can reach it.

**r4_1, the r3_3 re-run** (a two-block bound run at rung-TC; the statement
names blocks A; B differs from A in one gain word of block 1):

- The honest prover handed B is refused: "ruling CS-6 — block 1 handed to
  the run is not the block the run statement names ...; refused before
  anything is absorbed". 0 witnesses asked, 0 segments sunk.
- A CHEATING prover (the test switch) proves B under A, giving 15,012,880 B
  of segments. Then:
  - `verify_run` handed B is refused by CS-6's name. Round 3 ACCEPTED this
    case. It is refused also with the switch on in the verifier's thread.
  - `verify_run` handed A is rejected by the argument ("M: mask: ...").
  - `verify_run_from_dir` handed B is refused by CS-6, both from the real
    directory and from a missing one (so the directory is not read first).
  - Counts of 1 and 3 blocks are refused by CS-6's name.
- The honest A chain verifies.

### 2. Run hygiene (speed plan task 1)

- **SHA-free reload, TOCTOU.**
  - `BlockCache::get` rebuilds the block with `reload_block` (the same code,
    the array SHA-256s skipped) and refuses it unless
    `blk.digest() == digests[k]`.
  - `BlockPublic::digest` covers every public word the prover and verifier
    read (unchanged since round 3; no new field).
  - The block is then held as an immutable `Arc`. The witness source and the
    prover share that `Arc`, and every reload is checked again. So no file
    read lies between the check and the use.
  - A change between the digest pass and the reload is refused in all five
    r4_4a cases:
    - wq, wd_t or gamma_m rewritten while the manifest SHA is left stale
      (the reload no longer hashes the array): refused with "layer 1's
      reloaded public statement is not the one the run statement binds";
    - array and manifest rewritten, `profile.json` carries manifest
      digests: refused by the manifest SHA;
    - array and manifest rewritten, no manifest digests: refused by the
      block digest.
  - **Verifier side:** `stack-verify` runs the FULL digest pass first (array
    SHA against the manifest, manifest SHA against `profile.json`), rebuilds
    the statement, and refuses unless it equals `--expect-statement`. Only
    then does it reload. It re-hashes everything it must.
- **In-process verify off by default.**
  - `stack-prove` still checks parity in the proving pass.
  - `--lie-at-boundary` forces the in-process verify, because its verdict is
    the control.
  - No current caller relies on it: `r5_stack.sh` always runs a
    fresh-process `stack-verify`. The GPU zero-check lane's `stack.sh` runs
    on a pre-R5 tree, where in-process verify is still on. See note N-r4-a.
- **Parallel hashing equals the sequential digests.**
  - The R5 CLI's parallel digest pass rebuilds round 3's statement for my
    two-layer rung stack (72098637..., `r4/r4-stack2-verify.log`).
  - The author's 8B T32, TinyLlama T32 and T128 identities are unchanged.
  - r4_4b (4 layers): parallel pass == sequential `load_layer` ==
    `reload_block`, digest by digest, and the records are equal.
- **`weights_vanish_off_support`.**
  - The parallel pre-scan visits exactly the entries the sequential loop can
    refuse on: a nonzero anywhere in an off-support row, and a nonzero at an
    off-support inner index of a supported row.
  - On a violation it falls back to that same loop, so the first error is
    the same.
  - r4_2: 9,672 random cases (9,648 violating) at rung-G, P2, K4 and TC,
    across all six axis pairs. Verdict and first error equal the round-3
    loop every time.
- **First error in layer order.** The digest pass collects each two-layer
  chunk in order and returns the first `Err`. r4_4b covers three cases:
  layer 0's error wins over layer 1's within one chunk; layer 1's wins over
  layer 3's across chunks; layer 3's when it is alone.
- **Parallel `pad_matrix`.** It assumes injective maps, which holds for
  every caller. r4_4d: equal to the sequential version at 4 shapes, for the
  Wq/Wo head map (288 of 384 Q indices moved at rung-TC), Wk, gamma, Wg and
  Wd.

### 3. The r3_6 fix

**`run::read_segment_bounded`** does the following, in order:

1. It computes the verifier's own counted length and checks it against the
   wire ceiling.
2. It calls `symlink_metadata` and refuses anything that is not a regular
   file.
3. It requires the metadata length to equal the counted length.
4. It opens the file with `O_NOFOLLOW | O_NONBLOCK`.
5. It re-checks the opened file with `fstat` (regular file, correct length).
6. It reads through `take(want + 1)` and re-checks the length.

`stack_controls` reads only through it, using the honest statement.

All runs below used the review CLI under the guard (light class, 0.5 GiB
declared, 1.5 GiB cap) [MEASURED, shared box, n=1]:

| case | round 3 (r4 CLI) | round 4 (review CLI) |
|---|---|---|
| segment 0 is a symlink to /dev/zero | killed at the 1.5 GiB cap | exit 1, "not a regular file ... refused before it is opened", 0.04 s, 11.6 MiB |
| segment 0 is a 512 MiB sparse file | read whole, 515 MiB RSS | exit 1, "is 536870912 B, the counted length is 7398936; refused before it is read", 0.05 s, 10.3 MiB |
| segment 0 is a FIFO | hung until the 20 s limit | exit 1, "not a regular file", 0.05 s, 10.5 MiB |
| segment 0 one byte short / one byte long | (read, then refused) | exit 1, refused from metadata |
| segment 0 is a directory, a /dev/null symlink, or a symlink to the honest file | — | exit 1, "not a regular file" |
| segment 1 is a FIFO (with and without `--controls`) | — | exit 1 after stage 0 verified, 29 MiB |
| segment 0 is a hard link to the honest file (control) | — | verified |
| honest run, `--controls` | 11 refused | verified; 11 refused, the 3 calibration controls now by the run binding; 41 MiB |

- **A file swapped between the check and the read** (r4_5): a second
  thread swapped the path 1.8 M times in 12 s, cycling through a regular
  file, a /dev/zero symlink, a FIFO, a 512 MiB sparse file, a short file, a
  same-length other file and a symlink to the sparse file. Over 105,316
  reads:
  - it returned bytes only of exactly the counted length;
  - refusals: 29,067 by lstat type, 49,456 by lstat length, 3,279 by the
    `O_NOFOLLOW` open and 24 by the post-open `fstat`, so the race window
    is real and the post-open checks close it;
  - no refusal of an unknown kind; slowest call 5.6 ms.
- **The export reader (`trained_block.rs::read_bounded`):** symlink, FIFO and
  over-bound files are refused by name from metadata (`r4-exp-arr-*`,
  about 8 MiB). But see r4_A and r4_B.

### 4. Byte counters

- `timing.rs` imports no transcript, rng or commitment.
- Every `mark_bytes` / `slot_work` argument is a public size.
- `n_tabs` is read before `run_slot` consumes `def`.
- With HL_PB_TIMING unset, every call returns on its first line.
- Empirical check (`r4/r4_prove_checks.sh`): the review CLI proved the rung
  stack with and without `HL_PB_TIMING=1`.
  - Both receipts have the round-3 segment lengths (7,398,936 / 7,613,944).
  - Both have parity bit-exact and statement 72098637....
  - Each verifies in a fresh process under the opposite setting.
  - The timing receipt also passes all 11 controls.
- The bytes cannot be compared directly, because the prover draws OS
  randomness.

## Findings

| id | what | severity | status |
|---|---|---|---|
| r3_3 | CS-6 at the library level (blocks B under a statement over A) | soundness (latent API) | **CLOSED** (r4_1) |
| r3_6 | unbounded segment read in the stack verifier | verifier DoS | **CLOSED** (table above) |
| **r4_A** | **export-side memory amplification from the parallel array loads** | **verifier DoS, not soundness. Low-medium: needs a crafted export.** | **OPEN (new in R5)** |
| r4_B | the export reader's lstat-to-read race | verifier DoS, not soundness. Low: needs a concurrent writer in the export directory. | OPEN (pre-existing; R5 fixed the same race only in the segment reader). r4_4e reproduces it. |
| N-r4-a | in-process verify off by default | note | see below |
| N-r4-b | `BlockCache::fit_the_shape` compares geometry only | note | accepted |
| N-r4-c | CS-8 admits writes of a trained shape's calibration inputs | note | by design |
| N-r4-d | capture pin list completeness beyond G-2 | note | for the privacy-gate lane |
| N-r4-e | array-load refusals name the array but not the layer | note | operability |

### r4_A in detail

- **Locations** (all in `trained_block.rs`):
  - `load_layer_mode` (about line 878): the eleven arrays are loaded with
    `names.par_iter()`.
  - `stack_records` (about line 1813): `DIGEST_PASS_WIDTH = 2` layers are
    loaded in parallel.
  - `load_array_checked` (about line 389): each read is bounded only by
    `MAX_ARRAY_BYTES` (256 MiB). The manifest's own length `n` and the
    code's expected shape are compared only AFTER the bytes are resident.
- **Why sequential code was safe:** the first oversized array was refused
  before the next one was read.
- **What R5 does:** up to 2 × 11 reads are in flight, each up to 256 MiB.
  That is up to about 5.6 GiB. The statement pin is checked only after the
  digest pass.
- **Reproduction** (`r4/make_fixtures.py`): the rung export with every
  array replaced by a sparse file, manifest unchanged.

  | run | export | CLI | result |
  |---|---|---|---|
  | `r4-exp-fat` | 255 MiB arrays | review CLI | no refusal; cgroup at its 1.5 GiB cap (peak RSS 1.43 GiB) until the guard's 60 s limit (exit 75) |
  | `r4-exp-fat-r4cli` | 255 MiB arrays | round-4 CLI | exit 1 in 0.28 s ("array `wq`: 267386880 bytes on disk, the manifest's dtype and shape give 147456"), 264 MB |
  | `r4-exp-fat40` | 40 MiB arrays | review CLI | 471 MB RSS, then the same refusal |
  | `r4-exp-fat40-r4cli` | 40 MiB arrays | round-4 CLI | 44 MB |

  All [MEASURED, shared box, n=1].
- **Minimal fix**, in `load_array_checked`, before any byte is read:

  ```rust
  // n = dtype.size() * product(shape), from the manifest (already computed)
  // (a) the manifest's dtype/shape must be the one the code expects for this
  //     array (pass the expected (Dtype, &[shape alternatives]) in and move
  //     the `expect` checks here), so a manifest cannot declare a huge shape;
  // (b) bound the read by the exact length, refused from metadata:
  let bytes = read_bounded(&dir.join(file), n as u64)?;   // was MAX_ARRAY_BYTES
  if bytes.len() != n { ... }                               // as now
  ```

  With (a) and (b), a crafted export can make the reader hold no more than
  the honest arrays' sizes, the same footprint as the honest digest pass.
  (b) alone already closes the reproduction above.
- **Suggested regression test:** the exp-fat export, refused by name with
  RSS under, say, 2× the honest digest pass.

### r4_B in detail

- **The pattern:** `read_bounded` in `trained_block.rs` (line 294) checks
  `symlink_metadata` (refuses symlinks and non-regular files, checks
  `len <= max`) and then calls a plain `std::fs::read(path)`. A path swapped
  after the check is:
  - followed, if it became a symlink;
  - blocked on, if it became a FIFO;
  - read to EOF with no bound, if it grew or is a larger file.
- **Where it applies:**
  - every export read: `profile.json`, manifests, arrays, the `seq_*` files;
  - the artifact's `statement/expected.bin`;
  - the single-block `verify`'s `segment-000.bin`;
  - the same pattern in `mvp_driver.rs` (about line 503).
- **Evidence:** r4_4e ran `read_bounded(max 4096)` while the path was
  swapped among a 4,096 B file, a 64 MiB sparse file, a symlink to it and a
  FIFO. Over 6,362 calls in 10 s:
  - 340 returned MORE than the bound (64 MiB, 16,384 times the bound);
  - 171 got stuck in a FIFO open, freed only by the test's non-blocking
    writer (without it they would block forever).
- **Fix:** give `read_bounded` the open discipline `read_segment_bounded`
  already has: `O_NOFOLLOW | O_NONBLOCK`, an `fstat` re-check of type and
  length, and `take(max + 1)`.

### Notes

- **N-r4-a.** With in-process verify off, `stack-prove` writes `statement/`
  and prints `"event":"proved"` for an artifact nobody has verified. It does
  say `"in_process_verified":false`. Any lane that moves an EXPERIMENTAL
  prover, such as the GPU zero-check arm, onto R5 must pass
  `--verify-in-process` or run a fresh `stack-verify`. That lane's current
  `stack.sh` does neither: it relies on the pre-R5 default.
- **N-r4-b.** `BlockCache::fit_the_shape` compares profile, axes and padded
  axes only.
  - This is deliberate, so that the calibration controls reach the run
    binding: they now say "this segment belongs to another run".
  - CS-1/CS-4 run on each block at the run's shape inside `verify_core`.
  - In production the cache and the statement come from the same constants.
- **N-r4-c.** For a trained shape, `check_constructed` rebuilds the shape
  through the door at the shape's OWN calibration.
  - So a written calibration input that stays within its class passes
    CS-8. r4_3 at the trained rung: in-class writes of cn_a, cn_m, ceps,
    sh_ao, sh_s, sh_o, sh_h and sh_z are admitted. Derived fields, flags,
    axes, f_e and windows are refused.
  - Such a constant is bound by the trained statement and the transcript;
    the run-level controls show it is refused by the run binding.
- **N-r4-d.** G-2's three files are pinned. The capture list still omits:
  - `hashline/src/gpu/{mod,cuda}.rs`, `layer.rs`, `wcache.rs` and
    `tables_v3.rs`;
  - `zkp-core/src/tables.rs`.

  These are on the GPU path or are table generators. The privacy-gate lane
  should decide whether bundles must pin them.
- **N-r4-e.** "array `wq`: SHA-256 mismatch" does not say which layer.

## The author's suite on my copy

`r4-suite`:

- **What ran:** `cargo test --release --no-fail-fast -- --test-threads=8
  --skip review_r4`, on the scratch copy (= the frozen copy plus my
  test-only modules, which were skipped).
- **Result:** 29 targets, 688 passed, 0 failed, 29 ignored. In the lib
  target, 543 passed and 9 were filtered out (my review tests).
- **Cost:** wall 444 s, peak RSS 4.25 GiB, after 2,460 s waiting for the
  heavy lock [MEASURED, shared box, n=1].
- **Coverage includes:**
  - every `cs_port_tests` test (CS-1/3/4/6/7/8/9, S38-F1(a));
  - `run_tests::review_r3_6_...` and the stack CLI test with its four r3_6
    cases;
  - `rung_tests::a_proof_made_with_the_phase_clock_on_verifies_with_it_off`;
  - the frozen toy pins, the archived receipts and slot-IR digests;
  - the s24/s25/s33 registry and census tests.

## Evidence (this directory)

- `PROGRESS.md`, `r3-vs-r4.patch`.
- `r4/`:
  - scripts: `r4_queue.sh`, `r4_prove_checks.sh`, `r4_fat40.sh`,
    `make_fixtures.py`;
  - `binaries.sha256`;
  - every `r4-*.log` / `.guard.json` / `.done`.
- Scratch, `ops/zkp-mvp/trained-1b-review-r4-scratch/`:
  - the review modules `hashline/src/private_block/review_r4_tests.rs` and
    `review_r4_inner` in `trained_block.rs`;
  - the fixtures under `review_out/stack2/`. `run-fifo*` and
    `exp-arr-fifo` hold named pipes; the `*sparse*`, `exp-fat*` and
    `exp-arr-big` arrays are sparse files.
