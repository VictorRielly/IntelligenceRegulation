# M4 Activation Design: SiLU as a Declared Piecewise Fixed-Point Gadget Chain

Status: design + reference implementation COMPLETE (this tranche); no
Rust changes. Every number in this document is computed by
`scripts/silu_piecewise.py` (runnable standalone, pure stdlib, ~2 s;
captured output: `results/m4_silu_error.txt`); nothing is
hand-computed. Companions: TRANSFORMER_PROOF_PLAN.md Section 2 Class 3
(the M4 decision context), M2_REPORT.md/M3_REPORT.md (the gadget-cost
findings this extends), GADGET_MODULUS_DECISION.md (the q46 gadget
layer + modulus link this compiles onto), SOUNDNESS_REFERENCE.md
Sections 4.3-4.7 and 6 (the claim families and their grades).

Grading follows the soundness reference's legend: **[PROVEN]** /
**[MODEL]** / **[OBLIGATION]**.

**The two headline results, stated up front and honestly:**

1. SiLU (`x * sigmoid(x)`, Llama's FFN gate activation) **compiles
   entirely to the existing gadget set** — dense binary/range claims at
   q46, the cross-modulus link, one H3 slot-Hadamard product, and
   Class-0 algebra — as a *declared* piecewise fixed-point function.
   The recommended operating point (int8 in/out, K = 32 segments,
   degree 1, Pe = 6) has max approximation error 0.0068 vs float SiLU
   (out half-ulp 0.031) and is at most 1 output ulp from the ideal
   int8-quantized SiLU on every one of the 256 inputs. Completeness of
   the composed claim chain is checked by enumeration over the full
   input grid.
2. **The cost is bad, and the reason is structural.** The compilation
   adds ~105 committed element-equivalents per activation element
   (64 of them from slot-packed tensors at the H3 16x density penalty,
   41 from q46 bit planes). On the 7B/512 reference pass that is
   **+201% of today's entire commit bill** (+193-242 s at 22T,
   +15-18 s GPU, +108 GB commit stream). The Class-3 "<20% of the
   matmul layer" criterion is missed by ~1.5 orders of magnitude —
   ~8,000x better than Route Z's M2 measurement per element, but still
   far outside budget. This document therefore doubles as the
   quantified case for the lookup-argument primitive (Section 8): the
   piecewise route is the *buildable interim*, not the destination.

## 1. The statement: what the proof certifies

The proof certifies membership in the M3-style quantized-spec
statement, extended with one declared nonlinearity:

> The committed tensor `Y` satisfies, elementwise over the integers,
> `Y[t] = PW[x -> y](X[t])`, where `PW` is the exact integer function
> pinned by the **activation spec header** below, and `X` is the
> committed, range-proved input tensor.

There is no claim that `PW` equals real SiLU — the approximation error
is a *model-quality* statement (Section 3 quantifies it), exactly as
TRANSFORMER_PROOF_PLAN.md Section 1 requires: the quantized spec is the
ground truth, and the published claim must say "this declared quantized
activation," never "SiLU."

### 1.1 The activation spec header (statement declaration format)

The spec header is a canonical JSON document; its SHA-256 digest enters
the claim manifest (and therefore every Fiat-Shamir challenge via
`ctx`), closing M3 gap 5 for this operation:

    {
      "function": "silu-piecewise-fixedpoint-v1",
      "input":  { "width": W_in,  "frac_bits": F_in,  "signed": true },
      "output": { "width": W_out, "frac_bits": F_out, "signed": true },
      "segments": K, "seg_shift": wseg, "degree": d, "pe": Pe,
      "rounding": "y = floor((y_raw + 2^(s-1)) / 2^s), s = Pe + F_in - F_out",
      "table": [[A_0, B_0, ...], ..., [A_{K-1}, B_{K-1}, ...]]
    }

Semantics (all exact integer arithmetic; this *is* the function, not a
description of one):

    tau   = x_int + 2^(W_in - 1)          // shifted domain, [0, 2^W_in)
    j     = tau >> wseg                    // segment index, K = 2^(W_in - wseg)
    u     = tau - j * 2^wseg               // local variable, [0, 2^wseg)
    y_raw = A_j + B_j*u (+ C_j*u^2)        // scale 2^-(F_in + Pe)
    y_int = (y_raw + 2^(s-1)) >> s         // s = Pe + F_in - F_out (arith. shift)

