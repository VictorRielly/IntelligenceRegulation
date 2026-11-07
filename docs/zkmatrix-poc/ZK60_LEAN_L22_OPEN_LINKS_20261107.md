# D63 lane L22: the openings' deterministic links (`hexec`, `hsem`) and the extraction failure at the verifier (2026-11-07)

Lean lane L22 (Claude), on its own worktree fast-forwarded to perf at `c25c9944` (L9 to L17 and L20 merged). Lean
4.34.1, Mathlib v4.34.1, no new dependency. Six new library files under `formal/ZK60Formal/`, imported by the library
root: `LinkW16Parse.lean`, `LinkW16Trace.lean`, `LinkW16Mask.lean`, `LinkW16MaskChain.lean`, `LinkW16Sem.lean`,
`ExtractInstW16.lean`. No Rust and no production source changed. `Statements.lean` and every existing Lean file are
unchanged. Evidence: `results/zk60_lean_l22_20261107/`.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms at most `propext`, `Classical.choice`, `Quot.sound`),
**HYPOTHESIS** (a named premise, with the shape a later lane must prove), **LEFT** (not done).

## 1. In plain words, for Victor

**What this lane was asked.** L20 reduced the openings' part of a block's knowledge statement (`hOpen`) to proved
probability bounds plus two DETERMINISTIC links: `hexec` ("when the block verifier accepts, each opening's and `M`'s
rounds, read off the verifier's own transcript, are alive at the end") and `hsem` ("when the extracted data passes the
openings' good tests, every claim and every `M` functional is true of it"). It also left the extraction failure's
instance at the verifier's real queries (L16-8). The lane was to prove all three and assemble `hOpen`.

**What is now proved.**
1. **The verifier's transcript is the chain the theorems read.** The FS theorems read a sub-protocol's rounds off an
   abstract chain built from "step heads" with a width rule `W`. PROVED: for the block verifier's real operations, that
   chain IS the executable transcript's trace, for every hash function, once `W` gives each challenge vector its width
   at its first squeeze counter (`cChain_stps`). The accepting block verifier's whole run is exactly: the header, the
   roots and slots, `M`'s five steps, `A`'s and `H`'s steps (`blockVerify_run_w16r2`); every challenge the code draws is a
   function of the trace's digests (`challengeFp2Vec_sqDs`, `challengeIndices_sqDs`, `idxCode_sqDs`).
2. **`M` is fully linked.** PROVED (`mask_subSt_of_ok`): if `M`'s executable check accepted, and the extracted mask
   table agrees with the opened columns at the sampled indices, then `M`'s window is at a step's end and `M` is alive at
   the end of the chain, with the code's own `θ`, row coefficients and indices. The field link (`maskOk_mFinal`) reads
   the code's sum, product and proximity checks as the soundness model's `MFinal`.
3. **The extraction failure at the verifier is a theorem.** PROVED (`extract_fail_block_w16r2`, `_r13`): the chance that
   some opened column of `A`, `H` or `M` verifies but differs from the column extracted from the prover's log is at most
   `(q + 1)·(2^14 + 2^16)/2^126`, the figure L20's budget already counts. Outside that event every accepted opened
   column IS the extracted one (`opened_eq_extracted`).
4. **The claims' meaning (`hsem`) is proved in L21's `OpenTrue` form for `M`, `A` and `H`.** `M`'s good case makes EVERY
   functional it received true, the hosts' ones included (`mGood_mTrue`, L21-2); an opening's good case makes EVERY
   claim of its list true of the decoded matrix, `H`'s LogUp sum claim included (`groupsGood_claimSem`, L21-3).

**What is not done** (§5). Three things stay, all deterministic or bookkeeping:
- the regular opening's field link (the `A`/`H` analogue of item 2: the code's `pcs` checks read as the model's
  `GroupsAccept`), which needs the claims' grouping map of item 4 carried through the batching;
