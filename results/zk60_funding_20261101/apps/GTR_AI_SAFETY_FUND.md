# GTR AI Safety Fund (Global Technology Risk Foundation, Berlin): proposal

**Why this one is fast.**
- Rolling, with "initial feedback, either a decision or an invitation to a call, within 21 days".
- Individuals at any career stage can apply; there is no geographic focus.
- Its named areas include "international agreements and verification mechanisms" and "cybersecurity".
- It funds compute and hiring support.

Read on 2026-11-01: `NEW_SOURCES_AI_GOV.md` §3.1.

**What to submit** (the Apply section of https://www.gtr-foundation.org/gtr-ai-safety-fund):
1. **The proposal** below, as a PDF of 1–3 pages: `GTR_PROPOSAL.pdf`, made from the text between the lines.
2. **A CV:** `../cv/Victor_Rielly_CV_grant.pdf`.

Uploads are capped at 10 MB.

**The ask.** $300,000 for 12 months, minimum $150,000. The fund gives no range, so the proposal states a clear plan
with a smaller option.

**Open question.** Whether a German gGmbH can pay a US individual is not stated. If they ask, offer a fiscal sponsor
(kit §9).

---

# Hashline: cryptographic verification of AI model runs, without disclosing the data

**Victor Rielly** · victor23@pdx.edu · Portland, Oregon, USA · linkedin.com/in/victor-rielly-50508b3a

## 1. The work, and the problem it addresses

Agreements and audits about advanced AI depend on claims that outsiders cannot check:
- which model was evaluated, and what it scored;
- whether the model deployed is the one that was audited;
- what a safety filter decided.

Today a checker must trust the operator, see the private data (user content, test sets, prompts), or rely on secure
hardware, which moves the trust to a chip vendor and its supply chain. None of these scales to verification between
parties that do not trust each other, such as labs, auditors, insurers or governments.

**Hashline is a zero-knowledge prover for transformer inference.**
- **What a proof shows:** a stated model, run on a hidden input, produced a stated result: a next token, a
  classifier's verdict, or an evaluation score.
- **Who can check it:** anyone.
- **What stays hidden:** the input, the output and every intermediate activation. The verifier learns only the facts
  the owner chooses to publish.
- **What it rests on:** a standard hash function. There is no trusted setup and no secure hardware, and soundness is
  counted at about 97 bits per run.

**What works today** [measured, single runs unless noted]:
- **Trained Llama-3-8B, private next token:** proved in 192 s on a laptop CPU, verified in 43 s. 65 of 65 tampered
  proofs were rejected.
- **A real 3B content-safety classifier (Mistral's Shieldstral):** private proofs of its verdicts on a post, all 26
  layers, anchored on a public testnet.
- **A new GPU backend:** one 8B-sized layer over 128 hidden tokens proves in 0.36 s on one Apple GPU, down from 12 s
  on a laptop CPU. That is about 11 proved tokens per second for a full 32-layer model (computed from the per-layer
  time). The target is 50.
- **Privacy:** two privacy statements accepted after independent internal reviews. There has been no external audit
  yet.

**The 12-month plan:**
1. **NVIDIA GPUs:** port the GPU prover to NVIDIA (RTX 5090, then H100), with proofs byte-identical to the CPU
   reference. Target: 50 proved tokens per second for an 8B model on one card. Throughput is measured and published
   either way.
2. **Open release:** release the whole stack under a permissive licence: prover, verifier, a specification of the
   proof system and its privacy statement, and reproducible benchmarks.
3. **External review:** commission an external cryptographic review of soundness and zero-knowledge, and publish it
   with our fixes.
4. **Verification uses:**
   - proofs of evaluation scores on hidden test sets, so an evaluator can publish a checkable score while keeping its
     test items secret;
   - proofs of which model produced an output.
5. **Hidden weights (version 2):** design it, so a lab can prove facts about a confidential model. That is the step
   that verification of frontier systems needs.

## 2. Background, what I have built, and why AI safety matters to me

- **Education:** PhD in Applied Mathematics (Portland State University, 2025, machine-learning emphasis); B.S. in
  Mathematics and Physics (Pacific University, salutatorian).
- **Research:** papers in the Journal of Computational Physics and TMLR, a third accepted in a SIAM journal and two
  under review. They are on kernel methods that learn differential equations from data. I am a postdoctoral
  researcher at the Translational Genomics Research Institute.
- **Earlier work:** R&D at Intel and NASA, and three years as lead engineer of a networked IoT device.
- **Hashline:** since December 2025 I have led its design, made every security and privacy ruling, and directed a
  team of AI coding agents under strict rules: byte-identical outputs, independent soundness and privacy reviews of
  every release, and a recorded measurement behind every number. That is about 1,640 commits.

**Why AI safety:** as AI systems take on decisions that matter, the ability to check what they did, without
surveillance and without blind trust, becomes basic infrastructure. In 2023 I wrote a research proposal on provably
safe language models. Hashline is that interest made concrete. I would rather the verification layer of AI governance
be open and reviewable than owned by one company. The only fast competitor I know of is closed source.

## 3. Why GTR, and other funding

**What the work needs.**
- **People.** I keep my current job and lead Hashline part-time; the grant pays me nothing. It hires:
  - a GPU and zero-knowledge engineer (full-time contract, $150,000);
  - a quarter-time applied cryptographer ($50,000).
- **An external review:** $50,000.
- **AI agents and cloud GPU time:** $30,000.
- **Administration:** $20,000.
- **Total: $300,000 for 12 months.** A $150,000 option (a half-time engineer plus the review) delivers items 1–3.

**Why GTR.**
- **Scope:** GTR names verification mechanisms for international agreements.
- **Who it funds:** individuals early.
- **What it covers:** compute and hiring support, which is what this project lacks.
- **The gap elsewhere:** most AI-safety funders have no open call this month, and zero-knowledge ecosystem funds
  require building on their own blockchains.

**Other funding.** None received. Applying in parallel to:
- EA Funds (Transformative AI Fund);
- Lightcone Commons;
- NLnet;
- Y Combinator and Alliance (equity, for the product side).

If two funders cover the same budget line, I will tell both and take only one.

**References:**
- Bruno Jedynak (Portland State University), bruno.jedynak@pdx.edu
- Kamel Lahouel (TGen), klahouel@tgen.org
