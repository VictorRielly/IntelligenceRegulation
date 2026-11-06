# D63 steps L1 and L2: first families proved, and what the proofs show about the circuit (2026-11-06)

Lean lane (Claude), on perf at 3f25ef9a. Lean 4.34.1, Mathlib v4.34.1, no new dependency. New files under
`formal/ZK60Formal/`: `ModelInt.lean`, `CircuitField.lean`, `CircuitRequant.lean`, `CircuitNorm.lean`,
`CircuitSoftmax.lean`, `CircuitHelpers.lean`, `Goldilocks.lean`, `L1Check.lean`. One test-only Rust file:
`ops/zkp-mvp/gpu-metal/hashline/src/private_block/lean_l1_export_tests.rs`, registered by a one-line
`#[cfg(test)]` module declaration in `witness.rs` (one line, so that the source audits of `s25_tests` read it as a test
module) and listed in `s25_tests.rs`'s `TEST_ONLY_FILES` (the R19b file census); no prover source changed. Evidence: `results/zk60_lean_l1l2_20261106/`.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms `propext`, `Classical.choice`, `Quot.sound` only),
**TESTED** (value for value), **CODE** (read off the sources, file:line), **ESTIMATE** (rows and lookups from the
census and the layout, not measured).

## 1. In plain words, for Victor

**What L1 and L2 are.** L2 is the lemma `circuit_iff`: the profile's constraints can be satisfied for an input and an
output exactly when the output is what the integer model computes. Field arithmetic mod Goldilocks must agree with
integer arithmetic, and the range checks are what make it agree. L1 is that integer model, written as runnable Lean,
and checked number for number against the Rust prover.

**What is done.**
- **Three slot families are proved end to end**, each with its integer spec, its constraints exactly as the Rust code
  builds them, the iff, clean axioms, and values that agree with Rust:
  1. **requantization**, every rounding to int16, int8, 24-bit and the gate class (the largest family; almost every
     range lookup of the block serves it);
  2. **RMSNorm**: the integer square root and the rounded division;
  3. **softmax**: the rounded division and the row maximum.
  The residual additions are proved too.
- **Goldilocks is proved prime** in Lean. Every earlier L3 and L4 proof was stated for "any field"; it now applies to
  the field the code actually uses.
- **L1: the Lean integer model reproduces the Rust witness of a whole small block, value for value**: every word and
  every remainder of all 18 stages, both norms' square-root witnesses, and every softmax internal, for both export
  stacks (the W16R2 stack and the older one). The Lean constraints also hold on Rust's own witness, evaluated in the
  field. Details in §4.
- **Not yet proved:** each family is proved one position at a time, given its inputs (for a requantization, that the
  hosted value is an integer below 2^62). The link to the matmul sums, RoPE and the product in the iff, and the
  composition into one whole-block `CircuitIff` come next (§3, §7). `ProductionReady` is not claimed.

**What the proofs showed about the circuit (your second request).** Writing the iff forces you to say exactly which
fact each constraint contributes. Five places carry slack:
- **The biggest saving (C1):** two LogUp helper planes are half empty. The exp and SiLU table lookups each get a
  helper of their own, while the domain's odd range lookup also sits alone. Pairing them changes no lookup and no
  table, and removes **320 of the block's 4,793 committed rows (−6.7%)**, 12.7% of the helper commitment.
- **C2:** each block checks its input words, which are the previous block's output words, already checked. Dropping
  the repeat saves 64 rows and 0.5 M lookups per block, with no change to the model.
- **C3:** two 18-bit remainders are split into a 16-bit and a 2-bit limb. One direct 18-bit table proves exactly the
  same fact (proved), with one lookup fewer on two domains. That is −115 rows after C1 (−435 alone) and −2.6 M
  lookups (−8%) per block.
- **C4:** the attention-output and down-projection words need no range check to be exact: the residual pins them. Their
  check only enforces the int16 class (proved, with a counterexample). Dropping them is a model change, so it needs your
  ruling; it saves 64 rows and 1 M lookups.
- **C5, C7:** a cheaper int8 score check (−63 rows with C3), and one clause of the softmax (`zsel` booleanity) that no
  proof uses (no rows).

**Together**, the four levers that need no model change (C1, C2, C3, C5) take about **−562 committed rows per block
(−11.7%) and −3.7 M lookups (−11%)** [ESTIMATE]. Every one changes the profile, so under D67 they belong to the
profile after W16R3, unless you add them to W16R3. None is implemented.

**What W16R3 changes here.** W16R3 does not change what any constraint means; Sol's design note says the same
("exact W16 words, rounding, lookups and the approved `CircuitIff` remain the statement"). It repacks the F domain (B3),
so the F-domain savings above shrink by 1/8. §5 has the details.

