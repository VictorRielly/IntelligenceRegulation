# ZK60 — Tier 2: the feed-forward half of the composed private block, in the attention module's idiom

**Status: ACCEPTED AS THE DESIGN TO BUILD, per `ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md` (security owner, 2026-09-19), with errata E-1 … E-22 of `ZK60_PRIVATE_BLOCK_CONSTRUCTION_TIER2_CHECK.md` and rulings R-A and R-B applied in this text. Not a privacy acceptance; no privacy property is established; no speed claim. Drafted by delegated Opus agents.** Extends `ZK60_PRIVATE_BLOCK_CONSTRUCTION.md` section C.5.

| | |
|---|---|
| Worktree / branch | `/home/victor/wt-zk60-attention-compile`, `zk60-attention-compile` |
| Extends | [`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md`](ZK60_PRIVATE_BLOCK_CONSTRUCTION.md) §C.5 ("Tier 2 … `[ESTIMATE]`"). Tier 1 is that memo's §C.1–§C.4 (`norm_m` + residual 2); this memo is the feed-forward half |
| Binding rule | [D12](ZK60_DECISIONS.md) — one proof, one transcript, two external endpoints (`x_in`, `xres2`), no commitment opened twice, hidden intermediates only on prover-generated commitments, `norm_m` proves its output int8, endpoint scales tied to the approved calibration |
| Idiom | the built component: `hashline/src/private_attention/{layout.rs, argument.rs, protocol.rs, witness.rs}`; its rules: [`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md`](ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md), [`…_NATIVE.md`](ZK60_PRIVATE_ATTENTION_NATIVE.md), [`…_DISPOSITION.md`](ZK60_PRIVATE_ATTENTION_NATIVE_DISPOSITION.md), [`…_REVIEW_R2.md`](ZK60_PRIVATE_ATTENTION_NATIVE_REVIEW_R2.md) |
| What this is | a **design**, precise enough to implement and to run the rank / CFS / inventory tools against. Not an implementation, not a privacy acceptance, not a speed claim. Nothing was built, run or measured |

## 0. What this is, and the hole it closes

Plain words first. Tier 1 grows the built private-attention component until it
holds the second RMS norm (`norm_m`, whose output is called `nm`) and the second
residual (`xres2 = xres1 + z16`). It stops there. The plane that holds `z16` —
the feed-forward's output — is, in Tier 1, a plane nobody constrains. A prover
can write *any* values into it, add them to `xres1`, prove the sum is in the
int16 class, and bind that sum to the block's output endpoint. Every check in
Tier 1 passes. The block's output is whatever the prover wanted.

That is not an unfinished table; it is a soundness hole. The draft says so
itself: "Residual 2 does **not** prove `z16 ∈ int16`; the feed-forward half
does … Under form (S) that obligation moves into Tier 2 (§C.5) and must be
discharged there — it is listed as an open item, not as done"
(`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md:501-506`). The class is the smaller half
of it. The larger half is that nothing ties `z16` to `nm` at all.

This memo closes it. It designs the five feed-forward relations as planes,
lookups, slots and hosts on the *same* `A`, `H` and `M` commitments, under the
*same* single transcript, each commitment still opened once — "form S" of the
draft's §B.1, which the security owner has agreed to. After Tier 2 the chain
from the block's input endpoint to its output endpoint is closed link by link:

```
x_in --(SC_IO_IN)-- A_X --(norm_a)-- A_Y --(QKV,RoPE,softmax,PV,Wo)-- A_AO
      --(residual 1, c5)-- A_X1 --(norm_m, c6/c7)-- A_YM = nm
      --(gate matmul + requant)-- A_G8 --(activation lookup)-- A_A16
      --(up matmul)-- A_U16 ; (A_A16 x A_U16, requant) -- A_H16
      --(down matmul + requant)-- A_Z16
      --(residual 2, c9)-- A_X2 --(SC_IO_OUT)-- xres2
```

Every arrow is a relation proved inside one sumcheck slot at one random point,
and every plane named is a plane of the prover's own `A` commitment. No value
in that chain is ever compared in the clear, and no commitment is opened twice.

**Which files change (ruling R-A).** Every `layout.rs`, `argument.rs`,
`protocol.rs`, `witness.rs` and `wire.rs` named below is the **block module's
own copy**: the block is built as a new module, `hashline/src/private_block.rs`
and `hashline/src/private_block/{layout,witness,argument,protocol,wire}.rs`,
grown from a copy of the attention module, with its own example and test file
(`ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md` §2, R-A, and
`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md` §B.1). **`hashline/src/private_attention.rs`
and `hashline/src/private_attention/*` are not edited**, so the accepted
component's receipt, tests and R-1 / R-2 records stay valid byte for byte; the
`:line` citations throughout this memo point at the attention module, which is
the source the copy is grown from. One consequence for the tools:
`scripts/zk60_attention_native_inventory.py` must take the **module path as a
parameter**, or it keeps inventorying the attention module while the block
grows beside it.

**How to read the numbers.** Another agent is independently checking Tier 1's
counts (390 `A` rows, 332 `H` rows, 102 `A` sites, 42 `H` sites, 19 slots, 5
host groups, 42 `M` rows, 29 functionals). Every count in §D is therefore
stated **as a delta on Tier 1 first** and as a whole-block total second, so a
correction to Tier 1 propagates by addition and nothing here has to be
re-derived. Where I found a Tier-1 claim wrong I say so in place (§E and §I.1
item 14 carry the two).

## A. The relations

Every identity below is read out of `private-block-kernel/src/lib.rs`, which is
the integer reference ("The result must equal `FixedCausalOracle::build`
exactly", `:10-12`). The feed-forward is `:627-645`; its shift constants are
`calib::SH_G = 7`, `SH_U = 0`, `SH_H = 14`, `SH_Z = 6` (`:81-84`); the classes
are `I8 = (-128, 127)`, `I16 = (-32768, 32767)` and the attention subset
`I8N = (-127, 127)` (`:93-96`). I confirmed each from the source rather than
from the draft's summary, and one of them differs from what one would guess
(see A.2).

### A.1 The requantization identity, derived from the kernel

`requant(acc, sh)` (`private-block-kernel/src/lib.rs:294-308`):

```
sh > 0 :  y = (acc + 2^(sh-1)) >> sh          // arithmetic shift = floor division
sh <= 0:  y = acc * 2^(-sh)                   // exact up-scaling, no rounding
```

For `sh > 0`, writing `r' = (acc + 2^(sh-1)) − y·2^sh`, the shift gives
`r' ∈ [0, 2^sh)` and therefore the **exact integer identity**

```
acc  =  2^sh · y  +  r'  −  2^(sh−1),        r' ∈ [0, 2^sh)
```

`r'` is the *biased* remainder. The equivalent balanced form
`acc = 2^sh·y + r`, `r = r' − 2^(sh−1) ∈ [−2^(sh−1), 2^(sh−1))`, is what the
existing feed-forward prover uses (`hashline/src/export_v3.rs:296-305`, tested
at `:436-454`; `layer.rs:1194-1201` states the equivalence). **The attention
module uses the biased form**, because a biased remainder is a non-negative
integer and so decomposes into byte limbs that the module's single 256-entry
`U8` table can range-prove: the built `SC_QZC` host term is literally
`2^SH_QKV·q8 + rql − 2^(SH_QKV−1)` (`argument.rs:679`), and `witness.rs:56-68`
fills the remainder plane with `rem + (1 << (sh − 1))`. Tier 2 follows the
module, not the existing feed-forward prover. Every remainder plane below holds
`r'`, never `r`.

`requant_all` (`:312-321`) applies `requant` elementwise and **refuses the whole
site** if any result leaves the class — "NO clamping: an out-of-class value is a
refusal, never a saturated result" (`:27-28`). So each class below is a
*refusal condition of the kernel*, which the proof must reproduce as a range
obligation, not as a hint.

`sh <= 0` is the branch that matters for the up matmul: `requant(acc, 0)` is
`shl(acc, 0) = acc` (`:299-300`), exactly, with no remainder at all.

### A.2 R1 — the gate matmul

Kernel `:627-629`. `matmul_in_out(&nm, &w.wg_t, D, F, &mut g)` then
`requant_all(&mut g, SH_G, I8, "FFN gate")`. `matmul_in_out` (`:363-377`) is
`out[t,j] = Σ_i x[t,i]·w[i,j]`, i.e. **`wg_t` is stored (input, output)
row-major**, `wg_t[i·F + j]`, unlike the attention matrices which are
(output, input) (`:127-129`, and the oracle comment at
`causal_oracle.rs:199-200`). With `t ∈ [0,32)`, `i ∈ [0,16)` (the `d` axis),
`j ∈ [0,16)` (the `f` axis):

```
gacc[t,j]  =  Σ_{i<16} nm[t,i] · Wg[i,j]                       (exact, over Z)
gacc[t,j]  =  2^7 · g8[t,j]  +  rg[t,j]  −  2^6
             g8 ∈ [−128, 127]        class I8
             rg ∈ [0, 2^7)           biased remainder
```

**The class is `I8`, not the attention subset `I8N`.** `requant_all(&mut g,
SH_G, I8, "FFN gate")` at `:629` passes `I8 = (-128, 127)`, which *includes*
`−128`; every attention quantity uses `I8N = (-127, 127)` and the module's
`sym()` helper (`layout.rs:193-195`) proves exactly `[−127, 127]`. Using
`sym(A_G8)` would be a **completeness bug**: an honest `g8 = −128` would be
unprovable. This is the one place where copying the attention idiom verbatim
would be wrong, and §B.3 handles it — for free, as it happens (A.3).

Refusals reproduced: `KernelError::Range("FFN gate")` when `g8 ∉ [−128,127]`;
also `Range("FFN gate")` at `:635-636` when `g8 + 128` is not a valid table
index, which is the same condition.

### A.3 R2 — the activation lookup

Kernel `:633-637`:

```
a[t,j]  =  act[ g8[t,j] + 128 ],     act: [i16; 256]   (PublicTables, :182)
```

This is a **pair** lookup: the index `g8 + 128` and the value `a` must come from
the *same* row of one public 256-entry table. The module already proves exactly
this shape once, for the exp table: the table's public values are
`i + β·exp[i] + g_exp` (`argument.rs:505-507`) and the witness-side value is
`δ + β·E + g_exp` (`:721`), with `β` a Fiat–Shamir challenge drawn once at
`protocol.rs:310` and `g_exp = γ·TAG_EXP` a per-table tag (`:314`). Matching the
two multisets for random `α`, `β` forces both coordinates to agree. Tier 2 uses
the identical construction with a third tag:

```
witness value :  (g8 + 128)  +  β · a16  +  g_act
table values  :  i           +  β · act[i] + g_act ,   i ∈ [0, 256)
g_act = γ · TAG_ACT
```

Two facts fall out of the single lookup, and both are needed:

1. `g8 + 128 = i ∈ [0, 256)`, i.e. **`g8 ∈ [−128, 127]`** — R1's class, with no
   separate range lookup and no `sym()`. It is the right window, `I8` not
   `I8N`, because the table has 256 rows.
2. `a16 = act[g8 + 128]` — R2 itself.

It is also the reason `a16` needs no range *plane* at all: its magnitude bound
`|a16| ≤ 32768` is the value range of the public, digested table. **But that
bound must be enforced by the proof's own public statement, not assumed of the
caller's words (erratum E-2, BLOCKING).** The kernel's `act: [i16; 256]`
(`lib.rs:182`) is a type in a crate the proof never runs, and the public
statement carries the analogous exp table as `exp: Vec<i64>`
(`private_attention.rs:66`) whose value range is enforced by an **explicit
structural check**, `exp.iter().any(|e| !(0..=one_e).contains(e))` at
`private_attention.rs:97-99`. So `BlockPublic::new` must validate
`act.iter().all(|v| (-32768..=32767).contains(v))` — or hold `act: [i16; 256]`
— mirroring that check (§F, §E and decision 7 carry the same condition).
Without it `a16`'s class is a caller's promise, §E items 5 and 6 are
unfounded, `f0` can wrap `p`, and `h16` is no longer pinned. With it, the
conclusion stands. The existing feed-forward prover agrees that no *witness*
range plane is needed: its LogUp helper specs cover `g8`/`a16` (as one fused
pair), `u16`, `h16` and `z`/`rd`, and `a16` never appears in a class lookup of
its own (`hashline/src/layer.rs:1395-1400`, `c_hg` at `:1695`). The R-2 review
records the same reasoning for `A_E`, the exp-table output — and names the
public table validation as half of the reason
(`ZK60_PRIVATE_ATTENTION_NATIVE_REVIEW_R2.md:133`).

### A.4 R3 — the up matmul, and what `SH_U = 0` removes

Kernel `:630-632`: `matmul_in_out(&nm, &w.wu_t, D, F, &mut u)` then
`requant_all(&mut u, SH_U, I16, "FFN up")` with `SH_U = 0`.

```
uacc[t,j]  =  Σ_{i<16} nm[t,i] · Wu[i,j]
u16[t,j]   =  uacc[t,j]                       exactly  (requant :299-300 at sh = 0)
u16        ∈  [−32768, 32767]                 class I16, kernel refusal "FFN up"
```

**`SH_U = 0` removes the up remainder plane entirely.** There is no `ru`, no
byte limbs for it, no lookups for it, and the host term that reconstructs
`uacc` carries no `2^sh` coefficient and no `−2^(sh−1)` constant: it is just
`u16`. `export_v3::requant_round` agrees — at `sh <= 0` it returns an
all-zero remainder vector (`:297-299`) — and the existing prover commits that
column all-zero over a one-row window (`layer.rs:1202-1205`). Committing an
identically-zero plane and proving it is in `{0}` is pure cost; the module has
no such plane and Tier 2 adds none. What remains is the **int16 class of
`u16`**, which is a real obligation and is proved by two byte limbs with the
offset 32768, exactly as `x_in`, `ao` and `xres1` are (`layout.rs:226`, `:232`,
premise at `:204-206`).

### A.5 R4 — the product

Kernel `:638-642`: `hh[idx] = mul(a[idx], u[idx])` then
`requant_all(&mut hh, SH_H, I16, "FFN product")`, `SH_H = 14`.

```
hacc[t,j]  =  a16[t,j] · u16[t,j]                             (exact, over Z)
hacc[t,j]  =  2^14 · h16[t,j]  +  rh[t,j]  −  2^13
             h16 ∈ [−32768, 32767]      class I16
             rh  ∈ [0, 2^14)            biased remainder
```

This is the module's only *product of two private planes on the same domain*
outside the two bilinear slots. It is proved as a degree-2 term of a
zero-check, not as a bilinear sumcheck: the pattern is `SC_TZC`'s
`dsq − d·d` (`argument.rs:536`) and `SC_DZC`'s `2^(tn+1)·y·D`
(`argument.rs:632`), both private×private under a public `eq(τ)` factor with
one extension round. `SC_PV`'s two-extension-round treatment
(`argument.rs:598-610`) is for a product summed over a *different* axis than
the one the zero-check runs on; that is not the case here.

Refusal: `KernelError::Range("FFN product")`.

### A.6 R5 — the down matmul

Kernel `:643-645`: `matmul_in_out(&hh, &w.wd_t, F, D, &mut z)` then
`requant_all(&mut z, SH_Z, I16, "FFN down")`, `SH_Z = 6`. `wd_t` is (input,
output) too, `wd_t[j·D + i]`.

```
zacc[t,i]  =  Σ_{j<16} h16[t,j] · Wd[j,i]
zacc[t,i]  =  2^6 · z16[t,i]  +  rd[t,i]  −  2^5
             z16 ∈ [−32768, 32767]       class I16
             rd  ∈ [0, 2^6)              biased remainder
```

`z16` is on the **`d` axis** (`z: [i64; X_LEN]`, `X_LEN = T·D`), which is why
Tier 1 already places `A_Z16` in `Dom::D` (`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md`
§C.2) — correct, and Tier 2 keeps it there. Residual 2 then reads it in the
same zero-check that proves its class and its requantization.

Refusal: `KernelError::Range("FFN down")`. Note `z16`'s class is *also* what
residual 2 needs for its own no-wraparound argument, and Tier 1 explicitly
defers it here (`:501-506`).

**Weight classes.** `Wg`, `Wu`, `Wd` are `i8` and **any `i8` word including
`−128` is accepted**: "Any i8 word (including -128) is accepted; the caller must
authenticate the words" (`private-block-kernel/src/lib.rs:129-130`, fields at
`:139-141`). So the weight bound used in §E is `|W| ≤ 128`, not 127. The
attention matrices are the same (`argument.rs:575` folds them as `i8`).

