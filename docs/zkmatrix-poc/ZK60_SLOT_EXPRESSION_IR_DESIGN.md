# ZK60 — a slot expression IR for the private block

**DESIGN MEMO. Written 2026-09-21 by the design-drafter lane. It changes no
production code, makes no speed claim, and changes no privacy or soundness
statement.** Section 9 says what it is not, in full.

Code read (read-only) at lane `zk60-private-block-125m` tip `226f3b2`,
worktree `/home/victor/wt-zk60-block125m`:
`hashline/src/private_block/{argument,protocol,layout,shape,timing,pad}.rs`,
`hashline/src/zk.rs`, `zkp-core/src/{sumcheck,field,rng}.rs`. Counting
evidence: `results/zk60_slot_ir/` (script `slot_ir_inventory.py`, report
`slot_ir_counts.md`, per-slot detail `slot_ir_detail_m125.txt` and
`slot_ir_detail_rung_w14.txt`, the IR sketch `slot_ir_m125.json`).

**Labels.** **[MEASURED]** = quoted from a committed log, with its path.
**[COUNTED]** = produced from the code or the shape by the script above.
**[MODEL]** = estimated. *No time prediction appears anywhere in this memo.*
A counted gain is a count; it is never relayed as a second saved.

**Vocabulary, defined once.**

* **slot** — one of the twenty-three sub-arguments the private block's
  transcript runs in order (`layout.rs`, `SC_SS = 0 … SC_IO_OUT = 22`). Each
  is one masked sumcheck.
* **table** — one vector of `2^n` field elements the slot's sumcheck reads,
  where `n` is the slot's *main round* count. A slot has between 2 and 60 of
  them.
* **round polynomial** — in round `j` the prover sends the values, at
  `t = 0 … degree`, of the sum over the remaining cube of the slot's
  polynomial with variable `j` set to `t`. Today it is produced by calling a
  Rust closure `degree + 1` times per *pair index*.
* **pair index** — in round `j` the cube of `2^{n-j}` entries is read in
  pairs `(i, i + half)`; there are `half = 2^{n-1-j}` of them.
* **`Fp` / `Fp2`** — the base field, and its quadratic extension
  `Fp[u]/(u² − 7)`. `Fp2::mul` costs **five** `Fp` multiplications,
  `Fp2::mul_base` (extension times base) **two**, base times base **one**
  (`zkp-core/src/field.rs:158`). Every cost in this memo is counted in `Fp`
  multiplications, which is the only unit that is not a guess.
* **base-field-valued table** — a table all of whose words have zero
  imaginary part. Committed witness planes (`A`) and shape-driven public
  tables are; challenge-weighted `eq` tables and LogUp helper columns (`H`,
  which hold inverses) are not.
* **wrapper** — the leading factors a group of terms shares: the zero-check's
  `eq(tau, ·)` and, where the term carries it, the pad rule's support gate.
* **IR** — intermediate representation: the polynomial written as data
  instead of as code.

---

## 0. The problem, in three observed facts

**Fact 1 — the shared loop cannot specialise.** `zkp-core/src/sumcheck.rs`'s
`prove` gathers `cur[t] = v0`, `dif[t] = v1 − v0` per pair index and then
calls `poly(&cur)` — a `Box<dyn Fn(&[Fp2]) -> Fp2>` — once per evaluation
point, walking `cur[t] += dif[t]` between them. It cannot know that 62.1% of
the words it is multiplying are base-field: **[MEASURED, lane ledger
`ZK60_BLOCK125M_LANE_PROGRESS.md` stage 29 task 4, `r29-m125-bfcensus.log`]
84 of the 136 tables that round 1 of slots 17, 14, 18, 15 and 04 reads at the
125M shape are wholly base-field — 130,547,712 of 210,239,488 words.** Every
one of those words nevertheless enters a full five-multiplication `Fp2::mul`.

