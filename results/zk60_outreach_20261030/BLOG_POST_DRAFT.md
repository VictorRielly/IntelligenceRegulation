<!--
DRAFT for Victor. Written 2026-10-30 ~20:28 UTC by a Claude agent. Not sent, not posted.
Fill every <...> before use. Every number below comes from the files in "Sources";
labels: [MEASURED] = a run happened (n = 1 unless stated), [COUNTED] = arithmetic,
[EXTERNAL] = someone else's claim, not checked by us.
Body length: about 1,350 words (excluding this note and the sources).
-->

# Proving what a safety classifier said, without showing what it read

*<AUTHOR_NAME>, <DATE>*

A platform that moderates posts can say "our classifier checked this post and found nothing wrong". Today you have to take its word for it. The open-source prover at <REPO_URL> lets the platform publish a receipt instead. Anyone can check that a specific public model computed a specific verdict on the post, and the receipt does not reveal the post.

The first real post went through our demo app on 2026-10-30. Mistral's open safety classifier, Shieldstral-1.0-3B, judged a short public test post under three policies: sexual content, graphic violence and hate. The three receipts are published, and their fingerprints are anchored on the Base Sepolia test network.

## What it is

The prover makes a zero-knowledge proof of a whole model run. The weights are public. The input, the output and every intermediate value stay hidden from whoever checks the proof. For the classifier, the checker learns the verdict bit (flagged or not), the model by digest, the policy, the post's length in tokens, and a sealed fingerprint of the post that the platform stores with it. The checker does not learn the post's tokens, any activation in the 26 transformer blocks, or the classifier's score.

How it works:

- **Exact integers.** The model is first converted to exact integer arithmetic: 8-bit weights, an integer softmax, and integer norms and activation tables.
- **One proof per run.** A single proof, under one transcript, covers the policy template, the post's tokens, all 26 blocks, the final norm, and the "yes minus no" score compared with the policy's threshold.
- **The proof system** is hash-based, written in Rust over the Goldilocks field: a Ligero-class hiding commitment with salted BLAKE3 Merkle leaves, masked sumchecks (Chiesa–Forbes–Spooner style, as in Libra), and LogUp lookups. There is no trusted setup.
- **Tables from the weights.** The verifier rebuilds every public table from the pinned weights itself.

One limit comes first: **the party that runs the prover sees the content.** In our app, that party is the platform. The proof hides the content from everyone else.

## Why hiding the content matters

- **Moderation.** A platform can show an auditor, a regulator or its users that a named classifier ran on each item, and what it said, without handing over the items. This matters most for private messages and for material nobody should copy.
- **EU DSA and UK OSA.** Both laws push platforms toward documented moderation decisions and age-appropriate distribution. Regulators already accept zero-knowledge proofs for age checks: the developer documentation of the European Commission's age-verification blueprint names them as the preferred way to present one [EXTERNAL]. **No regulator asks for proofs of classifier verdicts today.** We want to test that idea with platforms and auditors.
- **AI insurance.** Insurers such as Armilla say they feed third-party evaluation evidence into underwriting [EXTERNAL]. A proof that a filter really ran on every item is stronger evidence than a vendor's report.

In the demo app, each post is proved once per category, when it is created. The proved labels decide who receives it: for example, explicit content is not sent to minors. A post without an accepted proof is not published.

## What works today

All rows: [MEASURED, n = 1, one laptop (Intel Core Ultra 9 185H, 15 GB RAM), CPU only; research measurements, not benchmarks].

| What was proved | Prove | Verify (fresh process) | Receipt | Soundness | Privacy status |
|---|---|---|---|---|---|
| Shieldstral-1.0-3B verdict, real 17-token post, one proof per category | about 456 s per category, 8 threads | 69–81 s, model load included | 848 MB | 96 bits | **draft, not accepted** |
| TinyLlama-1.1B next token, 32-token hidden prompt | 85.3 s | 10.6 s | 255 MB | 97 bits | **accepted** (D36), named binaries |
| Llama-3-8B next token, 128-token hidden prompt | about 500 s in total | about 57 s | 928 MB | 96 bits | **none** |

On the first post:

- **Proving.** Two categories took 456 s on 8 threads. The first ran on 2 threads and took 1,031 s. Peak memory was 8.0–8.2 GiB.
- **Publication.** All 84 public segments (2.55 GB) were re-hashed, and the three receipts re-verified from the public store, in 79–82 s each.
- **Anchor.** Base Sepolia transaction `0x0f2dc9dd…ad01a`, block 52,075,726.

What "private" means, in numbers:

- **Accepted.** Two statements cover TinyLlama-1.1B at 32 tokens: the 22-layer stack (D33) and the next-token proof (D36). A checker's view is within about 2^-70 per run of a view that does not depend on the hidden values. Both hold in the random-oracle model for BLAKE3, and only for named binaries.
- **Draft.** The classifier statement proposes about 2^-68.2 per proof, and about 2^-66.6 for a three-proof post [COUNTED].
- **Evidence.** Our privacy gate re-derived all 442 public tables of the real classifier proof (118 million entries). It then rebuilt the checker's whole view from all-zero hidden data: 81.7 million entries compared, 0 different [MEASURED].

## What does not work yet

- **The classifier privacy statement is not accepted.** It waits on my acceptance and on a ruling about the policy wording.
- **Private posts cannot go through the app yet.** The app must first show failures only to the authenticated author, and the refusal rate on real content must be measured. Neither is done. The first post was public text.
- **The public facts leak by design.** The verdict and the length are public; for a long post, so is each chunk's verdict. An accepted proof also shows the post fit the integer model's ranges, and whether a post is refused can depend on what it says.
- **Narrow coverage.** Statements cover named binaries only. A binary you build has a different digest, so no statement covers it.
- **No external audit.** The arguments survived review inside the project. No outside cryptographer has checked them, and they are not machine-checked.
- **Soundness** is about 96 bits per run, an accepted deviation from the 128-bit target.
- **Fidelity.** The verdict is the integer model's. Its agreement with the original model on a benchmark: <NUMBER?>.
- **Scope.** CPU only, text only, public weights only.

