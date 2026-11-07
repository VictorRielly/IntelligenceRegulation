# D63 lane L20: the per-position Fiat–Shamir count on the code's chain, and the openings' knowledge (2026-11-07)

Lean lane L20 (Claude), on its own worktree, fast-forwarded to perf at `fdad3157` (L9 to L16 merged). Lean 4.34.1,
Mathlib v4.34.1, no new dependency. Five new library files under `formal/ZK60Formal/`, imported by the library root:
`CountW16Chain.lean`, `CountW16Slots.lean`, `CountW16Target.lean`, `OpenKnowChain.lean`, `OpenKnowBlock.lean`. No Rust
and no production source changed. `Statements.lean` and every existing Lean file are unchanged. Evidence:
`results/zk60_lean_l20_20261107/`.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms at most `propext`, `Classical.choice`, `Quot.sound`),
**ESTIMATE** (arithmetic on bounds, not proved in Lean), **HYPOTHESIS** (a named premise of a proved theorem, with the
shape another lane proves or must prove).

## 1. In plain words, for Victor

**The problem this lane fixes (L16-1).** The Fiat–Shamir theorems on the code's own transcript counted every one of
the verifier's own hash queries as if it could be attacked with the WORST sub-protocol error. A block's verifier asks
about a million hashes. Charged LogUp's `2^-103` or `M`'s `2^-106` each, they add up to a constant term of about
`2^-83`, far above your target's `2^-100`, even with no cheating queries at all. This was a weakness of the proof
method, not of the protocol.

**What is now proved.**
1. **The sharper count, on the code's chain.** Each of the verifier's own steps is now charged only the error of the
   round it actually starts. Most of the verifier's hashes start no round at all (absorbs, interstitial challenges,
   the rest of a wide challenge) and cost nothing. The verifier's whole chain then costs the sum, over the
   sub-protocols, of rounds times error, whatever the chain's length. The prover's own queries are still charged the
   worst error, as they must be. This holds with the committed data extracted from the prover's log, as the knowledge
   statement needs.
2. **The block's slots with that count.** The constant part of the slots' term drops from `(hdrLen + 1045)·5/2^128`
   (up to about `2^-105.7` for a header of `2^19` operations) to `924/2^128 ≈ 2^-118` at the W16R2 rung (296 rounds of
   degree 2 to 5), whatever the header's length.
3. **The openings' knowledge, with the matrix extracted.** `M`'s three rounds cost `(q + 3)·2^-106`. The regular `A`
   and `H` openings are each split in two (the batching challenges, then the column indices), bounded as two separate
   schedules and added. This is L16's suggested route; no hand-over between the two halves is needed. Each costs
   `(q + 1)·(2^-111 + 2^-113)` at W16R2's geometry (`N = 2^15`, `Q = 280`).
4. **The block's knowledge statement, restated where it can be proved.** L16's statement asked for the openings'
   bound on the event "the slots accept". That cannot hold: a prover can pass the slots with false opening claims and
   then fail the openings. The statement is now about the whole block verifier accepting (finding L20-1). There, the
   openings' term is a sum of the proved bounds above, given two deterministic links (§5).
5. **The block's total meets your target for every `q`.** With the openings and `M` at their proved bounds and the
   extraction failure, the sum is at most `q·2^-100 + 2^-100`. The other lanes' terms (L13's relations, LogUp) must
   fit a budget of `(q + 1)·2^-101` together; LogUp at `2^-102.9` per query fits. The fixed part is about `2^-104`.
   The proof is per block shape; W16R2's numbers are one instance, and the opening exponents are parameters (an R13
   geometry is given too).

**What is not done** (§5). Two deterministic links stay as named premises. Neither involves probability; both are
plumbing:
- **the executable link**: when the block verifier accepts and the opened columns are the extracted ones, each
  opening's rounds read off the verifier's own transcript are alive at the end of the chain;
- **the claims' index map**: the extracted data satisfying each opening's good predicate makes every claim and `M`
  functional true.

## 2. What is proved

