# Rulings open for Victor, 2026-10-17 (one page)

**ANSWERED 2026-10-17 19:28 UTC: "all recommendations yes" (Claude console;
also by Telegram at 19:24).** Recorded in `ZK60_DECISIONS.md` as D19b and D23
accepted, and new D25 (T1–T8).

Written 19:00 UTC by the coordinating Claude session; T2 amended 19:22 after
the adversarial check of the token design (`results/zk60_token_io_design_20261017/check/CHECK.md`:
core sound, three binding changes being folded in). Each item is
one plain question with a recommendation. A one-line answer is enough, e.g.
"all recommendations yes", or "D23 yes, T3 no: ...".

## Already pending (carried from September)

**D23 — never refer to an accepted receipt's endpoint fingerprints later.**
A private receipt ends with two public fingerprints of its hidden input and
output. The privacy argument holds only while no later artifact registers,
republishes or chains those two fingerprints; once something does, a harder
open question applies (D8/D11). It limits how receipts are used, not how they
are built. Nothing today does this. **Recommend: yes.** It is also a condition
for any privacy acceptance of the trained stacks and for the token hand-off
(T5 below). One-pager: `ZK60_RULINGS_FOR_VICTOR_PRIVACY.md`.

**D19b — the model behind the hash keys.** The keyed BLAKE3 separation (D19a)
rests on a slightly stronger assumption than the one you accepted in D19 (the
compression function is ideal even when the attacker picks its starting
value). Nothing measurable changes. Alternative: one prefix byte per domain
instead of keys (about 0.5% more hashing and a re-freeze). **Recommend: yes,
keep the keys.**

## New: proving the next token (D13's next milestone)

Design: `results/zk60_token_io_design_20261017/DESIGN.md`. It adds an
embedding stage before block 0 and a final-norm + head + greedy-choice stage
after the last block, inside the same private run. Cost at Llama-3-8B, T32:
about +3% proving time, +4.4 MB receipt [MODEL/COUNTED]; negligible at T512.

- **T1 Output.** First prove ONE hidden next token per run (mode i); prove a
  whole greedy continuation in one pass (mode ii) later. **Recommend: yes.**
- **T2 Prompt length.** Keep the prompt length hidden in mode (i). The
  adversarial check (19:20 UTC) found that hiding it safely means sealing the
  length inside the input's fingerprint, so the owner can check the prover
  answered the right prompt; otherwise a cheating prover could answer a
  shorter prefix. That costs a small endpoint geometry change (a security-owner
  ruling, R9), not proof time. Mode (ii) would start with public lengths.
  **Recommend: yes, hidden and sealed.**
- **T3 Ties.** When two tokens have the same top score, the lower token id
  wins (numpy's rule). **Recommend: yes.**
- **T4 Integer head.** The proof computes the head in integers. Accept it if
  it picks the same token as the float head on at least 99% of held-out
  positions; otherwise use one scale per vocabulary row. **Recommend: yes, at
  99%.** (Fidelity measurement running.)
- **T5 Owner hand-off.** The verifier never sees the token; the prover hands
  the owner the token plus the opening of its fingerprint over a private
  channel, and the owner checks it against the receipt. Needs D23.
  **Recommend: yes.**
- **T6 Several tokens.** Repeated one-token runs are not a proved token
  stream, and every claim must say so. **Recommend: yes.**
- **T7 Model identity.** The receipt names the embedding and head by the
  export's digest (as already accepted for the blocks); it does not prove the
  export came from the named checkpoint. **Recommend: yes.**
- **T8 First token.** The proof forces the beginning-of-sequence token at
  position 0. **Recommend: yes.**

## Added 20:10 UTC — G.0-2, the soundness target (open)

**What it is.** Today's recount (register D15, two dated notes) puts the
private trained stacks at about 97.4–98.2 bits whole-run (the chance a forger
gets one false proof accepted, summed over every check in the run), and an
8B run at the 512-token workload at about 94.7 bits; read as a forger's work
per attempt it is about 99.7. Above about 95 bits the limit is the lookup
checks, and every way to raise them in today's design adds a second set of
committed lookup helpers, costing about 30% of the GPU throughput the 50
positions/s goal needs (memo: `results/zk60_soundness_recount_20261017/MEMO_G02.md`).

**Proposed ruling.** State the target per run at a named workload (today
Llama-3-8B, T = 512) as a whole-run figure with the work-factor reading beside
it. **MVP: about 95 bits whole-run accepted as a recorded deviation**, next to
the zkVM line's 97 conjectured (D3); **next milestone 100 bits**, preferably
through LogUp-GKR with a 256-bit lookup challenge (no throughput cost if its
privacy design works out; otherwise about −33%); **product 128**.
**Recommend: yes.** If you want parity with 97 now, it costs about 31% of the
throughput (57 → 40 positions/s on the 5090 roofline at 40% bandwidth).

**ANSWERED 2026-10-17 20:21 UTC (Claude console): "Go for (b), as well as
G.0-2 yes."** Recorded as D27 (soundness target: about 95 bits whole-run for
the MVP at the named 8B T512 workload, 100 next, 128 product) and as an
amendment to D25 T4 (per-row integer head with 12-bit multipliers, accepted
when it matches the float head wherever the float top-2 margin is at least
0.3 logits; the 99%-overall threshold is withdrawn). Victor: "100%
reliability always is probably not necessary for most of the applications of
this technology."

