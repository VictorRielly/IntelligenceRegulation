# Research handoff: what the verifier's seven weight folds spend on pad, and what a live-only fold would save (2026-11-27, claude tick 73, queue item 115)

From Claude, the background researcher. Triage material, not a work order.

**Scope.** Code reading and arithmetic only (no web). No build, no prover or verifier run, no Git. Written: this file,
`20261127-claude-tick73-weight-fold-pad.py` (standard library, reads no file) and its output `...weight-fold-pad.out.txt`,
a STATE.md entry, the queue update and the coordination pointer. Clock reading at writing: 2026-11-27T19:51Z.

Labels: **COUNTED** (file:line), **MEASURED** (record cited), **DERIVED** (arithmetic in the script), **ASSUMED**.
Code cited is the tree that runs, `ops/zkp-mvp/gpu-metal/hashline/src/private_block/` and `.../zkp-core/src/mle.rs`.
The measurement is `results/zk60_verify_1t_installed_20261127/README.md` (one thread, the app's pinned binary
`zk60_classify.a30a31`, one retained receipt of `W16R2_SHIELD_T128_H24`, one run; **real trained weights on this export,
not the diagonal test weights of the 275.5 ms record**).

## 0. Headline

- All seven folds run the same verifier path and visit **243,269,632 padded entries a block at both profiles** (same
  `d_pad` 4,096 and `f_pad` 16,384), but the pad differs: **126,877,696 entries (52.2%) at the installed profile**
  (`d` = 3,072 pads to 4,096; `f` = 9,216 to 16,384), **25,165,824 (10.3%) at 8B** (only `f` = 14,336 to 16,384)
  [COUNTED shape, DERIVED].
- Every pad entry is **proved zero at construction** (`weights_vanish_off_support`, `private_block.rs:510`, called for all
  seven matrices at `:635-638, :776-778`), so a fold over live entries only returns the same Fp2 vector.
- Priced at ASSUMED zero-entry rates (anchored below), the live-only fold saves **33 to 67 ms a block at the installed
  profile, mid 50 ms**: 24 to 48% of the 139.5 ms, **10 to 20% of the 338.9 ms block proof check**, 4.5 to 9% of the 740.0 ms
  table; hard ceiling 72.8 ms (a pad entry cannot cost more than the average entry). At 8B: 6.5 to 13 ms a block. No receipt
  byte moves; no committed word moves; no effect on proved tokens a second (checking happens after the clock).

## 1. Which fold function each slot calls on the verifier side [COUNTED]

The slot definitions are shared by prover and verifier (`argument.rs:3218-3259` rows, `:3367-3400` columns); the stack of
both profiles is `LowH24` (`shape.rs:301-302`), not Legacy, so each calls `fold_checked` (`accuracy_fold.rs:1137`), and
the verifier has `prove_side = false` (`argument.rs:4110-4111`), which returns at once into `fold_with_mode(..., fast =
false)` (`accuracy_fold.rs:1149-1150`, `:1043-1085`). That does: shape checks; `has_i8_min` (a parallel `contains(&i8::MIN)`
over the **whole padded matrix**, `:45-48`); the weighted vector `eq * coefficient`; then `mle.rs` `fold_rows_i8` (`:157`) or
`fold_cols_i8` (`:182`). (The prover's NEON form, `fold_rows_fast`, is not on this path.)

| slot | matrix | function | padded shape | live at installed | live at 8B |
|---|---|---|---|---|---|
| 5 | Wq | `fold_rows_i8` | 4096 x 4096 | 4096 x 3072 | all live |
| 6, 7 | Wk, Wv | `fold_rows_i8` | 1024 x 4096 | 1024 x 3072 | all live |
| 10 | Wo | `fold_rows_i8` | 4096 x 4096 | 3072 x 4096 | all live |
| 11, 12 | Wg, Wu | `fold_cols_i8` | 4096 x 16384 | 3072 x 9216 | 4096 x 14336 |
| 13 | Wd | `fold_cols_i8` | 16384 x 4096 | 9216 x 3072 | 14336 x 4096 |

Pad entries per slot (script): 4.19 M (Wq, Wo), 1.05 M (Wk, Wv), 38.80 M (each of Wg, Wu, Wd) at the installed profile, so
**the three feed-forward matrices hold 92% of the pad**; at 8B 8.39 M each on those three only. The pad is contiguous:
the last 1,024 of 4,096 bytes of each Wq/Wk/Wv row, whole trailing rows of Wo (1,024), Wg/Wu (1,024 rows plus 7,168 of
16,384 bytes of each live row) and Wd (7,168 rows plus 1,024 of 4,096 bytes of each live row).

## 2. Is the deferred integer fold on the verifier's path?

**Yes, by default.** `fold_rows_i8` takes `fold_rows_deferred` when `deferred_rows()` (`mle.rs:160, 229-232`) and
`fold_cols_i8` takes `fold_cols_deferred` when `deferred_cols()` (`:185, 284-287`); both default on (env `HL_FSP_ROW_FOLD` /
`HL_FSP_COL_FOLD` = 0 switches off); I found neither set in `apps/`, `docs/` or `PROGRESS_UPERF3.md`. The loops are
**zero-skip**: a zero value costs a load, a widen and a compare, with no multiply (`:268-273`, `:311-315`), and a zero
**weight** does not skip a row in the deferred rows form (no `is_zero` test there). **Not verified:** that the pinned
binary `a30a31` carries both changes (M8 is 2026-11-01, A26 2026-11-07 touched `mle.rs`; I take the A30/A31 label to be
later, by the task numbering, not by hash).

## 3. Price of a fold over the live region only

Model: a block's fold cost = pad entries x z + live entries x l, with z the cost of a pad entry (loop visit of a zero byte
plus its share of the `has_i8_min` pass) and the measured average over **all** padded entries 0.573 ns
(139.5 ms / 243,269,632 [MEASURED / given]). The 139.5 ms is the whole rows of slots 5 to 7 and 10 to 13; the other
work in those rows (eight small eq tables, coefficient vectors, end-point evaluation of 4,096 to 16,384 entries, round
checks) is of the order of the 1.6 ms the seven other slots cost together, so I treat the 139.5 ms as the folds.

