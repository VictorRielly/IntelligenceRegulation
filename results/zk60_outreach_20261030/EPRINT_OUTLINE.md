# IACR ePrint paper: outline (draft for Victor)

Written 2026-10-30 ~20:31 UTC by a Claude agent. **An outline, not a paper. Nothing has been
submitted.** D43(b) asks for a paper with the demo, and D48 says nothing waits on a patent. The
release plan suggests posting the ePrint on the same day as the public repository
(`docs/zkmatrix-poc/ZK60_OPEN_RELEASE_PLAN.md`, "Decisions for you", item 2).

**Markers.**
- **[VICTOR-WRITES]** marks a place where the core idea must be stated in Victor's own words: the
  motivation, the contribution claims, the key insight of the construction, the theorem statement
  and the discussion. These are the parts a reviewer reads as the author's.
- **[EVIDENCE]** lists the files a section cites. Paths are relative to the repository root unless
  absolute.
- `<...>` is a placeholder. `<NUMBER?>` is a figure not found in the files.

---

## Title (pick one)

1. **Zero-Knowledge Proofs of Transformer Inference with Hidden Inputs, Outputs and Activations: A
   Safety-Classifier Verdict on a Laptop**
2. Proving What a Safety Classifier Said Without Revealing What It Read
3. Private-IO Proofs of LLM Inference: Construction, Privacy Argument and Measurements

## Abstract (draft, 197 words)

> Zero-knowledge proofs of machine-learning inference usually make the input and output public and
> hide, at most, the model. We present an open-source prover for transformer inference with public
> weights that hides the input, the output and every intermediate activation from the verifier. The
> model is calibrated to exact integer arithmetic. One proof covers a whole run, from token lookup
> to final decision, under one Fiat–Shamir transcript. The proof
> system is transparent and hash-based over the Goldilocks field: a Ligero-class hiding commitment
> with salted leaves, sumchecks masked in the style of Chiesa, Forbes and Spooner, and LogUp
> lookups. We state privacy as a statistical distance in the random-oracle model, and support each
> step of the argument with an executable gate and independent review. On a laptop CPU we prove a
> verdict of Mistral's Shieldstral-1.0-3B safety classifier on a hidden post in about 456 s, with
> an 848 MB receipt and a 96-bit soundness floor. We also prove a TinyLlama-1.1B next token in 85 s
> (accepted privacy distance about 2^-70 per run) and a Llama-3-8B next token. Our proofs are slower
> and larger than public-IO systems. We report measured costs and limits, including what public
> facts and refusals reveal.

<VICTOR-WRITES: check every number in this abstract against section 7 at submission time. The
classifier privacy figure stays out of the abstract until the v3 statement is accepted.>

---

## 1. Introduction

- The problem in one paragraph: a platform, auditor or regulator wants evidence that an approved
  model ran on content that must not be shown. **[VICTOR-WRITES]**
- Why public-IO proofs do not solve it: the content is the input.
- **Contributions** (3–5 bullets). **[VICTOR-WRITES]** Candidates:
  - a whole-run construction (input endpoint through the decision) with hidden IO and activations;
  - a privacy method combining a statement with stated residuals, an executable gate and
    independent review;
  - measurements at 1.1B, 3B and 8B on a laptop CPU;
  - an application: proved moderation labels anchored on a public chain;
  - an open-source release.
- An honest positioning sentence: slower and larger than public-IO provers, with a different
  property.
- **[EVIDENCE]** `docs/zkmatrix-poc/ZK60_PRIVACY_REQUIREMENTS.md`; `docs/zkmatrix-poc/ZK60_DECISIONS.md`
  D1, D37, D38; `docs/zkmatrix-poc/START_HERE.md` §1.

## 2. Problem and threat model

- **Parties:**
  - the prover (in the app, the platform; **it sees the content**);
  - the input owner (holds the opening of the sealed input fingerprint);
  - the verifier (gets the receipt and the public facts);
  - for soundness, a malicious prover.
- **Privacy goal P1:** inputs, outputs and intermediate values are hidden; the weights may be
  public. P3 (hidden weights) is future work.
