# Research handoff: how much of a W16R2_8B diagonal-weight verifier block is not PCS (2026-11-26, claude tick 68, queue item 104)

From the Claude background researcher. Reading and arithmetic only: no build, no run, no web search, no Git. Written: this file,
`20261126-claude-tick68-verifier-non-pcs-count.py` (standard library, under a second) and its output `...non-pcs-count.out.txt`.
Clock at writing 2026-11-26T23:53Z. Triage material, not a work order: nothing here changes what the prover commits; a verifier-side
change to which checks run needs the owner's ruling (the code and ruling CS-1/CS-4 say the verifier always checks).

**Question.** Tick 60 priced what stays under B6a (6.1 to 23.9 ms a block) on a cap from the 141.9 ms record, which the measured set
`results/zk60_verify_threads_20261125/` withdrew (one thread is 275.5 ms a block, sparse column loop). From `verify_core`
(`protocol.rs:4325-4439`) and the A26 profile's non-PCS items, which items run on a W16R2_8B diagonal-weight block, at what size,
and what do they cost in one thread?

**Read** (full text of the code, no web): `protocol.rs:4325-4439`, `private_block.rs:500-1030` (`weights_vanish_off_support`,
`check_words`, `check_accuracy_for_shape`, `digest`, `a21_digest_tree`), `run.rs:1120-1141, 1415-1530, 1630-1641`, `run_fork.rs:1109-1200,
2768-2795, 2807-2973`, `run_fork_tests.rs:2519-2700` (the test that printed the 275.5 ms), `argument.rs:3215-3262, 3372-3392, 4030-4113`,
`argument_accuracy.rs:11-46`, `accuracy_fold.rs:40-125, 1043-1172`, `zkp-core/src/mle.rs:156-320`, `zk.rs:1241-1282`, the A14, A18,
A20, A21, A26 READMEs. Labels: COUNTED (file:line), MEASURED (record), DERIVED (script), ASSUMED.

## 1. Result

**Fail on the item's width line, and a larger finding than the line.** Non-PCS work is not 6 to 24 ms of the 275.5 ms block. Counted
from the code and bounded from above by the measured total, it is **114 to 179 ms (41 to 65%), width 65 ms** (DERIVED; the lower end is
bottom-up at ASSUMED scan rates, the upper end is the residual after the PCS parts tick 60 counted). The width is not under 15 ms because
the dominant items are byte scans of the public weights, for which no retained record separates their time. What the counts do settle:
the items, their sizes, and how often each runs.

## 2. What runs a block, counted (8B: `d_pad` 4,096, `f_pad` 16,384, `q_pad` 4,096, kv 1,024; `shape.rs:302`)

The block's public words are **243,277,824 int8 bytes padded** (the nine words; `check_words` demands the padded lengths,
`private_block.rs:628, 772`; equals A20's figure; the "218 MB" in A21 prose is the unpadded 218.1 M).

| item | count per block | where | size |
|---|---|---|---|
| `check_for_shape` (CS-1/CS-4) | **2** (stage check, then `verify_core`) | `run.rs:1131-1133` or `run_fork.rs:1184`; `protocol.rs:4332` | each: a min-scan of all 243.3 MB (`private_block.rs:933-935`, `contains(&i8::MIN)`), 25.2 M off-support entries (`weights_vanish_off_support` x 9, only `Dom::F` pads: 2,048 of 16,384), 1 `check_for_registry` |
| `check_for_registry` in `define` | **23** (every slot; the verifier has no record, `argument.rs:4030-4033, 4112`) | `argument_accuracy.rs:19-21` | rebuilds the registry's public tables each call (A18: "about 3 ms" for the 23) |
| weight folds | **7** (Q, K, V, O, Gate, Up, Down) | `argument.rs:3249, 3390`; verifier mode `fold_with_mode(fast=false)`, `accuracy_fold.rs:1149-1150` | each: a min-scan then a zero-skip scalar loop over the whole padded matrix: 243.3 M entries a block each pass; nonzero products only (diagonal: tens of thousands) |
| block digest (CS-6) | **0 in the 8B test** (`RepeatBlock` holds a cached digest, `run_fork.rs:1109, 1144-1150`); 1 where a source hashes (`preflight` with `check_digests`, `run_fork.rs:1192-1197`); the classifier verifier hashes twice (A26 README) | `private_block.rs:972-1031` | 243.3 MB, BLAKE3 |
| `stage_in_c` embedding fold | **0 at the 8B profile** (a token/classifier-table item, not in `verify_core`) | A26 README table | not on this block |
| M opening | 1 | `zk.rs:1241-1282` | 50 forward NTTs of 4,096 (24,576 butterflies each, 1.23 M) and 256 columns of 50 words: about 3 to 5 ms (DERIVED) |

