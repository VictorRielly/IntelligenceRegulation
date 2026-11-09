# D63 lane L27: the classify run's chain: the kinds part by part, the covers, the extraction failure (2026-11-07)

Lean lane L27 (Claude), on its own worktree, fast-forwarded to perf at `2ba55340` (lanes L9 to L24 merged), with lane
L22's branch (`c29adbf5`, the openings' links) merged in as the coordinator announced. Lean 4.34.1, Mathlib v4.34.1,
no new dependency. Six new library files under `formal/ZK60Formal/`, imported by the library root:
`RunChainStab.lean`, `RunChainSched.lean`, `RunChainExtract.lean`, `RunChainCover.lean`, `RunChainKinds.lean`,
`RunChainAssemble.lean`. No Rust and no production source changed. `Statements.lean` and every existing Lean file are
unchanged. Evidence: `results/zk60_lean_l27_20261107/`.

The lane was cut off on 2026-11-07 (a usage limit) with its last file checked but not committed, and resumed on
2026-11-09 after the Mac's restart. The resumed session committed that state, renamed one theorem whose name another
lane also uses (L27-6), added the cover without the endpoint (`cover3_of_runParts`, with `kindsFK_ℓ`, `kindsFK_lin`,
`kindsFK_mem`) and ran the final check (§6). perf has since moved to `8baff9cc` (L25 merged); the files it gained
(`HonestClassify*`) are not imported by this lane's files and share no declaration name with them.

Labels: **PROVED** (a Lean theorem, axioms at most `propext`, `Classical.choice`, `Quot.sound`), **HYPOTHESIS** (a
named premise of a proved theorem), **ESTIMATE** (arithmetic not proved in Lean).

## 1. In plain words, for Victor