**Fact 2 — nothing in this form runs on a GPU, and the five-second target is
a GPU target.** Two phases have to move. **[MEASURED, lane ledger stage 28
"Integrator requests, with MEASURED attribution", one run, shared box]** the
sumcheck round loop and `zk::extension` are **6.907 s, 28.1%**, and
`pcs::commit_zk_owned` for `A` and `H` is **6.575 s, 23.7%**, of a prove the
ledger labels 24.59 s. That 24.59 s figure is a post-task-1 working tree and
no commit (the ledger's own correction S28-R4); the honest whole-prove figure
is **[MEASURED] 17.4–19.4 s for one 125M block, two runs on the laptop**
(stage 28's 17.40 s and stage 29's 19.36 s, same receipt length 40,783,352 B).
A `Box<dyn Fn>` over a `&[Fp2]` slice has no device representation at all.

**Fact 3 — the independent Python gate re-implements each slot by hand, and
that is how finding M-F1 happened.** `zk60_native_rg_terminals.py` carries a
hand port of every slot polynomial (`sc_tzc`, `sc_szc`, `sc_fzc`, …). Three
of them assumed the pad rule's extra draws were always taken; at 125M
`Dom::T`, `Dom::Kv` and `Dom::F` do not pad, the prover draws two fewer
challenges in slots 02, 16 and 18, and the port silently diverged on a branch
no development shape could reach
(`ZK60_NATIVE_RUN_GATE.md` §13.3). The repair derived the branch instead of
widening a slice — but the port is still a hand port.

One change addresses all three: **make each slot's round polynomial DATA.**

---

## 1. Inventory: all twenty-three slots [COUNTED at `226f3b2`]

### 1.1 What was extracted and what was hand-written

`results/zk60_slot_ir/slot_ir_inventory.py` reads three things straight out
of `argument.rs` and marks them `[extracted]`:

* the builder-call sequence of every arm of `argument::define` (`b.eq`,
  `b.public`, `b.a`, `b.a_at`, `b.a_slice`, `b.a_range`, `b.h`, `b.endpoint`,
  `b.supp`, `b.group_eq`) in source order — 16 arms, naming 23 of 23 slots;
* the `.mul(` token count inside each slot's closure body;
* the challenge draws of each arm.

The per-shape table list, the expression graph and the loop trip counts are
**hand-transcribed** from the same source and are marked as such in the
script. Three cross-checks guard them, and all three pass at every shape the
script runs:

| cross-check | what it compares | result |
|---|---|---|
| 1, the token identity | for each slot, `dynamic multiplications = extracted token count + this slot's declared adjustments` (a named local closure called *n* times, a loop body, `helper_sum`, `limbs`, `PadTerm::eval`), each adjustment printed | holds by construction and is printed slot by slot in `slot_ir_counts.md`, so a reader can re-derive it |
| 2, the MEASURED census | the table COUNT per slot and the wholly-base-field split, against the lane ledger's stage-29 census | **125M: 30 / 60 / 20 / 21 / 5 tables at slots 17 / 14 / 18 / 15 / 04 and 18 / 40 / 11 / 11 / 4 wholly base-field — all five agree. rung-K4: 30 / 62 / 21 / 21 / 5 and 18 / 40 / 12 / 11 / 4 — all five agree.** |
| 3, the lane layout model | main rounds, extension rounds and declared degree per slot, against `scripts/zk60_private_block_layout_model.py` in the lane worktree | **23 of 23 slots, 0 differences, at all nine registered shapes** |

Cross-check 2 is the strong one: it is a MEASURED count, produced by a
diagnostic that walked the real tables inside a real 125M prove, and the
model reproduces it exactly, including the two places where rung-K4 and 125M
differ (correction C-6 drops four `Dom::D` lookups at 125M, so slot 14 has 60
tables there and 62 at rung-K4).

### 1.2 The table inventory, by kind

Seven table kinds appear. `eq` and `group_eq` are challenge-weighted public
tables built by `eq_cube`; `pub` is a shape-driven public table
(`fold_rows_i8`/`fold_cols_i8` of a weight matrix, the causal mask, the RoPE
pair, the three byte-table value columns, the two norm gains); `supp` is the
pad rule's support indicator (`pad::indicator_table`, a public selector);
`A` is a committed witness plane; `H` is a committed LogUp helper column;
`EP` is an endpoint plane. The field column is what fact 1 turns on. **Base**:
every `A` plane (integer witness data lifted by `Fp2::from_base`), every
`supp` indicator, both `EP` planes, and ten of the nineteen `pub` tables (the
causal mask twice, the two padded norm gains, the four RoPE tables, the U8
value column, the all-ones vector). **Extension**: the 25 `eq` and 2
`group_eq` tables (challenge-weighted), all 50 `H` helper columns (they hold
inverses), the seven folded weight matrices (each is `eq(r_j)`-weighted by
`fold_rows_i8`/`fold_cols_i8`) and the exp and activation value columns (each
carries `beta·table[i]` and a challenge tag). 143 base, 86 extension.

**rung-W14 and 125M have the SAME slot structure**: the same tables by kind,
the same degrees, the same expression graph, the same multiplications per
evaluation. Only the cubes differ. (Both have width 768, so `limbs_norm = 4`
with a full top byte — correction C-6 — and both have `limbs_sigma_s = 3`;
both pad `{Ht, L, D, Q, S, Tab}` and leave `{T, Kv, F}` exact.) That is why
the ledger calls rung-W14 "the shape whose receipt must not move under
shared-file speed work", and it is why the test plan in §7 can lean on it.

| slot | name | cube W14 | cube 125M | deg | eq | grp | pub | supp | A | H | EP | tables | base/ext | IR terms | nodes | forms | monomials | mul/eval |
|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| 00 | SC_SS | 2^16 | 2^19 | 4 | 1 | · | · | 1 | 1 | · | · | 3 | 2/1 | 1 | 0 | 0 | 1 | 3 |
| 01 | SC_SSM | 2^16 | 2^19 | 4 | 1 | · | · | 1 | 1 | · | · | 3 | 2/1 | 1 | 0 | 0 | 1 | 3 |
| 02 | SC_TZC | 2^6 | 2^9 | 3 | 3 | · | · | · | 22 | · | · | 25 | 22/3 | 3 | 3 | 6 | 36 | 28 |
| 03 | SC_LZC | 2^14 | 2^14 | 4 | 1 | · | · | 1 | 2 | 1 | · | 5 | 3/2 | 1 | 3 | 4 | 12 | 8 |
| 04 | SC_RS | 2^16 | 2^22 | 4 | 1 | · | 1 | 1 | 2 | · | · | 5 | 4/1 | 1 | 1 | 0 | 2 | 4 |
| 05 | SC_QMM | 2^10 | 2^10 | 2 | · | · | 1 | · | 1 | · | · | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 |
| 06 | SC_KMM | 2^10 | 2^10 | 2 | · | · | 1 | · | 1 | · | · | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 |
| 07 | SC_VMM | 2^10 | 2^10 | 2 | · | · | 1 | · | 1 | · | · | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 |
| 08 | SC_SCORE | 2^8 | 2^8 | 3 | · | 1 | · | · | 2 | · | · | 3 | 2/1 | 1 | 0 | 0 | 1 | 2 |
| 09 | SC_PV | 2^8 | 2^11 | 3 | · | 1 | · | · | 2 | · | · | 3 | 2/1 | 1 | 0 | 0 | 1 | 2 |
| 10 | SC_WO | 2^10 | 2^10 | 2 | · | · | 1 | · | 1 | · | · | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 |
| 11 | SC_GMM | 2^10 | 2^10 | 2 | · | · | 1 | · | 1 | · | · | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 |
| 12 | SC_UMM | 2^10 | 2^10 | 2 | · | · | 1 | · | 1 | · | · | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 |
| 13 | SC_DMM | 2^10 | 2^11 | 2 | · | · | 1 | · | 1 | · | · | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 |
| 14 | SC_DZC | 2^16 | 2^19 | 5 | 3 | · | 2 | 1 | 37 | 17 | · | 60 | 40/20 | 3 | 22 | 49 | 272 | 152 |
| 15 | SC_QZC | 2^16 | 2^19 | 5 | 3 | · | 2 | 1 | 8 | 7 | · | 21 | 11/10 | 3 | 10 | 18 | 77 | 44 |
| 16 | SC_KVZC | 2^14 | 2^17 | 4 | 3 | · | 2 | · | 7 | 6 | · | 18 | 9/9 | 3 | 8 | 15 | 59 | 33 |
| 17 | SC_SZC | 2^16 | 2^22 | 5 | 3 | · | 1 | 2 | 15 | 9 | · | 30 | 18/12 | 3 | 17 | 26 | 121 | 75 |
| 18 | SC_FZC | 2^16 | 2^20 | 4 | 3 | · | · | · | 11 | 6 | · | 20 | 11/9 | 3 | 9 | 14 | 56 | 37 |
| 19 | SC_TAB | 2^14 | 2^14 | 3 | 1 | · | 3 | 1 | 3 | 3 | · | 11 | 5/6 | 1 | 5 | 7 | 21 | 16 |
| 20 | SC_ZS | 2^14 | 2^14 | 2 | · | · | 1 | · | · | 1 | · | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 |
| 21 | SC_IO_IN | 2^16 | 2^19 | 2 | 1 | · | · | · | 1 | · | 1 | 3 | 2/1 | 1 | 1 | 0 | 2 | 1 |
| 22 | SC_IO_OUT | 2^16 | 2^19 | 2 | 1 | · | · | · | 1 | · | 1 | 3 | 2/1 | 1 | 1 | 0 | 2 | 1 |
| — | **all 23** | | | | **25** | **2** | **19** | **9** | **122** | **50** | **2** | **229** | **143/86** | **35** | **80** | **139** | **672** | |

"IR terms" is the number of top-level terms (a term is a coefficient times a
wrapper product times an inner product); "nodes" and "forms" are the shared
sub-expressions the graph names; "monomials" is what the graph expands to if
every node is flattened — the length of the flat product list a naive kernel
would iterate. "mul/eval" is the number of `Fp2::mul` calls the CLOSURE makes
per evaluation point, cross-check 1's dynamic figure.

### 1.3 Every slot's polynomial, written out

The full written-out form — every table with its kind and field, every affine
form, every sub-expression node with its degree, every term with its
coefficient and the coefficient's provenance — is in
`results/zk60_slot_ir/slot_ir_detail_m125.txt` and
`…_detail_rung_w14.txt`, one section per slot, 23 of 23, generated. The
prose below says what each slot *is*; the generated file is the
authoritative form, and it is what §2's grammar encodes.

Coefficient provenance takes exactly three values, and this is the
distinction the whole design turns on:

* **`one`** — the coefficient is `1` or `−1`: no multiplication at all.
* **`kbase`** — a PUBLIC BASE-FIELD constant: a power of 256 from a byte-limb
  decomposition (`pow256(k)` in `limbs`, `l2`, `l3`), a fixed-point shift
  (`2^SH_QKV`, `2^SH_ROPE`, `2^SH_S`, `2^SH_O`, `2^SH_AO`, `2^SH_G`,
  `2^SH_H_PROD`, `2^SH_Z`, `2^F_P`), a norm constant (`2·NORM_CN`, `2^NORM_TN`,
  `2^(NORM_TN+1)`, `NORM_CEPS`), an int16 bias (`32768`), or a lookup's
  integer coefficient (`byte`/`scaled`/`sym` in `layout::lookups_at`, each of
  which has exactly ONE table term). Today every one of these is executed as
  a full five-multiplication `Fp2::mul`; each is a two-multiplication
  `mul_base`.
* **`chal`** — a challenge or a product of challenges: `mu_k`, `nu_0`/`nu_1`,
  `zeta^j` under the pad rule, `lam_z`, `beta`, `alpha`, `nu_0 · per_row`.
  These are genuine extension multiplications and stay so.

**Slots 00 and 01 (`SC_SS`, `SC_SSM`), private row sums.** Three tables:
`eq(r_t)` (or `eq(r_t2)`), the plane `A_X` (or `A_X1`), and `supp(Dom::D)`
where `Dom::D` pads. One term, coefficient 1, four factors:
`supp · eq · A · A`. Degree 4 = declared 4. The only slots where the support
indicator genuinely raises the degree, along with 04 and 17.

**Slot 02 (`SC_TZC`), the norm-squares zero-check, host of 00 and 01.**
Twenty-five tables at both shapes: three `eq` (`tau`, `r_t`, `r_t2`), the
four `Dom::T` planes `A_D`, `A_DSQ`, `A_DM`, `A_DSQM`, and the eighteen
byte-limb sub-slices (`A_LIMB[0..9]`, `A_LIMBM[0..9]`, `N_LIMBS = 3 ·
LIMBS_ISQRT`). Three terms: the zero-check arm `eq(tau) · zc`, where `zc` is a
six-subterm node (`mu0 (dsq − d²) + mu1 (d − dl) + mu2 (2d − a1 − a2)` and
the same three for `norm_m`), and two host terms `nu_k · eq(r_t^{(k)}) ·
supp_T · (dsq + a1 − NORM_CEPS)`. Six affine forms, each a `dl`/`a1`/`a2`
byte-limb triple with `kbase` coefficients 1, 256, 65536. Degree 3 = declared
3. At 125M `Dom::T` does not pad, so there is no `supp_T` table, `pad_on` is
false and the slot draws two fewer challenges — this is exactly the branch
finding M-F1 tripped over.

**Slot 03 (`SC_LZC`), the limb LogUp, standalone.** Five tables:
`eq(tau)`, `A_LIMB`, `A_LIMBM`, the helper `H_L0`, `supp(Dom::L)`. One term
`eq(tau) · zc`; `zc` holds the one LogUp helper relation
`h · d1 · d2 − d1 − d2` (degree 3, with `d_i = alpha − byte(plane_i)` an
affine form with one `kbase` coefficient) and, under the pad rule, the
batched pad-zero node. Degree 4 = declared 4. Note the LogUp arm is NEVER
gated by the support indicator (`argument.rs` §3.7a: gating it would drop the
padded positions out of the value-0 identity while their multiplicities still
count them).

**Slot 04 (`SC_RS`), the masked softmax row sums, private.** Five tables:
`eq(p_ht)`, the public causal mask, `A_E`, `A_ZSEL`, `supp(Dom::S)`. One
term, wrapper `supp · eq`, inner the two-subterm node
`mask · e + lam_z · zsel`. Degree 4 = declared 4. Its cube is 2^22 at 125M —
the joint largest, with slot 17 — so despite having only five tables and four
multiplications per evaluation it is the fifth most expensive slot there
(608 M `Fp` multiplications, behind 17, 14, 18 and 15) [COUNTED].

**Slots 05, 06, 07, 10, 11, 12, 13 (`SC_QMM`, `SC_KMM`, `SC_VMM`, `SC_WO`,
`SC_GMM`, `SC_UMM`, `SC_DMM`), the seven matmuls, private.** Two tables each:
the committed plane read at a fixed row point, and the public weight matrix
folded over its output index against `eq(r_j)` (`fold_rows_i8` for the four
attention matmuls, `fold_cols_i8` for the three feed-forward ones). One term,
coefficient 1, two factors. Degree 2 = declared 2. The folded weight table is
extension-valued (it is weighted by an `eq` of challenges), so these are the
one public-table family that is not base-field.

**Slots 08 and 09 (`SC_SCORE`, `SC_PV`), the bilinear matmuls, private.**
Three tables where the shape groups its key-value heads: the public group
gate `eq(r_g, ·)` over the LEADING `lkv = log2(kv_heads)` variables, and the
two committed factors (`A_QR8` × `A_KR8`, `A_P` × `A_V8`). One term,
coefficient 1, three factors. Degree 3 = declared 3. At `kv_heads = 1` the
gate is absent, the degree is 2 and the term is the plain product — the
frozen toy's path, byte for byte. These are the only two slots with TWO
extension rounds (one per private factor). The group bits are SUMCHECK
variables of both factors, not fixed coordinates: that is the repair of
finding S19-F1, and the IR has to carry it as a public factor over the
leading variables or it would re-state the bug.

**Slot 14 (`SC_DZC`), the width zero-check, host of `SC_WO` and `SC_DMM`.**
The widest slot: sixty tables at 125M (three `eq`, the two padded norm gains
`gamma_a`/`gamma_m`, thirty-five `Dom::D` planes, the two `Dom::T` slices
`A_D`/`A_DM`, seventeen LogUp helpers, `supp(Dom::D)`). Three terms. The
first, `eq(tau) · zc`, holds three arms: the eleven inhomogeneous clauses
`c0 … c10` **multiplied by the support gate ONCE as a sum** (the closure
multiplies each of the eleven separately), the seventeen ungated LogUp
relations, and the pad-zero node over thirty-five planes. The two host terms
are `nu_k · eq(p) · supp · (2^sh · plane + remainder − bias)`. Forty-nine
affine forms, twenty-two sum nodes, 272 monomials if flattened. **IR max
product degree 4, declared degree 5** — see §1.4.

**Slots 15 and 16 (`SC_QZC`, `SC_KVZC`), the two RoPE zero-checks, hosts.**
Twenty-one and eighteen tables: three `eq`, the two public RoPE tables laid
out on the padded domain stride, the domain's `A` planes, one extra `A` slice
at the FLIPPED partner bit (`Coord::Flip` at `log − log2(head_dim)`, trap
T-8), the LogUp helpers, and the support indicator where the domain pads.
Three terms: the rope clause `mu0 · supp · (cos·src + sin·partner −
2^SH_ROPE·rot − rot_rem + 2^(SH_ROPE−1))` and the LogUp and pad arms under
`eq(tau)`, plus two host terms. IR degree 4; declared 5 at `SC_QZC` (where
`Dom::Q` pads at both shapes) and 4 at `SC_KVZC` (where `Dom::Kv` is exact at
both shapes — the M-F1 branch again).

**Slot 17 (`SC_SZC`), the softmax zero-check, host of `SC_RS` and
`SC_SCORE`. The most expensive slot at 125M.** Thirty tables: three `eq`
(`tau`, `p_ht`, `p_s`), the public causal mask, thirteen `Dom::S` planes, the
two `Dom::Ht` slices `A_MX`/`A_SUM` read on the leading coordinates, eight
LogUp helpers, the exponential-pair helper `H_SEXP`, and TWO support
indicators — this is the only slot that hosts two domains, and `Dom::Ht`'s
indicator is lifted over the trailing `j` axis and carries its own pad-zero
group (finding S9-F7). Three terms. The zero-check arm carries five gated
clauses, the ungated exponential-pair relation `cx`, eight LogUp relations
and a two-group pad node. Its cube is 2^22 at 125M, 30 tables of 4,194,304
`Fp2` words — **1,920 MiB of table set for one slot [COUNTED]**. **IR max
product degree 5 = declared 5**, and the term that reaches it is
`eq(tau) · supp_S · mu1 · zsel · mask · (s8 + 127)`, the masked-score half of
clause `c1`.

**Slot 18 (`SC_FZC`), the hidden-cube zero-check, host of `SC_GMM` and
`SC_UMM`.** Twenty tables: three `eq`, eleven `Dom::F` planes, five LogUp
helpers, the activation-pair helper `H_FACT`. `Dom::F` is exact at both
shapes, so there is no support table. Three terms: the three gated clauses
(the int16 product `a16·u16`, and two byte decompositions), the ungated
activation-pair relation, five LogUp relations, two host terms. IR degree 4 =
declared 4 here; where `Dom::F` pads the declared degree rises to 5 and the
IR's stays 4.

**Slot 19 (`SC_TAB`), the three byte tables' helper relations, standalone.**
Eleven tables: `eq(tau)`, then three `(multiplicity, helper, public values)`
triples (U8, exp, activation), then `supp(Dom::Tab)`. One term: `eq(tau)` times
a node with three relations `h_j (alpha − values_j) − m_j` and, under the pad
rule, a TWO-group pad node — one over the three multiplicities and one over
the three helpers (finding F-2's repair checks both lists against
`pad::zero_rule_*_planes`). Degree 3 = declared 3. The exp and activation
value tables are the one public family that is extension-valued: they carry
`beta · exp[i]` and the tag `g_exp` / `g_act`.

**Slot 20 (`SC_ZS`), the zero-sum row, standalone.** Two tables: the all-ones
vector over `Dom::Tab` and the hidden plane `H_U`. One term, two factors,
degree 2.

**Slots 21 and 22 (`SC_IO_IN`, `SC_IO_OUT`), the endpoint equalities,
standalone.** Three tables: `eq(tau)`, the committed plane (`A_X` or `A_X2`),
and the external endpoint plane. One term `eq(tau) · (plane − endpoint)`,
degree 2.

### 1.4 One thing the IR computes that nobody had computed [COUNTED]

The IR's maximum product degree equals the declared degree at nineteen of the
twenty-three slots. At four it is **one lower**:

| slot | IR max product degree | declared | why |
|---|--:|--:|---|
| 14 `SC_DZC` | 4 | 5 (at both shapes) | the ungated LogUp arm `eq · h · d1 · d2` already reaches 4; the support indicator raises only the CLAUSE arm, from 3 to 4 |
| 15 `SC_QZC` | 4 | 5 (at both shapes) | same |
| 16 `SC_KVZC` | 4 | 5 where `Dom::Kv` pads — rung, rung-G, rung-K4 only; it is exact at rung-P2, rung-C6, rung-W14, rung-E32 and 125M | same |
| 18 `SC_FZC` | 4 | 5 where `Dom::F` pads — rung, rung-G, rung-K4 only; exact at the rest | same |

(At the frozen toy profile there is no pad machinery at all and the IR degree
equals the declared degree at all 23 slots. The gap appears at exactly the
shapes and slots listed, and at no others: `slot_ir_counts.md` prints the
list per shape.)

`Shape::slots` adds one to `BASE_DEGREE[s]` for every slot in
`INDICATOR_SLOT_DOMAIN` whose domain pads. For the four LogUp hosts that is
conservative: their base degree was already set by the ungated LogUp arm, and
the gate only lifts the arm that was one lower. **This is reported as a count
and is NOT proposed.** The declared degree is what `slot_lengths` builds the
round message length from — `L = (main + ext)·degree + 2` — so lowering it
moves bytes, changes the transcript, and needs a new profile (D17) and a
security ruling. It belongs nowhere near a "moves no byte" migration. It is
recorded here because the IR is the first artefact in the project that can
compute the true degree at all, and because a future profile revision should
know.

---

## 2. The IR

### 2.1 The grammar, and why it is two levels and not one

A flat list of monomials would be the simplest IR and the worst one: the
LogUp relation `h · (alpha − c1 p1) · (alpha − c2 p2) − (…)` expands to seven
monomials per helper, and slot 14 has seventeen helpers. Flattened, slot 14 is
272 monomials against 22 shared nodes and 49 affine forms [COUNTED]. Worse,
flattening multiplies the COEFFICIENT count: the closure multiplies a whole
clause by its `mu` once, and a flat form would multiply every monomial of it.

So the IR is a small **expression graph**: a sum of products whose factors are
table references, affine forms, or other nodes. That is exactly the level the
closures already work at, which is what makes the oracle test in §7 an
equality and not an approximation.

```rust
/// A table reference: the slot's own push index — which is also the index
/// its masked terminal arrives at in `SlotProof::terms`, so the gate can
/// join the IR to a capture without a second naming scheme.
pub type TableId = u16;
pub type NodeId  = u16;

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum TableKind {
    /// `Tab::Eq`: eq(point, x[start .. start + |point|]), challenge-weighted
    Eq { start: u16, point_len: u16 },
    /// the bilinear slots' public group gate over the LEADING lkv variables
    GroupEq { bits: u16 },
    /// `Tab::Pub`: a shape-driven public table
    Public,
    /// `Tab::Pub` holding `pad::indicator_table(shape, dom)` — a selector
    Support { dom: Dom },
    /// `Tab::Priv` in the A commitment: a committed witness plane
    PlaneA,
    /// `Tab::Priv` in the H commitment: a LogUp helper column (re + u im)
    HelperH,
    /// `Tab::Priv` in an endpoint commitment
    Endpoint,
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum FieldKind { Base, Extension }

pub struct TableRef {
    pub id: TableId,
    pub kind: TableKind,
    /// what the WORDS hold, not what the type is: an A plane is integer data
    /// lifted by `Fp2::from_base` and so is `Base`
    pub field: FieldKind,
    pub label: &'static str,
}

/// Where a coefficient comes from.  The evaluator types its multiplication
/// from this and from nothing else, which is the whole point of recording it.
#[derive(Clone)]
pub enum Coef {
    One,
    NegOne,
    /// a PUBLIC BASE-FIELD constant: a power of 256, a fixed-point shift, a
    /// norm constant, an int16 bias, a lookup's integer coefficient.
    /// `why` is the shape fact or the module constant that fixes it.
    Base { value: Fp, why: &'static str },
    /// a challenge or a product of challenges drawn in `define`
    Challenge { value: Fp2, label: &'static str },
}

pub enum Factor { Table(TableId), Node(NodeId) }

pub enum NodeBody {
    /// degree 1:  konst + sum_i coef_i * table_i
    Affine { konst: Fp2, terms: Vec<(Coef, TableId)> },
    /// degree = max over subterms of the sum of the factors' degrees
    Sum { subterms: Vec<SubTerm> },
}

pub struct SubTerm { pub coef: Coef, pub factors: Vec<Factor> }

pub struct Node {
    pub id: NodeId,
    pub label: &'static str,
    pub body: NodeBody,
    /// computed, asserted against a walk of the body
    pub degree: u8,
}

/// One top-level term: coef * prod(wrapper) * prod(inner).
/// `wrapper` is what this term shares with its group — the zero-check's
/// `eq(tau, .)` and, where the term carries it, the pad gate.  Grouping by
/// wrapper is the ONLY reassociation the evaluator is allowed to invent.
pub struct SlotTerm {
    pub coef: Coef,
    pub wrapper: Vec<TableId>,
    pub inner: Vec<Factor>,
    pub note: &'static str,
}

pub struct SlotIr {
    pub slot: u8,
    pub profile: &'static str,   // the shape's profile string: an IR is per SHAPE
    pub main_rounds: u8,
    pub extension_rounds: u8,
    /// the DECLARED degree (`Shape::slots`), which is what the round message
    /// length is built from.  `max_term_degree()` is computed and may be
    /// lower (section 1.4); the evaluator uses the DECLARED one.
    pub degree: u8,
    pub tables: Vec<TableRef>,   // in push order == terminal order
    pub nodes: Vec<Node>,        // topologically ordered: a node only refers back
    pub terms: Vec<SlotTerm>,
}
```

The JSON the Python gate would read is this structure with the challenge
values as decimal pairs; `results/zk60_slot_ir/slot_ir_m125.json` is a
generated sketch of it (121 KB for all 23 slots at the 125M shape, structure
only — it carries provenance labels, not challenge values, because a
definition-time challenge is per proof and the shape-level export is per
shape). The gate reads the STRUCTURE from the export and the VALUES from the
transcript it re-derives itself; see §6.

```json
{
  "slot": 5, "name": "SC_QMM", "kind": "private",
  "main_rounds": 10, "extension_rounds": 1, "declared_degree": 2,
  "tables": [
    {"index": 0, "kind": "A",   "field": "base", "label": "A_Y"},
    {"index": 1, "kind": "pub", "field": "ext",  "label": "fold(Wq, r_j)"}
  ],
  "nodes": [],
  "terms": [
    {"coef": "1", "coef_provenance": "one", "wrapper": [],
     "factors": [{"table": 0}, {"table": 1}], "degree": 2,
     "note": "plane * folded weight"}
  ]
}
```

### 2.2 What the IR says about each special construct

* **The zero-check wrapper.** A zero-check slot's whole arm sits under
  `eq(tau, ·)`. In the IR that is the term's `wrapper`, and the evaluator
  multiplies it in once per group instead of once per term. The hosted
  sub-claims are separate terms with their OWN wrapper (`eq(p_a)`,
  `eq(p_z)`, `eq(pq)`, `eq(p_o)`, `eq(p_ht)`, `eq(p_s)`, `eq(r_t)`,
  `eq(r_t2)`), because a host term is a different eq and cannot share.
* **Bilinear slots 08 and 09.** The group bits are SUMCHECK VARIABLES, and
  the public factor is `TableKind::GroupEq { bits: lkv }` over the LEADING
  `lkv` variables (`Tab::Eq { start: 0 }`). The IR records `bits`, so an
  exporter at a one-key-value-head shape emits a two-factor term of degree 2
  and at a four-group shape a three-factor term of degree 3, which is the
  S19-F1 repair restated as data. A reader of the export can check `bits ==
  log2(kv_heads)` from the shape alone.
* **The LogUp slots.** Each helper is ONE `Sum` node with two or three
  subterms (`h·d1·d2 − d1 − d2`, or `h·d1 − 1` for the odd last helper), and
  each denominator is one `Affine` node `alpha − (cst + c·plane)` with a
  single `Coef::Base` term — because every lookup of this profile has exactly
  one table term (`byte`, `scaled`, `sym` in `layout::lookups_at`). The IR
  must record that the LogUp arm is **NOT** under the support gate; it is a
  different term group from the clause arm and the grammar makes that
  visible rather than commented.
* **The pad-rule terms.** They exist only when `pad_on` is true for the slot
  at the shape — `pad::pad_zero_host(dom) == slot` and
  `pad::zero_rule_a_planes(shape, dom)` non-empty. The IR is built PER SHAPE,
  so the export simply has no pad node and no `Support` table at a shape
  where the domain is exact. That is the form of M-F1's repair: the gate no
  longer decides the branch, it reads it.
* **The extension rounds and the CFS mask stay OUTSIDE the IR.** What lives
  in `zk.rs` / `zkp-core/src/sumcheck.rs` and must not move into an IR:
  the masking polynomial `g` and its closed-form round messages
  (`CfsMask::round`), the multiplier `c`, the addition `s_j + c g_j`
  (`CfsMasker::mask_round`), the masked terminals
  (`masked_terminal`), the transcript, and the extension round's own
  interpolation (`extension_round`). The IR describes `f`, never `f + c·g`.
  The extension round DOES call the same `poly` on the interpolated
  `(finals, exts)` vector — so an IR evaluator serves it too, but with
  `degree + 1` evaluations total, not per pair index: it is not a hot path.
* **Table CONSTRUCTION stays outside the IR too.** `priv_table`, `eq_cube`,
  `fold_rows_i8`/`fold_cols_i8`, `causal_mask_at`, `rope_tables_at`,
  `pad::indicator_table`, `table_values_*` — the IR NAMES a table, it does
  not build one. That boundary is deliberate: the coordinate lists
  (`Coord::Rho` / `Flip` / `Fixed`) are where the claim points and therefore
  the privacy-relevant structure live, and they stay in `argument.rs` where
  the reserved-pair audit can see them.

### 2.3 Three slots, fully encoded

**(i) The simplest matmul, slot 05 `SC_QMM`.** Two tables, one term, no node.

```rust
SlotIr {
  slot: 5, main_rounds: 10, extension_rounds: 1, degree: 2,
  tables: vec![
    TableRef { id: 0, kind: PlaneA,  field: Base,      label: "A_Y at (r_q fixed, rho)" },
    TableRef { id: 1, kind: Public,  field: Extension, label: "fold_rows_i8(Wq, eq(r_j))" },
  ],
  nodes: vec![],
  terms: vec![ SlotTerm { coef: One, wrapper: vec![], inner: vec![Table(0), Table(1)],
                          note: "plane * folded weight" } ],
}
```

Cost per evaluation point: one multiplication. In round 0 it is
extension-times-base (2 `Fp` muls) because table 0 is a witness plane; from
round 1 it is 5. That is the whole of lever (a) for this slot, and it is 20%
of its round-loop cost [COUNTED].

**(ii) The softmax zero-check, slot 17 `SC_SZC` — the most expensive.**
Thirty tables (table ids as in §1.3; the full generated listing is in
`slot_ir_detail_m125.txt`). Abbreviating `t_k` for table `k`:

```
tables  t0 eq(tau) t1 eq(p_ht) t2 eq(p_s) t3 causal-mask
        t4 A_S8  t5 A_RSL  t6 A_ZSEL  t7 A_E  t8 A_P
        t9..t10  A_PL0..1        (limbs_p = 2)
        t11..t13 A_SR0..2        (limbs_sigma_s = 3)
        t14..t16 A_SG0..2
        t17 A_MX  t18 A_SUM      (Dom::Ht slices, leading coordinates)
        t19..t26 H_S0..7  t27 H_SEXP
        t28 supp(Dom::Ht), lifted over the trailing j axis
        t29 supp(Dom::S)

forms   <mx+127>  = 127 + t17
        <s8+127>  = 127 + t4
        <sr>      = 1*t11 + 256*t12 + 65536*t13                 (Base coefs)
        <c3>      = 1 + <sg> + <sr> - t18
        <c4>      = t8 - <pl>
        <den_S_0..14>  = alpha - (cst + c*plane), one Base coef each

nodes   (delta)   = <mx+127> - t3 * <s8+127>                          deg 2
        (c0)      = t6*t6 - t6                                        deg 2
        (c1)      = t6 * (delta)                                      deg 3
        (c2)      = 2^F_P * t3*t7  -  t8*t18  -  <sr>                 deg 2
        (clauses) = mu0*(c0) + mu1*(c1) + mu2*(c2) + mu3*<c3> + mu4*<c4>   deg 3
        (alpha-..)= -(delta) - beta*t7 + (alpha - g_exp)               deg 2
        (cx)      = t27 * (alpha-..) - 1                               deg 3
        (logup_S_k) = t_{19+k} * <den_2k> * <den_2k+1> - <den_2k> - <den_2k+1>   deg 3
                      k = 0..6, and (logup_S_7) = t26 * <den_14> - 1    deg 2
        (pad)     = (1 - t28) * (zeta^0 t17 + zeta^1 t18)
                  + (1 - t29) * (zeta^2 A_S8 + ... + zeta^13 A_SG2)    deg 2
        (zc)      = t29 * (clauses) + mu_cx*(cx)
                  + sum_k mu_S_k*(logup_S_k) + mu_pad*(pad)            deg 4

terms   1        * [t0] * (zc)                                         deg 5
        nu0*per_row * [t1, t28] * <host_rs: t18 + lam_z>               deg 3
        nu1      * [t2, t29] * <host_s: 2^6 t4 + t5 - 2^5>             deg 3
```

Seventeen sum nodes, twenty-six affine forms, 121 monomials if flattened,
three top-level terms [COUNTED]. Three things a reader should check against
the Rust: `(delta)` is shared between `(c1)` and `(cx)` — the closure computes
it once and the IR names it once; `(cx)` and the LogUp arm sit OUTSIDE `t29`,
the support gate, while `(clauses)` sits inside it; and the `Dom::Ht` host
term takes `t28`, the LIFTED `supp_Ht`, not `t29` — `supp_S` would be zero
wherever `j` pads and would force a true row's maximum to zero (finding
S9-F7). All three are in the generated listing.

