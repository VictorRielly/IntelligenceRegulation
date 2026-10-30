# ZKP efficiency explorer — durable state

Cycle 0149 COMPLETE: `20261029T185649Z-81a2bde2`.
Started 2026-10-29 18:56:49 UTC; deadline 19:16:49 UTC.
Next cycle no earlier than 19:56:49 UTC. Read AGENDA.md every cycle.
Startup memory, owner documents and prior results are preserved in
experiments/h-structural-support-20261029/startup/.

**No native proving improvement measured.** Frozen R13 H source offsets
and unchanged claim builders establish disjoint evaluation supports, plus
full-data LogUp sum and dense proximity. At source 8B/T128 with generic
distinct public slot keys, chunk4 H visits fall from 13,170 to 8,778
without DD, and 12,702 to 8,358 with DD32: logical matrix reads decrease
33.3485% / 34.1993% with the prior zero-skip candidate. Combined with the
prior conservative A bound, the reductions are 11.4455% / 11.7830%.
These are structural work bounds, not physical DRAM, time or R14 results.
Native define and native Fiat–Shamir were not executed.

Exact three-batch structural packing gives 5,592 / 5,280 visits, or
57.5399% / 58.4317% below dense H. Exhaustive DP agrees with batching the
sum, proximity and largest D/F evaluation supports together. Full batches
precede the sole partial batch; all tested outputs return to logical order.
Planning, copy and device costs remain unknown. The existing API's simple
implementation adds 702,400 / 745,184 B of public rho copies; streaming can
limit active clone payload to 280,960 / 270,976 B. The prior kernel's source
accumulator plus weight temporaries grow 64 to 128 B/thread; actual
registers, spills and occupancy are unknown.

Corner challenges merge group keys. Some small fixtures fit in one batch,
where dense proximity leaves no matrix-read saving. Never hardcode generic
counts. Preserve the prior mask-only packing counterexample; do not assume
A has H's disjointness. Keep H sum/U, all masks, pads, proximity, outputs,
refusals, RNG order, FS and PCS. No private material or randomness is reused.

Validation: 20 Rust fixtures; 539,532 independent full-cube coefficients;
1,683 message-plus-pad folds; 1,683 restored-order values; five control
classes invoked 90 times. The independent Python offset/interval/union/DP
census passes 175 checks. Exact native helpers were extracted, with local
public Shape and source-read slot mapping supplied. Seed 202610290149.
Final compile 2.232 s / 185,528 KiB; probe 0.0658 s / 9,324 KiB; census
0.0658 s / 17,428 KiB. One CPU affinity, nice 19, 40 s CPU / 45 s alarm /
50 s parent, 384 MiB address-space caps. Initial macro compilation and
single-batch control failures are retained and corrected. Passing results
before packed scatter also remain. Final artifact audit: 90 checks PASS;
six mandate/owner documents unchanged. No CUDA or native build.

Ranked queue: 1 owner whole-prover high-end GPU plus verified resident
1/2/4/8 workloads; 2 admitted-context/DD/fidelity scaling; 3 exclusive
native phases and capacity. All 68 prior hypothesis objects are unchanged;
69 adds H source incidence, 70 adds conditional complete-support packing.
Ceiling: N/(T−C_removed_exclusive+A_added); exclusive fraction f unknown,
and free deletion is bounded by 1/(1−f). No numerical 8B rate forecast.

Owner next: current public H part/group/nonzero/union counters and exclusive
rho-H2D/allocation/kernel/D2H/pad/open/enclosing clocks, including the prior
rho-H2D stats omission. Re-pin R14 separately. Only if material, owner uses
current shared locks for CUDA/register/device and native golden/refusal/
RNG/FS/PCS/privacy plus independently verified full-receipt A/B. Main/Claude
reviews and integrates. No heavy or GPU job queued; prior patch unapplied.
Next local: derive A's actual source offsets and overlapping support, using
H as a control. New owner measured bottlenecks take precedence.

Seven LIVE records added, 993→1000; nine raw web batches saved. Refreshed
StateSync October26v2, zkDuel and June NTT/sumcheck; newly assessed 2012
cache locality and May2026 constrained hypergraph partitioning/AxonCUDA.
Expander commit 4c7d50a03b40867032167aac37dc7af026e1afcd metadata and partial
diff date to October28,2024, not October2026. Current root AGPL3 body
inspected; MIT declarations lack inspected full license bodies. Exact
URLs, date/license/commit limits and Cachemiss blockers retained. Future
November16 search result excluded. No author performance reproduced.

Owner R13/R14 matched result remains n=1 shared-box, public sparse
synthetic two-block T128, 49.2→35.1 s; reviews owed. Its 17:33:30 state
report is not liveness. No 8B GPU result. D44/D45/S4 do not amend the target;
R13 8B/T512 is unregistered at 94.48/94.80 bits.

New independently verified full-stack proofs / passes / positions:
**0 / 0 / 0**. Actual context and accelerator: **none**. Modeled context128.
Device: one pinned Intel Core Ultra 9 185H CPU worker. Witness, proof,
serialization, verification, startup/prefill duration and fraction, proof
latency/bytes, steady-state and total-workload rates: **unmeasured**.
No prefill, resident-model series or decode ran. Larger workloads remain
allowed; dense attention can grow quadratically. Complete private8B
>=50 proved tokens/s remains **unachieved**.

Carried older-profile CPU8B baseline, not rerun/reverified/newly counted:
T128/L32, one 16-thread pass, GPU off. Total478.737s=0.267370positions/s;
prove_run393.785s includes witness98.348s/load17.595s. Sealing84.824s
precedes it, with overlapping load27.151s/witness80.897s. Receipt922,711,264B;
verify42.709s plus load13.681s. Isolated serialization/startup fraction and
steady slope unknown. No high-end GPU conclusion follows.

Experiment: experiments/h-structural-support-20261029/README.md.
Handoff: handoffs/20261029-h-structural-support.md.
Report: progress/20261029T185649Z-81a2bde2.md.
Checkpoint 2026-10-29 19:10 UTC; editorial cleanup 19:12 UTC.
Only research outside runtime written. Production/Git/receipts/calibration/
instructions/safety/reviewer files untouched. No GPU/native build/install,
foreign execution, external write/message, purchase, escalation, Git or
merge. Saved reports do not imply delivery or supervisor liveness.
