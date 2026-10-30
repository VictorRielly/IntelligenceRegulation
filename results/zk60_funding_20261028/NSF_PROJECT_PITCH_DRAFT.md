# NSF SBIR/STTR Project Pitch — draft (for Victor)

Submit at seedfund.nsf.gov ("Submit a Project Pitch"). No company or
registration is needed for the pitch. A reply (invitation or not) usually
comes in 1–2 months. The first realistic full Phase I deadline after an
invitation is **2027-03-04** (up to $305k; ask the program director about
Fast-Track). Topic: **CA9 Secure and Trusted Computing** (alternatives: CA3
Data Privacy and Integrity; AI7 Trustworthy AI). The section limits used here
are NSF's usual ones (3,500 / 3,500 / 1,750 / 1,750 characters); confirm them
on the form. **[VICTOR: …]** = yours to fill in. Every number is MEASURED on
one laptop (RTX 4070 + CPU, one run each). The reviews were internal; there
has been no external audit.

## 1. The Technology Innovation

We are developing zero-knowledge proofs of AI model inference that keep the
input, the output and every intermediate activation hidden. A verifier who
never sees the data can check that a public model, given a hidden input,
produced a stated result: the next token of a language model, or the verdict
of a safety classifier. Today, anyone who wants to check an AI decision must
either trust the operator or receive the private data. Our proofs remove that
choice.

The innovation is a proof system built for transformer arithmetic rather than
general-purpose computation: hash-based polynomial commitments over a 64-bit
prime field, with zero-knowledge masking of every committed activation. It
proves exact integer versions of attention, normalization and the nonlinear
layers. An integer accuracy setup measured within 1.1% of the
floating-point model's perplexity is being built into the prover. We already
prove the trained Llama-3-8B: a private next token in
192 s, verified in 43 s, with a 471 MB proof and about 97 bits of soundness.
The privacy of the runs is checked by a mechanical gate and stated formally.

The first product is verifiable content labels. A platform proves that each
post was classified (explicit, violence, hate) by a specific open safety
classifier under a specific policy, without revealing the post, and the
labels then control distribution, for example keeping explicit content from
minors. General-purpose zero-knowledge virtual machines are orders of
magnitude too slow for this. Specialized systems such as zkLLM prove large
models but target hiding the model rather than the user's data. Our
distinguishing property is a stated, checked privacy guarantee for the
input, the output and every activation.

## 2. The Technical Objectives and Challenges

**Objective 1 — speed.** Move the prover's hot loops to GPU kernels and
measure proved tokens per second at 8B scale; our target is 50 tokens/s on a
single high-end GPU. A first GPU kernel already matches the CPU output byte
for byte; the challenge is the memory bandwidth of commitment hashing.

**Objective 2 — the classifier at production quality.** Prove Shieldstral-1.0-3B
verdicts with zero integer-range refusals and float/integer verdict agreement
on public benchmarks. We have already found and costed one layer's range
problem; the challenge is getting exact integer arithmetic without paying
more in proof size.

**Objective 3 — assurance.** An external cryptographic review of soundness
and zero-knowledge, which today rest on internal reviews; publish the
verifier and specification so others can check proofs independently.

**Objective 4 — scale and privacy.** Keep about 95 bits of soundness at
512-token runs, and design hiding of the weights for cases where the model
itself is confidential.

Risks: GPU memory limits for 8B proofs (mitigated by proving the model
block by block, as the 8B stack already is); a soundness margin at long sequences (measured per
profile); integer fidelity (measured against the float model on standard
benchmarks).

## 3. The Market Opportunity

Online platforms face new duties on harmful content and on minors: the UK
Online Safety Act, the EU Digital Services Act and US state laws. Regulators
increasingly accept privacy-preserving proofs; the EU age-verification
blueprint favours zero-knowledge proofs. Our customers are platforms and
trust-and-safety vendors that must show which model and policy labelled
content, without exposing user data to auditors, plus auditors and AI
providers that need proofs of inference. Revenue comes from per-proof fees, a
licensed prover SDK, and verification services. [VICTOR: any design-partner
conversations.]

## 4. The Company and Team

[VICTOR: company name and status (being formed as a Delaware C-corp), your
background, US citizenship or residency, full-time status.] The founder
designed the system and directs a team of AI coding agents under strict
engineering controls: frozen code trees, independent soundness and privacy
reviews, failing-first tests. That produced about 1,600 commits in 11 months,
with every claim tied to a recorded, reproducible artifact. SBIR funds would
pay for GPU hardware, the external cryptographic review, and the founder's
full-time work.
