# The sequential-kernel lemma for (field, hash) pairs — the independent adversarial check

> **VERDICT ON THE LEMMA AS STATED: PROVED WITH CHANGE.** Lemma P (the path
> identity), Theorem S-H and Theorem S-H′ are **correct**, and they survive
> everything I could throw at them — two and three challenge rounds, early
> aborts, every completion of a truncated challenge vector, adversarial
> schedules, and a non-adapted bad-event flag. Three changes are required
> before the statement is usable: one hypothesis is **missing from the
> numbered list** (B-7), one term is **in the wrong place** — `B_sep` is a
> failure of hypothesis (iii) and cannot be repaired inside the (iv′) bad
> event (B-1) — and one quantity in the conclusion, `Pr^ξ[B]`, is **not
> well defined** as worded (B-10).
>
> **VERDICT ON "O-4 IS CLOSED": NO. O-4 IS REDUCED, NOT CLOSED**, and by a
> little less than the memo claims. The composition step is written and
> correct; but hypothesis (iii) is reached only by an (L1) hybrid hop the
> memo prices and does not perform (B-1); the enumeration of prover oracle
> queries that (iii) rests on is **incomplete on the production path**
> (B-2); and hypothesis (iv′) is **not delivered by the accepted theorems** —
> the owed sentence is the project's own "one candidate with no structural
> answer" (B-3), and the memo's stated reason for believing it is the reason
> it is missing.
>
> **Nothing accepted is damaged.** D22 rests on Route A; correction K-1
> touches one MIXED/RELIES-ON row of one memo and no accepted sentence
> (verified by search, §6). No number in the memo is wrong; the toy total
> stays 2^-77.70 and a twelve-block 125M run 2^-69.29 [COMPUTED].

| | |
|---|---|
| Checker | **An independent adversarial Opus agent.** I did not write the memo and owe it nothing. Instructed to assume it wrong |
| Written | 2026-09-21, 01:42 – 02:30 PDT (`date` read at the start and before writing any time) |
| Under attack | `ZK60_SEQUENTIAL_KERNEL_LEMMA_HASHED.md` (987 lines, drafted 01:14–01:45 tonight) and `results/zk60_sequential_kernel_lemma_hashed/` |
| My evidence | `results/zk60_sequential_kernel_lemma_hashed_check/` — `adversarial_kernel_check.py`, `checks.json`, `checks.log`, `README.md`. Exact `Fraction` arithmetic, standard library only, fixed seeds, ~80 s. **Nothing reused from the memo's script** |
| Code read | lane worktree `/home/victor/wt-zk60-block125m` at **`8c5922b`**, read-only via `git show`. A full BLAKE3 call-site inventory of the tree at that commit was made for this check |
| Scope guard | This is a check of an inference and of a hypothesis-to-code match. **No privacy property is established or withdrawn here.** D22 is untouched |

---

## 1. Verdict table, claim by claim

