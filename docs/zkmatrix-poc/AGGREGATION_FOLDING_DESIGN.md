# O-8: The Cross-Layer Folding Design — One Proof per 32-Layer Pass

Status: DESIGN COMPLETE (U-AG4 tranche, Agent FA lane, 2026-07-27;
paper + Python spike only — no engine changes). **Section 2 (F-IF1)
was COMMITTED EARLY as the binding interface for Agents FB/FC (first
commit of this file); its structure is unchanged since — this
edition only fills the numeric slots F-IF1 explicitly reserved as
[spike-final] and completes Sections 3-9.** Changes to F-IF1 go
through the orchestrator (PROGRESS_UAG4.md "Interface note").

Spike: `scripts/aggregation_folding_spike.py` (stdlib, ~1 s, 34 MiB
RSS, **33/33 self-checks**; imports Agent DA's
`greyhound_params_spike.py`, Agent EA's
`aggregation_byte_model_spike.py` and Agent EB's
`slack_composition_spike.py` READ-ONLY and reproduces their recorded
verdict numbers — including EA's 1,500,496 B floor and EB's
corrected kappa-11 layer totals — before printing anything. Every
number quoted below is printed by it unless cited elsewhere.)

Verdict in one line (full row in Section 8): **index-extension
folding closes O-8 — the folded Tier N pass is 352,948 B = 0.337 MiB
(activation side, the EA-comparable unit: 4.25x UNDER the 1,500,496 B
floor) and 505,272 B = 0.482 MiB in the recommended two-proof W-C
layout with the committed-weight opening included; per-layer
amortized 11,029-15,789 B = 0.04-0.06x of the 262,144 B B1 gate; the
fold adds ZERO per-layer wire and ~2 KB/layer of log-factor
overhead; and it hands FB a base on which the one-floor P2 surcharge
lands the Tier Z pass at ~0.65-0.71 MiB [preview] — inside Amendment
A1's 0.5-2 MiB target class.**

## 0. Plain-language summary (start here)

**The goal.** The project wants ONE small proof that a whole
32-layer feedforward pass of the model ran correctly — not 32 medium
proofs, one per layer. After the U-AG3 round, one layer's proof is
~277-306 KB, so 32 of them are ~9-10 MB per pass. The budget
conversation (TARGET_CONTRACT Amendment A1) is per PASS, and the
target class for the full-ZK pass is 0.5-2 MiB. Getting from "32
medium proofs" to "one small proof" is what "folding" means here,
and this document is that design.

**Why the obvious tricks are not enough.** U-AG3's Agent EA computed
a floor: even if you keep only ONE copy of the two biggest per-layer
objects (the "descent pair" — the lookup argument's transcript — and
the "evaluation proof" — the commitment-opening argument), the 32
layers' remaining sumcheck transcripts and claimed values still cost
32 x 38,976 B ~ 1.25 MB, landing the pass at 1,500,496 B = 5.7x the
old 256 KiB line (AGGREGATION_ENCODING_DESIGN.md Section 4.3). So
the per-layer PROOF TRANSCRIPTS themselves — the sumcheck instances
— have to be folded into one, not just the openings deduplicated.

