# Review of Lean lane L65 (Antigravity), 2026-11-17

Reviewer: Claude (independent, read-only on formal/, hashline/, ops/, docs/). Files under review: three untracked modules
`formal/ZK60Formal/RunStgShieldToK.lean`, `RunStgShieldDg.lean`, `RunStgShieldCTopDg.lean`, plus three import lines in
`formal/ZK60Formal.lean`.

## Verdict: ACCEPT WITH FIXES

The kernel facts are as claimed and I found no defect that makes a theorem false or vacuous. The concrete degree lists match the
Rust code (none is below it). The main issue is how the result is described: the new top theorem is a plain instantiation of the
L63 theorem. It discharges no premise, it does not use the new `stgDefsV_valid_*` lemmas, and those lemmas rest on premises that
the top theorem does not carry. Counts: High 0, Medium 2, Low 3, Note 5.

## Check 1. Hygiene (all pass)

- sha256 of the three files equals the posted hashes (cfd9b784..., e92be7f4..., 0924fb60...). Line counts 1771, 1741, 436 (newline count).
- `git diff formal/ZK60Formal.lean` is exactly three added lines: `import ZK60Formal.RunStgShieldToK`, `...RunStgShieldDg`,
  `...RunStgShieldCTopDg`, after `RunStgShieldCTopW` (diff stat 3 insertions). All three are L65's. No import for a later lane yet.
- `git status --short formal/` shows only that file modified and the three new files. `git diff --stat formal/ZK60Formal/Statements.lean` is empty.
- Scan for sorry, admit, axiom, native_decide, unsafe, implemented_by, opaque, extern, `decide := true`: no hits in code.
  Matches are only the docstring words "Only `propext`, `Classical.choice`, `Quot.sound`" (CTopDg:10, ToK:17, Dg:14).
