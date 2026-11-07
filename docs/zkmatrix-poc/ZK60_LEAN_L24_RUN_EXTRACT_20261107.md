# D63 lane L24: the classify run's extraction (O11), the first-doom count on the code's chain (2026-11-07)

Lean lane L24 (Claude), on its own worktree, fast-forwarded to perf at `99c4dc30` (lanes L9 to L21 and L18 merged).
Lean 4.34.1, Mathlib v4.34.1, no new dependency. Five new library files under `formal/ZK60Formal/`, imported by the
library root: `ZoneCodeWide.lean`, `ZoneCodeFirst.lean`, `RunExtractKinds.lean`, `RunExtractClassify.lean`,
`RunExtractOpenU.lean`. No Rust and no production source changed. `Statements.lean` and every existing Lean file are unchanged. Evidence:
`results/zk60_lean_l24_20261107/`.

Labels: **PROVED** (a Lean theorem, axioms at most `propext`, `Classical.choice`, `Quot.sound`), **CODE** (read off the
sources), **ESTIMATE** (arithmetic on proved bounds or on code counts, not proved in Lean), **HYPOTHESIS** (a named
premise of a proved theorem).

## 1. In plain words, for Victor

**What this lane had to do.** The gate for the media app's classify run (L18's `ClassifyOpen`) still needs its
extraction part, O11: from any prover that gets a receipt accepted, read the hidden data off its hash queries and show
that the data satisfies every part (stage IN-C, the 26 blocks, stage OUT-C, the input endpoint), except with a tiny
probability. L18 found that the way the proofs counted did not reach your target over the whole run: about `2^-99.5`
against `2^-100`, and summing 26 per-block bounds is worse (finding L18-2). You approved the fix in D66(4): follow ONE
cheat through the run instead of adding up every block.

**What is now proved.**
1. **The one-zone count, carried to the code's real transcript, in a sharper form.** In the knowledge setting every
   check's claim is about the data extracted from the prover's queries, so a false claim is a "doom" of that one check.
   The proof follows the FIRST check that started with a false claim. That check can only be rescued by its own
   challenges, so the verifier's whole transcript costs ONE check's rounds, not 26 blocks' (`fs_code_chain_first_log`).
   The prover's own queries are still charged the worst per-query error, as they must be. This is D66(4)'s path-wise
   bound with the zone shrunk from one block to one check.
2. **The blocks jointly.** Grouping the run's checks by kind (the sumcheck slots, `M`, the two halves of every
   commitment opening, the four relation schedules, LogUp), each kind is one schedule over all 26 blocks, counted
   once. **At W16R2 the 26 blocks together cost what ONE block costs: 31.2 million units of `(q + 1)/2^126`, inside
   half of your target** (`joint_w16r2_target`, every `q`).
3. **O11 in exactly the form `ClassifyOpen` names it** (`classify_O11_of_kinds`, `ClassifyOpen.withO11`), and the gate
   at your targets through it (`classify_productionReady_O11_target`), from named premises.
4. **A better assembly: the run's extraction as one event** (`classify_productionReady_joint_target`). `ClassifyOpen`
   asks four separate bounds and adds them, so every shared kind pays its query term four times. Counting the run once
   pays it once. **At R13, the app's real profile, only this joint form meets your target**: `57.3` million of the
   `67.1` million units (85 %, `joint_r13_target`). The per-part form misses it (finding L24-4).

**One finding needs your attention (L24-1, High).** As the classify protocol is instantiated today, "the input
commitment opens to `x`" means that ALL `N = 65,536` columns of the input commitment open. The verifier only spot-checks
256 of them. A cheating prover can put one unusable leaf in the commitment tree and still be accepted about 99.6 % of
the time, and then NO input opens the commitment in that sense. So the endpoint part of the extraction (O11d) cannot
hold with any small bound, for any extractor, and the gate at your targets cannot be reached with this definition (nor
can `KnowledgeSound` at this instance). This is a mismatch between a Lean definition and the protocol, not a weakness of
the protocol: the commitment still pins `x` down, because all other columns are consistent with `x`. The fix is to
define the opening at the code's unique-decoding radius ("all but at most `e` columns open to `x`'s encoding", `2e`
below the code distance). The core of `Binding` for that definition is proved here (`opensU_diff`: two different
inputs would give two different openings of one tree position). `Statements.lean` does not change; the classify
instance's `opensIn` (L10/L18) does, which needs your or the coordinator's reading first.

