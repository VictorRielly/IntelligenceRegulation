# D24 review, round 6: verdict on the native R6 tree

Written 2026-10-18 (04:26 UTC) by the independent review lane, after the
usage-limit stop at ~03:17 UTC (my queue finished by itself at 03:20:45; the
results were read at 04:22). **Not a privacy review**; only Victor rules on
privacy.

**What I reviewed**

- **Source.** My frozen copy `ops/zkp-mvp/trained-1b-review-r6/` of the R6
  freeze (2026-10-18T02:36:11Z, tree hash 83f1fdcb...).
- **Integrity.** `ops/zkp-mvp/trained-1b-review-r6.sha256` (219 entries)
  matches `r6/manifest_frozen.json` file for file; the tree hash recomputes;
  the copy was unchanged after every run.
- **Diff.** Every hunk of `r5-vs-r6.patch` (1,610 lines, 11 files, equal in
  size to the author's `r6/r6-vs-r5b.patch`).
- **Binary.** My own CLI from the untouched frozen copy:
  `r6/zk60_trained_block.review-r6.release.bin`, sha256 46a949f6....
- **Log.** `PROGRESS.md`, section ROUND 6.

All measurements: shared box, one run each [MEASURED].

## Verdict

**R6 is ACCEPTED on soundness.** Nothing in it lets a verifier accept
something false, and the three items it was asked to fix are fixed.

1. **r5_A is CLOSED.** The verifier now writes `<run>/statement/` itself,
   from its own rendering and the hashes of exactly the bytes it verified.
   Every attack from round 5 and every new one I tried is refused, with two
   outcomes that are by design (notes N-r6-a and N-r6-e below).
2. **Per-layer `sh_s` is ACCEPTED.**
   - The value enters one relation (the score host) and one lookup
     coefficient; over its whole class 1..=8 the relation stays at or below
     2^21.0 at every profile (p/2 is about 2^63).
   - Each layer's own value is validated at the trained door on both
     sides, bound in the trained identity and in that stage's schedule line
     (so in the run header), and the stage is proved and verified at that
     shape.
   - Run-wide exports keep their identities, including the real 32-block
     8B b6 T128 run (6aba46fb...) and my round-3 rung stack (72098637...).
   - A per-layer export that disagrees with its manifest, its profile or
     the window is refused on both sides, before any run directory exists.
   - The calibration lane's real b7 T128 export loads; my CLI rebuilds its
     identity as **97c4acda9da994c1...**. The native lane's b7 stack landed
     later and is verified in the addendum at the end: its prove printed
     that identity, and my fresh verify accepts it with 11 controls
     refused.
3. **N-r5-a, N-r5-c, N-r5-d are CLOSED.** The CS-3 lookup-miss refusal now
   runs in the sealing pass; the prover's claims are grouped and labelled in
   both statement schemas; the early stdout event is `prover_start` and the
   scope texts say "accepted".

**The two exit-1 jobs the coordinator asked about are explained; neither
is a loader incompatibility.**

- `r6-8b-b6-under-r6`: the R5b-proved run VERIFIED under R6 with its
  identity unchanged (load 12.6 s, verify 33.4 s). The exit 1 came
  afterwards, from the r5_A byte-check of its EXISTING `statement/`, which
  R5b wrote under schema `/1` ("not schema zk60-trained-stack-run/2"). That
  is the intended rule: an older writer's statement is refused, never
  trusted. See N-r6-c.
- `r6-8b-b7-identity`: I passed a deliberate all-zero pin so the CLI would
  print the identity it rebuilds from the per-layer export. Exit 1 is the
  pin mismatch, after the export loaded in full.

## 1. The r5_A fix

**What the code does now** (`trained_block.rs`, `stack_verify_inner`):

1. Before reading anything from a statement directory, `check_statement_dir`
   requires a real directory (a symlink is refused by name, never
   followed) holding exactly its named files, each a regular file.
2. `expected.bin` is read once and must be its canonical encoding.
3. `verify_run_from_dir_hashed_with` returns the length and SHA-256 of
   exactly the bytes each step verified, from the same buffer.
4. After the verify (and the controls), the found `statement.json` must be,
   byte for byte, the verifier's own rendering with the writer and prover
   claims it names (strict parse, duplicate keys refused), and the found
   `segments.json` must equal the verified hashes.
5. For an unverified statement the verifier then writes a fresh
   `statement.writing-<pid>` (`create_dir`), checks the target is absent,
   renames, and removes the prover's directory (re-checked as a real
   directory first). An existing `statement/` is only checked.
