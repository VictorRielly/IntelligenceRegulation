# The Fold/Mask Interaction and the Option B Pass Pricing (U-AG4, Agent FB)

Status: DESIGN COMPLETE (U-AG4 tranche, Agent FB lane, 2026-08-06;
paper + Python spike only — no engine changes). Deliverables per
PROGRESS_UAG4.md FB lane: the **fold/mask interaction lemma**
(Section 2), the **folded Tier Z pass number** — the TARGET_CONTRACT
Amendment A1 freeze candidate (Section 3), the **P2 split-proof
pricing** — ZK_GAP_OPTIONS Section 6 questions (a)-(c) settled
(Section 4), the **P1 bounded-leak label template** (Section 5), and
the **E4-wrap endgame pricing under folding** (Section 6). Built on
the FINAL F-IF1 interface (IXF flat-32 — AGGREGATION_FOLDING_DESIGN
.md Section 2, read complete with its Section 9.1 exports) and the
FC verification (AGGREGATION_FOLDING_SOUNDNESS.md Sections 8-10).
There are NO [F-IF1 PENDING] rows: both sibling lanes closed before
this document was written.

Spike: `scripts/fold_privacy_pricing_spike.py` (stdlib, < 1 s,
< 100 MiB RSS, **15/15 numbered OK checks** — output recorded
verbatim in Section 9; every byte total and threshold quoted below
is printed by it unless cited elsewhere).

Grading legend (SOUNDNESS_REFERENCE.md Section 0 + the spike-round
convention): [PROVEN] / **[PROVEN*]** (complete argument here + a
named FPP spike certificate; engine-scale certification owed to the
build round) / [MODEL] / [OBLIGATION].

## 0. Plain-language summary (start here)

**What this document decides.** Victor's Option B decision made
zero-knowledge non-negotiable: the proof must not leak the private
data (model weights and/or user inputs — whichever the deployment
declares private), and we agreed to pay extra proof bytes for that.
The open question was the PRICE after folding: Amendment A1 left a
blank — "the binding pass-level Tier Z budget is frozen at the
U-AG4 FINAL" — with a guess of 0.5-2 MiB per 32-layer pass. This
document fills the blank.

**The headline numbers.** On Agent FA's folded pass (one proof for
all 32 layers, the recommended W-C layout with committed weights):

- **Full privacy (P3 — weights AND inputs private): ~1.01 MiB per
  pass** [MODEL]. Recommended freeze: **1.0625 MiB**.
- **Weights-only privacy (P2 — the likely flagship: proprietary
  model, non-secret inputs): ~0.75 MiB per pass** — the Tier N
  (non-private) pass plus ~0.27 MiB.
- **Inputs-only privacy (P1), if the small quantified input leak
  below is declared acceptable: ~0.49 MiB per pass** — essentially
  the Tier N price.

For scale: today's measured unfolded protocol is ~595 GiB per pass —
the full-privacy folded number is ~600,000x smaller; the unfolded
Option B estimate was 14-16 MiB per pass — folding made full ZK
~14-16x cheaper, exactly the "the surcharge is per evaluation proof,
so folding concentrates it" prediction, now derived instead of
guessed. All three modes land INSIDE Amendment A1's 0.5-2 MiB
target class.

**Why the price went up a little vs FA's preview.** FA previewed
P2 at 0.65-0.71 MiB and P3 at 0.82-0.94 MiB using the older
"+176-240 KB" masking-surcharge class. That class was computed
against the older, smaller floor. The "floor" is the one part of
the compressed proof that is sent in the clear (the recursion's
final small witness), and the soundness corrections of the last
round (R-EB4) made it ~13-17% bigger: 90,880 bytes (activation
side) / 93,952 bytes (weight side) per pass. Masking the floor
means replacing each 1-byte cleartext value with a ~4-byte
noise-widened value, so the surcharge is 3 bytes per floor
coordinate: **+272,640 B / +281,856 B per masked floor** — re-derived
here from the corrected floors, not imported. That pushes P2/P3 to
0.75/1.01 MiB. Still comfortably inside the target class.

