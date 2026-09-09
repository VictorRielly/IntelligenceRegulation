# ZK60 milestone map

**Required scope:** the first PoC (P1) hides inputs, outputs and intermediate
activations; weights may be public. The full version (P3) also hides weights.
Victor reaffirmed this on 2026-09-09. These are requirements, not claims of
current acceptance. [Canonical privacy requirements](ZK60_PRIVACY_REQUIREMENTS.md).

**2026-09-09, round 21:** the [history audit](ZK60_ROUND21.md) confirms this
scope was already explicit in September 4 documentation and code. The
P1/P3 declarations and private endpoint preparation/policy serializer remain
unchanged at their original source sections; recent pushes introduced no
public-IO switch. Six current Rust IO tests and sixteen saved-receipt process
cases pass. Eight actual IO CFS channel checks, seven Python tests and 72
corruption controls also pass, within the fixed-challenge scope.

The immediate gate remains P1's private IO/activation transcript composition,
including the caller-fixed endpoint simulator model, followed by private
attention and a tiny block. O8's joint message review remains pending.
Whole-proof privacy acceptance is still open; P3 weight privacy follows for
the full version. The earlier entries below retain their historical scope.

**2026-09-09, round 20:** exact opening checks pass on all four round-19
captures: 18 private PCS owners and four shared eight-slot M openings.
The [conditional construction](ZK60_ROUND20.md) preserves pad vectors and
sampled columns together, including M's shared q/proximity blinders.
**35 Python tests and 22 real-capture numerical rejection controls pass.**
There is no production protocol change or new disclosure finding.

O8's joint message/alias analysis remains pending. Codex next combines it with
the CFS and opening channels under the actual transcript, including the
caller-fixed endpoint roots; then private attention and the tiny block.
Full IO zero-knowledge acceptance remains open. Earlier entries retain their
historical scope; the minimal maintained core remains priority 3.

**2026-09-09, round 19:** Opus O7 is integrated and its fourteen source
hashes verified. `1f0ff36` adds full-acceptance-only IO capture/replay: four
source-pinned captures with complete M/A/H/private-W/endpoint observations and
saved receipts. **227 Rust tests, 157 Python tests, six separate-process receipt
verifications, 64 ingestion controls and native freeze-check pass.**
[Round 19](ZK60_ROUND19.md) records the evidence and the corrected fixture-path
retry. The release transcript and receipt format are unchanged.

[Opus O8](ZK60_OPUS_QUEUE.md) now analyzes these captures with the inherited
linear model and explicit exclusions. Joint IO privacy acceptance, private
attention and the complete block remain open. Codex retains the CFS/column/
adaptive-transcript argument and protocol changes; the minimal core refactor
remains priority 3. Earlier dated entries below are historical.

**2026-09-08, round 18:** the repaired FFN now proves equality to independently
committed private input/output endpoints. After O6, `137b109` consolidates all
eight mask slots into one commitment and delays every opening until both
equalities are complete. **227 Rust tests, 227 affected Python tests, 56 process
checks, all four frozen CPU proofs and native freeze-check pass.**
[Round 18](ZK60_ROUND18.md) records the implementation and evidence.

Opus O5/O6 are integrated in `ea3d886`; [O7](ZK60_OPUS_QUEUE.md) reviews the
actual `/2` IO profile. Codex next handles the joint IO observation analysis,
then the remaining private attention construction and a tiny complete block.
A complete private block, registered private model binding and full privacy
acceptance remain open. The minimal core refactor remains priority 3.
Earlier dated entries below retain their historical scope.

**2026-09-08, round 17:** the repaired FFN can now be saved and verified in a
separate process in both modes. Source `29d3436` passes 220 Rust tests and all
21 process checks. Opus O1–O4 are integrated through `2fb7e0a`; all 69 new review
tests and 57 legacy joint tests pass. The linear model reports A/W disclosure 0
and only H's public LogUp identity; excluded transcript channels still require
review. All 213 affected Python tests, four CPU frozen proofs and native
freeze-check pass. [Round 17](ZK60_ROUND17.md) records the evidence and limits.

