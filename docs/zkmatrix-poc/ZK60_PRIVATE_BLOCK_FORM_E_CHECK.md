# Independent check of "Form E" (ZK60_PRIVATE_BLOCK_FORM_E.md)

**STATUS: COMPLETE.** Adversarial re-derivation by an independent checker
for the security owner, 2026-09-19. Read-only on all code and on the draft.
Nothing here establishes a privacy property; every rank is a rank on a small
linear model and is evidence about that model only. D8/D11 are not touched.

Method model: `ZK60_PRIVATE_ENDPOINTS_AT_SCALE_CHECK.md` §0, §1 and its
errata table. Findings are ranked **BLOCKING**, **CORRECTION** or **NOTE**
and every disagreement carries the draft's line, the source's `file:line`
and a corrected value.

## 0. How this check was run

I read the draft in full (1,713 lines), then re-derived each of its
load-bearing claims from source. Every `file:line` below was opened. No code
was edited, no cargo run, no GPU, no git write.

New files, all under `results/zk60_form_e_check/`:

| file | what it is |
|---|---|
| `smallmodel_orig.py` | verbatim copy of `scripts/zk60_native_jv_smallmodel.py` from branch `zk60-native-jointview` (never edited) |
| `jv_field.py` | verbatim copy of `scripts/zk60_native_jv_field.py` from the same branch (Goldilocks / Fp2 / exact rank) |
| `seam_smallmodel.py` | **the extension**: two commitments, one aliased plane, the seam's published quantities, 17 cases |
| `seam_smallmodel_out.json` | its output |
| `.done` | exit code |

Ranking: **BLOCKING** = the construction is wrong or unsafe as written and
must change before code; **CORRECTION** = a number, a citation or a claim in
the draft is wrong and the corrected value is given; **NOTE** = true but
incomplete, or a condition the draft omits.

## 1. Hiding with a seam — the small-model experiment (item 4)

### 1.1 What was built, and what it is not

`results/zk60_form_e_check/seam_smallmodel.py` is the joint-view gate's
negative-control model with a second commitment and a seam bolted on. Two
commitments `L` (the attention side) and `R` (the feed-forward side), each
with the row order *[plane rows | side-private data rows | one reserved pair
per claim | proximity pair]*, `N = 4` message positions per row, `q_pad`
pads, `INV_RATE 4`, columns sampled without replacement, and

    disclosed = rank([M_rand | M_data]) − rank(M_rand)

by brute-force dense rank over Fp, exactly as the original.

The **aliasing** is the point: the plane rows of `L` and of `R` are the
*same free variables*. Everything else — the two sides' pads, salts-free
mask rows and proximity pairs, and the CFS slot — is independent.

Every structure is transcribed from source, not invented:

| object in the model | source |
|---|---|
| the seam claim's three parts `((1−e) on the data slice at ρ, e on mask row r, e·U on mask row r+1)`, value = the published masked terminal | `hashline/src/zk_ffn_fresh_io.rs:204-235` |
| `masked_terminal(fin, ext, e) = (1−e)·fin + e·ext` | `zkp-core/src/sumcheck.rs:312-314` |
| `ext_k` = that side's mask **pair** evaluated at the column tail, `re + U·im` | `zk_ffn_fresh_io.rs:201-203` |
| the seam polynomial `v0·(v1 − v2)` | `zk_ffn_fresh_io.rs:198-200` |
| `nb_d` data parts with coefficients `μ_c(1−e)` under one column key | `zkp-core/src/pcs.rs:752-831`, `ZK60_PRIVATE_ENDPOINTS_AT_SCALE.md` §3.3 form 2 |
| the extension round `s_k(x) = poly((1−x)fin + x·ext) + c·g_k(x)` | `zkp-core/src/sumcheck.rs:297-309`, `hashline/src/zk.rs:984-997` |
| the CFS mask's `sum_weights`, `eval_weights`, `round(j, prev)` — transcribed coefficient by coefficient | `zkp-core/src/sumcheck.rs:222-274` |
| the opening view: group vectors over `N + q` coordinates, the proximity vector, one Fp functional per (row, sampled column) | `zkp-core/src/pcs.rs:915-944` |

**This establishes no privacy property.** It is a rank on a small linear
model of an idealised view; the hash layer, the nonlinear CFS↔PCS link, the
adaptive lift and D8/D11 are all outside it, exactly as in the joint-view
report.

### 1.2 One structural fact the draft does not state, and it is the reason the answer is 0

On the honest witness the two seam tables are **pointwise equal**, so the
seam's polynomial `v0·(v1 − v2)` is **identically zero on the whole cube**.
Therefore:

* every masked round message is *exactly* `c·g_j(X)` — the data part is not
  merely small or hidden, it is **zero as a function of the data variables**
  (`zk.rs:984-997` adds `c·g_k` to a term that vanishes);
* the claimed sum is `γ = c·g_s.total()` with **no** data term, which is
  literally what the code sets (`zk_ffn_fresh_io.rs:295`);
* the extension round reduces to `(1−x)·x·eq(τ,ρ)·(ext_L − ext_R) + c·g_k(x)`,
  a functional of the two sides' mask pairs only;
* the only data-bearing published quantities of the whole seam are the two
  masked terminals, each of which **is** its side's seam claim value and is
  blinded by that side's own reserved pair.

The draft gets the terminal half of this right (§D.4 step 3, line 866-873)
but says nothing about the rounds; its §E.1 line 989-993 calls `c ≠ 0` a
*hiding* condition. In this model it is not (case 5 below). **CORRECTION.**

### 1.3 Predictions, written before the runs

| # | case | predicted |
|---:|---|---|
| 0 | honest, plane aliased, seam included | 0 |
| 1 | not aliased, no seam | 0 |
| 2 | `nb_d = 3`, μ-batched | 0 |
| 3a | both terminals blinded from ONE source, plane **aliased** | **0** (I disagree with the draft, which predicts > 0) |
| 3b | the same, plane **not** aliased | > 0 |
| 4 | the seam claim reuses an ordinary claim's pair on one side | > 0 |
| 5 | `c = 0` | **0** (I disagree with the draft, which predicts > 0) |
| 6 | `e = 0` | > 0 |
| 8 | a second masking commitment's functional added | 0, and equal to the sum |
| 9 | one side opened twice | > 0 |
| 10 | `q_pad` = distinct opened columns | 0 |
| 11 | two seams at the **same** terminal point (groups merge) | 0 |
| 12 | two seams at independent points | 0 |
| 13 | one pad fewer than the opened columns | > 0 |
| 14 | the seam slot too short | **0** (I disagree with the draft, which predicts > 0) |
| 15 | the counterparty's seam claim carries **no** reserved pair | > 0 |
| 16 | the two seams share one pair on each side | > 0 |

### 1.4 Measured

Every figure is the brute-force dense rank, in Fp dimensions.

