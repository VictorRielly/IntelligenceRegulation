# O-1: Parameter Re-Derivation for the Greyhound Reroute at the House Ring

Status: DESIGN COMPLETE (U-AG2 tranche, Agent DA lane, 2026-07-27;
paper + Python spike only — no engine changes). Discharges obligation
**O-1** of AGGREGATION_LITERATURE.md Section 8.1 and supplies the
**O-2 byte-model skeleton**. Verdict (Section 6, one line): the
family-(c) architecture at D = 128 / q31 **closes at the measured 2^20
layer shape (0.96x budget) and lands 1.04-1.10x at the 512x11008 FFN
shape under every sound configuration** — at the line, not through it —
with the sign at FFN scale decided by two named, priced levers; the
recorded BaseFold fallback is **not** triggered, and the precise
boundary that would trigger it is stated in Section 6.3.

Spike: `scripts/greyhound_params_spike.py` (stdlib, sub-second, 15/15
anchor self-checks; every number quoted below is printed by it unless
cited elsewhere). Companion docs: PROOF_BYTE_LEDGER.md (the budgets and
the tensor inventory this design is priced against),
AGGREGATION_LITERATURE.md (the verdict this design instantiates),
SOUNDNESS_REFERENCE.md (grading style and the L1/L2 challenge engines),
ESTIMATOR_NOTE.md (the hardness-estimate conventions reused verbatim).

Grading legend (SOUNDNESS_REFERENCE.md Section 0): **[PROVEN]** —
complete argument here or standard fact, machine-checked where
applicable; **[MODEL]** — quantitative engineering model, parameters
stated; **[OBLIGATION]** — believed and designed, write-up owed
(collected in Section 6.4 for O-7).

Lane discipline note: docs/zkmatrix-poc/AGGREGATION_CLAIM_REDUCTION.md
and scripts/claim_reduction_spike.py belong to Agent DB (O-3) and are
not touched; everything this design assumes about DB's output is
isolated in Section 7 ("Interface assumptions for O-3").

## 0. Scope and sources

O-1 asks (AGGREGATION_LITERATURE.md 8.1): the global-commitment layout
per tensor (two-tier Ajtai at D = 128 / q31; CRS sizing; the C2
wave-cap question re-derived for the global shape), and the
Greyhound + LaBRADOR security re-derivation at our ring (challenge
operator norms, soundness per recursion level, recursion slack absorbed
into the C2/C3 chains, MSIS hardness at the resulting shapes). Numbers
come only from:

- `zkmatrix-rs/src/ring/params.rs` + `ring/mod.rs` — the ACTUAL ring
  parameters, verified this session: D = 128; q31 = `Q8` =
  2,147,483,249 = 2^31 − 399 (q ≡ 17 mod 32, k = 8 split, slots
  GF(q^16), |GF(q^16)| ≈ 2^496); fallback modulus `Q8_46` =
  70,368,744,176,561 = 2^46 − 1103; quinary challenge set |C| = 5^128 =
  2^297.2; LS18 margin 1.30x at (k = 8, q31); `LOG2_DELTA0` = 0.005326;
  TAIL = 1.3, E_C2 = 2.0; op-norm conventions `op_norm`/`combine`/
  `witness_coeff_bound`.
- `zkmatrix-rs/src/ring/ct_engine.rs` `derive_ct_round_params` — the
  per-wave chain whose C2 cap this design re-derives (Section 2.4).
- PROOF_BYTE_LEDGER.md — tensor inventory (Sections 1-2), unit costs
  (Section 0), the 262,144 B / ≤ 2 s budgets (Section 3), the 4 B/limb
  descent width (Section 3.1).
- ESTIMATOR_NOTE.md — the [core-SVP] model (Chen delta, 0.292 b) and
  the published anchor rows the spike self-checks against.
