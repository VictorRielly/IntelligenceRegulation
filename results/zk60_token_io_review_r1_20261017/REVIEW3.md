# Token I/O — independent adversarial code review, ROUND 3 (rebase onto R6, per-layer score shifts, rung R3: Llama-3-8B)

Reviewer: the independent adversarial code reviewer (Claude Opus 5.5
subagent; did not write the code), 2026-10-19, 10:18–10:58 UTC. Same rules
as rounds 1–2 (`ops/zkp-mvp/LANE_RULES_20261017.md`). **No privacy
acceptance and no ruling is made here.**

**Object.** `ops/zkp-mvp/token-io/` at the lane's
`results/zk60_token_io_r1_20261017/manifest_final_r3d.sha256` (file sha256
`67327e11…`), frozen at 10:19 UTC into `ops/zkp-mvp/token-io-review-r3/`.
Manifest `ops/zkp-mvp/token-io-review-r3.sha256`: 228 files, list sha256
`4ab62df1861ad4b049ceba0a6f36518e6a43eabaaed03c7c98a54d77583d7234`. All 227
entries of `manifest_final_r3d.sha256` match byte for byte; the extra file
is `BASELINE.sha256`. The trained receipt I re-verified is the lane's
`runs/r3/trained-ho00/`: 34 segments, 471,285,072 B, sha256 over the
per-segment sha256s
`eda3752ca53773ad1c8d65f389985dbcab3637d0dcd874dc2bbc300f920c4fc8`;
`statement.txt` sha256 `e02c8199…`. My tests:
`ops/zkp-mvp/token-io-review-r3-scratch/tree/hashline/src/private_block/token_io/run/review_tests.rs`.

---

## 1. Verdict

**The merge.** Verified (§3.1). The tree is the R6 freeze plus exactly the
lane's 15 files. My own 3-way merge reproduces the four shared files: three
byte for byte, and `run_capture.rs` up to its two conflicts, each resolved by
keeping both sides. **No R6 refusal or fix is lost.**

**Is R3 sound as built?** Yes, at the level I could test.
* **Streaming.** Each stage's block is checked (shape at the stage shape,
  plus the CS-6 digest) and then proved or verified with **the same
  in-memory object**. `BlockPublic::digest()` hashes the words each time it
  is called, so there is no gap between check and use. The export source
  also re-checks every reload against the digest pass.
* **Per-layer score shift.** Each layer's shift comes from the trained
  statement's layer records, which the model identity binds. It is validated
  by `with_score_shift` and named in the stage line, so the schedule digest
  binds it too. Block stage k is laid out, checked, witnessed, proved and
  verified at that shape.
* **The 8B tables loader.** It checks the file length from metadata
  *before* reading, reads exactly that many bytes in 16 MiB chunks with the
  SHA-256 streamed, and refuses on a mismatch.
* **V_pad = 2^17.** This is exactly the door's limit: V = 2^17 is admitted
  and V = 2^17 + 1 refused (lane test). The keyed window is 56 bits, 7
  limbs. The honest maximum, 2^55.98, fits under 2^56, and 2^57 < p.
* **Whole-run figure.** My independent recount from its documented pieces
  equals the code's figure exactly: 137 openings, column 2^-98.045, LogUp
  2^-99.441, PCS-field + sumcheck bound 2^-105.883, total 2^-97.575, floor
  97 bits. The total sits 0.575 bits past the floor, and that is *after* the
  left-out terms are included.
