# ZK60 Lean lane L55: the stages' readers off the code's header (`hW`), the verdict refusal, and the boundary openings' geometry (2026-11-10)

Lane L55 of D63 (Claude Opus 5.5), on its own worktree holding perf `2e5cde97` (lanes L49 and L52 merged). Lean 4.34.1,
Mathlib v4.34.1, no new dependency. Evidence: `results/zk60_lean_l55_20261110/`.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms at most `propext`, `Classical.choice`, `Quot.sound`),
**CHECKED** (a script or Lean checker run against the code, with its log and a negative control), **MEASURED**,
**ARGUED** (reading the code or the Lean, not a theorem), **ESTIMATE**, **LEFT** (not done).

**STATUS.** Deliverable 1 DONE, green, committed: `hW` PROVED at the code's header (`vd_hW`), with one finding on the way
(L55-1, High: the Lean verifier omits the code's refusal of a verdict above `1`; without it `hW` cannot be met, and
neither can `hdout`; repaired in Lean, no code change). Deliverable 4 DONE for deliverable 1: the top theorem restated
from L52's, generated, with `hW` gone (`vd_productionReadyL_epP_codeT`... see §2.2). Deliverable 2 PARTLY: both closing
geometries CHECKED against the code with a negative control (the boundaries and `B_out` are L48's block geometry `ogR13`
with `38` rows at R13 Shieldstral T128), and the verifiers' numbers at that geometry PROVED for the real `B_out` verifier
and for the code's boundary opening; the `RhOpW` instances themselves (`hopX1`) LEFT, with the route (§5.2). Deliverable 3
NOT started (§5.3).

## 1. In plain words, for Victor

**What was asked first.** The app's top theorem reads, off the proof's transcript, which verifier each of the two
stages used. For the input stage that is trivial (one verifier for every statement). For the output stage the verifier
depends on the PUBLIC verdict, so the reader must find the verdict in the transcript. The code's run header absorbs the
verdict as one byte, the seventh of its eight absorbs. This lane proved that the reader that takes that byte gets the
statement's verdict, on every accepted run, at the code's header.

**What I found on the way (finding L55-1).** In the Lean model the verdict is any whole number; in the code it is one
byte, and the code refuses any verdict other than `0` or `1` before it reads a single segment (twice: when it reads
`statement.json`, and when it builds the statement). The Lean model of the verifier had no such refusal. That matters:
a byte cannot tell `1` from `257`, so no reader of the transcript could meet the premise, and the output stage's
soundness premise (`hdout`, lane L53's) would also be false (a prover could claim the verdict `2` and pass the output
stage's arithmetic honestly). The repair needs no code change: the model's "statement check" of the first block now
carries the code's refusal (`vdChk`, with the code's message). On every statement the code can build it is the old
check, so the model accepts exactly what the code accepts.

**What else.** The closing openings of the blocks and of the output stage open the run's boundary commitments. I read
their geometry off the code and checked it with a checker and 25 single-change controls: at the app's profile each
boundary is `2^14` columns at rate `1/4`, `256` checks, `38` rows, the same code geometry as the blocks' own
commitments. I proved that the code's boundary verifier and the real output stage's `B_out` verifier have exactly the
numbers the top theorem's opening lemmas need. Tying each of those openings to the transcript (the remaining part of
`hopX1`) is the next lane's (§5.2).

## 2. What is proved

All in namespace `ZK60.ProtocolClassify` (the top theorem in `ZK60.ProtocolClassify.RunShapeP`; the geometry in
`ZK60.Exec.Link`). Every declaration on at most `propext`, `Classical.choice`, `Quot.sound` (§7).

### 2.1 Deliverable 1: `hW` (`RunVerdictW.lean`)

| Theorem or object | Meaning |
|---|---|
| `vdByte`, **`vdWout`**, **`vdWin`** | the readers: the verdict byte at header position `6` (exactly a one-byte absorb, else `0`) and `F` of it; the constant IN-C verifier |
| **`vdByte_eq`** | the byte is the verdict when the verdict is below `256` |
| **`vdChk`**, **`vdChk_eq`**, **`vdChk_le`** | the code's verdict refusal as block `k`'s statement check in front of the existing one; it IS the existing check on every verdict `0` or `1`; it passes only a verdict `≤ 1` (the premise `hchk`, met) |
| **`vd_check0_of_accept`** | an accepted run with a block passed block `0`'s statement check |
| **`vd_hdr_wrap`**, **`vd_outc_ne`** | without the refusal: the code's header is the same at verdicts `v` and `v + 256`, while stage OUT-C's verifiers there differ (finding L55-1) |
| **`vd_hW`** | THE TOP THEOREM'S `hW` IN ITS EXACT FORM, at the code's header (`hRn`), for `Win := vdWin Vi`, `Wout := vdWout F`, from `hinc` (IN-C's family constant), `houtc` (OUT-C's reads only the verdict), `hchk`, `0 < Lb` |

