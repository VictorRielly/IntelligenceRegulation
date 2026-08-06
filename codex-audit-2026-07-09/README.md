# Independent technical audit of the zkMatrix / transformer-proof work

Audit date: 2026-07-09  
Audited commit: `9fea0a5620679aa484dce3edaff9deae65b0def8`  
Branch: `perf/zk-batch-optimizations`

This folder is an independent review of the repository as it existed on the
date above, including the uncommitted Route R R1 masking work that was being
edited during the review. Nothing outside this folder was changed by this
audit.

## Bottom line

The repository contains unusually substantial proof-of-concept work for its
age: several independent matrix-proof backends, transcript-binding repairs,
negative tests that demonstrate real attacks, an end-to-end toy quantized FFN,
a new ring/lattice performance route, parameter scripts, and documentation that
often records failures rather than hiding them. Those are meaningful research
assets.

It is **not**, however, presently a proof of a transformer feed-forward, an
8-billion-parameter demonstration, a production-secure zero-knowledge system,
or evidence for a five-second prover. The current work should be described as a
research prototype with unresolved soundness, zero-knowledge, completeness,
implementation-security, and performance questions.

The most important blockers are:

1. The repository's own M4 review identifies a chain-wide slot-constancy hole
   in composed Hadamard use. This affects the Llama-style `gate o up` product,
   not just the proposed SiLU construction.
2. The committed Route R quadratic layer at the audited commit leaks witness
   images; for the committed-executions gate the documented attack recovers the
   product matrix. The live worktree now contains an uncommitted R1 pad
   implementation plus leak/order regressions, but it is a protocol change that
   has not been committed, independently reviewed, or recosted at scale.
3. There is no implementation of attention, softmax, RMSNorm/layer norm,
   RoPE, a multi-layer transformer DAG, an 8B model, or a GPU proof backend.
4. The latest complete activation costing projects roughly **35-55 seconds**
   for the reference pass even after assumed GPU acceleration. The five-second
   figure appears only after further unimplemented lookup/packing gains in an
   older ladder.
5. The Rust performance path uses deterministic SplitMix64 secrets and
   floating-point, branchy Gaussian/rejection sampling. It is explicitly
   prototype code, not safe cryptographic software.

## Goal scorecard

| Requested property | Status in this snapshot | Evidence-based assessment |
|---|---|---|
| Prove one feed-forward through a transformer | **Not implemented** | The best complete demo is one tiny FFN block; attention and normalization are absent. |
| 8B-parameter model | **Not demonstrated** | Cost models use a Llama-7B-class 6.7B reference; no model trace is generated or proved. |
| Five seconds or less | **Not demonstrated; current model misses** | No proof GPU backend exists. Latest activation-inclusive model is 35-55s under assumed GPU factors. |
| Zero knowledge | **No at audited commit; candidate fix in worktree** | The project proves the old garbage-image leak. The live R1 work now has targeted regressions, but not independent proof/audit or a committed release. |
| Secure | **No production claim support** | Custom protocol, classical model-based parameter review, insecure benchmark RNG/samplers, no parser or deployment setup. |
| No more computationally expensive than inference | **Not demonstrated and literally ill-posed for total prover time** | A prover must at least compute the witness. The useful target is added proof overhead on identical hardware. |

## What I would keep

- The negative-test culture and explicit attack demonstrations.
- The manifest-first transcript discipline as a design principle.
- The separate pairing, Route Z, and Route R tracks until an evidence-based
  architecture decision is made.
- The quantized-integer statement discipline: prove an exact declared model,
  and measure model-quality equivalence separately.
- The parameter and algebra harnesses, provided they are treated as checks of
  examples/formulas rather than substitutes for cryptographic review.

## What I would not claim publicly yet

- “Transformer inference proved,” “8B proved,” “five-second prover,”
  “production zero knowledge,” “post-quantum secure,” or “proof overhead no
  greater than inference.”
- That a document marked `[PROVEN]` is formally verified or peer reviewed.
- That the 20x GPU row is measured; it is an assumption applied to CPU anchors.
- That R1 costs about 1.5KB per committed-executions gate. The current code adds
  a complete wide commitment and opening in that path.

## Contents

- [REPOSITORY_MAP.md](REPOSITORY_MAP.md) — what is actually implemented.
- [FINDINGS.md](FINDINGS.md) — prioritized errors and gaps with evidence.
- [SECURITY_REVIEW.md](SECURITY_REVIEW.md) — cryptographic and implementation-security review.
- [PERFORMANCE_REVIEW.md](PERFORMANCE_REVIEW.md) — five-second feasibility and measured-vs-modeled separation.
- [TEST_EVIDENCE.md](TEST_EVIDENCE.md) — commands, initial failures, and final live-fix results.
- [RECOMMENDATIONS.md](RECOMMENDATIONS.md) — a gated plan from research prototype to a credible POC.
- [SNAPSHOT.md](SNAPSHOT.md) — exact review boundary and concurrent-edit caveat.
- [FIXES_VERIFIED.md](FIXES_VERIFIED.md) — regressions found during review and the live fixes Fable added.
- [REFERENCES.md](REFERENCES.md) — primary external sources used for context.

## Overall recommendation

Continue only with milestone gates. First close and independently review R1,
close slot constancy and integer non-wrap for a composed chain, define a real
verifier/statement format, and remeasure the resulting proof. In parallel,
benchmark a lookup/sumcheck-oriented alternative for nonlinear layers. Do not
fund an 8B/GPU scaling push until a single complete transformer block is both
sound and zero knowledge and its recosted bandwidth/operations model leaves a
credible path to the latency target.
