# Independent privacy review: the Shieldstral-1.0-3B T128 classifier privacy statement, DRAFT v1

Reviewer: Claude (independent; I did not write the draft). Read-only review. Written 2026-10-29 from 23:10 UTC
(read from `date -u`).

Object: `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_CLASSIFIER_SHIELDSTRAL_T128_DRAFT.md`, sha256
`db89f427dcd1258f78c631c15a8b0f65982edf2d9620e49109795cc86eec2ee1` [MEASURED: re-hashed, equal to the brief's prefix].

Labels: [MEASURED] I ran a bounded light check (tree diff, arithmetic; under 1 GiB, seconds). [COUNTED] exact arithmetic.
[READ FROM FILE] read in a cited file and line. [MINE] my own reasoning, checked by nobody else.

Nothing was built, proved, verified or streamed. No git. No owner-private file was opened. The only scratch script is
in my session scratchpad (a tree-hash diff); the only file written in the repository is this one.

## Verdict: NOT ACCEPTABLE YET

In plain words: the arithmetic is right, the code baseline is what the draft says, and the per-commitment evidence is
strong. But two premises of the core theorem (Step 4, "the joint law is input-free") are not yet established for the
part of the run that matters most, the 26 R13 blocks. They are assumed by analogy with D36. D36 closed the same two
items by measurement before it was ruled. Gate round 22 is already working on both (its ledger, 22:51 UTC onward).

Once those two land, the draft is **acceptable with changes**: it must add a whole-post sentence (a post is 3 to 22
proofs over one hidden text), say that every accepted proof also reveals that the post passed the integer ranges,
correct the plain-words account of refusals, and state a refusal / retry / display rule that the app actually meets.
Today's demo app does not meet the display rule.

## 1. Findings

Severity: **blocking** = must be measured before the security owner can rule; **must-change** = text or operating rule
to change before the ruling, no new heavy measurement; **note** = for the record.

### P-1 (blocking). The R13 block slots have no NL-1 check at all; G-R2 rests on analogy there

Where: §3 Step 4, "G-R2, the slots" (draft lines 342–352); §10 item 3 (lines 568–569).

What is wrong:
- Step 4's theorem needs G-R2: every non-linear sumcheck slot must meet NL-1's premises, and its masked terminal
  claims must be onto with only the declared disclosure (S3–S5, the terminal surjection, control TS-1).
- For the 12 classifier slots only the S1 premise checks were run (12 / 12) [READ FROM FILE: round-20 record
  `NL1_classifier_slots`, 0.02 s].
- For the 7 R13-redefined block slots **not even the S1 premises were run**. The round-19 and round-20 records hold
  NL-1 entries only under `NL1_classifier_slots`. The block section `terminals_block_stages` has no premise,
  public-factor or degree fields [MEASURED: key search over the round-20 real record and the 14 round-19 records].
- The terminal identity (23 / 23, measured) shows the gate's public tables match the receipt. It is a consistency
  check. It is not a disclosure check.
- §10 item 3 says "today the premise checks and the terminal identity are measured". For the R13 slots that is not
  true. §3 Step 4 itself says "measured here by the terminal identity only".

Why it blocks: the R13 blocks hold almost all hidden activations (26 × 23 slots). R13 changed these slot polynomials
(gate fold with multipliers, ACT3 tuple lookups, norm shift, score precision). A monomial without a public factor, or
private factors across two rounds, would void the NL-1 lemma for that slot. D36 closed the same gap (F-T5 / PR4-7) by
measurement before its ruling.

Resolves it: NL-1 S1–S5 and the terminal surjection with TS-1 on the 7 R13-redefined block slots, plus S3–S5 and the
surjection on the 12 classifier slots. The rung captures first, then the real hate capture (light Python, as the
existing checks). Correct §10 item 3's wording. Gate round 22 item 3 is doing this (ledger 22:58 UTC; results under
`EV/round22/item3/`, not landed when I read).

### P-2 (blocking). G-R4 (the draw discipline) is not established for IN-C, OUT-C or the R13 blocks

Where: §3 Step 4 "G-R4" (lines 353–356); §4 "Not confirmed by value" (lines 462–463); §10 item 2.

What is wrong:
- The stage-47 root-rebuild replay is the only measured evidence that every blinding value is a fresh draw, used once,
  in the order the analysis assumes.