Codex next binds the repaired FFN to specified input/output endpoints, then
implements the private attention requirements and composes a tiny block.
Registered private model binding and full privacy review remain unfinished.
Opus continues with [O5/O6](ZK60_OPUS_QUEUE.md); core extraction stays priority 3.
The older status entries below are historical snapshots.

**2026-09-08, round 15 integration:** Fable's FA6–FA9 analyses, CL21 tooling
and corrected typed FFN/core extraction are integrated. Source `612ff9c`
adds CFS refusal guards, a public int8 registration constructor and fixed norm
limb guard, live-checkout validation, and suite v6 for the 32-test core plus
215 storage-enabled hashline tests. **247 Rust tests, 564 tooling tests,
189 device checks, all 12 frozen proofs, B4 reproduction and B5 verification
pass; all 24 suite-v6 cases are green.**
[Round 15](ZK60_ROUND15.md) and [current Fable queue](ZK60_FABLE_QUEUE.md).

Next: checked repaired-mask generation and versioned FFN/capture integration;
Fable reviews the actual schedule and attention channels while continuing the
lower-priority complete FFN extraction. Conditional construction analyses are
available, but the repaired private proof, authenticated stable P3, private
blocks and complete maintained ZKP path remain open.

**2026-09-08, round 14:** local stable-weight registration now joins
protected material, the durable counter, an external key callback and reserved
material access. Fable's PCS extraction is integrated into the maintained core;
`df7fb0d` also fixes journal lock cleanup during concurrent process startup.
**219 Rust tests, 343 tooling tests, 189 device oracle cases, all 12 frozen
CPU/GPU/chunk proof comparisons, B4 exact reproduction and B5 verification pass.**
See [round 14](ZK60_ROUND14.md) and the
[registration contract](ZK60_STABLE_WEIGHT_REGISTRATION.md).

Fable's next typed-decoder commit is held for three reproduced robustness and
compatibility findings; see the [review](ZK60_CL20_ROUND14_REVIEW.md). Fable
retains FA6–FA9, CL21 and lower-priority CL20. Codex next reviews those deliveries
and continues the reviewed layout generator plus authenticated approval/key
provisioning, followed by the versioned prover/verifier and private blocks after
privacy/arithmetic closure. H2, approved stable P3 and full CL20 remain open.

**2026-09-08, round 13:** Codex implements protected stable-weight
registration material and exact CPU commitment reconstruction in `ccc6f26`.
**202 Rust tests, four frozen CPU proof artifacts and public B4/B5 receipt
checks pass.** [Implementation and evidence](ZK60_ROUND13.md).

The opt-in [material store](ZK60_STABLE_WEIGHT_MATERIAL.md) binds encryption to
the trusted slot policy and expected row roles. Default builds and `zkp-core`
exclude its encryption dependencies. Fable retains FA6–FA9, CL21 and remaining
CL20 work. Next: reviewed arithmetic/core integrations, H2 registration/layout
and key-custody orchestration, then the repaired slot-consuming prover/verifier
once the privacy review closes. H2, approved P3 and private blocks remain open.
[Current handoff](ZK60_FABLE_QUEUE.md). Earlier dated entries retain their scope.

**2026-09-08, round 12:** Codex fixes typed attention extra-message
acceptance (`42471f0`) and implements the durable public slot journal for
FA4 H2 (`72a884e`). Final source `972da4e` passes **191 Rust tests, all four
frozen CPU proof artifacts, exact B4 reproduction and separate-process B5
verification**. [Implementation and evidence](ZK60_ROUND12.md).

Fable retains FA6–FA9, CL21 and remaining CL20 extraction. R32 has an
implementation for independent review; R09/R10/R31 remain open. The
[slot journal](ZK60_STABLE_WEIGHT_SLOTS.md) persists spent reservations before
exposure but stores no secrets and enables no stable P3 proof. H2 completion,
the privacy repair and private blocks remain open. [Current handoff](ZK60_FABLE_QUEUE.md).
Earlier dated entries below retain their original validation scope.

