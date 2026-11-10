# D63 lane L30: the gate at `classifyProtocolU` through the run's chain; the column test on the run's transcript; finding L26-3's code fact (2026-11-09)

Lean lane L30 (Claude), on its own worktree, at perf `998be85f` (lanes L9 to L29 merged; L28 and L29 were merged in
while the lane ran). Lean 4.34.1, Mathlib v4.34.1, no new dependency. Six new library files under
`formal/ZK60Formal/`, imported by the library root: `BindingUCode.lean`, `RunChainUOrd.lean`, `RunChainUStab.lean`,
`RunChainUGate.lean`, `RunChainUExec.lean`, `RunChainUToken.lean`. No Rust and no production source changed.
`Statements.lean` and every existing Lean file are unchanged (the root's import lines apart). Nothing is switched:
L18's `classifyProtocol`, L29's `classifyProtocolExec` and L26's `classifyProtocolU` stand side by side, and Victor
has not ruled on finding L24-1. Evidence: `results/zk60_lean_l30_20261109/`.

Labels: **PROVED** (a Lean theorem, axioms at most `propext`, `Classical.choice`, `Quot.sound`), **HYPOTHESIS** (a
named premise of a proved theorem), **ESTIMATE** (arithmetic or reasoning not proved in Lean).

## 1. In plain words, for Victor

**Where things stood.** Two lanes were merged today and each named the other as its missing half.
- L26 built the classify run's protocol object with the corrected meaning of "the input commitment opens"
  (`classifyProtocolU`, the fix proposed for finding L24-1, awaiting your ruling), and a production gate for it.
- L27 put the run's security count on the run's ONE transcript, kind of check by kind of check, and wrote two gates.
  Those sit at the OLD protocol object, where one premise is false (L24-1), so they prove nothing about a real run.

**What this lane did.**
1. **The gate at the corrected object, through the run's transcript.** PROVED
   (`classifyU_productionReady_run_r13`, `_w16r2`): your two approved statements at your targets for the classify
   run at `classifyProtocolU`, from L27's nine kinds of checks, L26's two extra checks on the input commitment
   (eleven kinds), the run's hash-tree extraction failure, and the per-part covers.
2. **L26's two extra checks now sit on the run's transcript with no stability assumption.** L26 had to assume that
   the data its checks read does not change when the prover's hash log grows (`StabU`). PROVED (`stabU_cA`,
   `stabU_cB`): this holds for every extraction that reads the log by cutting it at a commitment root's first
   appearance, which is how every extraction in the code reads it.
3. **L26's open code fact (finding L26-3) is true, and proved.** The check on the input commitment draws its random
   weights in the larger field `F_p²`, while "the commitment opens" speaks of the base field. L26 reduced the gap to
   one fact about the code and left it open. PROVED (`encLin_base_fact`, `closeIn_enc_iff`): for the code the system
   uses, a matrix of base-field columns is close to the code over `F_p²` exactly when it is close to the base-field
   code. It holds at both registered codes (`closeIn_r13_iff`, `closeIn_w16r2_iff`).
4. **The object the final assembly needs exists.** L29 made the two stage verifiers executable Lean, on the OLD
   object. The final assembly needs both changes at once. That object is one definition (`classifyProtocolUExec`),
   and this lane's gates hold at it as they are (`classifyUExec_productionReady_run_r13`, `_w16r2`).
5. **The gate at the app's real input commitment** (`classifyU_productionReady_run_r13_token`): at R13's registered
   token commitment the geometry premises become facts, and the base-field step of item 3 is used inside the gate.

**One thing you should know (finding L30-1, Medium).** L27's cover theorem fits L26's gate as a term; I compiled
that (`cover3_fits_h3`). But one of its premises cannot be supplied. It asks that on EVERY accepted run, every check
of every kind ended in a good state. Acceptance does not give that. Some checks end well only if an earlier check was
sound: the first half of a commitment opening ends well only if its second half did not start from a false claim;
the sumchecks end well only if the openings' values are true; and so on. A prover who passes a column test by luck
(chance below `2^-172` at R13, but not zero) is accepted with a first half that did not end well. So L27's premise is
false for that prover, and L27's cover (and its two gates) cannot be used as written. This is a fault in the form of
a premise, not in the protocol and not in the count. The per-block lanes (L20 to L23, L28) already use the right
form. This lane states the run's cover in that form (`cover3_of_runParts_ord`): the kinds are taken IN ORDER, and
each kind must end well only when no earlier kind started from a false claim. The gates here use it.

