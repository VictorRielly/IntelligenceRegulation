# Y Combinator W27: application answers (2026-11-01; supersedes the 10-28 draft)

**Deadline: Monday 2026-11-02, 8 pm PT** (from the 10-28 research; confirm on ycombinator.com/apply).
- Decisions by Dec 11.
- Terms: $500k, in two parts:
  - $125k for 7% on a post-money SAFE;
  - $375k on an uncapped MFN SAFE.
- No company is needed to apply.
- The batch runs January to March 2027 in San Francisco.

**What only you can do (about 30 minutes):**
1. **Create an account** at ycombinator.com/apply and fill your founder profile. Your LinkedIn and the CV in
   `cv/` cover it.
2. **Record the 1-minute founder video (required).** The script is at the end of this file. A phone camera is fine.
3. **Answer the two items marked `[V]`:** the non-compete / IP question, and the company name if you don't want
   "Hashline".
4. **Paste the answers below and submit.** The question wording follows YC's recent form; match by meaning if the
   live form differs.

**Full-time.** Victor, 2026-11-01: if accepted to a program that needs a full-time founder, "we can figure out how
to make that happen when the time comes". The answers say exactly that.

---

## Founders

**Who writes code, or does other technical work on your product? Was any of it done by a non-founder? Please explain.**
> I do all the technical direction, and AI coding agents write the code. I set the design, make every security and
> privacy ruling, and define the gates each change must pass:
> - byte-identical proof outputs;
> - independent soundness and privacy reviews of each release;
> - a recorded measurement behind every number.
>
> The agents (Claude Code and OpenAI Codex) implement and review under those rules. No other person has worked on
> it. The result is about 1,640 commits since December 2025 and a working prover.

**Are you looking for a cofounder?** Yes. I would welcome a technical cofounder with GPU or cryptography experience.
I will also hire engineers with the funding.

## Company

**Company name:** Hashline [V: change if you prefer another name; no legal entity yet]

**Describe what your company does in 50 characters or less.**
> Proofs of what an AI did, without the data (41)

Alternatives:
- "Zero-knowledge proofs that an AI ran, privately" (47)
- "Prove an AI's verdict without revealing input" (45)

**Company URL:** none yet (leave blank)

**Demo (optional, 3 min).** Skip it unless you record one. A 60-second founder video matters more.