## How it compares

It is slow, and its proofs are large. Systems with public inputs and outputs are much faster:

- **DeepProve** (Lagrange with university co-authors, IACR ePrint 2026/1112) reports about 86 tokens per minute on GPT-2 and Gemma 3, and 1–3.7 s verification [EXTERNAL].
- **Attestable**, a closed-source vendor, claims 53–77 tokens per second on a 31B model on one H100, with 4–8 MB proofs, and has published no paper [EXTERNAL].

Our private 8B proof runs at about 0.26 prompt tokens per second on a laptop CPU [MEASURED]. We are not competing on speed. What we offer is different: inputs, outputs and every activation are hidden from the verifier, with a written, reviewed privacy argument. <CHECK BEFORE PUBLISHING: we did not find this property in the published descriptions we read; confirm against each system's full paper and documentation before using "only" or "first".> We want hidden inputs to become a standard feature of open proving stacks, and the licence is chosen to make that easy (<LICENCE>).

## Check a receipt yourself

The first post's receipts are at <RELEASE_ASSETS_URL>, with a `SHA256SUMS` file.

1. **Fetch the model.** Get Shieldstral-1.0-3B at revision `003ec7e2` (about 7.7 GB) and check it against the pins in `evidence/zk60_shieldstral_prep_20261021/`. Copy the checkpoint as a regular file to `$ZK60_MODELS/shieldstral-1.0-3b/snapshot-003ec7e2/model.safetensors`. The verifier refuses symlinks, which the Hugging Face cache uses.
2. **Rebuild the integer export** with `tools/model-export/shieldstral-export/`. This is the hard step: the tools are not yet self-contained.
3. **Build:** `cargo build --release --locked --manifest-path hashline/Cargo.toml --example zk60_classify`.
4. **Verify:** `ZK60_MODELS=<your models dir> zk60_classify verify` on a receipt directory. A wrong checkpoint is refused before any table is derived.

## How to help

- **Break the privacy claim:** <CHALLENGE_URL>. We offer public credit, not money.
- **Review the arguments.** The soundness reviews, the privacy statements and the decisions register are in the repository.
- **Make it fast.** The goal is at least 50 proved tokens per second for a private 8B model on one high-end GPU.
- **Upstream it.** If you maintain an open zkML stack, we would like to help add hidden inputs and outputs.
- **Tell us what a receipt must say.** This is for platforms, moderation auditors and AI insurers: <CONTACT>.

<OPTIONAL, Victor's call: "Most of the code and documents were written by AI agents (Claude, Codex) under my direction; every claim here comes from the project's own records.">

---

### Sources (all local files; read 2026-10-30)

- First post, timings, anchor, re-verification: `docs/zkmatrix-poc/MVP_STATUS.md` (entries 2026-10-30 01:54, 05:30, 11:35 UTC); per-category records `results/zk60_astra_20261026/real_app_demo_1/{sexual,violence,hate}.json` (prove 1,031.2 / 456.3 / 457.0 s; verify step 80.8 / 69.3 / 69.2 s; app work 1,300 / 687.5 / 693.5 s); anchor in `results/zk60_astra_20261026/real_app_demo_1/complete.json`.
- What is public and hidden, refusal channel, distances, gate evidence, conditions C-7 / C-8: `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_CLASSIFIER_SHIELDSTRAL_T128_DRAFT_v3.md` §0, §2, §3, §4, §5.
- Accepted statements: `docs/zkmatrix-poc/ZK60_DECISIONS.md` D33, D36; `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_NEXT_TOKEN_TINYLLAMA_T32.md`.
- Product rules (prove once per category at creation, labels for distribution, fail closed, length public): `ZK60_DECISIONS.md` D37, D38, D41, D45; the prover sees the content: D49 and the v3 draft §0.
- Soundness: `ZK60_DECISIONS.md` D27 (about 95 bits whole-run accepted as an MVP deviation; 128 for the product).
- TinyLlama row: `MVP_STATUS.md` entry 2026-10-18 01:42 UTC (measured on rung R2, before the D36 binary was frozen). Llama-3-8B row: `MVP_STATUS.md` entry 2026-10-19 23:25 UTC (b7voc0, 501.6 s, about 57 s, 928 MB, 96 bits; about 0.26 prompt tokens/s).
- Construction: `/home/victor/ir-public/README.md` §1; `/home/victor/ir-public/hashline/README.md`; the module doc of `/home/victor/ir-public/hashline/src/zk.rs`.
- Receipt check steps: `/home/victor/ir-public/README.md` §5; `docs/zkmatrix-poc/ZK60_OPEN_RELEASE_PLAN.md` (status 13:05 and 17:00 UTC).
- DSA / OSA, the age-verification blueprint, Armilla: `results/zk60_funding_20261028/INVESTORS_PUBLICATION.md` §2c; `results/zk60_funding_20261028/wave2/CUSTOMERS_PARTNERS_NICHE.md` §2 [EXTERNAL, researched 2026-10-28].
- DeepProve and Attestable figures: `INVESTORS_PUBLICATION.md` §2b, §2d; `docs/zkmatrix-poc/START_HERE.md` §2 [EXTERNAL]. Attestable is closed source: `ZK60_DECISIONS.md` D51.
- Speed goal: `ZK60_DECISIONS.md` "At a glance" (the 2026-09-26 direction).
