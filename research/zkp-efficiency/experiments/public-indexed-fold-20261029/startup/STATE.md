# ZKP efficiency explorer — durable state

Cycle 0150 COMPLETE: `20261029T195649Z-795daf31`.
Started October 29, 2026 at 19:56:49 UTC; deadline 20:16:49 UTC.
Next cycle no earlier than 20:56:49 UTC. Read AGENDA.md every cycle.
Checkpoint: 2026-10-29T20:12:13.050001+00:00. Startup snapshots and hashes are retained in
experiments/a-overlap-support-20261029/startup/ and memory-index.json.

**No native proving improvement measured.** Frozen R13 A public source
support gives 9,654 / 9,328 row visits versus 45,770 / 44,550 dense chunk4
at 8B/T128, noDD / DD32: 78.9076% / 79.0617% fewer logical matrix reads
with the prior zero-skip candidate. Combined original-order A/H reduction:
68.7275% / 69.1085%. A has 508 / 509 overlapping data rows; do not import
H's partition. Native define, FS and CUDA were not run. R14 differs.

Public pair-swap plans give 5,658 / 5,794 A visits, local optima only.
Python planning: 17.9 / 27.3 ms n=1. Source-row/narrow-five-column base-field
folds restore all logical outputs. Simple rho clones add 2,709,584 /
2,779,920 B, or streamed active payload 292,928 / 285,120 B. No production
patch; the prior kernel patch remains unapplied.

All row scans and 44.394 / 45.546 GB of logical rho operands remain.
Matrix-plus-rho source read reduction is only 9.3938% / 8.9843% before
compiler/cache/broadcast effects; no physical traffic or time follows.
Source accumulator plus weights grows 64→128 B/thread; registers/spills/
occupancy remain unknown. Keep all transfers, outputs, pads, fresh masks,
proximity, H sum/U, refusals, RNG/FS/PCS and privacy requirements.

Validation: 14 Rust fixtures; 27,540,288 independent coefficients;
5,172 restored synthetic message-plus-pad values; 380 source-row packed
base-field values; 62 controls. Independent census: 517 checks; helper/
artifact audit: 64; nine owner/mandate documents unchanged. Synthetic small
shapes are unadmitted; native pads, FS, receipts and privacy were not tested.
Initial compile/log/census-key/modulo failures and prior passing results saved.
Seed 202610290150. Compile 2.6373 s / 183,748 KiB RSS; probe 0.6713 s /
25,748 KiB; census 0.1663 s / 17,388 KiB. All bounded stages use one CPU
affinity, nice 19, 40 s CPU /45 s alarm /50 s parent and 384 MiB address-space
caps. Serial worker; compiler auxiliary threads unmeasured, one codegen unit.

Ranked priorities: 1 owner complete high-end GPU proofs and verified resident
1/2/4/8 workloads; 2 admitted context/DD/fidelity; 3 exclusive phases/capacity.
All 70 prior hypotheses preserved; 71 tests A support and packing; 72 asks
whether sorted public row-union indices remove empty scans and rho loads.
Next local: indexed-loop/base-field differential with missing, duplicate,
out-of-range and order controls, imaginary rho, masks, pads and proximity.
Charge construction, upload and indirection. Original index payload:
38,616 /37,312 B, or packed 22,632 /23,176 B, including dense proximity.
No indexed kernel tested. New owner measured bottlenecks take precedence.

Owner next: actual current public descriptor/group/support counters and
exclusive rho H2D/allocation/kernel/D2H/pad/open/enclosing clocks; prior H2D
stats omit rho upload. Re-pin R14 separately. If material, owner uses current
shared locks for CUDA/register, native golden/refusal/RNG/FS/PCS/privacy and
independently verified full-receipt/workload A/B. Main/Claude integrates.
Ceiling N/(T−C_removed_exclusive+A_added); exclusive fraction unknown;
free deletion ≤1/(1−f). No numerical 8B GPU forecast.

Five LIVE records, 1000→1005; eight raw batches. StateSync October26v2,
efficient-sumcheck and MegaZK refreshed; 2025 cache methodology and 2026 HE
objective newly assessed. StateSync's current BSL1.1 body inspected; no
foreign implementation executed or adopted, no external commit inspected.
Exact URLs, dates/nulls, license limits and Cachemiss blockers saved.
Owner R14 state at 19:14:14 reports held pipelines, not liveness. Its n=1
shared-box two-block public sparse comparison excludes initial setup/later
verify; reviews/privacy remain owed. D44/D45/S4 do not amend this target.
R13 8B/T512 remains unregistered at 94.48 /94.80 bits. No 8B high-end GPU rate.

New independently verified full-stack proofs / passes / positions: **0/0/0**.
Actual context and accelerator: none; modeled T128; one pinned Intel Core
Ultra 9 185H CPU worker. Witness, proof, serialization, verification,
startup/prefill duration and fraction, proof latency/bytes and both rates:
unmeasured. No prefill, resident series or decode. Larger workloads remain
allowed; attention can grow quadratically. Complete private 8B >=50 proved
tokens/s remains unachieved.

Carried older CPU 8B baseline, not rerun/reverified/newly counted: T128/L32,
one 16-thread pass, GPU off; total 478.737 s =0.267370 positions/s.
prove_run 393.785 s includes witness 98.348 s /load 17.595 s; sealing
84.824 s precedes it, with overlapping load 27.151 s /witness 80.897 s.
Receipt 922,711,264 B; verify 42.709 s plus load 13.681 s. Isolated
serialization, startup fraction and steady slope unknown. No GPU conclusion.

Experiment: experiments/a-overlap-support-20261029/README.md.
Handoff: handoffs/20261029-a-overlap-support.md.
Report: progress/20261029T195649Z-795daf31.md.
Only research outside runtime written. Production/Git/receipts/calibration/
instructions/safety/reviewer files untouched. No GPU/native build, install,
foreign execution, external write/message, purchase, escalation, Git or merge.
Saved reports do not imply delivery or supervisor liveness.
