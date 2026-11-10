# D63 lane L35: the block's `define` and the tables part of the slot polynomials (2026-11-09)

Lean lane L35 (Claude Fable 5.2, cut off by a usage limit at 19:21 PST; resumed and finished by Claude Opus 5.5), on
its own worktree: perf `b938ae87` (L31 merged), then perf `2155ede8` (L32, L33, A28, L34) and perf `16acb7c8` (L36)
merged in. Lean 4.34.1, Mathlib v4.34.1, no new dependency. Eleven new library files under `formal/ZK60Formal/`, all
`BlockDefine*.lean`,
imported by the library root; one checker `BlockDefineCheck.lean`, not imported by the root. No Rust.
`Statements.lean` and every existing Lean file are unchanged. Evidence: `results/zk60_lean_l35_20261109/`.

**STATUS: deliverables 1, 2, 3, 5 and 6 done for the W16R2 rung, and joined with lane L36's statements; deliverable 4
(R13) done in its generic form only: the R13 slot program is not written (section 6). The check of section 7 is
green.** The merged-tree check is the coordinator's.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms at most `propext`, `Classical.choice`, `Quot.sound`),
**MEASURED** (read off a real receipt and checked by `BlockDefineCheck` or an earlier lane's checker), **ESTIMATE**
(derived by a rule, no receipt), **ARGUED** (a reasoned claim, not a Lean theorem), **HYPOTHESIS** (a named premise),
**LEFT** (not done).

## 1. In plain words, for Victor

**What this lane was asked.** Lane L31 left the block's security statement with one big assumption: "the slot
polynomials, written over the committed data, exist and behave". Each of the block's 23 sumcheck slots proves that a
polynomial sums to a value. That polynomial is built from tables: some public, some challenge tables, some read from
the committed private data. L31 assumed this polynomial (`Poly`), its key identity (`hPoly`), its degree (`hdegP`) and
some bookkeeping about how many private tables each slot reads (`DefCm`). This lane was to build the real thing for
the W16R2 block and prove those facts, then do R13.

**What is now proved.**
1. **The block's `define` is now a Lean object.** The code's `define` builds, per slot, the list of tables and the
   slot's polynomial. Here it is written as data (`progW16`): 23 slot programs, each with its tables (for a private
   table: which commitment, which rows and columns, which challenge coordinates, which mask rows) and its polynomial as
   L13's builder. A small evaluator (`defineS`) turns the data into the verifier's `define`.
2. **It agrees with the code on a real receipt** (MEASURED). On the real W16R2 rung receipt, for every one of the 23
   slots: every coefficient of the polynomial (as a value), every table in order, every challenge point, every hosted
   coefficient, the plane read by 156 of the 162 private tables; and the mask rows reserved in the `A` and `H`
   commitments. 143 checks, 0 failed. A negative control with 10 deliberate single changes fails exactly 10 checks.
   Not compared (no corpus carries them): the private tables' coordinates and extension rounds (finding L35-7).
