# Unconventional funding, wave 2: ecosystems, prover markets, prizes, crowdfunding

As of 2026-10-28 (complete for this pass).
Method: official pages via web search/fetch. Nothing applied for, no accounts,
no contact. UNVERIFIED = could not confirm on an official page this session.
Note: the session's shared web-search budget ran out partway through; later
items were checked by direct fetch of known official URLs only.

## 1. Plain summary

- **Open now and on-theme:** three programmes. **0G Apollo Cohort 2** (up to
  $2M investment, rolling, **closes Nov 11**; it wants revenue-stage teams, which
  is a stretch for us). **Celo Prezenti Season 3 Frontier** (up to $15k in
  stablecoin; "verification and trust systems" is a named focus; needs a Celo
  mainnet deploy plus KYC). **World One** ($30k residency in San Francisco,
  World ID required; applications are *not* confidential).
- **Fastest cash:** Celo Prezenti (20% paid when the contract is signed) and
  World One (monthly stipend). Phala gives $1k of compute credits in about 48 h,
  but that is credits, not cash.
- **Gone or empty:** Bittensor Subnet 2, the one network that paid for zkML
  proofs, was handed to Dani Labs and its repo archived on 2026-10-20. Gensyn,
  EigenCloud, Ritual and Lagrange have no open cash programme. Zama pays for FHE
  work only. Optimism Retro is reported paused. No ZPrize round exists.
- **Prover markets** (Succinct, Boundless, Brevis, Lagrange) pay only for
  proofs made with *their* systems, never with ours. They need a 24 GB GPU and a
  token stake, and Succinct's own docs say its reference prover won't earn much.
  Treat them as idle-GPU pocket money on the 5090, not as funding.
- **No ZK or AI cash prize is open before February.** The nearest is the ETHDenver
  2027 BUIDLathon, likely in late February, with applications likely opening
  mid-November (both dates inferred). Reg CF crowdfunding becomes available
  about 4–6 weeks after the C-corp exists.

## 2. Tables

### 2a. Verifiable-AI / decentralized-AI networks (funders, partners, acquirers)

| Name | What exists (as seen) | Amount | Chain req | Status | Fit | Verified? |
|---|---|---|---|---|---|---|
| Bittensor Subnet 2 (Inference Labs "Omron"/DSperse) | Paid miners in TAO emissions for zk proofs of inference, scored on proof speed and size | Emissions (TAO) | Bittensor | **Gone for this purpose**: repo archived 2026-10-20, README says "Subnet 2 is now Dani Labs"; Dani Labs site describes a plain (non-ZK) inference subnet "in development" | Was High, now Nil | Verified (GitHub README, danilabs.ai, sn2-docs) |
| Inference Labs | Commercial verifiable-AI company (Proof of Inference, DSperse, JSTprove on Polyhedra Expander, "Sertn"); site claims 950M network proofs. No grants/partner program on site | n/a | none | Site refreshed 2026-10-20; "Talk to sales" only | Partner/acquirer or competitor; their stack slices models and targets CNNs, not private 8B LLMs | Verified (inferencelabs.com) |
| Lagrange (DeepProve) | zkML prover for full LLM inference (started with GPT-2); partners Intel Liftoff, Oracle, Raytheon supplier network, Inference Labs, Talus. No grants or partner-funding programme found | n/a | none | n/a | Direct competitor; possible acquirer; its defense/government channel is a signal of buyer demand | Partial (official blog seen via search, no programme page) |
| World / Tools for Humanity | TfH bought Modulus Labs (zkML) in 2024 to form an applied-research team (aggregator sources). **World One residency** on world.org/grants: $10k/month x 3 months = $30k, up to 5 solo builders, San Francisco co-location at TfH office, must build with World ID; no equity mentioned | $30k | World ID (not World Chain) | Application form live; terms effective 2026-09-15; no cohort dates; offer must be accepted in 10 days (KYC, W-9). Individuals 18+, US work authorisation. **Applications are not confidential and TfH may build similar products** — file the provisional first | Medium: needs SF relocation and a World-ID angle (e.g. "proof of human-posted content" plus private classifier proof). Strategic: TfH is the one big buyer with a zkML team | World One Verified (world.org/grants, /one-terms-and-conditions); Modulus deal UNVERIFIED (aggregators) |
| EigenCloud / Eigen Foundation | EigenAI + EigenCompute (verifiable inference, TEE-based). Foundation grants: 40M EIGEN cap for 2025 in six-month seasons, Grants Team awards; newest foundation post 2025-12-18 (new incentives committee). No 2026 open call found. Paid Summer Fellowship 2026 ($5k/month, SF) closed | EIGEN tokens | Build on EigenLayer/EigenCloud (AVS) | No open call seen | Low-Medium: their verifiable AI is TEE/re-execution; a ZK AVS for private inference is a pitch but no live channel | Verified (blog.eigenfoundation.org) |
| Ritual (Altar) | Altar = rolling support programme (fundraising help, investor network, GTM, hiring). No cash amounts stated. Must build on Ritual Chain | none stated | Ritual Chain | Rolling, "apply any time" | Low-Medium: introductions, not cash | Verified (ritual.net/blog/altar, altar.ritual.net) |
| Gensyn | Mainnet app Delphi (2026-04-22), token TGE 2026-04-29; verification is Verde (reproducible ops + bisection), not ZK. No grants programme found | n/a | Gensyn | n/a | Low | UNVERIFIED (secondary only; no grants page found) |
| Zama | Developer Program Mainnet Season 4 (posted 2026-07-30): one FHE bounty (confidential PoolTogether), 5,000 cUSDT split among up to 3, deadline 2026-09-05 (closed). Grants are FHE (cryptanalysis / FHE apps); nothing ZK | 5k cUSDT/season | Zama fhEVM (Sepolia) | Season 4 closed; later seasons not found | Low: FHE only; ZK work does not qualify | Verified (zama.org Season 4 post); grant terms UNVERIFIED |