### 2.2 Deliverable 4 for deliverable 1: the top theorem restated (`RunVerdictTop.lean`, generated)

| Theorem | Meaning |
|---|---|
| **`vd_productionReadyL_epP_codeW`** | lane L52's `eb_productionReadyL_epP_codeT` (repair B, the column test built from part `0`'s opening; L50's alive discharges kept) with `Win := vdWin Vi`, `Wout := vdWout F` and `hW` PROVED (`vd_hW`); generated by `l55_mk_top.py` |

### 2.3 Deliverable 2 (part): the boundary openings' geometry (`RunCloseBGeo.lean`, `RunCloseBPcs.lean`)

| Theorem or object | Meaning |
|---|---|
| `cbBndRows`, **`cbBndRows_r13`** | a boundary's rows (`BoundarySpec::commitment_rows`: `t_pad·d_pad/2^log_n + 2·sites + 2`); `38` at R13 Shieldstral T128 |
| **`cb_bnd_geo`** | the boundary geometry at R13 Shieldstral T128 is L48's `ogR13` (`2^14` columns, `2^16` symbols, `256` queries, the largest radius `24448`, `64` index squeezes) and meets `OGeo.Ok` |
| **`rcPcsAt_bnd`**, `rcPcsAt_bnd_r13` | L29's `pcsAt` (the code's `pcs::verify_zk_tagged`) at `log_cols 14`, rate `1/4`, `256` meets `RkPcsAt ogR13` and `RkPcsR13` |
| **`rcOutcAt_pX_bnd`** | stage OUT-C's closing opening (`B_out`) at the real OUT-C contract `rcOutcAt` (`geo.bLogN = 14`, `blr = 2`, `bq = 256`) meets `RkPcsAt ogR13` |
| `cbBndOpen`, `cbBndPcs`, **`cbBndPcs_at`**, `cbBndPcs_r13`, `cbBndPcs_rows` | the code's boundary opening as the run's `bndOpen`, its `RtPcs` (each block's `pX` in `rcRunClassifyAt`), its numbers at `ogR13`, `38` rows at R13 |

### 2.4 The check against the code (`RunCloseBGeoCheck.lean`, executable, not imported)

See §7.

## 3. The numbers

| Figure | Value | Label |
|---|---|---|
| where the code's header absorbs the verdict | position `6` (the 7th of `8` absorbs), ONE byte | PROVED from the header (`ab_verdictAbs`); the header CHECKED by L51, re-run here (§7) |
| verdicts the code accepts | `0` and `1` only (classify_cli.rs:464, classify.rs:1018-1019) | ARGUED (source reading) |
| verdicts the Lean verifier accepted before `vdChk` | any `ℕ` | ARGUED (reading `classifyVerifyE`) |
| a boundary's geometry at R13 Shieldstral T128 | `log_n 14`, rate `1/4`, `256` checks and pads, `2^16` symbols: `ogR13` | CHECKED (§7) and PROVED equal to `ogR13` (`cb_bnd_geo`) |
| a boundary's rows at R13 Shieldstral T128 | `128·4096/2^14 + 2·2 + 2 = 38` (`32` data rows) | CHECKED (§7); PROVED (`cbBndRows_r13`) |
| `B_out` | the last boundary `B_L`, the same geometry | CHECKED (source: stage OUT-C is handed `prev`) |
| the top theorem's explicit binders | `127` (`vd_productionReadyL_epP_codeW`) against L52's `124`: gone `Win`, `Wout`, `hW`; new `Vi`, `F`, `hinc`, `houtc`, `hchk`, `hLb1` | CHECKED (the generator's binder parser) |
| R13 total | unchanged, `55,852,891` of `2^26 = 67,108,864` (no new event in this lane) | PROVED (L52's `eb_total`) |

## 4. The files

New, imported by the root (in this order): `RunVerdictW.lean`, `RunVerdictTop.lean` (generated by `l55_mk_top.py`),
`RunCloseBGeo.lean`, `RunCloseBPcs.lean`. Not imported: `RunCloseBGeoCheck.lean` (an executable checker). No existing
Lean file changed (the root's import lines apart); `Statements.lean` unchanged; no Rust.

## 5. What is left, premise by premise

### 5.1 The premises this lane introduced (of `vd_productionReadyL_epP_codeW`), and whether the real objects meet them

| Premise | What it says | Met by the real objects? |
|---|---|---|
| `Vi`, `F`, `hinc` | stage IN-C's verifier family is the constant `Vi` | YES: the real family is `fun _ => incVAt …` (L39's `rcIncAt`), `hinc` is `fun _ => rfl` |
| `houtc` | stage OUT-C's family reads only the verdict, `outc hd v = F v` | YES: the real family is `fun _ v => outcVAt … (rcVerdict O v) …` (L39's `rcOutcAt`), `houtc` is `fun _ _ => rfl` |
| `hchk` | block `0`'s statement check passes only a verdict `≤ 1` | YES with `check := vdChk check0` (`vdChk_le`, PROVED), which is the code's (`vdChk_eq` on every verdict the code admits; the code's refusals classify_cli.rs:464 and classify.rs:1018-1019) [ARGUED that the accepted inputs are the code's: the code refuses before any segment, the model at block `0`'s step]. NOT with a `check` that omits the refusal (finding L55-1) |
| `hLb1` | `0 < Lb` | YES: the app has `26` blocks |

### 5.2 Deliverable 2: `hopX1` (the closing openings of parts `1` on): what is done and what is LEFT

Done: the geometry (CHECKED), and the verifiers' numbers at it for the real objects (`rcOutcAt_pX_bnd` for `B_out`;
`cbBndPcs_at` for the code's `bndOpen`). LEFT: the `RhOpW` instances. The route, with what each step uses:

1. **The carry's content.** Part `i ≥ 1` opens the root and the claims the previous part handed on. L45's
   `rx_accept_two` gives the two consecutive steps on one carry; with `inSegExec_step_ok_iff` (IN-C hands on its
   pending claims and `B_in`'s root) and `d12a_blockSeg_step_ok_iff` (block `k` hands on `⟨acc.claims.out, B_{k+1}⟩`),
   the carry is `⟨(acc (i − 1)).claims.out, root (i − 1)⟩`, which is `rkPend (rxAcc …) i` read at the window (the
   previous part's reader, `rk_take_take_le`). `rk_blk_run`'s carry comes from `RtRun.accept_part` (its own
   existential): a version of it on `rx_accept_two`'s carry is needed (the transcript before part `i` from part
   `i − 1`'s contract `R.hσ` and `rt_segsOk` on the first `i` parts).
2. **The root's position**: the previous part's frame absorbs the 32-byte root alone at `off (i − 1) + 2` (`rtIncFrame`
   and the block frame both absorb `B` third; `absorbRoot` absorbs the root, then rows and `log_n` separately).
3. **The opening's numbers**: premises `pXk : ∀ k, RtPcs (bndOpen at k)` with `RkPcsR13` (met: `cbBndPcs`,
   `cbBndPcs_r13`), and for part `Lb + 1` `RkPcsAt ogR13 Oout.pX` (met at the real stage: `rcOutcAt_pX_bnd`).
4. **The extraction**: outside L45's `EvXR` (no new event): `rxRoots` lists every block's boundary root and IN-C's
   `B_in`, and `rxVx` checks every block's `in_open` and OUT-C's `B_out` columns (`rxOpenings`), at depth `16`.
5. **The kinds data**: `(base i).gX = rkAt ogR13 38 (off (i − 1) + 2)` and `(base i).nX` the previous part's `nOut` plus
   part `i`'s `nIn`, for `1 ≤ i ≤ Lb + 1` (a choice of `base`, like L52's `hgX0`, `hnX0`).

Then `rx_blk_opA`'s proof pattern (part `k + 1`, the opening after `H`: `u` extended by `A` and `H`'s steps) gives
`RhOpW` at block parts, and `rs_inc_opXG`'s at OUT-C.

### 5.3 Deliverable 3 (the input endpoint's extractor): NOT started

As L52 §5.3 items 1 to 3 left it: `ops`, `Xx`, `Ux` read from L52's tag-checked `ebOpenX`; its failure event bounded by
L16's `ExtBad` argument (`extract_of_opens`); `hread` by definition; `hE`, `mk`. If the new event REPLACES `ebEvIn`, the
R13 total stays `55,852,891`; if it is added with the same constant `2^16 + 2^18`, it becomes `56,180,571 ≤ 2^26`
(83.7 %) [ESTIMATE: the sum; the event's bound is the work].

### 5.4 Every premise of `vd_productionReadyL_epP_codeW` still left, by name

L52's list (§5.2 of L52's doc) without `Win`, `Wout`, `hW`, with `Vi`, `F`, `hinc`, `houtc`, `hchk`, `hLb1`:

Objects: `Rp`, `Lq`, `Lb`, `preA`, `preB`, `start`, `inc`, `incG`, `Pk`, `sgeom`, `check`, `paths`, `digest`, `bRows`,
`bLogN`, `bndCheck`, `bndOpen`, `outc`, `outcG`, `P`, `U`, `key`, `domain`, `Rn`, `D`, `site`, `kOf`, `δOf`, `E`, `O`,
`tag`, `cx0`, `pin`, `pout`, `Iin`, `Oout`, `bp`, `wXk`, `gXk`, `mXk`, `Vi`, `F`, `lscIn`, `lscOut`, `mIn`, `kIn`, `kOut`,
`base`, `eL`, `hw`, `Fsl`, `AlkL`, `TL`, `mlkL`, `mk`, `ops` (and the section's `Rr`, `dR`, `pos`, `place`, `msg`, `pad`,
`salt`, `path`, `tagc`).

Hypotheses: `h64`, `hr`, `hon`, `hbij`, `hs`, `hL`, `hL64`, `hv`, `hRn`, `hD`, `hU`, `hσ`, `hLb`, `hgeo`, `hIA`, `hIH`,
`hOA`, `hOH`, `hBA`, `hBH`, `htI`, `htO`, `htB`, `hfIA`, `hfIH`, `hfOA`, `hfOH`, `hfBA`, `hfBH`, `hfIM`, `hfOM`, `hfBM`,
`hinc`, `houtc`, `hchk`, `hLb1` (new, §5.1: met), `hlscIn`, `hlscOut`, `hmIn`, `hkIn`, `hkOut`, `hDe`, `hopX1` (§5.2),
`hgX0`, `hnX0`, `hXep`, `hfitX`, `hRr`, `hL81`, `hslB`, `hsl_blk`, `hsl_stg`, `hR0_blk`, `hR0_stg`, `hR1_blk`, `hR1_stg`,
`hH0_blk`, `hH0_stg`, `hH1_blk`, `hH1_stg`, `hLU_blk`, `hLU_stg` (L53, L54), `hdin`, `hdout` (L53; `hdout` needs `hchk`'s
refusal, finding L55-1), `hblk` (L54), `hE`, `hops`, `hcan`, `hread`, `hdzero` (§5.3; `hdzero` L53's lists), `hzk`.

## 6. Findings

**L55-1 (High; for the coordinator, lane L53 (`hdout`) and whoever instantiates the top theorem): the Lean run
verifier omits the code's refusal of a verdict other than `0` or `1`, and without it `hW` and `hdout` cannot be met.**
The code refuses a verdict above `1` twice before reading any segment: `found_statement` (classify_cli.rs:464,
"statement.json: verdict_bit is not 0 or 1") and `ClassifyRunStatement::new_chunk` (classify.rs:1018-1019, "classifier
run: the verdict is one bit"), the only constructor of the statement the verifier runs on (classify.rs:897, :902 of
classify_cli.rs). The Lean `classifyVerifyE` reads the verdict (a `ℕ`) only in the header (as `UInt8.ofNat v`) and in
stage OUT-C; `preA`, `preB` read only the header type. Consequences: (1) `hW` is unmeetable by any reader: the header is
the same at `v` and `v + 256` (`vd_hdr_wrap`, PROVED) while the OUT-C verifiers differ (`vd_outc_ne`, PROVED) [that both
can be accepted with the same transcript prefix: ARGUED]; (2) `hdout` is unmeetable: at `v = 2` the Lean OUT-C reads
`σ = −1` and the constant `2 + c`, so a prover whose margin is at most `c − 2` passes OUT-C's arithmetic honestly with
`δ = c − 2 − Δ`, no entrant is doomed, and `OutOkP` fails (`b ≤ 1`) [ARGUED]. The repair, Lean only, no code change:
the real `check` is `vdChk check0` (the refusal in front of block `0`'s statement check); `vdChk_eq` shows it is the old
check on every statement the code can build, so the model's accepted inputs are the code's [ARGUED]. Not a protocol
issue: the code refuses. This is the tenth premise found unmeetable as modelled; found and repaired in this lane.

**L55-2 (Low; for the coordinator): `hW`'s reader of the verdict needs the verdict below `256`, and the real header
absorbs ONE byte.** `vdByte` reads exactly a one-byte absorb at position `6`; the width is the code's
(`&[self.verdict]`, a `u8`), CHECKED by L51 on a real receipt (re-run here). With the refusal the verdict is `0` or `1`.

**L55-3 (Info; for the next lane on `hopX1`): the run's Merkle event already covers the closing openings of parts `1`
on.** `rxRoots` lists IN-C's `B_in` root and every block's boundary root; `rxOpenings` lists every block's `in_open` and
OUT-C's `B_out`. So `hopX1` needs no new extraction event and no change to the count.

**L55-4 (Info; for the coordinator): `rk_blk_run`'s carry is not tied to the previous part.** It comes from
`RtRun.accept_part`, an existential per part, so the closing opening's claims and root cannot be read from it (§5.2
item 1). A version on `rx_accept_two`'s carry is the first step of `hopX1`.

## 7. Checks

`results/zk60_lean_l55_20261110/check_l55.sh`, one guarded cpu job (`lean-l55-check`, need 24 GiB, cap 36 GiB,
`LEAN_NUM_THREADS=4`), on perf `2e5cde97` plus this lane. RESULTS TO BE FILLED.
