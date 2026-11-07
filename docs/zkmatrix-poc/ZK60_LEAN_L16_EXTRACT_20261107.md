# D63 lane L16: the W16R2 block's knowledge extraction, discharging L10-6 (2026-11-07)

Lean lane L16 (Claude), on its own worktree branched from perf at `5a1c7ea8` (L9, L10, L11 and L12 merged). Lean
4.34.1, Mathlib v4.34.1, no new dependency. Five new library files under `formal/ZK60Formal/`, imported by the library
root: `ExtractW16Chain.lean`, `ExtractW16Slots.lean`, `ExtractW16Terminal.lean`, `ExtractW16Block.lean`,
`ExtractW16Open.lean`. No Rust and no production source changed. `Statements.lean` and every existing Lean file are
unchanged. Evidence: `results/zk60_lean_l16_20261107/`.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms at most `propext`, `Classical.choice`, `Quot.sound`),
**CODE** (read off the sources), **ESTIMATE** (arithmetic on bounds, not proved in Lean), **HYPOTHESIS** (a named premise
of a proved theorem, with the shape another lane proves or must prove).

## 1. In plain words, for Victor

**What this lane is.** Statement 1's "only if" needs more than "a false claim is caught": it needs that from any prover
that gets a block accepted, one can READ OFF the data behind its commitments (the extractor, from the prover's own
hash queries), and that this data satisfies the block's constraint system. L10 left one gap open there (finding
L10-6): L9's block theorem assumed that each slot's final value is the slot's polynomial at the challenge point, and
that polynomial had to be something the transcript shows, while the true polynomial is built from the committed
tables, which the transcript does not show.

**What is now proved.**
1. **The knowledge version of the Fiat–Shamir composition on the code's real transcript.** L8's theorem (any schedule
   of sub-protocols on the code's chain, per-query rate = the largest error) now allows each sub-protocol's state to
   read data EXTRACTED from the prover's log, cut at the first query that absorbs a root, exactly as the knowledge
   statement's extractor may (it reads only the prover's own log). The bound is unchanged.
2. **The block's 23 slots with polynomials over the extracted tables.** L9's block bound (at most `2^-61` at the rung)
   holds for ANY slot polynomials that read the prover's log cut at the three roots `A`, `M`, `H`. PROVED for every
   block shape, and at the rung **for every number of hash queries `q` it is below your approved target
   `q·2^-100 + 2^-100`**.
3. **The terminal identity is enforced by `M` and the openings.** If the claims a block hands to the `A`/`H`/endpoint
   openings and the functionals it hands to `M` are true of the extracted data, then every slot's final value IS its
   polynomial over the extracted data at the point. So the premise L10-6 named reduces exactly to "the openings' and
   `M`'s claims are true of the extracted tables" (L11-2's observation, now a theorem).
4. **One block's knowledge statement, composed.** For any admissible block shape (A25's finding: each block may carry
   its own plane list and range families), the probability that the block's slots accept while the extracted planes do
   NOT satisfy CircuitBlock's `BlockSat` at the logical positions is at most `εopen + εsc + εrel + εlk`. `εsc` is proved
   (point 2). The other three are named hypotheses with the exact shape the other lanes must prove: the openings' and
   `M`'s knowledge (`εopen`), L13's slot relations (`εrel`), LogUp (`εlk`).
5. **Pieces of `εopen`, proved.** `M`'s three rounds with EXTRACTED mask rows on the code's chain (at most
   `T·2^-106 + collisions`), and the Merkle extraction-failure bound for any run (an opened column that verifies but is
   not the extracted one: at most `collBound T + (2T² + 4T)/2^256`).

**What is not done yet** (§5): the regular `A`/`H` opening's knowledge on the code's chain (its two rounds as one
schedule, L10-3), the step from "the block verifier accepts" to "`M`/the openings are alive at the end" (relating L10's
`MaskOk`/`PcsOk` to the extracted rows), the verifier's queries as an oracle computation (to instantiate the
extraction-failure bound), and the run level (`L` blocks, the D55 tree).

**One finding needs attention (L16-1, Medium).** With L8's way of counting (every verifier query is charged the
largest error), the block's constant term is about `2^20 · 2^-103 ≈ 2^-83`, which is ABOVE your target's `2^-100`. The
slots alone are fine (their error is tiny), but `M` (`2^-106`) and LogUp (`2^-102.9`) charged on every one of the
verifier's ~`2^20` queries are not. The fix is a sharper count that already exists on L3's model chain
(`FSPathWide.lean`, finding F25): charge each verifier query only its own step's error. It must be carried to the
code's chain. This is a proof-technique limit, not a weakness of the protocol.

