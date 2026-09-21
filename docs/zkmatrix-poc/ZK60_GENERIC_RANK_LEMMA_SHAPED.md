# The generic-rank lemma at a SHAPED layout and at a RUN (gap G-R1)

> **REVISED after an independent check and the security owner's disposition,
> 2026-09-20 23:37 PDT: not a privacy claim; the lemma HOLDS WITH CHANGES;
> Fact 1 restated under the hypothesis `log(Dom::Tab) == log_cols`; finding
> N-2 and gap GS-10 STRUCK.**
>
> The check is `ZK60_GENERIC_RANK_LEMMA_SHAPED_CHECK.md` (a second delegated
> agent, its own field library and four scripts in
> `results/zk60_generic_rank_lemma_shaped_check/`, findings B-1 … B-12); the
> rulings are `ZK60_GENERIC_RANK_LEMMA_SHAPED_DISPOSITION.md` (S-1 … S-5).
> Where the check's suggested repair and a ruling differ, the ruling is what
> this page now says. Every numerical verdict of the draft was reproduced
> independently at both shaped layouts; nothing that survived has been
> softened, and no gap has been deleted — struck gaps keep their number and
> carry a STRUCK paragraph.

**Changes in this revision**

| Ruling (check finding) | What changed | Sections |
|---|---|---|
| **S-1** (B-2) | Fact 1 is **false as stated** and is replaced by **Fact 1′** in two clauses; clause (ii) rests on the shape hypothesis `log(Dom::Tab) == log_cols`, which is added to the lemma's hypotheses, joins ruling G-3's invariant list, and is owed a named, tested `Shape::new` refusal | header, §0, §1.4, §2.1, §2.2 T2, §3.1, §6.1 S2, §6.2 |
| **S-2** (B-1) | **Finding N-2 and gap GS-10 are STRUCK** — the group-count check is not a privacy check; what a boundary's hiding rests on is restated on N-1 | §3.6, §6.1 S16, §6.2, §7 GS-10 |
| **S-3** (B-3) | a latent **structural** key collision (`head_dim ≥ row width`) named as a liveness trap outside every shape in scope; a named `Shape::new` refusal owed | §3.1 |
| **S-4** (B-5, B-6) | table-helper raw counts corrected to **768 at every shape** (bit figures unmoved); the refinement **CONFIRMED** by independent recount; N-3 conditioned on **any witness the constructors admit**; GS-12 narrowed | §0, §5.3, §6.1 S23, §7 GS-12 |
| **S-5** (B-4, B-7, B-8, B-9, B-10, B-11, B-12) | `SC_GMM`/`SC_UMM` and rung-K4 added to the shared-coordinate inventory; **GS-15 CLOSED** (largest group 35, 17 singletons); two measured figures re-cited; the *why* of `H`'s 2, computed; the boundary's determinant identity; GS-7 confirmed as sized; the layout model's second stale endpoint | §1.5, §3.1, §3.5, §3.6, §4.B, §4.D, §5.4, §6.1, §7 |
| — | the `k0` definitional note, and one citation erratum found by the check (`inverses` call sites) | §4.B, §5.3 |
| — | a new closing section, **§9 "What the check changed"**, one line per B-1 … B-12 | §9 |

**Drafted by a delegated Opus agent for the security owner.**
2026-09-20, 22:08–23:10 PDT (`date`). Code read, read-only, at the lane
worktree `/home/victor/wt-zk60-block125m`, commit **`e6b612f`**. Evidence:
`results/zk60_generic_rank_lemma_shaped/` (five scripts, exact integer
arithmetic over Goldilocks, nothing built, no prover run, no capture read).

**Revised by a third delegated Opus agent (errata editor)** on the security
owner's disposition, 2026-09-20 23:37–23:55 PDT. It edited this file only —
no code, no build, no git write — and re-read at `e6b612f` every code
citation it touched. Where it could not verify something it says so in
place.

**This is not a privacy acceptance and nothing here establishes a privacy
property.** It is one step of one argument, at two layouts, on the linear
channels only. Register entry D22 (the toy block) is untouched; no run, no
development rung and no 125M block may be called private on the strength of
this page.