**A number that changed (finding L30-2, Low).** L24 and L26 priced R13's ordinary openings with an assumed figure
(`2^-105` for the column round, at a smaller radius). L28 has since PROVED the R13 figures at the same radius the
input commitment uses: `2^-110` and `2^-126`. With the proved figures the R13 total is **55,525,211 units of the
67,108,864 your target allows (83 %)**, where L26's doc had 57,589,594. W16R2 is unchanged: **31,480,689**, inside
half the target.

**No decision is needed from this lane.** Your two open rulings are unchanged: L24-1 (adopt the opening at the
unique-decoding radius: this lane's gates are all at that object, beside the old one) and L19-2 (the zero-knowledge
cap).

**What is NOT proved.** The gates are theorems with named premises (§5). The largest: the run's transcript as a Lean
object with the nine kinds' lists on it (now possible, since L29 made the stage verifiers executable); the per-part
covers on it; the links between the input commitment's check and the run's extractor; and everything L18 left in
`ClassifyOpen` (the weights' validity, completeness, the honest prover's refusals, zero knowledge).

## 2. What is proved

PROVED in every row (the audit is in §7).

### 2.1 `BindingUCode.lean`: finding L26-3's code fact

`F ⊆ K` is any field extension (in use: Goldilocks and `F_p²`).

| Theorem / definition | Statement |
|---|---|
| `exists_base_proj` | an `F`-linear map `π : K → F` that is the identity on `F` |
| `RowFormExt`, `coefForm_ext`, **`lagForm_ext`** | the row form over `K` is the base one with scalars extended; true of W16R3's coefficient rows and of the interpolant rows (W16R2, R13) at the embedded root of unity |
| `coefPoly_map_base`, `encPoly_map_base`, **`encLin_map_base`** | the `K`-encoder of an embedded message is the embedded base codeword |
| `encLin_proj_single`, **`encLin_proj`** | `π`, column by column, sends the `K`-codeword of a message to the base codeword of the projected message |
| **`encLin_base_fact`** | THE FACT (L26's `hbc`): a `K`-codeword with base-field values on a set of columns agrees there with a base codeword. For EVERY set (L26 asked it for sets of all but `e` columns) |
| `closeIn_enc_base`, `closeIn_enc_ext`, **`closeIn_enc_iff`** | the embedded matrix is close inside `X` over `K` if and only if the base matrix is close inside `X` |
| `closeIn_base_encLin` | L26's `closeIn_base` with its premise discharged |
| `rowFormK14`, `rowFormK14_ext_w16r2`, `rowFormK14_ext_r13`, **`closeIn_w16r2_iff`**, **`closeIn_r13_iff`** | the two registered codes |

### 2.2 `RunChainUOrd.lean`: the run's cover, the kinds alive in order

| Theorem / definition | Statement |
|---|---|
| `KindRun.Dm`, `KindRun.Al` | a kind has a sub-protocol that entered its window doomed; all its sub-protocols are alive at the end |
| **`AliveOrd`**, `aliveOrd_of_all` | for a list of kinds in order: each is alive at the end PROVIDED no earlier kind has a doomed entrant; L27's flat premise is the special case |
| `aliveOrd_nil`, **`aliveOrd_cons`** | the order built one kind at a time: the first kind alive, and the rest alive in order if the first has no doomed entrant |
| **`exists_dm_al`**, **`kindEv_of_dm_ord`** | if some kind has a doomed entrant, the first such kind is alive at the end, so some kind's event (L24's `FirstKind.Ev`) holds |
| **`cover3_of_runParts_ord`** | L27's `cover3_of_runParts` with `halive` in the ordered form; the same conclusion, the premise `h3` of L26's gate |

