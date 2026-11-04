# Application kit: paste-ready blocks for every funding application (2026-11-01)

Victor's direction (D57, 2026-11-01): submit as many applications as possible, with as little input from him as
possible. He keeps his current job and leads the project part-time. The money mainly hires collaborators.

This file is the common source. Each application file in this folder reuses these blocks and fits them to its form.
Drafted by Claude (coordinator) from the repo's recorded evidence. Nothing has been submitted or sent.

Every number carries a label:
- **[MEASURED]**: a recorded run (n and machine stated);
- **[COUNTED]**: from the proof's own security accounting;
- **[MODEL]**: computed or projected, not measured.

The honesty rules of `docs/zkmatrix-poc/ZK60_FUNDING_PLAN.md` apply: never round a claim up.

**`[V: …]` marks the only blanks.** Section 0 lists all of them, so you can answer them once for every form.

---

## 0. Answer these once; every application reuses them

| # | Question | Default used in the drafts (change it if wrong) |
|---|---|---|
| V1 | Your current job (employer and role) | "a full-time research position" (no employer named) |
| V2 | Hours a week you will give the project | **10–15 hours a week** |
| V3 | References: two people, with name, role and email | **Set (Victor, 2026-11-01):** two references chosen; their names and emails are kept in local files only, never in the repository |
| V4 | How the money is received | **As an individual** for small grants. For grants above about $150k, through a fiscal sponsor or a company (section 9) |
| V5 | US citizen or permanent resident? (federal programs only) | unknown; federal drafts leave it blank |
| V6 | May a funder publish your name, the amount and a summary? | Yes, with the one-sentence summary only |
| V7 | A public project page (Manifund)? D53 holds all publication until GPU proving exists. Metal GPU proving exists now, CUDA does not | No, until you say so |
| V8 | A small stipend for yourself? | **$0.** All money goes to the work (a strong point with funders) |

**Before you sign with any employer:** an invention-assignment clause can reach work done while you are employed
there. Ask the employer for a written prior-invention carve-out naming this project (started December 2025; about
1,640 commits). This is a point for your attorney, not legal advice.

---

## 1. Identity block

Source: Victor's CV (`~/Downloads/Resume.pdf`, saved 2026-11-01) and LinkedIn, confirmed by Victor the same day.

- **Name:** Victor Rielly
- **Email:** victor23@pdx.edu
- **Phone:** [phone: kept in local files only] (local files only; never on a public page)
- **LinkedIn:** https://www.linkedin.com/in/victor-rielly-50508b3a/
- **Location:** Portland, Oregon area, USA (Pacific time)
- **Education:**
  - PhD, Applied Mathematics, Portland State University (Oct 2022 – May 2025), with an emphasis on machine learning;
  - B.S., Mathematics and Physics, minor in Computer Science, Pacific University (2016): salutatorian, and the
    awards for best mathematics, best physics and best natural-science student.
- **Positions:**
  - Postdoc, Translational Genomics Research Institute (TGen), June 2025 – present;
  - R&D intern at Intel (2022–23);
  - lead software engineer, IoT power device (2016–19);
  - NASA Marshall (2015) and Glenn (2014) intern.
- **Publications:**
  - J. Comput. Phys.: arxiv.org/abs/2206.15215
  - TMLR: arxiv.org/abs/2306.10189
  - accepted, SIAM: arxiv.org/abs/2503.13791
  - under review: arxiv.org/abs/2505.11622 and arxiv.org/pdf/2606.23472
- **Grant writing:** as a TGen research assistant (2023) he wrote a research grant proposal for a proof-of-concept
  technique toward provably safe AI language models.
- **Project name:** **Hashline**: zero-knowledge proofs of private AI inference
- **Code:** private repository; access for evaluators on request. Under D48 the whole stack is to be released openly.

### Bio, about 50 words
> Victor Rielly holds a PhD in Applied Mathematics (Portland State University, 2025; machine-learning emphasis). He
> has peer-reviewed papers in the Journal of Computational Physics and TMLR on kernel methods that learn differential
> equations from data, and research internships at Intel and NASA. Since December 2025 he has created and led
> Hashline, a zero-knowledge prover for private language-model inference.

