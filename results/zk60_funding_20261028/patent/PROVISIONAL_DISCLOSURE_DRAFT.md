# TECHNICAL DISCLOSURE — DRAFT FOR A US PROVISIONAL PATENT APPLICATION

**Draft for patent-attorney review — not legal advice.**
**CONFIDENTIAL — inventor's working draft. Do not post, upload, email or publish.**

Prepared 2026-10-28 from the IntelligenceRegulation repository (inventor: Victor Rielly).
Drafted by Claude (an AI assistant) from the repository's own records, for Victor
and his attorney.

## 0. How to read this draft

**Purpose.** Victor ruled on 2026-10-28 (decision D43 in
`docs/zkmatrix-poc/ZK60_DECISIONS.md`) that a US provisional patent application
is filed **before** anything about this technology is published (preprint,
open-source release, public grant page). This file is the technical disclosure
for that filing. It is written for a patent attorney, or for Victor if he files
it himself in USPTO Patent Center. It is a draft for attorney review. It is not
legal advice. Nothing here says that any aspect is novel, non-obvious or
patent-eligible; that is the attorney's assessment after a prior-art search.

**What it covers.** A system that produces a zero-knowledge proof that a named,
integer-calibrated transformer language model (or a classifier built on one)
was run on a hidden input. The input, the output and every intermediate
activation stay hidden. The model weights may be public (privacy scope "P1",
D1). A later variant ("P3") also hides the weights. The draft also covers the
application built on top: proof-carrying content labels that decide who
receives a piece of content.