## 2. What is proved

55 theorems (Chain 8, Slots 17, Terminal 13, Block 8, Open 9), every one on at most `propext`, `Classical.choice`,
`Quot.sound` (the axiom audit, §6); no `sorry`, `axiom`, `native_decide`, `admit`, `maxRecDepth`, `maxHeartbeats`,
`implemented_by`, `extern`, `bv_decide` or `ofReduceBool` (the source scan). Facts about the literal Goldilocks prime are
stated for a variable `p` within `2^32` below `2^64` (L7-4).

### 2.1 `ExtractW16Chain.lean`: the knowledge composition on the code's chain (generic)

| Theorem / definition | Statement |
|---|---|
| `chain_take`, `chain_link_mem` | a chain's prefix is a chain with a prefix of its queries; entry `i`'s link query is among the chain's queries |
| `isAbsAt`, `cutAt`, `cutAt_append`, **`cutAt_proverLog_stable`** | the log cut at the first query absorbing a value (any decoder `absOf`); once a log holds such an absorption, every longer log cuts the PROVER's log (recovered by replay) at the same place (FSOpening's `cut_proverLog_stable` for any chain encoding) |
| `allSt_short`, `everSt_congr_pre` | windows after `s` entries: no doom before `s`; two schedules agreeing after an `s`-prefix agree on `everSt` |
| **`fs_code_chain_ever_log`**, **`fs_code_chain_sound_sched_log`** | L8's `fs_code_chain_ever` / `fs_code_chain_sound_sched` for a FAMILY of schedules indexed by the run's log, frozen once a chain's first `s` entries are logged: some sub-protocol enters its window with a false claim and all are alive at the end with probability at most `T·ε + collBound T + collBound (T + 1)`, `T = q + ℓ + 1` |

### 2.2 `ExtractW16Slots.lean`: the block's slots over the extracted tables

| Theorem / definition | Statement |
|---|---|
| `SlotX`, `SlotX.at`, `slotsAt`, `slotsLenX`, `slotsLen_at`, `slotsAt_take`, `slotsLen_take_at` | slots whose statements read a log; the run at one log |
| `subSt_congr`, `subSt_slotSub_at`, `allSt_slotsAt_congr` | schedules at two logs agree where their statements agree |
| **`exec_sumchecks_fs_knowledge`** | L8's `exec_sumchecks_fs_sound` for slots whose statements read the prover's log, frozen after `s` entries: the same bound |
| `absAt`, `rootsAt`, `rootsOf`, `cutO`, `cuts3`, `absOfC`, `absOfC_link`, `rootsAt_trace`, `rootsAt_append`, `absAt_logged`, `cutO_stable` | the three roots as the trace shows them (`A` after the header, `M` 3 later, `H` 7 later); on the verifier's trace they are the core's; the cut at a root the chain shows is frozen once the chain is logged |
| `blockSlotX`, `blockSchedX`, `slotsLenX_blockSchedX`, **`blockWinX_slotsWin`** | the block's schedule with polynomial `F (cuts) (roots) k (seen)`; L9's `BlockWin` with it is the slots' win |
| **`block_sumchecks_fs_knowledge`**, `block_sumchecks_fs_knowledge_shape`, **`W16R2.rung_block_fs_knowledge`** | L9's bound for ANY slot polynomials over the prover's log cut at the roots; `2^-61` at any shape of degree `≤ 7`, `T ≤ 2^64 + 2^20`; at the rung |

### 2.3 `ExtractW16Terminal.lean`: the terminal identity (L10-6 (b), (c); L11-2)

| Theorem / definition | Statement |
|---|---|
| `Claims4.get`, `Claims4.get_push_self`, `Claims4.get_push_mono`, `slotClaimList`, `slotClaims_mono`, `slotClaims_mem` | the claims a slot builds (`build_claim` per private table, the masked terminal its value) are among the accumulator's, which only grow |
| `slotAcc_claims`, `slotAcc_fs_mono`, **`slotAcc_fs_eval`** | a slot's `M` functional `⟨[(s, evalWeights(ρ, d))], g⟩` is in the functional list after it |
| `exGuard_ok`, **`slotStep_ok_terminal`**, **`slotsLoop_terminal`** | an accepting slot (loop) exposes its definition, `c ≠ 0`, its values, `g = (fin − poly)·c⁻¹`, its functional in the final list, its claims among the final claims |
| `scVerify_fin_canon`, `fin_identity` | the sumcheck's final value is canonical; `fin = poly(vals) + c·g` in `K` |
| `ClaimsTrue`, `MTrue`, `SlotEval` | the claims / `M` functionals true of some data; the slot polynomial's evaluation interface over that data (the masked slot polynomial: `f(ρ) = poly(true values) + c·(M functional on the data)`) |
| **`blockSlots_terminal`** | `blockSlots` accepts ∧ `ClaimsTrue` ∧ `MTrue` ∧ `SlotEval` ⇒ every slot's terminal check `fin = f(ρ)`: L9's `BlockWin` premise |

