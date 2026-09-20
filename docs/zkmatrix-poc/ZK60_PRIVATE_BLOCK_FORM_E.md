# Form E: a complete private block at model width that keeps the GPU feed-forward prover

**Status: REVISED AFTER INDEPENDENT CHECK — core accepted, NOT yet accepted as a design to build, per `ZK60_PRIVATE_BLOCK_FORM_E_DISPOSITION.md` (security owner, 2026-09-19). Errata E-1 … E-20, conditions C-1 … C-11 of `ZK60_PRIVATE_BLOCK_FORM_E_CHECK.md` and rulings R-1 … R-5 applied in this text. Not a privacy acceptance; D8 and D11 remain open; paper only. Drafted by a delegated Opus agent.**

## 0. What this is, and what it is not

**In plain words.** A transformer block is attention followed by a
feed-forward part. The project has two provers that can each do half of it
privately, and they are built in different idioms. The attention-side prover
(`hashline/src/private_block.rs` and `hashline/src/private_block/`) proves a
*whole* block today — attention, both norms, the feed-forward and both
residuals — but only at a toy geometry (32 tokens, width 16), and it does the
feed-forward arithmetic in its own idiom on the host. The other prover
(`hashline/src/zk.rs`, `hashline/src/layer.rs`) proves the feed-forward alone,
at real model width, with CUDA kernels written against a block decomposition
of the weight matrices — and it is the only route to speed anybody has
measured (58.40 s for all 32 feed-forward layers of Mistral-7B at 512 tokens,
public inputs and outputs, on a laptop RTX 4070 [MEASURED, NOISY-SHARED,
2026-09-04; `MVP_STATUS.md:139`]).

"Form E" is the construction that keeps both: the attention half proved by the
native private argument, the feed-forward half proved by the GPU prover, the
two joined by a *masked equality* — a proof that two sealed boxes hold the same
hidden numbers, without opening either. The construction memo on branch
`zk60-attention-compile` named this form, priced it and deferred it
(`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md` §B.2, §B.3); the security owner's
disposition accepted the deferral and recorded that form E "is the only form
that keeps the block-decomposed GPU feed-forward prover and is what 8B will
probably need" (`ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md` §1.1). This
page designs it properly, so that the next independent check has something
concrete to attack.

**What this is not.** It is paper. No code was written, built or run for it. It
establishes **no privacy property**; it does not close D8 or D11; it makes no
speed claim; every number in it is a count or a model unless it carries
[MEASURED]. Three counted speed estimates in this project shrank three- to
seven-fold this week when they were finally measured, so treat every second in
§G as a hypothesis with a named experiment attached.

**What is already decided and is binding here.** D1 (inputs, outputs and every
intermediate activation hidden; weights may be public). D12 (a block is one
proof under one transcript with exactly two external endpoints; **no
commitment is opened more than once**; hidden intermediates never get a
caller-fixed endpoint commitment shared by two proofs; the second norm proves
its output is int8; declared scales are tied to the calibration). D13 (the
first MVP proves hidden blocks; token generation is the next milestone). D15
(quote the whole-proof soundness figure, not the per-opening one). D16 (the
norm's range pins when the geometry is widened). D17 (an entry point that
accepts a shape other than the pinned tiny one binds the **whole** plane
through the batched multi-block seam, at every width; the tiny private-IO path
stays byte-frozen; everything new is additive; pair exclusivity is enforced in
code; an io-path joint-view capture is a hard gate). **D18** (for the first
MVP the **prover** seals the hidden input and output at proof time; sealing in
advance by a third party — a salted handle that is **not** a
polynomial-commitment root, plus a hashing gadget inside the proof — is a
recorded todo and the expected end state, `ZK60_DECISIONS.md` D18). And the
rule that binds §F: **a private run is one transcript end to end**, because
two separately finished private proofs cannot be chained through a commitment
root (`ZK60_D8_D11_RESTATEMENT_DISPOSITION.md` §2 item 5).

**What the independent check changed, in one place.** The check
(`ZK60_PRIVATE_BLOCK_FORM_E_CHECK.md`) and the security owner's disposition
accepted the construction's core — nothing is opened twice, the seam adds
**0** to the disclosed dimension on a small linear model, the pair discipline
is right and is now quantified, the soundness arithmetic reproduces — and
returned the draft for revision on five blocking points, all applied below:
the acceptance experiment and its gate (§D.6, §H step 0 and step 8), the
tiling constraint's scope (§B.2), the memory figures the build plan rested on
(§F, §G.2: **one block ≈ 28.9 GB resident, two ≈ 57.9 GB** — `g = 2` does not
fit a 32 GB card), and the transcript restructuring (§B.6: **two** lookup
triples, the frozen prover is not split, which reverses decision 4). Two
consequences reach the top of the page: **the first feasible target for
complete private blocks in one transcript is the 125M-class shape**, with the
8B case recorded as not fitting one consumer GPU under this construction; and
about 60 % of every model-width byte figure here is an ESTIMATE for an
attention layout that does not exist.

**A naming note, because two rulings sets meet on this page.** From here on
**R-1 … R-5 unqualified are the form-E disposition's rulings**
(`ZK60_PRIVATE_BLOCK_FORM_E_DISPOSITION.md` §2). The earlier rulings this
page also cites — from the endpoints-at-scale disposition and the
private-block construction disposition — are written out as "the endpoints
disposition's R-x" and "ruling R-A".

**Vocabulary, once.** A *commitment* is a sealed box of numbers, identified by
a 32-byte *root*; *opening* it publishes 256 sampled columns of its encoded
form plus their authentication paths, which is how a verifier checks a claim
about its contents. A *claim site* is one point at which a proof asks for a
committed plane's value; each site is blinded by its own *reserved mask pair*,
two extra uniform rows of the same commitment, drawn before the commitment
exists and used by that site and no other. A *CFS slot* is a masking
polynomial, living in a separate *masking commitment* `M`, that blinds one
sumcheck's round messages. An *opening group* is a set of claims that share a
column key and are answered by one published vector. A *plane* is one named
rectangle of hidden numbers (`nm`, `z16`, `xres1`, …) inside a commitment. A
*d-block* is one chunk of the model-width axis: the feed-forward prover cuts
the width into `nb_d` blocks of `2^log_db` columns, and `nb_d = 1` only when
the width is a power of two no larger than 4096.

## A. The object: two provers, one transcript, one block

### A.1 What a block is, arithmetic first

The arithmetic is fixed by the kernel the built block module reproduces
(`hashline/src/private_block.rs:6-11` states the chain
`x_in -> ... -> nm -> (g8,u16) -> a16 -> h16 -> z16 -> xres2`):

```
attention half        x_in  --norm_a-->  y   --QKV,RoPE,causal softmax,Wo-->  ao
                      xres1 = x_in + ao                      (residual 1)
                      nm    = norm_m(xres1)                  (second RMSNorm, int8 out)
feed-forward half     g  = requant(nm · Wg, SH_G=7)   -> int8, including -128
                      u  = requant(nm · Wu, SH_U=0)   -> int16
                      a  = act[g + 128]               -> the 256-entry SiLU table
                      h  = requant(a · u, SH_H=14)    -> int16
                      z16= requant(h · Wd, SH_Z=6)    -> int16
back on the other side  xres2 = xres1 + z16            (residual 2)
```

The shift constants are `SH_G=7, SH_H_PROD=14, SH_Z=6` with `SH_U = 0`
implicit (`hashline/src/private_block/layout.rs:66-70`). In form S all of
this is one prover. **In form E the cut is drawn exactly once, at `nm` going
out and `z16` coming back**: everything above the feed-forward line and
residual 2 below it stay with the attention-side prover; the four
feed-forward steps go to the v3 prover.

### A.2 The commitments that exist, side by side

There are two provers, so there are two sets of commitments, and under D12
item 2 they live under **one** transcript.

**Attention side** — the `private_block` module's three, at the tiny geometry
today (`private_block.rs:399-408`; the `Receipt` carries `a_root`, `h_root`,
`mask_root`, and the two endpoint roots come from the caller's `ExpectedIo`
and are absorbed, not carried in the frame, `private_block/wire.rs:80-82`):

| name | what it holds | rows at T32/d16 | root fixed by |
|---|---|---:|---|
| `A_attn` | every witness plane (`layout.rs:112-200`, `N_A = 81`) plus the committed lookup multiplicities, then two reserved mask rows per claim site, then one proximity pair | 455 (`A_ROWS`, `layout.rs:523`) | **prover** |
| `H_attn` | 51 Fp2-valued LogUp helper planes, each as a real slice and an imaginary slice, plus the zero-sum pair `u`, mask rows, proximity pair | 384 (`H_ROWS`, `layout.rs:524`) | **prover** |
| `M_attn` | the 23 CFS masking polynomials, two rows each, plus `b_re, b_im, u_re, u_im` | 50 (`M_ROWS = 2·23+4`, `layout.rs:519`) | **prover** |
| `In` | the hidden input plane `x_in`, a 7-row `private_seam` hiding commitment | 7 (`private_block/protocol.rs:184-190`; `private_seam.rs:106-111`) | **caller** |
| `Out` | the hidden output plane `xres2` | 7 | **caller** |

PCS parameters on this side today: `log_cols 8, inv_rate 8, 256 column checks`
(`private_block/protocol.rs:21-23`), i.e. 256 message positions per row and
2,048 encoded positions, with `NttTables::new(12)` (`protocol.rs:276`, `:435`).

**Feed-forward side** — the v3 prover's four (`zk.rs:741-777`,
`LayerProofZk`):

| name | what it holds | rows at 125M / Mistral | root fixed by |
|---|---|---:|---|
| `W_ffn` | `Wg`, `Wu`, `Wd` in `nb_d × nb_f` blocks (`statement.rs:169-170`) | 288 / 10,752 | **prover** (P1 may pin it to a caller-supplied public root, `zk_ffn_fresh_poc.rs:163-176`) |
| `A_ffn` | 7 planes per f-block (`g8, rg, a16, u16, ru, h16, rh`) and 3 per d-block (`x, z, rd`), then the mask pairs, then the six committed table histograms (`zk.rs:2476-2532`) | 585 / 3,665 repaired | **prover** |
| `H_ffn` | the LogUp helpers `hg, hu, hh` per f-block and `hz` per d-block, plus table helpers | 486 / 3,030 | **prover** |
| `M_ffn` | the six CFS masking polynomials plus `b`/`u`, `n_base = 2·slots + 4` (`zk.rs:435`) | 16 base rows | **prover** |

PCS parameters on this side at model width: `log_cols 14, inv_rate 4, 256
column checks` (`hashline/src/bin/hashline.rs:59`), clamped to
`log_n = min(log_cols, log_t + min(log_db, log_fb))` (`zk.rs:2005-2007`), so
16,384 message positions per row, 65,536 encoded, Merkle depth 16, and
`NttTables::new(16)`.

**So a form-E block has nine commitments: seven prover-generated (`A_attn`,
`H_attn`, `M_attn`, `W_ffn`, `A_ffn`, `H_ffn`, `M_ffn`) and two caller-fixed
(`In`, `Out`).** Each is opened exactly once; §C walks it claim by claim.

### A.3 Which hidden plane lives on which commitment

The planes that matter are the ones a relation on one side must read and a
relation on the other side must produce.

| plane | what it is | attention side | feed-forward side | must it cross? |
|---|---|---|---|---|
| `x_in` | the block's hidden input, int16 class | `A_X` = plane 8, `Dom::D` (`layout.rs:112-200`), bound to `In` by slot `SC_IO_IN` (`argument.rs:902-909`) | — | no |
| `xres1` | residual 1's output | `A_X1` = plane 24, `Dom::D`, produced by residual 1 and read by `norm_m` **and** residual 2 | — | no |
| **`nm`** | the second norm's output, **int8**, the feed-forward's input | `A_YM` = plane 27, `Dom::D`, 512 columns at T32/d16, 2 committed rows (`layout.rs:140-141`); produced by `SC_SSM` + the `c6`/`c7` terms of `SC_DZC` (`argument.rs:733-734`); range-pinned as int8 by the symmetric pair `nm + 127`, `127 − nm` (`layout.rs:326`) | must be readable by the gate and up matmuls, i.e. it must equal the v3 layout's `lay.x[c]` for every d-block `c` (`zk.rs:2015`, `:3350`) | **YES — seam 1** |
| `g8, u16, a16, h16` and their remainder limbs | feed-forward interior | absent in form E (the 11 `Dom::F` planes of the built block module, `layout.rs` planes 67-77, do not exist on this side) | `A_ffn`'s f-plane block | no |
| **`z16`** | the feed-forward output, int16 class | `A_Z16` = plane 36, `Dom::D`, 2 rows (`layout.rs:144-145`); read by residual 2 through `c9 = x2 − x1 − z16` (`argument.rs:736`) | `lay.z[c]`, one of the three d-planes per block (`zk.rs:2015`, `:3351`) | **YES — seam 2** |
| `xres2` | the block's hidden output | `A_X2` = plane 37, `Dom::D`, bound to `Out` by `SC_IO_OUT` (`argument.rs:902-909`) | — | no |

Everything else stays put. **Exactly two planes cross, in opposite
directions**: `nm` from the attention side to the feed-forward side, `z16`
back.

### A.4 Where residual 2 lives, and the defence

**Decision: residual 2 lives on the attention side**, with `xres1`, `A_Z16`
and `A_X2`, exactly as the accepted form-S design places it
(`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md` §B.4, decided there for form S and
inherited here; the disposition accepted it, §1.3).

The defence, in four steps.

1. **`xres1` has three consumers and only one of them is the feed-forward.**
   Residual 1 produces it, `norm_m` consumes it, residual 2 adds it
   (`private_block.rs:6-11`). Two of the three are attention-side relations.
   Putting residual 2 on the feed-forward side would send `xres1` across a
   third seam — a plane of the same size as `nm`, in the *wider* int16/int24
   class — for no gain.
2. **It keeps the seam count at two, one per direction.** With residual 2 on
   the attention side the cut is `nm` out, `z16` in, and nothing else. With
   residual 2 on the feed-forward side the cut is `nm` out, `xres1` out, and
   `xres2` is then a feed-forward-side plane, so the block's two external
   endpoints would sit on two different modules' commitments — the input
   endpoint on `A_attn`, the output endpoint on `A_ffn`. That is legal under
   D12 but it duplicates the endpoint machinery (`SC_IO_IN`/`SC_IO_OUT`,
   `check_endpoint_opening` at `private_block/protocol.rs:186-198`, the
   `ExpectedIo` frame) into a module that has none of it.
3. **The arithmetic is already there on the attention side and absent on the
   other.** Residual 2 is `c9 = x2 − x1 − z16` with every shift zero
   (`argument.rs:736`), a single additive term in an existing zero-check, plus
   the int16-class limbs `A_X2L0/A_X2L1`. The v3 layout has no residual
   relation, no class-limb planes for a residual and no norm apparatus
   (`table_specs_v3`, `zk.rs:1941-1944`, is a feed-forward table set).
4. **The alternative "thin block layer" is worse for the same reason it was
   rejected for form S**: a third commitment holding `nm`, `z16` and `xres2`
   would need three or four seams instead of two, its own mask rows,
   proximity pair and slots, and a third commitment in the joint analysis,
   and it has no arithmetic of its own (`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md`
   §B.4 row (c)).

**One consequence worth naming.** With residual 2 on the attention side, the
attention side holds a *copy* of `z16` whose int16 class is proved twice: once
on the feed-forward side (its lookup list covers `z` and `rd`,
`zk.rs:2685-2690`) and once on the attention side by `A_ZL0`/`A_ZL1` and
`c10 = z16 + 32768 − l2(A_ZL0)` (`argument.rs:737-738`). The seam makes the
second redundant. Dropping it saves 4 committed rows and 512 byte lookups at
the tiny geometry; keeping it makes the attention side's statement
self-contained and independent of the seam's correctness. **Recommendation:
keep it** (decision 7 in §I.1) — the cost is negligible and it is the
belt-and-braces version of the one relation that the seam is there to
protect.

### A.5 What the external endpoints are

Exactly two, per D12 item 2: `x_in` and `xres2`, both on the attention side,
both bound by the existing `SC_IO_IN` / `SC_IO_OUT` slots to the two
caller-fixed 7-row `private_seam` commitments (`argument.rs:902-909`;
`private_block.rs:319-354`). They carry the open D8/D11 obligation in full and
this page closes none of it.

**The feed-forward side has no endpoint commitments at all in form E.** This
is the structural point that makes form E legal under D12 item 3: the io
profile that exists today binds `lay.x[0]` and `lay.z[0]` to *caller-fixed*
endpoint commitments (`zk_ffn_fresh_io.rs:284`, `:346`), and D12 item 3
forbids exactly that for a hidden intermediate of a block. In form E the
counterparty of each feed-forward seam is a slice of `A_attn` — a commitment
the **prover** generated inside the same proof.

## B. The seams

### B.1 The building block: the batched multi-block seam, restated

Form E uses, unchanged in form, the masked equality that was designed,
independently attacked and accepted today
(`ZK60_PRIVATE_ENDPOINTS_AT_SCALE.md` §3.3 form 2, §4.1;
`..._CHECK.md`; `..._DISPOSITION.md` R-1 … R-5). Restated as a relation
between two commitments `P` and `Q` holding the same plane:

1. after **every** root of the proof is absorbed, draw
   `tau = challenge_fp2_vec(m)` where `m = log_t + log_db` is the bit width
   of one d-block's cube, and `mu = challenge_fp2_vec(nb_d)`, the batching
   coefficients — `nb_d` fresh transcript draws taken at the point `tau` is
   drawn, never re-derived from `rho` or from the terminals, and **not**
   refused on zero (the endpoints disposition's R-4; `zk_ffn_fresh_io.rs:292`,
   verifier `:385-386`);
2. draw the masking coefficient `c` through `draw_mask_challenge(.., repaired
   = true)`, which **discards the attempt** on `c = 0` rather than resampling
   (`zk_ffn_fresh_poc.rs:221-233`);
3. publish `gamma = c · g_s.total()` for a CFS mask in slot `s`, reserved
   before its masking commitment was built (`zk.rs:2172`);
4. run a masked sumcheck of degree 2 over three tables — `eq_table_msb(tau)`,
   `Σ_c mu_c · P_c` and `Σ_c mu_c · Q_c` — with
   `poly(v) = v[0]·(v[1] − v[2])`, for `m` rounds;
5. add one extension round, refusing a zero extension challenge `e`
   (`zk_ffn_fresh_io.rs:336-338`), which replaces each side's terminal by its
   reserved mask; publish the two masked terminals and the mask evaluation;
6. the verifier checks
   `fin == (1 − e)·eq(tau, rho[..m])·(terminals[0] − terminals[1]) + c·mask_eval`
   (`:389-401`).

Each side contributes **one claim** to its own commitment's single opening:
`nb_d` data parts (one per d-block, coefficient `mu_c·(1−e)`) plus two mask
parts on its own reserved pair with coefficients `e` and `e·U`. All `nb_d + 2`
parts share one column-weight key, which `group_zclaims` already supports
(`zkp-core/src/pcs.rs:809-831`), so the whole thing is **one claim site, one
opening group and one reserved mask pair per side, at every width**.

Soundness: `(m + 2(m+1))/|Fp2|` from the random evaluation point and the
sumcheck, plus `1/|Fp2|` for the batching. §E gives the numbers. **Per D17
and the endpoints disposition's R-1 the batched form is used unconditionally
at every width, including widths
where `nb_d = 1`** — there is no "this width is unaffected" exemption.

### B.2 The two layouts, and why the plane is tiled differently on each side

This is the part of form E that is genuinely new, and it produces one hard
constraint on the attention-side layout at model width. The two provers do not
lay a plane out the same way, and two of the three differences are harmless
while the third is not.

**Difference 1 — columns per committed row. Harmless.** The attention side
uses `LOG_N = 8`, 256 message positions per row
(`private_block/layout.rs:40-49`, `protocol.rs:21-23`); the v3 side at model
width uses `log_n = 14`, 16,384 (`zk.rs:2005-2007`). A claim names a
*contiguous slice* `{offset, log_size}` of a commitment's flat message space
and a point `rho`; `zpart_weights` splits `rho` into a row-weight part and a
column-weight part **according to that commitment's own `n`**
(`zkp-core/src/pcs.rs:752-792`). So the same multilinear evaluation of the
same plane is expressible on two commitments with different column counts,
and neither side needs to know the other's `n`. **What must be fixed in code
is that `claim()` and `mask_value` on the io path are shared between the two
claim sites and hard-code one width** — erratum E-19c of the endpoints check,
change C7 of its list. Form E makes that mandatory rather than tidy, because
in form E the two sides genuinely differ.

