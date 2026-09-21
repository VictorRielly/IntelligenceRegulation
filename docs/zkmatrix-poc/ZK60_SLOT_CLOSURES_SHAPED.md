# The 23 slot closures at the shaped layouts — the reading owed by gap G-R2

Drafted by a delegated Opus agent for the security owner.
2026-09-21, 00:28 PDT (`date` on the WSL box).
Lane read, read-only, at commit **`8c5922b`** (`/home/victor/wt-zk60-block125m`,
branch `zk60-private-block-125m`, stage 23 ledger).
Evidence and scripts: `results/zk60_slot_closures_shaped/`.

**REVISED after an independent check and the security owner's disposition,
2026-09-21 01:26 PDT: not a privacy claim; the closure property HOLDS WITH
CHANGES; clause C4 holds in a STRONGER form than drafted; clause C1 reworded
for slots 15/16.** The check is `ZK60_SLOT_CLOSURES_SHAPED_CHECK.md`
(findings B-1 … B-8, written by an agent told to assume this page wrong, with
its own ports and seven scripts under
`results/zk60_slot_closures_shaped_check/`). The rulings are
`ZK60_SLOT_CLOSURES_SHAPED_DISPOSITION.md` (C-1 … C-7, §1 and §3). Where the
check's suggested repair and a ruling differ, the **ruling** is what this
page now says. Every label, every gap name and every figure that survived the
attack is unchanged; nothing that survived has been softened and no gap has
been deleted.

**Changes in this revision.**

| ruling | what changed | sections |
|---|---|---|
| **disposition §1** (the check's §0) | **C4 strengthened.** At every SHAPED layout every monomial of all 23 arms carries a public factor, so `poly(exts)` is the ZERO POLYNOMIAL in the prover's values, not merely zero at each honest value; the "other private factor is zero" mechanism is needed only at the toy (`lkv = 0`) | §0, §1.2 C4, §3.2, §3.3, §4.3, §6.1 step 5, §6.2 S-C1 |
| **C-1** (B-1) | slots 14, 15, 16, 18 **DECLARE** degree 5 where the closure's degree is 4 wherever their domain pads; the degree-rise cost split into what the closure needs and what it wastes. **Not changed** — recorded as slack | §3.3, §3.8, §6.1 step 12a, §6.2 |
| **C-2** (B-2) | clause C1 reworded per `Tab::Priv`, not per plane (slots 15/16's flipped rotary partner); ruling S-3 is what keeps their two column keys apart, with 6–8 bits of margin; the checker's flip miniature recorded | §1.2 C1, §3.2, §4.2, §4.4, §6.3 |
| **C-3** (B-3) | gap S-C3(i) restated: **nothing** compares `define`'s literal hosted lists with `HOSTS` at the shaped layouts; a **soundness** matter, not a privacy one; a generic test owed on the lane | §3.8, §5, §6.1 step 8a, §6.2 S-C3 |
| **C-4** (B-4) | the mask budget's "production guard" is a prover-side assertion in `mask_commit`; `Shape::new` has ten refusals and none is the budget; a named refusal owed. Every "panic" is qualified: **no verifier-side panic is reachable from a malformed receipt** | §1.2 C7, §6.2 S-C3 |
| **C-5** (B-5) | §4.2's joint-law sentence corrected for the six **HOST** slots; marginal uniformity by the toy's Lemma 2.2, cited with document and section | §4.2 |
| **C-6** (B-6.1) | the ζ / `mu_pad` count stated once and consistently: **8 and 8** at rung-G and rung-K4, **5** at 125M; ruling R-7 was amended at 00:43 on 2026-09-21 | §3.3, §6.1 step 12a, §6.2 |
| **C-7** | gap S-C1 marked **TAKEN UP** — a Rust test on the lane, owed; under the stronger C4 it can assert identity to zero for arbitrary values | §6.2 S-C1 |
| B-6.2, B-6.3, B-8 | the `mu`-not-refused observation kept, with the check's verdict on why it is soundness-only; the check's own rank figures and its measured C6 on a real bundle recorded; this page's `eq_table_msb` port tested for a bit-order defect and found clean | §3.3, §4.2, §4.3, §4.4, §5 |

*Editor's note on the cross-references.* The disposition cites "C-4 (B-4,
B-5)" and "C-5 (B-6)"; in the check, B-4 is the prover-side guard and the
verifier-panic sweep, B-5 is the joint-law sentence and B-6 is the three
confirmations. Each ruling is applied here to the finding it **describes**,
and the ζ recount of B-6 is applied under C-6.

**§8, at the end of this page, is one line per finding B-1 … B-8** — what
each one changed and which ruling disposed of it.

**This is not a privacy acceptance of anything.** It discharges one
hypothesis of one theorem, at two development shapes and one counted shape.
Register entry D22 (the toy block) is untouched. No run, no development rung
and no 125M block may be called private on the strength of this page.

---

## 0. Plain words, for the security owner

The privacy argument says: everything a proof publishes is either a public
number, or a number that a fresh random pad has made uniform. To say that,
the theorem has to know exactly *what* each of the 23 masked sumchecks
publishes and *how* each published number is padded. That per-slot knowledge
is hypothesis **(H4)**, and its gap is **G-R2**.

At the toy block someone read all 23 slots and checked it. At the shaped
layouts the slots are different functions: six or eight of them carry a
support indicator, five or eight carry a pad-zero term, two were rebuilt last
night with a third factor, one grew a limb, and in a run two of them hang their
padded terminal on a commitment that a *different* stage opens. So the
reading is owed again. This page is that reading.

**The verdict in one line:** the closure property holds at rung-G, rung-K4
and the 125M layout — **holds with changes**, after the check and the
disposition: four of its seven clauses carry a named defect that is
bookkeeping or enforcement and none of them is a break of (H4). **8 of 23
slots carry over verbatim, 3 carry over with a changed count, and 12 needed a
new argument** (the 8 that host a pad-zero term, the 2 repaired bilinear ones
and the 2 boundary ones) — and three things are left open by name (§6: S-C1
**TAKEN UP**, S-C2 **STANDS**, S-C3 **NARROWED**), plus one place where the
code did not match an earlier ruling (§3.3 — **settled**: ruling R-7 was
amended at 00:43 on 2026-09-21 and the count is 8 / 8 / 5).

**The one structural fact a reader should take away.** Every shaped addition
— the support gate, the pad-zero term, the group `eq`, the third limb, the
lifted `Dom::Ht` indicator — sits **inside** a factor that is zero in the
extension round: the slot's own `eq(tau)` or `eq(point)`, or (for the two
bilinear slots) the public group `eq`. That single placement is what keeps
the construction premise true. Move the pad-zero term one bracket outwards
and the premise is false and honest proofs stop verifying — computed, control
C4 of §4.

