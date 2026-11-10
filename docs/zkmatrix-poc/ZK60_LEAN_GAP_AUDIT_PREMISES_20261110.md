# ZK60 Lean gap audit: the premise register and the vacuity hunt (2026-11-10)

Independent audit of the D63 Lean formalization, at perf `2155ede8` (lane L34 merged). Scope: the top theorems about
the classify run, every premise they take, and whether those premises can hold at the real system. Evidence:
`results/zk60_gap_audit_premises_20261110/` (scratch Lean files, never imported by the root, and their logs). Every
claim below is labelled PROVED (a Lean theorem, with its name), CHECKED (Lean output I ran, with the log), or ARGUED.
No library file, no Rust and no shared doc was changed.

## In plain words, for Victor

**Are there gaps? Yes, and most of the proof's substance is still in them.** The strongest statement in the tree,
`rt_productionReady_r13`, is a true theorem with no `sorry` and only the three standard axioms [CHECKED, iter1.log].
But it is an implication: "if these hypotheses hold, the classify run is `ProductionReady`". Besides the structure
`ClassifyOpen` (16 fields, 4 of them empty), it takes 39 named propositional hypotheses, and several structure-valued
premises (the schedule `Rn`, the kinds data `D`, the column test `T`, the honest salts `hon`, `mk`) with conditions
inside them [CHECKED: the printed statement, iter2.log:5-432]. What is actually proved is the bookkeeping that turns per-step soundness into the approved error bound, the
binding of the input commitment, the circuit equivalence, the completeness arithmetic and the transcript object. What
is assumed is:

1. **All of statement 2 (zero knowledge and semantic hiding).** The conclusion's two privacy parts are the premise
   `O.zk` (O12) passed through unchanged [PROVED: `gap_zk_passthrough`].
2. **The heart of soundness.** Five deterministic "cover" premises (`halive`, `hdin`, `hdblk`, `hdout`, `hdzero`) and
   two endpoint links (`hread`, `hBal`) say, in effect, "whenever the extracted data is wrong, some check started from
   a false claim". That IS the soundness argument for stage IN-C, the 26 blocks and stage OUT-C. None is started.
3. **The heart of completeness.** O8 to O10: every part's honest segment is accepted, and the honest prover refuses only
   at counted places. Reduced by L25, L29 and L32; the slots' arithmetic is not started.
