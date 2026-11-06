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
