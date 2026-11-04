# Current throughput target — 2026-11-04 (D64): meet or exceed FlashProve

**Victor, 2026-11-04:** "we now have a new latency target to meet or exceed after anthropics announcement". The bar
is Anthropic's FlashProve:
- about **110 proved tokens/s** on one H100;
- prefill, a batch of 24 requests of 1,024 tokens in about 223 s;
- Llama 4 Maverick, about 17B active parameters per token, 4-bit integer weights;
- the weights hidden, the prompt and the reply public.

**Coordinator's reading, for Victor to confirm** (the measurement rules below are unchanged):
- **Headline target:** at least 110 proved tokens/s on this document's clock: amortized over the whole workload,
  witness work included, every receipt verified.
  - It is for a complete private (P1) 8B forward pass on one GPU (RTX 5090 or H100).
  - Batching concurrent requests is allowed, as FlashProve's figure is a 24-request batch; report the batch size and
    the per-request latency beside the rate.
- **Like-for-like stretch:** FlashProve proves about 17B active parameters per token, about 2.1× our 8B. Equal work
  per second would be about 230 tok/s at 8B. Its weights are 4-bit; ours are 8-bit.
- The ≥ 50 tok/s target below is superseded as the goal and kept as a milestone.

## Previous target — 2026-09-26

Victor's direction then: a complete private **8B-parameter forward-pass proof
at >=50 proved tokens per second on an RTX 5090 or another high-end GPU**.
Larger token workloads are acceptable to amortize initialization and initial
prefill. This supersedes treating the historical 512-token window and its
10.24-second budget as mandatory acceptance limits. The earlier five-second
latency objective is secondary to sustained throughput.

P1 hides input, output and intermediate activations; P3 also hides weights.
D13 still scopes the first MVP to the complete transformer stack. Embedding,
final norm, output head and token selection belong to the following milestone.
No complete private 8B performance result exists yet.

## Measure completed proof work

For N distinct token positions covered by independently verified complete-stack
proofs, record both:

- **Amortized throughput:** N divided by total workload wall time, including
  its initialization, witness work, commitments, proving and serialization.
- **Steady-state throughput:** completed proved positions divided by the
  measured interval after the explicitly recorded startup boundary. Include
  all recurring work, transfers and pipeline drain; do not allow proof backlog
  to grow while counting inference outputs as proved tokens.

Record verification time separately; every counted receipt must verify. Publish
the startup/initial-prefill duration, steady interval, total elapsed time,
proof latency and proof bytes alongside both rates. A warm result does not
claim a cold-start latency result. All tokens are counted once across the
complete stack, never once per layer or once per repeated receipt verification.

For a total-workload >=50-token/s result, the elapsed budget is N / 50:

| Proved positions | Total workload time at 50 tokens/s |
|---:|---:|
| 512 | 10.24 s |
| 1,024 | 20.48 s |
| 2,048 | 40.96 s |
| 4,096 | 81.92 s |
| 8,192 | 163.84 s |

These are arithmetic budgets, not predictions, implemented profiles, or a
required maximum latency. Report the measured startup fraction rather than
calling it negligible without a number.

## Keep the workloads identifiable

1. **Longer single-context prefill:** sweep T from the historical 512 reference
   through 1,024 / 2,048 / 4,096, then larger if the actual layout and memory
   permit. Count T positions; include their forward computation and proof.
   Standard dense attention has T-squared score work, so increasing context
   length need not improve throughput. Larger profiles require shape, range,
   soundness and privacy checks before an accepted result is possible.
2. **Repeated passes with a resident model:** sweep the number of complete
   passes while retaining valid reusable public/model setup. Record context
   length, pass count, concurrency and whether inputs are independent or a
   continuous stream. Total positions = sum of positions newly proved in those
   passes. Several independent contexts are aggregate throughput, not a claim
   that one long context was processed or that a user received tokens that fast.
3. **Later decode stream:** record initial context/prefill separately and count
   only newly generated, proven positions. Include growth of the KV context
   and its proof binding. Do not substitute repeated prefill measurements for
   decode. A continuous stream requires the intended cross-chunk relation to
   be proved; concatenating independently verified outputs is insufficient.

A useful steady slope must be measured across workload sizes, not extrapolated
from the best small kernel. Count every per-proof mask/commitment; larger runs
do not authorize blinding reuse, repeated private commitment openings beyond
their accepted model, or weaker privacy. Record failures and resource limits.

## GPU and evidence

Use **one RTX 5090 as the primary target**, or report a named alternative
high-end GPU as its own result. Record actual accelerator use, device count,
VRAM, host RAM/CPU, driver/build, power settings and transfer/peak-memory data.
The historical <=600 W consumer-GPU rows remain historical comparisons;
alternative-GPU rows disclose their actual configuration. No purchase or
multi-GPU deployment follows from this benchmark direction.

Retain trained checkpoint/config and calibration identity, all transformer
operations, proof/profile/source pins, and independent verification. Follow
the existing p50/p95 discipline for an eventual claim: repeated complete
workloads with the same N, separately labeled cold/warm runs, and no inference
of pass-level p95 from per-layer statistics. Early runs remain n-shot diagnostics.

The next steps are native correctness and the queued 125M diagnostic A/B, then
actual 8B layout/lifetime/traffic accounting and a GPU memory-bounded workload
sweep. The CPU development fixture and hypothetical GPU bandwidth calculations
do not establish the 5090 target.
