# D63 lane L32: the openings' completeness, `check_opening`'s refusals as sites, and what is left of `Complete` for the classify run (2026-11-09)

Lean lane L32 (Claude), on its own worktree branched from perf at `6e788dcb` (lanes L9–L29 merged). Lean 4.34.1,
Mathlib v4.34.1, no new dependency. Ten new library files under `formal/ZK60Formal/`, imported by the library root:
`HonestOpenPcs.lean`, `HonestOpenM.lean`, `HonestOpenFields.lean`, `HonestOpenSites.lean`, `HonestRunBlock.lean`,
`HonestRunProg.lean`, `HonestRunCount.lean`, `HonestRunCover.lean`, `HonestRunStageIn.lean`,
`HonestRunStageOut.lean`. No Rust, no checker. `Statements.lean`, every
existing Lean file (except the root's import lines) and every production source are unchanged. Evidence:
`results/zk60_lean_l32_20261109/`.

Labels: **PROVED** (a Lean theorem, axioms at most `propext`, `Classical.choice`, `Quot.sound`), **CODE** (read off
the sources, file:line, 2026-11-09), **ESTIMATE** (arithmetic or reasoning not proved in Lean), **PREMISE** (a named
hypothesis a later lane must discharge).

## 1. In plain words, for Victor

**What this lane is.** Your gate `ProductionReady` includes `Complete`: an honest prover is accepted except with
probability at most `2^-40`. For the media app's classify run, lanes L18, L25 and L29 reduced `Complete` to three
obligations: O8 (each part's honest proof is accepted), O9 (the honest prover gives up only at listed places) and O10
(how often those places can occur). This lane was asked to close them. It closes one layer of each and does NOT close
any of the three outright. What is done is green and stands on its own; what is left is listed by name in §6.

**What now exists.**
- **The openings are complete, as theorems about the code's own verifier.** Every committed table is checked by
  "opening" it: the prover sends a few combined rows and some columns with their Merkle paths. Until now the Lean
  proofs ASSUMED that the verifier accepts an honest opening. Now the honest opening prover is written in Lean, for
  the regular commitments (`A`, `H`, the endpoints, the boundaries) and for the mask commitment `M`, and it is PROVED
  that lane L10's executable verifiers accept its output at EVERY hash function and from EVERY transcript. Their
  completeness error is exactly zero: no challenge can make an honest opening fail. This holds at the parameters of
  the media app's blocks (R13), of W16R2, and of the two token stages.
- **The honest openings have the right shape.** Their words are canonical, their counts and lengths are the
  geometry's, their Merkle paths have the tree's depth. These are the facts the wire codec and the depth pre-checks
  ask for.
- **A part's proof is accepted, given only arithmetic.** For a block of the media app, for stage IN-C and for stage
  OUT-C, the executable verifier accepts the honest proof given: the profile's own pre-checks, each slot's arithmetic,
  and "the claims the run makes are true of the committed tables". The opening assumptions and the depth assumptions
  of lane L25's and lane L29's theorems are gone (three and three for a block, four and four for each stage).
- **The prover's own refusals around an opening are fresh coin flips, counted exactly.** Before each opening the
  prover checks its challenges and gives up in two cases (this protects zero knowledge): a member coefficient is zero,
  or the two proximity coefficients are "dependent". PROVED: these are refusal sites in lane L18's sense, each a fresh
  coin flip (`δ = 0`); an opening on a commitment with `n` claims has exactly `n + 2` of them with exactly
  `p + n + 1` bad values in all (`p ≈ 2^64` is the field size: the "dependent" case). This is the dominant term of
  the completeness error, the `2^-64` per opening that lane L18 estimated: now a theorem, not an estimate.
- **The openings as "transcript programs".** A refusal is a fresh coin flip only if everything the prover did before
  it is written as one chain of transcript operations. Lanes L25 and L29 did that for the slots. The openings were
  missing. They are written now, and PROVED to end on exactly the honest prover's transcript.
- **The count stays inside `2^-40`** with stage IN-C's refusal counted correctly (finding L29-3: 13 places instead of
  1). The reasoning behind the 13 is now a small theorem (`seq_zero`); the 13 places themselves are counted, not
  built.

**What it does not do.**
- **O8 is not closed.** What is left is arithmetic along the honest run: each slot's polynomial (23 per block, 12 for
  the two stages), and that every claim and every mask functional the run produces is TRUE of what was committed. No
  slot arithmetic was started. The three part theorems stop at the part's core: the wire framing around it (the
  codec's remaining facts, a block's boundary opening) is not assembled.
