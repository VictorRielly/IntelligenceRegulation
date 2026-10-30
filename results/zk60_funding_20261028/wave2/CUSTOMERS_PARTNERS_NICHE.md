# Strategic customers, partners and niche grants (researched 2026-10-28)

Scope: paying pilots, partner programs, sponsored research and niche grants
for the private-LLM-inference ZK prover (hidden input/output/activations,
public weights; 8B next token proved in 192 s on a laptop; no external audit
yet) and its MVP (media app with proved safety-classifier labels).
Already-covered avenues (accelerators, VCs, compute credits, NSF SBIR, DARPA,
DoD SBIR, NIST CAISI, DHS SVIP, AI-safety philanthropy, crypto grants, Safe
Online, Thorn/IWF/C2PA grants) are not repeated.

Status: COMPLETE (research only; nothing was applied for, registered,
emailed or sent).

Labels: "Verified" = read on the organisation's own page on 2026-10-28.
"Partial" = the page loaded but the relevant part did not.
"UNVERIFIED" = no official page confirmed it (several sites refused the
fetcher, and the session's shared web-search budget ran out partway
through, so some rows rest on earlier search excerpts only).

## 1. Plain summary

- **Nobody in this field runs a paid pilot program or an open grant for
  verification tech.** Money will come from business development with a
  working demo. The routes are partner contact forms.
- **Best paying-pilot targets:**
  - **Armilla AI.** Its partner program exists to feed third-party
    evaluation signals into AI insurance underwriting.
  - **Checkstep.** It has an AI-model marketplace and produces DSA
    statements and transparency reports.
  - **k-ID.** Its "age-adaptive" apps need proved content labels as the
    other half of age-appropriate distribution.
- **Free integration available now:** a self-run **Bluesky labeler**.
  - AT Protocol labels are already signed, and each user can follow up to
    20 labelers.
  - Proofs must be published beside the label, because the label format
    has no extra field.
  - This is the demo every buyer will ask for.
- **Niche grant found:**
  - **OJJDP "Strengthening ICAC Technological Investigative Capacity"**
    admits small for-profits, up to $675k. It closes on Grants.gov
    **tomorrow (29 Oct 2026)**, so plan for the FY2027 call; it needs SAM.gov.
  - NLnet (3 Nov) excludes AI projects and expects a European dimension.
- **University partner:** **Daniel Kang (UIUC)** works on "trustless
  audits without revealing data or models", the same thesis. He is the
  natural STTR, SaTC and I-Corps partner, and I-Corps requires a
  university link anyway.
- **Contract cash:**
  - Veridise is hiring a remote "Formal Methods Researcher for ZK".
  - Code4rena is winding down.

## 2. AI insurance and AI assurance buyers

None of these pays outside vendors for "verification tech" as a grant. Two
run partner programs whose stated purpose is feeding third-party
evaluation evidence into underwriting, which is exactly where a proof of
"this classifier ran on this hidden content and said X" would sit.