**The design in one paragraph.** All the proofs in the reduced
protocol are statements about tensors committed inside one global
commitment, addressed by index bits (a tensor slice = fixing some
address bits — lemma CR-L5). This design commits the WHOLE PASS —
all 32 layers' activations — into that one commitment, and adds 5
address bits for the layer number (2^5 = 32). Every per-layer check
("gate x up = z at every position", "this matmul is right", "these
values came from the SiLU table") then becomes ONE check over the
extended address space: instead of 32 separate sumchecks of size N,
one sumcheck of size 32N — which costs only 5 extra ROUNDS (~64-192
B of wire each), because a sumcheck's transcript grows with the
LOGARITHM of the data. The 32 layers' lookup descents merge the same
way (all layers share the same frozen SiLU table, so the table side
does not grow at all). The result: the pass costs one descent pair
(a third bigger than a layer's), one set of slightly-longer sumcheck
transcripts, and one evaluation proof per commitment group — ~0.34-
0.48 MB total instead of 9-10 MB. We call this INDEX-EXTENSION
FOLDING (IXF) to distinguish it from the literature's
fold-them-one-at-a-time schemes.

**Why not LatticeFold's fold-one-at-a-time?** The LatticeFold papers
(the family-(b) literature) fold instances SEQUENTIALLY: keep a
running "accumulator" instance, mix each new instance into it with a
random challenge. That shape exists for streaming settings (prove
step k without knowing step k+1). Our pass is known in full before
proving starts, and the sequential shape has three real costs the
flat shape avoids: (i) each of the 31 mixing steps emits fold
messages (commitments/cross-terms) — at our widths >= 31 x 5,680 B
~ 176 KB of pure overhead; (ii) mixing witnesses with challenges
grows their certified NORM bound LINEARLY in the number of folds
(+10.0 bits at 32 folds, spike-measured law) where the flat design
pays sqrt(32) = +2.5 bits ONCE — and at q31 the norm budget is
measured in fractions of a bit, so the sequential shape is forced
into LatticeFold's decompose-then-refold machinery at every step
(that is WHY LatticeFold exists), whose materialized limbs ARE the
fold messages; (iii) it imports a new extraction theorem (32 nested
rewindings) where the flat design reuses the already-proven
per-level story (SC-L4) unchanged. The sequential alternative is
priced and recorded (Section 4), not adopted.

**The one real casualty, stated plainly.** Committing 32x more data
under one fold costs sqrt(32) in the fold norm, so the digit base
the values are chopped into must shrink (e0 5 -> 2 on the
activation side, 1 on the weight side — Section 5). That is absorbed
— the spike shows the re-derived bases fit with real headroom and,
pleasantly, at ZERO byte cost (the robust e0 = 2 point prices
identically to the razor-thin byte-optimal one). The weight side is
the tight one: it fits ONLY on the exact-digit branch (which the
tranche already mandates), and at the true 8B shape its headroom is
0.05 bits — the single sharpest number in this design (Section 5.4).

**Labels used below** (each explained where it first matters):
"instance" = one sumcheck-provable claim (e.g. one layer's Hadamard
check); "descent pair" = the lookup argument's witness-side +
table-side GKR transcripts; "eval proof" = the Greyhound/LaBRADOR
commitment-opening argument; "floor" = the eval proof's final
cleartext witness (the ZK-critical object — Agent FB's subject);
"e0" = the digit base committed values are chopped into (norm
control); "kappa" = the commitment's row count (11 after Agent EB's
correction); "K" = the degree-16 extension field GF(q^16) all
sumcheck challenges live in; "Tier N / Tier Z" = the non-ZK-labeled
/ full-ZK artifact tiers of TARGET_CONTRACT Amendment A1; "W-C /
W-B / W-A" = the three weight-domain layouts of F-IF1.4.

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
spike; their recorded totals are reproduction anchors — spike checks
1-6). The LatticeFold construction facts cited in Sections 0/4 are
the repo-recorded abstract-verified rows (AGGREGATION_LITERATURE
2.1, refs 6/7); the deep extraction-theorem transcription is Agent
FC's lane, not this one's.

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
lanes' docs are filed as export notes (9.3), never edited in place.

## 2. F-IF1 — THE BINDING FOLD INTERFACE (committed early)

Everything in this section is the interface FB and FC build against.
The [spike-final] slots reserved at first commit are now FILLED with
the spike's printed values (marked "slot filled"); the structure is
unchanged from the committed edition. Changes go through the
orchestrator (R-1..R-8 precedent).

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
| SiLU lookup descent pair (dw 24 + dt 9 at FFN; 105,664 B/layer = 36-40% of every artifact — THE named owner) | **FOLDS** | ONE masked pair per pass at dw_pass = dw + 5 (witness multiset = union over layers; 32x data = +5 GKR input levels), dt UNCHANGED (all layers share the one frozen SiLU table; multiplicity column m is committed per pass). 32 pairs -> 1: 3,381,248 B -> 143,104 B. |
| range-arm descent (witness side) | **FOLDS (conditional)** | rho-shares the folded SiLU witness descent — the D-R1 assumption extended verbatim to pass scope [MODEL, same risk, same battery item; break case priced in Section 6.3]. |
| range-arm table descent (28 rounds) | **FOLDS** | ONE per pass, rounds unchanged (shared table — table side is layer-count-free). |
| matmul sumchecks x3 (CR-L3; deg 2; 12/12/14 rounds) | **FOLDS** | 3 per pass (gate/up/down), each a JOINT (layer, inner) sumcheck: rounds li + 5; wire degree 3 in the 5 layer rounds, 2 in the b rounds (FD-L2). Weight side reads the stacked weight tensor W(l, i, j). |
| Hadamard zero-check (CR-L6/CR-3; deg 3; 23 rounds at FFN) | **FOLDS** | ONE per pass over (l, b): 28 rounds at FFN-pass, 25 at 2^20-pass (FD-L1). |
| requant/rescale zero-checks (CR-7; deg <= 3; ~23 x 2) | **FOLDS** | 2 per pass, rounds + 5 each. |
| terminal batch sumcheck (CR-L4a/b) | **FOLDS** | ONE per pass; rounds = ceil(log2(pass committed coefficients)) = 30 at FFN-pass, 28 at 2^20-pass. |
| batch-entry claimed values (~135/layer at complete scope) | **count-invariant** | 151 = 135 + 16 [MODEL pass-bookkeeping slack] per PASS, not per layer: pins are per-descent-pair (one pair), matmul/Hadamard terminals are per-instance (3 + 1), etc. |
| eval-proof openings | **FOLDS to one per GROUP** | one batched opening per commitment group (F-IF1.4): activation group always; weight group per deployment. |
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
per group). The per-layer claim families reach R_IXF through the IXF
lemmas (Section 3): a layer instance IS the pass instance with 5
index variables fixed to the layer's bits (CR-L5), so proving the
pass instance proves all 32 simultaneously. The "accumulator" never
exists half-full: arity 32, flat.

### F-IF1.3 Fold arity and schedule: flat-32, not tree, not sequential

Adopted: **flat arity 32** (one-shot index extension). Rejected with
reasons (Section 4 prices both):

- **sequential (Nova/LatticeFold shape, arity 2 x 31 steps):** 31
  fold messages at >= 5,680 B each (>= 176 KB pure overhead —
  comparable to the ENTIRE flat-fold overhead); the certified norm
  bound grows LINEARLY in fold count (+10.0 bits at 32 folds vs
  flat's +2.5 — spike checks 19-20) forcing LatticeFold's
  decompose-refold apparatus and a 32-deep extraction recursion that
  SC-L4 does not cover; 31 interleaved commit-challenge FS edges
  (AZ-L4 surface x 31).
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
  blinders); T_blind rides its own commitment as today (DA 2.1/2.5
  pattern; 2^12 rings, 31-bit class [MODEL]). Dense value classes:
  X/Y/UP 8-bit, Z 15-bit, aux 31-bit (D-1).
- **T_W** — the stacked weight tensor W(l, ·, ·), 3 matrices x 32
  layers = 33,816,576 rings dense int8 (8-bit class), committed ONCE
  per model (off the clock, TARGET_CONTRACT Section 3); its OPENING
  is per-pass (challenge-dependent).

The batching keeps per-group structure by construction (CR-L4b's nu
is drawn per group): the pass emits **one eval proof per group** —
activation-group proof always; weight-group proof in any deployment
where weight claims cannot be verifier-evaluated. Deployment table
(the hook FB's split-proof pricing consumes; ZK_GAP_OPTIONS Section
6 question (a) is answered structurally here — the terminal claims
split onto the two commitments BY CONSTRUCTION, nothing crosses):

| mode | activation-group proof | weight-group proof |
|---|---|---|
| P0 / P1 (weights public) | bare (Tier N; P1 carries the bounded-leak label — one floor per pass) | bare (W-C two-proof layout, RECOMMENDED) or merged single proof (W-B variant — priced; norm-thin at 7B, INFEASIBLE at 8B, spike F-N4) — verifier-side evaluation of public weight terminals (W-A) is priced and REJECTED at pass scale (Section 6.4: ~4.33e9 elements -> ~6.1 s single-threaded [MODEL] > the 2 s R2 line) |
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
per group [slots filled from the spike; the derivation chain was
binding from first commit]:

- activation group, exact-digit gate (gamma_max = 2^22.12): the
  layer's e0 = 5 CANNOT survive x32 (gamma 2^23.68 — spike negative
  N5); byte-optimal re-derived e0 = 3 at 2^22.00 (0.12 b headroom);
  **ADOPTED e0 = 2 at 2^21.26, headroom 0.86 b, at ZERO byte
  premium** (spike F-N3: the eval-proof schedule prices identically
  — the robustness is free). Conservative per-level-gate variant
  (2^21.07, EB Section-4 convention): e0 = 1, headroom 0.33 b.