60 theorems (`CountW16Chain` 18, `CountW16Slots` 9, `CountW16Target` 11, `OpenKnowChain` 19, `OpenKnowBlock` 3),
every one on at most `propext`, `Classical.choice`, `Quot.sound` (the axiom audit, §6); no `sorry`,
`axiom`, `native_decide`, `admit`, `maxRecDepth`, `maxHeartbeats`, `implemented_by`, `extern`, `bv_decide` or
`ofReduceBool` (the source scan). Facts about the literal Goldilocks prime are stated for a variable `p` within `2^32`
below `2^64` (L7-4).

### 2.1 `CountW16Chain.lean`: the per-position count on the code's chain (generic)

| Theorem / definition | Statement |
|---|---|
| `CSk`, `CSub.sk` | a sub-protocol's skeleton (window, rounds, error): what the charge reads; the state may read the prover's log |
| `Charged`, `chargeC` | **the charge of a step**: after a chain of whole steps, the step with head `h` is charged the error of every sub-protocol whose round it STARTS (window started, reader between rounds and not frozen, `h` a squeeze of the round's width, message flag agreeing), capped at `εmax` |
| `potRd`, `potS`, `potW`, `potS_step`, `chargeC_add_potW_le` | the potential "rounds still owed": one item never raises it, a charged step lowers it by one |
| **`vSumFrom_chargeC_le`**, `vSumFrom_chargeC_nil_le` | along ANY chain the charges sum to at most `Σ_c n_c·ε_c` (`FSPathWide.lean`'s verifier charge `B`) |
| `rdAlive_charged` | a sub-protocol doomed at a step's end is revived only by a charged step |
| `CodeRbrE`, **`allSt_rbr_pos`**, `everSt_rbr_pos`, `codeRbr_step_pos` | L8's `allSt_rbr`, `everSt_rbr`, `codeRbr_step` with the per-step error `chargeC` |
| **`fs_code_chain_ever_log_pos`**, **`fs_code_chain_sound_sched_log_pos`** | L16's log-reading composition with the per-position count: some sub-protocol enters its window with a false claim and every one is alive at the end with probability at most `q·εmax + Σ_c n_c·ε_c + collBound T + collBound (T + 1)`, `T = q + ℓ + 1` |
| `lsum_map_add`, `lsum_le_lsum`, `le_lsum_of_mem` | list sums in `ℝ≥0∞` |

### 2.2 `CountW16Slots.lean`: the block's slots, per position

| Theorem / definition | Statement |
|---|---|
| `slotsND`, `slotSubs_sk_at`, `slotSubs_charge_list`, `sum_n_div`, `slotSubs_charge` | the slots' skeleton is the same at every log; its charge is `Σ_k n_k·d_k·fibC/|Dig|` |
| **`exec_sumchecks_fs_knowledge_pos`** | L16's `exec_sumchecks_fs_knowledge` with the per-position count: `(q·dmax + Σ_k n_k·d_k)/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)` |
| `blockND`, `slotsND_blockSchedX`, **`block_sumchecks_fs_knowledge_pos`** | the block's slots over the extracted tables, any shape: `(q·dmax + blockND)/|K|·(1 + p/2^128)² + coll` |
| **`block_terminal_knowledge_pos`** | L16's `block_terminal_knowledge` (claims and `M` functionals true of the extracted data) with that bound |
| `W16R2.rung_nd` | `blockND rungSlots = 924` |

### 2.3 `OpenKnowChain.lean`: the openings' knowledge on the code's chain

| Theorem / definition | Statement |
|---|---|
| **`mask_knowledge_chain_pos`** | `M`'s three rounds with the mask rows and functionals EXTRACTED: `q·maskEps + 3·maskEps + coll` (`maskEps ≤ 2^-106`) |
| `mGood_val_eq_true`, `groupsGood_claims` | the good predicates' meaning: `MGood` gives a decoding under which every functional's value is its true value; `GroupsGood` makes every claim true of the decoded matrix |
| `RbrWide.and_left` | a state guarded by a condition on the statement keeps its round-by-round error |
| `opARounds`, `opBRounds`, `opARead`, `opARead_some`, `opBLR`, `HdrX`, `opACSub`, `opBSt'`, `opBCSub`, `opACsAt`, `opBCsAt` | `opA` (round 0: `(λ, ρ)`) and `opB` (round 1: the proximity vector, then the indices) on the code's chain, the matrix any extraction `Ux` of the prover's log; `opB` reads `opA`'s digests off its own header with `opA`'s reader |
| `opACSub_rbr`, `opBCSub_rbr` | each round-by-round sound (L10's `opA_rbrWide`, `opB_rbrWide`, carried by `rbrWide_toCode`) |
| **`opening_split`** | deterministic: `opA`'s window at a step's end and `opB`'s window in the chain ⇒ `opA` alive at the end, or `opB` entered its window doomed (`opB`'s header state holds only when `opA`'s round is complete there, frozen, with the `(λ, ρ)` `opB` reads) |
| **`opening_knowledge_chain_pos`** | the opening accepts at the end while a claim is false of the extracted, decoded matrix: at most `(q·εA + εA + coll) + (q·εB + εB + coll)`, `εA = A/|F|·βLR`, `εB = ((N − (e + 1))/N)^Q·βJ` |
| `opB_col_w16r2_nat`, `opB_eps_w16r2`, `opA_eps_w16r2`, `opA_eps_le` | W16R2 (`N = 2^15`, `e = 8052`, `Q = 280`, `A = N`): `εB ≤ 2^-113`, `εA ≤ 2^-111` (any `A ≤ 2^15`) |
| `opB_col_r13_nat`, `opB_eps_r13` | a rate-1/4, δ/3 geometry (`N = 2^16`, `e = 16298`, `Q = 256`): `εB ≤ 2^-105` |
| `encLin_range_le`, `encLin_minDist`, `encLin_caOn`, **`w16r2_open_code_facts`** | the row encoder's words are RS words of degree `≤ n + Q − 1`, so its code has the RS distance and correlated agreement at δ/2 with `A = N` (FlashProve's `caOn_rsCode`, `CAOn.subcode`); at W16R2: `MinDist 16105`, `2·8052 < 16105`, `CAOn … 8052 2^15`, the inputs of `opening_knowledge_chain_pos` |

### 2.4 `CountW16Target.lean`: the total against the target (arithmetic)

| Theorem / definition | Statement |
|---|---|
| `u126`, `u126_add`, `u126_mono`, `u126_le_target` | `(q + 1)·c/2^126`; at most `εsTarget q` for `c ≤ 2^26` |
| `coll_le_u126`, `slots_le_u126`, `lin_le_u126`, `sched1_le_u126`, `sched3_le_u126`, `xfail_le_u126` | each term as `(q + 1)·c/2^126`: a collision term `2^14`, the slots' first term `dmax + ND`, a sub-protocol of error `2^-j` charged `q + c` times `c·2^(126−j)`, the extraction failure `2^14 + 2^16` |
| **`block_total_le_target`** | for any opening exponents `jM`, `jA`, `jB`: the block's whole sum is at most `εsTarget q` for `q < 2^100` when `3·2^(126−jM) + 2·(2^(126−jA) + 2^(126−jB)) + 2^18 + 2^16 + dmax + ND + crel + clk ≤ 2^26` |
| `block_total_le_target_w16r2` | at W16R2 (`106`, `111`, `113`): the budget is `dmax + ND + crel + clk ≤ 2^25` |

### 2.5 `OpenKnowBlock.lean`: the block's knowledge statement on acceptance

| Theorem / definition | Statement |
|---|---|
| `BlockAcc` | the slots accept (`SlotsAcc`) and `blockVerify` accepts on the same transcript |
| **`block_knowledge_acc`** | L16's `block_knowledge` on `BlockAcc`, with the per-position slots' term; `hOpen`, `hRel`, `hLk` needed only on `BlockAcc` |
| **`block_open_knowledge`** | `hOpen` on acceptance from the openings: with `hsem` and `hexec` (§5), at most `εM + εA + εH + εX`, the chain bounds and the extraction failure |
| **`block_knowledge_target`** | for ANY block shape and EVERY `q`: the block verifier accepts while the extracted planes fail `BlockSat` with probability at most `εsTarget q = q·2^-100 + 2^-100`, given the openings' chain events at their proved bounds, the extraction failure, `hsem`, `hexec`, and `hRel`, `hLk` within the budget |

## 3. The block's ε against `εsTarget`

`T = q + ℓ + 1`, `ℓ` the block's chain items (`≤ 2^20`), `|K| = p²`, `p = 2^64 − 2^32 + 1`. Each term is written as
`(q + 1)·c/2^126` (`u126`); the target is `(q + 1)·2^26/2^126`.

| Term | Bound | `c` | Status |
|---|---|---|---|
| `εsc`, the slots (per position) | `(q·5 + 924)/p²·(1 + p/2^128)² + 2 coll` at the rung | `929 + 2·2^14` | PROVED |
| `εopen`: `M` | `q·maskEps + 3·maskEps + 2 coll`, `maskEps ≤ 2^-106` | `3·2^20 + 2·2^14` | PROVED (chain bound); its link to acceptance a HYPOTHESIS (`hexec`) |
| `εopen`: `A` opening | `(q·εA + εA + 2 coll) + (q·εB + εB + 2 coll)`, `εA ≤ 2^-111`, `εB ≤ 2^-113` | `2^15 + 2^13 + 4·2^14` | PROVED (chain bound, any extraction; W16R2's code facts and numbers) |
| `εopen`: `H` opening | the same | `2^15 + 2^13 + 4·2^14` | the same |
| `εopen`: the extraction failure | `collBound T' + (2T'² + 4T')/2^256`, `T' ≤ 2^22·(q + 1)` | `2^14 + 2^16` | PROVED for any run (L16's `extract_fail_run`); its instance at the block verifier's queries is left (L16-8) |
| `εrel` (L13) and `εlk` (LogUp) | the other lanes' bounds | `crel + clk ≤ 2^25 − 929` at the rung | HYPOTHESIS (budget) |

**The total** (PROVED, `block_total_le_target_w16r2`, `block_knowledge_target`): the fixed part sums to
`3,555,328 ≤ 2^22` units (about `(q + 1)·2^-104.2`). So the block's knowledge error is at most `q·2^-100 + 2^-100` for
EVERY `q` whenever `εrel + εlk ≤ (q + 1)·(2^25 − 929)/2^126`, about `(q + 1)·2^-101`.
- **The constant term is now under `2^-100`.** With `q = 0` the openings, `M`, the slots and the extraction failure give
  about `2^-104.2` together (the bound used; the true constants are smaller: `M`'s three rounds are `3·2^-106`, the
  openings' four rounds about `2·2^-113 + 2·2^-113.9`, the slots `924/2^128 ≈ 2^-118`). L16's count gave about
  `2^-82.6`.
- **The per-query rate** of the proved part is about `2^-106 + 2·(2^-113 + 2^-113.9) + 5/2^128 ≈ 2^-105.9` (ESTIMATE
  from the proved bounds), leaving room for LogUp's `2^-102.9` within the target's `2^-100`.
- **LogUp needs the per-position count too.** With L8's count, LogUp's own constant would be `(ℓ + 1)·2^-102.9 ≈
  2^-82.9`, alone above the target. L21 must bound `hLk` with `fs_code_chain_sound_sched_log_pos` (finding L20-5).
- **An R13 geometry** (rate 1/4 at the δ/3 radius, `N = 2^16`, `Q = 256`; to be confirmed by L17): `opB ≤ 2^-105`
  (PROVED, `opB_eps_r13`), `opA ≤ 2^-111` (`opA_eps_le` with `A = e + 1 = 16299`). Then the fixed part is
  `3·2^20 + 2·(2^15 + 2^21) + 2^18 + 2^16 ≈ 7.7·10^6 ≤ 2^23` and the budget left for the slots, L13 and LogUp is
  about `2^25.8` units (`block_total_le_target` with `jB = 105`): met with the same LogUp.

## 4. Findings

No mismatch with the approved statements; no statement or target weakened. `Statements.lean` unchanged.

**L20-1 (Low; interface, fixed here): L16's `hOpen` cannot be discharged as stated.**
- `block_knowledge`'s `hOpen` bounds "the slots accept (`SlotsAcc`) and some claim handed to an opening, or some `M`
  functional, is false of the extracted data". The slots do not check the openings, so a prover can make them accept
  with false opening claims and then fail the openings: that event can have probability near `1`.
- The knowledge statement needs the BLOCK VERIFIER's acceptance (`BlockAcc`: the slots, `M` and both openings), and
  there `hOpen` is a sum of the openings' chain bounds (`block_open_knowledge`).
- `block_knowledge_acc` is `block_knowledge` on `BlockAcc`. Its conclusion is about the event the receipt's
  acceptance produces. Its hypotheses `hRel`, `hLk` are needed only on `BlockAcc`, so they are WEAKER than L16's: L21's
  bounds on the slots-only event apply as they are.

**L20-2 (Info): the per-position charge is a potential, so no read-back of the verifier's chain is needed.**
- `FSPathWide.lean`'s `chain_sound_wide_seq` charges the verifier's step its own error `e τ it`, a function of the chain
  before it. Here `e` is `chargeC`: the errors of the sub-protocols whose round the step starts.
- The bound on the verifier's whole charge (`hB`) is a potential argument (`potS`: the rounds a sub-protocol still owes),
  valid for every chain. So the charge is `Σ_c n_c·ε_c` (rounds times error), independent of `ℓ`.
- The prover's `q` queries keep the largest error `εmax`, as they must.

**L20-3 (Low): what remains of `hOpen` is deterministic.**
- `block_open_knowledge` reduces `hOpen` (on `BlockAcc`) to the proved chain bounds plus two deterministic links. The
  links involve no probability:
  - **`hexec`, the executable link**: on acceptance with every opened column equal to the extracted one, each
    opening's chain event holds unless its good predicate does. It needs three things:
    (a) the verifier's items at `M`'s, `opA`'s and `opB`'s windows are those sub-protocols' rounds under a step parse
    `W` whose wide rounds' first squeezes are step heads (`M`'s `2S + 2` and `64`, `opA`'s `#claims + rows`, `opB`'s
    `⌈Q/4⌉`). The counters are fixed only if the header's squeeze count is (L16-2; true for a run's fixed header);
    (b) L10's `MaskOk` / `PcsOk` read in `K` (`mcol_iff_K`, `sum_iff_K`, `toK_combinedWeights`, `colEq_iff_K`,
    `opening_columns_K`) at the opened columns, equal to the extracted ones, are `MFinal` / `GroupsAccept` on the
    extracted data;
    (c) the digests read by `chalTheta` / `chalRows` / `lrCode` / `idxCode` (halves) are the executable's
    `challengeFp2` / `challengeFp2Vec` / `challengeIndices`.
  - **`hsem`, the claims' index map**: `GroupsGood` / `MGood` of the extracted data make every claim in `acc.claims.a`,
    `acc.claims.h` and every `M` functional true (`groupsGood_claims`, `mGood_val_eq_true` give the per-claim facts;
    what is left is the map from the executable's `ZClaim` / `MaskFunctional` lists to the `OClaims` / `MData`
    indices, `zpartWeights`, `combinedWeights`).
- The endpoint claims (`Cm.inp`, `Cm.out`) are the run's (L16-5): `hsem` must cover them with the run's boundary and
  endpoint openings, or the block statement is used with them as run-level premises.

**L20-4 (Info; closed here): W16R2's opening code facts.** `opening_knowledge_chain_pos` takes the code facts
(`MinDist (range enc) d`, `2e < d`, `CAOn Unit (range enc) e A`) as hypotheses; for L10's row encoder `encLin` they are
PROVED (`w16r2_open_code_facts`). The encoder's range is inside `rsCode dom (n + Q − 1)` (`encLin_range_le`), so it
has the RS distance (`MinDist.anti`), and correlated agreement passes to the subcode (`CAOn.subcode`). At W16R2,
`2e + K + 1 = 16104 + 16663 + 1 = 2^15`: the unique-decoding radius is used exactly.

**L20-5 (Info, for L21): LogUp and L13's relations must use the per-position count.** The budget left for `εrel + εlk` is
`(q + 1)·(2^25 − dmax − blockND)/2^126 ≈ (q + 1)·2^-101`. LogUp's `α` at about `2^-102.9` per query fits it only when
the verifier's positions are charged per round. `fs_code_chain_sound_sched_log_pos` is generic (any sub-protocols,
any log-reading states, any step parse) for that purpose.

**L20-6 (Info): every theorem is per block shape (A25).** The chain theorems take any schedule; the slots' theorem any
`BlockParams`; the openings' theorem any encoder, geometry and extraction; the target theorem any opening exponents.
W16R2's rung (`blockND = 924`) and its opening geometry (`106`, `111`, `113`) are instances; an R13 geometry is §3.

## 5. What is left

1. **`hexec`** (L20-3): the openings' and `M`'s rounds read off the verifier's own transcript at fixed windows (the
   block's chain of `blockOps` followed by `M`'s, `A`'s and `H`'s operations), with the field links (b) and the
   challenge links (c). The probability part is done.