### 2.3 `RunChainUStab.lean`: the column test on the run's transcript

| Theorem / definition | Statement |
|---|---|
| `RunChain.toChainU`, `RunChain.toChainU_chain` | L27's parse of the run's transcript as L26's chain data |
| `CutReads`, `cutReads_of_cut`, `CutReads.comp` | a reader of the prover's log that reads it only through cuts at the roots the header absorbs; "cut at the root shown at position `i`, then read" is one |
| `agreeOn_xACSub`, `agreeOn_xBCSub` | the test's two halves at two logs agree when the extracted matrix and the openable set agree on the header |
| **`stabU_cA`**, **`stabU_cB`** | L26's `StabU` premises, PROVED for cut readers (L27's `cutEq_esc`) |
| **`xRunA`**, **`xRunB`**, `xRunA_ℓ`, `xRunB_ℓ`, `xRunA_lin`, `xRunB_lin` | L26's `xKindA`, `xKindB` on a parse of the run's transcript, with no stability premise; their chain bound and linear parts |
| **`xRun_cover`** | the test's chain event on the run's transcript `tr` lies in one of the two kinds |
| **`xB_subSt_of_opB`** | the test's second half is alive at the end when the endpoint opening's own second half (L20's `opB`) is, and every sampled column is in the openable set |
| **`xlink_of_read`** | the test's chain event from its pieces, with the BASE-field matrix not close (finding L26-3's step is `closeIn_enc_base`) |

### 2.4 `RunChainUGate.lean`: the gates

| Theorem / definition | Statement |
|---|---|
| `cover3_fits_h3` | L27's `cover3_of_runParts` is a proof of L26's `h3`, term for term (its `halive` is the flat one: L30-1) |
| **`classifyU_productionReady_runChain`** | the gate, generic: any kinds on the run's transcript with constants, further kinds, an extra event, the kinds alive in order, the per-part dooms, L26's endpoint premises, constants `≤ 2^26` |
| `eleven_bud_w16r2`, `eleven_bud_r13`, `eleven_totals`, `nine_lin_r13u` | the numbers (§3) |
| **`classifyU_productionReady_run_w16r2`**, **`classifyU_productionReady_run_r13`** | the gate at W16R2 and at R13: nine kinds in their forms, the test's two kinds, the run's extraction failure, the ordered cover, the endpoint's links |

### 2.5 `RunChainUExec.lean`: the instance with both changes

| Theorem / definition | Statement |
|---|---|
| **`classifyProtocolUExec`** | `classifyProtocolU` at L29's run verifier `classifyRunV …` |
| `classifyProtocolUExec_verify`, `_verify_iff`, `_prove`, `_opensIn` | the same verifier and honest prover as `classifyProtocolExec`; the input opening is `OpensU` |
| **`classifyUExec_productionReady_run_w16r2`**, **`classifyUExec_productionReady_run_r13`** | the two gates at that instance |

### 2.6 `RunChainUToken.lean`: the gates at the registered token commitments

| Theorem | Statement |
|---|---|
| **`classifyU_productionReady_run_w16r2_token`**, **`classifyU_productionReady_run_r13_token`** | the gates at `w16r2TokenCommit` (radius `8052`) and `R13.r13TokenCommit` (radius `24,448`): `he`, `hN20`, `hplane` are facts; `hlink` splits into `hwin`, `hread`, `hBal` |

`RunChainUExec.lean` and `RunChainUToken.lean` are generated from `RunChainUGate.lean`'s statements by
`l30_mk_exec.py` and `l30_mk_token.py`, so the three files cannot drift apart. The check compares them with their
generators' output.

## 3. The numbers

Units: `u126 q c = (q + 1)·c/2^126`; target `εsTarget q = u126 q 2^26`. PROVED (`eleven_bud_*`, `eleven_totals`).

