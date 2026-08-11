# U-AG-B1 T_blind Report — Lane BL (wave 4: masking the weight-touching round polynomials in the composed P2 path)

Status: PLAN (2026-08-10, U-AG-B1 wave 4, worktree wt-uagb1-bl,
branch uagb1-bl, base f75aba3). Sections marked [PLAN] are the
pre-implementation design transcription (deliverable 1); measured
sections land as the stages land. Machine: Victor's Mac (Apple
silicon) — NOT the contract reference box; every timing [MAC-BOX,
non-reference], [NOISY-SHARED] where sibling lanes (BJ/BK/PV-S2) run
concurrently. Byte counts, rank certificates, battery verdicts and
freeze rows are machine-independent.

## 0. What this lane closes, in one paragraph

BG's wave-3 composed P2 pass (UAGB1_PASS_AGG_REPORT.md) masks the
weight group's eval-proof FLOOR (Tier-Z, once per pass) but ships the
weight-touching ROUND POLYNOMIALS and weight-side TERMINALS in
cleartext — the honest gap BG labeled "T_blind absent = E-1..E-5,
~1,664 B [MODEL]" (FP 3.2's 4 x 416 B midpoint). This lane
transcribes the O-4 T_blind + masked-sumcheck design
(AGGREGATION_ZK_DESIGN Sections 2-3: AZ-L1a round masks, AZ-L2a
selector-extension terminal pads, AZ-L2b unit-weight claim segment)
onto the composed engine path, mode-gated so P0 (and the noblind-P2
battery config) stay byte-identical, and wires the AZB E-blocks the
stage unlocks (E-1..E-5, plus E-7(ii,iii)/E-8/E-9). I-6 stays hard:
no new Gaussian-masked opening anywhere — the blinding is committed
T_blind material + masked sumcheck only; the single Gaussian object
remains BG's priced Tier-Z floor response.

## 1. The leak inventory at the composed P2 path [PLAN]

Under P2 (private set = the 36 weight-class entries; activations
public by declaration), the composed artifact's weight-referencing
cleartext surface, beyond the already-masked Tier-Z floor:

| # | object | bytes/pass (12L) | leak form |
|---|---|---:|---|
| L1 | round polynomials of mm-gate/mm-up/mm-down | 3 x ~38-41 kel | each round sends d+1 evaluations of a polynomial whose coefficients are public-kernel contractions of the WEIGHT tables (tb) — challenge-keyed weight functionals, accumulating across proofs (the R1 principle) |
| L2 | weight-side terminals b* (final_evals[2]) | 3 x 64 B | raw MLE(W-fold)(k*, l*) — one exact weight functional per instance per proof (the AZB-1/E-1 object) |
| L3 | weight-group claim rows b_rows | 16 x 516 B | ct coordinates are public by design (= v_batch, the ct-row-gate); the 16 x 127 NON-ct coordinates are inner products of rotated claim kernels with the weight witness — the batch-value face (AZ-L2b's object at the engine's conj-packed realization) |