### 2a-ii. Chain foundations (non-covered chains)

Pattern: the 2024-25 ZK-L2 programmes (Mina zkIgnite, Arbitrum Trailblazer
AI, Scroll Level Up, Polygon Community Grants S2) are retired or closed.
What is left is mostly tied to deploying on that chain, often paid in its token.

| Ecosystem | Programme | Amount | Chain req | Status / deadline | Fit | Verified? |
|---|---|---|---|---|---|---|
| 0G | Apollo Accelerator Cohort 2 (with xBuilders, Stanford Builders) | Up to $2M **investment** per project after due diligence; instrument not stated | Built around 0G compute/storage (EVM); hybrid considered | **Rolling, closes 2026-11-11**; runs Nov 2026-Feb 2027, December build sprint, Demo Day + in-person graduation at Stanford; mostly remote; up to 10 teams | Medium: "trust layer for AI", privacy/compliance focus, but asks for "revenue-generating AI products, a validated market" — Victor has none yet; dilutive | Verified (apollo.0g.ai) |
| Celo | Prezenti Season 3, Frontier tier | Up to $15k per grant; season pool $172k; paid in USDm stablecoin, 20% upfront / 80% on milestones, 4-month delivery | Celo mainnet deployment + ERC-8004 registration + Self Agent ID + on-chain activity | Season 3 plan posted 2026-07-23, "Season 3 Is Open" thread; no close date; runs to Jul 2027 | Medium: "verification and trust systems" is a named Frontier focus; stablecoin (no token risk); EVM port from Base is small. Contract + KYC required | Verified (forum.celo.org/t/13598) |
| Solana | Colosseum accelerator | $250k pre-seed (SAFE + token warrant) | Solana integration | Only via a Colosseum hackathon win; Crypto World's Fair (Sep 14-Oct 12) in judging; next hackathon undated | Medium-Low: large but gated and needs a Solana port | Verified (colosseum.com/accelerator, per helper) |
| Solana Foundation | Standard / convertible grants, RFPs | Not stated | Solana | Rolling; ~1 week review, ~3 weeks decision | Medium-Low: an open-source Solana verifier + spec could fit "public goods" | Verified (solana.org/grants-funding, per helper) |
| Phala | Startup Program | Up to $1,000 GPU-TEE credits, no equity | None | Open, 48-hour review | Low (tiny), quick | Verified (phala.com/startup-program, per helper) |
| Arbitrum | Trailblazer AI 1.0/2.0, DAO grants | $1M rounds (done) | Arbitrum | All "Complete"; Foundation milestone grant programme "will open soon" | Low now; watch | Verified (arbitrum.foundation/grants, per helper) |
| Aztec | Foundation grants / forum RFPs | Snippets say up to $75k RFPs (Jan 2026) | Aztec/Noir | grants page 404 | Medium on theme if it reopens | UNVERIFIED |
| Mina | zkIgnite retired (2024-12-21); Core grants via GitHub | not stated | Rebuild on o1js | No 2026 season found | Low-Medium | Partly verified |
| NEAR, Sui, Aptos, Sei | Metrics rewards / RFPs / research award ($25k Sui) / Aptos $5-50k (429-blocked) / Sei grants (no terms) | varies | Own chain | No ZK/AI call found | Low | Mixed; Aptos UNVERIFIED |
| ZKsync, Scroll, Polygon | Governance RFPs (ZK token); Scroll community grants (deadline 2025-12-19, stale); Polygon grants page redirects off-domain | — | Own chain | Nothing open that fits | Low | Mixed |
| Filecoin/FFDW/PL R&D, Celestia, Story (now DATA Foundation), Numbers, Akash, Nillion, Hyperbolic, Atoma | No open grant fitting ZK/zkML found; Hyperbolic raised a $30M Series A1 on 2026-10-27 (partner, not funder) | — | — | — | Low | Mixed (several 429/404) |

