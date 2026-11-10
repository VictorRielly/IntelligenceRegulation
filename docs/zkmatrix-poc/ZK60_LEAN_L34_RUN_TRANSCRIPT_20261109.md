# ZK60 Lean lane L34: the classify run's transcript as a Lean object (2026-11-09)

Lane L34 of D63. Files: `formal/ZK60Formal/RunTr*.lean` (eight library modules). Evidence:
`results/zk60_lean_l34_20261109/`. Task list: `ZK60_LEAN_L30_RUN_GATE_U_20261109.md` §5.7.

## In plain words, for Victor

The classify run (run header, stage IN-C, 26 blocks, stage OUT-C) uses ONE Fiat–Shamir transcript. L30's soundness
gate for the run took that transcript as a premise: "give me the list of everything the verifier hashes, with every
challenge at a known position". This lane writes that object and proves the facts about it that the gate asks.

What is now proved (Lean, no gap inside these statements):

1. **The transcript.** The run's list of transcript operations is a function of the statement and the receipt alone.
   Whenever the run verifier accepts, the transcript it really hashed is this list, and its state before each part
   is the list's prefix.
2. **Fixed positions.** On an accepted run every part's operation and squeeze counts are the profile's constants.
   So every window sits at a fixed position. This closes findings L27-2 and L28-1 at run level.
3. **The two readings.** The transcript is given both readings the gate needs (every squeeze its own step; wide
   challenge vectors as one step), each with at most `2^21` items.
4. **The nine kinds.** The nine families of sub-protocols are built on that transcript, part by part, with exactly
   the cost forms the gate asks. Each part's closing opening (the input endpoint, a boundary, `B_out`) is inside the
   two opening kinds, so the block's "endpoint claims" term (`εend`) adds nothing to the count.
5. **The gate applied.** L30's gate is applied to these objects. Its premises about the transcript, the kinds, their
   forms and the parses are gone. One endpoint premise (`hwin`) is also proved.

What is NOT done. The real run's numbers (the 28 parts' counts for Shieldstral T128) and the per-part lists of slots
and draws enter as data with stated conditions; they are not yet instantiated. The cover (`halive`, `hdin`, `hdblk`,
`hdout`), the Merkle extra work and three of the four endpoint premises are untouched. A comparison of the whole
run's operation list with a Rust receipt needs new test-only Rust, which I did not write. So this is the core of the
lane (items 1 to 3 and 7 of the task list, one premise of item 6), not all of it.

Nothing here is a production claim. No Rust changed. No statement was weakened. No existing Lean file changed.

## 1. What is proved

All in namespace `ZK60.ProtocolClassify`. "Profile" means the record `RtProf` of counts: the header's, and for each
part the counts `RtPart` (its single-step phase, `M`'s mask count `S`, and for each of its three openings `A`, `H`,
`X` the batching width, the group count and the index-squeeze count).

Every part has the same shape: a single-step phase (frame, roots, head challenges, slots), then `M`, then the
openings of `A`, of `H`, and of the commitment the part closes (`X`: the input endpoint in stage IN-C, the previous
boundary in a block, `B_out` in stage OUT-C).

### 1.1 The transcript and its parses (items 1 and 2)

