# Public request retention candidate — 2026-10-20

Run `20261020T001854Z-f39e44f4`; research-only,unbuilt/unapplied. No native speed result.

Interface: take the pool's public capacity vector plus an ordered MULTISET of
next exact requests followed by next minimum-capacity requests. Assign each
idle buffer at most once,using the existing first-smallest-fit semantics;
retain selected buffers in their original order,free only unselected idle
buffers,and observe stream/free completion before relying on reclaimed bytes.
Never inspect values,free a live lease,or reuse private masks/openings.
Preserve GPU/POOL lock ordering;do not recursively acquire the GPU mutex in
a drain wrapper while already holding it. Single-thread models do not test
concurrency or stream completion.

Patch location: tested Python `capacity_model.py` retain branch in
experiments/pool-live-capacity-20261020/. No production patch exists. Native
seam: frozen R8 hashline/src/gpu/cuda.rs pool_take441,pool_put455,
pool_take_min465,commit_zk_chunked1817,dev_pool_drain3146,
dev_reserve_hard3183;owner must re-pin/rebase. Existing drains/retry are already
present,including legacy zk.rs layer-top/after-H;do not add a redundant drain.

Validation: 59 synthetic scenarios,4602 events,
45703 independent request/lifetime checks,590
evidence corruptions rejected. Mixed public row schedule: no-drain peak
1794484768B/8 fresh;full-drain603304480B/20 fresh;selective603304480B/8 fresh.
Fixed-geometry full drain saves0 peak bytes and raises fresh5->20 over four
partial commits. These are modeled allocation capacities and counts,not VRAM,
CUDA clocks,full-layer/full-stack fit or complete-model passes.

Limits: synthetic dimensions and known-next-commit horizon;all previous
commitments dropped between iterations;no openings,caches,other phases or
concurrent leases;immediate/deferred release brackets do not reproduce the
driver. Rust policy was transcribed into Python,not executed. R8 optional
32-byte key upload is outside the current RAW_ALLOC note count;this alone is
not a meaningful speed lever. No native timing/receipt/privacy gate passed
in this cycle. D33 does not cover8B/R8/GPU/next-token merely by this study.

Owner next: source/request census at actual current trained/GPU call sites,
then native telemetry that distinguishes live pooled,idle pooled,raw,cache
and completed/pending releases. Compare original full drains with public
retention only where pressure and reuse coexist. Preserve exact/min choices,
one-shot/cap/refusal behavior and complete CPU/GPU bytes/receipt/CS/H-1/privacy
gates under shared build/heavy locks. Measure end-to-end allocations,sync,
witness,proof,serialization,verification and fixed-context1/2/4/8 resident
complete workloads with fresh masks. No GPU/build/merge authority here.

Falsify on absent avoidable idle,unmodeled live state or stale contents,
request-planner overhead/first-touch causing enclosing regression,or any gate
divergence. Target complete private8B >=50/s remains unchanged/unachieved.
