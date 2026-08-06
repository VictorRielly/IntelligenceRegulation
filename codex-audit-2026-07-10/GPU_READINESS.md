# GPU readiness decision

## Decision table

| Proposed work | Decision now | Reason |
|---|---|---|
| Backend interface, device buffers, bit-exact CPU oracle | **Go** | Reversible groundwork with value even if the protocol evolves. |
| A1/commitment GPU microkernel | **Conditional go** | The arithmetic semantics are relatively stable, it is a measured bottleneck, and differential test vectors already exist. Keep it an experiment, not a pass-latency claim. |
| Wide-object commitment streaming on GPU | **Conditional go** | M5 gives a bounded layout, but include transfers, hashing, RNG, and proof output in the clock. |
| Current unmasked lookup on GPU | **No-go** | It is explicitly non-ZK and its data layout is not FFN-memory-ready. |
| Full GPU prover / five-second milestone | **No-go** | Masking, end-to-end FFN integration, exact statement semantics, and coherent cost accounting remain open. |

## Why a narrow commitment spike is defensible

The A1 path has properties that make it a good hardware experiment:

- exact finite-field semantics;
- a schoolbook oracle and bit-identical CPU optimized paths;
- stable input/output shapes;
- a real full-shape CPU commitment-stream baseline;
- wide-object chunking that bounds the CRS footprint;
- no dependency on the unbuilt U-K5 masking equations.

The experiment should answer one question: “What is the measured end-to-end
speedup of this exact commitment workload on named hardware?” It should not be
used to claim a complete proof time.

## Why the lookup should wait

The masked protocol changes the workload:

- degree-3 rounds gain degree-5 cases;
- new mask/blinder commitments and openings appear;
- per-tensor MLE outputs are replaced by aggregate-only pins;
- table depth and transcript shape change;
- mask freshness becomes stateful across proofs;
- current heap-allocated tree tables need a different memory representation.

Optimizing the unmasked control/data flow first risks building kernels around
objects U-K5 deliberately removes.

## Required gates

### Gate 0 — Freeze the target

Publish one benchmark contract:

- exact 8B model and model digest;
- token mode and sequence length;
- batch size;
- exact quantization, rounding, clipping, and overflow rules;
- private/public status of weights, input, output, and cache;
- preprocessing that is excluded or amortized;
- whether witness inference is inside the prover clock;
- exact GPU model/count, VRAM, interconnect, driver, and power mode;
- proof bytes, verifier time, security target, and p50/p95 goal.

### Gate 1 — Freeze the protocol shape

- U-K5a-e implemented and reviewed;
- R1 and E2 included;
- q31/q46 exactness and every range premise proven;
- canonical model/operation statement validated by a generic verifier;
- small complete FFN accepts honest inputs and rejects malicious range,
  lookup, junk-coordinate, and manifest substitutions.

### Gate 2 — Make the lookup memory-bounded

- replace `Vec<u64>` K elements with an inline or structure-of-arrays format;
- preallocate scratch buffers;
- process/recompute tree layers without retaining unnecessary tables;
- specify device-resident versus streamed buffers;
- measure the actual masked `2^23` instance's host and device peaks;
- fit with at least 25-30% VRAM headroom for allocator/runtime variability.

### Gate 3 — Establish per-kernel CPU baselines

Do not use a shared “20x” constant. Measure separately:

- column commitment/A1 NTT;
- A2 and response combinations;
- K-field multiplication and reductions;
- masked tree construction and sumcheck folds;
- E4 weight/claim generation;
- SHA-256/transcript work;
- secure RNG/sampling;
- serialization and host/device transfer.

For each: work units, bytes read/written, arithmetic intensity, one-thread and
parallel CPU p50/p95, peak memory, and output digest.

### Gate 4 — GPU commitment backend

Exit criteria:

- CPU/GPU bit identity on random and worst-case boundary vectors;
- no unchecked capacity/reduction overflow;
- identical commitments and accepted proofs across backends;
- tamper negatives remain backend-independent;
- end-to-end clock includes allocation, transfer, kernel, synchronization,
  hashing, and proof materialization;
- repeated p50/p95 and peak VRAM on named hardware;
- prediction error within 2x of a pre-registered roofline model.

### Gate 5 — GPU masked lookup backend

Build only after U-K5 and the contiguous representation land. Repeat all
semantic and ZK regression tests across CPU and GPU, including mask reuse,
round ordering, invalid table pair, wrong multiplicity, wrong E4 coordinate,
and device-buffer truncation.

### Gate 6 — Integrated proof

Measure, in order:

1. one complete FFN;
2. one complete decoder block;
3. two linked blocks;
4. a small imported model;
5. the exact 8B target.

No earlier rung should inherit a generic speedup from another kernel.

## Backend/library note

ICICLE is worth evaluating rather than rebuilding every device abstraction:
its current documentation exposes Rust device buffers, batched NTTs, and
negacyclic lattice-ring APIs. However, the repository's Route R modulus,
ring/CRT layout, and GF(q^16) lookup are custom. ICICLE's documented sumcheck
API currently says extension-field challenges are unsupported, so it is not a
drop-in replacement for this lookup engine. Treat it as a possible runtime and
primitive source, then prove compatibility with small prototypes.

Primary documentation:

- [ICICLE lattice/negacyclic NTT Rust API](https://dev.ingonyama.com/api/rust-bindings/lattice/lattice-snarks)
- [ICICLE sumcheck API and extension-field limitation](https://dev.ingonyama.com/api/cpp/sumcheck)
- [NVIDIA CUDA Best Practices Guide](https://docs.nvidia.com/cuda/cuda-c-best-practices-guide/index.html)
- [NVIDIA Nsight Compute roofline documentation](https://docs.nvidia.com/nsight-compute/NsightCompute/index.html)

NVIDIA's guidance reinforces the correct measurement boundary: minimize and
account for host/device transfers, leave related data on device, and profile
the real end-to-end pipeline rather than isolated kernel time.

## Recommended immediate scope for Fable

If GPU work starts now, constrain it to this deliverable:

> A backend-agnostic commitment API plus one batched q31 A1 commitment kernel,
> with CPU/GPU bit identity, transfer-inclusive p50/p95, peak VRAM, and no
> changes to protocol status or whole-pass latency claims.

In parallel, the main protocol work should be U-K5 and the original U-K8
integration. Full GPU lookup work begins only after those gates.