Not in scope: the act group (public in P2 — P1/P3 keep refusing,
with the refusal text updated to name the act-side mask as the ONLY
remaining absent piece); commitment hiding tails (u_0/u_i are
deterministic Ajtai images engine-wide — a pre-existing structural
gap of the eval-proof layer shared by every landed wave, adjacent to
but distinct from the round-polynomial scope; recorded as finding
BL-F1, not built here — eval_proof.rs is lane BJ's zone this stage).

## 2. The construction, transcribed to the composed path [PLAN]

### 2.1 T_blind commitment shape (the zero-extra-identity decision)

T_blind = CLASS_Q31C tensors (full centered mod-q residues, e0 = 2,
l0 = 16, mod-q-native recomposition) APPENDED TO THE WEIGHT GROUP's
registry before precommit:

| tensor | shape | values | digit rings | role |
|---|---|---:|---:|---|
| tbl-mask-{gate,up,down} | n_g_pad x 16 | n_g_pad x 16 | n_g_pad x 2 | round-mask coefficients as K-coordinate grids (n_g = 1 + sum d_t = 2*lk + 3*lambda + 4 incl. the extension round; padded to n_g_pad = next multiple of 8 for the no-tail discipline, pad rows carry zero kernel weight) |
| tbl-pad-{gate,up,down} | 1 x 128 | 128 | 16 | the b* terminal pad ring (AZ-L2a, ring-granular per AZ-R1) |
| tbl-claimseg | 16 x 128 | 2,048 | 256 | the unit-weight claim segment (AZ-L2b): value ring c enters b_rows[c] diagonally |

125M pass totals: 3 x 96 + 256 = 544 blind digit rings on 3,538,944
(+0.015%); battery shape (3 layers, T = 16): 496 on 884,736. The
weight group's ONE u_0 outer identity covers T_W ++ T_blind, and
h0_agg contains u_0 — the "T_blind digest inside h0 before any
challenge" edge (AZ-L4/FP-L2 A6/A7 class, E-3's object) is thereby
realized structurally at the u_0/descent face with ZERO extra
identity bytes. DEVIATION RECORDED: the design tables (FP 3.3 /
PARAMS 2.5) price T_blind as a THIRD outer identity (+5,680 B); the
composed engine path gets the same pre-challenge binding from the
group identity because the blind columns are witness columns of the
one batched opening (E-O2-BB: still exactly one opening per group).
Consequences: (i) the E-3 battery pair's shipped REJECT surfaces at
the commitment-binding/descent gate rather than as an h0 digest
mismatch — same edge, engine face; (ii) mask material rides the
Tier-Z-MASKED weight descent and NEVER lands in a bare floor (the
act floor stays blind-free — the AZB-11 invariant is untouched).

Freshness (E-5/A7): blind values are drawn per proof from a
session-fresh ProverRng; the derive path keeps a process registry of
SHA(witness digest || T_blind digest) and REFUSES a repeat loudly
(deployment-blocking, F-Z3 semantics). The registry is the engine
realization of "the statement hash records the T_blind segment id".

### 2.2 The masked instance (Surface 1 + Surface 2 per matmul)

Extended index space: one selector-extension bit as the TOP variable
(bound last; the engine binds low bits first): tables of size
2^(lk + lambda + 1), schedule [2; lk] ++ [3; lambda] ++ [2].

- ta_ext: A-table on the 0-block, ZERO on the 1-block (activations
  need no pad in P2) — so the extended cube sum equals the original
  claim v_c exactly (every 1-block product has a zero side; the
  selector arrangement of AZ-L2a step 2).
- tb_ext: B-table on the 0-block; on the 1-block, delta(k = 0) *
  beta_t replicated over l, with beta_t = sum_{j<128} beta_j *
  eq_ry[j] — committed pad content contracted with a public
  sub-kernel of the instance's own eq_ry.
- eq_exp_ext: the layer-eq table replicated across ext (round-poly
  degree 2 in the ext round).

Per-instance FS order (the E-4 edges): r_l, rx, ry drawn -> v_c
absorbed -> **G pin absorbed** (G = sum_cube g = 2^n c_0 + 2^(n-1)
sum_t p_t(1)) -> **rho drawn** (the mask activation challenge —
after G, edge E-4(iii)) -> masked rounds (product part by the house
round_poly/fold arithmetic + rho * the additive mask contribution
M_t(X) = 2^(n-t-1)[c_0 + sum_{s<t} p_s(r_s) + p_t(X)] +
2^(n-t-2) sum_{s>t} p_s(1)) -> final_evals absorbed -> **g_open
absorbed** (= c_0 + sum_t p_t(r_t)). Masked initial claim = v_c +
rho*G; verifier end check: running claim == eq* a* b* + rho*g_open,
with eq* recomputed (constant in k/ext by replication), and a*, b*,
g_open grounded through the batched opening:

- a* claim: value = shipped a*, real parts scaled (1 - ext*) *
  eq_ls[li] (act group).
- b* claim: value = shipped (blinded) b*, real parts (1 - ext*) *
  eq_ls[li] (weight tensors) + blind part {tbl-pad, scale = ext* *
  eq_ks[0], row = [1], col = eq_ry[..128]}.
- mask-opening claim: value = g_open, blind part {tbl-mask, scale =
  1, row = monomial kernel [1, r_1..r_1^{d_1}, ...] (zero on pad
  rows), col = the 16 K basis vectors} — nu-weighted like any claim.
- v_c claim: unchanged (act side).

Guards (Q4.8 class, ~2^-496 events): ext* not in {0,1}, eq_ks[0]
nonzero, pad kernel nonzero — asserted, restart counter logged
(expected 0).

### 2.3 The claim segment (Surface L3)

One BgClaim with value v_s (shipped, uniform) and blind part
{tbl-claimseg, scale = 1, row = the 16 K basis vectors, col =
[1, 0, .., 0]}: by the conj-packing arithmetic its bpoly for row c
restricted to segment value ring c is the unit polynomial — value
ring c is added VERBATIM to b_rows[c], covering all 128 coordinates
of every row (ct included; the ct face is public via v_batch as
designed). It enters v_batch at UNIT weight, appended after the nu
draws (AZ-L2b's unit-weight discipline — no adversarial nu
degeneracy can cancel it): vb_w = sum nu_i v_i + v_s.

### 2.4 The derived byte surcharge vs BG's [MODEL] price

| line | derived B |
|---|---:|
| per masked instance: G pin 64 + mask opening 64 + extension round (deg-2, 3 evals) 192 | 320 |
| x 3 instances (mm-gate, mm-up, mm-down) | 960 |
| claim-segment value v_s | 64 |
| **TOTAL wire surcharge (P2+blind vs P2-noblind)** | **1,024** |
| committed-only (zero wire): 544 blind digit rings at 125M | 0 |
| BG's price for the same gap | ~1,664 [MODEL] |

The 640 B delta is structural, not slack: FP 3.2 priced FOUR masked
instances (3 matmuls + the CR-L4 terminal-batch sumcheck at 416 B
midpoint); the composed engine path has NO terminal-batch sumcheck
(BD replaced it by direct nu-RLC into the 16 conj-packed rows), so
its masking face is the 64 B claim segment instead of a fourth
320-512 B instance. Schedule effect: floors expected UNCHANGED under
BG-F4's witness-size-independence law (544 rings on 3.5M); verified
at derive and pinned in the UAGB1-BL freeze rows. [MEASURED section
lands with deliverable 2.]

## 3. Mode gating and the differential discipline [PLAN]

Every engine touch is gated on BgOpts.t_blind (default FALSE) and
marked [UAGB1-BL]: P0 and the noblind-P2 config are byte-identical
to BG's landed path (bg_battery and bg_canary are UNTOUCHED — lane
BJ's stage owns the canary harness — and must stay green as the
differential anchors). The shipped `pass-agg prove .. p2` flips
t_blind ON (one marked line): P2 carries the surcharge, per the
lane brief. The differential test asserts the P0 3/16 counted bytes
equal BG's pinned 383,798 B with zero blind material present.

