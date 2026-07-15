# M4 Lookup Design: LogUp-GKR as the Fused-Pair int8 SiLU Certificate

Status: design round COMPLETE (equations + machine-checked spike);
ENGINE STATUS (2026-07-10): the UNMASKED core is built — E3 = U-K1..K4
(`ring/kfield.rs`, `ring/sumcheck.rs`, `ring/gkr.rs`, `ring/lookup.rs`)
and the E4 landing U-K6/K7, every designed hash edge pinned F5-style;
U-K5 (ZK masking) is BUILT AND BATTERY-TESTED (tranche U-K5c/d/e,
2026-07-10: committed masked pass with aggregate-only pins, the
engine-scale m-recovery harness closed, E3Z-N1..N4 F5 pairs, freeze
rows LKP-6/7; design: M4_LOOKUP_ZK_DESIGN.md; lemmas Q4.7-Q4.9) — the
non-ZK label on lookup-bearing proofs is LIFTED at the subprotocol
level (honest-verifier ZK, proof-of-protocol; chain-wide ZK is the
composition's statement, per the R1.3-class honesty note); the U-K8
integration exit CLOSED 2026-07-10 at row-block granularity: the
masked committed lookup runs INSIDE a chain (range-proved X in,
slot-packed E1-composed Y out, downstream gate-o-up, validated v2
statement) with measured marginals — Sections 7'' and 8. Four
statuses, tracked separately: core algebra BUILT+MEASURED-1T; E4
landing BUILT (N=256 committed rig); masked lookup
BUILT+BATTERY-GREEN (battery shape; FFN-point mask material and
transcript pinned by the LKP-6/7 formula freeze rows); FFN integration
BUILT+MEASURED-1T at 1020-element row-block sub-instances covering the
tensor (`ffn-chain`, LKP-8) — NOT at the single-instance 512x11008
shape, which the q31 ct-round's C2 wave capacity blocks near 2^17
elements per committed descent (a wall this integration surfaced,
ahead of the audit H-03 memory wall; Section 7'').
Every algebraic claim below is exercised by `scripts/logup_gkr_spike.py`
(pure stdlib, exact arithmetic; 16 OK assertion lines; output recorded in
Section 10). Companions: M4_LOOKUP_LITERATURE.md (the decided verdict
this design implements), M4_ACTIVATION_DESIGN.md (the piecewise incumbent
at ~105 dce/el that this replaces, and the E1/E2 slot-link machinery, now
BUILT), GATE_ALTERNATIVES.md option 2 (the hash-sumcheck gate that shares
the E3 engine), SOUNDNESS_REFERENCE.md (grading conventions and the
Section 7 audit-table format used for every hash edge below),
LLM_SCALE_ESTIMATE.md (the ladder the cost table slots into).

Grading follows the soundness reference's legend: **[PROVEN]** /
**[MODEL]** / **[OBLIGATION]**; **[SKETCH]** marks arguments given here
in full but not yet transcribed into the soundness reference.

**The verdict in one paragraph.** Adapt LogUp-GKR (Habock ePrint
2022/1530; Papini-Habock ePrint 2023/1284) as a fused-pair lookup of the
committed activation pair (x, y) into the 256-row exact int8 SiLU table,
with the challenge/soundness field being the engine's NATIVE CRT slot
field GF(q^16) (decided; the explicit GF(q^6) tower is the recorded
alternative, Section 2). Committed cost ~4.5e-5 dce per activation
element (one 256-coefficient multiplicity column per layer instance) —
versus the piecewise incumbent's 105 and the Class-3 budget of 2-4 —
plus ~43 extension-field multiplications per element of prover TIME
(~5.4 ring-mult equivalents; ~9-22 s at 22T, ~1-3 s GPU-class per
7B/512 pass [MODEL]) and a ~120 KB per-pass transcript. One design
sharpening came out of the spike: the fusion challenge kappa can be the
FIXED field generator Y (no challenge, zero soundness error, ordering
edge removed by construction), because a base-field pair can never
collide across an extension-field fusion (spike OK-2d). Two build
obligations carry the whole construction: E3 (a sumcheck/GKR transcript
layer over GF(q^16)) and E4 (MLE-evaluation claims, which land as
EXISTING linear ct-claims with new public-weight computation — no new
claim family). The honest headline risk: the GKR transcript is NOT
zero-knowledge unmasked (the R1 lesson repeats one level up; every
prover-sent sumcheck value is a witness statistic), and the masking
design is an explicit obligation (E3-Z), not hand-waved.

## PROGRESS

- [x] Section 0: symbols and units
- [x] Section 1: the statement and the chain interface
- [x] Section 2: the field decision (GF(q^16) vs GF(q^6)), arithmetic
- [x] Section 3: the protocol, fully specified (+ hash-edge drafts)
- [x] Section 4: the characteristic ceiling and instancing bookkeeping
- [x] Section 5: batching across tensors and layers (decided)
- [x] Section 6: soundness accounting table
- [x] Section 7: cost table and ladder impact
- [x] Section 8: build plan (E3/E4 tranches, negative batteries, freeze rows)
- [x] Section 9: what could kill this
- [x] Section 10: spike output (recorded)

## 0. Symbols and units

- **q** = q31 = 2^31 - 399, the protocol modulus; Z_q the base field;
  char(any extension of Z_q) = q ~ 2.1e9. **D** = 128, the ring degree;
  the ring R_q splits into k = 8 CRT slots, each the field GF(q^16)
  (SOUNDNESS_REFERENCE 1.1).
- **K** — the challenge/soundness field of the lookup: an extension
  GF(q^e) of Z_q. Section 2 decides e = 16 (the slot field).
- **N** — number of lookups. Per 7B/512 pass: N_pass = 32 layers x
  512 x 11008 = 180,486,144 ~ 2^27.43. Per layer instance:
  N_inst = 5,636,096 ~ 2^22.43.
- **T** — table rows: 256 (the int8 SiLU pair table).
- **dce** — dense q31-coefficient element-equivalents of COMMITMENT
  cost, the LLM_SCALE_ESTIMATE unit (1 dce = one committed Z_q
  coefficient in a dense-packed ring element). The 7B/512 baseline pass
  commit bill is ~9.4e9 dce; the Class-3 budget is <= ~2-4 dce per
  activation element (<20% of the pass).
- **MLE** — multilinear extension: for a vector v of length 2^n, the
  unique multilinear polynomial over K^n agreeing with v on {0,1}^n.
  MLE(v)(r) = sum_i L_r[i] v_i with the PUBLIC tensor weight vector
  L_r[i] = prod_t (r_t if bit_t(i) else 1 - r_t).
- **GKR** — the Goldwasser-Kalai-Rothblum interactive proof over a
  layered circuit: here, Papini-Habock's fractional-sum binary tree in
  projective coordinates (p, q) — no committed intermediates, one
  sumcheck per tree layer.
- **m** — the multiplicity column: m_j = #{i : x_i = v_j}, length T,
  committed per table instance.
- **F5 pair** — the repo's negative-battery pattern for hash-ordering
  edges: the attack demonstrated ACCEPTING under the violated order, and
  REJECTED under the shipped order (SOUNDNESS_REFERENCE 4.3).

## 1. The statement, and its interface to the chain

The lookup certifies ONE mod-q relation per activation tensor pair:

> For committed tensors X (activation input) and Y (activation output),
> elementwise over i: the pair (X_i mod q, Y_i mod q), read as centered
> residues, is a row of the declared table
> T_SiLU = { (v, S[v]) : v in int8 }, where S is the EXACT
> int8-quantized SiLU pinned by the table spec header below.

Composition with the chain gives the integer statement. The chain
already range-proves X upstream (the rescale that produced it pins X_i
to int8 — today via bit planes, later possibly via range lookups;
the lookup does NOT care which). An int8 centered residue IS the
integer, so the mod-q table fact plus the upstream range fact yields:
Y_i = S[X_i] over Z, and Y_i's OWN int8 range comes free (every table
output is int8 by construction) — the lookup's output needs no separate
range planes, exactly as the literature review's Section 5.1 predicted.

**Interface: "range-proved tensor in, table-certified tensor out."**
The lookup consumes any committed q31 tensor pair — dense-packed
directly, or slot-packed (H3) through the E1 slot-constant projection
functional (Section 3.4); it never touches, and must never hard-code,
the input's bit planes. This keeps the primitive reusable for the
range-lookup rung (Section 7) where the inputs will NOT have planes.

