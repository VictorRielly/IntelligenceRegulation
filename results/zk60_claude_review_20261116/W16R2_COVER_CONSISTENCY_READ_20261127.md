# `covParamsW16` against `BlockAcc`: consistency of the conjuncts on one core (independent read)

Question: at `P := covParamsW16 tag ioIn ioOut checkOpening Ly Pb` (`formal/ZK60Formal/BlockW16U1Cover.lean:88-110`),
do the conjuncts of `BlockAcc` (`OpenKnowBlock.lean:45-48`) = `SlotsAcc` (`ExtractW16Block.lean:50-53`: `CoreCanon`,
`CoreShape P.geom`, `blockSlots = .ok`) ∧ `blockVerify = .ok` place contradictory requirements on the core `out.2`,
for every oracle `G`? This is a reading, not machine-checked. Nothing was built, compiled or edited. Paths below are
relative to `formal/ZK60Formal/`. COUNTED = read at file:line; DERIVED = arithmetic or unfolding shown (arithmetic
re-run in one `python3 -c` block).

## 0. Findings first

1. **No contradiction found.** 31 pairs checked: **29 CONSISTENT, 0 CONTRADICTION, 2 NOT DETERMINED** (row 23,
   public-table lengths at 14 of the 23 slots; row 29, the free `checkOpening`). With today's `covDimW16`, each count
   that `CoreShape` fixes is the count the verifier functions demand at this record: 280 opened columns of 2504/2606
   words with paths of 15, vectors of 16664, 36/9 group vectors; `M` 1024/1024/256 columns of 50 words, paths 12; 23
   slots with `n+e` rounds of `d+1` values and `shieldTerms` terminals. **Not finding a contradiction does not prove
   satisfiability.** This read does not show that an accepting core exists at the record.
2. **Two requirements depend on the oracle and fail on a small but non-empty set of `G`. They do not fail for every
   `G`.** (a) The `A`/`H` group-vector counts 36/9 that `CoreShape` fixes must equal the number of distinct column
   keys among the claims (`ExecOpening.lean:586`). That number is 36/9 for generic challenges (DERIVED, row 6) and
   smaller when challenge values collide (for example `ρ₁₂ = 1/2` at slot 15, where the flipped coordinate equals the
   plain one). (b) Zero draws are refused (`BlockDefineSym.lean:225`; `ExecBlockVerify.lean:340,352`). On those `G`,
   `BlockAcc` is false whatever the core.
3. **`checkOpening` decides whether acceptance is possible at all.** `cov_block_knowledge_w16r2_shieldU1` quantifies
   over every `checkOpening`, including one that always refuses, and there `BlockAcc` is empty. Every claim of
   "consistent" in this report assumes a `checkOpening` that can accept (for example `fun _ _ _ _ => .ok ()`, or
   `checkField` at the code's geometry, whose group count at `ExecOpeningBlock.lean:200` repeats rows 6-7; its audit
   `auditClaims` was not read).
4. **Two weak equalities that `BlockAcc` does not force**, recorded for the run-level record (checklist §2, items
   14-16). `P.aRows`/`P.hRows` are only absorbed (`ExecBlockVerify.lean:379,384`) and are never compared with
   `rowsOf`. `kind` is pinned only at the six host slots (by `define`'s `hosted`) and in total count (by
   `nFunctionals`). Which two non-host slots besides 3, 19 and 20 are standalone is not forced.

## 1. Pairs (two conjuncts constraining the same quantity, or a verifier demand that holds independently of the core)

Record values (COUNTED): `geom = R13.geom shieldSlots shieldTerms 50 36 2504 9 2606 with blk := covDimW16`
(Cover `:91-92`). Field order: `R13.geom` `ExecBlockR13.lean:296-298` against `Geom` `ExecBlockWire.lean:92-105`.
Values: `mRows 50, aGroups 36, aRows 2504, hGroups 9, hRows 2606`; mask constants `1024, 256, 4096, 12`
(`ExecBlockFS.lean:972-978`); `covDimW16 = ⟨checks 280, vec 2^14+280, encCols 2^15, path 15⟩` (Cover `:82`, `Dim`
`ExecBlockWire.lean:80-84`); `aPath = hPath = 15`, `maskPath = 12` (Cover `:97-99`). Below, `CS` = `CoreShape`
(`ExecBlockWire.lean:238-247`), `BV` = `ExecBlockVerify.lean`, `EO` = `ExecOpening.lean`, `EM` = `ExecOpeningM.lean`,
`TR` = `ExecTranscript.lean`.

