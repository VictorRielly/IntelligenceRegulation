# D63 lane L47: the block's lookup side and SC_TAB at W16R2, and SC_TAB at R13 (2026-11-10)

Lean lane L47 (Claude Opus 5.5), on its own worktree, after perf `31af9ac1` (L44 merged). Lean 4.34.1, Mathlib
v4.34.1, no new dependency. Eighteen new library files under `formal/ZK60Formal/` (`BlockTab*`, `BlockLook*`,
`BlockR13Join*`), imported by the library root; two agreement checkers (`BlockTabExportCheck.lean`,
`BlockHostExportCheck.lean`, each with a `main`, not imported); one test-only Rust file
(`hashline/src/lean_l47_export_tests.rs`, declared by one test-only line in `private_block/w16r2_tests.rs`).
`Statements.lean` and every existing Lean file are unchanged; no production Rust source changed. Evidence:
`results/zk60_lean_l47_20261110/`. The work was split across four forks of the lane (A: `SC_TAB`'s identity, at W16R2
then at R13; B: the cover; C: LogUp's helper relations; D: the checks against the code); their iterations are `tab_*`,
`r13_*`, `cov_*`, `rel_*`, `exp_*`.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms at most `propext`, `Classical.choice`, `Quot.sound`),
**CHECKED** (an executable comparison with the code on a real receipt, with a negative control), **MEASURED** (read off
the code or a corpus), **ESTIMATE** (arithmetic on measured counts, not a Lean theorem), **ARGUED** (a reasoned claim,
not a Lean theorem), **LEFT** (not done).

## 1. In plain words, for Victor

**What was asked.** The security statement of one transformer block ("the block verifier accepts while the committed
data breaks the block's equations with probability at most the target plus the endpoint term") still rested, at the
W16R2 test rung, on assumptions about the block itself: the table slot `SC_TAB`, and the whole lookup side (every
looked-up value is in its table). This lane was to prove those, check the lookup side's public tables against the real
code by value, state the block's theorem with no block-level assumption left, and carry the same to R13 and the app's
Shieldstral block as far as possible.

**What is now proved or checked.**
1. **`SC_TAB`'s identity at W16R2** (PROVED): the table slot's polynomial, summed over the cube, is exactly the formula
   the algebra needs (17 table relations `h·(α − t) − m`, 22 padding planes, degree 24).
2. **The lookup side at W16R2 is built and proved** (PROVED). The looked-up tuples are read off the committed `A`
   matrix exactly as the code lists them (1,064,960 lookups: 475,136 pairs and 114,688 singles, with the exp and ACT
   tuples); the table is the code's 17 columns of 16,384 entries (bytes, exp, ACT, 14 range sub-planes), and every entry
   is a real table entry; every lookup the block's equations ask for is in the list; and LogUp's helper columns satisfy
   their relations and their sum, from what the verifier checks. A gap in the earlier interface was closed on the way
   (finding L47-2): the lookups must be fixed before the challenges, and the Lean model read them from data that also
   depends on a later root; this lane proves that for a fixed prover the earlier data determines that root.
3. **The public tables are checked against the code by value** (CHECKED): on a real W16R2 rung receipt, every public
   table of the lookup side (29 tables, 475,136 entries) and every host table L44 built (20 tables, 283,136 entries)
   equals the Lean definition entry for entry; so do the code's slot kinds and its LogUp sum claim. Every deliberate
   change (19, 37) is caught. This closes L44-E2.
4. **The W16R2 rung block's theorem with every block-level premise gone** (PROVED,
   `block_knowledge_look_w16r2_rung`). What is left: run-level premises (as before), "the verifier is the code's"
   (CHECKED facts), and public data with its validity (§4).
5. **R13** (item 4, part): `SC_TAB`'s identity is PROVED at the R13 rung and at every one of the 26 Shieldstral layers
   of the app's model, and R13's lookup-side tables are CHECKED against the code at the R13 rung. The rest of R13 (the
   hosts, the extraction, the lookup side) needs the R13 counterpart of lanes L41 and L44 first (§4.2).

