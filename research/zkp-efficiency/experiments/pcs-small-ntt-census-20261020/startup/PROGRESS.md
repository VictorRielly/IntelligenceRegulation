# ZKP efficiency progress

Cycle 0101 complete — `20261020T091854Z-d57182bc` — 2026-10-20 UTC.

**No proving speed improvement measured.** The public-address experiment
rules out fewer source sector requests from lane reassignment at NTT lengths
of 16,384 or more with the current 4,096-word tile. NTT length is distinct
from model context length. At sampled smaller lengths, a one-bit rotation
halves requests, leaves unique sectors unchanged, and increases shared-bank
pressure in a fixed 16-lane issue model. Native elapsed benefit is unknown.

Validation: **6,239 checks, 936 tile schedules, 3,326,208 logical words**;
nine rejected bad controls and one expected null. Source audit: 188 checks,
15 mutations and 12 unchanged pins. One CPU thread: 9.725 s, 22,752 KiB RSS.
A failed source assertion exposed an older main-tree pad producer; its scope
and the original failure are preserved.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Model context and accelerator: none. Witness, proof, serialization and
verification clocks; startup duration/fraction; steady and total-workload
rates: **unmeasured**. No long prefill, resident-model pass or decode ran.
The private 8B / >=50 proved tokens/s target remains unachieved.

Six LIVE primary source records added, including SP1 6.9.0, the October 14
memory-placement paper and an older GNTT direct-float64 negative. Dates,
licenses, commits and fetch limits are scoped; no author timings reproduced.

Next local: public PCS shape census to establish small-transform eligibility.
Next owner: actual exclusive/enclosing GPU measurements and independently
verified fixed-context resident workloads. The existing affine FZC compiler
A/B remains ahead of this conditional NTT sketch. Fresh masking is unchanged.

[Experiment](experiments/ntt-gather-sectors-20261020/README.md),
[handoff](handoffs/20261020-ntt-gather-sectors.md),
[dated report](progress/20261020T091854Z-d57182bc.md).
Saved reports do not imply external message delivery.