| # | Quantity | Side 1 (file:line, value) | Side 2 (file:line, value) | Verdict |
|---|---|---|---|---|
| 1 | A/H path length | `CS:245` `col.path.length = blk.path` = 15 (COUNTED) | `BV:392-393` `pathsDepth aPath/hPath` = 15; `pcsVerify` `badPath (log2 nn)` `EO:582`, `nn = 2^14·2` (`EO:515,942`) → 15 (DERIVED) | CONSISTENT |
| 2 | A/H opened-column count | `CS:245` `columns.length = blk.checks` = 280 | `EO:596-599` `columns.length = idx.length`, `idx = idxLoop` with fuel = rem = `nQ` 280, 4 per squeeze (`TR:141-155`) → exactly 280 (DERIVED: 70 squeezes, last takes 4) | CONSISTENT |
| 3 | A/H column index | `CS:245` `col.j < blk.encCols` = 2^15 | `EO:561` `j = wj`, `wj = leNat c &&& (2^15 − 1)` (`TR:147`) < 2^15 | CONSISTENT |
| 4 | A/H column length | `CS:247` `col.col.length = geom.aRows / hRows` = 2504 / 2606 | `EO:562` `col.length = rows`, `rows = rowsOf cm` (`ExecOpeningBlock.lean:222`) = `covRowsW16 .a/.h` = 2504 / 2606 (Cover `:74-77`) | CONSISTENT |
| 5 | A/H group and prox vector length | `CS:244` `blk.vec` = 16664 | `EO:544` `v.length = n + qPad`, `EO:593` `proxVec.length = n + qPad`; `w16r2Prm = ⟨14,2,280,280⟩` (`EO:942`) → 16384 + 280 = 16664 (DERIVED) | CONSISTENT |
| 6 | A group-vector count | `CS:246` `aOpen.groupVecs.length = aGroups` = 36 | `EO:586` `= (groupZclaims claims.a 2504 14).length` = distinct `ZKey`s (`EO:406-421,449-459`). DERIVED from `rawSlot` (`BlockDefineW16.lean:313-495`), `aOff` (`:184-185`), ids (`:135-145`), schedule (`ExecBlockR13.lean:391-393`): SS 1, SSM 1, TZC 9 (`c0 ∈ {k·128, k<9}`, log 7 < 14), LZC 1, RS 1, QMM/KMM/VMM 3, SCORE 2, PV 2, WO/GMM/UMM/DMM 4, DZC 2, QZC 2 (flip coordinate at 12 is in the tail), KVZC 2, SZC 2, FZC 1, TAB 1, IOIN 1, IOOUT 1 = 36 for generic challenges | CONSISTENT (fails only on `G` with key collisions; §0.2) |
| 7 | H group-vector count | `CS:246` `hGroups` = 9 | `EO:586` on `hc = claims.h ++ [logupSumClaim]` (`BV:401`). DERIVED: H tables at slots 3, 14-20 (`hCnt` `BlockInstW16Shield.lean:124-125`), each slot's helpers on one domain (`hDoms` `BlockDefineW16.lean:236-239`): 8 keys, plus `logupSumW16`'s key `⟨[],0,2^14⟩` (`:599-603`, L domain log 14) = 9 | CONSISTENT (same caveat) |
| 8 | PCS parameter refusals (independent of the core) | `EO:580` `cmLogCols = prm.logCols`: 14 = 14 (`ExecOpeningBlock.lean:222`); `EO:581` `qPad ≥ nQ`: 280 ≥ 280 | `TR:155` `isPow2 2^15` holds | CONSISTENT |
| 9 | M `q`, `prox` lengths | `CS:242` `maskVec` = 1024 | `EM:152,157` `2·mMsg` = 1024 (`EM:70`) | CONSISTENT |
| 10 | M column count | `CS:242` `maskChecks` = 256 | `EM:159,162` `idx.length`, `challengeIndices mQ mDom`, `mQ` = 256 → 256 (DERIVED, as row 2) | CONSISTENT |
| 11 | M column index | `CS:243` `col.j < maskDom` = 4096 | `EM:135` `j = wj`, `wj < mDom` = 4096 (`TR:147`) | CONSISTENT |
| 12 | M column length | `CS:243` `mRows` = 50 | `EM:136` `2S + 4`, `S = 23` (`maskField tag 23`, Cover `:108`; `ExecOpeningBlock.lean:213-215`) = 50; highest word read is index `2S+3` = 49 (`EM:116-121`) | CONSISTENT |
| 13 | M path length | `CS:243` `maskPath` = 12 | `BV:394` `pathsDepth "M" P.maskPath` = 12; `EM:137` path = 12 | CONSISTENT |
| 14 | Slot count | `CS:239` `slots.length` = 23 (`ExecBlockR13.lean:391-393`) | `slotsLoop` runs over `core.slots` (`BV:360-366`); `BV:397` `fs.length = nFunctionals` = 34, where `fs` gains 1 per slot, +1 per standalone, +1 per host (`BV:311-319`). With `shdP_slotKind` (hosts {2,14..18}, standalone {3,19..22}, `RunShieldBlkInst.lean:498-500`): 23 + 5 + 6 = 34. Only 23 slots give 34 (count strictly increasing) | CONSISTENT |
| 15 | Rounds per slot | `CS:241` `rounds.length = n + e` | `BV:344` `scVerify … d (n+e)`, `ExecSumcheck.lean:137` `rounds.length = nRounds` | CONSISTENT |
| 16 | Round length | `CS:241` `d + 1` | `ExecSumcheck.lean:124` `s.length = degree + 1`, degree `d` (`BV:344`) | CONSISTENT |
| 17 | Terminals per slot | `CS:241` `terms.length = shieldTerms[i]` (`BlockInstW16Shield.lean:37-38`) | `BV:341` `= nPriv`; `BV:290` `nPriv = slotTerms` (same list). `define`'s `nPriv` = `aCnt + hCnt` (`progW16_shieldU1_cntA/H`, `BlockDefineW16Shield.lean:215-238`, at `cfgU1 = cfgShieldU1`, `BlockW16U1Base.lean:48`) + 1 `epTab` at 21, 22 only (`BlockDefineW16.lean:276,492-494`) = `shieldTerms` (`cnt_terms_w16_shield`, `BlockInstW16Shield.lean:132-135`) | CONSISTENT |
| 18 | `kind` against `define`'s `hosted` (`BV:291`) | `hosted` non-empty exactly at 2, 14, 15, 16, 17, 18 (`BlockDefineW16.lean:334,395,422-423,448,467`; `[]` elsewhere) | `shdP_slotKind` host exactly there (`RunShieldBlkInst.lean:499`) | CONSISTENT |
| 19 | `extRound < e` (`BV:294`) | `extRound` 0, except 1 on SCORE/PV's second table (`BlockDefineW16.lean:370,374`) | `e` = 2 at slots 8, 9; 1 elsewhere (`ExecBlockR13.lean:391`) | CONSISTENT |
| 20 | `coords.length = log` (`BV:294`) | `privOKb` (`BlockDefineSym.lean:285`) | `progW16_shieldU1_ok` (`BlockDefineW16Shield.lean:200-204`), proved by `decide` | CONSISTENT |
| 21 | Hosted index < scalars so far (`BV:282-283`) | `scalars` gains one per slot | hosts 2←{0,1}, 14←{10,13}, 15←{5,9}, 16←{6,7}, 17←{4,8}, 18←{11,12} (`SlotW16R2.lean:72-79`, `BlockDefineW16.lean` as row 18) | CONSISTENT |
| 22 | `eq` table length ≤ `n` (`BV:245`) | `rho = rhoFull.take n`, length `n` | DERIVED with `lt 7, lh 5, ldh 7, ld 12, lq 12, lf 14, lkvw 10, lkv 3`, logs from `draws` (`SlotW16R2.lean:182-204`) against `shieldDrawList` and `sched`. SS/SSM 7≤19; TZC 7,7,7≤7; LZC 14≤14; RS 12≤19; SCORE/PV 3≤10; DZC 19,19,19≤19; QZC 19,19,19≤19; KVZC 17,17,17≤17; SZC 19,12,19≤19; FZC 21,21,21≤21; TAB 14≤14; IO 19≤19 | CONSISTENT |
| 23 | Public table length `= 2^n` (`BV:296`) | slots 3, 19, 20: `cubeTab 14` / `List.range (2^14)` (`BlockW16U1TabBase.lean:77-81`, `BlockHostPub.lean:45-46`) = 2^14 = `n`; slot 19 reads at most 16 + 9 = 25 indices (`BlockW16U1Done.lean:18`), and `restEU1` defines 25 | other slots through `pubsR13 c0` (`BlockR13HostPub.lean:58-89`): `cubeTab (nD c)`, `cubeTab (nS c)`, `foldTab …`. I did not read `nD`, `nS` or `foldTab`'s length | NOT DETERMINED (slots 0,1,4-7,10-18) |
| 24 | Draw indices `define` reads | `drawAt` reads `dr.getD` (`BlockDefineSym.lean:61-62`, no length refusal); `seg` indices < `drawLen shShieldW16U1 s` (`BlockDefineW16.lean:286-288`, `cfgShieldU1.sh` `BlockDefineW16Shield.lean:41`) | `P.draws s = shieldDraws s = drawLen shShieldW16U1 s` (`BlockInstW16Shield.lean:82-87`); cross-slot reads only of earlier slots. `nonzero` lists hold only draws (zero for a negligible set of `G`) | CONSISTENT |
| 25 | Header rows | `BV:379,384` absorb `P.aRows` 2504, `P.hRows` 2606 | `pcsField` uses `rowsOf` 2504/2606 (row 4). Lean never compares the two | CONSISTENT (no constraint; values agree) |
| 26 | Mask functionals | `combinedWeights 23` rows (`EM:99-101`); `addRow`/`addPrefix` drop out-of-range terms silently (`EM:83-92`) | functionals from `slotAcc` (`BV:310-319`) | CONSISTENT (no count refusal) |
| 27 | Claim reserved rows | `maskRow` up to `2280 + 2·110 + 1 = 2501 < 2504`, `2516 + 2·43 + 1 = 2603 < 2606` (DERIVED; `BlockDefineW16.lean:506-511`, `aDataRows/hDataRows` `BlockW16U1Base.lean:72-74`) | `addAt` ignores an out-of-range row (`EO:400-403`) | CONSISTENT |
| 28 | `CoreCanon` (`ExecBlockWire.lean:271-272`) | every slot, mask and opening word `< p` | no verifier step found that needs a non-canonical word | CONSISTENT |
| 29 | `checkOpening` (`BV:402,406`) | free parameter of the cover | a refusing choice empties `BlockAcc`; `checkField`'s audit not read | NOT DETERMINED (choice-dependent; §0.3) |
| 30 | `preChecks` (`BV:391`) | `.ok ()` (Cover `:100`) | n/a | CONSISTENT |
| 31 | (outside `BlockAcc`; `decodeFork` only) frame length vs ceiling | `forkLen` = 24,540,200 B (DERIVED from `ExecBlockWire.lean:87,108-117`: slots 27,344; mask 243,712; A 15,619,648; H 8,649,280) | `ceiling` 268,435,456 (`ExecBlockR13.lean:292`) | CONSISTENT |

