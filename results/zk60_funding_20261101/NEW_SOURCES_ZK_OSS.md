# New funding sources: ZK and crypto ecosystems, open-source and privacy funds, compute, prizes

Researched 2026-11-01. Research only: nothing was submitted, no account was
created, nobody was contacted.

Scope: sources **not** in the 2026-10-28 notes
(`GRANTS_PHILANTHROPY_ECOSYSTEM.md`, `wave2/ECOSYSTEM_PRIZES_REVENUE.md`,
`INVESTORS_PUBLICATION.md`). A few items from those notes were re-checked
only where the state might have moved. They are marked "re-check".

Ranking follows the coordinator's priority update. It sorts by **how soon
money can arrive** and how urgent the deadline is, fit permitting. Slow
programmes get a short entry only.

Labels:
- **Verified**: read on the official page today. The URL is in the source log.
- **Partial**: an official page was only partly readable, or the fact comes
  from an aggregator that copies the official page.
- **UNVERIFIED**: no official page confirmed it.

"Earliest realistic money" dates are **my estimates** from the stated review
times. They are not promises from the funder.

## 1. Plain summary

- **The most urgent new item is the NEAR Hackathon.** It has a "Privacy & Private AI" track paying $10k / $3k / $2k, and a $55k grand prize, paid in NEAR tokens. Submissions close **Sat 14 Nov 2026, 23:59 UTC** (15:59 PST). Results come by 18 Nov. It needs a public repo and new code built on NEAR.
- **The fastest compute is the Lambda Research Grant.** It gives up to $5,000 of cloud credits, on a rolling basis. Its form asks for H100 hours and needs no university field. This could pay for CUDA/H100 benchmark runs while the 5090 box is not up.
- **The biggest rolling cash is the OTF Internet Freedom Fund.** Awards are $10k–$900k in USD, with $50k–$200k typical. Individuals and for-profits may apply. It answers a concept note in about 6–8 weeks. The fit is uncertain: it funds internet freedom and digital security, not AI audits.
- **The Ethereum Foundation has no open door.** ESP shows no RFPs, no wishlist items and no grant rounds. The last academic round I could confirm closed 24 Mar 2025. PSE (the privacy lab) was reported wound down after the June 2026 cuts.
- **Most other chain programmes are closed, paused, or need a port to their chain.** Cardano Catalyst is paused, Polkadot Fast-Grants and Flashbots grants are closed, and Taiko, Tezos, Stellar and Algorand all want their chain used. ZPrize has no new round.
- **New this week, compared with the 10-28 notes:** wave 2 said "no ZK or AI cash prize is open before February". That is no longer true: NEAR (14 Nov), Apart's Agent Attribution sprint (29 Nov) and the Encode/Concordium hackathon (9 Dec) are all open. All three are small.
- **Before any public entry:** a hackathon repo is a public disclosure. Settle the patent question (earlier notes advised a provisional first). Then keep every claim to the measured numbers in `ZK60_DECISIONS.md`.

## 2. Ranked table (sorted by earliest realistic money)

Ind = a US individual can apply. PT = a part-time lead hiring others is fine.
Co = a new US company can apply.