**Status labels used throughout** (the repository's own convention):

| Label | Meaning |
|---|---|
| **BUILT** | Implemented in the repository's Rust prover/verifier (or the app), with tests that pass. Built is not the same as reviewed or accepted. |
| **BUILT, REVIEWED** | Built, and accepted on soundness by an independent review round recorded in the repository. |
| **BUILT, PRIVACY ACCEPTED** | Built, and covered by a privacy statement that Victor accepted (D22, D33, D36). |
| **IN PROGRESS** | Code exists but is not frozen or reviewed as of 2026-10-28. |
| **DESIGN ONLY** | Written and costed (sometimes adversarially checked) but not implemented. |
| [MEASURED] | A run happened. Unless noted: one laptop (WSL2, about 15 GiB RAM, CPU path), shared with other jobs, one run (n = 1). |
| [COUNTED] | Derived exactly from the code's layout or arithmetic, not timed. |
| [MODEL] | An estimate with stated assumptions. |

**Accuracy rule.** Every technical statement below is taken from the
repository's code, ledgers, design notes or the decisions register. File paths
are given so the attorney (or an expert) can check them. Where the repository
records an item as unfinished or only designed, this draft says so. Including
design-only variants is deliberate: a provisional application supports later
claims only to the extent its text describes them.

**Confidentiality.** This draft describes unpublished work. Keep it out of
email, cloud documents, chat tools and public repositories until the attorney
decides how to handle it.

## 1. Title, field and background

### 1.1 Proposed title (working)

*Zero-knowledge proofs of private, integer-exact transformer inference with
masked single-opening commitments, per-row division dictionaries and public
classifier verdicts, and proof-carrying content labels that gate distribution.*

Shorter alternatives: "Private verifiable AI inference"; "Zero-knowledge proof
of a hidden-input transformer computation and its use for content labelling."

### 1.2 Field

Cryptography, specifically succinct non-interactive arguments of knowledge with
zero knowledge, applied to machine learning inference (transformer neural
networks, large language models, safety classifiers). Also content moderation
and distribution systems that rely on verifiable classification, and
publication/anchoring of proofs on persistent stores and blockchains.

### 1.3 The problem

An AI service often has to show a third party that a specific, approved model
produced a specific decision, for example that a post was classified as "not
explicit" by an approved safety classifier, or that an answer was the model's
own next token. Today the third party must either trust the service's word, or
be given the data (the post, the prompt, the answer), which defeats privacy.
The goal is a proof that:

1. names the model exactly (by digests of its integer weights and calibration);
2. shows that the model's exact integer computation ran, bit for bit, on some
   input;
3. reveals nothing else about the input, the output or any intermediate value,
   except what the application deliberately makes public (for example a single
   verdict bit);
4. can be checked by anyone with a small, deterministic verifier, and
   rejects tampered proofs.

### 1.4 Limits of existing approaches (as recorded in the repository's own literature notes)

The repository has not done a formal patentability search. The notes below are
what its own literature reviews record; the attorney should commission a proper
search.

- **General-purpose zkVMs.** The project ran one tiny complete transformer
  block (about 10^5 multiply-accumulates) inside the RISC Zero v3 zkVM: the
  inner STARK proof took **3,743 s** on the laptop CPU, then a Groth16 wrap gave
  a 785-byte receipt [MEASURED, `docs/zkmatrix-poc/MVP_STATUS.md`]. The 8B
  model's feed-forward pass alone is about 2.9 × 10^12 multiply-accumulates,
  so a zkVM is not a route to model-scale proofs. That line also rests on about
  97 bits of conjectured soundness and a Groth16 trusted setup (D3, D4).
- **Prior ZKML systems** named in the repository notes
  (`docs/zkmatrix-poc/AGGREGATION_LITERATURE.md`, `PROVING_CHANNEL_OPTIONS.md`,
  `M4_LOOKUP_LITERATURE.md`, `results/zk60_token_io_design_20261017/DESIGN.md`):
  - zkLLM (Sun, Li, Zhang; ACM CCS 2024; arXiv 2404.16109): log-derivative
    table lookups ("tlookup") for non-arithmetic operators and "zkAttn" for
    attention; recorded as 13B-class in about 15 minutes on a datacenter GPU;
  - zkGPT (USENIX Security 2025; ePrint 2025/1184): GPT-2 (124M) in under 25 s
    with 101 KB proofs, "result-as-witness" for softmax/LayerNorm/GELU;
  - Polyhedra zkPyTorch (ePrint 2025/535): Llama-3-8B about 150 s per token;
  - Lagrange DeepProve-1 (GPT-2 class, open-sourced 2026-06);
  - zkAgent (ePrint 2026/199): 0.40 s per token;
  - zkLLMPoT (arXiv 2610.08258, v2 of 11 Oct 2026): hides the **weights** with
    **public** audit inputs, which is the reverse of this project's P1;
  - Attestable (vendor blog, 2026-08-11; no paper, no code): claims Gemma-4-31B
    at 53 proved tokens/s on one H100 with private weights; states that it
    proves "all non-linear operations in floating points" with approximation.
  This draft's summary of those notes (not a legal conclusion): of the systems
  the notes characterise, zkLLMPoT and Attestable hide weights rather than the
  input data, and Attestable proves non-linear operations through floating-point
  approximations whose semantics are not published; the notes do not identify
  a system that proves the exact integer computation of a complete trained
  transformer with its inputs, outputs and activations hidden. The attorney's
  search must test this.
- **Building blocks that are prior art and are used here, not claimed as new
  by themselves:** Ligero/Brakedown-class linear-code polynomial commitments;
  the sum-check protocol and zero-checks over multilinear extensions;
  zero-knowledge sum-check masking of the Chiesa–Forbes–Spooner type as used in
  Libra; the LogUp log-derivative lookup argument (Haböck, ePrint 2022/1530);
  multi-column tuple compression with a challenge (Plookup, Gabizon–Williamson,
  ePrint 2020/315); Lasso (ePrint 2023/1216) and Twist and Shout (ePrint
  2025/105), considered and not used; Fiat–Shamir with BLAKE3; the Goldilocks
  prime field. The repository also records that Orion's hidden-column
  construction (ePrint 2022/1010) was reported unsound (ePrint 2024/1164).
- **Content credentials.** The app's appended proof manifest is described in
  the repository as "a content-credentials pattern" (D37 addendum). The
  attorney should search content-provenance standards (for example C2PA-style
  manifests) as prior art for the manifest aspect; the repository has not done
  that search.

### 1.5 What is different here, in one paragraph

The system compiles a trained model into an exact integer computation, proves
the whole forward pass (embedding lookup, every transformer block, final norm,
head and the token choice or classifier verdict) as **one proof under one
Fiat–Shamir transcript**, and keeps every hidden value on prover-generated
hiding commitments, **each opened exactly once**, with a reserved pair of
random mask rows for every place a commitment is claimed. It replaces the
expensive per-entry division of softmax with a **per-row division dictionary**
whose size is fixed by public data. It can end in a **public verdict bit**
instead of a hidden token, which turns the proof into a label ("this hidden
content was classified safe by model M under policy P"). An application
publishes one such label proof per category and per content chunk at creation
time, appends a signed manifest of the proofs to the content, anchors the
manifest entries in batched Merkle roots, and uses the proved labels to decide
which audiences receive the content, failing closed when a proof is missing.

## 2. Summary of the inventive aspects

Thirteen aspects are listed. They are separable, so the attorney can claim them
independently or as a combination. "Status" says what exists as of 2026-10-28.
Section 3 gives the detail; the table's last column points to the subsection.

| # | Aspect | Status (2026-10-28) | Detail |
|---|---|---|---|
| A1 | Private attention: hidden claimed sums carried as masked scalars and proved inside host zero-checks | BUILT, REVIEWED; PRIVACY ACCEPTED at named profiles | §3.2 |
| A2 | Single-opening masked commitments: a reserved mask pair per claim site, derived commitment geometry, and a machine disclosure ("rank") gate on captured receipts | BUILT, REVIEWED; gate run on every accepted profile | §3.3 |
| A3 | Composition: a whole block, and a whole multi-block run, as one proof under one transcript, with prover-generated boundary commitments opened once | BUILT, REVIEWED; PRIVACY ACCEPTED (TinyLlama 22-block run) | §3.4 |
| A4 | Integer-exact model statement: exact norm, softmax and activation gadgets on one byte table; per-layer (and per-group) activation tables; calibration and model identity bound into the transcript | BUILT (per-layer tables); per-group tables DESIGN ONLY (spec written, fidelity measured) | §3.5 |
| A5 | DD, the per-row division dictionary for softmax | BUILT, REVIEWED (soundness), privacy gate passed; no privacy statement yet | §3.6 |
| A6 | Hidden-token input stage: embedding gather by indexed LogUp over a challenge-compressed table row | BUILT, REVIEWED; PRIVACY ACCEPTED (TinyLlama T32) | §3.7 |
| A7 | Hidden next-token output stage: keyed greedy argmax with the first-maximum tie rule; hidden output endpoint decommitted privately to its owner | BUILT, REVIEWED; PRIVACY ACCEPTED (TinyLlama T32) | §3.8 |
| A8 | Public-verdict classifier endpoint: a signed margin range proof with the verdict bit in the transcript; template pinning and control-token exclusion | BUILT on synthetic models, privacy gate passed on 7 captures; Shieldstral profile IN PROGRESS | §3.9 |
| A9 | Tied-embedding recomputation binding: the verifier recomputes the public token tables from the pinned checkpoint tensor | IN PROGRESS (candidate code and tests, not frozen or reviewed) | §3.10 |
| A10 | Chunked content proofs with public, re-derivable chunk ranges and a fail-closed OR label | BUILT (classifier CLI and app) | §3.11 |
| A11 | Proof-carrying content labels that gate distribution, with an appended signed proof manifest | BUILT in the app with a stand-in prover (labels not yet bound by the proof) | §3.12 |
| A12 | Anchoring: off-chain receipts, batched Merkle anchoring of per-(item, chunk, category) records, salted content commitments | BUILT with a local chain stand-in; testnet publisher BUILT, nothing broadcast | §3.13 |
| A13 | Proof hygiene: selectable security tier bound into the statement, keyed hash domains, all input-dependent refusals before any commitment, statement written only by the verifier | BUILT | §3.14 |

### A1. Private attention with masked claimed sums and host zero-checks

- **What it is.** A zero-knowledge proof of the attention half of a transformer
  block (RMSNorm, Q/K/V projections, rotary position encoding, causal scores,
  integer softmax, the value product, output projection, residual), in which no
  intermediate value, not even a claimed sum of a sub-proof, is ever sent in
  the clear.
- **How it works.** Each sub-proof (a "slot") that would normally publish a
  claimed sum s publishes only one masked scalar `claim = s + c·G`, where G is
  the total of a committed random masking polynomial and c a fresh challenge.
  The evaluation that defines s is moved, with a fresh batching coefficient ν,
  into a zero-check that already runs over the same domain (the "host"), whose
  own claimed sum becomes `ν·claim + Γ_host` with
  `Γ_host = c_host·G_host − ν·c·G`. Hosts run after the slots they host. A
  claimed sum that mixes evaluations on different domains (the fused Q/K/V
  product) is split into one slot per domain. All lookup helper sums collapse
  into one committed zero-sum row whose only published claim is "sums to 0".
  Pointwise checks that used to be done on clear values become batched terms
  of a zero-check.
- **Why it matters.** It is what lets the verifier check attention without
  seeing any attention value; the construction's machine checks show zero
  disclosed dimensions on every commitment except the public lookup identity.

### A2. Single-opening masked commitments with derived geometry and a disclosure gate

- **What it is.** A discipline for hiding polynomial commitments: **no
  commitment is opened more than once**; every place a commitment is claimed
  (a "claim site") has its own reserved pair of fresh random rows; every
  commitment has its own proximity pair; and the number of rows is **derived**
  from the data size and the claim count, never accepted from a caller.
- **How it works.** For an internal boundary commitment holding `data` rows
  with `sites` claim sites, the prover builds `rows = data + 2·sites + 2` (a
  pair per site plus the proximity pair) and the verifier refuses any other
  count by name; the block commitments are laid out the same way from the
  fixed geometry (data rows, then one pair per claim site, then the proximity
  pair), and the verifier computes every count itself. Each
  opened value is published only as `(1 − e)·T(p) + e·(R_re + u·R_im)(tail p)`
  using that site's reserved pair. An analysis tool takes a captured receipt,
  writes every verifier-visible field value as a linear function of witness and
  mask coordinates, and computes the "disclosed dimension" of the witness; it
  also constructs blinding that reproduces the exact view from an all-zero
  witness.
- **Why it matters.** The repository found that two openings of one commitment
  at its endpoint geometry recover all hidden words (D11), and that a single
  proximity row instead of a pair discloses one dimension (ruling M-1). The
  rule and the gate prevent both, and make privacy checkable on real receipts.

### A3. One-transcript composition of blocks and runs

- **What it is.** A complete transformer block (attention, second norm,
  feed-forward, residual) is one proof under one transcript with exactly two
  external endpoints. A run of L blocks is also one transcript; block k's hidden
  output is block k+1's hidden input through an **internal boundary
  commitment** that the prover generates, that two slots claim (block k's
  output equality and block k+1's input equality), and that is opened once, in
  stage k+1.
- **How it works.** Stage order: absorb the stage index and the block's public
  digest; commit the boundary `B_k`; run the block (commit A, commit M, draw
  the lookup challenges, commit H, run the slots, open M, A, H); then open
  `B_{k−1}`, whose claim list is complete only now. The receipt is segmented per
  stage so a verifier streams it. The run statement is written only after the
  whole run verifies.
- **Why it matters.** Gluing separately finished proofs through a shared
  commitment root is exactly the broken double-opening configuration; this
  composition proves a 22-layer or 32-layer model in one proof while keeping
  every inter-layer plane hidden.

### A4. Integer-exact model statement and non-linear gadgets

- **What it is.** The trained float model is converted once ("calibration")
  into an integer model whose every operation (matrix products with shifts and
  remainders, RMSNorm via an integer square root, an exponential table for
  softmax, activation tables for SiLU, rotary tables) is exactly defined; the
  proof is about that integer computation bit for bit. Model identity,
  calibration constants and table digests are absorbed into the transcript.
- **How it works.** All range facts reduce to byte limbs looked up in **one**
  256-entry table. The norm's square root `D` and its two witnesses are pinned
  by at most four byte limbs, which is exactly where the square relation cannot
  wrap in the field. SiLU tables are members of a frozen, digest-pinned family
  chosen per layer (built) and, in the next profile, per channel group with a
  public group column (designed). A public random Hadamard rotation of the
  residual basis is folded into the public weights.
- **Why it matters.** Integer exactness makes the proof's meaning
  hardware-independent and makes an uncalibrated or out-of-range computation
  fail to prove, instead of being silently approximated. The designed accuracy
  stack measures within about 1% of the float model's perplexity (measured in a
  replica of the integer arithmetic, not yet in a built proof profile).

### A5. DD, the per-row division dictionary

- **What it is.** A way to prove softmax's division `p = ⌊e·2^F_P / Sum⌋`
  without a division proof per score entry.
- **How it works.** The exponential table has few distinct outputs (19 at
  Llama-3-8B, at most a public `cap` = 32). Within one attention row the
  denominator `Sum` is fixed, so the row's probabilities take at most `cap`
  values. Each row gets `cap` committed dictionary slots
  `(key = row Sum, e_k, P_k)` with `e_k` from a public column (the sorted
  distinct table outputs plus 0) and `P_k` proved once by the exact division
  relation; each score entry then does one tuple lookup `(Sum, e, p)` into its
  row's slots. Every slot is constrained whether used or not, and the
  dictionary size is fixed by public data, so it reveals nothing about which
  values occur.
- **Why it matters.** Bit-exact, and at Llama-3-8B with 512 tokens it removes
  20.8% of committed elements, 28.2% of byte lookups and 20.1% of zero-check
  work [COUNTED]; the saving grows with context length.

### A6. Hidden-token input stage

- **What it is.** The proof starts from hidden token ids, not hidden
  activations: each hidden id selects its row of the public embedding table
  inside the proof.
- **How it works.** After the hidden plane and the token ids are committed, the
  verifier draws a column point `r_emb`; each position contributes one tuple
  `(tok_t, x̃(t, r_emb))` looked up by LogUp in the V-row table
  `(v, Ẽ(v, r_emb))`. The table's values depend on a challenge, so the cost does
  not grow as T·V. A separate clause with its own fresh coefficient forces the
  beginning-of-sequence token at position 0.
- **Why it matters.** It hides the prompt itself, at about 0.5 M committed
  elements for Llama-3-8B at any context length [COUNTED].

### A7. Hidden next-token output stage with keyed argmax

- **What it is.** The proof ends with the model's greedy next token, hidden in
  an output commitment that only its owner opens.
- **How it works.** Final RMSNorm, then a per-row int8 head with public 12-bit
  integer multipliers, then a keyed argmax: with `V_pad = 2^v`, key
  `κ_i = 2^v·l_i + (2^v − 1 − i)`; a committed one-hot selector, a committed
  maximum, and per-entry non-negative differences in byte limbs prove that the
  selected id is the **first** maximum (lowest id among ties), with every
  relation shown load-bearing. The prover hands the token and the output
  commitment's decommitment to the owner privately; the owner rebuilds the
  root and compares it with the receipt.
- **Why it matters.** It proves a model's actual answer while the verifier
  learns neither prompt nor answer.

### A8. Public-verdict classifier endpoint

- **What it is.** A classifier variant in which the only public output is one
  bit `b` (for example "flagged"), plus the model and policy identity.
- **How it works.** The two head rows for the answers "yes" and "no" are
  replaced by one public int16 margin vector `w_Δ` (their quantized
  difference), so the integer margin is `Δ = Σ_i y_i·w_Δ,i`. With `σ = 2b − 1`,
  the prover commits byte limbs (five at the classifier's declared bounds) of
  `δ = σ·(Δ − c) − b` and one slot proves
  `Δ − σ·δ = σ·b + c` over the integers; `b` is absorbed into the transcript.
  Then `b = 1` exactly when `Δ > c`. There is no output commitment. On the
  input side, a template clause pins the public policy prompt around the hidden
  content, and a third public lookup column proves that no content position is
  a control token.
- **Why it matters.** The proof becomes a publishable label: "this hidden
  content was judged (not) to violate policy P by model M", with nothing else
  disclosed.

### A9. Tied-embedding recomputation binding

- **What it is.** The verifier (or the trusted loader) recomputes the
  embedding table, the head table and the classifier margin vector from the
  pinned checkpoint tensor itself, with a spelled-out quantizer, and refuses any
  table whose recomputed digest differs from the one in the statement.
- **Why it matters.** Without it, a prover could present a consistent-looking
  but doctored head table with a self-made digest; the independent review of
  the classifier profile raised exactly this (R12 finding F1).

### A10. Chunked content proofs

- **What it is.** Long content is split into fixed-size token chunks, each
  proved separately per category; chunk size and overlap are public deployment
  parameters (tunable per hardware), and the label for a category is the OR of
  the chunk verdicts, failing closed.
- **How it works.** The content is tokenized once; chunk `j` covers
  `[j·s, j·s + n)` with stride `s = n − o`, the last chunk end-aligned to
  `[N − n, N)`; every chunk proof absorbs `(j, K, range, N, n, o)`; the verifier
  re-derives the ranges and refuses any other.
- **Why it matters.** Proof size and memory are bounded by the chunk, so the
  same system runs on a laptop (about 40 content tokens per chunk) or a server
  (about 424).

### A11. Proof-carrying content labels that gate distribution

- **What it is.** Each item is classified once, at creation, for each category
  of a fixed pre-registered list; every label (yes or no) is published with its
  proof; a signed manifest listing every (chunk, category) proof travels with
  the item; the platform uses the proved labels to choose which audiences
  receive it (for example, explicit content is never sent to minors).
- **Why it matters.** Distribution decisions become checkable by anyone,
  without revealing the content to the checker, and missing or failed proofs
  default to the most restrictive label.

### A12. Anchoring

- **What it is.** Receipts (hundreds of MB) live in content-addressed storage;
  a small domain-separated record per (item, chunk, category) is hashed into a
  sorted Merkle batch whose root is anchored on a chain; the manifest carries
  each entry's leaf and path. The hidden-input commitment root is deliberately
  not repeated in the anchors.

### A13. Proof hygiene

- **What it is.** A set of rules built into the prover and verifier: the
  security tier is a parameter bound into the statement and the verifier
  enforces a minimum; hash inputs of different roles are separated by keyed
  BLAKE3 with per-profile keys; every refusal that depends on the hidden input
  happens in a sealing pass before the transcript header exists, so a refused
  input publishes nothing; the prover inverts every lookup-table entry on every
  attempt so the remaining refusals depend only on public challenges; the run
  statement is written by the verifier after it accepts.

## 3. Detailed description

This section is written so that a person skilled in zero-knowledge proof
systems could build each aspect. Symbols: `T` tokens (padded `T_pad`), `d`
model width, `V` vocabulary size (`V_pad = 2^v`), `L` number of blocks,
`⌊·⌋` floor, `x̃` the multilinear extension of a vector `x`, `eq(r, x)` the
multilinear equality polynomial.

### 3.1 Common machinery (one embodiment, as built)

**3.1.1 Parties and data.**
- The **prover** holds the hidden input (token ids or an activation plane), runs
  the integer model, and produces a **receipt** (proof bytes, in segments) and a
  **statement** (public JSON naming the model, profile, calibration, endpoints
  and security floor).
- The **verifier** holds a trusted copy of the public model export (integer
  weights, public tables, calibration constants) and of the profile, and
  accepts or rejects the receipt.
- An **owner** of a hidden endpoint (input owner, output owner) may receive a
  private decommitment of that endpoint from the prover.
- Public (P1): weights, tables, shapes, shifts, the profile, the model and
  calibration identity, commitment roots, and masked values. Hidden: input,
  output, every activation, every inter-block plane, every histogram, helper
  sum and claimed sum.

**3.1.2 Field.** Goldilocks `p = 2^64 − 2^32 + 1`; every verifier challenge is
in the quadratic extension `F_{p^2} = F_p[u]/(u^2 − 7)`
(`ops/zkp-mvp/trained-1b/zkp-core/src/field.rs`).

**3.1.3 Polynomial commitment** (Ligero/Brakedown class;
`zkp-core/src/pcs.rs`, `hashline/src/zk.rs`).
- A committed vector of length `m·n` (`n = 2^log_cols`, `2^12` at the trained
  profiles) is an `m × n` matrix. Each row is Reed–Solomon encoded
  systematically (its `n` values are evaluations on the size-`n` subgroup,
  re-evaluated on a larger domain) and a BLAKE3 Merkle tree is built over the
  encoded columns.
- An opening of a linear functional with row weights `ρ` and column weights
  `c` sends `v = ρ^T M`; the verifier checks `⟨v, c⟩` against the claimed value
  and, at `Q = 256` random columns `j`, that `Enc(v)[j] = Σ_i ρ_i·encoded[i][j]`.
  Functionals sharing column weights are batched with a random combination of
  row weights; a random proximity combination rides on the same columns.
- **Hiding.** Each row's message polynomial is `f = f_data + Z_n·g_pad`, with
  `Z_n(x) = x^n − 1` and `g_pad` fresh uniform of degree `< Q`; the evaluation
  domain is the coset `h·G_{4n}` (`h = 7`), disjoint from the message subgroup,
  so any `Q` opened columns are jointly uniform. Merkle leaves are salted:
  `leaf_j = BLAKE3(BLAKE3(column_j) ‖ salt_j)` with 32 fresh random bytes per
  column. Rate about 1/4 (column test `(1 − δ/3)^Q ≈ 2^-105.6` per opening);
  endpoint commitments use row width `2^8` and rate 1/8 (about `2^-106.25` per
  opening).
- Randomness: each proof draws fresh secret bytes from the operating system;
  a seeded mode exists only for test fixtures and byte-identity gates.

**3.1.4 Zero-knowledge sum-checks** (`zk.rs`, `private_block/argument.rs`).
- Every sum-check or zero-check over hidden data is masked in the
  Chiesa–Forbes–Spooner / Libra manner: a committed random masking polynomial
  `g(x) = a_0 + a'·Π_j x_j + Σ_j Σ_{e=1..deg} a_{j,e}·x_j^e` and a challenge `c`;
  the sum-check runs on `f + c·g`.
- **Last-round extension for terminals:** each hidden table `T` of a slot is
  extended by one trailing variable, `T_ext(x, y) = (1 − y)·T(x) + y·R_T(x)`
  with `R_T` a reserved random mask row, and the public factor carries
  `(1 − y)`. Rounds over `x` are unchanged; the final round reveals only the
  masked terminal `(1 − ρ_y)·T̃(ρ) + ρ_y·R̃_T(ρ)`, which is uniform. Two
  bilinear slots (scores, PV) have two hidden factor families and take two
  extension rounds.
- The masking polynomials of all slots live in one small commitment **M**
  (one row per slot coefficient set plus blinding rows), opened **once** with a
  product-form linear test; all mask functionals of a block (each slot's
  `g(ρ_s)` and the batched host corrections) are folded into that one test by
  one challenge θ.

**3.1.5 Lookups.** All range facts and table relations use LogUp
(log-derivative) lookups with tuple compression `α − (value + β·aux + γ·TAG)`:
- the **multiplicity histograms are committed** (in A) before any lookup
  challenge;
- per table a committed helper column `g_T[i] = m_T[i] / (α − t_T(i))` is
  proved by the degree-1 relation `g_T·(α − t_T) − m_T = 0` in a table
  zero-check;
- the whole lookup identity becomes **one** sum claim with value 0 on the
  helper commitment H, masked by a zero-sum row `u` (`Σ_j u[j] = 0`) that has
  its own zero-sum mask pair and a fresh pair for its terminal;
- no helper sum and no histogram is ever sent. Tags in the built code:
  `TAG_U8 = 129` (byte range), `TAG_EXP = 133`, `TAG_ACT = 134`, `TAG_DD = 141`
  (`private_block/layout.rs`).

**3.1.6 Commitments of one block.** `A` (base-field witness planes, limbs,
histograms, reserved mask rows), `H` (extension-field lookup helpers), `M`
(sum-check masks), plus endpoint or boundary commitments. Example
[MEASURED, every captured record]: trained TinyLlama-1.1B at T = 32 has per
stage A = 1,729 rows (1,487 data, 120 claim sites, 36 opening groups) and
H = 1,798 rows (50 claim sites, 9 groups); an external endpoint has 21 rows
(16 data + 5); an internal boundary has 22
(`docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_TRAINED_TINYLLAMA_T32.md` §1).

**3.1.7 Transcript order of one block** (`private_block/protocol.rs`):
`header → A root → M root → (β, γ, α) → H root → the slots in fixed order →
one M opening → one opening per hiding commitment (A, H, input endpoint, output
endpoint), in that order`. Per slot (`argument.rs`): absorb the slot index →
draw `c` (zero is refused) → absorb the **one** published scalar (`s + c·G`
for a private sum, `c·G` for a public-zero slot, the batched `Γ_host` for a
host) → masked rounds → one extension round per hidden factor family → absorb
the masked terminals. Prover and verifier are driven by **the same code**
(`Side::Prove` / `Side::Verify`), so they cannot build different claim lists.

**3.1.8 The block's slots** (as built; `layout.rs`, 23 slots, a 24th on DD
profiles), in transcript order:

| # | Slot | Role |
|---|---|---|
| 0, 1 | SS row sums of the two norms (private) | `Σ_i x[t,i]^2` per row |
| 2 | norm-squares zero-check | hosts 0 and 1; isqrt facts |
| 3 | limb zero-check | byte limbs of the norm witnesses |
| 4 | masked row sums + selector (private) | softmax denominators |
| 5–7 | Q, K, V matmuls (private) | split per domain (A1) |
| 8 | score matmul (private, bilinear) | `q·k` per head |
| 9 | PV matmul (private, bilinear) | probabilities × values |
| 10 | Wo matmul (private) | output projection |
| 11–13 | gate, up, down matmuls (private) | feed-forward |
| 14 | D-domain zero-check | hosts 10, 13; norm quotients, residual pins |
| 15 | Q-domain zero-check | hosts 5, 9; RoPE on queries |
| 16 | KV-domain zero-check | hosts 6, 7; RoPE on keys |
| 17 | softmax zero-check | hosts 4, 8; masked max, exp lookup, quotient |
| 18 | F-domain zero-check | hosts 11, 12; SiLU lookup, product |
| 19 | table helper zero-check | `g_T·(α − t_T) − m_T = 0` |
| 20 | zero-sum row | `Σ u = 0` |
| 21, 22 | IO-in, IO-out endpoint equality | binds the hidden input/output planes |
| 23 | DD dictionary zero-check (DD profiles only) | §3.6 |

### 3.2 Aspect A1 — private attention with masked claimed sums

Source: `docs/zkmatrix-poc/ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md` (the
construction, 2026-09-16), `hashline/src/private_attention.rs` (first native
build), carried into `private_block.rs` / `argument.rs`.

**3.2.1 Problem.** In a non-private sum-check pipeline, the verifier forms the
claimed sum of a later sub-proof from earlier public evaluation claims (for
example, the claimed sum of the Q-projection product is `2^sh_q·q8(p) + rq(p)`,
read from earlier terminals). Under hiding those terminals are masked, so the
verifier cannot form the sum, and publishing the sum would disclose a value.

**3.2.2 Rule for a private claimed sum.**
1. The private slot `s` publishes exactly one masked scalar
   `claim_s = s_s + c_s·G_s`, absorbed before its first round challenge, where
   `G_s = Σ a_s` is the slot's mask total (enforced through the M opening).
2. The evaluation that defines `s_s` (for example `2^sh·q8(p) + rq(p)`) becomes
   a term `ν·eq(p, x)·V(x)` inside a **host** zero-check on that plane's own
   domain, where `V` is the public-coefficient combination of committed planes
   that reconstructs the value and `ν` is a fresh challenge.
3. The host's claimed sum is `ν·claim_s + Γ_host` with
   `Γ_host = c_host·G_host − ν·c_s·G_s`, published; the host's terminal
   evaluates the planes at the host's own point through pair-masked claims.
4. Consequently `s_s` never appears; the slot's own terminal closes against
   `claim_s`; the mask accounting mixes only quantities already in the view.
5. **Hosts run after the slots they host** (their claimed sums consume the
   masked scalars).
6. In the M commitment's functional list, a standalone mask-total functional
   is emitted only for public-zero standalone slots; hosted totals appear only
   inside their host's batched `Γ`. (A standalone total on a hosted slot would
   reveal `s_s = claim_s − c_s·Σ_s`; the CFS check exhibits that leak.)

**3.2.3 Splitting across domains.** A masked scalar can carry one mask total,
so a public λ-combination of evaluations on different domains cannot be hosted
by one zero-check. The fused QKV claimed sum
`acc_q + λ_k·acc_k + λ_v·acc_v` therefore becomes three slots (Q on the Q
domain; K and V on the KV domain with two `ν`s). Combinations on a single
domain keep one slot.

**3.2.4 Host assignment** (the built mapping):

| Private slot | Stands for | Host |
|---|---|---|
| SS row sums | `a1 + Dsq − Ceps` per norm site | norm-squares zero-check (T domain) |
| softmax row sums | the row-sum block `Sum(h, t)` | softmax zero-check (S domain) |
| Q / K / V matmuls | `2^sh·q8 + rq` etc. | Q-domain / KV-domain zero-checks |
| score matmul | `2^sh_s·s8 + rs` | softmax zero-check |
| PV matmul | `2^sh_o·o8 + ro` | Q-domain zero-check |
| Wo matmul | `2^sh_ao·(Σ coef·ao) + rao` | D-domain zero-check |
| gate, up matmuls | requantized gate/up words | F-domain zero-check |
| down matmul | requantized down word | D-domain zero-check |

**3.2.5 Clear-value checks become zero-check terms.** Linear relations that a
public pipeline checks on clear claim values become `μ`-batched degree-1 terms
of the zero-check on their domain, each with its **own fresh coefficient**:
the isqrt facts `a2 = 2·D − a1`, the limb sums `a1 = l0 + 2^8·l1 + …`, the norm
remainder relation `σ + ρ + 1 = D·2^{tn+1}`, and the residual pins
`xres1·2^sh + rr1 = x_in·2^sh + ao·2^sh`, `xres2·2^sh + rr2 = xres1·2^sh + z·2^sh`.

**3.2.6 Integer softmax in the softmax zero-check.** Per head and query row:
a masked row maximum (causal mask), `δ = max − s8` (in `[0, 255]`), `E = exp
table[δ]` by lookup, a masked row sum `Sum = Σ mask·E`, and the quotient
`p = ⌊mask·E·2^F_P / Sum⌋` with remainder windows by byte limbs (or by the
dictionary of §3.6). The exp table is a public member keyed `(e_s, d_h, f_E)`:
`E[δ] = round_half_up(2^f_E·exp(−δ·2^e_s/√d_h))`, `δ ∈ [0, 255]`, monotone,
`E[0] = 2^f_E` (`hashline/src/tables_attn.rs`).

**3.2.7 Rotary position encoding.** The rotation relation reads two public
integer tables `c[t][i] = round_half_up(cos(t·base^(−2i/d_h))·2^f_ro)` and the
matching sine table; a scaled RoPE (YaRN, llama3) changes only those public
tables, computed in binary64 by the reference formulas, and a profile whose
attention factor is not exactly 1 is refused (`private_block/rope.rs`).

**3.2.8 Evidence.** The construction's rank tool (exact arithmetic, P1 and
P3) shows disclosed data dimension 0 on every group and every commitment, H
disclosing exactly the public LogUp identity, and every negative control
leaking as predicted (no masks; one base row per claim; a single proximity row;
a dropped seam pair; published helper sums; a zero-sum row without its fresh
pair). The CFS slot check passes 97 checks (`results/zk60_private_attention_evidence/`).

