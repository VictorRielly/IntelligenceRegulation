# Token I/O — independent adversarial code review, ROUND 4 (TR3 fixes and the token CLI)

Reviewer: the independent adversarial code reviewer (Claude Opus 5.5
subagent; did not write the code), 2026-10-19, 11:37–12:00 UTC. Same rules
as rounds 1–3. **No privacy acceptance and no ruling is made here.**

**Object.** `ops/zkp-mvp/token-io/` at
`results/zk60_token_io_r1_20261017/manifest_final_r4.sha256` (file sha256
`86f5958c…`), frozen at 11:38 UTC into `ops/zkp-mvp/token-io-review-r4/`.
Manifest `ops/zkp-mvp/token-io-review-r4.sha256`: 232 files, list sha256
`1beca5cae036dccd4281410a62c3ccf0ea7302e7ea1acf96e6f5bfa8e59dbae6`. All 231
entries of `manifest_final_r4.sha256` match byte for byte; the extra file is
`BASELINE.sha256`.

**Base.**
* The R7 freeze is intact: all 219 entries of
  `results/zk60_1b_native_20261017/r7/manifest_frozen.json` match.
* The tree differs from R7 in exactly the lane's 19 files:
  * 8 changed: `private_block.rs`, `run.rs`, `run_capture.rs`, `s24`,
    `s25`, `s33`, `hash_domain_tests`, `trained_block.rs`;
  * 11 added: `examples/zk60_token_io.rs`, `token_io.rs`, and
    `token_io/{r0_words, r2_tests, r3_tests, run, stage_in, stage_out,
    tests, load, cli, cli_tests}.rs`.
* R7 differs from R6 only in `trained_block.rs` and
  `trained_stack_tests.rs`.
* The lane's `trained_block.rs` differs from R7's by visibility only: 10
  helper signatures widened to `pub(crate)`, no body changed.

**My binary.** `zk60_token_io`, built from my scratch copy
(`ops/zkp-mvp/token-io-review-r4-scratch/tree/`, which is the frozen tree
plus my test module), sha256 `4bf20de7…`.

---

## 1. Verdict

**Is the token CLI sound?** Yes, for what `prove` and `verify` do.
* **Verify.** It rebuilds the statement from public files only and pins the
  trained identity. It requires the prover's statement to be the canonical
  rendering, with a backend from the build's own list. It verifies the
  bytes it read and hashes those same bytes. It then publishes
  `statement/` itself, through the R7 write-then-rename path, and never
  replaces a statement. A second run re-checks the published statement byte
  for byte. These refusals all held:
  * a tampered segment;
  * a statement written by the prover;
  * an export holding `seq_*`;
  * the wrong export, under its own pin or the run's;
  * a policy above the derived figure.

  Two verifiers racing over one run leave exactly one statement, and it
  re-checks.
* **Prove.** It writes `<out>.incomplete/` and renames it only after `Ok`.
  A refusal mid-run (parity at block 0, after stage IN's segment was
  written) left nothing behind. Every refusal I provoked left no directory
  at all.

**Do its outputs leak hidden data?** Not on the outputs a verifier or
audience sees:
* the published `statement.json` holds public model facts, the derived
  figure, the context and the two random roots;
* `segments.json` holds lengths and hashes;
* stdout of `prove` and `verify` holds identities, lengths, timings and the
  floor;
* refusal texts carry the class of the problem, never the prompt id, the
  token or a malformed prompt entry (RV4-3).

The owners' decommitments are files of mode 0600 outside the run directory.
But see TR4-3 on where they go.

**The 8B demo artefacts through my own binary:**
* the re-check verify of the lane's published 8B statement passes;
* an independent publication from the same bytes is **byte for byte the
  lane's** `statement.json` and `segments.json`;
* the owner reads **token 11**;
* a tampered copy is refused at block 19;
* `--min-bits 98`, the prover's export (`seq_*`) and the input
  decommitment given to `owner` are each refused.

**Fit to be shown in a demo?** **Yes, with two fixes (or an explicit
procedure) first.** Both findings are MEDIUM because of what the demo would
claim, not because the proof is unsound:
* **TR4-1.** `owner` does not establish that the run verified. It answers
  after a segment is tampered and over a `statement/` the prover wrote.
  Reproduced at 8B: owner prints 11 over a tampered receipt that verify
  refuses.