- weight group: e0 = 1 (sign-binary), gamma 2^21.88, headroom 0.24 b
  at the exact-digit gate; **INFEASIBLE at the per-level gate**
  (spike F-N2) — the exact-digit branch (already triple-mandated) is
  load-bearing for the weight opening. 8B-shape flag (spike F-N4):
  at 4096x14336 the weight group's headroom is **0.05 b** — the
  relaxed-e0 line (EB 2.4(b)) is the recorded relief [MODEL].
- merged single-proof variant (W-B): e0 = 1, headroom 0.10 b at 7B;
  EXCEEDS the gate at the 8B shape (F-N4) — priced, NOT recommended.

Levels >= 1 are UNCHANGED IN KIND: each level re-grounds its own
norms (SC-L4 C-ground) with the R-EB4 base caps (e_i <= 7) and
T_cap = 33; the pass adds LEVELS (stop L7-L8 vs the layer's L5-L6
class; the LaBRADOR floor is witness-size-independent: 710-734 rings
after R-EB4), never a new norm factor. Knowledge error: +2-3
per-level terms in the SC-L4 sum — the exact-digit branch's post-FS
~2^-220 class has >90 bits of margin for them [EB 3.3].

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
layers (the entire IXF overhead — there are no other fold bytes;
all values spike-printed):

    fold_overhead = [descent] kel(dw+5,9) - kel(dw,9) = +585 kel
                    = +37,440 B at FFN (F-IF1.8)
                  + [instances] 5 rounds x wire-deg x 64 B per folded
                    instance + batch +5 rounds (= +6,720 B over the
                    8 FFN instances: 37,056 vs 30,336)
                  + [eval] +2-3 levels x 6,716 B (= 5,680 commit at
                    kappa 11 + 1,036 K-draw agg) per group
                  + [statement] 32 manifest rows (+2,048 B [MODEL])
                  + [identities] +5,680 B if the weight group opens
                    separately (W-C)

and the pass total is

    bytes(pass) = statement + sum_g u_g + kel(dw+5, 9) · 64
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
(Section 6.3 sensitivity: +25% on the extrapolated increment moves
the W-C pass total by 9,360 B = +1.9%).

— end of F-IF1 —

## 3. The IXF lemmas (why index extension is sound)