- **O9 is not closed.** The pieces are there for one part of the run (a block core, a stage): the head and the slots
  (L29), the openings (this lane), the `check_opening` sites (this lane). Chaining the 28 parts of the run into one
  program is not done. Four kinds of refusal are still named events and not sites (§6).
- **O10 follows O9.** The per-opening count is exact and proved; the other counts are still read off the code.
- So `Complete` at `2^-40` is still a theorem FROM NAMED PREMISES (lane L18's `classify_complete_target`), with fewer
  and smaller premises than before. §6 lists every one.

**One thing worth your attention (finding L32-1).** The table `H` of a block depends on three challenges that are
drawn from the transcript. Lane L25's description of the honest prover gives the `H` opening no access to those
challenges, and its completeness contract asks for every possible starting transcript. Read literally, no honest
prover fits. The fix is small and is done here for a block core and for both stages: build the honest prover's data
from the transcript it starts on. The run's honest parts need the same change before O8 can be closed; no statement
changes.

## 2. What is proved

All PROVED; the theorem counts and the axiom audit are in §7.

### 2.1 The regular opening: honest prover and completeness (`HonestOpenPcs.lean`)

CODE: `zkp-core/src/pcs.rs` `open_zk` :1040-1069, `fold_rows_multi_zk` :976-1000, `encode_row_zk` :674-693.

| Theorem / definition | Meaning |
|---|---|
| `combAt`, `combVec`, `toK_combAt`, **`encK_combVec`** | the row combination on the words (`Σ_i ρ_i·row_i`); it is the field's; L10's encoder is linear in it |
| `Table`, `ColsHonest`, `rootOf`, `pathOf`, **`verifyPath_honest`** | one commitment's honest data (rows `message ‖ pad`, encoded columns, salts); the committed columns ARE the encoder's values; the honest Merkle root and paths verify |
| `tabVal`, `MemTrue`, `ClaimTrue`, **`groupZclaims_true`** | a claim is TRUE of the rows (its value is its own weights' functional); then every member of every group `group_zclaims` forms is true |
| **`pcsProve`**, `pcsProve_eq`, **`pcsProve_shape`**, **`pcsProve_canon`** | the honest opening prover (`open_zk`); what it returns; its shape; its words canonical |
| `claim_check`, `colOk_honest` | the claim check passes; one honest column passes every check |
| **`pcsVerify_of_prove`** | L10's executable `pcsVerify` ACCEPTS the honest opening and lands on the prover's transcript: any parameters, points and column evaluator meeting L10's `ColEncSpec`, every hash function, every transcript |

### 2.2 `M`'s opening: honest prover and completeness (`HonestOpenM.lean`)

CODE: `hashline/src/zk.rs` `mask_commit_tagged` :499-536, `combined_weights` :551-574, `mask_open` :618-656.

| Theorem / definition | Meaning |
|---|---|
| `MTable`, `mCol`, `MHonest` | `M`'s honest rows as polynomials over the base field; the committed column at a point; the degrees and `b`'s zero sum over `G_512` |
| `qPoly`, `pPoly`, **`qPoly_sum`** | the product polynomial (offset `1`: D65(1)) and the proximity polynomial; the sum check holds when every functional is TRUE of the masks |
| **`maskProve`**, `maskProve_eq`, **`maskProve_shape`** | the honest `M` prover (`mask_open`); what it returns; its shape and canonical words |
| `mColOk_honest`, **`maskVerify_of_prove`** | L10's executable `maskVerify` ACCEPTS the honest `M` opening and lands on the prover's transcript, at every hash function and transcript |

### 2.3 The fields of the block and stage verifiers (`HonestOpenFields.lean`)

| Theorem / definition | Meaning |
|---|---|
| `ofOZ`, `ofMO`, `toOZ_ofOZ`, `toMO_ofMO`, `pathsDepth_ofOCol`, `ofMO_canon`, `ofMO_shape`, `bMask_fst` | this lane's openings in L9's wire types; the wire form keeps the words, the shape and the path depths |
| **`bOpen`**, **`bMask`**, `lagK`, `colEnc_spec_at` | the honest opening provers in the shape L25's `CoreData` takes; the interpolant row form with the code's roots |
| **`pcsAt_of_prove`** | a stage's opening check (`A`, `H`, the token endpoint, `B` of IN-C and OUT-C) accepts the honest opening |
| **`pcsField_of_prove`**, **`pcsFieldR13_of_prove`** | `BlockParams.pcsVerify` at W16R2 and at R13 (the media app's blocks) accepts the honest opening |
| **`maskField_of_prove`** | `BlockParams.maskVerify` (every profile) accepts the honest `M` opening |
| **`bOpen_canon`**, **`bOpen_shape`**, **`bOpen_pathsDepth`**, **`bMask_canon`**, **`bMask_shape`**, **`bMask_pathsDepth`** | canonical words (`HidingCanon`, `MaskCanon`), counts and lengths (the opening parts of `CoreShape`), path depths (`pathsDepth`, T-4) |

### 2.4 `check_opening`'s challenge refusals as sites (`HonestOpenSites.lean`, `HonestRunCount.lean`, `HonestRunCover.lean`)

CODE: `protocol.rs` `check_opening_challenges` :312-323, `check_opening` :327-337.

| Theorem / definition | Meaning |
|---|---|
| `drawAt`, `chalVec_add_tr`, `groupDraws_spec`, `foldDraws_spec` | the draws of consecutive `challenge_fp2_vec` calls are the transcript's squeezes in order |
| **`openingChallenges_refuses`** | `check_opening_challenges` refuses ONLY when the geometry has no pair, a member draw is zero, or the pair of draws has determinant zero |
| `lineBad`, `lineBad_card`, **`det_zero_line`** | a canonical pair with `a ≠ 0` and determinant zero has `b` on the base-field line through `a`: at most `p` values |
| `drawZero_fires`, **`depPairSite`**, **`depPairSite_fires`** | the zero draw (`k = 1`) and the dependent pair (`k = p`) as L18's `Site`s, `δ = 0`, firing exactly when the guard does |
| **`openingChallenges_cover`** | a refusal of `check_opening_challenges` after a prefix program is one of its sites firing |
| `openSite`, `openK`, **`openSite_k`**, **`openK_sum`**, **`openSite_cover`**, **`open_refusal_eq`** | one opening's sites as one family indexed by the claim count `n`: `n + 2` sites, every `δ = 0`, exactly `p + n + 1` bad values, its part of the completeness total |
| `bumpKey_sum`, **`openingGroupsAt_sum`** | the groups' member counts add up to the number of claims, whatever the grouping |
| **`checkOpeningExec_refuses`**, **`checkOpening_cover`** | `check_opening` refuses only when the audit, the grouping or the group count refuses, the geometry has no pair, or one of the opening's sites fires |

### 2.5 A block core and the two stages from their tables (`HonestRunBlock.lean`, `HonestRunStageIn.lean`, `HonestRunStageOut.lean`)

| Theorem / definition | Meaning |
|---|---|
| `CoreTables`, `bgaOf`, **`coreDataAt`**, `bgaOf_core` | a block core's honest commitments; L25's `CoreData` built at a start transcript (finding L32-1) |
| **`blockVerify_of_tables_r13`** | L9's executable `verify_core` at an R13 profile ACCEPTS the honest core, from the pre-checks, the slots' arithmetic, honest tables, true functionals and true claims: L25's opening and depth premises are discharged |
| `IncTables`, `incChOf`, **`incDataAt`**, `incChOf_data` | stage IN-C's honest commitments; L29's `IncData` built at a start transcript |
| **`incVerify_of_tables`** | L29's executable `stage_in_c::verify` (the fields of `incVAt`: `maskField tag 4`, `pcsAt`) ACCEPTS the honest segment, from the slots' arithmetic, honest tables (`A`, `H`, the token endpoint), true functionals and true claims: L29's four opening and four depth premises are discharged |
| `OutcTables`, `outcChOf`, **`outcDataAt`** | stage OUT-C's honest commitments; L29's `OutcData` built at a start transcript, `own` comparing the carry's root with the honest boundary root |
| **`outcVerify_of_tables`** | L29's executable `stage_out_c::verify` (the fields of `outcVAt`: `maskField tag 8`, `pcsAt`) ACCEPTS the honest segment on the honest carry, from the slots' arithmetic, honest tables (`A`, `H`, the last boundary), true functionals and true claims (the carry's pending claims included) |

### 2.6 The openings as transcript programs (`HonestRunProg.lean`)

| Theorem / definition | Meaning |
|---|---|
| `sqsP`, `rhosP`, `absorbsP` with `final_*`, `sep_*` | the index squeezes, `zk_rhos` and the vectors' absorbs as programs |
| **`maskProg`**, **`final_maskProg_prove`** | `M`'s opening as a program after any prefix, the rows and functionals read off the prefix's data: it ends on `maskProve`'s transcript |
| **`pcsProg`**, **`final_pcsProg_prove`** | one commitment's opening as a program after any prefix: it ends on `pcsProve`'s transcript |
| `pcsProve_tr`, `maskProve_tr`, `sep_maskProg`, `sep_pcsProg` | the provers' final transcripts; the programs add no outside query |

### 2.7 The counts (`HonestRunCount.lean`)

| Theorem | Meaning |
|---|---|
| **`seq_zero`** | the sequential zero test behind stage IN-C's `kEmb + 1` sites (finding L29-3): a value built one coordinate at a time vanishes only at `α`'s draw or at ONE value of the first coordinate where it becomes zero |
| **`shield_k_le_inc`**, **`shield_refusal_total_le_inc`** | L25's Shieldstral count with IN-C's D66(3) as `kEmb + 1 ≤ 13` sites of at most `2^17` values: still at most `2^85` bad values, total at most `εcTarget = 2^-40` |

## 3. The `ClassifyOpen` fields

`AssembleClassify.lean`'s `ClassifyOpen`. **No field is discharged outright by this lane.** What changed:

| Field | Before (L29) | Now (L32) |
|---|---|---|
| O8 `parts` | CONTRACTS inside `IncOK`, `D12aBlockOK`, `OutcOK`: (i) the completeness of `M`'s test, the openings, the audits; (ii) canonical words, shapes, depths; (iii) each slot's arithmetic | (i) PROVED for `M` and every regular opening at every parameter set the run uses (`maskField_of_prove`, `pcsFieldR13_of_prove`, `pcsField_of_prove`, `pcsAt_of_prove`), given honest tables and TRUE claims / functionals. (ii) PROVED for the openings (`bOpen_*`, `bMask_*`); the slot proofs' words and the frame lengths are not. (iii) not started. For each kind of part the layers are assembled at the part's core: `blockVerify_of_tables_r13`, `incVerify_of_tables`, `outcVerify_of_tables`. The audits (`check_opening`, the boundary and endpoint audits) on the honest run are O9's, not O8's: they are refusals of the prover |
| O9 `refuse` | covered part by part given each part's prefix as a transcript program; open: (a) the openings as programs and the chain, (b) `define`, (c) `check_opening`'s challenge refusals, (d) IN-C's D66(3), (e) deterministic facts, `own` | (a) first half PROVED: the openings as programs (`maskProg`, `pcsProg`); the chain over the run is not built. (c) PROVED: `checkOpening_cover`, except the schedule audit's own two challenge-dependent refusals (L32-4). (b), (d), (e) unchanged |
| O10 `counts` | `δ = 0` for transcript-program sites; counts with margins | the new sites are `tprogSite`s (`δ = 0`); per opening the count is EXACT and proved (`openK_sum`: `p + n + 1`); IN-C's corrected count is inside the bound (`shield_k_le_inc`) |
| O1–O7, O11, O12 | as L18 / L19 / L26 / L29 | unchanged |

## 4. `εc` against `εcTarget = 2^-40`

| Term | What is proved | Value |
|---|---|---|
| each regular opening, `M`'s opening | `pcsVerify_of_prove`, `maskVerify_of_prove`: accepted at every oracle | `0` [PROVED] |
| `check_opening` of one commitment with `n` claims | `openSite_k`, `openK_sum`, `open_refusal_eq`: `n + 2` sites, `δ = 0`, `p + n + 1` bad values | `(p + n + 1)·fibC/|Dig| ≈ 2^-64` [PROVED per opening] |
| the run: `3L + 5 = 83` openings at `L = 26` | L18 §4.1's count of openings | `83·(p + n + 1) ≈ 2^70.4` bad values [ESTIMATE on the CODE count of openings and claims] |
| stage IN-C's D66(3) | `seq_zero` (the argument), `shield_k_le_inc` (the count) | `13` sites of at most `2^17` values at `d_pad = 4096` [the bound PROVED; the sites not built] |
| total | `shield_refusal_total_le_inc` | `≤ 2^-40` [PROVED at L25's margins]; about `2^-57.5` [ESTIMATE] |

## 5. Findings

No mismatch was found between the code's opening provers and verifiers and what the approved statements need;
`Statements.lean` is unchanged and no statement or target is weakened.

**L32-1 (Medium, for the assembly's shape; no statement change; for the coordinator and the next completeness lane):
the honest `H` opening needs the head's challenges, and the honest-data types do not give them to it.**
- CODE `protocol.rs:2434-2790` (`prove_core_after_with`): the helper commitment `H` is built AFTER `β, γ, α` are
  squeezed; its table is a function of them.
- L25's `CoreData` has `hRoot : Fp2 → Fp2 → Fp2 → Dig` (a function of the challenges) but
  `hOpen : List ZClaim → Tr → OpeningZk × Tr` (the claims and the transcript before the opening only). L29's
  `IncData` / `OutcData` are the same (`hRoot : List Fp2 → Dig`, `hOpen` without the challenges). The contracts
  `D12aBlockOK`, `IncOK`, `OutcOK` quantify over EVERY start transcript `t`, and the honest data is chosen before `t`
  (`D12aBlockP.core : (HIn → Dig) → St → X → Coins → ℕ → CoreData`).
- So for a start transcript other than the one the data was built for, `hOpen` opens a table that is not the one
  `hRoot β γ α` commits, and the claims are not true of it: the contract cannot hold for every `t`.
- Here: `coreDataAt` builds the honest `CoreData` PER START TRANSCRIPT (it recomputes `β, γ, α` from the transcript,
  `bgaOf`, with the same absorbs and squeezes), and `blockVerify_of_tables_r13` is stated for it; `incDataAt` and
  `outcDataAt` do the same for the stages.
- What the next lane needs: honest parts whose data is a function of the start transcript (a `SegP` whose `run`
  builds `coreDataAt … t`; the stage provers on `incDataAt … t` / `outcDataAt … t`). L18's `RunP` takes the parts
  as free `SegP`s, so this needs no change to L18's or L25's files; L25's `d12a_block_complete` and L29's
  `inc_stageInOK` / `outc_stageOutOK` are re-proved for the new parts by the same steps. The same remark as L25-1
  (`own`): the alternative is to restrict `SegComplete` to the transcripts the honest run reaches.

**L32-2 (Low, completeness; code; for the coordinator): `open_zk` asserts, it does not refuse.** CODE
`pcs.rs:1006-1021` (`assert_mask_sites`, called by `open_zk` :1045): the prover PANICS if a group's combined weights
touch no mask row or the proximity weights miss the proximity mask row. A panic of the honest prover is a
completeness failure that the Lean prover (`pcsProve`) does not model. It cannot fire after `check_opening` accepted
[CODE reasoning: the audit gives every claim its own reserved pair with independent weights, every member
coefficient is nonzero, and the proximity pair is independent, protocol.rs:249-323]. Not proved in Lean: a theorem
"`checkOpeningExec = ok` implies the assertion's two conditions" would close it.

**L32-3 (Info, modelling, as L10-1 and L25-7): what the honest provers compute.** The Lean honest commitment is
specified by the encoder's values (`ColsHonest`; `mCol` for `M`), and `M`'s `q'` and proximity words are the
canonical words of the true coefficients (`polyWords`). The code computes all of them by NTT. That the two agree is
TESTED only indirectly (L10's corpus: the code's honest openings pass the same Lean verifier). The regular opening's
clear vectors (`combVec`) are computed on the words, as the code does.

**L32-4 (Low, completeness arithmetic, L25-2 unchanged): the schedule audit's two challenge-dependent refusals are
still named events.** `audit_claims` refuses on a zero terminal mask coefficient and on a claim's reserved pair
weights dependent over the base field (protocol.rs:269, :291). Both are functions of the slots' challenges, not of
the opening's draws. In `checkOpening_cover` they stay inside the named event "the audit refused". Making them sites
needs the claims' coefficients as functions of the slot challenges (the slots' `define`).

**L32-5 (Low, for the next lane): stage IN-C's `kEmb + 1` sites are counted, not built.** `seq_zero` is the
argument; `shield_k_le_inc` the count. Building the sites needs (1) `IncPub.embFold` read in the field as a function
affine in each coordinate of `r_emb` when the later coordinates are zero (a premise on the embedding fold: true of a
multilinear extension), (2) stage IN-C's head up to each draw as `drawProg j pre` (this lane's `drawAt` machinery
applies: the head's draws `β, γ, α, r_1, …` are consecutive squeezes), (3) the link from L29's word-level guard
`incAlphaBad` to "some row's value is zero".

**L32-6 (Info): an opening's site family is indexed by the schedule, not by the challenges.** The grouping of the
claims can depend on the challenges; the number of member draws cannot: it is the number of claims
(`openingGroupsAt_sum`). So `openSite` is indexed by the claim count `n`.

**L32-7 (Info, L18-3 made exact): the dependent-proximity refusal has exactly `p` bad values** given a nonzero first
coefficient (`lineBad_card`, `det_zero_line`), plus one for a zero first coefficient: `p + 1`, where L18 wrote
`p ≈ 2^64`.

## 6. What is left, by name

**O8 (each part's honest segment is accepted).**
- `SlotsSum` (block, L25) and `StSlotsSum` (stages, L29): each slot's masked polynomial has the round degree and its
  claimed sum is the true sum, along the honest run. 23 slots per R13 block, 12 for the two stages. Not started.
- For every commitment the run opens: `ColsHonest` (the committed columns are the encoder's values: the honest
  commitment's definition), `MHonest` (`M`'s degrees, `b`'s zero sum), `ClaimTrue` for every claim the accumulator
  leaves and for `logup_sum_claim`, and the functionals' truth (`mTrue`) for `M`. The last two are arithmetic of the
  same kind as `SlotsSum`: the terminal values the slots publish are the committed tables' evaluations.
- The boundary opening of a block (`bndOpen`: a regular opening at the boundary's parameters, as stage OUT-C's
  `B_out` here), and the three part theorems lifted from the core to the framed part (`SegComplete`).
- The codec contract's remaining parts: `SlotCanon` and the slot part of `CoreShape` (the honest slot proofs' words
  and counts), `CloseOk`, the counted lengths.
- Transcript-aware honest parts (finding L32-1).
- The profile's finite facts: `preChecks`, the path depths (`aPath = hPath = 16`, `maskPath = 12` at R13), the
  degrees `1 ≤ d < p`.

**O9 (the honest prover refuses only at listed sites).**
- (a) The chain: the run's prefix up to each part as ONE transcript program. Built: every piece of one part. Not
  built: the commitments' Merkle roots as `RootProg`s for this lane's `rootOf` (L29's cover theorems take them as
  premises), the frames between the parts, the composition over IN-C, 26 blocks, OUT-C, and from it
  `classify_refuse_of_cover`'s premise.
- (b) Per instance: `define` refuses only on a zero batching draw; the builder never fails.
- (c) The schedule audit's two challenge-dependent refusals as sites (L32-4).
- (d) Stage IN-C's `kEmb + 1` sites (L32-5).
- (e) The deterministic facts: the group count is the declared one, the geometry has a proximity pair
  (`prox + 1 < rows`), the grouping does not refuse, the functional count, the schedule checks (L25-4, L29-5);
  `own = true` along the run (L25-1).
- The assertion of L32-2.

**O10.** Follows O9's site list. The per-opening count is exact; the counts of openings, slots, hosts and LogUp
domains per run are CODE counts.

**At which instance.** Every theorem here is about the executable verifiers: `pcsFieldR13` / `maskField` /
`checkField` are the fields of L17's R13 block profile, `pcsAt` the stages' in L29's `classifyProtocolExec`. Lane
L26's corrected instance `classifyProtocolU` changes `opensIn` only; `completeU_of_complete` transfers `Complete`.
So `Complete` at `2^-40` for the classify run holds at either instance from: L18's `ClassifyOpen` fields O1–O7, O11
as before, and O8, O9, O10 from the premises listed above. No new assembled theorem is stated: the assembled theorem
is still L18's `classify_complete_target`.

## 7. Checks

All through the zk60 resource guard (class cpu, need 14 GiB, cap 24 GiB, `run_guarded.py`), logs and `.done` markers
in `results/zk60_lean_l32_20261109/`. The heavy lock was shared with the app lane's GPU runs and lanes L30, L31, L33.

- `iter1.log` (18 s; waited about 25 minutes for admission): `HonestOpenPcs.lean`, two rewrite errors (a pattern
  stated through a definition the goal had not unfolded) and one unused `simp` argument.
- `iter2.log` (34 s): `HonestOpenPcs.lean` green. `HonestOpenM.lean`: "maximum recursion depth" twice. Cause: to
  compare a structure projection with `polyWords` (a `List.ofFn` over `1024` positions) the unifier unfolded the
  list. Fix: the projections are reduced first, and `polyWords` is marked irreducible after its four lemmas.
- `iter3.log` (81 s): `HonestOpenM`, `HonestOpenSites`, `HonestRunCount`, `HonestRunCover` green.
  `HonestOpenFields.lean`: four `whnf` timeouts in the `bMask_*` lemmas. Cause: the unifier evaluated `M`'s index
  squeezes (`challenge_indices(256, 4096)`, both numbers literal) under a `List.map` over the opened columns. Fix: the
  lemmas go through `ofMO` generically (`ofMO_canon`, `ofMO_shape`, `bMask_fst`), and `mIdx` is marked irreducible
  after `maskProve_eq`. `HonestRunProg.lean`: "maximum recursion depth" in `final_maskProg_prove`.
- `iter4.log` (61 s): nine modules green. `HonestRunProg.lean`: the same place. Cause: the unifier unfolded `runOps`
  over the `64` index squeezes before reducing the other side's projection. Fix: `final_done_fst`, `final_done_snd`,
  `mT2_eq` make the two sides the same term before `rfl`.
- `iter5.log` (ONE guarded job, 82 s, peak RSS 3.73 GiB, waited 388 s): the ten modules, each built on its own, then
  `check_l32.sh` (`check.log`, 52 s):

| Gate | Result |
|---|---|
| each L32 module built on its own (`prebuild_*.log`) | ten, green, **0 warnings** |
| full `lake build` of the library (`full.log`) | green, **3,601 jobs, 0 warnings, 0 errors, no `sorry`** |
| axiom audit (`gen_axioms.py` → `axioms_l32.lean` → `axioms.log`: every `theorem`, `def` and `structure` of the ten files) | **192 declarations** (126 theorems: Pcs 35, M 21, Fields 18, Sites 15, RunBlock 2, RunProg 16, RunCount 7, RunCover 9, StageIn 2, StageOut 1; 60 definitions; 6 structures): 115 on `[propext, Classical.choice, Quot.sound]`, 54 on `[propext, Quot.sound]`, 3 on `[propext]`, 20 on none; no `sorryAx`, no `Lean.ofReduceBool`, no other axiom |
| source scan of the ten files (`sorry`, `axiom`, `native_decide`, `admit`, `maxRecDepth`, `maxHeartbeats`, `implemented_by`, `extern`, `bv_decide`, `ofReduceBool`) | **none** |
| the root imports the ten files | yes |
| `Statements.lean`; existing files under `formal/` changed since the base `6e788dcb` (the root's import lines apart); lines removed from the root; files changed under `ops/` or `apps/` | unchanged; **0**; **0**; **0** |
| regressions on their committed corpora: L6Check / L5Check / L11Check / fixture L1 | **1,206 / 5,553 / 404 / 101,956 checks, 0 failed** |
| name clashes with every other Lean file of every worktree (`l32_nameclash.py`, `l32_nameclash.log`) | 192 declarations, **0 clashes** over 41 worktrees |

Not run here: the corpus checkers `ExecBlockCheck`, `CheckR13Block`, `StageCheckOutC`, `ProtocolClassifyCheck`,
`StageVerifyExecCheck` (this lane changes no file they read, and adds no checker against the Rust code: its honest
provers are specifications of the code's, finding L32-3).

**L32-8 (Info, for the Lean lanes): literal sizes make the unifier compute.** `M`'s constants are literals (`1024`
coefficients, `256` indices out of `4096`, `64` squeezes). A definition that recurses over them (`List.ofFn`,
`challenge_indices`' loop, `runOps` over a replicated list) is evaluated by the unifier whenever it meets a
projection or a `List.map` it cannot match at once: "maximum recursion depth" or a `whnf` timeout, far from the cause.
What worked: prove the definition's lemmas, then mark it irreducible; state transfer lemmas generically (over any
opening) and instantiate; make both sides of a `rfl` the same term by explicit unfolding lemmas first. This is the
same family as finding L7-4 (the literal Goldilocks prime).