| # | Opportunity | Next deadline (TZ) | Amount, payout | Earliest realistic money (estimate) | Ind / PT / Co | Fit | Check |
|---|---|---|---|---|---|---|---|
| 1 | **NEAR Hackathon, Privacy & Private AI track** | **14 Nov 2026 23:59 UTC** (15:59 PST) | $10k / $3k / $2k per track; $55k grand prize; paid in NEAR | Late Nov–Dec 2026 (results by 18 Nov; payout date not stated) | Yes / yes (teams 1–8+) / not addressed | **Med**: on-theme track, but NEAR-centred, token-paid, and a 2-week sprint | Verified |
| 2 | **Lambda Research Grant** | Rolling | Up to $5,000 in Lambda cloud credits (not cash) | Dec 2026 (review time not stated) | Appears yes / yes / appears yes (optional "Company" field) | **Med-High** for compute: H100 hours for the CUDA port and scaling numbers | Verified (page + form) |
| 3 | Encode Club x Concordium "Trusted Agents" hackathon | Final submissions 9 Dec 2026 (time not stated) | Pool UNVERIFIED (one aggregator: $5,000) | Late Dec 2026 | Teams of 2–3 (aggregator) | Low-Med: ZK agent identity, not inference | Partial |
| 4 | **OTF Internet Freedom Fund** | Rolling | $10k–$900k, typically $50k–$200k over 6–12 months; USD, on deliverables | Concept-note reply ~6–8 weeks (late Dec–mid Jan); cash ~Q2 2027 | Yes (18+, any nationality, not OFAC-sanctioned) / yes / yes (for-profits) | **Med**: large and on-terms, but the remit (internet freedom) may not fit | Verified |
| 5 | **0xPARC research grants** | Rolling (email) | "Short to medium term grants"; amount not stated | Unknown | Not stated | **Med** on topic (zkSNARKs, hardware acceleration, lookups); the page looks stale (newest output May 2023) | Partial |
| 6 | Taiko Grant Cycle 3 | Rolling | $25M fund ("Taiko 2025 Grant Fund"); per-grant size and token not stated | Unknown | Not stated / KYC or KYB required | Low-Med: AI track; dApps must launch on Taiko | Partial (no 2026 date) |
| 7 | **EF Academic Grants (next round)** | None open; the 2025 round ran 20 Jan – 24 Mar 2025 AoE | 2025 round: "$2M" in total (the FAQ says $1.5M) | Mid-2027 at best, if a 2027 round repeats the 2025 pattern | Yes, individuals, teams and organisations / yes / organisations yes | **Med**: strong topic, but closed now; needs an academic-style proposal | Verified (2025 page; no current round) |
| 8 | EF Proximity Prize (Reed–Solomon proximity) | **31 Dec 2027 23:59 UTC** | $1M across two grand challenges; payout form not stated | 2027–28 | "Anyone" except judges | Low-Med: only if a hired cryptographer works on it; sharper RS bounds would help Ligero/FRI soundness | Verified |

## 3. Detail: High and Med fits

### 3.1 NEAR Hackathon, track "Privacy & Private AI" (Med, the most urgent)

1. **Name, URL, status:** NEAR HACKATHON, https://nearhackathon.com/. It is
   live now. It started "1 Nov 2026 · 00:00 UTC". Verified.
2. **Next deadline:** "Development ends: 14 Nov 2026 · 23:59 UTC" (15:59
   PST). Judging runs 16–18 Nov. "results are announced by 18 Nov 2026 ·
   23:59 UTC". Verified.
3. **Amount and payout:**
   - Each of 13 tracks pays "1st $10K, 2nd $3K, 3rd $2K".
   - There is one $55K grand prize overall.
   - The prize pool is "paid in NEAR" to the NEAR account address you give.
   - The payout date is not stated. Verified.
   - NEAR's X post says "$250K+ in prizes" in total. Partial.
4. **Eligibility:**
   - (a) A US individual: "Developers, designers and people with ideas for
     the NEAR ecosystem". The page does not mention KYC, countries, age or
     tax forms. Verified (that they are absent).
   - (b) A part-time lead with others: teams of 1 to 8+ may enter. "one
     person can enter up to 2 different projects, if they are independent
     and each README names the other one." Verified.
   - (c) A new company: not addressed.
5. **Open-source and chain conditions:**
   - "Publish the repository. Judges can't open a private one."
   - You must post a demo on X that tags @NEARProtocol and #NEARHackathon,
     with a video or screenshots.
   - "Code written since the announcement counts." So the existing prover
     can be a dependency, but only the new integration work counts.
   - "Build on NEAR". No licence is required.
   - The track text: "Explore confidential computation, private finance and
     AI that protects sensitive data. Build intelligence without exposure."
     Its tags are Private AI, TEE and NEAR AI Cloud.
   - The track's starter prompt suggests a TEE-attested expense auditor on
     NEAR AI Cloud. It does not mention zero-knowledge proofs.
   - Verified (page and the GitHub prompt file).
6. **Time to decision:** 4 days after the close (results by 18 Nov). "Claude
   Code & Codex screen every project first to check that it runs and does
   what the README says. Human judges make the decisions." Verified.