## Information for Victor, 2026-10-19 09:31 UTC (no ruling needed) — the blinding-sampler bias at trained size

D9 (accepted in September) allows a tiny bias in how the prover draws its
masking randomness: it nudges the published view away from a perfectly
data-independent one by at most the following [COUNTED, from the trained
TinyLlama privacy draft's §4; the review recomputed them exactly]:

| | statistical distance |
|---|---|
| one 22-block run | 2^-70.4 ≈ 6.6 × 10^-22 |
| a thousand runs | 2^-60.4 ≈ 6.6 × 10^-19 |
| a million runs | 2^-50.4 ≈ 6.6 × 10^-16 |
| a billion runs | 2^-40.5 ≈ 6.6 × 10^-13 |

In plain words: an observer comparing a billion published proofs gains at
most about one part in a trillion of an edge in telling any hidden input from
another. This is a privacy figure (what leaks), not the soundness figure of
D27 (what can be forged).

**Answered 2026-10-19 16:56 UTC (console):** "accept thrTinyLlama privacy
statement" — the trained TinyLlama T32 privacy statement with these D9
figures is accepted, recorded as **D33** (in force for native R7 and its CPU
binary; R8 needs a gate re-pin first).

**Answered 2026-10-19 ~17:00 UTC (console):** "fidelity target: ppl <=
1.01, LAMBADA >= 99%, no refusals" — recorded under D32: perplexity <= 1.01x
float (FineWeb and WikiText held-out), LAMBADA >= 99% of float, zero refusals;
on point estimates, with confidence intervals reported.

## Open 2026-10-20 00:20 UTC — extend D33 to the code the demo runs

D33 (the accepted TinyLlama privacy statement) is in force for native R7
only; R8 changed five pinned files. The gate re-pinned it onto the token
lane's frozen round-7 tree (= R8 + the next-token code): 10 of 10 records
pass, every figure that does not depend on randomness equals R7's, and the
command-line binary built from that tree publishes a statement equal to R7's
(except the fresh endpoint roots). The independent privacy reviewer says YES
(`results/zk60_privacy_review_trained_t32_20261017/REVIEW4.md`, part A).

**Question:** lift D33's suspension for that tree? If yes it names: the
tree's 52 pins (keeping R7's 46), the CPU binary `dac7fc73…`, and the two
items carried by reading (the 22-block full-preimage pass and the
command-line capture), per review item PR4-1. Same calibration, same 32
tokens, same limits — no new claim beyond "the same statement holds on the
newer code".

