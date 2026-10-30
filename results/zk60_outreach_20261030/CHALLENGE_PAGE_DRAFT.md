<!--
DRAFT for Victor. First written 2026-10-30 ~20:32 UTC by a Claude agent; redesigned ~20:42 UTC
after Victor's objection to guessing games; updated ~20:48 UTC to his ruling D52 (the reveal is
approved; the win rule is 4 consecutive tokens; the scope is offline only). The primary game is
random-secret recovery, where one correct answer is a break and no statistics are needed. Not
published. Fill every <...>. No bounty amount: funding is on hold (D47). Public credit only.
The remaining open items are listed in this folder's README.md.
-->

# Break the privacy claim

*<PROJECT_NAME> · <REPO_URL> · challenge open <START_DATE> to <END_DATE>*

Our prover makes zero-knowledge proofs that a public language model computed a result, and it
hides the input, the output and every intermediate value from whoever checks the proof. We have
written down exactly how private we claim this is. **We ask you to show that we are wrong.**

The main challenge is simple: **each receipt below hides a random secret. Tell us four
consecutive tokens of any one of them.** A blind guess succeeds with probability about
2 × 10^-18. Even 100 million guesses stay near 2 × 10^-10, so a single correct answer is a break.

There is no money: this project has no funding today. If you break a claim, you get public credit
in the repository, in the decisions register and, with your permission, in the paper. And we fix
it.

## 1. What is claimed

Each claim is a **privacy statement**: one sentence with a number, plus the conditions it rests on.
It covers named binaries only, meaning the exact program files identified by SHA-256 hash. A binary
you build yourself has a different hash and is not covered. You can still use your own build to
*verify* our challenge receipts.

### Accepted statements (in force)

| ID | What is proved | The claim, in plain words | Exact scope |
|---|---|---|---|
| **D36**, the target of this challenge | **TinyLlama-1.1B next token**: prompt lookup, all 22 blocks, final norm, head and greedy choice, in one proof | A checker is never given the prompt's tokens at positions 1–31, their embeddings, the activations, the scores or the next token. Its view is within about **2^-70.35 per run** of one that does not depend on them | 32 tokens, public-row variant, calibration `pg_rot1_b4_T32_cal128`; CPU path; named token binary `0c9f247c…` (frozen-r11), extended from `b56f1b71…` (frozen-r9) |
| **D33** | A trained **TinyLlama-1.1B** block stack, 22 blocks, 32 tokens | About **2^-70.4 per run** (2^-74.8 at 1 block, 2^-73.8 at 2) | profile `hashline-zk-mr1/private-run-tinyllama-1.1b-t32-trained-statement/1`, calibration `pg_rot1_export_T32`; CPU path; trained-block binary `631e2a15…` (frozen-r11). No challenge set for D33 yet |

**D36's public facts** (not hidden, and not a break):
- the prompt length T = 32;
- the BOS token at position 0;
- the vocabulary size V = 32,000;
- the embedding, final-norm constants and head, by digest;
- the run length L, the trained-model identity and the tier.

**D36's assumptions:**
- BLAKE3 behaves as a random oracle, keyed per role (D19, D19a, D19b);
- the prover's random generators are indistinguishable from uniform, and independent across runs
  (E-1, X-1).

The full texts are `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_NEXT_TOKEN_TINYLLAMA_T32.md` (D36) and
`docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_TRAINED_TINYLLAMA_T32.md` (D33). Read §2 (the sentence),
§5–§6 (conditions and operating rules), §8 (what is not claimed) and §9 (what makes a statement
lapse).

### Draft statement (not in force)

| ID | What is proved | The proposed claim | State |
|---|---|---|---|
| Classifier v3 | **Shieldstral-1.0-3B** safety-classifier verdict on a hidden post, T128, one proof per (category, chunk) | A checker learns nothing beyond the verdict bit, the policy, the post's length and chunk facts, the model, and the fact that the post passed the integer model's ranges, except with about **2^-68.19 per proof** (J proofs: J times that) | **Draft v3, not accepted, not in force.** <UPDATE WHEN VICTOR RULES.> Named binaries `dfb8025e…` (r16b) and `81bd8624…` (r17). There is no challenge set for it |

Reports against the draft are welcome now. They are credited, and they shape the statement before
acceptance. They count as **breaks** only once the statement is accepted.

## 2. The main challenge: recover a random secret

### The receipts

We publish **M = 20** (D52; <CONFIRM M>) accepted D36 receipts, made fresh by the named binary `0c9f247c…`. Every
receipt proves TinyLlama's next token on a 32-token prompt with the same layout:

