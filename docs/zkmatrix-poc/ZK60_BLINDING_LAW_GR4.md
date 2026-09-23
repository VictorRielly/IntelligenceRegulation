# Gap G-R4, the LAW of the blinding — draft

> **DRAFT, UNCHECKED.** Written by a delegated Opus agent for the security
> owner on 2026-09-23 (`date` read at 15:53, 16:03 and 16:09 PDT on the WSL
> box). Nobody has reviewed it. **This is not a privacy acceptance of
> anything.** Register entry D22 (the toy block) is untouched, and no run,
> development rung or 125M block may be called private because of this page.

**Sources read.** Lane `zk60-private-block-125m` at **`2ea7221`** (worktree
`/home/victor/wt-zk60-block125m`, read-only; every citation into
`hashline/` and the lane's `zkp-core/` is at that commit). Main-tree
`zkp-core` at `980edc7`: the production part of `rng.rs` (lines 1–100) and
`field.rs:10, 36-38` are byte-identical to the lane's (the diff is empty). The
main tree's `pcs.rs` is older — it has no tagged commit — so pad and salt draw
sites are cited in the lane's `zkp-core/src/pcs.rs`. The untagged twin in the
main tree draws in the same order (`pcs.rs:673-674` there).

**Evidence.** `results/zk60_blinding_law_gr4/`:
* `law_and_residual.py` is exact rational arithmetic: the per-draw distance,
  every draw count re-derived and compared with the lane's measured parts,
  the residuals, and six exact small models.
* `draw_discipline_scan.py` reads the source through `git show 2ea7221:…`.
  It covers the order of draws and the headers that enclose each one, the
  refusal exits after the first draw, the generator's API, and a Python
  port of the lane's assertion-6 scan with three mutations.

Both scripts end with `ALL ASSERTIONS PASSED`, and their outputs are saved
beside them as `.out`.

**Labels.** Each claim carries one of these:

| Label | Meaning |
|---|---|
| **ARGUED** | Shown by reading code or by a proof on this page |
| **MEASURED** | Read off a real run by the lane's observers |
| **COUNTED** | Arithmetic from the code's constants |
| **OPEN** | Owed |
| **ASSUMED** | A named assumption |

---

## 0. In plain words

Every privacy theorem the project has for the toy block and for a run says
"in the uniform-blinding idealisation". That phrase means: pretend every
random number the prover uses to hide things is perfectly random and
independent of everything else. Gap G-R4 asks whether the real prover's
random numbers deserve that pretence, and what exactly "perfectly random" has
to mean for the theorems to go through.

The answer has three parts:

* **What the theorems need.** Every hiding value of every commitment of one
  proof or one run, together with every salt, must be uniform on a set the
  code declares and independent of the hidden input and of the challenges.
  That set is a product: free field elements, plus two named linear
  relations. The law stays the same after conditioning on anything that
  depends only on the input and the challenges, which includes every
  refusal. §1 gives the exact statement.
* **Why the real prover is close to that.** Three things together get it
  there. The first is the named generator assumption (M-3, and E-1 between
  generators). The second is that the code draws in a fixed order and a
  fixed amount, set by the shape alone. It never uses a drawn value twice,
  never picks among drawn values, and never lets a drawn value decide a
  refusal. The third is the sampler's rounding bias, which comes to
  **2^-77.68** per toy proof, **2^-72.86** per 125M proof and **2^-69.29**
  per twelve-block 125M run (§4).
* **What is still owed.** Three items stand out:
  * **Machine coverage is narrower than the ledger's wording says.** The
    lane's value-level test sees only pads, salts, `b` and `u`. It cannot see
    the reserved mask pairs, the proximity rows or the CFS coefficients,
    which are exactly the values the linear-channel arguments depend on
    (§5.7). A one-line mutation that copies a reserved-pair value from `A`
    into `H` moves no draw count, and a Python port of the scan does not flag
    it. Confirming that on the Rust test is the first thing a checker should
    do.
  * **Cross-proof independence is not named.** E-1 as worded covers the
    three entropy reads within one proof. Every "per million proofs" figure
    also needs it across proofs (§5.4).
  * **The run's hidden input must be fixed before the run's stream is
    drawn.** This is still an operating condition, not a code fact (§5.9).

One observation matters for how the gap is closed. **A public order of draws
is sufficient but is not what makes the law exact.** Two properties are:
each drawn value is used once, and no control flow reads a drawn value. The
exact small models in §2.3 show both directions. Counting draws, which is all
the stage 36/46 observers do, therefore cannot close G-R4 by itself.

---

## 1. The statement: what "the law of the blinding" must be

### 1.1 Where the composition theorems use it

| Theorem | Hypothesis that carries the blinding | What it needs of the blinding |
|---|---|---|
| Toy, Theorem 3.3 (`ZK60_JOINT_LAW_COMPOSITION.md` §3.3) | **(H5)**: `α`, `π`, `μ` mutually independent, `α` uniform | `α` = the 23 CFS coefficient vectors (B6); `π` = the PCS blinding of `A`, `H`, `In`, `Out` (B1–B5, B9); `μ` = `M`'s pads, `b`, `u` (B7, B8) |
| Toy (H1), through Proposition 4.2′ (§4.2) and the generic-rank lemma | independent per-role blinding (condition **O-2**) | each commitment's reserved pairs, proximity rows and pads uniform. The zero-sum pair (B4) is uniform on its hyperplane |
| Toy (H3), Lemma 3.1 | `μ`'s law | `b` uniform subject to the zero sum over `G_512`, and `u` and the pads uniform |
| Run, Theorem B (`ZK60_JOINT_LAW_COMPOSITION_RUN.md` §3.7) | **(H5^run)**: the `L` families `α_k`, the whole of `π` (all `4L+1` roles) and the `L` families `μ_k` mutually independent, each `α_k` uniform | the same, per stage |
| Run, Proposition R.1 (run memo §3.4, line 828) | **hypothesis (ii)**: the per-role blindings `β_r` mutually independent, `4L+1` roles | cross-role independence. This is the item called G-R4 |
| Joint sentence (JS), clause (a) (`ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES.md` §2.0) | the salt segments independent of every blinding segment | the salts are uniform and independent of the field blinding |

Every one of these rows is a **marginal or a factorisation** of a single
statement: the whole blinding vector has the uniform product law on its
declared support, independently of the input and the challenges. The rest of
this page states that one law and argues it, rather than the six weaker
statements separately.

### 1.2 The random variables

Let `Ω` be the tuple of every value the prover draws for hiding in one
attempt: one standalone block, or one run. Per commitment, from the code at
`2ea7221`:

| Commitment | Family | Where drawn | Count (`fp()` draws unless noted) |
|---|---|---|---|
| `A` (per block or stage) | reserved pairs and the proximity pair, rows `a_mask_base..a_rows` | `protocol.rs:1002-1004` | `(a_rows − a_data_rows)·n` |
| | pads, 256 per row, every row | `zkp-core/src/pcs.rs:777` | `a_rows·Q` |
| | salts | `pcs.rs:778` | `nn`, as `bytes32` |
| `M` (per block or stage) | CFS coefficients `α_s ∈ Fp2^{L_s}` | `zk.rs:485` → `sumcheck.rs:201-203` | `2·Σ_s L_s` |
| | per-a-row pads | `zk.rs:496` | `46·256` |
| | `b_re, b_im, u_re, u_im` | `zk.rs:503-508` | `4·1024` |
| | salts | `zk.rs:513` | `4096`, as `bytes32` |
| `H` (per block or stage) | reserved pairs and the proximity pair | `protocol.rs:1115-1117` | `(h_rows − h_data_rows)·n` |
| | zero-sum pair `U` (two rows of `H`'s data region, `layout.rs:1281-1284`) | `protocol.rs:1118-1126` | `2(n − 1)`; the last entry of each row is computed, not drawn |
| | pads and salts | `pcs.rs:777-778` | `h_rows·Q`; `nn` |
| endpoint (`In`, `Out`; own generator) | 5 mask rows (the pair, the proximity pair, one spare) | `endpoint_g.rs:276-278` (toy: `private_seam.rs:211-213`) | `5·n_e` |
| | pads and salts | `endpoint_g.rs:280` → `pcs.rs:777-778` | `rows_e·Q`; `nn_e` |
| boundary `B_k` (run stream) | 6 mask rows (two pairs and the proximity pair) | `boundary.rs:346-348` | `6·n_e` |
| | pads and salts | `boundary.rs:350` → `pcs.rs:777-778` | `(rows_e + 1)·Q`; `nn_e` |

The counts are **COUNTED** and match the lane's measured parts exactly at
four shapes (§4, `law_and_residual.py` §2). The families are those of the
toy memo's §1.2 table (B1–B10) and of claim A-4 of the joint-sentence page,
now read at `2ea7221`.

### 1.3 The declared support

`S_decl(shape, L)` is the product, over every commitment and family above,
of:

* `Fp` for every drawn coordinate that no relation touches;
* `{x ∈ Fp^n : Σ_j x_j = 0}` for each of `H`'s two zero-sum rows;
* `{x ∈ Fp^1024 : x_512 = −x_0}` for each of `M`'s `b_re` and `b_im`. The
  zero sum of `p_b` over `G_512` is `512(b_0 + b_512) = 0`;
* `{0,1}^256` for every salt.

Nothing else. This is the declared relation set of J-5's assertion 6, and it
is ARGUED complete in §3.4. `S_decl` depends on the **shape and `L`
only**, not on the weights or any statement digest.

The two overwritten words `b_re[512]` and `b_im[512]` (`zk.rs:505-506`) are
drawn and then discarded. They are not coordinates of `Ω`, they enter no
published value, and they are counted in `N` below, which is conservative.

### 1.4 The experiment the law lives in

The composition theorems are all stated in the **fixed-challenge
experiment**. The public statement `P`, the hidden input `w` and the challenge
vector `ρ` are fixed or drawn exogenously, and the prover then runs. For a
run, `w` is an admissible run input: the joint condition on all `L` stages
(ruling R-1.1). `w` is **fixed before the prover's generators are created**.
For a run this is ruling R-2's condition 2, an operating condition (§5.9).
The passage from this experiment to the hashed Fiat–Shamir protocol belongs
to G-R5 (Lemma H^run, Route A) and to the joint sentence's two hops. It is
not re-argued here (§5.10).

### 1.5 The statement

> **LB (the law of the blinding, idealised).** In the fixed-challenge
> experiment, for every profile, `L`, public statement `P`, admissible
> hidden input `w` and challenge vector `ρ`:
>
> **(LB-1)** `law(Ω | P, w, ρ) = Uniform(S_decl(shape, L))`. Equivalently:
> every free coordinate, zero-sum row, `b` row and salt is uniform on its
> factor, all of them are mutually independent, and the whole of `Ω` is
> independent of `(P, w, ρ)`.
>
> **(LB-2)** For every event `E` that is a function of `(P, w, ρ)` alone and
> has positive probability, `law(Ω | P, w, ρ, E) = Uniform(S_decl)`. Such
> events include `NR(ρ)` (no challenge-driven refusal), the absence of a
> zero LogUp denominator, the admissibility of `w`, and for a run the
> acceptance of all `L` stages.
>
> **Not conditioned on the published view or the transcript.** `law(Ω)` is
> the input of the composition theorems. The law of the view is their output.
> Conditioning `Ω` on the view is what a simulator does, and it is no part
> of this hypothesis.

**Every hypothesis in §1.1 follows from LB.** Uniform on a product set is the
product of the uniforms on the factors. The factors split along commitments,
because no relation in §1.3 crosses two commitments, and along families
within a commitment. That gives:

* `α ⟂ π ⟂ μ` with `α` uniform, which is (H5) and (H5^run);
* the per-role blindings mutually independent, which is Proposition R.1 (ii)
  and O-2;
* the salts independent of the field blinding, which is JS clause (a).

[ARGUED — immediate.]

> **LB-real (the real prover).** Take the same `(P, w, ρ, E)`, one
> generator per role as built (§5.4), and any distinguisher `D` given `Ω`.
> Then `D`'s advantage between the real `Ω` and the ideal `Ω` is at most
> `ε_M3 + ε_E1 + N·δ`, where:
>
> * `ε_M3` is the advantage against the named generator (M-3, ruling C-3,
>   two-sided and over the whole stream);
> * `ε_E1` is the advantage against E-1 (independent OS entropy reads);
> * `δ = r(p−r)/(p·2^128) = 2^-96.0000000003` is one `fp()` draw's distance
>   from uniform;
> * `N` is the number of `fp()` draws.
>
> The hops are taken **in this order**: the generator assumption first, then
> the sampler (ruling J-1). At fixed `ρ`, conditioning on `E` costs nothing,
> because the real `Ω` is also independent of `(P, w, ρ)` (§2.2 step 4). The
> factor `1/Pr[A]` of JS §2.0a belongs to the Fiat–Shamir world, where `ρ`
> depends on the roots.

### 1.6 What LB is not

LB is not a statement about the view, the hash layer or Fiat–Shamir. It is a
per-proof statement. More than one proof needs the cross-proof clause of
§5.4. It says nothing about timing, memory or power (D20).

---

## 2. The argument from the three ingredients

### 2.1 The three ingredients

* **(i) The generator assumption [ASSUMED].** M-3 (ruling C-3): each
  generator's whole output stream is indistinguishable from uniform,
  two-sided. E-1 (ruling J-2): the separate OS entropy reads are independent
  and uniform. `ZkRng` is BLAKE3-XOF over `key ‖ le64(counter)`
  (`rng.rs:53-61`). Its key is keyed-BLAKE3 of 32 fresh `/dev/urandom` bytes
  over a public domain (`rng.rs:30-51`).
* **(ii) The draw discipline [ARGUED; the counts MEASURED].** Set out in
  §3.
* **(iii) The sampler's bias [COUNTED].** D9: one `fp()` draw is a uniform
  128-bit integer reduced mod `p` (`rng.rs:73-77`, `field.rs:36-38`), within
  `δ < 2^-96` of uniform. Summed in §4.

### 2.2 The proof of LB from them

1. **Hop 1, the generator [ASSUMED: M-3, E-1].** Replace each generator's
   stream by an independent uniform byte string. A standalone block has
   three generators and a run has three (§5.4).
2. **The map `Φ` from streams to `Ω` [ARGUED, §3].** Four properties:
   * (a) `Φ` is a fixed map: which stream word goes to which coordinate is a
     function of the shape, `L` and the stage index, and of nothing else;
   * (b) no stream word is returned twice (`rng.rs`: `pos` only grows
     within a refill, `counter` only grows, and there is no seek, set,
     `Clone` or serialisation);
   * (c) each drawn word feeds exactly one coordinate or is discarded, and
     the only relations imposed after drawing are the three of §1.3;
   * (d) the reduction mod `p` is the only non-identity step, and it selects
     nothing: there is no rejection or retry, and no choice among draws.

   Hence `Φ` pushes the uniform product of 128-bit integers and 256-bit salts
   forward to the product of the reduced draws. The zero-sum rows' closing
   entries and the overwritten `b` entries are deterministic and declared.
   The result is `Uniform(S_decl)` up to the reduction, times the law of the
   discarded words.
3. **Hop 2, the sampler [COUNTED].** Each reduced draw is within `δ` of
   uniform. The draws are independent, so the product is within `N·δ`
   (sub-additivity of total variation over a product). `Φ`'s remaining steps
   are deterministic, so data processing gives `TV(Ω_real, Ω_ideal) ≤ N·δ`.
4. **Independence from `(P, w, ρ)`, and conditioning [ARGUED].**
   * The keys are drawn from fresh entropy under public domains
     (`hash_domain.rs:207-262`). No witness value, root or challenge enters a
     key (the capture rule, `hash_domain.rs:161-167`).
   * By step 2(a), no position depends on `(P, w, ρ)`.
   * In the fixed-challenge experiment `ρ` is exogenous.

   So `Ω ⟂ (P, w, ρ)`, and conditioning on any event in `σ(P, w, ρ)` leaves
   `Ω`'s law unchanged. This holds for the ideal `Ω` and for the real one.
   What makes the refusals such events is §5.1: **no refusal reads a drawn
   value**.

### 2.3 What is load-bearing, and what is merely sufficient

`law_and_residual.py` §4 builds six exact models over `F_5`. Each has an ideal
stream of four symbols and two roles, and each masks one data value per role.
The question in each is whether `law(view | world, accept)` is the same in two
worlds:

| Model | Same law in both worlds? | Label |
|---|---|---|
| honest discipline, no refusal | yes (TV 0) | ARGUED; illustration |
| honest, with a challenge-only refusal | yes (TV 0) | " |
| honest, with a refusal on `(w, ρ)`, LogUp-like | yes (TV 0) | " |
| **the ORDER of draws chosen by the hidden data (still injective)** | **yes (TV 0)** | " |
| control: one drawn value used by two roles | **no (TV 1)** | " |
| control: a refusal that reads a drawn value | **no (TV 1/4)** | " |

So in the idealised world, an input-dependent **order** would be harmless.
The two things that are not harmless are **reuse** and a **refusal or branch
that reads a drawn value**. A public order and a public count, which the code
has, still earn their place for three reasons:

* they fix `N` for the D9 term;
* they make the discipline checkable by counting, since a witness-independent
  total can be compared across witnesses;
* they close the timing channel that a data-dependent count would open, a
  channel outside the model by D20.

Counting cannot see reuse. Ruling R-3's counterexample (ii), two distinct
rows with coinciding values, has probability 1 under a copy and passes every
count, and the joint-sentence page's A-19 already says so. This is why §5.7
matters.

---

## 3. The draw discipline, read off the code

### 3.1 Order and number of draws, in source order [ARGUED; pinned to `2ea7221` by `draw_discipline_scan.py` A]

| # | Site (`2ea7221`) | What | Enclosing control flow | Count is a function of |
|---|---|---|---|---|
| G1 | `protocol.rs:813` | `ZkRng::from_os(single_block_seed_domain(sh))`, one per standalone attempt | the body of `prove_inner_at` | — |
| G1r | `run.rs:727` | `ZkRng::from_os(run_seed_domain(profile))`, one per run | the body of `prove_run` | — |
| 1 | `protocol.rs:1003` | `A` mask and proximity rows | `for x in &mut a_data[lay.a_mask_base * n..]` (`:1002`) | `layout.rs:1085-1087` |
| 2–3 | `protocol.rs:1009` → `pcs.rs:777, :778` | `A` pads, then `A` salts | the body | `a_rows`; `q_pad = num_col_checks` (`pcs.rs:579-580`); `nn` |
| 4–7 | `protocol.rs:1021` → `zk.rs:485, 496, 503-508, 513` | `α`, then the 46 pad blocks, then `b` and `u`, then 4,096 salts | `for (s, mk) in masks…` / `for (k, part) in [re, im]…` (`zk.rs:489, 492`) | `lay.mask_specs()` = `sh.slots()` (`layout.rs:1227-1229`); `MASK_*` (`zk.rs:373-375`) |
| 8 | `protocol.rs:1116` | `H` mask and proximity rows | `for x in &mut h_data[lay.h_mask_base * n..]` (`:1115`) | `layout.rs:1096-1098` |
| 9 | `protocol.rs:1121` | `H` zero-sum rows, `n − 1` each | `for r in lay.h_u_rows()` → `for j in 0..n - 1` (`:1118, :1120`) | `n` |
| 10–11 | `protocol.rs:1128` → `pcs.rs:777, :778` | `H` pads, then `H` salts | the body | `h_rows`, `nn` |
| run | `run.rs:756`, then `run.rs:774` | boundary `B_k` (mask rows `boundary.rs:347`, then pads and salts `:350`), then block body `k` (1–11) | `for k in 0..l` (`:739`); the boundary only under `if k + 1 < l` (`:750`) | `k`, `L`, the boundary spec |
| endpoint | `endpoint_g.rs:269, 277, 280` (toy: `private_seam.rs:196, 212, 215`) | own `from_os`, 5 mask rows, then pads and salts | `for x in &mut data[first_mask * n..]` | the endpoint spec |

The scan asserts that each of these functions draws at exactly these lines,
in this order. It also asserts that **every enclosing header is a loop over a
shape, layout or spec constant, or the run's `k` and `L`**: none is an `if`,
`match`, `while` or `loop` on a witness value, a challenge, a drawn value, a
feature or an environment variable. The one `if`, `k + 1 < l`, is public.
Every count is a layout or spec constant. `Layout::check_is_for_shape`
(`layout.rs:1178-1204`, ruling CS-8) refuses a caller-built layout at every
entry, so a caller cannot move a count. Within `pcs.rs`, the pads and the
salts are drawn **before** any backend or tag branch (`pcs.rs:777-778`
against `:782-785`). The accelerator therefore cannot move a draw.

**The generator never reaches the slot argument or an opening** (scan C).
`argument.rs`'s production text has no `rng`. `pcs::open_zk`
(`pcs.rs:1023-1052`) and `zk::mask_open` (`zk.rs:563`) take none. The
refusal replay squeezes a **clone** of the transcript (`protocol.rs:326-327`,
`:388-389`). On a real rung-G `L = 2` run, the openings are measured drawing
nothing from the run's generator (the assertion at `s36_tests.rs:1403`).
**MEASURED** at one shape; ARGUED everywhere else.

So the ORDER and the NUMBER of draws are functions of `(shape, L, k)` only.
[ARGUED by reading.]

### 3.2 Each stream word is used at most once [ARGUED]

* `ZkRng`'s fields are private (`rng.rs:9-14`). Its public surface is `new`,
  `from_os`, `next_u64`, `fp`, `fp2`, `fp_vec`, `fp2_vec` and `bytes32`. There
  is no seek, set or rewind, and it has no `Clone`, `Copy` or `Serialize`
  (scan D; the lane's `rng.rs` test `the_generator_is_still_not_clone`).
* `pos` grows by 8 inside an 8,192-byte buffer and is reset only by `refill`,
  which increments `counter` (`rng.rs:53-70`). Distinct refills hash
  distinct inputs `key ‖ le64(counter)`, so a generator returns each stream
  word at most once.
* `fp()` takes two words, `bytes32()` four, `fp2()` two `fp()`s.
* The owners that hold drawn values are consumed by value and have no
  `Clone`: `Endpoints` and the endpoint owners (`private_block.rs:1029-1041`,
  `endpoint_g.rs:209-211`, `private_seam.rs:142-143`), `PreparedBoundary`
  (`boundary.rs:238-281`, `into_opening(self)`). So a drawn plane cannot be
  opened twice, and cannot be reused by a second attempt (J-4).

### 3.3 No drawn value decides anything [ARGUED]

In the draw window of `prove_core`, the early exits after the first draw are
at `protocol.rs:1052, 1053, 1060, 1062, 1092, 1140, 1153, 1157`
(scan B). Line 1111 is a `#[cfg(test)]` injection. §5.1 lists what each one
reads, and none reads `Ω`. The masked-sumcheck provers assert only on the
challenge `c` (`zk.rs:1081, 1093`). The mask-site assertion in `open_zk`
reads only `ρ` (`pcs.rs:989-1004`). No draw sits inside a branch (§3.1).

### 3.4 The declared relations are the only ones [ARGUED; MEASURED only in part, see §5.7]

The three relations are the two `b` overwrites and the zero-sum closing entry
(§1.3). Two further facts come from reading `prove_core`:

* The zero-sum rows lie in `H`'s **data** region (`layout.rs:1281-1284`, the
  `H_U` plane), below `h_mask_base`. So the mask fill at `:1115-1117` does not
  cover them, and no drawn word is overwritten there.
* No drawn buffer is copied into a second commitment:
  * `a_data` moves into `A`'s commitment (`:1009`), `h_data` into `H`'s
    (`:1128`), and `mc` owns `α`, `b`, `u` and `M`'s pads.
  * The only cross-channel reads are the designed ones:
    * the slot loop reads `pd.data[·]`, the committed matrices of `A`, `H`
      and the two IO commitments, to form the extension rounds' masked
      terminals (`argument.rs:541`);
    * the slot loop also reads `pd.masks` (`α`) (`argument.rs:524`);
    * boundary `B_k`'s two disjoint reserved pairs are read by stage `k`'s
      slot 22 and stage `k+1`'s slot 21 (`run.rs:766-773`).
  * These reads put one commitment's blinding into two channels, `V_pcs` and
    `V_sc`, which Theorems 3.3 and B handle by conditioning on all of `π`
    first (toy memo C-12; run memo §3.7, first remark). They do not put one
    value into two commitments.

### 3.5 What the stage 36 and 46 observers measured, and whether they pin order

| What | Stage 36 (`29cba9a`) | Stage 46 (`2ea7221`) | Pins ORDER? |
|---|---|---|---|
| total stream bytes of the block generator, in situ | toy and five rungs; toy 5,396,672 B = 320,908 fp + 8,192 salts | rung-G 687,028 fp; 125M 9,029,804 fp | **no**: a total |
| per-role offsets inside `prove_core` | **derived**, not measured (S36-F3) | still derived | **no** |
| witness- and statement-independence of the total | **MEASURED at the toy** (three `(witness, statement)` pairs including all-zero; `s36_tests.rs:657`) | one witness per shape; equal to the witness-free COUNTED figure | no (counts only) |
| endpoint generators | on a **replica** (S36-F2) | replica, plus the objects the real generator filled READ in situ; equal | no |
| run: the generator between steps | — | **rung-G, `L = 2`**: boundary 0 = 8,704, then stage 0 = 687,028, then stage 1 = 687,028, and the openings draw nothing (`s36_tests.rs:1353-1403`), on a replica of `prove_run`'s loop held to production by a source test (`:1602`) | **coarse order yes**, at one shape and one `L` |
| 125M run | — | a sum of measured parts, not a measured run | no |
| value-level relations (assertion 6) | a source scan (`s36_tests.rs:727-796`) | unchanged | no; and see §5.7 for coverage |

**Answer.** The observers measured **counts**, at six plus two shapes. They
pin the **run-level interleave** (boundary before block, per stage) at rung-G
`L = 2` only. They pin **no order inside a block**: J-5's widened assertion 2,
the `11L + 3(L−1)` segment offsets, is measured nowhere. The order inside a
block is ARGUED by reading, and this page's scan pins that reading to a
commit. A pinned scan is not a lane test.

---

## 4. The sampler residual, recomputed exactly [COUNTED; `law_and_residual.py` §1–3]

`p = 2^64 − 2^32 + 1`. `2^128 mod p = r = p − 2^32`. The exact law of
`U mod p` for `U` uniform on `[0, 2^128)` gives

* `TV(one fp(), uniform) = r(p − r)/(p·2^128) = 2^-96.0000000003`, recomputed
  from the definition and equal to the closed form;
* the **rejection-region mass** `r/2^128 = 2^-64.0000000007`. This is the
  "bias 2^-64" of the `rng.rs:72` comment. It is a per-outcome relative bias,
  not a distance, and pricing it as an event costs 32 bits (JS A-13 and A-14;
  D9's verification note).

Salts are four raw `next_u64` words (`rng.rs:93-99`) with no reduction, so
they are **exactly** uniform in the ideal stream and carry no D9 term.

| Object | `N` (`fp()` draws) | `log2(N·δ)` | As quoted | Provenance of `N` |
|---|---:|---:|---|---|
| toy proof, three generators | 327,052 | **−77.6808** | 2^-77.7 (D9 / D22) | MEASURED, stage 36 |
| rung-G standalone proof | 701,876 | −76.5791 | 2^-76.58 | MEASURED, stage 46 (endpoints: replica plus in-situ objects) |
| rung-K4 standalone proof | 765,388 | −76.4542 | 2^-76.45 | stage 36 block plus replica endpoints |
| **125M standalone proof** | 9,212,588 | **−72.8648** | 2^-72.86 | MEASURED, stage 46 (endpoints: replica plus in-situ objects) |
| rung-G run, `L = 2` | 1,397,608 | −75.5855 | — | MEASURED in situ on the run stream (1,382,760) plus endpoints |
| rung-G run, `L = 3` | 2,093,340 | −75.0026 | H-6 | a sum of measured parts |
| **125M run, `L = 12`** | 109,728,784 | **−69.2906** | 2^-69.3 | H-6; a sum of measured parts, not a measured run |
| the same, pre-S19-F1 count | 109,728,040 | −69.2906 | — | 744 = 12 × 62 lower; no change at four decimals |

The per-part draw counts come from the segment formulas of §1.2 with the
shape constants. They equal the lane's measured parts at the toy, rung-G,
rung-K4 and 125M for the block, the endpoint and the boundary, and are
asserted equal in the script. `N·δ` and `N·2^-96` agree to six decimals.

**Over many proofs** (a hybrid over proofs), the toy gives 2^-57.75 and
125M gives 2^-52.93 at 10^6 proofs. **This is valid only if the blinding is
independent across proofs, and nothing named covers that (§5.4).**

---

## 5. Where the argument needs more than (i)–(iii)

### 5.1 Refusals, and the absence of a restart [ARGUED; one operating rule]

A refusal returns `Err` and no receipt is assembled. A standalone block never
reaches `protocol.rs:831` on `Err`. `Endpoints` is consumed by value at
`:802` on success and on failure, and each attempt makes its own generator at
`:813`. **Nothing restarts on the same generator or the same endpoints**
(J-4). A service retry is a new call, with fresh generators and freshly
prepared endpoints.

What each exit after the first draw reads:

| Exit | Reads | Reads `Ω`? |
|---|---|---|
| `protocol.rs:1052-1053`: the helper inverses, zero LogUp denominator | the looked values (`w`), `α`, `γ` | no |
| `:1060, :1062`: the exp and activation denominators | `w`, `α`, `β`, `γ` | no |
| `:1092`: the table denominators | the public tables, `α`, `β`, `γ` | no |
| `:1140`: `argument(…)` refusals: `c = 0` (`argument.rs:479-482`), `e ∈ {0,1}` (`:589-591`), the `nonzero` batching challenges (`:951-956`), schedule and table-shape checks (`:450-463`, public) | challenges and the shape | no |
| `:1153, :1157`: `check_opening`, which is `audit_claims` (`protocol.rs:230-274`; claim coefficients are products of challenges) plus the group count plus `check_opening_challenges` on a cloned transcript (`:293-314, 326-327`) | challenges and the schedule | no |
| `prove_inner_at :820, :824`: `check_endpoint_opening` (`:376-390`) | challenges and the schedule | no |
| before the first draw: `refuse_lookup_misses` (`:978`), shape, layout and statement checks, `from_os` failure | `w` and the public statement | no draw has happened yet |
| run: `src.boundary_plane(k)?` (`run.rs:752`), `boundary::prepare`'s length and canonicity check (`boundary.rs:339-341`), `src.witness(k)?` (`:764`), `into_opening` (`:782`), `sink(k, …)?` (`:820`) | `w`, the public spec, the environment's I/O | no |

So the acceptance event `A` is a function of `(P, w, ρ)` and the
environment. By §2.2 step 4, `law(Ω | A, P, w, ρ)` is uniform. The law of a
refused attempt does not matter, because a refused attempt publishes nothing.
That last point is **an operating rule, not a code fact**:

* D21: a receipt the prover's final check rejected is never transmitted.
  HB-1: the production caller verifies before emitting.
* M-9: a run directory without the run statement is never transmitted, and
  the launcher removes it. A refused run leaves up to `k` finished segments on
  disk (R-1).

What a refusal reveals when a retry is visible (changed roots, timing) is the
refusal channel. That is S-4's 2^-118.4 per block, J-4 and R-1. It is not the
blinding's law. **OPEN**, as operating conditions: D21, M-9 and HB-1 must hold
in whatever production caller is written (S-5).

### 5.2 Draws whose count depends on a challenge [ARGUED; the openings MEASURED at rung-G `L = 2`]

There are none.

* The generator is never passed to the slot argument or to an opening (§3.1).
* `nonzero(…)` **refuses** and never redraws (`argument.rs:951-956`). The
  same holds for `c = 0` and `e ∈ {0, 1}`, whose comments say "never
  resampled" and "never redrawn" (`argument.rs:477-478, 587-588`).
* The refusal replay squeezes a clone and consumes no generator byte. Stage
  36 measured this: the closed form has no replay term, and it is asserted
  for the endpoint calls.

The *transcript's* squeeze counts are also shape-determined: 14,252 at 125M,
the same on the dense and the all-zero bundle (stage 45 and gate round 9j,
MEASURED). `challenge_indices` masks with a power-of-two bound and does not
reject (lane `transcript.rs:136-148`). That is not the generator either way.

### 5.3 Rejection sampling [ARGUED]

There is none. `fp()` is a reduction, so every `fp()` consumes exactly 16
bytes whatever it draws (JS A-2). Had it rejected, LB would still hold by a
stopping-time argument (JS A-9), but the positions would be random stopping
times, and "a fixed map `Φ`" in §2.2 step 2 would have to become "a
stopping-time map shown witness-free".

### 5.4 Separate generators, and what E-1 covers [ASSUMED; one gap OPEN]

* **Within one attempt [ASSUMED: E-1].** A standalone block has three
  generators (`protocol.rs:813`, and `endpoint_g.rs:269` twice through
  `private_block.rs:1075-1076`). A run has three (`run.rs:727` and the two
  external endpoints). `4L − 1` of the `4L + 1` commitments of a run share
  one stream, 47 of 49 at `L = 12`, so their independence rests on M-3 over
  disjoint positions (§3.1). The rest rests on E-1.
* **A structural backstop at tagged profiles [ARGUED].** Since stage 26 the
  three domains differ by use literal and role byte (`hash_domain.rs:177-262`):
  `0x00`/`0x01` for the endpoints plus the spec digest, `0x02` for the single
  block, `0x03` for the run. The key is keyed-BLAKE3 with the entropy as key
  over `literal ‖ domain` (`rng.rs:44-50`). Suppose the three reads returned
  the **same** 32 bytes. The three keys would still be three evaluations of
  one keyed function on three distinct inputs, pseudo-independent under the
  PRF property of keyed BLAKE3 with a secret key. That is an assumption of the
  same kind as M-3. At tagged profiles, therefore, the total failure of E-1 is
  covered by an assumption the project already makes. **At the frozen toy it
  is not**: both endpoints call `private_seam::prepare`, which uses the one
  28-byte `DOMAIN` (`private_seam.rs:196`). That is D22's clarification 6,
  unchanged here.
* **Across proofs, NOT covered [OPEN].** E-1 as worded (ruling J-2) is about
  "separate reads … made by one process **within one proof**". Several
  statements use independence **across** proofs:
  * the "grows linearly, about 2^-57.7 at a million proofs" row of D22 §4;
  * the 10^6-proof column of the standalone-block table;
  * the toy memo's §6.3 row 29 ("conditional on … cross-proof stream
    independence").

  Across proofs, the domains are identical for the same profile, so there is
  **no** structural backstop. A repeated entropy read, from a VM snapshot
  restore, a container checkpoint and restore, a process `fork()` after key
  derivation, or a pre-initialisation entropy pool, gives two proofs the
  **same** blinding. The published values of two different inputs then differ
  by the difference of the data: the classic nonce-reuse leak. **Proposed:**
  widen E-1 by name to "every `from_os` read, in any process, is independent
  of every other", and list the four deployment hazards beside D21's
  operating rules.

### 5.5 The endpoint generator on a replica (S36-F2) [ARGUED: immaterial to the law]

Stage 46 read the objects the **real** endpoint generator filled (the mask
words above the data rows, the pads and the salts), in situ, and found them
equal to the replica's counts. A source test holds the replica to the
production body's two draw steps. What remains unobserved is the real
generator's **byte counter**, which could reveal a draw the owner does not
store. A stored value that was not drawn would break LB. An extra unstored
draw would not affect `Ω` at all, and would only make D9's `N` conservative.
So S36-F2 concerns the provenance of `N`, not the law. The one-line
`endpoint_g::prepare_with_rng` would close it. **OPEN (small)**.

### 5.6 Anything shared across commitments [ARGUED]

| Candidate | Shares a blinding VALUE across commitments? |
|---|---|
| the one run stream across `4L − 1` commitments | no: disjoint positions (§3.1). Totals MEASURED; coarse order MEASURED at rung-G `L = 2` |
| a boundary's two claim sites in two stages | no: two **disjoint** reserved pairs of one commitment; `audit_claims` refuses a shared one (`protocol.rs:270-272`) |
| the endpoint planes are `A`'s own planes; a boundary plane sits in `A_k`, `B_k`, `A_{k+1}` | no: shared **data**, not blinding (Corollary R.2) |
| `H`'s zero-sum pair shared by two `H` groups | within one commitment: the one deliberate exception, tied by the public LogUp identity |
| `α` read by the slots and committed in `M` | by design: (H3) and (H4) |
| a reserved pair read by `V_sc` (the extension rounds) and by `V_pcs` | by design: C-12; handled by conditioning on all of `π` |
| hash-tag keys, NTT tables, the transcript | public, not blinding |

### 5.7 The machine assertion covers less than it says [ARGUED; `draw_discipline_scan.py` E] — FINDING

Ruling R-3 asked for independence to be machine-asserted. The value-level
half is J-5's assertion 6, `s36_tests::the_only_relations_imposed_on_drawn_
values_are_the_three_the_schedule_declares` (`s36_tests.rs:727-796`). Its
docstring (`:712-713`) says it finds "every buffer a generator filled
(`rng.fp_vec`, …, and the `for x in &mut <slice> { *x = rng.fp(); }`
idiom)". The code does not do what that sentence says:

* the scan skips every line whose trimmed text starts with `*`
  (`s36_tests.rs:738`, meant for doc-comment lines), and that skips
  `*x = rng.fp();` itself;
* `binding_name` returns a name only for a `let` binding (`:897-906`);
* `α` is drawn through `CfsMask::random(rng, …)` (`zk.rs:485`), which contains
  no `rng.` pattern.

A Python port of the test's matching logic, run on the same nine files at
`2ea7221`, reproduces the test's result exactly: four overwrite sites, all
declared. It also shows that **the drawn buffers the scan can see are `pads`,
`salts`, `b_re`, `b_im`, `u_re`, `u_im` and `v`**. Five production fill sites
are invisible to it:

* `protocol.rs:1003` and `:1116` (the reserved pairs and proximity rows of
  `A` and `H`);
* `endpoint_g.rs:277`, `boundary.rs:347` and `private_seam.rs:212`;
* and so is `α`.

Mutations, one inserted line each:

| Mutation | Flagged by the scan? |
|---|---|
| m1: overwrite a drawn `A` proximity-row word after the fill | **no** |
| m2: copy an `A` reserved-pair word into `H`'s reserved rows | **no** |
| m3 (control): overwrite a drawn `u_re` word | yes |

m1 and m2 also move no count, so assertions 1–4 stay green. **The reserved
pairs, the proximity rows and `α` are exactly the blinding that the
per-commitment rank argument, the terminal-surjection step and the CFS
degrees-of-freedom identity depend on.** So on the page, cross-role
independence is machine-asserted for positions (derived), totals (measured)
and the relations on pads, salts, `b` and `u`. It is **not** machine-asserted
at the value level for the reserved rows or `α`.

This is a port, not the Rust test. **A checker should confirm it on the Rust
test with m1 and m2.**

**Smallest closures (OPEN, for the lane).**

* (a) Widen the scan. Bind the slice name from the `for x in &mut NAME[…]`
  header and scan for later writes into `NAME` after that line. Treat
  `CfsMask::random(rng` as a draw of `masks`. Add a "no read of a drawn region
  into another commitment's buffer" pattern.
* (b) The stronger option: a **seeded replay test**. `prove_core` takes its
  generator from the caller (`protocol.rs:906`), and tests already call it
  that way (`s36_tests.rs:254`). Run it on `ZkRng::new(seed, …)`, regenerate
  the same stream independently, cut it at the predicted offsets, rebuild
  `A`'s, `M`'s and `H`'s committed matrices and salts from the witness and the
  predicted segments, and require the three **roots** to match. Collision
  resistance makes that a value-level check of every blinding coordinate's
  position, order and injectivity at once. It would also close S36-F3 and
  J-5's assertion 2.

### 5.8 Order inside a block, and at run scope [ARGUED; OPEN as a measurement]

Inside `prove_core`, the order is ARGUED (§3.1) and pinned by this page's
scan, and it is measured nowhere (S36-F3). At run scope, the interleave was
measured once, at rung-G `L = 2`, on a replica loop. The `11L + 3(L − 1)`
offsets of J-5's widened assertion 2 are measured nowhere, and the 125M run
is a sum of parts. §2.3 shows that order is not what the law rests on. What
this item really owes is §5.7's value-level check, which would pin order as
a by-product.

### 5.9 The run's hidden input must be fixed before its stream [OPEN: an operating condition]

LB-1 needs `w ⟂ Ω`. `RunWitnessSource::witness(k)` and `boundary_plane(k)` are
called inside the stage loop (`run.rs:752`, `:764`), after segment `k − 1` has
gone to the sink (`:820`). An adaptive source could choose block `k`'s input
from earlier segments, which are functions of `Ω_{<k}`. That is ruling R-2's
condition 2, as corrected by H-1:

* for an **accepted** run, the endpoints are sealed by the witness builder's
  own pass before the header;
* the hidden values are the committed input's forward pass;
* an adaptive source can therefore move them only where the witness is not
  unique given the input.

This page does not examine that case. **OPEN** as stated in R-2.

### 5.10 The Fiat–Shamir world [not this page]

LB lives in the fixed-challenge experiment. In the hashed protocol, `ρ` is
computed from the transcript, which absorbs roots, which are functions of
`Ω`. Independence of `ρ` and `Ω` there is the **content of hop 1** (JS §2.0a,
ruling J-1) together with Lemma H^run and Route A (G-R5). The interface is
exactly LB-2. Nothing here re-argues it.

### 5.11 Test-only and device paths [ARGUED]

The `#[cfg(test)]` injections in `prove_core` (`:989-1001`, `:1102-1114`) and
`CheatingProver` draw nothing and are absent from a release build. On the GPU
path the draws come first (§3.1). D22's scope is the CPU path (J-3), and this
page inherits that scope.

---

## 6. Status, open items, and what a checker should attack first

| # | Claim | Label |
|---|---|---|
| 1 | LB (§1.5) implies (H5), (H5^run), Proposition R.1 (ii) / O-2 and JS clause (a) | ARGUED |
| 2 | The generators' streams are uniform and the reads independent | **ASSUMED**: M-3, E-1 (within one proof) |
| 3 | The order and number of draws are functions of `(shape, L, k)` only | ARGUED (§3.1); scan pinned to `2ea7221` |
| 4 | Each stream word is returned at most once; the owners are not `Clone` | ARGUED (§3.2) |
| 5 | No refusal or branch reads a drawn value | ARGUED (§3.3, §5.1) |
| 6 | The declared relations are the only ones | ARGUED; MEASURED only for pads, salts, `b`, `u` (§5.7) |
| 7 | Draw totals per generator | **MEASURED** at the toy and 5 rungs (stage 36), rung-G and 125M standalone, rung-G `L = 2` (stage 46); the 125M run is a sum of measured parts |
| 8 | Witness-independence of the total | **MEASURED** at the toy (3 pairs); elsewhere ARGUED plus one-point MEASURED = COUNTED |
| 9 | Coarse run-level order, and openings draw nothing | **MEASURED** at rung-G `L = 2` (a replica loop) |
| 10 | The residuals 2^-77.68, 2^-72.86, 2^-69.29 | **COUNTED**, exact (§4) |
| 11 | Order inside a block | ARGUED; **OPEN** as a measurement (S36-F3; J-5 assertion 2) |
| 12 | Value-level injectivity for the reserved rows and `α` | **OPEN** (§5.7) |
| 13 | Cross-proof independence of the generators | **OPEN**: unnamed (§5.4) |
| 14 | The run's input fixed before its stream | **OPEN**: an operating condition (R-2.2) |
| 15 | Refused attempts and partial run directories never published | **OPEN**: operating rules D21, M-9, HB-1 |
| 16 | S36-F2 (endpoint byte counter) | **OPEN, small**; immaterial to the law |

**Attack first, in this order:**

1. **§5.7 on the Rust test.** Insert m1 and m2 into `protocol.rs` in a
   scratch copy and run
   `s36_tests::the_only_relations_imposed_on_drawn_values_are_the_three_the_schedule_declares`.
   If it stays green, the finding stands. If it goes red, this page's port is
   wrong.
2. **§3.3 and §5.1, "no control flow reads a drawn value".** Re-derive the
   exit list after the first draw independently. Look inside `argument()`,
   `masked_prove` and the transcript masker (`CfsMasker`) for any branch or
   assert on a value computed from `α`, a reserved row or a pad. One such
   branch makes LB-2 false (the TV = 1/4 model).
3. **§2.3's exchangeability claim.** Is there any way an input-dependent
   order or count could matter that the models miss? Candidates: the
   positions of published salts under Fiat–Shamir, or the non-adaptive M-3
   reduction when `ρ` depends on the stream.
4. **§5.4.** Confirm that no page names cross-proof independence, and that
   the million-proof figures use it.
5. **§1.3, whether `S_decl` is complete.** Is any drawn value constrained by
   anything other than the three declared relations? For example, is a
   reserved row ever overwritten by a data plane at some shape, or do the
   endpoint or boundary geometries leave a mask row inside the data region?

---

## 7. Reproduce

```
python3 results/zk60_blinding_law_gr4/law_and_residual.py
python3 results/zk60_blinding_law_gr4/draw_discipline_scan.py 2ea7221
```

Both exit 0. The second reads the lane only through `git show`, and writes
nothing there.

**Not a privacy acceptance.** No run, development rung or 125M block is
private on the strength of this page. D22 is untouched.
