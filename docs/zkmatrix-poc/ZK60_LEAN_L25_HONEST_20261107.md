# D63 lane L25: the classify run's honest provers, their completeness contracts, the refusal sites and their counts (2026-11-07)

Lean lane L25 (Claude), on its own worktree branched from perf at `99c4dc30` (lanes L9–L21 and L18 merged). Lean 4.34.1,
Mathlib v4.34.1, no new dependency. Five new library files under `formal/ZK60Formal/`, imported by the library root:
`HonestClassifySum.lean`, `HonestClassifyBlock.lean`, `HonestClassifyRun.lean`, `HonestClassifyCount.lean`,
`HonestClassifyLinks.lean`. No Rust; `Statements.lean` and every production source are unchanged. Existing Lean files
are unchanged except the root's import lines and ONE line of `ExecBlockVerify.lean` (`slotAcc`'s host functional: lane
L23's fix L23-1, carried at the coordinator's direction and reconciled by the coordinator at merge; finding L25-6).
Evidence: `results/zk60_lean_l25_20261107/`.

Labels: **PROVED** (a Lean theorem, axioms at most `propext`, `Classical.choice`, `Quot.sound`), **CODE** (read off the
sources, file:line, 2026-11-07), **ESTIMATE** (arithmetic or reasoning not proved in Lean), **CONTRACT** (a named
premise a component lane must discharge).

## 1. In plain words, for Victor

**What this lane is.** Lane L18 assembled your D63 gate `ProductionReady` for the media app's classify run from 15
named open obligations (`ClassifyOpen`). Three of them need the HONEST prover, of which there was no Lean model: O8
(each part's honest segment is accepted), O9 (the honest prover refuses only at listed places) and O10 (how often those
refusals can happen, and that each is a fresh coin flip). O12 (zero knowledge) also asks for honest-prover properties.
This lane writes the honest prover down in Lean, part by part, in the code's own order, and proves what it can.

**What now exists.**
- **The honest sumcheck, against the code's own verifier.** For any polynomial of the right degree, the Lean honest
  prover's round values are accepted by the executable `sumcheck::verify` (L6's mirror of the Rust) at EVERY hash
  function, and it lands on the same transcript as the prover. The masked (`--zk`) version too. So the 600-odd
  sumchecks of a classify run contribute nothing to the completeness error. PROVED.
- **The honest block prover.** One block's core prover (`prove_core_after_with`) as a Lean specification: the same
  absorbs and squeezes as the verifier, slot by slot, the two challenge refusals of each slot (`c = 0`, a degenerate
  `e`) exactly where the code has them, then `M`, `A` and `H`'s openings. PROVED: L9's executable block verifier
  `verify_core` ACCEPTS this prover's core, given (i) each slot's arithmetic (its polynomial has the right degree and
  its claimed sum is the true sum) and (ii) the three openings' own completeness (L10's components). Generic in the block
  shape, so it covers R13 (the app's profile) and W16R2.
- **The run's parts.** Stage IN-C, every block of the D12a run and stage OUT-C as honest `SegP`s, and L18's per-part
  completeness contract `SegComplete` PROVED for each from its components' contracts; for a block, L17's segment codec
  is discharged by L17's own theorem. Then O8 in exactly the form `AssembleClassify.lean` names, from those contracts.
- **Where the honest prover refuses.** PROVED: the honest run refuses ONLY where one of its parts refuses, a block only
  where a slot's `define` refuses, `c = 0`, a degenerate `e`, `check_opening` of `A`, `H` or the boundary refuses, or a
  deterministic schedule check fails. Then O9 in its exact form, from the cover of those places by the listed sites.
- **The freshness `δ` is now a theorem, `δ = 0`.** L18 argued that every refusal's challenge is a fresh coin flip. PROVED
  here for every site whose computation is written as the transcript up to it (with the Merkle-type queries it needs):
  the challenge point is never asked earlier, at every hash function. The proof is the counter argument (every earlier
  squeeze has a smaller counter; absorbs are at least 48 bytes, squeezes exactly 47). Writing each of the run's sites in
  that form is the next step (L25-3).
- **The counts.** PROVED: at the Shieldstral run's counts (with a wide margin on every count) the refusal sites have at
  most `2^85` bad values in total (in fact below `2^72`), and with `δ = 0` the completeness error is within your
  approved `εcTarget = 2^-40` (it is about `2^-57.5`).

**What it does not do.** The parts' completeness is reduced to named contracts, not closed: the stage verifiers are
still parameters of L18's instance (no executable IN-C / OUT-C verifier in Lean), and the openings' completeness
(L10's `pcs::verify_zk_tagged`, `M`'s `mask_verify_tagged`, the boundary opening) is not proved at the executable level.
The honest prover is a functional specification; its oracle form for O12's counts (`pOC` in L14's `FSModel` form) is not
built, so most of L19's honest-prover hypotheses stay open; this lane discharges the "honest rounds" ones (zero gaps, a
standalone's sum `0`, the terminal) in L19's coefficient form. The run's ZK as one receipt stays capped at
`R ≤ 2^112` (L19-2, your ruling).

