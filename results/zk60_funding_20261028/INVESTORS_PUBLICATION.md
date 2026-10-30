# Investors, accelerators, strategic routes and publication — research note

Date: 2026-10-28 (research only; nothing applied for, no contact made).
Scope: accelerators, ZKML/verifiable-AI investors and comparable rounds,
strategic/customer and compute-credit routes, academic venues. Government
grants and philanthropy/crypto-foundation grants are covered by other notes.

Status: complete draft, 2026-10-28. Dates are US Pacific unless marked AoE.

## 1. Plain summary

- **Fastest real money on this side: Y Combinator W27, deadline Monday
  Nov 2 2026, 8 pm PT** — $500k, decision by Dec 11, cash in early 2027. No
  company is needed to apply; YC helps incorporate after acceptance.
- **Second: Alliance ALL19 (Nov 18; $400k at a $4M post-money SAFE plus a
  token side letter; starts Jan 11 2027)**, with Techstars Spring 2027
  (Nov 18; $220k) as a weaker hedge. Every equity route needs a company
  (Delaware C-corp is the default) before money moves.
- **Market check:** a funded direct competitor exists. **Attestable** (ex-StarkWare
  founders) raised a **$20M seed (Altimeter + TLV Partners, Aug 2026)** and
  claims 53–77 proved tokens/s on a 31B model on one H100 (alpha, no paper,
  no input-privacy claim found). Victor's 8B stack is ~0.26 tokens/s on a
  laptop. Pitch the *privacy of inputs/outputs/activations*, measured
  soundness and reproducibility, not speed, and expect the comparison.
- **A paper does not bring money in time** for these windows (top-venue
  decisions are 3–5 months out). A *preprint* (IACR ePrint) is the cheap
  credibility lever for interviews and grant reviewers; submit for peer review
  (USENIX Security Jan 26 2027 or CCS 2027 cycle 1, ~mid-Jan) in parallel.
  If a patent is wanted, file a US provisional **before** any preprint.

## 2a. Accelerators

All checked 2026-10-28 on the program's own page unless marked. "Entity"
= what must exist to take the money. Victor has no company today, so every
equity route below needs one first (a Delaware C-corp is the default the
US programs expect; YC says it helps incorporate after acceptance, and no
program checked requires a company just to *apply*, except where noted).