* **TR4-2.** The verifier's pin covers the trained blocks but not the token
  stages: the embedding, the head and its multipliers, BOS and the final
  norm. A run proved with another head, or another Cn, verifies and is
  published under the same pin.

The fixes are small: make `owner` re-verify, and add a pin on the
statement's `token_profile_digest`. Without them, the demo must run
`verify` on the same directory immediately before `owner`, and show the
table SHAs matching the calibration lane's manifest. Also move the owners'
decommitments out of `results/` (TR4-3).

---

## 2. Findings

### TR4-1 — MEDIUM — `owner` checks against `<run>/statement/` without establishing that the run verified

**Where.** `token_io/cli.rs` `owner_inner`. It checks the statement
directory's file names, that the writer line says "verify", and that the
statement is the canonical rendering for the found roots. It then checks
the decommitment against those roots. It never reads `segments.json`
against the segments, and never verifies the run.

**Reproduction.**
* RV4-2 (rung):
  * after an honest publication, one segment is flipped: `verify`
    (re-check) refuses, `owner` exits 0;
  * the prover writes `statement/` itself (the unverified statement with
    its writer line changed, `segments.json` arbitrary) and no verifier
    ever runs: `owner` exits 0.
* At 8B (c4 / c5): a copy of the lane's run with `segment-020.bin` flipped
  is refused by verify ("block 19: A: pcs zk: Merkle path … fails"), yet
  `owner` prints `next token 11`.

**Impact.** The owner command's output, "the next token", is shown as the
verified result, but nothing in the command establishes verification. D25
T5 / DESIGN 3.4 say the owner checks the decommitment "against the
receipt". The writer line is plain text that anyone with write access to
the run directory can produce. In the demo the run directory is the
prover's.

**Fix.** Make `owner` run the same check as `verify`'s re-check path:
* re-read the segments;
* verify them under the policy;
* compare with `segments.json`;
* only then print the token.

That costs about 50 s at 8B. Alternatively, `owner` refuses unless the
statement directory lives where only the verifier writes. Until then, every
demo and doc must run `verify` (re-check) on the same directory immediately
before `owner`.

### TR4-2 — MEDIUM — the verifier's pin does not cover the token stages' constants

**Where.** `public_inputs` (`verify` and `owner`). `--expect-statement` is
compared with `TrainedModelStatement::identity()`, which covers the blocks,
the calibration and the source. The embedding, head and multiplier tables,
BOS and the final norm (Cn, tn, Ceps, g0) come from `--emb` / `--head`
manifests and are not pinned.

**Reproduction** (RV4-1, rung).
* Head: a run proved with every head multiplier changed, handed to a
  verifier together with those tables, **verifies and is published** under
  the same pin.
* Final norm: the same happens with a run whose head manifest names half
  the Cn.

The published statement does name the changed head SHA or Cn, so it is
truthful. But the verifier's acceptance never confirmed that these are the
approved model's tables.

**Impact.** For a claim like "Llama-3-8B's next token", the head, the
embedding and the final norm are part of the model. A verifier given a
substituted table set (for example a "verifier copy" prepared by the
prover) publishes a statement for a different next-token function, and the
pin check passes.

**Fix.** Pin the token stages too. The statement already carries
`token_profile_digest` (V, BOS, final norm, both table digests, multiplier
class, tier). Add `--expect-token-profile HEX` to `verify` and `owner`, or
fold it into a combined pinned identity. Record the 8B value from the
calibration lane's manifest.

### TR4-3 — LOW — where the owners' decommitments go (D21)

**What happens.** `prove` writes `<out>.owner-private/{input,output}.dec`
as a SIBLING of the run directory, in the same parent. The files are mode
0600; the directory is the default 0755 (RV4-4: listable, not readable). In
the demo, that parent is `results/zk60_token_io_r1_20261017/cli/`. Git does
not ignore it (`git check-ignore` exit 1), so a routine snapshot would
retain both decommitments, and `input.dec` carries the prompt ids in clear.

D21: the decommitment is a private artefact, never in a published or
retained bundle. The data here is public calibration text (ho00), so
nothing secret leaked, but the shipped layout contradicts the rule. Any
"publish the run's parent directory" step would expose the decommitments.

**Fix:**
* create the directory 0700;
* require an explicit `--owner-dir` outside the run's parent, or default
  to a private location;
* in the demo, move `run-b7_T32-ho00.owner-private/` out of `results/` (or
  git-ignore it) before the next snapshot.

### TR4-4 — INFO

