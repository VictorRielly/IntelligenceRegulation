# ZKP efficiency progress

Cycle 0078 — `20261019T101854Z-3562a78f`, 2026-10-19 UTC.

**Useful scheduling result; no measured proving speedup.** Constructing D
endpoint pairs on first use lowers the current unpadded catalogs' complete
logical peak **129→77 field words (40.3%)**, including endpoints, construction
temporary and round accumulator. Arithmetic and reads are unchanged; all
original tables, folds and finals remain. This is a logical model, not a GPU
register, VRAM or proof-time measurement. Keeping the cache until the end
loses the gain; recomputation on every use adds reads.

Thirty synthetic fixtures and 221 independent audit checks pass. The main
test took 8.613 s on one Core Ultra 9 185H CPU thread. The audit caught a
saved-metadata bug, now fixed; the initial failure is retained.
[Experiment](experiments/dzc-lazy-endpoints-20261019/README.md) and
[unapplied handoff](handoffs/20261019-dzc-lazy-endpoints.md).

Seam: `SC_DZC` / `SumcheckRounds`. Native compiler, receipt, RNG, refusal,
privacy and timing gates remain owner work. Next: interleave affine
contributions with endpoint helper uses, charging every accumulator, read
and aliased term. Eight LIVE source records include newly revised
Chimera/Sluice and older compiler papers; no external benchmark reproduced.

Latest carried 8B diagnostic: context 32, 32 blocks, one CPU pass, shared n=1;
total 230.5 s, prove 191.7 s (nested witness 17.3 s / load 14.3 s), fresh
verify 43.4 s (load 14.0 s included), 471,285,072 B. Serialization, startup
fraction and steady slope are unisolated; review/privacy acceptance pending.
One next-token proof is not a decode stream.

New target proofs/passes/positions: **0/0/0**, device none. Target steady and
total rates, startup fraction, witness/proof/serialization/verification clocks
remain unmeasured. No prefill, resident series or decode ran. Larger workloads
remain allowed; longer context can increase attention quadratically.
Complete private 8B >=50/s remains unachieved. Only research files changed;
no mask or opening reuse.

[Dated report](progress/20261019T101854Z-3562a78f.md). Saved reports do not establish delivery.