- LOOP: 0.22 to 0.40 ns a zero entry. Anchor [MEASURED, with a limit]: tick 68 reports 0.224 ns an entry for the three
  feed-forward folds on diagonal weights (A14/A18, prover side, nearly all entries zero); whether that profile ran the
  scalar loop or the NEON form was not rechecked, so 0.22 is a floor for the scalar loop, not a measurement of it.
- SCAN: 0.04 to 0.125 ns a byte (8 to 25 GB/s, tick 68's assumed band) for `has_i8_min`; I did not measure it.
- Saving = pad x (LOOP + SCAN): **33.0 / 49.8 / 66.6 ms a block** (low / mid / high), x 26 blocks = 0.86 / 1.29 / 1.73 s
  of a one-thread standalone check (a 73.8 s process whose 60.6 s are three export passes; item 116).
- Consistency: at these z the implied live-entry cost is 0.92 / 0.77 / 0.63 ns, above z in every case, as two i128
  multiply-adds per nonzero entry should be. A hard ceiling is z = 0.573: 72.8 ms.
- Pad bytes are also read by the construction check (`private_block.rs:522-530` reads exactly the off-support entries) so
  a pad entry is touched three times a block on the verifier (statement check, min-scan, fold loop); this lever removes
  two of them. The min-scan removal needs the construction check to have run in the same process on the same bytes
  (I take it that it does, since the block's public data is built through `new_shaped`; the call chain from the verifier's
  load to `ctx.public` was not traced).

## 4. What such a change touches

- **Receipt bytes: none.** The output is the same Fp2 vector given zero pad. **Verifier's own computation:** `fold_with_mode`
  (or a new `fold_*_live`) on the `prove_side = false` branch only. **Lean:** the folds are modelled as hypotheses on
  their value, not as loops: `PubR.wq ... wd` (`formal/ZK60Formal/BlockR13HostBase.lean:659-700`, cited to
  `fold_rows_i8` in its comment) and `W16Pub` ("the padded entries zero", `LayoutW16.lean:224-225`). A value-preserving loop
  change leaves both unchanged; what it needs is the equality with the full fold, which holds by the pad-zero check, itself
  a Rust refusal (the Lean line says the pad is zero; I did not trace which Lean statement discharges it from the Rust check).
- **Risk, Wq:** the head axis pads as interleaved slots per key-value group (`Axis::Q`, `private_block.rs:459-461`), not as
  a suffix. At both profiles `h_pad = q_heads = 32`, so Wq has no head pad here, but a general live-only loop must use the
  support predicate, not truncate. Restrict a first version to the suffix axes (D and F).
- The min-scan is a property of the weights, not of the challenge; a resident checker could keep its result (tick 68's
  check-once lever, not repeated here).

## 5. Falsifiable test (not scheduled; needs the owner's or coordinator's go)

T-F1, no protocol change, one thread, no prover: in a test binary call the verifier's `fold_with_mode` and a live-only
variant on the seven matrices of the installed verifier export with one fixed eq vector. **Pass:** the seven output
vectors are bytewise equal and the median-of-7 sum of the seven folds is lower by 33 to 73 ms (at least 25% of 139.5).
**Fail:** equality breaks (a pad entry non-zero: refuse), or the saving is under 15 ms (then z is under 0.12 ns and the
fold is already compare-bound, drop the lever). It also separates LOOP from SCAN if the min-scan is timed alone.

## 6. Honest effect

Committed words per request: 0. Proved tokens a second: 0 (verification is after the clock). Standalone check: at most
0.9 to 1.7 s of a 73.8 s one-thread run at this profile. Resident checker (four threads, export kept): scale by the
pool; not measured. It is a small, safe verifier item; it does not touch the speed goal.

## 7. Not verified

The scalar-versus-NEON path of the 0.224 ns anchor; the scan rate; the share of zero weights among live entries (they cost
z, not l, and would raise the saving slightly); that the 139.5 ms contains nothing but the folds (inferred from the
1.6 ms of the other slots); a Lean statement that discharges the pad-zero equality; whether the pinned binary has both
deferred folds. The 8B figure uses the installed profile's rates, not an 8B measurement.

## Coordinator's check (2026-11-27)

By Claude (co-coordinator). Own cross-check: `20261127-claude-tick73-weight-fold-pad-crosscheck.py`, output `-crosscheck.out.txt` (74 checks, none failed; run with `python3 -I` and, as its one argument, the path of a copy of the pinned checker binary). The researcher's script was re-run with the heavy lock free and prints its saved output.

**Confirmed, line by line.** The shapes, taken from the source and not typed (`shape.rs:705, 710`; the two W16R2 profiles take them through `:301-302, 699`): both profiles fold 243,269,632 padded entries a block; the pad is 126,877,696 entries (52.2%) at the installed profile and 25,165,824 (10.3%) at 8B; the three feed-forward matrices hold 91.7% of the installed profile's pad (the handoff rounds to 92%). At 32 heads over 8 key-value heads every head slot is a true head, so Wq and Wo have no head pad (`shape.rs:2301, 2328`, `private_block.rs:486`). The checker's path: the slot lines (`argument.rs:3231-3234, 3249, 3375-3377, 3390`), the side flag (`:4110`), the base fold for every caller that is not the prover (`accuracy_fold.rs:1149-1150`), the scan for the one refused value over the whole padded matrix (`:47, 1073`), and the two integer loops, on unless a switch is set to 0, which skip a zero value and never test a zero weight (`mle.rs:160, 185, 231, 286, 270, 313`). The pad is tested zero entry by entry for all seven matrices (`private_block.rs:510, 635-638, 776-778`), reading the off-support entries only (`:522-528`). Lean states each fold by its value (`BlockR13HostBase.lean:664-702`, fields `wq` to `wd`) and the pad as zero (`LayoutW16.lean:225`).

**Settled: the pinned binary has both integer folds.** The handoff left this open. A byte-identical copy of the binary the app pins (its SHA-256 is the one `apps/proven-media/deploy.json` holds) contains the names `HL_FSP_ROW_FOLD` and `HL_FSP_COL_FOLD` once each, so both switches, and the loops they select, are compiled in. No file under `apps/` names either (105 files read), and the one-thread run of this morning set neither.

**Added: the per-matrix rows of that run [MEASURED, one run, one thread, real weights].** The handoff used their sum. Median over the 26 tables, in ms a block: Wq 12.89, Wk 3.46, Wv 3.34, Wo 12.64 (row form, 25.0% pad; 0.771 ns a padded entry over the four); Wg 35.41, Wu 35.94, Wd 36.26 (column form, 57.8% pad; 0.535 ns a padded entry over the three). The three feed-forward folds are 107.6 ms of the 139.9 ms the seven medians sum to (77%).

**Those rows do not test the estimate.** The matrices with more pad cost less a padded entry, which is the direction a cheap pad entry would give. But the two groups also differ in loop form, and the run has no control that separates the two. There are two equations and three unknowns. If a live entry costs the same in both loop forms, a pad entry costs 0.23 ns (29 ms a block, just under the handoff's low figure); if a live entry of the column form is 0.3 ns cheaper, 0.52 ns (66 ms). Nothing in the run excludes values outside that either. What the rows do give is a slightly lower ceiling: taken matrix by matrix, 70.3 ms a block (the handoff's pooled ceiling is 72.8).

**The anchor is not a floor.** Section 3 calls the 0.22 ns "a floor for the scalar loop". Its source (tick 68, line 129) is 45 ms of sampled pool CPU a block in a prover-side profile with six forks, which that text itself calls an indication, since sampled pool time can include waiting. On the prover side `fold_checked` can also take other loops than the checker's (`accuracy_fold.rs:1152-1155`); which one that profile sampled was not read. So the figure bounds the checker's loop from neither side. The band of 33 to 67 ms a block is ASSUMED at both ends.

**Not traced, as the handoff says.** The pad test runs in the two constructors and in `check_for_shape` (`private_block.rs:602, 661, 759, 797`), and `check_for_shape` is called at 53 lines of the prover source; which of them the installed checker passes through was not traced. So "a pad entry is touched three times a block" is not established. A fold over the live entries only gives the same vector because that test has run on the same bytes; it has to stay behind it.

**What it means, and the order.** Checker only: no receipt byte, no committed word, nothing on proved tokens a second. At the assumed rates it is 10 to 20% of the 338.9 ms a block's proof check takes, and 0.9 to 1.7 s of the 73.8 s one-thread standalone check (1.2 to 2.3%). The next queue item (116: the three passes over the model export, 60.6 s of those 73.8 s) is the larger one for that check. **T-F1 is not scheduled.** It needs new test code, and a rule pushed before any timing; it stays the only way named here to learn what a pad entry costs.
