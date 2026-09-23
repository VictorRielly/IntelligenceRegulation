# Adversarial check of the GS-13 draft (the non-linear channel at the shaped layouts)

**Status: CHECK COMPLETE, findings open for the drafter and the security
owner.** Independent adversarial check by one delegated Opus agent, started
2026-09-22 20:11 PDT, findings written 20:38 PDT. Target:
`docs/zkmatrix-poc/ZK60_NONLINEAR_CHANNEL_SHAPED.md` (DRAFT, unchecked, main
tree at `55719ea`) and its machine check
`results/zk60_nonlinear_channel_shaped/` (`nl_check.py`, `nl_field.py`,
`nl_check.json`, `nl_check.log`). I did not edit either. **Not a privacy
acceptance** — only the security owner rules.

> **Headline: no counterexample, nothing blocking.** Re-derived by a different
> method (a symbolic monomial expansion instead of random evaluation, an
> analytic proof of Fact 2.1 for every challenge vector, full-size fibre runs
> with the protocol's real slot kinds), every load-bearing algebraic claim of
> the draft holds at rung-G, rung-K4 and 125M. **Four errata and seven notes.**
> The largest erratum (N-1): the draft's fibre test treats all 23 slots as
> *Private* slots, so at the 11 Standalone and Host slots it tested worlds the
> protocol never produces. I re-ran it with the real kinds and admissible
> witnesses — 4 Standalone runs at the full rung-G cube and 18 host couplings
> (all six hosts × rung-G, rung-K4, 125M): 22 of 22 pass, the two matching
> controls fire, and 4 further full-size runs of the bilinear slots 08 / 09 at
> 125M pass too.
> GN-1 (completeness for every admissible witness) stays open, as the draft
> says.

## 0. Plain words first

**What the draft claims.** The toy block's privacy proof has a "curved" half:
the sumcheck messages and the one number the mask commitment reveals about
them give nothing away. The draft says that half carries over unchanged to
the big shapes, where three things are new: some steps have degree 5, the two
attention-score steps multiply by a public "which key-value group" factor, and
eight to eleven steps multiply by a public padding indicator.

**What I did.** I tried to break it, and I checked it a different way from
the draft wherever the claim carries weight:

* instead of plugging random numbers into each step's polynomial, I
  **multiplied every polynomial out** into its list of terms (monomials) and
  checked each term by inspection. That verdict holds for every value of
  every challenge, so the draft's question "are the random coefficient values
  realistic?" stops mattering;
* instead of computing ranks at sample challenge points only, I **proved**
  that the masking polynomial covers every step for every challenge vector,
  then confirmed it numerically at all 42 sizes and 7 challenge patterns;
* instead of a 3-variable stand-in, I ran the "two worlds, same published
  numbers" construction **at the real size** of four steps, with their real
  public tables, and — the part the draft missed — with each step's **real
  kind** (a Standalone step must sum to zero; a Host step's sum is tied to the
  steps it hosts).

**What I found.** No privacy counterexample and nothing that blocks. The
draft's numbers all reproduce (every total, every count, 40 of 40 source
citations). What is wrong is the way some evidence is described: the draft's
two-worlds test used worlds that break the rules of 11 of the 23 steps, and
its "control" for one dependency could not fail. I replaced both with tests
that respect the rules, and they pass. A stale-number correction the draft
proposes is incomplete, one "largest mask" location is a tie, and a few
checks are illustrations rather than tests.

**What is still owed** is unchanged from the draft: completeness for every
admissible input (GN-1), the linear half (H1), the hash layer, runs.

## 1. What I checked, and how it differs from the draft's own check