| # | the memo's claim | my verdict | where |
|---|---|---|---|
| 1 | **Lemma P**, the path identity `Pr^ξ[m, E] = Pr_{ρ^ξ(m)}[m, E]` | **CORRECT.** Proof is right; the set equality is a genuine set equality. Machine-checked by me at 2 and 3 rounds, with aborts, 0 mismatches over 12,303 schedule instances [COMPUTED] | §3, B-11 |
| 2 | Lemma P is well defined for **truncated** `m` | **CORRECT BUT UNDERSPECIFIED.** `ρ^ξ(m)` is only a prefix; `F` ignores the tail, so the identity is insensitive to the completion — verified for every completion [COMPUTED]. But the memo never says so | B-10 |
| 3 | **Theorem S-H** (exact), in model (L0) | **CORRECT**, on hypotheses (i), (iii), (iv) **and the unnumbered publicness hypothesis**. (ii) is not needed | B-7, B-8 |
| 4 | **Theorem S-H′** (identical-until-bad), bound `½(Pr^ξ_w[B] + Pr^ξ_{w′}[B])` | **CORRECT.** The one-line step `Σ_m Pr_ω[F(w,·,ρ^ξ(m))=m, B] = Pr^ξ_w[B]` is sound. Tight in every instance I built | §3.2 |
| 5 | hypothesis **(iii)** as stated: `ξ ⊥ (ω, w)` | **CORRECT AS A HYPOTHESIS, MISPLACED IN THE ASSEMBLY.** It is consumed at "Fix ξ", not at the end of the proof as the memo says; and a *partial* correlation is as fatal as a total one, so it cannot be priced as a bad event | **B-1** |
| 6 | the five-way query partition makes (iii) hold at `8c5922b` | **FALSE AS WRITTEN.** At least two further production-path query kinds, one of them exactly 64 bytes twice per block | **B-2** |
| 7 | **Claim S-5**, `B = B_samp ∪ B_salt ∪ B_sep ∪ B_logup`, gives (iv′) | **NOT ESTABLISHED.** `B_sep` does not belong in `B` (B-1); Repair 1 needs a named coupling (B-4); Repair 3 / GAP S-1 is under-sized and its reason is wrong (B-3) | **B-3** |
| 8 | **Repair 1** (the sampler idealisation becomes an event), number unchanged | **CORRECT FOR ONE COUPLING ONLY.** The rejection-region coupling of `fp()` works and keeps the number at 2^-96; a generic maximal coupling does not | **B-4** |
| 9 | **Repair 2** (`B_salt` a witness-free superset of `B_H`'s collision event, costing the published figure) | **CORRECT.** `C(N_leaf,2)·2^-256` = 2^-229.830 toy / 2^-214.523 run [COMPUTED], matching the two memos' tables exactly | §7 |
| 10 | **Claim K-0**: the naive approximate form is false, blow-up `\|C\|` | **CORRECT AND UNDERSTATED.** At two rounds the blow-up is `\|C\|^2` [COMPUTED: ×4, ×9, ×16]. The memo's prose says "the number of reachable challenge vectors"; its evidence only ever measured one round | **B-11** |
| 11 | **Correction K-1** to the toy memo §3.3 | **CORRECT, AND NOTHING ACCEPTED IS AFFECTED** (searched; §6). Partly foreseen: the *same sentence* K-1 corrects already names the defect's second half, and the branch lemma's own proof already says "witness-dependent refusal events break it" | §6 |
| 12 | **Corollary S-H″** (the distinguisher's `q` queries) | **CORRECT**, and it survives *optimal adaptive* querying, which the memo's C8 did not test [COMPUTED]. The bound is very loose | B-11 |
| 13 | **Claim S-6** (Game ⊥ makes (iv′) trivial at challenge-refused `ρ`; Game prefix does not) | **CONFIRMED and made exact.** I built one protocol where (iv′) holds at every `ρ` under Game ⊥ and fails under Game prefix, with the adaptive conclusion following [COMPUTED] | B-13 |
| 14 | hypothesis **(ii)** and GAP S-4, "COMPUTATIONAL for the interior … through binding" | **WRONG LABEL.** (ii) is not needed for the conclusion [COMPUTED]; it is a well-posedness condition. The soundness appeal is unnecessary — in the privacy game the prover is honest — and should be deleted. S-4 is a gap in (iv) | **B-8** |
| 15 | "the composition is proved in **(L0)**, the ROM used for three priced quantities only" | **OVERSOLD.** (iv′) is itself an (L1) statement — Lemma H is (H6), which its own memo says is "not a theorem: a statement inside an assumed model" — and (iii) needs one more (L1) hop | **B-9** |
| 16 | "**Two terms leave the tally and none joins it**"; totals unchanged | **TOTALS CORRECT, TALLY INCOMPLETE.** §5.3 omits three rows the run's accepted residual table carries (B10, tag-key, key-collision) and two the toy's does. None moves a total [COMPUTED] | **B-5** |
| 17 | `B_logup` at 2^-117.42 / 2^-113.83 "(ruling S-4)" | **THE NUMBERS ARE RIGHT, THE ATTRIBUTION IS WRONG**, and the memo carries both sides of the one-bit trap the run check named as B-12c. My C4 shows the factor 2 is *forced* | **B-6** |
| 18 | every other figure in §5.3 | **ALL REPRODUCE** to two decimals, except B4/B6, which is **not recomputable** from the memo (it never states the absorb count `A`) | §7 |
| 19 | "D22's sentence does not change, and must not" | **CORRECT.** Verified by search across the statement, its draft, and every disposition | §6 |
| 20 | the machine evidence C1–C8 | **PARTLY VACUOUS.** [COUNTED] all eight checks run at `rounds ≤ 1`. C2 is tautological on instances built to satisfy (iv) exactly; C8's bound exceeds 1 at `q = 1` | **B-11** |

---

## 2. Findings, most serious first

### B-1 — `B_sep` is inside the (iv′) bad event, where it cannot live. An overlap of the two oracle query classes is a failure of hypothesis (iii), and no bookkeeping inside Theorem S-H′ repairs it. SERIOUS

**The memo's text.** §3.6 Claim S-5: "*Take `B := B_samp ∪ B_salt ∪ B_sep ∪ B_logup` with … `B_sep` — a transcript-class query input equals a prover-class query input … Then (iv′) holds*". §3.7 row R-b prices `Pr[B_sep]` at 2^-241.42 (untagged toy) or 0 by D19a.

**Why it is in the wrong place.** Hypothesis (iv′) is a statement *inside* the fixed-challenge experiment: for every `ρ` and every `m`,
`Pr_ω[F(w,ω,ρ) = m, ¬B] = Pr_ω[F(w′,ω,ρ) = m, ¬B]`, with `ω ~ μ` **unconditioned**. Hypothesis (iii) is what licenses the proof's very first move. The memo writes the proof of S-H as "*Fix ξ. … By (★) … Since this holds for every `ξ` and `ξ ⊥ w` by (iii), the joint law of `(view, ξ)` is the same*" — as if (iii) were used only at the end. It is not. "Fix `ξ`" means *condition on* `ξ`, and (★) is then applied with `ω ~ μ`. That is legitimate **only because** `law(ω | ξ) = μ`, i.e. because of (iii). If `T ∩ P ≠ ∅` then `ξ = O|_T` and `ω ⊇ O|_P` share a coordinate; conditioning on `ξ` changes `ω`'s law; and (iv′), stated for the unconditioned `μ`, no longer supplies what the proof consumes. Putting the overlap event into `B` does not help, because `B` is quantified inside the experiment whose measure has already shifted.

**Evidence that this is not pedantry.** The memo's own C7 tests only a *total* coincidence — the challenge query point **equals** the generator refill point — and reports TV 1 there, TV 0 when separated. That is an all-or-nothing picture and it invites the reading that a small overlap probability buys a small distance. It does not. [COMPUTED, check **B3**] With `|C| = 4`, a protocol whose per-`ρ` joint law is witness-free at **every** `ρ`, and a challenge source that leaks **one bit** of the prover's pad:

| leak from `ω` into `ξ` | per-`ρ` TV | adaptive TV |
|---|---|---|
| none | 0 | **0** |
| one bit of the pad | 0 | **1** |
| the whole pad | 0 | **1** |

One bit is already fatal. So "(iii) holds except with probability `Pr[B_sep]`" is not a statement the lemma can consume, and `2^-241.42` is not the price of a small failure of (iii) — it is the price of a *different* argument.

**The smallest repair, and what it costs the headline.** An explicit game hop, before S-H′ is applied:

> **Game 0** — the real experiment, one oracle `O`.
> **Game 1** — two *independent* oracles `O_T`, `O_P`, the prover's transcript queries answered by `O_T` and its commitment/generator queries by `O_P`.
> The two games are identical until a transcript-class input equals a prover-class input, so any distinguisher's advantage differs by at most `Pr[B_sep]`.
> In Game 1, hypothesis (iii) holds exactly, and Theorem S-H′ applies.

Numerically nothing changes (2^-241.42 at the untagged toy; 0-by-assumption under D19a). What changes is the claim in §0 bullet 1 and §5.1: the composition is (L0), but **the model in which its hypothesis (iii) is true is reached by one (L1) hybrid hop** — a hop of exactly the kind Route A is made of. The memo's §3.8 table should gain a row saying so, and its "Two terms leave the tally and none joins it" should say "and one hop is added".

---

### B-2 — the enumeration of the prover's oracle-query kinds is incomplete on the production path. At least two further kinds exist, and one of them is exactly 64 bytes — the salted-leaf/node length — twice per block. SERIOUS

**The memo's text.** §1.3: "*the **prover class** `P` — the salted-leaf inputs (`digest ‖ salt`, 64 bytes), the Merkle node inputs (64 bytes), the column digests (`8·rows` bytes), and the generator's refill inputs (`key(32) ‖ le64(counter)(8)` — exactly 40 bytes)*". §6.2 invites exactly this attack: "*Is the partition of §1.3 exhaustive of the prover's queries at `8c5922b`? I checked the five kinds I list; a sixth kind … would put a prover query into the transcript class and break the independence with no term to pay for it.*"

**What a full call-site inventory of the tree at `8c5922b` returns.** Not exhaustive of every consequence, but exhaustive of the call sites:

| # | site at `8c5922b` | input | length | mode | in the memo? |
|---|---|---|---|---|---|
| **(a)** | `zkp-core/src/rng.rs:45-51` `ZkRng::from_entropy_reader` (via `from_os`) — the **generator's SEED derivation** | `b"hashline-zk-os-rng/v1/"(22) ‖ domain` | `22 + \|domain\|`; at the general endpoint the domain is 42 B → **exactly 64** | **keyed under the fresh secret 32-byte OS entropy** | **NO.** The memo counts only the *refill* |
| **(b)** | `zkp-core/src/transcript.rs:30` `Transcript::new` / `:41` `new_tagged` — the **transcript constructor** | `b"hashline-v1/"(12) ‖ profile` | `12 + \|profile\|`; toy 51, 125M run profile **46** | unkeyed (legacy) / **keyed under the SAME transcript key as absorbs and squeezes** | **NO in §1.3**; the memo's §4 row (iii-a) does cite finding F-2 and condition C-H4′, so the memo half-knows |
| **(c)** | `private_block.rs:511`, `layout.rs:1288`, `run.rs:220`, `run.rs:285`, `boundary.rs:210`, `endpoint_g.rs:157`, `private_seam.rs:115`, `private_block.rs:221` — statement / schedule / spec digests and the calibration identity | domain-prefixed framed public data | 30 … thousands | **unkeyed even at a tagged profile** | **NO** |
| (d) | `zkp-core/src/hashtag.rs:95-98` | `blake3::derive_key(CTX, profile)` ×4 | — | BLAKE3's **third mode** | no |

**Why (a) is the sharp one.** `endpoint_g.rs:224` calls `ZkRng::from_os` with a 42-byte domain, from `private_block.rs:757`, **twice per block on the production path**. `22 + 42 = 64` — the salted-leaf and Merkle-node length. The memo's separation argument at an untagged profile is a **length** argument: "*A random oracle's restrictions to disjoint input sets are independent random functions; that — not an extra assumption — is what supplies (iii-a)*". By length, this query is in the same class as every leaf and node. What actually separates it is BLAKE3's **key** — it is `new_keyed(&entropy)`, so it is a different function under convention **V-2**. That is fine, and the memo already prices `ε_gen`'s "*two routes, the key and the OS entropy*", so it knows the query exists. But the partition of §1.3 does not contain it, and the argument that separates it is not the argument §1.3 runs. **This is the sixth kind the memo asked the checker to look for.**

**Three smaller consequences.**
* (b) is the transcript constructor. At a tagged profile it is **keyed under the transcript key** — same oracle instance as the absorbs and squeezes — and its format is neither. `12 + |profile| = 47` at a 35-byte profile would make it length-identical to the squeeze class; the two 35-byte profiles in the tree are refused before a transcript is built, and no production profile is 35 bytes, the closest being the 125M **run** profile at **46**. That is finding F-2 and ruling H-8's one-line test; it belongs in §1.3, not only in the §4 table.
* The run's accepted residual table already carries a row **B10, "constructor-vs-absorb"**, at `(A + q)·2^-256 = 2^-128.00`, added by the run check as its B-7. The memo's §5.3 does not carry it (see B-5).
* **Claim N5 is false crate-wide.** "40 bytes is used by nothing else on this path" is true on the path; but `boundary.rs:604` and `stable_weight_material_tests.rs:119` build `Transcript::new` on 28-byte domains, i.e. `12 + 28 = 40` bytes **unkeyed**, in files that also drive `ZkRng`. Test-only — but the memo's §2.2 makes the 40-byte claim load-bearing "at the toy and at a run alike", and the run memo's own rider (ii) about a legacy-rule profile proved on the same machine is exactly this attack shape. At the two legacy-rule profiles (`shape.rs:549-551`: the frozen toy and the frozen-seam rung) the **entire unkeyed oracle is shared** by classes T, P, the constructor, every statement digest, the whole layer/pass path, `private_attention`, `private_seam`, the public receipts, `pcs_compact`, `wcache` and `stable_weight_*`.
* **The position tag re-issues the live chain's next two squeeze inputs verbatim.** `clone_state` copies state, counter **and** key (`transcript.rs:153-163`, comment cites ruling T-7); `position_tag` squeezes twice off the clone (`run.rs:396-411`). Those two 47-byte inputs are the same oracle points the live transcript will query next if no absorb intervenes. Row (iii-c) is still right — a tag is a published challenge, not a message — but any *distinct-query* count, including `B_sep`'s and `ε_hit`'s, must say so.

**Repair.** Add (a) and (b) to §1.3 with their separating arguments named (V-2 for (a), C-H4′/F-2 for (b)); add (c) as a third class with its own disjointness condition; correct claim N5 to "on this path, and not crate-wide"; add one sentence on the tag's repeated squeeze inputs.

---

### B-3 — GAP S-1 is under-sized, and the memo's reason for believing it is exactly the reason it is missing. It is not a bookkeeping sentence; it is the project's own "one candidate with no structural answer". SERIOUS

**The memo's text.** §3.6 Repair 3: "*The field view never mentions a salt, so I believe the conditional form is immediate; **but it is not written in either document, and I will not write it for them.** What is owed is one sentence in each: 'the theorem's randomness is the blinding stream, and the statement holds conditionally on the salts, which are independent of it.'*" §8: "*That is GAP S-1, and it is a bookkeeping gap, not a loop.*"

**What the cited documents actually say.**

1. Theorem 3.3's probability space is **`α, π, μ`, i.e. blinding families B1–B9, only** (`ZK60_JOINT_LAW_COMPOSITION.md` §3.3 setup). **B10, the leaf salts, is in the blinding table but not in the partition**, and is the only family marked *published*: "`B10 | the 5 × 2,048 / 4,096 leaf salts | — | 32 B each | **yes**, for the 256 opened leaves per commitment`".
2. The conditional sampler "*takes no witness, no pad, no mask, no salt*" and "*produces no roots, no salts and no authentication paths. It is a field-view sampler.*"
3. The salts sit on the **conditioning side of the hash-layer assumption (H6)**, not inside Theorem 3.3: "(H6) … *the conditional law of (the three roots, the 5 × 256 authentication paths) **given** the field view **and the published salts** …*".
4. And, decisively, the block memo's own counterexample-candidate table, **row 6**: "`A`'s 256 **published salts**, drawn from the same stream that later produces `H`'s pads | the receipt, and (secretly) `H`'s pads | **only** assumption M-3 in its two-sided, whole-stream form (ruling C-3). **This is the one candidate with no structural answer**". §8 Q6: "*Those three come from **one** BLAKE3 stream as disjoint consecutive segments, so `α`, `π` and `μ` are independent only under M-3 (and `A`'s 256 salts are published before …)*".

So: the field view's not mentioning a salt is not evidence that the two are independent — the salts and the blinding are **consecutive segments of one stream**, and the project has already identified their independence as its single structural hole. The memo's "*I believe the conditional form is immediate*" is the wrong word, and S-1 is mis-sized as bookkeeping.

**S-1 is under-sized in a second direction too.** The assembly needs
`law(V, H, 1_{¬B} | ρ, w)` witness-free — the *joint* law of the field view, the hash objects **and the flag**. The memo asks only the two **field** theorems for a sentence. `Lemma H` / `Lemma H^run` owe one as well: their conditional kernel must stay witness-free after conditioning on `¬B_samp` (a blinding-stream event) and `¬B_sep`. And the hash half is weaker than the memo's §4 row ("Lemma H … core accepted") admits: Lemma H **is** (H6), and its own memo says "***Nothing above turns (H6) into a theorem: it is a statement inside an assumed model***" (§5.2), listing it as a gap.

**Repair.** Re-size GAP S-1 to three owed sentences — one from each field theorem, one from each hash lemma — and name M-3's two-sided whole-stream form (ruling C-3) and §5.3 row 6 as the only thing standing behind the salt/blinding independence, at a run gap **G-R4**. Delete "immediate".

**Answer to the brief's question 3, plainly.** (iv′) does **not** follow from Theorem 3.3 / Theorem B as accepted. The owed sentence, written out:

> *For every admissible `w` and every `ρ` with `NR(ρ)`, the joint law of (the field view `V`, the published salts, the hash objects `H`, and the indicator `1_{¬B}`) is the same for all admissible `w` — where `B = B_samp ∪ B_salt ∪ B_logup`, the theorem's blinding randomness is uniform **conditionally on `¬B_samp`** under the coupling of B-4, and the salt segment of the generator's stream is independent of its blinding segments (assumption M-3 in its two-sided whole-stream form, ruling C-3; at a run, gap G-R4).*

Of that sentence: the conditional-uniformity clause is **new but elementary** (B-4); the salt-independence clause is **not new mathematics but the strongest possible use of the project's weakest assumption**, and the project has explicitly recorded it as having no structural answer.

---

### B-4 — Repair 1 is correct for one specific coupling and wrong for a generic one. The memo does not say which. MEDIUM

**The memo's text.** §3.6 Repair 1: "*`fp()` reduces a uniform 128-bit integer mod `p` (`rng.rs:73-77`), a law at total-variation distance exactly `2^-96` from uniform on `Fp`. By the coupling lemma there is, for each draw, a coupling of the real draw and a uniform one that agree except with probability `2^-96`.*"

**Why "the coupling lemma" is not enough.** The assembly then needs Theorem 3.3 to apply *conditionally on `¬B_samp`*, i.e. hypothesis (H5) — "`α`, `π`, `μ` mutually independent and `α` uniform" — must survive the conditioning. Under a generic **maximal** coupling it does not: conditioned on agreement the common value is distributed as the normalised minimum of the two measures, which is **not uniform**, and Theorem 3.3's fibre-count step (H2) then fails.

**What does work, and it keeps the number.** The rejection-region coupling native to `fp()`. Let `k = ⌊2^128/p⌋`, `r = 2^128 − kp`, `U` uniform on `[0, 2^128)`, real value `X = U mod p`; define the ideal value `Y = X` when `U < kp` and a fresh independent uniform when `U ≥ kp`; set `B_samp = {U ≥ kp}` (per draw, union over draws). Then `Y` is exactly uniform, `Pr[B_samp] = r/2^128`, and — the point — **conditionally on `¬B_samp` the value `U mod p` is exactly uniform on `Fp` and the draws stay independent**, because `kp` is a multiple of `p`. (H5) survives the conditioning. The number is unchanged: the memo's `2^-96` per draw is the same `r/2^128`, `327,052 · 2^-96 = 2^-77.681` toy and `109,728,784 · 2^-96 = 2^-69.291` run [COMPUTED].

**Repair.** One sentence naming the coupling, plus the observation that the conditional law is still uniform. Without it, Repair 1 does not deliver (iv′).

---

### B-5 — "Two terms leave the tally and none joins it" is measured against a tally that is not the project's. MEDIUM

**The memo's text.** §3.8: "***Two terms leave the tally and none joins it.*** *No total moves.*" §5.3 lists eight rows and two struck-through ones.

**What the project's tables carry that §5.3 omits.** From the run memo's accepted residual table (§6.2, reproduced independently by its check):

| row the memo omits | formula | 125M `L = 12` | does it drop under Route B? |
|---|---|---:|---|
| **constructor-vs-absorb (B10)** — added by the run check as its B-7 | `(A + q)·2^-256` at `q = 2^128` | **2^-128.00** | presumably yes, by the same argument as B4/B6 (both inputs are transcript-class; a collision is transcript binding, i.e. soundness) — **but the memo must say so** |
| **tag-key collision** (ruling H-4) | `C(12, 2)·2^-256` | **2^-249.96** | **no** — it is D19a/V-2 bookkeeping, which Route B leans on *harder*, not less |
| **key collision** (tag key = a generator key) | `3·4·2^-256` | **2^-252.42** | **no**, same reason |

and from the toy table: **leaf input = node input** (C-4, ruling L-7) at 2^-484.83, and the **generic-rank term `Δ_gr`** — "0 on the accepted structural route; ≈ **2^-56** on the fallback if its structural step is rejected". That last one is the only term in the corpus that would *dominate* 2^-77.7, and a page that reprints the tally should carry it even at 0.

**Totals are nevertheless right.** [COMPUTED, check **E1**] Summing the memo's own rows: toy **2^-77.6808**, run **2^-69.2906**, against the memo's 2^-77.70 and 2^-69.29 and the run memo's own `−69.2906`. Every individual figure reproduces to two decimals — `B_samp` (2^-77.681 / 2^-69.291), `B_salt` (2^-229.830 / 2^-214.523), `ε_hit` (2^-114.415 / 2^-106.762), `ε_gen` (2^-125.415), the liveness rates (2^-62.000 / 2^-58.791), and the dropped B3 (2^-116.034). **One figure is not recomputable from the memo**: B4/B6, the absorb-input collision at 2^-233.07, because neither the memo nor the toy memo states the absorb count `A` — the toy memo says outright "*I have not counted them exactly, and say so*". The second-largest distance term at 125M is 37 bits below the sampler, so nothing on this page can move a total, which is what the memo claims and what I confirm.

---

### B-6 — the memo carries **both** sides of the one-bit LogUp trap the run check explicitly warned about, inside one document, and attributes the doubled figure to a ruling that has no factor 2. MEDIUM

**The memo's text.** §2.5 table: "*a zero LogUp denominator … — `2^-118.4` per block, `2^-114.8` for a twelve-block 125M run*". §3.7 row R-a and §5.3: "*`2·768/|Fp2|` = **2^-117.42** per block (ruling S-4); `2·L·768/|Fp2|` = **2^-113.83** at `L = 12`*".

**The resolution.** Ruling **S-4** (`ZK60_GENERIC_RANK_LEMMA_SHAPED_DISPOSITION.md` §2) rules the **one-sided** figures: "`768 / p²` and `12 · 768 / p²`", i.e. 2^-118.415 and 2^-114.830 [COMPUTED]. The run memo's §5.2 discharge uses **twice** them and says why: "*The constant is 2, not 1, because the conditioning event itself differs between the worlds in the LogUp class (the toy's correction C-8, unchanged).*" And the run CHECK flagged this exact hazard as **B-12c**: "*Beware a one-bit reading trap … §6.2's table prices the S-4 row at `L·768/|Fp2|` — the one-sided figure — while the discharge above uses **twice** it … the two are named here so nobody adds them twice.*"

So the memo's **numbers are correct** (the doubled figure is the distinguishing bound, and the toy residual table's own parenthetical "(2^-117.4 counting distinct)" agrees), but it **reproduces the trap internally** — one-sided at §2.5, doubled at §3.7 and §5.3 — and it attributes the doubled figure to ruling S-4, which has no 2. Its parenthesis "*(D22's own statement carries the coarser raw count, 2·2^-112.0)*" also adds a factor 2 that D22's sentence does not have ("up to 2^-112").

**The factor 2 is forced, not decorative** — worth saying because a reader who "simplifies" to S-4's figure gets a **false** bound. [COMPUTED, check **C4**] On an 8-value LogUp-shaped instance (refuse iff the challenge equals `g(w)`), over every schedule:

| flag | max (TV − bound) |
|---|---|
| `B = B_w ∪ B_{w′}` (the memo's union) | **0** — bound holds, tight |
| `B = B_w` (single world) | **+3/8** — bound **VIOLATED** |

The union flag is required for (iv′) to hold at all. The memo never explains why the 2 is there.

**Repair.** One sentence in §3.7 R-a: "the factor 2 is the union of the two worlds' refusal events, which (iv′) requires; ruling S-4's figure is the one-sided count, and the run check names this as trap B-12c." Make §2.5 quote the same convention.

---

### B-7 — a hypothesis the lemma cannot do without is not in the numbered list: **every absorbed word must be public**. It is smuggled into Definition 1.4 and appears only as code row (iii-d), "spot-checked here". MEDIUM

**The memo's text.** Theorem S-H is stated on "(i), (ii), (iii), (iv)". Definition 1.4 quietly does the work: "*A challenge schedule is a family of deterministic maps `χ_j : (public prefix) → C`*". §4 tracks it as row **(iii-d)**, status "**CODE FACT**, spot-checked here; the exhaustive reading is the toy memo §3.1 and run memo §1.2".

**Why it is a hypothesis.** Lemma P's `ρ^ξ(m)` is *defined* by `ρ^ξ(m)_i = χ_i^ξ(m_{≤i}, ρ^ξ(m)_{<i})`. If `χ` reads anything not in `m`, `ρ^ξ(m)` is not even well defined, and (★) is false. [COMPUTED, check **B5**] A one-round protocol with per-`rho` TV **0** — hypothesis (iv) holds *exactly* — in which `χ` reads one unpublished absorbed word has adaptive TV **1**. The numbered list (i)–(iv) does not exclude it.

**Why it matters here and not in the field-only lemma.** The field lemma's messages were the whole published view by construction. This protocol absorbs a header (`protocol.rs:113-123`, `run.rs:315-320`) whose `expected-IO` carries both external endpoint roots — objects that are simultaneously (1) the seal that fixes the witness, hypothesis (ii), and (2) published hash objects whose law must be witness-free, hypothesis (iv). The memo never notices that the same object is doing both jobs, which is fine (a commitment binds and hides) but should be said.

**Repair.** Promote publicness to **hypothesis (0)** in the theorem statement; leave row (iii-d) as the code obligation and mark it *not* exhaustively read on this page. §6.2 tells the checker to attack Lemma P part 3's quantifier; the actual weak point is one definition upstream.

---

### B-8 — hypothesis (ii) is not needed for the conclusion, and the soundness appeal in §4 row (ii) is both unnecessary and a category error. MEDIUM

**The memo's text.** §4 row (ii): "***CODE FACT for the input plane; COMPUTATIONAL for the interior.** The interior chain is fixed **because** the endpoints are committed and the relations are proved — a **binding/soundness** argument used inside a privacy proof. Soundness has not been reviewed (`FA5`)*". GAP S-4 is then filed against hypothesis (ii).

**Two things are wrong.**

1. **(ii) is not needed.** [COMPUTED, check **B2**] Two *adaptive witness sources* — the stage-1 secret chosen **after** `r_0`, as a function of `r_0` and the source's own seed, which is exactly `RunWitnessSource` being called inside the stage loop (`run.rs:500`, `:512`) — satisfying (i), (iii) and (iv) at every `ρ`, give **adaptive TV 0** over every schedule. An adaptive source folds into the message maps and causality is untouched. (ii) is a **well-posedness** condition: it fixes what the quantifier in (iv) ranges over. Therefore **GAP S-4 is a gap in (iv)**: Theorem B is stated "for every **admissible hidden run input** — the JOINT condition on all `L` stages, ruling R-1.1", and a chain assembled adaptively is outside that quantifier, so Theorem B simply does not cover it. Filing S-4 under (ii) points the integrator at the wrong obligation.
2. **The binding argument is unnecessary.** In the privacy game the prover is **honest**. Given the input plane, the honest prover computes the whole interior chain deterministically — no binding, no soundness, no FA5. Soundness would be needed only if an adversarial prover could produce a different interior chain for the same sealed plane, which is not the game. Importing an unreviewed soundness property into a privacy proof would be a genuine defect; here it is simply not needed and should be struck.

**Repair.** Restate row (ii) as: "(ii) holds by the quantifier of the privacy statement. The residual obligation is that the *deployed* interface cannot be used outside that quantifier — condition C-R3, a gap in (iv)'s admissibility set, owed by the integrator." Delete the soundness sentence.

---

### B-9 — "proved in a weaker model (L0)" is oversold. Measured honestly, the model is not weaker; it is re-partitioned, and the gains lie elsewhere. MEDIUM

**The memo's text.** §0 bullet 1: "***The composition itself needs no idealisation of the hash at all.*** *It needs one thing: that the function answering the challenges is independent of the dice the prover rolls.*" §5.1 table: "*the ROM used for three priced quantities only (§3.7)*". §3.7: "*exactly three quantities need (L1)*".

**Why it is oversold.** `ω` is *defined* (§1.1) to contain "*the answers of every oracle the prover's own hashing uses*". With a real, fixed BLAKE3 there are no such answers: the prover's hash parts are deterministic in `(w, ω)`, `ξ` is a constant function, and (iii) is vacuously true — but then (iv′) would have to hold for real BLAKE3, which no project document claims and which `Lemma H` explicitly does not. So the model in which (iii) is a *substantive* hypothesis is the model in which the oracle is ideal. Add B-1's hybrid hop and the count becomes: **(L1) is needed for hypothesis (iv′) itself** (Lemma H = (H6), "*a statement inside an assumed model*"), **for one hybrid hop to reach (iii)**, and for the three priced quantities. "Three priced quantities only" is not true of the statement as a whole.

**What is genuinely gained over Route A — stated without salesmanship.**
* The **view-level** conclusion needs no replacement of challenges by uniform values. Route A's hop `G_6 → G_7` disappears; only *one probability*, `Pr^ξ[B_logup]`, still needs uniformity (R-a).
* No lazy sampling of the whole oracle inside the composition (only inside Corollary S-H″).
* The conclusion holds **per realization of `ξ`**, which is a real strengthening and is exactly why `B3/B5` (the distinguisher pre-querying a challenge point) legitimately drop: giving the distinguisher all of `ξ` is free.
* The argument is short enough to check. Route A is ten hops and its own disposition says "***one hop of the hybrid is missing***".

**Does D22's step 5 end up on more assumptions, fewer, or the same?** The same *set* — D19/D19a, V-1, V-2, M-3-or-`ε_gen`, D9 — differently distributed, **plus one requirement Route A does not visibly make**: the sub-measure form of (iv′), i.e. the S-1 sentence (B-3). Route A's hops need only a chain of pairwise distances; Route B needs the joint law of *(view, flag)*. So until S-1 is discharged, moving step 5 to Route B would rest step 5 on **more**, not less. After S-1 is discharged it rests on less. That is the trade, and the memo should print it.

One more thing the memo drops: §3.8 row 3 says the squeeze counter's distinctness is "*not needed for the composition … still needed for R-c's book-keeping and for soundness*". It is **also needed for R-a**: pricing `Pr^ξ[B_logup]` in the ROM requires each challenge point to be fresh.

---

### B-10 — `Pr^ξ[B]` is not defined when the run stopped before that challenge was drawn. No soundness hole; a factor-2 ambiguity in the stated bound. MEDIUM-LOW

**The memo's text.** §3.3: "*where `Pr^ξ_w[B]` is the probability of the flag **in the adaptive run***", with (iv′)'s flag declared "*measurable with respect to `(w, ω, ρ)`*" for `ρ ∈ C^N` — the **full** vector. Lemma P part 3 is stated only for events that are "*the same measurable rule of `(w, ω, the challenges seen)`*".

**The gap and the good news.** If `B` reads a component of `ρ` at a round the adaptive run never reached, "the probability of the flag in the adaptive run" has no referent. [COMPUTED, check **C3**] I built a two-round instance where (iv′) **holds** under a non-adapted flag, half the runs abort before `ρ_1` is drawn, and the true adaptive TV is `1/2`:

| completion of the undrawn `ρ_1` | `Pr^ξ[B]` | bound `½(·+·)` | true TV |
|---|---|---|---|
| pad with 0 | 1/2 | **1/2** | 1/2 (tight) |
| pad with 1 | 1 | **1** | 1/2 (loose by 2×) |

**0 violations in 256 checks** over every schedule × every completion. The theorem is safe — quantifying (iv′) over the **full** `C^N` is exactly what rescues a non-adapted flag, since the constraint at the completions where `B` is false already pins the truncated tuples. But the bound's *value* moves by a factor 2 with the convention.

**Repair.** One sentence: "`B` is required **adapted** — it may read only the challenges drawn — or, equivalently, fix any completion of `ρ^ξ(m)` past the abort and read `Pr^ξ[B]` under it; (iv′) is quantified over all of `C^N`, so the choice is free and the smallest completion is the sharpest."

---

### B-11 — the machine evidence never leaves ONE challenge round, so the *sequential* part of the sequential-kernel lemma is untested in it. LOW (the claim survives my test)

[COUNTED] Every protocol in `results/zk60_sequential_kernel_lemma_hashed/sequential_kernel_hashed.py` is built as `Protocol(..., [m0, m1])`, i.e. `rounds = len(rules) − 1 = **1**`: `salted_leaf_protocol`, `random_masked_protocol`, `hash_mask_counterexample`, `leaky_on_hit_protocol`, `refusal_steering_protocol`, the C7 separation protocol. C8 has no rounds. Also, C2 is tautological on instances constructed to satisfy (iv) exactly, and C8's bound `q·N/|S|` already exceeds 1 at `q = 1`, so it cannot fail.

**I filled the gap and the lemma survives.** [COMPUTED, checks **A1/A2/A3**] Two-round `(field, hash)` protocols (256 `ω`, 20 challenge slots) and a three-round protocol with a challenge-driven abort (34 slots), 4,101 schedules each — a fixed-seed uniform sample plus four named adversarial schedules (constant; **read the hash part only**; read a bit of the previous field message; round-parity) — and an abort protocol with both a `ρ`-only and an `ω`-only refusal: **0 path-identity mismatches**, max per-`ρ` TV 0, max adaptive TV 0, in Game ⊥ and Game prefix alike, under every completion of a truncated `ρ`.

**Two things my multi-round instances add to the memo's negative findings.**
* [COMPUTED, check **C1**] The blow-up of the naive approximate form at **two** rounds is `|C|^2`, not `|C|`: ×4, ×9, ×16 at `|C| = 2, 3, 4`. The memo's prose says "in the worst case by the number of reachable challenge vectors" and is right; its evidence measured only the one-round case, so the headline "blow-up exactly `|C|`" understates its own finding.
* The memo states **no** correct approximate form. One falls out of the same identity and is worth printing beside K-0: `d(law A(w), law A(w′)) ≤ Σ_{reachable ρ} d(law F(w,·,ρ), law F(w′,·,ρ))`, hence `≤ (#reachable ρ)·δ`. Verified and **tight in every row** of my C1.

Two smaller things: [COMPUTED, check **D2**] Corollary S-H″ survives an *optimal adaptive* `q`-query distinguisher (exact dynamic-programming optimum over the posterior), which the memo's C8 did not test — it fixes the query set in advance and asserts "*which for one leaf is without loss*". And the memo's C6 reproduces exactly; I confirm adaptive TV **1** under a constant challenge function at `|C| = 4, 8, 16`.

---

### B-12 — claim S-6 is confirmed, and one thing beyond it must be said: under Game ⊥ the abort *indicator* is inside the view. LOW

[COMPUTED, check **D1**] For **one and the same protocol** — masked `m_0`; `m_1` masked when `r_0 = 1` and raw when `r_0 = 0`; a challenge-driven refusal at round 2 firing exactly when `r_0 = 0`:

| | per-`ρ` view TV, Game prefix | per-`ρ` view TV, Game ⊥ | adaptive TV, prefix | adaptive TV, ⊥ |
|---|---|---|---|---|
| masked variant | 0 | 0 | 0 | 0 |
| leaky variant | **1** | **0** | **1** | **0** |

So claim S-6 is right and sharp: hypothesis (iv′) holds at every `ρ` under Game ⊥ and fails at the challenge-refused `ρ` under Game prefix, and the adaptive conclusion follows the hypothesis. **Game ⊥ is load-bearing, and GAP S-3 is a real obligation** — ruling H-2 records that rule M-9 has no production code at `8c5922b` (`prove_run` has no production caller; `verify_then_write` is test-only), while segments are fsynced and renamed into place as they are made (`run_sink.rs:181-203` from `run.rs:568`). Game ⊥ for a run is a rule about what is *transmitted*, not about what is on disk.

**Beyond S-6.** Under Game ⊥ the distinguisher sees whether a receipt exists at all, and that indicator is *inside* the view. [COMPUTED, same check] A protocol with a perfectly masked prefix and a refusal rate of `w/4` has Game-⊥ adaptive TV **1/2** — exactly the gap in refusal rate. Nothing in the lemma hides it. The memo's line "*a **liveness** figure, never a distance*" for the challenge-driven class is therefore valid **only because that class is a function of `ρ` alone**. I read the code for two of the four: `check_opening_challenges` (`protocol.rs:283-294`) refuses on a zero drawn group coefficient or a zero determinant of two drawn proximity coefficients — both functions of the drawn challenges and of public layout data, so ✓ CODE FACT for those two. The other two (`c_s = 0`, `e ∈ {0,1}`) I did not read. The classification deserves a line-by-line check, not an assertion, because if any of the four also reads `ω` or `w` it becomes a **distance** term. (For context the memo does not restate: the run documents concede that on an **inadmissible** chain the refusal indicator is 0-or-1 in the hidden data, observable, and "*outside every statement the project has*" — sealed off by a quantifier, not bounded by the model.)

---

### B-13 — citation and vocabulary defects. LOW

* "*ruled last night to be **the** remaining gap for a run as well (`ZK60_HASH_LAYER_AND_FS_LIFT_RUN_DISPOSITION.md` §3, gap **G-H1**)*" — §3 of that disposition is headed "**The gap that remains: O-4, the sequential composition**" and **never uses the label G-H1**, which is coined in the RUN *memo* §4.5. Substantively right, bibliographically loose.
* "***Game ⊥** (the one the project's statements use, decision **D21** and operating rule **M-9**)*" — `grep` for "Game ⊥" and "Game prefix" over the run memo, its check and its disposition returns **zero hits**. Both names are this memo's own coinage, presented as project vocabulary. The substance (D21/M-9 make it a ⊥-game) is correct.
* "*ruling **S-4**" attached to the doubled figures (see B-6).
* "*(D22's own statement carries the coarser raw count, 2·2^-112.0)*" — D22 says "up to 2^-112", without the 2.
* §5.1's "*the refusal sentence: unchanged by this page*" is right, but the accepted clause reads "a function of the verifier-visible **random** challenges alone", and that word is supplied by Route A's uniform-challenge hop. Under Route B it is supplied only by R-a, which needs (L1) **and** the squeeze-input distinctness §3.8 lists as unneeded. Say so.

---

## 3. Where I attacked hardest and found nothing

I record these because a check that only lists faults is not a check.

* **Lemma P part 3 is a genuine set equality**, not merely an equality of probabilities. Forward: causality makes the adaptive run's drawn challenges equal `ρ^ξ(m)`'s prefix, so the fixed run at any extension reproduces `m`. Backward: if `F(w,ω,ρ^ξ(m)) = m` then the challenges `F` was handed are by construction the ones `χ^ξ` would have produced along `m`, so the adaptive run produces `m`. The sets `{ω : A has messages m}` are disjoint and cover `Ω`, and therefore so are their images. **Nothing in the identity cares that `χ_j` reads the hash part of `m_j`, nor that the hash part is an oracle image of `ω`'s salts** — `ξ` is *fixed*, and the evaluation *points* being `ω`-dependent is exactly the harmless dependence the memo's note 3 names. This is correct and it is the best paragraph on the page.
* **The one line doing the real work**, `Σ_m Pr_ω[F(w,·,ρ^ξ(m)) = m, B] = Pr^ξ_w[B]`, is sound: the events `{A has messages m}` partition `Ω`, and (★) applies term by term. Modulo B-10's convention, there is no double-counting and no under-counting — including when two different `ω` give the same transcript `m`, because the flag is evaluated on `(w, ω, ρ)` and the identity is between *sets of `ω`*, not between transcripts.
* **The abort sub-space.** [COMPUTED, check **A2**] The identity is insensitive to the completion of `ρ` past an abort, in both games, over every schedule.
* **`ε_hit` and the `Q_pub`/`Q_hid` split.** The proof sketch's "randomized functions do not increase total variation" survives adaptive querying in my instances; the classification of *opened* columns' leaves and paths into `Q_pub` is right (the verifier recomputes `salt_leaf_keyed(hash_column_keyed(col, K_C), salt, K_L)` before walking the path).
* **Dropping B3/B5 is legitimate**, and for exactly the reason given: the conclusion is conditional on the **whole** of `ξ`, so a distinguisher that pre-queries the challenge oracle learns nothing new. This is a real and clean gain over Route A.
* **Dropping B4/B6 is legitimate** for the composition: `χ_j` is a function of the prefix whatever the state chain does, and transcript-binding collisions are a soundness matter.
* **Repair 2 is exactly right and costs nothing** — replacing "two salted-leaf *inputs* coincide" (witness-dependent) by "two salts coincide" (witness-free, `ω`-measurable) preserves the published figure because that figure was already `C(N_leaf,2)·2^-256` over uniform salts: 2^-229.830 / 2^-214.523 [COMPUTED].
* **Corollary S-H′a's taxonomy is correct and useful** — `ω`-only flags cost the same under every schedule; challenge-reading flags do not. It is the right organising idea on the page.
* **The negative findings are real.** K-0 reproduces (blow-up `|C|` at one round, `|C|^2` at two); C6 reproduces (constant `χ` ⇒ adaptive TV 1); C7's point reproduces and is *stronger* than stated (one bit suffices, B-1).

---

## 4. The three necessity questions the brief asked, answered

| hypothesis | needed for the conclusion? | evidence |
|---|---|---|
| **(0) every absorbed word is public** (unnumbered, inside Definition 1.4) | **YES** — and its absence is fatal | per-`ρ` TV 0, adaptive TV **1** [COMPUTED, B5] |
| **(i) causality** | **YES** | a prover reading the challenge that follows its own message: per-`ρ` TV 0, adaptive TV **1/2** [COMPUTED, B1]. The memo never tests this |
| **(ii) witness fixed before `m_0`** | **NO** | two adaptive witness sources satisfying (i),(iii),(iv): adaptive TV **0** [COMPUTED, B2]. It is well-posedness; see B-8 |
| **(iii) `ξ ⊥ (ω, w)`** | **YES, and not all-or-nothing** | one leaked bit ⇒ adaptive TV **1** while (iv) holds at every `ρ` [COMPUTED, B3] |
| **(iv) / (iv′) joint per-`ρ`** | **YES** | marginals-only: adaptive TV 1 [COMPUTED, B4]; the union flag is required [COMPUTED, C4] |

The memo's statement is therefore **not tight**: it lists a hypothesis that is not needed (ii) and omits one that is (0).

---

## 5. Is hypothesis (iii) exhaustive at `8c5922b`? — the enumeration

Summarised from the full BLAKE3 call-site inventory made for this check (every call site in the tree at that commit, with input length, mode and key). The short answer is **no**; see **B-2** for the three extra kinds, the 64-byte production-path seed derivation at `endpoint_g.rs:224`, the two test-only 40-byte constructors, the crate-wide unkeyed digest family, the legacy-rule sharing (`shape.rs:549-551`) and the position tag's repeated squeeze inputs.

Two things the memo gets **right** and that I confirm:
* **No transcript absorb can ever be 47 or 40 bytes.** The absorb input is `48 + |label| + |data|` with `|label| ≥ 1`, minimum 49, realised minimum 57 on the block path. That half of the separation is sound *by construction*, not by luck.
* **`absorb_u64(b"log-cols", ·)` is the only absorb reaching 64 bytes.** Exhaustive over the `absorb_u64` labels on the path (`rows` 4, `log-cols` 8, `pb-slot` 7, `pb-run-stage` 12, `io-side` 7, `pa-slot` 7, `layer` 5, `t_rows` 6, `use` 3, `d` 1, `f` 1), only `|label| = 8` gives `48 + 8 + 8 = 64`. The memo's 2^-241.42 is counting the right object.

The prover does run the transcript itself (`protocol.rs:486-491`, `run.rs:479-505`), so the absorb and squeeze queries are the prover's — which is fine for the memo's bookkeeping, since `ξ = O|_T` is the *function*, not the queries, and the prover's messages depending on `ξ` through the challenges is the harmless direction. That is consistent, and the memo says so.

---

## 6. Does anything ACCEPTED depend on the sentence K-1 corrects? — **NO**

Searched `ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md`, its draft, `ZK60_HASH_LAYER_AND_FS_LIFT_DISPOSITION.md`, `ZK60_JOINT_LAW_COMPOSITION_DISPOSITION.md`, `ZK60_PRIVACY_CASE_FIRST_MVP_DISPOSITION.md`, `ZK60_GENERIC_RANK_LEMMA_DISPOSITION.md` and `ZK60_DECISIONS.md` for `Route A|Route B|need not be uniform|arbitrary challenge|any challenge function|challenge function`.

* **`ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md`: zero occurrences** of "Route", "sequential-kernel", "kernel", "arbitrary", "challenge function". Its step 5 reads "*The hash layer adds nothing, and the fixed-challenge theorem lifts to the hashed protocol — core accepted, in the model of D19*", and its single citation is the **disposition**, not any named Route.
* **`ZK60_HASH_LAYER_AND_FS_LIFT_DISPOSITION.md`: zero occurrences of "Route B".** Rulings L-1…L-7 never mention it. Its verdict names only the ROM route, and says of Route A: "***one hop of the hybrid is missing***".
* The corrected sentence lives in **one place**: §3.3 of `ZK60_HASH_LAYER_AND_FS_LIFT.md`, a row labelled **MIXED / RELIES ON** (§8 row 24, condition O-D), whose own text already records that its lemma lives on another branch.

**Two caveats the memo should print anyway.**
1. The **same sentence** K-1 corrects already names the defect's second half: "*Route B is stronger in one way — it does not need the challenges to be uniform — and weaker in another: it needs the per-`ρ` hypothesis at **every** `ρ` … so Route B still needs §4.*" And the branch lemma's own proof already ends "*witness-dependent refusal events break it (the LogUp collision … at most `(lookups + table rows)/2^128` per proof)*". So K-1's **novelty** is narrower than "the lemma is false": it is that the parenthetical bound in the branch lemma is a **per-`ρ`** count and therefore **cannot** bound the adaptive probability for an arbitrary `H`. That is a genuine and useful sharpening, and it should be claimed as that rather than as a new falsification.
2. D22's accepted refusal clause — "*Whether the prover refuses is, up to 2^-112, a function of the verifier-visible **random** challenges alone*" — is supported by Route A's uniform-challenge hop. If step 5 moves to Route B, that clause needs R-a, i.e. (L1) plus squeeze-input distinctness (B-9). The clause does not change; **what supports it does**.

---

## 7. The arithmetic, recomputed

All from `results/zk60_sequential_kernel_lemma_hashed_check/checks.json`, check **E1**. `p = 2^64` (back-solved from the memo's own `4/p ≈ 2^-62.0`), `|Fp2| = 2^128`.

| term | formula | recomputed | memo | |
|---|---|---:|---:|---|
| `B_samp` toy | `327,052 · 2^-96` | **2^-77.681** | 2^-77.70 | ✓ |
| `B_samp` run | `109,728,784 · 2^-96` | **2^-69.291** | 2^-69.29 | ✓ (and = the run memo's own −69.2906) |
| `B_salt` toy | `C(12,288, 2)·2^-256` | **2^-229.830** | 2^-229.83 | ✓ |
| `B_salt` run | `C(2,473,984, 2)·2^-256` | **2^-214.523** | 2^-214.52 | ✓ |
| `ε_hit` toy | `2^128 · 12,288 · 2^-256` | **2^-114.415** | 2^-114.42 | ✓ |
| `ε_hit` run | `2^128 · 2,473,984 · 2^-256` | **2^-106.762** | 2^-106.76 | ✓ |
| `ε_gen` | `6 · 2^128 · 2^-256` | **2^-125.415** | 2^-125.42 | ✓ |
| `B_logup` toy | `2·768/\|Fp2\|` | **2^-117.415** | 2^-117.42 | ✓ — the **doubled** figure (B-6) |
| `B_logup` run | `2·12·768/\|Fp2\|` | **2^-113.830** | 2^-113.83 | ✓ — doubled |
| ruling S-4 one-sided | `768/\|Fp2\|`, `12·768/\|Fp2\|` | **2^-118.415**, **2^-114.830** | 2^-118.4, 2^-114.8 | ✓ — **the source of the one-bit confusion** |
| liveness toy | `4/p` | **2^-62.000** | 2^-62.0 | ✓ |
| liveness run | `(3L+1)/p`, `L=12` | **2^-58.791** | 2^-58.79 | ✓ |
| dropped B3 toy | `2^128 · 4,000 · 2^-256` | **2^-116.034** | 2^-116.03 | ✓ |
| dropped B4 toy | `C(A, 2)·2^-256` | **not recomputable** | 2^-233.07 | the absorb count `A` is stated nowhere; the toy memo says "I have not counted them exactly, and say so" |
| **TOTAL toy** | | **2^-77.6808** | 2^-77.70 | ✓ |
| **TOTAL run** | | **2^-69.2906** | 2^-69.29 | ✓ |

**Answering the brief's question 5 directly.** `B_salt` uses `N_leaf` = 12,288 (toy) and 2,473,984 (per run, 125M `L = 12`) — the same counts the two memos use for `ε_hit`, and they are the right counts for a birthday bound over salts. The **one-bit LogUp discrepancy is not an error**: it is the memo's union-over-both-worlds definition of `B_logup`, which my check **C4** shows is *forced* — the single-world flag violates the bound by 3/8 on an explicit instance. "Two Route-A terms drop and none is added" is right about the memo's own tally and **wrong about the project's**, which carries three more rows (B-5). The totals do not move.

---

## 8. What I could not check

1. **Whether Lemma H / Lemma H^run is true.** They are (H6) / (H6^run), and their own memo says "*Nothing above turns (H6) into a theorem: it is a statement inside an assumed model*". I take the memo's citation of them at face value; hypothesis (iv′)'s hash half is therefore an **assumption**, not a cited theorem.
2. **The exhaustive reading of "every absorbed word is public"** (my hypothesis (0)). I spot-checked the block and run headers and the root absorbs; the memo defers to the toy memo §3.1 and run memo §1.2, which I did not re-read line by line.
3. **Two of the four challenge-driven refusal classes** (`c_s = 0` and `e ∈ {0,1}`). I read `check_opening_challenges` and confirmed its two are functions of the challenges and public layout data; the other two I did not.
4. **Whether Route A's ten hops implicitly need the same conditional-on-salts sentence.** If they do, B-3's "Route B needs more" softens.
5. **The absorb count `A`**, hence B4/B6 and B10 independently.
6. **Anything at 125M** — G-R3 is blocking and untouched here — and anything about soundness (FA5), out of scope.
7. **Whether `Pr^ξ[B_logup] ≈ 2·768/|Fp2|` is right for the real BLAKE3 challenge chain.** I checked the arithmetic and the argument shape, not the freshness accounting over the actual 23-slot schedule.

---

## 9. What the security owner must rule on — one thing first

> **Is `B_sep` a bad event or a hypothesis failure?** Everything else on this page is a rewrite. This one decides whether the memo's headline survives. My answer is: **a hypothesis failure**, repaired by one explicit `(L0)`→`(L1)` game hop at the same price (B-1). If the owner accepts that, then **the honest form of the claim is: "the composition is model-free; reaching the model in which its hypothesis (iii) holds costs one hybrid hop, and hypothesis (iv′) is an (L1) statement throughout"** — which is still a real improvement on a ten-hop hybrid with a missing hop, and it is still worth building a run's statement on. If the owner instead keeps `B_sep` inside `B`, the memo claims a theorem it has not proved.

Then, in order: **(2)** re-size GAP S-1 to the three owed sentences and strike "immediate" (B-3) — this is the gap that actually blocks, because it lands on the project's one candidate with no structural answer; **(3)** re-file GAP S-4 against hypothesis (iv) and delete the soundness appeal (B-8); **(4)** add the two missing oracle query kinds and correct claim N5 (B-2); **(5)** name the coupling in Repair 1 (B-4); **(6)** fix the one-bit attribution and say why the 2 is there (B-6); **(7)** promote publicness to hypothesis (0) (B-7); **(8)** fix the `Pr^ξ[B]` convention (B-10); **(9)** print the three missing tally rows (B-5); **(10)** re-run the machine checks at two and three rounds, or cite mine (B-11).

**What should NOT change.** Lemma P, Theorem S-H, Theorem S-H′, Corollary S-H′a, Corollary S-H″, Repair 2, claim S-6, the negative findings K-0 and C6, and every number. The page is right about the mathematics it invented and wrong mostly about where its own weight is resting.

---

*Written by an independent adversarial checker who did not write the memo.
Nothing here establishes or withdraws a privacy property. D22 is untouched
and rests on Route A. Evidence:
`results/zk60_sequential_kernel_lemma_hashed_check/`.*
