# D63 lane L18: the classify run's `Protocol` instance, its Fiat–Shamir schedule, `Complete`, and the assembly into `ProductionReady` (2026-11-07)

Lean lane L18 (Claude), on its own worktree branched from perf at `160dc05d` (lanes L9, L10, L11, L12, L15 merged);
perf merged in at `0940de9a` (lanes L13, L14, L16, L17: a merge, no rebase) so that the R13 instance uses L17's and L16's
results. Lean 4.34.1, Mathlib v4.34.1, no new dependency. Five new library files under `formal/ZK60Formal/`, imported
by the library root: `ProtocolClassify.lean`, `ProtocolClassifyFS.lean`, `ProtocolClassifyComplete.lean`,
`AssembleClassify.lean`, `ProtocolClassifyR13.lean`; one checker, `ProtocolClassifyCheck.lean`, not imported (it defines `main`). One TEST-ONLY
Rust file, `ops/zkp-mvp/gpu-metal/hashline/src/lean_l18_export_tests.rs`, declared by two lines (a comment and one
`#[cfg(test)] #[path] mod`) at the end of the test-only `private_block/token_io/classify_capture_tests.rs`; it lives in
`src/`, not `src/private_block/`, as lane L10's does, so `s25_tests.rs`'s `TEST_ONLY_FILES` (85 entries) is unchanged.
`Statements.lean`, every existing Lean file and every production source are unchanged. Evidence:
`results/zk60_lean_l18_20261107/`.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms at most `propext`, `Classical.choice`, `Quot.sound`),
**TESTED** (value for value against the Rust code), **CODE** (read off the sources, file:line), **ESTIMATE**
(arithmetic on proved bounds or code counts, not proved in Lean).

## 1. In plain words, for Victor

**What this lane is.** Your D63 gate is ONE statement, `ProductionReady`, about three objects for a profile: the
integer model, its constraint system, and the protocol (prover, verifier, commitments). The first two exist for the
classifier (`classifyModel`, `classifyArith`). The protocol object did not exist, so nothing could be assembled. This
lane builds it for the media app's real run (Shieldstral T128: stage IN-C, the 26 blocks, stage OUT-C, on the
sequential D12a run) and assembles the gate.

**What now exists.**
- **The protocol object for the classify run** (`classifyProtocol`). Its verifier is `verify_classify_run_with`,
  step for step: the pre-header checks, the segment count, then the `L + 2` segments on ONE transcript, each decoded at
  the transcript's position tag, checked, and its end tag compared; for a block, the run's framing absorbs, the block's
  core, and the opening of the previous boundary with the claims left pending. PROVED: the verifier accepts exactly
  when stage IN-C, the blocks in order and stage OUT-C each accept (`classifyVerifyE_ok_iff`), and each part's step is
  unfolded in the code's order (`blockSeg_step_ok_iff` and its two siblings).
  - The **block profile is a parameter**, and its **R13 instance is built** from lane L17's executable D12a segment
    decoder and L9's executable block verifier (`d12aBlockProf`): the app's real profile after A25. W16R2 is the same
    definition with W16R2's parameters. The two stages' verifiers are parameters.
  - The commitments are lane L10's: the input opens as a plane commitment, the classifier's hidden output is `Unit`.
  - The declared leakage is the shapes, `T`, `L` and the served bit; every refusal is ONE constant output
    (D65(2), `prove_unserved`).
- **It agrees with the code on a real receipt.** A test-only export proves an honest two-block classifier run on the
  development rung, verifies it with the production verifier, and replays the run's loop beside it. Lean recomputes
  every position tag (BLAKE3 in Lean) and every block's framing absorbs from the recorded transcripts:
  **[N] checks, 0 failed** [TESTED]; five deliberate corruptions are each caught.
- **One Fiat–Shamir schedule for the whole run.** PROVED: the stages' and the blocks' sub-protocols together on the
  run's one transcript give a per-query rate equal to the LARGEST part's error, not 28 times it
  (`classify_run_fs_sound_sched`). For the run's sumcheck slots that is at most **2^-61** for `q ≤ 2^64`
  (`classify_run_sumchecks_fs_sound_le`).