| Theorem or object | File | Meaning |
|---|---|---|
| `rtTr` | Sched | the run's transcript: the trace of the run's operations from the fresh keyed transcript. An output that has not the profile's shape gets the empty step list, so the object is defined for every oracle and output |
| `rt_stpOK` | Base | a step list whose squeeze runs have the profile's widths parses under the widths function `rtW` (one parse for the whole run) |
| `rtRC1`, `rtRC2` | Sched | the two parses as L27's `RunChain`: single steps (`W1`, `stepsOne`), and wide runs (`rtW`, `stepsB`); header `hdrLen − 1` |
| **`rtRC1_chain`**, **`rtRC2_chain`** | Sched | `htr`: each parse's chain IS `rtTr`, for every oracle and every output |
| `rtRC1_ℓ`, `rtRC2_ℓ` | Sched | `ℓ = 2^21` |
| **`rtTr_split`**, **`rtTr_part`** | Sched | the transcript cut at a step boundary: prefix and suffix are traces; the cut is a step's end under the wide parse; the squeeze counter there is the profile's (`sqAt i + …`); the rest parses from it |
| `RtSeg.Holds` | Verify | one part's contract: if its framed step accepts, the transcript moves by the part's steps on the data read from the segment, and that data has the profile's counts |
| **`RtRun.accept`**, **`RtRun.acceptU`** | Verify | acceptance ⇒ the output has the profile's shape (`RtGood`) and the verifier's final transcript is `runOps` of the run's steps |
| **`RtRun.accept_part`**, **`RtRun.acceptU_part`** | Verify | acceptance ⇒ before part `i` the verifier's transcript is `runOps` of the prefix up to part `i`, and part `i`'s step accepted from there |
| **`rtBlock_holds`** | Parts | block `k`'s contract on the D12a frame with its boundary opening, from L28-form premises (`maskField`, `PcsOk`, the claims' counts, the slot geometry) |
| **`rtInc_holds`**, **`rtOutc_holds`** | Stages | stage IN-C's and stage OUT-C's contracts on L29's executable stages |
| **`rtRunClassify`** | Stages | the schedule (`RtRun`) at `classifyRunV … (d12aBlockProf …) …`, the verifier of `classifyProtocolUExec` |

How the object stays oracle-free: the verifier decodes a segment against the binding digest and the start tag, which
depend on the oracle. The object reads both from the segment's own header bytes (`rtBnd`, `rtStart`). On acceptance
the two readings agree (`rtSegOf_decode`, `rtStageOf_decode`).

### 1.2 The nine kinds and the column test's parse (item 3)