Notation: layers l in {0,1}^5, per-layer position index b; stacked
tensors T(l, b) committed as segments of the group commitment
(IA-O1-1 alignment: layer = the 5 HIGH index bits, positions low —
exactly CR-L5's slice form).

**Lemma FD-L1 (stacked zero-check).** Let {P_l}_l be a per-position
claim family with per-layer form "P_l(b) = 0 for all b" (Hadamard,
requant), where P_l is a degree-d composition of MLEs of layer-l
tensor slices. Define P(l, b) by the same composition over the
stacked tensors. Then (a) P(l, b) = 0 for all (l, b) iff every
per-layer claim holds; (b) the CR-L6 kernel applies verbatim over
n + 5 variables: for r drawn from K^{n+5} after the pass
commitments, sum_{(l,b)} eq(r, (l,b)) · P(l, b) = 0 accepts a false
family with probability <= (n + 5)/|K| + the sumcheck's round terms.
*Proof.* (a) is the definition of stacking (each (l, b) is one
per-layer position). (b) is CR-L6 with n replaced by n + 5 — the
lemma is variable-count-generic; layer selectivity is CR-L5 (fixing
the 5 high bits of the challenge domain recovers any single layer's
claim). ∎ Status: **[PROVEN* — CR-L6/CR-L5 are DB's certified
lemmas; the toy end-to-end fold with tamper is spike checks 8-9]**.

**Lemma FD-L2 (joint matmul fold).** For stacked A(l, i, k),
B(l, k, j), C(l, i, j): C_l = A_l·B_l for ALL l iff for
(r_l, rx, ry) drawn from K^5 x K^lr x K^lm after the commitments,

    sum_{l, b} eq(r_l, l) · A~(l, rx, b) · B~(l, b, ry)
      = C~(r_l, rx, ry),

except with probability <= (5 + lr + lm)/|K| over the outer draw
plus the round terms of the degree-(3, 2) sumcheck over 5 + li
variables (degree 3 in the l-rounds — eq, A, B are each multilinear
in l — and 2 in the b-rounds). The eq factor MUST ride inside the
sumcheck: the "naive" fold that evaluates the stacked MLEs at r_l
FIRST and sumchecks sum_b A~(r_l, rx, b)·B~(r_l, b, ry) computes
sum_{l, l'} eq_l·eq_{l'}·(A_l·B_{l'})~ — the cross terms make it
INCOMPLETE on honest data, and with early-drawn challenges it is
also UNSOUND (a forged C' != A·B accepts).
*Proof.* Completeness/soundness of the joint form: MLE(C)(r_l,·) =
sum_l eq(r_l, l)·MLE(C_l)(·) (MLE linearity in the fixed-index
slices) and per-l Schwartz-Zippel as in CR-L3, union over the joint
outer draw. The cross-term identity is the displayed expansion.
∎ Status: **[PROVEN* — CR-L3 + MLE linearity; spike checks 10-11
(honest verify / tamper reject), 14-16 (both naive-fold failure
directions exhibited numerically)]**.

**Lemma FD-L3 (descent stacking).** The LogUp-GKR lookup relation is
a multiset statement: witness multiset W_l vs table T with
multiplicities m_l. The pass instance is the union multiset
W = ∪_l W_l vs the SAME table T with m = sum_l m_l. One descent
pair at dw_pass = dw + 5 (witness side: 32x elements = 5 more GKR
input levels) and dt UNCHANGED (the table side depends only on T,
which is frozen and shared — table_spec_digest in every statement)
proves all 32 layers' lookups. The multiplicity column m is
committed per pass (aux segment); the masked-descent machinery
(Q4.7-9) is depth-parametric and carries over; its mask columns at
dw + 5 are aux-class material [MODEL, inside the aux class row].
*Proof.* LogUp soundness is multiset equality of the fingerprint
sums; sums over a disjoint union split layer-wise, so the union
instance holds iff every layer's does (multiplicities add because
the fingerprint is linear in the multiplicity column). Depth: the
witness-side GKR tree over 32x leaves is 5 levels deeper; the
table-side tree is over T, unchanged. ∎ Status: **[PROVEN* at the
multiset-algebra level — CR-10/M4_LOOKUP_DESIGN 3.4 carry the
engine; the dw + 5 byte law is F-IF1.8 [MODEL]]**. The range arm
rides identically (shared range table, 28-round table descent
unchanged) UNDER the D-R1 rho-sharing assumption extended to pass
scope — same [MODEL] risk, now once per pass instead of once per
layer; the break case is priced in Section 6.3.

**Lemma FD-L4 (pass batching).** CR-L4a/b apply verbatim at pass
scope: all pass-instance terminals land at one shared point per
group (shared terminal rounds; shorter tensors padded by fixing
high variables — the same IA-O1-1 alignment), mu batches points
(<= 1/|K| + sumcheck term), nu_g batches tensors within group g
(<= 1/|K|). The knowledge-error composition through the eval proof
is SC-L6 at the pass shape — FC's verification target, no new
mathematics. ∎ Status: **[PROVEN* algebra per DB; composition
[OBLIGATION -> FC], unchanged in kind]**.

## 4. The rejected alternative: sequential/tree RLC folding, priced

For the record (and as FC's negative control), the LatticeFold-shape
accumulator over the same instance population:

- **Messages.** Each of the 31 fold steps commits at least one
  cross-term / refreshed-accumulator object: >= 31 x 5,680 B =
  176,080 B at kappa 11 — before any per-step norm-control
  material. The ENTIRE flat-fold overhead (F-IF1.7) is ~60-66 KB;
  the sequential shape pays ~2.7-2.9x that in messages alone.
- **The norm law (the crux).** Spike-measured over 12 chained
  quinary negacyclic folds (checks 19-21): honest values
  concentrate like a random walk, but the CERTIFIED bound the
  verifier/extractor must charge is additive-linear:
  B_k = k · T_cap · mag — after 32 folds +10.0 bits vs the flat
  fold's one-time +2.5 bits. q31 cannot host +10 bits anywhere
  (the whole exact-digit budget above the layer point is ~0.9 b):
  the sequential shape is therefore FORCED into per-step
  decompose-refold (the spike demonstrates the reset and the limb
  materialization it charges) — that apparatus and its per-step
  messages are what LatticeFold's construction exists to manage,
  and at our widths they are pure overhead the flat design never
  pays.
- **Extraction.** 32 nested rewindings with per-step relaxation —
  exactly the compounded-reading shape SC-L4 Section 2.2 warns
  about; a LatticeFold-class extraction theorem at our ring would
  need FC's full transcription (FC's lane prices whether it even
  composes). The flat design needs only SC-L4 at bigger shapes.
- **When it WOULD win.** Streaming/IVC (prove layer k before layer
  k+1 exists) or heterogeneous instance shapes. Neither applies to
  the per-pass product (TARGET_CONTRACT Section 1). Recorded as the
  return path if a streaming requirement ever lands.

## 5. Norm growth and the SC-L4 hypotheses at pass shape

### 5.1 The activation group

Value classes at FFN-pass (EA's dense per-layer classes x 32 +
T_blind): 4,227,072 rings @ 8-bit, 1,409,024 @ 15-bit, 6,400 @
31-bit aux, 4,096 @ 31-bit blind = 5,646,592 rings. Spike-printed:

| e0 | limb-rings | gamma_z | vs gamma_max 2^22.12 | verdict |
|---:|---:|---|---:|---|
| 5 (the layer's base) | — | 2^23.68 | −1.56 b | **FAILS (spike N5)** — the re-derivation is mandatory |
| 3 (byte-optimal) | 19,841,792 | 2^22.00 | +0.12 b | fits, razor |
| **2 (ADOPTED)** | 28,348,416 | 2^21.26 | **+0.86 b** | fits with real headroom, ZERO byte premium (F-N3) |
| 1 (conservative per-level gate 2^21.07) | 55,277,312 | 2^20.74 | +0.33 b vs 2^21.07 | the EB-Section-4-convention variant |

### 5.2 The weight group (W-C)

33,816,576 rings @ 8-bit (3 matrices x 32 layers, dense int8):
e0 = 1 -> 270,532,608 limb-rings, gamma_z = 2^21.88, headroom
0.24 b at the exact-digit gate. Two findings:

- **F-N2 (spike check 28):** the weight group DOES NOT FIT under
  the per-level gamma gate (2^21.88 > 2^21.07) at any e0 — the
  exact-digit branch is load-bearing for the committed-weight
  opening, not merely byte-preferred. (The tranche already mandates
  exact-digit; this makes the mandate structural.)
- **F-N4 (spike check 31) [MODEL]:** at the 8B shape (4096x14336)
  the weight group's headroom shrinks to **0.05 b** — the sharpest
  number in this design. The recorded relief is EB 2.4(b)'s
  relaxed-e0 line (the q/8-derived gamma gate is over-strict; the
  honest constraints C-win/C-msis have ~6 b window margin), which
  the build round must adopt EXPLICITLY if the 8B rung is built at
  q31. Exported to FC (verify the relaxed line supports the
  extraction at these shapes) and to the orchestrator.

### 5.3 The merged variant (W-B) and why it is not recommended

Merged witness 39,463,168 rings -> e0 = 1, gamma 2^22.02, headroom
0.10 b at 7B; at the 8B shape the merged witness EXCEEDS the gate
(F-N4) — W-B does not scale to the target. It is 149,252 B cheaper
than W-C at 7B (one proof instead of two) and is recorded as a
7B-only byte saver with no P2 split and no 8B future.

### 5.4 SC-L4 at pass shape (what FC must verify)

The composed chain at pass shape satisfies SC-L4's hypotheses with
the SAME per-level structure as the layer chain — nothing new in
kind, three things bigger: (i) level count: stop at L7 (2^20-pass) /
L8 (FFN-pass, both groups) vs the layer's L5-L6 class; knowledge
error gains 2-3 per-level terms (margin >90 bits on the exact-digit
branch [EB 3.3]); (ii) level-0 shape m1 x m2 at the pass witness
(C-win/C-msis re-checked per level by the schedule; R-EB4 caps
active at the floor: e_final = 7, floors 710-734 rings); (iii) the
weight-group chain is a SECOND instance of the same composition
(independent proof, own FS lane after the shared h0_agg). FC's
verification target list is Section 9.2.

## 6. The 32-layer wire model and byte tables

All tables: exact-digit branch, kappa 11, R-EB3 K-draw aggregation
line (1,036 B/level), R-EB4 caps, canonical ledger widths; entries
and framing [MODEL] as flagged. Format per PROOF_BYTE_LEDGER.

### 6.1 The folded pass artifacts (spike-printed, DOC-lockstep
asserted)

**2^20 ledger-unit PASS** (32 rig layers; activation group only —
the rig statement has no matmul):

| component | bytes |
|---|---:|
| statement (v3 + 32-row pass manifest) [MODEL] | 6,144 |
| outer identities u (T_act + T_blind, kappa 11) | 11,360 |
| masked descent pair (dw 26 + dt 9) [MODEL kel fit] | 119,872 |
| folded instance transcript (2 inst, +5 rounds each) | 10,688 |
| batch-entry claimed values (68) [MODEL] | 4,352 |
| eval proof [act]: L7 msgs + 732-ring floor (e_f 7) | 139,672 |
| framing [MODEL] | 2,048 |
| **TOTAL (pass)** | **294,136 = 0.281 MiB** |

9,191 B/layer amortized = 0.035x the B1 gate. (The unfolded
32-layer 2^20 pass at EA's dense exact-digit layer is 32 x 256,208
= 8,198,656 B — the fold is 27.9x smaller.)

**FFN 512x4096x11008 complete PASS** — three layouts:

| component | act-only (EA-comparable) | W-C (RECOMMENDED) | W-B (merged) |
|---|---:|---:|---:|
| statement (v3 + 32-row manifest) [MODEL] | 6,144 | 6,144 | 6,144 |
| outer identities u (kappa 11) | 11,360 | 17,040 | 11,360 |
| masked descent pair (dw 29 + dt 9) [MODEL] | 143,104 | 143,104 | 143,104 |
| folded instance transcript (8 inst) | 37,056 | 37,056 | 37,056 |
| batch entries (151) [MODEL] | 9,664 | 9,664 | 9,664 |
| eval proof [activations] (L8, 710-ring floor) | 143,572 | 143,572 | — |
| eval proof [weights] (L8, 734-ring floor) | — | 146,644 | 146,644 (merged) |
| framing [MODEL] | 2,048 | 2,048 | 2,048 |
| **TOTAL (pass)** | **352,948** | **505,272** | **356,020** |
| MiB | 0.337 | 0.482 | 0.340 |
| B/layer amortized | 11,029 | 15,789 | 11,125 |

### 6.2 Reading the table

- The descent pair remains the named owner at pass scope: 143,104 B
  = 28-41% of the artifact — any GKR-side dw compression still moves
  the verdict one-for-one (EA 5.1's ownership carries over).
- The fold overhead vs one layer-class artifact is ~60-66 KB TOTAL
  for covering 31 extra layers (~1.9-2.1 KB/layer): descent
  +37,440 B, instance rounds +6,720 B, eval levels +2-3 x 6,716
  B/group, statement +2,048 B.
- The two eval proofs are now the biggest line class (57% at W-C).
  Their floors are R-EB4-corrected: 710/734 rings = 90,880/93,952
  cleartext bytes — the object FB's masking prices.

### 6.3 Sensitivities [MODEL] (W-C base 505,272 B)

| variation | pass total |
|---|---:|
| entries 116 / 186 (band) | 503,032 / 507,512 |
| requant checks 1 (not 2) | 499,640 |
| kel fit +25% on the extrapolated increment | 514,632 (+1.9%) |
| robust act e0 = 2 (ADOPTED) | 505,272 (identical — F-N3) |
| D-R1 breaks (range arm cannot share): +1 full pass descent pair | 648,376 (0.618 MiB — still 2.3x under the floor) |
| conservative per-level gate (act-only; weight group infeasible, F-N2) | 354,228 |

The verdict is band-stable: no sensitivity crosses the floor or
leaves the Tier Z target class.

### 6.4 The W-A rejection arithmetic (why weights are committed)

With public weights and NO weight commitment, the verifier must
evaluate the 3 stacked weight MLEs itself: 32 x 3 x 4096 x 11008 =
4.33e9 elements ~ 6.1 s single-threaded at the 0.18 us/ring-MAC
kernel class [MODEL] — over the 2 s R2 line (statement validation
included) with no headroom story. Committed weights + the W-C
opening keep the verifier in the sqrt regime: scaling EA's measured-
class dense layer verify (0.060 s) by sqrt(witness ratio) gives
~0.34 s (activation proof) + ~0.83 s (weight proof) + polylog
transcripts ~ **1.2 s-class for the W-C pass [MODEL]** — inside the
2 s line with modest headroom; the honest re-derivation is an
O-5-class build-round item (Section 9.4).

### 6.5 Prover note

IXF adds no prover-side fold work beyond the bigger (single)
sumchecks — total prover work across the pass instances equals the
32 per-layer instances' work plus the eq-kernel factor (one extra
multilinear table per instance) and the +5 rounds; the commit path
is EA's dense marginal (+0.2 us/el [MODEL]) over 32x the elements,
committed once. The weight commitment is per-model, off the clock
(TARGET_CONTRACT Section 3). No H-05-class risk is introduced
[MODEL; O-6 owns the full model].

## 7. AZ-L4(a) hash-edge rows for the fold challenges

Extends AGGREGATION_ZK_DESIGN 5.5's table (CRB-N1..N5 + AZB rows
inherited unchanged); SR Section 7 format. Batteries are build-round
scope (AZB numbering continues; F5 pairs = the build round's
forge/fix exhibit pairs).

| challenge | drawn from | must follow | attack if violated | pinned by (planned) |
|---|---|---|---|---|
| h0_agg (pass statement hash) | — (a hash) | T_act, T_W digest, T_blind (all masks/pads/extensions) AND the 32-segment manifest AND the privacy-class group map | segment-swap: relabel layer segments after challenges — the eq-kernel binds the WRONG slices; group-swap: migrate a weight claim into the bare activation opening after mu/nu (a weight functional lands in the bare floor — a PRIVACY break in P2, not just soundness) | **AZB-7 F5 pair (NEW — the two IXF-specific edges)** |
| instance outer draws incl. the 5 index coords r_l | FS on h0_agg | every referenced commitment (all 32 layers' segments) | spike N1: two-position defect with eq_r-weighted sum zero ACCEPTS when r is early (check 12) and REJECTS in order (check 13) — CRB-N1's attack, index-extended | AZB-4 + CRB-N1 (rows extended to the l-coords) |
| the 5 index round challenges | prefix through the round polynomial | round polys | classic sumcheck order attack (CRB-N2 / E3-N4 shape) | CRB-N2 re-run at n + 5 |
| mu (pass terminal batch) | prefix through ALL blinded terminals | every tilde-v of every pass instance | CRB-N4 one level up (terminal chosen after mu) | AZB-4 |
| nu_g (per-group RLC) | prefix through the mu terminals | the group map (in h0_agg) + batched claims | shift one tensor's claim against another's WITHIN a group; cross-GROUP shifts are blocked by the h0_agg group-map edge above | CRB-N5 + AZB-7 |
| c^(i) per group's eval proof | prefix through u_i + norm material | u_i | AZ-L4 A1 (SPKZ-5's attack, unchanged); the two groups' proofs are independent FS lanes after h0_agg — no cross-group edge exists to violate | AZB-6 (per group) |
| (floors) | — | z_L sent after ALL that group's fold challenges | A1 class | AZB-6 |

The IXF-specific content is exactly TWO new edges, both landing in
h0_agg: the **segment-map edge** (the 32-layer manifest must precede
every challenge — otherwise layer relabeling voids the fold) and the
**group-map edge** (the privacy-class assignment of every segment
must precede every challenge — otherwise claims migrate between the
masked and bare openings after the draws). Both are statement-hash
edges — cheap to pin, catastrophic to skip. Everything else is the
per-layer table at n + 5.

## 8. Verdict row

**O-8 DESIGN-CLOSES with instance folding beating the floor.**

| quantity | value | vs reference |
|---|---:|---|
| folded Tier N pass, FFN complete, activation-only (the EA-comparable unit) | **352,948 B = 0.337 MiB** | **4.25x UNDER the 1,500,496 B floor**; 1.35x of one 262,144 B layer-gate unit |
| folded Tier N pass, W-C two-proof (RECOMMENDED — committed weights, P2-ready, 8B-viable) | **505,272 B = 0.482 MiB** | 2.97x under the floor; 1.93x of one layer-gate unit |
| per-layer amortized (W-C) | 15,789 B | **0.060x of the 262,144 B/layer B1 gate** |
| vs 32 unfolded EB-corrected layers (9,068,544 B) | — | **17.9x smaller** |
| 2^20 ledger-unit pass | 294,136 B = 0.281 MiB | 27.9x under its unfolded pass |
| Tier Z preview (FB owns the number): W-C + one masked weight floor (P2) | ~0.65-0.71 MiB | inside Amendment A1's 0.5-2 MiB class |
| Tier Z preview: both floors masked (P3) | ~0.82-0.94 MiB | inside the class |

> **FINAL RECONCILIATION BLOCK (orchestrator, U-AG4 FINAL,
> 2026-08-06)** — four rulings, per the ledger's
> changes-via-orchestrator rule:
> 1. **The two Tier Z preview rows above are SUPERSEDED** by FB's
>    corrected-floor derivation: P2 788,792 B = 0.752 MiB, P3
>    1,063,096 B = 1.014 MiB (AGGREGATION_FOLD_PRIVACY_PRICING.md).
>    The delta is fully explained by the R-EB4 floor correction
>    (90,880/93,952 cleartext coords, ~13-17% above EC's 64-80k
>    class); FB's numbers are the recorded ones, and the A1 freeze
>    (1,114,112 B, P3/W-C scope) is in TARGET_CONTRACT.md.
> 2. **AZB renumbering:** this doc's "AZB-7" label (Sections 7/9,
>    the segment-map/group-map F5 pair) collided with EC's AZB-7
>    (the floor exhibit, priority by age). RULING: the IXF
>    segment/group pair = **AZB-10**; FB's weight-independence
>    canary = **AZB-11**. Read every "AZB-7 F5 pair" in this doc as
>    AZB-10.
> 3. **R-FC3 discharged by citation:** the two-commitment-group
>    composition step (one eval proof per group under shared mu,
>    per-group nu) rides **AFS-L8** in
>    AGGREGATION_FOLDING_SOUNDNESS.md — "SC-L6 verbatim" was not
>    verbatim at two groups; AFS-L8 is the correct citation.
> 4. **R-FC4 discharged (binding, F-IF1 amendment):**
>    slot-completeness **I-3 is restated as binding** for every
>    pass-scope claim family F-IF1.2 enumerates — the 5 index
>    variables extend each family's slot population; no family may
>    leave slots outside the extended enumeration. (FC's
>    one-sentence fix, adopted verbatim.)
> Also noted from FC: R-FC1 (this doc's Section 4 LatticeFold
> rejection stands on corrected grounds — bytes/FS-surfaces/
> envelope tax, not norm-growth-depth or nested rewinding) and
> R-FC2 (the Section 5 digit-base headrooms are knife-edge, <1 b;
> per-group freeze rows are a build-round obligation).

**Does instance folding beat the floor — YES**, by 3.0-4.3x
depending on layout, under these conditions: (1) the D-R1
rho-sharing assumption extends to pass scope (break case 648,376 B —
still 2.3x under the floor; the verdict does NOT hinge on it);
(2) the kel(dw) extrapolation holds within +25% (moves the total
1.9%); (3) the exact-digit branch is used (F-N2 — it is already
triple-mandated); (4) at the 8B shape, the relaxed-e0 line must be
adopted for the weight group's 0.05 b headroom (F-N4 — the one
forward risk with no in-design mitigation). The B1 per-layer gate
becomes trivially met under folding; the binding number is now the
pass number above.