**2026-09-08, round 11:** Codex implements verified A/H/P3-W capture and
replay, integrates Fable through GPU `5949b38` and privacy review `46608bb`,
and moves seven canonical CPU primitive modules into a working `zkp-core`
crate. Source `c8a342f` passes **178 Rust tests, 546 Python/native tests
(zero skips), 189 executed GPU oracle cases and all 12 frozen proof gates**;
cache parity and public B4/B5 receipts also pass.
[Implementation, evidence and limits](ZK60_ROUND11.md).

**Next:** [FA6–FA9, CL21 and the remaining CL20 work](ZK60_FABLE_QUEUE.md).
FA3 delivers a candidate mask schedule, but its joint CFS masking and full
transcript arguments remain open. No repaired FFN, private block or private
two-block proof is claimed. PCS/FFN/codec extraction continues from the
[implemented primitive boundary](../../zkp-core/MIGRATION.md); the full
minimal ZKP subproject remains incomplete. The dated entries below retain
their historical statuses; this update supersedes their pending GPU/capture
and design-only core statements.

**2026-09-07, round 10:** CL19 actual proof-size accounting is implemented
and validated: **156 Rust tests, 39 Python profile/benchmark tests, all four
unchanged frozen CPU proofs, exact per-layer byte totals and P3 profiling
on/off byte parity**. [Closure and continuation](ZK60_ROUND10.md). The next
Codex step is public-only H/P3-W opening capture to support the independent
joint privacy review. GPU integration, privacy repair and private-block
composition remain open; `zkp-core` is still a lower-priority design scaffold.