- The toy's G-R4 reading found that the other gate checks miss some draw mutations. Three Rust mutations stayed green
  under the value scan and only the strengthened root rebuild caught them [READ FROM FILE: register, commit 3aae3b8's
  message, and D22's G-R4 record].
- No replay has ever run on the R13 block commit path or on the new IN-C / OUT-C prove bodies.
- The full zero-data preimage (81.7 M entries, 0 differing) shows that *some* blinding reproduces the view under zero
  data. It does not show that the prover's actual blinding is fresh and independent. A reused mask row would still
  leave a preimage.

Why it blocks: G-R4 is a premise of Step 4, not just a source for the figure. D36 closed it (F-T6 / PR4-8) by
measurement at L = 1 and 2 before its ruling.

Resolves it: the replay at the R13 h24 rung, L = 1 and 2. It should cover stage IN-C, the R13 block and stage OUT-C.
The production verifier must accept. Every root must be rebuilt in the predicted order. The bytes consumed must equal
(counted draws − the endpoint's) × 16 + (salts − the endpoint's) × 32. The non-vacuity perturbations must fire. A
replay at the real Shieldstral shape is **not** required: D36 also replayed only L = 1 and 2 and carried the rest by
formula, and §4's K-1 controls tie the formula to the real geometry. Gate round 22 item 2 plans exactly this: a
test-only port of `gr4_token_tests.rs` to `prove_classify_run_with`, at the rung, seconds, about 1 GiB (ledger
"23:0x UTC plan"). The run should go through the guard, for example:

```
python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run --class cpu --need-gib 2 --cap-gib 3 \
  --label gate22-gr4-rung --max-secs 3600 --log <log> --done <log>.done --result-json <log>.guard.json -- \
  /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 \
  --manifest-path /home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/gr4-tree-r17/hashline/Cargo.toml \
  <the ported GR4 classifier test> -- --ignored --nocapture
```

The test name is the gate lane's to choose. A build in the same tree is `--class build` first.

### P-3 (must-change). The statement is per run; a post is 3 to 22 runs over one hidden text. Add a whole-post sentence

Where: §0 "per proof" (line 46); §2 sentence (lines 171–199); §4 note "Per run, not per post" (lines 449–450).

What is wrong:
- The app publishes every proof of a post together: 3 categories × the D41 chunks, with input roots, anchors and a
  manifest. All of them are about the same hidden text, and with D41's end-aligned overlap a chunk can share up to 54
  of its 55 tokens with its neighbour.
- §2's sentence covers one run. The only whole-post figure is a note in §4 ("about 3 × 2^-68.19 ≈ 2^-66.6 in total").
  The hybrid argument and its hypotheses are not stated.
- A lay reader of §0 ("2^-68.19 per proof") will read it as "per post".

What I checked:
- The three real runs of the 35-token post have three different input roots (`4cf9e8ae…`, `ddd23e51…`, `96ad1af1…`).
  The gate's round-19 re-prove has a fourth (`c8027b13…`) [READ FROM FILE: the three `statement.json` under
  `~/zk60-artifacts/token-io/r16-runs/`; `OWNER_RECORD.json`]. So each run seals its own endpoint.
- Each run makes exactly two OS-entropy reads (the endpoint seal and the run stream). Each read builds a new
  keyed-BLAKE3 key from 32 fresh bytes of `/dev/urandom` [READ FROM FILE: frozen-r17 `zkp-core/src/rng.rs:30–50`;
  `classify_run.rs:146`; A5 review §2].