## 9. Exports

### 9.1 To FB (fold/mask + Tier Z pricing) — raw facts, FB owns the lemmas

1. **The floor population under IXF:** the pass has ONE floor per
   commitment group — activation floor 710 rings = 90,880 cleartext
   B, weight floor 734 rings = 93,952 B (R-EB4-corrected; note these
   are ~13-17% LARGER than the 64-80k-coordinate class
   AGGREGATION_ZK_DESIGN 4.4 quotes at layer scale — the R-EB4 base
   caps raised the floor; FB's dim(z_L) numbers should use 90,880/
   93,952). The fold does not create any new floor-class object:
   the floor count went 32 -> 1 per group, and each floor's
   coordinates are challenge-fold images of the PASS-stacked
   witness (AZ-L3(a) verbatim at the bigger shape).
2. **The accumulation split is structural:** the weight floor's
   functionals act on T_W only, the activation floor's on T_act only
   (the group-map edge, Section 7, is what enforces this — it is
   also FB's weight-independence canary hook: the canary certifies
   the ACTIVATION floor carries no weight-dependence, which under
   IXF reduces to checking the group map + the nu_g separation).
   Weight floors accumulate per pass (one per pass, every pass);
   activation floors are one-per-fresh-witness (the P1 bounded-leak
   label bound is dim = 90,880 constraints per pass, once, ever).
