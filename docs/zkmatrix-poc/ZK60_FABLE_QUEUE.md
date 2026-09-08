# Fable — next task queue, round 11

**2026-09-08:** Codex has integrated GPU lane `5949b38`, privacy-review lane
`46608bb` and core design `882f037`. The combined source `c8a342f` passes
178 Rust tests, 546 Python/native tests (zero skips), 189 device oracle cases
and all twelve frozen CPU/GPU/chunk proof comparisons. CL12–CL19 implementations
and FA1–FA3 analysis/design deliveries are credited below, not reassigned.
FA4's design and FA5's analysis remain distinct from enforcement/security
closure. [Round-11 review and continuation](ZK60_ROUND11.md).

**Pick up the performance branch first.** Actual H/P3-W observation capture
and public JSON export are now in `8b697b0`. `c8a342f` makes seven primitive
modules canonical in `zkp-core`; its 19 tests and public sumcheck example pass.
Keep that single implementation when continuing CL20. Neither the observer
nor the refactor repairs the disclosed privacy defect.

| Next task | Priority | Concrete delivery and acceptance |
|---|---:|---|
| **FA6 — CFS masking channel** | 0 | Review FA3 B1 against the actual CFS round messages, claimed sums, terminals and product-form mask opening together. Derive the conditional distribution or a concrete counterexample, enumerate every shared coefficient/function, and state precisely which mask specification is approved. Include both new seam slots and negative controls. A rank test of PCS vectors alone cannot close this task. |
| **FA7 — captured joint observations** | 0 | Consume the schema-1 A/H/W JSON captures and retain their proof/file hashes. Analyze individual terminal values jointly with group vectors and proximity, including shared X/h16 row identities and H's zero-sum relation. Codex's 30 per-column cases are a lower-bound subset, not this closure. Reproduce the actual Wd disclosure; deliver a parser/model test and a precise handoff for repaired-profile captures and predicate cases. |
| **FA8 — complete transcript and repeated-proof argument** | 0 | Address FA3 B2–B4 with an explicit simulator/conditioning argument, hash and entropy assumptions, failure/retry behavior, and the entire composition schedule. Treat fresh P1 and FA4's budgeted stable P3 W separately. List anything unresolved; no implementation or finite rank matrix substitutes for this review. Depends on the FA6 construction and FA7 observation inventory. |
| **FA9 — close arithmetic and registrar gaps** | 0 | Independently package FA5 R09's norm alias as a Rust adversarial test and propose the narrow verifier-enforced range fix, with fixed-profile and wider-profile classifications. Resolve R31's authenticated weight/gamma range premise, R10's actual limb width, and R32's extra typed-proof fields. Codex owns attention/contract fixes; provide exact patch/test proposals and update FA5's obligation table. |
| **CL21 — gate the extracted dependency** | 1 | Make the floors/preflight source identity include `zkp-core` and both lockfiles, and gate the core tests/example with an explicit suite version and expected cases. A dirty or missing core must refuse qualification. Preserve archived v1–v3 meanings. The round-11 outer validator hashes both crates; the current standalone floors manifest still only checks the `hashline/` delta. |
| **CL20 — continue the maintained core** | 3 | Start from the implemented primitive boundary in [MIGRATION.md](../../zkp-core/MIGRATION.md). Extract CPU PCS behind a narrow GPU adapter, then table/statement/witness/layout/proof pieces, the selected FFN path and bounded codec. Preserve compact/cache/GPU consumers and full frozen proofs; add actual old/new tiny FFN parity. A primitive or public-only example does not close the full task. |

FA6, FA7 and FA9 can proceed independently; CL21 can proceed alongside them.
FA8 can draft its structure but closes only against the reviewed construction.
Codex's next protocol work is the separately versioned repair and pending FFN
lifecycle once the required privacy review closes, then one private block and
two connected private blocks. P3 additionally requires implemented approved
model consistency. No full-model laptop or 5090 job is authorized by this queue.
Use two threads and the existing heavy/build-lock discipline. Keep one writer
per source boundary; no duplicate primitive implementation.