6. The in-process path publishes the same way, and its verified hashes must
   equal the prover sink's.

**Attacks** (`review_r6_inner::r6_1`, two-layer rung stacks, `r6/r6-fast.log`):

| attack | result |
|---|---|
| (b) after the verify: segment 1 swapped for another transcript's and the prover's `segments.json` rewritten to name it | refused; nothing published |
| (b') the swap alone | published `segments.json` names the VERIFIED bytes; a later verify of the swapped directory fails |
| (c) duplicate keys + false scope; writer label `InProcess` or `FreshVerify` inside an unverified directory; a non-canonical JSON escape; a 300-character backend; one trailing space | each refused; nothing published |
| (d) the unverified directory is a symlink | refused; the target's marker left intact |
| (d2) a published `statement/` replaced by a symlink to an identical copy | refused |
| (e) a leftover `statement.writing-424242/` from a killed writer | the run no longer verifies at all (see N-r6-b) |
| (i) both `statement/` and the unverified directory present | refused |
| (k) two verifiers publishing the same run at once | exits 0 / 1; no leftover writing directory; a third verify checks byte for byte |
| (c') a canonical but false backend claim | published under `prover_reported` (by design, N-r6-e) |
| (f) a PROVER-written `statement/` naming `stack-verify` as its writer, canonical otherwise | accepted at the byte check after a full verification (N-r6-a) |

The author's port of my r5_3 tests (`trained_stack_tests::review_r5_3_...`)
passes in my run of their tests. My round-3 rung stack: the R6 prover wrote
only the unverified directory; `stack-verify --controls` verified, refused 11
controls and published; a second `stack-verify` reported "statement-checked
... byte for byte this verifier's rendering of the verified run".

## 2. Per-layer `sh_s`

| check | evidence | status |
|---|---|---|
| Export format | `profile_constants` nulls must equal `per_layer_constants_differ` (M1/M2 refused); with `sh_s` listed the run base is the mode over the run's layers, ties to the smaller (O1); the real b7 export: profile `sh_s` null, `per_layer_constants_differ` = [exp_e_s, sh_s, silu_member], layer 1 at 7, 31 layers at 6, all 32 manifests pinned (profile sha256 040eb5cf...). | as described |
| Validation at the door, both sides | `load_layer_mode` records an own value only after `Shape::with_score_shift` (trained shapes only, window 1..=8, CS-8 rebuild, trained class); `new_bound_from_digests` re-validates each own value when the run statement is built (prover and verifier both build it); `check_self` refuses own == base or outside the window. r6_2: layer 1 at 9 or 0, base 9: refused on the verifier AND the prover side with no run directory; the real b7 export with layer 1 set to 9 (re-pinned): "a per-layer sh_s 9 is outside its structure-preserving window 1..=8" in 0.6 s. | accepted |
| Binding | `LayerRecord.sh_s` encoded as `sh-score-layer` only when present; the stage schedule line carries the value only when it differs (so the header's schedule digest moves); stage layout, `prove_core` and `verify_core` run at `stage_shape(k)`. r6_2 M4: layer 1 re-pinned at 7 gives another identity and the run proved at 6 is refused under it; the author's per-layer test (flattened copy refused) passes. Real export: flattening b7's layer 1 to 6 (re-pinned) moves the identity from 97c4acda... to d29c4343.... | accepted |
| No-wrap over the class at every profile | `reviewer_nowrap_r6.py` (`.json`): the score host relation over sh_s 1..=8 is <= 2^20.022 at head_dim 64 (TinyLlama T32/T64/T128) and <= 2^21.0 at head_dim 128 (8B T32/T64/T128); the lookup `scaled(rsl, 2^(8 - sh_s))` keeps the remainder below 2^sh_s at every value; no other clause depends on sh_s. Round 5's full clause set re-run at all six profiles: worst 2^35 (TinyLlama) and 2^36 (8B), far below p/2. [COUNTED] | accepted |
| Run-wide exports keep their identities | round-3 rung stack 72098637... (R6 prove, verify, re-check); the R5b 8B b6 T128 run 6aba46fb... verified under R6 (the schedule digest is absorbed, so the run-wide schedule is unchanged too). | accepted |
| A mismatching per-layer export | M3 (manifest edited, profile digest stale): refused by the manifest digest; M5 (a run-level constant differing in one layer): refused ("one calibration per run"); the sealing pass's parity would refuse a reference computed at another shift before the header. | accepted |
| Sub-ranges | `--layers 1..2` of the per-layer export: base 6, no own record, verifies; its identity differs from the full range's (the layer list was already in the context). | as designed |
| The real b7 T128 stack | landed after this verdict; see the addendum (2026-10-19): prove printed 97c4acda..., my fresh verify accepts it, 11 controls refused, published statement byte-checked with layer 1's own sh_s 7. | verified |

## 3. N-r5-a, N-r5-c, N-r5-d

- **N-r5-a (CS-3 in the sealing pass):** `protocol::check_lookup_misses`
  (the exp/act histograms factored into helpers shared with `prove_core`)
  runs on every sealed witness at its stage shape, before the header. r6_3:
  an exp miss and an act miss are refused by CS-3's name with the table
  family only. CLOSED.
- **N-r5-c (prover claims):** both statement schemas (`/2`) carry
  `prover_reported: {backend, gpu_declines, what}` with a sentence saying a
  verifier cannot check them, and `statement_written_by` names one of three
  writers. CLOSED (see N-r6-a on the writer label).
- **N-r5-d (wording):** `prover_start`; the 8B T64/T128 scope and comments
  say accepted by round 5. CLOSED.

## Findings and notes

| id | what | severity | status |
|---|---|---|---|
| r5_A | the publication was not bound to what was verified | — | **CLOSED** |
| N-r5-a / N-r5-c / N-r5-d | | — | **CLOSED** |
| N-r6-a | the `statement_written_by` label is not authenticated | low (publication semantics, not soundness) | note |
| N-r6-b | a leftover `statement.writing-<pid>` blocks every later verify | low (liveness) | note |
| N-r6-c | an R5b-written `statement/` (schema /1) is refused by R6 after a successful verification | compatibility note | by design |
| N-r6-d | my `r6/queue.out` prints "exit 0" for the two b7 variant jobs | log artefact | — |
| N-r6-e | `prover_reported` claims are unverifiable | by design | labelled |

- **N-r6-a.** A prover can write `<run>/statement/` itself with canonical
  content and the `FreshVerify` writer label (r6_1 (f)). Any `stack-verify`
  still runs the full verification before the byte check, so nothing false
  is ever accepted and the content is correct. What the label cannot prove
  is that a verifier wrote it. Operating rule: the evidence of a
  verification is a `stack-verify` log line (`statement-published` or
  `statement-checked`) or a re-run, never the directory's existence. A
  verifier-held key (a signature over the statement) would make the label
  checkable; that is a design choice outside this review.
- **N-r6-b.** `segment_paths` refuses any foreign entry in the run
  directory, so a `statement.writing-<pid>` left by a writer killed mid-way
  makes every later verify fail until it is removed by hand. Suggestion:
  refuse it by name with a hint, or remove a stale one whose pid is dead.
- **N-r6-c.** The R5b-proved 8B b6 T128 run verifies under R6 with its
  identity unchanged, but its `statement/` was written by R5b under schema
  `/1`, so R6's byte check refuses it. The native lane's
  `r6_compat_prepare.py` re-lays such statements; the proof bytes and the
  identity do not move. Not a loader fault.
- **N-r6-d.** The "exit 0" lines in my `queue.out` for `r6-8b-b7-flat` and
  `r6-8b-b7-shs9` come from `$?` being read after a command substitution in
  the wrapper; the `.done` files and guard records hold the real codes (1
  and 1, both as intended: a printed identity and a door refusal).

## Test runs

- My review tests `r6_1`, `r6_2`, `r6_3`: 3 passed, 0 failed.
- The author's tests of the touched modules on my binary: 72 passed, 0
  failed, 9 ignored (heavy), including `r6_tests` (6), the per-layer stack
  test and `review_r5_3`.
- The author's own full suite on this tree (`r6-suite1`): 700 passed, 0
  failed, 31 ignored. I did not re-run it.

## Evidence (this directory)

- `PROGRESS.md` (ROUND 6), `r5-vs-r6.patch`, `reviewer_nowrap_r6.py` /
  `.json`.
- `r6/`: `r6_queue.sh`, `r6_b7_variants.sh`, `make_b7_variants.py`,
  `binaries.sha256`, and every `r6-*` log, guard record and done marker.
- Scratch `ops/zkp-mvp/trained-1b-review-r6-scratch/`: `review_r6_inner` in
  `hashline/src/private_block/trained_block.rs`; `verifier-8b-b7-T128/` (hard
  links into the calibration lane's export, read only) and its `-flat` /
  `-shs9` variants (fresh copies of the two edited files only; the original
  export is untouched, profile sha256 040eb5cf... re-checked).

## Addendum, 2026-10-19 09:28 UTC: the native lane's b7 T128 stack

The stack landed after this verdict was written:
`results/zk60_1b_native_20261017/r6/stack-llama3_8b_pg_rot1_b7_T128-ho00-cpu/`.
- **Native lane's runs.** The prove finished 2026-10-18T04:58:26Z with the R6
  CLI c17abef1...: 471.7 s wall, peak 6.43 GiB, 922,711,264 B. Their verify
  and their re-check both exited 0.

**The re-check** (`r6/r6-8b-b7-stack-verify.*`, guarded cpu 3/5 GiB, quiet
box: no other guarded job, n=1):

- **Identity.** The prove log prints statement identity
  **97c4acda9da994c11790c2c8ec93b44beecb21501686b7e25965d2c18f970566**. That
  is exactly what my CLI rebuilt from the calibration lane's export in
  round 6 (`r6-8b-b7-identity`).
- **Fresh verify, done independently.** My CLI (46a949f6...) verified the
  stack from MY verifier copy of the calibration lane's original export
  (hard links, no `seq_*`; profile sha256 040eb5cf... re-checked), pinned
  to that identity, with `--controls`:
  - verified, 32 blocks, 922,711,264 B (load 10.2 s, verify 30.6 s);
  - all 11 run-level controls refused, and the honest run still verifies;
  - the f_e + 1 control refused by the counted length, because the T128
    layout moves with the sigma_s limbs;
  - wall 128.5 s, max RSS 2.33 GB.
- **Published statement, byte-checked.** `statement-checked ... byte for
  byte this verifier's rendering of the verified run`. The statement was
  written by `stack-verify`, uses schema `/2`, has run base `sh_s` 6, and
  records **layer 1's own `sh_s` 7** (the only layer with one).
- **Read only.** The native run directory and its `statement/` are
  unchanged: the listing and the statement hashes are identical before and
  after (`r6/r6-8b-b7-before.txt`, `r6/r6-8b-b7-after.txt`).

**Conclusion.** The first real per-layer-`sh_s` stack, the 32-block
Llama-3-8B T128 stack on b7, verifies independently. The R6 verdict
stands.