**What is not done.** The premises are deterministic links and the per-kind schedules, listed in §4: for the blocks,
the schedules of L16/L20/L21's checks laid on the run's one transcript, and the links that L22 (`hexec`, `hsem`) and L23
(the cover lemmas) are working on; for the stages, their schedules and links; the input endpoint needs L24-1's fix first.

## 2. What is proved

PROVED in every row below (axioms at most `propext`, `Classical.choice`, `Quot.sound`; the counts in §6).

### 2.1 `ZoneCodeWide.lean`: the wide-hit composition with a charge that reads the prover's log

| Theorem / definition | Statement |
|---|---|
| `posErrL`, `posErrL_le` | the position charge: `εmax` at a prover's position; at the verifier's, `e (P.take r.2) τ it`, the prover's own log `P.take r.2` recovered by replay |
| `posBad_prob_le_L` | the named set has probability at most that charge, given the round bound read at `proverLog A P` |
| `posErr_sum_le_L` | the charges along the run sum to at most `q·εmax` plus the verifier's charge read at the prover's whole log |
| **`chain_sound_wide_seq_L`** | `FSPathWide.lean`'s `chain_sound_wide_seq` with that charge and the WEAK stability `hstabW` (the state at the log before the escaping step's first query agrees with the state at the whole log, on that chain and that step: exactly where the proof uses stability) |
| `hstabW_of_hstab` | the usual stability (any extension) gives the weak form |

The three proofs are `FSPathWide.lean`'s, line for line, with the charge's extra argument and the two stability uses
replaced (generated from the source and checked by the build).

### 2.2 `ZoneCodeFirst.lean`: the first-doom count

| Theorem / definition | Statement |
|---|---|
| `EntD`, `entD_append` | a sub-protocol entered its window with a false claim (a property of its header) |
| `SortedA`, `IsFirst`, `exists_isFirst`, `isFirst_unique`, `isFirst_append`, `isFirst_take`, `firstK`, `firstK_eq_some_iff` | the first doomed entrant (smallest index); with windows in order it never changes once chosen, and it was already first at its window's start |
| `firstSt`, `firstCharge`, `firstCharge_of_charged`, `firstCharge_le`, `firstSt_short`, `not_subSt_of_entD_take` | the state "the first doomed entrant is alive"; the charge of a step: that entrant's error when the step starts one of ITS rounds |
| **`firstSt_rbr`** | the first-doom state is round-by-round with that charge (no releases; rounds via L8's `rdAlive_step`, `rdAlive_charged`) |
| `everG`, `everG_congr`, **`everG_rbr`**, `not_everG_first_short`, `everG_first_of_event` | doomed at some step's end and alive now, for any state; the event "some entrant doomed, every sub-protocol alive at the end" is that state's |
| `vSumFrom_le_along`, `vSumFrom_zero`, **`firstCharge_vSum_le`** | along ANY chain the verifier's charge is at most `max_c n_c·ε_c` (one sub-protocol; L20's potential for that one) |
| **`fs_code_chain_first_log`** | a family of schedules read off the prover's log, each sub-protocol `RbrWide` with error `≤ εmax`, no releases, windows in order and after `s`, `n_c·ε_c ≤ B`, the first-doom state stable at the escaping step: some sub-protocol enters its window with a false claim and every one is alive at the end with probability at most `q·εmax + B + collBound T + collBound (T + 1)`, `T = q + ℓ + 1` |

### 2.3 `RunExtractKinds.lean`: kinds of sub-protocols over the whole run, and the arithmetic

