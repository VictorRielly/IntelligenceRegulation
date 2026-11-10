# ZK60 Lean lane L51: the run header as the code builds it, where it absorbs the input root, and the input endpoint's windows (2026-11-10)

Lane L51 of D63 (Claude Opus 5.5), on its own worktree holding perf `2f34ebe5` (lane L48 merged). Lean 4.34.1,
Mathlib v4.34.1, no new dependency. Evidence: `results/zk60_lean_l51_20261110/`.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms at most `propext`, `Classical.choice`, `Quot.sound`),
**CHECKED** (a script or Lean checker this lane ran against the code, with its log and a negative control),
**MEASURED**, **ARGUED** (reading the code, not a theorem), **ESTIMATE**, **LEFT** (not done).

**STATUS.** Deliverable 1 DONE, green and committed, with a High finding: L48's premise `hInAbs` cannot be met by the
code (finding L51-1), so the brief's "prove `hInAbs`" became "prove it false at the code's header, and give the two
repairs". Deliverable 2 PARTLY (`hwin` PROVED; the rest is blocked by L51-1 or LEFT, §5). Deliverable 3 NOT started.
Deliverable 4 DONE at the REPAIRED header (`ab_productionReadyL_epP_fix`: `hopX` at part `0` and `hwin` discharged);
at the code's header only `hwin` is discharged (`ep_hwin_top`), §5.3.

## 1. In plain words, for Victor

**The question.** The app's top theorem needs to know where the proof's transcript "absorbs" the root of your input's
commitment. Absorbing the root before any challenge is what pins the input: the challenges are computed after it, so
the prover cannot change the input once it sees them. Lane L48 left this as a premise, `hInAbs`: "the transcript
absorbs the 32-byte input root at some position".

**What the code does.** I read the run header in the code (`ClassifyRunStatement::transcript`) and checked it against a
real classifier receipt: the header is eight absorbs, and the input root is absorbed exactly once, inside the second
one, `expected-IO`, as the last 32 bytes of an 84-byte message (`"classify-expected/v1"`, the input commitment's
parameter digest, then the root). Nothing else in the transcript before the input's opening absorbs the root.

**What that means (finding L51-1, High).** The root IS bound before every challenge, so the protocol is fine. But the
Lean model's extraction reads a root only from an absorb of exactly 32 bytes. With the code as it is, `hInAbs` is false
where the root is absorbed (PROVED), at the header's other positions and at stage IN-C's root absorbs on the real
receipt (CHECKED), and I PROVED that the part of the top theorem that needed it (`hopX` at part `0`, the input commitment's
opening) can never be met through L48's route. This is the ninth premise found unmeetable at the real system. The same
reason blocks the input test's link `hBal` under the run's extraction event.

**Two repairs, your choice.**
- **A (code, one line):** absorb the input root on its own as well, right after `expected-IO`
  (`tr.absorb(b"input-root", &self.in_root);`). It changes every classifier receipt's binding (a protocol change, so a
  new profile version and a re-gate). With it, `hInAbs` is PROVED at position `2` and L48's `og_hopX0` applies with no
  premise left about the header (both PROVED here, at a Lean model of the repaired header).
