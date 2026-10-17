# ZKP efficiency progress

Cycle0027 — `20261004T090146Z-73c03938`, checkpoint 2026-10-04T09:19:08.453675+00:00.

Complete public digest streaming/cache oracle passed 27 synthetic cases, 216 byte-stream comparisons, 351 tensor mutations and 23 controls in 0.144145s / 17812KiB RSS on one CPU thread. **No proving improvement measured.** [Experiment](experiments/full-public-digest-cache-20261004/README.md) · [Review handoff](handoffs/20261004-full-public-digest-cache.md).

Caching could remove repeated setup/statement digest scans and replace a counted64MiB cast temporary with64KiB scratch. The counted padded32layer public preimage is7.802GB per scan; this is no timing or peak measurement. Run stages already use stored digests, so they gain no avoided scan. Cold caches reset per process; fresh verifier/import content is independently hashed. A review-only Rust diff is saved, uncompiled/unapplied. Native ownership/BLAKE3/refusal/RNG/receipt parity and isolated digest clocks remain pending.

LIVE primary search assessed recent [GlueLUT](https://eprint.iacr.org/2026/494), older [cq](https://eprint.iacr.org/2022/1763), official Rust cache semantics and repository releases/history. Five qualified records saved; no author result reproduced. GlueLUT timings exclude PCS, and cq's large-table pairing setup differs from this256-entry native lookup path.

Accepted complete private8B passes0/countabletokens0; deviceCPU only, contextnull, passes0. Steady/total-workload rates, startup fraction, witness/proof/serialization/independent-verification and latency/lag/drain clocks unmeasured. No prefill/resident/decode proof; >=50/s remains unachieved. Larger workloads allowed, attentionT², masks/privacy unchanged.

Next: owner isolates both witness/down/SC_SZC and digest/cast clocks/actual peaks, then native/device/full-stack independent verification. Next local experiment bounds public prefix-hasher reuse across context changes. GPU SC_SZC/witness recurrence remains first priority. Reports are local artifacts, not notification-delivery evidence.