- **Completeness is proved, given each part's own completeness.** PROVED: if every part's honest segment is accepted by
  its verifier, and the honest prover refuses only at listed sites, then the honest receipt is accepted, carries the
  model's verdict and opens to the input, except with probability at most the sum of the sites' refusal terms. With
  the site counts below a stated budget that is **`εcTarget = 2^-40`** (`classify_complete_target`).
- **The gate is assembled.** PROVED: `classify_productionReady` gives your `ProductionReady` for the classify run's
  protocol from ONE structure of named open obligations (`ClassifyOpen`, 12 fields). Discharged inside: the circuit
  lemma, `Binding` at the target, `Complete` at the target, the extraction's link from the parts to the whole run, and
  the two statements that follow generically.

**What it does not do.** The remaining gap is now a checkable list (§3). The big items are unchanged in kind: each
part's Lean honest prover and its completeness (O8), the run's knowledge extraction (O11: lane L16 for the blocks, L17
at R13, the stages' Fiat–Shamir lift, L10-6), and zero knowledge (O12: lane L14 and the run's simulator).

**Two numbers worth your attention** (findings L18-2 and L18-3, §5).
- The code-chain composition of lane L8, applied to the whole run, has a query-free part of about `2^-90`: the
  verifier's own ~`2^16` items times `M`'s `2^-106.4` per-round error. That is above your target's `2^-100` constant.
  It does not break anything proved; it says the run-level extraction must use the path-wise count you approved in
  D66(4) (one block zone, `FSPathBlock.lean`), carried to the code's chain.
- The openings' "dependent proximity coefficients" refusal costs about `1/p ≈ 2^-64` per opening, not `2^-111`: about
  `2^-57.6` over the run's ~83 openings. Still far inside `2^-40`.

## 2. What is proved

All PROVED (`results/zk60_lean_l18_20261107/`; the counts are in §6).

### 2.1 The `Protocol` instance (`ProtocolClassify.lean`)

The code: hashline `src/private_block/token_io/classify_run.rs`, `verify_classify_run_with` :246-396,
`prove_classify_run_with` :103-236 (read 2026-11-07; unchanged).