All of it is `results/zk60_nonlinear_channel_shaped_check/nlc_check.py`
(Python, exact Goldilocks arithmetic in its own `nlc_field.py`, written
without importing or copying the draft's files; about 25 s, CPU only, no Rust).
Inputs are read-only; every digest the draft pinned is byte-identical today
(N-10). Stages:

| stage | what | how it differs from the draft |
|---|---|---|
| K0 | field self-test (7 a non-residue, `u² = 7`, inverses, a rank sanity case) | own implementation, `u² = 7` per `zkp-core/src/field.rs:2,131-163` |
| K1 | every slot of all nine IR exports **expanded symbolically** into its monomial support (cancellation ignored): the premise per extension round, "a public TABLE in every monomial", product degree, per-variable bound, where each support indicator and group `eq` sits | the draft evaluated at three random points with coefficients drawn per occurrence; a support verdict is a sufficient condition that holds for **every** coefficient value, related or not |
| K2 | `L_s`, `dim C_s`, totals, worst `L`, round values, terminals by commitment, words per block, the `(N, d)` pairs, indicator / group-`eq` / degree-5 slots | recounted from the IR's `(main, ext, d)` and tables |
| K3 | the extension round of every private push in `define`, by a **balanced-parenthesis** parse (multi-line safe) plus the helper defaults and every `Tab::Priv` construction site; the IR labels of slots 08 / 09 against the code's coordinate lists and push order; `SLOT_KINDS`, `HOSTS`; IR table kind against provenance | the draft used a one-line regex and assumed the IR is in push order; I check the order |
| K4 | Fact 2.1: the mask map `R` built **per basis coefficient** from a derivation of `g`'s round messages (checked against a brute-force cube sum, 260 values), rank, `Im R ⊆ C`, and the eval / sum weights factoring through `R` by **augmented rank**, at 42 pairs × 7 regimes; plus the analytic proof below | the draft ported `CfsMask::round` and tested the explicit kernel |
| K5 | the Theorem 3.3 fibre with the protocol's **real kinds** and **admissible** witnesses: slots 08 / 09 at their full 125M cube (real group `eq`, two extension rounds); Standalone slots 20 / 21 at their full rung-G cube (claim 0, scalar `cG`, `Γ` revealed); all six hosts with their two hosted slots at rung-G, rung-K4 and 125M (IR polynomials, 2³ cubes, host relation enforced, scalars and `M` functionals as `argument.rs:522-526, 561, 603-615` build them); main-round challenges in `{0, 1}`; three controls | the draft modelled every slot as Private with random (inadmissible) tables on 2³ cubes |
| K6 | my figures against the draft's `nl_check.json` | — |
| K7 | the draft's 40 source citations, line by line; the GN-1 evidence markers | — |
| K8 | Lemma 3.1's pad argument at the shaped mask lengths: rank of the 256 × 256 pad block of the `G_512` Lagrange basis at 256 opened coset points, at `L = 50, 117, 256`, with a one-pad-short control | not in the draft (it cites D8 as shape-free) |

**Fact 2.1, proved for every challenge vector (K4's analytic part).** With
`g(x) = a₀ + a′ Π x_i + Σ_{i,e} a_{i,e} x_i^e`, round `j`'s message is
`g_j(X) = 2^{N−1−j}(a₀ + Σ_{i<j} u_i(ρ_i) + u_j(X) + ½ Σ_{i>j} u_i(1)) + a′ P_j X`
with `P_j = Π_{i<j} ρ_i` and `u_i(X) = Σ_e a_{i,e} X^e`. `R(a) = 0` forces
`g_j ≡ 0` for every `j`, i.e. `a_{j,e} = 0` for `e ≥ 2`,
`a_{j,1} = −2^{j+1−N} P_j a′`, and every constant term zero; the constant
terms then telescope (`a_{j,1} ρ_j = ½ a_{j+1,1}`) so the single condition at
`j = 0` fixes `a₀`. The kernel is therefore **exactly one line for every
`ρ ∈ Fp2^N`** — zeros, ones, repeats included — so `rank R = Nd + 1 = dim C`
with no exceptional challenge, and both `eval_weights` and `sum_weights`
annihilate that line (direct substitution), so both factor through `R`. The
numeric run (294 / 294) only confirms this.

## 2. Findings

Ranked. **No finding is blocking and none is a privacy counterexample.**

### N-1 (erratum) — the fibre test models every slot as a Private slot; at the 11 Standalone and Host slots its worlds are not the protocol's

**What the draft says.** §0: "for every step at every shape, I built two
worlds with different hidden data that publish exactly the same numbers …
207 of 207"; §2.5 items 1–5.

**What the code of the check does.** `miniature()` fills every table of every
slot with random values (`nl_check.py:665`) and publishes
`A = σ + c·G` through `masked()` (`:616-623`), which never reads `sl.kind`.
So at a **Standalone** slot (03, 19, 20, 21, 22) the two worlds have `σ ≠ 0`
— inadmissible, because the relation says the sum is zero — and the modelled
scalar is `σ + cG`, not the protocol's `cG` (`argument.rs:524`); at a
**Host** slot (02, 14–18) the sum is not tied to the hosted slots' sums and
the modelled scalar is not `c_h G_h − Σ coef·c_hs G_hs` (`argument.rs:525`).
`nl_check.json` confirms it: every Standalone and Host row at 125M has
`fibre_private_gamma_would_differ: true`, i.e. `σ₁ ≠ σ₂`. That is **99 of the
207 rows** (11 slots × 9 exports) testing the Private-kind variant of a
polynomial the protocol runs under a different kind.

**Why it does not break the conclusion.** In the claimed-sum coordinates the
Standalone case is the Private case restricted to `σ = 0`, and the Host case
is the Private case after the triangular map `T ↦ T′` (D7). But that is an
argument, and the draft presented the test as evidence for all 23 slots.

**Independent repair (K5), all pass:**

* Standalone slot 21 (IO equality) at its **full rung-G cube** (2¹², real
  `eq(tau)`), witness with plane = endpoint; Standalone slot 20 (zero-sum row)
  at its full cube (2¹⁰, the real all-ones table), witness with `Σu = 0`: the
  claim is 0 in both worlds, the published scalar is `cG`, `M` reveals
  `Γ = cG`, and the two admissible worlds publish identical scalars, rounds,
  terminals **and** identical `M` eval and `Γ` values — 2 regimes each
  (random challenges; main-round challenges in `{0, 1}`).
* **All six hosts** (02, 14, 15, 16, 17, 18) coupled to their two hosted
  Private slots (`HOSTED` in `nlc_check.py`, from `argument.rs:1164, 1445,
  1566, 1629, 1695`, with `per_row` for `SC_RS`), at rung-G, rung-K4 and 125M:
  the host relation `σ_h = Σ coef·σ_hs` enforced in both worlds; each slot's
  verifier chain and final identity `(fin − poly(vals))/c = g(ρ)` accept in
  both worlds; **every** published scalar, round, terminal, `M` eval value and
  the host's `Γ` is identical across the worlds — **18 of 18**.
* Controls: slot 21 with an inadmissible world 2 (one endpoint entry off by
  one) — `T′` of world 2 leaves `C`, **no fibre exists** (fires); host 17 at
  125M with an inadmissible world 2 — the host scalar and its `Γ` differ and
  the **verifier rejects** world 2 (fires).

This also narrows **GN-4** (cross-slot coupling "checked structurally only"):
the triangular host coupling is now exercised, on miniature cubes, for every
host at the three shapes of record.

**Fix.** In §0 and §2.5 say the miniature runs model every slot as a
Private-kind sumcheck; label the 99 Standalone / Host rows accordingly; cite
K5 (or add equivalent correct-kind runs) for the kinds; move GN-4 to "host
coupling exercised on miniatures, the `θ`-batch follows from per-functional
equality".

### N-2 (erratum) — the "in-test control on D9" cannot fail, and at 11 slots it probes a functional the protocol does publish

**What the draft says.** §2.5 item 6: "the slot's own mask total `c·G` differs
between the two worlds by exactly `σ₁ − σ₂`. Had a Private slot's `Γ` been one
of `M`'s functionals, `q` would separate the two worlds … the control of item 6
fires at 207 of 207."

**Why it is not a control.** Item 5 already requires equal published scalars,
`σ₁ + cG₁ = σ₂ + cG₂`, which **is** `c(G₂ − G₁) = σ₁ − σ₂`; the code compares
exactly those quantities (`nl_check.py:736-746`, where `G1`, `G2` already
include `c`). Whenever item 5 passes, item 6 passes. And at the Standalone and
Host slots the functional it probes **is** one of `M`'s functionals in the
protocol (`argument.rs:604-611`); with admissible worlds it does **not**
separate them (N-1, K5). D9 itself stands — it is a code fact,
`SlotKind::Private => {}` at `argument.rs:613` — CONFIRMED-WEAKLY by reading.

**The control done where it means something (K5).** In the 18 host-coupling
runs, adding a `Γ = c_hs G_hs` for a **hosted Private** slot to `M` would
separate the two admissible worlds — 18 of 18. That is the real reason D9
matters.

**Fix.** Drop "control fires 207 / 207" from §2.5 and the headline table;
state D9 from the code; if a test is wanted, use the hosted-Private version.

### N-3 (erratum) — the proposed correction of the run memo's stale totals is incomplete

The draft (§3.5) corrects `ZK60_JOINT_LAW_COMPOSITION_RUN.md` §2.1's table
(`:323-324`, 840 / 817 and 1,208 / 1,185). The attribution is right: the run
memo pinned lane tip `caa9b9a` (2026-09-20 16:39) and its errata revision
`1a858ee` is 18:18, both before stage 20 (`5155d5b`, 19:09), and the
differences +19 / +31 are exactly slots 08 / 09's repair (K2 reproduces
859 / 836 and 1,239 / 1,216). But the same pre-repair figures sit in three
more places the correction does not name:

* the theorem statement, `:598` — "with `dim C` replaced by 817 (rung-G) or
  1,185 (125M)";
* the run simulator `O1_run`, `:756` — "uniform on C^k (dimension 817 or
  1,185)";
