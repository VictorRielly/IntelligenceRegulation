# ZK60 — independent adversarial review of stage 28 (the 125M prover, "faster without moving a byte")

**Reviewer:** an independent agent that did not write stage 28. **Lane under
review:** `zk60-private-block-125m`, stage 28, commits `d2c2733`, `a9f2211`,
`1952a1e`, `309d238` over the base `79f0726`. **Review worktree:**
`/home/victor/wt-zk60-block125m-review`, branch
`zk60-private-block-125m-review`. **Opened 2026-09-21 10:00 PDT.**

Nothing in the stage's ledger section is taken on trust. Every figure below is
re-derived from the code, from the committed logs, or from a test this review
wrote (`hashline/src/private_block/s28_review_tests.rs`, nine tests, test-only,
no production line touched). Evidence:
`results/zk60_block125m_s28_review/`.

**Bottom line.** No soundness hole and no arithmetic divergence was found. The
stage's three headline claims — bytes unchanged, refusals unchanged, verifier
semantics unchanged — hold as far as this review could push them, and the
verifier claim is structural rather than merely tested. Eight findings, none
of them a hole: the sharpest are that **one changed computation (`total`, the
claimed sum) has no equality gate at all and its parallel branch is crossed by
no test that is not `#[ignore]`d**, and that **the second half of finding
S28-F1 is false as written** — a counterexample is exhibited and passes as a
test.

---

## 1. The production diff, line by line

**The forbidden-files proof re-run by this reviewer** (`git diff --stat
79f0726 309d238 -- zkp-core hashline/src/zk.rs hashline/src/pcs.rs
hashline/src/layer.rs hashline/src/wcache.rs hashline/src/field.rs
hashline/src/native_capture.rs hashline/src/private_seam.rs hashline/src/gpu
private-block-kernel private-model-kernel private-block-kernel-shaped
zkvm-block scripts tests`) prints **nothing**, and the diff's whole
non-documentation, non-evidence file list is five files:
`private_block.rs`, `private_block/{argument,protocol,timing}.rs` and the new
`private_block/s28_tests.rs`. **Confirmed.**

`git diff 79f0726 309d238` touches four production files:
`private_block.rs` (+6, a `#[cfg(test)] mod` registration),
`timing.rs` (+20, one new test-instrument function),
`argument.rs` (5 hunks) and `protocol.rs` (4 hunks). Every hunk was read.

### 1.1 `argument.rs`