**One thing worth your attention (finding L25-1).** L18's per-part contract `SegComplete` asks each part to be accepted
for EVERY carry it is handed. A block's opening of the previous boundary can only be accepted for the honest carry. So
the Lean honest block prover checks that the carry is its own and refuses otherwise (it never refuses on the honest
run). No statement changes; the assembly's form is kept.

## 2. What is proved

All PROVED (`results/zk60_lean_l25_20261107/`): the theorem counts and the axiom audit are in §7.

### 2.1 The honest sumcheck, executable (`HonestClassifySum.lean`)

CODE: `zkp-core/src/sumcheck.rs` `prove` / `verify`; the masked arm of `run_slot`, argument.rs:1262-1420. The prover and
the verifier share the transcript: per round the `d + 1` words absorbed under `"sc-round"`, then one squeeze.

| Theorem / definition | Meaning |
|---|---|
| `WProver`, **`scProve`**, `scProve_length`, `scChal_scProve` | a strategy of round WORDS (the executable twin of `SoundSumcheck.lean`'s `Prover`); the prover's run on the transcript; the verifier's challenge walk (`scChal`) ends on the prover's transcript |
| `WHonest` | the words are canonical, `d + 1` per round, and read in `K` are the TRUE round polynomial's values (`Complete.honestMsg`), at every canonical challenge |
| `whonest_rounds`, **`scProve_accepts`** | the honest run's list transcript passes `scAccept` for the TRUE claim `Σ f` (`honestMsg_check`, `interpEval_honestMsg`) |
| **`scVerify_honest`** | L6's executable `sumcheck::verify` returns `Ok (fin, rs)` on the honest rounds, `rs` the transcript's challenges, `fin = f(rs)` in `K`, and leaves the prover's transcript: at EVERY hash function and from EVERY transcript |
| **`scVerify_honest_masked`** | the same for `f + c·g` on the claim `S + c·G` (the `--zk` sumcheck), every mask, every `c` |
| `ofK`, `ofK_canon`, `toK_ofK`, `honestWords`, **`honestW`**, **`honestW_honest`**, `scVerify_honest_exists` | for every `f` of individual degree `≤ d` the honest strategy exists (the canonical words of the true values; `toK` is a bijection on canonical words when `fp2 U` is), and the code's verifier accepts it |

### 2.2 The block core's honest prover (`HonestClassifyBlock.lean`)

CODE: protocol.rs `prove_core_after_with` :2434-2790 (the roots, `β, γ, α`, `H`'s root, the slots, `zk::mask_open`,
`check_opening` and `pcs::open_zk` of `A`, then `H` with `logup_sum_claim`), argument.rs `run_slot` :1153-1505 (shared by
both sides) and `argument_with` :3000-3075 (the hosts' functionals and the functional count, both sides).

| Theorem / definition | Meaning |
|---|---|
| `SlotData`, `slotT2`, `slotC`, `slotT4`, `slotSP`, `slotRho`, **`slotProve`** | one slot of the honest prover: `define` (the shared public function), `c` (REFUSED when zero), the slot proof (scalar, the rounds by `scProve`, the terminals), the degenerate-extension refusal, then the shared bookkeeping (`slotDefChecks`, `hostedSum`, `tabVals`, `slotAcc`) and the transcript after `pb-term` |
| `SlotSum` | the slot's ONE arithmetic obligation: the words are the honest strategy of a polynomial `F` (the slot's masked `f + c·g`) of individual degree `≤ d`, the claimed sum the verifier computes (`scalar + Σ κ·scalar_h`) is canonical with value `Σ F`, the terminal count is the schedule's |
| `polySlotData`, **`slotSum_of_poly`** | with the words built by `honestW`, `SlotSum` is the slot's arithmetic alone (degree, true sum, terminal count): `WHonest` is discharged by construction |
| **`slotStep_of_prove`** | L9's `slotStep` ACCEPTS the honest slot proof and returns EXACTLY the prover's record, accumulator and transcript, whenever the prover did not refuse and `SlotSum` holds |
| `slotsProve`, `SlotsSum`, **`slotsLoop_of_prove`** | the same for the slot loop (`SlotSum` at every state the honest loop reaches) |
| `CoreData`, `CoreRun`, `coreT2`, `coreB`, `coreG`, `coreA`, `coreT3`, **`coreProve`**, `coreProve_ok` | the block core's honest prover and its run's facts |
| **`blockVerify_of_prove`** | L9's executable `verify_core` (`blockVerify`) ACCEPTS the honest core and returns its IO claims and the prover's final transcript, given: the profile's pre-checks; the honest openings' path depths (T-4); `SlotsSum` along the run; and the completeness of `M`'s `mask_verify_tagged`, `A`'s and `H`'s `verify_zk_tagged` on the run's own functionals and claims (CONTRACTS: L10's components). Generic in `BlockParams` (R13 and W16R2 instances) |
| **`slotProve_refuses`**, `slotsProve_refuses`, **`coreProve_refuses`** | the honest core prover refuses ONLY at: a slot's `define` refusal, `c = 0`, a degenerate `e`, a deterministic schedule failure (`slotDefChecks`, a hosted index, a table length), the functional count, or `check_opening` of `A` / `H` |

### 2.3 The run's parts (`HonestClassifyRun.lean`)

CODE: classify_run.rs `prove_classify_run_with` :185-330 (per part the start tag, the part, the end tag, the frame; per
block the framing absorbs, `prove_core_with`, `powner.into_opening` = `boundary::check_opening` then the opening of the
PREVIOUS boundary the prover owns, boundary.rs:275-290).

| Theorem / definition | Meaning |
|---|---|
| `StageInP`, `inSegP`, `StageInOK`, **`inSeg_complete`** | stage IN-C's honest part and L18's `SegComplete` for it from two CONTRACTS (its frame decodes back; `stage_in_c::verify` accepts the honest segment) |
| `StageOutP`, `outSegP`, `StageOutOK`, **`outSeg_complete`** | the same for stage OUT-C (`stage_out_c::verify` on the carry) |
| `D12aBlockP`, `d12aFrame`, **`d12aBlockSegP`** | the honest block part of the D12a run at ANY block profile `Pk`: the carry check (`own`, L25-1), `coreProve` on the run's frame, the boundary audit (refused as the verifier refuses), the opening of the previous boundary, L17's `encSeg`, the carry `(io_out, B_{k+1})` |
| `D12aBlockOK`, **`d12a_codec_of_enc`**, **`d12a_block_complete`** | `SegComplete` of a block part against L18's `d12aBlockProf` (L17's `decodeSegment`, L9's `blockVerify`); the codec contract is DISCHARGED by L17's `decodeSegment_enc` from the canonical words and the segment's shape |
| `honestRunP`, `forall₂_parts`, **`parts_complete`**, **`classify_parts`**, **`classify_parts_d12a`** | ClassifyOpen's field O8, in EXACTLY `AssembleClassify.lean`'s form, from the three parts' contracts; `classify_parts_d12a` for the D12a run (blocks through `d12aBlockProf`) |
| **`proveSegs_refuses`**, **`honestSegs_refuses`**, **`d12aBlockSegP_refuses`** | the honest run refuses only where stage IN-C, a block or stage OUT-C refuses at its own state; a block only where its carry is not its own, its core refuses, or the boundary audit refuses |
| **`classify_refuse_of_cover`** | ClassifyOpen's field O9 in its exact form, from the cover of the run's refusals by the listed sites |

### 2.4 The freshness `δ` and the counts (`HonestClassifyCount.lean`)

| Theorem / definition | Meaning |
|---|---|
| `squeezeMsg_length`, `absorbMsg_length`, `squeezeMsg_inj` | a squeeze input is 47 bytes, an absorb input at least 48; two squeeze inputs with the same bytes have the same counter |
| `TProg`, `TProg.final`, `TProg.Sep`, `TProg.NoWrap`, `TProg.askQ`, `TProg.sqPoint`, `TProg.oc`, `askQ_run`, **`oc_run`**, `final_key`, `final_counter_ge`, `Below`, `queries_askQ`, `queries_below` | a site's computation as a transcript program (absorbs and squeezes of ONE transcript, outside queries separated by key or length), as an oracle computation on L5's `QB Lq`; it runs the transcript semantics under `liftH` |
| **`tprog_point_fresh`**, **`tprog_delta_zero`** | the site's squeeze point is NEVER asked by its own computation, at every oracle: `δ = 0` |
| `tprogSite`, `tprogSite_delta`, **`tprogSite_fires`** | L18's `Site` from a transcript program, `δ = 0` PROVED; it fires exactly when the challenge read at the program's next squeeze is bad |
| `isZero_iff_toK`, **`slot_c_guard_iff`**, **`degenerate_guard_iff`** | the honest slot prover's two guards are such events, bad sets `{0}` (`k = 1`) and `{0, 1}` (`k = 2`) |
| **`slotProve_refuses_sites`** | a slot of the honest prover refuses only at `define`'s refusal, the CFS challenge (the squeeze after `pb-slot`) in `{0}`, an extension challenge in `{0, 1}`, or a deterministic schedule failure: the refusal cases in the sites' form |
| `kPer`, `SiteIdx`, **`siteK_sum`**, **`shield_k_le`** | the bad values per site by kind; at the Shieldstral run's counts with a margin on every count, `Σ k ≤ 2^85` |
| **`classify_counts`** | ClassifyOpen's field O10 in its exact form, `δOf = 0`, for sites with `δ = 0` (transcript programs) |
| **`shield_refusal_total_le`** | the completeness total `Σ (k·fibC/|Dig| + δ) ≤ εcTarget` at those counts |

### 2.5 For O12: the honest rounds in L19's coefficient form (`HonestClassifyLinks.lean`)

| Theorem / definition | Meaning |
|---|---|
| `coeffsOf`, `peval_coeffsOf`, `roundCo`, `peval_roundCo`, `roundSum_roundCo`, **`honestCo`** | the honest prover's round polynomials along the challenges in L19's coefficient form (the interpolants of `HonestClassifySum.lean`'s words) |
| **`chainDefect_honestCo`** | their chain defects are `(Σ f, 0, f(r))`: true claimed sum, zero gaps, terminal `f(r)`, every `r` |
| **`chainDefect_honestCo_masked`** | the rounds the code SENDS (`s_j + c·g_j`, the CFS mask's rounds) have defects `(Σ f + c·G, 0, f(r) + c·g(r))` |
| **`slotDefect_honestCo`** | L19's `slotDefect` of the honest rounds is `(0, 0, f(r))` for either kind: `slotDefect_honest`'s premises `hmid`, `hsum`, `hT` DISCHARGED from the polynomial |

## 3. The `ClassifyOpen` fields

`AssembleClassify.lean`'s `ClassifyOpen R Lq V P Cin h64 hr hon U site kOf δOf E εin εblk εout εep εzk`:

| Field | Before (L18) | Now (L25) |
|---|---|---|
| O8 `parts` | open, not started | **reduced to named CONTRACTS** by `classify_parts` / `classify_parts_d12a`: with `P` the honest run's parts (`inSegP`, `d12aBlockSegP`, `outSegP`), O8 holds from `StageInOK`, each block's `D12aBlockOK` and `StageOutOK`. Inside `D12aBlockOK` the sumchecks are DISCHARGED (`scVerify_honest`), the slot words' honesty is DISCHARGED by `polySlotData` (`slotSum_of_poly`), the codec is reduced by `d12a_codec_of_enc` (L17's `decodeSegment_enc`) to the honest segment's canonical words, shape and counted length; what stays is each slot's arithmetic (degree and true claimed sum along the run), the profile's pre-checks and depths, the three openings' and the boundary opening's completeness, and the stages' verifiers. Not discharged outright: the stage verifiers are parameters of L18's instance, and L10's executable openings have no completeness proof |
| O9 `refuse` | open | **reduced** by `classify_refuse_of_cover` to the cover premise; the refusal structure is PROVED (`honestSegs_refuses`, `d12aBlockSegP_refuses`, `coreProve_refuses`, `slotProve_refuses`); the two slot guards are PROVED to be site events (`slot_c_guard_iff`, `degenerate_guard_iff`). Open: the site OCs of the honest run as transcript programs (the run's oracle form), the stages' refusals, and the deterministic schedule facts of the registered profile (L25-4) and `own = true` along the run (L25-1) (L25-3) |
| O10 `counts` | count ESTIMATE, `δ` argued | **`δ` PROVED `= 0`** for every transcript-program site (`tprog_delta_zero`, `tprogSite`); the count `Σ k ≤ 2^85` PROVED at the Shieldstral counts with margins (`shield_k_le`); O10 in its exact form by `classify_counts`. The counts per kind remain CODE counts (L18 §4.1) |
| O12 `zk` (L19's honest-prover hypotheses) | open | the "honest rounds" hypotheses (zero gaps, a standalone's sum `0`, the terminal) DISCHARGED in L19's coefficient form (`slotDefect_honestCo`, `chainDefect_honestCo_masked`). Open: `hπ`, `hout`, `hclaim` (masked terminals as claim values), the honest host sums and hand-off, `hlay` / `hMK`, the openings' coin and weight conditions, the counts by kind (`hKw`, `hKc`, `hUw`, `hwb`, `hwba`) with the column digests as programmed points (L19-3): they need the prover's `FSModel` / `pOC` form, not built (L25-3). The cap `R ≤ 2^112` for the run as one receipt stays (L19-2) |
| O1–O7, O11 | as L18 | unchanged |

## 4. `εc` against `εcTarget = 2^-40`

| Term | What is proved | Value |
|---|---|---|
| the sumchecks | `scVerify_honest`: accepted at every oracle | `0` |
| the slot guards (`c = 0`, degenerate `e`) | `slot_c_guard_iff`, `degenerate_guard_iff`: site events with `k = 1`, `k = 2` | `k·fibC/|Dig|` each (L18's `Site.prob_le`) |
| the freshness `δ` of every transcript-program site | `tprog_delta_zero` | `0` |
| the total at the Shieldstral counts | `shield_k_le`: `Σ k ≤ 2^85` (below `2^72`); `shield_refusal_total_le`: `≤ εcTarget` | about `2^70.5·2^-128 ≈ 2^-57.5` [ESTIMATE on the CODE counts; the bound `≤ 2^-40` PROVED] |

The dominant term is unchanged from L18-3: the openings' dependent-proximity refusal, `p` bad values per opening.

## 5. Findings

No mismatch between the code's honest prover and the approved statements was found; `Statements.lean` is unchanged and
no statement or target is weakened. The prover's transcript order is the verifier's in every part read (CODE: the slot
routine `run_slot` is shared by both sides; `prove_core_after_with` opens `M`, then audits and opens `A`, then `H`, as
`verify_core` checks them; `prove_classify_run_with` frames each part with the start and end tags the verifier
compares).

**L25-1 (Medium, for the assembly's shape; no statement change): L18's `SegComplete` quantifies over every carry, and a
block can only be complete for its own.**
- CODE (classify_run.rs:302-329, boundary.rs:275-290): the honest prover opens the PREVIOUS boundary from its own state
  (`powner.into_opening`, the owner data of the boundary it committed), with the claims `pending ++ io_in` it carries
  itself; the verifier checks that opening against the carry's root and pending claims.
- L18's `SegComplete p v` asks, for EVERY carry `cr` and every transcript, that the part's honest segment be accepted.
  For a carry that is not the prover's own (another root, or false pending claims) no honest opening exists, so no
  prover that ignores its carry meets O8 in L18's form.
- Here the Lean block prover checks that the carry is its own (`D12aBlockP.own`) and refuses otherwise; on the honest
  run the carry IS its own, so it never refuses there, and O8 becomes satisfiable. The cost is one deterministic item
  in O9's cover: `own = true` along the honest run. Stage OUT-C's opening of `B_L` has the same property (its prover
  is a parameter, `StageOutP.prove`, which may make the same check). Alternative: restrict `SegComplete` to the carries
  the honest run reaches (a change to L18's definition, not made).

**L25-2 (Low, completeness arithmetic): `check_opening`'s schedule audit has challenge-dependent refusals that L18
§4.1 does not list.**
- CODE protocol.rs:240-305 (`audit_claims`): "zero terminal mask coefficient; discard attempt" (:269) when a reserved
  pair's part coefficient is zero, and "a claim's reserved pair weights are dependent over the base field" (:291).
- The first cannot fire once the degenerate-extension guard has passed: the pair's coefficient is
  `e_r·Π_{j>r}(1 − e_j)`, nonzero when every `e` is outside `{0, 1}` [CODE reasoning]. The second fires when the pair's
  induced row weight `w` is zero (the pair's weights are `w` and `u·w`, whose determinant is the norm of `w`): a few bad
  values per claim [ESTIMATE; `pcs::zpart_row_weight` is not modelled].
- In the Lean spec both are among `check_opening`'s refusals (`coreProve_refuses`), so O9 covers them; their count is
  inside `shield_k_le`'s margin for kind 1 (`2^20` sites).

**L25-3 (Info, the next step for O9, O10 and O12): the honest prover's oracle form.** The honest prover here is a
functional specification over a hash function (`HIn → Dig`). O9's cover premise, O10's per-site `δ = 0` (through
`tprogSite`) and O12's `pOC` / `FSModel` hypotheses (the counts by kind `hKw`, `hKc`, `hUw`, `hwb`, `hwba`, the coin map
`hπ`, the receipt off the view `hout`) all need it as an ORACLE computation: each site's prefix as a `TProg`, the whole
run as a query-bounded `OC`. `TProg` and `tprog_point_fresh` are the machinery; writing the run's prefixes in it is
mechanical but long (every absorb and squeeze of IN-C, 26 blocks and OUT-C), and was not reached.

**L25-4 (Info): the honest prover's deterministic refusals.** Besides its challenge sites the honest prover refuses on
deterministic schedule checks: a slot's table length (argument.rs:1236), the slot schedule checks (:1158-1172, both
sides), the hosted index, the functional count (:3071, both sides), the sealing pass (classify_run.rs:209-232). They are
not challenge sites (no `k`, no `δ`): O9 needs them excluded for the registered profile as finite facts. L18's site
list does not mention them; `coreProve_refuses` lists them.

**L25-5 (Info, `δ = 0`, L18-4 made precise and proved).** L18-4's argument is right with one refinement: a site's
computation is the MAIN transcript up to it plus the outside queries that feed it (the roots' Merkle, leaf and
column-digest queries); the CLONES (each segment's position tags, `check_opening`'s replay) are not part of it, because
nothing they output is absorbed. Then `δ = 0` exactly (`tprog_point_fresh`), given the separations the code has [CODE]:
an absorb's input is at least 48 bytes and a squeeze's exactly 47; the run's start message is `"hashline-v1/" ‖
profile` (`protocol::tagged_transcript`, classify.rs:1277: 84 bytes for the Shieldstral profile string); the Merkle,
leaf and column hashes are under their role tags (D19 T-1); fewer than `2^64` squeezes.

**L25-6 (Info, coordination with L23-1).** The honest block prover's `M` functionals are the shared bookkeeping's
(`slotAcc`, as the code's `run_slot` computes them on both sides). At the coordinator's direction this worktree carries
lane L23's one-line fix L23-1 in `ExecBlockVerify.lean`'s `slotAcc` (a host's `Γ` uses each HOSTED slot's own
`sum_weights`, argument.rs:1500); every L25 theorem is generic in `slotAcc` and holds with either line. The coordinator
reconciles the line with L23's at merge.

**L25-7 (Info, modelling): the masked rounds.** The spec's round words are the TRUE round values of the masked
polynomial `f + c·g` (`honestW`); the code computes the CFS mask's rounds in coefficient form and adds them
(`CfsMasker::mask_round`; ExecCfs's `toK_roundBody`, `toK_maskRound`). `chainDefect_honestCo_masked` shows the code's
form is an honest chain of the same polynomial; the two are the same values by `interpEval_peval` (ExecCfs). A theorem
equating the code's words with `honestW`'s word for word is not written.

## 6. What is left

- **O8**: the CONTRACTS of `D12aBlockOK` per block (each slot's arithmetic along the honest run: the masked
  polynomial's degree and the claimed sum's TRUE value, `slotSum_of_poly`; the profile's pre-checks and path depths;
  the completeness of `M`'s `mask_verify_tagged`, `A`'s and `H`'s `verify_zk_tagged` and the boundary opening, L10's
  executable functions, from L3's model completeness `opening_complete` / `mopening_complete` and L10's
  `pcsVerify_ok_iff` / `maskVerify_ok_iff`); stage IN-C's and OUT-C's honest provers and executable verifiers (still
  parameters of L18's instance).
- **O9**: the cover premise of `classify_refuse_of_cover`: each refusal case of `honestSegs_refuses` /
  `d12aBlockSegP_refuses` / `slotProve_refuses_sites` as a site of `tprogSite` form (L25-3), the deterministic schedule
  facts (L25-4), `own = true` along the run (L25-1), and the stages' refusals.
- **O10**: per-site `δ = 0` needs the sites built by `tprogSite` (L25-3); the per-kind counts stay CODE counts.
- **O12**: L19's hypotheses other than the honest rounds (L25-3); the cap `R ≤ 2^112` for the run as one receipt
  (L19-2, Victor's ruling).

## 7. Checks

All through the zk60 resource guard (class cpu, need 14 GiB, cap 24 GiB, `run_guarded.py`), logs and `.done` markers in
`results/zk60_lean_l25_20261107/`. The heavy lock was shared with lanes A27, L23 and the coordinator's merges: the
prebuild waited 3,922 s for admission, iteration 2 waited 5,774 s.

- `prebuild.log`: the fresh worktree's first build, the root's modules one target at a time (`prebuild.sh`): 595 s,
  peak RSS 7.4 GiB; every existing module built; the L25 modules failed at their first error (below).
- `iter1.log` … `iter6.log`: the L25 modules while they were written (`stage.sh`). The errors fixed on the way:
  `simp` unfolding `List.ofFn` into a cons (replaced by `List.getElem?_ofFn` and a `split`); a recursive call missing a
  binder before the colon (twice); `split at h` failing dependent elimination on `match … = .ok (vars)` (replaced by
  `cases h : … with` and `simp only [h] at h'`); `split_ifs` closing its contradictory branches itself; the do-block of
  `verify_core` placing each continuation INSIDE the sub-check's `match` (seen in the error, then `simp only [hM']`);
  `Fin (0 + 1)` without a `Subsingleton` instance; implicit transcripts in recursive calls; a lambda binder's type; the
  unused-variable and unused-section-variable linters (`omit … in`).
- `check.log`: `check_l25.sh`, ONE guarded job, 56 s, peak RSS 21.3 GiB:

| Gate | Result |
|---|---|
| full `lake build` of the library (`full.log`) | green, **3,542 jobs, 0 warnings, 0 errors, no `sorry`** |
| axiom audit (`gen_axioms.py` → `axioms_l25.lean` → `axioms.log`: every `theorem` of the five L25 files) | **67 theorems** (Sum 12, Block 14, Run 14, Count 21, Links 6): 39 on `[propext, Classical.choice, Quot.sound]`, 16 on `[propext, Quot.sound]`, 5 on `[propext]`, 7 on none; no `sorryAx`, no `Lean.ofReduceBool`, no other axiom |
| source scan of the five L25 files (`sorry`, `axiom`, `native_decide`, `admit`, `maxRecDepth`, `maxHeartbeats`, `implemented_by`, `extern`, `bv_decide`, `ofReduceBool`) | **none** |
| the root imports the five L25 files | yes (lines 150–154) |
| regressions on their committed corpora: L6Check / L5Check / fixture L1 / L11Check | **1,206 / 5,553 / 101,956 / 404 checks, 0 failed** |

Not run here: the block-verifier corpus checkers `ExecBlockCheck` / `CheckR13Block` (the L23-1 line changes `slotAcc`'s
host functional, which those checkers compare against the code's; the merged tree's run is the coordinator's, with L23's
own repair).
