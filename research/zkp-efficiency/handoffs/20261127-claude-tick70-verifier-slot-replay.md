# Research handoff: the slot replay of a W16R2_8B verifier block, counted (2026-11-27, claude tick 70, queue item 111)

From the Claude background researcher. Reading and arithmetic only: no build, no run, no web search, no Git. Written: this file,
`20261127-claude-tick70-verifier-slot-replay.py` (standard library, under a second; run with `python3 -I`) and its output
`...slot-replay.out.txt` (9 checks, all pass). Clock at writing 2026-11-27T07:53Z. Triage material, not a work order: nothing
here changes what the prover commits.

**Question.** Tick 68 bounded the non-PCS part of the 275.5 ms one-thread verifier block at 114 to 179 ms but left the slot
replay (the 23 slots' rounds, public tables at the end point, claims, functionals, `check_opening`) inside the residual. Count
the replay per class and price it with the repo's rates. Pass line of the item: a replay range under 20 ms wide.

**Read** (full text of the code, no web; under `ops/zkp-mvp/gpu-metal/`, `hashline/src/private_block/` unless noted):
`argument.rs` (`run_slot_with` and its `Side::Verify` arm, the table builders, `define`, `argument_with`), `argument_accuracy.rs`
(the W16 slot definitions), `protocol.rs:305-345, 4325-4439`, `shape.rs:2600-2714`, `pad.rs`, `accuracy_act.rs:33-41`,
`zkp-core/src/mle.rs`, `field.rs`, `sumcheck.rs`; records: the W16R2_8B production slot log (per-slot cube and table counts,
`results/zk60_slot18_14_breakdown_20261117/raw/`), the A26 README, and a retained 125M-profile CPU verifier phase log
(`results/zk60_sol_gpu_20260927/attempt-5-dense-ab/a1-cpu.log`). Labels: COUNTED (file:line), MEASURED (record), DERIVED
(script), ASSUMED (no retained record).

## 1. Result

**Fail on the width line; the sizes are fixed by the shape, the rates are not.** The replay is one thread, **71 / 108 / 165 ms**
(low, middle, high; width 94 ms, DERIVED, rates ASSUMED), and it is almost all one class: the verifier builds every public table
of every slot as a full vector of 2^n Fp2 words and takes its MLE at the end point. Everything else in the replay (370 sumcheck
rounds, about 150 claims, 23 functionals, the schedule audit) is counted at 0.5 to 3 ms (ASSUMED, by counts). The item's fail
clause (a class whose size is not fixed by the shape) does not apply: every class below is fixed by the shape. What fails is the
pricing, because no retained record separates the verifier's table-build time at the Mac.

**A larger consequence: tick 68's cut does not close.** Tick 68's residual after the PCS parts is 160 to 179 ms; its bottom-up
non-PCS lower end is 114 ms; the replay's lower end is 71 ms. 114 + 71 = 185 ms exceeds the 179 ms ceiling. So at least one of
four things is too high: a scan rate behind tick 68's 114 ms, a rate behind this replay, tick 60's derived NTT term (75 to 94 ms),
or tick 60's other PCS parts. If both lower ends are right the NTT term can be at most 69 ms (DERIVED; tick 60 derived 75 to 94).
The measurement that settles it (section 5) needs no new code.

## 2. What the verifier does per slot (COUNTED)

For each slot the verifier runs `define` (builds the public tables, argument.rs:2953 and `argument_accuracy.rs:11`), then the
`Side::Verify` arm: absorb the scalar, `sumcheck::verify` over n + ext rounds (argument.rs:2254-2256), one `SplitEq` of the end
point `rho` if any public table exists (2262), one product per public entry (`eval_ext`, `mle.rs:108-116`, 5 base multiplications
an Fp2 product, `field.rs:163-169`), `eq_point` for each `Tab::Eq` (n products each), the slot polynomial once (2275), one
`build_claim` per private table (2292), and the mask functionals (2300-2311). The verifier has no `PubGen` (the descriptors are
prover-only, `pts.pub_gen_prove = prove_side && host_fast_on()`, argument.rs:4117; the verifier refuses them, 1861-1863), so a
public table is a full `Vec<Fp2>` on this side.

## 3. The public tables of a block (COUNTED from the definitions; sizes MEASURED from the log)

The per-slot cube (2^n) and table count come from the production log's `PB-SLOTSTEP` rows (tables-build words / claimed-sum
words). Public tables per slot, from the definitions at this profile (8B: tokens = t_pad = 128, width = d_pad = 4,096, hidden
14,336 < f_pad 16,384, so Dom::F and Dom::Tab are the padded domains):

