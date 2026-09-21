# CHECK of `ZK60_GENERIC_RANK_LEMMA_SHAPED.md` — an adversarial re-derivation

> **Verdict on Lemma S as stated: HOLDS WITH CHANGE.** Every numerical
> verdict of the memo reproduced on independent computations at both shaped
> layouts — `k0 = 0` for `A`, `H`, the endpoints and the boundaries; the
> `H` term exactly 2 and exactly the public LogUp identity; the refusal
> figures; the backstop degrees; the endpoint and receipt corrections. Two
> statements must change and three figures are errata.
>
> **Verdict on Fact 1: FALSE AS STATED, TRUE IN THE FORM THE MEMO NEEDS.**
> A claim's evaluation point *does* reach the non-data block — on `H`, at
> the two zero-sum `u` rows, through two claims' data parts. It is harmless
> for a reason the memo does not give (`log(Dom::Tab) == log_cols` after the
> P-3 lift, so the eq-tensor is trivial there), and that reason is a shape
> condition nobody has written down. **§3.1's corollary about the repaired
> bilinear slots is untouched and correct**: those planes live on `A`, where
> `audit_claims` really does keep every claim's parts off every non-data row.
>
> **Verdict on Finding N-2: BROKEN.** The boundary's opening-group COUNT
> check is not a privacy check. The configuration the memo prices cannot
> occur past the audit that runs before it.

**Written by a second delegated Opus agent, independently of the memo's
author.** 2026-09-20, 22:56–23:30 PDT (`date`). Read-only against
`/home/victor/wt-zk60-block125m`; `git --no-pager diff --stat e6b612f` shows
only `shape.rs` has moved since the memo's pin (the 60 lines that add
`Shape::rung_k4`), so every other file I read is the memo's own tree.
Evidence: `results/zk60_generic_rank_lemma_shaped_check/` (five scripts,
exact Goldilocks arithmetic, generic elements at several seeds; nothing
built, no prover run, no capture read).

**This is not a privacy acceptance either.** It is one adversarial pass over
one memo. Labels: [COUNTED] (from the code or a model), [COMPUTED] (exact
arithmetic, script named), [ARGUED] (reading only).

---

## 1. Verdict table

