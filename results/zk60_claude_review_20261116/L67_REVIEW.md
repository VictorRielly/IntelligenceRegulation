# Review of Lean lanes L67 and L67b (Antigravity), 2026-11-17

Reviewer: Claude (independent, read-only on formal/ and ops/). Files under review, committed at `f5b70efe` on `perf/zk-batch-optimizations` (not pushed):
`formal/ZK60Formal/RunShieldInstP.lean` (1,377 lines), `formal/ZK60Formal/RunStgShieldLu.lean` (616 lines), and two import lines in `formal/ZK60Formal.lean`.
The author's claims are items 1 and 2 of the entry "Antigravity (co-coordinator) 2026-11-17T19:14:00Z" in `ops/zkp-mvp/RECOVERY_COORDINATION.md`, plus the two file headers.
Baseline: `L66_REVIEW.md` (its "open list after L66"). Marking: [CHECKED] = by me, with the command or line; [CLAIM] = the author's, not re-derived; [NOT CHECKED] = could not or did not.

## Verdict: ACCEPT WITH FIXES

Every kernel claim holds. Both files elaborate from source with no error and no warning, every declaration prints only the three standard axioms, and the machine accounting
of the top theorem against the `pinsHd` theorem confirms "96 binders eliminated" as a count of non-instance binders. I found nothing that makes a theorem false, nothing circular and
no premise dropped silently. But three things in the summary say more than the source does: (1) the top theorem is **not wired to the LogUp file or to the profile domain**, so `hLuStg`,
`eI eO ΛI ΛO`, `domain hs hL` and `hbij` are all still free there; (2) "concrete verifier" is true of the **shape and geometry** only, because the verifier's own checks
(`preA preB check0 paths digest bndCheck`) and the block parameters `Pk0` stay free; (3) `shd_ΛI` and `shd_ΛO` are concrete only modulo free arguments (`P`, `Epad`, `iB`, `I`, `O`)
and a trivially true predicate still meets every premise that mentions them except the three doom premises. Counts: High 0, Medium 2, Low 7, Note 6.

## What I ran

| Step | Guard run | Exit | Wall | Peak RSS | Note |
|---|---|---|---|---|---|
| Single-file elaboration of both files, `lake env lean`, no `-o`, LEAN_NUM_THREADS=2 (review copies = source + `#print axioms` for every declaration; the first copy also has a binder-dump appendix) | `3b7ebee43fe8`, `claude-l67-review-elab`, class build | 0 | 15 s (waited 111 s for the heavy lock) | 4.11 GiB | `l67_review/l67_elab.sh`, `inst_elab.out`, `lu_elab.out` |
| First meta run (signature dump, use analysis, hLuStg test, trivial-predicate examples) | `c18f0031f928`, `claude-l67-review-meta` | 0 | 17 s | 3.78 GiB | two bugs of mine (a `value!` panic on a theorem, and a syntax slip in the examples); the hLuStg test and the dump already worked |
| Corrected meta run | `145ae90db7e4`, `claude-l67-review-meta2` | 0 | 15 s | 3.78 GiB | `L67Meta.lean`, `l67_meta.sh`, `meta.out`, `sigp_*.txt`, `argmap.txt`, `use_top.txt`, `hlu_test.txt`, `reducibility.txt` |

The two Lean files were **elaborated from source by me**; no .olean was written (no `-o`), nothing was written under `formal/`. The meta run reads the author's `.olean` files of the two modules
(built 10:54 and 11:09) because Lean 4.34 does not expose the proof term of a theorem of the file being elaborated. I did not tie those `.olean` files to the source by hash, but the
binder list of the top theorem read from the `.olean` (`sigp_shieldInst.txt`) has the same 68 binders, in the same order, with the same names and types up to namespace qualification, as the one
from my fresh elaboration (`sig_shieldInst.txt`). The author's own guard runs (`fb78892e7557` build exit 0, 15 s, 4.29 GiB; `c24a37738154` axioms exit 0, 2.6 s, 3.59 GiB) are in
`results/zk60_resource_guard/history.jsonl` with those numbers.

## A. Kernel facts [CHECKED]

- **Hashes.** `RunShieldInstP.lean` `8f92c842...f65f`, `RunStgShieldLu.lean` `99121add...296b71`, and the `f5b70efe` blob of `ZK60Formal.lean` `e95f2789...6687` all equal the posted ones. The working copy of
  `ZK60Formal.lean` has since changed (527 lines, `261f6bb3...`): HEAD moved during my review to `152fdd2e`, the L63 lane's merge of `f5b70efe`, which adds that lane's own import lines. The two Lean files are byte-identical in
  the commit and in the working tree, and I elaborated the working copies. `git diff --stat f5b70efe -- formal` (at start) was empty.
- **What else changed under `formal/`** (`git diff --stat 2ae06f54 f5b70efe -- formal`): 3 files, 1,995 insertions, 0 deletions: the two new files and `ZK60Formal.lean` (+2: `import ZK60Formal.RunStgShieldLu`, `import ZK60Formal.RunShieldInstP`).
  `Statements.lean` and `RunBlkPinsHd.lean` are not in the diff.
- **Counts.** `RunShieldInstP`: 87 declarations, 69 public (44 theorems, 25 definitions or abbreviations), 18 private. `RunStgShieldLu`: 33 declarations, 30 public (16 theorems, 14 definitions), 3 private. Both match the claim.
- **Axioms.** `#print axioms` on all 87 + 33 declarations (`parse_axioms.py`, `parse_axioms.out`): `RunShieldInstP`: 47 print `[propext, Classical.choice, Quot.sound]`, 21 print `[propext, Quot.sound]`, 10 print `[propext]`,
  and 9 depend on no axiom. `RunStgShieldLu`: 31 print all three, 2 print `[propext]`. **0 outside the standard set, 0 `sorryAx`, 0 `Lean.ofReduceBool`.** The top theorem, `shdP_rtProf_valid`, `stgLkIn_rbr`, `stgLkOut_rbr` and `shd_hLuStg`
  print `[propext, Classical.choice, Quot.sound]`.
