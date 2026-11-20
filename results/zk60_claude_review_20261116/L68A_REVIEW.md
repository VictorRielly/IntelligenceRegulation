# Review of Lean lane L68a (Antigravity), 2026-11-17

Reviewer: Claude (independent, read-only on formal/ and ops/). File under review: `formal/ZK60Formal/RunShieldBlkInst.lean` (835 lines, untracked, not imported by `formal/ZK60Formal.lean`), sha256 `92e49c7fcf318ddbfab77a64966e3028d06b161fff01fb7d3360aff67c485645` (equal to the posted one).
The author's claims are item 2 of the entry "Antigravity (co-coordinator) 2026-11-17T20:26:00Z" in `ops/zkp-mvp/RECOVERY_COORDINATION.md` plus the file header.
Baseline: `L67_REVIEW.md` (its open list and findings M1, M2, L2, L3). Marking: [CHECKED] = by me, with the command or line; [CLAIM] = the author's, not re-derived; [NOT CHECKED] = could not or did not.

## Verdict: ACCEPT WITH FIXES

Every kernel claim holds. The file elaborates from source with no error and no warning; all 52 declarations (20 public, 32 private) print only `propext`, `Classical.choice`, `Quot.sound` or fewer; no forbidden token; nothing else under `formal/` changed.
The top theorem is the L63 theorem `sshC_productionReadyL_epP_shieldLu` applied once (after a `have`) at concrete arguments, and the kernel accepts it; I found nothing false, nothing circular, no premise dropped silently.
What the summary overstates is the meaning of "discharged": (1) `hPk0` is gone because the block verifier is now **defined** by this file (`shdP_Pk0`), not because a fact about the registered verifier was proved; the theorem now holds for one Lean-defined verifier family, narrower than the old premise (M1). (2) "Clamp eliminated" is true only of `O` and the conclusion; the clamp is still inside all four stage premises and `min k 25` is now inside the definition of `shdP_Pk0` (L1). (3) "hzk discharged" is a numeric bound on an error function; the zero-knowledge property itself is still the field `O.zk` of the open `O` (L5, answer D).
Counts: High 0, Medium 1, Low 6, Note 6.

## What I ran

| Step | Guard run | Exit | Wall | Peak RSS | Note |
|---|---|---|---|---|---|
| Single-file elaboration of the review copy (source + `#print axioms` for all 52 declarations + a meta appendix that dumps signatures and reducibility), `lake env lean`, no `-o`, LEAN_NUM_THREADS=2 | `c85b4182aa30`, `claude-l68a-review-elab`, class build | 0 | 28 s (no wait for the heavy lock) | 4.15 GiB | `l68a_review/l68a_elab.sh`, `blk_elab.out`, guard log `elab.guard.log` |

One run only. The review copy equals the source plus 103 inserted lines before the final `end ZK60.ProtocolClassify` (`diff` shows 0 removed lines, one insertion hunk 835-937). No .olean was written (no `-o`), nothing was written under `formal/`, nothing built in the shared tree. Imports were read from the shared `.lake` build products, which I did not hash-tie to their sources (the `RunStgShieldTopSJ.olean` is dated 12:13, its source 12:00, and `git status --short formal` shows only the new file).
Lean 4.34 does not expose the proof term of a theorem of the file being elaborated, so unlike L67 there is no machine-dumped argument map; the proof is `have hmain := shieldLu (named arguments)` followed by `exact`, so the argument map is the source text, lines 811-831, tabled below. The kernel acceptance of that term is what makes the table true.
The author's runs, found in `results/zk60_resource_guard/history.jsonl`: `b4e0d006bea0` (`agy-lean-l68a-build6`, build, exit 0, 18.05 s, 4.31 GiB) and `c45237304d9c` (`agy-lean-l68a-axioms`, cpu, exit 0, 2.7 s, 3.50 GiB). Both match the summary. A 2.7 s run cannot have elaborated the source (mine took 27 s), so the author's axiom listing was read from a compiled module, not from source; mine is from source.

## A. Kernel facts [CHECKED]

