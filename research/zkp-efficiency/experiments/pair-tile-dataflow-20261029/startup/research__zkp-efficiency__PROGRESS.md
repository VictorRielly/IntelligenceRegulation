# ZKP efficiency progress

Cycle 0142 complete — `20261029T115649Z-076e8d4a`, October 29, 2026.

**No native proving speedup measured.** R13 LOW+h24/DD has 201–209 private
mask pairs per 8B T128 block, depending on precision and DD. The older
non-DD estimate had 174. Six unchanged native metadata methods agree with
an independent schedule model across 144 retained census rows and 12
registered geometries. Native constructor, proof and privacy gates remain owed.

Validation passes 22,461 probe checks, 564 synthetic fixtures, 4,908 mask
comparisons, 4,908 extension terminals and nine controls. The independent
source/count audit passes 7,503 checks. Harness: 2.169 seconds, 25.0 MiB RSS,
one CPU worker. One audit-anchor whitespace error was retained and corrected.

Current public-tail grouping needs 33 non-DD or 36 DD Eq builds. Eager
public-sum preparation still adds about 35–37 MB of logical accesses per
block; prior low-reuse regressions remain, so it stays parked. All 60
hypotheses are retained; 53, 55, 57 and 60 are refined. Eight LIVE primary
source records cover October revisions and older plookup/Jolt techniques.

Next: owner measurements of exclusive Eq, dot, extension and enclosing proof
clocks. Complete proofs on a named high-end GPU and verified resident
1/2/4/8-pass workloads retain priority.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context/device: **none**; research used one Intel Core Ultra 9
185H CPU worker, no GPU. Witness, proof, serialization, verification,
startup and initial-prefill durations, startup fraction, proof latency/bytes,
steady-state and total-workload rates: **unmeasured**. No prefill, resident
model series or decode ran. Larger workloads remain allowed; longer dense
attention can increase work quadratically. The complete private 8B target of
at least 50 proved tokens/s on RTX 5090 or another named high-end GPU remains
unachieved.

[Experiment](experiments/current-profile-mask-census-20261029/README.md) ·
[Handoff](handoffs/20261029-current-profile-mask-census.md) ·
[Dated report](progress/20261029T115649Z-076e8d4a.md).
Saved reports do not imply message delivery or supervisor liveness.
