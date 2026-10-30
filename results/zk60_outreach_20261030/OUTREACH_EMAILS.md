# Outreach emails: drafts for Victor

Written 2026-10-30 ~20:30 UTC by a Claude agent. **Drafts only: nothing has been sent.**
Victor sends each one under his own name, after the repository and the preprint are public, so that
the links resolve.

**How to read this file.**
- Each email has a subject line, a one-line "why them" note (for Victor, not for the recipient) and
  a body of at most 180 words.
- Fill every `<...>` before sending. Recipient names and addresses are not in the project files.
- **Numbers used in every email** [MEASURED, n = 1, one laptop CPU]: about 456 s to prove per
  category with 8 threads; an 848 MB receipt; a 96-bit whole-run floor; the classifier privacy
  statement still a draft; no external audit. Sources are at the end.

---

## 1. Lagrange (the DeepProve team)

**Subject:** Hidden-input proofs as an open DeepProve feature, or a joint paper?

**Why them:** DeepProve is a leading zkML prover with a public paper (ePrint 2026/1112, university
co-authors). It is far faster than ours, and we did not find hidden inputs and activations in its
published description. Under D51 it is an upstream target. <CONFIRM: DeepProve's public repository
and licence, <DEEPPROVE_REPO_URL>.>

> Hi <NAME>,
>
> I maintain an open-source prover (<REPO_URL>, <LICENCE>) that proves an LLM's computation while
> hiding the input, the output and every intermediate activation. The weights are public. In its
> first real use, Mistral's Shieldstral-1.0-3B judged a post, and the receipt reveals only the
> verdict, the model, the policy and the post's length.
>
> Measured once on a laptop CPU: about 456 s to prove per category, 848 MB receipts, a 96-bit
> floor. DeepProve is much faster with much smaller proofs. I am not trying to compete on speed.
>
> **My ask:** would your team consider hidden inputs and outputs as an open DeepProve feature? We
> would contribute the masking design (a hiding Ligero-class commitment and masked sumchecks) and
> our reviewed privacy argument. A joint paper on what privacy costs at scale would also work. A
> 30-minute call would tell us whether it fits your architecture.
>
> Preprint: <EPRINT_URL>. The privacy argument and its reviews are in the repository. It has not
> been externally audited.
>
> <SIGNATURE>

---

## 2. EZKL / Zkonduit

**Subject:** Hiding every activation at multi-billion-parameter scale: upstream to EZKL?

**Why them:** EZKL is a widely used zkML library and has an external audit (Trail of Bits, March
2025, per our research notes). D51 lists it as an open upstream target. <CHECK BEFORE SENDING:
EZKL's licence, and which input, output and parameter visibility options it already offers. Neither
is in the project files. If EZKL already hides inputs, reword the ask around scale (a 3B classifier
and an 8B next token) and around the written privacy argument.>

> Hi <NAME>,
>
> I maintain an open-source prover (<REPO_URL>, <LICENCE>) that proves transformer inference while
> hiding the input, the output and every intermediate activation, with public weights. In its first
> real use, Mistral's Shieldstral-1.0-3B judged a post, and the receipt reveals only the verdict,
> the model, the policy and the post's length.
>
> Measured once on a laptop CPU: about 456 s to prove per category, 848 MB receipts, a 96-bit
> floor. It is slow and large. What may be useful to you is the design: a hiding hash-based
> commitment, masked sumchecks, and a privacy argument that independent reviewers attacked step by
> step. It has not been externally audited.
>
> **My ask:** a 30-minute call to see whether any part belongs upstream in EZKL as an open feature,
> and what your users would need from it. Whatever helps, we would write and test it with you.
>
> Preprint: <EPRINT_URL>.
>
> <SIGNATURE>

---

## 3. Daniel Kang (UIUC)

**Subject:** Trustless audits with hidden inputs: a research collaboration?

**Why them:** His "Trustless Audits without Revealing Data or Models" (ICML 2024) and his ZKML work
share this project's thesis. UIUC is a US research institution, which STTR, SaTC and I-Corps
require. He may also be the partner Victor is looking for under D47. <VICTOR DECIDES: whether to
mention the partner role at all.>

> Dear Professor Kang,
>
> Your work on trustless audits without revealing data or models is close to what I have built: an
> open-source prover (<REPO_URL>) that proves an LLM's computation while hiding the input, the
> output and every activation, with public weights. In its first real use, Mistral's
> Shieldstral-1.0-3B judged a post, and the receipt reveals only the verdict, the model, the policy
> and the length. Measured once on a laptop CPU: about 456 s per category, 848 MB receipts, a
> 96-bit floor. There is no external audit yet.
>
> **My ask:** would you be open to a research collaboration, starting with co-authoring the
> conference version of the preprint (<EPRINT_URL>)? Candidate venues are USENIX Security or CCS.
> The open questions include speed, hiding the weights, and an audit methodology. I would value a
> 30-minute call.
>
> <OPTIONAL, Victor's call: "I am also looking for a research partner who could lead the next phase,
> and would be glad to discuss what that could look like.">
>
> <SIGNATURE>