### 2b. Prover markets as revenue

All four markets pay for proofs of *their own* zkVM (SP1, RISC Zero, Pico)
or the Lagrange stack. None runs Victor's prover. So this is "rent the GPU",
not "sell our proofs". The laptop's 8 GB RTX 4070 is below Succinct's stated
floor; only the 32 GB RTX 5090 desktop would qualify, and it is meant for our
own benchmarks.

| Market | What a prover needs | How it pays | Earnings evidence | Fit | Verified? |
|---|---|---|---|---|---|
| Succinct Prover Network (SP1) | >=1,000 PROVE staked to bid (may change); GPU >=24 GB VRAM (4090/5090 best), 4+ cores and PCIe x16 per GPU, 32 GB RAM per GPU; slashing for missed deadlines "not currently enabled" | Auctions ("proof contests"), paid in PROVE; delegators share emissions + fees | Docs: the reference prover "is not expected to be competitive for generating significant revenue"; no incentives beyond fees | Low (5090 only; 1,000 PROVE ~ $160-400 at secondary-quoted prices, UNVERIFIED) | Verified (docs.succinct.xyz FAQ) |
| Boundless (RISC Zero) PoVW "ZK mining" | Stake ZKC on Ethereum mainnet; run Bento (no GPU minimum published); collateral to lock requests | 75% of each ~2-day epoch's ZKC emission to miners by proven cycles, 25% to stakers; per-epoch cap = stake/15; year-1 emission 7% (up to 70M ZKC) | Docs give worked examples only, no profitability claim | Low-Medium: an 8 GB card may run small jobs (UNVERIFIED); token-price risk; cap ties income to capital staked | Verified (docs.boundless.network quick-start, mining overview) |
| Brevis ProverNet (Pico) | Register a node with a USDC stake (beta); CPU or GPU | Beta pays USDC on Base; mainnet to move to BREV with staking/slashing | Press release only | Low; one interesting fact: payouts on Base in USDC (no token risk during beta) | UNVERIFIED (press release + secondary; no official docs fetched) |
| Lagrange Prover Network | Stake LA; EigenLayer-restaked operators (85+ institutional names cited) | Auction profits + fixed LA emissions | Secondary projections only | Low (institutional operators) | UNVERIFIED (Binance/CoinDesk research pages) |
| Fermah (universal proof market) | GPU suppliers; claims "any proof system" | Not published | Company claims only; testnet | The only market that might one day route *our* proof type; partner lead, not revenue | UNVERIFIED (company blog/careers pages) |

