# ZKP efficiency progress

Cycle0108 complete — `20261020T161854Z-f0b8edce` — 2026-10-20 UTC.

**No proving speed improvement measured.** The prospective tiled lookup
consumer now passes exact native Goldilocks Fp2 checks. Its helper reader
matches 3,168 entries against pinned Rust arithmetic; 100 tiny consumers match
every cubic row and terminal MLE. Independent audit adds 28 consumers,
164 affine/wrapping reader values and all 256 possible table zero-denominator
sites, including zero multiplicities. Main 10,386 checks; audit 1,766; all pass.

This is unmasked arithmetic, not a private proof. The native reciprocal cache
already exists. A fresh denominator table adds 4 KiB payload; native proof
memory/time and private masking/PCS costs remain unknown. Probe 0.313s,
audit 2.925s, under 19 MiB RSS; tiny reference build 0.423s/134 MiB, no GPU.

Searched current LogUp-GKR, Chimera October16 and Plonky3 sources; screened
older OpenSSLNTRU batch inversion. Thirteen LIVE queries/11 primary records;
no author speedups reproduced. Twenty hypotheses retained and lookup rank7
refined; complete GPU/resident evidence, DD scaling and capacity clocks lead.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context/device: **none**. Witness, proof, serialization, verification,
startup duration/fraction, steady-state and total-workload proved rates:
**unmeasured**. CPU clocks here measure research checking only. No long-context
prefill, resident-model pass or decode was performed. Larger workloads remain
allowed; longer context can increase attention work quadratically. The complete
private 8B target of >=50 proved positions/s on RTX 5090 or another named
high-end GPU remains unachieved.

Next local: price private claim/mask/PCS sites and explicit native point mapping
before claiming memory savings. Owner next: verified resident1/2/4/8, DD context
scaling and all-eleven FZC A/B under locks. Privacy/fidelity gates remain.

[Experiment](experiments/native-fp2-u8-consumer-20261020/README.md),
[handoff](handoffs/20261020-native-fp2-u8-consumer.md),
[dated report](progress/20261020T161854Z-f0b8edce.md).
Research-only writes; saved reports do not establish external delivery.
