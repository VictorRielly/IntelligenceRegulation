# ZKP efficiency progress

Cycle 0055 — `20261017T052624Z-c8881557`, completed 2026-10-17 UTC.

**No native speed improvement established.** A fixed first-round softmax sumcheck evaluator passed 2,790 synthetic schedules over 93 fixtures, 28,650 independent round samples, 67,770 final values and 192 extension checks. Five mutation controls caught errors, including an invalid temporary overwrite. The final run took 13.14 seconds and 26,948 KiB RSS on one low-priority CPU thread.

The fixed body preserves the previous 7.0153% reduction in scoped field calls versus prepared scalar at full-head T512. It removes dynamic width tests from the research prototype; it establishes no additional saving in the native scalar prover. The lifetime audit finds 20–23 live field temporaries (320–368 logical bytes). Four output coefficients occupy 64 bytes but do not describe peak scratch. Native spills, registers and enclosing time remain unknown.

Generated Rust helpers and a review handoff are saved for SC_SZC in `argument.rs` and the row/part/sample loop in `grouped.rs`. They use research-port indices and remain uncompiled. Native layout mapping, masked/refusal/RNG/PCS/privacy and independent-verifier gates remain for the owner. Next local experiment: use a public clause-streaming order to shorten lifetimes without extra field calls. No build, GPU job or merge occurred.

LIVE searches covered the September quantization and October 15 Range papers, older private matrix lookup, VeriLoRA CUDA softmax and DeepProve setup/license history. Findings distinguish utility simulation, inference caching, projections and proof measurements. Six source records were appended, bringing the ledger from 276 to 282. Exact dates, licenses, the inspected commit and access errors are retained. No author performance or security result was reproduced. PDF/history/source fetch failures did not block local work.

[Experiment](experiments/fixed-round0-factory-20261017/README.md) and [handoff](handoffs/20261017-fixed-round0-factory.md) retain commands, seed, source hashes, dimensions, controls, costs and limits. Initial missing-import and stale-oracle-constant failures are preserved; corrected runs pass. The independent AST/integrity audit passes 25,986 checks. All 11 native/measurement pins match, and owner memory files are unchanged. This audit is not a native proof gate.

Accepted independently verified complete private 8B proofs/passes/tokens: **0/0/0**. Proof context length: unmeasured (null). Device: Intel Core Ultra 9 185H CPU only, one thread, nice 19, CPU0 affinity. Steady-state and total-workload rates, startup duration/fraction, witness/proof/serialization/independent-verification clocks, proof latency/lag/drain: **all unmeasured**. No long-context prefill, resident-model pass or decode proof ran. Synthetic schedules use at most 16 cells. T512/T1024 arithmetic is allocation-free accounting, not a profile or proof; doubling context produces roughly four times the attention work. Larger workloads remain permitted with complete coverage and fresh masks. The >=50 proved-token/s target is unchanged and unachieved.

Production, runtime, Git, calibration, safety gates and reviewer files were untouched. No installation, external write/message or heavy job was queued. Saved reports do not establish delivery or supervisor liveness.
