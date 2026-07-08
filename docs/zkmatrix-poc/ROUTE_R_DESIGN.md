# Route R Design: the Cyclotomic Ring Lift of the Lattice Track

Status: design spike, complete. Companion artifacts:
`zkmatrix-rs/src/bin/ring_lattice.rs` (arithmetic-core prototype with one
full Sigma round at ring level; all self-tests pass) and
`scripts/route_r_params.py` (the parameter tables below are its output).
Sources: lattice report Sections 5.5, 7.5, 10, 11, 17; `M2_REPORT.md`
Section 4; `LLM_SCALE_ESTIMATE.md` Sections 3-3b; `PROVER_OPTIMIZATIONS.md`
Tier 2. Mandates carried: the 2x prover-overhead target and Class-3
elementwise viability (Route Z gadgets measured at ~108 ms/element, 135x
over the <20% criterion).

Three findings in this spike change numbers that were previously assumed:

1. **Ternary challenges at d = 128 fail the report's own Fiat-Shamir
   budget** by ~54 bits. The fix is nearly free (quinary coefficients).
2. **r = 1 per-slot soundness holds only for ring-valued claims.** Every
   compression and opening lifts by transcription, but any place the
   protocol compresses to a Z_q scalar (Pi2's product gate, Pi1's A-row
   checks) needs the ALS20/LNP22 ct-extraction machinery or a mini-repeated
   scalar layer. This is a sharper statement of the report's Section 17
   caveat, and it covers Pi2 as well as Pi1.
3. **The q = 5 mod 8 mandate caps CRT splitting at one level**, so ring
   multiplication is half-schoolbook (Karatsuba ~3x), not d log d. The
   commit-arithmetic lever assumed in `LLM_SCALE_ESTIMATE.md` Section 3
   ("~15x fewer commit ops via ring packing") does not materialize at
   k = 2; the r: 64 -> 1 proof lever and the elementwise-gadget lever do.
   Section 7 revises the projections.

## 1. Ring and modulus

**Ring.** `R_q = Z_q[X]/(X^d + 1)` with **d = 128**.

- vs d = 64: the challenge-set budget of Section 2 needs
  `|C| >= 2^257`; at d = 64 even coefficients in {-8..8} give only
  17^64 = 2^261 with a ~4x worse norm expansion than quinary-128, and the
  packing granularity halves. Feasible but strictly worse.
- vs d = 256: ternary coefficients would pass the budget (3^256 = 2^405.8),
  but every ring operation costs ~2x (schoolbook is quadratic in d), the
  worst-case multiplication expansion `||c||_1 <= 2d` doubles, and message
  padding waste doubles at the demo shapes (columns of length 8-64 already
  pad to one element at d = 128). d = 256 is the fallback if quinary
  challenges are rejected in review; nothing else in this document changes.
- d = 128 with quinary challenges passes the budget with 40 bits of margin
  at the smallest cost point. It also matches the report Section 17's
  d = 128 sketch and the granularity of LNP22-class production systems.

**Splitting.** q prime, **q = 5 (mod 8)**, so `X^128 + 1 =
(X^64 - r)(X^64 + r) mod q` with `r^2 = -1`, both factors irreducible:
`R_q ~= F_{q^64} x F_{q^64}`, exactly two CRT slots.

**The LS18 invertibility bound** (Lyubashevsky-Seiler, EUROCRYPT 2018,
general form: for `q = 2k+1 mod 4k`, `X^d + 1` splits into k irreducible
factors and every nonzero `y` with `||y||_inf < q^(1/k) / sqrt(k)` is
invertible). At k = 2:

    every nonzero y in R_q with ||y||_inf < q^(1/2) / sqrt(2) is invertible.

This is what restores the two facts Part I of the report used primality
for: challenge differences are nonzero divisors (3-special-soundness
extraction divides by them), and Freivalds compression gets per-slot
Schwartz-Zippel. Verification for the concrete moduli:

| modulus | value | q mod 8 | LS18 bound | challenge diffs (inf <= 4) |
|---|---|---|---|---|
| q31 (prototype) | 2^31 - 19 = 2147483629 | 5 | 32767.9 | covered, 8000x margin |
| q46 (protocol) | 2^46 - 635 = 70368744177029 | 5 | 5931642 | covered, 1.5e6x margin |

Both are single-limb primes; `sqrt(-1) mod q31 = 629208553` (verified
`r^2 = -1` in the prototype). Products of invertible differences are
products of invertibles, so Vandermonde-type clearing in the 3-transcript
extraction needs no larger bound. The prototype exercises the bound both
ways: 200 explicit challenge-difference inversions via CRT ext-gcd
(`inv * diff = 1` checked in R_q), and a negative control showing an
element that vanishes in one slot (far above the bound, `||.||_inf ~ q/2`)
is a genuine zero divisor.