## 2. What is proved

All PROVED. `lake -d formal build` succeeds with no warnings; `#print axioms` on each theorem below shows only
`propext`, `Classical.choice`, `Quot.sound` (`results/zk60_lean_l1l2_20261106/axioms.log`).

| File | Theorem | Statement |
|---|---|---|
| CircuitField | `int_eq_of_cast_eq`, `int_eq_zero_of_cast` | no wrap: equal images in `GF`, difference below `p` ⇒ equal integers |
| | `word16_iff` | the lookup `x + 32768 ∈ [0, 2^16)` ⇔ `x` is an int16 |
| | `twoLimbs_iff`, `remW16_iff`, `limbs_iff` | a `16 + k`-bit remainder in two W16 limbs ⇔ one direct `(16 + k)`-bit range fact (any limb widths) |
| | `threeBytes_iff` | the isqrt's three byte limbs ⇔ `InRange 24` |
| | `rangeQuery_mem_iff`, `w16r2Fams_ok` | finding F4: LogUp's tuple conclusion ⇒ the value is a canonical representative, for the W16R2 families |
| | `inRangeB_iff` | the decision procedure the L1 check uses is exact |
| CircuitRequant | **`requant_iff`** | requantization at any shift `s ≤ 24`, any word class, `|a| ≤ 2^62`: host relation + word lookup + remainder lookups ⇔ `requantIn` admits `a` and `q` is its word |
| | `requant_witness` | the witness remainder is the spec's |
| | `wordS8_iff`, `word24_iff`, `gateWord_iff` | the int8 score, 24-bit product and gate classes as the code looks them up |
| | `requant_iff_sites` | the W16R2 8B sites: int16 at 15 and 21 (two limbs), int8 at 18, gate at 18, 24-bit at 16 |
| | **`residual_iff`** | residual clause + int16 lookup ⇔ `residual` admits the sum |
| | `residual_pins_word`, `requant_of_residual`, `ao_class_gap` | candidate C4 (§6) |
| | `run_inputs_bounded` | candidate C2 (§6) |
| CircuitNorm | **`isqrt_iff`** | the TZC clauses + three 24-bit facts ⇔ the spec's isqrt witness, in its window |
| | **`normDiv_iff`** | the two DZC division clauses + 24-bit remainders + int16 word ⇔ `normElem` |
| | `isqrt_pos`, `normDiv_d_zero` | the `d ≠ 0` refusal is unreachable (§6, C8) |
| CircuitSoftmax | **`softmaxDiv_iff`** | c2, c3 + P's direct lookup + sr, sg limbs ⇔ `P = ⌊num/sum⌋` |
| | `softmax_sg_window` | the builder's `sg ≥ 2^wrho_s` refusal is unreachable under the window rule |
| | **`rowmax_without_booleanity`** | row sum of `zsel` = 1, `zsel·δ = 0`, exp index range ⇒ `mx` is the row maximum (no booleanity) |
| CircuitHelpers | `pair_helper_iff`, `helper_split_count`, `w16r2_helper_planes` | candidate C1 (§6) |
| Goldilocks | **`gP_prime`**, `rowmax_gf` | `2^64 − 2^32 + 1` is prime (Lucas, witness 7); the row-maximum lemma with no premise |
| L1Check | `hostRes_zero_iff` | the L1 check's host residual is `HostRel` |

**Code citations for the constraints** (all under `ops/zkp-mvp/gpu-metal/hashline/src/private_block/`):
- the requantization hosts: `argument_accuracy.rs` `dzc_w16` 496-497, `fzc_w16` 526, 530-531, `qzc_w16` 560-561,
  563-564, `szc_w16` 620;
- the residuals: `argument_accuracy.rs` 491, 493;
- the norm division: `argument_accuracy.rs` 490-493;
- the isqrt: `argument.rs` 2088-2095 (`SC_TZC`);
- softmax: `argument_accuracy.rs` 624-631 and `argument.rs` 2135-2148 (`SC_RS`);
- the lookups: `accuracy_layout.rs` 289-344, `range16.rs` 113-158;
- the helpers: `argument.rs` 1749-1765, `shape.rs` 2563-2578.

The integer spec (`ModelInt.lean`) is the Rust reference:
- `requant` is `accuracy.rs:12-27`;
- `requantIn` is `quantized`'s class check (`witness_accuracy.rs:373-391`);
- `residual` is `witness_accuracy.rs:459-469`;
- `normRow` / `normElem` / `isqrtWitness` are `normalized` (`witness_accuracy.rs:414-457`);
- `softmaxRow` is the softmax loop of `build_with` (`witness_accuracy.rs:869-904`);
- `matmulIO` / `rope` are `witness.rs:870-905, 944-958`.