- Arithmetic [COUNTED]: J runs give J × 2^-68.19. That is 2^-66.60 at J = 3 (a post of at most 49 tokens) and
  2^-63.73 at J = 22, the most a post can have at T128 (N ≤ 336; 337 is refused) [MEASURED: chunk-plan enumeration with
  the frozen `chunk_ranges` formula, `classify.rs:307–319`; agrees with the A5 review's plan check].

Resolves it: add to §2 a corollary in the same form as the sentence. For the J accepted runs of one post (all
categories and all chunks of its D41 plan), the joint view is within J × 2^-68.19, plus cross-run hash terms, of a
distribution computed from the public facts of all J runs (N, the plan, the 3·k verdict bits). The cross-run terms
are of the size of §4's pre-query and collision rows, with q raised by the honest runs' own oracle calls J·A. The
corollary needs these hypotheses, stated:
1. X-1 per run: two fresh, independent OS reads per run, also when runs share a process;
2. each run its own input endpoint, opened once;
3. no run's root is an input to another proof;
4. the verifier holds none of the post's openings.

In §0, say "per proof; a post of J proofs is J times this".

### P-4 (must-change). The batch command (A5, token round 18) is outside the statement; say so

Where: §1 "Binaries" (line 151); §6 "CPU only, the named binaries" (lines 483–484).

What is wrong:
- Three proofs of one post in one process is the case X-1 matters for most. `prove-batch` will be a new binary.
- The A5 review found that the two new `#[path]` files sit outside the randomness census, so a later edit could add a
  seeded generator unnoticed. Its finding 1 is that a failed batch leaves earlier receipts and `input.dec` behind that
  look finished [READ FROM FILE: `r18/A5_PATCH_REVIEW.md` findings 1, 2].
- Leftover receipts after a failure are a privacy issue, not just tidiness: if published, they would reveal which
  category failed.

Resolves it: state in §1 and §6 that `prove-batch` and any r18 binary are not covered until named. Naming needs the A5
fixes adopted, the census extended, the byte-identity check of A5 §4 passed, and the corollary of P-3 read for one
process. Until then the app runs one `prove` per (category, chunk) with `dfb8025e…`. The app does that today
[READ FROM FILE: `apps/proven-media/proven_media/shieldstral_runtime.py:16–17`].

### P-5 (must-change). Every accepted proof also reveals that the post is admissible

Where: §0 "What is public" and "What the public facts themselves reveal" (lines 49–82); §2 (lines 184–199); §8.

What is wrong:
- The draft treats admissibility as something a refusal reveals.
- But the range checks are part of the proved relation. So an accepted proof reveals the same fact the other way
  round: every activation of this post, the pad rows included, fits the R13 integer ranges under this policy.
- That is a fact about the hidden text, and it is published with every proof.
- At small n it narrows the candidate set beyond the verdict. At n = 1, three verdict bits plus admissibility pin the
  id to one cell of at most 16, and anyone can compute the cells with the public model.
- The only measured rate is high: 102 of 300 dev ids refused at one dev calibration. The draft does not say that the
  same round found none refused at Cn 4000 [READ FROM FILE: `round19/R19_SUMMARY.md:241–242`].
- The real-model rate is unmeasured.

Resolves it:
- Add a bullet to §0's "public facts reveal" list: "an accepted proof also shows that the post passed the integer
  model's ranges; whether a post passes is a property of what it says, and may correlate with the verdict itself".
- In §2, name admissibility among what the simulated distribution is conditioned on.
- Add to §8: "that an accepted proof reveals nothing about the content beyond the verdict and the length".
- Move the real-model refusal rate from "optional" to "before the app runs on non-public posts". The integer evaluator
  alone can measure it; no prover is needed (§10 "Optional").

### P-6 (must-change). The plain-words account of refusals is inaccurate in three places

Where: §0 lines 93–95 and 106–107; §2 lines 194–199 and 237–240.

1. "The one refusal that can still happen after the proof has started (a lookup denominator that happens to be zero)"
   (lines 106–107) is wrong.
   - Refusals on degenerate challenges (84/p ≈ 2^-57.6 per run [COUNTED]) also come after the header, and they are
     about 2^50 times likelier.
   - So do operational failures: guard admission, a kill, a timeout, I/O.
   - These do not depend on the content. Degenerate challenges are input-free in the random-oracle model; resource
     failures are out of scope by D20.
   - Say instead: "the only refusal after the proof has started whose chance can depend on the post".
   - Also, "for an accepted proof … a refusal … is priced" reads oddly, since an accepted proof was not refused. Say:
     "for an admissible post, whether its attempt is refused after the start depends on the post with probability at
     most 2^-108.25".
2. "Someone who sees 'could not be verified' learns that one of these ranges was left, or a control token was present"
   (lines 93–94) is too strong and does not say who.
   - The same message also follows machine failures.
   - Who sees it depends on the app (P-7). Say: "learns that the attempt failed; most such failures come from the
     content (a range left, a control token), some from the machine; the app must show this only to the author and
     never say which".
3. "That outcome is a public function of the hidden content" (line 199) reads to a lay reader as "it is made public".
   Say: "a function of the content that anyone holding the content can compute (the model is public); whether others
   learn it depends on the app's display rule (§6)".

### P-7 (must-change). State the refusal / retry / display rule precisely; the demo app does not meet it today

Where: §6 "Fail closed" (lines 485–488); §5 P-4 (line 477).

The rule the statement needs [MINE]:
- **R1 (all or nothing).** A post's proofs are published (anchored, listed in a manifest, made visible) only when every
  category and every chunk has an accepted proof. On any failure nothing about the attempt leaves the prover host:
  no partial receipts, statements, anchors or manifest entries.
- **R2 (who sees a failure).** Only the authenticated author sees that a post could not be verified. The author sees
  one bit per post, not per chunk or category. No reason, chunk index, layer, timing or attempt count is shown or
  stored where others can read it (D21).
- **R3 (no new questions).** A post refused before its header is never re-proved under any changed public parameter:
  policy wording or list, threshold, export, profile (T), chunk size or overlap. Each change would ask new yes / no
  questions about the same text. An identical retry is allowed but reveals nothing new, because the refusal is
  deterministic.
- **R4 (retries of random failures).** A failure after the header (the 2^-108.25 event, a degenerate challenge, a
  machine failure) may be retried with fresh OS randomness up to a fixed bound. Each retry adds at most 2^-108.25 of
  content dependence, and the count is not shown. The app's stricter current rule also satisfies R4: no retry once
  any prove work ran.
- Add "profile (T), chunk plan" to P-4's list of things never changed for an item (line 477).

What the app does today [READ FROM FILE]:
- **R1 is met by the code.** `jobs.py:328–331` publishes a chunk's records only when the whole post is `accepted`.
  The app's `DESIGN.md` §1 item 5 still describes distributing a failed post with "unproved" labels. That text is
  stale against D45(4); the code is not.
- **R3 and R4 are met.** `store.py:112–130` allows a retry only when the earlier attempt failed before any prove work,
  and refuses the same item under another policy or threshold.
- **R2 is not met.**
  - `GET /api/posts/{pid}` returns `status`, `status_message` and the per-chunk view to any caller
    (`app.py:151–152, 172, 374–381`). For a failed post, `status_message` is "Could not be verified. k of m chunks
    without an accepted proof (chunk i: …)" (`jobs.py:372–381`).
  - The "author" check is an unauthenticated query parameter (`app.py:378`).
  - `/api/submissions?author=` returns every submission of that author, with the text, to any caller
    (`app.py:366–370`).
  - The demo stub's code 11 message names an integer-range refusal (`provers.py:356`).

Resolves it: write R1–R4 into §6, and add a condition in the form D36 used for TR7-3: **no non-public post goes
through the app until it serves failure status only to the authenticated author**. That fix belongs to the app lane.

### P-8 (must-change). Timing and memory are not mentioned; the app publishes proving time

Where: §0, §8. D20 is cited only in the source list (line 29).

What is wrong:
- D20 puts timing, memory and power out of scope.
- The app's public item record carries `timings.work_s` (total proving work) and `proved_at` (`jobs.py:365–368`,
  served by `public_record`).