Statement quality: the certified function is the IDEAL int8-quantized
SiLU (Variant B semantics: ulp_max = 0 against quantized SiLU by
construction) — strictly stronger than the piecewise incumbent's
1-ulp-approximate declared function. There is still no claim about real
SiLU: the published claim names the quantized spec, per
TRANSFORMER_PROOF_PLAN Section 1.

### 1.1 The table spec header

    {
      "function": "silu-int8-table-v1",
      "input":  { "width": 8, "frac_bits": 4, "signed": true },
      "output": { "width": 8, "frac_bits": 4, "signed": true },
      "rounding": "y = round_half_up(x * sigmoid(x)) on the fixed-point grid",
      "table": [ [v_0, S_0], ..., [v_255, S_255] ]
    }

The SHA-256 digest of this canonical JSON enters the claim manifest and
therefore every Fiat-Shamir challenge via ctx (the M3 gap-5 rule); a
freeze row pins it (LKP-1, Section 8). Proofs are not transplantable
across tables. The same header format serves the later exp_q table
(width 12-16) unchanged.

## 2. The field decision: GF(q^16) via CRT slots — decided

The lookup needs one large field K for the log-derivative point alpha
and every sumcheck challenge. Two candidates; one recommendation with
the arithmetic; the loser recorded.

### 2.1 Soundness arithmetic (Papini-Habock Props. 1-2 shapes)

Error terms at the recommended protocol point (kappa := Y deterministic
fusion, Section 3.2; per-layer instances rho-batched into one GKR run,
Section 5; witness depth 23, table depth 8):

| term | formula | GF(q^6), |K| ~ 2^186 | GF(q^16), |K| ~ 2^496 |
|---|---|---|---|
| fractional identity, per statement (instance) | <= 2 N_inst / (|K| - N_inst) | 2^-162.6 | 2^-472.6 |
| fractional identity, per pass | <= 2 N_pass / (|K| - N_pass) | 2^-157.6 | 2^-467.6 |
| fused-pair reduction (kappa := Y) | 0 (exact; spike OK-2d) | 0 | 0 |
| (if kappa were drawn instead) | N_pass T / |K| | 2^-150.6 | 2^-460.6 |
| GKR sumchecks, per pass | <= 3 x 281 rounds / |K| | 2^-176.3 | 2^-486.3 |
| rho instance batching | <= 23 layers x 32 / |K| | 2^-176.5 | 2^-486.5 |
| E4 psi coordinate batch | 9 theta-style copies at 2^-31 | 2^-279 | 2^-279 |
| **pass total** | sum | **~2^-157.5** | **~2^-279** (psi-capped) |

Both fields clear the 2^-128 target: GF(q^6) by ~29 bits, GF(q^16) by
~151 bits (the psi rows cap it; they are base-field machinery shared by
both options). FS grinding across the ~300-challenge transcript carries
the standard random-oracle forking loss [MODEL], absorbed by either
margin. Soundness therefore does NOT decide the field.

### 2.2 Prover multiplications per element, both ways

Papini-Habock count the entire fractional GKR at ~43 K-multiplications
+ 29 K-additions per looked-up element (their Eq. 5-6; the M = 1
single-fused-column point). N_pass x 43 = 7.76e9 K-mults per pass.

- **GF(q^16) via slots:** the CRT structure executes 8 independent
  GF(q^16) multiplications per ring multiplication (slot-wise product =
  ring product), and the GKR workload is embarrassingly lane-parallel
  (independent tree nodes / independent instances fill slots; only the
  geometrically small top layers under-fill). ~43/8 = **5.4 ring-mult
  equivalents per element**, ~9.7e8 ring mults per pass; at the
  measured A1-kernel ring-op class (~0.2-0.5 us/ring mult 1T
  [MODEL band]) that is ~195-490 s 1T -> **~9-22 s at 22T, ~1-3 s
  GPU-class** [MODEL]. No new multiplication kernel exists in this
  path: slot arithmetic IS ring arithmetic.
- **GF(q^6) tower:** one GF(q^6) mult ~ 15-18 base-field mults
  (Karatsuba/Toom on degree-6), so ~650-770 base mults per element,
  ~1.2-1.4e11 per pass; at ~1-2 ns/Montgomery-mult SIMD class this
  lands in the SAME ~10-30 s at 22T band [MODEL]. Prover time does not
  decide the field either.

### 2.3 Implementation surface — this decides it

