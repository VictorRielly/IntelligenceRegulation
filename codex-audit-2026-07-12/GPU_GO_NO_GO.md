# GPU readiness decision

## Outcome

**No-go for a GPU proof backend as the next milestone.**

**Conditional go for isolated kernel research:** U-K9's packed field/tree
representation is a reasonable CPU reference for an experimental GPU arithmetic
kernel after its boundary tests and merge are complete. That work must not be
presented as acceleration of a secure FFN proof, because no such end-to-end
artifact exists yet.

## Why the GPU cannot rescue the current design

### Security is not a throughput problem

A GPU does not fix publicly reconstructible masks, a verifier-controlled hash
gap, inconsistent integer semantics, or the absence of an independent proof
format. Accelerating the current path would make an invalid security boundary
faster and harder to change.

### The measured bottleneck is not U-K9's kernel

The live U-K8 measurements attribute roughly 96% of chain proving time to the
q46 binary/range family and its coupled Fiat–Shamir-with-aborts restarts. U-K9
roughly halves the lookup core in my runs; it does not change q46, the C2
commitment cap, or the 1,020-element block structure.

Even eliminating lookup computation entirely would leave almost all of the
reported activation-chain wall time. This is an architecture/Amdahl limit, not
a missing CUDA implementation.

### The target-scale unit is wrong

Current GPU modeling assumes large, well-amortized lookup instances. The
committed chain is forced into 176,832 independent blocks per 32-layer pass.
Each block repeats fixed masks, blinders, pins, q31/q46 rounds, and transcript
material. A GPU can parallelize blocks, but it cannot turn roughly 6.30 GiB of
lookup messages into a 256 KiB proof or remove the verifier's corresponding
work without a new aggregation protocol.

### The benchmark factors are assumptions multiplied together

`lookup-bench` prints a 22-thread row by dividing by 8.74 and a GPU row by
dividing that result by another 20. The lookup code is single-threaded and the
GPU kernel does not exist. These are explicitly labeled assumptions, and they
must not be used as a design acceptance test—especially because the benchmark
is unmasked and uncommitted.

## Required gates before GPU integration

| Gate | Required evidence | Current status |
|---|---|---|
| Secure prover coins | OS-seeded CSPRNG; secret fresh masks/blinders; reconstruction/reuse regression | Fail |
| Independent verifier | Proof bytes only; recomputes every transcript seed; no shared prover variables | Fail |
| Integer semantics | Typed table/quantization spec; exact rescale and signed bounds; adversarial vectors | Fail |
| Complete unit of work | One caller-supplied FFN layer with 3 matmuls, requantization, lookup, Hadamard, output | Fail |
| Scalable aggregation | Full tensor/pass aggregation with measured proof bytes and verifier cost | Fail |
| Range architecture | Removes or radically reduces the q46 96% wall and restart coupling | Fail |
| U-K9 integration | Clean merged U-K8+U-K9 tree, 42/42 plus boundary tests and committed-chain benchmark | Fail |
| CPU reference | Canonical bit-exact reference, portable/AVX2 differential, target-scale resource artifact | Partial |
| GPU differential | CPU/GPU bit identity, malformed-input behavior, host/device RSS and transfer-inclusive p95 | Not started |

## Recommended GPU scope when the gates pass

Start with kernels whose protocol semantics are already frozen:

1. canonical packed q31 field multiply/fold/tree operations;
2. q31/q46 commitment kernels with secure device-side randomness or securely
   transferred coins;
3. transcript hashing with an exact CPU/GPU known-answer test;
4. range/lookup aggregation kernels only after the replacement protocol is
   selected; and
5. end-to-end measurements including witness generation, commitments, hashing,
   serialization, transfers, and proof bytes.

Report p50/p95 on a named GPU and driver. Do not derive the result from stacked
speedup assumptions.