| Theorem / definition | Statement |
|---|---|
| `FirstKind`, `FirstKind.Ev`, `FirstKind.bnd`, **`FirstKind.prob_le`** | one kind: a chain encoding of the run's transcript, a step parse, the receipt's heads, a log-read schedule holding that kind's sub-protocols of every part, with every premise of `fs_code_chain_first_log` for every prover; its event; its bound |
| `prH_exists_list`, **`ext_of_kinds`**, `εKinds`, `ext_of_kinds_min` | any event covered by a list of kinds and one extra event (the Merkle extraction failure) is at most the extra bound plus the kinds' bounds, and at most `1` |
| `coll_le_u126_102`, `FirstKind.bnd_le_u126`, `kinds_le_u126` | for `q + 1 ≤ 2^102` and chains of `≤ 2^21` items, a kind within `(q + 1)·(c + 2^17)/2^126` when its linear part is within `(q + 1)·c/2^126` |
| `half_eq`, `u126_le_half`, `one_le_half`, `four_le_target`, `xfail_le_u126_102` | the half target `(q + 1)/2^101`; the target beyond `2^102`; the extraction failure (`T' ≤ 2^22(q + 1)` queries, `≤ 2^100` roots) within `(q + 1)·(2^16 + 2^18)/2^126` |
| `lin_kind_le`, `sched_kind_le`, `logup_kind_le`, `lk_main_le_u126_r13` | the kinds' linear parts at their forms (one error per round; the slots' and define draws' `(q·d + ND)β/p²`; LogUp's `(q·e + 3e)β/p²`, at R13 `e ≤ 2^26` within `50,331,700` units) |

### 2.4 `RunExtractClassify.lean`: O11 as `ClassifyOpen` names it, the joint form, the numbers