* the draw-count reconciliation of check B-8 / ruling R-7, `:1660-1664` —
  "+ M with ΣL_s bounded by 23 × 117 instead of 1,208 … +2,966" (at the
  post-repair `Σ L_s = 1,239` the term is `2 × (2,691 − 1,239) = 2,904`), and
  with it every draw count in that memo built on `Σ L_s` (+62 draws per 125M
  block). The residual 2^-69.3 does not move at that precision.

**Fix.** Name all four places; say the B-8 reconciliation is exact for the
pre-repair schedule.

### N-4 (erratum) — rung-G's largest mask length is a tie

§2.3: "largest `L` 72 (rung-G) and 77 (rung-K4), both at slot 17". At rung-G
slots 17 **and 18** are both `(13, 1, 5)`, `L = 72` (K2). Rung-K4 (17 alone,
77) and 125M (17 alone, 117) are right. **Fix:** "72 at slots 17 and 18".

### N-5 (note) — three "checks" are illustrations that cannot fail

* The per-slot terminal-pair rank "69 / 69" (§2.6, §5 table): each terminal
  owns its pair, and `(r_re, r_im) ↦ cm(r_re + U r_im)` is a bijection
  `Fp² → Fp2` for every `cm ≠ 0` whatever `eq(tail)` is (it has a non-zero
  entry). The model uses a 2-variable tail at every slot
  (`nl_check.py:1059-1060`). Rank `2m` is guaranteed by construction.