**What this lane had to do.** Lane L24 proved the classify run's extraction as ONE event, counted by kinds of checks:
each kind (the sumcheck slots, `M`, the two halves of every commitment opening, the four relation schedules, LogUp) is
one schedule over all 26 blocks and the two stages, laid on the run's one transcript, and costs what one block costs.
L24 left as named premises everything about that transcript: each kind's schedule on it with its properties, the
deterministic covers (accepted while some part's conclusion fails ⇒ some check started with a false claim), and the
Merkle extraction failure at the run's queries. This lane discharges what lives on the run's chain.

**What is now proved.**
1. **A kind can be put together part by part.** Give, for each part of the run (stage IN-C, block 0 … block 25, stage
   OUT-C), that part's checks of the kind at their positions on the run's transcript, and every structural premise
   of L24's count follows: the windows are in order across the whole run, nothing is released, each check is
   round-by-round sound with its error, the run's header comes first (`KindRun.toFirstKind`).
2. **L24-2's stability premise is now a theorem.** L24 needed the extracted data to be the same whether one reads the
   prover's hash log just before "the escaping step" or the whole log, and could only argue it informally. It is
   proved for every extraction that reads the log by cutting it at a commitment root's first appearance
   (`cutAt_proverLog_esc`, `cutEq_esc`). Every extraction in the code does this (the slots' tables, the relation and
   LogUp data, `M`'s rows, the openings' columns: `cuts3_cutEq`, `defSq_cutEq`, `lkSq_cutEq`, `colX_cutEq`).
3. **The nine kinds' actual checks fit.** The code's sub-protocols of each kind (`slotSub`, `maskCSubX`, `opACSub`,
   `opBCSub`, the define draws and LogUp as squeeze runs) meet these premises at any position of the run's transcript,
   with the per-kind constants L24 budgeted (`RunChainKinds.lean`, `nine_lin_w16r2`, `nine_lin_r13`).
4. **The Merkle extraction failure for the whole run is one event with a proved bound**: at most
   `(q + 1)·(2^16 + 2^18)/2^126`, exactly L24's figure, for the 26 blocks at W16R2's or R13's opening geometry plus up
   to 3.8 million further Merkle queries for the boundaries and stages (`extract_fail_run_w16r2`, `_r13`). Outside it,
   every column the run verifier checks is the extracted one (`opened_eq_extracted_run`).
5. **The run's one cover reduces to per-part covers** (`cover3_of_runParts`, `jointCover_of_runParts`): on acceptance
   every check of every kind is alive at the end, and each part's failure makes one of that part's checks start with a
   false claim. Block `k`'s part reads the planes `B_k` and `B_{k+1}`, and its failure reduces to the four checks of
   L21's case analysis (`block_doom_w16`, `block_doom_r13`). A block's own results (L20 to L23) apply on the run's chain
   because a block's transcript is a prefix of the run's (`cChain_prefix`, `entD_of_prefix`, `subSt_of_prefix`).
   The first form covers stage IN-C, the blocks and stage OUT-C and asks nothing about the input endpoint; it is the
   form lane L26's gate takes (the endpoint handled there by its own two checks).
6. **The gate at W16R2 and at R13 through the run's chain** (`classify_productionReady_run_w16r2`, `_r13`): your
   targets, from `ClassifyOpen`'s other fields, the run's chain, the nine kinds and the per-part covers.

**What is not done** (§3). This lane does not finish the run's extraction: it reduces it to deterministic premises.
The run's chain itself is not yet built from the run verifier (L18 models the two stages as abstract parameters, so the
run's list of transcript operations is not yet a Lean object); the nine kinds' lists on it are therefore not written
out, only every fact they need; the per-part links (each block's and stage's "false conclusion ⇒ some check starts
doomed", and "accepted ⇒ every check alive") are named premises with their per-block sources given; and the input
endpoint (O11d) waits on your ruling on L24-1 (lane L26). The two gates of item 6 are stated at L18's instance, whose
endpoint premise is false (L24-1), so they become usable only at lane L26's instance: that restatement is short and is
left for after L26 is merged (L27-5).

**No finding needs your decision.** The findings (§5) are a premise L24 stated a little too strongly (L27-1, Low, met
here), the run-level form of L22-1 (L27-2, Medium: every part's squeeze count must be a profile constant, as the D12a
frame makes it), and bookkeeping (one of them a theorem name two lanes chose, renamed here, L27-6).

## 2. What is proved

PROVED in every row (axioms at most `propext`, `Classical.choice`, `Quot.sound`; the audit in §6).

### 2.1 `RunChainStab.lean`: L24-2's weak stability at the escaping step

| Theorem / definition | Statement |
|---|---|
| `cutAt_self_of_none`, `cutAt_append_cons`, `cutAt_proverLog_esc_aux` | a log with no absorption of `r` is its own cut; a log whose first absorption of `r` follows `P` is cut at `P` |
| **`cutAt_proverLog_esc`** | if the log's entry `t` absorbs `r`, the PROVER's log (replayed) cut at `r`'s first absorption is the same for `L.take t` and for `L` (either `r` was absorbed earlier, L16's `cutAt_proverLog_stable`, or entry `t` is the first absorption and both cuts stop there, whether `t` is the prover's query or the verifier's) |
| `CutEq`, `absAt_take`, `cutEq_take`, `cutEq_of_prefix` | two logs cut alike at every root a chain prefix absorbs, and at its prefixes |
| `StepCont`, **`stepsB_cont`** | a step's continuation is its head again or a squeeze; true of the code's steps `stepsB` |
| `zipItems_getElem?`, `stepItem_kind`, `absAt_eq_single`, `absAt_none`, `absAt_single`, `ents_map_getElem?`, `absAt_ents` | a step's entries (with ANY digests) absorb at most the step head's bytes |
| **`cutEq_esc`** | in the context of `FirstKind.hstab` (the chain before the escaping step logged before `t`, entry `t` the step's first query): `proverLog A (L.take t)` and `proverLog A L` are cut alike at every root any prefix of `τ ++ ext` absorbs (inside `τ` by L16's `cutO_stable`, the step's head by `cutAt_proverLog_esc`) |

### 2.2 `RunChainSched.lean`: one kind on the run's transcript, part by part

| Theorem / definition | Statement |
|---|---|
| `runCat`, `mem_runCat`, `pairwise_runCat`, `forall₂_append'`, `forall₂_runCat`, `forall₂_getElem?` | the parts' lists in the run's order (part `0` IN-C, part `k + 1` block `k`, part `L + 1` OUT-C) |
| `sortedA_of_pairwise`, `off_mono`, **`sortedA_run`** | windows in order over the whole run when each part's are and lie between its offsets |
| `AgreeOn`, `isFirst_congr`, **`firstSt_congr`**, `liftC_congr`, **`agreeOn_of_st`** | two schedules agreeing sub-protocol by sub-protocol (entered doomed alike, alive alike) have the same first-doom state; the same window, rounds and release with states agreeing on the header suffice |
| **`RunChain`**, `RunChain.chain` | a parse of the run's transcript: the code's chain encoding of `ItB Lq` items, a step parse `W`, steps (`StepCont`), the heads read off the statement and receipt, `ℓ`, the header `s` |
| **`KindRun`** | one kind on the run's ONE transcript `tr`: its own parse `RC` whose chain is `tr` (`htr`), `np` parts with offsets, each part's sub-protocols at their ABSOLUTE windows between its offsets, rbr, `ε ≤ εmax`, `n·ε ≤ B`, no releases, windows after the header, states reading the log through cuts (`hcut`) |
| `KindRun.sched`, `KindRun.mem_sched`, **`KindRun.toFirstKind`**, `toFirstKind_cs`, `_εmax`, `_B`, `_ℓ` | the kind as L24's `FirstKind`: EVERY field proved from the parts, `hstab` (L24-2's weak form) from `hcut` and `cutEq_esc` |
| `allSt_iff_mem`, **`KindRun.ev_of_parts`** | the kind's event from the parts: some part's sub-protocol entered doomed on `tr`, every part's alive at its end |
| `KindRun.PowForm`, `KindRun.SqForm`, **`lin_of_powForm`**, `fibC_div_le`, **`lin_of_sqForm`**, **`lin_of_lkForm`**, `lin_lk_w16r2`, `lin_lk_r13` | the per-kind constants: one error per round `≤ 2^-j` in `n` rounds gives `n·2^(126 − j)`; squeeze runs (errors `emax·fibC/|Dig|`, rounds `ND·fibC/|Dig|`) give `emax + ND`; LogUp (`e`, `3e`) gives `26,370,000` (`e ≤ 35,153,256`) or `50,331,700` (`e ≤ 2^26`), in units of `(q + 1)/2^126` |

### 2.3 `RunChainKinds.lean`: the nine kinds' sub-protocols meet `KindRun`'s premises

Every per-block sub-protocol takes its window as a parameter, and its rbr lemma holds at every window and header
reader (`slotSub_rbr`, `maskCSubX_rbr`, `opACSub_rbr`, `opBCSub_rbr`, `sqSub_rbr` with `defSq_rbr` / `lkSq_rbr`, the
stages' `chalSub_rbr`). With L9's block model at `hdrLen := h` (block `k`'s run prefix: the run header, stage IN-C, the
earlier blocks, its frame), every window is at its run position: `defPos P h k`, LogUp's `h + 4`, the slots'
`slotsLen` from `h + 10`, `M` and the openings after the slots.

| Theorem / definition | Statement |
|---|---|
| `forall₂_map_map` | two lists mapped from one list agree when every pair does |
| **`cuts3_cutEq`**, **`colX_cutEq`**, **`defSq_cutEq`**, **`lkSq_cutEq`** | L16's three cuts, L22's extracted column, L21's define draws and LogUp read the log only through cuts at the roots the header absorbs |
| `SqCut`, **`agreeOn_sqSub`**, `sqPart`, **`sqPart_cut`**, **`sqPart_facts`**, `defSq_sqCut`, `lkSq_sqCut` | a part of squeeze runs (a block's define draws, its LogUp): `hcut`, and rbr, `ε ≤ emax·fibC/|Dig|`, `n·ε ≤ ND·fibC/|Dig|`, no release (the four define kinds and LogUp) |
| `defOff_succ_le`, **`defPart_sorted`**, **`defPart_seg`**, **`lkPart_seg`** | a block's define part has its windows in order (slots in increasing order) and inside the block (`h ≤ defPos P h k ≤ defLen P h`); its LogUp part sits at `h + 4`: `KindRun.hsort` and `hseg` for these kinds' block parts |
| **`agreeOn_slotSub`**, **`slotSub_facts`** | one slot at two logs, its statement a cut reader; its rbr, error, rounds, no release (the slots' kind) |
| `slotsLen_take_succ`, `slotsLen_take_mono`, **`slotSubs_sorted`** | a block's slots (L8's `slotSubs`) have their windows in order: `KindRun.hsort` for the slots' block parts |
| **`agreeOn_toCSub`**, **`agreeOn_maskCSubX`**, **`mask_facts`** | `M` at two logs with agreeing readers; `M`'s error `≤ 2^-106` in three rounds (`PowForm 3 106`) |
| **`agreeOn_opACSub`**, **`agreeOn_opBCSub`** | the openings' `opA` and `opB` at two logs with agreeing extracted matrices |
| **`agreeOn_chalSub`**, **`chalSub_facts`** | the stages' single challenges (LogUp's `α`, the hosts' `ν`, the pads' `ζ`): agreement and the `SqForm` facts |

### 2.4 `RunChainExtract.lean`: the Merkle extraction failure at the run's queries (L16-8)

| Theorem / definition | Statement |
|---|---|
| `blocksV`, `blocksV_bounded`, `blocksV_queries`, `runV`, `runV_bounded`, `runV_queries` | the run verifier's Merkle work: block `k`'s L22 `blockV` for `k < n`, then the boundaries' and stages' `Vx`; at most `n·m + nx` queries; block `k`'s queries among the run's |
| `length_runCat_le`, `runRoots`, `runRoots_length`, `mem_runRoots` | the run's roots: every block's three, then the extra ones; at most `3n + nrx` |
| `EvXR`, **`extract_fail_classify_run`** | ONE extraction-failure event for the whole run: at most `collBound T + (2T² + (1 + 3n + nrx)·T)/|Dig|`, `T = q + n·m + nx` (`extract_fail_run` at `runV`) |
| **`opened_eq_extracted_run`** | outside it, every column block `k`'s Merkle work checks is the extracted one |
| **`extract_fail_run_u126`**, `xfail_run_w16r2`, `xfail_run_r13`, **`extract_fail_run_w16r2`**, **`extract_fail_run_r13`** | the number: `≤ (q + 1)·(2^16 + 2^18)/2^126` for `q + 1 ≤ 2^102` (L24's `cx`), 26 blocks (`340,704` queries at W16R2, `332,800` at R13), `nx ≤ 3,800,000`, `nrx ≤ 2^99` |

### 2.5 `RunChainCover.lean`: the covers on the run's chain

| Theorem / definition | Statement |
|---|---|
| **`cChain_prefix`** | the chain of a run's first heads (a block's view: its run prefix as its header) is a prefix of the run's chain |
| **`entD_of_prefix`**, **`rdAlive_of_prefix`**, **`subSt_of_prefix`**, **`allSt_of_prefix`**, `exists_entD_of_prefix` | a doom on a prefix is a doom on the run's chain; a sub-protocol read alive and frozen (all rounds read) on a prefix, never released, is alive at the end of the run's chain |
| **`cover3_of_runParts`** | the cover of stage IN-C, the blocks and stage OUT-C from per-part covers, for any `Protocol` on the classify model and with no premise about the endpoint: `halive` (on acceptance outside `Ex`, every kind's sub-protocols of every part alive at the end of `tr`), and `hdin`, `hdblk` (block `k`'s `BlockOn` on `B_k`, `B_{k+1}`), `hdout` (each failing part makes one of its sub-protocols of some kind enter doomed) give: accepted with `¬ (InOk ∧ BlocksOk ∧ OutOk)` lies in `Ex` or in the event of a kind, in any list `Ls` holding the run's kinds. This is premise `h3` of lane L26's `classifyU_productionReady_ep_target` |
| **`jointCover_of_runParts`** | `classify_productionReady_joint_target`'s `hcover` (all four parts): the same premises and `hdep` (the endpoint's failure makes some sub-protocol enter doomed). Named `jointCover_of_parts` until 2026-11-09 (L27-6) |
| **`block_doom_w16`**, **`block_doom_r13`** | block `k`'s `hdblk` from L21's case analysis: with `B_k`, `B_{k+1}` the block's extracted planes, `BlockOn` failing ⇒ one of the four links fires (the openings' and `M`'s claims, the slots' claimed sums, the slot relations, the lookups; L16's `blockSat_of_slots`, L17's `blockSat_of_slots_r13`, L18's `blockOn_of_blockSat`) |

### 2.6 `RunChainAssemble.lean`: the gate through the run's chain

| Theorem / definition | Statement |
|---|---|
| `kindsFK`, `kindsFK_fst` | the kinds with their constants as L24's `FirstKind`s |
| `kindsFK_ℓ`, `kindsFK_lin`, `kindsFK_mem` | the kinds' chain bounds (`≤ 2^21`) and linear parts carried to their `FirstKind`s, and their membership in any longer list of kinds: with `cover3_of_runParts`, what another protocol's gate takes from this lane |
| **`classify_productionReady_runChain`** | `ProductionReady … εcTarget εsTarget εsTarget εzkTarget` from `ClassifyOpen` (every field but O11), the run's transcript `tr`, any list of kinds on it (chains `≤ 2^21`, `np = L + 2`) with their constants, an extra event with its bound, the per-part covers, constants `≤ 2^26` |
| `εxRun`, `εxRun_le`, `hEx_w16r2`, `hEx_r13` | the extra event: the run's extraction failure, within `(q + 1)·(2^16 + 2^18)/2^126` for `q + 1 ≤ 2^102`, `1` beyond |
| `nine_lin_w16r2`, `nine_lin_r13`, `nine_bud_w16r2`, `nine_bud_r13` | the nine kinds' linear parts from their forms, and the budgets (`31,177,585` and `57,261,913`, each `≤ 2^26`) |
| **`classify_productionReady_run_w16r2`**, **`classify_productionReady_run_r13`** | the gate at W16R2 and at R13 (the app): the nine kinds in their forms, the run's extraction failure at the 26 blocks' geometry, the per-part covers |

## 3. What remains

Exactly the premises of `classify_productionReady_run_w16r2` / `_r13`. All are deterministic: every probability on the
run's chain is now proved.

1. **The run's transcript and its parses** (`tr`, each kind's `RunChain` with `htr`). The run verifier's list of
   transcript operations as a function of the statement and receipt (the run header, stage IN-C, every block's D12a
   frame and `verify_core`, the boundary openings, stage OUT-C), then `tr G o` its executable trace. L22's
   `cChain_stps` (wide parse) and L21's `cChain_trace` (single steps) give `htr` for any operation list, so what is
   missing is the list itself: L18 models stages IN-C and OUT-C as abstract parameters (`StageInV`, `StageOutV`); the
   blocks are concrete (`d12aBlockProf`). With it: `ℓ ≤ 2^21` (L18's ESTIMATE: about `2^16` items for the whole run),
   `StepsOK` for each parse (L22's `stpOK_opsStps`, `wRuns_at` per part), `StepCont` (`stepsB_cont`), the header `s`,
   and the profile's counts (L27-2).
2. **Each kind's parts** (`KindRun.cs i`): the stages' sub-protocols of each kind (L24-6: IN-C's and OUT-C's slots,
   their single challenges, their `M` and openings, define schedules for their relations), and the blocks' at their
   run windows. §2.3 gives every constructor's facts; what remains is writing the lists with the profile's counts and
   checking the forms' side conditions (`e ≤ emax`, `n·e ≤ ND`, `opA`'s `A ≤ 2^15`, `|K| = p²`), the numbers L20, L21
   and L23 already checked per block.
3. **The covers** (`halive`, `hdin`, `hdblk`, `hdout`):
   - blocks: `block_doom_w16` / `_r13` reduce `hdblk` to four per-block links on the run's chain, each L20–L23's link
     through the block's view (`cChain_prefix`, `entD_of_prefix`, `allSt_of_prefix`): L22's `hsem` (`mGood_mTrue`,
     `groupsGood_claimSem`) and `hexec` (`mask_subSt_of_ok`; the `A`/`H` field link still open in L22), L21's
     `defWin_event` / `lkWin_event`, L23's `hcoverR`, `hcoverH`, `hsplit`; plus the boundary-plane link (`B_k`,
     `B_{k+1}` are block `k`'s extracted planes: L12's `RunFrame`, the boundary openings) and the step parse at each
     window (L27-2);
   - stages: `hdin`, `hdout` from IN-C's and OUT-C's round-by-round pieces (L24-6; L12's `inc_stage_sound` and L15's
     `outc_stage_sound` are joint over all challenges and lift only through those pieces);
   - `halive`: every sub-protocol read alive and frozen in its part (`allSt_of_prefix`).