| Theorem or object | File | Meaning |
|---|---|---|
| `rtKind1`, `rtKind2` | Kinds | a `KindRun rtTr` from per-part records `RtKPart` (lists `cs`, `hseg`, `hsort`, `hR`, `hε`, `hnorel`, `hB`, `hcut`), on the single-step and on the wide parse; `np` is the number of parts, `off` the profile's offsets |
| `RtKPart.ofSlots`, `.ofMask`, `.ofOpA`, `.ofOpB`, `.ofSq` | Kinds | the per-part records of the code's sub-protocols: L21's `slotSubs`, L22's `maskCSubX`, L20's `opACSub` and `opBCSub` (with L28's `EvOW` arguments), L21's squeeze runs |
| `RtOpen.opA_rbr`, `RtOpen.opB_rbr`, `RtOpen.opA_eps`, `rtOpen_r13_epsB` | Kinds | the openings' halves are round-by-round sound; their errors are at most `2^-110` and, at R13's geometry, `2^-126` |
| `rtKsl`, `rtKM`, `rtKA`, `rtKB`, `rtKR0`, `rtKR1`, `rtKH0`, `rtKH1`, `rtKLU` | Kinds | the nine kinds from a kinds data `D : RtKData` that meets `RtKData.Valid` |
| **`rtK_forms`** | Kinds | slots `SqForm 7 (7·370)`, `M` `PowForm 3 106`, `opA` `PowForm 1 110`, `opB` `PowForm 1 126`, each define schedule `SqForm 80 (80·451)`, LogUp `SqForm eL (3·eL)` |
| **`rtK_chain`** | Kinds | every kind: `ℓ ≤ 2^21`, `np` = the number of parts |
| `rtKo`, `rtKo_mem` | Kinds | the nine kinds in L30-1's order: `opB`, `M`, `opA`, slots, relation draws, host draws, LogUp |
| `rtRCx_hw` | Kinds | a window at or after the header's end is after the wide parse's header (`hwA`, `hwB`) |
| `rtOps_win` | Kinds | each part's three openings have their windows at the profile's positions, in the part, in order |

`M`'s and the openings' windows are fixed by the profile. The slots' and the draws' windows are data of `D`, with the
condition that they lie in their part.

### 1.3 The endpoint's windows (item 6, first premise only)

| Theorem | File | Meaning |
|---|---|---|
| **`rtTr_winX`** | Win | on an output of the profile's shape, part `i`'s closing opening has both windows at steps' ends under the wide parse, at `off i + oX` and `off i + oBX`; the second lies on the transcript |
| **`rt_hwin`** | Win | the gate's `hwin` for a column test whose windows are the input endpoint opening's (part `0`) |
| `rt_hwin_hdr` | Win | those windows are after the run header |

### 1.4 The gate (item 7)

**`rt_productionReady_r13`** (Gate): `classifyU_productionReady_run_r13_token` at `tr := rtTr …`, the nine kinds of
§1.2 in the order `rtKo`, and `RCx := rtRC2 …`. Discharged: `tr`, `Ksl … KLU`, `hℓ`, `hnp`, the nine forms, `heL`,
`Ko`, `hKo`, `RCx`, `htrx`, `hℓx`, `hwA`, `hwB`. It holds for any run verifier `V` with a schedule `Rn`; at
`V := classifyRunV …` the schedule is `rtRunClassify` and the protocol object is `classifyProtocolUExec`.

### 1.5 L28's `εend` at run level

Question of the brief: is the block's endpoint-claims term a new term at run level? Answer for the COUNT: no, and
this is proved. Each part's closing opening is the third entry of that part's list in `rtKA` and `rtKB`
(`rtOps`). The forms `PowForm 1 110` and `PowForm 1 126` are proved for those lists (`rtK_forms`), and the gate's
conclusion is at `εsTarget` with no further term. What remains is deterministic and is NOT proved here: a false
endpoint claim is a doomed entry of the closing opening's `opA`. It belongs to `halive` and `hdblk`.

## 2. The numbers

| Figure | Value | Label |
|---|---|---|
| items of each parse | at most `2^21 = 2,097,152` | PROVED (from `RtProf.Valid.len`, a premise on the profile) |
| `M`'s steps | `2S + 69` operations; squeeze runs `1`, `2S + 2`, `64` | PROVED (L22's `mStps`, used at every part) |
| an opening's steps | `w + g + 1 + m` operations; squeeze runs `w`, `m` | PROVED (L22's `pcsStps`) |
| a block's single phase | `15 + shapeLen` operations, `3 + shapeSq` squeezes | PROVED (`rtBlock_holds`: 5 frame absorbs, 10 root operations, the slots) |
| a stage's single phase | frame `+ 7 + m + shapeLen` operations, `m + shapeSq` squeezes after the frame (`m` head draws) | PROVED (`rt_stagePre`) |
| slots' form | `7`, `7·370 = 2,590` | PROVED form; the bound on each slot is a condition on `D` |
| define draws' form | `80`, `80·451 = 36,080` | PROVED form; condition on `D` |
| `opA` error | at most `2^-110` | PROVED (`RtOpen.opA_eps`) for row length up to `2^16` and batching width up to `2^61` |
| `opB` error | at most `2^-126` | a condition of `RtOpen.Valid` (`hεB`); PROVED at R13's geometry `(16, 256, 24448)` (`rtOpen_r13_epsB`, L28's `opB_eps_r13u`) |
| LogUp | `eL ≤ 2^26` | condition on `D` (`heL`) |
| Shieldstral block: slot phase | 1,283 operations, 844 squeezes | L31's figure (derived there); not re-derived here |
| Shieldstral block: squeezes without its boundary opening | `10,255` | L31's figure |
| the run's length | about `4·10^5` operations, about 5 times under `2^21` | ESTIMATE (26 blocks of about 16,000 operations from L31's counts; the concrete profile is not built) |

## 3. What is left, each premise by name

