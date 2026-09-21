# The generic-rank lemma at a SHAPED layout and at a RUN (gap G-R1)

**Drafted by a delegated Opus agent for the security owner.**
2026-09-20, 22:08–23:10 PDT (`date`). Code read, read-only, at the lane
worktree `/home/victor/wt-zk60-block125m`, commit **`e6b612f`**. Evidence:
`results/zk60_generic_rank_lemma_shaped/` (five scripts, exact integer
arithmetic over Goldilocks, nothing built, no prover run, no capture read).

**This is not a privacy acceptance and nothing here establishes a privacy
property.** It is one step of one argument, at two layouts, on the linear
channels only. Register entry D22 (the toy block) is untouched; no run, no
development rung and no 125M block may be called private on the strength of
this page.

Every claim below is labelled: **PROVED HERE**, **REDUCED to** (document,
section), **COUNTED**, **COMPUTED** (script, instances), **ARGUED**, or
**GAP**. The gaps are numbered `GS-1 … GS-15` and listed together in §7, and four
new findings `N-1 … N-4` are marked where they occur (and are NOT the same
namespace as the label table's rows `S1 … S31` in §6.1).

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
   structural: a claim's evaluation point reaches only the *data* rows and
   the *column* key; it never reaches the random rows whose rank is the whole
   question. Computed on a faithful miniature with two group bits, at ten
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
   an honest witness only ever produces 768 of them per block whatever the
   shape. That moves a twelve-block run from `2^-97.8` to `2^-114.8` (§5.3).

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
equality tensor over the part's *data rows*, and the **trailing**
`log_cols` coordinates become the *column key*. Nothing about the point
reaches any other row.

> **Fact 1 (shape-free).** A claim's evaluation point influences the
> verifier's linear view in exactly two ways: through the data-row weights
> of its own data part(s), and through its column-weight key (hence which
> opening group it joins). It never appears in the commitment's non-data
> block. **PROVED HERE** from `build_claim:264-278` and
> `zpart_weights:860-900`, **given** the four assertions
> `zkp-core/src/pcs.rs:867, 876, 883, 894` that make `part_rows`
> (`protocol.rs:215-218`) exact (ruling G-3's invariant, re-cited here at
> this tree's line numbers).

Fact 1 is the whole answer to the brief's question (a), and §3.1 spells that
out.

### 1.5 One number this changes: the 125M endpoint and the receipt

`Shape::m125` declares `endpoint_rows = 37` and `endpoint_g.rs`'s own test
asserts `(len 524_288, data_rows 32, commitment_rows 37, enc_log 16)`; the
rung-G endpoint is `(4_096, 4, 9, 12)`. The pure-Python layout model still
carries the memo's superseded **29**
(`model_m125.json["shape"]["endpoint_rows"]`), which is finding S11b-F3's
old figure. Consequences [COUNTED, `shaped_counts.txt`]:

* the model's 125M receipt of **40,750,584 B** becomes **40,783,352 B** —
  `2 × 256 × (37 − 29) × 8 = 32,768` more bytes in the two endpoint
  openings — **which is exactly the figure measured after the S19-F1 repair**
  (`ZK60_BLOCK125M_S19F1_DISPOSITION.md` §6). Two independent counts now
  agree on it;
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
> as the protocol draws them. Then **on every run that is not discarded by
> one of the prover's own refusals**, for each PCS commitment separately:
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
| T2 | the eq-tensors never reach the non-data rows; pair weights are `(cm, cm·U)` (§2.2) | **verbatim, with one new case**: planes below the row width take `zpart_weights`' second branch. Pair weights unchanged. §1.3, §1.4 above. PROVED HERE |
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

**The answer, and it is a theorem rather than a measurement.** By Fact 1
(§1.4) a claim's point reaches only (i) its own data-row equality tensor and
(ii) its column key. The non-data block — the object whose rank is the good
event — contains, for claim `j` in group `g`, only the two entries
`λ_{g,j}·cm_j` and `λ_{g,j}·cm_j·U` at rows `(r_j, r_j+1)`, and zero
everywhere else among the non-data rows. `cm` depends on the slot's
extension challenges, not on `ρ`. **Therefore shared evaluation coordinates
cannot change the non-data block at all**, and the factorisation, the good
event and the bad set are exactly what they were. **PROVED HERE.**

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
   `2^-1280`, `2^-1024`, `2^-1792`.

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

[COMPUTED, `boundary_endpoint.txt`, 8 seeds, both shapes]

| boundary case | generators | non-data | rank on non-data | `k0` |
|---|---:|---:|---:|---:|
| honest | 6 | 6 | 6 | **0** |
| proximity pair `Fp`-dependent | 6 | 6 | 5 | **1** |
| `cm = 0` on one site | 6 | 6 | 4 | **2** |
| the two claims sharing one pair (`audit_claims` forbids) | 6 | 6 | 4 | **2** |
| a THIRD opening group appears | 8 | 6 | 6 | **2** |
| **one proximity ROW instead of a pair** (ruling M-1's own case) | 6 | 5 | 5 | **1** |
| the two claims merged into one group | 4 | 6 | 4 | 0 |

Three readings, in order of importance.

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

> **Finding N-2 (new). At the boundary the opening-group COUNT check is a
> privacy check.** `check_opening` refuses when the first-occurrence grouping
> has a different number of groups from the schedule (`protocol.rs:301-303`,
> reached from `boundary.rs:281-283` with `want_groups = spec.sites()`). With
> three groups instead of two there are 8 generators against 6 non-data rows,
> the full-rank implication cannot hold, and `k0` rises to 2. Nowhere is this
> recorded as a privacy-relevant check; it is documented as a schedule check.
> **GS-10** records that no test pins it as one.

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

| `A`, rung-G (122 claims in 36 groups) | generators | non-data | rank\|nd | `k0` |
|---|---:|---:|---:|---:|
| honest | 74 | 246 | 74 | **0** |
| proximity pair `Fp`-dependent | 74 | 246 | 74 | **0** |
| `cm = 0` in a SINGLETON group | 74 | 246 | 72 | **2** |
| `cm = 0` in a multi-member group | 74 | 246 | 74 | **0** |

The last two rows reproduce ruling G-4 at the shaped layout **and sharpen
it**: the zero-mask refusal is exactly necessary **where a group has one
member**, and harmless where it does not. How many singleton groups `A` has
at a shaped layout depends on the real column keys, which I did not derive;
the script uses a reconstruction (its largest group has 36 members, which is
an artefact of that reconstruction and not a counted fact — **GS-15**).
What *is* counted, from `sites_per_slot` and the declared
`Shape::a_groups` detail (`shaped_counts.txt`), is a rigorous lower bound:
**at least 15 of the 36 groups on `A` are singletons** — the eleven slots
that raise one claim in one group, plus the four claims of the two
**bilinear** slots, which the schedule puts in two groups of one each.

> **Finding N-4.** Each of the four claims of the repaired bilinear slots is
> **alone in its opening group** at both shaped layouts. By ruling G-4's own
> criterion the zero-mask-challenge refusal (`argument.rs:405`,
> `protocol.rs:246`) is therefore **exactly necessary for each of them**: set
> one of their `cm` to zero and the commitment discloses `n` field elements
> (`bilinear_miniature.txt` part C, `k0 = 2`; part D, disclosed 16 = 2·`n`).
> [COUNTED + COMPUTED.]

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
certifying minor nonsingular; 243–251 distinct opened columns inside the
256-pad budget; the pad block's exact rank equal to the distinct count.

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
   receipt bytes and close the largest part of **GS-3**.
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
`:691, 702, 703, 734`) and discards the attempt on a zero. Ruling R-6 prices
it by the **raw count of inversions**, and asks for a distinct-value
refinement before any 125M statement. The raw counts reproduce exactly from
the layout model:

| shape | u8 positions | exp | act | table rows | raw total | bits | R-6's figure |
|---|---:|---:|---:|---:|---:|---:|---:|
| toy | 61,440 | 2,048 | 512 | 768 | 64,768 | `2^-112.02` | `2^-112.0` |
| rung-G | 419,840 | 8,192 | 8,192 | 3,072 | **439,296** | `2^-109.26` | `2^-109.3` |
| 125M | 98,598,912 | 4,194,304 | 1,048,576 | 49,152 | **103,890,944** | `2^-101.37` | `2^-101.4` |
| 12 × 125M | | | | | 1,246,691,328 | `2^-97.78` | `2^-97.8` |

**The refinement, taken.** `α` is drawn *after* the `A` and `M` roots
(`protocol.rs:682-684`), so every denominator's argument is fixed before it,
and the bad event is `α` landing in the **set of distinct arguments**. For an
honest witness that set is:

* the byte-lookup family: `α − (v + γ·TAG_U8)` with `v` a byte — **≤ 256**
  values, whatever the number of positions;
* the exponential family: `α − (d + β·e + γ·TAG_EXP)` with `(d, e)` a row of
  the 256-entry exponential table — **≤ 256**;
* the activation family: `α − (i + β·a + γ·TAG_ACT)` with `(i, a)` a row of
  the 256-entry activation table — **≤ 256**;
* the three **table**-helper families add nothing new: their values are
  indexed `x % U8_LEN` (`argument.rs:870-872, 881-883`), so the P-3 lift
  repeats rather than extends them.

> **Finding N-3.** The distinct-argument set has at most **3 × 256 = 768**
> elements **at every shape**, so the input-dependent refusal is at most
> `768 / p² = 2^-118.42` per block and, with `L` independent `α`s,
> `12 × 768 / p² = 2^-114.83` for a twelve-block 125M run. Against R-6's raw
> figures that is **17.0 bits** at 125M, **9.2** at rung-G and **6.4** at the
> toy. It removes R-6's stated worry that the term "sits a third of a bit
> from the run's soundness level": at `2^-114.8` it is 17 bits below it.
> **PROVED HERE** (the argument) and **COUNTED** (the arithmetic).
>
> The conditioning is the right one: this is the *prover's own* refusal, run
> on the witness it is proving, and an honest witness's lookup arguments are
> table rows by definition of the LogUp statement. A dishonest prover can
> make an argument that is not a table row, but then the LogUp identity fails
> and the receipt is refused for a different reason; that is soundness, not
> this term. **GS-12** records that I did not re-derive the byte-range
> obligation on every one of the `u8` lookup expressions.

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

---

## 6. The table of every step, and what to attack first

### 6.1 Label table

| # | Statement | Label |
|---|---|---|
| S1 | full row rank of the non-data block ⇒ `k0 = 0` | REDUCED to `ZK60_GENERIC_RANK_LEMMA.md` §1.3 (shape-free) |
| S2 | a claim's point reaches only its data rows and its column key (Fact 1) | **PROVED HERE** §1.4, GIVEN the four asserts `pcs.rs:867, 876, 883, 894` |
| S3 | pair weights are `(cm, cm·U)` at every shape, including planes below the row width | **PROVED HERE** §1.3 from `argument.rs:264-278`, `pcs.rs:860-900`; COMPUTED in every miniature instance |
| S4 | the repaired bilinear slots' shared coordinates leave the non-data block unchanged | **PROVED HERE** §3.1 (corollary of S2); COMPUTED `bilinear_miniature.py`, 10 seeds + 9 regimes + brute force |
| S5 | the pre-repair and repaired schedules give the same linear view | COMPUTED `bilinear_miniature.py` part C, 5 seeds |
| S6 | the pad-zero term raises no claim and allocates no pair | **PROVED HERE** §3.2 from `argument.rs:527-529, 588-600, 690-746` |
| S7 | ruling P-2's zero-off-support public weights are not the PCS `cw` | **PROVED HERE** §3.3 |
| S8 | `cw ≠ 0` always | REDUCED to `ZK60_TERMINAL_SURJECTION_REVIEW.md` §1.4 (shape-free) |
| S9 | a known-zero data region can only lower the disclosed dimension (Fact 2) | **PROVED HERE** §3.4; COMPUTED `bilinear_miniature.py` §E with a separating control |
| S10 | the LogUp sum claim is constructible and alone in its group at both shaped layouts | **PROVED HERE** §3.5; COUNTED `shaped_counts.txt` (1 key with the lift, 3 without) |
| S11 | the sum claim's pair coefficients are `(1, U)` at both shaped layouts | **PROVED HERE** §3.5 from `protocol.rs:167-178` and the lifted `Dom::Tab` |
| S12 | `H`'s two groups share the zero-sum pair at every shape; rank them as one component | REDUCED to `ZK60_GENERIC_RANK_LEMMA.md` §3.3 (change R-5); COMPUTED at shaped counts |
| S13 | the u-row term is exactly the public LogUp identity at 125M | **GAP GS-1** for the *measurement*; the argument is REDUCED (S10–S12). MEASURED at rung-G only |
| S14 | the endpoint's spare row is the slack that absorbs a degenerate proximity draw | **PROVED HERE** §3.5; COMPUTED `boundary_endpoint.py`, 8 seeds, both shapes |
| S15 | the boundary has zero slack; its proximity refusal is exactly necessary (Finding N-1) | **PROVED HERE** (rank argument) + COMPUTED, 8 seeds, both shapes |
| S16 | the boundary's opening-group count check is a privacy check (Finding N-2) | **PROVED HERE** + COMPUTED; **GS-10** for the missing test |
| S17 | the zero-mask refusal is exactly necessary where a group is a singleton; **at least 15 of 36** `A` groups are, including all four bilinear claims (Finding N-4) | COMPUTED `boundary_endpoint.py` + COUNTED `shaped_counts.txt` |
| S18 | H-pad / M-cols at both shaped `(n, nn, Q)`, every column set | **PROVED HERE** §4.C with exact determinants; conditional on `q_pad == num_col_checks == 256` |
| S19 | the reduction is right at `n ≠ Q` | COMPUTED without the reduction, `bilinear_miniature.py` part D′; the *general* reduction at `n ≠ Q` is **GAP GS-5** |
| S20 | `uncovered_s = 0` and the mask functionals lie in the round span, all 23 slots of both shapes | COMPUTED `channels_shaped.py`, 5 `ρ` regimes, with the `d`-values control; the proof is REDUCED to the toy §3.5 |
| S21 | the individual claim values add nothing (Step 7 / terminal surjection) | REDUCED to `ZK60_TERMINAL_SURJECTION_REVIEW.md` §1.4; COMPUTED at `m = 1` and `m = 2` in the brute force |
| S22 | refusal probabilities per block and per run | COUNTED §5.1; reproduces ruling R-6's `2^-58.8` |
| S23 | the input-dependent refusal is `≤ 2^-118.42` per block, `2^-114.83` per run | **PROVED HERE** + COUNTED §5.3 (Finding N-3) |
| S24 | the Schwartz–Zippel backstop at both shapes and for a run | COUNTED §5.4 |
| S25 | 125M endpoint rows 37, prox pair (34,35), receipt 40,783,352 B | COUNTED §1.5; matches the measured receipt |
| S26 | `audit_claims` exclusivity on a shaped claim schedule | RELIES ON the code; MEASURED at rung-G by the run gate on two captures; **GS-4** at 125M |
| S27 | the refusal replay draws the same challenges the PCS will | RELIES ON reading; **GS-2**, no Rust test, and the shaped layout has more to get wrong |
| S28 | non-data rows uniform in the new commitments | RELIES ON `endpoint_g.rs:229-232`, `boundary.rs:322-325`; not re-derived |
| S29 | the joint law across commitments | **GAP** — U-3(b) / G-R4, untouched |
| S30 | the non-linear channel | **GAP** — out of scope; the shaped slots reach degree 5, so `poly_s` is worse than the toy's degree 4 |
| S31 | the hash layer | **GAP** — out of scope |

### 6.2 What the checker should attack first — my own ranking

1. **Fact 1 (§1.4), because everything in §3.1 is a corollary of it.** If
   there is any path by which a claim's evaluation point reaches a non-data
   row — a data part whose slice straddles into the site rows, a plane whose
   `a_off` is not row-aligned so that `c0 ≠ 0` and the mask part's key is not
   what I say, a fourth branch of `zpart_weights` — then the repaired
   bilinear slots become a real question and this memo's headline is wrong.
   Attack `part_rows` (`protocol.rs:215-218`) and the four asserts. I did
   read the `a_off` / `h_off` cursors (`layout.rs:1037-1042, 1052-1057`) and
   they are row-aligned, so `c0 = 0`; attack that reading.
2. **Finding N-1's slack argument (§3.6).** I claim the boundary's zero slack
   makes the proximity refusal necessary and that `A`'s slack makes it
   unnecessary. Both come from one synthetic model with uniformly drawn
   data-row weights. Attack the claim that uniform data weights are the worst
   case for `k0`, and attack the modelling of the group vectors (I put each
   group's members at their own pairs with independent `λ`, which is
   `zk_rhos`, but I did not model a group whose members' *data* weights are
   linearly dependent — which is exactly what the shared coordinates
   produce).
3. **Finding N-3's conditioning (§5.3).** I price the input-dependent refusal
   over the *honest* witness's distinct arguments. Attack whether every `u8`
   lookup expression is really range-proved to a byte *before* its
   denominator is inverted, and whether `exp_deltas` and `act_indices` are
   really table rows for every admissible witness at a padded shape — the
   padded positions are where I would look.
4. **Whether `2(G+1)` is the right generator count at a boundary.** I take
   `G = sites = 2` from the declared count. If a run ever opens a boundary
   with a claim the schedule does not declare, or with `sites > 2`, the slack
   goes negative and `k0 > 0` follows immediately.
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
| **GS-1** | **Nothing has ever been measured at 125M.** No capture, no disclosure figure, no rank, no certifying minor. Lemma S at 125M rests on structure + counts only, and the run disposition's own table says "nothing" in that column for every row. |
| **GS-2** | The refusal replay order is still pinned by no Rust test (the toy's condition O-1), and a shaped layout adds two things to get wrong: 36 groups on `A`, and a boundary whose `want_groups` is derived separately in `boundary.rs`. |
| **GS-3** | **`lkv = 2` has never been exercised on real receipt bytes.** rung-G has `lkv = 1`; 125M has `lkv = 2` and no capture. §4.A's miniature is the only place two group bits have been computed at all. |
| **GS-4** | `audit_claims` exclusivity at 125M is enforced but never observed. At rung-G the run gate observed it on two captures. |
| **GS-5** | The tool's **reduction** `disclosed = n·k0 + u-term` is not re-derived at `n ≠ Q`. I computed *without* it at `n ≠ Q` on a miniature (part D′); the general derivation, including why the u-term enters as `u_dim` and not `n·u_dim` when `n = 16,384`, is owed. |
| **GS-6** | The joint statement across commitments (U-3(b) / G-R4) is untouched, and the boundary is where three commitments hold the same plane. Nothing here licenses adding the per-commitment figures. |
| **GS-7** | A boundary's site-0 claim value is published one stage **before** the opening whose `λ`s blind it. Harmless at fixed challenges; it belongs to the Fiat–Shamir lift for a run (gap G-R5), which is unwritten. |
| **GS-8** | ~~`a_off` unread.~~ **CLOSED while drafting**: `layout.rs:1037-1042` and `:1052-1057` push every plane offset at a row boundary, so `c0 = 0` at every shape and the sub-row-plane case of §1.3 is settled. Kept in the list so the numbering does not move. |
| **GS-9** | The `ζ` count at rung-G (8) is an upper bound: the project's pad table classifies only 125M's planes, so `Dom::T`, `Dom::F` and `Dom::Kv` are unclassified at the rung. Worth `< 1` bit. |
| **GS-10** | No test pins the opening-group **count** check as a privacy check at the boundary, where it is one (Finding N-2). |
| **GS-11** | `M-q` and `M-prox` (`zk.rs:452-457`) are taken from the toy lemma, not re-derived. `M`'s geometry is shape-independent, so this is a carry-over, not a new gap — but it is still a RELIES ON. |
| **GS-12** | Finding N-3 assumes every `u8` lookup argument is a byte and every exp/act argument a table row for an honest witness at a **padded** shape. I did not re-derive that plane by plane. |
| **GS-13** | The non-linear channel is worse at a shaped layout than at the toy: slot degrees reach **5** (against the toy's 4), the two bilinear closures now carry a public `eq` factor, and eight slots carry a support indicator. `ZK60_JOINT_LAW_COMPOSITION_RUN.md`'s gap G-R2 (the 23 closures re-read) is untouched here. |
| **GS-14** | **A linear-view argument cannot see a completeness defect of any kind**, on any witness. S19-F1 proved that the hard way. Nothing in this memo, and nothing any disclosure gate can compute from a capture, would have caught it. |
| **GS-15** | `boundary_endpoint.py`'s `A` and `H` cases use a **reconstruction** of the group-size distribution from the declared per-slot group counts, not the real column keys. The rank verdicts do not depend on it (every group has a member with its own pair whatever the split), but any *count* of singleton groups taken from that script does. The rigorous lower bound is 15 of 36. |

---

## 8. What this is not

1. **Not a privacy property and not a privacy acceptance.** It is a statement
   about the rank of an explicitly stated linear model, per commitment, at
   two layouts.
2. **Not a discharge of gap G-R1.** G-R1 asks for (H1) at a shaped layout.
   This memo supplies the structure and the counts, and closes the two
   channels the toy proved identically (§4.C). It does **not** supply the
   certificate at 125M, where nothing has been computed (GS-1), and it does
   not supply the `lkv = 2` evidence on real bytes (GS-3). **My own reading
   is that G-R1 should be narrowed, not closed**: at rung-G it is down to
   GS-2, GS-5 and the gate's two-challenge-vector limit; at 125M it is still
   open in full.
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
   written by one delegated agent in one sitting and has not yet been
   attacked.
