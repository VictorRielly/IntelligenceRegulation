# W16R2 (D59): the soundness recount for the rate-1/2 profiles

Written 2026-11-01 for D59 condition (2): "the accounting documents (D15/D24/D27 figures) recounted and
independently re-checked". This file is the recount. **It has not been independently re-checked yet.** It is
written so that a checker can redo every number from the inputs below.

Labels used here:
- **[CODE]**: a value the code prints (the `W16R2-ACCOUNTING` lines, see "Inputs").
- **[COUNTED]**: exact rational arithmetic in `count.py` (Python `fractions`, log2 taken at the end).
- **[CARRIED]**: a term or convention taken from an earlier accepted document, not re-derived here.

## Headline

| Profile | Per regular opening | Whole run | Same run under W16 (rate 1/4) | Change |
|---|---:|---:|---:|---:|
| `W16R2_8B_T128_H24` (Llama-3-8B, L = 32) | 2^-105.934 | **2^-97.361** | 2^-97.269 | +0.092 bit |
| `W16R2_SHIELD_T128_H24` (Shieldstral-1.0-3B, L = 26) | 2^-105.934 | **2^-97.660** | 2^-97.568 | +0.092 bit |
| `W16R2_RUNG_H24` (development rung, one block) | 2^-105.934 | 2^-103.565 | 2^-103.303 | +0.262 bit |
| `W16R2_RUNG_H24` (the 3-block run the gate chain proves) | 2^-105.934 | 2^-102.180 | 2^-101.928 | +0.252 bit |

- The per-opening figure includes the field term. The column term alone is 2^-105.946 for W16R2 and
  2^-105.609 for W16.
- **No soundness is given up.** Every regular opening is 0.33 bit stronger than W16's, and every whole run is
  stronger. This meets D59's condition that no bits are traded.
- Both trained runs still clear D27's MVP floor of about 95 bits whole-run: 8B T128 by 2.36 bits and
  Shieldstral T128 by 2.66 bits. Neither reaches the next milestone of 100.
- The runs are LogUp-bound (2^-97.92 at 8B, 2^-98.22 at Shieldstral). That term is the same for W16 and
  W16R2, because the rate moves no plane, lookup or slot.
- These figures reproduce the lemma check's §6 exactly: W16 8B T128 2^-97.27 against W16R2 2^-97.36.
  Here the sumcheck terms are counted from the slot table rather than scaled from REVIEW_R14 (see "Terms").
- **D27's named workload is 8B T512, and no W16R2 profile exists for it.** The lemma check's §6 counts the
  R13 layout there at Q = 258 and finds 2^-94.66, the same as today. It is LogUp-bound. That figure is
  carried, not recounted here.

## What changed, and what did not

Only the PCS geometry of the **regular** commitments changes: `A`, `H`, every boundary `B_k` and both
endpoints. The code is `shape.rs` (`W16R2_PROFILES`, `Shape::build`) and the gate is
`w16r2_profiles_fix_rate_one_half_and_q_260_and_change_nothing_else`.

| | W16 | W16R2 |
|---|---|---|
| message width n | 2^14 | 2^14 |
| inverse rate, so N = n · inv_rate | 4, N = 2^16 | **2, N = 2^15** |
| opened columns Q, and pads per row q_pad | 256, 256 | **260, 260** |
| code K = n + q_pad, ρ = K/N | 16,640, 0.2539 | 16,644, 0.5079 |
| endpoint and boundary geometry | the same as the core | the same as the core |
| column-test count | D15: Ligero δ/3, δ = 1 − K/N | **D59: BCIKS20 Thm 3.1 at δ_t = (1 − K/N)/2** |
| masking commitment `M` | `zk.rs` constants: RS(1024, 4096), Q = 256, δ/3 | **unchanged** (the lemma does not cover M) |
| planes, rows, lookups, slots, LogUp challenges | — | **identical** (the layouts are equal; the gate asserts it) |

The verifier takes the rate and Q from the profile. `Shape::build` refuses a W16R2 string at any other
geometry. `protocol::pcs_params_at` and `endpoint_pcs_params` read the shape, and no verifier site reads a
receipt's geometry. Control (e) shows that a receipt at another rate or Q is rejected.

## Inputs [CODE]

