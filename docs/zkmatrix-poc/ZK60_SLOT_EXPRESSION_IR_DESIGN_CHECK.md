# ZK60 — adversarial check of the slot expression IR design memo

**INDEPENDENT ADVERSARIAL CHECK of
`docs/zkmatrix-poc/ZK60_SLOT_EXPRESSION_IR_DESIGN.md` (drafter lane,
commits `b94f3b3`..`7c09272`).** Written 2026-09-21 by the checker lane.
It changes no production code and makes no speed claim. The rule this
check worked under: assume the memo is wrong until the figure has been
re-derived here, by a different method.

Code read (read-only) at lane `zk60-private-block-125m` tip `226f3b2`,
worktree `/home/victor/wt-zk60-block125m`:
`hashline/src/private_block/{argument,protocol,layout,shape,pad,timing}.rs`,
`hashline/src/zk.rs`, `zkp-core/src/{sumcheck,field,rng,transcript}.rs`.
Checker evidence: `results/zk60_slot_ir_check/`
(`slot_cost_check.py` + `.txt` + `.json`, `measured_vs_counted.py` + `.txt`).
The drafter's `results/zk60_slot_ir/slot_ir_inventory.py` was **not run and
not read as a source**; it was consulted only after the fact, to diff.

**Labels.** **[MEASURED]** = quoted from a committed log, with its path.
**[COUNTED]** = produced here by this check's own counter.
**[MODEL]** = an estimate. No time prediction appears as a result.

---

## 0. Verdict table

| headline claim | verdict | memo | this check |
|---|---|--:|--:|
| **baseline** "today" multiplication count | **CONFIRMED, exactly** | 16,478,006,793 (125M) / 746,012,745 (W14) | **identical, component by component** |
| **(a)** base-field operands in round 0 | **OVERSTATED, and mis-specified for 12 tables** | 23.4% (20.8% of baseline) | **16.8% (14.4% of baseline)**; 131 base tables, not 143 |
| **(b)** sharing, hoisting, typed coefficients | **CONFIRMED and UNDERSTATED** | 10.9% | **14.2%** |
| **(c)** finite differences per sub-expression | **VALID, and UNDERSTATED as a count; additions not priced** | 38.7% (26.4% of baseline) | **43.8% (31.2% of baseline)**; 52.4%/44.9%/29.9% combined once additions are priced |
| **combined** | **CONFIRMED** | 58.2% / 59.6% | **59.9% / 59.9%** |
| **"nothing sent changes"** | **CONFIRMED for the three levers**; two unnamed hazards | — | see §6 |
| **identical structure W14 vs 125M** | **CONFIRMED** (three non-cube differences, all harmless) | — | see §7 |
| **the degree finding** | **CONFIRMED**, scope narrower than the headline | "four slots" | **two slots at the two shapes the memo is about** |
| **Option A** | **SOUND but mis-specified in three ways** | "~20 lines, verbatim, 13+12 sites" | **~+128/−89 lines; `Sync` locks the GPU out; 18+18 sites** |
| **GPU memory** | **ARITHMETIC CONFIRMED; the conclusion is not** | "both fit an 8 GB card" | true for the round loop alone; the commitments it also needs do not |

Twenty findings, IR-C1 … IR-C20, in §12.

---

## 1. Method: how this check counted

The drafter's baseline is a `.mul(` **token** count over `argument.rs` plus
hand-declared adjustments — a definition, as their own §3.5 concedes. This
check does not reuse it. Instead
(`results/zk60_slot_ir_check/slot_cost_check.py`):

* **every one of the 23 closures is transliterated into Python** from
  `argument.rs`'s `define` arms, including the three shared helpers
  `limbs`, `helper_sum` and `PadTerm::eval`;
* **each value is a univariate polynomial in the round variable `t` with
  exact `F_{p^2}` coefficients** (`p = 2^64 − 2^32 + 1`, `u² = 7`). A table
  contributes `v0 + t (v1 − v0)`, which is exactly what `sumcheck::prove`'s
  `cur[t] = cur[t] + dif[t]` walk computes (`sumcheck.rs:76-89`);
* the multiplication count is therefore an **execution** count, not a token
  count, and every intermediate's degree is the **true** degree after
  cancellation;
* **base-field-ness is read off the coefficients**, so the round-0
  classification is computed and never declared. That is what found IR-C1.

Shape parameters were derived from `shape.rs` independently (and
cross-checked by a second reader against `layout.rs`/`pad.rs`): both shapes
give `limbs_norm 4` with a full top byte (C-6), `limbs_sigma_s 3`,
`limbs_p 2`, `lkv 2`, helpers `L 1 / D 17 / Q 7 / Kv 6 / S 8 / F 5`,
lookups `2/34/13/12/15/9`, pad set `{Ht, L, D, Q, S, Tab}`.

The cost unit is the memo's: `Fp2::mul` = 5 `Fp` muls, `mul_base` = 2,
base × base = 1. **Verified against `zkp-core/src/field.rs:158-166`**:
`mul` is schoolbook `ac, bd, ad, bc` plus `bd.mul(Fp(NONRESIDUE))` — five
`Fp::mul` calls as written, not Karatsuba's three (the non-residue 7 could
be a shift-add, which the memo's §3.5 already flags); `mul_base` is two.
**And `sumcheck::prove` evaluates `poly` at `degree + 1` points per pair
index** (`acc[0] = poly(&cur)` then `for d in 1..=degree`), with no reuse of
`s(0) + s(1) = claim` — see IR-C19.

---

## 2. The baseline: exact

