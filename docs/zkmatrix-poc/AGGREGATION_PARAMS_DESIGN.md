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

## 3. (b) The Greyhound + LaBRADOR security re-derivation at our ring

### 3.1 Challenge sets and operator norms at D = 128

Greyhound/LaBRADOR publish at degree-64 rings with their own challenge
sets (Reference 5: d = 64, challenges sampled sparse/small with
pairwise-invertible differences). At our ring every challenge role is
filled by an existing house object — no new set is introduced:

| role | house object | op norm | soundness engine |
|---|---|---|---|
| fold challenges (multiply witnesses) | quinary C, |C| = 2^297.2 | 20.8 conc / 256 worst (params.rs) | L2 per-slot point mass 2^−297 [PROVEN] |
| fold-challenge differences (extraction) | C − C | 29.4 conc / 512 worst | LS18 invertibility, margin 1.30x (C0') [PROVEN, checked at derive time] |
| constraint-aggregation challenges (never multiply witnesses) | full-entropy R_q (SOUNDNESS_REFERENCE 1.3) | — | per-slot q^−16 = 2^−496 [PROVEN] |
| sumcheck/batching field challenges | GF(q^16) K-field draws | — | SZ over 2^496 field |

The concentration figures carry the house restart discipline
(params.rs `conc` + `center_sq`: restart-if-exceeded on honest
centers, 2^-64-class soundness surcharge — Q4 note), extended
unchanged to the new folds [OBLIGATION: the Q4-style transcription of
that surcharge for the aggregate folds, folded into O-7].

### 3.2 Level norm chains

**Level 0 (Greyhound fold).** z = sum_j c_j ŝ_j over the m2 columns;
with digit magnitude 2^{e0−1} and column flat dimension m1·l0·D, the
concentration bound is

    gamma_z = 20.8 · 2^{e0−1} · sqrt(n · l0 · D),    n = m1·m2.

Spike values: 2^20.92 (2^20 shape, e0 = 3) / 2^20.88 (FFN, e0 = 1) /
2^21.40-2^21.69 (exact-digit variants) — against gamma_max = 2^21.07
(per-level) / 2^22.12 (exact-digit). Headroom 0.15-0.7 bits: REAL but
thin; e0 is pinned to {1,2,3,4} by it (Section 2.2's table). The
verifier checks ||z|| <= gamma_z with the house restart rule sizing
the honest success rate.

**Levels >= 1 (LaBRADOR steps).** Each level: split the current
witness (all entries digits of magnitude <= 2^{e_i−1}) into r_i
chunks, commit chunks (fresh inner commitments, kappa rings each),
send one merged outer commitment + norm-check material + aggregation
scalars, fold with quinary challenges, decompose the fold and the new
commitment/garbage coefficients for the next level. The recurrence the
spike optimizes (g and h garbage terms per Reference 5's protocol —
r(r+1)/2 each, mod-q, decomposed):

    n_{i+1} = ceil(n_i/r_i)·l_z + r_i·kappa·l_t + r_i(r_i+1)·l_gh

with ADAPTIVE digit bases: e_i = the largest base with
20.8·2^{e_i−1}·sqrt(n_i·D) <= gamma_max. This adaptivity is what makes
deep recursion possible at all at q31 — the base grows as dimensions
shrink (e = 1..4 at the top, e = 9-10 at the floor), keeping every
level's fold norm just under the same gamma_max. Spike schedules run
7-9 levels to a floor of ~500-620 rings (both shapes, both sound
models); the floor is set by the r_i·kappa·l_t + r_i²·l_gh regrowth
terms, exactly the LaBRADOR floor structure (Reference 5).

### 3.3 MSIS instances at the resulting shapes

Every level's binding is a fresh MSIS instance at that level's
extracted-difference bound. Sizing follows the house C3 line with
kappa = ceil(k_Z/128), then a [core-SVP] bit count (ESTIMATOR_NOTE
conventions, spike-implemented and anchor-checked):

| instance | q | log2 beta_top | k_Z | kappa | core-SVP bits |
|---|---|---:|---:|---:|---:|
| top (level-0 inner), 2^20, per-level | q31 | 27.84 | 1,188 | 10 | **132.1** |
| top, 2^20, exact-digit | q31 | 27.56 | 1,188 | 10 | **135.9** |
| top, FFN, per-level | q31 | 27.80 | 1,188 | 10 | **132.6** |
| top, FFN, exact-digit | q31 | 27.28 | 1,188 | 10 | **140.0** |
| top, FFN, q46 per-level | q46 | 40.32 | 1,887 | 15 | **155.7** |

All clear 128-bit classical [MODEL: core-SVP floor; MATZOV would sit
20-30 bits higher per ESTIMATOR_NOTE's measured spreads]. Levels >= 1
have the same gamma_max by construction, hence the same instance class;
kappa = 10 is used uniformly [q31]. The C2' validity condition
beta_top <= q/8 holds at every row above (limit 2^28.00 at q31) — with
as little as **0.16 bits to spare** at the FFN per-level point. That is
the honest thinness of q31: one lost bit anywhere in the norm chain
flips the verdict, which is why every constant above is either measured,
anchor-checked, or flagged.

Quantum note: at kappa = 10 the top instances sit near the classical
frozen-point margins; the ESTIMATOR_NOTE quantum caveat (0.257b) applies
unchanged — a 128-bit-quantum policy would cost kappa+1 exactly as
documented there (not adopted, matching the freeze).

### 3.4 Recursion slack — the load-bearing unknown, stated precisely

The extraction slack that the C2/C3 chains must absorb is
beta_top = slack · gamma_z with three defensible readings; O-7 must
decide which lemma is provable for OUR composition:

| reading | slack | at q31 this admits | source of the factors |
|---|---|---|---|
| **per-level** (baseline) | 2 (fork) · 2.07 (one JL application) · 29.4 (one dc-clearing) = 121.7 | gamma_max 2^21.07, depth 9: **works** | each level's binding is a fresh MSIS pinning that level's witness; cross-level consistency by committed-value equality, not norm transport — the house relaxed-binding shape (SOUNDNESS_REFERENCE 2.2) |
| **exact-digit** | 2 · 29.4 = 58.8 | gamma_max 2^22.12: works, +1 bit | replace the JL norm check with the house deterministic digit range claims (sigma.rs / M2 binary ct-claims class) — no JL slack, no JL statistical term |
| **compounded** (adversarial) | 121.7 · 4.13^(L−1) | gamma_max(L=2) = 2^19.02 < min gamma_z = 2^20.88: **NO second level fits** | if extracted-norm slack multiplies through levels, q31's 31 bits cannot host even L = 2 |

The compounded row is the PRECISE FAILURE STATEMENT the tranche brief
asked for: at q31, if slack compounds, the layout admits exactly one
fold level, the final witness is 323,827 rings, and the artifact floor
is 41,593,548 B = 158.67x budget (spike, FFN/q31/compounded row) — the
architecture then fails at this modulus regardless of engineering.
LaBRADOR's published viability at q ≈ 2^32 with 6-7 levels (References
2, 5) is strong evidence AGAINST the compounded reading — a compounded
stack would break their published parameters equally — but their
knowledge analysis is exactly what the PSS line (ePrint 2024/311 [S10])
was written to repair, so this design does not lean on it silently:
**[OBLIGATION → O-7]: prove the per-level (or exact-digit) composition
lemma for our chain in the Q4_LEMMAS transcription style.**

### 3.5 Knowledge error per level and FS composition

Spike accounting (FFN point; 2^20 within 1 bit):

- fold rounds: sum of r_i challenge dimensions, L2 engine:
  2^−288 [PROVEN per-round engine, composition OBLIGATION]
- claim batching (Section 4): 2^−293 [PROVEN lemma, Section 4.1]
- sumcheck SZ over GF(q^16): 2^−487 [PROVEN class]
- JL norm-check statistical term (only when JL is used): **2^−141
  [MODEL — LaBRADOR-class constant at 256 projection rows; the exact
  paper constant was not independently confirmable this session]**
- pre-FS union: 2^−139 (JL) / 2^−286 (exact-digit)
- FS composition, PSS-style linear-in-Q loss [MODEL], Q = 2^64,
  R ≈ 33 rounds: post-FS **2^−70 with 256-row JL — FAILS the 2^−128
  target**; 2^−211 with 512-row JL [MODEL]; 2^−217 exact-digit —
  both PASS.

Design consequence (firm): the 256-row JL configuration is NOT
shippable at our target under FS grinding; the two sound
configurations are **per-level + 512-row JL** (+1,024 B/level wire)
and **exact-digit** (no JL; integration of the existing deterministic
digit claims into the level loop is new protocol plumbing
[OBLIGATION], priced in Section 5). Both appear in every Section 5/6
table; nothing below quotes the unsound configuration except as a
bound.

### 3.6 The split-ring check the field just learned to make

zksecurity's 2026-04-30 review (Reference 6) found three public
LaBRADOR implementations UNSOUND — soundness collapsing to 1-31 bits —
because their rings split into small CRT factors (NTT-friendly moduli),
breaking the RLC-aggregation argument: a cheating witness nonzero in
one small slot survives the random combination with probability
1/|smallest factor|. The failure mode is precisely the quantity our
house engines were built around: our ring splits into EIGHT factors of
size **2^496** (not degree-1 factors of size 2^31), the small-norm
challenges carry the L2 per-slot injection lemma (2^−297 per slot),
and the full-entropy aggregation challenges carry 2^−496 per slot;
the LS18 margin (1.30x, freeze-checked) guards difference
invertibility. The re-derivation at k = 8 (vs LaBRADOR's specified
2-factor split) is therefore NOT a formality — it is exactly the class
of parameter change that silently killed those implementations — and
Sections 3.1/3.5 + Section 4 are that re-derivation. [External
confirmation that the slot-field SIZE is the load-bearing quantity;
our design passes it with 365 bits of margin over the 128-bit line.]

## 4. (c) Batched MLE-evaluation claims over the 8-slot GF(q^16) structure

AGGREGATION_LITERATURE.md Section 9 records: "RLC batching of
evaluation claims is folklore over fields; at our 8-slot GF(q^16) CRT
structure with small-norm challenge sets, the knowledge-error
accounting is nowhere in print." This section derives it. Setting: the
masked sumcheck/GKR engine (DB's O-3 output) leaves B claims

    v_{i,s} = f~_i(r) |_slot s        i = 1..B,  s = 1..8,

where f~_i is the multilinear extension of segment i of T_data/T_blind
over the slot field GF(q^16), r ∈ GF(q^16)^{dw} is the common
evaluation point (interface I-1), and the verifier holds all 8 slot
values per claim (interface I-3).

### 4.1 The batching lemma [PROVEN]

Batch with INDEPENDENT quinary ring challenges gamma_1..gamma_B
(norm-driven choice, 4.2): the batched claim, per slot s, is

    sum_i res_s(gamma_i) · v_{i,s}  =  ( sum_i gamma_i ⊙ f~_i )(r) |_s,

where res_s is the (injective, by L1/LS18) restriction of the
challenge to slot s and ⊙ is the ring action on the slot
decomposition. Soundness claim: if for some claim i* and slot s* the
prover's committed f~ disagrees with the claimed v_{i*,s*}, the
batched check in slot s* passes with probability at most 2^−297 over
gamma.

Proof (the L2 conditioning argument of SOUNDNESS_REFERENCE 1.3,
verbatim in a new role): let delta_i = f~_i(r)|_{s*} − v_{i,s*} ∈
GF(q^16), not all zero. The batched check in slot s* requires
sum_i res_{s*}(gamma_i) · delta_i = 0. Fix any i0 with delta_{i0} ≠ 0
and condition on all gamma_i, i ≠ i0: the requirement becomes
res_{s*}(gamma_{i0}) = k for a fixed slot-field constant k
(delta_{i0} is invertible in the FIELD GF(q^16)). By L2, res_{s*} is
injective on C, so Pr <= 5^−128 = 2^−297. Since the verifier checks
ALL 8 slots (I-3), a disagreement in ANY slot is caught with the same
bound — no union over slots is even needed; the spike's ledger entry
charges 2^−293 (= B·2^−297 at B = 16, the lazy union over claims,
strictly looser than the conditioning bound). ∎

Two design rules fall out of the proof, both binding on DB (Section 7):
(i) claims must be checked slot-COMPLETE — a design that sums or
samples slots re-opens the small-slot escape of Reference 6; (ii) the
batching weights must come from a set with per-slot injectivity — the
house quinary set qualifies via LS18; an ad-hoc small set would not.

### 4.2 The norm side of batching [PROVEN arithmetic]

The gamma_i multiply committed columns inside the fold, so they enter
the level-0 norm chain: independent quinary weights contribute the
same E[c²] = 2 as the fold challenges, and the batched fold over
(B segments spanning the m2 columns) has EXACTLY the gamma_z of
Section 3.2 — batching is norm-free beyond the fold it rides
(the segments partition the columns; no column is folded twice).
Powers-of-one-challenge batching (gamma^j weights) is REJECTED on
norms: op(gamma^j) grows as 20.8^j, unusable past j = 2 at our
budget; independent draws also carry the cleaner lemma above. The
FS transcript cost of B independent challenges is zero (XOF-derived).

### 4.3 Multi-point handling

If DB's reduction lands claims at k > 1 distinct points, the standard
merge (one extra batch-evaluation sumcheck over an RLC of the k
point-evaluations) costs one dw-round transcript: the Section 5 model
prices it at dw·(deg+1) K-elements — 5,376 B at 2^20, 6,144 B at FFN
[MODEL] — and its soundness rides the same SZ/2^496 engine. Every
point family BEYOND the first adds one such block; more than ~4
erodes the byte line (Section 5). Hence interface I-1: land at ONE
point, or as few as possible.

### 4.4 What remains for O-7 here

The lemma of 4.1 is per-round sound. The EXTRACTOR for the batched
composition (B+1-transcript forking across the batching round,
composed with the level extractors of Section 3.4) is predicate-
special-soundness territory (the PSS pattern, ePrint 2024/311 [S10])
and is owed as part of O-7 [OBLIGATION]. Nothing in the byte or norm
accounting depends on its outcome; the knowledge-error TARGET already
carries it as the dominant [MODEL] flag (Section 3.5).

## 5. (d) The O-2 byte-model skeleton and the verifier model

### 5.1 The closed-form artifact

In the ledger's unit-cost style (PROOF_BYTE_LEDGER.md Section 0
widths: poly = 516 B, K-element = 64 B at the canonical 4 B/limb,
u32 length prefixes), the complete aggregate artifact is:

    bytes = statement                                  (v3 codec, ~4 KiB)
          + n_gc · (4 + kappa·516)                     (outer identities u)
          + kel(dw, dt) · 64                           (masked descent pair)
          + [k>1 points] · dw·(deg+1)·64               (batch-merge sumcheck)
          + (4 + kappa·516)                            (level-0 v commitment)
          + (L−1) · [ (4+kappa·516) + JL + agg ]       (level messages)
          + n_L · 128 · ceil((e_L+1)/8)                (final bare witness)
          + B·8·64                                     (batched claim values)
          + framing

with every constant either a ledger width or a Section 2/3 derived
shape. The spike evaluates it with the level schedule of Section 3.2;
JL = 1,028 B at 256 rows / 2,052 B at the sound 512-row setting.

### 5.2 The tables (spike output, canonical widths)

**2^20 layer, q31, per-level + 512-row JL (the sound byte-optimum):**

| component | bytes |
|---|---:|
| statement (v3) | 4,096 |
| 2 outer identities (kappa = 10) | 10,328 |
| masked descent pair (dw 21 + dt 9) | 86,272 |
| batch-merge sumcheck [MODEL] | 5,376 |
| eval proof: 7 level messages (incl. 512-row JL) | 56,684 |
| eval proof: final bare witness (624 rings, 7-bit digits) | 79,872 |
| batched claim values (16 x 8 slots) [MODEL] | 8,192 |
| framing [MODEL] | 2,048 |
| **TOTAL** | **252,868 B = 246.9 KiB = 0.96x budget → PASS** |

**FFN 512x11008, q31 — the sound frontier:**

| configuration | bytes | vs 262,144 B |
|---|---:|---:|
| per-level + 512-row JL | 278,968 | **1.06x — OVER** |
| per-level + 512-row JL + one-point landing (I-1) | 272,824 | 1.04x — OVER |
| exact-digit | 289,080 | 1.10x — OVER |
| exact-digit + one-point landing | 282,936 | 1.08x — OVER |
| (256-row JL, FS-unsound, lower bound) | (271,800) | (1.04x) |
| compounded slack reading | 41,593,548 | 158.67x — architecture-fail |
| q46, per-level + 512-row JL | 354,104 | 1.35x — OVER (wider coeffs everywhere) |

Reading: at FFN scale the model lands **10,700-27,000 B (4-10%) over**
the hard line with all repo-recorded levers applied. The remaining
named levers, each with its owner:

1. **The descent pair is 105,664 B = 39% of the artifact** — the
   single biggest line, owned by the GKR engine shape (dw 24 + dt 9),
   not by this lane. Any descent-side compression (round-elimination,
   cross-layer folding of the pair under O-8, or a dw reduction from
   DB's claim restructuring) moves the verdict one-for-one.
2. **Digit bit-packing** of the final witness ((e+1)-bit packed vs
   byte-aligned): worth ~1/8 of the bare-witness line when e_L = 7
   lands on a byte boundary (current schedules: zero gain — the
   stop-scan already found byte-aligned optima) but up to 10 KiB on
   schedules with e_L = 5-6; a canonical-codec EXTENSION (R4 review
   required) [MODEL].
3. **32-layer pass scope** (R1 requires the number stated): one
   artifact per layer x 32 = **8.5-8.9 MiB/pass** at the FFN sound
   frontier; the (b)-folding accumulator (O-8) is the recorded
   mechanism to beat that, not this lane's. If the 256 KiB budget is
   read per-PASS, family (c) alone misses by ~34x and O-8 is
   mandatory — same conclusion as the literature round
   (AGGREGATION_LITERATURE Section 7 note).

Against today: 18.59 GiB → 279 KB at FFN scale is a **71,569x
reduction** [MODEL vs the ledger's DERIVED baseline]; the residual gap
to budget is 1.06x.

### 5.3 The verifier model [MODEL] vs ≤ 2 s

Ring-MAC accounting at the measured 0.18 us/ring-MAC kernel class
(RING_MULT_BOTTLENECK.md 6.5), single-threaded:

| shape / config | dominant term | modeled verify |
|---|---|---:|
| 2^20, per-level | level-1 statement pass (kappa·(z_len + t̂ + ŵ) ≈ 8.6e5 MACs) | **0.18 s** |
| 2^20, exact-digit | same class | 0.14 s |
| FFN, per-level | level-1 statement pass ≈ 4.6e6 MACs | **0.93 s** |
| FFN, exact-digit | same, smaller l0 | 0.52 s |
| FFN, q46 | fewer limbs | 0.30 s |

All PASS the 2 s line; the FFN per-level point has only **2.2x
headroom** — statement validation, hashing, and codec overhead
[not modeled] must fit in that. The structural claim survives: the
verifier is O(sqrt N)-statement-sized (the level-1 pass) + polylog
(descents), never linear in the 2.16e6-ring witness; the ledger's
Section 3.2 rule ("sublinear in commitments x waves; no per-wave
re-checks") is met by construction since neither commitments-per-wave
nor waves exist. Assert-3 of the U-AG-B1 gate (p95 over 20 runs) is
where this model gets measured.

### 5.4 The prover marginal [MODEL] vs H-05

Commit-path marginal of the reroute (inner + outer commits + fold
passes, kernel-served): **+25.6 us/el at the FFN per-level point
(+4% on the 578.7 us/el whole-prove), +13.2 us/el (+2%) exact-digit,
+9.1/+6.6 us/el at 2^20.** The e0 = 1 decomposition (31 limbs) is
what makes the per-level q31 point the most expensive; still far
inside the >10x H-05 re-break line. O-6 owes the full model (this is
the commit-path term only; the retired per-wave BDLOP commits and
Sigma rounds come OFF the bill and are not credited here).