## 3. What is assumed (explicit hypotheses, no axioms)

- **Each family is proved at one position, given its inputs.** The hosted value `a` of a requantization is an integer
  with `|a| ≤ 2^62`; that it IS the matmul's integer sum is the matmul sumcheck's hand-off, a separate family (next,
  §7). The honest values are below `2^50` (the D56 inventory), so the premise has more than 12 bits of room.
- **Range facts come from LogUp.** The families take `InRange w x` as given. `rangeQuery_mem_iff` turns L3's conclusion
  (`logup_block_bound`: every looked-up tuple is a table tuple) into it. The functional tables are taken the same way:
  the exp tuple's index in `[0, 256)` and the ACT tuple's index `g + 2048 ∈ [0, 4096)`.
- **The isqrt's byte limbs** are proved to certify exactly `InRange 24` (`threeBytes_iff`); `isqrt_iff` is stated
  with `InRange 24` directly, and the link `d = dl` (argument.rs:2090) is the clause that ties the two.
- **The softmax premises** `0 ≤ num ≤ 2^f_p·sum` and `1 ≤ sum ≤ 2^wrho_s` come from the exp tuple and the row sum
  (`SC_RS`). The block-level composition that links them is not written yet.
- **Block boundaries (C2):** that the boundary commitment equates block `k + 1`'s input plane with block `k`'s output
  plane at every position is a hypothesis (`hlink`). L3's opening soundness supplies it.

## 4. What the L1 value-for-value test covered

`lake -d formal env lean --run formal/ZK60Formal/L1Check.lean …` (command in the file header; log
`results/zk60_lean_l1l2_20261106/l1check.log`): **101,956 checks, 0 failed** [TESTED]. Per stack, 56 sites;
every site is listed in the log with its count.

- **The block.** The R13 trace fixture (`r13_vectors/block_fixture_t32.tsv`): one whole block, 32 tokens, width 16,
  hidden 32, 4 query heads of 4 over 2 KV heads, public synthetic weights.
- **Both export stacks:** `low-h24`, the stack the W16R2 profile proves, and `low`.
- **The Rust side.** The whole witness, from the new test `lean_l1_export_the_fixture_trace` (run under the guard,
  rc 0, `rust_export.log`; 104 arrays in `rust_fixture_trace.tsv`). Every stage is recomputed in Lean from the
  previous stage's Rust words.
- **Spec checks.** The Lean words AND remainders must equal Rust's for:
  - both norms: the isqrt witness `d, a1, a2`, and per element the word, remainder and slack;
  - Q, K, V, the RoPE rotations of Q and K, the scores, softmax (row maximum, total, `zsel`, `e`, `P`, `sr`, `sg`),
    PV, the output projection, residual 1, gate (with the group folds), up, the product, down, and residual 2.
- **Oracle checks.** Every Rust word site must also equal the independent oracle's trace
  (`block_trace_low{,_h24}_t32.tsv`).
- **Constraint checks.** The Lean constraints are evaluated in `GF` on Rust's witness: the host relation of every
  requantization site, every word-class lookup and remainder limb (through `inRangeB`), the residual clauses, the
  isqrt clauses, the norm division clauses, the softmax division and argmax clauses, the row sums, and the exp tuples.
- **The rational vectors.** The requantization's 324 independent vectors (`r13_requant_vectors.tsv`).
- **Not recomputed: the SiLU table.** It is public data. Its values come from the Rust trace, and only its
  functionality is checked (same `(group, gate)`, same value).
- **The Rust test's own hygiene.** The source audits that read `witness.rs` and the `private_block/` directory
  (`s25_tests`, the absorb-label and byte-literal scans) passed 21 of 22 on the first run (`rust_audit_try1.log`). The one
  failure was the R19b file census, which requires every new file to be listed; `lean_l1_export_tests.rs` is now in
  `TEST_ONLY_FILES`. The rerun is queued under the guard (`rust_audit.sh`, writing `rust_audit.log` and `.done`); at
  hand-back the heavy lock was still taken by other lanes.
- **Not covered: the 8B shapes.** The same functions run at any shape; an 8B export is next (§7).

## 5. What W16R3 changes for these proofs

Read from `W16R3_DESIGN_B1_B3_20261105.md` (main checkout; its §0 and §7) and D67:
- **B1** (coefficient-form rows) changes the PCS encoder only. No constraint changes.
- **B2** (equal-size zero-check batching) changes how slot relations are batched into sumchecks, and the challenge
  schedule. The per-position relations proved here are unchanged.
