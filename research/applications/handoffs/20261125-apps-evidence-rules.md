# Rules that ask for evidence a receipt could supply (A11)

**Question.** For content moderation, synthetic-media marking and model audits: which published rules (by article or section, with dates of application) ask a provider for a record that a named check ran, who is entitled to see it, does a receipt add anything over a signed log, and what can a receipt not supply? No legal advice; texts quoted.

**Answer in one line.** In every text read, the party entitled to the evidence is either a regulator or auditor with a legal right to the data and systems (who can rerun an open model themselves) or the public through aggregate reports. No provision read asks for a per-item proof. A receipt adds something over a signed log only where a third party must check, without trusting the provider's key and without seeing the content, that a named pinned classifier produced a stated verdict. The texts read name few such cases.

## What was read and how

5 web searches (standard) and 10 page fetches, within budget. Primary texts: EUR-Lex consolidated Regulation (EU) 2022/2065 (read in three slices), Delegated Regulation (EU) 2024/436 (first slice only), legislation.gov.uk section 77 of the Online Safety Act 2023, the Commission's AI Act service-desk FAQ. Secondary (law-firm or aggregator pages, flagged below): the AI Act articles 50 and 53 pages at artificialintelligenceact.eu, Goodwin and Troutman summaries. The fetch tool returned model-written summaries of each page, not raw text; quotations below are as that tool returned them and should be checked against the Official Journal before anyone relies on wording. Nothing was run.

## Findings

Labels: [text] = quoted from the cited page as returned; [secondary] = a law-firm or aggregator page.

**Content moderation (EU Digital Services Act, Regulation 2022/2065).** [EUR-Lex](https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32022R2065)
- Art. 15(1)(c) and (e) [text]: a published report with "meaningful and comprehensible information about the content moderation engaged in at the providers' own initiative", including "any use made of automated means", with a qualitative description and an account of error rates. Entitled: the public.
- Art. 17(1) and (3)(c) [text]: a "clear and specific statement of reasons" to the affected recipient, with "where applicable, information on the use made of automated means in taking the decision". Entitled: the affected user.
- Art. 24(5) [text, as summarised]: providers submit decisions and statements of reasons to the Commission for a public, machine-readable database, "without undue delay", with no personal data.
- Art. 40(1) and (4) [text]: access to data for the Digital Services Coordinator or the Commission on reasoned request (very large providers), and for vetted researchers on the coordinator's request.
- Art. 37(1) [text]: annual independent audit of very large platforms and search engines, at their own expense. Art. 42(4) [text]: the report goes to the coordinator and the Commission and is public within three months of receipt.

