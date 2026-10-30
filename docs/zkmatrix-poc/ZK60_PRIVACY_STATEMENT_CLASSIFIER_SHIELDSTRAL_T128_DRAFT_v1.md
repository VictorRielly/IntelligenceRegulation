# Privacy statement for the Shieldstral-1.0-3B classifier proof (T128, native R13, public-row, verdict as a public bit) — DRAFT v1, for independent privacy review (NOT accepted, NOT in force)

Drafted 2026-10-29 from 21:37 UTC by the PRIVACY GATE lane (a delegated Claude Opus 5.5 agent, gate round 21), at
the coordinator's request. It follows the form of the two statements in force, D33
(`docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_TRAINED_TINYLLAMA_T32.md`) and D36
(`docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_NEXT_TOKEN_TINYLLAMA_T32.md`). It is a separate draft beside them, not an
edit of either, and it extends neither.

| Status | **DRAFT v1. NOT accepted, NOT in force, and NOT a privacy acceptance. Nothing on this page establishes a privacy property.** It proposes a sentence for one classifier run and lists what that sentence rests on, what is measured, and what is still owed. Next: an independent privacy review round (as privacy reviews 4–6 were for D33 / D36), then the security owner's decision, then Victor's acceptance. **The policy wording is pending Victor's strict / moderate ruling: this page names the policy list as a parameter and evaluates it at the registered moderate list.** |
|---|---|

**Labels.**

- [MEASURED]: a run happened and a record is cited. Laptop, shared box, one run unless stated.
- [COUNTED]: exact arithmetic from the code and the captured geometry.
- [READ]: a fact read in a cited source line, record or document.
- [ARGUED]: an argument that survived independent attack in D33's / D36's record (the reviews named there). It is
  carried here only where the classifier stages and the R13 blocks do not change it.
- [MINE]: my own reading or arithmetic for this page, checked by nobody yet. The privacy review should attack these
  first.

**Sources.**

- **EV** is `results/zk60_gate_tinyllama_20261017/` (the gate lane), ledger `EV/PROGRESS.md`.
- **The token lane** is `results/zk60_token_io_r1_20261017/` (design `classifier/DESIGN_CLASSIFIER.md` v2.7, §§1–6,
  14–18; CLI notes `cli/README.md`); its code reviews are in `results/zk60_token_io_review_r1_20261017/`
  (`REVIEW_R13.md`, `REVIEW_R14.md`, `REVIEW_R16.md`).
- **The native R13 review** is `results/zk60_d24_review_20261017/REVIEW_R13.md` (soundness, not privacy).
- **The register:** D1, D19 / D19a / D19b, D20, D21, D23, D29, D33, D34, D36, D37–D41, D45
  (`docs/zkmatrix-poc/ZK60_DECISIONS.md`).

---

## 0. In plain words

### What would be claimed

A media app proves, for each post and each of three fixed categories (sexual / explicit, graphic violence, hate /
harassment: D37), "the approved integer version of Shieldstral-1.0-3B says this post is [flagged / not flagged] under
this category's policy". One proof covers one chunk of the post under one category (D41): the template, the post's
tokens, all 26 transformer blocks, the final norm and the yes-minus-no margin against the policy's threshold, under
one transcript.

Consider anyone who checks such a proof and is given the public facts listed below. **This page would claim that the
proof itself tells them essentially nothing more about the post.** In numbers: what they see is within a statistical
distance of about **2^-68.19 per proof** (about one chance in 3 × 10^20) of something that could be produced without
the post at all, from the public facts alone.

### What is public, and what stays hidden

