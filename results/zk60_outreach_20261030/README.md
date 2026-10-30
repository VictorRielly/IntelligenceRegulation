# Outreach drafts, 2026-10-30

Written 2026-10-30 from 20:27 to 20:35 UTC by a Claude agent; the challenge page was redesigned at
~20:42 UTC at the coordinator's request. Both rounds of work were done under
D48 (open by default) and D51 (upstream into open stacks only). **Everything here is a draft.
Nothing has been sent, posted, published, registered or emailed.** Victor sends everything under
his own name. No git writes were made, and nothing outside this folder was changed.

## The four drafts

| File | What it is | Length |
|---|---|---|
| `BLOG_POST_DRAFT.md` | A plain-English post for engineers and policy readers. It covers what the prover is, why hiding content matters (moderation, DSA / OSA, AI insurance), what works with numbers, what does not, how it compares, how to check a receipt, and how to help | about 1,360 words |
| `EPRINT_OUTLINE.md` | A title, a 197-word abstract, and an 11-section outline of an IACR ePrint paper with the evidence paths each section cites. It marks every place Victor must write in his own words, and adds a note on disclosing AI use | outline |
| `OUTREACH_EMAILS.md` | Five emails (Lagrange / DeepProve, EZKL, Daniel Kang, Armilla AI, Checkstep), each with a subject, a "why them" line and one ask, at 146–163 words. It ends with "Not contacted, and why" (Attestable) | 5 × ≤ 180 words |
| `CHALLENGE_PAGE_DRAFT.md` | A public "break the privacy claim" page, **redesigned 20:42 UTC** after Victor's objection to guessing games. The primary game is random-secret recovery on D36 receipts: one correct answer is a break, with no statistics. **Updated ~20:48 UTC to D52:** a 4-token win, the reveal approved, an offline-only scope. An optional distinguishing game has a pre-registered test. The page keeps the commit-now-reveal-later design, the scope, the rules and the honest status of the statements. Prerequisites and cost are in a section for Victor at the end. No bounty; credit is public | page |

## Decisions Victor must make (the placeholders)

**Before anything goes out**
1. **Order.** The emails and the blog link to <REPO_URL>, <EPRINT_URL> and <RELEASE_ASSETS_URL>, so
   they should go out after the public repository, the tag and the ePrint exist (release plan
   checklist steps 6–8). Recommended order: repository and ePrint, then the blog, then the emails,
   then the challenge page.
2. **The licence** (<LICENCE>): "MIT OR Apache-2.0" is pending your confirmation (release plan,
   decision 1).
3. **Contact addresses:** <CONTACT>, <SECURITY_CONTACT>, <SIGNATURE>. Also <AUTHOR_NAME> and the
   affiliation for the ePrint.
4. **The classifier statement.** Will you accept draft v3, and with the strict or the moderate
   policy wording? The blog, the abstract and the challenge page treat v3 as **not accepted**.
   Update them if you accept it first (the challenge table has an <UPDATE WHEN VICTOR RULES> slot).
5. **"Only" or "first" wording.** The blog has a <CHECK BEFORE PUBLISHING> marker. Our research
   read abstracts only, and found no other system stating hidden inputs, outputs and activations.
   EZKL in particular may offer input and output visibility settings: that comes from the agent's
   general knowledge, **not** from the project files, and must be checked. Narrow the claim to what
   is measured if needed.
6. **The AI-use sentence.** There is one optional sentence in the blog. The ePrint disclosure is
   required by the venue policies (see the ePrint note).

**Per draft**
- **Blog:** <DATE>; the optional AI sentence; <NUMBER?> for the integer-versus-float verdict
  agreement.
- **ePrint:**
  - the title (three options);
  - every **[VICTOR-WRITES]** block: motivation, contributions, key idea, theorem statement,
    positioning, acknowledgements, and which text was AI-drafted;
  - <TAG>;
  - the bibliography;
  - two <NUMBER?> slots: the fidelity agreement, and the cost of privacy measured as public-IO
    against hidden IO on the same workload.
- **Emails:**
  - the recipient names (<NAME>) and the addresses, none of which are in the files;
  - whether the Kang email mentions the partner role (D47), which is optional;
  - <ONE_PAGER_URL> for Armilla. No one-pager exists in this folder: write one, or drop the line;
  - <DEEPPROVE_REPO_URL>, and a check of DeepProve's code and licence;
  - a check of EZKL's licence and visibility features.
