# D63 lane L29: the executable stage IN-C and OUT-C verifiers, the stages' completeness, and the honest prover's refusals as transcript programs (2026-11-07, finished 2026-11-09)

Lean lane L29 (Claude), on its own worktree branched from perf at `6d1b21ad` (lanes L9–L25 merged; nothing merged in
since). Started 2026-11-07, cut off by a usage limit the same day, resumed and finished 2026-11-09. Lean 4.34.1,
Mathlib v4.34.1, no new dependency. Nine new library files under `formal/ZK60Formal/`, imported by the library root:
`StageVerifyExecLay.lean`, `StageVerifyExecInC.lean`, `StageVerifyExecOutC.lean`, `StageVerifyExec.lean`,
`StageVerifyExecComplete.lean`, `StageVerifyExecAssemble.lean`, `HonestOracleProg.lean`, `HonestOracleSlots.lean`,
`HonestOracleParts.lean`; one checker, `StageVerifyExecCheck.lean`, not imported (it defines `main`). One TEST-ONLY
Rust file, `ops/zkp-mvp/gpu-metal/hashline/src/lean_l29_export_tests.rs`, declared by two lines (a comment and one
`#[cfg(test)] #[path] mod`) at the end of the test-only `private_block/token_io/classify_capture_tests.rs`; it lives in
`src/`, not `src/private_block/`, as lanes L10's and L18's do, so `s25_tests.rs`'s `TEST_ONLY_FILES` needs no new entry.
`Statements.lean`, every existing Lean file (except the root's import lines) and every production source are
unchanged. Evidence: `results/zk60_lean_l29_20261107/`.

Labels: **PROVED** (a Lean theorem, axioms at most `propext`, `Classical.choice`, `Quot.sound`), **TESTED** (value for
value against the Rust code), **CODE** (read off the sources, file:line, 2026-11-07), **ESTIMATE** (arithmetic or
reasoning not proved in Lean), **CONTRACT** (a named premise a component lane must discharge).

## 1. In plain words, for Victor

**What this lane is.** Your gate `ProductionReady` for the media app's classify run was assembled by lane L18 with the
run's two token stages as PARAMETERS: IN-C (the hidden token ids into the first block's input) and OUT-C (the last
block's output into the published verdict). No Lean verifier existed for them, so the protocol object was only as
concrete as those parameters. Lane L25 then wrote the honest provers of the blocks and reduced completeness (O8) and
the refusal list (O9) to named contracts, one of which was "the stage verifiers". This lane removes that parameter and
takes the next step on the honest prover's oracle form.

**What now exists.**
- **Both stage verifiers, as executable Lean, in the code's order.** `stage_in_c::verify` and `stage_out_c::verify`
  line for line: the segment decoder (the stage frame `HLPCLIN1` / `HLPCLOT1`), the path-depth checks, the frame
  absorbs, the roots, the challenges, every slot's definition with its tables and closure (lane L15's closures for
  OUT-C, new ones for IN-C), the slot loop (lane L9's), the functional count, the openings' audits (lane L10's), and
  the openings themselves (lane L10's executable functions at the stages' parameters). PROVED: each accepts EXACTLY
  when every one of its checks passes in that order, and their slot phases are lane L15's Fiat–Shamir model of a
  stage.
- **The classify run's protocol object is now concrete in its stages.** L18's stage parameters are instantiated with
  these verifiers (`classifyProtocolExec`); the run's acceptance is PROVED to unfold into: the pre-header checks,
  `L + 2` segments, stage IN-C's decode and verify, the blocks in order, stage OUT-C's decode and verify.
- **It agrees with the code on a real receipt.** A test-only export proves an honest classifier run on the development
  rung, verifies it with the production verifier, and replays both stage verifiers step by step beside it. Lean then
  runs ITS OWN stage verifiers on the same data, including the two real segments' bytes (1.2 MB and 2.5 MB) through
  the full executable verifier with lane L10's executable openings: **CHECKS_TOTAL checks, 0 failed** [TESTED]. Seven
  deliberate corruptions of the data cause exactly the eight failures they must.
- **The stages' completeness in L25's form** (`StageInOK`, `StageOutOK`). The honest IN-C and OUT-C provers are written
  in Lean in the code's order, and PROVED: the executable stage verifier accepts the honest segment (and the segment
  decodes back) given the same kind of component contracts L25 named for a block: each slot's arithmetic, and the
  completeness of `M`'s test and of the openings (L10's functions, whose completeness is not yet proved). So O8's stage
  part is now in exactly the shape of its block part, and O8 as `AssembleClassify.lean` names it holds for the run with
  the executable stages from those contracts alone (`classify_parts_exec`).
