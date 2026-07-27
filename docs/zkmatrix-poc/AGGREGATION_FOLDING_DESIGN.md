# O-8: The Cross-Layer Folding Design — One Proof per 32-Layer Pass

Status: DESIGN IN PROGRESS (U-AG4 tranche, Agent FA lane, 2026-07-27;
paper + Python spike only — no engine changes). **Section 2 (F-IF1) is
COMMITTED as the binding interface for Agents FB/FC as of this file's
first commit; changes to it go through the orchestrator** (PROGRESS_
UAG4.md "Interface note"). The full design, tables and verdict follow
in Sections 3-8 and are marked SPIKE-PENDING until
`scripts/aggregation_folding_spike.py` lands; F-IF1's STRUCTURE
(what folds, the accumulator relation, arity, draw classes, FS
positions, the norm law) is final now, and only the numeric slots
marked [spike-final] inside it await the spike's printed values.

## 0. Plain-language summary (start here)

**The goal.** The project wants ONE small proof that a whole 32-layer
feedforward pass of the model ran correctly — not 32 medium proofs,
one per layer. After the U-AG3 round, one layer's proof is ~277-306
KB, so 32 of them are ~9-10 MB per pass. The budget conversation
(TARGET_CONTRACT Amendment A1) is per PASS, and the target class for
the full-ZK pass is 0.5-2 MiB. Getting from "32 medium proofs" to
"one small proof" is what "folding" means here, and this document is
that design.

**Why the obvious tricks are not enough.** U-AG3's Agent EA computed
a floor: even if you keep only ONE copy of the two biggest per-layer
objects (the "descent pair" — the lookup argument's transcript — and
the "evaluation proof" — the commitment-opening argument), the 32
layers' remaining sumcheck transcripts and claimed values still cost
32 x 38,976 B ~ 1.25 MB, landing the pass at ~1.50 MB = 5.7x the old
256 KiB line (AGGREGATION_ENCODING_DESIGN.md Section 4.3). So the
per-layer PROOF TRANSCRIPTS themselves — the sumcheck instances —
have to be folded into one, not just the openings deduplicated.