Values outside the input grid are out of scope: the upstream rescale's
range proof pins `x_int` to `[-2^(W_in-1), 2^(W_in-1))`, and the
declared quantization clamp (standard in int8 inference) is part of the
*upstream* spec. Recommended-point digest (K = 32, deg 1, Pe = 6,
int8 -> int8):

    49eb999930fda5060a7d3d94d9f9097ec5309b627e7ebad051404fb96b25d67f

A model spec pins this digest; proofs are not transplantable across
tables (plan Section 3, item 4).

## 2. Why piecewise, and why NOT some alternatives

- **Global polynomial** (no segmentation): SiLU on [-8, 8) needs
  degree ~12-16 for comparable error, and x^12 at the int8 grid is
  ~2^84 — hopelessly outside q31 headroom without per-power rescales,
  each of which costs more than a segment table. Dead on arrival.
- **Sign/|x| split** (the M3 ReLU pattern + a half-domain table, using
  silu(-x) = silu(x) - x, which holds *exactly* on the fixed-point
  grid): saves half the indicator planes but adds a sign bit, a
  committed |x| path, and one extra slot Hadamard (b o x). Net cost is
  slightly WORSE than doubling the segment count, because indicator
  planes are cheap (1 dce) and slot products are expensive (16 dce).
  The recommended design therefore uses signed-direct segments on the
  shifted domain tau and needs NO sign gadget at all.
- **Lookup argument** (zkLLM tlookup / LogUp class): the principled
  answer, a genuinely new primitive for this stack — Section 8.

## 3. The approximation and its error budget

Error budget derivation: the statement's faithfulness target is int8
inference itself. The output grid step is 2^-F_out = 1/16, so output
*quantization* alone contributes up to half-ulp = 0.03125 absolute
error against float SiLU. The budget rule adopted (and encoded in the
harness): **approximation error <= half of the output half-ulp
(0.015625), and the declared function may differ from the ideal
int8-quantized SiLU by at most 1 output ulp.** Then the piecewise
function is quantization-limited, not approximation-limited: it is as
faithful as int8-quantized SiLU is, which is the strongest claim an
int8 statement can support.

Harness sweep (exhaustive over all 256 inputs; full table in
`results/m4_silu_error.txt`), selected rows:

| K | deg | Pe | approx max | approx mean | total max | ulp max | mismatch | dce/el | rule |
|---|---|---|---|---|---|---|---|---|---|
| 8 | 2 | 8 | 0.033447 | 0.003850 | 0.06250 | 1 | 19/256 | 117 | -- |
| 16 | 2 | 8 | 0.006005 | 0.000778 | 0.03346 | 1 | 3/256 | 124 | PASS |
| 32 | 1 | 6 | **0.006836** | **0.000997** | **0.03346** | **1** | **5/256** | **105** | **PASS** |
| 32 | 1 | 10 | 0.006697 | 0.000685 | 0.03223 | 1 | 1/256 | 109 | PASS |
| 32 | 2 | 10 | 0.000287 | 0.000075 | 0.03090 | 0 | 0/256 | 141 | PASS |

**Recommended operating point: W_in = 8/F_in = 4 -> W_out = 8/F_out = 4,
K = 32 uniform segments (0.5 real units wide), degree 1, Pe = 6** —
the cheapest rule-passing configuration at 105 dce/element. The
measured surprise, worth recording: **degree 1 with more segments beats
degree 2 with fewer**, because the marginal cost of a segment is one
q46 bit plane (1 dce) while the marginal cost of a polynomial degree is
two slot-packed q31 tensors (32 dce). The classic approximation-theory
trade (degree vs segments) is inverted by the commitment cost model.

Distribution-shaped pipeline error (100k samples/distribution,
quantize -> declared function vs float SiLU on the real input; the
"baseline" columns are the *ideal* int8-quantized SiLU on the same
quantized input — the floor any int8 statement pays):

| distribution | declared max | declared mean | baseline max | baseline mean |
|---|---|---|---|---|
| uniform[-8,8) | 0.06544 | 0.017810 | 0.06402 | 0.017758 |
| gauss(sigma=0.5) | 0.05970 | 0.017787 | 0.05970 | 0.017630 |
| gauss(sigma=1) | 0.06329 | 0.018766 | 0.06329 | 0.018670 |
| gauss(sigma=2) | 0.37248 | 0.018989 | 0.37248 | 0.018933 |
| gauss(sigma=4) | 9.88131 | 0.052737 | 9.88131 | 0.052695 |

