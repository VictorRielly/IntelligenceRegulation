# ZKP efficiency progress

Cycle0060 — `20261017T102624Z-c13de864`, completed2026-10-17 UTC.

**No native speedup established.** New linked TinyLlama T32 owner logs put
sealing/parity plus witness rebuilding at453.647/528.926s CPU(85.77%) and
457.911/545.079s GPU-assisted(84.01%). Matching fresh-verifier logs were inspected,
not rerun. These phases are recurring/input-dependent; startup is unsplit.

Tested exact int8/int32 projection helpers:200fixtures,17,820
independent dot checks,318,888 rounding checks and12controls.
Small C kernels including packing/widening ran3.12–7.72× faster in the tiled
arm; narrowing alone regressed strided IO. This is a synthetic CPU result,
not a native witness/proof speedup. Main run1.867s,
37,876KiB RSS,one nice19 CPU thread; audit145snapshot checks passed.

Six source calls are exact-int32 eligible; int16 FFNdown is not. An uncompiled
[Rust patch/handoff](handoffs/20261017-exact-witness-projections.md) preserves
full K and original quantize order. Next owner: native parity/refusal/bytes
and projection phase clocks against the new R3 path. **Concurrent owner source
drift makes the patch stale:** R3 already tiles/parallelizes and builds witnesses
once; no R3 verified timing was reproduced. Next local: new-path allocation/
lifetime census. Six LIVE source records appended, including
IntegerAlibi/CUTLASS and new AWE:65,536 exact pair checks pass, but six FP4
products are a poor theoretical baseline against native one-product INT8.

Accepted independently verified complete private **8B** proofs / passes / positions: **0 / 0 / 0**. Target steady-state and total-workload rates, startup seconds/fraction, witness/proof/serialization/independent-verification clocks, context length, proof latency/lag/drain: **unmeasured**. Local experiments: one Intel Core Ultra 9 185H CPU thread, CPU0, nice19, no GPU. Retained owner diagnostics: TinyLlama1.1B, T32,22 linked blocks, one CPU pass and one RTX4070Laptop-assisted pass (not resident repeats); shape privacy acceptance is absent. No long-context prefill, resident-model sweep or decode proof ran. Longer contexts increase dense-attention work approximately quadratically. Larger workloads remain permitted with fresh masks and all privacy obligations; the >=50 proved-token/s target remains unchanged and unachieved.

Research only; no native build/proof/GPU, install, production/runtime/Git or
external-message action. Saved reports do not establish notification delivery.
