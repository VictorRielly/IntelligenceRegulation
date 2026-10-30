# Gate round 18: the classifier gate on R-C2 / R-C3 (token frozen-r14)

Privacy gate lane, 2026-10-29 02:14-04:15 UTC. **This is NOT a privacy acceptance.**
Labels: [MEASURED] a run happened (shared box, n = 1); [COUNTED] exact arithmetic; [READ] read from
the code.

Machine-readable records:

* `round18/R18_SUMMARY.json` (sha256 `d3ad213c…`): every record, the cross-verdict comparisons, the
  short-vs-full comparisons, the /3 statement check, failing-first, D41.
* `round18/C13_PER_N.json` (`ab83a255…`): the C-13 figures at each n.

## 1. Result in one paragraph

* **Captures.** 21 captures of the development rung (T 32, d 384) were each gated by frozen tools v21.
  * **All 21 PASS**, with 0 false parts and no control that failed to fire [MEASURED].
  * They cover L1 / L2 at verdict 0, 1 and the tie; one D41 item of two chunks; and short items at
    n = 1, 11, 20 and 22, each at all three verdict cases at L2.
  * Two captures came through the token lane's named r14 CLI binary: one full-length item and one short
    item.
* **Per commitment**, the disclosed dimension is the expected one everywhere: 0 on every A, endpoint and
  boundary commitment, and 2 on every H (its zero-sum pair).
* **No public table is taken from a capture any more.** All 19 public tables of the classifier stages are
  rebuilt from public data, the public n and the public verdict. This includes tau and the margin vector,
  which are now derived from the pinned tied tensor (B-3).
* **The verdict moves nothing but its public bit.** At L1, at L2, and at each of n = 1, 11, 20 and 22, the
  randomness-free figures of the v0 / v1 / tie captures are equal.
* **A short item moves nothing but its public length (D45(1)).** Its figures equal those of the
  full-length item. Its run facts differ only in n, the pad layout, the chunk word and the run-random
  roots. At n = 1 the test policy's c also differs: the fixture places c from each item's own margin.
* **Token round 14 is ACCEPTED on soundness** (REVIEW_R14), so the frozen-r14 basis stands. The open
  dependency recorded at the start of the round is closed.

## 2. What was gated [MEASURED, frozen v21, 0.28-0.33 GiB, 290-412 s each]

| capture (`~/zk60-artifacts/token-io/captures/`) | L | n | verdict | pad pos. | verdict row | full preimage (entries / differing) | status |
|---|---|---|---|---|---|---|---|
| classify-rc3-rung-L1-v0 / -v1 / -vtie | 1 | 23 | 0 / 1 / 0 (tie) | 0 | 31 | 958,229 / 955,737 / 961,805, all 0 | PASS ×3 |
| classify-rc3-rung-L2-v0 / -v1 / -vtie | 2 | 23 | 0 / 1 / 0 | 0 | 31 | 1,725,349 / 1,721,000 / 1,714,398, all 0 | PASS ×3 |
| classify-rc3-rung-L2-v1-chunk0o27, -chunk1o27 (one 27-id item, [0, 23) and [4, 27)) | 2 | 23 | 1, 1 | 0 | 31 | 1,725,147 / 1,726,646, 0 | PASS ×2 |
| classify-rc3-rung-L2-{v0,v1,vtie}-short1 | 2 | 1 | 0 / 1 / 0 | 22 | 9 | 1,727,967 / 1,723,263 / 1,724,242, 0 | PASS ×3 |
| classify-rc3-rung-L2-{v0,v1,vtie}-short11 | 2 | 11 | 0 / 1 / 0 | 12 | 19 | 1,721,403 / 1,716,239 / 1,736,700, 0 | PASS ×3 |
| classify-rc3-rung-L2-v1-short20 | 2 | 20 | 1 | 3 | 28 | 1,729,620 / 0 | PASS |
| classify-rc3-rung-L2-{v0,v1,vtie}-short22 | 2 | 22 | 0 / 1 / 0 | 1 | 30 | 1,721,771 / 1,720,791 / 1,724,367, 0 | PASS ×3 |
| classify-rc3-rung-L1-vtie-short20 | 1 | 20 | 0 (tie) | 3 | 28 | 946,361 / 0 | PASS |
| classify-rc3-cli-p18-r14 (token lane; CLI path, binary 48dac988…) | 1 | 23 | 0 | 0 | 31 | 946,702 / 0 | PASS |
| classify-rc3-cli-short11-r14 (CLI path for a short item; gate patch H18-1) | 1 | 11 | 0 | 12 | 19 | 959,406 / 0 | PASS |