| | W16R2 | R13 (the app) |
|---|---|---|
| slots | `5 + 924` | `7 + 7·370` |
| `M` | `3·2^20` | `3·2^20` |
| `opA`, `opB` (the ordinary openings) | `2^15`, `2^13` | `2^16`, `1` (L28's proved `2^-110`, `2^-126`) |
| four define schedules, each | `80 + 80·351` | `80 + 80·451` |
| LogUp | `26,370,000` | `50,331,700` |
| the column test's two kinds | `2^15`, `2^13` | `2^16`, `1` |
| collision terms, eleven kinds | `11 · 2^17` | `11 · 2^17` |
| the run's Merkle extraction failure | `2^16 + 2^18` | `2^16 + 2^18` |
| **total** | **`31,480,689 ≤ 2^25`** (94 % of the half target) | **`55,525,211 ≤ 2^26`** (83 %) |

L26's doc gave `57,589,594` for R13, with `opA` at `2^15` and `opB` at `2^21` (L24's δ/3 pricing). The difference is
`2,064,383`.

## 4. The instance with both changes, and how the lanes combine

`classifyProtocolUExec R Lq L preA preB start inc incG blk outc outcG P Cin h64 hr base e` is by definition
`classifyProtocolU S R Lq (classifyRunV L preA preB start inc incG blk outc outcG) P Cin h64 hr base e`.
`classifyProtocolU` is stated for any run verifier `V`, and L29's `classifyProtocolExec` is L18's instance at
`V := classifyRunV …`. So the instance with both changes is an instantiation, and no proof is transferred.

What carries to it unchanged:
- **This lane**: every theorem (all are stated for any `V`). `classifyUExec_productionReady_run_*` are the gates
  written out at it; the token gates are stated for any `V`, so they hold at it too.
- **L26**: all of it. `Binding` (`classifyU_binding_r13`, `_w16r2`), `Complete` and `ZeroKnowledge` (transferred
  from L18's instance at the same `V`, which is `classifyProtocolExec`), O11d, the gate
  `classifyU_productionReady_ep_target`.
- **L27**: the kinds' machinery (`KindRun`, `toFirstKind`, `cutEq_esc`, the constructors' facts), the extraction
  failure (`hEx_r13`, `hEx_w16r2`), the block's case analysis (`block_doom_r13`, `block_doom_w16`). They do not
  mention the protocol. NOT its two gates and not `cover3_of_runParts` as a route (L30-1); R13's `nine_lin_r13`
  asks figures L28's openings do not meet (L30-2).
- **L28**: all of it. It speaks of one block's verifier, not of the run's protocol object.
- **L29**: `classifyProtocolExec_verify_iff` unfolds the acceptance of `classifyProtocolUExec` too (the verifier is
  the same term, `classifyProtocolUExec_verify`). `classify_parts_exec` gives `ClassifyOpen`'s O8 at
  `V := classifyRunV …`, which is the `ClassifyOpen` the gates here take.

## 5. The remaining premises, exactly

What `ProductionReady` for the classify run at R13 still rests on: the premises of
`classifyU_productionReady_run_r13_token` (file `RunChainUToken.lean`), read at `V := classifyRunV …`. Each line
gives the premise, what it says, and who should discharge it. "Next lane" is the lane that writes the run's
transcript.

### 5.1 The run's transcript and the kinds on it (next lane; L29 makes it possible)