- **Public facts in the classifier profile:**
  - the verdict bit, the model by digest, the policy, the length n;
  - the chunk facts, the input-endpoint root, the profiles;
  - **admissibility**: an accepted proof shows the item passed the integer ranges.
- **The privacy adversary:** a verifier holding the receipt and the public facts, without the
  opening, making at most 2^128 hash queries, in the random-oracle model for BLAKE3 with the keyed
  domains (D19, D19a, D19b).
- **Out of scope:**
  - timing, memory and power (D20);
  - what the prover host sees;
  - what an opening holder learns.
- **Operating rules that are part of the model:**
  - rejected receipts are never transmitted (D21);
  - an accepted receipt's endpoint roots are never used by a later proof (D23, as amended by
    D45(3));
  - fail closed (D45(4)).
- **The refusal side channel:** whether a run is refused before its header depends on the content.
  It is stated, not hidden.
- **[EVIDENCE]**
  - `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_CLASSIFIER_SHIELDSTRAL_T128_DRAFT_v3.md` §0, §1, §2, §6;
  - `ZK60_DECISIONS.md` D1, D18, D19, D19a, D19b, D20, D21, D23, D40, D45, D49.

## 3. The exact integer statement

- **Calibration:** int8 weights with per-channel multipliers, an integer softmax with exp tables
  and an exact division, RMSNorm with integer square-root witnesses, SiLU lookup tables, RoPE
  (including YaRN for Shieldstral), and the residual stream at 16 or 24 bits. **Exactness**: the
  proof is about the integer computation, bit for bit, the same on any hardware.
- **Fidelity is a separate question:**
  - the target is D32 (perplexity ≤ 1.02× float, zero refusals, as amended);
  - measured stacks: 8B LOW + 24-bit h, perplexity 1.011× / 1.009×;
  - the Shieldstral integer-versus-float verdict agreement on the benchmark: **<NUMBER?>**, not
    reported yet.
- **The classifier decision:** the yes-logit minus the no-logit exceeds a public threshold c,
  computed from two rows of the tied head (D38(b)), with c = 0.
- **[EVIDENCE]**
  - `START_HERE.md` §1, §4;
  - `docs/zkmatrix-poc/ATTENTION_INTEGER_SPEC.md`;
  - `ZK60_DECISIONS.md` D24, D30, D32, D38;
  - `results/zk60_fidelity_parity_20261019/REPORT.md`;
  - `results/zk60_shieldstral_export_20261026/native_low_h24_t128/` (profile `2ba468f9…`);
  - `MVP_STATUS.md` (2026-10-26 18:05 and 2026-10-28 entries).

## 4. The construction (high level)

**[VICTOR-WRITES]** the key idea in one paragraph: why this combination hides every activation
while the verifier still checks every relation.

- **Field and commitment:**
  - Goldilocks p = 2^64 − 2^32 + 1, with the extension F_p[u]/(u^2 − 7) for challenges;
  - a Ligero/Brakedown-class multilinear polynomial commitment: rows Reed–Solomon encoded on a
    coset (rate about 1/4), BLAKE3 Merkle trees over columns, Q = 256 column checks.
- **Hiding the commitment (Ligero-ZK):**
  - pad rows (f = f_data + Z_n·g_pad), so any Q opened columns are jointly uniform;
  - mask rows tied to the sumchecks;
  - a zero-sum blinding row for the sum group;
  - salted leaves: leaf = BLAKE3(BLAKE3(column) ‖ salt).
- **Relations:**
  - matrix-multiplication sumchecks;
  - zero-check sumchecks for the Hadamard and requantisation identities;
  - LogUp lookups with committed multiplicities and helper columns, for the SiLU, exp, range and
    requantisation facts.
- **Masked sumchecks:**
  - Chiesa–Forbes–Spooner masking polynomials as in Libra, with an extra coefficient so that both
    the mask's total and its terminal value are uniform;
  - a last-round extension that masks every private terminal value;
  - the masks committed per layer and opened with Ligero's product-form linear test.