| Program | Next deadline (PT) | Decision / start | Terms (verified) | Entity | Fit for this project |
|---|---|---|---|---|---|
| **Y Combinator W27** | **Nov 2 2026, 8 pm PT** (5 days out). Late apps still considered, no promised timing | Decision by **Dec 11 2026**; batch Jan–Mar 2027, in person in SF | $500k: $125k post-money SAFE for 7% + $375k uncapped MFN SAFE; not milestone-contingent; no fees | US, Canada, Cayman or Singapore corp; YC helps incorporate after acceptance | High: technical founder with a working, measured artifact (the W27 Request for Startups has AI-security and data-trust items but no ZK or AI-safety item). Being a solo founder (if so) and having no users yet are the weak spots. Fastest *large* equity cheque available |
| **Alliance ALL19** | **Nov 18 2026** ("Apply to ALL19 by November 18"); early deadline passed | Program starts **Jan 11 2027** in NYC | $400k at $4M post-money SAFE + 1:1 token side letter | Corp (SAFE); token side letter if a token ever launches | Medium-high: crypto-native, says it backs "crypto, AI ..."; Base anchoring is a crypto hook; $4M post is a low valuation (10% dilution) |
| **Techstars Spring 2027** (e.g. NYC; AI Health Baltimore is the only AI-named track) | **Nov 18 2026** final (opened Aug 24) | Start **Mar 8 2027**; Demo Day Jun 3 2027 | $220k = $200k uncapped MFN SAFE + $20k for 5% common (NYC page) | Corp | Medium-low: generic; no security/AI-infra/web3 track listed |
| **PearX W27** | Regular deadline **closed Oct 4**; "applications received after that date will be reviewed on a rolling basis" | Jan 2027 start (UNVERIFIED for W27) | Not on the page; S26 reported as $500k for 10% (third-party, UNVERIFIED) | Corp | Medium: rolling-late is a real but weak door |
| **South Park Commons Founder Fellowship** | F26 deadline was Aug 2 2026 (passed); next cycle UNVERIFIED | — | $400k for 7% (standard SAFE) + $600k guaranteed in next round; solo founders accepted | Corp | Medium-high fit, but no open window found |
| **AI Grant** | "Applications for Batch 4 are closed"; no next date | — | $250k uncapped MFN SAFE (no cap, no discount) + $350k Azure + ~$250k other credits | **Delaware corp only** | Medium: AI-product focused; watch for Batch 5 |
| **Neo Residency** | Not found (TechCrunch Feb 19 2026: summer cohort of 12–15) | — | $750k uncapped SAFE (TechCrunch); floor/valuation details conflict across sources | Corp | Medium; next window UNVERIFIED |
| **Entrepreneur First** | No deadlines on site; rolling via apply.joinef.com | — | Equity-free stipend while ideating; "up to $250K investment once you form a company" | Becomes required during program | Low-medium: built for pre-team/pre-idea; useful only if a cofounder is wanted |
| **a16z CSX** (a16z Crypto renamed **a16z Frontier** on Oct 22 2026) | No open cohort on the CSX page | — | Last published: $500k for 7% (Fall 2024, third-party summary, UNVERIFIED now) | Corp | High thesis fit (crypto + AI), but no window; go to the fund directly (see 2b) |
| **Base Batches** (Base Ecosystem Fund) | 004 closed Sep 9 2026; "cohorts run twice a year"; next date not posted (likely early 2027, UNVERIFIED) | 8 weeks virtual; demo day | "$100,000 investment from the Base Ecosystem Fund" (subject to diligence); Base must be default chain; no prior seed round | Corp | Medium: posts anchored on Base qualify, but tracks are finance/agents |
| **Outlier Ventures Post Web Base Camp** | "Accepting early applications for 2026 cohort"; no deadline | 12 weeks, remote | "Agreed equity stake and future token supply", no figures | Corp + token terms | Low: DeAI/DePIN token focus; terms opaque |
| **Seldon Lab** (AI-security accelerator, SF) | Batch 2 demo day was Apr 20 2026; apply page live, no dates | — | Third-party: up to $500k per startup (UNVERIFIED) | Corp | High thesis fit (AI security/governance tooling); small; check RFS |
| ZK-specific accelerators | None open found (Outlier ZK Base Camp 2023 is closed; Starknet/Midnight programs are chain-ecosystem builder programs) | — | — | — | Not a route right now |

## 2b. Investors and comparable rounds

Only rounds confirmed by a company post, press release or established
trade press (The Block, CoinDesk, Fortune, TechCrunch, Calcalist) are listed.