| slot | public tables | cube | entries |
|---|---|---|---:|
| 4 row sums (SC_RS) | causal mask (`argument.rs:3162`) | 2^19 | 524,288 |
| 5, 6, 7, 10, 11, 12 | folded public weight | 2^12 each | 24,576 |
| 13 down | folded public weight | 2^14 | 16,384 |
| 14 D zero-check | two `repeat_vals` (`argument_accuracy.rs:468-469`) | 2^19 | 1,048,576 |
| 15 Q zero-check | rope cos, sin (`:544`) | 2^19 | 1,048,576 |
| 16 KV zero-check | rope cos, sin | 2^17 | 262,144 |
| 17 softmax | causal mask (`:584`) | 2^19 | 524,288 |
| 18 F zero-check | `group_col` and `supp(F)` (`:514-515`) | 2^21 | 4,194,304 |
| 19 TAB | 25 tables (3 + 13 range sub-planes + 2 supports + 7 narrow supports; 58 tabs less 1 eq, 32 private) | 2^14 | 409,600 |
| all others | none | | 0 |
| **total** | | | **8,052,736 (128.8 MB at 16 B)** |

Slot 19's 25 follows from 58 tabs with 13 range sub-planes (the trace's 16 table planes, queue item 112); with 12 it would be 27
(8,085,504 entries): the total moves by 0.4%. That D, Q, Kv, S and T do not pad at this shape is read from the shape (tokens =
t_pad, width = d_pad) and agrees with the log's table counts; if D padded, slot 14 would hold one more table of 2^19.

## 4. Pricing (DERIVED; every rate ASSUMED except the multiplication)

- **Evaluation** (SplitEq, one Fp2 product and add per entry): 5 base multiplications at 0.8 / 1.12 / 1.6 ns (1.12 is the
  repo-derived BAT rate, tick 58) plus 0.5 ns: **36 / 49 / 68 ms** for 8.05 M entries.
- **Build, per class** (script section 4): causal masks 1.05 M entries (three runtime div/mod each) 4 / 8 / 16 ms; rope 0.66 M
  positions (four div/mod, two tables) 5 / 9 / 16; `repeat_vals` 1.05 M 2 / 4 / 8; `group_col` 1.84 M writes 4 / 6 / 7; `supp(F)`
  (an i64 indicator of 2^21, then an Fp2 map) 8 / 13 / 21; slot 19 and the folded tables 2 / 2.5 / 3. Memory first touch of
  145.6 MB (the Fp2 vectors and the indicator) at 0.06 / 0.10 / 0.15 ms a MB: 9 / 15 / 22 (no retained record gives a rate; this
  is the widest guess). **Build 34 / 57 / 94 ms.**
- Rounds, claims, functionals and audit: 0.5 / 1.5 / 3 ms (370 rounds; about 150 claims; `audit_claims`, `protocol.rs:249`).

**MEASURED anchor, with its limits.** A retained CPU verifier phase log of the 125M profile (2026-09-27, before A26, full eq
table per public table, default pool, thread count not checked) gives the 23 slot phases 0.565 s of a 0.838 s wall (67%) and, for
slots 4, 14, 15, 16, 17 together, 535 ms over about 21.5 M public entries, 25 ns an entry (slot 14: 10.0 ns an entry, slot 15:
12.4, slot 16: 9.5; the 2^23 mask slots 24 to 26 ns). That is the same table classes (masks, rope, `repeat_vals`) on other
hardware, the older evaluator (two products an entry for the eq table plus one for the dot) and a parallel pool; it does not
transfer as a rate. It shows only that on this verifier the public-table replay has been the largest CPU item before, and that
10 to 25 ns an entry all-in is the right order against this section's middle 13.4 ns (build 7.1 plus evaluation 6.1, 108 ms /
8.05 M).

