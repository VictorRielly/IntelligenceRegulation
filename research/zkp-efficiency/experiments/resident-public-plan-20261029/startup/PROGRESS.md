# ZKP efficiency progress

Cycle 0143 complete — `20261029T125649Z-54c94436`, October 29, 2026.

**No native proving improvement found.** Tiling two or four fresh private
mask pairs passes 36,000 terminal comparisons and 28,800 synthetic extension
checks. It was slower in 39 of 42 small CPU median comparisons; the initial
run was slower in all 42. These shared-machine diagnostics establish no
reliable native or GPU gain. The candidate remains parked.

R13 8B T128 accounting gives logical dot-read ceilings of about 1.28× and
1.48× before added costs. All 5.76–5.99 million private-word reads remain.
Extra accumulators require 24 or 72 bytes. Under the stated spill model,
one spilled 64-bit accumulator per added pair cancels the public-load saving.
Physical traffic, GPU registers, occupancy and native times are unmeasured.

The probe took 1.222 seconds and 20.6 MiB RSS on one CPU worker. Accounting
passes 414 checks; the source/count audit passes 1,072. Ten negative controls
pass. An initial control-count label was corrected and retained. All 60
hypotheses remain; hypothesis 60 is refined. Seven LIVE primary-source
records include a newly assessed older study of cache and register tiling.

Next: obtain exclusive native Eq, dot, extension and enclosing-proof clocks
before integration. The next local rotation tests public geometry planning
across 2/4/8 synthetic resident passes with fresh challenges. Whole-prover
high-end GPU measurements and verified resident workloads retain priority.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research used one Intel Core
Ultra 9 185H CPU worker. Witness, proof, serialization, verification, startup
and initial-prefill clocks, startup fraction, proof latency/bytes, steady-state
and total-workload rates: **unmeasured**. No prefill, resident-model proof
series or decode ran. Larger workloads remain allowed; longer dense attention
can increase work quadratically. The complete private 8B target of at least
50 proved tokens/s on an RTX 5090 or named high-end GPU remains **unachieved**.

[Experiment](experiments/pair-tile-dataflow-20261029/README.md) ·
[Dated report](progress/20261029T125649Z-54c94436.md).
Saved reports do not imply message delivery or supervisor liveness.
