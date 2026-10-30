# Privacy statement for the Shieldstral-1.0-3B classifier proof (T128, native R13, public-row, verdict as a public bit) — DRAFT v2, for privacy re-review (NOT accepted, NOT in force)

Draft v1 was written 2026-10-29 from 21:37 UTC (gate round 21); draft v2 from 23:15 UTC (gate round 22), both by the
PRIVACY GATE lane (a delegated Claude Opus 5.5 agent), at the coordinator's request. **v2 supersedes v1**, which is kept
unchanged as history: `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_CLASSIFIER_SHIELDSTRAL_T128_DRAFT_v1.md` (sha256
`db89f427…`). v2 answers the independent privacy review of v1
(`results/zk60_privacy_review_20261029/CLASSIFIER_T128_PRIVACY_REVIEW.md`, verdict NOT ACCEPTABLE YET: blocking P-1,
P-2; must-change P-3..P-9; notes P-10..P-15). The finding-by-finding disposition is §12.

It follows the form of the two statements in force, D33 (`docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_TRAINED_TINYLLAMA_T32.md`)
and D36 (`docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_NEXT_TOKEN_TINYLLAMA_T32.md`). It is a separate draft beside them, not
an edit of either, and it extends neither.

| Status | **DRAFT v2. NOT accepted, NOT in force, and NOT a privacy acceptance. Nothing on this page establishes a privacy property.** It proposes a sentence for one classifier run, a corollary for one post, and lists what they rest on, what is measured, and what is still owed. Next: the privacy re-review of v2, then the security owner's decision, then Victor's acceptance. **The policy wording is pending Victor's strict / moderate ruling: this page names the policy list as a parameter and evaluates it at the registered moderate list.** |
|---|---|

**Labels.**

- [MEASURED]: a run happened and a record is cited. Laptop, shared box, one run unless stated.
- [COUNTED]: exact arithmetic from the code and the captured geometry.
- [READ]: a fact read in a cited source line, record or document.
- [ARGUED]: an argument that survived independent attack in D33's / D36's record (the reviews named there). It is
  carried here only where the classifier stages and the R13 blocks do not change it.
- [MINE]: my own reading or arithmetic for this page. The re-review should attack these first.

**Sources.**

- **EV** is `results/zk60_gate_tinyllama_20261017/` (the gate lane), ledger `EV/PROGRESS.md`.
- **The token lane** is `results/zk60_token_io_r1_20261017/` (design `classifier/DESIGN_CLASSIFIER.md` v2.7, §§1–6,
  14–18; CLI notes `cli/README.md`); its code reviews are in `results/zk60_token_io_review_r1_20261017/`
  (`REVIEW_R13.md`, `REVIEW_R14.md`, `REVIEW_R16.md`) and `r18/A5_PATCH_REVIEW.md`.
- **The native R13 review** is `results/zk60_d24_review_20261017/REVIEW_R13.md` (soundness, not privacy).
- **The privacy review of v1** is `results/zk60_privacy_review_20261029/CLASSIFIER_T128_PRIVACY_REVIEW.md` ("the
  review").
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

**Who sees the post.** The app runs the prover, so the app sees the post (and keeps its opening, D45(3)). The proof
hides the post from everyone else who sees the proof.

Consider anyone else who checks such a proof and is given the public facts listed below. **This page would claim that
the proof itself tells them essentially nothing more about the post.** In numbers: for a post that passes the integer
model's ranges, what they see is within a statistical distance of about **2^-68.19 per proof** (about one chance in
3 × 10^20) of something that could be produced from the public facts alone, without the post. **A post of J proofs (3
categories × its chunks: J is 3 to 22 at T128) is J times this**: 2^-66.60 for a post of up to 49 tokens (J = 3),
2^-63.73 at the most a post can have (J = 22, N ≤ 336) (§2, corollary).

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
- **An accepted proof also shows that the post passed the integer model's ranges.** Every activation of the post, pad
  rows included, fits the R13 integer ranges (otherwise there would be no proof). Whether a post passes is a property of
  what it says, and it may correlate with the verdict itself. It is published with every proof.
- **At small n the public facts say a lot.** At n = 1 the verdict is a function of one hidden token id, one of at most
  130,072 possible ids (the vocabulary of 131,072 minus the 1,000 control ids; a real one-token post is the tokenizer's
  encoding of ' ' + text, so far fewer ids occur in practice). The three verdict bits plus admissibility put the id in
  one of at most 16 cells, and anyone can compute the cells with the public model.
- **Per-chunk bits are public** (D41): a "flagged" label also shows which part of the post triggered it. **The last
  chunk is end-aligned**, so it can overlap its neighbour by up to 54 of 55 tokens (for example a post of 56 tokens is
  proved on [0, 55) and [1, 56)): two bits on windows that differ by one token at each end can localise a decisive
  token. An edited post re-proved shows which edit flipped its verdict.

### The refusal channel, stated plainly

**Whether a post gets a proof at all can depend on what the post says.** The honest prover stops before it writes any
proof when an activation of the post — or of the pad rows after it — leaves one of the R13 stack's fixed integer
ranges (the norm word in int16; the widened words in [-32768, 32767]; the attention score in [-127, 127]; the gate
word in [-2048, 2047]; the norm and softmax denominators and their remainder windows), or when a content position holds
a control token. Such an attempt yields no proof and nothing for a verifier to see. Under D45(4) the app then shows the
post as **"could not be verified"** and does not publish it.

**Someone who sees "could not be verified" learns that the attempt failed.** Most such failures come from the content
(a range left, a control token); some come from the machine (a guard admission or memory kill, a timeout, an I/O
error). The app must show this only to the post's author, one bit per post, and never say which reason, chunk or
category (§6, rules R1–R4). What is known about how often content causes it:

- on a development calibration of the same arithmetic, 102 of 300 vocabulary ids each made an item refuse; at the
  same round's other calibration (norm constant 4,000 instead of 10,000), none of the 300 did (gate round 19, R19-1)
  [MEASURED];
- on the real model, every real proof attempted so far proved: one 35-token post under all three policies (token round
  16) and the gate's re-prove of it (round 19) [MEASURED, 4 runs];
- the export lane's integer replay of the same arithmetic saw no range refusal on its 192 calibration sequences through
  all 26 layers, and none so far on 4,872 benchmark items through layers 0–5 [READ, the export lane's report; not the
  prover, incomplete];
- **the refusal rate on real posts is not measured.** It must be measured (with the integer evaluator alone, no prover
  needed) before the app runs on non-public posts (§10).

**After the proof has started**, the only refusal whose chance can depend on the post is a lookup denominator that
happens to be zero: for an admissible post, whether its attempt is refused after the start depends on the post with
probability at most **2^-108.25** per proof, and that is counted in the distance. Other failures after the start (a
degenerate challenge, about 84/p ≈ 2^-57.6 per run, and machine failures) do not depend on the content.

### Which code, model and policies

- **Code:** the token lane's frozen trees **frozen-r16b** (binary `zk60_classify.r16b.release.bin`, `dfb8025e…`, the
  app's binary) and **frozen-r17** (binary `zk60_classify.r17.release.bin`, `81bd8624…`; its changes from r16b are
  test-only). CPU path only, one `prove` per (category, chunk). The 72 source files a capture pins. **The batch command
  (`prove-batch`, token round 18) and every r18 binary are not covered** until named (§1, §6).
