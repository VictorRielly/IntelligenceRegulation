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