* **Tamper tests.** Every probe was refused at the predicted place, whether
  on real data, at the rung, or on the trained receipt:
  * On the b7 export's first two trained layers with the TRAINED 8B tables
    (layer 1 at its own shift 7, 32-row vocabulary planes, calibrated Cn
    4,234, admitted with max |y| 71), I proved 15 forgeries, all refused at
    the predicted slot. They include block 1 witnessed at the run-wide shift
    (refused at block 1's softmax slot), and the honest receipt read with
    the shift dropped or moved to layer 0 (binding).
  * At the full 32-layer trained statement, a forgery (A6-only at id 53,488;
    honest token 11) was refused at RSEL.
  * At the rung: the per-layer shift probes, and a wrong block mid-run,
    refused by name on both sides.
* **The lane's receipt.** The trained receipt (token 11, 471,285,072 B)
  verifies with **my** binary in a fresh process from the saved bytes, in
  37.7 s under a 95-bit policy. So does the lane's own verify test run with
  my binary (41.8 s; one-bit change refused).
* **Probes on that receipt.** Nine probes were each refused:
  * a 98-bit policy, before any segment is read;
  * Cn 512 instead of 4,234;
  * every layer at the run-wide shift;
  * BOS 1 instead of 128,000;
  * one head multiplier changed;
  * the generic run's context;
  * layer 0's block handed in at stage 5 (CS-6);
  * two block segments swapped;
  * a bit flip in stage OUT.

**Round-2 items.** R2-1..R2-6 are folded in and checked (§3.6).

**May R3 stand as the trained 8B next-token result?** **Yes**, with this
wording: a proved greedy next token of the integer, calibrated Llama-3-8B,
which is:
* the `llama3_8b_pg_rot1_b7_T32` export: 32 trained blocks streamed, layer 1
  at its own score shift 7;
* T32, the public-row variant, BOS 128,000 forced;
* the calibration lane's trained int16 embedding and per-row int8 head with
  12-bit multipliers;
* the final norm at the calibrated `Cn = 4,234`.

The proved token, 11, equals the calibration lane's integer head, R0's
reference and the float head (float margin 4.40 logits). Parity with the
export is bit-exact at all 32 layers. The figure is 97 bits whole-run in the
derived convention at 8B T32, with the PCS-field and sumcheck terms bounded
[COUNTED].

It is **not**:
* a privacy acceptance (the G-1..G-7 gate is owed; TR-6 is a listed
  exception);
* a hidden prompt length;
* a token stream (D25 T6);
* a proof that the tables derive from the checkpoint (D25 T7);
* a figure at D27's named workload (8B T512);
* a quiesced timing.

No round-3 finding is above LOW.

---

## 2. Findings (round 3)

**No HIGH or MEDIUM finding.**

### TR3-1 — LOW — a mid-run refusal comes after earlier segments reached the sink

**What happens.** `prove_token_run_with` hands each segment to the sink as
soon as its stage is done. A refusal at block stage k (CS-6, or a block
prover error) therefore comes after k + 1 segments were emitted. Stage IN's
segment carries the input token endpoint's one opening.

**Reproduction.** RV3-A2: a source handing block 0 at stage 1 is refused by
name by the honest prover after 2 segments. The R2-5 fix covers only the
stage-OUT witness, which is now checked before any segment.

**Why it is low.**
* The sink contract says nothing is published before `Ok`, and the R3
  driver removes the run directory on `Err`.
* The endpoint owners are consumed by value, so a retry needs a fresh seal.
  A partial transcript therefore exposes no more than a full receipt of that
  seal would.
* In honest use, a mid-run CS-6 fires only if a block file changes between
  the digest pass and its reload.

**Fix (cheap).** Either check every block's digest before stage IN, which the
R3 harness's digest pass already does, so a production driver should keep
it; or hold back stage IN's segment until the run returns `Ok`. Also write
the sink contract into the production driver when one exists.

### TR3-2 — INFO — the 8B tables loader and the streaming block source are test code

`load_token_tables`, `read_streamed` and `ExportBlocks` live in
`r3_tests.rs`; there is no production token-I/O loader or CLI yet. When one
is written, carry over the metadata-length check, the exact-length chunked
reads, the streamed SHA-256 and the digest check on reload.

The test loader has two rough edges, both harmless for the lane's own
trusted manifests:
* `json_sha_after` parses the manifest by substring (the first `"sha256"`
  after the key) and slices `rest[q..q + 64]` without a length check, so a
  truncated manifest panics instead of returning an error;
* `read_to_string` on the two manifests is unbounded.

Use a real JSON parse with bounded reads in production. The binding itself
does not depend on the manifest: the tables enter the statement by their
own digests (D25 T7).

### TR3-3 — INFO — the per-layer shift is read by position

`TokenRunStatement::new` takes block k's shift from `model.layers[k]`. That
is correct because `model.check_against` aligns the records with the block
digests, and records must be consecutive. A future statement over a
non-prefix or non-consecutive layer set must keep that alignment. A one-line
assertion (`layers[k].block_digest == block_digests[k]`) would make it local.

### Round-2 items, status

| item | fix in the final tree | check | status |
|---|---|---|---|
| R2-1 floor margin | `WholeRun::omitted_log2` = `openings · 2^-113 + (L + 2) · 2^-117.2` (MEMO_G02's per-unit figures at 8B T512), added before the floor | my recount reproduces the code's total to 1e-9; R3 total 2^-97.575, margin 0.575 bits past the floor with the bound inside | **closed** |
| R2-2 stage IN LogUp term | `(N + R (2 + log2 d_pad) + T log2 d_pad) / |F_p^2|` | in my recount (N 4,096, R 128,256) | **closed** |
| R2-3 mutable figure | `whole_run` private, read through `whole_run()` | — | **closed** |
| R2-4 tier name | documented; the new profiles' text says the binding figure is the statement's | — | **closed** |
| R2-5 refusal before segments | stage-OUT witness asked first and its byte refusal run before stage IN | lane test: 0 segments emitted; mid-run refusals remain (TR3-1) | **closed** for the stage-OUT witness |
| R2-6 texts | `describe_under` / `digest_under`; R1 / R2 texts kept byte for byte; later profiles `token-io:` and `two-internal-boundaries` | the R1 / R2 tests and receipts still verify (t1) | **closed** |

---

## 3. Item by item

### 3.1 The merge onto the native R6 freeze

**The R6 freeze is intact.** All 219 entries of
`results/zk60_1b_native_20261017/r6/manifest_frozen.json` match the frozen
tree.

**The review tree differs from R6 in exactly the lane's 15 files** (plus
`BASELINE.sha256`):
* 7 changed: `private_block.rs`, `private_block/run.rs`, `run_capture.rs`,
  `s24_tests.rs`, `s25_tests.rs`, `s33_tests.rs`, `hash_domain_tests.rs`;
* 8 added: `token_io.rs` and `token_io/{r0_words, r2_tests, r3_tests, run,
  stage_in, stage_out, tests}.rs`.

**No R6 change is lost:**
* R6 changed 18 files against R5. Its 14 files that the lane did not touch
  are byte-identical in the review tree.
* `s25_tests.rs`, `s33_tests.rs` and `hash_domain_tests.rs` were not touched
  by R6 (R5 == R6), so taking the lane's versions loses nothing.
* For the 4 files both sides changed, I recomputed the 3-way merge myself
  with `git merge-file -p`: stdout only, no repository write. The inputs:
  ours = the lane's R3-C snapshot `snap-r3c/`, base = the R5 freeze,
  theirs = R6.
  * My merges of `private_block.rs`, `run.rs` and `s24_tests.rs` are clean
    and byte-identical to the tree.
  * `run_capture.rs` has 2 conflict regions: the `OWN_SOURCE_FILES` length,
    and the list body. The lane resolved both by keeping both sides
    (16 + 4 token_io files + R6's `trained_block.rs` = 21 entries). Apart
    from the conflict markers, that is the only difference from my merge.

**Evidence:** `ops/zkp-mvp/token-io-review-r3-scratch/merge/`, and the
lane's full suite on this tree (s5: 729 passed, 0 failed, 37 ignored). Its
difference from R6's own suite (700 / 0 / 31) is exactly the lane's 29 tests
and 6 env-gated ignored tests.

### 3.2 Streaming (CS-6 on reload, TOCTOU)

* **The source interface.** `TokenBlocks::block(k)` returns a `BlockRef`:
  either a borrow from a resident slice or an `Arc` from a one-block cache.
* **Prover side.** Block stage k first absorbs the statement's
  `pb-run-block` digest. It then takes the block and runs
  `stage_block_is_the_statements`: CS-1 / CS-4 at `stage_shape(k)`, then CS-6
  (`blk.digest()` against the statement). Only then does the stage use that
  same `blk` for the witness (`src.witness(k, &blk, &ssh)`) and for
  `prove_core(&ssh, …, &blk, …)`. The block is dropped at the end of the
  stage.
* **Verifier side.** It loads and checks before decoding the segment, then
  runs `verify_core(&ssh, …, &blk, …)` on the same object.
* **No TOCTOU.** `BlockPublic::digest()` hashes the in-memory attention and
  feed-forward words on every call, and no re-read happens between the check
  and the use. The 8B export source (`ExportBlocks`) reloads at the stage
  and compares the reload with the digest pass's digest before handing it
  out, so a file changed between the digest pass and the reload is refused.
* **Probes.** Block 0 handed in at stage 1 (rung: verifier and prover; 8B:
  verifier) and layer 0's block at stage 5 (full trained statement) were all
  refused by name (RV3-A2, B15, C1g). The prover side's partial emission is
  TR3-1.

### 3.3 The per-layer score shift in the token run

* **Where the shift comes from.** `stage_sh_s[k]` is the record's
  `sh_s.unwrap_or(run sh_s)`, validated by `Shape::with_score_shift` (the
  one-limb window, the constructor rebuild, the trained class). The trained
  statement itself refuses an own shift equal to the run's, or outside the
  window (RV3-A1).
* **How it is bound:**
  * through the model identity in the header's calibration word;
  * through the stage line (`score shift 7 (the layer's own; the run's is
    6)`), which enters the schedule digest;
  * runs without an own shift are byte-unchanged.
* **Where it is used.** Block stage k's layout (`block_layout(k)` →
  `Layout::for_shape(stage_shape(k))`), its CS-1 / CS-4 check, its witness,
  its prover and its verifier all use the stage shape.
* **Evidence at real 8B weights (b7 layers 0, 1):**
  * the honest two-layer run proves and verifies, with parity against the
    export at both layers;
  * block 1 witnessed at the run-wide shift is refused at block 1's softmax
    slot (RV3-B12);
  * the honest receipt read without layer 1's shift, or with the shift moved
    to layer 0, is refused by binding (RV3-B13, B14).
* **At the full statement.** The trained statement puts exactly layer 1 at
  its own shift `[(1, 7)]`. With every layer at the run-wide shift, the
  receipt is refused by binding (RV3-C1c).

### 3.4 The 8B tables loader and the V_pad 2^17 edge

* **Loader** (`r3_tests.rs::load_token_tables` / `read_streamed`):
  * `metadata().len()` must equal `2·V·d`, `V·d` or `8·V` before the file is
    opened for reading;
  * exactly that many bytes are read with `read_exact`, in 16 MiB chunks;
  * the SHA-256 is streamed and compared with the manifest's;
  * the tables are built once, with no second copy.

  The tables then pass the door (multiplier class, the −128 head-word class,
  BOS < V) and enter the statement by digest. Lane tests: round trip, wrong
  SHA, wrong size. Notes in TR3-2.
* **V_pad = 2^17** (`V = 128,256`):
  * Voc and Vo planes are 32 rows of 4,096. `MAX_DOM_LOG = 17` admits 2^17
    and refuses 2^17 + 1.
  * The keyed window is `bits(2^17 · 2 · 4096 · 127² · 2^12 + V − 1)` = 56,
    giving 7 limbs. The honest maximum 2^55.98 fits under 2^56, and the door
    checks `2^56 + 2^56 < p`.
  * `iota` runs to 131,071, so `|i − j| < 2^17` holds.
  * The last-row and pad-entry controls at 2^17 were refused as predicted:
    the lane's R3-1..R3-8, and my RV3-B1, B4, B5, B7, B8, B10 with the
    trained tables.

### 3.5 The whole-run figure

* **The code's figure.** `whole_run_of(sh, 32, tp)`: 137 openings (stages'
  A, H, M; two token endpoints; 32 × (A, H, M); 33 boundaries). Column
  2^-98.045. LogUp 2^-99.441: blocks `N = 12,271,616` each with
  `(N + 2303)`, stage OUT `N = 970,752`, stage IN by the R2-2 term with
  `N = 4,096`, `R = 128,256`. The omitted-term bound is 2^-105.883. Total
  2^-97.575, floor 97.
