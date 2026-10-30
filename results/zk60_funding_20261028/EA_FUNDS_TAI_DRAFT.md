# EA Funds Transformative AI Fund — application draft (for Victor)

Drafted by Claude (coordinator) from the repo's recorded evidence, 2026-10-28.
Nothing has been submitted, registered or sent. **[VICTOR: …]** = only you can
fill this in. Every number is labelled MEASURED (one laptop, shared box, one
run each, n=1), COUNTED (from the proof's own accounting) or MODEL/projected.

## 0. How to submit, and what could and could not be read

- **Fund:** EA Funds, Transformative AI Fund (it replaced the Long-Term Future
  Fund). Page read 2026-10-28:
  https://funds.effectivealtruism.org/funds/transformative-ai
  - "We are always open to applications."
  - "Grants are typically in the $10k-$150k range and rarely exceed $300k."
  - Who can apply: individuals, new organizations, and existing organizations
    starting new projects. For-profits are not mentioned, so **apply as an
    individual**.
  - Scope: early-stage grants "mainly to reduce global catastrophic risks from
    advanced AI", including "technical research, policy analysis,
    forecasting, advocacy, and demonstration projects". The fund calls itself
    "early-stage, fast, and tolerant of failure".
  - Contact: transformativeai[at]effectivealtruismfunds.org.
- **Form:** https://av20jp3z.paperform.co/?fund=Transformative%20AI%20Fund
  (linked from the fund page). **Its questions could not be read:** the form
  is drawn by JavaScript, and the automated fetch returned only the heading
  "EA Funds Grant Application". The FAQ at funds.effectivealtruism.org/faq
  showed only its question headings, not the answers. Those headings include
  "What is a Theory of Change?", "Can I request for my grant to be private?"
  and "Will I be more likely to receive funding if I apply with a lower
  amount?".
- **So the answers in section 1 follow the fund's published scope**, the FAQ
  headings, and applicant advice on the EA Forum (MichaelA, "Things I often
  tell people about applying to EA Funds", 2021, informal):
  - give a range of amounts and what each would buy;
  - say where else you have applied;
  - flag time sensitivity;
  - treat the application as the start of a dialogue.
  The site says it takes "less than 1h". Older posts say decisions come in a
  few weeks, faster if urgent; the current site gives no time (UNVERIFIED).
- **To do:** open the form in a desktop browser, then paste each block below
  into whichever field matches. If the fields differ a lot, send me the field
  names and I'll reshape the answers.

---

## 1. Answers (paste into the matching fields)

### Applicant
- Name, email, location: **[VICTOR]**
- Applying as: an individual. **[VICTOR: confirm.]** A Delaware C-corp may be
  formed later. If so, the grant-funded outputs are released openly anyway
  (see "Why grant money"), and any IP is assigned cleanly to the company.
- Links: **[VICTOR: LinkedIn / CV / personal site]**. The code repository is
  private until a provisional patent is filed (your ruling of 2026-10-28), so
  offer it to evaluators on request rather than linking it publicly.

### Project title
Verifiable AI governance: zero-knowledge proofs that a stated model produced
a stated result, without revealing the data

### One-sentence summary
An open verifier, specification and benchmark for zero-knowledge proofs of
AI model runs, which keep the input, the output and every intermediate
activation hidden, plus an external security review and proofs of
evaluation results over hidden test sets. The prover already proves a
private next token of a trained Llama-3-8B on a laptop.

### Project description (what, why, how)
Oversight of advanced AI rests on claims nobody outside the operator can
check: which model was evaluated, what it scored, which model was deployed,
what a safety filter decided. Checking such a claim today means trusting the
operator or handing the private data (user content, test sets) to an
auditor. That trade-off weakens audits, evaluations and any agreement
between labs, auditors, insurers and governments.

I built a zero-knowledge prover for transformer inference that removes it.
A proof shows that a public model, run on a hidden input, produced a stated
result: a next token, or a safety classifier's verdict. The verifier never
sees the input, the output or any intermediate activation; it learns only
the facts the owner chooses to publish. The prover is my own system: Rust,
hash-based commitments over a 64-bit prime field, with zero-knowledge masking
of every committed activation. It proves exact integer versions of
attention, normalization and the nonlinear layers.

What exists now [MEASURED on one laptop, shared box, n=1, unless marked]:
- **Trained Llama-3-8B, private next token** (32-token hidden prompt):
  proved in 192 s on the laptop CPU, verified in 43 s in a fresh process,
  471 MB proof, 65 of 65 tamper checks caught. Soundness is about 97 bits
  for the whole run [COUNTED].
- **Full private 32-layer Llama-3-8B pass over a 128-token hidden prompt:**
  about 480 s.
- **TinyLlama-1.1B private next token:** 85 s, 255 MB.
- **Two privacy statements accepted, both for the trained TinyLlama:** its
  private block stack, and a whole next-token run. Each was accepted after
  independent internal reviews and a mechanical privacy gate. **There has
  been no external audit yet; this grant pays for one.**
- **A demo media app** labels posts with classifier verdicts. The classifier
  is Mistral's open Shieldstral-1.0-3B. The app runs end to end today on a
  stand-in proof. The real classifier proof is in integration; its verdict
  stage passes the privacy gate on 7 of 7 test runs, on small test models.
  That is not yet a privacy acceptance.

This grant turns the prover into a public, checkable primitive (12 months):
1. **Month 3:** an open-source verifier, a written specification of the proof
   system and its privacy statement, and a reproducible benchmark suite
   (commands, inputs, expected results).
2. **Month 6:** an external cryptographic review of the soundness and privacy
   claims, published along with our fixes.
3. **Month 9:** proofs of evaluation results, for example "model M scored S
   on a hidden test set". An assessor, insurer or regulator learns the score
   and which model produced it, but not the test items. Also an IACR ePrint
   preprint and a peer-reviewed submission.
4. **Month 12:** a GPU prover with published throughput, and a design for
   hiding the weights as well. Weight hiding is needed when a lab's model is
   itself the secret.

The open-source release covers the verifier, the specification and the
benchmarks. The prover stays the product, per your 2026-10-28 ruling. The
release follows the provisional patent filing.

### Theory of change
1. **The problem:** governance of advanced AI (evaluations, audits,
   deployment commitments, international agreements) needs claims that can
   be checked without trusting one party and without leaking data. Today
   the choices are trust, disclosure or trusted hardware.
2. **What a proof adds:** a proof of which model ran, under which policy and
   with what result, with the data hidden. It rests on mathematics (a hash
   function) rather than on trusting the operator or a hardware vendor. It
   complements hardware-based verification rather than replacing it.
3. **How this grant moves it:**
   (a) an open verifier and specification let anyone check proofs
   independently;
   (b) an external review makes the soundness and privacy claims credible
   enough for evaluators, AI safety institutes, auditors and insurers to
   rely on;
   (c) proofs of evaluation results on hidden test sets let an evaluator keep
   its test items secret, which protects them from contamination and gaming,
   while still publishing a score anyone can check;
   (d) a weight-hiding design is the step that makes this usable with
   closed frontier models.
4. **Who uses it first:** evaluators and auditors working with open-weight
   models; platforms that must show which model and policy labelled content.
   Both work at today's speed, because each item is proved once.
5. **The long-run outcome:** "proof-carrying" AI claims become a standard
   building block for oversight, so verifying an AI claim stops requiring
   either blind trust or access to private data.

### Why this is a good bet now (track record)
- One founder directing a team of AI coding agents (Claude, GPT Sol, GPT
  Astra) under strict rules:
  - frozen code trees;
  - independent soundness and privacy reviews;
  - failing-first tests;
  - a resource guard on a shared machine.
- About 1,600 commits in 11 months. Every claim above is tied to a recorded,
  reproducible artifact: frozen source manifests, proofs and review reports.
- **[VICTOR: your background, in two or three sentences, and why you started
  this.]**

### Risks, and what happens if it fails (premortem)
- **Speed:** a private 8B pass is far from real time today (about 0.26
  proved tokens/s on the laptop CPU at 8B). Mitigation: the first uses
  (evaluation results, content labels) prove each item once, so today's
  speed works. The GPU work in month 12 is measured, not assumed. A funded
  competitor (Attestable, $20M seed) claims much higher speed. It has
  published no paper, and we found no statement that it hides inputs.
- **The external review finds a flaw:** we fix it and publish the review
  with the fixes. Finding a flaw is the point of paying for the review.
- **Scope:** today's privacy guarantee covers the data, not the weights.
  The weights are public, so closed-model use waits on the weight-hiding
  design.
- **Single founder:** the specification, benchmarks and reproducible
  artifacts mean the work survives without me. The open verifier is the
  part others can build on.
- **Fallback if the larger goals fail:** an open, externally reviewed
  verifier and specification for private transformer proofs, plus
  benchmarks, is still a public good.

### Amount requested, and what different amounts buy
- **Requested: $100,000 for 12 months.** This buys all four deliverables
  (budget in section 2).
- **Minimum useful: $75,000.** This keeps the external review and the open
  verifier, specification and benchmarks (deliverables 1 and 2), and fewer
  agent-months for 3 and 4.
- **Up to $150,000:** the $100,000 plan plus a founder stipend
  **[VICTOR: amount; this tier leaves $50,000 for it]**, so I can work on it
  full time.

### Other funding (applied for, planned or received)
Use this exact list at submission time:
- **Foresight Institute, AI for Science & Safety Nodes, call II** (due Oct
  31). It covers the same open deliverables. **If both fund, I will tell
  both funders and not take two grants for the same budget line.** The
  external review would be paid once, and the second grant would move to the
  stipend and the weight-hiding design.
- **NSF SBIR Project Pitch** (federal, for the company's product work).
- **Y Combinator W27** and **Alliance ALL19**: equity investment in a
  planned company, for the product.
- **[VICTOR: add any others sent by then, e.g. Lightcone Commons; amounts
  received: none so far?]**

### Why grant money, if a company may form
The grant-funded outputs are public goods released openly: the verifier,
specification, benchmarks, review report and evaluation-result proofs. The
company's product work (the prover, the app) is funded separately, by
investors or SBIR.

### Time sensitivity
**[VICTOR: say whether this is time-sensitive and why (runway). If it is,
tick the fast-response option the form offers.]**

### Public reporting
**[VICTOR: choose.]** The form reportedly lets you choose whether EA Funds
publishes a payout report. My suggestion: allow a public report with only
the one-sentence summary above, and no technical detail, until the
provisional patent is filed.

### References
**[VICTOR: one or two people who can speak to your work.]**

---

## 2. Budget (12 months)

| Line | $75k minimum | $100k requested | $150k full |
|---|---:|---:|---:|
| External cryptographic review (soundness + zero-knowledge) | 35,000 | 35,000 | 35,000 |
| AI agent usage and cloud GPU | 30,000 | 45,000 | 45,000 |
| GPU hardware or cloud for the throughput work | 10,000 | 10,000 | 10,000 |
| Contingency, accounting and tax preparation | — | 10,000 | 10,000 |
| Founder stipend **[VICTOR]** | — | — | 50,000 |
| **Total** | **75,000** | **100,000** | **150,000** |

The $100k column matches the Foresight draft's lines. Foresight's 10%
overhead line becomes contingency here. Grant income to an individual is
taxable in the US. **[VICTOR: confirm with your tax adviser.]**

## 3. Blanks only Victor can fill

1. Name, email, location, links; individual vs company.
2. Background and track record, in your words.
3. Stipend amount (or drop the $150k tier).
4. Other applications actually sent, and any money received.
5. Time sensitivity and runway.
6. Public payout report: yes, limited, or private.
7. References.
8. Confirm the open-source release waits for the provisional patent.

**Wording to fix in the other drafts (not changed here):**
- **Testnet anchoring.** The Foresight and YC drafts say proofs "are
  anchored" on Base testnet. As of 2026-10-28 22:15 UTC, the test wallet was
  funded but nothing had been deployed on Base Sepolia yet. Until a
  deployment lands, the app anchors to a local hash-chained stand-in. This
  draft says only what is true now.
- **Accuracy figure.** The YC draft's "integer model within 1.1% of float
  perplexity" holds for the chosen accuracy setup. The prover round that
  carries that setup (R13) is specified but not yet built. The 8B proofs
  quoted above predate it.
