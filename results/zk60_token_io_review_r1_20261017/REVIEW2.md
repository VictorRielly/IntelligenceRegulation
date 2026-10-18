# Token I/O — independent adversarial code review, ROUND 2 (TR fixes + rung R2)

Reviewer: the independent adversarial code reviewer (Claude Opus 5.5
subagent; did not write the code), 2026-10-18, 01:42–03:00 UTC. Same rules
as round 1 (`ops/zkp-mvp/LANE_RULES_20261017.md`): every cargo leaf through
the resource guard, detached with `.done` markers, no git writes. **No
privacy acceptance and no ruling is made here.**

**Object.** `ops/zkp-mvp/token-io/` at the lane's final manifest
`results/zk60_token_io_r1_20261017/manifest_final.sha256` (file sha256
`1ef25c3c…`), frozen at 01:43 UTC into `ops/zkp-mvp/token-io-review-r2/`.
Manifest `ops/zkp-mvp/token-io-review-r2.sha256`: 225 files, list sha256
`5c4e14b84407ae3830ee4480feced5258c5f69fc71528c648ce1eb8fb0d8bcfb`. All 224
entries of `manifest_final.sha256` match byte for byte; the extra file is
`BASELINE.sha256`. The R2 receipt I re-verified is the lane's
`runs/r2/ho00/`: 24 segments, 255,258,816 B, sha256 over the per-segment
sha256s `687b6cba3defd72f38e40e41e78bf2d9fe9c908f1139030752a127b6f7c4072d`;
`statement.txt` sha256 `6341f768…`. My tests live in
`ops/zkp-mvp/token-io-review-r2-scratch/tree/` (the frozen tree plus
`hashline/src/private_block/token_io/run/review_tests.rs` and one
`mod review_tests;` line).

---

## 1. Verdict

**Do the TR fixes close the round-1 findings?** Yes.
* TR-1 to TR-5 are closed. I re-ran every one of my round-1 probes on the
  final tree, and each is now refused at the place the fix put it (§3.1).
* TR-6 is carried as a gate-checklist exception: it is informational, with
  no soundness or privacy consequence.
* TR-7 is a recorded decision: the run keeps the block shape's hash-tag key
  set, and the design's sentence should be amended.

**Is R2 sound as built?** Yes, at the level I could test.
* **Real data, two layers.** On R2's real tables (32,000 × 2,048 embedding,
  per-row int8 head with 12-bit multipliers), the R2 profile, eight-row
  vocabulary planes and the calibrated `Cn = 5,664`, I proved 12 forgeries
  over the export's first two trained layers. All 12 were refused at the
  predicted slot. They cover:
  * a selector on the last, partial row;
  * A6-only and A3-only forgeries across vocabulary rows;
  * a histogram count moved onto a padded table entry (invisible to LogUp);
  * a limb or a second hot entry on the last cube entry (32,767);
  * a value on the channel domain's lift;
  * the logits from row T−2 of the 16-row `B_out`;
  * a padded token id in the eighth row;
  * block 0 proved on another input;
  * a consistent re-lookup under the honest seal;
  * a histogram count moved between real ids in different rows.
* **Full scale.** Two more forgeries at the full 22-layer R2 statement were
  refused: A6-only across rows (86.7 s to prove), and the histogram moved
  onto a padded entry.
* **The lane's receipt.** The lane's saved ho00 receipt (token 29914,
  255,258,816 B) verifies with **my** binary in a fresh process from the
  saved bytes, in 8.9 s, under a 95-bit policy. So does the lane's own
  verify test run with my binary (9.1 s).
* **Probes on that receipt.** Ten probes were each refused:
  * policies above its 97 bits, refused before any segment is read;
  * a statement inflated to 120 bits;
  * the refusal-free `Cn`;
  * another sequence's context;
  * the two roots swapped;
  * a 21-layer prefix statement;
  * two block segments swapped;
  * a bit flip in stage IN's segment;
  * one changed head multiplier.