| # | case | **joint** | about the shared plane | L alone | R alone | sum of parts | as predicted |
|---:|---|---:|---:|---:|---:|---:|---|
| 0 | honest, aliased, seam | **0** | 0 | 0 | 0 | 0 | yes |
| 1 | not aliased, no seam | 0 | 0 | 0 | 0 | 0 | yes |
| 2 | μ-batched over 3 blocks | **0** | 0 | 0 | 0 | 0 | yes |
| 3a | one blinding source, **aliased** | **0** | 0 | 0 | 0 | 0 | yes (**the draft's control does not fire**) |
| 3b | one blinding source, **not aliased** | **8** | 8 | 0 | 0 | **0** | yes |
| 4 | seam pair shared with an ordinary claim | 8 | 4 | 8 | 0 | 8 | yes |
| 5 | `c = 0` | **0** | 0 | 0 | 0 | 0 | yes (**the draft's control does not fire**) |
| 6 | `e = 0` | 8 | 8 | 8 | 8 | 16 | yes |
| 8 | second masking commitment | 0 | 0 | 0 | 0 | 0 | yes |
| 9 | one side opened twice | 10 | 6 | 10 | 0 | 10 | yes |
| 10 | `q_pad` = distinct columns | 0 | 0 | 0 | 0 | 0 | yes |
| 11 | two seams, same terminal point | 0 | 0 | 0 | 0 | 0 | yes |
| 12 | two seams, independent points | 0 | 0 | 0 | 0 | 0 | yes |
| 13 | one pad fewer | 6 | 4 | 3 | 3 | 6 | yes |
| 14 | seam slot too short | **0** | 0 | 0 | 0 | 0 | yes (**the draft's control does not fire**) |
| 15 | counterparty claim with **no** reserved pair | 8 | 8 | 8 | 0 | 8 | yes |
| 16 | two seams sharing one pair per side | 8 | 8 | 8 | 8 | 16 | yes |

Reference points from the joint-view gate's own one-commitment model, which
this model reproduces: two claims sharing one pair → **8**; a commitment
opened twice → **10**; one pad fewer → **3** per commitment (here 3 + 3 = 6
for two). Agreement on all three is the evidence that the extension did not
break the original.

### 1.5 The answer to the question the brief asks

**On this model, a seam between two commitments holding the same plane adds
exactly 0 to the disclosed dimension, and the joint disclosed dimension
about the shared plane is 0, equal to the sum of the parts.** The draft's
falsifiable claim at line 915-918 survives. Its headline "8 Fp, all of it
public identity" (line 911) is *not* what this model measures — this model
measures the PCS channel, where the answer is 0 on both sides; the 8 Fp is
an accounting sum over the two `H` LogUp identities and the two `M`
θ-combinations under the joint-view's accepted convention
(`ZK60_NATIVE_JOINT_VIEW.md` §3, §9a answer 1), and none of it is the seam.
That part of the draft is arithmetic over a convention, not a measurement,
and should be labelled so.

### 1.6 Three of the draft's own controls do not fire, and one of them is its stop gate

This is the most consequential result of §1, and it cuts **against the
draft's acceptance criterion**, not against the construction.

* **Case 3a (draft §D.6 case 3, line 948).** The draft predicts "> 0 — expect
  the difference of the two evaluations in the clear, so ≥ 2 Fp", citing the
  `zk.rs:1971-1974` comment. Measured: **0**. The comment is about two
  *different* blocks' evaluations; in form E the two planes are **equal**, so
  the difference of the two terminals is identically zero and a shared
  blinding source hides nothing that needed hiding. Case 3b shows the hazard
  is real (8 Fp) the moment the two planes are not equal.
* **Case 5 (draft §D.6 case 5, line 950).** `c = 0`: measured **0**. On the
  honest witness the seam's rounds carry no data, so a zero masking
  coefficient exposes nothing. `c = 0` must still be refused — the code
  refuses it by panic in `masked_prove`/`extension` (`zk.rs:976`, `:988`) and
  by `Err` on the io path (`zk_ffn_fresh_poc.rs`, `draw_mask_challenge(..,
  true)`) — but it is a **soundness/simulator** condition for this seam, not
  a hiding one.
* **Case 14 (draft §D.6 case 7, line 952).** A short slot: measured **0**,
  same reason.

The draft's §D.6 "Acceptance" paragraph (line 957-963) says "cases 3–7 and 9
must give more than 0. **A control that stops firing is a stop**". Run as
written, the experiment would therefore *stop the construction* on three
cases where nothing is wrong. **BLOCKING as an acceptance criterion** — the
criterion, not the design, must change. §10 item 1.

### 1.7 The one place where the joint exceeds the sum of the parts

Case 3b: **joint 8, L alone 0, R alone 0, sum of parts 0.** Each side's own
per-commitment analysis sees nothing; only the joint view sees the leak.

The cause is exactly the hypothesis of the joint view's stage-4 argument:
*disjoint randomness*. Sharing one blinding source across the two
commitments makes the randomness **not** disjoint, and the "joint = sum of
parts" step fails. The draft asserts the hypothesis survives (§D.4 step 1,
lines 851-856) and says it is "automatic because the pairs live on different
commitments" (line 881-883). That is true of the design as drawn, but it is
**not checkable by the gate the draft schedules**: §H step 9 (line 1530)
specifies a joint-view capture whose acceptance is *per role* — "`A_attn` 0,
`A_ffn` 0, both `H` 2, both `M` 2, `In`/`Out` 0" — which is a **sum of
parts** and would return all-zeros on case 3b. **BLOCKING**: the form-E
capture gate must compute a genuine cross-commitment joint rank with the
aliased plane's coordinates identified, not a per-role sum. §10 item 2.

### 1.8 What the model says about the draft's case 8 (its own stop gate)

Case 8 measures 0 and equals the sum, as predicted. But the honest reading
is that **this model cannot decide the draft's case 8 at all**: in a linear
model, an `M` commitment's independently published functional (the
θ-combination `q[0] + q[512]`) is a functional of the mask coefficients,
which are pure randomness, so it touches no data coordinate whatever the
number of masking commitments. The real content of U-14 is the *nonlinear*
redundancy of §3.1 of the joint-view report (degree up to 4), which linear
algebra explicitly cannot certify (`ZK60_NATIVE_JOINT_VIEW.md` §3, "that
redundancy is a **nonlinear** fact … so linear algebra cannot show it").
Making case 8 "the gate: if the joint exceeds the sum of parts, stop and
redesign" (draft line 1521) promises a decision the instrument cannot make.
**CORRECTION**: case 8 should be replaced by the per-slot derived-mask-
evaluation identity check of joint-view §3.1, asserted for **both** `M`s on
a real form-E receipt. §10 item 3.

### 1.9 Two controls the draft omits and that do fire

* **Case 15**, the counterparty's seam claim carrying **no** reserved pair:
  **8**. This is the concrete answer to "does the attention side need
  anything of its own" — it needs a **pair**, and without one the plane is in
  the clear at the seam point, column by column.
* **Case 16**, the two seams sharing one pair on each side: **8** per side,
  16 summed, 8 jointly. `audit_claims` catches this on `A_attn`
  (`private_block/protocol.rs:89-133`); **nothing catches it on `A_ffn`**
  (`check_masks` tests only the Fp2 span, `zk_ffn_fresh_poc.rs:253-321`).
  The draft says this (§C.2 line 713-719) and is right.

## 2. "Nothing is opened twice", and the prepare/finish split (item 1)

### 2.1 Commitment by commitment

Walked against source, not against the draft's table.

| commitment | claim sites | opened where | count |
|---|---|---|---:|
| `A_attn` | `A_SITES` sums to 120 (`private_block/layout.rs:512`, the 23-entry array), + 2 seam claims | `pcs::open_zk(&a, &ac, &mut tr)` then `drop(a)` — `private_block/protocol.rs:397-398` | **1** |
| `H_attn` | 51 sites + the value-0 LogUp sum claim (`finish_claims`, `protocol.rs:178-182`) | `protocol.rs:400-401` | **1** |
| `M_attn` | 34 functionals under one θ | `zk::mask_open(&mc, &acc.fs, …)`, `protocol.rs:392-393` | **1** |
| `W_ffn` | weight-block terminals | `PendingV3::finish`, `zk.rs:2313-2321` | **1 in both modes** (see below) |
| `A_ffn` | `8·nb_f + 4·nb_d + 6` + 2 seam claims | `zk.rs:2324`, then `drop` at `:2326` | **1** |
| `H_ffn` | its helper sites + the zero-sum claim | `zk.rs:2329`, `drop` at `:2331` | **1** |
| `M_ffn` | 6 + 2 functionals | `zk.rs:2309`, `drop(self.mc)` at `:2310` | **1** |
| `In`, `Out` | one claim each from `SC_IO_IN`/`SC_IO_OUT` | `protocol.rs:403`, `:406` | **1** each |

**Confirmed: no commitment is opened twice, and the move-semantics claim is
real** — every owner is taken by value (`open_zk(&a, …)` then `drop(a)`;
`PendingV3::finish(mut self, …)` consumes the struct; `Endpoints` is
consumed by `check_endpoints(expected, endpoints)`, `protocol.rs:243-254`).

**CORRECTION — `W_ffn` under P1.** The draft's §C.2 table (line 642) and its
opening count (line 1004) say `W_ffn` is "**not opened** (P1)". Refuted:
`PendingV3::finish` opens it in *both* modes — `PendingWeightV3::Public(cm,
claims) => { self.proof.w_open = pcs::open(&cm, &claims, tr); }`
(`zk.rs:2314`) against `Private(..) => pcs::open_zk(..)` (`zk.rs:2318`).
Under P1 the opening is **plain, not hiding**; it still happens, still
carries a proximity term and still counts in the opening budget. See §7.2
for the recomputed figure.

### 2.2 Can a claim be added after `prepare`? Yes on the feed-forward side, by construction

`PendingV3` (`zk.rs:2292-2305`) holds `ac: Vec<ZClaim>` and `fs:
Vec<MaskFunctional>` as **plain owned vectors**, and `finish`
(`zk.rs:2307-2334`) is the *only* consumer: it calls `mask_open(&self.mc,
&self.fs, …)`, then `pcs::open_zk(&self.a, &self.ac, tr)`. Nothing between
`prepare` returning and `finish` being called touches them. The precedent
does exactly this: `zk_ffn_fresh_io.rs:343-345` pushes onto
`self.pending.ac` and `:351-353` extends `self.pending.fs`, then calls
`self.pending.finish(&ntt, &mut self.tr)` at `:356`. **Confirmed.**

**BLOCKING (visibility) — the draft never says where the new module may
live, and there is only one place it can.** `PendingV3` is declared `struct
PendingV3` with **no** `pub` (`zk.rs:2292`), its fields are private,
`prepare_layer_zk_v3_inner` is private (`zk.rs:2337`) and
`verify_layer_zk_v3_with_seams` is private (`zk.rs:3471`). The io profile
reaches them only because it is a **descendant module** of `zk` —
`lib.rs:35 pub mod zk` → `zk.rs:4184 pub mod fresh_poc` →
`zk_ffn_fresh_poc.rs:15 pub mod io`. `private_block` is a **sibling**
(`lib.rs:51`). So form E's new module must be declared **inside `zk`**
(it can then reach `private_block`'s `pub(crate)` items, which is what
`prove_inner`, `audit_claims`, `check_opening`, `transcript` and
`pcs_params` are, `protocol.rs:21`, `:29`, `:89`, `:155`, `:258`), or the
four private items above must be made `pub`, which widens the frozen
prover's API. The draft's R1/R3 ("a new block-owned entry beside them", "a
new block module grown from a copy") leave this open. §10 item 4.

### 2.3 Is any challenge drawn in a way that breaks when claims are appended?

Checked both sides.

* **Feed-forward side.** No challenge is drawn between the end of
  `prepare_layer_zk_v3_inner` and `finish`. Inside `finish` the only draws
  are `mask_open`'s θ and prox (`zk.rs:515`, `:536`) and `open_zk`'s per-group
  λ vector and prox ρ (`pcs.rs:919`, `zk_rhos` at `:835-856`). Appending a
  claim changes the **number of λ draws** in the group it lands in and can
  add a group, which shifts every later challenge — consistently on both
  sides, because the verifier appends the same claims in
  `before_openings` (`zk.rs:3739`) before the same calls.
* **Attention side.** `prove_inner` draws nothing after `argument()` returns
  except inside `mask_open` and `open_zk` (`protocol.rs:392-407`).
  `check_opening` does **not** advance the transcript: it clones it
  (`protocol.rs:173`, `Transcript::clone_state`) and replays the PCS prefix
  to run the refusals. So appending claims is safe *mechanically*.

**Two things do change and are hard-wired constants, and the draft names
only the second:**

1. `check_opening(&ac, …, A_GROUPS, &tr)` **fails unless the group count
   equals the constant** (`protocol.rs:169-171`, `A_GROUPS = 35`,
   `layout.rs:516`). Two seam claims with fresh column tails make it 37.
2. `audit_claims` fails unless **every** reserved pair row is used by
   exactly one claim (`protocol.rs:129-131`). Reserving two pairs without
   pushing two claims is a refusal, and vice versa.

I checked the seam claim's shape against `audit_claims` directly: its
`nb_d` data parts land on data rows (not site rows), its two mask parts
touch one site row each and are adjacent, so `touched.len() == 2 &&
touched[1] == touched[0] + 1` holds (`protocol.rs:119-121`), and
`part_key` gives all `nb_d + 2` parts the same `(tail, c0, len)`
(`protocol.rs:67-72`), so `check_opening`'s "claim parts with different
column weights" refusal (`:161-163`) passes. **The seam claim is
audit-compatible as designed.** Confirmed.

### 2.4 Refactor or protocol change?

**The split itself is a refactor. What form E does with it is a protocol
change, and the draft's R1 understates one part of it.**

* Splitting `prove_inner` into `prepare` (through `argument()`) and `finish`
  (the four openings) with **nothing in between** leaves the transcript
  byte-identical. The draft's §H step 4 acceptance — "reproduces its
  byte-identical existing receipt" (line 1525) — is exactly right and
  achievable. **Refactor.**
* Form E changes the profile string, the schedule digest, `A_SITES`,
  `A_GROUPS`, `A_ROWS`, the absorbed parameters and the transcript
  interleaving. **Protocol change**, a new profile, as the draft itself says
  (line 422).

**CORRECTION — R1 is wrong that the feed-forward side is "a wrapper change,
not a prover change" (draft line 579).** The draft's own §B.6 requires both
`A` roots and both `M` roots to be absorbed **before** the shared
`(β, γ, α)` (steps 9-13, lines 484-489). But
`prepare_layer_zk_v3_inner` absorbs the statement, `W` (`zk.rs:2471`), `A`
(`:2542`) and `M` (`:2550`), **then draws `β, γ, α` at `:2554-2556`**, then
builds and absorbs `H` — all in one contiguous body. There is no seam in
that function at which the attention side's `A` and `M` commits can be
inserted. So §B.6 as written needs `prepare_layer_zk_v3_inner` itself split
at line 2553 — a change to the prover, not to a wrapper, and to a function
whose four 12×512 digests are frozen.

**The cheap alternative the draft does not consider:** keep
`prepare_layer_zk_v3_inner` intact and order the roots

```
A-attn, M-attn | [ W-ffn, A-ffn, M-ffn, (β,γ,α)_ffn, H-ffn ] | (β,γ,α)_attn, H-attn
```

Every commitment's root is still absorbed before any challenge its contents
depend on, and the seam challenges still come after every root. This is
sound and needs **no** change inside the frozen prover — but it costs the
draft's decision 4: there are then **two** `(β,γ,α)` triples, not one.
**The security owner must pick: split the frozen prover, or take two
triples.** §10 item 5.

### 2.5 The attention side's monolith, in detail

`prove_inner` (`protocol.rs:258-422`) builds the transcript at `:279`, `A`
at `:316`, `M` at `:324`, `H` at `:373`, runs all 23 slots at `:384`, and
opens at `:392-407`. A `Pending` holding `a`, `h`, `mc`, `ein`, `eout`,
`acc.claims` and `acc.fs` is mechanically straightforward; the one real
constraint is that `ProverData` borrows the commitments' `data` slices
(`protocol.rs:382`), so the slots must run inside `prepare`, which is where
the draft puts them. No obstacle found.

## 3. The tiling finding (item 2)

### 3.1 The finding itself is TRUE. Re-derived from both layouts.

**Feed-forward side.** `log_db = d.trailing_zeros().min(12)`, `nb_d = d/db`
(`zkp-core/src/ffn_v3/statement.rs:153-155`), `x = vecn(nb_d, tdb)` with
`tdb = t_rows·db` (`:160`), sliced as `s_d(off) = Slice { offset,
log_size: log_t + log_db }` (`:180`). The fill is explicit:

```rust
a_data[lay.x[c]..lay.x[c] + tdb].par_chunks_mut(db).enumerate()
    .for_each(|(t, row)| { for kp in 0..db { row[kp] = w.x[t * d + c * db + kp] } });
```
(`hashline/src/zk.rs:2486-2488`) — **token-major inside the d-block**, so
block `c` holds `(t, c·db + kp)` at flat position `t·db + kp`.

**Attention side.** `Dom::D` is "`(t, i)` (9 vars)"
(`private_block/layout.rs:79-80`) — one flat rectangle with `i` over the
whole width. (The draft cites `layout.rs:202-214` for this, line 307; that
is `a_dom()`, the plane→domain map. **CORRECTION**, citation only.)

So for `nb_d > 1`, d-block `c` is the **strided** column set `[c·db,
(c+1)·db)` of every token inside the attention side's flat plane. A
`ZPart` names `Slice { offset, log_size }` — one contiguous run
(`zkp-core/src/pcs.rs:729-749`), and `zpart_weights` asserts `offset % n ==
0` for a multi-row slice (`:759`, `:775`). A strided sub-plane is not
nameable. **The draft's Difference 3 is correct.**

### 3.2 But the proposed constraint, as written, does not type-check

Draft line 324-325: *"a new domain on the attention-side layout — call it
`Dom::Db` … carrying `nb_d` planes for `nm` and `nb_d` for `z16`, **in place
of one `Dom::D` plane each**."*

**BLOCKING.** `nm` and `z16` are not read alone. They are read inside a
single pointwise expression of the `Dom::D` zero-check, alongside planes
that would stay flat:

```
c6  = k_num·igm·x1 + k_dv·dm − k_den·nm·dm − mr
c9  = x2 − x1 − z16
c10 = z16 + 32768 − l2(A_ZL0)
```
(`private_block/argument.rs:731-737`), evaluated at **one** point of **one**
cube, over the slice family `b.a_range(A_X, A_RDL)` (`:709`) — planes 8…42,
**35 planes** (`layout.rs:126-152`, `a_dom` at `:207`). A term cannot mix a
plane on a `2^(log_t+log_db)` cube with a plane on a `2^(log_t+log_d)` cube;
the sumcheck has one variable set.

**The correct constraint** is therefore much larger than the draft's:

> At any width where `nb_d > 1`, the **whole `Dom::D` family** adopts the
> d-block tiling together — all 35 A planes `A_X..=A_RDL`, all 19 `Dom::D`
> LogUp helper planes `H_D0..=H_D_LAST` (`layout.rs:224-225`, `:245`), the
> two public per-column vectors `gamma_a`/`gamma_m` (which are indexed
> `x % D`, `argument.rs:706-707`, so each block needs its own public slice
> and the public-statement digest moves), and the `Dom::D` zero-check
> itself, which must be batched over the `nb_d` blocks with fresh public
> coefficients.

### 3.3 Do the relations survive the re-tiling? Yes — for one reason the draft half-states

* `c6`, `c7`, `c9`, `c10` and every `Dom::D` lookup (`sym(A_YM)`, the limb
  bytes, `layout.rs:326-334`) are **pointwise** in the cube coordinate, so
  they survive any bijection applied uniformly to every plane in the family.
* The one relation that is **not** pointwise survives only because the
  tiling keeps the token index most significant: `id = b.a_slice(lay.a_off[
  A_D], 5, rho(0..5), 0)` and the same for `A_DM` (`argument.rs:710-711`)
  read the per-token isqrt witnesses at the **first `log_t` variables** of
  the D-cube point. Under the d-block tiling the within-block index is
  `t·db + i'`, so `rho(0..log_t)` still selects the token. Under any other
  permutation (for example width-major) it does not, and the zero-check is
  silently wrong. The draft's "MSB-first cross-check" paragraph (lines
  341-346) is right, and this is the concrete reason it is load-bearing:
  it is not only the seam that needs it, it is `SC_DZC`'s norm terms.
* The lookups are built from the same `idx` slice handles
  (`lk_tables(lay, Dom::D, &idx, g_u8)`, `argument.rs:714`), so they follow
  the planes automatically. ✓

### 3.4 The cost claim is wrong

Draft line 327-339: "Two things make this constraint **cheap rather than
painful**… adopting `db = 256, nb_d = 3` **costs nothing**… A pointwise
relation over `nb_d` sub-planes is **the same zero-check with `nb_d` more
entries**."

**CORRECTION.** `a_range(A_X, A_RDL)` sweeps 35 **different planes at one
point**, not sub-planes of one plane. Tiling multiplies the slice count by
`nb_d`: at `nb_d = 3` the `Dom::D` zero-check reads **105** A slices instead
of 35, publishes `nb_d`× the terminals, and therefore needs `nb_d`× the
claim sites and `nb_d`× the reserved pairs. `A_SITES` currently gives that
slot 37 sites (`layout.rs:512`); at `nb_d = 3` it becomes ≈ 107, i.e. **+70
claim sites and +140 committed rows on `A_attn`**, plus the same
multiplication on the 19 `Dom::D` helpers of `H_attn`. It is one sumcheck
and one slot only if the `nb_d` blocks are batched with fresh public
coefficients — which is a change to the zero-check, not a free relabelling.

The draft's *relative* point stands and is worth keeping: at any width whose
`T·d` is not a power of two the attention side must tile **somehow**, so
adopting the feed-forward's tiling costs nothing *over the alternatives*.
That is a different claim from "costs nothing", and §G.2 / §D.1 must carry
the `nb_d` multiplication wherever `nb_d > 1`. §10 item 7.

### 3.5 The public-permutation alternative: sound, cheaper, but only sometimes

The brief asks whether the equality could instead be expressed with a public
index map, the two sides evaluating at different points. **It can, and where
it applies it removes the re-tiling entirely.**

Write `d = nb_d · db` with `nb_d = 2^k` a power of two. The attention side's
flat index is `t·d + i` with `i = c·db + i'`, so in bits, MSB-first, it is
`(t ‖ c ‖ i')`. The feed-forward's block-`c` index is `(t ‖ i')` with `c`
selecting the plane. For a multilinear extension that is exactly

```
P̃_flat(ρ_t, ρ_c, ρ_i')  =  Σ_c eq(ρ_c, c) · P̃_c(ρ_t, ρ_i')
```

i.e. the μ-batched right-hand side **with `μ_c := eq(ρ_c, c)`**. So:

* the attention side keeps `nm` and `z16` as single flat `Dom::D` planes —
  **no re-tiling, no new domain, no multiplication of claim sites**;
* it contributes **one** claim over the whole plane at the point
  `(ρ_t, ρ_c, ρ_i')`;
* the feed-forward side contributes its `nb_d` parts at `(ρ_t, ρ_i')` with
  coefficients `eq(ρ_c, c)` — all `nb_d` parts share one column key, so
  `group_zclaims` still folds them into **one** group
  (`zkp-core/src/pcs.rs:809-831`);
* the `nb_d` independent `μ` draws disappear; the soundness term becomes
  `(log_t + log_d)/|Fp2|` instead of `(m + 2(m+1) + 1)/|Fp2|` — smaller, not
  larger.

The masked sumcheck is still required (two terminals blinded by *different*
commitments' mask pairs cannot be compared directly; the sumcheck plus the
extension round is what makes the comparison checkable). But the cube it
runs over, and the tiling of the attention side, are free parameters that
this map fixes cheaply.

**Where it does NOT apply, and this is why the draft's constraint is still
the general answer:** `nb_d` is a power of two only for `d ∈ {4096 → 1,
8192 → 2, 16384 → 4}`. At the widths where the tiling problem actually
bites it is odd — `768 → 3`, `2560 → 5`, `3072 → 3`, `5120 → 5`,
`6144 → 3`, `12288 → 3` — and then `T·d` is not a power of two either, so
the attention side cannot hold a flat plane at all and must tile.

**Consequence for the draft: its constraint is stated "at any width" (line
318), and at Mistral (`nb_d = 1`) it is vacuous, while at `nb_d = 2` or `4`
the index map is strictly better.** The constraint should read *"at any
width where `nb_d` is not a power of two"*, with the index map named as the
cheaper route at the rest. **CORRECTION.** §10 item 8.

## 4. Transcript order and domain separation (item 3)

### 4.1 What each side absorbs today, in order

| attention side (`private_block/protocol.rs`) | feed-forward side (`zk.rs`, `zk_ffn_fresh_io.rs`) |
|---|---|
| `Transcript::new(PROFILE)` `:30` | `Transcript::new(PROFILE)` `zk_ffn_fresh_io.rs:139` |
| `"expected-IO"` `:31` | `"expected-IO"` `:140` |
| `"public-statement"` `:32` | — |
| `"parameters"` `:33` | `"parameters"` `:141-144` |
| `"calibration"` `:35` | — |
| `"schedule"` `:36` | `absorb_statement_v3` + `tr.absorb(b"zk", header_v3)` `zk.rs:2364`, `:2368` |
| — | `absorb_com(tr, b"W", …)` `zk.rs:2471` |
| `absorb_root(b"A")` = root, `"rows"`, `"log-cols"` `:40-44`, called `:320` | `absorb_com(tr, b"A", …)` `zk.rs:2542` |
| `tr.absorb(b"M", &mask_root)` `:326` | `tr.absorb(b"M", &proof.mask_root)` `zk.rs:2550` |
| `β, γ, α` `:330-332` | `β, γ, α` `zk.rs:2554-2556` |
| `absorb_root(b"H")` `:377` | `absorb_com(tr, b"H", …)` `zk.rs:2700-…` |
| 23 slots `:384` | 6 arguments |
| `mask_open(M)`, `open_zk(A)`, `open_zk(H)`, `open_zk(In)`, `open_zk(Out)` `:392-407` | `PendingV3::finish`: `mask_open(M)`, `open(W)`/`open_zk(W)`, `open_zk(A)`, `open_zk(H)` `zk.rs:2307-2334` |

### 4.2 Domain separation: the collision is real and concrete

`absorb_com(tr, label, c)` is `tr.absorb(label, &c.root); tr.absorb_u64(label,
c.rows)` (`zkp-core/src/ffn_v3/statement.rs:199-202`). The feed-forward
absorbs its `A` under the byte string `b"A"` (`zk.rs:2542`) and its `M`
under `b"M"` (`:2550`). The attention side absorbs its `A` under `b"A"`
(`protocol.rs:40`, called at `:320`) and its `M` under `b"M"` (`:326`).
**In a shared transcript the two sides' `A` roots would be absorbed under
the identical label.** The draft's decision 5 (component tags before every
root) is therefore **necessary, and this is the concrete reason**.
Confirmed, with the collision named.

**CORRECTION, citation.** The draft's §B.6 step 11 says the feed-forward's
`A` absorb carries `"rows" ; "log-cols"` (line 486). It carries root and
rows, **not** `log_cols` (`statement.rs:199-202`). Only the attention side
absorbs `log_cols` (`protocol.rs:43`). Under form E `log_cols` is bound
instead through the draft's step-4 `"parameters"` absorb — which is fine,
but the claim as written is false and the binding must be *stated* as
coming from `"parameters"`, not assumed from `absorb_com`.

### 4.3 One `(β, γ, α)` triple: sound, and the tag sets are already disjoint

The two sides' LogUp tags, read out of source:

| side | tags | source |
|---|---|---|
| attention (the block prover actually uses three) | `TAG_EXP = 129`, `TAG_U8 = 133`, `TAG_ACT = 134` | `tables_attn.rs:49`, `:70`, `:77`; used at `protocol.rs:333-335` |
| attention (others reserved) | `TAG_U16 128`, `TAG_PROB 130`, `TAG_INT8A 131`, `TAG_INT16A 132`, `tag_srem_a`, `tag_win` | `tables_attn.rs:47-80` |
| feed-forward | `TAG_ACT16 = 3`, `TAG_INT16 = 4`, `tag_rem_v3(sh)` in `64..=88` | `layer.rs` (imported at `zk.rs:1914`), used at `zk.rs:2557-2562`; table set at `zk.rs:1943` |

**The namespaces are already disjoint, deliberately and in writing**:
`tables_attn.rs:29` — "the LogUp table TAGS of the attention statement
(disjoint from the FFN's: TAG_SILU 1, TAG_INT8 2, TAG_ACT16 3, TAG_INT16 4,
the v2 range tags 16 + sh, the v3 window tags 64 + sh + 8 in 64..=88)" —
and `tables_attn.rs:73-76` spells out that `TAG_ACT = 134` "must NOT reuse
the FFN statement's `TAG_ACT16 = 3`". So the draft's decision 4 condition is
**already satisfied by the constants**; the audit it asks for is cheap and
worth adding as an assertion rather than a comment.

**Can a shared challenge let one side's table row stand in for the other's?
No, for a stronger reason than the draft gives.** The two sides' LogUp
identities are separate zero-sum claims on **separate `H` commitments**
(`protocol.rs:52-62` `logup_sum_claim` on `H_attn`; the v3 zero-sum on
`H_ffn`), so there is no sum in which a row of one could cancel a row of the
other. Even if they were combined, a collision would need
`v + γ·tag₁ = v′ + γ·tag₂`, i.e. `γ = (v′ − v)/(tag₁ − tag₂)` for bounded
integers `v, v′` — one value of `γ` out of `|Fp2|` per pair. **Confirmed:
one triple is sound.** NOTE: the draft does not count that cross-side
collision term anywhere in §E; it is negligible (≈ `2^41/2^128`) but should
be named once.

### 4.4 The proposed order is not achievable without opening a frozen function

Already covered in §2.4: §B.6 steps 9-13 require both `A` and both `M`
roots before one shared `(β, γ, α)`, and `prepare_layer_zk_v3_inner` runs
`W → A → M → (β,γ,α) → H` in one body (`zk.rs:2471`, `:2542`, `:2550`,
`:2554-2556`). **CORRECTION to R1**, alternative given in §2.4.

### 4.5 A second ordering error in §B.6 that nothing else catches

Draft steps 20-24 (lines 503-508) order the openings

```
20 mask_open(M-attn)  21 mask_open(M-ffn)  22 open(A-attn)
23 open(H-attn)       24 open(W/A/H-ffn)
```

with step 21 and step 24 both citing `zk.rs:2307-2334`. That is one
function: `PendingV3::finish` performs `mask_open(M_ffn)`, then `W`, then
`A_ffn`, then `H_ffn`, **contiguously and atomically**, consuming `self`.
The listed order is therefore unreachable unless `finish` is also split.
The reachable orders are either

```
mask_open(M-attn) | [ M-ffn, W, A-ffn, H-ffn ] | A-attn, H-attn, In, Out
```

(the io profile's own shape: `zk_ffn_fresh_io.rs:356` then `:357-362`), or a
split of `finish`. Any fixed order is sound; the draft must name a
reachable one. **CORRECTION.** §10 item 9.

### 4.6 What §B.6 gets right

* Every root absorbed before the seam coefficients: correct and necessary
  (`zk_ffn_fresh_io.rs:292` draws `tau` after `prepare` has absorbed both
  `A` roots; the verifier redraws at `:386`).
* The seam coefficients drawn at the point `tau` is drawn, never re-derived,
  and **not** refused on zero: correct — `tau = tr.challenge_fp2_vec(9)`
  with no zero check (`:292`, verifier `:386`).
* `c` discards the attempt on zero rather than resampling: correct —
  `draw_mask_challenge(.., true)` returns `Err` (`zk_ffn_fresh_poc.rs:221-233`),
  and `masked_prove`/`extension` additionally `assert!(!c.is_zero())`
  (`zk.rs:976`, `:988`).
* `e = 0` rejected: correct (`zk_ffn_fresh_io.rs:336-338` prover,
  `:391-394` verifier).
* Steps 18-19 could sit before step 16: correct, any position after all
  roots and before the openings works.

## 5. The two masking commitments and the seam slots (item 5)

### 5.1 `n_base = 2·slots + 4`, and 16 → 20: CONFIRMED

`mask_commit` builds `n_base = 2 * masks.len() + 4` rows — two per slot
(`re`, `im`) plus `b_re, b_im, u_re, u_im` (`zk.rs:435`, `:458-461`), and
`mask_verify` recomputes the same (`zk.rs:555`). `mask_specs_v3` yields six
specs for function 1 and appends two more when `zl.a_io.is_some()`:
`v.extend([((lay.log_t + lay.log_db) as usize + 1, 2); 2])` (`zk.rs:2172`).
So `2·6 + 4 = 16 → 2·8 + 4 = 20`. **The draft's re-derivation is correct**,
and the committed test already asserts it: `receipt.ffn.mask_open.columns
… all(|(_, c, _, _)| c.len() == 20)` (`zk_ffn_fresh_io_tests.rs:70-76`).

### 5.2 The slot-length bound: CONFIRMED, with one wrong entry in the draft's table

`CfsMask::len(n_vars, degree) = n_vars * degree + 2` (`sumcheck.rs:197-199`);
`mask_commit` asserts `part.len() + MASK_Q <= m` with `m = 512`,
`MASK_Q = 256` (`zk.rs:442`, `:373-375`) — so `L ≤ 256`.

| shape | seam `(n_vars, deg)` | seam `L` | **largest slot on `M_ffn`** | its `L` |
|---|---|---:|---|---:|
| tiny T32/d16/f16 | (10, 2) | 22 | table `(log_s+1, 3) = (17, 3)` | 53 |
| 125M, `nb_d = 3`, `nb_f = 1` | (18, 2) | 38 | **zero-check F `(log_t+log_fb+1, 4) = (21, 4)`** | **86** |
| Mistral, `nb_d = 1`, `nb_f = 7` | (22, 2) | 46 | zero-check D `(22, 4)` | 90 |

**CORRECTION.** The draft's §B.5 table (line 451) gives the 125M maximum as
"zero-check D (18,4), `L = 74`". Zero-check **F** is `(log_t + log_fb + 1,
4)` (`zk.rs:2162`) and at 125M `log_fb = min(tz(2048), 12) = 11`, so it is
`(21, 4)`, `L = 86`. The conclusion is unchanged — `86 + 256 = 342 ≤ 512`,
and the seam is never the binding slot — but the number is wrong.

The `1u64 << n_vars` overflow in `CfsMask::sum_weights` (`sumcheck.rs:223-224`)
and `round` (`:266`) is real and binds at `n_vars = 62`: **confirmed**,
both sites, and the guard does belong in the type.

### 5.3 Can a slot on `M_ffn` mask a sumcheck whose other terminal lives on `A_attn`? YES — and there is a working precedent with no counterparty `M` at all

Read out of the code, the division of labour is:

* **The CFS slot masks the sumcheck's ROUND MESSAGES, not the terminals.**
  `CfsMasker::mask_round` adds `c·g_j(X)` to every round
  (`sumcheck.rs:284-293`), and `extension` adds `c·g_k(X)` to the extension
  round (`zk.rs:990-995`). That is a property of the *argument*, which
  belongs to neither commitment.
* **Each terminal is blinded by its OWN side's reserved mask pair on its OWN
  `A`.** `exts = [Fp2::ZERO, mask_value(&self.pending.a, rows[i], &rho),
  mask_value(&endpoints[i], 2, &rho)]` (`zk_ffn_fresh_io.rs:320-324`), then
  `masked_terminal(fin, ext, e)` (`:339-342`,
  `sumcheck.rs:312-314`).
* **What is published on `M_ffn`** is exactly two functionals per seam:
  `(slot, sum_weights·c) = γ` and `(slot, eval_weights(ρ‖e)) = mask_eval`
  (`zk_ffn_fresh_io.rs:236-253`), checked at the single `mask_open`
  (`zk.rs:512-550`).

**The decisive fact: in the committed io profile the counterparty is a
7-row `private_seam` plane that has NO masking commitment whatever** — no
slots, no `M`, no θ — and the seam works. So the answer to the brief's
question is **no, the attention side does not need a seam slot of its own.**

**What it does need is a reserved mask PAIR per seam claim on `A_attn`**,
and that is load-bearing, not hygiene: small-model case 15 (§1.4) measures
**8 Fp** disclosed when the counterparty's seam claim carries no pair.
The draft's §B.5 "+4 `A_attn` rows (2 pairs)" is right and is the whole of
what the attention side must add.

**Decision 3 is therefore sound as recommended.** Both slots on `M_ffn`;
`M_attn` unchanged at 50 rows. One condition the draft omits: the seam
slots' *index* must be distinct from every slot index of `M_attn` only
inside the `M_ffn` namespace — they are, because they are indices into
`M_ffn`'s own spec vector — but the two `mask_open` calls draw **two
separate θ** from the same transcript at two different positions
(`zk.rs:515`), so the `MaskFunctional` lists must not be mixed between the
two commitments. That is a code invariant with no check today. §10 item 10.

### 5.4 The machinery generalises to model width; the *entry points* do not

Worth recording because the draft's §B.7 leans on "the reservation already
exists in committed code".

* `ZkLayoutV3::with_io` is **shape-generic**: `let first = zl.a_len /
  zl.a_n; zl.a_io = Some([first, first + 2]); zl.a_len += 4 * zl.a_n;`
  (`zk.rs:2055-2059`), and the pairs join `a_mask_rows()` unconditionally
  (`zk.rs:2086-2087`). ✓
* `mask_specs_v3`'s io branch is shape-generic (`log_t + log_db + 1`). ✓
* But the io **entry** is pinned to the tiny shape by
  `fresh_poc::preflight`: `if (st.t_rows, st.d, st.f) != (32, 16, 16) {
  return Err("fresh FFN PoC requires T32/d16/f16") }`
  (`zk_ffn_fresh_poc.rs:72-78`), reached from `check_witness`
  (`:117-118`) which `zk_ffn_fresh_io::prepare` calls at `:153`. And
  `prepare_layer_zk_v3_inner` refuses io unless `mr1` and function 1
  (`zk.rs:2352-2354`).
* And the io path's own PCS parameters are **`log_cols 8, inv_rate 8,
  Q 256`** (`zk_ffn_fresh_poc.rs:51-57`) — the *same* as the attention side
  (`protocol.rs:21-23`). **CORRECTION**: the draft's §B.2 "Difference 2 —
  encoding rate" (lines 287-298) contrasts "the attention side runs
  `inv_rate 8` … the v3 side `inv_rate 4`". At the only geometry where both
  exist today they are identical (8/8/256); the 14/4/256 figures are the
  **binary's defaults** (`bin/hashline.rs:59-60`), which the io path does
  not use. The difference is real at model width and decision 2 is right,
  but it is a difference between *the io profile* and *the model-width
  driver*, not between the two provers.

## 6. Chaining (item 6)

### 6.1 Openings per commitment, recounted

| candidate | openings per commitment | who fixes each boundary root | caller-fixed roots per 32-block pass | my verdict |
|---|---|---|---:|---|
| **(i)** all 32 blocks, one transcript | **1** everywhere. Every commitment survives to one `open_zk` at the end; the boundary residual is a slice of block `k`'s `A_attn` and of block `k+1`'s `A_attn`, bound by the same seam form as inside a block | prover, except the pass's two | **2** | count confirmed |
| **(i′)** runs of `g` | **1** everywhere | prover, except `2·(32/g)` | `64/g` (32 at `g = 2`) | count confirmed |
| **(ii)** shared boundary commitment | **2** on each boundary commitment | caller | 33 | confirmed; forbidden by D12 item 1 |
| **(iii)** own copies + link proof | **2** on each of two boundary commitments | caller or prover | 64 | confirmed |
| **(iv-B5)** public boundary tensor | 1 | n/a | 0 | confirmed; violates D1 |
| no binding | 1 | caller, 64 | 64 | confirmed; D17 item 4 |

The draft's opening counts are right in every row. Two things to add.

**NOTE — (i′) also changes the opening count per pass, which §E does not
pick up.** A `g`-block proof has 7 prover commitments per block plus **two**
endpoint commitments for the whole proof, not two per block. At `g = 2`:
`32 × 7 + 16 × 2 = 256` openings per pass instead of 288. At `g = 32`:
`32 × 7 + 2 = 226`. That is a genuine (small) soundness improvement the
draft leaves on the table.

**CORRECTION — the dismissal of recursion is right in conclusion and wrong
in its stated reason.** Draft line 1279-1284: "the aggregator still cannot
bind block `k`'s hidden output to block `k+1`'s hidden input unless it can
compare the two planes, which means opening them, which is (ii)". A
recursive verifier can bind two planes without any PCS opening (it verifies
both receipts inside a circuit and carries a commitment as a shared public
input), and an aggregator could equally ride a masked equality on the two
receipts' *existing* single openings. The real obstruction is the same one
the draft correctly identifies for candidate (iii) (line 1229-1235): **a
claim can only be authenticated by an opening under a transcript that
already contains the claim's challenge point**, so binding requires a
shared transcript, which is (i). Recursion additionally does not exist on
this line and would move the obligation onto a published boundary root,
i.e. back onto D8/D11.

### 6.2 D12 item 2, quoted and read

> 2. **A block is one proof under one transcript with exactly two external
>    endpoints**: its hidden input `x_in` and its hidden output `xres2`. Two
>    separately finished component receipts glued by a shared root are not a
>    block.
> — `ZK60_DECISIONS.md:319-322`

**Reading: a multi-block proof GENERALISES item 2; it does not contradict
its substance, but it does contradict its letter, so the draft is right
that a sentence is owed.**

* The *purpose* is stated in the item's own second sentence and in D12's
  plain-words paragraph (`:308-315`): the target is **gluing two separately
  finished receipts by a shared root**. Candidate (i′) is the opposite of
  gluing — it is one transcript, nothing finished separately, nothing
  shared by two proofs.
* Every other clause is satisfied *more* strongly: item 1 (no double
  opening) holds everywhere; item 3 (hidden intermediates on
  prover-generated commitments inside that one proof) holds for the
  cross-block residual too, which is the point.
* The letter fails: under `g = 2`, block 1's output `xres2` is **not** an
  external endpoint, so block 1 is not "one proof … with exactly two
  external endpoints". It is half a proof.

The draft's proposed wording (line 1144-1147) is adequate. **One addition
it omits, and it matters**: the amendment must say that a run's *internal*
boundary residuals are hidden intermediates under item 3 — otherwise the
new sentence licenses a run whose internal boundaries sit on caller-fixed
roots, which is exactly what item 3 forbids. §10 item 12.

### 6.3 The memory arithmetic, recomputed — and the draft's `g = 2` claim does not hold

From the draft's own row counts: `26,676 + 17,471 = 44,147` rows of 16,384
words × 8 B = **5.786 GB systematic**; at `inv_rate 4` the encoded matrix is
4× that = **23.14 GB**. Both must be resident until the single opening
(`open_zk` gathers columns from `cm.store`, `pcs.rs:930-942`; the systematic
`data` is needed by `fold_rows_multi_zk`, `:863-874`). So:

| | systematic | encoded | **resident total** |
|---|---:|---:|---:|
| one form-E block | 5.79 GB | 23.14 GB | **≈ 28.9 GB** |
| `g = 2` | 11.57 GB | 46.3 GB | **≈ 57.9 GB** |
| `g = 32` | 185.2 GB | 740.5 GB | ≈ 926 GB |

The draft's 185 GB / 740 GB at `g = 32` reproduce exactly. **But at `g = 2`
it quotes "about 11 GB of systematic data resident — plausible on a 32 GB
card" (line 1164-1166) — systematic only, where two sentences earlier it
quoted systematic *and* encoded.** Corrected: `g = 2` needs ≈ 58 GB and does
**not** fit a 32 GB card; and **one** form-E block at ≈ 29 GB is already at
that card's limit. **CORRECTION, and it is load-bearing**: §F.7's
recommendation "start with two blocks, which needs no spilling on a 32 GB
card" (line 1316) is contradicted by the draft's own numbers, and §F.7's
measurement 1 ("peak resident bytes for `g = 2`") is not a tie-breaker but
a near-certain negative. §10 item 13.

Sanity check on the model: the feed-forward half alone is `17,471 × 16,384 ×
8 = 2.29 GB` systematic, 9.2 GB encoded, ≈ 11.5 GB resident — consistent
with the repository's own record that one 8B layer's commitments overflow an
8 GB part (`zk.rs:2386-2394`).

**Which inputs are COUNTED and which are the draft's ESTIMATE.** Counted
from source or from a measured lane: `A_ffn` 3,669 (3,665 + the 4 io pair
rows, `zk.rs:2057-2059`), `H_ffn` 3,030, `W_ffn` 10,752, `M_ffn` 20 — total
17,471. **Estimate**: the entire attention half's 26,676, which is a
plane-count scaling of a `T = 32, D = 16, H = 2, DH = 8, KV = 8, F = 16`
layout hard-coded as `pub(crate) const`s (`private_block/layout.rs:40-49`).
So 60 % of the resident bytes in every row of the table above is an
estimate, and every memory conclusion inherits that.

## 7. Soundness and cost figures (item 7)

### 7.1 The seam errors: all six figures reproduce exactly

`|Fp2| = |Fp|^2` with `Fp = 2^64 − 2^32 + 1` (`zkp-core/src/field.rs:10`),
so `log2|Fp2| = 127.99999999995`. Per seam the draft charges
`m + 2(m+1)` field terms:

| shape | `m` | terms | one seam | two seams | 64 seams |
|---|---:|---:|---:|---:|---:|
| tiny | 9 | 29 | 2^-123.14 | 2^-122.14 | 2^-117.14 |
| 125M | 17 | 53 | 2^-122.27 | 2^-121.27 | 2^-116.27 |
| Mistral | 21 | 65 | **2^-121.98** | 2^-120.98 | **2^-115.98** |

**Every entry reproduces.** [COUNTED, confirmed.] The `μ` batching's extra
`1/|Fp2|` per seam and `2^-121` over 64 also reproduce.

### 7.2 The whole-proof figure: arithmetic right, opening inventory wrong

Per-opening bound, re-derived from the code's own comment and the ZK-mode
distance `1 − (n + Q)/nn` (`pcs.rs:16-19`, `:517-528`):

* `log_cols 14 / inv_rate 4 / Q 256`: `δ = 1 − 16640/65536 = 0.74609`,
  `(1 − δ/3)^256 = 2^-105.609` ✓
* tiny `8/8/256`: `δ = 0.75`, `0.75^256 = 2^-106.25` ✓
* the `Q = 512` variant of §F.3: `δ = 1 − 16896/65536`,
  `(1 − δ/3)^256 = 2^-104.97`, i.e. **0.64 bits** ✓

All three confirmed. The pass arithmetic also reproduces: `9 × 2^-105.609 =
2^-102.44`; `288 × = 2^-97.44`; `192 × = 2^-98.02`; `2^-97.44 + 2^-94.2 =
2^-94.06`; `+ 2·2^-94.2 = 2^-93.13`. ✓

**Two corrections to the inventory, neither of which moves the headline:**

1. **`W_ffn` is opened under P1 too** (§2.1), so "nine openings" is right
   but "not opened (P1)" is wrong; the draft's own count of 9 happens to be
   correct for the wrong reason.
2. **Charging every opening 2^-105.609 is conservative, and the draft does
   not say so.** Only `A_attn`, `H_attn`, `A_ffn`, `H_ffn` are at
   `14/4/256`; `M_attn`/`M_ffn` run at 512-of-4096 with `MASK_Q = 256`
   (`zk.rs:373-375`), `In`/`Out` at `8/8/256` (`private_seam`, 7 rows), and
   `W_ffn` under P1 is a **plain** opening with no pads. Those five are at
   ≈ 2^-106.25, giving a block ≈ 2^-102.76 rather than 2^-102.44. The
   draft's figure is the safe side. NOTE.

**The draft's honest headline is correct and is the most important sentence
in its §E: nobody has projected the attention half's lookup term at model
width**, so ≈ 94 bits is an upper bound on the bits, not a figure. I confirm
the gap: the tiny block's own lookup counts are
`private_block/layout.rs:744-746` and `tests.rs:107`, and the score-domain
lookups scale as `H_q·T²`.

### 7.3 "About 26,676 rows": the arithmetic is solid, the premise is not

I recounted the plane inventory independently from `layout.rs:112-200` and
`a_dom` (`:202-214`):

| domain | A planes | of which dropped in form E | cube at Mistral | rows each | A rows |
|---|---:|---|---:|---:|---:|
| `Dom::T` | 4 | — | 2^9 | 1 | 4 |
| `Dom::Ht` | 2 | — | 2^14 | 1 | 2 |
| `Dom::L` | 2 | — | 2^13 | 1 | 2 |
| `Dom::D` | **35** (`A_X` 8 … `A_RDL` 42) | `A_RDL` | 2^21 | 128 | 4,352 |
| `Dom::Q` | 7 (43…49) | — | 2^21 | 128 | 896 |
| `Dom::Kv` | 6 (50…55) | — | 2^19 | 32 | 192 |
| `Dom::S` | 11 (56…66) | — | 2^23 | 512 | **5,632** |
| `Dom::F` | 11 (67…77) | all 11 | — | — | 0 |
| `Dom::Tab` | 3 (78…80) | `A_MACT` | 2^8 | 1 | 2 |
| | | | | | **11,082** |

`H`: 51 planes (`layout.rs:222-241`), drop the 6 `Dom::F` helpers → 45; each
plane is two Fp slices, so `2 + 19·2·128 + 7·2·128 + 6·2·32 + 8·2·512 +
4·2·1 = 15,242` data rows. **Both figures reproduce the draft exactly**
(11,082 and, in its prose, 15,242). The table's 15,334 is 15,242 plus ≈92
mask rows, which the `A_attn` row of the same table lists separately —
cosmetic inconsistency only. Total `11,292 + 15,334 + 50 = 26,676` ✓.

Mistral's head counts are confirmed: 32 query heads, 8 key/value heads, head
dimension 128 (`TARGET_CONTRACT.md:24`,
`ZK60_MVP_COMPLETION_PLAN.md:48`, `:71`).

**So "about 26,676 rows" is arithmetically solid to within a few rows,
given four premises that are not:**

1. a model-width attention layout has the *same* plane inventory as the toy
   (81 A planes, 51 H helpers) — unverified, and D16 explicitly says the
   norm's limb counts change with width, which changes `A_NR0..3`,
   `A_MR0..3`, `A_NS0..3`, `A_MS0..3`;
2. the per-domain cubes scale as written — `Dom::L` in particular is "sixteen
   packed 32-entry limb sub-planes" (`layout.rs:78-79`), whose widening rule
   D16 owes;
3. `nb_d = 1` at Mistral, so §3.4's `nb_d` multiplication does not bite —
   **true at Mistral and false at 125M**, where the same estimate would have
   to multiply the whole `Dom::D` family by 3;
4. the claim-site count stays ≈104 — but sites scale with planes and with
   `nb_d`.

**Two conclusions of the draft that survive the premises, and one that gets
stronger.** The score-domain domination (5,632 of 11,082 A data rows, 8,192
of 15,242 H data rows, scaling `H_q·T²` against the feed-forward's `T·f`) is
robust: it would take a factor of 5 error to overturn it. And the
"attention is the bigger half" claim is **understated**: 26,676 against
17,471 is 60 %, but `W_ffn`'s 10,752 rows are the *public* weights; against
the feed-forward's private commitments alone (`3,669 + 3,030 + 20 = 6,719`)
the attention half is **80 %** of the private material. Form E's Amdahl
warning is the right one and should be sharpened, not softened.

### 7.4 The byte figures

`0.525 MiB` feed-forward-side seam overhead at 125M: `4·256·8 + 4·256·8 +
2·(16384+256)·16 + 2·(1 + 18·3 + 2 + 1)·16 = 8,192 + 8,192 + 532,480 +
1,856 = 550,720` ✓. Mistral: `8,192 + 8,192 + 532,480 + 2·70·16 = 551,104`
✓. Attention side at `log_cols 14`: `8,192 + 2·16,640·16 = 540,672` ✓.
Combined 1,091,392 B ✓. All reproduce. NOTE: the `4 × 256 × 8` terms charge
256 opened columns per extra row, which is right for the *column* part of
the opening but omits the extra **group vectors' pad entries** — already
counted in the `(16384+256)` term. Consistent.

## 8. Every "already exists" claim, confirmed or refuted (item 8)

I opened every one. The draft's attention-side citations are unusually
accurate (`A_ROWS` `layout.rs:523`, `H_ROWS` `:524`, `M_ROWS` `:519`,
`A_GROUPS` `:516`, `A_SITES` `:512`, `audit_claims` `protocol.rs:89-133`,
`SC_IO_IN/OUT` `argument.rs:902-909`, the frame bytes `tests.rs:108` — all
exact to the line). Its `zk.rs` citations in §B.7's "what cannot be
restructured" are systematically ~70 lines early.

| # | draft's claim | verdict | source |
|---:|---|---|---|
| 1 | `verify_layer_zk_v3_with_seams(…, before_openings)` is an existing verifier seam hook | **CONFIRMED** — signature at `zk.rs:3471-3472`, called at `:3739` before `mask_verify` (`:3742`) and before every opening. It receives `&mut Vec<ZClaim>` (A only), `&mut Vec<MaskFunctional>` and `&mut Transcript`. **Caveat: it is a private `fn`, and it does not expose `hc`** | `zk.rs:3468-3472`, `:3739` |
| 2 | `PendingV3::finish` is openings only | **CONFIRMED** — `mask_open`, `W`, `A`, `H`, each once, each dropped | `zk.rs:2307-2334` |
| 3 | `zk_ffn_fresh_io::PendingProof` already runs seams against another party's commitment | **CONFIRMED** — two masked sumchecks against `endpoints[i]`, then `self.pending.finish(..)`, then the endpoint openings | `zk_ffn_fresh_io.rs:276-368` |
| 4 | `prepare_layer_zk_v3_inner` already takes `&mut Transcript` | **CONFIRMED** | `zk.rs:2337` |
| 5 | `prove_layer_zk_v3` is literally `prepare(..)?.finish(..)` | **CONFIRMED** | `zk.rs:2279-2285` |
| 6 | `ZkLayoutV3::with_io` reserves two pairs, `a_len += 4·a_n`, pairs join `a_mask_rows()` | **CONFIRMED**, and shape-generic | `zk.rs:2055-2059`, `:2086-2087` (draft says `:2057-2063`, `:2090`) |
| 7 | `mask_specs_v3` reserves slots 6 and 7, spec `(log_t+log_db+1, 2)` | **CONFIRMED**, exact line | `zk.rs:2171-2172`; `FIRST_IO_SLOT` `zk_ffn_fresh_io.rs:14` |
| 8 | `n_base = 2·masks.len() + 4`; 16 → 20 | **CONFIRMED**, exact line; the committed test asserts 20 | `zk.rs:435`, `:555`; `zk_ffn_fresh_io_tests.rs:70-76` |
| 9 | `L = n_vars·degree + 2`; `mask_commit` asserts `L + 256 ≤ 512` | **CONFIRMED**, exact | `sumcheck.rs:197-199`; `zk.rs:442`, `:373-375` |
| 10 | the `1u64 << n_vars` overflow is in **two** places | **CONFIRMED** | `sumcheck.rs:223-224`, `:266` |
| 11 | `group_zclaims` folds `nb_d + 2` parts under one key | **CONFIRMED** — asserts all parts share a key, sums row weights | `pcs.rs:809-831` |
| 12 | `zpart_weights` splits `rho` by *that* commitment's `n` | **CONFIRMED** | `pcs.rs:752-792` |
| 13 | `audit_claims` refuses unused/shared pairs; runs on prover and verifier | **CONFIRMED** | `protocol.rs:89-133`, called `:156` from `check_opening` `:155-175`, used at `:396`/`:399` and `:458`/`:464` |
| 14 | `check_masks` "checks only that each claim's mask coefficients span Fp2" | **CONFIRMED in conclusion, understated**: it also checks the claim mapping shape, that all parts share one column tail, and replays the zero-group-coefficient and prox-determinant refusals. It does **not** check pair exclusivity | `zk_ffn_fresh_poc.rs:253-323`, `:325-345` |
| 15 | `ZkOpts::standard` ties `q_pad = num_col_checks`; `commit_zk_owned_with` refuses less | **CONFIRMED**, exact | `pcs.rs:543`, `:670` |
| 16 | `draw_mask_challenge(.., repaired)` discards on `c = 0` | **CONFIRMED**, exact | `zk_ffn_fresh_poc.rs:221-233`; plus `assert!` at `zk.rs:976`, `:988` |
| 17 | `e = 0` rejected on both sides | **CONFIRMED**, exact | `zk_ffn_fresh_io.rs:336-338`, `:391-394` |
| 18 | `claim()`/`mask_value` hard-code one `log_n` and the endpoint geometry | **CONFIRMED** — `log_size: 9`, `row*256`, `rho[len-8..]`, `MaskPoint::new(.., 256)`, and `claim(0, 2, ..)` | `zk_ffn_fresh_io.rs:201-235`, `:346` |
| 19 | the FFN's lookup list never covers `lay.x` | **CONFIRMED** — `g8`+`a16`, `u16`, `h16` per f-block, `z`+`rd` per d-block; no `x` | `zk.rs:2684-2691`; table set `zk.rs:1943` |
| 20 | `lay.x[c]`/`lay.z[c]` are the claimed arithmetic planes | **CONFIRMED**, exact lines | `zk.rs:3350`, `:3351`, `:3360` |
| 21 | `MASK_ROWS = 5` gives the endpoint one terminal pair; general minimum `2·sites + 2` | **CONFIRMED** | `private_seam.rs:35`, rows `= data_rows + MASK_ROWS = 7` at `:106-111` |
| 22 | "a plane opened at k points has k pairs" | **CONFIRMED**, verbatim | `private_attention/layout.rs:9-10` |
| 23 | `Endpoints` consumed by value, pinned by a `compile_fail` doctest | **CONFIRMED** on both modules | `zk_ffn_fresh_io.rs:125-131`; `private_block.rs:357-370` |
| 24 | `zk.rs:1971-1974` names the shared-mask-row hazard | **CONFIRMED that the text exists** (`zk.rs:1972-1975`) **but the context is wrong**: it is the doc comment of the **P3 W-block** mask rows, about two *different* W blocks' evaluations, not about seam terminals. In form E the two planes are equal, and §1.4 case 3a measures 0 | `zk.rs:1961-1975` |
| 25 | the three v3 "cuts": `commit_zk_owned` for A at `:2467`, `mask_commit` at `:2477-2478`, the H commit at `:2632` | **CONFIRMED in substance, all three citations wrong by ≈ 70 lines**: `:2537`, `:2548`, `:2702` | `zk.rs:2537`, `:2548`, `:2702`, `:2708` |
| 26 | the attention side's cuts at `protocol.rs:296`, `:304` | **CONFIRMED in substance, citations wrong**: the A commit is `:316`, the M commit is `:324` | `protocol.rs:316`, `:324` |
| 27 | move semantics on every `?` path, "`zk.rs:3219-3226` on the v3 side" | **substance CONFIRMED, citation REFUTED**: `zk.rs:3219-3226` is function 2's predicate sumcheck tables. The guarantee is that `finish(mut self, ..)` owns `mc`, `a`, `h` and drops them at `:2310`, `:2326`, `:2331` or by `self` going out of scope on a `?` | `zk.rs:2307-2334` |
| 28 | `zk_ffn_fresh_wire.rs` is not extensible: five named constants | **PARTLY REFUTED** — see below | `zk_ffn_fresh_wire.rs` |
| 29 | `check_opening_challenges` prox-determinant refusal at `protocol.rs:143-145` | **substance CONFIRMED, citation off**: `:143-145` is the zero-group-coefficient loop; the determinant is `:148` | `protocol.rs:141-152` |
| 30 | the block module already absorbs `b"calibration"` at `protocol.rs:35` | **CONFIRMED**, exact | `protocol.rs:35` |

**Row 28, in detail.** Of the draft's five constants (line 584):

| draft says | verdict |
|---|---|
| `TERMINALS: [usize; 6]` zipped over six arguments (`:10`, `:74-83`) | **CONFIRMED**, `zk_ffn_fresh_wire.rs:10` |
| `c.len() != 16` for the M columns (`:129`) | **REFUTED** — the check is `c.len() != self.mask_rows`, computed as `2·specs.len() + 4`, and `io_shape` already does `shape.mask_rows += 4` (`:137`, `:228-232`) |
| `hiding(&p.a_open, 5, ..)` for five A groups (`:121`) | **REFUTED** — A uses `self.a_groups`, which `io_shape` already sets to 7 (`:129`, `:230`). The hard-coded **5** is on **H**: `hiding(&p.h_open, 5, self.rows[2])` (`:130`) |
| a binding digest with no peer-root/slice/role/scale field | **CONFIRMED** (`:148-165`) |

**And four model-width blockers the draft misses, all harder than the ones
it names**, because they freeze the frame to `log_cols 8 / inv_rate 8`:
`groups(.., 512)` fixes the group-vector width at `n + Q = 512`
(`zk_ffn_fresh_wire.rs:101`, `:104`); `p.len() == 11` fixes the Merkle depth
(`:108`); `*j < 2048` fixes the encoded column count (`:108`); and
`p.len() != 12` fixes the mask tree's depth (`:137`). At `log_cols 14 /
inv_rate 4` every one of them rejects an honest frame. §10 item 15.

## 9. What I did not check

* **I did not build, run or prove anything.** No cargo, no test, no GPU.
  Every "confirmed" is a reading of source; every number is arithmetic over
  constants or a rank on a small Python model.
* **The small model is linear and idealised.** It does not cover the hash
  layer (roots, 256 salted leaves per opening, authentication paths), the
  nonlinear CFS↔PCS redundancy (`poly_s` is degree up to 4), the adaptive
  or distributional lift, integer-range side information, timing, or
  D8/D11 — exactly the exclusions of `ZK60_NATIVE_JOINT_VIEW.md` §7. **It
  establishes no privacy property.** It also models the seam's round
  channel only on the honest (aliased) manifold, where its data part is
  identically zero; the non-aliased cases deliberately drop the rounds
  because their data part is quadratic and outside a linear model.
* **I did not read the bodies of** `masked_prove`'s inner `sumcheck::prove`,
  `pcs::commit_zk_owned_with`, `encode_row_zk`, `mask_verify`'s NTT
  arithmetic or `MerkleTree`. I read their call sites, signatures and the
  invariants they assert.
* **I did not examine the GPU kernels** or `layer.rs:1379-1400`, so the
  draft's §G.3 claim about what stays on the device, and whether the
  block-decomposed CUDA path tolerates four extra `A_ffn` rows and two
  extra opening groups, is unchecked here (the draft says the same).
* **I did not re-derive D15's lookup-term projection** (2^-94.2); I reused
  it, and §7.2's whole-pass figures inherit it.
* **I did not verify the measured baselines** quoted by the draft — 58.40 s,
  4.649 s, 3.453 s, the 12×512 row counts 585/486/288/16, the per-layer
  byte figures, the four frozen digests. They are cited to lanes and
  ledgers I did not open.
* **I did not check P3** anywhere: `W_ffn`'s hiding variant, its mask rows,
  its disclosed dimension, or the second matmul extension round's effect on
  the seam.
* **I did not cost verification** — verifier seconds, memory, or decode
  bounds.
* **I did not attempt the model-width attention layout** the draft's §H step
  1 asks for; §7.3 reproduces the draft's estimate and audits its premises,
  it does not replace it.

## 10. ERRATA AND CONDITIONS FOR ACCEPTANCE

One numbered, de-duplicated list. **E-1 … E-5 are BLOCKING**; **E-6 … E-20
are CORRECTIONS**; **C-1 … C-11 are conditions the draft omits.** Line
numbers are the draft's (`ZK60_PRIVATE_BLOCK_FORM_E.md`).

### BLOCKING

| # | draft | source | what must change, and to what |
|---:|---|---|---|
| **E-1** | §D.6 acceptance, lines 957-963 and §H step 0, line 1521: "cases 3–7 and 9 must give more than 0. A control that stops firing is a stop" | measured: §1.4 cases 3a (**0**), 5 (**0**), 14 (**0**) | Three of those controls **cannot** fire for an *equality* seam at the honest witness, because the seam polynomial `v0·(v1−v2)` is identically zero there (`zk_ffn_fresh_io.rs:198-200`, `zk.rs:990-995`). As written the experiment stops a correct construction. Replace with: *cases 0, 1, 2, 8, 10, 11, 12 must give 0; cases 4, 6, 9, 13, 15, 16 must give > 0; cases 3, 5, 7 are reclassified as **soundness/simulator** conditions and are run in their non-aliased form (case 3b), where they do fire (8 Fp)* |
| **E-2** | §H step 9, line 1530: the form-E capture gate accepts on a **per-role** list ("`A_attn` 0, `A_ffn` 0, both `H` 2, both `M` 2, `In`/`Out` 0") | measured: §1.4 case 3b — **joint 8, `L` alone 0, `R` alone 0, sum of parts 0** | A per-role sum is blind to the one failure mode a seam introduces: randomness shared across the two commitments. The gate must compute a **genuine cross-commitment joint rank with the aliased plane's coordinates identified**, and must assert `joint == sum of parts` as well as `joint == 0`. Without that, §D.4 step 1's "disjoint randomness survives" is an assumption the gate does not test |
| **E-3** | §B.2, lines 318-325: "a new domain … carrying `nb_d` planes for `nm` and `nb_d` for `z16`, **in place of one `Dom::D` plane each**" | `private_block/argument.rs:709`, `:731-737`; `layout.rs:207`, `:224-225`, `:245` | Does not type-check. `c6`, `c9`, `c10` read `nm`/`z16` **together with** `x1`, `x2`, `dm`, `mr`, `ms` and the limb planes in one pointwise term of one sumcheck over one cube. Restate: *at any width where `nb_d` is not a power of two, the **whole `Dom::D` family** re-tiles together — all 35 A planes `A_X..=A_RDL`, all 19 `Dom::D` helper planes, the public `gamma_a`/`gamma_m` vectors (re-sliced per block, so the public-statement digest moves), and the `Dom::D` zero-check, batched over the `nb_d` blocks* |
| **E-4** | §F.2 line 1164-1166 and §F.7 line 1316: "`g = 2` … needs about 11 GB of systematic data resident — plausible on a 32 GB card"; "Two blocks at a time needs no spilling on a 32 GB card" | the draft's own row counts; `pcs.rs:863-874`, `:930-942` | Systematic-only, where two sentences earlier the same section quotes systematic **and** encoded. At `inv_rate 4` the encoded matrix is 4× and must also be resident. Corrected: **one** form-E block ≈ 5.79 + 23.14 = **28.9 GB**; `g = 2` ≈ **57.9 GB**. `g = 2` does **not** fit a 32 GB card, and one block is already at its limit. §F.7's "simplest first" plan and its measurement 1 must be rewritten on these numbers |
| **E-5** | §B.7 R1, line 579: "the inner `prepare_layer_zk_v3_inner` already takes `&mut Transcript`, so this is a **wrapper change, not a prover change**" | `zk.rs:2471`, `:2542`, `:2550`, `:2554-2556` | §B.6 steps 9-13 require both `A` and both `M` roots before **one** `(β, γ, α)`. `prepare_layer_zk_v3_inner` absorbs `W → A → M`, **then draws `β, γ, α`**, then commits `H`, in one contiguous body with no insertion point. Either split that frozen function at `zk.rs:2553` (a prover change) **or** take two `(β, γ, α)` triples with the order `A-attn, M-attn │ [W, A-ffn, M-ffn, (βγα)_ffn, H-ffn] │ (βγα)_attn, H-attn`, which is sound and needs no change inside the prover. **This is a ruling the security owner must make; it reverses or keeps decision 4** |

### CORRECTIONS

| # | draft | source | corrected value |
|---:|---|---|---|
| **E-6** | §C.2 line 642 and §E.2 line 1004: `W_ffn` "**not opened** (P1)" | `zk.rs:2313-2321` | `W_ffn` is opened in **both** modes — plainly under P1 (`pcs::open`), hidingly under P3 (`pcs::open_zk`). The count of nine openings per block is right; the reason given is wrong |
| **E-7** | §B.5 line 451: the largest `M_ffn` slot at 125M is "zero-check D (18,4), `L = 74`" | `zk.rs:2162`; `log_fb = min(tz(2048),12) = 11` | It is **zero-check F, `(log_t+log_fb+1, 4) = (21, 4)`, `L = 86`**. Conclusion unchanged (`86 + 256 ≤ 512`) |
| **E-8** | §B.2 lines 287-298: "the attention side runs `inv_rate 8` … the v3 side `inv_rate 4`" | `zk_ffn_fresh_poc.rs:51-57`; `protocol.rs:21-23`; `bin/hashline.rs:59-60` | At the only geometry where both exist the parameters are **identical** (`8/8/256`). The `14/4/256` figures are the **binary's defaults**, which the io path does not use. Decision 2 stands; the contrast is between the io profile and the model-width driver, not between the two provers |
| **E-9** | §B.6 steps 20-24, lines 503-508 (order: `M-attn, M-ffn, A-attn, H-attn, W/A/H-ffn`) | `zk.rs:2307-2334`; `zk_ffn_fresh_io.rs:356-362` | Unreachable: `PendingV3::finish` performs `M-ffn, W, A-ffn, H-ffn` contiguously and consumes `self`. Name a reachable order, e.g. `mask_open(M-attn) │ [M-ffn, W, A-ffn, H-ffn] │ A-attn, H-attn, In, Out` |
| **E-10** | §B.6 step 11, line 486: the FFN's `A` absorb carries `"rows" ; "log-cols"` | `zkp-core/src/ffn_v3/statement.rs:199-202` | `absorb_com` absorbs root and **rows only**. `log_cols` must be bound through the step-4 `"parameters"` absorb, and the memo must say so |
| **E-11** | §B.2 line 307: the attention side's flat `(t, i)` layout is at `layout.rs:202-214` | `private_block/layout.rs:79-80` | `:202-214` is `a_dom()`. The statement is the `Dom::D` doc comment at `:79-80` |
| **E-12** | §D.4 lines 876-883 and §E.1 lines 989-993: the `zk.rs:1971-1974` hazard applies to the two seam terminals; `c = 0` is a *hiding* condition | `zk.rs:1961-1975`; measured §1.4 cases 3a, 3b, 5 | The comment is the **P3 W-block** mask-row doc and concerns two *different* blocks' evaluations. For an equality seam, sharing the blinding source discloses **0** (case 3a) and `c = 0` discloses **0** (case 5). `c ≠ 0` and slot length are **soundness/simulator** conditions here, not hiding ones. `e ≠ 0` **is** a hiding condition (case 6: 8 Fp) |
| **E-13** | §B.2 lines 327-339: the tiling constraint "costs nothing"; "the same zero-check with `nb_d` more entries" | `argument.rs:709`; `layout.rs:512` | `a_range(A_X, A_RDL)` sweeps **35 different planes at one point**, not sub-planes. At `nb_d = 3` the `Dom::D` zero-check reads 105 A slices, so ≈ **+70 claim sites and +140 `A_attn` rows**, plus the same factor on 19 `H` helpers. The *relative* claim (free against any other tiling at a non-power-of-two `T·d`) is correct and should be stated that way |
| **E-14** | §B.2 line 318: the tiling constraint holds "at any width" | `statement.rs:153-155` | It is vacuous at `nb_d = 1` (Mistral) and unnecessary at `nb_d ∈ {2, 4}`, where the public index map of §3.5 (`μ_c := eq(ρ_c, c)`) binds the *flat* plane to the `nb_d` blocks with **no re-tiling and no extra draws**. Restate as *"at any width where `nb_d` is not a power of two"*, and name the index map for the rest |
| **E-15** | §B.7 R6, line 584: `c.len() != 16` for the M columns at `:129`; `hiding(&p.a_open, 5, ..)` for five A groups at `:121` | `zk_ffn_fresh_wire.rs:129-137`, `:101-108` | Both wrong. M uses `c.len() != self.mask_rows` (computed; `io_shape` already adds 4); A uses `self.a_groups` (`io_shape` already sets 7). The hard-coded **5** is on **H**. The frame's real model-width blockers are `groups(.., 512)`, `p.len() == 11`, `*j < 2048` and `p.len() != 12` — all frozen to `log_cols 8 / inv_rate 8` |
| **E-16** | §D.6 case 8, lines 953 and 1521: two masking commitments jointly, "the gate: if the joint exceeds the sum of parts, stop and redesign" | `ZK60_NATIVE_JOINT_VIEW.md` §3, §9a answer 1; measured §1.4 case 8 (**0 = sum**) | A linear model cannot decide it: an `M` opening's independently published functional touches **no data coordinate** whatever the number of `M`s. Replace case 8 with the per-slot **derived-mask-evaluation identity** of joint-view §3.1, asserted for **both** `M`s on a real form-E receipt |
| **E-17** | §B.7 items, lines 598-601: the three v3 cuts at `zk.rs:2467`, `:2477-2478`, `:2632`; the attention cuts at `protocol.rs:296`, `:304` | `zk.rs:2537`, `:2548`, `:2702`; `protocol.rs:316`, `:324` | Substance right, all five citations wrong by ≈ 70 / ≈ 20 lines |
| **E-18** | §C.2 line 665: move semantics "`zk.rs:3219-3226` on the v3 side" | `zk.rs:3219-3226` is function 2's predicate tables | The guarantee is `PendingV3::finish(mut self, ..)` owning `mc`/`a`/`h` and dropping them at `zk.rs:2310`, `:2326`, `:2331`, or by `self` on a `?` |
| **E-19** | §F.5 lines 1279-1284: recursion cannot bind because "it must compare the two planes, which means opening them" | the draft's own §F.4 argument, lines 1229-1235 | Wrong reason. A recursive verifier binds without any PCS opening. The right reason is the one the draft gives for candidate (iii): a claim can only be authenticated by an opening under a transcript that already contains its challenge point, so binding needs a shared transcript — which is (i). Recursion additionally does not exist on this line and moves the obligation onto a published boundary root (D8/D11) |
| **E-20** | §G.2 table, line 1425: `H_attn ≈ 15,334` against the prose's 15,242 (line 1441) | recount, §7.3 | 15,242 is the data-row figure and is **exact**; 15,334 silently adds ≈92 mask rows, which the `A_attn` row of the same table lists separately. Cosmetic, but the table should be consistent. The totals 11,082 / 11,292 / 26,676 all reproduce exactly |

### CONDITIONS THE DRAFT OMITS

| # | condition |
|---:|---|
| **C-1** | **The counterparty's seam claim must carry its own reserved mask pair, and this is quantified**: small-model case 15 discloses **8 Fp** without it. Together with decision 6 (port `audit_claims` to the v3 claim path before any external claim is pushed onto `A_ffn`), make both a build precondition. Case 16 (two seams sharing one pair on one side) also discloses 8 Fp and is caught today on `A_attn` only (`protocol.rs:129-131`) |
| **C-2** | **Restate the joint view's stage-4 argument per CHANNEL, not per commitment.** The seam's round channel has data support on **both** commitments while its randomness lives only on `M_ffn`'s slot; the phrase "disjoint randomness across A, H, the endpoints and M" does not cover it. The decomposition still holds (the slot's coefficients are disjoint from every PCS pad), but the sentence in §D.4 step 1 must say so explicitly |
| **C-3** | **State the structural reason the answer is 0**, which the draft never does: on the honest witness the seam's tables are pointwise equal, so `poly = v0·(v1−v2)` vanishes identically, every masked round is exactly `c·g_j(X)`, `γ = c·g.total()` carries no data term, and the extension round reduces to `(1−x)·x·eq(τ,ρ)·(ext_L − ext_R) + c·g_k(x)`. Only the two masked terminals carry data, and each is its side's own claim value under its own pair |
| **C-4** | **The form-E module must be declared inside `hashline::zk`** (a descendant, as `zk::fresh_poc::io` is), because `PendingV3`, its fields, `prepare_layer_zk_v3_inner` and `verify_layer_zk_v3_with_seams` are all module-private to `zk` (`zk.rs:2292`, `:2337`, `:3471`) while `private_block` is a sibling (`lib.rs:51`). From inside `zk` it can still reach `private_block`'s `pub(crate)` items. The alternative — making those four `pub` — widens the frozen prover's API and should be refused |
| **C-5** | **`before_openings` exposes `ac` but not `hc`** (`zk.rs:3471-3472`). Form E must keep every seam claim on `A`, or the hook's signature changes — which touches a frozen verifier |
| **C-6** | **Two `mask_open` calls draw two separate θ** (`zk.rs:515`) at two transcript positions. The `MaskFunctional` lists of `M_attn` and `M_ffn` must not be mixed; there is no check for that today and `combined_weights` would silently index the wrong spec (`zk.rs:470-487`) |
| **C-7** | **Count the cross-side LogUp collision term once.** With one shared `(β, γ, α)` the two sides' tag sets must be injective; they already are, deliberately (`tables_attn.rs:29`, `:73-76`: attention ≥ 128, feed-forward `{3, 4} ∪ 64..=88`). Turn the comment into an assertion, and add the ≈ `2^41/2^128` collision term to §E once |
| **C-8** | **The D12 item 2 amendment must also say that a run's internal boundary residuals are hidden intermediates under item 3**, or the new sentence licenses a run whose internal boundaries sit on caller-fixed roots — which item 3 forbids |
| **C-9** | **Recount openings per pass under (i′).** A `g`-block proof has two endpoint commitments for the whole proof, not two per block: 256 openings at `g = 2`, 226 at `g = 32`, against 288 for 32 single-block proofs. A small soundness gain the draft does not claim |
| **C-10** | **Sharpen the Amdahl warning.** `W_ffn`'s 10,752 rows are the *public* weights. Against the feed-forward's **private** commitments alone (3,669 + 3,030 + 20 = 6,719 rows) the attention half is **80 %** of the private material, not 60 % |
| **C-11** | **§D.5's "8 Fp, all of it public identity" is an accounting sum, not a measurement**, and must be labelled so. Under the joint-view's accepted convention (`ZK60_NATIVE_JOINT_VIEW.md` §9a answer 1) it is `2 (H_attn) + 2 (H_ffn) + 2 (M_attn) + 2 (M_ffn)`; the PCS channel measures **0** on both sides jointly (§1.4 case 0), and **none of the 8 is the seam** — which is the draft's real, and surviving, claim |

**What survives the table.** The construction's core is sound on everything
I could check: nothing is opened twice, the seam claim is audit-compatible,
the seam adds **0** to the disclosed dimension on the small model, the
reserved-pair discipline is the right discipline and is quantified, the
soundness arithmetic reproduces to the last digit, the tiling finding is
true, and the chaining recommendation (i′) is the right shape. What must
change before code is the acceptance criteria (E-1, E-2, E-16), the tiling
constraint's scope (E-3), the memory claim that the build plan rests on
(E-4), and the transcript-restructuring ruling (E-5).