**(iii) Bilinear slot 08 `SC_SCORE`.**

```rust
SlotIr {
  slot: 8, main_rounds: lkv + log2(head_dim), extension_rounds: 2,
  degree: 2 + (lkv > 0) as u8,
  tables: vec![
    // present only when lkv > 0
    TableRef { id: 0, kind: GroupEq { bits: lkv }, field: Extension,
               label: "eq(r_g, rho[..lkv])" },
    TableRef { id: 1, kind: PlaneA, field: Base,
               label: "A_QR8 at (r_t fixed | group summed | r_hj fixed | c)" },
    TableRef { id: 2, kind: PlaneA, field: Base,
               label: "A_KR8 at (r_j fixed | group summed | c)" },
  ],
  nodes: vec![],
  terms: vec![ SlotTerm { coef: One, wrapper: vec![0], inner: vec![Table(1), Table(2)],
                          note: "eq(r_g) * the two private factors" } ],
}
```

The whole content of the S19-F1 repair is in two facts the IR states: `bits ==
log2(kv_heads)` (so the group is a summed variable, not a fixed coordinate of
both factors), and `start == 0` (so the `eq` reads the LEADING variables,
where the group sits, because coordinates are most-significant-first
throughout). Both are checkable from the shape by a reader of the export.

---