Out-there variant: register our own Bittensor subnet for private verifiable
inference (validators pay miners to prove with our verifier). Registration
lock cost and current TAO economics UNVERIFIED this session; Subnet 2's exit
on 2026-10-20 leaves the zkML niche on Bittensor empty but is also a signal
that it did not pay.

### 2c. Prizes, bounties, hackathons (Nov 2026 - Jan 2027)

Bottom line: no ZK or verifiable-AI prize with cash is open in this window.

| Name | Amount | Req | Dates / status | Fit | Verified? |
|---|---|---|---|---|---|
| ETHGlobal | Pools not shown | Ethereum; application | Only hackathon listed: **Mumbai, Nov 5-7 2026, in person**; then ETHConf (conference) NYC Jun 14-16 2027. No online/async hackathon listed through mid-2027 | Low (India, 1 week out) | Verified (ethglobal.com/events) |
| ETHDenver 2027 BUIDLathon | Sponsor bounties; no pool published even for 2026 | BUIDLer application | 2027 not on site. 2026 pattern: applications opened Nov 18 2025, selections closed Jan 5, event Feb 18-21. So 2027 applications likely ~mid-Nov 2026 (inference) | Medium-High: US, ZK/AI/Base sponsor bounties typical; event itself falls just after the 3-month window | 2026 Verified (ethdenver.com); 2027 UNVERIFIED |
| Devcon 8 / Devconnect | No bounties | — | Devcon 8 Nov 3-6 2026, Mumbai; no Devconnect 2026 | Low | Verified (per helper) |
| ZPrize | 2023: ~4 x $500k | MSM/NTT acceleration | No round after 2023 | Nil now | Verified (zprize.io) |
| ZK Hack; Succinct / RISC Zero / zkVerify | — | — | No upcoming events; RISC Zero bug bounty only | Low | Verified absence (per helper) |
| XPRIZE | — | — | Open prizes: quantum, water, healthspan, wildfire, carbon, rainforest. Nothing on AI safety / privacy / child safety | Nil | Verified (per helper) |
| NIST / US-UK PETs / Challenge.gov | — | — | Challenge.gov shut 2026-03-30 (moved to usa.gov/challenges, not fetched); PETs prize was 2022-23; no 2026/27 round found | Nil now | Partly verified |
| iDASH 2026 | Not stated | HE / Solidity / MPC tracks, no ZK track | Workshop Nov 7 2026, Dallas; competition done | Low; watch 2027 tracks | Verified (per helper) |
| Zama bounties | 5k cUSDT (S4) | FHE only | Closed | Nil | Verified |
| Encode Club, DoraHacks, Kaggle, AI-safety prizes | — | — | Pages blocked or not found | ? | UNVERIFIED |

### 2d. Crowdfunding and community capital

| Name | Amount | Req | Dates / status | Fit | Verified? |
|---|---|---|---|---|---|
| Reg CF (StartEngine, Wefunder, Republic) | Up to $5M / 12 months | Issuer must be a US-state entity (form the C-corp first). Financials: <=$124k raise = tax-return figures + CEO certification; $124k-$618k = CPA review; >$618k = audit (first-timers may use review up to $1.235M) | StartEngine quotes ~4-6 weeks to launch; Republic/Wefunder pages blocked | Medium-High once incorporated; the Form C is **public**, so the provisional must be filed first | SEC/CFR rules Verified; StartEngine partial; Republic/Wefunder UNVERIFIED |
| Gitcoin GG25 | GG24 was $1.8M over 6 domains incl. Privacy $150k | Open-source public goods | GG24 ended Oct 2025; GG25 mentioned (2026-08-31 governance post) with no dates | Low-Medium: only the open verifier + spec could enter | Verified (no dates) |
| Octant | Epoch 13 "privacy round": 100 ETH QF | Traction required; privacy-critical code open source; KYC/KYB; >$1M raised counts against | E13 closed Sep 10 2026; E14 not announced (~90-day cycle, secondary) | Low-Medium: conflicts with closed prover | Verified (E13) |
| Optimism Retro Funding (post-Season 9) | — | — | Reported paused >=12 months; seasons replaced by continuous voting | Nil in window | Partial (official blog seen only via search excerpt) |
| Giveth QF, Drips, Deep Funding, Protocol Guild | — | — | No active rounds / not eligible | Low | Mostly verified |
| AngelList syndicates (verifiable AI / ZK) | — | — | None verifiable | ? | UNVERIFIED |