* **My recount.** It is built from the documented pieces in my own code,
  calling only the per-opening and lookup-size functions (RV3-C1). It gives
  the same numbers to 1e-9.
* **External checks.** The figure agrees with RECOUNT's derived 8B T32 stack
  terms (column 2^-98.19 for the stack; lookup about 2^-99.43). The
  omitted-term constants are MEMO_G02's (2^-113 per opening, 2^-117.2 per
  block, computed at 8B T512, which is larger than every registered token
  run).
* **Binding.** The figure is bound in the parameter line, it is private,
  and the policy is checked before any segment is read (RV3-C1a).

### 3.6 Re-verifying the trained receipt, and my tamper tests at R3 shape

* **Fresh-process verify (two ways).** My `rv3_c1` rebuilds every public
  input from the b7 export's public files: a 32-layer digest pass, the
  trained tables through the SHA-checked loader, and the blocks streamed and
  digest-checked. It reads the roots and context from `statement.txt` and
  checks the parameter line and the trained-statement identity. It accepted
  the lane's receipt in 37.7 s. The lane's `token_io_r3_verify_from_dir`,
  with the lane's t21 environment and my binary, accepted in 41.8 s; a
  one-bit change was refused.
* **Tamper tests.** The 15 RV3-B controls on the b7 export's layers 0–1 with
  the trained tables. The honest two-layer run: token 28246, prove 31.0 s,
  34,872,672 B, floor 100 bits. Plus RV3-C2 at the full 32 layers.

