# Rulings waiting on Victor — one page each

**Reviewed by the security owner (Claude Fable 5.1), 2026-09-19 10:55, and
sent to Victor.** Drafted by a delegated Opus agent. What I checked myself: the
power ruling in `TARGET_CONTRACT.md` (the bound is 600 W by Victor's
2026-09-04 ruling — confirmed); the D7 page, where I corrected one stale fact
(the secret scan and the constant-cycle check *have* been run for the block
program on the hardening lane; they have not for the token program); and the
D9 page, whose recommendation I agree with as the owner of the privacy
argument — the term is a privacy residual of about 2^-72 inside a bound that
already carries about 2^-62, so removing it changes nothing an adversary
could observe, and if it is ever removed the moment is after the `zk.rs`
speed lane lands, because that lane leans on the same two frozen digests. The
other four pages I read at the level of their summary rows and
recommendations, which match the two plans they cite.

Written 2026-09-19. Six things wait on one person. Each page is
self-contained: the question, why it is in front of you now, the facts that
decide it, the options with their prices, one recommendation, and the exact
words that settle it. Nothing here reopens a decided ruling (D1, D2, D3, D4,
D5, D12 all stand). Labels: **[MEASURED]** a run produced it, **[COUNTED]**
arithmetic on measured pieces, **[MODEL]** an estimate with no run behind it.

## Summary

| # | Decision | Recommendation | What it unblocks | Urgency |
|---|---|---|---|---|
| 1 | **RTX 5090 install** (an action, not a ruling; power already ruled at ≤ 600 W) | **Install now**, driver → toolkit → feature, in a quiet window | The only step that reaches 10–15 s per proof, plus a 14-check campaign already written and queued | **High** — needs a window with no lanes running |
| 2 | **D7** — the zkVM line's endpoint and model-identity profile as the P1 statement | **Accept**, with three weak spots recorded | Renames two finished receipts from "experiment" to "private block"; starts the model approval record | **High** — free, and it is the label on everything already built |
| 3 | **D13 (proposed)** — must the first MVP generate a word, or are the hidden blocks enough? | **Blocks are enough**; generation is the next milestone | The shape of task A10 and everything downstream of a word; open since 2026-09-04 | Medium — blocks design, not today's code |
| 4 | **D14 (proposed)** — commission the costed memo for lever L4 (fewer hashed bytes)? | **Yes, write the memo** (paper only; the change stays a separate ruling) | The only recorded route from 10–15 s to 5–10 s; turns "is 5 s possible" into a yes or no | Medium — best answered alongside #1 |
| 5 | **D10** — the compact commitment: 1.23 GB → 62 MB, 4.4× prover time, 95–98 bits instead of 106 | **No, keep Ligero**; build the free Merkle cap instead | The proof-size gate and a month of build work behind it | Low — pending since 2026-09-03, nothing waits |
| 6 | **D9** — the ~2^-75 reduction-bias term in the privacy argument | **Accept as stated** | The last residual term in the final privacy statement | Low to decide, **but this week if the answer is "re-freeze"** |

---

## 1. The RTX 5090 install — an action only you can take

**The question.** When do you install the RTX 5090 you already have, into
which machine, and how much memory does that machine have?

**Why now.** The speed ladder has six steps. Steps 1–4 are mechanical work
agents can do (58.40 s → about 34 s on the laptop card). **Step 5 is the card,
and it is the first step that makes a contract-shaped claim possible: 10–15 s
per proof** [MODEL, `docs/zkmatrix-poc/ZK60_FIVE_SECOND_PLAN.md` §5]. Nothing
else recorded gets there, and a 14-check qualification campaign is already
written and queued for it (`ZK60_CLAUDE_5090.md`, task CL11).

**What you need to know.**
1. **Power needs no new ruling.** Your 2026-09-04 console ruling amended the
   contract from 450 W to **≤ 600 W** instead of capping the card, so a 575 W
   part is inside it (`TARGET_CONTRACT.md` §4). [decided]