## 3. Ranked list for the next 3 months

Common prerequisites, in order: (a) file the provisional patent. World One,
Reg CF and every hackathon demo count as publication, and World One's terms
say TfH may build similar products. (b) Form the Delaware C-corp, which 0G,
Reg CF and probably the Celo contract/KYB need. (c) Make the Base anchor
contract portable to any EVM chain (Celo, 0G). (d) Have a one-page deck and a
2-minute demo video of the private Shieldstral verdict proof.

1. **0G Apollo Cohort 2.** Deadline **Nov 11** (rolling, so earlier is better).
   Up to $2M investment, terms unstated, mostly remote, demo day at Stanford.
   *Pitch:* "0G sells a trust layer for AI; we add a cryptographic proof of which
   model ran on hidden content, with no TEE trust." Store receipts on 0G Storage.
   *Chain:* 0G (EVM), hybrid allowed. *Needs first:* deck, company (likely), and
   an answer to "revenue-generating product" (pilot letters, or frame the
   media-app MVP). Low odds, high value, two weeks of effort at most.
2. **Celo Prezenti S3 Frontier.** Up to $15k in USDm; 20% on contract, 80% on
   milestones over 4 months. *Pitch:* verification and trust for AI agents and
   posts, i.e. an agent's safety verdict carries a private ZK proof. *Chain:*
   Celo mainnet deployment plus ERC-8004 registration plus Self Agent ID plus
   on-chain activity. *Needs first:* port the anchor contract, then KYC and a
   contract. Smallest effort per dollar among the open items.
3. **World One residency (TfH).** $30k over 3 months, SF co-location, up to 5
   solo builders, US work authorisation. *Pitch:* World ID gives "a human
   posted this"; our proof gives "and it passed a safety classifier, content
   unseen". Together that is private, human-verified moderation. TfH also
   owns the ex-Modulus zkML team, so this doubles as a strategic contact.
   *Needs first:* the provisional (applications are not confidential), World ID
   in the app, and willingness to relocate.
4. **ETHDenver 2027 BUIDLathon.** Dates and pool UNVERIFIED; 2026 opened
   applications on Nov 18. *Pitch:* target ZK, AI and Base sponsor bounties with
   the live app. *Needs first:* the provisional before the demo. Watch ethdenver.com
   from mid-November.
5. **Reg CF raise** (StartEngine; Wefunder/Republic UNVERIFIED). Possible in
   Q1 2027 if the C-corp is formed in November. Raises up to $124k need only
   tax-return figures and a CEO certification. *Pitch:* "verifiable private AI
   moderation / child safety" sells to a retail audience. *Needs first:* the
   C-corp, the provisional (Form C is public), and a counsel review.
6. **Solana Foundation grant** (rolling, ~3-week decision) for the open-source
   verifier, spec and benchmarks as a public good. Only if a Solana anchor is
   acceptable; the 471 MB proof means verification stays off-chain.
7. **Watch, no action yet:** Arbitrum Foundation grant programme ("opening
   soon"); Aztec grants (page 404); Gitcoin GG25 and Octant Epoch 14 (both
   need open source, so only the verifier qualifies); the next Colosseum hackathon
   ($250k accelerator gate); iDASH 2027 tracks.
8. **Idle-GPU revenue (optional, low):** Boundless PoVW or Succinct on the 5090,
   only when it is not benchmarking and only through the resource guard. Expect
   cents to a few dollars a day (UNVERIFIED) with token-price risk and a stake
   to buy. Its real value is learning how buyers price proofs.
9. **Relationships, not applications:** Inference Labs (left Bittensor; their
   stack targets small and sliced models), Lagrange (closest competitor;
   defense/Oracle channel), Hyperbolic (raised a $30M Series A1 on 2026-10-27;
   compute partner), Fermah (a universal proof market that might one day route
   our proof type). Possible partners or acquirers later; nobody contacted.