**Findings that need a decision.** None needs a ruling on the statements. L47-1 (Medium): the profile structure
`IsRungW16` does not pin the LogUp sum claim or three slot kinds; they are now named verifier premises, CHECKED. L47-4
(Low): an earlier lane's lookup count omits two tuple lookups; at the app's block the corrected count still fits the
bound, with a smaller margin (ESTIMATE).

## 2. What is proved

Every theorem below is on at most `propext`, `Classical.choice`, `Quot.sound` (§6).

### 2.1 `SC_TAB` at W16R2 (deliverable 1): `BlockTabBase.lean`, `BlockTabSlot.lean`, `BlockTabForm.lean`

| Theorem / definition | Statement |
|---|---|
| `tabTupE`, `tabTupW` | the code's table tuple of column `k` at position `i`: bytes `(i mod 256, TAG_U8)`, exp `(i mod 256, TAG_EXP, exp)`, ACT `(gate, TAG_ACT, act, group)` (padding: group 0's row at 2048), range sub-plane `j` `(s·2^14 + i mod support, TAG_RANGE0 + w)` |
| `foldWd`, **`toK_foldWd`** | the fold `x + γ·tag + β·y + β²·z` in the code's word arithmetic; read in the field it is `fold β γ (tupK u)` (no canonicity premise) |
| `gateLW`, `gateTabW`, **`restE` / `restW16`** | the lookup side's public tables (`rest` of `pubsW16 B rest`): `supp(Dom::L)`, `SC_TAB`'s 17 folded value columns and 10 gates, `SC_ZS`'s ones; `rest3_getD`, `rest19_getD`, `rest19_gate_getD`, `rest20_getD` |
| `cTabW`, `wTabW`, **`spTabW`**, `spTabW_dg`, `spTabW_Gd` | `SC_TAB`'s 17 relations, 22 pad planes, certified polynomial (L23's `SlotPoly.zc`, degree 24) |
| `slot19_eq`, `grp19_flat`, `tab_vals_*`, **`tab_cube`** | slot 19 of the program as explicit data (by `rfl`), its value list at a cube point, its cube sum |
| **`tab_formAt`**, **`hTform_w16`**, **`hTdeg_w16`** | `SC_TAB`'s named identity (`FormAt` at 19); L44's `hTform` and `hTdeg` word for word |

### 2.2 The lookup side at W16R2 (deliverable 2): `BlockLookBase.lean`, `BlockLookEntry.lean`, `BlockLookCov*.lean`, `BlockLookRel*.lean`, `BlockLookSum.lean`