**And it is true more strongly than this page first drafted it** (disposition
§1, on the check's §0). The placement holds for *every* monomial of *every*
one of the 23 closures at *every* shaped layout: each one carries a public
factor — a `Tab::Eq`, a `Tab::Pub`, or the group `eq` of the two repaired
bilinear slots. So `poly(exts)` is not merely zero at each honest value of
the prover's reserved-pair evaluations; it is the **zero polynomial** in
them. The second mechanism this page also relies on — "the other private
factor is extended in a different round" — is needed at exactly one place in
the whole module: slots 08 and 09 at `lkv = 0`, the frozen toy, where
`group_eq` returns `None`. [Independently COMPUTED by the check,
`premise_cover.py`: **92 of 92** (slot, shape) arms, **600** evaluations at
six random values of the reserved pairs and at both extension rounds of the
bilinear slots, all exactly zero; the negative control — the pad-zero term
moved one bracket outwards — turns the premise FALSE in **21 of 21** pad-zero
arms, so the test is not vacuous.] Nothing here depends on honest behaviour:
`exts` is built by `run_slot` from the DEFINITION (`argument.rs:353-360`, a
hard `Fp2::ZERO` in every table that is not a private table of that round)
and the verifier models the same by multiplying every public table's
main-variable value by `sel = ∏(1 − e_j)` (`argument.rs:383`, `:389-390`). A
malicious prover chooses round messages; it never chooses `exts`.

---

## 1. The closure property, stated precisely, and split into clauses

### 1.1 What the theorem asks

The composition theorem is Theorem 3.3 of
`ZK60_JOINT_LAW_COMPOSITION.md` §3.3, restated for a shaped block as Theorem
A of `ZK60_JOINT_LAW_COMPOSITION_RUN.md` §2.9. Its fourth hypothesis, quoted
from the run memo §2.8:

> **(H4)** — `V(α) = V_pub(V_sc, V_pcs)`, a public function of the already
> published view, and `V` factors through `R` — is Fact 3.2, and at the toy
> it is VERIFIED IN THE CODE *by reading all 23 slot closures*. At a shaped
> layout the closures are different functions: eight of them now carry a
> support indicator, six or eight carry a pad-zero term, two carry the
> grouped-head factor, one carries the third limb. **The reading is owed
> again.**

and the gap:

> **GAP G-R2. (H4) is owed at both new shapes as a reading of all 23
> closures, as the independent check supplied it for the toy.** Twelve of 23
> are machine-confirmed at rung-G on two runs; eleven are not evaluated at
> all; no slot is confirmed at 125M.

Fact 3.2 itself (`ZK60_JOINT_LAW_COMPOSITION.md` §3.2) is three sentences:
the 23 `eval` functional values are `g_s(ρ_full^s) = (fin_s −
poly_s(vals_s))·c_s^{-1}` with `fin_s` read off the published rounds and
`vals_s` built from the published terminals and public quantities; the 5 + 6
`Γ` functional values are the published scalars themselves; therefore `V(a)`
is a public function of the published view. And it needs the

> **CONSTRUCTION PREMISE** (`argument.rs:18-22`): *every slot polynomial has
> a public factor (an eq, a public table, or the other side's zero extension)
> in every monomial, so `poly(extensions) = 0` and the extension round is
> consistent.*

The proof of Theorem 3.3 uses the premise in a stronger form than
"completeness": it needs `T′(w, π) ∈ C` **for every `π`**, not only for the
`π` that arise on runs that verified. I make that explicit below, because it
is the clause the shaped additions actually put at risk.

### 1.2 The clauses

Write `N_s = main_s + ext_s` for the round count, `d_s` for the degree, `L_s
= N_s d_s + 2` for the mask length.

> **C1 — claim placement** (reworded under ruling C-2; the draft said "every
> private *plane*", which is false for slots 15 and 16 — see the note below
> this list). Every `Tab::Priv` a slot **pushes** raises exactly one `ZClaim`
> on its own commitment
> (`argument.rs:411-417`), whose parts are the plane's data slices at the
> claim point with coefficient `cd = ∏_j (1 − e_j)`, plus the two rows
> `(mask_row, mask_row + 1)` with weights exactly `(cm, cm·U)`
> (`argument.rs:274-276`), where `cm = e_r · ∏_{j>r} (1 − e_j)` for a plane
> masked in extension round `r` (`argument.rs:413`). The pair is that
> claim's alone (`protocol.rs:259-263`, `:270-272`), the pair index comes
> from the declared schedule (`layout.rs:1217-1228`), and `cd ≠ 0`, `cm ≠ 0`
> because every extension challenge is refused at `0` and at `1`
> (`argument.rs:404-406`).
>
> **C2 — a public closure.** `def.poly` is a fixed function of the table
> values chosen from the public statement and the transcript challenges
> alone; on the verify side the non-private table values are recomputed by
> the verifier (`argument.rs:385-396`) and the private ones are the published
> terminals, so `g_val = (fin − poly(vals))·c^{-1}` (`argument.rs:397`) is a
> public function of the published view.
>
> **C3 — the declared masking.** The slot's round messages are the honest
> ones plus `c_s · g_s.round(j, ρ_{<j})` for all `N_s` rounds — the `main_s`
> masked rounds through the transcript masker (`argument.rs:349`,
> `zk.rs:1077-1086`, `zkp-core/src/sumcheck.rs:284-294`) and the `ext_s`
> extension rounds through the same mask (`argument.rs:361`,
> `zk.rs:1089-1102`) — with `g_s` the slot's own CFS polynomial of `L_s`
> uniform coefficients, `(N_s, d_s)` the DECLARED pair of `Shape::slots`, and
> `c_s ≠ 0` (`argument.rs:331-334`).
>
> **C4 — the construction premise, in the form the theorem needs.**
> `poly_s(exts) = 0` at every extension round, where `exts` is zero in every
> table position except the private tables of that round
> (`argument.rs:353-360`). Consequence: the verifier's chain accepts the
> unmasked transcript, i.e. `T′_s(w, π) ∈ C_s`, **for every witness `w` and
> every value `π` of the reserved-pair evaluations**, honest or not.
> **In the stronger form the check established and the disposition (§1)
> accepts:** at every shaped layout every monomial of every one of the 23
> closures carries a public factor, so `poly_s(exts)` is the **zero
> polynomial** in the reserved-pair evaluations, not a polynomial that
> happens to vanish at each honest value. The consequence above follows
> immediately, and the second mechanism ("the other private factor is
> extended in a different round") is needed only at the toy's slots 08 and 09
> (`lkv = 0`). [VERIFIED IN THE CODE, 23 arms; COMPUTED, 92 of 92 at four
> shapes, §0 and §4.2.]
>
> **C5 — host discipline.** A Private slot contributes no `Γ` functional
> (`argument.rs:421-432`); a hosted slot's published scalar is consumed by
> exactly one host slot, with coefficient `κ·c_h`, and the hosted mask totals
> cancel exactly between `argument.rs:345` (prover) and `argument.rs:379`
> (verifier); the host runs after the slots it hosts; the hosted list is the
> declared one.
>
> **C6 — nothing else is published.** Slot `s`'s contribution to the receipt
> is exactly `1 + N_s(d_s + 1) + terms_s` `Fp2` words (`shape.rs:938`): one
> mask-bearing scalar, the round messages, and the pair-masked terminals of
> its private tables. No plane evaluation, no honest sum, no helper sum, no
> histogram, and never `g_s(ρ_full)` itself.
>
> **C7 — the mask budget and geometry.** `L_s + 256 ≤ 512` and the slot owns
> rows `2s, 2s+1` of the shape-independent 50-row `M` (`zk.rs:373-375`,
> `:437-447`, `layout.rs:930`). The budget holds at all three shapes with
> room (the worst is `117 + 256`), but **nothing refuses a shape that broke
> it**: the only production guard is a prover-side `assert!` inside
> `mask_commit` (`zk.rs:442`), and `Shape::new` has ten refusals of which
> none is this one — ruling C-4, gap S-C3(ii) as restated in §6.2.

C1 is what the terminal-surjection step consumes; C2 + C4 are Fact 3.2; C3 +
C7 are Fact 2.1 and Lemma 2.2; C5 is the triangular change of coordinates of
§2.2; C6 is the inventory row.

**The rewording of C1, and why it was needed** [ruling C-2, the check's
B-2]. The draft said "every private *plane* a slot reads … raises exactly one
`ZClaim`". Slots 15 and 16 push the **same plane id twice**: the rotary
partner is `b.a_at(ids.at(src), cf, 0)` with `cf = rho(0..log)` and
`cf[log − ldh] = Coord::Flip(log − ldh)` (`argument.rs:1361-1368`, re-read at
`8c5922b`) — same commitment, same slice offset, two claim points differing
in one flipped coordinate, two reserved pairs, two terminals. So a *plane*
can raise two claims in one slot; a `Tab::Priv` raises exactly one. The
clause is true, and the terminal-surjection step consumes it, per `Tab::Priv`.
This page's own §2.2 table already listed the partner as a separate site; it
was the prose that was wrong. The checker built the miniature this page
admitted (§6.3 item 4) it had not built, and every property holds — §4.2.

### 1.3 The three travelling conditions, and where they are met at a shape

`ZK60_TERMINAL_SURJECTION_REVIEW.md` §1.4 and §5 (R-1) fix the conditions
that must travel with the terminals step:

1. **the reserved pair's weight SHAPE `(cm, cm·U)` with `cm ≠ 0`** — an
   `Fp`-basis of `Fp2`, so that the pair's contribution ranges over all of
   `Fp2`. Built at `argument.rs:274-276` at every shape, in a loop over
   `[Fp2::ONE, Fp2::U]`; `cm ≠ 0` from `argument.rs:404-406`. **Shape-free.**
2. **the pair exclusive to that claim and to that group** — `audit_claims`
   `protocol.rs:259-263` ("a claim does not carry exactly its own reserved
   pair") and `:270-272` ("a reserved pair is unused or shared between
   claims"), with the helper commitment's shared zero-sum pair as the one
   stated exception (`protocol.rs:252-258`). **Shape-free**, and the site
   rows are shape-driven (`layout.rs:1217-1228`, prefix sums of the shaped
   `claim_sites`).
3. **the pad budget** — `ZkOpts::standard` sets `q_pad = num_col_checks` and
   the opened positions are drawn with replacement, so the distinct opened
   columns are at most the pad count structurally at every shape
   (`ZK60_JOINT_LAW_COMPOSITION_RUN.md` §2.6, PROVED there). **Shape-free.**

None of the three is a per-slot reading; all three are inherited. What is
per-slot is C1's "exactly one claim per private table, on the declared pair".

---

## 2. The 23 slots at the shaped layouts

### 2.1 The numbers

[COMPUTED, `results/zk60_slot_closures_shaped/slot_table.py`, an independent
hand port of `shape.rs:756-807` (`slots`), `:704-739` (`claim_sites`),
`:742-749` (`slot_terms`), `:834-841` (`slot_lengths`), `:593-635` (the
domains), `layout.rs:170-176` (the P-3 lift) and `pad.rs:289-381` (the pad
rule). **138 of 138 counted figures per shape agree with the lane's own
Python model** `results/zk60_block125m_lane/model_{toy,rung_g,rung_k4,m125}.json`
at `8c5922b`, at all four shapes, 0 different — two ports written from the
same Rust and not from each other.]

`words` is what the slot puts in the receipt: `1 + (main+ext)(degree+1) +
terminals`, `Fp2` words of 16 bytes (`shape.rs:938`).

| s | name | kind | rung-G `(m,e,d)` | rung-K4 | 125M | `L` G/K4/125M | terms G / 125M | words G/K4/125M |
|---|---|---|---|---|---|---|---|---|
| 00 | 01 SS row sums norm_a | private | (12,1,4) | (12,1,4) | (19,1,4) | 54/54/82 | 1+0 / 1+0 | 67/67/102 |
| 01 | 01m SS row sums norm_m | private | (12,1,4) | (12,1,4) | (19,1,4) | 54/54/82 | 1+0 / 1+0 | 67/67/102 |
| 02 | 02 norm squares zero-check | host | (5,1,3) | (5,1,3) | (9,1,3) | 20/20/32 | 22+0 / 22+0 | 47/47/63 |
| 03 | 08 limb zero-check | standalone | (10,1,4) | (10,1,4) | (14,1,4) | 46/46/62 | 2+1 / 2+1 | 59/59/79 |
| 04 | 07 masked row sums + selector | private | (13,1,4) | (14,1,4) | (22,1,4) | 58/62/94 | 2+0 / 2+0 | 73/78/118 |
| 05 | 09Q matmul | private | (7,1,2) | (7,1,2) | (10,1,2) | 18/18/24 | 1+0 / 1+0 | 26/26/35 |
| 06 | 09K matmul | private | (7,1,2) | (7,1,2) | (10,1,2) | 18/18/24 | 1+0 / 1+0 | 26/26/35 |
| 07 | 09V matmul | private | (7,1,2) | (7,1,2) | (10,1,2) | 18/18/24 | 1+0 / 1+0 | 26/26/35 |
| **08** | **10 score matmul (bilinear)** | private | **(5,2,3)** | **(5,2,3)** | **(8,2,3)** | 23/23/32 | 2+0 / 2+0 | 31/31/43 |
| **09** | **11 PV matmul (bilinear)** | private | **(6,2,3)** | **(7,2,3)** | **(11,2,3)** | 26/29/41 | 2+0 / 2+0 | 35/39/55 |
| 10 | 12 Wo matmul | private | (7,1,2) | (7,1,2) | (10,1,2) | 18/18/24 | 1+0 / 1+0 | 26/26/35 |
| 11 | 13G gate matmul | private | (7,1,2) | (7,1,2) | (10,1,2) | 18/18/24 | 1+0 / 1+0 | 26/26/35 |
| 12 | 13U up matmul | private | (7,1,2) | (7,1,2) | (10,1,2) | 18/18/24 | 1+0 / 1+0 | 26/26/35 |
| 13 | 13D down matmul | private | (8,1,2) | (8,1,2) | (11,1,2) | 20/20/26 | 1+0 / 1+0 | 29/29/38 |
| 14 | 03 D zero-check | host | (12,1,5) | (12,1,5) | (19,1,5) | 67/67/102 | 37+19 / 37+17 | 135/135/175 |
| 15 | 04 Q zero-check | host | (12,1,5) | (12,1,5) | (19,1,5) | 67/67/102 | 8+7 / 8+7 | 94/94/136 |
| 16 | 05 KV zero-check | host | (10,1,5) | (10,1,5) | **(17,1,4)** | 57/57/74 | 7+6 / 7+6 | 80/80/104 |
| 17 | 06 softmax zero-check | host | (13,1,5) | (14,1,5) | (22,1,5) | 72/77/117 | 15+9 / 15+9 | 109/115/163 |
| 18 | 14 F zero-check | host | (13,1,5) | (13,1,5) | **(20,1,4)** | 72/72/86 | 11+6 / 11+6 | 102/102/123 |
| 19 | TAB table helper zero-check | standalone | (10,1,3) | (10,1,3) | (14,1,3) | 35/35/47 | 3+3 / 3+3 | 51/51/67 |
| 20 | ZS zero-sum row | standalone | (10,1,2) | (10,1,2) | (14,1,2) | 24/24/32 | 0+1 / 0+1 | 35/35/47 |
| 21 | IO-in endpoint equality | standalone | (12,1,2) | (12,1,2) | (19,1,2) | 28/28/42 | 1+0+1 / 1+0+1 | 42/42/63 |
| 22 | IO-out endpoint equality | standalone | (12,1,2) | (12,1,2) | (19,1,2) | 28/28/42 | 1+0+1 / 1+0+1 | 42/42/63 |

Totals [COUNTED]: main rounds **217 / 220 / 336**; extension rounds **25** at
every shape; `A` sites **122 / 122 / 122**, `H` sites **52 / 52 / 50**;
terminals **176 / 176 / 174**; largest `L` **72 / 77 / 117**, all inside the
`L + 256 ≤ 512` budget; slot words **1,254 / 1,269 / 1,751** = 20,064 /
20,304 / 28,016 bytes.

The 217 and 336 are the S19-F1 disposition's "main rounds 215 → 217 and 332 →
336" (`ZK60_BLOCK125M_S19F1_DISPOSITION.md` §4). The repair's receipt cost
recounts here from the two schedules alone: **+21 words = +336 bytes** per
rung-G block and **+35 words = +560 bytes** per 125M block [COMPUTED], which
is the disposition's figure to the byte.

**The claim-site table barely moves, and that is the strongest single fact in
this page for clause C1** [COUNTED]. Against the toy's frozen `A_SITES` /
`H_SITES` (`layout.rs:923-924`), the shaped tables differ at **one slot**:
slot 17 goes 13 → 15 `A` sites (the third `sigma_s` limb's two planes,
`shape.rs:584-586`, `:650`) and 8 → 9 `H` sites (one more `Dom::S` helper);
plus slot 14's `H` count falls 19 → 17 at 125M only (correction C-6 drops
four `Dom::D` lookups, `shape.rs:658-676`). Every other slot raises exactly
the claims it raised at the toy, on exactly the same commitments, so C1's
per-slot reading transfers for 21 of 23 slots with no arithmetic at all.

**Three shape-driven changes in that table, and only three.** 125M's `Dom::Kv`
and `Dom::F` do **not** pad (`tokens = t_pad = 512`, `hidden = f_pad = 2048`),
so slots 16 and 18 keep degree 4 instead of 5 and host no pad-zero term; and
125M's `Dom::T` does not pad either, so slot 02 carries no pad-zero term
there. Everything else is a log.

### 2.2 The closures, slot by slot

Notation: `Eq(p @ k)` a `Tab::Eq` on the point `p` starting at cube variable
`k`; `Pub(...)` a `Tab::Pub`; `A[plane]` / `H[plane]` a `Tab::Priv` on
commitment `A` / `H`; `ep[In|Out]` the endpoint (or, in a run, boundary)
plane; `supp_X` the domain indicator (a `Tab::Pub`, `argument.rs:588-596`);
`pz` the batched pad-zero term `mu_pad · Σ_groups (1 − supp) · Σ_j ζ^j
plane_j` (`argument.rs:707-746`); `g` the support gate
(`argument.rs:753-763`, the constant `1` when the domain does not pad).

| s | private planes (commitment), coordinates | public tables | closure, as written | raises / lands |
|---|---|---|---|---|
| 00 | `A[A_X]` on `Dom::D`, all summed (`:944`) | `Eq(r_t @ 0)`, `supp_D` | `g·v0·v1²` (`:946`) | 1 `A` claim, own pair; the slot is hosted by 02 |
| 01 | `A[A_X1]`, all summed (`:952`) | `Eq(r_t2 @ 0)`, `supp_D` | `g·v0·v1²` (`:955`) | 1 `A`; hosted by 02 |
| 02 | `A[A_D]`, `A[A_DSQ]`, 9 limb sub-slices of `A_LIMB` at offsets `k·t_pad`, `A[A_DM]`, `A[A_DSQM]`, 9 of `A_LIMBM`; the four `Dom::T` planes on the `Dom::T` cube, the limbs on `rho(0..lt)` (`:970-981`) | `Eq(tau)`, `Eq(r_t)`, `Eq(r_t2)`, `supp_T` (not at 125M) | `v[tau]·(zc + pz) + ν₀·v[r_t]·g·(…) + ν₁·v[r_t2]·g·(…)` (`:1006-1017`) | 22 `A`, own pairs; **hosts 00 and 01** |
| 03 | `A[A_LIMB]`, `A[A_LIMBM]`, 1 `H` helper (`:1030-1031`) | `Eq(tau)`, `supp_L` (**no closed form**, `pad.rs:176` returns `None` for `Dom::L`) | `v0·(helper_sum + pz)` (`:1041`) | 2 `A` + 1 `H` |
| 04 | `A[A_E]` (**the exempt plane**), `A[A_ZSEL]` (`:1049-1050`) | `Eq(p_ht)`, `Pub(causal_mask_at)`, `supp_S` | `g·v0·(v1·v2 + λ·v3)` (`:1056`) | 2 `A`; hosted by 17 |
| 05,06,07,10 | one `A` plane at `fixed(r_q) ‖ rho(0..ld)` (`:1074-1076`) | `Pub(fold_rows_i8(W))` | `v0·v1` (`:1085`) | 1 `A`; hosted by 15 (05), 16 (06, 07), 14 (10) |
| 08 | `A[A_QR8]` at `fixed(r_t) ‖ rho(0..lkv) ‖ fixed(r_hj) ‖ rho(lkv..lkv+ldh)`, **ext round 0**; `A[A_KR8]` at `fixed(r_j) ‖ rho(0..lkv) ‖ rho(lkv..lkv+ldh)`, **ext round 1** (`:1148-1159`) | `Eq(r_g @ 0)` — **new at a shaped layout** (`:1138`, built by `group_eq` `:488-493`) | `ig·v[iq]·v[ik]` (`:1160`) | 2 `A`, two distinct pairs; **hosted by 17** |
| 09 | `A[A_P]` at `rho(0..lkv) ‖ fixed(r_hj) ‖ fixed(r_t) ‖ rho(lkv..lkv+lt)`, ext 0; `A[A_V8]` at `rho(lkv..lkv+lt) ‖ rho(0..lkv) ‖ fixed(r_i)`, ext 1 (`:1175-1185`) | `Eq(r_g @ 0)` | `ig·v[ip]·v[iv]` (`:1186`) | 2 `A`; **hosted by 15** |
| 11,12,13 | one `A` plane at `fixed(r_row) ‖ rho(...)` (`:1206-1208`) | `Pub(fold_cols_i8(W))` | `v0·v1` (`:1217`) | 1 `A`; hosted by 18 (11, 12), 14 (13) |
| 14 | every `Dom::D` `A` plane (`a_range(A_X..A_RDL)`), `A[A_D]` and `A[A_DM]` on the `T` cube, `helpers(D)` `H` planes (`:1234-1242`) | `Eq(tau)`, `Eq(p_a)`, `Eq(p_z)`, `Pub(γ_a)`, `Pub(γ_m)`, `supp_D` | `v0·zc + ν₀·v1·g·host_wo + ν₁·v2·g·host_dmm` (`:1260-1288`) | 37 `A` + 19/17 `H`; **hosts 10 and 13** |
| 15,16 | every `Dom::Q` / `Dom::Kv` `A` plane, the **flipped RoPE partner** of the source plane at `rho(0..log)` with coordinate `log−ldh` flipped (`:1366-1368`), `helpers(dom)` `H` planes | `Eq(tau)`, two `Eq` host points, `Pub(cos)`, `Pub(sin)`, `supp_dom` | `v0·zc + ν₀·v1·g·host1 + ν₁·v2·g·host2` (`:1387-1402`) | 8/7 `A` + 7/6 `H`; **15 hosts 05 and 09; 16 hosts 06 and 07** |
| 17 | every `Dom::S` `A` plane, `A[A_MX]` and `A[A_SUM]` on the `Dom::Ht` cube, `helpers(S)` + `H_SEXP` (`:1418-1429`) | `Eq(tau)`, `Eq(p_ht)`, `Eq(p_s)`, `Pub(causal_mask_at)`, **`supp_Ht` and `supp_S`** | `v0·(zc + pz) + ν₀·v1·supp_Ht·host_rs + ν₁·v2·supp_S·host_s` (`:1456-1476`) | 15 `A` + 9 `H`; **hosts 04 and 08** |
| 18 | every `Dom::F` `A` plane, `helpers(F)` + `H_FACT` (`:1303-1310`) | `Eq(tau)`, `Eq(p_g)`, `Eq(p_u)`, `supp_F` (not at 125M) | `v0·zc + ν₀·v1·g·host_g + ν₁·v2·g·host_u` (`:1324-1341`) | 11 `A` + 6 `H`; **hosts 11 and 12** |
| 19 | `A[A_MU8]`, `A[A_MEXP]`, `A[A_MACT]` and the three `H` table helpers (`:1488-1496`) | `Eq(tau)`, three `Pub` table-value vectors, `supp_Tab` | `v0·(μ₀r₀+μ₁r₁+μ₂r₂ + pz)` (`:1521-1526`) | 3 `A` + 3 `H` |
| 20 | `H[H_U]` on `Dom::Tab` (`:1537`) | `Pub(ones, len = size(Dom::Tab))` (`:1536`) | `v0·v1` (`:1538`) | 1 `H`, **whose data parts sit on the zero-sum rows** (ruling S-1) |
| 21,22 | `A[A_X]` / `A[A_X2]` on `Dom::D`; `ep[In]` / `ep[Out]` on `Dom::D` at the layout's `io_mask_row` (`:1544-1545`, `:564-568`) | `Eq(tau)` | `v0·(v1 − v2)` (`:1546`) | 1 `A` + 1 endpoint/boundary claim |

**How the toy's table differs**, item by item: the toy has no `supp_*` table
and no `pz` anywhere (`Shape::carries_pad_rule` is false for the frozen toy
profile, `shape.rs:522-524`); the toy's slots 08 and 09 have `lkv = 0`, so
`group_eq` returns `None`, `Gate(None)` is the constant `1`, the closure is
`v[0]·v[1]`, the degree is 2 and the schedule is byte-identical
(`argument.rs:488-493`, `shape.rs:803`); the toy has two `sigma_s` limbs, so
slot 17 reads two fewer `A` planes and slot 03's lookup count differs; the
toy's `Dom::Tab` sits at its natural log and is not lifted; and the toy's
`io_mask_row` is `endpoint_rows − 5` and never a boundary
(`layout.rs:1137-1138`).

---

## 3. Clause-by-clause verdict, slot by slot

### 3.1 The summary

A slot "needed a new argument" if **any** clause of §1.2 is answered by
something the toy reading does not contain. The classification below is the
one §3.8's clause table makes; a reader who disagrees with a row should
disagree with that table, not with this count.

| verdict | slots | count |
|---|---|---|
| **carries over verbatim** — the toy's reasoning word for word, with only the round count and the domain logs moved | 05, 06, 07, 10, 11, 12, 13 (the seven matmuls) and 20 | **8** |
| **carries over with a changed count** — the same reasoning, but a new public gate table, a higher degree, more sites or more terminals | 00, 01, 04 | **3** |
| **needed a new argument** | the 8 pad-zero hosts (02, 03, 14, 15, 16, 17, 18, 19 — of which only 03, 14, 15, 17, 19 host one at 125M), the 2 repaired bilinear slots (08, 09), the 2 boundary slots in a run (21, 22) | **12** |

Of the twelve, eight share **one** new argument — "the pad-zero term's
public-factor-free monomial is inside the slot's `eq(tau)` bracket" (§3.3) —
and five have arguments of their own on top: 08 and 09 (§3.2), 17 (two
indicators and two differently gated hosts, §3.3), and 21 and 22 (the
boundary site, §3.5). Slot 14 also needs the mixed-host argument of §3.6 and
slot 19 the two-commitment group argument of §3.3.

### 3.2 (a) Slots 08 and 09 — the repaired bilinear pair

**The question the brief asks:** with `degree = 3`, `ext = 2` and the summed
variables including group bits shared by BOTH private factors, is the
masking still exactly what the sampler assumes?

**Answer: yes, and the repair makes the premise stronger, not weaker.**

*C4 (the premise).* The repaired closure is
`eq(r_g, ·)·X·Y` with `X` in extension round 0 and `Y` in round 1
(`argument.rs:1152`, `:1159`; `:1179`, `:1185`). At extension round `m`,
`exts` is zero in every position but that round's private table
(`argument.rs:353-360`), so:

* round 0: `poly(exts) = 0 · P_X · 0 = 0` — the group `eq` kills it AND the
  other private factor is zero;
* round 1: `poly(exts) = 0 · 0 · P_Y = 0` — likewise.

**Which mechanism holds where, exactly** (rewritten under disposition §1).
At the toy (`lkv = 0`) `group_eq` returns `None`, there is no `eq` factor,
and the premise rests on the **second** mechanism alone — "the two factors
are extended in different rounds". At every shaped layout (`lkv ≥ 1`) the
public group `eq` is a factor of the one monomial, so the **first**
mechanism holds on its own: the monomial is killed by a public factor
whatever the private values are, and `poly(exts)` is the zero polynomial in
them. Both mechanisms are present at the shapes and either would do; only
one — the first — is needed there. **Slots 08 and 09 at the toy are the only
place in the whole module where the second mechanism is load-bearing**; that
is the disposition's §1 finding, and it is what makes this page's C4 stronger
than drafted. [PROVED HERE from the closure; COMPUTED, §4 P1, 10 of 10
bilinear miniatures at `lkv = 1` and `lkv = 2`; independently COMPUTED by the
check, `premise_cover.py`, 92 of 92 arms over four shapes.]

*C3 (the masking).* `Shape::slots` declares `(main, ext, degree) = (lkv +
log2(head_dim), 2, 3)` for slot 08 and `(lkv + log2(t_pad), 2, 3)` for slot
09 (`shape.rs:781-782`, `:798`, `:803-804`), and the SAME triple drives
`run_slot`'s round loop, the verifier's `sumcheck::verify(claimed, degree, n
+ ext, …)` (`argument.rs:380`) and the mask's `CfsMask::len(N, d)`
(`layout.rs:944-946` at the toy, `argument.rs:292-295` at a shape). The mask
covers all `N = main + 2` rounds — the extension rounds are masked by the
same `g_s` at `argument.rs:361` — so Fact 2.1 applies with the shaped `(N,
d)`.

**Computed dimensions** [COMPUTED, `mask_dof.py`, exact rank over `Fp2`,
three independent challenge vectors each]:

| shape | slot | `(N, d)` | `L = Nd+2` | `dim C = Nd+1` | `rank R` | `dim ker R` |
|---|---|---|---|---|---|---|
| rung-G | 08 | (7, 3) | 23 | 22 | **22** | **1** |
| rung-G | 09 | (8, 3) | 26 | 25 | **25** | **1** |
| rung-K4 | 08 | (7, 3) | 23 | 22 | **22** | **1** |
| rung-K4 | 09 | (9, 3) | 29 | 28 | **28** | **1** |
| 125M | 08 | (10, 3) | 32 | 31 | **31** | **1** |
| 125M | 09 | (13, 3) | 41 | 40 | **40** | **1** |

so the covering is tight with no slack at the new degree, exactly as at the
toy. The same identity holds for **all 23 slots at all four shapes: 92 of 92**
(§4).

*C1 (claim placement) — the one genuinely new arithmetic.* With `ext = 2` the
two private factors get **different** pair coefficients:
`cd = (1−e₀)(1−e₁)` for both data parts, `cm_X = e₀(1−e₁)` for the round-0
factor and `cm_Y = e₁` for the round-1 factor (`argument.rs:409`, `:413`).
Both are non-zero because `argument.rs:404-406` refuses `e = 0` and `e = 1`
for **every** extension challenge, not just the first. The pair weights are
`(cm, cm·U)` at `argument.rs:274-276` as at every other slot, so travelling
condition 1 of §1.3 is met for both. [COMPUTED, §4 P5: the published terminal
equals `cd·T(point) + cm·P` exactly, on every miniature and every `π`.]

*C2, C5, C6, C7.* Unchanged in kind. Slot 08 is hosted by 17 and slot 09 by
15 (`layout.rs:915`, `:917`) — a cross-domain pairing (the score's claim is
consumed by the softmax zero-check on `Dom::S`, the PV output's by the `Q`
zero-check on `Dom::Q`), which is the toy's pairing unchanged. Both slots
publish `1 + N·4 + 2` words.

*What the repair did NOT change.* [COMPUTED, control C2 of §4] Dropping the
group `eq` from the closure leaves the premise true and the chain accepting,
but the slot then proves a different sum. **The S19-F1 defect was a
completeness defect at the (H4) layer too** — every clause of §1.2 held
before the repair as well. This matters for the checker: the repair is not
what makes (H4) true for these slots, and a reader must not treat
"repaired" as "now private".

*The two named shape refusals that protect this slot.* Ruling F-2
(`shape.rs:252-260`) refuses a shape whose `Dom::Q`, `Dom::Kv` or `Dom::S` is
lifted by P-3, because the bilinear arms write coordinate lists at the
domain's NATURAL log. Ruling S-3 (`shape.rs:317-322`) refuses `head_dim ≥
2^log_cols`, because slot 08's two coordinate lists end in two copies of the
same symbol segment and their PCS column keys would then collide by
construction on every run. Both are liveness cliffs, both are named, neither
is near at any declared shape.

**S-3 protects a second thing, for a reason nobody had written down**
[ruling C-2, the check's B-2]. Slots 15 and 16's flipped rotary partner
(§1.2's rewording of C1) raises a second claim on the same commitment at the
same slice offset. Its PCS column key differs from the first claim's **only
because the flipped coordinate falls inside the claim point's TAIL** — the
key is the last `min(p.log, log_cols)` coordinates (`part_key_at`,
`protocol.rs:186-192`, re-read at `8c5922b`) — and it does so only when
`log2(head_dim) ≤ log_cols`. Above that the two claims would carry the SAME
key, collapse into one column-weight group, and `check_opening` would refuse
every proof: the same failure S-3 was written for at slot 08. S-3 refuses
`head_dim ≥ 2^log_cols` and therefore covers this too, with one unit to
spare. The margins are **6, 7 and 8 bits** at rung-G, rung-K4 and 125M
(`log2(head_dim)` 4, 3, 6 against `log_cols` 10, 10, 14) [COMPUTED by the
check, `counts_and_cliffs.py`]. **The refusal's documentation and its test
are being extended on the lane to say it protects slots 15 and 16 too** —
the disposition's ruling C-2; until that lands, this paragraph is the only
place it is written.

### 3.3 (b) Every zero-check that carries the pad-zero term

The term is built at `argument.rs:707-746` and added by
`PadTerm::add` (`:718-733`). It is hosted by the domain's own zero-check
except for `Dom::T` (hosted by 02) and `Dom::Ht` (hosted by 17)
(`pad.rs:347-359`).

| shape | hosting slots (`pad_on`) | domains | `ζ` and `mu_pad` draws per proof |
|---|---|---|---|
| rung-G, rung-K4 | 02, 03, 14, 15, 16, 17, 18, 19 | T; L; D; Q; Kv; **Ht and S**; F; Tab | **8** |
| 125M | 03, 14, 15, 17, 19 | L; D; Q; **Ht and S**; Tab | **5** |

[COUNTED, `slot_table.py`]. Slot 17 hosts two domains and draws **one** `ζ`
and one `mu_pad` for both (`argument.rs:1410`, `:1448`), the `ζ` powers
continuing across the two groups (`argument.rs:724-726`).

> **Where the code differs from an earlier memo.** `ZK60_JOINT_LAW_
> COMPOSITION_RUN.md` §2.2, as corrected by ruling **R-7** (check finding
> B-7), says the pad rule costs "**≤ 7**" `ζ` challenges and "≤ 7" `mu_pad`
> entries, on the reasoning that there are exactly seven `ζ` draw sites in
> the source. There **are** exactly seven source lines — `argument.rs:961`
> (02), `:1028` (03), `:1224` (14), `:1299` (18), `:1352`, `:1410` (17),
> `:1485` (19) — but line `:1352` is in the **shared `SC_QZC | SC_KVZC`
> arm**, which `define` runs **twice**, once per slot. At rung-G and rung-K4
> eight slots have `pad_on == true`, so a proof draws **8** `ζ` and **8**
> `mu_pad`, not 7. At 125M it is 5, as R-7 says. **The draft R-7 corrected
> was right at the rungs and the correction was not**; the earlier draft's
> "8 at rung-G" should stand. [COUNTED,
> `results/zk60_slot_closures_shaped/slot_table.json`, `pad_zero_hosting_slots`.]
> It costs one extra challenge-only refusal event at the rungs (a `ζ` of
> zero, `argument.rs:765-770`), which is negligible beside every other term
> and moves no proof byte; nothing else in that section changes.
>
> **SETTLED, and this is the count to quote** [ruling C-6]. The figure is
> **8 `ζ` and 8 `mu_pad` at rung-G, 8 and 8 at rung-K4, 5 and 5 at the 125M
> shape** — one number, stated once, used everywhere on this page (§3.3's
> table above, §6.1 step 12a, §6.2). Three independent counts now agree: this
> page's, the shaped rank lemma's checker, and this page's own checker
> [COUNTED, `counts_and_cliffs.py`, from `pad.rs:pad_zero_host` and the
> padded-domain sets]. **Ruling R-7 was amended at 00:43 on 2026-09-21** in
> `ZK60_JOINT_LAW_COMPOSITION_RUN_DISPOSITION.md` §2, which now records that
> its own "at most 7" correction was wrong and the draft was right. The seven
> `ζ` source lines are `argument.rs:961`, `:1028`, `:1224`, `:1299`, `:1352`,
> `:1410`, `:1485`, and `:1352` sits in the shared `SC_QZC | SC_KVZC` arm
> (`argument.rs:1344`) that `define` runs twice — all re-read at `8c5922b`.
> Nothing above is open any more; it is inventory, not a claim.
>
> The same section's other two figures **do** reproduce here exactly: the
> degree rise costs **105** extra `Fp2` in round messages at rung-G and
> **126** at 125M (and 107 at rung-K4, which the memo predates) [COMPUTED].
> **What those figures mean has changed** — see the declared-degree paragraph
> immediately below.
>
> **A second, smaller difference in the same section.** It says "`nu`/`mu`
> entries are refused on zero". At `8c5922b` **`mu` is not**: `nonzero(…)`
> (`argument.rs:765-770`) is applied to `nu` and to `ζ` and to nothing else
> — `argument.rs:960-961`, `:1028`, `:1223-1224`, `:1298-1299`,
> `:1351-1352`, `:1409-1410`, `:1485` — while every `mu` vector is a plain
> `tr.challenge_fp2_vec(...)` (`:959`, `:1222`, `:1297`, `:1350`, `:1408`,
> `:1484`) and `SC_LZC`'s dedicated `mu_pad` a plain `tr.challenge_fp2()`
> (`:1027`). [VERIFIED IN THE CODE, and confirmed independently at `8c5922b`
> by the check: `nonzero(…)` wraps `nu` and `ζ` and nothing else.] A zero
> `mu` switches one constraint or
> the pad-zero term off at probability `|Fp2|^{-1} ≈ 2^-128` per slot: a
> soundness term, not a privacy one, and it makes the *liveness* inventory
> smaller rather than larger. It changes nothing in (H4) — the closure is a
> public function of the view whatever `mu` is — and I record it only
> because the run memo states the opposite.
>
> **RULED** (disposition §1, on the check's B-6.2): a zero `mu` or `mu_pad`
> is a soundness matter at 2^-128 and nothing else, and the reason is sharper
> than this page gave. **`mu` enters only the slot POLYNOMIAL.** The
> published terminals, the claim points and the reserved-pair coefficients do
> not depend on the polynomial at all — only the honest sum and the round
> messages do, and both are masked by the same `c·g`. A zero `mu` changes
> what is PROVED, not what is DISCLOSED. The run disposition's errata note of
> 2026-09-21 00:43 records the slip in its own section as well.

**The declared degree of four of those slots exceeds their closure's, and
this page priced the difference as if it were all real** [ruling C-1, the
check's B-1]. §3.8's clause table marked C3 as "`N` (deg 4→5)" for slots 14,
15, 16 and 18. What rises there is the **DECLARED** degree, not the
closure's. The reason is structural, and §3.4 states its premise without
drawing the consequence: `Gate` is put on the inhomogeneous clauses and on
the host terms and is **never** put on the LogUp arm (`argument.rs:748-763`,
re-read at `8c5922b`; the doc comment on `struct Gate` says so in the source).
In slots 14, 15, 16 and 18 the LogUp arm `v[eq]·h·d₁·d₂` is what sets the
degree, at **4**, and every gated monomial is at most degree 3 before the
gate — so the gate cannot raise those four slots' degree. In slots 00, 01, 04
and 17 the gated monomial IS the maximal one and the rise is real.

| slot | declared at a padding shape | the closure's degree (upper bound) |
|---|---|---|
| 00, 01, 04, 17 | 4, 4, 4, 5 | 4, 4, 4, 5 — **tight** |
| **14, 15, 16, 18** | **5** | **4** |

[COMPUTED by the check, `degree_maxplus.py`: each arm's closure evaluated in
the max-plus degree semiring — an exact port of the arithmetic of each
`define` arm, giving an upper bound — reproducing `BASE_DEGREE` at the toy
23 of 23 as its self-check.] The degree-rise cost of the box above therefore
splits:

| shape | degree-rise cost | of which the closure needs | of which buys nothing |
|---|---|---|---|
| rung-G | 105 `Fp2` | **54** | **51 = 816 B per block** |
| rung-K4 | 107 `Fp2` | **56** | **51 = 816 B per block** |
| 125M | 126 `Fp2` | **86** | **40 = 640 B per block, 7,680 B per twelve-block run** |

[COUNTED, `counts_and_cliffs.py`.] It also inflates `L` for those four slots
(slot 14 at 125M: `L = 102` where 82 would do), inside the `L + 256 ≤ 512`
budget either way.

**Over-declaring is safe for (H4); under-declaring would not be, and no slot
under-declares.** The round messages are evaluated at `d + 1` points and the
mask has `L = Nd + 2` coefficients, so the covering is exact at the DECLARED
pair — which is what §4.1's rank identity measures. An under-declared degree
would break C3 outright: a degree-`(d−1)` mask spans only **27 of the 40**
dimensions of slot 09's channel at 125M [COMPUTED, control, `rank_dof.py`].
The check ran that direction too and found **no slot under-declares at any of
the four shapes** [COMPUTED]. The method this page used — read
`Shape::slots()`' declared triple, never ask what `def.poly` actually is —
structurally cannot see either direction; the Rust test of gap S-C1 should
assert the degree as well as the premise.

**RULING C-1: not changed.** The four slots stay as they are. Taking the
bytes back would mean gating `shape.rs:795`'s indicator term on the indicator
landing on a maximal-degree monomial — a shape change, moving every shaped
profile's bytes, for 7,680 bytes in a twelve-block 125M run of 484 MB, below
two thousandths of a percent. It is **recorded as slack** to take if the
schedule is ever reopened. Nothing here is a defect of (H4).

**Which planes enter `Σ ζ^j · plane_j`.** Exactly the domain's `Rule::Zero`
planes, in plane order (`pad.rs:365-381`). Concretely at rung-G / rung-K4:
`Dom::T` 4 `A` planes; `Dom::L` 2; `Dom::D` all 37 − 2 = the domain's own
planes; `Dom::Q` 7; `Dom::Kv` 6; `Dom::Ht` 2; `Dom::S` all but `A_E`;
`Dom::F` 11; `Dom::Tab` 3 `A` **and 3 `H`**. At 125M the same, minus T, Kv
and F. **`A_E` is excluded by name** (`pad.rs:299-301`), every LogUp helper
is excluded by name (`pad.rs:314-325`), and `H_U` has no rule at all.

**Do those claims become new claim sites?** **No, at every slot.** In every
hosting slot the planes the term names are *already* `Tab::Priv` entries the
slot pushed:

* 02 resolves them through an explicit match on the four `Dom::T` plane ids,
  with a **named refusal** for a fifth (`argument.rs:993-1001`);
* 17 checks the `Dom::Ht` list is exactly `[A_MX, A_SUM]`, with a **named
  refusal** (`argument.rs:1449-1451`), then uses the two table indices it
  already pushed;
* 19 checks both lists against the declared ones through
  `tab_group_is_declared` (`argument.rs:625-633`, called at `:1516`);
* 03, 14, 15, 16, 18 resolve them through `B::tab` (`argument.rs:537-539`),
  the shaped-plane→table-index map filled by the slot's own `a_range` sweep.

Because the term adds no `Tab::Priv`, it adds **0 new claim sites, 0 new
committed rows, 0 new terminals and 0 new rounds** at every shape — the run
memo's §2.2 table, re-derived here [COUNTED]. `Shape::claim_sites`
(`shape.rs:704-739`) has no indicator entry, and `Shape::slot_terms`
(`:742-749`) does not read `pad_on`.

**Does the term publish anything beyond the zero-check's own terminals?** No.
Its only trace in the published view is that the slot's round messages are
one `Fp2` longer per round in the eight `INDICATOR_SLOT_DOMAIN` slots whose
domain pads (`shape.rs:65-66`, `:795`, `:804`) — a **declared** degree rise,
not a new object, and in four of those eight slots the closure's own degree
does not move at all (ruling C-1, the paragraphs above) — and that the
challenge vector `ρ` is longer by the `ζ` and `mu_pad`
draws (`ζ` refused on zero, `mu_pad` not — see the box above). The declared
degree rise
enters `L_s` and `dim C_s` through the same `d`, so the DOF identity keeps
zero slack **at the declared pair**: computed for all 23 slots at all four
shapes, **92 of 92** (§4), and recomputed independently by the check at 1,120
(slot, shape, challenge-vector) points with none not tight (§4.1).

**The one clause that needed a new argument, and it is the load-bearing one.**
`pz.eval` has a monomial with **no public factor of its own**: the `1` in
`(1 − supp)` leaves `mu_pad · ζ^j · plane_j`, a bare private table value. The
premise survives **only** because every hosting slot puts `pz` inside the
slot's own `eq(tau)` bracket:

`argument.rs:1014` (02), `:1041` (03), `:1281`+`:1287` (14), `:1333`+`:1340`
(18), `:1392`+`:1401` (15, 16), `:1469`+`:1475` (17), `:1525` (19).

In all seven arms the expression is `v[eq(tau)] · ( zc + pz.eval(v) )`, and
`eq(tau)` is a `Tab::Eq`, hence `0` in `exts`. [VERIFIED IN THE CODE, all
seven arms read at `8c5922b`; PROVED HERE for the consequence; **COMPUTED**,
§4 P1 and control C4: the identical closure with `pz` moved one bracket
outwards has `poly(exts) ≠ 0` and the verifier's chain **rejects** the honest
transcript. **Re-read independently at `8c5922b` by the check**, which
re-read every one of those lines, including the two where `pz` is added to
`zc` before the multiplication, and found every one of them to be
`v[eq(tau)] · ( … + pz.eval(v) )`: the citation list is accurate and the
conclusion is right.]

**And the `eq(tau)` bracket does more than rescue this one monomial.** Under
the stronger form of C4 (disposition §1, §0 above), the bracket is why
**every** monomial of these seven arms carries a public factor, so at a
shaped layout `poly(exts)` is the zero polynomial in the prover's values and
not a quantity that happens to vanish. The negative control has teeth in
exactly that form: moving the term one bracket outwards turns the premise
FALSE in **21 of 21** pad-zero arms across the four shapes [COMPUTED by the
check, `premise_cover.py`].

**A second monomial without a public factor, in slot 19.** `SC_TAB`'s
`r₀ = v[helper]·(α − v[values]) − v[multiplicity]` contains the bare
`− v[multiplicity]`. Same resolution: `v[0] = eq(tau)` wraps the whole sum
(`argument.rs:1525`). [VERIFIED IN THE CODE; COMPUTED, §4, the `SC_TAB`-shape
miniature.]

### 3.4 (c) The support indicators and the planes exempt by name

*The indicators.* Public 0/1 tables that both sides build
(`pad.rs:48-54` for the definition of record, `pad.rs:160-193` for the closed
forms, `pad.rs:335-340` for what the argument uses). They enter the closure
only as `Tab::Pub` (`argument.rs:595`), which carries no mask row and no
claim; they raise nothing and publish nothing. Their one release-build
refusal is `tile_rep` (`argument.rs:613-618`, finding F-1): an indicator that
does not tile the slot's cube is refused by name, on both sides, and the
refusal names only shape quantities. `supp_L` has no closed form at any shape
(`pad.rs:176` gives `BitForm::of(9, 16) = None`), so `Dom::L`'s indicator is
the builder's support table verbatim — a public table of `size(Dom::L)`
entries, 1,024 at the rungs and 16,384 at 125M. **Carries over with a changed
count.**

*Where the gate goes.* `Gate` multiplies the inhomogeneous clauses and the
host terms of the eight `INDICATOR_SLOT_DOMAIN` slots, and is **never** put
on the LogUp arm (`argument.rs:748-752`, and `:1331-1333` for `f_act`,
`:1467-1469` for `cx`). For (H4) this is neutral either way: gated or not,
each monomial still sits under the slot's `eq`. It matters for soundness, not
for the closure.

*The exemptions.* Three, by name (`pad.rs:289-326`): `A_E` (the exp-table
plane, `pad.rs:299-301`), every LogUp helper (`pad.rs:314-325`), and `H_U`
(no rule). Their effect on (H4) is **nil**: an exempt plane is an ordinary
`Tab::Priv` read by its slot with its own claim site and its own reserved
pair, exactly like a `Rule::Zero` plane; the exemption only removes it from
the pad-zero term's summand list. `A_E` is read by slot 04
(`argument.rs:1049`) and by slot 17 (inside `a_range`); the helpers are read
by 03, 14, 15, 16, 17, 18, 19; `H_U` by slot 20. All of them are covered by
C1 verbatim. **Carries over verbatim.**

*The matmuls have no indicator at all, and that is deliberate.* Slots 05, 06,
07, 10, 11, 12, 13 sum a private plane against a folded public weight
(`argument.rs:1078`, `:1210`). Their pad-safety rides on ruling P-2 — a
public weight nonzero off its axis's support is refused by name at
construction, entrywise, with two distinct messages
(`private_block.rs:257-271`, the entrywise sweep documented at `:272-280`) —
so the padded inner positions
contribute zero without an indicator. For (H4) the closure is the toy's
`v0·v1` with `v1` a `Tab::Pub`: the premise holds on the first mechanism.
**Carries over verbatim.**

### 3.5 (d) Slots 21 and 22 in a run

In a single block these are the two external endpoints; in a run, block `k`'s
slot 22 claims on the internal boundary `B_k` at site 0 (row `data`) and
block `k+1`'s slot 21 claims on `B_k` at site 1 (row `data + 2`)
(`run.rs:48-49`, `:269-281`; `boundary.rs:196-202`; `layout.rs:1142-1160`).
The reserved pair the slot uses is the run's declared schedule, set on the
stage layout by `Layout::with_io_mask_rows` (`run.rs:391`).

**What the slot itself publishes IN ITS OWN STAGE** is unchanged in form and
in count: one mask-bearing scalar, `(19+1)·3 = 60` round words at 125M, and
**two** terminals — the `A` plane's and the boundary plane's, each
`cd·T(ρ) + cm·P` with `P` the value of that commitment's reserved pair at the
claim's column tail (`argument.rs:252-261`, `:264-278`). The boundary's
ROOT was absorbed at the top of the stage, before any slot challenge
(`run.rs:498-509`, the absorb at `:505`); the boundary's **opening** — its
group vectors, proximity vector and opened columns — appears in the NEXT
stage's segment, because its claim list is complete only then
(`run.rs:525-531` and `:547` prover, `run.rs:660-670` and `:760` verifier).

**Verdict per clause.** C2, C3, C4, C5, C6, C7: **verbatim** — the closure is
`v0·(v1 − v2)` with `v0 = eq(tau)` (`argument.rs:1546`), both private factors
are in extension round 0, and the eq kills them. C1: **needs a new
argument**, and it is a short one. The pair is a boundary's, not an
endpoint's; the pair row is derived, not literal (`boundary.rs:196-202`); the
derived row count `data + 2·sites + 2` is checked against the declaration and
refused by name otherwise (`boundary.rs:146-151`); the two sites are
disjoint by construction; and the boundary's opening is audited with the
SAME `audit_claims` and the same exact group count as any other commitment
(`boundary.rs:281-283` → `protocol.rs:297-307`, with `want_groups =
spec.sites() = 2`).

Three consequences worth naming, none of which the toy reading covers.

1. **(H4) is a within-stage statement and stays one.** The `eval` functional
   of slot 22 is computed from values published in stage `k`
   (`argument.rs:397`); the boundary's opening in stage `k+1` is part of
   `V_pcs`, i.e. (H1) / gap G-R1's business, not (H4)'s. There is no
   cross-stage term in the closure. [PROVED HERE, by inspection of
   `argument.rs:373-399`, which reads only `sp`, `acc` and `def`.]
2. **A terminal published in stage `k` is masked by a row of a commitment
   opened in stage `k+1`.** That is legitimate here — the mask row is fixed
   at commit time — but it is exactly the place where the per-commitment
   statement and the per-slot statement have to be glued, and the gluing is
   G-R1's, not this page's. Recorded as a hand-off, not closed.
3. **A further challenge-only refusal, not in the run's inventory.** The
   boundary opening demands **exactly 2** column-weight groups. The two
   claims' keys are the last `endpoint_log_n` coordinates of two claim points
   drawn in different stages, so a collision refuses an honest proof. The
   probability is `|Fp2|^{-endpoint_log_n}` ≈ **2^-1280** at rung-G and
   **2^-1792** at 125M [COMPUTED from `part_key_at`, `protocol.rs:186-192`] —
   negligible beside every other term, but it belongs in the inventory for
   completeness.

### 3.6 (e) The mixed slot — slot 14, the `D` zero-check

Slot 14 hosts slot 10 (`SC_WO`, the attention output projection, whose input
plane `A_O8` lives on `Dom::Q`) and slot 13 (`SC_DMM`, the feed-forward down
projection, whose input plane `A_H16` lives on `Dom::F`) (`layout.rs:914`).
It is the only slot whose two hosted claims come from two different regions
of the block.

**Why that is harmless for (H4), stated as the clause it touches.** What a
host consumes is not its hosted slots' *planes* but their *claimed values at
their output points*, and both output points are on **`Dom::D`**: `p_a =
(r_q, r_j)` with `|r_j| = log2(d_pad)` (`argument.rs:1072-1073`) and `p_z =
(r_td, r_j)` with `|r_j| = ld` (`argument.rs:1199-1211`), both of length
`log(Dom::D)`. So slot 14's two `Tab::Eq` tables live on its own cube like
any other host's, and the two host terms `ν₀·v1·g·host_wo` and
`ν₁·v2·g·host_dmm` are `eq`-led monomials (`argument.rs:1287`). C4 holds on
the first mechanism. C5's cancellation is the generic one, checked
symbolically (§4, P7).

Two counts do change and are worth stating: slot 14 is the slot with the most
claim sites at every shape (37 `A` + 19 `H` at the rungs, 37 + 17 at 125M —
**correction C-6 drops four `Dom::D` lookups at 125M**, `shape.rs:658-676`,
which is why `H` sites fall from 52 to 50), and it is the slot whose
extension round mixes reserved-pair evaluations from `A` **and** `H` in one
round. That mixing is why the run memo's correction C-12 says `V_sc` is not a
product across roles and why Theorem 3.3 conditions on the whole of `π`; it
is unchanged in kind at a shape, only wider. **Carries over with a changed
count.**

### 3.7 (f) The lookup slots against ruling S-1

Ruling S-1 (`ZK60_GENERIC_RANK_LEMMA_SHAPED_DISPOSITION.md`, wired as a named
refusal at `shape.rs:289-296`) is: the lookup-table domain must sit at
**exactly** the row width, because two `H` claims put **data** parts on the
two zero-sum rows, which the argument's accounting counts as non-data. The
two claims are:

* **slot 20**'s claim on `H_U` (`argument.rs:1537`, the plane at
  `layout.rs:1237-1240`'s rows) — a `Tab::Priv` with its own reserved pair
  AND data parts on the zero-sum rows;
* the **pairless LogUp sum claim** (`protocol.rs:167-178`), which is not a
  slot's claim at all: it is appended after the 23 slots
  (`protocol.rs:310-314`) and is the one claim `audit_claims` allows to be
  pairless, provided it covers both zero-sum rows
  (`protocol.rs:252-258`).

**Verdict for (H4).** The sum claim is outside every slot's closure, so it is
outside this reading; I record it as such rather than silently covering it.
Slot 20's closure is `v0·v1` with `v0 = Pub(ones)`
(`argument.rs:1536-1538`): the premise holds on the first mechanism and C1..C7
carry over verbatim. What S-1 buys is not a closure property but the fact
that, at `log(Dom::Tab) = log_cols`, both claims' row part of the eq-tensor is
`eq_table_msb(point[..0]) = [1]`, so the zero-sum rows carry a
point-INDEPENDENT weight. **That is a hypothesis of G-R1's per-commitment
statement, not of (H4)** — but it is a hypothesis the closure of slot 20
would break if the table domain ever moved, and it is now a construction
refusal. I cite it and do not redo it.

Slot 03 and the five domain zero-checks carry the LogUp helper relation
`helper_sum` (`argument.rs:672-688`): `h·d₁·d₂ − (d₁+d₂)` with `d_i` affine
in the plane values. Every term is under the slot's `eq(tau)`. **Carries over
with a changed count** — the helper count is shape-driven
(`shape.rs:679-681`), 19 → 17 on `Dom::D` at 125M.

### 3.8 The clause-by-clause table

A cell is `V` when the toy's reading answers it unchanged (a longer round
count or a bigger domain log is **not** counted as a change), `N` when only a
count moves, `A` when the answer is new.

| s | C1 pair | C2 public | C3 mask | C4 premise | C5 host | C6 nothing else | C7 budget |
|---|---|---|---|---|---|---|---|
| 00, 01 | V | V | **N** (deg 3→4) | V (eq) | V | V | N |
| 02 | V | V | V | **A** (pz inside eq) | V | V | N |
| 03 | V | V | V | **A** (pz inside eq) | V | V | N |
| 04 | V | V | **N** (deg 3→4) | V (eq) | V | V | N |
| 05–07, 10–13 | V | V | V | V (Pub weight) | V | V | V |
| 08, 09 | **A** (two pair coefficients) | V | **A** (deg 2→3, `N` grows by `lkv`) | **A** (the group `eq`, new at a shape; at the toy the other mechanism, §3.2) | V | V | N |
| 14 | **N** (`H` 19→17 at 125M) | V | **N** (DECLARED deg 4→5; the closure stays at 4 — C-1) | **A** (pz inside eq) | **A** (mixed hosts, one cube) | V | N |
| 15, 16 | V, on C1 **as reworded** (the flipped RoPE partner is a second `Tab::Priv` on the same plane, with its own claim, pair and terminal — C-2; unchanged from the toy, which shares the arm) | V | **N** (DECLARED deg 4→5, not 16 at 125M; the closure stays at 4 — C-1) | **A** (pz inside eq) | V | V | N |
| 17 | **N** (13+8 → 15+9) | V | **N** (deg 4→5, tight) | **A** (two groups, two gates) | **A** (two differently gated hosts) | V | N |
| 18 | V | V | **N** (DECLARED deg 4→5, not at 125M; the closure stays at 4 — C-1) | **A** (pz inside eq) | V | V | N |
| 19 | V | V | V | **A** (pz over `A` **and** `H`) | V | V | N |
| 20 | V | V | V | V (Pub ones) | V | V | V |
| 21, 22 | **A** (boundary site in a run) | V | V | V (eq) | V | V | N |

**Three notes the check and the disposition add to this table.**

1. **The C3 cells say DECLARED** (ruling C-1). For slots 14, 15, 16 and 18 it
   is the declared degree that rises to 5; the closure's own degree stays at
   4 wherever their domain pads, because the LogUp arm sets it and the gate
   never touches the LogUp arm. Over-declaring is safe for (H4) and no slot
   under-declares at any of the four shapes [COMPUTED]. See §3.3.
2. **The C5 cells rest on a reading that nothing enforces at a shape**
   (ruling C-3). Every `V` in the C5 column means "the hosted mask totals
   cancel", which they do by construction on both sides
   (`argument.rs:345` subtracts `κ·c_hs·G_hs`, `:379` adds back
   `κ·scalars[hs]`) — and that part is confirmed. It does **not** mean the
   hosted lists are checked: no test and no production check compares the
   lists written literally in the arms with `HOSTS`. That is gap S-C3(i) as
   restated in §6.2, and it is a **soundness** matter, not a privacy one.
3. **The whole table is a reading, not a test** (ruling C-7). Gap S-C1's Rust
   test would replace the C4 column with a machine check at every shape the
   module can build; under the stronger C4 it can assert identity to zero for
   arbitrary values, not only for honest ones.

---

## 4. The generic-instance computations

All exact over `Fp2 = Fp[u]/(u²−7)`, `p = 2^64 − 2^32 + 1`
(`zkp-core/src/field.rs:10`, `:130`). Scripts and outputs in
`results/zk60_slot_closures_shaped/`; the README there says how to rerun
them. A rank is a rank: there is no sampling test anywhere below.

### 4.1 The mask identity at the shaped `(N, d)` — clause C3

`mask_dof.py` ports `CfsMask::round`, `::sum_weights`, `::eval_weights`
(`zkp-core/src/sumcheck.rs:222-274`) and builds the matrix of `R_s` column by
column at the shaped `(N_s, d_s)` of every slot.

**Result [COMPUTED]: 92 of 92** (23 slots × 4 shapes), at three independent
challenge vectors each: `rank R_s = N_s d_s + 1 = dim C_s` and
`dim ker R_s = 1`, and the mask's own rounds satisfy the verifier's chain
(`r₀(0)+r₀(1) = ⟨sum_weights, a⟩` and `r_j(0)+r_j(1) =
interpolate_eval(r_{j−1}, ρ_{j−1})`), and `eval_weights` is the chain's
terminal. That is Fact 2.1 recomputed at the shaped parameters, including
`(7,3)`, `(8,3)`, `(9,3)`, `(10,3)`, `(13,3)` for the two bilinear slots and
`(N,5)` for the five gated hosts.

**Recomputed by the check, on a second implementation, at degenerate
challenge vectors as well as random ones** [COMPUTED, `rank_dof.py`]. The
code refuses the EXTENSION challenges at 0 and at 1 (`argument.rs:404-406`)
and refuses the main-round challenges at nothing, so the check recomputed
`rank R_s` at 12 or 14 challenge vectors per slot per shape — including a
main `ρ_j = 0`, a main `ρ_j = 1` at three positions each, two equal
coordinates, all coordinates equal, all coordinates zero, and `e₀ = e₁` for
the two bilinear slots. **1,120 checks, none not tight**, and therefore **no
bad challenge set that either page could find**. At the 125M parameters slot
09 sits at `(N, d) = (13, 3)`: **`L = 41`, `dim C = 40`, `rank R = 40`,
`dim ker R = 1`** at every one of those vectors, degenerate ones included.
The controls have teeth: a mask declared one degree low reaches rank **27 of
40**, and a wrong sum weight breaks the chain at round 0.

### 4.2 The miniatures — clauses C1, C2, C4, C5

`closure_miniatures.py` runs the REAL mechanism on small cubes:
`priv_table` (`argument.rs:186-219`), `table_of` (`:221-231`), the
sumcheck prover and verifier (`zkp-core/src/sumcheck.rs:47-160`), the CFS
masker, `extension_round` and `masked_terminal` (`:284-314`), and the
verifier's own `vals`/`g_val` (`argument.rs:383-397`) — all ported line by
line. Five families, **17 miniatures**, each on generic random data from a
named seed:

* **slot 08's shape** at `lkv = 1` (rung-G) and `lkv = 2` (rung-K4 and 125M),
  three seeds each, with the real coordinate lists
  `A_QR8 = fixed(r_t) ‖ rho(0..lkv) ‖ fixed(r_hj) ‖ rho(lkv..)` and
  `A_KR8 = fixed(r_j) ‖ rho(0..lkv) ‖ rho(lkv..)`;
* **slot 09's shape** at both `lkv`, two seeds each;
* **a pad-zero zero-check** with a quadratic private clause (`d·d`, as slot
  02 has), a support gate, a batched pad-zero group and two gated host terms,
  three seeds;
* **slot 19's shape**, where the pad-zero group spans the three `A`
  multiplicities and the three `H` table helpers in one `ζ` sequence
  (`argument.rs:1518-1519`), two seeds;
* **slot 17's shape**, with `supp_Ht` lifted over the trailing axis and
  `supp_S` not, two pad-zero groups whose `ζ` powers continue across them,
  and two host terms gated by DIFFERENT indicators, two seeds.

Each miniature is checked for six properties, at **six values of `π`** (four
random, `π = 0`, and both pair values equal) and against **a second witness
at the same public statement**:

| property | what it is | result |
|---|---|---|
| **P1** | `poly(exts) = 0` at every extension round | **17 of 17** |
| **P2** | the verifier's chain accepts the unmasked transcript — `T′(w, π) ∈ C_s` — for every `π`, including `π = 0` and equal pair values | **17 of 17**, 6 `π` each |
| **P3** | `rank R_s = dim C_s`, `dim ker R_s = 1` | **17 of 17** |
| **P4** | `(fin − poly(vals))·c^{-1}` equals the mask's own `g(ρ_full)` | **17 of 17** |
| **P5** | every terminal equals `cd·T(point) + cm·P`, with `cd`, `cm` non-zero | **17 of 17** |
| **P6** | every `T′(w,π) − T′(w′,π′)` lies in `Im R_s` (disclosed dimension **0** of the sumcheck channel), and the variations are not all zero (rank 3) | **17 of 17** |

Completeness of the repaired bilinear closure is checked too: on all six slot-08
miniatures the honest sum equals the multilinear extension of the true score
plane at `(r_h, r_t, r_j)`, computed by a plain loop over the Boolean cube
that never calls the definition function — and on the same instances the
PRE-repair definition disagrees. [COMPUTED, 6 of 6 each way.]

**What P1..P6 give, put together.** Fix `π` (the reserved-pair values). The
terminals are a function of `(w, π)` alone (the tables are never masked, only
the round messages are: `argument.rs:349`, `:361`). As the mask coefficients
`a` range uniformly over `Fp2^{L}`, the published channel is
`T′(w,π) + R(a)`, which by P2 and P3 is **uniform on `C_s` for every `π`**.
So the channel is independent of `π` and of `w`, and conditionally on it the
terminals are `cd·T + cm·P` with `cm ≠ 0` (P5), uniform in `π`. The joint law
of `(scalar, rounds, terminals)` is therefore `Unif(C_s) × Unif(Fp2^{terms})`
— the same for every witness, and of the dimension the sampler assumes:
`dim C_s = N_s d_s + 1` plus one per terminal. **PROVED HERE for the
miniatures; the ingredients P1..P6 are COMPUTED.** This is Theorem 3.3's
argument (condition on `π`, sum over `α`) instantiated at one slot.

> **CORRECTION, ruling C-5 (the check's B-5): the sentence above is stated
> for a Private or a Standalone slot, and is NOT true as written for the six
> HOST slots.** A Host slot's published scalar is
> `c_h·G_h − Σ_{hs} κ·c_hs·G_hs` (`argument.rs:345`, re-read at `8c5922b`).
> It is **not** `T′(w,π) + R_h(a_h)`: it carries **other slots'** mask
> totals, while `R_h` is a map out of slot `h`'s own `L_h` coefficients
> alone. Two shaped details the re-statement needs, neither of which the
> draft recorded: a host's scalar contains **no honest sum of its own** (a
> host is a zero-check, its own total is zero, and the hosted values arrive
> through `claimed` at `argument.rs:379`), and one hosted coefficient is
> shape-dependent — `SC_SZC` hosts `SC_RS` with `κ = ν₀·per_row`,
> `per_row = size(Dom::S) / size(Dom::Ht)` (`argument.rs:1433-1434`).
>
> **What repairs it, and why the conclusion stands.** A host slot's scalar is
> still **marginally uniform**, because `G_h` is uniform and `c_h ≠ 0`
> (`argument.rs:331-334`). The step that turns the six per-slot statements
> and the marginals into one joint law is the toy memo's **Lemma 2.2** —
> `ZK60_JOINT_LAW_COMPOSITION.md` §2.2, the triangular change of coordinates
> in the `G` totals — which this page inherits and does not re-prove (§4.4
> lists "the 23 slots as one system" among what the miniatures do not model).
> Privacy does not need `κ ≠ 0`: the change of coordinates is triangular in
> `G_h` whatever `κ` is. Soundness does, and `per_row` is a power of two,
> never `0 mod p`. **No conclusion of this page changes; the sentence did.**

**The one structural feature this page said its miniatures did not model, the
checker modelled** [ruling C-2, the check's B-2; COMPUTED, `flip_miniature.py`].
§6.3 item 4 named "a slot whose two private tables are the SAME plane at two
points (slots 15/16's flipped RoPE partner, `argument.rs:1366-1368`)" and
invited a checker to build it. It was built — 5 generic seeds, 7 values of
`π` each, with the real mechanism ported from `priv_table` / `mask_eval` /
`build_claim` / `masked_prove` / `extension` and the verifier's `vals` — and
**18 properties hold, 5 of 5 on each**: `poly(exts) = 0` for every `π`; the
chain accepts the unmasked transcript for every `π`; `g_val` equals the
mask's own `g(ρ_full)`; both terminals equal `cd·T(point) + cm·P`, each with
ITS pair; the two pairs' rows are disjoint; each claim's parts carry ONE PCS
column key **and the two keys DIFFER**; `words = 1 + N(d+1) + terms`;
`rank R = dim C`, every `T′(w,π) − T′(w′,π′)` in `Im R`, variation rank 3.
The key separation is the thing ruling S-3 protects — §3.2. **That feature is
no longer unmodelled; the remaining one is slot 14's 56 terminals** (§4.4).

### 4.3 The controls

(The control labels below are the script's own and are **not** the clause
labels C1..C7 of §1.2.)

| control | what it does | result | why it matters |
|---|---|---|---|
| **C1** | both private factors in extension round 0, no public factor | premise **false**, chain **rejects** | P1/P2 have teeth |
| **C1b** | the same two factors in rounds 0 and 1 | premise true, chain accepts | the toy's own mechanism, isolated |
| **C2** | the public group `eq` dropped from slot 08's closure | premise **true**, chain **accepts**, but the sum is **not** the score target | S19-F1 was a completeness break, not an (H4) break |
| **C3** | a degenerate witness (no variation across key-value groups) | the repaired and the pre-repair definitions **both** hit the target | why a degenerate instance can never decide this clause — the trap of 2026-09-20 |
| **C4** | the pad-zero term moved OUTSIDE the `eq(tau)` bracket | premise **false**, chain **rejects** | the placement is load-bearing for (H4), not cosmetic |
| **C5** | the refusal on terminal challenges | recorded | at `ext = 2` it covers both pair coefficients, not one |
| **P7** | the host cancellation, symbolically at two hosted slots | exact | C5's clause, at `argument.rs:345` / `:379` |

**Four more controls, from the independent check, on its own ports**
[COMPUTED, `results/zk60_slot_closures_shaped_check/`]:

| control | what it does | result | why it matters |
|---|---|---|---|
| the pad-zero term moved OUTSIDE the `eq` bracket, **every** pad-zero arm at **every** shape | `premise_cover.py`'s negative control | premise **false** in **21 of 21** arms | the 92-of-92 premise result is not vacuous |
| a mask declared one degree low, slot 09 at 125M | `rank_dof.py` control | rank **27 of 40** | an under-declared degree would break C3 outright; none does (ruling C-1) |
| a wrong sum weight in the chain | `rank_dof.py` control | chain breaks at **round 0** | the chain check has teeth |
| **this page's own `eq` construction, with the bit order deliberately broken** | `closure_miniatures.py` re-run under a reversed convention | **all 17 miniatures fail P4**, control C3 flips | P1..P6 are not self-fulfilling on the bit-order axis — see §4.4 |

### 4.4 What the miniatures do NOT model

One slot's published field values at fixed challenges. **Not** the PCS
openings (group vectors, proximity vectors, opened columns) — that is (H1)
and gap G-R1; **not** the mask commitment `M`'s opening — that is (H3); not
the hash layer; not the real prover's randomness (the uniform-blinding
idealisation of (H5) is assumed throughout); not the cube sizes of a real
shape (the miniatures use cubes of 8 to 32 positions, with the real
coordinate STRUCTURE but not the real extent); not the 23 slots as one
system (that is Lemma 2.2, which the toy memo proves, and which §4.2's
correction now calls on explicitly for the six host slots); and not a run.
They say nothing about any privacy property of a block.

**The list of unmodelled structural features, after the check.**

* **A slot whose two private tables are the SAME plane at two points** —
  slots 15/16's flipped RoPE partner. **No longer unmodelled:** the checker
  built it, 18 properties on 5 seeds × 7 `π`, all holding (§4.2, ruling C-2).
* **A slot with 56 terminals** — slot 14 (37 `A` + 19 `H` at the rungs).
  **Still unmodelled,** by this page's miniatures and by the check's alike;
  the check did not build it and does not claim to have. The largest
  miniature here has a handful of terminals.
* **The verifier's own `eq_point`.** `closure_miniatures.py`'s `verify_slot`
  substitutes `eval_mle_ext(the prover's own eq table, ρ)` where the real
  verifier calls `eq_point(point, ρ[start..])` (`argument.rs:389`). The check
  verified by hand that the two agree for every `start` and every point
  length, so nothing rides on it — but it is the one place where these
  miniatures are not the real verifier, and it belongs on this list.
* **The port's bit order is not self-fulfilling** [the check's B-8]. This
  page's `eq` tensors are built by a nested per-node construction where
  `mle.rs:48-52` reverses the point first, which is the obvious place for a
  port to be wrong in the same direction twice. The checker tested exactly
  that: the construction **is** most-significant-first and matches `mle.rs`
  value for value, and when the convention is deliberately broken **all 17
  miniatures fail P4** and control C3 flips. So P4 is a real port check and
  not a tautology. (The perturbed run rewrote
  `results/zk60_slot_closures_shaped/closure_miniatures.json` in place; the
  checker restored it by re-running this page's script unmodified and
  reported the directory clean.)

---

## 5. What the machine-checked terminal identities add, and what they cannot

`/home/victor/wt-zk60-jointview/docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE.md`
rounds 2–5 evaluate the verifier's own final identity `fin_s = c_s·mask_eval_s
+ poly_s(vals_s)` from the captured terminals and rebuilt public tables, and
compare it with the capture's stored `terminal_polynomial`: **23 of 23 slots,
69 of 69 checks**, on fully dense generic bundles at rung-G and rung-K4, with
the ports' coordinate lists for slots 08 and 09 re-derived from the shape and
compared entry by entry (12 of 12 lists, 135 entries, 69 fixed coordinates)
[MEASURED, §8.2, §8.4, §9].

| clause | what the gate adds | what it cannot |
|---|---|---|
| **C1** | nothing directly; it reads terminals, not claims | it never sees a `ZClaim`, a reserved pair or a mask row |
| **C2** | **strong**: it recomputes `poly_s(vals_s)` from the published terminals and public tables alone, so "the closure is a public function of the published view" is exercised, not argued, for all 23 slots at two shapes | it is the verifier's own check recomputed — a receipt agreeing with itself — at **two** challenge vectors |
| **C3** | **useful**: it derives each slot's `(main, ext, degree)` from the shape and compares it with the slot's declaration AND with the shape's table (6 of 6 for the bilinear pair), and re-derives every challenge of the replay | it never touches the mask coefficients, `R_s`, or `M` |
| **C4** | **weak, and this is the important line**: an identity that holds on runs that verified is not the identity `poly(exts) = 0`, which must hold **identically**, for every witness and every `π`. The gate cannot distinguish "the premise is true" from "the prover and the verifier share one wrong definition" — which is exactly how S19-F1 survived a round trip | this is why §4's P1 and P2 exist, and why condition O-1 is still owed |
| **C5** | it checks the claimed sums as the verifier forms them | it does not check the hosted list against `HOSTS` — and **nothing else does either**, at any shape (ruling C-3, gap S-C3(i) as restated in §6.2) |
| **C6** | **strong**: the replay accounts for every transcript position and every published word, and the segment byte lengths match the schedule to the byte | it does not show that nothing else about a private factor is *derivable*, only that nothing else is *transmitted* |
| **C7** | nothing | the budget is a layout fact |

**Net.** The gate closes C2 and C6 empirically at rung-G and rung-K4, and
adds nothing at 125M (no bundle exists at that shape; the run gate cannot
ingest 484 MB). It does not close C4, which is the clause the shaped
additions actually put at risk, and which §4 closes by computation on
miniatures and by reading all 23 arms.

**C6, measured again on a real bundle by the check** [MEASURED,
`bundle_words.py`, bundle `run-i-dense-k4`, stage 0]. On that bundle **23 of
23** slots satisfy `words = 1 + N(d+1) + terminals` exactly, for a total of
**1,269 slot words = 20,304 bytes** — this page's counted rung-K4 figure
(§2.1) confirmed to the word on a real receipt — and the chain and the
terminal identity re-run from the published fields alone for all 23. The
wire writer puts a scalar, the round messages and the terminals into a slot's
frame and nothing else (`wire.rs:394-398`): no length prefix, no hosted
value, no pad-zero extra. What a slot publishes is what the count says.

---

## 6. Step table, and what the checker should attack first

### 6.1 The steps

| # | step | label |
|---|---|---|
| 1 | (H4) stated as C1..C7 | REDUCED to (`ZK60_JOINT_LAW_COMPOSITION.md`, §3.1–3.2) and (`..._RUN.md`, §2.8) |
| 2 | the three travelling conditions are shape-free | REDUCED to (`ZK60_TERMINAL_SURJECTION_REVIEW.md`, §1.4, §5 R-1) |
| 3 | the per-slot schedule at the three shapes | COUNTED (138 of 138 per shape against the lane's model) |
| 4 | `rank R_s = N_s d_s + 1`, `dim ker R_s = 1` at every shaped slot | COMPUTED (92 of 92; recomputed independently at 1,120 (slot, shape, `ρ`) points including degenerate `ρ`, 0 not tight) |
| 5 | `poly_s(exts) = 0` at every extension round, all 23 arms | VERIFIED IN THE CODE (23 of 23 read at `8c5922b`, and re-read by an independent checker) + COMPUTED (17 of 17 miniatures, control C4 negative). **STRONGER after the disposition (§1):** at every shaped layout every monomial carries a public factor, so `poly_s(exts)` is the ZERO POLYNOMIAL, not a value that vanishes — COMPUTED 92 of 92 arms, 600 evaluations, 21 of 21 negative controls |
| 5a | no slot **under**-declares its degree; four slots over-declare by one where their domain pads | COMPUTED (`degree_maxplus.py`, self-checked against `BASE_DEGREE` at the toy 23 of 23) — ruling **C-1**, not changed, recorded as slack |
| 6 | the pad-zero term adds no claim site, no terminal, no round | COUNTED + VERIFIED IN THE CODE (seven arms) |
| 7 | the terminal decomposition `cd·T + cm·P`, `cm ≠ 0` at `ext = 2` | PROVED HERE (from `argument.rs:409`, `:413`, `:404-406`) + COMPUTED (P5) |
| 7a | the flipped RoPE partner: one plane, two claims, two keys that differ | COMPUTED (`flip_miniature.py`, 18 properties, 5 seeds × 7 `π`) — clause C1 reworded per ruling **C-2**; the key separation is ruling S-3's, margin 6–8 bits |
| 8 | the host cancellation | VERIFIED IN THE CODE + COMPUTED (P7) |
| 8a | the hosted **list** matches `HOSTS` at a shaped layout | **NOT CHECKED BY ANYTHING** — ruling **C-3**, gap S-C3(i); a **soundness** matter, a generic test owed on the lane |
| 9 | slots 21/22 publish nothing of the boundary's opening in their own stage | PROVED HERE (by inspection of `argument.rs:373-399`, `run.rs:487-547`) |
| 10 | the joint law of one slot's published view is `Unif(C_s) × Unif(Fp2^{terms})` | PROVED HERE **for the miniatures**, on P1..P6 — **for Private and Standalone slots**; the six HOST slots need Lemma 2.2's change of coordinates, inherited (ruling **C-5**, §4.2) |
| 10a | what a slot publishes equals `1 + N(d+1) + terminals` on a real receipt | MEASURED (`bundle_words.py`, `run-i-dense-k4` stage 0: 23 of 23, 1,269 words = 20,304 B) |
| 10b | no verifier-side panic is reachable from a malformed receipt | VERIFIED IN THE CODE by the check (wire decoder, `sumcheck::verify`, the public-length refusal, `pcs::verify_zk`, `mask_verify` all return `Err`) — ruling **C-4** |
| 11 | ruling S-1's hypothesis, and the pairless LogUp sum claim | REDUCED to (`ZK60_GENERIC_RANK_LEMMA_SHAPED_DISPOSITION.md`, S-1) — **outside this reading** |
| 12 | (H4) at the 125M shape | ARGUED — the reading is the same reading, the counts are computed, but **nothing at 125M has ever been evaluated by any tool** |
| 12a | the pad rule's challenge cost: **8 `ζ` + 8 `mu_pad` at rung-G, 8 + 8 at rung-K4, 5 + 5 at 125M**; 105 / 107 / 126 extra `Fp2` from the DECLARED degree rise, of which 54 / 56 / 86 the closure needs | COUNTED, three independent counts — ruling **C-6**; ruling R-7 was amended at 00:43 on 2026-09-21 and no longer says "≤ 7" |
| 13 | the closure property as a whole | **HOLDS WITH CHANGES: gap G-R2 is closed as a READING at all three shapes, conditional on the three gaps below.** Four of the seven clauses carry a named defect (C-1 bookkeeping, C-2 wording, C-3 and C-4 enforcement); none is a break of (H4) |

### 6.2 The gaps, by name

> **GAP S-C1 — the premise is a reading, not a test, and it can rot.
> [TAKEN UP — ruling C-7]**
> Condition O-1 of the toy's independent check — a Rust test that, for each
> slot, evaluates `def.poly` on a vector supported on that extension round's
> private tables and asserts zero — is **still not written**, at any shape.
> §4's P1 tests ported miniatures, not `def.poly` itself. One test would
> close C4 for all 23 slots at every shape the module can build, at every
> future schedule edit, and it is cheap: `define` is already driven from a
> `Shape`, and `run_slot` already builds `exts` (`argument.rs:353-360`).
> **This is the single highest-value thing the integrator can do off this
> page.**
>
> **TAKEN UP** (ruling C-7): the test is on the lane, owed, not written. Two
> things about it have changed since the draft. **(a)** Under the stronger
> form of C4 (disposition §1) the test can assert **identity to zero for
> arbitrary values** of the reserved-pair evaluations, not merely zero at the
> honest ones — a strictly stronger assertion, and the one the theorem wants.
> **(b)** It should assert the **degree** as well as the premise (the check's
> B-1): evaluating `def.poly` in the max-plus degree semiring, or bounding
> it, would catch an under-declared degree, which would break C3 outright and
> which this page's method — read the declared triple, never ask what
> `def.poly` is — structurally cannot see. Both independent implementations
> are ports of the arms, not the arms; only this test closes that.

> **GAP S-C2 — nothing at 125M has been evaluated. [STANDS AS WRITTEN]**
> Every computed figure
> here for 125M comes from the shape model, not from a proof or a capture.
> The run gate has no 125M bundle and cannot ingest one. So step 12 is
> ARGUED. What would close it: a slot-level capture at 125M (one stage, the
> 23 slots' `(main, ext, degree)`, terminals and `terminal_polynomial`), or
> the O-1 test of S-C1, which closes it without a capture.
>
> **STANDS EXACTLY AS WRITTEN** after the check, which says so in its own
> words: every 125M number on either page comes from the shape model, and
> both checkers' scripts are ports of the arms, not the arms.

> **GAP S-C3 — three enforcement points are test-only or are panics, not
> named refusals. [NARROWED — rulings C-3 and C-4; item (i) is a SOUNDNESS
> gap today, not a future-edit risk]** *(All three restated below after the
> check and the disposition; the gap keeps its name and none of its three
> items is dropped.)*
>
> **(i) NARROWED, and it is worse than the draft said — and it is a
> SOUNDNESS matter, not a privacy one** (ruling C-3, the check's B-3). The
> draft said "every private slot is hosted exactly once by a Host that runs
> after it" is asserted in `layout.rs:1325-1337`, inside `mod tests`, against
> the toy's frozen constants, so the risk is a future edit. The true position
> at `8c5922b`: that assertion checks `HOSTS` against `SLOT_KINDS` and
> **never touches `define`**. The hosted lists that actually run are
> **literals inside each arm** — `vec![(SC_SS, nu[0]), (SC_SSM, nu[1])]` at
> `argument.rs:982`, and six more, e.g. `SC_SZC`'s
> `vec![(SC_RS, ν₀·per_row), (SC_SCORE, ν₁)]` at `:1433-1434` — and
> **nothing, test or production, at the toy or at a shape, compares those
> literals with `HOSTS`**. The only production check is `run_slot`'s
> `(kind == SlotKind::Host) == def.hosted.is_empty()` (`argument.rs:305`): a
> Host must host at least one slot and a non-Host none. The count, the
> identities and the once-only property are unchecked. **It is not a privacy
> defect.** A private slot hosted zero times would have its honest sum
> unconstrained — a soundness hole — but its published scalar would still be
> `S + c·G`, uniform, and its terminals still pair-masked; hosted twice, the
> change of coordinates stays triangular. So C5's real content for (H4) is
> only "the hosted mask totals cancel", which they do by construction on both
> sides (`argument.rs:345`, `:379`) and which both pages confirm.
> **A test, generic over every shape, is owed on the lane; the integrator is
> told.** The cheap fix is three lines in `run_slot`: compare `def.hosted`'s
> slot list against `HOSTS[host]`.
>
> **(ii) RESTATED** (ruling C-4, the check's B-4). The mask budget
> `L + 256 ≤ 512` is asserted per shape only in tests (`grow_tests.rs:535`,
> `k4_tests.rs:158`, `pad.rs:896-898`, `s20_review_tests.rs:503`). The
> "production guard" is a **prover-side** runtime `assert!` inside
> `mask_commit` (`zk.rs:442`, re-read at `8c5922b`; only the prover calls
> `mask_commit`, `zk.rs:1315`, `:2653`). `Shape::new` has **ten** refusals
> and **none of them is the budget** — seven are geometry (a zero axis, a
> non-power-of-two axis or width, `d_pad ≠ h_pad·head_dim`, the two head
> divisions, the row range) and three are the named rulings F-2, S-1 and S-3
> [COUNTED, `shape.rs:100-326`]. So an over-budget shape kills the PROVER at
> construction time; no frame can reach it. Every shape in scope passes with
> room (the worst is `117 + 256`). **The mask budget becomes a named shape
> refusal, with a test, on the lane** — the disposition's ruling.
>
> **(iii) UNCHANGED, and confirmed define-time.** In slots 03, 14, 15, 16 and
> 18 the pad-zero group's
> planes are resolved through `B::tab` (`argument.rs:537-539`), which returns
> `usize::MAX` for a plane the slot's `a_range` did not sweep; `PadTerm::eval`
> would then index out of bounds and panic where a refusal is owed. It is
> unreachable at every shape this module builds (each domain is one
> contiguous plane run, `layout.rs:1376-1384`, and each sweep covers its
> domain), and slots 02, 17 and 19 already have the named refusal — but the
> other five do not. All three are the class of finding F-2 and F-6, and all
> three are shape-only: no refusal here can depend on a witness.
>
> **What "panic" does NOT mean here, and the draft should have said so**
> (ruling C-4). **No verifier-side panic is reachable from a malformed
> receipt.** The check read the whole verify path at `8c5922b` and found
> none [VERIFIED IN THE CODE]: `wire::decode` checks the exact frame length
> and every field word's canonicality, reads each slot's rounds and terminals
> at the schedule's own widths through a bounds-checked reader and refuses
> trailing bytes (`wire.rs:115-120`, `:225-243`); `sumcheck::verify` refuses
> a wrong round count and a wrong round width before touching them
> (`sumcheck.rs:141-152`); the `Tab::Pub` length refusal now sits BEFORE the
> Prove/Verify split (`argument.rs:317`, finding F-6's fix), so
> `eval_mle_ext`'s own `assert_eq!` is unreachable behind it;
> `sp.terms.len() != n_priv` is refused (`argument.rs:375`) and
> `es[p.ext_round]` is guarded by the `ext_round >= ext` refusal (`:308`);
> `pcs::verify_zk` and `zk::mask_verify` return `Err` on every length,
> column-count, column-index and Merkle-depth mismatch. **All three of this
> gap's panics are define-time and shape-driven: they can be reached by a
> developer declaring a new shape, never by an attacker sending a frame.**
> Nobody should read this gap as a denial of service on the verifier; the
> opposite reading would be a security finding, and this is not one.

Three further items I record without calling them gaps.

* **Ruling R-7's "≤ 7 `ζ`" was wrong at the rungs, and R-7 has been amended**
  (§3.3, ruling C-6): a proof draws 8
  `ζ` and 8 `mu_pad` at rung-G and at rung-K4 because slots 15 and 16 share one
  source line and are two slots, and 5 and 5 at 125M. It is an inventory
  correction, not a
  soundness or privacy change, and no proof byte moves. Three independent
  counts agree, and `ZK60_JOINT_LAW_COMPOSITION_RUN_DISPOSITION.md` §2
  records the amendment at **00:43 on 2026-09-21**. Nothing here is open.
  The run memo's 105 / 126 degree-rise figures reproduce exactly — but see
  ruling C-1 for what they mean: 51 / 51 / 40 `Fp2` of the 105 / 107 / 126
  buy nothing, because four of the eight slots' closures do not rise.
* **The same section says `mu` entries are refused on zero; they are not**
  (§3.3). Only `nu` and `ζ` pass through `nonzero`. A soundness term of
  `2^-128` per slot, no effect on (H4), and it shrinks rather than grows the
  liveness inventory. Ruled (disposition §1): soundness only, because `mu`
  enters the polynomial and never a terminal, a claim point or a pair
  coefficient.
* The boundary opening's **exact-group-count** refusal is a further
  challenge-only liveness event not in the run's inventory (§3.5, 2^-1280 at
  rung-G, 2^-1792 at 125M).
* The **pairless LogUp sum claim** is not any slot's claim and is therefore
  not covered by this reading (§3.7); it is `protocol.rs:167-178`, appended
  at `protocol.rs:310-314`, and belongs to G-R1.

### 6.3 What the checker should attack first — and what the checker did

*The six items below are the draft's own invitation, kept verbatim, each with
what the independent check made of it.*

1. **The claim that `eq(tau)` wraps the pad-zero term in ALL seven hosting
   arms.** It is seven line citations and one misreading would falsify the
   whole of §3.3. Re-read `argument.rs:1014, 1041, 1281, 1287, 1333, 1340,
   1392, 1401, 1469, 1475, 1525` at `8c5922b` against my claim, and check in
   particular the two arms where `pz` is added to `zc` *before* the
   multiplication (`:1281`, `:1333`) rather than inline.
   → **DONE, CONFIRMED.** The checker re-read every one of those lines,
   including the two, and found every arm to be
   `v[eq(tau)] · ( … + pz.eval(v) )`. "The citation list is accurate and the
   conclusion is right."
2. **Slot 17's second pad-zero group.** `supp_Ht` is lifted over the trailing
   `j` axis of the `Dom::S` cube and `A_MX`/`A_SUM` are read on the LEADING
   coordinates. If the lift did not tile, `tile_rep` refuses — but does the
   *group* then batch the right two planes at the right `ζ` powers? I
   modelled it (§4) but I did not evaluate the real `define`.
   → **STILL OPEN, and named as such by both pages.** The checker confirmed
   the group membership and the `ζ` power continuation by reading
   `pad.rs:365-381` and `argument.rs:1444-1454`, modelled it, and decided the
   `[A_MX, A_SUM]` refusal's reachability by scan (below) — but did not
   evaluate the real `supp_Ht` lift against a real cube either.
3. **My claim that C1 is the only clause slots 21/22 change in a run.** I
   read `argument.rs:373-399` and `run.rs:487-547` and found no cross-stage
   term. A checker should look for one in `verify_core`'s `io_claims` path
   and in `wire::decode_segment`.
   → **DONE, CONFIRMED.** `run.rs:498-509`: the boundary's root is absorbed
   at step 2 of stage `k`, before `prove_core` and so before any slot
   challenge; the two sites are disjoint by construction; no cross-stage term
   in `argument.rs:373-399` or the wire path. The hand-off of the gluing to
   G-R1 is called the correct call.
4. **The miniatures' fidelity.** They are a port, and a port can be wrong in
   the same direction twice. The sharpest attack is: find a structural
   feature of a real slot that my miniature does not have and that could
   break P1 or P2. Candidates I know of and did not model: a slot whose two
   private tables are the SAME plane at two points (slots 15/16's flipped
   RoPE partner, `argument.rs:1366-1368`), and a slot with 56 terminals
   (slot 14).
   → **HALF DONE.** The flipped RoPE partner **was built** and everything
   holds (§4.2, 18 properties, 5 seeds × 7 `π`) — but it forced the
   rewording of clause C1 (§1.2, ruling C-2) and exposed that ruling S-3 is
   what keeps the two column keys apart. **Slot 14's 56 terminals remains
   unmodelled** by this page and by the check alike (§4.4). The checker also
   attacked the port's own bit order and could not break it (§4.4, B-8).
5. **The `ζ` recount of §3.3.** I claim ruling R-7 is wrong at the rungs. It
   is one `filter` in `argument.rs:933` and one shared match arm at `:1344`;
   a checker should re-derive it and, if I am right, say so to the security
   owner, because R-7 is a recorded ruling.
   → **DONE, CONFIRMED, AND RULED.** The checker re-derived it from
   `pad.rs:pad_zero_host` and the padded-domain sets and said so to the
   security owner; R-7 was amended at 00:43 on 2026-09-21. 8 / 8 / 5.
6. **Whether "8 / 3 / 12" is the right split.** I count a slot as needing a
   new argument if any clause of §3.8 is `A`, and I do not count a longer
   round count as a change. A checker may reasonably argue slots 00, 01 and
   04 need a new argument too, because their degree rise comes from a factor
   (`supp`) that is a `Tab::Pub` the toy never had — I treat that as a count
   because the mechanism (`eq` kills the monomial in `exts`) is the toy's.
   → **NOT DISPUTED.** The checker did not argue the split; it attacked the
   table's cells instead, and the one row it found wrong about the code is
   C3 for slots 14/15/16/18 (ruling C-1, §3.3), which moves no slot between
   the three groups.

**What a next checker should attack, after this one.** (a) Slot 17's second
pad-zero group against the real `define` — item 2, still the sharpest
unevaluated place on either page. (b) A miniature with slot 14's 56
terminals. (c) Whether the `Gate`'s placement is right for **soundness**:
both pages read it only for what it publishes, and §3.4's "neutral either
way" is a statement about (H4) alone — whether the LogUp arm must stay
ungated is a soundness question neither page answers.

**Two shape cliffs the checker closed rather than argued** (its B-7), both
recorded here because they are liveness facts about these closures.
`argument.rs:1449-1451` refuses slot 17 whenever
`zero_rule_a_planes(Dom::Ht) != [A_MX, A_SUM]`, and a shape where `Dom::S`
pads but `Dom::Ht` does not would produce exactly that — an honest shape
refused with a message that misdescribes the cause. **It is unreachable:**
under ruling F-2 (`shape.rs:252-260`, no P-3 lift of `Dom::S`),
`size(Dom::S) = h_pad·t_pad²` and `size(Dom::Ht) = h_pad·t_pad`, so with
`t_pad ≥ tokens` and `h_pad ≥ q_heads`, `Dom::Ht` pads **iff** `Dom::S`
does; a scan over 635 F-2-legal geometries (of 720 candidates) finds none
[COMPUTED, `counts_and_cliffs.py`]. The second is the flipped partner's PCS
key, closed by ruling S-3 with 6 to 8 bits of margin (§3.2). Both are
liveness cliffs closed by rulings written for other reasons.

### 6.4 Where gap G-R2 stands, in the security owner's words

This is the disposition's §3, reproduced so that this page and the ruling
cannot drift apart.

> At the two development shapes (H4) is read, computed and — for the terminal
> identity and the published-word count — measured on fully dense bundles;
> what is left there is enforcement (C-3, C-4, C-7). **At the 125M shape
> every figure is a count or a computation at that shape's parameters;
> nothing has been evaluated on a 125M receipt, and the present tools
> cannot.** Same limit, same wording, as for the per-commitment lemma.

And the disposition's own framing of what this page is: **not a privacy
acceptance of anything** — it narrows gap G-R2, the hypothesis (H4) of the
run's composition theorem, and no more.

---

## 7. What this is not

* **It is not a privacy acceptance.** It discharges one hypothesis, (H4), of
  a theorem whose other hard hypothesis, (H1) / gap **G-R1**, is open from
  the start at both new shapes and has no proof at any of them. Theorem A and
  Theorem B remain conditional statements.
* **It is not a measurement.** Nothing here was proved, verified, timed or
  captured. The only MEASURED figures I cite are the run gate's, and I cite
  them as somebody else's.
* **It is not a statement about 125M.** Every 125M figure is COUNTED or
  COMPUTED from the shape model. Gap S-C2 says so.
* **It is not a soundness review.** The pad rule, the support gates and the
  repaired bilinear slots exist for soundness; I read them only for what they
  publish.
* **It does not cover the pairless LogUp sum claim, the `M` opening, the PCS
  openings, the hash layer, the run's refusal channel, or the real prover's
  randomness.**
* **It does not supersede the toy reading.** The toy profile is frozen and
  D22 rests on it; nothing here touches it.

---

## 8. What the check changed

One line per finding of `ZK60_SLOT_CLOSURES_SHAPED_CHECK.md`, with the
ruling that disposed of it. The check found **no break of (H4)** at any of
the three shapes.

| finding | what it changed on this page | ruling |
|---|---|---|
| **its §0** (not a numbered finding) | **C4 is stronger than drafted**: at every shaped layout every monomial of all 23 arms carries a public factor, so `poly(exts)` is the zero polynomial in the prover's values; the second mechanism is needed only at the toy. 92 of 92 arms, 600 evaluations, 21 of 21 negative controls | disposition §1 |
| **B-1** | §3.8's C3 cells for slots 14, 15, 16, 18 now say **DECLARED** degree: the closure's degree stays at 4 wherever their domain pads. The 105 / 107 / 126 `Fp2` degree-rise cost splits into 54 / 56 / 86 the closure needs and 51 / 51 / 40 that buy nothing (816 / 816 / 640 B per block, 7,680 B per twelve-block 125M run). No slot under-declares | **C-1: not changed**, recorded as slack |
| **B-2** | clause **C1 reworded** — per `Tab::Priv`, not per plane: slots 15/16's flipped rotary partner makes the same plane raise two claims at points differing in one flipped coordinate. The checker built the miniature this page said it had not (18 properties, 5 seeds × 7 `π`, all holding). Their column keys separate only because `log2(head_dim) ≤ log_cols`, which **ruling S-3** enforces, with 6–8 bits of margin | **C-2**; S-3's documentation and test are being extended on the lane to say so |
| **B-3** | gap **S-C3(i) restated and narrowed**: nothing, test or production, compares `define`'s literal hosted lists with `HOSTS` at any shape. A **soundness** matter, not a privacy one; the cancellation that (H4) actually needs is confirmed | **C-3**: a generic test, over every shape, owed on the lane |
| **B-4** | the mask budget's "production guard" is a **prover-side** assertion inside `mask_commit` (`zk.rs:442`); `Shape::new` has ten refusals and none is the budget. And every "panic" in gap S-C3 is qualified: **no verifier-side panic is reachable from a malformed receipt**, and all three panics are define-time and shape-driven | **C-4**: a named shape refusal, with a test, owed on the lane |
| **B-5** | §4.2's joint-law sentence **corrected for the six HOST slots** — a host's scalar carries other slots' mask totals and is not `T′ + R_h(a_h)`; marginal uniformity stands, and the joint step is the toy's Lemma 2.2, now cited by document and section. No conclusion moved | **C-5: errata** |
| **B-6** | three confirmations stated with more force: the **ζ recount** (8 / 8 / 5, three independent counts; ruling R-7 amended at 00:43 on 2026-09-21); **`mu` is not refused on zero** and that is soundness-only, because `mu` enters the polynomial and never a terminal, a claim point or a pair coefficient; the **rank identity has no unrefused bad set** — 1,120 checks including degenerate challenge vectors, none not tight, slot 09 at 125M `L = 41`, `dim C = 40`, `rank 40`, `kernel 1`, with a degree-`(d−1)` mask reaching only 27 of 40 | **C-6** for the ζ count; disposition §1 for the other two |
| **B-7** | two shape cliffs decided rather than argued, both closed and both now recorded in §6.3: slot 17's `[A_MX, A_SUM]` refusal is unreachable under ruling F-2 (635 F-2-legal geometries scanned, none found), and the flipped partner's PCS key is closed by S-3 | no ruling needed |
| **B-8** | this page's own `eq_table_msb` port was attacked for a bit-order defect and **found clean**: it is most-significant-first and matches `mle.rs` value for value, and breaking the convention deliberately fails all 17 miniatures at P4 — so P4 is a real port check, not a tautology. One place where the miniature is not the real verifier (`eval_mle_ext` in place of `eq_point`) is now listed in §4.4 | no ruling needed |

**What the check did not change.** The 138-of-138 schedule counts, the
92-of-92 rank identity, the 17 miniatures and their P1..P6, the seven-arm
bracket reading, the receipt arithmetic (+21 words / +336 B at rung-G, +35 /
+560 at 125M; 1,254 / 1,269 / 1,751 slot words), slots 21/22's ordering in a
run, the "8 / 3 / 12" split, and every gap by name. Two independent readings
of the 23 arms agree, two independent implementations of every computation
agree, and the two pages disagree on **no number** and on **one clause's
wording**.