The matching [task records](zk60_fable_tasks.json) carry current statuses and
acceptance. The remainder of this file preserves **historical round-9 contracts
and writing-time status**. Do not restart completed CL12–CL19 or FA1–FA3 work
from a historical "ready" label below.

---

## Historical round-9 queue

**2026-09-07, round 10:** CL19 is implemented and validated by Codex; see
[the closure and continuation](ZK60_ROUND10.md). Pick up the current performance
branch when synchronizing CL12/CL17 so the combined gate includes this module.
CL13–CL18, the independent review and lower-priority CL20 retain their owners.

Victor requested the next task list on 2026-09-07. This is the pickup queue
for Fable's own session: **nine engineering tasks (CL12–CL20) and five
independent review tasks (FA1–FA5)**. CL IDs continue the existing Claude
GPU/tools lane; FA IDs preserve the independent privacy/identity assignment.
These are assignments, not claims that another session or reviewer ran them.

## Read this before pickup

Codex fetched and reviewed lane tip `3ad4d97ce4cb47b9eeeb76647a5a9159d15d2357`
against integrator baseline `44d72ffa5cb28d69bbedfa19d5f2a5026d9aa87a`.
The [round-9 review](ZK60_ROUND9_REVIEW.md) credits **12 archived matching
CPU/GPU/forced-chunk proof cases, 49 device oracle cases, both missing-feature
controls and 215 newly rerun CPU tool tests**. The archived GPU run was at
`82314a1`, before the H1 merge; it does not validate the final combined tree.
Codex performed no new GPU run. CL6/CL11 malformed-input probes still reproduce.

The atomic cache fix and ZK cache report are already validated and pushed in
`44d72ff`; adopt them. H1 isolation is already on the lane through `c84668f`.
Do not redo those fixes or replace the isolation with a broad configuration
refactor. The old nested-lock deadlocks and the JSON expansion bug have a
successful later run; the next gate is for the new combined source.

## Execution order and ownership

Start **CL12 → CL13 → CL14 → CL15 → CL16 → CL17**. CL18 follows that
validated baseline. CL19 is complete; FA1, FA4 and FA5 offer ready review work;
FA2 follows FA1, and FA3 follows FA2. Do not wait for hardware to do CPU
tooling or independent analysis. Final FA5 closure incorporates the repaired
construction. P1 can proceed after the shared privacy review without P3 identity.

**CL20 is Victor's lower-priority refactoring task:** establish the maintained
minimal [zkp-core subproject](../../zkp-core/README.md) while preserving the
existing experiments. Its design scaffold exists now; extraction follows
CL17 and must not displace the correctness/privacy work. A working library,
explicit support boundary and parity tests are required to mark it complete.

Continue the existing lane in its separate checkout. One writer owns
`gpu/cuda.rs`, kernels and PCS; planner ownership stays there too. Codex owns
`zk.rs`, attention/composition, verifier/receipt/CLI integration, shared boards
and the final performance-branch merge. New review documents and dedicated
tests can be prepared without touching another owner's partial source.
For shared instrumentation or serializer changes, deliver an exact patch/API
proposal to the owner before editing; the user has already authorized this
coordination and review work. Preserve the distinction between implementation
authorship and independent review, including named source/reviewer provenance.

Each task gets a separate reviewable commit/report with files, base/result
commit, commands, exits, actual cases, full hashes, memory units, limits and
status. Mark completed only against its acceptance checks. Update the matching
entry in [the machine-readable queue](zk60_fable_tasks.json); final shared-board
integration remains Codex-owned. Legacy CL2–CL11 task IDs are retained in
[the original Claude queue](ZK60_CLAUDE_QUEUE.md).

## Common gates

- Preserve legacy transcript/RNG order and full frozen proof bytes for CL work.
  A reviewed privacy repair needs its own explicit profile/domain boundary.
- CPU-first synthetic inputs; no sensitive application data before privacy
  closure. No full-model laptop job or 5090 launch is implied by this queue.
- Use two build/Rayon/prover threads and `flock /tmp/zk-heavy.lock` for heavy
  work. Detach runs expected over five minutes with distinct logs and exit
  markers. Do not hold `/tmp/zk-build.lock` outside a script that takes it.