**Target q size.** The estimate hoped for 32-bit-class. The recomputed
norm chain (Section 3) says: the **opening/linear layer fits q31**
(prototype runs at 3.4 bits of C2 headroom), and **Pi1 fits 2^37**, but
**Pi2 at n = 2048 needs ~2^46** under concentration norm bounds (worst-case
l1 bounds do not close below 2^62). Recommendation: **q46 = 2^46 - 635**
as the single protocol modulus. Consequences, stated honestly:

- Single u64 limb, products via u128 or AVX-512 IFMA (52-bit lanes hold
  q46 products only after RNS/limb splitting; the practical CPU kernel is
  u128 lazy accumulation, same as the prototype's).
- The tensor-core mapping of `LLM_SCALE_ESTIMATE.md` Section 3 ("~16 int8
  GEMMs per 30-bit modular GEMM") scales roughly with (bits/30)^2: ~2.4x
  more int8 GEMMs at 46 bits. Real but not disqualifying.
- The lever that would restore 32-bit-class q is Dilithium-style response
  decomposition (drop low bits of z, carry a hint), which cuts B and hence
  beta by ~2^8-2^12. It touches the ZK argument (Lemma 6.3 rework) and is
  scoped as open question Q2, not assumed.

**Why q = 5 mod 8 costs kernel speed (finding 3).** `v2(q-1) = 2` exactly,
so the only root of unity available is the 4th root r: one CRT level
(X^128+1 -> two degree-64 negacyclic halves), then schoolbook or Karatsuba
within slots. Measured in the prototype (approximate, shared machine):
naive negacyclic mul 18-31 us, per-slot degree-64 schoolbook 2.6-9.1 us
(x2 per ring mul + split overhead ~ 2x total win; Karatsuba projects ~3x).
There is **no d log d NTT at k = 2**; any claim built on one implicitly
assumes a fully-splitting modulus (q = 1 mod 2d) and the ALS20-style
soundness rework that comes with it. This trade (invertibility margin and
simple soundness vs kernel speed and slot count) is the k-split trade
study, open question Q2/Q3.

## 2. Challenge set and the soundness accounting that replaces r(b-2) >= 256

**Set.** `C = { c in R_q : ||c||_inf <= 2 }` — quinary coefficients,
`|C| = 5^128 = 2^297.2`. Differences satisfy `||c - c'||_inf <= 4`,
invertible by LS18 whenever q > 32 (trivially true).

**Why not ternary (the report's Section 17 sketch).** The report Section
7.5 sizes Fiat-Shamir as `(Q+1)^2 * eps <= 2^-lambda` with Q = 2^64 hash
queries and mu = 2 challenge rounds, i.e. the interactive knowledge error
must satisfy **eps <= 2^-256** (that is what `r(b-1) >= 256` for Pi1 and
`r(b-2) >= 256` for Pi2 implement at r = 64). At r = 1 the same discipline
gives, per challenge set (script output):

| challenge set | log2 C | knowledge error 2/C | post-FS (Q+1)^2 eps | verdict |
|---|---|---|---|---|
| ternary d=128 | 202.9 | 2^-201.9 | 2^-73.9 | FAIL (misses by 54 bits) |
| quinary d=128 | 297.2 | 2^-296.2 | 2^-168.2 | PASS (40-bit margin) |
| ternary d=256 | 405.8 | 2^-404.8 | 2^-276.8 | PASS (fallback) |

The 3^128 ~ 2^202 folklore number covers interactive 128-bit soundness but
not the grinding budget. Quinary costs one extra bit of `||c||_inf` (LS18
still trivially covers it) and a factor 2 in the worst-case l1 expansion
(2d vs d) — absorbed in the Section 3 tables.

**Per-challenge knowledge error, assembled.** Three error sources, each of
which must independently sit at or below 2^-256-class:

1. *3-special-soundness slack (Pi2's gate, Theorem 8.3's argument):*
   `(k-1)/|C| = 2/5^128 = 2^-296.2`. Extraction clears Vandermonde products
   of challenge differences; each factor is invertible by LS18, so the
   slack is a unit and the report's `q > 2*2^(3b)` C0 constraint collapses
   to the trivial q > 32.
2. *Freivalds compression, per CRT slot:* a nonzero defect survives
   `<s, defect> = 0` only if a fresh challenge lands in a prescribed coset
   of one slot. Reduction of a quinary c mod `X^64 - r` has coordinates
   `c_i + r c_{i+64}`; the 25 values per coordinate pair are distinct
   (a collision would force `j^2 + k^2 = 0 mod q` with `j, k <= 4` — 
   impossible for q > 32), so the max point mass is `(1/25)^64 = 5^-128 =
   2^-297.2` per slot, `2^-296.2` over both slots. Same bound for any
   partial split k | d, since all 128 coefficients enter every slot image.
3. *Concentration-bound exceptions* (Section 3): where extraction compares
   against honest combined openings bounded by concentration rather than
   worst-case l1, the exception probability (challenges are FS outputs)
   adds ~2^-64-class terms. Dominated by the budget margin.

Total per-challenge error ~2^-295; post-FS ~2^-167. Replaces C1.

**The scalar-claim caveat (finding 2).** The 2^-296 compression error is a
statement about **ring-valued** equations (per-slot SZ in two fields of
size q^64). Any compression whose *output is a Z_q scalar* — Route Z's
final gate scalar `t = s^T C v`, or a ct() projection — carries only the
per-coordinate entropy of the weights: quinary scalar weights give ~2^-2.3
per claim, and a length-128 quinary-quinary inner product weight has
~2^-5.5-class point mass. **No small-coefficient scalar compression
reaches 2^-256 at r = 1.** Uniform-mod-q weights would (error q^-1 per
combination, so `l = ceil(256/log2 q)` = 6 rows at q46), but uniform
weights cannot multiply randomness-bearing commitments — combined openings
must stay short (report Section 2, the reason challenges are small in the
first place). Resolution, used throughout this design:

> Uniform weights theta may multiply **public functionals and messages**;
> small ring challenges multiply **commitments**. Scalar claims are proven
> by the **ct-engine** (Section 4): commit a masking element g with the
> claim-carrying coefficients zeroed *before* theta is drawn, reveal
> `h = g + f_theta(witness)`, check the claimed coefficients of h directly
> (deterministic — no scalar SZ at all), and prove the *ring-valued* linear
> claim "h opens to f_theta + g" (per-slot sound). This is LNP22's Pi_ct
> shape; ALS20 Section 4 is the same idea specialized to products.

Engineering fallback if the ct-engine bookkeeping stalls: repeat only the
scalar-gate layer r_g times with fresh (s, v) — it is side-linear and
cheap; commitments and all linear layers stay at r = 1. Even r_g = 8 would
cost percent-level.

## 3. Parameter re-derivation (C0-C4 over the ring)

**Dimensions.** Message length n packs to `msg_r = ceil(n/d)` ring
elements; randomness `N_r` ring elements (`N_Z = N_r * d` integer
coefficients); binding `kappa` ring rows (`k_Z = kappa * d`). Commitment
per column: `(kappa + msg_r) * d * log2(q)` bits. MSIS/MLWE live at ranks
kappa and `N_r - kappa - msg_r` over R_q; the C3/C4 models below evaluate
them at their Z-dimensions (module problems are at least as hard as their
unstructured counterparts in all known cryptanalysis; estimator sign-off
is Q5).

**Norm bookkeeping (coefficient embedding).** Multiplication operator
norm: `||c x||_2 <= ||c||_1 ||x||_2` worst case (`||c||_1 <= 2d = 256`
quinary); concentration `E||c x||^2 = d E[c_i^2] ||x||^2` exactly (negacyclic
convolution), so `||c x||_2 <~ 1.3 sqrt(2d) ||x||_2 = 20.8 ||x||_2` with a
subgaussian tail. Combining t column commitments with independent ring
challenges: worst `t * 2d * B0`, concentration `1.3 sqrt(2 d t) * B0`.
Concentration bounds are legitimate for rejection-center sizing (they only
affect completeness/ZK via a restart-if-exceeded rule) and add 2^-64-class
terms to soundness where extraction compares combined honest openings;
both uses flagged, both columns tabulated. The X^d+1 expansion factor is
exactly these operator norms — there is no other place d enters the chain.

**The constraint system** (ring analogues; same solve order as report 11.2):

- C0': challenge differences and their products invertible: LS18 with
  `||diff||_inf <= 4` -> q > 32. (Replaces `q > 2*2^(3b)`.)
- C1': `log2 |C| >= lambda + 2 log2 Q + 1 = 257` -> quinary d=128 (297.2).
- C2: `q > 8 beta` (unchanged; beta from the lifted chain below).
- C3: `k_Z >= (log2 beta / 2)^2 / (log2 q * log2 delta0)`, kappa = k_Z/d.
- C4: `N_Z >= k_Z + msg_Z + 768 log2 q / 11.7` (knapsack MLWE hiding).

Chain (Pi2, mirroring `derive_params_gadget` with `2^b -> op`):
`B_rho_s = combine(rows)`, `B_rho_v = combine(cols)`,
`T^2 = op^2 (B_s^2 + B_v^2) + (op B0 + op^2 B_v)^2`, `sigma = 12 T`,
`B = 1.2 sigma sqrt(3 N_Z)`,
`beta = max(2B + op B_s, 3 op B + op^3 B_v)`. Pi1 analogous with
`T^2 = 2 (op B_rho)^2`, dim 2 N_Z, `beta = 2B + op B_rho`.

**Worked table** (`scripts/route_r_params.py` output; "min log2 q" is the
smallest half-integer modulus with >= 1 bit of C2 headroom):

| shape / protocol | norm model | min log2 q | kappa | N_r (N_Z) | msg_r | log2 sigma | log2 beta | commit/col KB | proof KB (r=1) |
|---|---|---|---|---|---|---|---|---|---|
| demo chain 32x32x64, Pi2 | worst-case l1 | 61.0 | 20 | 52 (6656) | 1 | 39.9 | 56.9 | 20.0 | 129.0 |
| demo chain 32x32x64, Pi2 | concentration | 43.0 | 13 | 36 (4608) | 1 | 25.8 | 38.9 | 9.4 | 61.1 |
| n = 2048 square, Pi2 | worst-case l1 | none <= 62 | — | — | — | — | — | — | — |
| n = 2048 square, Pi2 | concentration | 46.0 | 15 | 54 (6912) | 16 | 28.6 | 42.0 | 22.3 | 117.0 |
| n = 2048 square, Pi1 | worst-case l1 | 50.0 | 16 | 57 (7296) | 16 | 37.5 | 45.7 | 25.0 | 86.4 |
| n = 2048 square, Pi1 | concentration | 37.0 | 11 | 46 (5888) | 16 | 24.6 | 32.6 | 15.6 | 50.4 |
| FFN 512x4096x11008, Pi2 | concentration | 48.0 | 15 | 72 (9216) | 32 | 30.0 | 43.6 | 35.2 | 174.8 |
| opening proof (prototype, q31) | worst-case l1 | 31.0 | 8 | 26 (3328) | 2 | 17.4 | 24.6 | 5.0 | ~15 |

Readings:

- Proof sizes land at 50-175 KB — inside the report Section 17's promised
  50-150 KB band, vs multi-MB on Route Z. This is the r -> 1 lever.
- **q46 covers every shape through FFN scale with concentration bounds**;
  the conservative worst-case discipline needs two limbs for Pi2 and is
  the reviewable fallback, not the recommendation.
- The prototype's q31 opening layer is real: single-commitment claims have
  no m-fold combinations, hence the 22-bit-smaller beta. Anything that
  combines thousands of commitments pays ~sqrt(t) in beta.
- Norms enter only via combination counts (log-insensitive to matrix
  area), same as Route Z: parameters freeze once per deployment family.
- If the gate design settles on chunk-granular s (n_r = 16 combinations
  instead of n = 2048), B_s drops ~11x and Pi2 fits ~2^42; the table's
  row-granular counts are the conservative end.

## 4. The Pi1 general-A-map design point

**The problem, precisely.** Pi1's check (1-ii) has the verifier apply the
public matrix A to a response: `A z_b - z_c = (first message) + c * 0`.
Over R_q the challenge c multiplies commitments ring-wise, and for the
extraction algebra to close the verifier's map must commute with it:
`A(c * x) = c * (A x)`. That holds iff A is R_q-linear, i.e.
block-negacyclic in the coefficient basis. A general d x d block has d^2
degrees of freedom; a ring element has d. General A does not embed.

**Option (a): negacyclic-block embedding.** Express A over R_q and apply
it by ring multiplication. Exact only for block-negacyclic A; a general
block needs the full automorphism basis (`|Gal| = d` terms
`sum_tau a_tau tau(x)`), i.e. d ring products per block — *zero
compression* — and every automorphism twists the challenge algebra
(`tau(c x) = tau(c) tau(x)`). Verdict: use only where A is genuinely
structured over the ring: shift/gadget matrices (powers-of-two
recomposition), convolutions, block-selection maps. Those cover most
gadget-internal linear maps, and there the embedding is free and clean.

**Option (b): coefficient-domain application with ct-extraction
(ALS20/LNP22).** Keep A out of the ring entirely:

1. *Column compression (transcription):* v in C^m ring challenges,
   `x_b := sum_j v_j bpack_j`, `x_c := sum_j v_j cpack_j` — R-linear on
   commitments, per-slot sound (2^-296). Claim: `pack(A unpack(x_b)) = x_c`
   as vectors of length n (packed n_r).
2. *Output compression with uniform theta:* draw `theta in Z_q^{l x n}`
   uniform (FS), `l = ceil(256 / log2 q)` = 6 at q46. The verifier (and
   prover) compute `t_l := A^T theta_l in Z_q^k` — public data, one plain
   matvec of A per row. Each row claim becomes a Z_q scalar:
   `<t_l, unpack(x_b)> = <theta_l, unpack(x_c)>`, with compression error
   q^-l <= 2^-276.
3. *ct-form:* for public w in Z_q^k, `<w, unpack(x)> = ct(sum_u
   sigma_{-1}(w~_u) x_u)` where sigma_{-1}(X) = X^{-1} = -X^{d-1} is the
   conjugation automorphism and w~ is w packed chunk-wise. The inner
   combination is **R-linear in the witness** with public ring
   coefficients — it commutes with the challenge. Only the outer ct() is
   Z-linear, and it is discharged by the ct-engine:
   - prover commits `g in R_q` with `ct(g) = 0` (uniform elsewhere)
     **before** theta is drawn;
   - after theta: reveal `h_l = g_l + f_l(witness)` where f_l is the
     R-linear ct-expression of row l;
   - verifier checks `ct(h_l) = 0` **directly** (deterministic), and the
     ring-valued linear claim "committed g_l plus derived f_l-commitment
     opens to h_l" rides the same masked Sigma round as every other
     linear claim (per-slot sound).
   ZK: g's d-1 free coefficients blind f's junk coefficients; the ct
   itself is 0. Packing multiple rows per g (LNP22 packs up to d/2 via the
   sigma_{-1) pairing) is an optimization, not a correctness need; the
   baseline is one g per theta row (6 extra committed + revealed ring
   elements per Pi1 claim — negligible).

**Exactly which check changes:** Pi1's per-repetition vector check (1-ii)
`A z_b - z_c ?= w + ...` (r = 64 A-matvecs per proof) is **replaced** by:
(i) l = 6 public precomputations `t_l = A^T theta_l`; (ii) l revealed
mask elements h_l with `ct(h_l) = 0` checked coefficient-wise; (iii) one
additional ring-valued linear opening equation binding h to the derived
commitments. Checks (1-i) (commitment opening) and (1-iii) (norm) lift
unchanged in shape. Verifier A-work drops from 64 matvecs to 6 — a
side-benefit of the lift.

**Recommendation: (b)**, with (a) reserved for structured gadget maps.
The argument: (b) is the only option that handles arbitrary A at packing
density 1 with per-slot soundness; its machinery (theta-batching +
ct-masks) is *shared* with the Pi2 gate and the M2 gadget family, so it is
built once; and its verifier cost is strictly better than Route Z's. Its
one real risk — the ct-mask bookkeeping — is exactly the machinery ALS20
and LNP22 publish and test at these dimensions (report Section 17: "it is
also exactly the machinery those papers supply").

**Pi2's gate is the same design point.** The product gate compresses to a
scalar; by finding 2 that scalar cannot carry r = 1 soundness naively.
The lift: compressions `x_a = sum_i s_i apack_i`, `x_b`, and the derived
scalar-key commitment for the compressed C-claim lift by transcription
(the derived-key trick `g_s = s^T G2` becomes `g_s = sum_u s_u G2_u`, same
shape as Route Z's T_t and the M2 mixed keys); the bilinear layer
(garbage terms g0, g1, response inner product) lifts as ring products of
responses; and the final scalar extraction — relating
`ct(sigma(x_a)-conjugated products)` to the committed C coefficients,
junk cross-correlation coefficients absorbed by ct-masks — is the
ct-engine again. The exact junk/mask bookkeeping for *packed matmul* at
k = 2 is this design's highest-risk item (Q1): the objects are all in
ALS20/LNP22 but their composition for the packed-matrix statement needs to
be written out and differentially tested against the Z oracle. Fallback:
mini-repeat the gate layer (r_g <= 8, side-linear, percent-level cost).

## 5. CRT-slot elementwise operations (the M2 mandate)

At k = 2 the two slots are big fields, not d scalar lanes; the
naive "SIMD Hadamard" reading of the M2 report does not exist at this
splitting. What does exist, per gadget class:

**Binary and range/rescale — the 111-second item — do not need slots at
all.** In dense coefficient packing:

- *Binary:* b_t(b_t - 1) >= 0 for every integer, with equality iff
  b_t in {0, 1}. So "all coefficients binary" is the **single Z-scalar
  claim** `<b, b - 1~>_Z = 0` (1~ = all-ones), one quadratic ct-claim per
  tensor via the ct-engine — deterministic, no per-element or per-column
  Sigma-protocol, plus the norm-smallness side condition (the sum must not
  wrap mod q: needs ||b||^2 < q/2-class, i.e. an approximate range bound
  from the same LNP22 toolbox — JL-projection ARP, 256 extra ct-claims per
  tensor, side-linear).
- *Range width W:* commit W bit-tensors dense-packed (d bits per ring
  element), one binary ct-claim each, plus the recomposition
  `value = sum_i 2^i bit_i` — a public Z-linear map, theta-batched into l
  ct-claims per tensor (the powers-of-two map is also negacyclic-friendly,
  so option (a) applies here if preferred).
- *Rescale x = 2^shift y + r:* the zero-opening linear claim lifts by
  transcription (it is R-linear); the two range proofs as above.

Per-element cost model (q46 FFN-scale parameters kappa=15, N_r=72,
msg_r=32; Karatsuba slot kernels ~37 ops/coefficient; commit ops per
committed element `(1 + kappa/msg_r) * N_r * 37 ~ 3900`):

| item | Route Z measured | Route R projected |
|---|---|---|
| rescale W=12, sh=6: commits (value+quot+rem+18 bit-coeffs) | ~4x value commit | ~20 elements' worth: ~80k ops/element |
| rescale family proofs | ~10^6 MACs/element x 2.76 | amortized ct-claims: ~0 per element |
| total per rescaled element | **~108 ms** | **~17 us/element** (80k ops / 4.6e9 MACs/s) |

~6000x, from removing the per-column Sigma floor (r x M x per-rep masks)
and paying only commitment arithmetic. Against the M2 exit criterion: the
demo's 1024 rescaled elements cost ~20 ms of family work vs the ~1 s
matmul claim — **~2%, meeting the <20% criterion with 10x margin** (Route
Z: 13,566%).

**General Hadamard (x o y = z, both hidden) is the one class that needs
multiplicative structure.** x_t y_t - z_t is not sign-definite, so the
binary trick does not apply. Three costed options at k = 2 mandate:

| option | density | mechanism | per-element commit overhead | notes |
|---|---|---|---|---|
| (H1) 2-slot packing | 2/128 | true slot-wise products (prototype-demonstrated) | 64x dense | fine for narrow tensors; disqualifying at LLM scale |
| (H2) Sidon-set packing | ~12/128 | B2 set positions: pairwise coefficient products land at distinct positions of x*y; z read off by a public selection map (ct-claims) | ~10.7x dense | the k = 2 default; products isolate exactly; re-extraction needed per chained op |
| (H3) k = 8 partial split (q = 17 mod 32) | 8/128 | 8 honest slots; LS18 bound q^(1/8)/sqrt(8) > 4 needs only q > 2^28.1; per-slot SZ unchanged (5^-128) | 16x dense | requires modulus-class change; slot-SZ and invertibility for +-4 diffs verified above; products of differences still fine (products of invertibles) |

Recommendation: **(H2) Sidon packing as the k = 2 default**, (H1) for
narrow interim tensors, and the k = 8 variant folded into the k-split
trade study (Q3) — notable because at q46 the k = 8 LS18 margin is still
~19/4 = 4.75x for quinary differences, so the mandate's k = 2 is a
simplicity choice, not the only sound point. Hadamard-heavy workloads
(SwiGLU gates: 2 of ~10 tensors per FFN layer) pay the ~10x density loss
only on those tensors: ~+2x on the layer commit bill, the number that
feeds the Section 7 projection.

**What the packed range proof becomes over slots:** it doesn't — it
becomes the dense-coefficient binary/recomposition family above, which is
strictly better than any slot mapping at k = 2. M2's packed-bits-per-
column trick (bits of a column in one committed column) survives as
"bits of a tensor in d-per-element dense packing"; the swappable range
strategy hook in the manifest gains a third strategy (ARP-only approximate
ranges where the quantized spec tolerates them, at ~zero bit-tensor cost).

## 6. Migration plan

**Survives unchanged (verbatim or near-verbatim):**

- `manifest.rs`: format, operation kinds (Matmul/Equality/Transpose/
  Hadamard/Binary/Range/Rescale), order-sensitive digest, CRS-hash binding.
  Only `key_info`/`commitment_bytes` contents change width.
- Statement-hashing discipline: every challenge derives from
  `H(crs, shape, ctx, all commitment groups)`; ctx = manifest digest for
  chains. The ct-engine adds one rule: mask commitments g enter the hash
  before theta is drawn (same "commitments before challenges" rule).
- Wave scheduling: repetitions disappear, but the wave structure is
  exactly right for batching *claims* and *rejection restarts* (restart
  probability per claim is still 1 - 1/M ~ 0.64): pending-set + blocked
  passes over (A1, A2) lift with r = 1 as "one wave-slot per claim".
- Gadget statement shapes: derived-key scalar commitments (Pi2 T_t, the
  mixed Hadamard keys, transpose g_s/g_v) all lift by replacing scalar
  weights with ring challenges; the M2 negative-test battery transfers
  test-for-test.
- Parameter-derivation structure: the C0-C4 iteration shape, worst-case
  combination counts over shapes, exact-integer norm checks at
  verification. `route_r_params.py` is the reference implementation.
- The Python/Rust dual-track discipline: Route Z stays the differential
  oracle (report Section 17 build order), so `lattice_matmul.rs` is not
  modified — the ring backend is a new sibling.

**Rewritten:**

- Arithmetic layer: `Zq` scalar kernels -> ring kernels (add/sub, ternary
  add/sub specialization, CRT split, Karatsuba slot mult, matvec/matmat
  blocked over ring elements). The prototype's `poly_*`/`slot_*`/
  `ring_matvec_small` are the seed.
- CRS expansion: ring matrices A1, A2 (per-element XOF discipline kept).
- All Sigma-protocol internals: challenge sampling (quinary ring), masks
  (Gaussian over N_Z coefficients), rejection sampling (unchanged
  formula, dimension = coefficient embedding — prototype-validated),
  responses as integer ring vectors, mod-q + exact-norm verification.
- Parameter constants: (b, r) -> (|C|, r=1); LOG2_Q; HIDING_DIM at q46.
- Proof serialization (ring elements; sizes per Section 3 table).
- New shared machinery: the ct-engine (theta rows, g-masks, h reveals,
  packing conventions incl. sigma_{-1} conjugated layouts), Sidon-set
  packing tables, slot utilities.

**Suggested module layout** (bin-collection crate, `#[path]`-shared like
`manifest.rs`):

    zkmatrix-rs/src/ring/mod.rs        // arithmetic: Poly, CRT, Karatsuba, norms, sampling
    zkmatrix-rs/src/ring/params.rs     // C0'-C4 iteration (port of route_r_params.py)
    zkmatrix-rs/src/ring/commit.rs     // BDLOP-style com, CRS expansion, derived keys
    zkmatrix-rs/src/ring/sigma.rs      // masked openings, rejection, wave scheduler
    zkmatrix-rs/src/ring/ct_engine.rs  // theta batching, g/h masks, packing conventions
    zkmatrix-rs/src/bin/ring_matmul.rs // Pi1/Pi2 lift + gadget family + demos + self-tests
    (zk_lattice/ring_*.py mirrors follow the Rust, as for Route Z)

**Effort units** (at the pace this project has sustained; each unit ends
with self-tests + suite green + a doc note):

| unit | contents | estimate |
|---|---|---|
| U1 | ring arithmetic module + Karatsuba + differential tests vs prototype naive kernels | 2-4 days |
| U2 | commitment + opening proofs + params port (prototype exists; q46 constants) | 2-3 days |
| U3 | ct-engine: theta batching, g/h masks, ARP; unit-proofs against Z oracle | 1-2 weeks |
| U4 | ring-Pi1 (option b A-map) end-to-end + negative battery | ~1 week |
| U5 | ring-Pi2 gate (ALS20/LNP22 product layer; fallback r_g mini-repetition kept behind a flag) | 2-3 weeks (highest risk) |
| U6 | M2 gadget family re-map (binary/range/rescale via ct-claims; Sidon Hadamard) | ~1 week |
| U7 | manifest/chain integration, wave batching, Z-oracle chain demos | ~1 week |
| U8 | estimator sign-off (MSIS/MLWE at q46), parameter freeze, perf pass | 2-3 days |

Total: **6-9 weeks**, consistent with the estimate's 4-8 week line item
once U5's risk is priced in. U1-U3 are unblocked today; U5 should start
with a one-page writeup of the gate equations reviewed against ALS20
before code.

## 7. Revised projections (with reasoning)

**(a) M2 gadget family, per element.** Route Z measured 108 ms/element
(range/rescale, W=12). Route R: the Sigma floor disappears (ct-claims
amortize to ~zero per element); the cost is bit-tensor commitment
arithmetic: ~20 committed elements' worth per rescaled element x ~3,900
ops each ~ 80k ops -> **~17 us/element** on today's CPU kernels
(~6,000x; ~2% of the demo matmul claim vs criterion <20%). Even with
worst-case (non-Karatsuba) kernels it stays <40 us. Hadamard elements pay
the H2 density factor: ~10x that, still ~10^2-10^3x under budget. The
Class-3 mandate is met by design, not by kernel tuning.

**(b) n = 2048 Pi2 claim.** Route Z measured: prove 2.41-2.84 s, verify
1.29 s, commit 19.4 s, proof multi-MB (r = 64, M = 2.76).
Route R at q46 (kappa=15, N_r=54, msg_r=16), ops accounting:

- prove: combinations x_a/x_b/tau_v ~ 3 x 2048 x 16 ring mults ~ 98k ring
  mults x ~4.8k ops ~ 4.7e8 ops ~ 0.1 s; mask commits ~ (15+16) x 54 x 4
  ring mults x M ~ 2.76 ~ 9e7 ops ~ 0.02 s; gate/ct layer smaller. 
  **~0.1-0.2 s (~15-25x faster; ~5-10% of the 1.88 s raw mod-q matmul)**.
- verify: one blocked pass over the same objects: **~0.1 s (~10x)**.
- proof size: **~117 KB (vs multi-MB, ~25-50x)**.
- commit: ring ~3,900 ops/element (Karatsuba) vs Route Z ~11,300
  MACs/element at this shape: **~2-3x fewer ops — NOT the 15x of the
  estimate** (finding 3: k = 2 has no d log d transform). Projected
  n = 2048 commit ~7-9 s vs 19.4 s measured. Ternary add/sub and GPU
  levers apply to both routes roughly equally on top.

**LLM-scale consequence (correcting `LLM_SCALE_ESTIMATE.md` Section 3).**
The "+ Route R" table row assumed ~15x commit-op reduction; recomputed at
k = 2 it is ~2-3x: commit bill ~25-35 min after Tier-1 (was ~1.2 h),
claim proofs hour-scale -> minutes, gadget proofs -> noise. Endpoint after
GPU (20x) and bit-packing: **~2-4 min per 7B/512-token pass, i.e. ~20-35x
quantized-CPU inference — not the ~2x the table promised.** The Section 3b decomposition still
identifies the path to ~2x: commit ops/element (~3,900 at q46 ring, ~8-11k
Route Z) must come down to the few-hundred class, which requires either
the k-split trade (fuller splitting + ALS20-style soundness rework, giving
real d log d kernels) or response decomposition shrinking q and dims (Q2).
The 2x target is therefore **gated on Q2/Q3, not on Route R as mandated
(k = 2)**. Verification stays milliseconds-to-subsecond and proof sizes
drop to KB across the board regardless.

## 8. Prototype evidence (Deliverable 2)

`zkmatrix-rs/src/bin/ring_lattice.rs` (standalone bin, ~880 lines, no
changes to existing files; `cargo run --release --bin ring_lattice`):

- Ring arithmetic at (d=128, q31): add/sub/mul, naive negacyclic kernel
  cross-checked against the two-way CRT split; coefficient norms; ternary/
  quinary/Gaussian sampling. Timings (approximate): ring mul 18-31 us
  naive, slot mul 2.6-9.1 us.
- LS18 in practice: 200 challenge differences inverted explicitly (CRT
  ext-gcd, `inv * diff = 1` verified); zero-divisor negative control.
- 2-slot Hadamard demonstrated (slot-packed constants multiply slot-wise).
- Toy module commitment `(A1 rho, A2 rho + x)`, kappa=8, N_r=26, msg_r=2;
  in-code C0-C4 assertions (beta = 2^24.6, q > 8 beta at 3.4 bits
  headroom, C3 k_Z = 912 <= 1024, C4 satisfied).
- One complete r = 1 Sigma round (report Alg. 1 / Section 5.5 shape):
  quinary FS challenge, exact-integer rejection sampling (alpha = 12,
  M = 2.76; observed 4 attempts), verification = mod-q ring checks + exact
  l2 norm. Battery: valid passes; tampered response / tampered first
  message / wrong context / wrong statement all fail; **+q norm-overflow
  response caught only by the exact-norm check** (the Route Z battery's
  sharpest case, reproduced at ring level); honest-case 2-transcript
  extraction recovers rho exactly via LS18 inversion; prove ~55-105 ms,
  verify ~11 ms, proof ~15 KB.

## 9. Open questions, ranked by risk (Deliverable 3 summary)

1. **Q1 — Pi2 gate bookkeeping at k = 2** (junk cross-correlation
   coefficients vs committed C; exact ct-mask composition for packed
   matmul). Known-machinery adaptation, not invention (ALS20/LNP22), with
   a cheap sound fallback (r_g mini-repetition of the gate layer only).
   Risk: schedule, not feasibility. Mitigation: U5 starts with equations
   on paper reviewed against ALS20 Fig. 2-3; Z-oracle differential tests.
2. **Q2 — modulus class and the 2x endpoint.** q46 vs 32-bit-class:
   response decomposition (Dilithium-style) would shrink q, kappa, N and
   with them the commit bill; it reworks Lemma 6.3. This decides whether
   the LLM-scale endpoint is ~20-35x or approaches the promised ~2x.
3. **Q3 — the k-split trade study.** k = 2 (mandate) has the invertibility
   margin and the simplest soundness story but no fast transforms and only
   2 slots; k = 8 (q = 17 mod 32) keeps quinary LS18 invertibility
   unconditional (verified above), keeps per-slot SZ at 5^-128, gives 8
   slots and one more CRT level; full splitting gives d log d kernels and
   dense slot-Hadamard but needs the ALS20 automorphism soundness rework.
   Decides finding 3's commit-kernel penalty and H3.
4. **Q4 — concentration-bound formalization.** Restart-on-oversize
   discipline and the 2^-64 soundness surcharge need a written lemma
   (extension of Lemma 6.3); worst-case fallback costs two-limb q for Pi2.
5. **Q5 — estimator sign-off.** C3/C4 are design models (report's own
   caveat); MSIS/MLWE at (kappa, N_r, q46, beta) need lattice-estimator
   validation; expect tens-of-percent movement in kappa/N_r.
6. **Q6 — kernel engineering at q = 5 mod 8.** Karatsuba/AVX-512 IFMA slot
   kernels, u128-free lazy reduction at 46 bits, GPU RNS mapping at 2.4x
   the 30-bit int8-GEMM count. Pure engineering.

**Recommended implementation order:** U1 -> U2 -> U3 (unblocks everything;
Q4 lemma written during U3) -> U4 (Pi1, option b) -> U6 (gadgets; the M2
mandate is met here already) -> U5 (Pi2 gate, with the r_g flag as the
pressure valve) -> U7 -> U8 (Q5), with the Q2/Q3 trade studies run as
paper studies in parallel with U3-U5 since they gate the LLM-scale
endpoint, not the M3/M4 milestones.