2. **`hsem`** (L20-3): the index map of the claims and functionals to the openings' `OClaims` / `MData`, and the
   endpoint claims at the run level (L16-5).
3. **The extraction failure at the block verifier's queries** (L16-8): `extract_fail_run` needs the verifier's chain
   and Merkle checks as an `OC` (`chainOC`, `checkAll`).
4. **`hRel`, `hLk` under the per-position count, within the budget** (L21; L20-5).
5. **The run level**: `run_blocks_union` (each block its own shape) and the D55 tree (F31) with the per-position count.

## 6. Checks

All in `results/zk60_lean_l20_20261107/`, each run as one job through the zk60 resource guard (class `cpu`,
`run_guarded.py`). The build cache was cloned from the main checkout (L13 to L15 built), so only L16's and this lane's
modules were rebuilt.
- `iter1.log` … `iter7.log` (`stage.sh`, the modules built one target at a time): the five files while they were
  written. The errors fixed on the way are in those logs: `add_le_add_left`/`_right`'s argument order; deprecated
  `if_pos`/`if_neg` (now `ite_eq_left`/`ite_eq_right`); a `whnf` timeout in the first form of
  `fs_code_chain_ever_log_pos`, removed by stating its premises as separate `have`s; a `dsimp` with no progress; a
  `simp` reaching the recursion limit on `fibC`'s literal (replaced by `Nat.cast` rewrites); `Code`'s namespace for
  `MinDist`, `CAOn`; a missing parenthesis; `ring` with a `2^270` literal above the exponent threshold (rewritten with
  products); an `omega` recursion limit (replaced by an explicit `calc`); unused section instances (`omit … in`).
  Peak RSS 3.7–6.8 GiB, each 19–43 s once admitted. Waiting for admission dominated: up to 108 minutes per job behind
  the other lanes' and A26's GPU jobs.
