# M4 Lookup-Argument Literature Review: What the Field Offers for int8 SiLU at 1.8e8 Elements

Status: COMPLETE — literature review tranche (searched and read
2026-07-09; primary papers read in full wherever costs are quoted).
Companion to
M4_ACTIVATION_DESIGN.md (the piecewise baseline this review must beat:
~105 committed-element-equivalents per activation element, against a
Class-3 budget of <= ~2-4 per element, i.e. <20% of the pass commit
bill), TRANSFORMER_PROOF_PLAN.md Section 2 (the Class-3 problem
statement), GATE_ALTERNATIVES.md (option 2, the hash-based sumcheck
fallback this review interacts with), LLM_SCALE_ESTIMATE.md (the cost
ladder: 15-30 s/7B pass today, 5-15 s target).

## Executive verdict

The literature CONFIRMS the lookup track and sharpens it to one
construction. Recommendation (a): adapt **LogUp-GKR** — Habock's
logarithmic-derivative lookup (ePrint 2022/1530) with the
Papini-Habock GKR fractional sumcheck (ePrint 2023/1284) — as a
fused-pair lookup into the 256-row int8 SiLU table. It fits the
lattice setting because the whole identity is mod-q (no norms, no
pairings, FS-in-ROM), it already runs in production over hash
commitments at our exact field size (Stwo/SP1), and its committed
cost is ONE table-length multiplicity column: **~0 dce per
activation element** (vs 105 incumbent, budget 2-4), paying instead
~43 extension-field mults/el of prover time (~10-30 s at 22T per 7B
pass [MODEL], GPU-friendly) plus two build obligations shared with
the GATE_ALTERNATIVES hash-sumcheck fallback: a sumcheck/GKR
transcript layer over GF(q^e) and MLE-evaluation claims against
dense lattice commitments. Fallbacks, in order: tlookup-style
committed inverses (~6 dce/el, no GKR needed); Shout-style d=8
read-checking over the chain-native input bit planes (~0 dce/el, no
characteristic ceiling). Full verdict with arithmetic: Section 6.

## PROGRESS

- [x] Q1a: LogUp + LogUp-GKR (papers read in full, costs extracted)
- [x] Q1b: cq, plookup lineage, Lasso/Jolt, tlookup details,
      Twist/Shout, lattice-native 2024-2026 (LatticeFold/+,
      Neo/SuperNeo, FLI, Greyhound)
- [x] Q2: deployed zkML systems' nonlinearity strategies
- [x] Q3: alternative strategies worth pricing
- [x] Q4: amortization profiles across ~1e8 lookups of one table
- [x] Q5: int8 / exp-at-12-16-bit quantization tricks
- [x] Executive verdict
- [x] References
- [x] "What we did not find"

(All boxes checked: the review ran to completion; every section is
citable as written.)

## 0. Ground rules for the cost arithmetic

Every construction below is priced in the LLM_SCALE_ESTIMATE unit:
**dce** = dense q31-coefficient element-equivalents of *commitment*
cost (1 dce = one committed Z_q coefficient in a dense-packed ring
element; one H3 slot-packed value = 16 dce; one q46 plane coefficient
= 1 dce). The workload is fixed throughout: N = 1.8e8 int8 SiLU
lookups into ONE shared table of T = 256 (input, output) pairs per
7B/512 pass, on a pass whose baseline commit bill is ~9.4e9
element-equivalents. The budget is <= ~2-4 dce per activation element
(the Class-3 "<20% of the pass" criterion); the incumbent piecewise
design costs ~105 dce/el, and the exact one-hot table (Variant B)
costs 256 dce/el.

Two facts about our engine that decide transferability:

- The base field is Z_q with q = 2^31 - 399 (prime, so Z_q is a field
  of characteristic ~2^31), and the CRT slot structure already
  implements the degree-16 extension field GF(q^16) — 8 independent
  GF(q^16) slots per ring element, with slot-wise multiplication
  being ring multiplication. Any lookup argument that needs "a large
  field" can get one, either as GF(q^16) via slots or as an explicit
  GF(q^e) tower over Z_q.
- Lookup identities of the logarithmic-derivative family are **pure
  mod-q statements** — unlike range gadgets they need NO integer
  non-wrap accounting and NO norm bounds, because the certified
  relation ("this committed value equals some table value mod q")
  combines with the chain's existing range proofs (int8 inputs are
  already range-proved upstream) to give the integer statement for
  free. This is why they escape the bit-plane cost floor.

## 1. The logarithmic-derivative family (LogUp, LogUp-GKR, tlookup)

### 1.1 LogUp — the fractional-sum identity

**What it is.** LogUp (Habock, ePrint 2022/1530) replaces the
grand-product ("multiset") identities of the plookup lineage with the
formal logarithmic derivative: a witness column w of N values lies in
a table t of T values iff there is a multiplicity vector m with

    sum_{i=1..N} 1/(alpha - w_i)  =  sum_{j=1..T} m_j/(alpha - t_j)

as rational functions of alpha; the verifier samples alpha at random
from a large enough field and the identity is checked as a "fractional
sumcheck". The one structural precondition is that the TOTAL number of
looked-up elements stays below the field characteristic (else
multiplicities can wrap): for us N = 1.8e8 < q ~ 2.1e9 — satisfied
with a ~12x margin at 7B/512, but a fact to re-check per statement
(it fails around T = 6000 tokens at this activation volume if all
lookups share one table instance; splitting into per-layer table
instances removes the ceiling entirely).

**Committed data (the elementary variant).** The prover commits
(i) the multiplicity column m — length T, i.e. 256 values TOTAL per
table, amortized to ~1.4e-6 dce/el across N = 1.8e8 lookups — and
(ii) *helper columns*: multilinear h_i agreeing with 1/(alpha - w_i)
on the hypercube, one column of length N per batch of witness columns
(a tunable trade between helper-column count and the algebraic degree
of the sumcheck identity; Habock Sections 3.2-3.3). The helper values
live in the extension field the challenge alpha is drawn from. For a
single fused (input, output) column — see 1.4 — that is ONE length-N
extension-field column.

**Soundness.** Statistical: error ~ (M+1)*N / (|K| - N) for the
fractional-identity reduction plus the sumcheck's ~3*log(N)/|K|
(Habock Lemma 5 / Papini-Habock Prop. 2), K the challenge field. For
N = 2^27.5 and a 2^-128 target, |K| >= ~2^156: over q31 that is a
degree-6 extension GF(q^6) (2^186, comfortable) or the slot field
GF(q^16) (2^496, free-riding on existing kernels). No computational
assumption beyond the commitment scheme's binding: the IOP part is
field-agnostic and transplants to ANY commitment that can serve
evaluation/linear-functional claims — this family is exactly the
"polynomial-IOP parts transplant onto sumcheck-over-hash or the ring
engine" case the review was asked to find.

