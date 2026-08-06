# Recommendations and gated roadmap

## Immediate: stop the claim surface from outrunning the evidence

1. Add a top-level `STATUS.md` with four separate columns: implemented,
   measured, modeled, and open. Link it from the root README.
2. State explicitly that no proof from the audited Route R revision is suitable
   for real secrets or publication as zero knowledge.
3. Freeze a precise benchmark/security statement before further optimization.
4. Make all status tables and cost counts generated artifacts checked by CI.
5. Keep the current uncommitted R1 work isolated until its protocol version,
   tests, and costs are complete.

## Phase 0 — Restore a trustworthy research baseline

Exit criteria:

- preserve the now-green 42-test baseline from a clean checkout;
- move binary self-tests into Rust `#[test]` modules where practical;
- CI builds release/debug, runs Python/Rust behavioral suites, formatting,
  clippy, and status/cost drift checks;
- root quick start works on a clean supported machine;
- add a license and dependency lock/reproduction policy.

## Phase 1 — Close correctness and ZK before performance

### R1

- complete the both-direction ordering regression specified in Q4;
- add leak non-recovery tests for twisted ct, twisted ring, and untwisted ring
  families;
- include pad groups in parameter derivation rather than repairing individual
  demos with magic constants;
- version the transcript/proof;
- recost all proof objects and rerun estimators;
- obtain independent review of the simulator and extractor.

### Composition

- implement E1 dense-to-slot target links;
- implement E2 non-constant coordinate pinning;
- construct an explicit malicious junk-coordinate witness and require rejection;
- tie the Hadamard result into the actual FFN chain;
- close q31/q46 non-wrap and all weight/input ranges.

Exit criterion: a small FFN with real composition is sound and ZK under one
canonical statement, with no declared-but-unproved bounds.

## Phase 2 — Build the statement and verifier product boundary

Create a versioned canonical schema containing:

- model identifier and full architecture;
- tensor IDs, shapes, orientations, visibility, and quantization metadata;
- exact scale, rounding, clamp, and overflow rules;
- weight and activation-table commitment/digest;
- complete operation DAG;
- backend/protocol/security parameter identifiers;
- public input/output;
- proof object references and transcript version.

Implement a generic verifier that validates the schema and operation coverage
before cryptography. Add bounded canonical serialization and fuzz it. The demo
builder and verifier must be separate processes/interfaces so verification does
not inherit trusted witness-side state.

## Phase 3 — Prove one complete transformer block

Do not call an FFN a transformer. The block exit criterion should include the
exact target architecture's:

- RMSNorm/layer norm;
- Q/K/V and output projections;
- RoPE or the target positional operation;
- causal attention and the exact declared softmax approximation/lookup;
- residuals;
- gate/up/down FFN with exact SwiGLU/SiLU semantics;
- all ranges, rescaling, and cross-representation links.

Use imported quantized model weights and compare public outputs against a
separate reference implementation over randomized and known vectors.

## Phase 4 — Resolve the nonlinear architecture choice

Run a time-boxed bake-off:

| Candidate | Measure |
|---|---|
| Route R plus a new lookup | Complete-block proof time/bytes, R1/E2 included, PQ-hiding assumptions |
| Small-field sumcheck/lookup stack | Complete-block time/bytes, GPU maturity, ZK for private inputs/weights |
| Pairing/PCS lookup stack | Setup size, GPU MSM, proof/verifier cost, trust model |

Select based on measured full-block results, not isolated matmul asymptotics.
The repository's own M4 result is already strong evidence that compiling SiLU
from bit planes and H3 products is not the endpoint.

## Phase 5 — Production hardening

- CSPRNG and reviewed samplers;
- no secret-dependent floating-point/branches;
- zeroization and side-channel review;
- canonical proof parser with limits;
- ceremony/transparent setup lifecycle;
- external cryptographic audit;
- reproducible parameter generation and native estimator confirmation;
- classical and quantum targets with safety margin;
- adversarial fuzzing and differential tests on every optimized kernel.

## Phase 6 — GPU and scale

Only after the complete block is correct:

1. Implement GPU commitment, NTT/matmul, transcript, and aggregation paths.
2. Measure end-to-end, including witness generation, transfer, restarts, proof
   materialization, and peak memory.
3. Validate the model at two or more sizes before extrapolating.
4. Scale to two layers, then a small real model, then the exact 8B target.
5. Report p50/p95, proof bytes, verifier cost, and energy/hardware count.

## Suggested success metrics

| Milestone | Required metric |
|---|---|
| Sound small FFN | All exact-integer bounds proved; R1+E2; external review findings addressed |
| Complete block | 100% operation coverage; reference-output equivalence; generic verifier |
| GPU block | Prediction error <=2x; p95 and bytes published |
| Small model | Multi-layer streaming, memory bounded, no statement gaps |
| 8B POC | Exact benchmark contract; secure/ZK proof; reproducible end-to-end result |
| Five-second claim | p95 <=5s on named hardware, including the declared timing boundary, with proof size/verifier/security published |

## Decision recommendation

The next high-value work is **not** another ring kernel optimization. It is R1
review, E2 composition, exact statement construction, and a lookup bake-off.
Those determine whether the fast arithmetic proves the intended computation at
all. Performance work before those gates risks optimizing a protocol or cost
model that must change again.
