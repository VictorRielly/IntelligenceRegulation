# DARPA IPTO office-wide BAA HR001126S0011 — abstract draft (for Victor)

Drafted by Claude (coordinator) from the repo's recorded evidence, 2026-10-28.
Nothing has been submitted, registered or sent. **[VICTOR: …]** = only you can
fill this in. Every number is labelled MEASURED (one laptop, shared box, one
run each, n=1), COUNTED (from the proof's own accounting) or MODEL (the
project's cost model; a projection, not a result).

## 0. What the BAA requires, and what could and could not be read

**Read (2026-10-28):**
- The grants.gov listing: https://simpler.grants.gov/opportunity/4ec76651-17d7-47fd-ac5e-377e8673b3a4
  (Open; posted 2026-06-22, updated 2026-09-08, closes 2027-06-22).
- **The BAA PDF** (HR001126S0011.pdf), **the conformed BAA with Amendment
  01** (the file posted as "HR001126S0011-Amendment-02.pdf"), and **the
  required abstract template** (IPTO_OW_Abstract_Template__Required_.docx).
  All three were downloaded from the listing's official file host. The
  summarizer could not decompress them, so their text was extracted locally
  from the saved copies.
- darpa.mil: the IPTO office page (program-manager directory:
  https://www.darpa.mil/about/program-managers) and the proposer
  instructions page (BAAT).

**Not readable:**
- The sam.gov notice page renders no content without JavaScript.
- The file posted as "HR001126S0011-Amendment-01.pdf" is only an internal
  DARPA routing page that points to SharePoint; it holds no amendment text.
- The proposal-templates zip and the BAAT site were not opened. They are not
  needed for an abstract.

**What the BAA and template require (as read):**
- **Abstracts are required**; full proposals are by invitation only.
  Abstracts are accepted on a rolling basis until **2027-06-22, 2:00 pm ET**.
- **The BAA "strongly encourages" contacting a program manager before
  submitting** (section 5).
- **Submission:** unclassified abstracts go only through **DARPA's BAAT**,
  https://baa.darpa.mil/; email submissions are refused. BAAT needs:
  - a DARPA Extranet account (two emails: a username, then a temporary
    password);
  - a BAAT account and an organization registration;
  - one zip upload of at most 100 MB.
  Accounts lapse after 30 days of inactivity.
- **Amendment 01: a SAM.gov UEI is required at abstract submission.** The
  abstract therefore cannot go in until the company exists and its SAM.gov
  registration is active (up to about 3 weeks). The program-manager email
  can go now.
- **Format:**
  - at most **5 pages**, 8.5×11", **12-point font, 1" margins** (8 or 10
    pt allowed in figures and tables);
  - PDF or Word, named "Organization Name_IPTO OW Abstract";
  - the cover sheet, table of contents, AI-use disclosure, bibliography and
    technical papers do not count toward the 5 pages;
  - a figure is encouraged; "elaborate brochures or marketing materials" are
    not wanted;
  - "Information not explicitly requested will not be reviewed."
- **Required sections:**
  - the cover sheet;
  - Goals and Impact;
  - Technical Approach (six listed questions);
  - Capabilities/Management Plan;
  - Cost and Schedule;
  - the Disclosure of AI Utilization (Parts A and B).
  A bibliography and technical papers are optional.
- **Markings:** mark pages with proprietary information "Company
  Proprietary", never "Confidential", which is a classification marking.
- **Evaluation (amended):**
  - **Step 1 is a strict conformance review** of the technical approach for
    originality, mission understanding and operational realism. "Generic,
    boilerplate, or broadly aggregated content" is rejected at this step.
  - **Step 2** asks whether the approach is innovative, feasible and aligned
    with DARPA's mission, whether the key challenges and risks are
    identified, and whether the proposer can achieve the goals.
  - The amended conformance definition adds a requirement that **the PI and
    key personnel provide "strong evidence" of successfully executing similar
    research**. The template says peer-reviewed papers count; patents
    applied for and non-peer-reviewed internet papers do not.
- **Scope rules:**
  - "Revolutionary advances"; "research that primarily results in
    evolutionary improvements … is specifically excluded."
  - Proposers may not propose work they have already completed, or work
    already funded or approved for funding by DARPA or another agency.
  - Shorter periods of performance are encouraged.
- **AI-use rule (template):**
  - AI may be used for "administrative drafting, formatting, or editorial
    refinement", but "the core scientific hypotheses, technical
    methodologies, and proposed operational solutions must be the original
    product of the human authors";
  - in the research itself, AI may be "an adjunct to — and not a
    replacement for — human creativity, insight, and direction".
- **Award instruments:** procurement contract, grant, cooperative agreement,
  or Other Transaction (research or prototype). Procurement contracts
  require CMMC Level 1 at proposal. Grants and OTs need the FRRBS
  foreign-influence forms (biographical sketch, current and pending support)
  at the proposal stage. Grant awardees also post a one-page public abstract.
  DARPA alone decides whether the work counts as fundamental research.
- **Contact:**
  - The BAA coordinator is **IPTO_OfficeWide@darpa.mil** in the amended BAA
    (the original BAA and the grants.gov listing give HR001126S0011@darpa.mil).
  - Coordinator questions must include the name of a designated point of
    contact.

**Things to settle before submitting (each is also marked [VICTOR] below):**
1. **A company, a SAM UEI and a BAAT account.** None exists yet.
2. **The "strong evidence" requirement.** There are no peer-reviewed papers
   yet. That is the most likely reason for a non-conforming verdict. The
   mitigations:
   - name a university cryptographer as co-investigator or reviewer;
   - name the external audit firm;
   - get the IACR preprint and a submission out first (after the provisional
     patent);
   - ask the program manager, on the first call, how they weigh
     reproducible artifacts.
3. **The AI-use disclosure.** This text was drafted by Claude, and the
   system was built by AI agents working under your direction. Part A must
   be ticked "AI tools were used". You must be able to attest that the core
   hypotheses and methods are yours, so **rewrite the technical paragraphs
   in your own words**, and fill Part B truthfully. Section 1.6 holds a
   factual starting text.
4. **No overlap with other government funding.** If NSF SBIR funds the GPU
   objective first, re-scope this abstract so it does not ask DARPA for the
   same work.
5. **Mark the abstract "Company Proprietary"** and keep construction detail
   at the level below. The provisional patent should be filed first in any
   case (your 2026-10-28 ruling).

---

## 1. The abstract (paste into the required template; body ≈ 1,900 words plus one table and Figure 1, about 4–4½ of the 5 pages at 12 pt — check the page count in Word before submitting)

### 1.0 Cover sheet (template fields)

| Field | Entry |
|---|---|
| Abstract Title | Proof-Carrying AI: Zero-Knowledge Proofs of Full Trained Language-Model Inference with Hidden Inputs, Outputs and Activations |
| Proposer Organization | **[VICTOR: company name]** |
| SAM.gov UEI | **[VICTOR: required at submission (Amendment 01)]** |
| Technical POC | **[VICTOR: name, mailing address, telephone, email]** |
| Administrative POC | **[VICTOR]** |
| Other team members | **[VICTOR: university co-investigator / external review firm, if agreed; otherwise "none at abstract stage; external cryptographic reviewer to be engaged"]** |
| Award instrument requested | **Grant** or **Other Transaction for Research** (recommended; avoids procurement-contract CMMC requirements) **[VICTOR: choose]** |
| Estimated total cost (base + options) | **[VICTOR: $ — see 1.5]** |
| Estimated period of performance | **[VICTOR: proposed 18-month base + 6-month option]** |
| Other solicitations this concept was proposed to | **[VICTOR: list what was actually sent: e.g. NSF SBIR/STTR Project Pitch (topic CA9); Foresight Institute AI Nodes call II; EA Funds Transformative AI Fund]** |

### 1.1 Goals and Impact

Military and civil users increasingly rely on AI models whose outputs can't
be checked by anyone outside the operator. When a model triages a report,
flags content or scores a test, a second party who wants to verify that
claim today has two choices. It can trust the operator, or it can receive
the private inputs, which may be operational data, user content or a held
test set. Hardware enclaves add a third option, but that option means
trusting a hardware vendor.

**We propose proof-carrying AI.** Every output of a full, trained large
language model comes with a zero-knowledge proof that anyone can check.
The proof shows that a stated, pinned model and policy produced the stated
result. The verifier learns nothing else about the input, the output or any
intermediate activation. Weights may be public (privacy level P1) and, in
the second phase, hidden as well (P3).

**This is no longer hypothetical at small throughput.** On one laptop CPU,
our prover has produced a single proof that a trained Llama-3-8B, given a
hidden 32-token prompt, chose a hidden next token. The proof covers the
embedding, all 32 trained blocks, the final normalization, the output head
and the token choice. It proved in 192 s and verified in 43 s in a fresh
process, at 471 MB, with about 97 bits of whole-run soundness; 65 of 65
tamper checks were caught [MEASURED, n=1; bits COUNTED]. A full private
32-layer pass over 128 hidden tokens takes about 480 s [MEASURED].

**What success changes (quantitatively):**
1. **Throughput.** We go from about 0.26 proved tokens/s (8B, 128 tokens,
   laptop CPU) to at least 50 proved tokens/s for the complete trained 8B
   model on one high-end GPU, a factor of about 200. That turns proofs from
   a forensic, after-the-fact tool into one that can run alongside
   inference.
2. **Assurance.** Soundness rises from about 95 bits whole-run at 512
   tokens [COUNTED] to 100 bits, with a path to 128.
3. **Scope.** We hide the weights too (P3), so the owner of a closed model
   can prove facts about it without releasing it.

**Applications:**
- **Assured AI:** a fielded system proves which approved model version
  produced each recommendation, and an inspector can check it later without
  the operational input.
- **Evaluation:** a test organization publishes a model's score on a hidden
  test set that third parties can check, and the test items never leave
  its control.
- **Coalition and privacy:** a partner checks an AI-produced label or
  verdict without receiving the underlying data. Our first application is
  of this kind: proofs that a safety classifier (Mistral's open
  Shieldstral-1.0-3B) labelled content under a stated policy, without
  revealing the content.

**Relationship to past and present work:**
- **DARPA SIEVE** (HR001119S0076, 2019) set out to make zero-knowledge
  proofs expressive and efficient for very large DoD statements. We address
  one now-central class of statement, transformer inference at full
  trained-model scale, with the model's internal state hidden. General
  methods do not reach this class: a general-purpose zkVM needed 3,743 s
  for one tiny synthetic transformer block that our specialized prover
  proves in 0.095 s [MEASURED, shared laptop CPU, diagnostic].
- **zkLLM** (CCS 2024) proves large models but targets hiding the model's
  parameters. DeepProve, zkGPT and zkAgent prove smaller models or other
  settings. The commercial claims of higher throughput (e.g. Attestable)
  come with no paper and, as far as we found, no statement that inputs are
  hidden. We found no published system that states and checks hiding of the
  inputs, outputs and all activations at 8B scale.

We have not been funded by DARPA or any other agency for this work.

*Figure 1 (to draw):* one trained model as a column of 32 blocks between
"hidden prompt" and "hidden token". A shaded band covers every activation,
labelled "committed and masked — never opened". Two outputs leave the
column: a small public box ("model ID, policy, published fact") and a proof.
The proof goes to an inspector icon marked "checks in seconds–minutes,
learns nothing else". A side bar shows the throughput ladder: 0.26
(measured, laptop CPU) → GPU phases → ≥50 proved tokens/s (goal).

### 1.2 Technical Approach

**What the work does.** It delivers a GPU prover and an open verifier for
full trained-transformer inference with hidden inputs, outputs and
activations. The work then extends the construction to hidden weights and
demonstrates two assured-AI uses: model-identity attestation and proofs of
evaluation results.

**State of the art and its limits.**
- General-purpose zkVMs are orders of magnitude too slow for this (above).
- Specialized model provers either hide the model rather than the data, or
  report throughput without a stated privacy property or published
  soundness accounting.
- Plain inference of an 8-bit 8B model on the same laptop CPU takes about
  1.55 s for 32 tokens. Our private proof of the block stack takes about
  100× that at 32 tokens and 77× at 128 [MEASURED]. That overhead is what
  this program attacks.

**What is new, and why it should work.** The prover is built for
transformer arithmetic rather than general computation:
- hash-based polynomial commitments over a 64-bit prime field, with no
  trusted setup;
- zero-knowledge masking of every committed activation;
- exact integer forms of attention, normalization and the nonlinear layers.

Three things already work:
- **Privacy is stated, not asserted.** For the trained TinyLlama-1.1B,
  two privacy statements have been accepted after independent internal
  reviews and a mechanical privacy gate: the block stack, and a whole
  next-token run. A verifier's view of an accepted run is within a
  statistical distance of about 2^-70 per run (22 layers) of a view that
  does not depend on the hidden input, output or activations, in the
  random-oracle model for the hash [COUNTED]. There has been no external
  audit; this program pays for one.
- **Soundness is counted per run** at a named workload: about 97 bits for
  the measured runs, about 95 bits at 8B with 512 tokens [COUNTED].
- **Fidelity:** a chosen integer configuration measures within 1.1% of the
  float model's perplexity at 8B [MEASURED]. It costs about 23% more
  committed data [COUNTED], and the prover round that carries it is
  specified but not yet built.

**Path to ≥50 proved tokens/s (the core risk).** The project's cost model
is refit on the measured 8B 128-token run. It projects, for 8B at 512
tokens on one RTX 5090 [MODEL]:

| Stage | Projected proved positions/s |
|---|---:|
| Today's code | about 0.6–0.8 |
| Whole prover on the GPU at today's kernel efficiency | 6.6–8.6 |
| Plus attention-layout changes | 9.4–11.8 |
| ≥50 | needs kernels near memory-bandwidth roofline |

Three measured facts back this:
- the first GPU kernel matches the CPU output byte for byte, at 11.7–19.4%
  of the laptop GPU's memory bandwidth (clock-capped laptop) [MEASURED];
- a counted layout change (a per-row division dictionary) already removes
  20.8% of committed elements at 8B with 512 tokens [COUNTED];
- the remaining levers are batching across contexts and reuse of public
  prefixes.

The ≥50 target counts total workload: 512 positions within 10.24 s,
including setup, witness, commitments and proving, with every receipt
verified. Larger workloads amortize setup.

**Technical challenges and planned solutions:**
1. **Memory bandwidth of commitment hashing on the GPU.** The approach is
   kernel redesign toward roofline, measured kernel by kernel against the
   byte-identical CPU reference.
2. **GPU memory at 8B.** The model is proved block by block, as the 8B
   stack already is.
3. **Soundness at longer sequences.** Lookup-argument changes target
   100 bits whole-run without trading away throughput.
4. **Weight hiding (P3).** The weights become committed and masked, rather
   than public, with new privacy accounting. We design and count before
   building.
5. **Integer fidelity.** Every profile is measured against the float model
   on standard benchmarks.

**How the DoW test community would use it.**
- A test and evaluation organization runs the open verifier, a small
  separately specified program, to check proofs that come attached to
  model outputs or evaluation reports.
- A model owner submits proofs of evaluation results on the tester's hidden
  test set, so the test items never leave the tester's control.
- The same verifier checks fielded systems' attestations after the fact.

**Plans to deliver resilient software:**
- The verifier is small, separately specified and open: it ships with a
  written specification and a reproducible benchmark suite.
- Today's engineering controls continue:
  - frozen code trees with source-hash manifests;
  - byte-identity gates between the CPU and GPU paths;
  - failing-first tests and named tamper controls that must fail on every
    run;
  - independent soundness and privacy reviews before any acceptance.
- In line with DARPA's preference for formal methods, we propose
  machine-checked verification of the verifier's core checks.

**Milestones** (all proofs verified; MEASURED on the stated hardware):
- **M1 (month 6):** the whole prover on the GPU for trained 8B at 512
  tokens, measured on one RTX 5090, at or above the model's 6.6
  positions/s; the external cryptographic review completed and published
  with fixes.
- **M2 (month 12):** attention-layout changes, at or above 9.4 positions/s;
  100 bits whole-run soundness; a demonstration proof of an evaluation
  result on a hidden test set.
- **M3 (month 18):** ≥50 proved tokens/s total workload for the complete
  trained 8B model on one high-end GPU; machine-checked verifier core.
- **Option (months 19–24):** the hidden-weight (P3) construction, counted
  and prototyped at TinyLlama-1.1B scale, with its privacy statement
  reviewed.

**[VICTOR: confirm the months.]**

### 1.3 Capabilities/Management Plan

**Principal Investigator:** **[VICTOR: name, background, prior research and
engineering record. Give peer-reviewed papers in bold in the bibliography,
if any.]**

The PI designed the system and makes every security and privacy ruling;
the rulings are recorded in a dated register. The implementation is done by
AI coding agents working in separate lanes with strict file ownership,
under the PI's direction. Each change is independently reviewed for
soundness and privacy before acceptance. The result is about 1,600 commits
in 11 months, with every claim tied to a recorded, reproducible artifact:
frozen source manifests, proofs and review reports.

**Evidence of execution:**
- the first private proof of a trained 8B model's next token, with hidden
  input, output and activations;
- two accepted privacy statements;
- a working media application that verifies proofs in a fresh process and
  fails closed on tampering.

We know the BAA counts peer-reviewed publication as strong evidence. A
technical report (IACR ePrint) and a peer-reviewed submission are planned
once the provisional patent is filed.

**Team and roles:**
- PI: architecture, security rulings, integration.
- **[VICTOR: proposed university cryptography co-investigator, for
  independent soundness and zero-knowledge review and the P3 design]**.
- **[VICTOR: external review firm]**.
- **[VICTOR: GPU engineer hire]**.

### 1.4 Disclosure of AI utilization (excluded from the page count)
See section 1.6. **[VICTOR: complete it truthfully.]**

### 1.5 Cost and Schedule

The schedule is 18-month base plus 6-month option, as in the milestones
above. **[VICTOR: confirm; fill the amounts.]**

| Line | Base | Option |
|---|---:|---:|
| PI labor | [VICTOR] | [VICTOR] |
| GPU / cryptography engineer | [VICTOR] | [VICTOR] |
| External cryptographic review (our other drafts budget about $35,000; re-quote) | [VICTOR] | — |
| University co-investigator subaward (if teamed) | [VICTOR] | [VICTOR] |
| AI agent usage and cloud GPU (incl. H100-class time for a second "high-end GPU" data point) | [VICTOR] | [VICTOR] |
| Hardware (the RTX 5090 machine is already owned; spares, storage) | [VICTOR] | — |
| Formal-methods effort on the verifier | [VICTOR] | — |
| Travel (PI meetings) | [VICTOR] | [VICTOR] |
| Indirect costs | [VICTOR] | [VICTOR] |
| **Total** | **[VICTOR]** | **[VICTOR]** |

### 1.6 Disclosure of AI Utilization — starting text (Victor must verify and complete)

**Part A:** ☒ AI tools were used during the development of this abstract.

**Part B (abstract development):**

| Phase | Tool(s) | How used | Human authorship and validation safeguard |
|---|---|---|---|
| 1. Brainstorming and concept | **[VICTOR]** | **[VICTOR]** | **[VICTOR: state truthfully which hypotheses and methods are yours]** |
| 2. Literature and prior art | Claude (Anthropic) | Located program pages and prior work (SIEVE, zkLLM, DeepProve, zkGPT, zkAgent) | **[VICTOR: you checked each cited source]** |
| 3. Technical drafting | Claude (Anthropic) | Drafted the text from the project's recorded measurements, review reports and decision register | **[VICTOR: you rewrote and approved every technical statement; every number traced to a recorded artifact]** |
| 4. Editorial | Claude (Anthropic) | Fitted the template and page limit | **[VICTOR]** |
| 5. Formatting | **[VICTOR]** | **[VICTOR]** | **[VICTOR]** |

**AI in the performance of the research (factual):** AI coding agents
(Claude; OpenAI GPT models) implement and test code in separate lanes under
the PI's direction. All security and privacy rulings are made and recorded
by the PI. Soundness and privacy claims are accepted only after independent
review, and from this program on, after external review. **[VICTOR: confirm
this describes your role accurately; the template requires that AI be "an
adjunct to — and not a replacement for — human creativity, insight, and
direction".]**

### 1.7 Bibliography (optional; excluded from the page count)
- DARPA SIEVE BAA HR001119S0076 (2019).
- Sun, Li, Zhang, "zkLLM", ACM CCS 2024 (arXiv 2404.16109).
- Qu et al., "zkGPT", USENIX Security 2025.
- "DeepProve", IACR ePrint 2026/1112.
- "zkAgent", IACR ePrint 2026/199.
- **[VICTOR: your own publications in bold; the preprint once posted.]**

---

## 2. First email to an IPTO program manager (≤150 words)

Choose a program manager from https://www.darpa.mil/about/program-managers
whose portfolio covers Inherent Security and Privacy or assured AI. This
email describes results only, not the construction.

> **Subject:** HR001126S0011 — private, checkable proofs of AI model runs
>
> Dear [PM name],
>
> I lead **[VICTOR: company]**, a small US startup building zero-knowledge
> proofs of AI inference that hide the input, the output and every
> intermediate activation. Anyone can check that a stated trained model
> produced a stated result, without seeing the data.
>
> Measured on one laptop CPU: a private next-token proof of a trained
> Llama-3-8B, proved in 192 s and verified in 43 s, with about 97 bits of
> soundness. Privacy has been reviewed internally; there is no external
> audit yet.
>
> I would like to propose, under Inherent Security and Privacy and assured
> AI: a path to at least 50 proved tokens per second for a full 8B model on
> one GPU, hidden weights, and checkable evaluation results on hidden test
> sets.
>
> Could we speak for 20 minutes before I submit an abstract?
>
> **[VICTOR: name, title, phone]**

(About 138 words including the greeting and signature, under the 150-word
limit.)

---

## 3. Blanks only Victor can fill

1. Company name, SAM.gov UEI, BAAT/Extranet accounts (the UEI is required
   at abstract submission).
2. Technical and administrative POC details.
3. Background, and any peer-reviewed publications. Whether to team with a
   university cryptographer (strongly advised, for the "strong evidence"
   criterion).
4. Award instrument (grant vs OT for research); total cost and the cost
   table; confirm the 18 + 6-month schedule.
5. The AI-use disclosure, truthfully; rewrite the technical paragraphs in
   your own words.
6. Other solicitations actually sent (NSF pitch, Foresight, EA Funds).
7. Fundamental research or not. DARPA decides, but you state a view. Your
   open-core position (verifier open, prover the product) and the plan to
   publish after the provisional patent both bear on it.
8. Which program manager to email, and when. The email can go now; the
   abstract waits for the UEI.