**2026-09-07, round 9:** [the latest review](ZK60_ROUND9_REVIEW.md) pins
lane `3ad4d97`, credits the successful archived `82314a1` GPU gate (12 byte
cases, 49 oracle cases), and reruns 215 CPU tool tests. H1 was merged after
that run and the cache fix still needs lane pickup; final combined validation
remains open. [Fable's next queue](ZK60_FABLE_QUEUE.md) has 14 concrete tasks,
including independent privacy review and a lower-priority maintained
[ZKP core subproject](../../zkp-core/README.md). That subproject currently has
only its design scaffold. No new private-protocol or throughput acceptance.
**2026-09-06, round 8:** the public-weight cache now publishes through
exclusive per-writer files, fixing concurrent lost saves and partial-entry
exposure. ZK v3 reports cache activity. **151 Rust tests, 144 Python/native
tests with zero skips, frozen proof compatibility and cold/warm full-byte
cache parity pass**; [round 8](ZK60_ROUND8.md) records final-stage provenance.
The [latest Claude review](ZK60_ROUND8_CLAUDE_REVIEW.md) pins `a1aa2b7`,
credits the corrected earlier findings and adds CL6/CL7/CL11 follow-ups.
The twice-deadlocked floor launch must use only the outer heavy lock.
Round-7 source is pushed as `3ff8d5f`, and reviewed tasks as `a0495dc`.
The independent privacy audit/repair and final GPU integration gate remain open.

**2026-09-06, round 7:** [actual FFN diagnostics](ZK60_FFN_MASK_DIAGNOSTIC.md)
now reproduce the suspected privacy defect in verified P1/P3 proofs, including
fresh OS randomness: complete tiny X/h16 recovery at T2 and per-column
linear-functional disclosure at T32. The test-only observer changes no
production protocol; independent joint privacy review and the repair remain
open. **147 Rust tests, the 63-test library suite at sixteen test threads,
four frozen CPU artifacts, B4 parity and separate-process B5 verification
pass. All 144 Python/native tests pass with zero skips.** See
[round 7](ZK60_ROUND7.md) and [exact evidence](../../results/zk60_round7_validation.json).
The H1 fixture configuration race is fixed through process isolation. Updated
[CL1 review](ZK60_CL1_INTEGRATION_REVIEW.md) and
[CL5/CL9 follow-ups](ZK60_CL5_CL9_REVIEW.md) and [CL8/CL10 review](ZK60_CL8_CL10_REVIEW.md)
pin `39272d6`; the newer CL3/CL4 response `c346236` has also been reviewed,
including a reproduced embedded-parser syntax error that holds its final gate.
The `9b24975` planner response fixes capacity/return lifetimes and passes 25
CPU tests; an unreachable warm-pool fallback remains in the queue.
Later concurrent work remains outside those reviews. The historical snapshots below
retain their original counts and writing-time status.

Round-6 update: [B5](ZK60_PUBLIC_CHAIN.md) implements an independently verified
**two-block public chain**, including actual residual continuity and request/
ordered-model binding. **143 integrated Rust tests, 144 Python/native tests
(zero skips), four frozen CPU artifacts and separate-process byte verification
pass.** Exact evidence: [round-6 validation](../../results/zk60_round6_validation.json).
The [Claude/Fable review handoff](ZK60_PARALLEL_ROUND6.md) is pushed as `606a24e`.
Claude's committed `6e28b6f` fixes strict off/twiddle behavior and adds late
allocation fallback, but reviewed CL3/CL4 follow-ups still hold integration.
[Fable's priorities](ZK60_FABLE_QUEUE.md) now include precise real-FFN mask-group
hypotheses; no new real-FFN disclosure diagnostic was implemented or executed.

The snapshot below also retains round-4/5 evidence; round-6 closure supersedes
its counts. The target and privacy limits are unchanged.

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
| Public two-block byte receipt | [B5](ZK60_PUBLIC_CHAIN.md): 4,290,981 bytes, actual residual continuity, independently ordered contracts/context/external tensors and separate-process bounded verification. Genuine inconsistent constituent proofs and fresh boundary mismatches reject. | Exactly two T32/d16/f16 **public** blocks. Not private composition, recursion, trained-model generation or target-eligible throughput. |
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
| Whole-profile privacy and identity | **Fable: independent review remains outstanding**, [F1 brief](ZK60_EXECUTION.md#f1--task-for-fable-prove-which-model-ran); Codex's [actual FFN diagnostic](ZK60_FFN_MASK_DIAGNOSTIC.md) now reproduces the tiny/T32 cases. | Audit actual joint opening groups, masks, proximity vectors, functionals, challenge order and reuse. Resolve the demonstrated core FFN defect and determine all affected profiles. For P3, specify and test consistency between fresh private W roots and independently approved stable model identity. |
| One complete private block, then two | **Codex: after reviewed privacy/interface prerequisites**, [private-block tasks](zk60_private_block_tasks.json). | Implement pending attention/FFN ownership, private lookup/norm/attention relations and both internal seams on the **actual** commitments. Reserve all masks before commitment and open once. Establish integer/range/no-wrap obligations; then test two-block residual linkage with freshly rebuilt adversarial witnesses. |
| Complete generated-response relation | **Codex: subsequent coverage gate**, [execution milestones](ZK60_EXECUTION.md#c1-and-subsequent-milestones). | Bind all layers, embedding, final norm/head, token selection and request/model/calibration state. Prove position/KV/window transitions and the chosen generation/receipt policy; report generation time, proof readiness and post-generation proof lag separately. |
| Bounded-memory GPU execution | **Claude/Fable: archived `82314a1` gate reviewed at `3ad4d97`; final combined gate pending.** [Round-9 review](ZK60_ROUND9_REVIEW.md) credits 12 byte and 49 oracle cases. | Complete CL13–CL16 input/boundary fixes and CL17 on the current combined source, including atomic cache/H1 and round-10 telemetry. Earlier parser/reuse findings are superseded as recorded. No full-model/target-clock acceptance follows from component gates. |
| Target measurement | **Codex integration + Claude hardware evidence: pending.** | Complete supported relation and reviewed security, named-device memory headroom, stable model/calibration, independently decoded verification, and the statistical clock below. No 5090 benchmark has been recorded in this work. |

B4 follow-ups, Fable's review and Claude's bounded-memory lane can proceed
independently under the declared file ownership. B4 remains public; a
public codec does not solve private composition. P1 can start with approved
public weights without waiting for P3's private-model consistency construction,
but **cannot skip the shared privacy audit**. A copied plane plus an S2 equality
receipt is not a replacement for a link to the arithmetic commitment.

The singleton-mask defect now has actual FFN evidence at the tested tiny/T32
profiles, not a completed impact assessment of every FFN group. The independent audit and
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