| Premise | Statement | Source |
|---|---|---|
| `tr` | the run's ONE transcript, a function of the oracle and of (statement, receipt) | to write: the run verifier's list of transcript operations (run header, stage IN-C, each block's D12a frame and core, the boundary openings, stage OUT-C), from L29's `classifyProtocolExec_verify_iff`, `incVerify_ok_iff`, `outcVerify_ok_iff`; then its trace |
| `Ksl … KLU : KindRun tr` | each of the nine kinds part by part: its parse `RC` of `tr` (`htr`), offsets, the lists `cs i` at absolute windows, `hseg`, `hsort`, `hR`, `hε`, `hnorel`, `hB`, `hcut` | L27 §2.3 gives each constructor's facts; L22's `cChain_stps` and L21's `cChain_trace` give `htr`; the lists themselves are to write, from the profile's counts |
| `hℓ`, `hnp` | each parse has at most `2^21` items; `np = L + 2` | counts on `tr` (about `2^16` items [ESTIMATE, L18]) |
| `hsl`, `hM`, `hA`, `hB`, `hR₀` … `hH₁`, `hLU`, `heL` | the kinds' forms: slots `SqForm 7 (7·370)`, `M` `PowForm 3 106`, `opA` `PowForm 1 110`, `opB` `PowForm 1 126`, define `SqForm 80 (80·451)`, LogUp `SqForm e (3e)`, `e ≤ 2^26` | L28's `opA_eps_r13`, `opB_eps_r13u`, `maskEps_le`; L21 / L23's degree and draw counts; L17's R13 counts |
| `RCx`, `htrx`, `hℓx`, `hwA`, `hwB` | the column test's parse of `tr`; its two windows after the header | as the openings' parse (wide runs) |
| the header's squeeze count (inside the above) | every part's operation and squeeze counts are the profile's, so the windows are fixed positions | L27-2, L28-1 (`run_acc` per block); for the stages L29's `StageGeom`. To prove with `tr` |

### 5.2 The Merkle extraction failure (next lane)

| Premise | Statement | Source |
|---|---|---|
| `tag`, `C`, `coreOf` | the blocks' Merkle work: block `k`'s decoded segment | L22's `blockV` at the D12a profile |
| `Vx`, `nx ≤ 3,800,000`, `hVx` | the boundary and stage openings' column checks as an oracle computation. It must include the input endpoint opening's checks, for `hread` and `hBal` below | to write |
| `rx`, `nrx ≤ 2^99`, `hrx` | their roots | to write |

### 5.3 The cover of stage IN-C, the blocks and stage OUT-C

| Premise | Statement | Source |
|---|---|---|
| `Ko`, `hKo` | the nine kinds in the order of dependence. Proposed: `opB`, `M`, `opA`, slots, relation draws (2), helper draws (2), LogUp | this doc |
| `halive` | accepted, no extraction failure ⇒ the kinds of `Ko` alive in order (`AliveOrd`) | `opB`: L28's `pcs_subSt_of_acc` (blocks; `pcsOk_groupsAccept` holds for any parameters, so also for the stage and boundary openings); `M`: L22's `mask_subSt_of_ok`; `opA`: L20's `opening_split`, given no `opB` doom; slots: L28's `hsem_geo` (good openings make the claimed values true) and L16's final check, given no `opB`, `M`, `opA` doom; draws and LogUp: L21's `defWin_event`, `lkWin_event` under the claimed sums. Each is seen on `tr` through L27's `allSt_of_prefix` |
| `hdin` | stage IN-C's conclusion fails ⇒ a sub-protocol of part `0` entered doomed | L12's `inc_stage_sound` pieces on L15's stage model; L29's `incSlots_model` says IN-C's slot phase is that model |
| `hdblk` | block `k`'s `BlockOn` on `B_k`, `B_{k+1}` fails ⇒ a sub-protocol of part `k + 1` entered doomed | L27's `block_doom_r13`; its four links: L28's `hsem_geo` and `hexec_geo` (the openings and `M`), L16's slots, L23's `hcoverR`, `hcoverH`, `hsplit`; and the boundary planes (below) |
| `hdout` | stage OUT-C's conclusion fails ⇒ a sub-protocol of part `L + 1` entered doomed | L15's `outc_stage_sound` pieces; L29's `outcSlots_model` |

**L28's `εend`** (the block's input and output claims, which the block verifier does not open). At the run level
this is not a new term of the count [ESTIMATE, reasoning]: the boundary openings' `opA` and `opB` are further
sub-protocols of the two opening kinds, and a kind costs the same whatever the number of its sub-protocols. What is
needed is deterministic: the boundary openings' `hexec` and `hsem` (L28's `pcsOk_groupsAccept` at their parameters),
and the identification of `B_k`, `B_{k+1}` with block `k`'s extracted planes (L12's `RunFrame`). They enter `hdblk`
(a false endpoint claim is a doom of a boundary opening's `opA`) and `halive`.

### 5.4 The input endpoint (L26's links)

| Premise | Statement | Source |
|---|---|---|
| `mk : Cin.SaltMk` | the opening-data type holds the decoded rows, pads, salts and paths | the instance's `Salt` type; the honest half is L18's `HonestIn.withPaths` |
| `ops`, `hops`, `hcan` | the extractor's openings: each verifies against the statement's root; canonical columns | to write, on the Merkle extraction (`SoundExtract.lean`) extended to return salt and path (L30-5) |
| `hE` | the run's extractor reads the endpoint by decoding (`decodeIn`) and builds the opening data with `mk` | the definition of the run's extractor `E` |
| `T`, `hTenc`, `hTe`, `hTQ`, `hβJ`, `pr`, `hp1`, `hp2`, `hF`, `hw0`, `hβLR` | the column test's parameters: the registered code over `F_p²`, `e = 24,448`, `Q = 256`, exact indices, the `(λ, ρ)` bias | L10's opening parameters for the endpoint (`pcsFieldR13`); L28's `lrCode_sqDs` |
| `Ux`, `Xx`, `hUc`, `hXc` | the test's matrix and openable set, cut readers | `cutReads_of_cut` at the input root's position in the run header |
| `hwin` | the test's two windows are at steps' ends on `tr` | with `tr` (as L28's `run_acc`) |
| `hread` | at its window the test's openable set and matrix are the run extractor's (`exX`, `exU` of `ops`, embedded) | the run header absorbs the statement's input root, so the cut is the same |
| `hBal` | the test's second half is alive at the end | **`xB_subSt_of_opB`** reduces it to: the endpoint opening's `opB` alive (L28's `pcs_subSt_of_acc`) and every sampled column in the openable set (outside the extraction failure, an accepted opened column is the extracted one) |
| `hdzero` | the decoded endpoint plane vanishes off the token positions, or a sub-protocol of the run's kinds entered doomed (L26-4) | stage IN-C's SIC_IO zero-check and the endpoint opening's claims, with L26's `decodeIn_eq` (the decoding is unique) |

### 5.5 The frame and `ClassifyOpen` (L18's O1 to O10 and O12), unchanged

| Premise or field | Statement | Source |
|---|---|---|
| `hr`, `hon`, `U`, `hbij`, `site`, `kOf`, `δOf`, `E` | the frame of L18's assembly: the opened columns fit the oracle's input bound; the honest opening data; `F_p²` as pairs (`U² = 7`); the refusal sites and their counts; the run's extractor | L18 (`AssembleClassify.lean`); `E` is defined with the transcript (its endpoint part is `hE`) |
| O1 `shape`, O3 `inPub`, O4 `outPub` | the registered shape and the stages' public data are valid | L9, L15 (`shield_in_valid`, `shield_outc_valid`) |
| O2 `weights` | every block's public weights are in their classes | **the weights' validity**: a finite check on the real weights, which are not in the repository (D62) |
| O5 `blocks`, O6 `commit`, O7 `policy` | the block count; the input commitment's geometry (by definition at `r13TokenCommit`); the verifier's pre-header policy accepts the registered header | definitions; L18 |
| O8 `parts` | every part's completeness contract | L29's `classify_parts_exec` from `IncOK`, `D12aBlockOK`, `OutcOK`: the slots' arithmetic and the completeness of L10's executable `M` test and openings (open) |
| O9 `refuse`, O10 `counts` | the honest prover refuses only at a listed site; the sites' counts | L25, L29 (open items in L29 §6) |
| O11 | four extraction bounds at the OLD instance | not used by the gates here; they hold with the trivial bound `1` |
| O12 `zk`, `hzk` | zero knowledge of the run as one receipt, within `εzkTarget` | L19's honest-prover hypotheses (open); **Victor's ruling L19-2** (the cap `R ≤ 2^112`) |

### 5.6 Rulings

- **L24-1 (Victor)**: adopt the opening at the unique-decoding radius. Every gate here is at that instance. Until the
  ruling, nothing is switched.
- **L19-2 (Victor)**: the zero-knowledge cap. It enters only through `O.zk` and `hzk`.

### 5.7 What the next lane must write, in order

1. The run's list of transcript operations as a function of (statement, receipt), and `tr` as its trace. Prove that
   on acceptance the verifier's transcript states are those of its prefixes.
2. The two parses of `tr` (single steps; wide runs) as `RunChain`s, with `htr`, `StepsOK`, `StepCont`
   (`stepsB_cont`), the header, `ℓ ≤ 2^21`.
3. The part offsets and, for each of the nine kinds, the list of its sub-protocols in each part (`cs i`), with the
   profile's counts. Then each `KindRun`'s fields from L27 §2.3 and its form from the figures above.
4. The Merkle extra work `Vx` with the endpoint opening in it; the extractor's openings `ops`.
5. `halive` in the order of §5.3, `hdin`, `hdblk`, `hdout`.
6. The endpoint: `hwin`, `hread`, `hBal` (through `xB_subSt_of_opB`), `hdzero`.
7. Apply `classifyU_productionReady_run_r13_token` at `V := classifyRunV …`.

## 6. Findings

No statement or target is weakened. `Statements.lean`, L18's, L26's, L27's, L28's and L29's files are unchanged.

**L30-1 (Medium; L27's `cover3_of_runParts`, `jointCover_of_runParts` and its two gates): the premise `halive` asks
more than acceptance gives.** It asks, on every accepted run outside the extraction failure, that every
sub-protocol of every kind is alive at the end. For an opening's first half (`opA`), "alive" after its round is
`Alive1`: the matrix is close and the batched claims hold, or the `ρ`-combination is close. The verifier sees
neither; it sees the sampled columns. L20's `opening_split` gives `opA` alive only when `opB` did not enter doomed.
The slots' final claims are true only when the openings' claimed values are (L22's `hsem`); the define draws and
LogUp only under the claimed sums. So for a prover whose column test passes by luck the premise is false, and the
theorems that take it prove nothing about that prover [reasoning; the per-block lanes L20 to L23 and L28 already use
the conditional form, e.g. `hexec`: good or the chain event]. Fix, here: `AliveOrd` and `cover3_of_runParts_ord`.
`cover3_of_runParts` itself fits `h3` as a term (`cover3_fits_h3`). L27's files are not changed.

**L30-2 (Low; L27's R13 forms): `nine_lin_r13` asks `opA` at `2^-111` and `opB` at `2^-105`.** These are L24's
figures for the δ/3 radius, an assumption. L28 proved R13's openings at the unique-decoding radius `24,448`:
`opA ≤ 2^-110` (which does not give `2^-111`) and `opB ≤ 2^-126`. An `opA` kind built from L28's pieces does not meet
L27's form. Here: `nine_lin_r13u` and `eleven_bud_r13` at L28's figures; total `55,525,211`.

**L30-3 (Info; finding L26-3 closed): the code fact is true as stated, and more.** It holds for every set of
columns, not only for sets of all but `e`, and for any field extension. It needs the row form over `K` to be the
base one with scalars extended (`RowFormExt`); proved for the interpolant rows at the embedded root of unity and for
coefficient rows. The proof is the coordinator's sketch: the coordinate-wise base-field projection is `F`-linear and
sends `K`-codewords to base codewords. The gate takes the identification of the test's encoder with that code as
`hTenc`; L10's column evaluator is specified against the same row form (`ColEncSpec`, at the root `(rootFp 14).toGF`,
which is `rootGF 14` by `rootFp_toGF`).

**L30-4 (Low; shape of a premise): `hdzero` is asked as a doom of the run's kinds.** L26's `hzero` asks "some kind's
event". The gates here ask instead that a sub-protocol of one of the run's kinds entered doomed, and get the event
from the ordered cover (`kindEv_of_dm_ord`). This is the form the stage lane can supply (it is the form of `hdin`).
L26's general form is still available through L26's own gate, with `cover3_of_runParts_ord` as its `h3`.

**L30-5 (Low; for the next lane): the extractor's openings need salt and path.** `OpensU` needs, for each column that
opens, a full Merkle opening. `SoundExtract.lean`'s `extractCol` returns the column only. `ops` (with `hops`, `hcan`)
is therefore a premise here; the next lane needs an extraction that also returns the salt and the path, and `Vx`
must contain the endpoint opening's checks so that "an accepted opened column is the extracted one" applies to it.

**L30-6 (Info): the instance with both changes is an instantiation** (§4). `classifyProtocolUExec` is a definition
beside the three existing instances; nothing is switched.

**L30-7 (Info; method): two files are generated.** `RunChainUExec.lean` and `RunChainUToken.lean` restate
`RunChainUGate.lean`'s long statements with one replacement each. They are written by scripts and compared with the
scripts' output in the check.

## 7. Checks

One guarded job (`results/zk60_lean_l30_20261109/check_l30.sh`, run through `run_guarded.py` and `iter.sh`, the zk60
resource guard, class cpu, need 14 GiB, cap 24 GiB; iteration 3, 2026-11-09; the guard's record: run `1e43a28f9d17`,
waited 0 s, exit 0, 61 s, peak 3.68 GiB). Its log is `check.log`; the iteration is `iter3.log`. The script exits 0
only when every line below holds.

| Check | Result |
|---|---|
| the two generated files against their generators' output | identical (`RunChainUExec.lean`, `RunChainUToken.lean`) |
| the six L30 modules, one at a time (`prebuild_*.log`) | each `rc 0`, no warning |
| full `lake build` of the library on the lane's tree, perf `998be85f` with L28 and L29 (`full.log`) | green, **3597 jobs, 0 warnings, 0 errors, 0 `sorry`** |
| axiom audit (`gen_axioms.py`, `axioms_l30.lean`, `axioms.log`): every `theorem`, `def`, `abbrev`, `structure` of the six files | **63 declarations audited of 63 generated: 53 theorems, 10 definitions** |
| their axioms | 57 on `[propext, Classical.choice, Quot.sound]`, 6 on `[propext]`; `sorryAx` 0, `Lean.ofReduceBool` 0, any other axiom 0 |
| source scan of the six files for the forbidden words | none |
| the library root imports the six files | all six |
| `Statements.lean`, L18's `ProtocolClassify.lean`, L26's five files, L27's six files against perf `998be85f` | unchanged |
| existing files under `formal/` modified, deleted or renamed (the root's added import lines apart) | 0; lines removed from the root's imports: 0 |
| regression: `L6Check` on the committed L6 corpus | 1,206 checks, 0 failed |
| regression: `L5Check` on the committed L5 corpus | 5,553 checks, 0 failed |
| regression: `L11Check` on L11's committed W16R2 rung corpus | 404 checks, 0 failed |
| regression: the fixture L1 check | 101,956 checks, 0 failed |
| declaration names against every other Lean file of every worktree (`l30_nameclash.py`, `l30_nameclash.log`; not part of `check_l30.sh`) | 63 declarations against 3,087 files in 39 worktrees: 0 clashes |

By file: `BindingUCode.lean` 17 theorems (272 lines), `RunChainUOrd.lean` 6 (185), `RunChainUStab.lean` 14 (325),
`RunChainUGate.lean` 8 (493), `RunChainUExec.lean` 6 (293), `RunChainUToken.lean` 2 (268); 1,836 lines in all.

The iterations.
- `iter1.log` (waited 71 s, 26 s): `BindingUCode` green at the first build. `RunChainUOrd`: one error (a bound
  variable whose type Lean could not infer), so `RunChainUGate` was not reached. `RunChainUStab`: green with two
  "not explicitly referenced" warnings.
- `iter2.log` (waited 3,861 s behind the coordinator's L29 merged-tree check, 20 s): all six modules green, no
  warning. The files changed while the job waited (the plan is read when the guard admits it): `aliveOrd_cons`,
  `xB_subSt_of_opB`, `hdzero` in the generic gate, and the token file were added in that time and built in this run.
- `iter3.log`: the check above.

**Not checked here.**
- The merged tree after later lanes: the coordinator's check.
- `ExecBlockCheck` and `CheckR13Block`: not in this lane's script (no L30 file is imported by them).
- The reasoning marked ESTIMATE: that L27's `halive` fails for a lucky prover (L30-1; the Lean content is the
  ordered cover, which does not depend on that reasoning), and that L28's `εend` is absorbed by the opening kinds
  (§5.3).
- Nothing was run on the GPU or timed.