| # | The memo's claim | Verdict | Where |
|---|---|---|---|
| S2 | Fact 1: a claim's point reaches only its data rows and its column key, never the non-data block | **FALSE AS STATED** (B-2); true on `A`, false on `H`'s `u` rows | `argument.rs:1529-1538`, `protocol.rs:167-178`, `pcs.rs:882-890` |
| S3 | pair weights `(cm, cm·U)` at every shape, incl. sub-row planes | **CONFIRMED** | `argument.rs:264-278`, `pcs.rs:860-900`, `layout.rs:1037-1042` |
| S4 | the repaired slots' shared coordinates leave the non-data block unchanged | **CONFIRMED** | `keys_bilinear.txt`; `argument.rs:1126-1187` |
| S5 | pre-repair and repaired give the same linear view | **CONFIRMED** (follows from S4 on `A`) | `keys_bilinear.txt` |
| — | the tail positions that must coincide by accident: 6/10, 10/10, 8/14, 14/14 | **REPRODUCED EXACTLY**, and extended to rung-K4 (7/10, 10/10) | `keys_bilinear.txt` |
| — | "no structural column-key collision for slots 08/09" | **CONFIRMED at all four shapes**, but the condition that would cause one is unnamed and unrefused (B-3) | `shape.rs:240-262` |
| S6 | the pad-zero term raises no claim and allocates no pair | **CONFIRMED** (`b.tab` returns an index into the slot's own table list; `a_sites` 122 and `a_groups` 36 unchanged) | `argument.rs:519-539, 588-600` |
| S9 | Fact 2, a known-zero region can only lower the disclosed dimension | **CONFIRMED** (trivially: `F ∩ T' ⊆ F ∩ T`) | — |
| S10 | the LogUp sum claim is constructible and alone in its group at both shaped layouts | **CONFIRMED**: with the lift every `H` domain log ≥ `log_cols`, so every evaluation key has a non-empty tail and the sum key `([], 0, n)` is alone | `layout.rs:136-142`, `shape.rs:852-861` |
| S11 | the sum claim's pair coefficients are `(1, U)` | **CONFIRMED** | `protocol.rs:167-178` |
| S13 | the `u`-row term is exactly the public LogUp identity | **COMPUTED HERE, span equality and all** (the memo only computed the dimension; it deferred the identity to GS-1) | `brute_view.txt` §2 |
| S14 | the endpoint's spare row absorbs a degenerate proximity draw | **REPRODUCED** (k0 0 / 0 / **1** with the spare removed / 2 / 0) | `nondata_rank.txt` |
| S15 | Finding N-1: the boundary's proximity refusal is exactly necessary | **REPRODUCED**, 6 seeds, k0 rises 0 → 1 | `nondata_rank.txt` |
| S16 | Finding N-2: the boundary's group-COUNT check is a privacy check | **BROKEN** (B-1) | `protocol.rs:259-272, 297-303` |
| S17 | Finding N-4 + "at least 15 of 36 `A` groups are singletons" | **CONFIRMED and tightened**: the real distribution is derivable, largest group **35** (not 36), singletons **17** (not ≥15) | `nondata_rank.txt`, `shape.rs:642-677, 823-840` |
| S21 | the individual claim values add nothing (Step 7) | **COMPUTED at m = 5 and m = 3**, disclosed 0, control fires at 16 (the memo reached m = 2) | `brute_view.txt` §1 |
| S22 | the refusal figures per block and per run | **REPRODUCED to 2 d.p.**, every term | `refusal_recount.txt` §C |
| S23 | Finding N-3: `≤ 2^-118.42` per block, `2^-114.83` per run | **CONFIRMED**, and its conditioning can be STRENGTHENED from "honest witness" to "any witness the constructors admit" (B-6) | `refusal_recount.txt` §B |
| — | §5.3's raw counts (table rows 3,072 / 49,152) | **WRONG**: the code inverts `Dom::Tab.len()` = 256 per table, so 768 at every shape (B-5). Bit figures unmoved | `argument.rs:854-883`, `layout.rs:163-165` |
| S24 | the backstop degrees and unions | **REPRODUCED**, and shown MOOT: the minor is exactly a product of norm forms (B-10) | `refusal_recount.txt` §D, `nondata_rank.txt` |
| S25 | 125M endpoint rows 37, prox pair (34, 35), receipt 40,783,352 B | **CONFIRMED**; the receipt figure is MEASURED in `ZK60_BLOCK125M_S19F1_DISPOSITION.md` §6, and the model's 29 is stale at `scripts/zk60_private_block_layout_model.py:603` | `shape.rs:416`, `protocol.rs:316-348` |
| — | "9 and 6 at rung-G" | **CONFIRMED** (`endpoint_rows = 9`, geometry `(9, 4, 6)`) | `shape.rs:332`, `protocol.rs:335-348` |
| — | "one data part per endpoint claim, not three" | **CONFIRMED**; the toy documents really do say three | `protocol.rs:355-367` |
| — | ζ draws 8 at rung-G, 5 at 125M | **CONFIRMED** by an independent recount of which domains pad (nine at rung-G; six at 125M — `Dom::T`, `Dom::Kv` and `Dom::F` do not pad there) | `shape.rs:546-573` |
| — | boundary geometry `data + 2·sites + 2`, zero slack | **CONFIRMED** (rung-G 10/4, sites [4,5,6,7], prox 8; 125M 38/32, sites [32..35], prox 36) | `boundary.rs:174-202, 345-371` |
| — | both boundary refusals enforced on BOTH sides | **CONFIRMED**: prover `boundary.rs:269-275`, verifier `run.rs:670`, both through `protocol::check_opening` | — |
| — | GS-7 is an ordering gap in the ARGUMENT, not the protocol | **CONFIRMED** (B-11) | `run.rs:486-510, 528-537` |
| — | §1.2's rung-G table matches the run gate entry for entry | **CONFIRMED**, but two figures are cited to the wrong place (B-8) | — |

---

## 2. Findings, most serious first

### B-1 — Finding N-2 is broken: the boundary's opening-group COUNT check is not a privacy check

**The memo says** (§3.6, Finding N-2): *"`check_opening` refuses when the
first-occurrence grouping has a different number of groups from the
schedule… With three groups instead of two there are 8 generators against 6
non-data rows, the full-rank implication cannot hold, and `k0` rises to 2.
Nowhere is this recorded as a privacy-relevant check… **GS-10** records that
no test pins it as one."*

**The evidence.** Two things.

1. **The arithmetic is right and the scenario is unreachable.** [COMPUTED,
   `nondata_rank.txt`, 6 seeds] 3 groups against 6 non-data rows does give
   `k0 = 2`. But `check_opening` (`protocol.rs:297-307`) runs `audit_claims`
   **first**, on line 298, and `audit_claims` makes three claims impossible
   on a two-site boundary: every non-sum claim must touch **exactly two
   adjacent site rows** (`protocol.rs:259-262`) and **every site row must be
   used exactly once** (`protocol.rs:270-272`). A boundary has `2·sites = 4`
   site rows, so `claims × 2 = 4` and there are exactly two claims. With two
   claims the first-occurrence grouping returns 1 or 2 groups and never 3.
   The 8-generator case the memo prices cannot occur.
2. **The only deviation the count check can catch is harmless.** With two
   claims, `groups.len() != want_groups` means the two column keys collided
   and the groups merged. [COMPUTED, `nondata_rank.txt`, 6 seeds] a merge
   gives 4 generators, 6 non-data rows, rank 4, **`k0 = 0`** — the verifier
   sees strictly less (one group vector instead of two) and the hidden rows
   are no less blinded.

**The memo contradicts itself on this.** §3.1 point 2 says of exactly this
event: *"That is refused by name… and it is a liveness event, not a leak."*
§3.6 then prices the refusal that catches it as a privacy check.

**The smallest repair.** Withdraw Finding N-2 and withdraw GS-10. Keep the
count check — it is a schedule and soundness check and it is cheap — but do
not record it as load-bearing for hiding. Recording a check as
privacy-critical when it is not is not a harmless over-statement: it is the
kind of entry that later licenses relaxing something that *is* critical, on
the grounds that "the count check covers it". What actually carries the
boundary is `audit_claims`' exclusivity plus the proximity refusal, and
Finding N-1 already says so.

### B-2 — Fact 1 is false as stated; it is true under an unnamed shape condition

**The memo says** (§1.4): *"**Fact 1 (shape-free).** A claim's evaluation
point influences the verifier's linear view in exactly two ways… **It never
appears in the commitment's non-data block.**"* And §6.2 ranks Fact 1 first
to attack, correctly: *"everything in §3.1 is a corollary of it."*

**The evidence.** On `H` the point does appear in the non-data block,
because two claims' **data parts lie on rows the memo's own model counts as
non-data**:

* the memo's §1.2 table lists `H`'s non-data as `2 (u) + 2 (prox)` plus the
  reserved pairs — so the two zero-sum `u` rows are non-data by the model's
  own accounting;
* the `u` rows **are** the two rows of the hidden plane `H_U`
  (`protocol.rs:760-768` fills them, `layout::h_u_rows` names them);
* `SC_ZS` raises an ordinary evaluation claim on that plane —
  `b.h(hids.u())` at `argument.rs:1537`, whose `Priv` carries
  `coords: rho(0..log)` (`argument.rs:540-546`) — and the pairless LogUp sum
  claim covers the same two rows (`protocol.rs:167-178`);
* `audit_claims` does **not** forbid this. Its only row-placement checks are
  "no part reaches the proximity pair" (`protocol.rs:241-243`) and the site-row
  exclusivity (`:244-249, :259-272`). The `u` rows are neither.

So Fact 1's universal quantifier is wrong. **Why it is harmless here, and it
is not Fact 1's reason:** `Dom::Tab` is lifted by P-3 to *exactly* the row
width (`layout.rs:136-142`), so for both claims `ls == log_cols`, hence
`lr = ls − log_cols = 0`, `eq_table_msb(&point[..0]) = [1]`
(`pcs.rs:884-889`), and each `u` row's weight is the point-**independent**
coefficient (`cd` and `cd·U`, or `1` and `U` for the sum claim). The point
reaches the non-data block and contributes nothing to it.

**Why this matters.** If a future shape ever put `log(Dom::Tab)` **above**
the row width, the two `u` rows would carry an eq-tensor in the claim's
point, the non-data block would become point-dependent, and §3.1's corollary
— the memo's headline about the repaired bilinear slots — would have to be
re-derived. Nothing refuses that: `domain_log_at` only lifts upward, and
`Dom::Tab`'s natural log is fixed at `clog2(U8_LEN) = 8`, so today it is
safe by construction rather than by check.

**The smallest repair.** Replace Fact 1 with two clauses:

> **Fact 1′.** (i) `audit_claims` (`protocol.rs:241-249, 259-272`) keeps every
> claim's parts off every reserved-pair row but its own and off the proximity
> pair, so on those rows the weights are exactly `(cm, cm·U)` and the point
> does not enter. (ii) On the only other non-data rows a claim's data part
> may occupy — `H`'s two zero-sum rows — the weight is point-independent
> **because** `log(Dom::Tab) == log_cols` makes `lr = 0`. Clause (ii) is a
> shape condition, and it belongs in the P-3 lift's invariant list beside
> ruling G-3's four asserts.

§3.1, §4.A and the whole bilinear verdict stand: `A_QR8`, `A_KR8`, `A_P` and
`A_V8` are on `A`, where clause (i) is the whole story.

### B-3 — a structural column-key collision the memo does not name: `head_dim ≥ row width`

**The memo says** (§3.1 point 2): two shared coordinates *"can make two
column keys collide… **It is *more likely* than for an unrelated pair**…
which is worth counting rather than waving at"*, and counts the accidental
case.

**The evidence** [COMPUTED, `keys_bilinear.txt`]. `A_QR8`'s coordinate list
ends with `rho(lkv..lkv+ldh)` and `A_KR8`'s ends with the **same symbols**
(`argument.rs:1141-1158`). If `ldh ≥ log_cols`, both tails are the last
`log_cols` entries of that one shared segment, so the two keys are **equal by
construction on every run**: `opening_groups_at` returns `a_groups − 1` and
`check_opening` refuses **every** run at that shape. The condition is
`head_dim ≥ 2^log_cols`. Not reachable anywhere in scope (head_dim 8 / 16 /
8 / 64 against row widths 256 / 1024 / 1024 / 16384 at toy / rung-G /
rung-K4 / 125M), and it is a liveness cliff rather than a leak — but nothing
refuses it. `shape.rs:240-262`'s guard covers only the opposite direction
(a bilinear domain **below** the row width, lifted by P-3). `SC_PV` can
never collide structurally: `A_V8`'s tail always ends in the fixed `r_i` and
`A_P`'s in `ρ_s`.

**Repair.** One refusal in `Shape::new` beside the existing P-3 guard, and
one line in the memo saying the collision is accidental *at these shapes*
rather than *by construction*.

### B-4 — §3.1's inventory of structurally shared coordinates is incomplete

**The memo** counts only the repaired slots' pairs. `SC_GMM` and `SC_UMM`
raise two claims on the **same plane `A_YM`** whose coordinate lists share
the **fixed** row point `r_tf` (`argument.rs:1194-1208`: `r_tf` is drawn once,
in `SC_GMM`, and reused). [COMPUTED, `keys_bilinear.txt`] their tails agree
by construction at 3 of 10 positions at rung-G, 4 of 14 at 125M — collision
`2^-896` / `2^-1280`. Immaterial, and §5.1's union over `C(claims, 2)` pairs
at `p^-2` already dominates it, so **no figure moves**. Recorded because the
memo's §3.1 reads as an exhaustive inventory of "claims that share
coordinates by construction" and is not one.

### B-5 — §5.3's table-helper raw counts are wrong by a factor of the row width

**The memo's table** prices "table rows" at 768 / 3,072 / 49,152 for
toy / rung-G / 125M, i.e. `3 × row width`.

**The code** inverts `table_values_u8(g_u8)` etc. (`protocol.rs:730-734`),
which is `table_values_*_at(Dom::Tab.len(), …)` (`argument.rs:854-883`), and
`Dom::Tab.len()` (`layout.rs:163-165`) is `1 << domain_log_at(8, true,
LOG_N)` with `LOG_N` the **toy's 8** — i.e. **256, at every shape**. So the
term is `3 × 256 = 768` everywhere. [COUNTED, `refusal_recount.txt` §A] raw
totals become 64,768 / 436,992 / 103,842,560, and the bit figures do not
move (`2^-112.02` / `2^-109.26` / `2^-101.37`). An erratum, not a finding —
but it also removes the need for the memo's lift argument on the table
families: they never grow in the first place.

### B-6 — N-3's conditioning is weaker than it needs to be, and GS-12 can mostly be closed

**The memo says** (§5.3): *"The conditioning is the right one: this is the
prover's own refusal, run on the witness it is proving, and an **honest
witness's** lookup arguments are table rows by definition… **GS-12** records
that I did not re-derive the byte-range obligation on every one of the `u8`
lookup expressions."*

**The evidence** [COUNTED, `refusal_recount.txt` §B]. The byte ranges are
**refusals in the constructor**, not a property of honesty:

* `byte(p)` is `value = p`, `scaled(p, k)` is `k·p`, `sym(p)` is the pair
  `p + 127` and `127 − p` (`layout.rs:561-571`) — every u8 lookup expression
  in the module is one of these three;
* `Witness::new` refuses out-of-range values at `witness.rs:290, 374, 386,
  394, 534, 555, 600, 640, 672, 708`, including `if !(0..256).contains(&delta)`
  for the exp difference at `:533` and `:639`;
* at a **padded** position every non-exempt plane is proved zero (ruling
  P-1), so the argument is the constant `cst ∈ {0, 127}` — still a byte.

So the 768 bound holds for **"any witness the constructors admit"**, which is
exactly Lemma S's own hypothesis. GS-12 can be closed for the u8 and exp
families and narrowed to "the activation family's `act_indices` at padded
positions".

**The caveat that replaces it.** Those same range refusals are ruling R-1's
input-determined refusal sites. The LogUp-denominator term is correctly
priced *given admission*; the admission event itself is a function of the
hidden input and is governed by operating rule M-9, not by this term. The
memo should say that in §5.3 rather than leaving it to §8 item 4.

**Recount, for the record.** `α` is drawn at `protocol.rs:684`, after `β`
(`:682`) and `γ` (`:683`) and after the `A` and `M` roots, so conditioned on
the transcript the whole argument set is fixed and `α` is uniform on `Fp2`.
Three families of at most 256 arguments each; the three table-helper
families are subsets of them by construction. `|S| ≤ 768` per block →
`2^-118.42`; twelve independent `α`s → `2^-114.83`. **Both figures confirmed
to the digit.**

### B-7 — GS-15 can be closed, and N-4's "at least 15" is loose

**The memo says** (GS-15): the `A` and `H` cases *"use a **reconstruction**
of the group-size distribution… its largest group has 36 members, which is
an artefact of that reconstruction"*, and the rigorous singleton bound is
"at least 15 of the 36".

**The evidence** [COUNTED, `nondata_rank.py` header]. The distribution is
derivable exactly from `claim_sites` (`shape.rs:642-677`) and the declared
`a_group_detail` (the layout model's, which reproduces `a_groups`
= `tzc + 15 + 4 + 8`, `shape.rs:823-840`):

`[6, 2×8 | 1, 1 | 2 | 2 | 1×3 | 1,1 | 1,1 | 1 | 1×3 | 35, 2 | 7, 1 | 6, 1 |
13, 2 | 11 | 3 | 1, 1]` — 36 groups, 122 claims, **largest 35**, **17
singletons**. The extra two over the memo's 15 are `SC_QZC`'s and
`SC_KVZC`'s off-cube claims, each alone in its group.

[COMPUTED, `nondata_rank.txt`, 6 seeds, at the real distribution] `A` honest
`k0 = 0`; degenerate proximity `k0 = 0`; `cm = 0` in a singleton `k0 = 2`;
`cm = 0` in the 35-member or the 6-member group `k0 = 0` — the memo's §4.B
table, reproduced without its reconstruction.

### B-8 — two MEASURED figures in §1.2/§4.D are quoted from the wrong place

`rank_P1` "74 of 623" is in the run gate's **§8.5** (lines 1084, 1097), not
§2.3/§2.4 as cited. "243–251 distinct opened columns" is specifically
`run-b-zero`'s spread (§2.3 line 173); the tabulated `run-a-tame` spread is
246–250, and §8.5's per-bundle stage-0 `A` figures include **242 and 252**,
outside the quoted range. Everything else in the §1.2 cross-check matches
the gate entry for entry. Cosmetic, but these are measurements.

### B-9 — the memo never says WHY `H` discloses 2, and the reason is shape-dependent

**The memo** REDUCES the `u`-row term to the toy's §3.3 and MEASURES the span
equality at rung-G only (S13, GS-1).

**The mechanism** [COMPUTED, `brute_view.txt` §2, 3 seeds]. `protocol.rs:760-768`
fills each `u` row with `n − 1` random words and sets the last to their
negation, so the **all-ones functional on a `u` row is publicly zero**. The
LogUp sum claim's column weights are exactly all-ones on `[0, n)` (its key is
`([], 0, n)`, `pcs.rs:872, 905-908`). So the `u` rows give the sum claim **no
blinding at all**, which is precisely why its public value 0 becomes a
constraint on the hidden data. My brute force, run *without* the zero-sum
constraint, returns disclosed **0**; run *with* it, disclosed **2** and the
disclosed span **equal** to the public identity's span on all three seeds.