3. **Mask-then-fold vs fold-then-mask:** under IXF the question
   collapses to the per-proof question — there are no fold messages
   to mask and no per-step interleaving; every mask/pad commitment
   sits in h0_agg BEFORE all challenges (F-IF1.6), i.e. the shipped
   order is mask-then-fold by construction. FB's lemma should state:
   the fold does not enlarge the floor image because the fold IS the
   commitment layout (no new wire object class exists for it to
   enlarge — Z1-checked: nothing formerly masked reappears; spike
   has no new wire object anywhere).
4. **P2 split pricing inputs:** bare base 505,272 B; the masked
   weight-side proof replaces the 146,644 B bare weight proof; the
   E2-class surcharge band +176-240 KB applies ONCE per pass
   (ZK_GAP_OPTIONS Section 6(c): YES, the weight-side masked proof
   amortizes — one weight commitment, one masked opening per pass
   under IXF). Question (a) is answered structurally (F-IF1.4);
   question (b)'s canary is item 2 above.
5. **W-B warning:** under W-B (merged), P2 CANNOT run a bare
   activation side — the single floor mixes both groups; P2 under
   W-B means masking everything. One more reason W-C is the
   recommended layout.

### 9.2 To FC (folding soundness) — the exact hypotheses

1. **No LatticeFold-class extraction is needed for the adopted
   design.** The obligations are: (a) SC-L4's C-alg/C-ground/C-cap/
   C-msis verified at the pass schedules (Section 5's shapes: act
   e0 = 2, 28,348,416 limb-rings, stop L8, floors 710-734 rings at
   e_f 7, kappa 11, T_cap 33); (b) SC-L6 (batching extractor) at
   pass entry counts (151 entries, 2 groups — nu_g per group);
   (c) FD-L1/L2's SZ terms at n + 5 (a variable-count check, not a
   new theorem); (d) the TWO-PROOF composition: two independent
   SC-L4 chains sharing h0_agg — verify knowledge errors ADD and
   no cross-proof rewinding is needed (the proofs share no witness:
   T_act vs T_W disjoint).