On each capture the gate checks:

* the replay, with the classifier header absorbing the verdict and the chunk;
* the 12 classifier slots, 12 / 12;
* the block stages, 23 / 23 per block, at the rung fixture's calibration (`trained_calib_tests.rs:55-58`,
  unchanged at r14), with NC-1 firing;
* NL-1, 12 / 12;
* per commitment, as above;
* mask / CFS, 0 entries differing;
* the joint figure, 0, with joint = the sum of the parts;
* the joint preimage, with the couplings respected;
* B-3, the one public bit and D41.

**Controls.** The CC-1..CC-6, J-1..J-3, CC-8 / CC-9 and C13-2..C13-4 controls fire on every capture.
C13-1 fires wherever the item has a pad position, and is marked not applicable on the 9 full-length
captures.

**How the captures were made.**

* The 19 rung captures came from the frozen r14 hook `capture_a_classify_rung_run`, built in the gate's
  byte-equal copy of frozen-r14 (`ops/zkp-mvp/gate-tinyllama/capture-tree-r14/`, 258 / 258 files).
  * Each verdict case uses its own test policy with its own export profile (N-r13-3).
  * Captures took 2.3-4.0 s at 0.20-0.22 GiB each [MEASURED].
* The CLI short item needed a gate **test-only** patch, H18-1: one new `#[ignore]` test in
  `token_io/classify_capture_tests.rs`, which is **not a source pin**.
  * Patch: `round18/cap/H18-1.classify_capture_tests.patch`; the file goes from `9540bb20…` to
    `7229da16…`.
  * The named binary's own `prove` and `verify` ran as their own processes. The recorder and every pinned
    file are frozen-r14's bytes.
  * Every other capture was made before the patch.

## 3. Tools v21 (frozen 02:53 UTC)

* **Freeze.**
  * `frozen_v21/`, manifest `gate-tinyllama.tools.frozen.v21.sha256`: 77 files,
    `258149772c1b9c9453f27d05dada541a158f0d2c6a44544b2b91df71b521e8cf`. Check: 77 / 0 / 0.
  * Patches: v20 -> v21 scripts `14eeda6b…`, tests `54fb4d91…`; vs original `3ad773bc…`.
* **Suite:** 93 OK in the frozen snapshot [MEASURED, 45 s]. That is 89 + 4 new tests (`ClassifierV21`).
  The v19 / v20 tests were updated for R-C3; the R-C1 capture is now a negative fixture.