The inputs are printed by `private_block::w16r2_tests::w16r2_accounting_inputs_are_printed_from_the_code`
(`--nocapture`). The log is `logs/accounting_inputs.log`. `count.py <log>` parses those lines and asserts
they equal its constants. The test asserts that the T128 lookup counts equal the W16 review's
(`results/zk60_limb16_20261031/REVIEW_W16_20261101.md` §1): 32,276,480 / 524,288 / 2,097,152, and
Σ2^w = 110,772.

| Profile | n | inv_rate | N | Q = q_pad | K | e (δ/2) | A rows | H rows | M rows | range/byte queries | exp | ACT | Σ 2^w | Σ(main+ext)·deg | Σ(3(main+ext)+3) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| W16R2_8B_T128_H24 | 16,384 | 2 | 32,768 | 260 | 16,644 | 8,062 | 2,501 | 2,602 | 50 | 32,276,480 | 524,288 | 2,097,152 | 110,772 | 1,099 | 1,179 |
| W16_8B_T128_H24 | 16,384 | 4 | 65,536 | 256 | 16,640 | — | 2,501 | 2,602 | 50 | 32,276,480 | 524,288 | 2,097,152 | 110,772 | 1,099 | 1,179 |
| W16R2_SHIELD_T128_H24 | 16,384 | 2 | 32,768 | 260 | 16,644 | 8,062 | 2,501 | 2,602 | 50 | 32,276,480 | 524,288 | 2,097,152 | 110,772 | 1,159 | 1,179 |
| W16_SHIELD_T128_H24 | 16,384 | 4 | 65,536 | 256 | 16,640 | — | 2,501 | 2,602 | 50 | 32,276,480 | 524,288 | 2,097,152 | 110,772 | 1,159 | 1,179 |
| W16R2_RUNG_H24 | 16,384 | 2 | 32,768 | 260 | 16,644 | 8,062 | 317 | 198 | 50 | 1,015,808 | 16,384 | 32,768 | 110,774 | 924 | 957 |
| W16_RUNG_H24 | 16,384 | 4 | 65,536 | 256 | 16,640 | — | 317 | 198 | 50 | 1,015,808 | 16,384 | 32,768 | 110,774 | 924 | 957 |

Notes on the inputs:
- **Exp and ACT queries** are the sizes of `Dom::S` and `Dom::F` (one exp query per score entry, one ACT query
  per padded hidden lane), as in REVIEW_W16 §1.
- **Σ(main+ext)·deg** sums the slot table (`Shape::slots`) over the profile's slots (23, non-DD). It differs
  between 8B and Shieldstral because their attention geometry differs.
- **The row counts depend on the calibration's gate shift.** The rows above are at the trained door's shift
  20 (`range16_tests::built`, the shape the W16 review counted). The A/B's synthetic case commits 2,504
  `A` rows and 2,606 `H` rows; 2,606 is the lemma check's m. Rows enter only the reduction-bias factor and
  the byte counts, never a term above. The lookup counts are the same at both.
- **Constants:**
  - p = 2^64 − 2^32 + 1, |Fp2| = p².
  - G = 4 activation groups, the conservative value REVIEW_W16 §1 uses.
  - The carried PCS ceiling is 4,096 per opening (REVIEW_R14 A5, the lemma check §6).
  - The mask constants come from `zk.rs`: MASK_LOG_DOM 12, MASK_LOG_MSG 9 and MASK_Q 256, printed beside the
    rows.

## Terms

Every term below is an interactive bound. Under Fiat–Shamir it is a per-attempt rate, as D27 reads every
term (REVIEW_R14 A2).

**1. Column test, one regular opening.**
- **D59, W16R2.** The lemma check's statement, §4:
  Pr[accept ∧ (U δ_t-far ∨ a claim false)] ≤ (1 − (e+1)/N)^Q + N/|Fp2|, with e = ⌊(N − K)/2⌋.
  - The far case and the close case exclude each other, so the bound is the larger of the two, not their sum.
  - The claim-batching term 1/|Fp2| is absorbed in N/|Fp2|.
  - The bound is multiplied by (1 + p/2^128)^(2m), which is 1 + 2^-51.65 at m = 2,606 (the largest committed
    row count measured). It is negligible.
- **D15, W16.** The column term is ((2N + K)/(3N))^Q. The field term is (⌊δN/3⌋ + 1)/|Fp2|, with
  δ = 1 − K/N. This is RECOUNT §1–5 and REVIEW_R14 §3, unchanged.
- **Both regimes** add the carried 4,096/|Fp2| per opening.

