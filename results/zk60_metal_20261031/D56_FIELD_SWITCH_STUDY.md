# D56 study: what moving the private-block prover from Goldilocks to a 31-bit field would cost

Status: research note, 2026-11-01. Read-only. Nothing was built and no cargo command or test was run. The only
code I executed was two exact-arithmetic Python scripts. They recount the integer bounds and the cost model, and
the bounds script is reproduced in the appendix. The question is open question D56 in
`docs/zkmatrix-poc/ZK60_DECISIONS.md:85`. The measured motivation is M18 in `README.md:968-996` of this directory.

Labels used below:
- [COMPUTED]: exact integer arithmetic over the code's declared classes.
- [COUNTED]: derived from the code's plane and lookup lists.
- [ESTIMATE]: a design I sketched and checked for bounds, but nothing built.
- [MODEL]: a scaling model, not a measurement.

Scope: the W16 accuracy stack at `W16_8B_T128_H24` (`shape.rs:248`): Llama-3-8B geometry, LowH24, Standard
registry, non-DD, T = 128. Today's counts there are `A` 40,976,384 words, `H` 42,631,168 words and lookups
32,276,480 (`results/zk60_limb16_20261031/DESIGN.md:19-20`). I reproduced all three from `shape.rs` (§2.3).

## Bottom line

1. **Fifteen relations in the W16 block do not fit a 31-bit field.** They fall into eleven groups. Their integer
   bounds run from 2^37 to 2^49.8, against p ≈ 2^30.9 for BabyBear and 2^31 for Mersenne-31. The worst are:
   - the down-projection requantization, 2^49.8;
   - the gate requantization, 2^48.0, because the folded gate multiplier reaches 2^14;
   - the norm isqrt square and row sum, 2^48;
   - the SiLU product, 2^45.0;
   - the norm division, 2^43.3;
   - the Wo requantization, 2^42.0.

   Every public-weight matmul (Q, K, V, Wo, gate, up, down) and the score matmul is too wide. Each multiplies int8
   weights by int16 (or 24-bit) activations over 128 to 16,384 inputs, with per-channel multipliers up to 2^14. The
   softmax quotient, PV, RoPE, the residuals, all range and tuple lookups, and the LogUp characteristic condition do
   fit at T128.
2. **The cheapest exact fix costs roughly as many committed words and lookups as W16 just saved, and then
   more.** Every wide matmul accumulator has to be carried as digits: byte-limb inputs, two-digit partial sums and a
   carry. Totals [ESTIMATE]:

   | | W16 today | after the fix | ratio |
   |---|---:|---:|---:|
   | `A` | 41.0 M words | ≈ 104 M words | ×2.5 |
   | lookups | 32.3 M | ≈ 84.6 M | ×2.6 |
   | `H` (helpers in Fp4, four base words each) | 42.6 M words | ≈ 193 M base words | ×4.5 elements, ×2.3 bytes |

3. **Under that cost the measured arithmetic gain disappears** [MODEL]. A block's GPU work is about 0.165 s today.
   It goes to about 0.24-0.34 s with committed helpers, and to about 0.19-0.29 s with LogUp-GKR. Goldilocks with
   LogUp-GKR and no field switch models at about 0.14-0.17 s. D56's model of 0.07-0.08 s assumed today's witness
   would survive the switch unchanged. It does not.
4. **Soundness accounting.** With challenges in a degree-4 extension (|F| ≈ 2^123.6), today's LogUp term worsens:
   - W16 8B T128 run: from 2^-97.92 to about 2^-92.2 [COMPUTED];
   - 8B T512 run: about 2^-90.1 (rough count).

   D27's MVP target is about 95 bits whole-run at 8B T512, so it is missed unless the lookup challenges come from a
   bigger field. That is cheap only inside LogUp-GKR; with committed helpers it would double `H` again.
5. **No sound "commit in 31 bits, run the IOP in Goldilocks" half-step exists.** The two fields are unrelated:
   neither is a subfield of the other. The sound first steps that do exist are:
   - a field-generic refactor that keeps Goldilocks bytes identical;
   - LogUp-GKR in Goldilocks;
   - a counted census of the 31-bit layout;
   - a Metal benchmark of BabyBear's own quartic extension, which M18 did not measure.
6. **Recommendation: do not adopt D56 now.** If it is revisited, after LogUp-GKR and the census, choose BabyBear
   (or KoalaBear), not Mersenne-31. This PCS is a Reed-Solomon (Ligero) code over multiplicative subgroups with
   coset hiding, and BabyBear's two-adicity of 27 keeps that structure. Mersenne-31 needs a circle-FFT code and a
   re-derived zero-knowledge encoding.

---

## 1. No-wrap inventory

**Rule.** A clause `E = 0` checked in F_p implies `E = 0` over the integers only if |E| < p for every admissible
witness. The admissible witnesses are fixed by the range facts the proof itself enforces (lookups), not by honest
behaviour. The thresholds:
- BabyBear: p = 15·2^27 + 1 = 2^30.907.
- Mersenne-31: p = 2^31 - 1.
- Goldilocks today: 2^64.

**Classes used** (all from the code):
- int16 words: `word + 32768` in R16, so [-32768, 32767] (`accuracy_layout.rs:297-325`, `range16.rs:84`).
- The 24-bit product word h: [-2^23, 2^23) (`range16.rs:95`).
- int8 weights: -128 is refused, so |W| ≤ 127 (`accuracy_fold.rs:42-45, :53`).
- Per-channel multipliers: m ≤ 2^bits with bits [q 5, k 5, v 6, o 8, g 6, u 4, d 6] (`accuracy_precision.rs:96`,
  checked at `accuracy_public.rs:133-139`).
- The folded gate multiplier: ≤ 2^14 (`accuracy_groups.rs:60-66`, `accuracy_fold.rs:52`).
- Shifts: the tested 8B calibration q = k = 15, v = 16, score 18, pv 12, ao 21, gate 18, up 12, down 20; the
  product fold shift is 16 (`accuracy_precision.rs:84-90, :117-118`; `accuracy_aligned.rs:25-29`). These
  reproduce the logged range families of `REVIEW_W16_20261101.md:46`.