- Peak memory differs across the three categories of one post (8.08–8.27 GiB) [READ FROM FILE: register, token round
  16]. A memory kill near the cap would be a failure that depends on the input.

Resolves it:
- Add to §8: "that the time, memory or number of attempts of a proof reveal nothing; they are out of scope (D20), and
  the app's public record shows the proving time".
- Add to §6: set the guard cap with margin above the class maximum, so that no honest post is killed for its memory.
- Add to §1 "Not in scope": the app's own salted SHA-256 commitment of the text (`jobs.py:74–78`). It hides the text
  only while the 32-byte per-post salt stays secret.

### P-9 (must-change). Say which binary made each piece of evidence, and what the real-shape evidence covers

Where: §0 "What has been measured" (lines 120–132); §1 "Binaries" and "Lengths in evidence" (lines 151, 154).

What is wrong:
- The no-limit PASS of gate round 20 is on a receipt made by `e94cecf9…`. That binary is frozen-r16 plus one changed
  comment [READ FROM FILE: `cli/zk60_classify.r16.BUILD.txt`], and it is not named in the sentence.
- The named r16b binary's own real receipt (round 19) passed with declared limits.
- The r17 binary has never proved a gated receipt; it only re-verified.
- The carry to the named binaries is by source reading. I confirm that reading in §2 item 7 below.
- At the real shape, only not-flagged items with n = 35 were gated, and only under the hate and sexual policies. The
  violence policy, flagged verdicts, short items and two-chunk items rest on the rung and on the code.