### Bio, about 120 words
> Victor Rielly holds a PhD in Applied Mathematics from Portland State University (2025, machine-learning emphasis)
> and a B.S. in Mathematics and Physics from Pacific University, where he was salutatorian. He is a postdoctoral
> researcher at the Translational Genomics Research Institute.
> - **Research:** papers in the Journal of Computational Physics and Transactions on Machine Learning Research, a
>   third accepted in a SIAM journal and two more under review. They introduce kernel methods that learn
>   differential equations from data.
> - **Industry R&D:** internships at Intel (machine-learning models of circuit-simulation noise) and at NASA
>   (Marshall and Glenn). Three years as lead software engineer of a networked IoT power device.
> - **Software:** lead developer of a live transcription and translation app used at more than ten sites in three
>   states.
> - **This project:** since December 2025 he has led the design of Hashline, a zero-knowledge prover for private inference of
>   trained language models. He made its security and privacy rulings and directed a team of AI coding agents under
>   strict review rules (about 1,640 commits).

---

## 2. Titles and summaries

**Title, short:** Hashline: fast, open zero-knowledge proofs of private AI inference

**Title, governance framing:** Checkable AI claims without disclosing data: zero-knowledge proofs that a stated model
produced a stated result

### One sentence
> Hashline proves that a specific AI model, run on hidden data, produced a specific result. Anyone can check the
> proof, while the input, the output and every intermediate value stay secret.

### About 50 words, plain (for "what are you trying to do" fields)
> We make it possible to check what an AI system did without seeing the private data it used. Our proofs show that a
> named model, given a hidden input, produced a stated result. Anyone can verify the proof. The input, the output
> and the model's internal steps stay secret, so nobody has to trust the operator.

### About 120 words
> **The problem.** Claims about AI systems usually cannot be checked without trusting the operator or handing over
> private data. Examples: "this post was screened by safety model X"; "model M scored 92% on our held-out test";
> "the deployed model is the audited one".
>
> **What exists.** Hashline is a zero-knowledge prover built for transformer arithmetic. It hides inputs, outputs and
> every intermediate activation, and its soundness is counted (about 97 bits per run). It has produced private proofs
> for a trained Llama-3-8B and for a real 3B safety classifier. Its new GPU backend proves an 8B-sized layer over 128
> hidden tokens in 0.36 s.
>
> **What the grant buys.** We will hire engineers to move the prover onto NVIDIA GPUs, aiming at 50 proved tokens per
> second. We will release the whole stack as open source and pay for an external security review.

### About 250 words
> **The problem.** Oversight of AI rests on claims that outsiders cannot check: which model ran, what it scored on a
> test, what a safety filter decided about a post. Today a checker must either trust the operator or see the private
> data (user content, test sets, prompts). Trusted hardware moves that trust to a chip vendor. General zero-knowledge
> proof systems remove it, but they have been far too slow for language models. Published systems for language
> models mostly hide the model, not the user's data.
>
> **What exists.** Hashline is a zero-knowledge prover built for transformer arithmetic. It proves exact integer
> versions of attention, normalisation and the nonlinear layers. It hides the input, the output and every
> intermediate activation. It uses only hash-based commitments, with no trusted setup. Its soundness is counted at
> about 97 bits per run, and two privacy statements passed independent internal review.
>
> **Measured so far:**
> - a private next-token proof for the trained Llama-3-8B in 192 s on a laptop CPU;
> - private proofs of a real 3B content-safety classifier's verdicts, anchored on a public testnet;
> - since last week, a GPU backend that proves an 8B-sized layer over 128 hidden tokens in 0.36 s, about 11 proved
>   tokens per second for a 32-layer model on one Apple GPU.
>
> **The grant.** The project lead works part-time and takes no salary from the grant. The grant hires a GPU and
> zero-knowledge engineer to port the prover to NVIDIA GPUs, aiming at 50 proved tokens per second for an 8B model on
> one card. It also releases the whole stack as open source with a specification and reproducible benchmarks, and
> pays for an external cryptographic review. The result is a public, checkable building block for audits,
> evaluations and content accountability.