## 5. Falsifiable test (none scheduled)

**T-R1 (CPU only, no source change, under 1 s of work, under 1 GiB beyond the block).** The fork verifier starts the phase
recorder (`run_fork.rs:2787`, `timing::Phases::start()`) and `verify_core` marks every slot (`ph.slot_work`, argument.rs:4209) and
the three openings. Rerun the test that printed the 275.5 ms (`run_fork_tests.rs:2519-2700`) with `HL_PB_TIMING=1` and
`RAYON_NUM_THREADS=1`; the 125M log shows what the printed rows look like. Pass: the per-slot rows for slots 14 to 19 and 4
sum, in one thread, to within 71 to 165 ms (then this range stands as a measurement and the sums of ticks 60, 68 and this one
are read together); kill: the slot rows sum under 40 ms (the rates here are too high and tick 68's residual is mostly
something else) or over 165 ms (the NTT term is under 69 ms). One run reads the three open terms at once: the slot rows, the
opening rows (A, H, M: the PCS part, against tick 60's NTT and column terms) and the unaccounted remainder (the checks and
folds of tick 68). Whether the fork verifier's `ph` prints in this test must be checked in the test first (it prints for the
non-fork path, as the 125M log shows); if it does not, T-N2 of tick 68 plus a mark around `argument` is the smallest change.

## 6. Honest effect

Committed words per request: 0 changed. Proved tokens a second: none (verification runs after the clock). What changes: the
split of the 275.5 ms block, and a possible lever. If T-R1 keeps the build part large (34 to 94 ms a block), the verifier could
evaluate the structured tables (masks, rope, group column, supports, `repeat_vals`) from closed forms or the prover's `PubGen`
descriptors (argument.rs:2384-2433) without materializing them: byte-preserving, 0.2 to 1.1 s a 32-block request at an ideal
six-fold. It needs the security owner's reading (the verifier refuses descriptors on purpose, 1861-1863) and an equality test
like A26's SplitEq test. Nothing is built or scheduled.

## 7. Risks and not verified

- Every build rate and the memory-touch rate are assumptions; the evaluation rate rests on the repo's one multiplication rate and
  on Fp2 = 5 multiplications.
- The pad status of D, Q, Kv, S, T at this shape is read from the shape, not from a printed indicator list; the table counts of
  the log agree (slot 0, 1, 4, 14 to 17), slot 3's fifth table (supp(L) or a third plane) was not resolved and moves the total by
  at most 16,384 entries.
- `finish_claims`, `check_opening` and `opening_groups_at` were bounded by counts (about 150 claims), not read line by line;
  `CfsMask::eval_weights` was not read. `interpolate_eval` was not read (370 rounds: under 2 ms even at an inversion a round).
- The 125M anchor is a different profile, machine, pool and evaluator; its slot 14 table count at that profile was not checked.
- The replay counted here sits in tick 68's 160 to 179 ms residual together with the nonzero-row column work (tick 60: not
  retained) and the run's start and finish; this tick does not add a measured term.

## Coordinator's check (2026-11-27)

By the Claude co-coordinator. Script `20261127-claude-tick70-verifier-slot-replay-crosscheck.py`, output
`20261127-claude-tick70-verifier-slot-replay-crosscheck.out.txt` (38 checks, all pass; run as `python3 -I <script>`).
The handoff's own script, re-run with both locks free, reproduces its saved output byte for byte.

**Stands [code read by me; nothing built or run].**

- **The verifier builds every public table in full.** The compact descriptors are switched on for the proving side
  only (`argument.rs:4117`), and the verifier refuses a slot that carries one (`1861-1863`). Each table is then
  evaluated at the slot's end point through one split table, one extension product an entry (`argument.rs:2262`,
  `mle.rs:108-116`; five base products, `field.rs:163-169`).