2. **The rejected sequential design is your negative control:** its
   certified norm law (+10.0 bits at 32 folds, spike checks 19-20)
   is the compounded-reading shape of SC 2.2 — if your LatticeFold
   transcription concludes the sequential fold COULD compose at our
   ring within budget, that contradicts this design's Section 4
   arithmetic and must be reconciled at FINAL.
3. **The relaxed-e0 dependency (F-N4):** at the 8B shape the weight
   group needs EB 2.4(b)'s relaxed gamma line (C-win/C-msis as the
   honest gates, not q/8). Please verify the extraction supports the
   relaxed line at the weight-group shape — it is the one place this
   design leans on EB's correction beyond its recorded working
   point.
4. **F-IF1 verification requests:** the spike's composed pipeline
   (dense classes x EB corrections) is anchored at both edges
   (checks 5-6) but the COMPOSITION itself is new — an independent
   re-derivation of the pass schedules (even at one shape) is the
   highest-value check FC can run on this lane's numbers.

### 9.3 Export notes filed (corrections to other lanes' docs — NOT
edited in place)

- AGGREGATION_ZK_DESIGN 4.4: floor dimension at pass scope is
  90,880-93,952 B-coordinates (R-EB4-corrected), not 64-80k — FB to
  carry into the label text.
- AGGREGATION_ENCODING_DESIGN 4.3's floor (1,500,496 B) is
  reproduced exactly (spike check 2) and now BEATEN; its "instance
  folding mandatory" conclusion is confirmed and discharged.
- DA/EA/EB layer artifacts price no weight-domain opening (the
  latent assumption of F-IF1.4) — orchestrator to record at FINAL
  whether the per-layer B1 gate stays activation-only (recommended:
  yes, it is an engineering gate).

### 9.4 Obligations raised here (for the ledger)

- **F-O1 (build round):** the pass manifest (32 segment rows +
  privacy-class group map) in Statement v3; the AZB-7 F5 pair
  (segment-swap + group-swap batteries).
- **F-O2 (build round):** kel(dw) measurement at dw 26/29 (replace
  the F-IF1.8 extrapolation with recorded points — the M4 masked
  descent rig at stacked toy shapes can produce them).
- **F-O3 (build round / O-5):** the pass verifier model to R2
  discipline (the 1.2 s-class W-C estimate of 6.4 is [MODEL];
  includes the two-proof structure).
- **F-O4 (8B rung):** adopt the relaxed-e0 line for the weight
  group BEFORE any 8B q31 commitment layout is frozen (F-N4).
- **F-O5 (with FB):** the Tier Z pass number = this design's W-C
  base + FB's mask deltas — the Amendment A1 freeze candidate is
  FB's deliverable on this base.

## 10. R-FC2 per-group digit-headroom FREEZE ROWS (dated addition, 2026-08-08, U-AG-B1 Agent BA)