---

## 3. The problem, why now, and the theory of change

### The problem
- **Claims about AI systems are hard to check.** Typical ones:
  - "this content was screened by classifier X under policy P";
  - "model M scored S on our private test set";
  - "the model we deploy is the one that was evaluated";
  - "this answer came from model M".
- **Today there are three ways to check such a claim, and each has a cost:**
  - trust the operator;
  - disclose the private data (user content, test items, prompts) to a checker;
  - rely on trusted hardware, which moves the trust to a chip vendor and its supply chain.
- **That weakens what depends on these claims:** audits, third-party evaluations, platform transparency reports
  (e.g. the EU Digital Services Act), insurance underwriting and any agreement between labs, auditors and
  governments.

### What a proof adds
- A zero-knowledge proof lets anyone check that the stated model, run on a hidden input, produced the stated result.
- The checker learns only the facts the owner chooses to publish, such as the verdict, the score or the model's
  identity.
- The guarantee rests on mathematics (a standard hash function), not on the operator or a hardware vendor.
- It complements hardware-based verification rather than replacing it.

### Why now
- Two things make this tractable now:
  - proof systems built from sumchecks and lookups;
  - GPUs fast enough to run them.
- The first commercial claims have appeared. Attestable claims 53 proved tokens per second on one H100 and raised a
  $20M seed in August 2026, but its system is closed. If the only fast systems are proprietary, the verification
  layer of AI governance would itself depend on trusting one company.
- An open, reviewed and fast prover keeps that layer checkable by anyone.

### Theory of change (for AI-safety and governance funders)
1. **Open verifier, specification and benchmarks:** anyone can check proofs independently.
2. **External review:** makes the soundness and privacy claims credible enough for evaluators, AI safety
   institutes, auditors and insurers to rely on.
3. **Speed:** 50 proved tokens per second for an 8B model on one GPU makes proofs routine, not exceptional.
4. **First uses at today's speed:** each item is proved once, so these work now:
   - evaluation scores on hidden test sets: the test items stay secret, which protects them from contamination and
     gaming, and the score is still checkable;
   - content-safety verdicts for platforms;
   - model-provenance records.
5. **Hidden weights (version 2):** lets labs prove results about confidential models. This is the step outside
   assessment of frontier labs needs.
6. **Outcome:** proof-carrying AI claims become a standard building block of oversight. Checking an AI claim then no
   longer needs blind trust or access to private data.

### Other framings, by funder type
- **Privacy and open-source funders (NLnet, OTF, FFDW and similar):**
  - private AI use without surveillance: a person or platform can prove a policy was applied without exposing the
    content;
  - an open, permissively licensed prover is public infrastructure.
- **Cryptography and Ethereum ecosystem funders:**
  - a hash-based, transparent, plausibly post-quantum proof system for the largest workloads people now run;
  - an open alternative to closed zkML;
  - on-chain anchoring of proved AI verdicts (on testnet today).
- **Child-safety and trust-and-safety funders:**
  - platforms prove that a screening classifier ran on every post, and what it said;
  - no content leaves the platform.
- **Government (NSF, DARPA):**
  - trustworthy AI;
  - data privacy and integrity;
  - secure and trusted computing.

---

## 4. What exists today (the evidence table; as of 2026-11-01)