**2. Mask opening M** (both profiles, unchanged). The column term is (3/4)^256 = 2^-106.250 and the field term
is (2·512 + 1 + 4,096)/|Fp2| [CARRIED: REVIEW_R14 §3].

**3. LogUp, one block.** The term is (N_lk + 4·T_d − 1)/|Fp2| [CARRIED convention: REVIEW_W16 §1, REVIEW_R14 §3].
- N_lk = range/byte + exp + ACT queries.
- T_d = 256 + 256 + 4,096·G + Σ2^w.
- The term is identical for W16 and W16R2. The rate changes neither N_lk nor T_d, and the challenge order is
  the same in both: A is committed and its root absorbed before β, γ and α are drawn.

**4. Sumcheck rounds, one block:** Σ(main+ext)·degree/|Fp2|.

**5. Zero-check, batching and output-point allowance, one block:** Σ(3(main+ext)+3)/|Fp2|. This is
REVIEW_R14's allowance.

**6. A run of L blocks.**
- It opens 3L + 1 regular commitments: 2L block commitments (A and H), L − 1 boundaries and 2 endpoints.
- It opens L mask commitments.
- It carries L LogUp, sumcheck and zero-check terms.
- The whole run is the union of all of them (D15's reading, REVIEW_R14 A6).

## Per regular opening [COUNTED]

| Profile | Rule | e | Column | Field | Both |
|---|---|---:|---:|---:|---:|
| W16R2 (all three) | δ/2 | 8,062 | 2^-105.946 | 2^-112.830 | **2^-105.934** |
| W16 (all three) | δ/3 | 16,298 (= ⌊δN/3⌋) | 2^-105.609 | 2^-113.684 | 2^-105.604 |
| M (both) | δ/3 | 1,024 | 2^-106.250 | 2^-115.678 | 2^-106.248 |

The lemma check's table reproduces exactly:
- Q = 260 gives 2^-105.946 in the exact integer form.
- Q = 259 gives 2^-105.539, short of W16's 2^-105.609. So **260 is the minimum Q** that keeps W16's figure.
  `count.py` asserts this, and `shape.rs` hard-codes 260 with the same comment.

## Per block [COUNTED]

| Profile | N_lk | T_d | LogUp | Sumcheck | Zero-check |
|---|---:|---:|---:|---:|---:|
| 8B T128 (W16 and W16R2) | 34,897,920 | 127,668 | 2^-102.922 | 2^-117.898 | 2^-117.797 |
| Shieldstral T128 (both) | 34,897,920 | 127,668 | 2^-102.922 | 2^-117.821 | 2^-117.797 |
| rung (both) | 1,064,960 | 127,670 | 2^-107.412 | 2^-118.148 | 2^-118.098 |

## Whole run [COUNTED]

| Profile | L | Openings | Column | PCS field | LogUp | Sumcheck | Zero-check | **Whole** |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| W16R2_8B_T128_H24 | 32 | 97 + 32 M | -99.004 | -106.166 | -97.922 | -112.898 | -112.797 | **-97.361** |
| W16_8B_T128_H24 | 32 | 97 + 32 M | -98.732 | -106.969 | -97.922 | -112.898 | -112.797 | -97.269 |
| W16R2_SHIELD_T128_H24 | 26 | 79 + 26 M | -99.301 | -106.462 | -98.222 | -113.121 | -113.096 | **-97.660** |
| W16_SHIELD_T128_H24 | 26 | 79 + 26 M | -99.029 | -107.266 | -98.222 | -113.121 | -113.096 | -97.568 |
| W16R2_RUNG_H24 | 1 | 4 + 1 M | -103.680 | -110.781 | -107.412 | -118.148 | -118.098 | **-103.565** |
| W16_RUNG_H24 | 1 | 4 + 1 M | -103.394 | -111.596 | -107.412 | -118.148 | -118.098 | -103.303 |
| W16R2_RUNG_H24 | 3 | 10 + 3 M | -102.310 | -109.449 | -105.828 | -116.563 | -116.513 | **-102.180** |
| W16_RUNG_H24 | 3 | 10 + 3 M | -102.033 | -110.257 | -105.828 | -116.563 | -116.513 | -101.928 |

All entries are log2. Checks against earlier documents:
- **W16 at 8B T128** reproduces the lemma check's §6 row "Today" (column 2^-98.73, PCS field 2^-106.97, whole
  2^-97.27).