- **Composition:**
  - one proof and one transcript per run (D12, D12a);
  - one prover-generated boundary commitment between adjacent blocks, opened exactly once;
  - no commitment opened twice.
- **Endpoints:**
  - the input token endpoint is a hiding commitment sealed by the prover (D18), with its own
    geometry (D26);
  - the classifier has one endpoint and no output endpoint, with the verdict as a public bit in
    the transcript header (D40).
- **The verifier derives its tables:** the margin row, the embedding and every block table are
  rebuilt from the pinned checkpoint and profile, never read from a file (R-C2; v3 condition C-6).
- **Optional details, if space allows:**
  - the division dictionary DD (D30), not used by the classifier profile;
  - keyed BLAKE3 domains (D19a);
  - the run statement, written only after the run has verified (D12b).
- **[EVIDENCE]**
  - `/home/victor/ir-public/hashline/README.md`;
  - the module doc of `/home/victor/ir-public/hashline/src/zk.rs` (items (a)–(e));
  - `ZK60_DECISIONS.md` D12, D12a, D12b, D17, D18, D19a, D26, D30, D40;
  - `results/zk60_token_io_r1_20261017/classifier/DESIGN_CLASSIFIER.md` (v2.7) and its check
    `.../classifier/check/CHECK.md`;
  - v3 §1 (the geometry table).

## 5. Soundness accounting

- **Whole-run figures, never per-opening ones** (D15): about 106 bits per opening; the whole run
  is the union bound.
- **D27:** about 95 bits per run at the named workload is accepted as an MVP deviation. The next
  milestone is 100 bits, and 128 is the product target. Security tiers are profile parameters.
- **Measured floors:** Shieldstral T128 has a 96-bit floor (97.3 bits per R13); TinyLlama has 97;
  Llama-3-8B T128 has 96.
- **Independent soundness reviews:** R12b, R13 (accepted on soundness), the token rounds R13–R19b,
  and the forgery attempts they refused.
- **The zkVM route** (section 9) has its own accepted deviations: about 97 bits conjectured (D3)
  and a Groth16 trusted setup (D4). They do **not** apply to the hash-based line, which is
  transparent.
- **[EVIDENCE]**
  - `ZK60_DECISIONS.md` D3, D4, D15, D27;
  - `results/zk60_d24_review_20261017/REVIEW_R13.md`;
  - `results/zk60_token_io_review_r1_20261017/REVIEW_R13.md` … `REVIEW_R19B.md`;
  - `MVP_STATUS.md` (2026-10-29 07:21 UTC entry).

## 6. The privacy statement method

**[VICTOR-WRITES]** the theorem statement in his own words, built from the D36 sentence and the v3
sentence.

- **The form of a statement:**
  - one sentence with a per-run distance;
  - the public facts, the hypotheses and the named binaries;
  - conditions, operating rules, lapse triggers, and what must not be claimed.
- **Accepted statements:**
  - D22, the toy profile, about 2^-77.7;
  - D33, the TinyLlama stack: 2^-74.8 / 2^-73.8 / 2^-70.4 at L = 1 / 2 / 22;
  - D36, the TinyLlama next token: 2^-74.43 / 2^-73.62 / 2^-70.35.
- **The draft:** classifier v3, 2^-68.19 per run; 2^-66.60 for J = 3 and 2^-63.73 for J = 22.
- **The argument in five steps** (as in D33, D36 and v3):
  1. a reference item proves and verifies;
  2. **G-R1, the rank lemma:** the linear view of each commitment discloses nothing (disclosed
     dimension 0 on A, boundary and endpoint commitments; exactly 2 on H, the public LogUp
     zero-sum relation);
  3. **the zero-data preimage:** the gate constructs blinding that reproduces the verifier's
     whole view from all-zero hidden data;
  4. **the joint law** (Theorem B), a reduction conditional on:
     - **G-R2, NL-1:** a slot-by-slot check of the masked polynomials. S1: every monomial has a
       public factor, and degrees and masks fit. S3: Fact 2.1 is tight. S4: miniature masked runs
       accept and terminal maps are onto. S5: failing-first controls, which strip a public factor
       or remove a degree, must fire;
     - **the terminal surjection, with control TS-1:** with one claim's reserved pair removed,
       the group must disclose (on a real block, 0 → 32,768 field elements). This shows the check
       is not vacuous. A claim census finds no identical claims and no equal published values;
     - **G-R4, the draws by value:** a seeded replay rebuilds every root in the predicted order,
       and the counting function matches by value;
  5. **G-R5:** the hash layer adds nothing (the hash-input census; every transcript call keyed).
