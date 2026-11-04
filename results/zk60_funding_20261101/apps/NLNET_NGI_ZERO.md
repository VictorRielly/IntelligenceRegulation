# NLnet (NGI Zero Commons Fund): proposal draft

> **Skip this round (checked 2026-11-01 on nlnet.nl).**
> - **Open funds:** two, both closing Nov 3, 12:00 CET.
>   - **Restack:** "AI-related projects are not within scope" unless they have over 1M active users.
>   - **CodeSupply:** software-packaging metadata.
> - **The form:**
>   - summary 1,000 characters; budget 4,000; comparison 4,000; challenges 4,000; ecosystem 2,000; "right person"
>     2,000; other funding 1,000;
>   - it says "Proposals and projects should be made by humans, not AI", asks for prompt logs, and asks whether the
>     codebase contains AI-generated code.
> - **For a future call:** keep this file as facts only, and Victor writes the text himself.

**Deadline.** Listed on 10-28 as **3 Nov 2026**. NLnet's deadlines are 12:00 CET/CEST, i.e. **04:00 Pacific**. Check
the exact time in `OPEN_CALLS_VERIFIED.md` and submit the evening before. If it has moved, the next call is two months
later.

**Why it is worth 20 minutes.**
- €5k–€50k, paid per completed milestone.
- Individuals anywhere may apply.
- NLnet adds free support services: a security audit through its partners, packaging, accessibility and licensing
  advice.
- It is open-source only, which suits D48.
- Fit is moderate: NLnet wants a European dimension, given below.

