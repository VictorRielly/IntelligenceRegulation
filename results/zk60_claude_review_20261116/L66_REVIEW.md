# Review of Lean lane L66 (Antigravity), 2026-11-17

Reviewer: Claude (independent, read-only on formal/ and ops/). Files under review: `formal/ZK60Formal/RunBlkPinsHd.lean` (3,541 lines,
untracked) and one added import line in `formal/ZK60Formal.lean`. The author's claims are the entry "Antigravity 2026-11-17T16:15:00Z" in
`ops/zkp-mvp/RECOVERY_COORDINATION.md` (plus the file header, lines 1-61). Out of scope: `RunShieldInstP.lean` (L67).
Marking: [CHECKED] = by me, with the command or line; [CLAIM] = the author's, not re-derived; [NOT CHECKED] = could not or did not.

## Verdict: ACCEPT WITH FIXES

Every kernel claim holds, and I found nothing that makes a theorem false or the top theorem vacuous. The block side is really finished: base and D are now
ordinary definitions, the five old pins are proved lemmas that the top theorem uses, and all 16 conjuncts of `RkPart.Ok` are proved for the block parts.
But three sentences of the summary say more than the source. (1) `hblkIO` is "proved outright" only because the extractor was replaced by a wrapper
(`epxBndE`) whose planes are defined to be the reader's output; the real obligation now sits in `hdinS` and `hdoutS`, which are restated for the wrapped
extractor. (2) The four stage premises are not an equivalent split of `hD`: two are implied by it, two are sufficient conditions that L65's lemmas consume.
(3) "Zero non-uniqueness hazard" is proved for `Lay.dPos` only; the premises that mention `shdRkD` now depend on `Classical.choose` witnesses for the rest
of the block data. Counts: High 0, Medium 3, Low 5, Note 6.

## What I ran

| Step | Guard run | Exit | Wall | Peak RSS | Note |
|---|---|---|---|---|---|
| Single-file elaboration of the source (+ `#print axioms` appendix), `lake env lean`, no `-o`, LEAN_NUM_THREADS=2 | `7ed8c7cef0a0`, label `claude-l66-review-elab`, class build | 0 | 23 s (waited 30 s for the heavy lock) | 4.13 GiB | `l66_review/l66_elab.sh`, `l66_elab.out` |
| Same, source + binder dump appendix; and the L63 IO-link test file (see C) | `ea117ca002f5`, `claude-l66-review-meta` | 0 | 25 s | 4.13 GiB | `l66_all.sh`, `sig_*.txt`, `iolink_test.out` |
| Use analysis of the proof term, replaying the author's .olean | `7f3e3b1cdb58`, `claude-l66-review-use2` (the first attempt, run before the script was fixed, wrote nothing) | 0 | 16 s | 3.79 GiB | `l66_use.sh`, `UseAnalysis.lean`, `use_top.txt`, `use_aux.txt` |

I did the first of the two things you asked for: the file was **elaborated from source by me**, not replayed. The copy `RunBlkPinsHd_review_copy.lean` is the file
byte for byte up to the last `end ZK60.ProtocolClassify`, with `#print axioms` lines inserted before it; nothing was written under `formal/`, and no .olean
anywhere (no `-o`). Output: 0 errors, 0 warnings, 0 other messages. The use analysis (third row) reads the author's .olean, because Lean 4.34 does not expose the
proof term of a theorem in the file being elaborated; I did not tie that .olean to the source by hash.

## Check 1. Kernel and hygiene [CHECKED]

- Hashes: `RunBlkPinsHd.lean` `ead9b379...e6fe04` and `ZK60Formal.lean` `3be442cb...1a57`, both equal to the posted ones.
- `git status --short formal`: ` M formal/ZK60Formal.lean`, `?? formal/ZK60Formal/RunBlkPinsHd.lean`. `git diff --stat -- formal`: one file, 1 insertion
  (`import ZK60Formal.RunBlkPinsHd` after `RunBlkAliveR13`). `RunShieldInstP` is not imported. `Statements.lean` and `RunBlkAliveR13.lean` unchanged.