- External references verified THIS session: Greyhound ePrint 2024/1293
  (abstract page: 53 KB evaluation proofs at degree N = 2^30, O(sqrt N)
  verifier, LaBRADOR-composed) and LaBRADOR ePrint 2022/1341 (abstract
  page: 58 KB at 2^20 R1CS constraints); the protocol STRUCTURE of both
  via the two zksecurity expositions (References 4-5 — the ePrint PDFs
  are behind a bot-check this session, so every structural fact used is
  cited to those expositions and flagged where a paper constant could
  not be independently confirmed); and the 2026-04-30 zksecurity
  finding on LaBRADOR soundness in NTT-friendly rings (Reference 6,
  load-bearing for Section 3.6). References inherited from
  AGGREGATION_LITERATURE.md Section 10 without re-verification are
  marked [S10].

## 1. Inherited constants (all verified against source this session)

| constant | value | source |
|---|---|---|
| D | 128 | ring/mod.rs (`aux::D`) |
| q31 | 2,147,483,249 = 2^31 − 399 | mod.rs `Q8` |
| q46 (fallback) | 2^46 − 1103 | mod.rs `Q8_46` |
| CRT split | 8 slots GF(q^16), 2^496 each | SOUNDNESS_REFERENCE 1.1 |
| challenge set C | quinary, 5^128 = 2^297.2 | mod.rs / SOUNDNESS_REFERENCE 1.3 |
| per-slot point mass | 2^−297 (L2 lemma) | SOUNDNESS_REFERENCE 1.3 [PROVEN] |
| LS18 invertibility | margin 1.30x at (k=8, q31) | params.rs `assert_ls18`, C0' |
| op norm, conc | 1.3·sqrt(2D) = 20.8 | params.rs `op_norm` |
| op norm, worst | 2D = 256 | params.rs `op_norm` |
| challenge-difference op, conc | 1.3·sqrt(4D) = 29.4 | derived: variances add [PROVEN] |
| C3 line | k_Z ≥ (log2 β/2)²/(log2 q·0.005326) | params.rs; = core-SVP @ b = 445 (ESTIMATOR_NOTE 5) |
| C2 discipline | q > 8β, ≥ 1 bit headroom | params.rs `finalize` |
| d_lwe (hiding) | ceil(768·log2 q/11.7) = 2035 @q31 | params.rs; ESTIMATOR_NOTE 3 |
| ring-MAC cost | 0.16-0.20 us 1T | RING_MULT_BOTTLENECK.md 6.5 [MEASURED] |
| budgets | 262,144 B; ≤ 2 s 1T p95 | PROOF_BYTE_LEDGER.md 3 |

The spike pins its use of these against five classes of repo anchors
(15 checks): the op-norm identities; the C3 line reproducing the frozen
kappa rows (prototype β = 2^24.55 → κ = 8; Pi2 e=4 β = 2^26.13 → k_Z =
1034 → κ = 9 — ESTIMATOR_NOTE Sections 4/6); the core-SVP leg
reproducing ESTIMATOR_NOTE's published bit counts to ≤ 0.4 bits
(prototype 153.0/152.8, Pi2 e=3 136.7/136.5, FFN 143.4/143.3); the
ledger's descent-byte rows exactly (86,272 B at 2^20; 105,664 B at
FFN); and the ct-engine C2 wave cap reproduced EXACTLY from the
`derive_ct_round_params` chain: the cap saturates at **134
commitments** with sigma(134) = 2^17.3 — the ledger's "sigma ~ 2^17.4
at the 134-commitment bundle" and M4_LOOKUP_DESIGN's "~134 commitments"
wall, re-derived from constants rather than recalled.

## 2. (a) The global-commitment layout

### 2.1 Tensor inventory → segments

The committed material at the two reference shapes, from the ledger's
[DERIVED] counts (PROOF_BYTE_LEDGER.md Sections 1-2; 1,024 committed
q31 coefficients per data commitment):

| tensor class | 2^20 layer | FFN 512x11008 | encoding |
|---|---:|---:|---|
| X value data | 1,024 commits (1.05e6 coeff) | 5,504 (5.64e6) | 1 coeff/el |
| Y slot tensor | 16,384 (16.8e6) | 88,064 (90.2e6) | 16 coeff/el (slot form) |
| UP slot tensor | 16,384 | 88,064 | 16 coeff/el |
| Z slot tensor | 16,384 | 88,064 | 16 coeff/el |
| SiLU lookup material (m column, blinders, mask chunks) | 21 | 25 | — |
| **data total** | **50,197 commits = 51.4e6 coeff = 401,576 rings** | **269,721 = 276.2e6 coeff = 2,157,768 rings** | |
| per-wave g-groups | 38,050 | 204,460 | **ABOLISHED by the reroute** |
| Z1 wave pads | 6 + closing | 32 | **ABOLISHED** (replaced per Section 2.5) |

