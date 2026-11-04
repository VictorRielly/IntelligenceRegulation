# Lambda Research Grant: starting answers (up to $5,000 of H100 cloud credits; rolling)

**Form.** https://form.typeform.com/to/Wn8YWMIj (linked from https://lambda.ai/research).
- The field list below was read from the form's definition on 2026-11-01. No character limits were shown.
- These are starting answers; rewrite as you like.
- The decision time is not stated. Aggregators (UNVERIFIED) say a Lambda Cloud account needs phone verification and a
  card on file.

**Contact information:** Victor Rielly · [phone: kept in local files only] · victor23@pdx.edu · Company: Hashline (optional field)

**Related publications:**
- arxiv.org/abs/2206.15215
- arxiv.org/abs/2306.10189
- arxiv.org/abs/2503.13791

The prover itself is private until release; a demo is available on request.

**Research problem:**
> Can anyone check what an AI model did without seeing the private data it ran on? I am building zero-knowledge
> proofs of language-model inference. A proof shows that a stated model, given a hidden input, produced a stated
> output, while the input, the output and every intermediate activation stay hidden. That makes AI claims checkable:
> audits, evaluation scores on hidden test sets, content-moderation decisions.
>
> Success means 50 proved tokens per second for an 8B model on one GPU, from an open-source prover with a published
> benchmark.

**Relevance and novelty:**
> **Related work:** zkLLM (CCS 2024) mainly keeps model weights private and needs minutes per inference. EZKL handles
> small models. DeepProve (Lagrange) is under a restrictive licence. Attestable claims 53 tokens/s on one H100 but is
> closed source.
>
> **What is new here:**
> - it hides the user's data, with a reviewed privacy statement;
> - it is hash-based, with no trusted setup;
> - its soundness is counted (about 97 bits per run);
> - it will be fully open source.
>
> On an Apple M3 Ultra GPU, one Llama-3-8B-sized layer over 128 hidden tokens now proves in 0.36 s, about 11 proved
> tokens per second for the full model.

**Challenges:**
> - Porting the GPU kernels to CUDA while keeping every proof byte-identical to the CPU reference.
> - Memory bandwidth in the commitment step (Reed-Solomon encoding and Merkle hashing).
> - Measuring honestly on H100-class hardware so results can be compared with closed systems.
> - Non-technical: a small team, and the work of building trust through an external review.

**GPU compute needs (a number):** **1,000** H100 hours.
> These hours cover the CUDA port's development and benchmarking:
> - correctness gates on H100;
> - a throughput ladder (128 to 512 tokens; one to several concurrent proofs);
> - the published benchmark run.
>
> Together they give the first H100 measurement to set against the closed competitor's claim.

**Notable achievements:**
> - The first private next-token proof of a trained Llama-3-8B that I know of: 192 s on a laptop CPU, verified in
>   43 s.
> - Private proofs of a real 3B safety classifier's verdicts.
> - A 34× per-layer speedup moving the prover from a laptop CPU to an Apple GPU, with byte-identical proofs.
> - Peer-reviewed papers in the Journal of Computational Physics and TMLR.

**GitHub / Google Scholar / social:** [V: your profiles, if any]. LinkedIn: linkedin.com/in/victor-rielly-50508b3a

**Partnerships and support:** Research collaborations at Portland State University and TGen. R&D internships at Intel
and NASA.

**Roadmap:**
1. Month 1: CUDA kernels pass the byte-identity gates on H100.
2. Month 2: a full 8B throughput measurement on H100.
3. Month 3: the open-source release with reproducible benchmarks.
4. Month 4 onward: an external security review, and a preprint.

**Publishing plan:**
> The whole stack is released under a permissive open-source licence, with an IACR ePrint preprint and a submission
> to a peer-reviewed security venue. The benchmark scripts and results are public.

**Willing to co-write a blog for Lambda's research page?** Yes.