**Cost in our units.** Helper column = 1 extension-field value per
element = e base-field coefficients, dense-packable: **e = 6 dce/el
(GF(q^6)) to 16 dce/el (GF(q^16) slots)**, plus ~0 for multiplicities.
Within an order of magnitude of budget but not inside it; the GKR
variant below removes exactly this term.

### 1.2 LogUp-GKR — the variant that actually fits the budget

**What it is.** Papini-Habock (ePrint 2023/1284) prove the fractional
sumcheck with the Goldwasser-Kalai-Rothblum (GKR) protocol — an
interactive proof over a layered circuit that needs NO commitments to
intermediate wires — instead of committing helper columns. The
fractions are summed up a binary tree in projective coordinates
(numerator, denominator), one GKR/sumcheck round per tree layer.

**Committed data.** Quote (Section 4): "the prover only needs to
provide a single additional column, the one for the multiplicities."
Everything else is transcript, not commitment. Marginal committed
data: **~0 dce/el** (256-entry m column per table + nothing per
element).

**Prover cost.** Counted precisely in the paper (Eq. 5-6): ~**43
extension-field multiplications + 29 additions per looked-up
element** for the entire fractional GKR, about 2x the field work of
the elementary variant, in exchange for eliminating all helper
commitments. The paper's own forecast: with elliptic-curve
commitments the trade wins >= 10x; with hash/Reed-Solomon
commitments 2-10x. With lattice commitments at our measured ~119
helper-prime multiplications per committed element — and 16x that
for slot-packed data — the trade is similarly one-sided.

**Final claims.** The GKR run reduces everything to evaluation claims
of the multilinear extensions (MLE — the unique multilinear
polynomial agreeing with a vector on the Boolean hypercube) of the
witness column(s), the table, and m at ONE random extension-field
point. This is the entire transplant surface: the ring engine must
certify "committed dense tensor w, evaluated as an MLE at public
point r, equals claimed v" — an inner product of the committed
coefficients with the PUBLIC tensor vector L(x, r), i.e. a
public-weight linear functional of a dense-committed tensor, the same
claim shape as the engine's existing ct-claim/link rows (mod-q only,
no integer accounting needed since the whole identity is mod-q).
Soundness error and field requirements as in 1.1.

**Verdict for our setting: the construction to adapt.** Marginal
commitment ~0 dce/el; prover field work ~43 GF(q^e) mults/el — using
the slot field GF(q^16), 8 slot-mults ride one ring mult, so this is
~5-6 ring mults/el, order 1e9 ring mults/pass, tens of seconds CPU /
seconds GPU class, NOT a commit-stream cost. The open engineering is
(a) a sumcheck/GKR transcript layer over Z_q extensions (new code, no
new cryptography — Fiat-Shamir in the random-oracle model, already
our model), and (b) the MLE-evaluation claim against lattice
commitments (new claim wiring, existing machinery class). Both are
also exactly what GATE_ALTERNATIVES option 2 (hash-based sumcheck
gate) needs — one sumcheck engine serves both.

### 1.3 tlookup (zkLLM) — the same identity, engineered for tensors

**What it is.** tlookup (Sun-Li-Zhang, zkLLM, ACM CCS 2024) is
exactly the LogUp lemma (their Lemma 4.1 cites Habock) packaged for
tensor workloads over a sumcheck backend with Hyrax commitments (a
Pedersen-style multilinear commitment on the BLS12-381 curve,
|F| ~ 2^254). Protocol 1 of the paper: the prover commits the tensor
S (length D), the multiplicity vector m (length N_table), and the
two inverse tensors A_i = 1/(beta + S_i) (length D) and
B_j = 1/(beta + T_j) (length N_table) after the challenge beta; ONE
degree-3 sumcheck (their Eq. 14) then simultaneously proves that A
and B are the claimed inverses and that sum A_i = sum m_j B_j,
ending in evaluation claims on the commitments of A, B, S, m, T.
Function lookups use the fused-pair reduction of 1.4 (their
Example 4.2 does ReLU-with-rescale as two tables, O(B + gamma)
instead of the naive O(B * gamma) single-table blowup — the same
split-the-domain economics as zkAttn below).

**Committed data.** Per looked-up element: ONE field element — the
inverse A_i — in a ~254-bit field, plus amortized table-side data
(m, B: 2 * N_table). tlookup is therefore the "elementary LogUp"
point of Section 1.1, engineered for GPU: helper column committed,
no GKR.

**Cost in our units.** The inverse lives in whatever field the
challenge beta is drawn from. Transplanted to our engine that is
GF(q^6) (soundness 1.1) at dense packing: **~6 dce/el**, or GF(q^16)
slot-native at 16 dce/el. 6 dce/el is 17x cheaper than the piecewise
design but still ~2x over the top of the 2-4 budget; it is the
"skip the GKR engineering" fallback point, and LogUp-GKR strictly
dominates it in committed bytes at the price of the GKR transcript
layer.