- Preserve actual case/device evidence. Archived GPU results, new CPU tests,
  derived memory estimates and future acceptance gates are distinct records.
- Passing correctness tests does not establish privacy, complete generation,
  approved P3 identity, p95 performance or the 60/s target.

CPU-only review commands (run from the selected checkout):

```sh
python3 -m unittest discover -s tests -p 'test_hashline_cl_*.py' -v
python3 -m unittest discover -s tests -p 'test_hashline_memory_plan.py' -v
env CARGO_BUILD_JOBS=2 RAYON_NUM_THREADS=2 HL_GPU=0 flock /tmp/zk-heavy.lock cargo test --release --offline --manifest-path hashline/Cargo.toml --lib mask_diagnostic -- --nocapture --test-threads=2
env CARGO_BUILD_JOBS=2 RAYON_NUM_THREADS=2 HL_GPU=0 flock /tmp/zk-heavy.lock cargo test --release --offline --manifest-path hashline/Cargo.toml --test zk60_identity_gap -- --nocapture --test-threads=2
```

Use CL13's corrected portable runner for CL17. Its lock ownership must be
outer heavy lock only, with the build lock managed inside. The existing
script still hardcodes eight prover threads and a checkout path, so copying
its old command is not completion of the resource/portability task.

## Task contracts

### CL12 — Synchronize the lane and preserve exact validation provenance

Priority 0; **ready**. Owner: Fable / existing Claude GPU lane. Dependencies: none.

Files: `existing zk60-cl1 checkout and branch`; `docs/zkmatrix-poc/ZK60_CLAUDE_GPU.md`.

Work:

- Fetch and inspect the actual lane and performance tips. Merge the published performance baseline through 44d72ff into the existing lane, preserving its history and any concurrent work; record the resulting commit. H1 3ff8d5f is already merged as c84668f and must not be duplicated.
- Pick up the completed atomic public-cache publication and ZK cache summary from 44d72ff. Credit CL9 and the report request as implemented; do not recreate either fix.
- Correct the closure wording: the successful floor run used 82314a1, before the H1 merge. Retain that successful evidence, the failed attempts and their distinct source identities.

Acceptance:

- Record both parent pins, the resulting source tree, and exactly which source each archived gate tested.
- No combined-tree acceptance is claimed from the 82314a1 log. Integration into the performance branch remains Codex-owned; CL17 supplies the new combined evidence.

Limits: This is baseline synchronization, not a GPU launch. Keep the validated H1 process isolation; a replacement global-config scheme is not needed for this queue.

### CL13 — Bind qualification evidence and make the runner portable

Priority 0; **ready**. Owner: Fable / Claude tools lane. Dependencies: none.

Files: `scripts/hashline_cl_5090_preflight.py`; `tests/test_hashline_cl_5090_preflight.py`; `results/cl1_floors.sh`; `scripts/hashline_cl_gpu_gates.py (new if useful)`; `tests/test_hashline_cl_gpu_gates.py (new if useful)`; `docs/zkmatrix-poc/ZK60_CLAUDE_5090.md`.

Work:

- Replace green-substring/timestamp qualification with a versioned run manifest identifying source inputs, CPU/GPU binaries, build configuration, device, each expected/executed case, exits, verification verdicts, full proof hashes and lengths. Tie the chosen binary and run evidence together; a dirty count is not source identity.
- Keep unsupported full/target requests refused. The generated pass commands still implement FFN-only coverage; flags cannot supply generation, decoded full-relation verification or security evidence.
- Make the selected repository/export/scratch/device/threads explicit and propagate the requested layers/tokens and memory budget into every emitted command. Remove the hardcoded checkout and fixed 32-layer campaign assumptions. Test shell quoting with paths containing spaces.
- Move parser self-tests ahead of builds and hardware work. Keep the corrected quoted JSON default. Use one outer heavy lock; the script acquires its build lock internally. Honor two build/Rayon/prover threads on this shared laptop instead of hardcoded --threads 8.

Acceptance:

