# D63 lane L44: the block join, continued — the five other hosts, the public tables, the helper layer, the code export and the R13 program (2026-11-10)

Lean lane L44 (Claude Opus 5.5), on its own worktree, after perf `f17599c4` (L41 merged). Lean 4.34.1, Mathlib
v4.34.1, no new dependency. New library files under `formal/ZK60Formal/` (`BlockHost*`, `BlockLk*`, `BlockR13Prog*`),
imported by the library root; three agreement checkers (`BlockHelperExportCheck`, `BlockR13ProgCheck`,
`BlockR13ProgExportCheck`, each with a `main`, not imported); one test-only Rust file. `Statements.lean` and every
existing Lean file are unchanged; no production Rust source changed. Evidence: `results/zk60_lean_l44_20261110/`.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms at most `propext`, `Classical.choice`, `Quot.sound`),
**CHECKED** (an executable comparison with the code, with a negative control), **MEASURED** (read off the code or a
corpus), **ARGUED** (a reasoned claim, not a Lean theorem), **LEFT** (not done).

## 1. In plain words, for Victor

**What was asked.** The security statement of one transformer block ("the block verifier accepts while the committed
data breaks the block's equations with probability at most the target") still rested on assumptions about the block
itself. Lane L41 had proved the piece for ONE of the six "host" checks of a block. This lane was to prove the other
five, tie the verifier's public tables to the public data, prove the helper (LogUp) layer, check the Lean model of the
verifier against the real code, and start the same work for the R13 profile the media app uses.

**What is now proved or checked.**
1. **All six hosts of the W16R2 rung block are proved** (PROVED): for each of `SC_DZC` (the norms and the residual
   stream), `SC_QZC` and `SC_KVZC` (RoPE and the Q/K/V products), `SC_SZC` (softmax, with its row sums and the score
   product), `SC_FZC` (the MLP), the polynomial the verifier checks, summed over the cube, is exactly the named formula
   the earlier algebra (lane L36) needs. With L41's `SC_TZC`, the premise `hformRest` is gone.
2. **The verifier's public tables are now built from the public data** (PROVED): the support gates, the norms' `γ`,
   RoPE's `cos`/`sin`, the causal mask, the activation's group column and the seven folded weight matrices, in the
   code's own arithmetic (`pubsW16`), and every fact the hosts need about them follows (`pubW16_of`).
3. **The statement is assembled** (`block_knowledge_host_w16r2_rung`, `…_pubs`, `…_helper`): over L41's statement, the
   five hosts' identities, the pad-plane counts, the batch's other entries and (in `_pubs`) the public-table facts are
   gone; in `_helper` the helper layer is gone too, except the table slot `SC_TAB`.
4. **The Lean model of the verifier agrees with the code, table by table** (CHECKED): a test-only export from a REAL
   W16R2 block receipt (every table's offsets, sizes, coordinates, reserved rows, extension rounds, the claims, the
   plane offsets) matches the Lean program in all 1,685 checks; 14 deliberately wrong changes are each caught. This
   closes the open point L35-7 for the private tables and the layout.
5. **The R13 program exists and agrees with the code** (PROVED and CHECKED): `progR13`, including the `SC_TAB` slot the
   code never transcribed (finding L17-9), passes the verifier's shape check at the rung and at every one of the media
   app's 26 Shieldstral layers; its table counts are **146 `A` / 54 `H` at Shieldstral, confirming L31-3's derived
   figure**; it matches L17's R13 corpus (163 checks) and a fresh R13 receipt export (2,041 checks), each with its
   negative control.

**What is not done.** The lookup side (that every looked-up value is in its table: `hhr`, `hcov`, `Alk`, `T`, `mlk`,
`hTtab`, `hN`, `he`) and the table slot `SC_TAB`'s identity at W16R2 are still named premises; the public tables of the
lookup side (`SC_LZC`'s support, `SC_TAB`'s columns, `SC_ZS`'s ones) are not yet built from the public data; the
public tables' VALUES are not yet compared with the export (lengths only); nothing of items 1–4 at R13 (a later lane).

**Findings that need a decision.** L44-R3 (the guard's heavy lock is not first-come-first-served in practice; another
lane's chained jobs held it for hours) and L44-K1 (the slot kinds of `SC_LZC`, `SC_TAB`, `SC_ZS` are not pinned by the
verifier's parameters; a named premise, measured against the code). Neither needs a ruling on the statements.

## 2. What is proved

Every theorem below is on at most `propext`, `Classical.choice`, `Quot.sound` (section 6).

### 2.1 `BlockHostBase.lean`: the shared tools

| Theorem / definition | Statement |
|---|---|
| `LayW16` | the layout facts the hosts read (public data): tokens, head dimension, head slots and groups do not pad; the RoPE flip is the head dimension's top bit |
| **`gQ_one`**, `gK_one`, `gS_one`, `gHt_one`, `gT_one'` | the gates of the cubes that do not pad are `1` everywhere |
| `PubW16` | **the verifier's public tables, as public data**: one field per table the hosts read (gates, `γ`, `cos`/`sin`, mask, group column, the seven folded weights `Σ_j eq(r_out, j)·W(c, j)`) |
| `hPl`, `tabK_ph_cpt`, `aFx_eval`, `ptK_fx`, **`tabK_fx_cpt`**, `mleAt_append_bits` | an `H` plane; a table with fixed coordinates then the slot's variables, at the zero extension, is `Σ_z eq(r, z)·plane(z ++ b)` |
| **`mm_cube`**, **`mm_fold`** | a hosted matmul's cube sum, and with the folded weight it is the multilinear extension of the contraction |
| `lkRels_congr`, `padPls_congr`, `toK_zpowW`, `lksS_eval` | the batch's LogUp and pad entries read no `eq` table and no draw; the pad weights `ζ^j`; the lookups' words read only `α`, `γ` |
| **`formAt_two`** | L36's `FormAt` of a host with two hosted slots, from its program's hosted list and its cube identity |

### 2.2 The five hosts (deliverable 1)

| File | Main theorem | Also |
|---|---|---|
| `BlockHostDzc.lean` | **`formAt_dzc`** (slot 14) | `slot14_eq`, `slot10_eq`, `slot13_eq` (by `rfl`); `dzc_vals`; `xcDzc` (the ten LogUp helper relations, draw-free), `pwDzc` (19 pad planes); `relClD_alg`, `relGhD_alg`; `dzc_Z`; `mm_wo`, `mm_dmm` |
| `BlockHostQkv.lean` | **`formAt_qzc`** (15), **`formAt_kvzc`** (16) | `slot15/5/9/16/6/7_eq`; the flipped RoPE table (`tabK_fl_cpt`); `xcQzc`, `xcKvzc`; `qzc_Z`, `kvzc_Z`; `qmm_spSum`; `pv_cube`, `pv_spSum` (the bilinear `SC_PV`); `kvmm_spSum` (split claim points) |
| `BlockHostSzc.lean` | **`formAt_szc`** (17) | `xcSzc` (five LogUp relations and the exp tuple); `szc_hostPhi`, `szc_cube`; `rs_cube`, `algH0_mle` (the hosted `SC_RS` with weight `32·ν₀`); `score_cube` (the bilinear `SC_SCORE`); `relCl17_alg`, `relGh171_alg`, `rsA_alg`, `rsB_alg`, `relMm171_alg` |
| `BlockHostFzc.lean` | **`formAt_fzc`** (18) | `slot18/11/12_eq`; `xcFzc` (the ACT tuple and four LogUp relations), `pwFzc` (9 pad planes); `fzc_rel0`, `fzc_gh0`, `fzc_gh1`; `fzc_batch`; `gmm_sum`, `umm_sum` |

### 2.3 `BlockHostPub.lean`: the public tables (deliverable 2)

| Theorem / definition | Statement |
|---|---|
| `wordGF`, `cubeTab`, **`cubeTab_getD`** | a table of a function on the cube in the code's index order |
| `drSeg`, `wsumF`, `foldTab`, **`foldTab_getD`** | the fold of a weight by `eq_table_msb(r)` in the code's `Fp2` arithmetic, read in the field: `Σ_y eq(r, y)·W(c, y)` (canonical `r`) |
| **`pubsW16 B rest`** | every public table the hosts read, from `B`; the lookup side's (slots 3, 19, 20) from `rest` |
| **`pubW16_of`** | `PubW16 U (pubsW16 B rest) Pb Lay B`, for every `rest` |

### 2.4 `BlockLk*.lean`: the helper layer (deliverable 3, in part)

| Theorem / definition | Statement |
|---|---|
| `spHW`, `spHW_dg`, `spHW_formAt` | the helper layer's polynomials: the relation layer's `algSp` at the six hosts, a family off the hosts |
| `slot3_eq`, `lzc_vals`, `lzc_irEval`, `cLzc`, `wLzc`, `lzc_cube`, `spLzc`, **`lzc_formAt`** | `SC_LZC`: its limb LogUp relation and pad planes, its certified polynomial and named identity |
| `fhU_eq`, `slot20_eq`, `zs_cube`, **`zs_formAt`** | `SC_ZS`: the zero-sum row, its named identity |
| `HGdW` | what the helper layer's start claims say, read at `(β, γ, α)` only |
| **`hgd_of`** (`hgdH`), **`helper_dg`** (`hdgH`), **`helper_formAt`** (`hformH`) | lane L36's helper premises, from the hosts' identities, `SC_LZC`'s, `SC_ZS`'s, and `SC_TAB`'s (a named premise) |

### 2.5 `BlockHostFinal.lean`: the statements (deliverables 1, 2, 3, 4)

| Theorem / definition | Statement |
|---|---|
| `xcW`, `pwcW` | **the batch's entries past the named clauses and the pad planes, DEFINED** per host |
| **`formAt_rest_w16`** | L41's `hformRest` PROVED |
| **`formAt_hosts_w16`** | all six hosts' identities |
| **`block_knowledge_host_w16r2_rung`** | `Pr[BlockAcc ∧ header ∧ ¬BlockSat(xtW)] ≤ εsTarget q + εend` at the W16R2 rung with all six hosts proved |
| **`block_knowledge_host_w16r2_rung_pubs`** | the same at the concrete public tables `pubsW16 B rest` (`PubW16` gone) |
| **`block_knowledge_host_w16r2_rung_helper`** | the same with the helper layer discharged except `SC_TAB` |

### 2.6 `BlockR13Prog*.lean`: the R13 program (deliverable 6, parts 1–3)

| Theorem / definition | Statement |
|---|---|
| `progR13`, `cfgRungR13`, `cfgShieldR13`, the R13 IR builders, `SC_TAB`'s IR | R13's 23-slot program; `SC_TAB` transcribed from argument_accuracy.rs:416-444 (L17-9) |
| **`progR13_rung_ok`**, **`progR13_shield_ok`** | the program passes the verifier's shape check at the rung and at every Shieldstral layer |
| **`progR13_rung_cntA/H`**, **`progR13_shield_cntA/H`** | the per-slot table counts: rung 148 / 54, Shieldstral 146 / 53 (with the sum claim 55 / 54) |

## 3. The numbers

| | value | label |
|---|---|---|
| hosts whose named identity is proved (W16R2 rung) | 6 of 6 (L41: 1; L44: 5) | PROVED |
| W16R2 export agreement (`BlockHelperExportCheck`) | 1,685 checks, 0 failed; 14 of 14 negative controls | CHECKED |
| R13 program vs L17's corpora (`BlockR13ProgCheck`) | 163 checks, 0 failed; 11 of 11 negative controls | CHECKED |
| R13 program vs the R13 export (`BlockR13ProgExportCheck`) | 2,041 checks, 0 failed; 14 of 14 negative controls | CHECKED |
| Shieldstral T128 R13 table counts `A` / `H` | 146 / 53 (54 with the sum claim): L31-3's 146 / 54 HOLDS | PROVED |
| R13 rung table counts | 148 / 54 (55 with the sum claim) | PROVED |
| export corpora | W16R2 521,917 B, R13 594,254 B (sha256 in `l44_export_sha256.txt`) | MEASURED |
| census tests with the export file | `s25_tests` 20 passed, `hash_domain` 15 passed | MEASURED |

## 4. What is left, by name

`block_knowledge_host_w16r2_rung_pubs` takes:
* run-level premises (as L31/L41): `U`, `hU`, `hK2`, `key`, `domain`, `hs`, `hL`, `hL64`, `hL20`, `hdrLen`, `hdrSq`,
  `hh`, `hq`, `csE`, `rE`, `QE`, `XE`, `hcsE`, `q`, `A`, `hA`, `εend`, `hEnd`;
* the verifier's facts: `hP : IsRungW16`, `hdef : P.define = defineS (progW16 …) (pubsW16 B rest)` (now CHECKED
  against the code for every private table and the layout; the public tables' values not yet), `hlc`, `hep`;
* public data: `Pb`, `Lay`, `B`, `fams`, `hF`, `hW`, `h24`, `hS : RungS S` (ARGUED: the rung's `PREC`), `hLay : LayW16`
  (ARGUED: the rung's axes do not pad; the RoPE flip), `rest` (the lookup side's tables);
* lane L36's helper layer and lookup side: `HGd`, `spH`, `hdgH`, `hformH`, `hgdH`, `Alk`, `T`, `mlk`, `hN`, `he`,
  `hTtab`, `hcov`, `hhr`.

`block_knowledge_host_w16r2_rung_helper` replaces the first five of the last line by: `gL`, `spT`, `hTdeg`, `hTform`
(`SC_TAB`'s certified polynomial and named identity: LEFT; the intended construction is L23's `SlotPoly.zc` on its 17
table relations and 22 pad planes, `lk_iter1.log`), `hk3`, `hk20` (slot kinds standalone, MEASURED against
`layout.rs` `SLOT_KINDS`, L44-K1), `hgate`, `hones` (`SC_LZC`'s and `SC_ZS`'s public tables, MEASURED against the code
for `hones`, ARGUED for `hgate`).

Not started: `hhr` (the zero-sum needs AccT's `OpenTrue` on `logupSumW16`, L44-K3), `Alk`, `T`, `mlk`, `hTtab`, `hcov`
(through L36's `W16LookupsG` and `lookupsN`), `hN`, `he` (ARGUED: about 1.02 M lookups plus 17·16,384 table entries,
far below 35,153,256). R13 items 1–4 (a later lane).

## 5. Findings

No statement of `Statements.lean` changed. No target weakened. No existing Lean file changed.

**L44-R3 (Medium, process; for the coordinator): the heavy lock is not first-come-first-served in practice.** Lane
A29's back-to-back jobs (`a29-diag-calib`, `a29-census-uniform`, `a29-eval-u1-0` … `-25`) took the lock on each
resubmission ahead of this lane's waiting jobs (the guard polls every 60 s); some of this lane's checks of a few
seconds waited 1.5–2 hours, and the lane lost about 3–4 hours. D69 says arrival order; the guard's FIFO mode is off and
needs an announced decision (ZK60_RESOURCE_PROTOCOL.md). Nobody here touched it. (Also reported by the forks as L44-E1,
L44-S1, L44-K4.)

**L44-K1 (Medium; for the coordinator): the slot kinds of `SC_LZC`, `SC_TAB`, `SC_ZS` are not pinned by `IsRungW16`.**
Their named identities (`FormAt`, standalone form) hold only if `P.kind k = standalone`; the statement now takes `hk3`,
`hk20` (and `SC_TAB`'s `hk19` will be needed) as named verifier premises, MEASURED against the code's `SLOT_KINDS`
(layout.rs:1077-1104).

**L44-K3 (Info): the LogUp zero-sum is not a slot fact.** `HelperRel`'s `Σ single + Σ pair − Σ table = 0` must come from
the opening of `protocol::logup_sum_claim` (`DefW16.logupSumW16`, all 46 `H` planes with signs) at `AccT`, combined
with `SC_ZS`'s `Σ H_U = 0`; `hhr`'s shape already passes `AccT`.

**L44-R1 (Info): L35's doc says L17's `SlotR13.lean` has the R13 IR builders; it has only the draws.** The builders
are now in `BlockR13Prog.lean`. **L44-R2 (Low): the code itself still has no IR for R13's `SC_TAB`** (the Metal path
keeps it on the CPU); the Lean IR is checked against the code's closure value at one real point and its tables.
**L44-R4 (Info): one kernel decision of `progOKb` over all 26 Shieldstral layers times out (peak about 33 GiB); one
theorem per layer passes (about 5 GiB).**

**L44-E2 (Info): the public tables' VALUES are exported (in full or by digest) but compared only by length;**
comparing them needs the fixture's public data `B` in the export.

**L44-D1 (Low; for every lane): `if_pos`, `if_neg`, `dif_pos`, `dif_neg`, `Fin.coe_castAdd`, `Fin.coe_natAdd` are
deprecated in this toolchain** (warnings); use `ite_eq_left/right`, `dite_eq_left/right`, `Fin.val_castAdd/natAdd`.
**L44-D3 (Info): every premise introduced is meetable**: `PubW16`'s fold fields need canonical draws, which accepting
outcomes supply (`defineS_ok`); `RungS` is `precRungW16`.

## 6. Checks

All in `results/zk60_lean_l44_20261110/`, each run as one job through the zk60 resource guard (class `cpu`,
`run_guarded.py`). The work was split across forks of the lane (one per host group, the export, R13, the helper
layer); their iterations are `dzc_*`, `qkv_*`, `szc_*`, `fzc_*`, `exp_*`, `r13_*`, `lk_*`; the lane's own `iter1` …
`iter5` (`iter5.log`: `BlockHostFinal` type-checks, no warning).

**`check.log`** (`check_l44.sh`, job `lean-l44-check`, cap 36 GiB, need 24, `LEAN_NUM_THREADS=4`; exit 0, 72 s, peak
3.80 GiB), on the tree at `9a1a6cb3`:
- the thirteen L44 library modules built one at a time (`prebuild_*.log`), then the full build (`full.log`): **3,694
  jobs, rc 0, 0 warnings, 0 errors, no `sorry`**; 0 warnings in the modules' own builds;
- the axiom audit (`axioms_l44.lean`, `axioms.log`): **467 declarations (296 theorems, 163 definitions, 7 structures,
  1 abbreviation)**; 228 on `[propext, Classical.choice, Quot.sound]`, 34 on `[propext, Quot.sound]`, 125 on
  `[propext]`, 80 on none; no `sorryAx`, no `ofReduceBool`, no other axiom;
- the source scan of the library files and the three checkers for the forbidden words: none;
- the root imports the thirteen modules; `Statements.lean` unchanged; no existing file under `formal/` modified,
  deleted or renamed against the base `f17599c4`; no import line removed; under `ops/` only the two test-only Rust
  files of deliverable 5;
- name clashes over every worktree (`l44_nameclash.py`, prefixes `BlockHost`, `BlockLk`, `BlockHelper`,
  `BlockR13Prog`; 565 declarations, 42 worktrees, `nameclash.log`): 0;
- regressions: `L6Check` 1,206, `L5Check` 5,553, `L11Check` 404, the fixture L1 check 101,956; 0 failed;
- the lane's agreement checks against the code: `BlockHelperExportCheck` (W16R2 export) **1,685 checks, 0 failed, 14
  of 14 negative controls caught**; `BlockR13ProgCheck` (L17's R13 corpora) **163 checks, 0 failed, 11 of 11**;
  `BlockR13ProgExportCheck` (R13 export) **2,041 checks, 0 failed, 14 of 14**.

The export itself (`exp_export1.log`, `exp_export.sh`): `cargo test --release --offline --locked -j 2 --lib
lean_l44_export`, rc 0, 186 s; `s25_tests` 20 passed and `hash_domain` 15 passed (`exp_s25_tests.log`,
`exp_hash_domain.log`). Not run by this lane: `BlockDefineCheck`, `BlockAlgCheck`, `ExecBlockCheck`, `CheckR13Block`
(no file they read was changed), and the merged-tree check on perf, which is the coordinator's.