- **Messages.** 0 errors, 0 warnings, 0 other lines for both files.
- **Forbidden tokens** (grep over both files): no `sorry`, `admit`, `axiom`, `native_decide`, `unsafe`, `opaque`, `implemented_by`, `extern`, `decide +kernel`, `macro`, `elab`, `run_cmd`. The word "irreducible" appears in comments and in two
  `attribute` lines. `set_option`: `autoImplicit false`, `linter.constructorNameAsVariable false`, and `quotPrecheck false` at `RunShieldInstP.lean:1034` (see N3). The only `absurd` is at `RunStgShieldLu.lean:111` (benign, see D2).
  No `exfalso`, `False.elim`, `nomatch`.
- The summary's "0 B diff on Statements.lean" is consistent with the diff stat. "0 short-name collisions across all 518 files" I did not check.

## B. Premise accounting by machine [CHECKED]

Method: the signature of both top theorems printed by Lean itself (`forallTelescope`, with a Prop flag per binder; `sigp_pinsHd.txt`, `sigp_shieldInst.txt`), diffed by name (`sigdiff2.py`, `sigdiff.out`); and the **argument map**:
`argmap.txt` is the proof term of `sshC_productionReadyL_epP_shieldInst` with the `have`s peeled, whose head is `RunShapeP.sshC_productionReadyL_epP_pinsHd` applied to 154 arguments; for each of the 154 binders of the `pinsHd` theorem
it prints the term supplied, and whether that term is a forwarded binder of the new theorem (`argmap_summary.txt`). Because the proof is `exact pinsHd ...`, **the kernel accepting it proves the conclusions agree after the substitution**
(printed in `sig_shieldInst.txt`: `Lb := 26`, `start := clsStart domain key hw`, `inc := fun _ => shdP_incV ...`, `Pk := shdP_clampPk Pk0`, `bndOpen := cbBndOpen tag 38`, `hon := shdP_honestIn tag epBase`, and so on).

Counts. `pinsHd`: 154 binders (8 instance, 146 other; 81 Prop, 66 data or type; 140 explicit). `shieldInst`: 68 binders (8 instance, 60 other; 24 Prop incl. one instance, 37 data or type; 55 explicit).
**Removed by name: 96 non-instance binders (95 explicit and the implicit `pos`): 59 Prop-valued and 37 data. Added: 10 (2 Prop, 8 data). Kept by name: 50, of which 37 keep their text and 13 change text.**
So **"96 binders eliminated" is confirmed** as a binder count. Two cautions: 37 of the 96 are data (shapes, geometry, verifier components), not premises, and 10 are new, so the net is -86 (explicit 140 to 55, net -85). Of the 59 removed Prop binders one (`hPkD`) is
not discharged but renamed (below), so **58 Prop premises are proved, 1 is carried under a new name.**

| Group (removed binders) | Supplied by | How |
|---|---|---|
| `Rr dR pos hpos place hplace` | `6`, `1`, `shdP_epPos`, `shdP_epPos_injective`, `shdP_epPlace`, `shdP_epPlace_injective` | definitions and proofs in the file (lines 51-64) |
| `Lb hLb1 hL81` | `26`, private `zero_lt_26`, `omega` from `hL20` | trivial |
| `start inc incG outc outcG Vi F sgeom check bRows bLogN bndOpen Pk h64 hr hon` | `clsStart domain key hw`, `shdP_incV`, `rcIncGeom .. 28`, `shdP_outcV`, `rcOutcGeom .. 28`, `shdP_sgeom`, `vdChk check0`, `38`, `14`, `cbBndOpen tag 38`, `shdP_clampPk Pk0`, `le64_of_le20 hL20`, `shdP_hr`, `shdP_honestIn tag epBase` | ordinary definitions (C) |
| `Rn hv hRn hσ` | `shdP_rtRun`, `shdP_rtProf_valid`, `shdP_rtRun_hdr`, `shdP_rtRun_σs` | def + lemmas (`rfl` for hdr and σs), computation for Valid |
| `cx0 pin pout Iin Oout bp wXk gXk mXk` | `rcCx0`, `rcIncPart`, `rcOutcPart`, `shdP_Iin`, `shdP_Oout`, `shdP_rtBlk`, `1+1+38`, `2`, `64` | defs |
| `hgeo hIA hIH hOA hOH hBA hBH htI htO htB hbpRows hinc houtc hchk hlscIn hlscOut hmIn hkIn hkOut hXk hwXk hmXk hwX0 hmX0 hOX hwXo hXep hRr` | `rfl`, the existing `rcIncAt_pA_stage` etc., `shdP_rtBlk_pA_r13`, `vdChk_le`, `shdP_incPub_logs`, `shdP_incLay_nums`, `cbBndPcs_r13`, `rcOutcAt_pX_bnd_r13`, `rcIncAt_pX_ep` | proved |
| `hfIA hfIH hfOA hfOH hfBA hfBH hfIM hfOM hfBM hfitXk hfitXo hfitX` | `omega` after rewriting with the computed layout numbers | proved |
| `pXk lscIn lscOut mIn kIn kOut` | `cbBndPcs tag 38`, `(ViS).lay.logupSumClaim`, `(FoS 0).lay.logupSumClaim`, `15`, `8`, `14` | defs |
| `P0in P0out hNin hNout hN64I hN64O hPin hPout` | `shdP_P0in`, `shdP_P0out`, `shdP_hNin`, `shdP_hNout`, `shdP_hN64I`, `shdP_hN64O`, `shdP_hPin`, `shdP_hPout` | defs; the four `N` facts by `decide` over the 4 and 8 slots |
| `hSm hlcStg hLay` | `⟨pin.S = 4, pout.S = 8⟩` with `norm_num`; `⟨12 ≤ 12, ..⟩`; `shdP_stgInLay_incPub` | **discharged** (see below) |
| `hPkD` | `shdP_shieldRunAtD_clamp hPk0` | **renamed**, not discharged |

New binders: `hhdrFit` (Prop), `hPk0` (Prop), `check0 embDigest embFold bInRow wDigest bOutRow Pk0 epBase` (data).
`hhdrFit : ∀ hd, 64 + ((hw hd).shape.length + (hw hd).params.length + (hw hd).chunk.length + 84) ≤ Lq` is the header-fit fact that used to sit inside the `RtRun` premise `Rn`; it is now needed to build `shdP_rtRun`. It is a new premise in the list (see L1).