| Theorem / definition | Statement |
|---|---|
| `ocNext`, `ocNext_runLog`, `rootOfCut`, **`rootOfCut_cutsOf`** | for a fixed prover, the `A` root the extraction reads is a function of the `A` cut (finding L47-2) |
| `dofA`, **`dofA_aPl`** | the data the `A` cut fixes; on every outcome its `A` planes are the real ones |
| `SgIx`, `PrIx`, `TbIx`; `lkTupW`, `lkAtW`, `expTupW`, `actTupW`, `sgTupW` | the index sets (singles, pairs, table positions) and the looked-up tuples, read off `A` at the code's offsets |
| **`AlkW`, `TW`, `mlkW`** | lane L36's `Alk`, `T`, `mlk` |
| `card_sgIx`, `card_prIx`, `card_tbIx`, **`hN_w16`**, **`he_w16`** | 114,688 singles, 475,136 pairs, 278,528 table positions; `hN`, `he` |
| `famsW`, `famsW_ok`, `w16Widths_famsW`, `tabTupW_code`, **`hTtab_w16`** | the table's families (`FamsOK`, `W16Widths` from `RungS`); every table entry is a tuple of `CodeTable` (`hTtab`), given `0 < nG` |
| `planeZ_one`, `aPl_entry`, `aPl_flat` | a committed plane at a Boolean point is the matrix entry at its flat index |
| `exists_lk`, `exists_exp`, `exists_act`, `cov_gen`, `covR`, `covC`, `covN`, `remLk_one/two`, `covLimb`, **`cover_xtW`**, **`hcov_w16`** | every field of `W16Lookups` (13 fields) asks a tuple that IS an entry of `AlkW`; lane L36's `hcov` |
| `relLk_pair`, `relLk_single`, `denV_lkSym`, **`bga_canon_of_accT`** | LogUp's relation list entry by entry; a denominator is `α − fold(β, γ, tuple)`; `α`, `β` are canonical on acceptance |
| `host_pair`, `host_single`, `*_planes`, `*_help`; `relL/D/Q/K/S/F_pair`, `relD/S/F_single`, `relExp`, `relAct` | each host's helper relations from its batch's vanishing entries (`Lk.HGdW`), for the 23 pair planes and 5 single planes |
| `claimSem_empty`, `sum_planeZ2`, `logupSum_planes`, **`hhr_sum`** | the code's LogUp sum claim is `Σ_hp sign·(the plane's cube sum)`; with `H_U`'s zero sum it gives `Σ singles + Σ pairs − Σ table = 0` |
| `hhr_core`, **`hhr_w16`** | lane L36's `hhr` (L44-K3 settled) |

### 2.3 The W16R2 statement (deliverable 3): `BlockLookJoin.lean`, `BlockLookFinal.lean`, `BlockLookDone.lean`

| Theorem | Statement |
|---|---|
| `block_knowledge_look_w16r2_rung_of` | L44's `_helper` at `pubsW16 B (restW16 Pb S.nG)`, `famsW`, `spTabW`, `AlkW`, `TW`, `mlkW`; left `hTform`, `hcov`, `hhr` |
| `block_knowledge_look_w16r2_rung_hhr` | the same with `hTform`, `hcov` proved |
| **`block_knowledge_look_w16r2_rung`** | `Pr[BlockAcc ∧ header ∧ ¬BlockSat(xtW)] ≤ εsTarget q + εend` at the W16R2 rung with every block-level premise gone |

### 2.4 R13 (deliverable 4, part): `BlockR13JoinTab.lean`, `BlockR13JoinForm.lean`

| Theorem / definition | Statement |
|---|---|
| **`restR13`**, `rest19R13_getD`, `rest19R13_gate_getD`, `rest20R13_getD` | R13's lookup-side public tables (three folded value columns, `supp(Tab)`, the ACT support, `SC_ZS`'s ones) |
| `cTabR`, `wTabR`, **`spTabR`**, `spTabR_dg`, `spTabR_Gd` | R13's `SC_TAB`: 3 relations, 6 pad planes, degree 8, for any configuration |
| `numProg_getD`, `progR13_slot19`, `rawSlotR`, `rawSlot19_rung`, `rawSlot19_shield`, `tabR_cube`, **`tabR_formAt`** | slot 19 of `progR13` is its raw slot numbered (the mask rows do not matter on the cube); the identity for any configuration of that shape |
| **`tabR13_formAt_rung`**, **`tabR13_formAt_shield`** | `SC_TAB`'s named identity at the R13 rung, and at every layer `L ∈ shieldExport` of the app's Shieldstral T128 R13 block |

## 3. The numbers

| | value | label |
|---|---|---|
| W16R2 lookups: singles / pairs / total `N` | 114,688 / 475,136 / 1,064,960 (65·2^14) | PROVED |
| W16R2 table positions (17 columns × 2^14) | 278,528; `N + 2·|T| ≤ 1,622,016 ≤ 35,153,256` | PROVED |
| `SC_TAB` at W16R2: relations, pad planes, degree | 17, 22, 24 | PROVED |
| `SC_TAB` at R13 (rung and all 26 Shieldstral layers): relations, pad planes, degree | 3, 6, 8 | PROVED |
| helper planes: pairs / singles / table / `H_U` | 23 / 5 / 17 / 1 (46 `H` planes) | PROVED from the code's `HIds` (evaluated) |
| W16R2 lookup side vs the code (full corpus) | 283 checks, 0 failed; 19 of 19 negative controls | CHECKED |
| W16R2 lookup side vs the code (short corpus, committed) | 254 checks, 0 failed; 19 of 19 | CHECKED |
| W16R2 host tables vs the code (full / short) | 156 / 94 checks, 0 failed; 37 of 37 / 20 of 20 | CHECKED |
| R13 rung lookup side vs the code (full / short) | 49 / 43 checks, 0 failed; 15 of 15 / 15 of 15 | CHECKED |
| entries compared one by one | W16R2: 475,136 (lookup side) + 283,136 (hosts); R13: 98,304 | CHECKED |
| Shieldstral lookups with the exp and ACT tuples | 64,258,048 + 2^19 + 2^21 = 66,879,488; with `2·|T| ≤ 98,304`: 66,977,792 ≤ 2^26 = 67,108,864 (margin 131,072) | ESTIMATE (L47-4) |

## 4. What is left, by name

### 4.1 At the W16R2 rung

`block_knowledge_look_w16r2_rung` takes:
* **run-level** (unchanged since L31 / L41 / L44): `U`, `hU`, `hK2`, `key`, `domain`, `hs`, `hL`, `hL64`, `hL20`, `hdrLen`,
  `hdrSq`, `hh`, `hq`, `csE`, `rE`, `QE`, `XE`, `hcsE`, `q`, `A`, `hA`, `εend`, `hEnd`;
* **the verifier is the code's W16R2 rung verifier**: `hP : IsRungW16` (as before), `hdef : P.define = defineS (progW16
  …) (pubsW16 Pb Lay B (restW16 Pb S.nG))` (the program CHECKED by L35 / L44; every public table now CHECKED by value),
  `hlc : P.logCols = 14`, `hep : 0 < P.endpointLogN`, and four facts the profile structure does not pin: `hk3`, `hk19`,
  `hk20` (slots 3, 19, 20 are standalone) and `hls : P.logupSumClaim = logupSumW16 cfgRungW16` — all four CHECKED
  against the code (`SLOT_KINDS`, `protocol::logup_sum_claim`; L47-1);
* **public data and its validity**: `Pb`, `Lay`, `B`, `hS : RungS S` (ARGUED: the rung's precision), `hLay : LayW16 Lay`
  (ARGUED: the rung's axes do not pad), `hnG : 0 < S.nG` (one ACT group at least; the code refuses fewer,
  accuracy_act.rs:15; the fixture has 3, MEASURED).

Gone against L44's `block_knowledge_host_w16r2_rung_pubs`: `HGd`, `spH`, `hdgH`, `hformH`, `hgdH`, `gL`, `spT`, `hTdeg`,
`hTform`, `hgate`, `hones`, `rest`, `fams`, `hF`, `hW`, `h24`, `Alk`, `T`, `mlk`, `hN`, `he`, `hTtab`, `hcov`, `hhr`.

**Can each premise be met by the real system?** `hk3`, `hk19`, `hk20`, `hls`, the public tables in `hdef`: CHECKED on a
real receipt. `hnG`: the code's own check. `hS`, `hLay`: ARGUED, as before. The run-level premises: unchanged. The
premises this lane discharged are discharged by theorems about the real objects (the code's lookup list, table and
helper planes, read off the committed matrix), not by choices made to fit: in particular `Alk` and `mlk` read the data
the `A` cut fixes, which `rootOfCut_cutsOf` and `dofA_aPl` prove is the real data on every outcome (L47-2).

### 4.2 At R13 and the app's Shieldstral block (deliverable 4): where this lane stopped

Done: `SC_TAB`'s identity (item 1) at the R13 rung and at all 26 Shieldstral layers (PROVED, with `hkind` and `hrest`
as premises: `hkind` CHECKED at the R13 rung, `hrest` is "the slot-19 tables are `restR13`'s", CHECKED at the R13 rung);
R13's lookup-side public tables CHECKED at the R13 rung (no Shieldstral block receipt exists to export).

Not done, and what the next lane needs, in order:
1. **The R13 counterpart of L41 and L44** (the hosts): R13's extracted planes (`R13Data` read off `A` at
   `DefR13.aOff`, the analogue of `xtW`), the algebra data and `R13Spec` (L36's `r13Rels_of_algGood` is ready), and the
   six hosts' named identities against `progR13`'s `r13DzcIr`, `r13QzcIr`, `r13SzcIr`, `r13FzcIr` and the shared arms; then
   the helper layer (`SC_LZC`, `SC_ZS`, and `SC_TAB` from this lane's `tabR_formAt`), and `pubsR13` from the public data
   (with a value check like fork D's).
2. **The R13 lookup side**, by this lane's W16R2 pattern: `AlkR13` over R13's byte lookups (`DefR13.lookups`, the top-bit
   pins), the exp and ACT tuples, `TR13` (`tabTupE` for `k < 3`), the cover against `R13Query`, and `hhr` with R13's sum
   claim (no Lean transcription of R13's `logup_sum_claim` exists yet; its 108 parts are in fork D's R13 corpus). The
   cut lemmas (`rootOfCut_cutsOf`) and the sum-claim lemmas (`claimSem_empty`, `sum_planeZ2`) are generic and carry over.
3. Then the R13 rung statement on L35's `block_knowledge_define_alg_r13_lk` and, at the app's block,
   `block_knowledge_define_alg_r13_shield_lk26` per layer (L36-1: not L31's), with `he ≤ 2^26` met by the count of
   L47-4.

## 5. Findings

No statement of `Statements.lean` changed. No target weakened. No existing Lean file changed.

**L47-1 (Medium; for the coordinator): the profile structure does not pin the LogUp sum claim.** `IsRungW16` fixes the
draws, schedule, groups and openings, but not `P.logupSumClaim` (nor the slot kinds of 3, 19, 20, L44-K1). The
helper-sum part of `hhr` reads the sum claim through `AccT`'s `OpenTrue`, so the statement takes `hls` (and `hk3`,
`hk19`, `hk20`) as named verifier premises, CHECKED against the code on a real receipt (92 parts, coefficient words,
signs, empty points, value 0). Adding these fields to the profile structures (and the R13 ones) would remove them.

**L47-2 (Medium; for the coordinator and the gap audit; resolved here, PROVED): the lookups had to be fixed by the `A`
cut alone, while the extracted planes also read the `A` root.** L21's LogUp argument takes `Alk`, `mlk` as functions of
the prover's log cut at the `A` root's first absorption; the extracted planes `xtW` read the `A` matrix through that cut
AND the root of the prover's output. Unless the cut determines the root, no `Alk` of the required type can contain every
query of the extracted planes on every outcome, and `hcov` would not be meetable (L31-1's pattern). PROVED
(`rootOfCut_cutsOf`): for the fixed prover the cut determines the root — the prover's next question after the cut is
the root's absorption, or, when the cut is the whole log, the prover's output is determined by it. `Alk` therefore
depends on the prover `A` (legitimately: the statement is for a fixed `A`).

**L47-3 (Low; for the coordinator): the ACT column's padding rows.** The code pads the ACT column with `2048 + g_act`
(the tuple `(2048, TAG_ACT, 0, 0)`); `ActTable` contains it only as group 0's row at 2048, which needs `act[0][2048] = 0`
and at least one group. Lean's table uses group 0's row at 2048 (`act 0 2048`); the two agree because the code refuses
an ACT table whose row 2048 is not 0 (accuracy_act.rs:22), CHECKED on the fixture. `hTtab` then needs only `0 < nG`
(premise `hnG`). `BlockShape.Valid` states `nG ≤ 4` but not `1 ≤ nG`; adding it would make `hnG` a consequence.

**L47-4 (Low; for the coordinator and the R13 lookup lane): lane L36's lookup count omits the exp and ACT tuples.**
`lkCount` counts the domains' lookup lists only: W16R2 rung 1,015,808 (62·2^14), Shieldstral 64,258,048. The code's
LogUp also looks up the exp tuple at every `Dom::S` point and the ACT tuple at every `Dom::F` point (helpers `sexp`,
`fact`). At the rung the corrected count is PROVED here (1,064,960). At the app's block it is 66,879,488 (ESTIMATE), and
with twice the table's 3·2^14 positions 66,977,792 ≤ 2^26: the repaired bound of L36-1 still holds, with a margin of
131,072 instead of about 2.75 million. The block budget (L36's 54,314,754) used the bound `2^26`, not the count, and does
not change.

**L47-5 (Info; for the next lanes): the cover needs the shape's precision.** `W16Lookups`' remainder fields read their
widths from the shape `S`; they match the code's lookups only at the rung's precision, so `hcov_w16` takes `RungS`
(already a premise). The layout's `LayW16` is not needed: the cover holds at every point of the product cubes.

**L47-6 (Info, method).** Writing slot 19's 62 tables as a generated list made `slot19_eq` hit the recursion limit;
explicit lists fixed it. At R13, evaluating only the raw slot (the numbering's mask rows do not affect a table's value
on the cube) made all 26 Shieldstral layers check in seconds (L44-R4 had a 33 GiB blow-up evaluating whole programs).

## 6. Checks

All in `results/zk60_lean_l47_20261110/`, each run as one job through the zk60 resource guard (class `cpu`,
`run_guarded.py`).

**`check.log`** (`check_l47.sh`, run as the last step of job `lean-l47-check`, `iter11.log`; cap 36 GiB, need 24,
`LEAN_NUM_THREADS=4`; exit 0, 209 s, peak RSS 3.80 GiB), on the tree with every module of this lane:
- the eighteen L47 library modules built one at a time (`prebuild_*.log`), then the full build (`full.log`): **3,721
  jobs, rc 0, 0 warnings, 0 errors, no `sorry`**; 0 warnings in the modules' own builds;
- the axiom audit (`axioms_l47.lean`, `axioms.log`, every `theorem`, `def`, `abbrev` of the eighteen files): **240
  declarations (165 theorems, 71 definitions, 4 abbreviations)**; 152 on `[propext, Classical.choice, Quot.sound]`, 23
  on `[propext, Quot.sound]`, 40 on `[propext]`, 25 on none; no `sorryAx`, no `ofReduceBool`, no other axiom;
- the source scan of the library files, the two checkers and the test-only Rust file for the forbidden words: none;
- the root imports the eighteen modules (not the checkers); `Statements.lean` unchanged; no existing file under
  `formal/` modified, deleted or renamed against the base `31af9ac1`; no import line removed; under `ops/` only the two
  test-only Rust files;
- name clashes over every worktree (`l47_nameclash.py`, prefixes `BlockTab`, `BlockLook`, `BlockR13Join`,
  `BlockHostExport`; 340 declarations, 41 worktrees, `nameclash.log`): 0;
- regressions: `L6Check` 1,206, `L5Check` 5,553, `L11Check` 404, the fixture L1 check 101,956; 0 failed;
- the lane's agreement checks against the code on the committed short corpora: `BlockTabExportCheck` W16R2 lookup side
  **254 checks, 0 failed, 19 of 19 negative controls caught**; `BlockHostExportCheck` host tables **94 checks, 0 failed
  (the 7 folded-weight tables need the full corpus), 20 of 20**; `BlockTabExportCheck` R13 rung lookup side **43 checks,
  0 failed, 15 of 15**.

**The exports and the full corpora** (fork D; `exp_export.sh`, `exp_iter1.log` … `exp_iter3.log`): `cargo test --release
--offline --locked -j 2 --lib lean_l47_export` on the W16R2 rung (`shape::W16R2_RUNG_H24`) and R13 rung
(`shape::R13_RUNG_H24`) receipts proved by the production `prove_core` and accepted by `verify_core`; census tests with
the export file `s25_tests` 20 passed, `hash_domain` 15 passed (`exp_s25_tests.log`, `exp_hash_domain.log`). Re-running
the export reproduced the W16R2 corpora byte for byte (the seeded fixture). Full corpora (outside the repository, sha256 in
`l47_export_sha256.txt`): W16R2 lookup side 12,410,467 B (`exp_check3.log`: **283 checks, 0 failed, 19 of 19**), host
tables 8,267,721 B (`exp_check_host3.log`: **156 checks, 0 failed, 37 of 37**), R13 rung 2,324,865 B
(`exp_check_r13_1.log`: **49 checks, 0 failed, 15 of 15**). Committed short corpora: `l47_w16r2_short.txt` 188,660 B,
`l47_host_short.txt` 71,626 B, `l47_r13_short.txt` 107,864 B. A table is compared entry for entry in a full corpus, and
by two fingerprints `Σ v_i·ρ^i` (two fixed public points, the code's word arithmetic on both sides) plus its first and
last 64 entries in a short one.

The forks' iterations: `tab_iter*.log` (SC_TAB at W16R2), `r13_iter*.log` (SC_TAB at R13), `cov_iter*.log` (the cover),
`rel_iter*.log` (LogUp's helper relations), `exp_*` (the exports and checkers); the lane's own `iter1` … `iter11`
(`iter1.log`, `iter9.log`: the probes of the W16R2 and R13 programs). Not run by this lane: the merged-tree check on
perf, which is the coordinator's.