* **No input-owner command.** `input.dec` is written but the CLI has no
  `owner --input` (`owner_check_input`: BOS, prompt, zero pads, the root).
  The input owner cannot check its seal from the command line.
* **The table opener.** `load.rs::read_exact_streamed` opens the table
  files with `File::open` after a `symlink_metadata` check. That leaves a
  window where a swapped-in link is followed. It is bound anyway by the
  streamed SHA-256 and the statement's table digests. Use R7's
  `SEGMENT_OPEN_FLAGS` (`O_NOFOLLOW | O_NONBLOCK`), as
  `read_regular_file_bounded` does.
* **A killed prove.** A prove killed mid-run (SIGKILL) leaves
  `<out>.incomplete/`. A retry with the same `--out` refuses by name, and
  nothing in it is verifiable: no statement, and the endpoints were fresh
  seals.
* **Publish order.** `prove` renames the run into place before it writes
  the owners' files. A crash in between leaves a verifiable run with no
  decommitment. That loses the owner's answer; it leaks nothing.

### Round-3 items, status

| item | fix | check | status |
|---|---|---|---|
| TR3-1 | every block checked (CS-1 / CS-4 / CS-6 at its stage shape) before the first segment; the per-stage check kept; the CLI's `<out>.incomplete/` renamed only on `Ok` | the lane's fail-first test (0 segments); my RV4-4a (refused mid-run, nothing left) | **closed** |
| TR3-2 | `token_io/load.rs`: manifests bounded from regular files, strict JSON; tables length-checked, exact chunked reads, streamed SHA-256, links refused; export source with the digest check on reload | the lane's tests (truncated manifest refused by name; wrong digest, short file, link) | **closed** (opener note in TR4-4) |
| TR3-3 | `layers[k].block_digest == block_digests[k]` asserted where the shift is read | code | **closed** |

---

## 3. Tests run

All through the resource guard, detached, waiting on `.done` markers
(`ops/zkp-mvp/token-io-review-r4-scratch/launch_r4.sh`; logs
`results/zk60_token_io_review_r1_20261017/logs4/`) [MEASURED, shared box,
n=1].

