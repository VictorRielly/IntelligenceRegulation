# Shieldstral-1.0-3B: what a proof costs, and the split-width option (native R12)

Native lane, round 12, 2026-10-21. This is the round's task 5 plus the
multimodal lane's two questions. **Counting and modelling only.** It is **not a
soundness or privacy acceptance**.

Labels:
- **[COUNTED]**: exact, from the layout. Two independent paths agree:
  - the R10 replica of R9's counting (`../r10/r10_weight_range_cost.py`), whose
    anchor reproduces every size the R9 prover printed;
  - the Rust layout's own totals for the registered profiles, printed by
    `r12_tests::f2_the_shieldstral_shapes_build_and_lay_out`.
  `r12_cost.py` checks that they are equal.
- **[MEASURED]**: one run on a shared box, n=1.
- **[MODEL]**: an estimate, explained where it is used.

Script and outputs: `r12_cost.py`, `r12_cost.json`.

## 1. The padding facts [COUNTED]

Shieldstral's text decoder has four axes that matter here:
- the model axis, d = 3072;
- the query axis, 32 × 128 = 4096 (decoupled from d / heads; this is F2);
- the key-value axis, 8 × 128 = 1024;
- the feed-forward axis, 9216.

The layout pads every axis to a power of two:

| axis | true width | padded | padding |
|---|---|---|---|
| model (`Dom::D`) | 3072 | 4096 | 25% |
| query (`Dom::Q`) | 4096 | 4096 | none |
| key-value (`Dom::Kv`) | 1024 | 1024 | none |
| feed-forward (`Dom::F`) | 9216 | 16384 | 43.75% |
| scores (`Dom::S`) | 32 × T × T | same | none |

Llama-3-8B's padded widths are the same: 4096, 4096, 1024 and 16384 (from
14336).

**So the multimodal lane is right.** At the same T and row width:
- A Shieldstral block has exactly the committed elements and the byte lookups
  of a Llama-3-8B block.
- Its zero-check work is about 0.5% higher, because its model axis pads and
  that adds one support table.
- The parts that differ do not change the counts: the norm window is
  tn 10 + 1 + 21 = 32 bits (four limbs), and Shieldstral has 26 layers to
  8B's 32.

## 2. Cost per block and per proof

Each row is one block, against Llama-3-8B at the same T and row width:

| T (row width) | DD | committed elements | byte lookups | zero-check element-terms | 8B committed |
|---|---|---|---|---|---|
| 128 (2^14) | no | 117,882,880 | 51,937,280 | 218,364,160 | equal |
| 128 (2^14) | yes | 113,328,128 | 48,398,336 | 212,334,848 | equal |
| 256 (2^15) | no | 272,662,528 | 121,700,352 | 509,952,512 | equal |
| 256 (2^15) | yes | 241,532,928 | 101,515,264 | 465,912,320 | equal |
| 512 (2^15, counted only) | no | 663,257,088 | 306,249,728 | 1,286,984,704 | equal |
| 512 (2^15, counted only) | yes | 525,172,736 | 219,742,208 | 1,089,852,416 | equal |

On the row widths:
- The registered row widths follow task 3's rule (the smallest counted
  receipt), counted by
  `r12_tests::the_shieldstral_row_widths_are_the_smallest_counted_receipts`.
- **T128 is at 2^14:** 29,301,816 B per block.
- **T256 is at 2^15:** 45,011,240 B, against 48,025,704 at 2^14. The cost is
  2.3% more committed elements.
- **T512 is not registered.** It is counted at 2^15, the review's anchor
  width.

**Prove time and memory [MODEL].**

| T | DD | argument s/block | witness/load s/block | 26 blocks | peak memory |
|---|---|---|---|---|---|
| 128 | no | 8.97 | 1.75 | **279 s** | 6.69 GiB |
| 128 | yes | 8.88 | 1.75 | **277 s** | 6.56 GiB |
| 256 | no | 20.45 | 3.50 | **623 s** | **15.5 GiB** |
| 256 | yes | 18.86 | 3.50 | **582 s** | **14.0 GiB** |
| 512 | no | 49.66 | 7.00 | 1,473 s | 37.6 GiB |
| 512 | yes | 41.47 | 7.00 | 1,260 s | 30.4 GiB |

How the model is built:
- **Time** follows R9's convention. Each argument phase uses the measured
  Llama-3-8B T128 cost per unit (R8 run without DD, R9 run with DD) times its
  counted size at Shieldstral's shape.
- **Witness / load** is the 8B T128 measured share of 3.29 s per block, scaled
  by two things:
  - the block's public weight count: 116,391,936 words against 8B's
    218,103,808;
  - T / 128.
- **Peak memory** is the 8B T128 stack-prove peak with the witness cache off
  (6.69 GiB without DD, 6.56 GiB with DD), scaled by committed words per block.
  This is a crude linear model.
- **Measured check:** a single Shieldstral T128 block was proved by
  `f2_a_generic_dense_shieldstral_t128_*` (HL_PB_TIMING). Its numbers are in
  §5.

What this means for memory:
- T128 fits the 15 GiB laptop path.
- **T256 does not**: about 15.5 GiB without DD and 14 GiB with DD, with the
  guard's caps on top. This confirms the multimodal lane's ~14 GiB.
- The token stages, which the token lane builds, add to these figures.