| Position | Content | Public? |
|---|---|---|
| 0 | BOS | public (D36) |
| 1–21 | a fixed template, the same 21 token ids in every receipt, published in full: `<TEMPLATE_IDS>` | public by us |
| **22–31** | **the secret: S = 10 token ids, each drawn uniformly and independently from all V = 32,000 ids** | **hidden** |

- **Why all 32,000 ids.** D36's sealing check admits any id below V at positions 1–31; only
  position 0 must be BOS (statement §2, "Admissible"; `token_io/stage_in.rs:88-93`).
- **The secret's entropy:** 10 × log2(32,000) ≈ **149.7 bits** per receipt.
- **Same public facts every round.** Every receipt has the same length, layout and public facts.
  The next token is the model's output on a random input, so you cannot compute it without the
  secret.
- **Why random and not natural text.** If the secrets were natural text, a language model's prior
  could recover tokens far above chance without any break. Uniform secrets leave nothing to guess
  from.

### The win

A **guess** names one receipt i, one starting position j in 22–28, and four token ids. **A guess
wins if those ids equal the secret's tokens at positions j, j + 1, j + 2 and j + 3** of receipt i
(D52).

- One winning guess is a break. Guessing the whole secret also wins, since it contains every
  window.
- **No global cap on guesses.** The chance below stays negligible at any realistic number of
  guesses.
- **A handling limit, not needed for the bound:** <OPTIONAL: up to 1,000 guesses per entrant, so
  that checking stays manageable.>
- **Recovering only the next token does not win.** Its chance cannot be bounded from the secret's
  entropy: the model's output on random input may be quite predictable. Report it anyway as a
  finding (see §4).

**The chance of a blind guess** [COUNTED, 2026-10-30]:

| | Probability |
|---|---|
| One guess, four uniform ids | 32,000^-4 = **9.54 × 10^-19** (about 2^-59.9) |
| One guess, after the admissibility correction below (at most a factor of 2) | ≤ **1.91 × 10^-18** |
| One entrant, 1,000 guesses (if the optional handling limit is used) | ≤ **1.91 × 10^-15** |
| **10^8 guesses in total, over all entrants and all M receipts** | ≤ **1.91 × 10^-10** |
| The number of guesses at which the total would reach 10^-9 | about 5.2 × 10^8 |
| Guessing a whole 10-token secret | 32,000^-10 ≈ 8.9 × 10^-46 |

The bound does not grow with M, because every guess names a single receipt.

- **The admissibility correction.** A prompt is proved only if it passes the integer model's range
  checks. A drawn secret that fails is discarded privately, publishes nothing (D21), and is
  redrawn. The published secrets are therefore uniform over the *admissible* secrets, and a guess's
  chance is at most 32,000^-4 divided by the acceptance rate. We require an acceptance rate of at
  least 1/2 (prerequisite P3 below), hence the factor of 2.

### The commitment: commit now, reveal later

- **Before the start,** for each receipt i we publish `C_i = SHA-256(salt_i ‖ secret_i)`.
  - `salt_i` is 32 fresh random bytes (256 bits), different for every receipt.
  - `secret_i` is the 10 ids encoded as 2-byte big-endian unsigned integers, 20 bytes in all.
  - The receipts themselves carry a second commitment: the prover's sealed input fingerprint (the
    input endpoint root).