**Audits (Delegated Regulation 2024/436).** [EUR-Lex](https://eur-lex.europa.eu/eli/reg_del/2024/436/oj/eng), first 100,000 characters only.
- Art. 5(2) [text]: the provider grants the auditor "access to all data necessary", extending to IT systems, testing environments and personnel.
- Art. 10(5)(c) [text]: minimum procedures include "the performance of tests, including with respect to algorithmic systems"; Art. 2(17) defines a test as "measurements, experiments or other checks".
- Art. 11 [text]: evidence must be relevant, sufficient and reliable. Art. 12(1): sample size and method chosen without provider interference.
- Recital 30 [text, as quoted by the fetch]: tests should let the auditor "independently reproduce and assess results of accuracy indicators". The fetch found no explicit duty to keep logs for the auditor.

**Synthetic-media marking (EU AI Act).** [artificialintelligenceact.eu Art. 50](https://artificialintelligenceact.eu/article/50/) [secondary]; [Goodwin](https://www.goodwinlaw.com/en/insights/publications/2026/08/alerts-technology-dpc-eu-ai-act-transparency-obligations-now-in-force) [secondary]
- Art. 50(2): providers must mark outputs "in a machine-readable format and detectable as artificially generated or manipulated". Art. 50(4): deployers disclose deep fakes, and public-interest text unless human-reviewed under editorial responsibility. Art. 50(5): information to "the natural persons concerned".
- Date: applies from 2 August 2026; Regulation (EU) 2026/1744 (in force 27 July 2026) gives generative systems already on the market until 2 December 2026 for the marking duty [Goodwin, secondary; also reported by several other law-firm pages in the search]. Not verified in the Official Journal.

**General-purpose models (AI Act).** [artificialintelligenceact.eu Art. 53](https://artificialintelligenceact.eu/article/53/) [secondary]; [Commission FAQ](https://ai-act-service-desk.ec.europa.eu/en/ai-act/faq/commissions-enforcement-powers-related-ai-act-obligations-providers-most-advanced-models) [text]
- Art. 53(1)(a): technical documentation "including ... the results of its evaluation", provided "upon request, to the AI Office" and national authorities. Art. 53(1)(b): information to downstream providers.
- The Commission's powers, including "requesting access to a model for evaluations", apply from 2 August 2026; obligations have applied since 2 August 2025 [FAQ]. Art. 55 duties (evaluation, adversarial testing) are described only by secondary pages in the search; I did not read the article.

**California AI Transparency Act (SB 942 as amended by AB 853).** [Troutman summary](https://www.troutmanprivacy.com/2025/10/california-ai-transparency-act-amendments-signed-into-law/) [secondary]
- Covered generative providers (over one million monthly users): free public detection tool, latent disclosure, optional visible label; operative 2 August 2026; substantive duties apply to image, video and audio only.
- Large platforms (over two million monthly users): detect provenance data in distributed content and show it to users; 1 January 2027. Capture-device makers: latent disclosures by default; 1 January 2028. Enforcement and penalties not found.

**UK Online Safety Act 2023, section 77.** [legislation.gov.uk](https://www.legislation.gov.uk/ukpga/2023/50/section/77) [text]: Ofcom gives each provider of a relevant service a notice; the provider produces a report with the information "specified or described in the notice", submits it to Ofcom and publishes it as the notice says. Entitled: Ofcom and the public. Record-keeping (section 34) and proactive-technology provisions were not read.

## Does a receipt add over a signed log, and what it cannot supply

DERIVED from the texts above and from `ZK60_PRIVACY_REQUIREMENTS.md` (inputs hidden from the verifier; the prover sees the content).

1. **Auditors and regulators (Delegated Reg. Art. 5(2), 10(5)(c); DSA Art. 40(1); AI Act Art. 53(1)(a)).** They are entitled to data and systems, and the classifiers in scope have public weights, so they can rerun the model on the logged input. A receipt would save them a rerun only at volume; it hides nothing from them they are not entitled to see. Adds little.
2. **Public aggregate reports (DSA Art. 15; OSA s.77).** The numbers are aggregates; error rates need human-labelled ground truth, which a receipt does not provide. Adds nothing.
3. **Affected user (Art. 17) and Commission database (Art. 24(5)).** A signed statement is the provider's assertion. A receipt would let the recipient, a complaint body or the Commission check that the stated automated verdict is the output of a named pinned model on a committed input, without the database carrying the content. This is the one case read where the no-content, no-trust-in-provider property is used. It is a hypothesis about a use, not something any article asks for.
4. **Marking (Art. 50(2); California latent disclosure).** The duty is to mark generated output so anyone can detect it. A receipt of a classifier run is not a mark and does not make output detectable. Adds nothing.
5. **Platform provenance detection (California, 2027).** Checking embedded provenance data is signature verification, not a neural classifier run; the installed relation does not apply.

**A receipt cannot supply, in any row:** that the check covered every item (completeness); that the input committed is the item actually published; that the model or policy is adequate; that a verdict is correct (it is a statistical screen); that content stayed private from the party that ran the prover; retention; human review. A signed log cannot supply computational integrity of the classification step either, so (3) is where the two differ.

## What a product would have to build

A statement-of-reasons record format with a field referencing a receipt (model hash, policy id, input commitment, verdict bit, verifier result); a registered public policy list per provider; for category-level statements, the multi-token label relation noted in A10; and a verifier a complaint body can run.

## A test that would confirm or kill the finding

Take ten items from the installed classifier's calibration set. Produce for each (a) a signed statement of reasons and (b) the same statement with its receipt reference. Give each pair to a reviewer who is told the input is not available. **Confirmed** if the reviewer can check "this pinned model gave this verdict on a committed input" only from (b) and the check runs with the installed verifier unchanged. **Killed** if the reviewer's actual need (what was removed and why) is met by (a), or if the item must be shown to the reviewer anyway (so the hidden input property is unused).

## What was not verified

Raw Official Journal text for every provision (the fetch tool summarises pages); Regulation 2026/1744's wording and the 2 December 2026 date beyond one law-firm page; Art. 42(1) reporting frequency; Art. 55 text; the AI Act code of practice on marking (status not found); California statute sections, enforcement and penalties; Ofcom codes and section 34; US and other jurisdictions; Delegated Reg. 2024/436 beyond its first 100,000 characters; the DSA's own date of application (not retrieved this tick). The search tool is US-only.