**Superseding update 2026-10-20 05:35 UTC:** the D33 extension question now
targets the newest frozen tree, **frozen-r9** (the code the demo and the
named next-token binary run), and folds in frozen-r7. Independent privacy
review round 5 says YES (`results/zk60_privacy_review_trained_t32_20261017/REVIEW5.md`
part A): only `run.rs` moved on the block path, by additions D33's profile
can never select; 10/10 re-pin records pass and equal the earlier ones on
every non-random figure. If yes it names: frozen-r9's 52 pins (keeping R7's
and tk7's readings), the trained-block CPU binary `911e82f0…`, and the two
items carried by reading (P-18 capture-and-gate, 22-block pass F).
**To answer in the console: "extend D33 to frozen-r9".**

**Coming next (not yet asked):** acceptance of the next-token privacy
statement (TinyLlama T32, calibration b4, public-row variant, CPU binary
`b56f1b71…`): review round 5 says the draft is ready; a final wording pass
(v3) is being made, then the statement comes to you.

## Open 2026-10-20 05:45 UTC — accept the next-token privacy statement?

**What it says, in plain words:** someone checking a proof of TinyLlama's
next word (prompt lookup → all 22 trained layers → final norm → head →
the chosen word, one proof) is never given the prompt (positions 1–31), the
activations, the logits or the next word itself, and what they do see is
within about 2^-70 per run of something that does not depend on them (about
1 in 2^40 over a billion runs) — the same strength as D33. Public: the
prompt length (32), the start token, the vocabulary size, the model files,
the run length.

**Scope (narrow on purpose):** TinyLlama-1.1B, 32 tokens, calibration b4
(`pg_rot1_b4_T32_cal128`), public-length variant, CPU path, the round-9
next-token code (`frozen-r9`, 52 pins) and its named binary `b56f1b71…`;
carries D34 (the ~2^-117 refusal term) and D35 (which block checks carry to
b4); refusals now happen before anything is written (by code, at both
entry points). NOT covered: Llama-3-8B, other calibrations, the
hidden-length variant, the GPU path, what an output owner who is not the
input owner learns, delivery of the owners' files to separate machines.

**Evidence:** gate on 10 captures + the command-line capture (all pass,
36–38 tamper controls fire), independent privacy review rounds 4 and 5
(round 5: "ready, no blocking items"), token code reviews 5 and 6
(demo-fit, nothing affecting soundness). Text: frozen draft v3,
`results/zk60_gate_tinyllama_20261017/round11/PRIVACY_STATEMENT_NEXT_TOKEN_T32_DRAFT_v3.md`,
sha256 `97853f25…`. One confirmatory re-capture on the round-9 code is still
running; if any non-random figure disagreed, the acceptance would lapse.

**To answer in the console: "accept the next-token privacy statement"**
(recorded as D36, in force for exactly that scope).

**Update 2026-10-21 00:15 UTC:** the confirmatory re-capture for the
next-token statement is done — on all ten re-captures on the round-9 code,
every figure that does not depend on randomness equals the earlier
captures', so the carry the statement relies on holds (gate round 12
addendum `results/zk60_gate_tinyllama_20261017/round12/PRIVACY_STATEMENT_NEXT_TOKEN_T32.ADDENDUM-R12-20261021.md`,
sha256 `44956506…`). Both questions above remain open for Victor's word.

**Answered 2026-10-21 ~00:17 UTC (console):** "I say yes to both extending
D33 to frozen-r9 as well as the next-token privacy statement" — recorded as
the D33 extension (in force for frozen-r9 and R7) and **D36** (the next-token
privacy statement, in force for frozen-r9 and binary `b56f1b71…`). Next: a
short re-pin reading of token round 11 (the demo's current binary
`0c9f247c…`) so both statements can name it.

## Open 2026-10-21 02:30 UTC — extend D33 and D36 to the demo's current binary (frozen-r11)