| What | Number | Label | Record |
|---|---|---|---|
| Trained Llama-3-8B, private next token (32-token hidden prompt) | prove 192 s, verify 43 s, 471 MB proof; 65 of 65 tamper checks rejected | MEASURED, laptop CPU, n=1 | `docs/zkmatrix-poc/MVP_STATUS.md` |
| Soundness | about 97 bits per run (R13 accepted at all 12 registered profiles; R14 about 97.3 bits) | COUNTED; independent internal reviews | `ZK60_DECISIONS.md` D27 |
| Privacy | two statements accepted after independent internal reviews and a mechanical privacy gate: the trained TinyLlama-1.1B private block stack (D33), and a whole next-token answer (D36). **No external audit yet** | review outcome | `ZK60_DECISIONS.md` D33, D36 |
| Real content-safety classifier: Mistral's Shieldstral-1.0-3B (Apache 2.0), all 26 layers | about 440–452 s per category on 8 laptop threads, peak 8.2 GiB. A demo post's proofs are anchored on the Base Sepolia **testnet** (block 52,373,745). Its privacy statement (draft v3) is complete but **not yet accepted** | MEASURED, n=1 | `MVP_STATUS.md` (2026-10-30) |
| GPU backend (Apple M3 Ultra, Metal) | proofs byte-identical to the CPU path | MEASURED | `results/zk60_metal_20261031/README.md` |
| One Llama-3-8B-sized layer, 128 hidden tokens | 12.3 s laptop CPU → 4.66 s Mac CPU → 2.20 s Mac GPU (Oct 31) → **0.356 s** Mac GPU with the 16-bit lookup format (Nov 1) | MEASURED, warm n=3, synthetic weights at the true shape | same |
| Throughput for a 32-layer 8B model | **about 11 proved tokens/s** per request (13 at 256 tokens); **about 22** with six requests at once | MODEL from the measured per-layer times; layer proofs only | same |
| The 16-bit lookup format | independent soundness review passed (lookup error 2^-102.9 per layer). Its privacy gate run is still owed, so no receipt uses it yet | review outcome | `results/zk60_limb16_20261031/REVIEW_W16_20261101.md` |
| Speed target | ≥50 proved tokens/s for an 8B model on one high-end GPU (Attestable claims 53 on one H100, unverified) | target | `START_HERE.md` |

### What sets it apart (keep this careful)
- **It hides the user's data.** Inputs, outputs and every activation are hidden, with a written privacy statement
  and a mechanical gate. Published systems such as zkLLM (CCS 2024) mainly keep the model's weights private.
- **No trusted setup.** It is hash-based throughout (Ligero-style commitments, sumcheck and LogUp over a 64-bit
  prime field), and plausibly post-quantum.
- **Counted soundness**, with independent reviews of each release.
- **Open.** The whole stack is to be open-sourced under a permissive licence (D48). Attestable is closed. DeepProve
  (Lagrange) is under a restrictive non-open licence.
- **It is honest about speed.** We are about 4.5× short of 50 on today's machine, and we say so. The plan to close
  the gap is concrete (section 5).

---

## 5. The plan: 12 months, staffed by hires

**Who does what.**
- **Victor (part-time, unpaid by the grant):** technical direction, security and privacy rulings, review of every
  release.
- **The hires:** they own the engineering. They work with the project's existing practice:
  - byte-identity gates;
  - independent soundness and privacy reviews;
  - a recorded measurement for every claim;
  - AI coding agents under strict review rules.

| Work package | Months | Deliverable | Done when |
|---|---|---|---|
| WP1. NVIDIA GPU prover | 1–5 | The Metal backend's batched sumcheck and commitment kernels ported to CUDA (RTX 5090, then H100) | Proofs byte-identical to the CPU path. Published throughput for an 8B model; target ≥50 proved tokens/s on one card |
| WP2. Open release | 1–4 | The whole stack under a permissive licence: prover, verifier, specification of the proof system and its privacy statement, reproducible benchmarks (commands, inputs, expected digests) | A stranger reproduces the benchmark digests from the README |
| WP3. External review | 4–8 | A paid external cryptographic review of soundness and zero-knowledge | The review and our fixes are published |
| WP4. First uses | 5–10 | (a) Proofs of evaluation scores on hidden test sets ("model M scored S on test set T", with T hidden). (b) A public demo: a content labeler that publishes a proof with each label | Verifier support for both, plus a public demo |
| WP5. Paper | 6–10 | An IACR ePrint preprint and a submission to a top security venue (USENIX Security or ACM CCS) | Submitted |
| WP6. Hidden weights (version 2) | 9–12 | A design and prototype that also hides the model's weights | Design note and a working small-model prototype |