- `set_option` lines: `autoImplicit false` (CTopDg:15, ToK:22, Dg:18) and `linter.constructorNameAsVariable false` (CTopDg:16, same as lane L63's files). Neither switches a check off in a way that affects soundness.
- `noncomputable def stgTabK` (ToK:692) and `open Classical in` before `stgSpT_eval_and_deg`, `offZero_standalone_draw`, `offZero_standalone_drawC`, `offZero_host_draw` (ToK:1438, 1487, 1588, 1647) are decidability helpers for `if IndDegLE ...` guards, the same device L63's `stgΦBC` uses (DefC:54). They do not make a statement trivially true.

## Check 2. Top theorem against `sshC_productionReadyL_epP_claimsW`

I extracted both signatures with `l65_review/sigdiff.py` and compared them. After deleting the binder `(dgI dgO : ℕ → ℕ)`
(CTopW:200) and substituting `ZK60.ProtocolClassify.sshDgI` for `dgI` and `sshDgO` for `dgO`, the L63 signature equals the L65
signature text exactly (the script prints `True`). So: no added premise, no strengthened premise, no weakened conclusion, same
conclusion `ProductionReadyL (classifyModelP Rp) ... εcTarget εsTarget εsTarget εzkTarget`.

Premises that mention dg: `hb0` and `hdinS` and `hdzW` mention `dgI` (4 occurrences with the binder); `hbL` and `hdoutS` mention `dgO` (3 occurrences with the binder). All
five are now stated at the concrete lists. The proof is a bare application of `sshC_productionReadyL_epP_claimsW` with
`(dgI := sshDgI) (dgO := sshDgO)` (CTopDg:401-430). **It discharges nothing.** See finding M1.

## Findings

### Medium

**M1. The top theorem is a specialisation, not a discharge (CTopDg:2-8, 102-106, 401-430).**
Evidence: the signature diff above. In L63 `dgI`, `dgO` are universally quantified binders. They carry no proof obligation of
their own. The obligations (`.Rbr`, `e ≤ 80`, `n·e ≤ 80·451` on the stage entries) live inside the premise `hD : D.Valid ...`
(`RtKData.Valid`, `r0 : RtSqOk ... 80 (80*451) D.r0`, RunTrKinds.lean:509), reached through `hDe`/`hb0`/`hbL`.
`hD` is still a premise of the new theorem, and the new proof never calls `stgDefsV_valid_inC` or `stgDefsV_valid_out`
(they are not referenced after their definitions). The new theorem is a corollary of the old one and strictly less general. The
header wording "removing `dgI` and `dgO` as free parameters" is literally true but could be read as closing a premise.
Fix: say so in the lane document (the L63 premise list is unchanged, `hD` still open for the stage `r0` entries). To make the L65 lemmas
count, add a lemma that builds the stage-`r0` conjuncts of `hD` from `stgDefsV_valid_inC/out` (see M2 for what that needs).

**M2. The validity lemmas need premises the top theorem does not carry (CTopDg:32-39, 56-63).**
`stgDefsV_valid_inC` takes `hlc : Vi.pub.lt ≤ lc`, `hIO0`, `hIO1` (`StgCsIODeg ...` for `csIO`), and 64-bit log bounds `hc0..hc2`.
`stgDefsV_valid_out` takes `hlc`, `hIO`, `hc0..hc3`. None of these is among the top theorem's premises (it has only `hIOI`/`hIOO`, which say the value argument is ignored, and
`hIOlI`/`hIOlO`). `StgCsIODeg` (ToK:1334) says `csIO` read at a built claim has individual degree ≤ 1 in the sumcheck variables.
This is exactly the L63 open item "csIOI/csIOO tied to the extraction" (L63 doc section 13): it holds when `csIO` is the multilinear
evaluation `claimSem` of a table (`stgCsIODeg_of_claimSem`, ToK:1348, which needs `min p.log eLog ≤ lcIO`), and nothing yet
shows that for the real run. So `e = 2` on the three IO-reading slots (IN-C slots 0 and 1, OUT-C slot 0) is conditional on that link. The premise can hold (the `claimSem` witness satisfies it under the `min` condition; I did not check that condition at the code's parameters).
Fix: state in the doc that `sshDgI/sshDgO` validity is conditional on `StgCsIODeg`, and either add these premises to a restated top theorem or record them beside the open `csIO` link.

### Low

**L1. "Full `D.Valid` entry bundles" is overstated (Dg header line 2; CTopDg:2).** `RtSqOk` (RunTrKinds.lean:487) has six conjuncts per entry: `SqCut`, `.Rbr`, `e ≤ emax`, `n·e ≤ ND`, window `pf.off i ≤ sx.a ≤ pf.off (i+1)`, plus `Pairwise (a ≤ a)` ordering. L65 proves the first four (the docstrings at CTopDg:30, 54 say "four", correct). The window and ordering conjuncts stay in `hD`. Fix: reword the header to "the four `r0` conjuncts".

**L2. Duplicated objects.** `ssh_inc_dg_count` and `ssh_outc_dg_count` (ToK:45, 50) restate L63's `ssh_inc_count` and `ssh_outc_count` (RunStgShieldRbr.lean:203, 210); the L63 IN-C version uses a uniform `1+1`, and `ssh_outc_dg_count` calls `ssh_outc_count`. `IndDegLE_mulc` (ToK:207) wraps `IndDegLE.cmul` (StageInExtractSlots.lean:60). They are consistent today. Fix: keep one family, or state the relation, so they cannot drift.

**L3. The 11 unfoldings skip IN-C's ZS slot.** IN-C has four slots, OUT-C eight (Rust stage_in_c.rs:43-50, stage_out_c.rs:75-84). L65 unfolds `incDefIO/QZC/TZC` (3) and all eight OUT-C builders. `incDefZS` has no draws and is handled by the `n = 0` argument (Dg:968-974), so no soundness gap, but "all 11 stage define builders" is 11 of 12. Fix: say "11 of the 12 builders; the twelfth draws nothing".

### Note

**N1. Fidelity of `sshDgI` and `sshDgO`, entry by entry (no entry is below the code).** Here `e = d + 1`, `d` the individual degree of the define polynomial in the slot's own draws, `+1` for the zero challenge that `nonzero` refuses. Source: R13 frozen tree `ops/zkp-mvp/token-io-review-r13-scratch/hashline/src/private_block/token_io/stage_in_c.rs:164-236` and `stage_out_c.rs:281-427`, with `zeta_fold` at `token_io.rs:1194`.

| Slot | Draws in Rust | Degree of the polynomial in the draws | Lean `e` | Verdict |
|---|---|---|---|---|
| IN-C 0 INC-00 IO | tau (lw) | 1 (eq) | 2 | upper bound (no refusal in the code, so 1 would suffice; the +1 is spare) |
| IN-C 1 INC-01 QZC | tau (ti_log), mu(4), zeta | 1 | 2 | equal |
| IN-C 2 INC-02 TZC | tau (voc_log), mu(2), zeta | 1 | 2 | equal |
| IN-C 3 INC-03 ZS | none | none | 1 | n = 0, irrelevant |
| OUT-C 0 IO | tau (d_bits) | 1 | 2 | upper bound (no refusal) |
| OUT-C 1 SS, 3 PD | none (hosted) | none | 1 | n = 0 |
| OUT-C 2 TZC | tau (TO_LOG=1), mu(4), nu, zeta | 1 | 2 | equal |
| OUT-C 4 LZC | tau (llo), mu(2), nu | 1 | 2 | equal |
| OUT-C 5 DZC | tau (ldo), mu(10 = 3+H_DO_HELPERS+1, H=6), zeta | 11 in zeta (`zeta_fold` over planes C_X..C_MULT-1 = 12 planes, powers 0..11) | 12 | equal |
| OUT-C 6 TAB | tau (ltab), mu(2), zeta | 1 | 2 | equal |
| OUT-C 7 ZS | none | none | 1 | n = 0 |

Draw counts and the refusal sets also agree: `Z_range` offsets and lengths in `ssh_inc_rbrC` (Dg:957-967) and `ssh_outc_rbr` (Dg:1678-1731) are IN-C 1: ti_log,5; IN-C 2: voc_log,3; OUT-C 2: 1,6; OUT-C 4: llo,3; OUT-C 5: ldo,11; OUT-C 6: ltab,3; slots 0 have the empty set. Each matches the `nonzero` calls in Rust. The Lean builders mirror the Rust text (for example `outcDefDZC`, StageVerifyExecOutC.lean:198-213, mu drop/take 10, zeta at ldo+10). The Lean polynomial is also what the Rbr proofs are about, so a degree below the Lean polynomial's true degree could not have been proved; fidelity to Rust therefore rests on L63's `StageVerifyExec*.lean` mirror, not on the list itself.
The bounds: `ssh_inc_dg_count` and `ssh_outc_dg_count` are proved from `sshDgI`/`sshDgO` themselves (ToK:45-55; the OUT-C one via `sshDegO k ≤ 11`), and `stgDefsV_valid_*` take `e ≤ 80` and `n·e ≤ 80·451` from them with `n` from `hPin`/`hPout` (CTopDg:45-52, 69-76). 80 and 80·451 are the `D.Valid` constants (RunTrKinds.lean:509). Not computed from smaller lists.

**N2. The unfolded terms are not fresh copies.** `incDefIO`, `incDefQZC`, `incDefTZC` (StageVerifyExecInC.lean:152, 165, 194) and `outcDefIO ... outcDefZS` (StageVerifyExecOutC.lean:140-230) are the executable verifier definitions, already used by `RunCoverDefine.lean` and `RunStgAlgHost.lean`. L65 adds only theorems about them (17 theorems `*_ok`/`*_err`). The R14 tree changed the verdict row and a pad clause (diff of stage_in_c.rs, stage_out_c.rs) but not draws or degrees, so the table in N1 holds for R14 too. (`outcDefIO` uses `O.verdictRow`, the R14 form; that is lane L63's business.)

**N3. The refusal branch is treated as rejection, and its probability is counted.** `*_err` theorems give `.error` when a Z coordinate is zero. Then `stgΦB`/`stgΦBC` is `0` (DefC:71, `| .error _ => 0`), and `OffZero` requires `Φ y = 0` there (RunStgShieldRbr.lean:36; engine at ToK:1583-1586). In `szSt_escape_offZero` (Rbr:44-...) the zero value is inserted into the escape set (`insert 0 p.roots.toFinset`), so every round's bound is `d + 1`. The zero draw is counted as a value the prover might get lucky on; it is never used to accept a false claim. This is conservative: the +1 is also paid on rounds with no refusal (IN-C 0, OUT-C 0).

**N4. Non-vacuity.** `ssh_inc_rbrC`, `ssh_outc_rbr`: premises `hU` (U^2 = 7, the standing field setting), `hPin`/`hPout` (`StgSame`, satisfied by the block's own schedule), `hlc`, and `StgCsIODeg` (see M2). No premise is an equality that forces a degenerate case. In the engines, `hdef_ok`/`hdef_err` quantify over y and are the two halves of `define`'s behaviour; they are consistent and discharged by the `*_ok`/`*_err` theorems. `tabsFit` failing yields `Pp = 0` (ToK:1524), a harmless degenerate branch. `indDegLE_claimSem_priv` has `hmin`, `hvars`, `hcan`, `hsl`, all properties the code's tables meet (tabPrivOK constructors prove them for each table). Two inherited behaviours: `stgDefSqV.St` is `True` when `tHistS` cannot parse the history (RunStgAlgList.lean:84-85), so unparseable histories carry no obligation (an L63 design choice); and `stgΦBC` is `0` where a table's degree exceeds the slot's declared degree (DefC:64). L65's content on the second point is useful: it proves the gate always passes on the eight slots (`hguard`, ToK:1553), via `indDegLE_claimSem_priv` and `stgTabK_indDeg`.

**N5. Name clashes and overlap.** 153 declarations in the three files (87 + 63 + 3). Short-name search against every other `formal/ZK60Formal/*.lean` declaration: 0 clashes, 0 duplicates inside L65 (`l65_review/names.py`). L65 depends on L63's `RunStgShieldRbr` (`OffZero`, `szSt_escape_offZero`, `ssh_outc_count`), `RunStgShieldDefC` (`stgΦBC`, `sshΦIC`, `stgSpTC`, `stgPolyT`-based facts), `RunStgShieldInst` (`sshΦO`, `sshΦI`), `RunStgShieldCTopW` (the top theorem), and the earlier `StageVerifyExec*`, `RunStgAlgList` (`stgDefSqV`, `stgDefsV`) files. Only L2 above is duplicated content.

## Check 6. Independent kernel check

Script `results/zk60_claude_review_20261116/l65_review/l65_kernel_check.sh` (axioms file `l65_axioms.lean`), launched with
`run_guarded.py` (class cpu, default poll), guard run `2d540a1bfe0f`, label `claude-l65-review-kernel`: **exit 0**, child wall 15 s, peak RSS 3.74 GiB, no queue wait.
- `lake build ZK60Formal.RunStgShieldCTopDg`: rc 0, "Build completed successfully (3833 jobs)", 3 s (the build directory was warm). 8 warning lines, all in other files (RunStgJoinLk, RunBlkWireDoom, RunBlkWireSlots, replayed). **0 warnings naming an L65 file.**
- `#print axioms` for 13 declarations, every one on exactly `[propext, Classical.choice, Quot.sound]`: `stgDefsV_valid_inC`, `stgDefsV_valid_out`, `RunShapeP.sshC_productionReadyL_epP_dg`, `ssh_inc_rbrC`, `ssh_outc_rbr`, `offZero_standalone_draw`, `offZero_standalone_drawC`, `offZero_host_draw`, `indDegLE_claimSem_priv`, `ssh_inc_dg_count`, `ssh_outc_dg_count`, `outc_ss_spT_deg`, `outc_pd_spT_deg`. 0 sorryAx, 0 ofReduceBool.
- Logs: `l65_review/kernel.log`, `l65_build.log`, `l65_axioms.out`.

## What I checked

Hygiene items 1 to 6 above; the full top-theorem signature diff by script; the Rust stage define code for IN-C and OUT-C
(R13 frozen tree, and a diff to R14) against the Lean builders, the draw counts, refusal sets and degrees; the Lean statements of `ssh_inc_rbrC`, `ssh_outc_rbr`, the three engines, `stgDefSqV_rbrZ_canon`, `indDegLE_claimSem_priv`, `StgCsIODeg`, `stgDefsV_valid_*`; `RtSqOk`/`RtKData.Valid`; the L63 document sections 13 to 15; name clashes by script; the axiom audit.

## What I did not check

- The proofs line by line (the kernel did that; my kernel check used the warm build directory, so the .olean files were replayed, not re-elaborated; this relies on lake's source-hash trace).
- That the `StageVerifyExec*.lean` mirrors equal the Rust byte for byte beyond the slots and draws listed in N1 (L63's lane).
- That `StgCsIODeg`'s side condition `min p.log eLog ≤ lcIO` holds at the code's real parameters.
- That `hD` for the real run is satisfiable end to end (this is the open gap in M1/M2).
- The 4 `open Classical in` theorems' use of decidability inside the proofs; the axiom audit shows only the standard three axioms.
- Anything outside the three files and the root's import lines; no regression suites were run.