- **Model:** Shieldstral-1.0-3B (`mistralai/Shieldstral-1.0-3B`, checkpoint sha256 `87753e30…`), the T128 integer
  export `results/zk60_shieldstral_export_20261026/native_low_h24_t128` (profile.json `2ba468f9…`), trained-model
  identity `29aeba6c…`.
- **Policies:** the three registered moderate-wording category policies (§1). **The wording is Victor's open ruling.**
  A strict ruling replaces the three entries; this page is then re-evaluated at the new list (§9).

### What has been measured, and by which binary

- **Gate round 20** [MEASURED]: the real moderate-hate run, captured with its public tables, passes the classifier gate
  with **no declared limit**: disclosed dimension 0 on every A, endpoint and boundary commitment and exactly the expected
  2 on every H (84 commitments); the **full** zero-data preimage of the verifier's view (81,731,058 entries, 0
  differing); masks 0 of 440,221 entries differing; the joint figure 0; all 23 block slots in each of the 26 blocks;
  15 + 7 controls fire. **That receipt was made by the round-16 binary `e94cecf9…`** (frozen-r16 plus one changed
  comment, so the same prover code as r16b apart from the policy list) and re-verified by r17.
- **Gate round 19** [MEASURED]: the gate's own fresh re-prove (moderate-sexual) by the **named r16b binary**, which
  passed with two declared limits (since closed on the hate capture), and 13 development-rung captures (verdict 0 / 1 /
  tie, two chunks, short items at n = 1, 11, 22): all pass. **The r17 binary has never proved a gated receipt**; it only
  re-verified. The carry to the named binaries is by source reading, confirmed independently by the review (§2 item 7).
- **At the real shape** only not-flagged items with n = 35 were gated, under the hate and sexual policies. The
  violence policy, flagged verdicts, short items and two-chunk items rest on the rung (where the randomness-free figures
  are equal across verdict 0 / 1 / tie and n) and on the code. **The named r16b binary did prove real receipts at
  n = 17 under all three policies** (the app's first real post, 2026-10-30, all not-flagged, each verified and
  owner-checked: §3 Step 4); those receipts were not captured or gated.
- **Gate round 21** [MEASURED]: the 15 public block tables per block (17 arrays) that rounds 19 / 20 took from the
  capture were **derived again by the gate from the export: 442 of 442 arrays equal, byte for byte, in all 26
  blocks**, the SiLU tables checked against four independent sources; the per-run distance was counted; the owner
  checks were recorded.
- **Gate round 22** [MEASURED], the review's two blocking items: **the seeded draw replay (G-R4 by value)** at the R13
  rung, L = 1 and 2, passes — the production verifier accepts, the prover drew exactly the counted bytes stage by
  stage, every root is rebuilt; **NL-1 S1–S5** passes on the 12 classifier slots and the 7 R13-changed block slots, on
  the rung and on the real capture; **the terminal surjection with TS-1** passes on the rung and on the real capture's
  classifier stages, and is partial on a real R13 block (three roles pass, TS-1 not run there; §3 Step 4). Also the
  hash-input census (C-R1 / C-R2), the measured transcript count A = 287,237, and the owner check at n = 17.

### What is still open (§10)

The privacy re-review of v2; Victor's strict / moderate ruling; the real-model refusal rate before non-public posts;
the app's failure display (rule R2) before non-public posts; the security owner's decision and Victor's acceptance.

---

## 1. Scope — what a statement would cover

| | |
|---|---|
| Run profile | `hashline-zk-mr1/private-classify-run-shieldstral-3b-t128-r13-public-row/1` (token frozen-r16b / r17 `token_io/run.rs`). Mode: **verdict as a public bit**, variant public-row (the item fills positions 0 … item_length − 1; trailing positions hold the public pad id) [READ] |
| Block profile | `hashline-zk-mr1/private-block-shieldstral-3b-t128-lowh24-blocks/1` (shape `R13_SHIELD_T128_H24`: accuracy stack LOW + h24, non-DD). T 128, width 3072 (padded 4096), hidden 9216 (padded 16384), 32 query heads, 8 key-value heads, head_dim 128 (RoPE YaRN, factor 16), columns 2^14 at rate 1/4, Q 256, 23 slots [READ, run.json `shape`] |
| Form | **One classifier run**: stage IN-C, 26 R13 blocks, stage OUT-C, **one** external endpoint (the input token endpoint, 2^8 words at rate 1/8, 6 rows) and **no output endpoint**; the verdict b is a public bit absorbed into the header and placed in the margin slot's public right-hand side (D40). 28 segments, 848,412,096 B per receipt [READ; MEASURED] |
| Model | Shieldstral-1.0-3B, checkpoint sha256 `87753e30c8c321da478b83bbabebcd813cc9b3d0cee5c5b3d64349a8ee4172f7` (revision `003ec7e2…`), tied tensor `language_model.model.embed_tokens.weight` `67a138c1…`. Export variant `shieldstral-s2-fixed-low-h24-t128-v2`, `profile.json` sha256 **`2ba468f98085caf1136f27cf66220f93d8e316acb8dbae7e98f9eb68347f05a0`**; trained-model identity **`29aeba6c04a819cdbafde311f7c9d0c678d85aff22292ae6b9647761158a0bd1`**; per-layer gate denominators G = [19, 19, 18, 20 × 7, 19, 20 × 3, 19, 20 × 8, 19 × 3]; embedding digest `1cb276d1…`; margin-vector digest `6429a242…`; margin scale 4.08288030735373e-6 (bits `0x3ed11ff597db2fb6`) [READ; MEASURED in gate rounds 19–21] |
| **Policies (a parameter)** | The fixed list of D45(2), evaluated here at the registered **moderate** wording: `shieldstral-1.0-3b-moderate-sexual/1` (P0 72, chunk 55), `shieldstral-1.0-3b-moderate-violence/1` (P0 72, chunk 55), `shieldstral-1.0-3b-moderate-hate/1` (P0 78, chunk 49); suffix `[/INST]` = [4], S = 1; yes 13059, no 2649, c 0; pad id 11; control ids < 1000; V 131,072; tokenizer tekken.json `ceb11e85e44d7c91` (plain-text encoder). r16b's production list is `[policy_rung_dev(), the three category policies]`; at this profile exactly the three are admitted because the profile refuses the development policy (its V = 300 and margin parameters), which r16b's test pins; the model card's `card-unsafe/1` is test-only since r16b (REVIEW_R16 F-1, fixed) [READ]. **Pending Victor's strict / moderate ruling.** |
| Item lengths | 1 ≤ n ≤ the policy's chunk size (55 / 55 / 49 at T128). A post longer than that is split into chunks by D41 (overlap 8, the last chunk end-aligned), each chunk its own run; a post has at most 336 tokens at T128 (22 runs) [READ; the review's enumeration]. item_length = P0 + n + S; pad positions = 128 − item_length; verdict row = item_length − 1 [READ] |
| Binaries | **r16b** `results/zk60_token_io_r1_20261017/cli/zk60_classify.r16b.release.bin`, sha256 **`dfb8025eb903b203f4b50371fdd0dd00659d46a9dbaad9d121d6a68343ebc70c`** (built from frozen-r16b; the app's binary, one `prove` per (category, chunk): `apps/proven-media/proven_media/shieldstral_runtime.py:16–17` [READ, the review]); **r17** `cli/zk60_classify.r17.release.bin`, sha256 **`81bd86248e9f42393c9fe739e6794b7af155ad9a0a06874c89efb7a7bba18317`** (built from frozen-r17). CPU only (no gpu-cuda) [READ]. **Not covered:** the round-16 binaries (`e94cecf9…`, which proved the hate receipt in evidence, and `dae5abd7…`), which still admit the card policy; and **`prove-batch` and every r18 binary** (token round 18's A5: several proofs of one post in one process) until named after the A5 review's fixes are adopted, the randomness census is extended to its new files, A5 §4's byte-identity check passes and the corollary of §2 is read for one process (§6) |
| Code | **frozen-r16b** (`results/zk60_token_io_r1_20261017/frozen-r16b/`, 301 files, manifest list sha256 `04d94bc0904ccaeb621d001b72be51b54034bfb5f7135a543e872a36a834c549`) and **frozen-r17** (303 files, list sha256 `23a958766cf946d07b35e93e1f82685c3f952e5526a99f4d389be766881dd9a2`; six paths moved, all `#[cfg(test)]`; confirmed independently by the review §2 item 7). Native base: R13 (`bb9eb212…`). **Condition 7's pin set is the 72 files a classifier capture pins**, accepted by the gate's v23 rule (`zk60_native_rg_classpins.classify_capture_pins_v23`) |
| Path | **CPU only**, as an operating rule. No GPU-built classifier receipt was captured or gated |
| Lengths in evidence | the real item n = 35 (14 / 20 / 20 trailing pads under hate / sexual / violence; gated under hate and sexual, not-flagged only); the app's real post n = 17 (proved by r16b under all three policies, verified and owner-checked, not captured); the development rung at n = 1, 11, 22, 23 and a two-chunk item (gate round 19, L = 1 and 2 at the R13 h24 rung) |
| Hash rule | D19a's keyed BLAKE3 (`blake3-keyed/1`), the run transcript separated by the run-profile string (D17) [MEASURED in every record] |
| Tools | gate tools **v22** (`EV/gate-tinyllama.tools.frozen.v22.sha256`, `ab703596…`) and **v23** (`64f4b757…`, 80 files); rounds 21 / 22's scripts under `EV/round21/`, `EV/round22/` |