**Milestones for reports:**
- M1 (month 4): WP2 released.
- M2 (month 5): WP1 measured.
- M3 (month 8): WP3 published.
- M4 (month 10): WP4 and WP5.
- M5 (month 12): WP6.

### How the hires are found (for "team" questions)
- **Channels:**
  - a paid role advertised in the zero-knowledge community: ZK Hack, the ZKProof forum, the 0xPARC and Ethereum
    research channels;
  - outreach to the groups closest to this work: Daniel Kang (UIUC; trustless audits of models and data) and
    Benedikt Bünz (NYU; hash-based proof systems);
  - contract engineers through zero-knowledge audit and engineering firms.
- **First hire:** a GPU (CUDA) engineer with proof-system experience.
- **Second hire:** an applied cryptographer, part-time, who owns the specification and works with the external
  reviewers.
- **Entry path:** the codebase is documented for newcomers (`START_HERE.md`, a task board with exact commands and
  byte-identity acceptance). A new engineer can land a gated change in the first week.

---

## 6. Budget tiers

**Assumptions [ESTIMATE]:**
- a GPU or zero-knowledge engineer on contract at about $12,500 a month full-time, about $150k a year with no
  benefits;
- an applied cryptographer at 0.25 FTE, about $4,200 a month;
- an external review of the core arithmetic and privacy, about $50k (quotes vary: $40k–$100k);
- AI-agent usage and cloud GPU time, about $2,000 a month;
- the project lead takes **$0** (V8).

| Line | A: $60k / 6 mo | B: $150k / 12 mo | C: $300k / 12 mo | D: $750k / 24 mo |
|---|---:|---:|---:|---:|
| GPU / ZK engineer | 0.5 FTE: 37,500 | 0.5 FTE: 75,000 | 1.0 FTE: 150,000 | 2.0 FTE: 600,000 |
| Applied cryptographer (0.25 FTE) | — | — | 50,000 | in D's review line |
| External cryptographic review | — | 50,000 | 50,000 | 80,000 (two rounds) |
| AI agents and cloud GPU | 12,000 | 24,000 | 30,000 | 50,000 |
| Admin, fiscal sponsor or accounting, contingency | 10,500 | 1,000 | 20,000 | 20,000 |
| **Total** | **60,000** | **150,000** | **300,000** | **750,000** |
| **Buys** | WP1 + WP2 | WP1–WP3 | WP1–WP5 | WP1–WP6, plus a larger-model study and a second review |

**What smaller amounts buy** (many forms ask):
- $25k: three months of a half-time engineer on WP1 alone.
- $60k: the CUDA port and the open release.
- $150k: adds the external review.
- $300k: the full 12-month plan.

The hardware is already in hand: an RTX 5090 desktop and an M3 Ultra Mac Studio. Grant income to an individual is
taxable in the US; contractor payments are a business expense. **Confirm both with a tax adviser.**

---

## 7. Risks and what happens if the project falls short

1. **Speed.**
   - *Risk:* 50 tokens/s may not be reached on one card.
   - *Mitigation:* the first uses (evaluation scores, content verdicts) prove each item once, so they work at
     today's speed. The CUDA throughput is measured, never assumed.
2. **The external review finds a flaw.**
   - *Mitigation:* we fix it and publish the review with the fixes. Finding flaws is why the review is funded. Every
     check fails closed.
3. **False assurance.**
   - *Risk:* a proof could be read as "the AI is safe".
   - *Mitigation:* a proof states one fact about one stated model. The specification says exactly what is and is not
     proved.
4. **Misuse of privacy.**
   - *Risk:* an operator could look compliant while hiding problems.
   - *Mitigation:* the proof establishes only the stated fact; open verification lets anyone check every published
     claim.