| # | what it computed at `79f0726` | what it computes now | where the two agree | called by |
|---|---|---|---|---|
| A1 | `priv_table`: per plane index `idx`, walk all `p.log` coordinates, OR each bit into `x` at `n_vars-1-k` (complemented for `Flip`), shift each `Fixed` bit into `z`; accumulate `v` over the slices; `out[x] += eqf[z] * v` | the same `(x, z)`, read from two precomputed half-maps (`idx`'s high `ceil(log/2)` bits and low `floor(log/2)` bits), recombined as `x_hi \| x_lo` and `(z_hi << fixed_lo) \| z_lo`; `v` short-circuited when there is one slice with coefficient 1; the write is a plain store when `eqf == [1]` **and** the moving coordinates use pairwise distinct challenge indices; the broadcast pass is skipped when `used` is the full mask | **everywhere**, and the re-derivation is exact, not approximate: `x` is an OR of bits, which is associative, so splitting the coordinate walk in two cannot move it even when an index repeats; `z`'s high part is shifted by the NUMBER OF FIXED COORDINATES IN THE LOW HALF, which is what keeps the coordinate order; `Fp2::ZERO.add(Fp2::ONE.mul_base(a)) == Fp2::from_base(a)` by the definitions in `zkp-core/src/field.rs`; the plain store is sound exactly because the counted condition `used.count_ones() == moving` makes `idx -> x` injective — and it also forces `p.log <= n_vars`, so the store cannot overwrite (`moving == coords.len() == log` and `used` has at most `n_vars` bits). The one case the randomised gate does not reach, `p.log > n_vars` (only possible with fixed coordinates, which make `eqf.len() > 1`), necessarily takes the add fallback in both forms; verified by reading, not by test. Verified on 1,800 randomised comparisons (§3) | **prover only** (`table_of`, `Side::Prove` arm) |
| A2 | `Tab::Eq` arm: `e[(x >> shift) & (e.len()-1)]` per entry, `shift = n_vars - start - point.len()` | `eq_cube`: fill one block of `2^shift` copies per `eq` entry, then double with `extend_from_within` until the cube is full; `shift = n_vars - start - e.len().trailing_zeros()` | `e.len() == 2^point.len()`, so the two shifts are the same number; the cube IS the small table repeated. Verified on all 560 `(width, \|point\|, start)` triples to 2^13 (§3) | **prover only** |
| A3 | `table_of(&Tab)`, `Tab::Pub(v) => v.clone()` | `table_of_taking(&mut Tab)` on the proving path: `Tab::Pub(v) => std::mem::take(v)` | the moved-out vector IS the clone's content; the `Tab::Pub` length check runs BEFORE the move (`run_slot`, "public table length"), and every later read of `def.tabs` on the prove path matches `Tab::Priv` only (three sites: the `ext` loop, the terminal filter, the claim loop). The capture writer that does read `Tab::Pub` payloads runs under `if let Side::Verify`. Verified by reading all four sites | **prover only** |
| A4 | `total`: one serial pass over the cube, gathering a row per point and folding `poly(row)` | the same pass, chunked at 1,024 points and reduced with rayon above `len > 2^14` | field addition is exact, associative, commutative **and canonical** (`Fp::add` normalises; `Fp2` derives `PartialEq` on two canonical `u64`s), so any grouping gives the same WORD. `Poly` was already `Box<dyn Fn + Send + Sync>` at `79f0726`; the closures are pure field arithmetic. **No equality gate — finding S28-R1** | **prover only** |
| A5 | `run_slot(… def: SlotDef …)` | `run_slot(… mut def: SlotDef …)`, four `timing::slot_step` wrappers around the existing steps | `slot_step` calls `f()` exactly once in both branches and does nothing else when the clock is off; the `tr.absorb_fp2(b"pb-scalar", …)` between the claimed sum and the sumcheck is OUTSIDE every closure, so the transcript sequence is untouched | shared preamble; the changed lines are all in the `Side::Prove` arm |

### 1.2 `protocol.rs`

| # | before | now | agreement | called by |
|---|---|---|---|---|
| P1 | `lookup_values`: `lay.lookups(dom).iter().map(per-index wrapping map)` | the same map, on an INDEXED `par_iter` above `cols * len >= 2^17` | a per-index map of wrapping integer arithmetic; indexed collect preserves order. Verified under 1, 2 and 8 threads on real witnesses at two shapes (§3) | **prover only** (`prove_core`) + one test |
| P2 | the byte histogram: one serial `m_u8[bin(v)] += 1` over every looked word | above `lookup_words >= 2^17`, per-chunk `u64` histograms of 2^16 words reduced bin by bin; `m_u8 = bins` | a histogram is a sum of integers; `m_u8` is freshly zeroed and nothing writes it before this point (checked: the declaration is four lines above), so the ASSIGNMENT loses nothing. No gate (the ledger says so) | **prover only** |
| P3 | per column: `inverses(col.map(alpha - (v + g_u8)))`, i.e. `batch_inverse2_checked` over the whole column, all columns of a domain first, then the pairs added | `u8_denominator_inverses` (256 denominators, the nonzero ones batch-inverted once per proof) + `helper_inverses_u8` / `helper_pair_inverses_u8`, one indexed lookup per word, one helper written at a time | the field inverse is unique and every representation is canonical, so a table lookup, a single `inv()` and a batch inversion all write the same word. Columns are still visited in index order and `helpers(dom) = lookups_per_position(dom).div_ceil(2)`, so `cols[2k]` is always in range and columns `0 .. 2*count` cover every column: the refusing SET is unchanged. See §6 | **prover only** |
| P4 | — | the shared `ZERO_DENOMINATOR` constant | byte-identical to the literal `inverses` still uses (`protocol.rs:410` vs `:417`) | — |

### 1.3 The verifier surface: **empty**

`grep` for every call site of the five changed computations
(`priv_table`, `eq_cube`, `table_of`/`table_of_taking`, `total`,
`lookup_values`, the three helper functions) finds **no caller on the
verifying path**. In `run_slot` the `Side::Verify` arm is unchanged in the
diff: it evaluates `Tab::Eq` with `eq_point`, `Tab::Pub` with `eval_mle_ext`
and takes `Tab::Priv` terminals from the frame, none of which stage 28
touched. The only change a verifier build even compiles differently is
`def: SlotDef` -> `mut def: SlotDef`. **"Verifier semantics unchanged" is
therefore structural, not merely tested.**

---

## 2. Are the ten equality gates real?

**Oracle independence — checked mechanically, not by eye.** This review
extracted `priv_table` from `git show 79f0726:…/argument.rs` and compared it
against `s28_tests::priv_table_walked` with comments stripped: **identical,
line for line** (the only difference is one omitted comment). The same script
confirms this review's own copy. `eq_cube_gathered`, `old_path` and the
`lookup_values` oracle are re-derived from `crate::field` / `crate::mle` and
share no helper with the code under test. **The ten gates are real oracles.**

**Coverage — where they stop.**

| the gate reaches | the gate does not reach |
|---|---|
| byte columns at 1 / 255 / 2^14 / 70,000 words, three challenge pairs | a column whose OUT-OF-TABLE value has a zero denominator (**S28-R3**, closed by this review) |
| 21 hand-written `priv_table` cases (3 widths x 7 descriptor shapes) | `log = 0`, `n_vars = 0`, three-slice planes, `Flip` and `Rho` on the same index, all-zero and constant data (**closed by this review**: 1,800 randomised comparisons) |
| every `(width, start, \|point\|)` triple at 3 widths | widths 0..13 with random points and the shift read from the point (**closed by this review**) |
| one thread-count check, on one function, on one column | the paired helper, `lookup_values`, and the refusal under different thread counts (**closed by this review**) |
| `lookup_values` at the toy and rung-K4, ambient pool | — |
| — | **`total` (the parallel claimed sum): no gate at all (S28-R1)** |
| — | the parallel table build and the moved public table: no gate; covered only by end-to-end proofs |
| — | the parallel byte histogram: no gate (the ledger says so and the argument is sound) |

**The shape-specific cases the brief names.** No unit gate — the stage's or
this review's — builds the REAL slot descriptors (there is no reachable
constructor for a `SlotDef` from a test module), so the bilinear slots 08/09,
the group-bit variables and the padded tails of a non-power-of-two token count
are covered **end to end only**: `lkv = 0` at the toy (1 KV head), `lkv = 1` at
the rung and rung-G (2 KV heads, 24 tokens padded to 32), `lkv = 2` at rung-K4
and 125M (4 KV heads). Every honest proof at all five shapes proves and
verifies from its own bytes in the runs of §9, and the group-bit sweep of
`k4_tests` rejects all seven third/fourth-group tampers at the verifier. That
is real coverage of `priv_table` on the descriptors the schedule actually
builds, but it is end-to-end coverage, not an oracle.