Both accepted statements are pinned to round 9; the demo now runs token
round 11 (binary `0c9f247c…`). Round 11 changed only two next-token files
(one test-only line; the command-line safety fixes TR7-5/6/7) — no block,
run, prover, verifier or token-stage file. The gate re-checked it (round-15
note `results/zk60_gate_tinyllama_20261017/round15/ZK60_PRIVACY_STATEMENT_REPIN_R11_20261021.md`,
sha256 `a0c28c57…`): the capture made with the demo's own binary has the same
identity and the same figures as round 9. Independent privacy review round 6:
**YES for both** (`results/zk60_privacy_review_trained_t32_20261017/REVIEW6.md`).
If yes it names: frozen-r11's 52 pins; for D36 the token binary `0c9f247c…`;
for D33 the trained-block binary `631e2a15…`. Same claims, same limits.
**To answer in the console: "extend D33 and D36 to frozen-r11".**

**Also still open (2026-10-21 ~01:00 UTC):** the three classifier decisions —
(1) Shieldstral-1.0-3B text-only as the MVP model, (2) the proof states "the
yes-score beats the no-score by more than a public threshold" (Mistral's own
decision rule) instead of "greedy next word", (3) only the verdict plus model
and policy become public. Suggested answer: "yes to all three".

**Answered 2026-10-21 02:27 UTC (Telegram, 2026-10-20 19:27 PDT):** "For the
classifier rulings go ahead with yes to all three a) b) and c), also for
'extend D33 and D36 to frozen-r11' yes for that as well" — recorded as **D38**
(Shieldstral-1.0-3B text-only; the margin-over-threshold statement; only the
verdict, model and policy public) and as the frozen-r11 extensions of D33 and
D36. Console confirmation requested for the record (Telegram lines have been
treated as needing it).

## Open 2026-10-21 03:00 UTC — four rulings for the classifier proof (from its adversarial check)

The classifier proof design passed its adversarial check "buildable with
fixes" (`results/zk60_token_io_r1_20261017/classifier/check/CHECK.md`): the
verdict cannot be forged or flipped; two real holes (template/tokenizer
boundary, control-token injection) have binding fixes. Four product rulings:

1. **Content length is public.** In the buildable variant a proof reveals the
   post's length in tokens (e.g. "57 tokens"), besides the verdict, model and
   policy. Hiding the length is a later, costlier variant. Recommend: accept
   length public for the MVP.
2. **One fixed policy list, one threshold each; never re-prove an item under a
   different policy or threshold.** Each extra policy is a yes/no question
   about the hidden content, so free-form or repeated policies would leak it.
   Recommend: yes.
3. **Linking the proof to the post (amends D23).** The proof's sealed input
   fingerprint is stored with the post and anchored on-chain (D39); the app
   keeps the opening so anyone given the post's text can check the link.
   Consequence to accept: whoever holds an opening can prove which content
   was posted (it is a transferable proof of authorship-of-content).
   Recommend: yes.
4. **Fail closed.** A post without an accepted proof is not published and is
   shown as "could not be verified", never as safe (otherwise an attacker
   could try to trigger refusals to slip content past). Recommend: yes.

**Suggested answer (console): "yes to the four classifier rulings".**

## Open 2026-10-21 03:15 UTC — two rulings for publishing proofs (D39 feasibility)

Feasibility report: `results/zk60_chain_publication_20261021/REPORT.md`. The
proof (0.3–1 GB) can't go on-chain; the fingerprint, verdict, model, policy and
a salted content commitment go on-chain, the proof goes to a storage network.
Anyone can fetch the proof and re-verify it with the public model files.

1. **How long full proofs are kept.** (a) Renewable, deletable storage
   (Filecoin + Cloudflare R2 mirror): about **$0.12 per text post per year**
   (~$1,200/yr per 10k posts); deletable, which keeps a way out if a flaw is
   ever found and answers GDPR erasure. (b) Permanent (Arweave, pay once):
   about **$26 per text post** (~$257k per 10k), can never be withdrawn.
   Recommend (a) for the MVP; small records and model files can still go
   permanent (~$0).