| component | memo, 125M | this check | memo, W14 | this check |
|---|--:|--:|--:|--:|
| round loop | 15,282,222,978 | **15,282,222,978** | 691,163,010 | **691,163,010** |
| table fold | 1,096,105,095 | **1,096,105,095** | 51,531,975 | **51,531,975** |
| claimed sum | 99,678,720 | **99,678,720** | 3,317,760 | **3,317,760** |
| **total** | **16,478,006,793** | **16,478,006,793** | **746,012,745** | **746,012,745** |

Two independent methods, same digits. Every per-slot `mul/eval` in the
memo's §1 table is also reproduced exactly, including the four the brief
asked for: slot 17 = 75 `Fp2::mul` + 15 `mul_base`, slot 14 = 152 + 34,
slot 08 = 2, slot 05 = 1. The pair-index arithmetic (`2^n − 1` summed over
rounds), the fold (`k` muls per pair index per round) and the claimed sum
(a cube walk for the **12 private slots only** — `SLOT_KINDS` at
`layout.rs:885`, host and standalone slots publish `c·mask.total()` at
`argument.rs:522-526`) are all as stated.

Two details the token count got right and a structural reader might miss,
both confirmed here by execution: `PadTerm::eval` still costs one
`Fp2::mul` (`self.mu.mul(acc)`) at slots 02/16/18 where there is **no** pad
group at all; and `Gate::at` returning `Fp2::ONE` does not stop
`m.mul(g).mul(c)` from paying for the multiply by one.

**IR-C3: the memo's baseline survives an independent re-derivation
exactly. This is the strongest thing in the memo and it should be said so.**

### 2.1 But the baseline does not predict the measurement

[MEASURED, `/home/victor/wt-zk60-block125m/results/zk60_block125m_lane/q28-m125-final-dense.log`
lines 9-97, one 17.401 s 125M prove] against [COUNTED] round loop + fold:

| slot | measured s | measured share | counted share | implied 1e9 Fp/s |
|---|--:|--:|--:|--:|
| 17 `SC_SZC` | 3.054 | 46.3% | **66.1%** | 3.54 |
| 14 `SC_DZC` | 1.642 | 24.9% | **16.9%** | 1.68 |
| 18 `SC_FZC` | 0.659 | 10.0% | 7.1% | 1.77 |
| 15 `SC_QZC` | 0.544 | 8.2% | 5.1% | 1.52 |
| 16 `SC_KVZC` | 0.258 | 3.9% | **0.8%** | 0.53 |
| 04 `SC_RS` | 0.203 | 3.1% | **3.2%** | 2.58 |
| 19 `SC_TAB` | 0.035 | 0.5% | 0.04% | 0.18 |

If the memo's unit were the cost, the last column would be one number. Over
the six slots above 0.2 s it spans **a factor of 6.7**; over the twelve
above 0.005 s, **a factor of 20**. The counted 17:14 weight ratio is
**3.92** against a measured **1.86** — the model over-weights the biggest
slot against the second by 2.1×. And the model **inverts** slots 04 and 16.

I tried to repair it by adding the table-count-proportional work the unit
omits — per pair index and round, `2k` word reads, `k` subtractions, the
`degree·k` additions of the `cur[t] += dif[t]` walk, and the fold's `k`
read-modify-writes. Best fit over the six big slots moves the worst share
error from 79% to 78%. **It does not repair it**, so the missing cost is
not only traffic. Run-to-run spread on the two committed samples is +1.7%
to +14.0% per slot, far too small to explain a 2.1× ratio error.

**IR-C9: the count model does not reproduce the measured per-slot shares,
misorders two of the six big slots, and over-weights slot 17 against slot
14 by 2.1×. A 58–60% reduction in multiplications is defensible only as an
aggregate count; it may not be carried to any slot's time, and the memo's
"65.3% at slot 14 and 58.8% at slot 17" invites exactly that reading.**

---

## 3. Lever (c), finite differences — valid, and the largest

**Is it valid for every node it is applied to?** Yes, under one condition
the memo states only implicitly and must state explicitly.

For a fixed pair index, every table's contribution along `t` is
`v0 + t(v1 − v0)`: a polynomial of degree **at most** 1, at **every** cube
point. Every node is built from tables, challenges (degree 0) and public
base constants (degree 0) by `+`, `−` and `×`, so a node's degree is
bounded above by the **structural** bound — the sum of its factors'
degrees for a product, the max for a sum. That bound holds pointwise. The
brief's specific worries all check out:

* the **`eq` factor** is an ordinary folded table: degree ≤ 1 (often 0,
  because `eq_cube` repeats each entry over the trailing variables — lower,
  never higher);
* the **support indicator / `pad_on` terms**: `B::supp` pushes a
  `Tab::Pub` of 0/1 values (`argument.rs:770-778`), folded like any table,
  degree ≤ 1; `PadTerm::eval`'s `(1 − supp)·Σ ζ^j plane_j` is degree 2;
* the **`group_eq` gate** of slots 08/09 is `Tab::Eq { start: 0 }`, a table,
  degree ≤ 1;
* **LogUp helper products** `h·d1·d2 − d1 − d2`: each denominator is
  `alpha − (cst + c·plane)` with `c` a base coefficient, degree 1, so the
  relation is degree 3;
* **anything multiplied by a challenge-dependent table**: a challenge is
  degree 0 in `t`; a challenge-weighted *table* is still a table.

