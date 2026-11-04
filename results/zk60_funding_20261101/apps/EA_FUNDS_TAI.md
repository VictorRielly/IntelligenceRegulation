# EA Funds Transformative AI Fund: field-by-field starting answers (matched to the real form, 2026-11-01)

**Form.** https://av20jp3z.paperform.co/?fund=Transformative%20AI%20Fund (no login).
- **It cannot be edited after you submit.** Fields: `FORM_FIELDS.md` §7.

**Limits.**
- **Total:** at most 10,000 characters, and they recommend 2,000–5,000. The text answers below are counted by script
  (see the end).
- **Short description:** 120 characters at most. It may be published without checking with you.
- **Summary:** 1,000 characters at most. They read it first.

**Leave optional fields completely empty** rather than writing "N/A". They say "N/A" can delay processing.

**Response times.** The form says they are "longer than usual at the moment". It offers a "decision within eight
weeks" option only if you also tick the EA Infrastructure Fund, so skip that.

Starting draft; rewrite freely.

---

**1. Fund:** Transformative AI Fund

**2. Confirmation of fund scope:** tick.

**3. Funding from Coefficient Giving:** INDIVIDUAL

**4. Name:** Victor Rielly

**5. Organization name:** leave empty.

**6. Grant program:** **Applied Transformative AI Grants** ("technical or applied governance projects"; the output is
built and deployed).

**8. Main collaborators:** leave empty. The collaborators are to be hired; this is covered in the goals.

**9. Email:** victor23@pdx.edu

**10. Employed by CEA?** No, never.

**11. Short description** (max 120):
> Open, GPU-fast zero-knowledge proofs that a stated AI model produced a stated result, without revealing the data.

**12. Summary** (max 1,000):
> I built Hashline, a zero-knowledge prover for transformer inference. A proof shows that a stated model, run on a
> hidden input, produced a stated result. Anyone can verify it, while the input, output and activations stay hidden.
> That lets evaluators, auditors and platforms make AI claims checkable without trusting the operator or disclosing
> data.
>
> Working today:
> - private proofs for a trained Llama-3-8B and a real 3B safety classifier;
> - soundness counted at about 97 bits;
> - a GPU backend at about 11 proved tokens/s for an 8B model on one Apple GPU.
>
> I lead part-time and take no salary. The grant hires an engineer to port the prover to NVIDIA GPUs (target 50
> tokens/s), release it fully open source, and fund an external security review. The only fast competitor is closed
> source.

**13. Project goals:**
> **Actions (12 months):**
> 1. Port the GPU prover to NVIDIA (RTX 5090, then H100), byte-identical to the CPU path; publish 8B throughput.
>    Target: 50 proved tokens/s on one card.
> 2. Release the whole stack under a permissive licence, with a specification and reproducible benchmarks.
> 3. Commission an external review of soundness and zero-knowledge, and publish it with fixes.
> 4. Prove evaluation scores on hidden test sets.
>
> **Path to impact:** governance of advanced AI needs claims that can be checked without trusting one party or
> leaking data. That covers evaluations, audits, deployment commitments and content screening. An open, reviewed,
> fast prover makes such claims routinely checkable. Version 2 hides the weights too, so labs can prove facts about
> confidential models.
>
> **How we will know:** a published benchmark anyone can rerun, a published external review, and outside parties
> verifying proofs with the open verifier.

**14. Track record:**
> - **Hashline (since December 2025):** I led the design, made every security and privacy ruling, and directed AI
>   coding agents under strict rules (byte-identical outputs, independent soundness and privacy reviews, a recorded
>   measurement behind every claim), about 1,640 commits.
> - **Results:** a private next-token proof of trained Llama-3-8B (192 s on a laptop CPU, 43 s to verify), and a 34×
>   per-layer speedup on GPU.
> - **Failures:** a laptop crash lost demo artifacts, which led to durable storage; and several speed ideas measured
>   no gain and were reverted and recorded.
> - **Before this:** a PhD in applied mathematics (Portland State University, 2025); papers in the Journal of
>   Computational Physics and TMLR; R&D at Intel and NASA.
> - **Spending so far:** self-funded, with no staff.

**15. Public portfolio:**
> - arxiv.org/abs/2206.15215
> - arxiv.org/abs/2306.10189
> - arxiv.org/abs/2503.13791
>
> The prover is to be open-sourced; reviewers can have access on request.

**16. Funding amount and breakdown:**
> Requested: $150,000 for 12 months (budget sheet linked).
> - 50% ($75,000): a half-time GPU / zero-knowledge engineer, on contract;
> - 33% ($50,000): an external cryptographic review;
> - 16% ($24,000): AI-agent usage and cloud GPU;
> - 1% ($1,000): accounting.
>
> No salary for me. Range: $60,000 buys the NVIDIA port and the open release; $300,000 adds a full-time engineer, a
> quarter-time cryptographer and a paper. The project's total budget is the same as this request.

**Budget sheet link:** import `budget_ea_funds.csv` into Google Sheets, set it to "Anyone with the link can view", and
paste the link here. [V]

**17. Requested amount (USD):** 150000

**18. Organizational budget:** leave empty.

**19. Alternatives to funding:**
> Without this grant the work continues part-time and slowly. Applications in the last 12 months: [V: update at
> submission]. For example:
> - GTR AI Safety Fund, Nov 2026, pending;
> - Lightcone Commons, Nov 2026, pending;
> - Y Combinator W27, Nov 2, pending (equity).
>
> No grant has been received.

**20. Use for additional funding:**
> A full-time engineer instead of half-time, a quarter-time applied cryptographer, and earlier work on hiding the
> weights.

**21. Confidential information:** leave empty.

**22. LinkedIn/CV:** https://www.linkedin.com/in/victor-rielly-50508b3a/

**23. File upload:** `Victor_Rielly_CV_grant.pdf` (optional).

**24. Start date / end date:** 2027-01-01 / 2027-12-31 [V: adjust]

**25. Currency:** USD

**26. Location:** Portland, Oregon, USA (both)

**27. China or India?** No

**28. An award for past achievement?** No

**29. Anyone under 18?** No

**30. Lobbying?** leave empty (none).

**31. References:**
> - Bruno Jedynak, [reference email: local files only]: Portland State University; co-author of my research. [V: confirm the role,
>   e.g. PhD advisor]
> - Kamel Lahouel, [reference email: local files only]: TGen; co-author and research colleague. [V: confirm]

**32. Referral to other funders:** Forward.

**33. Secondary fund (EA Infrastructure):** No.

**34. How did you hear about EA Funds?** [V]

**36. Public reporting:** PUBLIC.

**37. Network sharing:** Yes.

**38. Anything else:** leave empty.

**39–40.** Tick both after re-reading.

---
Character counts (script, 2026-11-01): short description 113/120; summary 787/1,000; goals 934; track record 797; portfolio 153; budget 465; alternatives 290; additional 120; references 223. Total about 3,900 (recommended 2,000–5,000; maximum 10,000).