**What breaks / changes on a lattice backend.** Nothing structural:
the identity is field-agnostic and the paper's own sumcheck is the
transplant surface. What changes is (a) the challenge field must be
built as an extension of Z_q (they get largeness for free from the
curve's scalar field), and (b) their Hyrax evaluation proofs must be
replaced by our MLE-evaluation claims (same requirement as 1.2).
Their measured numbers (A100 40GB, CUDA): LLaMa-2-7B full-inference
proof in 620 s, 183 kB proof, 15.5 GB memory; 13B in 803 s / 188 kB
(their Table 1) — commitment time additionally 531 s / 986 s. Not
PQ (discrete log), and the numbers do not transfer to lattice
commitments — quoted here as evidence the log-derivative route
scales to real LLM volumes, not as a cost prediction for us.

### 1.35 The plookup lineage and cq — where the pairing setting parts ways

**plookup** (Gabizon-Williamson, ePrint 2020/315) is the multiset-
equality ancestor: witness values are in the table iff the sorted
concatenation of witness and table "steps through" table values, an
identity proven with a grand-product accumulator. Committed extras:
~3 auxiliary polynomials of degree ~(N + T) — call it **~3 dce/el**
of base-field committed data — with no large-field requirement (the
SoK of Hafezi-Anthoine-Campanelli-Fiore, ePrint 2025/1876, notes
VerITS runs plookup over a field of size 2^31 - 1, our exact field
class, and RISC0 runs it over hash-based commitments). plookup is
transplantable and its constant is *within sight* of budget, but the
grand-product accumulator is sequential (an N-long running product —
awkward for our batched, GPU-leaning prover), and LogUp strictly
improves the committed-column count (Habock's stated 3-4x fewer
oracle commitments at 20 columns). Historical anchor, not the pick.

**cq** ("cached quotients", Eagen-Fiore-Gabizon, ePrint 2022/1763)
is the log-derivative identity compiled for KZG (the
Kate-Zaverucha-Goldberg pairing-based polynomial commitment): after
an O(T log T) preprocessing of the table, the prover runs in
O(N log N) *group* operations independent of table size, with
constant-size proofs (8-ish group elements). Every step of that
compilation — cached quotient commitments, pairing checks, trusted
setup — is pairing-specific. **Not transplantable**: what survives
outside pairings is exactly the LogUp lemma it builds on (the SoK
classifies cq under "Logup-based"), and for our tiny table the
table-size independence cq buys is worthless anyway (T = 256 is
already free). Recorded to close the question, and because its
successors (mu-seek, ePrint 2025-class) stay pairing-bound.

### 1.36 Lasso, Jolt, and Twist/Shout — the "pay only for what you use" family

**Lasso** (Setty-Thaler-Wahby, ePrint 2023/1216, EUROCRYPT 2024)
proves N lookups into a table of size T by committing, at parameter
c = 1, **N + T field elements, all small** (values in {0..N}): per
lookup, essentially one read-counter, plus final per-cell counts —
offline memory checking (Spice-lineage) with grand products proven
GKR-style. For giant *decomposable* tables (c > 1) the cost is
3cN + alpha*T^(1/c) committed small elements, and nobody ever
commits the table — the "lookup singularity"/"pay only for what you
look up" property. It works with ANY multilinear polynomial
commitment scheme (their explicit design goal), so the IOP
transplants; the "small values are cheap" advantage, however, is an
MSM (multi-scalar multiplication) fact about curve commitments and a
bits-committed fact about hash schemes — our dense lattice commit
kernel prices a coefficient the same whatever its value, so Lasso
c = 1 lands at **~1-2 dce/el** (one ~28-bit counter per lookup,
dense-packable, plus table-side columns), plus grand-product
transcript work. **Jolt** (Arun-Setty-Thaler, ePrint 2023/1217) is
the zkVM built by running ~all of RISC-V through Lasso lookups —
evidence of the paradigm at scale, no new per-lookup economics.

**Twist and Shout** (Setty-Thaler, ePrint 2025/105) supersede Lasso.
Shout (read-only memories = lookups) commits, per lookup, a
d-dimensional **one-hot address encoding**: d chunks, each a
one-hot vector of length T^(1/d) — total d*T^(1/d) committed BITS
per lookup, with the read value never committed (a "virtual
polynomial" evaluated inside one sumcheck of degree ~d against the
table's multilinear extension). Their Figure 3/4 numbers: for
structured tables, Shout d = 2 commits 2 nonzero values and ~42
field mults per lookup; the paper measures >=2-10x prover
improvements over Lasso/Spice, and booleanity checking costs ~3dN
field mults (or is free under commitments that enforce bit-ness,
e.g. Binius). Soundness: sumcheck + Schwartz-Zippel over a large
(extension) field; any multilinear PCS.

**What Shout means in our units.** The one-hot chunks are exactly
our q46 indicator planes, so a dense-committed Shout at T = 256 is:
d = 1 -> 256 planes/el (= Variant B, 256 dce/el); d = 2 -> 32;
d = 4 -> 16; **d = 8 -> 16 planes/el of which ALL EIGHT pairs are
the bit/complement planes of the input's existing binary
decomposition — i.e., ~0 NEW committed data**, because at
T^(1/d) = 2 a one-hot pair (b, 1-b) is determined by the chain-native
input bit planes xb_i the upstream rescale already commits. The
read-checking sumcheck then proves y_i = sum_v T[v] * prod_j
(selector bit j of v matches x's bit j) — a degree-9-ish sumcheck
with NO committed intermediates, ~60-110 field mults/el (their
Section 7.5 formula (7C + d^2 + 3d + c + 2)T, or the Appendix C
linear-in-d variant (8d - 7.5)T). This is the second route — besides
LogUp-GKR — by which the 2025 literature reaches "approximately zero
marginal commitment, one sumcheck engine" for exactly our workload
shape. The caveat is the same: everything rides on (i) a sumcheck
transcript layer over GF(q^e) and (ii) MLE-evaluation claims against
lattice commitments; and Shout additionally wants the *complement*
selector algebra to stay cheap, which for base-2 chunks it is.

### 1.37 The lattice-native line: LatticeFold, LatticeFold+, Neo/SuperNeo, FLI, Greyhound

This is the "did 2024-2026 produce a lattice-native lookup?" answer,
and it is: *not as a standalone gadget — as folding-scheme
machinery*, in three steps.

**LatticeFold** (Boneh-Chen, ePrint 2024/257) — folding (Nova-class
recursive accumulation) over module-SIS Ajtai commitments, with
range/norm control done by **bit/low-radix decomposition** of
witnesses before folding: the lattice cost model we already live in
(committed planes per value), and its authors note the sumcheck at
its core can host Lasso-style lookups. No per-lookup improvement
over our Variant-A/B economics.

**LatticeFold+** (Boneh-Chen, ePrint 2025/247) replaces the bit
planes with a **monomial-embedding range proof**: value f_i is
committed a second time as the ring monomial X^(f_i), whose
Ajtai commitment is fast to compute (0/1 coefficients), and a
"monomial set check" plus one algebraic relation pins f_i to
(-d/2, d/2). Structurally this is a one-hot indicator over the 128
coefficient positions of one ring element — in our dense accounting
**~128 dce/el**, Variant-B-class; the paper's win is prover SPEED
and folding-friendliness under sparse/small-norm commit kernels, not
committed-coefficient volume. It is a range gadget, not a function
table: mapping x -> SiLU(x) is not expressible as monomial-ness of
one committed object. Verdict: the technique that matters here is
its *sparse-commit* observation, not the gadget.

**Neo** (Nguyen-Setty, ePrint 2025/294) and **SuperNeo** (ePrint
2026/242) — lattice (module-SIS) folding for CCS over small fields
with **pay-per-bit Ajtai commitments** (commit cost scales with the
bit-size of the message, so one-hot/bit data is cheap to COMMIT),
plus norm-preserving embeddings so the sumcheck runs field-native.
Neo Section 1.4 says explicitly that Shout folds into it: "we can
use Shout's reduction to fold lookup relations alongside CCS." So
the honest 2026 state of the art for lattice-native lookups is
**Shout-over-pay-per-bit-Ajtai inside a folding scheme**. For us
this is a whole-protocol alternative, not a gadget: our engine's
ABDLOP/LNP22-class openings and ARP masking are DENSE — a one-hot
witness of 256N bits still pays dense masking/response costs in our
Sigma-protocol layer, so Neo's pay-per-bit economics do not arrive
by swapping a kernel; they arrive by adopting folding-style
commitment handling. Recorded as the structural competitor to
watch, not the M4 move.

**FLI** (Garreta-Manzur, ePrint 2024/1531, ASIACRYPT 2024) — folds
lookup instances by committing the one-hot selector MATRIX rows;
same one-hot economics as Shout (the Twist/Shout paper credits it as
the closest prior work), curve-instantiated in the paper; nothing to
transplant beyond what Shout already gives.

**Greyhound** (Nguyen-Seiler, ePrint 2024/1293, CRYPTO 2024) — not a
lookup argument but the first concretely efficient lattice
POLYNOMIAL commitment: evaluation proofs of ~53 KB at degree 2^30,
sqrt-time verifier, built on LaBRADOR recursion. Relevant to M4 only
as an existence proof that "MLE/polynomial evaluation claims against
lattice commitments" — the one primitive both LogUp-GKR and Shout
reduce to — is a solved problem class in the literature; our own
ring-claim engine can serve the same claims without importing
LaBRADOR, since an MLE evaluation at a public point is a
public-weight linear functional of the committed coefficients
(mod-q only, no integer accounting).

### 1.4 Pair lookups (input, output) — how a function becomes a table

All of the above check set membership of single values. A function
table ("y = SiLU_int8(x)") is certified by the standard fusion: the
verifier draws kappa from K and the lookup runs on the fused column
w_i = x_i + kappa * y_i against the fused table t_j = v_j + kappa *
T[v_j]. A fused mod-q match pins (x_i, y_i) to a real table row
except with probability ~T/|K| per element (union bound ~N*T/|K|,
still negligible at |K| >= 2^156). Both x and y are committed
already in the baseline chain (x range-proved upstream; y is the
downstream operand), so the fusion adds NO committed data — the
fused column is a public linear combination of two existing
commitments, and its MLE evaluation is the same linear combination
of their MLE evaluations.

## 2. How deployed zkML systems certify nonlinearities

The through-line of this section: the field moved from
model-changing tricks (2017), to bit decomposition (2021), to lookup
arguments (2023-2024), to lookup-plus-sumcheck with minimal
committed data (2025-2026) — the same trajectory our M2 -> M4
documents retraced internally. Systems are listed chronologically;
"what breaks on lattice" is called out per system.

**SafetyNets** (Ghodsi-Gu-Garg, NeurIPS 2017, arXiv 1706.10268) —
interactive GKR-style proofs (no zero-knowledge) over sumcheck; it
handles nonlinearities by NOT having any: the model is retrained
with quadratic activations and sum pooling so everything is
arithmetic. The historical lesson stands: changing the model is the
one strategy our plan already ruled out (the statement must be the
declared quantized spec of the model people actually run).

**vCNN** (Lee-Choi-Kim-Oh, ePrint 2020/584) and **pvCNN**
(Weng et al., 2023) — pairing-based QAP/QPP SNARKs; convolutions get
a clever polynomial encoding (vCNN: 18,000x over vanilla QAP on
VGG16), but activations stay ordinary comparison circuits inside the
QAP (bit decomposition). Pairing setting; nothing here transplants
beyond what our M2 gadgets already do.

**ZEN** (Feng-Qu-Ho-Papamanthou-Katz, ePrint 2021/087) — Groth16
R1CS with "quantization-friendly" encodings: sign-bit grouping and
remainder-based verification remove most explicit bit
decompositions from the quantize/requantize steps. The R1CS
comparison for ReLU remains. Pairing-based; the quantization-aware
encoding IDEAS (avoid materializing bits when a remainder witness
suffices) are already reflected in our chain design (the rescale
gadget witnesses remainders, M2).

**zkCNN** (Liu-Xie-Zhang, ACM CCS 2021, ePrint 2021/673) — GKR over
the Virgo transparent (hash-based) polynomial commitment; the
closest published ancestor of our hash-sumcheck fallback. ReLU: the
prover supplies the bit decomposition of |x| plus a sign bit as
auxiliary committed input — Q+1 committed values per activation
element (Q = quantization bits) — checked by booleanity and
recomposition identities inside GKR (their Section 4.3). That is
~9-17 committed elements per activation element, the same cost class
as our chain-native range planes (~13 dce/el), and it is exactly the
design point the lookup literature then beat. Transplant: trivially
compatible in spirit (hash commitments, sumcheck); it simply never
got the lookup upgrade.

**Mystique** (Weng-Yang-Xie-Katz-Wang, USENIX Security 2021, ePrint
2021/730) — VOLE-based interactive ZK (designated verifier, not
publicly verifiable): arithmetic/Boolean conversions per
nonlinearity. Wrong deployment model for us (we need publicly
verifiable, non-interactive), and its per-activation cost was the
one the next paper measured itself against:

**Hao et al.** ("Scalable Zero-knowledge Proofs for Non-linear
Functions in Machine Learning", Hao-Chen-Li-Weng-Zhang-Yang-Zhang,
USENIX Security 2024; ePrint 2025/507) — same VOLE setting, but
replaces Boolean circuits with **table lookups plus digital
decomposition into 5-12-bit limbs**, covering ReLU, sigmoid, GELU,
softmax, normalization: measured **50-179x runtime improvement over
Mystique** (ReLU ~100x, softmax ~179x, GELU ~77-86x). This is the
cleanest published measurement of "lookup replaces bit
decomposition" as a like-for-like swap inside one proof system —
the ratio we are counting on (105 dce/el -> ~0-6 dce/el is the same
order). VOLE itself does not transplant (interactive, designated
verifier); the decomposition-into-limbs pattern does.

**ezDPS** (Wang-Hoang, PoPETS 2023, ePrint 2022/1456) — Spartan +
Hyrax for a classical-ML pipeline (DWT/PCA/SVM); nonlinearities via
auxiliary witnesses and range checks. Curve-based; small models;
no per-activation numbers relevant at our scale.

**zkML / Kang et al.** (arXiv 2210.08674) and **ZKML**
(Chen-Wang-Abhyankar et al., EuroSys 2024) and **EZKL** (production
framework) — the halo2 lineage: nonlinearities (ReLU, softmax
division, GELU) are handled with **plookup-class lookup tables over
Plonkish columns**; Kang et al. proved MobileNet-v2/ImageNet with
proof size ~6 KB. EZKL's documented limitation is instructive: its
tables "cannot be materialised for large ranges," so ops are
restricted to small-value/int8-class domains — i.e., production
zkML already lives at exactly our table size (2^8-2^16). The halo2
lookup is univariate (multiplicative subgroups, KZG or IPA
commitments); transplanting it would mean rebuilding univariate
polynomial machinery we do not have — the multivariate/sumcheck
LogUp line supersedes it for our purposes.

**Zator** (Chen et al., 2023, github.com/lyronctk/zator) — Nova
folding, one CNN layer per fold (512 layers, ~2.5e9 constraints
total, ~10k constraints recursion overhead per step); ReLU as R1CS
constraints inside each folded step. Curve-based (Pasta curves);
demonstrates folding-for-depth, not cheap nonlinearities.

**zkLLM** (Sun-Li-Zhang, ACM CCS 2024) — Section 1.3. The direct
precedent: log-derivative lookups (tlookup) for every nonlinearity,
the zkAttn limb decomposition for softmax's exp (Section 5.2 below),
and notably SiLU/Swish handled by REUSING the exp machinery
(Sigmoid(z) = Softmax over {z, 0}), because at their >8-bit
activation precision a direct table was too big. At OUR int8 spec a
direct 256-row pair table is strictly simpler.

**zkGPT** (Qu-Sun-Liu-Lu-Guo-Chen-Zhang, USENIX Security 2025,
ePrint 2025/1184) — GKR-based, non-interactive; GPT-2 (124M)
end-to-end in **under 25 s, 101 KB proofs**: a "result-as-witness"
paradigm for softmax/LayerNorm/GELU (commit the claimed output,
prove consistency with cheap fused range checks rather than
recompute the function in-circuit) plus constraint fusion/circuit
squeezing to cut range-check overhead. Curve-based commitments;
the meta-lesson transplants: at transformer scale the winning
systems spend their design effort MINIMIZING COMMITTED AUXILIARY
DATA per nonlinear element, which is precisely the axis on which
LogUp-GKR/Shout win.

**Jolt Atlas** (Benno-Centelles-Douchet-Gibran, arXiv 2602.17452,
Feb 2026) — verifiable ONNX inference built directly on the Jolt
zkVM's lookup machinery (sumcheck-based; Twist/Shout lineage), with
"neural teleportation" to shrink activation lookup tables while
preserving accuracy; reports practical proving for embedding models
and small LMs. Curve-committed today; its existence confirms the
industry direction: inference proving as ALL-LOOKUPS.

**NANOZK** (Wang, arXiv 2603.18046, Mar 2026) — layerwise LLM
proofs with lookup-table treatment of softmax/GELU/LayerNorm that
"preserves perplexity exactly"; toy dimensions (d = 128) but 70x
smaller proofs than EZKL per layer. Same direction, same verdict.

**What breaks when moving any of these to a lattice backend**, in
one place: (i) curve PCS (KZG/Hyrax/Pedersen/Dory) must be replaced
by ring-claim or hash MLE-evaluation machinery — this is work we
have already scoped (GATE_ALTERNATIVES option 2, and the E1/E2 link
extensions); (ii) VOLE systems change the trust/deployment model
entirely (interactive, designated-verifier) — excluded; (iii) halo2
univariate lookups assume FFT-friendly multiplicative subgroups and
Plonkish columns — superseded by multivariate LogUp; (iv) "small
committed values are nearly free" (MSM economics) does NOT hold for
our dense commit kernel — any construction whose headline depends
on it (Lasso/Shout commitment claims, LatticeFold+ monomials) must
be re-priced in dce, as done in Section 1.

## 3. Alternative strategies, priced against the same budget

**One-hot / indicator tables (our Variant B, 256 dce/el).** The
literature reinvented this three times in 2024-2025: Shout at d = 1,
FLI's elementary-matrix rows, and LatticeFold+'s monomials
(X^f is a one-hot vector over coefficient positions). Every version
is priced as CHEAP in its home cost model because its home
commitment scheme pays per nonzero (curve MSM) or per bit
(hash/Binius, pay-per-bit Ajtai) — and every version re-prices to
Variant B's 256 dce/el under our dense commit kernel and dense
ARP/masking layer. The literature therefore does not rescue the
one-hot route for us; it explains precisely which engine change
WOULD rescue it (sparse/pay-per-bit commitment + folding-style
openings, i.e., the Neo stack), and that is a protocol replacement,
not an M4 gadget.

**Polynomial approximation with proven error bounds.** No 2024-2026
system at transformer scale uses a global polynomial approximation
for exp or SiLU; zkLLM explicitly positions zkAttn against
"the accuracy degradation and high overheads linked with
bit-decompositions and polynomial approximations," and our own
M4_ACTIVATION_DESIGN Section 2 killed degree ~12-16 global
polynomials on q31 headroom grounds. The piecewise-linear variant is
our incumbent at 105 dce/el and is dominated by every lookup row in
the table below. Closed.

**Spline lookups (piecewise + lookup hybrid).** Look up the segment
(coefficients) with a lookup argument, then evaluate the linear
piece with ring claims. This saves table size versus a direct table
only when the input width is large; at int8 the direct 256-row table
makes the spline pointless, and at exp's 12-16 bits the direct table
(4,096-65,536 rows) is STILL essentially free on the table side
(Section 5.2), while the spline would re-introduce the H3
slot-Hadamard evaluation costs (16 dce per committed operand) that
made Variant A expensive. Only relevant beyond ~20-bit inputs, which
our specs do not have.

**Committed table + permutation/multiset check directly with ring
claims (plookup transplanted).** Buildable: commit the sorted
concatenation of witness and table (~1 dce/el), prove the multiset
equality with a grand-product accumulator. The accumulator is the
problem: as a committed running product it is sequential and
slot-packed (16 dce/el class); as a GKR grand product (Thaler's
tree) it needs the same sumcheck engine as LogUp-GKR while STILL
paying the ~1 dce/el sorted column and the sort. LogUp-GKR
dominates it on every axis (the SoK's reading of history agrees:
the field moved from multiset to log-derivative for exactly this
reason). Dominated; do not build.

**Batch-friendly range decompositions.** The most consequential
synergy found in this review, pointing beyond M4: once a
LogUp-GKR-class lookup exists, EVERY w-bit range proof in the chain
is a lookup into the table [0, 2^w) — Habock's paper itself
presents batch range checks as the flagship application, and Hao et
al. (USENIX Security 2024) measured 50-179x wins doing ranges and
nonlinearities this way in a VOLE system. Our baseline pass is
82.8% bit-plane coefficients (GADGET_MODULUS_DECISION); replacing
per-bit planes+ARP with per-tensor lookups is the
"bit-packing / lookup-based ranges (2-4x)" rung that
LLM_SCALE_ESTIMATE already reserves at the bottom of the ladder.
M4's activation lookup is the cheapest possible pilot for that
machinery: same primitive, 1/50th the volume of the range workload.

**Sumcheck/GKR layers over hash commitments.** GATE_ALTERNATIVES
option 2 (Brakedown/Ligero-class hash PCS + sumcheck for the
bilinear gate) and this review's recommendation share ~all of their
new code: a sumcheck/GKR transcript layer over GF(q^e), and
claims tying MLE evaluations to lattice-committed tensors (link
rows, ~59 KB/tensor as priced there). If the hash-sumcheck fallback
is ever built for the gate, LogUp-GKR rides it for free; conversely,
building LogUp-GKR first de-risks the gate fallback. Either order,
the sumcheck engine is bought once and used twice — this synergy is
an argument FOR the lookup track that did not exist when
GATE_ALTERNATIVES was written.

## 4. Amortization: what decides M4

Two different "table amortization" properties appear in the
literature, and only one of them matters to us:

- **Sublinearity in table size** (Caulk/Caulk+/Baloo/cq: prover
  independent of T after preprocessing; Lasso/Shout: pay only for
  accessed entries; the SoK's Appendix A is a map of this axis).
  Irrelevant at T = 256-65,536: the table side costs one
  multiplicity column and one histogram pass regardless of
  construction.
- **Amortization across N lookups of ONE shared table** — the axis
  that decides M4 at N = 1.8e8. Here the constructions separate
  cleanly, in marginal committed data per lookup:

| construction | committed/el (our dce) | prover field work/el | table-side (amortized over 1.8e8) |
|---|---|---|---|
| piecewise Variant A (incumbent) | 105 | small | — |
| one-hot Variant B / Shout d=1 dense / LatticeFold+ | 256 (dense engine) | small | — |
| plookup-multiset via ring claims | ~1-3 + sort | grand products | sorted table column, ~0 |
| Lasso (c = 1) | ~1-2 (small counters) | O(1) + grand products | counts column, ~0 |
| tlookup / elementary LogUp | ~6 (GF(q^6) inverse) | ~19 ext mult + inversion | m, B columns, ~0 |
| **LogUp-GKR** | **~0** (m column only) | **~43 ext mult + 29 add** | m column (256 coeffs), ~1.4e-6 dce/el |
| **Shout d=8 on existing xb planes** | **~0 new** | ~60-110 mult (deg-9 sumcheck) | table MLE, verifier-computable |

Both ~0-dce rows converge on the same two obligations (sumcheck
layer, MLE-evaluation claims) and differ in flavor: LogUp-GKR needs
extension-field inversions on the prover side (batched, one inverse
tree per tensor) and a multiplicity histogram; Shout needs the
degree-9 product-of-selectors sumcheck and reuses the input bit
planes as its one-hot chunks. LogUp-GKR is the one with (i) a
written soundness analysis in the exact multivariate form we need
(Papini-Habock Props. 1-2), (ii) production deployments over
small-field hash commitments (Stwo, SP1 — cited by the SoK as
running LogUp over FRI at field sizes like 2^31, our field class),
and (iii) a direct zkML precedent (zkLLM). It is the primary
design input; Shout's read-checking is the secondary one.

Prover-work sanity check at our scale [MODEL, arithmetic shown]:
43 GF(q^16)-mults/el, and the slot structure executes 8 independent
GF(q^16) mults per ring mult, so ~5.4 ring mults per element; at the
A1 kernels' measured ~0.16-0.20 us/ring-MAC-class throughput
(RING_MULT_BOTTLENECK 6.5; a full 128-coeff ring mult is more than
one MAC, so take this as a floor-to-2x band), 1.8e8 elements land at
roughly 3-10 min single-thread, i.e., **~10-30 s at 22T, seconds on
a GPU** (zkLLM demonstrates the whole family is CUDA-friendly). The
GKR tree is embarrassingly parallel within each layer. This is
prover TIME, not commit stream: it adds no bytes to the commitment
bill, which is what the <20% Class-3 criterion prices. A GF(q^6)
tower instead of slots lands in the same band (43 x ~12-18 base
mults with Karatsuba).

The characteristic ceiling is the one real scale constraint: LogUp
needs total-lookups-per-table-instance < char(F) = q ~ 2.1e9. SiLU
at 7B: 1.8e8, 12x margin; SiLU at T = 2048 tokens: 7.2e8, ~3x;
softmax exp at T = 2048: ~4.3e9 — OVER the ceiling. Remedy is
trivial (per-layer or per-head table instances, one 2-ring-element
multiplicity column each) but must be in the design from day one.
Shout has no such ceiling (no multiplicities); a second reason to
keep it as the fallback shape.

## 5. Quantization-specific tricks

### 5.1 int8 activations (T = 256)

At int8 the table is so small that every sophistication collapses:

- **Fused pair table** (Section 1.4): one 256-row table of
  x + kappa*T[x] values; no decomposition, no segments, no zkAttn
  machinery. The multiplicity histogram is one 256-bin count over
  the tensor (memory-bandwidth cost).
- **Output ranges come free**: a successful pair lookup pins y mod q
  to a declared int8 table value, so the activation's OUTPUT needs
  no separate range planes — the M4 piecewise design charged those
  planes to the baseline chain ("chain-native"); under the lookup
  they are certifiably int8 by table construction. Whether the
  downstream gate o up gadget still wants yb planes for its own
  bookkeeping is an engine question, not a soundness one; if they
  can be dropped, the lookup's marginal cost vs today's baseline is
  NEGATIVE on the output side.
- **Sign/symmetry tricks are obsolete**: silu(-x) = silu(x) - x
  (the M4 doc's half-table idea) saves 128 table rows — worth zero
  when the table side is already ~0; not worth one extra claim.
- ZEN-style quantization-aware encodings (sign-bit grouping,
  remainder-based verification) address costs the lookup route
  simply does not have.

### 5.2 exp_q for softmax at 12-16 bits

The published precedent is zkAttn (zkLLM Section 5): decompose the
(shifted, nonpositive) exponent input in mixed radix, x =
sum_k x^(k) B^(k); then exp(x) = prod_k exp(B^(k) x^(k)) turns one
big table into K small tables T^(k) of size b^(k) plus K-1 products,
with two published refinements — top limbs collapse to zero/indicator
tables (underflow to y = 0) and bottom limbs collapse to the
constant 1 (their Section 5.1.1) — and the row normalization checked
as sum-to-theta instead of proving division (exactly our plan's
"softmax without division"). The paper does NOT publish its concrete
K and b^(k) (stated as balanced for accuracy/overhead; their code
is public if we ever need the operating point).

For OUR cost model the zkAttn decomposition is the wrong default:
each inter-limb product is a committed slot-packed Hadamard operand
chain (16 dce/el per committed factor), while a DIRECT table at
12-16 bits costs the lookup argument nothing but a longer
multiplicity column (4,096-65,536 coefficients — 32-512 ring
elements, amortized over 2.7e8 attention elements: still ~0 dce/el).
zkAttn's limb split exists because a 2^16-row table strained GPU
memory in THEIR per-table-instance layout, not because lookups get
more expensive with T — LogUp's prover is O(N + T). Recommendation:
direct fused-pair table up to 16-bit exp inputs, with per-layer
table instances for the characteristic ceiling (Section 4); revisit
limbs only if a spec ever needs >16-bit nonlinearity inputs.

### 5.3 Where the leftover bit planes go

The exp path still needs its INPUT range-proved (the shift z - zhat
and the clip at -B are upstream range facts, as with SiLU's int8
input) — those planes are chain-native today. Section 3's range-
lookup synergy applies: the same primitive can eventually replace
them. Nothing in the lookup design should hard-code the assumption
that inputs arrive as bit planes; it should consume "range-proved
tensor" as an interface.

## 6. The verdict in full (the executive verdict, with its arithmetic)

Recommendation: **(a) adapt a specific construction — LogUp-GKR**
(Habock's log-derivative lookup with the Papini-Habock GKR
fractional sumcheck), as a fused-pair lookup over one shared 256-row
int8 SiLU table, with soundness field GF(q^6) or the native GF(q^16)
slot field. It fits the lattice setting because the entire identity
is mod-q (no norm/integer accounting), needs no pairings, is FS-in-
ROM, and is deployed in production over hash commitments at exactly
our field size (Stwo/SP1 STARK stacks). Landing constant [MODEL]:
**~0 committed dce/el** (a 256-coefficient multiplicity column per
table instance, ~1.4e-6 dce/el amortized) + ~43 extension-field
mults/el of prover time (~10-30 s at 22T per 7B pass, GPU-friendly)
+ one MLE-evaluation ring claim per tensor — versus the piecewise
incumbent's 105 dce/el (+201% pass commit) and the 2-4 dce/el
budget: the budget is met with two orders of magnitude of headroom,
PROVIDED the two obligations land: (E3) a sumcheck/GKR transcript
layer over GF(q^e), and (E4) public-weight MLE-evaluation claims
against dense lattice commitments (mod-q-only link-row machinery;
ZK masking of the evaluation values inherits the repo-wide 8.1
obligation). Design inputs to carry: tlookup (zkLLM) as the
committed-inverse fallback at ~6 dce/el if the GKR layer slips;
Shout-style d=8 read-checking (reuses chain-native input bit
planes, no characteristic ceiling) as the alternate ~0-dce shape;
zkAttn only as the >16-bit contingency. The same primitive then
retires exp_q/softmax (direct 12-16-bit tables, per-layer instances
for the char ceiling) and opens the range-proof-as-lookup rung of
the LLM_SCALE ladder toward the 5-15 s/8B target.

## 7. What we did NOT find (honest gaps)

- **No lattice-native standalone lookup argument.** 2024-2026
  lattice work does lookups only INSIDE folding stacks (LatticeFold+
  monomial ranges; Neo/SuperNeo folding Shout). Nobody has published
  "LogUp/Shout over ABDLOP/LNP22-class commitments with Sigma-
  protocol openings" — our E3+E4 build would be the first of its
  shape, and no paper's measured constants cover it. All landing
  constants above are our arithmetic, flagged [MODEL].
- **No measured LogUp-GKR-per-element numbers on ANY backend** in
  the papers themselves — Papini-Habock give operation counts (which
  we used) and a forecast, not benchmarks. Production STARK stacks
  (Stwo/SP1) validate the design but publish no per-lookup breakdown
  we could cite.
- **zkAttn's concrete parameters** (K, b^(k), theta^(k)) are not in
  the CCS paper; only the parameter-selection framework (their 7.1).
- **zkLLM's SiLU cost is not isolated** in their evaluation (only
  end-to-end and zkAttn-isolated numbers), so "measured cost per
  activation" for tlookup is not quotable; we derived its committed
  cost (1 field element/el) from Protocol 1 instead.
- **No PQ transplant of the halo2/univariate lookup lineage** (cq,
  Caulk, Baloo families are pairing-bound; nothing to re-price).
- **ZK (hiding) analyses of lookup arguments are thin everywhere**:
  LogUp/Shout papers prove soundness of the IOPs; hiding is deferred
  to the commitment/masking layer. Our garbage-image ZK obligation
  (SOUNDNESS_REFERENCE 8.1) therefore extends to the new claims and
  nothing in the literature discharges it for us.
- **Jolt Atlas / NANOZK (2026)** publish direction but not
  per-activation cost tables usable here (and both are
  curve-committed today).

## 8. References

1. Ulrich Habock. "Multivariate lookups based on logarithmic
   derivatives." IACR ePrint 2022/1530.
   https://eprint.iacr.org/2022/1530
2. Shahar Papini, Ulrich Habock. "Improving logarithmic derivative
   lookups using GKR." IACR ePrint 2023/1284.
   https://eprint.iacr.org/2023/1284
3. Liam Eagen, Dario Fiore, Ariel Gabizon. "cq: Cached quotients for
   fast lookups." IACR ePrint 2022/1763.
   https://eprint.iacr.org/2022/1763
4. Ariel Gabizon, Zachary J. Williamson. "plookup: A simplified
   polynomial protocol for lookup tables." IACR ePrint 2020/315.
   https://eprint.iacr.org/2020/315
5. Srinath Setty, Justin Thaler, Riad Wahby. "Unlocking the lookup
   singularity with Lasso." EUROCRYPT 2024; IACR ePrint 2023/1216.
   https://eprint.iacr.org/2023/1216
6. Arasu Arun, Srinath Setty, Justin Thaler. "Jolt: SNARKs for
   virtual machines via lookups." EUROCRYPT 2024; IACR ePrint
   2023/1217. https://eprint.iacr.org/2023/1217
7. Srinath Setty, Justin Thaler. "Twist and Shout: Faster memory
   checking arguments via one-hot addressing and increments." IACR
   ePrint 2025/105. https://eprint.iacr.org/2025/105
8. Haochen Sun, Jason Li, Hongyang Zhang. "zkLLM: Zero Knowledge
   Proofs for Large Language Models." ACM CCS 2024; arXiv:2404.16109.
   https://arxiv.org/abs/2404.16109
9. Hossein Hafezi, Gaspard Anthoine, Matteo Campanelli, Dario Fiore.
   "SoK: Lookup Table Arguments." IACR ePrint 2025/1876.
   https://eprint.iacr.org/2025/1876
10. Dan Boneh, Binyi Chen. "LatticeFold: A Lattice-based Folding
    Scheme and its Applications to Succinct Proof Systems." IACR
    ePrint 2024/257. https://eprint.iacr.org/2024/257
11. Dan Boneh, Binyi Chen. "LatticeFold+: Faster, Simpler, Shorter
    Lattice-Based Folding for Succinct Proof Systems." IACR ePrint
    2025/247. https://eprint.iacr.org/2025/247
12. Wilson Nguyen, Srinath Setty. "Neo: Lattice-based folding scheme
    for CCS over small fields and pay-per-bit commitments." IACR
    ePrint 2025/294. https://eprint.iacr.org/2025/294
13. Wilson Nguyen, Srinath Setty. "Neo and SuperNeo: Post-quantum
    folding with pay-per-bit costs over small fields." IACR ePrint
    2026/242. https://eprint.iacr.org/2026/242
14. Albert Garreta, Ignacio Manzur. "FLI: Folding Lookup Instances."
    ASIACRYPT 2024; IACR ePrint 2024/1531.
    https://eprint.iacr.org/2024/1531
15. Ngoc Khanh Nguyen, Gregor Seiler. "Greyhound: Fast Polynomial
    Commitments from Lattices." CRYPTO 2024; IACR ePrint 2024/1293.
    https://eprint.iacr.org/2024/1293
16. Tianyi Liu, Xiang Xie, Yupeng Zhang. "zkCNN: Zero Knowledge
    Proofs for Convolutional Neural Network Predictions and
    Accuracy." ACM CCS 2021; IACR ePrint 2021/673.
    https://eprint.iacr.org/2021/673
17. Chenkai Weng, Kang Yang, Xiang Xie, Jonathan Katz, Xiao Wang.
    "Mystique: Efficient Conversions for Zero-Knowledge Proofs with
    Applications to Machine Learning." USENIX Security 2021; IACR
    ePrint 2021/730. https://eprint.iacr.org/2021/730
18. Boyuan Feng, Lianke Qin, Zhenfei Zhang, Yufei Ding, Shumo Chu.
    "ZEN: An Optimizing Compiler for Verifiable, Zero-Knowledge
    Neural Network Inference." IACR ePrint 2021/087.
    https://eprint.iacr.org/2021/087
19. Zahra Ghodsi, Tianyu Gu, Siddharth Garg. "SafetyNets: Verifiable
    Execution of Deep Neural Networks on an Untrusted Cloud."
    NeurIPS 2017; arXiv:1706.10268. https://arxiv.org/abs/1706.10268
20. Seunghwa Lee, Hankyung Ko, Jihye Kim, Hyunok Oh. "vCNN:
    Verifiable Convolutional Neural Network based on zk-SNARKs."
    IACR ePrint 2020/584. https://eprint.iacr.org/2020/584
21. Jiasi Weng, Jian Weng, Gui Tang, Anjia Yang, Ming Li, Jia-Nan
    Liu. "pvCNN: Privacy-Preserving and Verifiable Convolutional
    Neural Network Testing." IEEE TIFS 2023; arXiv:2201.09186.
    https://arxiv.org/abs/2201.09186
22. Haodi Wang, Thang Hoang. "ezDPS: An Efficient and Zero-Knowledge
    Machine Learning Inference Pipeline." PoPETs 2023; IACR ePrint
    2022/1456. https://eprint.iacr.org/2022/1456
23. Daniel Kang, Tatsunori Hashimoto, Ion Stoica, Yi Sun. "Scaling
    up Trustless DNN Inference with Zero-Knowledge Proofs."
    arXiv:2210.08674. https://arxiv.org/abs/2210.08674
24. Bing-Jyue Chen, Suppakit Waiwitlikhit, Ion Stoica, Daniel Kang.
    "ZKML: An Optimizing System for ML Inference in Zero-Knowledge
    Proofs." EuroSys 2024.
25. Meng Hao, Hanxiao Chen, Hongwei Li, Chenkai Weng, Yuan Zhang,
    Haomiao Yang, Tianwei Zhang. "Scalable Zero-knowledge Proofs for
    Non-linear Functions in Machine Learning." USENIX Security 2024;
    IACR ePrint 2025/507. https://eprint.iacr.org/2025/507
26. Wenjie Qu, Yijun Sun, Xuanming Liu, Tao Lu, Yanpei Guo, Kai
    Chen, Jiaheng Zhang. "zkGPT: An Efficient Non-interactive
    Zero-knowledge Proof Framework for LLM Inference." USENIX
    Security 2025; IACR ePrint 2025/1184.
    https://eprint.iacr.org/2025/1184
27. Lyron Co Ting Keh et al. "Zator: Verified inference of a
    512-layer neural network using recursive SNARKs" (Nova). 2023.
    https://github.com/lyronctk/zator
28. EZKL (zkonduit). Production halo2-based zkML framework;
    lookup-table nonlinearities. https://github.com/zkonduit/ezkl
29. Wyatt Benno, Alberto Centelles, Antoine Douchet, Khalil Gibran.
    "Jolt Atlas: Verifiable Inference via Lookup Arguments in Zero
    Knowledge." arXiv:2602.17452 (Feb 2026).
    https://arxiv.org/abs/2602.17452
30. Zhaohui Geoffrey Wang. "NANOZK: Layerwise Zero-Knowledge Proofs
    for Verifiable Large Language Model Inference." arXiv:2603.18046
    (Mar 2026). https://arxiv.org/abs/2603.18046
31. Zhizhi Peng, Chonghe Zhao, Taotao Wang, Guofu Liao, Zibin Lin,
    Yifeng Liu, Bin Cao, Long Shi, Qing Yang, Shengli Zhang. "A
    Survey of Zero-Knowledge Proof Based Verifiable Machine
    Learning." arXiv:2502.18535. https://arxiv.org/abs/2502.18535

---

*Changelog: 2026-07-09 — first edition (M4 lookup literature review
tranche): Q1-Q5 answered, verdict issued: adopt LogUp-GKR as the M4
lookup-track primary, tlookup fallback, Shout alternate.*