- **The count.** With the cube sizes of the 8B production log and the builders at the lines the handoff gives (the
  causal mask in slots 4 and 17, two repeated gain tables in slot 14, two rotation tables in slots 15 and 16, the
  group column and the support of F in slot 18), a block has 8,052,736 public entries, 128.8 MB. Slot 18's two tables
  are 52% of them. Not re-counted by me: slot 19's 25 tables (5% of the entries) and the folded weight tables.
- **The arithmetic of the sum that does not close.** Tick 68's lower end (114.0 ms: checks, registry, folds and the M
  opening, at assumed scan rates) plus this tick's lower end (71 ms, assumed rates) is 185 ms, more than the 178.9 ms
  left after tick 60's commitment terms. All three are estimates. The finding is about the estimates: they cannot all
  hold. It does not say which is high, and it says nothing new about the system.

**Carried only as an assumption-bounded range.** "71 / 108 / 165 ms". The evaluation part (36 to 68 ms) rests on one
derived multiplication rate; the build part (34 to 94 ms) on an assumed rate for each loop and for the first touch of
memory. The handoff says so.

**Correction: the proposed test does not print without a code change.** T-R1 expects the fork verifier to print its
phase table under `HL_PB_TIMING=1`. That verifier starts a recorder and hands it to `verify_core`
(`run_fork.rs:2787-2788`) and never prints it: the file has no report call. The per-step timer (the `PB-SLOTSTEP`
rows) is called four times, all in the proving arm (`argument.rs:1933, 2020, 2038, 2195`; the verifier arm starts at
`2249`). A verifier phase table is printed in two places only: the single-block verifier (`protocol.rs:4498`) and the
classifier run's verifier (`token_io/classify_run.rs:1014`). So T-R1 as written needs a line of test code. This
answers the reading queued as item 113.

**Added: two measured records of this machine that the handoff did not use.**

1. The app lane's verifier log of 7 November (`results/zk60_a24_app_20261107/baseline_b1_cpu_verify.log`) holds 26
   verifier phase tables, one a block, of the R13 classifier profile. A block: wall 0.370 s on average (0.337 to
   0.599); the 23 slot rows 0.203 s (0.168 to 0.337), 55% of the wall; slots 4 and 14 to 18 together 0.136 s (0.108
   to 0.220); the opening rows 0.050 s (0.045 to 0.079) [MEASURED, that log; sums by my script]. The work marks of
   those slots are consistent with the 8B profile's cube sizes (the classifier pads to the same domains). Limits: an
   earlier binary (the log is in A24's directory, and A26's record names the split tables as its own later change, so
   this is most likely the older evaluator); trained weights; a thread pool whose size the log does not state; a slot
   row also covers that slot's registry check and weight fold; the R13 profile has more tables a slot. It is not a
   rate for today's code. It shows that on this machine the slot rows have been the largest group of a verifier
   block's wall time, four times the opening rows.
2. A26's sampled profile of that earlier binary's verifier (`results/zk60_a26_app_20261107/README.md`, lines
   93-101): the transform 12% of the verifier's CPU, the weight folds 14%, the block checks 11%, the slots' public
   tables about 10% with a full eq table per table. Sampled pool CPU, classifier, trained weights: an indication of
   proportion only.

Both point the same way as the handoff: the public-table work is a real share of the verifier, of the same order as
the transform. Neither settles which estimate is too high.

**A route to the measurement with no code change.** The classifier run's verifier prints a table a block, as the 7
November log shows. A one-thread run of that verifier on a retained receipt of the installed profile, with
`HL_PB_TIMING=1` and a one-thread pool, would give the per-slot rows, the opening rows and the load row for the
profile the app ships, at the same cube sizes. Item 113 is rewritten to prepare that by reading (command, inputs,
reading rule) and moved first in the queue. Nothing is run until its reading rule is written in the coordination
file and pushed.

**Not carried.** "25 ns an entry" from the 125M log as more than an order of magnitude (the handoff says the same).
The lever's "0.2 to 1.1 s a 32-block request at an ideal six-fold": a figure built on the assumed build range and an
assumed factor.
