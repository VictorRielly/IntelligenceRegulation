# Independent check of the 23 shaped slot closures

**Verdict on the closure property as claimed: HOLDS WITH CHANGE.**
**Verdict on C4 in the strong form (`poly(exts) = 0` for every `π`, not only
honest `π`): HOLDS — and more strongly than the memo states.**

I found no break of (H4) at any of the three shapes. I found one clause row
of the memo's own verdict table that is wrong about the code, one clause
statement whose wording does not describe what slots 15 and 16 do, one cost
figure that is correctly counted but wrongly explained for about half of
itself, and three places where the memo credits a per-slot reading with what
a shape-free production check actually enforces.
None of them changes the memo's headline. One of them changes a number the
security owner may be asked to sign.

Written by an independent adversarial checker who did not write the memo.
2026-09-21, 01:15 PDT (`date` on the WSL box). Read-only at lane commit
**`8c5922b`** (`/home/victor/wt-zk60-block125m`). Nothing built, proved or
committed. Evidence and scripts: `results/zk60_slot_closures_shaped_check/`
(README there says how to rerun each one).

**This is not a privacy acceptance of anything, and it does not upgrade the
memo into one.** It says that one hypothesis of one theorem survives an
attack at two development shapes and one counted shape.

---

## 0. What I attacked, and what happened

The brief told me to assume the memo is wrong. I went at C4 first, because
that is the clause the shaped additions put at risk and the clause a
verifying run cannot test. I could not break it. So I stopped arguing and
computed it: **all 23 arms, at all four shapes, at both extension rounds of
the bilinear slots, at six random values of the reserved-pair evaluations —
600 evaluations, 92 of 92 (slot, shape) arms give exactly zero** [COMPUTED,
`premise_cover.py`], with the memo's own negative control (the pad-zero term
moved one bracket outwards) turning the premise FALSE in **21 of 21**
pad-zero arms, so the test is not vacuous.

