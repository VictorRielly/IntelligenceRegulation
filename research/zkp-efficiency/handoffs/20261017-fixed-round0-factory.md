# Review handoff — fixed unpadded first-round SC_SZC factory

Cycle 0055, run `20261017T052624Z-c8881557`, 2026-10-17 UTC.

**Arithmetic candidate only; no native proving-time gain.** A fixed factory retains the previous 7.0153% scoped field-call reduction versus prepared scalar at hp32/kv8/qh32/T512 with three limbs. Field-call counts match the dynamic cubic prototype exactly. This cycle removes prototype width/tag dispatch and exposes temporary lifetimes. The 159,383,552 removed prototype width tests are not native savings.

Interface: `factory(values, differences, constants, offsets) -> [coefficient; 4]`. Group0 only, unpadded first round, at least two rows. Constants contain current alpha, beta, g_exp and mu. Offsets are `alpha - (lookup_constant + current_tag)`, formed once within that proof. Public mask dependencies select constant or moving-mask code before row evaluation. Only immutable public layout/axis metadata selects a body. No private-value or degree pruning; no masks, offsets or openings cached across proofs.

Research files under `experiments/fixed-round0-factory-20261017/`:

- `generate.py`: locally authored expression compiler and last-use emitter.
- `fixed_factory.py`: proof-local adapter to the retained grouped synthetic driver, with a hoisted offsets tuple.
- `generated/ls3-lk15-mask0.rs` and `ls3-lk15-mask1.rs`: review-only Rust helpers. **Uncompiled, using research-port indices.** Native owner must map captured `im/idx/imx/isum/h0/ihx` indices to the public layout; do not copy numeric port indices as native indices.
- `generated/*-recycled.py` and liveness JSON: executable fixed-slot references and auditable logical schedules.

The actual native seam is candidate `hashline/src/private_block/argument.rs:1699` / bracket closure1788, and `zkp-core/src/sumcheck/grouped.rs:93` through row/part/sample accumulation and recovery132. Candidate and sonnet-hardening argument/grouped hashes match; root main differs. Source snapshots and 11 checked native/measurement pins are retained. No Git operation occurred.

Integration needs an optional coefficient callback, suffix weighting of four coefficients, reduction, then evaluation at original 0/1/2/3. Retain the original five outer samples. Hosted groups and later rounds use prepared scalar. Preserve running claims, zero-factor fallback, pending values/finals and fold order. This is a reviewable arithmetic helper, not a production patch.

Validation: 2,790 synthetic schedules / 93 fixtures; 28,650 independent round samples, 67,770 finals and 192 arbitrary-extension checks. There were 996 recoveries and 1,092 fallbacks. All 24 generated bodies have no AST loops/branches; 48 executed field-operation censuses and 1,116 schedule counter comparisons agree. Five mutations catch dropped/reversed coefficients, a wrong sign, wrong mask dependencies and premature live-slot overwrite; three padded factories refuse. Final run: 13.144796 seconds, 26,948 KiB RSS, one nice19 Core Ultra 9 thread, seed2026101755, 59s/512MiB caps. Independent register-use/integrity audit: 25,986 checks pass. Commands, hashes, logs and initial import/oracle failures are retained. No native constructor, transcript, RNG, PCS or verifier was executed.

For three limbs / 15 lookups, the constant-mask factory uses 393 field calls and 20 live logical temporary results (320B); moving mask uses 419 calls and 23 temporaries (368B). Output64B is not peak scratch. Read-only inputs/constants/offsets, caller accumulators/equality and native API internals are excluded. Native registers, spills, stack, occupancy, code size, transfers and enclosing time remain unmeasured. Prior 7.0153% arithmetic scope omits common equality/fold/PCS/witness/mask work. Round0 recurs every proof, not at startup.

Owner gates before promotion: native independent oracle at every intended layout; accepted/refused challenges and masked/unmasked messages; original Fiat–Shamir/RNG continuation; group finals/claims; PCS/fresh verifier and corrupt/refusal controls. Preserve P1/P3 and pending profile/privacy gates. D24 remains proposed. Then guarded literal/prepared/fixed timing with affected and enclosing clocks, both recurring witness paths, peak host/VRAM and complete resident workloads, fresh masks, startup fraction, serialization, independent verification and drain. No heavy job queued; no merge here.

Falsify on any native value/refusal/RNG mismatch, or if added register/spill/dispatch/weighting costs erase enclosing savings. Complete8B ceiling is unknown. Erasing all SC_SZC would remove only 28.317% of the cited 27.523873-second synthetic125M diagnostic; that is not a model-scale estimate.

Next local question: can a public clause-streaming schedule lower the 20–23 logical temporary peak to <=16 without extra calls or changed outputs? Generate another schedule over the same DAG, validate independent values/counters/last uses, and retain a negative result if it fails. This target is a hypothesis, not an obtained improvement.

Accepted independently verified complete private 8B proofs/passes/tokens: **0/0/0**. Proof context length: unmeasured (null). Device: Intel Core Ultra 9 185H CPU only, one thread, nice 19, CPU0 affinity. Steady-state and total-workload rates, startup duration/fraction, witness/proof/serialization/independent-verification clocks, proof latency/lag/drain: **all unmeasured**. No long-context prefill, resident-model pass or decode proof ran. Synthetic schedules use at most 16 cells. T512/T1024 arithmetic is allocation-free accounting, not a profile or proof; doubling context produces roughly four times the attention work. Larger workloads remain permitted with complete coverage and fresh masks. The >=50 proved-token/s target is unchanged and unachieved.

[Full experiment](../experiments/fixed-round0-factory-20261017/README.md). No production/runtime/GPU/build/install/external action. Reports do not establish delivery.