### 2.4 `ExtractW16Block.lean`: one block's knowledge statement

| Theorem / definition | Statement |
|---|---|
| `SlotsAcc`, `cutsOf`, `blockSlots_fin_canon` | the slots accept a canonical core of the shape; the extractor's cut logs |
| `BlockWinT`, **`blockWinT_blockWin`** | the slots' win with the claims' and `M`'s truth is L9's `BlockWin` |
| **`block_terminal_knowledge`**, `block_terminal_knowledge_shape` | its probability is at most L9's bound for polynomials over the extracted tables; `2^-61` at the shapes above |
| `slots_bound_le_target`, **`rung_block_terminal_knowledge_target`** | at the rung, FOR EVERY `q`: at most `εsTarget q = q·2^-100 + 2^-100` |
| **`block_knowledge`** | the slots accept while the extracted planes do not satisfy `BlockSat`: at most `εopen + εsc + εrel + εlk` (named hypotheses `hOpen`, `hRel`, `hLk`, `hdeg`); for ANY `BlockParams`, `W16Layout`, `W16Pub`, range families and extraction `xtE` |
| `run_blocks_union` | several blocks, each with its own shape and bound (A25's finding: a real model's blocks carry different plane lists): some block fails with probability at most the sum |

### 2.5 `ExtractW16Open.lean`: `M` with extracted data; the Merkle extraction failure

| Theorem / definition | Statement |
|---|---|
| `maskCSubX`, `maskCSubX_rbr`, `maskCSubX_St_nil`, `allSt_singleton`, `maskCsAt` | L10's `maskCSub` with the data as the statement (`X = MData`, read off the header by any `xOf`); round-by-round sound with `maskEps ≤ 2^-106` |
| **`mask_knowledge_chain`** | `M`'s rounds with the data EXTRACTED from the prover's log, on the code's chain: entering its window with `¬ MGood` and alive at the end has probability at most `(q + ℓ + 1)·maskEps + collBound T + collBound (T + 1)`, any step parse `W` |
| `sum_range_four_mul_add_le`, `extNamedR`, `extNamedR_card`, **`extract_fail_run`** | any run (a prover, then any verifier computation), several roots: an opened column verifying against a root the prover output, but not the column extracted from the prover's log cut at that root's first absorption, at most `collBound T + (2T² + (1 + nr)·T)/|D|` |
| `bind_digOf_eq_iff`, `absD`, `cutAt_absD` | on the code's chain the digest cut is the byte cut of `cuts3` |

## 3. ε_block against the target

`block_knowledge` gives, for one block of any admissible shape, `ε_block(q) = εopen(q) + εsc(q) + εrel(q) + εlk(q)`.
`T = q + ℓ + 1`, `ℓ` the block's chain items (`ℓ = hdrLen + 1044` at the rung, `≤ 2^20` for a header of `≤ 2^19`
operations), `|K| = p²`, `p = 2^64 − 2^32 + 1`.