That is a stronger result than the memo's, and the memo undersells its own
structure. The memo says the premise rests on two mechanisms ("a public
factor kills the monomial" and "the other private factor is zero"), and that
slots 08/09 are "singly determined at the toy" and "over-determined at the
shapes". The sharper true statement, which I checked arm by arm at `8c5922b`:

> **At every SHAPED layout, every monomial of every one of the 23 closures
> carries a public factor** — a `Tab::Eq`, a `Tab::Pub`, or the group `eq` of
> the two repaired bilinear slots. So `poly(exts)` is not merely zero at
> every `π`; it is the ZERO POLYNOMIAL in `π`. The second mechanism ("the
> other private factor is extended in a different round") is needed at
> exactly one place in the whole module: slots 08 and 09 at `lkv = 0`, i.e.
> at the frozen toy, where `group_eq` returns `None`.
> [VERIFIED IN THE CODE, 23 arms; COMPUTED, 92/92.]

And it does not depend on honest behaviour anywhere. `exts` is built by
`run_slot` from the DEFINITION (`argument.rs:353-360`: every table that is
not a private table of this round gets a hard `Fp2::ZERO`), and the verifier
models the same thing by multiplying every public table's main-variable value
by `sel = ∏(1 − e_j)` (`argument.rs:383`, `:389-390`). A public table's value
at an extension coordinate is therefore **0**, not 1 and not a natural
extension — the brief's question — and both sides agree on that by
construction, not by agreement. A malicious prover chooses round messages,
never `exts`.

Then I went at the rest. What follows is what survived.

---

## 1. Clause table

`V` = holds as the memo states it. `V*` = holds, but the memo's statement of
it is wrong or incomplete in a way I name below. `?` = outside what I could
decide.

| clause | verdict | how I decided it |
|---|---|---|
| **C1** claim placement | **V\*** — finding B-2 | the arithmetic `cd = ∏(1−e_j)`, `cm = e_r ∏_{j>r}(1−e_j)` re-derived from `argument.rs:409`, `:413` and computed end to end on a miniature; the wording is false for slots 15/16 |
| **C2** a public closure | **V** | re-run on a real bundle: the chain and `fin = c·mask_eval + poly(vals)` from the published fields alone, **23 of 23 slots**, `run-i-dense-k4` stage 0 [MEASURED, `bundle_words.py`] |
| **C3** the declared masking | **V\*** — finding B-1 | `rank R_s = N_s d_s + 1`, `dim ker R_s = 1` at **1,120** (slot, shape, `ρ`) points, 0 not tight [COMPUTED, `rank_dof.py`]. The mask covers the channel at the DECLARED `(N, d)`. But the memo's row "`N` (deg 4→5)" for slots 14/15/16/18 is wrong about the closure |
| **C4** the construction premise | **V**, stronger | 92/92 arms, 600 evaluations, 21/21 negative controls [COMPUTED, `premise_cover.py`]; all 23 arms read at `8c5922b` |
| **C5** host discipline | **V\*** — finding B-3 | the cancellation re-derived from `argument.rs:345`/`:379`; the enforcement is weaker than the memo's own gap S-C3(i) says, and the matter is soundness, not privacy |
| **C6** nothing else is published | **V** | counted on a real bundle: **1,269 words = 20,304 B** at rung-K4, **23 of 23** slots equal `1 + N(d+1) + terms`, and `wire.rs:394-398` writes scalar, rounds and terminals and nothing else — no length prefix, no hosted value, no pad-zero extra [MEASURED] |
| **C7** the mask budget and geometry | **V\*** — finding B-4 | the budget holds at all three shapes; the "production guard" is PROVER-side and `Shape::new` carries no mask-budget refusal at all |

---

## 2. Findings

### B-1 — the declared degree of four slots exceeds the closure's, and the memo prices the difference as a real cost of the pad rule

**The memo's text.** §3.8's clause table marks C3 as "`N` (deg 4→5)" for
slots 14, 15, 16 and 18. §3.3 says the pad rule's "only trace in the
published view is that the slot's round messages are one `Fp2` longer per
round in the eight `INDICATOR_SLOT_DOMAIN` slots whose domain pads — a degree
rise", and prices it at "**105** extra `Fp2` in round messages at rung-G and
**126** at 125M (and 107 at rung-K4)". §6.1 step 12a records those figures as
COUNTED.

**My evidence.** I evaluated every arm's closure in the max-plus degree
semiring — each table value degree 1, a constant degree 0, `+` → max, `·` →
sum — an exact port of the arithmetic of each `define` arm, giving an UPPER
bound on the total degree. The port reproduces `BASE_DEGREE` at the toy
**23 of 23**, which is the self-check [COMPUTED, `degree_maxplus.py`]. At the
shapes:

| slot | declared at a padding shape | closure's degree (upper bound) |
|---|---|---|
| 00, 01, 04, 17 | 4, 4, 4, 5 | 4, 4, 4, 5 — **tight** |
| **14, 15, 16, 18** | **5** | **4** |

The reason is structural and the memo's own §3.4 states the premise for it
without drawing the consequence: `Gate` is put on the inhomogeneous clauses
and the host terms and is **never** put on the LogUp arm
(`argument.rs:748-752`). In slots 14, 15, 16 and 18 the LogUp arm
`v[eq]·h·d₁·d₂` is what sets the degree (4), and every gated monomial is at
most degree 3 before the gate. So the gate cannot raise those four slots'
degree. In slots 00, 01, 04 and 17 the gated monomial IS the maximal one, and
the rise is real.

**What it costs.** Nothing for correctness — over-declaring a degree is safe
(the round messages are evaluated at `d+1` points, the mask has `L = Nd+2`
coefficients, and my rank check confirms the covering is exact at the
DECLARED pair). It costs receipt bytes, and it makes the memo's cost figure
wrong in its meaning:

| shape | memo's degree-rise cost | of which the closure needs | of which buys nothing |
|---|---|---|---|
| rung-G | 105 `Fp2` | **54** | **51 = 816 B per block** |
| rung-K4 | 107 `Fp2` | **56** | **51 = 816 B per block** |
| 125M | 126 `Fp2` | **86** | **40 = 640 B per block, 7,680 B per 12-block run** |

[COUNTED, `counts_and_cliffs.py`.] It also inflates `L` for those four slots
(slot 14 at 125M: `L = 102` where 82 would do), which is inside the
`L + 256 ≤ 512` budget either way.

**Why it matters beyond bytes.** The memo's method — read `Shape::slots()`'
declared triple, never ask what `def.poly` actually is — structurally cannot
see this. The same method would not see the dangerous direction either. I
checked that direction too: **no slot under-declares at any of the four
shapes** [COMPUTED]. An under-declared degree would break C3 outright (the
mask would not cover: a degree-`d−1` mask spans 27 of the 40 dimensions of
slot 09's channel at 125M [COMPUTED, control]) and break completeness. It is
worth a Rust test of its own, next to the O-1 test gap S-C1 asks for.

**Smallest repair.** Two lines of the memo: say "the DECLARED degree rises"
in §3.8's C3 cells for slots 14/15/16/18, and split the 105 / 107 / 126 into
54 / 56 / 86 needed and 51 / 51 / 40 not. If the bytes are wanted back, the
`indicator` term of `shape.rs:795` would have to be gated on the indicator
landing on a maximal-degree monomial — a shape change, not a memo change, and
not worth doing for 816 bytes before the 5 s work lands.

### B-2 — C1's wording is false for slots 15 and 16: one plane, two claims

**The memo's text.** C1 (§1.2): "*Every private plane a slot reads is a
`Tab::Priv` that raises exactly one `ZClaim` on its own commitment*".

**My evidence.** `argument.rs:1361-1368`: slot 15 pushes `A_Q8` through
`a_range`, and then pushes the **same plane id** again at a coordinate list
with one coordinate flipped (`cf[log − ldh] = Coord::Flip(log − ldh)`). Same
commitment, same slice offset, two claim points, two reserved pairs, two
terminals. Slot 16 does the same with `A_K8`. So a plane can raise **two**
claims in one slot. The true statement is per `Tab::Priv`, not per plane, and
the memo's own §2.2 table lists the partner as a separate site — the prose
and the table disagree.

The memo names this (§6.3 item 4) as a structural feature its miniatures do
NOT model and invites a checker to build it. I built it
[`flip_miniature.py`, 5 generic seeds, 7 values of `π` each, the real
mechanism ported from `priv_table` / `mask_eval` / `build_claim` /
`masked_prove` / `extension` / the verifier's `vals`]. **Everything holds**:

| | |
|---|---|
| `poly(exts) = 0` for every `π` | 5/5 |
| the chain accepts the unmasked transcript for every `π` | 5/5 |
| `g_val` equals the mask's own `g(ρ_full)` | 5/5 |
| both terminals equal `cd·T(point) + cm·P`, each with ITS pair | 5/5 |
| the two pairs' rows are disjoint | 5/5 |
| each claim's parts carry ONE PCS column key, and the two keys DIFFER | 5/5 |
| words `= 1 + N(d+1) + terms` | 5/5 |
| `rank R = dim C`, every `T′(w,π) − T′(w′,π′)` in `Im R`, variation rank 3 | 5/5 |

**One thing the memo does not say and should.** The two keys differ only
because the flipped coordinate falls inside the claim point's TAIL, and it
does so only when `log2(head_dim) ≤ log_cols` (`part_key_at`,
`protocol.rs:186-192`: the key is the last `min(p.log, log_cols)`
coordinates). Above it, the two claims would carry the SAME key, collapse
into one column-weight group, and `check_opening` would refuse every proof —
the same failure ruling **S-3** was written for at slot 08. S-3 refuses
`head_dim ≥ 2^log_cols` and therefore covers this too, with one unit to
spare; the margins are 6, 7 and 8 bits at rung-G, rung-K4 and 125M
[COMPUTED, `counts_and_cliffs.py`]. The memo attributes S-3's protection to
slot 08 alone (§3.2); it protects slots 15 and 16 as well, for a reason
nobody wrote down.

**Smallest repair.** Reword C1 to "every `Tab::Priv` a slot pushes", and add
one sentence to §3.2 saying S-3 also keeps the RoPE partner's key separate.

### B-3 — C5's enforcement is weaker than the memo's own gap says, and it is a soundness matter

**The memo's text.** Gap S-C3(i): "*'every private slot is hosted exactly
once by a Host that runs after it' is asserted in `layout.rs:1325-1337`,
inside `mod tests`, and against the toy's frozen `SLOTS`/`HOSTS` constants;
nothing shape-driven re-checks it, though `HOSTS` is shape-independent so the
risk is a future edit*".

**My evidence.** It is weaker than that. `layout.rs:1325-1337` checks `HOSTS`
against `SLOT_KINDS` — it never touches `define`. The hosted lists that
actually run are **literals inside each arm** (`vec![(SC_SS, nu[0]),
(SC_SSM, nu[1])]` at `argument.rs:982`, and six more), and nothing anywhere —
test or production, at the toy or at a shape — compares those literals with
`HOSTS`. The only production check is `run_slot`'s
`(kind == SlotKind::Host) == def.hosted.is_empty()` (`argument.rs:305`): a
Host must host at least one slot and a non-Host none. The count, the
identities and the once-only property are unchecked.

**And it is not a privacy matter.** If a private slot were hosted zero times,
nothing would constrain its honest sum — a soundness hole. Its published
scalar would still be `S + c·G`, a uniform value, and its terminals would
still be pair-masked, so nothing leaks. If it were hosted twice, the change
of coordinates stays triangular and nothing leaks either. So C5's real
content for (H4) is only "the hosted mask totals cancel", which they do by
construction on both sides (`argument.rs:345` subtracts `κ·c_hs·G_hs`, `:379`
adds back `κ·scalars[hs]`) — and that part I confirm.

**Smallest repair.** Move the finding from "a future-edit risk" to "a
soundness gap today", and note that the cheap fix is three lines in
`run_slot`: compare `def.hosted`'s slot list against `HOSTS[host]`.

### B-4 — C7's "production guard" is prover-side, and no verifier panic is reachable from a receipt

**The memo's text.** Gap S-C3(ii): "*the production guard is the runtime
`assert!` at `zk.rs:442`, a **panic**, not a named refusal*". S-C3(iii)
describes two more panics.

**My evidence.** `zk.rs:442` is inside `mask_commit`, which only the prover
calls (`zk.rs:1315`, `:2653`). `Shape::new` has **ten** refusals and none of
them is the mask budget: seven are geometry (a zero axis, a non-power-of-two
axis or width, `d_pad ≠ h_pad·head_dim`, the two head divisions, the row
range) and three are the named rulings F-2 (no P-3 lift of
`Dom::Q`/`Kv`/`S`), S-1 (the table domain at exactly the row width) and S-3
(the head dimension) [COUNTED, `shape.rs` lines 100-326]. So
an over-budget shape kills the PROVER at construction time; a verifier
running the same shape would fail inside the `M` opening, and in neither case
can a frame reach it.

I then asked the question the brief asks — **is any verifier-side panic
reachable from a malformed receipt?** I read the whole verify path at
`8c5922b`. **No.** [VERIFIED IN THE CODE.]

* `wire::decode` checks the exact frame length and every field word's
  canonicality, reads each slot's rounds and terminals at the schedule's own
  widths through a bounds-checked reader, and refuses trailing bytes
  (`wire.rs:115-120`, `:225-243`).
* `sumcheck::verify` refuses a wrong round count and a wrong round width
  before touching them (`sumcheck.rs:141-152`).
* the `Tab::Pub` length refusal now sits BEFORE the Prove/Verify split
  (`argument.rs:317`), which is finding F-6's fix; `eval_mle_ext`'s own
  `assert_eq!` is unreachable behind it.
* `sp.terms.len() != n_priv` is refused (`argument.rs:375`); `es[p.ext_round]`
  is guarded by the `ext_round >= ext` refusal (`:308`).
* `pcs::verify_zk` and `zk::mask_verify` return `Err` on every length,
  column-count, column-index and Merkle-depth mismatch.
* S-C3(iii)'s `B::tab` → `usize::MAX` → out-of-bounds panic is at **define**
  time, from the shape, on both sides. No receipt selects it.

This matters for how the gap reads. "Panic" invites the reader to think
denial of service. S-C3's three panics are all shape-only: they can be
reached by a developer declaring a new shape, never by an attacker sending a
frame. The memo should say so, because the opposite reading would be a
security finding and this is not one.

### B-5 — §4's joint-law sentence does not hold, as written, for the six host slots

**The memo's text.** §4.2: "*Fix `π` … the published channel is
`T′(w,π) + R(a)`, which by P2 and P3 is uniform on `C_s` for every `π`. …
The joint law of (scalar, rounds, terminals) is therefore
`Unif(C_s) × Unif(Fp2^{terms})`*".

**My evidence.** A Host slot's published scalar is
`c_h·G_h − Σ_{hs} κ·c_hs·G_hs` (`argument.rs:345`). It is not
`T′(w,π) + R_h(a_h)`: it carries **other slots'** mask totals, and `R_h` is a
map out of slot `h`'s own `L_h` coefficients only. Its marginal law is still
uniform (because `G_h` is uniform and `c_h ≠ 0`), so no conclusion of the
memo is wrong — but the sentence as written is not true of six of the 23
slots, and the step that repairs it is Lemma 2.2's triangular change of
coordinates, which the memo explicitly defers to the toy (§4.4) and never
re-states at a shape.

Two shaped details that the re-statement will need, neither of which the memo
records: the host's scalar contains **no honest sum of its own** (a host is a
zero-check; its own total is zero and the hosted values arrive through
`claimed` at `:379`), and one hosted coefficient is shape-dependent —
`SC_SZC` hosts `SC_RS` with `κ = ν₀·per_row`, `per_row = size(Dom::S) /
size(Dom::Ht)` (`argument.rs:1433-1434`). Privacy does not need `κ ≠ 0` (the
change of coordinates is triangular in `G_h` whatever `κ` is); soundness
does, and `per_row` is a power of two, never `0 mod p`.

**Smallest repair.** One paragraph in §4.2 saying the per-slot statement is
for Private and Standalone slots, and that Host slots need Lemma 2.2's change
of coordinates, which is inherited and which `κ` cannot break.

### B-6 — three confirmations, stated with the force the memo does not give them

These are places I attacked and could not break. They belong here because the
memo hedges them and they deserve less hedging.

1. **The `ζ` recount is right, and R-7 is wrong at both rungs.** A proof
   draws **8** `ζ` and **8** `mu_pad` at rung-G AND rung-K4, and **5** at
   125M [COUNTED, `counts_and_cliffs.py`, from `pad.rs:pad_zero_host` and the
   padded-domain sets]. I re-derived the memo's reason and it is exact: there
   are seven `ζ` source lines (`argument.rs:961`, `:1028`, `:1224`, `:1299`,
   `:1352`, `:1410`, `:1485`), but `:1352` is in the shared `SC_QZC |
   SC_KVZC` arm, which `define` runs twice. Ruling **R-7's "≤ 7" is
   violated** at both rungs; the earlier draft the correction overwrote was
   right. **The security owner has a recorded ruling to amend.**
2. **`mu` and `mu_pad` are not refused on zero, and that is not a privacy
   matter.** Confirmed at `8c5922b`: `nonzero(…)` wraps `nu` and `ζ` and
   nothing else. The reason it cannot be a privacy matter is sharper than the
   memo's: `mu` enters only the SLOT POLYNOMIAL, and the published terminals,
   the claim points and the reserved-pair coefficients do not depend on the
   polynomial at all — only the honest sum and the round messages do, and
   both are masked by the same `c·g`. A zero `mu` changes what is PROVED, not
   what is DISCLOSED. Soundness, `2^-128` per slot.
3. **The rank identity has no unrefused bad set that I could find.** The code
   refuses the EXTENSION challenges at 0 and at 1 (`argument.rs:404-406`) and
   refuses the main-round challenges at nothing. I therefore recomputed
   `rank R_s` at 12 or 14 challenge vectors per slot per shape, including a
   main `ρ_j = 0`, a main `ρ_j = 1` (three positions each), two equal
   coordinates, all coordinates equal, all coordinates zero, and — for the
   two bilinear slots — `e₀ = e₁`. **1,120 checks, 0 not tight**
   [COMPUTED, `rank_dof.py`]. **Slot 09 at the 125M parameters `(N, d) =
   (13, 3)`: `L = 41`, `dim C = 40`, `rank R = 40`, `dim ker R = 1` at every
   one of those vectors, degenerate ones included.** The controls have teeth:
   a mask declared one degree low reaches rank 27 of 40, and a wrong sum
   weight breaks the chain at round 0.

### B-7 — two shape cliffs I decided rather than argued, both closed

* **`argument.rs:1449-1451`** refuses slot 17 whenever
  `zero_rule_a_planes(Dom::Ht) != [A_MX, A_SUM]`, and a shape where `Dom::S`
  pads but `Dom::Ht` does not would produce exactly that — an honest shape
  refused with a message that misdescribes the cause. **It is unreachable.**
  Under ruling F-2 (`shape.rs:252-260`, no P-3 lift of `Dom::S`),
  `size(Dom::S) = h_pad·t_pad²` and `size(Dom::Ht) = h_pad·t_pad`, and since
  `t_pad ≥ tokens` and `h_pad ≥ q_heads`, `Dom::Ht` pads **iff** `Dom::S`
  does. A scan over 635 F-2-legal geometries (720 candidates) finds none [COMPUTED,
  `counts_and_cliffs.py`]. Another liveness cliff closed by a ruling written
  for a different reason.
* **The flipped partner's PCS key**, above: closed by S-3, margin 6 to 8
  bits.

### B-8 — one thing I tried to break and could not: the memo's own port

The memo's `closure_miniatures.py` builds its `eq` tensors with a nested
per-node construction where `mle.rs:48-52` reverses the point first. I
suspected a bit-order defect — the same trap I fell into writing my own port
— and tested it: the memo's construction **is** most-significant-first and
matches `mle.rs` value for value [COMPUTED]. To make sure their P1..P6 are
not self-fulfilling on that axis I deliberately broke the convention and
re-ran their script: **all 17 miniatures fail P4** and control C3 flips. So
their port is consistent with the Rust, and P4 is a real port check and not a
tautology. Their `verify_slot` does substitute `eval_mle_ext(the prover's own
eq table, ρ)` for the real verifier's `eq_point(point, ρ[start..])`
(`argument.rs:389`); I checked by hand that the two agree for every `start`
and every point length, so nothing rides on it — but it is the one place
where their miniature is not the real verifier, and it is worth a line in
§4.4's list of what the miniatures do not model.

(The perturbed run rewrote `results/zk60_slot_closures_shaped/closure_miniatures.json`
in place; I restored it by re-running their script unmodified, and `git status`
reports that directory clean at the time of writing.)

---

## 3. What the memo gets right that a reader should not re-litigate

* **The bracket placement, all seven arms.** I re-read every line the memo
  cites at `8c5922b`, including the two where `pz` is added to `zc` before
  the multiplication: `:1014` (02), `:1041` (03), `:1281`+`:1287` (14),
  `:1333`+`:1340` (18), `:1392`+`:1401` (15/16), `:1469`+`:1475` (17),
  `:1525` (19). Every one is `v[eq(tau)] · ( … + pz.eval(v) )`. The citation
  list is accurate and the conclusion is right.
* **Slot 19's second bare monomial** (`− v[multiplicity]`) and its
  resolution under `v[0]`: confirmed at `:1521-1526`.
* **The pair coefficients at `ext = 2`.** `cd = (1−e₀)(1−e₁)`,
  `cm_X = e₀(1−e₁)`, `cm_Y = e₁`, from `argument.rs:409` and `:413`, and
  `:404-406` refuses 0 and 1 for EVERY extension challenge on both sides
  (the refusal is in `run_slot`, which both sides run). Confirmed, and
  computed end to end on the miniature.
* **The receipt arithmetic.** +21 words / +336 B at rung-G and +35 / +560 at
  125M for the S19-F1 repair, and 1,254 / 1,269 / 1,751 slot words: I
  re-derived all of them and they are exact, and the rung-K4 figure is
  confirmed against a real bundle to the word [MEASURED].
* **Slots 21/22 in a run.** `run.rs:498-509`: the boundary `B_k` is prepared
  and its root absorbed at **step 2 of stage `k`, before `prove_core` and so
  before any slot challenge** — the blinding of the pair slot 22 uses is
  fixed and committed before the terminal that uses it is computed. There is
  no ordering problem. Its opening lands in stage `k+1` with the two claims'
  lists complete (`run.rs:525-531`, `:547`). The two sites are disjoint by
  construction (`run.rs:269-281`, `boundary.rs:196-202`) and the external
  endpoints keep their own row at `k = 0` and `k = l−1`. I looked for a
  cross-stage term in `argument.rs:373-399` and in the wire path and found
  none. The memo is right and its hand-off of the gluing to G-R1 is the
  correct call.
* **`audit_claims` is what actually enforces travelling condition 2**
  (`protocol.rs:240-272`): every non-sum claim must touch exactly two
  consecutive, correctly aligned site rows, every site row must be used
  exactly once, and a zero pair coefficient is refused. It is shape-free and
  runs in production on both sides. This is stronger than the memo's per-slot
  reading of C1 and it deserves to be the headline of §1.3, with the reading
  as corroboration.

---

## 4. What I could not check

* **125M is still unevaluated by anything.** Gap S-C2 stands exactly as
  written. Every 125M number here, like every 125M number in the memo, comes
  from the shape model. My `premise_cover.py` and `degree_maxplus.py` are
  ports of the arms, not the arms.
* **The real `def.poly`.** No build, so I could not evaluate the Rust
  closures. My re-ports agree with `BASE_DEGREE` at the toy 23/23 and with the
  memo's public/private structure arm by arm, which is the strongest
  cross-check available without `cargo`. **Gap S-C1's O-1 test remains the
  single highest-value thing anyone can do off either page**, and B-1 says it
  should assert the degree as well as the premise.
* **Slot 17's second pad-zero group against the real `define`** (the memo's
  own attack item 2). I confirmed the group membership and the `ζ` power
  continuation across the two groups by reading `pad.rs:365-381` and
  `argument.rs:1444-1454`, modelled it, and decided the refusal's
  reachability by scan — but I did not evaluate the real `supp_Ht` lift
  against a real cube, and nor did the memo.
* **Everything the memo excludes**: (H1) / G-R1, the `M` opening, the PCS
  openings, the hash layer, the pairless LogUp sum claim, the real prover's
  randomness, and the 23 slots as one system.
* **Whether the `Gate`'s placement is right for SOUNDNESS.** I read it only
  for what it publishes, as the memo does. §3.4's claim that gating is
  "neutral either way" for (H4) is true; whether the LogUp arm must stay
  ungated is a soundness question neither page answers.

---

## 5. The one thing the security owner must rule on

**Ruling R-7 is wrong and a recorded ruling has to be amended.** The pad
rule's challenge cost is **8** `ζ` and **8** `mu_pad` at rung-G and rung-K4,
not "≤ 7"; 5 at 125M is right. Two independent counts now say so (the memo's
and mine), both from `pad.rs:pad_zero_host` and the padded-domain set, and
the mechanism is one shared match arm that `define` runs twice. Nothing about
it moves a proof byte and nothing about it is a privacy or soundness change —
it is a liveness-inventory correction — but it is a **ruling**, and the
register entry says the day a ruling is made it goes in the register. This
one has to be un-made.

Everything else on this page is a memo edit or a future Rust test.