- §1 says this, but §0 does not.

Resolves it: two sentences in §0. Also make one real-shape capture of the app's 17-id post under all three policies
when it runs (it is already owed for the owner check). A real flagged item would be welcome. Neither is blocking: the
rung measured equal randomness-free figures across verdict 0 / 1 / tie and n.

### P-10 (note). D41's end-aligned last chunk can overlap its neighbour by up to 54 of 55 tokens

- The last chunk is `[N − c, N)` [READ FROM FILE: `classify.rs:317–319`].
- At c = 55, a post of N = 56 gets windows [0, 55) and [1, 56): two bits on windows that differ by one token at each
  end.
- For 168 of the 281 multi-chunk lengths at c = 55, and 175 of 287 at c = 49, the last overlap is at least half a
  chunk [MEASURED: enumeration over N ≤ 336].
- Chunk count and ranges reveal nothing beyond N, but the bits on near-identical windows can localise a decisive
  token.
- This is public by D41. §0's "public facts reveal" list should say it, next to "which part of the post triggered it".

### P-11 (note). n = 1: 130,072 is an upper bound on the candidate set

- The CLI admits any id below V that is not a control id. A real one-token post is the tekken encoding of ' ' + text
  (B-1), so far fewer ids occur in practice, and the verdict narrows more.
- Add "at most" to line 79.

### P-12 (note). The refusal term is derived correctly and is conservative; C-5 can be a reading condition

- 2·(26·(256 + 256 + 4,096·4) + 128 + 256) = 879,360. Over p² that is 2^-108.254 [COUNTED].
- The formula is D34's: two worlds; denominators in F_p², so 1/p² per value; counted over table rows.
- [READ FROM FILE] IN-C inverts the query of every position, and on the table side only the rows in use
  (`stage_in_c.rs:328–344`). So at most T values depend on the content.
- OUT-C uses one 256-row byte table (`stage_out_c.rs`, `logup_size` returns `U8_LEN`).
- The block code also inverts every row of its three tables on every attempt (`protocol.rs`, S28-F1 comment near
  line 740). So the block part may in fact depend only on the challenges, and counting it is conservative.
- No plausible recount moves the total. Even 2^30 distinct content-dependent values give 2^-97.
- C-5 (D34's premises at R13's TAB slot) can be confirmed by the security owner's reading. It is not blocking.

### P-13 (note). §10 item 4 and §4's A bound have been overtaken by gate round 22

- The gate ledger (23:00–23:03 UTC) and `EV/round22/census/CENSUS_REAL_HATE.json` record [READ FROM FILE]:
  - C-R2 holds: the constructor input is 12 + 73 = 85 B, not 47;
  - W-2 holds: no absorb of 84–86 B among 36 lengths;
  - every F_T call is keyed;
  - C-R1 holds by reading over 13 unkeyed sites (`C_R1_READ.json`);
  - **A is measured at 287,237.** §4's bound of 2^20 can be replaced, and the pre-query term becomes 2^-109.87.
- My own partial reading agrees. The profile string is 73 B [COUNTED]. The calibration digest's unkeyed input is
  32 + 32 + 32 = 96 B, the shortest I found (`classify.rs:1110–1116`). No unkeyed input I read is 40 B or depends on
  hidden data.
- Draft v2 should cite round 22 for item 4 and use the measured A. The total stays 2^-68.19.

### P-14 (note). D23 is amended, not met; cite the reading

- D23's own text names "records it in a registry" as the act that brings the D8/D11 question back.
- D45(3) amends D23 for classifier runs. The technical reading that re-publishing the same root adds nothing (D19b's
  hiding rests on fresh per-column salts), provided no later proof claims or opens it, is in
  `classifier/check/CHECK.md:258–263` and `DESIGN_CLASSIFIER.md` §6.1.