- Declarations (`l66_review/gen_axioms.py`, `public_theorems.txt`): 51 theorems, of which **44 public** (matches the claim) and 7 private, plus 21 definitions.
- `#print axioms` on all 72 (51 theorems + 21 definitions), parsed by script after joining wrapped lines (`parse_axioms.py`, `parse_axioms.out`): 63 print
  `[propext, Classical.choice, Quot.sound]`, 7 print `[propext, Quot.sound]`, 2 print `[propext]`. **0 outside the standard set, 0 `sorryAx`, 0
  `Lean.ofReduceBool`.** The top theorem prints `[propext, Classical.choice, Quot.sound]`.
- Source scan: no `sorry`, `admit`, `axiom`, `native_decide`, `unsafe`, `opaque`, `implemented_by`, `extern`, `decide +kernel` (grep; the only hits are the words
  "irreducible" at lines 1037 and 1100 and `local notation` at 2845). `set_option`: `autoImplicit false` (64) and `linter.constructorNameAsVariable false` (65).
- No `absurd`/`exfalso`/`False.elim` other than six `absurd h List.not_mem_nil` on empty lists (lines 1550-1552, 1736-1738): benign.
- The memory claim (36.85 GiB down to 4.34 GiB) cannot be re-measured without the old version. My peak for the current file is 4.13 GiB, consistent with 4.34.
  `card_of_pairs` exists at `ExecSumcheckFS.lean:541` and is used at line 1823.

## Check 2. Premise accounting by machine [CHECKED]

Method: the signatures of both top theorems printed by Lean itself (`forallTelescope`, `sig_blkAlive.txt` from the .olean, `sig_pinsHd.txt` from my fresh
elaboration), diffed by `sigdiff_kernel.py` (output `sigdiff_kernel.out`); and independently a text diff of the source signatures (`sigdiff.py`, `tokdiff.py`).
Kernel counts: blkAlive 167 binders (153 explicit, 14 implicit or instance), pinsHd 154 (140 explicit). 8 instance binders on each side (the names differ only by
hygiene). **The conclusions are identical** (`ProductionReadyL (classifyModelP Rp) ... εcTarget εsTarget εsTarget εzkTarget`, same protocol term, `CinS` notation both sides).
The order of the 134 shared binders is unchanged.

| Binder | blkAlive | pinsHd | Verdict |
|---|---|---|---|
| `D`, `hD`, `base`, `eL`, `hDe` | premises | gone | concrete: `shdRkD`, `shdRkBase`, `2 ^ 26`, `shdRkD_eq_ebData` (proved by `rfl`, line 1068, before the `irreducible` line); `hD` is now proved (`shdRkD_valid`) from the four new stage premises |
| `hgXk`, `hnXk`, `hgX1`, `hnX1`, `hgXo`, `hnXo`, `hgX0`, `hnX0` | premises | gone | proved at the top of the aux theorem from `shdRkBase_gX_nX` and `shdRkBaseX_*_gX` (3042-3057), then used (passed to the dg theorem) |
| `hslB`, `hbBlk`, `hb0`, `hbL` | premises | gone | proved: `shd_hslB`, `shd_hbBlk`, `shd_hb0`, `shd_hbL`, each applied in the aux proof (3062-3152) and passed on |
| `hblkIO` | premise | gone | proved for a changed extractor, see M1 |
| `hPkC : ShieldRunAtC tag Pk Rp.blks Lb` | premise | gone, replaced by `hPkD` (below) | strengthened |
| `dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)` | none | **added**, explicit section variable, position 17 (between `tag` and `Rp`) | not fixed to `shieldDPos0`: a free parameter |
| `hPkD : ShieldRunAtD tag dPos0 Pk Rp.blks Lb` | none | **added** | `ShieldRunAtC` plus `Lay.dPos = dPos0` inside the existential for every block (line 139) |
| `hSm`, `hlcStg`, `hCsIO`, `hLuStg` | none | **added** | see C |
| `hTrIIO`, `hTrOIO`, `hLI_stg`, `hLO_stg` | `∀ A G, ... D hD ...` | gain a binder `(hDV : (shdRkD ...).Valid ...)` after `G`; `D hD` become `_ hDV`; nothing else changes (`tokdiff.out`) | substance unchanged: `hDV` is a proof, supplied by `shdRkD_valid`; the premises now mention `shdRkD` (see M3) |
| `hdinS`, `hdoutS` | about `epxE ... E0` | about `epxE ... (epxBndE ... (shdRkD ...) dPos0 E0)`; nothing else changes | the extractor is wrapped, see M1 |
| `hdzW`, `hNin`, `hNout`, `hN64I`, `hN64O`, `hPin`, `hPout`, `csIOI`, `csIOO`, `ΛI`, `ΛO` | | | text differs only by namespace qualification (`StgVw` vs `ZK60.ProtocolClassify.StgVw`); identical in the kernel dump |
| the other 115 binders | | | identical |