Reading: on every distribution the declared function's error is within
noise of the ideal-int8 baseline (means differ by < 1%). The large max
errors at sigma >= 2 are **input-range clipping** (samples beyond
+/-8), identical for declared and baseline — a property of the int8
input format, not of the approximation; a real deployment declares its
clip range from calibration data exactly as int8 inference does.

Higher-fidelity secondary spec (Q3.8 in -> Q3.8 out, 12-bit): K = 32,
deg 2, Pe = 10 gives approx max 0.0049, ulp max 1, at 145 dce/element —
the piecewise structure scales gracefully in precision (planes grow
linearly, slot tensors not at all), which is its one real advantage
over the exact-table variant (Section 7).

## 4. The gadget compilation, element by element

### 4.1 Packing conventions (the cost-model ground truth)

Two packings exist in the engine, and the entire cost model hangs on
the distinction:

- **Dense packing**: 128 coefficients per ring element. Used by value
  tensors, bit planes, the binary/recomposition/rescale claims, and
  the modulus link. Unit cost 1 dce (dense-coefficient equivalent) per
  value.
- **H3 slot packing**: 8 values per ring element (one per CRT slot,
  `ring_matmul.rs` `slot_pack`). Slot-wise products of slot-constant
  elements are ring products, so a committed elementwise product
  `x o y = z` is ONE untwisted `QuadRingClaim` (soundness reference
  4.4) per packed element — but each slot-packed value costs
  **16 dce** of commitment. Every tensor that participates in a
  committed-x-committed elementwise product must live here.