### 3.3 Aspect A2 — single-opening masked commitments, derived geometry, disclosure gate

Sources: D11, D12, D12a, D17 in the register; `private_block/boundary.rs`,
`endpoint_g.rs`, `layout.rs`, `hash_domain.rs`; the privacy statements.

**3.3.1 Rules (enforced in code).**
1. **No commitment is opened more than once** anywhere in a proof or across
   proofs. Prepared commitments are consumed by value on success and failure;
   there is no API for a second opening.
2. **Every claim site has its own reserved mask pair**: two fresh random rows
   used by exactly that one claim. A plane opened at `k` points has `k` pairs.
   Members of one opening group share column weights; each member's pair sits
   on its own rows.
3. **Every commitment has a dedicated proximity pair.**
4. **Geometry is derived.** An internal boundary with `sites` claim sites has
   `rows = data + 2·sites + 2`; any other row count is refused by name. An
   external endpoint with one site has `data + 5` rows: the terminal pair at
   `(data, data + 1)`, the proximity row at `data + 2`, and two more random
   rows. The verifier and the wire parser compute every count from the
   geometry, never from the receipt.
5. **Every published value of a hidden plane** is a pair-masked terminal
   `(1 − e)·T(p) + e·(R_re + u·R_im)(tail p)`; no single base-field mask is used
   anywhere.
6. **Pad rule.** Every hidden plane on a padded domain is proved zero off its
   support by one batched term `μ_pad·(1 − supp(x))·Σ_j ζ^j·plane_j(x)` in that
   domain's zero-check, with named exemptions (`private_block/pad.rs`).
7. **Collapse is off**: no claim may be merged into another's opening.

**3.3.2 Why each rule is needed (recorded counterexamples).**
- At the endpoint geometry (7 rows of 256 columns) two openings of one
  commitment recover all 512 hidden words (D11).
- A boundary with a single proximity row (`data + 2·sites + 1`) has joint rank
  5 of 6 on its reserved rows and discloses one real dimension, and a schedule
  audit that trusts the caller's declaration does not catch it (ruling M-1,
  finding U-1; `boundary.rs`).
- Raising size limits on a multi-block plane without a whole-plane binding
  leaves the rest of the plane unbound (an attack was built; D17), so every
  wider shape binds the whole plane.

**3.3.3 The disclosure ("rank") gate on captured receipts.**
1. Capture every verifier-visible field value of a real receipt (roots aside):
   masked scalars, round messages, masked terminals, opened column values, M
   openings.
2. Express each value as a linear function of the hidden witness coordinates
   and the mask coordinates, using the code's own layout and draws.
3. For each commitment, compute the rank of the witness-dependent part modulo
   the span of the mask part ("disclosed dimension"); require it to equal the
   declared public identity (0 for A, endpoints, boundaries and M; exactly the
   2-dimensional public LogUp identity for H).
4. Construct, from an all-zero witness, blinding values that reproduce the
   captured view exactly (a "zero-data preimage"), commitment by commitment and
   jointly over all couplings.
5. Run negative controls (remove a mask pair, publish a sum, and so on) and
   require each to leak.
- Measured example [MEASURED]: trained TinyLlama 22-block run — A disclosed 0
  everywhere (rank 74 of 74 generators on the non-data rows), H disclosed
  exactly 2, endpoints 0, all 21 boundaries 0, M 0; full preimage over
  24,605,616 entries with 0 differing; terminal identity 506 of 506
  (privacy statement §3, D33).
- A non-linear channel check (NL-1) confirms that every slot polynomial has a
  public factor in every monomial, within its declared degree, and that the
  mask covers every slot (`L_s + 256 ≤ 512`).

### 3.4 Aspect A3 — one-transcript composition of a block and of a run

Sources: D12, D12a, D12b, D18, D23 in the register; `private_block.rs`,
`private_block/run.rs`, `boundary.rs`, `run_sink.rs`, `run_statement_file.rs`.

**3.4.1 One block = one proof.** The block's chain
`x_in → norm_a → (Q, K, V) → RoPE → scores → softmax → PV → Wo → xres1 → norm_m
→ (gate g8, up u16) → SiLU a16 → product h16 → down z16 → xres2` is closed link
by link inside one argument on one A, one H and one M, under one transcript,
with exactly two external endpoints (`x_in`, `xres2`). Hidden intermediates
(`xres1`, `nm`, `z16`) never get an endpoint commitment shared by two proofs.
The second norm's output carries a mandatory int8 range proof, because the
feed-forward relations prove no range on their own input (D12 item 4).
Declared endpoint scales are tied to the approved calibration (D12 item 5).

**3.4.2 One run = one transcript.** For `L` blocks:
1. The external input endpoint (hidden input plane, or the token endpoint of
   §3.7) is committed by the prover at proof time (D18) and claimed by stage 0.
2. Stage `k` (for `k = 0 … L−1`): absorb the stage index and block `k`'s public
   digest; if `k < L − 1`, commit the boundary `B_k` (the padded hidden output
   plane of block `k`, `rows = data + 2·2 + 2`) and absorb its root; run block
   `k` unchanged (A, M, `β, γ, α`, H, the slots, open M, A, H); then open
   `B_{k−1}` with both of its claims (block `k−1`'s IO-out and block `k`'s
   IO-in). The last stage commits no boundary and closes the external output
   endpoint.
3. Transitively, `A_k`'s output plane equals `A_{k+1}`'s input plane word for
   word, which is the chaining statement.
4. **One randomness generator per run**, never cloned, forked or serialized;
   the hidden input is fixed before the first segment (D12b(2)).
5. **Interior boundary scales are constants of the approved calibration**; a run
   refuses any other (D12b(3)).
6. **Segmented receipt.** Each stage's proof bytes are one segment (one file
   per segment, written atomically); a streaming verifier reads them one at a
   time, so verifier memory is bounded by one stage
   (`run_sink.rs`). Example: the TinyLlama next-token receipt is 24 segments
   (22 blocks + input stage + output stage), 255,258,816 B, exactly equal to the
   counted lengths [MEASURED].
7. **Statement written by the verifier.** A run directory is publishable only
   if it contains the run statement, which the verifier writes after the whole
   run has verified, from its own rendering and the hashes of the verified
   bytes; a directory without it is never transmitted (D12b(1), D21).
8. At trained profiles a single-block receipt is refused: "one block" means a
   run with `L = 1` (`protocol::single_block_profile_allowed`).

**3.4.3 Operating rules that the privacy argument relies on.** An accepted
receipt's endpoint roots are never registered, republished or referred to by a
later artifact (D23); joining two finished runs through a root is forbidden
(D12a); rejected receipts are never transmitted, and retained capture bundles
count as publishing (D21).

**3.4.4 Soundness and privacy of record.** Twelve-block run at the 125M
geometry about `2^-97.5` (ruling M-2). Privacy accepted by Victor for the
trained TinyLlama-1.1B T32 run (D33): an accepted run's view is within about
`2^-74.8 / 2^-73.8 / 2^-70.4` per run (`L = 1 / 2 / 22`) of a distribution that
does not depend on the hidden input, output, activations or boundary planes,
in the random-oracle model for BLAKE3 and under the stated generator
assumption.

### 3.5 Aspect A4 — integer-exact model statement and non-linear gadgets

Sources: `hashline/src/norm.rs`, `chain.rs`, `tables_attn.rs`,
`zkp-core/src/tables.rs`, `private_block/trained_block.rs`,
`trained_statement.rs`; D16, D24, D32; `results/zk60_fidelity_parity_20261019/REPORT.md`.

**3.5.1 Calibration (done once per model, outside the proof).** The float
checkpoint is converted into an integer export: int8 weights (with public
per-row or per-channel scale handling), an int16 residual stream, per-site
requantization shifts, norm constants, a public exp-table member per layer,
a public SiLU-table member per layer, public RoPE tables, and an optional
public change of basis of the residual stream (a randomized Hadamard rotation
folded into the public weights; it costs the proof nothing because weights are
public). A Python integer reference reproduces the integer model; the native
prover's witness must equal it bit for bit at every layer (a parity check that
refuses before anything is committed).

**3.5.2 Requantized matrix products** (`chain.rs`):
`acc = X·W^T` exactly (bounded, e.g. `|acc| < 2^24`); `y8 = acc >> sh`,
`r = acc & (2^sh − 1)` (floor requantization; `y8 ∈ [−128, 127]`). The
remainder is range-proved by byte limbs against the single 256-entry table
(top limb scaled by `2^(8 − sh)` where needed). Example FFN chain: gate and up
products, `a8 = S[g8 + 128]` (the activation table), `hh = a8·u8`,
`h8 = hh >> sh_h`, down product, `z = dacc >> sh_z`.

**3.5.3 Exact RMSNorm gadget** (`norm.rs`, D16, D24):
- `SS_t = Σ_i x[t,i]^2` (a row-sum sum-check);
  `SSe_t = SS_t + Ceps`, `Ceps = max(1, round_half_up(ε·d·2^(−2e_x)))`;
- `D_t = isqrt(SSe_t)`, proved by the witness pair `a1 = SSe − D^2 ∈ [0, 2D]`,
  `a2 = 2D − a1 ≥ 0`;
- `y[t,i] = ⌊x[t,i]·g[i]·Cn / (D_t·2^tn)⌋` via `y·D·2^tn + ρ = x·g·Cn`,
  `ρ ∈ [0, D·2^tn)` (exact remainder window);
- **`D`, `a1`, `a2` each pinned directly by byte limbs, at most four**,
  because `(2^32 − 1)^2 + (2^32 − 1) = p − 1` exactly, so four limbs is the last
  count at which the square relation cannot wrap in the Goldilocks field; a
  field alias `D ↦ k + (p − 1)/2` that satisfies every relation is refused by
  the byte lookup (built and tested);
- **per-profile norm precision** (D24): `tn` is lowered with width (10 at
  2048, 9 at 4096) so the remainder window stays at most 32 bits, i.e. four
  byte limbs, instead of adding a fifth limb.

**3.5.4 Softmax exp table and RoPE tables:** §3.2.6, §3.2.7.

**3.5.5 Activation tables (SiLU).**
- **Built:** each layer's activation table is a member of a frozen,
  digest-pinned family, e.g. the int16-output family
  `S[g] = clamp(round_half_up(f(g·2^e_in)/2^e_out), −32767, 32767)` over the
  int8 gate domain `g ∈ [−128, 127]`, `f = silu` in binary64; the loader
  regenerates the bytes from the formula and refuses any digest mismatch; the
  profile names the member per layer (at trained TinyLlama, 7 distinct members
  over 22 layers). Each lookup is a two-column tuple `(g, S[g])` under
  `TAG_ACT`.
- **Designed (next profile, "R13"; build spec
  `results/zk60_fidelity_parity_20261019/S2_BUILD_SPEC.json`):**
  **per-channel-group tables.** SiLU input int12 with 4096-row registry tables;
  at most 4 groups per layer at T128 (8 at T512); a **public group column**
  assigns each channel to its group, and the lookup tuple includes the group
  so the right member is used without new committed planes. Member rule per
  group: the finest `e_in ∈ [−5, −1]` with
  `127·2^e_j ≥ min(8 × channel max, 4 × tensor max)`; one output member per
  group; with power-of-two group output scales the per-group scale is applied
  before the product rounding as a per-group shift selected by the public
  group column. Counted cost: 0 committed planes and 0 lookups; one public
  column (+1.3–2.0% zero-check element-terms) [COUNTED].