---

## 4. Armilla AI (partner program)

**Subject:** Proved classifier verdicts as an underwriting signal

**Why them:** Armilla's partner program says it integrates partners' risk signals into its
underwriting. A proof that a named safety filter ran on each item is such a signal. Revenue would
come through its insured clients, not from Armilla (per our research notes).

> Hi <NAME / Armilla partnerships team>,
>
> Your partner program says it feeds technology partners' risk signals into underwriting. I would
> like to test whether one more signal is useful: a cryptographic receipt that a named safety
> classifier really ran on each piece of content, and what it said, while the content stays hidden
> from whoever checks the receipt.
>
> This works today as a research prototype (<REPO_URL>, open source). Mistral's open
> Shieldstral-1.0-3B classifier judged a real post, and the receipts are anchored on a public
> testnet. Measured once on a laptop: about 456 s and an 848 MB receipt per category. It is not
> audited.
>
> **My ask:** a 30-minute call as a prospective technology partner. I would like to learn whether a
> proved verdict could count as underwriting evidence, and what such a receipt would have to state
> for your underwriters.
>
> One page with the details: <ONE_PAGER_URL>.
>
> <SIGNATURE>

---

## 5. Checkstep (moderation and DSA transparency)

**Subject:** Statements of reasons backed by a proof: a small pilot?

**Why them:** Checkstep is a moderation and DSA / OSA compliance platform. It has an AI model
marketplace whose listed partners include Mistral, and it produces DSA statements of reasons and
transparency reports, where audit evidence has a buyer (per our research notes).

> Hi <NAME / Checkstep partnerships team>,
>
> Your platform files DSA statements of reasons and transparency reports. I have built an
> open-source prover (<REPO_URL>) that could back such a statement with a cryptographic receipt.
> The receipt shows that a named classifier gave a specific verdict on a specific item, without
> revealing the item to whoever checks it.
>
> It runs today with Mistral's open Shieldstral-1.0-3B. A real post went through our demo app under
> three policies, and the receipts are anchored on a public testnet. Measured once on a laptop:
> about 456 s and an 848 MB receipt per category. The proof is slow, so it suits labels computed
> once per item, not real-time filtering. It is a research prototype and not audited.
>
> **My ask:** a 30-minute call to test whether a proved verdict, attached to a statement of reasons
> or to a transparency-report count, would help your customers' audits. If so, a pilot could run on
> public test content.
>
> <SIGNATURE>

---

## Not contacted, and why

- **Attestable.** Its technology is closed source (D51: "As far as I'm aware attestable does not
  open source their technology"), and it is a direct, funded competitor ($20M seed, August 2026, per
  our research notes). Under D48 and D51, contributions and partnerships go to open projects only.
  Attestable is a point of comparison: its numbers are vendor claims (53–77 tokens/s on a 31B model
  on one H100, 4–8 MB proofs, no paper), not techniques to copy or a place to give the technology.
- **Deferred to a later batch, not excluded:** ROOST (an open-source safety tool plugin), k-ID (age
  assurance plus proved labels), and a self-run Bluesky labeler. All three are in
  `results/zk60_funding_20261028/wave2/CUSTOMERS_PARTNERS_NICHE.md` §8.
- **A conflict note on Lagrange:** its Chief Scientist (C. Papamanthou, Yale) was listed in our
  research as a possible academic partner, flagged as a competitor or acquirer conflict. The
  Lagrange email above goes to the company, and no separate academic email to him is drafted.

---

### Sources

- Measured numbers: `docs/zkmatrix-poc/MVP_STATUS.md` (2026-10-30 01:54 and 05:30 UTC entries);
  `results/zk60_astra_20261026/real_app_demo_1/{violence,hate}.json` (prove 456.3 / 457.0 s).
- What a receipt reveals and hides: `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_CLASSIFIER_SHIELDSTRAL_T128_DRAFT_v3.md` §0
  (a draft, not accepted).
- Testnet anchor: `MVP_STATUS.md` 05:30 UTC entry; `ZK60_DECISIONS.md` D39, D45(3).
- Open-source direction and upstream targets: `docs/zkmatrix-poc/ZK60_DECISIONS.md` D48, D51; partner
  search on hold: D47.
- DeepProve (ePrint 2026/1112, co-authors), EZKL (Trail of Bits audit, no public round), Attestable
  (seed, claims): `results/zk60_funding_20261028/INVESTORS_PUBLICATION.md` §2b, §2d.
- Daniel Kang, Armilla, Checkstep, Papamanthou: `results/zk60_funding_20261028/wave2/CUSTOMERS_PARTNERS_NICHE.md`
  §1, §2, §3, §6, §8.
- Mechanism names (Ligero-class commitment, masked sumchecks): `/home/victor/ir-public/hashline/src/zk.rs`
  module doc.
- Venues: `INVESTORS_PUBLICATION.md` §2d.