**Skip this window:** Bittensor SN2 (gone), Gensyn, EigenCloud (no open call;
TEE/deterministic-inference stack), Ritual Altar (no cash; Ritual Chain only),
Zama (FHE only), ZPrize, ZK Hack, XPRIZE, PETs/NIST, Optimism Retro, Giveth,
Mina/Scroll/Polygon/ZKsync/NEAR/Sui/Aptos/Sei/Filecoin/Celestia/Story/Akash/
Nillion. Base Batches is covered in wave 1.

## Sources log (official pages fetched 2026-10-28)

- https://github.com/inference-labs-inc/subnet-2 — archived 2026-10-20; "Subnet 2 is now Dani Labs"; miner min 8-core CPU, 32 GB RAM.
- https://danilabs.ai — inference subnet "in development"; no ZK, no grants.
- https://sn2-docs.inferencelabs.com/ — scoring on proof speed/size; "October 15, 2026: Subnet 2 became owned and operated by Danilabs".
- https://inferencelabs.com — products list; no grants/partner programme; page dated 2026-10-20.
- https://world.org/grants — World One residency, $10k/month x 3, up to 5, SF.
- https://world.org/one-terms-and-conditions — effective 2026-09-15; individuals 18+, US work authorisation; materials not confidential; TfH may build similar products.
- https://www.eigenlabs.org/blog/ — 2026 posts on EigenAI deterministic inference, agent events; no open grant/prize call.
- https://apollo.0g.ai — Cohort 2, up to 10 teams, up to $2M per project, closes 2026-11-11, Nov-Feb, Stanford graduation, revenue-stage teams.
- https://forum.celo.org/t/prezenti-grants-season-3-plan/13598 — posted 2026-07-23; Frontier cap $15k; pool $172k; USDm 20/80; Celo mainnet + ERC-8004 + Self Agent ID; KYC.
- https://ethglobal.com/events — Mumbai Nov 5-7 2026 (in person), Pragma Mumbai Nov 6, ETHConf NYC Jun 14-16 2027; no pools shown.
- https://www.ethdenver.com/ — 2026 only (Feb 18-21; applications live Nov 18 2025; selections Jan 5 2026); no prize pools.
- Checked by helper agents (official pages unless marked): colosseum.com/accelerator; solana.org/grants-funding; phala.com/startup-program; arbitrum.foundation/grants; grants.scroll.io; minaprotocol.com/blog/zkignite-update; sui.io/grants-hub; near.org/funding; seifdn.org; datafdn.org; hyperbolic.ai; zprize.io; devcon.org; devconnect.org; zkhack.dev; xprize.org/prizes; challenge.gov; humangenomeprivacy.org/2026; github.com/zama-ai/bounty-program; gitcoin.co/campaigns; gov.gitcoin.co/t/25366; giveth.io/qf; octant.substack.com/p/epoch-13-the-privacy-round; drips.network; deepfunding.org; startengine.com/raise-capital; law.cornell.edu/cfr/text/17/227.100 and 227.201. Blocked (429/403/404, not bypassed): aptosfoundation.org, fil.org, aztec.network/grants, polygon.technology/grants, republic.com, wefunder.com, dorahacks.io, kaggle.com, petsprizechallenges.com, lagrange.dev/blog, docs.brevis.network.
- https://blog.eigenfoundation.org/ — newest post 2025-12-18; 2025 grants 40M EIGEN in seasons.
- https://ritual.net/blog/altar and https://altar.ritual.net/core/about — rolling; must build on Ritual Chain; no cash amounts.
- https://www.zama.org/post/zama-developer-program-mainnet-season-4 — 2026-07-30; 5,000 cUSDT; deadline 2026-09-05; FHE only.
- https://docs.succinct.xyz/docs/provers/setup/faq — 1,000 PROVE; >=24 GB VRAM; "not expected to be competitive".
- https://docs.boundless.network/zkc/quick-start and /zkc/mining/overview — ~2-day epochs; 75/25 split; cap stake/15; 7% year-1.