**Public** (in the run's published statement, or derived by every verifier from public files):

- **the verdict bit** (flagged / not flagged);
- the model: Shieldstral-1.0-3B by digest, its integer export (profile `2ba468f9…`), the trained-model identity
  `29aeba6c…` and the 26 per-layer gate denominators;
- the policy (one of the three registered ones), its template token ids, the threshold c = 0, the "yes" and "no" token
  ids;
- **the content length in tokens, n** (D45(1)), and with it the item length, the number and positions of the trailing
  pad tokens (id 11) and the row the verdict is read at;
- **the chunk facts** (D41): which chunk of how many, its token range, the post's total length;
- the input endpoint root (the proof's sealed fingerprint of the token plane; D45(3) anchors it beside the post);
- the context, the run and block profiles, the 96-bit whole-run soundness floor.

**Hidden** (never given to the verifier, and — this page's claim — not learnable from the proof beyond the distance
above):

- the post's token ids and their embedding rows;
- every activation of all 26 blocks, at every position, the pad rows included, and the planes between blocks;
- the final-norm values, the margin itself (how strongly the model said yes or no) and its range limbs.

### What the public facts themselves reveal (not the proof's doing)

The page bounds what the **proof adds** to the public facts. It does not make the public facts harmless:

- **The verdict is a yes / no answer about the hidden post.** The model is public, so anyone can compute the verdict
  for any candidate text. Three categories give three such bits per chunk; D45(2) fixes the list so that no item is
  ever asked a fourth question.
- **At small n the verdict says a lot.** At n = 1 the verdict is a function of one hidden token id, one of 130,072
  possible ids (the vocabulary of 131,072 minus the 1,000 control ids). The published bit tells a reader which of two
  sets the id is in, and the model, being public, tells them the sets.
- **Per-chunk bits are public** (D41): a "flagged" label also shows which part of the post triggered it. An edited
  post re-proved shows which edit flipped its verdict.

### The refusal channel, stated plainly

**Whether a post gets a proof at all can depend on what the post says.** The honest prover stops before it writes any
proof when an activation of the post — or of the pad rows after it — leaves one of the R13 stack's fixed integer
ranges (the norm word in int16; the widened words in [-32768, 32767]; the attention score in [-127, 127]; the gate
word in [-2048, 2047]; the norm and softmax denominators and their remainder windows), or when a content position holds
a control token. Such an attempt yields no proof and nothing for a verifier to see. Under D45(4) the app then shows the
post as **"could not be verified"** and does not publish it.

So **someone who sees "could not be verified" learns that one of these ranges was left, or a control token was
present: a fact about the hidden content.** The proof system adds nothing to that fact (there is no proof), but the
fact itself is public in the app. What is known about how often it happens:

- on a development calibration of the same arithmetic, 102 of 300 vocabulary ids each made an item refuse (gate round
  19, R19-1) [MEASURED];
- on the real model, every real proof attempted so far proved: one 35-token post under all three policies (token round
  16) and the gate's re-prove of it (round 19) [MEASURED, 4 runs];
- the export lane's integer replay of the same arithmetic saw no range refusal on its 192 calibration sequences through
  all 26 layers, and none so far on 4,872 benchmark items through layers 0–5 [READ, the export lane's report; not the
  prover, incomplete];
- **the refusal rate on real posts is not measured.**

For an accepted proof, the one refusal that can still happen after the proof has started (a lookup denominator that
happens to be zero) is priced inside the distance: at most **2^-108.25** per proof.

### Which code, model and policies

- **Code:** the token lane's frozen trees **frozen-r16b** (binary `zk60_classify.r16b.release.bin`, `dfb8025e…`) and
  **frozen-r17** (binary `zk60_classify.r17.release.bin`, `81bd8624…`; its changes from r16b are test-only). CPU path
  only. The 72 source files a capture pins.
- **Model:** Shieldstral-1.0-3B (`mistralai/Shieldstral-1.0-3B`, checkpoint sha256 `87753e30…`), the T128 integer
  export `results/zk60_shieldstral_export_20261026/native_low_h24_t128` (profile.json `2ba468f9…`), trained-model
  identity `29aeba6c…`.
- **Policies:** the three registered moderate-wording category policies (§1). **The wording is Victor's open ruling.**
  A strict ruling replaces the three entries; this page is then re-evaluated at the new list (§9).

### What has been measured

- **Gate round 20** [MEASURED]: the real moderate-hate run, captured with its public tables, passes the classifier gate
  with **no declared limit**: disclosed dimension 0 on every A, endpoint and boundary commitment and exactly the expected
  2 on every H (84 commitments); the **full** zero-data preimage of the verifier's view (81,731,058 entries, 0
  differing); masks 0 of 440,221 entries differing; the joint figure 0; all 23 block slots in each of the 26 blocks;
  15 + 7 controls fire.
- **Gate round 19** [MEASURED]: the gate's own fresh re-prove (moderate-sexual) by the named r16b binary, and 13
  development-rung captures (verdict 0 / 1 / tie, two chunks, short items at n = 1, 11, 22): all pass.
- **Gate round 21** [MEASURED]: the 15 public block tables per block (17 arrays) that rounds 19 / 20 took from the
  capture were **derived again by the gate from the export: 442 of 442 arrays equal, byte for byte, in all 26
  blocks**, the SiLU tables checked against four independent sources (§3 step 3); the per-run distance figure was
  counted (§4); the owner checks were recorded (§3 step 4).

### What is still open (§10)

The independent privacy review; Victor's strict / moderate ruling; the stage-47 draw replay and NL-1's full battery on
the R13 and classifier slots (§10); owner checks at n ≠ 35; the security owner's decision and Victor's acceptance.

---

## 1. Scope — what a statement would cover

| | |
|---|---|
| Run profile | `hashline-zk-mr1/private-classify-run-shieldstral-3b-t128-r13-public-row/1` (token frozen-r16b / r17 `token_io/run.rs`). Mode: **verdict as a public bit**, variant public-row (the item fills positions 0 … item_length − 1; trailing positions hold the public pad id) [READ] |
| Block profile | `hashline-zk-mr1/private-block-shieldstral-3b-t128-lowh24-blocks/1` (shape `R13_SHIELD_T128_H24`: accuracy stack LOW + h24, non-DD). T 128, width 3072 (padded 4096), hidden 9216 (padded 16384), 32 query heads, 8 key-value heads, head_dim 128 (RoPE YaRN, factor 16), columns 2^14 at rate 1/4, Q 256, 23 slots [READ, run.json `shape`] |
| Form | **One classifier run**: stage IN-C, 26 R13 blocks, stage OUT-C, **one** external endpoint (the input token endpoint, 2^8 words at rate 1/8, 6 rows) and **no output endpoint**; the verdict b is a public bit absorbed into the header and placed in the margin slot's public right-hand side (D40). 28 segments, 848,412,096 B per receipt [READ; MEASURED] |
| Model | Shieldstral-1.0-3B, checkpoint sha256 `87753e30c8c321da478b83bbabebcd813cc9b3d0cee5c5b3d64349a8ee4172f7` (revision `003ec7e2…`), tied tensor `language_model.model.embed_tokens.weight` `67a138c1…`. Export variant `shieldstral-s2-fixed-low-h24-t128-v2`, `profile.json` sha256 **`2ba468f98085caf1136f27cf66220f93d8e316acb8dbae7e98f9eb68347f05a0`**; trained-model identity **`29aeba6c04a819cdbafde311f7c9d0c678d85aff22292ae6b9647761158a0bd1`**; per-layer gate denominators G = [19, 19, 18, 20 × 7, 19, 20 × 3, 19, 20 × 8, 19 × 3]; embedding digest `1cb276d1…`; margin-vector digest `6429a242…`; margin scale 4.08288030735373e-6 (bits `0x3ed11ff597db2fb6`) [READ; MEASURED in gate rounds 19–21] |
| **Policies (a parameter)** | The fixed list of D45(2), evaluated here at the registered **moderate** wording: `shieldstral-1.0-3b-moderate-sexual/1` (P0 72, chunk 55), `shieldstral-1.0-3b-moderate-violence/1` (P0 72, chunk 55), `shieldstral-1.0-3b-moderate-hate/1` (P0 78, chunk 49); suffix `[/INST]` = [4], S = 1; yes 13059, no 2649, c 0; pad id 11; control ids < 1000; V 131,072; tokenizer tekken.json `ceb11e85e44d7c91` (plain-text encoder). Exactly three policies are admitted at this profile; the model card's `card-unsafe/1` is test-only since r16b (REVIEW_R16 F-1, fixed) [READ]. **Pending Victor's strict / moderate ruling.** |
| Item lengths | 1 ≤ n ≤ the policy's chunk size (55 / 55 / 49 at T128). A post longer than that is split into chunks by D41 (overlap 8, end-aligned), each chunk its own run. item_length = P0 + n + S; pad positions = 128 − item_length; verdict row = item_length − 1 [READ] |
| Binaries | **r16b** `results/zk60_token_io_r1_20261017/cli/zk60_classify.r16b.release.bin`, sha256 **`dfb8025eb903b203f4b50371fdd0dd00659d46a9dbaad9d121d6a68343ebc70c`** (built from frozen-r16b; the app's binary); **r17** `cli/zk60_classify.r17.release.bin`, sha256 **`81bd86248e9f42393c9fe739e6794b7af155ad9a0a06874c89efb7a7bba18317`** (built from frozen-r17). CPU only (no gpu-cuda) [READ]. The round-16 binaries (`e94cecf9…`, which proved the hate receipt in evidence, and `dae5abd7…`) still admit the card policy and are **not** in the sentence; the hate receipt they made is used as evidence because r16b changes only the policy list and tests, and r16b and r17 re-verify it with an unchanged statement (§3, Step 1) |
| Code | **frozen-r16b** (`results/zk60_token_io_r1_20261017/frozen-r16b/`, 301 files, manifest list sha256 `04d94bc0904ccaeb621d001b72be51b54034bfb5f7135a543e872a36a834c549`) and **frozen-r17** (303 files, list sha256 `23a958766cf946d07b35e93e1f82685c3f952e5526a99f4d389be766881dd9a2`; six paths moved, all `#[cfg(test)]`). Native base: R13 (`bb9eb212…`). **Condition 7's pin set is the 72 files a classifier capture pins**, accepted by the gate's v23 rule (`zk60_native_rg_classpins.classify_capture_pins_v23`): every one read across native R12b → R13 and token r14 → r16b → r17, none moving a receipt, block-stage or statement byte at a profile captured before (gate rounds 19 / 20 [READ] lists). No commit; a frozen copy with its pins is condition 7's object, as for D33 / D36 |
| Path | **CPU only**, as an operating rule. No GPU-built classifier receipt was captured or gated |
| Lengths in evidence | the real item n = 35 (14 / 20 / 20 trailing pads under hate / sexual / violence); the development rung at n = 1, 11, 22, 23 and a two-chunk item (gate round 19, L = 1 and 2 at the R13 h24 rung) |
| Hash rule | D19a's keyed BLAKE3 (`blake3-keyed/1`), the run transcript separated by the run-profile string (D17) [MEASURED in every record] |
| Tools | gate tools **v22** (`EV/gate-tinyllama.tools.frozen.v22.sha256`, `ab703596…`) and **v23** (`64f4b757…`, 80 files); round 21's scripts under `EV/round21/` |

**Not in scope; each owes the argument again:**

- the T256 profile (registered, never proved or captured), any DD profile (none registered for the classifier), any T
  other than 128;
- any other export, calibration or model, and any other policy wording or list (a strict ruling, §9);
- the round-16 binaries, any rebuild not named here, and the GPU path;
- images (D39's text-and-image scope: the Pixtral encoder is not proved), hidden weights (P3);
- what a holder of the input opening learns (the app; D45(3)); the delivery of that opening (not built);
- **the classifier's quality** (fidelity is the export lane's benchmark, D32) and **soundness** (the native R13 review
  and the token code reviews).

## 2. The statement (proposed sentence — not in force)

> In the random-oracle model for BLAKE3 (D19), read as BLAKE3's compression function being ideal also at a chaining
> value the adversary knows (D19b), and assuming the prover's generators' joint output is indistinguishable from uniform
> (E-1; X-1 across runs), consider a verifier who:
>
> - receives an **accepted** classifier run of the profile in §1, written by the frozen-r16b or frozen-r17 code (the
>   CPU binaries `dfb8025e…` / `81bd8624…`), under one policy of the registered list Π (today the three moderate
>   category policies);
> - receives it bound to its trained-model statement (`29aeba6c…`) and its classifier profile;
> - has the export, the tied tensor, the template and policy texts, the context label and the tier fixed before and
>   independently of any hidden content;
> - is not the holder of the run's input opening;
> - makes at most q ≤ 2^128 hash queries.
>
> That verifier is never given any of the following, and its view is within about **2^-68.19 per run** of a
> distribution that is computed from the public facts alone — the verdict bit b, the policy, the content length n and
> the chunk facts (D41), the model and the profiles — and depends on none of them:
>
> - the content's token ids and their embedding rows;
> - the activations of all 26 blocks at every position, the pad rows included, and the internal boundary planes;
> - the final-norm values, the margin and its range limbs.
>
> This holds for every **admissible** item.
>
> Whether an attempt on an admissible item is refused **after** its header is not a function of the challenges
> alone: it may depend on the hidden content with probability at most **2^-108.25** per run, a two-world distance
> counted in the figure above (D34 / D40, recounted at R13). **Whether an item is admissible at all is a function of
> its hidden content** (the range refusals before the header, and a control id at a content position): an
> inadmissible item gets no proof and no view, and under D45(4) the app shows it as "could not be verified". That
> outcome is a public function of the hidden content; it is not counted in the distance.

**The assumptions, in plain words.**

- **Hash.** BLAKE3 behaves like a random function (the random-oracle model, D19), keyed per role (D19a), and its
  compression function stays ideal even where an adversary knows the chaining value (D19b). Every Merkle leaf is salted.
- **Fiat–Shamir.** Every challenge is a hash of everything sent before it, under the run-profile domain (D17); that is
  sound and zero-knowledge-preserving only inside the random-oracle model above.
- **The commitment (PCS).** The Ligero-class hiding commitment hides because each committed row carries mask rows and
  per-column salts, and the number of pads equals the number of opened columns (D33's conditions 1–6); this page uses
  only its hiding. Its binding and the whole-run soundness (96 bits at T128) are the soundness reviews' (native R13,
  token R13–R16), not this page's.
- **Randomness.** The prover's generators' joint output is indistinguishable from uniform (E-1), independently across
  runs (X-1); the operating system's random source is sound.
- **No external audit.** Like D22 / D33 / D36, the argument has been drafted and attacked inside the project (the gate
  lane, an independent privacy review lane, the security owner). No outside cryptographer has audited it, and it is not
  a machine-checked proof.

**Accepted** means the party who publishes the run has verified it itself in a fresh process, with the named binary's
`verify`, which writes the run's `/3` statement from its own data ("statement_written_by: zk60_classify verify, after
its fresh-process verification of the run directory, from its own data") [READ, the hate run's statement]. This is
D33's Q-3 rule, transposed.

**Admissible** means the item passes the classifier run's sealing predicate. Every part of it is checked **before the
run header** [READ, REVIEW_R16 §§2–8; gate round 19 §6(b)]:

1. the CLI's door: the policy is one of Π, the profile and the trained identity are the bound ones, the content ids are
   < V and none is a control id (< 1000), n is within the chunk size and the chunk is the D41 split, the item is laid
   out as template + content + trailing pads at id 11, the whole-run floor (`--min-bits`) is met;
2. the export and the tied tables are re-derived from the pinned checkpoint and the bound profile (R-C2: the margin row
   and the embedding never come from a file);
3. the sealing pass at every block's **own** stage shape (native `fit_the_stages`): the witness builder's integer
   ranges (the R13 norm word in int16; the widened words y, nm, q, k, v, qr, kr, o in [-32768, 32767]; the score in
   [-127, 127]; the gate word in [-2048, 2047]; the h24 product and residual words; the norm and softmax denominators
   and remainder windows), CS-1 / CS-4 / CS-6, CS-3 (lookup misses) and the activation parity against the item's
   per-layer activations;
4. stage IN-C's and OUT-C's lookup checks and the final norm's ranges.

**What can still fail after the header:** a zero LogUp denominator (D34's event, priced at 2^-108.25), a file that
changes between the two passes, and I/O errors. None can be provoked by choosing the content: the denominator event
needs the challenges to hit. Even then nothing is published: segments are held until the run returns Ok, and leftovers
are refused by name at the next `prove` (as D36 §2) [READ, REVIEW_R16; D29 / D21].

## 3. What it rests on, step by step

Each step names what D33 / D36 established, what is **new** for the classifier stages and the R13 blocks, what is
MEASURED, and what is OWED.

### Step 1 — a reference item proves and verifies; the receipts in evidence

- **New here.** The classifier run has template positions with public ids, content positions, and trailing pad
  positions with the public id 11. As in D36, the all-zero-**data** preimages of step 3 are linear statements about
  blinding and need no admissible all-zero item [ARGUED in D36, MINE for the classifier].
- **MEASURED.**
  - The real 35-id ToxicChat post proves under all three policies (token round 16, binary `e94cecf9…`; 439–456 s,
    peak 8.08–8.27 GiB) and verifies in fresh processes; verdicts not-flagged.
  - The hate receipt re-verifies under r16b and r17 with an unchanged statement (identity `29aeba6c…`; REVIEW_R16
    §6; token round 17).
  - The gate's own fresh re-prove of the post under the moderate-sexual policy by the **named r16b binary** (gate
    round 19: 469 s, 8.13 GiB, 848,412,096 B; verify 74.6 s) [MEASURED, `EV/round19/cap/real/`].
- **OWED.** Nothing for this step.

### Step 2 — per commitment, the linear view discloses nothing (G-R1)

- **Argument of record:** the generic rank lemma as D33 / D36 carry it [ARGUED]: a lemma about commitment geometry
  (rows, reserved pairs, groups, the proximity pair, pads = opened columns).
- **New here.** The R13 block commitments are larger (A 4,577 rows / 4,283 data; H 4,390 / 4,282), the classifier
  stages have their own geometry (IN-C A 41 / 33, H 76 / 68; OUT-C A 76 / 16, H 38 / 18, at 2^12 columns), the
  boundaries 38 rows / 32 data at 2^14, the token endpoint 6 rows / 1 data at 2^8 [READ, the capture's stage files].
  There is no output endpoint.
- **MEASURED** (gate round 20, frozen v23, the real hate run; round 19 the same per kind on the sexual run):
  - 84 commitments: **disclosed dimension 0** on every A, every boundary and the input endpoint; **2** on every H (the
    exact public LogUp zero-sum relation);
  - the 28 masking commitments 0;
  - the endpoint: certifying minor full rank, pad block full rank (242 distinct opened columns), k0 = 0, exclusivity
    holds; B_in's and B_out's reserved blocks full rank; the claim points (G-2) accepted.
- **OWED.** Nothing by this page's evidence rule.

### Step 3 — the gate constructs blinding that reproduces the view under all-zero data

- **The machinery:** tools v22 / v23: the classifier replay (every challenge re-derived), the classifier slots'
  terminal identity with every public table rebuilt, the R13 block-stage terminal identity, the masking layer (G-3),
  the word-level joint, and the full zero-data preimage with the joint assignment.
- **MEASURED, the real hate run** (gate round 20; `EV/round20/v23/v23-classify-r13-shield-t128-cli-hate-r17-values.json`,
  `e94d6e7b…`; 14,605 s, 6.47 GiB, alone):

  | | |
  |---|---|
  | Status | **PASS, no declared limit**, 0 false parts, 0 unfired controls |
  | Replay | run binding reproduced; 3,303 positions and 263,324 challenges re-derived |
  | Hash layer | 28,672 opened columns re-hashed and authenticated (482.8 MB), keyed rule |
  | Full zero-data preimage | **all 84 commitments, 81,731,058 view entries, 0 differing**; 21,504 salted leaves authenticated |
  | Joint preimage | all four couplings respected (C4 with the block stages) |
  | Masking layer (G-3) | 0 of 440,221 entries differ |
  | Joint figure | 0 over 1,052,800 word pairs (0 = the sum of the parts; by ruling R-3 a consistency check, not evidence of independence) |
  | Classifier slots | 12 / 12 terminal identity; **19 public tables rebuilt, none taken**; the margin vector and the embedding derived by the gate from the 7.7 GB checkpoint, bit-exact (B-3) |
  | Block stages | **23 / 23 slots in each of the 26 blocks**, each at its own G; 15 statement tables per stage TAKEN from the capture (see below); 7 R13 controls fire |
  | Controls | CC-1..CC-6, CC-8 / CC-9, C13-1..C13-4 at pad id 11, J-1..J-3 fire |

- **The 15 block tables per stage are no longer taken on trust** (gate round 21, this page's new evidence). Rounds 19 /
  20 took, per block stage, the seven weight folds (with the R13 multipliers), gamma_a / gamma_m, the RoPE pairs on Q
  and Kv, the group column, the exp table, the ACT3 table and its support from the capture and checked their length,
  digest and structure; that they are the **export's** was only the token recorder's own attestation. Round 21
  **derives all seventeen arrays again in the gate**, from the export's arrays and the slot's own public challenges,
  with its own exact arithmetic (no token-lane code imported or run), and compares them byte for byte with the capture
  (`EV/round21/derive_block_tables.py`):
  - the export is pinned: each array's SHA-256 against its layer manifest, each manifest against `profile.json`, and
    `profile.json` against the run's `2ba468f9…`;
  - the gate fold coefficients c_j = m_j 2^(G − s_j) and G_k = max(s_j, 17) are rebuilt from the groups, and G_k is
    compared with each stage line's;
  - **the ACT3 rows are checked against four SiLU sources**: a float64 transcription of the definition
    (`silu_table_for`, including the Shieldstral (0, −8) member), Sol's reference formula (`reference_silu.py`,
    transcribed; that script writes into Sol's tree and covers only the nine standard members, so it was read, not run),
    an exact 60-digit Decimal evaluation (which also measures how close any word comes to a rounding tie), and the native
    tree's reference vectors `r13_vectors/silu_*.bin`; the exp words against `exp_table_generate` and an exact
    evaluation;
  - eight non-vacuity controls C21-1..C21-8 (a weight, a multiplier, a gate coefficient, the challenge point, the sin
    sign, one SiLU word, G_k, the neighbouring layer's export) each break exactly the tables they touch.

  **[MEASURED, all 26 blocks]** (`EV/round21/derive/DERIVE_ALL.json`, `5c2c7111…`; guarded cpu 0.5 / 1.0, 22.9 s,
  peak RSS 0.29 GiB, 2026-10-29 22:45 UTC):
  - **442 of 442 arrays equal by SHA-256 and byte for byte** (17 per block × 26; 118,210,560 field entries);
  - the store itself re-hashed equal to the capture's manifest (2,253,896,728 B), the stage files and run.json too;
  - **G_k derived from the export equals the stage line in all 26 blocks** ([19, 19, 18, 20 × 7, 19, 20 × 3, 19,
    20 × 8, 19 × 3]); 3 or 4 SiLU groups per layer;
  - **every raw SiLU table equals all four sources**, over the seven distinct members the export uses ((−5, −13),
    (−4, −12), (−3, −11), (−2, −11), (−1, −10), (−1, −9) and the Shieldstral (0, −8)); no word comes closer than
    1.0 × 10^-5 to a rounding tie, so float64 and exact arithmetic cannot disagree;
  - the five exp tables (e_s 1, 2, 3, 4, 6 at f_e 9) equal their generator in float64 and exactly;
  - **all 8 controls fire** exactly as predicted.

  The development run on stage 1 (`EV/round21/dev/dev_b1.json`, `b2c92067…`) gave the same result first.
  **So every public value the verifier evaluates in the 26 block stages is a function of the named export and the
  re-derived challenges alone** [MEASURED]; together with the 19 classifier-stage tables rebuilt in rounds 19 / 20 and
  B-3, no public table of the run is taken on trust.
- **OWED.** Nothing by this page's evidence rule.

### Step 4 — the joint law of all published field values is input-free (Theorem B)

**Argument of record:** D33's step 4 [ARGUED for the block stages], extended by D36 to two more stages of the same
transcript; extended here to stage IN-C, the R13 blocks and stage OUT-C [MINE: the review should attack the
extension]. It is a reduction conditional on G-R1, G-R2, G-R4 and G-R5.

- **G-R2, the slots.**
  - The classifier slots: NL-1's premise checks hold 12 / 12 (the public factor in every monomial, one extension round
    with all private factors in round 0, degree fits) [MEASURED, round 20 record `NL1_classifier_slots`].
  - The block slots that R13 leaves unchanged keep D33's argument of record (NL-1 and the terminal surjection passed on
    the legacy block slots at the trained TinyLlama export, D33's G-7); at Shieldstral they are measured here by the
    terminal identity only.
  - The R13 block slots: the terminal identity holds 23 / 23 in all 26 blocks with the tables of step 3, and the seven
    R13 controls fire (G + 1 → exactly slot 18; the score precision → 17; the norm shift → 14; a group id → 18; an ACT3
    entry → 19; a gate weight fold → 11; the legacy FZC body on R13 bytes refused) [MEASURED].
  - **Not run on these slots** (run for D36's token stages as PR4-7): NL-1's miniature masked runs and terminal map
    (S3–S5) and the terminal surjection with its TS-1 control. Owed or to be waived by the review (§10).
- **G-R4, the draw discipline.** The stage-47 root-rebuild replay (which confirmed D36's draw count by value, PR4-8) is
  **not ported** to stages IN-C / OUT-C or to the R13 blocks. The figure of §4 is COUNTED from the capture's geometry
  and the draw sites READ in the frozen code (`stage_in_c.rs:310–360`, `stage_out_c.rs:562–616`, the block's
  `protocol.rs` commit path, `zk::mask_commit_tagged`), not confirmed by value. Owed (§10).
- **R-1 / H-1, the production caller.** Every input-provokable refusal comes before the header (§2 "Admissible"), so
  D29's reading transfers: the refusal census is a completeness item, and the only refusal after the header that
  depends on the content is the zero-denominator event, priced by D34 / D40 at R13 [READ; REVIEW_R16 §8: wrong
  activations are refused even by a prover with its own checks switched off — completeness, never soundness].
- **The one endpoint and its owner (D40, D45(3)).** The prover seals the input token endpoint (D18); the app keeps the
  opening (rows, 256 pads per row, salts; about 90 KB) so that anyone given the post and the opening can rebuild the
  root. The holder of the opening is outside the adversary. The endpoint is opened exactly once, at the place the
  statement fixes. **Owner checks recorded by the gate** [READ, `EV/round21/owner/OWNER_RECORD.json`, `09b824df…`]:
  - the hate run: the token lane's `input-owner` in a fresh process, exit 0, `content-checked`, content_total 35,
    range [0, 35), verdict not-flagged, against the statement's input root `4cf9e8ae…` re-verified over all 28
    segments; that root is the hate-values capture's (the run gate round 20 passed);
  - the gate's own re-prove (round 19): the named r16b binary's `input-owner`, exit 0, the same facts, root
    `c8027b13…`;
  - **short items at n ≠ 35: no owner record exists.** Round 19's rung short items were made in-process by the gate's
    capture hook, which keeps the decommitment in memory and drops it; no `input.dec` and no run directory exist for
    them. The first owner check at n ≠ 35 will be the app's own 17-id demo post (its pipeline runs `input-owner` per
    category); owed (§10).
- **The new channels** [MINE, checked against the captures]:
  - **the verdict b**: absorbed into the header and the margin slot's public right-hand side; the margin and its five
    byte limbs are committed and CFS-masked; the window and L are fixed by the class, so the proof's length depends
    only on T [READ, DESIGN §5]: the real receipts are 848,412,096 B, and at the rung the segment bytes are the same at
    every n and verdict [MEASURED, round 19 C-13 per n];
  - **the length n**: public (D45(1)); a short item's figures equal a full item's apart from the public length fields
    (round 19: six short / full pairs at the rung) [MEASURED];
  - **the pad rows**: ordinary hidden rows of every block (their activations depend on the content through causal
    attention); their tokens are public and pinned to id 11 in stage IN-C; C13-1..C13-4 fire at pad id 11 on the real
    capture [MEASURED];
  - **the verdict moves nothing but its public bit**: at the rung, the randomness-free figures are equal for verdict
    0 / 1 / tie at every n [MEASURED, round 19];
  - the verifier's tables are functions of public data and challenges: all 19 classifier-stage tables rebuilt (rounds
    19 / 20) and all 17 block-stage arrays per block derived from the export (round 21).

### Step 5 — the hash layer adds nothing (G-R5)

- **Argument of record:** D33's step 5 (Lemma H^run, Route A^run) under D19b [ARGUED]: more roots, the same keyed roles.
- **New here:** none in kind; the classifier run-profile string separates the transcript. The C-R1 / C-R2 census
  (every unkeyed BLAKE3 input public and ≥ 96 B) was recorded for the token stages (R4 §2.1), **not re-run for the
  classifier absorbs** [MINE: owed or waived, §10].
- **MEASURED** in every record: every challenge re-derived, the run binding reproduced, every opened column re-hashed
  and re-authenticated under the derived keys.

## 4. Residuals, sized [COUNTED]

- **Source:** `EV/round21/classify_run_counts.py` → `EV/round21/CLASSIFY_RUN_COUNTS.json` (`513c376d…`).
- **Method:** D33 / D36 §4 (the round-9 script in force for D36), each formula re-read for the classifier stages, applied
  to the real hate capture's own geometry. **Control K-0:** the same residual function, fed round 9's L22 geometry and
  measured transcript counts, reproduces D36's 2^-70.35. **Control K-1:** each of the 27 boundaries draws 108,032, the
  frozen counting script's figure for that geometry.

**Draw sites** (D36's wording): a hiding commitment draws (rows − data)·n + rows·Q; an H also draws its zero-sum pair,
2(n − 1), once, inside its data rows; a masking commitment draws 2·ΣL_s + 2·N_slots·Q + 4,096 with L_s = rounds_s·d_s + 2.

**The arithmetic (Q = 256):**

| Part | Geometry | Draws |
|---|---|---|
| IN-C, A-in | (41 − 33)·4,096 + 41·256 | 43,264 |
| IN-C, H-in | (76 − 68)·4,096 + 76·256 + 2·4,095 | 60,414 |
| IN-C, M | 2·185 + 2·4·256 + 4,096 | 6,514 |
| **IN-C** | | **110,192** |
| one R13 block, A | (4,577 − 4,283)·16,384 + 4,577·256 | 5,988,608 |
| one R13 block, H | (4,390 − 4,282)·16,384 + 4,390·256 + 2·16,383 | 2,926,078 |
| one R13 block, M | 2·1,205 + 2·23·256 + 4,096 | 18,282 |
| **26 blocks** | 26 × 8,932,968 | **232,257,168** |
| OUT-C, A-out | (76 − 16)·4,096 + 76·256 | 265,216 |
| OUT-C, H-out | (38 − 18)·4,096 + 38·256 + 2·4,095 | 99,838 |
| OUT-C, M | 2·308 + 2·8·256 + 4,096 | 8,808 |
| **OUT-C** | | **373,862** |
| **27 boundaries** (B_in, B_1 … B_25, B_out) | 27 × ((38 − 32)·16,384 + 38·256) = 27 × 108,032 | **2,916,864** |
| **input token endpoint** | (6 − 1)·256 + 6·256 | **2,816** |
| **Total draws per run** | | **235,660,902 ≈ 2^27.81** |

Salts (one per encoded column): IN-C and OUT-C 2·4,096·4 + 4,096 = 36,864 each; each block 2·16,384·4 + 4,096 =
135,168; each boundary 16,384·4 = 65,536; the endpoint 256·8 = 2,048: **N_leaf = 5,359,616**.

| Term | Value | Kind |
|---|---|---|
| Sampler bias (D9): draws × 2^-96 = 235,660,902 × 2^-96 | **2^-68.19** | distance |
| Input-dependent refusal, two-world (D34 / D40, recounted at R13): 2·(26·(256 + 256 + 4,096·4) + 128 + 256)/p² = 879,360/p² | **2^-108.25** | distance |
| Salt guessing, q·N_leaf·2^-256 | 2^-105.65 | distance |
| Transcript pre-query, q·A·2^-256, A ≤ 2^20 (bound) | ≤ 2^-108.0 | distance |
| Leaf-input / transcript-input collisions | 2^-212.3 / ≤ 2^-217.0 | distance |
| Generator, in-model alternative (6q·2^-256, ASSUMED) | 2^-125.4 | assumption |
| Generator-key row, 3·4·2^-256 | 2^-252.4 | distance |
| Constructor vs absorb, (A + q)·2^-256 | 2^-128.0 | distance |
| **Total distance per run** | **2^-68.19** (the sampler bias is 99.9999999993 % of it) | |
| Refusal on degenerate challenges, (3L + 6)/p = 84/p | 2^-57.6 | **liveness, not distance** |
| 10^6 runs, linear | 2^-48.26 | distance |
| 10^9 runs, linear | 2^-38.29 | distance |

**Notes.**

- **Per run, not per post.** A post is proved once per category and per chunk (D41): one short post under the three
  categories is three runs, about 3 × 2^-68.19 ≈ 2^-66.6 in total; the linear rows above cover many posts.
- **The refusal term** is charged at the class maximum of four SiLU groups per layer (16,896 table rows a hidden query
  can hit per block: the byte table 256, exp 256, ACT3 4,096 × 4); at the export's actual 3–4 groups it is 2^-108.42
  [COUNTED, round 19 recount, `EV/round19/refusal/R19_REFUSAL_RECOUNT.json`, `c12550a6…`]. It replaces D40's 2^-112.7
  (the legacy 256-row activation table) for any classifier statement at the R13 Shieldstral profiles. The pad rows add
  no distinct value: in IN-C a pad position's query is pinned to the public pad id; in the blocks the pad rows' queries
  fall in the same tables (the count is over table rows, not positions).
- **A is a bound, not a measurement.** The transcript-query count was not measured on this capture (its replay needs the
  2.25 GB store resident); 2^20 is four times the 263,324 challenges round 20 re-derived. The term stays below 2^-107
  even at 2^21.
- **Against D36:** TinyLlama's 22-block run draws 52.7 M and sits at 2^-70.35; Shieldstral's blocks are 3.8 times
  larger (8.93 M draws each), so a 26-block classifier run sits about 2.2 bits higher.
- **Not confirmed by value** (§3 Step 4, G-R4): the stage-47 replay that showed D36's prover consumed exactly the
  counted bytes has not been run here.

## 5. Conditions — D33's and D36's, and those the classifier adds

| # | Condition | State |
|---|---|---|
| 1–6 | D33's conditions: reserved pairs and exclusivity; pads = opened columns; mask rounds and functional order; one opening per commitment; salted leaves; fresh OS randomness | Measured for all 84 commitments of the real run (G-1 / G-2 / G-3 / G-6, rounds 19–20). One opening per commitment, **the input endpoint opened once**. Draws counted, not replayed (G-R4 owed) |
| 7 | The gates' source pins; a change suspends step 3 | **the 72 pins** of a classifier capture under the v23 rule; a moved pin is refused by name (v22 refused the r17 captures on `run_capture.rs` alone, round 20 failing-first) |
| C-1 | One external endpoint, no output endpoint, the verdict a public bit in the header and the margin slot's right-hand side (D40) | Code fact [READ]; round 20 `G6_endpoint.no_output_endpoint` [MEASURED] |
| C-2 | The policy is one of the registered list Π (D45(2)); exactly |Π| = 3 policies admitted at this profile; an item is never re-proved under another policy or threshold | Code fact (r16b F-1 fix, test of exactly three) [READ]; **an operating rule for "never re-proved"** (§6) |
| C-3 | n, the chunk facts, the pad id and positions and the verdict row are the public length facts of D45(1) / D41 and nothing else | Measured: C13-1..C13-4 fire at pad id 11; short-versus-full pairs differ only in those fields (round 19) |
| C-4 | Every input-provokable refusal precedes the header (H-1 for classifier runs) | Code fact at the CLI (REVIEW_R16 §§2–8; R19 §6(b)) [READ] |
| C-5 | D34's premises at R13: no draw or absorb between the inversions, no retry, no position tag changing the count | [READ, round 19 recount]; owed by the review to confirm at R13's TAB slot |
| C-6 | The margin row, the embedding and every block table are the export's / the checkpoint's | Classifier: B-3 derived from the checkpoint by the gate, bit-exact; blocks: the 17 arrays derived from the export by the gate (round 21) [MEASURED] |
| P-4 | The export, the tied tensor, the policy texts and templates and the context are fixed before and independently of any hidden content; no item is retried under another export, policy or label | A HYPOTHESIS the sentence carries |

## 6. Hypotheses and operating rules

D33's and D36's §6 rules carry over, with these additions.

- **CPU only, the named binaries.** A deployment runs `dfb8025e…` (r16b) or `81bd8624…` (r17). Another binary, even one
  rebuilt from these trees, is outside this statement until it is named. The round-16 binaries are outside it.
- **Fail closed (D45(4)).** A post without an accepted proof for a category is not published and is shown as "could not
  be verified", never as safe. The app must not show *why* an attempt failed (D21: a refusal reason is never shown to
  anyone not entitled to the content), and must not retry the item under another policy, threshold, export or chunking
  to obtain a proof (C-2, P-4).
- **One fixed policy list (D45(2)).** Each listed policy is one public yes / no bit about each chunk. Changing the list
  (the strict / moderate ruling, or a fourth category) changes Π and this statement's sentence; an item proved under one
  wording is never re-proved under another.
- **The proof is linked to the post (D45(3)).** The input endpoint root is stored with the post and anchored on-chain
  (D39); the app keeps the opening, and anyone given the post's text and the opening can check the link. **Accepted
  consequence: whoever holds an opening can prove which content was posted.** The opening is as sensitive as the
  content; it is never published (D21), never put in a capture or an export, and no later artifact claims or opens the
  root (D23 as amended).
- **Publication.** Publish a run only after one's own fresh-process verification (the CLI's `verify` does it). Never
  publish the opening, the content, the per-layer activations (`--seq-dir`), prover stdout, refusal text or verifier
  output beyond the statement.
- **Owner storage.** Openings live under the CLI's owner base (`$HOME/zk60-owner-private/token-io/`, 0700, outside every
  artifacts tree), or the app's own owner-only directory. Delivery of an opening to a separate party is not built.
- **Content length is public** (D45(1)). Hiding it is a later, costlier variant.

## 7. Findings, with dispositions

| # | Finding | Disposition now |
|---|---|---|
| **R19-1** | Range refusals depend on the hidden content, pad rows included (102 of 300 ids refuse at one dev calibration) | **Stated as the refusal channel** (§0, §2): admissibility is a public function of the hidden content; "could not be verified" under D45(4). Quantified as far as known; the real-content rate is unmeasured |
| R19-2 (refusal term) | The R13 SiLU tuple table has 4,096·G rows, so D40's 2^-112.7 is wrong at R13 | **Recounted: 2^-108.25** (round 19), carried in §4 |
| R13-T (taken tables) | Rounds 19 / 20 took the 15 block tables per stage from the capture, on the recorder's attestation | **Closed by measurement in round 21** (§3 Step 3): all 442 arrays derived by the gate from the export, byte for byte, G_k equal in all 26 blocks, ACT3 against four SiLU sources |
| O19-1 | At the R13 rung the margin is the same for every item: the rung's verdict does not depend on the content | Noted: the rung figures rest on the code, not on content dependence; only the real captures are content-dependent |
| F19-G1 / F19-G2 / F20-G1 | The gate's own tools (repository root, refused pins, file reads) | Fixed in v23 |
| O20-1 | A values capture's array store becomes resident file pages when memory-mapped | Operations only (declarations); round 21 reads the store with pread |
| N20-1 | The r17 values bundle's README names the round-19 tree | Wording only (token lane) |
| N-r14-6 | Pad-row refusals were not observed on the real item | Part of R19-1 |

## 8. What must not be claimed, even if this came into force

- That the verifier "learned nothing" without the distance. Say it was never given the hidden values and that its view
  is within the stated distance of one computed from the public facts alone.
- That the public facts are harmless: the verdict bits, n and the chunk ranges are disclosed, and at small n the
  verdict says much about the content (§0).
- That "could not be verified" reveals nothing: it is a public function of the hidden content (§0, §2).
- That the content length is hidden.
- That the verdict is the float model's. It is the approved integer model's (fidelity is D32's question).
- That the classifier is accurate, or that "not flagged" means safe. The statement is about privacy, not quality.
- That the proof shows *which* content was posted to anyone without the opening (it does not: D45(3) needs the
  opening).
- Anything at T256, at another export, policy wording or list, for another binary, on the GPU, for images, or about
  soundness.
- That D33 or D36 covers this run, or that this draft extends them.

## 9. What would lapse or reopen it

- Anything in D33 §9 or D36 §9 that touches the blocks, the endpoint or the hash layer.
- A change to any of the 72 pinned files, or another binary.
- **A change of the policy list Π** (Victor's strict ruling replacing the moderate three, a fourth category, a new
  threshold): the sentence is re-evaluated at the new list (the gate re-captures one policy of the new list; the
  per-run figure does not depend on the policy text but the template length P0 does change n's range and the pad
  positions).
- A different export, tied tensor or calibration (a new `profile.json` digest or trained identity).
- A finding against any step of §3, or a lapse condition of D34 / D40.
- An endpoint opened twice, an opening published, the root claimed or opened by a later artifact (D23 as amended).
- A refusal provokable through the content after the header (C-4).
- A GPU-built receipt.
- A per-block table, margin row or embedding that the gate cannot derive from the named export and checkpoint.

## 10. What is owed before the security owner could rule

**Closed since gate round 19's list** (R19 §8, R20 §6):

| Item | How |
|---|---|
| The real capture's declared limits (block slots without tables; preimage on a sample) | Gate round 20: all 23 slots × 26 blocks; the full preimage over 84 commitments, 0 differing [MEASURED] |
| The refusal term at R13 | 2^-108.25 (round 19) [COUNTED] |
| The per-run distance figure at the Shieldstral R13 shape | **2^-68.19** (round 21, §4) [COUNTED] |
| The refusal channel in plain words (R19-1) | §0, §2 (for the review to attack) |
| A gate-side derivation of the 15 block tables | Round 21, §3 Step 3: **442 / 442 arrays equal, all 26 blocks**, G_k equal, ACT3 against four SiLU sources, 8 / 8 controls [MEASURED] |
| The input owner's check on the real runs, recorded by the gate | Round 21 `OWNER_RECORD.json` (hate run, the round-19 re-prove) [READ] |

**Still owed:**

1. **An independent privacy review round** on this draft, attacking in particular the [MINE] extensions (Step 4 to
   IN-C / OUT-C and the R13 blocks), the refusal channel's wording, and whether the items below are needed or can be
   waived.
2. **The stage-47 root-rebuild replay (G-R4 by value)** at the classifier stages and the R13 blocks; today the draw
   count of §4 is counted, not confirmed by value.
3. **NL-1 S3–S5 and the terminal surjection** (with TS-1) on the 12 classifier slots and the seven R13-redefined block
   slots; today the premise checks and the terminal identity are measured.
4. **The C-R1 / C-R2 hash-input census** for the classifier absorbs.
5. **An owner check at n ≠ 35**: the first will be the app's 17-id demo post (its pipeline runs `input-owner`); the
   gate records it when it lands. The delivery of the opening that D45(3) keeps with the app is not built.
6. **Victor's strict / moderate wording ruling**, and with a strict list a gate re-capture under it.
7. The independent check of token rounds 16b and 17 (routed by the coordinator), and the token lane's README note N20-1.
8. **The security owner's decision and Victor's acceptance.** No lane can claim a privacy acceptance.

**Optional, by measurement:** the refusal rate of the real model on real posts (an honest-prover census on a sample of
the benchmark, which needs the per-item activation source); the T256 profile, if it is ever proved.

## 11. Evidence index

| What | Where (EV = `results/zk60_gate_tinyllama_20261017/`) |
|---|---|
| Gate round 18 (the R-C3 rung, 21 captures) | `EV/round18/R18_SUMMARY.md` (`c8046dd0…`), `R18_SUMMARY.json` (`d3ad213c…`); tools v21 (`25814977…`) |
| Gate round 19 (R13 rung, 13 captures; the real sexual re-prove) | `EV/round19/R19_SUMMARY.md` (`c01ff9f5…`), `R19_SUMMARY.json` (`96e333e8…`), `C13_PER_N.json` (`65bcae83…`), the real record `EV/round19/v22/v22-classify-r13-shield-t128-cli-sexual-r16b.json` (`901c1f7a…`); tools v22 (`ab703596…`) |
| The refusal recount | `EV/round19/refusal/R19_REFUSAL_RECOUNT.json` (`c12550a6…`) |
| Gate round 20 (the real hate run, no declared limit) | `EV/round20/R20_SUMMARY.md` (`b4db9702…`), `R20_SUMMARY.json` (`24e1d6b9…`), the record `EV/round20/v23/v23-classify-r13-shield-t128-cli-hate-r17-values.json` (`e94d6e7b…`); tools v23 (`64f4b757…`) |
| Gate round 21 (this draft's new evidence) | `EV/round21/R21_SUMMARY.md`; the derivation `EV/round21/derive_block_tables.py`, its development record `EV/round21/dev/dev_b1.json` (`b2c92067…`) and the all-26 record `EV/round21/derive/DERIVE_ALL.json` (`5c2c7111…`); the counts `EV/round21/classify_run_counts.py` (`87492320…`) → `CLASSIFY_RUN_COUNTS.json` (`513c376d…`); the owner record `EV/round21/owner_record.py` (`46d810b1…`) → `owner/OWNER_RECORD.json` (`09b824df…`) |
| The captures | `~/zk60-artifacts/token-io/captures/classify-r13-shield-t128-cli-hate-r17-values/` (the hate run with its public tables; 2.25 GB store), `…-cli-sexual-r16b/`, the 13 `classify-r13-rung-L*` captures |
| The real runs | `~/zk60-artifacts/token-io/r16-runs/{hate,sexual,violence}-run/` (statements `/3`), the token lane's `r16/real_runs.json` and `r16/logs/real-*` |
| The export | `results/zk60_shieldstral_export_20261026/native_low_h24_t128/` (profile `2ba468f9…`; 26 layer manifests) |
| Code and binaries | `results/zk60_token_io_r1_20261017/frozen-r16b/` (`04d94bc0…`), `frozen-r17/` (`23a95876…`), `cli/zk60_classify.r16b.release.bin` (`dfb8025e…`), `cli/zk60_classify.r17.release.bin` (`81bd8624…`) |
| Reviews (soundness) | `results/zk60_token_io_review_r1_20261017/REVIEW_R13.md` (`9537a60a…`), `REVIEW_R14.md` (`dbf05846…`), `REVIEW_R16.md` (`da6e2f79…`); `results/zk60_d24_review_20261017/REVIEW_R13.md` (`7ea6d302…`) |
| Design | `results/zk60_token_io_r1_20261017/classifier/DESIGN_CLASSIFIER.md` (v2.7) §§1–6, 13–18 |
| Register | `docs/zkmatrix-poc/ZK60_DECISIONS.md` D19 / D19b, D20, D21, D23, D29, D33, D34, D36, D37–D41, D45 |