## 3. What it buys, as counts

All figures are **[COUNTED]** base-field (`Fp`) multiplications for one
proof, all 23 slots, from `results/zk60_slot_ir/slot_ir_counts.md`. Three
components are counted: the round loop (`(degree+1)` evaluations per pair
index, summed over all rounds of all slots), the table fold
(`a + r(b − a)`, one multiplication per table per pair index per round), and
the claimed sum (`argument::total`, one evaluation per cube point — paid by
the twelve PRIVATE slots only (of 23: 12 private, 6 host, 5 standalone);
host and standalone slots publish
`c · mask.total()` or a batched host scalar and never walk their cube for it).

### 3.1 The three levers, cumulative

**rung-W14:**

| form | round loop | fold | claimed sum | total | marginal |
|---|--:|--:|--:|--:|--:|
| closure as written (the baseline) | 691,163,010 | 51,531,975 | 3,317,760 | **746,012,745** | — |
| + (b) shared sub-expressions, hoisted wrappers, coefficients typed by provenance | 602,073,834 | 51,531,975 | 3,317,760 | 656,923,569 | **11.9%** |
| + (a) base-field operands in round 1 | 458,586,346 | 42,031,239 | 3,317,760 | 503,935,345 | **23.3%** |
| + (c) finite differences per sub-expression | 256,019,524 | 42,031,239 | 3,317,760 | **301,368,523** | **40.2%** |
| all three together | | | | | **59.6% of the baseline removed** |

