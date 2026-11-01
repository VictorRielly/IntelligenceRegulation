# Anthropic External Researcher Access: starting answers ($1,000 of API credits; reviewed the first Monday of each month)

**Next review:** **Mon Nov 2**, then Mon Dec 7.
**Form:** https://forms.gle/pZYC8f6qYqSKvRWn9 (fields in `FORM_FIELDS.md` §1).

**Before you start:**
- Create a Claude Console account at console.anthropic.com.
- Copy the **Organization ID** from Settings → Organization.

**Confidentiality:** answers are treated as non-confidential, so describe results, not internals.

**Why bother:** the money is small, but it pays for the AI agents that do the engineering, and it takes 10 minutes.

Starting draft; rewrite freely.

---

**1. Name of primary contact:** Victor Rielly

**2. Organization:** leave empty. (Or "Hashline (independent project)".)

**3. Recommended by an Anthropic employee?** No

**5. Organization ID:** [V: from the Console]

**6. Applicant description** (under 200 words):
> I am an applied mathematician:
> - PhD from Portland State University (2025);
> - papers in the Journal of Computational Physics and TMLR;
> - postdoctoral researcher at the Translational Genomics Research Institute;
> - earlier R&D at Intel and NASA.
>
> Since December 2025 I have led Hashline, a zero-knowledge prover for private language-model inference. I set the
> design and make the security and privacy rulings. Claude Code agents do most of the implementation and review,
> under strict rules: byte-identical outputs, independent soundness and privacy reviews, and a recorded measurement
> behind every claim. That is about 1,640 commits so far.

That is about 95 words.

**7. Research and why credits matter** (under 300 words):
> **Topic.** Zero-knowledge proofs that a stated AI model, run on a hidden input, produced a stated output. The
> input, the output and every intermediate activation stay hidden; anyone can verify the proof. This makes AI claims
> checkable without disclosing data or trusting the operator: evaluation scores on hidden test sets, content-safety
> verdicts, and which model produced an output.
>
> **Results so far:**
> - a private next-token proof for a trained Llama-3-8B;
> - private proofs of a real 3B safety classifier's verdicts;
> - a GPU backend that proves one 8B layer over 128 hidden tokens in 0.36 s, about 11 proved tokens per second for
>   the full model.
>
> **Why credits matter.** The project is self-funded, and Claude agents do the engineering: GPU kernels,
> byte-identity gates, and independent review passes that check soundness and privacy arguments. The next phase is
> porting the GPU prover to NVIDIA and preparing an open-source release with a specification. Each needs long agent
> sessions for implementation and adversarial review. API credits let the review agents run on the API alongside the
> implementers, so every change gets an independent check.
>
> **Output.** Everything will be open source, with a public specification, reproducible benchmarks and a preprint.

That is about 210 words.

**8. More than $1,000?** No

**9. Quality of service:** "I'm fine with receiving a low quality of service"

**10. Google Scholar or GitHub:** [V: your Google Scholar profile, if you have one; otherwise LinkedIn]

**11. Additional information:** leave empty.

**12. Located in the United States?** Yes

**13. Terms:** tick.
