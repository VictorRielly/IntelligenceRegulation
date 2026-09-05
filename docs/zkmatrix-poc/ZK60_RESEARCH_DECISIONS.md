# ZK60 R2 — research decisions for a complete private proof

Reviewed 2026-09-04 PDT by the Codex research/security worker, not Fable
or Claude. Source baseline: `19ebd18` plus the integrated C0/round-1
snapshot in `/tmp/zk60-round2-oNXEVd/research`. This lane changes only
this document. It follows [round 2](ZK60_PARALLEL_ROUND2.md), the
[private-block plan](ZK60_PRIVATE_BLOCK.md) and
[execution contract](ZK60_EXECUTION.md).

## Decision

Keep the current hashline implementation and finish the tiny, fixed-policy
P1 private-block path. In parallel, test whether **one causal execution of
a completed sequence** matches our frozen integer semantics exactly. Treat
commitment avoidance as a measured, later protocol experiment, not an
immediate rewrite or an assumed speed multiplier. Keep reusable private
weight commitments behind a separate security/design gate.

The practical product remains a short response followed by a delayed proof
receipt. This does not establish proof-before-release of each token, and
neither current FFN coverage nor a standalone equality gadget constitutes
a complete generation proof.

## Evidence levels and comparison

**Paper** means the specified text was inspected, not its theorem independently
proved. **Abstract** is narrower. **Vendor/README** means an author's report.
**Source** means the described implementation was read, not executed or
audited. **Reproduced external results: none.** No external benchmark,
model download, dependency installation or external source-code import was
performed. GitHub links below are moving `master` snapshots, not pinned
build artifacts; a future reproduction must first record immutable revisions.

| System / evidence | Relevant scope | Security/privacy boundary | Timing/readiness boundary |
|---|---|---|---|
| DeepProve: abstract, engineering article, selected source | Completed causal sequence; backward claim composition | Inspected default PCS is pairing-based; clear-prompt driver is not evidence of private prompt support | Published clocks below differ; code warns unaudited |
| Attestable: vendor article | One proof after decoded sequence | Claimed private committed weights and hash-only 100-bit security; not independently validated here | Single-H100 claims, no reproduced clock or post-decode lag |
| Scorpius: revised paper | Repaired hash-based PCS, including batched evaluation | Conditional outer commit-and-prove SNARK; repeated Eval is explicitly not the ZK interface | PCS construction, not a complete LLM prover or GPU speed result |
| zkLLM: paper | Tensor lookup / attention and model-inference experiments | Hyrax/Pedersen, discrete-log assumptions; quantization/approximation contract | Fixed-sequence inference benchmark, not demonstrated receipt-ready generated-token throughput |
| ZKTorch: paper | Specialized block compiler and parallel accumulation | KZG/pairings/SRS; private inputs or weights | Useful composition comparison, not evidence for our hash-only performance target |

### DeepProve: useful architecture, materially different implementation