2. **The order is forced and was tested the hard way:** Windows driver ≥ 570
   **first**, then CUDA ≥ 12.8, then the `cudarc` feature. Toolkit first was
   tried on 2026-09-04 and **took the GPU away silently** — the binary fell
   back to the CPU and still printed `PASS … ACCEPT`
   (`BLACKWELL_5090_RUNBOOK.md` §3a). [MEASURED]
3. **Only the driver needs you.** The code half is done and CUDA 12.8 sits
   unused on disk; step 2 is three symlink commands. The box must be quiet
   first: `/home/victor/cuda-root` is shared by every worktree, so no lanes
   running and both agents pushed. [runbook §3]
4. **Day one buys a free ~1.9×:** the private 8B pass spills 8,585 MB onto an
   8,188 MiB card and pages; a 16 GB+ board should give ~140 s instead of
   265 s with no code change [PREDICTION, runbook §6].
5. **One thing I could not find:** no document says *which machine* takes the
   card. The same page lists a Windows-side driver install and "host RAM
   15 GB against the ≥ 64 GB the 8B arm wants" — 15 GB is the current laptop.
   A different box means standing the toolchain up there and re-running eight
   byte gates before any timing.

**The options.**
- **(Recommended) Install now**, quiet window, card-size test the same day.
  Cost: one driver install, ~1 h of agent time on the gates. Buys: the
  largest [MODEL] term becomes measured; 10–15 s becomes reachable.
- **Install after ladder steps 1–4.** Cost: 2–4 weeks before the first real
  number. Buys: nothing — the condition that said "wait" (the host wall)
  landed with lane AL.
- **Skip it, rent an H100.** Cost: money, and a claim on a machine no
  customer owns. Deferred on purpose until a 5090 number exists.

**Recommendation.** Install now. The one condition that told us to wait — do
not measure before the host wall lands — was met when lane AL cut host time
inside the prove from 49.8 s to 11.9 s. Reverse only if the card goes into a
machine with no working build of the prover; standing that box up is a week's
work and should be scheduled, not squeezed into an evening.

**Next.** On "go": we name the window, push both lanes, you do the driver, an
agent does the toolkit and runs the eight byte-identity gates (a digest that
moves on new hardware is a bug, not a hardware finding — we stop and report),
then the card-size test, then CL11. On "later": re-ask at about 34 s.

**How to answer.** `5090: go <when>, it goes in <machine>, host RAM <n> GB` —
or `5090: later`.

---

## 2. D7 — what "private" means for the zkVM line's receipts

**The question.** Do you accept the zkVM line's endpoint profile — the prompt
and the answer published only as salted SHA-256 fingerprints inside a fixed
144-byte public record, with the model identified by digests over the exact
bytes the program used — as the official statement of what its receipts claim
under P1?

**Why now.** Two Groth16 receipts exist and verify (one block; one two-block
model that emits a word). Both are labelled **"complete-block experiment", not
"private block"**, purely because this profile has not been accepted
(`docs/zkmatrix-poc/ZK60_DECISIONS.md` D7). Every status page and every future
zkVM artifact carries that qualifier until you rule. It costs no engineering;
it is the name of what we already built.

**What you need to know.**
1. **What is actually published:** 144 bytes — a profile tag, the context, the
   model digest, and two endpoints of 32 bytes. An endpoint is
   `SHA-256(tag ‖ profile ‖ role ‖ context ‖ model digest ‖ 32-byte secret
   salt ‖ count ‖ the values)`. The program commits those bytes and nothing
   else: no log, no cycle count, no activation.
   [`ZK60_ZKVM_BLOCK_SOURCE_REVIEW_FABLE.md` §1, branch `zk60-mvp-fable`]
2. **Two independent source reviews found no defect**, and both end the same
   way: a source review, not a privacy acceptance, and **no cryptography was
   assessed**. Accepting D7 accepts a *definition of the claim*, not a finding
   that it hides. [the two `…_SOURCE_REVIEW_FABLE.md` verdicts]