Bit tensors and their binary claims run at q46 (GADGET_MODULUS_DECISION
option (a)): per-plane one quadratic ct-claim + ARP per <= 512-coeff
unit (the freeze-row granularity cap), grounded into the q31 value
chain by modulus links. The design below is arranged so that the
*number of slot-packed tensors is the minimum the claim algebra
permits* (Section 3's degree-1 finding is a direct consequence).

### 4.2 Committed objects, per gate tensor (n = 512 x 11008 elements)

New q46 bit planes (dense, 1 dce/element each; 41 total at the
recommended point):

| planes | count | role |
|---|---|---|
| `e_0..e_{K-1}` | K = 32 | one-hot segment indicators |
| `ub_0..ub_{wseg-1}` | wseg = 3 | bits of the local variable u |
| `rb_0..rb_{s-1}` | s = Pe = 6 | bits of the output-rescale remainder |

New q31 slot-packed tensors (16 dce/element each; 4 at degree 1):

| tensor | role |
|---|---|
| `u_s` | local variable, slot-packed |
| `A_sel`, `B_sel` | per-element selected segment coefficients |
| `y_raw` | polynomial output before the output rescale |

(Degree 2 adds `C_sel` and the Horner intermediate `w1`: 6 slot
tensors.) Chain-native, NOT charged to SiLU: the input planes
`xb_0..xb_{W_in-1}` (the upstream rescale's range proof) and the
output planes `yb_0..yb_{W_out-1}` (the downstream `gate o up` product
needs the output range-proved under ANY activation).

### 4.3 Placement: which segment, proven entirely at q46

All placement claims are native dense q46 claims over bit planes —
no q31 tensor, no committed segment index `m`, no sign gadget:

- **P-bin**: every new plane is binary — the standard quadratic
  ct-claim + ARP per <= 512-coefficient unit (11,008 units per plane
  at FFN width; the partitioning is exactly the freeze-row rule).
- **P-one** (one-hot): `sum_j e_j = 1~` — one `RingClaim` at q46 with
  constant coefficient 1 on each indicator plane and public constant
  the all-ones vector. Mod-q46 exactness is integer exactness
  (K << q46).
- **P-place**: `sum_i 2^i xb_i + 2^(W_in-1) * 1~ - h * sum_j j*e_j -
  sum_i 2^i ub_i = 0~` — one `RingClaim` at q46 (h = 2^wseg). Every
  quantity is < 2^(W_in+1) << q46/2, so the mod-q46 identity is the
  integer identity
  `tau(t) = h*m(t) + u(t)` with `m(t) := sum_j j e_j(t)`.

**Placement soundness [PROVEN, given the graded inputs]:** P-bin makes
every `e_j(t)` and `ub_i(t)` a 0/1 integer (grade of that step: the
q46 ARP budget, [MODEL] per soundness reference 4.7). P-one then
forces exactly one `e_{j*}(t)` = 1, so `m(t) = j*` in `[0, K)`; the
`ub` recomposition bounds `u(t)` in `[0, h)`; P-place pins
`tau(t) = h j* + u(t)`, i.e. `j*` is the true segment of `tau(t)` and
`u(t)` its true offset — uniquely, since `[jh, (j+1)h)` partitions the
domain. A wrong `j*` forces `u` outside `[0, h)` (caught by its
planes); a wrong `u` breaks P-place.

### 4.4 Coefficient selection: modulus links with table-weight maps

`A_sel(t) = sum_j A_j e_j(t)` is a *public-integer-weighted* sum of
committed, binary-proven q46 planes — exactly the modulus-link
interface (GADGET_MODULUS_DECISION Section 3.5) with `map` = the
declared coefficient table instead of `2^i`:

    L_A: LINK(gnd = (q46, e-planes, binary proofs), tgt = (q31, A_sel),
              map = weights A_j on plane j, w, l = ceil(256/w))
    L_B: same with weights B_j;  L_u: the u planes with weights 2^i.

Because P-one forces one-hot indicators, the grounded integer is
*exactly* the selected coefficient, and `|A_sel(t)| <= max_j |A_j|`
feeds the link's w_max rule `n * 2^(w-1) * max|map| < q46/2`
(script-checked at full-tensor granularity n = 5,636,096):

| link | max map value | w | rows l |
|---|---|---|---|
| L_u (u planes -> u_s) | 7 | 19 | 14 |
| L_A (e planes -> A_sel) | 7,676 | 9 | 29 |
| L_B (e planes -> B_sel) | 70 | 16 | 16 |
| L_out (y/r planes -> y_raw) | 16,383 | 8 | 32 |

Two deltas against the shipped link (`ring/link.rs`), both flagged in
Section 6: the targets are **slot-packed** (extension E1) and signed
weights appear in the maps (the link's integer accounting, soundness
reference 6.1/6.2, is magnitude-based and unaffected — the w_max rule
uses |map|).

### 4.5 Evaluation: ONE slot Hadamard claim (degree 1)

With `u_s`, `A_sel`, `B_sel` slot-packed and link-grounded, the whole
polynomial evaluation is a single untwisted quadratic ring claim per
packed element at q31 (the H3 gadget, soundness reference 4.4):

    C-eval:   B_sel o u_s + A_sel - y_raw = 0

(Degree 2, Horner: `H1: w1 = C_sel o u_s + B_sel`,
`H2: y_raw = w1 o u_s + A_sel` — two claims, two more slot tensors.)
Integer non-wrap at the recommended table [script-asserted]:
`|y_raw| <= max_j (|A_j| + |B_j|*(h-1)) = 8,124 < 2^13 << q31/2`, so
the per-slot mod-q31 identity is the integer identity.

### 4.6 Output rescale: link-grounded rounding

The declared rounding `y_int = (y_raw + 2^(s-1)) >> s` becomes the
integer identity (offset output code `y_code = y_int + 2^(W_out-1)`):

    y_raw + 2^(s-1) + 2^s * 2^(W_out-1)  =  2^s * y_code + r_out,
    r_out in [0, 2^s),  y_code in [0, 2^W_out)

proven by ONE link `L_out` with grounding = {output planes `yb_i`
(weights `2^(s+i)`), remainder planes `rb_i` (weights `2^i`)} and
target `y_raw` (the public constants fold into the link's q31-side
functional — Class-0). No separate rescale claim, no committed `y_out`
value tensor, no committed `r_out` value tensor: the planes ARE the
range proofs, and the link IS the recomposition — the same fusion the
F3 link already performs for plain ranges.

### 4.7 The claim DAG, assembled

    x (q31 chain) --[upstream rescale, baseline]--> xb planes (q46)
      |
      |   e planes (q46): P-bin, P-one     ub planes (q46): P-bin
      |         \                 |            /
      |          +---- P-place (q46 RingClaim) ----+        [Sec 4.3]
      |
      |   L_u:  ub -> u_s (slot q31)                        [Sec 4.4]
      |   L_A:  e  -> A_sel (slot q31)
      |   L_B:  e  -> B_sel (slot q31)
      |
      |   C-eval: B_sel o u_s + A_sel = y_raw (QuadRingClaim, q31)
      |
      |   L_out: {yb, rb planes} -> y_raw  (rounding identity)
      v
    yb planes ground y (q31 chain, offset code) --> gate o up (chain)

Transcript discipline: all commitments (planes, slot tensors) enter
the statement hash before any challenge; each link's xi rows derive
from an h0_link binding BOTH sides including g-masks; binary-claim
theta randomizers are post-mask (F5 rule). New rows for the Section 7
ordering audit: the xi draws of L_u/L_A/L_B/L_out (attack if violated:
choose coefficients after xi — per-row 2^-w becomes 1; pinned by the
same `stale h0_link` negative pattern as U-L4).

## 5. The cost model (the honest headline)

Units: **dce** = dense q31-coefficient element-equivalents (the
LLM_SCALE accounting unit); one slot-packed value = 16 dce; one q46
plane coefficient = 1 dce for CPU-commit purposes but carries x1.38
stream bytes and x2.26 GPU-int8 cost (GADGET_MODULUS_DECISION 3.1).

**Per element (marginal, on top of the baseline chain):** 105 dce =
4 slot tensors x 16 + 41 q46 planes. For scale: a plain matmul output
element costs 1 dce to commit; a range-proved activation element under
the LLM_SCALE assumptions costs ~13 (value + 12 planes). SiLU
multiplies the gate tensor's committed footprint **~9x**.

**Per pass (7B/512: 180M SiLU'd elements, 32 gate tensors of
512 x 11008)** — the script's cost table, against the measured anchors
(commit 96-120 s 22T / 5-6 s GPU per 9.4e9 element-equivalents; the
GPU column applies the q46 x2.26 factor to the plane fraction):

| variant | dce/el | slot | planes | +pass % | commit 22T | GPU | stream | ARP 1T |
|---|---|---|---|---|---|---|---|---|
| A: piecewise K=32 deg=1 (rec) | 105 | 4 | 41 | **+201%** | +193-242 s | +15-18 s | +108 GB | +412 s |
| A2: piecewise K=16 deg=2 Pe=8 | 124 | 6 | 28 | +238% | +228-285 s | +15-18 s | +121 GB | +281 s |
| B: exact one-hot table (2^8) | 256 | 0 | 256 | +491% | +472-589 s | +56-67 s | +315 GB | +2570 s |

Readings, each one honest:

- **Commit bill x3.** +1.89e10 element-equivalents on a 9.4e9 pass.
  The 22T CPU commit goes from 1.6-2.0 min to ~5-6 min; the GPU commit
  row from 10-12 s (F3 option (a)) to ~25-30 s; the projected pass
  from ~20-37 s to roughly **~35-55 s (~5-8x CPU-int8)** — the 15 s/8B
  rung recedes by another ~2x beyond the F3 retreat.
- **The bit-tensor fraction roughly doubles.** 41 planes x 1.8e8 =
  7.4e9 new q46 bit coefficients vs 7.78e9 in the whole baseline pass
  (the 82.8% figure the modulus decision prices). Every q46 cost
  multiplier now lands on ~2x the volume; the +108 GB commit stream is
  the same fact in bytes (streamed, not resident — but real bandwidth).
- **The Class-3 criterion is missed by ~1.5 orders of magnitude.**
  Marginal prover work ~13-14 us/element 1T (commit ~11 us + ARP
  ~2.3 us + links/eval, model-estimated) vs the matmul-claim layer's
  110-330 s 1T over these elements — the gadget family costs ~7-22x
  the ENTIRE matmul layer against a <20% criterion. For calibration:
  Route Z's measured M2 cost was ~108 ms/element — this compilation is
  **~8,000x cheaper per element than Route Z** and still ~35-110x over
  budget. The M2 finding's structure repeats one level up: the floor
  is now the H3 slot density (16x) plus per-element indicator planes,
  not the Sigma-protocol masking.
- Link overhead is noise: 91 rows x ~2.5 KB x 32 tensors ~ 7 MB/pass
  (from the Section 4.4 row counts).
- A fused-gate variant (evaluate `gate o up` on `y_raw` directly at
  internal precision, one rounding after the product — headroom
  2^13 x 2^7 = 2^20 << q31/2) saves the 6 remainder planes and one
  rounding of statement error: ~99 dce/el. A shave, not a rescue;
  recorded, not recommended as the primary.

## 6. Where the existing gadget set is insufficient (flagged loudly)

1. **E1 — slot-packed link targets [BUILT at the machinery level
   (U-E2): `ring/link.rs::link_claims_tgt_slot` reads slot targets
   through the CRT projection rows (`crt_coord_rows`); the
   M4-specific map-weight wiring (u_s/A_sel/B_sel tables) ships with
   whichever M4 variant lands].** The
   shipped link (`ring/link.rs`) targets dense q31 tensors: its
   q31-side row claim uses weights xi_t on coefficient t. Here the
   targets (`u_s`, `A_sel`, `B_sel`, `y_raw`) are slot-packed, so the
   row functional must read the slot-constant coordinate of slot t —
   a PUBLIC linear functional of the 128 coefficients (a CRT
   projection row), composed with xi. This is new weight *computation*
   feeding the same ct-claim machinery (`pack_functional`) with the
   same grounding-side integer accounting (6.1/6.2 untouched — the
   integer bound lives on the q46 side). Build + negative battery
   owed; protocol shape identical to U-L1..L4. Signed map weights
   (the coefficient tables) are a second mechanical delta — the w_max
   rule and the detection argument are magnitude-based already.
2. **E2 — slot-constancy enforcement [BUILT (U-E2): zeta junk rows in
   `link_claims_tgt_slot` + `derive_link_zeta`, pinned by the U-E2
   battery (composed-product shift demonstrated; constant-only-rows
   ACCEPT / zeta-rows REJECT pair) and a freeze row — the chain-wide
   gap below is CLOSED].** H3 packing puts each value at the constant
   coordinate of its CRT slot; nothing in the shipped engine forces a
   committed slot tensor's other 15 slot-field coordinates to zero.
   Slot-field multiplication (GF(q^16)) mixes coordinates, so an
   adversarial `u_s` with correct constants but free junk coordinates
   shifts `y_raw`'s constant coordinates arbitrarily through the
   product claim — a genuine break of any COMPOSED use of the H3
   Hadamard. This is not specific to SiLU: **the Llama chain's own
   `gate o up` elementwise product has the same gap**, and
   `chain-demo`'s Hadamard layer is standalone (never tied to the
   rescale chain), so the gap is currently latent, not exercised.
   Fix, designed here and costed at zero extra rows: extend each E1
   link row's q31-side functional with fresh XOF weights over ALL
   non-constant coordinates of the target (grounding contribution
   zero); a nonzero junk vector survives each row w.p. <= 2^-w — the
   same Schwartz-Zippel accounting as 6.2, in the same rows.
   Intermediates (`w1`, `y_raw`) then inherit slot-constancy from
   claim exactness [PROVEN given pinned operands: GF(q) is closed
   under the slot operations]. The E1+E2 link IS the missing
   dense<->slot "repack" gadget the chain needs anyway.
3. **The lookup argument is still the real M4 primitive.** Nothing
   here removes the plan's Section 2 assessment; Section 9 quantifies
   why this compilation strengthens it.

## 7. Soundness and completeness of the composed chain, graded

| step | claim | grade |
|---|---|---|
| plane binariness | quadratic ct-claims + ARP at q46, n <= 512 units | [MODEL] — the ARP SLACK_OP composition (soundness ref 4.7); freeze rows pin the budget |
| one-hot + placement | P-one/P-place RingClaims, integer-exact (no wrap) | [PROVEN] given binariness (Sec 4.3 argument) |
| coefficient/u/rounding links | per-row 2^-w, l rows to 2^-256; integer exactness via w_max + range gate | [PROVEN] for the dense-target protocol (soundness ref 6.1/6.2); slot-target machinery + negatives [BUILT] (U-E2); the M4 map-weight wiring rides the chosen variant |
| slot-constancy of link targets | junk-coordinate pinning inside link rows | [BUILT] (E2, U-E2 battery + freeze row) |
| evaluation claim | QuadRingClaim extraction, three-transcript | [PROVEN] (soundness ref 4.4); non-wrap bounds script-asserted |
| rounding identity | L_out functional = declared rounding | [PROVEN] arithmetic identity; ranges from planes |
| completeness | every claim relation satisfied by honest witnesses | [PROVEN by enumeration] — `gadget_trace` asserts every relation for all 256 inputs |
| zero-knowledge | garbage-image ZK of quadratic claims | [OBLIGATION] — inherited repo-wide gap (soundness ref 8.1), nothing new added here |
| cost anchors | commit/GPU/stream/ARP projections | [MODEL] — measured anchors, linear scaling |

The composed extraction argument, in one paragraph: extract all
committed planes and slot tensors via the round's [PROVEN] special
soundness; binariness + one-hot + placement pin `(j*, u)(t)` as the
true segment data of the (chain-grounded) input; the links pin each
slot tensor's constant coordinates to the table-selected integers and
(E2) its junk coordinates to zero; C-eval then forces `y_raw(t)` to
the exact integer polynomial value (no wrap); L_out forces the
grounded output code to the declared rounding of `y_raw(t)`. Every
step is exact over Z once its side conditions hold; the failure
probabilities are the per-gadget ones (ARP budget, 2^-w*l link rows,
2^-31-per-copy theta claims), all inside the existing C1' accounting.

## 8. Variant B: the exact one-hot table (the zero-machinery fallback)

For W_in = 8 the input has only 256 values, so the activation can be
certified EXACTLY: 2^W_in indicator planes `e_v` (binary, one-hot,
placement against the input planes as in 4.3), and ONE standard
dense-target link with map weights `T[v] = the full table` grounding
the output directly. No slot tensors, no Hadamard, no E1/E2, no
approximation error (the declared function IS int8-quantized SiLU;
ulp_max = 0 by construction). Cost: 256 dce/el, +491% pass commit,
+2,570 s 1T of ARP — 2.4x variant A's committed data and ~6x its claim
time, in exchange for statement exactness and zero new machinery
(every gadget grade is already in the soundness reference). Variant B
is the right choice for a NEAR-TERM demo that must not wait on E1/E2;
it dies at W_in = 12 (4,096 planes/element), where A costs 145.

## 9. Recommendation, and what this does to the M4 decision

1. **If M4 must ship on the existing gadget set:** variant A at the
   recommended point (int8, K = 32, degree 1, Pe = 6; spec digest in
   Section 1.1), building E1/E2 as one bounded link-extension tranche
   with the U-L4-pattern negative battery. Variant B as the
   no-new-machinery demo fallback at small scale.
2. **The honest finding for the M4 research gate:** the
   piecewise-with-ranges route (plan Section 2, option (b)) is
   buildable and sound-modulo-known-obligations, but costs +201% of
   the whole pass commit bill — the activation would dominate the
   proof the way M2's finding made gadgets dominate Route Z. These
   numbers are the quantified baseline the lookup-argument track
   (option (a), zkLLM tlookup/LogUp-class) must beat; a lookup
   argument at the typical few-committed-columns-per-table cost
   (~2-4 dce/el equivalent) would be ~25-50x cheaper than this
   compilation. **The M4 decision should move to the lookup track**,
   with this design as the interim and as the fallback if lattice
   lookup arguments miss their promised constants.
3. **Do not extend this compilation to softmax's exp_q without
   re-running the cost model at attention shapes**: the score tensors
   (512 x 512 x 32 heads x 32 layers ~ 2.7e8 elements at 7B/512) are
   LARGER than the FFN gate volume, and exp_q needs more precision
   than an int8 SiLU — the same structure would land at +300% class or
   worse.
4. Integration notes for the merger (this tranche edits no existing
   files): TRANSFORMER_PROOF_PLAN.md Section 2's Class-3 asymptotics
   ("O(T d w) committed elements") should be annotated with the H3
   slot-density constant (16x on every Hadamard operand) — it is the
   constant that decides M4, exactly as the bit-width constant decided
   M2; SOUNDNESS_REFERENCE.md Section 8 should gain the E2
   slot-constancy obligation (it is a gap of the shipped H3 gadget's
   composed use, not of this design); the ordering-audit table gains
   the four link-row entries of Section 4.7.

---

*Changelog: 2026-07-09 — first edition (M4 tranche U-M1..U-M3):
design + reference implementation + measured error/cost tables.*