## 2. Checklist: equalities that satisfiable `BlockAcc` forces on an arbitrary `P : BlockParams`

Necessary conditions only. "IsShieldW16?" says whether `Link.IsShieldW16` (`BlockInstW16Shield.lean:140-150`) already
implies the condition. Items 3-13 assume `pcsVerify = pcsField tag rowsOf` and `maskVerify = maskField tag S`, which
`IsShieldW16.hPp/hPm` give with S = 23.

| # | Forced condition | Forced at | IsShieldW16? |
|---|---|---|---|
| 1 | `geom.blk.path = aPath = hPath` (when `blk.checks > 0`) | `ExecBlockWire.lean:245`; `ExecBlockVerify.lean:392-393` | no |
| 2 | `geom.maskPath = P.maskPath` (when `maskChecks > 0`) | `ExecBlockWire.lean:243`; `ExecBlockVerify.lean:394` | no |
| 3 | `geom.blk.path = log2(2^14 · 2) = 15` (hence `aPath = hPath = 15`) | `ExecOpening.lean:582,942` | no |
| 4 | `geom.blk.checks = 280` | `ExecOpening.lean:596-599`; `ExecTranscript.lean:141-155` | no |
| 5 | `geom.blk.vec = 2^14 + 280` | `ExecOpening.lean:544,593` | no |
| 6 | `geom.blk.encCols ≥ 2^15` (needed for every index sample; smaller only loses the `G` that draw a larger index) | `ExecOpening.lean:561`; `ExecTranscript.lean:147` | no |
| 7 | `geom.aRows = rowsOf .a`, `geom.hRows = rowsOf .h` (so 2504, 2606) | `ExecBlockWire.lean:247`; `ExecOpening.lean:562` | rowsOf side only (`hrA`, `hrH`) |
| 8 | `geom.aGroups` = distinct keys of `claims.a`; `geom.hGroups` = distinct keys of `claims.h ++ [logupSumClaim]` (36, 9 generically at this `define`) | `ExecBlockWire.lean:246`; `ExecOpening.lean:586` | values fixed (`hag`, `hhg`); the link to `define` needs `hdef` and is not proved |
| 9 | `geom.maskVec = 1024` | `ExecOpeningM.lean:152,157` | no |
| 10 | `geom.maskChecks = 256`; `geom.maskDom ≥ 4096` (same caveat as 6) | `ExecOpeningM.lean:159,162,135` | no |
| 11 | `geom.mRows = 2S + 4` (= 50) | `ExecOpeningM.lean:136` | S only (`hPm`) |
| 12 | `geom.maskPath = P.maskPath = 12` | `ExecOpeningM.lean:137`; `ExecBlockVerify.lean:394` | no |
| 13 | `nFunctionals = |slots| + #standalone + #host` (over slot indices `< |geom.slots|`) | `ExecBlockVerify.lean:311-319,397`; `ExecBlockWire.lean:239` | value 34 (`hnf`) and slots (`hsl`); `kind` not fixed |
| 14 | `kind s = host` ⇔ `define`'s `hosted` at `s` is non-empty | `ExecBlockVerify.lean:291` | no (premises `hk3`, `hk19`, `hk20` pin three slots) |
| 15 | `geom.terms[s]` = number of private tables that `define` gives at `s` | `ExecBlockVerify.lean:290` | `htm` fixes the list; equality with `define` needs `hdef` (row 17) |
| 16 | each private table `extRound < geom.slots[s].e`, `coords.length = log`; each public table length `2^n`; each `eq` point `start + len ≤ n`; each hosted index `< s` | `ExecBlockVerify.lean:282-283,293-297,245` | no (`hsl` + `hdef` make them a property of `define`) |

