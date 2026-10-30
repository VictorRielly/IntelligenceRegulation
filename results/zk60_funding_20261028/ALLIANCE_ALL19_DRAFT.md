# Alliance ALL19 — application draft and pitch-deck outline (for Victor)

Drafted by Claude (coordinator) from the repo's recorded evidence and the
YC W27 draft, 2026-10-28. Nothing has been submitted or sent. **[VICTOR: …]**
= only you can fill this in. Every number is labelled MEASURED (one laptop,
shared box, one run each, n=1), COUNTED (from the proof's own accounting) or
MODEL/projected.

## 0. The program, and what could and could not be read

Read on alliance.xyz on 2026-10-28:
- **Deadline:** ALL19 regular admission **Nov 18, 2026** (early admission
  closed Sep 23). The FAQ says to apply early: an interview invitation comes
  within about 1 week of applying.
- **Interviews:** about a 10-minute Zoom with mentors; a decision by email
  24–48 h after the interview. Teams that are not selected get no
  personalized feedback.
- **Terms:** **$400k at a $4M post-money valuation on a SAFE** (10% on
  conversion) **plus a 1:1 token side letter**, standard for every company:
  "if a startup launches a token, Alliance would have a claim to it". The
  site says the side letter places no other constraints on the business. The
  program is otherwise free. Money is wired 1–2 weeks after acceptance, once
  paperwork, KYC and payment checks are done. **A company is needed before
  the wire.**
- **Program:** starts **Jan 11, 2027**. Two weeks of in-person onboarding in
  New York, eight weeks remote, then Demo Day in week 10 (in New York, also
  online). It asks for "full commitment during the program's 3 months".
- **Who they want:** "If you're a technical founder building something
  ambitious, you should apply." They care "far more about the founder than
  the product"; pre-product and pre-revenue are fine. Sectors include crypto
  and AI, and non-crypto-native startups are welcome. The site says the
  application takes about 20 minutes. A search excerpt of Alliance's
  best-practices page (the page itself returned 404) says to cut jargon and
  to use precise numbers and facts.
- **Form: could not be read beyond its first step.** https://alliance.xyz/apply
  shows only "Email (1st Founder)*" and a Next button. Going further would
  mean starting an application, which I did not do. Third-party guides list
  no questions. So section 1 answers the questions accelerator forms usually
  ask, reusing the YC draft. Paste each block into the field that matches,
  or send me the field names and I'll reshape it.

**Overlap with YC:** YC decides by Dec 11, and its batch runs Jan–Mar 2027
in San Francisco. Alliance runs Jan 11 – mid-March in New York and remote.
You cannot do both in full. Apply to both and choose if both say yes.
**[VICTOR: decide which you would take.]**

---

## 1. Application answers

**Founder email(s):** **[VICTOR]**

**Company name:** **[VICTOR]** (no entity yet; a Delaware C-corp is planned).

**One-liner:**
- "Zero-knowledge proofs that an AI ran — privately"
- alternative: "Proof an AI checked content, without seeing it"

**Website / demo:**
- **[VICTOR: demo video URL]** — reuse the YC demo recording.
- The repo is private until the provisional patent is filed; offer access on
  request.

**What are you building?**
We make zero-knowledge proofs of AI model runs in which the input, the
output and every intermediate activation stay hidden. Anyone can check a
proof, and it reveals only the facts the owner chooses to publish.

The first product is verifiable content labels:
- when a post is created, an open safety classifier labels it for explicit
  content, violence and hate (Mistral's Shieldstral-1.0-3B);
- we publish a proof of each label, and the content stays private;
- a platform can then prove to users, auditors or regulators that a given
  model and policy produced each label;
- the labels also drive distribution, for example withholding explicit
  content from minors.

The same prover covers full language models: it has proved a private next
token of a trained Llama-3-8B.

**How far along are you? (precise numbers; MEASURED on one laptop, n=1)**
- Our own prover: Rust, hash-based commitments over a 64-bit prime field.
  About 11 months of work and 1,566 commits.
- **Trained Llama-3-8B, private next token** (32-token hidden prompt):
  proved in 192 s on the laptop CPU, verified in 43 s, 471 MB proof, about
  97 bits of soundness [COUNTED].
- **Full private 32-layer Llama-3-8B pass over 128 tokens:** 479–487 s.
- **TinyLlama-1.1B private next token:** 85 s, 255 MB.
- **Two privacy statements accepted, both for the trained TinyLlama:** its
  private block stack, and a whole next-token run. Each was accepted after
  independent internal reviews and a mechanical privacy gate. **No external
  audit yet.**
- **The media app runs end to end today on a stand-in proof.** The real
  classifier proof is in integration; its verdict stage passes the privacy
  gate on 7 of 7 test runs, on small test models.
- **On-chain:** a publisher for Base's public testnet (Sepolia) is built and
  its test wallet is funded, but no deployment had been made as of
  2026-10-28. Until then the app anchors to a local hash-chained stand-in.
  Testnet only. **[VICTOR/coordinator: update this line at submission if the
  testnet deployment has landed.]**

**How long have you been working on it? Full-time?** Since Dec 2025.
**[VICTOR: full-time since …?]** **[VICTOR: can you be in New York for Jan
11–24 and for Demo Day, and commit fully for the 3 months?]**

**Users / revenue:** none yet. **[VICTOR: any design-partner conversations,
letters of intent?]**

**Why now?**
- Platforms now carry legal duties over harmful content and minors (the UK
  Online Safety Act, the EU Digital Services Act, US state laws).
- Regulators already accept zero-knowledge proofs for age checks: the EU's
  age-verification blueprint names them the preferred method.
- AI now makes the decisions (moderation, ranking, screening) that those
  duties cover, and nobody outside the operator can check them.
- Proofs of classifier verdicts are not yet required anywhere. We are
  testing this demand with design partners rather than assuming it.

**Competitors, and why you win:**
- **Attestable:** $20M seed, Aug 2026. It claims 53–77 proved tokens/s on a
  ~31B model on one H100; the company calls these alpha numbers, and we
  found no paper.
- **Lagrange (DeepProve), EZKL, Inference Labs; Modulus**, now part of
  World.
- **zkVMs:** RISC Zero, Succinct.
- **Academic:** zkLLM (CCS 2024), which targets hiding the model.

**We are far behind Attestable on speed:** about 0.26 proved tokens/s on a
laptop CPU, versus their claimed tens on an H100. Where we are ahead:
- **Privacy:** the input, the output and every activation are hidden. That is
  a reviewed, stated property, not a claim. In the abstracts we read, we
  found no competitor stating it.
- **Soundness is counted** per proof.
- **Reproducibility:** everything runs on consumer hardware, with frozen,
  recorded artifacts.
- **Speed has a measured plan:** GPU kernels (an RTX 5090 is next), batching
  and public-prefix reuse.

Content labels don't need fast proofs. Each item is proved once, when it is
created, and the proof travels with it. Today's proof times already work
for that, and privacy, not throughput, is what buyers pay for.

**Business model:**
- per-proof fees, or a licensed SDK, for platforms and trust-and-safety
  vendors that need auditable moderation;
- verification as a service for auditors;
- later, proofs of inference for AI providers (provenance, audits).

**[VICTOR: pricing view.]**

**Where does crypto fit?**
- Zero-knowledge proofs are crypto-native technology. The prover is
  transparent: hash-based, with no trusted setup.
- Proof records are published on a public chain, testnet first, so anyone
  can check what was proved and when.
- Later: verifiable inference for on-chain AI agents. That is a hypothesis,
  not current demand.

**Token plans:** **[VICTOR: e.g. "No token planned." You accept the 1:1
side letter either way.]**

**Funding so far:** none. **[VICTOR: confirm.]** Parallel applications:
Y Combinator W27, plus non-dilutive grants (Foresight, EA Funds, NSF SBIR).

**Founder(s):** **[VICTOR: background, technical accomplishments, the most
impressive thing you've built, solo or with a co-founder.]**

Say plainly that you built the system by directing a team of AI coding
agents (Claude, GPT Sol, GPT Astra) under strict review rules: frozen trees,
independent soundness and privacy reviews, failing-first tests. That is the
"can your team ship" answer: about 1,600 commits in 11 months, and the
first private proof of a trained 8B model's next token.

**Deck:** **[VICTOR: link]**, built from section 2.
**Video:** reuse the YC founder video and demo recording.

---

## 2. Pitch deck outline (12 slides)

Rules for every slide:
- one message per slide;
- numbers carry their label (MEASURED n=1 laptop / COUNTED /
  MODEL-projected);
- no construction internals beyond "hash-based commitments with masking"
  (the provisional patent comes first).

**1. Title**
- Company name **[VICTOR]**; the one-liner "Zero-knowledge proofs that an AI
  ran — privately".
- Founder name, contact; "Alliance ALL19 application, Nov 2026".
- *Visual:* a post card with a green "proved" badge beside a closed padlock
  over the post text.

**2. Problem: AI decisions nobody can check**
- Platforms label and rank content with AI; regulators, users and auditors
  must take the label on trust.
- Checking means handing over the private data: user posts, test sets.
- New duties on harmful content and minors (UK Online Safety Act, EU DSA)
  raise the stakes. Ofcom has already fined age-check failures (£1M, Dec
  2025; £1.35M, Feb 2026).
- *Visual:* two bad options side by side: "trust us" vs "send the auditor
  your users' data".

**3. Solution: a proof travels with every AI decision**
- A zero-knowledge proof that a stated public model, under a stated policy,
  produced a stated label.
- The input, the output and every intermediate activation stay hidden; only
  the published facts are visible.
- Anyone can verify in a fresh process; tampering with the proof or the label
  fails verification.
- *Visual:* the input goes into a locked box labelled "model + policy"; out
  comes a public label plus a proof; a verifier icon shows a check mark.

**4. Demo: the media app**
- Create a post → per-category labels (explicit / violence / hate) with
  proof badges.
- "Re-verify" checks the proof in a fresh process; the verifier never sees
  the content.
- Change one byte → verification fails (fail closed); minors' feeds hide
  restricted items, with the reason shown.
- Honest caption until the real classifier proof lands: "labels in this demo
  come from a stand-in; the proof shown is the private TinyLlama run".
- *Visual:* three screenshots in a row (compose, labelled post with badges,
  failed tamper check), or a QR code to the demo video.

**5. How it works (one diagram)**
- Hidden post → tokenizer pinned by digest → the public, pinned classifier,
  run in exact integer arithmetic → yes/no score against a public threshold
  → a proof is produced.
- Each committed activation is masked; the proof shows the arithmetic is
  right without opening any hidden value.
- Public: the model identity, the policy, the verdict bit, and the proof's
  digest on a public chain (testnet).
- *Visual (diagram in words):* a left-to-right pipeline of five boxes,
  "Post (hidden)" → "Pinned tokenizer" → "Public classifier (integer, every
  activation masked)" → "Verdict vs threshold" → "Proof". A dashed line
  splits the diagram: everything above it is hidden (post, tokens,
  activations, scores); below it is public (model hash, policy, verdict,
  proof). From "Proof", one arrow goes to "Verifier ✓" and one to "Chain
  record (testnet)".

**6. Measured numbers (one laptop, RTX 4070 8 GB + CPU, n=1)**
- Trained Llama-3-8B private next token: 192 s prove (laptop CPU) / 43 s
  verify / 471 MB, about 97 bits of soundness [MEASURED; bits COUNTED].
- Full private 8B pass, 32 layers × 128 tokens: 479–487 s. TinyLlama-1.1B
  next token: 85 s / 255 MB [MEASURED].
- Privacy statements accepted for two TinyLlama artifacts after independent
  internal review and a mechanical gate. No external audit yet.
- Classifier verdict stage: privacy gate passes on 7 of 7 test runs (small
  test models) [MEASURED].
- *Visual:* a four-row table; a small "n=1, shared laptop" footnote.

**7. Market: who needs checkable AI**
- **Privacy-preserving moderation:** platforms and trust-and-safety vendors
  that must show which model and policy labelled content, without exposing
  user data.
- **AI audits:** auditors, evaluators and insurers that need checkable
  results (e.g. a score on a hidden test set) without receiving the data.
- **Provenance:** AI providers proving which model produced an output.
- Regulators already accept zero-knowledge proofs for age checks (EU
  age-verification blueprint); proofs of classifier verdicts are a new
  category we are testing with design partners.
- *Visual:* three columns (moderation / audits / provenance), each with
  "buyer" and "what they pay for". No market-size figure until we have a
  sourced one.

**8. Competition: honest positioning**
- Attestable ($20M seed, Aug 2026) claims 53–77 proved tokens/s on ~31B on
  an H100 (alpha, no paper). **We are far behind on speed** (about 0.26
  proved tokens/s, 8B, laptop CPU).
- Others: Lagrange DeepProve, EZKL, Inference Labs, Modulus (now World),
  zkVMs (RISC Zero, Succinct), zkLLM (academic; hides the model).
- Where we lead: hidden inputs, outputs and activations as a reviewed
  statement; soundness counted per proof; reproducible on consumer hardware.
- *Visual:* a 2×2 grid. x-axis: "data privacy stated and reviewed" (no →
  yes); y-axis: "speed" (low → high). Attestable top-left, us bottom-right,
  an arrow from us pointing up labelled "GPU plan".

**9. Business model**
- Per-proof fees or a licensed prover SDK for platforms and trust-and-safety
  vendors.
- Verification as a service for auditors and regulators.
- Later: proofs of inference for AI providers (provenance, audits).
- **[VICTOR: pricing hypothesis, e.g. per proof or per seat; mark it as a
  hypothesis.]**
- *Visual:* a simple flow (platform pays per proof → proof attached to the
  post → auditor verifies for free or through a paid service).

**10. Go-to-market: design partners first**
- Target: a few design partners, from trust-and-safety vendors, platforms
  with minors in the audience, and an AI auditor. **[VICTOR: target number;
  names / LOIs]**.
- Give each a working demo, a one-page security statement (with its limits)
  and a price. LOIs in weeks and a paid pilot in 1–3 months at best
  (estimates).
- Credibility: an IACR ePrint preprint after the provisional patent; peer
  review in 2027; the external audit.
- Open-core: the verifier, specification and benchmarks are open, so anyone
  can check proofs; the prover is the product.
- *Visual:* a timeline Q1 → Q4 2027 with partner, pilot, audit and preprint
  milestones.

**11. Team**
- **[VICTOR: name, background, the impressive thing you built.]**
- How we build: one founder directing AI coding agents (Claude, GPT Sol, GPT
  Astra) under strict rules: frozen trees, independent soundness and privacy
  reviews, failing-first tests, a resource guard.
- Output: about 1,600 commits in 11 months; every claim tied to a recorded,
  reproducible artifact.
- First hires with the money: **[VICTOR: e.g. a GPU / cryptography
  engineer]**; external auditors.
- *Visual:* founder photo, plus a small "agent team" diagram (founder → lanes
  → independent reviewers → frozen release).

**12. The ask and use of funds**
- **$400k on Alliance's standard terms** ($4M post-money SAFE + 1:1 token
  side letter).
- Use of funds (**[VICTOR: runway in months; set the split]**):
  - founder salary;
  - external cryptographic review (about $35k, as budgeted in the Foresight
    draft);
  - AI agent usage and cloud GPU;
  - a first engineering hire;
  - legal (incorporation; the provisional patent: USPTO fee $65–$325 plus
    attorney time);
  - design-partner pilots.
- Milestones this buys:
  - real Shieldstral proofs in the app;
  - testnet anchoring live;
  - a GPU prover on the RTX 5090 with published throughput, toward ≥50
    proved tokens/s (the target, not a result);
  - the external audit;
  - the preprint;
  - signed design partners.
- *Visual:* a bar of the use-of-funds split, with the milestone timeline
  under it.

---

## 3. Blanks only Victor can fill

1. Company name; company formation timing (needed before the $400k is
   wired).
2. Founder background; solo or co-founder; full-time status.
3. Can you do New York Jan 11–24 and Demo Day, and 3 months of full
   commitment? Would you take Alliance or YC if both accept?
4. Design-partner conversations or LOIs.
5. Pricing view; use-of-funds split.
6. Token plans (for the side-letter question).
7. Demo video URL and deck link.
8. At submission: update the testnet line, and the classifier-proof status
   if the real Shieldstral proof has landed in the app.
