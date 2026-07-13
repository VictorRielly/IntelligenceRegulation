# Remaining risks and gates

## GPU work may start

The packed U-K9 arithmetic has a stable layout, scalar oracle, forced-portable
path, AVX-dispatched path, boundary vectors and runtime capacity checks. That is
enough to begin an accelerator implementation safely.

## The headline remains a no-go

The following are still substantial blockers to “secure zero knowledge for an
8B transformer feedforward in at most five seconds.”

### 1. There is no complete 8B proof path

U-K8 proves one range -> lookup -> Hadamard gate chain. The 32-layer statement
inventory is a validated cost model, not a proof that executes all 736
operations. Attention, normalization and the complete model-wide commitment
and proof schedule are not integrated into one independently verifiable proof.

### 2. Five seconds is unsupported

The current secure U-K8 block takes seconds for only 1,020 elements, and q46
grounding dominates. The corrected pass inventory models about 115 seconds at
22 CPU threads before a complete proof exists. The repository's 5.4-second GPU
line is an assumed speedup for an unmasked, uncommitted lookup microbenchmark.

Before a five-second target is credible, measure GPU kernels for every dominant
stage and an actual end-to-end proof. Do not multiply an unrelated CPU scaling
factor by an assumed 20x GPU factor.

### 3. Proof and verifier boundaries are still prototype-grade

The U-K8 verifier now owns transcript derivation, but proving and verification
still live in one driver function. There is no canonical proof serialization,
untrusted byte parser, size limit, or standalone verifier API. Extract owned
`PublicInput`, `Proof` and `Verifier` types before calling the system secure.

Required negative tests include truncation, extension, reordered sections,
duplicate sections, noncanonical field encodings, oversized lengths and proof
transplant across statements.

### 4. Randomness needs a production portability pass

The active U-K8 CLI uses Linux `/dev/urandom`, which fixes the public-mask flaw
on the target host. Before a production release:

- use a maintained cross-platform OS entropy interface;
- define fork/reseed behavior;
- zeroize long-lived secret buffers;
- remove or feature-gate deterministic constructors from production builds;
- migrate remaining legacy demo APIs away from `u64` RNG state; and
- add failure-injection tests for entropy exhaustion/read errors.

### 5. Sampling and side channels remain prototype-grade

Gaussian and rejection sampling still use floating-point `exp()`, as the source
already notes. Replace this with a reviewed constant-time or otherwise
side-channel-appropriate discrete sampler. Audit secret-dependent branches,
memory access, GPU timing and buffer lifetime.

### 6. The capacity cap needs a target-shape schedule

The CPU packed reference rejects tables above `2^25` leaves. The final model
schedule must prove that each GPU chunk respects the same accumulator bound, or
derive and review a higher bound. Multi-instance aggregation can exceed a
per-tree size even when each tree fits individually.

### 7. Panics must become typed errors

The current prototype uses assertions for malformed sizes, allocation caps,
entropy failures and protocol guards. An untrusted verifier and GPU runtime
must return typed errors without advancing transcript state or partially
accepting a proof.

### 8. External cryptographic review is still required

Passing adversarial batteries is not a security proof. The combined lookup
masking, lattice commitment, rejection sampling, cross-modulus links and
Fiat-Shamir composition need independent cryptographic review against the exact
implementation and frozen parameter set.

## Recommended next sequence

1. Implement fixed-multiply and fold on GPU against the U-K9 byte-for-byte
   differential gate.
2. Add projective tree step, then round-polynomial accumulation.
3. Benchmark each kernel at admitted maximum chunks with transfer time and
   peak memory included.
4. Extract canonical proof/public-input types and a standalone verifier.
5. Integrate one complete FFN block from statement to proof bytes.
6. Only then scale layer count/model dimensions and revisit the five-second
   target with measured end-to-end data.