### A.7 The two open questions of C.5, answered

**(i) Does the activation table join `SC_TAB` as a third triple, and what tag?**
**Yes**, and the pair is bound by a random linear combination under a distinct
tag, exactly as the exp table binds `(δ, E)` — *not* by two separate lookups.

`SC_TAB` (`argument.rs:732-748`) is already two identical `(multiplicity,
helper, public values)` triples: `(A_MU8, H_GU8, table_values_u8)` and
`(A_MEXP, H_GEXP, table_values_exp)`, batched under `mu[0]`, `mu[1]`, each
relation `v[helper]·(α − v[table]) − v[mult] = 0`. Tier 2 appends a third,
`(A_MACT, H_GACT, table_values_act)` under `mu[2]`, with

```
table_values_act(public, beta, g_act) = (0..256).map(|i| k(i) + beta·k(act[i]) + g_act)
```

byte-for-byte the shape of `table_values_exp` (`argument.rs:505-507`). The
degree of the slot does not change (each triple is `helper × public table`,
degree 2, times `eq(τ)` = 3), so `SLOTS[SC_TAB]` stays `(8, 1, 3)`.

The tag must be a fresh constant in the attention statement's namespace, which
is the `≥ 128` block of `hashline/src/tables_attn.rs`: `TAG_U16 = 128`,
`TAG_EXP = 129`, `TAG_PROB = 130`, `TAG_INT8A = 131`, `TAG_INT16A = 132`,
`TAG_U8 = 133` (`:47-70`). **`TAG_ACT = 134`** is the next free scalar value
there. It must not reuse the feed-forward statement's `TAG_ACT16 = 3`
(`tables_attn.rs:29`, used at `zk.rs:2557`): that namespace is deliberately
disjoint (`tables_attn.rs:28-30`) and the two tables are different objects (256
int16 rows here; the frozen member with its own spec digest there). The
verifier derives `g_act = γ·TAG_ACT` alongside `g_u8` and `g_exp` from the same
single `γ` (`protocol.rs:313-314`); nothing new is absorbed.

**(ii) Does `SH_U = 0` make the "up" remainder plane vanish?** **Yes** —
plane, limbs, lookups, the `2^sh` coefficient and the `−2^(sh−1)` constant all
vanish; only `u16`'s int16 class survives. Derived in A.4 from
`private-block-kernel/src/lib.rs:298-300` and cross-checked against
`export_v3::requant_round`'s `sh <= 0` branch (`:297-299`). This is one plane,
two lookups and one `H` helper cheaper than the draft's `[ESTIMATE]` assumed.

## B. The planes

### B.1 A new `Dom::F` — why a variant is needed even at `F = D`

**A correction to the draft, now applied there as erratum E-14.** Tier 1
originally made the new `Dom::F` conditional on `F != D`, concluding that at
this geometry `Dom::D` serves
(`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md:138`, `:666-667`, both since corrected).
Such a conclusion is true of the *size* and false of the *variant*. In this module
`Dom` is not a size — it is the key of a lookup family, a helper family and a
zero-check:

```rust
pub(crate) fn lookups(dom: Dom) -> Vec<Lk>          // layout.rs:221
pub(crate) fn helpers(dom: Dom) -> (usize, usize)   // layout.rs:263
pub(crate) const LOOKUP_DOMS: [Dom; 5]              // layout.rs:274
```

The module already carries two distinct variants at the same log: `Dom::D`
"(t, i) (9 vars)" and `Dom::Q` "(t, h, i') (9 vars) — **same flat index as
`D`**" (`layout.rs:62-66`). They are separate because they are separate lookup
lists, separate helper blocks (`H_D0..+9` vs `H_Q0..+6`, `layout.rs:156-157`)
and separate zero-checks (`SC_DZC`, `SC_QZC`). The feed-forward's `f` cube needs
all three of those for the same reason, whatever `F` happens to equal.

So Tier 2 adds `Dom::F` with `log() = 9` at this geometry, `LOOKUP_DOMS`
becomes six entries, and `a_dom` / `h_dom` gain a contiguous plane range each
(`layout.rs:141-152`, `:167-176`). §H says what changes when `F ≠ D`.

The alternative — put the `f`-cube planes in `Dom::D`, let `SC_DZC` carry the
feed-forward relations and host the gate and up matmuls as well as `SC_WO` and
`SC_DMM` — is arithmetically possible (the degree stays 4) and is recorded in
§I.1 decision 1 with what it is worth. It is not recommended: it merges two
independently checkable halves into one 47-lookup, 48-site, 4-hosted-slot
monster and it makes the `Dom::D` helper block change shape whenever the
feed-forward changes.

### B.2 The new `A` planes

Naming follows the module (`A_*` for `A` planes, `A_*L0/L1` for byte limbs,
`A_R*` for remainders). `rows_of(log) = ⌈2^log / 256⌉` (`layout.rs:399-401`), so
`Dom::F` → 2, `Dom::D` → 2, `Dom::Tab` → 1.

**`f`-cube planes (`Dom::F`, 512 entries, 2 rows each), declared contiguous so
`b.a_range(A_G8, A_RH1)` reaches them all:**

| Plane | Contents | Why it exists | Rows |
|---|---|---|---:|
| `A_G8` | `g8`, the requantized gate | R1 output; the act lookup's index is `g8 + 128` | 2 |
| `A_RGL` | `rg ∈ [0, 2^7)`, the biased gate remainder | R1's requant identity | 2 |
| `A_A16` | `a16 = act[g8 + 128]` | R2 output; a factor of R4 | 2 |
| `A_U16` | `u16 = uacc` | R3 output; the other factor of R4 | 2 |
| `A_UL0`, `A_UL1` | byte limbs of `u16 + 32768` | `u16 ∈ int16`, exactly | 4 |
| `A_H16` | `h16`, the requantized product | R4 output; the down matmul's input | 2 |
| `A_HL0`, `A_HL1` | byte limbs of `h16 + 32768` | `h16 ∈ int16`, exactly | 4 |
| `A_RH0`, `A_RH1` | byte limbs of `rh ∈ [0, 2^14)` | R4's requant identity | 4 |

**Eleven planes, 22 `A` data rows.**

**`d`-cube additions (`Dom::D`, 2 rows each).** `A_Z16`, `A_X2`, `A_X2L0`,
`A_X2L1` are Tier 1's (`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md` §C.2) and are **not**
re-counted here; `A_YM` (= `nm`) is Tier 1's §C.1 and is reused as the
feed-forward's input.

| Plane | Contents | Why | Rows |
|---|---|---|---:|
| `A_ZL0`, `A_ZL1` | byte limbs of `z16 + 32768` | **`z16 ∈ int16`** — the class Tier 1 defers (`:501-506`) | 4 |
| `A_RDL` | `rd ∈ [0, 2^6)`, the biased down remainder | R5's requant identity | 2 |

**Three planes, 6 `A` data rows.**

**Table-domain addition (`Dom::Tab`, 256 entries, 1 row).**

| Plane | Contents | Why | Rows |
|---|---|---|---:|
| `A_MACT` | the committed multiplicity histogram of the activation table | the module's rule: "the histograms are committed `A` rows" (`layout.rs:12-13`, `:133-135`), never published | 1 |

**One plane, 1 `A` data row.**

**Tier-2 `A` planes: 15. Tier-2 `A` data rows: 22 + 6 + 1 = 29.**

`N_WITNESS` (the planes the integer witness fills, `layout.rs:138`) grows by 14;
`A_MACT` is derived from the witness like the other two histograms
(`protocol.rs:275-292`).

### B.3 The lookup lists

Every range fact goes through the **single 256-entry `U8` table**, the accepted
deviation (`ZK60_PRIVATE_ATTENTION_NATIVE_DISPOSITION.md`; `layout.rs:18-25`).
The three patterns the module uses, with the widths they give exactly (R-2
brute-forced every one, `…_REVIEW_R2.md:100-116`):

* `byte(p)` alone → `p ∈ [0, 256)`.
* `byte(p)` + `scaled(p, 2^(8−s))` → `p ∈ [0, 2^s)` for `s ≤ 8`.
* `byte(l0)`, `byte(l1)`, `scaled(l1, 2^(16−s))` → `l0 + 256·l1 ∈ [0, 2^s)` for
  `8 < s ≤ 16`.
* `byte(l0)`, `byte(l1)` with the relation `v + 32768 = l0 + 256·l1` →
  `v ∈ [−32768, 32767]`, exactly (`…_REVIEW_R2.md:102`).

**`Dom::F` lookups, in helper order — nine:**