- The scaled ACT table: |a| ≤ 32767·2^15 Standard, 32767·2^16 Shieldstral (`accuracy_tables.rs:14-16`,
  `accuracy_aligned.rs:37-46`).
- Norm class: Cn ≤ 2^20, Ceps ≤ 2^40, |γ| ≤ 128 (i8), D < 2^24 by three byte limbs (`shape.rs:259-261`,
  `private_block.rs:548`).
- Softmax: f_e = 9, so wrho_s = 16 at T128 (`shape.rs:286-289`); e ∈ [0, 2^9]; P < 2^13 (`range16.rs:105`).

All bounds are [COMPUTED] (appendix).

| # | Relation (clause) | Where | max \|E\| | BabyBear | M31 |
|---|---|---|---:|:-:|:-:|
| 1 | Q requant: `2^15 q + r - 2^14 = Σ m_q W y` (4096 inputs) | `argument_accuracy.rs:557`; matmul `argument.rs:1803-1843` | 2^38.99 | ✗ | ✗ |
| 2 | K requant (same form) | `argument_accuracy.rs:557` | 2^38.99 | ✗ | ✗ |
| 3 | V requant, s = 16, m ≤ 2^6 | `argument_accuracy.rs:558` | 2^39.99 | ✗ | ✗ |
| 4 | Wo requant `2^21 ao + ral - 2^20 = Σ m_o W o` (q_width 4096, m ≤ 2^8) | `argument_accuracy.rs:490` | 2^42.01 | ✗ | ✗ |
| 5 | gate requant `2^gs g + rg - half = Σ m_g W ym`, folded m ≤ 2^14 | `argument_accuracy.rs:524` | 2^47.99 | ✗ | ✗ |
| 6 | up requant, s = 12, m ≤ 2^4 | `argument_accuracy.rs:525` | 2^37.99 | ✗ | ✗ |
| 7 | down requant `2^20 z + rd - 2^19 = Σ m_d W h` (14,336 true, 16,384 padded inputs, h 24-bit) | `argument_accuracy.rs:491`; `argument.rs:1952-` | 2^49.80 (2^49.99 padded) | ✗ | ✗ |
| 8 | score requant `2^18 s8 + rsl - 2^17 = Σ_128 qr·kr` (both int16) | `argument_accuracy.rs:614`; `argument.rs:1884-1919` | 2^37.00 | ✗ | ✗ |
| 9 | PV requant `2^12 o + ro - 2^11 = Σ_s P v`: naive bound (P < 2^13 each) / derived bound (Σ_s P_s ≤ 2^12) | `argument_accuracy.rs:558`; `argument.rs:1920-1945` | 2^35.0 / **2^28.0** | ✗ / ✓ | ✗ / ✓ |
| 10 | product `f0 = a·u - 2^16 h - rh + 2^15` (a = scaled SiLU word) | `argument_accuracy.rs:520` | 2^45.02 (2^46.01 Shieldstral) | ✗ | ✗ |
| 11 | scaled ACT values representable as signed field elements (\|a\| < p/2) | `accuracy_aligned.rs:44-46` | 2^31.0 | ✗ | ✓ Std / ✗ Shieldstral |
| 12 | norm_a division `c0 = γ x 2Cn + 2^tn D - 2^(tn+1) D y - nr` | `argument_accuracy.rs:484` | 2^43.32 (class); about 2^38 at honest scale | ✗ | ✗ |
| 13 | norm_m division (same, on x1, ym) | `argument_accuracy.rs:486` | 2^43.32 | ✗ | ✗ |
| 14 | norm `c1 = nr + ns + 1 - 2^(tn+1) D` (×2) | `argument_accuracy.rs:485, :487` | 2^26.0 | ✓ | ✓ |
| 15 | row sums of squares into the TZC host: `Σ x² = dsq + a1 - Ceps` (×2: norm_a, norm_m) | `argument.rs:1683-1698, :1760-1761` | 2^48.0 (Σ x² alone 2^42) | ✗ | ✗ |
| 16 | TZC `dsq - D²` (×2) | `argument.rs:1755` | 2^48.0 | ✗ | ✗ |
| 17 | TZC `D - limbs`, `2D - a1 - a2` | `argument.rs:1755-1756` | 2^25.0 | ✓ | ✓ |
| 18 | residuals `x1 - x - ao`, `x2 - x1 - z` | `argument_accuracy.rs:485, :487` | 2^16 | ✓ | ✓ |
| 19 | RoPE `c q + s q' - 2^7 qr - rr + 2^6` | `argument_accuracy.rs:554` | 2^23.0 | ✓ | ✓ |
| 20 | softmax `c2 = mask e 2^12 - P·Sum - sr`: T128 / T256 / T512 | `argument_accuracy.rs:623` | 2^29.0 / 2^30.0 / 2^31.0 | ✓ / ✓ / ✗ | ✓ / ✓ / ✗ |
| 21 | softmax `c3 = sg + sr + 1 - Sum` | `argument_accuracy.rs:624` | 2^17 | ✓ | ✓ |
| 22 | row-sum host `Σ_j mask e = Sum`, `Σ zsel = 1` | `argument.rs:1788-1802`; `argument_accuracy.rs:612` | 2^17.6 | ✓ | ✓ |
| 23 | selector `c0`, `c1`; exp, ACT and DD tuple lookups; tag fold `q + γ·tag` | `argument_accuracy.rs:521-522, :621-625`; `range16.rs:51` | identities in the extension | ✓ | ✓ |
| 24 | range lookups: words, `h = lo + 2^16 t`, `limbs16` | `range16.rs:74-105`; `argument.rs:1404-1407` | 2^24 | ✓ | ✓ |
| 25 | LogUp characteristic: N < p (each value's query count must stay below p) | `REVIEW_W16_20261101.md:72` | N = 2^25.06 today; 2^26.38 after the fix; about 2^28.5 at T512 | ✓ | ✓ |
| 26 | IO endpoints and run boundaries (field equality of committed planes) | `argument.rs:2598-2603` | none | ✓ | ✓ |
| — | *outside the block, in a next-token run:* the token stage's keyed difference `2^v·(2·d·127²·2^12) + V` | `token_io.rs:463-471` (checked against Goldilocks `P` at :468-470) | about 2^56 | ✗ | ✗ |

**Count.** At W16 8B T128, **15 clauses do not fit BabyBear**: rows 1-8, 10, 12, 13, two each of 15 and 16. They
form 11 groups: seven public-weight requantizations, the score, the product, the norm division and the norm
isqrt/row sums. Three more items do not fit:
- the scaled ACT table cannot be read as signed values in BabyBear (row 11);
- softmax `c2` at T512 (row 20);
- the next-token stage (last row).

M31 changes none of this: its extra 0.09 bits of room covers only the Standard ACT table's representability.

**Notes on the rows that fit.**
- **PV (row 9) fits only under an ordered argument.** The softmax clauses must be integer-sound first: c2, c3 and
  the row sum, rows 20-22, which fit at T128 and T256. From them, P_s = floor(mask·e_s·2^12 / Sum) with Sum =
  Σ mask·e, so Σ_s P_s ≤ 2^12 and |Σ P v| ≤ 2^27. The new no-wrap derivation has to state this ordering. Today's
  Goldilocks premise never needed it (`layout.rs:762-828`).
- **Softmax c2 (row 20).** P < 2^13 and Sum ≤ T·2^f_e, so it fits up to wrho_s = 17 and wraps at 18. The trained
  class allows wrho_s ≤ 24 (`shape.rs:289`), so a 31-bit profile must narrow the class to wrho_s ≤ 17 and refuse
  above it by name. Alternatively, a T512 profile moves the division to the DD dictionary domain (D30), where a
  split of P·Sum is cheap (Dom::Dd is 2^19 at T512, against 2^23 for Dom::S).
- **LogUp characteristic (row 25).** It holds with 2.4-5.8 bits of margin at T128-T512. It fails per block at about
  T ≈ 2048: the S domain alone then carries about 2^30.5 queries. Long-context profiles would need split sum claims.
- **The isqrt and row-sum clauses (rows 15-16) sit on the tiny Dom::T** (128 positions), so their fix is cheap. The
  norm division (rows 12-13) sits on Dom::D (2^19 positions) and is not.

## 2. Fixes for the relations that do not fit, and their cost

### 2.1 What does not work cheaply

**A matmul must split its input.**
- With int8 weights over 4096 inputs, an unsigned input digit of b bits keeps a partial sum below p/2 only if
  2^12 · 127 · 2^b < 2^29.9, so b ≤ 10.
- int16 activations therefore need two input digits (8 + 8), and the 24-bit h over 14,336 inputs needs three.
- Splitting the inner dimension instead would cost hundreds of planes per output.

**The per-channel multiplier m cannot be folded into the matmul.** m·W·digit·n reaches 2^35. So each partial sum
P_k (up to 2^27-2^29) must itself be split before m multiplies it: m·P_k reaches 2^35-2^41.

**Changing the fixed-point scales to fit the field fails the fidelity bar.**
- int8 activations, as in the legacy stack, make everything fit natively (Σ int8·int8 over 4096 is 2^26). They are
  exactly what the D32 fidelity bar rejected: legacy 8B was 1.28x float perplexity. The 16-bit norm and attention
  words and the multipliers of LOW+H24 are what pass (`docs/zkmatrix-poc/MVP_STATUS.md:498-500, :569-577,
  :638-640`).
- A cheaper fixed-point design is therefore a fidelity question with a ruling attached, not a proof-system lever.

**No field trick avoids the decomposition.**
- Checking E ≡ 0 mod p and E ≡ 0 mod 2^k, with E < 2^k·p, needs the same low digits and carry, so it costs the same.
- CRT over two 31-bit primes means a whole second proof system over the same witness.
- Mersenne-31's 2^31 ≡ 1 gives nothing for integer equalities.

### 2.2 The cheapest exact construction I found [ESTIMATE; every new relation's bound checked, appendix]

**Gadget M: requantized public-weight matmul.**
- **Input digits.** x = Σ_k 2^8k x_k: two byte digits for int16 inputs, three for h. The top digit is signed.
  - One new plane per extra digit.
  - The word's single R16 lookup becomes byte lookups, so one more lookup per extra digit.
  - Shared inputs share their digits: Y for Q, K and V; YM for gate and up.
- **One matmul sumcheck per site, as today.** Its private factor becomes Σ_k λ^k x̃_k with λ an extension challenge.
  The output claim covers Σ_k λ^k P̃_k, with P_k = Σ_j W_ij x_k,j: |P_k| ≤ 2^26.98 at 4096 inputs and 2^28.98 at
  16,384. These are exact integers below p/2.
- **Each P_k is hosted on a two-digit linear form** P_k = L_k + 2^c_k·H_k, with L_k ∈ [0, 2^c_k) and H_k signed;
  both are committed and range-checked. Every high weight 2^(8k + c_k) must be a multiple of 2^s.
- **Two carry clauses replace the old host clause.**
  - `m·Σ_k 2^8k L_k + 2^(s-1) = 2^s·q' + r`, with q' a new small committed carry and r today's remainder.
  - `q = m·Σ_k 2^(8k + c_k - s)·H_k + q'`.
- **Cut choices that keep every clause below p_BB:**

  | site | cuts | largest new clause |
  |---|---|---:|
  | Q / K | [15, 16] | 2^29.0 |
  | V | [16, 16] | 2^30.0 |
  | Wo | [21, 13] | 2^30.0 |
  | up | [12, 12] | 2^26.0 |
  | down | [20, 15, 7] | 2^30.09 |

- **The folded gate fails.** With multipliers up to 2^14 the low clause reaches 2^31 and wraps. The gate is costed
  after **unfolding the common denominator**: per-channel shifts ≤ 22 with raw multipliers ≤ 2^6, cuts [22, 14],
  largest clause 2^29.0. That needs a per-position remainder width: a public width column folded into the tagged
  range query. That is a scale or format change for the security owner. Keeping the fold instead needs a third
  carry level, about +2 planes on F.

**Score: private × private, both factors int16.**
- QR and KR get byte digits.
- The bilinear sumcheck takes the combined factors (qr_lo + λ qr_hi)(kr_lo + λ kr_hi). This yields claims on the
  three exact cross sums: S00 ≤ 2^23, Smid ≤ 2^23, S11 ≤ 2^21.
- Commit a0, a1 (S00 = a0 + 2^16 a1), b0, b1 (Smid = b0 + 2^8 b1), S11 and a binary carry c.
- Two clauses, at 2^17 and 2^21, replace `host_s`.
- 6 planes and 4 lookups per score entry.

**Product f0.** The aligned construction's scaled table (a up to 2^30-2^31) cannot be kept.
- The ACT table holds the raw int16 SiLU word w, and the group exponent becomes a per-channel shift s' = 16 - e.
- u is split into bytes, and a carry chain at 2^8 runs: level clauses at 2^23 and 2^29.
- About 3 planes and 3 lookups per F position, plus per-position remainder widths. Moving the scale out of the table
  undoes the reason for the aligned construction (`accuracy_aligned.rs`).

**Norm division (c0, both norms).** It reuses the x, y and D digits. The public 2·Cn·γ goes into two public 14-bit
digits, and a carry chain of about 3 levels runs, so about 3 planes and 3 lookups per D position per norm. Narrowing
the Cn class from 2^20 to 2^16 would save about one digit.

**Norm isqrt and row sums.**
- The row sum becomes three sums: Σx_lo², Σx_lo·x_hi, Σx_hi², each below 2^28.
- D² gets a byte-digit chain using D's existing three limbs.
- All of this lives on the 128-position Dom::T: about 32 one-row planes in total.

### 2.3 Counts per block, W16 8B T128 [ESTIMATE, from the gadget table in the appendix]

Domain sizes are D, Q and S 2^19; Kv 2^17; F 2^21; row width 2^14 (`results/zk60_limb16_20261031/count.py:11`).
My model reproduces W16's 32,276,480 lookups exactly. It also reproduces `A` = 2,279 data rows plus 222 mask and
proximity rows, and `H` = 2 × 1,257 data rows plus 88.

| addition | domain | planes / lookups per position | added `A` words | added lookups |
|---|---|---|---:|---:|
| Q requant | Q | 5 / 5 | 2,621,440 | 2,621,440 |
| K requant | Kv | 5 / 5 | 655,360 | 655,360 |
| V requant | Kv | 5 / 5 | 655,360 | 655,360 |
| Wo requant | D | 6 / 6 | 3,145,728 | 3,145,728 |
| gate requant (unfolded) | F | 6 / 6 | 12,582,912 | 12,582,912 |
| up requant | F | 5 / 5 | 10,485,760 | 10,485,760 |
| down requant | D | 9 / 9 | 4,718,592 | 4,718,592 |
| score requant | S | 6 / 4 | 3,145,728 | 2,097,152 |
| product | F | 3 / 3 | 6,291,456 | 6,291,456 |
| norm division, both norms | D | 6 / 6 | 3,145,728 | 3,145,728 |
| input digits (y, ym, x, x1 / o, qr / kr / h) | D / Q / Kv / F | 4 / 2 / 1 / 1 | 5,373,952 | 5,373,952 |
| norm isqrt and row sums | T | 32 one-row planes | 524,288 | 524,288 |
| **total added** | | | **53,346,304** | **52,297,728** |

**Resulting block** [ESTIMATE]:

| | W16 today (Goldilocks) | 31-bit exact-digit design | ratio |
|---|---:|---:|---:|
| `A` elements | 40,976,384 (data 37.3 M + 222 mask/prox rows) | ≈ 104.3 M (data ≈ 90.7 M; mask/prox ≈ 13.6 M: 222 → 444 rows for 4-row masks, plus about 384 rows for the new claim sites) | ×2.55 elements, ×1.27 bytes (4-byte words) |
| lookups (N for LogUp) | 32.3 M (N = 2^25.06) | 84.6 M (N = 2^26.38) | ×2.62 |
| `H` base elements | 42,631,168 (Fp2: 2 per helper) | ≈ 193 M (Fp4: 4 per helper; helpers 20.6 M → 46.7 M) | ×4.5 elements, ×2.26 bytes (772 MB vs 341 MB) |
| zero-check tables, weighted by domain size | 108.25 | 261.5 | ×2.42 |

A plausible lower bound for this style of construction is about 20% below these numbers: four digits per two-digit
output instead of five, binary carries, and paired 8-bit digits sharing one 2^16 tuple lookup. That is still about
×2 on `A` and lookups.

### 2.4 Time model [MODEL, not measured]

**Baseline.** M10 measured about 0.165 s of GPU work per W16 8B block (`README.md:783-786`): sumcheck rounds
0.075 s, two commitments 0.065 s, opening folds 0.025 s.

**How I scaled it.**
- Each part scales by the counted work above.
- Arithmetic gets M18's per-multiply gains: base ×3.5; extension ×1.8, using QM31 as a stand-in for BabyBear's
  quartic extension, which was not benchmarked.
- Hashing scales by bytes.
- Ranges run from ALU-bound to bandwidth-bound. The Fp4 table element is 16 bytes, the same as today's Fp2.
- The LogUp-GKR cost for Goldilocks is DESIGN.md's estimate of 0.05-0.08 s (`DESIGN.md:88-93`). For BabyBear it is
  about 0.07-0.11 s: 2.4 times the leaves at 1.8 times the speed.

| configuration | rounds | commitments | folds | GKR | total |
|---|---:|---:|---:|---:|---:|
| today: Goldilocks Fp2, committed helpers | 0.075 | 0.065 | 0.025 | — | **0.165 s** |
| BabyBear Fp4, exact digits, committed helpers | 0.10-0.18 | 0.09-0.12 | 0.04-0.05 | — | **0.24-0.34 s** |
| Goldilocks Fp2 + LogUp-GKR | 0.049 | 0.032 | 0.012 | 0.05-0.08 | **0.14-0.17 s** |
| BabyBear Fp4 + LogUp-GKR, exact digits | 0.07-0.12 | 0.03-0.04 | 0.02 | 0.07-0.11 | **0.19-0.29 s** |

**Reading.** D56's model of about 0.07-0.08 s holds only if the witness stays the same size, and for bit-exact
R13/W16 arithmetic it does not. Even with every gain M18 measured, the 31-bit design is slower than today unless:
- the quantization design changes (a fidelity ruling); or
- a cleverer decomposition than mine cuts the digits by more than half.

This needs the census of §4.3 to become a counted figure.

## 3. Everything else that changes

### 3.1 Commitment scheme (Ligero form, `zkp-core/src/pcs.rs`)

| item | today | in a 31-bit field |
|---|---|---|
| code | systematic RS over the size-n subgroup, encoded on the size-n·inv_rate group; ZK form `f_data + Z_n·g_pad` on a disjoint coset (`pcs.rs:1-19, :557-569`) | BabyBear: same construction (two-adicity 27 ≥ the largest nn = 2^18 at T512). M31: no 2^k multiplicative subgroup, so a circle-group RS code, circle FFT and a new hiding encoding with the circle vanishing polynomial; the "any Q positions jointly uniform" lemma must be re-derived |
| rate, columns | inv_rate 4, Q = 256 opened columns: (1 − δ/3)^Q = 2^-106.2; ZK code RS(n + Q, nn) about 2^-105.6 (`pcs.rs:16-19`; `protocol.rs:73`) | **unchanged** (combinatorial, field-independent), provided every row weight and proximity coefficient stays in the extension (it does: Fp2 today) |
| field terms | "O(n/2^128)" (`pcs.rs:19`) | O(nn/\|Fp4\|) = 2^16/2^123.6 = 2^-107.6 per opening: fine |
| coset generator | 7, a generator of Goldilocks^* (`pcs.rs:579-584`) | 31 for BabyBear (generator); recheck `coset_powers`' disjointness assert (`pcs.rs:645-654`) |
| NTT tables | `two_adic_root`, TWO_ADICITY 32, plonky2 root pinned in a test (`field.rs:13-16, :80-86, :296-306`) | new twiddles; BabyBear Montgomery form must be canonicalised before hashing |
| word size | 8 bytes in hashing, openings and instrumentation (`pcs.rs:113-118, :141-147, :616-620`; `protocol.rs:1563, :1768` hard-code `8 *`) | 4 bytes for base words; Fp4 is 16 bytes, like Fp2 today |

### 3.2 Where challenges live, and transcript derivation

**Every production challenge is already an extension element.**
- `challenge_fp` (base field) is used only in a test (`transcript.rs:113-117, :200`).
- All slot, LogUp (α, β, γ), batching (μ, ν, ζ) and PCS challenges go through `challenge_fp2`
  (`transcript.rs:119-129`; 651 call sites including tests).
- In a 31-bit field this must stay absolute. One base-field challenge anywhere (in GKR, a pad ζ or a batching
  weight) would cost the proof down to about 2^-31.

**Sampling.**
- Today: one 32-byte squeeze gives two 128-bit draws, bias 2^-64 each.
- Fp4 from one squeeze: 64 bits per coordinate, bias about 2^-33. For soundness this is only a (1 + 2^-33)^4
  factor, but two squeezes (128 bits per coordinate, bias 2^-97) or rejection sampling keep the documented style.
- `challenge_indices` (`transcript.rs:135-148`) is unchanged.

**Absorb lengths and the D19 length guard.**
- An Fp4 element stays 16 bytes. So `sc-round` keeps `56 + 16(d + 1)` (`shape.rs:2529`).
- `absorb_fp` drops from 8 to 4 bytes per word. That moves lengths in the hash-length guard
  (`hash_domain.rs`, `hash_domain_tests.rs`), and D19's length-separation reading (`ZK60_DECISIONS.md:46`) must be
  rechecked. Tagged profiles (D19a) make this a re-check, not a redesign.

### 3.3 LogUp soundness [COMPUTED]

The review's accounting is (N + 4·T_d − 1)/|F| per block, with T_d = 127,668 (`REVIEW_W16_20261101.md:32-57`).

| field (challenges) | \|F\| | W16 N = 2^25.06 | 31-bit design N = 2^26.38 |
|---|---:|---|---|
| Goldilocks Fp2 (today) | 2^128 | 2^-102.92 / block, 2^-97.92 / 32-block run | (2^-101.61 / 2^-96.61) |
| BabyBear Fp4 (x^4 − 11) | 2^123.63 | 2^-98.55 / 2^-93.55 | **2^-97.24 / 2^-92.24** |
| M31, QM31 | 2^124.0 | 2^-98.92 / 2^-93.92 | 2^-97.61 / 2^-92.61 |
| BabyBear Fp4, 8B T512 (N about 2^28.5, rough) | | | 2^-95.1 / **2^-90.1** |

- **D27** (`ZK60_DECISIONS.md:56`) accepts about 95 bits whole-run at 8B T512 for the MVP, with 100 as the next
  milestone. A degree-4 extension misses 95 by about 5 bits.
- **Ways back:**
  - draw α, β, γ from a degree-8 extension: helpers become 8 base words, doubling `H` again;
  - repeat the lookup argument: helpers ×2;
  - LogUp-GKR: helpers are never committed, so a large challenge field costs only GKR-round arithmetic. This is the
    route D27 already names for 100 bits.
- An external data point from the explorer's notes, not verified by me: TensorZKP runs BabyBear with a
  **degree-8** extension (`research/zkp-efficiency/experiments/grouped-down-schedule-20261004/snapshots/FINDINGS.md:19`).
- **The tag-fold and table-pole terms** move from 2^-110.0 and 2^-111.0 to 2^-105.7 and 2^-106.7 per block.
- **The characteristic condition** N < p holds (§1, row 25).

### 3.4 Sumcheck and batching

- Per round the bound is d/|F|. About 24 slots × ≤ 27 rounds × degree ≤ 6 gives about 2^-112 per block in Fp4,
  against about 2^-116 today: negligible.
- Batching and zero-check eq terms are (#clauses)/|F|: negligible.
- The new carry clauses add clauses but no new rounds. Digit products, as in the norm and the product, stay within
  today's declared degrees; the slot-IR degree tests would confirm this.

### 3.5 Zero-knowledge: everything that assumed a degree-2 extension or 64-bit words

**Mask pairs become mask quadruples.**
- Each claim site owns a reserved *pair* of base-field rows, read as `R_re + u·R_im`, so the mask is uniform in Fp2
  (`layout.rs:21`; `argument.rs:64-65, :706-740`).
- An Fp4 combination needs four rows. One base-field row hides only one Fp-line of an Fp4 value, so the other three
  coordinates would leak.
- `A` mask and proximity rows double, and every new claim site costs 4 rows.

**`H` helpers are stored as (re, im) planes** (`argument.rs:1263-1267`; `shape.rs:2560`, `2 * rows`). They become
four coordinate planes, and the `H` opening claims change with them.

**CFS masks.** "A Gamma spans two rows" (`zk.rs:393`), with re and im encoded separately (`zk.rs:622-623, :666-667`).
These become four rows; `MASK_LOG_DOM` and `MASK_Q` (`zk.rs:373-375`) are otherwise unchanged.

**Hidden endpoints.** Each has five reserved rows: a terminal pair, a proximity row and two random rows
(`endpoint_g.rs:10-14`; `protocol.rs:328-350`). The terminal pair becomes a terminal quadruple.

**Generator.** It draws 128 bits reduced mod p (`rng.rs:82-86`). For a 31-bit p the bias falls to about 2^-97 per
element. It is still a statistical term, so the privacy statements' generator assumption (E-1 / X-1 in D33) must be
re-stated for the new sampler.

**Privacy residual terms change.**
- The refusal residuals currently divide by p² (D30 condition 4, D34). They become /|Fp4|, about 4.4 bits weaker.
  That is still far below the statements' about 2^-70.
- The rank lemma, NL-1 and the joint-view passes (D33's gate machinery) were built for pairs. They must be re-run
  for quadruples.

**New private planes for the privacy statement.**
- The digit histograms of the new range families are finer statistics of the hidden accumulators than anything
  committed today. The privacy statement must list them, as the W16 review already asked for the 16-bit histograms
  (`REVIEW_W16_20261101.md:184-192`).
- So D1 is unaffected in principle, but the plane list and every privacy statement change.

### 3.6 Hashing (BLAKE3)

- **Leaves.** BLAKE3 over little-endian column bytes (`pcs.rs:141-205`) works unchanged over 4-byte words.
  - `A` columns halve in bytes per row but gain 2.5× rows, so `A` hashing comes to about ×1.27 bytes.
  - `H` comes to about ×2.26 bytes.
  - Hashing does not get the 3.5× arithmetic gain; it scales with bytes.
- **The device path.** The M11 lazy u128 row fold assumes 64-bit words (`README.md:788-795`) and would be
  rewritten, probably simpler, with u64 accumulators.

### 3.7 What is generic over the field, and what is hard-coded

**Nothing in the code is generic over the field.**
- `Fp` and `Fp2` are concrete structs (`zkp-core/src/field.rs:20, :133`), re-exported to hashline
  (`hashline/src/field.rs:2`). No `Field` trait exists.
- The seams that do exist abstract other things, over these concrete types:
  - the PCS device seam (`zkp-core/src/pcs/backend.rs`, `Backend`);
  - sumcheck round providers (`zkp-core/src/sumcheck/rounds.rs:90`, `grouped.rs:59`), typed on Fp2.

[COUNTED, by script over the source tree]:

| piece | evidence | field-specific? |
|---|---|---|
| base field arithmetic, constants, reduction | `field.rs:10-16, :97-111` (P, EPSILON, GENERATOR 7, NONRESIDUE 7, TWO_ADICITY 32) | Goldilocks only |
| extension | `field.rs:133-204` (u² = 7, `inv` via the norm, 16-byte `to_bytes`) | degree 2 only |
| uses | 118 files use Fp or Fp2: about 3,430 `Fp2` and 1,720 `Fp` references (zkp-core 22 files / 7.0 k lines; hashline 190 files / 132.6 k lines, 43.7 k of them in test files) | — |
| degree-2 idioms | `Fp2::U` 91 uses, `.c0`/`.c1` 308 uses, mask pairs, (re, im) helper planes, two-row Gamma | degree 2 only |
| GPU | `metal_kernels.metal` (863 lines, 18 kernels; Goldilocks constants and reduction at :14-60), `metal.rs` (2,119 lines), `kernels.cu` (1,643), device slot IR (`slot_ir.rs`, `slot_ir_accuracy.rs`, about 178 KB) | Goldilocks / Fp2 only |
| no-wrap premises | `layout.rs:762-828` ("no term wraps the 64-bit field"), `NOWRAP_DERIVATION.md` §4, `token_io.rs:468-470` (compares against `u128::from(P)`) | written for p ≈ 2^64 |
| the one degree parameter | `token_io.rs:177-179` `Tier::lookup_ext_degree`, refused unless 2 (`:206-208`) | parameterised, unbuilt |
| **portable today** | lookups carry **integer** linear forms (`layout.rs:729-745`; converted with `Fp::from_i64` at `argument.rs:1399`); witnesses are i64/i128 integers (`witness_accuracy.rs`); the integer reference kernels (`private-block-kernel*`) | field-agnostic |

### 3.8 Memory and receipts

- The committed bytes grow by about 1.27× for `A` and 2.26× for `H`. On top of today's per-proof footprint, that
  narrows how many concurrent proofs fit, which matters for the D55/M10 concurrency path.
- Column openings carry every row, so the receipt grows about 1.5-2× [ESTIMATE].

## 4. Effort, risk, choice of field, and smaller first steps

### 4.1 Effort [ESTIMATE, focused agent-lane weeks]

| step | files and crates | weeks |
|---|---|---:|
| E1: field-generic refactor, Goldilocks byte-identical, with extension degree as a parameter (masks k rows, helpers k coordinates, CFS rows, wire sizes) | zkp-core (field, ntt, merkle, mle, pcs, sumcheck, transcript, rng); hashline `zk.rs`, `pcs*.rs`, `private_block/{argument,protocol,layout,shape,wire,run*,token_io,endpoint_g,boundary}.rs`; Metal and CUDA | 3-5 |
| E2: BabyBear + Fp4 (x^4 − 11) on CPU and Metal, Montgomery, canonical serialisation, NTT, coset; benchmark Fp4 on Metal (M18 measured only QM31) | `field.rs`, `ntt.rs`, `gpu/metal_kernels.metal`, `gpu/metal.rs` | 1-2 |
| E3: relation redesign for rows 1-16 (digits, carries, gate unfold, ACT table, norm), plane lists, pad rules, range families, witness, device IR | `accuracy_layout.rs`, `argument_accuracy.rs`, `argument.rs` (matmul, SS/SSM/TZC slots), `shape.rs`, `pad.rs`, `range16.rs`, `witness_accuracy.rs`, `slot_ir_accuracy.rs`, `accuracy_aligned.rs`/`accuracy_tables.rs` | 4-8 |
| E4: new no-wrap derivation and exact checker (as `NOWRAP_DERIVATION.md` + `nowrap_check.py`) over the class corners; class rulings (wrho_s ≤ 17, gate shifts, Cn) | results/ | 1-2 |
| E5: security accounting in Fp4; LogUp-GKR (with masked layers for ZK), or a degree-8 lookup field, to meet D27 | new | 3-6 (GKR) |
| E6: privacy re-derivation for 4-row masks and the new histograms; gate rounds | results/, privacy statements | 3-6 |
| E7: goldens, CPU/Metal identity, malicious controls, independent D24-class review | tests | 2-4 |
| **total** | | **about 17-33 weeks of lane work: 3-6 months calendar with parallel lanes** |

**What would be redone.**
- Every digest and golden of the new profile: the trained digests, the W16 digests (`c5e0bdac…`), the golden chain,
  the slot-IR export digests and the token fixtures.
- Old profiles stay byte-identical only if E1 keeps Goldilocks byte-identical and the 31-bit field ships as an
  opt-in profile, per the D54 convention.
- The zkp-core field, NTT and PCS conformance tests pin Goldilocks constants (`field.rs:296-306`) and would be
  duplicated for the new field.
- The `hash_domain` length tests.
- A D24-class soundness review of about 15 new relations, the LogUp recount and the PCS.
- The privacy gate rounds.
- New rulings: D56 itself, the D27 tier, the class narrowings and the per-position remainder widths.

**Risk: high.** The change touches every soundness and privacy argument at once. The no-wrap margins of the new
clauses are thin: several sit at 2^30.0-2^30.1 against p = 2^30.9. And the speed model says the work does not pay
for itself for this arithmetic.

### 4.2 BabyBear or Mersenne-31

**BabyBear (or KoalaBear) for this code base.**
- The PCS is a systematic RS code on multiplicative subgroups with coset hiding (`pcs.rs:557-569`). BabyBear
  (two-adicity 27) keeps it with new constants.
- Mersenne-31 has two-adicity 1. It needs circle-group codes and a circle FFT, plus a re-proof of the ZK encoding.
  That is more code and more review for +10% multiply speed (576 vs 522 G/s) and 0.09 bits of headroom, which
  changes no row of §1.
- KoalaBear (p = 2^31 − 2^24 + 1 ≈ 2^30.98, two-adicity 24) has the same structure with slightly more headroom. It
  is unmeasured here.
- BabyBear's quartic extension (x^4 − 11) must be benchmarked on Metal before any decision; M18 measured only QM31.

### 4.3 Is there a smaller first step?

**Committing in a 31-bit field while the IOP stays in Goldilocks is not sound.** The PCS proves F_BB-linear facts
(MLE evaluations mod p_BB at F_BB-extension points). The IOP needs evaluations of the same integer vectors over
Goldilocks.
- Neither field is a subfield of the other, so no opening transfers.
- Binius-style "small-field data in a big-field PCS" works only for subfields or towers.
- A bridge would need a cross-field consistency argument for committed vectors. That is research-grade, and nothing
  in the repo provides it.
- A separate BabyBear sub-proof for one stage has the same problem: the boundary planes would have to be bound in
  both fields.

**Sound, useful first steps, none of which needs a ruling to start:**
1. **E1 on its own:** make the core generic over (base, extension, degree) with Goldilocks byte-identical. This is
   pure refactoring, checked by the existing goldens. It also enables any later field experiment.
2. **LogUp-GKR in Goldilocks** (DESIGN.md lever 4; D27's 100-bit path). It is worth about ×1.1-1.2 on its own. It
   is also the precondition for any small field to pay off: it removes `H`, the part a degree-4 extension makes 4×
   larger in elements.
3. **A census, CPU only:** a `count.py`-style exact count of the 31-bit layout at W16 8B T128 and T512 from a draft
   plane list. It turns this note's [ESTIMATE] into [COUNTED] before any build.
4. **The missing benchmark:** BabyBear Fp4 multiplies and NTT on Metal, beside M18.
5. **Only if the census and benchmark beat Goldilocks + GKR:** a 31-bit profile at the development rung, then 8B.
   - The rung's narrow widths (384 / 768) do not exercise 8B's widest relations, so its numbers would mislead on
     their own.

**Recommendation.** Record D56 as "not now". On the counted cost side, the 31-bit field costs more than it saves for
bit-exact R13/W16 arithmetic. The levers that remain:
- Goldilocks + LogUp-GKR, which needs a ZK design and a ruling;
- D55 concurrency, which needs a ruling;
- non-power-of-two domains, a small gain at 8B.

Revisit D56 only if either:
- LogUp-GKR is built and the census plus a BabyBear-Fp4 benchmark show a net gain over Goldilocks + GKR; or
- a fidelity study admits narrower accumulators: activations and multipliers that keep matmul sums below about
  2^29. That is a D32 question.

## 5. What I could not determine

- **The actual Llama-3-8B calibration constants.** The norm Cn/Ceps, the per-channel multipliers and the per-group
  gate shifts are loaded from the export, not stored in the code. All bounds use the code's classes plus the shift
  set matching the logged W16 families. A calibration well inside the classes could save one digit at a few sites
  only if the classes were narrowed by ruling.
- **Whether the per-channel gate shifts at 8B stay ≤ 22**, which the unfolded gate gadget assumes.
- **The exact claim-site count of the new layout**, and so the exact mask-row count. I used one site per new plane,
  four rows each.
- **BabyBear-Fp4 speed on Metal.** QM31 was used as a stand-in.
- **The real cost of LogUp-GKR.** I used DESIGN.md's 0.05-0.08 s estimate and scaled it.
- **Whether a cleverer construction** (different cuts, shared digits across Q/K/V outputs, GKR-style range
  arguments) beats about 5 digits per two-digit output by more than the about 20% I allowed.
- **The token stage** (final norm, head, keyed argmax) is outside the W16 block and was inventoried only at the
  level of its widest relation.

---

## Appendix: the bounds and gadget check (Python, exact integers)

Run with `python3 -I d56_bounds.py`. It prints the §1 table, the §2.2 gadget checks, the §2.3 counts and the §3.3
LogUp figures quoted above. The time model of §2.4 is a separate 40-line scaling of M10's three parts by the counted
tables and bytes, with M18's speedups; its inputs are all stated in §2.4.

```python
from math import log2, ceil
P_GL = 2**64 - 2**32 + 1; P_BB = 15 * 2**27 + 1; P_M31 = 2**31 - 1
b = lambda x: log2(x) if x > 0 else float('-inf')
I16, W8 = 2**15, 127
d, qw, f_true, f_pad, hd, T = 4096, 4096, 14336, 16384, 128, 128
m_bits = dict(q=5, k=5, v=6, o=8, g=6, u=4, d=6); m_gate_folded = 2**14
sh = dict(q=15, k=15, v=16, score=18, pv=12, ao=21, gate=18, up=12, down=20, prod=16)
f_e, F_P, H24 = 9, 12, 2**23
A_STD, A_SHD = 32767 * 2**15, 32767 * 2**16
CN_MAX, TN1, CEPS_MAX = 2**20, 1, 2**40
D_MAX = int((CEPS_MAX + d * I16 * I16) ** 0.5); D_LIMB = 2**24 - 1
rows = []
def rel(name, pos, neg): rows.append((name, max(pos, neg)))
def mm(name, n, x, m, s, qmax):
    acc = n * W8 * x * m; lhs = 2**s * qmax + 2**s; rel(name, acc + lhs, acc + lhs)
mm("Q", d, I16, 2**5, 15, I16); mm("K", d, I16, 2**5, 15, I16); mm("V", d, I16, 2**6, 16, I16)
mm("Wo", qw, I16, 2**8, 21, I16); mm("gate folded", d, I16, 2**14, 18, 2048)
mm("up", d, I16, 2**4, 12, I16); mm("down", f_true, H24, 2**6, 20, I16)
acc = hd * I16 * I16; rel("score", acc + 2**18 * 128, acc + 2**18 * 127)
rel("PV naive", T * (2**13 - 1) * I16 + 2**12 * I16 + 2**12, 0)
rel("PV derived", 2**F_P * I16 + 2**12 * I16 + 2**12, 0)
rel("product f0", A_STD * I16 + 2**16 * H24 + 2**15, 0)
gx = 128 * I16 * 2 * CN_MAX; dy = 2**(TN1 + 1) * D_LIMB * I16
rel("norm c0", gx + 2**TN1 * D_LIMB, dy + 2**24 + gx)
rel("norm c1", 2**25, 2**(TN1 + 1) * D_LIMB)
rel("SS/TZC host", d * I16 * I16 + CEPS_MAX, D_LIMB**2 + 2 * D_LIMB); rel("TZC dsq-D^2", D_LIMB**2, 0)
rel("RoPE", 2 * 128 * I16 + 2**6, 2**7 * I16 + 2**7)
for Tt, ws in [(128, 16), (256, 17), (512, 18)]:
    rel(f"softmax c2 T{Tt}", 2**f_e * 2**F_P, (2**13 - 1) * Tt * 2**f_e + 2**ws - 1)
for name, m in rows:
    print(f"{name:20s} 2^{b(m):6.2f}  BB {'ok' if m < P_BB else '--'}  M31 {'ok' if m < P_M31 else '--'}")

def check(name, pos, neg):
    m = max(pos, neg); print(f"  {name:60s} 2^{b(m):6.3f} {'ok' if m < P_BB else 'WRAPS'}"); return m < P_BB
def gadget(name, n, K, mb, s, cuts, qbits):
    # acc = sum 2^{8k} P_k ; P_k = L_k + 2^{c_k} H_k ; 8k + c_k >= s ;
    # R_lo: m sum 2^{8k} L_k + 2^{s-1} = 2^s q' + r ;  R_hi: q = m sum 2^{8k+c_k-s} H_k + q'
    Pmax = [n * W8 * 255] * (K - 1) + [n * W8 * 128]; m = 2**mb
    assert all(2 * P < P_BB for P in Pmax) and all(8*k + cuts[k] >= s for k in range(K))
    LOW = sum(2**(8*k) * (2**cuts[k] - 1) for k in range(K))
    Hmax = [ceil(Pmax[k] / 2**cuts[k]) + 1 for k in range(K)]
    HIGHw = sum(2**(8*k + cuts[k] - s) * Hmax[k] for k in range(K))
    qp = (m * LOW + 2**(s - 1)) // 2**s + 1
    ok = check(f"{name} R_lo", m * LOW + 2**(s - 1), 2**s * qp + 2**s)
    ok &= check(f"{name} R_hi", m * HIGHw + qp, 2**(qbits - 1) + m * HIGHw)
    for k in range(K):
        ok &= check(f"{name} hosting P_{k}", Pmax[k] + 2**cuts[k] * Hmax[k], Pmax[k] + 2**cuts[k])
    pieces = sum(ceil(cuts[k] / 16) + ceil(b(2 * Hmax[k]) / 16) for k in range(K)) + ceil(b(qp) / 16)
    return ok, pieces
for cfg in [("Q", d, 2, 5, 15, [15, 16], 16), ("V", d, 2, 6, 16, [16, 16], 16),
            ("Wo", qw, 2, 8, 21, [21, 13], 16), ("gate unfolded", d, 2, 6, 22, [22, 14], 12),
            ("up", d, 2, 4, 12, [12, 12], 16), ("down", f_pad, 3, 6, 20, [20, 15, 7], 16)]:
    print(cfg[0], gadget(*cfg))   # -> Q 5, V 5, Wo 6, gate 6, up 5, down 9 planes (= lookups) per output

Td = 127_668
for name, F in [("GL Fp2", P_GL**2), ("BB Fp4", P_BB**4), ("M31^4", P_M31**4)]:
    for N in (34_897_920, 34_897_920 + 52_297_728):
        e = (N + 4 * Td - 1) / F
        print(f"LogUp {name} N=2^{b(N):.2f}: block 2^{b(e):.2f}, 32-block run 2^{b(32 * e):.2f}")
```