Thirteen premises changed text (`E0 O hIOlI hIOlO hCsIO hLuStg hTrIIO hTrOIO hLI_stg hLO_stg hdinS hdoutS hdzW`): all because removed binders were substituted by their values (for example `(RtRun.pf Rn).off (Lb+1)` became `.off 27`, `mIn * eI` became `15 * eI`,
`Vi.pub.epLogN` became `8`). Each is forwarded unchanged to `pinsHd` (all 13 are `FORWARD` in the argument map), so the statement is the old one after substitution.

**The four you asked about.** `hLay`: **discharged** by `shdP_stgInLay_incPub` (line 212), see C4. `hSm`: **discharged**: `pin.S = 4` and `pout.S = 8` are computed (lines 990-1001) from the Lean layouts `incLay`/`outcLay`, then `2*4+2 ≤ 2^20`.
`hlcStg`: **discharged**, but only as `12 ≤ 12`: `Vi.pub.lt` is *set* to 12 by `shdP_incPub` (line 143) and `ogStage.lc` is 12 by definition; the correspondence to the Rust (`stage_log_n = 12`) is real (I checked, C3) but it is a constant, not a derivation.
`hPkD`: **remains**, as `hPk0 : ShieldRunAtD tag dPos0 Pk0 Rp.blks 26` (a section variable, hence an explicit argument of the theorem). It is the old `hPkD` at `Pk := shdP_clampPk Pk0`, `Lb := 26`: for `k < 26` the clamp equals `Pk0 k`, so the two are equivalent
(`shdP_shieldRunAtD_clamp` proves one direction, the other is `shdP_clampPk_lt`); it is neither weaker nor stronger. `dPos0` remains a free explicit parameter, not fixed to `shieldDPos0`.

## Findings

### Medium