**Not in scope; each owes the argument again:**

- the T256 profile (registered, never proved or captured), any DD profile (none registered for the classifier), any T
  other than 128;
- any other export, calibration or model, and any other policy wording or list (a strict ruling, §9);
- the round-16 binaries, `prove-batch` / r18, any rebuild not named here, and the GPU path;
- images (D39's text-and-image scope: the Pixtral encoder is not proved), hidden weights (P3);
- what a holder of the input opening learns (the app; D45(3)); the delivery of that opening (not built);
- **the app's own salted SHA-256 commitment of the text** (`apps/proven-media/proven_media/jobs.py:74–78` [READ, the
  review]): it hides the text only while its 32-byte per-post salt stays secret;
- **timing, memory, power and attempt counts** (D20): out of scope; the app's public record shows the proving time
  (§8);
- **the classifier's quality** (fidelity is the export lane's benchmark, D32) and **soundness** (the native R13 review
  and the token code reviews).

## 2. The statement (proposed sentence — not in force)

> In the random-oracle model for BLAKE3 (D19), read as BLAKE3's compression function being ideal also at a chaining
> value the adversary knows (D19b), and assuming the prover's generators' joint output is indistinguishable from uniform
> (E-1; X-1 across runs), consider a verifier who:
>
> - receives an **accepted** classifier run of the profile in §1, written by the frozen-r16b or frozen-r17 code (the
>   CPU binaries `dfb8025e…` / `81bd8624…`, one run per process call), under one policy of the registered list Π
>   (today the three moderate category policies);
> - receives it bound to its trained-model statement (`29aeba6c…`) and its classifier profile;
> - has the export, the tied tensor, the template and policy texts, the context label and the tier fixed before and
>   independently of any hidden content;
> - is not the holder of the run's input opening;
> - makes at most q ≤ 2^128 hash queries.
>
> That verifier is never given any of the following, and its view is within about **2^-68.19 per run** of a
> distribution that is computed from the public facts alone — the verdict bit b, the policy, the content length n and
> the chunk facts (D41), the model and the profiles, **and the fact that the item is admissible** (passes the R13
> integer ranges and has no control id at a content position) — and depends on none of them:
>
> - the content's token ids and their embedding rows;
> - the activations of all 26 blocks at every position, the pad rows included, and the internal boundary planes;
> - the final-norm values, the margin and its range limbs.
>
> This holds for every **admissible** item.
>
> For an admissible item, whether its attempt is refused **after** its header depends on the hidden content with
> probability at most **2^-108.25** per run, a two-world distance counted in the figure above (D34 / D40, recounted at
> R13). **Whether an item is admissible at all is a function of its content** that anyone holding the content can
> compute (the model is public): an inadmissible item gets no proof and no view; whether others learn that it failed
> depends on the app's display rule (§6, R2).

