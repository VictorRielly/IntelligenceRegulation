# ZKP efficiency progress

Cycle0080 — `20261019T121854Z-575be12a`, 2026-10-19 UTC.

**Compiler storage improvement; no proving speedup measured.** Generated D
coefficient code with runtime parameters and the unchanged native field lowers
the CPU caller's local stack allocation **1,160→360bytes**. Arithmetic and884
Fp2 calls are unchanged; caller instruction count rises slightly. All59
original tables/folds/finals remain. This compares unintegrated prototypes,
with non-inlined Fp2 adapters; GPU allocation and enclosing timing remain open.

Six synthetic fixtures pass:780 coefficients,390 captured-Rust grid/78off-grid
values,18 messages,354 original finals,six final relations; seven controls
and2,372 independent audit checks. Main3.807s including compiler1.055s;
audit1.005s,one Core Ultra9 185H CPU thread. The first signed-base conversion
bug was caught and corrected. Fully inlined native compilation exceeded40s;
that negative and the successful separate-call arm are both saved.

[Experiment](experiments/dzc-static-runtime-20261019/README.md) and
[unapplied handoff](handoffs/20261019-dzc-static-runtime.md).
Next: helper-group functions that reduce scalar calls while bounding compiler
cost and preserving low lifetimes, at SC_DZC / SumcheckRounds.

Carried8B diagnostic: T128,32blocks,one16-thread CPU pass,GPUoff;
total471.580s,proof region370.137s including witness94.021/load17.408s;
seal101.279s,receipt922,711,264bytes,D44.833s. Deleting ALL D caps only that
CPU diagnostic at1.105x,not a candidate/GPU prediction. Fresh verification
34.587s plus loading11.599s. Serialization,startup fraction and steady slope
remain unisolated. Researcher checked logs/pins,not receipts.

Eight LIVE primary records include new RS-commitment and memory leads,older
scheduling and current GitHub design/releases. Exact dates,licenses and
access failures saved; no foreign benchmark reproduced.

New target proofs/passes/positions **0/0/0**, device none. Target context,
steady/total rates,startup fraction,witness/proof/serialization/verification
unmeasured. No prefill,resident series or decode ran. Larger workloads allowed;
attention can grow quadratically. Complete private8B >=50proved positions/s
remains unchanged and unachieved. Only research files changed; no mask reuse.

[Dated report](progress/20261019T121854Z-575be12a.md). Saved reports do not establish delivery.