| Organisation | Program / route (official page) | What it says | Fit and offer | Status |
|---|---|---|---|---|
| Armilla AI (Lloyd's coverholder, AI-only MGA) | Armilla Partner Program, https://www.armilla.ai/partnerships ; "Become a Partner" goes to /contact-us | Four partner types: technology (LLM evaluation, observability, MLOps, AI security, GRC), service (auditors, certification bodies), data, infrastructure. "We integrate your risk signals directly into our underwriting process." Partner outputs (conformity assessment, monitoring, evaluations, audits) are the "ground truth" for coverage. No fees or payments to partners mentioned. Launched 2025-10-08 with Trustible as first partner (Armilla blog). | Best insurance fit. Offer: a "technology partner" risk signal = signed, proved classifier verdicts on hidden user content (e.g., proof that a deployed safety filter actually ran on every post). Revenue comes indirectly (Armilla's clients buy the tool), not from Armilla. | Verified |
| AIUC (Artificial Intelligence Underwriting Company), AIUC-1 standard | https://www.aiuc-1.com/ ; contributor community https://www.aiuc-1.com/research/contributor-community (form aiuc.typeform.com/contributors) | AIUC-1 = certification standard for AI agents; six domains incl. Data and Privacy. Quarterly releases (Jan 15, Apr 15, Jul 14, Oct 15 2026). AIUC runs the evals itself (1,000-5,000 scenarios); accredited auditors Schellman and Coalfire. Community is for agent builders, AI buyers and security professionals: peer-review standard updates, suggest requirements; quarterly calls. No evaluation-vendor program; no mention of cryptographic verification. | Medium. Free to join; a route to propose a requirement such as "evidence that a privacy-preserving evaluation ran, without exposing customer data". Not a payer. | Verified |
| Munich Re aiSure (Insure AI) | https://www.munichre.com/en/solutions/for-industry-clients/insure-ai.html | Performance warranties for AI vendors and cover for AI deployers (hallucination, bias, privacy leakage, harmful content). Partner case studies (Mosaic, Sustaind, MKIII, iTOO, Instnt...). Named contacts incl. a Palo Alto business-development manager for Insure AI. No startup/partner program; no assessment methodology published. | Low-medium. Not a buyer of tools; possible later as insurer of a proved-moderation product ("performance guarantee on proved classifier"). | Verified |
| Lloyd's Lab accelerator | https://www.lloyds.com/news-and-insights/lloyds-lab/insurtech/lloyds-lab-programme | Cohort 17: apps 10 Jun-20 Jul 2026, Pitch Day 10 Sep, start 28 Sep, Demo Day 9 Dec 2026. Two cohorts a year (FAQ); not exclusively for insurance ventures. Equity/fees/funding not stated. Cohort 18 dates not published as of 2026-10-28. Armilla and Testudo are Lab alumni. | Medium (as a partner channel to Lloyd's AI syndicates). Watch for the Cohort 18 call (pattern suggests ~Dec 2026-Jan 2027 open). | Verified (Cohort 17); Cohort 18 UNVERIFIED |
| Testudo (Lloyd's coverholder, GenAI liability) | Trade press only (fintech.global 2026-03-09, The Insurer 2026-01-15) | Standalone GenAI liability, US enterprises, Apollo/Atrium/QBE capacity (~$9.25M per insured). | Same "risk signal" pitch as Armilla; no partner page found. | UNVERIFIED (no official page read) |
| Credo AI (AI governance) | https://www.credo.ai/partnerships ; "Become a Partner" credo.ai/partnership/becomeapartner | Partner categories: hyperscalers, GSIs, management consulting, federal/public sector, boutique, distributors. No evaluation/verification-tech category; no revenue share stated on the page. | Low-medium (integration later, "proved evaluation" evidence inside Credo's governance records). | Verified |
| Holistic AI | No partner page found (search only: NVIDIA Inception, Microsoft Pegasus) | -- | Low. | UNVERIFIED |
| ORCAA (Cathy O'Neil) | No partner page found | Algorithmic audit consultancy. | Low; possible co-author/validator of an "audit without seeing data" method. | UNVERIFIED |
| Big-four AI assurance (Deloitte, PwC, EY, KPMG) | Not researched to an official page (search budget exhausted) | -- | Their alliance programs are for large vendors; realistic only after an external audit and a company. | UNVERIFIED |

## 3. Trust and safety vendors, platforms, age assurance

No T&S vendor publishes a paid pilot or technology-partner program for
outside verification tech. Every route is a "Become a partner / Talk to us"
contact form, so these are business-development targets, not applications.
The one place where proved labels can plug in today, with no permission
needed, is the Bluesky / AT Protocol labeler system.

| Target | Official page | What it says (2026-10-28) | Fit and offer | Status |
|---|---|---|---|---|
| Bluesky / AT Protocol labelers | Spec https://atproto.com/specs/label ; guide https://atproto.com/guides/creating-a-labeler ; app source `src/lib/constants.ts` in github.com/bluesky-social/social-app | Anyone can run a labeler: a separate account publishes an `app.bsky.labeler.service/self` record with its label values (Ozone is the reference server: web UI, backend, Postgres). Labels "are signed using public-key Cryptography" with the `#atproto_label` key; fields `src, uri, cid, val (<=128 bytes), neg, cts, exp, sig`. No field for extra data, and signing covers only the listed fields. Labels are served by `subscribeLabels` / `queryLabels`. The Bluesky app's `MAX_LABELERS = 20` per user. | **Highest-leverage free integration.** Run a "proved-label" labeler: each label pins a post by `cid`, and the proof is published separately, keyed by (uri, cid, val), on the labeler's own endpoint or Base. Users or apps subscribe. It is a live public demo of "labels you can check without seeing the content". No money, but it is the best demo for every buyer below. | Verified |
| ROOST (Robust Open Online Safety Tools) | https://roost.tools/ , /partnerships , /contact | 501(c)(3) building open-source safety tools: Osprey (rules engine; used by Bluesky, Discord, Matrix), Coop (review console), ROOST Model Community (open safety models). Partners include Google, OpenAI, Discord, Roblox, Microsoft, Mozilla, Bluesky, Hugging Face, Cinder, Match Group, Zoom. No grants, fellowships or vendor calls listed. | High for reach: an open-source "proved verdict" plugin for Osprey/Coop puts the work in front of every founding platform at once. Offer a contributed module. Not a payer. | Verified |
| Checkstep | https://www.checkstep.com/ , /about/partnerships | Moderation and DSA/OSA compliance platform with an "AI marketplace" to test and swap models; it files DSA statements of reasons and transparency reports. Partner categories: AI partners (OpenAI, Cohere, Mistral, Anthropic, Sightengine, Unitary...), technology, BPOs, bodies (NCMEC, C3P). "Become a partner" goes to the contact form. | **Good integration fit.** A proved classifier as a marketplace model, plus "proved transparency-report entries" for DSA audits. | Verified |
| Tremau (Nima platform) | https://tremau.com/ | Moderation platform plus advisory for DSA/OSA compliance. Contact topic "Event / Research / Media / Collaboration". No partner program. | Medium: DSA audit evidence. Pitch through the collaboration contact. | Verified |
| Cinder, Hive, ActiveFence (now "Alice"), Thorn Safer | cinder.co and safer.io fetch failed; Hive and ActiveFence: search results only | Hive integrates Thorn Safer and IWF hashes (press releases). ActiveFence rebranded to Alice. No partner programs found. | Medium-low: licensing ("wrap your classifier in a proof") once there is an audit. | UNVERIFIED |
| Tech Coalition | https://www.technologycoalition.org/membership/criteria | Members must be technology companies with "at least one product or service that could reasonably be affected by child sexual exploitation". Excluded: "vendor companies whose main business is providing content moderation tooling" that do not host content. Funded by members; programs Lantern, Pathways, Research, Elevate. | The **media app itself** (it hosts content) could later qualify as a member; a pure prover vendor could not. | Verified |
| Google Jigsaw Perspective API | https://perspectiveapi.com/ | Being sunset: "The service will remain active until December 31, 2026"; no new requests since Feb 2026; no migration support. | A niche opening: its users need a replacement toxicity scorer. A proved open classifier is a talking point, not a business. | Verified |
| Microsoft PhotoDNA / DCU, Meta, Discord, Roblox, Reddit | Not fetched (search budget exhausted) | -- | Reach these through ROOST and the Tech Coalition rather than cold contact. | UNVERIFIED |
| k-ID (OpenAge / AgeKey) | https://www.k-id.com/ ; developer portal portal.k-id.com | Products: AgeKit/AgeKit+, AgeKey (reusable age credentials), compliance logic for 200+ markets; customers Discord, Snapchat. OpenAge initiative (launched Nov 2025, per search results) is open to "any platform or certified verification provider". No partner program on the site. | **Best age-assurance fit.** Pair "proved content label (explicit = yes/no)" with "AgeKey says minor", and the app decides distribution with neither side revealing data. Pitch as a complement to AgeKey, not a competitor. | Verified (site); OpenAge membership terms UNVERIFIED |
| Yoti | https://www.yoti.com/ (partnerships page yoti.com/partnerships not readable) | Age estimation, digital ID (27M installs), "Trust and Safety" moderation, more than 70 SaaS integrations, developer hub. | Medium: integration partner. | Partial |
| Privately (CH) | https://www.privately.eu/ | On-device age assurance ("No pictures or biometric data are ever sent to a server"); ISO/IEC 27566-1; embedded in-device technology page. | Medium: on-device classifier plus proof is a natural joint story. | Verified |
| VerifyMy | https://verifymy.io/ | Age assurance plus content moderation (pre-recorded, livestream) and consent checks for UGC platforms; Partners page linked. | Medium: proved moderation for adult-content platforms facing Ofcom audits. | Verified |
| Fediverse: Sovereign Tech Agency, IFTAS, Nivenly | https://www.sovereign.tech/ ; https://about.iftas.org/ | STA invests "globally" in open-source infrastructure; its Resilience program is open (28 Sep 2026 news item) but covers bug bounties and hardening of existing infrastructure. IFTAS runs denylists and the SW-ISAC; no grant calls. Nivenly not checked. | Low: the project is not existing open infrastructure. | Verified (STA, IFTAS); Nivenly UNVERIFIED |
| AT Protocol funds (Skyseed, AT Protocol Community Fund) | Search results only; atprotocol.dev page 404 | Skyseed (Peter Wang, Dec 2024): $5k-$25k developer grants, contact @skyseed.fund on Bluesky; focus includes data privacy and "user-centric design for parents". The Community Fund is fiscally hosted by the Raft Foundation. No 2026 call found. | Small grant possible for an open-source proved-label labeler. | UNVERIFIED |

## 4. Content provenance and journalism funds

| Target | Official page | What it says | Fit | Status |
|---|---|---|---|---|
| Content Authenticity Initiative (Adobe-led) | https://contentauthenticity.org/membership | "CAI membership is free and open to all", individuals or companies; quarterly member meetings, early materials, open-source tools. No fund or grant. | Join for free (credibility, ecosystem news); pitch "a C2PA assertion that carries a ZK proof of a classifier verdict" at a working session. | Verified |
| C2PA | https://c2pa.org/membership/ | Steering, General and Contributor members via Linux Foundation / JDF enrollment; fees not stated on the page. | Later, as a standards contributor (a proof-carrying assertion). | Verified (fees UNVERIFIED) |
| Truepic | https://www.truepic.com/ | Now leads with Truepic Vision (photo/video authentication for inspections); partners page linked; no partner program described. | Low-medium. | Verified |
| Digimarc | Not fetched | -- | Low. | UNVERIFIED |
| Lenfest Institute | https://www.lenfestinstitute.org/ | Grants to individuals and organisations in journalism; AI Collaborative and Fellowship Program expanded with OpenAI support; nothing for tech vendors. | Low (news organisations only). | Verified |
| Google News Initiative | https://newsinitiative.withgoogle.com/ | No open funding call listed on the home page. | Low. | Verified (no call) |
| Knight Foundation | Not fetched | ROOST founding funder (roost.tools). | Low directly; reach it through ROOST. | UNVERIFIED |

## 5. Child-safety and justice grants (US, UK, EU)

| Program | Official page | What it says | Fit | Status |
|---|---|---|---|---|
| **OJJDP FY2026 Strengthening ICAC Technological Investigative Capacity** (O-OJJDP-2026-172753) | https://ojjdp.ojp.gov/funding/opportunities/o-ojjdp-2026-172753 ; NOFO PDF ojp.gov/funding/docs/ojjdp-2026-172753.pdf | **For-profit organisations, including small businesses, are eligible**; no cost share. Cat. 1 "develop new, innovative, and widely used investigative tools ... that address CSAM", up to $675k (2 awards); Cat. 2 enhance existing tools, up to $650k (1); Cat. 3 training, up to $550k (1). 24-month cooperative agreements from 1 Jan 2027. Grants.gov deadline **29 Oct 2026 11:59 pm ET**, JustGrants 5 Nov; SAM.gov registration had to start by 29 Sep. | **Cannot be met this cycle** (no entity, no SAM UEI, one day left). This is a recurring line, so plan for the FY2027 NOFO (this one was posted 21 Sep). The fit is weak-to-medium: it funds tools for police investigators. A ZK angle would be "platforms prove a CSAM-classifier hit to an ICAC task force without moving the content". That needs a law-enforcement partner and a CSAM-legal data path. | Verified |
| OJJDP FY2026 ICACCOPS (O-OJJDP-2026-172740) | https://ojjdp.ojp.gov/funding/opportunities/o-ojjdp-2026-172740 | Maintenance and enhancement of the existing ICAC On-Line Child Protection System; Grants.gov 16 Nov, JustGrants 23 Nov 2026. | Not a fit (it funds an incumbent system). | Verified |
| OJJDP FY2026 ICAC Task Force Program Support (-172731) | https://ojjdp.ojp.gov/funding/current | Closes 9 Nov 2026. | Not a fit. | Verified (title and date only) |
| NIJ current solicitations | https://nij.ojp.gov/funding/current | Nine FY2026 solicitations close 23 Nov - 7 Dec 2026 (crime and justice research, human trafficking, school safety, drones, gangs, elder exploitation...). None names CSAM, online exploitation, deepfakes, AI or digital evidence. No FY2027 forecast on the page. | None now. Check NIJ around Q3 FY2027 for an "R&D in forensic science / digital evidence" call. | Verified |
| NCMEC | https://www.missingkids.org/ (corporate and program partner pages) | Partnerships are donor/program relationships; no technology-vendor program found. | Low (credibility once there is a product). | Verified (navigation only) |
| UK Ofcom / DSIT Safety Tech Challenge Fund successors; OSTIA | gov.uk, ofcom.org.uk and ostia.org.uk fetches failed | -- | Unknown. | UNVERIFIED |
| EU calls admitting US firms | Not verified (search budget exhausted). Related: NLnet https://www.nlnet.nl/propose ; https://nlnet.nl/restack/ | NLnet's next deadline is **3 Nov 2026 12:00 CET**, €5k-€50k, open licences required. EU-funded calls "require a strong European dimension". Restack **excludes AI-related projects** unless they already have over 1M active human users. | Likely ineligible (US applicant, AI project). Only a generic, non-AI hash-based proof library might argue fit. | Verified (NLnet); other EU calls UNVERIFIED |

## 6. University partners (STTR / SaTC co-PIs, sponsored research, I-Corps)

Each row was read on the PI's own page. Work marked "(not on page)" is
known from the literature but was not confirmed on that page.

| PI | Institution (own page) | Relevant work shown | Use |
|---|---|---|---|
| **Daniel Kang** | Asst. Prof. CS (courtesy ECE), UIUC (https://ddkang.github.io/ , /publications/) | ZKML (EuroSys 2024); **"Trustless Audits without Revealing Data or Models" (ICML 2024)**; ZK-IMG (attested images); "Scaling up Trustless DNN Inference with ZK Proofs"; Cove (verifiable AI governance, ICML 2026 TAIGR workshop). Funded by Google and Open Philanthropy; has consulted for and advised startups. | **First choice** for STTR research partner, SaTC co-PI and I-Corps technical lead. His audit thesis is the same as the product. |
| Yupeng Zhang | Asst. Prof. ECE, UIUC (siebelschool.illinois.edu profile) | ZK proofs and MPC "applied to blockchain and machine learning" (zkCNN not on page). | Second UIUC option; proof-system depth. |
| Benedikt Bünz | Asst. Prof. CS, NYU Courant; co-founder and Chief Scientist, Espresso (https://cs.nyu.edu/~bb/) | **ARC: folding/accumulation for hash-based proof systems**, ProtoStar, HyperPlonk, Bulletproofs. | Technical fit for amortising many token proofs; SaTC co-PI. |
| Justin Thaler | Assoc. Prof. CS, Georgetown, **on leave at a16z crypto research** (https://people.cs.georgetown.edu/jthaler/) | Sum-check provers, Lasso, Jolt, Brakedown, Hyrax; *Proofs, Arguments, and Zero-Knowledge*. | Reviewer/advisor on the sum-check core. On leave, so a Georgetown STTR role is unlikely now. |
| Charalampos Papamanthou | Prof. CS, Yale; co-director Yale Applied Cryptography Lab; **Chief Scientist, Lagrange Labs** (https://www.cs.yale.edu/homes/cpap/) | Verifying computations while keeping inputs private. | Strong, but Lagrange sells zkML (DeepProve), so treat as a possible competitor or acquirer conflict. |
| Ari Juels | Weill Prof., Cornell Tech; co-director IC3; Chief Scientist, Chainlink Labs (https://www.arijuels.com/) | "Blockchain technologies and AI security, as well as applied cryptography and privacy." | IC3 industry route; AI-security framing. |
| Dawn Song | Prof. CS, UC Berkeley; co-director Berkeley RDI (https://dawnsong.io/) | AI safety and security, decentralisation (ZK work not on page). | RDI events and sponsor network; less hands-on. |
| Michael Walfish | Prof. CS, NYU Courant (https://cs.nyu.edu/~mwalfish/) | Page says only "computer systems, security, and networks" (verifiable-computation work not on page). | Secondary. |
| Hongyang Zhang | Asst. Prof., U. Waterloo; Vector Institute; SafeAI Lab (https://hongyanz.github.io/) | **zkLLM (CCS 2024)** with Haochen Sun and Jason Li. | Closest published system. Canadian, so not an STTR research institution; use as a collaborator or benchmark. |
| Boneh (Stanford), Mishra (UPenn), Wahby (CMU), Miers (UMD), Fisch (Yale), Jiaheng Zhang (NUS) | Pages refused or failed to load | -- | UNVERIFIED |

- **NSF I-Corps (National Teams)**, https://www.nsf.gov/funding/initiatives/i-corps/national-teams-applicants:
  - "Applicants must have a technology development connection to an institution of higher education."
  - You qualify with an NSF research award in the last 5 years, or by completing a regional I-Corps program and getting a recommendation letter.
  - Teams have 3-5 people: technical lead (usually faculty), entrepreneurial lead and an independent industry mentor.
  - Awards are up to $50k, from which a $10k participation fee is paid.
  - So Victor can enter only through a university partner (Kang is the natural technical lead) or a regional Hub program (Hub pages not checked).
- **STTR:** the research partner must be a US research institution, which rules out Waterloo and NUS. The work-split rules (from memory: at least 40% by the small business, 30% by the institution) are UNVERIFIED this pass. sbir.gov/about only points to the policy directive.
- **Sponsored research:** UIUC OTM links "Engage With Our Research Enterprise" (https://otm.illinois.edu/industry-partners/engage-our-research-enterprise). Terms were not read.

## 7. Contract and consulting revenue

| Source | Official page | What it says | Verdict |
|---|---|---|---|
| Veridise (ZK audits, Picus) | https://veridise.com/careers/ | Fully remote. Openings: **"Formal Methods Researcher for ZK"** and an open application. They audit ZK circuits and zkVM apps. | Best short-term ZK contract or part-time lead. Ask whether contract work is possible. |
| zkSecurity | https://www.zksecurity.xyz/ | Audits ZK/MPC/FHE/TEE/PQ; no careers listed; "Get in Touch" form. | Possible subcontracting (prover reviews). |
| Trail of Bits | https://www.trailofbits.com/careers/ | 6 roles, none ZK-specific; "All roles are remote-friendly." | Low. |
| Code4rena | https://code4rena.com/ | "**Code4rena is winding down**"; only finishing active contests. | Dead end. |
| Cantina / Spearbit | https://cantina.xyz/opportunities | 52 bounties and 1 competition; the visible bounties are DeFi (Uniswap $15.5M, Coinbase $5M...), none ZK. | Low. |
| Immunefi, zkSync Era | https://immunefi.com/bug-bounty/zksyncera/information/ | Max bounty $300k; KYC with government ID; prover/circuit scope not shown on this page. | Long shot, though the team's soundness-review habit transfers. |
| EZKL | https://ezkl.xyz/ | "The only audited library for verifiable AI"; hiring via Wellfound. | Competitor; it shows buyers want an *audited* zkML library. |
| Boundless prover market | https://docs.boundless.network/provers/quick-start | Needs a GPU with at least 8 GB VRAM, 32 GB RAM, 16 threads, Ubuntu 24.04 VM or bare metal, ZKC collateral; "at least 10 GPUs to run a competitive prover". | Not viable on the 15 GiB WSL box; any GPU use would go through the resource guard anyway. |
| Lagrange (DeepProve) | lagrange.dev returned 403 | -- | UNVERIFIED |

## 8. Ranked outreach / application list, next 3 months (Nov 2026 - Jan 2027)

**What Victor needs first (blocks most rows):**
- (a) The Delaware C-corp, EIN and a **SAM.gov UEI**, started right after incorporation. SAM takes weeks, and the OJJDP and STTR routes need it.
- (b) A 2-minute demo: post, then proved label, then a public verifier, then a minor account not seeing explicit content.
- (c) A one-page "proved moderation labels" sheet that states honestly what exists: about 95-98-bit soundness, **no external audit**, 192 s per 8B token, and the Shieldstral classifier timing actually measured.
- (d) A decision on open-source versus patent filing **before** publishing labeler or ROOST code (see `../patent/`).

| # | Who | Why they would pay or help | What to offer | Needs first | When |
|---|---|---|---|---|---|
| 1 | **Bluesky labeler (self-run)** | Free, permissionless; signed labels already exist; up to 20 labelers per user. It is the demo every buyer below will ask for. | A "proved-label" labeler for MVP-app posts (opt-in content only), with the proof keyed by (uri, cid, val) and published beside each label. | (b), (d) | Build Nov-Dec |
| 2 | **Armilla AI** partner program | Says outright that it pulls partner evaluation signals into underwriting. A proof is a stronger signal than a vendor report. | Technology-partner pilot: proved classifier verdicts for one Armilla insured. | (a), (b), (c) | Contact form in Nov |
| 3 | **Checkstep** | Has an AI-model marketplace and files DSA statements and transparency reports, where audit evidence has a buyer. | Proved classifier as a marketplace model; "proved transparency-report counts" pilot with one customer. | (b), (c) | Nov-Dec |
| 4 | **k-ID** (AgeKey / OpenAge) | Sells "age-adaptive" apps to Discord and Snapchat. Proved content labels are the missing half of age-appropriate distribution. | Joint demo: AgeKey says minor, the proved label says explicit, the post is withheld, and neither side sees the data. | (b) | Dec |
| 5 | **Daniel Kang, UIUC** | Same thesis ("trustless audits without revealing data or models"). | STTR Phase I partner, SaTC co-PI, I-Corps technical lead, or sponsored-research scoping. | (a) for STTR; one-pager | Email in Nov (Victor's call) |
| 6 | **ROOST** | One integration reaches Discord, Roblox, Google, OpenAI, Bluesky and Match Group. | An open-source Osprey/Coop "verify-proof" plugin. | (d) | Jan |
| 7 | **AIUC-1 contributor community** and **CAI membership** | Both free. They give credibility and a voice in the AIUC-1 quarterly updates (next one is Jan 15) and C2PA work. | Join; propose a "privacy-preserving evaluation evidence" requirement and a proof-carrying C2PA assertion. | none | This week |
| 8 | Tremau, VerifyMy, Privately, Yoti | DSA/OSA audit pressure; adult-content and age-assurance buyers. | Same pilot as #3; on-device classifier plus proof with Privately. | (b), (c) | Dec-Jan |
| 9 | Lloyd's Lab Cohort 18; Testudo; Munich Re aiSure | Channel to Lloyd's AI capacity and a later "warranty on a proved classifier". | Application when Cohort 18 opens (date UNVERIFIED); intro after the Armilla pilot. | (a), pilot data | Watch Dec-Jan |
| 10 | **OJJDP ICAC Technological Investigative Capacity, FY2027** | Admits small for-profits, up to $675k. The FY2026 call closes 29 Oct (Grants.gov), too soon. | "Prove a CSAM-classifier hit to a task force without moving the content", with an ICAC task force or university as subrecipient. | (a) plus SAM; a law-enforcement partner; legal review of CSAM handling | Prepare by Aug 2027 |
| 11 | Veridise / zkSecurity contract work | Short-term cash if grants slip. | Part-time ZK formal-methods or prover review. | none | Only if runway requires |
| 12 | Skyseed / AT Protocol Community Fund | A $5k-$25k grant for an open-source labeler (UNVERIFIED). | Message @skyseed.fund once #1 is live. | #1 | Jan |

Not worth pursuing now: NLnet (deadline 3 Nov; AI excluded and European
dimension required), NIJ (no relevant call open), ICACCOPS (incumbent
system), Code4rena (winding down), journalism funds (news organisations
only), Boundless proving (hardware mismatch).
