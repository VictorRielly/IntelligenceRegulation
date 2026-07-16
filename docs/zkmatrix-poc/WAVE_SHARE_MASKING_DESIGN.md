# Wave-Share Masking Design (Z1): Closing the Multi-Wave Partial-Scalar Leak

Status: DESIGN ROUND ONLY (tranche U-Z, item Z1, 2026-07-15). This
round ships NO code and NO spike by the tranche's own discipline
("paper-first, implementation gated on review" — PROGRESS_UZ.md Z1);
that is one step MORE conservative than the M4_LOOKUP_ZK_DESIGN
precedent, which carried a machine-checked spike. The grading
consequence is stated in Section 0. Spec: codex-audit-2026-07-14
FINDINGS.md C-02 and REMEDIATION_PLAN.md Phase 2. Companions:
RANGE_AGGREGATION_DESIGN.md Section 2b (the multi-wave architecture
being masked), PROGRESS_UR.md S0-S2 (the as-built wave mechanics and
every measured number cited here), M4_LOOKUP_ZK_DESIGN.md (the
Libra-class masking precedent whose vocabulary — exposures, pads, rank
certificates, F5 pairs, one-time mask freshness — is reused
throughout), SOUNDNESS_REFERENCE.md Sections 0 and 7 (grading legend,
hash-edge row format).

**The verdict in one paragraph.** The audit's C-02 leak is real and is
sharpened in Section 1 to an exact identity: every per-wave pin partial
is a public-coefficient linear functional of that wave's private
committed coefficients, 9(W−1) fresh base-field equations per proof
beyond the totals (6,021 at the measured 2^20 shape, W = 670), and the
equations ACCUMULATE across proofs of the same witness — the same
"bounded but growing" shape the R1 history killed. The fix is NOT a
Libra-style polynomial mask (the wave shares are scalars, not
polynomial evaluations — Section 2.0 states exactly where the U-K5
techniques do and do not apply): it is a committed one-time pad on the
share vector. Uniform additive pads e_{j,w} with Σ_w e_{j,w} = 0 are
committed in shared pad commitments bound by h0_link BEFORE any
challenge; each wave's ct-round proves its masked share σ̃ =
functional + pad against committed material; one extra closing
ct-round proves the nine zero-sum claims Σ_w pad = 0 exactly. The
masked share vector is then EXACTLY uniform on the coset
{Σ = total} — a finite one-time-pad statement, not a rank-genericity
argument — so the multi-wave transcript collapses to the leakage of
the monolithic single-round transcript, which the U-K5 machinery
already simulates. A free rider surfaced by the analysis: the zeta
slot-constancy family's per-wave shares are IDENTICALLY ZERO for every
honest witness, so their reveal wire (48 of the ~57 reveals per wave)
can be deleted outright and replaced by per-wave zero claims —
strictly stronger soundness, −72% masked-transcript bytes at 2^20.
Priced cost of the whole construction at the S2-measured shapes:
+0.025 dce/el on the 1.335 dce/el pin floor at 2^20 (+1.9%),
+0.8%-class on the C-03 full-wire ledger, net NEGATIVE on the
masked-descent byte ledger (0.512 → ~0.14 B/el at 2^20). What does
NOT close here: the C-03 proof-size wall (orthogonal, Phase 3), and
one new engine pattern (a commitment opened in many rounds) whose
composition lemma is an explicit OBLIGATION with a priced fallback.

## PROGRESS

- [x] Section 0: scope, symbols, and the grading convention for a
      spike-less round
- [x] Section 1: the leak, sharpened (exact identities, counts at the
      measured shapes, accumulation)
- [x] Section 2: the construction (pads, shared pad commitments, the
      zero-sum round, the zeta deletion, hash edges)
- [x] Section 3: the simulator for the complete multi-wave transcript,
      component by component, graded
- [x] Section 4: soundness non-interference, graded
- [x] Section 5: the rank/leakage/recovery battery spec ([Z1-a..i])
- [x] Section 6: cost delta, priced against the S2/S3 measured tables
- [x] Section 7: what could kill this / what this design does NOT close
- [x] Section 8: implementation-tranche sketch and freeze-row candidate

## 0. Scope, symbols, and the grading convention

### 0.1 What is being masked

The `ffn-chain layer` rig (PROGRESS_UR.md S1, `ring_matmul.rs`
`ffn_layer_run`): one per-layer instance, multi-wave q31 commit, ONE
masked descent pair, with every cross-wave linear claim routed through
`split_claims_prover` / `split_claims_verifier`
(`ring/ct_engine.rs:1643-1702`). Frozen constants used throughout:
commit shape {kappa 8, n_r 26, msg_r 8} (so one commitment carries
msg_r · D = 8 · 128 = 1024 committed base-field coefficients), C2 wave
capacity 134 at that shape with data cap 76 (LKP-9 freeze row;
PROGRESS_UR.md S2), UR1_PIN_COPIES = 9 psi copies of the pin batch,
zeta family at the frozen link width w = 11 → l = 24 rows per family,
two families (Y, UP) → 48 zeta shares per chunk wave, 9 + 48 = 57
reveal shares per wave ("12 B x ~56 shares/wave", PROGRESS_UR.md S2).
Measured wave counts: 43 / 168 / 670 at 2^16 / 2^18 / 2^20
(PROGRESS_UR.md S2 table).

OUT of scope, recorded honestly: (a) the block chain (B = 1020) —
it runs one round per block and never splits claims; its reveal
families (`link_reveal_y`) are a pre-existing single-round trust class
handled under Z2's legacy-arm labeling, not a wave-share leak; (b) the
S3 scope notes that predate this design (range-witness pad coverage,
multi-table statement typing); (c) chain-wide ZK composition beyond
proof-of-protocol (the standing R1.3/B.2 honesty note).

### 0.2 Symbols

- **W** — wave count of the layer plan; **w** a wave index.
- **σ_{j,w}** — the TRUE partial ct scalar of split claim j in wave w
  (what `split_claims_prover` reveals today); **T_j** its public
  total, with Σ_w σ_{j,w} ≡ T_j (mod q).
- **e_{j,w}** — the new pad: a uniform Z_q scalar committed
  pre-challenge, with Σ_w e_{j,w} ≡ 0.
- **σ̃_{j,w} := σ_{j,w} + e_{j,w} (mod q)** — the masked reveal.
- **pad commitment** — an ordinary BDLOP commitment at the layer shape
  whose 1024 message coefficients hold pads, wave-major.
