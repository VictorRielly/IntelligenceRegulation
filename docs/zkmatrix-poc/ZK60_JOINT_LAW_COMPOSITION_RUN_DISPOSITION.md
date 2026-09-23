# The joint-law composition for a shaped block and a run — disposition

By the interactive Claude Fable 5.1 session (the security owner), 2026-09-20,
17:58. It rules on `ZK60_JOINT_LAW_COMPOSITION_RUN.md` (a delegated agent's
draft of the same afternoon) after `ZK60_JOINT_LAW_COMPOSITION_RUN_CHECK.md`
(an independent agent told to assume the draft wrong). Both read the lane
`zk60-private-block-125m` at `caa9b9a`.

**This is not a privacy acceptance of anything.** Register entry D22 (the toy
block) is untouched. No run, no development rung and no 125M block may be
called private on the strength of this page.

## 1. What survived the attack

- **Theorem B is not false**, in the checker's first line: *at fixed,
  non-refused challenges and under the uniform-blinding idealisation, the
  joint law of every field value an L-block run publishes is the same for
  every admissible hidden run input.* Its proof is a correct **reduction**:
  the toy theorem per stage, plus one factorisation over stages.
- **The factorisation's key hypothesis is a fact of the code, not a reading**:
  there is no run-wide masking commitment; every slot of block k is masked by
  block k's own commitment, opened once in stage k (`protocol.rs:674, 780`).
- **The pad budget cannot be exceeded at any shape**: the pad count is set
  equal to the number of opened columns and indices are drawn with
  replacement.
- **Every counted figure reproduces** on an independent recount from the
  source — among them the draw count per 125M block (9,029,742), per
  twelve-block run (109,728,040), and the residual 2^-69.3 *[2026-09-23:
  both are the pre-S19-F1 counts; after the repair 9,029,804 per 125M block
  and 109,728,784 per twelve-block run (ruling H-6), now MEASURED in situ as
  a sum of measured parts by lane stage 46 (`2ea7221`): block stream
  9,029,804 at 125M, 687,028 at rung-G, a 2-block rung-G run 1,382,760 —
  every measured count equal to its counted one; the residual 2^-69.3
  unmoved]*. The toy control
  reproduces decision D9's accepted 327,052 draws to the draw, and only with a
  term the design and its checker had both missed (the helper commitment's
  zero-sum re-draw); the design's 109.4 million was therefore low by a third
  of a percent, the residual unchanged.
- **A boundary's two claim sites can be PROVED input-free, not merely
  reduced**: the boundary's 6 × 6 system is block-triangular with an
  invertible diagonal, and all three conditions that travel with the terminals
  step are enforced there.

## 2. Rulings

