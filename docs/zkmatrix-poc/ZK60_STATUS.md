# ZK60 milestone map

Snapshot: round 4 is committed and pushed as `5657a8d`, with the concurrent
board-only handoff `2c88e4a` preserved. [Round 5](ZK60_PARALLEL_ROUND5.md)
has validated verifier hardening, Python fixture repair and CL1 review; the
[expanded Claude queue](ZK60_CLAUDE_QUEUE.md) has ten substantive tasks.
The public receipt is byte-verified in
a separate process and all four frozen CPU compatibility gates pass.
**We have a verified tiny public transformer block and useful private-proof
components, not a complete private LLM proof or a 60-tokens/s result.**
This map separates passed gates from proposed or currently executing work.

## Achieved, with limits

| Milestone | Evidence now available | Boundary |
|---|---|---|
| Foundations and honest measurement | [C0](ZK60_EXECUTION.md): fresh OS randomness by default, explicit insecure fixture seeds, unsupported privacy-command refusals, proof-ready clocks and benchmark validation. [Round 1](ZK60_PARALLEL_ROUND1.md): exact integer oracles, opt-in approved P1 FFN boundary and component memory planner. | Randomness and byte parity do not certify privacy. Existing CLI paths do not automatically acquire the opt-in approval boundary. The blocked CPU matmul experiment was **not** promoted. |
| Fixed block metadata and integer execution | [A00](ZK60_BLOCK_CONTRACT.md) pins approved weights/gamma, constants, scales and shape. [E1](ZK60_CAUSAL_ORACLE.md) executes attention, both norms/residuals and FFN without input-dependent fitting. | T32/d16/f16 only. Metadata preflight is not a no-wrap certificate. Same-T32 future-suffix tests are not variable-length or KV-cache equivalence. |
| Actual public one-block proof | [B3](ZK60_PUBLIC_BLOCK.md) verifies both internal FFN X/Z seams and independently approved W/gamma roots. Freshly recommitted mismatches reject. Payload: **2,137,764 bytes**, excluding wrapper framing. | **P0 only**: the immutable P1 contract is reused as metadata, not accepted as a private proof. B3 has no external input/output linkage, complete decoder or two-block proof. Its checked short-W subcube adapter is specific to this public tiny profile. |
| Standalone experimental private equality | [S2](ZK60_PRIVATE_SEAM.md) has fresh paired masks, one-shot ownership, bounded framing and a separate-process byte-verifier demonstration. | It proves equality at standalone commitments, not provenance from actual attention/FFN arithmetic. It is **not integrated private-block composition** or a complete security theorem. |
| Executed schedule and composition design | [A01](ZK60_ATTENTION_SCHEDULE.md) records actual public attention metadata and preserves on/off proof bytes. [A03](ZK60_PENDING_FFN.md) specifies pending ownership, mask reservations and finalization; layout/count tests pass. | A01 does not observe challenge coordinates, PCS group rank or FFN internals; cross-layer coverage is a synthetic hook replay. A03 is a **reviewed interface proposal**, not an implemented pending private prover. |

The round-5 integrated gate passed **129 release Rust tests, 144 full Python/native
tests (zero skips) and four unchanged frozen CPU proof artifacts**. These are compatibility
and tested-correctness results, not whole-profile security certification.
Exact commands, source hashes and results:
[round-5 validation](../../results/zk60_round5_validation.json),
[round-5 handoff](ZK60_PARALLEL_ROUND5.md). The native export-path failures
are repaired; all six fixture-dependent methods passed, including both
previously skipped two-layer smokes. The full CPU suite took 921.316 s with
two threads, maximum reported RSS 1,707,192 KiB and no swaps. Concurrent
Claude CL8 tests added after discovery are not part of that count.

## Next gates and owners