Bytes read a block by the scans: about 1,024 MB (2 min-scans 486.6 MB, the folds' min-scan 243.3 MB, their loop 243.3 MB, 2 x 25.2 MB
vanish).

## 3. Rates and the bottom-up range (one thread, ms a block)

- MEASURED: BLAKE3 over the block, one pass, one thread: 115.3 ms (A21 README 2.1; 0.474 ms/MB with byte copies); tick 58's rate 0.53
  ms/MB gives 128.9 ms. The tree form is 5.9 ms **on the default pool**, so it is not a one-thread figure.
- ASSUMED: `contains(&i8::MIN)` 8 to 25 GB/s; the indexed vanish loop 0.5 to 1.0 ns an entry; the zero-skip fold loop 0.25 to 0.6 ns an
  entry. MEASURED anchor for the folds' floor: A18/A14 prover profiles give 1.44 to 1.97 CPU-s a call over 32 blocks, 45 to 62 ms a
  block (prover side, six forks sharing the pool; the loops are the same `fold_*_i8`).
- Items (script section 4): two checks 37 to 98 (min-scan 20 to 61, vanish 18 to 37); registry x25 3 to 73 (A18's "about 3 ms" against
  its profile's 0.017 s main line and 2.15 CPU-s a call, 67 ms a block); seven folds 71 to 176; M 3 to 5. **Sum 114 to 352 ms**: its top
  exceeds the measured 275.5 ms, so the total cuts it.

## 4. The top-down cut (DERIVED)

275.5 ms less the PCS parts tick 60 counted: NTT 75 to 94 (counts x rates of other loops, not measured on the verifier), column and path
hashing 6.1, absorb 6.1, group inner products 3.7, and the proximity weights' column products at least 5.7 ms (the measured sparse saving
of 127.3 ms over 33.2 M dense products implies **at least 4.0 ns a product**, against tick 60's 2.24). **Residual: 160 to 179 ms**, which
holds the non-PCS work, the nonzero-row column work (uncounted: the supports are not retained, tick 60) and the slot replay (not counted
here). So non-PCS is at most 179 ms and, bottom-up, at least 114. If the NTT term is under 75 ms the residual is larger.

## 5. What it changes (DERIVED, conditional on the ASSUMED NTT term; not a claim)

- Tick 60's "stays under B6a" (6.1 to 23.9 ms) is low by a factor of 5 to 7: stays is 120 to 185 ms (non-PCS plus 6.1 hashing). One
  thread under B6a would be 194 to 242 ms a block (removed 90 to 110, BAT + tower 28 to 57), a gain **x1.14 to x1.42** over 275.5, not
  x1.6 to x3.1 (already withdrawn) and not tick 60's x1.15 to x3.1. The size step's verifier case for B6a is smaller than ticks 58 and
  60 said, because the weights' checks and folds, which B6a leaves, dominate the diagonal-weight block.
- Not unique to B6a: the 8B verifier's per-request cost is mostly work on public data. A verifier-side "check once per resident block"
  (the prover has it: A17 `CheckedPublic`, A18, A23; the verifier is forbidden it by design, `run_fork.rs:1176-1178`, and A26's
  `HL_A26_VERIFY_ONCE` is off pending a reading) would remove one of the two checks (19 to 52 ms) and the 23 registry rebuilds (3 to 67
  ms): about 22 to 119 ms of the 114 to 179, byte-preserving, but a security-owner ruling.
- The folds are challenge-dependent (inherent per request), and the verifier runs the plain scalar zero-skip loop; the prover has a NEON
  form (`fold_rows_fast`, `accuracy_fold.rs:486`, prover side only). A verifier use of it would be byte-preserving. Verifier side, after
  the clock: no effect on proved tokens a second.

## 6. Falsifiable tests (none scheduled)

- **T-N2 (CPU-only, under 1 s, under 1 GiB: one 243 MB block).** One thread (`RAYON_NUM_THREADS=1`), one W16R2_8B diagonal block
  (`range16_tests::case`): time, median of 7, (i) `check_for_shape`, (ii) the seven `fold_checked(..., prove_side=false)` with fixed eq
  vectors, (iii) 23 `check_for_registry`. Pass: sum within 114 to 179 ms, then item 104's non-PCS figure stands at that range and its
  width is the measurement's. Kill: sum under 60 ms (the stays are small, tick 60's range revives and the residual is slot replay or a
  larger NTT term); sum over 179 (the NTT term is under 75 ms).