5. **Part-time lead and hiring risk.**
   - *Mitigation:* the system design and its reviews already exist, so the hires inherit a working prover with gates.
   - Every result is a reproducible artifact, so the work survives a change of people.
   - If hiring is slow, the grant pays contractors per milestone.
6. **Scope.**
   - *Limit:* version 1 hides the data, not the weights, so closed-model use waits for WP6.
7. **Competition.**
   - *Risk:* a funded closed competitor exists.
   - *Our position:* an open, reviewed system is the public alternative, and it remains a public good even if a
     closed product is faster.

**The fallback if the bigger goals fail:** an open, externally reviewed prover, verifier and specification for
private transformer inference, with benchmarks. That is still a public good others can build on.

---

## 8. Open source, publication and data

- **Licence:** everything funded is released under a permissive open-source licence (D48). There is no patent.
- **Timing:** the release is prepared with a secret scan and a third-party licence inventory. It ships as soon as
  GPU proving and verification are in place (D53); the Metal backend exists, the CUDA port is WP1.
- **What is never released:** no user data. Synthetic challenge data only. No model weights whose licences forbid
  redistribution.
- **Publication:** an IACR ePrint preprint, then a peer-reviewed security venue.

---

## 9. How the money is received (V4)

- **Small grants (up to about $150k), as an individual:** this works for EA Funds, Lightcone, NLnet, the OpenAI
  cybersecurity grants, crypto foundations and similar. Grant income is taxable, and contractors are paid on 1099s.
- **A fiscal sponsor (no company needed):** for charitable funders that will not pay individuals for staff, or
  above about $150k. Options to check, all **UNVERIFIED** as to current terms:
  - Ashgro (fiscal sponsor for AI-safety projects);
  - Rethink Priorities Special Projects;
  - Players Philanthropy Fund;
  - for open-source money, Open Source Collective.
  - Fees are typically 5–10%; budget line "admin".
- **A Delaware C-corp:** needed for SBIR and DARPA, equity and most compute-credit programs. Under SBIR the principal
  investigator must be primarily employed by the company, so a **hired collaborator** would be the PI, not Victor.

---

## 10. Answer bank for common questions

**Why you?**
> I led the design of the proof system and made every security and privacy ruling. The prover works today: private proofs for
> a trained 8B model and a real safety classifier. One 8B layer took 12 s on a laptop CPU; on a GPU it now takes
> 0.36 s. What the project lacks is engineering hands, which this grant buys.

**Why now?**
> The first fast zero-knowledge proofs for language models are arriving as closed products. An open, reviewed
> alternative is needed before the verification layer of AI governance comes to depend on trusting one vendor.

**Counterfactual: what happens without this grant?**
> The work continues part-time and slowly. The CUDA port, the open release and the external review wait months or
> longer. The grant turns a working research prover into reviewed public infrastructure this year.

**How will you measure success?**
> Proved tokens per second for an 8B model on one GPU, measured on a published benchmark that anyone can rerun. The
> external review published with fixes. Outside users verifying proofs with the open verifier.

**What is the biggest risk?**
> Speed. 50 proved tokens per second is about 4.5× beyond today's machine. The first uses do not depend on it, and
> every throughput figure will be measured and published either way.

**How does this reduce risks from advanced AI?**
> Governance of advanced AI depends on claims that can be checked: evaluation results, deployment commitments,
> safety screening. Proofs make those claims checkable without trusting the operator and without exposing data. Hidden
> weights, in version 2, extends this to confidential frontier models.

**Dual use?**
> The work adds no capability to any AI model. It makes claims about models checkable. The privacy it gives covers
> the data a proof is about, never the fact being proved.

**Use of AI in this application** (some forms ask):
> The project's engineering uses AI coding agents under strict review rules. This application was drafted with AI
> assistance from the project's recorded evidence, and I reviewed and edited it.

Mercatus Emergent Ventures rejects AI-written applications, and DARPA requires the core ideas to be the authors' own.
Write those yourself.

**Other funding** (keep this current at each submission):
> Applied or applying (no awards yet): [list]. If two funders cover the same budget line, I will tell both and take
> only one.