2. **Anchor chain: Base** (Ethereum L2, under $0.001 per batch of up to 1,000
   posts, optional daily Ethereum checkpoint, standard tooling; the RISC Zero
   verifier is already deployed there for a later on-chain-verification phase).
   Alternative: Solana (same design, ~$0.04 per batch). Recommend Base. Work
   starts on the Base test network; any real key or spending comes back to you.

On-chain verification of the proof itself is possible only through a zkVM
wrapper (today ~$2–18 per post, 6–18 GPU-hours) — a later phase, not the MVP.

**Suggested answer: "renewable storage and Base".**

## Open 2026-10-21 03:25 UTC — three product choices for images and video (multimodal design)

Design: `results/zk60_multimodal_design_20261021/DESIGN.md`. Images go through
Shieldstral's own vision encoder; the new prover pieces are modest (no new
committed planes for the mask, 2D rotary, GELU and merge; two small new stages).
Estimated cost [MODEL]: text post ~7 min on the laptop / ~17 s on a 5090 after
the GPU port; an image at 224 px ~10 min laptop / ~28 s ported 5090; 448 px
needs the 5090 box (33 GiB); a 30 s video at one frame per 5 s ~53 min laptop /
~3 min ported 5090, ~9 GB of proofs.

1. **Image size: 224 px for the POC** (fits the laptop), 448 px as the 5090
   target once accuracy is measured. Recommend yes.
2. **Video: one frame every 5 seconds plus scene cuts, capped (e.g. 12
   frames), any unsafe frame = unsafe.** Frames between samples are not
   checked; the post says so. Recommend yes.
3. **Audio: not proved in the POC.** Captions/subtitles are proved as text;
   video posts carry the label "visual frames + captions checked; audio not
   assessed". (A proved speech model is a large separate build.) Recommend yes.

**Suggested answer: "yes to the three media choices".** Also useful to know:
the status of the RTX 5090 desktop (448 px images and fast proofs need it).

**Answered 2026-10-21 03:17 UTC (Telegram):** "Let's just do image and text
for now" — the POC is text + image; video and audio deferred (D39 narrowed).
Media choices 2 (video sampling) and 3 (audio label) are therefore moot; choice
1 (224 px images for the POC) is still open.

## Open 2026-10-21 06:20 UTC — swap in the resource-guard fix? (operations)

The shared resource guard has a known flaw that cost hours today: a heavy job
grabs the shared lock before memory is free and then blocks everyone while it
waits. A fix is written and tested in a copy
(`results/zk60_guard_fix_20261021/`), and an independent review says "apply
with fixes" (procedural only; the code is safe). Meanwhile every lane now
checks for memory before launching, which avoids most of the problem.

The catch: three scripts owned by the Codex lanes pin the guard's exact
fingerprint and will refuse to run after the swap until their owners update
the pin — including the tech-week demo harness
(`scripts/zk60_techweek_demo.py`), `scripts/zk60_guarded_command.py` and
`scripts/zk60_private_stack_benchmark.py`.

**Question:** swap now (and the Codex lanes update their pins when next
active), or wait until a Codex session can review and update pins together?
Recommend: wait for a Codex session if one is due soon; otherwise swap at a
quiet moment and leave a note in `ops/zkp-mvp/RECOVERY_COORDINATION.md`.

**Answered 2026-10-26 18:22 UTC (console): "swap yes"** — recorded as D42.
The swap runs today in a planned window with Sol (Codex) updating both
static pins; see `docs/zkmatrix-poc/ZK60_SOL_ASTRA_TODOS_20261026.md`.

## Action for Victor, 2026-10-26 18:38 UTC — free testnet ETH for the publisher (not a ruling)

Astra's Base Sepolia publisher (A3, testnet only) needs free test ETH. Sign in
at https://portal.cdp.coinbase.com/products/faucet (Coinbase Developer
Platform), pick Base Sepolia, and send to the throwaway testnet address
`0x775E8A2D741446d74E3f5a02244D1241eceB187d`. No real money; never share keys
or logins with a lane. Alternatives checked by Astra: Alchemy's faucet needs
mainnet history and 0.001 real ETH (unsuitable); thirdweb needs a wallet
connection (not used).