- Weight side (designed, same spec): per-output-channel public integer
  multipliers `m_j = ⌈2^b·rowmax/127⌉`, words `W'_j = round(W_real·2^b/m_j)`,
  output `round(m·acc / 2^(sh + b))` (bits per site q 5, k 5, v 6, o 8, g 6,
  u 4, d 6).

**3.5.6 Model and calibration identity bound into the transcript**
(`trained_statement.rs`, built). The run header absorbs, as its 32-byte
calibration word, the identity of a separately versioned statement containing:
(1) the source identity (repository, immutable revision, SHA-256 of the tensor
file and config, parameter and layer counts, every source tensor's name and
raw-byte SHA-256); (2) every integer constant the relations use, the
endpoint/boundary scale labels and the digests of the quantizer and the public
calibration token set; (3) per proved layer the block's public digest and the
SHA-256 of each padded integer weight word and public table; (4) the profile and
geometry strings. The verifier checks it against its own trusted copy. The
loader refuses (naming file and field) any schema, pin, constant, shape, dtype,
length or digest mismatch, and any table that is not the named generator
member.

**3.5.7 Fidelity (why exactness does not cost accuracy).** Victor's target
(D32, amended): integer perplexity at most 1.02 × float on held-out FineWeb and
WikiText, LAMBADA at least 98% of float, zero refusals. Measured in the
fidelity lane's replica of the integer arithmetic (not yet a built proof
profile) [MEASURED, n = 1]: Llama-3-8B with the "LOW + h int24" stack —
perplexity ratio 1.0108 / 1.0094 with 0 of 96 sequences refused, LAMBADA
0.800 vs float 0.780 on 200 items (its two LAMBADA refusals were calibration
bounds, fixed at no proof cost; the full re-run with the fixes is still owed);
TinyLlama-1.1B "LOW" — 1.0086 / 1.0101, LAMBADA 0.599 vs 0.598 on 1,000 items,
0 refused. Counted proof cost of that stack: +22.8%
committed at 8B T128 [COUNTED]. Calibration rules found necessary: score bounds
must cover all `T × T` pairs including masked future scores (the relation
range-checks the whole score matrix); group-SiLU bounds from the full
calibration set; layer-0 vocabulary maxima.

### 3.6 Aspect A5 — DD, the per-row division dictionary

Sources: D30 and its implementation note in the register;
`results/zk60_gpt_nonlinear_review_20261018/REVIEW.md` §R2.4 and `dd_check/`;
`results/zk60_1b_native_20261017/PROGRESS.md` Round 9; `private_block/layout.rs`
(`SC_DD = 23`, `TAG_DD = 141`), `argument.rs`, `protocol.rs`, `witness.rs`.

**3.6.1 Observation.** The softmax probability of a score entry is
`p = ⌊mask·E·2^F_P / Sum⌋` where `E` is the exp-table output and `Sum` the
row's masked sum. Within one row `Sum` is fixed, and `mask·E` takes values only
in the set of distinct exp-table outputs plus 0, which is small and **public**
(19, 11 and 6 distinct outputs at Llama-3-8B for `e_s` = 2, 3, 4; 24/14/8 at
TinyLlama for `e_s` = 1/2/3). So each row's `p` takes at most `n_E + 1` values.

**3.6.2 Construction (as built in native round R9).**
1. A per-profile constant `cap` (32 at the built profiles) bounds the number
   of distinct values `{0} ∪ outputs(exp table)`; a profile whose tables need
   more is refused by name at the loader and at the run statement, before any
   header (an over-cap block with 44 values was refused in testing).
2. A new domain `Dd` with `cap` slots per attention row `(h, t)`. Slot `k`
   holds the tuple `(key, e_k, P_k)`:
   - `key` = the row's `Sum` (the register allows the row id instead);
   - `e_k` = the `k`-th entry of the public column `sorted({0} ∪ outputs)`,
     padded with 0;
   - `P_k = ⌊e_k·2^F_P / Sum⌋`, proved by the existing exact-division relation
     verbatim (`e_k·2^F_P = P_k·Sum + σ`, `σ + ρ + 1 = Sum`, with byte limbs for
     `σ`, `ρ` and `P_k`), **at every slot of every true row, with no usage gate**;
   - a hidden multiplicity plane `M_dd` and a table helper.
3. Each score entry keeps its score word, row-max selector, `E` and `P` (PV
   reads `P`), drops its own division limbs, and proves
   `(Sum, mask·E, P) ∈ dictionary(row)` with **one** tuple lookup, compressed as
   `α − (γ·TAG_DD + key + β·mask·E + β^2·P)`.
4. Tuples and multiplicities are committed in A **before** `β, γ, α`; the
   dictionary's table helper `g·(α − τ) − M_dd` enters the **single** value-0
   sum claim with sign −1; each dictionary plane is opened only at its own
   reserved site; no virtual claim is used.
5. The prover inverts **every** dictionary slot on every attempt (so whether
   an attempt is refused for a zero denominator depends only on public data and
   challenges, up to a counted residual `2·L·(768 + rows·cap)/p^2`, about
   `2^-103` per 32-block run).
6. Built restriction: a DD profile has an unpadded dictionary (heads and `T`
   unpadded, `cap` a power of two), which makes the pad clause vacuous.
7. The dictionary zero-check is appended as the last slot (slot 23) only on DD
   profiles, so every non-DD transcript is byte-identical to before
   (seeded golden digests equal; older receipts verify under the new code).

**3.6.3 Why it is exact.** Every value `mask·E` can take is in the public
column; each `(row, e)` has exactly one proved quotient; membership therefore
forces `P = ⌊mask·E·2^F_P/Sum⌋`; the witness is unchanged bit for bit.

**3.6.4 Why it is privacy-safe in shape.** The dictionary's size,
`rows × cap`, is fixed by the public table, not by which values occur; all
slots are proved; multiplicities are hidden committed rows. (A dictionary sized
to the observed distinct pairs, as in the general literature idea, would leak
that count.)

**3.6.5 Results.** [COUNTED] at Llama-3-8B, T512: committed elements
663,257,088 → 525,172,736 (−20.8%), byte lookups −28.2%, zero-check work
−20.1%, lookup soundness +0.40 bits; at T128 −3.86% (the dictionary is 1/4 of
the score domain at T128 and 1/16 at T512; the saving grows with `T`, −31.4%
counted at T1024). [MEASURED, n = 1, shared box] Llama-3-8B T128 prove
474.9 s with DD vs 478.7 s without (no measurable change at this length, as
counted), receipt 930,231,520 B, parity bit-exact at every layer, 11 of 11
tamper controls refused. Independent soundness review round r9 accepted it at
the three DD profiles; the privacy gate on DD captures (round 14) passed 13 of
13 records with the dictionary planes adding no disclosure. No privacy
statement covers a DD profile yet.

**3.6.6 Mutation tests that show each condition is load-bearing** (R9,
[MEASURED]): an unconstrained dictionary slot passes when the condition is
switched off and is rejected as built at slot 23; dropping the row key is
rejected at the value-0 sum claim; removing the dictionary helpers from the
sum claim is rejected there; choosing multiplicities after `α` is rejected at
slot 23 against the committed `M_dd`.

### 3.7 Aspect A6 — hidden-token input stage (embedding gather)

Sources: `results/zk60_token_io_design_20261017/DESIGN.md` §2 (v4), D25, D26,
D34; the token lane's built code (`results/zk60_token_io_r1_20261017/`).

**3.7.1 Run shape with token I/O.**
`[IN] → B_in → block 0 → B_0 → … → block L−1 → B_out → [OUT]`. `B_in` and
`B_out` are ordinary internal boundaries (two claim sites, `data + 6` rows,
opened once). The external **input token endpoint** holds the `T` hidden ids
(row width `2^8`, rate 1/8); in the public-row variant it has one claim site
(`data + 5` rows).

**3.7.2 Stage IN** (its own `A_in`, `H_in`, `M_in` at row width `2^12`, under the
run transcript). Order: absorb the stage tag and the embedding table's digest;
commit `B_in`, `A_in`, `M_in`; draw `β, γ, α` and a column point `r_emb`;
commit `H_in`; run the slots; open `M_in`, `A_in`, `H_in` (and the token
endpoint, when it has one site).