- **`check.log`** (`check_l20.sh`, job `lean-l20-check`, exit 0, 76 s, peak RSS 3.66 GiB):
  - the five L20 modules built one target at a time (14 s), then the full build (`full.log`): **3,512 jobs, rc 0,
    0 warnings, 0 errors, no `sorry`**; 0 warnings in the L20 files;
  - the axiom audit (`axioms_l20.lean`, written by `gen_axioms.py`, → `axioms.log`): **60 theorems**, 55 on
    `[propext, Classical.choice, Quot.sound]`, 3 on `[propext, Quot.sound]`, 2 on `[propext]`; `sorryAx` and
    `Lean.ofReduceBool` nowhere;
  - the source scan of the five L20 files (`sorry`, `axiom`, `native_decide`, `admit`, `maxRecDepth`,
    `maxHeartbeats`, `implemented_by`, `extern`, `bv_decide`, `ofReduceBool`): none; the root imports all five;
  - the regressions: **L6Check 1,206 checks, 0 failed**; **L5Check 5,553 checks, 0 failed**; **L11Check 404 checks,
    0 failed** (L11's committed W16R2 rung corpus); **the fixture L1 check 101,956 checks, 0 failed**.
- No agreement corpus is new: every L20 theorem is about L8's, L9's, L10's and L16's definitions, whose agreement with
  the Rust verifier their lanes established; L20 adds no executable code.