- **Generation.** The secrets and salts are drawn from the operating system's random source when
  the challenge is created, by a script we publish beforehand: `<GENERATION_SCRIPT_PATH>`.
  - Ids are drawn with an unbiased method (Python's `secrets.randbelow(32000)`), and salts with
    `secrets.token_bytes(32)`.
  - The secrets and salts stay in owner-only storage until the reveal.
- **At the end,** we publish:
  - every salt and secret, so anyone can recompute every `C_i`;
  - the number of discarded draws;
  - the input-endpoint opening of every receipt, so anyone can run the input-owner check and see
    that each receipt was proved on exactly that prompt.
  Anyone can then check every guess.
- **This reveal is approved as D52.** It is a deliberate, scoped exception to the rule that
  openings and inputs are never published (D21). It covers only these synthetic challenge receipts,
  made from random secrets; no real or user content is ever revealed. No later proof refers to
  their roots (D23), and they are used for nothing else.

### Downloads

- the M receipts, the template ids and the commitments `C_1 … C_M`: <CHALLENGE_ASSETS_URL>, with
  `SHA256SUMS`;
- the verifier build and TinyLlama verification steps: <REPO_URL> README §4–§5, plus
  <TINYLLAMA_VERIFY_STEPS>.

## 3. Secondary and optional: measure partial leakage (the distinguishing game)

This game is clearly secondary. Run it only if you think a leak is real but too weak for the
recovery game.

- **The setup.** For each round i = 1 … N, we publish two candidate prompts A_i and B_i. Both use
  the §2 layout, with independent uniform secrets, so they have the same length and public facts.
  We flip a fair coin in private and publish one accepted receipt, proved on the prompt the coin
  chose. At the start we publish `SHA-256(salt_i ‖ coin_i)` for each round, and we reveal the salts
  and coins at the end.
- **The test, registered before the start:** a one-sided binomial test at **p < 10^-6**, with N and
  K fixed in advance. Choices that meet it:

  | N | K (correct guesses needed) | Chance by guessing |
  |---|---|---|
  | 32 | 30 | 1.2 × 10^-7 |
  | 64 | 51 | 9.4 × 10^-7 |
  | 100 | 74 | 8.3 × 10^-7 |

  <VICTOR DECIDES N; K follows from the table.> Each entrant gets one guess per round, submitted as
  a single sheet before the reveal.
- **Reaching K is a break.** **Falling short of K is not evidence of privacy:** a real but small
  leak can stay under any fixed threshold. The claim rests on the written argument, not on this
  game.

## 4. Other findings that count as breaks

These are not guessing games. Each counts once we have reproduced it:

1. **A false step.** A step of an accepted statement's argument that does not hold for its named
   binary, shown concretely. Examples:
   - a commitment whose opened view discloses more than the statement declares;
   - a random draw that is reused, predictable or correlated across runs;
   - a hash input that two roles share, which the census missed;
   - a residual undercounted so that the true distance is materially larger than the stated
     figure.
2. **A scope error.** The named binary does something the statement says it does not. Examples: a
   content-dependent refusal **after** the run header; a second opening of an endpoint; a receipt
   that carries a hidden value in plain form.
3. **A method that recovers the hidden next token** of the §2 receipts consistently. It is not a win
   by itself (§2), but we will evaluate it against the revealed secrets, and credit it if it shows
   a leak.

**Soundness reports** are also welcome and credited: an accepted receipt for a false statement,
such as a wrong token or a wrong model. They are not privacy breaks, but they matter more.

## 5. What is not a break (already stated as limits)

- **The public facts.** For D36: the length, BOS, V, the model digests and L. For the classifier
  draft: the verdict bits, the length, the per-chunk verdicts and the end-aligned last chunk.
- **Admissibility and refusals.** Whether a prompt passes the integer ranges, and whether it is
  refused, depend on the content. This is stated.
- **Several proofs of one item.** The bound for J proofs is J times the per-proof bound, as stated.
- **Timing, memory, power and attempt counts** (out of scope, D20).
- **What the prover host sees,** anything that needs an opening, and the demo app's failure display
  (condition C-7 is open and stated).
- **Binaries that are not named,** GPU builds, other calibrations, models or lengths, and the
  `prove-batch` path.
- **Attacks on the assumptions themselves:** BLAKE3, the random-oracle model, or the operating
  system's random source. Tell us anyway. That is a result outside our claim, and we will credit it
  as such.

## 6. How to submit

1. **Report privately first** to <SECURITY_CONTACT>, or as described in `SECURITY.md`.
   - For a §2 guess: the receipt i, the position j and the four ids. One line per guess (within the
     optional handling limit, if set), sent before <END_DATE>.
   - For §3: one sheet with all N guesses.
   - For §4: the statement ID, the files used, the method, and code or a transcript that reproduces
     it.
2. **We acknowledge** within <ACK_DAYS> days. Guesses are checked at the reveal. The project's
   security owner and one independent reviewer check every other claimed break.
3. **Public disclosure** of a §4 finding comes after <DISCLOSURE_WINDOW> or once it is fixed,
   whichever is first. You may then publish your own write-up.
4. **Credit:**
   - your name (or handle) and the finding go into <CREDITS_URL>;
   - the decisions register records what changed;
   - the paper's acknowledgements include it, with your permission.
   The first complete report of a finding gets the credit.

## 7. Rules

- **Scope:** attacks are offline analysis of the published receipts and files only. Do not attack
  any live system, service or person.
- No bounty and no payment of any kind.
- We may update this page. Changes are dated, and a finding is judged under the version in force
  when it was reported. The win rule, M, N and K never change after the start.

## 8. Status of the system (so you know what you are attacking)

- **A research prototype.** It has **not been externally audited**. The arguments survived
  independent review inside the project, and they are not machine-checked.
- **Soundness:** about 95–97 bits per whole run, depending on the profile. This is an accepted
  deviation from a 128-bit target (D27).
- **Measured on one laptop CPU** (n = 1): a TinyLlama next-token proof takes 85 s and makes a
  255 MB receipt; a Shieldstral classifier verdict takes about 456 s and makes an 848 MB receipt.

---

## For Victor: prerequisites and cost (not for the public page)

**Prerequisites, in order:**

- **P1. The named binary.** `results/zk60_token_io_r1_20261017/cli/zk60_token_io.r11.release.bin` is
  present, and its SHA-256 equals `0c9f247c0f91162177f8ed90285f8664cc4dd36ebd8934dc650804bafe5c2c6b`.
  I checked this on 2026-10-30 at ~20:40 UTC (also listed in `cli/binaries_r11.sha256`). **Still to
  check:** that it runs and proves on today's tree. Make one fresh prove and verify of the
  32 × BOS reference prompt through the resource guard before generating anything.
- **P2. The export.** The calibration `pg_rot1_b4_T32_cal128` export (profile.json `826f7641…`) and
  its verifier copy are present and match D36's pins.
- **P3. The acceptance rate.** Measure how many uniformly random secrets in the §2 layout pass the
  integer ranges, using the integer evaluator or the CLI's pre-header seal pass. No full proof is
  needed. Do this on at least 1,000 draws, and proceed only if at least 60% are accepted. If the
  true rate were below 1/2, a result that high would happen with chance about 1.4 × 10^-10. If
  fewer pass, pick a different template and measure again. **This rate is not in the files; for
  random-token prompts it is unmeasured.**
- **P4.** Publish the generation script and the template ids before generating anything.

**Cost** [from MEASURED inputs, n = 1, laptop CPU: 85.3 s to prove, 10.6 s to verify, 255,258,816 B
per receipt; measured on rung R2, so confirm on `0c9f247c…` with the first challenge receipt]:

- **Formulas:**
  - proving time ≈ M × 85 s;
  - fresh-process verification ≈ M × 11 s;
  - storage ≈ M × 255 MB.
  - Refused draws stop before the header and write nothing, so they add at most about
    (1/acceptance − 1) × M partial attempts.
- **M = 20:** about 28 min of proving, plus about 4 min of verification and 5.1 GB of receipts.
- **The §3 distinguishing game, if run:** N × the same per-receipt cost (N = 32: about 45 min and 8.2 GB; N = 100:
  about 2.4 h and 25.5 GB).
- **Run as guarded CPU jobs,** one at a time. Never chain them in one script (D46 disk rule: check
  that C: has room for M × 255 MB plus margin).

---

### Sources

- D36 scope, public facts (V = 32,000, BOS at 0, T = 32), admissibility (ids < V, BOS at 0, checked
  before the header), figures and binaries: `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_NEXT_TOKEN_TINYLLAMA_T32.md`
  (header; §1, "public facts"; §2, the sentence and "Admissible"); `docs/zkmatrix-poc/ZK60_DECISIONS.md` D36.
- D33: `ZK60_DECISIONS.md` D33; `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_TRAINED_TINYLLAMA_T32.md`.
- The binary pin: `results/zk60_token_io_r1_20261017/cli/binaries_r11.sha256`, and a `sha256sum`
  of the file on 2026-10-30.
- Classifier draft: `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_CLASSIFIER_SHIELDSTRAL_T128_DRAFT_v3.md`
  §0, §2, §4, §5 (C-7), §8.
- Assumptions and operating rules: `ZK60_DECISIONS.md` D19, D19a, D19b, D20, D21, D23, D27, D46.
- No funding, so no bounty: D47. Open release: D48.
- The challenge rulings (the reveal as a scoped exception to D21, the 4-token win, no global cap,
  the offline-only scope, M = 20, the prerequisites): `ZK60_DECISIONS.md` D52 (2026-10-30 20:46 UTC).
- Timings and sizes: `docs/zkmatrix-poc/MVP_STATUS.md` (2026-10-18 01:42 and 2026-10-30 01:54 UTC
  entries).
- Probabilities and binomial thresholds: computed 2026-10-30 (32,000^-4 with the factor of 2, the
  totals at 1,000 and 10^8 guesses, the one-sided binomial tails).