| # | Lookup | Form | Enforces |
|---:|---|---|---|
| 0 | `byte(A_RGL)` | `rg < 256` | |
| 1 | `scaled(A_RGL, 2)` | `2·rg < 256` | `rg ∈ [0, 2^7)` exactly (mirrors `layout.rs:236`) |
| 2 | `byte(A_UL0)` | | |
| 3 | `byte(A_UL1)` | | `u16 ∈ [−32768, 32767]` with the `f1` term of §C.1 |
| 4 | `byte(A_HL0)` | | |
| 5 | `byte(A_HL1)` | | `h16 ∈ [−32768, 32767]` with `f2` |
| 6 | `byte(A_RH0)` | | |
| 7 | `byte(A_RH1)` | | |
| 8 | `scaled(A_RH1, 4)` | `4·l1 < 256` ⇒ `l1 < 64` | `rh = l0 + 256·l1 ∈ [0, 2^14)` exactly (mirrors `layout.rs:254`, the softmax `ρ_s`) |

Nine is odd, so helper 4 sits in the single-lookup branch of `helper_sum`
(`argument.rs:460-466`, `h·d1 − 1`, degree 2) and helpers 0–3 in the two-lookup
branch (degree 3). `Dom::Q` and `Dom::S` are already odd at 13
(`layout.rs:234-256`), so this is the normal case, and the slot's degree is set
by the even helpers at 3 either way.

**`Dom::D` lookups, Tier-2 delta — four**, appended after Tier 1's 34:

| Lookup | Enforces |
|---|---|
| `byte(A_ZL0)`, `byte(A_ZL1)` | **`z16 ∈ [−32768, 32767]`** with the `c10` term of §C.2 |
| `byte(A_RDL)`, `scaled(A_RDL, 4)` | `rd ∈ [0, 2^6)` exactly (mirrors `layout.rs:252`, the score remainder at `SH_S = 6`) |

`Dom::D`: 34 → **38** lookups. The append is clean because 34 is even, so no
existing helper's pair changes — the same argument Tier 1 makes for appending to
20 (`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md:364-366`).

**The activation lookup is not in any `lookups()` list.** It is a two-column
lookup into a different table, so — like the exp lookup — it is a bespoke term
with its own helper plane, written directly in the zero-check
(`argument.rs:706`, `:721-722`). §C.1 gives the term.

### B.4 The new `H` helper planes

Every `H` plane is Fp2: a `re` slice and an `im` slice, so `2 × rows_of(log)`
rows (`layout.rs:438-445`). Helper `k` of a domain covers lookups `(2k, 2k+1)`
(`layout.rs:197-198`).

| Planes | Domain | Count | Why | Rows |
|---|---|---:|---|---:|
| `H_F0 … H_F0+4` | `Dom::F` | 5 | `⌈9/2⌉` for the nine `U8` lookups | 20 |
| `H_FACT` | `Dom::F` | 1 | the activation lookup's helper column, mirroring `H_SEXP` (`layout.rs:160`) | 4 |
| `H_D0+17`, `H_D0+18` | `Dom::D` | 2 | `⌈38/2⌉ = 19` helpers, up from Tier 1's 17 | 8 |
| `H_GACT` | `Dom::Tab` | 1 | the activation table's helper, mirroring `H_GEXP` (`layout.rs:162`) | 2 |

**Nine planes, 34 `H` data rows.**

`H_GACT` enters the value-0 LogUp identity with a **negative** sign, as the
other two table helpers do (`protocol.rs:47-57`, the `p == H_GU8 || p ==
H_GEXP` test gains a third arm); `H_F0..+4`, `H_FACT` and the two new `Dom::D`
helpers enter positive. The zero-sum row `u` and its fresh pair are unchanged:
there is still exactly one sum claim on `H` and no helper sum is ever published
(`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md:95`).

The prover-side fill is the existing loop: `Dom::F` joins `LOOKUP_DOMS` so
`protocol.rs:316-326` writes `H_F0..+4` with no change; `H_FACT` is one more
`inverses(...)` call beside the exp one at `:327-328`; `H_GACT` is a third entry
in the `[(H_GU8, …), (H_GEXP, …)]` array at `:329-333`.

### B.5 What needs no plane and no lookup

Worth stating, because each is a plane the draft's `[ESTIMATE]` budgeted and the
source says is not needed:

* **`ru`, the up remainder, and its lookups** — `SH_U = 0` (A.4).
* **A range lookup on `A_A16`** — the public digested table bounds it (A.3).
* **A range lookup on `A_G8`** — the activation lookup gives `[−128, 127]`
  exactly, and `sym()` would give the *wrong* window (A.2, A.3).
* **A separate `gacc` / `uacc` / `hacc` / `zacc` plane** — an accumulator is
  never committed in this module; it exists only as a private slot's claimed
  sum, reconstructed inside its host (`…_CONSTRUCTION.md:53-56`).
* **A second `M` commitment, a seam plane, a pending object** — form (S)
  (`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md` §B.1).

## C. Slots, hosts, sites

A **slot** is one masked sumcheck with one published scalar. Its shape is the
triple `(main rounds, extension rounds, degree)` in `SLOTS`
(`layout.rs:318-338`), and `L_s = (main + ext)·degree + 2` is the number of
coefficient columns its mask row occupies on `M` (the budget assertion is
`n·d + 2 + 256 ≤ 512` at `layout.rs:548-550`). A **private** slot publishes one
masked scalar `claim_s = s_s + c_s·G_s` and never a clear sum; the value it
stands for is reconstructed inside its **host**, a zero-check over the plane's
own domain, as a `ν`-batched term (`argument.rs:269-274`, `:348-360`;
`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md:53-56`). Every claim **site** — one
plane read at one point — gets its own reserved mask pair, two fresh rows
(`layout.rs:9-10`, enforced by `audit_claims`, `protocol.rs:84-127`).

### C.1 The five new slots

Slot indices are §C.3's; `p_g`, `p_u`, `p_z` are the points the three matmul
slots publish into `Points` for their hosts, exactly as `SC_WO` publishes
`p_a` (`argument.rs:581`).

---

**`SC_GMM` — the gate matmul (private).** Shape `(4, 1, 2)`, `L = 5·2 + 2 =
12`. Hosted by `SC_FZC`.

```
draw   r_tf  = tr.challenge_fp2_vec(5)          // the row point, shared with SC_UMM
       r_jg  = tr.challenge_fp2_vec(4)          // log2(F) = 4
tables [0] A_YM  at  fixed(r_tf) ++ rho(0..4)          PRIVATE, 1 A site
       [1] public  fold_cols_i8(wg_t, D, F, &eq_table_msb(&r_jg))    length D = 16
poly   v[0] * v[1]
point  p_g = cat(&[&r_tf, &r_jg])
```

The claimed sum is `Σ_{i<16} nm(r_tf, i)·(Σ_j eq(r_jg, j)·Wg[i,j])`, which is
the multilinear extension of `gacc` at `p_g`. `A_YM` is a `Dom::D` plane (log
9) and the coordinate list is 5 fixed + 4 `rho`, so `coords.len() == p.log`, the
shape test at `argument.rs:251`.

