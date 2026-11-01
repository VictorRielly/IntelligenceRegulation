# EA Funds Transformative AI Fund: application draft (2026-11-01; supersedes the 10-28 draft)

**Why this one is early in the queue.**
- The fund is always open. It calls itself "early-stage, fast, and tolerant of failure".
- Individuals can apply.
- Decisions come in weeks (UNVERIFIED), and there is a fast-response option for time-sensitive requests.

**Form.** https://av20jp3z.paperform.co/?fund=Transformative%20AI%20Fund (open it in a desktop browser).
- The field names below follow the fund's published guidance.
- If `FORM_FIELDS.md` lists the real fields, use that mapping instead.
- Paste each block into the field that matches.

**The ask.** $150,000 for 12 months, minimum $60,000. The fund's typical range is $10k–$150k.

---

### Project title
Hashline: open, reviewed zero-knowledge proofs that a stated AI model produced a stated result, without revealing the
data

### One-sentence summary
Hire an engineer to move a working zero-knowledge prover for private language-model inference onto NVIDIA GPUs,
release it fully open source, and pay for an external security review. A proof shows which model produced which
result, while the data stays hidden.

### Project description
Oversight of advanced AI rests on claims outsiders cannot check: which model was evaluated and what it scored,
whether the deployed model is the audited one, what a safety filter decided. Checking such a claim today means
trusting the operator or handing private data (user content, test sets) to an auditor. Trusted hardware moves the
trust to a chip vendor.

I built Hashline, a zero-knowledge prover for transformer inference that removes this trade-off. A proof shows that a
stated model, run on a hidden input, produced a stated result. The verifier never sees the input, the output or any
intermediate activation. The proof system is hash-based (no trusted setup), with soundness counted at about 97 bits
per run.

**What exists [MEASURED unless marked]:**
- **Trained Llama-3-8B:** a private next-token proof in 192 s on a laptop CPU; verified in 43 s; 65 of 65 tamper
  checks rejected (n=1).
- **Real 3B safety classifier (Mistral's Shieldstral):** private proofs of its verdicts on a post, all 26 layers,
  about 7.5 minutes per category on a laptop, anchored on a public testnet.
- **Privacy:** two privacy statements accepted after independent internal reviews. There has been no external
  audit; this grant pays for one.
- **New GPU backend (this week):**
  - one Llama-3-8B-sized layer over 128 hidden tokens proves in 0.36 s on an Apple M3 Ultra, down from 12 s on a
    laptop CPU;
  - that is about 11 proved tokens per second for a 32-layer model [MODEL from measured per-layer times], against a
    target of 50.

**What the grant buys (12 months):**
1. The GPU prover ported to NVIDIA (RTX 5090, then H100), byte-identical to the CPU path, with published 8B
   throughput. The target is ≥50 proved tokens per second on one card.
2. The whole stack released open source: prover, verifier, a specification of the proof system and its privacy
   statement, and reproducible benchmarks.
3. An external cryptographic review of soundness and zero-knowledge, published with our fixes.
4. Proofs of evaluation scores on hidden test sets, so an evaluator can publish a checkable score while keeping the
   test items secret.

### Theory of change
1. AI governance needs claims that can be checked without trusting one party and without leaking data. Examples:
   evaluations, audits, deployment commitments, content-safety screening.
2. A zero-knowledge proof makes such a claim checkable by anyone. It rests on a hash function, not on the operator or
   a hardware vendor, and complements hardware-based verification.
3. **Open release:** anyone can verify proofs independently. The only fast competitor I know of (Attestable, which
   claims 53 tokens/s) is closed. Without an open alternative, the verification layer of AI governance would itself
   rest on trusting one company.
4. **External review:** makes the claims credible enough for evaluators, AI safety institutes, auditors and insurers
   to rely on.
5. **Speed:** GPU speed makes proofs routine. Evaluation scores and content verdicts are proved once per item, so
   they are useful even at today's speed.
6. **Next step (version 2): hidden weights.** Labs can then prove facts about confidential models, which outside
   assessment of frontier labs needs.

### Track record
- **Education:** PhD in Applied Mathematics (Portland State University, 2025, machine-learning emphasis); B.S. in
  Mathematics and Physics (salutatorian). I am a postdoctoral researcher at the Translational Genomics Research
  Institute.
- **Publications:** peer-reviewed papers in the Journal of Computational Physics and TMLR, a third accepted in a
  SIAM journal, and two under review.
- **Industry R&D:** internships at Intel and NASA; three years as lead engineer of a networked IoT device.
- **This project (since December 2025, about 1,640 commits):**
  - I led the design of the proof system and made every security and privacy ruling;
  - I direct a team of AI coding agents under strict rules: byte-identity gates, independent soundness and privacy
    reviews, and a recorded measurement behind every claim.
- LinkedIn: https://www.linkedin.com/in/victor-rielly-50508b3a/

### Who will do the work
- I keep my current job and lead the project part-time, about [V2: 10–15] hours a week. **The grant pays me
  nothing.**
- The money hires a GPU / zero-knowledge engineer on contract and pays for the external review.
- I will recruit through the zero-knowledge community (ZK Hack, ZKProof, Ethereum research) and the academic groups
  closest to this work.
- The codebase is documented for newcomers, with a task board of exact commands and byte-identity acceptance.

### Amount, and what different amounts buy
| Amount | Buys |
|---|---|
| $60,000 (minimum) | A half-time engineer for 6 months: the NVIDIA port and the open release |
| **$150,000 (requested)** | A half-time engineer for 12 months, plus the $50k external review, plus AI-agent and cloud GPU costs: deliverables 1–3 and most of 4 |
| $300,000 | A full-time engineer, plus a quarter-time cryptographer, the review and the paper: the full plan |

Budget for $150k:
- engineer, $75,000;
- external review, $50,000;
- AI agents and cloud GPU, $24,000;
- accounting, $1,000.

### Risks and premortem
- **Speed:** 50 tokens/s may not be reached. The first uses work at today's speed, and every throughput figure is
  measured and published either way.
- **The review finds a flaw:** we fix it and publish both; that is why it is funded.
- **Hiring:** if a full hire is slow, I pay contractors per milestone. The design and gates already exist, so a new
  engineer is productive within the first week.
- **Scope:** version 1 hides the data, not the weights.
- **Fallback:** an open, externally reviewed prover and specification for private transformer inference is still a
  public good.

### Other funding
None received. Applying in parallel to: [keep current from `README.md`]. If two funders cover the same budget line, I
will tell both and take only one.

### Time sensitivity
> Yes, moderately. A funded closed competitor exists, and the project is ready for engineers now: the prover and its
> review process work. An answer within a few weeks lets me hire this winter.

(Tick the fast-response option if the form offers it.)

### Public reporting
Allow a public payout report with the one-sentence summary.

### References
- Bruno Jedynak, Portland State University: bruno.jedynak@pdx.edu
- Kamel Lahouel, Translational Genomics Research Institute: klahouel@tgen.org