- **B3** (compact F domain: 112 rows per F plane instead of 128, with the padded tail dropped) changes F's
  **indexing** and removes F's pad indicator. The per-position F relations (gate, up, product, the ACT tuple) are
  unchanged.
  - The block-level instance must re-index F.
  - The F part of candidates C1 and C3 scales by 112/128: C1 is −224 instead of −256 data rows on F.
- **No B4** (D67(2)). The exact W16 word checks stay, so every iff here stands as proved.

**Flag:** none of B1–B3 changes a constraint's meaning. The per-family iffs carry over unchanged to W16R3.

## 6. Optimization candidates

Ranked by estimated committed-row saving per W16R2 8B T128 block. The census is
`results/zk60_effplan_20261105/census.log`: A data 2,279, H data 2,514, total 4,793; 32,276,480 lookups; rows per plane
D 32, Q 32, Kv 8, F 128, S 32, Tab 1; H planes are `Fp2` (two data rows per row). The numbers are ESTIMATES from the
layout, not measurements.

| # | Candidate (constraint) | Lean evidence | Saving per block [ESTIMATE] | Protocol impact |
|---|---|---|---|---|
| C1 | **Pair the functional-table query with the half-used range helper.** F: 7 range lookups → 3 pairs + 1 single, plus the ACT single (`fact`, argument_accuracy.rs:528); S: the same with the exp single (`ihx`, :631). `shape.rs:2573-2578` | `pair_helper_iff`: a pair relation forces `h = 1/(α−a) + 1/(α−b)` whatever tables `a`, `b` come from (both linear folds, degree unchanged); `helper_split_count`: L3's `logup_block_bound` depends on the split only through `N = |ι| + 2|π|`; `w16r2_helper_planes` | **−320 data rows** (F −256, S −64): −6.7% of committed rows, −12.7% of H; no lookup, table or A change; same `N`, same LogUp bound | new H layout and slot relations: new profile. No model change |
| C3 | **Direct 18-bit family for the two-limb 18-bit remainders** RGL (gate, F) and RSL (score, S) (`range16::rem_lookups`, accuracy_layout.rs:321, 330) | `twoLimbs_iff`: `lo ∈ [0,2^16) ∧ hi ∈ [0,2^2)` with `R = lo + 2^16·hi` ⇔ `R ∈ [0,2^18)`; `requant_iff` uses only `InRange s R` | after C1: A −145 (the RGL-hi F plane −128, the RSL-hi S plane −32, +16 Tab sub-planes, −1 for the 2-bit family), H +30 (Tab helpers): **−115 rows**; alone: **−435 rows** (also one F and one S helper plane). Lookups −2,621,440 (−8.1%, helping LogUp's α term) | new table family and layout: new profile. No model change |
| C2 | **Drop the block-input word check `X`** for blocks after the first (accuracy_layout.rs:304): it is the previous block's `X2`, already checked | `run_inputs_bounded`: boundary link + block 0's input check + every block's output check ⇒ every block's input is int16 | D 19 → 18 lookups, 10 → 9 helper planes: **−64 rows**, −524,288 lookups (−1.6%) | block profile without `X`'s lookup plus a once-per-run entry check (or the embedding stage's table): new profile. No model change |
| C4 | **Drop the `AO` and `Z16` word checks** (accuracy_layout.rs:306, 308) | `residual_pins_word` + `requant_of_residual`: with `X`, `X1` (resp. `X1`, `X2`) checked, the residual makes `AO` (`Z16`) the exact floor of its accumulator with no lookup; `ao_class_gap`: only the int16 CLASS is lost (an explicit witness with `ao = 65535`) | with C2: D 18 → 16, 9 → 8 planes: **−64 rows**, −1,048,576 lookups | **model change**: the class of AO and Z16 becomes `(−2^16, 2^16)` (an exact iff with the redefined model, not B4's probabilistic gap); needs Victor's ruling |
| C5 | **One query for the symmetric int8 score** instead of two byte queries (accuracy_layout.rs:328-329), into a 255-entry family `{0..254}` | `wordS8_iff`: the two queries certify exactly `[−127, 127]`, the set a single `s8 + 127 ∈ {0..254}` certifies | only with C1 + C3: S 5 range + exp → 3 planes: **−63 rows**; −524,288 lookups | new table family: new profile |
| C7 | **The booleanity clause `c0 = zsel² − zsel`** (argument_accuracy.rs:627) is used by no proof | `rowmax_without_booleanity` / `rowmax_gf` | no rows; one clause and one `μ` fewer in SZC | removes a clause: new profile; negligible |
| C8 | **Unreachable refusals** in the witness builder: `d == 0` (witness_accuracy.rs:422), `sg ≥ 2^wrho_s` (:898) | `isqrt_pos`, `normDiv_d_zero`, `softmax_sg_window` | prover-side only, negligible | byte-preserving; keep as defensive checks unless profiling says otherwise |

**Combined** (ESTIMATE):
- C1 + C2 + C3 + C5, none a model change: about **−562 committed data rows per block (−11.7%)** and −3.67 M lookups
  (−11.4%).
- Adding C4: −626 rows (−13.1%) and −4.72 M lookups.

How much of this reaches the wall is not modelled here. The H commitment's cost scales with its rows, and B6's receipt
census puts clear vectors at 52% of the receipt; the B4/B5 study's time model is the place to price it.

**Looked at and rejected:**
- **A tighter norm remainder decomposition** (`nr < 2^(tn+1)·d` as a 3-bit and a `d`-bounded limb). With
  `LIMBS_ISQRT = 3`, `d` can need 24 bits, and it would cost 5 lookups instead of 4.
- **SR's and SG's upper bounds.** Each is implied by the other's lower bound and `c3`, but a range check is the only
  way to prove a lower bound, so both checks stay.
- **P's 13-bit check.** It is needed: without it `c2` is solved mod `p` by a false `sr` (the B4 note's argument). Its
  width is tight for honest values (`P ≤ 2^f_p`).