- **The honest prover's refusals as transcript programs, `δ = 0`.** L25 proved that a refusal whose computation is
  written as a "transcript program" is a fresh coin flip (`δ = 0`), and left writing the run in that form (L25-3).
  This lane:
  - builds the combinators (sequencing, draws, the honest sumcheck, a commitment's Merkle root, the transcript's
    creation);
  - writes ONE honest slot, and then the whole slot loop of a part, as a transcript program, PROVED to end on exactly
    the transcript, records and accumulator of L25's honest prover;
  - writes the head of each kind of part (a block's core, stage IN-C, stage OUT-C) as a program;
  - and PROVES, for each of the three kinds of part: whenever the part's honest prover refuses, one of a short list
    of events holds, and the challenge events on that list are sites with `δ = 0` and at most 2 bad values (a slot's
    `c = 0`, a degenerate extension challenge), or 256 (stage OUT-C's LogUp refusal).

**What it does not do.**
- O8 is not closed outright: the openings' completeness (L10) and each slot's arithmetic stay contracts, for the
  stages as for the blocks.
- O9 is not closed outright. Each part's refusals are covered GIVEN the run up to that part as a transcript program.
  Chaining the parts needs the openings' provers (`mask_open`, `open_zk`) as transcript programs, which no lane has
  modelled; three kinds of refusal are named but not turned into sites (a zero batching draw inside `define`, per
  instance; `check_opening`'s challenge refusals, L25-2; stage IN-C's LogUp refusal, finding L29-3 below); and the
  deterministic schedule checks must be excluded for the registered profile (L25-4).
- O12's honest-prover hypotheses (L19) are NOT discharged, none of them. They need the prover as L14's `FSModel`
  (points causal in values, the receipt read off the view, the column digests as programmed points). The transcript
  programs here are the first half of that; the second half was not reached.
- The run's zero-knowledge cap `R ≤ 2^112` (L19-2) stays; it is your ruling.

**One thing worth knowing (finding L29-3).** Stage IN-C's LogUp refusal ("zero LogUp denominator; discard attempt")
is checked after the embedding challenge `r_emb` is drawn, and the table it compares `α` with depends on `r_emb`,
which is drawn AFTER `α`. So it is not one refusal at `α` with a fixed bad set, as L18's site list has it. Counted
correctly it is about thirteen sites (one at `α`, one per `r_emb` coordinate) of at most `V = 2^17` bad values each:
about `2^20.7` bad values at Shieldstral, where L18 counted `2^17`. Still far inside the `2^85` budget; no statement
changes. This count is an ESTIMATE: the thirteen sites are not built in Lean.

## 2. What is proved

All PROVED; the theorem counts and the axiom audit are in §7.

### 2.1 A stage's layout, slot builder and slot loop (`StageVerifyExecLay.lean`)

CODE: `token_io.rs` `StageLayout::new` :810-841, the site rows and `logup_sum_claim` :849-896, the slot builder `SB`
:1160-1225, `run_stage_slot` :997-1135.

| Theorem / definition | Meaning |
|---|---|
| `Lay`, `Sched`, `SSpec`, `Lay.aOff` … `Lay.logupSumClaim` | the stage layout computed as the code computes it: the planes contiguous and row aligned, one reserved pair per claim site, the proximity pair, the zero-sum pair, `M`'s rows, the functional count |
| `SBM`, `eqT`, `pubT`, `aSliceT`, `aAtT`, `aT`, `hT`, `ioT`, `finishT`, `build` | the slot builder: each table pushed in the code's order, the site counts checked against the declared schedule |
| `stageBP` | a stage's slot schedule as L9's `BlockParams` |
| `stSlotsLoop`, **`stSlotsLoop_const`** | the stage's slot loop: L9's `slotStep` with each slot's IO commitment read at ITS OWN row width (finding L29-1); with one width it is L9's `slotsLoop` |
| **`slotStep_strip`**, **`stSlotsLoop_strip`** | the row width changes ONLY the outgoing claims: the verdict, the records, the transcript and the claim-free accumulator are L9's at any width |

### 2.2 The stages' schedules and definitions (`StageVerifyExecInC.lean`, `StageVerifyExecOutC.lean`)

Definitions only. CODE: `stage_in_c.rs` `layout` :42-57, `challenges` :254-262, `tau_table` :160-164, `define`
:166-238; `stage_out_c.rs` `layout` :71-102, `define` :283-429.

- IN-C: `IncPub`, `IncGeo`, `incSched`, `incLay`, `incElog`, `incCtx`, `tauTable`, `incDraws`, the four slots
  `incDefIO`, `incDefQZC`, `incDefTZC`, `incDefZS`, and `incDefine`. The classifier's public embedding fold
  `E~(·, r)` is a field of `IncPub` (a function; the weights are not in the repository, D62).
- OUT-C: `OutcPub`, `OutcGeo`, `outcSched`, `outcLay`, `outcDraws`, the eight slots `outcDefIO` … `outcDefZS` with lane
  L15's executable closures, and `outcDefine`.

### 2.3 The executable verifiers and the protocol instance (`StageVerifyExec.lean`)

CODE: `token_io.rs` `StageSegGeom::decode` / `encode` :1363-1497; `stage_in_c.rs` `verify` :399-464; `stage_out_c.rs`
`verify` :658-749.

| Theorem / definition | Meaning |
|---|---|
| `StageSeg`, `StageGeom`, `decodeStage`, `encStage`, **`decodeStage_enc`** | the stage segment codec; the honest segment of the verifier's geometry decodes back |
| `checkTokenEp`, `pcsAt`, `withPre`, `refuseIf` | `check_token_endpoint_opening`; L10's executable opening at a commitment's parameters; the code's error prefix; a guard |
| `IncV`, `IncV.verify`, **`incVerify_ok_iff`** | `stage_in_c::verify`; it accepts EXACTLY when, in the code's order: one closed commitment, the four path depths, `B_in`'s root present, the slot phase, the functional count, `M`, `check_opening` and the opening of `A`, of `H` (with `logup_sum_claim`), the endpoint audit and its opening |
| `OutcV`, `OutcV.verify`, **`outcVerify_ok_iff`** | the same for `stage_out_c::verify` on its carry, with "no claim on an output endpoint" and `boundary::check_opening` |
| **`outcSlots_model`** | stage OUT-C's slot phase IS lane L15's `stageSlots` (by definition, one `BlockParams`) |
| `withCh`, **`incSlots_model`** | stage IN-C's slot phase is `stageSlots` at the `BlockParams` of its drawn `r_emb`, on everything but the claims (findings L29-1, L29-2) |
| `incStageV`, `outcStageV`, `classifyRunV`, **`classifyProtocolExec`** | L18's `StageInV` / `StageOutV` instantiated; the classify run's `Protocol` with the executable stages |
| **`inSegExec_step_ok_iff`**, **`outSegExec_step_ok_iff`**, **`classifyProtocolExec_verify_iff`** | the run's acceptance with the executable stages, in the code's order |
| `incVAt`, `outcVAt` | the stage verifiers at a tier's parameters, with L10's executable `M` test and openings (what the agreement check runs) |

### 2.4 The stages' honest provers and completeness (`StageVerifyExecComplete.lean`, `StageVerifyExecAssemble.lean`)

CODE: `stage_in_c::prove` :282-395, `stage_out_c::prove` :517-653.

| Theorem / definition | Meaning |
|---|---|
| `sdAt`, `stSlotsProve`, `StSlotsSum`, **`stSlotsLoop_of_prove`**, `stSlotsProve_refuses` | the stage's honest slot loop at each slot's IO row width; the stage's slot loop accepts it (L25's `slotStep_of_prove`, slot by slot) |
| `IncData`, `IncRun`, `incCh`, `incAlphaBad`, **`incProve`**, `incProve_ok`, **`incVerify_of_prove`** | stage IN-C's honest prover; the executable verifier accepts its segment, from the slots' arithmetic and the completeness of `M` and the three openings (CONTRACTS) |
| `OutcData`, `OutcRun`, `outcCh`, `u8Entry`, `outcAlphaBad`, **`outcProve`**, `outcProve_ok`, **`outcVerify_of_prove`** | the same for stage OUT-C on its own carry (finding L25-1: the prover checks the carry is its own) |
| `incP`, `IncOK`, **`inc_stageInOK`**; `outcP`, `OutcOK`, **`outc_stageOutOK`** | L25's `StageInOK` / `StageOutOK` for the executable stages, from the codec and the contracts |
| **`incProve_refuses`**, **`outcProve_refuses`** | the stage provers refuse ONLY at D66(3), a slot's refusal, the functional count, a `check_opening` (IN-C's endpoint audit, OUT-C's boundary audit), OUT-C's output-claim check, or OUT-C's carry not being its own |
| **`classify_parts_exec`** | `ClassifyOpen`'s field O8 in EXACTLY `AssembleClassify.lean`'s form, at the run verifier with the executable stages, from `IncOK`, each block's `D12aBlockOK` (L25) and `OutcOK` |

### 2.5 Transcript programs: the combinators and the sites after any prefix (`HonestOracleProg.lean`)

| Theorem / definition | Meaning |
|---|---|
| `bindP`, **`final_bindP`**, `sep_bindP`; `SqLE`, **`noWrap_of_sqLE`**, `sqLE_mono`, `sqLE_bindP` | sequencing; a program with fewer than `2^64` squeezes does not wrap |
| `drawsP`, **`final_drawsP`**; `scP`, **`final_scP`** | `challenge_fp2_vec`; the honest sumcheck as a program is L25's `scProve` |
| `RootProg`, `absorbRootP`, `final_absorbRootP` | a commitment's root as a program (its Merkle hashes: queries that are never 47 bytes, so separated from every squeeze) and `absorb_root` |
| `StartProg`, **`startProg_point_fresh`** | `δ = 0` also for a site whose computation creates the transcript |
| `slotCProg`, **`slotCSite`**, **`slotCSite_fires`** | a slot's `c = 0` refusal: a site with `k = 1`, `δ = 0`, firing EXACTLY when the honest prover's guard does, after ANY prefix program ending at the slot |
| `drawProg`, `drawZeroSite`, **`drawZeroSite_fires`** | a zero draw of `define` (a batching coefficient, `ν`, `ζ`): `k = 1`, `δ = 0` |
| `scUpToP`, `scUpTo_chal`, `slotEAfter`, `slotEProg`, **`slotESite`**, **`slotESite_fires`** | round `m`'s degenerate value: `k = 2`, `δ = 0`, firing exactly when the honest slot's challenge of round `m` is `0` or `1` |
| `outcAlphaProg`, `u8Bad`, **`outcAlphaSite`**, `outcAlphaBad_iff`, **`outcAlphaSite_fires`** | stage OUT-C's D66(3) refusal: a site with at most 256 bad values, `δ = 0`, firing exactly when `outcProve`'s guard does |

### 2.6 The honest slot loop as one program (`HonestOracleSlots.lean`)

| Theorem / definition | Meaning |
|---|---|
| `scPc`, **`final_scPc`** | the honest sumcheck as a program returning its rounds AND its challenges |
| `slotOut`, `slotAfterC`, `slotProg`, **`final_slotProg`** | ONE honest slot as a program: whenever L25's `slotProve` returns, the program ends on its transcript, with its slot proof, record and accumulator |
| `famProve`, **`slotsProve_eq_fam`**, **`stSlotsProve_eq_fam`** | the honest loop over a FAMILY of slot parameters; L25's loop (a block's core, OUT-C) and the stage loop (IN-C, per-slot IO widths) are instances |
| `famProg`, **`final_famProg`**, **`famProve_refuses_at`** | the loop as a program; the loop refuses only at a slot whose state is the one the earlier honest slots LEFT |
| `famPre`, **`final_famPre`** | the prefix of slot `i` of a part: the head, then `i` honest slots |
| `depCProg`, **`depCSite`**, **`depCSite_fires`**; `depEProg`, **`depESite`**, **`depESite_fires`**; **`drawZeroSite_fires_at`** | slot `i`'s sites when its parameters and honest data are read off the prefix's data (the head's challenges; the coins) |
| **`fam_refuse_cover`** | if the honest loop refuses, then at the slot it reached: `define` refused, or the slot's CFS site fires, or one of its round sites fires, or a deterministic schedule check failed |

### 2.7 The three kinds of part (`HonestOracleParts.lean`)

| Theorem / definition | Meaning |
|---|---|
| `SlotCover`, `slotCover_of_refuse` | `fam_refuse_cover`'s conclusion, named |
| `coreHeadProg`, `final_coreHeadProg`, **`core_refuse_cover`** | a block's core (L25's `coreProve`, any `BlockParams`): its head as a program; a refusal is a slot's (covered by its sites) or, after the slots, the functional count or `check_opening` of `A` / `H` |
| `outcHeadProg`, `final_outcHeadProg`, **`outc_refuse_cover`** | stage OUT-C: a refusal is a carry not its own, the D66(3) site, a slot's (covered), or after the slots: the functional count, an output-endpoint claim, `check_opening` of `A` / `H`, the boundary audit |
| `incHeadProg`, `final_incHeadProg`, **`inc_refuse_cover`** | stage IN-C: a refusal is D66(3)'s guard (not one site, L29-3), a slot's (covered), or after the slots: the functional count, `check_opening` of `A` / `H`, the endpoint audit |