**R-1 (the check's B-1, the one real break): a run's refusal channel is not
"challenge-only".** For a single block the witness is built before anything
public exists. For a run it is built *inside* the stage loop, one block at a
time, after the earlier segments are on disk; twelve of the witness builder's
fourteen refusal sites are range or relation checks on hidden values. So an
inadmissible chain is discovered at its first inadmissible block, with
certainty, and leaves that many finished segments behind. Rulings:
1. **"Admissible hidden run input" is a joint condition on all L stages**, and
   every statement about a run says so. For an admissible chain the witness
   builder never refuses; for an inadmissible one no proof exists, by design —
   and *which block refused is a function of the hidden input*.
2. **Operating rule M-9 (of D21's shape).** A run directory is publishable
   **only** if it contains the run statement, which is written only after the
   whole run has verified (built in stage 18). A directory without it is not a
   run: it is never transmitted, and whoever launched the run removes it. The
   refusal reason, **which names the stage**, is never shown to anyone not
   entitled to the input.
3. **Recorded alternative, not built:** check the whole chain's admissibility
   before the first segment is handed to the sink. Worth: no partial directory
   from this cause, and no proving time wasted on an inadmissible input (up to
   L × 31 s at the 125M shape). Cost: one more forward pass — up to about 15%
   of a run if done with the witness builder, less with the reference kernel.
   Revisit when a service exists whose clients can observe the time to a
   refusal (decision D20 puts timing out of scope for the first MVP), or if
   real checkpoints turn out to produce inadmissible inputs in practice.

*(**Correction to R-1.3, 2026-09-21 01:12** — ruling H-1 of
`ZK60_HASH_LAYER_AND_FS_LIFT_RUN_DISPOSITION.md`: the run header absorbs both
external endpoint roots before any challenge, so the prover has **already run
the whole forward pass** before the first segment; the "one more forward pass,
up to 15%" costing above is withdrawn. The rule that replaces it: a production
caller seals the endpoints with the witness builder's own pass, refusals
included, so an inadmissible chain is refused before the header. For the same
reason the condition in R-2 below — the hidden input fixed before the first
segment — is a fact of the code for an accepted run, not only an operating
condition; what remains is that the witness-source interface still permits an
adaptive source.)*

**R-2 (B-2): one randomness generator per run is accepted as built.** The
design's "one generator per commitment" was a recommendation, never one of my
rulings, and I withdraw it: under the named generator assumption one stream
read at schedule-determined positions is as good as forty-nine, and it leaves
one fail-closed entropy point before stage 1 instead of one that can fail six
minutes in. Conditions: the generator is never cloned, forked or serialised;
**the run's hidden input is fixed before the first segment** (the per-stage
witness interface would let a caller choose block k's input after seeing
earlier challenges — an operating condition, not a code fact).

**R-3 (B-3): "joint = sum of parts" is a consistency check of the model, not
evidence of independence**, and the run gate's report and my run disposition
are corrected to say so. The checker built the counterexample: two *distinct*
blinding rows whose *values* coincide score exactly like an honest run (joint
0 = sum 0) while disclosing 1,024 field elements at the development shape.
Independence across the 4L + 1 commitments rests on the generator and the draw
discipline (the draft's gap G-R4). **It is to be machine-asserted**: a test
that accounts for every draw of a run by role, shows the roles' stream
positions pairwise disjoint, and totals the counted figure. If that needs a
hook in `zkp-core/src/rng.rs`, it is asked of the integrator.

**R-4 (B-4): whether the ideal world exists at the 125M shape is blocking, not
engineering.** There is no all-zero test at that shape, and the zero witness
sits on two exact range boundaries whose constants moved there. A
witness-builder test and a one-block proof on the all-zero input at 125M are
being added now (the lane's test-only stage 19); I launch the heavy one.

**R-5 (B-5, the draft's G-R7): interior boundary scales become constants of
the approved calibration.** I read it myself: `RunStatement::new` takes the
per-block scale pairs as a caller argument (`run.rs:113`), nothing ties the
interior ones to `calibration_identity()`, and `BoundarySpec::digest()` is
never absorbed — the external scales are bound through the endpoint policy,
the interior ones by nothing. They have no arithmetic effect, so no equation
is at risk; but a receipt does not attest to them, and a scale chosen from the
input would publish a hidden intermediate's dynamic range. **Ruling: a run
refuses any block scale pair other than the approved calibration's** (as
`IoSpec::new` already does for endpoints). The scales are then bound through
the calibration identity the run already absorbs, and no proof byte moves. A
future calibration with per-layer scales must put them under its identity.
Lane stage 20, after the test-only stage.

**R-6 (the figures).** The input-dependent refusal *inside the argument* is
shape-dependent. Raw counts of inverted lookup denominators: 64,768 at the toy
(2^-112.0, the figure in D22's statement), 439,296 at the development shape
(2^-109.3), 103,890,944 per 125M block (2^-101.4), **2^-97.8 for a
twelve-block 125M run** — not the 2^-108.4 of my 09:50 handoff entry, which
multiplied the toy's figure by twelve. Challenge-only refusal (liveness)
scales with openings, 3L + 1 of them: **2^-58.8** at L = 12. **Before any 125M
statement, the distinct-value refinement is taken** (98.6 of 103.9 million
denominators are byte lookups over at most 256 values; worth 5.4 bits at the
toy and far more here), because at 2^-97.8 this term sits a third of a bit
from the run's soundness level.
*(Taken the same night, 23:27 — ruling S-4 of
`ZK60_GENERIC_RANK_LEMMA_SHAPED_DISPOSITION.md`: the inverted denominators
fall in three families of at most 256 arguments, so at most 768 distinct
arguments per block at every shape; **2^-118.4 per block and 2^-114.8 for a
twelve-block 125M run**, counted by the drafter and recounted independently by
its checker. The raw figures above stay correct as upper bounds; the worry
about the run's soundness level is withdrawn.)*

**R-7 (B-6, B-7, B-9, B-10, B-11): errata.** Corollary R.3 upgraded to proved,
with all three travelling conditions named; "8 ζ challenges" corrected to at
most 7 *(**this correction of mine was itself wrong — note of 2026-09-21
00:43.** There are seven source lines, but one of them is the shared arm of
the Q and KV zero-checks, which runs twice: a proof draws **8** at the two
development shapes and **5** at the 125M shape. The draft was right. Two
independent recounts agree — the shaped lemma's checker and the slot-closures
draft. A second slip in the same section, found by the latter: only the `nu`
and ζ challenges are refused on zero; `mu` is not. Both are bookkeeping at
2^-128 and move no byte)*; the two citations copied from the design re-read (`zkp-core/src/
pcs.rs:943` for the combination vectors); the "120-byte framing" difference
withdrawn as already recorded; the helper commitment's zero-sum pair not
double-counted. An errata pass on the draft follows.

## 3. Where a run's privacy path stands after this

| Step | For a run at the development shape | At the 125M shape | Status at 2026-09-23 (dated correction; the two columns to the left are kept as written at 17:58 on 2026-09-20) |
|---|---|---|---|
| All-zero input proves and verifies | done (three-block run, tests) | **not tested — blocking (R-4)** | **R-4 closed on its own terms.** The witness builder admits the all-zero input at 125M under both weight recipes, the three zero-headroom boundaries pinned at the shape's constants (lane stage 19 task 9); one 125M block on the zero input proves and verifies, 26.98 s / 1.23 s (`ZK60_BLOCK125M_S19F1_DISPOSITION.md` §6); a two-block all-zero 125M run proved, verified, was captured (`m125-capture-zero-l2`, 2026-09-21 08:57) and gated (run gate round 9). **A twelve-block all-zero run has not been run**; it rests on the stage-19 test that the zero chain is identically zero and its witness weight-independent |
| Per-commitment lemma at the new layouts (gap G-R1) | owed from the start | owed from the start | Core accepted with changes S-1 … S-6 at both shapes (`ZK60_GENERIC_RANK_LEMMA_SHAPED_DISPOSITION.md`, 2026-09-20 23:27); measured at 125M on two two-block captures: `A` 0, `H` 2 = the public LogUp identity, endpoints 0, the boundary 6 of 6 disclosed 0 (round 9). Left: GS-2 at 125M, GS-4, GS-5, GS-11, GS-12 |
| The gate constructs preimages | boundaries and endpoints done; `A` and `H` skipped, not faked | nothing | Constructed for every commitment, `A` and `H` included (round 7), the masking commitments and one joint run assignment (round 8) at the development shapes; at 125M all seven hiding commitments of a two-block run, 8,263,736 entries none differing, masking 32,918, joint sum 8,296,654, channel table 28 at 10 / 5 / 4 / 9 (rounds 9 and 9c; `ZK60_PRIVATE_RUN_MULTI_BLOCK_DISPOSITION.md` §2b). Two-block runs only |
| Slot closures (gap G-R2) | 23 of 23 machine-checked on two tagged runs; owed as a reading | nothing | Read: holds with changes (`ZK60_SLOT_CLOSURES_SHAPED_DISPOSITION.md`, 2026-09-21 01:22); enforcement C-3, C-4, C-7 built (lane stage 24 items 6–8, `68e8769`); terminal identity 46 of 46 at 125M (round 9); the non-linear channel's algebraic half closed (NL-1) |
| Joint law (this page) | reduction accepted, conditional on G-R1, G-R2, G-R4, G-R5 | the same, plus R-4 and R-6 | Still a reduction. R-4 closed (row 1); R-6's refinement taken (S-4, the dated note under R-6 above); G-R1 and G-R2 narrowed (rows 2, 4); G-R4 counted and machine-asserted on single blocks (row 6), the LAW still owed (NL-8); G-R5 written (row 7) |
| Cross-role independence (G-R4) | to be machine-asserted (R-3) | the same | The seven draw-accounting assertions (J-5) are live on single-block proofs at six shapes — toy, rung-K4, rung-P2, rung-C6, rung-W14, rung-E32 — with the toy's 327,052 draws reproduced exactly (lane stage 36, `29cba9a`). **Not at 125M and not at run scope** (J-5's widened assertion 2, `11L + 3(L−1)` segments, is measured nowhere); the endpoint generators on a replica (S36-F2). J-1 places the independence in the first hop |
| Hash layer and lift | computed for what a receipt opens, under the keyed rule; the lift for a run (gap G-R5) unwritten | nothing | G-R5 written (Lemma H^run, Route A^run), core accepted with changes (`ZK60_HASH_LAYER_AND_FS_LIFT_RUN_DISPOSITION.md`, 2026-09-21 01:12); at 125M 2,304 opened columns (52,867,072 B) re-hashed and authenticated and 27,828 challenges re-derived (round 9). Open: G-H1 (Route B, unruled), D19b (pending Victor), the explicit L = 2 hybrid for the position tags, GS-7 |

*Correction block, 2026-09-23: every row of this table moved after it was
written; the right-hand column says where each stands and why, and nothing to
its left was changed. Evidence: lane ledger `ZK60_BLOCK125M_LANE_PROGRESS.md`
(stages 19, 24, 36) on `zk60-private-block-125m`; run gate rounds 7–9c as
recorded in `ZK60_PRIVATE_RUN_MULTI_BLOCK_DISPOSITION.md` §2b; the dispositions
named per row; reconciled in `ZK60_SHAPED_PRIVACY_PATH_STATUS.md` §2.6 and §4
rows 1–7. None of it is a privacy acceptance; no run and no 125M block may be
called private on the strength of this page.*

## 4. What I checked myself, and what was delegated

Myself: the interior scales' path through `run.rs` and `boundary.rs` (R-5);
the run header's absorbs; that the statement file is written only after
verification (stage 18). Delegated and not re-derived by me: the theorem's
proof, every recount, the counterexample of R-3, the witness builder's refusal
sites. The draft and the check disagree nowhere on a number.