| step | result |
|---|---|
| builds (tests; CLI example) | exit 0 / exit 0 |
| `cargo test --release --lib token_io -- --test-threads 2 --nocapture` | **38 passed, 0 failed, 6 ignored** (incl. the lane's two CLI end-to-end tests, TR3-1 / TR3-2, and my 5 `rv4_*`); 77 lines `AS PREDICTED`, 0 `NOT` (141 s) |
| c1 `verify` (re-check) of the lane's published 8B statement | `statement-checked`, exit 0 (verify 48.2 s, total 80.1 s) |
| c2 `verify` publishing from a reconstructed unverified statement over the same bytes | `verified`, exit 0; published `statement.json` and `segments.json` **IDENTICAL** to the lane's |
| c3 `owner` with the lane's `output.dec` | **`next-token` 11**, exit 0 |
| c4 `verify` of a copy with `segment-020.bin` flipped | refused at block 19 (Merkle path), exit 1 |
| c5 `owner` over that tampered copy | **`next-token` 11, exit 0** (TR4-1) |
| c6 `verify --min-bits 98` | refused (97 bits below 98), exit 1 |
| c7 `verify` given the prover's export (`seq_ho00`, `seq_ho09`) | refused (P-5), exit 1 |
| c8 `owner` with `input.dec` | refused (does not rebuild the root), exit 1 |

My 8B artefact directories (`ops/zkp-mvp/token-io-review-r4-scratch/b8/`)
hard-link the lane's 34 segments read-only and copy its two statement
files. Nothing in the lane's directories was written.

`REVIEW-R4` lines from the unit tests:

| id | probe | result |
|---|---|---|
| RV4-1a / b | a run proved with another head, or another Cn, verified under the same identity pin | **ACCEPTED and published** (TR4-2) |
| RV4-2 | owner after an honest verify | accepted (correct) |
| RV4-2a | verify (re-check) after a tampered segment | refused at stage OUT A |
| RV4-2 (owner) | owner after the tampering; owner over a prover-written `statement/` | **ACCEPTED** (TR4-1) |
| RV4-2b | verify (re-check) over the prover-written `statement/` | refused (`segments.json` not the verified hashes) |
| RV4-3a / b / c | prompt with a non-BOS 263; an id 4321 ≥ V; an entry `x9y` | refused with fixed texts naming none of them; nothing left behind |
| RV4-3d | owner given the input decommitment | refused; the text does not contain the token |
| RV4-4a | prove refused mid-run (parity at block 0, after stage IN's segment) | refused; **nothing left behind** |
| RV4-4 (placement) | where the decommitments go | sibling directory, mode 755, files 600 (TR4-3) |
| RV4-4b | prove whose `<out>.owner-private` exists | refused, nothing written |
| RV4-5a / b | another export with the run's pin / its own pin | refused (pin; context) |
| RV4-5 (race) | two verifiers at once | one published, one refused (`statement.writing-<pid>` exists); after the race exactly `statement/`, which re-checks |

---

## 4. Files

* Frozen copy `ops/zkp-mvp/token-io-review-r4/`, with manifest
  `ops/zkp-mvp/token-io-review-r4.sha256`.
* My tests:
  `ops/zkp-mvp/token-io-review-r4-scratch/tree/hashline/src/private_block/token_io/cli/review_tests.rs`.
* `prep_b8.py`, `launch_r4.sh`, and the 8B artefact copies `b8/`, all in
  `ops/zkp-mvp/token-io-review-r4-scratch/`.
* Logs `results/zk60_token_io_review_r1_20261017/logs4/`.
* Ledger `results/zk60_token_io_review_r1_20261017/PROGRESS.md` (ROUND 4).

---

## ROUND 5 (2026-10-19, 13:39–14:27 UTC): confirmation of the TR4 fixes

**Verdict (one line): yes, the token CLI is demo-fit now.** All four TR4
fixes hold, both in the tiny reproductions and on the 8B artefacts through
my own binary, and the layer-0 pre-check refuses by name and claims nothing
it lacks. One new LOW, TR5-1: two proves sharing an owner directory can
delete the winning run's decommitments. Until it is fixed, run demo proves
one at a time with distinct run names. No privacy acceptance and no ruling
is made here.

**Object.**
* `ops/zkp-mvp/token-io/` at
  `results/zk60_token_io_r1_20261017/manifest_final_r5.sha256` (file sha256
  `5f7d155e…`).
* Frozen at 13:39 UTC into `ops/zkp-mvp/token-io-review-r5/`, manifest
  `ops/zkp-mvp/token-io-review-r5.sha256`: 232 entries, list sha256
  `1366de3c…`.
* All 231 entries of `manifest_final_r5.sha256` match. They were re-checked
  at 14:25 with 0 mismatches.
* Changed against r4: `token_io/cli.rs`, `cli_tests.rs`, `load.rs`,
  `src/private_block.rs`, `examples/zk60_token_io.rs`.

**My binary** (sha256 `51269365…`) is built from my scratch copy: the frozen
r5 tree plus one `#[cfg(test)] mod review_tests;` line, which the example
binary does not contain. The lane's r5 binary is `da48f6d4…`; the two differ
by the embedded build path.

### R5.1 The TR4 fixes, item by item

**TR4-1: closed.** `owner` and the new `input-owner` now run `check_run`
before printing anything. `check_run` does all of the following:
* pins the identity;
* pins the token profile;
* checks the statement is canonical;
* re-verifies every segment;
* requires `segments.json` to equal the hashes this process saw;
* reads only a statement a verifier published.

Round-4 reproductions, now refused:
* **Owner over a tampered copy.**
  * Tiny run: RV5-1e/f, `stage OUT A: pcs zk`.
  * 8B: c1 (owner) and c2 (input-owner) on `art-tamper`, segment 020
    flipped, both refused with `block 19: A: pcs zk: Merkle path for column
    2123 fails`.
  * In round 4 the owner printed token 11 here.
* **Owner over a `statement/` the prover wrote**, i.e. the canonical
  statement text with its own `segments.json`. Refused with "not the hashes
  of the bytes this verifier verified":
  * tiny: RV5-1g;
  * 8B: c4.
* **Owner with no verifier-published statement**, only the prover's
  unverified one. Refused with "no statement a verifier published; run
  `zk60_token_io verify` first":
  * tiny: RV5-1a;
  * 8B: c3.

Honest paths and controls:
* Honest runs pass:
  * tiny: RV5-1b/c;
  * 8B: c9 owner gives token 11, c10 input-owner gives `input-checked`;
  * the lane's r5 demo run, re-checked from a hard-linked copy: c12
    statement-checked, c13 token 11, c14 input-checked.
* A wrong prompt is refused: RV5-1d and c11, "the sealed input plane is not
  the owner's prompt".
* The round-4 run's decommitment over the r5 run is refused (c15, "does not
  rebuild the receipt's root").
* The printed line now says what it was checked against: "the published
  statement, re-verified against every segment in this process". Each
  owner command costs one full verification (about 98 s at 8B, peak RSS
  2.8 GiB) [MEASURED].

**TR4-2: closed.** `--expect-token-profile` is required on verify, owner
and input-owner. Without it the command is refused: RV5-2c and c6,
"--expect-token-profile is required". The pin is compared with
`TokenProfile::digest_under(profile)`, which the command rebuilds from the
tables, BOS and final norm it was handed.
* **Tiny, round-4 reproduction.** A run proved with another head (every
  multiplier changed) or with half the Cn is refused under the approved pin
  (RV5-2a/b), and nothing is published. The same runs are accepted only
  under their own tables' pin. That is by design: the pin is the verifier's
  choice.
* **8B, my binary.**
  * `profile` on the prover's export and on the verifier copy both give
    `e8238cf1…7132`, equal to the lane's `token_profile_pin_b7_T32.txt`
    (p1/p2).
  * A wrong pin is refused (c5).
  * The verifier's tables with one head multiplier changed (row 0, 2086 to
    2087, with the manifest SHA updated) give profile `8b4a8b1e…`. Under the
    approved pin they are refused by the pin (c7). Under their own pin they
    are refused because the published statement is not canonical for those
    tables (c8).

**TR4-3: closed, edges below.**
* The default owner directory is
  `$HOME/zk60-artifacts/token-io/<run name>.owner-private`, with the base
  created 0700.
* An owner directory whose canonical parent lies under the run's canonical
  parent is refused. Tested:
  * the run's parent itself (RV5-3a);
  * an existing subdirectory of it (RV5-3b);
  * a symlink to it (RV5-3c).
* The directory is 0700 and its files 0600 (RV5-3; on disk for both 8B
  runs).
* No owner material remains under `results/`: the old
  `cli/run-b7_T32-ho00.owner-private` has moved to the default location.

**TR4-4: closed.**
* Table files are lstat-checked as regular files, opened
  `O_NOFOLLOW|O_NONBLOCK`, and re-checked by fstat. A symlinked
  `embedding_int16.bin` is refused before it is opened (p4).
* `prove` writes the owner files and the unverified statement before the
  final rename.

### R5.2 Findings

#### TR5-1 — LOW — prove's error path removes an owner directory it did not create

**Location.** `token_io/cli.rs`, `prove_inner`:
* The `written` closure begins with `create_private_dir(&owners_dir)?`.
* Its error branch runs `let _ = std::fs::remove_dir_all(&owners_dir);`.
* The existence check on the owner directory runs at the start, minutes
  before the directory is created.

**What goes wrong.** Suppose another prove creates the same directory in
that window. This prove's `create_private_dir` fails with EEXIST, and its
cleanup then deletes the other run's `input.dec` and `output.dec`. The other
run has already printed `proved` and exited 0. Its blinding is OS-seeded,
so the decommitments cannot be recovered.

**When it triggers.** Two concurrent proves with:
* the same `--owner-dir`; or
* the same run base name in different directories under the default,
  because the default is keyed by base name only.

**Reproduction.** RV5-3 collision, two threads, `p1/same` and `p2/same`
sharing one owner directory [MEASURED]: one returns exit 0, the other "File
exists (os error 17)", and the owner directory is **GONE** afterwards.

**Not affected.** The same `--out` twice: the early `incomplete` check and
the plain `create_dir(&incomplete)?` keep that case clean.

**Minimal fix.** Claim the owner directory atomically at the start: call
`create_private_dir` in place of the `symlink_metadata` check. Then remove
it on error only because this process created it. Or move
`create_private_dir` out of the closure whose failure triggers the cleanup.
Treat `create_dir(&unverified)` the same way.

#### TR5-2 — INFO — the layer-0 pre-check: wording at its edges, no coverage claimed that it lacks

Tested (light Python, logs `logs5/precheck/`):
* The lane's 4 unit tests pass.
* The b7_T32 ho00 prompt gives `clear`, exit 0, by `--prompt` and by
  `--seq`.
* 662 and 16309 give exit 2, each named with id, text, positions, site V and
  the fix.
* b7_T64, and b6_T64 with the b7 embedding, match the b7 fingerprint and
  refuse by name. This is legitimate: their layer_00 weights and their
  manifest without RoPE are byte-identical to b7's.
* These give `not-covered` ("nothing claimed"), exit 0:
  * the non-b7 8B T32 export;
  * TinyLlama 1B;
  * the fidelity lane's voc0 variant.
* These give exit 1:
  * a missing `token_io/` embedding;
  * a malformed prompt.
* Fingerprint coverage is complete for the scanned sites: the embedding,
  gamma_a, wq/wk/wv, and the layer_00 constants (norm_cn_a, sh_qkv, f_ro,
  …).

Edges:
* **(a) "clear" does not print its scope.**
  * The scan covers only the layer-0 norm_a / Q / K / V / RoPE sites.
  * It does not cover layer-0 scores (the loose bound is 588 against class
    127) or anything after attention.
  * The tool's docstring line "Layer-0 values depend on the token only"
    overstates this.
  * A "clear" prompt can still be refused by the prover, which is safe.
  * Fix: put the entry's `scan_scope` and "scores and later layers not
    covered" in the clear line.
* **(b) `check` never reads the export's RoPE tables.** `record` checks
  their prefix only for `--also-export`. With QR/KR bounds of 66/67 against
  127, taken as a max over unit-norm rotations, no real RoPE table changes
  the answer. A prefix check in `check` would make it exact.
* **(c) "not-covered" exits 0**, the same as "clear", so the demo proceeds.
  It is labelled and claims nothing; that is acceptable.
* **(d) A refusal names the prompt's tokens and positions.** That is fine on
  the prover's side. But the demo writes `d0-precheck.log` into the
  repository's `logs/`, so treat it as prover-private for any
  non-calibration prompt.

#### TR5-3 — INFO — owner-directory and pin edges

* **(a)** An explicit `--owner-dir` anywhere outside the run's parent is
  accepted, including elsewhere inside the repository (for example beside
  the export). "Outside the repository" holds for the default only.
* **(b)** With `--out` directly under `$HOME`, the default owner directory
  is refused: the run's parent is an ancestor of
  `$HOME/zk60-artifacts/token-io`. Such runs need an explicit
  `--owner-dir`.
* **(c)** The demo derives its token-profile pin by running `profile` on
  the prover's export with the binary under test.
  * The digest is reproducible: my binary gives the same value from the
    verifier copy.
  * But a verifier given another head's own pin accepts a run proved with
    that head (RV5-2 note).
  * So the approved pin must come from the calibration lane's approval
    record, never from the prover's files.

### R5.3 Tests run (round 5)

| id | what | result |
|---|---|---|
| t1 | `cargo test --release --lib token_io` (cpu-guarded, 188 s, peak 2.50 GiB) | 39 passed / 0 failed / 6 ignored (the lane's 36 incl. tr4_1..3 + my 3); 78 AS PREDICTED, 0 NOT |
| p1 / p2 | `profile`, prover export / verifier copy | both `e8238cf1…7132` = the lane's pin file |
| p3 / p4 | `profile`, one-multiplier tables / symlinked embedding | `8b4a8b1e…` / refused, not a regular file |
| c1 / c2 | owner / input-owner over `art-tamper` | refused, block 19 pcs |
| c3 / c4 | owner, unverified-only / prover-written `statement/` | refused / refused |
| c5 / c6 | verify, wrong / no token-profile pin | refused / refused |
| c7 / c8 | verify with one-multiplier tables, approved / own pin | refused (pin) / refused (statement not canonical) |
| c9 / c10 / c11 | owner / input-owner / wrong prompt on `art-recheck` | token 11 / input-checked / refused |
| c12 / c13 / c14 | the lane's r5 run: verify / owner / input-owner | statement-checked / token 11 / input-checked |
| c15 | the r5 run with the round-4 run's output.dec | refused, root not rebuilt |

### R5.4 Files (round 5)

* Frozen copy `ops/zkp-mvp/token-io-review-r5/` (+ `.sha256`).
* `ops/zkp-mvp/token-io-review-r5-scratch/`:
  * `tree/.../token_io/cli/review_tests.rs`;
  * `prep_b8_r5.py`;
  * `launch_r5.sh`;
  * `b8/` (hard links, a one-multiplier table copy, a symlinked-embedding
    table copy).
* Logs `results/zk60_token_io_review_r1_20261017/logs5/`.
* Ledger `PROGRESS.md` (ROUND 5).
* Nothing of mine is pending (no `trv5-*` job in the guard status;
  `logs5/launch_r5.done` = 0).