**The design in one paragraph.** All the proofs in the reduced
protocol are statements about tensors committed inside one global
commitment, addressed by index bits (a tensor slice = fixing some
address bits — lemma CR-L5). This design commits the WHOLE PASS —
all 32 layers' activations — into that one commitment, and adds 5
address bits for the layer number (2^5 = 32). Every per-layer check
("gate x up = z at every position", "this matmul is right", "these
values came from the SiLU table") then becomes ONE check over the
extended address space: instead of 32 separate sumchecks of size N,
one sumcheck of size 32N — which costs only 5 extra ROUNDS (~64 B of
wire each), because a sumcheck's transcript grows with the LOGARITHM
of the data. The 32-layer lookup descents merge the same way (all
layers share the same frozen SiLU table, so the table side does not
grow at all). The result: the pass costs one descent pair (a third
bigger than a layer's), one set of slightly-longer sumcheck
transcripts, and one evaluation proof per commitment group — a few
hundred KB total instead of 9-10 MB. We call this INDEX-EXTENSION
FOLDING (IXF) to distinguish it from the literature's fold-them-
one-at-a-time schemes.

**Why not LatticeFold's fold-one-at-a-time?** The LatticeFold papers
(the family-(b) literature) fold instances SEQUENTIALLY: keep a
running "accumulator" instance, mix each new instance into it with a
random challenge. That shape exists for streaming settings (prove
step k without knowing step k+1). Our pass is known in full before
proving starts, and the sequential shape has three real costs the
flat shape avoids: (i) each of the 31 mixing steps emits fold
messages (commitments/cross-terms) — at our widths ≥ 31 x 5,680 B ~
176 KB of pure overhead; (ii) mixing witnesses with challenges grows
their NORMS multiplicatively at every step — the reason LatticeFold
needs its decompose-then-fold machinery at all — and at q31 our norm
budget is measured in fractions of a bit; (iii) it imports a new
extraction theorem (32 nested rewindings) where the flat design
reuses the already-proven per-level story (SC-L4) unchanged. The
flat design's only norm cost is a ONE-TIME sqrt(32) from committing
32x more data under one fold, absorbed by re-deriving the digit base
(Section 5). The sequential alternative is priced and recorded, not
adopted.

**Labels used below** (each explained where it first matters):
"instance" = one sumcheck-provable claim (e.g. one layer's Hadamard
check); "descent pair" = the lookup argument's witness-side + table-
side GKR transcripts; "eval proof" = the Greyhound/LaBRADOR
commitment-opening argument; "floor" = the eval proof's final
cleartext witness (the ZK-critical object — Agent FB's subject);
"e0" = the digit base the committed values are chopped into (norm
control); "kappa" = the commitment's row count (11 after Agent EB's
correction); "K" = the degree-16 extension field GF(q^16) all
sumcheck challenges live in; "Tier N / Tier Z" = the non-ZK-labeled
/ full-ZK artifact tiers of TARGET_CONTRACT Amendment A1.

**Verdict preview** (Section 8 has the full row; numbers
[spike-final]): the folded Tier N pass lands in the ~0.37-0.40 MB
class (activation side; ~0.55-0.60 MB with the committed-weight
opening included) versus the 1.50 MB floor — instance folding beats
the floor by ~3-4x — and gives FB a base on which the one-floor ZK
surcharge (+176-240 KB) lands the Tier Z pass inside Amendment A1's
0.5-2 MiB target class.

## 1. Scope, sources, and standing constraints

O-8 asks (AGGREGATION_LITERATURE 8.1; PROGRESS_UAG4.md FA lane):
design the family-(b) accumulator that folds the reduced protocol's
per-layer sumcheck INSTANCES across the 32-layer pass — the
per-layer claim/artifact population of AGGREGATION_ENCODING_DESIGN
Section 3 — with the accumulator relation, arity/schedule, challenge
draws, the norm-growth law, fold-message bytes, the 32-layer wire
model, and the folded Tier N pass number vs EA's 5.7x floor.

Sources verified in-worktree this session (all at 6313518):
AGGREGATION_ENCODING_DESIGN.md (Sections 3, 4, 6 — the instance
population, the floor, the exports), AGGREGATION_CLAIM_REDUCTION.md
(CR-L1..L6, Section 10 — the reduced protocol), AGGREGATION_PARAMS_
DESIGN.md (Sections 2, 3, 5 — layout, norms, byte skeleton),
AGGREGATION_SOUNDNESS_COMPOSITION.md (SC-L4, R-EB1/R-EB3/R-EB4,
kappa 11 — the corrections SUPERSEDE DA's tables), AGGREGATION_ZK_
DESIGN.md (4.4 the floor object, 5.5 AZ-L4), ZK_GAP_OPTIONS.md 6-7 +
TARGET_CONTRACT.md Amendment A1 (the Option B decision),
PROOF_BYTE_LEDGER.md (unit costs, format), and the three spikes
`greyhound_params_spike.py` / `aggregation_byte_model_spike.py` /
`slack_composition_spike.py` (imported READ-ONLY by this lane's
spike; their recorded totals are reproduction anchors).

Standing constraints inherited unchanged: I-6 HARD (no
Gaussian-masked openings in the aggregate layer at q31); Z1
discipline (nothing formerly wave-masked reappears on the wire);
config = EXACT-DIGIT (triple-mandated); DENSE Y/UP/Z encoding (D-1);
per-pass scope with per-layer 262,144 B as the B1 engineering gate;
ring X^128+1, q31 = 2,147,483,249 = 2^31 - 399, q ≡ 113 (mod 256),
GF(q^16) slots; kappa 11, T_cap = 33 (R-EB1), K-draw aggregation
(R-EB3), floor bases e <= 7 (R-EB4). Numbers only from repo-recorded
sources or session-verified refs, cited inline; [MODEL] on
unmeasured constants. Grading legend per SOUNDNESS_REFERENCE
Section 0: [PROVEN] / [PROVEN*] / [MODEL] / [OBLIGATION].

Lane discipline: AGGREGATION_FOLD_PRIVACY_PRICING.md and
AGGREGATION_FOLDING_SOUNDNESS.md belong to Agents FB/FC; everything
exported to them is collected in Section 9. Corrections to other
lanes' docs are filed as export notes, never edited in place.

## 2. F-IF1 — THE BINDING FOLD INTERFACE (committed early)

Everything in this section is the interface FB and FC build against.
Numeric values marked [spike-final] are slots whose final printed
value comes from `aggregation_folding_spike.py`; their CLASS and the
formulas that produce them are binding now. Changes after first
commit go through the orchestrator (R-1..R-8 precedent).

### F-IF1.0 The fold, named

**Index-extension folding (IXF), flat arity 32.** The pass commits
all 32 layers' activation tensors as segments of ONE global data
commitment; the layer number becomes lambda = 5 extra MLE index
variables; every per-layer instance family is replaced by ONE
pass-instance of the same family over the extended index space; all
terminals land in the ONE terminal-batch sumcheck (CR-L4) at pass
scope; each commitment GROUP is opened by one batched evaluation
proof. There are NO per-step fold messages, NO running
accumulator-witness pair, NO cross-term commitments, and NO
witness-mixing challenges at the claim layer. Folding soundness =
sumcheck soundness over 5 more variables + CR-L4/CR-L5 verbatim +
the eval-proof chain (SC-L4) at the pass shape.

### F-IF1.1 What folds — the instance-family dispositions

Population = AGGREGATION_ENCODING_DESIGN Section 3.1 x
AGGREGATION_CLAIM_REDUCTION Section 10.1, at the complete-layer
scope. dw/dt = descent depths; FFN reference shape 512x4096x11008;
ledger-unit reference 2^20.

| family (per-layer form) | folds? | pass form (IXF) |
|---|---|---|
| SiLU lookup descent pair (dw 24 + dt 9 at FFN; 105,664 B/layer = 36-40% of every artifact — THE named owner) | **FOLDS** | ONE masked pair per pass at dw_pass = dw + 5 (witness multiset = union over layers; 32x data = +5 GKR input levels), dt UNCHANGED (all layers share the one frozen SiLU table; multiplicity column m is committed per pass). 32 pairs -> 1. |
| range-arm descent (witness side) | **FOLDS (conditional)** | rho-shares the folded SiLU witness descent — the D-R1 assumption extended verbatim to pass scope [MODEL, same risk, same battery item]. |
| range-arm table descent (28 rounds) | **FOLDS** | ONE per pass, rounds unchanged (shared table — table side is layer-count-free). |
| matmul sumchecks x3 (CR-L3; deg 2; 12/12/14 rounds) | **FOLDS** | 3 per pass (gate/up/down), each a JOINT (layer, inner) sumcheck: rounds li + 5; wire degree 3 in the 5 layer rounds, 2 in the b rounds (F-IF1.2). Weight side reads the stacked weight tensor W(l, i, j). |
| Hadamard zero-check (CR-L6/CR-3; deg 3; 23 rounds at FFN) | **FOLDS** | ONE per pass over (l, b): 28 rounds at FFN, 25 at 2^20-pass. |
| requant/rescale zero-checks (CR-7; deg <= 3; ~23 x 2) | **FOLDS** | 2 per pass, rounds + 5 each. |
| terminal batch sumcheck (CR-L4a/b) | **FOLDS** | ONE per pass; rounds = ceil(log2(pass committed coefficients)) = 30 at FFN-pass, 28 at 2^20-pass. |
| batch-entry claimed values (~135/layer at complete scope) | **count-invariant** | ~135 + 16 [MODEL pass-bookkeeping slack] per PASS, not per layer: pins are per-descent-pair (one pair), matmul/Hadamard terminals are per-instance (3 + 1), etc. |
| eval-proof openings | **FOLDS to one per GROUP** | one batched opening per commitment group (F-IF1.4): activation group always; weight group per deployment (below). |
| outer commitment identities | per-group | one u per group on the wire: 4 + kappa·516 = 5,680 B at kappa 11. |
| statement (v3) | per-pass | ONE statement; manifest gains 32 layer-segment rows + the privacy-class group map (~64 B/row [MODEL]) — the ONLY wire object that scales with layer count (~2 KB/pass). |

**Residual per-layer wire: ZERO bytes.** Nothing outside the
statement manifest scales with the layer count; all per-layer
structure lives in index bits and eq-kernel weights the verifier
computes itself.

### F-IF1.2 The accumulator relation

The folded object is the CR-L4b batched-claim state at pass scope —
no new relation is introduced:

    R_IXF = { (T_g, {(z_j, v_j)}_j) : MLE(T_g)(z_j) = v_j
              for every commitment group g }

populated in ONE shot by running the pass-instances of F-IF1.1 with
shared terminal rounds (CR-L4b) and batching per group with mu (many
points -> one point per tensor) and nu (many tensors -> one opening
per group). The per-layer claim families reach R_IXF through the
IXF lemmas (Section 3): a layer instance IS the pass instance with
5 index variables fixed to the layer's bits (CR-L5), so proving the
pass instance proves all 32 simultaneously. The "accumulator" never
exists half-full: arity 32, flat.

### F-IF1.3 Fold arity and schedule: flat-32, not tree, not sequential

Adopted: **flat arity 32** (one-shot index extension). Rejected with
reasons (Section 4 prices both):

- **sequential (Nova/LatticeFold shape, arity 2 x 31 steps):** 31
  fold messages at >= 5,680 B each (>= 176 KB pure overhead —
  comparable to the ENTIRE flat-fold overhead); per-step
  witness-mixing norm growth (T_cap-class per step) forcing
  LatticeFold's decompose-refold apparatus and a 32-deep extraction
  recursion that SC-L4 does not cover; 31 interleaved
  commit-challenge FS edges (AZ-L4 surface x 31).
- **tree (arity 2, depth 5):** same message count (31 internal
  nodes), same extraction novelty; only the challenge-independence
  bookkeeping improves. No byte case.
- **flat:** zero fold messages; norm cost = one sqrt(32) absorbed at
  e0 (F-IF1.5); extraction = the existing per-level story at bigger
  shape parameters (FC verifies exactly this); FS edges identical in
  STRUCTURE to the per-layer protocol.

The flat choice is available because the pass is known in full
before proving starts (per-pass scope, TARGET_CONTRACT Section 1's
32-blocks-one-statement workload); nothing here precludes a future
streaming variant, but it is out of scope and NOT priced.

### F-IF1.4 Commitment groups and the split hook (FB's interface)

Committed domains at pass scope:

- **T_act** — all 32 layers' X/Y/UP/Z + lookup aux (m, masks,
  blinders) + T_blind rides its own commitment as today (DA 2.1
  pattern). Dense value classes: X/Y/UP 8-bit, Z 15-bit, aux 31-bit
  (D-1).
- **T_W** — the stacked weight tensor W(l, ·, ·), 3 matrices x 32
  layers, dense int8 (8-bit class), committed ONCE per model (off
  the clock, TARGET_CONTRACT Section 3); its OPENING is per-pass
  (challenge-dependent).

The batching keeps per-group structure by construction (CR-L4b's nu
is drawn per group): the pass emits **one eval proof per group** —
activation-group proof always; weight-group proof in any deployment
where weight claims cannot be verifier-evaluated. Deployment table
(the hook FB's split-proof pricing consumes; ZK_GAP_OPTIONS Section
6 question (a) is answered structurally here — the terminal claims
split onto the two commitments BY CONSTRUCTION, nothing crosses):

| mode | activation-group proof | weight-group proof |
|---|---|---|
| P0 / P1 (weights public) | bare (Tier N; P1 carries the bounded-leak label — one floor per pass) | bare (W-C two-proof layout, RECOMMENDED) or merged single proof (W-B variant, priced; norm-thin) — verifier-side evaluation of public weight terminals (W-A) is priced and REJECTED at pass scale (Section 6.4: ~4.3e9 MACs > the 2 s R2 line) |
| P2 (weights private) | bare | MASKED (FB's Tier Z surcharge, once per pass) |
| P3 (both private) | MASKED | MASKED |

**Discovered latent assumption, flagged to the orchestrator:** the
recorded per-layer artifacts (DA 5.2, EA 3.3, EB 2.4) price NO
weight-domain opening — their witnesses are activation-only. The
weight terminals of the complete-layer matmul instances were
implicitly unpriced. IXF makes the choice explicit (this table);
the two-proof layout is priced in Section 6 and the EA-comparable
activation-only number is reported alongside throughout.

### F-IF1.5 The norm-growth law

**Per fold step: NONE** — IXF mixes no witnesses at the claim layer
(no challenge ever multiplies a witness outside the eval proof's own
levels, which are unchanged in kind). **Global, one-time:** the
level-0 fold norm at pass scope is

    gamma_z(pass) = OP_CONC · 2^(e0-1) · sqrt(N_limb(pass) · D),
    N_limb(pass)  = 32 · N_limb(layer)   per value class,

i.e. +2.5 bits over the layer artifact at fixed e0 (PARAMS 3.2's
formula, OP_CONC = 20.79), absorbed by re-deriving the digit base
per group [spike-final slots; the derivation chain is binding]:

- activation group, exact-digit gate (gamma_max = 2^22.12): the
  layer's e0 = 5 CANNOT survive x32 (+2.5 b vs 0.94 b headroom —
  the spike's negative check); re-derived e0 = 2 at pass scope,
  headroom ~0.87 b class [spike-final]; conservative per-level-gate
  variant (2^21.07, EB Section-4 convention): e0 = 1, headroom
  ~0.33 b [spike-final].
- weight group: e0 = 1 (sign-binary), headroom ~0.23 b class at the
  exact-digit gate [spike-final]. 8B-shape flag: at 4096x14336 the
  weight group saturates the gate (~0.05 b) — the relaxed-e0 line
  (EB 2.4(b)) is the recorded relief [MODEL].
- merged single-proof variant (W-B): e0 = 1, headroom ~0.10 b —
  priced, NOT recommended.

Levels >= 1 are UNCHANGED IN KIND: each level re-grounds its own
norms (SC-L4 C-ground) with the R-EB4 base caps (e_i <= 7) and
T_cap = 33; the pass adds ~1-3 LEVELS (witness 32x bigger, floor
unchanged — the LaBRADOR floor is witness-size-independent), never
a new norm factor. Knowledge error: +1-3 more per-level terms in
the SC-L4 sum — the exact-digit branch's post-FS ~2^-220 class has
>90 bits of margin for them [EB 3.3].

### F-IF1.6 Fold challenges — draws and FS positions (AZ-L4(a))

Every IXF challenge is a K = GF(q^16) draw (SZ class 2^-496-per-slot
engine) or an existing draw class; **no new Z_q-parallel draw and no
new witness-multiplying challenge class is introduced** (R-EB3-clean
by construction; the eval-proof levels keep quinary T_cap = 33 fold
challenges and the K-draw ct-aggregation per EB 3.2). The complete
list — these rows EXTEND the CRB-N1..N5 + AZ-L4 hash-edge tables;
Section 7 gives the attack column and F5 pairs:

| challenge | class | drawn (FS position) |
|---|---|---|
| r_l — the 5 layer-index coordinates inside every zero-check / matmul outer draw (part of r, rx, ry) | K^5 per instance (CRB-N1 class) | after h0_agg = hash of statement INCLUDING the 32-segment manifest + privacy-class group map, T_act, T_W digest, T_blind (all masks/pads) |
| the 5 extra index round challenges per folded instance | K per round (CRB-N2 class) | in-round, prefix through that round's polynomial |
| mu (terminal point batch, pass scope) | K^m (CRB-N4 class) | after ALL blinded terminal values of every pass-instance |
| nu_g (per-GROUP cross-tensor RLC) | K^{#tensors in g} (CRB-N5 class) | after the mu-batch terminals AND the group map (already in h0_agg) |
| eval-proof level challenges c^(i), per group | quinary C, T_cap = 33 (R-EB1) | per AZ-L4(a): after u_i + level-i norm material; floor sent last (AZB-6) |

### F-IF1.7 The fold-message byte skeleton

What the fold ADDS to one layer-class artifact to cover all 32
layers (the entire IXF overhead — there are no other fold bytes):

    fold_overhead = [descent] kel(dw+5, dt) - kel(dw, dt) K-el x 64 B
                    (~ +585 kel ~ +37.4 KB at FFN via the kel fit,
                     F-IF1.8)
                  + [instances] 5 rounds x wire-deg x 64 B per folded
                    instance (~ +6-7 KB over 8 instances)
                  + [batch] +5 rounds x 3 x 64 B
                  + [eval] +1-3 levels x (4 + kappa·516 + K-draw agg)
                    (~ +7-20 KB per group)
                  + [statement] 32 manifest rows (~ +2 KB)
                  + [identities] +5,680 B if the weight group opens
                    separately (W-C)

and the pass total is

    bytes(pass) = statement + sum_g u_g + kel(dw+5, dt) · 64
                + sum_inst (rounds_i + 5) · deg_wire_i · 64
                + 4 · 64 · n_inst + entries · 64
                + sum_g evalproof_g(schedule at pass classes,
                                    kappa 11, R-EB3 K-draw, R-EB4
                                    caps) + framing.

All constants are ledger widths (PROOF_BYTE_LEDGER Section 0), EA
instance arithmetic (R8-b/c), or EB-corrected eval-proof machinery;
[MODEL] items: the kel fit (F-IF1.8), boundary/framing constants,
entry midpoint + pass slack, manifest row width.

### F-IF1.8 The descent-size model (the one new [MODEL] constant)

The masked descent pair's K-element count at dt = 9 fits the four
recorded (dw, kel) points EXACTLY (PROOF_BYTE_LEDGER 0.1/1-2:
dw 17 -> 1,000; 19 -> 1,166; 21 -> 1,348; 24 -> 1,651):

    kel(dw, 9) = 2·dw^2 + 11·dw + 235      [MODEL — exact fit to 4
                                            recorded points;
                                            extrapolated +5]

giving dw 26 (2^20-pass) -> 1,873 kel = 119,872 B and dw 29
(FFN-pass) -> 2,236 kel = 143,104 B. The quadratic form matches the
GKR structure (level i runs ~i rounds; total ~ dw^2/2 x ~4 kel per
round); the extrapolation is 5 steps beyond the last recorded point
and is flagged as THE load-bearing model risk of the byte table
(Section 8 sensitivity: even +25% on the extrapolated increment
moves the pass total < 3%).

— end of F-IF1 —

## 3. The IXF lemmas (why index extension is sound) — SPIKE-PENDING

[Full statements + certificates land with the spike; the lemma
skeletons below are final.]

- **FD-L1 (stacked zero-check).** A per-position claim family
  "P_l(b) = 0 for all b, for all layers l" is the single family
  "P(l, b) = 0 for all (l, b)" over the stacked tensors; CR-L6
  applies verbatim at n + 5 variables with SZ error (n + 5)/|K|.
  Layer selectivity is CR-L5 (a layer = 5 high index bits fixed).
- **FD-L2 (joint matmul fold).** For all l: C_l = A_l·B_l iff for
  random (r_l, rx, ry) drawn after commitment:
  sum_{l,b} eq(r_l, l) · A~(l, rx, b) · B~(l, b, ry)
  = C~(r_l, rx, ry), a degree-(3,2) sumcheck over 5 + li variables.
  The eq factor MUST ride inside the sumcheck: the naive product of
  stacked MLEs A~(r_l,...)·B~(r_l,...) has cross terms and is
  neither complete nor sound (spike negative N3 exhibits both
  directions).
- **FD-L3 (descent stacking).** The LogUp-GKR relation is a multiset
  statement; the pass witness multiset is the union over layers, the
  table is SHARED, multiplicities add: one descent pair at dw + 5,
  dt unchanged. The masked-descent machinery (Q4.7-9) is depth-
  parametric and carries over [its mask-column sizing at dw + 5 is
  aux-class material, priced].
- **FD-L4 (pass batching).** CR-L4a/b verbatim at pass scope; mu/nu
  soundness bounds unchanged (1/|K| class); the knowledge-error
  composition through the eval proof is SC-L6 at the pass shape —
  FC's verification target, not new mathematics.

## 4. The rejected alternative: sequential/tree RLC folding, priced —
SPIKE-PENDING

[Byte and norm arithmetic land with the spike; the structural
comparison is in F-IF1.3. The spike's chained-fold experiment
measures the RLC norm-growth law over >= 8 chained folds against the
additive T_cap model, and demonstrates the decompose-refold reset.]

## 5. Norm growth and the SC-L4 hypotheses at pass shape —
SPIKE-PENDING

[The e0 re-derivation tables per group and gate, the gamma_z
numbers, headrooms, MSIS rows at kappa 11, and the level-count
deltas. The law and its slots are in F-IF1.5.]

## 6. The 32-layer wire model and byte tables — SPIKE-PENDING

[PROOF_BYTE_LEDGER-format tables at both reference shapes, both
gates, activation-only (EA-comparable) and two-proof (recommended)
layouts, with every unmeasured constant [MODEL]-flagged. Includes
6.4: the W-A verifier-evaluation rejection arithmetic.]

## 7. AZ-L4(a) hash-edge rows for the fold challenges —
SPIKE-PENDING

[The F-IF1.6 table extended with attack-if-violated and F5-pair
columns; includes the two NEW edges IXF introduces: the segment-map
edge and the privacy-class group-map edge.]

## 8. Verdict row — SPIKE-PENDING

[Folded Tier N pass numbers vs the 1,500,496 B floor and the
262,144 B/layer B1 gate; beats-the-floor y/n; conditions.]

## 9. Exports to FB and FC — SPIKE-PENDING

[FB: what the fold does to masked instances and the floor image (raw
facts; FB owns the lemma). FC: the exact hypotheses the extraction
needs at pass shape.]

---

*Changelog: 2026-07-27 — F-IF1 committed early (first edition:
Sections 0-2 final, 3-9 skeletons marked SPIKE-PENDING), per the
PROGRESS_UAG4.md interface note.*