**125M:**

| form | round loop | fold | claimed sum | total | marginal |
|---|--:|--:|--:|--:|--:|
| closure as written (the baseline) | 15,282,222,978 | 1,096,105,095 | 99,678,720 | **16,478,006,793** | — |
| + (b) | 13,482,649,066 | 1,096,105,095 | 99,678,720 | 14,678,432,881 | **10.9%** |
| + (a) | 10,254,440,426 | 891,965,319 | 99,678,720 | 11,246,084,465 | **23.4%** |
| + (c) | 5,901,986,052 | 891,965,319 | 99,678,720 | **6,893,630,091** | **38.7%** |
| all three together | | | | | **58.2% of the baseline removed** |

Per slot, the saving runs from 20.0% (the seven matmuls, which have one
product and nothing to share) to **65.3% at slot 14** and **58.8% at slot
17**, the two most expensive. The per-slot column is in `slot_ir_counts.md`.

### 3.2 What each lever is, precisely

**(a) Base-field products formed before the single extension factor, in round
1.** After round 0 every table word is `v0 + r(v1 − v0)` with `r` an
extension challenge, so nothing is base-field again. Round 0 is therefore the
only round this applies to — but it is `2^{n-1}` of the `2^n − 1` pair
indices of the slot, very nearly half the work. Within round 0 the
specialisation is exact: `cur[t] = v0 + t·(v1 − v0)` with `v0, v1` base-field
is base-field at every evaluation point `t`, which is the lane ledger's own
argument for why a WHOLLY base-field table is the right unit. **143 of the
229 tables at both shapes are wholly base-field [COUNTED]**, consistent with
the 62.1% of WORDS the census MEASURED over its five slots. The gain is per
multiplication: 5 `Fp` muls → 2 when one operand is base, → 1 when both are.
It also halves the round-0 read of those tables and their resident size, if
`priv_table` hands out `Fp` cubes instead of `Fp2` ones (§4, §5).

**(b) Common sub-products shared across terms, wrappers hoisted, coefficients
typed by provenance.** Three distinct things, counted together because they
are the same act of writing the polynomial down:

* *shared sub-expressions*: the closures already share some (`dl`, `a1`,
  `delta`, the `at(p)` reads); the IR shares all of them by construction,
  because a node is evaluated once by identity;
* *the wrapper hoisted*: `argument.rs`'s eleven-clause loop writes
  `zc += m.mul(g).mul(c)` — one multiplication by the support gate `g` PER
  CLAUSE, where `g · Σ mu_i c_i` needs one in total. Eleven multiplications
  become one at slot 14, five become one at 17, three become one at 18;
* *coefficients typed by provenance*: every `k(...)`, `pow256(k)`,
  `2^SH_*`, `2^NORM_TN` in `argument.rs` is a base-field constant lifted by
  `Fp2::from_base`, and `x.mul(k(c))` executes as a five-multiplication
  `Fp2::mul` today where `mul_base` is two. Slot 14 makes 31 such
  multiplications per evaluation out of 152 (16 byte-limb powers of 256, 5
  from the `l2` closure, 2 `2·NORM_CN`, 2 `2^NORM_TN`, 4 `2^(NORM_TN+1)`, 2
  host shifts) and slot 17 makes 10 of 75 (8 byte-limb powers, `2^F_P`,
  `2^SH_S`) [COUNTED, from the closure text].