So: **removed by name = 19** in the kernel dump (the summary's 18 plus `hPkC`, which is the strengthened one); **added = 6 explicit** (`dPos0`, `hPkD`, `hSm`,
`hlcStg`, `hCsIO`, `hLuStg`). Explicit arguments 153 to 140, a net of **-13**, not the summary's "-14" (that figure leaves out `dPos0`, an explicit argument of the
theorem). The summary's list of 18 is exactly right as a list of names. It does not say that six further premises changed text (`hTrIIO`, `hTrOIO`, `hLI_stg`,
`hLO_stg`, `hdinS`, `hdoutS`); the file header does (lines 56-57).

## Findings

### Medium

**M1. `hblkIO` is "proved outright" by redefining the extractor; the obligation it stood for moves to `hdinS` and `hdoutS`.**
`epxBndE` (294-304) sets `.planes := bndPlanes ...` and `bndPlanes` (281-290) is literally `piB K (bndPl ... (D.opX (j+1)) (pf.off j + 2) 19 (hdrX ... (rtTr ... (fun _ => zeroDig) o)) (Fin.append ...))`.
`epxE_epxBndE_planes` (306-319) is `rfl`. `shd_hblkIO` (339-363) then shows the reader on `bndPlanes` agrees with the reader the block uses. The only real
mathematics is `absAt_opTrace_indep` / `hdrX_rtTr_at_lt` (a header read at an index below both header lengths does not depend on the oracle or the length), and
`hdPos` from `Lay.dPos = dPos0` for the coordinate. The statement `ShieldBlkIO_D` is the old `ShieldBlkIO` text with `dPos0` through `Lay.dPos` [CHECKED: 322-335 against
the L64 review's description]. `shd_hblkIO` carries no hypothesis except `h64`, `hPkD` and the data; it holds for **every** `D`. That is all true, and it is a clean way to remove
a premise, **but** it does not show that the real extractor reads the planes this way. The theorem now ranges over extractors of the form `epxBndE ... E0` (all
other fields of `E0` still free), and `hdinS` / `hdoutS` ("if `InOkP` / `OutOkP` fails for this extractor, the stage is doomed") are stated for that extractor. Whether the real
stage endpoints are bound to the plane the header claims is exactly what those two premises must now deliver. So `L64_REVIEW.md` M3 is closed as a block-side premise and
relocated, not discharged. Wording fix in G, items 5 and 6.

**M2. The four stage premises are not an equivalent split of `hD`.**
Checked against the proof of `shd_stg0_rkPartOk` (1378-1560), `shd_stgOut_rkPartOk` and `shdRkD_valid` (1750-1849), which use them as follows. `hSm` is the third conjunct of `mK`
(lines 1521, 1706) and `hLuStg` is the `lu` entry's `.Rbr`, `e ≤ 2^26`, `n * e ≤ 3 * 2^26` (1558, 1745): **both are implied by `hD` at parts 0 and `Lb+1`** (they are conjuncts of it).
`hlcStg` (`Vi.pub.lt ≤ ogStage.lc`) and `hCsIO` (`StgCsIODeg` on the three IO claims) are hypotheses of `stgDefsV_valid_inC` / `_out` (RunStgShieldCTopDg.lean:35-44), which
**derive** the `r0` entries' `.Rbr`; `hD` does not state either of them. So the replacement is by sufficient conditions in the form L65's lemmas consume, which is
the intended route, but a reader of "replaced the monolithic `hD` with 4 stage-only premises" would take it as equivalence. At the code's constants all four are
plausible (`4, 8`, `12 ≤ 12` per the comments) [CLAIM, not checked against Rust]. The full `D.Valid` is assembled by `ebData_valid` (1831) from `hv`, `hK`, and per-part `RkPart.Ok`:
blocks by `shd_blk_rkPartOk`, stages by the two stage lemmas [CHECKED: kernel]. For the block parts the proof uses no premise that was not already in the blkAlive theorem
(`hPkD` for `hPkC`, `hσ`, `hBA`, `hBH`, `hXk`, `hwXk`, `hmXk`, `hwX0`, `hmX0`); `hbpRows` is not used there (it is used by the five `shield_h*_blkD`).

**M3. Choice dependence is real and is not covered by "zero non-uniqueness hazard".**
What is proved: `(shieldLayD hPkD k hk).dPos = dPos0` follows from `Classical.choose_spec` (`shieldBlkAtD_spec`, last conjunct, line 230; used at 350). That is a real property, and it is
why `dPos0` was put inside the existential. What is not covered: `shdRkBase` (612-687) builds the block lists `r0..lu` and `sls` from `shieldLyD`, `shieldPbD`, `shieldLayD`, `shieldBD` and
`shieldIoInD/OutD` (all `Classical.choose`), and `shdRkD` is built on `shdRkBase`. `Ly`, `b`, `Pb` are unique (fixed by `shieldExport[k]?`, `blks[k]?`, `HEq Pb b.pub`);
`rowsOf`, `Lay` (beyond `dPos`), `B`, `ioIn`, `ioOut` are not. The **statements** of `hTrIIO`, `hTrOIO`, `hLI_stg`, `hLO_stg` (through `rtKB.Dm`, `rtKA.Dm`, ... of `shdRkD`) and of
`hdinS`, `hdoutS` (through `D.opX`; here `shdRkD_ops_eq_D0` shows the choice does not matter, but a reader must know that) therefore name a `D` that depends on those witnesses. The author who
instantiates these premises must prove them for the chosen witness, i.e. prove them from the spec alone or show the witness is determined. In L64 the same dependence existed
through `hbBlk`; now it is invisible in the premise list. Nothing here is false. It is a proof obligation for L67 and a sentence that should not read "zero hazard". Where a definition built
with `Classical.choose` is treated as "the intended object": nowhere with a proof gap in this file; the consumers only use `shieldRunAtD_spec` / `shieldBlkAtD_spec`.

### Low

**L1. Counts in the entry.** "net -14 explicit binders" is -13 with `dPos0` (see Check 2); `hPkC` is omitted from the removed list because it is counted as strengthened (fine, but state it); the six rewritten premises are not listed
in the entry.

**L2. `shieldDPos0` and `shieldDPos0_injective` are decorative.** Neither is used in any proof or in the top theorem (grep: lines 8-10, 99-112 only). `dPos0` is a free parameter. Any satisfiable `hPkD` already forces `dPos0`
injective, because `Lay.tok.inj` and `Lay.wid.inj` make `Lay.dPos` injective (LayoutW16.lean:127-148). The real obligation for the instantiating lane is to show that **the layout the verifier's `P.define`
really uses** has `tok.emb t = msbBits 7 t` and `wid.emb i = msbBits 12 i` for every block (one common map, so the same layout for all layers), and that the plane coordinate in `bndPl`,
`Fin.append (dPos0 p).1 (dPos0 p).2`, is the Rust endpoint plane index. [NOT CHECKED against Rust.] `nD (cfgShieldR13 _) = 19 = 7 + 12` is checked (`rfl`, line 351).

**L3. `attribute [irreducible] shdRkBase shdRkD` (line 1100) is global and persistent, not `local`.** It is in the .olean and applies to every file that imports `RunBlkPinsHd` (today only the root
file; L67 will). `rfl` and plain `unfold` on those two names fail downstream; the file proves its equation lemmas before the line (`shdRkD_eq_ebData`, `shdRkD_ops_eq_D0`, `shdRkBase_gX_nX`)
and uses them. Say so in the entry so L67 does not rediscover it.

**L4. Generality lost.** `eL` is fixed at `2 ^ 26` (closes N9 by specialising); `S := shieldS0` was already fixed. Both are fine. The top theorem no longer applies to a different LogUp escape bound.

**L5. Header and entry wording** is loose in two places: "eliminating all 16 structural schedule/list pins" (the sixteen are `base`, `eL`, `hDe` and the pins and gX/nX facts: not all pins); "proves all 13 unconditional stage conjuncts" is accurate
(three of 16 conjuncts per stage carry `hSm`, `hlcStg`+`hCsIO`, `hLuStg`) but the header should say that.

### Note

**N1. `shd_blk_rkPartOk` hypotheses (1145-1196):** `hPkD`, `Rn`, `cx0 pin pout Iin Oout bp wXk gXk mXk`, `hσ`, `hBA`, `hBH`, `pXk`, `hXk`, `hwXk`, `hmXk`, `hwX0`, `hmX0`, `Vi F lscIn lscOut mIn kIn kOut P0in P0out csIOI csIOO eI eO ΛI ΛO`, `k`, `hk`, and the usual field and parameter data. All 16 fields
(`slCut slDeg slWin mK mS gA gH gX wA wH wX r0 r1 h0 h1 lu`) appear in the `refine` (1242-1321). "0 new block premises" is true against the blkAlive premise set. `blk_hhi_of_rtRun` (1110-1141) takes only the run data, `hσ`, `k < Lb`;
it uses `RtProf.off_succ` and `pre = 15 + shapeLen` through `rx_part_of` [CHECKED: reading, kernel]. `(bp k).S = 23` comes from `maskField_inj_S ((bp k).hPm.symm.trans hP.hPm)` (1206).

**N2. `shd_hblkIO` hypotheses (339-349):** `h64`, `U`, `tag`, `dPos0`, `Lb`, `key domain hs hL`, `pf`, `rd`, `hPkD`, an **arbitrary** `D`, `k < Lb`, an arbitrary oracle `G`, `lg`, `o`. Nothing else.

**N3. Concrete definitions (E).** `shdRkBaseX` (514), `shdRkD0` (592), `shdRkBase` (612), `shdRkD` (690) are ordinary (`noncomputable`) definitions. `shdRkBaseX` sets only `gX, nX` (empty lists); `shdRkD0` is `ebData` on it; `shdRkBase` reads `D0.opA/opH/opX`
(for `hoAK0..hoOK0` and `bwFslRun`) and fills stage and block lists; `shdRkD` is `ebData` on `shdRkBase`. The cycle is broken correctly: `shdRkD_ops_eq_D0` (753-805) proves `opA/opH/opX` of `shdRkD` and `shdRkD0` agree, from `shdRkBase_gX_nX`. The five pins are proved as lemmas and
**used**: `shd_hb0`, `shd_hbL`, `shd_hbBlk`, `shd_hslB` are applied in the aux proof and passed to the dg theorem; `hDe` is `shdRkD_eq_ebData` (the public theorem passes `rfl rfl` for `base := shdRkBase ...` and `D := shdRkD ...`).

**N4. Vacuity and misuse (F).** Checked: (a) every one of the 154 binders of the top theorem and 156 of the private aux theorem **occurs in the proof term** (`use_top.txt`, `use_aux.txt`: 0 with `inBody=false`), so no premise is dead (a weak test, since the term only passes
them on; the linter reported nothing either); (b) the proof has no contradiction step; (c) what the concrete definitions fix cannot conflict with another premise by itself: `D`/`base` are not premises any more; (d) `hbpRows`, `hRr`, `hfBA` are mutually
satisfiable on their face (`4577` and `8 * 4577 ≤ Lq`, `Lq ≥ 2^20`); (e) index types: `Fin 7`, `Fin 12`, `shieldS0.Pos` are nonempty; `ι` is a free finite type as before; `∀ k < Lb` with `0 < Lb` (`hLb1`). Not checked: that one instance satisfies all premises at once (nobody has built one; as in L64).

**N5. `hdzW`, `hLay` and the other stage premises** are unchanged in text; see the open list.

**N6. The `Rbr`/escape bounds.** `hLuStg` takes `eI, eO ≤ 2 ^ 26`, `mIn * eI ≤ 3 * 2 ^ 26`, with `ΛI`, `ΛO` free predicates; no existing theorem in the tree discharges `(stgLkSqV ...).Rbr` for a concrete `Λ` (grep of `RunStg*.lean`, `RunBlk*.lean`:
only structural uses).

## C. The new premises, one by one

| Premise | Statement | Consumed at | Implied by old `hD`? | Discharged by an existing theorem? |
|---|---|---|---|---|
| `hSm` | `2 * pin.S + 2 ≤ 2 ^ 20 ∧ 2 * pout.S + 2 ≤ 2 ^ 20` | `mK` of parts 0 and `Lb+1` (1521, 1706) | yes (a conjunct of it) | not yet. `RtInc.hPm : maskVerify = maskField tag pin.S` plus the new `maskField_inj_S` and the code's `maskField tag 4` / `8` would give `pin.S = 4`, `pout.S = 8` (the comment says so); nobody has done it |
| `hlcStg` | `Vi.pub.lt ≤ ogStage.lc ∧ ∀ b, (F b).pub.lt ≤ ogStage.lc` | `stgDefsV_valid_inC` / `_out` (1484, ~1670) | **no** (sufficient condition) | not yet; a statement about the code's constants (`12 ≤ 12` [CLAIM]) |
| `hCsIO` | three `StgCsIODeg` links on `csIOI` and `csIOO` | same | **no** (sufficient condition) | L63's `ssh_hIO0`, `ssh_hIO1`, `ssh_hIOO` on the lane branch, with `hle` hypotheses (below) |
| `hLuStg` | `.Rbr`, `eI ≤ 2^26`, `mIn * eI ≤ 3 * 2^26` for `stgLkSqV ... ΛI`, and `.Rbr`, `eO ≤ 2^26` for `... ΛO` | `lu` of parts 0 and `Lb+1` (1558, 1745) | yes (conjuncts) | none found (N6) |
| `hPkD`, `dPos0` | D below | everywhere `shieldLyD` etc. are used | n/a: strengthens `hPkC` | none |

**Claim 7 (the `hCsIO` / L63 match), tested by the kernel.** I copied the three conjuncts from `RunBlkPinsHd.lean:3385-3387`, set `csIOI := csIOO := stgCsIOv U tag h64 lcI hI QI eI rI iI lcO hO QO eO rO iO`
and proved the conjunction with `⟨ssh_hIO0 ..., ssh_hIO1 ..., ssh_hIOO ...⟩`, in a file made of the branch's `RunStgShieldIOLink.lean` (from `git show worktree-agent-a8b5788916259e1b2:...`, 158 lines) plus my `example`
(`l66_review/IOLinkTest.lean`), elaborated from source against this tree: **rc 0, no output**. So **the three statements are identical** up to the instantiation `csIO := stgCsIOv ...`, binder names aside. Two further things
are needed at the point of use, which "character-for-character" does not mention: the three width hypotheses of the L63 theorems, `Vi.pub.epLogN ≤ lcI`, `Vi.geo.bLogN ≤ lcO`, `∀ b, (F b).geo.bLogN ≤ lcI` (true at the code, equal widths `2^8` and `2^14` per the file comment [CLAIM]),
are **not** premises of the top theorem and must be proved at instantiation; and `hU` is available (`hU : U ^ 2 = algebraMap GF K 7` is a binder of the top theorem). `hIOI`, `hIOO`, `hIOlI`, `hIOlO` of the top theorem correspond to
the branch's `stgCsIOv_value` and `vwLoc_stgCsIOv` (needs `iI, iO < n`) [CLAIM, from its header; not re-derived].

## D. `hPkD` and choice

- `ShieldRunAtD` adds one conjunct to `ShieldBlkAtC` inside the existential: `Lay.dPos = dPos0` (line 139), for every block, with one common `dPos0`.
- `dPos0` is a **free explicit parameter** of the top theorem, not fixed to `shieldDPos0`.
- Choice: `shieldLyD ... shieldIoOutD` (175-216) are `Classical.choose` projections of `hPkD k hk`; their specs are proved together (`shieldRunAtD_spec`, `shieldBlkAtD_spec`). The proofs only use the specs.
- "Zero non-uniqueness hazard": a proved property for `Lay.dPos` only; for the rest see M3. It is not a remark with no content, but it is narrower than the sentence.

## The open list after L66 (premises of `sshC_productionReadyL_epP_pinsHd`; 140 explicit arguments)

**Closed by L66 (as stated):** `hD` for the block parts and the structural stage conjuncts; `hbBlk`, `hslB`, `hb0`, `hbL`, `hDe`, `base`, `D`, `eL`, the eight `hgX*/hnX*` facts; `hblkIO` as a block premise (relocated, M1);
the `L64_REVIEW.md` items: M1 (joint satisfiability of `hbBlk` with `hD`/`hDe`/`hslB`) closed by construction; M2 (`blkLists_rkSqOk` not connected, `hhi`) closed for blocks; M3 relocated to `hdinS`/`hdoutS`; N9 closed by `eL = 2^26`.

**Still open:**

1. *Stage facts for the L63 / L65b lane:* `hCsIO` (the csIO link: `ssh_hIO0/1/O` plus width side conditions), `hSm`, `hlcStg`, `hLuStg` (stage LogUp parameters `ΛI ΛO eI eO` and their `.Rbr`), `hTrIIO`, `hTrOIO` (stage IO claims),
   `hLI_stg`, `hLO_stg` (stage LogUp facts on accepted un-doomed runs), `hdinS`, `hdoutS` (stage dooms, now over `epxBndE ... E0`), `hdzW` (non-zero decoded word past the token count), `hLay` (input layout), `hIOI hIOO hIOlI hIOlO`
   (csIO shape: value independence and view locality), `hNin hNout hN64I hN64O hPin hPout` (stage geometry and `StgSame`), and the free data `P0in P0out csIOI csIOO`.
2. *Instantiation (verifier, run shape, profile constants):* `hPkD` with `dPos0` (that the registered R13 Shieldstral verifier has this layout at every block, MSB coordinate order, common to all layers); `Rp Lq Lb hL20 hL64 hL81 h64 hr hon U hbij hU key domain hs hL`
   `preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck bndOpen P`; `Rn hv hw hRn hσ hgeo cx0 pin pout Iin Oout bp wXk gXk mXk`; the opening-geometry facts
   `hIA hIH hOA hOH hBA hBH hXk hOX hXep htI htO htB`, `hfIA..hfBM`, `hfitXk hfitXo hfitX`, `hwXk hmXk hwX0 hmX0 hwXo`, `hRr`, `hbpRows`, `hchk`, `hLb1`; `Vi F hinc houtc lscIn lscOut mIn kIn kOut hlscIn hlscOut hmIn hkIn hkOut pXk`.
3. *Oracle and zero knowledge:* `ι [Fintype ι] site kOf δOf` and `O : ClassifyOpenP` (extraction and opening data of the run), `E0` (the extractor, free apart from `.planes`), `εzk` and `hzk`.
4. *Other:* none beyond the above. Structural pins still to be **constructed** rather than proved: only `hPkD`.

## G. Sentences stronger than the source, with accurate wording

1. Entry, "closing M1, M2, M3, and N9 ... in one shot": M1 and N9 yes; M2 for the block parts; M3 is relocated, not closed (M1 above).
2. "(net -14 explicit theorem binders)" -> "net -13 explicit arguments (19 removed, 6 added: `dPos0`, `hPkD`, `hSm`, `hlcStg`, `hCsIO`, `hLuStg`)". "Removed 18 explicit binders" is correct as a list; add "and `hPkC`, strengthened into `hPkD`".
3. "Replaced monolithic `hD` with 4 focused stage-only premises" -> "`hD` is now proved; its stage part is supplied by four premises: `hSm` and `hLuStg` are conjuncts of the old `hD`; `hlcStg` and `hCsIO` are sufficient conditions that L65's lemmas consume".
4. "0 new block premises" -> "no block premise beyond the blkAlive theorem's, with `hPkD` in place of `hPkC`".
5. "`shd_hblkIO` + `epxBndE` prove `hblkIO` outright" -> "`hblkIO` holds by construction for the wrapped extractor `epxBndE ... E0` (planes defined as the block reader's output; header reads are oracle-independent); `hdinS` and `hdoutS` are restated for that extractor and now carry the coherence".
6. Header "proving `ShieldBlkIO_D` outright ... while sharing the exact extracted boundary planes `B_0 .. B_Lb`": same correction as 5; `ShieldBlkIO_D` is proved for every `D`.
7. "placing `Lay.dPos = dPos0` inside the existential so `Classical.choose` witnesses share `dPos0` across all blocks with zero non-uniqueness hazard" -> "so the chosen `Lay` has `dPos = dPos0` (proved from `choose_spec`); other chosen witnesses are not unique, and the premises that mention `shdRkD` depend on them". "accompanied by concrete `shieldDPos0` + `shieldDPos0_injective`" -> "a candidate value and a proof it is injective; neither is used by the theorem".
8. "match character-for-character" -> "identical up to `csIO := stgCsIOv ...` (kernel-checked); the L63 theorems also need three width inequalities that are not premises here".
9. Memory note: not contradicted (4.13 GiB peak on my run); the 36.85 GiB figure is not reproducible from the current file.
10. Header "eliminating all 16 structural schedule/list pins" -> "eliminating 16 binders (`base`, `eL`, `hDe`, the pins, and the `gX`/`nX` facts)".

## What I did not check

- That the real stage endpoints are bound to the planes of the wrapped extractor (the content of `hdinS`/`hdoutS`), nor that `InOkP`/`OutOkP` for the wrapped extractor are non-trivial.
- That a layout with `tok.emb = msbBits 7`, `wid.emb = msbBits 12` is the one the Rust verifier uses; the plane index `Fin.append (dPos0 p).1 (dPos0 p).2` against the Rust endpoint layout; rows 4577 and 4390.
- The values `Vi.pub.lt`, `pin.S = 4`, `pout.S = 8`, the width equalities `2^8`, `2^14` against the Rust code (the author's comments only).
- Proof bodies of `shd_hbBlk`, `shd_hslB`, `shd_hb0`, `shd_hbL`, `shield_h*_blkD` (1855-2818), `shd_stgOut_rkPartOk` and the 800-line stage lemmas line by line (the kernel did); `maskField_inj_S` (435-505) beyond its statement.
- Joint satisfiability of all premises (no instance exists); the `use_*` analysis reads the author's .olean, not my elaboration.
- Whether the premises `hTrIIO` etc. are true for every `Classical.choose` witness (M3).
- Anything outside the file, the root import line, and the L63 branch file named above; no regression suites.

## Reproducibility

`results/zk60_claude_review_20261116/l66_review/`: `gen_axioms.py` (declaration list and the elaboration copy), `l66_elab.sh`, `l66_elab.out`, `parse_axioms.py`, `parse_axioms.out`, `public_theorems.txt`, `sigdiff.py`, `sigdiff.out`,
`tokdiff.py`, `tokdiff.out`, `gen_meta.py`, `RunBlkPinsHd_review_copy.lean`, `RunBlkPinsHd_review_copy2.lean`, `sig_blkAlive.txt`, `sig_pinsHd.txt`, `sigdiff_kernel.py`, `sigdiff_kernel.out`, `l66_all.sh`, `gen_iolink_test.py`, `IOLinkTest.lean`,
`RunStgShieldIOLink_branch.lean` (a copy of the branch file for the test), `iolink_test.out`, `UseAnalysis.lean`, `l66_use.sh`, `use_top.txt`, `use_aux.txt`, `get_entry.py`, guard logs `elab.guard.log`, `all.guard.log`, `use.guard.log`.
The first `l66_meta.out` shows a Lean PANIC from my own first meta script (it asked for a theorem body that the 4.34 elaborator does not expose in the same file); the signature dumps were unaffected and the use analysis was redone against the .olean.