The [2026/1112 abstract](https://eprint.iacr.org/2026/1112) reports full
GPT-2/Gemma-3 sequence certification, 174/86 tokens per minute respectively
(2.90/1.43 per second), and 1,855 per minute distributed. These are author
claims, not our measurements; the distributed figure is not a one-GPU
result. The PDF failed to load through the research tool, so this review
does **not** claim to have checked its full theorem or experimental section.

The [August 3 engineering article](https://lagrange.dev/engineering-updates/inside-deepprove-proving-an-llm-end-to-end)
describes a causal forward pass over a completed prompt/response and checks
that predictions match subsequent claimed tokens. Its backward GKR flow
passes evaluation claims between layers instead of committing intermediate
activations; model parameters and lookup witnesses still have commitments.
This is the architectural idea to test, not evidence that deleting our
existing activation roots preserves soundness or privacy.

In the inspected [LLM driver source](https://github.com/Lagrange-Labs/deep-prove/blob/master/zkml/src/model/llm.rs),
`run_elements_with_runner` reruns the completed sequence for its trace.
`LLMVerifierContext::verify` invokes proof verification, checks the supplied
prompt against proof input, and checks shifted input/output token equality.
This corroborates the sequence strategy beyond a prose claim. Its
`user_input: Vec<Token>` interface also makes the prompt visible to that
verifier. Endpoint, EOS, padding and malformed-input behavior were not
audited; source presence is not proof of comprehensive correctness.

The [implementation README](https://raw.githubusercontent.com/Lagrange-Labs/deep-prove/master/zkml/README.md)
warns that it is unaudited and not production-ready. It describes default
12-bit symmetric quantization, HyperKZG, and BN254 for GPU proofs. Its
CPU table uses 24 cores/504 GB RAM and reports 512-context GPT-2 at 458.4 s
proving (1.12 tokens/s), Gemma-3 at 1,137 s (0.45 tokens/s), with 1.33/4.32 s
verification. Those README results and the abstract are different reported
artifacts, not interchangeable baselines. Accuracy after quantization is
not equality to our approved integer computation.

The [benchmark source](https://raw.githubusercontent.com/Lagrange-Labs/deep-prove/master/zkml/src/bin/bench/llm.rs)
times inference separately, calls the prover, serializes afterward to measure
size, then verifies the same in-memory proof object. Its displayed rate is
maximum context length divided by recorded proof time; it is not the number
of newly generated tokens divided by end-to-end receipt readiness. Do not
compare that numerator/denominator directly to our witness-through-written-
artifact clock or to generated-token latency.

The source is publicly readable, but its
[custom license](https://raw.githubusercontent.com/Lagrange-Labs/deep-prove/master/LICENSE)
limits permitted uses and restricts derivatives/distribution. It is not a
permissively licensed drop-in. Study the described ideas; obtain an explicit
rights review before importing code. No code was copied by this review.

### Attestable: the closest target claim, not an available recipe

The [vendor article](https://attestable.com/blog/proving-llms-scale)
reports Gemma 4 31B at 53 tokens/s for batch one with a 16K sequence, and
77 tokens/s across four 4K sequences on one H100. It explicitly produces
one proof after a sequence has decoded. Across successful configurations,
it reports 4.35–7.92 MiB proofs and 157–648 ms CPU verification. It claims
hash-only 100-bit security and committed-model execution with bound policy
and randomness. These security and performance claims are **not reproduced
or independently certified here**. Arithmetic uses dynamic INT8 linear
operations with floating nonlinearities, unlike our frozen integer path.
The inspected article provides neither prover source/license nor enough raw
timing evidence to establish witness/serialization inclusion, overlap cost,
or post-decode proof lag. Its 77 figure is aggregate throughput, not one
request's decoding speed. It supports investigating delayed receipts, not
asserting that our current design already meets 60/s.

### Scorpius: an explicit warning against unbounded private reuse

The [ePrint record](https://eprint.iacr.org/2024/1164) lists 2025-02-14 as
the latest revision and specifically notes revised zero-knowledge coding.
Use that revision, not unrepaired Orion or an older ZK-code sketch.

In the [revised paper, sections 4.5, 4.7 and 5.1](https://eprint.iacr.org/2024/1164.pdf),
Theorem 4 assumes a suitable randomized code **and** a complete,
knowledge-sound, zero-knowledge outer commit-and-prove SNARK. Section 4.7
explicitly rules out running Eval repeatedly while retaining its ZK goal;
the multipoint extension combines evaluations into **one** Eval. Section
5.1 treats Fiat–Shamir/domain separation, but leaves detailed security-loss
analysis for the full resulting zk-SNARK to future work. The paper links
attack code; this review did not establish a production Scorpius prover
implementation or its code license. These conditional results do not
certify hashline's masks, concrete query parameters or full composition.

**Application inference:** batching terminal claims in a one-shot proof and
reopening a cached secret model across adaptive receipts are different
interfaces. A stable public model label does not solve the latter. Retain
P1 independently registered public roots now; Fable's P3 review must specify
the consistency relation and cumulative-opening privacy before a cached
private W commitment becomes an accepted optimization.

### Two secondary decisions: lookup specialization and accumulation

[zkLLM sections 3, 7 and 8](https://arxiv.org/html/2404.16109v1) use
Hyrax/Pedersen commitments and zero-knowledge sumchecks, with attention
approximation and quantization error in the relation. Experiments use
2,048-token C4 sequences and one 40 GB A100; model commitment is timed
separately from proving. The paper's full-inference claim is not a measured
autoregressive receipt pipeline. Its useful lesson here is specialized
lookup/attention work and explicitly separated preprocessing, not a
replacement for our exact exp table or a hash-only theorem. External code
and license were not inspected in this bounded review.

[ZKTorch sections 2–3](https://arxiv.org/html/2507.07031v2) describe a
specialized-block compiler, KZG commitments to tensors and parallel Mira
accumulation. The construction uses pairing assumptions and an SRS; it
does not eliminate intermediate commitments in the DeepProve manner.
Private-input/weight support is a paper claim, not an implementation audit
here. Code/license and benchmark-clock reproduction were not investigated.
Use it to compare composition interfaces later; changing PCS/security
assumptions solely for proof compaction is outside this round.

## Conditions for completed-sequence equivalence in hashline

The following is our proposed correctness contract, inferred from causal
execution, not a theorem imported from another prover.

For every continuation position, the complete-sequence execution must yield
the exact same logits as executing the corresponding prefix under the
approved model. Checking the committed next token against those logits can
then certify the continuation. Establish all of these conditions first:

- Fix weights, quantization, tables, operation order, signed division and
  rounding. `fit_requant`, `fit_norm` and `derive_ffn_on` cannot silently choose
  new constants from the completed witness; sequence-length-dependent
  calibration can break prefix equivalence.
- Bind causal support, position/RoPE offsets, GQA mapping, window state and
  padding. Appending a future suffix must not change earlier valid rows.
  Preserve our integer softmax and its exact max/attainment semantics.
- Add the missing embedding, final norm/head and token-selection relations.
  Check continuation predictions, not arbitrary predictions of supplied
  prompt tokens. Specify empty prompts, EOS, truncation and argmax ties.
- Start with deterministic argmax. Supporting sampling needs a proven PRG,
  seed/counter-consumption and selection rule; a seed in a header alone is
  not that relation. Context and output disclosures need their own policy.
- Bind the user request/output to independently approved statements, not
  unauthenticated objects chosen by the proof producer. Private prompts
  require commitments/relations instead of the clear-token comparison used
  in the inspected DeepProve driver.

One certification pass avoids re-proving every prefix. It does **not** make
our dense score/PV workload linear in sequence length: existing attention
score planes scale with `heads * T * T`. Measure that cost and private
opening growth; do not extrapolate a general linear-speed claim to this
implementation.

## Five bounded experiments, in order

These were proposed follow-on tasks at the research handoff. The lead's
same-round E1/E2 progress is recorded below; remaining rungs are not run.
They do not reassign another worker's files or authorize production flags.

| Experiment | Smallest useful implementation / owner | Acceptance and decision |
|---|---|---|
| E1: exact causal oracle | Correctness lane after A00: a new `hashline/tests/zk60_sequence_equivalence.rs`; compare existing attention/FFN witness planes at T=1/2/4 under fixed constants, then extend through embeddings/head when A10 exists | Prefix vs full-sequence rows agree bit-for-bit; future-suffix mutation cannot alter past logits; wrong position, rounding, scale, EOS and tie policy reject. Before endpoints exist, label this a block oracle, not generation certification. |
| E2: private seams and opening lifecycle | Current S2 `private_seam.rs`, then A03 pending API around `zk::prove_layer_zk_v3`; integrator owns source, independent security reviewer checks it | Both roots/context precede challenges; every claim has a reserved independent mask; unequal rebuilt witnesses reach verifier rejection; exact counts, wrong roots/slots/context, extra data and reopen/double-finalize fail. Account for total opened information and actual code distance. Tests are not a simulator/composition proof. |
| E3: selective commitment avoidance | After a correct private-block baseline and phase attribution: isolated two-matmul/FFN toy with backward evaluation claims; proposed new experimental module, no `pcs.rs` rewrite | Same fixed integer relation and range/lookup checks; explicit root/challenge schedule and privacy argument. Measure encoded bytes, hashes, masks, total proof bytes and wall time actually removed. Stop if commitment savings move equivalent cost into lookups/openings or break privacy. |
| E4: stable private-model lifecycle | Fable's reserved F1 review; later a separately owned `hashline/tests/zk60_private_commit_reuse.rs` and reviewed identity relation | Distinguish one batched Eval from many receipts; specify adaptive-query leakage and masks over the full lifetime. Fresh per-proof W must be proven consistent with independent approval. Rebuilt alternate weights and registry/table/mode substitutions reject. Keep existing P1 boundary and P3 refusal intact until this is solved. |
| E5: receipt-ready clocks | Collector/integration lane: extend `scripts/hashline_benchmark.py` only when a framed sequence receipt exists | Record prompt/continuation/context counts separately; input-to-decode, input-to-proof-ready, post-decode lag, artifact serialization and independent decoded verification. Report cold + at least 20 warm rows, p50/p95, one-GPU inference/proving contention and actual coverage. |

Run E1 and independent E2 review now; finish A03–A08 before declaring a
private-block chain. Keep the exact CPU witness work and Claude's bounded-
memory GPU lane independent. Start E3 only if merged phase evidence shows
commitments warrant the protocol cost. E4 must not hold up the first P1
receipt. E5 then extends through A10 to full generation; the existing
512-row prefill milestone and generated-token throughput remain separate
metrics. No multiplicative product of microbenchmark or vendor speedups
predicts the final result.

### Same-round experiment progress

E1 now has a fixed-calibration **T32** attention/FFN/residual witness
builder and bounded suffix-causality tests, not the originally suggested
T1/2/4 comparisons. T32 supports A00's unchanged 256-check PCS width;
smaller shapes, variable-length decoding, logits/token choice and a proof
remain unimplemented. See [the causal oracle](ZK60_CAUSAL_ORACLE.md).
E2 has an experimental one-shot full-plane equality proof and exact framed
decoder, verified from bytes in a separate process. It is not connected
to actual FFN/attention arithmetic commitments, and its joint-transcript
security proof is still required. See [the seam report](ZK60_PRIVATE_SEAM.md).
E3–E5 remain proposals. The inherited masking finding below is a required
gate before private application use, not an optimization to postpone.

## Handoff and remaining uncertainty

The initial research lane added only this document. Validation was read-only source/document
inspection and primary-source browsing; no Rust/Python tests were needed
for this documentation-only lane, and no external performance was measured.
The DeepProve full paper PDF and an immutable repository revision were not
successfully obtained. Its code was inspected selectively, not audited.
No source here establishes production readiness or a whole-proof 100-bit
claim for our private block. Next useful work for this worker is independent
review of S2's algebra, transcript framing and opened-information budget.

## Follow-on S2 review and inherited interface diagnostic

After the research handoff, the same worker reviewed the new S2 module
read-only. It found no obvious acceptance flaw in the degree-2 extended
equality relation, commit-before-challenge schedule or fixed frame. It
requested a canceling two-position witness mutation; the lead added that
test. This was source review, not a whole-proof simulator/security audit.

The review checked the local masking budget: paired terminal rows span
Fp2 for nonzero coefficients; three otherwise unused base proximity rows
give a random 2x3 matrix with ideal-uniform rank failure probability
p^-2+p^-3-p^-5. Pads cover at most Q distinct columns in this one-shot
interface. S2's actual hiding encoding has 512/2048 rate. Challenge/RNG
distributions and the joint full transcript still need a security proof.

It also identified an **inherited PCS-interface privacy hazard** and ran
a bounded diagnostic, now preserved as `hashline/tests/zk60_mask_rank.rs`.
A verified singleton `ZClaim` with one private base row A and one base mask
R publishes `v=lambda*((1-e)*A+e*R)` in Fp2. For public e=e0+U*e1 with
e1 nonzero, writing w=v/lambda gives A=w0-(e0/e1)*w1, coordinatewise.
The test reconstructs four private row entries from the public clear
vector and transcript coefficients, without receiving a seed or mask.
An independently paired Fp2-mask control blocks this specific extraction.

The scratch diagnostic used tiny parameters (n=4,Q=4,inverse rate=8), a
genuine commitment, opening and successful `pcs::verify_zk`. The issue is
algebraic and does not require breaking Merkle hashes or repeated queries.
The worker ran two CPU tests successfully against the existing unchanged
PCS implementation; the lead also passed both in the integrated suite.
This is **not yet a reproduced full-FFN proof extraction**, and multiple
claims/masks in a group require their own rank analysis. Passing this
regression records a known hazard; it does not certify privacy.

Priority before sensitive application use: enumerate actual FFN/attention
opening groups, determine their joint mask rank and exposed functionals,
and introduce reviewed, versioned fixes wherever needed. S2 already uses
paired terminal masks, but neither it nor this diagnostic repairs other
callers. Preserve frozen legacy bytes as fixtures without treating them
as deployed privacy evidence. Fable's independent review should include
this audit alongside P3 model-identity consistency.

One source-comment discrepancy matters for that review: `pcs::zk_rhos`
draws BOTH group and proximity coefficients before absorbing either clear
vector. The prose comment on `open_zk` describes a different chronology;
reason about the code's order, not the comment. This round does not change
that PCS function or its transcript.
