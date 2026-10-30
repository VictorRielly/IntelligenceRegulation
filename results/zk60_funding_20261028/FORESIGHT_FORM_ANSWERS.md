# Foresight AI for Safety & Science Nodes — answers per form field

Built from the form Victor saved on 2026-10-28 (`Downloads\AI for Safety &
Science Nodes RFP 2026 - Airtable.htm`), his resume (`Resume (10).pdf`) and
the project's recorded evidence. Deadline: **Fri 2026-10-31, 23:59 PDT**;
decisions in January 2027. **[VICTOR: …]** = only you can decide or fill in.
Character counts for limited fields are checked (see the end of this file).

---

## About you

**Full name:** Victor Rielly ✓ (keep)

**Email:** victor23@pdx.edu ✓ (keep)

**Website, CV, or LinkedIn:** https://www.linkedin.com/in/victor-rielly-50508b3a/ ✓

**Affiliated organization(s) or project(s):** leave blank. The project is
independent. (Your TGen postdoc is mentioned under track record.)

**Applying as an:** Individual ✓

**What is your / your team's track record?** (replace your current text)
> PhD in Applied Mathematics (Portland State University, 2025, machine-learning
> emphasis); postdoc at the Translational Genomics Research Institute (2025–).
> Peer-reviewed papers in the Journal of Computational Physics and TMLR, a third
> accepted in a SIAM journal and two more under review, introducing kernel
> methods that learn differential equations from data. R&D intern at Intel
> (machine-learning models of circuit-simulation noise) and NASA (Marshall and
> Glenn). Lead developer of a live transcription and translation app used at
> 10+ sites in 3 states. On this project (since December 2025, about 1,600
> commits): a working zero-knowledge prover for private inference of trained
> language models. A Llama-3-8B next-token proof takes 192 s on a laptop.
> Every release gets independent soundness and privacy reviews.

**Project participant(s):**
> Victor Rielly — founder and principal investigator: system design, security
> and privacy decisions, and direction of the AI coding agents that implement
> and review the prover —
> https://www.linkedin.com/in/victor-rielly-50508b3a/

**Primary region / country:** America / United States ✓

**Primary reference (full name AND email):** the field asks for both and has
only the email. **[VICTOR: full name, plus title if you like]** —
klahouel@tgen.org

**What type of org?** Individual - US

## About your project

**What are you applying for?** Funding (Grant) ✓. Consider also:
- **Physical Node (Bay Area).** It is "strongly prioritised". If you select it,
  the node questions below become required.
  **[VICTOR: yes or no; I recommend yes for quarterly sprints if travel from
  Portland is feasible]**
- **Compute.** Ask for modest GPU time; see the Compute section.
  **[VICTOR: yes or no; I recommend yes]**

**RFP focus area:** **2. Supercollaboration and decentralized alignment.** Its
security side asks for "scalable verification and proof techniques" and
"checks and balances that no one party controls", and this area gets the
larger grants. (Area 4, AI Insurance & Open Governance, also fits, but it gets
smaller amounts.)

**Project title:**
> Private, checkable AI runs: zero-knowledge proofs that a stated model
> produced a stated result, without revealing the data

**What are you trying to do? (max 350 characters, zero jargon)**
> We make it possible to check what an AI did without seeing the private data
> it used. Our proofs show that a specific, named AI model, given hidden input,
> produced a specific result. Anyone can verify the proof, but the input, the
> output and the model's internal steps stay secret, so nobody has to trust
> the operator.

**How does your project address the RFP area you selected? (max 500 characters)**
> Area 2 asks for scalable verification and checks that no single party
> controls. Our proofs are such a check: an AI operator proves which model and
> policy produced a result, and anyone verifies it without the data. Built
> today: private proofs for a trained 8-billion-parameter language model and a
> safety classifier. The grant open-sources the verifier, a specification and
> benchmarks, funds an outside security review, and adds proofs of test scores
> on hidden test sets.

**How is today's approach limited? What is new in your approach and what does
success look like?**
> **Today:** checking an AI claim ("this post was screened by safety model X",
> "this model scored 92% on a held-out test") means either trusting the
> operator or giving the private data (user content, test sets) to an auditor.
> General-purpose proof systems that could remove that trust are far too slow
> for language models. Published proof systems for language models mainly aim
> to hide the model, not the user's data.
>
> **What is new:** a proof system built for transformer arithmetic. It hides
> the input, the output and every intermediate value, with a stated,
> mechanically checked privacy guarantee and counted soundness (about 97 bits
> per run). Measured on one laptop, single runs: a private next-token proof
> for the trained Llama-3-8B in 192 s, verified in 43 s; TinyLlama in 85 s. A
> demo app labels posts using proved safety-classifier verdicts.
>
> **Success in 12 months:**
> - an open-source verifier, specification and reproducible benchmarks that
>   anyone can run;
> - a published external security review;
> - public proofs of evaluation scores on hidden test sets that an insurer or
>   auditor can check without seeing the test items.