- **GF(q^16):** field elements are 16-coefficient residues of the
  binomials X^16 - eta^(2t+1) ALREADY implemented by the engine's CRT
  layer (`crt_split`, the H3 slot machinery, the E1 projection rows).
  New code: scalar GF(q^16) helpers (mul against one slot binomial,
  Fermat inversion for the verifier's few divisions, serialization) and
  the transcript layer — no new arithmetic theory, no new irreducible-
  polynomial selection, and the E4 coordinate projections are exactly
  the `crt_coord_rows` functionals that E1/E2 already ship. Transcript
  elements cost 64 B each (16 q31 words).
- **GF(q^6):** a NEW tower (find an irreducible degree-6 binomial or a
  quadratic-over-cubic tower over Z_q, new mul/inv kernels, a new
  battery, new freeze rows for the tower constants), disjoint from
  every existing kernel. Transcript elements cost 24 B — the one real
  advantage: ~2.3x smaller transcripts (Section 7: ~55 KB vs ~120 KB
  per pass — both noise against the MB-class gate proofs).

**Decision: GF(q^16) via the native CRT slots.** Rationale: zero new
field arithmetic, the 8-lane slot parallelism rides the measured ring
kernels, the E4 projections reuse E1 machinery, and the soundness
margin absorbs every union bound without bookkeeping. **Recorded
alternative (the loser): the explicit GF(q^6) tower** — strictly
smaller transcripts and a 2^-157-class (still ample) margin, at the
price of a new arithmetic layer; it becomes RELEVANT again only if the
tlookup fallback is ever taken, because committed inverse columns cost
e dce/el and only e = 6 (6 dce/el) is near budget while e = 16
(16 dce/el) is not. If the GKR layer slips and the fallback activates,
build the tower then.

## 3. The protocol, fully specified

Setting per pass: 32 layer instances (Section 4), instance ell holding
the committed pair (X^ell, Y^ell) — 5,636,096 elements each, padded to
2^23 leaves with dummy (p, q) = (0, 1) leaves which add zero fractional
mass. All commitments are the chain's standard BDLOP wave commitments
at q31.

### 3.1 Committed objects and where they live

| object | shape | CRS / packing | committed when |
|---|---|---|---|
| X^ell, Y^ell | 5.64e6 coeffs each | chain-native (dense, or H3 slot via E1 reading) | already in the pass wave (no new cost) |
| m^ell (multiplicity column) | 256 coeffs = 2 ring elements | 2 message slots riding the SAME wave commitment group as layer ell's tensors (msg_r >= 2 wave shapes per the R1 note) | in the statement wave, BEFORE any lookup challenge |
| E3-Z masking columns (ZK, Section 3.5) | ~3 x 23 + O(1) K-elements per run | one small dedicated commitment per pass | with m, before challenges [OBLIGATION] |

m^ell is the histogram of X^ell over the 256 table inputs — one
memory-bandwidth pass, no multiplication. m needs NO range proof and no
binariness: the log-derivative lemma pins table-row counts mod q
directly, and the ceiling constraint N_inst < q (Section 4) upgrades
that to exact counts. m depends only on X^ell, never on any challenge.

### 3.2 Fusion: kappa := Y, a deterministic sharpening [PROVEN at spike scale, one-paragraph argument]

The literature's fused-pair reduction draws a challenge kappa and looks
up w_i = x_i + kappa y_i in the fused table t_j = v_j + kappa S[v_j],
paying N T / |K| of soundness and one ordering edge (kappa after the
x, y commitments — the spike's OK-2c shows the exact collision
y'_i = S[v'] + (v' - x_i) kappa^{-1} when a BASE-FIELD kappa is known
first). But our witnesses and table entries are all BASE-field values,
and for any kappa with a nonzero non-constant coordinate the equation
(x - v) + kappa (y - S[v]) = 0 over GF(q^e) forces both base-field
brackets to zero separately — {1, kappa} are Z_q-linearly independent.
So fix **kappa := Y** (the field generator; in slot coordinates, the
second coefficient of the slot binomial's residue ring): the fusion is
EXACT, costs no soundness, needs no challenge, and the kappa ordering
edge disappears by construction. Spike OK-2d brute-forces this at toy
scale (all q candidate forgeries x all rows, for random extension kappa
AND kappa = Y: only the honest pair fuses); OK-2c preserves the
demonstration of what goes wrong under the tempting base-field
implementation shortcut. The audit table keeps a row for it so nobody
ever "optimizes" kappa into the base field.

### 3.3 Challenges and the transcript, in order

The lookup transcript hash chain, in the Section 7 audit format (these
rows are DRAFTS for the SOUNDNESS_REFERENCE Section 7 merge; every
challenge is a XOF read seeded as shown; ctx binds the table spec
digest LKP-1):

| challenge | drawn from | must follow | attack if violated | pinned by (planned) |
|---|---|---|---|---|
| (kappa — NOT drawn; fixed Y) | — | — | base-field kappa known first: exact fused collision y' = S[v'] + (v' - x) kappa^{-1} (spike OK-2c) | E3-N2 regression: a base-field-kappa build ACCEPTS the crafted pair / the Y-fusion REJECTS it |
| alpha (log-derivative point, GF(q^16)) | h0_lkp = H(ctx, CRS hash, ALL instances' X/Y/m commitments) | every X^ell, Y^ell, m^ell commitment + the table digest in ctx | crafted-m interpolation: with alpha known, m_0 := (LHS - sum_{j>=1} m_j/(alpha - t_j)) (alpha - t_0) accepts ANY witness (spike OK-2e) | E3-N1 F5 pair (stale-h0 alpha ACCEPTS / shipped order REJECTS) |
| rho (instance-batching weights, GF(q^16)^32) | XOF(h0_lkp, "rho") | same as alpha (all instance commitments) | commit one instance after rho: its defect can be crafted to cancel another instance's contribution in the batched claim | E3-N3 F5 pair |
| lambda_k (per-layer p/q batching), one per layer transition | XOF(transcript prefix through layer k's claimed values) | the layer-k claims it batches | forge p-defect against q-defect: two claims, one equation | E3-N4 battery (shared with r) |
| r_{k,t} (sumcheck round challenges) | XOF(prefix through round t's poly) | round t's polynomial g_{k,t} | classic sumcheck order attack: choose g after r and any false claim survives | E3-N4 F5 pair (tampered round poly = spike OK-3c; order pair in the battery) |
| mu_k (layer folding point) | XOF(prefix through the four layer-k+1 boundary values) | the claimed values vp0, vp1, vq0, vq1 | choose the four values after mu: one linear constraint on four unknowns — defect hidden in the slack | E3-N5 F5 pair |
| psi (E4 coordinate-batch randomizers, 9 base-field copies) | XOF(prefix through the claimed v^X, v^Y, v^M) | the claimed MLE values | choose v after psi: only the psi-combination is pinned; coordinate defects orthogonal to psi pass | E4-N1 F5 pair |
| c (ct-round challenge, E4 landing) | XOF(h0_round, head) — h0_round binds h0_lkp AND the full lookup transcript | everything above plus the round's commitments/images | forge the ct-claims; also: a rejection-sampling RESTART must re-derive c but must NOT re-derive alpha/r/psi (they precede the round) — the link-round pattern | existing engine batteries + E4-N2 (restart regression) |

Two structural rules, stated once: (1) the lookup transcript is
DETERMINISTIC prover work (no rejection sampling anywhere inside it);
it completes before the E4 ct-round begins, and the ct-round's h0 binds
the whole lookup transcript, so round restarts cannot grind any lookup
challenge. (2) Nothing in the lookup transcript may derive from
post-round data — the same one-way hash-chain discipline as the link's
h0_link (SOUNDNESS_REFERENCE Section 6).

### 3.4 The layered fractional GKR and the E4 landing

**The trees.** Per instance ell: witness leaves
(p, q)_i = (1, alpha - X_i - Y*Y_i) — note kappa = Y multiplies the
committed Y tensor; the fused leaf is a PUBLIC linear combination of
two committed base-field values and alpha. Table leaves
(p, q)_j = (m_j, alpha - v_j - Y*S[v_j]) over the 256 public fused
table values. Parents accumulate projectively:
p' = p_L q_R + p_R q_L, q' = q_L q_R (spike OK-3a: the root equals the
direct fractional sum). Root check, cross-multiplied so nobody inverts:

    P_w(ell) * Q_t(ell) = P_t(ell) * Q_w(ell),  Q_w, Q_t != 0,

which is exactly sum_i 1/(alpha - w_i) = sum_j m_j/(alpha - t_j) — the
LogUp identity (spike OK-3d: a wrong y passes its own internally
consistent descent and dies precisely here).

**The batched descent (rounds, messages, degrees).** The 32 witness
trees share shape (depth 23), so their layer claims are rho-combined
into ONE descent (Section 5): at each layer k = 0..22, one sumcheck
over k variables of the degree-3-per-variable relation

    P_k(z) + lambda_k Q_k(z) = sum_b eq(z, b) [ p_{k+1}(0,b) q_{k+1}(1,b)
        + p_{k+1}(1,b) q_{k+1}(0,b) + lambda_k q_{k+1}(0,b) q_{k+1}(1,b) ]

(child bit = variable 0, little-endian — the spike's convention after
its one real bug, recorded in OK-3b's history). Each round message is
the round polynomial as 4 K-elements (evaluations at 0..3; the standard
send-3 optimization g(1) = C - g(0) applies at build time); the
verifier checks g(0) + g(1) = C, folds C <- g(r) by Lagrange
interpolation, and at the sumcheck's end checks
C = eq(z, r) [vp0 vq1 + vp1 vq0 + lambda vq0 vq1] against the four
prover-sent boundary values, then folds them with mu_k into the next
layer's claim at z' = (mu_k, r). Total: sum_{k=1}^{22} k = 253 rounds
for the witness descent, 28 for the table descent (depth 8), ~1,012 +
~112 K-elements of round polynomials. Verifier arithmetic for the
descents: O(#rounds) K-ops — milliseconds.

**The final MLE claims (E4).** The witness descent terminates at point
z* in K^23 with two claims: P-claim = 1 (MLE of all-ones —
verifier-computable, free) and

    Q-claim = alpha - [ MLE(X~)(z*) + Y * MLE(Y~)(z*) ],

where X~, Y~ are the rho-weighted concatenations across instances
(Section 5) — so the whole witness side reduces to TWO tensor MLE
evaluations v^X := MLE(X~)(z*), v^Y := MLE(Y~)(z*). The table descent
terminates at z_t* in K^8 with v^M := MLE(m~)(z_t*) (the rho-weighted
multiplicity MLE) and the fused-table MLE, which the verifier computes
itself from the 256 public rows (256 K-ops). Spike OK-3b runs this
entire reduction end-to-end at toy scale, checking the leaf claims
E4-style.

**How v^X, v^Y, v^M land on the commitments — no new claim family.**
Each v is one GF(q^16) value; its 16 coordinates are BASE-FIELD
public-weight linear functionals of the committed coefficients (spike
OK-5b): coordinate c of v^X is sum_i (rho_ell L_{z*}[i])_c X^ell_i.
That is EXACTLY the engine's linear ct-claim shape (`CtClaim` +
`pack_functional`, SOUNDNESS_REFERENCE 4.2): public weights, dense
committed tensors, one reveal + one W image per claim, extraction
[PROVEN]. The 3 x 16 = 48 coordinate rows are batched with 9
theta-style base-field randomizer copies psi (2^-279, the engine's
existing convention) into **9 CtClaims per pass**, each spanning all
instances' X, Y and m commitments. For slot-packed (H3) tensors the
weight on value t composes with the slot-constant CRT projection row
(E1, `crt_coord_rows`) — same claim family, different public weight
computation; junk-coordinate pinning rides the chain's existing E2
zeta machinery where the tensor is also link-grounded. New CODE is
therefore: streaming tensor-weight generation (L_{z*} by the doubling
recursion, 1 K-mult per element, streamed in blocks — never
materialized: 1.8e8 x 64 B = 11.5 GB would not fit), the coordinate
projections, and the psi/rho composition. New CLAIM MACHINERY: none.

**Verifier work, totaled.** Descent checks ~10^3 K-ops; table MLE 256
K-ops; E4: weight expansion ~N_pass K-mults (~2.3e7 ring-mult
equivalents) plus the 9 rows' C_l/ZA_l combinations over ~2.8e6
committed ring elements (~2.5e7 ring ops) — **~5e7 ring-op class per
pass, ~10-25 s 1T, ~1-2 s at 22T [MODEL]**. The E4 verifier is LINEAR
in tensor volume — flagged honestly in Sections 7 and 9; "verification
cheaper than re-running the model" still holds by a wide margin, and
Greyhound-class sublinear evaluation proofs are the recorded future
path if verifier budget ever tightens.

### 3.5 Zero-knowledge status of every prover-sent value [OBLIGATION — the R1 lesson, one level up]

Grading honestly, R1-style: an unmasked prover-sent value that is a
deterministic function of (witness, public challenges) is a LEAK unless
proven otherwise. Inventory of the lookup transcript:

| prover-sent value | count per pass | witness-dependent? | status |
|---|---|---|---|
| round polynomials g_{k,t} | ~281 x 4 K-elements | YES — sums of products of layer values, which are polynomial images of the fused leaves | LEAK (unmasked) |
| layer boundary values vp0, vp1, vq0, vq1 | ~31 x 4 K-elements | YES | LEAK (unmasked) |
| roots P_w, Q_w, P_t, Q_t | 4 K-elements | YES — Q_w = prod_i (alpha - w_i) is a challenge-keyed digest of the fused multiset; P_w/Q_w its log-derivative | LEAK (unmasked) |
| final MLE values v^X, v^Y, v^M | 3 K-elements | YES — random linear combinations of the tensors; v^M leaks multiplicity-histogram (activation-distribution) statistics | LEAK (unmasked) |
| E4 reveals h_l | 9 ring elements | ct coordinate = psi-combination of the v's (already counted); non-ct coordinates g-masked by the existing round machinery | inherits the v leak only |
| m commitments | 32 x 2 ring elements | committed, MLWE-hiding | NOT a leak [PROVEN, 2.1] |

So the base construction leaks ~1,400 K-elements (~22,000 Z_q scalars)
of challenge-keyed witness statistics per pass. This does NOT break
soundness, and it is bounded — but the R1 precedent (Q4.3d/e: "bounded
images" turned out to reconstruct the full product matrix C) forbids
waving it through. **Status: the lookup subprotocol as specified is NOT
zero-knowledge; ZK is an explicit obligation (E3-Z, Section 8)** with a
concrete candidate design: Libra/zkCNN-class masked sumcheck — commit
one small masking polynomial per descent (sum of univariates,
~3 K-elements per round, ~100 K-elements per pass, committed in the
statement wave before alpha) and open it at the challenge point, making
every round polynomial and boundary value uniform; plus one blinding
leaf block per instance to randomize the roots and final MLE values
(the blinding block's own MLE claim rides E4 at ~zero cost). Until
E3-Z lands, lookup-bearing proofs must be labeled non-ZK exactly as the
pre-R1 pi2 proofs were — the deployment instruction the repo has used
before, applied from day one this time rather than discovered in
review.

**Update (2026-07-10, tranche U-K5c/d/e): E3-Z LANDED — the label is
LIFTED.** The masked engine (`ring/gkr_masked.rs`) plus the committed
aggregate-pin layer (`ring/lookup.rs` pin claims) are built and
battery-tested (the `[U-K5c]`/`[U-K5d]` batteries in the ring self
test): the engine-scale m-recovery harness demonstrates rank-256 EXACT
recovery of the multiplicity column from the zero-mask transcript and
FAILS against the masked one; v^X/v^Y/v^M no longer appear in the
transcript (aggregate-only pins); the mask- and blinder-ordering
attack pairs (E3Z-N1/N2) and the rank canaries (E3Z-N4) are live. The
leak table above is re-graded row by row in M4_LOOKUP_ZK_DESIGN.md
Section 4, transcribed as lemmas Q4.7-Q4.9. Measured price: 2,311
committed K-elements per pass of mask material (36,976 committed
coefficients — noise class against the pass commit bill), masked
transcript 150 KB/pass at the frozen FFN point (freeze row LKP-7),
descent core x2.0 prove / x1.4 verify — sub-percent at pass level
because the descent is O(N) against the tensor weight-expansion. The
lift is subprotocol-level honest-verifier ZK (proof-of-protocol); the
U-K8 FFN integration remains OPEN.

## 4. The characteristic ceiling, designed in from day one

The log-derivative lemma pins COUNTS only mod char(K) = q ~ 2.1e9:
char copies of an out-of-table value vanish from the identity
IDENTICALLY (spike OK-4a — the false accept demonstrated live, and note
carefully: enlarging the extension does NOT help, the ceiling is the
characteristic, not the field size). The constraint is therefore
**N_instance < q per table instance**, and the fix is instancing
(spike OK-4b: split instances reject the same attack). The design bakes
instancing in from day one:

| workload | instancing | N_inst | ceiling margin q/N_inst | m columns per pass | m cost (dce/el) |
|---|---|---|---|---|---|
| SiLU, 7B, T=512 | per layer | 5.64e6 | **381x** | 32 x 256 coeffs = 8,192 dce | 4.5e-5 |
| SiLU, 7B, T=2048 | per layer | 2.25e7 | **95x** | 32 x 256 = 8,192 dce | 1.1e-5 |
| exp_q (softmax), T=2048, forward-look | per layer | 1.34e8 | **16x** | 32 x 16,384 (2^14-row table) = 5.2e5 dce | 1.2e-4 of attention volume |
| exp_q, T=2048, conservative | per layer PER HEAD | 4.19e6 | 512x | 1,024 x 16,384 = 1.7e7 dce | 3.9e-3 |
| range-lookup rung (Section 7), 7B/512 | per layer | ~2e7 | ~100x | 32 x 2^12-row table = 1.3e5 dce | ~2e-4 |

Bookkeeping rules, to be enforced at derive time and pinned by freeze
row LKP-2: (a) every table instance carries its own m column (2 ring
elements at T = 256 — instancing is nearly free, so err toward more
instances); (b) the derive-time gate asserts N_inst <= 2^25 (margin
>= 64x) and REJECTS shapes over it, the `arp_budget_ok` pattern;
(c) instances share alpha and the batched descent (Section 5) — the
ceiling is about counts per m column, not about challenge reuse. The
single-instance-per-pass alternative (one m for all 1.8e8 lookups)
would still clear the ceiling at T = 512 (12x) but dies at exp_q
volumes and was rejected for the reasons in Section 5 anyway.

## 5. Batching across tensors and layers — decided: per-layer instances, one rho-batched descent

Three candidate shapes were priced:

1. **One GKR instance per tensor, 32 independent transcripts.**
   Transcript and verifier cost x32 (253 rounds EACH, ~2 MB/pass);
   prover work identical; maximal ceiling margin. Rejected: pays 32x
   transcript for margin nobody needs (381x vs 12x is already ample).
2. **One monolithic instance (concatenate all layers, depth 28).**
   Minimal transcript (325 rounds), but: (a) ceiling margin drops to
   12x at T = 512 and BUSTS at exp_q scale — the instancing machinery
   must exist anyway; (b) the prover must hold the whole (p, q) tree —
   2 x 2^29 K-values ~ 68 GB at GF(q^16) — versus 2.1 GB per layer
   instance processed in sequence [MODEL]; (c) one bad tensor poisons
   the whole pass's transcript with no isolation. Rejected.
3. **Per-layer instances, rho-batched into ONE descent (RECOMMENDED).**
   All 32 witness trees share depth 23; draw rho in K^32 once (Section
   3.3) and run every layer's sumcheck on the rho-weighted sum of the
   32 instances' relations. One set of round polynomials and boundary
   values for the whole pass (253 + 28 rounds total); per-instance
   soundness rides the rho combination (2^-176-class, Section 2.1);
   the final claims collapse to rho-weighted tensor MLEs, which E4
   serves as the SAME 9 ct-claims (the weights just carry the rho
   factor per instance block). Prover memory: one instance's tree at a
   time IF the rho-weighted relation is accumulated instance-by-
   instance per layer (the sum over instances commutes with the round
   computation) — 2.1 GB transient [MODEL]. Ceiling margin 381x.

Decision: (3). The one asymmetry: the table descent is also rho-batched
(the 32 fused tables are IDENTICAL, so the batched table tree is just
the single table tree with leaf multiplicities sum_ell rho_ell m^ell_j
— the per-instance m columns still exist separately for the ceiling,
and the E4 m-claim reads the rho-weighted combination of all 32
committed columns; 256 public weights per column, trivial).

**BUILD NOTE (U-K3, `ring/gkr.rs`) — batching mechanism as built.**
Shape (3) is implemented with the instance index as e = log2(32) = 5
EXTRA sumcheck variables rather than an explicit rho vector: layer k's
descent runs one degree-3 sumcheck over (k + 5) variables, the
instance coordinates z_e are drawn once from the transcript
immediately after every instance's roots are bound (`absorb_roots` —
this placement IS the E3-N3 edge, pinned by the U-K3 malleability
pair), and the eq-weights of the bound instance coordinates play
exactly rho's role. Same soundness class, same single 4-value
boundary per layer, same E4 landing (the final claims are MLEs of the
CONCATENATED columns — the "rho-weighted" reading with eq(z_e*, ell)
as the weights). Deltas against this section's narrative: the witness
descent runs 368 rounds instead of 253 (the b-variables count above
ignored the 5 instance variables per layer), i.e. round-poly volume
~92 KB instead of ~63 KB per pass — recorded in the LKP-3 freeze row
(368/1472+92 witness, 68/272+32 table, degree 3); per-instance root
cross-checks are unchanged; prover memory unchanged (one instance's
layer tables streamed per descent step remains available since the
per-instance tables enter the round computation additively).

## 6. Soundness accounting

Every row graded; error terms at the recommended point (GF(q^16),
kappa = Y, rho-batched); "checked at" names the spike line, the planned
battery (Section 8), or the paper citation.

| # | step | grade | error term (pass) | checked at |
|---|---|---|---|---|
| 1 | log-derivative lemma: identity + counts-below-char => multiset inclusion | [PROVEN] (Habock 2022/1530 Lemma 5; partial fractions) | exact given rows 3, 9 | spike OK-1a/1b; citation |
| 2 | deterministic fusion kappa := Y: fused equality <=> pair equality for base-field data | [PROVEN — one-paragraph argument, Section 3.2; SKETCH until transcribed to the soundness reference] | 0 | spike OK-2d (exhaustive at toy scale); OK-2c guards the base-field regression |
| 3 | rational identity -> random alpha | [PROVEN] (Schwartz-Zippel; Papini-Habock Prop. 1 shape) | <= 2 N_pass/(|K|-N_pass) = 2^-467.6 | spike OK-1b/2e; battery E3-N1 |
| 4 | GKR layer reductions (sumcheck + mu folding) | [PROVEN] (Papini-Habock Prop. 2 / standard sumcheck) | <= 3 x 281/|K| = 2^-486.3 | spike OK-3b/3c; battery E3-N4/N5 |
| 5 | rho instance batching | [PROVEN] (SZ per layer) | <= 736/|K| = 2^-486.5 | battery E3-N3 |
| 6 | root cross-check (no inversions; Q != 0) | [PROVEN] (algebra; honest-alpha pole prob (N+T)/|K| is a completeness term, 2^-468) | — | spike OK-3a/3d |
| 7 | E4 landing: CtClaim extraction over extracted openings | [PROVEN] (SOUNDNESS_REFERENCE 4.2) once wired; the wiring is [OBLIGATION] until U-K6 | inherits round accounting | engine batteries + U-K6 exit |
| 8 | psi coordinate batching (48 rows -> 9) | [PROVEN] (theta-convention point mass) | 2^-279 | battery E4-N1 |
| 9 | characteristic ceiling: N_inst < q enforced | [PROVEN] constraint; derive-time gate + freeze row | structural | spike OK-4a/4b; freeze LKP-2 |
| 10 | FS ordering (every edge in 3.3) | [OBLIGATION] until the F5-pair batteries land | — | E3-N1..N5, E4-N1/N2 |
| 11 | FS grinding/forking loss (ROM) | [MODEL] (Section 1.5 convention) | absorbed by 151-bit margin | — |
| 12 | ZK of the lookup transcript | [PROVEN at engine scale] — HVZK via the E3-Z masking (leak inventory 3.5 re-graded, M4_LOOKUP_ZK_DESIGN Section 4; lemmas Q4.7-Q4.9) | n/a (hiding, not soundness) | `[U-K5c]` committed masked pass + m-recovery harness; `[U-K5d]` E3Z-N1..N4; freeze LKP-6/7 |
| 13 | prover/verifier cost claims | [MODEL] (measured ring-op anchors, linear scaling) | n/a | Section 7 arithmetic |

The composed statement: extract all commitments by the round's [PROVEN]
special soundness; rows 7-8 pin the claimed v^X, v^Y, v^M as the true
MLE values of the extracted tensors; rows 4-6 walk them up to the
LogUp identity at alpha; rows 3 then 1-2 convert the identity to exact
fused-multiset inclusion, i.e., (X_i, Y_i) pairs in the declared table
mod q; row 9 makes the counts exact over Z; the chain's upstream range
fact turns residues into integers (Section 1). Every step is exact
once its side conditions hold, and the failure probabilities sum to
~2^-279 per pass at the recommended point.

## 7. Cost, with the arithmetic shown

Units as in Section 0; anchors: pass commit bill 9.4e9 dce = 96-120 s
22T / 5-6 s GPU; matmul-claim layer over these elements 110-330 s 1T;
target 5-15 s/8B with <20% Class-3 overhead. All non-cited numbers
[MODEL].

Committed data, recommended point: 32 m columns x 256 coeffs = 8,192
dce per pass / 1.8e8 elements = **4.5e-5 dce/el** (plus E3-Z masking
columns ~100 K-elements = 1,600 coeffs — noise). Prover:
43 K-mults/el = 5.4 ring-mult-equivalents/el (Section 2.2) = 9.7e8
ring mults/pass -> ~9-22 s 22T / ~1-3 s GPU. Transcript: 63.3 KB
witness round polys + 5.9 KB boundary values + 9.2 KB table descent +
~9 KB E4 rows + ~33 KB m-commitment rows = **~120 KB/pass** (~3.8 KB
amortized per tensor). Verifier: ~5e7 ring-op class (~1-2 s 22T).

| construction | committed dce/el | prover field work/el | ring-mult eq/el | transcript/pass | verifier/pass | budget verdict (2-4 dce/el) |
|---|---|---|---|---|---|---|
| **LogUp-GKR (recommended: GF(q^16), kappa=Y, rho-batched)** | **4.5e-5** | 43 K-mult + 29 K-add | ~5.4 | ~120 KB | ~5e7 ring ops (~1-2 s 22T) [MODEL] | **met, ~5 orders of headroom** |
| LogUp-GKR at GF(q^6) (recorded alternative) | 4.5e-5 | 43 K-mult (~650-770 base) | — | ~55 KB | same class | met; new tower arithmetic |
| tlookup fallback (committed inverses; requires the GF(q^6) tower) | 6 | ~19 K-mult + batched inversion | — | ~40 KB | linear (same E4) | ~2x OVER budget; no GKR layer needed |
| Shout d=8 read-check (alternate shape) | ~0 new (reuses input bit planes) | 60-110 mult (degree-9 sumcheck) | — | ~50 KB class | linear | met, BUT hard-codes bit-plane inputs (violates the Section 1 interface) and shares E3/E4 anyway; no ceiling |
| piecewise Variant A (incumbent) | 105 | small | — | ~7 MB link rows | — | missed ~30-50x (+201% pass commit) |
| Variant B exact one-hot | 256 | small | — | — | — | missed ~80x (+491%) |

**Ladder impact.** The A1-integrated baseline pass is ~15-30 s
(GPU-assisted commit). The piecewise plan would have pushed it to
~35-55 s (+201% commit, +15-18 s GPU). The lookup replaces that with:
commit +0.00009% (invisible), prover +1-3 s GPU (or +9-22 s at 22T
CPU-only), transcript +~120 KB — **the pass stays ~15-30 s**, i.e.,
the activation rung stops being a rung at all [MODEL]. Class-3
criterion: commit headroom ~5 orders; in TIME terms the lookup adds
~5-15% GPU / ~8-18% CPU of the pass — inside the <20% budget [MODEL].
Output-side bonus (from the literature review, Section 5.1): if the
downstream gadgets can consume the table-certified Y without its own
range planes, the lookup's marginal cost vs today's baseline is
NEGATIVE on the output side (up to -8 planes/el of chain-native cost)
— engine question, not claimed in the table.

**The later range-lookup rung [MODEL, flagged].** The same E3+E4
machinery makes every w-bit range proof a lookup into [0, 2^w): the
baseline pass is 82.8% bit-plane coefficients (7.78e9 dce); replacing
per-bit planes + ARP with per-layer range-table lookups could cut the
commit bill 2-4x toward the ~5-10 s ladder rung, at ~43 K-mults/el of
prover time over ~6.5e8 range-proved values (~3-8 s GPU class). The
ceiling holds only with per-layer instances (~100x margin, Section 4).
Nothing in this design blocks it; the SiLU lookup is deliberately its
1/50th-volume pilot. NOT a commitment — a priced option.

### 7' — lookup-core measurement addendum (lookup-bench, 2026-07-10;
### relabeled per the 2026-07-10 audit H-01/H-02 — the U-K8 exit is
### now CLOSED at row-block granularity, see Section 7'')

`ring_matmul lookup-bench` is an UNMASKED, UNCOMMITTED, single-thread
lookup-CORE microbenchmark (fused leaves, trees, descents, verify with
direct MLE grounding, E4 weight stream — it does NOT run the E4
ct-round, the U-K5 masking, an upstream range proof, or a downstream
Hadamard, and it is not FFN-shaped). Measured at N = 2^18 and 2^20
(rates agree to 1%, so the extrapolation is linear):

- **The committed-cost claim HELD exactly as designed**: one 256-row
  multiplicity column per instance, ~0 dce/el — the axis the Class-3
  criterion prices, and the axis on which the M4 decision was made.
- **The prover-time constant did NOT hold as-built**: measured
  10.8-10.9 us/element single-thread (fuse+trees+descents; verify
  +0.38 us/el; E4 weight stream +0.9 us/el) versus the ~0.5-1 us/el
  the Section 7 [MODEL] row implied. The gap is implementation class,
  not operation count: the model priced kernel-grade K-mults (8-lane
  slot packing riding the A1 kernels, lazy reduction); the as-built
  arithmetic is scalar schoolbook `slot_mul_g` with a per-mult
  reduction, and the 4-node round evaluation pays full K-mults.
  Pass impact at 1.8e8 elements: ~1.95 ks 1T [MEASURED-AT-RATE]. The
  22T row (~222-224 s) is **[ASSUMED]**: the lookup code has no
  parallel implementation, and the 8.74x factor is imported from the
  M5 COMMIT-kernel measurement — a different workload (audit
  2026-07-10 H-02). The GPU row uses the repo convention (20x over
  the 22T row, matching m5-bench) and is [ASSUMED] — ~11 s class IF
  both factors held; unknown until a backend exists.
- **The M4 verdict is unchanged, with honest numbers**: even as-built,
  ~1.95 ks 1T (~222 s 22T [ASSUMED]) beats the piecewise incumbent's
  +201% of the (M5-corrected) commit bill (~250-360 s at 22T on the
  same assumption class) AND removes its +201% commit-stream cost
  entirely. Reaching the design's
  "sub-dominant activation rung" (~10-25 s at 22T) requires the
  kernel-grade K-mult tranche — named **U-K9**: lane-packed bulk slot
  arithmetic through the A1 kernel class + lazy reduction inside
  `round_poly`/`build_tree` (plausible 5-10x from reduction discipline
  plus the 8x lane occupancy; measured, not assumed, when it lands).

### 7'' — U-K8 committed-chain integration addendum (ffn-chain,
### 2026-07-10 — the audit H-01 exit, closed at row-block granularity)

`ring_matmul ffn-chain [n_blocks | battery]` is the first run of the
MASKED, COMMITTED lookup INSIDE a chain: X range-proved upstream (q46
bit planes + ARP + the U-L modulus link), Y = SiLU(X) table-certified
by the [U-K5c] masked pass with aggregate-only pins, and Y consumed
downstream by a gate-o-up Hadamard against a second committed tensor
UP, producing the block output Z — all under one validated v2
statement (Binary/Range/Lookup/Hadamard operations, output Z) whose
digest is the ctx of every challenge. The slot-packed E4 variant is
now REAL: Y lives only slot-packed (H3), and the lookup's Q-pin reads
it through per-coefficient weights composed from the slot-constant CRT
projection rows (`ring/lookup.rs::slot_pin_weights`) — the Section 3.4
"same claim family, different public weight computation" promise,
exercised against commitments. The battery (in self-test) holds the
honest ACCEPT plus a REJECT at every chain edge: out-of-range X (the
link's target rows), off-table Y (the blinded root cross-check, with
wave/range/Hadamard still passing — the edge is isolated), a tampered
Hadamard output (the quad ring claim), and the F5 ordering pair for
the chain's one NEW hash edge — zeta (the E2 slot-constancy weights)
drawn before the slot commitments ACCEPTS crafted junk coordinates
whose gate-o-up output constants are WRONG while the lookup itself
still passes; the shipped post-commitment zeta REJECTS the same junk.
Freeze row LKP-8 pins the operating point.

**The two as-built capacity walls this integration surfaced** (neither
was visible from lookup-bench or the battery-shape U-K5c rig):

1. **The q31 C2 wave cap binds BEFORE the audit H-03 memory wall.**
   One ct-round at the working CRS shape (kappa 8, n_r 26, msg_r 8)
   satisfies the C2 gate q > 8 beta only up to ~134 commitments
   (~4.4e5 committed coefficients), so a SINGLE committed masked
   descent caps near 2^17 dense elements — an order of magnitude below
   the 5.6e6-element FFN gate instance the design's Section 5 batching
   assumed. The chain therefore runs 1020-element ROW-BLOCK
   sub-instances (Section 9 item 5 sub-instancing: own m column,
   masks, blinders, descents, pins and round per block; ceiling margin
   only improves). Lifting the per-instance cap needs wide/multi-round
   commitment machinery (M5-chunking class) or a CRS-shape rework —
   named follow-up work, not attempted here.
2. **The q46 ARP granularity + restart coupling.** The range side's
   binary units cap at ~896 bit-coefficients AND the rejection alpha
   is budget-capped (~4 at 512-bit units), while FS-with-aborts
   restarts all units of a round together — the frozen chain point is
   512-bit units, alpha 3.5, 4 units per grounding round (measured
   ~50 restarts/round mean, high variance — a rate SUPERSEDED by the
   2026-07-13 fixes, Section 7'''; the granularity/coupling wall
   itself stands). Range throughput, not the lookup, is the chain's
   wall-clock wall.

**Measured marginals** (ffn-chain 16 = 16,320 elements, single-thread;
labels: [MEASURED-AT-RATE] = measured at this shape and linear in
blocks by construction; every wall-clock is [NOISY-SHARED] — a second
agent was benchmarking on the same 22-thread box, so these establish
magnitude, and the quiesced re-measurement is the orchestrator's):

| axis | lookup-integrated arm vs lookup-omitted arm |
|---|---|
| committed data | +14,336 q31 coefficients per 1020-el block = **14.1 dce/el** (m column + blinders + Libra masks + 9 pin g-masks; a FIXED per-instance cost — amortizes as 1/B: ~1e-4 dce/el at the design's 5.6e6-el instances [MODEL]) |
| prove | **+206 us/el** (q46-restart noise excluded; lookup-stage attribution 100 us/el = trees + masked descents + pin building, the rest is the wave round growing by the pin claims) |
| verify | **+50-130 us/el** (box-noise-wide; attribution 40 us/el) |
| commit time | +64 us/el |
| transcript | +38,272 B/block = 37.5 B/el |
| peak RSS | unchanged, 0.29 GiB total — blocks stream; H-03's memory wall never binds at this granularity |

[Relabel 2026-07-15, audit 2026-07-14 C-03: the "transcript" row is
masked-descent bytes only — it EXCLUDES the per-round ct-round proof
objects (z/w1 opening arrays) a non-interactive verifier must
receive, so it is not proof size. The adopted byte accounting lives
in RANGE_AGGREGATION_DESIGN.md Section 3b "Proof bytes, honestly".]

Context for the prove marginal: the unmasked, uncommitted lookup CORE
runs at 10.9 us/el (Section 7'); the committed + masked + pinned
integration at 1020-element instances costs ~6-9x that in-stage plus
the wave growth — mostly FIXED per-instance material (masks, blinders,
pin claim building) that larger instances would amortize. Per 7B/512
pass (1.8e8 activation elements) the as-built lookup marginal
extrapolates to ~37 ks 1T [MEASURED-AT-RATE at block granularity] vs
~1.95 ks 1T for the bare core — the gap IS the price of the C2 wall's
tiny instances, which is why the wall is named above.

**The differential against piecewise variant A** (the incumbent this
design replaced, M4_ACTIVATION_DESIGN Section 7): even at the WORST
amortization the chain can exhibit (B = 1020), the lookup's committed
marginal is 14.1 dce/el vs variant A's 105 dce/el — 7.4x — and the
variant-A +201% pass commit stream does not exist at all in the lookup
chain. The M4 verdict survives its first committed integration on the
axis it was decided on, with the honest caveat that the TIME axis at
block granularity is dominated by per-instance fixed costs until the
C2 cap lifts.

The chain totals, for the ladder: ~10.7 ms/el 1T prove for the WHOLE
chain, of which ~96% is the q46 range family (582 dce/el of q46
commitments, ARP claim volume, restart loops) — both arms pay it, it
cancels in the marginal, and it reconciles with the ladder's
"bit planes are 82.8% of the pass" finding: the activation lookup is
not the pass's problem; ranges are (the Section 7 range-lookup rung
remains the priced option for that).

### 7''' — supersession note: the ARP restart rate (2026-07-13 fixes,
### recorded 2026-07-14)

The restart figures recorded above and in the U-K8 ledger — capacity
wall 2's "measured ~50 restarts/round mean, high variance", the A-D2
ledger's ~52/round, and the D-3 design expectation of ~6.5 expected
restarts/round they were measured against — are SUPERSEDED as
operating-point rates by two 2026-07-13 fixes. The 2026-07-10
paragraphs above stand unedited as the honest record of what was
measured then; this note is additive.

1. **log M parameterized by alpha (commit e6727e4).**
   `rejection_accept` (ring/mod.rs) hard-coded
   log M = 1 + 1/288 — the t = alpha = 12-sigma convention — while
   the chain's ARP samples masks at UK8_ALPHA = 3.5: per-unit accept
   e^-1.0 instead of the designed e^-0.47, predicting ~55
   attempts/round for a 4-unit-coupled round, which matches the
   ~52/round A-D2 measured. The rate was a mis-sized constant, not
   the design. Fix: log M is now a `rejection_accept` parameter;
   ArpParams carries log M = t/alpha + 1/(2 alpha^2) at t = 1.5
   (ARP_REJ_T, the LKP-8 e^-0.47 point); sigma.rs's 12-sigma call
   sites keep the old constant explicitly. ZK-safe in both directions
   (the old constant was conservative). Measured (ffn-chain 1, two
   runs): restarts 240 -> 61/66 total over 8 rounds — the design
   rate. Suite 42/42 + freeze-check green; the LKP-8 freeze gates are
   unmoved (they pin arp_budget_ok, which does not involve log M).
2. **Joint Q4.2b rejection across the round's 4 coupled units
   (commit 92ca018).** One summed-exponent test (`arp_attempt_joint`)
   replaces the per-unit product test in the ffn-chain grounding
   loop: expected ~2.8 attempts/round vs the product scheme's ~6.5,
   accepted output distribution unchanged per the PROVEN lemma
   (Q4.2b); the per-unit y-bound gate and `arp_check_reveal` are
   untouched. `joint_rejection_accept`'s log M is caller-supplied;
   its 12-sigma ct-round call site keeps `joint_log_m_alpha12`.
   Measured (ffn-chain 1, three runs): restarts per arm 4/10, 5/5,
   14/3 over 4 rounds — on the lemma's prediction; the whole
   ffn-chain battery ran with 3 restarts total (8/8 green).

Combined effect: restart work ~17x down vs the 2026-07-10 figures
(~240 -> ~14 restarts per 1-block run). What is NOT superseded:
capacity wall 2 itself (the ~896-bit unit cap, the budget-capped
alpha, and the whole-round restart coupling are architecture, not
rate); the Section 7'' measured marginals (the prove marginal already
excluded q46-restart noise); and the chain-total split (the ~96% q46
share was measured before the fixes). No new wall-clock number is
claimed here: the box was [NOISY-SHARED] with ~2x run-to-run q46
variance, and the post-fix wall-clock share awaits the orchestrator's
quiesced ladder pass.

U-R2 S3 result pointer (2026-07-14): the range-lookup pilot replacing
this wall's plane+ARP architecture is PILOT-MEASURED —
RANGE_AGGREGATION_DESIGN.md Section 3's appended table (range
certification at ~0.07-0.27 dce/el and ~+15-18 us/el prove
attribution vs 582 dce/el / ~10.3 ms/el as-built); the rejection
constants above are now pinned both directions by freeze row LKP-9.

Forward plan for the range wall itself: RANGE_AGGREGATION_DESIGN.md
(paper-first study, commit b6bb1e2) prices the Phase-5 pair — the
multi-wave C2-cap lift and the range-lookup rung — and its proposed
U-R tranche is now OPEN with S0 (multi-wave claim splitting) landed
(commit 7b2a57c; ledger PROGRESS_UR.md).

## 8. Build plan: the E3/E4 tranches

Discipline as in AUTOMORPHISM_GATE_DESIGN Section 7: paper-first items
named; every hash edge lands with its F5-pair negative battery; every
frozen constant gets a freeze row. E3 = the sumcheck/GKR transcript
layer over GF(q^16); E4 = the MLE-evaluation claims. Both are exactly
the two obligations GATE_ALTERNATIVES option 2 needs — build once, use
twice.

**E3 — U-K1..U-K5:**

- **U-K1 — slot-field scalars.** GF(q^16) helpers over the existing
  CRT layer (mul/inv/pow/serialize, embedding, coordinate projection
  via `crt_coord_rows`), plus the 8-lane packing adapter (8 independent
  K-values per ring element for bulk GKR work). Exit: field-axiom and
  lane-consistency battery (slot-packed bulk ops bit-identical to
  scalar ops); freeze row LKP-5 (slot binomial constants digest).
- **U-K2 — sumcheck core.** The degree-3 sumcheck prover/verifier over
  K-vectors with the little-endian variable convention (the spike's
  recorded bug class); Lagrange fold; transcript hash chain
  (h0_lkp -> alpha -> rho -> per-round). Exit: honest ACCEPT + tampered
  round poly REJECT at toy and FFN shapes; E3-N4 F5 pair (round poly
  after r ACCEPTS a false claim / shipped order REJECTS).
- **U-K3 — fractional GKR.** Projective tree builder (streamed,
  per-instance memory cap [MODEL: ~2.1 GB]; dummy-leaf padding), layer
  descent with lambda/mu folding, root cross-check, rho batching, the
  derive-time ceiling gate (N_inst <= 2^25). Exit: honest/tamper pairs
  (tampered layer, wrong m, wrong y — the spike's OK-3c/3d at engine
  scale); E3-N1/N3/N5 F5 pairs; freeze rows LKP-2 (ceiling gate) and
  LKP-3 (transcript shape at the frozen FFN point: depth 23, 253+28
  rounds, degree 3, byte count).
- **U-K4 — the kappa regression.** The Y-fusion wiring plus E3-N2: a
  deliberately mis-built base-field-kappa variant ACCEPTS the OK-2c
  crafted pair; the shipped Y-fusion REJECTS it (both directions kept
  live, F5 style). Exit: the pair green; table-digest binding (LKP-1)
  asserted in ctx.
- **U-K5 (E3-Z) — ZK masking design round.** Paper first: Libra-class
  masking polynomials + blinding leaf block, simulation argument in
  the Q4.3 machinery, THEN implementation. Exit: leak inventory of
  Section 3.5 re-graded row by row with a simulator or an explicit
  residual; the non-ZK deployment label lifts only when this lands.
  [DONE 2026-07-10 — it did spawn its own design round
  (M4_LOOKUP_ZK_DESIGN.md), and the build landed across U-K5a/b
  (08051af, masked GKR core + LKP-6), U-K5c/d (committed masked pass,
  m-recovery closed, E3Z-N1..N4, LKP-7), and U-K5e (lemmas Q4.7-Q4.9 +
  the SOUNDNESS_REFERENCE Section 7 rows + this re-grade). The exit
  criterion is met and the label is lifted — see the Section 3.5
  update.]

**E4 — U-K6..U-K8:**

- **U-K6 — evaluation-claim wiring.** Streaming tensor-weight
  generation (doubling recursion, block-streamed; never materialize
  L), coordinate projection to base-field rows, psi batching to 9
  CtClaims via `pack_functional`, the slot-packed (E1-composed) weight
  variant, m-column wave placement. Exit: end-to-end honest ACCEPT on
  a real committed FFN-shape tensor; wrong-v REJECT; wrong-tensor
  REJECT; measured verifier cost recorded against the Section 7
  [MODEL] row.
- **U-K7 — E4 hash edges + freeze.** E4-N1 (psi-before-v F5 pair);
  E4-N2 (rejection-restart regression: a restarted round re-derives c
  but alpha/r/psi unchanged — the link-round pattern); freeze row
  LKP-4 (psi copies = 9, row counts, weight-stream digest at the
  frozen point).
- **U-K8 — integration + report.** One FFN gate tensor end-to-end
  through the chain (range-proved X in, table-certified Y out,
  downstream gate-o-up consuming Y), differential against the
  piecewise variant-A numbers, cost-table reconciliation into
  LLM_SCALE_ESTIMATE and TRANSFORMER_PROOF_PLAN Section 2. Exit: the
  M4 decision memo updated with measured (not [MODEL]) marginal costs.
  [DONE 2026-07-10 (audit H-01 reopen closed at block granularity):
  `ring_matmul ffn-chain [n_blocks | battery]` + the `[U-K8]` battery
  in self-test — the masked committed lookup runs INSIDE a chain with
  a validated v2 statement (Binary/Range/Lookup/Hadamard, output Z),
  q46-grounded upstream range on X, the slot-packed E1-composed E4
  pin variant on Y (`ring/lookup.rs::slot_pin_weights`), downstream
  gate-o-up quad claims with zeta slot-constancy rows, tamper REJECTs
  at every chain edge and the zeta F5 ordering pair, freeze row LKP-8.
  Measured marginal costs and the two as-built capacity walls the
  integration surfaced (the q31 C2 wave cap and the q46 ARP
  granularity/restart coupling) are in the Section 7'' addendum. The
  full 512x11008 single-instance shape did NOT run — the C2 wave cap
  binds a single committed descent near 2^17 elements (before the
  audit H-03 memory wall), so the chain runs 1020-element row-block
  sub-instances (design Section 9 item 5); lifting the per-instance
  cap is wide-commitment/U-K9-class follow-up work.]

Freeze-row drafts (names final, values pinned at U-K landing):
**LKP-1** table spec digest (silu-int8-table-v1); **LKP-2** ceiling
gate (N_inst <= 2^25, margin >= 64x); **LKP-3** transcript shape
(depth/rounds/degree/bytes at FFN point); **LKP-4** E4 psi copies and
row counts; **LKP-5** slot-field constants digest.

## 9. What could kill this (each with a mitigation or an open flag)

1. **ZK of the transcript (the big one).** Every sumcheck message is a
   witness statistic (Section 3.5); the R1 history says "bounded leak"
   claims die in review. Mitigation: E3-Z (Libra-class masking +
   blinding leaves), designed paper-first; until it lands, lookup
   proofs carry the explicit non-ZK label. If E3-Z's simulation
   argument fails to close, the fallback is masking at the STATEMENT
   level (commit X, Y under fresh randomizing linear maps per proof) —
   costly, so treat E3-Z as design-blocking for ZK deployments.
   **Open flag, highest priority.** **RESOLVED (2026-07-10): E3-Z
   landed with its battery green (Section 3.5 update); the
   statement-level fallback was never needed.**
2. **Extension-field inversion in the prover.** RESOLVED by
   construction: the projective (p, q) accumulation never inverts —
   that is precisely Papini-Habock's contribution (spike OK-3a). The
   verifier performs O(1) inversions (Lagrange denominators are fixed
   integers). Only the tlookup FALLBACK pays inversion (batched
   Montgomery, ~3 mults/el amortized). Closed.
3. **Transcript size of a depth-23 GKR at 2^27.5 leaves.** Computed,
   not feared: ~120 KB/pass at GF(q^16) (Section 7) — noise against
   MB-class matmul-claim proofs. If it ever matters, GF(q^6) (~55 KB)
   or send-3-of-4 round polys shave constants. Closed [MODEL].
4. **Interaction with rejection-sampling rounds.** The lookup
   transcript is deterministic and strictly precedes the E4 ct-round;
   restarts re-randomize only the round (c, masks), never alpha/r/psi
   (Section 3.3 rule 1). Residual: FS grinding across ~300 challenges
   — absorbed by the 151-bit margin [MODEL]. Pinned by E4-N2. Low.
5. **Prover memory for the layer trees.** ~2.1 GB transient per layer
   instance at GF(q^16) [MODEL]; per-layer sequencing (Section 5) caps
   it; sub-instancing (row blocks) is free if a smaller cap is needed
   (ceiling margin only improves). Low.
6. **E4 verifier linearity.** ~5e7 ring-op class per pass (~1-2 s 22T
   [MODEL]) — acceptable now; flagged so nobody claims sublinear
   verification of the lookup layer. Future path: Greyhound-class
   evaluation proofs. Medium, monitored at U-K6 exit.
7. **The characteristic ceiling at future workloads.** exp_q at
   T = 2048 busts a single-instance design (4.3e9 > q); per-layer
   instancing (16x margin) or per-head (512x) is baked in from day one
   (Section 4, freeze LKP-2). Closed by design; the spike's OK-4 pair
   is the regression seed.
8. **Slot-lane under-utilization.** The 8-lane throughput model
   assumes fillable lanes; the top ~3 tree layers and odd tails
   under-fill. They are geometrically negligible (<1% of nodes), but
   the 5.4 ring-mult/el figure stays [MODEL] until U-K3 measures it.
   Low.
9. **The 43 mults/el constant itself.** Taken from Papini-Habock's
   operation count, not from any lattice-backend measurement (the
   literature review's honest gap: nobody has measured LogUp-GKR over
   Sigma-protocol lattice commitments — this build is the first). If
   the constant lands 2-3x worse in practice, the GPU path still
   clears the budget; the CPU-only path degrades toward ~25% of pass
   time. Monitored at U-K3/U-K8 exits with measured numbers replacing
   every [MODEL] tag.

## 10. Spike output (recorded verbatim)

`python3 scripts/logup_gkr_spike.py`, 2026-07-09, exit 0:

    OK 1a: log-derivative identity with multiplicities holds (GF(97^3), Y^3 - 2, N=128, T=16)
    OK 1b: one out-of-table witness value rejected at 3 random alphas
    OK 2a: fused-pair lookup x + kappa*y passes on the honest witness
    OK 2b: a wrong y at one element is rejected (3 random alphas)
    OK 2c: kappa ordering edge (F5 pair): base-field kappa known first ACCEPTS the exact fused collision (5 alphas); a kappa drawn after commitment REJECTS the same crafting
    OK 2d: extension-field kappa admits NO base-field forgery even when known in advance (brute force over all y' and rows, random kappa AND kappa := Y) — the deterministic-fusion basis
    OK 2e: alpha ordering edge (F5 pair): m crafted AFTER alpha ACCEPTS a corrupted witness; a fresh alpha REJECTS the same m
    OK 3a: projective (p,q) tree root equals the direct fractional sum (N=64 leaves, depth 6)
    OK 3b: full layered GKR transcript verifies: root cross-check, both descents, leaf MLE claims = public-weight inner products (the E4 shape) for x, y, and the multiplicity column
    OK 3c: a tampered interior layer value is rejected by the layer sumcheck (round-sum mismatch)
    OK 3d: wrong y at one leaf passes its own (consistent) descent but is rejected by the root cross-check — semantic soundness lives in the alpha-identity, as designed
    OK 4a: characteristic ceiling attack: N=16 >= char=13, 13 copies of out-of-table value 11 vanish from the identity -> FALSE accept at 5 random alphas (extension size 2197 does not help; the ceiling is the CHARACTERISTIC)
    OK 4b: per-instance splitting (8 + 8 < char each) REJECTS both sub-instances — the fix the design bakes in as per-layer table instancing
    OK 5a: MLE(x)(r) equals the public tensor-weight inner product <L(r), x> (N=64) — the E4 claim is a public-weight linear functional of the committed column
    OK 5b: v decomposes into e=3 base-field public-weight functionals (the ct-claim landing; e=16 in the slot field)
    OK 5c: a tampered witness coefficient breaks the pinned functional value (binding through the weights)
    all logup_gkr_spike assertions passed

Development note, recorded for honesty: the spike's one real bug during
construction was a variable-ordering mismatch (tensor weights built
big-endian against a little-endian MLE fold) — caught because OK-3b
runs the FULL transcript, not just the identities. The engine build
(U-K2) inherits "little-endian everywhere" as a stated convention and
the lane-consistency battery guards it.

---

*Changelog: 2026-07-09 — first edition (M4 lookup design round):
statement + interface, field decision (GF(q^16) slots over GF(q^6)
tower), full protocol with hash-edge drafts and the kappa := Y
sharpening, ceiling bookkeeping, batching decision, graded soundness
table, cost table + ladder impact, E3/E4 build plan (U-K1..U-K8),
risk register, spike output recorded (16/16 OK).*
