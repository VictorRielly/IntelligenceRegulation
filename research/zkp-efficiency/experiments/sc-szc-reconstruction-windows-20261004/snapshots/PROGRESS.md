# ZKP efficiency progress

Cycle0028 — `20261004T100146Z-8793c93e`, checkpoint 2026-10-04T10:17:12.159921+00:00.

Public digest prefix reuse passed **72 synthetic cases, 576 resumed hashes and 22 controls** in 2.623259s / 20,084KiB RSS on one CPU thread. **No proving improvement measured.** [Experiment](experiments/public-prefix-checkpoint-20261004/README.md) · [Owner handoff](handoffs/20261004-public-prefix-checkpoint.md).

The counted Llama-sized layout can reuse17.205% of a digest scan at context512. The remaining82.795% includes FFN weights; existing support validation and constructor copies also remain. Reusing a complete finished digest is better when public words/context stay unchanged. Cross-context reuse needs a shared immutable owner and native BLAKE3/receipt gates; this idea is demoted until phase clocks justify it.

LIVE search checked sumcheck/GKR literature, EPFL/ICICLE repositories, BLAKE3 APIs/releases and older modular composition. Six qualified source records saved; no author performance reproduced. BLAKE3's version list resolves the previous unknown release year to2026-08-20.

Accepted complete private8B proofs/passes0; countabletokens0; deviceCPU only; proof contextnull; passes0. Steady/total-workload rates, startup fraction, witness/proof/serialization/independent-verification and latency/lag/drain clocks unmeasured. No prefill/resident/decode proof; >=50/s remains unachieved. Larger workloads remain allowed, attentionT² and privacy/fresh masks unchanged.

Next local experiment: exact MSB SC_SZC folded-table reconstruction with bounded windows, comparing every original round/final and counting rereads/live payload. Owner first measures recurring witness/down/SC_SZC and setup digest clocks, then native/device full-stack independent verification under shared locks. No heavy job queued. These reports are local artifacts, not notification-delivery evidence.