**What is your company going to make? Please describe your product and what it does or will do.**
> We make zero-knowledge proofs of AI model runs. A proof shows that a specific model, given a hidden input, produced
> a specific result. Anyone can verify it, while the input, the output and every intermediate activation stay
> private.
>
> **First product: verifiable content labels.** A safety classifier (Mistral's open Shieldstral, 3B parameters)
> labels each post for explicit content, violence and hate. We publish a proof with each label, and the post stays
> private. A platform can then show users, auditors or regulators, for example under the EU's Digital Services Act,
> that the stated model and policy produced every label, without handing over user data.
>
> **The same prover handles full language models:** it has produced a private next-token proof for a trained
> Llama-3-8B.
>
> **The product:**
> - an open-source prover and verifier;
> - a hosted proving service for platforms that don't want to run GPUs;
> - integrations for trust-and-safety teams, evaluators and auditors.

**Where do you live now, and where would the company be based after YC?**
> Portland, Oregon now; San Francisco after YC.

**Explain your decision regarding location.**
> San Francisco is where the AI labs, trust-and-safety teams and zero-knowledge engineers we want to hire are.

## Progress

**How far along are you?**
> The prover works. Every number below is measured unless marked.
> - **Trained Llama-3-8B, private next token:** proved in 192 s on a laptop CPU, verified in 43 s, 471 MB proof.
>   Soundness is about 97 bits (counted).
> - **Real safety classifier in the app:** private proofs of all three category verdicts for a real post. All 26
>   layers of Shieldstral run in about 7.5 minutes per category on a laptop. The proof record is anchored on Base
>   Sepolia (testnet).
> - **New this week, the Apple GPU backend:** one Llama-3-8B layer over 128 hidden tokens proves in 0.36 s, down
>   from 12 s on a laptop CPU, and proofs are byte-identical to the CPU path. That is about 11 proved tokens per
>   second for a full 32-layer 8B model (computed from the per-layer time), and about 22 with several requests at
>   once.
> - **Privacy:** two privacy statements accepted after independent internal reviews. An external audit has not been
>   done yet.
> - **Next:** port the GPU work to NVIDIA (RTX 5090, then H100), aiming at 50 proved tokens per second for an 8B
>   model on one card.

**How long have each of you been working on this? How much of that has been full-time? Please explain.**
> Since December 2025, part-time alongside my research job, directing AI coding agents. If accepted, I will arrange
> to work on it full-time.

**What tech stack are you using, or planning to use, to build this product? Include AI models and AI coding tools you use.**
> **The prover:**
> - Rust;
> - a hash-based proof system: Ligero-style commitments, sumcheck and LogUp lookups over the Goldilocks field, BLAKE3;
> - Apple Metal GPU kernels, with CUDA next.
>
> **Models proved:** Llama-3-8B, TinyLlama-1.1B, and Mistral's Shieldstral-1.0-3B classifier.
>
> **The app:** Python, with proof anchoring on Base (testnet).
>
> **AI coding tools:** Claude Code (Claude Opus models) and OpenAI Codex (GPT models), run as a small agent team. It
> has implementer, reviewer and researcher roles, a shared resource guard, and byte-identity gates on every change.

**Optional: attach a coding agent session you're particularly proud of.**
Skip, or ask me to export one: for example, the session that batched the GPU sumcheck rounds (about 7% faster,
byte-identical).

**Are people using your product?** No, not yet.

**Do you have revenue?** No.

**If you have already participated or committed to participate in an incubator, "accelerator" or "pre-accelerator" program, please tell us about it.**
> No. I am also applying to Alliance (ALL19).

## Idea

**Why did you pick this idea to work on? Do you have domain expertise in this area? How do you know people need what you're making?**
> AI now makes decisions people cannot inspect: what gets moderated, ranked or flagged, and which model actually
> answered. Today the only ways to check are to trust the operator or to hand the private data to an auditor. A
> zero-knowledge proof removes that choice.
>
> I hold a PhD in applied mathematics with a machine-learning focus. That covers both halves of this problem: the
> mathematics of the proofs and the internals of the models being proved.
>
> **Evidence of need:**
> - Regulation is moving to checkable claims: the EU's DSA transparency reports, the AI Act's documentation duties,
>   and age checks where the EU blueprint prefers zero-knowledge proofs.
> - A competitor, Attestable, raised a $20M seed in August 2026 on the same premise.
>
> We have not yet run paid pilots. Design-partner conversations are the next step, and we are not assuming demand we
> have not seen.

**Who are your competitors? What do you understand about your business that they don't?**
> **Competitors:**
> - Attestable: $20M seed; claims 53 proved tokens/s on one H100; closed source, no paper we could find.
> - Lagrange (DeepProve): a restrictive licence.
> - EZKL and Inference Labs: smaller models.
> - Academic work: zkLLM (CCS 2024).
> - Trusted-hardware attestation (NVIDIA confidential computing).
>
> **Where we stand on speed:** we are about 4.5× behind Attestable's claim, on a Mac rather than an H100.
>
> **What we understand:**
> 1. The first paying uses do not need real-time speed. A content label or an evaluation score is proved once and
>    then travels with the item, so today's speed already supports a product while throughput improves.
> 2. Buyers pay for privacy of the data, not of the model. Our proofs hide the input, the output and every
>    activation, with a reviewed privacy statement. Most zkML work hides the weights instead.
> 3. In verification, open source wins trust. Nobody wants the checker of AI claims to be another black box. We are
>    open-sourcing the whole stack, and selling the hosted service and integrations.

**How do or will you make money? How much could you make?**
> **Revenue lines:**
> - a hosted proving service, priced per proof, for platforms and trust-and-safety vendors that need auditable
>   moderation;
> - enterprise integrations and support;
> - verification for auditors and evaluators (proved scores on hidden test sets);
> - later, proofs of inference for AI providers (provenance and compliance).
>
> **Market size:** trust and safety alone is a multi-billion-dollar software market, and regulation is pushing it
> toward auditable decisions. If proofs become the standard attachment to AI decisions, the hosted proving layer is
> a large infrastructure business.

**Which category best applies to your company?** B2B → Security (alternative: Infrastructure / AI).

**If you had any other ideas you considered applying with, please list them.**
> **Proved evaluation scores:** "model M scored S on hidden test set T", so evaluators can keep test sets secret
> while publishing checkable results.

## Equity

**Have you formed ANY legal entity yet?** No. A Delaware C-corp will be formed if accepted.

**Are any of the founders covered by non-competes or intellectual property agreements that overlap with your project?**
[V: answer truthfully. Your research employment and any new employer's invention-assignment terms matter here. If
unsure, write: "I am a postdoctoral researcher. My employment agreement has no non-compete, and this project is
independent of my employer's work, done on my own time and equipment." Use that only if it is true.]

**Have you taken any investment yet?** No.

**Are you currently fundraising?** Not from investors. I am applying for non-dilutive research grants (AI-safety
and open-source funders) for open-source work and an external security review.

## Curious

**What convinced you to apply to Y Combinator? Did someone encourage you to apply?**
> YC funds technical founders early, before revenue, and its network includes the platforms and AI companies that
> would use verifiable AI decisions.

**How did you hear about Y Combinator?** [V: one line; e.g. "I've followed YC for years."]

---

## Founder video script (1 minute; you on camera)

> Hi, I'm Victor Rielly. I'm an applied mathematician with a PhD from Portland State.
>
> AI systems now decide what gets moderated, ranked and flagged, and nobody outside can check them without seeing
> private data.
>
> I built Hashline: zero-knowledge proofs that a specific AI model produced a specific result, while the input and
> output stay hidden. We've proved a private next token for Llama-3-8B, and real safety-classifier verdicts on posts.
> This week our GPU backend got one 8B layer down to a third of a second, about 11 proved tokens per second for the
> full model. The closed competitor claims 53.
>
> Next: NVIDIA GPUs, open source, and the first platforms. Thanks.

That is about 130 words, roughly 55 seconds at a natural pace.
