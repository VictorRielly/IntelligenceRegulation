# Independent adversarial check of `ZK60_JOINT_LAW_COMPOSITION.md` (U-3b, the joint law)

**INDEPENDENT ADVERSARIAL CHECK of a delegated draft argument — delegated Opus
agent, 2026-09-20. Paper and Python only; NOT a privacy acceptance.**

Evidence: `results/zk60_joint_law_composition_check/` — `check_mask_dof.py`,
`check_toy_controls.py`, `check_pad_and_group.py` with their `.txt` outputs,
and `rerun_draft_toy_joint_law.txt` (the draft's own enumeration re-run,
byte-identical to its recorded output). No Rust was built or run, no prover,
no benchmark. No witness value, salt or private plane is reproduced anywhere.

Labels used below: **VERIFIED IN THE CODE** (I read the named file:line),
**RECOMPUTED** (my own script, exact arithmetic), **MY OWN ARGUMENT** (paper,
mine, labelled as such and not the draft's), **COULD NOT VERIFY**.

**Headline.** The theorem survives. Its proof is correct given its hypotheses,
no hypothesis restates the conclusion, and the load-bearing source reading
(Lemma 3.1's inventory of what the mask opening publishes) is complete. Two of
the draft's own open questions close in its favour — the completeness premise
Q1 and the block-diagonality gap Q2 — and one of its central conditional
facts (Fact 2.1) turns out to be unconditionally provable in five lines.
Against that: nine corrections, of which three are substantive (the sampler's
θ-ordering is wrong; a step the accepted lemma does not contain is needed and
is supplied here; the restart mechanism §5.4 cites does not exist in this
profile), and the theorem's "perfect" must be re-stated once the real
generator enters.

---

## A1. Theorem 3.3 and its hypotheses — is anything circular?

### A1.1 My own circularity table, built without looking at the draft's

I took each hypothesis of Theorem 3.3 and asked two questions: *what does it
assert*, and *is what it asserts an instance of the theorem's conclusion*.

| | hypothesis | what it actually asserts | is it an instance of the conclusion? | how it is discharged | my label |
|---|---|---|---|---|---|
| H1 | the law of `V_pcs` given `w` is `w`-free | the **four PCS commitments'** group vectors, proximity vectors, opened columns and 173 terminals | **a strict sub-view.** The conclusion is about `(V_sc, V_pcs, V_M)`; H1 is about the middle component alone and says nothing about the other two or about their joint | §4, from Lemma 4.1 (unconditional) + the accepted generic-rank lemma + cross-role independence. §4 never mentions §3 | conditional, **not circular** |
| H2 | `Im R = C`, equal fibres | a rank identity about the CFS mask map | no — a linear-algebra fact about a public matrix | the lemma's §3.5(a); **and I prove it outright below (A3.2)** | now **PROVED** |
| H3 | `M`'s opening depends on `α` only through `V(α)` | a statement about `mask_verify`'s checks | no | Lemma 3.1; I re-read `mask_verify` line by line (A2) and it is complete | PROVED on M-3 |
| H4 | `V(α) = V_pub(V_sc, V_pcs)`, and `V` factors through `R` | the verifier recomputes the mask functionals' values from the published view | no | the CONSTRUCTION PREMISE `poly(exts) = 0` — **I settle it by reading all 23 closures (A4.3)** | now **VERIFIED IN THE CODE** |
| H5 | `α, π, μ` independent and `α` uniform | a statement about `ZkRng` | no | false information-theoretically; M-3 + D9 | ASSUMED |

**Verdict on circularity: none.** The shape refused two days ago — a
restriction that restates the conclusion — is not present. The nearest thing
to it is H1, whose *sentence form* ("the view's law is witness-free") echoes
the conclusion; but H1's view is a strict subset of the conclusion's view, the
theorem's entire work is the composition of that subset with the two channels
H1 says nothing about (`V_sc`, `V_M`) and with the nonlinear link between
them, and §4 is genuinely self-contained: it uses Lemma 4.1, the accepted
lemma's per-role items and a disjointness fact, none of which mentions §3. I
checked this by reading §4 for any use of Theorem 3.3, Lemma 3.1, Fact 3.2 or
`V`; there is none.

Two further shapes I hunted for and did not find: "uniform given the view" used
to prove "the view is uniform" (absent: the pad-uniformity statements are
conditional on the *pads*, never on the view); and the joint hypothesis assumed
and then concluded (absent, as above).

The draft's own Appendix A flags one forward dependency: §2.3's
degrees-of-freedom table uses Lemma 3.1, which is §3.1. That is correct, it is
one-way, and — see A3.4 — the table is a mnemonic that nothing else depends
on, so it is harmless.

### A1.2 The proof of Theorem 3.3, checked step by step

I redid the conditional decomposition. Conditioning on `π` and summing over
`α`:

* the inner indicator really is `1[R(α) = t′ − T′(w, π)]`, because
  `F_sc(w, α, π) = T′(w, π) + R(α)` in the claimed-sum coordinates — this needs
  the hosted masks to cancel in `A_s`, which I verified in the code
  (prover `argument.rs:286-290`, verifier `:322`: the host publishes
  `cΓ − Σκ c_h G_h` and the verifier adds `Σκ Γ_h` back);
* `T′(w, π) ∈ C` **for every `π`**, not only for the `π` that arise on runs
  that verified. This is the step that really needs the completeness premise,
  because `exts` is a function of `π` (the reserved pairs' evaluations) and the
  chain equation of the extension round is `poly_s(exts) = 0`. The draft does
  not say that `π`-uniformity is where the premise bites; it is. See A4.3,
  where I settle the premise;
* the fibre count is `|Fp2|^{583−560} = |Fp2|^{23}`, one kernel dimension per
  slot — RECOMPUTED (`Σ L_s = 583`, `Σ dim C_s = 560`, `dim ker R_s = 1` at all
  23 shapes, `check_mask_dof.txt`);
* the remaining factor `Φ(m; V_pub(t, v))` is `π`-free, so it comes out of the
  `π`-sum. Correct.

**The proof is valid.** Its conclusion is exactly as strong as (H1)…(H5) and no
stronger.

---

## A2. The masked sumcheck from the code — what is actually published

### A2.1 What one slot publishes, in order (VERIFIED IN THE CODE)

`hashline/src/private_block/argument.rs:257-384`, one slot:

1. `absorb_u64(b"pb-slot", s)`;
2. `c = tr.challenge_fp2()`; **`c == 0` returns an error, never a redraw**
   (`:274-277`);
3. `absorb_fp2(b"pb-scalar", &[scalar])` — **exactly one** `Fp2`:
   Private `σ_s + c·G_s`, Standalone `c·G_s`, Host
   `c·G_s − Σ κ·c_h·G_h` (`:285-290`);
4. the `n_s` main rounds through `masked_prove`, then `ext_s` extension rounds
   through `extension` (`zk.rs:972-997`); each round absorbs `b"sc-round"` with
   **exactly `d_s + 1`** values, the masking applied inside the transcript
   (`transcript.rs:66-81`, `sumcheck.rs:284-294`) so nothing unmasked is ever
   absorbed;
5. refusal if any extension challenge `e ∈ {0, 1}` (`:347-349`);
6. `absorb_fp2(b"pb-term", &terms)` — `slot_terms(s)` masked terminals;
7. **no mask evaluation is transmitted**: the verifier derives
   `g_val = (fin − poly(vals))·c⁻¹` (`:340`), and the wire frame has no field
   for it (`wire.rs:46-96`, `encode` writes scalar, rounds, terms and nothing
   else).

Totals RECOMPUTED from `layout.rs SLOTS`: `Σ n_s = 159`, `Σ ext_s = 25`,
`Σ N_s(d_s+1) = 721` round values, 23 scalars, `120 + 51 + 2 = 173` terminals,
`Σ L_s = 583`, `Σ dim C_s = 560`, `max L_s = 50`, 11 distinct `(N_s, d_s)`.
**Every number in the draft's §1.3 and §2.3 reproduces.**

### A2.2 `mask_verify` — the source reading the draft calls the one most worth redoing (Q3)

`mask_verify` is **not** in `sumcheck.rs`; it is
`hashline/src/zk.rs:552-590`. Its complete list of checks:

| # | check | line |
|---|---|---|
| 1 | `q.len() == 2m` (1024) | `:558` |
| 2 | **`512·(q[0] + q[512]) == v`**, `v` the θ-batched *declared* functional values | `:560-561` |
| 3 | absorb `q`, draw `2S+2 = 48` proximity coefficients `r_row` | `:562-563` |
| 4 | `prox.len() == 2m`; absorb `prox`; draw the 256 indices | `:564-566` |
| 5 | per opened column: index match, `col.len() == 50`, Merkle path, **`b(x_j) + Σ_s a_s(x_j)·W_s(x_j) == q(x_j)`**, **`u(x_j) + Σ_row r_row·row(x_j) == prox(x_j)`** | `:573-588` |

**Nothing else.** No degree bound on `q` beyond its 1024 transmitted
coefficients, no second sum identity, no per-column check that pins more than
the `b` and `u` entries. **Q3 is answered: Lemma 3.1's inventory is complete.**

Three things I can state more sharply than the draft does, all VERIFIED:

* `combined_weights` writes only positions `j < L_s` (`zk.rs:476-481`), so the
  weight polynomials vanish on the 256 pad positions and **the pads cancel out
  of `V` exactly**. That is what makes `q ⊥ pads | a` and therefore stops the
  double count the brief asks about (A3.4);
* `b_re[512] = −b_re[0]`, `b_im[512] = −b_im[0]` and nothing else constrains
  `b` (`zk.rs:452-455`), so `p_b` is uniform on a subspace of Fp-codimension 2
  and `q` is uniform on the coset `{q[0]+q[512] = V/512}`. `u_re, u_im` are
  **unconstrained** (`:456-457`) and enter `prox` with coefficient 1
  (`:537`), so `prox` is a clean one-time pad;
* the verifier computes `v` itself from the declared values. So the honest
  statement is stronger than "`M` reveals one `Fp2` functional of `a`": **`M`'s
  opening reveals nothing about `a` that the verifier could not already
  compute**, once Fact 3.2 holds.

### A2.3 One real omission in the draft: the θ-ordering of the functionals

`argument.rs:361-376` pushes, **per slot in schedule order**: a Standalone
slot's `Γ` functional *then* that slot's `eval` functional; a Host slot's `Γ`
goes to a separate list. `argument.rs:924-925` appends the six host `Γ`s at the
**end**. So the declared order is

```
[ (Γ_s if s standalone) , eval_s ]  for s = 0..22 , interleaved
++ [ Γ_s for the six hosts, in slot order ]
```

The draft's O1 step 3 writes
`[Γ_s for standalone s] ++ [g_val_s for all s] ++ [Γ_s for host s]` — the first
two blocks are **not** concatenated, they are interleaved. **The sampler as
written computes the wrong `θ`-batch and therefore samples `q` on the wrong
coset.** The theorem is untouched (it never fixes an order); the algorithm is
wrong as printed. CORRECTION C-1.

### A2.4 Nothing else is published

I walked the whole receipt (`private_block.rs:399-408`, `wire.rs:68-96`):
three roots; per slot one scalar, `(n+e)(d+1)` round values, `slot_terms`
terminals; the `M` opening (`q`, `prox`, 256 × (index, 50 `Fp`, salt, 12
digests)); one opening each for `A`, `H`, In, Out (`G_r` group vectors of 512
`Fp2`, one proximity vector, 256 × (index, `rows` `Fp`, salt, 11 digests)).
**No second evaluation, no intermediate scalar, no `b`/`u` row value beyond the
opened columns, no zero-sum row's sum, no hosted slot's standalone total.** The
draft's inventory is complete. The one quantity a reader might expect and not
find — a Private slot's `G_s` — is genuinely absent, and `argument.rs:374`
(`SlotKind::Private => {}`) is the line that keeps it absent.

---

## A3. The degrees-of-freedom identity, and the `a′` discrepancy

### A3.1 Predictions, recorded before running

`rank R_s = N_s d_s + 1`; `dim ker R_s = 1`; `dim C_s = N_s d_s + 1`;
`sum_weights`, `eval_weights` in `rowspace(R_s)`; dropping `a′` leaves the rank
unchanged; and — my own prediction, which the draft does not make — **dropping
`a_0` also leaves the rank unchanged at generic `ρ` but not at `ρ = 0`**,
because the kernel is one-dimensional and its `a_0` component vanishes exactly
when every `ρ_i = 0`.

### A3.2 MY OWN ARGUMENT: Fact 2.1 is an identity that can be *proved*, not only recomputed

The draft carries Fact 2.1 as **RELIES ON** (the lemma's §3.5(a)) plus 115
recomputed pairs. It does not need to. Fix any `ρ`.

* `Im R_s ⊆ C_s`: the mask's own round messages are an honest sumcheck of
  `g_s`, so `r_0(0)+r_0(1) = G_s` and `r_j(0)+r_j(1) = interpolate_eval(r_{j-1},
  ρ_{j-1})`. (The Rust test `cfs_mask_rounds_match_brute_force`,
  `sumcheck.rs:363-365`, asserts exactly these two equalities.)
* `R_s` restricted to `{a′ = 0}` is **injective**. Suppose `R_s(a) = 0` with
  `a′ = 0`. Round `j`'s message is `2^{N-1-j}(base_j + u_j(X))`, a polynomial of
  degree `≤ d` in `X` vanishing at the `d+1` nodes `0..d`, hence identically
  zero; `u_j(0) = 0` forces `base_j = 0` and `u_j ≡ 0`, i.e. every `a_{j,e} =
  0`; then `base_0 = a_0 = 0`. So `a = 0`.
* Hence `rank R_s ≥ L_s − 1 = N_s d_s + 1 = dim C_s ≥ rank R_s`, so
  **`Im R_s = C_s` and `dim ker R_s = 1`, for every `ρ`, over any field of odd
  characteristic.** ∎

The kernel is explicit: `a′ = 1`, `a_{j,1} = −2^{j+1−N} ∏_{i<j} ρ_i`,
`a_{j,e≥2} = 0`, `a_0 = −½ Σ_{i>0} a_{i,1}`. (`base_{j+1} − base_j =
u_j(ρ_j) − u_{j+1}(1)/2 = 0` by construction, so one `a_0` serves all rounds.)

**This promotes row 5 of the draft's tally from RELIES ON to PROVED, and with
it (H2) and Lemma 2.2.** The `d+1`-values invariant is exactly what the
injectivity step consumes, so ruling G-3 keeps its load-bearing status — but
for this reason, not the reason §7.1 gives (A3.5).

### A3.3 RECOMPUTED, independently of the draft's script

`results/zk60_joint_law_composition_check/check_mask_dof.py` — the round map is
built from **my own derivation** of the partial sum of `g` over the boolean
tail (term by term, in the docstring), not from the code's closed form; the
closed form is then checked *against* genuine brute force so an error in it
cannot make the identity true by construction. Two fields (`2^61−1` and a
deliberately small `10007`), six `ρ` regimes, all 23 real shapes = **138
(slot, ρ) pairs per field, 276 in all**.

```
rank R_s == N d + 1            : 138/138   (both fields)
dim ker R_s == 1               : 138/138
dim C_s == N d + 1             : 138/138
sum_weights in rowspace(R_s)   : 138/138
eval_weights in rowspace(R_s)  : 138/138
my predicted kernel vector kills R : 138/138
closed form == brute force     : 318/318  (small shapes)
```

Layout arithmetic reproduces the draft's 583 / 184 / 721 / 560 / 50 / 11
exactly.

### A3.4 The `a′` discrepancy, settled — and the draft's reading sharpened

**The code comment at `sumcheck.rs:163-183` is wrong as written.** It says `a′`
is "the extra freedom that makes the total `G` AND the terminal `g(rho)`
jointly uniform given the round messages". But `G` *is* `r_0(0) + r_0(1)` of the
mask's own rounds and `g(ρ)` *is* the chain's terminal value, so both are
**determined** by the mask's round messages; no coefficient can make a
determined quantity uniform. RECOMPUTED: `sum_weights` and `eval_weights` lie
in `rowspace(R_s)` on 276/276 pairs. The draft's reading is right and the
comment should be corrected.

But the draft over-personalises `a′`. My control:

```
CONTROL drop a'  : rank − (Nd+1) in [0]        -- a' is redundant, always
CONTROL drop a_0 : rank − (Nd+1) in [-1, 0]    -- a_0 is ALSO redundant, at 5 of 6 rho regimes
```

`dim ker R_s = 1`, so *any* coordinate on which the kernel vector is non-zero
can be deleted without changing the image; `a_0` qualifies whenever some
`ρ_i ≠ 0`, and fails only in the all-zero regime where the kernel's `a_0`
component vanishes. **The content is "the kernel is one-dimensional", not
"`a′` is special."** Is `a′` needed for anything else? Not for hiding in this
construction: the `a′ = 0` sub-map is already a bijection onto `C_s`, so a mask
with `L = Nd+1` would still be a perfect one-time pad on the sumcheck channel.
Whether the CFS/Libra citation needs it for a statement this profile does not
use I **COULD NOT VERIFY**; removing it would be a protocol change and a
byte-changing re-freeze, and nothing here recommends it. Fix the comment; leave
the coefficient.

### A3.5 "Consumed 0 more" — attacked, and what survives

The brief asks whether `M`'s 256 opened columns and its proximity row are
double-counted against the coefficients' freedom. They are not, and the reason
is checkable:

* the a-row column values are `⟨E_j|coeff, a_i⟩ + ⟨E_j|pad, pad_i⟩`. The pad
  block is the Lagrange basis at the 256 pad message positions evaluated at the
  `d` distinct sampled coset points; **MY OWN ARGUMENT**: `L_t(x) = ω^t(x^m−1) /
  (m(x−ω^t))`, so the block factors as
  `diag((x_j^m−1)/m) · Cauchy(x_j; ω^{t_k}) · diag(ω^{t_k})`, of rank
  `min(d, 256)` for distinct `x_j` off the subgroup. RECOMPUTED at a
  scaled-down geometry over the real Goldilocks prime: rank
  `13/16/16` for `d = 13/16/20` against `Q = 16`
  (`check_pad_and_group.txt` (a)). So `M-cols` is not only "relied on" — it is
  provable, and the same one-line factorisation
  (`diag(x_j^n−1)·Vandermonde`) proves `H-pad` for the four PCS commitments
  (checked, (b));
* `q`'s law given `a` does **not** depend on the pads, because the weight
  vectors vanish on the pad positions (`zk.rs:476-481`) and `p_b` is uniform on
  the codimension-2 subspace. Hence `q ⊥ (a-columns) | a`, and the columns and
  `q` are each counted once. **No double count.**

What does *not* survive is the framing. The four rows of the §2.3 table
("consumed 0") live in four different spaces — `M`'s pads, the mask
coefficients, `rowspace(R_s)`, the `b`/`u` rows — and nothing in the proof of
Theorem 3.3 ever adds them up. **Row 8 of the tally is a mnemonic, not a
theorem; I demote it from PROVED HERE to ILLUSTRATION.** Its substantive
content is rows 5, 11 and 13, all of which stand.

### A3.6 §7.1's RESULT 4 does not show what it says

The draft reports that publishing only `d` values per round drops the rank and
raises `dim ker R` to 2…13, and concludes "the invariant IS load-bearing". I
reproduce the numbers (`dim ker R ∈ {2,3,4,6,7,8,10,11,13}`), but the
comparison is against `N d + 1`, which is `dim C_s` for the **`d+1`-value**
protocol. With `d` values per round the observation shrinks too, and a smaller
observation cannot leak more. My control G2 (A7) publishes only `d` values in
the distributional toy and the law **does not separate** on any witness pair.
The privacy-relevant invariant is *the mask's per-variable degree equals the
round degree* (the draft's own experiment C, which does separate 3/3), and the
`d+1` length check is load-bearing in the other direction — it stops a prover
sending **more** than `d+1` values, which the mask could not cover. CORRECTION
C-2.

---

## A4. The nonlinear link and the sampler O1

### A4.1 Is O1 well defined from public data?

Yes, with one bug. Steps 0–2 need the layout, `ρ`, the slot definitions
(functions of public challenges), the claim schedule and its grouping (from
`part_key`, public), `θ`, the 34 weight vectors and the five index lists — all
public. Step 4 needs `V`. Step 3 computes `V` — **in the wrong order** (C-1
above). With the order corrected, O1 is a public algorithm.

Step 2's use of a literal zero rectangle is legitimate and the draft's
justification is right: (H1) says the law is the same for *every* data
rectangle including the all-zero one, and the field view needs no witness
builder, no `NORM_CEPS = 1` and no producible receipt. The LogUp sum claim's
value comes out `Fp2::ZERO` by construction from the zero rectangle plus the
zero-sum `u` pair, matching the compile-time declared value
(`protocol.rs:52-62`).

### A4.2 Is it perfect? — and the step that is in neither document

Given (H1)–(H5) the sampler is perfect, because Corollary 3.4 is just the law
of Theorem 3.3 read as an algorithm. The delicate point the brief names is
real: the honest terminals are evaluations of the *real* data's multilinear
extensions masked by the reserved pairs, and the sampler's terminals come from
zeros plus pads; their laws agree only if the terminals are uniform **given
everything else published about that commitment**.

**Does the accepted lemma give that?** Its model (`GENERIC_RANK_LEMMA` §1.2(a))
*does* include "each claim value" in the functional space `F`. But its
**reduction** — `disclosed = 256·k0 + u-term` with `k0` computed from
`rowspace(ρ̃)`, whose generators are literally only the `2(G+1)` real and
imaginary parts of the group and proximity combinations (`_p1_rows`) — drops
them. The individual terminals are *not* generators, and they are not in the
span of the group combinations: a group vector gives only the `λ`-combination
`Σ_c λ_c value_c`, whereas the receipt publishes each `value_c` separately.
The reduction's correctness is one of the lemma's own RELIES ON rows and is
machine-validated only against a dense brute force on a small synthetic
instance. **So the step the sampler needs is asserted in neither document.**

**MY OWN ARGUMENT, supplying it.** Fix one opening group `g` with member
claims `c = 1..m`, shared column weights `cw ≠ 0`, and each claim's own
reserved pair contributing `P_c := msg_{r_c} + U·msg_{r_c+1} ∈ Fp2^{256}`,
uniform and independent across claims (`audit_claims` gives one pair per claim,
used by no other claim). The published objects touching those pairs are the
group vector's message half `v = D + Σ_c λ_c cm_c P_c` and the `m` terminals
`y_c = d_c + cm_c⟨P_c, cw⟩`. The verifier's own check forces
`⟨v, cw⟩ = Σ_c λ_c y_c`. Claim: the blinding map `(P_c)_c ↦ (v, y_1..y_m)` is
**onto** that consistency subspace whenever every `λ_c ≠ 0`, every `cm_c ≠ 0`
and `cw ≠ 0`. *Proof for `m = 2` (the general case is the same induction):*
given a target, choose `P_1` freely with `⟨P_1, cw⟩ = y_1/cm_1`, set
`P_2 = (v − λ_1 cm_1 P_1)/(λ_2 cm_2)`; then
`⟨P_2, cw⟩ = (⟨v,cw⟩ − λ_1 y_1)/(λ_2 cm_2) = y_2/cm_2`. ∎ So the individual
terminals add **exactly nothing** beyond the group vector and that one public
identity, and each is uniform given the rest.

RECOMPUTED (`check_pad_and_group.txt` (c)), over the real Goldilocks prime with
`U² = 7`, for groups of 1, 2 and 4 members: the blinding map's rank is
`2·ncol + 2m − 2`, i.e. all observations minus exactly one `Fp2` — the public
identity. Control `cm_0 = 0` (what `argument.rs:347-349` and
`audit_claims:103-108` refuse): the rank drops, to **0** for a singleton group,
which is the same verdict the lemma's own negative control reaches
(`k0 = 2`, 512 Fp disclosed, at a singleton group).

The proximity vector is handled the same way and the draft's treatment is
right: `ρ_prox` is non-zero on the reserved proximity pair and
`wedge(ρ_prox[p], ρ_prox[p+1]) ≠ 0` is refused otherwise
(`protocol.rs:141-151`), so `(a,b) ↦ ρ_p a + ρ_{p+1} b` is onto `Fp2^{256}`.

### A4.3 The completeness premise (Q1) — settled by reading

The draft calls this "the load-bearing one" and asks whether a symbolic check
of `poly_s(extensions) = 0` is owed for 23 closures. **I read all 23** in
`argument.rs:543-911`. The premise holds, and for exactly two reasons:

| mechanism | slots |
|---|---|
| every monomial carries an `eq` or public table as a factor, which is `0` in `exts` | SC_SS, SC_SSM, SC_TZC, SC_LZC, SC_RS, SC_QMM, SC_KMM, SC_VMM, SC_WO, SC_GMM, SC_UMM, SC_DMM, SC_DZC, SC_FZC, SC_QZC, SC_KVZC, SC_SZC, SC_TAB, SC_ZS, SC_IO_IN, SC_IO_OUT (21) |
| the two private factors are extended in **different** rounds, so one of them is `0` in each round's `exts` | SC_SCORE, SC_PV (2) |

Spot checks: SC_TZC's polynomial is `v[i_tau]·zc + ν₀·v[i_rt]·(…) +
ν₁·v[i_rt2]·(…)` and `i_tau`, `i_rt`, `i_rt2` are all `Tab::Eq`; SC_QMM…SC_DMM
are `v[0]·v[1]` with `v[1]` a `Tab::Pub` weight fold; SC_ZS is
`v[0]·v[1]` with `v[0] = Pub(vec![ONE; N])`; SC_IO_* is `v[0]·(v[1]−v[2])`
with `v[0]` the `eq(tau)` table, so the two private endpoint/A factors are
killed by it; SC_SCORE and SC_PV are `v[0]·v[1]` with `ext_round` 0 and 1
(`:649,652`, `:662,665`).

Two consequences the draft does not draw:

* the identity is **structural and witness-independent** — it is a statement
  about which table slots can be non-zero in `exts`, not about values — which
  is precisely the form Theorem 3.3 needs (it must hold for *all* `(w, π)`, not
  only on runs that verified). So the premise's "a violating term would make
  honest proofs fail, not leak" is not merely a soundness defence: it is the
  right defence here too;
* **no symbolic check and no Python port is owed.** The Python port
  `scripts/zk60_native_terminal_polys.py` is itself an unverified transcription
  (privacy case chain item 13, a standing REVIEWED OBLIGATION), so a check run
  through it would be weaker evidence than this reading. What *is* owed is a
  guard against rot: a Rust test that, for each slot, evaluates `def.poly` on a
  vector supported on that round's extended private tables and asserts zero.
  That is a cheap test and I recommend it as condition O-1 of this check.

**Fact 3.2 therefore rises from RELIES ON to VERIFIED IN THE CODE for the 23
toy-block closures**, and stays RELIES ON for every other schedule.

---

## A5. Composition across commitments — "GAP 21"

### A5.1 Every blinding family, and the commitment it enters (VERIFIED IN THE CODE)

| family | drawn where | enters |
|---|---|---|
| `A`'s 242 non-data rows (120 reserved pairs + proximity pair) | `protocol.rs:313-315`, `a_data[a_mask_base*N..] = rng.fp()` | `A` only |
| `A`'s 455×256 pads and 2048 salts | `pcs.rs:673-674` inside `commit_zk_owned(a_data, …, &mut rng)` (`protocol.rs:316`) | `A` only |
| the 23 CFS coefficient vectors, `M`'s 46×256 pads, `b_re/b_im/u_re/u_im`, `M`'s 4096 salts | `zk.rs:434, 445, 452-457, 462` inside `mask_commit(…, &mut rng)` (`protocol.rs:324`) | `M` only |
| `H`'s 104 non-data rows | `protocol.rs:361-363` | `H` only |
| `H`'s zero-sum pair `u` (2 × 255 draws, last entry the negated sum) | `protocol.rs:364-372` | `H` only |
| `H`'s 384×256 pads and salts | `commit_zk_owned(h_data, …)` (`protocol.rs:373`) | `H` only |
| each endpoint's 5 non-data rows, 7×256 pads, salts | `private_seam.rs:196, 211-217` — **its own `ZkRng::from_os`**, in a call the block never makes | that endpoint only |

I grepped `protocol.rs` for every write to `a_data` and `h_data`
(lines 282-316, 336-373): nothing is copied from one commitment's blinding into
another's, and no blinding value is read back. `commit_zk_owned_with` draws
`pads` then `salts` from the passed `rng` and nothing else (`pcs.rs:673-674`).
**No blinding variable enters two commitments. GAP 21's factual content holds
for the toy block, by reading.**

### A5.2 MY OWN ARGUMENT: the joint statement does not need the 100 × 358 matrix

Prop 4.2 routes the cross-commitment step through a joint rank. It does not
have to. Each role's published objects are a function of `(d, β_r)` with `β_r`
that role's own blinding, and the `β_r` are mutually independent (A5.1). Then

```
law(V_A, V_H, V_In, V_Out | d) = ⊗_r law(φ_r(d, β_r)) = ⊗_r P_r ,
```

so the four **per-role** witness-free statements give the joint one directly,
with no rank computation, no block-diagonality lemma, and **no need to say
anything about shared data coordinates at all**. The endpoint/`A` question the
brief raises answers itself: the two endpoint planes commit the same hidden
values as `A[10], A[11], A[68], A[69]` under independent pads, and since
`law(φ_A(d, β_A))` is data-free for *every* `d` and `β_A ⊥ β_E`, the pair
`(A`'s view, endpoint's view`)` is jointly data-free. The two IO terminals
being evaluations of the same plane at the same point is likewise harmless:
they carry independent reserved pairs, one in each commitment.

So the honest restatement of GAP 21 is: **"the four roles' blinding families
are mutually independent"** — settled by reading for the toy block, and
computational (M-3) for the three that share one BLAKE3 stream, information-
theoretic for the two endpoints. That is a weaker and more checkable
hypothesis than block diagonality of a specific 100 × 358 matrix, and it makes
row 18 ("the matrix for the joint statement *is* the joint non-data block")
an unnecessary identification.

One complication the draft should state and does not: **`V_sc` is not a
product across roles.** A single extension round mixes reserved-pair
evaluations from `A`, `H` and an endpoint in one slot (SC_DZC, SC_IO_*), so the
factorisation above covers `V_pcs` only, and Theorem 3.3's conditioning on the
whole of `π` remains necessary. That is exactly why (H1) is stated for `V_pcs`
and not for the whole view — correct, but worth saying.

### A5.3 The measurement arm of the draft's support is weaker than quoted

The draft cites the repaired stage 4 (`zk60-native-jointview` at `14b7d20`) as
"a control that shares a blinding row across two commitments and moves the
joint from 4 to 260". That control is real, but the same document records its
blind spot (`ZK60_NATIVE_JOINT_VIEW.md` §12.5): the joint rank sees a shared
blinding row **only at a tight position** — a singleton opening group's pair,
two generators against exactly two columns. `A` has 17 singleton groups out of
35 and `H` 2 out of 9; a sharing at a *slack* position changes no rank at all.
So "0 shared non-data classes on four captures" is a reading of the captures'
declared structure plus a control that can miss the general case. The draft
quotes the control without the blind spot. CORRECTION C-3.

### A5.4 Q8, the restart, and "opened twice" — a finding that goes the draft's way

The draft (§5.4) and the accepted lemma (§3.2, condition O-5) both rely on: *a
refused attempt restarts with fresh pads, salts and masks, so the accepted
transcript is uniform on the non-refused set.* **In this profile there is no
restart.**

* `private_block::prove_with_stats` calls `prove_inner` **once**
  (`private_block.rs:431-435`); there is no retry loop anywhere in the module.
* The two endpoint commitments are **not** created by the prover. They are
  caller-supplied `PreparedPlane`s made by `private_seam::prepare` with their
  own OS entropy, and **their roots are part of the public statement**
  (`ExpectedIo`, absorbed first at `protocol.rs:31`, re-checked at
  `:247-249`). A fresh endpoint has a different root and fails
  `check_endpoints`.
* `PreparedPlane` is documented and typed as **"No Clone, data getter, or
  repeated-opening method"** (`private_seam.rs:142-147`) and `Endpoints` carries
  a compile-fail doctest showing the owners are consumed
  (`private_block.rs:360-370`).

Consequences. (i) Q8's worry — a second attempt opening the same endpoint twice
— **cannot happen**: the type system forbids it, and a refused attempt emits
nothing. (ii) The "restart with fresh randomness" mechanism the draft cites is
**not what the code does**: a refusal is terminal for that `(statement,
endpoints)` pair, so the `2^-62.0` rate is a liveness cost with no retry
available at the same statement. (iii) The conclusion the mechanism was meant
to support survives and is in fact cleaner: with exactly one attempt,
"conditioning on non-refusal" is conditioning on `NR(ρ)`, a function of the
challenges, which is precisely what Theorem 3.3 does. **CORRECTION C-4: delete
the restart sentence and replace it with the single-attempt reading.** The same
correction is owed upstream to `ZK60_GENERIC_RANK_LEMMA.md` §3.2.

This also touches the draft's §6 item 3 ("many proofs"): two proofs about the
same input necessarily use **different** endpoint commitments, because the
owners are consumed, so the independence premise of that item holds for the
endpoints by construction rather than by assumption.

---

## A6. The hash layer and the lift to Fiat–Shamir

### A6.1 What is in a leaf, and what is published (VERIFIED IN THE CODE)

`leaf_j = blake3( blake3(column_j bytes) ‖ salt_j )` — `hash_column`
(`pcs.rs:137-143`, and `zk.rs:592-595` for `M`) then `salt_leaf`
(`pcs.rs:639-645`), with **one fresh 32-byte salt per encoded column**
(`pcs.rs:674`; `zk.rs:462` for `M`), i.e. 2048 salts for `A`/`H`/each endpoint
and 4096 for `M`. Only the **opened** columns' salts leave the process
(`open_zk:935-940`, `mask_open:545-548`). Sibling digests on an opened path
are roots of subtrees containing unopened leaves, so what (H6) needs is
salted-**subtree** hiding, not only salted-leaf hiding — the draft says this
(M-2) and is right.

Salt entropy is 256 bits, so a `q`-query adversary who guesses a low-entropy
column still cannot test it without the salt: `q·2^-256` per unopened leaf.
The draft's form of (H6) is the right standard statement. One qualification it
carries elsewhere but not here: the salts are `ZkRng` output, so the term is
`q·2^-256` **plus** the M-3 advantage, not `q·2^-256` alone.

### A6.2 The untagged domain — the draft's dismissal is right, its reason is incomplete

The brief asks whether a Merkle/leaf hash input can coincide with a transcript
hash input, making a challenge a function of a leaf digest. I did the length
analysis the draft does not.

| query | input length |
|---|---|
| `Transcript::squeeze_bytes` (**every challenge**) | `32 + 7 + 8 = 47` (`transcript.rs:85-94`) |
| `Transcript::absorb` | `48 + |label| + |data| ≥ 49` (`:44-52`) |
| `merkle::hash_pair`, `pcs::salt_leaf` | `64` |
| `hash_column` | `rows·8` ∈ {3640, 3072, 400, 56} for A / H / M / endpoint |

**MY OWN ARGUMENT.** 47 is occupied by nothing else: `absorb` inputs are at
least 49 bytes, node and leaf inputs are 64, and no `rows·8` equals 47 (47 is
not a multiple of 8). **So no challenge-producing query can ever coincide with
a node, leaf or absorb query**, and the sequential lift's "each challenge is
fresh uniform given the past" needs no separate argument about the shared
domain. Challenges *are* functions of leaf digests through the absorbed roots,
which is by design and is what the sequential-kernel lemma allows.

The one genuine overlap is the single 64-byte absorb. Enumerating the labels on
this path, only `absorb_u64(b"log-cols", 8)` gives `32+8+8+8+8 = 64`
(`protocol.rs:43`); `b"rows"` gives 60 and `b"pb-slot"` 63. Its last 32 bytes
are the **fixed constant** `le64(8) ‖ "log-cols" ‖ le64(8) ‖ le64(8)`. It
therefore collides with `hash_pair(a,b)` only if `b` equals that constant and
with `salt_leaf(d,s)` only if the salt does — `2^-256` per node or salt,
`≈ 2^-243` over one proof's objects. That belongs **inside** (H6)'s
"(collision terms)" and the draft does not put it there. CORRECTION C-5.

The draft's stated reason ("an extra query on an input the adversary already
knows, which does not help it guess a salt") is true but answers only the
salt-guessing direction. With the length argument and the fixed-suffix term
the dismissal stands. Its observation that an 8-row commitment's `hash_column`
would itself be a 64-byte input is correct and worth keeping: the endpoints are
**7** rows, one row away.

### A6.3 Bad events the lift must exclude, written out

The draft's §5.1/§5.2 composition is prose. For the record, the events are:
(i) two distinct `squeeze` inputs colliding (the challenge chain repeating) —
`2^-256` per pair, and impossible to reach from any other table by A6.2;
(ii) two distinct `absorb` inputs colliding — the transcript's binding;
(iii) a `hash_pair`/`salt_leaf` input coinciding with a 64-byte `absorb` input
— A6.2, `≈2^-243`; (iv) the prover's own oracle queries colliding with the
transcript's — subsumed by (i)–(iii). None of these is enumerated in the
draft, and Q5 (does the checker want the lift as a per-step kernel argument
with the message at step `j` the pair (field part, hash part)?) — **yes**, and
it is still owed.

---

## A7. The toy enumeration, re-run, plus my own controls

### A7.1 The draft's script, re-run

`python3 results/zk60_joint_law_composition/toy_joint_law.py` reproduces the
recorded output **byte for byte**
(`check_toy_controls/../rerun_draft_toy_joint_law.txt`, `diff` clean). I read
the script. It is honest about being an illustration and the arithmetic is
sound; the sanity counters (verifier chain, `derived g_val == true g(ρ,e)`)
fire zero failures on 3 × 78,125 runs.

### A7.2 Does it test the protocol's structure, or a simplification?

Mixed, and the draft does not distinguish.

* **B** (the `c = 0` refusal dropped) and **E** (a Private slot's `Γ` batched
  into `M`) are real rules of the real protocol (`argument.rs:275`, `:374`) and
  the controls are faithful.
* **F** (two slots sharing one mask) is a real rule (`mask_commit` draws one
  mask per spec) and fires.
* **C** (the mask's degree lowered) is a *distributional analogue*: the real
  protocol fixes the mask's degree to the slot's degree by construction
  (`mask_specs()`), so nothing in the code could lower it. It illustrates why
  `Im R ⊇ C` matters; it is not a rule that could be broken by an edit.
* **D** (the terminal's blinding published twice through `M`) is synthetic: no
  functional in `N_FUNCTIONALS` has that shape. It is the counterexample
  *shape*, which is its purpose.
* **The gap that matters**: experiment A's view contains **no `M` object at
  all**, and F runs only the broken variant with the θ-batched value, never the
  honest one. So the enumeration never exercises the composition it is offered
  as evidence for. I supply that below.

### A7.3 My controls — predictions recorded before running

`results/zk60_joint_law_composition_check/check_toy_controls.py`, model
re-coded from the Rust rather than imported.

| control | prediction | result |
|---|---|---|
| **G1** the view **plus** the derived `g_val` (i.e. `M` disclosing exactly `V`) — the honest form of Lemma 3.1 + Fact 3.2 at one slot | SAME | **SAME, 0 of 3 pairs separate** |
| **G7** honest **two slots**, independent masks and pairs, plus the θ-batched `V` | SAME | **SAME** (marginals and joint; support 531,441) |
| **G4** two slots whose terminals share **ONE reserved pair** (what `audit_claims:118-131` forbids), plus `V` | marginals SAME, joint DIFFERENT | **marginals SAME, JOINT DIFFERENT** |
| **G5** the same without `V` | joint still DIFFERENT (the sharing, not the batching, is the fault) | **JOINT DIFFERENT** |
| **G2** only `d` values per round published | SAME (strictly less is published) | **SAME** — this is the control that refutes §7.1 RESULT 4's reading |
| **G3** `d + 2` values per round | SAME (the extra value is determined) | **SAME** |
| **G6** a hosted slot **before** its host: two slots hosting each other with `κ₀κ₁ ≠ 1` | SAME (any invertible claimed-sum change of coordinates preserves "uniform on `C`") | **SAME** |
| **G6′** the same with `κ₀κ₁ = 1` | the coordinate change is singular | **no honest prover exists**: `M(Γ₀,Γ₁) = (A₀,A₁)` is unsolvable for a generic witness |

**G4/G5 are the check's most useful new result.** They exhibit the
`(H(mask), mask ⊕ w)` shape on the *commitment* side — two terminals sharing
one reserved pair, each marginal untouched, the joint separating. The draft's
§5.3 table row 3 asserts that the lemma's §3.2 disposes of this case but never
shows what it would cost; now there is an exact enumeration that does. It also
matches, in a second and independent way, the lemma's own finding that "two
claims share one reserved pair" gives `k0 = 16`.

**G6 corrects a rhetorical overstatement.** The draft says "Lemma 2.2 is
exactly where that rule [hosts after hosted] earns its keep". What the rule
buys is that the claimed-sum map is *implementable* and *invertible*;
invertibility alone preserves the conclusion, and the failure mode of a cycle
is a prover that cannot produce a consistent transcript at all — a completeness
failure, not a leak. CORRECTION C-6.

---

## A8. (H5), the randomness, and the `fp()` bias

(H5) as stated — `α`, `π`, `μ` mutually independent and `α` uniform — is
**false** for `A`, `M`, `H`, which are consecutive disjoint segments of one
BLAKE3 XOF stream (`protocol.rs:275` then `:313, 316, 324, 361, 373`). It is
*true information-theoretically* for the two endpoints, which have their own
`ZkRng::from_os` (`private_seam.rs:196`) — the draft does not make that
distinction and could. What is really assumed is:

* **M-3**, whole-stream two-sided indistinguishability of `ZkRng` from uniform
  (two-sided because `A`'s 256 salts are published before `H`'s pads are drawn
  from the same stream — ruling C-3);
* **D9**, the `fp()` reduction bias, `2^-96` per draw. RECOMPUTED: the draft's
  blinding table sums to exactly **327,052** `fp()` draws
  (61,952 + 116,480 + 26,624 + 510 + 98,304 + 1,166 + 11,776 + 4,096 + 6,144),
  and `327052 · 2^-96 = 2^-77.68`, so "≤ 2^-77.7" is right. The salts are
  `bytes32()` draws and carry no reduction bias — correctly excluded.

**Consequence the draft does not carry into its statements.** Theorem 3.3 is
stated as an exact equality of laws and §3.4 calls the sampler "perfect, not
close to". Both are correct **only in the uniform-blinding idealisation**. With
the real generator the honest statement is: the two laws are within `2^-77.7`
in statistical distance (D9) and otherwise indistinguishable under M-3. §3.4's
prose does say "in the uniform-blinding idealisation"; §0's "What is shown" and
the theorem's own statement do not, and the theorem is the sentence that will
be quoted. CORRECTION C-7. (The register's D9 entry prices "about 2^-75 at the
tiny shape"; the draft's 2^-77.7 is a tighter count for this profile's draw
total, and it should say so rather than appear to contradict the ruling.)

The reduction the draft's Q6 asks about — an adversary distinguishing the two
worlds yields a `ZkRng` distinguisher — is the standard hybrid and I do not
think it needs writing out; what does need writing is the one sentence above.

---

## A9. Corrected label tally

Rules: never strengthen without a proof written here; a row standing on a row
labelled RELIES ON, ASSUMED or GAP is marked *mixed*. Rows 1–32 are the draft's
numbering; 33–35 are new.

| # | statement | draft | mine | why |
|---|---|---|---|---|
| 1 | the inventory of published field messages | RELIES ON | **VERIFIED IN THE CODE** (promotion) — with C-1 | re-read end to end; complete; the θ-order is wrong |
| 2 | the linear/nonlinear split | PROVED HERE | PROVED HERE | — |
| 3 | blinding uniform and independent | RELIES ON | RELIES ON (M-3, D9); *information-theoretic for the two endpoints* | A8 |
| 4 | `dim C_s = N_s d_s + 1` | PROVED HERE | PROVED HERE (unconditional) | reproduced |
| 5 | Fact 2.1, `rank R_s = dim C_s`, `dim ker = 1` for every `ρ` | RELIES ON | **PROVED (unconditional)** (promotion) | A3.2, five lines; recomputed 276/276 |
| 6 | the claimed-sum change of coordinates is invertible | PROVED HERE | PROVED HERE, on the order rule; *triangularity is sufficient, invertibility is what is needed* | A7 G6 |
| 7 | Lemma 2.2 | PROVED HERE on 3, 5, 6 | PROVED HERE on 3, 5, 6 — now standing on a **proved** row 5 | — |
| 8 | the DOF accounting table | PROVED HERE | **ILLUSTRATION** (demotion) | A3.5: four different spaces, never summed in any proof |
| 9 | `M`'s geometry | RELIES ON | **VERIFIED IN THE CODE** (promotion) | `zk.rs:373-375, 431-447`; the load-bearing runtime assert is `zk.rs:442`, **not** `layout.rs:735`, which is inside `mod tests` (C-14) |
| 10 | shared points never share a pair | RELIES ON + PROVED HERE | same | G4/G5 exhibit the cost of breaking it |
| 11 | Lemma 3.1 | PROVED HERE on RELIES ON | PROVED HERE on **M-3 only** (partial promotion) | `M-cols` proved in A3.5; `mask_verify` re-read in A2.2 |
| 12 | Fact 3.2 / the completeness premise | RELIES ON — "see Q1" | **VERIFIED IN THE CODE** for the 23 toy-block closures (promotion); RELIES ON elsewhere | A4.3 |
| 13 | `V` factors through `R` | PROVED HERE on §3.5(b) | **PROVED** (promotion) | same argument as A3.2; recomputed 276/276 |
| 14 | **Theorem 3.3** | PROVED HERE on (H1)…(H5) | PROVED HERE on (H1)…(H5), **in the uniform-blinding idealisation** | proof re-checked, A1.2; C-7 |
| 15 | Corollary 3.4 / O1 perfect | PROVED HERE | PROVED HERE on row 14; **the printed algorithm is wrong** (C-1) | A4.1 |
| 16 | item 20 discharged at the field layer | PROVED HERE | mixed — conditional on the whole stack; field layer only | — |
| 17 | Lemma 4.1 | PROVED HERE | PROVED HERE (unconditional) | re-derived |
| 18 | the 100 × 358 joint non-data block is *the* matrix | PROVED HERE | **ILLUSTRATION / unnecessary** (demotion) | A5.2: the joint statement follows from independence, not from that rank |
| 19 | across slots inside one commitment | RELIES ON | RELIES ON **plus a step the lemma does not contain**, supplied in A4.2 | the 173 individual terminals are not among the lemma's generators |
| 20 | Prop 4.2 | PROVED HERE given 21 | PROVED HERE given 21, **superseded** by A5.2 | — |
| 21 | block diagonality | **GAP** | **RESTATED** as cross-role blinding independence: **VERIFIED IN THE CODE** for the toy block + M-3 (promotion); still not machine-asserted | A5.1–A5.2 |
| 22 | pad-half determinacy precision (Q7) | GAP (a precision) | **RESOLVED as to Q7's own worry → CORRECTION of the prose** (promotion) | the `256−d` undetermined coordinates of each pad half are supported on pad coordinates only, so they carry no data coordinate and cannot by themselves put a functional into `F ∩ T`. The correctness of the reduction `disclosed = 256 k0 + u-term` as a whole is unchanged and stays the **lemma's** RELIES ON row, not this memo's |
| 23 | (H1) | PROVED HERE conditional | mixed — on 17, 19 (+A4.2), 20/21 as restated, and two toy layouts | — |
| 24 | (H6) | ASSUMED + PROVED HERE inside the model | same, with the collision term of A6.2 added | C-5 |
| 25 | the untagged domain does not affect (H6) | PROVED HERE | **mixed** (demotion): the draft's reason covers one direction only; it stands with A6.2's length argument and a `≈2^-243` term | C-5 |
| 26 | the counterexample table | per-row | same; row 4's reason replaced by A5.2, row 2's completed by row 22 | — |
| 27 | conditioning on non-refusal | RELIES ON + ASSUMED | same label, **but the restart mechanism cited does not exist** | C-4 |
| 28 | Corollary 5.1 | PROVED-CONDITIONAL | PROVED-CONDITIONAL | — |
| 29 | many proofs at the field layer | PROVED HERE conditional | PROVED HERE conditional — and the endpoint premise is now *structural* (owners consumed, no Clone) | A5.4 |
| 30 | the 125M profile and the rung | GAP | GAP | — |
| 31 | the hash layer beyond (H6); D8/D11; ROM composition | GAP | GAP | — |
| 32 | the toy enumerations | ILLUSTRATION | ILLUSTRATION — **and experiment A contains no `M` object**, so it does not illustrate the composition | A7.2; G1/G7 supply it |
| 33 | *(new)* the individual terminals add nothing beyond the group vector and one public identity | — | **PROVED (mine)**, on `λ ≠ 0`, `cm ≠ 0`, `cw ≠ 0` | A4.2 |
| 34 | *(new)* no restart exists; endpoints cannot be opened twice | — | **VERIFIED IN THE CODE** | A5.4 |
| 35 | *(new)* no challenge query can coincide with a node, leaf or absorb query | — | **PROVED (mine)**, by input length | A6.2 |

**Corrected tally, 35 rows.**

| label | count | rows |
|---|---:|---|
| PROVED / PROVED HERE (unconditional) | 6 | 4, 5, 13, 17, 33, 35 |
| VERIFIED IN THE CODE | 5 | 1, 9, 12, 21 (restated), 34 |
| PROVED HERE on named RELIES ON / ASSUMED rows | 6 | 2, 6, 7, 11, 14, 15 |
| mixed | 6 | 16, 19, 23, 24, 25, 26 |
| RELIES ON (primary) | 4 | 3, 10, 27, 28 |
| GAP | 2 | 30, 31 |
| ILLUSTRATION / superseded | 6 | 8, 18, 20, 22, 29, 32 |

**Demotions, with reasons:** row 8 (the DOF table is a mnemonic, not a
theorem); row 18 (the joint matrix is not the matrix the joint statement
needs); row 25 (the untagged-domain argument as written covers one direction
and omits a collision term); row 32 is re-labelled with the observation that
its central experiment omits `M`. **Promotions, with proofs written above:**
rows 1, 5, 9, 12, 13, 21, 22, and the three new rows.

**Net movement: the argument came out of this check stronger, not weaker.**
Two of the draft's four gaps close (21 restated and settled by reading, 22
resolved), its own most-doubtful open question (Q1) closes by reading, and the
one conditional fact the whole sumcheck channel rests on (Fact 2.1) turns out
to be a five-line theorem. The remaining gaps are the two that were always
outside: other shapes (30) and the hash layer beyond (H6) (31).

---

## A10. Scope, and the plain-words summary

**Does anything say or imply that privacy is established?** No. I searched for
it. §0 ends with "Nothing here establishes a privacy property"; §5.4's
Corollary 5.1 says "This is not a privacy acceptance and must not be quoted as
one"; §9 repeats it; and §9 proposes the quoting rule that no sentence may
state Theorem 3.3 without naming GAP 21 and the two toy layouts. That
discipline is right and should be kept (with GAP 21 restated per row 21).

**Three places where §0 claims more than the body supports:**

* "provided five named inputs hold, **four of them already accepted
  elsewhere**". Only (H2) and (H5) are accepted elsewhere. (H1) is the memo's
  own §4 standing on what it itself calls a gap; (H3) is proved in the memo;
  (H4) rests on a premise the memo flags as its own most doubtful question.
  CORRECTION C-8.
* "The earlier drafts called that object **O1** and said it did not exist. It
  does; §3.4 is it." O1 exists **conditionally on (H1)–(H5)** and only for the
  **field view**; §3.5 says so, §0 does not. CORRECTION C-8 (same).
* "(i) The generic-rank lemma, **accepted** 2026-09-20 for the two toy
  layouts". The disposition's verdict is "the lemma's **core** is accepted …
  **the draft is NOT accepted as written**" and sends it back for an errata
  pass (which landed as `ef7c5a7`). Quote the core, not the draft.
  CORRECTION C-9.

Everything else in §0 and §6 is accurate, and §6's list of what is not covered
is honest and complete as far as I can check it.

---

## Verdict

**The theorem survives, in this exact form: at a fixed non-refused challenge
vector, in the idealisation where the prover's blinding is uniform and
independent, the joint law of every field value a toy private-block receipt
publishes is the same for every admissible hidden input — conditional on
(H1), which is the four PCS commitments' own per-role witness-freeness from the
accepted generic-rank lemma plus the fact that the four roles' blinding
families are mutually independent.** I could not break the proof: no hypothesis
restates the conclusion, the fibre argument is valid, and the one source
reading everything turns on — what `mask_verify` publishes — is complete. Two
of the draft's own open questions close in its favour under my reading rather
than staying open: the completeness premise `poly(extensions) = 0` holds for
all 23 slot closures for structural reasons I set out slot by slot, and
"block diagonality" is not the hypothesis that is needed — cross-role blinding
independence is, and that is a source reading I checked family by family and
found clean. One conditional fact the whole sumcheck channel rests on (Fact
2.1, "the mask covers the consistency subspace exactly") turns out to be
provable outright in five lines, for every challenge, rather than relied on and
sampled. Against that, the printed sampler O1 computes its θ-batch in the wrong
order and is wrong as an algorithm (the theorem is not); the step that makes
the 173 individual terminals safe is in neither this memo nor the accepted
lemma and I had to supply it; the restart mechanism §5.4 leans on does not
exist in this profile (which is good news, but the sentence is false); and
"perfect" must become "perfect in the uniform-blinding idealisation, within
2^-77.7 and the PRG advantage against the real prover" wherever the theorem is
quoted. **The shortest honest list of remaining work: fix the θ-order and the
four false or overstated sentences; add the two small Rust guards (a per-slot
`poly(exts) = 0` assertion and a cross-role blinding-disjointness assertion) so
neither reading can rot; write the lift as a per-step kernel argument over the
pair (field message, hash object); and then the field layer of the toy block is
done and only the hash layer and the other shapes remain.** Nothing here is a
privacy acceptance.

---

## ERRATA AND CONDITIONS FOR ACCEPTANCE

### BLOCKING (the memo should not be accepted until these are fixed)

| # | item | where | what to do |
|---|---|---|---|
| **B-1** | **The sampler O1 computes the wrong θ-batch.** The declared functional order is *interleaved* per slot (a Standalone's `Γ` immediately before that slot's `eval`), with the six host `Γ`s appended last — `argument.rs:361-376`, `:924-925`. The memo's step 3 concatenates three blocks instead | §3.4 step 3 | rewrite step 3 in the declared order; state that the order is part of the public data O1 needs |
| **B-2** | **A step the argument needs is in neither document.** The 173 individual terminals are published, are in the accepted lemma's functional space `F`, and are **not** among the generators of its reduction (`_p1_rows` = the `2(G+1)` group and proximity combinations only). Without them the sampler's step 2 is not justified | §4.2, §4.3 (H1) | import the per-group surjection of this check's A4.2 (or an equivalent), with its three non-vanishing conditions `λ_c ≠ 0`, `cm_c ≠ 0`, `cw ≠ 0`, and cite the refusals that give them. Say explicitly that the lemma's reduction is the thing being leaned on and that its correctness is one of the lemma's own RELIES ON rows |
| **B-3** | **"Perfect" is stated without its idealisation** in the two places that will be quoted | Theorem 3.3's statement; §0 "What is shown" | add "in the uniform-blinding idealisation"; state the real-prover form once: within `2^-77.7` (D9) and the M-3 advantage |
| **B-4** | **The restart the conditioning rests on does not exist.** `prove` is called once, `Endpoints` is consumed, `PreparedPlane` has no `Clone`, and the endpoint roots are in the public statement, so a refusal is terminal for that `(statement, endpoints)` pair | §5.4 bullet 1; §8 Q8 | replace with the single-attempt reading (which is stronger); record that "opened twice" is prevented by the type system; send the same correction to `ZK60_GENERIC_RANK_LEMMA.md` §3.2 (condition O-5) |

### CORRECTIONS

| # | item | where |
|---|---|---|
| C-1 | the functional order (same as B-1, as a fact about §1.3/§3.1 as well) | §1.3, §3.1 |
| C-2 | §7.1 RESULT 4's "d values per round" control does not show the invariant is load-bearing: publishing less cannot leak more, and my control G2 does not separate. The privacy-relevant invariant is *mask degree = round degree* (experiment C); the length check is load-bearing against **more** than `d+1` values | §2.3, §7.1 |
| C-3 | the joint-view gate's shared-blinding control has a recorded blind spot — it fires only at tight (singleton-group) positions (`ZK60_NATIVE_JOINT_VIEW.md` §12.5). Quote the control with the blind spot | §4.2 |
| C-4 | see B-4 | §5.4 |
| C-5 | (H6)'s collision terms must include the one real domain overlap: `absorb_u64(b"log-cols", …)` is the protocol's only 64-byte absorb and its last 32 bytes are a fixed constant, so it meets `hash_pair`/`salt_leaf` with probability `2^-256` per node or salt (`≈2^-243` per proof). Add the length argument (challenges are 47-byte queries; nothing else is) as the reason the dismissal works | §5.2 |
| C-6 | "Lemma 2.2 is exactly where that rule earns its keep" overstates: invertibility, not triangularity, is what the proof uses; a cycle's failure mode is a prover that cannot produce a consistent transcript (control G6) | §2.4 |
| C-7 | see B-3 | §3.3, §3.4 |
| C-8 | §0: "four of them already accepted elsewhere" (only two are), and "O1 … It does" (conditionally, and for the field view only) | §0 |
| C-9 | §0: the generic-rank lemma's **core** was accepted; the draft was explicitly not accepted as written | §0 |
| C-10 | the code comment `sumcheck.rs:163-183` is wrong as written (`G` and `g(ρ)` are determined by the mask's round messages). The memo should say so plainly rather than "the comment should be corrected or this drafter's reading refuted" — and should say that `dim ker R = 1`, not that `a′` is special: `a_0` is equally droppable at 5 of 6 `ρ` regimes | §2.3, Q4 |
| C-11 | the two endpoints' blinding is independent of the block stream **information-theoretically** (separate `ZkRng::from_os`), not only under M-3; §1.2 and Q6 lump all five together | §1.2, §8 Q6 |
| C-12 | say that `V_sc` is *not* a product across roles (one extension round mixes `A`'s and `H`'s reserved pairs), which is why (H1) is stated for `V_pcs` only and the conditioning on the whole of `π` is necessary | §3.3 |
| C-13 | the toy enumeration's experiment A contains no `M` object and F never runs the honest two-slot case, so §7.2 does not illustrate the composition. Cite this check's G1 and G7 (both SAME), or add them | §7.2 |
| C-14 | `layout.rs:735` (`n·d + 2 + 256 <= 512` for every slot) is inside `mod tests` (from `:695`) and is therefore **test-only**. The load-bearing runtime assert is `zk.rs:442`. §2.3 cites the test as if it were an invariant of the shipped path | §2.3 |

### OMITTED CONDITIONS (to carry into any acceptance)

| # | condition |
|---|---|
| O-1 | **A Rust guard for the completeness premise.** Per slot, evaluate `def.poly` on a vector supported on that extension round's private tables and assert zero. Cheap, test-only, and it stops the reading of A4.3 from rotting at the next schedule edit |
| O-2 | **A Rust guard for cross-role blinding disjointness.** The property that no blinding value enters two commitments is a whole-program fact with nothing asserting it. An assertion (or a stream-segment accounting test) is the closure the memo already asks for under GAP 21, restated |
| O-3 | **Fact 2.1 should be re-stated as a proved identity** (A3.2) in both this memo and `ZK60_GENERIC_RANK_LEMMA.md` §3.5(a), so that neither carries it as a sampled rank |
| O-4 | **The lift as a per-step kernel argument** over messages that are pairs (field part, hash part) — the memo's own Q5, still owed, and now with A6.3's bad-event list to discharge |
| O-5 | **Scope, unchanged**: the two toy layouts only; the 125M profile and the development rung owe the whole argument again (ruling G-2) |
| O-6 | **The quoting rule**, amended: no sentence may state Theorem 3.3 or Corollary 3.4 without naming the uniform-blinding idealisation, the cross-role independence hypothesis (formerly GAP 21) and the two toy layouts |
| O-7 | **`ZK60_GENERIC_RANK_LEMMA.md` inherits two of these**: the restart correction (B-4) and the terminals step (B-2). Both are the lemma's, not this memo's, and should be routed there |

*(check complete)*
