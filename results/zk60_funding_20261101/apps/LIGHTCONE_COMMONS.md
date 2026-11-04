# Lightcone Commons: application draft

**Deadline.** Rolling. Rounds close about monthly, and you should submit about 3 weeks before a round closes. For
the round closing in mid-December, that means **submit by about Nov 24** (UNVERIFIED today; see
`OPEN_CALLS_VERIFIED.md`).

**Eligibility.** Lightcone Commons accepts individuals, 501(c)(3)s and for-profits. It provides fiscal sponsorship
for charitable work by individuals. There is no topic restriction; the funders choose.

**Terms.** The application is a document you can keep editing after you submit. Decisions usually come about two
weeks after a round closes, and money about a month after that.

**What you do.** Paste the four sections below into the application. Fill nothing else, except as noted in
`APPLICATION_KIT.md` section 0: V1 (job), V2 (hours) and V3 (references), if the form asks for them.

**The ask.** $300,000 for 12 months (kit tier C), with a stated minimum of $150,000 (tier B) and a stretch of
$750,000 over 24 months (tier D). Lightcone has no per-grant cap, and its largest funder gives for AI alignment and
control, so the governance framing leads.

---

## 1. What are you doing?

**Hashline: checkable AI claims without disclosing data.**

Oversight of advanced AI rests on claims that outsiders cannot check. Which model was evaluated, and what did it
score? Is the deployed model the audited one? What did a safety filter decide about a piece of content? Today a
checker must trust the operator or see the private data (user content, test sets, prompts). Trusted hardware moves
that trust to a chip vendor.

I have built a zero-knowledge prover for transformer inference that removes this trade-off. A proof shows that a
stated model, run on a hidden input, produced a stated result: a next token, or a safety classifier's verdict.
Anyone can verify it. The input, the output and every intermediate activation stay hidden, and the verifier learns
only the facts the owner publishes. The proof uses only hash-based commitments (no trusted setup), with soundness
counted at about 97 bits per run.

**What already works:**
- **Trained Llama-3-8B:** a private next-token proof in 192 s on a laptop CPU, verified in 43 s (n=1).
- **A real safety classifier:** private proofs of Mistral's open Shieldstral-1.0-3B verdicts on a post (26 layers,
  about 7.5 minutes per category on a laptop), anchored on a public testnet.
- **Privacy:** two privacy statements accepted after independent internal reviews: the TinyLlama-1.1B block stack
  and a whole next-token answer. There has been no external audit yet.
- **A GPU backend, new this week:** one Llama-3-8B-sized layer over 128 hidden tokens proves in 0.36 s on an Apple M3
  Ultra (it took 12 s on a laptop CPU). That is about 11 proved tokens per second for a 32-layer model, and about 22
  with several requests at once. These are measured per-layer times; the stack figure is computed from them.

**Why it matters for AI safety:**
- **Evaluations:** an evaluator can publish a checkable score while keeping its test set secret, which protects the
  test from contamination and gaming.
- **Platforms:** they can prove that a safety classifier screened every item, and what it said.
- **Version 2 hides the weights too,** so a lab can prove facts about a confidential model. That is the piece outside
  assessment of frontier labs needs.

The only fast competitor I know of (Attestable, which claims 53 tokens/s and raised $20M) is closed source. If fast
proofs are proprietary, AI governance's verification layer would itself rest on trusting one company. Hashline will
be fully open source.

## 2. What will the money buy?

The money goes to hires and an external review. I keep my current job and lead the project part-time, about
[V2: 10–15] hours a week. **The grant pays me nothing.**

| Item | 12 months |
|---|---:|
| A GPU / zero-knowledge engineer, full-time contract | $150,000 |
| An applied cryptographer, quarter-time: specification, and liaison with the reviewers | $50,000 |
| An external cryptographic review of soundness and zero-knowledge, published with fixes | $50,000 |
| AI-agent usage and cloud GPU time (H100 benchmarks) | $30,000 |
| Fiscal sponsorship or accounting, plus contingency | $20,000 |
| **Total** | **$300,000** |

**Deliverables:**
1. **Months 1–5:** the GPU prover ported to NVIDIA (RTX 5090, then H100), byte-identical to the CPU path. Its
   throughput is published for an 8B model, aiming at ≥50 proved tokens per second on one card.
2. **Months 1–4:** the whole stack released under a permissive licence: prover, verifier, a specification of the
   proof system and its privacy statement, and reproducible benchmarks.
3. **Months 4–8:** the external review and our fixes, published.
4. **Months 5–10:**
   - proofs of evaluation scores on hidden test sets;
   - a public demo content labeler that publishes a proof with each label;
   - an IACR ePrint preprint and a submission to USENIX Security or ACM CCS.
5. **Months 9–12:** a design and small prototype that also hides the weights.

**Other amounts:**
- **$150k (minimum):** half the engineer, plus the review; delivers items 1–3.
- **$750k over 24 months:** two engineers, two review rounds and the full version-2 work.

## 3. Who is involved?

**Victor Rielly, project lead.**
- **Education:** PhD in Applied Mathematics (Portland State University, 2025, machine-learning emphasis); postdoc at
  the Translational Genomics Research Institute.
- **Publications:** peer-reviewed papers in the Journal of Computational Physics and TMLR, with a third accepted in a
  SIAM journal.
- **Industry R&D:** internships at Intel and NASA.
- **This project:** since December 2025 I have led the design of Hashline and made all of its security and privacy rulings,
  directing a team of AI coding agents under strict rules: byte-identity gates, independent soundness and privacy
  reviews, and a recorded measurement behind every claim. The repository has about 1,640 commits.
- LinkedIn: https://www.linkedin.com/in/victor-rielly-50508b3a/

**Hires, to be recruited with this grant:**
- a GPU engineer with proof-system experience;
- a part-time applied cryptographer.

They are found through the zero-knowledge community (ZK Hack, ZKProof, Ethereum research channels) and the academic
groups closest to this work. A newcomer starts from a documented codebase: a task board with exact commands and
byte-identity acceptance.

**References:**
- Bruno Jedynak, Portland State University: [reference email: local files only]
- Kamel Lahouel, Translational Genomics Research Institute: [reference email: local files only]

## 4. Logistics

- **Applicant:** Victor Rielly, an individual in the US (Portland, Oregon area). There is no organisation yet.
  [V4: "Please provide fiscal sponsorship" if you want the charitable route, or "pay me as an individual".]
- **Timeline:** start on funding; 12 months.
- **Open source:** everything funded is released under a permissive licence. There is no patent.
- **Other funding:** none received.
  - Applying in parallel to [list from `README.md`, kept current].
  - If two funders cover the same line, I will tell both and take only one.
- **Contact:** victor23@pdx.edu