### 3.1 Of the schedule `rtRunClassify` (to make `Rn` concrete)

| Premise | Says | Source |
|---|---|---|
| `hstart`, `hhdr` | the run header's operations: `st.transcript()` is `runOps` of them; on an accepted policy they have the profile's counts and fit | to write, from the statement's header absorbs |
| `I : RtInc` | stage IN-C: `hPm` (`M` is `maskField`), `pA`, `pH`, `pX` (`PcsOk` on acceptance, as `RtPcs`), `hgeo`, `hgt`, `hgeomL`, `hclose`, `hcnt` (claims' counts), and the counts the profile's for every header: `hpre`, `hpsq`, `hgA`, `hgH`, `hwA`, `hmA`, `hwH`, `hmH`, `hwX`, `hmX` | L10's openings; L29's `StageGeom` |
| `O : RtOutc` | the same for stage OUT-C | as above |
| `bp k : RtBlk` | block `k`: `hPm`, `pA`, `pH`, `hgt`, `hgeomL`, `hcnt` | `hcnt` from L31's `blockSlots_claims` / `hcnt_of_define`; the rest L28's premises in L28's form |
| `pX k`, `gX`, `hgeo`, `hgX` | block `k`'s boundary opening and segment geometry | L18's `d12aBlockProf` |
| `pend`, `hI`, `hbp`, `hO` | the pending claims' counts between parts | arithmetic on the above |
| `hv : pf.Valid` | header nonempty; every squeeze run in `1 … 2^61`; fewer than `2^64` squeezes; at most `2^21` operations | arithmetic on the concrete profile |
| `hs`, `hL`, `hL64` | the domain string's facts | as in L22 |

### 3.2 Of the kinds data `D` (`hD : D.Valid`)

`hK`; the slots `slCut`, `slDeg`, `slWin`; `M`'s `mK`, `mCut`, `mS`; the openings `opV` (`RtOpen.Valid`), `opW`
(widths the profile's); the squeeze runs `r0`, `r1`, `h0`, `h1`, `lu` (`RtSqOk`); `heL`. To discharge: take each
block's lists from L21 / L23's block schedule and L28's opening data, shifted by the part's offset; the stages'
lists from L15's stage model. The stages have no `SlotX` / `SqX` list in the library yet.

### 3.3 Of the gate, unchanged from L30 §5

- `O` (`ClassifyOpen`), `hzk`.
- Merkle work: `tag`, `C`, `coreOf`, `Vx`, `nx`, `hVx`, `hnx`, `rx`, `nrx`, `hrx`, `hnrx` (item 4, not started).
- Cover: `halive`, `hdin`, `hdblk`, `hdout` (item 5, not started).
- Endpoint: `T`, `hTenc`, `hTaA`, `hTaB`, `Ux`, `Xx`, `hUc`, `hXc`, `pr`, `hp1`, `hp2`, `hF`, `hw0`, `hβLR`, `hTe`,
  `hTQ`, `hβJ`, `mk`, `ops`, `hE`, `hops`, `hcan`, `hread`, `hBal`, `hdzero`. `hwin` is `rt_hwin` when the test's
  windows are the input endpoint opening's.

### 3.4 What the next lane needs first

1. The concrete profile for Shieldstral T128 (28 `RtPart`s) and `hv`.
2. The block's `D` (slots, draws, `M`, openings) from L21, L23, L28, L31, and the stages' from L15.
3. A congruence lemma for the parse (finding L34-1), before L28's per-block opening results can be used in `halive`.
4. For the slots' link in `halive` and `hdblk`: L31's `…N` chain only (finding L31-1). No file here cites a block
   statement that carries L16's `SlotEval`.

## 4. Findings

No statement or target is weakened.

- **L34-1 (Medium; the cover lane, L28, L31).** `opBCSub` takes the parse `W` as an argument. L28's and L31's
  per-block results are stated at the block's own widths (`OProf.W`). The run's kinds are at `rtW`. The two functions
  agree at the counters inside the block's window but are not equal. A lemma "the sub-protocol and its events depend
  on `W` only at the counters of its window" is needed. `rtTr_part` gives those counters and widths.
- **L34-2 (Low; L30's gate and `cover3_of_runParts_ord`).** `hdin` and `hdblk` ask for the doomed sub-protocol in the
  part itself (`cs 0`, `cs (k + 1)`). In the code a part's OUTPUT claims on its outgoing boundary are opened by the
  NEXT part's closing opening. So a false output claim is a doomed entry in `cs 1` / `cs (k + 2)`. The premises can
  still be met through the part's own first-level sub-protocols (a false relation family at its draws) [reasoning],
  but L30 §5.3's route "a false endpoint claim is a doom of a boundary opening's `opA`" lands in the next part. The
  cover's proof uses any part (`kindEv_of_dm_ord`), so restating the three premises with "some part `i < L + 2`"
  costs nothing.
- **L34-3 (Low; L29, L31).** The stages' counts must be the profile's for EVERY header (`RtInc.hpre` … `hmX`), and
  the stages' claim counts (`hcnt`) have no theorem yet. For blocks L31's `hcnt_of_define` gives `hcnt`.
- **L34-4 (Low; coordinator).** A check of the whole run's operation list against a Rust receipt needs new test-only
  Rust (an export of the run's operation trace, or of the block segments' bytes). L18's corpus has per-segment
  transcripts only; L29's stage segments are outside the repository. Not written, as instructed.
- **L34-5 (Info; L22, L17).** `blockVerify_ok` does not expose the IO claims, and `decodeSegment_spec` does not give
  the closed opening's shape. Both re-derived here (`rt_blockVerify_io`, `rt_decodeSegment_in`).
- **L34-6 (Info; L29).** `decodeStage` had no specification. `rt_decodeStage_spec` gives the header bytes, the core's
  shape and the closes' group counts.
- **L34-7 (Info).** The verifier decodes segments against oracle-dependent state. The transcript object reads the
  same values from the segment's bytes instead (§1.1).

## 5. Checks

`results/zk60_lean_l34_20261109/check_l34.sh`, one guarded cpu job (`lean-l34-check`), exit 0, 71 s, peak 9.65 GiB.
All figures MEASURED; logs in the evidence directory (`check.log`, `full.log`, `axioms_flat.log`).

| Check | Result |
|---|---|
| each of the eight modules built alone | 8 of 8 green, 0 warnings |
| full `lake build` | green, 3,613 jobs, 0 warnings, 0 errors |
| axiom audit of every declaration of the eight files | 213 audited of 213 generated (116 theorems, 81 definitions, 16 structures); 45 on no axiom; the rest on at most `propext`, `Classical.choice`, `Quot.sound`; `sorryAx` 0; `ofReduceBool` 0; other axioms 0 |
| source scan for the forbidden words | none |
| root imports | all eight imported; no import line removed |
| existing Lean files against perf at `b938ae87` | `Statements.lean` unchanged; 0 files modified, deleted or renamed |
| name clashes (`l34_nameclash.py`, 44 worktrees, 4,350 files read) | 0 |
| regressions | L6Check 1,206, L5Check 5,553, L11Check 404, fixture L1 101,956 checks; 0 failed in each |

Theorems by file: Base 18, Sched 35, Verify 9, Kinds 15, Parts 11, Stages 19, Gate 1, Win 8. Lines: 3,107.

Not checked: the transcript object against a real receipt's operation list (finding L34-4). The link to the code is
therefore by the proofs of §1.1 over L18's and L29's Lean models of the verifier, which earlier lanes checked
against corpora per segment.

Build note. The gate file's first form (the run's data as section variables behind local notations) did not build:
Lean reported an unknown identifier and a recursion-depth limit. The file was rewritten with ordinary theorem
binders and a term proof, in the shape of L30's own gate. No option was raised.