- The four reproduced probes all refuse: absent binary digest, unrelated binary digest, zero expected/executed cases, and flag-only full/target coverage.
- Reject missing/duplicate/unexpected case identities, missing negative controls, mismatched source/binary/device/artifacts, failed exits and stale/incomplete manifests. A complete supported diagnostic manifest passes.
- CPU-only tests inspect emitted commands and simulate parser/build failure before any GPU invocation; parser regression covers valid JSON, empty/missing data and the former extra-brace expansion.
- A dry-run emits no hardware jobs. Case expectations are tied to the suite version, not merely a threshold of 20 that could miss removed cases.

Limits: Do not change scripts/hashline_benchmark.py eligibility semantics. The manifest establishes recorded provenance; it is not independent privacy or security certification.

### CL14 — Reject invalid chunk-sweep measurement rows

Priority 0; **ready**. Owner: Fable / Claude tools lane. Dependencies: none.

Files: `scripts/hashline_cl_chunk_sweep.py`; `tests/test_hashline_cl_chunk_sweep.py`; `results/cl6_*`.

Work:

- Reuse CL5 validated-row logic or an equivalent common contract before parse_measured_log/reconcile ranks choices.
- Require a known successful invocation exit, accepted verification, consistent shape/privacy/cache/device metadata, serialized proof identity and finite nonnegative clocks. Define how exit status reaches the parser; absent status must not mean success.
- Revalidate the archived sweep against the corrected contract and retain any missing-evidence classification; do not invent successful exits for legacy logs.

Acceptance:

- The existing fixture with prove_s=-1 followed by exit 1 is refused; zero/NaN/infinite/negative and contradictory clocks have explicit outcomes.
- Tests reject conflicting verdicts/digests/metadata and missing or nonzero exits while preserving a valid comparison with complete evidence.
- Report whether the prior chunk-size conclusion survives. No automatic selector is promoted solely from equal digests or noisy timings.

Limits: CPU-only work is ready now. The archived sweep is not declared invalid merely because the parser accepted a malformed synthetic input.

### CL15 — Define and test empty GPU opening queries

Priority 0; **ready**. Owner: Fable / Claude GPU lane. Dependencies: none.

Files: `hashline/src/gpu/cuda.rs`; `hashline/src/gpu/mod.rs`; `hashline/tests/zk60_gpu_commit.rs`.

Work:

- Define the public/helper behavior for an empty query list: return an empty result or a clear error before device allocations. Carry it through hiding/non-hiding, fused/reference and pruned/dense routes where the API exposes them.
- Remove the reachable empty-list assumption around qs.last().unwrap() in the hiding pruned route. Retain duplicate-index expansion, index bounds and the reference switches.

Acceptance:

- A CPU-testable boundary rejects or returns empty without requiring a GPU or allocating scratch.
- The device oracle explicitly executes the empty boundary plus duplicate, out-of-range, ragged and below-fusion-threshold cases on applicable routes.
- Valid nonempty leaves/opened columns retain CPU parity and frozen proof bytes under CL17.

Limits: The round-9 finding is source-derived, not a Codex GPU reproduction. One GPU core writer; do not change PCS transcripts or caller semantics outside the agreed interface.

### CL16 — Reconcile the successful resident return snapshot

Priority 1; **ready**. Owner: Fable / Claude planner lane. Dependencies: none.

Files: `scripts/hashline_memory_plan.py`; `tests/test_hashline_memory_plan.py`; `scripts/hashline_cl_pending_memory.py`; `tests/test_hashline_cl_pending_memory.py`.

Work:

- In fallback mode that completes resident from an exact warm pool, end raw pad/power lifetimes before recording the return snapshot, as the resident source does.
- Keep requested size, allocated capacity, pool ownership, raw frees and returned commitment state consistent. Check dependent pending-memory reports for the same snapshot use.

Acceptance:

- At rows=300, log_cols=10, inv_rate=4, checks=q_pad=16, mode=fallback, pool_state=warm-resident, return live bytes equal 12,288,000; the old event reported 12,359,168, an excess of 71,168.
- The final stage agrees with commitment_live_after_return_bytes, while the peak includes pads/powers during their actual lifetime.
- Warm exact reuse remains a successful resident outcome; capacity is counted once, the 64-buffer cap is preserved, and existing planner/pending tests pass.