| Theorem / definition | Meaning |
|---|---|
| `ClsStmt`, `ClsReceipt`, `Carry`, `carry0` | the statement (the public header, `st.in_root()`, the PUBLIC verdict), the receipt (the `L + 2` segments' bytes), what one segment hands the next (the pending claims, the last boundary's root) |
| `SegV`, `segStep`, **`segStep_ok_iff`** | one framed segment: decode at the transcript's position tag (L9's `posTag`), check, compare the end tag |
| `runSegs`, `SegsOk`, **`runSegs_ok_iff`**, `segsOk_length`, `segsOk_append`, `segsOk_single` | the run of segments accepts exactly when each segment accepts in order, from the carry and transcript the previous one left |
| `StageInV`, `BlockProfV`, `StageOutV` | the parts the run CALLS, as parameters: stage IN-C's decoder and verifier; the block profile (statement check, D12a decoder, paths' depth, boundary root, digest, boundary geometry, `verify_core`, the boundary audit and opening); stage OUT-C's |
| `inSeg`, `blockFrame`, `blockSeg`, `outSeg` | the three parts' segments; `blockFrame` is the run's framing of block `k` (`pb-run-stage`, `pb-run-block`, `absorb_root("B")`, classify_run.rs:320-324) |
| **`inSeg_step_ok_iff`**, **`blockSeg_step_ok_iff`**, **`outSeg_step_ok_iff`** | each part's step unfolded in the code's order (a block: the check, the decode, the paths, the root, the framing, the core, `pending ++ io_in` audited and opened against the PREVIOUS boundary's root, the end tag; the carry becomes `(io_out, B_{k+1})`) |
| `RunV`, `RunV.parts`, `countOk`, **`classifyVerifyE`** | `verify_classify_run_with`: `preA`, the count `L + 2`, `preB`, the run of `inSeg :: blockSeg 0 … blockSeg (L−1) ++ [outSeg]` from `st.transcript()`, the binding its state |
| **`classifyVerifyE_ok_iff`** | the verifier accepts EXACTLY when `preA`, `L + 2` segments, `preB`, stage IN-C accepts segment 0 from nothing pending, the blocks accept segments `1 … L` in order, and stage OUT-C accepts segment `L + 1` |
| `SegP`, `proveSegs`, `RunP`, `honestStmt`, `honestSegs`, **`runProve`** | the honest prover as a SPECIFICATION: the parts' honest provers on one transcript, each segment framed with its end tag; the sealing pass refuses an inadmissible input; every refusal is the ONE constant output |
| `SegComplete`, **`runSegs_of_proveSegs`**, `proveSegs_length` | the per-part completeness contract (deterministic), and its composition: honest parts accepted ⇒ the honest run accepted |
| `planeLeaves`, `honestRoot`, **`planeCommit_opens_honest`**, `HonestIn`, **`honestIn_opens`** | the honest input commitment (the Merkle root of the honest salted columns) opens to the input with the honest paths (`CompleteSub.lean`'s `opens_honest` on L10's `PlaneCommit`) |
| `ClsLeak`, `clsLeak`, `admissible_canon` | the declared leakage (`T`, `d`, `L`, the served bit); an admissible item's ids are canonical words |
| **`classifyProtocol`** | the `Protocol (QB Lq) Dig Coins (classifyModel S R)` instance: `leak = clsLeak`, `ypub` = the verdict, `opensIn` = L10's `opensIn`, `opensOut` = L10's `opensUnit`, `prove` = `runProve` (the honest root, the model's verdict), `verify` = `classifyVerifyE` under `liftH` |
| `verify_true_iff`, **`prove_unserved`**, `leak_served`, `opensIn_iff`, `clsStmtOf`, `prove_served` | the instance's verdict is `classifyVerifyE`'s; an unserved input's output is the constant refusal (D65(2)); the leakage carries the served bit; `opensIn` is L10's; a served input's output is the honest statement and segments |

### 2.2 The run's Fiat–Shamir schedule (`ProtocolClassifyFS.lean`)

| Theorem / definition | Meaning |
|---|---|
| `runSched`, `mem_runSched` | the run's schedule `IN-C ++ block 0 ++ … ++ block (L − 1) ++ OUT-C`, every window at its absolute position |
| **`classify_run_fs_sound_sched`** | L8's `fs_code_chain_sound_sched` on the run's schedule: parts round-by-round sound with errors `≤ εin`, `≤ εblk` (the block profile's, a parameter), `≤ εout`, releases forward only: a false claim entering any window and every sub-protocol alive at the end `≤ T·max(εin, εblk, εout) + collBound T + collBound (T + 1)`, `T = q + ℓ + 1` |
| `hframe_of_noRelease` | a schedule that releases nothing meets `hframe` |
| `runSlots`, `slotsLen_append`, `slotsLen_flatMap_le`, `slotsLen_runSlots_le`, `runSlots_facts` | the run's sumcheck slots as ONE run of L8 `Slot`s; its item count from the parts' |
| **`classify_run_sumchecks_fs_sound`** | L8's `exec_sumchecks_fs_sound` on the run's slots: a false claim in ANY slot of ANY part passing every slot's executable `sumcheck::verify` `≤ T·dmax/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)` (L9's `block_sumchecks_fs_sound` and L15's `stage_sumchecks_fs_sound` are this bound for ONE part at its own `T`) |
| **`classify_run_sumchecks_fs_sound_le`** | with every degree `≤ 7` and `T ≤ 2^64 + 2^20`: at most `2^-61` for the WHOLE run |
| **`sched_le_target`** | the scheduled bound is `≤ εsTarget q` when the largest per-step error is `≤ 2^-103` and `q ≥ ℓ + 1` (`T ≤ 2^76`); finding L18-2 for `q < ℓ` |

### 2.3 `Complete` (`ProtocolClassifyComplete.lean`)

| Theorem / definition | Meaning |
|---|---|
| `chal_bad_card` | the digests whose `challenge_fp2` lies in a set of `k` field values number `≤ k·fibC` (`card_chal_fiber_le`) |
| **`site_refusal_le`** | one refusal site under Fiat–Shamir: the honest computation up to the site names the squeeze point; it fires with probability `≤ m/|Dig| + δ`, `δ` the probability that the point was asked before (`fresh_point_prob_le_coins` and the union bound) |
| `Site`, `Site.fires`, **`Site.prob_le`** | a site (its honest computation, its bad challenge values, their number `k`, its freshness bound `δ`) fires with probability `≤ k·fibC/|Dig| + δ` |
| **`classify_complete`** | `Complete (classifyModel S R) (classifyProtocol …) (Σ ε)` via `complete_of_checks`: the policy on the registered header, every part's `SegComplete`, the honest prover refusing only when a listed event fires, each event's bound; the verdict is the model's, the input commitment opens (`honestIn_opens`), the `Unit` output opens trivially |
| **`classify_complete_sites`** | the same with the sites: `εc = Σ (k_i·fibC/|Dig| + δ_i)` |
| `fib_le` (variable `p > 2^63`, L7-4), `fibC_le`, **`refusal_total_le_target`** | `fibC ≤ 2^130`; `Σ k ≤ 2^85` and `Σ δ ≤ 2^-41` give a total `≤ εcTarget = 2^-40` |
| **`classify_complete_target`** | `Complete … εcTarget` (`complete_mono`) |

### 2.4 The R13 instance (`ProtocolClassifyR13.lean`)

Lane L17's R13 results and lane L16's per-block knowledge form, instantiated rather than restated.

| Theorem / definition | Meaning |
|---|---|
| **`d12aBlockProf`** | the run's block profile: L17's `decodeSegment` (the D12a `HLPRUNS1` segment, `wire::decode_segment`) at block `k`'s segment geometry, L9's executable `blockVerify` (`verify_core`) at block `k`'s `BlockParams` (at R13 each layer's own calibration, with L17's `r13Fields`), the segment's `b_root`, the boundary opening of its `in_open`; W16R2 is the same definition with W16R2's parameters |
| **`d12a_blockSeg_step_ok_iff`** | the R13 block step unfolded in the code's order (the decoder, the core, the boundary opening) |
| **`d12a_block_segment_canonical`** | an accepted block segment is EXACTLY L17's `encSeg` of what it decoded (`decodeSegment_spec`): one receipt, one encoding, per block segment |
| `r13TokenCommit_facts` | L17's R13 input endpoint (`r13TokenCommit`, `N = 2^16`, depth 16) with the statement's root meets O6 |
| **`classify_binding_r13`** | `Binding … εsTarget` for the classify run at R13, from L17's `binding_classifier_target_r13` |
| **`shield_run_sumchecks_le`** | the media app's run: 26 blocks and two stages, each part `≤ 2^14` slot items (L17's `shield_len`: a Shieldstral R13 block's slot phase is its header plus 1,292), degrees `≤ 7`, `q ≤ 2^64`: a false claim in ANY slot of the run passes with probability `≤ 2^-61` (L17's `shield_block_fs_sound` is this bound for ONE block) |
| `blockOn_of_blockSat`, `blocksOk_of_blockSat` | `BlockSat` on two planes gives `BlockOn` (`BlockSat` carries the `Word16` class of both planes, `inX` and `res2`): L16's `block_knowledge` conclusion (with L17's `blockSat_of_slots_r13` as the `hRel` route at R13) is the blocks' part of O11, per block |
| **`blocks_extract_union`** | per-block failure bounds (L16's per-block form) give the blocks' part of `RunExtract` with their sum (L16's `run_blocks_union`) |

### 2.5 The assembly (`AssembleClassify.lean`)

| Theorem / definition | Meaning |
|---|---|
| `BlockOn`, **`runSat_of_blocks`**, **`runOn_of_blocks`** | block `k`'s conclusion on the extracted planes of boundaries `k` and `k + 1` (the shape L16 / L17 deliver per block) chains, through the unique int16 preimages, into the run's `RunSat` and L12's `RunOn` |
| `boundaryFrame` | one extracted plane per boundary index is L12's `RunFrame` (`B_in` block 0's input, `B_L` stage OUT-C's) |
| `RunExt`, `InOk`, `BlocksOk`, `OutOk`, `EpOk`, `RunExtract` | the run's extraction premise: ONE extractor, four failure bounds (stage IN-C with SIC_IO; the blocks JOINTLY; stage OUT-C for the statement's verdict; the input endpoint's opening) |
| `prH_or_le`, `prH_mono`, **`iopExtract_of_runExtract`** | `RunExtract … εin εblk εout εep → IOPExtract (classifyModel S R) (classifyArith S R) P (εin + εblk + εout + εep)`, through L12's `classify_inner_of_stages` |
| `ClassifyOpen` | the 12 open obligations as named fields (§3) |
| **`classify_productionReady`** | `ClassifyOpen … → ProductionReady (classifyModel S R) (classifyArith S R) (classifyProtocol …) εcTarget (εin + εblk + εout + εep) εsTarget εzk` via `productionReady_of`: `CircuitIff` (L2), `IOPExtract` (this lane), `Complete` at the target (this lane), `Binding` at the target (L10's `binding_classifier_target`), `ZeroKnowledge` (O12) |
| `extract_split_le_target`, **`classify_productionReady_target`** | with the extraction's parts within the target's halves and `εzk ≤ εzkTarget`: `ProductionReady … εcTarget εsTarget εsTarget εzkTarget` (`productionReady_mono`) |
| `classify_zk_target` | `ZeroKnowledge … εzkTarget` from a programming simulator's one-receipt hybrid step (`zeroKnowledge_target_of_hybrid`): the form O12 can be delivered in |
| `shield_inp_valid` | O3 for the registered Shieldstral category policies (L15's `shield_in_valid`) |

## 3. The remaining premises (`ClassifyOpen`)

`classify_productionReady` takes exactly these as premises; every other part of the gate is discharged. The instance's
DATA (the run public data `R`, the verifier's and the provers' parts with the block profile, the input commitment, the
refusal sites) are arguments, not premises.

| Field | Precise shape | Lane | Status |
|---|---|---|---|
| O1 `shape` | `S.Valid` (`BlockShape.Valid`) | registered profile (L9 §6) | open: finite checks of the Shieldstral T128 shape constants, not written |
| O2 `weights` | `∀ B ∈ R.Ps, B.Valid` | registered profile | open: needs the public weights (not in the repository, D62); a finite check at the export |
| O3 `inPub` | `R.inp.Valid` | L15 | discharged for the registered policies by `shield_in_valid` (`shield_inp_valid`), given `R.inp = shieldIn …` |
| O4 `outPub` | `R.out.Valid` | L15 | discharged by `shield_outc_valid` at `d = 3072` for the door's classes of `w_Δ` and the final norm |
| O5 `blocks` | `0 < R.Ps.length ∧ V.L = R.Ps.length` | instance | true at `L = 26` by the instance |
| O6 `commit` | the input commitment: canonical words admissible, `N ≤ 2^depth`, `root s = s.inRoot`, depth `≤ 64` | L17 (R13: `r13TokenCommit`), L10 (W16R2: `w16r2TokenCommit`) | **discharged at R13** by `r13TokenCommit_facts` (`N = 2^16`, depth 16) once the endpoint's layout (`pos`, the rows) is given; W16R2 the same by definition |
| O7 `policy` | `V.preA hdr = .ok () ∧ V.preB hdr = .ok ()` | registered profile; L17 | partly: L17's `shield_layers_accepted` proves the code's R13 calibration check passes for all 26 real layers (`preB`'s per-block stage shapes); the rest (rulings, tier, the D27 floor, NTT tables, the tables' binding) open |
| O8 `parts` | `List.Forall₂ (SegComplete …) (P.parts L) V.parts`: each part's honest segment accepted, deterministically | IN-C, OUT-C: L12/L15 (model completeness only); blocks: L9–L11 executable verifier, no Lean honest prover | **open, not started**: the Lean honest provers of the parts and the executable stage verifiers |
| O9 `refuse` | the honest prover refuses only when a listed site fires | with O8 | open: the sites are listed (§4.1); the statement is the prover specification's |
| O10 `counts` | `∀ x i, k ≤ kOf i`, `∀ x i, δ ≤ δOf i`, `Σ kOf ≤ 2^85`, `Σ δOf ≤ 2^-41` | this lane's site list | the count holds by a wide margin [ESTIMATE §4.1]; `δ` (freshness) is argued, not proved (L18-4) |
| O11 `extract` | `RunExtract R P εin εblk εout εep` (one extractor; four failure bounds) | IN-C: L12 (`inc_stage_sound`, interactive); OUT-C: L15 (`outc_stage_sound`, interactive); blocks: **L16**'s `block_knowledge` (any shape; `hOpen`, `hRel`, `hLk` named, L20/L21), at R13 with L17's `blockSat_of_slots_r13` for `hRel`, carried into O11 by `blocksOk_of_blockSat` / `blocks_extract_union`; endpoint: L10-6 | open: the stages' Fiat–Shamir lift; L16's three hypotheses; the identification of each block's extracted planes with the run's boundary planes (the boundary openings); the joint path-wise bound (the per-block sum misses the constant: L16-1, L18-2) |
| O12 `zk` | `ZeroKnowledge (classifyModel S R) P εzk`; for the target, `classify_zk_target`'s hybrid step (`εhv ≤ 2^-120`, `δ ≤ 2^-248`) | **L14**: `zeroKnowledge_of_oneStep`, `w16r2_zk_within_target` (generic in the protocol and the block shape; the stand-in simulator) | open: L14's obligations for the classify run (its prover as a bounded oracle computation, its Fiat–Shamir receipt model, the honest-verifier law, the counts; a 26-block run estimated at `R ≤ 2^85`, L14 §3.1); every `R` needs Victor's ruling on L14-1 / A5 |

## 4. The numeric totals against the targets

| Term | Target | What is proved | Status |
|---|---|---|---|
| `εc` | `εcTarget = 2^-40` | `classify_complete_target`: `Complete … εcTarget` given O8–O10 | PROVED given the open fields; the count [ESTIMATE] about `2^-57.5` |
| `εb` | `εsTarget q = q·2^-100 + 2^-100` | L10's `binding_classifier_target`, every `q` | PROVED (given O6) |
| `εs` | `εsTarget` | `εin + εblk + εout + εep`; `extract_split_le_target`: within the target when the stages' and endpoint's sum and the blocks' joint term are each `≤ q·2^-101 + 2^-101` | open (O11); the parts' interactive figures in §4.2 |
| `εzk` | `εzkTarget q R = q·2^-128 + R·2^-120` | `classify_zk_target` from the hybrid step | open (O12, A5) |
| the run's sumcheck slots under Fiat–Shamir | (part of `εs`) | `classify_run_sumchecks_fs_sound_le`: `≤ 2^-61` at `q ≤ 2^64` for the WHOLE run | PROVED |

### 4.1 `εc`: the refusal sites of the classify run [ESTIMATE, on CODE counts]

Each site's term is `k·fibC/|Dig| + δ` (PROVED per site, `Site.prob_le`); with `fibC = (⌊2^128/p⌋ + 1)² ≈ 2^128`
and `|Dig| = 2^256` it is about `k·2^-128 + δ`.

| Sites | `k` per site | Count at Shieldstral T128, `L = 26` | `Σ k` |
|---|---|---|---|
| per opening: proximity pair dependent over `Fp` (`det = 0`, protocol.rs:319, given the first nonzero) | `p ≈ 2^64` | `3L + 5 = 83` openings (A, H and the previous boundary per block; IN-C's A, H; OUT-C's A, H, `B_L`) | `≈ 2^70.4` |
| per opening: the pair's first coefficient zero; each zero group member coefficient | `1` | ≈ 83 + the groups' members (hundreds per opening) | `< 2^16` |
| per slot: `c = 0` (`k = 1`), the extension challenge degenerate (`k = 2`) | `1`, `2` | `23·26 + 4 + 8 = 610` slots | `< 2^11` |
| per host and batch: `ν` zero, a zero batching coefficient | `1` | a few hundred | `< 2^10` |
| per LogUp domain: `α` a folded table tuple | `M ≤ 2^17` | a few per block, IN-C (`V = 2^17`), OUT-C (256) | `< 2^24` |
| D66(3)'s dictionary (DD profiles only) | `cap·2^40` | per block, if the profile is DD | `< 2^65` at `cap ≤ 2^20` |
| total | | | `≈ 2^70.5 ≪ 2^85` |

So `εc ≈ 2^70.5·2^-128 ≈ 2^-57.5` plus the freshness terms (`δ`, argued to be `0`, L18-4): far inside `2^-40`.

### 4.2 `εs`: the parts' figures where they exist

| Part | Interactive (proved) | Under Fiat–Shamir |
|---|---|---|
| stage IN-C | `inc_stage_sound` (L12): about `2^-109.0` at `V = 2^17` (L15-1) | the sumcheck slots: inside the run's `2^-61` per `2^64` queries (this lane); the LogUp `α` and the pads' `ζ`: `chalSub_rbr` (L15), not composed |
| the blocks | W16R2: the slots' densities (L11), `blockSat_of_slots`; R13: L17 | W16R2 8B: `fs_path_run_8B_target` (L3, the MODEL chain, zone premises): `εsTarget` for `q ≤ 2^75`; the code chain: L8 / this lane, `T·εmax` (L18-2) |
| stage OUT-C | `outc_stage_sound` (L15): about `2^-112.3` | as stage IN-C |
| the endpoint | L10's `binding_classifier_target` (soundness of the plane commitment) | the knowledge version: L10-6, open |

## 5. Findings

No mismatch between the code and the approved statements was found; `Statements.lean` is unchanged.

**L18-1 (Info): the classify run fits the approved `Protocol`.**
- `Receipt` is the `L + 2` segments' bytes, as the code takes them; `Stmt` carries the public verdict (`ypub`).
- The code's sealing pass returns no receipt for an inadmissible input; `prove` must be total, so it returns the ONE
  constant refusal `(refused, [])`, which the verifier rejects (no `L + 2` segments). Every challenge-dependent
  `discard attempt` returns the same constant (D65(2)), so the refusal output is a function of the served bit alone
  (`prove_unserved`), as `refusal_output_must_be_leaked` requires.
- `Leak` is the shapes, `T`, `L` and the served bit. The classifier's hidden output is `Unit` (`opensUnit`, L12-5).
- The integer model `classifyModel` is the profile-independent ModelInt (CircuitBlock covers the Low stack), so the
  R13 block profile instantiates the same model; what changes at R13 is the protocol's block part (L17).

**L18-2 (Medium; for the run-level extraction, O11; lane L16 found the same for one block, L16-1): the code-chain
composition's query-free part is above the target's constant.**
- `fs_code_chain_sound_sched` (L8) bounds the run by `T·εmax`, `T = q + ℓ + 1`: the verifier's own `ℓ` items count
  as attempts. On the whole classify run `ℓ` is about `2^16` items [ESTIMATE: 26 blocks of about 2,000–2,500 items
  with their openings], and `εmax` is at least `M`'s column round, `(3071/4096)^256 ≈ 2^-106.4` (L10), so the
  query-free part is about `2^-90`, above `εsTarget(0) = 2^-100`.
- PROVED (`sched_le_target`): the scheduled bound meets `εsTarget q` once `εmax ≤ 2^-103` and `q ≥ ℓ + 1`. Below that
  it can miss.
- This is F25 again, on the code chain: D66(4)'s path-wise count (a forged proof lives in ONE block zone; the
  query-free floor is one zone's rounds, `2^-102.72` at 8B) is proved on the MODEL chain (`FSPathBlock.lean`), with
  zone premises. The run-level extraction must carry it to the code chain; that is why O11 takes the blocks JOINTLY,
  not as 26 per-block bounds (their sum, `26·2^-102.7 ≈ 2^-98`, would miss the constant too).
- Not a change to any statement or target. The sumcheck slots alone are fine (`ℓ·5/p² ≈ 2^-109.7` at `q = 0`).

**L18-3 (Low; completeness arithmetic): the dependent-proximity refusal is about `1/p` per opening.**
- CODE (protocol.rs:312-322): `check_opening_challenges` refuses when `det(ρ_prox, ρ_prox+1) = 0` in `Fp`, i.e. when the
  two coefficients are `Fp`-linearly dependent. Given a nonzero first, the bad second values are the `Fp`-line through
  it: `p` values of `Fp2`, probability `≈ 1/p ≈ 2^-64`.
- ASSEMBLY A7 put every refusal near `M/|Fp2| ≈ 2^-111`. Over the run's ~83 openings this one is about `2^-57.6`, the
  dominant completeness term, still `2^17` times inside `εcTarget = 2^-40`. `classify_complete_target` takes it with
  `k = p` per opening.

**L18-4 (Info; for O10): the freshness of the honest squeeze points.**
- `fresh_point_prob_le` needs each refusal site's squeeze point not asked earlier by the honest computation. CODE:
  squeeze messages are 47 bytes (`state ‖ "squeeze" ‖ le64 counter`), absorb messages at least 48, Merkle queries are
  under the tree keys; the main transcript's counter only grows. The code's CLONES do repeat points: the position tags
  (two squeezes of a clone at each segment boundary) and `check_opening`'s replay of an opening's challenges. A site
  must therefore be placed at its point's FIRST query (for an opening, the clone's), and every part's first transcript
  operation after its start tag is an absorb (block: `pb-run-stage`, classify_run.rs:182; stage IN-C: `pb-run-stage 0`,
  stage_in_c.rs:303; stage OUT-C: `pb-run-stage L + 1`, stage_out_c.rs:538), so no site shares a point with a tag.
- So `δ = 0` is expected; it is a premise (`Site.hfresh`) here, because proving it needs the honest prover's whole
  query list.

**L18-5 (Info): the extraction's blocks are one joint premise.** `BlocksOk` asks every block's `BlockOn` together;
`runOn_of_blocks` chains them. A per-block bound would be summed by any union bound over the blocks (L18-2).

**L18-6 (Info): two code details the model keeps.** The R13 pre-header loop checks every block's stage shape and
digest before the header (`preB`), and the block loop checks it again (`BlockProfV.check`). Absorbs of at least
`2^16` bytes are hashed as BLAKE3's own tree in parallel, the same digest as one BLAKE3 call (CODE:
zkp-core/src/transcript.rs:61-64), so the Lean `Tr.absorb` is the same function.

**L18-7 (Info, engineering).** `⟨fun h => by cases h, …⟩` parses as a two-target `cases`; parenthesized. `if_pos` /
`if_neg` are deprecated in this Mathlib (`ite_eq_left` / `ite_eq_right`). `rw` with an iff cannot rewrite under an
`∃` whose bound variables occur in the pattern; introduce first.

## 6. Checks

[to be filled in from check.log]