**Corollary (one post).** Under the same model, for the J accepted runs of one post — every category of Π and every
chunk of its D41 plan, J = |Π| · k with k the number of chunks — a verifier holding all J runs, and none of the post's
openings, sees a joint view within about **J × 2^-68.19** (plus cross-run hash terms of the size of §4's pre-query and
collision rows, with q raised by the honest runs' own oracle calls J·A, A = 287,237) of a distribution computed from
the public facts of all J runs (N, the plan, the |Π|·k verdict bits, admissibility). At T128 that is 2^-66.60 for J = 3
and 2^-63.73 for J = 22 [COUNTED]. It needs four hypotheses:

1. **X-1 per run:** each run makes two fresh, independent OS-entropy reads (the endpoint seal and the run stream), also
   when runs share a process [READ: frozen-r17 `zkp-core/src/rng.rs:30–50`, `classify_run.rs:146`; the review];
2. **each run its own input endpoint, opened once** (the real post's three runs have three different roots `4cf9e8ae…`,
   `ddd23e51…`, `96ad1af1…`, and the gate's re-prove a fourth `c8027b13…` [READ, the review]);
3. **no run's root is an input to another proof**;
4. **the verifier holds none of the post's openings.**

The argument is the standard hybrid over the J runs [MINE]: replace them one at a time by the simulated runs; each step
costs one run's distance, because hypotheses 1–4 make the runs' randomness and endpoints independent and nothing of one
run enters another.

**Assumptions, in plain words.**

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

**What can still fail after the header:** a zero LogUp denominator (D34's event, priced at 2^-108.25), a degenerate
challenge (84/p ≈ 2^-57.6 per run, a function of the challenges only), a file that changes between the two passes,
guard admission, a memory kill, a timeout and I/O errors. The last five are machine failures, out of scope by D20, and
must not depend on the content: the guard cap is set with margin above the class maximum (§6). None can be provoked by
choosing the content. Even then nothing is published: segments are held until the run returns Ok, and leftovers are
refused by name at the next `prove` (as D36 §2) [READ, REVIEW_R16; D29 / D21].

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
  | Block stages | **23 / 23 slots in each of the 26 blocks**, each at its own G; 7 R13 controls fire |
  | Controls | CC-1..CC-6, CC-8 / CC-9, C13-1..C13-4 at pad id 11, J-1..J-3 fire |

- **No public table is taken on trust** (gate round 21). Rounds 19 / 20 took, per block stage, 15 statement tables (17
  arrays: the seven weight folds with the R13 multipliers, gamma_a / gamma_m, the RoPE pairs on Q and Kv, the group
  column, the exp table, the ACT3 table and its support) from the capture. Round 21 **derived all of them again in the
  gate**, from the export's arrays and the slot's own public challenges, with its own exact arithmetic (no token-lane
  code imported or run), and compared them byte for byte with the capture (`EV/round21/derive_block_tables.py`;
  `EV/round21/derive/DERIVE_ALL.json`, `5c2c7111…`): **442 of 442 arrays equal** (118,210,560 entries); the store
  re-hashed equal to the manifest; G_k equal to every stage line; every raw SiLU table equal to four sources (a float64
  transcription of the definition, Sol's reference formula transcribed, an exact 60-digit evaluation, the native
  tree's reference vectors) over the seven members the export uses, (0, −8) included, with no word closer than
  1.0 × 10^-5 to a rounding tie; the exp tables equal their generator; 8 / 8 non-vacuity controls fire [MEASURED].
- **OWED.** Nothing by this page's evidence rule.

### Step 4 — the joint law of all published field values is input-free (Theorem B)

**Argument of record:** D33's step 4 [ARGUED for the block stages], extended by D36 to two more stages of the same
transcript; extended here to stage IN-C, the R13 blocks and stage OUT-C [MINE]. It is a reduction conditional on G-R1,
G-R2, G-R4 and G-R5. **v1 assumed G-R2 on the R13 block slots and G-R4 everywhere new by analogy with D36; the review's
blocking findings P-1 and P-2 asked for both to be measured, as D36 measured them (PR4-7, PR4-8). Round 22 did:**

- **G-R2, the slots: NL-1 S1–S5 on the 12 classifier slots and the 7 R13-changed block slots** [MEASURED, gate round
  22 item 3, `EV/round22/item3/ITEM3_REPORT.md`, `3be42c0a…`]. The seven: SC_DZC, SC_QZC, SC_KVZC, SC_SZC, SC_FZC and
  SC_TAB, which R13 redefines (`argument_accuracy.rs`), and SC_LZC, whose Dom::L lookups R13 changes; SC_DD is DD-only
  and no classifier profile is DD. Through the frozen `nl_check` with a slot IR built from the gate's own
  transcriptions, in four challenge modes (the run's re-derived challenges and three random seeds), on three rung
  captures (L 2 at G 20 / 21, a short item n = 1, a tie) and on the real hate capture (the classifier slots, and blocks
  0 and 2 at G 19 / 18; 100 s, 1.53 GiB):
  - fidelity first: the transcription equals the recorded terminal polynomial (T-0: classifier 12 / 12 on the rung,
    round 20's 12 / 12 on the real capture; R13 28 / 28 slot instances), its expansion equals it (E-0, 28 / 28), and a
    perturbed IR is caught (F-1);
  - S1: every monomial has a public factor, the degree fits (slack 0, or 1 at SC_DZC / SC_FZC), every mask fits (worst
    L 112 + 256 ≤ 512), all private factors in extension round 0 — on every slot;
  - S2: the stage sums (IN-C ΣL 185, OUT-C 308 at the real shape, equal to the mask specs §4 counts);
  - S3: Fact 2.1 tight at every (N, d) of the classifier and R13 slots, the real shape's included (55 / 55);
  - S4: every miniature masked run accepts and every terminal map is onto F_p²^m;
  - S5: N5-1 (a public factor stripped), N5-2 (one degree short, at zero slack), N5-3, N5-4 and F-1 all fire.
  The blocks at G 18 / 19 (real) and 20 / 21 (rung) cover every gate denominator of the real model ({18, 19, 20}); the
  R13 slot polynomials depend on the block only through its public G and calibration constants.
- **G-R2, the terminal surjection with TS-1** [MEASURED, gate round 22 item 3]: on the rung (`classify-r13-rung-L2-v1-r17-values`:
  IN-C, OUT-C and both R13 blocks; 3,864 s, 1.14 GiB) and the n = 1 short item, every A, endpoint, boundary and Input
  commitment is onto with 0 disclosed and every H discloses exactly its declared zero-sum relation (2); TS-1 (one
  claim's reserved pair removed) makes that group disclose on all 12 roles (6 / 6 at n = 1); the review's block-A
  controls C1 / C2 / G7-D3 fire and the five others do not, as predicted. **At the real shape:** the six
  classifier-stage roles of the hate capture pass with TS-1 (`EV/round22/item3/ts2-real-hate-classifier-stages.json`,
  `6da6296a…`; 353 s, 0.11 GiB): A-in 3 / 3, E-token-in 1 / 1, A-out 16 / 16, B-out 2 / 2 onto with 0 disclosed;
  H-in 3 / 4 and H-out 4 / 5 disclose exactly 2 (joint {2, 3} and {3, 4}); TS-1 fires 6 / 6. The real R13 block is
  **partial**: block 0 gives A 36 / 36 surjective disclosed 0, H 8 / 9 disclosed 2 (joint {7, 8}), Input 2 / 2
  disclosed 0 (`EV/round22/ITEM3_REAL_BLOCK1_PARTIAL.json`; 2,580 s, 0.85 GiB; stopped at 00:54 UTC for the app's
  post, so TS-1 on a real block did not run): **one real block partial, the rest named** (§10). The R13 block
  commitments' structure (rows, groups, claims) is the same in every real block (round 20's per-commitment table, equal
  per kind), and the rung's two blocks pass with TS-1.
- The other 16 block slots keep D33's argument of record (NL-1 and the terminal surjection passed on the legacy bodies
  at the trained TinyLlama export, D33's G-7); R13 changes only their matmul folds' public values, not their
  polynomials.
- **G-R4, the draw discipline BY VALUE: the stage-47 root-rebuild replay** [MEASURED, gate round 22 item 2,
  `EV/round22/gr4/`]. A test-only port of gate round 10's token replay (D36's PR4-8) to `prove_classify_run_with`
  (`gr4_classify_tests.rs`, in the gate copy `ops/zkp-mvp/gate-tinyllama/gr4-tree-r17/` = token frozen-r17, 303 / 303
  files equal apart from one `#[path]` line in a non-pinned test file): the prover's body replicated on ONE seeded
  generator, its segments **accepted by the production classifier verifier**; at the R13 h24 rung, L = 2 (gates 20 /
  21) verdict 1 whole item, L = 2 verdict 0 short item n = 1, and L = 1 tie, each:
  - **the count by value, stage by stage**: a fresh seeded generator advanced by the gate's formula for the stage (§4's
    draw sites, from the stage's geometry) gives the prover's probe, and 16 bytes further does not (IN-C 6,259,840 B;
    each R13 block 118,593,824 B; OUT-C 7,161,056 B; the run stream at L = 2 14,581,690 field draws + 540,672 salts =
    250,608,544 B = (counted draws − the endpoint's) × 16 + (salts − the endpoint's) × 32);
  - **every root rebuilt in the predicted order** from the witness and the replay stream, never through the
    production commit calls: IN-C B_in / A_in / M_in / H_in (H from the replayed challenges), per R13 block
    B_{k+1} / A / M / H (`prove_core`'s R13 path restated: the ACT3 histogram, queries and table), OUT-C A_out / M_out /
    H_out — all equal;
  - **5 / 5 non-vacuity perturbations** (A_in's proximity word; B_in after A_in; block 0's zero-sum rows from a reset;
    M_out's coefficient copy; a 32-byte stream offset before OUT-C) move exactly their roots and nothing earlier;
  - the input endpoint (its own OS generator) in situ: 2,816 drawn words and 2,048 salts pairwise distinct.
  **The same counting function that gives §4's Shieldstral figure from the real capture's geometry gives exactly the
  replay's per-part counts from the rung captures' files** (`EV/round22/gr4/COUNT_RUNG_L2_v1.json`, `…_L1_v1.json`)
  [COUNTED]. As in D36 (L = 1 and 2 replayed, L = 22 by formula), the real shape is carried by the formula, tied to the
  real geometry by §4's controls K-0 / K-1; no seeded re-prove at the real shape was run (it would stream the
  checkpoint, about 8 GiB).
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
  - **a short item at n = 17, through the app** [READ, `EV/round22/OWNER_RECORD_N17.json`, `dcf54d86…`, from the app
    lane's public records `results/zk60_astra_20261026/real_app_demo_1/input_owner_capture.json` and its per-category
    `sexual.json` / `violence.json` / `hate.json`; no opening, content or activation file read]: the app's first real
    post (17 content ids, a public demo text) proved by the **named r16b binary `dfb8025e…`** under all three moderate
    policies, each `input-owner` exit 0, `content-checked`, content_total 17, range [0, 17), verdict not-flagged,
    against the verified statement's root (three different roots `60efbf79…`, `952e06e3…`, `92a6aafd…`; item lengths
    90 / 90 / 96, 38 / 38 / 32 trailing pads), identity `29aeba6c…`;
  - **round 19's rung short items** (n = 1, 11, 22) have no owner record: the gate's capture hook keeps the
    decommitment in memory and drops it.
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
  - **admissibility** is a public fact of every accepted run (§0); the simulated distribution of §2 is conditioned on
    it;
  - the verifier's tables are functions of public data and challenges: all 19 classifier-stage tables rebuilt (rounds
    19 / 20) and all 17 block-stage arrays per block derived from the export (round 21).

### Step 5 — the hash layer adds nothing (G-R5)

- **Argument of record:** D33's step 5 (Lemma H^run, Route A^run) under D19b [ARGUED]: more roots, the same keyed roles.
- **New here, MEASURED / READ in gate round 22** (`EV/round22/census/`):
  - **C-R2 and W-2** [MEASURED, the frozen v23 replay on the real hate capture with the transcript classes wrapped,
    lengths only; `CENSUS_REAL_HATE.json`, `9868205e…`]: the run's transcript constructor input is 12 + 73 = **85 B, not
    the squeeze length 47**, and no absorb input of the run is 84, 85 or 86 B (36 distinct absorb lengths; nearest 81
    and 87); every one of 287,236 transcript-function calls is keyed; the rung capture likewise (77 B).
  - **C-R1** [READ, `C_R1_READ.json`, `d3923ea0…`]: the 13 unkeyed BLAKE3 sites on the classifier path (the
    classifier's embedding, margin-vector, template, profile, public-statement, calibration and schedule digests, the
    run context (also refused at 40 B at run time by `c_r1`), the R13 block digest, the boundary and endpoint spec
    digests, the trained identity, and the generators' refill) — apart from the refill, which is the reserved 40-byte
    class, every input's length exceeds 40 for every admissible parameter (the shortest, the template digest, is 45 +
    8k); none depends on the hidden content.
  - **A, the transcript-query count, is measured: 287,237** (the constructor, 13,330 absorbs, 273,906 squeezes, every
    instance including the position tags' clones), replacing v1's bound of 2^20 (§4).
- **MEASURED** in every record: every challenge re-derived, the run binding reproduced, every opened column re-hashed
  and re-authenticated under the derived keys.

## 4. Residuals, sized [COUNTED]

- **Source:** `EV/round21/classify_run_counts.py` → `EV/round21/CLASSIFY_RUN_COUNTS.json` (`513c376d…`), with A from
  `EV/round22/census/CENSUS_REAL_HATE.json`.
- **Method:** D33 / D36 §4 (the round-9 script in force for D36), each formula re-read for the classifier stages, applied
  to the real hate capture's own geometry. **Control K-0:** the same residual function, fed round 9's L22 geometry and
  measured transcript counts, reproduces D36's 2^-70.35. **Control K-1:** each of the 27 boundaries draws 108,032, the
  frozen counting script's figure for that geometry. **Confirmed by value (gate round 22, §3 Step 4 "G-R4"):** the
  seeded replay at the R13 rung found the prover consumed exactly the bytes this function predicts, stage by stage, and
  the function applied to the rung captures' files reproduces the replay's per-part counts exactly.

**Draw sites** (D36's wording): a hiding commitment draws (rows − data)·n + rows·Q; an H also draws its zero-sum pair,
2(n − 1), once; a masking commitment draws 2·ΣL_s + 2·N_slots·Q + 4,096 with L_s = rounds_s·d_s + 2.

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
| Transcript pre-query, q·A·2^-256, **A = 287,237 measured** (round 22) | 2^-109.87 | distance |
| Leaf-input / transcript-input collisions, C(N_leaf, 2)·2^-256 / C(A, 2)·2^-256 | 2^-212.3 / 2^-220.7 | distance |
| Generator, in-model alternative (6q·2^-256, ASSUMED) | 2^-125.4 | assumption |
| Generator-key row, 3·4·2^-256 | 2^-252.4 | distance |
| Constructor vs absorb, (A + q)·2^-256 | 2^-128.0 | distance |
| **Total distance per run** | **2^-68.19** (the sampler bias is 99.9999999993 % of it) | |
| Refusal on degenerate challenges, (3L + 6)/p = 84/p | 2^-57.6 | **liveness, not distance** |
| A post of J runs (§2 corollary): J = 3 / 22 | 2^-66.60 / 2^-63.73 | distance |
| 10^6 runs, linear | 2^-48.26 | distance |
| 10^9 runs, linear | 2^-38.29 | distance |

**Notes.**

- **Per run; a post is J runs** (§2 corollary). The cross-run hash terms raise q by J·A ≤ 22 × 287,237 < 2^23, which
  changes no row above at the quoted precision [COUNTED].
- **The refusal term** is charged at the class maximum of four SiLU groups per layer (16,896 table rows a hidden query
  can hit per block: the byte table 256, exp 256, ACT3 4,096 × 4); at the export's actual 3–4 groups it is 2^-108.42
  [COUNTED, round 19 recount, `EV/round19/refusal/R19_REFUSAL_RECOUNT.json`, `c12550a6…`]. It replaces D40's 2^-112.7
  (the legacy 256-row activation table) for any classifier statement at the R13 Shieldstral profiles. The pad rows add
  no distinct value: in IN-C a pad position's query is pinned to the public pad id; in the blocks the pad rows' queries
  fall in the same tables (the count is over table rows, not positions). The review notes the count is conservative:
  the block code inverts every row of its three tables on every attempt, so the block part may depend on the
  challenges only (review P-12).
- **Against D36:** TinyLlama's 22-block run draws 52.7 M and sits at 2^-70.35; Shieldstral's blocks are 3.8 times
  larger (8.93 M draws each), so a 26-block classifier run sits about 2.2 bits higher.

## 5. Conditions — D33's and D36's, and those the classifier adds

| # | Condition | State |
|---|---|---|
| 1–6 | D33's conditions: reserved pairs and exclusivity; pads = opened columns; mask rounds and functional order; one opening per commitment; salted leaves; fresh OS randomness | Measured for all 84 commitments of the real run (G-1 / G-2 / G-3 / G-6, rounds 19–20). One opening per commitment, **the input endpoint opened once**. The draw discipline replayed by value at the rung (round 22 item 2) |
| 7 | The gates' source pins; a change suspends step 3 | **the 72 pins** of a classifier capture under the v23 rule; a moved pin is refused by name (v22 refused the r17 captures on `run_capture.rs` alone, round 20 failing-first) |
| C-1 | One external endpoint, no output endpoint, the verdict a public bit in the header and the margin slot's right-hand side (D40) | Code fact [READ]; round 20 `G6_endpoint.no_output_endpoint` [MEASURED] |
| C-2 | The policy is one of the registered list Π (D45(2)); exactly |Π| = 3 policies admitted at this profile (r16b's production list also holds the development policy, which this profile refuses by its V = 300 and margin parameters, pinned by r16b's test); an item is never re-proved under another policy or threshold | Code fact (r16b F-1 fix, test of exactly three) [READ]; **an operating rule for "never re-proved"** (§6, R3) |
| C-3 | n, the chunk facts, the pad id and positions and the verdict row are the public length facts of D45(1) / D41 and nothing else | Measured: C13-1..C13-4 fire at pad id 11; short-versus-full pairs differ only in those fields (round 19) |
| C-4 | Every input-provokable refusal precedes the header (H-1 for classifier runs) | Code fact at the CLI (REVIEW_R16 §§2–8; R19 §6(b)) [READ] |
| C-5 | D34's premises at R13: no draw or absorb between the inversions, no retry, no position tag changing the count | [READ, round 19 recount]; a reading condition for the security owner (the review P-12: not blocking) |
| C-6 | The margin row, the embedding and every block table are the export's / the checkpoint's | Classifier: B-3 derived from the checkpoint by the gate, bit-exact; blocks: the 17 arrays derived from the export by the gate (round 21) [MEASURED] |
| C-7 | **No non-public post goes through the app until it serves failure status only to the authenticated author** (rule R2, §6) — in the form D36 used for TR7-3 | **Not met today** (the review P-7: the demo app's `GET /api/posts/{pid}` and `/api/submissions?author=` serve status, per-chunk reasons and submissions to any caller; the "author" check is an unauthenticated query parameter). The fix belongs to the app lane |
| C-8 | **The real-model refusal rate is measured before the app runs on non-public posts** (the integer evaluator alone) | Not measured (§10) |
| P-4 | The export, the tied tensor, the policy texts and templates, the context, **the profile (T) and the chunk plan** are fixed before and independently of any hidden content; no item is retried under another export, policy, label, profile or chunk plan | A HYPOTHESIS the sentence carries; the app's retry rule meets it (§6, R3) |

## 6. Hypotheses and operating rules

D33's and D36's §6 rules carry over, with these additions.

- **CPU only, the named binaries, one run per process call.** A deployment runs `dfb8025e…` (r16b) or `81bd8624…`
  (r17), one `prove` per (category, chunk). Another binary, even one rebuilt from these trees, is outside this statement
  until it is named. The round-16 binaries are outside it. **`prove-batch` and every r18 binary are outside it** until
  named: naming needs the A5 review's fixes adopted (`r18/A5_PATCH_REVIEW.md` findings 1, 2: its two new `#[path]`
  files sit outside the randomness census, and a failed batch leaves earlier receipts and `input.dec` behind that look
  finished — and leftover receipts of a failed post, if published, would show which category failed), the census
  extended to its new files, A5 §4's byte-identity check passed, and the §2 corollary read for one process.
- **The refusal, retry and display rules** (the review P-7):
  - **R1 (all or nothing).** A post's proofs are published (anchored, listed in a manifest, made visible) only when
    every category and every chunk has an accepted proof. On any failure nothing about the attempt leaves the prover
    host: no partial receipts, statements, anchors or manifest entries. *The app meets R1 in code* (`jobs.py:328–331`
    publishes a chunk's records only when the whole post is accepted; its `DESIGN.md` §1 item 5 text is stale against
    D45(4)) [READ, the review].
  - **R2 (who sees a failure).** Only the authenticated author sees that a post could not be verified: one bit per
    post, not per chunk or category. No reason, chunk index, layer, timing or attempt count is shown or stored where
    others can read it (D21). *The app does not meet R2 today* (condition C-7).
  - **R3 (no new questions).** A post refused before its header is never re-proved under any changed public parameter:
    policy wording or list, threshold, export, profile (T), chunk size or overlap. Each change would ask new yes / no
    questions about the same text. An identical retry is allowed and reveals nothing new, because the refusal is
    deterministic. *The app meets R3* (`store.py:112–130`) [READ, the review].
  - **R4 (retries of random failures).** A failure after the header (the 2^-108.25 event, a degenerate challenge, a
    machine failure) may be retried with fresh OS randomness up to a fixed bound; each retry adds at most 2^-108.25 of
    content dependence, and the count is not shown. *The app's stricter rule meets R4* (no retry once any prove work
    ran) [READ, the review].
- **Fail closed (D45(4)).** A post without an accepted proof for a category is not published and is shown as "could not
  be verified" — to its author only (R2) — never as safe.
- **The guard cap.** The resource guard's memory cap for a classifier prove is set with margin above the class maximum
  (the real proves peaked at 8.08–8.27 GiB across the three categories), so that no honest post is killed for its
  memory; a kill near the cap would be a failure that depends on the input.
- **One fixed policy list (D45(2)).** Each listed policy is one public yes / no bit about each chunk. Changing the list
  (the strict / moderate ruling, or a fourth category) changes Π and this statement's sentence; an item proved under one
  wording is never re-proved under another.
- **The proof is linked to the post (D45(3)).** The input endpoint root is stored with the post and anchored on-chain
  (D39); the app keeps the opening, and anyone given the post's text and the opening can check the link. **Accepted
  consequence: whoever holds an opening can prove which content was posted.** The opening is as sensitive as the
  content; it is never published (D21), never put in a capture or an export, and no later artifact claims or opens the
  root. This is **D23 as amended by D45(3)**, not D23 met: re-publishing the same root adds nothing, since D19b's
  hiding rests on fresh per-column salts, provided no later proof claims or opens it
  (`results/zk60_token_io_r1_20261017/classifier/check/CHECK.md:258–263`, `DESIGN_CLASSIFIER.md` §6.1); the toy's O-2 is
  carried only in this amended form.
- **Publication.** Publish a run only after one's own fresh-process verification (the CLI's `verify` does it). Never
  publish the opening, the content, the per-layer activations (`--seq-dir`), prover stdout, refusal text or verifier
  output beyond the statement.
- **Owner storage.** Openings live under the CLI's owner base (`$HOME/zk60-owner-private/token-io/`, 0700, outside every
  artifacts tree), or the app's own owner-only directory. Delivery of an opening to a separate party is not built.
- **Content length is public** (D45(1)). Hiding it is a later, costlier variant.

## 7. Findings, with dispositions

| # | Finding | Disposition now |
|---|---|---|
| **R19-1** | Range refusals depend on the hidden content, pad rows included (102 of 300 ids refuse at one dev calibration; none at the other) | **Stated both ways** (§0, §2): admissibility is a function of the content; a refusal shows "could not be verified" to the author only (R2); an accepted proof publishes admissibility (review P-5). The real-content rate must be measured before non-public posts (C-8) |
| R19-2 (refusal term) | The R13 SiLU tuple table has 4,096·G rows, so D40's 2^-112.7 is wrong at R13 | **Recounted: 2^-108.25** (round 19), carried in §4 |
| R13-T (taken tables) | Rounds 19 / 20 took the 15 block tables per stage from the capture, on the recorder's attestation | **Closed by measurement in round 21** (§3 Step 3) |
| Review P-1 / P-2 | NL-1 and the surjection on the R13 / classifier slots; the GR4 replay | **Round 22 items 3 / 2** (§3 Step 4) |
| O19-1 | At the R13 rung the margin is the same for every item: the rung's verdict does not depend on the content | Noted: the rung figures rest on the code, not on content dependence; only the real captures are content-dependent |
| F19-G1 / F19-G2 / F20-G1 | The gate's own tools (repository root, refused pins, file reads) | Fixed in v23 |
| O20-1 | A values capture's array store becomes resident file pages when memory-mapped | Operations only (declarations); rounds 21 / 22 read the store with pread or a lazy resolver |
| N20-1 | The r17 values bundle's README names the round-19 tree | Wording only (token lane) |
| N-r14-6 | Pad-row refusals were not observed on the real item | Part of R19-1 |

## 8. What must not be claimed, even if this came into force

- That the verifier "learned nothing" without the distance. Say it was never given the hidden values and that its view
  is within the stated distance of one computed from the public facts alone.
- That the public facts are harmless: the verdict bits, n and the chunk ranges are disclosed, and at small n they say
  much about the content (§0).
- **That an accepted proof reveals nothing about the content beyond the verdict and the length**: it also reveals that
  the post is admissible (§0).
- **That admissibility is hidden**, or that "could not be verified" reveals nothing: it is a function of the content,
  and who learns it depends on the app (§6, R2).
- **That a whole post is covered by the per-proof figure**: a post of J proofs is J times it (§2 corollary).
- That the content length is hidden.
- **That the time, memory or number of attempts of a proof reveal nothing**: they are out of scope (D20), and the app's
  public record shows the proving time (`timings.work_s`, `proved_at`: `jobs.py:365–368` [READ, the review]).
- **That `prove-batch` or any r18 binary is covered.**
- **That the real model was gated at more than one length and verdict**: only n = 35, not-flagged, hate and sexual.
- **That the rate of "could not be verified" is known.**
- That the verdict is the float model's. It is the approved integer model's (fidelity is D32's question).
- That the classifier is accurate, or that "not flagged" means safe. The statement is about privacy, not quality.
- That the proof shows *which* content was posted to anyone without the opening (it does not: D45(3) needs the
  opening).
- That the proof hides the post from the app that runs the prover.
- Anything at T256, at another export, policy wording or list, for another binary, on the GPU, for images, or about
  soundness.
- That D33 or D36 covers this run, or that this draft extends them.

## 9. What would lapse or reopen it

- Anything in D33 §9 or D36 §9 that touches the blocks, the endpoint or the hash layer.
- A change to any of the 72 pinned files, or another binary (including `prove-batch` / r18 until named).
- **A change of the policy list Π** (Victor's strict ruling replacing the moderate three, a fourth category, a new
  threshold): the sentence is re-evaluated at the new list (the gate re-captures one policy of the new list; the
  per-run figure does not depend on the policy text but the template length P0 does change n's range and the pad
  positions).
- A different export, tied tensor or calibration (a new `profile.json` digest or trained identity).
- A finding against any step of §3, or a lapse condition of D34 / D40.
- An endpoint opened twice, an opening published, the root claimed or opened by a later artifact (D23 as amended).
- A refusal provokable through the content after the header (C-4).
- A run that shares randomness or an endpoint with another run (the corollary's hypotheses 1–3).
- A GPU-built receipt.
- A per-block table, margin row or embedding that the gate cannot derive from the named export and checkpoint.
- The app publishing failure status, partial receipts or per-chunk failure reasons to anyone but the author (R1 / R2).

## 10. What is owed before the security owner could rule

**Closed since v1** (the review's list; rounds 21 / 22):

| Item | How |
|---|---|
| The real capture's declared limits | Gate round 20 [MEASURED] |
| The refusal term at R13 | 2^-108.25 (round 19) [COUNTED] |
| The per-run distance figure | **2^-68.19** (round 21, §4), with A measured in round 22 [COUNTED / MEASURED] |
| A gate-side derivation of the 15 block tables | Round 21: 442 / 442 arrays equal [MEASURED] |
| The input owner's check on the real runs, recorded by the gate | Round 21 `OWNER_RECORD.json` [READ] |
| **The C-R1 / C-R2 hash-input census** (v1 item 4) | Round 22 (§3 Step 5) [MEASURED / READ] |
| **The stage-47 replay (G-R4 by value)** (v1 item 2; review P-2) | **Closed at the R13 rung, L = 1 and 2** (round 22 item 2): verifier accepts, counts by value per stage, every root rebuilt, 5 / 5 non-vacuity [MEASURED] |
| **NL-1 S1–S5 and the surjection with TS-1** (v1 item 3; review P-1) | **Closed on the rung, and on the real capture's classifier stages (NL-1; the surjection with TS-1 6 / 6) and two real blocks (NL-1)**; the surjection on a real block **partial** (block 0's three roles, no TS-1) (round 22 item 3) [MEASURED]. Remaining by measurement, if the re-review asks for it: TS-1 on a real block and the surjection on further real blocks (~1 h of a cpu slot each); NL-1 on the other 24 real blocks (~26 × 25 s, 1.6 GiB); commands in `EV/round22/R22_SUMMARY.md` |

v1's §10 item 3 said "today the premise checks and the terminal identity are measured". For the 7 R13-redefined block
slots that was wrong: rounds 19 / 20 had no NL-1 entry for them at all (the review P-1). Corrected here.

**Still owed:**

1. **The privacy re-review of v2.**
2. **The real-model refusal rate** (the integer evaluator on a sample of real posts; no prover needed), before the app
   runs on non-public posts (condition C-8; the review P-5).
3. **The app's failure display (R2)** before non-public posts (condition C-7; the app lane).
4. ~~An owner check at n ≠ 35~~ **recorded** (round 22: the app's 17-id post, three policies, r16b, `OWNER_RECORD_N17.json`).
   Still welcome, not blocking (the review P-9): a real-shape capture of a short item under the violence policy, and a
   real flagged item.
5. **Victor's strict / moderate wording ruling**, and with a strict list a gate re-capture under it.
6. The independent check of token rounds 16b and 17 (the review §2 item 7 confirms the code reading), and the token
   lane's README note N20-1.
7. **The security owner's decision and Victor's acceptance.** No lane can claim a privacy acceptance.

## 11. Evidence index

| What | Where (EV = `results/zk60_gate_tinyllama_20261017/`) |
|---|---|
| Gate round 18 (the R-C3 rung, 21 captures) | `EV/round18/R18_SUMMARY.md` (`c8046dd0…`), `R18_SUMMARY.json` (`d3ad213c…`); tools v21 (`25814977…`) |
| Gate round 19 (R13 rung, 13 captures; the real sexual re-prove) | `EV/round19/R19_SUMMARY.md` (`c01ff9f5…`), `R19_SUMMARY.json` (`96e333e8…`), `C13_PER_N.json` (`65bcae83…`), the real record `EV/round19/v22/v22-classify-r13-shield-t128-cli-sexual-r16b.json` (`901c1f7a…`); tools v22 (`ab703596…`) |
| The refusal recount | `EV/round19/refusal/R19_REFUSAL_RECOUNT.json` (`c12550a6…`) |
| Gate round 20 (the real hate run, no declared limit) | `EV/round20/R20_SUMMARY.md` (`b4db9702…`), `R20_SUMMARY.json` (`24e1d6b9…`), the record `EV/round20/v23/v23-classify-r13-shield-t128-cli-hate-r17-values.json` (`e94d6e7b…`); tools v23 (`64f4b757…`) |
| Gate round 21 | `EV/round21/R21_SUMMARY.md` (`cffc21b3…`); `derive_block_tables.py` (`7eb5917e…`), `dev/dev_b1.json` (`b2c92067…`), `derive/DERIVE_ALL.json` (`5c2c7111…`); `classify_run_counts.py` (`87492320…`) → `CLASSIFY_RUN_COUNTS.json` (`513c376d…`); `owner_record.py` (`46d810b1…`) → `owner/OWNER_RECORD.json` (`09b824df…`) |
| Gate round 22 | `EV/round22/R22_SUMMARY.md`; the census `EV/round22/census/` (`hash_census.py` `9b2a2433…`, `CENSUS_REAL_HATE.json` `9868205e…`, `CENSUS_RUNG_L2_v1.json` `59614924…`, `C_R1_READ.json` `d3923ea0…`); the GR4 replay `EV/round22/gr4/` (`gr4_classify_tests.rs`, the three test logs, `COUNT_RUNG_L{1,2}_v1.json`); NL-1 and the surjection `EV/round22/item3/` (`ITEM3_REPORT.md` `3be42c0a…`) and `EV/round22/ITEM3_REAL_BLOCK1_PARTIAL.json`; the n = 17 owner record `EV/round22/OWNER_RECORD_N17.json` (`dcf54d86…`) |
| The privacy review of v1 | `results/zk60_privacy_review_20261029/CLASSIFIER_T128_PRIVACY_REVIEW.md` |
| The captures | `~/zk60-artifacts/token-io/captures/classify-r13-shield-t128-cli-hate-r17-values/` (the hate run with its public tables; 2.25 GB store), `…-cli-sexual-r16b/`, the 13 `classify-r13-rung-L*` captures |
| The real runs | `~/zk60-artifacts/token-io/r16-runs/{hate,sexual,violence}-run/` (statements `/3`), the token lane's `r16/real_runs.json` and `r16/logs/real-*` |
| The export | `results/zk60_shieldstral_export_20261026/native_low_h24_t128/` (profile `2ba468f9…`; 26 layer manifests) |
| Code and binaries | `results/zk60_token_io_r1_20261017/frozen-r16b/` (`04d94bc0…`), `frozen-r17/` (`23a95876…`), `cli/zk60_classify.r16b.release.bin` (`dfb8025e…`), `cli/zk60_classify.r17.release.bin` (`81bd8624…`) |
| Reviews (soundness) | `results/zk60_token_io_review_r1_20261017/REVIEW_R13.md` (`9537a60a…`), `REVIEW_R14.md` (`dbf05846…`), `REVIEW_R16.md` (`da6e2f79…`), `r18/A5_PATCH_REVIEW.md`; `results/zk60_d24_review_20261017/REVIEW_R13.md` (`7ea6d302…`) |
| Design | `results/zk60_token_io_r1_20261017/classifier/DESIGN_CLASSIFIER.md` (v2.7) §§1–6, 13–18 |
| Register | `docs/zkmatrix-poc/ZK60_DECISIONS.md` D19 / D19b, D20, D21, D23, D29, D33, D34, D36, D37–D41, D45 |

## 12. Disposition of the review of v1 (finding → where v2 answers it)

| Finding | Severity | Where v2 answers it |
|---|---|---|
| P-1 NL-1 absent on the R13 block slots | blocking | §3 Step 4 "G-R2" (round 22 item 3); §10 "Closed" and the corrected item-3 wording; §0 "measured" |
| P-2 G-R4 not replayed on IN-C / OUT-C / R13 | blocking | §3 Step 4 "G-R4" (round 22 item 2, at the rung, L = 1 and 2); §4 method; §5 conditions 1–6 |
| P-3 whole-post sentence | must-change | §2 "Corollary (one post)" with its four hypotheses; §0 "a post of J proofs is J times this"; §4 table row and note; §8; §9 |
| P-4 the batch command / r18 | must-change | §0 "Which code"; §1 "Binaries" and "Not in scope"; §6 first bullet; §8; §9 |
| P-5 admissibility is revealed | must-change | §0 "public facts reveal" (new bullet) and "refusal channel"; §2 sentence (conditioned on admissibility); §3 Step 4 "new channels"; §8 (two bullets); §10 item 2 and condition C-8 (rate before non-public posts); the Cn 4,000 result added |
| P-6 three plain-words errors | must-change | §0 "refusal channel" (who learns what; machine failures; "the only refusal after the start whose chance can depend on the post"; "for an admissible post …"); §2 ("a function of its content that anyone holding the content can compute … depends on the app's display rule"; "what can still fail after the header") |
| P-7 refusal / retry / display rule | must-change | §6 rules R1–R4 with the app's state; §5 condition C-7 ("no non-public post … until failure status is served only to the authenticated author") and P-4 ("profile (T), chunk plan"); §9 last bullet; §10 item 3 |
| P-8 timing / memory | must-change | §1 "Not in scope" (D20; the app's salted SHA-256 commitment); §6 "The guard cap"; §8 (`timings.work_s`, `proved_at`); §2 "what can still fail after the header" |
| P-9 which binary made each piece of evidence | must-change | §0 "What has been measured, and by which binary" (e94cecf9 for round 20; r16b's own receipt with limits; r17 never proved; real shape gated at n = 35 not-flagged hate / sexual only; r16b's real receipts at n = 17 under all three policies, owner-checked, not gated); §1 rows; §3 Step 4 owner checks; §8; §10 item 4 |
| P-10 end-aligned overlap | note | §0 "Per-chunk bits" (up to 54 of 55 tokens; the N = 56 example); §1 "Item lengths" |
| P-11 n = 1 upper bound | note | §0 "at most 130,072" with the tokenizer remark |
| P-12 refusal term conservative; C-5 a reading | note | §4 note; §5 C-5 |
| P-13 census done; A measured | note | §3 Step 5; §4 (A = 287,237, pre-query 2^-109.87); §10 "Closed" |
| P-14 D23 amended, not met | note | §6 "The proof is linked to the post" (CHECK.md:258–263, DESIGN §6.1; O-2 in amended form) |
| P-15 the production list holds the dev policy | note | §1 "Policies"; §5 C-2 |
| Review §2 item 8 wording | — | §0 "Who sees the post" and "for a post that passes the integer model's ranges"; §8 additions |