- **Residuals, counted:**
  - the sampler bias dominates (draws × 2^-96);
  - the input-dependent refusal is priced as a two-world distance (D34, D40; 2^-108.25 at R13);
  - salt guessing, transcript pre-query and collision terms.
- **Process:**
  - a gate lane drafts and measures;
  - independent privacy-review rounds attack each step;
  - the security owner reads the conditions;
  - Victor accepts.
  Say plainly: **not machine-checked and not externally audited**. Each step "survived independent
  attack"; none is a proof re-derived by the security owner.
- **Example of a closed review finding**, worth one paragraph: v1 assumed NL-1 on the redefined
  slots by analogy. The review blocked that (P-1, P-2), and round 22 measured it.
- **[EVIDENCE]**
  - the statements `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md`,
    `ZK60_PRIVACY_STATEMENT_TRAINED_TINYLLAMA_T32.md`,
    `ZK60_PRIVACY_STATEMENT_NEXT_TOKEN_TINYLLAMA_T32.md`, and v3 §2–§5, §12;
  - the gate evidence `results/zk60_gate_tinyllama_20261017/` (rounds 19–24; `round23/R23_SUMMARY.md`,
    `round24/R24_SUMMARY.md`);
  - the reviews `results/zk60_privacy_review_20261029/` (`CLASSIFIER_T128_PRIVACY_REVIEW.md`,
    `CLASSIFIER_T128_PRIVACY_REREVIEW_v2.md`, `CLASSIFIER_T128_V3_CHECK.md`) and
    `results/zk60_privacy_review_trained_t32_20261017/`;
  - the gate tools `ops/zkp-mvp/gate-tinyllama/frozen_v24/` (public as `privacy-gate/`);
  - `ZK60_DECISIONS.md` D22, D33, D34, D35, D36, and the gate round 23 / 24 entries.

## 7. Implementation and measured results

All [MEASURED, n = 1] on one laptop (Intel Core Ultra 9 185H, 15 GB RAM), CPU, unless marked.

| Workload | Prove | Verify | Receipt | Floor | Privacy |
|---|---|---|---|---|---|
| Shieldstral-1.0-3B, 17-token post, per category (8 threads) | 456.3 / 457.0 s | 69–81 s (app step, model load included) | 848,412,096 B (28 segments) | 96 | draft v3 |
| Shieldstral, 35-token post (token round 16) | 439–456 s | 36 s (68 s with load) | 848 MB | 96 | draft v3 (evidence capture) |
| TinyLlama-1.1B next token, T32 | 85.3 s | 10.6 s | 255,258,816 B | 97 | D36 (named binaries) |
| Llama-3-8B next token, T128 (b7voc0) | 501.6 s total | about 57 s | 928 MB | 96 | none |
| Llama-3-8B next token, T32 | 191.7 s | 43.4 s | 471,285,072 B | 97 | none |

Also report:

- **Peak memory:** 8.0–8.2 GiB (Shieldstral).
- **Publication:** 84 segments (2.55 GB) re-verified from the public store in 79–82 s; the Base
  Sepolia anchor.
- **The one-load batch** (token round 18): 1,418 s against 1,453 s, so the gain is a single model
  load. Byte-identical across 30 files.
- **The privacy gate's own runs:**
  - round 20: 14,605 s, 6.47 GiB;
  - C-9 on a real block: 14,718 s;
  - NL-1 on all 26 blocks: 731 s.