That is the first computation of the *identity* (not just the dimension) at
a layout where it was not measured, and it is the shaped version of what
GS-1 asks for at 125M. It also says the disclosure is a property of the
zero-sum construction — one line of the prover — and not a corollary of
anything.

### B-10 — the backstop discussion is moot, and its prominence is a hazard

**The memo says** (§5.4): the run backstop `2^-52.24` *"is now the largest
number anywhere on this page and sits below the run's own soundness level,
so **the backstop is not a usable fallback for a run**"*.

[COMPUTED, `nondata_rank.txt`, 6 seeds] the boundary's **whole** 6×6 non-data
determinant equals `Norm(λ₁cm₁)·Norm(λ₂cm₂)·wedge(ρ_prox[prox], ρ_prox[prox+1])`
exactly, on every seed. A product of norm forms vanishes iff a factor does,
and each factor vanishing is a **named refusal** (`protocol.rs:246` for
`cm = 0`, `:284-286` for `λ = 0`, `:289-290` for the proximity pair). So
"bad set ⊆ refusal set" is an **identity**, not a Schwartz–Zippel estimate,
conditional only on `audit_claims` giving each group a member with a pair of
its own. The same block-triangular argument goes through on `H` with the
pairless sum claim (its diagonal factor is `Norm(λ_sum · 1)`) even though
`SC_ZS`'s group also touches the `u` rows — ordering the `u` columns after
that group's own pair makes the extra entries upper-triangular.