Limits: This corrects an overcount, not evidence of unsafe peak underestimation. Component accounting alone does not authorize a whole private-block run.

### CL17 — Deliver final combined-source correctness evidence

Priority 0; **queued**. Owner: Fable / Claude lane; Codex reviews integration. Dependencies: CL12, CL13, CL14, CL15, CL16.

Files: `results/cl1_floors.sh`; `results/cl_round9_* (new, distinct run paths)`; `docs/zkmatrix-poc/ZK60_CLAUDE_GPU.md`.

Work:

- Freeze the combined source after the preceding fixes. Run the complete release CPU suite, required GPU oracle and all four frozen artifacts under CPU/GPU/forced hiding chunking.
- Include both missing-feature controls, named negative controls, and the new empty-query boundary. Test the adopted cache with actual separate cold/warm prover processes and P3 refusal.
- Produce the CL13 manifest, retained per-case logs and exit marker from that same build. Record CPU/GPU device dispatch and fallback evidence, not just a gpu: ON startup line.
- Hand the pinned changes and validation to Codex for integration. Preserve the prior 82314a1 success as historical evidence.

Acceptance:

- All 12 full SHA-256/length byte cases match; the exact oracle case set and negative controls execute on the named device.
- No required test is silently skipped; missing-feature-required mode refuses, ordinary no-feature mode explicitly reports zero device cases.
- Actual cold/warm proof bytes are identical with correct hit/miss counts; P3 cache refusal occurs before cache creation. Source/binary identity matches the artifact manifest.
- A final CPU combined-suite result covers H1 and the atomic cache tests alongside lane tests. Any source edits after a run are identified with their required retests.

Limits: Safe existing small fixtures only, shared heavy lock, two threads, detached logs/marker for long runs. No 32-layer laptop run, new hardware installation or target-throughput claim follows from this gate.

### CL18 — Evaluate compact pad/scale output as one bounded GPU optimization

Priority 2; **queued**. Owner: Fable / Claude GPU lane. Dependencies: CL17.

Files: `hashline/src/gpu/cuda.rs`; `hashline/src/gpu/kernels.cu`; `hashline/tests/zk60_gpu_commit.rs`; `docs/zkmatrix-poc/ZK60_CLAUDE_RESIDENCY.md`; `results/cl18_* (new)`.

Work:

- First derive the compact output stride and ownership for n+q coefficients versus nn; check k_ntt_p1 n_src handling in both commit and fused-opening paths. Quantify live and pooled capacities before implementing.
- If the derivation supports it, add a separately switchable compact pad/scale path with the full-output reference retained. Do not bundle other kernel changes.
- Measure the changed phase and end-to-end proof readiness at an already permitted small shape using identical seeds/mode/cache/chunk settings. Record neutral or negative results as valid outcomes.

Acceptance:

- CPU oracle verifies leaves AND openings across every supported rate, pad boundaries, ragged chunks, duplicate queries, interleaved commitments and fused/reference routes.
- Failure/cleanup ownership and memory counters agree with the planner; no stale stride or unsupported n+q path is silently used.
- Full frozen gates pass at the new source before promotion. The measured phase gain and whole-proof change are reported separately; the traffic reduction remains a hypothesis until measured.

Limits: This task authorizes a bounded optimization investigation, not a claimed speedup, altered security parameters, a private repair, or a full-model run.

### CL19 — Specify an exact proof-size telemetry handoff

Priority 2; **complete_by_codex**. Owner: Fable analysis; Codex owns serializer/CLI integration. Dependencies: none.

**Round 10 completion:** Codex implemented the typed byte counter and opt-in per-layer CLI report. **156 Rust tests, 39 Python consumer tests, four unchanged frozen proofs and P3 profiling on/off byte parity pass.** See [the continuation record](ZK60_ROUND10.md). Fable should use the actual-object counts for CL10 reconciliation; no duplicate serializer implementation is needed. The original handoff contract follows.

Files: `docs/zkmatrix-poc/ZK60_CLAUDE_ARTIFACTS.md`; `scripts/hashline_cl_artifact_profile.py`; `tests/test_hashline_cl_artifact_profile.py`.

Work:

- Specify LayerProofZk size-breakdown fields and the actual serializer boundaries that would supply them. Replace subtraction-only residual claims with a proposed independent measurement for each serialized section.
- Cover plain P1 W versus salted hiding P3 W, A/H/mask openings, group/proximity vectors, sumcheck messages and framing. Describe an API that counts without allocating a second complete proof.
- Provide a narrow proposed patch/test contract for Codex-owned zk.rs/CLI integration; keep the current working source read-only.

Acceptance:

- The handoff lists exact insertion sites, API/schema, ownership, and positive/negative tests that would fail if a section were omitted or assigned twice.
- Once Codex integrates it, measured section counts must sum to actual to_bytes length across supported small P1/P3 fixtures without changing proof bytes. Until then label this task design-delivered, not implemented telemetry.
- Separate serialization time/copies from byte count; no compression, mask removal or reduced checks is promoted as compatible from these counts.

Limits: The completed wcache::report request and H1 isolation need no replacement. Shared serializer/CLI production edits stay with Codex.

### FA1 — Independently reproduce the actual FFN disclosure

Priority 0; **ready**. Owner: Fable as reviewer of Codex diagnostic. Dependencies: none.

Files: `docs/zkmatrix-poc/ZK60_FABLE_PRIVACY_REVIEW.md (new)`; `results/zk60_fable_fa1_* (new)`; `hashline/src/zk_ffn_mask_diagnostic.rs (read-only baseline)`; `hashline/tests/zk60_mask_rank.rs (read-only baseline)`.

Work:

- Run the actual mask_diagnostic tests at the recorded baseline, then independently inspect/reconstruct the public-observation replay and extraction. A rerun alone is not an independent algebraic review.
- Verify the extractor receives only verifier-visible commitment/claims/opening/transcript, and observations publish only after the whole FFN verifies. Witness truth belongs only in the separate comparison harness.
- Cover T2 and T32 under P1 and P3, explicit fixture seeds and default fresh randomness; verify groups [7,3,1,1,6], X-at-p2 and h16-at-p5 mappings and challenge endpoints without resampling.

Acceptance:

- Record reviewer identity, exact source, commands/exits, profile parameters, proof hashes, group membership and observed rank/output dimensions; no recovered values or secret randomness in reports.
- Confirm or refute complete 32-value tiny-plane recovery and the T32 per-column functionals with independent reasoning. T32 extraction is not an upper bound on leakage.
- Independently inspect or add controls for malformed grouping/indices/roots/columns/final-H, zero/degenerate coefficients and paired masks. State the in-process observation boundary; do not claim a standalone FFN byte decoder.

Limits: CPU-only synthetic inputs. Existing tests are reproducible now; any additional hook in zk.rs/pcs.rs needs an exact cross-owner patch handoff before shared-source edits.

### FA2 — Determine joint exposure and affected profiles

Priority 0; **queued**. Owner: Fable independent privacy reviewer. Dependencies: FA1.

Files: `docs/zkmatrix-poc/ZK60_FABLE_PRIVACY_REVIEW.md (new)`; `scripts/zk60_fable_joint_rank.py (new, analysis only)`; `tests/test_zk60_fable_joint_rank.py (new if a rank tool is implemented)`; `results/zk60_fable_fa2_* (new)`.

Work:

- Enumerate actual joint A/H/W opening groups and repeated mask occurrences from verifier data: terminal/proximity vectors, sampled encoded columns, folded pads, helper sums, CFS functionals, table multiplicities and constrained zero-sum rows.
- Express base-field observation and mask matrices with actual extension coefficients and transcript-conditioning assumptions. State what the rank calculation models and what nonlinear or adaptive observations it does not settle.
- Expand beyond the two singleton A groups to P3 W and H. Classify tested tiny/T32 and larger supported layout families as affected, unresolved or covered by a stated argument; begin with symbolic/tiny cases instead of full-model jobs.

Acceptance:

- Each observation has a source/role, domain, coefficient provenance, mask support and reuse identity. Missing observations are explicit, never assigned zero cost.
- An implemented rank tool checks known deficient and independent-mask fixtures and agrees with an independent calculation; numerical rank alone is not called a simulation proof.
- Deliver an impact matrix and a precise list of unresolved assumptions that FA3 must address. Keep single-proof and repeated-proof observations distinct.