- the header readers: the sub-protocols' statements must be functions of the transcript prefix, so the functionals and
  the claims the verifier computed must be re-read from the trace (L9 did this for the slots' claims);
- the probability glue: plugging the concrete chain into L20's two chain theorems, and citing L21's
  `block_knowledge_target_mt`.

**One finding needs a decision (L22-1, Medium).** The width rule `W` is a function of the squeeze COUNTER, so the
openings' parse is fixed only if the number of squeezes before them is. L9's model lets the prover choose the block
header, so for a header with another squeeze count L20's `hexec` is false as stated. In the real run the header is the
verifier's (the run statement), so the knowledge statement should be read on blocks whose header has the run's squeeze
count. This is a scoping of the model, not a weakness of the protocol (§4).

## 2. What is proved

138 theorems (`LinkW16Parse` 32, `LinkW16Trace` 43, `LinkW16Mask` 20, `LinkW16MaskChain` 16, `LinkW16Sem` 11,
`ExtractInstW16` 16), every one on at most `propext`, `Classical.choice`, `Quot.sound` (§6). No `sorry`, `native_decide`,
`maxHeartbeats` or similar. The main ones are named below.

### 2.1 `LinkW16Parse.lean`: the step parse, made concrete (generic)

| Theorem / definition | Statement |
|---|---|
| `Stp`, `stpsOps`, `stpHeads`, `StpOK` | the operations as steps (one absorb, or a run of `n` squeezes), their heads with the code's counters, the widths agreeing with the runs |
| `u64_add_*`, `opItems_replicate`, `opsCtr_replicate`, `opsCtr_stpsOps`, `StpOK.append`, `stpHeads_mem` | counters of runs |
| `stepsB_items_sq`, `stepsB_items_ab`, **`flatMap_stpHeads`** | the heads expanded by `stepsB` are the code's items |
| **`cChain_stps`** | `cChain (chainEncB) (stepsB W) G (heads)` = `opTrace (liftH G) (Tr.newKeyed …) ops`, for every `G` |
| **`tRem_opTrace_stps`** | the trace of whole steps parses as whole steps |
| `cRd_run_sq`, `cRdStep_absorb_msg` | the scheduled reader takes a run as one round and an absorb under the round's label as its message |
| `sqDs`, **`challengeFp2Vec_sqDs`**, **`challengeIndices_sqDs`**, `idxLoop_sqDs` | the code's vector challenges and indices are functions of the run's digests |

### 2.2 `LinkW16Trace.lean`: the block verifier's run as steps

| Theorem / definition | Statement |
|---|---|
| `sqN`, `opsStps`, `stpOK_opsStps` | single steps parse under widths `1` |
| `wRuns`, `wRuns_pos`, `wRuns_le`, `wRuns_lt`, **`wRuns_at`** | the step parse of the wide runs from a fixed counter |
| `fullLen`, `fullSq`, `shapeLen`, `shapeSq`, `fullOps_length`, `fullOps_sq`, `full_shape` | window positions and counters from the shape |
| `slotsLoop_tr`, **`blockSlots_tr`** | an accepting slot phase ends at `runOps` of its operations |
| `mPre`, `mStps`, `vecStps`, `pcsPre`, `pcsStps`, `vStps` | `M`'s and an opening's steps; the whole run |
| `zkRhos_sqDs`, **`maskTranscript_runOps`**, **`pcsTranscript_runOps`** | L9's transcript schedules are `runOps` of the steps; challenges from the digests |
| **`groupZclaims_count`** | `group_zclaims` holds every claim once (the `(λ, ρ)` vector is `#claims + rows` wide) |
| **`blockVerify_ok`** | an accepting `verify_core`, decomposed: slots, functional count, `M`, `A`, `H` |

### 2.3 `LinkW16Mask.lean`, `LinkW16MaskChain.lean`: `M`, fully linked

| Theorem / definition | Statement |
|---|---|
| `mEtaE`, `mOmega`, `mDataOf` | `M`'s points, root, and the data its sub-protocol states |
| `comb_La`, `comb_Lb`, `mV_cw`, `mW_cw` | the combinations and `combined_weights` in `K` |
| **`maskOk_mFinal`** | `MaskOk` and the table agreeing with the opened columns ⇒ `MFinal` at the transcript's challenges |
| `leNat_append`, `chunks_halves`, `chunk_eq`, **`idxCode_sqDs`** | the code's indices are `idxCode` of the digests' halves |
| **`cRd_mStps`** | the reader reads `M`'s three rounds off the trace |
| **`mask_subSt_of_ok`** | `M`'s window at a step's end and `M` alive at the end of the chain (`hexec` for `M`) |
| **`blockVerify_mask`**, **`blockVerify_run_w16r2`** | with L10's fields, an accepting block verifier gives `MaskOk` at the slots' end and its whole run as `vStps` |

### 2.4 `LinkW16Sem.lean`: the claims' index map (`hsem`)

| Theorem / definition | Statement |
|---|---|
| `mRhOf`, `msOfTab`, **`mGood_mTrue`** | `M`'s semantics; `MGood` ⇒ every functional `M` received is true (hosts included) |
| `claimRw`, `claimCw`, `claimSem`, `memsOf`, `oclOf` | a claim's weights and value; the members in the code's draw order; the opening's `OClaims` by draw position |
| `GInv`, `gInv_step`, `gInv_foldl`, **`groupZclaims_mem`** | `group_zclaims`' invariant: each claim is a member of its key's group, whose column weights are its key's |
| **`groupsGood_claimSem`** | `GroupsGood` of `oclOf` ⇒ every claim of the list is true of the decoded matrix |

### 2.5 `ExtractInstW16.lean`: the extraction failure at the verifier (L16-8)

| Theorem / definition | Statement |
|---|---|
| `ColV`, `merkleEncV`, `climbV_eq`, **`opensV_of_exec`** | one Merkle encoding for `A`, `H`, `M`; the executable check is `Opens` |
| `colsV`, `blockV`, `blockV_bounded`, `blockV_queries_*` | the verifier's Merkle work as an oracle computation |
| `rootsV`, `EvXB`, **`extract_fail_block`** | the extraction failure at the verifier's queries: `collBound T' + (2T'² + 4T')/2^256` |
| **`opened_eq_extracted`** | outside it, every accepted opened column is the extracted one |
| `rootAt`, `colX`, `colX_root`, **`colX_stable`** | the extracted column read off the chain; frozen once the chain prefix is logged |
| **`extract_fail_block_w16r2`**, `extract_fail_block_r13` | at W16R2 (`T' = q + 13,104`) and R13 (`q + 12,800`): `≤ (q + 1)·(2^14 + 2^16)/2^126` |

## 3. Which premises of `block_knowledge_target(_mt)` remain

| Premise | Status |
|---|---|
| `hM` (`M`'s chain bound) | PROVED by L20 for any chain; this lane supplies the chain (`cChain_stps`), the parse (`wRuns`), the stability (`colX_stable`); the instantiation (heads, `hℓ`, `hhd`) is LEFT (§5 item 3) |
| `hEA`, `hEH` (the openings' chain bounds) | the same |
| `hX` (the extraction failure) | PROVED at the verifier's queries (`extract_fail_block_w16r2`, `_r13`) |
| `hexec`, `M` part | PROVED (`mask_subSt_of_ok`, `blockVerify_mask`), given the header reader (§5 item 2) and the header's squeeze count (L22-1) |
| `hexec`, `A`/`H` parts | LEFT: the field link `PcsOk ⇒ GroupsAccept` of `oclOf` (§5 item 1) |
| `hsem` (`OpenTrue` form) | PROVED for `M`, `A`, `H` (`mGood_mTrue`, `groupsGood_claimSem`), given the readers; the endpoint claims stay a run-level premise (L22-5) |
| `hRel`, `hLk` | L21's (merged into perf) |

## 4. Findings

No statement of `Statements.lean` changed, no target weakened. One model scoping (L22-1) needs a decision.

**L22-1 (Medium; model scoping): the openings' step parse needs the header's squeeze count fixed, and L20's `hexec` is
false without it.**
- The chain theorems read a sub-protocol's wide rounds (`M`'s `2S + 2` row coefficients and `64` index squeezes, an
  opening's `#claims + rows` batching squeezes and `70` index squeezes) through a FIXED width rule `W`, a function of
  the squeeze COUNTER (L8-3, L16-2). The counter at `M`'s window is `hdrSq + 3 + Σ_k (draws_k + 1 + n_k + e_k)`, so it
  is fixed only if the header's squeeze count `hdrSq` is.
- L9's `BlockWin` / L20's `BlockAcc` let the prover output ANY header of `hdrLen` operations. For a header with a
  different squeeze count, every counter after it moves, the fixed `W` mis-parses `M`'s and the openings' rounds, the
  reader leaves the schedule, and neither the good predicate nor the chain event need hold: `hexec` (`∀ G, BlockAcc →
  ¬EvX → (GA ∨ EvA) ∧ …`) is not provable as stated. A union over all possible `hdrSq` would cost a factor
  `hdrLen + 1 ≈ 2^19`, far outside the target.
- In the real run the header is the verifier's (the D55 run statement, fixed squeeze count), so the faithful statement
  is on `BlockAcc ∧ sqN header = hdrSq`. With it, `W = wRuns c_M [1, 2S + 2, 64, w0A, 70, w0H, 70]` parses the whole
  run (`stpOK_opsStps`, `wRuns_at`, `wRuns_lt`). Two equivalent ways to carry it: add the condition to the event, or wrap
  the prover (`A'` outputs a header of the wrong length when the squeeze count differs, so `BlockAcc` fails there; `A'`
  makes the same queries, so `block_knowledge_target_mt` applies to `A'` unchanged). Not a protocol weakness.

**L22-2 (Low): the `(λ, ρ)` width needs the claims' count fixed.** `opA`'s round draws `w0 = #claims + rows` squeezes
(`zkRhos_sqDs`, `groupZclaims_count`), and `opARounds w0` is fixed in the sub-protocol. So `#acc.claims.a` and
`#acc.claims.h + 1` must be fixed by the profile (each slot's private tables' commitments fixed by the schedule). A
premise of the instance, to be proved from L13's builders.

**L22-3 (Info): the openings' `OClaims` must be indexed by DRAW position.** `group_zclaims` groups the claims by key and
`zk_rhos` draws `λ` group by group (`memsOf`). Which claims share a group depends on the claims' keys (challenge-derived
points), so with claims indexed by list position the draw-order permutation `eLR` would vary with the transcript, while
`opACSub`'s `chalLR` is fixed. `oclOf` indexes by draw position (the `λ` vector then reads straight off the run), with
`G := ℕ` (only `DecidableEq` is needed). `groupsGood_claimSem` shows this indexing still makes every claim of the list
true.

**L22-4 (Info): one extraction event for three commitments.** `A`, `H` and `M` have different row counts, so L10's
`merkleEncB` gives three Merkle encodings and `extract_fail_run` would be applied three times. `merkleEncV` (columns of
at most `L/8` words) is one encoding for all three, so the extraction failure is ONE event with `nr = 3` roots, at L20's
`2^14 + 2^16` units.

**L22-5 (Info, the boundary): the endpoint claims are not the block's.** L21's `OpenTrue` contains
`ClaimsTrue … acc.claims`, which includes `acc.claims.inp` and `acc.claims.out`. The block verifier does not open them
(they are returned as the IO claims, L16-5). So `block_knowledge_target_mt`'s `hsem` holds only together with the
endpoint claims' truth: the block statement must carry `prH(BlockAcc ∧ ¬ endpoint claims true) ≤ εend` as a run-level
premise (the boundary and endpoint openings, L12), split off `hOpen` before `block_open_knowledge` is applied. The
`A`/`H`/`M` part of `OpenTrue`, `H`'s LogUp sum claim and the hosts' functionals included, is what `mGood_mTrue` and
`groupsGood_claimSem` give.

**L22-6 (Info): `L` must cover the longest absorb.** `cChain_stps` needs every operation within `L` bytes. The group
vectors' absorbs are `48 + 7 + 16·(2^14 + 280) = 266,935` bytes at W16R2, so `L ≥ 2^19`. `L` only sets the oracle's
domain; no bound depends on it.

**L22-7 (Low): the header readers.** The chain theorems' statements are functions of the chain prefix (`Dm hdr`,
`clOf hdr`), while the verifier computes the functionals and claims from the core and the hash. A reader of the trace
(the slots' round messages, terms and challenges, as L9's `tSeen` reads the claimed sums), with its correctness on the
verifier's own accepting trace, is the remaining deterministic link. `mask_subSt_of_ok` takes it as `hDm`.

**Independent of L23-1 (`slotAcc`'s host weights).** No theorem here unfolds `slotAcc`. Each takes `acc.fs ++
acc.hostFs` as the verifier computes it, so it holds with the corrected weights unchanged. `ExecBlockVerify.lean` is
not modified on this branch.

## 5. What is left

1. **The regular opening's field link** (the `A`/`H` analogue of `maskOk_mFinal`): L10's `PcsOk` at the opened columns,
   with the extracted matrix agreeing with them (`opened_eq_extracted`), is `GroupsAccept` of `oclOf` at `lrCode` and
   `idxCode` of the run's digests. Needed: `zkRhosAux` in `K` (each group's `ρ_g` and want as `groupWeights` /
   `groupWant` of `oclOf` in the draw order of `memsOf`), the group check (`dotF` of the first `n` entries is `⟨v, cw⟩`
   with the pads weighing `0`), and `opening_columns_K` with `encLin_apply` (the column is `comb` of the matrix). Then
   `opB`'s reader (`cRd (opBRounds labPcsProx 70)` at `pcsPre`'s end, as `cRd_mStps`) gives `subSt W (opBCSub …)`.
2. **The header readers** (L22-7): `fsRd` and `clRd` with `fsRd (chain.take aM) = acc.fs ++ acc.hostFs` and
   `clRd (chain.take aA) = acc.claims.a` on the verifier's accepting trace (or a determinism lemma, "`blockSlots`'
   accumulator is a function of its trace", and a `Classical.choose` reader).
3. **The probability glue.** Instantiate `mask_knowledge_chain_pos` and `opening_knowledge_chain_pos` (×2) with
   `C = chainEncB`, `St = stepsB L W`, `W = wRuns`, `heads o = liftItems L (stpHeads 0 (vStps …))` on outputs of the
   shape (else `[]`). `hℓ` is `flatMap_stpHeads` with the shape's op count. `hhd` needs the header's and roots' heads to
   be single items (`stpOK_opsStps`). `hstab` is `colX_stable` (the functionals' reader does not read the log). Then
   `hexec` for `M` is `cChain_stps` + `blockVerify_mask` + `opened_eq_extracted` + `mask_subSt_of_ok`, and
   `block_knowledge_target_mt` applies to the wrapped prover of L22-1, with the endpoint term of L22-5 added to `hOpen`.
4. **R13.** Everything here is per block shape. At R13, `M`'s field is L10's `maskField` (so `blockVerify_mask` and
   `mask_subSt_of_ok` apply as they are), the opening is `pcsFieldR13` (`pcsFieldR13_transcript`; `Q = 256` gives `64`
   index squeezes, `nn = 2^16`), and the extraction failure is `extract_fail_block_r13`. The R13 analogue of
   `blockVerify_run_w16r2` is the same proof with `pcsFieldR13_transcript`. Item 1 at R13 uses L17's `r13OpenCheck`.

## 6. Checks

All in `results/zk60_lean_l22_20261107/`, each run as one job through the zk60 resource guard (class `cpu`,
`run_guarded.py`, need 14 GiB, cap 24 GiB). The build cache was cloned from L20's worktree (L9 to L16 and L20 built), with
L17's R13 modules copied from the main checkout. So only L17's root and this lane's modules were rebuilt (`warm.log`:
3463 jobs, 28 s).
- `iter1.log` … `iter12.log` (`stage.sh`): the six files while they were written. The errors fixed along the way are in
  those logs:
  - `simp` normal forms (`UInt64.ofNat (j + 1)`, `List.getD` to `getElem?`);
  - recursive calls missing a theorem's own parameter;
  - `rfl` blocked by `List.append` with a symbolic `replicate` (`stpsOps_singleton`);
  - `verify_core`'s do-block compiled to join points (`blockVerify_ok` by `split`);
  - `unfold` reaching inside a fold (`groupStep` by cases on `keyIdx`);
  - two missing core lemmas (`getD_map'`, `getD_append'`);
  - a missing import (`ExecOpeningBlock`);
  - `subst` direction, and a field projection `(maskCSubX …).a` left unreduced (`show`).

  Peak RSS 3.7–6.7 GiB, each 3–28 s once admitted. Waiting for admission dominated: up to 139 minutes per job behind A27's GPU
  job.
- `l22_scratch1.lean` (not part of the library): `verify_core`'s elaborated shape after the slot phase, printed by
  `fail`.
- **`check.log`** (`check_l22.sh`, job `lean-l22-check`, exit 0, 73 s, peak RSS 6.66 GiB):
  - the six L22 modules built one target at a time, then the full build (`full.log`): **3,523 jobs, rc 0, 0 warnings,
    0 errors, no `sorry`**; 0 warnings in the L22 files;
  - the axiom audit (`axioms_l22.lean`, written by `gen_axioms.py`, → `axioms.log`): **138 theorems**:
    - 57 on `[propext, Classical.choice, Quot.sound]`;
    - 43 on `[propext, Quot.sound]`;
    - 29 on `[propext]`;
    - 9 on none.

    `sorryAx` and `Lean.ofReduceBool` appear nowhere;
  - the source scan of the six L22 files (`sorry`, `axiom`, `native_decide`, `admit`, `maxRecDepth`,
    `maxHeartbeats`, `implemented_by`, `extern`, `bv_decide`, `ofReduceBool`): none. The root imports all six;
  - the regressions:
    - **L6Check 1,206 checks, 0 failed**;
    - **L5Check 5,553 checks, 0 failed**;
    - **L11Check 404 checks, 0 failed**;
    - **the fixture L1 check 101,956 checks, 0 failed**.
- No agreement corpus is new. Every theorem is about L5's, L6's, L9's, L10's, L16's and L20's executable definitions,
  whose agreement with the Rust verifier those lanes established; L22 adds no executable verifier code.