* What changed from v20:
  * **Short items (R-C3).** The template pins the pad positions: kappa holds the suffix id on
    P0 + n .. P0 + n + S, then the public pad id up to T.
    * The door admits P0 + n + S <= T.
    * OUTC-00, the joint figure and the decoded B_out claim all use the verdict row P0 + n + S - 1.
    * D41 uses the plan size T - P0 - S and requires n = b - a. A short content is one chunk [0, n).
  * **The profile text.** These fields are re-derived and checked: item-length, pad-id (it must equal the
    registered policy's, 2), pad-positions, verdict-row, chunk-size, short-content, margin-scale-bits, the
    tied source and the D45 rulings sentence. The schedule line naming the verdict row is checked too.
  * **B-3 derived, not taken.**
    * The new `zk60_native_rg_classtied.py` regenerates the pinned dev tensor (`bba6d094…`).
    * It derives the int16 embedding and the margin row with native R12b's quantizer.
    * It reproduces REVIEW_R13's reference digests: embedding `c0e816c9…`, margin `24e6ff4c…`. It also
      reproduces the statements' BLAKE3 digests `a8d55fc0…` / `40f3fe49…`.
    * tau (the embedding folded at the replayed r_emb) and w_Delta are then REBUILT and compared digest
      for digest. "Taken tables" went from 2 in v20 to 0.
  * **Pins.**
    * The v21 rule accepts 60 / 60 pins on every r14 capture:
      * 36 by the token gate;
      * 7 by the block gate's native R9 readings;
      * 12 through chains of written readings;
      * 5 as the v21 port's own digests.
    * An R-C1 capture is refused by name (N-r13-8).
    * The native R9 -> R12 -> R12b readings are in the new `zk60_native_rg_tinyllama_r12b_pins.py`. They
      were written by a reading sub-lane and checked here.
  * **Finding F18-1 (capture format).** The r14 classifier and token-run writers emit `Shape::slots()`
    whole: 24 triples, the 24th being (0, 0, 0), with n_slots 23 (`run_capture.rs:2478 / 2717`). The block
    writer clips at :2229. v21 accepts only all-zero extra triples, records the note and strips them in
    memory. **For the token lane:** clip at n_slots.

## 4. The [READ] list

Each row reads one step of a file's digest chain.

* **Token side:** frozen-r12 -> frozen-r13 -> frozen-r14. Diffs are in `round18/readings/tok-*.diff`.
* **Native side:** R9 -> R12 -> R12b. Diffs are in `round18/readings/nat-*.diff`, readings in
  `round18/readings/NATIVE_R12B_READINGS.json`.
* "moves" means a receipt byte moves at a profile the gate captured before. For the five ported
  classifier files it is true by construction: they are accepted only at the v21 port's digests, never
  through a chain.

| file | digest | read against | diff | moves |
|---|---|---|---|---|
| token_io/classify.rs | 6c828db6 | 0937952f | +132 / -35 | ported |
| token_io/classify.rs | 0937952f | fe1d9bd7 | +128 / -2 | ported |
| token_io/classify_run.rs | 5d1d077f | be2ccd1c | +24 / -16 | ported |
| token_io/stage_in_c.rs | 6a92da0e | 05c1aae2 | +4 / -2 | ported |
| token_io/stage_out_c.rs | 93a79a2b | ee1cd237 | +5 / -3 | ported |
| token_io/classify_tied.rs | 401d38d4 | b0eb5047 (new at r13) | +200 / -12 | ported (derive_dev unchanged) |
| token_io.rs | eda64c31 -> 4a1e967a -> 057137a2 | | +3, +7 | no |
| token_io/load.rs | a9b72811 | 8c041721 | +2 (rope_scaling, None at these exports) | no |
| run_capture.rs | ef9c54db -> 23293061 -> aaff4e6e | | +11; +573 / -2 | no |
| argument.rs | c4f9f9f4 | 112352bc (R9) | +11 / -7 (q-axis width only; bilinear arms untouched) | no |
| shape.rs | 9a870818 | e214db86 | +147 / -8 | no |
| witness.rs | a586b777 | d1a85918 | +18 / -11 | no |
| pad.rs | 91141ea0 | 20afa04f | +3 / -2 | no |
| trained_statement.rs | 7908d827 -> 0fbf90ed -> ac61bf90 | | +4 / -2, +129 | no |
| trained_block.rs | f892dbc7 -> e2551aa1 -> c6d87b6e -> 357e2797 | | +10 / -10, +29 / -21, +248 / -23 | no |
| private_block.rs | 29540958 -> b4f73a05 -> 3810bdab -> 5e50acd5 | | +10, +3, +16 / -3 | no |
| run.rs | 51e8aed2 -> 5c9f0ffc -> cf80735d | | +62, +31 / -2 | no |
| rope.rs | a2f34537 | new at R12 | 239 lines | no |
| tied_tables.rs | 049ddc18 -> 901fa1e4 | new at R12b | +2 | no |
| tied_tables/derive.rs | 5cebeef0 -> e2b76895 | new at R12b | +3 / -3 | no |

Every R12 change is one of three kinds:

* gated by name on a new profile (Shieldstral, rung-HD);
* the query axis's own width q_pad = h_pad × head_dim, which is the identity where q_pad == d_pad. That
  holds at every pre-R12 shape; at rung-TC, 16 × 32 = 512 [COUNTED];
* an optional statement field, used only for a tied model or a scaled RoPE.

## 5. C-13: short items (DESIGN v2.4 §15; REVIEW_R14 §10)

**Controls on the real capture** (in memory, each predicted; all fire on every short capture).

* **C13-1, a doctored pad position.** Either the port's pad id + 1, or the captured kappa at the first pad
  position + 1. Exactly INC-01 refuses, both ways: the template clause pins the pad positions.
* **C13-2, a pad inside the content range.**
  * The port pins the last content position P0 + n - 1 to the pad id: exactly INC-01 refuses.
  * The profile text claims one pad position more: the integrity check refuses (pad_positions).
* **C13-3, a shifted verdict row.**
  * OUTC-00 read at verdict row -1 (and +1 where it exists): exactly OUTC-00 refuses.
  * With the expected row moved, the integrity check refuses on B_out's decoded OUTC-00 claim.
* **C13-4, a declared length that is not the actual one.**
  * classify.n + 1 in the facts: the integrity check refuses (the profile text's n, D41) and exactly INC-01
    refuses.
  * The chunk declaring one id more: the run binding and D41 both refuse.

**REVIEW_R14 §10, item by item** (C13_PER_N.json) [MEASURED / COUNTED]:

1. **The input endpoint.**
   * At each n, the CAPTURED template indicator pi has its ones exactly on the template and pad positions,
     and its zeros exactly on the content positions. The captured kappa holds the pad id (2) at every pad
     position.
   * Known words per n: 31 / 21 / 12 / 10 / 9 at n = 1 / 11 / 20 / 22 / 23 (P0 + S = 9, plus the pads).
     Hidden words: n.
   * **The joint figure per n is 0.** It covers 33,312 identified word pairs at L1 and at L2. The tok
     component is one signature over the 32 word positions, with 0 disclosed per word. Summed over the
     hidden words it gives 0, and over the known words 0, at every n.
   * The disclosed-rank and CFS figures are 0 at every n with every data word treated as unknown. This
     implies 0 on the hidden words with the known words fixed as constants. The masks are independent of
     the data, so a view whose distribution does not depend on any data word cannot depend on a subset of
     them.
2. **The blocks: no T < T_pad.**
   * The block shape is identical at every n: T = t_pad = 32, d 384 / d_pad 512, 23 slots.
   * The rung has no padded row >= T, so the pad rows are ordinary rows of every block plane. In
     particular, the masked score entries from content-row queries to pad-row keys are hidden witness.
   * The full preimage puts every block data row in the hidden set: 0 differing at every n, and block
     stages 23 / 23.
3. **The verdict row moves with n.**
   * B_out's OUTC-00 claim decodes to rows 9 / 19 / 28 / 30 / 31 at n = 1 / 11 / 20 / 22 / 23, equal to
     P0 + n + S - 1.
   * It is the ONLY B_out claim with fixed (public) row bits, 5 of them.
   * At a short item, row T - 1 is never opened at a fixed point.
   * B_out's disclosed dimension is 0 at every n.
4. **Captures** at n = 1, 22 and 11 (plus 20), each at v0 / v1 / tie with derived tables, and the CLI path
   for one short item: see §2.
5. **The statement allow-list.**
   * The published `zk60-classify-run/3` statement of the CLI short item has 38 keys, all classified
     [READ classify_cli.rs:323-385].
   * item_length = P0 + n + S, pad_positions = T - item_length, verdict_row = item_length - 1, and pad_id
     is the registered policy's [checked on the statement].
   * **The receipt length does not depend on n.** The segment bytes are 1,224,328 / 7,421,464 (per block)
     / 2,489,016 at every n.
6. **Refusals.**
   * **The LogUp term.** The input-dependent LogUp refusal term (D34 / D40) stays an upper bound at every
     n: stage IN-C inverts at most T distinct tau rows, and the pad positions add one public id. The count
     is 2(768 L + T + 256) / p², which is 2^-116.96 / 2^-116.17 at the rung (L 1 / 2, T 32) and
     2^-112.7 at Shieldstral L 26, T ≤ 512 [COUNTED].
   * **Range refusals.** The pad rows are hidden rows of every block, so they can trip range refusals
     (CS-3, N-r14-6), exactly as content rows can. Whether a short item proves therefore depends on its
     hidden content.
     * Under D29's reading such refusals come before the header: no proof and no view.
     * Under D45(4), the app then shows "could not be verified".
     * **The statement must therefore count the refusal fact, now including the pad rows, as a function
       of the hidden content.** No new transcript term arises from this.
7. **Small n.**
   * **At n = 1 the public verdict is a function of ONE hidden id.**
     * At the rung that id is one of the 295 non-control ids. At Shieldstral it is one of 130,072.
     * The public bit tells which side of the classifier's boundary that single id falls on.
   * D45(1) / (2) accept this; it is a property of the rulings, not a proof defect. The statement must say
     it in plain words, as the entropy left in a short post.

## 6. Cross-verdict, short vs full, D41, failing-first

* **Cross-verdict.** The randomness-free figures are equal for v0 / v1 / tie:
  * at L1 and at L2 (full length);
  * at L2 for each of n = 1, 11, 20 and 22.

  The figures compared are the replay counts, slot checks, rebuilt / taken tables, block slots, the
  per-commitment table, the joint figure, NL-1 and the CFS entries.
* **Short vs full.** Six comparisons were made: n = 20 at L2 and L1, n = 1 / 11 / 22 at L2, and the two
  CLI captures. Each has equal randomness-free figures and equal per-commitment disclosure.
  * The run facts differ only in: n; the chunk's b and total; the profile text's n / item-length /
    pad-positions / verdict-row; the profile digest; the run-random input root.
  * At n = 1 the test policy's c and id also differ. These are public policy constants that the fixture
    places from the item's margin.
* **D41.** The two chunks of the 27-id item, [0, 23) and [4, 27), share one test policy and one trained
  identity.
  * Their label is 1, the OR of the two verdict bits, with **no fail-closed reason**, and coverage holds.
  * Chunk 1 alone gives 1 (chunk 0 has no proof).
  * A short item's label is its verdict.
* **Failing-first.**
  * Frozen v20's whole gate exits 1 on an R-C3 capture, at its loader (F18-1).
  * v20's pin check refuses 23 pins on every r14 capture, and its reader evaluates 0 slots.
  * v21 refuses the R-C1 capture by name.

## 7. Notes and open items

* **Observation O18-1 (for the token lane: the generic-honest-witness rule).** The dev rung's margin at the
  verdict row hardly depends on the content.
  * c, placed from each item's own margin, is -190166 ± 1 at n = 11, 20, 22, 23 and for both chunks. It
    is -202071 ± 1 at n = 1.
  * So these captures barely exercise content-dependence of the margin. The gate's figures do not rely on
    it.
* **REVIEW_R14 notes for the app** (not gate items):
  * `label` has no expected-total check: the truncation class;
  * causality is enforced in the relation (SC_SZC's c2 with the public causal mask), not only in the
    witness. That is a design-text gap.
* **The working copy** of the gate tools is v21 as of this round's close (§8).
* No job of this lane is pending.

## 8. What a classifier privacy statement draft still needs

1. **The statement text** (the D36 analogue for a classifier run). It must state:
   * what is hidden: the content ids, embedding rows, activations, inter-block planes, final-norm values,
     the margin and its limbs;
   * what is public:
     * the verdict bit;
     * n and the pad layout (D45(1));
     * the chunk index, count, range and total (D41: per-chunk bits are public);
     * the policy, threshold and model identity (D45(2));
     * the input endpoint root (D45(3) binding);
   * the per-run distance figures at the classifier profiles;
   * the D34 / D40 refusal term;
   * the refusal fact, including the pad rows;
   * the small-n sentence (§5.7);
   * the fail-closed rule.
2. **The per-run distance numbers for the classifier stages.** The analogue of D36's 2^-74.4 / 2^-73.6 at
   L = 1 / 2 must be computed. It needs the blinding-law residuals (the G-R4 class) over the IN-C and OUT-C
   draws: the margin limbs, the LZC host term and the template clause's fresh coefficient.
3. **Owner checks.**
   * The input owner's check on short items: the decommitment opens to template + content + pad. The
     check exists in the CLI (`input-owner`), but no gate-side owner record has been made.
   * Delivery of the opening that D45(3) keeps with the app.
4. **Shieldstral.**
   * Its classifier run profile is not registered yet.
   * Still owed: its pad-row (id 11) refusal behaviour; captures at L 26, T 128 / 256 through the CLI;
     and the two checkpoint streams per run (N-r13-5).
   * The D40 figure there is 2^-112.7.
5. **An independent privacy review round** on the draft (as REVIEW4-6 did for D33 / D36).
6. **The security owner's sign-off and Victor's acceptance.** No lane can claim a privacy acceptance.