* C7 and C8 are the same linear algebra with one weight or one pair changed.

They show a mechanism; they do not test the code. The code facts behind them
are the weight shape `(cm, cm·U)` (`argument.rs:383-385`, read) and pair
exclusivity (`audit_claims`, which is (H1)). **Fix:** label them
illustrations and take them out of the headline figures.

### N-6 (note) — GN-8's refusal inventory omits the `ν` refusals

GN-8 lists `c_s = 0` (23), `e ∈ {0, 1}` (25), `ζ = 0` (5 at 125M). Every host
arm also draws its two hosted-claim weights through `nonzero(…)` —
`argument.rs:1142` (`SC_TZC`), `:1405` (`SC_DZC`), `:1552` (`SC_FZC`), `:1605`
(`SC_QZC` / `SC_KVZC`), `:1663` (`SC_SZC`) — 12 draws per block, refused if
zero. Challenge-only, so liveness, not distance; the inventory should list
them.

### N-7 (note) — the per-variable degree walk is implied by the product degree

Every table is multilinear, so a monomial's degree in one variable is at most
its number of factors; "per-variable ≤ `d`" follows from "product degree ≤ `d`"
and the separate walk (`nl_check.py:233-270`) adds nothing. The "3–4"
entries in §2.2's column are the walk's own conservative bound, not the true
per-variable degree. Harmless.