- **B (Lean only, no code change):** teach the Lean extraction to read a root out of a longer message. I PROVED the core
  of it: the generalized extraction, that it is the old one at 32-byte messages, that it reads the log only through
  cuts (so L30's stability carries), its failure probability, and the extraction outside that failure. The top theorem
  must then be restated with one more extraction event, which costs `u126 q (2^16 + 2^18)`: the R13 total goes from
  55,525,211 to 55,852,891 units of the 67,108,864 the target allows (83.2 %) [ESTIMATE: the sum, not yet a restated
  theorem]. That restatement (a new opening kind for part `0`, its "alive" lemma, the kinds data, the count) is a lane.

**What else is done.** The header is now the code's in Lean (`clsHdrOps`, `clsStart`), with the two header premises of
L34's run schedule (`hstart`, `hhdr`) PROVED for it; a Lean checker rebuilds the header from a real receipt's words and,
hashing with BLAKE3 in Lean, lands on the code's own run binding. The input test's window premise `hwin` is PROVED on the
run's transcript. The app's top theorem is restated at the repaired header with `hopX` at part `0` and `hwin` gone
(`ab_productionReadyL_epP_fix`), so repair A's effect on the proof is not a promise but a theorem.

**What is not done.** The run-level doom covers `hdin`, `hdout` (deliverable 3) and the endpoint links `hBal`,
`hdzero`, `hops`, `hcan`, `mk`, `hE` (deliverable 2): §5 says exactly what each needs.

## 2. What is proved

All in namespace `ZK60.ProtocolClassify` (`RunAbsTop.lean` in `ZK60.ProtocolClassify.RunShapeP`). Every declaration on
at most `propext`, `Classical.choice`, `Quot.sound` (§7).

### 2.1 Deliverable 1: the code's header and where it absorbs the input root (`RunAbsHdr.lean`)

| Theorem or object | Meaning |
|---|---|
| `abLabShape` … `abLabChk`, `abExpTag`, `abLabInRoot` | the header's eight labels and `expected_bytes`' tag, as bytes (CHECKED: they are `ascii` of the source's strings) |
| `ClsHdrW`, **`abExpMsg`**, `abExpMsg_length` | the header's public words; `expected_bytes` = tag ‖ input spec digest ‖ input root, `84` bytes |
| **`clsHdrOps`**, `clsHdrOf`, **`clsStart`** | THE CODE'S RUN HEADER (`ClassifyRunStatement::transcript`): eight absorbs, the input root inside `expected-IO`, the verdict as one byte; `st.transcript()` (CHECKED on a real receipt, §7) |
| `clsHdrOps_length`, `clsHdrOps_sqN`, `clsHdrOps_fit` | `8` operations, no squeeze, each within `Lq` bytes when the words fit |
| **`ab_hstart`**, **`ab_hhdr`** | L34's run schedule's header premises (`rtRunClassify`, `rcRunClassifyAt`: `hstart`, `hhdr`) at the code's header |
| **`ab_tr_hdr`**, `ab_absAt_hdr`, `ab_off0` | on an accepted run the run's transcript is the header's trace then the parts'; header position `j` absorbs what header operation `j` absorbs; part `0` starts at `8` |
| `ab_verdictAbs` | position `6` absorbs the public verdict's byte (for L45-1's `hW` at OUT-C) |
| **`ab_inAbs`** | THE CORRECTED `hInAbs`: on an accepted run at the code's header, transcript position `1` absorbs `abExpMsg (in spec digest) s.inRoot` |
| `abExpMsg_ne`, **`ab_hInAbs_false`** | L48's `hInAbs` is FALSE at position `1` (an 84-byte message is no 32-byte root) |
| `ab_rootAt_none`, `ab_colX_of_none`, `ab_colX_none` | L22's run extraction `colX` reads no root there, and extracts nothing |
| **`ab_rhOpW_none`** | NO `RhOpW` (L43's acceptance facts of an opening) exists for an opening whose geometry reads its root where the transcript shows no 32-byte root (the verifier opens `Q > 0` columns, `RhOpW` asks each to be `colX`'s) |
| **`ab_hopX0_at1_empty`**, **`ab_hopX0_at1_empty'`** | L48's route to part `0`'s `hopX` is closed at the code's header: `og_hopX0`'s conclusion at `xPos = 1` is empty |
| `clsHdrOpsFix`, `clsHdrFixOf`, lengths | REPAIR A (not the code): the header with one more absorb, `input-root`, the 32-byte root, at position `2` |
| **`ab_inAbs_fix`**, `ab_off0_fix` | at the repaired header, L48's `hInAbs` holds at position `2`; part `0` starts at `9` |
| **`ab_hopX0_fix`** | `og_hopX0` with `hInAbs` discharged at the repaired header |

### 2.2 Repair B's core: a root read out of a longer message (`RunAbsX.lean`)

| Theorem or object | Meaning |
|---|---|
| `ab_cutAt_cons`, **`ab_cut_coarse`**, `ab_cut_coarse_eq` | the log cut at a message's first absorption fixes the cut at the first absorption of anything the message reads as |
| `absMOf`, **`colXM`** | the extraction at the root the header's message at position `i` reads as under a reader `rd` |
| **`colXM_digOf`** | at the 32-byte reader it IS L22's `colX` (a generalization) |
| **`colXM_cutEq`**, `colXM_cutReads` | it reads the prover's log only through the header's cuts, for every reader (L30's `CutReads`) |
| `abRdIn`, **`abRdIn_expMsg`**, `ab_rdIn_at1` | the input root's reader: `expected-IO`'s last 32 bytes after its tag; at the code's header it reads `s.inRoot` at position `1` |
| `EvXM`, **`extract_fail_xm`**, **`extract_fail_xm_u126`** | the extraction failure under a reader at the run's queries, bounded by L16's `extract_fail_run` (generic in the reader): `≤ u126 q (2^16 + 2^18)` |
| **`ab_xok_in`** | outside `EvXM`, every sampled column verifying against the root the header shows is `colXM`'s (`rx_xok` for `colXM`) |

### 2.3 Deliverable 2 (part): the input test's windows (`RunEndptWin.lean`)

| Theorem or object | Meaning |
|---|---|
| `epPreX`, `epPreBX`, their splits and lengths | a part's steps up to its closing opening's batching run (`oX`) and up to its `"pcs-prox"` (`oBX`) |
| **`ep_win_part`**, `ep_win_run` | on an accepted run, for EVERY part, the closing opening's two windows are at steps' ends of the run's wide parse, inside the transcript |
| `ep_hwin`, **`ep_hwin_top`** | the top theorem's `hwin` in its exact form (at its own acceptance), when the test's windows are part `0`'s `oX`, `oBX` |

### 2.4 Deliverable 4: the top theorem restated (`RunAbsTop.lean`, generated)

| Theorem | Meaning |
|---|---|
| **`ab_productionReadyL_epP_fix`** | `og_productionReadyL_epP_exec_blk` AT THE REPAIRED HEADER: `hopX` at part `0` PROVED (`ab_hopX0_fix`), `hwin` PROVED (`ep_hwin_top`); generated by `l51_mk_top.py` |

### 2.5 The checks against the code

| Object | Meaning |
|---|---|
| `src/lean_l51_export_tests.rs` (test only) | an honest classifier run accepted by the production verifier; the header rebuilt absorb by absorb from the statement's public words and ASSERTED equal to the production binding; the corpus `l51_corpus.txt` |
| `RunAbsCheck.lean` (executable, not imported) | the Lean header `clsHdrOps` from the corpus's words IS the code's list of absorbs and, under BLAKE3 in Lean, lands on the run binding; where the root is (and is not) absorbed; the source text (§7) |

## 3. The numbers

| Figure | Value | Label |
|---|---|---|
| the run header's operations | `8` absorbs, `0` squeezes (`run-shape`, `expected-IO`, `public-statement`, `parameters`, `calibration`, `schedule`, `classify-verdict`, `classify-chunk`) | PROVED (`clsHdrOps_length`, `clsHdrOps_sqN`); CHECKED (source text and receipt) |
| where the input root is absorbed | transcript position `1` (the header's second absorb), as bytes `52 … 83` of `expected-IO`'s `84` (`20` tag + `32` spec digest + `32` root) | PROVED (`ab_inAbs`, `abExpMsg_length`); CHECKED on the receipt |
| positions absorbing the 32-byte input root before the endpoint opening | none: not the header's eight, not stage IN-C's frame digest and `B_in`, `A`, `M`, `H` roots; the slots' and openings' absorbs carry field elements the prover computes, not a root | PROVED at position `1`; CHECKED on the receipt for the header and IN-C's digests and roots; ARGUED for the rest (the source) |
| part `0` starts at | transcript position `8` (repaired header: `9`) | PROVED (`ab_off0`, `ab_off0_fix`) |
| the header's words on the receipt (dev rung, `L = 1`, verdict 1) | `run-shape` 88 B, `expected-IO` 84 B, three 32-byte digests, `parameters` 1,909 B, verdict 1 B, chunk 56 B | MEASURED (corpus) |
| the header's fit | `64 + 88 + 1,909 + 56 + 84 = 2,201 ≤ 2^20` | MEASURED; the bound's form PROVED (`clsHdrOps_fit`) |
| repair B's extra extraction event | `≤ u126 q (2^16 + 2^18)` (`(q + 1)·327,680/2^126`) | PROVED (`extract_fail_xm_u126`) |
| R13 total with repair B | `55,525,211 + 327,680 = 55,852,891` units of `2^26 = 67,108,864` (83.2 %) | ESTIMATE (the sum; no restated theorem) |
| the export | an honest classifier run on the development rung, `3` segments; corpus `5,677` B, sha256 `0d485c51…dea35` | MEASURED |

## 4. The files

New (this lane's prefixes), imported by the root: `RunAbsHdr.lean`, `RunAbsX.lean`, `RunEndptWin.lean`,
`RunAbsTop.lean` (generated by `results/zk60_lean_l51_20261110/l51_mk_top.py`). Not imported: `RunAbsCheck.lean` (an
executable checker). Test-only Rust: `ops/zkp-mvp/gpu-metal/hashline/src/lean_l51_export_tests.rs`, declared by one
`#[cfg(test)]` line (and its comment) at the end of the test-only `token_io/classify_capture_tests.rs`, as lanes L18
and L29 did. No existing Lean file changed (the root's import lines apart); `Statements.lean` unchanged; no production
Rust changed.

## 5. What is left, premise by premise

### 5.1 The premises this lane worked on (of `og_productionReadyL_epP_exec_blk`, and L48's `og_hopX0`)

| Premise | Status after this lane | Met by the real objects? |
|---|---|---|
| `og_hopX0`'s `hInAbs` | REFUTED at the code's header (`ab_hInAbs_false`); PROVED at the repaired header (`ab_inAbs_fix`) | NO today (finding L51-1); YES with repair A |
| `hopX`, part `0` (the input endpoint's closing opening) | through L48's route: CLOSED at the code's header (`ab_hopX0_at1_empty'`); PROVED at the repaired header (`ab_hopX0_fix`, in `ab_productionReadyL_epP_fix`) | NO today by L48's route [PROVED at position `1`; at the other positions CHECKED on the receipt for the header and IN-C's digests and roots, ARGUED for the field-element absorbs]; YES with repair A; with repair B the opening kind must read `colXM` (§5.2) |
| `hopX`, parts `1` on | L50's | — |
| the run schedule's header (`rcRunClassifyAt`'s `hdr`, `hstart`, `hhdr`; the top theorem's `start`, `Rn`) | PROVED for the code's header (`ab_hstart`, `ab_hhdr` with `hdr := clsHdrOf hw`, `start := clsStart …`, `hdrLen = 8`, `hdrSq = 0`) | YES: CHECKED (§7: the Lean header replays to the production binding); the words' fit (`64 + 88 + 1,909 + 56 + 84 ≤ Lq`) MEASURED on the receipt |
| `hwin` | PROVED (`ep_hwin_top`), given the test's windows are part `0`'s closing opening's (`hTwA`, `hTwB`) | YES once `T` is built from part `0`'s opening (its windows are those by construction) |
| `T`, `hTenc`, `hTe`, `hTQ`, `hβLR`, `hβJ`, `hw0`, `hF`, `hTaA`, `hTaB` | LEFT: `T` is still a parameter | the code facts exist (L48: `ep_open_code_factsU`, `XTest.εA_ep`, `XTest.εB_ep`); building `T` from part `0`'s opening (its `chalLR`, `chalJ` as L43's `lrCode`, `idxCode` at `ogEp`) is L46 §5 item 5's identification |
| `Ux`, `Xx`, `hUc`, `hXc`, `hread` | LEFT; decided by the repair: at the code's header the readers can cut at position `1` (`cutReads_of_cut`, and `colXM_cutReads` for the matrix), at the repaired header at position `2` | the cut-reading is met either way [PROVED pieces]; `hread` holds by construction when `ops` cuts at the same place [ARGUED] |
| `hBal` | BLOCKED by L51-1: its route (`xB_subSt_of_opB`) needs part `0`'s `opB` alive (`hopX` at part `0`) and every sampled column in `Xx` outside the extraction event, and the run's event `EvXR` cuts at the exact 32-byte root | NO today; with repair A from `ab_hopX0_fix` and `¬ EvXR`; with repair B from `EvXM` (`ab_xok_in`) |
| `ops`, `hops`, `hcan`, `mk`, `hE` | LEFT | needs an extraction that returns salt and path (L30-5) and `epTokenCommit`'s `SaltMk` |
| `hdzero` | LEFT | stage IN-C's `SIC_IO` zero-check as a part-`0` squeeze run (L46 §5 item 4) |
| `hdin`, `hdout` | NOT STARTED (deliverable 3) | §5.4 |

### 5.2 Repair B, what remains after `RunAbsX.lean`

1. An opening of the run whose extracted matrix is `colXM abRdIn` at position `1` (L43's `rkOpen` reads `colX`), its
   cut-reading (`colXM_cutReads`, done) and `RtOpen.Valid`.
2. `rh_opB_alive` for it (L43's proof with `UxW` replaced; `pcs_subSt_of_acc` is generic in the matrix reader), and an
   `RhOpW` whose `hcolX` speaks of `colXM` (from `ab_xok_in`).
3. `rkData` with part `0`'s closing opening of that kind, and the kinds' lemmas that read `rkData` (`rkData_valid`,
   `rkData_opX_cl`).
4. The top theorem with the extraction event `EvXR ∨ EvXM abRdIn …` (roots `[s.inRoot]`) and `u126 q (2^16 + 2^18)`
   more in the count: R13 total `55,525,211 + 327,680 = 55,852,891 ≤ 67,108,864` [ESTIMATE: the sum; the bound itself
   PROVED, `extract_fail_xm_u126`].

### 5.3 Why the restated theorem is at the repaired header

At the code's header the only premise of the top theorem this lane discharges is `hwin`; `hopX` at part `0` and `hBal`
cannot be met (L51-1). `ab_productionReadyL_epP_fix` shows what repair A buys: `hopX` at part `0` and `hwin` gone, at
the cost of the premises `hw`, `hRn` (the header), `hgX0`, `hnX0` (part `0`'s closing geometry: the choice of `base 0`),
`hXep` (PROVED for the real stage contract by L48's `rcIncAt_pX_ep`), `hfitX` (`8 · 6 ≤ Lq`: the endpoint commitment has
`6` rows [CHECKED by L48]), `hTwA`, `hTwB` (the test's windows). Every other premise is the original's.

Premises of `ab_productionReadyL_epP_fix` left, by name (all as in L48 §5 and L46 §4, unless said): `hσ`, `Iin`,
`Oout`, `bp`, `hgeo`, `wXk`, `gXk`, `mXk`, `cx0`, `pin`, `pout`, `base`, `eL`, `hDe`, `hD`, `hU`, `O`, `hzk`, `hlsc*`,
`hmIn`, `hk*`, `ht*`, `hf*`, `hLb`, `hIA`, `hIH`, `hOA`, `hOH`, `hBA`, `hBH`, `hW`, `hopX1` (parts `1` on), `hal_slots`,
`hal_R0`, `hal_R1`, `hal_H0`, `hal_H1`, `hal_LU`, `hdin`, `hblk`, `hdout`, `mk`, `ops`, `hE`, `hops`, `hcan`, `T`,
`hTenc`, `hTaA`, `hTaB`, `Ux`, `Xx`, `hUc`, `hXc`, `pr`, `hp1`, `hp2`, `hF`, `hw0`, `hβLR`, `hTe`, `hTQ`, `hβJ`,
`hread`, `hBal`, `hdzero`, and this lane's `hw`, `hRn`, `hgX0`, `hnX0`, `hXep`, `hfitX`, `hTwA`, `hTwB`.

### 5.4 Deliverable 3 (`hdin`, `hdout`): not started, and what it needs

`hdin` asks: if stage IN-C's conclusion `InOkP` fails on the run extractor's data, some kind of `rtKo` has a doomed
entrant in some part. The kinds' lists at part `0` are `base 0`'s (`sls`, `r0` … `lu`), a free choice of the top
theorem. The route (L46 §5 item 3): IN-C's four slots and its `SIC_IO` zero-check as the slot kind's and a define kind's
entries at part `0` (`SlotX`, `SqX` built from `stSlotsLoop`, L43-6), whose start claims are L12's `inc_stage_sound`
premises on L29's `incSlots_model`; a failing `InOkP` then gives a false start claim, and `rd_some_sq` / the slot kind's
entry gives the doom. The same for OUT-C with L15's `outc_stage_sound`. Neither the stages' `SlotX` / `SqX` nor their
start claims exist in Lean yet; that is the work.

## 6. Findings

**L51-1 (High; for Victor and the coordinator): L48's `hInAbs` cannot be met by the code, so neither can `hopX` at
part `0` by L48's route, nor `hBal`.** The code's run header absorbs the input root only inside `expected-IO`
(`"classify-expected/v1" ‖ in_spec.digest() ‖ in_root`, 84 bytes, classify.rs:1147-1153, 1283), and nothing before the
endpoint opening absorbs it alone (stage IN-C hands it to the opening's verifier, which absorbs no root; the other
32-byte absorbs are other commitments' roots and digests, CHECKED on the receipt, and field elements). The Lean run
extraction (`colX`, L22) and the run's extraction failure (`EvXR`, L27) both read a root only from an absorb of exactly
its 32 bytes. PROVED: `hInAbs` is false where the root is absorbed (`ab_hInAbs_false`), and no `RhOpW` exists for an
opening reading its root there (`ab_rhOpW_none`, `ab_hopX0_at1_empty'`). CHECKED on a real receipt: no header position and none of
stage IN-C's digest and root absorbs is the 32-byte root. The protocol itself is sound on this point [ARGUED]: the root is bound
before every challenge, inside `expected-IO`. The gap is the model's. This is the ninth premise found unmeetable at the
real system (after L45-2). Two repairs (§1): A, one absorb in the code (`tr.absorb(b"input-root", &self.in_root);`
after classify.rs:1283; a protocol change: every classifier receipt's binding moves, so a new profile version, goldens
and a privacy re-gate; the Lean side is ready, `ab_inAbs_fix`, `ab_hopX0_fix`, `ab_productionReadyL_epP_fix`); B, no
code change, a Lean restatement with one more extraction event (§5.2; core PROVED in `RunAbsX.lean`). Recommendation:
A is a smaller proof change and keeps one extraction event; B keeps today's bytes. Victor's choice; nothing is switched.

**L51-2 (Medium; for the coordinator and L46's successor): the input endpoint appears twice in the top theorem, and
both copies hinge on L51-1.** Part `0`'s closing opening in `rkData` (`hopX` at `0`) and the column test `T`
(`Ux`, `Xx`, `hread`, `hBal`) are the same opening read twice, at two types (L46 §5 item 5). Both read the input root
from the transcript; under repair A both cut at position `2`, under repair B both read with `abRdIn` at position `1`.
Whichever repair is chosen, the next lane should build `T` from part `0`'s opening so that `hBal` follows from
`hopX` at part `0` through L30's `xB_subSt_of_opB`.

**L51-3 (Low; for the coordinator): the header was free in every run theorem.** `RtRun.hdr` and the top theorem's
`start` were parameters (finding L45-1 for the verdict). `clsHdrOps` / `clsStart` now model the code's header, CHECKED;
`ab_hstart`, `ab_hhdr` discharge `rcRunClassifyAt`'s header premises with it. The top theorem itself still takes `start`
and `Rn` as parameters; instantiating them is the combiner's (`start := clsStart domain key hw`,
`Rn := rcRunClassifyAt … (clsHdrOf hw) 8 0 (ab_hstart …) (ab_hhdr …) …`). The verdict byte (`classify-verdict`) is
absorbed at position `6`, which is what L45-1's `hW` for OUT-C needs read back (L50's).

**L51-4 (Info): the receipt is the development rung's.** As for L48-6: the corpus is a classifier run at the rung
`private-classify-run-rung-tc-t32-public-row-dev/2`. The header's STRUCTURE is the same for every classifier profile
(`transcript()` has exactly these eight absorbs, CHECKED in the source; no branch on the profile, ARGUED); only the
words differ. The R13 T128 profile's header
words are not measured.

**L51-5 (Info; Lean method): `if_pos` / `if_neg` are deprecated in this toolchain** (warnings break the check):
`ite_eq_left` / `ite_eq_right` take their place.

## 7. Checks

`results/zk60_lean_l51_20261110/check_l51.sh`, one guarded cpu job (`lean-l51-check`, need 24 GiB, cap 36 GiB,
`LEAN_NUM_THREADS=4`), on perf `2f34ebe5` plus this lane: the run of record exit 0, 175 s, peak 3.70 GiB (the guard's
record). All figures MEASURED; logs in the evidence directory
(`check_run.log`, `full.log`, `axioms_flat.log`, `nameclash.log`, `abscheck.log`, `negative.log`, the regression logs).
The modules were built first in guarded iterations (`iter1` … `iter3`, logs kept). Two earlier runs of the check are
kept (`check_run1.log`, `negative_run1.log`, `negative_run2.log`): the first audited 67 of 68 lines (a docstring line
beginning with the word `theorem` was read as a declaration; reworded) and both had negative case 18 pass when it must
fail (the mutation hit the prover's `st.transcript()` call, not the verifier's; retargeted).

| Check | Result |
|---|---|
| each L51 module built alone (four) | 4 of 4 green, 0 warnings |
| full `lake build` | green, 3,745 jobs, 0 warnings, 0 errors, no `sorry` |
| axiom audit (`gen_axioms.py`) of every declaration of the four files | 67 of 67 (44 theorems, 22 definitions, 1 structure): 30 on `propext`, `Classical.choice`, `Quot.sound`; 5 on `propext`, `Quot.sound`; 7 on `propext`; 25 on none; `sorryAx` 0, `ofReduceBool` 0, other axioms 0 |
| source scan for the forbidden words (the four files, the checker, the Rust export) | none |
| root imports | the four modules imported (the checker not); no import line removed |
| existing files changed | none under `formal/` but the root's imports; `Statements.lean` unchanged; under `ops/` only the new test-only export and its declaration line (and comment) in the test-only `classify_capture_tests.rs` |
| name clashes (`l51_nameclash.py`, prefixes `RunEndpt`, `RunDoomIO`, `RunAbs`; 41 worktrees, 4,655 other Lean files) | 0 |
| `RunAbsTop.lean` against `l51_mk_top.py`'s output | identical |
| the Rust export (`exp_export.sh`, guarded) | green: the honest run accepted by the production verifier, the rebuilt header asserted equal to the production binding and counter and key, a one-byte root change asserted to move it; 168 s; census tests `s25_tests` 20/20, `hash_domain` 15/15 |
| agreement with the code (`RunAbsCheck.lean` on the export and the production sources) | 29 checks, 0 failed (below) |
| its controls (`l51_negative.py`) | 20 cases: the unchanged copy passes; 13 corpus changes and 6 source changes, each refused |
| regressions | L6Check 1,206, L5Check 5,553, L11Check 404, fixture L1 101,956 checks; 0 failed in each |

The agreement check:

| Kind | What | Result |
|---|---|---|
| CORPUS | the export is L51's; eight header absorbs; the Fiat-Shamir key | 3 of 3 |
| LABELS | the Lean labels are the source strings' bytes and the corpus's, in order | 3 of 3 |
| MODEL | `clsHdrOps` of the statement's words, input root and verdict IS the corpus's eight (label, data); `expected-IO` is `abExpMsg` (84 B); word sizes; the fit bound | 4 of 4 |
| REPLAY | under BLAKE3 in Lean, `Tr.newKeyed` of the profile is the code's fresh state, and the Lean header (and `clsStart`) lands on the run binding with no squeeze | 3 of 3 |
| POS | position `1` absorbs `abExpMsg`; no header position absorbs the 32-byte root; `rootAt 1 = none`; position `6` the verdict byte; stage IN-C's 32-byte absorbs before the endpoint opening are not the root | 5 of 5 |
| FIX | the repaired header absorbs the root at `2` and is another binding | 2 of 2 |
| SOURCE | `transcript()`'s eight absorbs, in order, nothing else, on the profile's tagged transcript; `expected_bytes`' three parts; `verify_classify_run_with` starts on `st.transcript()` and hands `st.in_root()` to IN-C; IN-C's `verify` uses `ep_root` only as a parameter, the commitment and a test-only hook, and absorbs no root | 9 of 9 |
| total | | **29 checks, 0 failed** |