**Form.** https://nlnet.nl/propose/ (choose the "NGI Zero Commons Fund" call).
- The fields below are NLnet's standard proposal form; the agent's `FORM_FIELDS.md` confirms or corrects them.
- **Generative-AI disclosure:** NLnet asks whether generative AI was used to write the proposal. Answer truthfully
  (drafted with AI assistance from the project's records, reviewed and edited by me). If it asks for the prompts or
  the unedited output, attach `NLNET_GENAI_LOG.md` (to be written once the field is confirmed).

**The ask.** €50,000.

---

### Contact
Victor Rielly · victor23@pdx.edu · [phone: kept in local files only] · USA · Organisation: none (individual)

### Proposal name
Hashline: open zero-knowledge proofs of private AI inference

### Website / wiki
[none public yet; write: "Repository to be published under a permissive licence at the start of the grant; private
access for reviewers on request"]

### Abstract: "Can you explain the whole project and its expected outcome(s)?"
> Hashline lets anyone verify what an AI model did without seeing the data it ran on. A proof shows that a stated
> model, given a hidden input, produced a stated result: a classifier's verdict on a post, a score on a test set, or
> a next token. The input, the output and every intermediate activation stay hidden. The verifier learns only the
> facts the owner chooses to publish.
>
> **How it works.** The system is hash-based (Ligero-style commitments, sumcheck and lookup arguments over a 64-bit
> prime field), so there is no trusted setup and no reliance on secure hardware. Soundness is counted at about 97
> bits per run.
>
> **What already works:**
> - private proofs for a trained Llama-3-8B (a next token in 192 s on a laptop CPU);
> - proofs for a real open-weight 3B content-safety classifier;
> - a new GPU backend that proves an 8B-sized layer over 128 hidden tokens in 0.36 s.
>
> **Expected outcomes of this grant:**
> 1. the complete prover and verifier released under a permissive licence, with a written specification of the proof
>    system and its privacy statement;
> 2. the GPU prover ported to NVIDIA hardware, with reproducible benchmarks;
> 3. a stand-alone verifier library and command-line tool that platforms, auditors and researchers can embed;
> 4. security hardening, with the findings of an external review fixed.
>
> **Why it matters.** Platforms and AI providers can show regulators and users, for example under the Digital
> Services Act and the AI Act, that a stated model and policy were applied. They can do it without exporting
> personal data, which fits GDPR's data minimisation.

### "Have you been involved with projects or organisations relevant to this project before? And if so, can you tell us a bit about your contributions?"
> I created and lead Hashline (since December 2025, about 1,640 commits). I led the design of the proof system, made every
> security and privacy decision, and ran its engineering process: byte-identity gates, independent soundness and
> privacy reviews, and a recorded measurement behind every claim. AI coding agents implement under that review.
>
> Before this:
> - a PhD in applied mathematics (Portland State University, 2025), with papers in the Journal of Computational
>   Physics and TMLR on kernel methods for learning differential equations;
> - research internships at Intel and NASA;
> - three years as lead engineer of a networked IoT device, including its own VPN layer;
> - lead developer of a live transcription and translation system used at more than ten sites.

### Requested amount
€50,000

### "Explain what the requested budget will be used for? Does the project have other funding sources, both past and present?"
> The budget pays engineering time, at €80/hour for about 625 hours, delivered by me and a contracted GPU engineer.
>
> | Task | Hours | € |
> |---|---:|---:|
> | 1. Open release: licence and secret scans, third-party licence inventory, build and test instructions, contributor docs | 60 | 4,800 |
> | 2. Specification of the proof system and its privacy statement, written for outside reviewers | 90 | 7,200 |
> | 3. NVIDIA GPU port of the batched sumcheck and commitment kernels (now Apple Metal), byte-identical to the CPU path | 250 | 20,000 |
> | 4. Stand-alone verifier library and command-line tool, with test vectors | 100 | 8,000 |
> | 5. Reproducible benchmarks: scripts, expected digests, CI | 60 | 4,800 |
> | 6. Fixes from NLnet's security audit and an external review | 65 | 5,200 |
> | **Total** | **625** | **50,000** |
>
> **Other funding.** There is no funding so far; the project has been self-funded. I am applying in parallel to
> AI-safety funders (for example EA Funds and Lightcone Commons) for a larger 12-month budget that hires a full-time
> engineer. NLnet's tasks above are separate deliverables. If any task is funded twice, I will tell both funders and
> take the money once.

### "Compare your own project with existing or historical efforts."
> - **General zkML frameworks** (EZKL, built on Halo2; zkLLM, CCS 2024):
>   - EZKL handles small models.
>   - zkLLM mainly keeps the model's weights private, and its proofs take minutes per inference for a 13B model.
>   - Hashline is built to hide the user's data (inputs, outputs, activations), with a written privacy statement and
>     a mechanical privacy gate.
> - **DeepProve (Lagrange)** is published under a restrictive non-open licence.
> - **Attestable** claims 53 proved tokens/s on one H100 but is closed source.
>   - Hashline's whole stack will be open under a permissive licence.
>   - It is about 4.5× behind that claim on our current machine; we say so, and the GPU port in this grant is the
>     next step.
> - **Trusted execution (confidential computing)** relies on hardware vendors and attestation keys. Hashline relies
>   only on a hash function and is plausibly post-quantum. The two can complement each other.

### "What are significant technical challenges you expect to solve during the project, if any?"
> 1. **Porting the GPU prover to CUDA while keeping every proof byte-identical to the CPU reference.** The batched
>    sumcheck design runs the Fiat-Shamir hashing and masking on the GPU, and the CPU replays each round to check it,
>    so a GPU fault cannot change a proof. That property must survive the port.
> 2. **Memory and bandwidth.** The commitments' Reed-Solomon encoding and Merkle hashing are bandwidth-bound. Reaching
>    the target throughput needs kernels at roughly a quarter to a third of the GPU's memory bandwidth.
> 3. **A verifier library that is small, dependency-light and hard to misuse:** domain-separated transcripts, strict
>    receipt parsing, and failing closed on every check.
> 4. **A specification precise enough for outside cryptographers to review soundness and zero-knowledge** without
>    reading the code first.

### "Describe the ecosystem of the project, and how you will engage with relevant actors and promote the outcomes?"
> **Users:**
> - trust-and-safety teams at platforms (proving that a content classifier ran and what it said);
> - AI evaluators and auditors (proving scores on hidden test sets);
> - researchers in verifiable computation.
>
> **Outreach:**
> - publish the repository, the specification and the benchmarks;
> - post an IACR ePrint preprint and submit to a peer-reviewed security venue;
> - present at zero-knowledge community venues (ZK Hack, ZKProof);
> - offer the verifier as a plugin for open trust-and-safety tooling, with a public demo labeler that publishes a
>   proof with each label.
>
> In Europe, the verifier helps platforms and AI providers meet the transparency obligations of the DSA and the AI
> Act while minimising personal data under the GDPR.

### Attachments
Optional. A one-page budget is already in the answer above.

### Generative AI
[See the note at the top.]