**Multi-row layout, whole-run figure, D20.**
* **Layout.** The multi-row row counts re-derive by hand to the counter
  (stage IN 17 / 28 rows, stage OUT 182 / 110). The pad terms bind every
  entry of every lifted or padded domain across rows. The IO slots sit on
  single-row token endpoints and on the existing multi-row boundaries.
* **Whole-run figure.** It is derived from the levers inside
  `TokenRunStatement::new`, bound through the parameter line, and checked
  against the verifier's policy before any segment is read. **A statement
  cannot claim more than its levers give**: an inflated figure changes the
  transcript and is refused. The only way to get a higher figure accepted is
  to mutate the statement object in-process (R2-3).
* **D20.** The final-norm int8 overflow at the calibrated Cn is refused by
  the honest pipeline before any commitment, with a fixed text that names
  no position or value. The R2 unit test fires it on a crafted row. On real
  data, ho00 at layer 21 (max |y| 49) and my two-layer prefix (max |y| 55)
  are admitted.

**May R2 stand as the trained-model next-token result?** **Yes**, with this
wording: a proved greedy next token of the integer, calibrated TinyLlama-1.1B
(the `pg_rot1` export, 22 trained blocks, T32). The run is one hidden token
under the public-row variant, the prompt fills T = 32, and BOS is forced. The
proved token equals the independent references: R0 in Python, and the
fidelity lane's integer and float heads at the same position. Parity with the
export is bit-exact at all 22 boundaries. The figure is 97 bits whole-run in
the derived convention, at TinyLlama T32 [COUNTED].

It is **not**:
* a privacy acceptance (the G-1..G-7 rank / CFS gate is owed);
* a hidden prompt length;
* a token stream (D25 T6);
* a proof that the tables derive from the checkpoint (D25 T7);
* a figure at the named D27 workload.

**May it be the base for R3 (Llama-3-8B)?** **Yes, conditionally.** No R2
finding is above LOW. R3 still needs the work in §3.6:
* streaming blocks: today's run holds `&[BlockPublic]`, 7.4 GB at 8B;
* `V_pad = 2^17`, exactly the door's `MAX_DOM_LOG`;
* BOS 128000;
* the new profile through the W-2 census;
* R2-1 fixed before an 8B figure is quoted;
* its own R3-scale controls on the 32-row vocabulary planes.

---

## 2. Findings (round 2)

Severity scale as in round 1. **No HIGH or MEDIUM finding in round 2.**

### Status of the round-1 findings