- **the closing round** — one extra ct-round over the pad commitments
  proving Σ_w e_{j,w} = 0 for each j (public zero scalars).
- **Exposure / pad** — as in M4_LOOKUP_ZK_DESIGN Section 0: an
  exposure is a transcript value the verifier sees; a pad is a
  committed uniform degree of freedom; hiding claims are statements
  that exposures are full-rank (here: bijective) images of pads.

### 0.3 Grading in a spike-less round

SOUNDNESS_REFERENCE's [PROVEN] requires a complete argument AND a
machine check. This round is forbidden code, so NEW claims here can
carry at most:

- **[PROVEN*]** — "proven on paper": a complete elementary argument is
  given in this document (one-time-pad on a finite coset, a counting
  identity, an exhibited attack); the machine check is OWED and is
  named as a specific Section 5 battery leg. [PROVEN*] must be
  promoted to [PROVEN] or demoted, leg by leg, when the
  implementation tranche lands.
- **[SKETCH]** — argued here in full but structurally dependent on a
  composition/transcription step (the M4_LOOKUP_ZK_DESIGN usage).
- **[MODEL]** / **[OBLIGATION]** — as in the soundness reference.

Imported claims keep their recorded grades (e.g. the U-K5 descent HVZK
is [PROVEN at engine scale] per M4_LOOKUP_ZK_DESIGN Section 4's build
update; the ct-round HVZK family is the [PROVEN] machinery of
SOUNDNESS_REFERENCE Section 3.2 + Q4_LEMMAS R1).

## 1. The leak, sharpened (the Q4.3d discipline)

C-02's finding, restated as exact identities with classes from the
M4_LOOKUP_ZK_DESIGN Section 1 taxonomy (recoverable-witness-image vs
aggregate-statistic).

### 1.1 The pin-share identity

For psi copy j and wave w, the revealed partial is

    σ_{j,w} = Σ_{i ∈ wave(w)} ct( P_{j,i,s} , msg_i[s] )        (1)

(`split_claims_prover`, ct_engine.rs:1651-1664), where the weight
polynomials P_{j,i,s} are PUBLIC: psi_j folded through the pin terms'
K weights by `pin_claims` / `pack_functional` (ring/lookup.rs:321-385)
— psi is transcript-derived, the pin-term weights are Lagrange rows
L_{z*} and challenge powers, all verifier-computable. The private side
msg_i is the wave's committed message coefficients: Y slot constants,
dense X offset codes, m columns, mask and blinder columns. Equation
(1) is therefore ONE public-coefficient linear measurement of the
wave's private data per (copy, wave) pair.

Counts at the measured shapes (PROGRESS_UR.md S2: W = 43/168/670):

| shape | pin shares 9W | new dims beyond totals 9(W−1) |
|---|---:|---:|
| 2^16 | 387 | 378 |
| 2^18 | 1,512 | 1,503 |
| 2^20 | 6,030 | **6,021** |

The audit's "roughly six thousand extra base-field measurements"
(C-02) is the 2^20 row. The 9 totals themselves add nothing: T_j =
Σ_rows psi_j[row] · pin_value[row] is a public function of the pinned
values already sent in the descent transcript, and those are
simulatable — the U-K5 masking made every pinned value uniform on its
check variety ([PROVEN at engine scale], M4_LOOKUP_ZK_DESIGN Section
4). So the ENTIRE leak delta of the multi-wave construction over the
monolithic round is the 9(W−1)-dimensional share quotient.

Class: **aggregate-statistic with LINEAR ACCUMULATION**, the exact
shape M4_LOOKUP_ZK_DESIGN Section 1 graded for v^X/v^Y — and the shape
the R1 history killed. Accumulation is real because the wave plan is a
pure function of the shape (D-2: `plan_waves` is deterministic), so
every fresh proof of the same tensors re-partitions identically while
psi, alpha, z* are fresh: P proofs yield 9(W−1)P independent-generic
equations against FIXED per-wave unknown vectors. Per wave the touched
support is ~2 · 1565 ≈ 3.1k coefficients (X̂ and Ŷ reads of the leaf Q
pin at ~1565 el/wave), so EXACT recovery of the layer's activations by
plain linear algebra needs ~350 proofs of the same witness at every
shape [MODEL — the ratio s_w/9 is shape-invariant]. Two honest
sharpenings, both directions: (i) 350 is an UPPER bound on the
adversary's cost — the witness entries are int8-structured, so integer
programming/lattice decoding can undercut the rank threshold; no
safety margin should be read into 350 [MODEL]; (ii) a single
transcript already hands over 6,021 measurements of private
activations at 2^20 — by the house R1 principle (a deterministic
witness image is a leak unless proven otherwise) the construction is
non-ZK at ONE proof; the accumulation argument is only what makes the
kill quantitative.

### 1.2 The zeta shares: identically zero, hence leakless — and deletable

The zeta slot-constancy family (the E2 machinery of
SOUNDNESS_REFERENCE Section 8 item 3, streamed per wave by
`ZetaStream`) reveals, per chunk wave, 2l = 48 partials of claims
whose public total is 0. Each share is a fresh-XOF-weighted (zeta)
linear functional of the wave's JUNK coordinates — the non-constant
CRT-slot coordinates of the packed Y/UP chunks. For every honest
witness the H3 packer zeroes those coordinates, so

    every honest zeta share = 0, identically.                   (2)

Grade [PROVEN* — linearity plus junk ≡ 0 by packing; canary owed,
leg Z1-f]. Consequence one: the zeta wire leaks NOTHING today (a
constant is trivially simulatable) — C-02's leak is the pin family,
not zeta. Consequence two, the free rider: a wire that always carries
zero should not exist. Section 2.4 deletes it and fixes each wave's
zeta share scalar to the constant 0, turning the layer-wide sum gate
into per-wave zero claims — strictly MORE constraints on a cheating
prover, and −576 B per chunk wave of transcript.

### 1.3 What the verifier learns, side by side