**If there are risks, is it possible to differentially advance
safety-enhancing aspects of the technology first?**
> Two risks.
> 1. **False assurance:** a buggy proof system could certify claims that are
>    not true. We publish the specification and the counted soundness, fail
>    closed on every check, and make an external security review a funded
>    milestone before wider use.
> 2. **Misuse of privacy:** an operator could use proofs to look compliant
>    while hiding problems. A proof establishes only the stated fact about the
>    stated model, never anything else, and open verification lets anyone
>    check every published claim.
>
> Yes, the safety-enhancing parts come first. This grant funds verification
> only: the open verifier, the specification, the benchmarks, the review and
> the published proofs. It adds no capability to any AI model. It makes claims
> about models checkable.

**Start and end time, key milestones:** (February 2027 – January 2028)
> - **Feb 2027:** start.
> - **M1, Apr 2027:** open-source verifier, specification and benchmark suite
>   (commands, inputs, expected results) for private-inference proofs of
>   TinyLlama, Llama-3-8B and the Shieldstral safety classifier.
> - **M2, Jul 2027:** external cryptographic review of soundness and privacy;
>   the review and our fixes published.
> - **M3, Oct 2027:** proofs of evaluation results on hidden test sets ("model
>   M scored S on test set T", with T hidden), with verifier support; a public
>   preprint and a peer-reviewed submission.
> - **M4, Jan 2028:** published GPU throughput benchmarks, and a design note
>   for hiding model weights (for labs' confidential models).

**If this goes well, how do you scale it for safe AI in 3 years?**
> Three steps.
> 1. **Speed and size:** move proving to GPUs (target: 50 proved tokens per
>    second for an 8B model on one high-end GPU) and extend to larger models.
>    AI coding agents already do most of our engineering under strict review
>    rules, so better AI agents directly speed up our development.
> 2. **Adoption:** make proofs a standard attachment to AI claims, with the
>    open verifier as the common checker:
>    - content labels on social platforms, such as a Bluesky labeler that
>      publishes a proof with each label;
>    - evaluation results for insurers and auditors;
>    - model-provenance records.
> 3. **Confidential models:** extend to hidden weights, so labs can prove
>    results about their models without revealing them. That is the missing
>    piece for outside assessment of frontier labs.
>
> As more decisions are made by AI systems, cheap, checkable proofs of which
> model did what become a basic accountability layer.

**Open-source commitment:** **Yes.** (Your ruling: the funded work product is
the verifier, the specification, the benchmark suite, the review report and
all published proofs and data. The prover implementation is developed and
funded separately. Say so in the next field.)

**Additional information and links:**
> Open-source scope: the funded work product, meaning the verifier, the
> specification, the benchmark suite, the review report, and every proof and
> dataset the grant produces, will be released under an open-source license.
> The prover implementation is developed and funded separately. All numbers
> above are single runs on one laptop (RTX 4070, 8 GB). Soundness and privacy
> have been reviewed by independent reviewers within the project; an external
> audit is milestone M2. Publications: arxiv.org/abs/2206.15215,
> arxiv.org/abs/2306.10189, arxiv.org/abs/2503.13791. A demo video is
> available on request. **[VICTOR: add a demo link if you record one]**

## Physical Node (only if you select it)

- **Which node:** Bay Area.
- **How long:** **[VICTOR]** e.g. "one-week sprints once a quarter, Feb 2027 –
  Jan 2028".
- **Who:** Victor Rielly (1 person).
- **How:** co-working during sprints, plus events.
- **More information:**
  > I would run a session on checkable AI claims with a live demo (proving and
  > verifying a private classifier verdict), and work with the node's
  > verification and AI-insurance projects on what proofs their assessments
  > need.
- **Open to one workshop:** Yes.

## Funding

- **Requesting funding:** Yes. **$100,000 for 12 months** **[VICTOR: adjust;
  add a stipend if you want one]**:
  - AI agent usage and cloud GPU: $45,000
  - external cryptographic review: $35,000
  - GPU hardware or cloud for throughput work: $10,000
  - overhead: $10,000
- **Overhead:** 0–10% (about 10% of direct costs).

## Compute (if you select it)

> GPU time for prover benchmarks and open benchmark results: about **[VICTOR:
> e.g. 300]** hours on 80 GB GPUs (H100-class) over the year. Today's work
> runs on an 8 GB laptop GPU, which cannot hold an 8B proof on the GPU alone.

## Sharing and miscellaneous

- **Share with Lightcone Commons:** **[VICTOR]** — I recommend **Yes**.
  Lightcone Commons is itself a funder (rounds of $15–25M), and these answers
  describe results, not how the prover works, so sharing doesn't disclose the
  invention. Keep any implementation detail out of every non-confidential
  field. Choose No if you'd rather wait until the provisional patent is filed.
- **Share with grant advisors:** Yes.
- **Confidential information:**
  > A US provisional patent application on the prover is being prepared. The
  > grant's open-source deliverables will be released after that filing,
  > before milestone M1. The prover implementation is not part of the funded
  > work product.
- **How did you discover this opportunity:** **[VICTOR]** e.g. "While
  researching AI-safety funding programs (Foresight website)."
- **Seminar group:** Yes (networking; optional).
- **Authority to submit:** confirm.

---
Character counts (checked by script):
- "What are you trying to do?": 317 / 350
- "How does your project address …": 470 / 500