### N-8 (note) — §2.5's "real CFS mask map" is at the miniature's size

The miniature's mask map is `(N, d) = (3 + ext, d)`, not the slot's real `N`;
the real-size map is §2.4's (and K4's). Wording.

### N-9 (note) — GN-1 pointer: the toy's refusal-site census does not transfer

Not a finding against the draft (it leaves GN-1 open), but a place to look.
The toy census (`refusals.rs:270-280`, asserted at `:321-322`) proves the `AO`
site unreachable from `|o8| ≤ 127`, `|Wo| ≤ 128` and **16** terms. At 125M the
sum has 768 terms: `|aoacc| ≤ 768·127·128 = 12,484,608`, so `requant(·, 7)`
reaches ±97,536, outside int16 — the site becomes **reachable**. The witness
builder refuses there too (`witness.rs:594`, `quantize(…, -32768, 32767,
"AO")`), so this is an admissibility boundary, not a completeness hole; but
I found no shaped equivalent of the toy's builder-versus-kernel census
(searched the lane's `private_block` sources for the census vocabulary).
GS-14 should include one.

### N-10 (note) — the lane head moved; nothing the draft pinned did

The draft pins lane head `d597a1d`; the lane is at `4373fb6` (stage 37:
`k8_tests.rs` and one `#[cfg(test)]` module line, test-only). Every digest the
draft pinned (`argument.rs f7fa2ad4`, `layout.rs 14758039`, `shape.rs
dbf4e2bc`, `zk.rs d4280962`, `sumcheck.rs 56dbb8c7`, `slot_ir.rs 734cd0e0`,
nine IR exports) is byte-identical at `4373fb6`. The IR files were rewritten
at 20:08:52 with identical bytes by the lane's stage-37 private gate
(`results/zk60_block125m_lane/s37-gate-private.log`, untracked in the lane,
`.done` = 0 at 20:10:38: 429 passed / 0 failed / 18 ignored), which includes
`slot_ir_tests::the_slot_ir_evaluates_to_the_closure_at_every_registered_shape_and_slot
... ok` and the export-canonical / digest test — so D14's oracle has a fresh
green run at the current code (CITED from the lane's log, not re-run here).
No figure moves.

### N-11 (note) — the norm gains' IR provenance

The two norm gains are `pub` tables with provenance `public-from-shape`
(IR at 125M, slot 14, tables 3 and 4). They are model weights, public under
P1. Irrelevant to P1; the P3 probe (C9) found them by label. For P3 scoping a
"public weight" provenance class would make the probe mechanical.

## 3. Verdict per draft claim

Labels: **CONFIRMED** = re-derived independently; **CONFIRMED-WEAKLY** = only
re-read; **REFUTED** = wrong as written; **UNVERIFIABLE** = cannot be decided
here.

| # | draft claim | verdict | evidence |
|---|---|---|---|
| 1 | no counterexample; (NL) lifts unchanged in proof at rung-G / K4 / 125M | **CONFIRMED** for every dependency testable without a receipt | K1–K5, K8 |
| 2 | premise with a public factor in every monomial, 184 / 184 shaped pairs | **CONFIRMED**, stronger: on the monomial support, for every coefficient value; also every IR term carries a public table at top level, 184 / 184 | K1 |
| 3 | toy: 23 premise, 21 by a public factor, 08 / 09 by different rounds | **CONFIRMED** | K1 (toy row), K3 |
| 4 | product degree ≤ declared, 207 / 207; walked = export's figure | **CONFIRMED** | K1 |
| 5 | Fact 2.1 tight, 210 / 210 (42 pairs × 5 regimes) | **CONFIRMED**, and proved for every `ρ` | K4, §1 |
| 6 | fibre test, 207 / 207 | **CONFIRMED for the 108 Private rows; overstated for the 99 Standalone / Host rows** (N-1); the correct-kind replacement passes 22 / 22 | K5 |
| 7 | in-test D9 control fires 207 / 207 | **REFUTED as a control** (tautological, N-2); D9 CONFIRMED-WEAKLY from the code; the meaningful control fires 18 / 18 | K5 |
| 8 | 12 / 12 control verdicts as expected | **CONFIRMED-WEAKLY** (read: C1–C6, C9 and the anchor are genuine; C7 / C8 are illustrations, N-5) | draft code |
| 9 | worst mask length 117 of 256 (125M slot 17) | **CONFIRMED**; budget holds at all nine exports | K2 |
| 10 | slots 08 / 09's second mechanism is now a backup | **CONFIRMED** (group `eq` in the single monomial at every shaped export; rounds 0 / 1 from the source) | K1, K3 |
| 11 | "public factor" must mean a public TABLE (R-b); no monomial's only public factor is an affine constant | **CONFIRMED**: 0 monomials without a public table at every shaped export; every monomial containing a support indicator also contains an `eq` table; 0 kind / provenance mismatches | K1, K3 |
| 12 | extension-round assignment (only `:1341`, `:1367` carry round 1; helpers hard-code 0) | **CONFIRMED** by a different parse; IR private order = push order at 18 / 18 | K3 |
| 13 | corrected totals 859 / 836 and 1,239 / 1,216; +19 / +31 = the repair | **CONFIRMED**; correction incomplete (N-3) | K2 |
| 14 | toy 583 / 560, 721 round values, 173 terminals; rung-K4 1,269 words; 125M 1,751 words | **CONFIRMED** | K2 |
| 15 | eight indicator slots at 125M, eleven at rung-G / K4; group `eq` at 08, 09; degree 5 at 14, 15, 17 (125M) and also 16, 18 (rungs) | **CONFIRMED** | K2 |
| 16 | rung-G largest `L` 72 "at slot 17" | **REFUTED in detail** (tie with 18, N-4) | K2 |
| 17 | 42 distinct `(N, d)` pairs, `N` 5–23, `d` 2–5 | **CONFIRMED** | K2 |
| 18 | per-slot terminal maps onto, 69 / 69; C7, C8 | **CONFIRMED but vacuous** (N-5) | algebra |
| 19 | P3 note: the seven matmul slots lose their public factor; slot 14 survives | **CONFIRMED-WEAKLY** (K1 shows the matmul monomial's only public factor is the folded weight table; slot 14's gains sit under `eq`) | K1 |
| 20 | GN-1 open; the dense 125M evidence | **CONFIRMED open**; markers `m125-run-l12-dense.done = 0`, `m125-capture-dense-l2.done = 0`, 12 / 12 log lines "4/4 key-value groups live" and "groups differ true" | K7, N-9 |
| 21 | 40 source citations of §1.2 / §2 | **CONFIRMED**, 40 / 40 contain the cited text | K7 |

The dependencies of §1.2, one by one:

| dep | verdict | how |
|---|---|---|
| D1 (`d + 1` values, one degree for all rounds) | CONFIRMED | `sumcheck.rs:148-150`, `zk.rs:1094`, `sumcheck.rs:287`; K4 control: a degree-4 mask at (23, 5) covers 93 of 116 |
| D2 (`L = Nd + 2` over all `N` variables, mask degree = declared) | CONFIRMED | K4; `layout.rs:1183-1185` and the prover's actual draw `protocol.rs:891` (`mask_commit_tagged(&lay.mask_specs(), …)`) |
| D3 (`c ≠ 0` refused) | CONFIRMED-WEAKLY | `argument.rs:476-479` |
| D4 (degree fits) | CONFIRMED | K1 (N-7) |
| D5 (premise) | CONFIRMED | K1, symbolic |
| D6 (semantic completeness) | UNVERIFIABLE here | GN-1; N-9 |
| D7 (hosts triangular, `T ↦ T′` invertible) | CONFIRMED | K3 parse; K5 host coupling 18 / 18 |
| D8 (`M` geometry) | CONFIRMED-WEAKLY, plus K8 | the pad block is Cauchy-type, invertible for any 256 pad positions: rank 256 at `L = 50, 117, 256`, control 255 with one pad short; opened coset points lie outside `G_512` |
| D9 (no `Γ` for a Private slot) | CONFIRMED-WEAKLY | `argument.rs:613`; N-2 |
| D10 (non-private `vals` public) | CONFIRMED | `argument.rs:565-579`; K5's verifier final identity with the real group `eq` and real `eq(tau)` |
| D11 (weights factor through `R`) | CONFIRMED | K4 augmented rank + §1 proof |
| D12 (mask coefficients uniform) | UNVERIFIABLE | an assumption (sampler, D9 of the register) |
| D13 (terminal formula, `e ∉ {0, 1}`) | CONFIRMED | K5 builds world 2's pairs from `cm = e_r Π_{m>r}(1 − e_m)` and the terminals align; `argument.rs:586-597` |
| D14 (IR = closure) | UNVERIFIABLE here, partly re-read | the lane's oracle is cited, and it ran green today at the current lane code (N-10); I read the 16 arms of `define`, and at 125M the IR agrees with them slot by slot on the public-table inventory (tables of kind `eq` / `pub` / `supp` / `group_eq` match the arms' `b.eq` / `b.public` / `b.supp` / `b.group_eq` pushes by count and label) and on the top-level terms (coefficient, wrapper tables, host expression — e.g. slot 14's `eq(tau)·zc + ν₀·eq(p_a)·supp(D)·host_wo + ν₁·eq(p_z)·supp(D)·host_dmm` against `argument.rs:1539`); inner node bodies compared in detail at slots 00, 04, 08, 09, 17, 19, 20, 21 only |

## 4. Independent figures against the draft's

Every figure below is mine (K2 / K4) and equals the draft's unless marked.

| figure | toy | rung-G | rung-K4 | 125M |
|---|---:|---:|---:|---:|
| main + extension rounds | 159 + 25 | 217 + 25 | 220 + 25 | 336 + 25 |
| `Σ L_s` / `Σ dim C_s` / kernel | 583 / 560 / 23 | 859 / 836 / 23 | 871 / 848 / 23 | 1,239 / 1,216 / 23 |
| worst `L` (slot) | 50 (17) | 72 (**17 and 18**) | 77 (17) | 117 (17) |
| round values | 721 | 1,055 | 1,070 | 1,554 |
| terminals A / H / endpoint | 120 / 51 / 2 | 122 / 52 / 2 | 122 / 52 / 2 | 122 / 50 / 2 |
| `Fp2` words per block | 917 | 1,254 | 1,269 | 1,751 |
| indicator slots | 0 | 11 | 11 | 8 |
| degree-5 slots (over-declared) | — | 14–18 (14, 15, 16, 18) | 14–18 (14, 15, 16, 18) | 14, 15, 17 (14, 15) |
| monomials in the 23 polynomials (K1) | 343 | 444 | 444 | 413 |
| premise / public table in every monomial | 23 / 21 | 23 / 23 | 23 / 23 | 23 / 23 |

Over the five development exports the same verdicts hold (23 / 23 each). K6
compares eight figures per export with the draft's `nl_check.json`: all 72
agree. Fact 2.1: 294 / 294 (42 pairs × 7 regimes: random, zeros, ones,
alternating 0/1, the interpolation nodes `0..d`, base-field random, all
equal).

## 5. The drafter's attack list, answered

1. **GN-1.** I did not find an admissible input at a shaped layout on which a
   Standalone or Host relation fails. Pad-driven failures are
   input-independent (the pad is fixed by the shape), so any would already
   show in the dense runs, which verify; what remains is the admissibility
   boundary, where the builder refuses at the constraint's own ranges
   (`witness.rs:394, 554, 594` read) — but the toy census of those sites does
   not transfer (N-9). **UNVERIFIABLE here; open, as the draft says.**
2. **The extension-round assignment.** CONFIRMED by a balanced-parenthesis
   parse (13 `a_at` / `a_slice` pushes, two with round 1 at `:1341` and
   `:1367`; `a()`, `h()`, `endpoint()` default to 0; the only `Tab::Priv`
   constructions in `argument.rs` are at `:682`, `:727`, `:749`) and by the IR
   labels of slots 08 / 09 matching the code's coordinate lists and push
   order at all nine exports. The draft's one-line regex is fragile but its
   assertion (`nl_check.py:145`) would stop the run on a count mismatch.
3. **The coefficient model.** Moot for the premise: K1's verdict is on the
   monomial support, so it holds for every coefficient value, the protocol's
   related ones included (one `ζ` for all powers, `μ` / `ν` / `α` shared
   across terms). Fiat–Shamir correlations between `ρ` and public tables
   cannot reduce the rank either: Fact 2.1 holds for every `ρ` (§1). K5 uses
   related coefficients and passes.
4. **R-b.** CONFIRMED: at every shaped export no monomial lacks a public
   table, and every monomial with a support indicator also has an `eq` table;
   the IR kinds agree with their provenance (0 mismatches) and with the code's
   public pushes (D14 row above).
5. **The miniature's faithfulness.** K5 re-ran the fibre at the real cube of
   slots 08 / 09 (125M: 2⁸ and 2¹¹, the real group `eq` over the leading 2
   variables, two extension rounds) and slots 20 / 21 (rung-G: 2¹⁰ and 2¹²,
   the real all-ones table and a real `eq(tau)`), with random challenges and
   with main-round challenges in `{0, 1}`: all pass.
6. **"Nothing in (NL) uses a degree bound."** CONFIRMED-WEAKLY: the `M` layout
   sizes each row from `CfsMask::len(n, d)` and asserts it
   (`zk.rs:529`, `:493`, `shape.rs:415-426`); the pad argument holds for every
   `L ≤ 256` (K8). I did not examine the wire and hash length guards.
7. **The hand-off to (H1).** CONFIRMED-WEAKLY: nothing new at the shaped
   layouts enters the terminal / pair structure — the group `eq` and the
   support indicators are public tables with no terminal and no claim (K1,
   K3). Whether the shaped (H1) absorbs the pair shift is (H1) and not
   checked here.

## 6. What I did NOT check

* **(H1)** — the linear channel, the terminal surjection jointly with the PCS
  openings, the joint law across commitments (G-R1, G-R4, GS-6).
* **GN-1 / GS-14** beyond the spot checks of N-9 and §5 item 1.
* **D14** beyond the hand-read of the 16 arms; I did not re-run the lane's IR
  oracle, and nothing here evaluated a Rust closure.
* **D12** (the sampler), the hash layer, the Fiat–Shamir lift, runs, the wire
  and hash length guards, P3, the GPU path, timing.
* No Rust was built or run; no receipt or capture bundle was read. K5's host
  coupling uses 2³ miniature cubes with random stand-ins for the public
  tables; only slots 08, 09, 20, 21 ran at full size.
* The toy's accepted memos were read only where the draft cites them.

**This check is not a privacy acceptance.** Only the security owner rules.

## 7. Evidence

`results/zk60_nonlinear_channel_shaped_check/` — re-runnable with no
arguments, about 25 s, CPU only:

```
python3 results/zk60_nonlinear_channel_shaped_check/nlc_check.py
```

| file | what it holds |
|---|---|
| `nlc_field.py` | Goldilocks `Fp` / `Fp2` (`u² = 7`), rank, rank with span test, solve; self-test |
| `nlc_check.py` | stages K0–K8 as in §1 |
| `nlc_check.json` | every per-slot, per-shape row; every fibre run; the input digests |
| `nlc_check.log` | the run's log, one line per verdict |

Inputs, read-only, SHA-256 in `nlc_check.json`: the lane worktree
`/home/victor/wt-zk60-block125m` at `4373fb6` (sources and IR exports
byte-identical to the draft's pins, N-10; `s24_tests.rs 36a59865`), and the
draft's `nl_check.json` (`aa9a727a`, figures compared only).