- **The cost of privacy** for the current construction (the same workload proved with public IO
  and with hidden IO): **<NUMBER?>**, not found in the files read. **Do not use** the older lane AD
  figure (+4.7% prover time on one Mistral-7B FFN layer, `START_HERE.md` §3.1). It was measured on
  the legacy `--zk` mode, which was later shown to disclose private values (`START_HERE.md`,
  "Privacy correction, 2026-09-08"). A matched public-IO versus private run would close this gap.
- **The gap to plain inference** (8B): about 100× at 32 tokens and 77× at 128 (2026-10-19
  baseline).
- **Tokens per second:** about 0.26 prompt tokens/s for 8B at T128.
- **GPU:** no accepted private-proof GPU result. Do not report GPU privacy.

**[EVIDENCE]**
- `MVP_STATUS.md` (entries 2026-10-18 01:42, 2026-10-19 10:20 and 23:25, 2026-10-29 08:47,
  2026-10-30 01:54 / 05:30 / 11:35 UTC);
- `results/zk60_astra_20261026/real_app_demo_1/*.json`;
- `results/zk60_token_io_r1_20261017/runs/r2/ho00/`, `.../runs/r3/trained-ho00/`;
- `results/zk60_cpu_inference_baseline_20261019/README.md`;
- `START_HERE.md` §3.1 (lane AD);
- `ZK60_DECISIONS.md` (token round 18 entry).

## 8. Limits (a section of its own; keep it prominent)

- The prover host sees the content. P1 hides it from verifiers only (D49 note).
- The public facts carry information: the verdict bits, the length, the per-chunk bits, and an
  end-aligned overlap that can localise a decisive token. At n = 1, the public facts place the
  token in one of at most 8 verdict patterns.
- Admissibility and the refusal channel. "Could not be verified" depends on the content, and the
  real-content refusal rate is **not measured** (C-8). The app does not yet limit failure display
  to the author (C-7).
- A post of J proofs is J times the per-proof distance.
- Statements cover named binaries only. `prove-batch` and r18 and later are not covered by v3
  until named. D33 and D36 are recorded up to frozen-r11.