R-FC2 (AGGREGATION_FOLDING_SOUNDNESS.md 8.3: "the Section 5
digit-base headrooms are knife-edge, < 1 b; per-group freeze rows are
a build-round obligation") is DISCHARGED here. Enforcement:
`scripts/aggregation_freeze_rows.py` Section 5 (run under the suite
by `tests/test_aggregation_freeze.py`) re-derives every row below
from the transcribed chain and fails if EITHER the chain or a pin
moves. Nothing above this section was edited.

### 10.1 The frozen chain (exactly the F-IF1.5 / spike form)

    N_limb(e0)    = sum over value classes c of  n_c · max(1, ceil(bits_c / e0))
    gamma_z(pass) = OP_CONC · 2^(e0−1) · sqrt(N_limb · D),   OP_CONC = 20.8 = 1.3·sqrt(2D)
    headroom      = log2(gamma_max) − log2(gamma_z)
    gamma_max     = 2^28 / 58.81 = 2^22.12  (exact-digit gate; = (q/8)/(2·29.42))
                  = 2^28 / 121.5 = 2^21.07  (per-level gate, recorded alternative)

Frozen class inventories (rings, value bits) — the derivation side of
the count pins:

| group | classes | derivation | source |
|---|---|---|---|
| activation, FFN pass | (4,227,072, 8), (1,409,024, 15), (6,400, 31), (4,096, 31) | 32 x 3 x 44,032 (X/Y/UP dense int8, 512x11008/128 rings each); 32 x 44,032 (Z); 32 x 200 aux; T_blind 2^12 [MODEL] | 5.1; EA 2.3/2.4; DA 2.5 |
| weight, W-C | (33,816,576, 8) | 3 x 32 x 4096·11008/128, dense int8 | 5.2; F-IF1.4 |
| weight, 8B [MODEL] | (44,040,192, 8) | 3 x 32 x 4096·14336/128 | 5.2 F-N4 |
| activation, 2^20 ledger-unit pass | (786,432, 8), (262,144, 15), (5,376, 31), (4,096, 31) | 32 x per-layer (24,576 / 8,192 / 168) + T_blind | EA SHAPES; spike pass_classes |

### 10.2 The rows

Deployment-mode note: the mode (P0-P3) decides WHICH groups open and
whether their floors are masked (F-IF1.4); it does NOT move gamma_z —
masking is a byte surcharge, not a norm term (FB's lemma set). The
norm rows below are therefore mode-independent; the per-mode content
of the freeze is the group map itself (activation group opens in
every mode; weight group per deployment; W-B merged priced,
NOT recommended, no P2 split, no 8B future).

| row id | group / point | e0 | N_limb | gamma_z | gate | headroom | verdict | doc prints |
|---|---|---:|---:|---|---|---:|---|---|
| FC2-act2 | activation, FFN pass — **ADOPTED** (all modes) | 2 | 28,348,416 | 2^21.26 | 2^22.12 | **+0.865 b** | fits, robust, zero byte premium (F-N3) | 0.86 here; 0.87 in FS 8.3 (rounding ulp) |
| FC2-act3 | activation, byte-optimal (razor; NOT adopted) | 3 | 19,841,792 | 2^22.00 | 2^22.12 | +0.122 b | fits, razor | 0.12 |
| FC2-act1 | activation, conservative per-level-gate variant | 1 | 55,277,312 | 2^20.74 | 2^21.07 | +0.336 b | fits (EB-Section-4-convention variant) | 0.33 (exact 0.336) |
| FC2-act5 | activation, the LAYER base at x32 — NEGATIVE row | 5 | 12,754,688 | 2^23.68 | 2^22.12 | **−1.559 b** | FAILS — the pass re-derivation is mandatory (spike N5) | −1.56 |
| FC2-W | weight, W-C — **ADOPTED** (sign-binary) | 1 | 270,532,608 | 2^21.88 | 2^22.12 | **+0.237 b** | fits ONLY on the exact-digit branch | 0.24 here; 0.23 in FS 8.3 |
| FC2-FN2 | weight vs the per-level gate — NEGATIVE row | 1 | 270,532,608 | 2^21.88 | 2^21.07 | −0.809 b | INFEASIBLE — F-N2: exact-digit is load-bearing for the weight opening | (structural) |
| FC2-WB | merged W-B variant (priced, NOT recommended) | 1 | 325,809,920 | 2^22.02 | 2^22.12 | +0.103 b | 7B-only; exceeds the gate at 8B | 0.10 |
| FC2-W8B | weight at the 8B shape [MODEL] — the knife edge | 1 | 352,321,536 | 2^22.07 | 2^22.12 | **+0.047 b** | the sharpest number in the design; F-O4 (relaxed-e0 line BEFORE any 8B freeze) stands as the fence | 0.05 |
| FC2-led | activation, 2^20 ledger-unit pass | 4 | 2,697,216 | 2^21.56 | 2^22.12 | +0.561 b | fits | 0.56 |
| FC2-law | the one-time pass norm law | — | — | — | — | +2.5 b = log2 sqrt(32), once, NO per-step growth | verified (FS V3) | 2.5 |

Pins are the exact derived values at 3 decimals; every doc-printed
2dp value above sits within 0.01 of its pin (the FS-8.3 "0.87/0.33/
0.23" prints and this document's "0.86/0.33/0.24" prints are the two
rounding directions of the same exact values — recorded so neither
gets "corrected" into a real change later).

### 10.3 What must extend this table (exports)

- **Lane BB (engine):** when the pass commitment layout lands in
  Rust, the group map + per-group (e0, N_limb chain, gamma gate) must
  be asserted at derive time and pinned in `freeze-check` (the
  LKP-7/8/9 both-direction pattern); the Python battery is the
  enforcement point until then. The 125M-shape rows (512x768x2048,
  12 layers, index pad to 16) do NOT exist yet — they must be DERIVED
  by the build round and appended here as new dated rows, not
  extrapolated from the FFN rows [MODEL until derived].
- **Lane BC (F-O4):** the 8B row's 0.047 b headroom is frozen HERE at
  the q/8-derived gate; adopting EB 2.4(b)'s relaxed-e0 line (the
  honest C-win/C-msis gates, ~6 b window margin) is the recorded
  relief and MUST be an explicit dated amendment to this table before
  any 8B q31 layout freeze.

## References

1. AGGREGATION_ENCODING_DESIGN.md (U-AG3 EA) — instance population,
   byte model, the O-8 floor, D-1 encoding.
2. AGGREGATION_CLAIM_REDUCTION.md (U-AG2 DB) — CR-L1..L6, the
   reduced protocol, FS table CRB-N1..N5.
3. AGGREGATION_PARAMS_DESIGN.md (U-AG2 DA) — layout, gamma formula,
   level machinery, byte skeleton.
4. AGGREGATION_SOUNDNESS_COMPOSITION.md (U-AG3 EB) — SC-L4/SC-L6,
   kappa 11, T_cap, R-EB1/3/4, the corrected constants.
5. AGGREGATION_ZK_DESIGN.md (U-AG3 EC) — AZ-L3/AZ-L4, the floor
   object, hash-edge format.
6. ZK_GAP_OPTIONS.md + TARGET_CONTRACT.md Amendment A1 — the Option
   B decision, modes P0-P3, tier structure.
7. PROOF_BYTE_LEDGER.md (U-AG GB) — unit costs, the four recorded
   descent points, format.
8. AGGREGATION_LITERATURE.md Section 2 — the LatticeFold lineage
   record (refs 6/7 there); the family-(b) scorecard this design
   instantiates on the "add-on accumulator" branch.

---

*Changelog: 2026-07-27 — first edition committed EARLY with F-IF1
binding and Sections 3-9 as skeletons (the interface-note protocol);
same day: [spike-final] slots filled from
`aggregation_folding_spike.py` (33/33), Sections 3-9 completed:
IXF lemmas FD-L1..L4, sequential-fold rejection priced, norm tables
(F-N2/F-N3/F-N4), byte tables (294,136 / 352,948 / 505,272 /
356,020 B), hash-edge rows (AZB-7's two new edges), verdict (floor
beaten 3.0-4.3x), FB/FC exports, obligations F-O1..F-O5.*

*2026-08-08 (U-AG-B1 Agent BA) — Section 10 appended: the R-FC2
per-group digit-headroom freeze rows (chain, class inventories, nine
rows + the one-time law) with both-direction enforcement in
scripts/aggregation_freeze_rows.py / tests/test_aggregation_freeze.py;
engine wiring exported to lane BB, the 8B relaxed-e0 amendment fence
to lane BC (F-O4). No pre-existing text edited.*