4. **The run's Merkle work's extra part**: `Vx` (the boundary and stage openings' column checks as an oracle
   computation, `nx ≤ 3,800,000` queries), `rx` (their roots, `nrx ≤ 2^99`), and `coreOf` (block `k`'s decoded segment).
5. **O11d, the endpoint** (`hdep`): false for the current `opensIn` (L24-1); with a unique-decoding `opensIn` (lane L26,
   pending Victor's ruling) it is the endpoint opening's `opA`/`opB` kinds and the decoding link. Lane L26's gate
   (`classifyU_productionReady_ep_target`, in L26's worktree on 2026-11-09, not yet merged) discharges the endpoint
   from its own column test and asks the other three parts' cover as its premise `h3`, which is
   `cover3_of_runParts`'s conclusion. **The gates through the run's chain at L26's instance** (the nine kinds beside
   L26's two, `kindsFK_mem`, `kindsFK_ℓ`, `kindsFK_lin`, L26's eleven-kind budgets) are not written: they need L26's
   files, which this lane may not import before they are merged (L27-5).
6. **Everything else in `ClassifyOpen`** (O1–O10, O12), as L18 left it (lane L25, merged on perf since, reduces O8,
   O9 and discharges O10 for transcript-program sites; not used here).

So of `classify_productionReady_joint_target`'s own premises: `hℓ` (each kind's chain `≤ 2^21`) is carried as the
same bound on each kind's parse; `hlin`, `hx`, `hbud` and `hEx` are **discharged** at both profiles (the constants
from the kinds' forms, the extraction failure's bound proved); every structural field of each `FirstKind` is
**discharged** from the parts (`hstab` included); `hcover` is **reduced** to `halive`, `hdin`, `hdblk`, `hdout`,
`hdep`; and `O` (the rest of `ClassifyOpen`), `hbij`, `hzk` pass through unchanged. New premises this lane introduces
in exchange: the transcript `tr` with each kind's parse (`htr`, `StepsOK`, `hcont`, the header), the nine `KindRun`s
with their forms (`SqForm` / `PowForm` at the profile's constants, `np = L + 2`), and the Merkle work's extra part
(`Vx`, `nx ≤ 3,800,000`, `rx`, `nrx ≤ 2^99`, `coreOf`).

## 4. The numbers

Units `u126 q c = (q + 1)·c/2^126`; `εsTarget q = u126 q 2^26`.

| | W16R2 | R13 (the app) |
|---|---|---|
| per-kind linear constants (L20/L21's figures, now from the kinds' forms) | slots `5 + 924`, `M` `3·2^20`, `opA` `2^15`, `opB` `2^13`, define `4 × (80 + 80·351)`, LogUp `26,370,000` | slots `7 + 7·370`, `M` `3·2^20`, `opA` `2^15`, `opB` `2^21`, define `4 × (80 + 80·451)`, LogUp `50,331,700` |
| the run's Merkle extraction failure (once) | `2^16 + 2^18`, at `340,704 + nx` verifier queries | `2^16 + 2^18`, at `332,800 + nx` |
| total (`nine_bud_*`) | `31,177,585 ≤ 2^26` (and `≤ 2^25`) | `57,261,913 ≤ 2^26` |

The extraction-failure bound needs `T' = q + n·m + nx ≤ 2^22·(q + 1)`: the 26 blocks use 8.1 % (W16R2) or 7.9 % (R13)
of the `2^22` allowance, leaving 3.8 million queries for the boundaries and stages [their counts: ESTIMATE, far below].

## 5. Findings

No statement or target is weakened; `Statements.lean` is unchanged.

**L27-1 (Low; L24's `FirstKind.hstab`): the premise quantifies over the escaping step's entries with ANY digests.**
`fs_code_chain_first_log` uses stability only for the step's own `wd it` digests, but `FirstKind.hstab` asks it for
`S.ents it ds` with any `ds`. For general steps the entries beyond the step's width are arbitrary items and the
stability could fail there. For the code's steps a step's continuation is its head again or a squeeze (`StepCont`,
`stepsB_cont`), so a longer `ds` absorbs nothing new and the premise holds (`cutEq_esc`). Carried as
`RunChain.hcont`; L24's theorem needs no change.

**L27-2 (Medium; the run-level form of L22-1): every part's operation and squeeze counts must be profile constants.**
The kinds' windows are fixed positions on the run's chain and each parse's `W` is one function of the squeeze counter,
so the run's chain parses as the kinds read it only if every part (stage IN-C, each block, stage OUT-C) has the
profile's operation and squeeze counts. The D12a verifier decodes every segment at the statement's geometry, so on an
accepted receipt this should hold [CODE reading, to be proved with the run's transcript, §3 item 1]. It is the
coordinator's L22-1 form (each block's header fixed by the D12a frame) at the run level, and the covers' premises
(windows at step ends) presuppose it.

**L27-3 (Info; the parses): different kinds read the one transcript through different parses.** L21's define and
LogUp schedules are proved with single steps (`W1`), L20/L22's `M` and openings with wide runs (`wRuns`). Both chains
are the same trace (`cChain_trace`, `cChain_stps`), so `KindRun` carries its own parse and the equation `htr` to the
run's ONE transcript; the covers are stated on that transcript, each kind with its own parse's `W`.

**L27-4 (Info; for the coordinator): a block's view of the run is L9's block model with the run prefix as header.**
Every per-block result of L20–L23 is about a block prover's output `(header ops, core)` with `hdrLen` the header's
length. Block `k` on the run is that model with `hdrLen` = block `k`'s run position, the run prefix as its header, the
same prover queries, and its chain a prefix of the run's (`cChain_prefix`). So the per-block deterministic links
transfer by `entD_of_prefix` and `allSt_of_prefix` (every block sub-protocol's rounds lie inside the block), with
L22-1's squeeze count the profile's.

**L27-5 (Low; for the coordinator): the endpoint stays open, so the two gates here are not yet usable.** `hdep` (O11d)
is a premise of `classify_productionReady_run_w16r2` and `_r13`, which are stated at L18's `classifyProtocol`. There it
is false (L24-1: the instance's `opensIn` asks all `N` columns to open), so no one can supply it and the two gates
prove nothing about a real run until the instance changes. Lane L26 builds that instance (`classifyProtocolU`) and a
gate that discharges the endpoint itself, pending Victor's ruling on L24-1. What carries over from this lane without
change is protocol-independent: the kinds (`KindRun.toFirstKind`), the extraction failure (`hEx_w16r2`, `hEx_r13`),
the constants (`nine_lin_*`), and the three-part cover (`cover3_of_runParts`, which is exactly L26's premise `h3`).
The restatement of the two gates at `classifyProtocolU` is a short step for whoever merges both lanes.

**L27-6 (Low; for the coordinator): two lanes chose the name `ZK60.ProtocolClassify.jointCover_of_parts`.** This lane's
`RunChainCover.lean` (committed 2026-11-07, `9fce8ae5`) and lane L26's `ProtocolClassifyU.lean` (uncommitted in its
worktree on 2026-11-09) both declared it, with different statements. The library root imports both files, so the
merged build would have stopped on a duplicate declaration. Found on resume by comparing this lane's 120 declaration
names with every Lean file of every worktree (35 worktrees); it was the only clash. Fixed here: this lane's theorem is
now `jointCover_of_runParts`; L26's keeps its name. The lanes cannot see each other's uncommitted names, so the same
comparison is worth running at each merge.

## 6. Checks

To be completed after the final check.