| Term | Value | Status |
|---|---|---|
| `εsc` (the 23 slots' sumchecks over the extracted tables) | `T·5/p²·(1 + p/2^128)² + collBound T + collBound (T + 1)`; at most `2^-61` for `q ≤ 2^64`; **at most `εsTarget q` for every `q`** | PROVED (`rung_block_fs_knowledge`, `rung_block_terminal_knowledge_target`) |
| `εopen`: `M`'s rounds over the extracted mask rows | `T·maskEps + collBound T + collBound (T + 1)`, `maskEps ≤ 2^-106` | PROVED as a sub-protocol of the code's chain (`mask_knowledge_chain`); its link to the verifier's acceptance is left (§5) |
| `εopen`: the Merkle extraction failure | `collBound T' + (2T'² + 4T')/2^256`, `T'` the run's queries | PROVED for any run (`extract_fail_run`); its instance at the block verifier's queries is left |
| `εopen`: `A` and `H` openings over the extracted matrices | per opening about `T·2^-113` (field term `2^15/2^128`, column term `((N − e − 1)/N)^280 ≈ 2^-114` at δ/2) | ESTIMATE (L10's per-round errors; the composition on the code's chain is left, L10-3 / L16-3) |
| `εrel` (L13: the slot relations given true claimed sums) | about `T·129/p² ≈ T·2^-121` per slot, `T·2^-121` composed | HYPOTHESIS (L13's composed bound) |
| `εlk` (LogUp's conclusion) | about `T·135/2^110 ≈ T·2^-102.9` (`Kind8B`'s LogUp `α`) | HYPOTHESIS / ESTIMATE |

**Against `εsTarget q = q·2^-100 + 2^-100`** [ESTIMATE from the rows above]:
- the per-query rate is about `2^-102.9 + 2^-106 + 2·2^-113 + 2^-121 + 2^-125.7 ≈ 2^-102.6`, below the target's `2^-100`
  per query: the `q` part meets the target for every `q`;
- at `q = 2^64`: `ε_block ≈ 2^-38.6`, against `εsTarget(2^64) ≈ 2^-36`: met;
- the constant part, with L8's union over the verifier's own `ℓ ≈ 2^20` queries, is `(ℓ + 1)·2^-102.6 ≈ 2^-82.6`, ABOVE
  the target's `2^-100` (finding L16-1). With the sharper count (each verifier query charged only its own step's error,
  `FSPathWide.lean`'s `chain_sound_wide_seq`, finding F25), the verifier's charge is the sum over its own steps, about
  `2^-102.9 (LogUp α) + 3·2^-106 (M) + 4·2^-113 (openings) + 296·2^-125.7 (slot rounds) ≈ 2^-102.5`: met.
- The slots' own part already meets the target at every `q` with L8's count (PROVED): their error is small enough that
  even `2^20` charged verifier queries stay below `2^-105`.

## 4. Findings

No mismatch with the approved statements; no statement weakened. `Statements.lean` unchanged.

**L16-1 (Medium): with L8's count, the block's constant term is above `εsTarget`'s `2^-100`.**
- `fs_code_chain_sound_sched` (and its knowledge version here) charges every one of the `T = q + ℓ + 1` positions,
  the verifier's `ℓ` included, the LARGEST sub-protocol error. For the slots (`≈ 2^-125.7`) that is harmless; for
  LogUp's `α` (`≈ 2^-102.9`) and `M` (`2^-106`) the verifier's `≈ 2^20` items give a constant `≈ 2^-82.6`.
- The approved target needs the per-position count on the code's chain: port `FSPathWide.lean`'s
  `chain_sound_wide_seq` (the prover's positions charged the largest error, each verifier position its own step's) to
  L8's code chain, then the block's constant is about `2^-102.5`. A proof-technique limit, not a protocol weakness.
  Alternatively, two schedules (the slots alone, proved here at the target; the rest with the sharper count).

**L16-2 (Low): wide rounds need a fixed header shape.** `M`'s and the openings' rounds draw challenge VECTORS, so their
schedule parse needs a width function `W` of the squeeze counter (L8-3). Their counters are fixed only if the
operations before them are; L9's `BlockWin` lets the prover choose the header (`hdrLen` operations of any kind), so
`mask_knowledge_chain` is stated for any `W` and steps with the parse premises (`hS`, `hhd`), and a profile instance
needs the run's fixed header shape (true for a D55 run, whose header is the run statement's). Not a soundness issue.

**L16-3 (Info; a route for L10-3): the regular opening without the schedule coupling.** L10 split the opening into two
sub-protocols `opA`, `opB` and left their coupling to the schedule. Their knowledge versions can be bounded SEPARATELY
(two one-sub-protocol schedules, each with the matrix extracted as in `mask_knowledge_chain`) and added: `¬GroupsGood ∧
GroupsAccept ⊆ (¬GroupsGood ∧ Alive1) ∪ (¬Alive1 ∧ GroupsAccept)`. The opening's term at most doubles (`≈ 2^-112`), and
no release is needed. What it does need: `opB`'s statement read off its header (the `λ`, `ρ` digests and the
`"pcs-vec"` absorbs at `opA`'s positions), which is plumbing.

**L16-4 (Info): the terminal identity needs canonical polynomial values.** L9's `BlockParams.define` returns `poly` as
an abstract function; `blockSlots_terminal` takes `hpolyC` (every value canonical). L11's IR evaluator meets it
(`canon_irEvalW`); the profile's `define` (L13's builders) must use it.

