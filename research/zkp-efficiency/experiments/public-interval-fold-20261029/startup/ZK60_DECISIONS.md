# ZK60 decisions register — the rulings that govern the proof project

**Read this before claiming any security or privacy property, and record every
new ruling here the day it is made.** One entry per decision: what was
decided, by whom, why, what it means day to day, and what would reopen it.
Entries are never deleted; a reversed decision gets a new entry that points
back. Keep this file short enough to read in five minutes.

## At a glance

**2026-09-26 performance direction, clarified by Victor in this session:**
continue the PoC and background researcher toward an **8B-parameter
forward-pass proof at >=50 proved tokens/s on an RTX 5090 or another high-end
GPU**. More tokens are explicitly acceptable to amortize initialization and
initial prefill. The earlier same-day 512-token / <=10.24-second interpretation
is a reference fixture, not an acceptance restriction. Sustained throughput
takes priority over the former five-second latency objective. Report startup,
workload shape, warm and total-workload rates, proof latency and verification;
count only positions covered by verified complete-stack proofs.
[Current workload and clock rules](ZK60_THROUGHPUT_TARGET.md). D1's privacy
scope and D13's block-only MVP boundary stand; no pending security/privacy
proposal is accepted by this performance direction. No speed result is claimed.

| ID | Decision | Status | Date | Decided by |
|---|---|---|---|---|
| D1 | Privacy scope: P1 hides inputs, outputs, activations (weights may be public); P3 also hides weights | **standing** | 2026-09-09 | Victor |
| D2 | Two lines: a zkVM intermediate delivers the first complete private tiny block; the custom-PCS line remains the route to the throughput target | **standing** | 2026-09-17 | Victor |
| D3 | Security level for the zkVM intermediate: about 97 bits conjectured soundness accepted, as a recorded deviation from the 128-bit target | **accepted** | 2026-09-18 | Victor |
| D4 | Groth16 trusted setup accepted for soundness of the zkVM intermediate's public artifact | **accepted** | 2026-09-18 | Victor |
| D5 | Public receipt kind: Groth16 only; composite never public; succinct is experimental evidence only | **decided (security review)** | 2026-09-18 | Fable disposition + Codex source review |
| D6 | Groth16 proving path on this box: native tools extracted from the official prover image, digests pinned (Docker absent) | **in progress** | 2026-09-18 | Codex (implementation) |
| D7 | New endpoint and weight identity profile for the zkVM route (salted SHA-256 commitments in a fixed journal; old PCS roots not compatible) | **accepted as the P1 statement of the zkVM line, with three recorded qualifiers**; the model approval record is still to be written | 2026-09-19 | Victor (Telegram 11:50); Codex implemented |
| D8 | Custom line, caller-fixed endpoint roots: obligation stands; the "two programmed points" closure is retracted for roots with any prior public opening | **corrected** | 2026-09-18 | Codex review; accepted by the security owner |
| D9 | Reduction-bias term of the prover's mask and pad draws on the custom line (about 2^-75 at the tiny shape, 2^-72 at 8B): accept as stated, or re-freeze fixtures with rejection sampling | **accepted as stated** | 2026-09-19 | Victor (Telegram 11:50) |
| D10 | Compact-PCS proof-size lever on the custom line (95–98 bits instead of 106) | **declined: keep the Ligero-class commitment** (the "free Merkle cap" first recorded beside this ruling is worth about 1% here, not 29% — corrected the same day) | 2026-09-19 | Victor (Telegram 11:50, phrased as a question and confirmed back to him) |
| D11 | D8's proposed reduction to empty history is not established by a consuming owner; prior authentication/hash history remains in scope | **technical correction** | 2026-09-18 | Codex native reproduction and independent review |
| D12 | Composed private block on the custom line: one proof, one transcript, two external endpoints; no commitment opened twice; hidden intermediates never get a shared caller-fixed endpoint; the second norm's int8 range proof is mandatory | **construction rule (restrictive; not a privacy acceptance)** | 2026-09-19 | Security owner (Fable), from the composition gap inventory |
| D13 | What the first MVP must prove: the hidden transformer blocks are enough; generating a token (embedding, final norm, head, token selection) is the next milestone | **decided** | 2026-09-19 | Victor (Telegram 11:50) |
| D14 | Commission a costed design memo for the fewer-hashed-bytes speed lever (encoding rate 1/2 and/or a 31–32-bit field). Paper only: building it would move every frozen digest and the soundness accounting, and stays a separate ruling | **memo commissioned** | 2026-09-19 | Victor (Telegram 11:50) |
| D15 | The custom line's "106 bits" is a per-opening figure; the projected whole 8B proof is about 94 bits. Every model-scale security statement quotes the whole-proof figure | **technical clarification**; the whole-proof target itself is a ruling still to be put to Victor | 2026-09-19 | Security owner (Fable), from `ZK60_FABLE_SECURITY_OBLIGATIONS.md` §5 and the D14 memo |
| D16 | Before the private block's norm is widened toward real-model widths, its denominator and the two isqrt witnesses keep a direct byte-limb range pin sized to the new maximum, at most four limbs each, with an exact remainder window | **construction rule (precondition for widening; soundness)** | 2026-09-19 | Security owner (Fable), from the norm range lane |
| D17 | Hiding endpoints beyond the tiny shape: the whole hidden plane is bound at every width (the batched multi-block seam, unconditional); the tiny private-IO path stays byte-frozen and new entry points are additive; a feed-forward-only private pass is a cost vehicle, never P1 | **construction rule (soundness) and a naming rule** | 2026-09-19 | Security owner (Fable), from the endpoints-at-scale draft and its independent check |
| D18 | Who fixes the commitment to a hidden input: **the prover, at proof time, for the first MVP** (what is built). A third party sealing an input in advance is a **recorded todo and the expected end state** — it needs a sealed handle that is not a polynomial-commitment root and a hashing gadget inside the proof (about +13% on the private pass [COUNTED, untested]; not built) | **decided: A now, B as a todo** | 2026-09-19 | Victor (Telegram 22:15) |
| D12a | Amendment to D12 for a private RUN of several blocks: a run is **one transcript end to end** with two external endpoints **for the run**, sealed by the prover (D18); each internal boundary plane is a hidden intermediate on **one prover-generated boundary commitment**, claimed by the two adjacent blocks, **one reserved pair per claim site, opened exactly once**, its row count **derived** as data + 2·sites + 2 (a single proximity row discloses 1 and the claim audit does not catch it); all five items of D12 carry over (no commitment opened twice; the second norm's int8 range proof holds at both ends of every boundary; **a boundary's scale is one field shared by both blocks, and the run absorbs one calibration identity**). Still forbidden: joining two finished runs (needs D18's option B **and** D8/D11 discharged); a boundary commitment fixed by anyone but the prover. Soundness of a twelve-block run at the 125M geometry about 2^-97.5 by the project's accounting — acceptance of that level is Victor's, pending | **construction rule (restrictive; not a privacy acceptance); paper only, nothing built** *[2026-09-23: "paper only, nothing built" is stale since the same day — the run was built on lane `zk60-private-block-125m` (stage 12) and measured: runs of 2, 3 and 12 blocks at the development rung verify from their segments; at the 125M shape a two-block run and a twelve-block run (484,100,736 B, 2026-09-20 11:22; dense witness after the S19-F1 repair 484,107,456 B, `m125-run-l12-dense.log`, 2026-09-20 21:01); the boundary geometry is derived in `boundary.rs` and any other refused (M-1, finding U-1); a boundary scale disagreement does not construct and a foreign calibration is rejected (M-4). The rule itself is unchanged; the lane is not yet integrated, and nothing here is a privacy acceptance — evidence: `ZK60_PRIVATE_RUN_MULTI_BLOCK_DISPOSITION.md` §2a, §2b; `ZK60_SHAPED_PRIVACY_PATH_STATUS.md` §4 row 16]* | 2026-09-20 | Security owner (Fable), from the multi-block design and its independent check (`ZK60_PRIVATE_RUN_MULTI_BLOCK_DISPOSITION.md`) |
| D12b | Three construction rules for a private RUN, from the check of its composition argument. **(1) A run directory is publishable only if it contains the run statement, which is written only after the whole run has verified**; a directory without it is never transmitted and is removed by whoever launched the run; the refusal reason — which names the refusing stage, a function of the hidden input, because a run builds each block's witness inside its stage loop — is never shown to anyone not entitled to the input (rule M-9, an application of D21). "Admissible hidden input" is a joint condition on all stages. **(2) One randomness generator per run is accepted as built**, never cloned, forked or serialised, with the run's hidden input fixed before the first segment. **(3) Interior boundary scales are constants of the approved calibration**: a run refuses any other, so they are bound through the calibration identity it absorbs (before this they were bound by nothing; no proof byte moves) | **construction rules (restrictive; not a privacy acceptance)**; (3) to be built on the lane *[2026-09-23: (3) is built — lane stage 21 item 3 (`71c6509`, 2026-09-20 20:16): `RunStatement::new` refuses any interior scale pair other than the approved calibration's, failing-first recorded, and a test pins the run header's binding, boundary digests and parameter line byte-identical before and after (no absorb added, no proof byte moved). (1) is still a rule plus a test-only writer: `prove_run` has no production caller (ruling H-2; "the run layer is still dead code in release", lane stage 44). Lane not yet integrated — evidence: lane ledger `ZK60_BLOCK125M_LANE_PROGRESS.md` stages 21 and 44; `ZK60_SHAPED_PRIVACY_PATH_STATUS.md` §4 row 17]* | 2026-09-20 17:58 | Security owner (Fable); `ZK60_JOINT_LAW_COMPOSITION_RUN_DISPOSITION.md` |
| D19 | The hash functions are modelled as random oracles, in Fiat–Shamir and in the Merkle layer; the untagged shared BLAKE3 domain recorded as a deviation for the toy profile (challenges are 47-byte queries, a length nothing else uses; residual about 2^-241 — first written as 2^-243, corrected 2026-09-20 04:11 by an independent recount) and a separating tag added in new profiles | **ACCEPTED** | 2026-09-20 13:45 | Victor (console: "Yes on D19 D20 and D21"); one-pager `ZK60_RULINGS_FOR_VICTOR_PRIVACY.md` |
| D19a | How D19's tag is built, and one fixture outside it. **The tag is BLAKE3's keyed mode**: four public keys per profile (Fiat–Shamir transcript, column digest, salted Merkle leaf, Merkle inner node), each derived from the profile string; the verifier derives them from the profile it trusts, never from a receipt; a profile is either wholly on the legacy rule or wholly tagged, never a mixture. **In the model of D19 this reads the random oracle as a family of independent random functions indexed by BLAKE3's mode and key** (distinct profiles share a key only with negligible probability). Tagged: the generalised development rung, the 125M block, the multi-block run (a run uses its shape's keys and is separated from a single-block proof by its own domain string, absorbed first under the transcript key). **Built and reviewed 2026-09-20 15:50** (lane `zk60-private-block-125m` at `9ded619`; additions only in the shared files but for four transcript lines that are the identical call under the legacy rule). Never tagged: the toy (frozen; D22 rests on its bytes). **Outside the obligation, by name: the frozen-seam development rung** — its endpoint is committed inside a frozen file, so it keeps the legacy rule as a whole; it is a stepping-stone fixture, never a deliverable, and **may not appear in any privacy statement**. A tagged commitment declines the GPU hasher until a keyed device path exists — a temporary CPU fallback, not a performance result | **construction ruling under D19 (not a privacy acceptance)** | 2026-09-20 15:01 | Security owner (Fable), after the integrator's review; `ZK60_D19_HASH_TAG_DISPOSITION.md` |
| D19b | **The model behind the tag of D19a — proposed, for Victor.** D19a reads D19's random oracle as a family of independent random functions, one per BLAKE3 mode **and key**. Corrections to D19a's own text (2026-09-21 01:12): that is **not** "BLAKE3's own design claim" — the designers' claim separates the three *modes*, whereas the salted-leaf and inner-node functions are the *same* mode under different **published** keys; and the randomness generator is **not** keyed (only its key derivation is; its stream is unkeyed BLAKE3 over key and counter). The honest model is that **BLAKE3's compression function is ideal, also when the adversary knows and chooses the chaining value it starts from** — the assumption under which BLAKE3 is shown to behave as a random function at all, but stronger than D19 as it was put to Victor. Nothing accepted rests on it (no tagged profile has a privacy statement; D22 is the untagged toy), and nothing measurable changes: the tag removes two terms of about 2^-241 and 2^-485 and adds a key-collision term of about 2^-251, zero for the keys that exist, by test. Recorded alternative: a one-byte prefix per domain under the single unkeyed function — inside D19 exactly, about half a percent of hashing, and a redo of the tag stage | **ACCEPTED by Victor 2026-10-17 19:28 UTC** ("all recommendations yes", in the Claude console, answering the sheet `ZK60_RULINGS_FOR_VICTOR_20261017.md`; the same answer came by Telegram at 19:24); proposed text unchanged | 2026-09-21 01:12 | Security owner (Fable), from the independent check of the run's hash-layer argument; `ZK60_HASH_LAYER_AND_FS_LIFT_RUN_DISPOSITION.md` ruling H-4 |
| D20 | Timing, memory and power are out of scope for the first MVP; **refusals are NOT** — they stay inside the privacy argument (challenge-only, about 2^-62; one of eighteen classes is input-dependent at about 2^-112 and is carried as a named residual) | **ACCEPTED** | 2026-09-20 13:45 | Victor (console); same one-pager |
| D21 | Rejected receipts are never transmitted, and retained capture bundles count as publishing: nothing computed from a hidden input may be added to them; a refusal reason is never shown to anyone not entitled to the input | **ACCEPTED** | 2026-09-20 13:45 | Victor (console); same one-pager |
| D22 | **Privacy accepted for ONE artifact: the toy private-block profile `hashline-zk-mr1/private-block-t32-poc/1`** (one block, 32 tokens, width 16, public synthetic weights, the prover sealing its own endpoints per D18): in the random-oracle model (D19), under the named generator assumption, an accepted receipt's view is within about 2^-77.7 per proof of one that does not depend on the hidden input, output or activations; refusal is challenge-only up to 2^-112; timing, memory and power out of scope (D20); operating rules of D21. **It is an argument each of whose steps survived one independent attack, not a proof re-derived by the security owner; it lapses for any code that changes one of its seven conditions. It covers NOTHING else: not the development rung, not the 125M block, not any multi-block run, not real weights, not sealing in advance (D8 and D11 untouched), not soundness**. *Scope said more exactly on 2026-09-21 03:23: it covers the profile on the **CPU path** — at this untagged profile a GPU-feature build with the accelerator enabled hashes columns with two hand-written CUDA kernels and moves blinding material to device memory, and that configuration is not covered until it has been read; and "the generator" means the proof's three generators jointly, separate operating-system entropy reads being assumed independent. On 2026-09-20 22:06 it was re-read against the integrator's merged code (`4751b93`) and its source pins extended to all 29 files on its path. On 2026-09-21 10:44 the refusal clause was sharpened, number unchanged (statement §9 item 10; ruling V-3 of `ZK60_BLOCK125M_S28_DISPOSITION.md`): for every admitted witness, WHETHER an attempt is refused for a zero lookup denominator is a function of the public challenges and the three public tables alone, because the prover inverts each whole table on every attempt; only which of two lines returns first depends on the hidden input, with the identical message and no absorb or draw between them — so "up to 2^-112" is an over-estimate kept as it is; the unqualified form of that sentence (for ANY witness) is false and is not claimed. On 2026-09-22 10:20 the gates were replayed on a capture of a receipt produced by the merged tree's own binary at `4751b93` (delivered by the integrator): 132 of 132 source pins equal, no figure of record moved, all ten controls fire — the statement now rests on the merged tree's proofs as well as the old tree's; scope unchanged* | **accepted by the security owner, within the model Victor accepted the same day** | 2026-09-20 13:46 | Security owner (Fable); statement `ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md` |
| D23 | **An accepted receipt's endpoint roots are never registered, republished or referred to by a later artifact — proposed, for Victor.** The privacy case's hypothesis O-2 / ask R-9 (`ZK60_PRIVACY_CASE_FIRST_MVP.md` §1.2 item 1, §5.2, l.1633, l.1801): the moment a later artifact refers to an accepted receipt's two endpoint roots (e.g. chains its output root into another proof, or records it in a registry), the D8/D11 question applies and D22 no longer covers that receipt. It was never put to Victor nor listed in D22's statement; found 2026-09-23 by `ZK60_BLINDING_LAW_GR4_TOY_READING.md`. The security owner carries it as a stated hypothesis of the toy statement (§6) from 2026-09-23 16:52; the argument and its figures are unchanged. Constrains operations, so it is Victor's | **ACCEPTED by Victor 2026-10-17 19:28 UTC** ("all recommendations yes", in the Claude console, answering the sheet `ZK60_RULINGS_FOR_VICTOR_20261017.md`; the same answer came by Telegram at 19:24); proposed text unchanged | 2026-09-23 16:52 | Security owner (Opus 5.5 session continuing the Fable lane); one-pager `ZK60_RULINGS_FOR_VICTOR_PRIVACY.md` |
| D24 | **Norm precision per profile instead of a fifth remainder limb — proposed 2026-10-17.** New trained profiles lower `NORM_TN` (10 at width 2048, 9 at width 4096) and scale the norm multiplier with it, so the exact remainder window stays at most 32 bits (four byte limbs, D16 rule 4); `D_max` for new profiles counts int16 -32768 and the profile's epsilon; old profiles stay byte-frozen | **ACCEPTED 2026-10-17 (security-owner lane, after two independent review rounds): norm rule, per-profile shifts, trained profile and loader; conditions R2-a/R2-b being fixed; round 3 (18:36 UTC) accepted the Llama-3-8B profile changes on soundness, verifier-DoS finding r3_6 open; not a privacy acceptance** | 2026-10-17 | Claude (security-owner lane) |
| D25 | **Proving the next token (D13's next milestone): eight product rulings T1–T8.** T1 one hidden next token per run first (mode i), a whole greedy continuation in one pass later (mode ii); T2 the prompt length stays hidden in mode (i) and is sealed inside the input endpoint so the owner can check it (needs the security-owner ruling R9 on the two-site endpoint geometry); T3 ties go to the lowest token id (numpy first maximum); T4 (amended 2026-10-17 20:21 UTC, option (b)) the integer head uses per-row int8 scales with 12-bit integer multipliers, and is accepted if its token equals the float head's on the same stack output at every held-out position where the float head's top-2 margin is >= 0.3 logits (measured 100%; overall 98.9%; every miss a float near-tie) — the original >= 99% overall threshold was missed (98.45% per-tensor, 98.91% per-row; `results/zk60_token_io_fidelity_20261017/REPORT.md`) and the 16-bit final-norm alternative (99.57%) was declined; T5 the verifier never sees the token: the prover hands the owner the token and the endpoint opening privately and the owner checks it against the receipt (rests on D21 and D23); T6 repeated one-token runs are not a proved token stream and every claim says so; T7 the receipt names the embedding and head by export digest, not proved to come from the checkpoint (as for the blocks under D24); T8 the proof forces the BOS token at position 0. Design `results/zk60_token_io_design_20261017/DESIGN.md`, adversarial check `.../check/CHECK.md` (core sound; binding changes B-1..B-3 folded in before rung R1) | **ACCEPTED by Victor 2026-10-17 19:28 UTC** ("all recommendations yes", Claude console); T4's threshold is applied to the fidelity measurement in `results/zk60_token_io_fidelity_20261017/`; nothing is built yet; not a privacy acceptance | 2026-10-17 | Victor, on the coordinating Claude session's sheet |
| D26 | **The two-site input token endpoint (R9; token-I/O run profiles only).** For a token-I/O run that hides the prompt length (D25 T2) or proves a greedy continuation (mode ii), the external input token endpoint is a hiding commitment with **two claim sites**: derived geometry `rows = data + 2·2 + 2`, row width 2^8, rate 1/8 (2^-106.25 per opening), its own spec type and digest domain, any other row count refused by name; prover-sealed (D18), root never referred to later (D23); claimed exactly twice — stage IN's IO-in on half 0 (public half bit 0) and stage OUT's IO-s on half 1 (`s = e_{P−1}`; SHIFT in mode ii) at public half bit 1 — each with its own reserved pair and each IO slot over its whole half with the public support factor; **opened exactly once after stage OUT and `B_out`**, the verifier refusing any other place, claim count or second opening; variant (public row / P / F), geometry and opening place fixed by the run statement, never by a segment; the owner re-encodes at the derived geometry and checks the root, the profile's BOS, the prompt, pad ids, zero pad words and `s = e_{P−1}`. **Variant P adopted; F (selector in the output endpoint) the recorded fallback; C not adopted.** Conditions C-a..C-e of the second check bind. Design fixes N-1 (the BOS clause gets its own fresh challenge drawn after `A_in`), N-2 (BOS id a per-profile statement constant in [0, V)) and N-3 (every batched clause has a fresh challenge) are part of building to this rule | **construction rule (security owner); not a privacy acceptance** — the D17 rule-3 joint-view gate (G-6/G-7) on captured receipts at both geometries is owed before any figure from a hidden-length or mode-(ii) receipt is quoted | 2026-10-17 19:50 | Claude (coordinating session as security owner), on the design `results/zk60_token_io_design_20261017/DESIGN.md` §8 and two independent adversarial passes (`check/CHECK.md`, `check/CHECK2.md` §4) |
| D27 | **The custom line's soundness target (question G.0-2).** The target is stated **per run at a named workload** (today Llama-3-8B, T = 512) as a whole-run union bound, with the forger-work-per-attempt reading quoted beside it. **MVP: about 95 bits whole-run (derived lookup bound, D15 note of 20:10; about 99.7 bits as work per attempt) is accepted as a recorded deviation**, next to the zkVM line's 97 conjectured (D3); **next milestone: 100 bits whole-run**, preferably through LogUp-GKR with a 256-bit lookup challenge (otherwise lookup repetition at about −33% throughput); **product: 128**. Throughput is not traded for bits at the MVP; near-free levers (more column checks) may be taken when convenient. Victor's reasoning: throughput matters more for applications than making the protocol "ridiculously unbeatable"; at about 95 bits a forgery needs about a million A100s for about 8,700 years or the whole Bitcoin network for about a year (generous one-hash-per-try estimate) | **ACCEPTED by Victor 2026-10-17 20:21 UTC** ("G.0-2 yes", Claude console); memo `results/zk60_soundness_recount_20261017/MEMO_G02.md`, lookup-bound check `.../check_logup/CHECK.md`; every security statement quotes the whole-run figure with its workload. **Direction added by Victor 20:22 UTC: proofs must eventually be selectable at different security standards for more critical applications.** Consequences: the security tier (e.g. MVP ~95, 100, 128 whole-run at the named workload) is a profile parameter bound into the run statement, with its derived whole-run figure; the verifier takes a minimum tier as policy and refuses receipts below it; the tier levers (column checks Q, lookup challenge field or repetition, proximity vectors) stay profile parameters, never hard-coded constants, in new code (token I/O included). Building more than the MVP tier is post-MVP work | 2026-10-17 | Victor, on the coordinating Claude session's sheet |
| D28 | **CS-2 and CS-5 are not needed at the trained profiles.** The 125M lane's refusal rulings CS-2 and CS-5 guard against shapes whose arithmetic windows could be set loosely; at the trained profiles every window is derived and checked exactly at construction (`shape.rs` ~1196-1200, ~1238-1246; `layout.rs` ~1080-1082) and the width is capped at 4096, so neither ruling adds a refusal the trained door does not already make. The trained privacy statement records them as unnecessary on these code facts | **construction reading (security owner); not a privacy acceptance** — reopen if a trained profile ever admits a declared (not derived) window or a width above 4096 | 2026-10-19 09:31 | Claude (coordinating session as security owner), on the privacy review (`results/zk60_privacy_review_trained_t32_20261017/REVIEW.md` P-13, `REVIEW2.md`) and the native tree |
| D29 | **The refusal census is a completeness item, not a condition of the trained privacy statement.** Since native R6 the honest prover runs the CS-3 lookup-miss refusal on every sealed witness in the sealing pass, before the run header exists (review r6, N-r5-a), so every refusal the trained door or the witness builder can make happens before anything is published (H-1 by code). Under D20/D21 a refused input publishes nothing; how often honest inputs are refused (GN-1/GS-14) is therefore a completeness and usability measurement, still owed, but it no longer bounds the privacy sentence | **reading (security owner); not a privacy acceptance** — reopen if any refusal can occur after the run header | 2026-10-19 09:31 | Claude (coordinating session as security owner), on `REVIEW2.md` Q-7 and `results/zk60_d24_review_20261017/R6_VERDICT.md` |
| D30 | **DD, the per-row division dictionary, admitted into the Llama-3-8B T512 profile specification.** Each attention row gets `cap` committed slots (key = row id or row Sum, public e from sorted({0} ∪ exp outputs), P_dict = floor(e·2^F_P/Sum) proved by the existing exact-division relation with byte-limb windows); each score entry does one tuple lookup into its row's slots instead of carrying its own division limbs. Bit-exact; −20.8% committed elements, −28.2% byte lookups, −20.1% zero-check work at 8B T512 [COUNTED]; supersedes EXR; FN stays a fallback. Conditions (binding): (1) every dictionary position is a valid tuple — division clauses and limb lookups at every slot of a true row with no usage gate, pads (key, 0, 0) and pad-zero limbs, multiplicities and helpers never gated; (2) tuples and multiplicities committed in `A` before β, γ, α, a distinct tag and β² for P; (3) the table helper in the single value-0 sum claim with sign −1, every dictionary plane opened only at its own reserved site, no virtual claim, P-3 unchanged; (4) the prover inverts every dictionary slot on every attempt, and the refusal residual 2·L·(768 + rows·cap)/p² (~2^-103 per 32-block run) replaces D22 §9 item 10's challenge-only sentence for this profile; (5) lookup term (N + 2303 + 4·rows·cap)/|F| per block, P's range accepted as range-by-membership in D16 rule 5's audit; (6) a profile whose exp tables need more than `cap` slots is refused at the trained door by name before any header; plus binding changes B-1..B-8 of the check | **construction rule (security owner); paper only, nothing built; not a privacy acceptance** — before any DD receipt is called sound or private: an independent soundness review of the written relations, the rank lemma / NL-1 / gate blinding and joint passes on captures of the new profile, and the calibration lane confirming the column count ≤ cap at T512 (the B6 e_s 0 candidate would force cap 64). Lapses on any unconstrained position, multiplicities moved after α, the helper leaving the sum claim, or cap exceeded without a refusal | 2026-10-19 09:53 | Claude (coordinating session as security owner), on the proposal (`results/zk60_gpt_nonlinear_review_20261018/REVIEW.md` round 2, from Victor's shared GPT conversation "Optimize Lookup Table Size") and its adversarial check (`.../dd_check/CHECK.md`) |
| D31 | **pg_rot1's identical lookup pairs are kept, as read; the declared class is not restricted.** At the trained TinyLlama export pg_rot1 four lookup pairs coincide (F RGL, Q RQL, Kv RKL, RVL), each landing in one paired LogUp helper whose relation has two equal denominators (H[19], H[26], H[28], H[39]). G-7 read them at the trained export: no duplicated H plane, no repeated terminal coordinate, no two equal published values in any capture; NL-1 S0–S5 pass; terminal surjection A 36/36 disclosed 0, H 8/9 with the LogUp sum claim disclosing exactly the declared 2, endpoints and boundary 0. Soundness of a paired helper with equal members is the LogUp check's counted case. Restricting the class to sh <= 7 (no such pairs) would discard the evidence of record for no measured gain | **reading (security owner); not a privacy acceptance** — reopen if a capture ever shows a duplicated plane, a repeated terminal coordinate or equal published values from these pairs | 2026-10-19 10:29 | Claude (coordinating session as security owner), on the gate's G-7 (`results/zk60_gate_tinyllama_20261017/g7/`) |
| D32 | **Fidelity target: no performance degradation versus the float model.** The proved integer model must score essentially the same as the original float model on task performance (held-out perplexity and downstream benchmarks); token-by-token agreement with the float model is a diagnostic, not the target. Today's gap: held-out perplexity 9.72 -> 15.48 at Llama-3-8B T128 (export b7) and 12.67 -> 15.80 at TinyLlama-1.1B T128; the exact metric set and the numeric "no degradation" threshold are proposed by the fidelity lane for Victor to confirm. Weight-side calibration (rounding, scale folding, rotations, calibration data) costs the proof nothing because weights are public and fixed; profile changes are costed against the speed plan | **ACCEPTED by Victor 2026-10-19 11:30 UTC** (Claude console: "fidelity target: no performance degredation versus float"; also stated by Telegram at 11:28 UTC). **Threshold RULED by Victor 2026-10-19 ~17:00 UTC** (Claude console: "fidelity target: ppl <= 1.01, LAMBADA >= 99%, no refusals"): held-out perplexity of the integer model at most **1.01x** the float model's (on the fidelity lane's held-out sets, FineWeb and WikiText); LAMBADA accuracy at least **99%** of the float model's; **zero** refusals on the evaluation sets. The threshold is on the point estimates; confidence intervals are reported beside them (the proposal's extra "upper CI <= 1.02" clause was not part of the ruling). **Threshold AMENDED by Victor 2026-10-21 ~00:19 UTC** (Claude console: "As far as fidelity goes, 1-2% is acceptable so I'd say let's fix the refusals and proceed with the current fidelity"): a 1–2% degradation is acceptable — recorded as held-out perplexity **≤ 1.02x** float (FineWeb and WikiText) and, by the same reading, LAMBADA **≥ 98%** of float [the coordinating session's reading of "1-2%" for LAMBADA, to be corrected if Victor meant otherwise]; **zero refusals stays** ("fix the refusals"). "Proceed with the current fidelity" is read as: stop chasing the 1.01 bar, lock in the level now reached, and take the **cheapest** accuracy stack that meets ≤ 1.02 with zero refusals at both models (measured candidates: 8B LOW 1.021 / 1.010 at about +22% committed, 8B HIGH 1.0045 / 1.0034 at about +29%; cheaper subsets to be checked), then build it as a new profile (soundness review and privacy gate before any claim) | 2026-10-19; amended 2026-10-21 | Victor |
| D33 | **Privacy accepted for ONE artifact: an accepted, bound run of the trained TinyLlama-1.1B T32 profile** (`hashline-zk-mr1/private-run-tinyllama-1.1b-t32-trained-statement/1`, calibration `pg_rot1_export_T32` profile.json `b25ba5f5…`, L = 1, 2 and 22, the CPU binary `e51cc6a4…` built from native R7 tree `36a8aed1…` with its 46 pins): in the random-oracle model for BLAKE3 read per D19b, under the generator assumption E-1 / X-1, an accepted run's view is within about **2^-74.8 / 2^-73.8 / 2^-70.4** per run (L = 1 / 2 / 22) of one that does not depend on the hidden run input, output, activations or internal boundary planes, for every admissible input; the refusal fact is challenge-only up to 2^-117.4 / 2^-116.4 / 2^-113.0. In plain words: someone checking a proof of the 22-layer TinyLlama stack learns nothing about the hidden prompt, activations or output, except with odds around one in 2^70 per run (about one in 2^40 over a billion runs). **Not covered:** other calibrations (dg, b4, every per-layer export), other T, the GPU path, the next-token stages (embedding / final norm / head / token choice; gate round 7 owed), Llama-3-8B, soundness (the D24 review's), the refusal fact itself. Like D22 it is an argument whose steps survived one independent attack per step (three review rounds), not a proof re-derived by the security owner | **ACCEPTED by Victor 2026-10-19 16:56 UTC** (Claude console: "accept thrTinyLlama privacy statement"), on the coordinating session's recommendation; **IN FORCE for R7 only** — native R8 changes five pinned files (`private_block.rs`, `run.rs`, `shape.rs`, `trained_block.rs`, `trained_statement.rs`), so by condition 7 step 3 is suspended for R8 and later trees until a gate re-pin round re-reads them. Text: `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_TRAINED_TINYLLAMA_T32.md` (acceptance header + the frozen final draft byte for byte, body sha256 `f971424f…`, file sha256 `ded3f0e7…`). Lapses on anything in its §9. **Note 2026-10-20 00:10 UTC:** the gate's re-pin note onto the token lane's frozen round-7 tree (R8 + token code) is written (`results/zk60_gate_tinyllama_20261017/tk7/ZK60_PRIVACY_STATEMENT_REPIN_TK7_20261019.md`, sha256 `9958e548…`; 10 records PASS, randomness-free figures equal R7's) and is under independent privacy review (REVIEW4); the suspension for that tree is NOT lifted until the review and Victor's word. **EXTENDED by Victor 2026-10-21 ~00:17 UTC** (Claude console: "I say yes to both extending D33 to frozen-r9 as well as the next-token privacy statement"): D33 is in force, unchanged in sentence, residuals and limits, also for the token lane's **frozen-r9** tree (manifest list sha256 `b666a991…`, = native R8 + next-token code), naming frozen-r9's **52 pins** (R7's 46 and the tk7 readings kept), the trained-block CPU binary **`911e82f0…`**, and the P-18 capture-and-gate and 22-block pass F **carried by reading**; basis the gate re-pin notes tk7 (`9958e548…`) and tk9 (`c4d88df1…`) and privacy review rounds 4 / 5 part A (YES). Token round 11 (`frozen-r11/`, binary `0c9f247c…`) is not covered until its re-pin reading is recorded. Note added to the statement file's header. **Further EXTENDED to frozen-r11 2026-10-21 02:27 UTC** (Victor via Telegram: "also for 'extend D33 and D36 to frozen-r11' yes for that as well"; console confirmation requested), naming frozen-r11's pins and the trained-block binary `631e2a15…`; basis gate round-15 note (`a0c28c57…`) and privacy review round 6 (YES) | 2026-10-19; extended 2026-10-21 | Victor |
| D34 | **Next-token stages: the input-dependent LogUp refusal is priced as a distance term, as D30 (4) did for DD.** In the next-token profiles (public-row variant) stage IN inverts only the prompt's own τ rows (at most T distinct, q_t = τ(tok_t), no position tag) and stage OUT at most 256 byte values; nothing is drawn or absorbed in between, the message is constant and there is no retry. Whether the prover hits a zero denominator there therefore depends on hidden data. Accepted as a counted two-world distance of 2·(768L + 32 + 256)/p² per run (2^-116.96 at L = 1 by this formula, the figure the statement carries; the reviewer's tight count is about 2^-117.14 — wording corrected 2026-10-20 04:33 UTC on the gate's note), which replaces, for the token stages, the "refusal is a function of the challenges and public tables alone" sentence; any next-token privacy statement must carry it. Inverting the whole τ table (challenge-only refusal) is rejected: it gives a worse 2^-111.96 and buys nothing the statement uses. In plain words: the chance that whether a run is refused gives away something about the hidden prompt is about one in 2^117, far below the statement's other terms (~2^-70) | **accounting rule (security owner); not a privacy acceptance** — lapses if the token stages draw or absorb between the inversions, retry an attempt, or add a position tag that changes the count | 2026-10-20 00:16 | Claude (coordinating session as security owner), on gate finding F-T2 (`results/zk60_gate_tinyllama_20261017/round9/PRIVACY_STATEMENT_NEXT_TOKEN_T32_DRAFT.md`) and its independent pricing in privacy review round 4 PR4-5 (`results/zk60_privacy_review_trained_t32_20261017/REVIEW4.md`) |
| — | **D30 implementation note (2026-10-20 04:56 UTC):** DD is BUILT as native R9 (frozen 2026-10-20T04:52:07Z, tree `af90c703…`, 222 files; patch `results/zk60_1b_native_20261017/r9/r9-vs-r8.patch`), profile-gated (`--dd`) at TinyLlama T128, Llama-3-8B T128 and a T32 dev rung; cap 32 counting {0} ∪ outputs, key = row Sum, TAG_DD 141, slot 23 appended last; non-DD transcripts byte-identical to R8 (seeded goldens equal; R8 receipts verify under R9 with identical statements). **Added restriction (refuses by name, changes no relation):** a DD profile must have an unpadded dictionary (h_pad = heads, t_pad = T, cap a power of two, Dom::S / Dd at or above the row width), which makes B-3's pad clause vacuous at these profiles. Measured at T128 [MEASURED, shared box, n=1]: 8B prove 478.7 -> 474.9 s (no measurable change; counted −3.86% committed), TinyLlama counted −6.66% committed (its measured −23% is box state, every phase fell alike). **Still owed before any DD receipt is called sound or private:** D24 review round r9 (running), then the gate on DD captures. **Update 2026-10-20 05:59 UTC: D24 review r9 ACCEPTS R9 on soundness at the three DD profiles** (`results/zk60_d24_review_20261017/R9_VERDICT.md`; no soundness finding; every dictionary slot constrained, commitment before β/γ/α, helper in the sum claim, P's range by membership holds, cap refused by name in four places, non-DD byte identity confirmed, mutations real; lookup term per run 2^-98.80 TinyLlama T128 DD / 2^-97.37 8B T128 DD). Binding conditions added from the review: **N-r9-a** — the Sum key rests on the row-sum relation; any change to that relation, its hosting at slot 17 or the Ht gate re-opens D30; **N-r9-b** — M_dd stays in A and the verifier draws no lookup challenge before the A commitment. Still owed before any DD receipt is called private: the gate (rank lemma, NL-1, joint passes) on DD captures. **Update 2026-10-21 05:30 UTC: the gate on DD captures is done** (gate round 14, `results/zk60_gate_tinyllama_20261017/round14/DD_GATE_REPORT_R9_20261021.md` + `.UPDATE-0530.md`): 13 of 13 staged records PASS with 0 unexplained leaves on the DD dev rung and TinyLlama T128 DD at L = 1 and 2 — the dictionary planes and slot 23 add no disclosure (A discloses 0; H discloses the pre-DD 2), full zero-data preimage and joint passes 0 differing, DD NL-1, DT-1..7 and DS-1/DS-2 controls fire. Gate evidence only: a DD receipt is called private only under a privacy statement covering its profile (none yet; the classifier statement will be the first) | built; **sound (r9)**; **gated (round 14)**; no privacy statement yet | 2026-10-20 | Claude (coordinating session) |
| D36 | **Privacy accepted for the trained TinyLlama-1.1B NEXT-TOKEN proof (T32, public-row variant, calibration `pg_rot1_b4_T32_cal128`, CPU path, frozen-r9 / token binary `b56f1b71…`, 52 pins).** One proof covers the embedding lookup, all trained blocks, the final norm, the head and the greedy next-token choice; a verifier of an accepted run is never given the prompt's ids at positions 1–31, their embedding rows, the activations and inter-block planes, the final-norm values and logits, or the next token, and its view is within about 2^-74.43 / 2^-73.62 / 2^-70.35 per run (L = 1 / 2 / 22) of a distribution that does not depend on them (same model as D33: D19, D19b, D20, D21, E-1 / X-1). Public: T = 32, BOS at position 0, V, the model files by digest, L, the identity. Carries D34 and D35; D29's reading extends to token runs (every input-provokable refusal precedes the header by code at both production callers, condition T-5); the harness carry is confirmed by gate round 12's re-capture (every randomness-free figure equal). In plain words: someone checking a proof of TinyLlama's next word never gets the prompt or the answer, and learns essentially nothing about them (about 1 in 2^70 per run). **Not covered:** Llama-3-8B, other calibrations (including D33's pg_rot1_export_T32 and every accuracy-fix profile), the hidden-length variant, the GPU path, what an output owner who is not the input owner learns about the prompt, delivery of decommitments to separate owners, soundness. Like D22 / D33, an argument whose steps survived independent attack (privacy review rounds 4–5), not a proof re-derived by the security owner | **ACCEPTED by Victor 2026-10-21 ~00:17 UTC** (Claude console: "I say yes to both extending D33 to frozen-r9 as well as the next-token privacy statement"), on the coordinating session's recommendation; **IN FORCE for frozen-r9 and binary `b56f1b71…`**; **extended to frozen-r11 and the token binary `0c9f247c…` (the demo's) 2026-10-21 02:27 UTC** (Victor via Telegram: "also for 'extend D33 and D36 to frozen-r11' yes for that as well"; console confirmation requested), basis gate round-15 note (`a0c28c57…`) and privacy review round 6 (YES). Text: `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_NEXT_TOKEN_TINYLLAMA_T32.md` (acceptance header + frozen draft v3 byte for byte, body sha256 `97853f25…`, file sha256 `aaefa158…`). Lapses on anything in its §9 | 2026-10-21 | Victor |
| D37 | **First application and full MVP: proven safety classification for a media app.** The first application of the proofs is security / harmful-content classifiers: a media app whose content carries **public proofs that it passed a harmful-content classifier** is the full MVP shown to investors. Victor asked specifically to look at Mistral's classifier models built to filter harmful content; a survey of Mistral's and other open safety classifiers (architecture fit with the Llama-style prover, size, prompt length, single-token verdict, licence, quality, text vs images) runs first (`results/zk60_classifier_survey_20261021/`). Working reading, consistent with P1 (not reopening it): the content is the hidden input; the classifier's verdict is the output the platform (output owner) chooses to publish by releasing its opening, so the public proof shows "this content was classified safe by model M" without the proof revealing the content | **product direction (Victor)**; model choice, app design and build plan follow the survey. **Operating model clarified by Victor 2026-10-21 03:19 UTC** (Telegram, spool line 2026-10-20T20:19:40 PDT: "The media platform will work by only allowing clean content on it. This makes proofs a one time computation at creation time. This removes the need for low latency proofs of content as content only needs to be proven once on creation time"): only content proved clean is published; each item is proved **once, at creation**; proof latency of minutes is acceptable (no low-latency requirement). Consistent with the fail-closed rule and the one-proof-per-item rule (O-1). **Revised by Victor 2026-10-21 03:23 UTC** (Telegram, spool line 2026-10-20T20:22:58 PDT: "Actually the proofs can just be used after the fact to determine who to distribute the content to. For instance, if content is explicit there is a proof of its explicit nature published then the app itself can later use that proof to determine not to send the content to a minor (as an example)"): the proofs are **content labels used for distribution** — content is classified at creation against a fixed, pre-registered list of categories (for example "explicit"), each label is published with its proof whether the answer is yes or no, and the app later uses the proved labels to decide who receives the content (for example, explicit content is not sent to minors). Each item is still proved once per category, at creation; latency of minutes is fine. Working reading: content without an accepted proof for a category is treated as the most restrictive label for it (not distributed to restricted audiences). The category list is to be confirmed by Victor. **Addendum by Victor 2026-10-21 03:24 UTC** (Telegram, spool line 2026-10-20T20:23:43 PDT: "So for all classifiers run on the content a proof is published and later as the content is distributed the signatures for each classifier are appended"): every classifier run on an item yields a published proof, and when the item is distributed it carries an appended **manifest of those proofs** (one entry per classifier or category: model, policy, verdict, proof and anchor reference, signed by the app), so any recipient can check which proved labels apply — a content-credentials pattern. **Category list confirmed by Victor 2026-10-21 03:25 UTC** (Telegram, spool line 2026-10-20T20:25:09 PDT: "I agree with these three suggested categories"): the POC categories are (1) **sexual / explicit content**, (2) **graphic violence**, (3) **hate / harassment** — three fixed Shieldstral policy texts, one threshold each, three proofs per item at creation | 2026-10-21 00:22 | Victor (Claude console: "For a first application, we will use these proofs for security classifiers. Have a look at mistral's classifier models that are built to filter harmful content, It would be nice to program a media app that comes with public proofs of non harmful content as our full MVP for VCs") |
| D38 | **The MVP classifier and what its proof states.** (a) **Model:** Mistral's open safety classifier **Shieldstral-1.0-3B** (Apache 2.0, ungated; Ministral-3-3B decoder), **text only** for the MVP (its Pixtral image encoder is not proved; images later). (b) **Statement:** the classifier proof states that the model's **yes-logit minus no-logit exceeds a public threshold** c (Mistral's own decision rule: score = softmax over the two logits, flagged above τ, i.e. z_yes − z_no > ln(τ/(1−τ))), computed from two rows of the head, instead of "the greedy next token over the full vocabulary". (c) **Disclosure:** only the verdict (safe / unsafe), the model identity and the policy text become public; the content is the hidden input; the confidence score is not published. Survey: `results/zk60_classifier_survey_20261021/REPORT.md` | **ACCEPTED by Victor 2026-10-21 02:27 UTC via Telegram** (spool line 2026-10-20T19:27:30 PDT: "For the classifier rulings go ahead with yes to all three a) b) and c)"); console confirmation requested for the record | 2026-10-21 | Victor |
| D39 | **MVP scope widened: text, image and video content; proofs published on a cheap blockchain (feasibility first).** (1) The proof-of-concept must prove text, **image and video** content, so D38's "text only" is widened. Images go through Shieldstral's own Pixtral vision encoder, which needs new prover relations: non-causal attention, 2D RoPE, GELU, patch embedding, the 2×2 merge, and binding the proof to the posted image. Video goes through a public, deterministic frame-sampling policy, with each sampled frame proved as an image and any audio or transcript handled separately; the design and cost come first. (2) **Publication:** the proofs should be published on a cheap blockchain so they are public and persistent. A feasibility analysis comes first. Today's receipts are 0.26–0.93 GB, so the likely shape is the proof stored off-chain on a persistent store, with its digest, verdict and statement anchored on-chain; on-chain verification would need a succinct wrapper | **product direction (Victor)**; feasibility analysis (chain) and multimodal design run before any build commitment. **Narrowed by Victor 2026-10-21 03:17 UTC** (Telegram, spool line 2026-10-20T20:17:35 PDT: "Let's just do image and text for now"): the POC covers **text and image** only; video (and audio) is deferred | 2026-10-21 02:36 | Victor via Telegram (spool line 2026-10-20T19:35:30 PDT: "For the media app lane, I would like to publish the proofs on a cheap blockchain so the proofs are publicly available and persistent. Let's do a feasibility analysis of this. I also want this POC to be able to prove text video and image content") |
| D40 | **Classifier profiles (D38): one external endpoint plus a public verdict bit; D34 recounted.** Construction rule for the classifier profile family: the run has ONE external endpoint (the input token endpoint) and NO output endpoint; the verdict b is a public bit absorbed into the transcript header and sits in the margin slot's public right-hand side (D12a's "two external endpoints" reads as one endpoint plus a public bit for these profiles). D34's input-dependent refusal term is recounted for Shieldstral's shape (L = 26, T ≤ 512): about 2^-112.7 per run [COUNTED by the adversarial check], and any classifier privacy statement carries that figure. Binding with the design's fixes B-1 (prefix ends at ':', content encoded ' ' + content by tekken's plain-text encoder), B-2 (that encoder pinned by digest; control ids excluded at content positions in-circuit) and B-3 (the verifier re-derives the margin vector, multipliers, c and the yes/no ids from the export) | **construction rule (security owner); not a privacy acceptance**; the classifier privacy statement, gate and Victor's acceptance follow the build | 2026-10-21 03:02 | Claude (coordinating session as security owner), on the adversarial check `results/zk60_token_io_r1_20261017/classifier/check/CHECK.md` (B-7) |
| D41 | **Long content is split into chunks, each proved; the chunk size is tunable per machine.** Content longer than the proof length allows is split into small chunks, each classified and proved separately per category (as many as needed, e.g. 40), and the chunk size is a tunable setting so the demo can run on different hardware (laptop T128: about 40 content tokens per chunk; T256 about 168; T512 about 424). Working design (coordinator's reading, for the lanes): the content is tokenized once with the pinned encoder and split on token boundaries, with optional overlap between chunks (tunable) to reduce missed meaning across a cut; the post's label for a category is "yes" if any chunk's proof says yes (and any chunk without an accepted proof counts as yes, fail-closed); the manifest lists every chunk proof with its token range so a verifier sees that the chunks cover the whole content. Consequences to note: per-chunk verdict bits are public, so a "yes" also shows which part of the post triggered it; classification of a chunk lacks the rest of the post's context | **product direction (Victor)**; design detail with the token and app lanes | 2026-10-21 03:36 | Victor via Telegram (spool line 2026-10-20T20:36:01 PDT: "For now, split the content up into small enough chunks and prove each chunk (40 chunks if needed) allow this to be a tunable thing. So we can demo on different hardware") |
| D42 | **Swap in the resource-guard fix today.** The live `scripts/zk60_resource_guard.py` (sha256 f0b87668…) is replaced by the reviewed candidate `results/zk60_guard_fix_20261021/zk60_resource_guard.py.new` (sha256 87138bda…: admission before the heavy lock; FIFO mode present but OFF by default), following `results/zk60_guard_fix_20261021/NOTES.md` §7: all lanes on hold and no guard process in any session's view; rollback copy kept outside /tmp (`results/zk60_sol_20261026/guard-backup/`); official guard suites without sandbox skips plus the 31 staged tests; Sol (a Codex agent, S3) updates the two static pins (`scripts/zk60_guarded_command.py` `REVIEWED_GUARD_SHA256`, `scripts/zk60_techweek_demo.py` `GUARD_PIN`) in the same window and notes it in `ops/zkp-mvp/RECOVERY_COORDINATION.md`; never during a demo | **operations ruling (Victor)**; **done 2026-10-26 19:00:31 UTC** (Sol S3: official suites 45/45 + 31/31 without skips, consumer suites green, both pins = 87138bda…, FIFO off; audit `results/zk60_sol_20261026/S3_AUDIT.json`; coordinator re-checked the live hash and pins at 19:01) | 2026-10-26 18:22 | Victor (console: "swap yes"), answering the 2026-10-21 06:20 question in `ZK60_RULINGS_FOR_VICTOR_20261017.md` after the plain explanation of 2026-10-26 |
| D43 | **Funding first; a paper with the demo once the PoC works.** (a) The top priority is to obtain funding for continuing the work as soon as possible — grants, other funding sources or publications, whichever gets there fastest and best; the coordinator researches the routes and brings one ranked plan (research under `results/zk60_funding_20261028/`). (b) Once the proof of concept works, write and publish a paper on the ZKP technology built here at a prestigious venue, together with the PoC demo, so the technology enters the literature for others to use. Working notes (coordinator, not rulings): in this field the top venues are mostly conferences (security and cryptography), with an IACR ePrint preprint as the fast public form; publication is prior art, so any patent filing must come first — Victor's call, flagged 2026-10-28 21:02 UTC. Neither part changes D1, D13, D27, D33, D36 or any security claim | **product direction (Victor)**; plan written 2026-10-28 21:23 UTC: `docs/zkmatrix-poc/ZK60_FUNDING_PLAN.md` (drafts for Foresight, due Oct 31, and YC W27, due Nov 2, in `results/zk60_funding_20261028/`); **ruled by Victor 2026-10-28 21:24 UTC (console):** (1) **file a US provisional patent before anything is published** (preprint, open-source release) — the private YC / Foresight applications are not blocked by it; (2) **open-source scope for grants that require it = the verifier + the specification + the benchmarks** (open-core; the prover stays the product). Still open: when the company is formed. **Addendum, Victor 2026-10-28 21:39 UTC (console):** "apply for multiple avenues of funding just in case some do not pan out … consider all options even if they might be a little out there" — apply broadly in parallel (all four of this week's applications plus every further fitting route), and widen the search to unconventional sources; a second research wave runs under `results/zk60_funding_20261028/wave2/` | 2026-10-28 21:01 / 21:02 | Victor (console: "once we have a working proof of concept, I want to see about writing and publishing a paper on the ZKP technology … together with the proof of concept demo"; then "the top priority is to find funding for continuation of this work … The priority is to achieve funding for this as soon as possible") |
| D44 | **Install the S8 guard swap-rule fix.** The live `scripts/zk60_resource_guard.py` (87138bda…) is replaced by Sol's candidate `results/zk60_sol_20261026/guard-s8/zk60_resource_guard.py.candidate` (88af4c63…). It changes one admission rule: while swap use is over 1 GiB, refuse only if MemAvailable < need + 1 GiB margin + all swap in use (before: refuse whenever swap use was over 1 GiB). Coordinator review: `results/zk60_guard_fix_20261021/S8_REVIEW.md` (accept, with conditions). The install follows D42's S3 procedure: drain and holds, `.orig` backup outside /tmp, atomic replace, both static consumer pins updated, the official suites (45 with the swap fixture changed in the official file, plus 31, plus the 9 S8 policy tests) on the host without systemd skips, FIFO off, a note in `ZK60_RESOURCE_PROTOCOL.md` that the guard cannot see Windows host memory, and rollback on any failure | **operations ruling (Victor)**; **done 2026-10-29 00:33:31 UTC** (Sol, attempt 2; attempt 1 at 00:24 aborted on a test-runner import path and rolled back cleanly). Host preflight clean; official 45 + S3 31 + S8 9 + consumer suites 8 / 13 / 14, all with zero skips; both static pins = 88af4c63…; FIFO off. Coordinator re-verified the live hash, the pins, `status` / `check` and the protocol note at 00:33:59; window 00:10–00:34 UTC, holds removed | 2026-10-28 23:50 | Victor (console: "Go ahead and install the guard swap-rule fix") |
| D45 | **The four classifier-proof rulings (from the classifier design's adversarial check, `results/zk60_token_io_r1_20261017/classifier/check/CHECK.md`).** **(1) Content length is public:** a proof reveals the post's length in tokens, besides the verdict, model and policy. Hiding the length is a later, costlier variant. **(2) One fixed policy list, one threshold each; an item is never re-proved under a different policy or threshold** (each extra policy is another yes / no question about the hidden content). **(3) The proof is linked to the post (amends D23 for classifier runs):** the proof's sealed input fingerprint is stored with the post and anchored on-chain (D39), and the app keeps the opening so anyone given the post's text can check the link. Accepted consequence: whoever holds an opening can prove which content was posted. **(4) Fail closed:** a post without an accepted proof is not published and is shown as "could not be verified", never as safe | **product rulings (Victor)**; consistent with D1 (P1) and D37–D41. Token round 14's short-item support (T < T_pad) stays within (1) | 2026-10-29 01:04 | Victor (console: "1) yes, 2) yes, 3) yes, 4) yes"), answering the open item of 2026-10-21 03:00 UTC in `ZK60_RULINGS_FOR_VICTOR_20261017.md` |
| D35 | **Next-token statement at calibration `pg_rot1_b4_T32_cal128`: which block-layer evidence carries from D33's calibration.** The calibration-SENSITIVE block controls were run at b4 inside the token captures and fire (NC-1: `sh_z` moved, fails exactly at slot 14; NC-2: the frozen-calibration fallback fails exactly at slots 2, 14, 15, 16, 18; NC-3: the cross-check; NC-4: a per-layer table swap), and the absorbed calibration word recomputed from the b4 export and the named embedding / head tables equals the statement header in 5 of 5 cases and 10 of 10 captures (gate round 10, PR4-9, tools v16). The remaining block control families — CT, GQ, P, M, X, C, CH, M9, the pin controls and G-10 — test the tools and the block shape, not the calibration constants; they were exercised at pg_rot1 on the same block shape and tools, and are recorded as carrying to b4. The token run's own integrity controls (TC-1..TC-12, J-1..J-3) fire on all ten token captures. In plain words: the parts of the privacy checks that depend on the calibration numbers were re-run at the new calibration; the parts that only test the machinery are not repeated | **statement-evidence note (security owner); not a privacy acceptance** — lapses if a carried family is found to read a calibration constant, or the block shape or the tools differ between the D33 runs and the b4 captures | 2026-10-20 04:34 | Claude (coordinating session as security owner), on privacy review round 4 PR4-9 ("can carry, if the owner records it") and gate round 10 (`results/zk60_gate_tinyllama_20261017/round9/PRIVACY_STATEMENT_NEXT_TOKEN_T32_DRAFT.ADDENDUM-20261020.md`) |
| — | RTX 5090 install (an action, not a ruling; the 600 W bound was ruled on 2026-09-04) | **go**; date, machine and host RAM still to be named | 2026-09-19 | Victor (Telegram 11:50) |

Operational rules (detached heavy runs, the shared-box lock, command hygiene)
live in `CLAUDE.md`; they are not repeated here.

---

## D1 — Privacy scope (standing since 2026-09-09)

**Decided.** The first proof of concept, P1, hides inputs, outputs and every
intermediate activation from the verifier and from every public artifact;
model weights may be public. The full version, P3, also hides weights.

**Why.** This is the product: a regulator or auditor can check that an
approved model produced an answer without learning the prompt or the answer.

**In practice.** Public-IO demos are diagnostics, never deliverables. A
component that opens or publishes an endpoint value is not P1. An unresolved
privacy argument is work to do, not a reason to shrink the private set.

**Reopens only** on an explicit new instruction from Victor.
Source: `ZK60_PRIVACY_REQUIREMENTS.md`.

## D2 — Two lines (standing since 2026-09-17)

**Decided.** Run an implementation, review and test loop until a workable
private MVP exists, using a RISC Zero zkVM re-execution of the exact integer
block as the intermediate. Keep the custom-PCS prover (hashline) as the
route to the model-scale throughput target.

**Why.** The custom line's privacy argument still has open obligations (D8)
and its private attention is unbuilt; the zkVM route sidesteps both because
its proof never opens the endpoint commitments. The zkVM route cannot reach
the throughput target: re-executing an 8B model is on the order of 10^13
cycles, so it is a functional intermediate and a differential oracle, not
the product's prover.

**In practice.** "Tiny block" claims come from `zkvm-block/`; speed claims
come from hashline. Neither line's results are quoted as the other's.
The exact-integer kernel (`private-block-kernel/`) is shared by both.

**Reopens** if the zkVM route's assumptions (D3–D5) become unacceptable, or
if the custom line's privacy acceptance lands first.
Sources: `ZK60_MVP_LOOP_20260918.md`, `ZK60_ZKVM_REVIEW_DISPOSITION.md`
(branch `zk60-mvp-fable`), `ZK60_FABLE_LANE_HANDOFF.md`.

## D3 — About 97 bits of conjectured soundness accepted for the zkVM intermediate (2026-09-18)

**Decided.** The zkVM intermediate's proofs are accepted at RISC Zero's
shipped security level, about 97 bits conjectured for 2^20-cycle segments
(95 at 2^24) and roughly 100 bits for the BN254 Groth16 layer, instead of
the project's 128-bit target. This is a **recorded deviation**, not a change
of the target: the target stays 128 bits for the product.

**What the number means.** "Bits" measure the work a forger needs: about
2^97 operations to produce a proof of a false block result. "Conjectured"
means the figure rests on a widely used but unproven conjecture about the
FRI protocol (the "toy problem" conjecture from ethSTARK); the bound that is
actually proven is lower and must be read off the build (see below). For
comparison, hashline's own default profile is 106 bits and its compact
lever 95–98 (D10), so the whole project is currently below 128.

**Why accepted.** The parameters (50 FRI queries, rate 1/4, the digest
width) are compile-time constants baked into RISC Zero's recursion circuits,
control roots and Groth16 circuit; no setting raises them. Reaching 128 bits
would mean a different proof system. For an intermediate whose purpose is a
complete private block, not a deployed product, the shortfall is accepted.

**In practice.**
- Every document that mentions the intermediate's security says
  "about 97 bits conjectured (RISC Zero default), accepted per D3", never
  "128 bits" and never "secure" without the number.
- The first real proving run records the build's own two figures,
  `conjectured_security` and `proven_soundness_error`, from
  `risc0-zkp/src/prove/soundness.rs` (`RUST_LOG=risc0_zkp=info`), and this
  entry is updated with them.
- Segment size stays at 2^20 or below (larger segments lower the figure).

**Reopens** when a proof system at or above 128 bits is adopted (the custom
line, or a future RISC Zero circuit version with different parameters), or
if the proven bound recorded from the build is unexpectedly low.
Sources: `risc0-zkp-3.0.5/src/lib.rs:40–46`, `src/prove/soundness.rs:15–35`;
`ZK60_ZKVM_REVIEW_DISPOSITION.md` §1–§2; vendor page
`dev.risczero.com/api/security-model`.

**D3 measurement addendum, same day.** The installed upstream calculator
has now been called directly with each actual circuit's tap set. At the
integration's trace limit `2^18`, rv32im reports **98.6424 conjectured bits**
and **45.3014 proven list-decoding bits**; recursion at its fixed `2^18`
reports **99.7587** and **46.0184**, respectively. These are per-circuit
calculator outputs, not a composition/whole-proof bound and not captured
prover telemetry. At `2^20`, the rv32im outputs are 97.1420 and 41.5670.
The accepted conjecture-based interpretation stays explicit. Source hashes
and all rows are in `results/zk60_loop_20260918/risc0-security.json`;
`zkvm-block/security/` invokes the installed Rust functions without private
data. The first proof ran with debug logs disabled; contrary to the earlier
command hint, this crate emits the per-proof figures at **debug**, not info.

## D4 — Groth16 trusted setup accepted for soundness (2026-09-18)

**Decided.** The public artifact of the zkVM intermediate is a Groth16
receipt, whose soundness depends on RISC Zero's trusted-setup ceremony.
This dependency is accepted.

**What a trusted setup is, in plain words.** Groth16 proofs are tiny and
fast to check because the verifier holds a fixed "reference string": a set
of elliptic-curve points computed once from secret random numbers. Whoever
knows those secret numbers can forge a proof of any false statement; nobody
can forge if they were destroyed. A ceremony makes many participants
contribute their own secret one after another and destroy it; the final
string is safe as long as **at least one** participant was honest. RISC
Zero ran such a ceremony for its STARK-verifier circuit and ships the
resulting verifying key as constants.

**What it does and does not affect.**
- *Soundness*: a colluding ceremony (every participant dishonest) or
  subverted ceremony software would allow forged receipts, i.e. a fake
  proof of a block result that never happened. That is the risk accepted.
- *Privacy*: **not affected.** Groth16's zero knowledge holds for any
  well-formed reference string, even one whose secrets are known. Inputs,
  outputs and activations stay hidden regardless of ceremony honesty.
- *The inner STARK*: unaffected either way; it has no setup.

**Why accepted.** The alternative, a succinct STARK receipt, has no setup
but its hiding rests on the vendor's STARK blinding, for which the vendor
itself states no finished mathematical argument (and the segment-level
prover adds no blinding at all). Groth16 trades a soundness assumption the
project can name and pin for a privacy argument it can cite (Groth 2016,
Theorem 3). For a private-block intermediate, privacy is the property that
matters most.

**In practice.**
- Pin and record: ceremony key `2024-05-17.1`, SHA-256
  `69c6056451ea814b37e30ccbc44639dbaafef73540cbfbff6ec7e68e2d325735`;
  verifying-key constants in `risc0-groth16-3.0.5/src/verifier.rs`;
  default verifier-parameter digest
  `73c457ba541936f0d907daf0c7253a39a9c5c427c225ba7709e44702d3c6eedc`;
  prover image manifest
  `sha256:7f173963196570b7a71816ed70565a4579264c5d2e3e0ecb028102538ad0e331`.
- Run RISC Zero's published ceremony verification once
  (`snarkjs zkey verify` against the published R1CS hash) and record the
  outcome here; until then the well-formedness of the string is an
  assumption, not a checked fact.
- The verifier binary embeds its verifying key and control roots; it never
  takes them from a receipt.

**Reopens** if RISC Zero publishes a new ceremony or circuit (new key), if
the ceremony verification fails, or when the product's prover no longer
needs a setup (the custom line is transparent).
Sources: `ZK60_ZKVM_SOURCE_REVIEW.md` (CRS and prover-randomness chain),
`ZK60_ZKVM_REVIEW_DISPOSITION.md` §1, §3; vendor page
`dev.risczero.com/api/trusted-setup-ceremony`.

## D5 — Receipt kind: Groth16 only (2026-09-18)

**Decided.** Only a Groth16 receipt leaves the prover. A composite receipt
is never public: its per-segment claims carry memory-image roots at every
split and its segment count reveals cycle counts, and the rv32im segment
prover adds no blinding rows in circuit 4.0.5. A succinct receipt is used
only as explicitly experimental evidence while the Groth16 wrap is being
brought up; it is never presented as a private artifact.

**In practice.** The verifier matches the receipt kind explicitly before
anything else, refuses dev mode by construction, and is built with
`default-features = false` (the crate's default features include the
Bonsai upload path). Fake receipts are refused always.

**Reopens** only with a reviewed zero-knowledge argument for the succinct
receipt at the shipped parameters.
Sources: `ZK60_ZKVM_REVIEW_DISPOSITION.md` §1–§2, §4;
`ZK60_ZKVM_SOURCE_REVIEW.md`.

## D6 — Groth16 proving path on this box (in progress)

Docker is not installed; the crate's Docker path cannot run. Codex is
extracting the native prover tools (`stark_verify`, `prover`, the proving
key) from the official image at the pinned manifest digest and running
them directly, with each tool's SHA-256 recorded (`scripts/zk60_zkvm_demo.py
--native-tools`). The CUDA Groth16 component is the alternative, not
installed; the 8 GB laptop GPU and the box's VRAM-freeze history make it
the second choice. This entry closes when the first Groth16 receipt
verifies and its tool hashes are recorded.

**Closed 2026-09-18 19:18.** The first Groth16 receipt (785 bytes, SHA-256
`6c67e05c…32e7`, image `8d74aab3…98d9`) was produced by the native tools
in 197 s and verified independently, by Codex's stage and again by the
security owner in a fresh process; the inner succinct receipt and seven
corrupted variants are refused. Tool provenance: `groth16-native-files.json`
under `results/zk60_loop_20260918/block-integration/`; public artifacts
retained in `…/groth16_public/`. Hardening items from the source review
(`ZK60_ZKVM_BLOCK_SOURCE_REVIEW_FABLE.md`) are open but not blocking.

## D7 — New endpoint and weight identity profile (implemented, ruling pending)

The zkVM route commits endpoints as salted SHA-256 hashes inside a fixed
public journal (Codex's implementation: 144 bytes; Fable's proposal: 260
bytes, superseded by the implementation), and identifies weights and
calibration by digests over the bytes the guest uses. Old PCS endpoint and
weight roots have no meaning here; a chain of blocks is checked by journal
equality, not by a seam argument. **Pending:** Victor's acceptance of this
profile as the P1 statement for the intermediate, and a new approval record
for the model digests. Until then the artifact is "complete-block
experiment", not "private block".

**Ruling (Victor, Telegram, 2026-09-19 11:50): accepted, with three
qualifiers written into the acceptance.** In plain words: for the zkVM
line, "private" now officially means that the prompt and the answer appear in
the public record only as SHA-256 fingerprints, each mixed with a 32-byte
secret salt, inside a fixed 144-byte record, and the model is named by
digests of the exact bytes the program used. The two verified Groth16
receipts (one block; the two-block token model) stop being "experiments"
and may be called **zkVM line, private under D3, D4, D5 and D7**. The
qualifiers, which travel with every such claim: (1) the hiding of an endpoint
is the secrecy of its salt under SHA-256 — in the toy token model the answer
is one of only 32 values, so whoever learns the salt learns the answer, and
the model library still accepts an all-zero or repeated salt (hardening item
H5 of the token source review; honest runs draw fresh salts); (2) the
program's identity (its image ID) depends on the directory it was built in,
so any approval record says "locally built, unreproduced" until a container
build exists; (3) timing is declared leakage — the secret scan and the
constant-cycle check were run for the block program on nine inputs (a
sample, not a proof of constant time) and not yet for the token program.
What this does **not** do: it is the definition of the claim, not a finding
that a cryptographic analysis was performed beyond the reviewed Groth16
premises; and the second half of D7, the approval record for the model
digests, is still to be written and cannot be credible before qualifier (2)
is fixed. Pages: `ZK60_RULINGS_FOR_VICTOR.md` §2.

## D8 — Caller-fixed endpoint roots on the custom line (corrected 2026-09-18)

**Standing obligation.** A proof on the custom line must be simulatable for
endpoint roots the caller fixed, with the distinguisher allowed to keep
prior public history (`ZK60_ENDPOINT_SIMULATION_MODEL.md`).

**Correction.** The round-2 memo on `zk60-mvp-fable` claimed this is met by
programming one oracle point per root. Codex's review showed that any
previously published authentication path under that root reveals the
honest top pair (the last sibling on the path), so the programmed point is
detectable as a second preimage. The claim is **retracted for any root with
a prior public opening**. What stands: for a root with no prior opening the
argument is unaffected, and the `/2` protocol's own pad budget means a
second opening of the same endpoint commitment is outside the protocol
anyway (the consuming API enforces one opening). The obligation therefore
reduces to stating the experiment for unopened roots and keeping one
opening per commitment; that restatement is the security owner's next
custom-line task, not a closed item.

**In practice.** No document says the external-root obligation is closed.
The joint-view tools and the attention construction remain valid
engineering; they do not establish whole-proof privacy.
Sources: `ZK60_JOINT_VIEW_REVIEW_20260918.md`; `ZK60_MVP_JOINT_VIEW.md`
§1.1 with its correction note.

## D11 — Technical correction to D8 and profile clarification (2026-09-18)

The historical D8 text is retained above, but its statement that one-use
ownership reduces the privacy experiment to unopened roots is not accepted.
An ordinary authentication path or root-child hash query can exist before
the sole accepted `finish`; the consuming API does not erase that history.
The general caller-fixed-root obligation stands unchanged.

Two native PCS openings at the actual endpoint geometry recover all 512
data words; fresh-owner controls do not. This confirms that consumption is
necessary for that opening design, not that the remaining one-use proof is
zero knowledge. A forced-challenge counterexample also refutes the new
budgeted simulator's universal per-use rank premise, without establishing
an efficient attack on randomly sampled challenges.
[Evidence and limits](ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md).

D7's phrase "a chain of blocks is checked by journal equality" is a proposed
integration description, not an implemented property. The block profile's
input/output roles are distinct, so its roots cannot be equated directly
across blocks. The next separate token-model guest recomputes both blocks
and their hidden seam inside one program; the public policy binds its
complete model and endpoints. This clarification changes no user ruling.

## D12 — How a complete private block is composed on the custom line (construction rule, 2026-09-19)

**In plain words.** A transformer block is attention followed by a
feed-forward part. Between them sit hidden values (the first residual
`xres1`, the second norm's output `nm`, the feed-forward output `z16`). The
tempting way to join the two existing components is to commit such a hidden
value once and let both proofs open that one commitment. That is exactly the
configuration D11 records as broken: at the actual endpoint geometry (7 rows
of 256 columns) two openings recover all 512 hidden words. This rule forbids
it and fixes the frame everything else is built in.

**The rule.**

1. **No commitment is opened more than once, anywhere in a composed block.**
   The double-opening configuration of
   `ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md` is not permitted as a seam,
   as a convenience, or as a test shortcut that could be mistaken for one.
2. **A block is one proof under one transcript with exactly two external
   endpoints**: its hidden input `x_in` and its hidden output `xres2`. Two
   separately finished component receipts glued by a shared root are not a
   block.
3. **Hidden intermediates never get a caller-fixed endpoint commitment shared
   by two proofs.** `xres1`, `nm` and `z16` live only on commitments the
   prover generates inside that one proof. How the two halves are tied
   together there (an equality between the two components' own commitments
   with reserved mask pairs and a seam slot, as
   `ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md` line 99 specifies, or a single
   shared layout with no seam at all) is settled in the block construction
   memo, with the simpler form built first and the other documented with
   what it is worth.
4. **The second norm must prove that its output is in the int8 class.** The
   feed-forward prover proves no range on its own input (verified in
   `hashline/src/layer.rs`: the lookup list covers the activation, the two
   int16 planes and the output, never the input plane), so without this the
   composed statement would admit an out-of-class feed-forward input.
5. **Declared endpoint scales must be tied to the approved calibration**
   before any seam compares them. Today the tag proves nothing, and the
   attention fixtures declare `(-3, -3)` where the calibration has
   `e_r = e_r1 = 0`; a tag-equality check would pass on a factor-of-8
   mismatch.

**What this does not do.** It is restrictive only. It does not discharge D8
or D11 for the block's two external endpoints, it accepts no privacy
property, and it makes no speed claim. The joint analysis for the extra seam
groups has never been done and remains owed at the block-scope privacy gate.
Source: `ZK60_PRIVATE_BLOCK_COMPOSITION_GAPS.md` on branch
`zk60-attention-compile` (`c2e010e`), sections 3, 4 and 5; the two code facts
in items 4 and 5 were re-checked by the security owner in the source.

**Follow-up, same day (03:01): the construction inside this rule is accepted
as the design to build.** Of the two forms item 3 left open, the simpler one
is built first: no seam at all, the attention construction grown into the
whole block in a new module, so every hidden intermediate sits on one proof's
own commitments. The other form (an equality between two components'
commitments) is deferred with its cost written down; it is what 8B will
probably need because it alone keeps the GPU feed-forward prover, and the two
measurements that would force it are named. The design was drafted and
independently checked by delegated agents, with the rank and slot tools run
on a paper description of the whole block (nothing disclosed, every negative
control fires) and 22 errata made binding. Still not a privacy acceptance.
Ruling and conditions:
`ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md` on `zk60-attention-compile`
(`e5962d2`).

## D9 — `fp()` reduction bias (accepted as stated, 2026-09-19)

Challenge words are 128-bit draws reduced mod p, each within 2^-96 of
uniform; over a proof this is about 2^-75 at A00. Either accept the term
in the privacy bound or re-freeze fixtures with rejection sampling (a
byte-changing change). Not gating any current work.

**Ruling (Victor, Telegram, 2026-09-19 11:50): accept the term as stated.**
In plain words: the prover's random masks are very slightly uneven, and the
final privacy statement will read "indistinguishable up to about 2^-72" (one
part in 5 × 10^21 at the 8B shape; 2^-75 at the tiny shape, 2^-72.9 at 125M)
instead of being exact. Nothing is re-frozen. **Wording correction to the
entry above**, from the source it cites (`ZK60_FABLE_TRANSCRIPT_REVIEW.md`
§B.7): the term comes from every *mask and pad the prover draws*, not from
the challenges, which the verifier reduces identically in both worlds and
which contribute nothing; and it is a **privacy** term, not a soundness
term — it does not make a false proof easier to forge. The bound already
carries a larger residual of about 2^-62 at the same shape, which is why
removing this one would not have made the statement unconditional. If an
auditor ever requires it removed, the change is one line in `ZkRng::fp`
(rejection sampling) plus a re-freeze of the zero-knowledge fixtures, and it
should be done after any lane that leans on the two frozen zero-knowledge
digests has landed. Pages: `ZK60_RULINGS_FOR_VICTOR.md` §6.

**Verification note (security owner, 2026-09-19 21:50): the accepted figures
are right; "2^-64" and "2^-96" are two different quantities, not a
discrepancy.** The draw is a 128-bit integer reduced modulo
`p = 2^64 − 2^32 + 1` (`zkp-core/src/rng.rs:72–77`, whose comment says "bias
2^-64"), and one review (O10, finding F10.4) read that as the per-draw term,
which would make the accumulated residual about 2^-51 instead of 2^-72. Exact
arithmetic settles it: `2^128 mod p = p − 2^32`, so all but `2^32` of the
`2^64` residues occur equally often and those `2^32` occur once less. The
**total statistical distance of one draw from uniform is exactly 2^-96**; the
**relative bias of a single outcome is 2^-64**. A privacy bound sums
statistical distances, so the per-draw term is 2^-96 and the accumulated
figures above stand: 2^-75.0 at 2^21 draws, 2^-72.9 at 2^23.1, 2^-71.7 at
2^24.3. This is a property of the Goldilocks prime specifically — a generic
64-bit prime would give about 2^-66 per draw — so it must be re-derived if
the field ever changes (D14).

## D10 — Compact-PCS proof-size lever (declined, 2026-09-19)

Drops a Mistral-7B layer's proof from 38.7 MB to 1.94 MB at 4.4x the prover
time and 95–98 bits instead of 106 (`START_HERE.md`, lane AF). A soundness
ruling for Victor; not compatible with the GPU path or zero knowledge yet.

**Ruling (Victor, Telegram, 2026-09-19 11:50): declined — keep the
Ligero-class commitment.** His message put it as a question ("5 seems to be
a no go?"); the recommendation in front of him was "no", it was confirmed
back to him the same minute, and he can reverse it with two words. In plain
words: the compact format would shrink an 8B proof from 1.23 GB to about
62 MB, but it **cannot run in private mode at all** (`--pcs compact --zk` is
refused by the prover), it does not live on the GPU, it multiplies proving
time by about 4.4, and it lowers soundness from 106 bits to 95–98. The
product is private (D1) and the goal is speed, so it pays on neither axis.
The proof-size budget in the target contract therefore stays unmet and
stays a recorded gap. **Correction, 2026-09-19 12:10 (security owner):** the
first version of this entry offered "capping the Merkle paths, about −29% of
bytes" as a free improvement. That figure was counted for the *compact*
commitment (157 queries across about ten trees,
`PROVING_CHANNEL_OPTIONS.md:244–248`); on the Ligero-class 1.23 GB proof the
Merkle paths are about **1%** of the bytes, so the cap is worth about 1%
[COUNTED, `ZK60_L4_FEWER_HASHED_BYTES_MEMO.md`]. There is no free lever on
proof size on this commitment; the ruling is unaffected, because its reason
is that the compact format cannot run privately. The
costed memo of D14 must say what its lever does to proof size as well as to
time. Pages: `ZK60_RULINGS_FOR_VICTOR.md` §5.

## D15 — "106 bits" is per opening; the whole 8B proof is about 94 (technical clarification, 2026-09-19)

**In plain words.** Each time the custom line's prover opens a commitment, a
cheating prover slips past the check with probability about 2^-106: that is
(3/4)^256, from 256 opened columns at encoding rate 1/4 under the proximity
rule the code assumes (`zkp-core/src/pcs.rs:17–19`; reproduced exactly by the
D14 memo). D3 above and several status pages quote that 106 as "hashline's
security level". **It is the level of one opening, not of a proof.** An 8B
proof makes about six openings per layer over 32 layers, and a forger needs
only one of them to fail, so the chances add up: the security owner's own
2026-09-08 projection puts the commitment term of the whole proof near
2^-98.7 and the lookup term near 2^-94.2 — **about 94 bits for the whole 8B
proof, before any cap from the hash** (`ZK60_FABLE_SECURITY_OBLIGATIONS.md`
§5, the deployment row; a PROJECTION of the same relations, not a measured
artifact). The tiny fixed block is a different object: about 2^-110 over its
two commitments, and that figure does not scale up.

**In practice.** Any statement of the custom line's security at model scale
quotes the whole-proof figure, labelled a projection, next to the zkVM
line's "about 97 bits conjectured" (D3): **at 8B both lines are below 100
bits today**, against a 128-bit target. Raising it is possible — more opened
columns, a lower rate, or batching openings across layers — and each costs
proof bytes or prover time; the D14 memo prices the first two.

**What is not decided here.** Whether the product's target is a per-opening
or a whole-proof figure, and how many bits, is Victor's ruling (the D14
memo's question G.0-2). It is not urgent for a tiny-block MVP; it becomes
binding before any byte freeze at model scale, and it decides whether the
rate half of the D14 lever is a gain or a net cost.

**Correction, 2026-10-17 19:40 UTC (technical clarification; soundness
recount `results/zk60_soundness_recount_20261017/RECOUNT.md`, [COUNTED]; the
pad-dilution observation came from the token-I/O design's adversarial check).**
The 2^-106 above holds only where a commitment's encoded rows have rate exactly
1/4. Every private-block commitment uses the zero-knowledge encoding, whose code
is RS(n + Q, n·inv_rate) (`zkp-core/src/pcs.rs:565`), so its distance is
1 − (n + Q)/(n·inv_rate), not the header's 1 − 1/inv_rate (`pcs.rs:16–19`,
cited above). With Q = 256 at rate 1/4 one opening of A, H, a boundary or an
endpoint is 2^-103.69 at row width 2^12 (TinyLlama T32), 2^-104.97 at 2^13
(TinyLlama T64, Llama-3-8B T32), 2^-105.61 at 2^14 (TinyLlama T128, 125M) and
2^-106.09 at 2^16. The masking commitment M (RS(1024, 4096)) and the frozen toy
stay at 2^-106.25. The δ/3 proximity regime (Ligero lemma, independent uniform
columns) is unchanged and correct. A native private run opens 4L + 1
commitments (A, H, M per block, L − 1 boundaries, two endpoints), not six per
layer. Whole-run figures of the registered trained stacks, lookup term under
the R14 convention 4N/|F| (derived N/|F| in brackets): TinyLlama T32 2^-97.1
(2^-97.4); T64 2^-97.2 (2^-98.2); T128 2^-96.5 (2^-97.9); Llama-3-8B T32
2^-96.8 (2^-97.7) — 0.1–1.2 bits (0.2–1.8) weaker than the same accounting at
2^-106.25 per opening. **From T64 up the lookup term, which grows with context
length, sets the figure**; an 8B T512 geometry would be about 2^-93 (2^-95)
[projection]. The 125M twelve-block figure of about 2^-97.5 (D12a) already used
the real distance and stands. The token-I/O design's stack term (2^-98.7 at 8B
T32) is replaced by these figures. Raising column checks and pads to 263 / 260
/ 258 at widths 2^12 / 2^13 / 2^14 restores 2^-106.25 per opening for +0.3% to
+1.9% of receipt bytes and a new statement version, but lifts no whole run
above about 97 bits from T64 up. Against D3's 97 bits (accepted for the zkVM
line only): TinyLlama T128 is below 97 under R14 with or without this
correction; Llama-3-8B T32 moves from 2^-97.1 to 2^-96.8. The whole-proof
target itself remains Victor's question G.0-2; a costed options memo is being
prepared.

**Lookup-term convention, 2026-10-17 20:10 UTC (technical clarification;
security owner, after an independent check
`results/zk60_soundness_recount_20261017/check_logup/CHECK.md`, [COUNTED]).**
The private block's LogUp (β, γ, α in Fp2 drawn after the A and M roots; free
base-field multiplicities with the table and padding rules; committed helpers;
the value-0 sum claim) has soundness error **(N + 2303)/|F| per block**, by the
logarithmic-derivative criterion (Haböck, ePrint 2022/1530; p > N holds with
N ≤ 3.2·10^8 per block). The paired-helper "both members equal α" event (R13)
is absorbed by a counting step (each such value is looked up at least twice);
without it the bound would be (2N + 2303)/|F|. R14's 4N/|F| is a valid upper
bound, 2.0 bits looser, and is **replaced by the derived bound as the project's
convention from today**. The bound is within about 3.3–3.9 bits of tight (an
explicit equal-limb strategy). Whole-run figures under it (union over blocks):
TinyLlama T32 2^-97.4, T64 2^-98.2, T128 2^-97.9; Llama-3-8B T32 2^-97.7; an
8B T512 geometry about 2^-94.7 [projection, unregistered profile]. The constant
is 2303 (the recount script's 1536 omits the zero-multiplicity table pole; no
printed figure moves). Two remarks not adopted: a per-first-cheating-block
composition might be about 5 bits better at 32 blocks (argument not written);
all figures are interactive, and Fiat–Shamir grinding over the A randomness
makes the per-block figure a per-try rate.

## D16 — The private block's norm before it is widened (construction rule, 2026-09-19)

**In plain words.** A norm divides by a square root. The proof does not
compute the square root; the prover supplies it (`D`) with two helper numbers,
and the verifier checks algebra that pins it. Over a prime field that algebra
has a second solution nobody intended — `D` replaced by `k + (p−1)/2` — unless
something forces `D` to be a small non-negative integer. In the project's
older public-IO attention prover nothing does (obligation R09): the alias is
excluded at the tiny profile only because its remainders happen not to fit
two 16-bit limbs, and **any profile with three remainder limbs — which is what
an int24 residual at width 4096 needs — accepts an all-zero norm output.**

**What was established today** (lane `zk60-private-norm-range`, pushed;
`ZK60_PRIVATE_NORM_RANGE_OBLIGATION.md`; test-only Rust, 41 tests pass, 5
new). The **private** block does not share that gap. It range-proves `D`
directly: `d = l0 + 256·l1 + 65536·l2` with every limb looked up in the 8-bit
table (`private_block/argument.rs:583–593`, `layout.rs:314–315`), for both
norms. The alias was built against this module's own relations and is
**refused by the verifier at the fixed profile by that range fact**, not by a
width: with honest limbs the zero-check slot rejects; with limbs made to
reconstruct the alias — so that every relation of all 23 slots holds in the
field — the byte lookup rejects. Both catches were predicted before they were
measured. Its remainders are proved in an exact window, so there is no
R10-style slack either.

**The rule, binding on any widening of the private block's geometry:**
1. `D` keeps a direct byte-limb range pin with `⌈log256(Dmax + 1)⌉` limbs:
   three today (Dmax 2^17) and at width 4096 with an int16 residual (2^21);
   **four at width 4096 with an int24 residual (2^29).**
2. The two isqrt witnesses `a1`, `a2` get the same treatment: their present
   exclusion **lapses at four limbs** (the alias's `a1` is about 2^30).
3. Never more than four limbs on any of them: `(2^32 − 1)² + (2^32 − 1) = p − 1`
   exactly, so four is the last count at which the square relation cannot wrap.
4. The remainder window stays exact and its coefficient is rewritten for the
   new width; the present window keeps about one bit of margin at int24 /
   4096 and less than a tenth of a bit at 8192, and `1 << (32 − NORM_WRHO)`
   (`layout.rs:321`) underflows above 32.
5. The audit that every committed value under a non-unit coefficient is
   independently range-proved is re-run on the widened layout, and the
   wraparound premise at `layout.rs:281–309` is re-derived.
6. The alias tamper tests of this lane travel with the module and must reject
   at every widened profile before it is used.
**Cost at the first widening:** 6 more claim sites, 12 more `A` rows
(455 → 467), 96 proof bytes, no new lookup, table, sumcheck or degree; a new
statement version. **Not covered:** the widened profile was analysed on paper
and by arithmetic tests, not run through the verifier, because reaching it
needs production changes this lane was not allowed to make; the public-IO
prover's R09 is unchanged and still owes the fix verified on 2026-09-08.

## D17 — Hiding endpoints beyond the tiny shape (construction rule, 2026-09-19)

**In plain words.** The private feed-forward hides its input and its output
by putting each in its own sealed commitment and proving, without opening
either, that the sealed plane equals the plane inside the proof. Today that
equality is checked over **one block** of the plane. At the tiny shape a
plane is one block, so that is the whole plane and the code is sound. At any
shape with several blocks, simply raising the size limits would leave the
rest of the plane **unbound**: an independent check built the attack (a
sealed plane honest on the first block and arbitrary elsewhere) and showed
that nothing in the present code rejects it; the existing tamper test would
not catch it either, because its one perturbed position lies in the first
block.

**The rule.**
1. **Any entry point that accepts a shape other than the pinned tiny one binds
   the whole plane**, through the batched multi-block seam, at every width.
   No width is exempt: a plane has one block only when the model width is a
   power of two no larger than 4096, so widths 768, 5120, 6144, 8192, 12288
   and 16384 all have several.
2. **The tiny private-IO path stays byte-frozen.** Its constants are hashed
   into its digests and fix its endpoint roots. Everything new is additive: a
   general spec with its own digest domain, a new profile tag, a new entry
   pair beside the pinned ones.
3. **Pair exclusivity is enforced in code on this path**, and a joint-view
   analysis of a captured receipt at the widened shape is a hard gate before
   the path is used for any measurement that is quoted.
4. **Naming.** A feed-forward-only private pass over 32 layers has **64
   endpoint roots fixed by the caller, not a chain** — attention, two norms
   and a residual sit between consecutive feed-forward blocks — and every one
   of them carries the open D8/D11 obligation. It is not a block under D12,
   and D13's "blocks" means complete blocks. **It is a cost vehicle and is
   never called P1**, in code, documents or status pages.

**What it costs** [COUNTED, none of it measured]: at one Mistral-width layer
about 274 more committed rows (1.6%) and 2.3 MiB of proof (6%); the whole-proof
soundness moves by 0.03 bit. **What it does not do:** it establishes no
privacy property and leaves D8 and D11 exactly where they were. Ruling and
the 19 binding errata:
`ZK60_PRIVATE_ENDPOINTS_AT_SCALE_DISPOSITION.md`.

## D8/D11 — note of 2026-09-19: a restatement was attempted and NOT accepted; the obligation stands

A delegated draft restated the obligation as a game and recommended
discharging part of it by restricting it to endpoint roots "first published
together with the proof that consumes them". An independent check, told that
the last confident closure was retracted within days, found the reduction
**circular** (its own restriction assumes the conclusion) and found that it
**excludes the party who fixed the root from ever being the adversary** — and a
regulator who seals an input in advance is exactly that party. The security
owner did not accept it. **D8 and D11 stand as written.** What is now on the
record (`ZK60_D8_D11_RESTATEMENT_DISPOSITION.md`): in today's code the
committer **is** the prover and an endpoint owner cannot leave the process, so
for every artifact that exists the caller-fixed scenario does not physically
arise and the standard game applies; a commitment opened twice is dead at this
geometry, so one opening per commitment must be kept everywhere and a verifier
cannot check that from the bytes; **separately finished private proofs cannot
be chained through a commitment root** (the upstream receipt already opened
it); a caller-fixed **salted handle** (as the zkVM line uses under D7) would
close every case for about +5.5% on the public pass and +12.6% on the private
one [COUNTED; no gadget exists]; and the Fiat–Shamir transcript shares one
untagged 64-byte hash domain with the Merkle and leaf hashes, which any
argument that programs the oracle must face.

## D18 — Who fixes the commitment to a hidden input (decided 2026-09-19: the prover, for the first MVP)

**In plain words.** A private proof refers to its hidden input through a
sealed commitment. Either the **prover** seals it at the moment it proves, and
the seal appears for the first time inside the receipt; or **someone else**
seals it in advance — a regulator fixes an input today and asks for a proof
about it tomorrow. Everything built so far does the first. The open
obligations D8 and D11 are about the second: whoever sealed the input holds
its randomness, and the project's simulation argument cannot treat that party
as an outsider.

**The recommendation put to Victor.** For the first MVP, **the prover seals**:
it is what exists, it needs nothing new, and D13 already scopes the MVP to the
hidden blocks. The receipt then says "the approved model ran on some hidden
input and produced some hidden output, both sealed here", and anyone later
given an input with its randomness can check it against the seal. **Sealing in
advance by a third party becomes the next milestone's requirement**, built
with a salted handle that is not a polynomial-commitment root (about +13% on
the private pass; a hashing gadget that does not exist yet) — the same handle
that chaining separately finished proofs would need. **This does not close D8
or D11; it says which product they bind.**

**Ruling (Victor, Telegram, 2026-09-19 22:15):** "I agree, let's proceed with
A now and B will be added as a todo. Ultimately B seems the more likely
approach to implement." So: **for the first MVP the prover seals the hidden
input and output at proof time**, the seals appear for the first time inside
the receipt, and the privacy game for every MVP artifact is the standard one in
which the prover produces the commitments. **Sealing in advance by a third
party is a recorded todo, and Victor expects it to be the approach the product
ultimately uses** — so it is planned work, not an optional extra: a salted
handle that is not a polynomial-commitment root, with a hashing gadget inside
the proof showing the sealed plane is the one the proof used. Its cost
(+5.5% public, +12.6% private) is counted with a factor-two band and rests on
a gadget that does not exist; it must be scoped and measured before it is
quoted. The same handle is what chaining separately finished proofs needs.
**D8 and D11 remain open**, and they bind that future configuration.

*Scoping note, 2026-09-19 23:13.* The todo was scoped on paper the same
evening and the scoping was attacked by an independent check
(`ZK60_SEALED_HANDLE_SCOPING.md`, its `_CHECK.md`, and the security owner's
`_DISPOSITION.md`). What that leaves on the record: the construction's shape
is accepted as the right one for this option; the memo is **not** accepted as
a basis for any cost or for the choice of hash. Of the two figures above, the
public one follows from its stated basis; **the private one (+12.6%) has no
published derivation and could not be reproduced — treat it as unverified.**
A claim in the draft that both figures were two times too low was checked and
withdrawn. The GPU zero-check is capped at degree 4 and the private block has
no device path, so no GPU-denominated cost for the gadget exists. **Which hash
the handle uses is a security acceptance for Victor of the same kind as D3, D4
and D7; it is taken when this option is scheduled, with the published
cryptanalysis read again that week** (it moved during 2026). The security
owner's direction for the design is a two-layer handle: an algebraic hash
inside the proof whose root is never published, wrapped in one standard salted
hash, so that hiding rests on the assumption D7 already accepted and only
collision resistance rests on the newer primitive. Unchecked and unpriced.
Nothing is scheduled to be built; the first MVP seals at proof time.

## D13 — What the first MVP must prove (decided 2026-09-19)

**Ruling (Victor, Telegram, 2026-09-19 11:50): the hidden transformer blocks
are enough for the first MVP; generating a token is the next milestone.** In
plain words: the first MVP is a private proof that the blocks of a model were
computed correctly on hidden inputs, with hidden outputs. It does not have to
go all the way to an emitted word — the embedding, the final norm, the output
head and the token selection are the milestone after. Why this was the
moment: the target contract's clock covers only the feed-forward blocks; only
the slow zkVM line has a token path at all (the two-block token model); and
the custom line's token path (task A10) is unbuilt, uncosted, and carries two
open design questions of its own. What it changes: A10 and everything
downstream of an emitted word leave the MVP's critical path; the MVP's
acceptance gates in `ZK60_MVP_COMPLETION_PLAN.md` §1.3 that concern
embedding, head and token selection become next-milestone gates. What it does
**not** change: P1 (D1) — inputs, outputs and activations hidden — and the
two-line structure (D2). Pages: `ZK60_RULINGS_FOR_VICTOR.md` §3.

## D14 — A costed memo for the fewer-hashed-bytes speed lever (commissioned 2026-09-19)

**Ruling (Victor, Telegram, 2026-09-19 11:50): write the memo. Paper only.**
In plain words: almost all of the prover's device time goes into encoding
and hashing committed data. Two changes would shrink that data: a
Reed–Solomon encoding rate of 1/2 instead of 1/4 or 1/8, and a 31–32-bit
field instead of the 64-bit Goldilocks field. It is the only recorded lever
that could take an RTX 5090 from 10–15 s per proof to 5–10 s [MODEL,
`ZK60_FIVE_SECOND_PLAN.md` §5 step 6]. It is also the most expensive change
the project could make: **it moves every frozen proof digest in the
repository and changes the soundness accounting** (a smaller field needs
extension-field challenges and more queries; a higher rate needs more
queries for the same proximity bound). The 2026-09-04 deferral rested on
"the 8B pass does not need it", which a 5-second target changes. This ruling
commissions the memo that turns "is 5 s possible" into a yes or a no with a
price: what changes, what it buys in seconds on the 4070 and the 5090, what
it costs in bits of soundness or in extra queries to keep them, what it does
to proof bytes, what must be re-frozen, how many weeks, and what could make
it fail. **Building it remains a separate ruling.** Pages:
`ZK60_RULINGS_FOR_VICTOR.md` §4.

## D24 — Norm precision per profile instead of a fifth remainder limb (proposed 2026-10-17)

**In plain words.** The private block's RMS norm computes
`y = round(g * Cn * x / (2^tn * D))` and proves the rounding with a remainder
that must fit an exact window of `tn + 1 + bits(D_max)` bits. At the toy
precision `tn = 11` that is 33 bits at TinyLlama's width 2048 and 34 bits at
the 8B width 4096 (contract review of 2026-09-30, which also corrected `D_max`
to count the int16 value -32768). Four byte limbs hold 32 bits, and D16 rule 3
forbids more than four limbs on the norm's other witnesses. Two routes were
recorded: a fifth remainder limb (a proof-layout change: new plane ids, a
top-limb range tightening to 33/34 bits) or a restricted 32-bit window with
a bound on every row's norm (which refuses honest inputs).

**Proposal.** Neither: a new profile lowers `tn` by one bit per extra bit of
`D_max` (10 at width 2048, 9 at width 4096) and its multiplier `Cn` falls by
the same factor. `y` is unchanged in meaning; only the multiplier's
resolution coarsens (about one part in a thousand for the calibrated values
measured on TinyLlama), which is negligible next to an int8 output. The
window stays exact and at most 32 bits, `D` keeps three byte limbs, so D16's
rules 1–4 hold as written. `tn`, both norms' `Cn` and `Ceps` become profile
fields bound into the statement; every existing profile and the D22 toy keep
their constants, geometry and bytes.

**Obligations before any trained receipt is called sound:** D16 rules 5 and
6 at the new profile (non-unit-coefficient range audit, wraparound premise,
alias tamper tests rejecting); the field no-wrap bounds re-derived for the
declared ranges of `Cn` and `Ceps` (calibration needs `Ceps` up to about
1.3e8); and an independent adversarial review of the implementation. Not a
privacy acceptance at any new shape. Revisit the five-limb route only if a
profile would need `tn` below about 8.

**Independent review, 2026-10-17** (`results/zk60_d24_review_20261017/`,
frozen copy `ops/zkp-mvp/trained-1b-review-r1/`). **The norm rule holds** over
the whole declared class (tn up to 10 at width 2048 / 9 at 4096, Cn up to
2^20, Ceps up to 2^40): the reviewer's own no-wrap checker reproduces the worst
clause at 2^48.04, about 16 bits under p; `D` stays pinned by its three-limb
window at Ceps 2^40; the quotient is unique; the alias is outside the limb pin;
every constant is bound into the schedule line and the trained statement;
frozen profiles are unchanged (82 of the author's pins and controls re-run).

**Blocking finding F-1 (not in the norm algebra):** the trained loader takes
the softmax precision `f_e` from the export without a declared class. At
`f_e >= 50` (T32) the softmax quotient clause can wrap the field, and the
reviewer produced a forged block output (2,010 of 65,536 words false) that the
saved release verifier accepted in a fresh process. The proofs made so far use
`f_e = 9`, inside the derived premise, and are unaffected. **Rule added with
this finding:** every constant an export can choose (f_e, requant shifts,
table keys, norm constants) has a declared class validated at the trained door
on both sides and in `Layout::for_shape`, and every field no-wrap premise that
touches it is re-derived over the whole class. Minor findings F-2 (trained
receipts can still absorb the synthetic calibration literal; label only), F-3
(`new_bound` accepts a frozen profile; the model-source claim is not proved
against the weights — the statement names the export, it does not prove the
export came from that checkpoint), F-4 (identity depends on the export's
directory name), F-5 (layout does not re-validate trained shapes), F-6 (one
trained profile string covers a family of calibrations, separated by the
schedule digest — acceptable, now recorded; test-only constructors to be
gated). Status: fixes in the native lane, then a focused re-review.

**Re-review round 2, 2026-10-17 — accepted with conditions.** On the frozen
round-2 copy (`ops/zkp-mvp/trained-1b-review-r2/`), no blocking or serious
finding. F-1 is closed (class enforced at the loader on both sides, at the
shape door and again in `Layout::for_shape`; the reviewer's own re-derivation
gives the softmax quotient clause at most 2^34.0 over the whole class; no
wrapping forgery exists at the class edge; the production CLI refuses the
round-1 export). F-2 to F-6 are closed. **Declared classes for trained
profiles (binding):** norm `tn` 1..=16 with the derived four-limb window
25..=32 bits, `Cn_a`/`Cn_m` 1..=2^20, `Ceps` 1..=2^40, width at most 4096;
requant shifts `sh_qkv`, `sh_s`, `sh_g`, `sh_z` 1..=8 (one-byte remainders),
`sh_o`, `sh_h` 9..=16 (two-byte remainders), `sh_ao` 0..=8, with the plane and
lookup lists unchanged; `sh_rope`, `sh_u`, `F_P`, `F_RO`, `sh_r2` fixed; softmax
`f_e` 9..=16 with `clog2(T) + f_e <= 24`; exp key `e_s` -8..=8; SiLU table a
frozen registry member; RoPE base pinned to 10000. All are bound into the
schedule, parameter line and trained statement (schema v3). **Not proved by
the receipt:** that the export came from the named checkpoint (the statement
names the export's digests), and the rotated residual basis (the proved hidden
values are in the rotated basis, bound only through the export's digest).
**Conditions:** R2-a — refuse a shape that carries a trained profile string
without the trained flag, and refuse `wrho_s > 24` for every shape (a shape
built outside the door under a trained profile string could otherwise skip
the class check; unreachable from production, closed before any non-CLI
caller); R2-b — test builds must exercise the strict checkpoint-source rule.
Evidence: `results/zk60_d24_review_20261017/` (ROUND 2). Not a privacy
acceptance; the stack's boundary composition and the GPU path were exercised
by controls, not re-reviewed.

**Independent review round 3, 2026-10-17 (closed 18:36 UTC) — the Llama-3-8B
profile changes are accepted on soundness.** On the frozen copy
`ops/zkp-mvp/trained-1b-review-r3/` (sha256 list re-checked, 195 entries): `tn`
9 at width 4096 with the derived `D_max` 2,097,152 (window 32 bits; every
geometry-dependent no-wrap clause at most 2^48.04 at the class extremes for
TinyLlama T32/T64/T128 and 8B T32), the RoPE base and checkpoint pinned per
profile (10000 TinyLlama, 500000 Llama-3-8B; amends round 2's "RoPE base pinned
to 10000" to "pinned per profile"), the 8B table digests and the statement
binding. The author's tests re-run on the reviewer's binary: 99 passed, 0
failed; the 32-block 8B T32 artifact verifies in a fresh process with the
production CLI. **Open, not soundness:** r3_6 — the stack verifier reads each
segment file without a bound before comparing its length with the counted
length (a /dev/zero symlink exhausts memory, a FIFO hangs); fix assigned to the
native lane (bounded regular-file reader, length equal to the counted length
before reading). r3_3 (a library caller handing both sides the wrong blocks) is
unreachable from the CLI and closed by the round-5 CS-6 port as written,
pending its test run. Note N-r3-a: refuse `--rope-from-export` at the pinned
profiles. Evidence: `results/zk60_d24_review_20261017/R3_VERDICT.md`. Not a
privacy acceptance; the round-5 changes (CS port, reload without the per-array
SHA-256) are for a later round.

**Independent review round 4, 2026-10-17 (reported 22:14 UTC) — the native
round-5 changes are accepted on soundness.** Frozen copy
`ops/zkp-mvp/trained-1b-review-r4/` (= the R5 freeze of 19:48:50, tree
d67fae7e…): the CS-1, CS-3, CS-4, CS-6..CS-9 refusals fire by name before
anything is absorbed on both sides (r3_3 closed: a verifier handed blocks B
under a statement over blocks A now refuses by CS-6's name); the proving-pass
reload without the per-array SHA-256 refuses every digest-pass/reload TOCTOU
case and the verifier still re-hashes everything it binds; parallel hashing
and padding equal the sequential results; the bounded segment reader refuses
every round-3 DoS case by name (r3_6 closed); the byte counters cannot reach
the proof. The author's suite on the reviewer's copy: 688 passed, 0 failed,
29 ignored. **Open, not soundness:** r4_A (new in round 5) — the parallel
layer load reads up to 11 arrays of up to 256 MiB before checking lengths
(a crafted export holds ~5.6 GiB in a verifier); r4_B (older) — the export
reader checks type and size, then reads unbounded (TOCTOU). Both fixes are
assigned to the native lane's R5b freeze. Note N-r4-a: with in-process verify
off, `stack-prove` publishes a statement for an unverified artifact — the same
issue as the privacy review's blocking item P-1, also being fixed in R5b.
Evidence: `results/zk60_d24_review_20261017/R4_VERDICT.md`. The Llama-3-8B
T64/T128 profiles added after the freeze are not covered by this round. Not a
privacy acceptance.

**Independent review round 5, 2026-10-18 (reported 00:37 UTC) — R5b accepted on
soundness; the Llama-3-8B T64 and T128 trained profiles accepted.** Frozen copy
`ops/zkp-mvp/trained-1b-review-r5/` (= the R5b freeze of 2026-10-18T00:06:31Z,
tree 44013397…). r4_A and r4_B closed (oversized, misdeclared, non-regular and
swapped export files refused by name before any read; 5.8 million racing reads
returned only the honest bytes). The privacy review's P-1: H-1 holds (the
sealing pass loads, digests, builds and parity-checks every layer before the
run exists; endpoints are the witness builder's planes) and M-9 / D12b(1) holds
for an honest prover (only `<run>.unverified-statement/` is written; a failed
verify promotes nothing). C-R4, P-5, P-6, P-7 as described. The 8B T64/T128
profiles: every T-dependent no-wrap clause far below p/2 at every f_e in 9..=16
(T128, f_e 16: c2 2^33, c3 2^24, PV 2^24, host-PV 2^24.6), counted layouts
re-derived, other T and f_e refused, all 14 trained profile strings distinct
(D17). The reviewer's own binary re-verified the 32-block Llama-3-8B T128 stack
(identity 6aba46fb…, 922,711,264 B, 11 controls refused) from its own copy of
the export. **Open, not proof soundness:** r5_A (medium) — `stack-verify`
promotes the prover's statement directory after a passing verify without
binding it to the verified bytes (a post-verify segment swap, forged
statement.json fields, or a symlinked directory get promoted); fix assigned to
native round R6 (the verifier writes `statement/` itself from what it
verified). Notes N-r5-a..d assigned with it. Evidence:
`results/zk60_d24_review_20261017/R5_VERDICT.md`. Not a privacy acceptance.

**D25 implementation status, 2026-10-18 (reported 03:00 UTC).** The next-token
proof (D25, D26) is built through rung R2: one private run proves a hidden
next token of the calibrated TinyLlama-1.1B (22 trained blocks, T32, public-row
variant, BOS forced, per-row head with 12-bit multipliers, calibrated final
norm with overflow as a D20 refusal): token 29914, 255,258,816 B, whole-run 97
bits (derived convention, TinyLlama T32). The independent code review accepted
R1 (round 1) and R2 with the round-1 fixes (round 2: no high or medium finding;
`results/zk60_token_io_review_r1_20261017/REVIEW.md`, `REVIEW2.md`); it
re-verified the R2 receipt with its own binary and refused ten probes and
fourteen R2-shape forgeries. Not a privacy acceptance (the G-1..G-7 gate is
owed), not a hidden prompt length (D26 variant P not built), not a token stream
(T6), not a figure at the named D27 workload. Rung R3 (Llama-3-8B) is in
progress with the review's conditions (streaming blocks, R2-1 fixed before an
8B figure).

**Independent review round 6, 2026-10-18 (reported 04:30 UTC) — R6 accepted on
soundness; per-layer `sh_s` accepted.** Frozen copy
`ops/zkp-mvp/trained-1b-review-r6/` (= the R6 freeze of 2026-10-18T02:36:11Z,
tree 83f1fdcb…). r5_A closed: a statement directory must be a real directory
of exactly its named regular files; the verifier returns the hashes of the
bytes it consumed and publishes `statement/` itself into a fresh
`statement.writing-<pid>` renamed without replacing; an existing `statement/`
is only byte-checked against the verifier's own rendering (strict parse,
duplicate keys refused); every round-5 attack (post-verify swap, forged
fields, symlinked directories, concurrent writers) refused with nothing
published. Per-layer `sh_s`: format (`profile_constants.sh_s` null, listed in
`per_layer_constants_differ`, per-layer manifests pinned), the door on both
sides (window 1..=8, trained shapes only; out-of-class and stale-digest
exports refused before any array is read), binding (an own value in the
trained identity and its stage's schedule line; flattening the real b7 T128
export's layer 1 moves its identity 97c4acda… → d29c4343…), no-wrap over the
whole class at all six trained profiles (score host relation ≤ 2^21 against
p/2 ≈ 2^63), run-wide exports keep their identities (the R5b 8B b6 T128 run
6aba46fb… verifies under R6). N-r5-a (CS-3 before the header), N-r5-c
(`prover_reported` label) and N-r5-d closed. The two 03:17 exit-1 jobs were
the reviewer's own probes (an R5b-format `statement/` refused by the new
byte-check as intended; an all-zero pin to print the b7 identity). **Notes,
not soundness:** N-r6-a the `statement_written_by` label is unauthenticated —
operating rule: evidence of a verification is a `stack-verify` log line or a
re-run, never a directory's existence; N-r6-b a `statement.writing-<pid>` left
by a killed writer blocks later verifies until removed; N-r6-c R5b-written
statements need re-layout under R6. The native lane's b7 T128 stack landed 2026-10-18 04:58 UTC (identity
97c4acda9da994c1…, 922,711,264 B, parity bit-exact at 32 layers) and the
reviewer re-verified it independently on 2026-10-19 09:28 UTC from its own
copy of the export (11 controls refused; published statement byte-checked;
layer 1's own `sh_s` 7 recorded): the first real stack with a per-layer
score shift. Evidence:
`results/zk60_d24_review_20261017/R6_VERDICT.md`. Not a privacy acceptance.

**D25 implementation status, 2026-10-19 (reported 10:17 UTC): rung R3 — the
trained Llama-3-8B next token is proved.** One private run on the
`llama3_8b_pg_rot1_b7_T32` export (32 trained blocks streamed, layer 1 at its
own score shift per R6), the trained int16 embedding and per-row int8 head
with 12-bit multipliers (`export/llama3_8b_pg_rot1_b7_T32/token_io/`, F2:
D25 T4 met), calibrated final norm (Cn 4,234), BOS 128000, public-row variant:
token 11 (equal to the in-test, Python and calibration-lane references; float
top-2 margin 4.40), parity bit-exact at 32 layers, 471,285,072 B, prove
191.7 s, fresh verify 43.4 s under a 95-bit policy, whole-run 97 bits with
the omitted terms bounded explicitly (review R2-1) [MEASURED, shared box,
n=1; `results/zk60_token_io_r1_20261017/runs/r3/trained-ho00/`]. The token
tree is now rebased on native R6. **Independent review round 3 (reported
10:58 UTC, `results/zk60_token_io_review_r1_20261017/REVIEW3.md`): R3 may stand as the
trained Llama-3-8B next-token result** — the merge onto R6 loses nothing (the tree
differs from R6 in exactly the lane's 15 files; R6's refusals intact), streaming
checks each reloaded block's digest at use, the per-layer shift is bound in the
stage line, the 8B table loader is length- and SHA-checked, V_pad 2^17 is the
door's exact edge, the whole-run figure recounts to 2^-97.575 (floor 97); the
receipt re-verifies with the reviewer's binary (37.7 s); 15 forgeries, 9 receipt
probes and a full 32-layer forgery refused. Findings LOW/INFO only (TR3-1 a
mid-run refusal after earlier segments reached the sink; TR3-2 the loader and
streaming source are test code; TR3-3 shift read by record position). Not a
privacy acceptance (G-1..G-7 owed), not a hidden prompt length, not a token
stream.

**Independent review round 7, 2026-10-19 (reported 10:25 UTC) — R7 accepted on
soundness.** Frozen copy `ops/zkp-mvp/trained-1b-review-r7/` (= the R7 freeze
of 2026-10-19T09:58:29Z, tree 36a8aed1…). The diff changes only statement
writing and publication plus a pre-listing cleanup; no proof, transcript,
loader or relation code. N-r6-b closed: a leftover `statement.writing-<pid>`
is removed only if its name is all ASCII digits, it is a real directory, its
pid is dead and it holds only the verifier's three regular files; every
other case is refused by name and kept (400 racing runs: outside targets
survived every run). Q-2 closed: `prover_reported.backend` is one of three
build constants (the CPU constant byte-identical to R5b/R6's), declines 0 on
the CPU path and <= 4096 with the device, checked before writing and before
publishing; 22 bypass attempts refused with nothing published. R6 CPU
statements byte-check under R7 (incl. the 8B b7 T128 stack, 97c4acda…).
**Notes, not soundness:** N-r7-a the live-pid test assumes `/proc` in the
verifier's own pid namespace (a removed live writer only fails its own
rename); N-r7-b the `gpu_declines` parse error echoes the prover's numeral in
local verifier output (deferred: fix with the next tree change, not worth a
re-pin now); N-r7-c a CPU prover may claim the device name (an unverifiable
self-report, now limited to three fixed names). Evidence:
`results/zk60_d24_review_20261017/R7_VERDICT.md`. Not a privacy acceptance.

**Native R8 frozen, 2026-10-19 14:38:35 UTC (recorded 14:39 UTC) — per-layer
calibration constants, under review (round r8).** For fidelity (D32): all
eleven export-chosen constants (norm_tn, norm_cn_a, norm_cn_m, norm_ceps,
sh_ao, sh_qkv, sh_s, sh_o, sh_g, sh_h, sh_z) may be per layer through one door
(`Shape::with_layer_calibration`, classes unchanged, plane list rebuilt and
any change refused — so norm_tn stays run-wide at the trained profiles);
recorded only where a layer differs from the run base; run-wide and
sh_s-only identities unchanged (97c4acda…, 259dad7c…, 9b71dfb0… re-verified
under R8); no-wrap worst 2^43.09 over every class at six trained profiles
[author's count]. Suite 707 passed / 0 failed. Per-layer constants close
about half of TinyLlama's perplexity gap with no new planes (fidelity lane).
**Independent review round 8 (reported 15:00 UTC): R8 accepted on soundness**
(`results/zk60_d24_review_20261017/R8_VERDICT.md`): the door checks every value in
its class and refuses any plane-list change, at the loader, the statement
self-check, statement build (both sides), per stage and in the sealing pass; 23
out-of-class values at layer 1 refused by name on both sides with no run directory;
whole-calibration swaps between layers and within-window swaps (sh_o/sh_h,
cn_a/cn_m) move the identity; no-wrap recomputed independently, worst 2^43.32 over
every class at six profiles; four published runs re-verify under R8. Notes, not
soundness: N-r8-a a negative own value would encode as u64::MAX (unreachable, all
classes positive); N-r8-b norm_tn must stay run-wide at the trained profiles;
N-r8-c the base depends on the --layers range; N-r8-d parity against the Python
reference at per-layer constants on a real export still owed (fidelity, not
soundness). Not a privacy acceptance.

**Native R12 frozen 2026-10-26 18:12:33 UTC (Sol, tree 1e406781…) — Shieldstral
shapes (decoupled head_dim, YaRN tables, tied embedding); independent review
(recorded 20:09 UTC): ACCEPTED WITH FIXES on soundness** at the four Shieldstral
profiles (T128/T256 × DD/non-DD) and the decoupled-head rung
(`results/zk60_d24_review_20261017/REVIEW_R12.md`). Existing profiles
byte-identical to R9 (four seeded digests, five identities, five retained R8/R9
stack receipts re-verify). Widths, head count and RoPE tables are fixed by the
profile (CS-7 refuses 28 edited shapes; the verifier computes YaRN itself and
matches transformers ≥ 5.13.1 to 1.4e-7 relative; 4.48.1's attention factor
refused by name). Pad lanes constrained (support = true lanes; three padded-lane
attacks rejected). Soundness per 26-block run: T128 97.60 / 97.67 (non-DD / DD),
T256 96.37 / 96.57, T512 95.03 / 95.42 [counted; T512 not registered; 0.03 bit
over D27's floor without DD]; no wrap, worst 2^43.08. **Fixes owed (Sol, R12b):**
R12-F1 (medium) the tied embedding is declared, not checked — the loader and
statement compare declared names/digests, then hash whatever token tables are
present (a doctored yes/no head with an updated manifest digest is accepted);
recompute the tables from the pinned tensor (or pin per-calibration table
digests) and check dtype/shape 131072 × 3072 — **blocks any classifier claim
that reads the head**; R12-F2 (low, DoS) unbounded/symlink-following token-table
reads; R12-F3 (low) `--rope-from-export` proves export tables the statement does
not record (refuse at transform-pinned profiles or record the digest). Notes
N-1..N-7 in the review. Not a privacy acceptance.

**Token round 16 frozen 2026-10-29 ~09:30 UTC (Claude token lane;
unreviewed): the real Shieldstral-1.0-3B classifier registered on native R13**
(`results/zk60_token_io_r1_20261017/frozen-r16.FROZEN.txt`; 300 files;
binaries e94cecf9… (made the real receipts) and dae5abd7… (frozen tree); suite
934 / 0 / 68 [MEASURED]).
- Run profiles `…private-classify-run-shieldstral-3b-t128-r13-public-row/1`
  and the T256 twin. The fixed policy list is the three D37 categories in the
  **moderate** wording, flagged pending Victor's strict / moderate ruling.
  Pad id 11; overlap 8.
- **First real proofs** [MEASURED, laptop, n=1]: one 35-token ToxicChat post
  through all three categories:
  - prove 439–456 s total (328–349 s proving), peak 8.08–8.27 GiB;
  - receipt 848,412,096 B in 28 segments;
  - verify / input-owner / label 66–71 s, about 2.3 GiB;
  - all verdicts not-flagged.
- Whole-run bits: T128 96.86, T256 95.91 [COUNTED].
- One checkpoint stream per prove / verify (N-r13-5 fixed).
- Blockers for the app: the per-item activation source (Astra's integer
  evaluator); Victor's policy-wording ruling; the independent review and the
  privacy gate (no classifier privacy statement exists).
- **Independent review (recorded 2026-10-29 10:06 UTC): ACCEPTED WITH FIXES
  on soundness** (`results/zk60_token_io_review_r1_20261017/REVIEW_R16.md`).
  - The real moderate-hate receipt re-verifies under the frozen-tree binary
    (identity 29aeba6c…, verify 39.6 s).
  - The rebase, the gate shift per layer, the per-block stage shapes,
    `build_for_block` and the bits (96.86 / 95.91, recomputed) all hold.
  - The single checkpoint stream stays inside the authenticated load.
  - Wrong activations are refused even by a prover with its own checks
    switched off, so **the activation source is integration only, not
    soundness**.
  - **Fix F-1 (medium; D45(2) conformance):** the production list still
    admits round 12's `shieldstral-1.0-3b-card-unsafe/1`, so four policies
    instead of three. Make it test-only, and test that each R13 profile
    admits exactly the three.
  - **N-r16-1 (low):** pin the exact floors (a mutant charging one block
    stays green).
  - The privacy-gate needs are in the review's §10.
- **Round 16b frozen 2026-10-29 ~10:55 UTC (recorded 10:58)** (`frozen-r16b`, binary
  `cli/zk60_classify.r16b.release.bin` dfb8025e…; suite 936 / 0 / 68).
  - **F-1 fixed:** `card-unsafe/1` is test-only, and T128 / T256 each admit
    exactly the three moderate policies (failing-first; the `card-back`
    mutant is killed).
  - **N-r16-1 fixed:** the exact floors are pinned, and the one-block mutant
    is killed.
  - No statement bytes moved: the real violence receipt re-verifies, identity
    29aeba6c….
  - Coordinator code check of `registered_policies` / `policy_shieldstral_card`
    confirms the fix.
  - **The app must use r16b or later** (the r16 binaries still accept the card
    policy).

Not a privacy or classifier-quality claim.

**Privacy gate round 19 (Claude gate lane, 2026-10-29, tools v22 frozen,
manifest ab703596…): all 14 classifier captures PASS, including the REAL
Shieldstral-1.0-3B classifier** (`results/zk60_gate_tinyllama_20261017/round19/R19_SUMMARY.md`).
- **The real capture** (r16b binary dfb8025e, moderate-sexual, the 35-token
  post as a short item with 20 pads at id 11): `PASS-WITH-DECLARED-LIMITS`.
  - Disclosed dimension 0 on all 84 A / endpoint / boundary commitments and 2
    on every H. CFS: 0 of 440,221 entries differ. Joint 0 over 1.05 M pairs.
  - 15 of 15 controls fire. 19 tables were rebuilt, and B-3 was derived from
    the checkpoint (bit-exact).
  - **Limits:** (1) the capture has no table values, so 12 of the 23 block
    slots stay open; (2) the full preimage was checked on a declared sample of
    15 commitments (9.7 M entries, 0 differing).
- **13 R13-rung captures** pass: the verdict reveals only its public bit, and
  a short item only its public length.
- **R19-PIN-1:** frozen-r16b's recorder cannot record R13 runs
  (`plane_index.rs` is legacy-only). The gate used test-only patches H19-1..4,
  and the token lane must adopt them.
- **Refusal recount** [COUNTED]: the D34 / D40 term at R13 Shieldstral is
  2^-108.25 (was 2^-112.7; the SiLU table has 16,384 rows).
- **R19-1:** range refusals depend on hidden content (102 of 300 ids refuse
  at one dev calibration). The classifier privacy statement must state this
  channel; with D45(4), fail-closed, it shows as "could not be verified".

**Not a privacy acceptance.**

**Privacy gate round 20 (Claude gate lane, 2026-10-29, tools v23 frozen,
manifest 64f4b757…): both of round 19's limits are CLOSED on the real
Shieldstral capture** (`classify-r13-shield-t128-cli-hate-r17-values`;
`results/zk60_gate_tinyllama_20261017/round20/R20_SUMMARY.md`). The status is
**PASS with no declared limit**.
- All 23 block slots hold in all 26 real blocks (each at its own gate
  denominator), and all 7 R13 block controls fire.
- **The full zero-data preimage over all 84 commitments: 81,731,058 view
  entries, 0 differing.**
- Everything round 19 checked holds again: disclosure 0 / 2, CFS 0 of
  440,221, joint 0, 12 classifier slots with tables rebuilt, B-3 bit-exact,
  15 controls including C-13 at pad 11.
- 4.06 h, 6.47 GiB peak, alone; one checkpoint stream.
- **Still owed for a classifier privacy statement:**
  - the statement text;
  - the per-run distance figure, including the 2^-108.25 refusal term;
  - the R19-1 refusal-channel wording;
  - an independent derivation (or review) of the 15 block tables the gate
    takes from the capture;
  - the owner checks;
  - Victor's policy-wording ruling;
  - an independent privacy review, the security owner's sign-off and
    Victor's acceptance.

**Not a privacy acceptance.**

**Token round 17 frozen 2026-10-29 (recorded 16:35 UTC; Claude token lane)**
(`frozen-r17`, 303 files, manifest 23a95876…; binary 81bd8624…; suite
940 / 0 / 70).
- It adopts the gate's H19-1..4 (an R13-aware `plane_index`, the classifier
  bundle schema, the capture hooks).
- Captures now record the public block tables (442 on the real run), each
  re-derived from the export and required byte-equal before recording.
- **All six changed files are test-only.** The coordinator confirmed that
  `run_capture` and `plane_index` are `#[cfg(test)]` modules: no prover,
  verifier, statement or receipt byte changes. The real hate receipt
  re-verifies with r17.
- The coordinator's check stands in for a separate review (scope: test and
  recorder code only). The gate's own reader closes 23 / 23 block slots on
  the rung and on 2 sampled real blocks.

**S4 split-width: independent design check (2026-10-29 07:43 UTC), PROCEED WITH
CONDITIONS** (`results/zk60_d24_review_20261017/S4_DESIGN_CHECK.md`; binding
conditions C-1..C-11, privacy re-derivations P-1..P-6). **Construction rules
adopted by the coordinator (security owner for construction rules), the same
day:**
- **(a) Lift placement "B-gate":** the zero lift (1 − b) enters only the
  public factor each term already has: the zero-padded weight fold for
  matmuls, and `Tab::Eq` at (r_t, 0^k) for the norm sums. The smaller piece's
  private table stays as native code builds it, and σ never enters a private
  functional. The masks, claim audit, `open_zk`, wire format and rank
  structure are unchanged. The lift is folded into that existing public
  factor, never added as a separate public table (that raises the extension
  degree to 4 against a declared 3; the checker's harness refuses it). This
  replaces the wording of the 06:35Z go-ahead about scaling the whole masked
  functional.
- **(b) Boundaries and endpoints:** **one commitment per logical boundary or
  endpoint holding both pieces as ordered row blocks** (30 rows external, 34
  internal in the checker's model, disclosure 0), not two commitments. D12a
  ("one prover-generated boundary commitment") therefore stands unchanged,
  and no extra PCS openings are added.
- **(c)** Per-piece rounding, wrong c2 / group offsets and a one-piece norm
  must become receipt-level attacks at the native stage. The ACT3 group
  column uses global channel ids, and the ACT3 bound is re-evaluated at the
  new lookup count.
- **(d)** The whole-run soundness bits are recounted (lookup term, opening
  count) before any S4 profile is registered (R13's lowest is 96.09).
- **(e)** S4 is a new versioned profile. R13 and legacy bytes stay fixed. A
  D24 review and a privacy-gate round (P-1..P-6) come before any S4 use.

**Native R13 frozen 2026-10-29 06:12 UTC (Sol; accuracy stack S2: LOW + h
int24 at 8B, LOW at TinyLlama, the Shieldstral-only SiLU member (0, −8),
two's-complement int16 at the 8 widened word sites; source bb9eb212…, 269
files; suite 816 / 0 / 51; 19 receipt-emitting attacks rejected).**
**D24 review (recorded 2026-10-29 07:21 UTC): ACCEPTED on soundness at all
twelve registered profiles** (`results/zk60_d24_review_20261017/REVIEW_R13.md`).
- Existing profiles are byte-identical (9 of 9 golden lines), and retained
  R8 / R9 stacks verify.
- An independent integer reference built from the S2 spec matches the native
  witness at 0 differences: generic fixtures, real Shieldstral layer 0 at
  T128, and layers 0 and 25 at T256 including the (0, −8) member.
- The widened words admit exactly [−32768, 32767] and the score [−127, 127].
  The worst field bound is 2^49.99.
- SiLU-group forgeries are refused: prover tables, doctored or fifth groups,
  wrong groups, swapped ids. Also refused: 15 self-consistent alternative
  witnesses, 9 doctored exports and 22 rebuilt calibration controls.
- **Bits:**
  - TinyLlama T128: 98.40 / 98.50 (no DD / DD);
  - 8B T128: 97.00 / 97.06;
  - Shieldstral T128: 97.30 / 97.36;
  - Shieldstral T256: 96.09 / 96.26;
  - **8B T512 (not registered): 94.48 / 94.80**. Below ~95 (N-r13-1),
    needing a ruling or a lever before 8B T512 is registered on R13.
- Low fix **R13-F1** (Sol): 11 calibration CLI controls are built at a
  legacy shape, so at R13 they are refused before any receipt byte is read
  (a test defect; the property itself was re-shown by the reviewer).
- The requirements for registering the Shieldstral classifier on R13 (token
  lane) are in the review.

Not a privacy acceptance.

**Native R12b frozen 2026-10-28 22:33 UTC (Sol, tree 51de5b83…, 229 files;
suite 739/0) — the three R12 fixes; independent fix-check review (recorded
23:12 UTC): ACCEPTED on soundness for the fix scope, no fixes required**
(`results/zk60_d24_review_20261017/REVIEW_R12B.md`).
- **R12-F1 FIXED:** the loader checks dtype, shape and exact size, then
  recomputes the embedding, head and multiplier tables from the checkpoint
  (whose sha256 must equal the model pin) and refuses any mismatch. The
  reviewer's independent quantizer reproduces every digest bit for bit, and
  27 attacks are refused, including rehashed one-byte forgeries of each table.
- The coordinator's three F1 conditions hold:
  - the yes / no ids and the scale are function arguments, never file
    contents (binding them to the profile is R-C2's job);
  - `token_io_parameters` sit inside the bound profile digest;
  - an out-of-range margin is refused, never clamped (0 of 3,072 coordinates
    refuse at the policy scale).
- **F2 FIXED:** symlinks, FIFOs, devices and names that escape `token_io/` are
  refused (no-follow flags are set on Linux x86_64 only).
- **F3 FIXED:** refused at all four Shieldstral geometries on both load paths.
  The older gap at unscaled profiles remains.
- **N-7 fixed with notes:** about ten older test sites still write to /tmp.
- **Regression:** five retained receipts verify with byte-identical
  statements, and Sol's golden output matches the reviewer's round-10 run
  9 of 9.
- **Note N-r12b-1:** every Shieldstral prove or verify reads the whole 7.7 GB
  checkpoint (17–18 s per load) at a path bound in the profile.
- **R-C2 must:** take the ids, the scale and threshold_c only from the bound
  profile's `classifier_margin_parameters`; require the returned profile
  digest to equal the statement's `export_profile_sha256`; use the derived
  margin, never the file; let refusals through; never apply the final norm
  or the rotation twice.

Not a privacy acceptance.

**Token round 13 (R-C2) frozen 2026-10-28 ~23:40 UTC (Claude token lane) on
native R12b** (`results/zk60_token_io_r1_20261017/frozen-r13.FROZEN.txt`; 257
files; binary `cli/zk60_classify.r13.release.bin` e320c237…; suite 832 / 0 /
55 [MEASURED]).
- The classifier verifier recomputes the margin row, the embedding, BOS and
  the final norm from the pinned tensor and the bound export profile
  (`classifier_margin_parameters`, `token_io_parameters`). It refuses
  doctored tables carrying updated manifest digests. Four tests failed first
  against R-C1 and are now green.
- The statement schema is `zk60-classify-run/2`. `--min-bits` is floored at
  93 (dev rung) and 95 (elsewhere, D27).
- Only the dev-rung classifier profile is registered. Shieldstral's waits for
  native R13 and Astra's fixed export.
- **Independent review (recorded 2026-10-29 00:56 UTC): ACCEPTED on soundness
  for R-C2's scope, no required fixes**
  (`results/zk60_token_io_review_r1_20261017/REVIEW_R13.md`).
  - The five R12b requirements hold in the shipped CLI.
  - 51 attacks in 9 groups are refused, and 13 of the reviewer's 14 mutations
    are killed by tests.
  - The dev-rung tables were recomputed independently (exact and binary64
    arithmetic agree).
  - Neither binary accepts the other's receipts; R-C1's doctored-row gap was
    shown live and is closed in r13.
  - **Must fix before the gate or any non-CLI caller relies on R-C2:**
    - **N-r13-1:** the binding to the model lives only in the CLI loader. The
      library prove / verify functions and the gate's capture tool accept any
      tables.
    - **N-r13-2:** no test fails without the post-derivation digest check.
  - The privacy gate must re-capture every R-C2 item; no R-C1 capture
    carries over.

  Not a privacy acceptance; no Shieldstral classifier claim (Shieldstral is
  not yet registered).

**Token round 14 frozen 2026-10-29 ~02:05 UTC (Claude token lane; unreviewed)**
(`results/zk60_token_io_r1_20261017/frozen-r14.FROZEN.txt`; binary
`cli/zk60_classify.r14.release.bin` 48dac988…; suite 845 / 0 / 56 [MEASURED]).
- N-r13-1: every library entry point takes only tables bound by
  re-derivation.
- N-r13-2: a test now kills the missing-digest-check mutant.
- The gate's capture helper builds derived tables.
- **Short items (T < T_pad):** one chunk with public pad positions (within
  D45(1)). Coverage by length: 100% of the 4,872 benchmark item / policy pairs
  at T128 and T256 [COUNTED].
- Schema `zk60-classify-run/3`.
- **Independent review (recorded 2026-10-29 03:05 UTC): ACCEPTED on
  soundness for round 14's scope, no required fixes**
  (`results/zk60_token_io_review_r1_20261017/REVIEW_R14.md`).
  - Short-item attacks are all refused: boundaries, restated lengths, 10
    forged prover layouts, moved verdict rows, other pad ids.
  - Causality is enforced by the relation: forged masked weights that moved
    the margin were refused at the softmax zero-check.
  - Only the diagonal verifies across the r12 / r13 / r14 schemas, and all 10
    mutants are killed.
  - **N-r14-1 (low, must close before the app accepts short items):** `label`
    cannot check that the proved chunks cover the whole post, so the app must
    compare `content_total` with the post's length (Astra), with a CLI
    `--expect-total` to follow.
  - Gate C-13 requirements are in the review's §10.

  Not a privacy acceptance.

**Privacy gate round 18 (Claude gate lane, 2026-10-29, tools v21 frozen,
manifest 25814977…): all 21 R-C3 classifier captures PASS**
(`results/zk60_gate_tinyllama_20261017/round18/R18_SUMMARY.md`).
- The captures cover L1 and L2 at verdict 0 / 1 / tie, a 2-chunk item, short
  items with n = 1, 11, 20 and 22, and two CLI-path captures.
- Disclosed dimension: 0 on every A, endpoint and boundary commitment, and 2 on
  every H (as expected). 19 public tables were rebuilt and none was taken from
  a capture.
- The verdict moves nothing but its public bit, at every n. A short item
  discloses the same as a full item, apart from its public length fields
  (D45(1)).
- All C-13 controls fire, and REVIEW_R14 §10 (a)–(f) is covered.
- Token-lane follow-ups: F18-1 (the capture writers emit 24 slot triples
  against n_slots 23), O18-1 and H18-1.
- Still owed for a classifier privacy statement: the statement text, per-run
  distance figures, owner checks on short items, the Shieldstral profile and
  its captures, an independent privacy review, the security owner's sign-off
  and Victor's acceptance.

**Not a privacy acceptance.**

**Token round 15 frozen 2026-10-29 ~04:52 UTC (Claude token lane)**
(`results/zk60_token_io_r1_20261017/frozen-r15.FROZEN.txt`; binary
`cli/zk60_classify.r15.release.bin` 5edb7241…; suite 850 / 0 / 59 [MEASURED]).
- **N-r14-1 closed:** `label --expect-total N` is required, and
  `aggregate_label` refuses unless every run names the same policy, model and
  plan, the total is N, and the ranges are exactly the D41 split of [0, N).
  Missing or duplicate chunks are refused.
- **F18-1:** the capture writers list exactly 23 slot triples.
- **H18-1:** the CLI short-item capture hook is adopted.
- Docs: v2.5, with the D45 marks and the causality argument citing the
  relation.
- The round changes no receipt or statement bytes: r14 and r15 cross-verify
  both ways, and the schema stays /3.
- **Coordinator code reading of `aggregate_label` (no separate review agent,
  given the scope):** correct. Note that `--expect-total` binds length only;
  binding to the post's content remains the input-owner check (D45(3)).
- The gate moves its two capture-source pins (`run_capture.rs`,
  `token_io.rs`) to r15 in its next round.

Not a privacy or classifier claim.