So the ledger's sentence *"for every computation changed, the OLD form and the
NEW form are run on the same inputs IN THE SAME TEST"* is **not true of four
of the ten changes** (the parallel table build, the moved public table, the
parallel `total`, the parallel histogram). Three of the four are covered
end-to-end instead; that is a different and weaker kind of evidence, and the
ledger should say which is which.

---

## 3. The differential tests this review added, and what they found

`hashline/src/private_block/s28_review_tests.rs`, registered under
`#[cfg(test)]`. Nine tests, eight of them in the default filter; **all pass,
first run, no production line changed.**

| test | what it does | result |
|---|---|---|
| `the_private_table_builder_agrees_with_79f0726_on_randomised_descriptors` | 600 random descriptors at widths 2^0…2^10 x 3 data flavours = **1,800 comparisons** against the verbatim `79f0726` walk; 20 duplicated-index descriptors, 131 with fixed coordinates, 395 short planes; data generic, all-zero and constant | **no difference** |
| `the_eq_cube_agrees_with_79f0726_at_every_width_including_the_degenerate_ones` | all **560** `(n_vars ≤ 13, \|point\|, start)` triples, random points, oracle shift read from the POINT | **no difference** |
| `an_out_of_table_value_whose_denominator_is_zero_is_refused_by_both_paths` | 8 out-of-table values (`256, 300, 65536, -1, -257, 2^40, i64::MIN, i64::MAX`) x 3 lengths, single and paired columns, both sides of the 2^14 threshold | **old and new both refuse, same string**; the branch the stage never tested |
| `every_helper_path_gives_the_same_words_and_the_same_refusal_under_one_two_and_eight_threads` | single and paired helpers, accepted vectors and refusals, in pinned 1/2/8-thread pools | **identical** |
| `the_looked_columns_are_the_serial_maps_under_every_thread_count` | `lookup_values` on real honest witnesses at the toy and rung-K4, 1/2/8 threads, against the serial map | **identical** |
| `whether_an_attempt_is_refused_still_depends_on_the_hidden_input_for_off_table_values` | the S28-F1 counterexample, byte family and exponential-pair family | **S28-F1's second half is false** (S28-R2) |
| `the_census_of_which_shape_crosses_which_stage_28_parallel_threshold` | five shapes x five thresholds | see §4 |
| `field_addition_is_associative_commutative_and_canonical_so_a_chunked_sum_is_the_same_word` | 200 random vectors, 4 chunk widths, forward and reverse reduction, compared as `u64` LIMBS | **the chunked sum is the same word** (this is the missing `total` gate's premise) |
| `a_run_directory_written_before_stage_28_verifies_under_the_stage_28_verifier` | `#[ignore]`d, env-driven; see §7 | see §7 |

---

## 4. Thread-count independence

Every parallel site stage 28 adds is an INDEXED rayon iterator
(`par_iter`, `par_iter_mut`, `par_chunks` + `reduce`), so order is preserved by
construction; the one order-free site (`total`'s `reduce`, and the histogram's)
reduces with an operation this review checked to be exact, associative,
commutative and canonical. Checked rather than argued:

* the helper column, the paired helper column and their refusals, under
  pinned 1, 2 and 8-thread pools — identical (§3);
* `lookup_values` on real witnesses under 1, 2 and 8 threads — identical (§3);
* **the whole `--lib private_` filter re-run under `RAYON_NUM_THREADS=1`** —
  see §9. Because every honest proof in that filter is verified from its own
  bytes, a thread-count-dependent field value anywhere in the prover would
  show up as a verification failure even though the receipt itself is not
  reproducible.

**Refusal decisions.** The two parallel refusal paths collect into
`Result<Vec<_>, String>`, where rayon keeps an arbitrary one of the errors.
That is harmless here because there is exactly ONE error string on these
paths (`ZERO_DENOMINATOR`, byte-identical to the literal `inverses` uses), so
WHICH error survives the race cannot be observed. No `find_any`-style
early-exit refusal was added.

**The threshold census** (this review's gate; `lookup_words` and the domain
sizes are functions of the public shape only):

| shape | lookup words | histogram ≥2^17 | `lookup_values` ≥2^17 | helper inverses ≥2^14 | slot tables ≥2^17 (lower bound) | `total` >2^14 |
|---|---:|---|---|---|---|---|
| toy | 61,440 | no | no | no | no | no |
| development rung | 419,840 | **yes** | **yes** | no | **yes** | no |
| rung-G | 419,840 | **yes** | **yes** | no | **yes** | no |
| rung-K4 | 542,720 | **yes** | **yes** | **yes** | **yes** | no |
| 125M | 98,598,912 | **yes** | **yes** | **yes** | **yes** | **yes** |

Two things follow. (a) The **frozen toy's byte pins — the stage's strongest
byte evidence — exercise none of the five parallel branches** (finding
S28-R6). (b) **`total`'s parallel branch is crossed by no test that is not
`#[ignore]`d**; its only execution anywhere is inside the 125M run, which does
prove AND verify from bytes (finding S28-R1).

---

## 5. Randomness: draws and absorbs

* **Static.** Filtering the whole production diff for `rng`, `ZkRng`,
  `from_os`, `seed`, `challenge`, `absorb` and `tr.` leaves exactly ONE
  matching line, and it is a comment ("no challenge index used twice"). No
  line added, moved or deleted draws from a generator or calls the transcript.
* **Structural.** The three calls that DO take `tr` inside `run_slot`
  (`masked_prove`, `extension`, and the `pb-scalar` absorb) keep their order:
  `slot_step` executes its `FnOnce` exactly once, synchronously, in both the
  clock-on and clock-off branches, and the `pb-scalar` absorb sits between two
  `slot_step` calls rather than inside one.
* **The lane's own order gates ran and are in the pass list** of
  `q28-gate2.log`: `s25_tests::no_profile_on_this_path_can_obtain_a_generator_other_than_from_the_operating_system`,
  `s25_tests::the_generator_is_never_cloned_and_each_prover_constructs_exactly_one`,
  `s25_tests::the_per_slot_terminal_absorb_lengths_are_printed_and_recorded_at_every_shape`,
  `s26_tests::no_two_generators_of_one_proof_share_a_derivation_input`,
  `hash_domain::tests::every_absorb_label_on_the_path_is_in_the_table`,
  `s23_tests::check_openings_three_checks_fire_in_the_audit_count_challenges_order`,
  and `tests::honest_receipt_verifies_in_typed_and_wire_form_with_the_declared_transcript_order`.
  The last one is the real detector: the verifier re-derives the transcript in
  its own order, so a prover-side reorder of an absorb or a draw makes every
  honest proof fail.

**Verdict: nothing in stage 28 touches randomness.**

---

## 6. Refusals, and the precise status of finding S28-F1

### 6.1 The helper line: same rule, same string, same point

* **Same rule.** Old: `batch_inverse2_checked` over the column refuses iff a
  zero denominator sits at an entry OF THE COLUMN. New: a value in `0..256`
  refuses iff its table entry is `None`; a value outside takes the old
  arithmetic and refuses iff its own denominator is zero. Those are the same
  predicate on the same multiset. Confirmed on the real functions in both
  directions, including the branch the stage never tested (§3).
* **Same set of columns.** `Shape::helpers(dom) = lookups_per_position(dom).div_ceil(2)`,
  so helpers `0..count` address columns `0..2*count ⊇ 0..cols.len()`: the new
  loop touches every column the old one inverted, no more and no fewer.
  (Had `count` been smaller, a column would have stopped being able to refuse;
  had it been larger, `cols[2k]` would panic. Neither can happen.)
* **Same string.** One literal, in `inverses` and in `ZERO_DENOMINATOR`,
  byte-identical; both surface as `Err(String)` out of `prove_core`. (The
  ledger's "a refusal is still the lowest-indexed column's" is true ACROSS
  helpers — they are still visited in index order — but not strictly within a
  parallel column, where rayon keeps an arbitrary one of the errors. Nothing
  observable turns on it: there is one string. See §4.)
* **One refusal string IS new**, and the ledger does not mention it:
  `helper_pair_inverses_u8` begins
  `if a.len() != b.len() { return Err("private block: paired lookup columns of
  different lengths") }`. It is unreachable — every column of a domain is
  built by `lookup_values` as `(0..len)` with the same
  `len = lay.shape().size(dom)` — so "no new refusal" is true of every
  reachable input, but the sentence should carry the exception.
* **Same point.** Between the old refusal point and the new one there is **no
  transcript absorb and no generator draw**: the whole region sits between the
  `alpha` challenge and the `H` root absorb. Partial `h_data` writes are
  discarded with the attempt. A caller cannot tell the two lines apart by
  error type, by string, or by any side effect other than elapsed time and
  peak memory.

### 6.2 S28-F1: **partly true — first half yes, second half no**

* **TRUE, and re-derived here on the real path:** the prover's table-helper
  line is `inverses(tv.iter().map(|t| alpha.sub(*t)).collect())?` with
  `tv = table_values_u8(g_u8) = table_values_u8_at(Dom::Tab.len(), g_u8)`, and
  `Dom::Tab.natural_log() = 8`, so `tv` carries all 256 byte rows at **every**
  shape (padded entries repeat `i % U8_LEN`). Two details make the claim
  airtight rather than nearly true: the inversion runs over the WHOLE table
  **before** the multiplicities are zipped in, so a table row whose
  multiplicity is zero still refuses; and the same construction holds for the
  exponential and activation tables under their own tags.
* **FALSE as written:** *"whether an attempt is refused is therefore a
  function of the public challenges and the public table alone"*.
  Counterexample, passing as a test: take `alpha = v + g_u8` with `v = 4096`.
  No table row carries 4096, so at every padded table length (256, 512, 2048,
  16384) the three table helpers accept; but the helper line refuses **iff a
  looked column carries 4096**. The same holds for the exponential pair
  family with `(delta, e) = (3, exp[3] + 1)`: the public exponential table
  accepts, the prover's own `inverses(exp_den)?` refuses iff the witness
  carries that pair.
* **What is actually true, and worth saying instead:** *for an honest
  witness*, every looked value lies in `0..256`, every `(delta, e)` pair is a
  row of the exponential table and every activation index a row of the
  activation table — so every denominator the prover forms IS a table
  denominator, and whether an honest attempt is refused is a function of the
  public challenges and the public tables alone. Only a dishonest or tampered
  prover can make the refusal depend on a value of its own, and that is not a
  privacy leak about anybody's hidden input.
* **Not a stage-28 regression.** The counterexample test asserts that the OLD
  path behaves identically on both sides. S28-F1 describes pre-existing
  behaviour; only its second sentence over-reaches.

### 6.3 What, precisely, still depends on the hidden input

1. **Which of the two lines refuses first** (the stage says this).
2. **Whether the attempt is refused at all, when the zero denominator sits at
   a value no public table carries** — reachable only by a witness that is
   already off the table, i.e. by a prover lying about its own secret.
3. **Nothing else.** The thresholds that choose a parallel branch are
   functions of the public shape; the table path is chosen by a value's RANGE,
   not its value (as the ledger says, and this review confirms by reading
   `usize::try_from(v)` + `k < U8_LEN`); elapsed time and peak memory are
   outside this review's scope and are the same class of channel they were.

---

## 7. End to end across versions

### 7.1 At the toy shape — a gate that already exists and ran

`review_tests::a_toy_receipt_made_before_the_lane_still_verifies` verifies
**four archived toy receipts produced before this lane existed** (at `4bf1fa0`
and earlier) under the current verifier, against a statement the verifier
rebuilds, and checks that a one-bit corruption of each is still refused. All
four files are present in the worktree (2,816,472 B each) and the test is in
`q28-gate2.log`'s pass list. **Old prover, stage-28 verifier, accepted.**

### 7.2 At the 125M shape — this review's own run

`/home/victor/zk60-artifacts/m125-run-l12-dense` is a complete 12-block 125M
dense run (`source_commit 0426ad2`, 484,107,456 B of segments, with
`statement/run-statement.json`). The lane's entry point is
`run_statement_file::verify_from_disk`: it re-reads the statement, regenerates
the public weights from the recorded recipe, checks each segment's length and
SHA-256, and verifies the whole run in a fresh `RunVerifier`. This review added
an `#[ignore]`d test that calls it on a directory named by
`HL_PB_S28_REVIEW_RUN_DIR`.

**RESULT: see §9.3.**

### 7.3 At the development shapes — what the committed captures can and cannot do

`results/zk60_run_captures_20260920/` holds ten **capture bundles**
(`hashline-native-capture/4-run`: `manifest.json`, `run.json`, `stage-NN.json`)
— the verifier's VIEW of a run, not its receipts. There are no segment files
and no frame bytes, so **they cannot be re-verified by the verifier** and this
review did not pretend otherwise. Their `source_pins` do record the old
SHA-256 of `protocol.rs` and `argument.rs`, which stage 28 moves; the ledger
already notes that, correctly, as a consequence and not a failure.

### 7.4 What old-prover/new-verifier acceptance does and does not bound

It bounds the verifier: if any field element the verifier computes had moved —
a claim point, an `eq` evaluation, a challenge order, a codec offset — an
archived receipt would stop verifying, because the receipt is fixed and only
the verifier's arithmetic can change. Combined with new-prover/new-verifier
acceptance at five shapes, it also bounds the PROVER's output to the set the
verifier accepts: the new prover still produces frames of the pinned length
that satisfy every relation the old verifier's arithmetic checks.

It does **not** exclude the one thing the stage claims and this path cannot
test: that the new prover writes the SAME BYTES as the old one on the same
randomness. Two provers can both be accepted and still differ in a masked
scalar or a round polynomial. That gap is exactly finding S28-F2's, and the
ten component equality gates plus this review's nine are what stand in for it.

---

## 8. Negative controls still bite

The whole tamper family ran in `q28-gate2.log`. The harness
(`tamper::prove_tampered_for`) **proves with the tampered witness — "the
prover does not pre-check any relation" — and then requires the VERIFIER to
reject at a named catch**, so each case necessarily runs the tampered values
through the code stage 28 changed. Five that land on changed paths, checked by
reading the tamper and its catch:

| tamper | what it feeds the changed code | catch |
|---|---|---|
| `block_output_cannot_be_chosen` (`z16 +1`, whole chain recomputed) | the witness planes of slot 14's table build and claimed sum | `Catch::Slot(SC_DZC)` = slot 14 |
| `a_product_output_not_equal_to_a16_times_u16_is_rejected` (`h16 +1`) | slot 18's tables | `Catch::Slot(SC_FZC)` = slot 18 |
| `a_limb_outside_its_byte_range_is_rejected_by_the_lookups` (`l0 += 256`, `l1 -= 1`, four limb pairs) | **an out-of-`[0,256)` value straight into a looked column**, i.e. `lookup_values`, the histogram's bucket-0 fallback and `helper_inverses_u8`'s out-of-table arm | `Catch::LogUp` |
| `a_moved_activation_multiplicity_is_rejected_by_the_logup_sum_claim` | the multiplicity a histogram bin carries | `Catch::LogUp` |
| `the_norm_m_quotient_is_pinned_by_its_remainder_windows` / `the_norm_m_denominator_is_pinned_by_its_isqrt_witness` | slots 15/17's tables and the byte columns | `Catch::LogUp` / `Catch::Slot(SC_TZC)` |

And the same family is re-run **at the shapes where the parallel branches are
taken**: `rung_tests::every_toy_tamper_family_is_rejected_at_the_rung` and
`…_at_the_rung_g_profile` (histogram, `lookup_values` and the slot-table build
parallel), `k4_tests`' third/fourth-group sweep at rung-K4, which asserts
`7 rejected by the VERIFIER, 0 by the prover, 0 accepted` (there the helper
inverses are parallel too), and
`run_tests::every_single_block_tamper_family_is_still_rejected_inside_a_run`.
**No tamper is caught earlier than it was, and none is accepted.**

---

## 9. The memory and timing claims against the stage's own logs

### 9.1 Do the logs say what the ledger says?

| claim | log | verdict |
|---|---|---|
| prove 27.71 -> **17.40 s** | `q28-baseline-dense.log` "prove 27.71 s"; `q28-m125-final-dense.log` "prove 17.40 s" | **supported** |
| receipt **40,783,352 B** both sides | both logs, in the summary line and in the `encode to bytes` phase | **supported** |
| peak RSS 10,232 -> **10,156 MiB** | both logs' `HWM MiB` column and summary line | **supported** (-0.74%) |
| same test, same witness, same env | both logs run `private_block::rulings_tests::private_block_125m_one_block` and print the identical case line ("weights dense …; input the recipe's own hidden input"); both `HL_PB_TIMING=1`, both exit 0 (`.done` = 0) | **supported** |
| every per-phase figure is in a log | this review re-summed all 92 `PB-SLOTSTEP` lines of both attribution logs: tables 6.011 -> 0.588, claimed sum 0.140 -> 0.020, sumcheck 6.907 -> 6.594, extension 0.747 -> 0.757, and the five per-slot splits (17: 3.419 -> 0.251; 14: 0.859 -> 0.051; 18: 0.620 -> 0.044; 15: 0.302 -> 0.025; 04: 0.364 -> 0.048 with total 0.116 -> 0.016) | **every figure reproduces to the digit** |
| the "baseline" column of the sub-step table | `q28-baseline-dense.log` contains **zero** `PB-SLOTSTEP` lines: `timing::slot_step` was first committed in `a9f2211` | **mislabelled — finding S28-R4.** Those four figures are from `q28-m125-task1-attrib.log` (prove 24.59 s, task 1 applied), a tree that is not any commit |

One more number the ledger does not mention: the intermediate task-1 run's
peak RSS was **10,260 MiB**, slightly ABOVE the baseline's 10,232; the final
tree's 10,156 is below both. Nothing turns on it, but "the high-water mark
went down" is only true of the endpoints.

### 9.2 The filter, with this review's tests included

`--lib private_`, the lane's recipe, `--test-threads=1`, this reviewer's
manifest. Evidence in `results/zk60_block125m_s28_review/`.

| run | threads | result |
|---|---|---|
| `gate-ambient.log` / `.done` | ambient rayon pool | **327 passed / 0 failed / 13 ignored, 414.59 s, exit 0** (the stage's 319 + 12, plus this review's 8 + 1) |
| `gate-rayon1.log` / `.done` | `RAYON_NUM_THREADS=1` | *(filled in below)* |
| `gate-final.log` / `.done` | ambient, final review code | *(filled in below)* |

### 9.3 Cross-version, 125M

*(filled in below)*

---

## 10. Findings

| # | severity | finding | evidence | what would close it |
|---|---|---|---|---|
| **S28-R1** | **equivalence gap + test weakness** | `total` (the parallel claimed sum) has **no old-against-new equality gate**, and its parallel branch (`len > 2^14`) is crossed by **no test that is not `#[ignore]`d** — the census shows only the 125M shape reaches it. The same is true, less sharply, of the parallel table build, the moved public table and the parallel histogram, so the ledger's "for every computation changed, the OLD form and the NEW form are run … in the same test" is false for four of ten changes | this review's threshold census; `grep` shows `total` is private to `argument` and is called nowhere in a test | make `total` `pub(super)` and add a differential test against the serial fold at cubes on both sides of 2^14; or state in the ledger that `total` is covered only by the 125M prove-and-verify. **Mitigation already verified here:** field addition is exact, associative, commutative and canonical (review gate 8), and the 125M run proves AND verifies from bytes with the branch taken |
| **S28-R2** | **wording (a security statement that over-reaches)** | S28-F1's second sentence — "whether an attempt is refused is therefore a function of the public challenges and the public table alone" — is **false**. A witness value off the table (byte `4096`; exponential pair `(3, exp[3]+1)`) gives a zero denominator that no public table carries, so the refusal depends on the hidden column | `s28_review_tests::whether_an_attempt_is_refused_still_depends_on_the_hidden_input_for_off_table_values`, passing | qualify it: the statement holds for every HONEST witness (all looked values and both pair families are table rows), and a dishonest prover's refusal can depend on its own off-table value. The security owner should rule on the qualified statement, not the unqualified one |
| **S28-R3** | **test weakness** | the stage's gates never take the `Err` arm of the out-of-table fallback: `the_table_path_agrees_on_columns_that_carry_values_outside_the_byte_table` asserts `Ok` on both sides | closed by `an_out_of_table_value_whose_denominator_is_zero_is_refused_by_both_paths` (8 values x 3 lengths, single and paired, both sides of the threshold) | already closed by this review's test |
| **S28-R4** | **wording + evidence reproducibility** | the task-3 sub-step table's column headed "baseline" is not the 27.71 s baseline (which has no `PB-SLOTSTEP` lines at all) but the 24.59 s post-task-1 tree, and that tree is not any commit: `slot_step` and the table-build change landed together in `a9f2211` | `grep -c PB-SLOTSTEP q28-baseline-dense.log` = 0; `git show d2c2733:…/timing.rs` has no `slot_step` | relabel the column, and record that the instrument-only tree was measured but not committed (or commit the instrument first next time) |
| **S28-R5** | **wording (trivial)** | the ledger says "Nine such tests" in the pins section and "ten tests" in the gate table; `s28_tests.rs` has ten `#[test]`s | the file | one word |
| **S28-R6** | **incompleteness** | the frozen-toy byte pins — the stage's headline byte evidence — cross **none** of the five parallel thresholds (toy `lookup_words` = 61,440 < 2^17; every domain < 2^14; every cube < 2^14). The parallel branches are covered by the rung / rung-G / rung-K4 / 125M proofs instead, which is adequate but is not what "byte identity at the frozen toy" buys | this review's census, pinned as a test | say in the ledger which shape covers which branch; the census test now pins it so a shape change cannot silently move a branch out of reach |
| **S28-R7** | **robustness (not reachable)** | on a violated precondition (`start + point.len() > n_vars`) old and new `eq_cube` diverge: the old gather produced a wrong but in-bounds cube, the new one computes a wrapped shift and `resize`s by `1 << (shift mod 64)` — a very large allocation. The triple is schedule-driven and public, and `run_slot`'s "table length" check would reject whatever came out, so nothing reachable changes | reading `argument.rs:276-291` against the `79f0726` arm | a `debug_assert!(start + e.len().trailing_zeros() as usize <= n_vars)`, or nothing, with the reason recorded |

| **S28-R8** | **wording (completeness)** | the stage says no refusal moved and none was added; `helper_pair_inverses_u8` does add one, `"private block: paired lookup columns of different lengths"`. It is unreachable (every column of a domain is `size(dom)` long by construction), but it is a new refusal string on the proving path and the ledger does not list it | `protocol.rs:502-504` | one sentence in the ledger, or a `debug_assert!` instead of an `Err` |

**No finding is a hole.** Nothing in this review found an input on which the
new prover computes a different field element, takes a different refusal
decision, or writes a different word from the code at `79f0726`.

---

## 11. Verdict per claim

| claim | verdict |
|---|---|
| **bytes unchanged** (same messages, same transcript) | **upheld as far as it can be tested.** Six of the ten changes have real old-against-new oracles, and this review widened three of them by orders of magnitude without finding a difference; four have only end-to-end evidence (S28-R1). No receipt digest exists to pin (S28-F2, which this review re-derived and agrees with: `s25_tests`' generator scan is the accepted toy statement's condition 6 in code). Receipt LENGTH is identical at the toy, both rungs, rung-K4 and 125M, and every honest proof verifies from its own bytes at all five |
| **refusals unchanged** | **upheld, with one exception to the wording.** Same predicate, same column set, same single string, no absorb or draw between the two refusal points, none removed. Checked on the real functions including the branch the stage never tested. The exception: `helper_pair_inverses_u8` adds one new (unreachable) length-mismatch refusal with a new string, which the ledger does not mention |
| **verifier semantics unchanged** | **upheld, structurally.** No changed computation has a caller on the verifying path; the `Side::Verify` arm is untouched in the diff; and four archived pre-lane toy receipts plus (see §9.3) a pre-stage-28 12-block 125M run still verify |
| **S28-F1** | **PARTLY TRUE.** First half (a zero denominator at a TABLE value refuses the attempt whatever the hidden input carries, with the same string): **true**, re-derived. Second half ("refusal is a function of the public challenges and the public table alone"): **false** for off-table witness values; **true** for every honest witness. See S28-R2 |
| **37% faster (27.71 -> 17.40 s), receipt identical, high-water down 0.7%** | **supported by the logs**, one run each on a shared box, same test, same witness, same environment, both exit 0. One label is wrong (S28-R4) |

---

## 12. What this review did not do

* It did not re-prove the 125M shape. The 17.40 s and the 10,156 MiB are the
  stage's own single runs on a shared box; this review checked that they are
  in the logs, that both runs are the same test with the same env and witness,
  and that every derived figure reproduces — not that they replicate.
* It did not test **byte identity of a receipt**, because no such test can be
  built on this path (S28-F2) and building one was out of scope.
* It did not review `zk.rs`, `pcs.rs`, `sumcheck.rs` or anything else stage 28
  did not touch, and it did not re-check the forbidden-files proof beyond
  confirming the diff's file list.
* It did not exercise the parallel SLOT-TABLE build or the moved public table
  through a unit oracle (no constructor for `SlotDef` is reachable from a test
  module); they are covered here only by the end-to-end proofs at the rungs
  and at 125M.
* It did not measure timing or memory side channels, and says nothing about
  them beyond noting that elapsed time still distinguishes which refusal line
  fired.
* It did not run the Python suite, and did not re-verify the run-capture
  bundles (they carry no receipts, §7.3).
* It made **no privacy claim** about any run.