Every claim below is labelled: **PROVED HERE**, **REDUCED to** (document,
section), **COUNTED**, **COMPUTED** (script, instances), **ARGUED**, or
**GAP**. The gaps are numbered `GS-1 … GS-15` and listed together in §7, and four
new findings `N-1 … N-4` are marked where they occur (and are NOT the same
namespace as the label table's rows `S1 … S31` in §6.1). **After this
revision, N-1, N-3 and N-4 stand (N-3 with a stronger conditioning and N-4
with a corrected count); N-2 is STRUCK. GS-10 is STRUCK, GS-15 CLOSED,
GS-12 and GS-3 NARROWED; the numbering does not move.**

---

## 0. Plain words

The project has a rule it keeps having to re-earn. For each of the sealed
boxes the prover publishes numbers out of ("commitments"), the verifier sees
a handful of *combinations* of the box's contents rather than the contents.
The rule is that those combinations are so thoroughly scrambled by the random
rows the prover puts inside the box that they pin down **nothing** about the
hidden rows — and that this is true not just at the random numbers we
happened to measure, but at every run the prover doesn't throw away.

That rule was proved for the smallest box (the "toy"). Since then the boxes
grew: bigger shapes, a new kind of endpoint box, a new kind of box between
two blocks of a twelve-block run, grouped attention heads, a padding rule,
and — today — a repair to two of the twenty-three arguments inside a block.
The security owner's ruling G-2 says the rule has to be earned again, from
the start, at each new layout. The run's composition theorem was accepted
today only *conditionally* on that, and called it "the biggest one"
(gap G-R1). This memo is that re-earning, taken as far as it honestly goes.

Three things came out of it that were not known before.

1. **Today's repair to the two bilinear attention slots is invisible to this
   argument.** The repair made two claims share some of their evaluation
   coordinates, which sounds alarming. It is not, and the reason is
   structural: on the activation box, a claim's evaluation point reaches only
   the *data* rows and the *column* key; it never reaches the random rows
   whose rank is the whole question. (The draft said that of *every* box. The
   independent check found one exception — on the LogUp-helper box two claims
   do land on rows this page counts as random — and it is harmless only
   because one lookup table happens to be exactly as wide as a row. That
   condition is now written down as a hypothesis, §1.4. The verdict about the
   repair is unaffected: its four claims are all on the activation box.)
   Computed on a faithful miniature with two group bits, at ten
   seeds and nine challenge regimes: the answer is the same before and
   after the repair (§3.1, §4.A). What the repair *does* do is put each of
   its four claims alone in its own opening group, which makes the
   zero-mask-challenge refusal exactly necessary for each of them (§4.B).
2. **How necessary a refusal is depends on how much room a commitment has.**
   On the big commitments there are hundreds of spare random rows, and a
   degenerate proximity draw does not move anything. On the **boundary**
   commitment of a run there are exactly none: six random directions against
   six random rows. There the proximity refusal is *exactly necessary* —
   turn it off and the verifier learns a row's worth of hidden data (§4.B).
   The endpoint's fifth, otherwise unexplained "spare" row is what buys it
   the same tolerance.
3. **One number the project is carrying can be made 17 bits better.** The
   one refusal that depends on the hidden input — a zero denominator in the
   lookup argument — was priced by counting *positions* (about 104 million
   per 125M block). It should be priced by counting *distinct values*, and
   **any witness the constructors admit** produces at most 768 of them per
   block whatever the shape — the byte ranges are refusals of the witness
   builder, not a property of honesty, which is the independent check's
   strengthening of the conditioning. That moves a twelve-block run from
   `2^-97.8` to `2^-114.8` (§5.3). Both figures were recounted independently
   and agree to the digit.

And one number changes against the project's own records: the 125M receipt.
The layout model still prices a 29-row endpoint where the code declares 37;
corrected, the model's figure becomes **40,783,352 bytes**, which is exactly
the figure measured this evening (§1.5). That is a coincidence only in the
sense that two independent counts agreeing is a coincidence.

---

## 1. The object, per commitment, at both shapes

### 1.1 Which commitments exist

A shaped **block** opens five: `A` (activations), `H` (LogUp helpers), `M`
(the masking commitment), and two **generalised endpoints**
(`endpoint_g.rs`, which replaces the frozen `private_seam.rs` at every shape
the seam cannot carry). A **run** of `L` blocks under one transcript opens
`4L + 1` commitments: `L` × (`A`, `H`, `M`), `L − 1` **internal boundaries**
(`boundary.rs`) and the two external endpoints; `3L + 1` of them are PCS
openings that carry a proximity refusal (`run.rs:495, 521, 661`;
`protocol.rs:795, 799, 992`). [COUNTED, `shaped_counts.txt`.]

Two development shapes are in scope, both as the Rust declares them
(`shape.rs:265, 319, 355`):

* **rung-G** — `Shape::rung_g`, 24 tokens, width 96, hidden 192, 6 query
  heads of 16 over 2 key-value heads, row width `2^10`, rate `1/4`,
  `Q = 256`, generalised endpoint. `lkv = log2(kv_heads) = 1`.
* **125M** — `Shape::m125`, 512 tokens, width 768, hidden 2048, 12 query
  heads of 64 over 4 key-value heads, row width `2^14`, rate `1/4`,
  `Q = 256`. `lkv = 2`.

### 1.2 The table

[COUNTED — `results/zk60_generic_rank_lemma_shaped/shaped_counts.txt`,
assembled from the lane's own shape-driven layout model
(`scripts/zk60_private_block_layout_model.py`, run read-only) plus the
geometry rules transcribed from `layout.rs:1051-1063`,
`protocol.rs:335-348`, `endpoint_g.rs:52`, `boundary.rs:178-197`.]

**rung-G**

| commitment | rows | data | reserved pairs | other non-data | non-data | claims | groups `G` | generators `2(G+1)` | slack |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `A` | 623 | 377 | 122 | 2 (prox) | 246 | 122 | 36 | **74** | 172 |
| `H` | 576 | 468 | 52 | 2 (u) + 2 (prox) | 108 | 53 | 9 | **20** | 88 |
| endpoint (×2) | 9 | 4 | 1 | 3 (prox pair + spare) | 5 | 1 | 1 | **4** | 1 |
| boundary (×(L−1)) | 10 | 4 | 2 | 2 (prox) | 6 | 2 | 2 | **6** | **0** |
| `M` | 50 | — | — | — | — | 34 functionals | — | — | — |

**125M**

| commitment | rows | data | reserved pairs | other non-data | non-data | claims | groups `G` | generators `2(G+1)` | slack |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `A` | 5,681 | 5,435 | 122 | 2 | 246 | 122 | 36 | **74** | 172 |
| `H` | 7,120 | 7,016 | 50 | 2 + 2 | 104 | 51 | 9 | **20** | 84 |
| endpoint (×2) | 37 | 32 | 1 | 3 | 5 | 1 | 1 | **4** | 1 |
| boundary | 38 | 32 | 2 | 2 | 6 | 2 | 2 | **6** | **0** |
| `M` | 50 | — | — | — | — | 34 | — | — | — |

Conventions, because two documents differ: the layout model's
`h_data_rows` **includes** the two zero-sum `u` rows; the run gate's "data"
column excludes them. The table above excludes them, so 468 = 470 − 2 and
7,016 = 7,018 − 2.

**Cross-check.** The rung-G rows of this table are, entry for entry, the
table the run gate measured on two real three-block captures — `A`
623 / 377 / 36 / 122 / 74, `H` 576 / 468 / 9 / 53 / 20, endpoint 9 / 4 / 1,
boundary 10 / 4 / 2 / 6 (`ZK60_NATIVE_RUN_GATE.md` §2.3, §2.4). Here they
are derived from the layout rules alone, with no capture read. [COMPUTED,
`shaped_counts.py`.]

### 1.3 The kind of claim each commitment receives

| commitment | claim sites, from which slots | point | batched into |
|---|---|---|---|
| `A` | 122, from 22 of the 23 slots (all but `SC_ZS`) (`claim_sites.a` = `[1,1,22,2,2,1,1,1,2,2,1,1,1,1,37,8,7,15,11,3,0,1,1]`) | each slot's own sumcheck challenges `ρ` with some axes fixed | 36 first-occurrence column-weight groups (`shape.rs:763-780`) |
| `H` | 52 (rung-G) / 50 (125M) evaluation claims + **one** LogUp sum claim | evaluation claims at `ρ(0..log)`; the sum claim has an **empty** point | 9 groups; the sum claim is alone in its own |
| endpoint | **1**, from `SC_IO_IN` or `SC_IO_OUT` (`argument.rs:1540-1546`) | `ρ(0..log(Dom::D))` | 1 group |
| boundary | **2**: block `k`'s `SC_IO_OUT` (site 0) and block `k+1`'s `SC_IO_IN` (site 1), raised in **two different stages**, opened **once** in stage `k+1` | two independent slots' `ρ` | 2 groups, and the count is checked |
| `M` | not a PCS claim schedule; 34 mask functionals over 23 slots | — | — |

**The shape of a claim is shape-free.** `build_claim`
(`argument.rs:264-278`) emits, for a private factor on plane `p` at point
`point`: its data part(s) with coefficient `cd`, then **exactly two** mask
parts on rows `(mask_row, mask_row + 1)` of `log_size = min(p.log, log_n)`
with coefficients `cm·1` and `cm·U`, at the point tail. `row_log`
(`argument.rs:244-249`) takes `log_n` from the *commitment*: `log_cols` for
`A`/`H`, `endpoint_log_n` for an endpoint or a boundary. `cd` and `cm` are
built from the slot's extension challenges only (`argument.rs:409, 413`):
`cd = ∏(1 − e_k)`, `cm = e_r · ∏_{k>r}(1 − e_k)`. **PROVED HERE** (reading,
plus the port in `bilinear_miniature.py::build_claim`, which is exercised on
every instance): the reserved pair's weights are `(cm, cm·U)` at every shape
and for every plane, including planes whose domain log is **below** the row
width.

That last case is new at the shaped layouts and deserves its own line. At
rung-G `Dom::T` (log 5) and `Dom::Ht` (log 8) sit below the row width 10; at
125M `Dom::T` (9) and `Dom::Ht` (13) sit below 14. `zpart_weights` then
takes its `ls < log_cols` branch (`pcs.rs:873-878, 891-896`), the mask part
occupies one row at column offset `c0 = offset % n`, and the key is
`(point, c0, 2^ls)`. Because the layout's plane cursor is **row-aligned by
construction** — `a_off.push(row * n)` with `row += sh.rows_of(d)` and
`rows_of = max(1, size >> log_cols)` (`layout.rs:1037-1042`,
`shape.rs:506-508`; `h_off` the same at `:1052-1057`, two rows per plane) —
`c0 = 0` in every case, at every shape. The pair weights are still exactly
`(cm, cm·U)`. **PROVED HERE** by reading, cross-checked against
`model_*.json`'s per-domain row counts (one row per sub-row plane).

### 1.4 Where the evaluation point goes — the decisive fact, restated

`zpart_weights` (`pcs.rs:860-900`) splits a part's point in exactly one
place: with `lr = ls − log_cols`, the **leading** `lr` coordinates become an
equality tensor over the rows of the part's *own slice*, and the **trailing**
`log_cols` coordinates become the *column key*. Nothing about the point
reaches any row outside that slice.

**The draft's Fact 1 was false as stated, and ruling S-1 replaces it.** The
draft asserted that a claim's point never appears in the commitment's
non-data block. On `H` it does: two claims' **data parts lie on rows this
memo's own §1.2 model counts as non-data**. `SC_ZS` raises an ordinary
evaluation claim on the hidden plane `H_U` (`b.h(hids.u())`,
`argument.rs:1537`, whose `Priv` carries `coords: rho(0..log)`,
`argument.rs:540-546`), and the pairless LogUp sum claim covers the same two
rows (`protocol.rs:167-178`); those rows **are** the two zero-sum `u` rows
(`protocol.rs:760-768` fills them, `layout::h_u_rows` at `layout.rs:1203`
names them), which §1.2 counts under "other non-data". And `audit_claims`
does **not** forbid it: its only row-placement checks are "no part reaches
the proximity pair" (`protocol.rs:241-243`) and site-row exclusivity
(`protocol.rs:244-249, 259-272`); the `u` rows are neither. [Verified at
`e6b612f` while editing.]

> **Fact 1′ (two clauses; clause (ii) is a SHAPE condition).**
>
> **(i)** `audit_claims` (`protocol.rs:241-249, 259-272`) keeps every claim's
> parts off every reserved-pair row but its own and off the proximity pair,
> so on those rows the weights are exactly `(cm, cm·U)` and the evaluation
> point does not enter. On `A`, on the endpoints and on the boundaries this
> is the whole story, and the draft's statement holds there verbatim.
>
> **(ii)** On the only other non-data rows a claim's data part may occupy —
> `H`'s two zero-sum `u` rows — the weight is point-**independent**, but for
> a reason Fact 1 did not give: `Dom::Tab` is lifted by ruling P-3 to
> *exactly* the row width (`domain_log_at`, `layout.rs:136-142`, with
> `Dom::Tab`'s natural log fixed at 8, `layout.rs:151`), so for both claims
> `ls == log_cols`, hence `lr = 0`, `eq_table_msb(&point[..0]) = [1]`
> (`pcs.rs:882-890`), and each `u` row's weight is the point-independent
> coefficient (`cd`, `cd·U`, or `1`, `U` for the sum claim). **The point
> reaches the non-data block and contributes nothing to it.**
>
> **PROVED HERE** from `build_claim:264-278` and `zpart_weights:860-900`,
> **given** the four assertions `zkp-core/src/pcs.rs:867, 876, 883, 894` that
> make `part_rows` (`protocol.rs:215-218`) exact (ruling G-3's invariant,
> re-cited here at this tree's line numbers), and **given** clause (ii)'s
> hypothesis.

> **Hypothesis S-1 (new, and now an invariant).**
> **`log(Dom::Tab) == log_cols`.** It holds at every shape in scope
> [COUNTED: row widths `2^8` / `2^10` / `2^10` / `2^14` at toy / rung-G /
> rung-K4 / 125M, and `domain_log_at` lifts a helper domain *up* to the row
> width and never down, so the equality holds exactly when
> `log_cols ≥ 8`]. It holds today **by construction rather than by check**:
> nothing refuses a shape that put `log(Dom::Tab)` above the row width, and
> at such a shape the two `u` rows would carry an eq-tensor in the claim's
> point, the non-data block of `H` would become point-dependent, and §3.1's
> corollary would have to be re-derived. **Ruling S-1: this condition joins
> the invariants that must not be weakened (ruling G-3's list), and is owed a
> named, tested shape refusal on the lane — owed, not yet built.**

Fact 1′ is the whole answer to the brief's question (a), and §3.1 spells that
out.

### 1.5 One number this changes: the 125M endpoint and the receipt

`Shape::m125` declares `endpoint_rows = 37` and `endpoint_g.rs`'s own test
asserts `(len 524_288, data_rows 32, commitment_rows 37, enc_log 16)`; the
rung-G endpoint is `(4_096, 4, 9, 12)`. When this memo was drafted the
pure-Python layout model still carried the superseded **29**
(`model_m125.json["shape"]["endpoint_rows"]`,
`scripts/zk60_private_block_layout_model.py:603`), which is finding
S11b-F3's old figure. Consequences [COUNTED, `shaped_counts.txt`]:

* the model's 125M receipt of **40,750,584 B** becomes **40,783,352 B** —
  `2 × 256 × (37 − 29) × 8 = 32,768` more bytes in the two endpoint
  openings — **which is exactly the figure measured after the S19-F1 repair**
  (`ZK60_BLOCK125M_S19F1_DISPOSITION.md` §6, where the 40,783,352 is the
  MEASURED figure; the check re-cited it there and reproduced the correction
  `40,750,584 + 2·256·8·8 = 40,783,352`). Two independent counts now agree
  on it;
* **the model is stale in a second place, not one** (ruling S-5, the check's
  B-12). `scripts/zk60_private_block_layout_model.py:582` declared
  `endpoint_rows=14` for the **frozen-seam rung**, where `Shape::rung`
  declares **21** (`shape.rs:295` at `e6b612f`, whose own comment says "the
  declared 14 / 4 were the TRUE shape's and matched nothing"); the 125M
  `endpoint_rows=29` sat at `:603`. Neither touches a figure in this memo
  (rung-G's 9 and the toy's 7 are right), but a model that is wrong about
  two of four endpoints should not be the source of a receipt figure without
  saying so. **Ruling: fixed in the model, on the lane** — the lane's working
  copy now derives the endpoint geometry from the shape rather than
  declaring it (`ENDPOINT_MASK_ROWS = 5`, header note "lane stage 23, the
  check's finding B-12"; uncommitted when this revision was written);
* the toy check's §8 item 3 and the toy lemma's §4 item 6(v) say
  "`ENDPOINT_ROWS` 7 → 29 and `ENDPOINT_PROX` 4 → 26 at 125M (9 / 14 at the
  rung)". As built the figures are **37 and 34** at 125M and **9 and 6** at
  rung-G (the frozen-seam rung is 21 and 18, not 9 / 14);
* the same two documents say each endpoint claim "gains **three data parts**
  instead of one". **That is not what was built.** `check_endpoint_opening`
  (`protocol.rs:355-367`) accepts exactly one claim with exactly three
  **parts** — one data part spanning rows `0..data`, then the two mask rows
  — because padding the plane to `t_pad × d_pad` made it a power of two and
  removed the need for the multi-block claim (finding S11b-F3). The
  factorisation therefore has **one** diagonal factor per endpoint, not
  three, and the pair shape survives as a *code fact* rather than the
  "design intention in another document" the toy check had to settle for.

---

## 2. The lemma, restated with explicit hypotheses

### 2.1 Statement

> **Lemma S (generic rank, shaped layouts).** Fix a public statement and one
> of the two shaped profiles — `hashline-zk-mr1/private-block-rung-g-t24-dev/1`
> or `hashline-zk-mr1/private-block-m125/1` — or a run over one of them. Run
> the prover on any witness the constructors admit, with the challenges drawn
> as the protocol draws them. Assume the **shape hypothesis S-1**,
> **`log(Dom::Tab) == log_cols`** — true of both profiles [COUNTED, §1.4] and
> of every shape in scope, but checked by no code path; without it clause
> (ii) of Fact 1′ fails, `H`'s non-data block becomes point-dependent, and
> items 2, 3 and 5 for `H` are not established. Then **on every run that is
> not discarded by one of the prover's own refusals**, for each PCS
> commitment separately:
>
> 1. the three hypotheses of the disclosure tool's reduction hold —
>    **H-pad** (the `d ≤ Q = 256` distinct opened columns have a pad block of
>    rank `d`), **H-pair** (every claim's non-data weights sit on exactly one
>    adjacent reserved pair, used by no other claim, with the pair's two
>    coefficients an `Fp`-basis of `Fp2`, and no claim touches the proximity
>    pair), **H-prox** (`wedge(ρ_prox[prox], ρ_prox[prox+1]) ≠ 0`);
> 2. the non-data block of the `2(G+1)` realified blinding generators has
>    **full row rank `2(G+1)`**, so `k0 = 0`, for `A`, for `H`, for each
>    endpoint and for each internal boundary;
> 3. therefore the disclosed dimension is `0` for `A`, for the endpoints and
>    for the boundaries, and `0 +` the u-row term for `H`; the u-row term is
>    exactly 2 over `Fp` and its span is the span of the public LogUp
>    identity's data-row weights;
> 4. in the mask channel, `uncovered_s = 0` for every slot and every
>    published mask functional lies in the span of that slot's published
>    rounds, so `M`'s independent contribution is the single public
>    θ-combination, 1 `Fp2` = 2 `Fp`;
> 5. the individual claim values add nothing beyond the group combinations
>    and one public identity per group (per connected component, on `H`).
>
> The only probabilistic content is how often the prover discards a run:
> **`2^-62.00` per block and `2^-58.79` for a twelve-block 125M run**, a
> liveness figure, because the refusal predicate is a function of the
> transcript challenges alone. This whole framing is a statement **inside
> the random-oracle model** (the toy lemma's correction C-11, unchanged).
>
> Items 1–5 are **per commitment**. Nothing here is a statement about the
> commitments jointly; that is U-3(b) / gap G-R4 and it is untouched.

**Status of Lemma S, part by part.**

* **the shape hypothesis S-1** (`log(Dom::Tab) == log_cols`): COUNTED true at
  every shape in scope, held by construction and by no check; ruling S-1 puts
  it in ruling G-3's invariant list and owes it a named `Shape::new` refusal
  with a test (§1.4). Until that refusal exists it is a **RELIES ON**.
* **item 1, H-pad**: PROVED HERE at both shapes, by exact determinant, for
  every admissible column set (§4.C).
* **item 1, H-pair**: RELIES ON `audit_claims` (`protocol.rs:230-274`) for
  `A`, `H` and the boundaries, and on the explicit three-part check
  (`protocol.rs:355-367`) for the external endpoints. MEASURED at rung-G on
  two captures by the run gate; never observed at 125M (**GS-4**).
* **item 1, H-prox**: a refusal (`protocol.rs:282-292`), so it holds on
  every non-refused run by construction.
* **item 4**: PROVED HERE at both shapes for all 23 slots and five `ρ`
  regimes, with the negative control (§4.C).
* **items 2, 3 and 5**: PROVED-CONDITIONAL on the code facts of §6.1, with
  the structural steps of §3 supplying what the toy lemma's proof needs at
  the new layouts. COMPUTED at the shaped counts on a synthetic model
  (§4.B) and on a faithful miniature with `lkv = 2` (§4.A), and MEASURED at
  rung-G on two real captures by the run gate (§4.D). **Not computed on any
  real 125M receipt, which does not exist for this purpose (GS-1), and
  never at `lkv = 2` on real bytes (GS-3).**

### 2.2 Hypothesis by hypothesis, against the toy lemma

| # | Toy lemma's step | At a shaped layout |
|---|---|---|
| T1 | full row rank of the non-data block ⇒ `k0 = 0` (§1.3) | **verbatim.** The implication is an inequality about restricting coordinates; no shape constant enters. REDUCED to `ZK60_GENERIC_RANK_LEMMA.md` §1.3 |
| T2 | the eq-tensors never reach the non-data rows; pair weights are `(cm, cm·U)` (§2.2) | **NOT verbatim — restated as Fact 1′ (ruling S-1).** Clause (i) holds verbatim on `A`, the endpoints and the boundaries; on `H` two claims' data parts do sit on the two zero-sum `u` rows, where the weight is point-independent only because `log(Dom::Tab) == log_cols`. One new case either way: planes below the row width take `zpart_weights`' second branch. Pair weights unchanged. §1.3, §1.4 above. PROVED HERE, under hypothesis S-1 |
| T3 | `wedge(x, xU) = Norm(x)`; `wedge(λa, λb) = Norm(λ)·wedge(a,b)` (§3.2 step 4) | **verbatim** — field identities |
| T4 | the maximal minor factorises as `∏ Norm(λ·cm) · wedge(prox pair)` (§3.2 step 5) | **same form, changed counts**: `G` is 36 / 9 / 1 / 2 instead of 35 / 9 / 1 / —. COMPUTED exactly on the bilinear miniature (10 seeds, direct determinant equals the product every time) and at the shaped counts in `boundary_endpoint.txt` |
| T5 | claim supports disjoint, one pair each, prox untouched | **RELIES ON** `audit_claims` (`protocol.rs:230-274`), unchanged code, now called with shaped arguments at `:795, :799` (prover) and `:887, :917` (verifier), and from `boundary::check_opening` (`boundary.rs:281-283`). Not called for the external endpoints, which use the explicit three-part check instead (`protocol.rs:355-367`) |
| T6 | `cm ≠ 0` on a non-refused run | **verbatim** (`argument.rs:405`, re-tested at `protocol.rs:246`). Count changes: 25 extension rounds at every shape |
| T7 | `λ ≠ 0`, proximity pair independent | **verbatim** (`protocol.rs:282-292`), counts change: 177 / 175 λ draws per block, 4 openings per block, 3L+1 per run |
| T8 | the replay draws the same challenges the PCS will | **verbatim and still unclosed** — condition O-1; no Rust test. At a shaped layout there is MORE to go wrong: 36 groups instead of 35, and a boundary whose `want_groups` is a separate argument. **GS-2** |
| T9 | the u-row term (§3.3) | **needs a new argument, and it now goes through**: the enabling hypothesis ("every `H` plane's `log_size` on one side of `LOG_N`") is FALSE before ruling P-3's lift and TRUE after it, at both shapes. §3.5, [COUNTED] |
| T10 | H-pad / M-cols for every column set (§2.3, §3.4) | **needs recomputation at the new `(n, nn)`; done.** §4.C, `channels_shaped.txt`. New wrinkle: `n ≠ Q` at both shaped layouts |
| T11 | `uncovered_s = 0` (§3.5a) | **needs recomputation at the new `(N_s, d_s)`; done** for all 23 slots of both shapes under five `ρ` regimes, with the negative control. §4.C |
| T12 | every published mask functional in the round span (§3.5b) | same. §4.C |
| T13 | `M-q`, `M-prox` | **verbatim** — `M`'s geometry is shape-independent (`zk.rs:373-375`, `M_ROWS = 2·23 + 4 = 50` at every shape). Still RELIES ON `zk.rs:452-457`, not re-derived here |
| T14 | the reduction `disclosed = n·k0 + u-term` itself | **needs care at `n ≠ Q`.** The toy had `n = Q = 256`; a shaped commitment publishes `n + Q` entries with `n` = 1,024 or 16,384 and `Q` = 256. COMPUTED without the reduction at `n ≠ Q` (§4.A, part D′) |
| T15 | refusals carry no witness information | **verbatim in form**, but a RUN breaks it: ruling R-1 of the run disposition found twelve input-determined refusal sites inside the witness builder. That is not this lemma's channel — it is the run's operating rule M-9 — and it is named here only so nobody reads Lemma S as covering it |
| T16 | the four `part_rows` assertions | **verbatim**, now at `pcs.rs:867, 876, 883, 894` in this tree. Invariant |
| T17 | `d + 1` values per sumcheck round | **verbatim** (`zkp-core/src/sumcheck.rs:148-150`), and the negative control reproduces at the new `(N, d)`: dropping to `d` values raises `dim_Fp2 ker R` from 1 to 2. Invariant |
| T18 | non-data rows' messages uniform | **verbatim** for `A`/`H` (`protocol.rs:655-657`, the mask and proximity rows; `:757-767`, `H`'s mask rows and its two zero-sum rows, uniform on a hyperplane), and for the new commitments: `endpoint_g.rs:229-232` and `boundary.rs:322-325` fill every row from `data_rows` up with `rng.fp()` from a fresh OS-seeded stream |

### 2.3 The six steps that need a NEW argument

The brief names them (a)–(f). §3 takes them in order.

---

## 3. The new arguments

### 3.1 (a) The repaired bilinear slots — two claims sharing `ρ_g`

**What changed.** Ruling §4 of `ZK60_BLOCK125M_S19F1_DISPOSITION.md` made the
key-value **group** bits sumcheck variables shared by both private factors of
`SC_SCORE` and `SC_PV`, under a public `eq(r_g, ·)`. Read off
`argument.rs:1126-1187`, the four coordinate lists are

```
SC_SCORE  A_QR8 :  fixed(r_t) ‖ rho(0..lkv) ‖ fixed(r_hj) ‖ rho(lkv..lkv+ldh)
          A_KR8 :  fixed(r_j) ‖ rho(0..lkv)               ‖ rho(lkv..lkv+ldh)
SC_PV     A_P   :  rho(0..lkv) ‖ fixed(r_hj) ‖ fixed(r_t) ‖ rho(lkv..lkv+lt)
          A_V8   :  rho(lkv..lkv+lt) ‖ rho(0..lkv) ‖ fixed(r_i)
```

So `SC_SCORE`'s two claims share the `lkv` group coordinates `ρ_g`, and
`SC_PV`'s two share `ρ_g` **and** the `lt` source-token coordinates. Both
pairs are on planes of the **same** commitment `A`.

**The answer, and it is a theorem rather than a measurement.** By **Fact 1′
clause (i)** (§1.4) a claim's point reaches only (i) its own data-row
equality tensor and (ii) its column key. The non-data block — the object
whose rank is the good event — contains, for claim `j` in group `g`, only the
two entries `λ_{g,j}·cm_j` and `λ_{g,j}·cm_j·U` at rows `(r_j, r_j+1)`, and
zero everywhere else among the non-data rows. `cm` depends on the slot's
extension challenges, not on `ρ`. **Therefore shared evaluation coordinates
cannot change the non-data block at all**, and the factorisation, the good
event and the bad set are exactly what they were. **PROVED HERE.**

**Which clause carries this, and what it depends on.** All four claims of the
two repaired slots are on `A` (`A_QR8`, `A_KR8`, `A_P`, `A_V8`), where
clause (i) is the whole story and no shape condition enters; the independent
check confirmed that reading. The *headline* nonetheless carries hypothesis
S-1 (`log(Dom::Tab) == log_cols`, §1.4), because §3.1 is stated as a
corollary of Fact 1 for every commitment of the block: at a shape that
lifted `Dom::Tab` above the row width, `H`'s non-data block would become
point-dependent and this section would have to be re-derived there. Ruling
S-1 makes that condition an invariant for exactly this reason.

Shared coordinates can do exactly two things, and both are accounted for:

1. **They correlate two claims' data-row weights.** Irrelevant: the
   disclosed dimension is `dim_Fp(F ∩ T)`, and under H-pair the only
   combinations of the view that could land in `T` are combinations of the
   generators that vanish on the non-data rows. There are none when the
   non-data block has full row rank, whatever the data-row weights are.
   **PROVED HERE**, and COMPUTED without the reduction in §4.A part D.
2. **They can make two column keys collide**, merging two declared opening
   groups. That is refused by name (`protocol.rs:301-303`, "N opening
   groups, the schedule declares M"), and it is a liveness event, not a leak. It is
   *more likely* than for an unrelated pair, because the shared coordinates
   sit at matching positions of the two tails and match automatically —
   which is worth counting rather than waving at. [COUNTED,
   `refusals_and_backstop.txt`]: of the `log_cols` tail positions, the
   number that must coincide by accident is **6 of 10** (rung-G `SC_SCORE`),
   **10 of 10** (rung-G `SC_PV`), **8 of 14** (125M `SC_SCORE`) and
   **14 of 14** (125M `SC_PV`) — collision probabilities `2^-768`,
   `2^-1280`, `2^-1024`, `2^-1792`. All four **REPRODUCED EXACTLY** by the
   independent check with its own key model, together with **zero numeric
   collisions over eight seeds of generic field elements** at every shape
   [COMPUTED, `..._check/keys_bilinear.txt`].

**The shape built after this draft (`Shape::rung_k4`, two group bits at rung
size).** It did not exist at `e6b612f` and is not in scope above; the check
computed its keys symbolically anyway, because it is the cheapest route to
`lkv = 2` on real bytes (GS-3). [COMPUTED, `..._check/keys_bilinear.txt`]:
**7 of 10** must coincide by accident for `SC_SCORE` (`2^-896`) and **10 of
10** for `SC_PV` (`2^-1280`); no structural collision; 0 numeric collisions
over eight seeds. A model, not a capture.

**Two more claims share a coordinate by construction, and the draft's
inventory missed them (ruling S-5, the check's B-4).** `SC_GMM` and `SC_UMM`
raise their claims on the **same plane `A_YM`** and share the **fixed** row
point `r_tf`, which is drawn once, in `SC_GMM`, and reused
(`argument.rs:1194-1208`; verified at `e6b612f`). [COMPUTED,
`..._check/keys_bilinear.txt`] their tails agree by construction at **3 of
10** positions at rung-G and **4 of 14** at 125M, so a collision needs
`2^-896` / `2^-1280`; there is none, and §5.1's union over `C(claims, 2)`
pairs at `p^-2` already dominates it. **No figure moves.** It is recorded
because the list above reads as an exhaustive inventory of claims that share
coordinates by construction and was not one.

> **A latent structural collision, outside every shape in scope (ruling S-3,
> the check's B-3).** `A_QR8`'s coordinate list ends with
> `rho(lkv..lkv+ldh)` and `A_KR8`'s ends with the **same symbols**
> (`argument.rs:1141-1158`: `tq` and `tk` are two copies of one segment).
> If `ldh ≥ log_cols` — that is, **`head_dim ≥ row width`** — both tails are
> the last `log_cols` entries of that one shared segment, the two column keys
> are **equal by construction on every run**, `opening_groups_at` returns
> `a_groups − 1`, and `check_opening` refuses **every** proof at that shape.
> That is a **liveness cliff, not a leak** (a merge discloses strictly less;
> see the STRUCK N-2 in §3.6, where the merge computes to `k0 = 0`). No shape
> is near it [COUNTED: head dimension 8 / 16 / 8 / 64 against row widths
> 256 / 1,024 / 1,024 / 16,384 at toy / rung-G / rung-K4 / 125M], and
> **nothing refuses it**: `shape.rs:252-260` guards only the opposite
> direction, a bilinear domain *below* the row width that P-3 lifts (read at
> `e6b612f`). `SC_PV` can never collide structurally — `A_V8`'s tail always
> ends in the fixed `r_i` and `A_P`'s in `ρ_s`. **Ruling S-3: a named
> `Shape::new` refusal, with a test — owed, not yet built.** The collision
> counted in point 2 above is therefore accidental *at these shapes*, not by
> construction at every shape.

**Verdict on the brief's question:** the two claims' functionals **are**
linearly independent of each other and of every other claim on `A` for
generic challenges; the bad set is unchanged and stays inside the refusal
set; **no new backstop term is owed** for the repair itself. The one new
refusal the repair could in principle trip is the group-count check, and it
is dominated by 700+ bits.

**COMPUTED** (`bilinear_miniature.txt`, §4.A below): a faithful miniature
with `lkv = 2`, over Goldilocks with random `Fp2` challenges, ten seeds —
4 claims, 4 distinct column keys, 4 opening groups, 10 generators, rank 10 on
the non-data rows, `k0 = 0`, and the direct determinant equal to
`∏ Norm(λ·cm) · wedge(prox)` on all ten. **The pre-repair schedule gives the
same answer**, which is the honest reading: S19-F1 was a completeness defect
and is privacy-neutral in the linear view. (It is also why no disclosure
gate could ever have caught it — the run gate says the same of itself,
`ZK60_NATIVE_RUN_GATE.md` §8.6 "What GQ-6 does NOT show".)

### 3.2 (b) The pad-zero term

Ruling P-1 adds to several zero-check slots a batched term
`μ_pad · Σ_groups (1 − supp(x)) · Σ_j ζ^j · plane_j(x)`
(`argument.rs:690-746`). The brief asks: new claim functionals, or the same
points?

**Neither — no claim at all.** The term's summands are obtained by
`b.tab(plane)` (`argument.rs:537-539`), which returns the table index of a
plane **already pushed** by `B::a_range` in the same slot; it never calls
`a_slice`, so it allocates no reserved pair and raises no claim. The support
indicator is `b.public(...)` (`argument.rs:588-596`), a `Tab::Pub`. The slot
then fails its own site-count assertion if the counts moved
(`argument.rs:597-600`). **PROVED HERE** by reading, and confirmed by the
counts: `a_sites` is 122 and `a_groups` 36 at both shaped layouts, the same
as without the term; the S19-F1 disposition's own list of counted
consequences ("it adds no rows, planes or claim sites") says the same.

What the term *does* add to this lemma is **one refusal per hosting slot** —
`ζ ≠ 0` (`argument.rs:765-770`), plus one more `μ` entry. The toy lemma's
§4 item 6(vi) flagged it as missing from the inventory; §5.2 below prices it.

**A correction to ruling R-7.** The run disposition corrected "8 ζ
challenges" to "at most 7". Seven is the number of **code sites**
(`argument.rs:961, 1028, 1224, 1299, 1352, 1410, 1485`), one of which
(`SC_QZC | SC_KVZC`) serves two slots. The number of **draws** is one per
distinct host slot of a padded domain that has at least one zero-rule `A`
plane (`pad.rs:347-359`, `argument.rs:933-935`): **8 at rung-G** (all nine
domains pad; `Dom::Ht` and `Dom::S` share the host `SC_SZC`) and **5 at
125M** (six domains pad). [COUNTED from the model's per-domain pad table;
**GS-9** records that the pad table classifies only 125M's planes, so the
rung-G figure 8 is an upper bound until `Dom::T`, `Dom::F` and `Dom::Kv` are
classified.] The difference is worth `2^-125.00` against `2^-125.68`, i.e.
nothing, which is why it is an erratum and not a finding.

### 3.3 (c) Exemptions by name, and public weights zero off support

Two distinct things are easy to conflate here, and conflating them is the
mistake a checker should look for.

* **The PCS column weights `cw`** (`zkey_weights`, `pcs.rs:902-915`) are
  either all-ones on `len` positions or an equality tensor whose entries sum
  to 1 at every point. They are never zero. Step 7 of the toy lemma's
  reduction needs exactly that, and it is a theorem, not a refusal.
  **Unchanged by P-2.** REDUCED to `ZK60_GENERIC_RANK_LEMMA.md` §3.2 step 7
  and `ZK60_TERMINAL_SURJECTION_REVIEW.md` §1.4.
* **Ruling P-2's "public weights are zero off their support"** is about the
  `Tab::Pub` tables *inside* a slot's polynomial — `fold_cols_i8(w, …)` at
  `argument.rs:1210` and the two norm gains at `:1232-1233`. Those are
  public factors of the sumcheck relation. They never enter `zkey_weights`
  and never enter a claim's row weights. **PROVED HERE** by reading
  `build_claim` (which takes only `slices`, `coef`, `point`) and
  `zpart_weights`.

**Exemptions by name** (35 planes, of which 34 are the lookup reciprocals
and one is `A_E`, `pad_table_recount.json`) change the *statement* — an
exempt plane is not proved zero off its support and is excluded from the
summations by the indicator — and change nothing in the linear view: an
exempt plane is committed hidden data claimed like any other. The honest
consequence is one sentence, and it is a limitation of the statement, not of
this lemma: **the prover chooses the padded positions of an exempt plane
freely, and Lemma S says the verifier's linear view discloses nothing about
them either.** **ARGUED.**

### 3.4 (d) Grouped heads with padded head slots: is the statement about the right space?

Under ruling P-1 most hidden planes on a padded domain are **proved zero**
off their support, and the padded head slots are `{3, 7}` at rung-G and
`{3, 7, 11, 15}` at 125M (`shape.rs:378-382`). So part of the data rectangle
holds values the verifier already knows. The brief asks whether the lemma is
then about the right space.

> **Fact 2.** Let `T` be the functionals supported on the whole data
> rectangle and `T' ⊆ T` those supported on the *unknown* positions only. If
> `dim(F ∩ T) = 0` then `dim(F ∩ T') = 0`. **PROVED HERE** — `F ∩ T'` is a
> subspace of `F ∩ T`. The lemma is therefore **conservative** at a padded
> shape: it proves more than the hidden data needs.

The converse fails, and that is the direction a checker should probe: a view
that discloses something could disclose it entirely inside the known-zero
region, in which case the tool's figure would overstate the harm. **COMPUTED**
(`bilinear_miniature.txt` §E): with the whole data rectangle hidden,
disclosed 0; with only the supported half hidden, disclosed 0; and in the
broken control (two claims sharing one reserved pair) the two figures
**separate**, 16 against 8 — so the computation can tell the two spaces
apart and is not reporting 0 by construction.

One further consequence worth recording, because it is not obvious: a
known-zero data position does **not** reduce the blinding. The blinding lives
on the mask rows, the proximity rows and the pads, none of which is a data
position. **ARGUED.**

### 3.5 (e) `H` after the P-3 lift, and (e′) the endpoint's spare row

**`H`'s u-row term at a shaped layout.** Blocking item B-1 of the toy check
said the LogUp sum claim *cannot be formed* at either shaped layout, because
the helper domains straddle the row width and the claim's parts fall under
three different column keys. Ruling P-3's lift (`layout::domain_log_at`,
raising `Dom::L` and `Dom::Tab` to the row width at no extra rows) closes it.
[COUNTED, `shaped_counts.txt`]:

| shape | row width | `H` domain logs after the lift | below the row width | keys, with lift / without |
|---|---|---|---|---|
| toy | `2^8` | D 9, F 9, Kv 8, L 9, Q 9, S 11, Tab 8 | none | 1 / 1 |
| rung-G | `2^10` | D 12, F 13, Kv 10, **L 10\***, Q 12, S 13, **Tab 10\*** | none | **1 / 3** |
| 125M | `2^14` | D 19, F 20, Kv 17, **L 14\***, Q 19, S 22, **Tab 14\*** | none | **1 / 3** |

(`*` = lifted.) With one key the sum claim is constructible, and steps 1–5 of
the toy lemma's §3.3 transfer:

1. **the sum claim is alone in its group** — its key is `([], 0, n)` because
   every part has an empty point (`protocol.rs:167-178`), and every
   evaluation claim's key has a **non-empty** tail, because after the lift
   every `H` plane's domain log is `≥ log_cols` so the tail has `log_cols ≥
   10` coordinates. **PROVED HERE** at both shapes (the toy needed a `p.log
   ≥ 1` enumeration; the lift makes it immediate);
2. **its pair coefficients are exactly `(1, U)`** — `H_U` has `Dom::Tab`,
   which after the lift is exactly the row width, so the plane occupies one
   row for `re` and one for `im`, and `logup_sum_claim` gives it `coef = ONE`
   and `ONE·U` (`protocol.rs:170-176`). The diagonal factor is `Norm(1) = 1`,
   a constant, at every shape. **PROVED HERE**;
3–5. the elimination of the other groups' coefficients, the uniqueness of the
   solution and the span equality are word for word the toy's, because they
   use only the block-triangular structure and `Norm(λ_{g,j}·cm_j) ≠ 0`.
   **REDUCED to** `ZK60_GENERIC_RANK_LEMMA.md` §3.3.

**The deliberate shared pair travels.** A second claim still evaluates `H_U`
(`argument.rs:1537`, `b.h(hids.u())` in `SC_ZS`) at every shape, in a
different opening group, so `H`'s reserved pairs are **not** disjoint across
groups and the two groups must be ranked as one connected component — the
toy's change R-5, unchanged in form. COMPUTED at the shaped counts
(`boundary_endpoint.txt`, the `H` block: 20 generators, 108 non-data rows,
rank 20, `k0 = 0`, including with a degenerate proximity pair). The *span
equality* with the public LogUp identity is MEASURED at rung-G by the run
gate on two captures (`equals_public_logup_identity: true`, 234 nonzero
weights) and is **not** measured at 125M (**GS-1**).

**Why `H` discloses 2 at all — written in, and now computed** (ruling S-5,
the check's B-9). The draft reduced the `u`-row term to the toy's §3.3 and
never said what makes it nonzero. The mechanism is one line of the prover:
`protocol.rs:760-768` fills each `u` row with `n − 1` random words and sets
the last to their negation, so **the all-ones functional on a `u` row is
publicly zero**. The LogUp sum claim's column weights are exactly all-ones
on `[0, n)` — its key is `([], 0, n)` and `zkey_weights` fills that range
with `ONE` (`pcs.rs:872, 902-914`) — so the `u` rows give the sum claim **no
blinding at all**, and its public value `0` becomes a constraint on the
hidden data. The disclosure is therefore a property of the zero-sum
construction, not a corollary of anything. [Verified by reading at
`e6b612f`.]

[COMPUTED, `..._check/brute_view.txt` §2, 3 seeds, on an `H`-like model with
groups of 3 and 1, `SC_ZS`'s group also touching the two `u` rows, and the
pairless sum claim alone in its group with coefficients `(1, U)`]: disclosed
**2**, disclosed span dimension 2, public-identity span dimension 2, **spans
EQUAL on every seed**; run *without* the zero-sum constraint the same model
returns disclosed **0**. **What that closes of GS-1:** the *identity* (not
just the dimension) is now computed at a shaped layout, which the draft had
deferred to GS-1 and had only MEASURED at rung-G. **What it does not close:**
GS-1 as written asks for a measurement on real 125M receipt bytes, and none
exists; this is a model at the shaped counts, not a capture.

**(e) The endpoint's spare row.** An endpoint commitment has five mask rows
(`endpoint_g.rs:52`): the terminal pair at `(data, data+1)`, the proximity
row at `data+2`, and two more random rows. The refusal tests
`(prox, prox+1) = (data+2, data+3)` (`protocol.rs:335-348`,
`:282-292`), so `data+4` is tested by nothing and named by nothing. What it
buys is **slack**: 5 non-data rows against 4 generators.

[COMPUTED, `boundary_endpoint.txt`, 8 seeds, both shapes]

| endpoint case | generators | non-data rows | rank on non-data | `k0` |
|---|---:|---:|---:|---:|
| honest | 4 | 5 | 4 | **0** |
| proximity pair `Fp`-dependent (a refused draw) | 4 | 5 | 4 | **0** |
| the same, **with the spare row removed** | 4 | 4 | 3 | **1** |
| `cm = 0` (a refused draw) | 4 | 5 | 2 | **2** |
| `λ = 0` (a refused draw) | 4 | 5 | 2 | 0 |

So the spare row is the reason a degenerate proximity draw would not disclose
anything at an endpoint even if the refusal were removed. It is not
decoration. **PROVED HERE** (the rank argument) and **COMPUTED**.

### 3.6 (f) The boundary — and the sharpest finding in this memo

An internal boundary is `data + 2·sites + 2` rows with `sites = 2`
(`boundary.rs:180-197`), a derived count that `BoundarySpec::new` refuses any
other value for (ruling M-1). Its two claims come from **two different
stages** — block `k`'s `SC_IO_OUT` in stage `k`, block `k+1`'s `SC_IO_IN` in
stage `k+1` — and are opened **once**, in stage `k+1`
(`run.rs:495, 521, 661`). Each claim gets its own reserved pair
(`BoundarySpec::mask_row`, `boundary.rs:196-202`), so the two blinding
sources are disjoint even though the claims are a stage apart.

Its arithmetic: `G = 2` singleton groups, generators `2(G+1) = 6`, non-data
rows `2·2 + 2 = 6`. **Slack zero, at every shape.** The chosen minor is the
*whole* non-data block, and its determinant is
`Norm(λ_1 cm_1)·Norm(λ_2 cm_2)·wedge(ρ_prox[prox], ρ_prox[prox+1])`.

**And that is an identity, which makes the backstop moot here** (ruling S-5,
the check's B-10). [COMPUTED, `..._check/nondata_rank.txt`, 6 seeds] the
boundary's **whole** 6 × 6 non-data determinant equals that product
**exactly**, on every seed, as an integer in `Fp`. A product of norm forms
vanishes iff one factor does, and each factor vanishing is a **named
refusal**: `protocol.rs:246` for `cm = 0`, `:284-286` for `λ = 0`,
`:289-290` for the proximity pair (all three verified at `e6b612f`). So at a
boundary **"bad set ⊆ refusal set" is an identity, not a Schwartz–Zippel
estimate**, conditional only on `audit_claims` giving each group a member
with a pair of its own (`protocol.rs:259-272`). The same block-triangular
argument goes through on `H` with the pairless sum claim, whose diagonal
factor is `Norm(λ_sum · 1)`, even though `SC_ZS`'s group also touches the
`u` rows: ordering the `u` columns after that group's own pair makes the
extra entries upper-triangular. §5.4's figures stay on the page as what they
are — a generic bound on a polynomial already known to be a product of norm
forms — and are **not** what the lemma rests on.

[COMPUTED, `boundary_endpoint.txt`, 8 seeds, both shapes]

| boundary case | generators | non-data | rank on non-data | `k0` |
|---|---:|---:|---:|---:|
| honest | 6 | 6 | 6 | **0** |
| proximity pair `Fp`-dependent | 6 | 6 | 5 | **1** |
| `cm = 0` on one site | 6 | 6 | 4 | **2** |
| the two claims sharing one pair (`audit_claims` forbids) | 6 | 6 | 4 | **2** |
| a THIRD opening group appears — **UNREACHABLE past `audit_claims`**, see the STRUCK N-2 below | 8 | 6 | 6 | 2 |
| **one proximity ROW instead of a pair** (ruling M-1's own case) | 6 | 5 | 5 | **1** |
| the two claims merged into one group | 4 | 6 | 4 | 0 |

Three readings, in order of importance — the second of them is now STRUCK
and is kept, struck, as the record of what was claimed and why it is wrong.

> **Finding N-1 (new). At the boundary the proximity refusal is EXACTLY
> NECESSARY for hiding, not a completeness convention.** With an
> `Fp`-dependent proximity pair, `k0` rises to 1 — a whole row of hidden data
> per boundary. On `A` and `H` the same perturbation leaves `k0` at 0, which
> is exactly what the toy check reported and concluded was "conservative".
> **The difference is slack, not the refusal**: `A` has 172 spare non-data
> rows and `H` 84, so the two proximity generators stay independent modulo
> the group rows on other columns; the boundary has none. [COMPUTED,
> `boundary_endpoint.txt`, and again in the brute force
> (`bilinear_miniature.txt` §D, disclosed 8 = one row's `n`).] This
> **sharpens** the toy disposition's ruling G-4 — which said the zero-mask
> refusal is exactly necessary — with a second refusal that becomes exactly
> necessary as soon as a commitment is tight.
>
> The finding was **REPRODUCED** by the independent check on its own model,
> 6 seeds — `k0` rising 0 → 1 at the boundary and staying 0 on `A` and `H`
> under the same perturbation — as was the whole of the table above, row for
> row (`..._check/nondata_rank.txt`).
>
> **What a boundary's hiding rests on, exactly** (ruling S-2's wording): the
> audit's **pair exclusivity**, the **two zero-mask refusals** and the
> **proximity-determinant refusal**. With 6 generators on 6 non-data rows a
> boundary has **zero slack**, and the external endpoint's spare row is what
> gives it slack 1. Nothing else carries it — in particular **not** the
> opening-group count check, which the draft's Finding N-2 wrongly priced as
> a privacy check and which ruling S-2 strikes (next).

> **~~Finding N-2~~ — STRUCK by ruling S-2 (the check's B-1).** The draft
> claimed that at the boundary the opening-group COUNT check is a privacy
> check: with three groups instead of two there would be 8 generators against
> 6 non-data rows, the full-rank implication could not hold, and `k0` would
> rise to 2. The arithmetic is right (`..._check/nondata_rank.txt`, 6 seeds,
> reproduces `k0 = 2`) **and the configuration is unreachable**.
> `check_opening` runs `audit_claims` **first** — `protocol.rs:298`, the
> first statement of the function at `:297` (verified at `e6b612f` while
> editing) — and on a two-site boundary the audit forces **exactly two**
> claims: every non-sum claim must touch exactly two adjacent site rows
> (`protocol.rs:259-262`) and every site row must be used exactly once
> (`protocol.rs:270-272`), so with `2·sites = 4` site rows, `claims × 2 = 4`.
> With two claims the first-occurrence grouping returns 1 or 2 groups and
> never 3. The only deviation the count check can catch is the **merge** of
> the two column keys, which this memo's own §3.1 point 2 calls a liveness
> event and which computes to **disclosure 0** (4 generators, 6 non-data
> rows, rank 4 — the last row of the table above, and
> `..._check/nondata_rank.txt`, 6 seeds): the verifier sees strictly less and
> the hidden rows are no less blinded.
>
> **The count check stays** — it is a schedule and soundness check and it is
> cheap — but it is **not** load-bearing for hiding, and **nobody builds a
> test for N-2**. Recording a check as privacy-critical when it is not is not
> a harmless over-statement: it is the kind of entry that later licenses
> relaxing something that *is* critical, on the grounds that "the count check
> covers it". What carries the boundary is stated on Finding N-1 above.
> **Gap GS-10 is struck with it** (§7).

> **Ruling M-1's own finding is reproduced.** A boundary with a single
> proximity row — `rows = data + 2·sites + 1` — has rank 5 of 5 on its
> reserved rows and discloses one real dimension. That was the checker's
> exact small model; here it comes out of the same generic computation, at
> the shaped counts, which is a mild independent confirmation.

**One thing the boundary does that this lemma does not cover.** Block `k`'s
`SC_IO_OUT` publishes its masked terminal — the claim *value* — in stage `k`,
one stage before the `λ`s and `ρ_prox` that blind the opening are drawn in
stage `k+1`. At **fixed** challenges that changes nothing, because the set of
published field values is the same. It matters for the Fiat–Shamir lift,
where later challenges are functions of a transcript that already contains
that value. That belongs to gap G-R5 and is **GS-7** here.

**GS-7 is correctly sized** (ruling S-5, the check's B-11): the check read
the ordering and found **no prover-side defect**. `run.rs:486-510` commits
the boundary root *before* either adjacent equality slot's challenges and
`:528-537` opens with `pending` + `ic`; the published terminal is `cm`-masked
by a mask row drawn from a fresh OS stream before the value exists, so the
value alone is uniform, and the `λ`s and `ρ_prox` are drawn strictly after it
and, in the ROM, independently of it. Both boundary refusals are enforced on
**both** sides — prover `boundary.rs:269-275`, verifier `run.rs:670`, both
through `protocol::check_opening`. What is owed is the **simulator's**
ordering in the Fiat–Shamir lift, which is gap G-R5, and this memo places it
there. [ARGUED by the check from reading; not re-verified line by line in
this revision.]

---

## 4. The computations

All exact, over Goldilocks `p = 2^64 − 2^32 + 1` with `Fp2 = Fp[U]/(U²−7)`,
in `results/zk60_generic_rank_lemma_shaped/`. **Every instance uses random
field elements at several seeds, never a degenerate one** — the lesson of
S19-F1 applied to this memo's own evidence.

### 4.A The bilinear miniature (`bilinear_miniature.py` / `.txt`)

**What is scaled down and what is not.** Scaled down: tokens, head
dimension, row width `n = 8`, pads `Q`, opened columns, and the number of
planes (4 instead of 83). **Not** scaled: `lkv = 2` (the 125M value); the
four coordinate lists axis by axis; which coordinate is a summed `ρ` and
which a fixed challenge; the two extension rounds and which factor each
masks; `build_claim`'s `(cd, cm, cm·U)`; both branches of `zpart_weights`
with their four asserts; first-occurrence grouping by column key; `zk_rhos`'
draw order; the field.

**Part A — the schedule and its grouping, 10 seeds.** 4 claims, **4 distinct
column keys → 4 opening groups**, 10 generators, `rank = rank|non-data = 10`,
**`k0 = 0`**, and the direct determinant of the chosen minor **equals**
`∏ Norm(λ·cm)·wedge(prox)` on all ten, never zero.

**Part B — where the shared coordinates show.** Each claim's non-data
support is exactly its own pair (`[12,13]`, `[14,15]`, `[16,17]`,
`[18,19]`), and the four keys differ.

**Part C — nine challenge regimes, 5 seeds each.**

| regime | groups | `k0` |
|---|---|---|
| uniform | 4 | **0** |
| both slots drawing the SAME fixed challenges | 4 | **0** |
| the group coordinates `ρ_g` driven to BOOLEAN values | 4 | **0** |
| **the PRE-REPAIR schedule** (group bits fixed in both factors) | 4 | **0** |
| the two bilinear claims forced into ONE group (`m = 2`) | 3 | **0** |
| one `cm = 0` | 4 | 2 |
| one group's `λ`s all 0 | 4 | **0** |
| the proximity pair `Fp`-dependent | 4 | 1 |
| two claims SHARING one reserved pair | 4 | 2 |

**Part D — brute force, no reduction at all.** The whole linear view is
built: every claim value, every group vector and the proximity vector in
full (message **and** pad halves), and each opened column's value at every
row. Coordinates are ordered with the hidden data rectangle last, and
`disclosed = rank(all) − rank(the observed-but-not-hidden block)`. 3 seeds:
256 functionals, 352 coordinates, **disclosed 0**. Controls fire: a shared
reserved pair → 16; one `cm = 0` → 16; an `Fp`-dependent proximity pair →
**8**; one opened column over the pad budget → 12; the two claims merged into
a 2-member group → 0 (Step 7 exercised at `m = 2`).

**Part D′ — `n ≠ Q`, which the toy could not show.** At the toy `n = Q =
256`; at rung-G `n = 1,024` and at 125M `n = 16,384`, against `Q = 256`. Run
at `(n, Q) = (8, 4)` and `(8, 2)`, 2 seeds each: **disclosed 0**, with the
one-over-budget control firing at each `Q`. This is the part of hypothesis
T14 the toy's evidence could not reach.

**Part E — the known-zero region** (§3.4 above).

**What this miniature does NOT show.** It has 4 claims where `A` has 122; it
has no `H`, no lookup identity and no CFS channel; its opened-column count is
4 where the real one is up to 256; and — the honest one — **a linear-view
model has no witness in it at all**, so it cannot see any defect that is a
disagreement between two definitions of the same polynomial. S19-F1 was
exactly such a defect. That is a limit of the method, not of this instance.

### 4.B The non-data block at the shaped counts (`boundary_endpoint.py` / `.txt`)

Every commitment kind at the shaped counts, 8 seeds (3 for `A`/`H`), with
each refusal switched off in turn. Data-row weights are drawn uniformly,
which is the **worst case** for `k0`: `k0 = rank(gens) − rank(gens|non-data)`
can only grow when `rank(gens)` grows. Results in §3.5 and §3.6, plus:

> **Definitional note, for anyone re-running these models** (the check's, and
> it cost it a first pass): `k0` is
> **`rank(all generators) − rank(generators restricted to the non-data
> rows)`**, *not* `#generators − rank(| non-data)`. The two differ exactly on
> the refused zero-`λ` draws, where a wholly zero generator discloses
> nothing — which is why the `λ = 0` rows of the endpoint and `cm = 0`
> boundary tables read as they do. Use this definition.

| `A`, rung-G (122 claims in 36 groups) | generators | non-data | rank\|nd | `k0` |
|---|---:|---:|---:|---:|
| honest | 74 | 246 | 74 | **0** |
| proximity pair `Fp`-dependent | 74 | 246 | 74 | **0** |
| `cm = 0` in a SINGLETON group | 74 | 246 | 72 | **2** |
| `cm = 0` in a multi-member group | 74 | 246 | 74 | **0** |

The last two rows reproduce ruling G-4 at the shaped layout **and sharpen
it**: the zero-mask refusal is exactly necessary **where a group has one
member**, and harmless where it does not. The draft could not say how many
singleton groups `A` has, because the script used a **reconstruction** of
the group-size distribution rather than the real column keys, and recorded
that as **GS-15**; its reconstruction's largest group had 36 members and its
rigorous lower bound was "at least 15 of the 36 singletons".

**GS-15 is CLOSED, and both figures move** (ruling S-5, the check's B-7).
The distribution is derivable exactly from `claim_sites`
(`shape.rs:582-617` at `e6b612f`) and the declared `a_groups` detail
(`shape.rs:763-780`, `a_groups = tzc + 15 + 2·2 + 4·2`), and it is

`[6, 2×8 | 1, 1 | 2 | 2 | 1×3 | 1,1 | 1,1 | 1 | 1×3 | 35, 2 | 7, 1 | 6, 1 |
13, 2 | 11 | 3 | 1, 1]`

— **36 groups, 122 claims, largest group 35** (not 36), **17 singletons**
(not "at least 15"). The two extra singletons over the draft's count are
`SC_QZC`'s and `SC_KVZC`'s off-cube claims, each alone in its group.
[COUNTED, `..._check/nondata_rank.py` header.] Re-run at the **real**
distribution, 6 seeds, the §4.B table above reproduces without the
reconstruction: `A` honest `k0 = 0`; degenerate proximity `k0 = 0`; `cm = 0`
in a singleton `k0 = 2`; `cm = 0` in the 35-member group or the 6-member
group `k0 = 0`; two same-group claims sharing one pair `k0 = 0`
[COMPUTED, `..._check/nondata_rank.txt`].

> **Finding N-4.** Each of the four claims of the repaired bilinear slots is
> **alone in its opening group** at both shaped layouts. By ruling G-4's own
> criterion the zero-mask-challenge refusal (`argument.rs:405`,
> `protocol.rs:246`) is therefore **exactly necessary for each of them**: set
> one of their `cm` to zero and the commitment discloses `n` field elements
> (`bilinear_miniature.txt` part C, `k0 = 2`; part D, disclosed 16 = 2·`n`).
> [COUNTED + COMPUTED.] **Unchanged by the check, and now with a counted
> denominator**: `A` has **17** singleton groups of 36 (above), four of which
> are these.

### 4.C The pad block and the CFS channel (`channels_shaped.py` / `.txt`)

**H-pad / M-cols at each shape's own `(n, nn, Q)`.** `E_j[pad k] = Z_n(x_j)
x_j^k` with `x_j = 7 w_nn^j`, so the pad block on distinct indices is
`diag(Z_n(x_j)) · Vandermonde(x_j)_{k<Q}` and its determinant on `Q` rows is
`∏_j Z_n(x_j) · ∏_{i<j}(x_j − x_i)` — computed exactly, with no elimination:

| parameters | `Z_n(x_j) ≠ 0` at every encoded position | nodes distinct | det ≠ 0 on 256 columns |
|---|---|---|---|
| toy `A`/`H` and endpoint, `n = 2^8`, rate 1/8, `nn = 2^11` | yes (8 distinct values) | yes | yes ×3 column sets |
| rung-G `A`/`H` and endpoint/boundary, `n = 2^10`, rate 1/4, `nn = 2^12` | yes (4) | yes | yes ×3 |
| 125M `A`/`H` and endpoint/boundary, `n = 2^14`, rate 1/4, `nn = 2^16` | yes (4) | yes | yes ×3 |
| `M` (shape-independent), `n = 2^9`, rate 1/8, `nn = 2^12` | yes (8) | yes | yes ×3 |

Column sets: consecutive, maximally spread, pseudo-random. **PROVED HERE**
with the finite arithmetic as evidence; no challenge enters and no union
bound is owed, exactly as at the toy, and the toy's standing condition O-3
carries unchanged: **`q_pad == num_col_checks == 256`, and the pad count and
`Q` must move together.**

**The CFS mask channel at every shaped `(N_s, d_s)`.** All 23 slots of each
shape, under five `ρ` regimes (uniform, all-one, all-equal, base-field,
all-zero): **`dim_Fp2 ker R = 1` in every case**, so `uncovered_s = 0`, and
both `sum_weights` and `eval_weights` lie in the row span in every case. The
`(N, d)` pairs are new — rung-G reaches `(14, 5)` and 125M `(23, 5)`, against
the toy's largest `d = 4` — so this is not a copy of the toy's run. Negative
control at the largest-degree slot: publishing only `d` values per round
instead of `d + 1` raises `dim_Fp2 ker R` from 1 to **2**, reproducing the
toy check's control at the new parameters and re-establishing ruling G-3's
second invariant at these shapes.

### 4.D What the run gate's figures test in Lemma S, and what they do not

The run gate (`ZK60_NATIVE_RUN_GATE.md`, rounds 1–4) computed, on **two**
three-block rung-G runs — one on a fully dense generic witness, one all-zero:
`A` disclosed 0 with `rank_P1` 74 of 623; `H` 2, shown by span equality to be
the public LogUp identity, 20 of 576; both external endpoints 0;
each boundary 0 on its reserved rows with rank 6 of 6; `M` 0; every
certifying minor nonsingular; the distinct opened columns inside the
256-pad budget; the pad block's exact rank equal to the distinct count.

**Two of those MEASURED figures are re-cited** (ruling S-5, the check's
B-8), because the draft quoted them from the wrong section and they are
measurements, not prose:

* **`rank_P1` "74 of 623"** is in the gate's **§8.5** ("The headline: dense
  against degenerate", lines 1084 and 1097), not §2.3/§2.4. §2.3's table
  carries the *generator count* 74, which is a different figure that happens
  to agree. [Verified against `ZK60_NATIVE_RUN_GATE.md` while editing.]
* **"243–251 distinct opened columns"** is specifically **`run-b-zero`'s**
  spread, stated in **§2.3** (line 173). The tabulated `run-a-tame` spread
  is **246–250**, and §8.5's per-bundle stage-0 `A` figures include **242**
  and **252**, i.e. outside the quoted range. What is true of all of them,
  and is the only thing this memo uses, is that every distinct count is
  **inside the 256-pad budget** and equals the pad block's exact rank.

**What that tests in Lemma S.** It confirms items 1, 2 and 3 at **one shape**
(rung-G) at **two challenge vectors**, on receipts a real binary produced —
which is worth more than any model, because it tests the code path, the
grouping the Rust actually formed, and the transcript the Rust actually
consumed. In particular it is the only evidence that `audit_claims`'
exclusivity really holds on a shaped claim schedule, and the only evidence
that the declared group counts (36 / 9 / 1 / 2) are the counts the PCS forms.

**What it does not test.** (i) Genericity over challenges: two vectors are
two vectors, which is the whole reason this lemma exists. (ii) Anything at
125M: the gate has no 125M bundle at all, and the run disposition's own table
says "nothing" in that column for every row. (iii) More than one group bit:
rung-G has `lkv = 1`, so the 125M case `lkv = 2` has never been exercised by
any capture — §4.A's miniature is the only place two group bits have been
computed. (iv) A completeness defect on any witness, which the gate says of
itself.

**What one more computation would add, in order of value.**

1. **A synthetic four-key-value-group capture at a rung-sized shape** — the
   stage-20 reviewer already had to build one (`head_dim = 8`, finding F-2).
   A capture from it, through the run gate, would give `lkv = 2` on real
   receipt bytes and close the largest part of **GS-3**. **In flight, not
   owed:** `Shape::rung_k4` was committed at `3247a89` *after* this memo's
   pin, and the disposition records real bytes (`run-i-dense-k4`) existing
   since 23:03 and with the gate. This memo has read neither.
2. **A rung-G capture with the certifying minor for the boundary printed
   with its determinant**, so that Finding N-1's zero slack is visible in the
   gate's own record rather than in this memo's model.
3. **A 125M single-block capture** (no run needed) for `A`, `H` and the two
   endpoints. The run disposition's table has "nothing" at 125M and that is
   the largest single hole in the evidence.

---

## 5. Refusals and the backstop, at both shapes and for a run

All figures [COUNTED / COMPUTED], `refusals_and_backstop.txt`. Every
challenge is drawn from `Fp2`, and for `a, b` uniform in `Fp2`,
`Pr[wedge(a,b) = 0] = (p² + (p²−1)p)/p⁴ = 2^-64.00` exactly.

**The script's toy column is its own control.** Run at the toy shape it
returns 174 PCS `λ` draws, a total refusal probability of `2^-62.000`, an
`A` minor of `72 × 72` at degree `212`, and a backstop union of `2^-55.85`
— every one of them the toy lemma's own figure (`ZK60_GENERIC_RANK_LEMMA.md`
§5), reached from the layout model rather than from that document.

### 5.1 Challenge-only refusals — liveness, not privacy

| term | toy block (control) | rung-G block | 125M block | 12-block 125M run |
|---|---:|---:|---:|---:|
| terminal mask `e ∈ {0,1}` (25 extension rounds) | `2^-122.36` | `2^-122.36` | `2^-122.36` | `2^-118.77` |
| CFS multiplier `c_s = 0` (23 slots) | `2^-123.48` | `2^-123.48` | `2^-123.48` | `2^-119.89` |
| `ν = 0` (5 sites × 2) | `2^-124.68` | `2^-124.68` | `2^-124.68` | `2^-121.09` |
| `ζ = 0` (0 / 8 / 5 pad-zero hosts) — **new to the inventory** | — | `2^-125.00` | `2^-125.68` | `2^-122.09` |
| PCS `λ = 0` (174 / 177 / 175 / 2,100 draws) | `2^-120.56` | `2^-120.53` | `2^-120.55` | `2^-116.96` |
| **proximity pair `Fp`-dependent** (4 / 4 / 4 / 37 openings) | **`2^-62.00`** | **`2^-62.00`** | **`2^-62.00`** | **`2^-58.79`** |
| an accidental column-key collision — **new to the inventory** | `2^-114.95` | `2^-114.90` | `2^-114.92` | `2^-111.34` |
| **total** | **`2^-62.00`** | **`2^-62.00`** | **`2^-62.00`** | **`2^-58.79`** |

The run total reproduces ruling R-6's `2^-58.8` exactly, from an independent
count of `3L + 1 = 37` openings. The column-key-collision term is a bound:
any two claims the schedule declares in different groups differ at ≥1 tail
position, so a collision costs ≥ `p^-2`; the union is over all
`C(claims, 2)` pairs per opening, which over-counts (pairs inside one
declared group are deliberate, not accidental) and is therefore conservative.

### 5.2 Draw census, for the sampler residual

Per block, the draws that enter this lemma [COUNTED]: rung-G **1,705**
(177 `λ`, 1,217 proximity, 242 sumcheck, 25 extension, 23 CFS, 10 `ν`, 8 `ζ`,
3 tags); 125M **13,477** (175, 12,875, 361, 25, 23, 10, 5, 3). At the privacy
case's `2^-96` per draw these price at `2^-85.3` and `2^-82.3` per block;
both are inside decision D9's accepted residual and are listed only so that
this lemma's own inputs are priced.

### 5.3 The input-dependent refusal, and the refinement ruling R-6 asked for

The prover inverts LogUp denominators (`protocol.rs:402-405`, called at
`:691, 702, 704, 734`) and discards the attempt on a zero. Ruling R-6 prices
it by the **raw count of inversions**, and asks for a distinct-value
refinement before any 125M statement. (The draft cited the fourth live call
site as `:703`; `:703` *builds* the activation denominators and the
inversion is on the next line — an erratum the check found while recounting,
corrected here and verified at `e6b612f`.) The raw counts, **with the
table-helper term corrected** by ruling S-4:

| shape | u8 positions | exp | act | table rows | raw total | bits | R-6's figure |
|---|---:|---:|---:|---:|---:|---:|---:|
| toy | 61,440 | 2,048 | 512 | 768 | 64,768 | `2^-112.02` | `2^-112.0` |
| rung-G | 419,840 | 8,192 | 8,192 | **768** | **436,992** | `2^-109.26` | `2^-109.3` |
| 125M | 98,598,912 | 4,194,304 | 1,048,576 | **768** | **103,842,560** | `2^-101.37` | `2^-101.4` |
| 12 × 125M | | | | | **1,246,110,720** | `2^-97.79` | `2^-97.8` |

**The correction to the table-helper term** (ruling S-4, the check's B-5).
The draft priced the three table helpers at `3 × row width` — 768 / 3,072 /
49,152 at toy / rung-G / 125M. The code inverts `table_values_u8(g_u8)`,
`table_values_exp(...)`, `table_values_act(...)` (`protocol.rs:730-734`),
each of which is `table_values_*_at(Dom::Tab.len(), …)`
(`argument.rs:854-883`), and `Dom::Tab.len()` (`layout.rs:163-165`) is
`1 << domain_log_at(8, true, LOG_N)` with `LOG_N` the **toy's 8**
(`layout.rs:48`) — i.e. **256, at every shape**, not `sh.size(Dom::Tab)`. So
the term is `3 × 256 = 768` everywhere. [COUNTED,
`..._check/refusal_recount.txt` §A, and verified in the code at `e6b612f`
while editing. The draft's own `refusals_and_backstop.py` carried the
superseded 3,072 / 49,152 until **2026-09-21 09:34**, when the security owner
corrected the one line (`tab = 256` at every shape, with the code lines cited
against the lane at `79f0726`: `layout.rs:48`, `:194-199`,
`protocol.rs:905-907`) and re-ran it: its raw counts are now 64,768 /
436,992 / 103,842,560 and its totals reproduce the check's to the digit shown
(`refusals_and_backstop.txt`).] The per-block bit figures **do not
move** (`2^-112.02` / `2^-109.26` / `2^-101.37`); the twelve-block figure
moves by 0.0007 bits, from `2^-97.78` to `2^-97.79` — the only *bit* figure
on this page the recount moves. It also means the P-3 lift argument
the draft gave for the table families is not needed: they never grow in the
first place.

**The refinement, taken.** `α` is drawn *after* `β` (`protocol.rs:682`), `γ`
(`:683`) and the `A` and `M` roots (`α` at `:684`), so conditioned on the
transcript the whole set of denominator arguments is fixed — including the
two families whose arguments contain `β` — and `α` is uniform on `Fp2`. The
bad event is exactly `α` landing in the **set of distinct arguments**. For
**any witness the constructors admit** that set is:

* the byte-lookup family: `α − (v + γ·TAG_U8)` with `v` a byte — **≤ 256**
  values, whatever the number of positions. Every `u8` lookup expression in
  the module is one of three constructors, `byte(p)` (`v = p`),
  `scaled(p, k)` (`v = k·p`, with `byte(p)` also present) and `sym(p)` (the
  pair `p + 127` and `127 − p`), `layout.rs:561-571`; and at a **padded**
  position every non-exempt plane is proved zero (ruling P-1), so the
  argument is the constant `cst ∈ {0, 127}` — still a byte;
* the exponential family: `α − (d + β·e + γ·TAG_EXP)` with `(d, e)` a row of
  the 256-entry exponential table — **≤ 256**;
* the activation family: `α − (i + β·a + γ·TAG_ACT)` with `(i, a)` a row of
  the 256-entry activation table — **≤ 256**;
* the three **table**-helper families add nothing new, and for a simpler
  reason than the draft gave: `table_values_*_at(256, …)` enumerates exactly
  the 256 rows of each table (§5.3's correction above), so each helper
  family is a **subset** of its own family above. [COUNTED,
  `..._check/refusal_recount.txt` §B.]

> **Finding N-3.** The distinct-argument set has at most **3 × 256 = 768**
> elements **at every shape**, so the input-dependent refusal is at most
> `768 / p² = 2^-118.42` per block and, with `L` independent `α`s,
> `12 × 768 / p² = 2^-114.83` for a twelve-block 125M run. Against R-6's raw
> figures that is **17.0 bits** at 125M, **9.2** at rung-G and **6.4** at the
> toy. It removes R-6's stated worry that the term "sits a third of a bit
> from the run's soundness level": at `2^-114.8` it is 17 bits below it.
> **PROVED HERE** (the argument) and **COUNTED** (the arithmetic).
> **CONFIRMED by independent recount** (ruling S-4): the check counted the
> same three families of at most 256 arguments each, with the three table
> helpers subsets of them, and reproduced `768`, `2^-118.42` and `2^-114.83`
> **to the digit** [COUNTED, `..._check/refusal_recount.txt` §B]. Ruling S-4
> adopts these figures; R-6's raw `2^-101.4` and `2^-97.8` stay correct as
> upper bounds, and the toy's own statement keeps its conservative
> `2^-112`.
>
> **The conditioning, strengthened** (ruling S-4, the check's B-6). The draft
> conditioned on "an honest witness". The right and stronger conditioning is
> **"any witness the constructors admit"** — which is exactly Lemma S's own
> hypothesis, so the term is in scope rather than parked beside it. The byte
> ranges are **refusals in the constructor**, not a property of honesty:
> `Witness::new` refuses out-of-range values at `witness.rs:290, 374, 386,
> 394, 534, 555, 600, 640, 672, 708`, including
> `if !(0..256).contains(&delta)` for the exp difference at `:533` and
> `:639`; every `u8` lookup expression is one of the three constructors at
> `layout.rs:561-571`; and a padded position carries the constant `cst`.
> [Each line verified at `e6b612f` while editing.]
>
> **The caveat that replaces the old one, and it belongs here rather than in
> §8.** Those same range refusals are ruling R-1's **input-determined**
> refusal sites. The LogUp-denominator term is correctly priced *given
> admission*; the admission event itself is a function of the hidden input
> and is governed by operating rule M-9, not by this term. Nothing here
> prices M-9.

### 5.4 The Schwartz–Zippel backstop, if a structural step is rejected

The realified maximal minor is `2(G+1)` square with entries of degree
`≤ 1 + ext ≤ 3` on the group rows and 1 on the proximity rows, over **`Fp`**
(realification is `Fp`-linear, not `Fp2`-linear — the toy's correction C-8
stands). Degree `≤ 6G + 2`:

| | `A` | `H` | endpoint | boundary | one block | 12-block run |
|---|---|---|---|---|---|---|
| minor | 74×74 | 20×20 | 4×4 | 6×6 | | |
| degree | 218 | 56 | 8 | 14 | | |
| bound | `2^-56.23` | `2^-58.19` | `2^-61.00` | `2^-60.19` | **`2^-55.82`** | **`2^-52.24`** |

Both shaped layouts give the same figures (the group counts are the same).
The toy control comes out at `72 × 72`, degree 212, union `2^-55.85` —
the toy lemma's own numbers — so the 0.03-bit move is exactly `A_GROUPS`
35 → 36, as the toy check predicted. As at
the toy, this is a **generic bound on a polynomial known to be a product of
norm forms**, not an estimate of the probability. But it is worth saying
plainly that at run scale it is now the largest number anywhere on this page
and sits below the run's own soundness level, so **the backstop is not a
usable fallback for a run** — if a structural step of §3 is rejected, the
answer is to fix the structure, not to fall back. **ARGUED.**

**At a boundary the backstop is not merely unusable, it is MOOT** (ruling
S-5, the check's B-10; the identity and its refusals are written out in
§3.6). The whole 6 × 6 minor **equals** `Norm(λ₁cm₁)·Norm(λ₂cm₂)·wedge(prox)`
exactly, so "bad set ⊆ refusal set" is an identity there and no
Schwartz–Zippel estimate enters. **`2^-52.24` is therefore a bound on a
quantity this lemma does not use, and no later reader should quote it as a
security figure of a run.**

**Where the figures still matter,** and the reason they stay on the page: as
a fallback for a commitment whose factorisation has *not* been verified as
an identity at its own size. This page computed the identity only on the
4-claim miniature (§4.A, 10 seeds) and at the boundary (§3.6, 6 seeds); the
full `A` (74 × 74) and `H` (20 × 20) minors at the shaped counts were
checked by **rank at random draws**, not symbolically. Anyone who rejects
H-pair, or the factorisation at those two sizes, is back to this table.

---

## 6. The table of every step, and what to attack first

### 6.1 Label table

| # | Statement | Label |
|---|---|---|
| S1 | full row rank of the non-data block ⇒ `k0 = 0` | REDUCED to `ZK60_GENERIC_RANK_LEMMA.md` §1.3 (shape-free) |
| S2 | **REVISED (S-1): Fact 1 as drafted is FALSE; Fact 1′ replaces it** — (i) on `A`, the endpoints and the boundaries the point reaches only its data rows and its column key; (ii) on `H`'s two zero-sum rows a claim's data part does land in the non-data block, and contributes nothing only because `log(Dom::Tab) == log_cols` | **PROVED HERE** §1.4, GIVEN the four asserts `pcs.rs:867, 876, 883, 894` **and hypothesis S-1**, which is checked by no code path and is owed a named `Shape::new` refusal |
| S3 | pair weights are `(cm, cm·U)` at every shape, including planes below the row width | **PROVED HERE** §1.3 from `argument.rs:264-278`, `pcs.rs:860-900`; COMPUTED in every miniature instance |
| S4 | the repaired bilinear slots' shared coordinates leave the non-data block unchanged | **PROVED HERE** §3.1 (corollary of S2, clause (i), the four planes being on `A`); COMPUTED `bilinear_miniature.py`, 10 seeds + 9 regimes + brute force; **CONFIRMED** independently (`..._check/keys_bilinear.txt`) |
| S4b | the shared-coordinate inventory also contains `SC_GMM` / `SC_UMM` (same plane `A_YM`, shared fixed `r_tf`), and a structural collision exists at `head_dim ≥ row width` (outside every shape in scope, a liveness trap, refused by nothing) | COUNTED + COMPUTED §3.1 from `..._check/keys_bilinear.txt`; **no figure moves**; ruling S-3 owes a named `Shape::new` refusal. *(New row; no existing number was renumbered.)* |
| S5 | the pre-repair and repaired schedules give the same linear view | COMPUTED `bilinear_miniature.py` part C, 5 seeds; **CONFIRMED** (the defect S19-F1 is privacy-neutral in the linear view) |
| S6 | the pad-zero term raises no claim and allocates no pair | **PROVED HERE** §3.2 from `argument.rs:537-539, 588-600, 690-746` (this row cited `:527-529` for `B::tab`; `fn tab` is at `:536-539` at `e6b612f`, as §3.2 already said — editor's erratum, found beyond the check's list); **CONFIRMED** by the check (`a_sites` 122 and `a_groups` 36 unchanged) |
| S7 | ruling P-2's zero-off-support public weights are not the PCS `cw` | **PROVED HERE** §3.3 |
| S8 | `cw ≠ 0` always | REDUCED to `ZK60_TERMINAL_SURJECTION_REVIEW.md` §1.4 (shape-free) |
| S9 | a known-zero data region can only lower the disclosed dimension (Fact 2) | **PROVED HERE** §3.4; COMPUTED `bilinear_miniature.py` §E with a separating control |
| S10 | the LogUp sum claim is constructible and alone in its group at both shaped layouts | **PROVED HERE** §3.5; COUNTED `shaped_counts.txt` (1 key with the lift, 3 without) |
| S11 | the sum claim's pair coefficients are `(1, U)` at both shaped layouts | **PROVED HERE** §3.5 from `protocol.rs:167-178` and the lifted `Dom::Tab` |
| S12 | `H`'s two groups share the zero-sum pair at every shape; rank them as one component | REDUCED to `ZK60_GENERIC_RANK_LEMMA.md` §3.3 (change R-5); COMPUTED at shaped counts |
| S13 | the u-row term is exactly the public LogUp identity at 125M | **GAP GS-1** for the *measurement*; the argument is REDUCED (S10–S12). MEASURED at rung-G only. **Advanced (S-5 / B-9):** the *identity* (not just the dimension) is now **COMPUTED** span-equal at the shaped layouts, 3 seeds, and the mechanism — the zero-sum construction leaving the all-ones sum claim unblinded — is written in at §3.5 |
| S14 | the endpoint's spare row is the slack that absorbs a degenerate proximity draw | **PROVED HERE** §3.5; COMPUTED `boundary_endpoint.py`, 8 seeds, both shapes |
| S15 | the boundary has zero slack; its proximity refusal is exactly necessary (Finding N-1) | **PROVED HERE** (rank argument) + COMPUTED, 8 seeds, both shapes; **REPRODUCED** independently, 6 seeds. Its bad set is an **identity**, not a bound (S-5 / B-10, §3.6) |
| S16 | ~~the boundary's opening-group count check is a privacy check (Finding N-2)~~ | **STRUCK by ruling S-2.** The configuration priced is unreachable past `audit_claims` (`protocol.rs:298`); the only catchable deviation is a key merge, disclosure **0**. See the STRUCK paragraph in §3.6 and the struck **GS-10** in §7. No test is owed |
| S17 | the zero-mask refusal is exactly necessary where a group is a singleton; **17 of 36** `A` groups are (derived, superseding the draft's "at least 15"), including all four bilinear claims (Finding N-4) | COMPUTED `boundary_endpoint.py` + COUNTED `shaped_counts.txt`; the distribution **derived** in `..._check/nondata_rank.py` (largest group **35**, 17 singletons) — **GS-15 CLOSED** |
| S18 | H-pad / M-cols at both shaped `(n, nn, Q)`, every column set | **PROVED HERE** §4.C with exact determinants; conditional on `q_pad == num_col_checks == 256` |
| S19 | the reduction is right at `n ≠ Q` | COMPUTED without the reduction, `bilinear_miniature.py` part D′; the *general* reduction at `n ≠ Q` is **GAP GS-5** |
| S20 | `uncovered_s = 0` and the mask functionals lie in the round span, all 23 slots of both shapes | COMPUTED `channels_shaped.py`, 5 `ρ` regimes, with the `d`-values control; the proof is REDUCED to the toy §3.5 |
| S21 | the individual claim values add nothing (Step 7 / terminal surjection) | REDUCED to `ZK60_TERMINAL_SURJECTION_REVIEW.md` §1.4; COMPUTED at `m = 1` and `m = 2` in the brute force, and independently **at `m = 5` and `m = 3`** (disclosed 0, control firing at 16; `..._check/brute_view.txt` §1) |
| S22 | refusal probabilities per block and per run | COUNTED §5.1; reproduces ruling R-6's `2^-58.8` |
| S23 | the input-dependent refusal is `≤ 2^-118.42` per block, `2^-114.83` per run, **conditioned on any witness the constructors admit** (S-4, not "an honest witness") | **PROVED HERE** + COUNTED §5.3 (Finding N-3); **COUNTED twice, independently**; the raw table-helper counts corrected to 768 at every shape, the bit figures unmoved but for the run's `2^-97.78` → `2^-97.79` |
| S24 | the Schwartz–Zippel backstop at both shapes and for a run | COUNTED §5.4; **REPRODUCED**, and **MOOT at a boundary** (S-5 / B-10): there the minor is exactly a product of norm forms and the inclusion is an identity |
| S25 | 125M endpoint rows 37, prox pair (34,35), receipt 40,783,352 B | COUNTED §1.5; **CONFIRMED**, and the receipt figure is MEASURED in `ZK60_BLOCK125M_S19F1_DISPOSITION.md` §6. The layout model was stale at **two** endpoints, not one (S-5 / B-12) |
| S26 | `audit_claims` exclusivity on a shaped claim schedule | RELIES ON the code; MEASURED at rung-G by the run gate on two captures; **GS-4** at 125M |
| S27 | the refusal replay draws the same challenges the PCS will | RELIES ON reading; **GS-2**, no Rust test, and the shaped layout has more to get wrong |
| S28 | non-data rows uniform in the new commitments | RELIES ON `endpoint_g.rs:229-232`, `boundary.rs:322-325`; not re-derived |
| S29 | the joint law across commitments | **GAP** — U-3(b) / G-R4, untouched |
| S30 | the non-linear channel | **GAP** — out of scope; the shaped slots reach degree 5, so `poly_s` is worse than the toy's degree 4 |
| S31 | the hash layer | **GAP** — out of scope |

### 6.2 What the checker should attack first — my own ranking

**Ranking as it stands after the check.** The check took item 1 and found
the memo's Fact 1 false as stated (the repair is in §1.4, the ruling is
S-1); it took item 2 and reproduced it; it took item 3 and *strengthened*
the conditioning; it took item 4 and showed the >2-claim case unreachable,
which is what struck Finding N-2 (§3.6, and GS-10 in §7 — **do not build a
test for either; they are STRUCK**). Items 5 and 6 are unexamined by anyone.
The ranking below is kept, amended, so that the next reader can see what has
already been swung at.

1. **~~Fact 1~~ → Fact 1′ and hypothesis S-1 (§1.4), because everything in
   §3.1 is a corollary of it.** The universal form is now known to be wrong:
   on `H`, `SC_ZS`'s claim and the pairless sum claim do reach the two
   zero-sum rows. What is left to attack is the *repair*: (a) the hypothesis
   `log(Dom::Tab) == log_cols` — find a shape, or a future lift, that breaks
   it before the owed `Shape::new` refusal exists; (b) whether any **other**
   non-data row can receive a data part, which would mean a third clause
   (the check enumerated `audit_claims`' row-placement checks at
   `protocol.rs:241-249, 259-272` and found only the `u` rows outside them);
   (c) the original targets, still live — a data part whose slice straddles
   into the site rows, a plane whose `a_off` is not row-aligned so that
   `c0 ≠ 0` and the mask part's key is not what I say, a fourth branch of
   `zpart_weights`. Attack `part_rows` (`protocol.rs:215-218`) and the four
   asserts. I did read the `a_off` / `h_off` cursors
   (`layout.rs:1037-1042, 1052-1057`) and they are row-aligned, so `c0 = 0`;
   attack that reading — the check did not re-derive the plane cursor
   either.
2. **Finding N-1's slack argument (§3.6).** I claim the boundary's zero slack
   makes the proximity refusal necessary and that `A`'s slack makes it
   unnecessary. Both come from one synthetic model with uniformly drawn
   data-row weights. Attack the claim that uniform data weights are the worst
   case for `k0`, and attack the modelling of the group vectors (I put each
   group's members at their own pairs with independent `λ`, which is
   `zk_rhos`, but I did not model a group whose members' *data* weights are
   linearly dependent — which is exactly what the shared coordinates
   produce).
3. **Finding N-3's conditioning (§5.3) — answered, and narrower now.** The
   draft priced the input-dependent refusal over the *honest* witness's
   distinct arguments; ruling S-4 conditions it instead on **any witness the
   constructors admit**, which the check justified from the constructor's own
   refusal sites. What is left to attack is the **activation family's
   `act_indices` at padded positions** (all that remains of GS-12), and the
   separate question the caveat names: the admission event is itself
   input-dependent and is priced by operating rule M-9, not here.
4. **Whether `2(G+1)` is the right generator count at a boundary.** I take
   `G = sites = 2` from the declared count. If a run ever opens a boundary
   with a claim the schedule does not declare, or with `sites > 2`, the slack
   goes negative and `k0 > 0` follows immediately. **Narrowed:** with
   `sites = 2` the audit makes a third *claim* impossible
   (`protocol.rs:259-272`, the reason Finding N-2 is STRUCK), so what is
   left to attack is a shape or a run that declares `sites > 2` in the first
   place, i.e. `BoundarySpec::new` and ruling M-1's derived count.
5. **The `ζ` count and the pad-zero term's reach.** I assert the term raises
   no claim. Attack `b.tab` returning `usize::MAX` for a zero-rule plane
   outside the slot's `a_range` — I believe that panics rather than
   mis-indexes a claim, but I did not test it.
6. **The miniature's faithfulness.** Attack the coordinate lists in
   `coords_score` / `coords_pv` against `argument.rs:1126-1187` entry by
   entry; a transcription error there would make §4.A vacuous.

---

## 7. The gaps, by name

| # | Gap |
|---|---|
| **GS-1** | **OPEN, slightly narrowed. Nothing has ever been measured at 125M.** No capture, no disclosure figure, no rank, no certifying minor. Lemma S at 125M rests on structure + counts only, and the run disposition's own table says "nothing" in that column for every row. *Narrowed only in this:* the `H` identity that GS-1 asked to be computed rather than assumed is now COMPUTED span-equal at the shaped layouts (§3.5, S-5 / B-9) — on a model, not on 125M bytes, and the disposition records that **nothing can be measured at 125M with the present tools** (a 125M capture is out of the Python gate's reach). |
| **GS-2** | The refusal replay order is still pinned by no Rust test (the toy's condition O-1), and a shaped layout adds two things to get wrong: 36 groups on `A`, and a boundary whose `want_groups` is derived separately in `boundary.rs`. |
| **GS-3** | **OPEN, in flight. `lkv = 2` has never been exercised on real receipt bytes** *by anything this memo read*. rung-G has `lkv = 1`; 125M has `lkv = 2` and no capture. §4.A's miniature and the check's rung-K4 key computation are the only places two group bits have been computed, and both are models. Since the pin, `Shape::rung_k4` exists (`3247a89`) and the disposition records real four-group bytes (`run-i-dense-k4`) with the gate. |
| **GS-4** | `audit_claims` exclusivity at 125M is enforced but never observed. At rung-G the run gate observed it on two captures. |
| **GS-5** | The tool's **reduction** `disclosed = n·k0 + u-term` is not re-derived at `n ≠ Q`. I computed *without* it at `n ≠ Q` on a miniature (part D′); the general derivation, including why the u-term enters as `u_dim` and not `n·u_dim` when `n = 16,384`, is owed. |
| **GS-6** | The joint statement across commitments (U-3(b) / G-R4) is untouched, and the boundary is where three commitments hold the same plane. Nothing here licenses adding the per-commitment figures. |
| **GS-7** | **OPEN and CONFIRMED AS SIZED** (S-5 / B-11): it is a gap in the *argument*, not in the protocol. A boundary's site-0 claim value is published one stage **before** the opening whose `λ`s blind it. Harmless at fixed challenges, and the check found no prover-side ordering defect (`run.rs:486-510, 528-537`; both refusals enforced on both sides). What is owed is the simulator's ordering in the Fiat–Shamir lift (gap G-R5), which is unwritten. |
| **GS-8** | ~~`a_off` unread.~~ **CLOSED while drafting**: `layout.rs:1037-1042` and `:1052-1057` push every plane offset at a row boundary, so `c0 = 0` at every shape and the sub-row-plane case of §1.3 is settled. Kept in the list so the numbering does not move. |
| **GS-9** | The `ζ` count at rung-G (8) is an upper bound: the project's pad table classifies only 125M's planes, so `Dom::T`, `Dom::F` and `Dom::Kv` are unclassified at the rung. Worth `< 1` bit. |
| **GS-10** | ~~No test pins the opening-group **count** check as a privacy check at the boundary, where it is one (Finding N-2).~~ **STRUCK by ruling S-2** (the check's B-1), not closed and not deleted: the count check is **not** a privacy check, the three-group configuration is unreachable past the `audit_claims` call at `protocol.rs:298`, and the only deviation it can catch — a key merge — computes to disclosure **0**. **No test is owed.** The reasoning is in the STRUCK paragraph of §3.6; the number is kept so nothing renumbers. |
| **GS-11** | `M-q` and `M-prox` (`zk.rs:452-457`) are taken from the toy lemma, not re-derived. `M`'s geometry is shape-independent, so this is a carry-over, not a new gap — but it is still a RELIES ON. |
| **GS-12** | **NARROWED** (S-4, the check's B-6). The draft did not re-derive, plane by plane, that every `u8` lookup argument is a byte and every exp/act argument a table row at a **padded** shape. The check derived it for the **u8 family** (three constructors only, `layout.rs:561-571`, plus `Witness::new`'s range refusals and the padded constant) and for the **exp family** (`witness.rs:533, 639` refuse `delta` outside `0..256`). **What remains of GS-12:** the activation family's `act_indices` at padded positions, not re-derived by anyone. |
| **GS-13** | The non-linear channel is worse at a shaped layout than at the toy: slot degrees reach **5** (against the toy's 4), the two bilinear closures now carry a public `eq` factor, and eight slots carry a support indicator. `ZK60_JOINT_LAW_COMPOSITION_RUN.md`'s gap G-R2 (the 23 closures re-read) is untouched here. |
| **GS-14** | **A linear-view argument cannot see a completeness defect of any kind**, on any witness. S19-F1 proved that the hard way. Nothing in this memo, and nothing any disclosure gate can compute from a capture, would have caught it. |
| **GS-15** | **CLOSED** (S-5, the check's B-7). `boundary_endpoint.py`'s `A` and `H` cases used a **reconstruction** of the group-size distribution rather than the real column keys, and its singleton count was a lower bound of 15 of 36. The distribution is derivable exactly from `claim_sites` (`shape.rs:582-617`) and the declared `a_groups` detail (`shape.rs:763-780`): **36 groups, 122 claims, largest group 35, 17 singletons**, and every rank verdict of §4.B reproduces at the real distribution (6 seeds). §4.B carries the list. |

---

## 8. What this is not

1. **Not a privacy property and not a privacy acceptance.** It is a statement
   about the rank of an explicitly stated linear model, per commitment, at
   two layouts.
2. **Not a discharge of gap G-R1.** G-R1 asks for (H1) at a shaped layout.
   This memo supplies the structure and the counts, and closes the two
   channels the toy proved identically (§4.C). It does **not** supply the
   certificate at 125M, where nothing has been computed (GS-1), and it does
   not supply the `lkv = 2` evidence on real bytes (GS-3). **G-R1 is
   narrowed, not closed.** Where it stands after the check and the
   disposition (the disposition's §3 table, reproduced so this page and the
   ruling cannot drift apart):

   | Shape | State |
   |---|---|
   | **Generalised rung** (one group bit) | Lemma **accepted with hypothesis S-1**. Left: a Rust test pinning the refusal replay order against the opening's challenge order (**GS-2**); the reduction not re-derived at pad count ≠ column count, though brute force there scores 0 (**GS-5**); and the computed gate sees only two challenge vectors per shape. |
   | **Four-group rung** (two group bits) | Covered by the checker's collision count and its generic computation; real bytes exist since 23:03 (`run-i-dense-k4`) and are with the gate now. Neither is read by this memo. |
   | **125M** | The argument and every count carry over; **nothing has been measured there** (**GS-1**), **and nothing can be with the present tools** — a 125M capture is out of the Python gate's reach. A privacy statement at this shape would rest on the argument, the counts, and measurements at the two development shapes that share its head geometry. That is a limit to state, not to hide. |

   Still open on the whole path, and untouched here: the joint law across
   commitments with its machine-asserted draw accounting (G-R4), the slot
   closures as a reading (G-R2), the sequential lift for a run (G-R5), and
   the non-linear channel (GS-13).
3. **Not a statement about the commitments jointly.** Adding the
   per-commitment figures is exactly the step ruling R-3 corrected.
4. **Not a statement about the run's refusal channel.** Ruling R-1 found
   twelve input-determined refusal sites in the witness builder of a run;
   they are governed by operating rule M-9 and are not this lemma's subject.
5. **Not evidence about any witness.** The linear view has no witness in it.
   The run gate's dense-vs-degenerate comparison found 153 of 173 figures
   identical for exactly that reason, and the 20 that differ are counts of
   distinct sampled columns.
6. **Not a re-derivation by the security owner.** Every computation here was
   written by one delegated agent in one sitting. It **has now been
   attacked**, once, by a second delegated agent with its own field library
   and its own models (`ZK60_GENERIC_RANK_LEMMA_SHAPED_CHECK.md`, findings
   B-1 … B-12, §9 below), and ruled on by the security owner
   (`..._DISPOSITION.md`, S-1 … S-5, which records what he checked himself
   and what he did not re-derive). Two independent computations agreeing is
   not a proof, and neither page is a privacy acceptance.

---

## 9. What the check changed

One line per finding of `ZK60_GENERIC_RANK_LEMMA_SHAPED_CHECK.md`, with the
ruling that disposed of it. Its verdict on the lemma as a whole: **HOLDS
WITH CHANGE** — every numerical verdict of this memo reproduced on
independent computations at both shaped layouts.

| # | What it found | Ruling | Where it landed |
|---|---|---|---|
| **B-1** | Finding N-2 is **broken**: the boundary's opening-group COUNT check is not a privacy check, and the configuration priced is unreachable past `audit_claims` | **S-2** | N-2 and GS-10 **STRUCK** (§3.6, §7); no test owed; N-1 restated as what a boundary's hiding rests on |
| **B-2** | **Fact 1 is false as stated** — on `H`, two claims' data parts reach the two zero-sum rows; harmless only because `log(Dom::Tab) == log_cols` | **S-1** | **Fact 1′** in two clauses + **hypothesis S-1** (§1.4), added to the lemma (§2.1), to T2 (§2.2), to §3.1 and to S2 (§6.1); joins ruling G-3's invariants; a named shape refusal is owed |
| **B-3** | a **structural** key collision nobody named: `head_dim ≥ row width` would merge `SC_SCORE`'s two keys on every run | **S-3** | §3.1, as a liveness trap outside every shape in scope; a named `Shape::new` refusal with a test is owed |
| **B-4** | the shared-coordinate inventory was incomplete: `SC_GMM` / `SC_UMM` share the fixed `r_tf` on the same plane | **S-5** | §3.1 (3 of 10 / 4 of 14 equal by construction, no collision), plus the rung-K4 row (7 of 10, 10 of 10); **no figure moves** |
| **B-5** | §5.3's table-helper raw counts are wrong by a factor of the row width — the code inverts `Dom::Tab.len() = 256` per helper | **S-4** | §5.3: **768 at every shape**, raw totals 436,992 / 103,842,560; bit figures unmoved but for `2^-97.78` → `2^-97.79` |
| **B-6** | N-3's conditioning is weaker than it needs to be; the byte ranges are **constructor refusals**, not honesty | **S-4** | §5.3: conditioned on **any witness the constructors admit**; **GS-12 narrowed** to the activation family at padded positions; the M-9 caveat moved into §5.3 |
| **B-7** | the `A` group-size distribution is derivable: largest group **35**, **17** singletons, not 36 and "at least 15" | **S-5** | §4.B, and **GS-15 CLOSED**; S17 corrected |
| **B-8** | two MEASURED figures cited to the wrong gate section | **S-5** | §4.D: `rank_P1` 74 of 623 → gate §8.5; "243–251" is `run-b-zero`'s spread (gate §2.3), `run-a-tame`'s is 246–250 |
| **B-9** | the memo never said **why** `H` discloses 2, and the reason is the zero-sum construction | **S-5** | §3.5: the mechanism written in, and the identity **COMPUTED** span-equal at the shaped layouts (closes the *identity* question there, not GS-1) |
| **B-10** | the boundary's whole 6 × 6 minor is **exactly** `Norm(λ₁cm₁)·Norm(λ₂cm₂)·wedge(prox)`, so the backstop is moot there | **S-5** | §3.6 and §5.4: "bad set ⊆ refusal set" is an identity at a boundary; `2^-52.24` is not a security figure of a run; where the figures still matter is said |
| **B-11** | GS-7 is correctly sized — an ordering gap in the argument, not in the protocol | **S-5** | §3.6 and §7: GS-7 confirmed as sized, still open, still G-R5's |
| **B-12** | the layout model is stale at **two** endpoints (the frozen-seam rung's 14 against the code's 21), not one | **S-5** | §1.5; fixed in the model, on the lane |
| — | definitional trap: `k0 = rank(all) − rank(non-data)`, not `#generators − rank(non-data)` | — | §4.B, as a note for anyone re-running the models |
| — | erratum found while recounting: the fourth live `inverses` call site is `protocol.rs:704`, not `:703` | — | §5.3 |
| — | **found by this revision, in neither page**: §6.1's S6 row cited `argument.rs:527-529` for `B::tab`, which is at `:536-539` at `e6b612f` (§3.2 had it right) | — | §6.1 |
| — | **found by this revision, in the check**: its `shape.rs` line numbers past `:379` are the *worktree's*, not `e6b612f`'s — `Shape::rung_k4` shifts everything after it by +60, so its `claim_sites` `:642-677` is `:582-617` here and its `a_groups` `:823-840` is `:763-780`. No verdict changes; this page cites the pin | — | §4.B, §7 GS-15 |

**What the check could not check, and nobody has**: anything on real 125M
bytes (GS-1); `lkv = 2` on real receipt bytes (GS-3, now in flight); the
exact column keys of all 122 `A` claims (it checked the four bilinear
claims, the three feed-forward matmuls and cross-slot spot checks, and took
the `SC_TZC` sub-row offsets from the code's own `a_groups` derivation
rather than recomputing the plane cursor); `M-q` / `M-prox` (GS-11); the CFS
channel and the pad block of §4.C (it read `channels_shaped.py` and judged
the method sound, but did not re-run it); the non-linear channel, the hash
layer and the joint law (GS-13, GS-6, S29–S31); and whether the declared 36
`A` groups are what the Rust forms at 125M (GS-4).