**One change to the shared code.** `SC_QMM` folds an (output, input) matrix with
`fold_rows_i8(w, outer, D, eq)` (`argument.rs:575`), which sums over the *first*
index. `wg_t` is (input, output) (A.2), so the fold is over the *second* index:
`fold_cols_i8(m, rows, cols, c) = Σ_j c[j]·m[i·cols + j]`
(`zkp-core/src/mle.rs:136-149`, already used by `layer.rs:23` and `zk.rs:609`).
It must be added to the `use crate::mle::{…}` line (`argument.rs:27`) of the
**block module's own** `argument.rs` — under ruling R-A that is
`hashline/src/private_block/argument.rs`, the copy grown from the attention
module, which is itself not edited. (Read every "one change to the shared
code" in this memo that way: the code is shared by copy, not in place.) The
alternative — transpose the weights into `BlockPublic` — is rejected in §I.1
decision 10: the statement digest should cover the same words the kernel
authenticates.

---

**`SC_UMM` — the up matmul (private).** Shape `(4, 1, 2)`, `L = 12`. Hosted by
`SC_FZC`.

```
draw   r_ju  = tr.challenge_fp2_vec(4)          // r_tf is reused, not redrawn
tables [0] A_YM  at  fixed(r_tf) ++ rho(0..4)          PRIVATE, 1 A site
       [1] public  fold_cols_i8(wu_t, D, F, &eq_table_msb(&r_ju))
poly   v[0] * v[1]
point  p_u = cat(&[&r_tf, &r_ju])
```

Reusing `r_tf` mirrors `SC_KMM` / `SC_VMM`, which reuse `SC_QMM`'s `r_q`
(`argument.rs:560-561`). The two claim points on `A_YM` still differ, because
each slot's own sumcheck challenges `ρ` differ; each gets its own reserved pair,
which is the permitted "a plane opened at k points has k pairs"
(`layout.rs:9-10`). Counting `SC_DZC`'s read at `ρ_D`, `A_YM` is opened at
**three** points in the block.

---

**`SC_DMM` — the down matmul (private).** Shape `(4, 1, 2)`, `L = 12`. Hosted
by `SC_DZC`.

```
draw   r_td  = tr.challenge_fp2_vec(5)
       r_id  = tr.challenge_fp2_vec(4)          // log2(D) = 4
tables [0] A_H16 at  fixed(r_td) ++ rho(0..4)          PRIVATE, 1 A site
       [1] public  fold_cols_i8(wd_t, F, D, &eq_table_msb(&r_id))    length F = 16
poly   v[0] * v[1]
point  p_z = cat(&[&r_td, &r_id])
```

Note the asymmetry that §H turns on: the slot's `main` rounds run over the
*contracted* axis (`F`, so `A_H16`'s own axis), while `p_z` lives on the `d`
cube where `z16` and `rd` are. `SC_DMM` is therefore the only slot that reads an
`f`-cube plane and produces a `d`-cube claim. The draft's guess that the down
matmul is hosted by `SC_DZC` is **confirmed**: the requant identity it needs
reconstructed is `2^6·z16 + rd − 2^5`, and both planes are `Dom::D`.

---

**`SC_FZC` — the `f`-cube zero-check (host of `SC_GMM`, `SC_UMM`).** Shape
`(9, 1, 4)`, `L = 10·4 + 2 = 42`.

```
draw   tau  = tr.challenge_fp2_vec(9)
       mu   = tr.challenge_fp2_vec(3 + 1 + helpers(Dom::F).1)     // = 3 + 1 + 5 = 9
       nu   = nonzero(tr.challenge_fp2_vec(2))?
tables [0] eq(tau, ·)                                  public
       [1] eq(p_g, ·)                                  public
       [2] eq(p_u, ·)                                  public
       [3..14]  a_range(A_G8, A_RH1)                   PRIVATE, 11 A sites at rho
       [14..19] h(H_F0 + k), k = 0..5                  PRIVATE,  5 H sites
       [19]     h(H_FACT)                              PRIVATE,  1 H site
hosted [(SC_GMM, nu[0]), (SC_UMM, nu[1])]
```

with, writing `at(p)` for the table value of plane `p`, `lks =
lk_tables(Dom::F, &idx, g_u8)`, and — the two bindings the module's own idiom
requires — `let i_fact = b.h(H_FACT)?;` for the activation helper's **table
index** (mirroring `let ihx = b.h(H_SEXP)?;` at `argument.rs:706`, read back
as `v[ihx]` at `:721`) and `h0 = 14`, the table index of the first `U8`
helper, for the `helper_sum` call. `H_FACT` is a *plane* constant, never a
table index; written as a table index it would read the wrong table:

```
f0    = at(A_A16)·at(A_U16) − 2^14·at(A_H16) − (at(A_RH0) + 256·at(A_RH1)) + 2^13     R4
f1    = at(A_U16) + 32768 − (at(A_UL0) + 256·at(A_UL1))                               u16 int16
f2    = at(A_H16) + 32768 − (at(A_HL0) + 256·at(A_HL1))                               h16 int16
f_act = v[i_fact]·( alpha − ( at(A_G8) + 128 + beta·at(A_A16) + g_act ) ) − 1         R2 + g8 class
        // i_fact = b.h(H_FACT)? — table index 19 in the listing above
zc    = helper_sum(v, &lks, h0, alpha, &mu[4..]) + mu[0]·f0 + mu[1]·f1 + mu[2]·f2 + mu[3]·f_act
        // h0 = 14, the table index of h(H_F0)
host1 = 2^7·at(A_G8) + at(A_RGL) − 2^6                                                R1 requant
host2 = at(A_U16)                                                                     R3, SH_U = 0
poly  = v[0]·zc + nu[0]·v[1]·host1 + nu[1]·v[2]·host2
```

`f_act` is `SC_SZC`'s `cx` with the exp table swapped for the activation table
(`argument.rs:721`: `v[ihx]·(α − (δ + β·E + g_exp)) − 1`). `host1` is
`SC_QZC`'s `2^SH_QKV·q8 + rql − 2^(SH_QKV−1)` with the gate's shift
(`argument.rs:679`). `host2` has no coefficient and no constant, which is A.4.

**Degree 4, and every monomial has a public factor.** The highest-degree
monomial is the two-lookup helper relation `h·d1·d2` (degree 3) times `eq(τ)`
(`helper_sum`, `argument.rs:457-468`); `f0`'s `a16·u16` is degree 2 and `f_act`
degree 2, both also times `eq(τ)`; the two host terms are `eq × (degree 1)` = 2.
So `(9, 1, 4)`, the same shape as `SC_DZC` and `SC_QZC`. The extension-round
premise (`argument.rs:18-22`) holds because every monomial carries `v[0]`,
`v[1]` or `v[2]`, all public `eq` tables — so one extension round suffices, as
for every non-bilinear slot.

**A sites 11, H sites 6.**

---

**`SC_TAB` — extended (standalone).** Shape unchanged `(8, 1, 3)`, `L = 29`.

```
mu = tr.challenge_fp2_vec(3)            // was 2
...  a(A_MACT)? ; h(H_GACT)? ; public(table_values_act(ctx.public, beta, g_act))
r2 = v[8]·(alpha − v[9]) − v[7]
poly = v[0]·( mu[0]·r0 + mu[1]·r1 + mu[2]·r2 )
```

**A sites 2 → 3, H sites 2 → 3.**

### C.2 The two extended slots

**`SC_DZC` — the `d`-cube zero-check.** Tier 1 already extends it with
`norm_m`'s `c6`, `c7` and residual 2's `c8`, `c9`, and its shape stays
`(9, 1, 4)`, `L = 42` (`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md:392-418`). Tier 2
adds one term, one `eq` table, three `A` sites, two `H` sites and a second
hosted slot:

```
mu  : 10 + 17   ->   11 + 19            (c0..c10, then helpers(Dom::D).1 = 19)
nu  : 1         ->   2
+ table  eq(p_z, ·)                                            public
+ planes A_ZL0, A_ZL1, A_RDL  (inside the widened a_range)      +3 A sites
+ helpers H_D0+17, H_D0+18                                      +2 H sites
c10   = at(A_Z16) + 32768 − (at(A_ZL0) + 256·at(A_ZL1))        z16 int16
host2 = 2^6·at(A_Z16) + at(A_RDL) − 2^5                        R5 requant
poly  = v[0]·zc + nu[0]·v[1]·host_wo + nu[1]·v[2]·host2
hosted [(SC_WO, nu[0]), (SC_DMM, nu[1])]
```

Shape unchanged at `(9, 1, 4)`, `L = 42`: `c10` is degree 1, the new host term
is `eq × (degree 1)` = 2, and the ceiling is still the two-lookup helper
relation at 3 times `eq(τ)`.

**`SC_TAB`** — see C.1.

Two consequences worth naming. First, `SC_DZC` now hosts two private slots, so
its `k` goes 1 → 2 and its host-group rank expectation changes (§C.4) — the
same move Tier 1 makes for `SC_TZC`. Second, the `a_range` in `SC_DZC` must
cover a plane block that now runs from `A_X` through the Tier-1 and Tier-2
`Dom::D` additions; the planes must stay contiguous in `a_dom`
(`layout.rs:146`), which is a layout-ordering constraint on the implementer, not
a design choice.

### C.3 The slot order, and host-after-hosted

`layout.rs:540` asserts `s < host` for every hosted slot, because a host's
claimed sum consumes the hosted slots' masked scalars (`argument.rs:272`,
`:306`). A second, softer ordering constraint is that a slot that *uses* a point
must run after the slot that *publishes* it into `Points`. Both are satisfied
by inserting the three matmuls immediately after `SC_WO` and `SC_FZC`
immediately after the softmax zero-check:

| # | slot | kind | host / hosted | status |
|---:|---|---|---|---|
| 00 | `SC_SS` row sums (norm_a) | private | → 02 | built |
| 01 | `SC_SSM` row sums (norm_m) | private | → 02 | Tier 1 |
| 02 | `SC_TZC` T zero-check | host | [00, 01] | Tier 1 extends |
| 03 | `SC_LZC` limb zero-check | standalone | | Tier 1 extends |
| 04 | `SC_RS` masked row sums + selector | private | → 17 | built |
| 05 | `SC_QMM` Q matmul | private | → 15 | built |
| 06 | `SC_KMM` K matmul | private | → 16 | built |
| 07 | `SC_VMM` V matmul | private | → 16 | built |
| 08 | `SC_SCORE` score matmul | private | → 17 | built |
| 09 | `SC_PV` PV matmul | private | → 15 | built |
| 10 | `SC_WO` Wo matmul | private | → 14 | built |
| **11** | **`SC_GMM` gate matmul** | **private** | **→ 18** | **TIER 2** |
| **12** | **`SC_UMM` up matmul** | **private** | **→ 18** | **TIER 2** |
| **13** | **`SC_DMM` down matmul** | **private** | **→ 14** | **TIER 2** |
| 14 | `SC_DZC` D zero-check | host | [10, **13**] | Tier 1 + **Tier 2** |
| 15 | `SC_QZC` Q zero-check | host | [05, 09] | built |
| 16 | `SC_KVZC` KV zero-check | host | [06, 07] | built |
| 17 | `SC_SZC` softmax zero-check | host | [04, 08] | built |
| **18** | **`SC_FZC` F zero-check** | **host** | **[11, 12]** | **TIER 2** |
| 19 | `SC_TAB` table helpers | standalone | | **Tier 2 extends** |
| 20 | `SC_ZS` zero-sum row | standalone | | built |
| 21 | `SC_IO_IN` input endpoint | standalone | | built |
| 22 | `SC_IO_OUT` output endpoint (`A_X2`) | standalone | | Tier 1 changes |

**Twenty-three slots, six host groups, twelve private, five standalone.**

Host-after-hosted, checked: `00,01 < 02`; `10,13 < 14`; `05,09 < 15`;
`06,07 < 16`; `04,08 < 17`; `11,12 < 18`. ✓
Point dependencies: `SC_DZC` (14) uses `p_a` from 10 and `p_z` from 13;
`SC_FZC` (18) uses `p_g` from 11 and `p_u` from 12. ✓

`SC_FZC` sits at 18 rather than next to `SC_DZC` only because its hosted slots
must precede it and the existing hosts occupy 14–17; nothing forbids 18.

### C.4 The row budget and the rank criterion per host group

**`L_s + 256 ≤ 512` on all twenty-three slots.** `L_s = (main + ext)·degree + 2`.

| Slot(s) | shape | `L` | `L + 256` |
|---|---|---:|---:|
| `SC_SS`, `SC_SSM` | (9,1,3) | 32 | 288 |
| `SC_TZC` | (5,1,3) | 20 | 276 |
| `SC_LZC` | (9,1,4) | 42 | 298 |
| `SC_RS` | (11,1,3) | 38 | 294 |
| `SC_QMM`, `SC_KMM`, `SC_VMM`, `SC_WO`, **`SC_GMM`, `SC_UMM`, `SC_DMM`** | (4,1,2) | **12** | 268 |
| `SC_SCORE` | (3,2,2) | 12 | 268 |
| `SC_PV` | (5,2,2) | 16 | 272 |
| `SC_DZC`, `SC_QZC`, **`SC_FZC`** | (9,1,4) | **42** | 298 |
| `SC_KVZC` | (8,1,4) | 38 | 294 |
| `SC_SZC` | (11,1,4) | **50** | **306** |
| `SC_TAB` | (8,1,3) | 29 | 285 |
| `SC_ZS` | (8,1,2) | 20 | 276 |
| `SC_IO_IN`, `SC_IO_OUT` | (9,1,2) | 22 | 278 |

Largest `L = 50` (`SC_SZC`), unchanged from the accepted component and from
Tier 1; headroom **206** coefficients. Tier 2 adds no slot above 42.

**The standalone CFS criterion** (FA6, `scripts/zk60_attention_cfs_slots.py:313-318`):
`rank = dim S = N·d + 1` with `N = main + ext`, image inside `S`,
`leaked_dim_fp2 = 0`, `kernel_dim_fp2 = 1`. Expected values for the new slots:

| Slot | `N·d + 1` |
|---|---:|
| `SC_GMM`, `SC_UMM`, `SC_DMM` | `5·2 + 1 = 11` (the same as the four built matmuls) |
| `SC_FZC` | `10·4 + 1 = 41` (the same as `SC_DZC`, `SC_QZC`) |
| `SC_TAB` | `9·3 + 1 = 28`, unchanged |

**The host-group criterion** (`:461-473`): `rank = dim S = ΣL − (k + 1)`,
`kernel = k + 1`, `leaked = 0`, where `k` is the number of hosted slots and `ΣL`
sums the host's `L` and its hosted slots'.

| Host | hosted | `ΣL` | arithmetic | `rank / kernel` |
|---|---|---:|---|---|
| `SC_TZC` | `SC_SS`, `SC_SSM` | 84 | `20 + 32 + 32` | 81 / 3 (Tier 1) |
| `SC_DZC` | `SC_WO`, **`SC_DMM`** | **66** | `42 + 12 + 12` | **63 / 3** (was 54 → 52/2) |
| `SC_QZC` | `SC_QMM`, `SC_PV` | 70 | `42 + 12 + 16` | 67 / 3 (unchanged) |
| `SC_KVZC` | `SC_KMM`, `SC_VMM` | 62 | `38 + 12 + 12` | 59 / 3 (unchanged) |
| `SC_SZC` | `SC_RS`, `SC_SCORE` | 100 | `50 + 38 + 12` | 97 / 3 (unchanged) |
| **`SC_FZC`** | **`SC_GMM`, `SC_UMM`** | **66** | `42 + 12 + 12` | **63 / 3** (new) |

Nothing here was run; these are the values the re-run of §G of the Tier-1 memo
must produce, stated so a run can be judged.

## D. Counts

### D.1 Deltas on Tier 1

Stated as deltas first so a correction to Tier 1 propagates by addition.

**`A` data rows: +29.** `rows_of(9) = 2`, `rows_of(8) = 1`
(`layout.rs:399-401`).

```
f-cube planes (Dom::F, 11 planes)        11 x 2 = 22
d-cube planes (A_ZL0, A_ZL1, A_RDL)       3 x 2 =  6
table multiplicity (A_MACT, Dom::Tab)     1 x 1 =  1
                                                  29
```

**`A` claim sites: +18.**

| Slot | Tier 1 | Tier 2 | why |
|---|---:|---:|---|
| `SC_GMM` (new) | — | **1** | `A_YM` at `p_g`'s tail |
| `SC_UMM` (new) | — | **1** | `A_YM` at `p_u`'s tail |
| `SC_DMM` (new) | — | **1** | `A_H16` at `p_z`'s tail |
| `SC_FZC` (new) | — | **11** | the eleven `f`-cube planes at `ρ_F` |
| `SC_DZC` | 34 | **37** | `+ A_ZL0, A_ZL1, A_RDL` at `ρ_D` |
| `SC_TAB` | 2 | **3** | `+ A_MACT` |

`1 + 1 + 1 + 11 + 3 + 1 = 18`.

**`H` claim sites: +9.** `SC_FZC` +6 (five `U8` helpers, one `H_FACT`);
`SC_DZC` 17 → 19 (its `b.h()` calls equal `helpers(Dom::D).1`,
`argument.rs:620-623`); `SC_TAB` 2 → 3 (`H_GACT`). `6 + 2 + 1 = 9`.

**`H` data rows: +34.** `2 × rows_of(log)` per Fp2 plane:
`(5 + 1) × 4` on `Dom::F` `= 24`, `2 × 4` on `Dom::D` `= 8`, `1 × 2` on
`Dom::Tab` `= 2`.

**Slots: +4** (`SC_GMM`, `SC_UMM`, `SC_DMM`, `SC_FZC`). **Host groups: +1**
(`SC_FZC`). **Private slots: +3.** Standalone unchanged at 5.

**`U8` lookups: +6,656.** `Dom::F` contributes `9 × 512 = 4,608`; `Dom::D` grows
by `4 × 512 = 2,048`.

**Rounds: main +21** (`4 + 4 + 4 + 9`), **ext +4**.

### D.2 Whole-block totals

| Quantity | accepted component | Tier 1 | **Tier 1 + 2** | arithmetic |
|---|---:|---:|---:|---|
| `A` data rows | 154 | 184 | **213** | `184 + 29` |
| `A` claim sites | 75 | 102 | **120** | `102 + 18` |
| `A` site-pair rows | 150 | 204 | **240** | `2 × 120` |
| `A` proximity pair | 2 | 2 | 2 | |
| **`A` rows** | **306** | **390** | **455** | `213 + 240 + 2` |
| `H` data rows | 218 | 246 | **280** | `246 + 34` |
| `H` claim sites | 35 | 42 | **51** | `42 + 9` |
| `H` site-pair rows | 70 | 84 | **102** | `2 × 51` |
| `H` proximity pair | 2 | 2 | 2 | |
| **`H` rows** | **290** | **332** | **384** | `280 + 102 + 2` |
| CFS slots | 18 | 19 | **23** | `19 + 4` |
| slot kinds (priv / standalone / host) | 8/5/5 | 9/5/5 | **12/5/6** | |
| host groups | 5 | 5 | **6** | `+ SC_FZC` |
| **`M` rows** | 40 | 42 | **50** | `2·23 + 4` (`layout.rs:388`) |
| **`M` functionals** | 28 | 29 | **34** | `23 + 5 + 6` (`layout.rs:533`) |
| largest CFS slot `L` | 50 | 50 | **50** (`SC_SZC`) | `L + 256 = 306 ≤ 512`, headroom 206 |
| `A` opening groups | 30 | 31, derived | **35**, derived | below |
| `H` opening groups | 8 | 8, derived | **9**, derived | below |
| `U8` lookups | 47,104 | 54,784 | **61,440** | below |
| exp lookups | 2,048 | 2,048 | 2,048 | unchanged |
| **act lookups** | — | — | **512** | `T × F = 32 × 16` |
| main + ext rounds | 129 + 20 | 138 + 21 | **159 + 25** | `+ (4,1)×3 + (9,1)` |

**The `U8` total, per domain** (count × domain length):

```
Dom::L    2 x  512 =  1,024
Dom::D   38 x  512 = 19,456
Dom::F    9 x  512 =  4,608
Dom::Q   13 x  512 =  6,656
Dom::Kv  12 x  256 =  3,072
Dom::S   13 x 2048 = 26,624
                     61,440
```

(Tier 1's 54,784 is the same sum with `Dom::D` at 34 and no `Dom::F`; the
accepted 47,104 with `Dom::D` at 20 — `…_NATIVE.md:93`.) The multiplicity
bound the no-wraparound premise needs is therefore 61,440, still far below `p`
(§E).

**Where the opening-group counts come from.** A group is a set of claims
sharing the PCS column key `(point tail, c0, len)` (`protocol.rs:62-67`). Tier 2
adds **four** fresh tails on `A` and **one** on `H`:

* `SC_GMM`, `SC_UMM`, `SC_DMM` each draw a fresh challenge vector and read one
  full-row plane, so each is a fresh key: **+3**.
* `SC_FZC`'s eleven `A` sites all sit at `ρ_F`, full rows, so they share one
  key: **+1**.
* `SC_DZC`'s three new sites share `ρ_D`'s tail with the 34 already there:
  **+0**. `SC_TAB`'s `A_MACT` shares `ρ_TAB` with `A_MU8` and `A_MEXP`: **+0**.
* On `H`: `SC_FZC`'s six helpers share `ρ_F`: **+1**. `SC_DZC`'s two new
  helpers share `ρ_D`: **+0**. `H_GACT` shares `ρ_TAB`: **+0**.

Hence 31 + 4 = **35** and 8 + 1 = **9**. I did **not** enumerate the grouping
exhaustively here, but the check of this memo did, with the committed
inventory tool on the whole-block schedule: **`A` = 35 and `H` = 9 are derived
values, member for member, not estimates**
(`ZK60_PRIVATE_BLOCK_CONSTRUCTION_TIER2_CHECK.md` §7.3, its T-C3), and the
four-fresh-tails argument above is right at every step. So `A_GROUPS = 35` and
`H_GROUPS = 9` go into `layout.rs`. `scripts/zk60_attention_native_inventory.py`
re-derives them from the source and remains the authority (`:830-848`); both
are transcript-bound through `describe()` (`layout.rs:487`) and prover and
verifier both refuse a mismatch (`protocol.rs:164-166`), which is a hard
refusal, not a warning. If the tool says 36, the constant is wrong, not the
tool. The tool's `H` count runs one below the declared constant by
construction (adaptation R-4, `ZK60_PRIVATE_BLOCK_CONSTRUCTION.md:1060`); that
offset carries unchanged.

### D.3 Receipt bytes

On the byte model of the Tier-1 memo's §C.4, which is **read out of
`hashline/src/private_attention/wire.rs:28-36`** (`opening_len`,
`encoded_len`) verbatim and reproduces all four published figures of the
accepted component exactly, with `MASK_VEC = 1024` and `MASK_PATH = 12`
(`wire.rs:23`, `:25`):

```
opening(groups, rows) = (groups + 1)*512*16 + 256*(8 + rows*8 + 32 + 11*32)
mask_open(M_ROWS)     = 2*1024*16 + 256*(8 + M_ROWS*8 + 32 + 12*32)
arguments             = 16*( N_SLOTS + sum_s (main+ext)*(degree+1) + terminals )
```

`Σ_s (main+ext)(degree+1)`: Tier 1's 626 plus `3 × (4+1)·3 = 45` for the three
matmuls plus `(9+1)·5 = 50` for `SC_FZC` = **721**. Terminals: `120 + 51 + 2 =
173`.

| Part | accepted | Tier 1 | **Tier 1 + 2** | arithmetic |
|---|---:|---:|---:|---|
| envelope + roots | 136 | 136 | 136 | unchanged |
| arguments | 11,296 | 12,656 | **14,672** | `16 × (23 + 721 + 173)` |
| `M` opening | 223,232 | 227,328 | **243,712** | `32,768 + 256·(8 + 50·8 + 32 + 384)` |
| `A` opening | 980,992 | 1,161,216 | **1,327,104** | `36·8,192 + 256·(8 + 455·8 + 32 + 352)`, at the derived 35 groups |
| `H` opening | 768,000 | 854,016 | **968,704** | `10·8,192 + 256·(8 + 384·8 + 32 + 352)` |
| endpoints | 262,144 | 262,144 | 262,144 | unchanged |
| **total** | **2,245,800** | **2,517,496** | **2,816,472** | **+25.4 % on the accepted component, +11.9 % on Tier 1** |

Each further `A` opening group would cost 8,192 bytes, about 0.3 %, but the
group count is derived rather than estimated (§D.2), and the model is
`wire.rs:28-36` verbatim, so the total is derived from source.

### D.4 Against the draft's C.5 estimate

| Quantity | draft `[ESTIMATE]` (`:669-681`) | **derived here** | why they differ |
|---|---:|---:|---|
| new `A` planes | ~20 | **15** | no `ru` plane (`SH_U = 0`), no `a16` limbs, no `g8` class plane |
| new `A` data rows | ~40 | **29** | the same three savings, ×2 rows each, plus `A_MACT` at 1 row not 2 |
| new lookups | ~16 | **13** | 9 on `Dom::F` + 4 on `Dom::D`; `ru`'s two and `a16`'s two are not needed, `z16`'s and `rd`'s are |
| new `H` helper planes | ~8 + 1 | **9** | **they agree**: the draft's `~8 + 1` is 9 and the derived value is 9. (Its composition differs — 5 `U8` + 1 act on `Dom::F`, 2 on `Dom::D`, 1 table helper — but the offsetting differences sit inside a total that does not differ.) |
| new `A` sites | ~30 | **18** | the draft's "~20 sites" for the `f`-cube zero-check is 11 in fact; `SC_TAB` costs 1 not 2 |
| new `H` sites | ~9 | **9** | agrees |
| new slots | 5 | **4** | an arithmetic slip in the draft: its own text named exactly four (`SC_GMM`, `SC_UMM`, `SC_DMM`, `SC_FZC`) while its column said 5, which propagated into its slot / `M`-row / functional line; both cells are corrected in T1 by erratum E-15 |
| `A` rows, whole block | ~510 | **455** | fewer planes, far fewer sites |
| `H` rows, whole block | ~410 | **384** | |
| slots / `M` rows / functionals | the draft's line, since corrected by E-15 | **23 / 50 / 34** | one fewer slot; functionals are `23 + 5 + 6` |
| receipt | ~3.1 MB | **2.82 MB** | |

The direction is consistent: the estimate was conservative and the derived
design is about 10 % smaller on every axis, mostly because `SH_U = 0` and the
activation lookup's double duty (class + table) remove work the estimate
budgeted.

## E. No-wraparound bounds

**The method.** Every relation in `define` is an identity between *integers*
only if no term wraps the 64-bit field `p = 2^64 − 2^32 + 1`. R-2's rule is to
bound each constrained expression by the **enforced** ranges alone — never by
what an honest witness would produce — and compare against the limit it
establishes: **worst case over the accepted component `562,949,886,312,450 <
2^49`**, "2³ below the note's 2⁵² claim and 2¹⁴ below `p/2`"
(`ZK60_PRIVATE_ATTENTION_NATIVE_REVIEW_R2.md:172-174`). Tier 2's bounds must
stay below `2^49`.

**The enforced ranges Tier 2 may use.** Only these:

| Quantity | Window | Enforced by |
|---|---|---|
| `nm` (`A_YM`) | `[−127, 127]` | `sym(A_YM)`, Tier 1 §C.1 (D12 item 4) |
| `Wg`, `Wu`, `Wd` | `[−128, 127]` | public `i8` words; `−128` accepted (`private-block-kernel/src/lib.rs:129-130`) |
| `g8` | `[−128, 127]` | the activation lookup (A.3) |
| `rg` (`A_RGL`) | `[0, 2^7)` | `byte` + `scaled(·, 2)` |
| `a16` | `[−32768, 32767]` | **`BlockPublic::new`'s value-range check on `act`** — `act.iter().all(\|v\| (-32768..=32767).contains(v))`, or `act: [i16; 256]` — mirroring the exp table's own check at `private_attention.rs:97-99` (erratum E-2). The kernel's `act: [i16; 256]` (`lib.rs:182`) is a type in a crate the proof never runs and enforces nothing here; without the statement-side check this row, and items 5 and 6 below, are unfounded |
| `u16`, `h16`, `z16` | `[−32768, 32767]` | two byte limbs + offset 32768, exact |
| `rh` | `[0, 2^14)` | `byte, byte, scaled(·, 4)` |
| `rd` (`A_RDL`) | `[0, 2^6)` | `byte` + `scaled(·, 4)` |

**The bounds, term by term.**

| # | expression | where | bound | vs `2^49` |
|---:|---|---|---:|---|
| 1 | `gacc = Σ_{i<16} nm·Wg` | `SC_GMM` claimed sum | `16·127·128 = 260,096 < 2^18` | OK |
| 2 | `uacc = Σ_{i<16} nm·Wu` | `SC_UMM` claimed sum | `260,096 < 2^18` | OK |
| 3 | `gacc − (2^7·g8 + rg − 2^6)` | `SC_FZC` `host1` | `260,096 + 16,384 + 127 + 64 = 276,671 < 2^19` | OK |
| 4 | `uacc − u16` | `SC_FZC` `host2` | `260,096 + 32,768 = 292,864 < 2^19` | OK |
| 5 | `a16·u16` | `SC_FZC` `f0` | `32,768 × 32,768 = 1,073,741,824 = 2^30` | OK |
| 6 | `a16·u16 − 2^14·h16 − rh + 2^13` | `SC_FZC` `f0` | `2^30 + 2^29 + 16,383 + 8,192 = 1,610,637,311 < 2^31` | **worst new case** |
| 7 | `u16 + 32768 − (l0 + 256·l1)` | `SC_FZC` `f1` | `65,536 + 65,535 = 131,071 < 2^17` | OK |
| 8 | `h16 + 32768 − (l0 + 256·l1)` | `SC_FZC` `f2` | `131,071 < 2^17` | OK |
| 9 | `zacc = Σ_{j<16} h16·Wd` | `SC_DMM` claimed sum | `16·32,768·128 = 67,108,864 = 2^26` | OK |
| 10 | `zacc − (2^6·z16 + rd − 2^5)` | `SC_DZC` `host2` | `2^26 + 2,097,152 + 63 + 32 = 69,206,111 < 2^27` | OK |
| 11 | `z16 + 32768 − (l0 + 256·l1)` | `SC_DZC` `c10` | `131,071 < 2^17` | OK |
| 12 | `scaled` products `2·rg`, `4·l1(rh)`, `4·rd` | the `U8` lookups | `510`, `1,020`, `1,020` | OK |
| 13 | `U8` multiplicities | `A_MU8` | `61,440` | OK |
| 14 | act multiplicities | `A_MACT` | `512` | OK |

**Worst new expression: 1,610,637,311 < 2^31**, which is `2^18` below the R-2
limit. Tier 2 therefore does not move the whole-block worst case, which stays
at Tier 1's `Dsq − D·D` (`…_REVIEW_R2.md:151`). Item 12 is the detail R-2
singles out: `scaled(p, k)` constrains `k·v` *in Fp*, and with the companion
`byte(p)` already forcing `v < 256` the products above are `≤ 1,020 ≪ p`, so the
field constraint is the integer constraint (`…_REVIEW_R2.md:118-121`).

**Every new decomposition is exact, by R-2's own table.** `rg`'s pattern is
R-2's `sh = 7` row, `rd`'s is its `sh = 6` row, `rh`'s is its `softmax ρ_s` row
(`l0, l1, 4·l1 ∈ U8` ⇒ `[0, 2^14)`), and `u16`/`h16`/`z16`'s is its `int16` row
(`…_REVIEW_R2.md:102-110`). Tier 2 invents no new pattern, so no new
brute-force is owed — only a re-run of `limb_windows.py` on the grown list.

**Two things this section does not cover, and one correction.**

* The activation lookup's value `(g8 + 128) + β·a16 + g_act` is a *field*
  expression with random coefficients, not a bounded integer; its soundness is
  the LogUp argument, not a wraparound argument. R-2 treats the exp lookup the
  same way (`…_REVIEW_R2.md:133`).
* The claimed sums of `SC_GMM` / `SC_UMM` / `SC_DMM` are *masked* scalars
  `s + c·G`; the bounds above are on the integer value `s` stands for, which is
  what the host reconstructs. The masking itself is field arithmetic.
* **A correction to Tier 1's §H.1** (erratum E-4, now applied there). The
  draft originally argued that `norm_m`'s bounds must be re-derived because
  its input `xres1` can exceed `x_in` at the extremes
  (`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md:1226-1230`). It cannot: the class the
  **verifier enforces** on the two is the identical two-limb, offset-32768
  pattern — `byte(A_XL0)`, `byte(A_XL1)` (`layout.rs:226`) with `c2`
  (`argument.rs:634`) for `x_in`, and `byte(A_X1L0)`, `byte(A_X1L1)`
  (`layout.rs:232`) with `c4` (`argument.rs:636`) for `xres1` — so both are
  `[−32768, 32767]`, the same window. (The honest prover's input type
  `input: &[i16]` and the calibration's `x_cls: Cls::Int16` are **not**
  admissible warrants for this: R-2's method takes bounds only over ranges
  the verifier enforces, `…_REVIEW_R2.md:35-39`.) R-2's
  `Σx² + ceps ≤ 17,179,869,185` is exactly `1 + 16·32768²`
  (`…_REVIEW_R2.md:178`), i.e. already computed over the full int16 range. So
  `norm_m`'s bounds are **bit-for-bit `norm_a`'s**, and the R-2 re-run for the
  second norm is a re-run, not a re-derivation. (The obligation to *run* it on
  the grown layout stands.)

## F. The transcript

Tier 2 changes the draft's §D order (`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md:714-777`)
in exactly three places, and **nothing has to be absorbed earlier than the draft
already absorbs it**.

**Step 3, `"public-statement"` — payload only.** The draft's `BlockPublic`
digest already lists `Wg, Wu, Wd` and `act` beside the attention material
(`:719-722`). Tier 2 confirms that is the right and sufficient place: the
activation table's 256 `i16` words and the three feed-forward matrices must be
in the digest, because the verifier rebuilds `table_values_act` and the folded
weight tables from them (`argument.rs:505-507`, `:575` for the existing
pattern). The digest domain string changes with the profile
(`"hashline/private-block-public/1"`), so a receipt cannot be replayed against
the attention statement. **No separate "activation-table digest" absorb is
needed**, and none should be added: a second absorb of the same words is a
second thing to keep in sync. The structural validation `AttentionPublic::new`
performs on `exp` and the rope tables (`private_attention.rs:93-105`) must be
carried over into `BlockPublic::new` for `act`, and it must be **more than a
shape check**: besides `act.len() == 256`, the constructor **refuses any
activation value outside `[−32768, 32767]`** —
`act.iter().all(|v| (-32768..=32767).contains(v))`, or `act` held as
`[i16; 256]` — exactly mirroring the exp table's own value-range check at
`private_attention.rs:97-99` (erratum E-2, BLOCKING). A length check alone
would leave `a16`'s int16 class a caller's promise, which §E's bounds, `f0`'s
no-wraparound argument and `h16`'s pinning all depend on. This is structure,
not provenance — the caller still owes the provenance of the words, exactly as
the module already warns (`:66-69`).

**Step 4, `"parameters"` — payload only.** The draft already proposes
`T32/d16/f16/H2/KV1/dh8/...` (`:723-724`). Add the feed-forward shifts so the
string is self-describing: `.../f16/.../sh-g7-u0-h14-z6/...`. This is belt and
braces — step 5's calibration digest binds them — but it makes a captured
transcript readable.

**Step 9, the `(β, γ, α)` draw — unchanged, and sufficient.** `g_act =
γ·TAG_ACT` is derived by prover and verifier from the same single `γ`, beside
`g_u8` and `g_exp` (`protocol.rs:313-314`, `:413-414`). `TAG_ACT` is a
compile-time constant of both sides, not an absorbed value — the same status as
`TAG_U8` and `TAG_EXP`. `β` is reused for the activation pair exactly as for
the exp pair. **Nothing moves before the `H` root**: `H_F0..+4`, `H_FACT` and
`H_GACT` are all computed from `(α, β, γ)` and written into `h_data` before
`commit_zk_owned`, which is where `H_SEXP` and `H_GEXP` are written today
(`protocol.rs:316-333`).

**Step 11, the slot loop — four new iterations and one renumbering.** The order
is §C.3's twenty-three; the per-slot labels are the draft's (`:738-745`) —
`pa-slot` / `pa-scalar` / `pa-term`, which ruling **R-B** leaves the
implementer free to rename `pb-*` but does not require — and Tier 2 adds no
label either way. Concretely, relative to the draft's slot list:

```
 ...
 10  Wo matmul        private -> 14
 11  gate matmul      private -> 18      NEW      (was the draft's "[10a]")
 12  up matmul        private -> 18      NEW      (was "[10b]")
 13  down matmul      private -> 14      NEW      (was "[10c]")
 14  D zero-check     host [10, 13]      EXTENDED (Tier 1 c6..c9; Tier 2 c10 + host2)
 15  Q zero-check     host [05, 09]
 16  KV zero-check    host [06, 07]
 17  softmax zc       host [04, 08]
 18  F zero-check     host [11, 12]      NEW      (was "[14a]")
 19  TAB              standalone         EXTENDED (third triple, TAG_ACT)
 20  ZS               standalone
 21  IO-in            standalone
 22  IO-out           standalone         A_X2
 ...
```

The draft's bracketed placeholders `[10a] [10b] [10c] [14a]` (`:759-766`) become
11, 12, 13, 18 — the same positions, now with the renumbering written out so the
`hosts_by_index` map the inventory tool pins becomes
`{2:[0,1], 14:[10,13], 15:[5,9], 16:[6,7], 17:[4,8], 18:[11,12]}`.

**Step 12, the `M` opening** — 34 functionals, one `θ`, unchanged in shape.
**Steps 13–16, the four openings** — unchanged; still one opening per
commitment, still `M, A, H, In, Out`, each owner dropped immediately
(`protocol.rs:365-381`).

**Domain separation, inside one transcript.** The draft's four mechanisms
(`:803-823`) all carry, and Tier 2 supplies the one it flagged as missing: the
third tag. `g_u8`, `g_exp` and `g_act` are three distinct multiples of the one
`γ`, folded into three disjoint denominator families of the single value-0 LogUp
identity. Without `TAG_ACT` an activation-table row and a `U8` row could
coincide, which is the collision the draft's Decision 10 names.

## G. The tripwire tests

The rule (`ZK60_PRIVATE_BLOCK.md:242-243`, quoted at
`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md:1274-1280`): a tamper test is only worth
something if the **verifier** rejects. A prover-side assertion, a witness-builder
refusal or a `debug_assert` proves nothing about the receipt. So every test
below injects the tamper into the witness planes *before the `A` commitment*,
lets `prove_inner` run to completion, and asserts `verify_inner(...).is_err()`.
The existing prover has exactly this shape of harness for the feed-forward
(`hashline/src/layer.rs:2139-2196`, `TamperV3` with
`recompute_v3_from_a16` keeping the downstream chain consistent); the private
module needs the same, `#[cfg(test)]`, on `witness::build`.

### G.1 The z16 tamper

**The tamper.** Consistent, not sloppy — every class proof must still be
satisfiable, so that the test isolates *binding* rather than *range*:

1. Build the honest witness. Pick an index `k` with `xres1[k] + z16[k] + 1 ≤
   32767` and `z16[k] + 1 ≤ 32767`.
2. `z16'[k] = z16[k] + 1`; recompute `A_ZL0`, `A_ZL1` from `z16'[k] + 32768`
   (still valid bytes).
3. `xres2'[k] = xres1[k] + z16'[k]`; recompute `A_X2L0`, `A_X2L1`.
4. Leave `rd`, `h16`, `a16`, `u16`, `g8`, `nm`, `xres1` and everything upstream
   untouched.
5. Commit a **fresh output endpoint** to `xres2'` and prove against it.

Everything Tier 1 checks still holds: `c8` (`x2 + 32768 = X2L0 + 256·X2L1`),
`c9` (`x2 − x1 − z16`), every `U8` lookup, `SC_IO_OUT`'s equality. **Under Tier
1 alone the verifier accepts**, and the block's output is whatever the prover
chose. That is the hole.

**What catches it once Tier 2 exists: `SC_DZC`'s second host term.** The
verifier's claimed sum for slot 14 is
`Γ_host + ν_0·κ_0·claim_{SC_WO} + ν_1·κ_1·claim_{SC_DMM}`
(`argument.rs:306`), and the polynomial it sumchecks contains
`ν_1·eq(p_z, x)·(2^6·z16(x) + rd(x) − 2^5)`. Tampering `z16` at one index moves
that sum by `ν_1·2^6·Δ·eq(p_z, k)`, which is nonzero except on a negligible
fraction of `p_z`; `claim_{SC_DMM}` is unchanged because `h16` and `Wd` are
unchanged. The two sides differ, and `sumcheck::verify` rejects at the first
round, where `g(0) + g(1) ≠ claimed` (`argument.rs:307`), with a message of
the form `slot 14 [<SLOT_NAMES[SC_DZC]>]: …`. **The name string itself
changes in this commit** (erratum E-20): `SLOT_NAMES[SC_DZC]`
(`layout.rs:308`) today reads `"03 D zero-check (hosts 12)"` and must name
both hosted slots once `SC_DZC` hosts `SC_WO` **and** `SC_DMM`, so a test must
assert on the slot **index**, not on the name.

**And the prover cannot compensate.** The three ways to try:

* *Move `rd[k]`.* It would have to move by `−2^6·Δ = −64`, but `rd ∈ [0, 2^6)`
  is a 64-wide window, so any nonzero `Δ` pushes it out and the
  `byte(A_RDL)`/`scaled(A_RDL, 4)` lookups fail — caught by the value-0 LogUp
  sum claim on `H` (`protocol.rs:47-57`) rather than by `SC_DZC`.
* *Move `h16`.* Then `SC_DMM`'s claimed sum moves too, but `h16` is pinned by
  `SC_FZC`'s `f0` to `a16·u16`, `a16` to `g8` by the activation lookup, and
  `g8`/`u16` to `nm` by `SC_FZC`'s two host terms against `SC_GMM` and
  `SC_UMM`. The chain ends at `nm`, which `norm_m` pins to `xres1`, which
  residual 1 pins to `x_in`, which `SC_IO_IN` pins to the caller's input
  endpoint.
* *Move `p_z`.* It is Fiat–Shamir output (`SC_DMM`'s own draws), absorbed
  before the slot's mask challenge; a prover that re-runs to search for a lucky
  `p_z` is the standard grinding attack the transcript refusals already treat
  (`argument.rs:258-261`, `:331-333`).

**Assertions to write.** `assert!(verify_inner(&public, &expected, &receipt).is_err())`,
and — because a test that passes for the wrong reason is worse than none — a
second assertion that the error names **slot index 14** (not the slot's name
string, which Tier 2 itself changes), so a later refactor that moves the catch
to, say, the `M` opening is noticed; and a third, the companion assertion that
the **honest** proof verifies, so the test cannot pass on a build that is
broken for an unrelated reason (erratum E-20; the same companion is required
of the E-1 tripwire).

### G.2 g, a, u, h

Same harness. Every row below **rejects at the verifier**, and each names a
real relation — but **the rows do not all isolate one relation** (erratum
E-19): four of them fire two or three independent catches, and the "kept
consistent" column says only what the tamper recomputes, not that nothing
else breaks. Where a row has more than one catch it is marked, because a test
that can pass for three reasons cannot be used to confirm that one particular
relation is *present*; to use these as presence tests, recompute the whole
chain in each row.

| # | tamper | kept consistent | what rejects, and why |
|---:|---|---|---|
| T-g1 | `g8[k] += 1`, `rg[k] −= 2^7` | the gate requant identity `gacc = 2^7·g8 + rg − 2^6` still holds over `Z` | **Three catches, not one.** `rg` leaves `[0, 2^7)` downwards, so it is `p − 128 + rg` in `Fp` and has **no row in either lookup**: `byte(A_RGL)` fails as well as `scaled(A_RGL, 2)` (E-18). And `a16` is not recomputed, so `(g8+1+128, a16)` is not a row of `act` and the **activation lookup** fails too. All of them surface as the **value-0 LogUp sum claim on `H`**. (`layer.rs:2178`'s `RemainderOutOfRange`, ported.) |
| T-g2 | `g8[k] += 1`, `a16[k] = act[g8[k]+129]`, and `h16`/`rh`/`z16`/`rd` recomputed down the chain | every class, every lookup, every downstream requant identity | the **gate requant identity** breaks: `SC_FZC`'s `host1` no longer matches `SC_GMM`'s claim at `p_g`. Slot 18 rejects. This is the test that `g` is bound to `nm` |
| T-a1 | `a16[k] += 1`, chain recomputed (`recompute_v3_from_a16`'s analogue) | every requant identity, every class | the pair `(g8[k]+128, a16[k]+1)` is not a row of `act`: the **activation LogUp** fails — `H_FACT`'s relation `f_act` in slot 18, and the `A_MACT` side of slot 19, cannot both be satisfied, so the one value-0 sum claim on `H` fails. (`layer.rs:2179`'s `WrongTableEntry`.) |
| T-u1 | `u16[k] += 1`, `h16`/`rh`/`z16`/`rd` recomputed | classes and downstream identities | the **up identity** `uacc = u16` breaks at `p_u`: `SC_FZC`'s `host2` no longer matches `SC_UMM`'s claim. Slot 18 rejects. This is the test that `u` is bound to `nm` |
| T-u2 | `u16[k] += 65536`, limbs "compensated" | — | **Two catches.** Impossible as stated: `A_UL1` would need to hold 256+, refused by `byte(A_UL1)`; if the limbs are left alone, `f1` fails in slot 18. Either way `host2` also fails, because `u16` no longer equals `uacc`. This is the **int16 class** test |
| T-h1 | `h16[k] += 1`, `rh` unchanged | nothing else | **Two catches.** `f0` fails: `a16·u16 ≠ 2^14·h16 + rh − 2^13`, slot 18 rejects. Slot 14 fails too — `SC_DMM`'s claim moves with `h16` while `SC_DZC`'s `host2` does not. (`layer.rs:2180`'s `WrongRequant`.) |
| T-h2 | `h16[k] += 1`, `rh[k] −= 2^14` | `f0` holds over `Z` | **Three catches.** `rh` leaves `[0, 2^14)` downwards, so `byte(A_RH0)`/`byte(A_RH1)` have no valid limbs at all and `scaled(A_RH1, 4)` fails with them; the LogUp sum claim rejects. Slot 14 fails too, for T-h1's reason |
| T-h3 | `h16[k] += 1`, `z16`/`rd` recomputed from the new `h16` | the down requant identity | `f0` fails (the product no longer matches) — same catch as T-h1, which is the point: the product is pinned from *both* sides |
| T-z1 | `z16[k] += 65536`, `rd[k] −= 65536·2^6` | the down requant identity over `Z` | `rd` leaves `[0, 2^6)` **and** `A_ZL1` leaves `[0, 256)`: two independent catches, both through the LogUp sum claim. (`layer.rs:2196`'s `OutOfRangeInt16`.) This is `z16`'s **int16 class** test |
| T-z2 | §G.1 | | the binding test |

Two more that belong in the same suite and are not Tier-2-specific, carried
here so they are not lost:

* **The D12 item-3 boundary test** (the draft's §H.2 item 7): prove honestly,
  then present the receipt against an output endpoint committing `xres1`
  instead of `xres2`; the verifier must reject at `SC_IO_OUT`.
* **The pair-sharing negative control** for the new planes: give `A_H16`'s site
  in `SC_FZC` the same reserved mask pair as `A_U16`'s and require
  `audit_claims` to refuse ("a reserved pair is unused or shared between
  claims", `protocol.rs:124-126`) *and* the rank tool's disclosed dimension to
  rise. The Tier-1 memo adds the analogous control for `A_YM` sharing `A_Y`'s
  pair (`:1085-1089`); the `f`-cube planes are the same kind of near-duplicate
  and deserve one.

## H. What 8B changes

At this geometry `F = D = 16`, so the `f` cube and the `d` cube are both
`32 × 16 = 512` entries, both 9 variables, both 2 rows per plane. §B.1 already
separates the two *variants*; this section says which **numbers** rest on the
coincidence and what a real `Dom::F` would change. It does not design one.

**What does not depend on the coincidence** — the structure. Because `Dom::F`
is a separate variant with its own lookup list, its own helper block and its own
zero-check, no relation in §A–§C reads an `f`-cube plane at a `d`-cube point or
batches an `f`-cube term into a `d`-cube zero-check. `SC_DMM` is the only slot
that spans the two axes, and it already does so explicitly: it reads `A_H16`
(`f`) and publishes `p_z` (`d`). That is a design property, not an accident of
`F = D`.

**What does depend on it**, item by item:

| Depends on `F = D = 16` | What a real `Dom::F` changes |
|---|---|
| `Dom::F.log() = 9` | becomes `log T + log F`; at the 125M rung (768 → 2048) that is `log T + 11` |
| `rows_of(Dom::F) = 2` per plane, so the eleven `f`-cube planes cost 22 rows | becomes `⌈2^(log T + log F) / 256⌉` per plane; the eleven planes dominate `A` |
| `SC_FZC` shape `(9, 1, 4)`, `L = 42` | becomes `(log T + log F, 1, 4)`, `L = (log T + log F + 1)·4 + 2`. **The row budget bites**: `L + 256 ≤ 512` (`layout.rs:548-550`) caps `log T + log F ≤ 62`, comfortable, but the mask row grows linearly |
| `SC_GMM`/`SC_UMM` main rounds `= log D = 4`, `r_j` width `= log F = 4` | main rounds `log D`, `r_j` width `log F` — these separate |
| `SC_DMM` main rounds `= log F = 4`, `r_i` width `= log D = 4` | main rounds `log F`, `r_i` width `log D` — these separate the other way |
| the folded public tables have length 16 = `2^main` | length `D` and `F`; **both must be powers of two**, and at 125M `D = 768` is not. This is the real 8B obstacle, and it is not a `Dom::F` question: it is the block decomposition the existing prover already carries (`nb_d` blocks of `2^log_db`, `nb_f` of `2^log_fb`, `layer.rs:1185-1186`), which form (S) does not inherit (`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md:155-161`) |
| `Dom::D` and `Dom::F` planes interleave freely in `a_dom`'s range match | unchanged in kind; the ranges just get bigger |
| `U8` lookup counts `9 × 512` and `4 × 512` | scale with the cube sizes; the `U8` table stays 256 rows, so only the multiplicities grow, and §E item 13's bound must be re-checked against `p` |
| the activation table stays 256 rows at every geometry | unchanged — it is indexed by `g8 + 128`, an int8, forever |

So: a `Dom::F` at `F ≠ D` is a mechanical widening of everything in §B–§D and
changes no relation in §A. The thing that is **not** mechanical, and that this
memo does not touch, is that at 125M and 8B the axes are not powers of two and
the planes must be block-decomposed — the draft's §B.3 measurement question,
unchanged by anything here.

## I. Decisions, open obligations, what I did not check

### I.1 Decisions for the security owner

Each is a choice I made and the security owner must confirm or overturn.
Numbered from 1 so they can be referred to as "Tier-2 decision *n*";
recommendation first, one sentence of reason.

1. **Give the feed-forward its own `Dom::F` variant (log 9 here) rather than
   folding its planes into `Dom::D`.** `Dom` is a lookup/helper/zero-check
   family key, not a size — the module already has two variants at log 9
   (`Dom::D`, `Dom::Q`, `layout.rs:62-66`) — and merging would make one slot
   carry 45 lookups, 48 `A` sites and four hosted slots. *(This corrects the
   Tier-1 draft on the point erratum E-14 records; T1 now carries the
   correction.)*
2. **One `f`-cube zero-check `SC_FZC`, hosting `SC_GMM` and `SC_UMM` and
   carrying the product, the two int16 decompositions, the activation lookup
   and the `Dom::F` LogUp helpers.** All of it is degree ≤ 4 on one cube, so a
   second slot would buy nothing and cost two `M` rows and a functional.
3. **No `ru` plane, no `2^sh` coefficient and no `−2^(sh−1)` constant in the up
   host term.** `SH_U = 0` makes `requant` the identity
   (`private-block-kernel/src/lib.rs:298-300`), so the remainder is identically
   zero and committing it would be pure cost.
4. **The activation table joins `SC_TAB` as a third `(multiplicity, helper,
   public values)` triple, with `TAG_ACT = 134` in `tables_attn.rs`'s `≥ 128`
   attention namespace.** It is the same 256-row shape as the exp table, and
   134 is the next free value after `TAG_U8 = 133` (`tables_attn.rs:47-70`);
   it must not reuse the feed-forward statement's `TAG_ACT16 = 3`.
5. **Bind the `(g8, a16)` pair by the random linear combination
   `(g8 + 128) + β·a16 + g_act`, not by two separate lookups.** It is the exp
   table's construction verbatim (`argument.rs:505-507`, `:721`) and it is the
   only form that proves index and value came from the *same* row. **This is
   a soundness requirement, not a preference** (erratum E-22): wherever
   `u16(x) = 0`, `f0` reads `a16·u16 = 0` and pins nothing about `a16(x)`,
   and `f_act` is the only other relation `a16` appears in — so the rejected
   alternative (separate class lookups on `g8` and on `a16`) would leave
   `a16`, and with it `h16` and `z16`, **free at every zero of the up
   matmul**.
6. **No range lookup on `A_G8`, and specifically not `sym(A_G8)`.** The
   activation lookup already gives `g8 ∈ [−128, 127]`, and `sym()` gives
   `[−127, 127]` — the *wrong* window, since the kernel's gate class is `I8`
   not `I8N` (`private-block-kernel/src/lib.rs:629`, `:93-95`), so `sym()`
   would make an honest `g8 = −128` unprovable.
7. **No range lookup on `A_A16` — but `BlockPublic::new` must refuse an
   out-of-range activation table.** Its bound is the value range of the
   public, digested 256-entry table, and the existing feed-forward prover
   likewise ranges `u16`, `h16` and `z16` and never `a16`
   (`layer.rs:1395-1400`). That is only sound if the proof's **own public
   statement** enforces the range: `BlockPublic::new` validates
   `act.iter().all(|v| (-32768..=32767).contains(v))`, or holds
   `act: [i16; 256]`, mirroring the exp table's check at
   `private_attention.rs:97-99` (erratum E-2, BLOCKING). Without that the
   class is a caller's promise and §E's bounds do not hold.
8. **`SC_DMM` is hosted by `SC_DZC` (which then hosts two slots); `SC_GMM` and
   `SC_UMM` by `SC_FZC`.** A host term must live on the domain of the planes
   that reconstruct the value, and `z16`/`rd` are `d`-cube while `g8`/`rg`/`u16`
   are `f`-cube. *(Confirms the draft's guess.)*
9. **`SC_GMM` and `SC_UMM` share one row point `r_tf`; `SC_DMM` draws its
   own.** It mirrors `SC_KMM`/`SC_VMM` reusing `SC_QMM`'s `r_q`
   (`argument.rs:560-561`); the two claim points on `A_YM` still differ through
   each slot's own `ρ`, so each keeps its own reserved pair.
10. **Keep the feed-forward weights in the kernel's (input, output) order and
    fold them with `fold_cols_i8`; do not transpose them into `BlockPublic`.**
    The statement digest should cover the same words the caller authenticates
    against the approved commitments (`private-block-kernel/src/lib.rs:17-23`),
    and `fold_cols_i8` already exists (`zkp-core/src/mle.rs:136-149`).
11. **Remainder widths: `rg` one limb with `scaled(·, 2)`; `rd` one limb with
    `scaled(·, 4)`; `rh` two limbs with `scaled(l1, 4)`.** These are R-2's
    already-brute-forced exact patterns for `sh = 7`, `sh = 6` and 14-bit
    windows (`…_REVIEW_R2.md:106-109`), so no new exactness proof is owed.
12. **The activation multiplicity histogram `A_MACT` is a committed `A` row,
    never published.** The module's rule (`layout.rs:12-13`), applied to the
    third table exactly as to the first two.
13. **Slot indices 11, 12, 13 for the matmuls and 18 for `SC_FZC`, with the
    renumbering of §C.3 and `hosts_by_index = {2:[0,1], 14:[10,13], 15:[5,9],
    16:[6,7], 17:[4,8], 18:[11,12]}`.** It is the only placement that keeps
    host-after-hosted (`layout.rs:540`) and the point-publication order without
    disturbing the built attention slots' relative order.
14. **Two Tier-1 statements that were wrong, both now corrected there.**
    (a) The draft's §C.5 counted five new slots while naming four, which
    propagated into its slot / `M`-row / functional line; the derived figures
    are `23 / 50 / 34` (erratum E-15). (b) The draft's §H.1 said `norm_m`'s
    bounds need re-derivation because `xres1` can exceed `x_in`; the class the
    verifier enforces on both is the identical two-limb, offset-32768 pattern
    (`layout.rs:226` + `argument.rs:634` for `x_in`, `layout.rs:232` +
    `argument.rs:636` for `xres1`), so both are `[−32768, 32767]` and R-2
    already computed over the full int16 range (`…_REVIEW_R2.md:178`): it is a
    re-run, not a re-derivation (erratum E-4). Neither is a soundness issue;
    both change what the security owner is told is outstanding.

### I.2 Open obligations

**This design establishes no privacy property.** It is a soundness design: it
binds `z16` to `nm`. Whether the grown layout is zero knowledge is untouched,
and the construction's acceptance gate — on captured real receipts, a
zero-witness preimage with the same free dimension as the real witness on every
channel (`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md:135`) — is unmet and unaffected.

* **The rank and CFS tools must be re-run on the whole-block layout, and the
  accepted verdicts do not transfer.** The Tier-1 memo's §G states the pass
  criteria for 19 slots; every one of them changes again here. The values the
  re-run must produce are in §C.4 and §D.2, and `NOTE_EXPECT`
  (`scripts/zk60_attention_native_inventory.py:1085-1100`) must be updated to
  `A 455/213/240`, `H 384/280/102`, `A_sites 120`, `H_sites 51`,
  `A_GROUPS 35`, `H_GROUPS 9` (derived, not estimated — §D.2),
  `M_ROWS 50`, `N_FUNCTIONALS 34`,
  `largest_L 50`, `U8 61,440`, `exp 2,048`, `act 512`, `main 159`, `ext 25`,
  twenty-three `SLOTS` triples and the `hosts_by_index` of decision 13.
  **Nothing here was run.**
* **`disclosed_dim = 0` is required on the four new `A` groups and the one new
  `H` group**, and `whole_H_with_values` must still be exactly 2 with
  `residual_is_exactly_the_public_identity = true` — now over
  `1 + 19 + 5 + 1 + 7 + 6 + 7 + 1 = 47` witness helper columns and **3** table
  helpers instead of Tier 1's 39 and 2.
* **A new CFS negative control is owed**: `nc_sigma_functional_for_private_slot`
  run against `SC_GMM`, `SC_UMM` and `SC_DMM`, since publishing `Σ` for any of
  them would reveal a feed-forward accumulator at a random point.
* **D8 and D11 stay open for the two external endpoints.** `x_in` and `xres2`
  are caller-fixed roots; simulatability against a distinguisher holding prior
  public history is not established, and one-use consumption does not reduce it
  to the empty-history case. Tier 2 changes nothing about this, in either
  direction.
* **D9** (the `fp()` reduction bias) applies unchanged.
* **The no-wraparound re-run.** §E derives the bounds; `limb_windows.py` and
  `wraparound_bounds.py` must be re-run over the grown expression list, and the
  multiplicity bound re-checked at 61,440.
* **The inventory parser, and the module it parses.** Under ruling R-A the
  block is a new module, so the tool must take the **module path as a
  parameter** rather than hard-coding the attention module's files. The new
  `define` arms must be written inside the
  Rust subset `zk60_attention_native_inventory.py` understands (`b.a`,
  `b.a_at`, `b.a_slice`, `b.a_range`, `b.h`, `rho`, `fixed`, `cat`, one `for`
  loop, `match slot`), or the parser must be extended in the same commit. The
  `b.public(fold_cols_i8(...))` call is not a site-creating call, so it needs
  only to parse, but `SC_FZC`'s eleven-plane `a_range` and six-helper loop must
  be in the subset or the only executable check of the schedule stops working.
* **Completeness is not proved.** I argue each honest witness satisfies each
  relation; I did not run a single honest proof.

### I.3 What I did not check

**Not run.** No `cargo` of any kind — no build, no `cargo check`, no test, no
example, no proof, no benchmark. No tool of §I.2 was executed; every number is
pencil arithmetic, cross-checked with `python3 -c` on the additions and
products only. No git write of any kind. No file other than this one was
created or edited.

**Not read in full.** `hashline/src/zk.rs`, `hashline/src/attention.rs` and
`hashline/src/layer.rs` were searched, not read; of `layer.rs` I read the v3
statement comment (`:1180-1214`), the helper specs and zero-check polynomials
(`:1374-1400`, `:1690-1700`, `:1760-1766`) and the tamper enum (`:2139-2196`).
I did not read `zkp-core/src/pcs.rs`, `zk::mask_commit` / `mask_open`,
`sumcheck.rs`, `private_attention/{wire.rs, tests.rs}`, or the three checking
scripts beyond the lines cited.

**Not derived *here*.** (a) The opening-group counts 35 / 9 — argued from the
tail rule, not enumerated in this memo; the check of this memo enumerated them
with the committed inventory tool and both are now derived, member for member
(`ZK60_PRIVATE_BLOCK_CONSTRUCTION_TIER2_CHECK.md` §7.3). (b) The receipt total
rests on Tier 1's byte model, which is
`hashline/src/private_attention/wire.rs:28-36` verbatim (not a
reverse-derivation, and not absent from source), though I did not read that
file myself. (c) Whether `SC_FZC`'s μ vector of 9 and `SC_DZC`'s of 30 have any
effect on the extension-round premise beyond the degree argument I checked —
R-2 did a full monomial expansion for the accepted layout and I did not. (d)
The exact grown values of the `helper_sums_published` and `no_mask_*` negative
controls. (e) Whether the `Dom::D` plane block stays contiguous under the
Tier-1 + Tier-2 insertions in every ordering, which is an `a_dom` range-match
constraint on the implementer.

**Not verified.** (a) That `fold_cols_i8` is re-exported through
`hashline::mle` under that name — `layer.rs:23` and `zk.rs:609` import it from
`crate::mle`, and I did not confirm the re-export chain from `zkp-core`. (b)
That `blake3`-digesting 256 `i16` words in `BlockPublic::digest` has no
endianness question I have not thought about. (c) The soundness error of the
three-table LogUp identity at the grown multiplicity count — the structure is
the module's, the constant is not re-derived.

**Not analysed.** No privacy analysis of any kind. No simulator. I did not
extend the rank or CFS models, did not evaluate whether the grown layout is
zero knowledge, and did not touch D1, D3, D4, D5 or D12, none of which is
reopened here. Nothing under `/home/victor/IntelligenceRegulation` was read or
written.

## Errata applied (2026-09-19)

Every change below is an item of this memo's check
(`ZK60_PRIVATE_BLOCK_CONSTRUCTION_TIER2_CHECK.md`, errata E-1 … E-22) or a
ruling of `ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md` (R-A, R-B).
Nothing else was edited. E-1, E-3 and E-7 … E-13 touch the Tier-1 memo only
and are recorded in its own errata table; of those, **E-1 needed no change
here** — §0 states the `z16` hole correctly and §G.1 gives the catch; what
was missing was the *guard*, and that is added in T1 §C.2, §D, Decision 4 and
Decision 12 — and **E-13 needed none either**: §F's "Tier 2 adds no label" was
already right.

| Item | Section changed | What changed |
|---|---|---|
| **E-2** (BLOCKING) | §A.3, §E (the `a16` "Enforced by" cell), §F, §I.1 decision 7 | `a16`'s int16 class is now enforced by the proof's own public statement: `BlockPublic::new` refuses any activation value outside `[−32768, 32767]` (`act.iter().all(\|v\| (-32768..=32767).contains(v))`, or `act: [i16; 256]`), mirroring the exp table's check at `hashline/src/private_attention.rs:97-99`; §E's cell cites **that** check, not the kernel's `[i16; 256]`; §F requires the range check and not only `act.len() == 256`. |
| E-4 | §E (the correction to Tier 1's §H.1), §I.1 decision 14(b) | Right conclusion, inadmissible warrant: the honest prover's `input: &[i16]` (`witness.rs:103`, `:108`) and the calibration's `x_cls: Cls::Int16` (`causal_oracle.rs:115`) are replaced by the verifier-enforced classes, `layout.rs:226` + `argument.rs:634` for `x_in` and `layout.rs:232` + `argument.rs:636` for `xres1`, as R-2's method requires. |
| E-5 | §D.3 (model header and closing note), §I.3 "not derived" (b) | The byte model is **read out of `hashline/src/private_attention/wire.rs:28-36`** verbatim; "reverse-derived" and "not read out of `zkp-core/src/pcs.rs`" are gone. |
| E-6 | §D.3 (the `mask_open` line and the `M`-opening row) | `mask_open` is `2·1024·16 + 256·(8 + M_ROWS·8 + 32 + 12·32)`, i.e. `MASK_VEC = 1024` and `MASK_PATH = 12`, not `8,192` and `480`; 243,712 is unchanged, because the two errors cancel. |
| E-14 | §B.1 (the opening paragraph) | The quoted Tier-1 wording is replaced by a reference: T1 made the new `Dom::F` conditional on `F != D`, and that is now corrected there. The finding itself — a variant is required at every geometry — is unchanged. |
| E-15 | §D.4 (the "new slots" and slots / `M`-rows / functionals rows) | The draft's figures are marked as since corrected in T1; the derived `4` and `23 / 50 / 34` stand unchanged. |
| E-16 | §D.2 (totals and the group-count paragraph), §D.3, §I.2, §I.3 "not derived" (a) | The `[E]` tags are dropped: `A` = 35 and `H` = 9 are **derived** member for member by this memo's check (§7.3), go into `layout.rs` as `A_GROUPS` / `H_GROUPS`, and are transcript-bound through `describe()`, a mis-declaration being a hard refusal on both sides. |
| E-17 | §C.1, `SC_FZC`'s relations | `f_act` now reads `v[i_fact]` with `let i_fact = b.h(H_FACT)?;` — `H_FACT` is a **plane** constant, not a table index (the module's own idiom is `let ihx = b.h(H_SEXP)?;` … `v[ihx]`, `argument.rs:706`, `:721`) — and `h0 = 14` is bound explicitly for the `helper_sum` call. |
| E-18 | §G.2, row T-g1 | `byte(A_RGL)` fails too, and always: a negative remainder is `p − 128 + rg` in `Fp`, in neither lookup's table. Both are now named. |
| E-19 | §G.2, the rubric and rows T-g1, T-u2, T-h1, T-h2 | The "each isolates one relation" claim is dropped; each of those four rows now names its two or three independent catches (T-g1 also the activation lookup, T-u2 also `host2`, T-h1 and T-h2 also slot 14), with the reason such a row cannot confirm that one relation is present. |
| E-20 | §G.1 (the quoted rejection message and the assertions) | The `SLOT_NAMES[SC_DZC]` string is one Tier 2 itself invalidates, so the quote is replaced and the test asserts on the slot **index**; a companion assertion that the **honest** proof verifies is added. |
| E-21 | §D.4, the "new `H` helper planes" row | The estimate `~8 + 1` **agrees** with the derived 9; the "why they differ" cell said otherwise and now says so. |
| E-22 | §I.1 decision 5 | Added the sentence that makes it a soundness requirement: wherever `u16(x) = 0`, `f0` pins nothing about `a16(x)` and `f_act` is the only other relation it appears in, so the rejected alternative leaves `a16`, `h16` and `z16` free at every zero of the up matmul. |
| **R-A** | §0 (new "Which files change" paragraph), §C.1 (the `fold_cols_i8` change), §I.2 (the inventory-parser bullet) | Every module file named in this memo is the **block module's own copy** — `hashline/src/private_block.rs` and `hashline/src/private_block/*`, grown from a copy of the attention module, with its own example and test file; `hashline/src/private_attention*` is not edited; the inventory tool must take the module path as a parameter. |
| **R-B** | §F, step 11 | The per-slot labels `pa-*` may be renamed `pb-*` but are not required to be; Tier 2 adds no label either way. |
