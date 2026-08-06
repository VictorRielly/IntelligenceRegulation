# Prioritized findings

Severity meanings: **Critical** blocks the claimed security/computation
statement; **High** blocks a credible POC or performance claim; **Medium** is
important engineering/review debt.

## Critical

### C-01 — Composed slot-packed Hadamard has a documented soundness break

The M4 design states that committed H3 tensors are intended to contain values
in only the constant coordinate of each CRT slot, but the engine does not force
the other 15 coordinates to zero. Multiplication in `GF(q^16)` mixes those free
coordinates, allowing an adversarial operand to alter the checked constant
coordinate. The document explicitly says this affects the Llama `gate o up`
product and that the chain demo's Hadamard is standalone rather than linked to
the rest of the chain.

Evidence: [`M4_ACTIVATION_DESIGN.md`, E2](../docs/zkmatrix-poc/M4_ACTIVATION_DESIGN.md), especially the section beginning near line 400.

Impact: a composed proof can accept a computation that is not the declared
elementwise computation. This prevents a sound FFN/SwiGLU or SiLU chain.

Required fix: implement E1 plus E2, bind all non-constant coordinates with
post-commitment random link rows, add positive and adversarial tests, and prove
the rows compose with every use of H3. Do not count standalone H3 tests as
evidence until this is done.

### C-02 — The audited Route R quadratic layer is not zero knowledge

The repository's own algebra harness demonstrates that quadratic garbage
images are determined by public transcript data plus fixed witness images. For
the committed-executions gate, those images recover the product matrix `C`.
The committed base revision therefore must not be used or published as a ZK
proof.

Evidence: [`SOUNDNESS_REFERENCE.md`, honest limitation 1](../docs/zkmatrix-poc/SOUNDNESS_REFERENCE.md), [`Q4_LEMMAS.md`, Q4.3d/e and R1](../docs/zkmatrix-poc/Q4_LEMMAS.md), and `python3 scripts/zk_lemma_check.py` results `OK 1`, `OK 2`, and `OK 4`.

The worktree contains an uncommitted R1 implementation that adds committed
one-time pads. During this review Fable also added an explicit zero-pad leak
pair and a “pad after challenge accepts / pad in h0 rejects” order pair. The
latest direct self-test passes them. This is meaningful positive evidence, but
not complete evidence of closure:

- the code is still an uncommitted protocol change;
- the regression covers a small untwisted claim, not a statistical simulation
  or independent review of every quadratic family and production batch;
- documentation still labels R1 as unbuilt and carries stale costs;
- no independent cryptographic review has evaluated the full simulator,
  extraction, transcript ordering, abort behavior, or multi-claim composition.

Required fix: treat R1 as a new protocol version, complete both-direction order
tests and leak non-recovery tests for every quadratic family, make all capacity
derivation explicit, re-run security estimates, obtain external review, then
retire the unmasked version.

### C-03 — Integer exactness/range coverage is incomplete

The q31 binary gadget checks modular identities, while the chain demo prints
that its non-wrap side condition remains open. The M3 model's input and weight
widths are declared and asserted by the honest demo, not proved against the
commitments. Thus a verifier does not yet establish the intended bounded
integer computation for the full chain.

Evidence: comments and output in `ring_matmul::chain_demo`, and
[`M3_REPORT.md`, gaps 2 and 5](../docs/zkmatrix-poc/M3_REPORT.md).

Required fix: put every quantization/range premise in the statement and prove
it, use the q46 grounding path or a proven tighter strategy, and test malicious
mod-q witnesses that exploit wraparound.

### C-04 — The production statement does not exist

There is no complete, machine-readable transformer statement connecting model
identity, exact quantization, weights, input/output, all layer operations, and
proofs. `manifest.rs` hashes caller-supplied records but does not validate
referenced IDs, matrix-shape compatibility, orientations, operation coverage,
scale transitions, or a model/activation spec header. Verifier logic is
hardcoded inside demos.

Impact: even flawless subprotocols would not yet prove “this specific 8B model
ran this input through this feed-forward.”

Required fix: specify and implement a canonical versioned statement/wire
format and a generic verifier before scaling.

## High

### H-01 — R1 exposed fragile capacity derivation; live fixes restored tests

On the first reviewed R1 snapshot, 40 of 42 tests passed. Both failures aborted
at the same C2 capacity assertion:

- `test_ring_matmul_self_test`
- `test_ring_chain_demo`

The F5 test selected the worst-case bundle model after R1 expanded the number
of commitments. The chain demo's original `msg_r=1` put each pad in a full
commitment and exceeded q31 capacity.

Fable repaired both while this review was running: F5 now uses the existing
concentration/restart discipline; the chain derives at least `msg_r=2` and
bumps `N_r` with it; a freeze row pins pad counts. The 42-test suite then passed,
and the later R1-expanded direct self-test passed in 31.86s. The process finding
remains: proof-shape changes were not centrally derived or caught by freeze/CI
before integration. Production batching still needs a general wave planner,
not demo-local bumps.

### H-02 — R1 invalidates published cost claims and prior latency models

`Q4_LEMMAS.md` says pads ride an existing g commitment, add no response bundle,
cost about 1.5KB per twisted claim, and are sub-percent. That is not true for
the committed-executions path in the current worktree: there was no existing g
commitment, so the implementation adds a complete wide commitment and opening.
The demo now prints roughly 1,347KB total marginal for ten objects including
R1. At that toy shape, the newly required tenth commitment plus opening is
about 116KB by the code's own accounting, not a 1.5KB R1 delta.