**Difference 2 — encoding rate. Not a difference between the two provers
today; a choice that must be made at model width.** [E-8] At the only
geometry where both provers exist the parameters are **identical**: the
attention side runs `log_cols 8 / inv_rate 8 / Q 256`
(`private_block/protocol.rs:21-23`) and so does the feed-forward's io profile
(`zk_ffn_fresh_poc.rs:51-57`). The `log_cols 14 / inv_rate 4 / Q 256` figures
quoted for "the v3 side" are the **binary's defaults**
(`hashline/src/bin/hashline.rs:59-60`), i.e. the model-width driver, which the
io path does not use. So the contrast is between the io profile and the
model-width driver, not between the two provers — but the choice is still
live, because at model width the two halves must agree: two different
per-opening figures make the block's whole-proof soundness a sum over two
conventions, and `check_ntt` differs (`NttTables::new(12)` on the attention
side, `private_block/protocol.rs:276`, `:435`; `new(16)` on the model-width
path).
**Recommendation (decision 2): at model width both sides use the enclosing
`LayerParams` — `log_cols 14 / inv_rate 4 / Q 256` — and one `NttTables` of
log 16, with each side checking it through a `check_ntt_for(max_log)`, as
change C5 of the endpoints list already specifies.** The tiny paths keep their
own frozen constants (D17 item 2).

**Difference 3 — the tiling of the plane along the width axis. NOT harmless.**
The v3 prover cuts the model width into `nb_d` d-blocks of `db = 2^log_db`
columns, with `log_db = min(trailing_zeros(d), 12)`
(`zkp-core/src/ffn_v3/statement.rs:153-156`), and writes each block's plane
token-major: for d-block `c`, the flat index is `(t, i − c·db)` with `t`
major (`zk.rs:2480-2491`, `par_chunks_mut(db)` per token). The attention side
lays a `Dom::D` plane out as a single flat `(t, i)` rectangle with `i` running
over the **whole** width (`private_block/layout.rs:79-80`, the `Dom::D` doc
comment "`(t, i)` (9 vars)"; `:202-214`, cited in the first draft, is
`a_dom()`, the plane→domain map — [E-11], citation only).

Those two are the same ordering only when `nb_d = 1`. When `nb_d > 1`, d-block
`c` of the feed-forward's plane is, as a subset of the attention side's flat
plane, a **strided** selection: the columns `[c·db, (c+1)·db)` of every token.
A PCS claim can only name a contiguous slice, so a strided sub-plane is not
claimable, and the two sides' block-`c` tables would not be the same function
of the sumcheck's cube coordinates.

**The constraint that follows, and it is load-bearing.** Restated here as
ruling **R-3** of the disposition requires, against errata **E-3**, **E-13**
and **E-14**; the first draft's version was both too weak (it named two
planes where the whole family moves) and too strong (it applied "at any
width", where at half the widths nothing has to move at all).

*Where `nb_d` is a power of two — `d = 4096 → 1`, `8192 → 2`, `16384 → 4` —
there is **no re-tiling and no extra draw**.* [E-14] The attention side keeps
`nm` and `z16` as single flat `Dom::D` planes, and the two sides are related
by a **public index map**. Writing the flat index MSB-first as `(t ‖ c ‖ i')`
with `i = c·db + i'`,

```
P̃_flat(ρ_t, ρ_c, ρ_i')  =  Σ_c eq(ρ_c, c) · P̃_c(ρ_t, ρ_i')
```

which is exactly the `mu`-batched right-hand side **with `mu_c := eq(ρ_c, c)`
fixed publicly instead of drawn**. The attention side contributes one claim
over the whole plane at `(ρ_t, ρ_c, ρ_i')`; the feed-forward side contributes
its `nb_d` parts at `(ρ_t, ρ_i')`, all sharing one column key, so
`group_zclaims` still folds them into one group
(`zkp-core/src/pcs.rs:809-831`). The `nb_d` independent `mu` draws disappear
and the soundness term falls to `(log_t + log_d)/|Fp2|`. The masked sumcheck
and the extension round are still required — two terminals blinded by
*different* commitments' mask pairs cannot be compared directly — but the
cube and the attention side's tiling are free parameters this map fixes
cheaply.

*Where `nb_d` is **not** a power of two — 768 → 3, 2560 → 5, 3072 → 3,
5120 → 5, 6144 → 3, 12288 → 3 — the **whole `Dom::D` family re-tiles
together**.* [E-3] Not `nm` and `z16` alone: they are never read alone. They
appear inside a single pointwise expression of the `Dom::D` zero-check,
alongside planes that would otherwise stay flat —

```
c6  = k_num·igm·x1 + k_dv·dm − k_den·nm·dm − mr
c9  = x2 − x1 − z16
c10 = z16 + 32768 − l2(A_ZL0)
```

(`private_block/argument.rs:731-737`) — evaluated at **one** point of **one**
cube over the slice family `a_range(A_X, A_RDL)` (`:709`), and a sumcheck has
one variable set. A term cannot mix a plane on a `2^(log_t+log_db)` cube with
a plane on a `2^(log_t+log_d)` cube, so a `Dom::Db` domain carrying `nb_d`
planes for `nm` and `nb_d` for `z16` "in place of one `Dom::D` plane each" —
the first draft's wording — does not type-check. The constraint reads:

> At any width where `nb_d` is not a power of two, the **whole `Dom::D`
> family** adopts the feed-forward's d-block tiling together — all 35 A
> planes `A_X..=A_RDL` (`layout.rs:126-152`, `a_dom` at `:207`), all 19
> `Dom::D` LogUp helper planes (`layout.rs:224-225`, `:245`), the two public
> per-column vectors `gamma_a`/`gamma_m`, which are indexed `x % D`
> (`argument.rs:706-707`) and so need one public slice per block — **the
> public-statement digest moves** — and the `Dom::D` zero-check itself,
> batched over the `nb_d` blocks with fresh public coefficients.

**And where it applies it does not cost nothing.** [E-13] `a_range(A_X,
A_RDL)` sweeps 35 **different planes at one point**, not sub-planes of one
plane, so tiling multiplies the slice count by `nb_d`: at `nb_d = 3` the
`Dom::D` zero-check reads **105** A slices instead of 35, publishes `nb_d`×
the terminals and therefore needs `nb_d`× the claim sites and `nb_d`× the
reserved pairs. `A_SITES` gives that slot 37 sites today (`layout.rs:512`);
at `nb_d = 3` it becomes ≈ 107, i.e. **≈ +70 claim sites and ≈ +140 committed
rows on `A_attn`**, plus the same multiplication on the 19 `Dom::D` helpers
of `H_attn`. It is one sumcheck and one slot only if the `nb_d` blocks are
batched with fresh public coefficients — a change to the zero-check, not a
free relabelling. **§D.1 and §G.2 must carry that multiplication wherever
`nb_d > 1`, and at the 125M shape (`nb_d = 3`) they do not yet.**

What survives of the first draft's cost argument is the *relative* claim, and
it is worth keeping: the attention side's domains are power-of-two cubes
(`rows_of`, `layout.rs:537-539`) and `T·d` is not a power of two at 125M
(512 × 768 = 393,216), so at any such width the attention side must tile
**somehow** and adopting the feed-forward's tiling costs nothing **over the
alternatives** — which is a different claim from "costs nothing". At Mistral
(`nb_d = 1`, 512 × 4096 = 2^21) the constraint is vacuous.

**A cross-check the design must survive.** The MLE variable order is MSB-first
over the flat index within the slice (`eq_table_msb`), so "same flat order"
means the same bit order of `(t, i')`, not merely the same set of words.
Getting this wrong produces a permuted plane that still satisfies the equality
at no point but `tau` — i.e. it fails loudly, not silently. §H's step 3 is the
test that pins it.

### B.3 The `nm` seam, exactly

**Relation.** For every d-block `c ∈ [0, nb_d)`, as multilinear extensions over
the `m = log_t + log_db`-variable cube in Fp2,

```
Σ_c mu_c · A_attn[ nm_c ](x)   ==   Σ_c mu_c · A_ffn[ lay.x[c] ](x)   at x = tau
```

masked throughout, with one extension round.

**Which slice of which commitment.**

| side | commitment | slice | class proof that travels with it |
|---|---|---|---|
| left | `A_attn` (prover-generated) | the single flat `nm` plane at the index map's point where `nb_d` is a power of two, else the `nb_d` contiguous sub-planes of the re-tiled `Dom::D` family (today one plane `A_YM`, `layout.rs:140-141`; both cases under §B.2 as restated by R-3) | int8: the symmetric pair `nm + 127`, `127 − nm` in the U8 table (`layout.rs:326`), which is **D12 item 4** discharged |
| right | `A_ffn` (prover-generated) | `lay.x[c]` for each `c`, the d-plane the v3 layout allocates at `statement.rs:159-164` and claims at `zk.rs:3350` | none — the feed-forward prover proves **no** range on its input plane (`zk.rs:2685-2690`; the lookup list covers `g8/a16`, `u16`, `h16` and `z`/`rd`, never `lay.x`) |

**This asymmetry is the whole point of D12 item 4.** The feed-forward's input
is unranged; the seam plus the attention side's int8 proof is what stops a
composed statement admitting an out-of-class feed-forward input. Write it
down as an invariant: *the seam is the only thing that gives `lay.x` a class,
so a form-E block whose `nm` seam is removed or weakened is not merely
unbound, it is unsound in the integer model.*

**The copied-plane defence.** The seam must bind the **actual arithmetic
plane**, not a copy: the right-hand slice must be exactly `lay.x[c]`, the
plane the gate and up matmul relations read (`zk.rs:2016`, `a_mgu[c]`, and
`zk.rs:3360`), and the left-hand slice exactly the plane `SC_SSM` and the
`c6`/`c7` terms produce. FA3 §12.1 already writes this as a refusal — "any
slice != `lay.x[c]` / `lay.z[c]`" (`ZK60_FABLE_MASK_REPAIR.md:605-609`, quoted
in `ZK60_OPUS_SEAM_REVIEW.md` §6.1) — and `ZK60_PENDING_FFN.md:25-28` states
why: "A proof about copied X/Z planes needs a further consistency relation to
the actual arithmetic commitment and is **not an acceptable substitute**."

**Scales.** Field-word equality is not represented-value equality
(`private_seam.rs:41-42`; `ZK60_PRIVATE_BLOCK.md:143-146`). Both sides'
declared scale for this plane must be the calibration's, pinned by a
constructor refusal and absorbed with the statement (D12 item 5; the block
module already absorbs `b"calibration"`,
`private_block/protocol.rs:35`). The pairing is `AttnConsts.e_xm ==
V3Exps.e_x` (`ZK60_PENDING_FFN.md:61`).

### B.4 The `z16` seam, exactly

Identical in form, opposite in direction.

```
Σ_c mu'_c · A_ffn[ lay.z[c] ](x)   ==   Σ_c mu'_c · A_attn[ z16_c ](x)   at x = tau'
```

| side | commitment | slice | class proof |
|---|---|---|---|
| left | `A_ffn` | `lay.z[c]`, claimed at `zk.rs:3351` | int16: `z` and `rd` are in the v3 lookup list (`zk.rs:2685-2690`) |
| right | `A_attn` | the `nb_d` sub-planes of `z16` (today `A_Z16`, plane 36, `layout.rs:144-145`) | int16 again, by `A_ZL0`/`A_ZL1` and `c10` (`argument.rs:737-738`) — redundant with the left side's, kept per §A.4 |

`z16` is then consumed by residual 2 on the attention side,
`c9 = x2 − x1 − z16` (`argument.rs:736`), and `xres2` is bound to the output
endpoint. Scale pairing: FFN `e_z16 == FullConsts.e_z16`
(`ZK60_PENDING_FFN.md:62`).

The two seams draw **independent** challenge vectors (`tau`, `mu`, `c`, `e`
and `tau'`, `mu'`, `c'`, `e'`) at different transcript positions, so their
opening groups have different column tails and never merge.

### B.5 Claim sites, reserved pairs, slots, and which `M` carries them