| Gate | Owner / current state | Evidence required to advance |
|---|---|---|
| B4 externally bound public receipt | **Acceptance passed**, [round-4 handoff](ZK60_PARALLEL_ROUND4.md). Complete 2,144,946-byte receipt verifies in a separate process and retains its full hash after round-5 H1. | Actual input/output/context linkage, internal seams, approved roots and bounded decoding are exercised. H1 now explicitly refuses zero lookup denominators in all three related verifier paths. Wider typed-input/resource/deployment hardening remains; this is not a production service or private proof. |
| Whole-profile privacy and identity | **Fable: independent review remains outstanding**, [F1 brief](ZK60_EXECUTION.md#f1--task-for-fable-prove-which-model-ran); Codex supplies diagnostics and implements only reviewed changes. | Audit actual joint opening groups, masks, proximity vectors, functionals, challenge order and reuse. Resolve the diagnosed singleton-mask hazard at the actual supported profiles. For P3, specify and test consistency between fresh private W roots and independently approved stable model identity. |
| One complete private block, then two | **Codex: after reviewed privacy/interface prerequisites**, [private-block tasks](zk60_private_block_tasks.json). | Implement pending attention/FFN ownership, private lookup/norm/attention relations and both internal seams on the **actual** commitments. Reserve all masks before commitment and open once. Establish integer/range/no-wrap obligations; then test two-block residual linkage with freshly rebuilt adversarial witnesses. |
| Complete generated-response relation | **Codex: subsequent coverage gate**, [execution milestones](ZK60_EXECUTION.md#c1-and-subsequent-milestones). | Bind all layers, embedding, final norm/head, token selection and request/model/calibration state. Prove position/KV/window transitions and the chosen generation/receipt policy; report generation time, proof readiness and post-generation proof lag separately. |
| Bounded-memory GPU execution | **Claude: CL1 delivered; integration held after source review.** Observed tip `c9fc897` adds the pooled-memory correction to `15eeda6`; source is unchanged. Existing hardware log reports 12 byte gates, six GPU oracle tests, 105 crate tests and both builds. [Review findings](ZK60_CL1_INTEGRATION_REVIEW.md) queue CL2/CL3/CL4 before merge. | Resolve deferred-opening twiddle state, strict off-mode semantics, complete bounded allocation fallback, double-counted NTT time and non-vacuous GPU-required tests. These are source-inspected, not independently GPU-reproduced. One-layer RTX 4070 Laptop times remain single-run diagnostics, not full-model or target-clock results. |
| Target measurement | **Codex integration + Claude hardware evidence: pending.** | Complete supported relation and reviewed security, named-device memory headroom, stable model/calibration, independently decoded verification, and the statistical clock below. No 5090 benchmark has been recorded in this work. |

B4 follow-ups, Fable's review and Claude's bounded-memory lane can proceed
independently under the declared file ownership. B4 remains public; a
public codec does not solve private composition. P1 can start with approved
public weights without waiting for P3's private-model consistency construction,
but **cannot skip the shared privacy audit**. A copied plane plus an S2 equality
receipt is not a replacement for a link to the arithmetic commitment.

The inherited singleton-mask diagnostic is a concrete interface hazard, not a
completed impact assessment of every FFN group. The independent audit and
field-to-integer/no-wrap obligations remain open; do not use experimental
private paths for sensitive application data on the strength of passing tests.
See [round-2 findings](ZK60_PARALLEL_ROUND2.md#findings-that-change-priorities).

## What the current CPU measurements tell us

[P2's nine one-layer 125M FFN samples](ZK60_PROFILE_SWEEP.md) cover P0/P1/P3,
16/32/64 rows, two CPU threads and no model weight cache. Uncached weight
commitment was the largest phase in every sample: **348–452 ms**. Witness
preparation was **23–54 ms**; exclusive attribution left less than 0.078%
unknown inside proof readiness. This supports measuring commitment work next
for that workload; it is not evidence that a 5090 has the same bottleneck.
The samples are noisy, page-cache state is uncontrolled, and they contain
neither full attention nor generated tokens. They do not justify multiplying
old speedup factors or extrapolating a microbenchmark to 8B/30B throughput.

[M1's 13,492 MiB count](ZK60_PARALLEL_ROUND1.md#m1-initial-allocation-result)
is a **single cold-pool P3 W-commitment component** at width 4096/f14336,
not measured peak VRAM or a whole-prover safety bound. Pending attention/FFN
states add overlapping lifetime costs. Claude must account for those before
scaling; nominal card capacity does not authorize a large run.

## The target clock, without a coverage shortcut

The first agreed engineering milestone in
[the execution contract](ZK60_EXECUTION.md#acceptance-target-and-current-limits)
is calibrated 8B-class, 512 prefill rows, one GPU, with P1 and P3 separated:
**512 / 60 = 8.533333 seconds** from input/witness preparation through serialized
proof readiness. That arithmetic is meaningful for the target only with the
required model/operation coverage and reviewed privacy/soundness; proving 512
exported FFN rows alone does not establish it. A 30B model is a follow-on.

Publication requires at least 20 warm runs on an idle named machine, separate
cold evidence, p50/p95, proof bytes, decoded verification time, host/device peak
memory, driver/toolkit/power settings and explicit inference/proving overlap.
Inference on a second uncounted GPU is not a one-GPU result. Existing proof-size
and verifier budgets remain obligations, not automatically amended by speed.

Sixty prefill rows/s, delayed completed-sequence receipts and each token proved
before release are different products. Keep the release/proof-lag requirement
explicit and never substitute one clock for another. Hardware preparation can
use the [5090 runbook](BLACKWELL_5090_RUNBOOK.md), but its historical scaled
columns are models, not current measurements or a promise of reaching 60/s.

This status is based on local handoffs and correctness artifacts, not new
target benchmarking.
Older document headers that say “uncommitted,” “pending integration,” or that
Claude is still finishing a task describe their writing time; the stated base
and latest explicit handoff control this snapshot. Preserve the distinction
between validated working-tree work and committed, reviewed integration.