**M1. The top theorem is not wired to `RunStgShieldLu`, to `shdP_runDomain` or to `shdP_fp2_bijective`.**
`RunShieldInstP.lean` imports only `RunBlkPinsHd` and `RunStgAlgCount` (lines 27-28). In `sshC_productionReadyL_epP_shieldInst` the premises `hLuStg`, `eI`, `eO`, `ΛI`, `ΛO` (lines 1113-1116) are still premises, and `domain`, `hs`, `hL` (1012-1013, `hs hL` in the
binder list) and `hbij` are still free; `shdP_runDomain` (972) occurs only in its own two lemmas (977-982), `shdP_fp2_bijective` (985) nowhere. The header (line 5) says the profile domain is "instantiated on top of" the theorem, and the entry lists
`shdP_runDomain (73 bytes)` among what the top theorem is built from. Accurate: `shdP_runDomain` is an exported constant (its 73 bytes equal Rust's `RUN_PROFILE_CLASSIFY_R13_SHIELD_T128`, C3) with two lemmas that discharge `hs` and `hL` *if* a caller sets `domain := shdP_runDomain`;
the top theorem holds for every domain. Likewise `shd_hLuStg` matches the `hLuStg` premise (D4) but is not applied. Nothing is false; it is a scope overstatement, and the join with L63 and L67b is still to be written.

**M2. `shd_ΛI` and `shd_ΛO` are concrete only modulo free arguments, and nothing yet ties them to the planes the doom premises read.**
`shd_ΛI U tag h64 P I Epad iB iA` has `P : InPublic shieldS0`, `I : IncPub`, `Epad`, and the two view positions as arguments; `shd_ΛO U tag h64 O iA` likewise. The readers use hand-typed plane constants: A_in `(rows 41, ogStage dims)`, B_in `(14, 16, 256, 24448, rows 38)` at plane `(offset 0, log 19)`
indexed by `Fin.append (msbBits 7 t) c` (lines 571-577), A_out rows 76. The docstring says `iB = pf.off 0 + 2`, but `iB` is a free argument of `shd_ΛI` and `shd_hLuStg`. Nothing in the files says these readers coincide with the planes `InOkP`/`epxBndE` read
(that is exactly what `hdinS`, `hdoutS` and `hLI_stg` must deliver for these predicates). The bit order `msbBits 7 ++ msbBits 12` is the same convention as `dPos0`, whose agreement with the Rust layout is itself not proved (L66 review L2). No unsoundness (the premises are open), but "concrete `shd_ΛI`/`shd_ΛO`" is not "the stage's Λ".

### Low

**L1. Counting wording.** "96 binders eliminated" is right as a binder count; it is not 96 premises (59 Prop, of which 58 proved and one renamed; 37 data), and 10 binders are new (`hhdrFit`, `hPk0` and 8 data). Net -86 non-instance, -85 explicit. `hhdrFit` is a relocated old obligation (a field of `Rn`), now visible.

**L2. The clamp is harmless but the conclusion is about the clamped verifier.** `shdP_clampPk Pk0 k = Pk0 (min k 25)` (line 395). It exists because `pinsHd` asks for `bp : ∀ k, RtBlk Lq (Pk k)` for **all** `k : ℕ`, while `ShieldRunAtD` only speaks about `k < 26`. For `k < 26` the clamp is the identity
(`shdP_clampPk_lt`, proved), `hPk0` quantifies only `k < 26`, and `classifyProtocolExec_verify_iff` (`StageVerifyExec.lean:~590`) shows `verify` reads the blocks `List.range L` only, so with `L = 26` nothing reads `Pk k` for `k ≥ 26`. So the clamp cannot make a premise true for a verifier that differs from the
registered one; the premise is still about `Pk0` on `0..25`. What the file does not prove is the equality of `ProtoS` (built from `clampPk Pk0`) with the protocol built from `Pk0`; it follows from the cited lemma, not from a theorem in the file. This is not a High finding.

**L3. Global, persistent `@[irreducible]`.** `attribute [irreducible] shdP_wDelta` (line 171) and `shdP_rtRun` (962) are **not** `local`; the imported environment reports `irreducible` for both (and for `shdRkD`, `shdRkBase` from L66) (`reducibility.txt`).
The facts the theorem needs are proved *before* the attribute: `shdP_wDelta_eq/length/getD` (159-169) before line 171; `shdP_rtRun_hdr/σs/pf/rd` (668-773) and `shdP_rtProf_valid` (907) before line 962. Downstream, `rfl` and `unfold` on these names fail; there is no lemma giving numeric `(RnS).pf.off k`
(a downstream proof must rewrite with `shdP_rtRun_pf`, whose right side has `hdrLen = 8`). L63 should be told.

**L4. `hSm` and `hlcStg` discharges rest on the Lean layout model.** `pin.S = 4` and `pout.S = 8` come from `shdP_incLay_nums`/`shdP_outcLay_nums` (`incLay`, `outcLay` of earlier lanes, computed by `simp`/`norm_num`); their agreement with `stage_in_c.rs`/`stage_out_c.rs` is the earlier lanes' unproved correspondence, unchanged by this lane.

**L5. Hypotheses of the bridges and of `shd_hLuStg` that the summary does not state.** `shd_hLuStg` needs `hV : P.V ≤ 2^17`, tight at the real vocabulary (131,072 = 2^17, Rust `embed_tokens [131072, ...]`); `not_stgLkIn_nil_of_not_inGood` needs `hV` and `Function.Injective (Dof v).vid`, which for `shdIncData` needs `P.Valid` (`inDataOf_vid_injective`); nothing supplies `P.Valid` here.

**L6. Wrong references in item 2.** `inSat_of_inGood` does not exist; the lemma is `in_inSat` (`StageInExtract.lean:258`). `in_lookup_sound` is at line 130 (not 132). `IncBosTmpl` is a definition at `StageInExtractSlots.lean:307` (line 402 is a theorem using it). `InGood` at `StageInExtract.lean:77` is correct and is the `InGood` of `not_stgLkIn_nil_of_not_inGood` (the only definition of that name). `stgLkOut_two` is not `Iff.rfl`: it is `lkStByte_two`, which needs a case split on the two-element list, then `rfl` (no mathematics, but not a bare `Iff.rfl`; `stgLkOut_nil` is).

**L7. "Unblocking L63".** `shieldInst` sits on `pinsHd` (the L66 line). L63's `sshC_productionReadyL_epP_dz` sits on `blkAlive`; `sshC_productionReadyL_epP_pdz` and `_trO` exist only on the L63 branch / the later merge `152fdd2e`, not at `f5b70efe`.
The helpers `shdP_hVi`, `shdP_hwO`, `shdP_hwB`, `shdP_epPlace_val` are stated for that other line and are **unused** in `shieldInst`. No theorem yet combines the two lines. Whether L63 is unblocked is a statement about the merge, not about these files.

### Note

**N1. Numbers.** 270,492 squeezes and 283,822 operations are **proved by computation in Lean** (lines 905-960), not stated: `515 + 26*10359 + 643 = 270,492 < 2^64`, `8 + 605 + 26*10862 + 797 = 283,822 ≤ 2^21` (I recomputed both), from per-part facts `pin.len = 605`, `pin.sq = 515`, `pout.len = 797`, `pout.sq = 643`, block `10,862` and `10,359`
(`shdP_incPart_nums`, `shdP_outcPart_nums`, `shdP_blkPart_nums`, via the Lean layouts and the existing `r13_shield_counts : 1283, 844`). The 73-byte domain: 73 bytes, equal to the Rust string (C3); `startMsg` 85 bytes is in a comment only (`startTag` is 12 bytes; the lemma proves `≤ 100` by `decide`).
26 layers: `shieldExport_l17 : shieldExport.length = 26` (existing, by `decide`). T = 128: `shieldS0 := carrier 128 3072`. The three `clog2` values at 18, 128, 256, 4096, 131072 are proved (lines 108-124).

**N2. Vacuity (E).** Checked: (a) all 68 binders of the top theorem occur in the proof term (`use_top.txt`: 0 with `inBody=false`; a weak test, since the term mostly passes them on); (b) no step derives the conclusion from a contradiction (no `False.elim`/`exfalso`; the `Decidable.byContradiction` terms in the proof are `omega` outputs for arithmetic such as `81 ≤ Lq`);
(c) the concrete definitions cannot make a remaining premise unsatisfiable by themselves: the remaining premises mention only `csIOI csIOO` (free), `ΛI ΛO eI eO` (free), the concrete run and the free `E0`; `hLuStg` is satisfiable (D4); `hdzW`'s index range `128 ≤ i < 256` is non-empty; (d) index types: `Fin 1`, `Fin 7`, `Fin 12`, `Fin 256`, `shieldS0.Tok = Fin 128`, `shieldS0.Pos` are non-empty;
`ι` and `Hdr` are free types (as before; an empty `Hdr` makes `hhdrFit` vacuous, harmless); `Coins` is `Nonempty`. Not checked: that one instance satisfies all premises at once (nobody has built one).

**N3. `set_option quotPrecheck false` and the eleven `local notation`s** (1034-1079) only affect parsing inside `section ShieldTop`; the kernel types are the real ones, dumped in `sig_shieldInst.txt` (no notation survives).

**N4. `E0` is free and appears only in `hdinS` and `hdoutS`** (`sigp_shieldInst.txt`); `O` and `hzk` do not mention it. The answer in item 2 ("zero collision with L67, O or hzk") is correct for this theorem.

**N5. HEAD moved** to `152fdd2e` (L63's merge of `f5b70efe`) while I worked; this does not affect the review (same bytes for the two files, see A). Its commit message says it rebuilt the merged tree and audited `shieldInst` on the three standard axioms.

**N6. Entry sentences I could confirm** (item 1): 69 and 30 public declarations; the sha256s; the guard run numbers; "4 bridge theorems exist" (`stgLkIn_of_inLogUp`, `not_stgLkIn_nil_of_not_inGood`, `stgLkOut_nil`, `stgLkOut_two`); `shdP_epPlace_val` is `rfl` (line 61); `shdP_eI = 2^19`, `shdP_eO = 2^16`; "polymorphic in `Dof` and `(limbOf, plOf, multOf)`"; "`E0` free".

## C. Honesty of the concrete definitions

All of the following are ordinary definitions (`def`, `noncomputable def`, `abbrev`) with no axiom, `opaque` or `implemented_by`. None is a premise; they are compositions of the earlier lanes' Lean model of the Rust verifier (`classifyRunV`, `incVAt`, `outcVAt`, `rcRunClassifyAt`, `d12aBlockProf`) at T128 R13 constants.

| Object | What it models | Proved in Lean | Only asserted (comment) or inherited | My Rust check |
|---|---|---|---|---|
| `shdP_epPos`, `shdP_epPlace`, `shdP_cin`, `shdP_honestIn` (51-100) | input token endpoint: token `t` at row 0, column `t`; plane `1 x 256`; `R = 6` rows | injectivity, `StgInLay` (`shdP_stgInLay`), `8*R ≤ Lq`, the `HonestIn` fields (`rfl`/`simp`) | `Rr = 6`, `dR = 1`; `epBase` is free | `input_plane`: `ep[t] = id_t` in a vector of `in_ep_words = max(t_pad, 2^8) = 256`; `MASK_ROWS = 5`, so `1 + 5 = 6` rows: agree |
| `shdP_stgDim`, `shdP_epDim` | PCS dims `⟨Q, ·, N, log N⟩` | nothing (constants) | all | tier `R1_MVP`: `opened_cols 256`, `stage_log_n 12`, `stage_inv_rate 4`, `ep_log_n 8`, `ep_inv_rate 8`, so `N = 2^14` and `2^11`: agree. The second field (`2^12+256`, `2^8+256`) not checked |
| `shdP_incPub`, `shdP_incGeo`, `shdP_outcPub`, `shdP_outcGeo` | stage IN-C / OUT-C public data and geometry | log values (`tiLog 12`, `vocLog 17`, `inEpWords 256`, `rBits 12`, `incHeadDraws 15`, `llo ldo ltab dBits 12`); layout numbers (`aRows 41`, `hRows 76`, `nFunctionals 8`; `76`, `38`, `14`; the slot lists) by `simp`+`norm_num` | `tokens 128`, `tPad 128`, `dPad 4096`, `v 131072`, `lt 12`, `epLogN 8`, `d 3072`, `bLogN 14`, `bRows 38`, `epDataRows 1`, `epRows 6`, `bDataRows 32`, `bSites 2`, stage index 27, `lr 2`, `elr 3`, `blr 2`, `q 256` | `v = 131072` (embed table `[131072, ..]`); `T128` log cols 14; boundary rows `(128*4096 >> 14) + 5 + 1 = 38`, data rows 32, sites 2; `d_pad 4096`: agree. `lr`, `elr`, `blr`, stage index 27 not checked |
| `shdP_wDelta` | `List.ofFn` of the 3072 weight deltas, `irreducible` | length 3072, `getD` equation, before the attribute | none | n/a |
| `shdP_P0in`, `shdP_P0out`, `shdP_Iin`, `shdP_Oout` | stage block params and opening contracts | `hNin..hN64O`, `hPin`, `hPout`, the opening-contract side conditions (`2^12+256 ≤ 2^15` etc., `norm_num`) | `lr 2`, `elr 3`, `28` segments (= `26+2`) | not checked |
| `shdP_clampPk`, `shdP_rtBlk`, `shdP_blkPcs`, `shdP_sgeom`, `shdP_blockProf` | the 26 block parameters and PCS data | `RtBlk` fields from `hPk0` for **every** `k` (`hokA`, `hokH`, `hgt`, `hgeomL`, `hPm`, and the counts `146/54/1/1` from `hPk0` and the existing `progR13_shield_cnt*`) | `S = 23`, `nA = 146`, `nH = 54`, `m = 64`, `wX = 40`, `gX = 2` (inherited from L66) | rows `4577` (A shape `4577 x 2^14`), `4390` (fixture), `76` and `6` stage shapes: agree |
| `shdP_runV`, `shdP_rtRun` | the run verifier and its `RtRun` | `hdr`, `σs`, `pf`, `rd` equations (`rfl`); `pf.Valid` (N1) | `hdrLen = 8` | not checked |
| `shdP_runDomain` | transcript domain | `decodeLink (startMsg ..) = none`, length `≤ 100` | that the run's transcript domain is the profile string | the 73 bytes **equal** `RUN_PROFILE_CLASSIFY_R13_SHIELD_T128` in `run.rs:153` (script `domain_check.py`); `Transcript::new` hashes `"hashline-v1/" || domain` (12-byte prefix = `startTag`) |

What stays free in `shdP_runV`: `preA`, `preB` (pre-header checks), `check0` (statement check; only `vdChk_le` is proved of it), `paths`, `digest`, `bndCheck`, `hw` and `hhdrFit` (header words), and `Pk0` (constrained only by `hPk0`). Since the theorem quantifies over them, it holds for the registered values; the cost is that the
stage and block premises still mention them (L1, M2). So "concrete verifier" is accurate for shape, geometry and layout, not for the verifier's checks.

**C1 (clamp).** See L2: `min k 25`; only `k ≥ 26` is affected; no read of those blocks; no High finding.

**C2 (`@[irreducible]`).** Global (L3). Facts needed are proved before the attribute and used in the theorem (`shdP_rtRun_hdr`, `_σs`, `shdP_rtProf_valid`, and the `wDelta` lemmas only inside the file).

**C3 (numeric claims).** All proved by computation (N1) except the three Rust-side constants that are asserted; I looked up the following in the Rust under `ops/zkp-mvp/gpu-metal/hashline/src/private_block/` and **they agree**: the domain string (byte for byte, 73); the token endpoint layout and tier constants (`token_io.rs:190`, `token_io/classify.rs:905-920`, `endpoint_g.rs:92`); vocabulary 131,072 and T128 log cols 14 and boundary rows 38 (`shape.rs:483-488, 2284`); the LogUp challenge order for IN-C (`stage_in_c.rs:255-258`: `beta, gamma, alpha, r_emb`, `g_emb = gamma*TAG_EMB`) and OUT-C (`stage_out_c.rs:576-578`: `gamma, alpha`, `g_u8 = gamma*TAG_U8`), which are the coordinate orders `y0 = β, y1 = γ, y2 = α, y(3+c) = r_emb c` and `[γ, α]` that D uses.
I did not check the layout correspondences (`incLay`, `outcLay`), `lr`, `elr`, `blr`, stage index 27, `hdrLen = 8`, that `tagU8`/`tagEmb` in Lean equal `TAG_U8`/`TAG_EMB`, or that the run's transcript domain is the profile string.

**C4 (`hLay`).** `StgInLay pos tokens words := dR * 2^8 = words ∧ ∀ k i, (∃ t, pos t = (k, i)) ↔ k*2^8 + i < tokens`. It is proved at `pos = shdP_epPos`, `dR = 1`, `tokens = 128`, `words = 256` (`shdP_stgInLay`, then rewritten with `inEpWords = 256` in `shdP_stgInLay_incPub`). The position map is **the code's** word layout (`input_plane`: `ep[t] = id_t`, plane 1 x 256), not a convenient one;
the Lean model of the code (`epPos t = (0, t)`) is what is proved, and its agreement with the code is the check I did above.

## D. The LogUp file (`RunStgShieldLu.lean`)

**D1. What the predicates are.** Both are predicates on `v : StgVw Lq` (the stage's view of the log: cuts and header) and a challenge prefix `τ : List (List UInt8 × K)` (messages empty, one challenge per entry).
- `shd_ΛI U tag h64 P I Epad iB iA v τ := szSt (incClearedPoly (shdIncData .. v)) τ` (`stgLkIn`, 405-408, 580-584). `szSt Φ τ` (`RelW16Chain.lean:50`) means: `Φ y = 0` for **every** `y : Fin 15 → K` that agrees with the challenges read so far. `incClearedPoly D y` is the division-free cleared LogUp numerator
  `Σ_t Π_{t'≠t}(α − A_t') · Π_j (α − T_j)  −  Σ_j m_j · Π_t(α − A_t) · Π_{j'≠j}(α − T_j')` with `y0 = β, y1 = γ, y2 = α, y(3+c) = r_emb c`, `A_t = fold β γ (qTup t)`, `T_j = fold β γ (tTup j)`, over the 128 token positions and the `V` table rows. So at the empty prefix it says "the cleared numerator vanishes as a function"; at a full prefix "it vanishes at the drawn point".
  `shdIncData` reads the token words from A_in (rows 41), the `B_in` rows from B_in (plane log 19), the multiplicities from A_in, and takes `Epad` and `P` as arguments.
- `shd_ΛO U tag h64 O iA v τ := lkStByte (limbOf v) (p1 kc) (p2 kc) (multOf v) tagU8 τ` (`stgLkOut`, 143-151, 212-215): `τ = []` or one challenge: `AllBytes` (every looked value, the 4096 limb words and the `2 x 24576` pair words, is a byte `0..255`); two challenges `(γ, α)`: `∃ H, ByteLogUp ... (γ, α) H` (the helper relation of the byte LogUp holds, table side shifted by `γ·TAG_U8`); any longer prefix: `True`.

**D2. The round-by-round statements are genuine.** `SqX.Rbr` (`RelW16Chain.lean:141`) says: for every reading `τ` with `τ.length < n` and state false, at most `e` next challenges `c` make the state at `τ ++ [(m, c)]` true (`EscapesWithin`, a set of at most `e` values).
`stgLkSqV_rbr` is exactly that with `St := Λ ∘ stgVw`. `stgLkIn_rbr` (411-423): state function `szSt (incClearedPoly (Dof v))`, event bounded: the next coordinate makes `Φ` vanish on every extension, bounded by the individual degree via `Exec.szSt_escape` (Schwartz-Zippel through `Polynomial.card_roots'`), the degree `≤ 2*(128 + V) ≤ 262,400 ≤ 2^19 = e` proved in `incClearedPoly_indDeg` (I re-derived the degree 2 per factor: `β` through `β·mle` and `β²·cz`; products of at most `127 + V` factors).
Hypotheses: `V ≤ 2^17` and the type-class data; **no injectivity and no field-size hypothesis** (the degree bound is enough). `stgLkOut_rbr` (176-193): state `lkStByte`; at `τ = []` and at one challenge the state is `AllBytes`, which does not depend on `γ`, so **no** challenge escapes (`∅`, line 111: this is the `absurd`); at one challenge, escapes of `α` are those with `∃ H, HelperRel` of the byte LogUp, bounded by `card_helperRel_le'` by `N + 2*256 − 1 = 53,759 ≤ 65,536 = 2^16` with `N = 4096 + 2*24,576 = 53,248` lookups, under `N < ringChar K` (proved from `ringChar_eq_gP`).
Hypotheses: none beyond type classes (field size comes from the `GF`-algebra). The state functions are non-trivial and the bounds are the stated ones.

**D3. The four bridges** (exact statements):
- `stgLkIn_of_inLogUp` (426-456): `ch.length = 15 → (∃ H, InLogUp φ (Dof v) ((((ch0, ch1), ch2), fun c => ch(3+c))) H) → stgLkIn Dof v (ch.map (fun c => ([], c.toK U)))`. **Carries mathematics**: `HelperRel → clearedFull = 0` by a division-free ring identity (`clearedFull_eq_sum_mul`, `clearedFull_eq_zero_of_helperRel`), valid at poles, then `szSt_full_map`.
- `not_stgLkIn_nil_of_not_inGood` (459-563): `V ≤ 2^17 → Function.Injective (Dof v).vid → ¬ InGood (Dof v) → ¬ stgLkIn Dof v []`. **Carries mathematics** (about 100 lines): if the cleared numerator vanished at every point, then at every challenge point off the poles `InLogUp` holds; the union bound of the pole set (`≤ 128 + V`) and of `in_lookup_sound` (`(128 + 4V − 1) + 128*12`) would cover all of `K^15`, contradicting `|K| ≥ |GF| = gP` (`omega` after `ZMod.card`).
- `stgLkOut_nil` (153-161): `Iff.rfl` (definitional).
- `stgLkOut_two` (163-173): `lkStByte_two` (a case split on a two-element list, then `rfl`; definitional in substance).

**"`stgLkIn` at the empty prefix is false when the lookup data are bad" is a doom in the sense the stage lists use.** `StgDoomAtV` (`RunStgAlgRun.lean:448-463`) has as second disjunct `¬ (stgLkSqV m hdrLen e absOf Λ).St Lg (opTrace ..) []`, and `stgLkSqV ... .St Lg hdr τ := Λ (stgVw absOf Lg hdr) τ` (`RunStgAlgList.lean:94-99`). So the entrant's state *is* `Λ (stgVw ..) []`, and `¬ stgLkIn Dof (stgVw ..) []` is that disjunct. The bridge is applied at `v := stgVw absOf Lg (opTrace ..)`; the data `Dof v` and its `¬InGood` hypothesis are what L63 must supply. [CHECKED by reading the definitions; no L63 theorem uses the bridge yet.]

**D4. `shd_hLuStg` is exactly `hLuStg`.** Tested by the kernel (`L67Meta.lean`, `hlu_test.txt`): take the `hLuStg` binder of `sshC_productionReadyL_epP_shieldInst`, replace `eI`, `eO` by `shdP_eI`, `shdP_eO` and `ΛI`, `ΛO` by metavariables, and unify with the conclusion of `shd_hLuStg` with metavariables for all its arguments: **`isDefEq = true`**. The solved metavariables:
`ΛI := shd_ΛI ?U ?tag ?h64 ?P ?I ?Epad ?iB ((RnS).pf.off 0 + 5)` and `ΛO := shd_ΛO ?U ?tag ?h64 ?O ((RnS).pf.off 27 + 2)`; `hdrIn`, `hdrOut`, `absOf` are determined (`pf.off 0 + 5`, `pf.off 27 + 2`, `absOfC (chainEncB ..)`).
The side conditions are conjuncts proved by `norm_num`: `shdP_eI = 2^19 ≤ 2^26`, `15 * 2^19 = 7,864,320 ≤ 3 * 2^26 = 201,326,592`, `shdP_eO = 2^16 ≤ 2^26`. Still free and to be chosen by the user: `U tag h64 P I Epad O iB`, and `hV : P.V ≤ 2^17`. I did not separately compare the four instance arguments (they are the same `Field K`, `Fintype K`, `DecidableEq K`, `Algebra GF K` classes).

**D5. A trivially true predicate.** Yes: `Λ := fun _ _ => True` satisfies `.Rbr` (`trivial_rbr`, compiled, standard axioms) and `StgLkAtV` (`trivial_lkAt`, compiled), hence `hLuStg` (with `eI`, `eO` the side conditions) and `hLI_stg`, `hLO_stg`. In the top theorem `ΛI`, `ΛO` occur only in `hLuStg`, `hLI_stg`, `hLO_stg`, `hTrIIO`, `hTrOIO` (inside the `hDV` hypothesis, not as a requirement), `hdinS`, `hdoutS` and `hdzW` (`hdzW` only `ΛI`).
**The premises that force them to be meaningful are `hdinS`, `hdoutS` and `hdzW`**: `StgDoomAtV` is a disjunction of a doomed define draw, `¬ Λ []`, and a false slot claim; with `Λ = True` the middle disjunct is unavailable, so these premises would have to be proved from the other two, which is not expected to be possible. L63's own handoff (`cf71ed56`) says the same. So the theorem is not made vacuous by a trivial Λ (the premises just become unprovable); the risk is for the proof effort, not for soundness.

## E. Vacuity and misuse (what I checked, what I did not)

Checked: items (a) to (d) of N2; the argument map shows every removed binder is supplied by a term (no `sorry`-like placeholder, no forwarded binder under a changed name except the stated renames); `hLb1 := zero_lt_26` is a real proof; `hL81` is a real `omega`.
Not checked: that all remaining premises are jointly satisfiable at the concrete shape; that `hPk0` is satisfiable with `Rp.blks.length = 26` and the real calibrations (`shield_run_exists` covers a run with the real shapes and zero public data, per its header); that the instance arguments of D4 coincide.

## The open list after L67 (premises of `sshC_productionReadyL_epP_shieldInst`; 55 explicit arguments)

**Closed by L67 (as stated, by the argument map):** `Rr dR pos hpos place hplace Lb start inc incG sgeom check bRows bLogN bndOpen outc outcG h64 hr hon Rn hv hRn hσ cx0 pin pout Iin Oout bp wXk gXk mXk hgeo hIA hIH hOA hOH hBA hBH htI htO htB hfIA..hfBM hbpRows Vi F hinc houtc hchk hLb1 lscIn lscOut mIn kIn kOut hlscIn hlscOut hmIn hkIn hkOut pXk hXk hwXk hmXk hfitXk hwX0 hmX0 hOX hwXo hfitXo hXep hfitX hRr hL81 P0in P0out hNin hNout hN64I hN64O hPin hPout hSm hlcStg hLay`; `hPkD` renamed `hPk0`.
From L66's open list item 2 (instantiation leftovers) the geometry facts and the stage-shape facts are closed; `hPkD` stays.

**Still open:**
1. *Stage facts for the other lane (L63 and the LogUp bridges):* `hCsIO` (three `StgCsIODeg` links on `csIOI`, `csIOO`), `hIOI hIOO hIOlI hIOlO` (value independence and view locality of the csIO readers), `hTrIIO`, `hTrOIO` (stage IO claims on an accepted run), `hLI_stg`, `hLO_stg` (stage LogUp state at the full reading), `hdinS`, `hdoutS` (stage dooms over `epxBndE .. E0`), `hdzW` (non-zero decoded word past the token count), and the free data `csIOI csIOO`.
   **`hLuStg` is still a premise here** (with `eI eO ΛI ΛO` free): it is discharged by `shd_hLuStg` at `eI := shdP_eI`, `eO := shdP_eO`, `ΛI := shd_ΛI ..`, `ΛO := shd_ΛO ..` once `P I Epad O iB U tag h64` and `hV` are chosen (D4), but that wiring is not written.
2. *Instantiation leftovers:* `hPk0` with `dPos0` and `Pk0` (that the registered R13 Shieldstral verifier has this layout at every block, MSB coordinate order, one layout for all layers); `hhdrFit` with `hw`; `U hbij hU`; `tag`; `Lq hL20 hL64`; `key domain hs hL` (`domain := shdP_runDomain` would give `hs`, `hL` by `shdP_runDomain_start_none` and `_start_le`); `Rp`; the free verifier components `preA preB check0 paths digest bndCheck`; the free run data `embDigest embFold bInRow wDigest bOutRow`; the free prover data `P`, `epBase`.
3. *Oracle and zero knowledge:* `ι [Fintype ι] site kOf δOf` and `O : ClassifyOpenP` (extraction and opening data), `E0` (the extractor, free apart from `.planes`, appears in `hdinS`/`hdoutS` only), `εzk` and `hzk`.
4. *Other:* nothing beyond the above.

## Sentences stronger than the source, with accurate wording

1. Item 1, "top theorem ... on `pinsHd` (`96` binders eliminated ...)": accurate as a count of non-instance binders (59 Prop, 37 data); add "10 new (2 Prop: `hPk0`, `hhdrFit`; 8 data), net -86; `hPkD` is renamed `hPk0`, not discharged".
2. Header and item 1, "concrete 26-layer Shieldstral T128 R13 `shdP_runV`": "the run's shape, geometry and layouts are concrete; the verifier's `preA preB check0 paths digest bndCheck` and the block parameters `Pk0` stay free arguments (`Pk0` under `hPk0`)".
3. Item 1, "`shdP_runDomain` (73 bytes)" in the list of what the top theorem is built from; header "profile domain instantiated": "an exported constant, byte-equal to the Rust profile string, with two lemmas giving `hs` and `hL`; the top theorem takes `domain` as a free argument".
4. Item 1, "`shd_ΛI` / `shd_ΛO` concrete" and "`shd_hLuStg`": "concrete up to the free arguments `P I Epad iB` (for `ΛI`) and `O` (for `ΛO`); `shd_hLuStg` equals the `hLuStg` premise of `shieldInst` (kernel-tested) but is not applied by any theorem, and needs `P.V ≤ 2^17`".
5. Item 1, "(unblocking L63 immediately)": "`shieldInst` sits on `pinsHd`; the L63 `dz`/`pdz`/`trO` line sits on `blkAlive`; the helpers `shdP_hVi`, `shdP_hwO`, `shdP_hwB`, `shdP_epPlace_val` are stated for that line and unused in `shieldInst`; the two lines are not combined".
6. Item 1, "`hLay` discharged outright": correct; add "at `pos t = (0, t)`, `dR = 1`, `tokens = 128`, `words = 256`, the code's `input_plane` layout". Header "leaves the 19 stage obligations untouched ... `hLuStg`": correct; note that includes `hLuStg`.
7. Item 2, Q2: "`StageInExtract.lean:261-285` (`inSat_of_inGood` / `inDataOf` lemmas)": "`in_inSat` at `StageInExtract.lean:258`; `in_lookup_sound` at 130; `IncBosTmpl` is a definition at `StageInExtractSlots.lean:307`".
8. Item 2, Q1: "`stgLkOut_two` ... (`Iff.rfl` via `lkStByte_two`)": "`stgLkOut_nil` is `Iff.rfl`; `stgLkOut_two` is `lkStByte_two` (a case split on the two-element list, then `rfl`)".
9. Item 2, "so L63 can instantiate `(ΛI, ΛO)` ... without needing an extra reader-equality glue lemma": true for the *Rbr* (`stg_hLuStg` is polymorphic), but L63 still has to prove that its readers satisfy `hdinS`/`hLI_stg`/`hdzW` for the chosen `Dof`, `P.Valid` (for the bridge's injectivity) and `hV`.

## What I did not check

- Fidelity to the Rust beyond C3: the layout functions `incLay`, `outcLay`, `shapeLenW`/`shapeSqW` against `stage_in_c.rs`/`stage_out_c.rs`; `lr = 2`, `elr = 3`, `blr = 2`, stage index 27, `hdrLen = 8`, 28 segments, `S = 23`, `nA = 146`, `nH = 54`; the second field of the two `Dim`s; `tagU8`/`tagEmb` against `TAG_U8`/`TAG_EMB`; the `B_in` plane constants `(14, 16, 256, 24448)` and `Fin.append (msbBits 7 t) c`; that the transcript domain is the profile string.
- Proof bodies line by line (the kernel checked them): `shdP_rtBlk_hcnt`, `shdP_*_nums`, `shdP_rtProf_valid`, the 100-line `not_stgLkIn_nil_of_not_inGood`, `incClearedPoly_indDeg` beyond the degree-2-per-factor argument, `lkStByte_escape` beyond its case structure.
- The instance arguments in the D4 test; the olean-to-source hash tie (see "What I ran").
- Joint satisfiability of all premises (no instance exists); whether any L63 theorem will use the bridges as stated.
- Short-name collisions across the 518 files; the author's memory and time numbers other than through `history.jsonl`; regression suites.
- Anything outside the two files and the root import line.

## Reproducibility

`results/zk60_claude_review_20261116/l67_review/`: `gen_axioms.py` (declaration lists and the elaboration copies), `l67_elab.sh`, `inst_elab.out`, `lu_elab.out`, `RunShieldInstP_decls.txt`, `RunStgShieldLu_decls.txt`, `RunShieldInstP_review_copy.lean`, `RunStgShieldLu_review_copy.lean`, `parse_axioms.py`, `parse_axioms.out`,
`sig_pinsHd.txt`, `sig_shieldInst.txt`, `sigdiff.py`, `sigdiff.out`, `L67Meta.lean`, `l67_meta.sh`, `meta.out`, `sigp_pinsHd.txt`, `sigp_shieldInst.txt`, `sigdiff2.py`, `argmap.txt`, `argmap_summary.txt`, `use_top.txt`, `hlu_test.txt`, `reducibility.txt`, `domain_check.py`, `get_entry.py`, and the guard files
`elab.guard.log/json`, `meta.guard.log/json`, `meta2.guard.log/json`. `meta.out` is the output of the corrected run; it contains two linter warnings about unused section variables in my own `trivial_*` examples and the two `#print axioms` lines for them.