3. **The tables part of the slot polynomials is built and its facts are proved, for ANY block whose `define` is
   given as such data** (PROVED): the polynomial `polyS` over the committed matrices; its key identity at the
   verifier's point (`polyS_slotEvalN`, L31's `hPoly`); its degree (`polyS_indDeg`, L31's `hdegP`); its outputs are
   canonical (`defineS_polyC`); the private tables per commitment (`defineS_defCm`). The heart of it: every table's
   value at the verifier's point is that table's multilinear extension (`tabVals_toK`), including a private table,
   whose value is the claim the verifier hands to the commitment, unfolded through L10's weight lists
   (`claimSem_parts`).
4. **The W16R2 block statement with all of this discharged** (PROVED): `block_knowledge_define_w16r2_rung` (on
   L31's statement) and `block_knowledge_define_alg_w16r2_rung` (on lane L36's, which also discharges the relation
   layers' algebra and the lookup bridge). Of the
   assumptions about `define`, only "the verifier's `define` IS this program" (`hdef`) and two plain facts about the
   verifier's row sizes (`hlc : P.logCols = 14`, `hep : 0 < P.endpointLogN`) remain. The program's own checks (each
   private table reads each challenge at most once; each slot polynomial's degree is within the slot's budget; the
   table counts 114 and 46 + 1) are evaluated by Lean.
5. **Joined with lane L36.** L36's three statements, including the one for the media app's block at LogUp's bound
   `2^26` (`block_knowledge_alg_r13_shield_lk26`, finding L36-1), are restated with the tables part discharged
   (`block_knowledge_define_alg_*`). L36's premise `hform` now reads the DEFINED tables part (`polyXof`), whose
   unfolding lemmas are in `BlockDefineUnfold.lean` (finding L36-2).
6. **L31's per-slot `A` split is confirmed at the rung** (PROVED from the program, which is MEASURED against the
   code): the program's private tables per slot are exactly L31's `aCntW16Rung` and `hCntW16Rung`.

**What is not done.** The R13 slot program (R13's `SC_TAB` IR is still not transcribed, L17-9), so the R13 and
Shieldstral statements are proved only for "any program that passes the check with the right counts"; the
Shieldstral counts 146 / 54 are therefore not confirmed here. The value of the tables on the Boolean cube, which
L36's remaining premise `hform` needs, and the tables `dt` that L36's `hspec` reads (section 6.1). The helper layer
and the run-level premises, as before.

**Findings that need a decision.** L35-8 (High for one statement, repaired): `block_knowledge_define_r13_shield`
(on L31's Shieldstral statement) inherits L31's lookup bound `he ≤ 35,153,256`, which the app's block cannot meet
(L36-1), so it says nothing about the app's block; cite `block_knowledge_define_alg_r13_shield_lk26` instead. L35-2
(Medium): the public tables `pubs` are a free parameter of the statements; nothing ties them to the block's public
statement `Pb`, `B`. The statements are true for every `pubs`, but L36's remaining premises can only be proved for
the real ones. L35-7 (Medium): the private tables' slices are checked against the code only through their plane ids
and the reserved rows; their coordinates and extension rounds are not in any corpus.

## 2. What is proved

Every theorem below is on at most `propext`, `Classical.choice`, `Quot.sound` (section 7). 141 theorems in the
nine files below, and 16 more in `BlockDefineUnfold.lean` and `BlockDefineAlg.lean` (section 2.8).

### 2.1 `BlockDefineAff.lean`: the degree calculus (35 theorems)

| Theorem / definition | Statement |
|---|---|
| `ConstAt`, `AffAt` and their closure rules (`add`, `sub`, `mul`, `ite`, `sum`, `prodOn`, `listSum`, `mul_const`, `const_mul`, `mul_or`) | a function does not read / is affine in one variable |
| **`AffAt.prod_one`**, `AffAt.prodOn_one` | a product in which at most one factor reads a variable is affine in it |
| `indDegLE_one_of_affAt` | affine in every variable gives individual degree `≤ 1` |
| `irDeg`, **`irDeg_map`** | the IR's degree in its tables, read off the IR's shape; it reads no coefficient |
| **`irEval_indDeg`** | if every table has individual degree `≤ 1`, the slot polynomial has individual degree `≤ irDeg ir` |

### 2.2 `BlockDefineClaim.lean`: a claim's value, unfolded through L10's weights (16 theorems)

| Theorem / definition | Statement |
|---|---|
| `addAt_getD`, `foldAdd_getD`, `zipAdd_getD`, **`zpartWeights_getD`**, **`zkeyWeights_getD`**, `zpartWeights_canon` | `zpart_weights` and `zkey_weights` entry by entry (words) |
| `eqMsb_toK`, `partRowK`, **`zpart_row_toK`**, `keyColK`, **`zkey_col_toK`** | a part's row weight is `coef·eq(point[..lr], bits(i − r0))` on its rows; the key's column weight is `eq(tail, bits(t − c0))` |
| `PartK`, `claimK`, `partK`, `PartOK`, **`claimSem_parts`** | L22's `claimSem` of a claim IS `Σ_i (Σ_parts coef·rowK_i)·Σ_t X_{i,t}·colK_t` |

### 2.3 `BlockDefineTab.lean`: the tables as functions of the slot's point (53 theorems)

| Theorem / definition | Statement |
|---|---|
| `xg`, `xrK`, `yeK`, `selK`, `cmK`, `toK_oneMinusProd`, `toK_maskCoef` | readers of a point; `sel = Π(1 − e_j)` and the mask coefficient on the verifier's words |
| `coordK`, `ptK`, `claimPoint_getD_toK`, `varsOKb`, `varsOK_spec` | a private table's claim point; "each challenge read at most once" as a checked condition |
| `CmData`, `PartSpec`, `privSpecs`, **`tabK`**, `buildClaim_partsK` | the tables' extensions: `sel·eq`, `sel·T̃`, and a private table's claim functional on its matrix |
| **`tabVal_toK`**, **`tabVals_toK`** | on an accepting slot whose claims are true, each terminal value the verifier computes is its table's extension at the slot's point |
| **`affAt_privTab`**, **`affAt_tabK`**, **`tabK_indDeg`** | every table's extension is affine in each variable (individual degree `≤ 1`) |

### 2.4 `BlockDefineSym.lean`: `define` as data (9 theorems)

| Theorem / definition | Statement |
|---|---|
| `Sym`, `Sym.eval`, **`Sym.eval_canon`** | coefficients and challenge words as expressions in the transcript's values; canonical on a canonical transcript |
| `CoordS`, `PrivS`, `TabS`, `SlotS`, `PubTabs`, **`defineS`**, **`defineS_ok`** | a slot program and `define` run on it |
| `cmCountS`, `cmCount_eval`, `privOKb`, `tabOKb`, `slotOKb`, **`progOKb`**, `progOK_getD`, `tabOK_eval`, `tabCanon_eval` | the facts that do not depend on the challenges' values, checkable by evaluation |

### 2.5 `BlockDefinePoly.lean`: the tables part, for every slot program (9 theorems)

| Theorem / definition | Statement |
|---|---|
| `histSeen`, `drSeen`, `histSeen_seenOf`, `drSeen_seenOf` | `define`'s inputs read off what the trace shows |
| **`polyS`** | the tables part of slot `k`'s polynomial: `irEval` of the IR on the tables' extensions |
| **`polyS_slotEvalN`** | L31's `hPoly`: `SlotEvalN U P cs (fun _ => 0) (polyS U P D prog pubs)`, for `P.define = defineS prog pubs`, a program passing `progOKb`, and `cs` the claim functional on `D` |
| **`polyS_indDeg`** | L31's `hdegP` |
| **`defineS_polyC`**, **`defineS_defCm`** | L31's `hpolyC` and `hdc` |

### 2.6 `BlockDefineFinal.lean`: the three statements, generic in the program (5 theorems)

Generated by `l35_mk_final.py` from L31's `BlockInstFinal.lean`.

| Theorem / definition | Statement |
|---|---|
| `xAof`, `xHof`, `rowsOfX`, `qOfX`, `colCast`, `xOfX`, **`dXof`** | the committed matrices: `A` and `H` as L31's `csXof` reads them, the endpoints' `XE` |
| `claimSem_cast14`, **`csXof_dXof`** | `csXof` is the claim functional on `dXof`'s matrices |
| `cntS`, `polyXof` | the program's tables per commitment; the tables part over `dXof` |
| **`block_knowledge_define_w16r2`**, **`block_knowledge_define_r13`**, **`block_knowledge_define_r13_shield`** | L31's `block_knowledge_final_*` with `aC`, `hC`, `hdc`, `hsA`/`hsH` on them, `Poly`, `hpolyC`, `hPoly`, `hdegP` gone, for every program `prog` with `hdef`, `hprog`, its counts `hsA`/`hsH`, `hlc`, and the endpoint premise `hcsE` |

### 2.7 `BlockDefineW16.lean`, `BlockDefineW16Rung.lean`, `BlockDefineW16Final.lean`: the W16R2 program (14 theorems)

| Theorem / definition | Statement |
|---|---|
| `W16Cfg`, `cstS`, `idsW`, `aOff`, `hOff`, `aDataRows`, `hDataRows`, `lookupsN`, `hIdsN`, `zeroPl`, `seg`, `claimPt`, **`rawSlot`**, `numProg`, **`progW16`**, `logupSumW16` | the W16R2 block's slot program, a function of its configuration (shape, precision, range families, row log) and the endpoints' mask rows |
| `numProg_ok`, `numProg_cm` | numbering the reserved mask rows changes no check and no count |
| `precRungW16`, `famsRungW16`, **`cfgRungW16`** | the rung's configuration (L13's `layout.txt`) |
| `progOKb_congr` | the check reads a row log only through its positivity |
| **`progW16_rung_ok`**, `progW16_rung_okP` | the rung's program passes its check (evaluated, `decide +kernel`) |
| **`progW16_rung_cntA`**, **`progW16_rung_cntH`**, `progW16_rung_sums` | its tables per slot are `aCntW16Rung`, `hCntW16Rung`; totals 114 and 46 + 1 = 47 |
| **`block_knowledge_define_w16r2_rung`** | the W16R2 rung block's statement at `prog := progW16 cfgRungW16 ioIn ioOut` |

### 2.8 `BlockDefineUnfold.lean`, `BlockDefineAlg.lean`: the join with lane L36 (16 theorems)

| Theorem | Statement |
|---|---|
| `polyS_apply`, **`polyS_seenOf`**, `polyXof_apply` | the tables part is a definition: at the trace's own view of slot `k` it is the slot's IR, at `define`'s inputs `histOf β γ α (rs.take k)` and `r.draws`, on the tables' extensions |
| `tabK_eq`, `tabK_pub`, `tabK_priv` | a table's extension by kind |
| `dXof_rows_a`, `dXof_rows_h`, `dXof_X_a`, `dXof_X_h`, `dXof_X_inp`, `dXof_X_out` | the committed matrices |
| **`block_knowledge_define_alg_w16r2_lk`**, **`block_knowledge_define_alg_r13_lk`**, **`block_knowledge_define_alg_r13_shield_lk26`** | L36's `block_knowledge_alg_*` (relation layers' algebra and lookup bridge discharged; the app's block at `2^26`) with `aC`, `hC`, `hdc`, `Poly`, `hpolyC`, `hPoly`, `hdegP` gone, as in section 2.6 (generated by `l35_mk_final.py`; arguments passed by name) |
| **`block_knowledge_define_alg_w16r2_rung`** | the W16R2 rung's, at its own program `progW16 cfgRungW16` |

## 3. The numbers

| | value | label |
|---|---|---|
| W16R2 rung program: `A` tables per slot | 1, 1, 22, 2, 2, 1, 1, 1, 2, 2, 1, 1, 1, 1, 21, 7, 7, 12, 9, 17, 0, 1, 1 (total 114) | PROVED from the program; equals L31's derived list |
| W16R2 rung program: `H` tables per slot | 0, 0, 0, 1, 0×10, 10, 3, 3, 6, 5, 17, 1, 0, 0 (total 46, + 1 LogUp sum claim = 47) | PROVED; equals L31's MEASURED list |
| `A` data rows (`aDataRows`), first reserved row | 90 | MEASURED (`SITES a` of L9's receipt: 228 rows, 90 to 317) |
| `H` data rows (`hDataRows`), first reserved row | 108 | MEASURED (`SITES h`: 92 rows, 108 to 199; the `u` plane at rows 106, 107) |
| agreement checks on the real rung receipt | 143 checks, 0 failed (23 × 6 per slot, the slot count, the plane count, 3 site lists) | MEASURED |
| private tables compared with the code by their plane id | 156 of 162 (the other 6 carry no plane id in the code's label) | MEASURED |
| negative control | 10 single changes, exactly 10 failed | MEASURED |
| Shieldstral R13 counts 146 / 54 (L31-3) | NOT confirmed: they belong to the R13 program, which is not written | LEFT |

## 4. The premises that are left, by name

`block_knowledge_define_w16r2_rung` takes, besides L31's run-level and public-data premises (`U`, `hU`, `hK2`, `key`,
`domain`, `hs`, `hL`, `hL64`, `hL20`, `hdrLen`, `hdrSq`, `hh`, `hq`, `csE`, `εend`, `hEnd`, `Pb`, `Lay`, `B`, `fams`,
`hF`, `hW`, `h24`, `xtE`, `q`, `A`, `hA`):

| Premise | What it is | Kind |
|---|---|---|
| `hP : IsRungW16 P tag rowsOf` | the profile (unchanged from L31) | definition of the profile |
| `ioIn ioOut : ℕ` | the endpoints' reserved mask rows (`Layout::io_mask_row`) | parameters |
| `pubs : PubTabs` | the block's public tables (folded weights, RoPE, gates, supports) | HYPOTHESIS-free parameter; see L35-2 |
| `hdef : P.define = defineS (progW16 cfgRungW16 ioIn ioOut) pubs` | the verifier's `define` is the rung's program | HYPOTHESIS on `P` (MEASURED against the code by `BlockDefineCheck`) |
| `hlc : P.logCols = 14`, `hep : 0 < P.endpointLogN` | the verifier's row logs | HYPOTHESIS on `P` (14 is the rung's `log_cols`, MEASURED by L13's export) |
| `rE`, `QE`, `XE`, `hcsE` | the endpoint commitments' semantics is the claim functional of some matrix (`csE cu rt cm z = claimSem … (XE cu rt cm) z` at `.inp`, `.out`) | run level (L31-6) |
| `spR`, `hdgR`, `hvR`, `hgdR`, `HGd`, `spH`, `hdgH`, `hvH`, `hgdH`, `Alk`, `T`, `mlk`, `hN`, `he`, `hbr`, `hhr` | L23's per-outcome algebra and the lookup bridge, now stated over `maskedFX … (polyXof … (progW16 …) pubs)` | HYPOTHESIS (lane L36) |

Gone against L31's `block_knowledge_final_w16r2`: `aC`, `hC`, `hdc`, `hsA`, `hsH`, `Poly`, `hpolyC`, `hPoly`, `hdegP`.

The generic `block_knowledge_define_w16r2` / `_r13` / `_r13_shield` take `prog`, `pubs`, `hdef`, `hprog`, `hsA`, `hsH`
(on `cntS`), `hlc`, `rE`, `QE`, `XE`, `hcsE` in place of those nine.

**The statements to cite.** At the app's block: `block_knowledge_define_alg_r13_shield_lk26` (NOT
`block_knowledge_define_r13_shield`, finding L35-8). At the W16R2 rung: `block_knowledge_define_alg_w16r2_rung`. The
`…_alg_…` statements take, in place of L31's `spR`, `hdgR`, `hvR`, `hgdR`, `hvH`, `hbr`, lane L36's premises: `sh`, `dt`,
`hform`, `enc`, `encHt`, `hspec` (`W16Spec` / `R13Spec`), `hTok`, `hHd`, `hformH`, `hTtab`, `hcov`, and `he` at `2^26`
for the app's block (L36 §4). L36's `hform` and `hformH` now read `polyXof`, a definition.

## 5. Findings

No statement of `Statements.lean` changed. No target weakened. No existing file changed.

**L35-1 (Low; for the coordinator and the run-level lanes): `defineS` refuses a non-canonical challenge word.**
`defineS` returns an error unless `α`, `β`, every earlier draw and the slot's draws are canonical words (`HistCanon`);
it needs this so that every coefficient is a canonical word (`Sym.eval_canon`). The code's field type holds reduced
words only, so the code never meets such a word. ARGUED, not proved here: the Lean verifier's squeezes return
canonical words, so the refusal never fires on a transcript the code accepts. If it did fire, the Lean verifier would
reject where the code accepts; the security statement would still be true, but about a stricter verifier. A lemma
"every squeezed word is canonical" at run level would close this.

**L35-2 (Medium; for L36 and the coordinator): the public tables `pubs` are a free parameter.** The statements hold
for every `pubs : PubTabs`. Nothing ties `pubs` to the block's public statement `Pb` / `B` (the folded weight
columns, RoPE tables, gates and supports). This does not make any statement false or vacuous. But L36's premises
(`hvR`, `hgdR`) relate `polyXof … pubs` to `W16Rels S Pb Lay B`, and can be proved only when `pubs` are the real
tables. L36 must state that link (`pubs k hist dr i` is the MLE table of `B`'s public column for slot `k`'s `i`-th
public table). The agreement check above compares the public tables' KINDS and places, not their values.

**L35-3 (Low; for the coordinator): `IsRungW16` / `IsRungR13` / `IsShieldR13` do not pin the row logs.** L31's
`csXof` reads `A` and `H` claims at row log 14, but the profile structures do not say `P.logCols = 14`. This lane
carries `hlc : P.logCols = 14` (and `hep : 0 < P.endpointLogN`) as premises; adding them to the profile structures
would remove them.

**L35-4 (Info): every slot polynomial's degree is now a computed fact at the rung.** `progW16_rung_ok` evaluates
`irDeg ≤ d` for all 23 slots of the rung's own IRs; L31 took `hdegP` on trust.

**L35-5 (Info): L31-1's pattern was checked for the new premises.** Each premise this lane adds can be met at the
real block: `hdef` by `P := ⟨…, defineS (progW16 …) pubs, …⟩` (and MEASURED to agree with the code's `define` as far as
L35-7 says); `hlc`, `hep` by the code's numbers; `hcsE` by `csE :=` the claim functional of the decoded endpoint rows,
which is what a run-level extraction gives; `hprog` and the counts are PROVED at the rung. None is a numeric bound
the block could exceed, and none quantifies over objects the verifier never produces (`polyS_slotEvalN` is a theorem,
not a premise, and is asked only at the verifier's own accepting slots). The premises this lane inherits are
L31's and L36's; of those, the one that cannot be met is L35-8's.

**L35-7 (Medium; for the coordinator and the next lane): what the agreement check does not cover.** `BlockDefineCheck`
compares, on one real W16R2 rung receipt: every slot's IR with its coefficient values, its tables in order with every
`eq` start and point, its hosted coefficients, the plane id of 156 of the 162 private tables, and the reserved rows of
`A`, `H` and the `u` plane. It does NOT compare: the private tables' log sizes, coordinates (`rho`, `flip`, `fixed`)
and extension rounds; the slice offsets of the 6 private tables whose code label names no plane (the `D` and `DM`
reads on the row axis, `MX` and `SUM` on `Dom::Ht`, the two endpoint tables); the offset
formula `aOff` / `hOff` beyond the totals `aDataRows = 90`, `hDataRows = 108`; the public tables' values (L35-2). The
corpora do not carry these. A test-only export of each slot's `build_claim` parts (offset, log size, coefficient,
point) on a real receipt would let the checker compare them all; it needs new test-only Rust, which this lane's brief
did not ask for.

**L35-8 (High for one statement; for the coordinator and the gap audit; repaired here): the Shieldstral statement on
L31's chain inherits an unmeetable lookup bound.** `block_knowledge_define_r13_shield` (BlockDefineFinal.lean) is
generated from L31's `block_knowledge_final_r13_shield` and keeps its premise `he : … ≤ 35,153,256`. The app's
Shieldstral T128 R13 block looks up 64,258,048 entries (L36-1, `lkCount_r13_shield_gt`), so that premise is false at
the app's block and the statement says nothing about it. The repaired statement is
`block_knowledge_define_alg_r13_shield_lk26` (BlockDefineAlg.lean), on L36's `block_knowledge_alg_r13_shield_lk26`
with `he ≤ 2^26`. The two rung statements are not affected (L36). `block_knowledge_define_r13_shield` is kept, as
L31's is, but must not be cited for the app's block.

**L35-6 (Info, method).** A large positional application of L31's statement timed out in `whnf` when an argument's
type was written `prog.map fun s => cmCountS .a s.tabs` in one place and passed as `aC` in another; naming the list
(`cntS`) fixed it. `decide +kernel` evaluates the whole 23-slot program's check in a few seconds.

## 6. What is left, and what the next lane needs

1. **R13 (deliverable 4).** LEFT for the concrete program. The generic statements `block_knowledge_define_alg_r13_lk`
   and `block_knowledge_define_alg_r13_shield_lk26` (and, on L31's chain, `block_knowledge_define_r13`) are PROVED for
   any slot program that passes `progOKb` against R13's schedule
   with counts 148 / 55 (rung) or 146 / 54 (Shieldstral). What is missing is `progR13`: the R13 slot programs. R13
   differs from W16R2 in the zero-check slots 14 to 19 (`A` tables 41, 15, 15, 17, 16, 3 against 21, 7, 7, 12, 9, 17)
   and in `SC_TAB`, whose IR is not transcribed (L17-9): L17's `SlotR13.lean` has the R13 IR builders for the other
   slots. Writing `progR13` as `rawSlot` was written, checking it against L17's R13 rung block corpus as
   `BlockDefineCheck` does, and evaluating its counts at the Shieldstral shape would settle L31-3.
2. **The public tables' values** (L35-2): a definition of `pubs` from `B`, checked against the code's public tables.
3. **The join with L36** (section 6.1): the value of `tabK` on the Boolean cube, then `hform`; `dt` and `hspec` built
   from the same planes; `sh`'s pad plane counts.
4. **Run level**: `hcsE` (the endpoint semantics), L35-1's canonical squeezes.

### 6.1 The interface for lane L36 (the per-outcome algebra)

Everything is in namespace `ZK60.Exec.Block`. `K` is the extension field (`[Field K] [Algebra GF K]`), `U` the square
root of 7 in it (`hU : U ^ 2 = algebraMap GF K 7`).

**The block's `define` as data.**
- `Sym` (`one`, `negOne`, `zero`, `base v`, `p16 k`, `p256 k`, `u64 n`, `alpha`, `beta`, `gtag t`, `dr slot i`, `add`,
  `sub`, `mul`, `neg`, `pow`); `Sym.eval (hist : Hist) (k : ℕ) (dr : List Fp2) : Sym → Fp2`.
- `CoordS` (`rho k`, `flip k`, `fixed v`), `PrivS` (`cm`, `slices : List (ℕ × Bool)`, `log`, `coords`, `maskRow`,
  `extRound`), `TabS` (`eq point start`, `pub i`, `priv p`), `SlotS` (`tabs : List TabS`, `ir : Ir Sym`,
  `hosted : List (ℕ × Sym)`, `nonzero : List Sym`).
- `PubTabs := ℕ → Hist → List Fp2 → ℕ → List Fp2` (public table `i` of slot `k`).
- `defineS (prog : List SlotS) (pubs : PubTabs) : ℕ → Hist → List Fp2 → Except String SlotDef`; `defineS_ok`.
- `progOKb (rl : Cm → ℕ) (prog : List SlotS) (slots : List (ℕ × ℕ × ℕ)) : Bool`; `cmCountS`, `cntS`.
- W16R2 (namespace `ZK60.Exec.Block.DefW16`): `progW16 (c : W16Cfg) (ioIn ioOut : ℕ) : List SlotS`, `rawSlot c s`
  (slot `s` before numbering: its tables in order and its IR as L13's builder `ssIr`, `tzcIr`, `lzcIr`, `rsIr`,
  `mmIr`, `bilIr`, `dzcIr`, `qzcIr`, `szcIr`, `fzcIr`, `tabIr`, `zsIr`, `ioIr` at `cstS` and the table positions
  written there), `cfgRungW16`. The table positions per slot are exactly L13's `SlotW16BuildCheck.build`'s (MEASURED
  equal to the code's by `BlockDefineCheck`), so L23's `*_code_eval` facts about those builders apply position by
  position.

**The tables' extensions and the tables part.**
- `CmData K P` (`rows`, `Q`, `X : (cm : Cm) → Fin (rows cm) → Fin (2 ^ rowLog P cm + Q cm) → K`).
- `tabK U P D n e x : Tab → K` at `x : Fin N → K` (`n` main variables, then `e` extension variables):
  `.eq point start ↦ selK n e x · eq(point, x[start..])`; `.pub v ↦ selK n e x · mle(v)(x[..n])`;
  `.priv p ↦ claimK (rowLog P p.cm) … (D.X p.cm) (privSpecs …)` (data parts `coef·sel` on the plane's slices at the
  claim point, then the reserved pair `cmK·1`, `cmK·u` on the mask rows at the point's tail).
- `polyS U P D prog pubs : (k : ℕ) → Seen → (Fin (n_k + e_k) → K) → K`
  `:= irEval ((ir_k.map (Sym.eval hist_k k dr_k)).map (Fp2.toK U)) (tabs_k.map (TabS.eval …) |>.map (tabK U P D n_k e_k x))`.
- `dXof tag hL20 P hlc h Q e rA rH rE QE XE cu rt : CmData K P`; `polyXof … prog pubs := fun cu rt => polyS U P (dXof … cu rt) prog pubs`.
  The statements' `F` is `maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280 8052 320 202 rE QE XE prog pubs)`
  at W16R2.

**Theorems L36 can cite**: `tabVals_toK`, `polyS_slotEvalN`, `polyS_indDeg`, `tabK_indDeg`, `affAt_tabK`,
`irEval_indDeg`, `irDeg_map`, `claimSem_parts`, `zpart_row_toK`, `zkey_col_toK`, `defineS_ok`.

**Unfolding lemmas (L36-2)**: `polyXof_apply`, `polyS_apply`, `polyS_seenOf` (at L36's `FormAt`'s own slot view:
`rs[k]? = some r`, `define`'s inputs `histOf bga.1 bga.2.1 bga.2.2 (rs.take k)` and `r.draws`, exactly the inputs
`FormAt` hands to `P.define`), `tabK_eq`, `tabK_pub`, `tabK_priv`, `dXof_X_a`, `dXof_X_h`, `dXof_X_inp`, `dXof_X_out`.

**The join with L36, by L36's names** (L36 §4 "The join with lane L35"):
- `hform : ∀ G bga rs acc, AccT … → ∀ k ∈ algHosts, FormAt U P (polyXof … prog pubs cu rt) (fun k h => (algSp U sh dt
  (card_K_gt K) 0 cu rt k h).Φ) bga rs k` is now a statement about a DEFINED polynomial. `formAt_host` reduces it to
  each host's cube sum of `polyXof … cu rt k (seenOf bga rs k)` being its named sum. What is still to prove, and what
  this lane leaves: **the value of `tabK` on the Boolean cube with the extension variables `0`.** There `selK = 1` and
  `cmK = 0`, so (i) an `eq` table's extension is `eq(point, bits)`; (ii) a public table's is the table's entry; (iii) a
  private table's is the multilinear extension of its plane (`D.X cm` at the slice) at the claim point whose `rho k`
  coordinates are the cube's bits, `flip k` coordinates `1 −` the bits and `fixed v` coordinates `v` (from
  `claimSem_parts`, `zpart_row_toK`, `zkey_col_toK`: the mask pair's coefficient is `0`). With that lemma, `polyS` on
  the cube is L13's builder evaluated on the planes' entries (`polyS_seenOf`, then L13's `*Ir_eval`), and L36's route
  (`hostTerms_hostPoly`, `host_cubeSum`, `matmul_sum`, `mleAt_append`, `rs_cubeSum`) applies.
- `dt : AlgData K L sh` and `hspec : R13Spec sh dt Pb Lay B xtE enc encHt` / `W16Spec …`: L36 asks the tables `dt.cl`,
  `dt.pw`, `dt.gh`, `dt.mm`, `dt.rsA`, `dt.rsB` to be the pullbacks of the relation tables through onto encodings
  `enc`, `encHt`. Building `dt` from `dXof`'s planes (`dXof_X_a`, `dXof_X_h` and the program's plane offsets `aOff`,
  `hOff`) and `xtE` from the same planes is the next lane's; this lane supplies the planes' places (`progW16`'s
  `PrivS.slices`, checked by plane id, L35-7) and the matrices (`dXof`), not `dt`.
- `sh : AlgShape P`: L36 asks the pad plane counts per host; `DefW16.zeroPl c d` is the program's list of the
  zero-rule planes of domain `d` (the pad group of each host's IR, MEASURED through the IRs' agreement).
- `pubs` (L35-2) must be the real public tables for `hspec` and `hform` to hold.

## 7. Checks

All in `results/zk60_lean_l35_20261109/`, each run as one job through the zk60 resource guard (class `cpu`,
`run_guarded.py`, need 14 GiB, cap 24 GiB).

- `iter1.log`, `iter2.log` (the first agent): `BlockDefineAff`, `BlockDefineClaim`, `BlockDefineTab` green.
- `iter3.log`: `BlockDefineSym`, `BlockDefinePoly` green; `BlockDefineFinal` timed out in `whnf` (L35-6);
  `BlockDefineW16` missing two imports.
- `iter4.log` (51 s): `BlockDefineFinal`, `BlockDefineW16`, `BlockDefineW16Rung` green, no warning.
- `iter5.log`, `iter6.log`: `BlockDefineW16Final` green; `BlockDefineCheck` 96 checks, 0 failed; negative control
  9 failed of 96.
- `check.log`: two runs of `check_l35.sh` before the merge of L36. The first (job `lean-l35-check`, exit 0, 98 s,
  peak RSS 21.62 GiB) was green in full on the nine modules of the time: 3,638 jobs, 0 warnings; 254 declarations
  (141 theorems) audited; scan none; clashes 0; `BlockDefineCheck` 96 / 0, negative control 9; regressions green. The
  second (`lean-l35-check2`, exit 1) stopped at a syntax error in the checker's new plane checks (fixed).
- `iter7.log`, `iter8.log`, `iter9.log`: the checker's plane checks (`String.drop` returns a slice in Lean 4.34; a
  structure-instance parse), then `BlockDefineUnfold`, `BlockDefineAlg` and the checker with ten mutations.
- **`check_final.log`** (`check_l35.sh` after the merge of L36, job `lean-l35-final`): section 7.1.

### 7.1 The full check

`check_final.log` (`check_l35.sh`, job `lean-l35-final`, exit 0, 83 s, peak RSS 3.72 GiB), on the tree with L36
merged (base `16acb7c8`):
- the eleven L35 modules built one target at a time, then the full build (`full.log`): **3,652 jobs, rc 0,
  0 warnings, 0 errors, no `sorry`**; 0 warnings in the L35 modules' own builds;
- the axiom audit (`axioms_l35.lean`, written by `gen_axioms.py`: every `theorem`, `def`, `abbrev` and `structure` of
  the eleven files; `axioms.log`): **270 declarations (157 theorems, 103 definitions, 2 abbreviations, 8
  structures)**; 103 on `[propext, Classical.choice, Quot.sound]`, 60 on `[propext, Quot.sound]`, 62 on `[propext]`,
  45 on none; no `sorryAx`, no `ofReduceBool`, no other axiom;
- the source scan of the eleven library files and `BlockDefineCheck.lean` for the forbidden words: none;
- the library root imports the eleven files and not the checker; `Statements.lean` unchanged; no existing file under
  `formal/` modified, deleted or renamed; no line removed from the root's imports; no file under `ops/` changed;
- the name-clash scan against the Lean files of all worktrees (`l35_nameclash.py`, `nameclash.log`): 0 clashes;
- **`BlockDefineCheck`** on L11's W16R2 rung receipt corpus and L9's corpus (`blockdefinecheck.log`): **143 checks,
  0 failed**: per slot (23 each) the IR's nodes, its terms, the tables, the hosted coefficients, the planes, their
  alignment; the slot count; the plane count (156); `SITES a`, `SITES h`, `SITES hu`;
- its negative control (`l35_mutate.py`: ten single changes, to a node and a term coefficient, a table kind, an `eq`
  start, an `eq` point word, a hosted coefficient, a plane label, the three site lists; copies written outside the
  repository; `negative_control.log`): **exactly 10 failed**, one per change;
- regressions: `L6Check` 1,206, `L5Check` 5,553, `L11Check` 404, the fixture L1 check 101,956; 0 failed.

The generated files (`BlockDefineFinal.lean`, `BlockDefineW16Final.lean`, `BlockDefineAlg.lean`) are the output of
`l35_mk_final.py` on this tree (re-running it reproduces them byte for byte). Not run by this lane: `ExecBlockCheck`,
`CheckR13Block`, `BlockInstCheck`, `BlockAlgCheck` (no file they read was changed), and the merged-tree check on perf,
which is the coordinator's.