The premises of the three cover theorems, all explicit: the part's prefix is a transcript program whose outside
queries are separated (`TProg.Sep`); each root is computed by a Merkle program (`RootProg`) and is the honest data's;
the honest slot data is the coins' (it reads the oracle only through the transcript: the head returns the coins' tag
with its challenges, and the slot family reads it); no wrap of the squeeze counter (`TProg.NoWrap`).

## 3. The `ClassifyOpen` fields

`AssembleClassify.lean`'s `ClassifyOpen R Lq V P Cin h64 hr hon U site kOf δOf E εin εblk εout εep εzk`. **No field is
discharged outright by this lane.** What changed:

| Field | Before (L25) | Now (L29) |
|---|---|---|
| O8 `parts` | reduced to CONTRACTS; the stage verifiers were parameters of L18's instance, their completeness two opaque contracts (`StageInOK`, `StageOutOK`) | the stage verifiers are executable and TESTED against the code; `StageInOK` / `StageOutOK` are PROVED from component contracts of the same kind as a block's (`inc_stageInOK`, `outc_stageOutOK`); **`classify_parts_exec`**: at `V = classifyRunV …` (the executable stages, the D12a blocks) and `P` the honest run's parts, O8 holds from `IncOK`, each block's `D12aBlockOK` and `OutcOK`. Still CONTRACTS inside those three: each slot's arithmetic along the honest run, the completeness of `M`'s test, of every opening and of the boundary opening (L10's executable functions), the honest segments' canonical words, counted shapes and path depths |
| O9 `refuse` | reduced to the cover premise; the stages' refusals open; no site built | the stages' refusal structure PROVED (`incProve_refuses`, `outcProve_refuses`); the cover PROVED part by part (`core_refuse_cover`, `outc_refuse_cover`, `inc_refuse_cover`) GIVEN each part's prefix as a transcript program. Open: the run's prefix up to each part (the earlier parts' openings as transcript programs); `define`'s zero batching draws as sites per instance (the site and its firing condition are proved: `drawZeroSite_fires_at`; the link "`define` refuses only then" is not); `check_opening`'s challenge refusals as sites (L25-2); stage IN-C's D66(3) (L29-3); the deterministic schedule facts (L25-4); `own = true` along the run (L25-1) |
| O10 `counts` | `δ = 0` for transcript-program sites; the count at Shieldstral proved with margins | every site built here is a `tprogSite` (`δ = 0` by L25's theorem) with `k ≤ 2`, or `256` for OUT-C's. Finding L29-3 raises IN-C's LogUp term from 1 site to about 13 of `V` values: inside `shield_k_le`'s margin for that kind (`2^8` sites of `2^17`) [ESTIMATE] |
| O12 `zk` (L19's honest-prover hypotheses) | the "honest rounds" ones discharged | unchanged: `hπ`, `hout`, `hclaim`, the host sums, `hlay` / `hMK`, the openings' coin and weight conditions and the counts by kind `hKw`, `hKc`, `hUw`, `hwb`, `hwba` (with the column digests as programmed points, L19-3) all REMAIN. The cap `R ≤ 2^112` for the run as one receipt stays (L19-2) |
| O1–O7, O11 | as L18 | unchanged |

## 4. `εc` against `εcTarget = 2^-40`

Unchanged from L25 §4 except one line of L18 §4.1's site table [ESTIMATE on CODE counts]:

| Sites | L18 §4.1 | With finding L29-3 |
|---|---|---|
| stage IN-C's LogUp refusal | 1 site, `k = V ≤ 2^17` | `1 + clog2(d_pad) = 13` sites at `d_pad = 4096`, `k ≤ V` each: `Σ k ≤ 13·2^17 ≈ 2^20.7` |
| total | `≈ 2^70.5` | `≈ 2^70.5` (the dominant term is the openings' dependent-proximity refusal, `p ≈ 2^64` per opening) |

So `εc ≈ 2^-57.5` still, far inside `2^-40`; `shield_k_le` (L25) already allows `2^8` LogUp sites of `2^17`.

## 5. Findings

No mismatch was found between the code's stage verifiers and what the approved statements need; `Statements.lean` is
unchanged and no statement or target is weakened. The executable Lean verifiers agree with the Rust on a real receipt
(§7). Findings L29-1 and L29-2 are differences between the CODE and lane L15's stage MODEL (`stageSlots`), handled in
this lane's definitions.

**L29-1 (Low, modelling; no code issue): a stage reads each IO commitment at its own row width.**
- CODE `token_io.rs:1048, :1103`: `run_stage_slot` builds each claim with `sched.row_log[p.cm]`, the row width of the
  claim's own commitment; `stage_in_c.rs:54`: `row_log = [lt, lt, ep_log_n, endpoint_log_n]`, so stage IN-C's two IO
  commitments (the token endpoint, `B_in`) have DIFFERENT widths (8 and 10 on the development rung).
- L9's `BlockParams` has ONE `endpointLogN` for both IO commitments, and L15's `stageSlots` is L9's `slotsLoop`. Read
  literally at one width, IN-C's claims on one of its two IO commitments would be built at the wrong width.
- Here: `stSlotsLoop` runs slot `s` at `atLog P (elog s)`; PROVED that the width changes only the claims
  (`stSlotsLoop_strip`), so L15's Fiat–Shamir model sees the same run (`incSlots_model`). OUT-C has one IO width and is
  `stageSlots` exactly. TESTED: every claim of both stages equals the code's (§7).

**L29-2 (Info, modelling): stage IN-C's `define` reads `r_emb`.** CODE `stage_in_c.rs:166-238`: the context `InCCtx`
carries `r_emb` and the table `τ` (a function of `β`, `γ`, `r_emb`). L9's `define` reads the head's challenges only
through `Hist = (β, γ, α, draws)`. So IN-C's `BlockParams` is a FAMILY indexed by the head's challenges
(`IncV.bp (incCtx pub ch)`), not one object; `incSlots_model` states the link to L15's model at the drawn challenges.
The honest prover's transcript programs must therefore compute a slot's parameters from the prefix's data
(`HonestOracleSlots.lean`'s dependent form).

**L29-3 (Low, completeness arithmetic; no statement change): stage IN-C's D66(3) refusal is not one site at `α`.**
- CODE `stage_in_c.rs:254-262` (`challenges`: `β`, `γ`, `α`, THEN `r_emb`), `:160-164` (`τ(v) = v + β·E~(v, r_emb) +
  β²·ctl(v) + γ·TAG_EMB`), `:329` (the refusal: `α` equals an entry of `τ`).
- L18's site model needs the bad set fixed by the computation BEFORE the challenge is drawn. Here the bad set for `α`
  depends on `r_emb`, drawn after `α`. So `incProve`'s guard `incAlphaBad` is left as a named event in
  `inc_refuse_cover`, not a site.
- The correct count [ESTIMATE, not proved in Lean]: for each vocabulary row `v`, `β·E~(v, r) − (α − v − β²·ctl(v) −
  γ·TAG)` is multilinear in `r = (r_1, …, r_k)`, `k = clog2(d_pad)`. Either it is the zero polynomial, which fixes
  `α` from `(β, γ)` alone (a site at `α`, at most `V` values); or there is a first coordinate `r_i` whose value kills
  it, one value per `v` (a site at `r_i`, at most `V` values). In total `k + 1` sites of at most `V` values: `13·2^17`
  at Shieldstral (`d_pad = 4096`), against L18's `2^17`.
- Consequence: none for the target (§4). The Lean construction of these `k + 1` sites needs `E~` as a multilinear
  polynomial in `K`, which `IncPub.embFold` (an opaque function) does not give; it is left open.
- Stage OUT-C does NOT have this: its table `z + γ·TAG_U8` depends only on `γ`, drawn before `α`
  (`outcAlphaSite`, PROVED).

**L29-4 (Info, a premise to check when the run is assembled): the honest slot data must read the oracle only through
the transcript.** A site's computation is a program of the coins, so the slot's honest data (`SlotData`: the scalar,
the round words, the terminals) may depend on the coins and on what the transcript gave (the history, the definition,
the challenges), not on the hash function directly. L25's and this lane's completeness contracts take the data as a
function of the hash function (`D H s x c`); the cover theorems ask that its slot part be the coins' (`hD : D.slot = Dc
c`). True of the code (the planes, masks and tables are the witness and the RNG's) [CODE reasoning]; it must be stated
when the run's prover is instantiated.

**L29-5 (Info, modelling): two deterministic refusals of the code are the statement's data here.** CODE
`stage_in_c.rs:431` computes `b_spec.mask_row(0)?` after `absorb_root("H")`, and `stage_out_c.rs:689` the same for
`mask_row(1)`: a geometry error there would refuse mid-stage. In Lean the reserved rows are fields of `IncGeo` /
`OutcGeo` (the statement's geometry), so that refusal is outside the model; it cannot fire for a registered geometry
[CODE reasoning]. Listed with L25-4's deterministic refusals.

**L29-6 (Info, the transcript programs past a refusal).** A slot's program runs to its end even when the slot's guard
has fired (the code's prover stops there). Nothing proved here reads a program past its first refusal: a later site's
firing condition is stated only when the earlier honest slots returned (`final_famPre`), and `δ = 0` and `k` hold for
every program.

## 6. What is left

- **O8**: the CONTRACTS of `IncOK`, `D12aBlockOK`, `OutcOK`: each slot's arithmetic along the honest run (for the
  stages: the twelve slot polynomials' degrees and true sums, from L12's and L15's stage arithmetic); the completeness
  of L10's executable `M` test and openings (`mask_verify_tagged`, `verify_zk_tagged`) and of the two audits; the
  honest segments' canonical words and shapes.
- **O9**: (a) the openings' provers as transcript programs, so that the prefix up to each part exists and the three
  cover theorems chain into `classify_refuse_of_cover`'s premise; (b) per instance, `define` refuses only on a zero
  batching draw (then `drawZeroSite_fires_at` applies) and the builder never fails; (c) `check_opening`'s challenge
  refusals as sites (L25-2); (d) stage IN-C's D66(3) as `k + 1` sites (L29-3); (e) the deterministic facts (L25-4,
  L29-5) and `own = true` (L25-1).
- **O10**: follows O9's sites; the counts per kind stay CODE counts, with §4's correction.
- **O12**: all of L19's hypotheses except the honest rounds (L25); the prover's `FSModel` form. Not started here.
- **L29-3**: `E~` as a multilinear polynomial, and the `k + 1` sites.

## 7. Checks

CHECKS_SECTION