| transcript value | today (unmasked split) | class |
|---|---|---|
| pin totals T_j (9) | public functions of U-K5-simulatable pinned values | not a leak [imported PROVEN at engine scale] |
| pin partials σ_{j,w} (9W) | equation (1): 9(W−1) fresh linear measurements of private activations per proof, accumulating across proofs | **the C-02 leak** — aggregate-statistic, linear accumulation; single-transcript at rigged shapes (Section 5's Z1-a) |
| zeta partials (48/chunk wave) | identically 0 by (2) | not a leak [PROVEN*], and deletable |
| per-wave ct-rounds, descents, quads | unchanged by splitting | the existing [PROVEN] / [PROVEN at engine scale] machinery |

The design target is therefore exact: make the σ̃ vector carry ZERO
information beyond the totals — collapse row 2 into row 1.

## 2. The construction

### 2.0 Where the U-K5 precedent applies, and where it does not

M4_LOOKUP_ZK_DESIGN masked POLYNOMIAL transcripts: round polynomials
(Libra Construction 1 small masks), boundary evaluations (vanishing-
factor LDE masks), and hypercube-valued tops/leaves (blinding leaves).
Its techniques that carry over here VERBATIM: (a) all mask material
committed BEFORE the statement hash's challenges, with an F5 pair per
new edge; (b) the "solved pad" pattern — one pad degree of freedom is
not drawn but solved to satisfy a public constraint (there: the
blinder mass equality; here: the last pad of each claim solves the
zero-sum); (c) one-time freshness — reused masks subtract out (its
E3Z-N3; our Z1-h); (d) exposure-vs-pad rank accounting as the hiding
argument, certified at derive time.

What does NOT apply, and why this is a different (easier) problem: the
wave shares are SCALARS, one per (claim, wave), constrained by a
single public linear relation (the sum gate). There is no polynomial
structure to preserve, no hypercube agreement to maintain, no
half-Boolean boundary obstruction (O-1) and no hypercube-value
obstruction (O-2). The correct tool is the degenerate, exact case of
the Libra counting: a one-time pad on the coset {Σ = T}, where the
hiding statement is not "full rank generically" but "a bijection,
unconditionally". The hard part is elsewhere — proving Σ pads = 0
against COMMITTED pads across rounds that can each only see their own
wave's commitments. That cross-round grounding problem has no U-K5
analogue and drives every structural choice below.

### 2.1 P1 — the pads

For every linear claim family routed through the splitter with policy
`Padded` (the pin claims; policy vocabulary in 2.5), for each psi copy
j ∈ [9] and each wave w the claim touches: draw e_{j,w} ∈ Z_q uniform,
free for the first k_j − 1 touched waves, and SOLVE the last:
e_{j,last} := −Σ_{w<last} e_{j,w} (mod q) — the M4 solved-pad pattern.
By construction Σ_w e_{j,w} ≡ 0, so completeness of the existing sum
gate is untouched: Σ_w σ̃_{j,w} = Σ_w σ_{j,w} = T_j (mod q). Reveals
are centered mod q exactly as today (`center_i128`); a uniform σ̃
always has a centered representative, so — unlike every mask family
in U-K5 — there are NO degenerate draws and NO restart guards.

Pads are per-claim-per-wave: 9 per pin-bearing wave (at arm A every
wave is pin-bearing: the plan co-locates each (Y, UP, Z) triple, so
every chunk wave holds a Y commitment below `pin_hi`, and the
remaining waves hold X or lookup material — `ring_matmul.rs` budget
closure). Totals: 387 / 1,512 / 6,030 pad scalars at 2^16/2^18/2^20.
The S3 range arm adds NO pads: silu and range pins share the ONE psi
batch and its 9 claims (PROGRESS_UR.md S3: "the per-wave pin surcharge
does NOT double").

### 2.2 P2 — shared pad commitments, bound pre-challenge

Pads are packed wave-major, 9 per wave, into ordinary BDLOP
commitments at the layer shape: 1024 coefficients each → 113 waves per
pad commitment → ceil(9W/1024) = 1 / 2 / 6 pad commitments at the
measured shapes. Two placement rules, both load-bearing:

1. **Pad commitments are statement material**: committed alongside
   the data and lookup commitments and bound by h0_link BEFORE any
   challenge is drawn (alpha, psi, every per-wave h0, the closing
   round's h0) — the D-4 streaming-binding pattern, and the exact
   analogue of U-K5's "all mask and blinder commitments enter h0_lkp".
2. **Wave w's round list gains its pad commitment**: idxs =
   wave ∪ {pad_cm(⌊w/113⌋)} ∪ g-range, derived by the verifier from
   the public plan (D-2 — nothing prover-chosen enters the layout).
   The C2 gate counts it: the frozen data cap 76 becomes 75, subject
   to re-derivation by `derive_ct_round_params`' own assert, which
   remains the single enforcement gate (D-3). Cost priced in
   Section 6.

The same commitment therefore appears in ~113 wave rounds plus the
closing round. This is the one genuinely NEW engine pattern in this
design; its soundness is per-round (binding is round-independent), and
its ZK composition obligation is stated in Sections 3.4 and 7.2 with a
priced fallback that avoids it entirely.

### 2.3 P3 — the amended share claims and the zero-sum closing round

Wave w's share of claim j becomes

    functional_w(msgs) + 1 · e_{j,w} = σ̃_{j,w}                  (3)

— the verifier-rebuilt share claim (`split_claims_verifier` +
pad policy) gains ONE msg_coeffs entry reading pad coefficient
(w mod 113)·9 + j of the wave's pad commitment with weight 1, and its
scalar is the masked reveal. No new claim, no new g-slot: the pin
share already consumes its g-slot; the pad term rides the same claim.
The sum gate is unchanged: Σ_w σ̃_{j,w} ≡ T_j (mod q).

The **closing round**: one additional ct-round whose commitment list
is the pad commitments plus its own g-groups (6 + 2 = 8 commitments at
2^20), proving the nine EXACT linear claims

    Σ_w e_{j,w} = 0        (public zero scalar, j = 1..9)       (4)

— each an all-ones-per-copy coefficient read across the pad
commitments, one g-slot each (9 slots → 2 g-groups at msg_r = 8). No
psi compression is involved: (4) is not a batched row family but nine
exact single claims, so no new 2^-31-per-copy edge opens. The closing
round may equivalently be folded into the last wave's round (its pad
commitment is already there; the other pad commitments join that
round's list) — an engine choice with identical pricing; this document
specifies the standalone round for auditability.

Soundness chain, previewing Section 4: per-wave rounds force (3),
the closing round forces (4), the sum gate forces Σσ̃ = T_j; adding
(3) over w and subtracting (4): Σ_w functional_w = T_j — EXACTLY the
unmasked guarantee. The pads cancel identically; a δ ≠ 0 pad sum is
the one new forgery lever and (4) is the leg that closes it — the
battery must demonstrate both directions (Z1-d).

### 2.4 P4 — the zeta wire deletion

By identity (2) the honest zeta share is the constant 0. The design
therefore REMOVES the zeta reveal wire: the verifier builds every
per-wave zeta claim with scalar 0 (policy `ForcedZero`), sends
nothing, and the per-wave ct-round proves zeta-functional_w(junk) = 0
directly. The layer-wide per-row sum gate (`zeta_sums`) becomes
vacuous and is retired with the wire.

- Completeness [PROVEN* — identity (2); canary Z1-f]: honest junk
  coordinates are zero per wave, not merely in aggregate.
- Soundness: per-wave zero is STRICTLY stronger than sum-zero — a
  cheating prover must now survive every wave's fresh zeta rows
  locally; the 2^-w-per-row point-mass argument
  (SOUNDNESS_REFERENCE 6.2/E2) applies per wave unchanged.
  Monotone strengthening [PROVEN*].
- Fragility flag, recorded: any future packing that legitimately
  leaves nonzero junk breaks COMPLETENESS here, loudly (honest
  proofs reject). A derive-time canary asserting junk ≡ 0 at pack
  time (Z1-f) converts silent drift into a named failure.
- Yield: −48 reveals × 12 B = −576 B per chunk wave, the dominant
  term of the masked-transcript ledger (Section 6.2).

The pin family CANNOT use `ForcedZero` — its shares are genuinely
value-carrying (equation 1); it takes the pads. The splitter's policy
enum is exactly {Padded, ForcedZero, Revealed}, with `Revealed`
requiring a per-family leakage waiver graded in this document's
style — the default is Padded, and the as-built behavior (Revealed,
no waiver) becomes a compile-away legacy mode for the Z1-a baseline
leg only.

### 2.5 Transcript order and hash edges (SOUNDNESS_REFERENCE Section 7 format)

New structural rule, stated once (the U-K5 rule, one level up): **all
pad commitments enter h0_link, and pads are one-time — fresh per
proof** (reuse subtracts: two proofs sharing pads reveal σ − σ' across
proofs; battery Z1-h).

| challenge | drawn from | must follow | attack if violated | pinned by (planned) |
|---|---|---|---|---|
| h0_link (layer statement hash) — Z1 scope note | — (a hash, not a draw) | now binds the pad commitments alongside data/lookup/mask/g commitments | a pad commitment outside h0_link can be SWAPPED between the wave rounds and the closing round: present pads summing to δ ≠ 0 to the waves and a different zero-sum set to the closing round — any pin total shifts by δ and a false claim ACCEPTS | [Z1-c] F5 pair |
| c_w (per-wave round challenge) | XOF(h0_w), h0_w = XOF(lkp state, wave index, wave list INCLUDING the wave's pad commitment) | the wave's pad commitment and the masked reveals σ̃ | pads/σ̃ chosen after c_w absorb a claim defect — the R1.2 pad-after-challenge shape lifted to wave shares; also the g-mask cross-use forgery class if the pad commitment identity is not in h0_w | [Z1-c] + [Z1-e] re-runs |
| c_z (closing-round challenge) | XOF(lkp state, closing tag, ALL pad commitments) | every pad commitment | the zero-sum "proven" against a pad set other than the one the waves read | [Z1-c] (same pair, closing direction) |
| psi (pin batch) — scope note | unchanged (M4_LOOKUP_DESIGN E4-N1 edge) | pad LAYOUT precedes everything (plan-derived); pad VALUES are drawn independent of psi | none new: the pad term is verifier-added public structure; the pad indexed (j, w) is "the pad for copy j's wave-w share" — a public position, not a psi-dependent object, so no circularity | E4-N1 re-run under masking |

Restart conditions: NONE (Section 2.1). Derive-time canaries instead:
pad count/layout re-derived independently by the verifier from the
plan; pads-cover-exposures counting per Section 3.1.

### 2.6 Alternatives considered and rejected (each priced)

The remediation plan's Phase 2 lists three candidate shapes; all were
worked, and the chosen construction is (a) with a structural twist.

1. **Per-wave pad commitments** (one per wave, living in its wave):
   avoids the shared-commitment pattern for the SHARE claims, but the
   zero-sum (4) then spans ~670 commitments — past any round's C2
   capacity — forcing a 2-level closing tree whose intermediate
   partial sums leak subset sums of σ unless double-masked, and whose
   closing rounds re-open every pad commitment anyway (the multi-round
   pattern returns) PLUS +1024 dce per wave: +0.65 dce/el at 2^20,
   26x the chosen variant's committed cost. Rejected on cost; kept as
   the fallback if the shared pattern fails review (Section 7.2).
2. **Pads in the waves' existing g-groups** (the R1 pad-slot
   precedent): zero new commitments for the shares, but the zero-sum
   spans ~1,340 per-wave g commitments — the closing tree re-opens all
   of them, strictly worse than option 1's wire cost. Rejected.
3. **Tree/accumulator aggregation of the global claim without
   per-wave right-hand sides** (remediation option 3 / "commit the
   partials"): each wave's share scalar committed instead of revealed
   is ISOMORPHIC to option 1 (the committed scalar is the pad-carrier)
   — same tree, same costs. Rejected as a disguise of option 1.
4. **Structured zero-sum pads** (telescoping e_w = s_w − s_{w−1},
   PRF-derived pads): kill the zero-sum proof but require cross-wave
   reads or unverifiable derivations — exactly the grounding problem
   again. Rejected.

The chosen shape — pads centralized in ceil(9W/1024) shared
commitments, each opened by ~113 wave rounds and one closing round —
is the minimal instance of the unavoidable cross-round object: 6
commitments carrying the entire cross-wave structure, at +0.008 dce/el
and one extra round.

## 3. The simulator for the complete multi-wave transcript

The claim: the masked multi-wave layer transcript is HVZK — a
simulator holding only the statement (commitments, table digests,
shape, the public plan) produces transcripts indistinguishable from
honest ones. The argument is component-by-component in the
AUTOMORPHISM_GATE_DESIGN Appendix B.2 / M4_LOOKUP_ZK_DESIGN Section 4
style, over the verifier's COMPLETE view — the remediation plan's
explicit demand ("a simulator for the entire composed transcript, not
one ct-round in isolation").

**What the verifier sees, in transcript order:**

1. The statement: all commitments (X, Y/UP/Z, lookup m/mask/blinder,
   per-wave g's, PAD commitments), h0_link.
2. The lookup transcripts: both masked descents (silu, and range at
   arm R), including every pinned value (G_j hypersums, mask openings,
   aggregate leaf pins).
3. psi (derived), the 9 pin totals T_j (derived from 2).
4. The masked share reveals σ̃_{j,w} — 9 per wave.
5. Per wave w: h0_w (derived), then the wave's ct-round proof: masked
   openings (z, w1) of the wave's data + pad + g commitments, g-masked
   claim material for the 9 pin-share claims (3) and the zeta zero
   claims, R1-padded quadratic (Hadamard) claims.
6. Zeta reveals: NOTHING (the wire is deleted).
7. The closing round: a ct-round proof over the pad commitments for
   the nine public-zero claims (4).

**The simulator**, S1..S6 matching the view:

- S1 commit to garbage in every commitment (MLWE hiding), derive
  h0_link.
- S2 run the U-K5 lookup simulator for both descents (uniform samples
  + forced values; witness-free).
- S3 derive psi and the totals T_j from S2's pinned values (public
  functions).
- S4 sample the share vector σ̃_{j,·} UNIFORM ON THE COSET
  {x ∈ Z_q^{k_j} : Σ x = T_j}: k_j − 1 coordinates uniform, the last
  solved. (Identical in shape to the honest prover's solved pad —
  the varieties coincide, the M4 component-3 pattern.)
- S5 per wave, run the ct-round simulator (the engine's existing
  [PROVEN] machinery) on the claims built from S4's scalars and the
  public zeta-zero claims.
- S6 run the ct-round simulator for the closing round (public zero
  scalars, no reveals).

### 3.1 The pad-coset lemma (the load-bearing new step)

For each claim j: the honest reveal vector is σ̃ = σ + e where σ is
FIXED (given the witness and challenges) with Σσ = T_j, and e is
uniform on the subgroup H = {Σ e = 0} ≤ Z_q^{k_j}. The map
e ↦ σ + e is a bijection from H to the coset σ + H = {Σ x = T_j}.
Hence σ̃ is EXACTLY uniform on that coset, independent of σ — i.e. of
the witness — and jointly independent across j (pads are drawn
independently per claim). S4 samples from precisely this
distribution: the real and simulated share vectors are EQUAL in
distribution, not merely computationally close.

Grade: **[PROVEN*]** — a finite one-time-pad statement (elementary
group theory; the degenerate exact case of the Libra Thm 4.1 counting:
free exposures per claim = k_j − 1 (the sum is forced), pad degrees of
freedom = k_j − 1, and the exposure/pad map is a bijection, not just
full-rank). Machine certificates owed: Z1-b (non-recovery + the
counting canary), Z1-g (accumulation stall).

Corollary (the C-02 closure statement): the masked multi-wave
transcript's distribution is a function of exactly the same objects as
the monolithic single-round transcript — commitments, descent
transcripts, totals — so **splitting a layer into waves adds ZERO
leakage** under this construction. What remains is what the monolith
already leaked, which is what U-K5 already simulates.

### 3.2 Component grades

| # | component | claim | grade |
|---|---|---|---|
| 1 | commitments incl. pad commitments | hiding | [PROVEN] under MLWE (SOUNDNESS_REFERENCE 2.1; the solved last pad is contents-correlation, covered by the same 2.1 note as U-K5's solved blinder) |
| 2 | descent transcripts + pinned values | simulatable | [PROVEN at engine scale] — imported, M4_LOOKUP_ZK_DESIGN Section 4 / batteries [U-K5c]/[U-K5d] |
| 3 | psi, totals T_j | public derivations | [PROVEN] (hash outputs / public functions of 2) |
| 4 | masked shares σ̃ | uniform on the sum coset, witness-independent | **[PROVEN*]** — Section 3.1; certificates Z1-b/Z1-g owed |
| 5 | per-wave ct-rounds | simulatable given claims | [PROVEN] — imported (Q4.2a masks, R1 pads, MLWE; SOUNDNESS_REFERENCE 3.2), EXCEPT the multi-round shared-commitment caveat, graded separately in 3.4 |
| 6 | zeta (deleted wire) | nothing sent; claims are public constants | [PROVEN*] via identity (2); canary Z1-f owed |
| 7 | closing round | simulatable (public claims, no reveals) | [PROVEN] — same machinery as 5, same 3.4 caveat |
| — | FS/ROM programming of the full challenge chain (~700 draws at 2^20) | hybrid | [MODEL] — the repo-wide forking/grinding convention (M4_LOOKUP_ZK_DESIGN Section 7 item 4) |
| — | whole-transcript composition (hybrids H0..H4 below) | indistinguishability sums the component defects | [SKETCH] here; transcription to Q4_LEMMAS + engine-scale certification [OBLIGATION] |

### 3.3 The hybrid chain

H0 = real. H1: replace every pad/share pair by S4's coset sampling —
distributionally IDENTICAL (3.1), defect 0. H2: replace the descents
by the U-K5 simulator — defect bounded by the U-K5 argument (MLWE +
its lemma stack). H3: replace the ct-rounds one at a time (W + 1
rounds) — per-round defect from Q4.2a's rejection-sampling lemma plus
MLWE for the g/R1 material; union over rounds, same accounting family
the engine already carries for W = 670 rounds per proof. H4 = the
simulator. Total distinguishing advantage: MLWE + Σ per-round defects
+ the [MODEL] ROM term. No step depends on the witness after H1 —
which is the point: H1 is the only NEW step this design adds, and it
is exact.

### 3.4 The one honest caveat: multi-round openings of a shared commitment

A pad commitment is opened (masked-opening z, image w1) in ~113 wave
rounds and the closing round; every other commitment in the system is
opened once. Each opening's mask y is fresh per round and each round's
z is, after rejection sampling, distributed independently of its
center (Q4.2a) — so the JOINT distribution of ~114 openings of one rho
is the product of the per-round simulable distributions, and the
statistical defect accumulates linearly (114 × the per-opening defect,
negligible-class at the frozen ct-round parameters). Argument class:
standard FS-with-aborts multi-proof composition. Grade: **[SKETCH]**
here — the repo has no transcribed lemma for the joint case, and this
design refuses to inherit one silently: transcription into Q4_LEMMAS
(a Q4.2a' composition corollary) is a named [OBLIGATION], with the
E3Z-N4-style derive-time canary counting openings per commitment. If
review rejects the pattern, the priced fallback is Section 2.6 option
1 (+0.65 dce/el, closing tree) — expensive but eliminates shared
commitments entirely.

### 3.5 What still leaks, honestly

(i) Shape metadata: n_el, W, the plan, pad layout, claim counts — all
public by design (D-2), not witness. (ii) The totals T_j and every
pinned value — simulatable per U-K5; no residual channel known.
(iii) HVZK is proof-of-protocol, not a chain-wide statement — the
standing R1.3 note; the manifest/reveal plumbing above the layer rig
carries its own analysis. (iv) Timing/memory side channels are out of
scope repo-wide. (v) Nothing else identified: in particular the
per-wave localization channel (WHICH wave holds which chunk) reveals
only plan structure, which is a public function of the shape.

## 4. Soundness non-interference (the R1.3 pattern)

The masks must not help a cheating prover. Every argument is an
identity or an exhibited attack/defense pair with its battery leg.

1. **Pads cancel identically.** Summing the wave-forced relations (3)
   over w and subtracting the closing-forced (4): Σ_w functional_w =
   Σ_w σ̃_{j,w} − Σ_w e_{j,w} = T_j − 0. The pad contributes ZERO
   soundness error — the cancellation is algebraic, not statistical
   (stronger than Libra's G-opening route, same structural position
   as U-K5's "G_j pinned to committed coefficients"). [PROVEN*]
2. **The zero-sum leg is load-bearing.** Drop (4) and the forgery is
   immediate: to pass a false total T' = T + δ, commit pads with
   Σe = δ and reveal σ̃_w = functional_w + e_w honestly — every wave
   round accepts (the claims are true over committed data), the sum
   gate accepts (Σσ̃ = T + δ = T'). Exhibited attack; the closing
   round rejects it (Σe = δ ≠ 0 is a false claim over committed
   data). Battery Z1-d demonstrates BOTH directions — the F5-pair
   discipline. [PROVEN* both directions]
3. **Extraction.** The knowledge extractor runs the existing ct-round
   extractor per round: binding (MSIS) fixes each commitment's
   message across all rounds that open it; the wave rounds extract
   (3), the closing round extracts (4); setting σ_w := σ̃_w − e_w
   reproduces exactly the unmasked split-claim extraction
   (PROGRESS_UR.md S0's load-bearing leg: a compensated lie rejects
   at its wave). No new extraction machinery; the pad is one more
   committed message coefficient. [SKETCH — transcription rides the
   same Q4 obligation as 3.4]
4. **The zeta strengthening is monotone.** Per-wave zero claims imply
   the layer-wide sum-zero claim they replace; a cheating prover
   faces the E2 point-mass bound (≤ 2^-w per row, w = 11, l = 24
   rows per family) per WAVE instead of per layer. No completeness
   loss by identity (2). [PROVEN*; fragility canary Z1-f]
5. **No new challenge surface.** The pads introduce no new challenge
   draws (nu-analogues are unnecessary — nothing needs combining), no
   quadratic claims (the R1/Vandermonde structure of
   SOUNDNESS_REFERENCE 3.3 is untouched), and no rejection-sampling
   surface (pads are committed data, not per-round samples — the
   M4_LOOKUP_ZK_DESIGN Section 5.5 argument ports verbatim: a
   ct-round restart re-derives c only; restarts cannot grind pads).
6. **Error budget.** +9 exact claims and +1 round: the psi-batch cap
   (9 copies ≈ 2^-279) is unmoved; the closing round's claims are
   exact (no compression, no new 2^-31 edge); per-round C2 capacity
   is re-derived at the +1-commitment wave shape by the engine's own
   scan (D-3) — the design does not hand-carry a constant here.
7. **Ordering edges.** Section 2.5's table: the pad-commitment swap
   (row 1) is THE new F5 edge; the σ̃-after-c_w edge (row 2) is the
   existing reveal edge with a grown reveal set. Every pre-existing
   edge binds strictly more data (h0_link gains the pad commitments)
   and is therefore preserved — the U-K5e "strictly more data"
   argument — but each S1 battery edge must be RE-RUN under masking
   (Z1-e), exactly as U-K5d re-ran E3-N1..N5.

## 5. The rank/leakage/recovery battery spec

The implementation tranche MUST land every leg below; the pattern is
the [R1] battery (leak pair + order pair, F5 style;
SOUNDNESS_REFERENCE Section 8 item 1) and the [U-K5c]/[U-K5d]
batteries (m-recovery harness at engine scale, rank certificates as
derive-time canaries, ordering pairs both directions). Legs Z1-a/b/g
are the audit's demanded "rank/recovery test that attempts to infer
activation chunks from all honest wave transcripts and compares
leakage with the original total claim" (REMEDIATION_PLAN Phase 2.4),
made precise.

**The baseline statements the battery certifies** (Section 1.3's
table, as executable claims):

- learnable-from-totals: 0 fresh witness equations per proof (the
  totals are public functions of U-K5-simulatable pinned values);
- learnable-from-shares TODAY: 9(W−1) fresh equations per proof,
  accumulating across proofs at fixed plan;
- learnable-from-shares MASKED: 0 fresh equations — equal to the
  totals baseline.

**[Z1-a] — the leak, demonstrated (unmasked baseline).** At a rigged
toy claim set (the [U-R1a] style: single-coefficient-support
commitments so that each wave's touched support s_w ≤ 9), run the
AS-BUILT splitter and recover the wave's private committed values
EXACTLY from one transcript's pin shares by solving the public linear
system (1) — the Z1b/Q4.3e "recovered exactly, rank s_w/s_w" pattern.
This leg is the C-02 exhibit and stays in the suite permanently as the
pre-fix regression (run against the legacy `Revealed` policy).

**[Z1-b] — masked non-recovery + the counting canary.** Same pipeline
against the masked transcript: the recovered values MUST differ from
the truth (recovered ≠ witness), and the solver's consistent solution
set MUST be the full coset predicted by 3.1. Derive-time canary at
engine shapes (the E3Z-N4 pattern): per claim j, #free exposures
(k_j − 1) == #free pads (k_j − 1), and the exposure/pad map is the
identity-plus-solve bijection — counted, not assumed.

**[Z1-c] — the F5 order pair (pad-commitment binding).** Attack
direction: pad commitments OUTSIDE h0_link (or h0_w built without the
wave's pad-commitment identity) — present δ-shifted pads to the wave
rounds and a consistent zero-sum set to the closing round; a false pin
total ACCEPTS. Defense direction: the shipped order (pads in h0_link,
wave lists derived from the plan) REJECTS the same crafting. Both
directions demonstrated, per the F5 house rule.

**[Z1-d] — the zero-sum load-bearing pair.** With the closing round
DISABLED (rigged verifier): committed pads with Σe = δ ≠ 0 and
honestly-computed σ̃ ACCEPT a false total T + δ (Section 4.2's
attack). With the closing round wired: the same proof REJECTS at
exactly the closing round. (The multi-wave analogue of U-R1a's
"compensated lie passes the gate but its wave REJECTS" — one level
up.)

**[Z1-e] — the S1/S3 tamper set re-run under masking.** Lied σ̃
REJECTS at the sum gate; compensated σ̃ pair passes the gate but
REJECTS at its wave's round (the pad term makes the wave claim false);
the g-mask cross-use forgery REJECTS; the lookup-h0 flip, off-table Y,
tampered Z, straddling-quad legs all re-run at the masked shape —
h0_link binding strictly more data must preserve every edge.

**[Z1-f] — the zeta deletion legs.** (i) Canary: honest per-wave zeta
functionals are identically zero across the full shape sweep (assert
at pack time — the fragility flag of 2.4); (ii) a junk-bearing witness
REJECTS at exactly its wave (per-wave localization, stronger than the
old layer-wide gate); (iii) the transcript-byte differential is
recorded (the −576 B/chunk-wave claim of Section 6.2 becomes a
measured row).

**[Z1-g] — the accumulation stall.** P fresh proofs of the SAME toy
witness (fresh commitment randomness, fresh psi/alpha/z*): unmasked,
the stacked system's rank grows by 9(W−1) per proof until exact
recovery (demonstrate recovery at the toy scale where P is small);
masked, the stacked system's solution set never shrinks below the
totals-only baseline — the rank STALLS. This is the quantitative form
of the 3.1 corollary.

**[Z1-h] — pad freshness (the E3Z-N3 analogue).** Two proofs sharing
one pad vector: the difference σ̃ − σ̃' = σ − σ' re-exposes honest
share differences — the leak returns at half rate (demonstrated), and
the engine REFUSES pad reuse (enforced: pads drawn from the per-proof
ProverRng stream, freshness asserted derive-time, pinned by the
freeze row).

**[Z1-i] — layout determinism and edge cases.** The verifier
re-derives pad count, layout, and wave lists from the public plan and
must agree with the prover byte-for-byte (the D-2 discipline extended
to pads); centered-representative edge cases at σ̃ near ±q/2 exercise
the mod-q sum gate; a claim touching ONE wave takes no pad (k_j = 1 →
zero free exposures — the splitter must not spend a pad where the
share IS the public total).

## 6. Cost delta, priced

Every input below is a repo-recorded number: the S2/S3 measured tables
(PROGRESS_UR.md, 2026-07-14, 1T [NOISY-SHARED]), the LKP-9 frozen wave
constants, and the audit's C-03 byte arithmetic
(codex-audit-2026-07-14/FINDINGS.md). Everything derived from them is
[MODEL] arithmetic shown inline. Accounting basis: 1 dce = one
committed q31 message coefficient; one commitment at the layer shape
(msg_r 8 × D 128) = 1024 dce — the same basis that makes S2's "~2
extra g-groups per wave" ≈ 2048 dce per ~1565-el wave ≈ the recorded
~1.3 dce/el pin floor.

### 6.1 Committed material (dce/el)

Ingredients per shape (waves W = 43/168/670; el 65,532 / 262,140 /
1,048,572 — S2 table):

| item | 2^16 | 2^18 | 2^20 |
|---|---:|---:|---:|
| pad scalars 9W | 387 | 1,512 | 6,030 |
| pad commitments ceil(9W/1024) | 1 | 2 | 6 |
| pad dce (×1024) | 1,024 | 2,048 | 6,144 |
| closing-round g (2 groups) | 2,048 | 2,048 | 2,048 |
| **new committed dce** | 3,072 | 4,096 | 8,192 |
| per element | +0.047 | +0.016 | **+0.008** |
| wave-count effect (cap 76→75, ×76/75 on the per-wave surcharge ≈ ×1.013 on ~1.3) [MODEL] | +0.021 | +0.018 | +0.017 |
| **total dce/el delta** | +0.068 | +0.034 | **+0.025** |
| measured baseline (S2 lookup marginal dce/el) | 1.609 | 1.387 | 1.335 |
| projected masked | ~1.68 | ~1.42 | **~1.36** |
| relative | +4.2% | +2.5% | **+1.9%** |

Against the ~1.3 dce/el pin-floor comparison the task demands: the
masking costs ~2% of the floor at the 2^20 shape, falling with n (the
pad commitments amortize as 1/n; only the cap-driven wave-count term
is a per-wave constant). The S3 range arm adds nothing (shared psi
batch, Section 2.1). The pin floor itself — the S2 finding that the
per-wave pin g surcharge does NOT fall as 1/n — is untouched by this
design in either direction.

### 6.2 Transcript bytes, masked-descent ledger

The ledger that S2 reports (0.512 B/el at 2^20) — relabeled by Z3 as
"masked-descent bytes only, EXCLUDES per-wave CtRoundProofs". Deltas:
pin reveals unchanged (9 × 12 B per wave — σ̃ replaces σ); zeta wire
DELETED (−48 × 12 B = −576 B per chunk wave); the closing round adds
no reveal bytes (public zero scalars).

| B/el | 2^16 | 2^18 | 2^20 |
|---|---:|---:|---:|
| measured (S2, arm A) | 1.417 | 0.716 | 0.512 |
| zeta deletion (−576·W/el) | −0.378 | −0.369 | −0.368 |
| **projected masked** | ~1.04 | ~0.35 | **~0.14** |

Net NEGATIVE: the free rider pays for the masking three times over in
this ledger (−72% at 2^20).

### 6.3 Transcript bytes, full-wire ledger (the C-03 accounting)

The honest ledger: C-03 prices each commitment opening at z (n_r · D)
+ w1 (kappa · D) fixed-width — 88,247 openings ≈ 2,930.08 MiB at the
measured 2^20 shape, ~34.0 KiB per opening. This design adds: +1
opening per wave (the shared pad commitment in each wave's list, ~670)
+ ~8 in the closing round + ~1.3% more g openings from the cap step
(~506) [MODEL]:

    +1,184 openings × ~34.0 KiB ≈ +39 MiB ≈ +1.3% at 2^20.

Stated plainly: **masking is orthogonal to the succinctness wall.**
The 2.86 GiB / 11,720x-over-budget problem (C-03, adopted by Z3 as
the design-doc problem statement) neither improves nor materially
worsens; Phase 3 aggregation work owns it. A masking design that
claimed transcript savings from the 6.2 ledger alone would be
repeating the accounting error C-03 named — this one does not.

### 6.4 Prover/verifier time and memory [MODEL]

Analytic: +1 commitment in ~137-commitment rounds (+0.7% per-round
work), +1.3% rounds, +6 commit operations, one closing round in ~671.
Net ~+2%-class on prove and verify — INSIDE the S2 noise band (the
A−B prove marginal at these shapes was −10..+42 us/el on 140-600 s
totals, [NOISY-SHARED]). Honest statement: unmeasurable until built;
the implementation tranche must carry it via the S2/S3 attribution
counters (the "clean signal" discipline), not via A−B totals. Memory:
+6 commitment stores against the measured 8.23 GiB peak at 2^20 —
noise; the 2^20 CLI cap and the 2^22 wall (S2/B-D2) are unmoved.

## 7. What could kill this, and what this design does NOT close

Each risk carries a mitigation or a priced fallback; each non-closure
is stated as a wall, per the house rule that a surfaced wall beats a
papered one.

1. **The C-03 proof-size wall — NOT CLOSED, by scope.** This design
   makes the multi-wave transcript private, not small. At 2^20 the
   complete wire cost remains ~2.9 GiB + this design's +1.3%
   (Section 6.3) against a 256 KiB budget. Any future aggregation
   scheme (Phase 3) must PRESERVE the pad structure or re-derive the
   privacy argument — recorded as a design constraint on that work:
   an aggregator that re-exposes per-wave right-hand sides undoes Z1.
2. **The multi-round shared-commitment pattern fails review.** The
   3.4 composition argument is standard but untranscribed
   [OBLIGATION]. Fallback, priced (Section 2.6 option 1): per-wave
   pad commitments + a 2-level closing tree with second-level pads —
   +0.65 dce/el at 2^20 (26x the chosen variant), ~+670 openings
   either way. The fallback eliminates shared commitments at pure
   commit-cost; it does not change the simulator's shape (the coset
   lemma is construction-agnostic).
3. **The C2 cap re-derivation surprises.** Section 6 assumes the +1
   commitment per wave costs exactly one data slot (76 → 75). D-3
   makes `derive_ct_round_params`' scan the gate; if the true cap
   drops further at the +1 shape, each extra step is ~+1.3% waves —
   linear, priced, no cliff.
4. **HVZK scope.** Honest-verifier, proof-of-protocol — the standing
   R1.3/B.2 residual note. Chain-wide composition (manifest, reveal
   plumbing, cross-layer statements) is Phase 1-3/Statement-v3
   territory, NOT closed here.
5. **Out-of-scope reveal families — NOT CLOSED here, by design.** The
   block chain's `link_reveal_y` class (the q46 legacy arm, Z2's
   labeling scope) and the S3 scope notes (range-witness pad
   coverage, multi-table statement typing) are unaffected. C-02 is
   closed for the layer rig's wave shares specifically; the audit's
   Phase 2.1 enumeration ("every value newly visible in the
   multi-wave transcript") is answered by Section 1.3's table for
   THIS rig only.
6. **The zeta-deletion fragility** (Section 2.4): a future packer
   change that leaves nonzero junk turns into loud completeness
   failure, caught by the Z1-f canary — an accepted trade for
   deleting a 32,160-value wire at 2^20.
7. **Independent review is still owed.** REMEDIATION_PLAN Phase 2.5
   asks for an independent cryptographer's review of Fiat-Shamir
   composition and abort behavior across waves; this document is the
   input to that review, not a substitute for it.

## 8. Implementation-tranche sketch (gated on review of this document)

Sub-tranches in the U-K5a..e mold; every hash edge lands with its F5
pair, every frozen constant gets a freeze row. NOT to be started until
the orchestrator's review of this design round.

- **Z1-impl-a — splitter policy + pad plumbing.** The
  {Padded, ForcedZero, Revealed} policy enum on
  `split_claims_prover/verifier` (Result-typed per Z5's hardening —
  coordinate with that lane's signatures); pad sampling (solved last
  pad), wave-major layout, shared pad commitments into h0_link; the
  per-wave round-list extension. Exit: [U-R1a]-style self-test with
  pads live, honest ACCEPT at toy scale, Z1-i determinism legs.
- **Z1-impl-b — the closing round + zeta deletion.** The nine exact
  zero-sum claims; the zeta `ForcedZero` path with the wire removed
  and the pack-time canary. Exit: honest layer ACCEPT at 2^12 battery
  shape both arms; Z1-d and Z1-f legs green.
- **Z1-impl-c — the battery.** Z1-a/b/c/e/g/h complete; the E3Z-N4-
  style derive-time counting canaries; the S1/S3 tamper set re-run.
  Exit: full battery green at the battery shape; the [Z1-a] baseline
  leg archived as the permanent C-02 regression.
- **Z1-impl-d — measure + freeze + re-grade.** One measured run per
  S2 shape (serialized, MemoryMax per the shared-box rule) recording
  the Section 6 projections against reality (dce/el, B/el both
  ledgers, attribution deltas); freeze row **LKP-10**: pad layout
  rule (9/wave, wave-major, 1024/commitment), pad freshness rule,
  closing-round shape, the zeta wire deletion (share count 57 → 9
  per wave), the re-derived data cap. Re-grade this document's
  [PROVEN*] rows to [PROVEN at engine scale] or demote them, row by
  row; transcribe 3.1/3.4/4.3 into Q4_LEMMAS; merge Section 2.5's
  rows into SOUNDNESS_REFERENCE Section 7. Exit: C-02 closed at
  engine scale or the failure surfaced.

---

*Changelog: 2026-07-15 — first edition (Z1 design round, tranche U-Z,
audit 2026-07-14 C-02). Leak sharpened to the pin-share identity with
counts at the measured shapes and the accumulation kill; zeta shares
shown identically zero (leakless, wire deletable); construction:
coset one-time pads in shared pre-challenge pad commitments + a
zero-sum closing round + the zeta deletion, alternatives priced and
rejected; complete multi-wave simulator with the exact pad-coset lemma
[PROVEN*] and the multi-round-opening composition caveat surfaced as
an OBLIGATION with priced fallback; soundness non-interference incl.
the load-bearing zero-sum pair; battery spec [Z1-a..i]; costs priced
from PROGRESS_UR.md S2/S3 and C-03: +0.025 dce/el on the 1.335 floor
at 2^20 (+1.9%), 0.512 → ~0.14 B/el masked-descent ledger, +1.3%
full-wire — succinctness explicitly NOT closed. No code, no spike:
paper-first per the tranche brief; grades capped at [PROVEN*]
accordingly.*