**Repair.** Say in §5.4 that the backstop is never reached and that
`2^-52.24` is a bound on a quantity the lemma does not use, so that no later
reader quotes it as a security figure of the run. That answers the brief's
question 6: what the lemma rests on if the backstop is unusable is the
factorisation, and the inclusion IS proved — given the audit.

### B-11 — GS-7 is correctly sized (a gap in the argument, not the protocol)

Checked, because the brief asked. Block `k`'s `SC_IO_OUT` terminal is
published in stage `k` and the boundary is opened once in stage `k+1`
(`run.rs:486-510` commits the boundary root **before** either adjacent
equality slot's challenges; `:528-537` opens with `pending` + `ic`). The
published value is `cm`-masked by a mask row drawn from a fresh OS stream
before the value exists, so the value alone is uniform; the `λ`s and
`ρ_prox` are drawn strictly after it and, in the ROM, independently of it.
There is no prover-side ordering defect. What is owed is the **simulator's**
ordering in the Fiat–Shamir lift — gap G-R5 — and the memo places it there.
Both refusals are enforced on both sides: prover `boundary.rs:269-275`,
verifier `run.rs:670`, both through `protocol::check_opening`.

### B-12 — the layout model is stale in a second place, not one

The memo reports `model_m125.json["shape"]["endpoint_rows"] = 29` against the
Rust's 37. `scripts/zk60_private_block_layout_model.py:582` also declares
`endpoint_rows=14` for the **frozen-seam rung**, where `Shape::rung`
(`shape.rs:295`) declares **21**. Same class of staleness, same file, not
mentioned. It does not touch any figure in the memo (rung-G's 9 and the toy's
7 are right), but a model that is wrong about two of four endpoints should
not be the source of a receipt figure without saying so.

---

## 3. What I reproduced, and what I could not check

**Reproduced independently** (my own field library, my own models, generic
elements, several seeds): the 6/10, 10/10, 8/14, 14/14 tail counts; `k0 = 0`
for `A`, `H`, endpoint and boundary at both shaped layouts; every row of the
memo's §3.5 endpoint table and §3.6 boundary table; the §4.B `A` table; the
determinant factorisation; `H` disclosing exactly 2 **and** exactly the
public identity; disclosed 0 at group sizes 5 and 3 with the control firing
at 16; every refusal figure in §5.1 to two decimal places; N-3's 768,
`2^-118.42` and `2^-114.83`; the backstop degrees and both unions; the
endpoint geometries 37/34 and 9/6; the boundary geometries; ζ draws 8 and 5
by an independent recount of which domains pad; `a_groups` 35 → 36; the
receipt correction `40,750,584 + 2·256·8·8 = 40,783,352`.

**A definitional trap worth recording.** `k0` is
`rank(generators) − rank(generators | non-data)`, **not**
`#generators − rank(| non-data)`. The two differ exactly on the refused
zero-`λ` draws (a wholly zero generator discloses nothing). My first pass
used the wrong one and made the memo's endpoint and boundary `cm = 0` rows
look wrong; they are right. Anyone re-running these models should use the
memo's definition.

**What I could not check.**

1. **Anything on real 125M bytes.** GS-1 stands entirely; nothing here
   touches it.
2. **`lkv = 2` on real receipt bytes.** GS-3 stands. `Shape::rung_k4` now
   exists (`shape.rs:379-399`, committed at `3247a89`, after the memo), so
   the cheapest way to close it exists as of tonight; my key computation
   covers rung-K4 symbolically (7/10 and 10/10, no structural collision) but
   that is a model, not a capture.
3. **The exact column keys of all 122 `A` claims.** I checked the four
   bilinear claims, the three feed-forward matmuls and the cross-slot spot
   checks. The `SC_TZC` sub-row offsets I took from the code's own
   `a_groups` derivation rather than recomputing the plane cursor.
4. **`M`** — I did not re-derive `M-q` / `M-prox` (`zk.rs:452-457`) either.
   The memo's GS-11 is unchanged and unexamined here.
5. **The CFS channel and the pad block (§4.C).** I did not re-run the memo's
   `channels_shaped.py`; I read it and its method (exact Vandermonde
   determinants, no elimination) is sound, but its results are unchecked
   here.
6. **The non-linear channel, the hash layer, the joint law across
   commitments** — GS-13, GS-6, S29–S31, all out of scope as the memo says.
7. **Whether `a_groups`'s declared 36 is what the Rust forms at 125M.** The
   run gate observed 36 at rung-G; at 125M it is enforced and unobserved
   (GS-4), and I did not run anything.

---

## 4. The one thing the security owner must rule on

**Fact 1's repair, and whether `log(Dom::Tab) == log_cols` joins ruling G-3's
invariant list.** Everything the memo says about the repaired bilinear slots
is correct, but it is correct for a narrower reason than the memo gives, and
the narrower reason is a shape condition that no code path checks. Ruling
G-3 already names four assertions in `zkp-core/src/pcs.rs` as invariants that
must not be weakened; the P-3 lift's "`Dom::Tab` sits at exactly the row
width" belongs beside them, because if it ever moves, the `H` commitment's
non-data block becomes point-dependent and §3.1 stops being a theorem.
Second, and smaller: Finding N-2 and GS-10 should be struck before anyone
builds a test for a property that is not true.