Limits: A/H/W local mask counts and passing paired-mask controls do not by themselves settle joint privacy. Additional public-only capture hooks remain an agreed Codex/PCS handoff.

### FA3 — Review a complete repair and pending-block mask contract

Priority 0; **queued**. Owner: Fable reviewer; Codex implements the accepted protocol. Dependencies: FA2.

Files: `docs/zkmatrix-poc/ZK60_FABLE_MASK_REPAIR.md (new)`; `docs/zkmatrix-poc/ZK60_PENDING_FFN.md (read-only design input)`; `docs/zkmatrix-poc/ZK60_PRIVATE_BLOCK.md (read-only design input)`.

Work:

- Specify masks for existing FFN A/H/W and future attention/seams together: independent randomness dimensions, role-to-row mapping, permitted point transforms, proximity/helper constraints and all commitments/openings.
- Define reserve-before-commit and one-shot finalization order on actual arithmetic commitments. Cover late claims, repeated/missing masks, discarded/error paths and two simultaneously pending blocks.
- Give the new profile/domain/version boundary, verifier obligations, CPU adversarial test matrix and memory/layout delta for CL8 tooling. Preserve legacy fixtures as legacy behavior, not as repaired privacy evidence.

Acceptance:

- Every FA2 observation is addressed by an explicit argument or remains an identified blocker; a seam-only mask pair is not accepted as a core FFN repair.
- The proposed P1 block API consumes both internal seams exactly once and prohibits copied-plane substitutes or unreserved late claims.
- A reviewer independent of the eventual implementation records the construction, assumptions and disposition. Codex can implement from the concrete schema without guessing mask counts or transcript order.

Limits: Design and review are the deliverable. Production private attention/FFN composition remains gated on acceptance of this complete plan; this queue does not certify a construction in advance.

### FA4 — Specify approved private-model consistency

Priority 1; **ready**. Owner: Fable independent identity reviewer. Dependencies: none.

Files: `docs/zkmatrix-poc/ZK60_FABLE_MODEL_IDENTITY.md (new)`; `hashline/tests/zk60_model_identity.rs (new dedicated review tests)`; `hashline/tests/zk60_identity_gap.rs (read-only baseline)`; `hashline/src/model_identity.rs (read-only baseline)`.

Work:

- Independently reproduce known_p3_gap_same_declared_model_and_input_different_weights_both_verify. Review the independently registered P1 boundary as the positive comparison.
- Specify how fresh hiding W/gamma commitments prove consistency with an independently approved stable model commitment, including registration/authentication, layer order, calibration/quantization and repeated-proof assumptions.
- Provide an explicit statement/API and adversarial matrix: substitute W/gamma, copied candidate root, changed calibration, wrong approved identity, layer swap and replayed consistency proof.

Acceptance:

- The current substitute-weight diagnostic is recorded as a missing constraint, not successful P3 identity enforcement.
- The proposed approval source is independent of the candidate proof; a model-name string or copied root cannot satisfy it.
- State the new proof relation, privacy/security obligations and implementation handoff. Review the final construction with FA2/FA3 before any P3 product acceptance.

Limits: P1 private-block work may proceed after its shared privacy prerequisites without waiting for P3 identity. Existing model_identity.rs ownership remains Codex.

### FA5 — Close arithmetic and security obligations for the precise MVP

Priority 1; **ready_analysis**. Owner: Fable independent arithmetic/security reviewer. Dependencies: none.

Files: `docs/zkmatrix-poc/ZK60_FABLE_SECURITY_OBLIGATIONS.md (new)`; `results/zk60_fable_fa5_* (new)`; `docs/zkmatrix-poc/ZK60_BLOCK_CONTRACT.md (read-only input)`; `docs/zkmatrix-poc/ZK60_CAUSAL_ORACLE.md (read-only input)`.

Work:

- Create an obligation table for the exact fixed integer profile: field/integer conversion, no-wrap bounds, quotient/remainder and range checks, lookup membership/multiplicities, norms, attention/softmax, seams and zero-denominator behavior.
- For each obligation distinguish an actual verifier constraint, a checked public precondition, a host-only assertion and an unproved assumption. Give a concrete counterexample/test or derivation where applicable.
- Review challenge distributions, degrees, code parameters, cumulative query counts and whole-proof composition against the eventual FA3/FA4 construction. Separate tiny test profiles from any deployment profile.

Acceptance:

- Deliver source locations, exact parameter assumptions and remaining gaps for every row. Host-oracle agreement and frozen bytes are not substituted for a proof-level bound.
- Any soundness/privacy estimate states its derivation and dependencies; do not inherit an old security number for a changed composition.
- Mark analysis-delivered separately from final closure. Final security acceptance incorporates the implemented repair and independent verification of its obligations.

Limits: Analysis can start now. Final closure depends on the concrete repair and, for P3, approved-model consistency; no target-throughput eligibility is granted by this document alone.

### CL20 — Create and maintain a minimal refactored ZKP subproject

Priority 3; **ready_design**. Owner: Fable refactoring lane; Codex reviews shared-core extraction. Dependencies: CL17.

Files: `zkp-core/README.md`; `zkp-core/Cargo.toml (new at implementation)`; `zkp-core/src/ (new at implementation)`; `zkp-core/tests/ (new at implementation)`; `zkp-core/examples/ (new at implementation)`; `hashline/Cargo.toml and extracted core modules (coordinated adapter changes)`.

Work:

- Use zkp-core/ as the small maintained library subproject, with a manifest, explicit supported-profile contract, architecture/API guide and tiny prove/verify example. Design can begin now; source extraction follows the validated CL17 baseline and does not delay privacy/integration work.
- Map the actual transitive dependency closure before moving code. In particular, PCS and sumcheck currently obtain ZkRng from zk.rs, PCS embeds GPU dispatch, and layer.rs mixes compact PCS/cache/export paths. Extract randomness/parameters/statement/proof primitives into coherent modules instead of copying those large modules wholesale.
- Keep the default library CPU-first with typed inputs, explicit parameters/backend selection, bounded proof decoding and clear errors. Exclude CLI, model download/export plumbing, benchmark campaign scripts, CUDA tooling and unused proof backends from its default dependency closure. Add adapters only for concrete consumers.
- Move one vertical proof/verification path at a time. Select and document the exact currently implemented profile, including any unresolved privacy limitation; preserve its relation, transcript and RNG semantics. A public-only example or a thin dependency on the entire hashline crate is not completion of the ZKP subproject.
- Keep hashline, zkmatrix-rs, experiments, reports, benchmarks and alternative paths available. Prefer one canonical extracted implementation consumed by existing adapters. A temporary duplicate must have explicit source pins, differential tests, maintenance ownership and a removal/convergence milestone.
- Establish a fast isolated test command and parity gates in CI or the existing local gate runner. Document how an accepted protocol repair is promoted into the small core and how experimental code stays outside it.

Acceptance:

- zkp-core builds/tests independently from its manifest with dependencies provisioned and has a runnable tiny prove/verify example; no CUDA installation, downloaded model or unrelated experimental binary is required.
- A supported-profile matrix identifies what is included, deliberately excluded and still unreviewed. Refactoring does not claim to repair the known FFN privacy defect or P3 identity gap.
- For the extracted profile, seeded proofs retain exact bytes, existing/new prover and verifier paths cross-check where interfaces permit, and malformed/tampered proofs reject consistently. Fresh randomness tests and applicable disclosure regressions remain present.
- Legacy entry points and frozen artifact gates still pass. Existing experiments are neither deleted nor silently redirected to different semantics.
- Document one source of truth per primitive, the dependency graph, module responsibilities, public API and migration ledger. Compare dependency/module surface before and after; do not reduce line count by discarding validation or hiding the whole legacy crate behind a wrapper.
- Completion means a working maintained subproject and adapters, not just this README or a copied snapshot. Implementation is split into bounded reviewable commits.

Limits: Lower priority than correctness, privacy repair and integration. The README created with this queue is a design scaffold only; no proof code has been extracted. Coordinate shared-source ownership and keep protocol redesign separate from mechanical refactoring.