The reroute commits the data total as **two global super-commitments**:

- **T_data** — the X, Y, UP, Z, and lookup material as SEGMENTS of one
  coefficient vector (segment boundaries recorded in the Statement v3
  manifest; MLE claims address segments via index bits — interface
  assumption I-2, Section 7). One commitment rather than one per tensor
  because identity bytes are pure overhead (5.2 KiB each at the derived
  κ = 10) and MLE segment-addressing is standard; nothing in the claim
  interface needs per-tensor commitments (I-2 asks DB to confirm).
- **T_blind** — the ZK material: the sumcheck masking polynomials that
  are today separate mask commitments in the descent machinery, plus a
  small claim-blinding segment (Section 2.5). Size ~2^10-2^12 rings
  [MODEL]; kept separate from T_data so that its segment can be
  refreshed per proof without touching data layout.

Total committed rings n: **401,576 (2^18.62) at the 2^20 shape;
2,157,768 (2^21.04) at FFN**. Both far inside Greyhound's published
N = 2^30 [verified abstract].

### 2.2 The two-tier Ajtai shape at D = 128 / q31

Following Greyhound's structure (Reference 4: coefficient matrix, inner
Ajtai commitments per column, one outer commitment over the decomposed
inner commitments), instantiated with house objects:

- Arrange the n committed ring elements as an m1 x m2 matrix (columns
  are the fold unit). Each column (m1 rings of full mod-q coefficients)
  is decomposed into balanced base-2^{e0} digits — l0 = ceil(31/e0)
  limbs — giving the short column witness ŝ_j ∈ R^{m1·l0} with
  |ŝ_j|_inf ≤ 2^{e0−1}, plus a hiding tail (Section 2.5).
- Inner commitments t_j = A ŝ_j ∈ R_q^κ, A ∈ R_q^{κ x (m1·l0+16)}
  seed-expanded. The t_j are WITNESS, not wire.
- Outer commitment u = B t̂ ∈ R_q^κ, where t̂ is the concatenation of
  the base-2^{e_t} digit decompositions of all t_j (m2·κ·l_t rings).
  u is the ONLY per-super-commitment wire object: **4 + κ·516 = 5,164 B
  at κ = 10** (P3 codec widths, ledger Section 0).

Derived shape at the reference points (spike output, verifier-balanced
split m1·l0 ≈ m2·κ·l_t — the balance is free w.r.t. norms because the
fold norm depends only on n·l0, Section 3.2):

| shape | q | slack model (3.4) | e0 (l0) | m1 | m2 | κ |
|---|---|---|---|---:|---:|---:|
| 2^20 | q31 | per-level | 3 (11) | 2,003 | 201 | 10 |
| 2^20 | q31 | exact-digit | 4 (8) | 2,003 | 201 | 10 |
| FFN | q31 | per-level | 1 (31) | 4,645 | 465 | 10 |
| FFN | q31 | exact-digit | 2 (16) | 4,645 | 465 | 10 |
| FFN | q46 | per-level | 15 (4) | 5,689 | 380 | 15 |

Note the q31 FFN row: the norm budget forces e0 = 1 — **sign-binary
digit decomposition of the tensor coefficients** — the deepest
decomposition the chain admits; this is the first concrete signal of
how tight q31 is (Section 3).

### 2.3 CRS sizing