- **Challenge: ruled by Victor as D52** (2026-10-30 20:46 UTC) and applied to the page:
  - **The reveal is approved.** The secrets, salts and input-endpoint openings of the synthetic
    challenge receipts are revealed at the end. This is a scoped exception to D21: no real or user
    content is ever revealed.
  - **The win rule is 4 consecutive tokens, with no global cap.** The chance by blind guessing:
    - per guess, 32,000^-4 = 9.54 × 10^-19, or **at most 1.91 × 10^-18** with the admissibility
      factor of 2;
    - an entrant at the optional 1,000-guess handling limit: at most 1.91 × 10^-15;
    - **10^8 guesses in total: at most 1.91 × 10^-10.** The total would reach 10^-9 only at about
      5.2 × 10^8 guesses.
    - Recovering the next token alone is still not a win.
  - **The scope line replaces safe harbour:** "Attacks are offline analysis of the published
    receipts and files only. Do not attack any live system, service or person."
- **Challenge: still open.**
  1. **M.** D52's text names M = 20 (about 28 min of proving and 5.1 GB); confirm it or change it.
     M does not change the bound.
  2. **The template:** a fixed public template at positions 1–21 (as drafted), or random fill.
  3. **Whether to run the optional distinguishing game**, and its N. K follows: N = 32 needs
     K = 30; N = 64, K = 51; N = 100, K = 74; each at p < 10^-6.
  4. **Whether to use the optional per-entrant handling limit** (1,000 guesses). It is not needed
     for the bound.
  5. The fill-ins: <START_DATE> and <END_DATE>, <ACK_DAYS>, <DISCLOSURE_WINDOW>, <CREDITS_URL>,
     <CHALLENGE_ASSETS_URL>, <GENERATION_SCRIPT_PATH>, <TEMPLATE_IDS> and
     <TINYLLAMA_VERIFY_STEPS>.
  6. Whether to add a D33 receipt set later.
  - **Prerequisites before launch** (D52; P1–P4 in the page's last section):
    - the frozen-r11 D36 binary still proves;
    - the export pins match;
    - **at least 60% of at least 1,000 uniformly random secrets pass the integer range checks**;
    - the 85 s / 255 MB figures are re-measured on that binary;
    - the generation script and the template are published first.

## Facts each draft depends on

| Fact | Value used | Source | Used in |
|---|---|---|---|
| First real post: Shieldstral-1.0-3B, 17 public tokens, three categories, all not flagged | as stated | `docs/zkmatrix-poc/MVP_STATUS.md` 2026-10-30 01:54 UTC | all four |
| Prove per category on 8 threads | about 456 s (violence 456.3 s, hate 457.0 s); the first category ran on 2 threads, 1,031 s | `MVP_STATUS.md` 01:54 UTC; `results/zk60_astra_20261026/real_app_demo_1/{sexual,violence,hate}.json` | all four |
| Receipt; memory; soundness floor | 848 MB (848,412,096 B, 28 segments); 8.0–8.2 GiB; 96 bits | same, plus the classifier v3 draft §1 | all four |
| Verify in a fresh process | 69–81 s per category for the app's verify step (80.8 / 69.3 / 69.2 s). That the step includes the model load is my reading: it matches the earlier post's 68 s with load. Also 36 s (68 s with load) on the earlier 35-token post; 79–82 s re-verifying from the public store | app records; `MVP_STATUS.md` 2026-10-29 08:47 and 2026-10-30 05:30 UTC | blog, ePrint |
| Testnet anchor | Base Sepolia transaction `0x0f2dc9dd777d33a72a5930f169ea5ba49b485fc25010ebdaa0f536bd5a9ad01a`, block 52,075,726; 84 segments, 2.55 GB | `MVP_STATUS.md` 05:30 UTC; `results/zk60_astra_20261026/real_app_demo_1/complete.json` | blog, emails |
| What is public and what is hidden; admissibility; the refusal channel; C-7 and C-8 | as stated | `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_CLASSIFIER_SHIELDSTRAL_T128_DRAFT_v3.md` §0–§6 | all four |
| Classifier distance (draft) | 2^-68.19 per proof; 2^-66.60 for a three-proof post | v3 §2, §4 | blog, ePrint, challenge |
| Gate evidence | 442 / 442 tables, 118 M entries; 81.7 M view entries, 0 different | v3 §3; `MVP_STATUS.md` 2026-10-29 21:37 and 22:50 UTC | blog, ePrint |
| Accepted statements | D33 about 2^-70.4 (L = 22); D36 about 2^-70.35; named binaries, frozen-r11 | `docs/zkmatrix-poc/ZK60_DECISIONS.md` D33, D36 | all four |
| TinyLlama next token | 85.3 s, 10.6 s, 255 MB, 97 bits (rung R2, 2026-10-18, before the D36 binary was frozen) | `MVP_STATUS.md` 2026-10-18 01:42 UTC | blog, ePrint, challenge |
| Llama-3-8B next token, T128 | 501.6 s total, about 57 s, 928 MB, 96 bits; about 0.26 prompt tokens/s; no privacy statement | `MVP_STATUS.md` 2026-10-19 23:25 UTC; D36 "Not covered" | blog, ePrint |
| Soundness policy | about 95 bits whole-run accepted for the MVP; 100 next; 128 for the product | D27 | all |
| D36's public facts and admissibility | T = 32, BOS at position 0, V = 32,000; any id < V is admissible at positions 1–31, checked before the header | `ZK60_PRIVACY_STATEMENT_NEXT_TOKEN_TINYLLAMA_T32.md` §1, §2 ("Admissible") | challenge |
| D36 named binary | `zk60_token_io.r11.release.bin`, SHA-256 `0c9f247c0f91…5c2c6b` (file present; hash re-computed 2026-10-30) | `results/zk60_token_io_r1_20261017/cli/binaries_r11.sha256`; D36 | challenge |
| Challenge guessing bounds (4-token win, D52) | 32,000^-4 = 9.54 × 10^-19 per guess, ≤ 1.91 × 10^-18 with the factor of 2; ≤ 1.91 × 10^-10 over 10^8 guesses; a 10-token secret carries 149.7 bits | computed 2026-10-30; D52 | challenge |
| zkVM route deviations | about 97 bits conjectured (D3); Groth16 trusted setup (D4); these do not apply to the hash-based line | D3, D4 | ePrint |
| Construction names | Goldilocks with F_p[u]/(u^2−7); a Ligero/Brakedown-class PCS; Ligero-ZK pad and mask rows; CFS masking as in Libra; LogUp with committed multiplicities; salted BLAKE3 leaves | `/home/victor/ir-public/hashline/README.md`; `/home/victor/ir-public/hashline/src/zk.rs` module doc | blog, ePrint, emails |
| Receipt-check steps | `ZK60_MODELS`, a regular file, symlinks refused, the export not self-contained | `/home/victor/ir-public/README.md` §5 | blog, ePrint |
| DeepProve, Attestable, zkLLM and other prior art | as stated, all [EXTERNAL] | `results/zk60_funding_20261028/INVESTORS_PUBLICATION.md` §2b, §2d; `START_HERE.md` §2 | blog, ePrint, emails |
| DSA / OSA, the EU blueprint, Armilla, Checkstep, Kang | as stated, all [EXTERNAL, researched 2026-10-28] | `INVESTORS_PUBLICATION.md` §2c; `results/zk60_funding_20261028/wave2/CUSTOMERS_PARTNERS_NICHE.md` | blog, emails |
| Attestable is closed source; upstream only into open stacks | — | D51 (Victor: "As far as I'm aware…"); D48 | emails, blog |
| IACR AI policy | ePrint: none stated; Eurocrypt 2027: follows ACM (no AI authors; disclose generative use; not "primarily" AI-generated) | online, read 2026-10-30 (URLs in `EPRINT_OUTLINE.md`) | ePrint |

## Facts I could not confirm (left as placeholders or flags)

- **"About 452–456 s":** no 452 s figure appears in the files. The first post's records give 456.3 s
  and 457.0 s, which `MVP_STATUS.md` rounds to 456 s. The earlier 35-token post was 439–456 s
  across its three categories (v3 §3, Step 1). The drafts say "about 456 s".
- **Verify time for the 17-token post without the model load:** not in the files. The 36 s figure
  is from the 35-token post.
- **Agreement between the integer and float Shieldstral verdicts** on the 4,872-item benchmark:
  not reported (`MVP_STATUS.md` still lists the "benchmark verdict metrics" as open). Marked
  <NUMBER?>.
- **The refusal rate on real content:** not measured (condition C-8).
- **The cost of privacy for the current construction** (public IO against hidden IO on the same
  workload): not found. The older lane AD figure (+4.7%) comes from the legacy `--zk` mode, which
  was later found to disclose values. The ePrint outline says not to use it.
- **DeepProve's public code and licence, and EZKL's licence:** the brief and D51 call both open,
  but the files do not give a repository or licence. Also unconfirmed: what DeepProve hides (only
  its abstract was read), and which visibility options EZKL offers.
- **Whether Daniel Kang is a DeepProve co-author** (DeepProve lists UIUC co-authors): not in the
  files. Check before sending both the Lagrange and the Kang emails.
- **Recipient names and contact routes:** only the partner-form URLs are in the research notes.
- **Attestable's closed source** rests on Victor's own statement (D51), not on a checked source.
- **Whether D33 and D36 cover the release reference (round 19b):** they do not. They name
  frozen-r11 binaries. The challenge receipts must be made with the named binary `0c9f247c…`
  (D36). **Confirmed** that it is present at `results/zk60_token_io_r1_20261017/cli/zk60_token_io.r11.release.bin`
  with a matching SHA-256. **Not confirmed** that it still runs and proves on today's tree.
- **The refusal rate of uniformly random TinyLlama prompts** in the challenge layout: not in the
  files, and unmeasured. The challenge's factor-of-2 bound assumes an acceptance rate of at least
  1/2 (prerequisite P3).
- **Receipt size and timing on `0c9f247c…`:** the 85.3 s and 255 MB figures were measured on rung R2
  (2026-10-18), before the D36 binary was frozen. Confirm them with the first challenge receipt.
- **The size of a TinyLlama input-endpoint opening** (published at the reveal): not in the files.
- **The IACR-wide AI policy,** and the policies of CRYPTO, Asiacrypt, TCHES and CCS 2027: not
  found. Only the ePrint pages (no policy) and the Eurocrypt 2027 policy page were read.

## Sources read

- `docs/zkmatrix-poc/START_HERE.md`
- `docs/zkmatrix-poc/MVP_STATUS.md`, the top blocks through 2026-10-18
- `docs/zkmatrix-poc/ZK60_PRIVACY_REQUIREMENTS.md`
- `docs/zkmatrix-poc/ZK60_DECISIONS.md`: the at-a-glance table, D1–D5, and the token round 18–19b
  and gate round 23–24 entries
- `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_CLASSIFIER_SHIELDSTRAL_T128_DRAFT_v3.md`, in full
- `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_NEXT_TOKEN_TINYLLAMA_T32.md`, the header and the NL-1
  part
- `docs/zkmatrix-poc/ZK60_OPEN_RELEASE_PLAN.md`
- `/home/victor/ir-public/README.md`, `/home/victor/ir-public/hashline/README.md`, and the
  `/home/victor/ir-public/hashline/src/zk.rs` module doc
- `results/zk60_funding_20261028/INVESTORS_PUBLICATION.md`
- `results/zk60_funding_20261028/wave2/CUSTOMERS_PARTNERS_NICHE.md`
- `results/zk60_astra_20261026/real_app_demo_1/{sexual,violence,hate}.json`; the anchor
  transaction in `complete.json`
- Online, 2026-10-30: https://eprint.iacr.org/about.html ,
  https://eprint.iacr.org/operations.html , https://eurocrypt.iacr.org/2027/aipolicy.php

**Coordinator note, 2026-10-30 21:15 UTC:** the gap study found that DeepProve's code is under the restrictive "Lagrange License" (`results/zk60_deepprove_gap_20261030/GAP_ANALYSIS.md` §0). Reword the Lagrange email before sending: a joint paper or research collaboration, not "upstream into DeepProve as an open feature". EZKL and academic groups are the open-source routes (D51). All drafts wait for the GPU version (D53).