- §6 should cite that reading next to "D23 as amended" (line 496). The toy's O-2 is carried only in this amended form.

### P-15 (note). The production list still includes the dev rung policy

- `registered_policies()` in r16b is `[policy_rung_dev(), the three category policies]` [READ FROM FILE: frozen-r16b
  `classify.rs`].
- "Exactly three admitted at this profile" therefore rests on the profile refusing the dev policy's V = 300 and margin
  parameters, which r16b's test pins.
- Say that in C-2 (line 472).

## 2. The eight attack points, answered

**1. The [MINE] extensions in Step 4.** Each premise, at IN-C / OUT-C / the R13 blocks:
- G-R1 (per-commitment disclosure) is **measured** on all 84 commitments and the 28 masking commitments. Established.
- Step 3 (zero-data preimage, public tables) is **measured**; all 442 block arrays were derived again. Established.
- G-R2 is **partly measured** for the classifier slots (S1 premises only). For the R13 slots it is **assumed by
  analogy** (P-1).
- G-R4 is **assumed**: counted and read, never replayed (P-2).
- G-R5 rests on the argument plus the replay's re-hashing. The census is now reported done (P-13).
- The "new channels" (verdict, n, pad rows, tables) are measured at the rung and on the real n = 35 capture.

So the extension is established for the linear view and the public tables. It is not yet established for the blocks'
non-linear slots or the draw discipline.

**2. The refusal channel.**
- The 2^-108.25 term is derived correctly and is conservative (P-12).
- The plain words are inaccurate on what happens after the header, on who sees a failure, and on "public function"
  (P-6).
- They also miss the other direction: every accepted proof reveals admissibility (P-5).
- What a refusal reveals:
  - The author knows the text anyway.
  - The app operator runs the prover and holds the text and the opening.
  - The public learns nothing unless the app shows it, and today's demo app does show it (P-7).
- Retries:
  - Retrying a refusal before the header with identical parameters reveals nothing more (it is deterministic).
  - Retrying under a changed public parameter (wording, threshold, export, T, chunk plan) asks new questions and leaks
    more. It must be forbidden.
  - Retrying a failure after the header with fresh randomness adds at most 2^-108.25 per attempt.
- Needed rule: R1–R4 in P-7. The app's current retry rule already meets R3 and R4; its display does not meet R2.

**3. The public facts.** The draft does not claim more than P1 gives, with two omissions:
- admissibility (P-5);
- near-duplicate chunk windows (P-10).

What I checked:
- The published `/3` statements carry: verdict, policy and template ids, n, the chunk index / count / range / total /
  size / overlap, item length, pad id 11, pad positions, verdict row, model and table digests, the context, the input
  root, the floor and the parameter line [READ FROM FILE: the three `statement.json`].
- Nothing hidden is in them, and no timing or memory.
- Pad positions and the verdict row are functions of n.
- The table values are functions of the export and the challenges (round 21).
- The chunk count and ranges are a function of N and the policy's chunk size only. `label --expect-total N` refuses
  any other split [READ FROM FILE: `classify.rs:307–319`; register token round 15].
- So beyond N they reveal only the per-chunk bits, which are public by D41.
- Outside the statement but public in the app: the proving time and the app's own salted commitment (P-8).

**4. The distance figure.**
- 235,660,902 draws [COUNTED, every row of §4 recomputed]. × 2^-96 gives 2^-68.188.
- The per-draw bias is exactly 2^-96, because 2^128 mod p = p − 2^32 [COUNTED].
- Every other row of §4 recomputes, including the totals for 10^6 and 10^9 runs and the 99.9999999993 % share.
- Every draw class is counted in kind: A, H with its zero-sum pair, M, 27 boundaries, one endpoint. Salts are bytes
  and carry no bias.
- The draw loops I read in IN-C match the formula (`stage_in_c.rs:309–358`).
- Only a replay shows that no other draw site exists and that the draws are fresh. For the number alone a replay could
  follow, since an undercount by 2 costs 1 bit. For G-R4 as a premise it is **required before acceptance**, at the
  rung (P-2).