| Theorem / definition | Statement |
|---|---|
| **`classify_O11_of_kinds`** | the four O11 fields of `ClassifyOpen` (O11a IN-C, O11b the blocks JOINTLY, O11c OUT-C for the statement's verdict, O11d the endpoint), for any protocol of the classify model and the run's extractor, from four lists of kinds and four deterministic covers; each bound `min 1 (εx q + Σ_K (q·εmax_K + B_K + coll))` |
| `ClassifyOpen.withO11` | any `ClassifyOpen` with its O11 fields replaced |
| `partConst`, `kindsP_le_u126`, `εKinds_le_u126`, `joint_le_target`, `joint_le_half`, **`four_way_le_target`** | the parts within the target (every `q`) when their constants total `≤ 2^26` (the four-way sum) or `≤ 2^25` (the half) |
| **`classify_productionReady_O11_target`** | the gate `ProductionReady … εcTarget εsTarget εsTarget εzkTarget` through `ClassifyOpen`, O11 from kinds, the parts' constants `≤ 2^26` |
| `JointOk`, `JointExtract`, **`iopExtract_of_joint`**, **`jointExtract_of_kinds`** | the run's extraction as ONE event (any part failing), from ONE list of kinds shared by all parts; `IOPExtract` at that one bound |
| **`classify_productionReady_joint`**, **`classify_productionReady_joint_target`** | the gate through the joint extraction (every `ClassifyOpen` field but O11), at the targets when the shared kinds' constants are `≤ 2^26` |
| `partConst_nine`, `joint_budget_w16r2`, `joint_budget_r13`, `joint_budget_r13_over_half`, **`joint_w16r2_target`**, **`joint_r13_target`** | the numbers (§3) |

### 2.5 `RunExtractOpenU.lean`: the input commitment's opening at the unique-decoding radius (L24-1's fix, its core)

| Theorem / definition | Statement |
|---|---|
| `word_eq_of_column_eq`, **`eq_of_columns_agree`** | two admissible values whose columns agree on at least `n + Q` positions are equal (each data row's word is a polynomial of degree `< n + Q`; the code-distance form of L10's `column_inj`) |
| `OpensU`, `opensU_of_opens` | the opening at radius `e`: admissible, and all but at most `e` columns verify against the root; a full opening is one (the honest prover's) |
| **`opensU_diff`** | two different admissible values opening one root at radius `e`, `2e + n + Q ≤ N`, have a position where BOTH open and their columns differ: two openings of one tree position, the step `PlaneCommit.binding` takes to `merkle_binding` |

## 3. The run's εs against the target

Units: `u126 q c = (q + 1)·c/2^126`; `εsTarget q = q·2^-100 + 2^-100 = u126 q 2^26`; the half target
`q·2^-101 + 2^-101 = u126 q 2^25`. Each kind's bound is `q·εmax + B + collBound T + collBound (T + 1)`; its linear
part `q·εmax + B` is the per-kind figure below (PROVED by L20/L21's lemmas at their forms), its two collision terms
`2^17` (PROVED for `q + 1 ≤ 2^102`, chains of `≤ 2^21` items; beyond `2^102` every bound is capped at `1` and the target
exceeds `4`).

**First-doom per kind**: `B` is the largest ONE sub-protocol's `n·ε` over every block (and, in the joint form, over the
stages): one block's figure, not 26 blocks'.

| Kind (all 26 blocks in one schedule) | W16R2 linear constant | R13 linear constant | source |
|---|---|---|---|
| sumcheck slots | `5 + 924` | `7 + 7·370` | L20 `slots_le_u126` (the block's whole `ND`; first-doom needs only one slot's) |
| `M` (three rounds, `≤ 2^-106` each) | `3·2^20` | `3·2^20` | L10 `maskEps_le`, L20 `lin_le_u126` |
| openings' `opA` (`λ, ρ`) | `2^15` (`≤ 2^-111`) | `2^15` | L20 `opA_eps_w16r2`, `opA_eps_le` |
| openings' `opB` (the indices) | `2^13` (`≤ 2^-113`) | `2^21` (`≤ 2^-105`, δ/3) | L20 `opB_eps_w16r2`, `opB_eps_r13` |
| four define schedules (relations, helpers) | `4·(80 + 80·351)` | `4·(80 + 80·451)` | L21 `rung_defND_le`; L17 451 draws |
| LogUp (`β, γ, α`, one count `e = N + 2M`) | `26,370,000` (`e ≤ 35,153,256`) | `50,331,700` (`e ≤ 2^26`) | L21 `lk_main_le_u126`; this lane `lk_main_le_u126_r13`; R13's `e` ESTIMATE from D54 (64.3 M looked-up words per Shieldstral block) |
| nine kinds' collision terms | `9·2^17` | `9·2^17` | `coll_le_u126_102` |
| the Merkle extraction failure (once) | `2^16 + 2^18` | `2^16 + 2^18` | `xfail_le_u126_102` |
| **total** | **`31,177,585 ≤ 2^25`** | **`57,261,913 ≤ 2^26`, `> 2^25`** | `joint_budget_w16r2`, `joint_budget_r13`, `joint_budget_r13_over_half` |

**W16R2** (PROVED, `joint_w16r2_target`): the blocks jointly, at most `(q + 1)·2^-101.1`, inside the HALF target for
every `q`. With the stages' and the endpoint's kinds inside the other half, L18's `extract_split_le_target` closes the
run. Against L18-2's `2^-99.5` for the run's constant and `26·εsTarget` for the per-block sum: the run now costs one
block.

**R13, the app** (PROVED given the per-kind figures, `joint_r13_target`): the run's shared kinds at most
`(q + 1)·2^-100.23 ≤ εsTarget q`, every `q`. The stages' kinds are no larger than the blocks' (IN-C's LogUp has
`e ≈ 531,166`, OUT-C's `≈ 54,094`, L15 §3), so in the JOINT form the stages add nothing to the maxima [ESTIMATE].

**The four-way split** [ESTIMATE on the per-kind figures]: `ClassifyOpen` adds the parts, each with its own kinds
(its own `M`, openings, LogUp, collision terms and extraction failure).
- W16R2: the blocks `31.2` M; stage IN-C about `4.5` M (`M` `3.1` M, LogUp at `e ≈ 531,166` about `0.4` M, openings,
  collision terms, extraction failure), OUT-C about `4.4` M, the endpoint about `0.7` M: about `40.8` M `≤ 2^26`, and
  each half `≤ 2^25`. L18's `extract_split_le_target` closes W16R2.
- R13: the blocks alone are `57.3` M, above the half target, so `extract_split_le_target` cannot apply; with IN-C
  (about `6.8` M: `opB` at `2^-105` costs `2.1` M per kind), OUT-C (about `6.5` M) and the endpoint (about `2.7` M) the
  sum is about `73` M `> 2^26 = 67.1` M. The joint form is what meets the target at R13 today (L24-4).

**The per-query rate** (the coefficient of `q`, ESTIMATE): W16R2 about `9.9` M units per query (LogUp `e/4 ≈ 8.8` M,
`M` `2^20`), `q·2^-102.8`; R13 about `20` M units per query (LogUp `2^26/4`, `M`, `opB` `2^21`), `q·2^-101.7`. Both
inside the target's `2^-100` per query.

## 4. The remaining premises

Every one is a named hypothesis of a PROVED theorem; none involves probability except the extraction failure's
instance.

1. **The kinds** (`FirstKind`'s fields, per kind). The chain encoding and step parse of the run's ONE transcript, the
   receipt's heads, and the kind's schedule: that kind's sub-protocols of every block (and, jointly, every stage) at
   their absolute windows, their claims read off the prover's log. Their per-sub-protocol round-by-round soundness is
   proved where the sub-protocols are defined (`maskCSubX_rbr`, `opACSub_rbr`, `opBCSub_rbr`, `slotSub_rbr`,
   `sqSub_rbr` / `defSq_rbr`, `lkSq_rbr`; for the stages `chalSub_rbr`, L15). What is left is laying them on the run's
   chain (windows in order, after the header `s`, chains of `≤ 2^21` items, a common step parse per kind) and:
   - **`hstab`, the first-doom state's stability at the escaping step.** Per block this is L16's `cutO_stable`. The
     STRONG form (any extension) fails for a schedule over several blocks (L24-2); the weak form holds for the
     cut-at-first-absorption extraction (a root absorbed by the escaping step's own query is cut at that query in both
     logs), which is what the theorem asks.
   - the linear constants (§3), from L20/L21's lemmas (`lin_kind_le`, `sched_kind_le`, `logup_kind_le`).
2. **The covers** (`hin`, `hblk`, `hout`, `hep`; jointly `hcover`), deterministic: accepted, the opened columns equal to
   the extracted ones, and a part's conclusion failing ⇒ some kind's event. For the blocks these are the block-level
   links with the run's planes:
   - each block's `BlockSat` on the run's boundary planes (block `k` reads `B_k` and `B_{k+1}` as the run's extractor
     does: the plane cut at `B_k`'s root, `boundaryFrame`), with its `io_in` / `io_out` claims checked by the boundary
     openings in segments `k` and `k + 1` (classify_run.rs's framing, L12's `RunFrame`);
   - L20/L21's `hexec`, `hsem` (L22: the openings' and `M`'s rounds read off the verifier's transcript, `OpenTrue`),
     `hcoverR`, `hcoverH`, `hsplit` (L23), now as statements about the run's chain;
   - "alive at the end" for every block's sub-protocol of the kind on acceptance (the opening split of L20's
     `opening_split` gives it for `opB`; `opA` dead at the end means `opB` entered doomed).
   For the stages: the same links for IN-C's and OUT-C's checks (L12's `inc_stage_sound` and L15's `outc_stage_sound`
   are joint over all challenges and cannot be lifted as black boxes; their round-by-round pieces are, L24-6).
3. **The extra event**: the Merkle extraction failure at the run's queries (L16's `extract_fail_run`; its instance at
   the verifier's queries, L16-8), within `(q + 1)·(2^16 + 2^18)/2^126`.
4. **O11d, the endpoint**: false for the current `opensIn` (L24-1). With a unique-decoding `opensIn` it is the
   endpoint opening's kinds (`opA`, `opB` at the token commitment's geometry, L20's `opening_knowledge_chain_pos`) and
   the decoding link.
5. **Everything else in `ClassifyOpen`** (O1–O10, O12) as L18 left it.

## 5. Findings

No statement or target is weakened; `Statements.lean` is unchanged.

**L24-1 (High; the classify instance's `opensIn`): O11d, and therefore `ClassifyOpen`, cannot hold.**
- `classifyProtocol`'s `opensIn` is L10's `PlaneCommit.Opens` (BindingW16.lean:115-118, ProtocolClassify.lean:727):
  the value is admissible and EVERY one of the `N` columns verifies against the root with its salt and path.
- The verifier opens the input commitment at `Q` FS-chosen columns only (R13: `N = 2^16`, `Q = 256`). A prover that
  replaces ONE leaf of the commitment tree by a digest it cannot open (and computes the rest honestly) is accepted
  unless that column is drawn: about `(1 − 1/N)^Q ≈ 0.9961`, and higher if it grinds. No extractor can then output
  `(x, r)` with every column opening: that needs a preimage of the leaf, probability at most `q/2^256`. So
  `Pr[accept ∧ ¬EpOk] ≳ 0.996` for every extractor, and `KnowledgeSound` at this instance is false for every small `εs`
  [argument, not a Lean theorem].
- Not a protocol weakness: every other column is consistent with `x`'s encoding, so the commitment does determine
  `x`. The definition asks too much.
- **Fix (instance, not statement):** `opensIn H s x r :⇔ C.ok x ∧ #{j | column j of (x, r) opens at j} ≥ N − e` with
  `2e < d` (the encoder's minimum distance; at R13 `e = 24,448`, the radius L17's `opening_sound_r13` uses).
  `Complete` holds unchanged (the honest commitment opens at every column: PROVED, `opensU_of_opens`). `Binding`
  holds: two different values opening the same root at the radius both open, with different columns, at some
  position (PROVED, `opensU_diff`, from `eq_of_columns_agree`, the code-distance form of `column_inj`); what is left is
  the reduction that finds that position (it queries the tree to check the openings) into `merkle_binding`.
  `KnowledgeSound` then is the opening's knowledge (L20's `opening_knowledge_chain_pos` decodes the extracted matrix
  within `e`). The radius at R13: `N = 2^16`, `n + Q = 16,640`, so `e ≤ 24,448`. This needs Victor's or the
  coordinator's reading before the instance (L10's `opensIn`, L18's `classifyProtocol`) is changed.

**L24-2 (Medium; the stability premise of L16/L20's composition): the strong `hstab` fails for a joint schedule.**
- L16's `fs_code_chain_sound_sched_log` and L20's `fs_code_chain_sound_sched_log_pos` ask the schedule to be frozen
  once the chain's first `s` entries are logged, for ANY extension. Over several blocks, block `k`'s roots are absorbed
  after block `k − 1`'s windows, so no single `s` freezes them: at a prover's position a later root may not be logged
  yet.
- The proof uses stability at two places only: the escaping step's chain and that step (`chain_sound_wide_seq`). There
  the cut-at-first-absorption extraction is stable (a root absorbed by the step's own first query is cut at that query
  in both logs). `chain_sound_wide_seq_L` takes exactly that weak form; `hstabW_of_hstab` keeps every existing
  per-block use.

**L24-3 (Info; resolves L18-2 for the blocks): in the knowledge setting the path-wise zone is ONE sub-protocol.**
- D66(4)'s zone (one block plus its boundary openings) is what a SOUNDNESS proof needs: the statement's doom is handed
  through the boundary commitments. In the knowledge setting with no releases, each sub-protocol's claim is about the
  extracted data; following the first doomed entrant suffices, and the verifier's chain costs that one sub-protocol's
  rounds (`firstCharge_vSum_le`).
- Grouped by kind, the blocks' joint term equals one block's (§3).

**L24-4 (Medium; the app's numbers): at R13 the blocks miss the half target and `ClassifyOpen`'s four-way sum misses
the target; the joint form meets it.**
- R13's LogUp reads about 64.3 M words per Shieldstral block (D54), about twice W16R2's 34.9 M (16-bit limbs). With L21's
  count (all three of `β, γ, α` charged `e = N + 2M`), LogUp's constant is `3e/4 ≈ 50.3` M units; the blocks' kinds
  total `57.3` M `> 2^25`.
- So `extract_split_le_target` (each half `≤ 2^25`) cannot close R13, and the four-way `ClassifyOpen` sum (each part its
  own kinds) is about `70` M `> 2^26` [ESTIMATE]. `classify_productionReady_joint_target` counts each shared kind once:
  `57.3` M `≤ 2^26` [PROVED given the figures].
- Two independent improvements would give margin: L21-9 (each LogUp round its own escape count `2M`, `M`, `N + 2M − 1`;
  about a third of the constant, `≈ 16.8` M) and R13's `opB` at the unique-decoding radius (L17-4: about `2^-172`
  instead of `2^-105`; needs R13's code facts on the chain, as `w16r2_open_code_facts` does for W16R2).
- **Recommendation:** assemble the classify run through `classify_productionReady_joint_target`; keep
  `ClassifyOpen` for the non-extraction fields.

**L24-5 (Low; `ClassifyOpen`'s form): the four-way split pays each shared term four times.** `RunExtract`'s four
bounds are added by `iopExtract_of_runExtract`, so the prover term `q·εmax` of a kind shared by the parts, and the Merkle
extraction failure, are counted once per part. `JointExtract` / `iopExtract_of_joint` count them once.

**L24-6 (Info; O11a, O11c): the stages lift through the same kinds.** L12's `inc_stage_sound` and L15's
`outc_stage_sound` bound the stages over all their challenges at once; a Fiat–Shamir lift cannot use them as black
boxes (the prover chooses when to query). Their round-by-round pieces can: the stage's slots (`stageSched`,
`slotSub_rbr`), its single challenges (`chalSub_rbr`: LogUp's `α`, the hosts' `ν`, the pads' `ζ`), its `M` and openings,
and define schedules for its relations (as L21's for the blocks). `classify_O11_of_kinds` takes them as kinds with the
deterministic cover that the interactive proofs' case analysis gives.

**L24-7 (Info; for the coordinator): `block_knowledge_target_mt` cannot be the joint count's input.** It is a per-block
probability bound (for a prover of one block); such bounds compose only by the union bound, which brings back the
`26×` on the prover term and on the constant (L18-2). The joint count takes what it is built from: L16's slots, L20's
`M` and opening chains, L21's define and LogUp schedules (each a kind here), and its deterministic premises (`hsem`,
`hexec`, `hcoverR`, `hcoverH`, `hsplit`) restated on the run's chain for every block, which is the covers' content
(§4, item 2). Its budget lemma `w16r2_budget_mt` is the W16R2 kinds' figures used in §3.

**L24-8 (Info, engineering).** `∃ k c, cs[k]? = some c ∧ …` leaves `k`'s type open (a stuck `GetElem?` instance): give
binder types. `dif_pos` / `if_pos` are deprecated here (`dite_eq_left` / `ite_eq_left`).

## 6. Checks

All in `results/zk60_lean_l24_20261107/`, each run as ONE job through the zk60 resource guard (class `cpu`,
`run_guarded.py`, need 14 GiB, cap 24 GiB), `iter.sh` reading `plan.txt`. The build cache was cloned from the main
checkout (L21 built) and L18's worktree (L18's six modules), so only this lane's modules were rebuilt. Waiting for the
shared heavy lock dominated (up to about two hours per job behind A27's GPU jobs and the other Lean lanes); each job
ran 14–109 s once admitted.

- `iter1.log` … `iter3.log`: the files while they were written. Fixed on the way: an existential `∃ k c, cs[k]? = …`
  with `k`'s type open (a stuck `GetElem?`); L20's `lsum_le_lsum` is for lists in `Type` (a list of kinds lives in
  `Type 1`: `lsum_le_lsum_univ`); two unused hypotheses; `∀ q, (q : ℝ≥0∞) * …` binding `q` in `ℝ≥0∞` (now `∀ q : ℕ`);
  a recursion-depth failure in two declarations of `RunExtractClassify.lean` (the event left to higher-order
  unification and the `constructorNameAsVariable` linter, which unfolds `Finset.univ` over the `2^256` digests, as in
  L18's `ProtocolClassifyComplete.lean`: the events are now given explicitly and that linter is off in that file); an
  implicit argument not determined under a `refine … ?_`; an unused section instance (`omit … in`).
- **`iter4.log` and `check.log`** (`check_l24.sh` inside iteration 4; the job: exit 0, 109 s, peak RSS 10.31 GiB):

| Check | Result |
|---|---|
| `lake build` of the five L24 modules, one at a time, then the whole library (`full.log`) | rc 0, **3,542 jobs, 0 warnings, 0 errors, 0 `sorry`**; 0 warnings in the L24 files |
| the axiom audit (`gen_axioms.py` → `axioms_l24.lean`, a `#print axioms` line for every `theorem` of the five files → `axioms.log`) | **63 theorems** (ZoneCodeWide 5, ZoneCodeFirst 19, RunExtractKinds 17, RunExtractClassify 18, RunExtractOpenU 4): 61 on `[propext, Classical.choice, Quot.sound]`, 2 on `[propext]`; no `sorryAx`, no `Lean.ofReduceBool`, no other axiom |
| the source scan of the five files for the forbidden constructs (the words included, also in comments) | none |
| the library root imports the five files | yes |
| L6Check on the committed L6 corpus | 1,206 checks, 0 failed |
| L5Check on the committed L5 corpus | 5,553 checks, 0 failed |
| L11Check on L11's committed W16R2 rung corpus | 404 checks, 0 failed |
| the fixture L1 check | 101,956 checks, 0 failed |

No agreement corpus is new: every L24 theorem is about L8's, L10's, L16's, L18's and L20's definitions, whose
agreement with the Rust verifier their lanes established; L24 adds no executable code.
