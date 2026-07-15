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