| Company (what it proves) | Round, date | Leads (others) | Source | Lesson for Victor |
|---|---|---|---|---|
| **Attestable** (ZK proofs of AI inference; founders ex-StarkWare/RAND; founded 2025, 15 staff) | **$20M seed, announced Aug 11 2026** | **Altimeter + TLV Partners** (Halcyon Futures, Cerca, Netz; angels incl. Assaf Rappaport) | Calcalist 2026-08-11; KuCoin/ChainCatcher 2026-08-12; noze.it analysis 2026-08-12 | **The direct, funded competitor.** Claims 53 tok/s (one 16K sequence) to 77 tok/s (4x4K batch) on Gemma 4 31B on one H100, "alpha", proof system undisclosed, no paper, no input-privacy statement found. Investors will compare Victor's 0.26 tok/s (8B, 128 tokens, 487 s, laptop) with it. The pitch has to be *hidden inputs/outputs/activations + measured soundness + transparent hash/lattice setup + reproducible artefact*, not raw speed |
| Modulus Labs (zkML) | $6.3M seed, Nov 1 2023 | Variant + 1kx | The Block, CoinDesk | Joined Tools for Humanity (World), Dec 2024: an acqui-hire exit for a zkML team |
| Lagrange Labs (DeepProve zkML) | $13.2M seed, May 8 2024; total $21.5M per company (Nov 2025) | Founders Fund (1kx, Archetype, Maven11 ...) | SiliconANGLE/CoinDesk; Business Wire (company) | Sells verifiable AI to defence (Raytheon/Lockheed supplier networks) and Oracle; papers on ePrint (DeepProve, CCS 2026) |
| Inference Labs (Proof of Inference, Bittensor SN2) | $6.3M total, Jun 26 2025 ($2.3M pre-seed 2024) | DACM, Delphi Ventures (Arche, Lvna; $1M Echo community round) | The Block / Decrypt press release | Token-network route |
| Succinct (SP1 zkVM) | $55M seed + Series A, Mar 21 2024 | Paradigm | Succinct blog, The Block | General ZK infra; very large |
| RISC Zero (zkVM, used in this repo's zkVM route) | $40M Series A, Jul 19 2023 | Blockchain Capital (Bain Capital Crypto ...) | RISC Zero blog, The Block | — |
| Nexus (zkVM) | $25M Series A, Jun 2024 | Lightspeed + Pantera (Dragonfly) | Nexus blog, Fortune | Lightspeed does write ZK cheques |
| Brevis (ZK coprocessor) | $7.5M seed (token round), Nov 11 2024 | Polychain + Binance Labs/YZi | The Block | Token-structured |
| Polyhedra (Expander, zkPyTorch) | $20M strategic at $1B, Mar 2024 | (Polychain, Binance Labs, Animoca) | trade press, UNVERIFIED totals | — |
| Mira (AI-output verification by consensus, not ZK) | $9M seed, Jul 16 2024 | BITKRAFT + Framework | PR Newswire | Framework backs "verifiable AI" even without ZK |
| EZKL / Zkonduit | No public round found (Trail of Bits audit Mar 2025) | — | — | UNVERIFIED |

Funds with a verified public record in verifiable AI / ZK: **a16z Frontier**
(a16z Crypto renamed Oct 22 2026; mandate widened to AI and "networks
connecting people and intelligent agents"; Chris Dixon, Eddy Lazzarin, Guy
Wuollet; ~$2.2B fund), **Paradigm**, **Polychain**, **1kx**, **Variant**,
**Founders Fund**, **Lightspeed**, **Pantera**, **Framework**, **Blockchain
Capital**, **Bain Capital Crypto**, **Delphi Ventures**; AI-safety funds
**Juniper Ventures** (AI assurance; Fund II, DNV committed $2.5M, May 20 2026)
and **Halcyon Futures/Ventures** (AI-safety incubator + venture arm; in
Attestable's round); **Altimeter** and **TLV Partners** (Attestable). Note
the Altimeter and TLV theses are AI-security, not crypto: verifiable AI is
now fundable outside crypto funds.

## 2c. Strategic / customer / compute-credit routes

Credits cut cost fast but are not cash; all require an incorporated company.

| Program / route | What it gives (verified) | Eligibility / catch | Speed |
|---|---|---|---|
| **NVIDIA Inception** | Free, no equity; partner cloud credits, preferred GPU pricing (rebate via supplier), "Inception Capital Connect" VC exposure | Incorporated, working website, <10 years old, NVIDIA use case. **"crypto-related companies" are excluded** — apply as an AI-safety/verifiable-AI company, not a crypto app | Rolling, no deadlines; review time not stated |
| AWS Activate | Founders: $1k, up to $5k (self-funded). Portfolio: up to $200k with an Org ID from an accelerator/VC | Pre-Series B, <10 yrs, paid-tier account | Founders tier: days; Portfolio after YC/Techstars/Alliance |
| Google for Startups Cloud | Scale tier up to $200k over 2 yrs; AI tier up to $350k | Google: "VC funding", pre-seed to Series A; AI-first on Vertex/Gemini | After a priced/SAFE round |
| Microsoft for Startups | "up to $150,000 in credits" (Azure) | Page states no criteria | Rolling |
| AI Grant bundle | $350k Azure + ~$250k partner credits (with the $250k SAFE) | Batch 4 closed | — |
| Lambda / other GPU clouds | not verified | — | UNVERIFIED |
| **Base Ecosystem Fund** | $100k investment via Base Batches (subject to diligence) | Base default chain, pre-seed | Next cohort date not posted |
| **Design-partner pilots** with trust-and-safety vendors or platforms | Paid pilots or LOIs (no program; direct sales) | Need a working demo, a one-page security statement and a price | 1–3 months to a paid pilot at best; LOIs in weeks |
| Defence / government AI assurance (Lagrange's model) | Supplier registration, not cash | Slow; overlaps the grants note | Months |

Regulatory pull (why platforms might pay; verified):
- **UK Online Safety Act**: "highly effective age assurance" duty in force since
  July 2025; Ofcom fines to date include £1M (AVS Group, Dec 3 2025) and £1.35M
  (Feb 2026); its guidance accepts yes/no age checks that share no date of birth.
- **EU DSA Art. 28 guidelines** (Jul 14 2025) and the Commission's
  open-source age-verification blueprint; its developer portal now names
  zero-knowledge proofs the preferred presentation method (Jul 2026 update;
  portal is the only source). Regulators are already accepting ZK for
  child-safety compliance — but for *age*, not for *classifier verdicts*.
  Victor's product (proof that a post passed a safety classifier without
  revealing it) is a new category; no regulator yet asks for it. Treat
  "moderation audit for regulators/auditors" as a hypothesis to test with
  design partners, not as demand.
- Mistral (owner of Shieldstral) is a possible co-marketing partner;
  no program found (UNVERIFIED).

## 2d. Publication venues

| Venue | Next deadline (AoE unless noted) | Decision | Fit | Note |
|---|---|---|---|---|
| **IACR ePrint** (+ arXiv cs.CR mirror) | Any day | Moderation only, "did not undergo any refereeing"; typically days (UNVERIFIED) | High | Fastest public, citable credibility; **is prior art** |
| **IEEE S&P 2027**, cycle 2 | Abstract **Nov 10**, paper **Nov 17 2026** | Early reject Jan 18; accept **Mar 5 2027**; conf. May 17–20 2027 Montréal | High | 3 weeks away: only if the paper is nearly written. S&P 2028 cycle 1 likely ~June 2027 (2027 pattern: Jun 4/11; UNVERIFIED) |
| **USENIX Security '27**, cycle 2 | Registration **Jan 19**, paper **Jan 26 2027** | Notification May 6 2027 (preliminary CFP); conf. Aug 11–13 2027 Denver | High | Best realistic top-tier target; Open Science (artifact) appendix mandatory — the repo's receipts and byte-identity gates are an asset |
| **ACM CCS 2027** | "Coming Soon"; 2026 pattern was Jan 14 and Apr 29 → expect ~mid-Jan and ~late-Apr 2027 (UNVERIFIED) | 2026: Apr 9 / Jul 17; conf. Oct 11–15 2027 Atlanta | **Highest** | zkLLM (CCS 2024), DeepProve and zkAgent (both CCS 2026 revisions) went here: the natural home and the reviewers who know the baselines |
| **PoPETs 2027** (privacy) | Issue 3 **Nov 30 2026**; Issue 4 **Feb 28 2027** | Feb 1 2027 / May 1 2027 | High for the hidden-IO (P1) claim | Quarterly, fastest peer review; less prestige than the big four |
| NDSS 2027 | Summer (May 6) and fall (Aug 19 2026) cycles both passed | — | Medium-high | NDSS 2028 summer likely ~May 2027 (UNVERIFIED) |
| IACR CRYPTO 2027 | Not posted; 2026 deadline was Feb 12 → ~Feb 2027 (UNVERIFIED) | 2026: Apr 7 / May 4 | Medium | Only for a new cryptographic contribution (e.g. the blinding/ZK construction with proofs), not a systems paper |
| EUROCRYPT 2027 | Sep 17 2026 (aggregator) — passed | — | Medium | — |
| **IACR Communications in Cryptology** (journal) | Vol 3 Issue 4 closed Oct 26 2026; next round not posted (~late Jan 2027, UNVERIFIED) | Guaranteed decision by the round's notification (~2 months) | Medium-high | Scope includes "secure implementation and optimization"; good fallback |
| Journal of Cryptology | Rolling | Many months | Low for speed | — |
| ICML 2027 | Projected Jan 22 2027 (not official; UNVERIFIED) | ~May | Low-medium | ML reviewers; reach for the AI-governance audience, weak for soundness claims |

Prior art the paper must beat or distinguish (verified): **zkLLM** (Sun, Li,
Zhang; ACM CCS 2024; 13B, full inference under 15 min, proof under 200 kB,
hides the *model parameters*); **zkGPT** (Qu et al., USENIX Security 2025;
GPT-2 in under 25 s); **DeepProve** (Lagrange + UIUC/HKUST/Yale, ePrint
2026/1112, CCS 2026 minor revision; GPT-2 and Gemma 3, ~86 tokens/min,
1,855 tokens/min distributed, verify 1–3.7 s); **zkAgent** (SJTU, ePrint
2026/199, CCS 2026 major revision; GPT-2 512-token transcript, 0.30 s/token
amortised); **OpenLLM** (Zhejiang/Ant, ePrint 2026/1578, preprint);
**"The Cost of Intelligence"** (Modulus/World, ePrint 2026/1063, MLP
benchmarks across proof systems); **Jolt** (EUROCRYPT 2024) and RISC Zero
for the zkVM route; **EZKL** (tool, no venue found); **Attestable** (blog
numbers only). None of the abstracts read states that *inputs, outputs and
activations* are hidden from the verifier, the property Victor's P1 proves.
That, plus a trained 8B next-token proof on an 8 GB consumer GPU, is the
publishable delta. Check each full paper before claiming "first".

**Does a paper speed up money?** Not directly. A top-venue decision comes
3–5 months after submission (S&P cycle 2: Mar 5; USENIX: May 6), long after
YC (Dec 11) or Alliance (Jan) decide. Accelerators and seed investors judge
the demo, the numbers and the founder; a *preprint* helps them (and grant
reviewers) as a credible, dated technical artifact, especially against a
funded competitor with no paper. So: preprint early, peer review in
parallel, never block an application on a paper.

**Patent order:** a public preprint, talk or open repo is prior art. The US
gives the inventor a one-year grace period for their own disclosure (35 USC
102(b)(1)); most other countries do not. If a patent is wanted, file a US
provisional first: USPTO fee $325 / $130 small / $65 micro entity (fee
schedule rev. Aug 14 2026), plus attorney drafting time. The GitHub repo
returned 404 to an anonymous fetch (appears private, good); Victor should
confirm whether the Sep 2026 Tech Week demo was shown publicly and what it
disclosed.

## 3. Top 5 actions (speed × amount × fit)

Preparation times are estimates, not measurements.

1. **Apply to YC W27 by Nov 2, 8 pm PT** ($500k; decision Dec 11).
   Prepare: the online form, a 1-minute founder video, a 2–3 minute screen
   recording of the demo (prove a next-token step, verify it, show a tampered
   proof failing), and plain numbers (85 s TinyLlama, 192 s / 43 s / 471 MB
   for 8B, 487 s for the 128-token 8B stack, ~97 bits). One paragraph on
   Attestable and why hidden IO is different. No entity, deck or data room
   needed to apply. **1–2 days.** Late applications are accepted with no
   promised timing, but on-time is much better.
2. **Apply to Alliance ALL19 and Techstars Spring 2027 by Nov 18.** Alliance
   ($400k, $4M post, token side letter; Base anchoring and verifiable-AI fit)
   is the better fit; Techstars ($220k for 5% + $200k uncapped SAFE) is a
   hedge. Prepare: a 10–12 slide deck (problem, privacy property, numbers vs
   zkLLM/DeepProve/Attestable, MVP app, market pull from UK OSA/EU DSA, ask),
   reuse the demo video. **2–3 days** after YC.
3. **Incorporate (Delaware C-corp) and file free credit applications** —
   NVIDIA Inception (position as AI safety; "crypto-related companies" are
   excluded), AWS Activate Founders, Microsoft for Startups. Needed for any
   SAFE and for credits; it also lets an 8B/RTX 5090 bench run on rented
   GPUs. **Incorporation: days (service and cost not researched here);
   credits: weeks.** Do it once an offer looks likely, or now if cheap.
4. **Provisional patent (only if wanted), then an IACR ePrint technical
   report, then a peer-review submission.** A 10–15 page report with the
   construction, the privacy statement (P1), soundness accounting and the
   measured table, posted before YC/Alliance interviews (late Nov–Dec) if
   possible; full paper to USENIX Security '27 (Jan 26) or CCS 2027 cycle 1
   (~mid-Jan, UNVERIFIED), PoPETs (Nov 30 / Feb 28) as the privacy-venue
   fallback. Provisional: USPTO fee $65–$325 + attorney, **1–2 weeks**;
   report: **2–4 weeks**; full paper: **6–10 weeks**. External audit is
   still missing: say so in the paper.
5. **Direct seed outreach with a small data room** (from late Nov, through
   warm intros) to funds with a verified verifiable-AI/ZK record: a16z
   Frontier (newly widened to AI), Variant and 1kx (Modulus), Founders Fund
   and 1kx (Lagrange), Paradigm, Polychain, Lightspeed/Pantera, Framework,
   plus AI-safety funds Juniper Ventures and Halcyon. Data room: deck, demo
   video, preprint, one-page privacy/security statement with its limits (no
   external audit; the accepted 97-bit level and, where the Groth16 wrap
   is used, its trusted setup, per D3/D4), roadmap to
   ≥50 tok/s with the measured gap. Seed rounds in this space: $6–20M.
   **Prep 1 week; rounds take weeks to months.** Watch-list for later
   windows: AI Grant Batch 5, SPC next cycle, Neo, Base Batches 005,
   Seldon Lab, PearX (rolling-late).

## Sources (all fetched or searched 2026-10-28)

Accelerators
- YC apply page (W27, Nov 2 8 pm PT, decision Dec 11): https://www.ycombinator.com/apply
- YC deal ($500k, 7%, entity types): https://www.ycombinator.com/deal ; RFS: https://www.ycombinator.com/rfs
- Alliance (ALL19 Nov 18, starts Jan 11 2027, $400k at $4M post, AI accepted): https://alliance.xyz/
- Techstars NYC (Nov 18, Mar 8 2027, $220k terms): https://www.techstars.com/accelerators/new-york ; list: https://www.techstars.com/accelerators
- PearX W27 (closed Oct 4, rolling after): https://pear.vc/pearx-application/
- SPC Founder Fellowship F26: https://www.southparkcommons.com/news/f26-founder-fellowship
- AI Grant (Batch 4 closed, terms): https://aigrant.com/
- Neo terms (TechCrunch, 2026-02-19): https://techcrunch.com/2026/02/19/ali-partovis-neo-looks-to-upend-the-accelerator-model-with-low-dilution-terms/
- Entrepreneur First: https://www.joinef.com/
- a16z CSX (no cohort shown): https://a16zfrontier.com/csx/ ; rename post (2026-10-22): https://a16zfrontier.com/posts/article/a16z-frontier ; TechCrunch: https://techcrunch.com/2026/10/22/as-blockchain-investing-falls-out-of-vogue-a16z-crypto-rebrands-as-a16z-frontier/
- Base Batches: https://docs.base.org/get-started/base-batches.md ; Batches 004 (2026-08-19): https://cryptobriefing.com/base-batches-004-investing-1m-startups/
- Outlier Base Camp: https://www.outlierventures.io/base-camp
- Seldon Lab: https://seldonlab.com/ (terms third-party: https://manifund.org/projects/ai-security-startup-accelerator-batch-2)

Rounds and investors
- Attestable: https://www.calcalistech.com/ctechnews/article/h1ddvrd8mg ; https://www.kucoin.com/news/flash/attestable-completes-20m-seed-round-for-ai-verifiable-tech-breakthrough ; https://www.noze.it/en/insights/zero-knowledge-proofs-inference-attestable/
- Modulus: https://www.theblock.co/post/260335/modulus-raises-6-3-million-to-bring-crypto-security-to-ai ; TFH: https://www.biometricupdate.com/202412/firm-using-cryptography-to-keep-ai-accountable-joins-world-via-tfh-acquisition
- Lagrange: https://siliconangle.com/?p=655252 ; https://www.businesswire.com/news/home/20251113488577/en
- Inference Labs: https://www.theblock.co/post/360011/inference-labs-raises-6-3m-to-secure-ai-agents-through-verifiable-inference-protocol
- Succinct: https://blog.succinct.xyz/series-a/ ; RISC Zero: https://risczero.com/blog/series-a ; Nexus: https://blog.nexus.xyz/series-a
- Brevis: https://www.theblock.co/post/325504/brevis-network-seed-funding-token-round ; Mira: https://prnewswire.com/news-releases/mira-closes-9m-seed-round-led-by-bitkraft-ventures--framework-ventures-302197520.html
- Polyhedra (UNVERIFIED totals): https://www.coindesk.com/business/2023/02/21/polyhedra-network-raises-10m-for-zero-knowledge-infrastructure/
- Juniper Ventures Fund II (DNV, 2026-05-20): https://www.dnv.com/news/2026/juniper-fund2/

Credits and regulation
- NVIDIA Inception: https://www.nvidia.com/en-us/startups/
- AWS Activate: https://aws.amazon.com/startups/credits ; Google AI tier: https://cloud.google.com/startup/ai ; Microsoft: https://www.microsoft.com/en-us/startups
- EU age-verification blueprint: https://digital-strategy.ec.europa.eu/en/news/commission-makes-available-age-verification-blueprint ; https://docs.ageverification.dev
- Ofcom fines: https://www.ofcom.org.uk/online-safety/protecting-children/ofcom-fines-nudification-site-50000-for-failing-to-introduce-age-checks ; https://www.grcreport.com/post/ofcom-sends-clear-warning-with-ps1-4-million-fine-over-missing-age-checks-2

Venues and prior art
- IEEE S&P 2027 CFP: https://sp2027.ieee-security.org/cfpapers.html
- USENIX Security '27: https://www.usenix.org/conference/usenixsecurity27 ; preliminary CFP PDF: https://www.usenix.org/sites/default/files/sec27_cfp-070826.pdf
- CCS 2027: https://www.sigsac.org/ccs/CCS2027/ ; CCS 2026 CFP (pattern): https://sigsac.org/ccs/CCS2026/call-for/call-for-papers.html
- NDSS 2027 CFP: https://www.ndss-symposium.org/ndss2027/submissions/call-for-papers/
- PoPETs 2027: https://www.petsymposium.org/cfp27.php
- CRYPTO 2026 (pattern): https://crypto.iacr.org/2026/callforpapers.php ; Eurocrypt 2027: https://eurocrypt.iacr.org/2027/callforpapers.php
- IACR CiC: https://cic.iacr.org/callforpapers ; ePrint about: https://eprint.iacr.org/about.html
- ICML 2027 (projection only): https://www.opencurious.com/ai-conference-deadlines/icml-2027
- zkLLM: https://arxiv.org/abs/2404.16109 ; zkGPT: https://www.usenix.org/conference/usenixsecurity25/presentation/qu-zkgpt ; DeepProve: https://eprint.iacr.org/2026/1112 ; zkAgent: https://eprint.iacr.org/2026/199 ; OpenLLM: https://eprint.iacr.org/2026/1578 ; Cost of Intelligence: https://eprint.iacr.org/2026/1063 ; Jolt: https://eprint.iacr.org/2023/1217
- USPTO fees: https://www.uspto.gov/learning-and-resources/fees-and-payment/uspto-fee-schedule