**The main structural finding (the fold/mask lemma, Section 2).**
The worry going into this round: does folding 32 layers into one
proof multiply the leaky floor by 32? Answer: **no — the fold
CONCENTRATES the leak instead of multiplying it.** The adopted fold
(FA's IXF) has no per-step folding messages at all — the 32 layers
are committed into one commitment and proven by one set of
slightly-longer sumchecks, so the pass has exactly ONE floor per
commitment group (one for activations, one for weights), the same
as a single proof — where 32 unfolded proofs would have exposed 32
floors (~2.6 million cleartext values vs ~91-185 thousand). And
because all masks and the layer/privacy bookkeeping are bound into
the statement hash BEFORE any challenge is drawn, the
"mask-then-fold" ordering the ledger demanded holds by
construction. The one genuinely new privacy edge is the **group
map**: the statement's assignment of every committed segment to
"weight side" or "activation side" must be hashed before any
challenge — otherwise a weight claim could migrate into the bare
activation proof and leak weight material (the spike demonstrates
the leak explicitly, and shows the shipped ordering plus a new
battery canary both catch it).

**The weights-vs-inputs asymmetry, now with concrete numbers**
(this is why "which side is private" matters so much, Section 4/5):

- **Inputs/activations** are fresh every pass. One pass leaks one
  floor = 90,880 fixed linear combinations of ~723 million
  committed activation values — 0.013% of what full recovery would
  need; an attacker would need ~7,953 fresh proofs OF THE SAME PASS
  (which the standing one-proof-per-pass rule forbids). That is the
  P1 "partial knowledge" case: small, quantified, bounded — the
  label text is in Section 5.
- **Weights** are the same witness re-proven every pass. Floors
  accumulate: at the 15 s/pass roadmap target, an unmasked weight
  floor reaches naive full-recovery rank in ~46,000 passes — about
  **8 days of continuous proving**. No rule can bound how many
  passes a deployment runs (proving is the product), so the weight
  floor must be masked on every pass in P2/P3. That is exactly what
  the +281,856 B buys.

**Labels used below**: "Tier N / Tier Z" = the non-ZK-labeled /
full-ZK artifact tiers of Amendment A1; "P0-P3" = the declared
private set (nothing / inputs / weights / both); "floor" = the
evaluation proof's final cleartext witness; "W-C" = FA's
recommended two-proof layout (separate activation and weight
commitment groups — the thing that makes P2's split possible);
"masked floor" = the E2/E4 rejection-sampled floor response
(4 B/coordinate); "IXF" = index-extension folding, FA's adopted
fold; "canary" = a derive-time machine check that fails loudly if
an invariant breaks.

## 1. Scope, sources, and the corrected floor sizes

### 1.1 What this lane owns

The privacy/pricing axis of the folded pass: the fold/mask
interaction (the EC export "the fold must not enlarge the floor
image" made precise), the Tier Z pass number that freezes Amendment
A1's blank, the P2 split-proof questions (a)-(c) that ZK_GAP_OPTIONS
Section 6 names as U-AG4 deliverables, the P1 label template, and
the E4 endgame. NOT this lane's: the fold shape itself (FA, final),
folding extraction (FC, verified COMPOSES), engine changes (build
round).

### 1.2 Sources (all read in full or at the cited sections this session)

PROGRESS_UAG4.md (lane spec + standing constraints);
ZK_GAP_OPTIONS.md (Sections 4B, 6, 7 — the decision and the open
questions); TARGET_CONTRACT.md Amendment A1; AGGREGATION_ZK_DESIGN
.md (the three surfaces, AZ-L1..L4, Section 4.4 the floor + masking
grid, 4.5 escapes, Section 6 AZB battery, 7.3 exports);
AGGREGATION_CLAIM_REDUCTION.md (CR-L4/CR-L5, Sections 10-11);
AGGREGATION_ENCODING_DESIGN.md (Section 3 byte model, 4.3 the O-8
floor, Section 6 exports; the D-R2 ~136 KiB extra-proof price, the
E-O2 rule); AGGREGATION_PARAMS_DESIGN.md (byte/JL/mask parameters);
AGGREGATION_SOUNDNESS_COMPOSITION.md Section 2.4 (R-EB4, kappa 11,
the corrected 283,392 B layer, the relaxed validity line);
WAVE_SHARE_MASKING_DESIGN.md Section 3 (the simulator idiom);
PROOF_BYTE_LEDGER.md Section 0 (unit widths, format);
AGGREGATION_FOLDING_DESIGN.md (FA — F-IF1 FINAL, byte tables,
Section 9.1 exports to this lane); AGGREGATION_FOLDING_SOUNDNESS.md
(FC — Section 8 verification + R-FC rows, Section 10 exports to
this lane).

### 1.3 The corrected floor sizes (the numbers everything below prices against)

FA's export 9.1 item 1, adopted here as the floor population of the
folded pass (R-EB4 base caps active, e_f = 7, kappa 11):

| object | rings | cleartext coords = bytes (1 B/coord at e_f = 7) |
|---|---:|---:|
| activation-group pass floor (FFN, L8) | 710 | **90,880** |
| weight-group pass floor (FFN, L8) | 734 | **93,952** |
| 2^20 ledger-unit pass floor (L7) | 732 | 93,696 |
| (reference: EB-corrected LAYER floor) | 640 | 81,920 |
| (reference: EC's pre-R-EB4 floor class) | 500-624 | 64,000-79,872 |

These are ~13-17% LARGER than the 64-80k class AGGREGATION_ZK_DESIGN
4.4 quotes (the R-EB4 base caps raised the floor). **Every masking
surcharge in this document is re-derived from these floors; the
+176-240 KB class is retired** (it appears only in the Section 3.4
reconciliation row).

### 1.4 Standing constraints, and the one reconciliation stated plainly

Inherited unchanged: Z1 discipline; one-proof-per-witness (now: per
PASS — the pass is the witness unit); exact-digit config
(triple-mandated; load-bearing for the weight group per F-N2);
DENSE encoding; per-pass scope; ring X^128+1, q31, GF(q^16) slots,
kappa 11, T_cap 33, R-EB3 K-draws, R-EB4 caps; numbers only from
repo-recorded sources, [MODEL] flags on unmeasured constants;
codex-audit-* read-only.

**I-6 and the Tier Z mask — the reconciliation.** I-6 (HARD) bans
Gaussian-masked openings in the aggregate layer at q31: derived at
GLOBAL fold scale (sigma ~2^25.3, bound ~2^37 — impossible) and, at
floor scale, dead on BYTES at the old 262,144 B budget. The Option
B decision (Amendment A1) is precisely the adoption of escape
E4 = "pay the bytes so the E2 floor-scale carve-out opens". So: the
Tier Z artifact contains exactly ONE class of rejection-sampled
masked object — the floor response, priced in Section 3 — under the
A1 authority; I-6 remains in force everywhere else (no global
masked opening, no per-level masked openings, ZK of surfaces 1-2
rides T_blind + masked sumcheck only, unchanged). The norm-side
condition for the carve-out (the e_L <= 4 no-limb-growth corner) is
re-checked at the pass floors in Section 3.1 and named F-Z1.

## 2. The fold/mask interaction lemma

### 2.1 Lemma FP-L1 (floor non-enlargement under IXF)

**Statement.** Under F-IF1 (IXF flat-32, W-C layout), the folded
pass transcript contains exactly ONE recursion-floor object per
commitment group, of dimension 90,880 (activation) / 93,952
(weight) base coordinates; each coordinate is a challenge-keyed
deterministic linear image of that group's level-L witness — AZ-L3
(a) verbatim at the pass-stacked shape — and the per-proof
accumulation law of AZ-L3(b)/(c) is unchanged by the fold. The
pass's total floor-class exposure is therefore 90,880 coords
(P1/activation-bare) or 184,832 coords (both groups bare), versus
32 x 81,920 = 2,621,440 coords for 32 unfolded EB-corrected layer
proofs: the fold REDUCES floor-class exposure per pass by
**14.2x (both groups) / 28.8x (activation side)** while leaving the
per-proof leak law untouched.

*Proof.* Four components, each already certified where cited:

1. **No new wire-object class exists for the fold to leak through.**
   F-IF1.1's disposition table has zero per-step fold messages, no
   accumulator-witness pair, no cross-terms; the only wire object
   that scales with layer count is the statement manifest (public
   metadata, D-2 class). Z1-checked by FA ("nothing formerly masked
   reappears; the spike has no new wire object anywhere").
2. **One eval proof per group.** CR-L4b's nu_g is drawn per group
   (F-IF1.6); each group emits one batched opening (E-O2 at pass
   scope), hence one recursion, hence one floor. [FA F-IF1.4;
   FC AFS-L8 verifies the two-group composition.]
3. **Floor dimension is witness-size-independent.** The floor is
   set by the LaBRADOR regrowth terms r_i·kappa·l_t + r_i(r_i+1)·
   l_gh (PARAMS 3.2), NOT by the witness size — EA's F-4
   (sqrt-law refutation) and EC's 1.3 export, R-EB4-corrected.
   Stacking 32 layers grows the floor only through +2-3 recursion
   LEVELS and the base caps: 710/734 rings vs the 640-ring layer
   floor (+11-15%), never x32. Spike **FPP-3a**: stacking 8/16/32
   toy layers under one commitment leaves the floor image dimension
   constant.
4. **The accumulation law is fold-invariant.** Each pass proof
   exposes dim(z_L) fresh challenge-keyed constraints on the SAME
   stacked witness; rank grows by exactly one transcript's worth
   per proof until naive completeness at the m2 threshold — spike
   **FPP-3b** (rank 1 / m2/2 / m2 at t = 1 / m2/2 / m2; exact
   witness-row recovery at t = m2 = 128; solution space dim m2 - 1
   after one transcript). The fold changes the proofs-per-pass
   COUNT (32 -> 1 per group), not the per-proof law. ∎

Status: **[PROVEN*]** — FPP-3a/3b; components [PROVEN]/[MODEL] as
cited (the floor ring counts are FA's spike-printed schedules
[MODEL at the kel/schedule level]).

This is the EC export ("the fold must not enlarge the floor image")
made precise, and it comes out STRONGER than required: the fold
shrinks the pass's exposure by an order of magnitude while the
masked modes (Section 3) delete it entirely.

### 2.2 Lemma FP-L2 (mask-then-fold; the ordering, extending AZ-L4)

**Statement.** Under IXF there are NO claim-layer fold challenges
and no per-step interleaving, so AZ-L4(b)'s "mask commitments
precede every challenge their uniformity lemma treats as
independent" collapses to statement-hash edges: T_blind (all
masks, extension pads, claim segment), the 32-segment manifest, AND
the privacy-class group map must all be inside h0_agg, which
precedes every draw (F-IF1.6 row 1). The shipped order is therefore
mask-then-fold BY CONSTRUCTION, and "fold-then-mask" is not even
expressible at the claim layer. What survives as live ordering
content is the PRIVACY COLUMN of FA's two new AZB hash edges plus
two mask-specific rows:

| edge (extends AZ-L4 A1-A4 / FA Section 7) | privacy attack if violated | spike / battery |
|---|---|---|
| **A5 (segment map late)**: the 32-layer segment manifest enters FS after some challenge | pad-to-segment assignment correlates with challenges — AZ-L2a's independence hypothesis fails (the A4 class, per segment); P1's label semantics also void (the floor can no longer be attributed to a declared pass) | FA's segment-swap F5 pair, privacy leg |
| **A6 (group map late)**: the privacy-class assignment enters FS after mu/nu_g | weight-referencing claims migrate into the BARE activation opening: up to dim(z_L) = 90,880 weight-functional coordinates land in cleartext in ONE pass — the P2 privacy break | **FPP-4b** (the leaked delta is exhibited as an explicit weight functional c_5·w1; the recompute canary fires; the shipped h0_agg edge rejects); battery = FA's group-swap F5 pair + the AZB-11 canary (Section 4.2) |
| **A7 (T_blind pass freshness)**: mask/pad material reused across passes | transcript differences re-expose masked values at half rate (E3Z-N3/Z1-h class) — AZB-5 verbatim with the refresh unit = the PASS | AZB-5, pass-scoped |
| **A8 (Tier Z floor mask)**: the masked floor response's Gaussian mask is prover-internal (rejection-sampled, never committed) — no hash edge exists or is needed; the response is sent after all of that group's level challenges (AZB-6 unchanged) | the abort/restart discipline must not leak through timing/restart counts beyond the standard FS-with-aborts argument | obligation **F-Z2** (Q4.2a-class transcription at build) |

*Proof.* The collapse claim is F-IF1.0/F-IF1.6 read against
AZ-L4(b)'s hypothesis list: every mask-consuming challenge class
(instance draws, index rounds, mu, nu_g, eval-proof c^(i)) is
FS-derived from a prefix containing h0_agg, and h0_agg contains
every mask/pad commitment — so every independence hypothesis of
AZ-L1a/b and AZ-L2a/b holds at pass scope by the same argument as
at layer scope (the lemmas are variable-count- and
instance-count-generic; AZ-L1b covers the shared-challenge
parallelism, which is exactly how the pass instances run). A5/A6
are the two NEW ways the collapse could silently fail, and both are
statement-hash edges. FPP-4a certifies the shipped direction
(activation floor recomputed exactly from (T_act, challenges) and
INVARIANT under weight perturbation); FPP-4b certifies the attack
direction. ∎ Status: **[PROVEN*]** — FPP-4a/4b; the h0_agg edge
inventory is FA's (verified by FC V4).

### 2.3 Where the lemma FAILS, precisely (constraints on fold shapes)

- **FP-C2 (the W-B failure — real, present, avoided).** Under the
  merged single-proof layout W-B, FP-L1's "one floor per group"
  degenerates to one floor MIXING both groups: the floor's
  coordinates are challenge-images of the joint (activation,
  weight) witness, so no bare mode exists for EITHER side — P2
  cannot run a bare activation proof, and P1 cannot run at all
  without paying the full mask. The split corollary of FP-L1
  FAILS under W-B. (Confirms FA 9.1 item 5 from the privacy side;
  W-B is independently norm-dead at 8B, F-N4 — doubly rejected.
  W-C is not a preference, it is what makes partial privacy
  EXIST.)
- **FP-C1 (condition on any future fold shape, exported).** FP-L1
  holds for any fold whose per-step material is COMMITTED and
  whose decide emits one floor per group. A fold emitting per-step
  CLEARTEXT norm-checked material (bare JL rows per fold round,
  bare per-step decomposition limbs, per-step mini-floors) enlarges
  the floor-class exposure by a factor of the step count — for such
  shapes the lemma FAILS and the Tier Z price scales with depth.
  The rejected sequential RLC family as conditioned by FC
  (AFS-L1..L5: per-round material committed, range arms in-sumcheck)
  does NOT violate FP-C1 — but each of its 31 fold steps carries
  the A5/A6-class FS surface, so its Tier Z ordering analysis would
  be 31x this section's. Binding on any streaming variant; joins
  F-C1..F-C6.

## 3. The folded Tier Z pass number (the Amendment A1 freeze candidate)

### 3.1 The masking surcharge, re-derived at the corrected floors

The Tier Z mask is the E2/E4 floor-scale response (Section 1.4):
replace the bare floor (1 B/coordinate at e_f = 7) by a
rejection-sampled masked response at ~4 B/coordinate (the response
bound 2^27-28-class needs 29 bits + sign — EC 4.4's width,
unchanged). Surcharge = 3 B/coordinate at the **no-limb-growth
corner** [MODEL]:

| masked object | coords | bare B | masked B | surcharge |
|---|---:|---:|---:|---:|
| activation pass floor | 90,880 | 90,880 | 363,520 | **+272,640** |
| weight pass floor | 93,952 | 93,952 | 375,808 | **+281,856** |
| 2^20 pass floor | 93,696 | 93,696 | 374,784 | +281,088 |

**The norm corner survives at pass scale (F-Z1).** EC's SPKZ-7b
grid: the masked floor is norm-viable only at e_L <= 4 with no limb
growth (2^27.2 vs the q/8 = 2^28.00 line; the limb-growth branch
2^28.6 is dead). Scaling the bound by sqrt(dim) to the pass floors
[MODEL, first-order]: 2^27.27 (act) / 2^27.30 (weight) — the corner
carries to the pass with ~0.7 bits, and the limb-growth branch
stays dead (spike **FPP-7**). Two honest flags: (i) the corner is
the E4 decision's known engineering risk ("the corner closes under
implementation detail" — ZK_GAP_OPTIONS 4B); it is now condition
**F-Z1** on the freeze. (ii) EB's corrected validity line (the q/8
discipline replaced by C-win/C-msis with ~6 bits of window margin —
SC 2.4(b)) only WIDENS the corner; F-Z1 is stated against the
stricter line, so the risk is one-sided in our favor. The
extraction-side counterpart (SC-L4's chain at the masked response
bound) is obligation **F-Z2**, exported to FC/build (Section 8.2).

### 3.2 The mask wire deltas [MODEL]

Per MASKED instance (EC 2.2/3.5 at pass scope): one G_j mask-sum
pin + one mask opening = 2 K-el = 128 B, plus 1-2 selector-extension
rounds at wire-degree 3 = 192-384 B: **320-512 B per masked
instance, midpoint 416 B**. Instance counts: P3 and P1-strict mask
all 8 pass instances (every instance touches a private tensor);
P2 masks 4 (the three matmuls — their round polynomials are
functions of the private weights — and the terminal batch, whose
rounds mix weight-tensor contributions); the 2^20 rig masks its 2.
The descent pair is priced masked in every tier already (the built
Q4.7-9 machinery — FA's base tables carry the masked kel counts).
Committed-only material (zero wire): T_blind at pass scope fits its
4,096-ring window with >= 6x headroom — spike **FPP-8** (~4,949
K-el ~ 619 rings: descent masks scaled to dw 29, instance masks,
one ring-granular pad per batch entry (AZ-R1), claim segment);
per-level hiding tails as in EC 4.3.

### 3.3 The Tier Z pass tables (PROOF_BYTE_LEDGER format)

All rows: exact-digit branch, kappa 11, R-EB3/R-EB4, W-C layout,
canonical ledger widths; base components are FA's (reproduced from
formulas — spike **FPP-5a**); [MODEL] items flagged per line. FFN
512x4096x11008 complete pass:

| component | P1-label (bare floors) | P1-strict | P2 | P3 |
|---|---:|---:|---:|---:|
| statement (v3 + 32-row manifest + group map) [MODEL] | 6,144 | 6,144 | 6,144 | 6,144 |
| outer identities u (T_act + T_blind + T_W, kappa 11) | 17,040 | 17,040 | 17,040 | 17,040 |
| masked descent pair (dw 29 + dt 9) [MODEL kel fit] | 143,104 | 143,104 | 143,104 | 143,104 |
| folded instance transcript (8 inst) | 37,056 | 37,056 | 37,056 | 37,056 |
| mask wire deltas (n_masked x 416 B) [MODEL] | 3,328 | 3,328 | 1,664 | 3,328 |
| batch-entry claimed values (151) [MODEL] | 9,664 | 9,664 | 9,664 | 9,664 |
| eval proof [activations]: L8 msgs 52,692 + floor | 143,572 (bare) | 416,212 (masked) | 143,572 (bare) | 416,212 (masked) |
| eval proof [weights]: L8 msgs 52,692 + floor | 146,644 (bare) | 146,644 (bare) | 428,500 (masked) | 428,500 (masked) |
| framing [MODEL] | 2,048 | 2,048 | 2,048 | 2,048 |
| **TOTAL (pass)** | **508,600** | **781,240** | **788,792** | **1,063,096** |
| MiB | 0.485 | 0.745 | **0.752** | **1.014** |
| B/layer amortized | 15,894 | 24,414 | 24,650 | 33,222 |
| x of the 262,144 B B1 layer gate (amortized) | 0.061 | 0.093 | 0.094 | 0.127 |

2^20 ledger-unit pass (32 rig layers, activation group only — the
rig statement has no matmul/weights; the Tier Z mode = masked
activation floor):

| component | Tier N (FA) | Tier Z |
|---|---:|---:|
| statement + identities + descent pair + instances + entries + framing | 154,464 | 154,464 |
| mask wire deltas (2 inst) [MODEL] | — | 832 |
| eval proof [act]: L7 msgs 45,976 + floor | 139,672 (bare) | 420,760 (masked) |
| **TOTAL (pass)** | **294,136** | **576,056 = 0.549 MiB** |

Reference row (the EA-comparable activation-only FFN layout, NOT a
deployable P2/P3 shape): 352,948 base + 272,640 + 3,328 = 628,916 B
= 0.600 MiB.

**Cross-check vs FA's Tier Z preview** (orchestrator instruction:
cross-check, don't import): FA previewed P2 0.65-0.71 / P3
0.82-0.94 MiB using the pre-R-EB4 +176-240 KB surcharge class. The
corrected floors move the class to +266-275 KiB per masked floor,
landing P2/P3 at 0.752/1.014 MiB — **+0.05-0.09 MiB above the
preview, fully explained by the floor correction**; both stay
inside the A1 class. FA's preview rows should be superseded by this
table at FINAL.

### 3.4 The unfolded check rows (the formulas reproduce ZK_GAP_OPTIONS 4B)

Spike **FPP-5d** reproduces, from the same component conventions:

| row | per layer | x32 pass |
|---|---:|---:|
| Option A / Tier N unfolded (EB-corrected exact-digit layer) | 283,392 B | 9,068,544 B = 8.65 MiB |
| Option B / Tier Z unfolded = 283,392 − 81,920 (bare layer floor out) + 4 B/coord x 512..640-ring masked floor [MODEL band] | 463,616..529,152 B | 14,835,712..16,932,864 B = **14.15..16.15 MiB** |

— the ZK_GAP_OPTIONS Section 4B corridor and its 14-16 MiB pass
class, exactly. (The corridor's [MODEL] band reads as the masked
floor rescheduled between 512 and 640 rings; the surcharge
convention — 4 B/coord response replacing the 1 B/coord bare floor
— is the same one Section 3.1 applies at the pass floors.)

Surcharge concentration (spike **FPP-5e**): the unfolded pass pays
32 masked floors = 5.50-7.50 MiB of pure surcharge; the folded W-C
pass pays TWO = 0.529 MiB — a **10.4-14.2x concentration**, the
per-evaluation-proof prediction of ZK_GAP_OPTIONS Section 4B made
exact.

### 3.5 Sensitivities [MODEL]

On the P3 total (1,063,096 B): FA's W-C base band (entries band,
requant count, kel fit +25%) spans −5,632/+11,600 B; the mask-delta
band spans −768/+768 B; the surcharges are exact given the R-EB4
schedules (floors are schedule outputs, not fits). Worst-case P3
band: **1,075,464 B = 1.026 MiB**. The one sensitivity that would
move the number materially is D-R1 breaking at pass scope (a second
full descent pair, +143,104 B -> P3 1.150 MiB) — still inside the
A1 class; the freeze below survives it only if re-opened, so D-R1
stays a named battery item (FA's disposition unchanged).

### 3.6 The freeze candidate

**Proposed Amendment A1 freeze row (the binding pass-level Tier Z
budget):**

> Tier Z (full-ZK aggregate artifact, modes P1-P3), binding
> pass-level budget: **<= 1,114,112 B (1.0625 MiB) per 32-layer FFN
> pass** (scope: the TARGET_CONTRACT Section 1 complete-FFN
> workload, one v3 statement, W-C two-group layout, exact-digit
> branch, kappa 11). Derived point: P3 = 1,063,096 B [MODEL], worst
> modeled band 1,075,464 B; the budget covers P3 with 3.6-4.8%
> model-risk headroom, and P2 (788,792 B) / P1 (508,600-781,240 B)
> a fortiori. Conditions attached to the freeze: **F-Z1** (the
> e_L <= 4 no-limb-growth masking corner, re-verified at pass
> floors, must survive the build round's schedule implementation),
> **F-Z2** (SC-L4 extraction at the masked-floor response bound),
> **F-O2** (FA's kel(dw) fit measured at dw 26/29). If D-R1 breaks
> at pass scope the number re-opens (+143,104 B) but stays inside
> the 0.5-2 MiB class.

Two subsidiary recommendations: (i) record the 2^20 rig Tier Z pass
(576,056 B) as the U-AG-B1 Tier-Z engineering gate alongside the
Tier N 294,136 B row; (ii) the interim per-layer line "Tier Z <=
512 KiB/layer unfolded" should be retired at the freeze (its own
corridor top, 529,152 B = 516.75 KiB, already pokes 4.75 KiB above
it — a latent A1 inconsistency this lane flags; the binding number
is now the pass number).

## 4. P2 split-proof pricing (ZK_GAP_OPTIONS Section 6 questions (a)-(c))

### 4.1 Question (a): the terminal-claim split — DERIVED (verified, not assumed)

**Claim FP-L3.** Under the reduced protocol at pass scope (CR-L4
batching, F-IF1.6 draws, group map in h0_agg), the joint matmul
instances' terminal claims split cleanly onto the two commitment
groups: the activation-group batched opening is a
public-coefficient combination of activation-tensor MLE claims
ONLY, and likewise the weight group. *Derivation.* (i) Each
terminal claim of the FD-L2 joint matmul references exactly ONE
tensor — MLE(A)(r_l, rx, r*) and MLE(C)(r_l, rx, ry) reference
stacked activation tensors, MLE(W)(r_l, r*, ry) the stacked weight
tensor; there is no mixed-tensor terminal (the sumcheck's mixing
lives in the ROUND transcripts, not the terminals). (ii) CR-L4a's
mu batch acts per tensor (many points -> one point for the SAME
tensor) — no cross-tensor object is created. (iii) CR-L4b's nu is
drawn PER GROUP (nu_g, F-IF1.6), so the cross-tensor RLC never
spans groups; the batched claim for group g mentions tensors of g
only. (iv) The assignment of tensors to groups is the h0_agg-bound
group map (FP-L2/A6), so no claim can migrate after the draws. ∎
Status: **[PROVEN*]** — spike **FPP-1a** (clean split verifies at
toy scale: each group's batched claim recomputed exactly from its
own tensors), **FPP-1b** (the split does not weaken binding: single
tampered weight position rejects), **FPP-2** (contamination is
detected). ZK_GAP_OPTIONS' "looks mechanical, but unverified" is
hereby VERIFIED, with the conditions named: nu per group; group map
inside h0_agg; slot-complete checks (I-3/R-FC4) at every batched
claim; and the E-O2 one-batched-opening rule read per GROUP — the
second proof is the rule's one justified exception, already priced
inside the W-C Tier N base.

What does NOT split, priced honestly: the matmul and terminal-batch
ROUND polynomials are functions of both sides — under P2 they carry
weight functionals and are therefore masked (4 masked instances;
+1,664 B [MODEL] — Section 3.2). mu is shared across groups but is
a public draw over blinded values (AZ-L2b) — harmless.

### 4.2 Question (b): the weight-independence canary — battery leg AZB-11

**Purpose.** P2's bare activation proof is a bare floor leak of
ACTIVATION functionals; the deployment label asserts it carries NO
weight-dependence. AZB-11 certifies that assertion mechanically.

**What would leak if the invariant broke:** up to dim(z_L) = 90,880
challenge-keyed weight-functional coordinates per pass, in
cleartext, in the nominally-bare-side proof — the FPP-4b exhibit
(the leaked delta IS c_j x (weight column)). Accumulating per pass,
this would silently re-create the exact accumulation catastrophe P2
pays +281,856 B to prevent.

**The canary (three ACCEPT legs + one REJECT leg):**

1. **Static (derive-time, every pass):** every tensor referenced by
   any activation-group batch entry lies in T_act per the h0_agg
   group map, and the activation nu-weight vector has ZERO support
   on any T_W segment. Pure manifest arithmetic. [FPP-2 static leg]
2. **Functional (engine-scale, battery + auditable per deployment):**
   recompute the activation-group batched claim values AND the
   activation floor image from (T_act witness, public challenges)
   alone; both must match the transcript byte-exactly. A weight
   dependence of ANY functional form — linear, migrated-claim, or
   plumbing bug — appears as a mismatch, because the recomputation
   input simply does not contain W. [FPP-2 functional leg, FPP-4a;
   the AZB-7(i) recompute pattern, applied per group]
3. **Perturbation (rigged, battery):** re-run the pass on a rigged
   witness with W perturbed and T_act fixed; the entire bare
   activation-side transcript must be byte-identical. [FPP-4a's
   invariance direction at engine scale]
4. **REJECT direction (F5 pair):** a rigged group-map migration
   (one weight column re-labeled into T_act after the draws) must
   (i) change h0_agg — transcript invalid; and, run with the forged
   map from the start, (ii) fire legs 1-2. [FPP-4b]

ACCEPT = legs 1-3 pass and leg 4 fires as specified. REJECT
semantics: ANY canary failure is deployment-blocking for P2 (the
label "weights private" is void until it passes) — not a warning.
Numbering note: EC's battery is AZB-1..9 and FA's new segment/group
F5 pair collides with EC's AZB-7 (the floor exhibit) — Section 8.3
proposes FA's pair = **AZB-10** and this canary = **AZB-11**.
AZB-11 leg 1 is also the derive-time input AZ-O2/AZB-8 needs at
pass scope (the joint-rank certificate now includes the group-map
separation).

### 4.3 Question (c): weight-side amortization under folding — CONFIRMED

Under IXF/W-C: ONE weight commitment (per model, off the clock —
TARGET_CONTRACT Section 3), ONE masked weight-group evaluation
proof per pass, hence ONE mask surcharge per pass:

> X_weight(pass) = +281,856 B (masked weight floor, F-Z1 corner)
>                + 4 x 416 B [MODEL] (masked matmul/batch instances)
>                = **+283,520 B, once per pass = 8,860 B/layer
>                  amortized**

CONFIRMED — with two boundary statements. (i) The confirmation is
layout-conditional: under W-B the single mixed floor makes the
split impossible (FP-C2) and "amortization" degenerates to "mask
everything" (= P3 price for P2 privacy). W-C is load-bearing.
(ii) The amortization is WITHIN-pass; ACROSS passes the weight
floor is masked every pass by construction, so the accumulation
asymmetry is answered by the mask, not by amortization — the
+283,520 B is a permanent per-pass cost, and spike **FPP-6** shows
why it is not optional: bare weight floors reach naive recovery
rank in ~46,072 passes ≈ 8 days of continuous proving at the 15
s/pass target [naive bound, no margin credited].

### 4.4 The P2 bottom line

> **P2 price = Tier N pass + X, X = +283,520 B ≈ +0.270 MiB**
> [MODEL]: P2 = 505,272 + 283,520 = **788,792 B = 0.752 MiB** per
> FFN complete pass (band 788,408-788,920 + FA's base band).
> Against the activation-only EA-comparable base the same artifact
> reads 352,948 + 152,324 (weight proof + identity, Tier N
> machinery) + 283,520 = 788,792 — i.e. "+0.42 MiB" in
> ZK_GAP_OPTIONS' old accounting frame; the Section 6 guess
> ("Tier N + ~0.3-0.4 MiB") was the right class, and the split is
> now derived, canaried, and cheaper than P3 by 274,304 B.

## 5. The P1 bounded-leak label template

### 5.1 The bound and the margins, per reference shape

P1 (inputs/activations private, weights public) may run the BARE
activation floor under Amendment A1 if the deployment accepts the
stated bound. The bound, exactly (spike **FPP-6**):

| shape | one floor exposes | committed activation coeffs | fraction of naive rank | naive rank-completeness threshold |
|---|---:|---:|---:|---:|
| FFN complete pass | 90,880 constraints | 722,763,776 | 0.0126% | ~7,953 proofs of the SAME pass |
| 2^20 ledger-unit pass | 93,696 constraints | 134,905,856 | 0.0695% | ~1,440 proofs of the same pass |

(EC 7.3's layer-scale anchor ~283 reproduces from the same formula
— the folded pass RAISES the naive threshold ~28x at FFN because
the stacked witness grew 32x against one floor: folding made the
P1 leak proportionally SMALLER.) Honesty rules carried verbatim:
the thresholds are naive linear-algebra upper bounds that confer NO
margin (WSMD 1.1 — the recursed case's digit structure is graded in
the adversary's favor); the bound counts floor constraints ONLY,
which requires the AZ-L1/L2 masks ON (surfaces 1-2 closed; the
mask-delta bytes are in the P1-label row of Section 3.3) and the
AZB confinement battery green (the floor is exactly the predicted
object, nothing more).

### 5.2 Conditions the label depends on (all enforceable)

1. ONE aggregate proof per pass, ever — re-proof requests served
   from cache (the one-proof-per-witness rule at pass granularity;
   fresh proofs of the same pass add 90,880 fresh constraints each
   and walk toward the threshold).
2. AZ-L1/L2 masking ON for surfaces 1-2 (P1-label mode is "bare
   FLOOR", not "bare transcript").
3. Weights public and committed (W-C; the weight-group proof runs
   bare — nothing private in it).
4. AZB battery green, including AZB-7 (floor recompute/confinement)
   and AZB-10/11 (map edges + canary — they protect the SEMANTICS
   of the bound).

### 5.3 The deployment-label text (normative template)

> **Privacy mode P1 (declared): inputs/activations private; weights
> public.** This deployment runs the Tier N (bare-floor) aggregate
> path on the activation group. Quantified disclosure: per 32-layer
> pass, the evaluation proof's recursion floor exposes exactly
> **90,880 challenge-keyed deterministic linear-constraint values**
> on the ~7.23 x 10^8 committed activation coefficients of that
> pass — 0.013% of naive recovery rank; naive rank-completeness
> would require ~7,953 fresh proofs of the SAME pass, and this
> deployment issues at most ONE (re-proofs are served from cache,
> enforced). Every other transcript component is simulatable
> (AGGREGATION_ZK_DESIGN Section 5, masks on; confinement
> certified by the AZB battery). This is a declared, bounded
> partial disclosure under TARGET_CONTRACT Amendment A1 — the
> artifact is NOT zero-knowledge with respect to the floor object;
> deployments requiring zero activation disclosure must run
> Tier Z / P1-strict (+272,640 B: Section 3.3).

(2^20-shape variant: replace the three numbers by 93,696 /
1.35 x 10^8 / ~1,440.)

## 6. E4-wrap endgame pricing under folding

E4 (ZK_GAP_OPTIONS Option B's mechanism: pay bytes so the masked
floor fits) is priced per EVALUATION PROOF. Folding therefore
changes not the mechanism but the COUNT:

| configuration | masked floors (wraps) per pass | surcharge/pass | full-ZK pass total |
|---|---:|---:|---:|
| unfolded, per-layer E4 (ZK_GAP_OPTIONS 4B) | 32 | 5.50-7.50 MiB | 14.15-16.15 MiB |
| folded, P3 (both groups) | 2 | 0.529 MiB | **1.014 MiB** |
| folded, P2 / P1-strict (one group) | 1 | 0.263-0.270 MiB | 0.745-0.752 MiB |

**One wrap per pass per private group is the endgame**: folded
Tier Z beats the unfolded per-layer E4 path by **14.0-15.9x** at
identical privacy. The three situations where per-layer E4 still
earns its keep, priced:

1. **Layer-granular deployments** (single-layer artifacts at the B1
   gate unit — per-layer attestation, partial re-verification,
   debugging): the folded pass does not exist there; per-layer E4
   at 463,616-529,152 B stays the only full-ZK per-layer artifact.
   (With the A1 bookkeeping note of Section 3.6: its corridor top
   sits 4.75 KiB above the interim 512 KiB line.)
2. **A k-way weight-group split at 8B** (if F-N4's 0.05-bit
   headroom closes and the relaxed-e0 relief fails, the weight
   commitment splits into k groups): each extra group adds one
   identity + one masked proof = 5,680 + 52,692 + 375,808 =
   +434,180 B [MODEL]. P2(k) = 788,792 + (k−1) x 434,180: k = 2 ->
   1.166 MiB, k = 3 -> 1.581 MiB — the freeze line re-opens at
   k >= 2 but the A1 class holds through k = 3; the unfolded
   per-layer P2 class (~0.64 MiB/layer -> ~20.5 MB/pass [MODEL])
   is never approached. Folded E4 wins categorically at pass scope
   for every plausible k.
3. **A future streaming variant** (out of scope; FP-C1 binding): a
   sequential fold would carry its Tier Z analysis per step — E4
   pricing there is 31x this section's ordering surface, priced
   only if that requirement ever lands.

If escape E5 (a ZK opening for balanced-digit Ajtai commitments at
q31, <= ~100 KB) ever lands, both surcharge columns collapse toward
zero and Tier Z re-converges to Tier N + mask deltas — the A1
reversibility note carries over unchanged (the freeze is a ceiling,
not a floor).

## 7. Verdict row

**FB lane verdict:**

> **The fold/mask lemma HOLDS for the adopted fold** (FP-L1: one
> floor per group — 90,880/93,952 coords, 14-29x LESS floor-class
> exposure than 32 unfolded proofs; accumulation law unchanged;
> FP-L2: mask-then-fold by construction, with the group-map hash
> edge as the one new load-bearing privacy edge), with its failure
> modes fenced (FP-C2: W-B has no partial-privacy mode; FP-C1:
> cleartext-per-step folds excluded, binding on streaming
> variants).
>
> **Folded Tier Z pass numbers (FFN complete, W-C, exact-digit,
> kappa 11) [MODEL]:** P3 = **1,063,096 B = 1.014 MiB** (worst band
> 1.026 MiB); P2 = **788,792 B = 0.752 MiB** = Tier N + 283,520 B;
> P1-strict = 781,240 B; P1-label = 508,600 B; 2^20 rig pass
> Tier Z = 576,056 B. All inside Amendment A1's 0.5-2 MiB class.
> **A1 freeze recommendation: 1,114,112 B = 1.0625 MiB** per
> 32-layer FFN pass (P3 scope, Section 3.6's text), conditions
> F-Z1 (masking corner at pass floors — spike-checked ~0.7 b,
> one-sided vs EB's relaxed line), F-Z2 (extraction at the masked
> bound), F-O2 (kel measurement).
>
> **P2 questions closed:** (a) the terminal split is DERIVED clean
> (FP-L3; conditions: nu per group, group map in h0_agg,
> slot-complete checks) — "looks mechanical" is now VERIFIED with
> positive and negative spike legs; (b) the weight-independence
> canary is specified as battery leg AZB-11 (static support +
> functional recompute + perturbation + F5 reject); (c) weight-side
> amortization CONFIRMED under W-C — one commitment, one masked
> opening, +283,520 B once per pass (REFUTED under W-B).
>
> The unfolded 14-16 MiB class reproduces from this document's
> formulas (32 x 463,616..529,152 B); folding concentrates the E4
> surcharge 10.4-14.2x and the full-ZK pass 14.0-15.9x.

## 8. Exports

### 8.1 To FA / the FINAL merge (constraints and reconciliations)

1. **AZB numbering collision (bookkeeping, fix at FINAL):** FA
   Section 7 labels its new segment-map/group-map F5 pair "AZB-7",
   which EC's battery spec already assigns to the floor
   exhibit/confinement leg. Proposal: FA's pair becomes **AZB-10**,
   this lane's weight-independence canary **AZB-11**; AZB-5's
   freshness unit is restated as the PASS (Section 2.2 row A7).
2. **FP-C2 confirms W-B is privacy-dead for P2** from the floor
   side (independent of F-N4's norm death) — FA's 9.1 item 5
   stands; recommend FINAL record W-C as MANDATORY for any P1/P2
   deployment, not merely recommended.
3. **FP-C1** (no cleartext per-step material) joins the F-C1..F-C6
   condition set as the privacy-side condition on any future
   streaming/sequential fold.
4. FA's Tier Z preview rows (0.65-0.71 / 0.82-0.94 MiB) are
   superseded by Section 3.3 (floor-correction explained in-table);
   the Section 8 verdict-table preview rows should be updated at
   FINAL.
5. **A1 bookkeeping niggle:** the interim "Tier Z <= 512 KiB/layer
   unfolded" line is inconsistent with its own corridor top
   (529,152 B = 516.75 KiB); retire the interim line when the pass
   number freezes (Section 3.6).

### 8.2 To FC / the build round (mask-related extraction hypotheses)

1. **F-Z2 (the one new extraction obligation):** SC-L4's chain at
   the Tier Z groups must tolerate the MASKED floor response — the
   decide check consumes a response with bound ~2^27.3 + mask width
   instead of the bare gamma; verify C-win/C-msis at that bound
   (EB's relaxed line gives ~6 bits of window room — expected to
   pass; this is the extraction-side face of the E4 engineering
   risk). FC's straight-line-over-T_blind property extends: the
   extractor rewinds challenges only and never needs the floor
   mask's randomness (it is prover-internal, FS-with-aborts class —
   Q4.2a' transcription at build).
2. **AZ-O2/AZB-8 at pass scope** now includes the group-map
   separation: the joint-rank certificate should run per group,
   with AZB-11 leg 1's support check as its input (a weight-side
   rank contribution appearing in the activation block is exactly
   the failure both are hunting).
3. The A8 row (floor-mask abort discipline) is the Q4.2a'-class
   composition obligation, floor instance — one lemma, cited both
   places.

### 8.3 To the orchestrator (freeze + doc updates)

1. The Section 3.6 freeze text (with conditions F-Z1/F-Z2/F-O2) is
   ready to paste into TARGET_CONTRACT Amendment A1 at FINAL.
2. ZK_GAP_OPTIONS Section 6 can be updated: questions (a)-(c) are
   settled (VERIFIED / SPECIFIED / CONFIRMED — Section 4); the
   Section 6 P2 estimate "Tier N + ~0.3-0.4 MiB" becomes
   "+0.27 MiB over the W-C Tier N base" (the extra-proof price
   moved into the Tier N base when W-A was rejected).
3. The P1 label template (Section 5.3) and the P2 canary semantics
   (Section 4.2) are the deployment-facing texts; the AZB-10/11
   renumbering needs a one-line ruling.
4. Obligations raised: **F-Z1** (corner re-check in the build
   round's schedule implementation), **F-Z2** (above), **F-Z3**
   (build round: the floor-mask rejection sampler + abort
   discipline + AZB-11 wiring into the derive path).

## 9. Spike output (recorded verbatim)

`python3 scripts/fold_privacy_pricing_spike.py`, 2026-08-06, exit 0
(0.76 s, stdlib only, GF(q31) toy arithmetic + byte/threshold
reproduction):

    OK FPP-1a: P2 split (a) POSITIVE: joint matmul sumcheck over (layer, inner) accepts honestly; terminals land ONE per tensor (MLE(A), MLE(W)); with nu drawn per group, each batched claim is recomputed EXACTLY from its own group's tensors alone — the split is clean, zero cross-terms
    OK FPP-1b: P2 split (a) NEGATIVE: a single tampered weight position rejects under the joint fold — the split does not weaken the matmul binding
    OK FPP-2: canary (b) at the claim layer: a weight functional smuggled into the activation-side batch is DETECTED by both legs — static support check (references a T_W tensor) and functional recompute-from-T_act-alone (value mismatch)
    OK FPP-3a: folded floor accounting: stacking 8/16/32 toy layers into ONE commitment leaves the floor image at dim 6 = ONE proof's image (witness-size-independent, the regrowth-floor law); 32 unfolded proofs would expose 32 x 6 = 192 values — the fold exposes 32x FEWER floor coordinates per pass
    OK FPP-3b: accumulation law at pass shape: rank grows exactly 1/transcript/row-system (1, 64, 128 at t = 1, 64, 128); EXACT witness-row recovery at t = m2 = 128 transcripts (AZ-L3(b) verbatim at the stacked shape); at t = 1 the solution space keeps dim m2 - 1 per row — the ONE-proof leak is bounded, the fold changes the per-proof law not at all
    OK FPP-4a: shipped order (group map inside h0_agg before every challenge): the bare activation floor is recomputed EXACTLY from (T_act, challenges) alone and is INVARIANT under weight perturbation — weight-independence holds by construction (mask-then-fold = the h0_agg edge, FP-L2)
    OK FPP-4b: ATTACK order (group map chosen after the fold challenges): a weight column migrated into the bare activation opening (i) shifts the floor by an EXPLICIT weight functional c_5 * w1 — the P2 privacy break made concrete; (ii) is caught by the recompute canary; (iii) is rejected by the shipped h0_agg group-map edge (changed assignment => changed statement hash) — the F5 pair for FA's group-map row
    OK FPP-5a: 11 recorded totals reproduced from component formulas: descent kel fits, the FFN instance transcript (layer 30,336 -> pass 37,056 = +5 index rounds on 7 of 8 instances, table side exempt), all three eval-proof lines (5,680 + (L-1) x 6,716 + floor x 128), and FA's three pass bases 352,948 / 505,272 / 294,136 B
    OK FPP-5b: corrected masked-floor surcharges at the R-EB4 pass floors: activation +272,640 B, weight +281,856 B, 2^20 +281,088 B (= 3 B/coord x 90,880 / 93,952 / 93,696 coords, no-limb-growth corner [MODEL]) — 13.8-17.6 pct ABOVE the stale +176-240 KB class (whose floors predate R-EB4)
    OK FPP-5c: folded Tier Z pass totals (W-C layout, midpoint deltas): P2 = 788,792 B = 0.752 MiB; P3 = 1,063,096 B = 1.014 MiB; P1-strict = 781,240 B; P1-label = 508,600 B; 2^20 pass = 576,056 B = 0.549 MiB — P2 and P3 both INSIDE Amendment A1's 0.5-2 MiB target class
    OK FPP-5d: unfolded check rows reproduced: Option A pass 32 x 283,392 = 9,068,544 B (8.65 MiB); Option B corridor 463,616-529,152 B/layer (= 283,392 - 81,920 bare floor + 4 B/coord x 512..640-ring masked floor [MODEL]) -> 14.15-16.15 MiB/pass — the ZK_GAP_OPTIONS 14-16 MiB class, from the same formulas
    OK FPP-5e: surcharge concentration: unfolded pays 32 masked floors (5.50-7.50 MiB of surcharge/pass), folded W-C pays TWO (0.529 MiB) = 10.4-14.2x concentration; freeze candidate 1,114,112 B = 1.0625 MiB covers P3 worst-band 1,075,464 B with margin and sits inside the A1 class
    OK FPP-6: recovery-rank margins [naive upper bounds, NO margin credited]: P1 FFN pass — one floor = 90,880 constraints on 722,763,776 committed activation coeffs = 0.0126 pct of naive rank; rank-completeness needs ~7,953 fresh proofs of the SAME pass (2^20 pass: ~1,440; EC 7.3 layer anchor ~283 reproduced). P2 asymmetry: weights re-proven EVERY pass reach naive recovery rank in ~46,072 passes = ~8 days of continuous proving at 15 s/pass — no operational rule can bound it; the weight-floor mask is mandatory in P2/P3, every pass
    OK FPP-7: the E2/E4 masked-floor norm corner at pass floors [MODEL, sqrt(dim) first-order]: e_L<=4 no-limb-growth bound 2^27.27 (act) / 2^27.30 (weight) vs the q/8 line 2^28.00 — the corner SURVIVES at pass scale with ~0.7 b; the limb-growth branch (2^28.70) stays DEAD — the F-Z1 corner condition carries to the pass unchanged, and EB's relaxed validity line (~6 b window margin) only widens it
    OK FPP-8: T_blind at pass scope [MODEL]: descent masks ~3,135 K-el (scaled to dw 29) + instance masks 478 + pads 1,208 + claim segment 128 = ~4,949 K-el = ~619 rings — fits the 4,096-ring T_blind window with >= 6x headroom; zero wire (committed only)
    15/15 OK — all fold_privacy_pricing_spike assertions passed

Reproduction notes: toy field GF(q31) directly (the claim-reduction
spike's small-field incident convention); the FPP-1 sumcheck runs
the FD-L2 joint form at 4 toy layers x 4 inner positions with the
eq kernel inside the sum (degree-3 rounds); the fold toys
demonstrate SPLIT/ORDERING/ACCOUNTING structure, not lattice
binding strength (the SPKZ convention); byte checks reproduce FA's
DOC-lockstep totals from component formulas independently re-derived
in this document (the FFN instance-transcript decomposition
30,336 = (12+12+14)x2x64 + (23+23+23+28+25)x3x64 + 8x4x64 and its
+5-round fold to 37,056 were derived here and match FA's recorded
values exactly — an incidental cross-lane verification of FA's
arithmetic).

## References

1. AGGREGATION_FOLDING_DESIGN.md (U-AG4 FA) — F-IF1 (binding),
   byte tables, floor population export, AZB hash edges.
2. AGGREGATION_FOLDING_SOUNDNESS.md (U-AG4 FC) — F-IF1
   verification, AFS-L8, R-FC2..4, exports to FB.
3. AGGREGATION_ZK_DESIGN.md (U-AG3 EC) — the three surfaces,
   AZ-L1..L4, the floor object and masking grid, AZB-1..9, the
   escape table.
4. ZK_GAP_OPTIONS.md + TARGET_CONTRACT.md Amendment A1 — the
   Option B decision, modes P0-P3, the freeze obligation.
5. AGGREGATION_ENCODING_DESIGN.md (U-AG3 EA) — byte model, D-R2,
   E-O2, the O-8 floor.
6. AGGREGATION_SOUNDNESS_COMPOSITION.md (U-AG3 EB) — R-EB4, kappa
   11, the corrected 283,392 B layer, the relaxed validity line.
7. AGGREGATION_CLAIM_REDUCTION.md (U-AG2 DB) — CR-L4/CR-L5,
   Section 11.
8. AGGREGATION_PARAMS_DESIGN.md (U-AG2 DA) — the regrowth floor,
   mask arithmetic, byte skeleton.
9. WAVE_SHARE_MASKING_DESIGN.md Section 3, PROOF_BYTE_LEDGER.md
   Section 0 — simulator idiom, unit widths.

---

*Changelog: 2026-08-06 — first edition (U-AG4 FB lane). Fold/mask
lemma FP-L1 (one floor per group, 14-29x exposure reduction,
accumulation law fold-invariant) + FP-L2 (mask-then-fold by
construction; A5-A8 privacy edges incl. the group-map edge) with
failure fences FP-C1/FP-C2; Tier Z surcharges re-derived at the
R-EB4 pass floors (+272,640/+281,856 B, corner F-Z1 spike-checked);
Tier Z pass tables (P3 1,063,096 B / P2 788,792 B / P1 508,600-
781,240 B / 2^20 576,056 B) with the unfolded 14-16 MiB check rows
reproduced; A1 freeze candidate 1,114,112 B = 1.0625 MiB; P2
questions (a) VERIFIED (FP-L3), (b) canary AZB-11 specified, (c)
amortization CONFIRMED (+283,520 B once per pass, W-C-conditional);
P1 label template with rank margins (7,953/1,440-proof thresholds,
the 8-day weight-recovery motivator); E4-wrap endgame (one wrap per
pass per private group, 14.0-15.9x vs unfolded). Spike
fold_privacy_pricing_spike.py 15/15.*
