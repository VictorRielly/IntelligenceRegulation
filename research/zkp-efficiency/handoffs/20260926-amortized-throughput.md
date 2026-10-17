# 2026-09-26 — sustained throughput with initialization amortized

**User clarification:** larger token workloads may amortize prefill and
initialization toward **at least 50 proved tokens/second**, on an RTX 5090
or another high-end GPU. A 512-token pass and its 10.24-second budget are
reference points, not fixed acceptance constraints. This supersedes the
fixed-window framing in the earlier research budget handoff. No GPU
performance, memory-fit or hardware-purchase recommendation follows here.

The authoritative acceptance clocks are in
[the current target](../../../docs/zkmatrix-poc/ZK60_THROUGHPUT_TARGET.md).
The verified-completion clocks proposed below are an additional, stricter
end-to-end view. Keep them separately labeled from proof-ready throughput
(serialization complete, receipts subsequently verified); they do not silently
add verifier latency to the existing prover-throughput target.

Three different workloads must remain distinguishable:

| Workload | What is repeated or enlarged | What can be amortized | Important limit |
|---|---|---|---|
| One longer prefill | More positions in one causal context, proved through the complete stack | Model setup and fixed per-proof costs | Attention score tensors grow quadratically with context length |
| Repeated fixed-context passes with a resident model | Separate requests through the same complete model/profile | Model loading, reusable model commitments and public caches | Every request still needs its witness and a fresh, complete proof |
| Later autoregressive decode stream | New generated positions sharing an evolving context/cache | Initial prefill and model setup, if their costs are separately recorded | Requires token generation and proved cache/state continuity; current prefill evidence does not establish it |

For a dense attention implementation, growing context from 512 to 4096
positions gives eight times as many positions but 64 times as many score
entries per head. Even an exact triangular causal layout retains quadratic
growth. Thus longer context can increase attention work and memory **per
position**, despite amortizing fixed overhead. Repeated 512-position requests
avoid increasing each request's attention domain; they are a different
workload, with less cross-request context. They cannot be presented as one
long-context computation.

Count `(logical request ID, position)` once, after a complete proof covering
all required transformer blocks, attention and FFN has passed independent
verification. Multiple layers, overlapping windows, cached prefixes,
replayed receipts, failed attempts and a second proof of the same logical
position add no tokens. Independent benchmark requests may reuse input
text, but label the repeated workload and account for fresh computation and
proofs. For decode, count each new position once; do not repeatedly count the
already-proved prefix. Retain D13's distinction between proving transformer
blocks and the later embedding/head/token-selection milestone.

Use two explicit wall clocks, plus phase diagnostics:

1. **Warm sustained clock:** after declared reusable setup, start when the
   first measured request becomes available to the pipeline; stop when the
   last counted request's serialized proof is independently verified.
   Include witness computation, per-request preparation, proving, transfers,
   serialization, verification and pipeline fill/drain within that interval.
   State that the model and specified public caches were already resident.
2. **Full-lifecycle clock:** start before model loading, reusable setup,
   initial prefill and other preparation excluded from the warm clock; stop
   at the same final verification. State whether download/installation is
   outside the workload. A decode lifecycle includes its initial prefill.
   If prefill positions also count in its numerator, report them separately
   from generated positions and count them only once after verification.

For either interval, throughput is accepted positions divided by elapsed
wall time. With overlapping stages, measure the actual interval; summing
overlapped phase durations overstates elapsed time, while dividing by only
the fastest stage understates it. Also report proof-ready throughput and
the separate verify clock to expose a verification backlog. All per-request
work stays on a measured clock: loading a previously computed witness does
not erase the cost of computing it. Identify reusable setup by actual
model/profile/cache identity; do not classify fresh pads, masks, endpoint
commitments or request-specific preparation as reusable initialization.
Retry time remains in the elapsed interval, with failed attempts excluded
from accepted-token counts and rejected artifacts handled under D21.

Arithmetic examples, **not performance predictions**: a verified
4096-position workload reaches 50 positions/s at 81.92 seconds. Thirty-two
verified 512-position requests contain 16,384 positions and need at most
327.68 seconds of measured elapsed time for that rate. If they take exactly
327.68 seconds warm plus 120 seconds of initialization, lifecycle throughput
is about **36.6 positions/s**. Always publish workload size, warm/lifecycle
rates and cold-start cost together; amortization is a declared choice of
workload, not removal of initialization from every claim. Retain run-to-run
latency and the established p50/p95 methodology alongside aggregate rates.

The bounded ladder is: first establish the complete model/profile and its
privacy gates; then compare one, two, four and eight independently verified
requests at the **same supported context and shape**, retaining memory peaks
and actual reusable-cache accounting. Repeated-request privacy composition
and fresh blinding remain required even when each request verifies alone.
Reuse public model preparation only where its existing interface permits;
never reuse per-proof blinding or connect independently accepted endpoint
roots in a way that assumes unresolved D8/D11 composition is solved.

Only after those results should a separately registered longer-context
profile proceed through exact layout/memory counts, integer/range and
softmax checks, honest/tamper verification, masking-budget checks and its
privacy review before device throughput measurements. Doubling context is a
candidate rung, not automatic authorization to allocate a larger existing
shape or claim its privacy. Hardware memory and shared-job limits bound each
run. The currently accepted D22 toy CPU scope is not broadened by this
ladder. The real 8B profile, larger GPU and longer context each need evidence;
no combination of small synthetic runs substitutes for the target proof.

This handoff makes no source, protocol, benchmark or security ruling. No
builds or GPU jobs ran, and explorer-owned state/runtime files were untouched.