Per seam, per side: **one claim site, one reserved mask pair (two committed
rows of that side's own `A`), one opening group.** Per seam, once: **one CFS
slot** in one masking commitment. Two seams, so:

| where | added | why exactly this |
|---|---:|---|
| `A_attn` rows | **+4** (2 pairs) | one pair per claim site is the rule the module already enforces: `audit_claims` refuses "a reserved pair is unused or shared between claims" and "a claim does not carry exactly its own reserved pair" (`private_block/protocol.rs:89-133`) |
| `A_attn` claim sites | **+2** | `A_SITES` 120 → 122 at the tiny geometry; the schedule digest moves, which is why form E is a new profile |
| `A_attn` opening groups | **+2** | the two seam points have fresh challenge tails, and grouping is first-occurrence by column tail (`zkp-core/src/pcs.rs:809-831`); `A_GROUPS` 35 → 37 at the tiny geometry (`layout.rs:516`) |
| `A_ffn` rows | **+4** (2 pairs) | `ZkLayoutV3::with_io` already does exactly this: `a_io = Some([first, first + 2])`, `a_len += 4·a_n`, and the pairs join `a_mask_rows()` so the repaired rank test covers them (`zk.rs:2057-2063`, `:2090`) |
| `A_ffn` claim sites | **+2** | 26 → 28 at 125M, 66 → 68 at Mistral (`8·nb_f + 4·nb_d + 6`, plus 2) |
| `A_ffn` opening groups | **+2** | 5 → 7 (`zk_ffn_fresh_wire.rs:43` → `:231-232`) |
| `M_ffn` slots | **+2** | `mask_specs_v3` already reserves them at `FIRST_IO_SLOT = 6` and `7`, spec `(log_t + log_db + 1, 2)` (`zk.rs:2172`; `zk_ffn_fresh_io.rs:14`) |
| `M_ffn` base rows | **16 → 20** | `n_base = 2·masks.len() + 4` (`zk.rs:435`): `2·6 + 4 = 16` → `2·8 + 4 = 20`. **This re-derives the construction memo's claim; it is correct.** |
| `M_attn` | **unchanged** | 50 rows, 23 slots |
| `H_attn`, `H_ffn`, `W_ffn` | **unchanged** | no seam claim touches them |

**Which `M` carries the seam slots: the feed-forward's.** Reasons, in order:
(a) the reservation already exists there in committed code and needs no new
mechanism — `mask_specs_v3` reserves slots 6 and 7 before `M` is committed,
and `zk_ffn_fresh_io.rs:279-280` states the invariant ("Slots 6 and 7 already
belong to the FFN M absorbed before its challenges. No new randomness or
commitment can be introduced during finalization"); (b) the seam's arity is
the feed-forward's cube arity `log_t + log_db + 1`, which the feed-forward's
spec function already computes; (c) the attention `M` keeps its 23-slot
schedule digest, so the attention-side change is only `+4 A` rows and `+2`
sites. The alternative — both slots on `M_attn`, 50 → 54 rows — is equally
sound and is listed as decision 3, not a finding.

**What the counterparty side must have, and it is a build precondition, not
hygiene** [C-1, ruling R-5]. The attention side needs **no seam slot of its
own** — the CFS slot masks the *argument's round messages*, which belong to
neither commitment, and the committed io profile's counterparty is a 7-row
plane with no masking commitment at all and the seam works. What it must have
is a **reserved mask pair per seam claim on `A_attn`**, and the cost of
omitting it is now measured rather than argued: in the check's small model
(§D.6, case 15) a counterparty seam claim carrying **no** reserved pair
discloses **8 Fp** — the plane in the clear at the seam point, column by
column. Two seams sharing one pair on one side (case 16) also discloses
**8 Fp**; `audit_claims` catches that on `A_attn`
(`private_block/protocol.rs:129-131`) and **nothing catches it on `A_ffn`**
(`check_masks` tests only the Fp2 span, `zk_ffn_fresh_poc.rs:253-321`).
Ruling R-5 therefore makes two things preconditions of the build, not
follow-ups: each side's seam claim carries its own reserved pair, and
`audit_claims` is ported to the feed-forward's claim path **before** any
external claim is pushed onto `A_ffn` (decision 6, §H step 1).

**The slot bound holds with room.** `L = CfsMask::len(n_vars, degree) =
n_vars·degree + 2` (`zkp-core/src/sumcheck.rs:197-199`) and `mask_commit`
asserts `L + MASK_Q ≤ 512` with `MASK_Q = 256` (`zk.rs:373-375`, `:442`):

| shape | seam `(n_vars, degree)` | `L` | `L + 256` | largest slot on that `M` |
|---|---|---:|---:|---|
| tiny T32/d16 | (10, 2) | 22 | 278 | `SC_TAB` (17,3), `L = 53` |
| 125M, `nb_d = 3` | (18, 2) | 38 | 294 | zero-check **F** `(log_t + log_fb + 1, 4) = (21, 4)`, `L = 86` (`zk.rs:2162`; `log_fb = min(tz(2048), 12) = 11`) [E-7] |
| Mistral, `nb_d = 1` | (22, 2) | 46 | 302 | zero-check D (22,4), `L = 90` |

All inside 256 (the largest entry, `86 + 256 = 342 ≤ 512`), and the seam is
never the binding slot. The real ceiling is
not the assert but the `1u64 << n_vars` overflow in **two** places of
`CfsMask` — `sum_weights` (`zkp-core/src/sumcheck.rs:223-224`) and `round`
(`:266`) — binding at `n_vars = 62`; per erratum E-19d the guard belongs in
the `CfsMask` type itself.

### B.6 The transcript order, label by label

The condition that shapes everything: **every root of both sides must be
absorbed before any seam coefficient or challenge is drawn** (FA3 §2.3 item 4,
`ZK60_FABLE_MASK_REPAIR.md:135-137`, and item 6's prohibition on attaching a
claim at a point not drawn after the target commitment's root,
`:145-147`). Because each side's `H` holds LogUp helpers that depend on that
side's `β, γ, α`, and those are drawn after that side's `A` and `M`, the two
sides' commit phases must interleave *somehow*. **The first draft asked for
both `A`s and both `M`s before ONE shared triple. That is not reachable**
[E-5]: `prepare_layer_zk_v3_inner` absorbs `W` (`zk.rs:2471`), `A`
(`:2542`) and `M` (`:2550`), **then draws `β, γ, α` (`:2554-2556`)**, then
builds and absorbs `H`, in one contiguous body with no insertion point, and
its four 12 × 512 digests are frozen. Splitting it at `zk.rs:2553` would be a
change to the prover, not to a wrapper.

**Ruling R-1 of the disposition settles it: two lookup-challenge triples, and
the frozen function is NOT split.** Under D17 accepted paths stay frozen and
everything new is additive, so the order is

```
A-attn, M-attn │ [ W-ffn, A-ffn, M-ffn, (β,γ,α)_ffn, H-ffn ] │ (β,γ,α)_attn, H-attn
```

then both sides' arguments, then the seams, then the openings in a reachable
order (E-9, below). Each side's triple is still drawn only after that side's
own `A` and `M` are absorbed, which is all LogUp needs; the seam coefficients
are still drawn after **every** root. The bracketed middle is
`prepare_layer_zk_v3_inner` run end to end, untouched. The interleaving is
carried entirely by the attention side's copy — which form E grows from a
copy anyway (ruling R-A) — and it makes that copy a three-part lifecycle:
commit `A` and `M`; pause; draw its own triple, commit `H`, run its slots.
**This reverses the first draft's decision 4**, which asked for one triple.

**Ruling R-6 (security owner, 2026-09-19, after the revision; found by the
errata editor).** The revised order first listed the feed-forward's statement
absorb as step 7, before the attention roots. That position is unreachable:
`absorb_statement_v3` is called at `zk.rs:2364`, inside
`prepare_layer_zk_v3_inner` (which begins at `zk.rs:2337`), and R-1 forbids
splitting that function. It therefore happens at step 9a, after `A-attn` and
`M-attn` are absorbed. That is sound on one condition, which becomes a build
requirement with a test that can fail: **the wrapper's step-3 public-statement
digest covers the exact `StatementV3` bytes that step 9a will absorb**, so the
attention commitments are bound to the feed-forward statement before they are
made, and every challenge on either side is still drawn after both absorbs.
The test: a verifier given a block statement whose step-3 digest and whose
feed-forward statement disagree must reject.

```
  1  Transcript::new("hashline-zk-mr1/private-block-formE-<geom>/1")     NEW profile string
  2  absorb  "expected-IO"        <- ExpectedIo::to_bytes()   (context digest, two scales,
                                     the In and Out roots)          private_block.rs:336-345
  3  absorb  "public-statement"   <- ONE digest over attention words, gamma_a, gamma_m,
                                     Wg/Wu/Wd identity, RoPE/exp/act tables
  4  absorb  "parameters"         <- T, d, f, heads, head dim, log_cols, inv_rate, Q,
                                     nb_d, nb_f, the five shifts, "P1",
                                     "two-private-endpoints/one-proof-one-transcript/form-E"
  5  absorb  "calibration"        <- the calibration identity digest   private_block.rs:94-96
  6  absorb  "schedule-attn"      <- the attention layout's schedule digest  layout.rs:678-686
  7  (moved by ruling R-6, below: the feed-forward's own statement absorb cannot sit
      here — it is the first act of the unsplit frozen function, step 9a. What binds
      the attention roots to the feed-forward statement is step 3, whose digest MUST
      cover the exact StatementV3 bytes that step 9a will absorb.)
  8  absorb  "A-attn"  <- a_root_attn ; "rows" ; "log-cols"            protocol.rs:316-320
  9  absorb  "M-attn"  <- mask_root_attn                               protocol.rs:324-326
     ---- the attention side pauses here; the frozen feed-forward prepare
          now runs end to end, byte-contiguous and unsplit ----
  9a absorb  the feed-forward statement <- absorb_statement_v3 + the zk mode header,
                          inside prepare_layer_zk_v3_inner, where it already is
                                                                       zk.rs:2364, :2368
 10  absorb  "W-ffn"   <- w_root                                       zk.rs:2468-2471
 11  absorb  "A-ffn"   <- a_root_ffn  ; "rows"   (root and ROWS only: absorb_com does
                          NOT absorb log_cols, statement.rs:199-202; log_cols is bound
                          through step 4's "parameters" absorb)        zk.rs:2536-2542
 12  absorb  "M-ffn"   <- mask_root_ffn                                zk.rs:2550
 13  challenge beta_ffn ; gamma_ffn ; alpha_ffn      (the FEED-FORWARD's triple)
                                                                       zk.rs:2554-2556
 14  absorb  "H-ffn"   <- h_root_ffn                                   zk.rs:2700-2708
     ---- end of prepare_layer_zk_v3_inner; the attention side resumes ----
 15  challenge beta_attn ; gamma_attn ; alpha_attn   (the ATTENTION triple)
     side tags: g_u8 = gamma_attn*TAG_U8, g_exp = gamma_attn*TAG_EXP,
                g_act = gamma_attn*TAG_ACT                             protocol.rs:330-335
 16  absorb  "H-attn"  <- h_root_attn ; "rows" ; "log-cols"            protocol.rs:373-377
     ---- every commitment that the seams will touch now has a public root ----
 17  the attention side's slot loop, slots 0 .. N-1, unchanged in shape
        (define -> "slot NN begin" -> c_s (zero refused) -> scalar -> rounds
         -> extension -> terminals)                                    argument.rs:270-350
 18  the feed-forward side's six arguments in the legacy order
        (gu, d, zero-check F, zero-check D, table, zero-sum)            zk.rs:2720-3172
 19  SEAM 1 (nm):   absorb "seam" <- 0 ; tau, mu (nb_d draws) ; c (zero DISCARDS the attempt)
                    ; publish gamma_seam ; m masked rounds ; extension challenge e
                    (zero rejected) ; two masked terminals ; the mask evaluation
 20  SEAM 2 (z16):  the same with index 1
     ---- the openings, in a REACHABLE order (E-9) ----
 21  mask_open(M-attn)   ; drop M-attn                                  protocol.rs:392-393
 22  PendingV3::finish, ONE atomic call that consumes self:             zk.rs:2307-2334
        mask_open(M-ffn) ; open(W-ffn) [P1, plain] or open_zk(W-ffn) [P3, hiding] ;
        open_zk(A-ffn) ; open_zk(H-ffn) — each ONCE, each dropped
 23  check_opening(A-attn) ; ONE open_zk(A-attn) ; drop                 protocol.rs:396-398
 24  check_opening(H-attn) ; ONE open_zk(H-attn) ; drop   (its claim list ends with the
                                                           value-0 LogUp sum claim)
 25  check_endpoint_opening(In)  ; ONE open_zk(In)  ; drop              protocol.rs:402-407
 26  check_endpoint_opening(Out) ; ONE open_zk(Out) ; drop
```

Six points about this order.

* **Steps 8–16 are the restructuring, and they are all on the attention
  side.** No code today absorbs two provers' roots into one transcript.
  Everything else in the list is an existing sequence with a relabelled
  payload, and the feed-forward's contiguous commit body is used exactly as
  it stands.
* **The openings are in a reachable order** [E-9]. The first draft ordered
  them `M-attn, M-ffn, A-attn, H-attn, W/A/H-ffn` with two separate steps
  citing `zk.rs:2307-2334`. That is one function: `PendingV3::finish`
  performs `mask_open(M_ffn)`, `W`, `A_ffn`, `H_ffn` **contiguously and
  atomically**, consuming `self`, so the listed order was unreachable
  without splitting `finish` too. Any fixed order is sound; step 22 above
  names one that exists (it is the io profile's own shape,
  `zk_ffn_fresh_io.rs:356` then `:357-362`).
* **Domain separation between the two halves is an obligation here, not a
  property.** In form S there is one component, so there is nothing to
  separate (`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md` §D). In form E a component
  tag must be absorbed before each root — `"A-attn"`, `"M-attn"`, `"H-attn"`
  against `"A-ffn"`, `"M-ffn"`, `"H-ffn"` — and the seam slots need their own
  index namespace, exactly as the seam review records ("If form (E) is built
  instead … a component tag must be absorbed before each root … None of that
  exists"). Steps 8–16 above do it. The collision the tag prevents is
  concrete: `absorb_com` absorbs a root under its label
  (`statement.rs:199-202`), the feed-forward absorbs its `A` under `b"A"`
  (`zk.rs:2542`) and the attention side absorbs its `A` under `b"A"` too
  (`protocol.rs:40`, called at `:320`) — **in a shared transcript the two
  sides' `A` roots would be absorbed under the identical label.**
* **Two `(β, γ, α)` triples, per ruling R-1** — steps 13 and 15 — because one
  shared triple is unreachable without splitting a frozen prover (above).
  Soundness is unaffected: the two sides' LogUp identities are separate
  zero-sum claims on separate `H` commitments, so no row of one can cancel a
  row of the other, and each triple follows its own side's `A` and `M`.
* **The tag sets are already disjoint, and the audit becomes an assertion**
  [C-7]. `tables_attn.rs:29` records the namespaces in writing — attention
  `TAG_U16 128, TAG_EXP 129, TAG_PROB 130, TAG_INT8A 131, TAG_INT16A 132,
  TAG_U8 133, TAG_ACT 134` against the feed-forward's `TAG_ACT16 3,
  TAG_INT16 4` and `tag_rem_v3(sh) ∈ 64..=88` — and `:73-76` spells out that
  `TAG_ACT = 134` "must NOT reuse the FFN statement's `TAG_ACT16 = 3`". So
  the injectivity the first draft asked for as an audit is already true by
  construction; what form E owes is to turn the comment into an **assertion**
  over both halves' tag sets, and to **count the cross-side collision term
  once** in §E (≈ `2^41/2^128`, negligible but unnamed until now).
* **Steps 19–20 could equally sit before step 17.** Any position after step 16
  and before step 21 satisfies the ordering condition. Putting them after both
  sides' arguments matches the one implementation that exists
  (`zk_ffn_fresh_io.rs` runs the seam arguments at `:290-355`, then calls
  `PendingV3::finish` at `:356`, then opens the endpoints at `:357-362`).

### B.7 The PREPARE / FINISH split: what exists, what must be restructured, what cannot be

**More exists than the construction memo credited, and it is the single
strongest argument for form E's feasibility.**

**What exists on the feed-forward side.**

* `prepare_layer_zk_v3_inner(w, t_rows, params, ntt, cfg, tr: &mut Transcript,
  mr1, io, rng) -> Result<PendingV3, String>` (`zk.rs:2337`) **already takes
  the transcript by mutable reference**. It runs every commit and every
  sumcheck and returns `PendingV3` (`zk.rs:2292-2305`), which holds the
  proof-so-far, the layout, the mask commitment `mc`, the functional list
  `fs`, the live `CommittedZk` handles for `A` and `H`, the weight handle, and
  the claim vectors `ac` / `hc`.
* `PendingV3::finish(self, ntt, tr) -> ProveOutputZk` (`zk.rs:2307-2334`) does
  **only** the openings: `mask_open(M)`, then `W`, `A`, `H`, each opened once
  and dropped. `prove_layer_zk_v3` is literally `prepare(..)?.finish(..)`
  (`zk.rs:2279-2285`).
* The reservation machinery for exactly two seam mask pairs and exactly two
  seam CFS slots is committed code: `ZkLayoutV3::with_io` (`zk.rs:2057-2063`)
  and `mask_specs_v3`'s slots 6 and 7 (`zk.rs:2172`).
* A **working interleaving precedent**: `zk_ffn_fresh_io::prepare -> PendingProof
  { pending: PendingV3, tr: Transcript, expected: ExpectedIo }`
  (`zk_ffn_fresh_io.rs:132-136`, `:148-181`), whose `finish` runs two extra
  masked sumchecks **against another party's `pcs::CommittedZk`** before
  calling `self.pending.finish(&ntt, &mut self.tr)` at `:356`.
* And a **verifier-side seam hook already in the signature**:
  `verify_layer_zk_v3_with_seams(st, proof, params, ntt, tr, mode, mr1, io,
  before_openings: impl FnOnce(&ZkLayoutV3, &mut Vec<ZClaim>, &mut
  Vec<MaskFunctional>, &mut Transcript) -> Result<(), String>)`
  (`zk.rs:3471-3472`). A caller can push seam claims and mask functionals and
  touch the transcript before the openings happen. This is precisely the shape
  form E needs.

**What must be restructured.**

| # | change | where | note |
|---|---|---|---|
| R1 | the feed-forward side must accept an **outer** transcript, not build one. `zk_ffn_fresh_io::prepare` constructs `Transcript::new(PROFILE)` internally (`transcript(expected)`, called at `:163`) and `fresh_poc::transcript` does the same (`zk_ffn_fresh_poc.rs:75-83`) | a new block-owned entry beside them, **declared inside `hashline::zk`** (R-4, below) | the inner `prepare_layer_zk_v3_inner` already takes `&mut Transcript`, so *passing the transcript in* is a wrapper change. **It is a wrapper change only because R-1 takes two lookup triples** [E-5]: the first draft's single shared triple would have required splitting that frozen function at `zk.rs:2553`, which is a prover change. With R-1's order the frozen body is called as it stands |
| R2 | the seam's counterparty must become **a slice of a large commitment**, not a 7-row endpoint plane. `claim(0, 2, rho, e, terminals[1])` (`zk_ffn_fresh_io.rs:346`) hard-codes offset 0 and mask rows 2/3, the endpoint geometry; and `claim()`/`mask_value` (`:201-235`) hard-code one `log_n` for both sides | the new block seam module | this is erratum E-19c (per-commitment `log_n`) plus a parameterised offset |
| R3 | the attention side must be **split into prepare and finish** — and under R-1 into three parts, because its own `(β, γ, α)` is drawn only after the feed-forward's block (steps 8-9, pause, 15-17). `private_block/protocol.rs:258`, `prove_inner(blk, wit, expected, endpoints) -> (Receipt, ProveStats)`, is one monolithic function: it creates the transcript at `:29-38`, commits `A`, `M`, `H`, runs all 23 slots, opens everything at `:392-407` and drops every owner. A `prepare` must stop after step 17 above, hold the live `CommittedZk` handles, the mask commit, the functional list and the claim vectors, and a `finish` must do the openings | a new block module grown from a copy, per ruling R-A, **inside `hashline::zk`** (R-4) | this is the same shape `PendingV3` / `PendingProof` already has on the other side. The split with nothing between the parts leaves the transcript byte-identical — a refactor; what makes form E a protocol change is the new profile, digest and counts |
| R4 | the attention side must reserve **two extra mask pairs** on `A_attn` before its `A` commit, and accept **two externally pushed claims** before `check_opening` | the new module's layout + protocol | `audit_claims` (`protocol.rs:89-133`) then covers them automatically: it re-derives that every reserved pair is used by exactly one claim |
| R5 | the two sides' **NTT tables and PCS parameters** must be reconciled (§B.2 difference 2) | the block statement | `NttTables::new(12)` vs `new(16)` |
| R6 | a **composed wire frame**. `zk_ffn_fresh_wire.rs` is not extensible: `TERMINALS: [usize; 6]` zipped over exactly six arguments (`:10`, `:74-83`), and a binding digest with no field for a peer root, slice, role or scale (`:144-159`). **Two of the five constants the first draft named were wrong** [E-15]: the `M` check is `c.len() != self.mask_rows`, computed, not `!= 16` (`:129-137`, and `io_shape` already adds the 4 io rows), and the `A` check is `self.a_groups`, not a hard-coded 5 (`:101-108`; `io_shape` already sets 7) — the hard-coded **5** is on **`H`**. The frame's real model-width blockers are `groups(.., 512)`, `p.len() == 11`, `*j < 2048` and `p.len() != 12`, all frozen to `log_cols 8 / inv_rate 8` | a new frame | the frame must carry two `A` openings, two `H` openings, two `M` openings and the two seam arguments, and bind both statements |
| R7 | a **role manifest**, because form E adds the one role class the existing audits cannot see by position: a seam role that is never consumed, or consumed twice, on either side. `audit_claims` is positional, not named (`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md` §E); on the v3 side nothing marks a seam role consumed at all (U-3) | both sides | §E of the construction memo specifies the `RoleSet`; form E is the first construction that actually needs it |

**Where the module lives, and three conditions on it — ruling R-4.** The
first draft never said where the new module may go, and there is only one
place it can.

* **Inside `hashline::zk`** [C-4]. `PendingV3` is declared with no `pub`
  (`zk.rs:2292`), its fields are private, and so are
  `prepare_layer_zk_v3_inner` (`zk.rs:2337`) and
  `verify_layer_zk_v3_with_seams` (`zk.rs:3471`). The io profile reaches them
  only because it is a **descendant** module — `lib.rs:35 pub mod zk` →
  `zk.rs:4184 pub mod fresh_poc` → `zk_ffn_fresh_poc.rs:15 pub mod io` —
  while `private_block` is a **sibling** (`lib.rs:51`). Declared inside `zk`,
  form E's module can still reach `private_block`'s `pub(crate)` items
  (`prove_inner`, `audit_claims`, `check_opening`, `transcript`,
  `pcs_params`). The alternative — making those four items `pub` — widens a
  frozen prover's API and **is refused**.
* **Every seam claim stays on `A`** [C-5]. The existing verifier hook
  `before_openings` exposes `ac` but **not** `hc` (`zk.rs:3471-3472`), so a
  seam claim on `H` would change the hook's signature, which touches a frozen
  verifier. Both seams of §B.3 and §B.4 are `A`-to-`A`, so this costs
  nothing — it is a constraint on future seams.
* **The two `mask_open` calls draw two separate θ, and their functional lists
  must never be mixed** [C-6]. `mask_open` draws its own θ (`zk.rs:515`) at
  each of the two transcript positions (steps 21 and 22 of §B.6). The
  `MaskFunctional` lists of `M_attn` and `M_ffn` are per-commitment and index
  into that commitment's own spec vector; mixing them would make
  `combined_weights` silently index the wrong spec (`zk.rs:470-487`).
  **There is no check for that today**, and R-4 requires one.

**What cannot be restructured, and must simply be accepted.**

1. **Both sides' commitments are resident at once.** Each side's `A`, `H` and
   `M` must survive until its single opening at steps 21–26, and the seams at
   19–20 need both `A`s live. Form E does **not** reduce peak residency
   relative to form S; what it buys is the GPU prover, not memory
   (`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md` §B.1, "Honest counterweight").
   §G.4 and §F give the numbers.
2. **Every mask row must be drawn before its own commitment, and every CFS
   slot before its own `M`.** The three cuts on the v3 side are
   `pcs::commit_zk_owned` for `A` (`zk.rs:2537`, after which no row of `A` can
   be written), `mask_commit` (`zk.rs:2548`, after which no eighth slot
   can be added) and the `H` commit (`zk.rs:2702`, the last RNG use); the
   attention side's are `protocol.rs:316` and `:324`
   (`ZK60_OPUS_SEAM_REVIEW.md` §5.2). [E-17 — the substance is right; all five
   citations in the first draft were early by ≈ 70 / ≈ 20 lines.] A seam claim
   raised later is impossible, not merely forbidden.
3. **No side may finish its own transcript.** `ZK60_PENDING_FFN.md:11-12`:
   `prove_layer_zk_v3` "has already opened W, A and H and dropped their
   committed states", and `:151`: "Do not fork/clone a completed transcript to
   add extra private openings." Form E must call `prepare`, never `prove`.
4. **The frozen tiny paths are not edited** (D17 item 2, the endpoints
   disposition's R-2). The
   `/2` io profile, `SeamSpec` and its four constants, `params()`, `digest()`
   and `check_ntt` stay byte-identical; everything in this section is a new
   entry point beside them.

## C. Why this is not the forbidden configuration

### C.1 The rule, quoted

D12, items 1 and 3 (`ZK60_DECISIONS.md`):

> 1. **No commitment is opened more than once, anywhere in a composed block.**
>    The double-opening configuration of
>    `ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md` is not permitted as a seam,
>    as a convenience, or as a test shortcut that could be mistaken for one.
> 3. **Hidden intermediates never get a caller-fixed endpoint commitment shared
>    by two proofs.** `xres1`, `nm` and `z16` live only on commitments the
>    prover generates inside that one proof.

The thing being forbidden is concrete, not theoretical: at the actual endpoint
geometry (7 rows of 256 columns) **two openings of one commitment recover all
512 hidden words**, by cancelling the fixed terminal mask between the two
published group vectors (D11;
`ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md`). The joint-view gate's small
model reproduces the shape of it: the control "the commitment opened twice"
disclosed **10** dimensions where the honest case disclosed 0
(`ZK60_NATIVE_JOINT_VIEW.md` §6).

### C.2 Claim by claim: every commitment, every opening

| commitment | claims on it | opened | where |
|---|---|---:|---|
| `A_attn` | 120 existing claim sites (`A_SITES`, `layout.rs:512`) **+ 2 seam claims**, one per seam, each a batch of `nb_d` data parts plus its own reserved pair | **once** | step 23, `pcs::open_zk`, then dropped (`private_block/protocol.rs:396-398`) |
| `H_attn` | 51 sites plus the value-0 LogUp sum claim (`finish_claims`, `protocol.rs:178-182`) | **once** | step 24, then dropped |
| `M_attn` | 34 functionals, one θ | **once** | step 21, `zk::mask_open` (`protocol.rs:392-393`) |
| `W_ffn` | the weight-block terminals | **once, in BOTH modes** [E-6]: plainly under P1 (`pcs::open`, `zk.rs:2314`), hidingly under P3 (`pcs::open_zk`, `:2318`). The first draft said "not opened (P1)"; that is refuted. The count of nine openings per block is unchanged | step 22 (`zk.rs:2307-2334`) |
| `A_ffn` | 26 sites at 125M / 66 at Mistral **+ 2 seam claims** | **once** | step 22 |
| `H_ffn` | its helper sites plus its zero-sum claim | **once** | step 22 |
| `M_ffn` | 6 functionals **+ 2 seam mask functionals**, one θ | **once** | step 22 |
| `In` | one claim from `SC_IO_IN` (`argument.rs:902-909`) | **once** | step 25, then dropped (`protocol.rs:402-407`) |
| `Out` | one claim from `SC_IO_OUT` | **once** | step 26 |

**The seam claims ride each side's single batched opening.** That is the whole
mechanism and it is what the accepted endpoints construction already does:
the two seam claims are pushed onto the claim vector before `open_zk`, and
`group_zclaims` folds each into one column-weight group
(`zkp-core/src/pcs.rs:809-831`); the endpoints memo records it as "**2** — one
per side … inside the FFN's own single `open_zk`" (§1.4). Nothing in form E
opens anything a second time, and nothing opens a commitment outside the one
transcript.

Two structural guarantees back this, both in code today rather than in
prose:

* **Move semantics.** Every committed owner is taken by value and dropped
  immediately after its one opening, on the success path *and* on every `?`
  path — `protocol.rs:396-407` on the attention side; on the v3 side the
  guarantee is `PendingV3::finish(mut self, ..)` owning `mc`, `a` and `h` and
  dropping them at `zk.rs:2310`, `:2326`, `:2331`, or dropping `self` on a `?`
  [E-18 — the first draft cited `zk.rs:3219-3226`, which is function 2's
  predicate tables]; `Endpoints` is consumed by value so a second proof does not
  type-check (`private_block.rs:360-370`, pinned by a `compile_fail` doctest
  on the io path at `zk_ffn_fresh_io.rs:125-131`).
* **Pair exclusivity.** `audit_claims` refuses "a reserved pair is unused or
  shared between claims" and "a claim does not carry exactly its own reserved
  pair", and runs inside `check_opening` on both the prover and the verifier
  (`private_block/protocol.rs:89-133`, `:155-175`). The two new seam claims
  fall under it automatically once their pairs are declared in the layout.
  **On the v3 side that audit does not exist** — `check_masks`
  (`zk_ffn_fresh_poc.rs:253-321`) checks only that each claim's mask
  coefficients span Fp2 — which is exactly the endpoints disposition's R-3
  open item; ruling R-5 makes porting it a **build precondition**
  (§H step 1).

### C.3 Who fixes each root

| root | fixed by | carries D8/D11? |
|---|---|---|
| `A_attn`, `H_attn`, `M_attn`, `W_ffn`, `A_ffn`, `H_ffn`, `M_ffn` | the **prover**, inside the one proof | no |
| `In` (plane `x_in`), `Out` (plane `xres2`) | the **caller** / endpoint owner, before proving (`private_block.rs:375-386`) | **yes, in full, and open** |

Neither `nm` nor `z16` has a caller-fixed root anywhere in form E. Each lives
twice, on `A_attn` and on `A_ffn`, both prover-generated, both inside one
proof, both opened once. That is D12 item 3 satisfied structurally.

### C.4 Findings

**No step of this design opens anything twice, and no step needs an
intermediate root to be fixed by anyone but the prover.** Three things that
*look* like they might, and do not:

1. *The seam's counterparty is "another party's commitment" in the existing
   code.* In `zk_ffn_fresh_io.rs` it is, because that profile's counterparty
   is a caller-fixed endpoint. In form E the counterparty is `A_attn`, which
   the same prover made in the same proof. The code path is the same; the
   provenance of the root is not. **A build that reused the io profile's
   endpoint objects for `nm` or `z16` would be the forbidden configuration
   even though the arithmetic is identical** — this is the single most likely
   implementation error and §H makes it a named negative test.
2. *Two masking commitments.* `M_attn` and `M_ffn` are two commitments, each
   opened once. That is not a double opening; it is two commitments. It does
   reopen the CFS-channel question jointly (recorded as U-14 in the seam
   review), which §D.3 addresses.
3. *Residual 2 reads `z16` and the seam also claims `z16`.* Two claims on one
   plane at two different points, each with its own reserved pair, is the
   ordinary case the attention module already uses seventy-five times
   ("a plane opened at k points has k pairs",
   `private_attention/layout.rs:9-10`). It is two claim sites on one
   commitment, inside one opening — not two openings.

**One thing that is a finding, and it is about the tests, not the
construction.** `audit_claims` exists only on the attention side. Form E puts
a seam claim on `A_ffn`, where nothing enforces that its reserved pair is used
by no other claim. The endpoints disposition's R-3 already rules that the
general io path ports that
audit; **ruling R-5 now makes the port a BUILD PRECONDITION, not a
follow-up** — the same precondition D17 set for the private-IO path — because
form E is the first construction that adds a claim to `A_ffn` from outside
the v3 prover's own claim builder, and because the counterparty's seam claim
must carry its own reserved pair (§B.5, [C-1]: 8 Fp disclosed without one).
The seam claim itself is audit-compatible as designed: its `nb_d` data parts
land on data rows, its two mask parts touch one site row each and are
adjacent, and `part_key` gives all `nb_d + 2` parts the same `(tail, c0,
len)`, so `audit_claims`' adjacency test and `check_opening`'s "claim parts
with different column weights" refusal both pass.

## D. Hiding, hypothesis by hypothesis

**Nothing in this section establishes a privacy property.** It is a recount
under the same linear model the joint-view report uses
(`ZK60_NATIVE_JOINT_VIEW.md`, branch `zk60-native-jointview`), which is
evaluated at real challenges of real receipts and explicitly establishes
nothing. Form E has no receipts, so everything here is a prediction with an
experiment attached.

### D.1 The recount: claim sites, pairs, opening groups, slots

Measured baseline, from the four real captures (`ZK60_NATIVE_JOINT_VIEW.md`
§2.3, §3, §4) [MEASURED]:

| role | rows | data rows | groups | rank(ρ) | k0 | disclosed (Fp) |
|---|---:|---:|---:|---:|---:|---:|
| A (form-S block) | 455 | 213 | 35 | 72 | 0 | **0** |
| H (form-S block) | 384 | 278 | 9 | 20 | 0 | **2** (the public LogUp identity) |
| In / Out | 7 | 2 | 1 | 4 | 0 | **0** |
| M (opening only) | — | — | — | — | — | **2** |
| **joint** | | | | | | **4**, all public identity |

Form E's counts, per side, at the tiny geometry (the only geometry where the
attention side's numbers are known) and at model width (where the
feed-forward side's are known and the attention side's are not):

| | `A_attn` | `H_attn` | `M_attn` | `A_ffn` | `H_ffn` | `M_ffn` |
|---|---:|---:|---:|---:|---:|---:|
| claim sites, form S / form E at T32-d16 | 120 → **122** | 51 | 23 slots | — | — | — |
| claim sites, form E at 125M | not known | not known | — | 26 → **28** | — | 6 → **8** slots |
| claim sites, form E at Mistral | not known | not known | — | 66 → **68** | — | 6 → **8** slots |
| reserved pairs | +2 (4 rows) | +0 | — | +2 (4 rows) | +0 | — |
| opening groups | 35 → **37** | 9 | — | 5 → **7** | unchanged | — |
| `M` base rows | — | — | **50** (unchanged) | — | — | 16 → **20** |
| proximity pairs | 1 | 1 | 1 | 1 | 1 | 1 |
| openings | 1 | 1 | 1 | 1 | 1 | 1 |

Each new claim site gets its **own** fresh reserved pair; no pair is shared,
across sites or across sides.

**What this table does not yet carry** [E-13]: at any width where `nb_d` is
not a power of two, §B.2's re-tiling multiplies the whole `Dom::D` family's
claim sites by `nb_d`. At the 125M shape (`nb_d = 3`) that is ≈ **+70 claim
sites and ≈ +140 committed rows on `A_attn`**, plus the same multiplication
on the 19 `Dom::D` helpers of `H_attn` — an order of magnitude more than the
seam's own `+2` sites and `+4` rows. The seam's numbers above are right; the
attention side's model-width totals are not, until §H's layout step counts
them.

### D.2 H-pad, H-pair, H-prox at the seam

**H-pad** — *the `d` distinct sampled columns satisfy `d ≤ Q`, the nodes are
distinct and `x_j^n − 1 ≠ 0`, so the pad block is a full-row-rank Vandermonde
and the opened columns contribute nothing.*

Unaffected. `ZkOpts::standard` sets `q_pad = num_col_checks = 256`
(`zkp-core/src/pcs.rs:542-544`) and `commit_zk_owned_with` refuses `q_pad <
num_col_checks` (`:670`), so `d ≤ Q` holds **by construction on every
commitment, at every width**, and the hypothesis mentions neither row count
nor plane length. The one-opening-per-commitment invariant of §C is what
keeps `d` at 256 rather than 512; the measurement that settles the boundary
is already done — 256 pads against 256 distinct opened positions of the real
coset gave exact Gaussian rank 256 of 256, disclosing 0
(`ZK60_NATIVE_JOINT_VIEW.md` §9b) [MEASURED]. **Form E adds commitments; it
does not add openings per commitment, so it does not touch the pad budget.**

**H-pair** — *every claim's row weights, restricted to the non-data rows, sit
on exactly one adjacent reserved pair; that pair is used by no other claim;
its two coefficients are an Fp-basis of Fp2; and no claim touches the
proximity pair.*

The seam claim's coefficients on the non-data rows are exactly `(e, e·U)`
with `e = 0` rejected (`zk_ffn_fresh_io.rs:336-338`, `:392-394`), and
`{e, e·U}` is an Fp-basis of Fp2 for every `e ≠ 0`. The data parts only add
columns to the data rectangle, which the reduction quotients out. So the
hypothesis holds **by construction** on both sides, as it does for the
accepted endpoints seam (`ZK60_PRIVATE_ENDPOINTS_AT_SCALE.md` §5.1).

Two live hazards, both already ruled on and both now binding on form E:

* on `A_attn`, `audit_claims` *checks* the "used by no other claim" half
  (`private_block/protocol.rs:89-133`) — good;
* on `A_ffn`, **nothing checks it** (`check_masks` tests only the Fp2 span,
  `zk_ffn_fresh_poc.rs:253-321`), which is the endpoints disposition's R-3.
  The joint-view gate
  measured what a violation costs: two claims sharing one pair disclosed
  **8** dimensions (`ZK60_NATIVE_JOINT_VIEW.md` §6). Form E must port the
  audit before it puts a claim on `A_ffn`.

**H-prox** — *`det(ρ_prox[prox], ρ_prox[prox+1]) ≠ 0`, and no claim reaches
the proximity pair.* Shape-free; refused otherwise by
`check_opening_challenges` (`zk_ffn_fresh_poc.rs:336-339`) and by the
attention module's own determinant test (`private_block/protocol.rs:143-145`).
The seam claim touches only its data parts and its own pair.

### D.3 The CFS slot bound with two masking commitments

Stage 3 of the joint view measured, per slot, that the mask covers the whole
consistency subspace — `rank R_s = dim C_s` for every slot of every capture
(23 block, 18 attention), so the masked rounds are uniform on `C_s` given the
data, and every published `M` functional lies inside the round span
(`rank(F mod rounds) = 0`) [MEASURED]. The seam slot has `N_s = m + 1` rounds
of degree 2 and `L_s = 2N_s + 2 = N_s·d_s + 2`, which is the same relation
every other slot satisfies, so nothing structural changes.

What *is* new is that there are now **two** masking commitments with two θ
draws and two openings. Under the accepted accounting (a derived mask
evaluation is not an independent observation, `ZK60_NATIVE_JOINT_VIEW.md` §9a
answer 1) each `M` opening independently reveals **one Fp2 functional** — the
θ-combination `q[0] + q[512]` — so two `M`s reveal **4 Fp** where form S
reveals 2. Under the pessimistic accounting it is `2 · (slots + standalone +
host)` Fp, i.e. 68 on the attention side plus 16 on the feed-forward side.
This is U-14 of the seam review ("Two `M` commitments also reopen the
CFS-channel question jointly") and it is **owed**, not discharged: the lemma
of §3.1 of the joint view is per-slot and per-commitment, and nothing has
checked that two θ-combinations from two independent masking commitments stay
independent of the data jointly.

**But a linear model cannot decide it, and the first draft wrongly made it a
small-model gate** [E-16]. An `M` opening's independently published
functional is a functional of the mask coefficients, which are pure
randomness: it touches **no** data coordinate whatever the number of masking
commitments, so the answer is 0 by construction rather than by evidence (the
check measured exactly that, 0 and equal to the sum). The real content of
U-14 is the **nonlinear** redundancy of `ZK60_NATIVE_JOINT_VIEW.md` §3.1
(degree up to 4), which linear algebra explicitly cannot certify. The
replacement is stated in §D.6 and gated in §H: the **per-slot derived-mask-
evaluation identity**, asserted for **both** masking commitments on a real
form-E receipt.

**And one code invariant that comes with the second `M`** [C-6, ruling R-4]:
the two `mask_open` calls draw **two separate θ** (`zk.rs:515`) at two
transcript positions, so the `MaskFunctional` lists of `M_attn` and `M_ffn`
must never be mixed — `combined_weights` would silently index the wrong spec
(`zk.rs:470-487`). There is no check for that today; R-4 requires one.

The slot-length bound is not close to binding on either side (§B.5 table); the
`CfsMask` 64-bit shift at `n_vars = 62` is the real ceiling and the guard
belongs in the type (erratum E-19d).

### D.4 What is NEW: cross-commitment correlation

This is the question the brief is right to single out, and it is the one thing
in form E that neither existing analysis covers.

**The situation.** The same hidden plane `nm` now exists twice: as data rows
of `A_attn` (masked by `A_attn`'s own pads, salts and mask rows) and as data
rows of `A_ffn` (masked by `A_ffn`'s). A published relation — the seam — ties
them. The joint-view analysis's stage-4 argument for "the joint disclosed
dimension is the sum of the parts" rests on **disjoint randomness**: each
commitment draws fresh pads and salts (`commit_zk_owned_with`) and each
`mask_commit` draws its own CFS coefficients, so a functional supported on
data coordinates that is a sum of functionals of several channels must have
each channel's part separately supported on data coordinates
(`ZK60_NATIVE_JOINT_VIEW.md` §4).

**Does the seam break it? On the linear model, no — and aliasing pushes the
other way.** Three steps.

**The structural reason the answer is 0, which the first draft never stated**
[C-3]. On the honest witness the two seam tables are **pointwise equal**, so
the seam's polynomial `v0·(v1 − v2)` is **identically zero on the whole
cube** (`zk_ffn_fresh_io.rs:198-200`). Therefore every masked round message
is *exactly* `c·g_j(X)` — the data part is not merely small or hidden, it is
zero as a function of the data variables (`zk.rs:984-997`); the claimed sum
is `γ = c·g_s.total()` with **no** data term, which is literally what the
code sets (`zk_ffn_fresh_io.rs:295`); and the extension round reduces to
`(1−x)·x·eq(τ, ρ)·(ext_L − ext_R) + c·g_k(x)`, a functional of the two sides'
mask pairs only. **The only data-bearing published quantities of the whole
seam are the two masked terminals, and each of them *is* its side's own claim
value under its side's own reserved pair.** Everything below follows from
that.

1. *Disjoint randomness survives, and the argument must be restated per
   CHANNEL, not per commitment* [C-2]. Aliasing **data** across two
   commitments says nothing about their **randomness**. `A_attn`'s pads,
   salts and mask rows and `A_ffn`'s are drawn from independent streams
   (`ZkRng::from_os` per prover, or disjoint prefixes of one stream), and the
   stage-4 argument quantifies over randomness coordinates. But the phrase
   "disjoint randomness across `A`, `H`, the endpoints and `M`" does not
   cover the seam as written: **the seam's round channel has data support on
   both commitments while its randomness lives only on `M_ffn`'s slot.** The
   decomposition still holds — that slot's coefficients are disjoint from
   every PCS pad, salt and mask row of either `A` — but the sentence must say
   so explicitly, per channel, or it is asserting a hypothesis it has not
   stated.
2. *Aliasing can only reduce, never increase.* The joint-view report states it
   directly: the joint space "can only be *smaller*, never larger, if data is
   aliased across commitments (two channels then disclose the same
   functional)" (§4). If `A_attn` disclosed a functional `f` of `nm` and
   `A_ffn` disclosed the same `f` of its copy, jointly that is one
   functional, not two. Both are measured at 0 on real form-S receipts, so
   the reduction has nothing to reduce.
3. *The seam's own published quantities are masked differences, and their
   data part vanishes on the honest manifold.* The verifier's identity
   `fin = (1 − e)·eq(τ, ρ)·(terminals[0] − terminals[1]) + c·mask_eval`
   determines the **difference** of the two masked terminals. Each terminal
   is blinded by its **own** reserved pair on its **own** commitment, so the
   difference is blinded by the difference of two independent uniform Fp2
   values — still uniform. And the data part of that functional is
   `nm_attn(ρ) − nm_ffn(ρ)`, which is identically zero once the aliasing
   constraint `nm_attn = nm_ffn` is imposed. So it discloses a functional of
   randomness and nothing of the data.

   **The converse is a hazard, but NOT the one the first draft named, and the
   correction matters** [E-12]. The code comment "a single shared row would
   leave the DIFFERENCES of two blocks' evaluations in the clear"
   (`zk.rs:1961-1975`) is the **P3 W-block mask-row** documentation and
   concerns two *different* blocks' evaluations. For an **equality** seam the
   two planes are equal, so the difference of the two terminals is
   identically zero and a shared blinding source hides nothing that needed
   hiding: the check measured a shared blinding source across the two
   commitments, with the plane aliased, at **0** (§D.6 case 3a). The hazard
   is real the moment the two planes are *not* equal — the same case with the
   plane not aliased discloses **8 Fp** (case 3b) — so two independent pairs
   remain a **requirement**, but as a **soundness/simulator** condition and
   as the guard on any future non-equality seam, not as a hiding condition of
   this one. In form E it is automatic because the pairs live on different
   commitments; a refactor that put both terminals' masks in one place would
   break it silently for the non-equality case, which is why §D.6 keeps the
   control in its non-aliased form.

   **And case 3b is the one place where the joint exceeds the sum of the
   parts** — joint 8, `L` alone 0, `R` alone 0, sum of parts **0**. Each
   side's own per-commitment analysis sees nothing; only a genuine joint view
   sees the leak. That is why §H's capture gate cannot be a per-role sum
   (E-2, ruling R-2).

**What is genuinely not covered by any of this.** (a) The nonlinear layer:
the seam's identity is degree 2 in the terminals and the CFS link is degree up
to 4; linear algebra cannot certify the redundancy, only the numerically
checked identity of `ZK60_NATIVE_JOINT_VIEW.md` §3.1 can, and there is no
form-E receipt to check it on. (b) The hash layer — two more roots, two more
sets of 256 leaf salts, two more path families — which linear algebra never
covered. (c) The adaptive lift: the sequential-kernel lemma's **joint**
hypothesis stays with obligation U-3, and form E adds two more channels to
the joint hypothesis it has never discharged. (d) D8/D11 on `In` and `Out`,
unchanged and open.

### D.5 The expected joint disclosed dimension

**Prediction, under the joint view's linear model and the accepted
accounting, for one form-E block:**

| channel | expected disclosed (Fp) | why |
|---|---:|---|
| `A_attn` | **0** | `k0 = 0`: the group vectors' non-data support is the reserved pairs with coefficients `(e, e·U)`, `e ≠ 0`; the two seam groups raise `rank(ρ)` from `2·35 + 2 = 72` to `2·37 + 2 = 76` and do not create a combination vanishing on every non-data row. **These two counts are the tiny geometry's**; where R-3 re-tiles the `Dom::D` family the group count changes and must be recounted from the layout at that shape (`ZK60_PRIVATE_BLOCK_125M_LAYOUT.md`, commissioned 2026-09-19) |
| `H_attn` | **2** | the public LogUp identity, published value `Fp2::ZERO` |
| `M_attn` | **2** | the θ-combination `q[0] + q[512]` |
| `A_ffn` | **0** | same reason; `rank(ρ)` rises from `2·5 + 2 = 12` to `2·7 + 2 = 16`, and the two seam pairs join `a_mask_rows()` (`zk.rs:2090`) so the repaired rank test covers them |
| `H_ffn` | **2** | its own LogUp identity |
| `M_ffn` | **2** | its θ-combination |
| `W_ffn` | 0 under P1 (the opening is **plain**, not hiding, and its rows are the public weights — but it *is* opened, [E-6]) / to be counted (P3) | out of scope here |
| `In`, `Out` | **0** each | the measured endpoint figure at the tiny geometry, for a reason that does not mention the plane length (`ZK60_PRIVATE_ENDPOINTS_AT_SCALE.md` §5.2) |
| **joint** | **8 Fp, all of it public identity** — an **ACCOUNTING SUM, not a measurement** [C-11] | the sum of the parts under the joint view's accepted convention, and aliasing can only reduce it |

**The 8 Fp must be labelled for what it is** [C-11]. It is arithmetic over a
convention — `2 (H_attn) + 2 (H_ffn) + 2 (M_attn) + 2 (M_ffn)` under
`ZK60_NATIVE_JOINT_VIEW.md` §9a answer 1, which rules that a derived mask
evaluation is not an independent observation — and **not** a figure any
instrument returned for form E. What the check's small model actually
measures is the **PCS channel**, where the answer is **0 on both sides
jointly** (§D.6 case 0), and **none of the 8 is the seam**.

Against form S's **measured** 4 Fp on a real receipt. The whole of the
increase is the second `H` and the second `M` — the price of having two
provers. That is the falsifiable claim, and it is the one that survived the
independent check:
*a seam between two commitments holding the same plane adds zero to the
disclosed dimension, provided each side's claim carries its own fresh
reserved pair on its own commitment.* On the check's small model, measured:
**joint 0, parts 0 + 0**, with the plane aliased, the seam present, batched
over three blocks and with both seams present.

### D.6 The small-model experiment, rewritten after the check

**The experiment now exists and has been run once**, by the independent check
(`results/zk60_form_e_check/seam_smallmodel.py`, 17 cases, predictions
written before the runs). Its **acceptance criteria are rewritten here**, as
ruling R-2 requires, because run exactly as the first draft specified it
**would have stopped a correct construction** [E-1]: three of the draft's
controls cannot fire for an *equality* seam at an honest witness — the seam
polynomial `v0·(v1 − v2)` vanishes identically there (§D.4, [C-3]) — and the
draft's acceptance paragraph said "a control that stops firing is a stop".
The design is not what must change; the criterion is.

**The model.** The joint-view gate's negative-control model
(`ZK60_NATIVE_JOINT_VIEW.md` §6: 4 message columns, Q pads, data rows, one
reserved pair per claim, a proximity pair, optionally a zero-sum pair, with
`disclosed = rank([M_rand | M_data]) − rank(M_rand)` computed by brute-force
dense rank), extended to **two commitments with an aliased plane and a
seam** and driven from the same harness so the existing controls keep
firing. It must be green, in the rewritten form below, **before any Rust is
written** (§H step 0).

**Construction.** Two synthetic commitments `C1`, `C2` over the same small
field pair, with independent pads, salts and mask rows. `C1` has data rows
`P ‖ R1`, `C2` has data rows `P ‖ R2` — `P` is the **aliased** plane (the same
free variables in both), `R1`/`R2` are private to each side. Each commitment
gets: one ordinary claim at its own point, one **seam claim** at a shared
point `ρ` with its own fresh reserved pair, one proximity pair, `q_pad = d`
pads and `d` sampled columns. Publish: both group vectors, both proximity
vectors, all sampled column values, and the seam's published equation
(masked rounds, the two masked terminals, `mask_eval`, `fin`), with the
seam's CFS mask drawn from a third channel.

**The case list, with the check's measured figures.** Predictions were
written before the runs; every figure below is a brute-force dense rank in Fp
dimensions [MEASURED ON A LINEAR MODEL — this establishes **no** privacy
property].

| # | case | must give | measured |
|---:|---|---|---:|
| 0 | honest, plane aliased, seam included | **0** | **0** (parts 0 + 0) |
| 1 | honest, plane **not** aliased, no seam | **0** | 0 |
| 2 | the seam `μ`-batched over 3 blocks | **0** | **0** |
| 3a | the two sides' terminals blinded from **one** source, plane **aliased** | *reclassified* — see below | **0** |
| 3b | the same, plane **not** aliased | **> 0** | **8** (joint 8; `L` alone 0, `R` alone 0, **sum of parts 0**) |
| 4 | the seam claim reuses an ordinary claim's pair on one side | **> 0** | 8 |
| 5 | the seam's masking coefficient `c = 0` | *reclassified* | **0** |
| 6 | the extension challenge `e = 0` | **> 0** | 8 |
| 8 | a second masking commitment's functional added | **replaced** — see below | 0, equal to the sum |
| 9 | one side's commitment opened twice | **> 0** | 10 |
| 10 | `q_pad` = the distinct opened columns | **0** | 0 |
| 11 | two seams at the **same** terminal point (groups merge) | **0** | 0 |
| 12 | two seams at independent points | **0** | 0 |
| 13 | one pad fewer than the opened columns | **> 0** | 6 |
| 14 | the seam's CFS slot too short (the first draft's case 7) | *reclassified* | **0** |
| 15 | the counterparty's seam claim carries **no** reserved pair | **> 0** | **8** |
| 16 | the two seams share one pair on each side | **> 0** | 8 per side, 16 summed, 8 jointly |

**Acceptance, as ruling R-2 rewrites it.**

* **Must give 0: cases 0, 1, 2, 8, 10, 11, 12.**
* **Must give more than 0: cases 4, 6, 9, 13, 15, 16.**
* **Cases 3, 5 and 7 of the first draft are RECLASSIFIED as
  soundness/simulator conditions and are run in their NON-ALIASED form**
  (case 3b), where they do fire (8 Fp). They cannot fire in their aliased
  form because the seam polynomial is identically zero on an honest witness,
  so for an *equality* seam a shared blinding source, a zero masking
  coefficient and a short slot each disclose **0**. They remain **refused in
  code** — `draw_mask_challenge(.., true)` returns `Err`,
  `masked_prove`/`extension` assert `!c.is_zero()` (`zk.rs:976`, `:988`), and
  the slot-length rule stands — but they are soundness and simulator
  conditions here, not hiding ones, and treating a silent one as a stop would
  stop a correct design.
* **Case 8 is REPLACED** [E-16]. A linear model cannot decide the
  two-masking-commitments question at all: an `M` opening's independently
  published functional is a functional of pure randomness and touches no data
  coordinate whatever the number of `M`s, so the 0 it returns is a property
  of the instrument, not evidence. In its place, the **per-slot
  derived-mask-evaluation identity** of `ZK60_NATIVE_JOINT_VIEW.md` §3.1 is
  asserted for **both** masking commitments on a **real form-E receipt**
  (§H's capture gate). That identity is nonlinear, which is exactly why
  linear algebra cannot stand in for it.
* **The gate the experiment must ADD is the joint one** [E-2, R-2]: compute a
  **genuine cross-commitment joint rank with the shared plane's coordinates
  identified**, and assert `joint == sum of parts` as well as `joint == 0`.
  Case 3b is the reason and it is the one new failure mode a seam introduces:
  **joint 8 with every per-commitment figure 0**. A per-role or per-commitment
  sum is blind to it, and without this assertion §D.4 step 1's "disjoint
  randomness survives" is a hypothesis the gate does not test.
* The reduction must agree with brute force on the honest instances, as it
  does today, and the model's three reference points must reproduce the
  joint-view gate's own one-commitment figures (two claims sharing one pair
  → 8; opened twice → 10; one pad fewer → 3 per commitment).

## E. Soundness

### E.1 The seam errors

The challenge field is the quadratic extension of 64-bit Goldilocks,
`|Fp2| ≈ 2^127.99999999995` (`zkp-core/src/field.rs:10`, `:15`). Writing
`m = log_t + log_db` for one d-block's cube:

* random evaluation point: `≤ m/|Fp2|` by Schwartz–Zippel on the multilinear
  extension of the difference;
* the sumcheck: `m + 1` rounds of degree 2, `≤ 2(m+1)/|Fp2|`;
* the `μ` batching: if any block differs, `Σ μ_c δ_c(x) = 0` with probability
  `1/|Fp2|`.

| shape | `m` | one seam | two seams, one block | two seams × 32 blocks |
|---|---:|---:|---:|---:|
| tiny T32/d16 | 9 | 2^-123.14 | 2^-122.14 | 2^-117.14 |
| 125M, `nb_d = 3` | 17 | 2^-122.27 | 2^-121.27 | 2^-116.27 |
| **Mistral, `nb_d = 1`** | **21** | **2^-121.98** | **2^-120.98** | **2^-115.98** |

[COUNTED]. Plus `2^-128` per seam for the batching, `2^-121` over a 64-seam
pass — below everything else. **The seam's soundness is field-limited and
grows logarithmically in the plane; it is nowhere near the binding term.**

Two refusals inside the argument are load-bearing rather than cosmetic, and
**they are load-bearing for different reasons** — the first draft called both
*hiding* conditions and that is wrong for one of them [E-12]:

* `e = 0` is rejected (`zk_ffn_fresh_io.rs:336-338`, `:392-394`) and **is** a
  hiding condition: measured 8 Fp disclosed without it (§D.6 case 6).
* `c = 0` discards the attempt (`zk_ffn_fresh_poc.rs:221-233`, with
  `assert!(!c.is_zero())` in `masked_prove`/`extension`, `zk.rs:976`, `:988`)
  and is a **soundness/simulator** condition for this seam, not a hiding one:
  for an equality seam the masked rounds carry no data at all, and the
  measured disclosure with `c = 0` is **0** (§D.6 case 5). The same holds for
  the slot-length rule (case 14).

Neither may be turned into a resample.

### E.2 The whole-proof figure per D15

D15 requires the whole-proof figure, labelled a projection, not the
per-opening one. Per opening at `log_cols 14 / inv_rate 4 / Q 256` the code's
own conservative Brakedown bound with message length `n + Q`
(`zkp-core/src/pcs.rs:17-19`, `:525-528`) is **2^-105.61**; at the tiny
`8/8/256` geometry it is 2^-106.25. Both conventions must not be crossed
(erratum E-8); everything below uses the corrected model-width figure.

**Openings per form-E block: nine** (`A_attn`, `H_attn`, `M_attn`, `W_ffn`,
`A_ffn`, `H_ffn`, `M_ffn`, `In`, `Out`), against D15's projected "about six
per layer" for the feed-forward-only pass. **The count is nine in both
modes** [E-6]: `W_ffn` is opened under P1 as well — plainly rather than
hidingly (`zk.rs:2314` against `:2318`) — so the first draft's nine was right
for the wrong reason. Charging every one of the nine `2^-105.609` is
**conservative**: only `A_attn`, `H_attn`, `A_ffn`, `H_ffn` run at
`14/4/256`; the two `M`s run at 512-of-4096 with `MASK_Q = 256`, `In`/`Out`
at `8/8/256`, and `W_ffn` under P1 is a plain opening with no pads, so the
five of them sit at ≈ 2^-106.25 and a block is really ≈ 2^-102.76. The
figures below keep the safe side.

```
one block,  9 openings          = 9   · 2^-105.609   = 2^-102.44
32 blocks, 288 openings         = 288 · 2^-105.609   = 2^-97.44
the feed-forward-only base      = 192 · 2^-105.609   = 2^-98.02   (D15's 192)
lookup term, feed-forward only  =                      2^-94.2    (D15, PROJECTION)
whole pass, commitment + lookup = 2^-97.44 + 2^-94.2 = 2^-94.06
if the attention half's lookup term equals the feed-forward's:
                                = 2^-97.44 + 2·2^-94.2 = 2^-93.13
```

[COUNTED, on a PROJECTION]. **So: a 32-block form-E pass is about 94 bits
whole-proof if only the feed-forward lookups are counted, and about 93 if the
attention half's lookups cost the same as the feed-forward's — against a
128-bit target, and against the zkVM line's "about 97 bits conjectured"
(D3).** The commitment half moves by only 0.06 bit relative to the
feed-forward-only pass; the openings are not where the budget goes.

**Two additions the first draft left out.**

* **Under a `g`-block run the opening count per pass falls** [C-9]. A
  `g`-block proof has 7 prover commitments per block plus **two** endpoint
  commitments for the whole proof, not two per block: `32 × 7 + 16 × 2 =
  **256** openings per pass at `g = 2`, and `32 × 7 + 2 = **226** at
  `g = 32`, against 288 for 32 single-block proofs. That is a small genuine
  soundness gain — 256 · 2^-105.609 = 2^-97.61, against 2^-97.44 — which §F
  may now claim.
* **The cross-side LogUp collision term, counted once** [C-7]. With two
  triples (R-1) the two sides' identities are separate anyway; even under one
  shared triple a cross-side collision would need
  `v + γ·tag₁ = v′ + γ·tag₂`, one value of `γ` out of `|Fp2|` per pair of
  bounded integers, ≈ **`2^41/2^128`** over the tag and value ranges in play.
  Negligible, but it had not been named; it is named here and nowhere else.

**The number that is missing, and it is the honest headline of this
section: nobody has projected the attention half's lookup term at model
width.** The tiny block does 61,440 byte lookups plus 2,048 exp and 512
activation lookups (`private_block/layout.rs:744-746`,
`private_block/tests.rs:107`); at model width the score-domain lookups alone
scale as `H_q · T²`. Until that projection exists, every form-E whole-proof
figure is a lower bound on the error, i.e. an upper bound on the bits.
§I.2 records it as an open obligation.

### E.3 What stops the feed-forward half from being proved on a different plane

**The seam, and nothing else.** Concretely, a cheating prover who wants the
feed-forward half to run on a plane `x' ≠ nm` must make

```
Σ_c μ_c · nm_c (τ)  ==  Σ_c μ_c · x'_c (τ)
```

hold at a `τ` and `μ` drawn **after** both `A` roots are public (steps 8-16
then 19 of §B.6). If `nm` and `x'` differ anywhere on the cube, the multilinear
extension of the difference is a nonzero polynomial of total degree `≤ m`, so
this happens with probability at most `(m + 2(m+1) + 1)/|Fp2| ≈ 2^-122`.

Three supporting facts, each of which must be a test rather than a belief:

1. **The claim must point at the arithmetic plane.** The right-hand slice is
   `lay.x[c]`, the plane the gate and up matmuls read (`zk.rs:2016`,
   `:3360`); the left-hand slice is the plane `SC_SSM` and the `c6`/`c7`
   terms produce. A prover who commits a *copy* satisfies the seam and proves
   nothing (`ZK60_PENDING_FFN.md:25-28`). FA3's refusal "any slice !=
   `lay.x[c]` / `lay.z[c]`" is the check
   (`ZK60_FABLE_MASK_REPAIR.md:605-609`).
2. **The challenge must come after both roots.** Drawing `τ` before
   `absorb_com(A_attn)` or before `absorb_com(A_ffn)` lets the prover choose
   the plane after seeing the point. §B.6 steps 8–16 then 19 fix it; the
   verifier must draw at the identical position (`zk_ffn_fresh_io.rs:385-386`
   is the pattern).
3. **The class comes from one side only.** The feed-forward proves no range
   on `lay.x` (`zk.rs:2685-2690`). If the seam is weakened, the composed
   statement admits an out-of-class feed-forward input — D12 item 4's exact
   concern. So the `nm` seam is a *soundness* component of the integer model,
   not only a binding component.

### E.4 The multi-block case

**At any width with `nb_d > 1` the single-slice seam binds only block 0, and
nothing in the present code would notice.** The independent check built the
attack: commit the counterparty plane as `(block 0 honest ‖ arbitrary ‖
arbitrary)` and publish its real root; the root comparison passes, the
sumcheck and both commitment claims touch block 0 only, the shape checks pin
rows, and the junk sits inside the data rectangle
(`ZK60_PRIVATE_ENDPOINTS_AT_SCALE_DISPOSITION.md` §1.1). The existing tamper
test perturbs position 271, inside block 0, so it would not catch it.

Which widths: `log_db = min(trailing_zeros(d), 12)`
(`zkp-core/src/ffn_v3/statement.rs:153-156`), so `nb_d = 1` **only when the
width is a power of two no larger than 4096**. 4096 → 1; **768 → 3**, 2560 →
5, 3072 → 3, 5120 → 5, 6144 → 3, 8192 → 2, 12288 → 3, 16384 → 4. Mistral's
4096 is the exception, not the rule — which is precisely why the endpoints
disposition's R-1 makes the batched form unconditional.

Form E therefore uses the `μ`-batched seam at every width, and the per-block
tamper battery of the endpoints disposition's R-5 (a tamper in block 0, in
block 1 and in the
last block, each **rejected by the verifier**) is a gate, not a nice-to-have.
Note the extra wrinkle form E introduces over the endpoints case: §B.2's
tiling constraint means a mis-tiled attention side would make the two sides'
block-`c` tables different functions of the cube, which shows up as an
honest-proof **failure**, not a silent acceptance — the safe direction, and
§H step 3 pins it.

## F. Chaining blocks

### F.1 The problem in plain words

*This subsection and §F.7 are written to be read without opening any code.*

A model is thirty-two blocks stacked on top of each other. Block 1's answer is
block 2's question. We are hiding every one of those intermediate answers, so
nobody — not the verifier, not the auditor — is allowed to see the numbers
that pass from one block to the next. But the verifier still has to be
convinced that block 2 really did run on block 1's answer, and not on some
other numbers the prover found convenient.

The project's way of hiding a number is to put it in a sealed box (a
commitment) and prove things about what is inside without opening the box.
There is one hard rule, D12 item 1: **a sealed box may be opened only once.**
That rule is not fussiness. It was written after a measured attack: at the
geometry the code actually uses, opening one of these boxes twice lets an
observer reconstruct **all** of the hidden numbers inside it. The reason is
that each opening publishes a masked combination of the box's contents, and
two such combinations can be subtracted to cancel the mask.

So the question "how do consecutive blocks agree on a hidden number they both
need?" comes down to: **who holds the box, and how many times does it get
opened?** There are only a few honest answers, and they trade off against each
other on three axes — how much memory the prover needs at once, how many boxes
have to be handed to the prover by somebody else (which is the part of the
security argument that is still open), and whether the answer needs the
project's own rules to be amended.

**One rule was settled while this page was under check, and it removes an
answer before we start.** Two separately finished private proofs cannot be
joined through a sealed box. The first proof's receipt already contains a
full opening of that box, so a second proof consuming the same box is a
*second opening* — the forbidden configuration — it is also prior history
that the security argument cannot absorb, and it is not implementable today
(`ZK60_D8_D11_RESTATEMENT_DISPOSITION.md` §2 item 5). **A private run is one
transcript end to end.** Blocks *inside* one run are fine; the boundary
*between* two runs is exactly the forbidden root. Joining two runs therefore
needs a different kind of handle — a salted hash that is **not** a
polynomial-commitment root, with a gadget inside the proof showing the sealed
plane is the one the proof used. That is **D18's option B**: Victor has
recorded it as a todo and expects it to be the end state (about +12.6 % on a
private pass [COUNTED, factor-two band]), and **it is not built**. Until it
is, "a chain" means "one transcript", and the number of blocks in a run is
bounded by memory alone.

### F.2 Candidate (i): all blocks in one proof, one transcript

Every block's commitments are made under one transcript; the residual plane
between block `k` and block `k+1` lives on prover-generated commitments on
both sides and is bound by the same batched seam form E uses inside a block.
The whole pass has exactly **two** caller-fixed roots: the model's hidden
input and the model's hidden output.

* **Openings per commitment: 1.** Every commitment is opened once, at the end
  of the pass. No rule is broken.
* **Openings per pass: fewer, not more** [C-9]. A `g`-block proof carries 7
  prover commitments per block plus **two** endpoint commitments for the
  whole proof, not two per block: **256** openings per 32-block pass at
  `g = 2` and **226** at `g = 32`, against 288 for 32 single-block proofs
  (§E.2). A small soundness gain that comes free with the shape.
* **Who fixes each root:** the prover, except the pass's two external
  endpoints.
* **D8/D11 carried:** 2 roots for the whole pass — the best of any candidate,
  by a factor of 32 against a per-block scheme.
* **D12 compatibility:** compatible in substance, but **one sentence needs
  clarifying, and the amendment needs a second clause the first draft
  omitted**. D12 item 2's first clause reads "A block is one proof under one
  transcript with exactly two external endpoints". Under (i) a block is *one
  thirty-second of* a proof: the letter fails, the purpose does not. The
  purpose, stated in the item's own second sentence, is to forbid **gluing
  two separately finished receipts by a shared root**, and (i) is the
  opposite of gluing — one transcript, nothing finished separately, nothing
  shared by two proofs. Every other clause is satisfied *more* strongly. So a
  multi-block proof **generalises** item 2 rather than contradicting it.
  Amendment, with the clause [C-8] requires: *"A block is proved under one
  transcript, with exactly two external endpoints per proof; several
  consecutive blocks may share one transcript, in which case the proof's two
  external endpoints are the first block's input and the last block's output,
  **and every boundary plane internal to that proof is a hidden intermediate
  under item 3 — on commitments the prover generates inside that same proof,
  never caller-fixed.**"* Without the second clause the new sentence licenses
  a run whose internal boundaries sit on caller-fixed roots, which is exactly
  what item 3 forbids.
* **Memory at 8B: this is where it dies, and it dies at `g = 1`, not at
  `g = 32`** [E-4]. Every commitment must survive until its single opening,
  because the 256 sampled columns are only known once every root is
  absorbed — and **both** the systematic data and the encoded matrix must be
  resident (`open_zk` gathers columns from `cm.store`, `pcs.rs:930-942`;
  `fold_rows_multi_zk` needs the systematic `data`, `:863-874`). One
  Mistral-width form-E block is about **44,100 committed rows** of 16,384
  words (§G.2), and at `inv_rate 4` the encoded matrix is 4× the systematic:

  | | systematic | encoded | **resident total** |
  |---|---:|---:|---:|
  | one form-E block | 5.79 GB | 23.14 GB | **≈ 28.9 GB** |
  | `g = 2` | 11.57 GB | 46.29 GB | **≈ 57.9 GB** |
  | `g = 32` | 185.2 GB | 740.5 GB | **≈ 926 GB** |

  The first draft quoted the systematic column alone at `g = 2` ("about
  11 GB … plausible on a 32 GB card") two sentences after quoting both.
  Corrected: **`g = 2` needs ≈ 58 GB and does not fit a 32 GB card; one
  block at ≈ 29 GB is already at that card's limit.** The project already
  records that one 8B layer's commitments alone overflow an 8 GB part
  (`gpu zk commit H (v3): cuMemAlloc(1514 MB) OUT_OF_MEMORY`,
  `zk.rs:2388-2394`, which is why the device pool is drained between layers).
  **About 60 % of every byte in that table is the [ESTIMATE] attention half**
  (§G.2) — a plane-count scaling of a toy layout that does not exist at model
  width — so the table's precision is spurious and its order of magnitude is
  the claim.
* **So at 8B there is no cheap variant.** `g = 2` at Mistral width does not
  fit one consumer GPU under this construction, with or without chunked
  commits; whether it can run with the encoded matrices in **host** memory is
  a measurement nobody has, and it is a different machine. Running `g = 32`
  needs a **disk-backed commitment store** — spill each commitment's encoded
  matrix, keep only roots and leaf hashes resident, stream the 256 columns
  back at opening time — which is real engineering, not new cryptography, and
  nothing like it is built. **Where the run-length parameter does work today
  is the 125M-class shape**, where every figure is small; §F.7 makes that the
  target.
* **The variant, (i′): run length `g`.** Put `g` consecutive blocks under one
  transcript and make the pass `32/g` proofs. It does not remove the boundary
  problem; it reduces the number of boundaries from 31 to `32/g − 1` — **and
  those remaining boundaries are not merely expensive, they are unbuildable
  today**, because a private run is one transcript end to end (§F.1) and two
  finished runs cannot be joined through a commitment root. So `g < 32` at a
  given width buys memory at the price of a pass that is *not a bound chain*
  until D18's option B exists; under D17 item 4 such a set of proofs "is not
  a chain" and must never be called P1. `g = 2` at the 125M shape is the
  right first build (§F.7) precisely because it is a *complete* run of the
  thing being tested, not a fragment of a model pass.

### F.3 Candidate (ii): one proof per block, a shared endpoint commitment opened by each

The residual plane between blocks `k` and `k+1` goes into one hiding
commitment; block `k`'s proof opens it as its output endpoint and block
`k+1`'s proof opens it as its input endpoint.

**Worked out exactly: this is one commitment and two openings. It is the
forbidden double opening.** Not by analogy — by the same construction D11
measured. Two native PCS openings at the endpoint geometry recover all 512
data words (D11; `ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md`), and the
joint-view small model's control "the commitment opened twice" disclosed 10
dimensions against 0 honest (`ZK60_NATIVE_JOINT_VIEW.md` §6). D12 item 1
forbids it in terms: "not permitted as a seam, as a convenience, or as a test
shortcut that could be mistaken for one."

**It is worth stating precisely *why* it fails, because the reason is a
parameter and not a law**, and a reader who does not know that will either
over- or under-rate this candidate.

1. *One reserved pair.* `MASK_ROWS = 5` gives the endpoint commitment exactly
   one terminal mask pair (`private_seam.rs:28-36`, `:216`). Two openings
   means two claims, and if they share one pair, their difference is in the
   clear. The general minimum is `2·claim_sites + 2`
   (`ZK60_PRIVATE_ENDPOINTS_AT_SCALE.md` §1.1, erratum E-14), so two
   consumers need `MASK_ROWS = 7`. **Fixable, cheaply.**
2. *The pad budget.* This is the structural one. `Q = 256` uniform pads per
   row absorb the sampled columns of **one** opening; `ZkOpts::standard` ties
   `q_pad = num_col_checks = 256` (`zkp-core/src/pcs.rs:542-544`). Two
   openings sample about 512 distinct columns against 256 pads, and H-pad
   fails — which is exactly what the "opened twice" control measures. The fix
   is `Q = 512` on that one commitment. Its price: the hiding message length
   becomes `n + Q = 16,896` of 65,536, so the per-opening proximity bound
   moves from **2^-105.61 to 2^-104.97 — 0.64 bits** [COUNTED]. Its
   obstruction: `ZkOpts::standard` is shared with frozen paths and is not
   changed now (`ZK60_NATIVE_JOINT_VIEW.md` §9a answer 2), so it would have
   to be a per-commitment option on a new type.
* **Openings per commitment:** 1 for every commitment except the boundary
  commitments, which are opened **twice**.
* **Who fixes each root:** the boundary roots are caller-fixed (or
  prover-fixed and then published, which is worse). 33 roots over a 32-block
  pass.
* **D8/D11 carried:** 33 caller-fixed roots, every one of them open.
* **D12 compatibility: NO. It needs D12 item 1 amended**, and the amendment
  would have to overturn a measured attack, not a wording preference. Nothing
  in this draft asks for that.

### F.4 Candidate (iii): one proof per block, own copies, a link proof

Each block proof commits its **own** copy of the boundary plane (bound to its
`A` by an in-proof seam, so that copy is genuinely the plane the arithmetic
used) and a separate small "link" proof shows block `k`'s output copy equals
block `k+1`'s input copy.

**Count the openings.** Block `k`'s output-copy commitment is opened once by
block `k`'s proof (to authenticate the in-proof seam claim) and once by the
link proof (to authenticate the link claim). Same for block `k+1`'s input
copy. So **two commitments, two openings each** — twice as much of the same
violation as (ii), plus an extra proof and an extra transcript. Candidate
(ii) strictly dominates it.

The only way to get (iii) down to one opening per commitment is to have the
block proof **not** open its boundary copy and defer that opening to the link
proof — but a claim can only be authenticated by an opening under a
transcript that contains the claim's challenge point, so the link proof would
have to absorb the block proof's transcript state. At that point the two
proofs are one proof with a deferred opening, which is candidate (i), with
candidate (i)'s residency problem intact.

* **Openings per commitment:** 2 on each boundary commitment.
* **D12 compatibility: NO**, same sentence as (ii), and it pays twice.

### F.5 Candidate (iv): what the existing documents propose

Four are on record, and none of them is a private chain today.

* **`ZK60_PUBLIC_CHAIN.md` (B5, the public two-block receipt).** Two
  independently approved contracts, layers 0 then 1, joined by "one public
  signed INT16 intermediate tensor" that is used as block 0's expected output
  and block 1's expected input, with each block's proof authenticating the
  boundary against its own arithmetic commitment. **It is explicitly P0
  public arithmetic** and publishes the activations, so it is not admissible
  under D1. Its value is the shape: it is candidate (ii) with the sealed box
  replaced by a plain public value. Turning it private turns it into (ii).
* **`ZK60_BLOCK_CONTRACT.md` (A00, `preflight_next_boundary`).** Checks
  consecutive layer order, identical approved model and calibration IDs, and
  matching outgoing/incoming residual scale and class — and says of itself
  "A private equality proof is still required for actual committed values",
  and "Neither context binding nor `preflight_next_boundary` can replace that
  equality proof." **It is metadata preflight; it names the obligation the
  other candidates must discharge, and discharges none of it.** It is also
  where the scale/class half of the boundary obligation lives, and form E
  should reuse it rather than re-derive it.
* **`ZK60_PRIVATE_SEAM.md` (S2).** The standalone masked-equality gadget, and
  the direct ancestor of the seam in §B. Its own "Next" line sets the order:
  reserve the endpoints in a pending opening lifecycle, authenticate them to
  actual attention commitments, complete the private arguments, "and only
  then compose one and two full blocks". It also states the one-shot rule
  plainly: "Repeated private Eval/opening on a stable root is not justified
  by this prototype."
* **`ZK60_OPUS_SEAM_REVIEW.md` §2.2, quoting `ZK60_PENDING_FFN.md:63`.** "The
  *cross-block* residual endpoint is a different object — attention
  class-plane reconstruction, not FFN X/z." The cross-block boundary plane is
  the residual reconstructed in the attention class, which is a **third**
  named obligation on top of the equality: the boundary plane's class and
  scale must be the one the next block's `norm_a` expects.
* **The other line's answer, for contrast.** D11 records that the zkVM route
  "recomputes both blocks and their hidden seam inside one program", with the
  public policy binding the complete model and endpoints — i.e. candidate (i),
  on the line that can afford it because it does not commit per-layer planes.

**And one candidate worth naming so nobody proposes it as new: recursion or
aggregation does not solve this — though not for the reason the first draft
gave** [E-19]. Folding 32 block receipts into one shrinks the *receipt*. The
draft said the aggregator "cannot compare the two planes without opening
them"; that is wrong, because a recursive verifier binds two planes with no
PCS opening at all (it verifies both receipts inside a circuit and carries a
commitment as a shared public input), and an aggregator could equally ride a
masked equality on the two receipts' *existing* single openings. **The real
obstruction is the one this page already gives for candidate (iii): a claim
can only be authenticated by an opening under a transcript that already
contains its challenge point**, so binding needs a shared transcript — which
is (i). Recursion additionally does not exist on this line, and it would move
the obligation onto a published boundary root, i.e. straight back onto
D8/D11. Aggregation is a size lever, not a binding lever.

### F.6 The comparison table

| | openings per commitment | who fixes the boundary roots | D8/D11 roots per 32-block pass | memory at 8B [E-4; ≈60 % ESTIMATE] | D12 as written? |
|---|---|---|---:|---|---|
| **(i)** all blocks, one transcript, `g = 32` | **1** everywhere (226 openings per pass) | prover (only the pass's 2 endpoints are caller-fixed) | **2** | **≈ 926 GB resident** (185 GB systematic + 741 GB encoded); needs a disk-backed commitment store | compatible in substance; **one sentence to clarify plus the internal-boundary clause** (item 2's "a block is one proof"; C-8) |
| **(i′)** run length `g`, e.g. 2 or 4 | **1** everywhere (256 openings per pass at `g = 2`) | prover, except `2·32/g` endpoints | `2 · 32/g` (32 at `g = 2`) | **≈ `g × 28.9` GB resident; `g = 2` ≈ 57.9 GB, which does NOT fit a 32 GB card** — and one block alone, ≈ 28.9 GB, is at its limit | same clarification |
| **(ii)** shared boundary commitment | **2** on each boundary commitment | caller | 33 | one block at a time — the cheapest | **NO** — needs D12 item 1 amended, over a measured attack; also needs a second reserved pair and `Q = 512` on that commitment (0.64 bits) |
| **(iii)** own copies + link proof | **2** on each of two boundary commitments, plus an extra proof | caller or prover | 64 | one block at a time | **NO** — same sentence, paid twice; dominated by (ii) |
| **(iv-B5)** public boundary tensor | 1 | n/a, the boundary is public | 0 | cheapest | compatible with D12 but **violates D1** — not P1 |
| **(iv-preflight)** metadata only | n/a | n/a | n/a | free | it is not a binding mechanism at all |
| **no binding** (32 independent block proofs) | 1 | caller, 64 roots | 64 | cheapest | D17 item 4's warning applies verbatim: this is **not a chain**, and it must never be called P1 |

### F.7 Recommendation, and what would change it

*Readable without code.*

**Recommend (i), built as (i′): put consecutive blocks under one proof, and
let the number of blocks per proof be a parameter set by how much memory the
machine has — and build it first at the 125M-class shape, not at 8B.**

The shape is right for a reason that is short. (i) is the only candidate that
needs **no new cryptography and no rule change** — every sealed box is still
opened exactly once, every intermediate box is still made by the prover, and
the only thing that has to change is a sentence in D12 that currently assumes
one block per proof (with C-8's clause). Every other candidate either
publishes the hidden numbers (the public chain), or opens a box twice (the
shared-boundary and link-proof forms), or does not bind the blocks together
at all. And it is now the only *permitted* candidate for a different reason:
**a private run is one transcript end to end** (§F.1), so runs cannot be
joined at all until D18's sealed handle exists.

**But the size at which it is buildable is not the size the first draft
assumed** [E-4]. The price of (i) is memory, and the corrected figures are
five times the ones the recommendation rested on: **one Mistral-width form-E
block is ≈ 28.9 GB resident, two are ≈ 57.9 GB, thirty-two are ≈ 926 GB.**
"Two blocks at a time needs no spilling on a 32 GB card" is withdrawn: two
blocks do not fit, and one block is at the card's limit. About 60 % of those
bytes is the [ESTIMATE] attention half, so the figures carry that band — but
no plausible correction of a 60 % estimate puts 57.9 GB inside 32 GB.

**What follows, plainly. The first feasible target for complete private
blocks in one transcript is the 125M-class shape** (T 512, d 768, f 2048),
where every figure is small, the feed-forward half's private cost is already
measured, and the project's own convergence plan points. **The 8B case is
recorded here as not fitting one consumer GPU under this construction**:
whether it can run with the encoded matrices in host memory is a measurement
nobody has, and its numbers are 60 % estimate. Form E's value at 8B today is
as the design that keeps the feed-forward half fast *if* the attention half
is ever given a device path — necessary for speed there, nowhere near
sufficient (§G.2, [C-10]: the attention half is about **80 %** of the
*private* material at model width and has no device path).

**Simplest first, concretely:** run the corrected small-model experiment
(§D.6) as a committed gate → build one form-E block at the 125M shape →
build **two blocks at the 125M shape under one transcript**, with the same
seam form between them as inside them → measure, and only then ask what a
run costs at 8B. The disk-backed store and the run length at model width are
questions for after a two-block 125M run exists.

**What would change the recommendation — one measurement, one theory result,
and one engineering result:**

1. **Peak resident bytes for one block, then for `g = 2`, at the 125M
   shape.** This is the measurement that gates the build. The equivalent
   reading at Mistral width is no longer a tie-breaker but a **near-certain
   negative** — the arithmetic already says ≈ 57.9 GB against 32 GB — so the
   useful 8B measurement is a *host*-memory run, not a VRAM one. Both are
   VRAM/RSS readings rather than timings, so neither needs a quiesced box.
2. **The double-opening experiment of §D.6 case 9, re-run with two reserved
   pairs and `q_pad = 512` on the boundary commitment.** If two openings of
   such a commitment disclose **0** in the small model, *and* the D11
   recovery attack is re-run against that geometry and fails, candidate (ii)
   would cost 0.64 bits per opening and a new commitment type. Note what it
   would **not** do: it would not make separately finished proofs chainable,
   because the second opening is also *prior history* and is unimplementable
   today (§F.1) — so it changes the memory story inside a run, not the rule
   between runs. It costs a Python afternoon plus a re-run of an existing
   attack script.
3. **A disk-backed commitment store benchmark** — spill and restream one
   Mistral-width commitment's encoded matrix and measure the added seconds.
   With one block already at 28.9 GB this is now the *only* route to a
   multi-block run at 8B, not an optimisation of one; if the cost is small
   relative to the 58.40 s public headline, the boundary question at 8B
   collapses to two caller-fixed roots for the entire model, which is the
   best security position available.

**What the recommendation does *not* do.** It does not close D8/D11 — (i)
reduces the number of caller-fixed roots from 64 to 2 but every remaining one
carries the obligation in full, and D18 rules only *who* fixes them for the
first MVP (the prover), not that they are discharged. It does not make any
chain P1: under D17 item 4, a set of block proofs with no cross-block binding
"is not a chain" and must never be called P1, and that wording applies to
`32/g` unbound proofs exactly as it applies to 32. And it does not make two
finished runs joinable: that needs D18's option B, which is a recorded todo
and is not built.

## G. What it costs

Everything here is **[COUNTED]** — a count multiplied by a constant read out
of source — unless marked **[ESTIMATE]**. Nothing is measured. Each block
names the measurement that would test it.

### G.1 At the 125M shape (T 512, d 768, f 2048; `nb_d = 3`, `nb_f = 1`)

Baselines, all from the mr1 lane's 12 × 512 run [MEASURED,
`ZK60_FSP_MR1_PROGRESS.md` stage 4 on branch `fsp-mr1`]: repaired private
`A_ffn` 585 rows, `H_ffn` 486, `W_ffn` 288, `M_ffn` 16; per-layer proof
7,363,039 B (88,356,464 / 12); GPU prove 4.649 s for 12 layers, 2.05× the
public arm and 1.059× the legacy private arm.

**The seam's own cost, feed-forward side.** Seam slot `(18, 2)`, `L = 38`,
`L + 256 = 294 ≤ 512` ✓; 18 rounds per seam.

| item | rows | bytes | arithmetic |
|---|---:|---:|---|
| `A_ffn`'s 2 reserved pairs | 4 | 8,192 | 4 rows × 256 opened columns × 8 B |
| `M_ffn`'s 2 extra slot pairs | 4 | 8,192 | same |
| `A_ffn`'s 2 extra group vectors | — | 532,480 | 2 × (16,384 + 256) × 16 B |
| 2 seam arguments | — | 1,856 | 2 × (1 + 18·3 + 2 + 1) × 16 B |
| **feed-forward side total** | **8** | **550,720 B = 0.525 MiB** | **+7.5 % of the measured per-layer proof** |

**The seam's own cost, attention side** (with that side at `log_cols 14`):
+4 `A_attn` rows, +2 claim sites, +2 opening groups, 0 slots →
`8,192 + 2 × 16,640 × 16 = 540,672 B`. **Combined seam overhead ≈
1,091,392 B ≈ 1.04 MiB per block.**

**A cost this section does NOT count, and it is the larger one at this
shape** [E-13]: 768 has `nb_d = 3`, which is not a power of two, so §B.2's
re-tiling of the whole `Dom::D` family applies here — ≈ +70 claim sites and
≈ +140 rows on `A_attn` and the same multiplication on 19 `H_attn` helpers,
against the seam's own +2 and +4. The seam is cheap at 125M; **making the
two layouts agree at 125M is not**, and the figure is owed by §H's
layout-only step.

**The comparison that matters.** The accepted caller-fixed-endpoint route
costs **2,017,088 B per layer at 125M** (§3.3 of the endpoints memo), of
which 1,466,368 B is the two dedicated 29-row endpoint commitments and their
openings. **Form E deletes those two commitments** — the counterparty plane
already lives on `A_attn` — and pays 540,672 B on the attention side instead.
**Net: form E's two seams cost about 0.93 MiB less per block than two
caller-fixed endpoints, and they bind to a prover-generated commitment
instead of a caller-fixed one, which is the whole point.** [COUNTED]

*Measurement that would test the bytes:* rung R5-style, the exact frame
length, which is binary-independent and load-independent — the mr1 lane's 30
runs under heavy load produced identical byte counts. No quiesced box needed.

### G.2 At Mistral width (T 512, d 4096, f 14336; `nb_d = 1`, `nb_f = 7`)

**Feed-forward side, known.** `A_ffn` 3,665 → **3,669** rows (the two seam
pairs, `zk.rs:2057-2063`), `H_ffn` 3,030, `W_ffn` 10,752, `M_ffn` 16 → **20**.
Seam slot `(22, 2)`, `L = 46`, `L + 256 = 302 ≤ 512` ✓; 22 rounds.
Seam bytes: `8,192 + 8,192 + 532,480 + 2 × 70 × 16 = 551,104 B`. Committed
rows on this side: **17,471**.

**Attention side, NOT known — [ESTIMATE] only.** There is no model-width
attention layout anywhere in the repository; the `private_block` module's
geometry is `T = 32, D = 16, H = 2, DH = 8, KV = 8, F = 16`, hard-coded as
`pub(crate) const`s with no parameterisation
(`private_block/layout.rs:40-49`). What follows is a plane-count scaling of
the tiny layout, taking Mistral's 32 query heads, 8 KV heads and head
dimension 128, dropping the 11 `Dom::F` planes and `A_MACT` (which move to
the v3 prover) and dropping `A_RDL`, at `n = 16,384`:

| domain | cube at Mistral | planes | rows each | rows |
|---|---:|---:|---:|---:|
| `Dom::D` (T·d) | 2^21 | 34 | 128 | 4,352 |
| `Dom::Q` (T·H_q·dh) | 2^21 | 7 | 128 | 896 |
| `Dom::Kv` (T·H_kv·dh) | 2^19 | 6 | 32 | 192 |
| `Dom::S` (H_q·T²) | 2^23 | 11 | 512 | **5,632** |
| `Dom::T`, `Ht`, `L`, `Tab` | ≤ 2^14 | 10 | 1 | 10 |
| **`A_attn` data rows** | | | | **≈ 11,082** |
| + site pairs (≈ 104 sites) and prox | | | | +210 |
| **`A_attn`** | | | | **≈ 11,292** |
| `H_attn` **data** rows (every helper Fp2, two slices) | | ≈ 45 | | **15,242** |
| + its mask and proximity rows | | | | +≈ 92 |
| **`H_attn`** | | | | **≈ 15,334** |
| `M_attn` | | 23 slots | | 50 |
| **attention side total** | | | | **≈ 26,676 rows** |

[E-20 — the first draft's table put 15,334 against its own prose's 15,242.
15,242 is the **exact** data-row figure; the ≈92 mask rows are now listed
separately, as the `A_attn` rows above already were. The totals 11,082,
11,292 and 26,676 all reproduce exactly.]

**So a form-E block at Mistral width is about 44,100 committed rows of
16,384 words: ≈ 5.79 GB of systematic data and ≈ 23.14 GB encoded at
`inv_rate 4`, and BOTH must be resident until the single opening — ≈ 28.9 GB
per block** (`open_zk` gathers columns from `cm.store`, `pcs.rs:930-942`;
`fold_rows_multi_zk` needs the systematic data, `:863-874`). The attention
half is roughly 60 % of those rows. [ESTIMATE — the feed-forward half's
17,471 rows are [COUNTED] and reproduce the repository's own figures; the
attention half's 26,676 are a scaling of a toy layout and could easily be
wrong by a factor of two in either direction. **So ≈ 60 % of every byte in
every memory figure on this page is an estimate for a layout that does not
exist**, and §F's conclusions inherit that.]

**Two things this estimate says that are probably robust to that factor.**

1. **The attention half is the bigger half at model width, and the
   score-domain planes (`Dom::S`, `H_q·T²`) dominate it** — 5,632 of 11,082
   `A` data rows and 8,192 of 15,242 `H` data rows in the table above. That
   scaling is `H_q·T²` against the feed-forward's `T·f`, so it gets worse
   with context length, not better. It would take a factor-5 error in the
   estimate to overturn this one.
2. **And the claim is UNDERSTATED as stated** [C-10]. 26,676 against 17,471
   is 60 %, but `W_ffn`'s 10,752 rows are the **public weights**. Against the
   feed-forward's *private* commitments alone — `A_ffn` 3,669 + `H_ffn` 3,030
   + `M_ffn` 20 = **6,719 rows** — the attention half is **80 % of the
   private material**, and it has **no device path at all**.
3. **Therefore form E's headline benefit is bounded by Amdahl's law, and the
   bound is tight.** Form E buys the GPU prover for the feed-forward half,
   which is one fifth of the private material. Four fifths of it stays on the
   host, so a form-E block can be *slower* than the number anyone expects,
   and no amount of device work on the feed-forward half moves the total by
   more than that fifth. **Form E is necessary for speed at model width and
   is nowhere near sufficient; the attention half needs a device path of its
   own, and that path does not exist even on paper.** Nothing in the accepted
   documents says otherwise, but nothing says it this plainly either.

**Proof bytes.** The seam adds ≈ 1.09 MiB per block (551,104 B + 540,672 B).
Against the measured legacy private feed-forward per-layer 40,174,324 B
(`1,285,578,368 / 32`), the seam is **+1.37 % of the feed-forward half's
bytes**. The attention half's own receipt bytes at model width are unknown
and will dominate: the tiny form-S block's frame is 2,816,472 B
(`private_block/tests.rs:108`) at 455 + 384 + 50 rows, and the byte model is
`opening(groups, rows) = (groups+1)·(n+Q)·16 + 256·(8 + rows·8 + 32 +
depth·32)` (`private_block/wire.rs:28-36`), which is linear in rows.

### G.3 What stays on the GPU

**Stays on the device** (this is what form E is for): the whole feed-forward
half — the three matmuls, the activation lookup, the product, the
requantisations, and the `A_ffn` / `H_ffn` / `W_ffn` commitments — through
the block-decomposed CUDA path (`layer.rs:1379-1400`, `zk.rs:2685-2690`),
which is the custom line's only measured route to throughput and the source
of the 58.40 s public 8B figure.

**Host-only today, and unchanged by form E:**

* the attention half in its entirety (the native module has no device path);
* **the two seam sumchecks**. Each is `m + 1` rounds of degree 2 over three
  tables of `2^m` Fp2 entries. At Mistral `m = 21`: about `6 × 2^21 ≈
  1.26 × 10^7` Fp2 multiply-adds per seam, plus `eq_table_msb(τ)` of `2^21`
  Fp2 and ≈ 96 MiB of transient table traffic per seam
  (`3 × 2^21 × 16 B`). The endpoints memo models this at **≈ 0.1 s per layer
  for two seams, ±2×** — **+3 %** of a 3.453 s Mistral feed-forward layer
  [MEASURED, `ZK60_CLAUDE_GPU.md:262-265`] — and flags it as "the only large
  host arithmetic left in a GPU layer", i.e. the term most likely to
  surprise. Form E inherits that risk unchanged.

**Two extra Merkle trees per block** (the attention side's `A` and `H`) that
the feed-forward-only pass does not build; their fixed cost is not
row-proportional.

### G.4 What is not known, and the first measurement of each

| unknown | why it is unknown | first measurement |
|---|---|---|
| **the attention half's cost at model width — rows, bytes and seconds** | no model-width attention layout exists; `private_block/layout.rs:40-49` is a fixed toy geometry | a **layout-only** instantiation: widen the layout constants and assert every derived count with **no proof generated**, in the style of `zk60_pending_layout.rs`. Rows and bytes are exact and load-independent, so this needs no quiesced box and no GPU. **Do this before anything else in §G is quoted.** |
| peak resident bytes for one form-E block | both sides' commitments live simultaneously and neither has been built at width | a VRAM reading on one Mistral-width block, GPU, detached, card verified idle, never chained (the WSL VRAM rule) |
| the seam sumchecks' real seconds | host arithmetic, never run at `m = 21` | three new phase lines — `seam argument 0/1`, and the attention side's `commit A`/`commit H` — that sum into the total, as change C9 of the endpoints list specifies |
| the attention half's **lookup soundness term** | never projected at model width; §E.2's whole-proof figure is therefore an upper bound on the bits | a count, not a run: `H_q·T²` score-domain lookups plus the rest, through the same relation D15 uses |
| whether form E is faster than form S at model width | form S has never been run above T32/d16 and form E has never been run at all | the two measurements the construction memo already named (`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md` §B.3): peak resident bytes, one commitment against two, and feed-forward prover wall clock host against device, both at the 125M rung on a quiesced box |

**And one number that is known and cuts against form E at small
geometries.** At T32/d16 the v3 prover's `A` alone is **702 rows** with the
io pairs (`zk_ffn_fresh_io_tests.rs:77`) and `H` is **1,326**
(`:78`) — larger than the *entire* form-S block's 455 + 384. **Form E is a
model-width construction; at the tiny geometry form S wins on every count,
and the accepted decision to build form S first is not disturbed by anything
in this draft.**

## H. A staged build

**The standing condition, from D17 item 2 and the endpoints disposition's
R-2: every accepted path stays frozen and everything here is additive.** The `/2` io profile,
`SeamSpec` and its four module constants, `params()`, `digest()` and
`check_ntt` (`private_seam.rs:28-36`, `:99-105`, `:119-133`, `:164-181`) are
not edited — those constants are hashed into every `SeamSpec::digest()`,
absorbed by the standalone seam transcript and compared by
`into_ffn_endpoint`. The accepted `private_block` module is not edited either
(ruling R-A): form E is grown from a copy, with its own profile string,
schedule digest, example and tests.

**The first build target is a two-block run at the 125M-class shape, under
one transcript, additive, in a module declared inside `hashline::zk`**
(disposition §5 item 3; ruling R-4). Not one block at 8B: at Mistral width
one block is ≈ 28.9 GB resident and two are ≈ 57.9 GB (§F.2), and 80 % of
the private material on that side is attention with no device path (§G.2,
[C-10]). Everything before the target is either a gate or a correctness
harness, and the 8B rungs move behind a model-width attention layout that
does not exist yet, on paper or in code (disposition §5 item 4).

Steps are ordered smallest-self-checking-first. Each names its acceptance
check. Nothing after step 0 starts until step 0 is green.

| # | step | acceptance check |
|---:|---|---|
| **0** | **The §D.6 small-model experiment as REWRITTEN, in Python, no Rust — a COMMITTED gate** (script and output under `results/`, not `/tmp`). Two commitments, an aliased plane, a seam claim per side, brute-force dense rank, predictions written before the runs | the case list of §D.6: **0 for cases 0, 1, 2, 8, 10, 11, 12**; **> 0 for cases 4, 6, 9, 13, 15, 16**; cases 3, 5 and 14 run in their **non-aliased** form (3b) as soundness/simulator conditions, where they do fire. **The gate is the JOINT one** [E-2, R-2]: a genuine cross-commitment joint rank with the shared plane's coordinates identified, asserting `joint == sum of parts` **and** `joint == 0` — case 3b is the reason (joint 8, every per-commitment figure 0). A per-role sum is not the gate and never was. Also run §F.7's variant — two openings of a commitment with two reserved pairs and `q_pad = 512` |
| **1** | **Port `audit_claims` to the feed-forward's claim path** — a **BUILD PRECONDITION** under ruling R-5, not a follow-up, because no external claim may be pushed onto `A_ffn` before it exists | the committed negative "a pair shared by two claims" (`private_block/tests.rs:325`) reproduced on the v3 side and rejected; a seam claim with **no** reserved pair rejected [C-1]; every existing v3 byte gate and frozen digest unmoved |
| **2** | **Layout-only widening of the attention side, at the 125M shape first.** Parameterise the toy geometry; assert every derived count (`A_ROWS`, `H_ROWS`, `M_ROWS`, `A_GROUPS`, `H_GROUPS`, slot lengths, `L + 256 ≤ 512` per slot) at T32/d16 and at 125M, and carry §B.2's `nb_d = 3` re-tiling of the whole `Dom::D` family (≈ +70 sites, ≈ +140 rows) into the counts. **No proof generated** | the tiny counts reproduce 455 / 384 / 50 / 35 / 9 / 23 exactly; the 125M counts are printed and become the [COUNTED] replacement for §G.1's and §G.2's estimates; D16's norm-range rules (limb counts for `D`, `a1`, `a2`; the remainder window) are re-derived at each width and refused where they lapse |
| **3** | **The two-sided plane agreement, as a pure test.** Where `nb_d` is not a power of two (125M, `nb_d = 3`): assert the attention side's `nb_d` sub-planes of `nm` and the v3 layout's `lay.x[c]` enumerate the same flat order (`(t, i')`, token-major, MSB-first), block for block. Where it is (Mistral, `nb_d = 1`; 8192 → 2; 16384 → 4): assert instead the **public index map** `μ_c = eq(ρ_c, c)` reproduces the flat plane's evaluation from the `nb_d` parts | a permutation of either side's tiling makes the assertion fail; the index-map identity holds exactly at random points. This is §B.2 as restated by R-3, pinned before any prover exists |
| **4** | **Externalise the transcript on both sides** (R1, R3 of §B.7), in a module **inside `hashline::zk`** (R-4): the attention side becomes a three-part lifecycle (commit `A`, `M` → pause → its own `(β,γ,α)`, `H`, slots → openings), and the feed-forward side is called through a block-owned entry that passes `&mut Transcript` into the **unsplit** `prepare_layer_zk_v3_inner`. No seam yet | the attention side's split reproduces its **byte-identical** existing receipt when driven end to end; the v3 side reproduces its four frozen 12 × 512 digests (`v2 50cf7bdf..`, `v3 5f368db6..`, `zk 021485e4..`, `zk-v3 40eb5479..`) and the twelve byte gates; the `MaskFunctional` lists of the two `M`s are separately typed or separately checked [C-6] |
| **5** | **One seam only (`nm`), at the tiny geometry, with the attention side's feed-forward planes still present** so the two halves can be cross-checked against each other. A correctness harness, not a product path | honest accept; the counted geometry reproduced exactly (`A_attn` +4 rows, +2 sites, +2 groups; `A_ffn` 702 → 706; `M_ffn` 16 → 20; slot `(10,2)`, `L = 22`) |
| **6** | **Both seams, tiny geometry, feed-forward half moved to the v3 prover.** The first real form-E block, still a harness | honest accept, and the **verifier-side negative battery** below, all green |
| **7** | **One form-E block at the 125M shape, `nb_d = 3`** — layout and one honest proof | the counted geometry of step 2 reproduced; the per-block tamper battery at three blocks (below); peak resident bytes recorded |
| **8** | **A joint-view capture of that 125M form-E receipt** in the `native-all-slots-v1` schema, through `scripts/zk60_native_joint_view.py` | **a HARD GATE**: (a) the per-role figures match §D.5's prediction (`A_attn` 0, `A_ffn` 0, both `H` 2, both `M` 2, `In`/`Out` 0) **and** (b) a **genuine cross-commitment joint rank**, with the `nm` and `z16` coordinates of `A_attn` and `A_ffn` identified, satisfies `joint == sum of parts` and `joint == 0` [E-2] — (a) alone is blind to a blinding source shared across the two commitments; and (c) the **per-slot derived-mask-evaluation identity** of `ZK60_NATIVE_JOINT_VIEW.md` §3.1 holds for **both** masking commitments [E-16], which is the replacement for the first draft's case-8 gate. `k0 = 0` everywhere, every negative control fires, `privacy_property_established` stays false |
| **9** | **THE FIRST BUILD TARGET: two blocks at the 125M shape under one transcript** (candidate (i′) of §F), with the same seam form between them as inside them | the cross-block seam rejects a second block proved on a different `xres2`; two caller-fixed roots for the pair, not four; every commitment opened exactly once (`2 × 7 + 2 = 16` openings); peak resident bytes for `g = 2` recorded; the capture gate of step 8 re-run on the two-block receipt |
| **10** | **A model-width (Mistral) attention layout, on paper and then as a layout-only instantiation** — *before* any further memory or speed claim about complete private blocks at 8B (disposition §5 item 4) | §G.2's 26,676 estimate replaced by a counted figure, or refuted; only then is a Mistral-width single-block run worth scheduling — GPU, detached, card verified idle, never chained (the WSL VRAM rule) — and the arithmetic already predicts ≈ 28.9 GB resident for one block and no fit for two |

**Verifier-side negative tests, named. Every one requires the VERIFIER to
reject, not the prover to refuse.**

| # | tamper | why it is the test that matters |
|---:|---|---|
| N1 | **the feed-forward half proved on a different `nm`**: commit `A_ffn` with `lay.x` set to any plane other than the attention side's `nm`, keep every feed-forward relation internally satisfied | the whole purpose of seam 1. Must be rejected by the seam identity |
| N2 | **a `z16` that differs from the feed-forward's output**: the attention side's `A_Z16` holds a different plane, residual 2 and every class proof still satisfied on that plane | the purpose of seam 2. The analogue of the accepted module's `block_output_cannot_be_chosen` tripwire |
| N3 | **per-block tampers at `nb_d = 3`**: one word altered in block 0, then in block 1, then in the last block, three separate runs | **the test today's code would fail if it were widened naively** (the endpoints disposition's R-5). A single-slice seam rejects the block-0 tamper and *accepts* the other two |
| N4 | **an out-of-class `nm`**: a value outside `[-127, 127]` on the feed-forward's input plane, with the attention side's int8 lookups removed | D12 item 4. Without the attention-side class proof the composed statement is unsound, and this test says so out loud |
| N5 | **the seam challenge drawn too early**: `τ` or `μ` drawn before `absorb_com(A_attn)` or before `absorb_com(A_ffn)` | §B.6's ordering condition; a prover that can see the point before fixing the plane wins |
| N6 | **a caller-fixed root smuggled in for `nm` or `z16`** — i.e. an attempt to reuse the io profile's `ExpectedIo` endpoints for an intermediate | §C.4 finding 1: the most likely implementation error, and it is the forbidden configuration even though the arithmetic is identical. A construction-time refusal |
| N7 | **a shared reserved pair**: the two seam claims on one side given the same pair; a seam claim with no pair of its own; and the two sides' terminals masked from one source | §D.6 cases 4, 15 and 16, now in Rust — each measured **8 Fp**. The shared-source variant is case 3b: it discloses 8 only when the two planes are not equal, so in Rust it is a **soundness/simulator** control, and on `A_ffn` it is caught only once step 1's `audit_claims` port exists |
| N8 | **a second opening of any commitment** | must not type-check where possible (owners moved by value) and must be refused at runtime where it does |
| N9 | **a mis-tiled attention side** (`nm` laid out flat instead of block-wise where `nb_d` is not a power of two), and, where it is, **the index map evaluated at the wrong point** | §B.2 as restated by R-3. Expected to fail the *honest* proof, which is the safe direction — assert that it does, so that a future refactor cannot make it fail silently instead |
| N10 | **a scale-tag mismatch**: `AttnConsts.e_xm ≠ V3Exps.e_x`, or `e_z16` mismatched, with the field words equal | D12 item 5. Field-word equality is not represented-value equality; the refusal must be a constructor refusal against the calibration, not a tag comparison |

**And the floor that travels with every step:** `python3 -m unittest discover
-s tests` plus freeze-check green; the four 12 × 512 digests and the twelve
byte gates unmoved; the 8B digests unmoved (public `dc980e81…4536c` /
1,234,936,956 B, legacy private `930ce9a0…c982e` / 1,285,578,368 B). **A
moved digest is a bug in the change, not a cost of privacy: revert and
record.**

## I. Decisions, open obligations, and what I did not check

### I.1 Decisions for the security owner

**Status after the disposition of 2026-09-19.** The security owner has ruled
on five of these. **Decision 4 is REVERSED** (R-1: two lookup triples, the
frozen prover is not split). Decisions 6 and 10 are **ruled and strengthened**
(R-5 makes the `audit_claims` port a build precondition; R-2 rewrites the
experiment and replaces its case-8 gate). Decision 8 is **ruled with a
changed target** (the 125M shape, and a private run is one transcript end to
end). Two rulings the first draft did not ask for are now binding: **R-3**
(the tiling rule, §B.2) and **R-4** (the module lives inside `hashline::zk`;
the four private items are not made `pub`; every seam claim stays on `A`; the
two `mask_open` functional lists are never mixed and get a check). Decisions
1, 2, 3, 5, 7, 9, 11 and 12 stand as recommended, 9 with an added clause.

**1. Residual 2 lives on the attention side, with `xres1`, `z16` and
`xres2`; exactly two planes cross the seam (`nm` out, `z16` back).**
*Recommend yes.* It is the only placement in which `xres1`'s three consumers
all read one commitment, it keeps the seam count at two, and it keeps both
external endpoints on the module that already has the endpoint machinery.

**2. At model width both sides use the enclosing `LayerParams` —
`log_cols 14 / inv_rate 4 / Q 256` — and one `NttTables` of log 16, each side
checking it through a `check_ntt_for(max_log)`.** *Recommend yes.* Two
sources of truth for one proof's PCS parameters is the pin the endpoints
check flagged as P12; and `NttTables::new(12)` against `new(16)` across the
two halves is closure C6 of the construction memo, which form S dissolved and
form E re-opens. Done additively, leaving the frozen tiny constants
byte-identical.

**3. Both seam CFS slots live on the feed-forward's masking commitment
`M_ffn` (16 → 20 base rows); `M_attn` stays at 50.** *Recommend yes.* The
reservation already exists in committed code (`zk.rs:2172`,
`FIRST_IO_SLOT`), the arity is the feed-forward's cube arity, and it keeps
the attention side's change to `+4 A` rows and `+2` sites. The alternative
(`M_attn` 50 → 54) is equally sound; this is a "reuse what exists" call, not
a security call.

**4. ~~One `(β, γ, α)` triple for both halves, drawn after both `A` and both
`M` roots~~ — REVERSED BY THE SECURITY OWNER (ruling R-1): TWO triples, in
the order `A-attn, M-attn │ [W, A-ffn, M-ffn, (βγα)_ffn, H-ffn] │ (βγα)_attn,
H-attn`.** One shared triple requires both `M` roots before either triple,
and `prepare_layer_zk_v3_inner` absorbs `W → A → M`, **then draws the
triple**, then commits `H`, in one contiguous frozen body (`zk.rs:2542-2556`)
with no insertion point; taking it would mean splitting that function at
`zk.rs:2553`, against D17's rule that accepted paths stay frozen and new work
is additive. Two triples are sound — each side's is drawn after that side's
own `A` and `M`, which is what LogUp needs, and the seam coefficients still
follow every root. **The injectivity audit survives the reversal and becomes
an assertion** [C-7]: the two halves' tag sets are already disjoint by
construction (`tables_attn.rs:29`, `:73-76`), and the cross-side collision
term (≈ `2^41/2^128`) is counted once in §E.2.

**5. A component tag is absorbed before every root (`"A-attn"`, `"M-attn"`,
`"H-attn"`, `"W-ffn"`, `"A-ffn"`, `"M-ffn"`, `"H-ffn"`), and the seam slots
get their own index namespace.** *Recommend yes, as a requirement.* In form S
domain separation is a property; in form E it is an obligation, and the seam
review records that none of it exists today.

**6. `audit_claims` is ported to the v3 claim path before any claim is pushed
onto `A_ffn` from outside the v3 prover — RULED (R-5): a BUILD
PRECONDITION**, the same one D17 set for the private-IO path, together with
the requirement that the counterparty's seam claim carries its own reserved
pair. R-3 already ruled the port; form E is the first construction that makes
it load-bearing, and the measured cost of its absence is **8 Fp** in both
forms the small model can produce — a pair shared between two claims (case
4/16) and a seam claim with no pair at all (case 15) [C-1]. §H step 1.

**7. The attention side keeps its redundant int16-class proof of `z16`
(`A_ZL0`/`A_ZL1`, `c10`).** *Recommend yes.* It costs 4 rows and 512 byte
lookups at the tiny geometry and makes the attention side's statement
independent of the seam's correctness; the seam is the one relation whose
failure would otherwise be silent on that plane.

**8. Chaining: build candidate (i′) — consecutive blocks under one
transcript, run length a parameter, starting at two — AT THE 125M-CLASS
SHAPE, and do not adopt candidate (ii) until the two-openings experiment says
what it costs.** *Ruled, with the target changed.* (i) is the only candidate
needing no new cryptography and no rule change; (ii) and (iii) both open a
commitment twice and would need D12 item 1 amended over a measured attack.
Two things fix the shape and the size. **A private run is one transcript end
to end** — two separately finished private proofs cannot be joined through a
commitment root, so joining runs waits on D18's option B, a recorded todo
that is not built. And on the corrected memory (E-4) a two-block run at
Mistral width needs ≈ 57.9 GB and does not fit a 32 GB card, while one block
at ≈ 28.9 GB is at its limit: **the first feasible target for complete
private blocks in one transcript is the 125M-class shape**, with the 8B case
recorded as not fitting one consumer GPU under this construction and its
numbers ≈ 60 % estimate.

**9. D12 item 2's first clause gets a clarifying amendment if (i′) is built,
WITH the internal-boundary clause [C-8].** *Recommend the wording in §F.2:*
"A block is proved under one transcript, with exactly two external endpoints
per proof; several consecutive blocks may share one transcript, in which case
the proof's two external endpoints are the first block's input and the last
block's output, **and every boundary plane internal to that proof is a hidden
intermediate under item 3 — on commitments the prover generates inside that
same proof, never caller-fixed.**" *Reason:* the substance of D12 is
untouched — a multi-block proof **generalises** item 2, whose target is
gluing two separately finished receipts — but as written the sentence says a
block is one proof, and (i′) makes a block a fraction of one. **The second
clause is not optional**: without it the amendment would license a run whose
internal boundaries sit on caller-fixed roots, which item 3 forbids.

**10. The §D.6 small-model experiment is run before any Rust — RULED (R-2),
and REWRITTEN.** It has now been run once, by the independent check. Two
corrections to the first draft's version of this decision. **Case 8 is not
the stop it was proposed as** [E-16]: a linear model cannot decide the
two-masking-commitments question — an `M` functional touches no data
coordinate whatever the number of `M`s — so that gate moves to the per-slot
derived-mask-evaluation identity on a real receipt (§H step 8). And **three
of the draft's controls cannot fire for an equality seam** [E-1], so "a
control that stops firing is a stop" would have stopped a correct design;
they are reclassified as soundness/simulator conditions and run non-aliased.
**What the experiment must add is the genuine cross-commitment joint rank**
[E-2], asserting `joint == sum of parts` as well as `joint == 0`: the one
new failure mode a seam introduces measured **joint 8 with every per-role
figure 0**. It still costs a Python afternoon, and it is now a committed
gate (§H step 0).

**11. Form E is not built at the tiny geometry as the product path.**
*Recommend yes.* At T32/d16 the v3 prover's `A` and `H` alone (702 + 1,326)
exceed the whole form-S block (455 + 384); form E's only justification is
model width. Build it at the tiny geometry as a **correctness harness** for
steps 5–6 of §H, and say so in the code.

**12. A model-width attention layout is scheduled as its own work item
before any form-E speed OR MEMORY number at 8B is quoted.** *Recommend yes;
the disposition makes it §5 item 4 and §H step 10.* §G.2's estimate says the
attention half is the bigger half at model width — **80 % of the private
material** [C-10] — and has no device path; it is also ≈ 60 % of every
memory figure that now decides the build target. If it is right, form E
alone does not deliver the speed it is being built for, and the project
should know that before it spends the implementation weeks.

### I.2 Open obligations

1. **D8 / D11 — the caller-fixed endpoint-root obligation — is OPEN**, and
   form E has two such roots per block (`In`, `Out`). Nothing here closes any
   part of it. Candidate (i′) reduces the count per pass; it does not
   discharge the obligation. **D18 says only which product they bind**: for
   the first MVP the *prover* seals the hidden input and output at proof
   time, so the caller-fixed configuration does not physically arise yet;
   sealing in advance by a third party — and joining two finished runs — both
   need the salted handle that is not a polynomial-commitment root, which is
   a recorded todo and is not built.
2. **U-2: no joint analysis covers a seam's opening groups landing on rows
   other groups already open** (`ZK60_OPUS_SEAM_REVIEW.md:639-646`). §D.6 is
   the first thing that would.
3. **U-3: the sequential-kernel lemma's joint hypothesis** stays open, and
   form E adds two more channels to a joint hypothesis that has never been
   discharged.
4. **U-14: two masking commitments reopen the CFS-channel question jointly.**
   §D.3 states it. **The linear model cannot decide it** [E-16] — an `M`
   opening's published functional touches no data coordinate whatever the
   number of `M`s — so the experiment is the **nonlinear** per-slot
   derived-mask-evaluation identity of `ZK60_NATIVE_JOINT_VIEW.md` §3.1,
   asserted for both masking commitments on a real form-E receipt (§H step
   8). Nothing has measured it.
5. **The attention half's lookup soundness term at model width is not
   projected**, so §E.2's ≈ 94 bits is an upper bound on the bits, not a
   figure.
6. **The hash layer** — now four prover roots plus two caller roots per
   block, six sets of 256 leaf salts and six path families — is outside every
   linear analysis this project has.
7. **Nonlinearity**: the seam identity is degree 2 in the terminals and the
   PCS↔CFS link is degree up to 4; the redundancy argument of
   `ZK60_NATIVE_JOINT_VIEW.md` §3.1 is a numerically checked identity, and
   there is no form-E receipt to check it on.
8. **D16's widening rules are owed at each new width** (limb counts for `D`,
   `a1`, `a2`; the exact remainder window; the wraparound premise re-derived;
   the alias tamper tests green at every widened profile). §H step 2 is where
   they land.
9. **The cross-block residual's class and scale** — "attention class-plane
   reconstruction, not FFN X/z" (`ZK60_PENDING_FFN.md:63`) — is a third
   obligation at every block boundary, separate from the equality and from
   the metadata preflight.
10. **No privacy property is established by this page**, and none of the
    figures in §G is measured.

### I.3 What I did not check

* **I read no bodies.** `masked_prove`, `extension`, `mask_open`/
  `mask_verify`, `sumcheck::verify`, `group_zclaims`, `zpart_weights`,
  `encode_row_zk` — I read their call sites, their signatures and their
  contracts, not their implementations. If one of them carries a size
  assumption or a two-commitment assumption, this draft would miss it. The
  same caveat the endpoints memo gave applies verbatim here.
* **I ran nothing.** No build, no test, no proof, no benchmark. Every
  [COUNTED] figure is arithmetic over constants read from source; every
  [ESTIMATE] is a scaling.
* **I did not verify the attention-side plane inventory independently.** The
  81-plane / 51-helper / 23-slot / 120-site / 51-site structure of
  `private_block` comes from a delegated read of `layout.rs`, `argument.rs`,
  `protocol.rs` and `witness.rs`; I re-checked the geometry constants, the
  PCS parameters, the NTT table sizes and the transcript skeleton myself, and
  the two counts I lean on hardest (`M_ffn` 16 → 20 and the one-pair-per-site
  rule) I re-derived from `zk.rs:435` and `protocol.rs:89-133`.
* **§G.2's attention-side row estimate is a scaling of a toy layout**, not a
  derivation from any existing model-width layout, because none exists. It
  could be wrong by a factor of two either way. **About 60 % of every memory
  figure on this page is that estimate.** Everything that rests on it — the
  "attention is the bigger half" claim (and [C-10]'s sharper "80 % of the
  private material"), the ≈ 23.14 GB encoded and ≈ 28.9 GB resident figures
  per block, candidate (i)'s memory arithmetic in §F and the ruling that the
  first feasible target is the 125M shape — inherits that uncertainty. §H
  step 2 replaces it with a counted figure at the 125M shape at no cost;
  §H step 10 owes the model-width one.
* **I did not re-derive the D15 projection**, only reused its published
  terms, and I did not check the 0.03-bit reconciliation of the two
  per-opening conventions beyond reproducing the arithmetic.
* **I did not examine the GPU kernels.** Whether `layer.rs`'s `dev_shape`
  gate and the block-decomposed CUDA path tolerate two extra mask pairs and
  two extra opening groups on `A_ffn` is asserted from the row arithmetic,
  not from the kernel source.
* **I did not consider P3** (hidden weights) anywhere: `W_ffn`'s hiding
  variant, its mask rows and its contribution to the disclosed dimension are
  out of scope, and the attention side's weight commitment does not exist.
* **I did not cost verification** — verifier seconds, verifier memory, or the
  composed frame's decode bounds — beyond noting that `zk_ffn_fresh_wire.rs`
  cannot express the composed receipt.

**(draft complete)**

## Revision record (2026-09-19)

One row per item of `ZK60_PRIVATE_BLOCK_FORM_E_CHECK.md` §10 and of
`ZK60_PRIVATE_BLOCK_FORM_E_DISPOSITION.md` §2–§3, with the section(s) this
text changed and what changed there. Nothing else in the memo was edited.
Every caveat the first draft carried — no privacy property established, D8
and D11 open, [COUNTED] / [ESTIMATE] / [MEASURED] labels — survives, and two
were strengthened (the ≈ 60 % estimate band on every memory figure, and the
label on §D.5's 8 Fp).

| item | section(s) changed | what changed |
|---|---|---|
| **E-1** | §D.6, §H step 0 | Acceptance rewritten: 0 for cases 0, 1, 2, 8, 10, 11, 12; > 0 for 4, 6, 9, 13, 15, 16; the first draft's cases 3, 5 and 7 reclassified as soundness/simulator conditions, run in their non-aliased form (3b), where they do fire (8 Fp). "A control that stops firing is a stop" no longer applies to a control that cannot fire for an equality seam |
| **E-2** | §H step 8 (was step 9), §D.4, §D.6 | The capture gate now computes a **genuine cross-commitment joint rank** with the shared plane's coordinates identified and asserts `joint == sum of parts` as well as `joint == 0`; the reason is stated (a blinding source shared across the two commitments measured joint 8 with every per-role figure 0) |
| **E-3** | §B.2 | The `Dom::Db` proposal withdrawn: it does not type-check, because `nm` and `z16` are read in one pointwise term with 35 flat planes on one cube. Restated as the **whole `Dom::D` family re-tiling together** — 35 A planes, 19 helpers, the public `gamma` vectors (the public-statement digest moves) and the batched zero-check |
| **E-4** | §0, §F.2, §F.6, §F.7, §G.2, §I.3 | Every memory figure replaced with the corrected ones: one block ≈ **28.9 GB** resident (5.79 systematic + 23.14 encoded), two ≈ **57.9 GB**, thirty-two ≈ **926 GB**. "About 11 GB … plausible on a 32 GB card" and "two blocks at a time needs no spilling" withdrawn; §F.7's plan and its measurement 1 rebuilt on the 125M shape; ≈ 60 % of the bytes labelled an estimate for an attention layout that does not exist |
| **E-5** | §B.6, §B.7 R1, §I.1 decision 4 | Two `(β, γ, α)` triples in R-1's order; `prepare_layer_zk_v3_inner` is **not** split; R1's "wrapper change, not a prover change" qualified to hold only because of that choice; decision 4 marked **reversed by the security owner** |
| **E-6** | §C.2, §D.5, §E.2 | `W_ffn` is opened in **both** modes (plain under P1, hiding under P3); "not opened (P1)" removed in all three places; the count of nine openings per block unchanged, with the conservatism of charging all nine 2^-105.609 now stated |
| **E-7** | §B.5 | The 125M largest slot corrected from "zero-check D (18,4), `L = 74`" to **zero-check F (21,4), `L = 86`**; conclusion unchanged (`86 + 256 ≤ 512`) |
| **E-8** | §B.2 | Difference 2 restated: at the only geometry where both provers exist the parameters are identical (8/8/256); the 14/4/256 figures are the binary's defaults. Decision 2 stands |
| **E-9** | §B.6 steps 21–26 and its bullets | The openings put in a **reachable** order, with `PendingV3::finish` named as one atomic call that performs `M-ffn, W, A-ffn, H-ffn` contiguously; the §C.2 table's step references follow |
| **E-10** | §B.6 step 11 | The `A-ffn` absorb carries root and **rows only**; `log_cols` is stated to be bound through the step-4 `"parameters"` absorb |
| **E-11** | §B.2 | Citation corrected to `private_block/layout.rs:79-80` (the `Dom::D` doc comment); `:202-214` identified as `a_dom()` |
| **E-12** | §D.4, §E.1 | The `zk.rs:1961-1975` comment identified as the **P3 W-block** mask-row documentation about two *different* blocks' evaluations; `c = 0` and slot length reclassified as soundness/simulator conditions (measured 0); `e ≠ 0` kept as a hiding condition (measured 8 Fp) |
| **E-13** | §B.2, §D.1, §G.1 | "Costs nothing" struck and replaced with the measured multiplication (≈ +70 claim sites, ≈ +140 `A_attn` rows at `nb_d = 3`, plus the same on 19 `H` helpers); the *relative* claim — free against any other tiling at a non-power-of-two `T·d` — kept, since it was right; §D.1 and §G.1 now carry the `nb_d` multiplication as an owed figure |
| **E-14** | §B.2, §B.3 | The constraint scoped to *"at any width where `nb_d` is not a power of two"*; the public index map `μ_c := eq(ρ_c, c)` named as the cheaper route at `nb_d ∈ {1, 2, 4}`, with no re-tiling and no extra draws |
| **E-15** | §B.7 R6 | Two of the five frame constants corrected (`c.len() != self.mask_rows`, computed; `self.a_groups`, not 5 — the hard-coded 5 is on `H`), and the real model-width blockers named (`groups(.., 512)`, `p.len() == 11`, `*j < 2048`, `p.len() != 12`) |
| **E-16** | §D.3, §D.6, §H step 8, §I.1 decision 10, §I.2 item 4 | Case 8 replaced by the per-slot **derived-mask-evaluation identity** asserted for **both** masking commitments on a real form-E receipt; stated that a linear model cannot decide the question at all, so the 0 it returns is a property of the instrument |
| **E-17** | §B.7 "what cannot be restructured" item 2 | Five citations corrected to `zk.rs:2537`, `:2548`, `:2702`, `protocol.rs:316`, `:324`; substance unchanged |
| **E-18** | §C.2 | The move-semantics guarantee restated as `PendingV3::finish(mut self, ..)` owning `mc`/`a`/`h` and dropping them at `zk.rs:2310`, `:2326`, `:2331`; the wrong citation (`zk.rs:3219-3226`, function 2's predicate tables) removed |
| **E-19** | §F.5 | The recursion dismissal's *reason* replaced: a recursive verifier binds without any PCS opening; the real obstruction is that a claim can only be authenticated under a transcript already containing its challenge point, plus the fact that recursion moves the obligation onto a published boundary root |
| **E-20** | §G.2 | `H_attn` split into **15,242** exact data rows plus ≈ 92 mask rows, as the `A_attn` rows already were; the ≈ 15,334 subtotal kept so that 11,082 / 11,292 / 26,676 still reproduce exactly |
| **C-1** | §B.5, §D.2, §H step 1, §I.1 decision 6, negative test N7 | Added: the counterparty's seam claim must carry its own reserved pair, quantified at **8 Fp** without one (case 15), with case 16 (two seams sharing one pair) also 8 and caught today on `A_attn` only; made a build precondition with the `audit_claims` port |
| **C-2** | §D.4 step 1 | Added: the stage-4 argument restated **per channel** — the seam's round channel has data support on both commitments while its randomness lives only on `M_ffn`'s slot; the decomposition still holds and now says so |
| **C-3** | §D.4 (new paragraph), §D.6 | Added: the structural reason the answer is 0 — on an honest witness the tables are pointwise equal, `v0·(v1 − v2)` vanishes identically, every masked round is exactly `c·g_j(X)`, `γ` carries no data term, and only the two masked terminals carry data, each under its own pair |
| **C-4** | §B.7 (new R-4 block), §H step 4 | Added: the module is declared **inside `hashline::zk`**; making `PendingV3`, `prepare_layer_zk_v3_inner` and `verify_layer_zk_v3_with_seams` `pub` is refused |
| **C-5** | §B.7 (R-4 block) | Added: `before_openings` exposes `ac` but not `hc`, so every seam claim stays on `A` |
| **C-6** | §B.7 (R-4 block), §D.3, §H step 4 | Added: the two `mask_open` calls draw two separate θ; the two `MaskFunctional` lists must never be mixed, and that gets a check, which does not exist today |
| **C-7** | §B.6 (new bullet), §E.2, §I.1 decision 4 | Added: the tag sets are already disjoint by construction, the audit becomes an assertion, and the cross-side LogUp collision term (≈ `2^41/2^128`) is counted once |
| **C-8** | §F.2, §I.1 decision 9 | Added to the D12 item 2 amendment: every boundary plane internal to a multi-block proof is a hidden intermediate under item 3, never caller-fixed |
| **C-9** | §F.2, §F.6, §E.2 | Added: a `g`-block proof has two endpoint commitments for the whole proof, so 256 openings per pass at `g = 2` and 226 at `g = 32` against 288 — a small soundness gain now claimed |
| **C-10** | §G.2, §F.7, §H intro, §I.1 decision 12, §I.3 | Sharpened: against the feed-forward's *private* commitments alone (3,669 + 3,030 + 20 = 6,719 rows) the attention half is **80 %** of the private material, not 60 %, and it has no device path |
| **C-11** | §D.5 | Added: the "8 Fp, all of it public identity" is an **accounting sum under a convention**, not a measurement; the PCS channel measures 0 on both sides jointly and none of the 8 is the seam |
| **R-1** | §B.6, §B.7 R1/R3, §I.1 decision 4 | Applied: two lookup triples, the order `A-attn, M-attn │ [W, A-ffn, M-ffn, (βγα)_ffn, H-ffn] │ (βγα)_attn, H-attn`, then the arguments, the seams and the openings in E-9's reachable order; the attention-side copy becomes a three-part lifecycle |
| **R-2** | §D.6, §H steps 0 and 8, §I.1 decision 10 | Applied: the experiment rewritten, the three reclassified controls run non-aliased, the joint-rank assertion added, the two-masking-commitments case replaced by the nonlinear identity on a real receipt |
| **R-3** | §B.2, §B.3, §D.1, §G.1 | Applied: public index map where the block count is a power of two; the whole `Dom::D` family re-tiles where it is not, with the corrected cost; "costs nothing" struck |
| **R-4** | §B.7 (new block), §H step 4, §I.1 header | Applied: module inside `hashline::zk`, the four private items stay private, every seam claim on `A`, the two `mask_open` functional lists never mixed and checked |
| **R-5** | §B.5, §C.2, §D.2, §H step 1, §I.1 decision 6 | Applied: the counterparty's seam claim carries its own reserved pair, and `audit_claims` is ported to the feed-forward's claim path as a **build precondition** |
| **§F rewrite** | §0, §F.1, §F.2, §F.5, §F.6, §F.7, §I.1 decision 8, §I.2 item 1 | Rewritten to the disposition's §3: a private run is **one transcript end to end**; the boundary between two runs is a root one proof opens as its output and the next would open as its input — a second opening, also prior history, unimplementable today — so joining runs needs D18's sealed handle (a recorded todo, not built); D12 item 2 is generalised, with C-8's clause; candidates and opening counts kept as corrected (C-9); on the corrected memory **the first feasible target for complete private blocks in one transcript is the 125M-class shape**, with the 8B case recorded as not fitting one consumer GPU under this construction and its numbers ≈ 60 % estimate |
| **§H rewrite** | §H intro, steps 0–10, N7, N9 | The first build target is a **two-block run at the 125M shape**, additive, inside `hashline::zk`, preceded by the corrected small-model experiment as a committed gate; the `audit_claims` port moved to step 1 as a precondition; the 8B rungs moved behind a model-width attention layout that does not exist |
| **Status line** | page header | Replaced with the disposition's status: core accepted, not yet a design to build; errata, conditions and rulings applied; not a privacy acceptance; D8 and D11 open; paper only |
| *(coherence only)* | §0 naming note, §B.1, §B.2, §B.7, §D.2, §E.4, §H, N3 | Applying R-1 … R-5 collided with this page's existing citations of the **endpoints-at-scale** disposition's own R-1 … R-5. Unqualified R-x now means the form-E disposition; the older ones are written out as "the endpoints disposition's R-x". No claim changed |
| *(coherence only)* | §B.6 step numbers, §C.2 table, §B.7, §E.3, §G.4 and §I cross-references | Step and section references renumbered to follow the reordered transcript (E-5, E-9) and the reordered build (§H). No claim changed |
| **R-6** *(security owner, after the revision; found by the errata editor)* | §B.6 (ruling paragraph, steps 7 and 9a) | The feed-forward's statement absorb cannot precede the attention roots, because it is the first act of the unsplit frozen function (`zk.rs:2364` inside `prepare_layer_zk_v3_inner`, `zk.rs:2337`). Moved to step 9a; the wrapper's step-3 digest must cover the exact `StatementV3` bytes, with a verifier-side test that a disagreement rejects |
| *(security owner, after the revision; found by the errata editor)* | §D.5, the `A_attn` row | The `rank(ρ)` counts 72 → 76 are marked as the tiny geometry's; they must be recounted where R-3 re-tiles |