- **Packing two remainders into one tuple lookup** on Q, Kv and F. The tables grow past the helper saving (for example
  RU with H16's top byte: a 2^20-entry table against one F plane).
- **The isqrt window.** It is looser than the norm admits (`r + s + 1 = 2^(tn+1)·d` with `r, s < 2^24` forces
  `d < 2^(24 − tn)`), but it lives on `Dom::T`/`Dom::L` and saves no row.

## 7. What is next

1. **The matmul family.** The sumcheck hand-off that the hosted value `a` IS `Σ W·x·m`, with its no-wrap bound from the
   input classes. This discharges `requant_iff`'s `|a| ≤ 2^62`.
2. **The RoPE and product relations**, inside the iff. Their spec and their host relations are already checked in L1.
   The ACT table's functionality also needs a lemma.
3. **The block-level `CircuitIff`.** Compose the families per position over the domains, with the pad rule, into one
   statement at the rung block, then the 8B block, then the run (with C2's boundary link).
4. **L1 at 8B.** Export one 8B W16R2 block's witness (the same test at a registered shape) and run `L1Check` on it.
5. **The candidates.** Victor to rule whether any of C1–C5 joins W16R3 or waits for the next profile, and on C4's
   class change.

---

# Second lane (2026-11-06, afternoon): the matmul hand-off, RoPE, the SiLU product and the ACT table, and `CircuitIff` for a whole block

Lean lane (Claude), on perf at acf5c78a. New files under `formal/ZK60Formal/`: `CircuitMatmul.lean`,
`CircuitRopeAct.lean`, `CircuitStage.lean`, `CircuitMasked.lean`, `CircuitBlock.lean`; `L1Check.lean` extended (a token
count, the RoPE rows and the input are now parameters, and the oracle comparisons are optional). The test-only Rust
export (`lean_l1_export_tests.rs`, already registered) gains the rung at the 8B token count; no prover source changed.
Evidence: `results/zk60_lean_l2b_20261106/`. Labels as in §1 to §7.

## 8. In plain words, for Victor

**The headline: `CircuitIff` is now PROVED for a whole W16R2 block, as an instance of the statement you approved.**
For every shape and every public data the code admits, the block's constraint system can be satisfied with input
words `x` and output words `y` exactly when `x` is admissible and `y` is the integer block's output
(`block_circuitIff`). The same holds for a RUN of blocks chained through their boundary planes (`run_circuitIff`).
The block is composed in the code's order: norm, Q/K/V, RoPE, scores, softmax, PV, output projection, residual,
norm, gate with its SiLU table, up, product, down, residual.

**The four steps you asked for:**
1. **The matmul premise is gone.** The earlier lemma assumed each hosted value was below `2^62`. That bound is now
   proved from the word classes and the code's size limits: the largest hosted value of any shape the code admits is
   the down projection's, below `2^58` (`noWrap_class_bounds`); every other site is below `2^51`.
2. **RoPE, the SiLU product and the SiLU (ACT) table are proved**, each family as the earlier ones were, and so is the
   exp table. The gate word has no range lookup of its own: the ACT table's index proves its class (`gateAct_iff`).
3. **The block-level `CircuitIff`** (above).
4. **L1 at a larger rung**: the whole block at the 8B token count, T = 128 (the full 128 × 128 causal score square per
   head), value for value against Rust. An 8B-wide export was not attempted (§11).

**What it still assumes** (§10): the IOP's conclusions (that is L3's part: LogUp's table membership, the per-position
zero-check and sumcheck identities, the row sums), the code's checks on the public data, and the LAYOUT MAP from the
committed cube to the logical positions (padding, head-slot order and, under W16R3's B3, the re-indexed F domain).

**One new saving (C9):** about half of the softmax domain is the masked triangle `j > t`. The proofs show that
everything committed there is forced (`P = 0`, `sr = 0`, `sg = sum − 1`) and that the model's output never reads the
masked scores. Moving the softmax internals to the causal triangle would save about **165 committed rows per 8B block
(−3.4%), 0.78 M range lookups (−2.4%) and 0.26 M exp tuples** with no model change, and about **270 rows (−5.6%) and
1.8 M range lookups (−5.6%)** if the masked scores also lose their int8 class check, which is a model change for you
to rule on [ESTIMATE].

**One finding about the approved statement (not changed, written up):** `IntModel.admissible` does not see the
weights, but the integer model refuses on weight-dependent overflows. The instance therefore fixes the public data per
model (sound under P1, where the weights are public). Under P3 (hidden weights) `admissible` would need the weights.

## 9. What is proved (second lane)

All PROVED; `lake -d formal build` succeeds with no warnings; `#print axioms` on every theorem below shows only
`propext`, `Classical.choice`, `Quot.sound` (`results/zk60_lean_l2b_20261106/axioms.log`).

| File | Theorem | Statement |
|---|---|---|
| CircuitMatmul | `hosted_cast`, `bilinear_cast` | the hosted field sum `Σ_i x_i·(W_i·m)` is the image of the integer `(Σ_i x_i·W_i)·m` |
| | `dot_abs_le`, `hosted_abs_le` | `|Σ x·w| ≤ |ι|·X·W`; the hosted bound from the input, weight and multiplier bounds |
| | `requantIn_mul` | `requant acc m s = requant (acc·m) 1 s` |
| | **`matmul_requant_iff`** | the matmul hand-off: hosted identity + word lookup + remainder lookups ⇔ the integer model on the INTEGER matmul sum admits the position and `q` is its word |
| | **`bilinear_requant_iff`** | the same for the private-by-private products (scores, PV) |
| | `hosted16_le`, `hosted24_le`, `hostedScore_le`, `hostedPV_le`, `noWrap_class_bounds` | every site's hosted value is below `2^62` for every shape in the code's no-wrap class |
| | `ss_bounds`, `ss_cast` | the norm's `ss = ceps + Σ x²` is in `[0, 2^60)` (`isqrt_iff`'s premise) |
| CircuitRopeAct | `ropeRel_iff`, **`rope_iff`**, `rope_pair` | the RoPE clause is a host at shift 7; its iff; the two positions of a pair are `Model.rope`'s two outputs |
| | `prodRel_iff`, **`product_iff`** | the SiLU product `a·u` requantized to the 24-bit word |
| | `expQuery_iff`, **`actQuery_iff`** | the exp tuple ⇔ `δ ∈ [0, 256)` and `e = exp[δ]`; the ACT tuple ⇔ the gate is in `[−2048, 2047]` and `a = act[group][g + 2048]` |
| | **`gateAct_iff`** | the gate's requantization with its class from the ACT index (no word lookup of its own) |
| | **`codeTable_range_iff`**, `codeTable_exp_iff`, `codeTable_act_iff`, `w16r2Fams_FamsOK` | L3's conclusion (every looked-up tuple is a tuple of the block's table) gives exactly the facts the families use |
| CircuitStage | `liftO_eq_some`, `liftO_exists` | a stage refuses when any position refuses; per-position iffs lift to planes |
| | `rqPlane_iff`, `rqPlaneBil_iff` | a whole matmul stage |
| | **`normTok_iff`**, `normTok_class` | one RMSNorm row (one isqrt shared by the row's divisions) |
| | **`softmaxRow_iff`**, `softmaxF_class` | one softmax row: the maximum (no booleanity used), the total (proved positive from `c3`), every column's division, the masked columns included |
| CircuitMasked | `masked_column_forced`, `softmaxF_live_only` | candidate C9 (§12) |
| CircuitBlock | `resPlane_iff`, `ropePlane_iff`, `prodPlane_iff`, `gatePlane_iff`, `normPlane_iff` | the remaining stages over planes |
| | **`blockSat_iff`**, `blockSpec_class` | the whole block, plane form |
| | **`block_circuitIff`** | **`CircuitIff (blockModel S P) (blockArith S P)`**, the approved statement, for every valid shape and public data |
| | `run_iff`, **`run_circuitIff`** | a run of blocks through the boundary planes |
| | `w16r2_8B_geometry` | the W16R2 8B T128 geometry is in the shape class |

**The instance.** `blockModel S P : IntModel`: `Input = Output =` int planes over (token, width); `admissible x`: `x` is
int16 and the integer block `blockSpec P x` does not refuse; `forward`: its output. `blockArith S P : Arith`: the
witness is the block's committed planes (`BlockWit`), and `Satisfies` says the endpoints are int16 word planes and
`BlockSat` holds on their images. `BlockSat` lists every clause of the code at every logical position, with its
file:line (CircuitBlock.lean): the input check; both norms (`SC_SS`/`SC_SSM` hosts, `SC_TZC`, the `dzc_w16`
divisions); Q, K, V, O, gate, up, down as hosted matmul identities with their word and remainder lookups; both RoPE
clauses; the scores; the softmax row relation (exp tuple, `c0`–`c3`, `SC_RS`'s two row sums, `P` and the slacks);
PV; both residuals; the ACT tuple; the product.

**The integer block** (`blockSpec`) is a composition of the per-position functions L1 already tests
(`requantIn`, `residual`, `normElem`, `isqrtWitness`) with functional forms of `normRow` and `softmaxRow`
(`normTok`, `softmaxF`), stage by stage; its every word is the image of the Rust builder's under the rung check (§11).

## 10. What is assumed

- **The IOP's conclusions, i.e. the meaning of `Satisfies`.** `BlockSat` is the constraint system pointwise. That the
  committed planes satisfy it is L3's: the per-position hosted identities and zero-check clauses (zero-check and
  sumcheck soundness, `SoundZeroCheck.lean`), the two row sums (`λ`-batching), and the lookups. **The lookup premise,
  exactly:** L3's `logup_block_bound` concludes that every looked-up tuple of the block equals a tuple of
  `CodeTable w16r2Fams exp act nG` (range families, exp rows, ACT rows). `codeTable_range_iff`, `codeTable_exp_iff`
  and `codeTable_act_iff` turn each membership into the fact `BlockSat` states (`InRange w x`, `ExpTable`,
  `ActTable`), given only that the family tags are distinct naturals below `p` and differ from `TAG_EXP` and `TAG_ACT`
  (`w16r2Fams_FamsOK`).
- **The public data** (`BlockPublic.Valid`): weights and gains symmetric int8, multipliers `≤ 2^14`, CS-4's RoPE and
  exp bounds, the scaled ACT words below `2^31`, every hidden channel's group registered. Each is a check the code
  makes at construction (cited field by field), not re-derived from an export.
- **The shape** (`BlockShape.Valid`): the code's no-wrap geometry class, the softmax window `T·2^f_e ≤ 2^wrho_s ≤ 2^24`,
  `f_p ≤ 12`, `1 ≤ ceps ≤ 2^24`, `|cn| ≤ 2^24`, `tn ≤ 16`, shifts `≤ 24`, at most 4 ACT groups.
- **The layout map.** `BlockSat` is stated at the LOGICAL positions. The committed layout pads `Dom::F` at W16R2
  (14336 → 16384 columns), permutes the head slots (C-1) and gates every clause by its support indicator. The next
  instance step is the map: a bijection of each domain's support with the logical positions, the pad rule (padded
  planes are zero, so they add nothing to a hosted sum, and a padded lookup reads `0` or the ACT pad row
  `(2048, TAG_ACT, 0, 0)`, which is group 0's row), and the head permutation. **W16R3's B3 changes exactly this map for
  `Dom::F`** (112 rows, no pad) and nothing proved here.
- **The boundary link** of a run: block `k + 1`'s input plane IS block `k`'s output plane (`RunSat` shares the plane;
  the boundary commitment equates the two committed planes, L3's opening soundness).
- **Not modelled:** the rest of the run (the embedding and token stages, D34), and the DD dictionary variant.

## 11. L1 coverage (second lane)

- **The fixture, unchanged:** the 101,956 checks of §4 still pass (`l1check.log`; the parametrized check runs the
  fixture exactly as before, and the Rust fixture export is byte-identical, `fixture` being `fixture_tokens(_, 32)`).
- **The rung at the 8B token count:** the fixture's weights, gains, multipliers, groups, exp table and calibration at
  `T = 128` (the RoPE rows of tokens `t ≥ 32` repeat the fixture's rows 1–31, the input of token `t` is the fixture's
  token `t mod 32` plus `4·⌊t/32⌋`), both export stacks, every stage recomputed in Lean from the previous stage's Rust
  words, every remainder and constraint evaluated on Rust's witness (`lean_l1_export_the_t128_rung_trace`, then
  `L1Check.lean`'s rung mode). The softmax at this rung has the 8B profile's full score square per head (128 × 128,
  the 8,128 masked columns per head included). No oracle trace exists at this rung, so the oracle comparisons are not
  run there. RESULT: see `results/zk60_lean_l2b_20261106/l1check.log`.
- **Not covered: an 8B-wide export.** An 8B block's public data is about 218 M int8 weights and its witness about 40
  planes of up to 2 M words; the interpreted Lean check would recompute about `2^35` multiply-adds. It fits the
  guard's memory but not this lane's time; the rung keeps the width (16) and the head count (4) of the fixture.

## 12. Optimization candidates (updated)

The table of §6 stands (C1–C8). New:

| # | Candidate (constraint) | Lean evidence | Saving per W16R2 8B T128 block [ESTIMATE] | Protocol impact |
|---|---|---|---|---|
| C9a | **Move the softmax internals to the causal triangle.** At a masked column `j > t` (half of `Dom::S`: 32 heads × 8,128 of 16,384 columns) the row relation commits `e`, `zsel`, `P`, `sr`, `sg` and looks up the exp tuple, `P`, `sr` and `sg` (argument_accuracy.rs:624-631; accuracy_layout.rs:335) | `masked_column_forced`: there `P = 0`, `sr = 0`, `sg = sum − 1` are forced, and `e` is read by nothing (the row sum multiplies it by the mask); `softmaxRow_iff` holds with the masked columns' clauses present or absent | `e, zsel, P, sr, sg` (5 of the 8 S planes) on a compact triangular domain of 264,192 positions (17 rows per plane instead of 32): A −75 rows; H: the square keeps 2 helper planes for the score's 4 lookups, the triangle 3 (P, sr, sg + exp) of 17 rows, −90 data rows: **−165 rows (−3.4%)**; range lookups −780,288 (−2.4% of the census's 32,276,480) and 260,096 exp tuples; smaller `SC_RS`/`SC_SZC`/`SC_PV` sumchecks | a second S domain with B3-style compact indexing and the causal mask in the hosted sums: new profile; no model change |
| C9b | **C9a plus the masked scores themselves** (their requantization's host, word check and remainders) | `softmaxF_live_only`: the integer softmax row depends only on its live scores, so the masked scores affect the model ONLY through their own int8 class check (`sSpec`) | all 8 S planes and all 5 helper planes on the triangle: A −120, H −150: **−270 rows (−5.6%)**; range lookups −1,820,672 (−5.6%) and 260,096 exp tuples; `SC_SCORE` over the triangle | **model change**: a masked score outside `[−127, 127]` no longer refuses (as C4, an exact iff with the redefined model); needs your ruling |

C9 overlaps C1 (the S-domain exp helper pairing), C3 (the 18-bit score remainder) and C5 (the int8 score check): the
estimates are not additive with them.

**Looked at and rejected (second lane):**
- **Dropping a word check because a later stage pins the word.** The int16 checks of `Y`, `YM`, `QR`, `KR`, `U` and the
  24-bit check of `H` are each the ONLY fact that makes the next matmul's hosted value an integer of bounded size: a
  remainder in range does not pin a requantized word (the clause solves `q` in the field for ANY remainder, and only a
  remainder making the numerator divisible gives an integer). Unlike `AO` and `Z16` (C4) no residual follows them.
- **The token-0 RoPE row.** CS-4 forces `cos = 2^7`, `sin = 0` at token 0, so `QR(0, ·) = Q(0, ·)` with the remainder
  `2^6`; one token of 128 on two of the twelve Q/Kv planes: negligible.
- **The isqrt's `dsq` plane.** Substituting `d·d` into `SC_TZC`'s host saves the two `Dom::T` planes (2 rows) for one
  degree: negligible.

## 13. What is next (second lane)

1. **The layout map** (§10): the committed cube's support to the logical positions, the pad rule and the head
   permutation, at W16R2, then re-indexed for W16R3's compact F domain. With it, `BlockSat` becomes a statement about
   the committed planes themselves.
2. **The link to L3**: instantiate `logup_block_bound` with the block's lookup list and `CodeTable`, the zero-check
   and sumcheck lemmas with the block's slots, and so derive `BlockSat` from an accepting transcript (KnowledgeSound's
   deterministic half).
3. **The rest of the run**: the embedding and token stages (D34) and the DD variant.
4. **L1 at 8B width**: an 8B export (one block's public data and witness, under the guard at `--need-gib 32`) and a
   compiled (not interpreted) Lean check.
5. **The candidates**: Victor to rule on C9a/C9b alongside C1–C5.