**L16-5 (Info): the endpoint claims belong to the run.** A block's private tables in `Cm.inp` / `Cm.out` produce claims
that `blockVerify` returns instead of opening. `block_knowledge`'s `hOpen` covers all four commitments; for `inp` /
`out` it is discharged at the run level (the boundary and endpoint openings, L12's stage lemmas).

**L16-6 (Info): the extraction rule.** The extractor cuts the prover's OWN log (recovered by replay, as `KnowledgeSound`
requires) at the first query that absorbs a root's bytes, under any label and state, for each of the core's three
roots (`cuts3`); it reads nothing else. This is `FSOpening.lean`'s rule on the code's chain. Its stability once the
verifier's chain is logged is PROVED (`cutO_stable`).

**L16-7 (Info, A25's finding): every theorem is per block shape.** `block_knowledge` and the slot theorems are stated
for any `BlockParams` (geometry, draws, `define`) and any `W16Layout` / `W16Pub` / range families; the rung is one
instance. A run composes blocks each with its own shape (`run_blocks_union`).

**L16-8 (Info): the verifier's queries as an oracle computation.** `extract_fail_run` bounds the extraction failure for
any run `A.bind V` whose queries include the opened columns' Merkle queries. `blockVerify` is a pure function of
`liftH G`; instantiating the bound needs the verifier's chain and Merkle checks as an `OC` (`chainOC` and `checkAll`
exist; their composition for the block's three openings is left).

## 5. What is left

1. **The regular opening's knowledge on the code's chain** (L10-3, route L16-3), with `opB`'s header readers.
2. **From acceptance to "alive at the end"** for `M` and the openings: `MaskOk` / `PcsOk` (L10) with the opened columns
   equal to the extracted ones give `MFinal` / `GroupsAccept` on the extracted data (L10's `mcol_iff_K`,
   `opening_columns_K` and the `groupZclaims` ↔ `OClaims` map). Then `hOpen` follows from `mask_knowledge_chain`, the
   opening's two rounds and `extract_fail_run`.
3. **The sharper count on the code's chain** (L16-1), to meet the target's constant term.
4. **The claim semantics** `csX`, `msX` and the slot polynomials `F` as functions of the extracted tables (the claims'
   functionals through `zpartWeights` / `zkeyWeights`, `M`'s through `combinedWeights`), with `SlotEval` and `hdeg`: the
   interface L13's builders meet.
5. **L13's `hRel`** and **LogUp's `hLk`** under Fiat–Shamir on the code's chain.
6. **The run level**: `run_blocks_union` (each block its own shape) is the plain union; the per-fork extraction on the
   D55 tree (finding F31, `fs_d55_sound_8B_target`) with one schedule per fork is not started.

## 6. Checks

All in `results/zk60_lean_l16_20261107/`, each run as one job through the zk60 resource guard (class `cpu`,
`run_guarded.py`; the build cache cloned from L10's worktree, so only the new modules were rebuilt):
- `warm.log`: the library built from the cloned cache, 3,486 jobs, 6 s.
- `iter1.log` … `iter6.log` (`iter.sh`, its plan file `plan.txt`): the five files while they were written; the errors
  fixed on the way are in those logs (an unannotated binder, a `subst` that kept the other name, a `simp` with no
  progress, `norm_cast` reaching the recursion limit on `2^102` casts, a missing `DecidableEq` instance, `zero_le`'s
  arity, a missing lemma name). Peak RSS 3.4–3.8 GiB, each 4–31 s once admitted.
- `check_run1.log`, `check_run2.log`: the full check before the last two fixes (both stopped at `ExtractW16Block`'s
  build errors; run 2 showed the other four files with 0 warnings).
- **`check.log`** (`check_l16.sh`, job `lean-l16-check`, exit 0, 54 s, peak RSS 3.77 GiB):
  - the full build (`full.log`): **3,491 jobs, rc 0, 0 warnings, 0 errors, no `sorry`**;
  - the axiom audit (`axioms_l16.lean`, written by `gen_axioms.py`, → `axioms.log`): **55 theorems**, 32 on
    `[propext, Classical.choice, Quot.sound]`, 15 on `[propext, Quot.sound]`, 8 on `[propext]`; `sorryAx` and
    `Lean.ofReduceBool` nowhere;
  - the source scan of the five L16 files: none; the root imports all five;
  - the regressions: **L6Check 1,206 checks, 0 failed**; **L5Check 5,553 checks, 0 failed**; **L11Check 404 checks,
    0 failed** (on L11's committed W16R2 rung corpus); **the fixture L1 check 101,956 checks, 0 failed**.
- No agreement corpus is new here: every L16 theorem is about L9's and L10's executable functions, whose agreement with
  the Rust verifier L9 (273 checks) and L10 (48 checks) established; L16 adds no executable code.