## 3. The split-width layout as a possible R12b [MODEL; paper only, not built]

**The idea.** Do not pad 3072 to 4096 or 9216 to 16384. Lay each model-axis
plane out as two power-of-two pieces, 2048 + 1024, and each feed-forward plane
as 8192 + 1024: two hypercubes per plane, in the same commitments.

**What the model assumes.** Each plane's rows become the sum of its pieces'
rows. Every D / F plane and helper is claimed on both pieces, which is the
main overhead. The zero-checks run over both cubes. The support tables of the
padded axes disappear. The extra matmul sumchecks are not counted; they work on
the inner index, so they are small.

The model gives the saving against the padded R12 layout, as an upper bound:

| T | DD | committed | byte lookups | element-terms | 26-block time [M] | peak [M] |
|---|---|---|---|---|---|---|
| 128 | no | −23.6% | −24.5% | −27.5% | 227 s (from 279) | 5.1 GiB |
| 128 | yes | −24.6% | −26.3% | −28.3% | 224 s (from 277) | 5.0 GiB |
| 256 | no | −20.4% | −20.9% | −23.5% | 519 s (from 623) | **12.3 GiB** |
| 256 | yes | −23.0% | −25.1% | −25.8% | 477 s (from 582) | **10.8 GiB** |
| 512 | no | −17.5% | −16.6% | −18.7% | 1,260 s (from 1,473) | 31.1 GiB |
| 512 | yes | −22.1% | −23.1% | −22.0% | 1,046 s (from 1,260) | 23.7 GiB |

This agrees with the multimodal lane's 18–26%. **It would bring T256 inside the
laptop path.**

**Relations it touches:**
1. **Every `Dom::D` relation:**
   - the two norms (c0 / c1 and c6 / c7);
   - the int16 limb decompositions of x, ao, x1, x2 and z16;
   - the residual adds;
   - the AO and down host clauses;
   - the `Dom::D` LogUp helpers.

   Each runs over two cubes. That means either two sumchecks, or one sumcheck
   over a 4096 cube whose second half is a 1024-wide piece with a public
   selector. The second form is the pad rule again, in another guise, and
   saves nothing. So it must be two cubes.
2. **The row sums** (`SC_SS`, `SC_SSM`) sum over both pieces, so the norm's
   denominator is the sum of two sub-sums.
3. **The model-axis matmuls:**
   - the inner index of Q / K / V, gate and up;
   - the output index of WO and down.

   Each becomes a sum over two inner cubes, or two output claims. The matmul
   families' separate widths (M-2) multiply.
4. **The feed-forward relations** (`SC_FZC`: the activation lookup, the
   product and its remainder, the int16 limbs) over 8192 + 1024, with the down
   projection's inner sum split.
5. **The endpoints and boundaries.** They commit the `Dom::D` plane (D12 /
   D12a: one boundary commitment per internal plane, opened once). That plane
   becomes two pieces, so its geometry, row counts, claim sites and
   opening-place rules change.
6. **The P-3 lift and B-3's single value-0 LogUp sum claim.** The H planes
   then have two piece sizes. Both are at or above the row width at T ≥ 128,
   so the single key holds, but this must be re-shown.
7. **The pad rule** (S9 / §3.7a) becomes vacuous on D and F. That is a
   simplification, but the indicator machinery's absence must be argued, not
   assumed.

**Soundness and privacy re-reads it would owe:**
- D24 (layout, windows, plane list, no-wrap: sums over 3072 / 9216 instead of
  4096 / 16384 only shrink the bounds);
- D12 / D12a (endpoint and boundary geometry);
- the CFS claim-site and functional schedule;
- D30 (DD is on `Dom::S` and does not move, but its lookup term's N changes);
- D27's floor (it only gains, from fewer lookups);
- privacy: the rank lemma, NL-1 and joint-view gates on new captures, under a
  new profile.

**Recommendation.**
- Worth building as R12b if T256 must fit the laptop CPU path.
- At T128 it is a ~19% time saving that the public-prefix reuse (F6) may
  overtake.
- It is independent of F6, and the two compose.

## 4. n_col against the DD cap, and the counted floors [COUNTED]

**n_col.** The exp table depends on `e_s`, `head_dim` and `f_e` only, so
Shieldstral (head_dim 128) has Llama-3-8B's n_col for every `e_s`.
- `r12_tests::n_col_against_the_dd_cap_at_head_dim_128` prints the full table
  for f_e 9–12 and every `e_s` in the declared class.
- The current exports' `e_s` 1–4 at f_e 9 fit cap 32.
- A real Shieldstral export's tables come from the calibration lane. The
  trained door refuses one over the cap by name, as in R9.

**Counted soundness floors.**
- Method: the token lane's MEMO_G02 accounting, restricted to the 26 blocks and
  27 boundaries, plus D30 (5)'s dictionary term at the DD profiles.
- `r12_tests::counted_soundness_floors` asserts at least 95 bits (D27) at every
  Shieldstral profile and prints each figure.
- The D24 review re-derives them.

## 5. Measured

The single-block Shieldstral T128 proofs are run by the R12 chain (stage 3)
with HL_PB_TIMING:
- non-DD and DD;
- generic dense witness, checked against the independent kernel;
- a one-byte segment flip refused.

The freeze note records their per-block prove seconds and peak memory beside
the model above.
