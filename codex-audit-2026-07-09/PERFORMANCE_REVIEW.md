# Performance and five-second feasibility review

## Verdict

There is no evidence in this repository that a secure, zero-knowledge,
activation-complete 8B transformer feed-forward can be proved in five seconds.
The current code has no proof GPU backend and no complete transformer proof.
The latest internal activation-inclusive projection is approximately 35-55s
under assumed GPU speedups, before the R1 recost and before closing all soundness
gaps.

This does not prove five seconds is impossible. It means the present work has
not established a credible path with measured end-to-end data.

## First define the target

“One feed-forward through an 8B model” is not a benchmark specification. At
minimum freeze:

- exact model and parameter count;
- decoder-only/full architecture and all operations;
- batch size;
- prefill token count and/or single-token decode;
- quantization format and exact rounding/clamping rules;
- public/private status of weights, input, output, and intermediate state;
- whether weight commitments and setup are preprocessed/amortized;
- whether witness inference time is included;
- proof generation start/stop boundary;
- hardware count, model, memory, interconnect, and power envelope;
- proof bytes and verifier time/security target.

Five seconds for one decode token, a 512-token prefill, and a full 8k-token
prefill are radically different goals.

## Measured facts versus projections

| Item | Status | Result / implication |
|---|---|---|
| Route Z M3 tiny FFN | Measured | `T=16,d=32,f=64`: 316.27s prove, 83.71s verify. Not a transformer. |
| Route R live-fixed toy chain | Measured during this audit | Small `128x128` matmul plus standalone gadgets: 0.46s prove, 0.07s verify. Not sound as a composed transformer benchmark and vastly smaller. |
| A1 CPU commitment kernels | Measured micro/integration anchors | Useful evidence for one cost component. Does not measure full proof, GPU, nonlinearities, I/O, or 8B trace. |
| 15-30s Llama-7B pass | Model | Combines CPU anchors with assumed ~20x GPU and ~15x threading factors. |
| 5-10s endpoint | Model of future work | Requires unimplemented bit-packing/lookup 2-4x improvement. |
| 35-55s activation-inclusive pass | Latest model | Piecewise SiLU adds ~201% of the previous commitment bill and misses the Class-3 budget. |
| R1 overhead | Not recosted at scale | Current CE implementation adds a wide commitment/opening; binary waves add three pad slots per quadratic claim. Older projections are stale. |

## Why the latency claim is fragile

### No GPU implementation

The scripts contain assumed GPU factors; the proof implementation contains CPU
Rayon and auxiliary-NTT kernels. Until an actual GPU path exists, transfer,
kernel occupancy, modular reduction, transcript serialization, rejection
restarts, and memory bandwidth are unknown.

### Nonlinear work dominates

The Route Z M3 result is about 188x slower than its two matmul proofs because
range/ReLU gadgets dominate. Route R was intended to address this, but the M4
piecewise SiLU design still adds about 105 committed-element equivalents per
activation and approximately 108GB of modeled commit stream for the reference
pass. Its own conclusion is to build a lookup argument instead.

### R1 has a structural cost

Security repairs are not free. In the current code, each twisted quadratic
claim needs three pad slots and each untwisted claim two. A claim family with
one reveal slot becomes four slots before packing. At small `msg_r` this also
widens the joint response bundle enough to fail C2. Any performance model that
predates R1 is not decision-grade.

### Proof size and bandwidth need a hard budget

The CE demo reports megabyte-scale proof material for a tiny claim. The older
large-model model mentions roughly 2,200 matmul claims. Without a measured
aggregation/streaming design, proof bytes, host/device traffic, and verifier
bandwidth can independently exceed a five-second budget. Every projection
should report bytes and minimum required bandwidth, not just operations.

### “No more expensive than inference” needs reinterpretation

Total proving includes generating the witness, so it cannot do less total work
than computing that witness. A meaningful engineering objective is one of:

- added proof latency <= 1x inference latency on identical hardware;
- total prove+infer latency <= 2x inference;
- proof work <= 1x inference work after excluding the required inference;
- near-zero user-visible latency with extra hardware and pipelining.

Choose one and report both work and wall-clock. Extra GPUs can reduce latency
without reducing computational cost.

## Recommended benchmark ladder

1. One operation microbench, with proof bytes and repeated p50/p95.
2. One fully sound/ZK quantized FFN including range and activation.
3. One complete transformer decoder block including normalization, RoPE,
   attention/softmax, residuals, and SwiGLU.
4. Two blocks to validate cross-layer linking and streaming.
5. A small real model with imported weights and known output vectors.
6. Only then extrapolate to the exact 8B target.
7. Implement GPU kernels and compare prediction with measurement at each rung.

## Go/no-go checks for five seconds

Before an 8B build, require:

- an end-to-end GPU benchmark within 2x of its component cost model;
- a complete transformer block, not an FFN surrogate;
- R1 and E2 included in the costs;
- measured proof bytes whose PCIe/network/storage bandwidth fits five seconds;
- peak memory fitting the target hardware without hidden recomputation;
- p95 latency under a published hardware and token/batch contract;
- security parameters meeting the chosen classical/quantum target.

If a complete block misses its normalized cost budget by more than 2-3x after
optimization, pivot rather than extrapolating. The most credible alternative to
evaluate is a lookup/sumcheck/small-field architecture designed around LLM
nonlinearities, while retaining Route R only if post-quantum hiding of private
weights is a non-negotiable requirement.
