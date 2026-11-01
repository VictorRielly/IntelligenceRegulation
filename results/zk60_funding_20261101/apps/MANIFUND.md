# Manifund: public project page draft

**Why consider it.** It can be the fastest money. A regrantor or the AI Safety Tactical Opportunities Fund (AISTOF)
can fund a project "in days, not months". Individuals can apply.

**The catch.** The page, the amount and later updates are **public**.
- D53 holds publication until GPU proving and verification exist.
- Metal GPU proving exists now; CUDA does not.
- **Post only if you say yes to V7.**

**Where.** manifund.org → "Start a project". The headings below follow Manifund's project template; the agent's
`FORM_FIELDS.md` confirms them.

**Settings.**
- Minimum funding: **$25,000**. Funding goal: **$150,000**.
- Funding deadline: 30 days after posting.
- After posting, message two or three AI-governance or security regrantors on Manifund, and AISTOF, asking whether it
  is in scope. That step is what makes the money fast.

---

### Title
Hashline: open zero-knowledge proofs of private AI inference

### Subtitle
Check which AI model produced a result, and what it said, without seeing the data. The prover works; this funds the
NVIDIA GPU port, an open release and an external review.

### Project summary
Oversight of AI rests on claims nobody outside the operator can check:
- which model was evaluated, and what it scored;
- whether the deployed model is the audited one;
- what a safety filter decided.

Today you trust the operator, hand over the private data, or trust a hardware vendor.

Hashline is a zero-knowledge prover for transformer inference. A proof shows that a stated model, run on a hidden
input, produced a stated result. The input, the output and every intermediate activation stay hidden. It is
hash-based (no trusted setup), with soundness counted at about 97 bits per run.

Working today:
- private next-token proofs for the trained Llama-3-8B (192 s on a laptop CPU);
- private verdict proofs for a real 3B safety classifier;
- since this week, a GPU backend that proves an 8B-sized layer over 128 hidden tokens in 0.36 s, about 11 proved
  tokens per second for a 32-layer model.

The only fast competitor I know of is closed source. Hashline will be fully open.

### What are this project's goals? How will you achieve them?
1. **Speed:** port the GPU prover from Apple Metal to NVIDIA (RTX 5090, then H100). Proofs stay byte-identical to the
   CPU path. Target: ≥50 proved tokens per second for an 8B model on one card. Throughput is measured and published
   either way.
2. **Openness:** release the whole stack under a permissive licence, with a specification and reproducible
   benchmarks.
3. **Trust:** commission an external cryptographic review of soundness and zero-knowledge, and publish it with fixes.
4. **Use:** proofs of evaluation scores on hidden test sets, and a demo labeler that publishes a proof with each
   label.

### How will this funding be used?
I keep my day job and lead part-time. **The grant pays me nothing.** It pays for:

| Amount reached | Buys |
|---|---|
| $25,000 (minimum) | 3 months of a half-time GPU engineer on the NVIDIA port |
| $60,000 | The port plus the open release |
| $150,000 (goal) | 12 months of a half-time engineer, the $50k external review, and AI-agent and cloud GPU costs |

### Who is on your team? What's your track record on similar projects?
**Victor Rielly** (project lead):
- PhD in Applied Mathematics, Portland State University, 2025;
- papers in the Journal of Computational Physics and TMLR;
- internships at Intel and NASA;
- created and leads Hashline (since December 2025, about 1,640 commits).

I led the design and made every security and privacy ruling. I run the engineering through AI coding agents under
strict rules: byte-identity gates, independent soundness and privacy reviews, and a recorded measurement behind every
number above.

The engineer will be hired with these funds.

### What are the most likely causes and outcomes if this project fails?
- **Most likely shortfall:** the NVIDIA port lands below 50 tokens/s. The outcome is still an open, measured GPU
  prover. The first uses (evaluation scores, content verdicts) prove each item once, so they work at that speed.
- **The external review finds a flaw:** we fix it and publish both.
- **Hiring is slow:** contractors are paid per milestone.

### How much money have you raised in the last 12 months, and from where?
None. Self-funded so far. Other applications pending: [keep current].