- **W16R2 at 8B T128** reproduces its row "#1" (2^-98.99, 2^-106.17, 2^-97.36). Its sumcheck input was an
  estimate (2^-111.5, scaled from REVIEW_R14). The counted sum of the two small terms here is 2^-111.85, which
  moves no printed whole-run digit.
- **The Shieldstral W16 column term** (2^-99.029) equals REVIEW_R14's (the same 79 + 26 openings at rate 1/4,
  Q 256).

**Where the change sits.**
- The field term grows from about 16,299 + 4,096 to 32,768 + 4,096 per regular opening (N/|Fp2| instead of
  the δ/3 erasure count), costing 0.8 bit on that term. That term is 9 bits below the run's figure.
- The column term gains 0.27 bit.
- The run is LogUp-bound, so the whole run moves +0.09 bit.

## Assumptions (carried; none proved here)

- **A1.** BLAKE3 is a random oracle, both in Fiat–Shamir and in the Merkle layer, keyed per profile (D19).
  The W16R2 strings derive their own four keys, and s24's H-4 test asserts they are distinct from every
  other profile's keys.
- **A2.** Every figure is an interactive union bound, which under Fiat–Shamir is a per-attempt rate. The
  multi-round Fiat–Shamir loss is not quantified anywhere in the project (lemma check §9).
- **A3′** (replaces REVIEW_R14 A3 for the W16R2 profiles only). The regular openings' column test is counted
  at the unique-decoding radius by BCIKS20 Thm 3.1, as the lemma check verified. Five conditions hold in code:
  - **(a) Independent row weights.** The proximity weights are `rows` independent uniform `challenge_fp2`
    draws over every row. They are not powers of one challenge, which would give 2^-101.65 per opening by
    Thm 1.6 at m = 2,606.
  - **(b) Index order.** The indices are drawn after every vector is absorbed.
  - **(c) Pads.** q_pad ≥ Q.
  - **(d) Path length.** The path length is checked: every W16R2 verifier site is `verify_zk_tagged`.
  - **(e) RS code.** The verifier's encoder is a bijection onto RS[D, n + q_pad]. This is unchanged code
    (`encode_row_zk`); W16R2 adds no new encoder.
  - (a) to (d) are pinned by `w16r2_the_lemmas_load_bearing_invariants_are_pinned`.
  - **Version caveat:** the BCIKS20 copy read is the July 2020 one. The 2021 revision says its main
    statements are unchanged (lemma check §9).
- **A4.** Every count is below p, and multiplicities are committed before β, γ and α (unchanged from W16).
- **A5.** The masked-sumcheck lemma and the 4,096 PCS ceiling are carried at their R13 level.
- **A6.** The union is taken over blocks. No first-cheating-block composition is used.
- **A7.** Only the blocks are counted. The token, classifier and fork-run stages are excluded.
  - D55's fork runs have their own figure (REVIEW_D55, 2^-97.3 at L = 32).
  - A D55 run over a W16R2 base moves only the PCS column and field terms counted here.

## What is not done here

- **No independent re-check.** D59 condition (2) needs one.
- **No W16R2 profile at T256 or T512**, so no figure at D27's named workload. The lemma check's 2^-94.66 at
  8B T512 (R13 layout, Q = 258) is carried, not recounted.
- **M under δ/2 is not counted.** The lemma check did not cover M. M keeps its current constants and its
  δ/3 accounting.

## How to re-check

```
python3 results/zk60_w16r2_20261101/count.py results/zk60_w16r2_20261101/logs/accounting_inputs.log
```

It prints every table above and fails if a parsed input differs from its constants. The inputs come from the
test binary:

```
<hashline test binary> --exact private_block::w16r2_tests::w16r2_accounting_inputs_are_printed_from_the_code --nocapture
```

The per-opening figure is also computed in Rust (`shape::column_term_log2`, f64). The profile gate asserts it
at 2^-105.946 (Q 260) and 2^-105.53 (Q 259) against 2^-105.61 (W16).

Independent sources for the formulas:
- `research/zkp-efficiency/handoffs/20261101-delta-half-lemma-check.md` §4–6;
- `results/zk60_d24_review_20261017/REVIEW_R14.md` §3;
- `results/zk60_limb16_20261031/REVIEW_W16_20261101.md` §1;
- `results/zk60_soundness_recount_20261017/RECOUNT.md`;
- `docs/zkmatrix-poc/ZK60_DECISIONS.md` D15, D27 and D59.