For binary claims, R1 adds three pad slots per quadratic ct claim in addition
to each reveal slot. At `msg_r=1`, the chain wave grows to approximately four
times as many g slots. The old 5-10s and 15-30s ladders have not been recosted
for this change.

Required fix: derive object/slot/response counts from code, add them to
freeze-check, benchmark R1 at representative shapes, and regenerate every
large-model projection before making latency claims.

### H-03 — The five-second result depends on software that does not exist

No Rust proof source contains a CUDA/Metal/OpenCL proof kernel. GPU numbers in
the cost scripts are constants such as a 20x factor applied to measured CPU
anchors. The older ladder reaches 5-10s only after an unimplemented 2-4x
bit-packing/lookup improvement. The newer activation-inclusive model instead
lands at about 35-55s under those GPU assumptions.

Required fix: implement and benchmark the actual GPU kernels end-to-end,
including transfer, transcript, rejection, and proof materialization. Report
p50/p95 across repeated runs and pin the exact hardware and power mode.

### H-04 — The requested transformer operations are absent

There is no standard attention block, softmax, RMSNorm/layer norm, RoPE,
SwiGLU/SiLU proof implementation, multi-layer DAG, tokenizer/model loader, or
8B execution trace. M4 is a design and Python enumeration/cost harness only.

Required fix: first prove one complete, exact quantized decoder block. Scaling
matrix dimensions before completing operation coverage will produce a fast
proof of the wrong/incomplete statement.

### H-05 — Rust secret sampling is unsuitable for cryptography

Route R uses seeded SplitMix64 for witness blinding, masks, pads, Gaussians, and
other prover secrets. The Gaussian and rejection decisions use `f64::exp` and
secret-dependent branches. Seeds are fixed in demos. There is no zeroization.

Evidence: [`ring/mod.rs`](../zkmatrix-rs/src/ring/mod.rs), RNG and Gaussian
sections near lines 704-850.

Required fix: define a CSPRNG interface seeded from OS entropy, use a reviewed
constant-time discrete Gaussian/rejection sampler or a protocol with easier
sampling, zeroize secrets, and test distribution/conformance. Keep deterministic
RNG only behind a test feature.

### H-06 — Security levels are model-dependent and classical-only

The parameter sign-off is a custom core-SVP model plus a lattice-estimator run
under a disclosed CPython Sage shim and runtime patch. It is useful evidence,
but native Sage confirmation is outstanding. The project reports 120.3,
125.9, and 126.2 quantum bits for several frozen shapes, below a 128-bit
quantum target. The estimates treat the construction through generic SIS/LWE
instances; a complete analysis of the bespoke module/ring structure and
protocol reductions is still needed.

Required fix: publish a threat/security target, reproduce with native Sage,
run current standard estimators, analyze algebraic/module attacks and the full
reduction loss, and add margin rather than freezing at a tight model frontier.

### H-07 — Pairing setup is not deployable

The BLS12-381 backend generates the SRS inside demos from a locally known,
deterministically generated `tau`. A prover knowing that trapdoor can violate
the intended setup trust. There is no ceremony, contribution verification,
SRS import format, or subgroup/length validation path for untrusted artifacts.

Required fix: either implement a real updatable ceremony/import-validation
workflow or clearly restrict this track to benchmarks.

### H-08 — No untrusted proof boundary has been tested

Proofs are in-memory Rust structs. There is no canonical serialization,
deserialization, length cap, malformed-proof handling, API boundary, or fuzz
target. Many invariant violations panic, and release builds use
`panic = "abort"`.

Required fix: design a bounded canonical wire format, make verifier failures
return errors/false without panics, and fuzz parsing plus every verification
entry point.

## Medium

### M-01 — “PROVEN” labels can be mistaken for formal or peer-reviewed proof

The documents use `[PROVEN]` for handwritten arguments, algebra scripts, and
enumeration. This is reasonable internal grading but not formal verification or
external cryptographic review. Machine checks demonstrate selected identities
and numeric cases; they do not prove simulation security, extraction in the
random-oracle model, side-channel safety, or all composition cases.

Recommendation: rename the public legend to `ARGUMENT`, `MODEL`, `TESTED
IDENTITY`, and `OPEN`; reserve `FORMALLY VERIFIED` and `PEER REVIEWED` for those
actual states.

### M-02 — Benchmark evidence is not yet publication grade

Several measurements have one run, mixed hardware/context, no error bars, and
explicit concurrent workloads. Large-model estimates extrapolate linearly from
small kernels and combine measured CPU anchors with assumed GPU/thread factors.

Recommendation: add a benchmark manifest, warmups, repetitions, p50/p95,
machine fingerprint, commit hash, power settings, peak memory, proof bytes,
and automatic measured/model labels.

### M-03 — Rust behavioral tests are hidden from `cargo test`

`cargo test --all-targets` compiles successfully but reports zero Rust tests in
every target. Important logic lives in large CLI `self-test` functions invoked
by Python subprocess tests. This limits test selection, coverage, fuzzing, and
normal Rust tooling.

Recommendation: extract a library crate and convert units/properties to
`#[test]`, retaining CLI demos only for benchmarks.

### M-04 — Documentation and code are already drifting

R1 code, status tables, proof-size statements, commitment counts, and the
soundness reference disagree. The M4 activation header claims its digest enters
the manifest, but `manifest.rs` has no such field or generic extension.

Recommendation: generate status and cost tables from versioned code outputs;
make stale status a CI failure.

### M-05 — Basic project packaging is incomplete

There is no CI, no license, no root dependency/installation guide, and no
single supported command that builds and tests the project. Legacy experiments
share the root with the current proof work.
