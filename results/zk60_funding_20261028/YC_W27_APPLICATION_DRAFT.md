# YC Winter 2027 — application draft (for Victor to edit and submit)

Deadline: **Monday 2026-11-02, 8 pm PT** (several sources agree; confirm on
ycombinator.com/apply). Decisions by Dec 11. Terms: $500k ($125k for 7% on a
post-money SAFE + $375k uncapped MFN SAFE). No company needed to apply.

Drafted by Claude (coordinator) from the repo's recorded evidence, 2026-10-28.
Question wording follows YC's usual form; the live form may differ. Every
number below is MEASURED on one laptop (RTX 4070 8 GB + CPU, shared box,
n=1) unless marked. **[VICTOR: …]** = only you can fill this in.
Do not claim anything beyond these lines; soundness and privacy were reviewed
by independent internal reviewers, not by an external audit — say so if asked.

---

## Company

**Name:** [VICTOR: company name]

**What does your company do? (≤ 50 characters)**
- "Zero-knowledge proofs that an AI ran — privately" (48)
- alt: "Proof an AI checked content, without seeing it" (46)

**What is your company going to make?**
We make zero-knowledge proofs of AI model runs in which the input, the output
and every intermediate activation stay hidden. Anyone can check the proof, and
it reveals only the facts the owner chooses to publish. The first product is
verifiable content labels: when a post is created, a safety classifier
(Mistral's open Shieldstral-1.0-3B) labels it for explicit content, violence
and hate. We publish a proof of each label, and the content stays private. A
platform can then prove to users, auditors or regulators that a given model
and policy produced each label. The labels also drive distribution, for example
withholding explicit content from minors. The same prover covers full language
models: it has proved a private next token of a trained Llama-3-8B.

**Demo / product link:** [VICTOR: demo video URL — script below]

## Progress

**How far along are you?**
- Our own prover (Rust, hash-based commitments over the Goldilocks field) for
  private transformer inference, ~11 months of work, 1,566 commits.
- **Trained Llama-3-8B, private next token:** proved in 192 s, verified in
  43 s, 471 MB proof, about 97 bits of soundness.
- **Full private 32-layer Llama-3-8B pass over 128 tokens:** 479–487 s.
- **TinyLlama-1.1B private next token:** 85 s, 255 MB.
- An integer accuracy setup measured within 1.1% of the float model's
  perplexity at 8B. The prover round that carries it is being built now; the
  proofs above use an earlier setup.
- Two privacy statements accepted after independent review and a mechanical
  privacy gate, both for the trained TinyLlama: its private block stack, and
  a whole next-token run.
- The media app runs end to end today on a stand-in proof. The real
  classifier proof is in integration: its verdict stage passes the privacy
  gate on 7 of 7 test runs. Anchoring on Base (testnet) is being deployed;
  today the app anchors on a local stand-in chain.

**How long have you been working on this? Full-time?** Since Dec 2025.
[VICTOR: full-time since …?]

**Are people using your product? Revenue?** Not yet; no users or revenue.
[VICTOR: any design-partner conversations, letters of intent?]

## Idea

**Why did you pick this idea?** [VICTOR: your reason, in your words.] Draft:
AI now makes decisions people cannot inspect, such as moderation, ranking and
screening. Today you either trust the operator or hand an auditor the private
data. A zero-knowledge proof removes that choice: the platform proves which
model and policy produced a decision, and the data stays private.

**How do you know people need it?** Regulation is moving toward
privacy-preserving proofs. The UK Online Safety Act's age checks have already
produced fines, and the EU's age-verification blueprint prefers zero-knowledge
proofs. Proofs of classifier verdicts are not yet required anywhere, so we are
testing this demand with design partners rather than assuming it.
[VICTOR: name any conversations.]

**Competitors:**
- Attestable: $20M seed, Aug 2026. It claims tens of proved tokens/s on a
  ~30B model on one H100; the company calls these alpha numbers, and we found
  no paper.
- Lagrange (DeepProve), EZKL, Inference Labs.
- Modulus, now part of World.
- zkVM routes: RISC Zero, Succinct.
- Academic work: zkLLM (CCS 2024).

We are behind Attestable on speed: about 0.26 proved tokens/s on a laptop,
versus their claimed tens on an H100. Where we are ahead:
- The privacy of the input, the output and every activation is a reviewed,
  measured statement, not a claim.
- Soundness is counted per proof.
- Everything is reproducible on consumer hardware.

Speed has a measured plan: GPU kernels (RTX 5090 next), batching and public
prefix reuse.

**What do you understand that others don't?** Content labels don't need fast
proofs. Each item is proved once, when it is created, and its proofs then
travel with it. That makes today's proof times usable for a real product
while speed improves, and it makes privacy, not throughput, the property
buyers pay for.

**How will you make money?** Per-proof fees or a licensed SDK for platforms
and trust-and-safety vendors that need auditable moderation; verification as
a service for auditors; later, proofs of inference for AI providers
(provenance, audits). [VICTOR: pricing view.]

## Equity / legal

**Legal entity?** [VICTOR: none yet → "Not yet; will form a Delaware C-corp"]
**Investment taken?** [VICTOR: none?] **Fundraising now?** Yes, alongside
grants (NSF SBIR, DARPA).

## Founders

[VICTOR: background, technical accomplishments, "something impressive you
built", how you met co-founders (if any).] Be explicit that the system was
built by you directing a team of AI coding agents (Claude, GPT Sol, GPT
Astra) under strict review rules: frozen trees, independent soundness and
privacy reviews, failing-first tests. YC asks about this, and the method is
part of the story.

**Founder video (1 min):** you, on camera: who you are, the problem, the
proof, one number.

## Demo video script (2–3 min, screen recording)

1. 0:00 — the problem in one line: "Platforms label content with AI. How
   do you prove it, without exposing the content?"
2. 0:15 — create a post in the media app. Show the per-category labels and
   their proof badges.
3. 0:45 — click "re-verify": a fresh process checks the proof, and the
   content is never shown to the verifier.
4. 1:15 — tamper with one byte of the proof or the label: verification
   fails (fail closed).
5. 1:40 — the bigger engine: the private 8B next-token proof run (192 s
   prove / 43 s verify), with its soundness bits.
6. 2:20 — what's next: real Shieldstral proofs in the app, then GPU speed.

Honest caption needed until the real classifier proof lands: "labels in this
demo come from a stand-in; the proof shown is the private TinyLlama run".