- **Hash.** Equal to the posted one (`shasum -a 256`).
- **Elaboration.** 0 errors, 0 warnings, 0 other messages (`grep -c -i "warning|error|sorry" blk_elab.out` is 0).
- **Axioms** (`parse_axioms.py`): 52 of 52 source declarations have a printed line: 45 print `[propext, Classical.choice, Quot.sound]`, 3 print `[propext, Quot.sound]`, 2 print `[propext]`, 2 depend on no axiom. 0 outside the standard set, 0 `sorryAx`, 0 `Lean.ofReduceBool`. The 20 public ones: all 20 on the three standard axioms except `shdP_rowsOf` (`[propext]`) and `shdP_slotKind` (none). The top theorem prints all three. The summary says "20/20 public decls strictly on [propext, Classical.choice, Quot.sound]": it should say "at most".
- **Counts.** 52 declarations: 20 public (9 theorems, 11 definitions, abbreviations and instances) and **32 private** (19 private theorems, 13 private defs). The summary says **21** private. Wrong by 11 (L3).
- **Forbidden tokens** (grep over the file): no `sorry`, `admit`, `axiom`, `native_decide`, `unsafe`, `opaque`, `implemented_by`, `extern`, `decide +kernel`, `macro`, `elab`, `run_cmd`. `set_option`: `autoImplicit false`, `linter.constructorNameAsVariable false`, `quotPrecheck false` (line 616, inside the top section, parsing only). `classical` at 531 and 556 (tactic). `absurd` at 338 and `exfalso` at 466 are inside the `gS_pad` and `Wo_pad` fields of `shdP_w16Pub` and are legitimate: they use that the slot and head-dimension axes are surjective (`msbBits_tokInv`, `slotEmb_slotInv`), so those pad cases do not occur (Note N3). One `attribute [irreducible] shdP_Pk0` (line 586), global.
- **`git status --short formal`:** one line, `?? formal/ZK60Formal/RunShieldBlkInst.lean`. `git diff --stat -- formal/ZK60Formal/Statements.lean formal/ZK60Formal.lean`: empty. The file is **not imported** by the root file, so `lake build ZK60Formal` does not build it; "built" in the summary means a single-file elaboration (the author's guard runs, and mine).
- **Name collisions.** None of the 20 public names is declared in any other file under `formal/ZK60Formal/` (grep). The "530+ files" count I did not check.

## B. Premise accounting by machine [CHECKED]

Method: the signature of `sshC_productionReadyL_epP_shieldLu` (read from its compiled module) and of `sshC_productionReadyL_epP_blkLu` (from the fresh elaboration) printed by Lean (`forallTelescope`, Prop flag per binder; `sigp_shieldLu.txt`, `sigp_blkLu.txt`), diffed by name (`sigdiff.py`, `sigdiff.out`).

Counts. shieldLu: 63 binders (8 instance, 55 other: 18 Prop, 37 data or type; 50 explicit). blkLu: 41 binders (4 instance, 37 other: 9 Prop, 28 data or type; 34 explicit).
**Removed by name: 22 (10 Prop, 12 data). Added: 4 (1 Prop, 3 data). Kept: 33 (27 with identical text, 6 with changed text).** Net -18 non-instance binders (explicit 50 to 34, net -16).

| Group | Binders (shieldLu) | Supplied by (source line) | How |
|---|---|---|---|
| Field and bijection | `K U hbij hU` | `shdP_K`, `shdP_U`, `shdP_hbij`, `shdP_hU` (812-813, 820) | instantiation; `shdP_hbij` from `fp2_bijective` with `finrank = 2` and `seven_not_square` (G below) |
| Layout and block verifier | `dPos0 Pk0 hPk0` | `shieldDPos0`, `shdP_Pk0 tag ioIn ioOut checkOpening Rp`, `shdP_shieldRunAtD ... hR` (813, 818) | **by construction**, see M1; `hPk0` replaced by new `hR : ShieldRun Rp` |
| Domain | `domain hs hL` | `shdP_runDomain`, `shdP_runDomain_start_none`, `shdP_runDomain_start_le hL20` (815) | closes L67 M1 for the domain |
| Stage IO pins | `csIOI csIOO hcsI hcsO rE lcE Qe XE hXEl` | the pinned formulas (`stgCsIOm ...`), `rfl`, `0`, `0`, `0`, `fun _ _ _ => 0`, `rfl`, `fun _ _ _ _ => rfl` (819-822) | by choosing the data to be the pinned values; with `rE = 0` the type `Fin 0 → ...` has exactly one inhabitant (N1) |
| Vocabulary | `hV` | `O.inPub.V2` (822) | taken from the still-open `O` |
| Zero-knowledge budget | `εzk hzk` | `εzk := refErr RunK.kinds` (type of `O`), `hzk := shdP_hzk` (820) | numeric bound only, see D |
| New | `hR`, `ioIn`, `ioOut`, `checkOpening` | | `hR : ShieldRun Rp`; the three data are arguments of `shdP_Pk0` |

Kept with changed text: `site` (type now over `shdP_K`), `O` (carries `shdP_Pk0` at the unclamped params and `refErr RunK.kinds` as its error function), `hLI_stg hLO_stg hdinS hdoutS` (the removed binders substituted by their values). The kernel accepted `(hLI_stg := hLI_stg)` etc. at shieldLu's binder types, so these four are the shieldLu premises after substitution, nothing else; the only change in their text is `shdP_Pk0 ...` for the former `Pk0` (still wrapped in `shdP_clampPk`, see L1), `shieldDPos0` for `dPos0`, `shdP_K`, `shdP_U`, `shdP_runDomain`, and the explicit `stgCsIOm` terms for `csIOI`, `csIOO`.
The `shdP_clampPk` and `shdP_Pk0` counts in the binder texts: `hLI_stg` 8 and 8, `hLO_stg` 8 and 8, `hdinS` 7 and 7, `hdoutS` 9 and 9; `O` has `shdP_Pk0` once and no clamp; the conclusion has no clamp (`sigp_blkLu.txt`, python count).

**The open list of blkLu by name** (34 explicit arguments, plus the implicit types `Hdr`, `Coins`, `ι` and 4 instance arguments `Fintype Coins`, `Nonempty Coins`, `Inhabited Coins`, `Fintype ι`):
- *Stage facts for the other lane (4):* `hLI_stg` (stage IN-C LogUp state at the full reading), `hLO_stg` (stage OUT-C LogUp state), `hdinS` (stage IN-C doom over `epxBndE ... E0`), `hdoutS` (stage OUT-C doom).
- *Instantiation leftovers:* `tag` (the hash-tag key set); `Lq hL20 hL64` (the log length and its two bounds); `key` (the optional transcript key); `Rp` (the run's public data); **`hR : ShieldRun Rp`** (new: the run's 26 calibrations are the export's); `hw hhdrFit` (header words and the header-fit fact); the verifier hooks `preA preB check0 paths digest bndCheck`; **`ioIn ioOut checkOpening`** (new: the program's IO numbers and the opening-check closure, now arguments of `shdP_Pk0` and so of the verifier in the conclusion); the run data `embDigest embFold bInRow wDigest bOutRow`; the honest prover's data `P epBase`.
- *Oracle and zero knowledge:* `ι site kOf δOf` (the refusal sites and their counts) and `O : ClassifyOpenP` (width, shapes, weights, inPub, outPub, blocks, commit, policy, parts, refuse, counts, and **zk**), and `E0` (the extractor; occurs once in `hdinS` and once in `hdoutS` and nowhere else).
- *Other:* nothing.

## C. The conclusion [CHECKED]

The conclusion of blkLu has the head and targets of shieldLu's: `ProductionReadyL (classifyModelP Rp) (classifyArithP Rp) <Proto> (classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget` (`sigp_blkLu.txt`, `sigp_shieldLu.txt`), the form the L66 and L67 theorems already had. It is **not the same proposition** after substitution; it differs in the protocol argument only: shieldLu's has `d12aBlockProf (shdP_clampPk Pk0) (shdP_sgeom Hdr (shdP_clampPk Pk0)) ...`, blkLu's has `d12aBlockProf (shdP_Pk0 ...) (shdP_sgeom Hdr (shdP_Pk0 ...)) ...` (`ProtoUnclampedB`), and the domain is `shdP_runDomain`.
The rewrite is proved in the file, not assumed: `shdP_clampPk_Pk0 : shdP_clampPk (shdP_Pk0 ...) = shdP_Pk0 ...` (lines 544-549, `funext`, `simp only [shdP_clampPk, shdP_Pk0, Nat.min_assoc, Nat.min_self]`). Direction: `hmain` (about the clamped protocol) is transported to the unclamped one by `(congrArg (fun Pk => ProductionReadyL ... Pk ...) hclamp).mp hmain` (824-831), and `O`, given at the unclamped params, is transported to the clamped one by `(congrArg ... hclamp.symm).mp O` (805-810). So the final statement is about the protocol built from `shdP_Pk0` itself; the four stage premises are still stated about the clamped one (equal as a function, so a stage prover can rewrite).
`Statements.lean` is unchanged (empty diff), and `ProductionReadyL` is the one defined there (line 351). What the statement is about: `classifyProtocolUExecP Rp Lq 26 preA preB (clsStart shdP_runDomain key hw) ... (d12aBlockProf (shdP_Pk0 tag ioIn ioOut checkOpening Rp) ...) ... P (epTokenCommit ...) ...`: the executable Lean model of the registered classify-run verifier, over the 26-layer Shieldstral T128 R13 run, with free hooks, at the Lean-defined block parameters. Whether that model is the Rust verifier is a correspondence the file cannot prove (M1).

## D. hzk [CHECKED]

`hzk` in shieldLu (`RunStgShieldTopSJ.lean:412`, `sigp_shieldLu.txt`): `∀ q R', q ≤ 2^64 → R' ≤ 2^64 → εzk q R' ≤ εzkTarget q R'`, with `εzk` an implicit function argument that also parametrises `O`. In blkLu `εzk := ZK60.ZKHonest.refErr ZK60.ZKCount.RunK.kinds` (it occurs in the type of `O`).
`shdP_hzk q R' (_hq : q ≤ 2^64) (hR' : R' ≤ 2^64) : refErr RunK.kinds q R' ≤ εzkTarget q R'` (line 77; `_hq` is unused). `runK_ref_cap_110 (q R) (hR : R ≤ 2^110) : refErr RunK.kinds q R ≤ εzkTarget q R` (`ZKHonestCount.lean:175`): an arithmetic bound on a sum `Σ_{j<R} wStep ...` over the counts record `RunK.kinds`, proved with `ref_cap_R` from per-kind count bounds (`by decide`, `by norm_num`).
**What is and is not proved about zero knowledge after this file:** the file proves only that the error function `refErr RunK.kinds` is at most the approved target `q·2^-128 + R'·2^-120` for q and R' up to 2^64; the zero-knowledge property itself (a simulator for the classify run at that error) is still assumed, as the field `zk : ZeroKnowledge (classifyModelP R) (classifyProtocolP ...) εzk` (O12) of the open `O : ClassifyOpenP` (`RunShapeProtocol.lean:472-473`), which the gates read as `O.zk` (`RunShapeProtocol.lean:499, 519`). The agreement of the counts record `RunK.kinds` with the real receipt is the earlier lane's (L19) and I did not check it.

## E. hPk0 and hR [CHECKED unless marked]

- `ShieldRun` is defined at `RunShapeShield.lean:244`: `ShieldRun R := R.blks.map RunBlock.cal = shieldExport.map shieldCal`, i.e. the run's 26 per-block calibrations are the export's, in order. It says nothing about block data, layout or verifier parameters.
- It is **new as a premise of this theorem**. It was not a premise of shieldInst or shieldLu; `hPk0 : ShieldRunAtD ...` implied its content for `k < 26` (the existential carries `b.cal = shieldCal Ly` and `shieldExport[k]? = some Ly`) and the length through `O.blocks` and the verifier's `L = 26`.
- `shdP_shieldRunAtD` needs `hR` for: `Rp.blks.length = 26` (from `congrArg List.length hR` and `shieldExport_l17.1`), `shieldExport[k]? = some Ly`, `Rp.blks[k]? = some b`, `b.cal = shieldCal Ly` (from `congrArg (fun l => l[k]?) hR`), and the cast of `b.pub` used by `shdP_Pk0`. Everything else in `ShieldRunAtD` (draws, slots, terms, groups, functionals, mask and PCS verifiers, rows, `define`, kinds, `logupSumClaim`, `LayR`, `dPos`) holds by `rfl` or by `shdP_bitLay_layR`, `shdP_bitLay_dPos`, because `shdP_blkParams` is built to have them (`shdP_blkParams_shieldBlkAtD`, 512-524).
- The existence theorem `shield_run_exists : ∃ R, ShieldRun R ∧ R.Valid` (`RunShapeShield.lean:326`, standard axioms, printed by me) is for a run with the real shapes, the export's 26 calibrations, a policy stage, a valid OUT-C stage and **zero block data** (`shieldZeroBlocks`). So `hR` is satisfiable and is not vacuous; it is not trivially true either (it restricts the calibration list of `Rp`), and for the real run it holds by construction of `Rp` from the export. It does not make `O` or the four stage premises satisfiable by itself [NOT CHECKED: joint satisfiability].
- `ioIn`, `ioOut`, `checkOpening` are **free arguments**, and they **do appear in the conclusion and in `O`** (through `shdP_Pk0 tag ioIn ioOut checkOpening Rp`). Before, `hPk0`'s existential allowed ioIn and ioOut to differ per block and `checkOpening` per block; now one triple serves all 26 blocks and the layers' `define` programs. The theorem is true for every triple; it applies to the registered verifier only if the registered verifier has uniform values (M1).

## F. The layout [CHECKED against Rust, for the token and width axes]

**Verdict: agree for the token axis (7 bits), the width axis (12 bits), their order (token bits first, then width bits, most significant first), and the RoPE flip bit; could not determine for the slot, group, head-dimension pairing and hidden axes.**
Evidence (all under `ops/zkp-mvp/gpu-metal/`):
- `zkp-core/src/mle.rs:12-17`: "r[0] is the MOST significant bit of the index. So a row-major matrix index (i * cols + j) ... corresponds to the point (r_row || r_col)"; `eq_table_msb` at :56-59; `eval_mle_base`/`eval_mle_ext` use it (:73-83). `hashline/src/mle.rs` re-exports it.
- `hashline/src/private_block/witness.rs:15` and `:499-501`: `(t, i)` of `Dom::D` is at `t * d_pad + i` ("a plane of a padded domain is laid out at the domain's PADDED stride"). `shape.rs:1036`: `t_pad, d_pad = next_power_of_two` (T128, width 3072 gives 128 and 4096, i.e. 7 and 12 bits; L67 C3 had checked 4096 and 128). `shape.rs:2421`: `Dom::D` log is `clog2(t_pad * d_pad)` (19). `layout.rs:90`: "`D`: (t, i)".
- So the flat index `t*4096 + i` read most-significant-bit first is the 7 token bits then the 12 width bits, which is `shieldDPos0 p = (msbBits 7 p.1, msbBits 12 p.2)` and `Exec.msbBits n idx j = decide (idx / 2^(n-1-j) % 2 = 1)` (`ExecMle.lean:419`, printed). Same convention in the stage readers: `token_io.rs:965-967` `fixed_bits` ("the MSB-first bits of `value`").
- RoPE flip: Rust `argument_accuracy.rs:142, 550` set `Coord::Flip` at index `log - lg(head_dim)`, the first (most significant) bit of the head-dimension field; Lean `hdEmb` puts the sign/flip bit first (`i.val = 0`, line 115) and `hdFlip` flips it (line 121), and `LayR.flip` (`BlockR13HostBase.lean:382`) says the same. Agree.
- Not determined: the slot axis (`slotEmb h = (msbBits 3 (h/4), msbBits 2 (h%4))`, i.e. 8 groups of 4 heads without padding) against `witness.rs:503-509` `head_slot` (groups own contiguous slot blocks, padding at the end of each block); the group axis (3 bits), the hidden axis (14 bits, f 9216), and `hd = (flip bit, msb 6 bits of k)` beyond the flip bit. I did not run any Rust.
- "`dPos = shieldDPos0 := rfl`" is true by construction (`shdP_bitLay` is defined with `tok := axMsb ... 7`, `wid := axMsb ... 12`; `dPos p = (tok.emb p.1, wid.emb p.2)`, `W16Layout.dPos` printed). It is not a proof of fidelity; the table above is the fidelity check, and it is mine, not the file's.
- `LayR` and `ShieldRunAtD` leave unconstrained: `LayR` asks only surjectivity of the token, head-dimension, slot and group embeddings and the flip equation (width and hidden are allowed to pad). The stage readers and dooms rely on the boundary-plane map `dPos0` only (token bits then width bits); `shdIncData` reads `Fin.append (msbBits 7 t) c` (L67 M2), which is now the same convention as the instantiated `dPos0 := shieldDPos0` (it was an independent free argument before). Nothing else about the layout is read by them.

## G. The other instantiations [CHECKED]

- `shdP_K := AdjoinRoot (X^2 - C 7)` over `GF`; `shdP_U := AdjoinRoot.root _`. The `Fact (Irreducible ...)` is `shdP_X2_sub_7_irred` from `X_pow_sub_C_irreducible_of_prime Nat.prime_two` and `Exec.seven_not_square` (lines 51-56).
- 7 is a non-residue: `seven_not_square : ∀ s : GF, s * s ≠ 7` at `ExecField.lean:482` (Euler's criterion via `Goldilocks.pow7_2`); the Rust constant `NONRESIDUE: u64 = 7` at `zkp-core/src/field.rs:15`.
- `shdP_hU : shdP_U ^ 2 = algebraMap GF shdP_K 7` := `(adjoinRoot_finrank seven_not_square).2` (`HidingMOpening.lean:707`). `shdP_hbij : Function.Bijective (Hiding.fp2 shdP_U)` := `shdP_fp2_bijective shdP_U (finrank = 2) shdP_hU`, i.e. `Hiding.fp2_bijective` (`HidingMOpening.lean:701`) with `seven_not_square`. It is the bijection the earlier theorems ask for (`hbij : Function.Bijective (fp2 U)`), at `K = AdjoinRoot (X^2 - 7)`, with no premise. All on the three standard axioms (printed).
- `shdP_K_decidableEq` and `shdP_K_fintype` are `noncomputable instance`s built from the bijection with `GF × GF` (lines 70-74); they are global instances on an abbreviation (L4).
- `domain := shdP_runDomain`: `hs` and `hL` discharged by `shdP_runDomain_start_none` and `shdP_runDomain_start_le hL20`. **This closes L67 M1 for the domain and `hbij`** (L67 reported them free and unwired). The domain bytes were checked equal to the Rust profile string in the L67 review.
- `XE := fun _ _ _ => 0` with `rE = lcE = Qe = 0`: the type is `StgVw Lq → Fin 0 → Fin (2^0+0) → K`, so `XE` is the unique function of that type up to funext and `hXEl := fun _ _ _ _ => rfl` is trivial. Legitimate as an instantiation of a universally quantified theorem (shieldLu holds for every `XE`). That it is the right choice for the real verifier rests on the other lane's claim that the code refuses every claim on the output endpoint (`ssh_outc_out_nil`, `RunStgShieldTrOIO.lean:37`; header of `RunStgShieldTopSJ.lean:145-148`) [CLAIM, not re-derived]. The stage prover must then prove `hdoutS` at `csIOO` with zero endpoint rows, which is the statement now printed in the binder.
- `hV := O.inPub.V2`: a field of the still-open `O` (`ClassifyOpenP.inPub : R.inp.Valid`); fine, but it means `hV` is not free of `O`.
- `shdP_w16Pub` (lines 315-470) is a `W16Pub` over the bit cube with the pad values forced by the structure's `*_pad`, `*_one` and `*_emb` fields; the fields are proved from `msbIndex_msbBits`. Pads are 0, `gD`/`gF` are indicators of the unpadded range, `gT gQ gK gS gHt` are 1.

## H. Irreducible attributes [CHECKED]

One new attribute: `attribute [irreducible] shdP_Pk0` (line 586), **global** (not `local`); `reducibility.txt` shows `shdP_Pk0 : irreducible`, `shdP_rtRun` and `shdP_wDelta` (L67's) also irreducible, `shdP_bitLay shdP_w16Pub shdP_blkParams shdP_clampPk shdP_rowsOf shdP_slotKind` semireducible, `shdP_K` reducible. The facts downstream files need are proved before it: `shdP_clampPk_Pk0` (544) and `shdP_shieldRunAtD` (552); the comment says so. The proof `hPk_eq : shdP_Pk0 ... k = shdP_blkParams ... Ly Pb` is local to `shdP_shieldRunAtD`, so no exported equation gives a field of `shdP_Pk0 k` except through the `ShieldRunAtD` existential; the stage prover who needs a field value must use `unfold shdP_Pk0` (not tested after the attribute) or add the lemma before the attribute. L3 of the L67 review (global irreducible) is **not closed**: there is one more.

## I. Vacuity and misuse [CHECKED unless marked]

- Premises not used by the proof term: every one of the 34 explicit arguments occurs in the source of the proof: `hR` through `HPk0B`, `ioIn ioOut checkOpening` through `Pk0B`, `hL64` in the stage premises and the call, `hhdrFit` in `RnB`, `site kOf δOf O` in the call. (No machine "use" dump; the proof term of the same file is not accessible.)
- Concrete choices that could make a remaining premise unsatisfiable: none found. `Fin 0` in `XE` is intended (E, G). `hLI_stg hLO_stg hdinS hdoutS` are, by the kernel acceptance of `(hLI_stg := hLI_stg)`, exactly shieldLu's premises at the substitution: the same readers (`shd_ΛI`, `shd_ΛO` at `shdP_incPub Rp ..`, `shdEpad Rp.inp`, `pf.off 0 + 2` and `+5`, `pf.off 27 + 2`), the same extractor `epxBndE ... E0` with `E0` free and occurring once each in `hdinS` and `hdoutS`, the same `shdP_eI shdP_eO`; the only changes are the substitutions listed in B. They are not easier or harder than the other lane's task C statements except that `dPos0 = shieldDPos0` is now fixed, which is what the L63 handoff asked for.
- Steps from a contradiction: none. The only `exfalso` and `absurd` are in the pad fields of `shdP_w16Pub` (lines 338, 466), valid because those axes are surjective.
- Possibly empty index types: `Fin 0` in `XE` (above); `Fin 7`, `Fin 12`, `Fin 3`, `Fin 14`, `Fin 128`, `Fin 3072`, `Fin 9216` are non-empty. `Hdr` and `ι` are free types (as before; an empty `Hdr` makes `hhdrFit` vacuous, harmless; an empty `ι` just removes refusal sites). [NOT CHECKED] that one instance satisfies all premises at once; `hR` alone is satisfiable (`shield_run_exists`).

## Findings

### Medium

**M1. `hPk0` is "discharged" by defining the verifier; the theorem is now about one Lean-defined verifier family, narrower than the old premise.** (`RunShieldBlkInst.lean:489-541`, `:552-582`.)
Before, `Pk0 : ℕ → BlockParams` was an arbitrary argument constrained only by `ShieldRunAtD`, which leaves `aRows hRows aPath hPath maskPath preChecks name`, and per block `ioIn ioOut`, `rowsOf` and `checkOpening` unconstrained, so the theorem held for every verifier with the right schedule. Now `Pk0 := shdP_Pk0 tag ioIn ioOut checkOpening Rp` and these fields are fixed by `shdP_blkParams`: `aRows 4577`, `hRows 4390`, `aPath = hPath = 16`, `maskPath = 12`, `preChecks := .ok ()`, `name s := toString s`, `geom := R13.geom ... 23 36 4577 9 4390`, `nFunctionals 34`, `kind` standalone at `{3, 19, 20, 21, 22}`, and one `(ioIn, ioOut, checkOpening)` for all 26 blocks (`min k 25` also makes blocks `k ≥ 26` copies of block 25). The proofs `shdP_blkParams_shieldBlkAtD` and `shdP_shieldRunAtD` are `rfl` and the layout theorems, so they prove only that the definition satisfies the spec `ShieldRunAtD`; that the registered Rust verifier equals this definition is a modelling claim outside Lean. I checked what the existing Lean says: `aPath = 16`, `maskPath = 12` equal `blkDim.path` and `W16R2.maskPath` of `ExecBlockR13.lean:289, 297`, and `preChecks := .ok ()` is the stand-in of the L9 and L17 corpus checkers (`CheckR13Block.lean:168-172`); so the values are consistent with the existing model, but I did not check them against the Rust.
What this means: the L67 open item "`hPk0` with `dPos0` and `Pk0` (that the registered verifier has this layout at every block)" is not discharged but converted into "the registered verifier is `shdP_Pk0` at some `(ioIn, ioOut, checkOpening)`". Fix: say so, and add the correspondence (a list of the fields above with their Rust sources, or a corpus check as L9 and L17 did) to the open list.

### Low

**L1. "Clamp eliminated" and "L2 wired" are partly true.** The clamp is gone from `O` and from the conclusion (`ProtoUnclampedB`), by a proved equality (C). It is still in all four stage premises (8, 8, 7, 9 occurrences in `hLI_stg hLO_stg hdinS hdoutS`, via `RkDLB`, `ProtoClampedB`, `BadEvB`) and the `min k 25` is now inside `shdP_Pk0`'s definition. The reason it is harmless is unchanged from L67 L2 (`classifyProtocolExec_verify_iff` reads blocks `0..L-1` only, cited, not proved here). L67 L2's gap "no theorem equates the clamped and unclamped protocol" is closed for the concrete verifier. Accurate wording: "the clamp is removed from `O` and the conclusion; the four stage premises still mention it".

**L2. Layout fidelity covers two of the layout's axes.** Header and summary say the layout embeds "Tok/Wid/Grp/Hid via MSB-first `Exec.msbBits`"; it also fixes the head-dimension axis (flip bit first, then 6 msb bits of the index, `hdEmb`) and the slot axis (`msbBits 3 (h/4)` with `msbBits 2 (h%4)`). I verified token, width and flip bit against the Rust (F); the slot, group, hidden and the hd pairing beyond the flip bit I could not determine.

**L3. Counts in the summary.** "20 public / 21 private": the file has 20 public and 32 private declarations (A). "20/20 public decls strictly on the three axioms": two print fewer (`shdP_rowsOf [propext]`, `shdP_slotKind` none). "Built" means a single-file elaboration; the file is not in the root import list. The author's "0 collisions" and the "530+ files" I did not check (I checked the 20 public names).

**L4. Global instances and a global irreducible.** `shdP_X2_sub_7_fact : Fact (Irreducible (X^2 - C 7))`, `shdP_K_decidableEq` and `shdP_K_fintype` are global instances on `AdjoinRoot (X^2 - C 7)` (an abbreviation `shdP_K`). They are true and harmless unless another file declares a competing `Fintype` or `DecidableEq` on the same type (I found none in `formal/ZK60Formal/`: grep for `shdP_K`). `attribute [irreducible] shdP_Pk0` is global and no unfolding equation is exported (H).

**L5. The remaining list in the summary is short.** "Only (1) the 4 stage premises, (2) `O`, `hhdrFit`/check-hook pins": the list should also carry `hR : ShieldRun Rp` (new; present in the Lean header but missing from the entry), `ioIn ioOut checkOpening` (new, in the conclusion), `E0` (free, in the two doom premises), the verifier hooks `preA preB check0 paths digest bndCheck` (universally quantified, not "pinned": the registered values must satisfy `O.policy` etc.), and the run and prover data `tag Lq key Rp hw embDigest embFold bInRow wDigest bOutRow P epBase`. And `hzk discharged` should read "the numeric bound on the error function is proved; the zero-knowledge property is `O.zk`" (D).

**L6. Author's summary of the gates.** "`ZK60Formal.lean` untouched so zero root-file conflict" is true and is also why the file is not built by the root; "20/20 public decls" was read from a compiled module in 2.7 s (not from source); mine is from source and also covers the 32 private declarations.

### Note

**N1.** `XE`, `rE`, `lcE`, `Qe`: with `rE = 0` the matrix has no rows, so `XE := 0` is the unique choice and `hXEl` is trivial (G).
**N2.** `hV := O.inPub.V2` uses the open `O` (G). `hzk`'s first hypothesis `q ≤ 2^64` is unused (the bound holds for every `q`).
**N3.** `exfalso`/`absurd` at lines 338 and 466 are for pad cases that cannot occur on the surjective axes (`gS_pad`, `Wo_pad`); legitimate.
**N4.** No premise of shieldLu is silently dropped: the 22 removed binders are all supplied (table in B); the 4 new ones are `hR`, `ioIn`, `ioOut`, `checkOpening`.
**N5.** The statement form of the conclusion is the one of L66 and L67 (`ProductionReadyL (classifyModelP Rp) ... εcTarget εsTarget εsTarget εzkTarget`), `Statements.lean` unchanged.
**N6.** Item 2's statement "shdP_Pk0 is marked global `attribute [irreducible]` after its spec theorems, documented inline" is accurate (lines 584-586).

## Baseline from the L67 review: what L68a closes

- **L67 M1** (top theorem not wired to `shdP_runDomain`, `shdP_fp2_bijective`, `RunStgShieldLu`): closed for the domain (`hs`, `hL`) and `hbij` (and `hU`, `K`, `U`); the LogUp wiring (`hLuStg`) was closed by the other lane's shieldLu, not by this file.
- **L67 M2** (`shd_ΛI`/`shd_ΛO` concrete only modulo free arguments; readers vs planes): the free arguments are fixed from `Rp` by shieldLu, not by this file; the open part (the readers coincide with the planes the doom premises read) is exactly `hLI_stg hLO_stg hdinS hdoutS`, still open. L68a adds one thing: `dPos0` is now the same convention as the readers' `msbBits 7 ++ msbBits 12`.
- **L67 L2** (clamp): closed for the concrete verifier by an in-file proof, with the caveats of L1 above.
- **L67 L3** (global irreducible): not closed; one more global irreducible (H).
- **L67 open item 2** (`hPk0` with `dPos0 Pk0`): converted (M1). `U hbij hU`, `domain hs hL`: closed. `εzk hzk`: the numeric part closed (D).

## The open list after L68a (premises of `sshC_productionReadyL_epP_blkLu`; 34 explicit arguments)

1. *Stage facts for the other lane:* `hLI_stg hLO_stg hdinS hdoutS` (the same four, with `E0` free in the last two).
2. *Instantiation leftovers:* `tag`, `Lq hL20 hL64`, `key`, `Rp`, `hR`, `hw hhdrFit`, `preA preB check0 paths digest bndCheck`, `ioIn ioOut checkOpening`, `embDigest embFold bInRow wDigest bOutRow`, `P epBase`; plus the correspondence "the registered verifier is `shdP_Pk0 ...`" (M1) and the Rust fidelity of the slot, group, hidden and hd axes (L2).
3. *Oracle and zero knowledge:* `ι site kOf δOf`, `O : ClassifyOpenP` (the real work: the 28-segment honest prover for `O.parts` and `O.refuse`, and `O.zk`, the zero-knowledge property at error `refErr RunK.kinds`), `E0`.
4. *Other:* nothing.

## Sentences stronger than the source, with accurate wording

1. "`hPk0` discharged from `hR : ShieldRun Rp`": "`hPk0` is replaced by `hR` and by the definition of the verifier `shdP_Pk0`, which satisfies the spec `ShieldRunAtD` by construction; the theorem is about that Lean-defined verifier (one `ioIn ioOut checkOpening` for all blocks); that it is the registered verifier is not proved."
2. "`L2` clamp eliminated" / "`M1`+`L2` wired": "the clamp is removed from `O` and from the conclusion by `shdP_clampPk_Pk0`; the four stage premises still contain it; `min k 25` now sits inside `shdP_Pk0`. `M1` is wired for the domain, `K`, `U`, `hbij`, `hU`; the LogUp wiring is shieldLu's."
3. "`dPos0 = shieldDPos0` confirmed & proved": "`shdP_bitLay_dPos` is `rfl` because the layout is defined that way; I checked the token and width order and the flip bit against the Rust (`witness.rs:499-501`, `mle.rs:12-17`); the slot, group, hidden axes are not checked."
4. "embeds Tok/Wid/Grp/Hid via MSB-first": "also fixes the head-dimension axis (flip bit first, then msb 6 bits) and the slot axis (3 + 2 bits)."
5. "`hzk := shdP_hzk` (via `runK_ref_cap_110`)": accurate as a numeric statement; add "the zero-knowledge property itself remains `O.zk`".
6. "`20` public / `21` private decls": "20 public, 32 private (52); 9 of the public are theorems".
7. "20/20 public decls strictly on [propext, Classical.choice, Quot.sound]": "on at most those; `shdP_rowsOf` prints `[propext]` and `shdP_slotKind` prints none".
8. "Remaining ... Only (1) ... (2) ... + `hhdrFit`/check-hook pins": add `hR`, `ioIn ioOut checkOpening`, `E0`, and say the hooks are universally quantified, not pinned (L5).
9. "Guarded build ... `ZK60Formal.lean` untouched": the file is not part of the root build; "built" is a single-file elaboration.

## What I did not check

- Rust fidelity of everything except the token and width layout order and the flip bit (F): the slot permutation, group, hidden and hd pairing; `aRows hRows aPath hPath maskPath preChecks` of `shdP_blkParams`; `ioIn ioOut` values; the counts record `RunK.kinds` against the real receipt.
- That the file's `shdP_w16Pub` embedding equals the tables of the real block (its fields are proved only against the Lean structure).
- Joint satisfiability of `O`, `hR` and the four stage premises (no instance exists; `hR` alone is satisfiable).
- The author's claim that `O.width/shapes/blocks/commit/policy/counts` are ready in `RunShapeShieldOpen` and `HonestRunCount` (outside the file), and the proposed `L68b` split.
- `ssh_outc_out_nil` and the other lane's output-endpoint argument for `XE`.
- Proof bodies line by line (the kernel checked them); an unfolding test of `shdP_Pk0` after its attribute; the olean-to-source tie of the imported modules.
- Regression suites; anything outside this file.

## Reproducibility

`results/zk60_claude_review_20261116/l68a_review/`: `gen_l68a.py` (declaration list, review copy, meta appendix), `l68a_elab.sh`, `RunShieldBlkInst_review_copy.lean`, `RunShieldBlkInst_decls.txt`, `blk_elab.out` (axioms, `#print`s), `parse_axioms.py`, `sigp_blkLu.txt`, `sigp_shieldLu.txt`, `sigp_shdP_hzk.txt`, `sigp_shdP_shieldRunAtD.txt`, `sigp_shdP_bitLay.txt`, `sigp_shdP_hbij.txt`, `sigp_shdP_hU.txt`, `sigp_shdP_clampPk_Pk0.txt`, `sigp_runK_ref_cap_110.txt`, `sigp_shield_run_exists.txt`, `sigdiff.py`, `sigdiff.out`, `reducibility.txt`, `get_entry.py`, `get_entry2.py`, `elab.guard.log`, `elab.guard.out`. The scripts are adapted from `l67_review/`; the originals are unchanged.