3. **Three honest weak spots, none a defect in the code.** (a) In the toy
   token model the hidden answer is **one of only 32 possible values**, so its
   secrecy is entirely the secrecy of the salt — whoever learns the salt gets
   the answer in 32 tries, and the code still accepts an all-zero salt (item
   H5); at a real vocabulary this stops mattering. (b) The program's identity
   ("image ID") **depends on the directory it was built in**, so any approval
   record must say "locally built, unreproduced" until a container build
   exists. (c) The two privacy checks the first review asked for **have since
   been run for the block program** on the hardening lane (branch
   `zk60-zkvm-hardening`, being integrated by Codex): a scan of every
   published file for the secrets, and a constant-cycle check on nine inputs
   (padded cycle total and segment count identical; the program's own cycle
   count varies by 0.27%) [MEASURED, `results/zk60_zkvm_hardening/cycle_gate/`].
   They have **not** been run for the two-block token program, whose host
   prints no cycle counts yet. Nine inputs are a sample, not a proof of
   constant time: **timing stays declared leakage**. [reviews §3; security
   owner's correction, 2026-09-19]
4. **The second half of D7 is an act, not a ruling:** a new approval record
   for the model digests, which cannot be credible before (b) is fixed
   (`ZK60_MVP_COMPLETION_PLAN.md` §2.5).

**The options.**
- **(Recommended) Accept the profile as the P1 statement for the zkVM line,
  with the three weak spots in the entry.** Cost: no engineering; you are on
  record accepting a statement whose hiding rests on SHA-256 with a secret
  salt. Buys: both receipts stop being "experiments", later artifacts inherit
  one named statement, the approval record can start.
- **Accept the block profile only.** Cost: the two-block demo stays unnamed.
  Buys: your name is never on the 32-value output space.
- **Decline until the image ID is reproducible and the two checks are run.**
  Cost: one to two weeks before anything on that line can be called a private
  block. Buys: an approval record a third party could reproduce.

**Recommendation.** Accept, with the three weak spots written into the entry.
This is the only endpoint statement either line has implemented and had
reviewed line by line, and accepting it renames work already done and already
verified. Reverse it if a reproducible build ever shows a different image ID
from the one we quote, because then the model half was never binding.

**Next.** On "accept": a dated entry lands the same day with the qualifiers,
the receipts lose the "experiment" wording and gain "zkVM line, accepted under
D3/D4/D5/D7", and the approval record is drafted marked "locally built,
unreproduced". On "decline": the qualifier stays and the reproducible build
plus the two checks become the next zkVM tasks.

**How to answer.** `D7: accept with the three qualifiers` — or `D7: block
only` — or `D7: not yet, fix the image ID first`.

---

## 3. D13 (proposed) — must the first MVP generate a word?

*(No decision number today; **D13** is my proposal, not an existing ruling.
Open since at least 2026-09-04 and invisible because it is not in the
register's table.)*

**The question.** For the **first** MVP, is it enough to prove the hidden
computation of the transformer blocks, or must the system actually produce a
next word — embedding lookup, final normalisation, output head, word choice?

**Why now.** Two of the project's own definitions disagree and nobody can
close the gap without you. The contract is literally about *"an 8B
feed-forward"* over 512 prompt rows (`TARGET_CONTRACT.md`), while the
ladder's task A10 says *"only this complete relation can support a
generated-token throughput claim"* (`zk60_private_block_tasks.json`). **The
speed target and the product target measure two different computations**
(`ZK60_MVP_COMPLETION_PLAN.md` §1.2). A10 is the largest unbuilt item on the
fast line and its shape cannot be specified until you answer.

**What you need to know.**
1. **The concept is already demonstrated, at toy scale, on the slow line:**
   embedding → two blocks → final norm → head → greedy next word, all hidden,
   785-byte receipt, eleven rejection controls — but a 32-word vocabulary,
   width 16, fixed 32-word context, no cache, no sampling, one word, public
   embeddings and head, and **7,488 s to prove plus 197 s to wrap**
   [MEASURED, shared box] (§2.4, gate G3).
2. **The fast line has none of it**, and no approved full model exists for it
   either. A10 is untouched: embedding gather, final norm, vocabulary
   projection, the word choice with a tie rule, the key/value cache, window
   state, causal semantics. [§2.4]
3. **A sub-question hides inside "yes":** may receipts arrive **after** a
   finished answer, or must **each word be proved before it is shown**?
   *"Delayed completed-sequence receipts and each token proved before release
   are different products"* (`ZK60_STATUS.md`, quoted in §2.4). If blocks are
   enough, this waits.
4. **A construction nobody has written.** Under P1 the answer is hidden, so a
   system that emits a word and hides it proves "I computed *some* word"; the
   value must reach you over a channel the proof binds. The zkVM host does
   this in practice, but **no such construction exists for the fast line**
   (§2.4, in the plan's "could not find").

**The options.**
- **(Recommended) Blocks are enough; generation is the named next
  milestone.** Cost: no "ask it a question, get an answer" demo on the fast
  line. Buys: the MVP stays inside the contract's own clock, and A10 with its
  two open questions leaves the critical path.
- **Generation is required.** Cost: A10 — a new relation with a dozen
  negative tests, an approved full model, plus the two questions above;
  nothing estimates it, and on the pattern of comparable items it is a
  quarter, not weeks. Buys: a demo anyone understands, and the only claim
  that can be stated in words per second.
- **Split it:** the fast line proves blocks, the zkVM line owns "here is a
  word". Cost: two artifacts to explain, and the zkVM line can never be fast
  (D2). Buys: both stories exist today — the status quo, made explicit.

**Recommendation.** Blocks are enough for the first MVP, with generation as
the named next milestone and the zkVM line keeping the "here is a word"
demonstration. The contract's clock, every measurement we have and the whole
speed plan are about blocks; adding generation makes an MVP that is already
3.9× from 15 s and 11.7× from 5 s on its best arm [MEASURED,
`ZK60_FIVE_SECOND_PLAN.md` §1.5] also depend on an unbuilt relation. Reverse
it the moment a real audience says a proof about layers is not legible to
them — then generation is not scope, it is the product.

**Next.** On "blocks are enough": a D13 entry records it, A10 becomes a
post-MVP milestone and the delayed-versus-immediate question is deferred with
it. On "generation required": A10 becomes a first-class delivery and I need
the sub-question answered in the same reply.

**How to answer.** `D13: blocks are enough` — or `D13: generation required,
delayed` — or `D13: generation required, before release`.

---

## 4. D14 (proposed) — commission the costed memo for lever L4?

*(No number today; **D14** is my proposal. The narrow thing you can rule on
now is **not** "do L4" — it is "spend a lane-week writing down what L4 would
cost".)*

**The question.** Should we commission the costed design memo for lever L4 —
halving or quartering the bytes the prover must hash, by encoding at rate 1/2
instead of 1/4 and/or moving from the 64-bit number field to a 31–32-bit one?

**Why now.** The speed plan's verdict is that after the four mechanical steps
and the 5090 we land at **10–15 s**, and **L4 is the only recorded lever large
enough to take that to 5–10 s** (`ZK60_FIVE_SECOND_PLAN.md` §5, step 6). You
have said the goal is 5 s. Today the honest answer to "is 5 s reachable at
all" is *not known*, because the only thing that could reach it has never been
costed.

**What you need to know.**
1. **Worth ×2–4 on the hashing and encoding work** — *the largest single lever
   recorded anywhere in this project* — [MODEL], never measured (§3.D;
   `U_PERF3_SIXTY_TOKENS_PLAN.md` §2). It is the design choice a competitor's
   Circle-STARK lineage already made.
2. **Your own 2026-09-04 ruling deferred it, for a reason that has changed.**
   You ruled the proof-of-concept shape to be 8B, and L4 was deferred
   *because the 8B target did not need it* — it was the lever that moved the
   30B floor (`U_PERF3_SIXTY_TOKENS_PLAN.md` §5). The target has since
   tightened towards 5 s per proof, and at 5 s the 8B target does need it.
3. **The change itself is uniquely expensive: it moves every frozen proof
   digest in the repository and re-derives the soundness accounting.**
   Byte-identity is this project's main correctness gate, so this is not a
   switch but a re-freeze of the whole evidence base plus a new security
   table. Both sources say: *no code before a costed memo*.
4. **The memo moves nothing.** Paper only: what rate 1/2 costs in soundness
   bits and bytes, which field, what breaks in arithmetic that assumes 64-bit
   words, which digests move, and what the 2–4× becomes when counted rather
   than modelled. About one lane-week [my estimate; no recorded figure].
5. **Even with L4, 5 s is marginal.** The verdict table: 5 s on a 5090, public
   inputs, feed-forward only — *"No without L4; marginal with it: 5–10 s"*
   [MODEL]; and the **private, complete-layer** product's honest band is
   **12–34 s on an H100**. The realistic product figure is the 15 s edge, and
   L4 is what would make 5 s an argument rather than a wish. [§5]

**The options.**
- **(Recommended) Commission the memo now; no code, no digest moves.** Cost:
  about a lane-week taken from the privacy lanes. Buys: a yes-or-no on
  whether 5 s exists on any machine we might own, before you spend anything
  on hardware chasing it.
- **Leave it deferred until after the 5090 number.** Cost: the 5 s question
  stays open another two to six weeks, and any later re-freeze lands on a
  larger evidence base. Buys: a memo written against a measurement.
- **Approve L4 outright.** Cost: every frozen digest moves and the soundness
  table is re-derived, on the strength of a [MODEL] number. Nobody recommends
  this; both sources say the memo comes first.

**Recommendation.** Commission the memo. It is the cheapest way to close the
largest open question about the goal you actually care about, and it commits
nothing — the change stays a separate ruling, priced by the memo itself.
Reverse it if you tell me 15 s is the product figure and 5 s was an
aspiration; then L4 returns to the 30B follow-on, and the lane-week is better
spent measuring what the repaired private construction costs at model width.

**Next.** On "yes": a lane writes the memo (paper only, forbidden to touch a
digest) and reports the counted factor, the soundness delta and the full list
of fixtures a switch would re-freeze. On "no": the deferral stands, re-dated,
and the speed plan records 10–15 s as the ceiling on recorded levers.

**How to answer.** `D14: yes, write the L4 memo` — or `D14: no, stay
deferred`.

---

## 5. D10 — the compact commitment: 1.23 GB becomes 62 MB, at a price

> **Correction after you ruled (security owner, 2026-09-19 12:10).** This page
> recommended "keep the current scheme **and build the Merkle cap**, a free
> −29% of proof bytes". The −29% is wrong for the scheme we are keeping: it
> was counted for the *compact* scheme (157 queries across about ten trees,
> `PROVING_CHANNEL_OPTIONS.md:244–248`). On the current 1.23 GB proof the
> Merkle paths are about **1%** of the bytes, so the cap is worth about 1%.
> The costed memo you commissioned under D14 caught it. **Your ruling is
> unaffected** — its reason is that the compact scheme cannot run privately —
> but there is no free lever on proof size, and the size budget stays a
> recorded, unmet gap. Every mention of the Merkle cap below should be read
> with this correction.

**The question.** Do we switch the fast line's proof-packaging scheme to the
compact (BaseFold-class) one — an 8B proof of about **62 MB instead of
1.23 GB** — at **4.4× the proving time** and **95–98 bits of security instead
of 106**?

**Why now.** Pending since 2026-09-03. It is the only recorded lever against
the contract's proof-size budget, a gate open by three orders of magnitude
(`ZK60_MVP_COMPLETION_PLAN.md` §1.4, G12), and it pulls against the seconds —
which is why the plan says to take this ruling **with the speed plan in front
of you**, hence its place next to pages 1 and 4.

**What you need to know.**
1. **The size win is real and measured on one real Mistral layer:
   38,688,700 B → 1,940,684 B, 19.94× smaller** [MEASURED, lane AF rung 4,
   `PROGRESS_UPERF3.md`]. Projected to the 32-layer 8B pass:
   **1,234,936,956 B → 62,101,888 B** [COUNTED; the measured layer matches the
   pass's per-layer average to 0.25%].
2. **The time cost is the problem: 15.497 s → 67.593 s on that layer, 4.36×
   slower** [MEASURED]. Verification gets 4× faster, which nobody asked for.
3. **It cannot run on the graphics card and it cannot hide anything.** On the
   GPU it proved the same pass in 34.96 s against the CPU's 28.76 s —
   *slower*, because the device paths decline it — and `--pcs compact --zk` is
   **refused by the driver**: there is no private version, only a written
   specification of what one would need. Under D1 the product is private, so
   **today's compact form cannot serve the product at all.** [MEASURED +
   source, lane AF rung 5]
4. **Even with a yes it does not meet the budget.** The frozen line is
   **1,114,112 B per 32-layer pass** (`TARGET_CONTRACT.md`, amendment A1), so
   62 MB is still **56× over**: D10 closes a factor of 20 out of 1,100.
   [COUNTED]
5. **The security number, plainly.** "Bits" measure the work a forger needs.
   Today's scheme is 106 bits; the compact one computes to **2^-95.1 at 8B**,
   and the shortfall comes from the field size, so more checks do not recover
   it [COUNTED, lane AF]. Separately, the Merkle cap gives **−29% of the proof
   bytes at zero soundness and zero prover cost** and needs no ruling
   [COUNTED, not implemented].

**The options.**
- **(Recommended) No — keep the current (Ligero) scheme, build the Merkle cap
  instead.** Cost: proofs stay about 1.2 GB and the size gate stays open (it
  is open either way). Buys: no 4.4× prover tax, the GPU path keeps working,
  the privacy path keeps existing.
- **Yes, switch now.** Cost: 4.4× prover time, no GPU, no privacy mode, 8–11
  bits of soundness — against a 5–15 s goal. Buys: 62 MB proofs, useful only
  if something outside the prover makes 1.2 GB impossible.
- **Yes in principle, conditional on three build items** (the four GPU
  kernels, the hiding version, the Merkle cap). Cost: not estimated, plausibly
  a month. Buys: the size win and the speed win composing instead of
  cancelling — the only version that helps the product.

**Recommendation.** No — keep the current scheme and build the Merkle cap. The
decisive fact is that the compact form **refuses to run in private mode at
all** while D1 says the product is private, so today the switch buys bytes for
a proof we are not allowed to ship. Reverse it immediately if a customer or
deployment target says a gigabyte per proof is unacceptable: size then stops
being a budget line and becomes a requirement, and 4.4× is the price of the
product existing.

**Next.** On "no": a dated "not now" with the three conditions that reopen it,
and the Merkle cap scheduled as ordinary work. On "yes": the compact path
becomes a build programme and the speed ladder is re-costed with a 4.4×
multiplier on the prover.

**How to answer.** `D10: no, keep Ligero` — or `D10: yes` — or `D10: yes once
it has a GPU and a private mode`.

---

## 6. D9 — the reduction-bias term of about 2^-75

**The question.** The fast line's random values are drawn slightly unevenly —
an imperfection of about 2^-75 in the privacy argument. Accept it as stated,
or remove it by drawing the randomness differently, which changes the bytes of
every zero-knowledge proof we have frozen?

**Why now.** Pending since 2026-09-15 and gating nothing today. But it is one
of the residual terms any final privacy statement must be stated "up to"
(`ZK60_MVP_JOINT_VIEW.md:65`), and **if the answer is "remove it", that must
happen before proof bytes are frozen as evidence, not after**
(`ZK60_MVP_COMPLETION_PLAN.md` §3.4). The private block and attention receipts
were produced this week and are about to become reference digests, so the
cheap moment is now.

**What you need to know.**
1. **What it is.** Random values are 128-bit draws reduced into the prover's
   number field; each lands within 2^-96 of perfectly even. Over a proof that
   accumulates to **2^-75.0 at the tiny shape, 2^-72.9 at 125M and 2^-71.7 at
   8B** [COUNTED, exact ledger in `ZK60_FABLE_TRANSCRIPT_REVIEW.md` §B.7].
   2^-72 is about one in 5 × 10^21.
2. **It is a privacy term, not a soundness term** — it bounds how far a real
   proof can be told apart from a simulated one; it does not make a false
   proof easier to forge. [same source]
3. **The register's wording is broader than its source.** The entry says
   "challenge draws"; the review's line H5 says the term comes from **every
   mask and pad the prover draws**, and that challenges contribute **none**,
   because the verifier reduces them identically in both worlds. Worth fixing
   either way you rule.
4. **Removing it is one line of code:** *"the prover can draw masks by
   rejection sampling (exactly uniform) and the term vanishes; this is a
   one-line change in `ZkRng::fp`"* [source, §B.7]. No algorithmic risk.
5. **The cost is the re-freeze, and it is narrower than L4's.** `ZkRng` is
   used only by the zero-knowledge paths, so what moves is the ZK fixtures —
   the two ZK byte gates and the new private block and attention receipts —
   **not** the public-input gates that carry the speed numbers. [my inference
   from the code's scope; no fixture inventory has been run, and one should
   precede any re-freeze.] And the bound carries other residual terms anyway,
   including one of about 2^-62 at the same shape, so removing this one does
   not make the statement unconditional. [COUNTED, §B.7]

**The options.**
- **(Recommended) Accept the term and record it.** Cost: the privacy statement
  reads "indistinguishable up to about 2^-72" for good, and an auditor may ask
  about it. Buys: nothing moves.
- **Remove it now, before the new receipts become references.** Cost: one line
  of code plus re-freezing the ZK fixtures and re-running their gates — about
  a day, mostly bookkeeping. Buys: one fewer caveat, at the cheapest moment it
  will ever be available.
- **Remove it later.** Cost: the same day's work against a larger set of
  frozen artifacts, and anything frozen in between must be re-taken. Buys:
  nothing — the one option I would argue against.

**Recommendation.** Accept the term as stated. It is a privacy imperfection of
about one in 5 × 10^21 inside a statement that already carries larger residual
terms, and a re-freeze spends real days of gate work for a difference no
adversary can observe. Reverse it if an auditor or a publication reviewer
requires the statement to be unconditional here — and then do it
**immediately**, because each week of new frozen receipts makes the same
one-line change more expensive.

**Next.** On "accept": a dated entry records the term, its three values and
the wording correction in item 3. On "re-freeze": a lane inventories the
affected fixtures, makes the one-line change, re-freezes them together and
re-runs the byte gates — this week, before the new private receipts are quoted
as references.

**How to answer.** `D9: accept as stated` — or `D9: re-freeze with rejection
sampling`.

---

## What I could not find

* **Which machine the RTX 5090 goes into, and its host memory.** The runbook
  speaks of "the new box" and a Windows-side driver install while listing the
  current laptop's 15 GB as the memory blocker. Page 1 asks it rather than
  assuming.
* **No costing anywhere for task A10.** Page 3's "a quarter, not weeks" is my
  inference from comparable items, not a recorded estimate — the weakest
  number on these pages.
* **No fixture inventory for a D9 re-freeze.** Page 6 item 5 names the digests
  I believe would move, from the scope of the code involved; nobody has
  enumerated them.
* **No recorded estimate for the L4 design memo.** "About one lane-week" is my
  inference from comparable memos.

*(draft complete)*