**(c) Evaluation at `t = 0 … d` by finite differences per sub-expression.**
The round message needs the polynomial's values at `d + 1` points. Today the
whole closure is re-run `d + 1` times. But a sub-expression of degree `δ` in
`t` is determined by `δ + 1` values: compute it at `t = 0 … δ` and extend to
`t = δ+1 … d` by forward differences, which are ADDITIONS. An affine form
needs 2 evaluations, not `d + 1`; a LogUp relation of degree 3 needs 4, not
6; a clause of degree 2 needs 3. Since most of a big slot's work is in nodes
of degree 1 and 2 under a slot degree of 5, this is the largest single lever
— **38.7% at 125M on top of (a) and (b)** — and it needs no change of
representation at all, only the degree of each node, which the IR carries.

### 3.3 Why none of this changes a single byte that is sent

**The round polynomial's values are the same field elements.** Each lever is
one of three operations, and each is exact in a field:

* **(a) is a representation change, not an arithmetic change.** `Fp2::mul` of
  `(a, 0)` and `(c, d)` produces `(ac + 0·7, ad + 0)` = `(ac, ad)`, which is
  exactly `Fp2::mul_base`'s `(a·c, a·d)` with the roles swapped, and exactly
  what a base-times-base product gives when both imaginary parts vanish. The
  omitted multiplications are multiplications by zero and the omitted
  additions are additions of zero. No rounding exists to differ: `Fp` is a
  prime field.
* **(b) is reassociation and redistribution:** `Σ_i m_i · g · c_i =
  g · Σ_i m_i c_i` is distributivity, and evaluating a shared node once
  instead of twice is substitution of equals. Both hold in any commutative
  ring.
* **(c) is polynomial interpolation.** If `P` has degree `δ` in `t`, its
  values at `0 … d` are determined by its values at `0 … δ`, and the forward
  difference recurrence `P(k+1) = Σ_{j} (−1)^j … ` reproduces them exactly
  over any ring of characteristic 0 or of characteristic larger than `d`. The
  field's characteristic is a 64-bit prime and `d ≤ 5`, so the binomial
  coefficients involved are units and the recurrence is exact. (The
  implementation should use the integer-difference table, which needs no
  division at all.)

