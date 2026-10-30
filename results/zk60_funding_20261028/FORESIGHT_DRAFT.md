# Foresight AI for Science & Safety Nodes — call II draft (for Victor)

Deadline: **Fri 2026-10-31, 23:59 PDT**. Apply at
https://airtable.com/appyVXc5SMPAvIKpP/pagp7takV26cG6JY1/form. Open it in a
desktop browser: the form's fields could not be read automatically, so paste
these sections into whatever fields it shows. Typical grants: $30k–$100k. The
funded work must be open source. Applicants who work in person at the SF or
Berlin node get priority. Drafted by Claude from the repo's recorded
evidence, 2026-10-28; **[VICTOR: …]** = yours to fill in.

---

**Title:** Private, checkable AI runs: zero-knowledge proofs that a stated
model produced a stated result, without revealing the data

**Focus area:** Call II, area 2 ("scalable verification and proof
techniques"; "checks and balances that no one party controls"). Also area 4:
giving outside assessors the facts they need without exposing what must stay
private.

**Summary (≈100 words).** Oversight of AI today rests on trust: an operator
says which model ran and what it decided, and checking that means handing the
data to an auditor. We built a zero-knowledge prover for transformer
inference that removes that trade-off. A proof shows that a public model,
run on a hidden input, produced a stated result: a next token, or a safety
classifier's verdict. The input, the output and every intermediate
activation stay hidden. It has proved a private next token of a trained
Llama-3-8B on a laptop. This grant open-sources the verifier, the
specification and the benchmarks, pays for an external review, and delivers
proofs of evaluation results over hidden test sets.

**What exists now (measured on one laptop with an RTX 4070 + CPU; one run each):**
- Trained Llama-3-8B private next token: proved in 192 s, verified in 43 s,
  471 MB proof, about 97 bits of soundness.
- Full private 32-layer 8B pass over 128 tokens: about 480 s.
- TinyLlama-1.1B: 85 s.
- Two privacy statements accepted after independent internal review and a
  mechanical privacy gate. There has been no external audit yet; this grant
  pays for one.
- A demo app labels posts with proved classifier verdicts (Mistral's open
  Shieldstral-1.0-3B). Anchoring the proofs on a public testnet is being
  deployed; today the app uses a local stand-in chain.

**Deliverables (all open source; 12 months):**
1. **Month 3:** an open-source verifier, a written specification of the
   proof system and its privacy statement, and a reproducible benchmark
   suite (commands, inputs, expected results).
2. **Month 6:** an external cryptographic review of the soundness and
   privacy claims, published along with our fixes.
3. **Month 9:** proofs of *evaluation results*, e.g. "model M scored S on a
   hidden test set": an assessor or insurer learns the score and which model
   produced it, not the test items. Plus an IACR ePrint preprint and a
   peer-reviewed submission.
4. **Month 12:** a GPU prover with published throughput, and a design for
   hiding the weights as well (needed when a lab's model itself is the
   secret).

**Why it matters for AI risk:** agreements between labs, auditors, insurers
and governments need claims that can be checked without trusting any one
party and without leaking data. Proofs of which model ran, under which
policy, with what result, are a primitive those checks can build on.

**AI-first:** one founder directs a team of AI agents (Claude, GPT) under
strict rules: frozen code trees, independent soundness and privacy reviews,
failing-first tests, and a resource guard on a shared machine. The project
reached ~1,600 commits in 11 months. Most of the grant buys compute and
agent time rather than headcount.

**Capability to execute:** every claim above comes with a recorded,
reproducible artifact (frozen source manifests, proofs, review reports).
[VICTOR: your background.]

**Risk / reward:** the risk is speed. A private 8B pass is far from real time
today, though one-time labelling at content creation works at today's speed.
The reward is a checkable-AI primitive that is open and private, and that
anyone can build on.

**Budget (ask: $100,000 for 12 months)** [VICTOR: adjust; your time if you
take a stipend]:
- AI agent usage and cloud GPU: $45,000
- External cryptographic review: $35,000
- GPU hardware or cloud for the throughput work: $10,000
- Overhead (≤ 10% allowed): $10,000

**In person:** [VICTOR: willing to work from the SF node for sprints?]

**Applicant type:** [VICTOR: individual now; company being formed]. Why grant
money, if a company: the funded outputs (verifier, spec, benchmarks,
review) are public goods released openly. The company's product work is
funded separately.
