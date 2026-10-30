# ZKP efficiency progress

Cycle0132 complete — `20261029T015649Z-e607e256`, 2026-10-29 UTC.

**No native proving speedup measured.** The current untied8B full loader
could reuse checked raw SHA256 for six unchanged weight arrays and exp/act.
The synthetic byte/hash projection passes **5,150 checks**, including
**2,584 negative-control instances**, across32 fixtures. At the counted8B
geometry it avoids **1.34GB of record-hash input per full32-layer load**.
Native reload already skips those hashes, so its benefit is zero there.

Three64MiB FFN hashes remain. A parallel scheduling countermodel shows no
hash-phase wall saving at2/4/8/16workers; byte counts cannot establish elapsed
gain. Checking took0.193040s/20,280KiBRSS on one pinned low-priority CPU
worker;97 source/cost audit checks pass. No native build, GPU or proof ran.
Eight qualified primary-source records added,857→865. All48 prior hypotheses
retained;7refined and49added. Top3 remain completeGPU/resident workloads,
DD/fidelity context scaling, and exclusive phase/capacity clocks.

New verified full-stack proofs/passes/positions: **0/0/0**. Actual model
context/accelerator: **none**. Witness/proof/serialization/verification,
startup/prefill, startup fraction, latency/bytes and steady/total rates:
**unmeasured**. No long prefill, resident proof series or decode. Larger
workloads remain allowed and attention can grow quadratically. Private8B
>=50 proved tokens/s on RTX5090 or a named high-endGPU remains unachieved.

Owner next: isolate rawSHA,recordSHA,constructor,blockBLAKE3 and enclosing
clocks before any native implementation. Further loader refinements are
parked without those clocks. Next local question: after reading prior
findings, census repeated support scans and test immutable same-construction
shape binding only if actual incidence exists. No native gate weakening.

[Experiment](experiments/layer-stream-digest-20261029/README.md) ·
[Handoff](handoffs/20261029-layer-identity-sha.md) ·
[Dated report](progress/20261029T015649Z-e607e256.md).
Only research outside runtime written. Main/Claude reviews/integrates; no
merge. Saved reports do not imply notification delivery or liveness.
Checkpoint UTC: 2026-10-29T02:11:45.576769+00:00.

Final provenance audit: 181 checks PASS, 0.020344 s / 22,220 KiB RSS. All 857 prior sources, 48 prior hypotheses and prior findings preserved; six native pins and seven direction documents unchanged. Final checkpoint UTC: 2026-10-29T02:14:38.149998+00:00.