**The order of summation cannot matter.** The round message is a SUM over
pair indices, and field addition is associative and commutative with no
rounding, so any decomposition — one thread, 1,024-point rayon chunks, a GPU
block reduction, a different chunk size per round — produces the identical
element. This is the argument `zkp-core/src/sumcheck.rs` already makes for
its own parallel round ("the field sums are order-independent: the values are
identical") and `argument::total_at` repeats for the claimed sum; the IR
inherits it and adds nothing to it. It is why lever (c)'s reduction may be
restructured freely and why a GPU reduction tree is admissible.

**What WOULD move bytes, and is excluded:** lowering a declared degree
(§1.4), changing a challenge count, changing the absorb order, changing the
table push order (it is the terminal order), or changing which quantity is
published. None of the three levers touches any of these. The IR does not
change `define`'s draws, `run_slot`'s absorbs, `acc.order`, the claim list or
the M functionals.

### 3.4 Table memory traffic

| shape | words read per proof | words written | bytes read at 16 B | base-field tables |
|---|--:|--:|--:|--:|
| rung-W14 | 20,612,790 | 10,306,395 | 0.31 GiB | 143 of 229 |
| 125M | 438,442,038 | 219,221,019 | **6.53 GiB** | 143 of 229 |

Per round the loop reads `2 · k · half` words and writes `k · half`; summed
over a slot that is `k·(2^{n+1} − 2)` read and `k·(2^n − 1)` written. Handing
the 143 base-field tables out as `Fp` cubes halves their bytes: the resident
table set of the biggest slot at 125M drops from **1,920 MiB to 1,344 MiB**,
and the sum over all 23 slots from **3.27 GiB to 2.25 GiB** [COUNTED].

---

## 4. The shared-file interface

The integrator owns `zkp-core/src/sumcheck.rs` and `hashline/src/zk.rs`. The
lane owns `argument.rs`. The question is the smallest change to the first two
that lets the second supply an evaluator.

### Option A (recommended) — the evaluator owns its tables

`zkp-core/src/sumcheck.rs` gains a trait and one function; `prove` becomes a
thin wrapper that is the code it is today.

```rust
/// One sumcheck's round machinery, supplied by the caller.  The default
/// implementation (`ClosureRounds`) is the code `prove` has today and is what
/// `prove` uses, so the legacy path is untouched.
pub trait SumcheckRounds: Sync {
    fn n_vars(&self) -> usize;
    fn degree(&self) -> usize;
    /// Round `j`'s message: the values at t = 0 ..= degree of the sum over
    /// the remaining cube.  The implementor chooses its own decomposition;
    /// field addition is exact, so any order returns the same elements.
    fn round(&mut self, j: usize) -> Vec<Fp2>;
    /// Fold every table with `r` and halve it.
    fn fold(&mut self, r: Fp2);
    /// Each table's terminal value, in table order.
    fn finals(&self) -> Vec<Fp2>;
}

/// `prove`'s loop over an arbitrary round machine.  `prove` is
/// `prove_rounds(&mut ClosureRounds::new(tables, degree, poly), tr)`.
pub fn prove_rounds<R: SumcheckRounds + ?Sized>(r: &mut R, tr: &mut Transcript)
    -> ProverOutput
{
    let mut rounds = Vec::with_capacity(r.n_vars());
    let mut challenges = Vec::with_capacity(r.n_vars());
    for j in 0..r.n_vars() {
        let sums = r.round(j);
        tr.absorb_fp2(b"sc-round", &sums);          // unchanged
        let c = tr.challenge_fp2();                 // unchanged
        challenges.push(c);
        rounds.push(sums);
        r.fold(c);
    }
    ProverOutput { proof: SumcheckProof { rounds }, challenges, finals: r.finals() }
}
```

`zk.rs`'s `masked_prove` gains a sibling `masked_prove_rounds(r, mask, c, tr)`
that sets the masker, calls `prove_rounds`, and takes the masker — four lines,
and `masked_prove` becomes a call to it with a `ClosureRounds`. The masked
and extension rounds are unaffected: the masker is a transcript-level hook
(`RoundMask::mask_round`) that already sits between `sums` and `absorb_fp2`,
and `zk::extension` takes `finals` and `exts` and calls `poly` `degree + 1`
times on the host, where the closure can stay.

**Why this and not something narrower.** The trait lets the implementor own
the table STORAGE, and that is the only way (a) and the GPU are reachable:
the lane's evaluator can hold `Vec<Vec<Fp>>` for the 143 base-field tables in
round 0 and `Vec<Vec<Fp2>>` thereafter, and a device evaluator can hold
device pointers and never materialise a host table at all. A narrower
interface that keeps `&mut Vec<Vec<Fp2>>` in the shared file forecloses both.

**Why the legacy path cannot move.** `prove` keeps its signature and becomes
one line; `ClosureRounds::round(j)` is the existing `round_of` closure and its
rayon decomposition verbatim, and `ClosureRounds::fold(r)` the existing fold
verbatim. The absorb, the challenge draw and their order are in
`prove_rounds` and are the same three lines in the same order. Everything
that calls `sumcheck::prove` today is untouched: one site in `zk.rs`, two in
`attention.rs` and nine in `layer.rs` [COUNTED by grep at `226f3b2`], plus
the thirteen `masked_prove` sites, none of which needs to change.

### Option B — a batched evaluator beside the closure

Keep the tables in the shared file; add

```rust
pub trait RoundEvaluator: Sync {
    fn eval_range(&self, tables: &[Vec<Fp2>], half: usize, lo: usize, hi: usize,
                  out: &mut [Fp2]);   // out.len() == degree + 1, accumulated
}
```

and a `prove_ev(tables, degree, poly, ev: Option<&dyn RoundEvaluator>, tr)`
that uses `ev` for the inner accumulation when it is `Some`. Smaller, and it
buys (b) and (c) — roughly half the counted saving. It does NOT buy (a) (the
tables are `Vec<Fp2>` by signature) and it does not admit a device evaluator
(the tables are host slices by signature).

**Recommendation: Option A.** It is about twenty lines of shared-file change
against Option B's ten, it is byte-identical for the same reason, and it is
the only one of the two that the GPU work and the base-field work can both be
built on. Doing B first and A later means doing the shared-file change twice.

---

## 5. GPU mapping sketch

No performance number appears in this section. Data sizes and launch counts
only, all **[COUNTED]**.

**What a kernel needs from the IR.** Four things, all small and all constant
for a slot at a shape:

1. **table device pointers** — `k` pointers, plus a per-table word size (8 B
   for a base-field table in round 0, 16 B thereafter) and the current half
   length;
2. **a node/product list** — the `nodes` and `terms` arrays of §2.1,
   flattened into three integer arrays (node header: kind, degree, subterm
   count; subterm header: coefficient index, factor count; factor: a tagged
   `TableId`/`NodeId`). At slot 14, the widest, that is 22 nodes, 49 affine
   forms and 3 terms — **at most a few kilobytes**, comfortably in constant
   memory; the whole 125M IR as JSON is 121 KB and the binary form is far
   smaller;
3. **a coefficient array** — one `Fp2` per distinct coefficient, uploaded
   once per slot after `define` draws the challenges; base-field coefficients
   carry a flag so the kernel takes the two-multiplication path;
4. **the current round index** — so round 0 takes the base-field path.

**The round kernel.** One thread per pair index (or per small strip of them),
evaluating the IR into a private `[Fp2; degree+1]` accumulator by the (c)
schedule — each node at `t = 0 … its own degree`, extended by additions —
then a block reduction into a per-block `[Fp2; degree+1]`, then a second pass
(or an atomic-free two-stage reduction) to `degree + 1` values. Slot 17's
round 0 at 125M is 2,097,152 pair indices; the smallest slot's last round is
one. A device implementation should run the last few rounds on the host, as
the CPU path already does with its `half * k <= 2^16` cut-off.

**Folding between rounds.** Elementwise and embarrassingly parallel:
`a[i] = a[i] + r (a[i + half] − a[i])` for `i < half`, one kernel over
`k · half` elements, in place, followed by a logical halving (no copy). In
round 0 the base-field tables are read as `Fp` and written as `Fp2`, which is
one allocation per base-field table per slot and is the memory peak.

**Where the round messages come back.** Every round: the `degree + 1` reduced
`Fp2` values cross to the host, the host absorbs them into the blake3
transcript, adds `c·g_j` from the CFS mask (host-side, a closed form over the
mask coefficients — see §2.2), draws the challenge and sends back one `Fp2`.
**At 125M that is 336 main rounds plus 25 extension rounds over the 23 slots,
1,554 `Fp2` values in total = 24,864 B crossing back over the whole proof**
[COUNTED] — 0.06% of the 40,783,352 B receipt. The round trip is a latency
question, not a bandwidth one.

**What stays on the host.** The transcript (blake3, and it is sequential by
construction), the CFS masks and their round messages, `mask_eval` and the
extension rounds, the PCS claims and openings, the M functionals, the wire
frame. And, for now, the two commitments — which is the Amdahl point in §8.

**Memory at 125M, against an 8 GB and a 32 GB card** [COUNTED]:

| resident set | as `Fp2` throughout | with base-field tables as `Fp` |
|---|--:|--:|
| the biggest single slot's tables (17 `SC_SZC`, 30 × 2^22) | 1,920 MiB | 1,344 MiB |
| second biggest (14 `SC_DZC`, 60 × 2^19) | 480 MiB | 320 MiB |
| all 23 slots' tables at once | 3.27 GiB | 2.25 GiB |
| the committed planes `A` and `H` (5,681 + 7,120 rows of 2^14 `Fp` words) | 1.56 GiB | 1.56 GiB |
| **slot-at-a-time working set (A + H + the biggest slot)** | **3.44 GiB** | **2.87 GiB** |
| **whole-block working set (A + H + all slots)** | **4.83 GiB** | **3.81 GiB** |

(The `A` and `H` row counts are **[MEASURED]**, from the run-gate report
`ZK60_NATIVE_RUN_GATE.md` §13.4's per-commitment table at 125M; the byte
figures are **[COUNTED]** as rows × 2^14 × 8 B.)

Both fit an 8 GB card slot-at-a-time with room to spare, and the whole block
fits too, which means the tables could be built once on device from the
committed planes rather than streamed per slot. On a 32 GB card the question
does not arise. The 5090 bring-up (`ZK60_5090_LINUX_BRINGUP.md`) and the
laptop 4070 are therefore both in range for the round loop — but note the
WSL VRAM rule: on the laptop, exhausting VRAM freezes the whole box, so a
device implementation must cap its allocation from the counted figures above
and refuse rather than try.

**Launch counts at 125M** [COUNTED]: 336 round kernels + 336 fold kernels
(or 336 fused ones) + 25 extension rounds on the host, plus one upload of the
coefficient array per slot (23) and one table build per slot. At rung-W14 it
is 292 + 292 + 25. Per-launch overhead therefore matters for the *small*
slots, not the big ones: slot 05's whole cube is 2^10 words.

---

## 6. How the Python gate consumes it

**The export.** A TEST-ONLY Rust exporter (`#[cfg(test)]`, beside
`run_capture.rs`) walks `define`'s `SlotIr` for a shape and writes the JSON of
§2.1 — the structure, not the values. It is pinned into the capture bundle by
SHA-256 exactly as the bundle already pins its source files and its arrays,
so a bundle names the IR it was produced under. `results/zk60_slot_ir/slot_ir_m125.json`
is a sketch of that file at the 125M shape (121 KB, 23 slots).

**What the gate does with it.** `zk60_native_rg_terminals.py` today holds
`sc_tzc`, `sc_szc`, `sc_fzc`, … — one hand-written Python function per slot,
each re-deriving the polynomial from the Rust by reading. Under the export it
would instead evaluate the terminal identity FROM the IR: walk the node list,
read the challenge values it has ALREADY re-derived from the transcript
itself (the gate re-derives all 27,828 challenges of a 125M capture — round 9
of the run gate, `ZK60_NATIVE_RUN_GATE.md` §13.4 stage (a) — so it never
takes a challenge from the bundle), and check `fin − c·g(rho) == poly(vals)`
slot by slot.

**What independence is lost, said plainly.** Today the gate's port is an
independent RE-DERIVATION of the prover's statement: two people read the same
specification and wrote two programs, and a disagreement is a finding. Under
the export the gate would be checking that the prover is consistent with the
prover's own description of itself. A prover bug that is also present in the
IR — because the IR was generated from the same buggy `define` — would pass.
That is a real loss and it should not be dressed up.

**How to keep enough of it.** Three things, and the first is not optional:

1. **The oracle test on the Rust side** (§7): the IR must equal the CLOSURE
   at every registered shape on random tables. That makes the export a
   faithful description of the prover — which is exactly the property the
   gate would be assuming, now asserted rather than assumed. It does not make
   either of them right, but it turns "the gate trusts the exporter" into
   "the gate trusts one tested equality".
2. **Keep one hand-ported family, permanently.** The nine cheapest slots —
   the seven matmuls (2 tables, 1 term) and the two bilinear slots (3 tables,
   1 term) — cost almost nothing to maintain by hand and cover the construct
   the project has already been bitten by once (S19-F1's group bits). The
   gate checks those nine BOTH ways and refuses on a disagreement. The
   expensive twenty-three-slot hand port goes away; the cheap nine stay.
3. **Prediction before measurement, from the shape alone.** This is the check
   that would have caught M-F1, and it does not depend on the export at all:
   before reading the IR, the gate derives from the SHAPE — tokens, width,
   heads, `log_cols`, `f_e` — every slot's main round count, extension round
   count, declared degree, table count by kind, and **definition draw count**
   (`tau` + `mu(n + n_pad)` + `nu(2)` + `zeta(n_pad)`), and refuses if the
   export or the transcript disagrees. M-F1 was precisely a draw-count
   divergence on `pad_on`; the run gate's round 9b already added control M9-3
   for it, and the same control applies unchanged to an export. The gate must
   also refuse an export whose `profile` string is not the capture's.

A fourth, cheap: the export carries the IR's max product degree beside the
declared degree, and the gate checks both against its own walk of the graph —
which is a free consistency check on the exporter's arithmetic (and which is
where §1.4's four slots show up).

---

## 7. Test plan for byte identity, without deterministic receipts

**The obstacle, and the way round it.** A private-block receipt is not
reproducible: the masks come from `ZkRng::from_os` and every attempt draws
fresh OS entropy. That is an accepted privacy condition (finding S28-F2,
ruling V-5) and must not be relaxed. But **the prover's entry point takes the
generator as a parameter**: `protocol::prove_core(sh, lay, blk, wit, io, ntt,
rng: &mut ZkRng, tr, …)`, and `ZkRng::new(seed, domain)` exists and is
documented "legacy deterministic stream for public test fixtures ONLY"
(`zkp-core/src/rng.rs:19`). So a TEST can prove twice from the same seeded
stream and compare receipts byte for byte, while PRODUCTION keeps
`prove_inner_at`'s `from_os`. That gives a true byte-identity gate without
touching the privacy condition, and it should be the headline test.

The plan, in the order it should be written:

1. **IR against the closure, per slot, on random tables.** For every slot and
   every registered shape — `toy`, `rung`, `rung_g`, `rung_k4`, `rung_p2`,
   `rung_c6`, `rung_w14`, `rung_e32` (and 125M once, §7.7) — build the slot
   definition, fill each table with random `Fp2` (and, separately, with
   BASE-FIELD-ONLY words in the base-field tables, so the (a) path is
   exercised), and assert `ir_eval(row) == (def.poly)(row)` for a few
   thousand random rows. The oracle is the closure, which does not change.
2. **Round-message equality, not just the final claim.** For a fixed
   transcript, assert that the `degree + 1` values of EVERY round of every
   slot are identical elements between the closure evaluator and the IR
   evaluator. A final claim can agree while an intermediate message does not,
   and it is the messages that are hashed.
3. **Both branches of every threshold.** Stage 29 made five thresholds
   arguments of inner functions for exactly this: `TABLES_PAR_MIN` (2^17),
   `TOTAL_PAR_MIN` (2^14), `LOOKUP_PAR_MIN` (2^17), `HISTOGRAM_PAR_MIN`
   (2^17), `HELPER_PAR_MIN` (2^14). Drive both sides of each on the same
   input, and drive the IR evaluator's own decomposition threshold both ways
   too. Under `RAYON_NUM_THREADS` 1, 2 and 8 — the lane's existing practice
   (`r29-s29-threads.log`).
4. **Both arms of the pad rule.** `rung_p2` is the shape stage 30 built so
   that `{T, Kv, F}` are exact and `{Ht, L, D, Q, S, Tab}` pad — 125M's own
   set. Every IR test must run there, or the `pad_on == false` arm of slots
   02, 16 and 18 is again reached only by an ignored heavy test, which is the
   M-F1 condition. `rung_c6` covers correction C-6's four dropped `Dom::D`
   lookups, which change slot 14's helper count and therefore its IR.
5. **A byte-identity gate on a seeded stream.** Call `prove_core` twice with
   `ZkRng::new(seed, domain)` — once with the closure evaluator, once with
   the IR evaluator — and assert the two receipts are equal BYTE FOR BYTE, at
   `toy`, `rung_p2`, `rung_c6` and `rung_w14`. This is the strongest
   statement available and it costs one test.
6. **The verifier does not change, and old receipts prove it.** The verifier
   calls `(def.poly)(&vals)` exactly ONCE per slot, on the terminals: it is
   not a hot path and the closure stays there. So
   `review_tests::a_toy_receipt_made_before_the_lane_still_verifies` and the
   receipt-length family (2,816,472 B toy; 4,742,728 B rung-P2; 7,452,040 B
   rung-C6; 11,368,824 B rung-E32; 16,421,048 B rung-W14; 40,783,352 B 125M)
   must all stay green unchanged, and a receipt made by the OLD prover must
   verify under the new tree.
7. **The 125M run once**, detached under `flock /tmp/zk-heavy.lock` with a
   `.done` marker, asserting the 40,783,352 B length and a clean verify from
   bytes. Not a timing claim — a correctness gate at the only shape that
   reaches `Dom::S` at 2^22.
8. **The whole `--lib private_` filter green**, at the count it stands at
   (394 passed / 0 failed / 17 ignored at `226f3b2`), plus the new tests, and
   the forbidden-files proof for whatever is not in the declared lane.

---

## 8. Migration in stages, and the case against

### 8.1 The stages

Each keeps the filter green and moves no byte.

| # | what | who | moves a byte? |
|---|---|---|---|
| 1 | The `SlotIr` types and a builder beside each arm of `define`; `define` returns the closure AND the IR; nothing calls the IR. The oracle test of §7.1 at every registered shape. | lane only | no — the IR is dead code on the proving path |
| 2 | An IR-driven CPU evaluator used for `argument::total` (the claimed sum) only, with an equality gate. `total` is in `argument.rs`, so still no shared file. | lane only | no |
| 3 | `SumcheckRounds` + `prove_rounds` in `zkp-core/src/sumcheck.rs`; `prove` becomes `prove_rounds(&mut ClosureRounds…)`; `masked_prove_rounds` in `zk.rs`. | **integrator** | no — the absorb, the draw and their order are the same three lines |
| 4 | The lane's IR evaluator implements `SumcheckRounds` with (b) and (c); the round-message equality gate of §7.2 at every shape; the seeded byte-identity gate of §7.5. | lane, on 3 | no |
| 5 | `priv_table` hands out `Fp` cubes for the wholly base-field tables; the evaluator takes the base-field path in round 0 and returns `Fp2` after the first fold. Lever (a). | lane + a small integrator review of the trait's storage contract | no |
| 6 | A device evaluator behind the same trait, host transcript, counted memory caps. | new work | no |
| 7 | The test-only JSON exporter, the bundle pin, and the gate's IR-driven terminal identity with the nine hand-ported slots kept (§6). | lane + gate | no |

**If only one thing is done, do stage 1.** It is lane-only, it changes no
execution path at all, and it is the prerequisite for every other stage, for
the GPU, for the exporter and for every count in this memo — which are
currently produced by a Python transcription that will drift the moment
`argument.rs` changes. Stage 1 makes the counts a property of the code.

**If two, add stage 3.** It is the only shared-file change in the list, it is
small, and doing it once (as Option A) rather than twice is worth an
integrator's attention early.

### 8.2 Risks, and the arguments against doing this

Argued as strongly as I can make them.

**1. The closures may not be the bottleneck the counts suggest, and an
interpreter may be slower than them.** The counts here are of MULTIPLICATIONS.
They say nothing about the indirect call, the branch predictor, or the
instruction cache — and a monomorphised Rust closure over a fixed `&[Fp2]`
compiles to straight-line code with the table indices as immediates, while an
IR *interpreter* walks a node list with a switch per node. It is entirely
possible for an IR evaluator to remove 40% of the multiplications and be no
faster, or slower. **Mitigation, and it should be designed in from the
start:** the IR is a source for a CODE GENERATOR, not only for an
interpreter. A `macro_rules!`/`build.rs` pass that emits one monomorphised
`SumcheckRounds` impl per slot per degree gets the counted arithmetic with the
closure's code shape. The interpreter is then the reference and the fallback.
Until a quiesced measurement exists, **nothing in this memo may be relayed as
a speed result.** (And measurement must wait: the box is not quiesced, and
this project's own figure for run-to-run spread here is up to a factor of
two.)

**2. The GPU may be bound by the commitments, not the rounds.** The two
[MEASURED] phases are 28.1% (rounds) and 23.7% (commitments) of that 24.59 s
tree. Moving the rounds alone and leaving the commitments on the CPU caps the
whole-prove gain at what Amdahl allows — and the rest of the prove (roughly
half) is neither. The IR does nothing whatever for `pcs::commit_zk_owned`.
A five-second target needs both, and the commitment side is a separate design
with its own memory question. **This memo should not be read as a plan to
reach 5 s; it is a plan to make one of the two halves movable at all.**

**3. An IR is a second source of truth, and this project has been bitten by
exactly that.** Finding M-F1 was a hand port diverging from the prover on a
branch no small shape reached. An IR that is hand-transcribed beside the
closures is the same shape of risk one level in. **Mitigations, in order of
strength:** (i) generate the CLOSURE from the IR once confidence exists, so
there is one source again; (ii) until then, the oracle test at EVERY
registered shape including both pad arms (`rung_p2`) and the C-6 arm
(`rung_c6`), not merely at the toy; (iii) the IR is built per SHAPE from the
same `Shape` methods the definition uses, never from a parallel table of
constants. Note that this memo's own Python model is exactly the artefact
this risk is about — it agrees with the MEASURED census and with the lane's
layout model today, and it will drift tomorrow. It is evidence for a design
decision, not a component.

**4. The degree finding is a trap.** §1.4 says four slots declare one degree
more than they use. The temptation is to take a free 17–20% off those slots
by lowering it. That moves bytes, changes every receipt length, needs a new
profile and a security ruling, and would have to be re-argued against the
soundness bound. It must not be smuggled in with a "moves no byte" migration.

**5. Effort, and where it is genuinely risky.** Twenty-three slot arms, each
a soundness-relevant statement, transcribed into a second form. The dangerous
ones are not the big ones — slot 14 is long but mechanical — but the ones
with a conditional structure: the pad arms (present or absent by shape), the
bilinear group gate (present or absent by `kv_heads`), the odd last LogUp
helper, correction C-6's dropped lookups, and `SC_SZC`'s two-domain pad group.
Every one of those is a branch that a test at one shape will not reach. The
test matrix of §7.4 is the whole defence.

**6. Nothing here helps the verifier, and nothing here helps the receipt.**
The verifier evaluates each polynomial once; the receipt is 40,783,352 B at
125M and this changes none of it. If the binding constraint turns out to be
receipt size or verify time, this is the wrong work.

---

## 9. What this memo is not

* **Not an implementation.** No production code was changed. The only files
  written are this memo and `results/zk60_slot_ir/`.
* **Not a speed result and not a speed prediction.** Every figure is a count
  of field multiplications, words, bytes or launches. The two time figures
  quoted (17.4–19.4 s for a 125M block; the 28.1% / 23.7% attribution) are
  MEASURED and are quoted from the lane ledger with its own caveats,
  including that the 24.59 s denominator is a working tree and no commit. A
  counted reduction in multiplications is not a second saved, and this memo
  makes no claim about what any of it would run at.
* **Not a change to any privacy or soundness statement.** The receipt's
  non-reproducibility stays (S28-F2 / ruling V-5); the masked terminals, the
  reserved pairs, the claim list, the M functionals and the absorb order are
  untouched; the pad rule, the support indicator and the LogUp arm's
  exemption from it are described, not revised; the declared degrees are
  described, not revised.
* **Not a privacy acceptance of anything.** The lane's code remains
  experimental (ruling V-1).
* **Not a decision.** It is a design and a set of counts for the integrator
  and the security owner to rule on. The one thing it asks for is stage 1.