**The condition**: the IR's `Node.degree` must be the structural bound
(`Node { degree: /* computed, asserted against a walk of the body */ }` in
the memo's §2.1 is the right thing). An *observed* or *generic* degree
would be unsound — a node can cancel at some cube points and not others,
and finite differences from too few points would then be wrong at exactly
the points that matter. The memo should say "walk of the body", not "the
true degree", in the one place (§1.4) where it says the IR "can compute the
true degree at all".

**The saving, re-derived.** Each multiplication is executed
`deg(result) + 1` times instead of `degree + 1`. Slot 17's 60 optimised
multiplications produce results of degree 1 (×40), 2 (×20), 3 (×20),
4 (×1), 5 (×1) — so most of the work runs at 2–4 points under a slot
degree of 5. [COUNTED] (c) removes **43.8%** of the (a)+(b) form at 125M
(memo: 38.7%): understated by the memo, not overstated.

**IR-C7 — the additions are not free.** Extending a node of degree `δ` to
`d + 1` points costs `δ(d − δ)` `Fp2` additions per pair index. [COUNTED]
at 125M that is **2,472,766,117 `Fp2` additions = 4,945,532,234 `Fp`
additions per proof**, against 6,609,568,274 `Fp` multiplications in the
(c) form. With an `Fp` addition priced at a stated fraction of an `Fp`
multiplication:

| Fp add priced at | combined saving [COUNTED + MODEL] |
|---|--:|
| 0 (the memo) | 59.9% |
| 0.25 | **52.4%** |
| 0.5 | **44.9%** |
| 1.0 | **29.9%** |

This is an **upper bound on the penalty**: (c) also *shortens* the
`cur[t] += dif[t]` walk, because a table feeding only low-degree nodes is
needed at fewer points, and I did not model that credit. The honest
statement is a band, and the memo gives a point.

---

## 4. Lever (a) — overstated, and wrong for twelve tables

**IR-C1 (the most important finding). Twelve of the 143 "wholly
base-field" tables are extension-valued. The correct count is 131 of 229,
at both shapes.**

`priv_table` (`argument.rs:204-269`) builds a plane's cube as
`out[x] += eqf[z] · v`, where `eqf = eq_table_msb(&fixed)` is the tensor of
the plane's **`Coord::Fixed`** coordinates — which are challenges. The
`simple` fast path (`:244`) requires `eqf.len() == 1`, i.e. **no fixed
coordinate at all**. So every plane read at a fixed claim point is
challenge-weighted and its words have a non-zero imaginary part. Eleven
tables are of that kind:

* the seven matmuls' committed plane — `coords = fixed(&pts.r_q) ++ rho(..)`
  at `argument.rs:1256-1258` and `fixed(&r_row) ++ rho(..)` at `:1388-1390`;
* the four bilinear factors of slots 08 and 09 — `cq`, `ck` at `:1330-1341`
  and `cp`, `cv` at `:1357-1367`, each with `fixed(&r_t)` / `fixed(&r_hj)` /
  `fixed(&r_j)` / `fixed(&r_i)` segments.

The twelfth is the **U8 value column** of `SC_TAB`:
`table_values_u8_at(len, g_u8)` is `k(i % 256) + g_u8` (`argument.rs:1046-1048`)
and `g_u8` is a challenge tag, so the column is extension-valued exactly as
the exp and activation columns are. The memo lists it among the ten
base-field public tables (§1.2).

The memo's §2.3(i) contradicts itself on the same line —
`TableRef { … field: Base, label: "A_Y at (r_q fixed, rho)" }` — and its
"Cost per evaluation point: … it is 20% of its round-loop cost [COUNTED]"
for slot 05 is, re-derived here, **0%**. Lever (a) buys the seven matmuls
and the two bilinear slots **nothing**.

The MEASURED census cannot see this: it covered slots 17, 14, 18, 15 and
04, and **none of those five reads a plane at a fixed coordinate**. The
memo generalised a five-slot measurement to all 23 and the generalisation
fails on exactly the nine slots the census did not touch.

**Why it matters more than the number.** In aggregate the error is tiny —
the nine slots have cubes of 2^8–2^11 and the fold difference is exactly
**43,776 `Fp`** (19,200 for the eleven planes, 24,576 for the U8 column),
which is how I confirmed the reclassification against the memo's own fold
figure. But **stage 5 of the migration is "`priv_table` hands out `Fp`
cubes for the wholly base-field tables"**. Implemented against the memo's
list, those nine slots would silently lose the imaginary part of a table
and the prover would compute a different field element — a byte-moving
correctness bug inside a migration whose whole claim is that it moves no
byte. And, per IR-C15, no `cargo test` gate pins private-block proof
content, so it would not go red.

**The saving, re-derived.** Round 0 is `2^{n-1}` of the `2^n − 1` pair
indices — correct, and it is the only round, because the fold challenge is
in the extension (`sumcheck.rs:118`) so nothing is base-field again. Within
round 0, the narrowing is *not* "5 → 2 or 5 → 1" across the board, because
most products carry a challenge or an `eq`:

| slot (after (b)) | muls, 0 base operands | 1 base | 2 base | round-0 cost |
|---|--:|--:|--:|--:|
| 17 `SC_SZC` | 30 | 25 | 5 | **66%** of full |
| 14 `SC_DZC` | 55 | 51 | 4 | **66%** of full |
| 05 `SC_QMM` | 1 | 0 | 0 | **100%** of full |

So (a) removes about a third of round 0, which is half the pair indices:
[COUNTED] **16.8% of the (b) form, 14.4% of the baseline**, against the
memo's 23.4% / 20.8%.

**IR-C5: (a) is the one lever the memo overstates. Re-derived it is worth
about 70% of the claim, and it is the lever with the correctness trap.**

Two things the memo gets right here and that this check confirms: the
per-product accounting *is* `(k−1)` base muls plus one `mul_base`-like step
when the extension factor arrives last (the counter reproduces it by
execution, not by declaration); and the base-field-at-round-1 argument
quoted from the ledger — a difference of two base words is base and the
`cur[t] += dif[t]` walk preserves it — is exactly right.

---

## 5. Lever (b) — confirmed, and understated

Both parts are value-preserving in a commutative ring and this check found
no exception:

* **hoisting the support gate**: `Σ_i μ_i · g · c_i = g · Σ_i μ_i c_i` is
  distributivity. `g` is one field element at each evaluation point,
  whatever the pad boundary does — at a cube point it is 0 or 1, at an
  interpolated point it is arbitrary, and distributivity does not care. It
  also leaves the degree structure unchanged (`deg(g) + max_i deg(c_i)`
  either way), so it does not interact with (c). **Valid.** 22 muls become
  12 at slot 14, 10 become 6 at slot 17;
* **typed coefficients**: every `k(...)`, `pow256(k)`, `2^SH_*` is
  `Fp2::from_i64` of a public integer, so `x.mul(k(c))` (5) is
  `x.mul_base(c)` (2), and `pow256(0)` is a runtime `Fp2::ONE` costing a
  full multiply by one — the memo's own small finding in §3.5, confirmed by
  execution: `limbs` (`argument.rs:825-827`) folds from `k = 0` while the
  hand-written `l2`/`l3` in the same file skip it. 31 such multiplications
  per evaluation at slot 14 and 10 at slot 17 — both reproduced exactly;
* **shared sub-expressions**: the closures already share `delta`, `dl`,
  `a1`, the `at(p)` reads. Beyond those I could find only two more by
  reading — `k_den·d` is recomputed in `c0` and `c1`, `k_den·dm` in `c6`
  and `c7` (`argument.rs:1449-1457`).

[COUNTED] (b) removes **14.2% of the baseline at 125M** (memo: 10.9%) and
**15.0% at rung-W14** (memo: 11.9%). **The memo understates its own lever.**

**IR-C11 (wording).** "the IR shares all of them by construction, because a
node is evaluated once by identity" overstates the grammar. `NodeBody` has
no hash-consing or CSE pass; a sub-expression is shared exactly when the
hand-written builder gives it one `NodeId` — which is what a Rust `let`
already does. The IR makes sharing **visible and checkable**, not
automatic. That is still worth having; it is not what the sentence says.

---

## 6. "Nothing sent changes"

**Confirmed for the three levers.** (a) is `Fp2::mul((a,0),(c,d)) = (ac,ad)`
— omitted multiplications by zero. (b) is distributivity and substitution
of equals. (c) is exact interpolation: the field's characteristic is a
64-bit prime and `d ≤ 5`, so the binomial coefficients are units, and the
integer forward-difference table needs no division at all. The order of
summation cannot matter because `Fp::add` (`field.rs:40-44`) reduces to the
canonical representative, so rayon's reduce tree is bit-irrelevant — the
comment at `sumcheck.rs:64-66` is correct and the memo inherits it
correctly.

I checked the five places a round polynomial's **representation** could
move and found all five untouched: the evaluation-point set stays
`0..=degree`; the message stays in value form; the declared degree is
explicitly excluded; the CFS mask is added **outside** the sumcheck, by
`Transcript::absorb_fp2` intercepting the `b"sc-round"` label and calling
`CfsMasker::mask_round` (`transcript.rs:82-99`, `sumcheck.rs:284-294`), so
the IR describing `f` and never `f + c·g` is right; the extension round
calls the same `poly` `degree + 1` times on the host and is not a hot path.

Two hazards the memo does not name, both landing in stages 3–4:

**IR-C16 (missing).** `CfsMasker::mask_round` derives the round index as
`let j = self.challenges.len()` (`sumcheck.rs:286`), fed by
`note_challenge` from `Transcript::challenge_fp2`. So the invariant an
implementor must preserve is not "absorb then draw" but **exactly one
`b"sc-round"` absorb and exactly one `challenge_fp2()` per round, while the
masker is installed**. An extra absorb creates a phantom masked round; an
extra draw shifts `j` and silently corrupts every later mask. §2.2 says the
mask "stays outside the IR" without saying what that costs the implementor.

**IR-C17 (missing, privacy-adjacent).** `sumcheck.rs:112` pushes the
**unmasked** `sums` into `ProverOutput.proof.rounds`; the masked ones exist
only inside the transcript and return via `take_masker()`. `masked_prove`
discards `out.proof` and nothing in the type system says why. A new public
`prove_rounds` entry point widens the surface for a future caller to put
the honest, unmasked round polynomials in a receipt. One doc line on
`ProverOutput` would close it.

---

## 7. Identical structure, rung-W14 vs 125M — confirmed

Re-derived from `shape.rs`/`layout.rs`/`pad.rs`, not from the memo's table.
The 229-table census is **identical row for row**: 25 `Eq`, 2 `GroupEq`,
19 `Pub`, 9 support indicators, 122 `A`, 50 `H`, 2 endpoint. So are the
degrees `[4,4,3,4,4,2,2,2,3,3,2,2,2,2,5,5,4,5,4,3,2,2,2]`, the extension
rounds (25 total), `slot_terms`, the helper and lookup counts per domain,
the pad-on set (slots 03, 14, 15, 17, 19 at both), the zero-rule plane
**lists** (not merely lengths), `a_groups` 36, `lkv` 2, C-6 true at both,
the `Dom::Tab` lift 8→14, and the per-evaluation multiplication counts.
Main rounds 292 vs 336; extension rounds 25 at both.

Three differences that are not cube size, all of which leave the slot
structure alone:

1. `endpoint_rows` 9 vs 37 — the endpoint commits `t_pad·d_pad` at
   `endpoint_log_n = 14`, so 4+5 vs 32+5 rows. Same table kind, same count;
2. `per_row` in `SC_SZC` 64 vs 512 (`argument.rs:1615`) — a public scalar
   folded into the hosted weight, and the tiling repetition of the lifted
   `supp_Ht` inside the `Dom::S` cube. It is the only `supp` call with
   `rep > 1` at either shape;
3. closed-form indicator bit **positions** (`pad.rs:160-193`): `supp_Ht`
   is `1 − b6·b7` vs `1 − b9·b10`, `supp_S` `1 − b12·b13` vs `1 − b18·b19`.
   Same algebraic form.

**IR-C12a (wording, worth one sentence in the memo).** Two of the
coincidences are calibration, not structure: `wrho_s = 18` at both comes
from `clog2(64) + 12` against `clog2(512) + 9` — the `f_e` values
**differ** (12 vs 9) and were chosen to land on the same window. Change
`f_e` at rung-W14 and `limbs_sigma_s` moves, which moves the `A` and `H`
plane lists and the slot 17 table count. Likewise `a_groups = 36` holds
because `9·t_pad ≤ 2^14` at both, not by construction. The memo's "rung-W14
is the shape whose receipt must not move under shared-file speed work" is
sound; "the SAME slot structure" is true today and is not a theorem.

---

## 8. The degree finding — confirmed, narrower than the headline

Verified by symbolic expansion with exact field arithmetic (the true
degree after cancellation, at a random point), not by a structural walk:

| slot | IR max product degree | declared | at 125M | at rung-W14 |
|---|--:|--:|---|---|
| 14 `SC_DZC` | **4** | 5 | gap | gap |
| 15 `SC_QZC` | **4** | 5 | gap | gap |
| 16 `SC_KVZC` | 4 | **4** | **no gap** (`Dom::Kv` exact) | **no gap** |
| 18 `SC_FZC` | 4 | **4** | **no gap** (`Dom::F` exact) | **no gap** |
| 17 `SC_SZC` | **5** | 5 | attained | attained |

The mechanism is as the memo says: `Shape::slots` adds one to
`BASE_DEGREE[s]` for each `INDICATOR_SLOT_DOMAIN` slot whose domain pads
(`shape.rs:1178, 1187`), and for the four LogUp hosts the base degree was
already set by the **ungated** LogUp arm `eq·h·d1·d2` = 4, while the gate
lifts only the clause arm from 3 to 4. Slot 17 reaches 5 through
`eq(τ)·supp_S·μ1·zsel·(mx + 127 − mask·(s8 + 127))` — the memo names the
right term.

**IR-C10 (wording/scope).** The §1.4 heading and §8.2 risk 4 say "four
slots"; the table's own footnotes say slots 16 and 18 only show the gap
where `Dom::Kv` / `Dom::F` pad, which is rung, rung-G and rung-K4. At the
two shapes this memo is about — 125M and rung-W14 — **it is two slots**.

**What it costs today** [COUNTED], at 125M:

* **bytes**: slots 14 and 15 each have 19 main + 1 extension rounds, each
  sending one extra `Fp2` = 20 × 16 B = 320 B; **640 B of 40,783,352 B,
  0.0016% of the receipt**;
* **evaluations**: dropping the declared degree from 5 to 4 removes one of
  six evaluation points from each slot's round loop — 434,109,636 +
  128,974,602 = **563,084,238 `Fp`, 3.4% of the baseline**;
* **mask budget**: `L = (main + ext)·degree + 2` falls from 102 to 82 for
  both. Ruling **C-4** is `L + MASK_Q ≤ MASK_MSG`, i.e. `L + 256 ≤ 512`,
  and the binding slot is 17 with `L = 117` — **which attains its declared
  degree**, so **no C-4 figure moves**. The lane ledger classifies C-4 as
  liveness, not soundness;
* **soundness**: nothing in the lane ledger or the run gate ties a
  soundness figure to a declared degree. The soundness count is against the
  number of **draws** (361 per block at 125M), which does not move. The
  documented bounds (2^-105.61 per endpoint opening at 125M, ≈2^-97.5 run
  level under ruling M-2) are degree-independent.

So the memo's refusal to propose it is right for the right reason — it is a
new profile (D17) and every frozen receipt-length literal moves — but the
*price* of leaving it is 3.4% of a count and 640 bytes, which is worth
saying out loud so nobody spends a ruling on it prematurely.

---

## 9. Option A — sound, mis-specified in three ways

The design is right in the part that matters most: **it needs no data
copy**. `ClosureRounds<'a, F>` can hold `&'a mut Vec<Vec<Fp2>>`; `round`
takes a shared borrow for the rayon map and `fold` a mutable one, in
separate statements, which is what the code already does under NLL. A
by-value copy would be fatal — slot 17's table set alone is 1,920 MiB. And
nothing needs the tables after `prove`: `zk::extension` takes
`finals`/`exts` only, and the `exts` come from `mask_eval` over the
committed data (`argument.rs:538`), not from the tables. **Option A's
central claim holds.** It also moves no refusal: there is no zero-challenge
check inside `prove` at all; every refusal lives above it, in `zk.rs` and
in `argument.rs:477, 586`.

Three things are wrong:

**IR-C12 (invalid as written).** `pub trait SumcheckRounds: Sync` **locks
the GPU out of the trait**. `prove_rounds` never parallelises — the rayon
region lives inside the implementor's `round` — so `Sync` belongs on the
`ClosureRounds` impl, not on the trait. `hashline/src/gpu/cuda.rs:234-248`
declares `unsafe impl Send for Gpu {}` and **not** `Sync`, and both device
round loops (`cuda.rs:3093`, `:3222` — two hand-written copies of this
exact loop, with the same absorb/draw/fold order) hold a
`MutexGuard<'_, Gpu>`. Since the memo's whole argument for A over B is "the
only one the GPU work and the base-field work can both be built on", the
supertrait contradicts the recommendation. Drop it.

**IR-C13 (overstated).** "`prove` becomes a thin wrapper that is the code it
is today" and "about twenty lines of shared-file change". The wrapper
*body* is one line, but the loop body must be **cut at `sumcheck.rs:109-112`**,
in its middle, and three loop-locals must become struct state or be
recomputed: `half` (`:63`, used at `:115, 117, 121`), `small` (`:67`, used
at `:116, 120`) and `len` (`:61, 127`); `k` becomes `self.tables.len()` and
`n_rounds` must be **cached**, not recomputed from shrinking tables. That
is duplicated logic across two methods that does not exist today. Honest
estimate: **~+128 / −89 lines in `zkp-core/src/sumcheck.rs`** (trait 12,
`prove_rounds` 20, struct 7, `new` with the 8 relocated asserts 12, the
impl 72, wrapper 5) and **~18 lines touched in `hashline/src/zk.rs`**
(memo: four — roughly honest on a tiny base). One consequence worth fixing
in the design: the shape asserts (`:51-58`) have no home in the trait, so a
hand-written or device implementor inherits none of them.

**IR-C14 (wrong number).** The call-site census undercounts.
`zk::masked_prove` has **18** sites, not 13 — the five missing ones include
`private_block/argument.rs:529`, *the very path this design exists for*,
and `private_seam.rs:386`, a declared **frozen** file. `sumcheck::prove`
has 12 production sites (9 `layer.rs`, 2 `attention.rs`, 1 `zk.rs`) plus
`zkp-core/examples/public_sumcheck.rs:14` — which is **gated**, its exact
stdout pinned by `scripts/hashline_cl_gpu_gates.py:110-111` — plus 5
in-crate tests. Keeping `masked_prove`'s signature is therefore not a
convenience, it is what keeps a frozen file untouched.

**IR-C15 (missing — the gate the test plan does not name).** Two things:

* **No `cargo test` gate pins private-block proof CONTENT.** Every
  private-block freeze pins receipt **length** (2,816,472 / 4,742,728 /
  7,452,040 / 11,368,824 / 16,421,048 / 40,783,352 B), and
  `a_toy_receipt_made_before_the_lane_still_verifies` exercises
  `sumcheck::verify`, not `prove`. A refactor that silently moved the
  private-block prover's round values — same round count, same degree, same
  length — would pass the whole suite. The memo's §7.5 seeded byte-identity
  test is exactly the right answer and it should be labelled as
  **compensating for a gap that exists today**, not as a nicety.
  (Feasibility confirmed: `prove_core` takes `rng: &mut ZkRng`
  (`protocol.rs:781`) and `ZkRng::new(seed, domain)` exists
  (`rng.rs:20`).)
* **`tests/test_zk60_mvp_security_probe.py` SHA-256-pins both Option A
  files** against `results/zk60_round22_captures.json → source_sha256`
  (10 files, including `zkp-core/src/sumcheck.rs`, `hashline/src/zk.rs`,
  `transcript.rs`, `pcs.rs`, `private_seam.rs`). **I ran it on main and it
  is already red** — `hashline/src/zk.rs` differs from its pin
  (`SourceBound::test_pins_match_round22_manifest` fails, plus one error in
  `test_diagnostic_does_not_close_security_requirements`). `sumcheck.rs`
  still matches on both trees. So stage 3 would newly break a pin that is
  currently green, on a manifest that is already stale for a different
  file. **That is a pre-existing condition, not the drafter's and not
  mine**, but it is a blocker for stage 3 and the memo's §7.8 ("the whole
  `--lib private_` filter green") does not reach it.

**IR-C18 (missing, and it cuts both ways).** Two behaviours an implementor
can change that **no test would catch**, because both are value-preserving:
`small = half·k <= 1<<16` (`:67`), which only selects serial vs rayon, and
`tb.truncate(half)` (`:125`), which only halves the resident table set each
round. Getting either wrong costs seconds or a 12 GB OOM with a green
suite. The same fact is the reassurance the memo wants: Option A **cannot**
break byte identity through chunking.

---

## 10. GPU memory — arithmetic right, conclusion not

Every figure in the memo's §5 table reproduces exactly:

| resident set | as `Fp2` | base tables as `Fp` | memo |
|---|--:|--:|---|
| slot 17, 30 × 2^22 | **1,920.0 MiB** | **1,344.0 MiB** | ✓ ✓ |
| slot 14, 60 × 2^19 | **480.0 MiB** | **320.0 MiB** | ✓ ✓ |
| all 23 slots | **3.267 GiB** | **2.253 GiB** | ✓ ✓ |
| `A` + `H` raw, 12,801 rows × 2^14 × 8 B | **1.5626 GiB** | — | ✓ |
| slot-at-a-time | **3.438 GiB** | **2.875 GiB** | ✓ ✓ |
| whole block | **4.829 GiB** | **3.816 GiB** | ✓ ✓ |

Independently corroborated: [MEASURED] slot 17's `tables: build` line
reports **125,829,120 words** = 30 × 2^22, so 16 B/word = 1,920 MiB.
(The tables are built at `2^main`, not `2^(main+ext)` — `argument.rs:492`.)

What is missing:

1. **The round-0 `Fp → Fp2` transition is a peak the table does not show.**
   Folding a base table reads `8·2^n` and writes `16·2^{n-1}` = the same
   bytes, so if the 18 base tables of slot 17 are folded before their `Fp`
   buffers are freed, the peak returns to **1,920 MiB** — exactly the
   all-`Fp2` figure. Freed table by table it is 1,376 MiB. §5 says "one
   allocation per base-field table per slot and is the memory peak" without
   saying which of the two it is. It is a **condition on the
   implementation**, and on a machine where exhausting VRAM freezes the
   whole box it should be written as one;
2. **fold scratch, per-block reduction buffers and the coefficient upload**
   — genuinely small (a `[Fp2; d+1]` per block: 4,096 blocks × 6 × 16 B ≈
   0.4 MiB at slot 17). Not a problem, but they are not zero and the table
   claims completeness;
3. **decisively: `A` and `H` are counted as raw data.** [MEASURED,
   `q28-m125-final-dense.log:107,114`] `A: commit` takes RSS from 2,164 to
   5,024 MiB (+2,860) and `H: commit` from 4,597 to 8,170 MiB (+3,573) —
   ~6.4 GiB for the encoded matrices at `inv_rate 4` plus the Merkle
   layers, against the 1.56 GiB of raw data in the memo's row. The whole
   prove's [MEASURED] peak RSS is **10,156 MiB (9.92 GiB)**.

**IR-C8b.** So "Both fit an 8 GB card slot-at-a-time with room to spare,
and the whole block fits too" is true **for the round loop alone** and
false for the commitments — which §8.2 says are also needed for 5 s and
which are 37.3% of the prove. Given the project's VRAM rule the sentence
should read: the round loop fits an 8 GB card; the commitment side needs
its own memory design and does not fit beside it.

---

## 11. The sharpened counter-argument

[MEASURED, `q28-m125-final-dense.log`, **one run, shared box**, 17.401 s]:
masked sumcheck bodies 6.594 s (37.9%), `A`+`H` commit 6.500 s (37.3%),
extension rounds 0.757 s, table build 0.588 s, claimed sums 0.020 s,
everything else ~2.9 s.

**[MODEL], an Amdahl ceiling and explicitly not a prediction** — it assumes
every removed multiplication becomes time, which §2.1 of this check shows
is false per slot:

| lever set | ceiling | cut |
|---|--:|--:|
| all three, at this check's 59.9% | **13.44 s** | −22.8% |
| all three, at the memo's 58.2% | 13.55 s | −22.1% |
| **the round loop to ZERO** | **10.79 s** | −38.0% |
| slots 17 and 14 hand-specialised only | **14.46 s** | −16.9% |

Three things follow.

* **The ceiling is 13.4 s and the floor with an infinitely fast round loop
  is 10.8 s.** Neither is near 5 s. The memo says this in §8.2 and is
  right; its own numbers understate how right, because it quotes
  28.1% / 23.7% when the current tip is 37.9% / 37.3% (IR-C8).
* **What dominates afterwards** is the two PCS commitments: 6.500 s, 60% of
  the 10.79 s floor. The IR does nothing for them. This is the memo's own
  risk 2 and it is the correct headline.
* **The cheaper way gets most of it.** Slots 17 and 14 are **82.4% of the
  counted baseline** at 125M and **71.2% of the measured masked-sumcheck
  seconds**. Hand-specialising those two alone reaches 14.46 s against the
  full-lever 13.44 s — **74% of the gain from 2 of 23 arms**, with no
  shared-file change, no trait, no exporter and no second source of truth.
  The memo's case for doing all 23 is therefore not the arithmetic; it is
  the GPU (a device kernel needs the polynomial as data) and the Python
  gate. Those are good reasons and the memo should lead with them rather
  than with 58.2%.

---

## 12. Findings

| # | severity | finding | memo | this check |
|---|---|---|--:|--:|
| **IR-C1** | **invalid lever / correctness trap** | 12 tables classified base-field are extension-valued: 11 `A` planes read at a `Coord::Fixed` claim point (7 matmuls + 4 bilinear factors, `priv_table`'s `eqf[z]` weighting) and the `SC_TAB` U8 value column (`+ g_u8`). Stage 5 implemented against this list would compute wrong field elements in 9 slots, and no `cargo test` gate would catch it | 143 of 229 | **131 of 229** |
| **IR-C2** | overstated / wording | the three lever percentages are shares of the **previous row**, not of the baseline; they sum to 73.0% against a 58.2% total, and every reader so far has added them | 10.9 + 23.4 + 38.7 | **14.2 + 14.4 + 31.2 = 59.9** |
| **IR-C3** | confirmed | the baseline reproduces **exactly**, component by component, at both shapes, by an execution count instead of a token count | 16,478,006,793 | **16,478,006,793** |
| **IR-C4** | understated | lever (b) | 10.9% | **14.2%** |
| **IR-C5** | **overstated** | lever (a) — the only lever the memo overstates | 20.8% of baseline | **14.4%** |
| **IR-C6** | understated | lever (c) as a count | 26.4% of baseline | **31.2%** |
| **IR-C7** | missing | (c)'s finite-difference additions priced at zero | — | **4.95e9 `Fp` adds**; combined saving 52.4 / 44.9 / 29.9% at 0.25 / 0.5 / 1.0 |
| **IR-C8** | **wrong number** | Fact 2 mixes runs and denominators: 6.907 s / 28.1% is the 24.59 s post-task-1 tree, 6.575 s / **23.7% is the 27.71 s baseline tree**, not the 24.59 s one (6.575/24.59 = 26.7%). Both are superseded in the same ledger | 28.1% / 23.7% | **37.9% / 37.3% of 17.401 s** |
| **IR-C8b** | overstated | "both fit an 8 GB card" — true for the round loop, false once the commitments §8.2 also needs are added (+6.4 GiB MEASURED) | 4.83 GiB | round loop only |
| **IR-C9** | **wrong model** | the count model does not reproduce the measured per-slot shares: implied throughput spans 6.7× over the six big slots, the 17:14 ratio is 3.92 counted vs 1.86 measured, and slots 04/16 are inverted. A traffic term does not repair it | "65.3% at 14, 58.8% at 17" | aggregate only |
| **IR-C10** | wording / scope | the degree finding is **two** slots (14, 15) at 125M and rung-W14, not four; 16 and 18 attain their declared degree at both. Cost of leaving it: **640 B** of receipt and **3.4%** of the counted baseline; no C-4 or soundness figure depends on it | "four slots" | **two** |
| **IR-C11** | wording | "the IR shares all of them by construction" — the grammar has no CSE pass; sharing is what the builder writes, as today | — | visible, not automatic |
| **IR-C12** | **invalid** | `pub trait SumcheckRounds: Sync` excludes the GPU (`Gpu` is `Send`, not `Sync`; the device loops hold a `MutexGuard`), contradicting Option A's own justification | — | put `Sync` on the impl |
| **IR-C12a** | wording | `wrho_s = 18` at both shapes is a **calibration** coincidence (`f_e` 12 vs 9), as is `a_groups = 36`; "the SAME slot structure" is true today, not a theorem | — | — |
| **IR-C13** | overstated | "`prove` becomes a one-line wrapper, today's code verbatim", "about twenty lines" — the loop must be cut at `:109-112` and `half`/`small`/`len`/`k`/`n_rounds` become state | ~20 lines | **~+128 / −89** in `sumcheck.rs`, ~18 in `zk.rs` |
| **IR-C14** | wrong number | call-site census: `masked_prove` 18 sites (incl. `private_block/argument.rs:529` and the **frozen** `private_seam.rs:386`); `prove` 12 + a gated example + 5 in-crate tests | 13 / 12 | **18 / 18** |
| **IR-C15** | **missing** | no `cargo test` gate pins private-block proof CONTENT (only length); and `tests/test_zk60_mvp_security_probe.py` SHA-256-pins `sumcheck.rs` and `zk.rs` — **already red on main for `zk.rs`** (verified by running it), a pre-existing blocker for stage 3 | — | §7 must name both |
| **IR-C16** | missing | `CfsMasker`'s round index comes from `note_challenge` counts: exactly one `b"sc-round"` absorb and one challenge per round, or every later mask is silently wrong | — | — |
| **IR-C17** | missing | `ProverOutput.proof.rounds` holds the **unmasked** rounds; a new public `prove_rounds` widens the surface for publishing them | — | one doc line |
| **IR-C18** | missing | `small` and `tb.truncate(half)` are value-invisible: getting them wrong costs seconds or a 12 GB OOM with a green suite (and equally, chunking cannot break byte identity) | — | — |
| **IR-C19** | **missing lever** | `prove` evaluates at all `degree + 1` points and never uses `s(0) + s(1) = claim`. The prover knows the claim, so one evaluation per pair index is redundant: **2,606,516,529 `Fp` = 15.8% of the baseline** at 125M (16.0% at W14) for a shared-file change smaller than any stage here. It interacts with (c) and it removes an implicit self-check, so it needs a judgement — but §3 never mentions it | — | **15.8%** |
| **IR-C20** | confirmed | §3.5's own caveat that "the token-plus-adjustment identity is a definition, not an independent check" is exactly right. **This check is that independent check, and the baseline passed it.** | — | — |

---

## 13. What this check did not do

* **No Rust was compiled and no proof was run.** The equality between the
  IR and the closure remains asserted from reading on both sides. My
  transliteration is a third hand-written description of the same 23
  polynomials and carries the same class of risk the memo's §8.2 risk 3
  names — the reassurance is that it agrees with the drafter's baseline
  digit for digit by a different route, not that either is right.
* **No timing was measured.** Every second quoted is from a committed log,
  and the box is not quiesced (the ledger's own run-to-run figure is up to
  a factor of two; the two committed 125M samples differ by up to 14% per
  slot). The Amdahl ceiling in §11 is [MODEL].
* **Lever (b) was re-derived as a lower bound.** I implemented the sharing
  and the coefficient typing I could find by reading; a more aggressive CSE
  would give more. My (b) already exceeds the memo's, so the direction is
  settled but the ceiling is not.
* **(c)'s addition credit was not modelled.** The `cur[t] += dif[t]` walk
  shortens under (c) and I counted only the extra extension additions, so
  the sensitivity band in §3 is pessimistic at the margins.
* **The rung-W14 side has no MEASURED per-slot data to check against.**
  No `PB-SLOTSTEP` or `PB-TIMING` run exists at that shape; the only
  measured W14 figures are end-to-end (prove 3.99–4.09 s, frame
  16,421,048 B). §2.1's disagreement is therefore established at 125M only.
* **I did not check the exporter, the bundle pin, or the Python gate's
  independence argument** (§6 of the memo) beyond reading it. The "what
  independence is lost, said plainly" paragraph is, in my reading, the
  most honest paragraph in the memo and I have nothing to add to it.
* **I did not verify the drafter's per-slot table in
  `slot_ir_counts.md`** beyond the five slots the census covers plus 05,
  08 and the totals; the 229-table census and the degree vector were
  re-derived in full, the `monomials` / `forms` / `nodes` columns were not.