- Real-shape gating covers only n = 35, not flagged, under the hate and sexual policies.
- Not externally audited, and not machine-checked.
- Soundness of about 95–96 bits per run is an accepted deviation.
- CPU only, text only (images are D39's scope, not built), and public weights.
- Timing side channels are out of scope (the app publishes the proving time).
- The app's own salted SHA-256 commitment hides the text only while its salt stays secret.
- **[EVIDENCE]** v3 §0, §1 "Not in scope", §6, §8; `ZK60_DECISIONS.md` D20, D27, D33, D36, D39,
  D49.

## 9. Related work

- **zkLLM** (Sun, Li, Zhang; CCS 2024): a 13B model with full inference under 15 min and a proof
  under 200 kB. It hides the **model parameters**. Contrast: P3 is our future work; our P1 hides
  the IO.
- **zkGPT** (USENIX Security 2025): GPT-2 in under 25 s.
- **DeepProve** (Lagrange, with UIUC, HKUST and Yale; ePrint 2026/1112; CCS 2026 minor revision):
  GPT-2 and Gemma 3, about 86 tokens/min, 1,855 tokens/min distributed, 1–3.7 s verification.
  <CONFIRM in the full paper: what it hides, and its repository and licence.>
- **zkAgent** (ePrint 2026/199), **OpenLLM** (ePrint 2026/1578), and "**The Cost of
  Intelligence**" (ePrint 2026/1063), a benchmark across proof systems.
- **EZKL:** a tool, no venue found; audited by Trail of Bits in 2025. <CONFIRM its visibility
  options for inputs, outputs and parameters before comparing.>
- **Attestable:** vendor claims only (53–77 tokens/s on Gemma 4 31B on one H100, 4–8 MB proofs,
  sub-second verification; no paper, no input-privacy claim found). Cite as a claim, not a result.
- **zkVM routes:** RISC Zero (used here for a tiny private block: a 785-byte Groth16 receipt, D2–D5)
  and Jolt. Re-executing an 8B model is on the order of 10^13 cycles (D2), so a zkVM is an
  intermediate, not the throughput route.
- **The proof-system building blocks:** Ligero, Brakedown, Libra and the Chiesa–Forbes–Spooner ZK
  sumcheck, and LogUp. <CITATIONS: add the exact bibliography.>
- Our research note found that no abstract it read states hidden inputs, outputs and activations.
  **Check every full paper before any claim of being first.** [VICTOR-WRITES the positioning
  paragraph.]
- **[EVIDENCE]**
  - `results/zk60_funding_20261028/INVESTORS_PUBLICATION.md` §2b, §2d (with the URLs);
  - `START_HERE.md` §2, §6;
  - `ZK60_DECISIONS.md` D2, D3, D4, D51.

## 10. Future work

- **Speed:**
  - the goal is ≥ 50 proved tokens/s for a private 8B model on one high-end GPU;
  - the GPU path;
  - split-width (R14) cut proving by 28.8% on a 2-block comparison [MEASURED, n = 1, not frozen
    or reviewed];
  - DeepProve techniques (D50 gap study, commissioned).
- **P3:** hidden weights, with authenticated private-model identity.
- **Variants:** hidden length (D45(1), D26), sealing the input in advance (D18 option B), and
  images (D39).
- **Soundness:** 100 and then 128 bits (D27), with selectable security tiers.
- **Assurance:** an external audit, and machine-checked proofs of the steps.
- **[EVIDENCE]** `ZK60_DECISIONS.md` "At a glance", D18, D26, D27, D39, D45, D50; `MVP_STATUS.md`
  (2026-10-29 15:13 UTC entry, the speed item).

## 11. Artifact

- Repository: <REPO_URL>, tag <TAG>, licence <LICENCE>.
- The reference prover is token round 19b (manifest list `cfae2d1e…`); the privacy gate is v24
  (`b0532c6e…`).
- The receipts of the first post: <RELEASE_ASSETS_URL>, with `SHA256SUMS`.
- The reproduction steps from the README §4–§5. State the limits: a self-built binary is not a
  named binary, and the export tools are not self-contained.
- **[EVIDENCE]** `/home/victor/ir-public/README.md`; `ZK60_OPEN_RELEASE_PLAN.md` (status
  17:00 UTC).

## Acknowledgements and AI-use disclosure

<VICTOR-WRITES the acknowledgements.>

**What the venues say** (checked online 2026-10-30):

- **IACR ePrint.** Its "about" and "operations" pages state **no policy on AI or generative tools**.
  They do say that authors are "solely responsible for the content and the correctness of the
  published work". The acceptance criteria also require "proofs or convincing arguments", a
  self-contained text, and a first page with the authors' names and a contact.
- **Eurocrypt 2027** (an IACR conference) has an AI-tool policy that "generally follow[s] the ACM
  Policy". Its points:
  - an AI tool cannot be an author;
  - generative use must be disclosed in the acknowledgements or prominently in the work, in
    proportion to the content generated;
  - whole generated sections go in an appendix or supplement, naming the tools, versions, prompts
    and post-editing;
  - editing-only use needs no disclosure;
  - the work must not be "primarily the result of the tool's generative capabilities".
- **Not found:** an IACR-wide policy, or policies for CRYPTO, Asiacrypt or TCHES. CCS is an ACM
  conference, so the ACM policy is the relevant one there. <CONFIRM on the CCS 2027 CFP when it is
  posted.>

**Suggested disclosure** (for Victor to adapt):

> Much of the implementation, the test suites and the review documents were produced by AI agents
> (Anthropic Claude, OpenAI Codex models) working under the author's direction. The author is
> responsible for every claim. <VICTOR-WRITES: which parts of this paper's text were AI-drafted,
> and how they were checked.>

**A flag for Victor:** the "primarily the result of the tool's generative capabilities" clause
matters for a peer-reviewed version. The research contribution, the theorem statements and the
paper's argument should visibly be his own. The **[VICTOR-WRITES]** markers above are placed for
that reason.

### Sources

- Every **[EVIDENCE]** path above.
- Online, read 2026-10-30: https://eprint.iacr.org/about.html ; https://eprint.iacr.org/operations.html ;
  https://eurocrypt.iacr.org/2027/aipolicy.php