---

## 4. Tests run

All runs used the round-3 scratch copy and went through the resource guard,
detached, waiting on `.done` markers (`ops/zkp-mvp/token-io-review-r3-scratch/launch_r3.sh`;
logs in `results/zk60_token_io_review_r1_20261017/logs3/`) [MEASURED,
shared box, n=1].

| step | guard | result | wall |
|---|---|---|---|
| `cargo test --release --offline --locked -j2 --lib --no-run` | build 3 / 5 GiB | exit 0, no warning from my file | 3m02s |
| `... --lib token_io -- --test-threads 2 --nocapture` | cpu 5 / 8 GiB | **31 passed, 0 failed, 9 ignored**: the lane's 29 (R1, TR, R2, R3 unit tests incl. the per-layer shift, the V_pad 2^17 controls, streaming, loader, folds) plus my 2 A probes; 72 lines `AS PREDICTED`, 0 `NOT` | 140 s, peak RSS 2.17 GiB |
| `... --lib rv3_ -- --ignored --test-threads 1 --nocapture` | cpu 5.5 / 8 GiB | **3 passed, 0 failed**: `rv3_b` (15 controls at R3 shape on two trained layers), `rv3_c1` (the trained receipt, a recount, 9 probes), `rv3_c2` (the full-scale forgery, proved in 170.5 s) | 1,097 s, peak RSS 3.97 GiB (cgroup 8.0 incl. the export's page cache) |
| `token_io_r3_verify_from_dir` (the lane's test, my binary, the lane's t21 environment, its saved bytes) | cpu 4.5 / 7 GiB | accepted in 41.8 s; one-bit change refused | 80 s |

`REVIEW-R3 CONTROL` lines (all `AS PREDICTED`):

| id | forgery or probe | refused at |
|---|---|---|
| RV3-A1 | per-layer receipt read with the shift moved to layer 0, on both layers, or dropped; records with an own shift equal to the run's, or 40 | binding; the trained door |
| RV3-A2 | block 0 handed in at stage 1, to the verifier and to the honest prover | CS-6 by name (prover: after 2 segments, TR3-1) |
| RV3-B1 | `e` on the padded entry V + 5 (last row of a 32-row plane) | stage OUT slot 06 |
| RV3-B2 | A6-only at id 75,422 (row 18; honest 28,246, row 6) | stage OUT slot 07 |
| RV3-B3 | A3-only, tok' = 32,342 (one row away) | stage OUT slot 07 |
| RV3-B4 | `m[0]` count moved to the padded entry V + 1 | stage IN slot 02 |
| RV3-B5 | a limb on entry 131,071 | stage OUT slot 06 |
| RV3-B6 | logits from row T − 2 | stage OUT slot 00 |
| RV3-B7 | a second hot `e` on entry 131,071 | stage OUT slot 06 |
| RV3-B8 | a padded token id V + 11 | stage IN slot 02 |
| RV3-B9 | block 0 proved on another input | block 0 slot 21 |
| RV3-B10 | a re-lookup to id 127,000 under the honest seal | stage IN slot 00 |
| RV3-B11 | a histogram count moved from id 9,091 to 13,187 | stage IN H (LogUp) |
| RV3-B12 | block 1 witnessed at the run-wide shift under the per-layer statement | block 1 slot 17 (softmax) |
| RV3-B13 / B14 | the honest receipt with layer 1's shift dropped, or moved to layer 0 | binding |
| RV3-B15 | the verifier handed layer 0's block at stage 1 | CS-6 |
| RV3-C1a | a 98-bit policy, no segments | the policy |
| RV3-C1b..f | Cn 512; every layer run-wide; BOS 1; one head multiplier; the generic context | binding |
| RV3-C1g | layer 0's block handed in at stage 5 | CS-6 |
| RV3-C1h | block segments 10 and 11 swapped | segment index |
| RV3-C1i | a bit flip in stage OUT | stage OUT A (PCS) |
| RV3-C2 | FULL trained R3: A6-only at id 53,488 (honest 11) | stage OUT slot 07 |

The forger is the honest prover algorithm with its refusals off (and, for
RV3-B12, a witness built at the wrong shape). Deviations from the round
algorithm fall under sum-check soundness and are not tested here.

---

## 5. Files

* Frozen copy `ops/zkp-mvp/token-io-review-r3/`, with manifest
  `ops/zkp-mvp/token-io-review-r3.sha256`.
* Merge products `ops/zkp-mvp/token-io-review-r3-scratch/merge/`.
* My tests:
  `ops/zkp-mvp/token-io-review-r3-scratch/tree/hashline/src/private_block/token_io/run/review_tests.rs`.
* Launcher `ops/zkp-mvp/token-io-review-r3-scratch/launch_r3.sh`.
* Logs `results/zk60_token_io_review_r1_20261017/logs3/`.
* Ledger `results/zk60_token_io_review_r1_20261017/PROGRESS.md` (ROUND 3).