Not forced by `BlockAcc`, yet needed for "this is the code's verifier": `P.aRows = rowsOf .a`, `P.hRows = rowsOf .h`
(absorbed only), `P.logCols = 14` (premise `hlc`; `pcsField` hard-codes 14), `P.draws ≥` the draws `define` reads
(a shortfall reads zero and is refused only through `nonzero`), the endpoint `rowsOf`, `name`, and `checkOpening`.

## 3. Limits

- I did not read the bodies of `pubsR13`'s tables at slots 0, 1, 4-7 and 10-18 (`nD`, `nS`, `foldTab`), so their
  lengths stay NOT DETERMINED (row 23). Nor did I read `auditClaims`/`openingGroupsAt`/`openingChallenges`
  (`checkField`), `Cfs.sumWeights`/`evalWeights`, `irEvalW`, `eqPoint`/`evalMleExt`, `scLoop` beyond its length
  checks, `verifyPath`, or the `ShapeW` record `shShield` itself. I derived the `ShapeW` logs used in rows 6 and 22
  from `shieldDrawList` and `shieldSlots`, which the tree proves equal to `drawLen`/`sched` (`BlockInstW16Shield.lean:72-79`).
- Rows 6-7 count keys symbolically. Equal keys need equal challenge values. I did not bound how many `G` are lost.
- Rows 1-31 compare counts and shapes only. The algebraic equalities (sumcheck round sums, `⟨v, c⟩ = want`, column
  encodings, the Merkle paths against the roots, the mask product and proximity checks) were not examined for joint
  satisfiability. Whether an honest core meets all of them at this record (in particular with `covRowsW16`'s
  placeholder endpoint rows and the `checkOpening` chosen) is not shown here or, as far as I found, anywhere else.
- I read only Lean. No Rust was consulted for this read; the Rust values cited in the cover header come from
  `W16R2_PARAMS_READ_20261127.md`.