**5. Cross-proof independence (X-1).**
- The draft is **per receipt**. It does not cover the joint view of a post's 3 to 22 receipts, except in a §4 note.
- Each run has its own input endpoint and its own root. I confirmed three distinct roots for the real post. Each run
  has its own two fresh OS reads, so no input commitment is opened twice.
- What must be added for a whole post is P-3's corollary with its four hypotheses, and P-4's exclusion of the batch
  binary until it is named and checked.
- A5 itself is consistent with X-1 by reading. Each proof still makes its own two `from_os` reads, and nothing
  mutable is shared [READ FROM FILE: A5 review §2]. But its census and cleanup fixes are required first.

**6. The owed list, items 2–4.**
- Item 2 (stage-47 replay): **required before acceptance**, at the rung (P-2).
- Item 3 (NL-1 S3–S5 and the surjection): **required before acceptance**, including the S1 premises on the R13 slots,
  which were never run (P-1).
- Item 4 (C-R1 / C-R2 census): **required, but reported closed** by gate round 22. Cite it (P-13).
- Item 5 (owner check at n ≠ 35) is about the post link and completeness, not the verifier's view. It **can follow**
  as a condition before the app goes live.
- Item 7: see point 7 below.

**7. The code baseline.** [MEASURED: SHA-256 of every file, `target/` excluded]
- **frozen-r16 → frozen-r16b** (300 → 301 files): `classify.rs` changed, two test files changed, one test file
  added (`classify_r16b_tests.rs`, registered by `#[path]` inside the `#[cfg(test)]` module `classify_r16_tests`).
  - `classify.rs` changes only `policy_shieldstral_card` (now `#[cfg(test)]`), `registered_policies()` (the card
    policy removed from the production list) and comments.
  - The change is privacy-relevant only in that the item can be asked fewer questions. It narrows D45(2) to the three
    category policies.
  - It touches no randomness, blinding, transcript, receipt or statement code.
- **frozen-r16b → frozen-r17** (301 → 303 files): four files changed and two added, all test-only.
  - `run_capture.rs` and `plane_index.rs` are `#[cfg(test)] mod` declarations (`private_block.rs:258–268`).
  - `s25_tests.rs` is `#[cfg(test)]` (`:308–309`); `classify_capture_tests.rs` is `#[cfg(test)]`
    (`token_io.rs:85–86`).
  - `gate19_capture_tests.rs` and `classify_r17_tests.rs` are reached only by `#[path]` from inside those test modules.
- No production byte moves. The register's account (16b fixes coordinator-checked; 17 test-only) is confirmed
  independently.
- The two binaries differ in bytes. The freeze record attributes this to the tree path baked into the build
  [READ FROM FILE]; I did not check binary bytes.
- The round-20 receipt's binary `e94cecf9…` is frozen-r16 plus one changed comment [READ FROM FILE]. So its prover
  code equals r16b's apart from the policy list.

**8. Wording.**
- §0 says "per proof" (P-3), omits admissibility (P-5), and gets the refusal details wrong (P-6).
- §0 should also say plainly that the app running the prover sees the post: the proof hides the post from everyone
  else who sees the proof.
- "Within 2^-68.19 … of something that could be produced without the post at all" should add "for a post that passes
  the ranges".
- §8 is missing:
  - "that a whole post is covered by the per-proof figure";
  - "that admissibility is hidden";
  - "that time, memory or attempt count are hidden";
  - "that prove-batch or any r18 binary is covered";
  - "that the real model was gated at more than one length and verdict";
  - "that the rate of 'could not be verified' is known".

## 3. What I did not check

- I ran no gate tool, replay, NL-1 or surjection check. I did not re-derive Theorem B, the rank lemma or the hash-layer
  lemma.
- I did not read the native R13 `prove_core` draw path or the full OUT-C prove body. I read IN-C's draw loops, both
  stages' lookup tables and the block's inversion helpers only.
- I did not verify binary bytes or rebuild anything. I did not compare the 72 v23 pins with the trees.
- I read only the round-22 census records and ledger lines that exist so far. Items 2 and 3 of that round had not
  landed when I read (23:05 UTC).
- I did not audit the app beyond the lines cited, did not run it, and did not check its manifest endpoint or its
  on-chain path.
- I did not check REVIEW_R16 beyond its §10, the GPU path, the T256 profile or images.
- I did not measure any refusal rate.