Seed-expanded (house `expand_crs` discipline), zero wire cost beyond
the 32 B seed already in the statement. Expanded sizes at the FFN
per-level point (κ = 10): inner A: 10 x (4,645·31 + 16) = 1.44e6 ring
elements ≈ **703 MiB if materialized**; outer B: 10 x (465·10·16 + 16)
= 744,160 rings ≈ 363 MiB; per-level CRSs strictly smaller (largest
2.6e5 rings). The 15 GiB box rule (shared-box discipline) makes
materializing A unattractive but not fatal; the commit pass can
stream-expand A column-blocks (the A1 kernels consume key columns
sequentially; same pattern as the existing commit path) at O(MB)
resident [MODEL — streaming constant unmeasured]. Recorded as a build
note, not a design risk.

### 2.4 The C2 wave cap, re-derived for the global shape

What the old cap was (reproduced exactly by the spike from
`derive_ct_round_params`): one per-wave masked ct-round over
n_commits standard commitments has bundle norm sqrt(n_commits·n_z),
mask sigma = 12·op·sqrt(bundle), response bound 1.2·sigma·sqrt(bundle),
and C2 (q > 8β) fails at q31 beyond **exactly 134 commitments** —
hence the 1020-element row-block sub-instancing and the "caps near 2^17
elements" wall (M4_LOOKUP_DESIGN.md Section 7''; TARGET_CONTRACT.md
Section 3).

What replaces it under the reroute — two separate facts, both derived
in Section 3 and evaluated by the spike:

1. **The Gaussian-mask term is EVICTED, not re-derived.** The old cap
   was dominated by the rejection-sampling blowup (sigma = 12·T,
   bound = 1.2·sigma·sqrt(dim)). At the global shape the equivalent
   masked opening would need sigma = 12·gamma_z ≈ 2^25.3 and bound ≈
   1.2·12·gamma_z·sqrt(m1·l0·D) ≈ 2^37 — **no rejection-sampled masked
   opening of a globally-folded witness fits under q31 at all**
   [PROVEN arithmetic, spike constants]. Consequence: the aggregate
   opening layer contains NO Gaussian-masked responses anywhere; ZK is
   carried entirely by committed-data masking (T_blind + masked
   sumcheck, Section 2.5/O-4). This is a hard design constraint
   exported to O-4 and DB (interface I-6).
2. **The new cap is the recursion-slack budget.** The binding
   inequality is no longer "n_commits ≤ 134 per wave" but
   gamma_max = (q/8) / slack_total, where slack_total is the
   extraction-slack stack of the recursion (Section 3.4). At q31,
   gamma_max = 2^21.07 (per-level reading) / 2^22.12 (exact-digit
   reading); the level-0 fold norm gamma_z = 20.8 · 2^{e0−1} ·
   sqrt(n·l0·D) must fit under it — which it does at every reference
   shape (0.15-0.7 bits of headroom, Section 3.2), with NO cap on the
   number of columns folded: the old per-wave counting cap is
   **vacated**. The 1020-element row-block granularity disappears with
   the waves themselves.

### 2.5 Hiding and the Z1 replacement (layout side only)

Two mechanisms, both priced into the layout; the simulator/battery
arguments belong to O-4:

- **Commitment hiding**: each inner column carries a 16-ring ternary
  hiding tail (16·128 = 2048 ≥ d_lwe = 2035, the integral-rank reading
  of the C4 line — ESTIMATOR_NOTE Section 6(b) convention), and the
  outer witness likewise. MLWE hardness at this exact shape (n_sec =
  2048 ternary at q31) is the estimator note's own measured row:
  **193.3 bits classical [core-SVP], 215.7 [MATZOV]** (ESTIMATOR_NOTE
  Section 4) — no new estimate needed. Cost: +16/(m1·l0) ≈ +0.01-0.5%
  witness, zero wire.
- **Claim blinding**: the Z1 pads' job (keep per-wave RHS off the
  wire) has no per-wave object left to protect; what remains exposed
  is the batched MLE claim VALUES, which are blinded by folding a
  T_blind segment into every batched claim with unit weight (the
  "blinded eval claims" move recorded in AGGREGATION_LITERATURE 3.3).
  Wire cost: the blind segment's own claim values, inside the Section
  5 claim-value line. WSMD Section 7.1 is satisfied via its second
  branch ("re-derive the privacy argument") — the re-derivation itself
  is O-4's deliverable, on the built masked-sumcheck machinery.