## 4. AZB E-block dispositions [PLAN — table updated as legs land]

| leg | planned disposition |
|---|---|
| E-1 | rigged sparse weight support (hook), blinding OFF (= the pre-BL P2 path, kept as the battery config), claims-only multi-proof collection under an h0 salt hook; solver over Z_q: rank grows by exactly min(48, remaining)/proof (3 K terminals = 48 base equations), EXACT recovery at ceil(dim/48), not before. Permanent pre-fix regression. |
| E-2 | (i) blinding ON: rank stuck at the data dims (each proof adds 384 fresh pad unknowns), >= 2 planted wrong tensors explained EXACTLY (constructive coset certificate); (ii) derive-time counting canaries in the shipped blind path: per instance rank(mask map) = n_g with exactly ell+1 forced relations (AZ-L1a); joint rank = sum n_g (the composed instances draw SEQUENTIAL challenges — the block-diagonal case, easier than AZ-L1b's shared-challenge form, stated); pad/terminal map diagonal nonzero (AZ-L2a). |
| E-3 | F5 pair: tblind_unbound hook (blind columns outside the committed group, openings ride as bare pins) — post-challenge mask-set swap ACCEPTS; shipped path REJECTS the same swap at the u_0/descent binding (the engine face of the h0-digest edge — Section 2.1 deviation note). |
| E-4 | three F5 pairs at the composed path: (i) pad committed after the instance outer draw (crafted pad absorbs a terminal lie -> hook ACCEPTS / shipped REJECTS); (ii) nus drawn before terminal absorption (compensated terminal lie -> hook ACCEPTS / shipped REJECTS); (iii) rho drawn before the G pin (crafted G absorbs a round lie -> hook ACCEPTS / shipped REJECTS). |
| E-5 | (i) attack: two salted proofs forced (hook) to share the blind draw — the differencing solver recovers the planted weight support at the predicted count (shared pads = one 384-dim unknown block instead of fresh-per-proof); fresh-blind control stays stuck; (ii) shipped derive REFUSES the repeated (witness digest, T_blind digest) pair loudly. Freeze row both directions. |
| E-6, E-7(i), E-10, E-11 | landed by BD/BG (wave 2/3) — consumed unchanged, not re-claimed. |
| E-7(ii) | toy 1-level floor-accumulation harness (direct LevelPlan, r = 4): rank grows by exactly dim(z)/proof, exact recovery at r proofs, not before. |
| E-7(iii) | toy-scale distributional simulator match for the components THIS stage adds (masked rounds on the check variety, blinded terminal, G, g_open, v_s — all uniform); commitments documented as computational (MLWE class) — simulated, never statistically tested. |
| E-8 | derive-time conditional-rank certificate, block-triangular composition: [rounds x mask] = AZ-L1a ranks; [terminals x pad] = diagonal; [b_rows x segment] = 2,048-dim diagonal unit block (structural); zero blocks (segment touches no round/terminal exposure; masks touch no terminal) verified; total conditional rank = n_exposures. FAIL = deployment-blocking error (F-Z3). |
| E-9 | (i) slot-shared segment hook (one 16-coord residue tiled 8x per ring): the per-slot solver recovers planted slot-differences of the real b_rows content — leak exhibited against the witness; (ii) shipped ring-granular draw: the 8 slot images certified independently via lane_split (per-slot rank/uniformity). Real partially-split GF(q^16) arithmetic. |

## 5. Measured results

[lands with deliverables 2-3]

## 6. Battery

[lands with deliverable 3]

## 7. Freeze rows and reproduction

[lands with the implementation; UAGB1-BL-1a.. both directions:
blind inventories + n_g arithmetic, P2+blind schedule vs the BG
pins, the derived 1,024 B surcharge, the E-8 exposure/dimension
counts.]

---

*Changelog: 2026-08-10 — plan edition (deliverable 1): leak
inventory, design transcription (zero-extra-identity T_blind in the
weight group, masked instance FS rows, claim segment), derived
surcharge 1,024 B vs the ~1,664 B [MODEL] price with the structural
explanation, E-block plan table.*