| round-1 | fix in the final tree | my probe re-run (RV2-A*) | status |
|---|---|---|---|
| TR-1 MEDIUM (tier door, no policy) | `Tier::REGISTERED` (name and levers); B-1 floors in `Tier::check` (stage row ≥ 2^12, stage ≤ 2^-103, endpoint ≤ 2^-106 per opening); `WholeRun` derived in `TokenRunStatement::new` and bound in the parameter line; `VerifierPolicy` checked before any segment | refused at the door AND by the statement: endpoints at rate 1/4 and 1/2, stage at 2^9, stronger levers not registered, F_p^3. Policy above the derived figure refused (R1 rung 93 bits; R2 97 bits) | **closed** |
| TR-2 LOW-MED (Q lever) | M opening sized from `zk.rs` (`MASK_Q`, `MASK_VEC`, `MASK_DOM`); `Tier::check` refuses Q ≠ `MASK_Q` until a Q ≠ 256 run is built | Q = 128 and Q = 1 refused by name | **closed** (the lever is shut, not built: honest) |
| TR-3 LOW (variants) | `variant_is_built` in the endpoint specs, the statement, the prover and the verifier | a forged public-row receipt under a statement relabelled P or F, proved by a prover with that refusal removed: **verifier refuses** | **closed** |
| TR-4 LOW (owner check) | `owner_check_input` (root, BOS, ids < V, zero pads, = the owner's prompt) and `owner_check_output` (root, id < V, zero pads), both over the statement | my round-1 planes refused (BOS; id ≥ V); the input decommitment to the output owner, and an honest decommitment under another run's statement, both refused | **closed** |
| TR-5 INFO (−128) | the door refuses −128; the class is in `describe()` | refused | **closed** |
| TR-6 INFO (To entry 1) | listed as a gate-checklist exception, with a planned control | — | open, accepted as an exception |
| TR-7 INFO (key set) | decision: keep the block shape's key set (measured rule for every run) | — | design sentence to amend |

### R2-1 — LOW — the whole-run floor's margin is claimed in a comment, not enforced

**Where.** `token_io/run.rs`, `whole_run_of` and the doc comment on
`WholeRun`.

**What the code does.** The figure leaves out the PCS field terms and the
sumcheck terms. The comment says flooring to whole bits "covers them while
the total stays more than 2^-12 away from the next whole bit". The code
floors `-total_log2` without checking that margin.

**Today.** At R2 the total is 2^-97.335, so the slack under the claimed
2^-97 is 2^-99.27, far above the omitted terms (below 2^-105 per run,
MEMO_G02). At the R1 rung the total is 2^-93.32. Both are safe.

**Risk.** A future profile whose total lands just under a whole bit (say
2^-97.001) would be credited 97 bits with a slack of only about 2^-107.5. The
omitted terms could then exceed it.

**Fix.** Add an explicit conservative bound for the omitted terms to the
total before flooring (e.g. 2^-105, or the per-run sum of `degree × vars /
|F_p^2|` plus the PCS field terms). Alternatively, refuse the statement when
the margin is below that bound.

### R2-2 — INFO — stage IN's LogUp term borrows the block's derivation

`stage_in::logup_size` returns `(2^h_log[H_Q], V)`, and the figure applies
the block convention `(N + 3R − 1)/|F_p^2|`. Stage IN's table, however, is a
tuple compressed with a challenge-dependent column point `r_emb`. A
collision is then a polynomial of total degree `1 + log2 d_pad = 12` in
`(beta, r_emb)`, not degree 1. Stage IN also has its own `B_in`-binding term,
`T · log2 d_pad / |F|`.

Recounted at R2, the term is about 2^-109.2 instead of the code's
2^-111.4. Against the total 2^-97.33 that is negligible. The figure should
still cite a derivation for this lookup. **Fix:** a stage-IN-specific term
`(N + R(2 + log2 d_pad) + T log2 d_pad)/|F_p^2|`, or a one-line note that it
is dominated.

### R2-3 — INFO — `TokenRunStatement::whole_run` is a mutable `pub(crate)` field

From bytes there is no way to inflate the figure: RV2-A4 and RV2-C1c are
refused by binding. But a verifier handed the mutated statement *object*
accepts at a 120-bit policy (`REVIEW-R2 FINDING TR2-figure`). **Fix:** make
the field private with a getter, so the derived constructor is the only
source of a figure.

### R2-4 — INFO — the tier's name carries a number the statement does not

The registered tier is named `mvp-95-whole-run (D27)`. The statements derive
93 bits (the R1 development rung) and 97 bits (R2), and the derived figure is
the one that binds. A reader of the name could over-read it. **Fix:** a
workload-neutral name, or document that the 95 refers to the named D27
workload.

### R2-5 — INFO — D20's "before any commitment" holds at the pipeline (ruling H-1), not inside `prove_token_run`

`prove_token_run` streams each segment to the sink as soon as its stage is
done. A caller that bypasses the honest pipeline and hands a stage-OUT
witness that overflows gets L + 1 segments emitted before stage OUT refuses.
The refusal text names only the class ("the witness looks up a value that
is not a byte"). This is the inherited streaming design. The honest path
(`honest_pipeline`, the R2 pipeline) refuses before the header exists.
**Fix:** none needed for R2. Document that a sink publishes nothing until
`prove_token_run` returns `Ok`.

### R2-6 — INFO — cosmetic

`TokenProfile::describe()` still begins with `token-io R1:` at R2, as the
lane noted. The block parameter line inside a token run says
`two-private-endpoints`, although the block's endpoints are internal
boundaries there. Both texts are transcript-bound and harmless; rename them
at the next profile change.

---

## 3. Item by item

### 3.1 Each TR fix against its finding (brief item 1)

The table above. My probes are in `review_tests.rs`:
`rv2_a1_the_round1_tier_probes_are_refused`,
`rv2_a2_an_unbuilt_variant_is_refused_by_the_verifier_even_for_a_forged_receipt`,
`rv2_a3_the_owner_checks_refuse_the_round1_planes` and
`rv2_a4_an_inflated_whole_run_figure_does_not_verify`. The lane's own
fail-first runs also check out in the ledger: t3, the six `tr*` tests,
failed before the fixes, and t4b passed after (t4 was voided because of
preserved file times).

The census edits (s24, s25, s33, hash_domain) only extend counts and lists
to the new code. One change looks like a relaxation and is not: the W-2
check now collects every undeclared equal-length pair before failing, with
the same assertion. Nothing was weakened.

### 3.2 The multi-row layout (brief item 2)

* **Domains.** Each domain sits at `max(natural padded log, stage row log)`:
  `Ti` 12, `Voc` 15, `Lo` 12, `Do` 12 (`d_pad` 2^11 lifted by one bit), `Vo`
  15, `Tab` 12. Planes are row-aligned, and a plane wider than a row spans
  whole rows (Voc and Vo planes: 8 rows each).
* **Row counts.** These are derived by `StageLayout::new`, and I re-derived
  them by hand. Stage IN: A 9 data rows (`tok` 1 + `m` 8) + 2·3 site rows + 2
  = 17; H 20 + 6 + 2 = 28. Stage OUT: A 82 data rows (To 4, LIMB 1, Do 12,
  Vo 8·8, histogram 1) + 98 + 2 = 182; H 82 + 26 + 2 = 110. This equals the
  counter and the R2 counted-layout test.
* **Claims on multi-row planes.** These use the block's own mechanism: the
  data part spans the plane's rows, weighted by the point's row bits; the
  reserved pair is masked over the 12-bit column tail; `audit_claims` and
  the exact group counts run unchanged and pass on the honest R2 run.
* **Pad terms across rows:**
  * VZC on `Vo`: `e` and every `lambda`, over the whole 2^15 cube, for
    entries ≥ V;
  * the table zero-check on `Voc`: `m`, `h_tab`;
  * DZC on `Do`: all 12 planes, for entries ≥ d, which covers the lift
    2,048..4,095;
  * LZC and TAB as at R1.

  My R2-scale forgeries hit each class:
  * the last partial row (RV2-B1, B4, B9);
  * the very last cube entry (B5, B8);
  * the Do lift (B7);
  * rows away from the honest token (B2, B3, B12).
* **IO slots.** The token endpoints are single 256-word rows, read on
  one-row domains. The boundaries `B_in` and `B_out` are 16-row commitments
  claimed by stage IN at `(rho_t, r_emb)` and by stage OUT at the public
  bits of `T − 1`. Stage OUT's claim fixes the 4 row bits, so it selects row
  15, and one column bit (G-2, as at R1). Controls: RV2-B6 (row T−2), B10
  (block 0 proved on another input, the 16-row `B_in`), B11 (a re-lookup
  under the honest seal).

### 3.3 The whole-run figure and the policy (brief item 3)

* **Derivation.** `whole_run_of(sh, L, tp)` is called only inside
  `TokenRunStatement::new`, with inputs from the shape (fixed by the profile
  string through CS-7), `L`, and a registered tier. It sums:
  * the column test of every opening: stages' A, H, M; two token endpoints;
    L × (block A, H, M); L + 1 boundaries; that is `4L + 9` = 97 at R2;
  * the derived LogUp terms (checked convention `(N + 2303)/|F|` per block).

  The figure is floored to whole bits and written into the parameter line,
  so it is part of the transcript.
* **The R2 figure re-derives** [COUNTED]:
  * 71 openings at 2^-103.69 plus 26 at 2^-106.25 give column 2^-97.46;
  * 22 blocks of about 6.3 M lookups give LogUp 2^-100.96;
  * total 2^-97.335, floor 97.

  It matches DESIGN §4.4's TinyLlama commitment term of 2^-97.46.
* **Can a statement claim more than its levers give?** No:
  * from bytes, a receipt proved under an inflated statement (120) fails
    the verifier's own derived statement by binding (RV2-A4, RV2-C1c);
  * a policy above the derived figure is refused before any segment is read
    (RV2-A4, C1a, C1b);
  * the only acceptance is an in-process mutated object (R2-3).
* **Gaps.** The floor's margin is not enforced (R2-1), and stage IN's LogUp
  term borrows the block derivation (R2-2). Both are inside the slack today.

### 3.4 D20 at the calibrated Cn (brief item 4)

* `stage_out::out_values(check = true)` refuses with the constant texts
  "final norm denominator (refused, D20)" or "final norm quotient/remainder
  (refused, D20)": no position, no value. The R2 unit test asserts the text
  exactly.
* It runs inside `honest_pipeline` / the R2 pipeline, before the endpoints
  are sealed and before any header or commitment.
* On a crafted spike row it fires at `Cn = 5,664` and not at the
  refusal-free 1,024. On real data, ho00 (layer 21, max |y| 49) and my
  two-layer prefix (layer 1, max |y| 55) are admitted.
* A cheating prover cannot clamp: the `sym` lookups bind `y` to
  `[-127, 127]` (round-1 control 17d).
* The refusal is pipeline-level (R2-5). The class itself is input-dependent,
  as D20 and C-7 admit.

### 3.5 The R2 honest run re-verified, and my tamper tests at R2 (brief item 5)

* **Fresh-process verify, two ways.** My own `rv2_c1` rebuilds every public
  input from the export and the tables, reads the roots and context from
  `statement.txt`, and checks the parameter line and the trained-statement
  identity. It accepted the lane's receipt in 8.9 s. The lane's
  `token_io_r2_verify_from_dir`, run with my binary on the lane's bytes,
  accepted in 9.1 s; a one-bit change was refused.
* **Tamper tests.** RV2-B1..B12, on two real layers at R2's tables, profile
  and Cn (the two-layer honest run: token 25608, prove 12.0 s, 27,422,816 B,
  floor 100 bits). RV2-C2a and C2b at the full 22 layers (honest token
  29914). All are refused as predicted.

### 3.6 What R3 (Llama-3-8B) needs that R2 does not exercise

* **Streaming blocks.** `prove_token_run` and `verify_token_run` take
  `&[BlockPublic]`; at 8B that is 7.4 GB of padded int8, plus the embedding
  (1.05 GB) and the head (0.54 GB). The native 8B run streams blocks from
  digests (`new_bound_from_digests`, `BlockSource`). The token run needs the
  same.
* **The vocabulary at the door's edge.** `V = 128,256` gives
  `V_pad = 2^17 = MAX_DOM_LOG`, so Vo and Voc planes are 32 rows each. The
  window is 56 bits, 7 limbs (2^56 + 2^56 < p, as the door checks). BOS is
  128000.
* **Census.** The new profile string must pass the W-2 equal-length census
  (R2's first string failed it).
* **Whole-run figure.** It is recounted at 8B T32 (`4L + 9` = 137
  openings). Fix R2-1 before it is quoted.
* **Controls.** Own R3-scale controls on the 32-row planes. The G-gates are
  still owed.

Not a problem in R2 itself.

---

## 4. Tests run

All runs used the round-2 scratch copy and went through the resource guard,
detached, waiting on `.done` markers (`ops/zkp-mvp/token-io-review-r2-scratch/launch_r2.sh`;
logs in `results/zk60_token_io_review_r1_20261017/logs2/`) [MEASURED,
shared box, n=1].

| step | guard | result | wall |
|---|---|---|---|
| `cargo test --release --offline --locked -j2 --lib --no-run` | build 3 / 5 GiB; waited ~53 min for the heavy lock | exit 0, no warning from my file | 3m07s |
| `... --lib token_io -- --test-threads 2 --nocapture` | cpu 4 / 7 GiB | **24 passed, 0 failed, 7 ignored**: the lane's 16 R1+TR and 4 R2 unit tests, plus my 4 A probes; 71 lines `AS PREDICTED`, 0 `NOT AS PREDICTED` | 138 s, peak RSS 0.47 GiB |
| `... --lib rv2_ -- --ignored --test-threads 1 --nocapture` | cpu 5 / 8 GiB | **3 passed, 0 failed**: `rv2_b` (12 forgeries on two real layers), `rv2_c1` (the saved ho00 receipt and 10 probes), `rv2_c2` (two full-scale forgeries) | 400 s, peak RSS 2.84 GiB |
| `token_io_r2_verify_from_dir` (the lane's test, my binary, `TOKEN_IO_R2_OUT` = the lane's `runs/r2`, read-only) | cpu 4 / 7 GiB | accepted in 9.1 s; one-bit change refused | 23 s |

`REVIEW-R2 CONTROL` lines (all `AS PREDICTED`):

| id | forgery or probe | refused at |
|---|---|---|
| RV2-A1 | round-1 tiers (endpoint rate 1/4 and 1/2, stage 2^9, Q 128, Q 1), stronger unregistered levers, F_p^3, a −128 head word | the tier door and the statement / the door |
| RV2-A2 | a public-row receipt forged under a statement relabelled P or F | the verifier ("variant is not built") |
| RV2-A3 | round-1 owner planes; the wrong owner; another run's statement | the owner checks |
| RV2-A4 | a receipt proved under a statement inflated to 120 bits; a 120-bit policy | binding; policy |
| RV2-B1 | `e` on the padded entry V + 5 (last row), tok = V + 5 | stage OUT slot 06 (VZC) |
| RV2-B2 | A6-only at id 434 (row 0; honest 25608, row 6) | stage OUT slot 07 (RSEL) |
| RV2-B3 | A3-only: tok' = 29704 (one row away), `M` shifted by `2^-v (tok' − j)` | stage OUT slot 07 |
| RV2-B4 | one count of `m[0]` moved to the padded entry V + 1 (invisible to LogUp) | stage IN slot 02 |
| RV2-B5 | a nonzero limb on entry 32,767 | stage OUT slot 06 |
| RV2-B6 | the logits from row T−2 of the 16-row `B_out` | stage OUT slot 00 |
| RV2-B7 | `x` on the Do lift (entry d_pad + 9) | stage OUT slot 05 |
| RV2-B8 | a second hot `e` on entry 32,767 beside the honest one | stage OUT slot 06 |
| RV2-B9 | a padded token id V + 11 at position 5, histogram on that entry | stage IN slot 02 |
| RV2-B10 | `B_in = E[tok]`, block 0 proved on another input | block 0 slot 21 |
| RV2-B11 | a re-lookup to id 31,000 under the honest seal | stage IN slot 00 |
| RV2-B12 | one histogram count moved from id 462 to 4558 | stage IN H (LogUp sum) |
| RV2-C1a/b | 98-bit policy, with and without segments | the policy, before segments |
| RV2-C1c..f, j | inflated figure; Cn 1,024; ho36 context; roots swapped; a changed head multiplier | binding |
| RV2-C1g | a 21-layer prefix statement | the segment count |
| RV2-C1h | block segments 5 and 6 swapped | the segment index |
| RV2-C1i | one bit flipped in stage IN | stage IN A (column check) |
| RV2-C2a | FULL R2: A6-only at id 13 (honest 29914) | stage OUT slot 07 (86.7 s to prove and refuse) |
| RV2-C2b | FULL R2: `m[0]` count moved to the padded entry V + 1 | stage IN slot 02 |

As in round 1, the forger is the honest prover algorithm with its refusals
off (plus, for RV2-A2, a prover without the variant refusal). Deviations
from the round algorithm are covered by sum-check soundness and not tested
here.

---

## 5. Files

* Frozen copy `ops/zkp-mvp/token-io-review-r2/`, with manifest
  `ops/zkp-mvp/token-io-review-r2.sha256`.
* My tests:
  `ops/zkp-mvp/token-io-review-r2-scratch/tree/hashline/src/private_block/token_io/run/review_tests.rs`.
* Launcher `ops/zkp-mvp/token-io-review-r2-scratch/launch_r2.sh`.
* Logs `results/zk60_token_io_review_r1_20261017/logs2/`.
* Ledger `results/zk60_token_io_review_r1_20261017/PROGRESS.md` (ROUND 2
  section).