| Commitment | Planes |
|---|---|
| `A_in` | `tok` (`T` lifted to the row width, pad-zero on the lift), `m` (multiplicities over `V_pad`) |
| `H_in` | `h_q` (query helpers), `h_tab` (table helpers), `u` (zero-sum pair) |
| `B_in` | `x_in_L00` (block 0's hidden input plane, `T_pad × d_pad`) |
| token endpoint | `tok` (and, in the hidden-length variant, a selector) |

Slots:
- **IO-in**: `end(0, z) = supp_T(z)·tok(0, z)` over the endpoint's whole token
  half (pad words bound to zero by the public support).
- **Query zero-check**, with fresh coefficients drawn after `A_in`, `M_in`,
  `H_in` are committed:
  `eq(τ, t)·[ μ_q·(h_q(t)·(α − q_t) − supp_T(t)) + μ_bos·[t = 0]·(tok(t) − BOS)
  + μ_pad·(1 − supp_T(t))·(tok(t) + ζ·h_q(t)) ] = 0`,
  where `q_t = tok(t) + β·x̃(t, r_emb) + g_emb` and `x̃(t, r_emb)` is **`B_in`
  read at the partially fixed point** `(ρ_t, r_emb)` (one claim site; no new
  plane).
- **Table zero-check**: `h_tab(v)·(α − τ(v)) = m(v)` with
  `τ(v) = v° + β·Ẽ(v°, r_emb) + g_emb` (`v° = v` for `v < V`, 0 on pads); pad-zero
  on `m` and `h_tab`. **The table's second column depends on the challenge
  `r_emb`**; both prover and verifier fold the public table `E` at `r_emb` once
  (`O(V·d)`).
- **LogUp sum**: `Σ_t h_q − Σ_v h_tab = 0` (the existing value-0 claim on H).
- **ZS**: the zero-sum row.

**3.7.3 Why it is sound.** (i) For random `α`, the fractional identity holds
only if the multiset of queries is contained in the table (a query outside
leaves a pole with residue in `[1, T]`, non-zero since `p > T`), error
`(T + V_pad)/|F_{p^2}| ≤ 2^-110.9`. (ii) For fixed `r_emb`, distinct tuples
collide for at most one `β`: `T·V_pad/|F_{p^2}|` (2^-102 at 8B T512). (iii)
`r_emb` is drawn after the roots of `B_in`, `A_in`, `M_in`, so
`x̃(t, r_emb) = Ẽ(tok_t, r_emb)` gives `x[t, ·] = E[tok_t, ·]` on every column
except with probability `T·log2(d_pad)/|F_{p^2}|` (2^-115.4). Block 0's IO-in
binds the whole `B_in` plane, so block 0's input is exactly the embedded
prompt.

**3.7.4 The BOS clause's own coefficient is load-bearing.** With a bare
addend, `tok_0 = BOS + 1` and `h_q(0) = 0` make the LogUp clause (−1) and the
BOS clause (+1) cancel at `t = 0`, so row 0 escapes the lookup; with its own
fresh coefficient the forgery is refused (tested). General batching rule
adopted from this: **every clause batched into one slot polynomial carries its
own fresh challenge, drawn after every commitment it constrains.**

**3.7.5 Cost** [COUNTED]: 0.184 M committed elements (TinyLlama), 0.479 M
(Llama-3-8B) at every `T`, versus 4.3–67 M for a one-hot × table matmul. The
verifier's table fold is about 0.82 s at 8B [MODEL].

**3.7.6 Hidden-length variant** (ruled as D26, DESIGN ONLY): the prompt is
right-padded inside the public bucket `T`, and a one-hot position selector `s`
is sealed as the second half of the input token endpoint, which then has two
claim sites (stage IN's IO-in and stage OUT's IO-s), derived geometry
`rows = data + 2·2 + 2`, opened exactly once after stage OUT.

### 3.8 Aspect A7 — hidden next-token output stage (keyed argmax)

Sources: DESIGN.md §3; D25 (T1–T8); built token code; measured runs
`results/zk60_token_io_r1_20261017/runs/r2/ho00/`, `runs/r3/trained-ho00/`.

**3.8.1 Stage OUT relations** (mode (i): one output position, `T_out = 1`).
1. **Row selection**: the stage's `x` row equals `B_out` at row `T − 1`
   (coordinates fixed to the bits of `T − 1`).
2. **Final RMSNorm** in the block's norm form with a uniform gain
   (`g0 = 127`), per-profile `tn`, calibrated `Cn`; `y ∈ [−127, 127]` by lookup;
   `x`'s int16 range re-proved.
3. **Head**: `W' = round(lm_head·diag(norm_weight)·R^T / s_j)` as int8 **per
   row** `j`, each row with a **public integer multiplier**
   `m_j = max(1, round(2^12·s_j / max_j s_j)) ∈ [1, 2^12]`, so
   `l_j = m_j·(y·W'_j)` with the multiplier folded into the matmul slot's public
   factor; the logits are raw integer accumulators and **virtual** (never
   committed); head words of −128 are refused at the loader.
4. **Keyed greedy argmax.** With `V_pad = 2^v` define
   `κ_i = 2^v·l_i + (2^v − 1 − i)` (larger logit first, then smaller index); the
   first maximum of `l` is the unique maximum of `κ`. Commit a selector
   `e[t, ·]` over the vocabulary, `L` byte limbs `λ_k[t, ·]` of a difference
   `δ[t, ·]`, and scalars `tok[t]`, `M[t]`. `L = ⌈window/8⌉` is **derived**, with
   `window = bits(2^v·2d·127^2·2^12 + V − 1)` (53 bits / 7 limbs at TinyLlama,
   56 / 7 at Llama-3-8B); the loader checks `2^(8L) + 2^window < p`. Prove:
   - (A1) `e·(1 − e) = 0`; `e = 0`, `λ = 0` on padded vocabulary entries;
   - (A2) `Σ_i e[t,i] = 1`; (A3) `tok[t] = Σ_i i·e[t,i]`;
     (A6) `Σ_i e[t,i]·δ[t,i] = 0` — batched into one slot with a public factor in
     every monomial,
     `Σ eq(r, t)·[ supp_V·e·(c1 + c2·ι + c3·δ) − u0·(c1·supp_T + c2·tok) ] = 0`,
     `c1, c2, c3` fresh challenges drawn after `A_out`;
   - (A4) `δ = Σ_{k<L} 256^k·λ_k`, every limb a byte (no top-limb pin needed);
   - (A5) the head claim lands on the virtual logits
     `l*[t,i] = supp_V(i)·(M[t] + 2^-v·(i − tok[t] − δ[t,i]))`, the host term of the
     vocabulary zero-check.
5. **Why it is the first maximum.** (A1)+(A2) make `e[t, ·]` one-hot at some
   `j < V`; (A3) gives `tok = j`; (A6) gives `δ_j = 0`; (A5) at `i = j` gives
   `M = l_j`. Hence `δ_i = 2^v·(l_j − l_i) + (i − j)` in the field; both sides
   are integers of absolute value below `2^window` and `δ_i ∈ [0, 2^(8L))`, and
   `2^(8L) + 2^window < p`, so the equality holds over the integers and
   `2^v·(l_j − l_i) + (i − j) ≥ 0`. If `l_i > l_j` the left side is negative,
   impossible; if `l_i = l_j` then `i ≥ j`. So `j` is the lowest index among the
   maxima (numpy's first-maximum rule, ruling D25 T3). Each of A3, A6 and the
   pad-zero clause was shown load-bearing by a forgery accepted when that one
   relation is removed. No honest argmax is ever refused.
6. **Output endpoint**: one hidden token id in a 256-word plane at row width
   `2^8`, rate 1/8 (one data row plus 5 mask rows), claimed once by IO-out
   (`end(z) = u0(z)·tok`), opened once.

**3.8.2 How the owner learns the answer.** The verifier never sees the token
(D25 T5). The prover sends the authorised owner, over a private channel, the
token id and the output endpoint's decommitment (every row including the mask
rows, each row's 256 pad coefficients, and the Merkle leaf salts). The owner
re-encodes, rebuilds the root (no proof work) and compares it with the
accepted receipt's output root; the input owner checks the input root the same
way. Built as the CLI commands `owner` and `input-owner`. The decommitment is
never published (D21) and the roots are never chained (D23).

**3.8.3 Mode (ii), whole greedy continuation in one proof** (DESIGN ONLY): with
prompt length `P` and `G` generated tokens, `T = P + G`; the input endpoint
holds the whole sequence; stage OUT computes the argmax at positions
`P − 1 … T − 1`; a SHIFT slot proves `tok_out[k] = tok_in[k + 1]`; the input
endpoint has two claim sites and is opened once at the end. Counted +5% to
+12% of the 8B stack.

**3.8.4 Measured examples** [MEASURED, laptop CPU, shared box, n = 1]:
- **TinyLlama-1.1B, next token, 32-token hidden prompt** (2026-10-18): hidden
  ids → embedding → all 22 trained blocks → final norm → per-row int8 head →
  greedy choice, one proof under one transcript; prove **85.3 s**, peak
  2.45 GiB; fresh-process verify 10.6 s under a 95-bit minimum policy; receipt
  255,258,816 B in 24 segments; a one-bit change refused; 55 of 55 applicable
  tamper controls caught where predicted; whole-run soundness 97 bits
  [COUNTED]. Next token confirmed by four independent references.
- **Llama-3-8B, next token, 32-token hidden prompt** (2026-10-19): all 32
  trained blocks streamed; prove **191.7 s**, peak 3.44 GiB; fresh-process
  verify **43.4 s**; receipt **471,285,072 B**; 65 of 65 applicable tamper
  controls caught; bit-exact at all 32 layers; whole-run soundness 97 bits.
- Llama-3-8B with a 128-token hidden prompt: 501.6 s total, verify about 57 s,
  receipt 928 MB, whole-run floor 96 bits.
- For scale: plain 8-bit CPU inference of the same 8B model takes about 1.55 s
  for 32 tokens, so the proof costs about 100× plain inference at that length
  [MEASURED, `results/zk60_cpu_inference_baseline_20261019/README.md`].
- Privacy accepted by Victor for the TinyLlama next-token proof (D36): view
  within about `2^-74.43 / 2^-73.62 / 2^-70.35` per run (`L = 1 / 2 / 22`) of an
  input-independent distribution; the verifier is never given the prompt ids at
  positions 1–31, their embedding rows, the activations, the final-norm values,
  the logits, or the next token.

### 3.9 Aspect A8 — public-verdict classifier endpoint

Sources: `results/zk60_token_io_r1_20261017/classifier/DESIGN_CLASSIFIER.md`
(v2, v2.1, v2.2), its adversarial check `check/CHECK.md`, D37–D41, and the
token lane ledger (R-C1 built and frozen as `frozen-r12/`, 2026-10-26).

**3.9.1 Model and rule.** The target embodiment (being built; the stage itself
is built and tested on synthetic models, §3.9.7) is Mistral's open safety
classifier Shieldstral-1.0-3B (Apache 2.0; a Ministral-3-3B decoder, 26 blocks,
`d = 3072`, `V = 131,072`, tied embeddings). Its decision rule: score =
softmax over the "yes" and "no" logits, flagged above `τ`, i.e.
`z_yes − z_no > ln(τ/(1 − τ))` (D38).

**3.9.2 What becomes public, and what stays hidden.** Public: the model
identity (all block digests, the calibration, the rotary table, the tied
embedding derivation), the int16 embedding table, the int16 margin vector
`w_Δ` and its scale, `V`, `d`, BOS, the final-norm constants, the yes/no ids
as profile constants, the threshold `c`, the canonical tokenizer by digest and
its control-id set, the template (prefix ids, suffix ids, policy text), the
content length if ruled public, the verdict bit `b`, the input endpoint root,
the whole-run security floor. Hidden: the content ids and their embedding rows,
every activation and inter-block plane, the final-norm values, both logits
(never formed), the margin `Δ` and its range limbs. There is **no output
endpoint** and no owner opening (D40: one external endpoint plus a public bit).

**3.9.3 Input side (stage IN-C).**
1. **Canonical encoding** (fix B-1):
   `prefix_ids ‖ tekken.encode(' ' + content, bos = False, eos = False) ‖ suffix_ids`,
   where the prefix is the reference chat encoding cut before the separating
   space (84 ids for the card template, ending at `:`), and the suffix is
   `[/INST]`. Reproduced 67 of 67 against the reference encoder.
2. **Template clause** (own fresh coefficient `μ_tmpl`, drawn after `A_in`,
   `M_in`, `H_in`): `eq(τ, t)·μ_tmpl·π(t)·(tok(t) − tmpl(t))`, with `π` the
   public template indicator and `tmpl` the public template ids (0 at content
   and pad positions; `tmpl(0) = BOS` checked at the loader; the design document
   writes this vector as κ). With a shared coefficient the
   clause could cancel against the LogUp clause; tested both ways.
3. **Control-token exclusion** (fix B-2): the stage-IN lookup tuple gains a
   third public column: table `τ(v) = v + β·Ẽ(v, r_emb) + β^2·ctl(v) + g_emb`,
   query `q_t = tok_t + β·x̃(t, r_emb) + β^2·c(t) + g_emb`, where `ctl(v) = 1`
   exactly for the tokenizer's special ids (`v < 1000` for tekken) and the public
   `c(t) = ctl(tmpl(t))` at template positions, 0 at content positions. A content
   position holding a control id matches no table entry. Guarantee: the posted
   text cannot structurally close the instruction or supply its own answer.
   Cost: one public vector, no new commitment.

**3.9.4 Output side (stage OUT-C).**
1. Row selection (the `[/INST]` position, public row `T − 1`) and final RMSNorm
   as in §3.8.1.
2. **Margin vector**, quantized directly as int16 with one public scale:
   `w_Δ = round((E_yes − E_no)·diag(norm_weight)·R^T / s_Δ)`, 0 on pads, from
   the tied matrix `E`. Then `|w_Δ| ≤ 32,767` and `Δ = Σ_i y(i)·w_Δ(i)` satisfies
   `|Δ| ≤ B_Δ = 3072·127·32767 ≈ 2^33.57` [COUNTED]. The individual logits are
   never formed (one rounding instead of three).
3. **Verdict and range proof.** `b ∈ {0, 1}` public, `σ = 2b − 1`,
   `δ = σ·(Δ − c) − b`, so `b = 1 ⇔ δ = Δ − c − 1 ≥ 0` and `b = 0 ⇔ δ = c − Δ ≥ 0`.
   Commit `L` byte limbs of `δ`; `L` derived from `window = bits(B_Δ + c_max + 1)`
   (35 bits with `|c| ≤ 2^33`, so `L = 5`); the loader checks
   `2^(8L) + 2^window < p`.
4. **Margin slot MRG**:
   `Σ_{i ∈ Do} [ y(i)·w_Δ(i) − σ·λ(i)·g(i) ] = σ·b + c`, with public
   `g(i) = 256^i` for `i < L` and 0 elsewhere; `λ` in its own small lifted domain
   with one byte lookup and one helper; a pad-zero clause on `λ` beyond `L` with
   its own coefficient; every monomial has a public factor and the right side is
   public. MRG replaces the head, vocabulary zero-check, selector slot and
   IO-out of §3.8.
5. **Why the verdict is right.** MRG at a random point drawn after `A_out`
   gives `Δ − σ·δ = σ·b + c` in the field; all terms are integers whose total is
   far below `p/2` (`|Δ| ≤ 2^33.57`, `δ < 2^40`, `|σb + c| ≤ c_max + 1`), so the
   identity holds over the integers and `Δ − c = σ·(δ + b)`: `b = 1 ⇒ Δ ≥ c + 1`,
   `b = 0 ⇒ Δ ≤ c`. Flipping `b` needs `δ' = −δ − 1 < 0`, which is not five
   bytes. The tie `Δ = c` gives `b = 0`, matching "flagged above τ".
   Load-bearing (each shown by a forgery): the byte lookups on `λ`; `λ`'s
   pad-zero clause; `b` absorbed into the transcript; and **the verifier's own
   derivation of `w_Δ`** (a swapped `−w_Δ` with a self-made digest would invert
   the meaning while every relation holds).
6. **Threshold.** For integer `Δ`, `c = ⌊θ/κ⌋` is exact, with
   `θ = ln(τ/(1 − τ))` and `κ = s_y·s_Δ` the margin's public scale
   (`Δ > ⌊x⌋ ⇔ Δ > x`); at `τ = 0.5`, `c = 0`; `c` is a profile constant.

**3.9.5 Statement and transcript.** The statement gains `classifier` (yes/no
ids, `w_Δ` digest and scale, `c`, `τ`, the rule text), `tokenizer` (digest,
plain-text mode, control-set digest), `template` (prefix/suffix ids, `P0`,
`S`, policy-text digest) and `verdict`. **The verifier derives** the ids, `w_Δ`,
`s_Δ`, `c` and the control set from the export and the tokenizer and refuses a
mismatch before reading any segment. All of these are absorbed before any
segment.

**3.9.6 Leakage and operating rules.** One bit per proof (the limbs and
multiplicities are committed, MRG is masked, the window and `L` are fixed by
the class, and proof length depends only on `T`). A fixed, pre-registered list
of `N` policies, one `c` each, gives exactly `N` disclosed bits per item;
re-proving an item at another threshold or policy is forbidden (it would leak
the hidden score). An item without an accepted proof is treated exactly as
flagged. The input-dependent refusal term for this shape is about `2^-112.7`
per run (D40) [COUNTED].

**3.9.7 Status and evidence.** R-C1 (stage OUT-C, template clause, `ctl`
column, chunk layer, CLI `classify-prove` / `classify-verify` /
`classify-input-owner` / `label`) is built and frozen on synthetic rung models
(full suite 789 passed / 0 failed; rebased probe 819 / 0). Honest runs at both
verdicts and at the tie [MEASURED]: verdict 0 at margin 5,214,444 and verdict 1
at 5,269,429 under `c = 5,214,444`; 4 segments; floor 93 bits (synthetic
shape). Privacy gate round 17 on 7 captures (1- and 2-block models; verdict
yes, no and tie; one item in 2 chunks): no commitment discloses more than
expected, 11 tamper checks fire, and the yes / no / tie runs look identical
apart from the public bit [MEASURED]. Not yet: the Shieldstral-shaped run
(R-C2), the tied-table binding (§3.10), a privacy statement.

**3.9.8 Binding the proof to the posted item.** From the receipt alone a third
party learns the template, that the content ids are below `V` and free of
control ids, the sealed input root, and the verdict; without a decommitment
nobody can tell that this content is the posted item (inherent to hiding).
- **Option R (built path):** the app keeps the input endpoint's decommitment;
  anyone given the item's bytes and the decommitment re-encodes, checks the
  template and control ids, and rebuilds the root. Recording the root beside
  the item needs an amendment of D23 (pending with Victor, item B-8).
- **Option S (DESIGN ONLY, not adopted):** derive the endpoint's pads, mask rows
  and leaf salts from a fresh 32-byte per-item seed by keyed BLAKE3 under a
  separate domain, `PRF(seed, policy id, chunk index, context)`, so one
  decommitment `(content, seed)` opens all `N × K` roots of an item.

### 3.10 Aspect A9 — tied-embedding recomputation binding (IN PROGRESS)

Sources: `private_block/tied_tables.rs`, `tied_tables/derive.rs`;
`docs/zkmatrix-poc/ZK60_SOL_ASTRA_TODOS_20261026.md` (S1b log, 2026-10-28);
token lane ledger (R12 F1 discussion).

**Problem.** In a model with tied embeddings (no separate `lm_head`), the input
embedding table, the head table and the classifier's margin vector are all
derived from one checkpoint tensor. If the loader only checks each table
against a digest in its own manifest, a prover can supply a doctored table with
a consistent digest (independent review finding R12-F1: "declared, not
checked").

**Construction (candidate code, focused tests passing, not frozen, review
pending).**
1. Pin the tied tensor by the SHA-256 of its raw bytes at its byte range in the
   checkpoint file (for Shieldstral: `embed_tokens.weight`, BF16
   `[131072, 3072]`); read it with bounded, exact-length, regular-file reads
   (no symlink following, no FIFO, file identity re-checked after opening).
2. Recompute, with a spelled-out quantizer: BF16 → binary64; block-Hadamard
   rotation; the embedding rotated, rounded through f32, then
   `⌊x/s_in + 0.5⌋`; the head multiplied by the checkpoint's final-norm weight
   before rotation, per-row `maxabs/127`, half-up rounding; the margin vector as
   `rotate((E_yes − E_no)·norm)`, `⌊x/scale + 0.5⌋`, refused (not clipped) outside
   `±32767`.
3. Take the yes/no ids and the scale from the statement-bound policy and
   profile; bind the token parameters (BOS, final-norm constants for head and
   classifier) into the trained statement's identity (nine fields).
4. Compare the recomputed embedding, head, multiplier and margin digests with
   the statement; refuse on any difference.
- Evidence so far [MEASURED, n = 1]: the native recomputation equals an
  independent NumPy oracle on the full pinned tensor; "re-hashed" forgeries of
  the multiplier and head (consistent digests, wrong values) are refused.

### 3.11 Aspect A10 — chunked content proofs

Sources: D41; DESIGN_CLASSIFIER.md §13; R-C1 code (`ChunkPlan`,
`chunk_ranges`, `ChunkRef`); `apps/proven-media/DESIGN.md` §3,
`apps/proven-media/deploy.json`.

1. **Encode once.** `c = encode(' ' + content)` with the pinned plain-text
   encoder; `N = |c|`. The model input of every chunk is defined on ids, never by
   re-encoding a text slice (a slice's round trip is not stable).
2. **Chunk size per category** `n_i = T − P0_i − S_i` (template overhead
   subtracted), so every chunk proof runs at exactly the profile's `T`. With an
   84-id prefix and a 1-id suffix: 43 / 171 / 427 content ids at T128 / T256 /
   T512 [COUNTED].
3. **Overlap** `o` (`0 ≤ o < n_i`), stride `s_i = n_i − o`. Chunk `j < K − 1`
   covers `[j·s_i, j·s_i + n_i)`; the last chunk is **end-aligned**,
   `[N − n_i, N)`; `K = 1 + ⌈(N − n_i)/s_i⌉` for `N ≥ n_i`. Example built test:
   27 ids, size 23, overlap 4 → chunks `[0, 23)` and `[4, 27)`.
4. **The prover never chooses `n_i` or `o` per item.** Both are in the
   classifier profile (and so in its digest) and the statement; each chunk
   proof absorbs `(j, K, [a_j, b_j), N, n_i, o)` under a dedicated transcript
   label; the verifier re-derives the ranges from `(N, n_i, o)` and refuses any
   other range.
5. **Label rule.** `label_i = OR_j b_{i,j}`, computed by the verifier from the
   public per-chunk bits. Fail closed: the label is 1 (flagged) if any chunk
   index has no accepted proof, a chunk appears twice, a range is not the
   split's, or chunks name different `N`, policy or model.
6. **Linking chunks to one item.** Each (category, chunk) proof has its own
   input endpoint (never one commitment opened in two proofs). A third party
   given the item's decommitment bundle re-encodes the content once, re-derives
   every range, builds each plane `prefix_i ‖ c[a_j : b_j] ‖ suffix_i`, and
   rebuilds each root (built path, about 90 KB per root). A seeded variant
   (option S, §3.9.8) would reduce this to one 32-byte seed.
7. **Hardware profiles** (tunable, D41): laptop 40 content tokens / overlap 8 /
   at most 4 chunks; workstation 168 / 16 / 8; server 424 / 32 / 16
   (`deploy.json`).
8. **Disclosed by chunking** (stated in the design): `K` bits per category
   instead of one (a "yes" label also shows which token range triggered it) and
   the total length `N`. Hiding per-chunk bits would need one aggregation proof
   of the OR over all chunk receipts (DESIGN ONLY, end state).

### 3.12 Aspect A11 — proof-carrying content labels that gate distribution

Sources: D37 (with Victor's 2026-10-21 revisions and addenda), D38, D39, D41;
`apps/proven-media/README.md`, `DESIGN.md`, `proven_media/manifest.py`.

**3.12.1 Operating model.**
1. A fixed, pre-registered list of categories, each with one fixed policy text
   and one threshold (proof of concept: sexual / explicit, graphic violence,
   hate / harassment). Policy texts are pinned by digest; a changed text is a
   new registered id, never an edited file.
2. **At creation**, each item is chunked (§3.11) and proved **once per
   (chunk, category)**; latency of minutes is acceptable because proving happens
   once. Re-checks re-verify stored proofs and never re-prove. Re-proving at
   another threshold or policy is forbidden.
3. **Both outcomes are labels.** A "yes" is not a rejection; it narrows the
   audience. Every accepted label, yes or no, is published with its proof.
4. **Distribution.** Server-side, every feed and item request carries the
   viewer's audience; an item whose labels exclude that audience is served as a
   placeholder with the labels and reasons, never with its content or manifest
   (for example, minors never receive an item unless it is proved "no" in all
   three categories).
5. **Fail closed per category.** A category without an accepted proof counts
   as the most restrictive label. If a later re-check is rejected by the
   verifier, every label of the item becomes "not proved" and the manifest is
   re-issued saying so.
6. **One encoding path.** A single function turns a post into prover input for
   each category (template around the token slice); it refuses empty content,
   over-length content and any control or unknown id.

**3.12.2 The appended proof manifest** (`zk60.manifest/1`). Produced when an
item's labels are complete (proved or failed); attached to the item in every
response that serves it and in its downloadable bundle. Contents:
- `item`: post id (128-bit random), kind, creation time, salted content
  commitment and its rule, content length;
- `category_set` id and digest; `chunking` (profile, chunk size, overlap,
  number of chunks);
- `labels`: the aggregated label per category and the label rule;
  `proved_once_at_creation` timestamp;
- `entries`, one per (chunk, category): chunk index, token range, classifier,
  model id, profile id, verifier id, policy id and SHA-256, threshold, verdict
  (yes / no / unproved), proof status, whether the verdict is bound by the
  proof, statement SHA-256, bundle (publication-manifest hash and URI), anchor
  (chain, contract, leaf hash), content commitment;
- `issued_at`, `issuer` (name, key id, public key);
- **signature**: Ed25519 over the canonical JSON without the signature field.
- A recipient verifies the signature, each proved entry's anchor leaf, Merkle
  path, block chain and batch file, and optionally re-runs each proof's
  verifier from the store; an unproved entry must name no anchor.

**3.12.3 Salted content commitment.**
`SHA-256("zk60/proven-media/content/v1" ‖ salt_32 ‖ u64_be(len) ‖ UTF-8 bytes)`;
the salt is stored encrypted and served to permitted viewers with the item, so
a viewer can check the shown text against the anchored commitment ("check it
in my browser"). Deleting the salt makes the public record unlinkable (the
design's answer to deletion requests). In the built app this commitment is not
yet bound inside the proof; the platform's binding check uses its private
endpoint decommitment.

**3.12.4 Status.** BUILT as a local application (`apps/proven-media/`:
FastAPI, SQLite, plain JavaScript) with a **stand-in prover**: each chunk gets a
real zero-knowledge proof of the TinyLlama next-token run, verified in a fresh
process, published to a local content-addressed store, anchored in a local
hash-chained ledger and listed in an Ed25519-signed manifest (local dev key).
**The labels in the stand-in come from a placeholder and are not bound by the
proof**; the Shieldstral classifier proof (§3.9) is designed to replace it
through one prover interface (`ClassifierProver`). Images are canonicalized by a
versioned integer-only preprocessing library to the classifier's 224-pixel
canvas and remain "pending verification" (visible to the author only) until an
image proof path exists. First stand-in post [MEASURED]: prove 104 s, verify
19 s, 255 MB bundle.

### 3.13 Aspect A12 — anchoring proofs on persistent stores and a chain

Sources: D39; `results/zk60_chain_publication_20261021/REPORT.md`;
`apps/proven-media/DESIGN.md` §5, `TESTNET.md`.

1. **Publication record**, one per (item, chunk, category), only after the
   fresh-process verifier accepted: schema, post id, category, chunk, token
   range, statement bytes, receipt segments, verdict, model id, policy id,
   profile id, verifier id, salted content commitment.
2. **Off-chain receipt.** Segments are stored content-addressed
   (`{file, bytes, sha256}` per segment; identical segments stored once).
   Receipts are 0.25–0.93 GB today, so they cannot go on a chain (one 0.5 GB
   receipt would fill about 130 Ethereum blocks [DERIVED in the report]).
3. **Anchor leaf.**
   `SHA-256("zk60/anchor-leaf/v3" ‖ f(post_id) ‖ f(category) ‖ f(chunk) ‖
   f(token_range) ‖ f(manifest_sha256) ‖ f(statement_hash) ‖ f(verdict) ‖
   f(model_id) ‖ f(policy_id) ‖ f(content_commitment))`, `f(x) = u16_be(len) ‖ x`.
4. **Batch.** A sorted, domain-separated Merkle tree every 10 minutes or 1,000
   leaves; node `SHA-256("zk60/anchor-node/v1" ‖ min ‖ max)`; one
   `anchor(root, count, batchFileHash)` call per batch; each manifest entry
   carries its leaf and path.
5. **The proof's hidden-input commitment root is not repeated** in anchors or
   manifests (it stays only inside the statement), per D23.
6. **Status.** BUILT with a local hash-chained ledger and a local
   content-addressed store as stand-ins; a Base Sepolia (testnet) publisher is
   implemented and tested against controlled RPC responses, refuses the
   stand-in's unbound labels, and has broadcast nothing. Recommended production
   shape (report, not built): receipts on Filecoin with an R2 mirror (deletable),
   small records and model files on Arweave, batch roots on Base, an optional
   daily checkpoint on Ethereum. Live price reads of 2026-10-21: anchoring under
   $0.001 per post; renewable receipt storage about $0.12 per text post per
   year [report's DERIVED figures].

### 3.14 Aspect A13 — proof hygiene built into prover and verifier

1. **Selectable security tier** (D27). The statement carries the profile's
   derived whole-run soundness floor; the verifier takes a minimum tier as
   policy and refuses receipts below it (runs above verified "under a 95-bit
   policy"). The tier levers (column checks `Q`, lookup challenge field or
   repetition, proximity vectors) are profile parameters, not constants.
2. **Keyed hash domains** (D19a/D19b). BLAKE3 keyed mode with four public keys
   per profile (Fiat–Shamir transcript, column digest, salted Merkle leaf,
   Merkle inner node), each derived from the profile string; the verifier
   derives them from the profile it trusts, never from the receipt. Additional
   guards: a commitment whose column-hash input length coincides with any other
   hash input length on the profile's path is refused by name; every opened
   Merkle path must have exactly its tree's depth (`hash_domain.rs`).
3. **All input-dependent refusals before the header** (sealing pass, ruling
   H-1, D29). The loader, the witness builder's refusal sites, bit-exact parity
   against the reference, and a lookup-miss check on every sealed witness run
   before the run header exists, so a refused input publishes nothing.
4. **Refusals that remain are challenge-only, or priced.** The prover inverts
   every entry of every public table on every attempt, so whether an attempt is
   refused for a zero lookup denominator depends only on public challenges and
   tables; where the token stages invert only the prompt's own queries, the
   input-dependent term is counted (`2·(768L + 32 + 256)/p^2`, about `2^-117`
   per run at `L = 1`; D34).
5. **Statement written by the verifier** (§3.4.2 item 7); rejected receipts are
   never transmitted; hidden inputs are read from protected files, never from
   the command line; owner decommitments are never published (D21).

### 3.15 Summary of measured results (examples)

All on one laptop (WSL2, about 15 GiB RAM), CPU path, shared with other jobs,
one run each (n = 1) unless noted. Soundness figures are the project's own
whole-run accounting [COUNTED].

| Proof | Prove | Verify | Receipt | Peak RAM | Soundness | Source |
|---|---:|---:|---:|---:|---|---|
| TinyLlama-1.1B, next token, T32 (22 blocks + token stages) | 85.3 s | 10.6 s | 255,258,816 B | 2.45 GiB | ~97 bits whole-run | MVP_STATUS 10-18 |
| Llama-3-8B, next token, T32 (32 blocks + token stages) | 191.7 s | 43.4 s | 471,285,072 B | 3.44 GiB | ~97 bits | MVP_STATUS 10-19 |
| Llama-3-8B, next token, T128 | 501.6 s total | ~57 s | ~928 MB | — | ~96 bits | MVP_STATUS 10-19 |
| Llama-3-8B, 32-block stack T128, DD on / off | 474.9 / 478.7 s | 37.5 s (DD) | 930,231,520 / 922,711,264 B | 6.56 GiB | — | native PROGRESS R9 |
| Classifier rung (synthetic 2-block model), both verdicts | — | — | 4 segments, ~18.6 MB | — | 93 bits | token PROGRESS R-C1 |
| Media app stand-in post (TinyLlama next token) | 104 s | 19 s | 255 MB | — | — | MVP_STATUS 10-21 |
| Tiny block in a general zkVM (RISC Zero), for comparison | 3,743 s | — | 223,514 B (succinct), 785 B (Groth16) | — | ~97 bits conjectured | MVP_STATUS |

Privacy accepted by Victor (each an argument whose steps survived independent
attack, not a formal proof, and each limited to named code, calibration and
CPU path): D22 (toy block), D33 (trained TinyLlama-1.1B T32 run, up to 22
blocks, about `2^-70.4` per run), D36 (trained TinyLlama-1.1B T32 next-token
proof, about `2^-70.35` per run). Speed relative to the product goal: the
target is at least 50 proved tokens/s on a high-end GPU; the measured systems
are far from it (Llama-3-8B about 0.12 prompt tokens/s at T32 and about 0.26
at T128 on the laptop CPU, including loading, per `MVP_STATUS.md`). Soundness of about 95–97 bits is a recorded deviation from the
conventional 128 bits (D27).

## 4. Alternatives and variants

These broaden the description. Each is recorded in the repository as a variant,
a costed design or a measured alternative; none of the DESIGN ONLY items is
built unless stated.

**4.1 Privacy scope.**
- **P3, hidden weights** (decided as the full version, D1; DESIGN ONLY). The
  weight commitment W gets the same treatment as activations: a reserved pair
  per claim site and a proximity pair (the attention construction's schedule
  already lists the P3 rows: six singleton W groups, a pair each plus a
  proximity pair). The model is then identified by a commitment whose binding
  to an approved model is registered rather than by public digests. Recorded
  constraint: a hash-based weight commitment reused across proofs leaks its
  sampled columns and becomes recoverable after about `(n + Q)/Q` proofs (65 at
  the 125M parameters; 257 / 513 at the 8B / 30B optimum), so P3 needs a fresh
  or differently built weight commitment per proof
  (`AGGREGATION_LITERATURE.md`, addendum 2026-09-02). The non-linear-channel
  argument does not carry to hidden weights as is (NL-7).
- **Inputs sealed in advance by a third party** (D18 option B; DESIGN ONLY,
  expected end state). A regulator or user seals an input today and requests a
  proof about it later: a salted handle that is not a polynomial-commitment
  root, with a hashing gadget inside the proof showing that the sealed plane is
  the one the proof used; the security owner's direction is a two-layer handle
  (an algebraic hash inside the proof whose root is never published, wrapped in
  one standard salted hash). The same handle allows chaining separately
  finished proofs.
- **Hidden prompt length** (D26 variant P; ruled, DESIGN ONLY): §3.7.6. A
  fallback variant puts the selector in the output endpoint.
- **Seeded endpoint randomness** (option S): §3.9.8.

**4.2 Statement variants.**
- **Mode (ii)** greedy continuation in one proof (§3.8.3).
- **Multi-class or multi-label classifiers:** one margin vector per pair of
  answer rows, or one proof per category (the built route); several thresholds
  under one policy are excluded by design because they would disclose the
  score.
- **Two-row margin form:** prove the two quantized head rows with per-row
  multipliers and subtract (`|w| ≤ 2^19.99`, `B_Δ = 2^38.56`), instead of one
  directly quantized difference row.
- **Step tie rule for argmax:** `δ' = M − l_i − [i < tok]` with a committed step
  vector (about 18% fewer committed words in mode (ii)).
- **Embedding gather alternatives:** a hidden one-hot matrix times the public
  table (simple, cost `T·V`), or two-chunk one-hot addresses ("Shout"-style),
  which needs a sparse one-hot sum-check prover.
- **Public-prefix reuse ("F6", DESIGN ONLY):** for a classifier with a long
  public template, the template's keys and values are public per layer; only
  the content rows are proved, the score slot splits into a public-key part and
  a private part, and the statement binds a digest of the public cache (counted
  gains 2.00× / 4.13× / 2.06× at content lengths 32 / 48 / 64).
- **Aggregated chunk labels:** one proof of the OR over all chunk receipts, so
  only the item's label (not per-chunk bits) is public (DESIGN ONLY).
- **Normalization after PV ("FN")** and **exact shared row reciprocal ("EXR")**
  as alternatives to DD; DD's key may be the row id instead of the row sum; a
  larger `cap` (64) for finer exponential tables.
- **Seam form of block composition:** instead of one shared layout, an equality
  between two components' own commitments with reserved pairs and a seam slot
  (keeps a separate feed-forward prover, e.g. on a GPU).
- **Split-width layout:** stop padding `d = 3072 → 4096` and the feed-forward
  width (counted −17% to −25% committed at Shieldstral).

**4.3 Models and modalities.**
- Built or profiled: TinyLlama-1.1B (22 blocks, grouped-query attention 32/4),
  Llama-3-8B (32 blocks, llama3 RoPE), Shieldstral-1.0-3B (26 blocks, YaRN RoPE,
  head dimension decoupled from width: query width 4096 ≠ `d` 3072, tied
  embeddings), feed-forward-only passes of Mistral-7B (public IO, earlier line).
- Other activation families: a frozen GELU-tanh int16-output table family
  exists beside SiLU (`zkp-core/src/tables.rs`).
- **Images (D39, DESIGN ONLY):** the classifier's own vision encoder needs new
  relations (non-causal attention, 2-D RoPE, GELU, patch embedding, 2×2 merge)
  and a binding of the proof to the posted image; the app already canonicalizes
  images by a versioned integer-only preprocessing library.
- **Video (deferred):** a public, deterministic frame-sampling policy, each
  sampled frame proved as an image; audio or transcript handled separately.

**4.4 Hardware.**
- **GPU proving** (BUILT for parts of the pipeline, not covered by the privacy
  statements): device kernels for column hashing and zero-checks; CPU and GPU
  proofs are byte-identical in seeded test mode. Measured on a synthetic block
  [MEASURED, shared RTX 4070 Laptop, two non-warm samples per arm]: 32.95 s CPU
  vs 17.13 s GPU proving. A keyed-hash device path is needed for tagged
  profiles. The product target is an RTX 5090-class GPU at ≥ 50 proved tokens/s.
- Larger workloads amortize startup and prefill (the current throughput target
  permits longer contexts).

**4.5 Proof-system alternatives.**
- Other polynomial commitments: the project's earlier lattice-based (MLWE/MSIS)
  commitment line; a compact-PCS variant (95–98 bits; declined, D10); encoding
  rate 1/2 or a 31–32-bit field (D14 memo).
- LogUp-GKR with a 256-bit lookup challenge for the 100-bit tier (D27).
- A general-purpose zkVM with a Groth16 wrap (the project's D2 intermediate
  line: salted SHA-256 commitments to hidden input and output in a fixed
  journal, 785-byte receipts; D7) as an alternative embodiment of the same
  statement for tiny models, and as a **succinct wrapper** of this system's
  verifier for on-chain verification (counted 6–18 GPU-hours and $2–18 per post
  today; a verifier redesigned for recursion could reach about 800-byte proofs).

**4.6 Publication alternatives.** Other chains (Base, Ethereum checkpoints) and
stores (Filecoin, R2, Arweave); committee or optimistic attestation instead of
on-chain verification; permanent vs renewable receipt storage (a ruling for
Victor).

## 5. Draft claims (starting set for the attorney)

**DRAFT CLAIMS — a starting point for the attorney, not legal advice. Wording,
scope, claim count and eligibility framing are the attorney's.** The
dependents are chosen to cover what is built, so that narrower fallback
positions exist. Square brackets mark choices the attorney may want to make.

### Set I — private transformer inference proof (aspects A1–A4, A13)

**1.** A computer-implemented method of generating a zero-knowledge proof that a
transformer neural network having public integer parameters was evaluated on a
hidden input, the method comprising:
(a) computing, by one or more processors, from the hidden input, an integer
witness of a forward pass of the transformer, the witness comprising hidden
activation planes of a plurality of blocks, each block comprising an attention
sub-layer and a feed-forward sub-layer, each operation of the forward pass
being defined in integer arithmetic;
(b) committing the hidden activation planes in hiding polynomial commitments,
each commitment comprising data rows, a reserved pair of random mask rows for
each claim site at which the commitment is to be evaluated, the pair being used
by that claim site only, and a proximity pair of random rows;
(c) proving relations of each block by a plurality of masked sum-check
sub-arguments under a single Fiat–Shamir transcript, wherein a sub-argument
whose claimed sum depends on hidden values publishes only a masked scalar equal
to the claimed sum plus a challenge multiplied by a total of a committed masking
polynomial, and wherein an evaluation that defines the claimed sum is proved as
a challenge-weighted term within a zero-check sub-argument over the domain of
the evaluated planes;
(d) linking consecutive blocks through a boundary commitment generated by the
prover to a hidden output plane of a first block, the boundary commitment being
claimed by an output-equality sub-argument of the first block and an
input-equality sub-argument of a second block and opened exactly once after both
claims exist;
(e) opening each of the commitments exactly once; and
(f) outputting a receipt comprising commitment roots, the masked scalars, masked
round messages, masked terminal values and the openings, the receipt containing
no unmasked activation value.

**2.** The method of claim 1, wherein the number of rows of the boundary
commitment is derived as the number of data rows plus two rows per claim site
plus two rows, and a verifier rejects a boundary commitment having any other
number of rows.

**3.** The method of claim 1, wherein a published value of a hidden plane at a
claim site is a combination `(1 − e)·T(p) + e·R(p')` of the plane's evaluation and
an evaluation of the claim site's reserved mask pair, `e` being a challenge.

**4.** The method of claim 1, wherein table lookups are proved by a
log-derivative argument in which multiplicity histograms are committed before
lookup challenges are drawn, a helper column per table is committed and
constrained by a zero-check, and the lookup identity is proved as a single sum
claim of value zero masked by a committed zero-sum row, no helper sum or
histogram being published.

**5.** The method of claim 1, wherein the zero-check sub-argument hosting a
claimed sum runs after the sub-argument whose claimed sum it hosts, and a
claimed sum that combines evaluations on different domains is split into one
sub-argument per domain.

**6.** The method of claim 1, wherein the attention sub-layer computes an integer
softmax comprising a masked row maximum, a lookup of a public exponential table
at the difference between the row maximum and each score, a masked row sum, and
a quotient with remainder, each range fact being proved by byte limbs looked up
in a single 256-entry table.

**7.** The method of claim 1, wherein a normalization sub-layer computes an
integer square root `D` with witnesses `a1 = S − D^2` and `a2 = 2D − a1`, each of
`D`, `a1` and `a2` being constrained by at most four byte limbs in a prime field
of order `2^64 − 2^32 + 1`.

**8.** The method of claim 1, wherein each hidden plane on a padded domain is
proved zero outside its support by a batched term of a zero-check, and each
clause batched into one sub-argument polynomial carries its own challenge
coefficient drawn after every commitment that the clause constrains.

**9.** The method of claim 1, wherein a header of the transcript absorbs an
identity of a model statement comprising digests of source tensors of a trained
checkpoint, every integer calibration constant used by the relations, and
per-layer digests of the integer weights and public tables.

**10.** The method of claim 1, wherein the feed-forward sub-layer applies an
activation function by lookup in a public table selected, per layer [or per
channel group indicated by a public group column], from a family of tables each
generated by a fixed formula and identified by a digest.

**11.** The method of claim 1, wherein every refusal condition that depends on the
hidden input is evaluated before the transcript header is formed, such that a
refused input produces no published output, and wherein the prover inverts
every entry of every public lookup table on every proving attempt.

**12.** The method of claim 1, wherein the receipt is divided into one segment per
block, a verifier verifies the segments sequentially, and a statement of the
proof is written by the verifier only after all segments verify.

**13.** The method of claim 1, wherein the statement includes a derived
whole-proof soundness level and a verifier rejects the receipt when the level is
below a minimum policy level.

**14.** The method of claim 1, wherein hashing for the transcript, column digests,
salted Merkle leaves and Merkle inner nodes uses a keyed hash function with four
distinct keys derived from a profile identifier that the verifier holds.

**15.** A system comprising one or more processors and memory storing
instructions that, when executed, cause the processors to perform the method of
any of claims 1–14.

**16.** A non-transitory computer-readable medium storing instructions that,
when executed by one or more processors, cause the processors to perform the
method of any of claims 1–14.

**17.** A computer-implemented method of verifying a receipt produced by the
method of claim 1, comprising: deriving every commitment geometry, claim list and
opening order from the public profile rather than from the receipt; re-deriving
all challenges from the transcript; checking each sub-argument's masked rounds,
the single opening of each commitment, and the mask commitment's opening; and
rejecting the receipt upon any mismatch.

### Set II — per-row division dictionary (aspect A5)

**18.** A computer-implemented method of proving, in a zero-knowledge argument,
attention probabilities `p = ⌊e·2^F / Sum⌋` of a transformer attention row, `e`
being an output of a public exponential lookup table and `Sum` the row's sum,
the method comprising:
(a) determining, from the public table, a public column of the distinct values
that a masked table output can take, and a public capacity at least equal to the
number of those values;
(b) for each attention row, committing a dictionary of slots equal in number to
the capacity, each slot holding a tuple of a row key, a value from the public
column and a quotient, and proving for every slot, whether or not used, by an
exact division relation with range-checked remainders, that the quotient
equals `⌊value·2^F / Sum⌋` for that row;
(c) committing a hidden multiplicity for each slot before any lookup challenge
is drawn; and
(d) for each score entry of the row, proving by a single tuple lookup that the
tuple (row key, the entry's masked table output, the entry's probability) is a
slot of the row's dictionary, without a per-entry division relation.

**19.** The method of claim 18, wherein the row key is the row's sum.
**20.** The method of claim 18, wherein a profile whose table has more distinct
values than the capacity is refused before any commitment is made.
**21.** The method of claim 18, wherein the dictionary's table helper enters a
single zero-valued log-derivative sum claim shared with the other lookups, with
the tuple compressed by a distinct tag and the square of a challenge for the
quotient component.
**22.** The method of claim 18, wherein the dictionary's sub-argument is appended
after all other sub-arguments only for profiles that use the dictionary, such that
transcripts of other profiles are unchanged.
**23.** The method of claim 18, combined with the method of claim 1.

### Set III — token endpoints (aspects A6, A7)

**24.** A computer-implemented method of proving in zero knowledge the greedy
next token of a language model on a hidden prompt, comprising:
(a) committing hidden token ids of the prompt in an input commitment;
(b) proving that a hidden first activation plane equals rows of a public
embedding table selected by the hidden token ids, by drawing a column challenge
after the plane and the ids are committed and proving, by a log-derivative
lookup, that each tuple of a token id and the plane's row evaluated at the
column challenge belongs to a table of tuples of each vocabulary index and the
embedding row evaluated at the column challenge;
(c) proving the model's blocks and a final normalization;
(d) proving integer logits as products of the normalized vector with public
integer head rows, each row scaled by a public integer multiplier;
(e) committing a selector over the vocabulary, a maximum, and for each vocabulary
entry byte limbs of a non-negative difference, and proving that the selector is
one-hot, that a hidden token id equals the selector-weighted sum of indices,
that the selector-weighted sum of differences is zero, and that each logit
equals the maximum plus `2^-v` times (index − token id − difference), whereby the
token id is the lowest index among maximal logits;
(f) committing the token id in an output commitment opened once; and
(g) providing the token id and a decommitment of the output commitment privately
to an owner, who rebuilds the output commitment root and compares it with the
receipt.

**25.** The method of claim 24, wherein a clause forcing a beginning-of-sequence
token at position 0 carries its own challenge coefficient.
**26.** The method of claim 24, wherein the number of byte limbs is derived from
the declared bounds of width, vocabulary and multipliers, and the loader checks
that `2^(8L)` plus `2^window` is below the field order.
**27.** The method of claim 24, wherein the prompt length is hidden by a one-hot
position selector sealed in a second half of the input commitment, the input
commitment having two claim sites and being opened once after the output stage.
**28.** The method of claim 24, wherein a plurality of generated tokens is proved
in one proof by a shift relation between output tokens and subsequent input
tokens.

### Set IV — public-verdict classifier (aspects A8, A9)

**29.** A computer-implemented method of producing a publicly verifiable
classification of hidden content, comprising:
(a) forming a token sequence of public template tokens encoding a classification
policy and hidden content tokens;
(b) proving in zero knowledge, under one transcript, an embedding of the token
sequence, the blocks of a neural classifier, and a final normalization producing
a hidden normalized vector;
(c) computing a hidden integer margin as the inner product of the normalized
vector with a public integer margin vector derived from the difference between
the classifier's output rows for a first answer and a second answer;
(d) fixing a public verdict bit `b`, absorbing `b` into the transcript,
committing byte limbs of `δ = σ·(Δ − c) − b`, where `Δ` is the margin, `σ = 2b − 1`
and `c` is a public threshold, and proving the identity `Δ − σ·δ = σ·b + c`,
whereby `b = 1` if and only if `Δ > c`; and
(e) outputting a receipt and statement in which the verdict bit, an identity of
the classifier and the policy are public and the content tokens, the
activations and the margin remain hidden.

**30.** The method of claim 29, further comprising proving that every template
position holds its public template token by a clause carrying its own challenge
coefficient.
**31.** The method of claim 29, further comprising proving that no content
position holds a control token by including in each lookup tuple a public
control-indicator column, content positions being required to match table
entries whose indicator is zero.
**32.** The method of claim 29, wherein a verifier re-derives the margin vector,
the answer token ids, the threshold and the control-token set from the public
model export and tokenizer and rejects a statement that differs, before reading
any proof segment.
**33.** The method of claim 29, wherein the margin vector, an embedding table and
a head table are recomputed from a pinned tensor of a tied-embedding checkpoint
by a specified quantizer and compared with digests in the statement.
**34.** The method of claim 29, wherein the proof has a single external hidden
commitment, to the token sequence, and no output commitment.
**35.** The method of claim 29, wherein the threshold is `⌊ln(τ/(1 − τ))/κ⌋`, `τ`
being a probability threshold and `κ` the public scale of the margin.

### Set V — content labels, chunks, manifests, anchoring (aspects A10–A12)

**36.** A content distribution system comprising one or more processors configured
to:
(a) receive a content item and split its token sequence into chunks according to
a public chunk size and overlap;
(b) for each chunk and each category of a pre-registered list of categories, each
category having a fixed policy and threshold, generate a zero-knowledge proof
that an approved classifier applied to the category's policy and the chunk
yields a verdict bit, the chunk remaining hidden from verifiers;
(c) verify each proof and publish each accepted proof with its verdict;
(d) compute, for each category, a label of the item as the logical OR of the
chunk verdicts, a chunk lacking an accepted proof being treated as a positive
verdict;
(e) generate a signed manifest listing, for each chunk and category, at least the
verdict, a classifier identity, a policy identity, a digest of the proof
statement and an anchor reference, and attach the manifest to the item; and
(f) upon a request from a recipient belonging to an audience, deliver the item
only if its labels permit that audience, and otherwise deliver a placeholder
without the content.

**37.** The system of claim 36, wherein every chunk except the last covers
`[j·s, j·s + n)` with stride `s` equal to chunk size `n` minus overlap, the last
chunk is aligned to the end of the sequence, each proof absorbs its chunk index,
chunk count, range and total length into its transcript, and a verifier
re-derives the ranges and rejects any other range.
**38.** The system of claim 36, wherein each item is proved once per chunk and
category at creation and never re-proved at another threshold or policy, and a
re-check rejected by the verifier changes every label of the item to "not
proved" and causes the manifest to be re-issued.
**39.** The system of claim 36, further configured to compute, for each proof, a
leaf hash over the item identifier, category, chunk, token range, manifest
digest, statement digest, verdict, model identity, policy identity and a salted
content commitment, to build a sorted, domain-separated Merkle tree over a batch
of leaves, to record the tree's root on a blockchain, and to include each leaf's
Merkle path in the manifest, the proofs themselves being stored off-chain by
content address.
**40.** The system of claim 39, wherein the hidden-input commitment root of each
proof is excluded from the leaves and the manifest.
**41.** The system of claim 36, wherein the salted content commitment is a hash of
a domain label, a random salt, the content length and the content, the salt
being provided to permitted recipients, such that deleting the salt makes the
public record unlinkable to the content.
**42.** The system of claim 36, wherein the chunk size is selected from public
hardware profiles.
**43.** The system of claim 36, wherein the classifier proof is produced by the
method of claim 29.

### Notes for the attorney on the claims
- Sets I–IV are cryptographic methods tied to concrete technical effects
  (fewer committed elements, bounded verifier memory, rejection of specific
  forgeries, measured proof sizes and times); Set V is a system that uses them.
  Eligibility framing is the attorney's call.
- The building blocks named in §1.4 are prior art; the claims are drafted around
  the combinations and specific constructions.
- Set IV and Set V depend on items that are partly in progress (Shieldstral
  profile, tied-table binding) or built only with a stand-in prover (the app);
  the description covers them in enough detail to support claims, but the
  attorney should know their status (§2 table).

## 6. Figures to prepare

Described in words; each can be drawn as a block or flow diagram. Figure
numbers are suggestions.

1. **System overview.** Model owner → calibration → public integer export and
   model statement (digests). Prover (hidden input) → receipt segments +
   statement. Verifier (trusted export + profile) → accept / reject and writes
   the statement. Owner channel (private decommitment) shown as a separate
   dashed line. Public vs hidden data colour-coded.
2. **Integer block data flow.** The chain `x_in → norm → Q/K/V → RoPE → scores →
   softmax (max, exp table, row sum, quotient) → PV → Wo → residual 1 → norm →
   gate/up → SiLU table → product → down → residual 2`, with each requantization
   (shift + remainder) and each table lookup marked, and the single 256-entry
   byte table shown as the target of all range lookups.
3. **Commitment layout of one block.** A, H, M and the two endpoint commitments
   as row stacks: data rows, then one reserved mask pair per claim site, then the
   proximity pair; one arrow per claim site to its pair; "opened once" marked on
   each commitment.
4. **Transcript timeline of one block.** Header → A root → M root → β, γ, α → H
   root → 23 slots (private slots before their hosts) → M opening → A, H,
   endpoint openings; per-slot inset: absorb index, draw c, absorb one masked
   scalar, masked rounds, extension round, masked terminals.
5. **Hosting of a private claimed sum.** A private slot publishing
   `s + c·G` and its host zero-check absorbing `ν·eq(p, x)·V(x)`, with the
   batched correction `Γ_host`; the QKV split into three slots on two domains.
6. **LogUp with committed histograms and a zero-sum row.** Witness query
   helpers and table helpers combined into the zero-sum row `u`; the single
   value-0 sum claim on H.
7. **Multi-block run.** Stages 0 … L−1 with boundary commitments `B_k`, each
   claimed by two adjacent stages and opened in the later stage; the segmented
   receipt below, one segment per stage; derived boundary geometry
   `data + 2·sites + 2`.
8. **Disclosure gate.** Captured receipt → linear model of the view → rank per
   commitment (disclosed dimension) → zero-data preimage → negative controls.
9. **DD.** One attention row: score entries on the left, each with one tuple
   lookup arrow into the row's `cap` dictionary slots on the right; each slot
   with its exact-division proof; the public `e` column; counted savings vs `T`.
10. **Token-in stage.** Hidden ids → tuple `(tok_t, x̃(t, r_emb))` → lookup into
    the challenge-dependent table `(v, Ẽ(v, r_emb))`; `B_in` read at a partially
    fixed point; the BOS clause.
11. **Token-out stage.** Final norm → per-row int8 head with multipliers →
    virtual logits → keyed argmax (selector, maximum, difference limbs) →
    output endpoint → private decommitment to the owner and root check.
12. **Classifier verdict stage.** Template ‖ hidden content ‖ suffix with the
    template clause and the control-indicator column; normalized vector · margin
    vector → hidden `Δ`; verdict bit `b` in the transcript; limbs of `δ`; the
    MRG identity; no output endpoint.
13. **Chunking.** A token sequence with overlapping windows of size `n` and
    stride `n − o`, the end-aligned last window, and the per-category OR with
    fail-closed handling.
14. **Proof-carrying labels in the app.** Post → chunk → per (chunk, category)
    proof → fresh-process verification → publication record → batch Merkle tree
    → chain anchor; the signed manifest assembled from the entries and attached
    to the item; the distribution gate choosing content or placeholder by
    audience.
15. **Anchor leaf and batch.** Field layout of the leaf hash; the sorted
    domain-separated Merkle tree; the anchor call.
16. **Tied-table recomputation.** Pinned checkpoint tensor → quantizer →
    embedding / head / margin digests → comparison with the statement →
    accept / refuse.
17. **Measured results.** A table or bar chart of §3.15 (prove, verify,
    receipt size for TinyLlama and Llama-3-8B), labelled "one laptop, n = 1".

## 7. Inventorship and prior-disclosure checklist

This is a list of facts for Victor to confirm and give to the attorney. It
records what the repository shows; where the repository cannot answer, it says
so. It is not legal advice.

### 7.1 Possible prior disclosures (the attorney must know about each)

| # | Item | What the repository shows | What Victor must tell the attorney |
|---|---|---|---|
| 1 | **Tech Week SF demonstration, prepared 2026-09-29 (PDT)** | `docs/zkmatrix-poc/ZK60_TECHWEEK_DEMO.md` and the "VC readiness snapshot for Tech Week SF" in `MVP_STATUS.md`: a local browser demo verifying two 785-byte Groth16 receipts (zkVM line: a tiny complete block and a synthetic two-block token model), tamper rejection, and a live native proof of the toy private block (2,816,472 B) with a public synthetic input. A two-minute talk script and a demo script exist (`results/zk60_vc_readiness_20260929/`). The repository does **not** record whether the demo was actually shown, to whom, or what was said. The trained models, DD, token stages at scale, classifier verdict, chunking, labels app and anchoring did not exist yet on that date. | Date(s), venue, audience, whether under a confidentiality agreement, any slides, handouts, recordings or follow-up emails, and how much of the construction was explained. |
| 2 | **Other showings or conversations** | A presenter kit for the 8B next-token demo exists (`results/zk60_token_io_r1_20261017/DEMO_PRESENTER.md`, 2026-10-20). Funding drafts exist (YC W27, Foresight, NSF pitch, others under `results/zk60_funding_20261028/`; deadlines Oct 31 and Nov 2). | Every meeting, call, application or message in which the technology was described, with dates, and any confidentiality terms of each application portal. D43 records that private applications are not blocked by the filing; the attorney should confirm. |
| 3 | **GitHub repository** | The checkout's remote is `github.com/VictorRielly/IntelligenceRegulation`. Its visibility (public or private) cannot be determined from the checkout; no network check was made for this draft. The root `README.md` invites readers to clone the repository and mentions the Tech Week demo. The ledgers record pushes of lane branches since August 2026 and, on 2026-10-17, a branch `snapshot/20261017-uncommitted` holding all uncommitted work since 2026-09-23. Much of the October work (`ops/`, `apps/`, many `results/` directories, several design docs) is untracked on the current branch; whether copies exist on other pushed branches was not checked (no git commands were run for this draft). | **Checked by the coordinator 2026-10-28 (`gh repo view`): the repository is PRIVATE** (`isPrivate: true`). Still for Victor: whether it was ever public (and when), whether any fork or collaborator access exists. If it was ever public, every commit pushed in that period is a dated public disclosure of what it contains. |
| 4 | **Shared ChatGPT conversations** | Four ChatGPT share links created by Victor on 2026-10-18/19 (titles "Literature Review Exponential ZKPs", "Explaining grouped lookup proofs", "Optimize Lookup Table Size", "Optimize Softmax Division Proofs"); URLs recorded in `results/zk60_gpt_nonlinear_review_20261018/SOURCE.txt`. They concern Victor's separate "expzk" gadget work; one contains the general "observed-pair quotient dictionary" idea that DD (A5) adapts. Share links are viewable by anyone who has the URL. | Whether the links were posted anywhere; whether to keep or disable them (attorney's advice). |
| 5 | **AI services used to develop the work** | Development used Anthropic Claude (Claude Code sessions and subagents), OpenAI Codex / GPT agents ("Sol", "Astra"), Grok via Cursor, and ChatGPT conversations. Design text and code passed through these services. | Which accounts and plans were used (some services' terms differ on data use and confidentiality); the attorney decides whether this matters. |
| 6 | **Publications and releases** | The repository records no preprint, ePrint, arXiv post, conference submission or open-source release of this work; D43 plans a paper after the PoC, and an open-source release of the verifier, specification and benchmarks for grants that require it. | Confirm nothing was published. Note that releasing the verifier publicly would disclose the proof's structure; the filing should come first (D43). |
| 7 | **Other external contact** | Model downloads from Hugging Face; an hourly research agent runs literature and GitHub searches (its queries may contain technical terms); the Base Sepolia testnet publisher has broadcast nothing; Victor's rulings reached the agents through a private Telegram bot. | Anything else shown or sent outside the laptop. |

**Timing points to confirm with the attorney** (general facts, not advice):
- The US allows a one-year grace period for the inventor's own public
  disclosures before filing; many other jurisdictions (for example the
  European Patent Office) have no general grace period, so any public
  disclosure before the filing date can bar patents there.
- A provisional application establishes a priority date only for what it
  describes; a non-provisional application (and any international application)
  must follow within twelve months to claim it.
- USPTO filing fees for a provisional are small (the funding plan records
  $65–$325 depending on entity size); attorney time is the main cost.

### 7.2 Inventorship

- **Named human:** Victor Rielly is the only human the repository records as
  directing the work and making product rulings. Victor should confirm that no
  other person (collaborator, advisor, Tech Week contact) contributed to the
  conception of any aspect.
- **AI-assisted development.** Most constructions, designs and code were
  drafted and implemented by AI agents under Victor's direction: Claude models
  in Claude Code sessions and subagents, and OpenAI Codex / GPT agents. For
  example, the private attention construction memo names a Claude agent acting
  as "security owner" as its author; the token-endpoint and classifier designs
  were written by Claude lanes; native prover round R12 and the tied-table code
  (R12b) by an OpenAI "Sol" agent; the app by Claude and "Astra" lanes. Each
  ledger names its lane. DD's starting idea came from a ChatGPT
  conversation Victor held; the privacy-safe form (public `cap`, every slot
  proved, hidden multiplicities) was worked out in the repository's review.
  The decisions register records which rulings Victor made: P1/P3 scope (D1),
  the MVP boundary (D13), the token-endpoint product rulings (D25 T1–T8), the
  soundness tier and selectable-tier direction (D27), the fidelity target
  (D32), the media application, classifier choice and verdict statement,
  modalities and anchoring direction, and chunking (D37–D41), and the
  provisional-first rule (D43). The attorney should apply current USPTO
  guidance on AI-assisted inventions claim by claim; Victor should be ready to
  describe, for each aspect, what he conceived and when.
- **Employment and ownership.** Victor to confirm whether any employer or
  contract has an invention-assignment clause that could reach this work, and
  whether any employer resources were used. The funding plan records an
  intention to form a Delaware C-corporation; an assignment of the application
  to the company would follow.

### 7.3 Dates useful as evidence (from the register and ledgers)

| Date (2026) | Event |
|---|---|
| 09-09 | Privacy scope P1 / P3 decided (D1) |
| 09-16 | Private attention construction written (A1–A4 schedule) |
| 09-18 | Native private attention compiled and proved at toy scale |
| 09-19 | Block composition rule D12; private block built; D16, D17, D18 |
| 09-20 | Multi-block private run built (D12a); toy privacy accepted (D22) |
| 09-29 | Tech Week demonstration prepared |
| 10-17 | Trained-model profiles and norm rule (D24); token I/O design and rulings (D25, D26); soundness tier (D27) |
| 10-18 | First private next-token proof of a trained model (TinyLlama) |
| 10-19 | Llama-3-8B next-token proof; DD admitted (D30); trained-run privacy accepted (D33) |
| 10-20 | DD built (native R9) and accepted on soundness |
| 10-21 | Next-token privacy accepted (D36); media app, classifier, multimodal, chunking directions (D37–D41); classifier design; app built with stand-in prover |
| 10-26 | Classifier verdict stage (R-C1) frozen; Shieldstral prover features (R12) frozen and reviewed with fixes |
| 10-28 | Privacy gate round 17 on classifier captures; tied-table binding (R12b) in progress; provisional-first ruling (D43) |

Victor should preserve the repository history, ledgers and register as they
are (they carry these dates).

### 7.4 Open questions for the attorney

1. One provisional covering all thirteen aspects, or separate filings (for
   example, the cryptographic core vs the content-label application)?
2. Whether to attach source files or design documents as appendices to the
   provisional to strengthen the written description.
3. Patent-eligibility framing for the cryptographic method claims and the
   content-distribution system claims.
4. The effect of the possible disclosures in §7.1 (Tech Week, GitHub
   visibility, ChatGPT share links) on US and foreign filings.
5. Inventorship given AI-assisted development (§7.2).
6. Timing of the planned open-source release of the verifier and
   specification, and of the paper (D43), relative to the non-provisional.
7. A professional prior-art search, in particular on zero-knowledge machine
   learning (the systems in §1.4), lookup-argument dictionaries, and content
   credentials / provenance manifests.
8. Foreign filing (PCT) plans and budget.

## Appendix A. Source documents in the repository

All paths are relative to the repository root
(`/home/victor/IntelligenceRegulation/`).

| Topic | Documents |
|---|---|
| Overview, status | `docs/zkmatrix-poc/START_HERE.md`, `docs/zkmatrix-poc/MVP_STATUS.md` |
| Rulings | `docs/zkmatrix-poc/ZK60_DECISIONS.md` (D1–D43) |
| Private attention / block | `docs/zkmatrix-poc/ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md`, `ZK60_PRIVATE_BLOCK_CONSTRUCTION*.md` |
| Native prover (Rust) | `ops/zkp-mvp/trained-1b/zkp-core/src/{field,pcs,sumcheck,transcript,tables}.rs`; `ops/zkp-mvp/trained-1b/hashline/src/{zk,norm,chain,tables_attn,private_attention,private_seam,private_block}.rs`; `hashline/src/private_block/{argument,layout,protocol,run,boundary,endpoint_g,pad,hash_domain,rope,shape,trained_block,trained_statement,tied_tables,slot_ir}.rs` |
| Native ledger | `results/zk60_1b_native_20261017/PROGRESS.md` (Rounds 9–12) |
| DD | D30; `results/zk60_gpt_nonlinear_review_20261018/REVIEW.md` §R2.4; `dd_check/CHECK.md` |
| Token endpoints | `results/zk60_token_io_design_20261017/DESIGN.md`; `results/zk60_token_io_r1_20261017/PROGRESS.md` |
| Classifier | `results/zk60_token_io_r1_20261017/classifier/DESIGN_CLASSIFIER.md`; `classifier/check/CHECK.md` |
| Privacy statements | `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_TRAINED_TINYLLAMA_T32.md` (D33), `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_NEXT_TOKEN_TINYLLAMA_T32.md` (D36) |
| Fidelity | `results/zk60_fidelity_parity_20261019/REPORT.md`, `S2_BUILD_SPEC.json` |
| Media app | `apps/proven-media/README.md`, `apps/proven-media/DESIGN.md`, `apps/proven-media/TESTNET.md` |
| Anchoring | `results/zk60_chain_publication_20261021/REPORT.md` |
| Tied tables (in progress) | `docs/zkmatrix-poc/ZK60_SOL_ASTRA_TODOS_20261026.md` (S1b) |
| Literature notes | `docs/zkmatrix-poc/AGGREGATION_LITERATURE.md`, `PROVING_CHANNEL_OPTIONS.md`, `M4_LOOKUP_LITERATURE.md` |
| Demonstration | `docs/zkmatrix-poc/ZK60_TECHWEEK_DEMO.md` |
| Funding plan | `docs/zkmatrix-poc/ZK60_FUNDING_PLAN.md` |

*End of draft. Draft for patent-attorney review — not legal advice.*