7. **Form fields** (the "Submit" section of nearhackathon.com):
   - project name
   - team lead
   - email
   - team size
   - tracks
   - NEAR wallet address
   - repository link
   - demo post link
   - a description of what you built (20–2,000 characters)
   - website (optional)
   - a consent checkbox for the organisers to review the submission and
     contact you.

   Attachments: none, beyond the public repo and the X post. Verified.
8. **Fit: Med.** The track's own example relies on TEE attestation. A
   ZK-proved classifier verdict on a hidden post (with no hardware trust),
   anchored on a NEAR contract, would stand out.

   The costs:
   - token payout;
   - a public repo now;
   - a NEAR integration in 13 days, part-time.
   - Prizes in NEAR count as income at their value when received; record
     the USD value on receipt and check with a tax adviser.

   Angle: "the same privacy as a TEE, but you trust maths, not a chip."
   Keep the claim to measured numbers: 8B blocks at about 11 tokens/s per
   request on an M3 Ultra; privacy accepted internally, with no external
   audit.

### 3.2 Lambda Research Grant (Med-High for compute; fast)

1. **Name, URL, status:** Lambda Research Grant, https://lambda.ai/research.
   The page shows "Apply for a grant" and gives no closing date. The form
   was last updated 2026-06-26 (from the form's metadata). Verified.
2. **Next deadline:** rolling. No deadline is stated. Verified.
3. **Amount and payout:** "up to $5,000 in cloud credits" for Lambda's
   Instances. These are credits, not cash. Selected research "may be
   featured" on Lambda's site. Verified.
   - Aggregators say a Lambda Cloud account needs phone verification and a
     credit card on file. UNVERIFIED.
4. **Eligibility:**
   - (a) "qualifying researchers", not defined. The form has no
     institution field. "Company" is optional. Aggregators claim an
     academic slant. Partial.
   - (b) A part-time lead: fine. Nothing on the form asks about employment.
   - (c) A company: the optional "Company" field suggests startups can
     apply. Partial.
5. **Open-source and chain conditions:**
   - No chain is involved.
   - A required "Publishing Plan" field asks "How do you plan to share your
     research outputs (e.g., paper, open-source projects)?"
   - A required yes/no asks "Are you willing to co-write a blog about your
     work for Lambda's research page?"
   - Verified.
6. **Time to decision:** not stated. UNVERIFIED.
7. **Form fields** (Typeform https://form.typeform.com/to/Wn8YWMIj, read
   from the form's own definition):
   - Contact Information: First name, Last name, Phone number, Email,
     Company (optional). Required flags for the others were not read.
   - "Related Publications (if any)" (optional): "Provide a link to your
     own relevant papers, project pages, or other supporting materials such
     as demos or prototypes which may have shown good results on small
     datasets"
   - "Research Problem" (required): "What problem does your research
     address, why is it important, and what success looks like?"
   - "Relevance and Novelty" (required): "What are the key related works
     and trends in this field, and how does your approach offer something
     new?"
   - "Challenges" (required): "What are the main challenges, technical and
     non-technical, you foresee?"
   - "GPU Compute Needs" (required, **a number**): "How much GPU compute
     are you applying for (at the scale of 100, 1,000, or 10,000 H100
     hours), and how will it support your research goals?"
   - "Notable Achievements" (required): "Briefly describe something
     impressive you or your team has published or built."
   - "Github Profile" (if applicable)
   - "Google Scholar Profile" (if applicable)
   - "Social Media Profile"
   - "Partnerships and Support" (optional): "Did you or your team
     collaborate with other organizations in the past?"
   - "Roadmap" (required): "What measurable milestones do you see as
     important to guide your idea forward and ensure the project stays on
     track?"
   - "Publishing Plan" (required). Text as quoted in item 5.
   - The blog question (required, yes/no). Text as quoted in item 5.
   - No character limits appeared in the definition. Attachments: none
     (links only). Verified.
8. **Fit: Med-High** for the compute need. The amount is small but quick.
   It buys H100 time for the CUDA port, a measured H100 data point to set
   against Attestable's "53/s on one H100", and scaling evidence for other
   applications.

   Answer "GPU Compute Needs" with the smallest number that covers a
   defined benchmark ladder. Run it through the resource rules on whatever
   box launches it.

### 3.3 OTF Internet Freedom Fund (Med; rolling, large, USD)

1. **Name, URL, status:** Open Technology Fund, Internet Freedom Fund,
   https://www.opentech.fund/funds/internet-freedom-fund/. Applications are
   "accepted on a rolling basis". Verified.
   - The official pages carry no notice about OTF's funding situation in
     2025–26. Aggregators describe OTF as US-government funded. Check that
     funding is flowing before investing effort. UNVERIFIED.
2. **Next deadline:** none (rolling). Verified. The separate Surge and
   Sustain Fund closed 15 Oct 2026 (aggregator, Partial).
3. **Amount and payout:** "$10,000 to $900,000 over up to 24 months". The
   ideal ask is $50,000–$200,000 for 6–12 months. It is paid in US dollars,
   released when agreed objectives and deliverables are met. Verified.
4. **Eligibility:**
   - (a) "Individuals aged 18 or older, or for-profit or nonprofit
     organizations, 'irrespective of nationality, creed, or sex.'" There is
     no support in OFAC-sanctioned countries. Verified.
   - (b) A part-time lead: allowed. The budget can pay collaborators; the
     concept note asks who does each task.
   - (c) A new company: yes, for-profits are eligible. Verified.
   - OTF says it prioritises first-time applicants and underfunded areas.
5. **Open-source and chain conditions:** none stated on the fund page. The
   examples are open-source tools, and OTF's IP policy in the guidebook was
   not read. No chain. Verified (absence on the page).
6. **Time to decision:** "Applicants can expect to hear back within
   approximately 6-8 weeks after submitting a Concept Note." Strong concept
   notes are invited to a full proposal, then go to Advisory Council review
   (no time is given). Verified.
7. **Form fields** (the Concept Note, from the Applicant Guidebook). These
   are the questions verbatim. No word limits are stated except "1-3
   sentences":
   1. Project Title
   2. "Describe your project in 1-3 sentences."
   3. "What problem will your project address?"
   4. "If this project is funded, what form will it take?" Choose one of
      Technical Development / Applied Research / Digital Security /
      Community Convenings.
   5. "Give a brief overview of the activities in this project."
   6. "Are there similar projects that exist already? How is your project
      different or complementary to those projects?"
   7. "How long do you estimate activities will take?"
   8. "How much funding do you estimate you will need? (In US Dollars)"
   9. "Who would benefit from this project?" ("Benefits everyone" is not
      accepted.)
   10. "Where are your intended users, or audiences located?" (UN regions)
   11. "What is your name?"
   12. "What email address should we use to contact you?"
   13. "Why are you, and your team members, the right people to work on
       this project?"
   14. "What is your proposed start date for this project?" (Convenings
       only; at least 90 days out.)

   - Full-proposal stage: the objectives question has a 500-word
     recommendation and a 2,000-word maximum. Monitoring and evaluation has
     400 recommended and 1,000 maximum.
   - Submission: https://apply.opentech.fund/ (a login is needed; the form
     itself was not visible).
   - Verified (guidebook appendices).
8. **Fit: Med (uncertain remit).** OTF funds "internet freedom in
   repressive environments": circumvention, censorship research and
   digital security.

   A content-safety proof could be read as a censorship tool. Frame it as
   *digital security and anti-surveillance*: platforms and auditors can
   check a moderation or safety verdict without collecting or seeing user
   content, so the user's post never leaves their control. Use category
   "Technical Development" or "Applied Research".

   OTF's evaluation asks about remit fit, a real problem,
   cost-effectiveness, sustainability and complementarity. Expect a no if
   the user story is not about at-risk users.

### 3.4 0xPARC research grants (Med on topic; status uncertain)

1. **Name, URL, status:** 0xPARC Research, https://research.0xparc.org/.
   The page text says: "By default, we provide short to medium term grants
   to values-aligned work within our current scope. Tell us what you'd like
   to do (or would like us to do) with a short proposal if this fits. The
   more ambitious and controversial, the better."
   - The newest item on its "/output" page is from **May 2023**, so the
     page may be stale.
   - 0xPARC is mainly EF-funded (aggregator), and EF cut its 2026 budget by
     about 40% (TechTimes). Partial.
2. **Next deadline:** none stated.
3. **Amount and payout:** not stated. Aggregators list "PARC Squad Grants"
   at $4,000–$40,000, and SJSU shows a $93,366 0xPARC award in Feb 2026.
   UNVERIFIED and Partial.
4. **Eligibility:** (a), (b) and (c) are not stated.
5. **Open-source and chain conditions:** not stated. 0xPARC "writes
   open-source tooling". No chain.
6. **Time to decision:** not stated.
7. **Form:** no form. A "short proposal" by email. The page's only address
   is nalin@0xparc.org, given for researcher hiring. The listed scope is:
   zkSNARKs, proof recursion, zkDSLs, **hardware acceleration**,
   **connective tissues (lookups)**, crypto primitives "(ECs, UO groups,
   lattices, ...)", (non-interactive) MPC, PIR, TEE, "exotic encryption".
   Partial (read from the site's script bundle).
8. **Fit: Med.** Our GPU sumcheck/LogUp/Ligero prover sits squarely in
   "hardware acceleration" and "lookups". A one-page email costs little.
   Only send it after confirming the programme is alive (for example from
   a recent 0xPARC post).

### 3.5 EF Academic Grants, next round (Med; slow, so a short entry)

- **Status:**
  - ESP "open rounds": "There are no active grant rounds at this time."
  - The RFP page: "There are currently no active Request for Proposals
    available for application."
  - Both Verified.
  - Aggregators mention a 2026 academic grantee announcement (July 2026).
    Not confirmed on EF pages. UNVERIFIED.
- **2025 round, the template for a repeat:**
  - It opened 20 Jan 2025 and the deadline was "23:59 AoE March 24th,
    2025". Decisions came 6 weeks later.
  - Projects ran 6–12 months.
  - Open to "individuals, teams, and organizations", for example
    "Individual researchers with academic backgrounds".
  - "Research output must be open-access with a free and permissive
    license". "Proposals must include a public repository or link to
    published work".
  - Excluded: retroactive funding and "Projects with a planned token
    launch or public funding round". Ask EF whether a future VC round
    counts.
  - Format: a PDF proposal in English, with a detailed description,
    budget, timeline and applicant profile.
  - Verified.
- **Context:** EF's Q1 2026 grants ($9.86M) funded ZK formal verification,
  "GPU-Accelerated R1CS Witness Generation" and "Formalising Proximity
  Generators", but no zkML. Verified.
- **Fit: Med.** The best co-PI vehicle (for example with a UIUC or NYU
  group) if a 2027 round opens. Money mid-2027 at the earliest. Watch
  esp.ethereum.foundation from January. Contact: academic-grants@ethereum.org
  (blog excerpt, Partial).

## 4. Low fits, closed doors and re-checks (one table)

| Source | What I found today | Fit | Check |
|---|---|---|---|
| Apart Research "Agent Attribution" sprint | Online 27–29 Nov 2026; closes 29 Nov 23:59 AoE; $2,000 total ($1,000 first); an 8-page PDF report; top teams fast-tracked to the Apart Fellowship. The fetched page also said submissions were closed, which conflicts with its dates | Low: about which human steers an agent, not ZK; a cheap AI-safety credibility point | Verified (dates) / Partial (status) |
| Apart "Threat Intelligence & Threat Modelling" sprint | 4–6 Dec 2026, online, $5,000 | Low | Partial (search excerpt) |
| UBC 2026 hackathon (UT Austin) | 13–21 Nov; >$23k; agentic payments track | Low | Partial (aggregator) |
| IXH26 Italian XRPL hackathon | 21–22 Nov, in person in Bari; "Advanced cryptography" track €2,000 / €1,200 / €800 | Low (travel to Italy, XRPL) | Partial (aggregator) |
| Stellar Community Fund #46 | Interest form "ASAP"; deadline 9 Nov 2026; up to $150k in XLM in tranches; must launch on Stellar | Low | Verified |
| Tezos Foundation ecosystem grants | Rolling; reviewed the month after each quarter (so Q4 → January); ~4 weeks review + ~4 weeks paperwork; amount not stated | Low (Tezos) | Verified |
| Algorand xGov | **Retroactive only**; small 10k–50k ALGO, medium 50k–250k; KYC; one active proposal per person | Low: needs finished Algorand work | Partial (xgov.app explorer FAQ, which cites algorand.foundation/xgov) |
| Cardano Project Catalyst | Fund 15/16 "not feasible" during the hand-over to the Cardano Foundation; the 2026 Pilot closed 20 Aug | Nil now | Verified |
| Polkadot Fast-Grants | "closing its application intake" (3 Nov 2025) | Nil | Verified |
| Flashbots research grants (FRP) | Repo says grant giving is "currently paused" | Nil | Partial |
| EF PSE / Privacy Stewards | PSE reported wound down (TechTimes, 23 Jun 2026). The official EF structure post does not mention PSE. pse.dev lists no grants | Nil | Partial |
| EF Poseidon Prize | Poseidon bounties; EF has since moved L1 work toward SHA/BLAKE (reported). We use BLAKE3 | Low | Partial |
| GitHub Secure Open Source Fund | $10k per project ($6k / $2k / $2k); 15 h over 3 weeks; rolling; needs "community traction" | Low until the repo is public and used | Verified |
| OpenMined research grants | Ensembles & Routing call closed 30 Oct 2026; $5k compute + $2k stipend; Apache 2.0 | Low (topic); watch for a privacy-AI call | Verified |
| Nebius research credits | Monthly review; notified by end of next month; aimed at academic and non-profit researchers | Low (route via an academic collaborator) | Verified |
| NSF NAIRR Pilot | US institutions; "startups or small businesses with federal grants"; monthly cycle; outcome within 3 months | Low now; Med after an SBIR/STTR award | Verified |
| NVIDIA Academic Grant | Full-time faculty only (aggregators); no official page found | Low (collaborator route) | UNVERIFIED |
| Google TPU Research Cloud | Free TPUs; must share results publicly | Low: the prover is Rust/Metal/CUDA, not TPU | Verified |
| Apple (Metal) | No Metal or GPU grant found; only the Apple Scholars PhD fellowship | Nil | UNVERIFIED (absence) |
| Modal credits | Startup credits $25k–$50k (conflicting; may need a VC or company); $30/month free tier | Low-Med after incorporation | UNVERIFIED |
| HackerNoon "Decentralize AI" | Blog-post contest, round 2 Nov 2026 – Feb 2027; mostly Nosana compute credits | Low | Partial |
| Taiko Grant Cycle 3 | See ranked table row 6; no 2026 date seen | Low-Med | Partial |
| DFINITY (Internet Computer) grants | Page failed to load (canister error). Search excerpt: a DeAI grant is still advertised; amounts unknown; must build on ICP | Low | Partial |
| ZKsync / ZK Nation; Linea | Governance allocations to Matter Labs and marketing RFPs; no research call. Linea: no confirmed 2026 open grant | Low | Verified / Partial |
| Arbitrum (re-check) | Foundation grant programme still "Applications will open soon"; Trailblazer AI complete | Low | Verified |
| Aztec | Forum RFGPs (e.g. state migration, closed 23 Jan 2026); nothing for zkML | Low | Partial |
| Sovereign Tech Fellowship | 2026 round closed 6 Apr 2026; freelance option worldwide; for maintainers of critical infrastructure | Low | Partial |
| Open Source Pledge | A pledge companies make, not a grant to apply for | Nil | Verified |
| Alpha-Omega; OpenSSF; DPGA; GitHub Accelerator | No open call found; GitHub Accelerator has no 2026 cohort | Nil | Partial / UNVERIFIED |
| Prototype Fund | Official page blocked (403); German-residence rule not confirmed today | Low | UNVERIFIED |
| a16z crypto research; IC3 | No seed or co-PI programme found. IC3 is sponsor-pays, and "All IC3 projects funded by our industry partners are open source" | Nil (relationship only) | Partial |
| Berkeley RDI AgentX | 2026 edition over; no 2027 dates | Watch | Partial |
| Akash; io.net; Vana; Avail | No builder or compute grant found | Nil | UNVERIFIED (absence) |
| EigenCloud; Ritual; Gensyn; Phala; Nillion; Bittensor SN2 | No change found since 10-28 (Eigen: nothing new) | Low | Partial |
| ZPrize; ETHGlobal (re-check) | No ZPrize after 2023 edition; ETHGlobal lists only Mumbai (5–7 Nov, in person) through April 2027 | Nil | Verified |
| Gitcoin GG25 (re-check) | Targeted "Q2 2026" in a withdrawn draft; no dates found | Low | Partial |
| Not re-checked (covered 10-28): Scroll, Polygon, Celestia, Mina, Sui, Aptos, Optimism, Protocol Labs, Starknet seed grants, Kusama, Aleo, Solana, Celo, 0G, World One | — | — | — |

## 5. Terms to settle before any of these

- **Public disclosure.** NEAR needs a public repo plus an X post. Apart and
  Encode publish reports. If a provisional patent is still wanted, file it
  first. If not, record that decision.
- **Token payouts.** NEAR (NEAR), Stellar (XLM), Tezos, Taiko and Algorand
  pay in tokens. That brings price risk and US income tax at the value on
  receipt. Only Taiko and Algorand state KYC; NEAR states none.
- **IP and openness.** The EF academic round needs a permissive open
  licence and excludes "a planned token launch or public funding round".
  Lambda asks for a publishing plan and a co-written blog. These fit the
  plan to open-source the stack, but each funder's IP terms must be read
  before signing.
- **Claims discipline.** Describe speed, soundness (~97-bit), privacy
  (internal acceptance, no external audit) and the Base anchor (testnet)
  exactly as in `docs/zkmatrix-poc/ZK60_DECISIONS.md`. The NEAR judges'
  AI screen checks that the README matches what runs.

## 6. Source log (fetched or searched 2026-11-01)

NEAR
- https://nearhackathon.com/ — seen: "1 Nov 2026 · 00:00 UTC" to "14 Nov 2026 · 23:59 UTC"; judging 16–18 Nov; results by 18 Nov 23:59 UTC; 13 tracks, $10K / $3K / $2K each, $55K grand prize, "paid in NEAR"; public repo, X demo post; "Code written since the announcement counts"; the form fields listed in 3.1; no KYC or terms link.
- https://github.com/nearai/near-hackathon-prompt-examples/blob/main/tracks/03-privacy.md — seen: "Private by design"; lean on "Private AI, TEE, NEAR AI Cloud"; example is a TEE-attested expense auditor; no ZK mentioned.
- https://x.com/NEARProtocol/status/2112257967818997891 (search excerpt) — "$250K+ in prizes. No signup."

Lambda
- https://lambda.ai/research — seen: "up to $5,000 in cloud credits"; "qualifying researchers"; form link.
- https://form.typeform.com/to/Wn8YWMIj — form definition read with curl; fields as in 3.2; "last_updated_at":"2026-06-26".

OTF
- https://www.opentech.fund/funds/internet-freedom-fund/ — seen: rolling; $10k–$900k up to 24 months, ideal $50k–$200k for 6–12 months; USD on deliverables; individuals 18+ and for-profits, any nationality, no OFAC-sanctioned countries; 6–8 weeks after a concept note.
- https://docs.opentech.fund/otf-application-guidebook/appendix-i-concept-note-guide — the concept-note questions quoted in 3.3.
- https://docs.opentech.fund/otf-application-guidebook/appendix-ii-proposal-guide (search excerpt) — full-proposal word limits.
- https://www.opentech.fund/ — no funding-status notice shown. https://apply.opentech.fund/ is behind a login.

0xPARC
- https://research.0xparc.org/ (script bundle read with curl) — grants paragraph, scope list and email as quoted in 3.4; newest output item May 2023.
- Aggregators (grantedai.com listings; sjsu.edu research foundation list, Feb 2026) — amounts, UNVERIFIED.

Ethereum Foundation
- https://esp.ethereum.foundation/applicants/rfp — "There are currently no active Request for Proposals available for application."
- https://esp.ethereum.foundation/applicants/open-rounds — "There are no active grant rounds at this time."
- https://esp.ethereum.foundation/academic-grants — the 2025 round as in 3.5.
- https://esp.ethereum.foundation/rounds/phdfp26 and https://blog.ethereum.org/2026/02/05/phd-fellowship (search excerpts) — PhD students only; closed in April 2026.
- https://blog.ethereum.org/2026/04/29/allocation-q1-26 — Q1 2026 total $9,856,014.14; ZK and privacy grants listed; no zkML.
- https://blog.ethereum.org/2026/06/23/ef-structure — new clusters; PSE and ESP not mentioned.
- https://www.techtimes.com/articles/318949/20260623/ethereum-foundation-cuts-54-jobs-shuts-zk-research-lab-slashes-budget-40.htm — 54 jobs cut, ~40% budget cut, PSE wind-down (secondary).
- https://pse.dev/ — no grants or RFPs listed.
- https://proximityprize.org/ — $1M; deadline 31 Dec 2027 23:59 UTC; peer-reviewed plus ePrint or arXiv; "Anyone is eligible ... with the exception of the prize judges"; "at this moment we are unable to award grants".
- https://blog.ethereum.org/ — no grant, RFP or prize posts from August to October 2026.

Hackathons and prizes
- https://ethglobal.com/events — only ETHGlobal Mumbai (5–7 Nov) in range.
- https://apartresearch.com/sprints/agent-attribution-2026 — 27–29 Nov; closes 29 Nov 23:59 AoE; $2,000; PDF report.
- https://web3voyager.com/blog/web3-hackathons-november-2026 — aggregator source for UBC, IXH26, Concordium, BCH and Dev3pack.
- https://www.encodeclub.com/programmes/concordium-trusted-agents-hackathon — title only; dates from search excerpts.
- https://decentralizeai.tech/ and https://hackernoon.com/... (search excerpts) — HackerNoon contest terms.
- ZPrize: https://www.zprize.io/faq (search) — no new round.

Chains
- https://communityfund.stellar.org/awards — SCF #46, "November 9, 2026", up to $150,000 in XLM.
- https://tezos.foundation/ecosystem-grants-program/ — quarterly review, ~4 + 4 weeks.
- https://xgov.app/ — retroactive only; size bands; KYC; one active proposal. https://docs.xgov.algorand.co/ — overview only.
- https://docs.projectcatalyst.io/current-fund/fund-basics/fund-parameters, https://projectcatalyst.io/, https://forum.cardano.org/t/its-open-apply-to-the-catalyst-pilot-or-join-decision-panel/156180 — Fund 15 timeline (2025–26); Pilot closed 20 Aug 2026; X post that Fund15/16 are "not feasible" (search excerpt).
- https://github.com/Polkadot-Fast-Grants/apply — intake closing (3 Nov 2025).
- https://taiko.xyz/grant-program — Cycle 3, $25M "Taiko 2025 Grant Fund", rolling, KYC/KYB, Airtable link.
- https://arbitrum.foundation/grants — programme list; foundation grants "will open soon".
- https://forum.zknation.io/t/tpp-draft-2026-zksync-protocol-network-development-allocation/1005 — Matter Labs allocation; no research call.
- https://github.com/flashbots/mev-research/blob/main/grants.md (search excerpt) — FRP grants paused.
- dfinity.org/grants — canister certificate error (not readable).

Open source and compute
- https://github.com/open-source/github-secure-open-source-fund — $10,000 per project; rolling; 3 weeks / 15 h.
- https://openmined.org/research/grants/ — Ensembles & Routing call closed 30 Oct 2026 AoE.
- https://nebius.com/nebius-research-credits-program — monthly cycle; academic audience.
- https://nairrpilot.org/help — eligibility and monthly cycle as in section 4.
- https://sites.research.google/trc/about/ — free TPUs; publish results.
- https://opensourcepledge.com/ — a company pledge.
- https://www.sovereign.tech/programs/fellowship (search excerpt) — 2026 round closed 6 Apr 2026.
- https://alpha-omega.dev/grants/ — page dated 2023, no call.
- Blocked or not found: prototypefund.de (403), 0xparc.org home (script-only page), dfinity.org (canister error).

Side finding, not funding (for the security owner): arXiv 2607.28884,
"Hollow-LLM Attack: Computationally Trivial Weights in Zero-Knowledge
Verification of LLM Inference". It was seen in search results only; I did
not read it.