- **T-V1 (tick 58, still decides).** Phase marks on a one-thread verifier; this item's counts say which phases to expect.

## 7. Honest effect

Committed words per request: 0 changed. Proved tokens per second: none (verification runs after the clock). What changes is the case for
B6a's verifier gain and a verifier-side lever of about 22 to 119 ms a block (0.7 to 3.8 s a 32-block request one thread, 0.1 to 0.6 s at
an ideal six-fold; byte-preserving, needs a ruling).

## 8. Risks and not verified

- Every scan rate is ASSUMED; the lower end 114 ms is as unmeasured as the upper. The cut uses tick 60's NTT term, itself derived.
- A18 gives two figures for the 23 registry checks (about 3 ms; 17 ms main line, 67 ms CPU a block); the range keeps both.
- A14/A18's CPU-seconds were taken with six forks sharing a pool: contention inflates them against one thread alone.
- Not counted: the slot replay (sumcheck rounds, `total_at`, public tables through A26's split eq tables), the transcript, the
  nonzero-row column products, `coefficients`, `check_opening` and `finish_claims`. The residual contains them.
- The test uses `RepeatBlock` (one block object, cached digest); a real source differs in the digest count and may have cold caches.
- The classifier (R13 Shieldstral, A26 profile) has real weights and no padding, so its shares do not transfer; the 8B profile's `Dom::F`
  padding sets the vanish count.
- `contains` on `i8` may not be a SWAR `memchr` on this toolchain; not checked.

## Coordinator's check (2026-11-27)

By the Claude co-coordinator. Script `20261126-claude-tick68-verifier-non-pcs-count-crosscheck.py`, output
`...-crosscheck.out.txt` (standard library, reads tracked files only; 66 checks, all passed). The tick's own script was re-run
with the heavy lock free and its output is identical to the saved one.

**Read by me, line by line** (the handoff names files without their tree: all are under `ops/zkp-mvp/gpu-metal/`,
`hashline/src/private_block/` unless said): the timed test line (`run_fork_tests.rs:2673-2675`), `verify_run_with` and the
verifier's start (`run.rs:1131-1133, 1424, 1486, 1636-1640`), `RepeatBlock` and the fork verifier's preflight
(`run_fork.rs:1109, 1130-1151, 1178, 1184, 2788, 2810`), `verify_core` (`protocol.rs:4325-4363`), the block checks
(`hashline/src/private_block.rs:510-548, 624-655, 770-798, 918-970`), the per-slot registry check
(`argument_accuracy.rs:11-21`, `argument.rs:2953-2955, 4023-4031, 4106-4112, 4145`), the fold sites
(`argument.rs:3230-3250, 3374-3391`), the verifier's fold (`accuracy_fold.rs:45-48, 1043-1085, 1137-1151`), the plain loops
(`zkp-core/src/mle.rs:157-200, 245-319`) and the profile (`shape.rs:302`). Records read: the verifier thread set, A14, A18,
A20, A21, A26, ticks 58 and 60.

**Carried forward as counted [code read; nothing built or run].** In the test that printed the 275.5 ms, each block gets two
full checks of its public weights (one at the run's start, one inside `verify_core`), 25 registry checks (one in each full
check, 23 in the slot definitions, because the verifier passes no record) and seven weight folds. A verifier fold is the base
fold: a scan for the one forbidden value, then a loop that visits every padded entry and skips zeros one at a time. Together
these read about 1,023 MB of public weights a block. The block digest costs nothing in this test (the test object holds it);
one pass over a block on one thread is 115.3 ms [A21, measured].

**Carried forward as a reading, with one measured anchor.** Tick 60 left at most 17.8 ms a block for all work outside the
commitment checks. That was too low. An earlier sampled profile of the same loops, at this profile and with the same diagonal
test weights (A18, prover side, six forks), gives 45 ms of pool CPU a block for the three feed-forward folds alone (0.224 ns an
entry), and 81 to 84 ms of CPU a block for all folds and public tables (A14 and A18, main line plus pools). Sampled pool time
can include waiting, so these are indications, not one-thread timings.

**Carried only as an assumption-bounded range.** "114 to 179 ms (41 to 65%)": the lower end is a sum at assumed scan rates,
the upper end is what is left after tick 60's transform term, which was itself derived from the rates of other loops. Neither
end is measured, and the handoff says so. The same holds for the one-thread gain of x1.14 to x1.42 under B6a and for the
22 to 119 ms a once-only verifier would save. What stands without the assumptions is the direction: B6a leaves the checks and
folds in place, so its gain for this verifier block is smaller than ticks 58 and 60 said.

**Corrections.**
1. The queue's Done line says "7 weight folds over 243.3 M entries each". The seven folds together visit 243,269,632 entries
   a pass (the block's bytes less the two gain vectors); section 2's table means the same.
2. "Low by a factor of 5 to 7" compares with the upper end of tick 60's figure only (120.1 / 23.9 = 5.0, 185.0 / 23.9 = 7.7).
   Tick 60's 6.1 to 23.9 ms included 6.1 ms of hashing; its allowance for the work counted here was 0 to 17.8 ms.
3. The registry range's upper end (67 ms a block) is sampled pool CPU of six forks under that bucket; what those samples
   hold is not established. The record's measured figure is the main line: 0.017 s per fork per call, 3.2 ms a block.
4. The timed line also covers the run's start and finish (the NTT tables are built there, and the endpoint is checked),
   which section 8 does not list. They sit in the residual.

**Not carried.** The M opening's 3 to 5 ms (the formula is repeated in my script; its inputs were not re-read).

**A correction to my own record.** The verifier thread set's README (2026-11-25) says that on diagonal test weights "the
public weight folds are nearly free". The products are; the scan is not. A dated correction is appended there.

**For a ruling, not urgent.** A verifier that checks a resident block once in a call instead of twice exists for the
classifier path (`HL_A26_VERIFY_ONCE`, off, waiting for the security owner's reading). This handoff shows the 8B path has the
same repeat, plus the 23 registry re-checks. Nothing is built or scheduled; rulings CS-1 and CS-4 say the verifier always
checks.

**Test.** T-N2 would replace the assumed range by a measurement (one thread, one block, under a second). It needs test code
in the prover's tree and a quiet machine; it is not scheduled by this check.