4. **The real system itself.** The run verifier `V`, the honest prover `P`, the block shape `S`, the public run data
   (template, the 26 blocks' weights, the verdict policy) and the block verifier's parameters are all free variables.
   No Lean object is "the Shieldstral T128 R13 run". "R13" in the theorem's name fixes only the input commitment's
   code and the error constants.

**One new finding matters (GA-1, High, PROVED).** The only way the tree builds the run's schedule `Rn` at the code's
verifier is `rtRunClassify` (lane L34). Its premise for stage IN-C, `RtInc`, can only be met by a stage IN-C that never
accepts anything. I proved that with any `RtInc`, the run verifier rejects every receipt
(`gap_rtRunClassify_never_accepts`), and that the top theorem's premises at that verifier, with any `RtInc` and any
admissible input, imply `False` (`gap_route_inconsistent`). So the top theorem, applied the way L34's doc says to apply
it, is empty. This is the same kind of slip as L31-1. It is a defect in a Lean contract, not in the protocol, and the
fix is small: `RtInc.hcnt` (and `RtOutc.hcnt`) need the same slot-count guard `RtBlk.hcnt` already has.

**Counts** (section 2 has every row): 47 register rows.
- 30 open obligations (a). 10 of them are substantive: the five cover premises, the two endpoint links, O8, O9 and
  O12. The other 20 are bookkeeping: true by construction, by `decide` or by arithmetic once the concrete instance is
  written.
- 2 suspect or proved vacuous (b): `RtInc` (PROVED, GA-1) and `RtOutc`.
- 6 modelling assumptions (c), 2 waiting on your ruling (d), 4 public-data facts (e).
- 3 need nothing: `hzk` is trivial, O6 is discharged here from the definitions, O11 is not an obligation at all.

**What it would take to close** (durations are ESTIMATES). (1) Guard `RtInc.hcnt` / `RtOutc.hcnt` (hours). (2) Write
the concrete Shieldstral R13 instance and one theorem at it, so every bookkeeping premise is discharged and the real
obligations stand alone (days). (3) Prove the cover premises: this is the soundness proof of each part on the run's
transcript, with the per-block results of L31 / L35 wired in; today no top theorem uses any block theorem (weeks).
(4) Completeness O8 to O10 (L32's list; weeks). (5) Zero knowledge O12, after your rulings D75(1) and D75(2) (weeks).
(6) The 8B token-I/O run has no protocol instance and no `ProductionReady` statement at all.

## 1. The top of the chain

| Theorem | File | What it is | Status |
|---|---|---|---|
| `rt_productionReady_r13` | RunTrGate.lean:58 | L30's gate with the transcript `rtTr`, the nine kinds and the column test's parse discharged; any `V`, schedule `Rn` | the strongest (fewest premises); axioms `propext`, `Classical.choice`, `Quot.sound` [CHECKED iter1.log:216] |
| `classifyU_productionReady_run_r13_token` | RunChainUToken.lean:171 | the gate at R13's token endpoint, kinds and transcript still premises | weaker: `rt_…` instantiates it |
| `classifyUExec_productionReady_run_r13` | RunChainUExec.lean:196 | the gate at `V := classifyRunV …`, transcript and kinds still premises | not combined with `rt_…` by any lane |
| `block_knowledge_final_r13_shield` (and `_r13`, `_w16r2`) | BlockInstFinal.lean:270 | one block: `Pr[accepted ∧ ¬BlockSat] ≤ εsTarget q + εend` | NOT used by any top run theorem [CHECKED, below] |

- The combination of the two (`rt_productionReady_r13` at `V := classifyRunV … (d12aBlockProf …) …` with
  `Rn := rtRunClassify …`) is the strongest statement about the run at the code's verifier shape. No lane wrote it.
  It typechecks by instantiation alone [CHECKED: `gap_c_compose.lean`, iter5.log], and it is empty (GA-1).
- Dependency closure of `rt_productionReady_r13` inside `ZK60` (3,029 constants) [CHECKED: `#gap_deps`, iter1.log:772]:
  uses `ClassifyOpen.zk`, `.parts`, `.refuse`, `.counts`, `.shape`, `.weights`, `.inPub`, `.outPub`, `.blocks`,
  `.commit`, `.policy`, `classifyRun_circuitIff`, `classify_complete_target`, `classifyU_productionReady_ep_target`,
  `encLin_caOn`; does NOT use `ClassifyOpen.extIn/extBlocks/extOut/extEp` (O11), any of the three
  `block_knowledge_final_*`, `rtRunClassify` or `rt_hwin`.
- The exact statements, every binder shown, are in iter2.log:5-432 (`rt_…`), :433-1221 (`classifyUExec_…`),
  :1222-1516 (`block_knowledge_final_r13_shield`).

## 2. The premise register

Classes: (a) open obligation, (b) suspect or proved vacuous, (c) modelling assumption, (d) waiting on a ruling, (e)
public-data fact. "Bookkeeping" marks an (a) that becomes true by construction, by `decide` or by arithmetic once the
concrete instance is written. File:line is the hypothesis in `RunTrGate.lean` unless another file is named.

### 2.1 Hypotheses of `rt_productionReady_r13`

| # | Premise | Meaning | file:line | Class | Discharged by | Vacuity verdict | Evidence |
|---|---|---|---|---|---|---|---|
| 1 | `hpos`, `msg_place`, `place`, `msg`, `pad`, `salt`, `path`, `tagc` | the token-words plane's layout in the input commitment | :45-48 | (a) bookkeeping | NOT (no Shieldstral layout object) | satisfiable by construction | ARGUED |
| 2 | `h64`, `hr`, `hs`, `hL`, `hL64` | query-length bounds, the domain string's facts | :59-62 | (a) bookkeeping | NOT (decidable on the concrete string) | satisfiable | ARGUED |
| 3 | `hon : HonestIn` | the honest salt and paths (3 equations) | :60; ProtocolClassify.lean:652 | (a) bookkeeping | NOT | satisfiable with `Salt` carrying the paths | ARGUED |
| 4 | `hbij` | `U` gives `K ≅ GF²` | :60 | (a) bookkeeping | `fp2_bijective` (HidingMOpening.lean:701) once `K` is built | satisfiable | ARGUED |
| 5 | `Rn : RtRun V …` | the run's schedule: header ops (`hstart`, `hhdr`), each part's contract (`hσ`) | :62; RunTrVerify.lean:136 | (a) bookkeeping once GA-1 is fixed; the tree's only constructor at the code's verifier is (b), rows R2, R3 | NOT; `rtRunClassify` is empty (GA-1) | the structure is satisfiable in principle; the route is not | PROVED GA-1 |
| 6 | `hv : Rn.pf.Valid` | the profile: header nonempty, squeeze runs ≤ 2^61, ≤ 2^21 operations | :63; RunTrSched.lean:156 | (a) bookkeeping | NOT | satisfiable (L34 ESTIMATE about 4·10^5 operations) | ARGUED |
| 7 | `D`, `hD : D.Valid` | the nine kinds' data per part and side conditions | :63-64; RunTrKinds.lean:484 | (a) bookkeeping (the blocks' lists come from L21, L23, L28; the stages have none yet) | NOT | trivially satisfiable (empty lists, constant readers): `Valid` does not say `D` is the run's real sub-protocols; that tie is rows 13-16, 21 | ARGUED from the printed structure, iter1.log:454-508 |
| 8 | `site`, `kOf`, `δOf` (with `Site.hk`, `hfresh`) | the honest prover's refusal sites | :65; ProtocolClassifyComplete.lean:94 | (a) bookkeeping; the content is O9 | NOT | see O9 | ARGUED |
| 9 | `E`, `hE` | the extractor; its endpoint words are the decoded openings | :66, :113-115 | (a) bookkeeping | NOT | satisfiable by construction of `E` | ARGUED |
| 10 | `T : XTest`, `hTenc`, `hTaA`, `hTaB`, `pr`, `hp1`, `hp2`, `hF`, `hw0`, `hβLR`, `hTe`, `hTQ`, `hβJ` | the input commitment's column test and its numbers | :70-79; ProtocolClassifyUEp.lean:138 | (a) bookkeeping | `T`'s code facts `hd`, `h2`, `hA`, `hAN`, `hca` PROVED here (`gap_xtest_code_r13`); `hLR`, `hJ` from `lrCode_prob_le`, `idxCode_prob_le` (used for the kinds, not yet for `T`) | satisfiable (`pr := p`, `F := GF(p²)`) | PROVED in part |
| 11 | `Ux`, `Xx`, `hUc`, `hXc` | the test's extraction reads the log only through cuts | :73-76 | (a) bookkeeping | NOT | satisfiable by construction | ARGUED |
| 12 | `tag`, `C`, `coreOf`, `Vx`, `nx`, `hVx`, `hnx`, `rx`, `nrx`, `hrx`, `hnrx` | the run's Merkle work outside the blocks' `A`, `H`, `M`, with its bounds | :80-83 | (a) bookkeeping | NOT (L34 item 4 not started) | satisfiable; but `Vx`, `rx` must cover ALL the run's other Merkle work, or rows 13-16 become unsatisfiable (they must hold outside `EvXR` only) | ARGUED |
| 13 | `halive` | on every accepted run outside `EvXR`, the nine kinds are alive in the order `opB, M, opA, slots, draws, hosts, LogUp` | :84-88; RunChainUOrd.lean:61 | (a) | NOT (L34: not started) | plausible (L30's ordered form answers L30-1); needs L34-1's congruence lemma | ARGUED |
| 14 | `hdin` | stage IN-C's conclusion fails ⇒ a doomed entrant in part 0 | :89-94 | (a) | NOT | plausible through IN-C's relation draws (a false relation is false at its entry, B_in being absorbed in IN-C's frame) | ARGUED |
| 15 | `hdblk` | block `k`'s `BlockOn` fails ⇒ a doomed entrant in part `k + 1` | :95-102 | (a) | NOT | plausible: input range is block-local (`BlockSat.inX`, CircuitBlock.lean:351), relations as row 14; the endpoint-claim route lands in the next part (L34-2) | ARGUED |
| 16 | `hdout` | stage OUT-C's conclusion fails ⇒ a doomed entrant in part `L + 1` | :103-110 | (a) | NOT | plausible as row 14 | ARGUED |
| 17 | `mk`, `ops`, `hops`, `hcan` | the extractor's endpoint openings verify and are canonical | :111-119 | (a) bookkeeping | NOT | satisfiable by construction (`ops` filters) | ARGUED |
| 18 | `hwin` | the test's two windows at steps' ends | :120-127 | (a) bookkeeping | `rt_hwin` (RunTrWin.lean:128) when `T.aA`, `T.aB` are part 0's `oX`, `oBX`; not applied | satisfiable | ARGUED (statement shapes match) |
| 19 | `hread` | the test's matrix and openable set are the extractor's openings | :128-134 | (a) | NOT | satisfiable by defining `Ux`, `Xx` from `ops` cut at the root | ARGUED |
| 20 | `hBal` | the test's second half alive at the end | :135-140 | (a) | NOT (L30's `xB_subSt_of_opB` reduces it to the endpoint's `opB`) | plausible | ARGUED |
| 21 | `hdzero` | the decoded endpoint plane is zero off the token positions, or a doomed entrant | :141-146 | (a) | NOT (L26-4) | plausible | ARGUED |
| 22 | `hzk` | `εzk ≤ εzkTarget` | :147 | trivial | `εzk := εzkTarget` | — | — |

### 2.2 `ClassifyOpen` (AssembleClassify.lean:205)

| # | Field | Meaning | line | Class | Discharged by | Vacuity verdict | Evidence |
|---|---|---|---|---|---|---|---|
| O1 | `shape` | `S.Valid`: 24 numeric bounds | :211 | (e) | NOT for Shieldstral's `S` (no concrete `S`); `w16r2_8B_geometry` checks 7 of them for 8B | satisfiable | ARGUED |
| O2 | `weights` | every block's public data in its classes | :214 | (e) | NOT: needs the weights (D62) | satisfiable if the export is in class | ARGUED |
| O3 | `inPub` | stage IN-C's public data valid | :216 | (e) | `shield_inp_valid` / `shield_in_valid` (StageCheckValid.lean:108) for the registered policies, given an int16 embedding | satisfiable | CHECKED statement |
| O4 | `outPub` | stage OUT-C's public data valid | :218 | (e) | `shield_outc_valid` (StageCheckValid.lean:138) at d = 3072, given weight bounds | satisfiable | CHECKED statement |
| O5 | `blocks` | `0 < L`, `V.L = L` | :220 | (a) bookkeeping | NOT | trivial at the instance | — |
| O6 | `commit` | the endpoint's geometry | :223 | discharged | PROVED here: `gap_o6_r13` | — | iter6.log:12 |
| O7 | `policy` | `V.preA`, `V.preB` accept the prover's header | :226 | (a) bookkeeping | NOT | decidable once concrete | ARGUED |
| O8 | `parts` | each part's honest segment is accepted (`SegComplete`) | :229 | (a) | NOT (L32 §6: slots' arithmetic not started; transcript-aware parts, L32-1) | alone it is met by a prover that always refuses (`gap_segComplete_refuser`); its content is O8 with O9, O10 | PROVED |
| O9 | `refuse` | the honest prover refuses only at a listed site | :233 | (a) | NOT (L32 §6 O9 (a) to (e)) | plausible; forces "no deterministic refusal of an admissible input" | ARGUED |
| O10 | `counts` | `Σk ≤ 2^85`, `Σδ ≤ 2^-41` | :237 | (a) bookkeeping, follows O9 | per-opening count exact (L32); rest follows O9 | satisfiable | ARGUED |
| O11a-d | `extIn`, `extBlocks`, `extOut`, `extEp` | the run's extraction, part by part | :242-267 | NOT an obligation at the top theorems | `gap_o11_top`: met at `εin = … = ⊤`, which the top theorems leave free; not in the proof's closure | vacuous as a premise (harmless) | PROVED; CHECKED iter1.log:773-776 |
| O12 | `zk` | `ZeroKnowledge` of the run at `εzk` | :272 | (a) and (d) | NOT; L33 reduces it to named premises, proved target only for R ≤ 2^110 receipts | the conclusion's `zk` and `semantic` ARE this premise (`gap_zk_passthrough`) | PROVED |

### 2.3 The schedule route `Rn := rtRunClassify …` (RunTrStages.lean:571)

| # | Premise | Meaning | file:line | Class | Verdict | Evidence |
|---|---|---|---|---|---|---|
| R1 | `hstart`, `hhdr` | the header's operations | RunTrStages.lean:573-575 | (a) bookkeeping | satisfiable | ARGUED |
| R2 | `I : RtInc` | stage IN-C's contract inputs | RunTrStages.lean:309 | **(b) PROVED unsatisfiable for any IN-C that accepts** | `hcnt` (line 324) has no slot-count guard; the empty core passes the slot phase, so every count is 0; IN-C needs exactly one endpoint claim | PROVED: `gap_rtInc_counts`, `gap_rtInc_never_accepts`, `gap_rtRunClassify_never_accepts`, `gap_route_inconsistent` |
| R3 | `O : RtOutc` | stage OUT-C's | RunTrStages.lean:444 | (b) | forces `nA = 0`, `nH = 1`, `nIn = 0` (PROVED `gap_rtOutc_counts`); whether OUT-C then never accepts not proved | PROVED in part; ARGUED |
| R4 | `bp k : RtBlk` | each block's | RunTrParts.lean:307 | (a) bookkeeping | `hcnt` IS guarded (`core.slots.length = …`); L31's `hcnt_of_defCm` gives it | ARGUED |
| R5 | `pX`, `gX`, `hgeo`, `hgX`, `pend`, `hI`, `hbp`, `hO` | boundary openings and claim counts | RunTrStages.lean:576-580 | (a) bookkeeping | satisfiable | ARGUED |

### 2.4 Modelling assumptions, rulings

| # | Assumption | Stated? | Standard? | Note |
|---|---|---|---|---|
| M1 | the hash is a uniformly random function on bounded queries (`prH`) | yes, Statements.lean:18 | yes (ROM) | the code uses BLAKE3 |
| M2 | the Lean run verifier `V` is the production verifier | D63 §6 choice; `V` is a free parameter | — | code-shaped `classifyRunV` checked per segment against corpora (L9, L17, L18, L29); not on a Shieldstral T128 receipt (L29; L31-3) |
| M3 | the Lean honest prover `P` models the Rust prover | no; `P` is a free parameter | — | `Complete` and `ZeroKnowledge` are about `P`; an honest statement's verdict is DEFINED as the model's (`clsStmtOf`), so `Complete`'s verdict conjunct is true by definition |
| M4 | the integer model `classifySpec` is the code's arithmetic | CircuitIff PROVED for the constraint system; model to Rust by corpora | — | the other auditor's scope |
| M5 | `Weights := Unit`, the weights live in the public run data `Rp` | yes | fine under P1 | `gap_units`; the `∀ W` ranges over one point |
| M6 | the extractor is any function of the log | Statements-level | — | the other auditor's scope |
| D1 | the instance's `opensIn` is `OpensU` at radius `e = 24,448` (L24-1) | D75(1) | — | every top theorem is at `classifyProtocolU`; under Choice B none is about the approved instance |
| D2 | O12 for every receipt count R | D75(2) | — | proved target R ≤ 2^110 (L33-3); `εzkTarget q R ≥ 1` once R ≥ 2^120 (`gap_epsZk_top`) |

## 3. Findings

**GA-1 (High; for the coordinator and the next run lane; PROVED; not a protocol weakness): L34's stage contracts
`RtInc` and `RtOutc` can be met only by stages that never accept, so the top theorem through `rtRunClassify` is empty.**
- `RtInc.hcnt` (RunTrStages.lean:324) asks the claim counts of EVERY core whose slot phase stage IN-C accepts to be
  `nA`, `nH`, `nIn`, `nOut`. A core with no slots passes the slot phase (`stSlotsLoop` on `[]` is `.ok`) with the empty
  accumulator. So any `RtInc` has `nA = 0`, `nH = 1`, `nIn = 0`, `nOut = 0` (`gap_rtInc_counts`).
- Stage IN-C accepts only with exactly one claim on the input token endpoint (`checkTokenEp`,
  StageVerifyExec.lean:196). So with any `RtInc`, stage IN-C never accepts (`gap_rtInc_never_accepts`), and
  `classifyVerifyE (classifyRunV … inc incG …)` rejects every header, oracle and receipt
  (`gap_rtRunClassify_never_accepts`).
- `ClassifyOpen` at that verifier gives `Complete` at 2^-40 (L18's `classify_complete_target`). Together with any
  `RtInc` for the same stages and any admissible input this is `False` (`gap_route_inconsistent`).
- L34's doc names `rtRunClassify` as the schedule at `V := classifyRunV …` and lists `RtInc` as "to discharge"
  (§1.1, §3.1). As written it cannot be discharged. `RtOutc.hcnt` has the same gap (`gap_rtOutc_counts`).
- `rt_productionReady_r13` itself is not shown empty: `Rn` is a free argument, and `RtRun` can be built another way.
- Fix: give `RtInc.hcnt` and `RtOutc.hcnt` the guard `RtBlk.hcnt` has (`core.slots.length = (V hd).geom.slots.length`;
  `rtInc_holds` already has the core's `CoreShape` from `rt_decodeStage_spec`), and re-prove `rtInc_holds`,
  `rtOutc_holds`. Also restrict the "for every header" counts to headers the policy accepts (L34-3).

**GA-2 (Medium; for the coordinator; PROVED; docs): statement 2 is assumed in every top theorem.** The conclusion's
`zk` and `semantic` conjuncts follow from `O.zk` and `hzk` alone (`gap_zk_passthrough`). The lane docs list O12 as
open, so nothing is hidden, but phrases such as "`Complete` and `ZeroKnowledge` carry over with the same bounds"
(MVP_STATUS, L26 bullet) and "ProductionReady … given premises" read stronger than the Lean. For the run, statement 2
is not proved at any receipt count.

**GA-3 (Medium; for Victor and the coordinator; CHECKED and PROVED): no top theorem uses a block theorem; each of the
26 blocks is covered only by the premises `hdblk` and `halive`.** The three `block_knowledge_final_*` are outside
`rt_productionReady_r13`'s dependency closure [CHECKED iter1.log:788-790]. They also carry a free `εend` whose only
constraint, `hEnd`, holds at `εend = ⊤` for every adversary; at `⊤` their bound is empty (`gap_block_end_free`). The
docs say so correctly ("plus the endpoint term"); the point is that "the app's block is proved" has no effect on the
run's statement until `hdblk` / `halive` are discharged from it (L34 §3.4 items 3, 4).

**GA-4 (Medium; for the coordinator; ARGUED, CHECKED by the printed statements): the "R13" theorems are schemas, not a
statement about the Shieldstral run.** `S`, `Rp`, `V`, `P`, the block verifier's parameters `Pk` (in
`classifyRunV … (d12aBlockProf Pk …)`), and the endpoint's `msg`, `pad`, `salt`, `path` are free [CHECKED
iter2.log:5-30]. Nothing ties `Pk` to `IsShieldR13`, `Rp` to Shieldstral's 26 blocks, or `EvXR`'s hard-wired `26`
blocks and depths `16, 16, 12` to `Rp.Ps.length` and the real Merkle work. "R13" fixes the input commitment's code
(`r13TokenCommit`, radius 24,448) and the kinds' error constants. A concrete instance is the next step (L34 §3.4 item 1).

**GA-5 (Low; for the coordinator; PROVED, CHECKED): `ClassifyOpen`'s O11 fields are vacuous premises of the top
theorems.** The four extraction errors are free implicit arguments; at `⊤` the fields are `le_top` (`gap_o11_top`); the
proof never reads them [CHECKED iter1.log:773-776]. Harmless, but a reader counting "16 obligations" overcounts by 4.

**GA-6 (Low; for the next completeness lane; PROVED): `SegComplete` (O8) alone does not tie the Lean prover to
anything.** A segment prover that always refuses meets it against any verifier (`gap_segComplete_refuser`). The content
is O8 with O9 and O10 (which force acceptance with probability ≥ 1 − 2^-40). This is also why GA-1 is caught.

**GA-7 (Low; for the cover lane; ARGUED): `hdin`, `hdblk`, `hdout` should name "some part", as L34-2 proposes.** I find
the relation route sound for all three (a failed relation is false at its draw's entry in the part itself; a block's
input range check `BlockSat.inX` is local), so the premises are plausibly true as written; but the endpoint-claim route
lands in the next part, and the proof (`kindEv_of_dm_ord`) needs only some part.

**GA-8 (Low; for the cover lane; ARGUED): the Merkle event `EvXR` covers only what `coreOf`, `Vx`, `rx` name.** The
cover premises must hold on every accepted run outside `EvXR`, deterministically. If `Vx` or `rx` miss any of the run's
non-block Merkle checks (boundaries, stages), a lucky Merkle collision there falsifies a cover premise, and the top
theorem cannot be applied. Pick them to be exactly the verifier's work; `EvXR`'s bound already allows `nx ≤ 3.8M`
queries and `2^99` roots.

**GA-9 (Info; PROVED): the conclusion's numbers mean what they say.** `εcTarget < 1` (`gap_epsC_lt_one`);
`εsTarget q < 1` for `q ≤ 2^98` (`gap_epsS_lt_one`); `εzkTarget q R ≥ 1` for `R ≥ 2^120` (`gap_epsZk_top`), so the
zero-knowledge statement says nothing beyond 2^120 receipts. `CircuitIff` holds for the trivial arithmetization
(`gap_circuitIff_free`), so the `circuit` conjunct constrains nothing; the relation the extractor must hit is the
integer model's verdict on the committed input (`KnowledgeSound`: `admissible x`, `OpensU` at radius `e`,
`ypub s = classifySpec R x`), as D63 approved, at D75(1)'s reading of "committed".

**GA-10 (Info; CHECKED by grep): nothing about the 8B token-I/O run beyond its circuit.** `tokenRun_circuitIff` and the
generic `token_inner_of_stages` exist; no `Protocol` instance and no `ProductionReady` statement for `tokenModel`.

## 4. Coverage map

| Part of the real classify run | In the top theorem's conclusion | Proved or assumed |
|---|---|---|
| run header | absorbed operations | ASSUMED (`Rn.hstart`, `hhdr`; O7 the policy) |
| input commitment | `Binding` at the target; extraction at radius `e` | Binding PROVED (L26); extraction PROVED from rows 9-11, 17-21 (endpoint links) and the column test's kinds |
| stage IN-C | `InOk` on the extracted data | ASSUMED (`hdin`, `halive`); executable verifier L29, corpus-checked on a rung receipt |
| each of the 26 blocks | `BlockOn` on the boundary planes | ASSUMED (`hdblk`, `halive`); per-block theorems exist but are not used (GA-3) |
| boundary openings | inside the opening kinds | forms PROVED (`rtK_forms`); "false claim ⇒ doomed `opA`" ASSUMED (`halive`, `hdblk`) |
| stage OUT-C | `OutOk` for the statement's verdict | ASSUMED (`hdout`) |
| Merkle layer | the extraction failure `EvXR` | bound PROVED (`extract_fail_classify_run`) for the work `coreOf`, `Vx`, `rx` name (GA-8) |
| Fiat–Shamir | the first-doom count over the nine kinds plus the test's two | PROVED: per-kind round-by-round (`RtKPart.of*`), composition (L24, L27, L30), transcript object (L34), given `Rn` (GA-1) |
| completeness | `Complete` at 2^-40 | arithmetic PROVED; its inputs O8-O10 ASSUMED |
| zero knowledge | `ZeroKnowledge`, `SemanticHiding` | ASSUMED (O12; GA-2) |
| the circuit | `CircuitIff` | PROVED (`classifyRun_circuitIff`) given O1-O4 |
| 8B token-I/O run | — | only `tokenRun_circuitIff` (GA-10) |

## 5. Checks run

All through the resource guard, class cpu, one job at a time; every scratch file runs with `lake env lean` against the
merged tree's build cache.

| Job | File | Result | Log |
|---|---|---|---|
| gap-prem-iter1 | `gap_a_statements.lean`: `#check`, `#print axioms` of the 7 top theorems, `#print` of 18 structures, the dependency closure | exit 0; every top theorem on `propext`, `Classical.choice`, `Quot.sound` | iter1.log |
| gap-prem-iter2, -iter3 | `gap_a2_full.lean` (full statements, no `⋯`); `gap_b_probes.lean` (9 theorems) | exit 0 after one fix; 9 of 9 on the standard axioms | iter2.log, iter3.log |
| gap-prem-iter5 | `gap_d_rtinc.lean` (4 theorems), `gap_c_compose.lean` (the composition types) | exit 0 | iter5.log |
| gap-prem-iter6 | `gap_d_rtinc.lean` (5 theorems, with `gap_route_inconsistent`), `gap_e_discharge.lean` (2 theorems) | exit 0; 7 of 7 on the standard axioms | iter6.log |

No scratch file uses `sorry`, `axiom` or `native_decide`.

## 6. Not finished

- I did not build a concrete instance, so for rows 13-16 and 19-21 the verdict "plausible" is ARGUED, not shown.
- I did not prove that stage OUT-C never accepts under `RtOutc` (GA-1, second half); only the forced zero counts.
- I did not check the per-block theorems' own premises (`hPoly`, `spR`, `hvR`, … of `block_knowledge_final_*`); they
  are outside the run theorem's closure and are lane L35's.
- `hLR`, `hJ` of the column test were not discharged here (the library lemmas exist).
