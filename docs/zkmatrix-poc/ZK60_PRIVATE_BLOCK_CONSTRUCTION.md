# ZK60 — the composed private block on the custom line: construction memo

**Status: DRAFT for the security owner's review — NOT ACCEPTED. Prepared by a delegated Opus agent on 2026-09-19. (draft complete)**

| | |
|---|---|
| Worktree / branch | `/home/victor/wt-zk60-attention-compile`, `zk60-attention-compile` |
| Inputs | [composition gap inventory](ZK60_PRIVATE_BLOCK_COMPOSITION_GAPS.md) (G1–G15, C1–C6); [decisions register](ZK60_DECISIONS.md) D1, D8, D11, **D12**; [attention construction](ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md) (the memo this one twins at block scope); [native delivery](ZK60_PRIVATE_ATTENTION_NATIVE.md) and its [disposition](ZK60_PRIVATE_ATTENTION_NATIVE_DISPOSITION.md) / [R-2 review](ZK60_PRIVATE_ATTENTION_NATIVE_REVIEW_R2.md); [seam design](ZK60_PRIVATE_SEAM.md) and [seam review](ZK60_OPUS_SEAM_REVIEW.md); [private block design](ZK60_PRIVATE_BLOCK.md); [block contract](ZK60_BLOCK_CONTRACT.md); [endpoint-reuse disposition](ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md) |
| What this is | a **construction**: one recommended shape for a complete private transformer block on the native (hashline) line, precise enough to implement and to run the rank / CFS / inventory tools against. Not an implementation, not a privacy acceptance, not a speed claim. |
| Scope guard | P1 (D1): inputs, outputs and every intermediate activation hidden; weights public. Nothing here narrows that set. |

## 0. The construction in one paragraph

A complete private block is **the existing native private attention component
grown until it is the whole block**, not two components tied together. The
second RMSNorm (`norm_m`), the SiLU feed-forward and the second residual become
more planes, more claim sites and more slots on the *same* `A`, `H` and `M`
commitments the component already builds, under the *same* single transcript,
with the *same* single opening per commitment. There is then no seam object at
all: `nm` and `z16` are ordinary planes of a prover-generated commitment, read
by two relations each at two different challenge points through two reserved
mask pairs — a shape the built component already uses seventy-five times
(`hashline/src/private_attention/layout.rs:9-10`, "a plane opened at k points
has k pairs"). The two caller-fixed endpoints become the block's real
boundary: `x_in` in, **`xres2`** out — which is a change from what is built,
where the output endpoint carries `xres1`
(`hashline/src/private_attention/argument.rs:757`). The alternative — keep two
provers and join them with masked equalities between their own `A` commitments
— is written out in §B.2 and is what the 8B line will probably need, because it
is the only form that keeps the existing GPU feed-forward prover; it is not what
should be built first, because it needs a pending/manifest lifecycle, a second
`M`, a composed wire format and a joint-rank analysis that has never been done
(`ZK60_OPUS_SEAM_REVIEW.md:639-646`, U-2), and none of that buys anything at the
tiny geometry. Concretely, at T32/d16, adding `norm_m` and residual 2 alone
takes the layout from 306/290 rows, 75/35 sites, 18 slots and 40 `M` rows to
**390/332 rows, 102/42 sites, 19 slots and 42 `M` rows**, with the largest CFS
slot unchanged at `L = 50` and 206 coefficients of headroom; §C shows the
arithmetic and §C.5 estimates the feed-forward half on top.

## A. Frame — D12, quoted, and what is built inside it

D12 (`ZK60_DECISIONS.md`, entry "D12 — How a complete private block is composed
on the custom line (construction rule, 2026-09-19)") is binding on everything
below. Its five items, quoted:

> 1. **No commitment is opened more than once, anywhere in a composed block.**
>    The double-opening configuration of
>    `ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md` is not permitted as a seam,
>    as a convenience, or as a test shortcut that could be mistaken for one.
> 2. **A block is one proof under one transcript with exactly two external
>    endpoints**: its hidden input `x_in` and its hidden output `xres2`. Two
>    separately finished component receipts glued by a shared root are not a
>    block.
> 3. **Hidden intermediates never get a caller-fixed endpoint commitment shared
>    by two proofs.** `xres1`, `nm` and `z16` live only on commitments the
>    prover generates inside that one proof. How the two halves are tied
>    together there (an equality between the two components' own commitments
>    with reserved mask pairs and a seam slot, as
>    `ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md` line 99 specifies, or a single
>    shared layout with no seam at all) is settled in the block construction
>    memo, with the simpler form built first and the other documented with
>    what it is worth.
> 4. **The second norm must prove that its output is in the int8 class.** The
>    feed-forward prover proves no range on its own input (verified in
>    `hashline/src/layer.rs`: the lookup list covers the activation, the two
>    int16 planes and the output, never the input plane), so without this the
>    composed statement would admit an out-of-class feed-forward input.
> 5. **Declared endpoint scales must be tied to the approved calibration**
>    before any seam compares them. Today the tag proves nothing, and the
>    attention fixtures declare `(-3, -3)` where the calibration has
>    `e_r = e_r1 = 0`; a tag-equality check would pass on a factor-of-8
>    mismatch.

This memo is the document item 3 names. It builds inside the five items as
follows, and nothing below may be read as weakening any of them.

**Item 1** is satisfied structurally, not by argument: the recommended form has
exactly five commitments — `A`, `H`, `M` (all prover-generated) and the two
caller-fixed endpoint planes — and each is opened once, in the fixed order
`M, A, H, In, Out`, with its owner dropped immediately after
(`hashline/src/private_attention/protocol.rs:365-381`). Nothing in §C or §D
adds a sixth commitment or a second opening.

**Item 2** is satisfied because the recommended form never had two transcripts
to join: one `Transcript::new(PROFILE)` is created at
`protocol.rs:266` and finished by the four openings at `:365-381`, and the block
adds slots to that one run. The two external endpoints are `x_in` (slot
`SC_IO_IN`) and `xres2` (slot `SC_IO_OUT`).

**Item 3** is where the built component must change. Today its output endpoint
— a *caller-fixed* root (`private_attention.rs:161-168`, `:220-231`) — commits
`xres1`, a hidden intermediate of a block (`argument.rs:757` opens plane
`A_X1` against `Cm::Out`). That is correct for a standalone attention-half
experiment and is exactly what item 3 forbids for a block half. In the block,
`SC_IO_OUT` binds `A_X2` (`xres2`); `xres1`, `nm` and `z16` are planes of the
prover-generated `A` and touch no caller-fixed root. The same reading applies to
the feed-forward IO profile, which binds `z16` to a caller-fixed endpoint
(`hashline/src/zk_ffn_fresh_io.rs:284`, `:346`): fine as a standalone
experiment, not usable as a block half.

**Item 4** is discharged by `sym(A_YM)` in §C.1 — the same two-lookup
`[-127, 127]` proof the component already applies to `norm_a`'s output
(`layout.rs:193-195`, used at `:227`). Item 4's premise re-checks in the source:
the feed-forward prover's LogUp helper specs cover `g8`/`a16`, `u16`, `h16` and
`z`/`rd` and never `lay.x` (`hashline/src/zk.rs:2685-2690`, GPU mirror
`hashline/src/layer.rs:1395-1400`); `lay.x[c]` appears only in evaluation claims
(`zk.rs:3350`, `:3360`), never in a range lookup.

**Item 5** is §F: the block's `IoSpec` is pinned to the calibration's `e_r = 0`
and `e_r2 = 0` (`hashline/src/causal_oracle.rs:116`, `:146`) by a constructor
refusal, and the calibration identity is absorbed with the statement.

## B. The seam form — one recommendation

Plain words first. A *seam* is the place where one half's hidden output is the
other half's hidden input. The two halves must agree on a value neither may
reveal. There are only two honest ways to do that under D12: either the value
never crosses a boundary at all because both halves live in one commitment
(form S), or the value lives twice, once on each half's own commitment, and a
masked equality proves the two copies agree (form E). Form E is not a
convenience — it is the thing that needs new machinery. Form S is not a
compromise — it is the absence of the problem.

### B.1 Form (S): one shared layout, no seam

**What it is.** The `private_attention` module's `Layout`
(`hashline/src/private_attention/layout.rs:403-450`) grows to hold the whole
block: `norm_m`'s planes, the feed-forward's planes, residual 2's planes. `nm`
is then one plane on `A`, produced by the `norm_m` relations and consumed by
the feed-forward gate and up matmuls — two relations, one plane, two claim
sites at two challenge points, each with its own reserved mask pair. Nothing is
"shared between proofs" because there is one proof.

**What must change, in which files.**

| File | Change |
|---|---|
| `hashline/src/private_attention/layout.rs` | new `A` planes (§C.1, §C.2, §C.5), a new `Dom::F` for the feed-forward inner axis if `F != D` (at this geometry `F = D = 16`, so `Dom::D` serves), new entries in `lookups`/`helpers`, new slot ids in `SC_*`, `SLOT_NAMES`, `SLOTS`, `SLOT_KINDS`, `HOSTS`, `A_SITES`, `H_SITES`, `A_GROUPS`, `H_GROUPS`, `N_FUNCTIONALS`; `describe()` gains the new lines and the schedule digest changes |
| `hashline/src/private_attention/witness.rs` | compute `norm_m`, the SiLU feed-forward and residual 2 with kernel semantics (`private-block-kernel/src/lib.rs:616-618`, `:627-645`, `:647-651`); `Witness::output()` returns `A_X2` instead of `A_X1` (`witness.rs:19-22`) |
| `hashline/src/private_attention/argument.rs` | new arms in `define` for the new slots; extended `SC_TZC`, `SC_LZC`, `SC_DZC` arms; `SC_IO_OUT` opens `A_X2` (`:757`) |
| `hashline/src/private_attention.rs` | `AttentionPublic` → `BlockPublic`: add `gamma_m`, `wg_t`, `wu_t`, `wd_t` and the activation table, new digest domain; new `PROFILE`; `IoSpec` slots and scale pinning (§F); `compute_output` returns `xres2` |
| `hashline/src/private_attention/protocol.rs` | unchanged in structure; the parameters label and the transcript labels change (§D) |
| `hashline/src/private_attention/wire.rs` | shape is derived from `Layout`, so it follows; only the profile magic changes |
| **not touched** | `hashline/src/zk.rs`, `hashline/src/layer.rs`, `hashline/src/zk_ffn_fresh_io.rs`, `hashline/src/private_seam.rs` (except the slot-tag table of §F), `attention.rs`, any frozen profile |

**Cost at the tiny geometry.** Derived in §C. Adding `norm_m` and residual 2
alone: `A` 306 → 390 rows, `H` 290 → 332, sites 75/35 → 102/42, slots 18 → 19,
`M` 40 → 42 rows, 28 → 29 functionals, host groups 5 (unchanged, but `SC_TZC`
goes from hosting one slot to hosting two). **Seam cost: zero** — no seam pair,
no seam slot, no extra opening group for a seam, no second `M`.

**At 8B scale.** This is where form (S) is weakest, and the memo should say so
plainly. Two facts from the source:

- The feed-forward prover's data planes are *block-decomposed*: `nb_d` blocks of
  `2^log_db` on the `d` axis and `nb_f` blocks of `2^log_fb` on the `f` axis
  (`hashline/src/layer.rs:1185-1186`; 768 = 3 × 256, 14336 = 7 × 2048), and the
  CUDA kernels are written against that decomposition
  (`layer.rs:1379-1383`, the `dev_shape` gate). Re-deriving the feed-forward
  inside the attention module's idiom means re-deriving it **on the host**; the
  GPU path does not come with it.
- One 8B layer's commitments already fill an 8 GB part: the prover comments
  record `gpu zk commit H (v3): cuMemAlloc(1514 MB) OUT_OF_MEMORY` at layer 1 of
  the first 32-layer attempt, and drain the device pool between layers for that
  reason (`hashline/src/zk.rs:2388-2394`, again at `:2576-2580`). A single `A`
  holding attention **and** feed-forward planes is a strictly larger matrix to
  commit in one shot.

Honest counterweight, because it cuts the other way too: form (E) does **not**
reduce peak residency for one block. D12 item 2 puts both halves under one
transcript, so both `A` roots must be absorbed before the seam challenge is
drawn (`ZK60_OPUS_SEAM_REVIEW.md:236-243`) and both commitments must survive
until their single openings at the end. Both halves are live simultaneously in
either form. What form (E) actually buys at 8B is **reuse of the existing
block-decomposed, GPU-accelerated feed-forward prover**, not a smaller peak.

**Interaction with "each component finishes its own transcript".** Form (S)
does not have this problem: there is one prover, `protocol::prove_inner`
(`protocol.rs:248-394`), which already creates the transcript at `:266` and
finishes it at `:365-381`. No outer `&mut Transcript` parameter is needed
anywhere, which is precisely what neither existing component can accept today
(`protocol.rs:26-33`, `zk_ffn_fresh_io.rs:138-146`, `:163`; recorded as C5 and
U-4).

### B.2 Form (E): an equality between two components' own commitments

**What it is.** Two provers, one transcript. `nm` is a plane on the attention
side's `A`; the feed-forward's input is `lay.x[c]` on its own `A`
(`hashline/src/layer.rs:78`); a masked equality sumcheck proves the two
multilinear extensions agree at a point drawn after **both** `A` roots and both
`M` roots are absorbed, in the S2 form implemented standalone at
`hashline/src/private_seam.rs:259-261` (prover `:335-428`, verifier `:432-505`).
The same again for `z16` in the other direction, so residual 2 can add it to
`xres1`. Each commitment is still opened exactly once: the seam claim rides the
single opening.

**What must change, in which files.**

| File | Change |
|---|---|
| `private_attention/layout.rs`, `argument.rs` | two reserved seam pairs on the attention `A` (`SeamNm`, `SeamZ16`), claimed at the seam sumchecks' own tails; `norm_m` and residual 2 planes as in form (S) |
| `private_attention/protocol.rs` | split `prove_inner` into `prepare` (through the `A`, `M`, `H` commits) and `finish` (the seam claims, then the openings); accept an **outer** `&mut Transcript`; a `Pending` type that is not `Clone` and whose `finalize` consumes it |
| `hashline/src/zk.rs` | a `RoleSet`/manifest on `ZkLayoutV3`; today only the two IO mask pairs are reserved before the `A` commit (`zk.rs:2056-2062`, `with_io`), and only two extra CFS slots (`zk.rs:2172`). Two seam pairs and two seam slots must join them, and `PendingV3::finish` (`zk.rs:2306-2334`) must refuse an unconsumed or twice-consumed role |
| `hashline/src/zk_ffn_fresh_io.rs` | a new profile: the transcript must come from outside (`:138-146`, `:163`), the seam claims must be pushed onto `self.pending.ac` before `finish`, and the input/output endpoints must disappear (the block's endpoints are the attention side's) |
| a new `hashline/src/private_block.rs` | the composed statement, the composed profile id, the composed bounded wire frame, the block-level `prove`/`verify` |
| `hashline/src/zk_ffn_fresh_wire.rs` | not extensible: six fixed terminal counts, 16 `M` base rows, 5 `A` groups, and a binding digest with no endpoint field (`ZK60_OPUS_SEAM_REVIEW.md:337-357`, U-6). A replacement frame is required |

**Cost at the tiny geometry.** Two seam pairs on the attention `A` (+4 rows) and
two on the feed-forward `A` (+4 rows)
(`ZK60_OPUS_SEAM_REVIEW.md:251-275`, `:283-286`); two CFS slots at
`(log_t + log_db + 1, 2) = (10, 2)`, `L = 22` each, on the feed-forward `M`,
taking it from 16 to 20 base rows (`ZK60_OPUS_SEAM_REVIEW.md:291-336`); attention
`A` opening groups 30 → 32 and feed-forward `A` groups 5 → 7 (two new column
tails). Plus everything form (S) needs anyway for `norm_m` and residual 2
(§C.1, §C.2), minus nothing. Plus a second `M` commitment in the receipt, a
second mask opening and a second set of PCS column openings, which is the
dominant byte cost: on the model of §C.4 a 20-row `M` opening alone is
`8192 + 256 × (8 + 160 + 32 + 480) = 178,432` bytes [ESTIMATE, the model is
reverse-derived].

**What it does not discharge.** Three things, all on record: the seam adds
opening groups on rows other groups already open and **no joint analysis covers
that** (`ZK60_OPUS_SEAM_REVIEW.md:639-646`, U-2); a shared mask row across two
opening groups leaves the *difference* of the two evaluations in the clear, so
the fresh pair per seam is mandatory, not optional
(`ZK60_OPUS_SEAM_REVIEW.md:258-275`, citing `zk.rs:1971-1974`); and nothing
marks a seam role consumed exactly once on either side (U-3, and §E below for
what the native module *does* already enforce). Two `M` commitments also
reopen the CFS-channel question jointly (U-14).

### B.3 Recommendation, what the other form is worth, and the measurement

**Recommendation: build form (S) first.** One reason, stated once: form (S)
satisfies D12 with **no new privacy machinery at all** — no seam relation, no
second `M`, no second transcript, no pending/manifest for a seam role, no new
opening group, no composed wire frame — whereas form (E) needs all six *and*
still needs everything form (S) needs for `norm_m` and residual 2. The
"simplest form that is faithful to D12" is the one that removes the seam rather
than the one that proves it.

Secondary reasons, in order:

1. The arithmetic form (S) must add is arithmetic the module already proves.
   The feed-forward is three matmuls, one 256-entry activation lookup, one
   product and four requantizations
   (`private-block-kernel/src/lib.rs:627-645`); the module already proves four
   matmuls with requantization and remainder limbs (`SC_QMM`, `SC_KMM`,
   `SC_VMM`, `SC_WO`, `argument.rs:559-583`), a 256-entry table lookup with a
   committed histogram and a helper column (`SC_TAB`, `:732-748`), and a
   product of two private planes with two extension rounds (`SC_PV`, `:598-610`).
2. Form (S) closes C4 and C6 by construction. C4 (the int8/int16 class mismatch
   at the seam) disappears because `norm_m` and the feed-forward read one plane.
   C6 (the endpoint verifier uses `NttTables::new(12)` on the attention side and
   `new(16)` on the feed-forward side, `private_attention/protocol.rs:263` vs
   `zk_ffn_fresh_io.rs:436`) disappears because there is one verifier with one
   table (`new(12)`).
3. Form (S) keeps the one executable check that exists. The rank/CFS re-run is
   driven by `scripts/zk60_attention_native_inventory.py`, which parses
   `layout.rs`, `argument.rs::define` and `protocol.rs::logup_sum_claim`
   directly (`:15-32`). It has no notion of two components; form (E) would need
   the tool rewritten in the same commit that needs the tool most.

**What form (E) is worth.** It is worth the 8B feed-forward prover. The
block-decomposed CUDA path (`layer.rs:1379-1400`, `zk.rs:2685-2690`) is the
custom line's only measured route to throughput, and form (S) does not inherit
it. Form (E) is also what a *streamed* multi-block proof would need if one
block's commitments cannot be resident at once — a constraint that does not
bind at T32/d16 and does bind at 8B (`zk.rs:2388-2394`). So form (E) is not
discarded; it is deferred, with its cost written down here so it can be picked
up without re-deriving.

**The measurement that would justify revisiting.** Two numbers, on a quiesced
box, at the first integration rung (the frugal-lm ladder shape, 125M,
768 → 2048, i.e. `nb_d = 3`, `nb_f = 1`, `layer.rs:1211`):

1. **peak resident bytes** of a form-(S) single-`A` commit versus the sum of the
   two form-(E) commits plus their simultaneous residency. If form (S)'s peak
   exceeds the card and form (E)'s does not, form (E) is forced.
2. **prover wall-clock of the feed-forward half**, host-only (form S) versus
   `prove_layer_zk_v3` on the GPU (form E). If the ratio at 125M exceeds the
   margin the 8B budget can absorb, form (E) is forced.

Neither measurement is taken here, and neither can be taken on the current box
while it is loaded (the project's measurement rule).

### B.4 Where `norm_m` and residual 2 live

Same treatment, same answer, and under form (S) the question mostly dissolves —
but it must still be answered, because form (E) inherits it and because it
decides which commitment holds which plane.

| Placement | What it would need | Verdict |
|---|---|---|
| **(a) attention-side component** (recommended) | `norm_m` reads `xres1`, which is already plane `A_X1` on the attention `A` (`layout.rs:106`), produced there by residual 1 (`argument.rs:637`, the `c5` term). `norm_m`'s planes and its int8 proof reuse the norm machinery that is already there for `norm_a` (`SC_SS`, `SC_TZC`, `SC_LZC` and the `c0`/`c1` terms of `SC_DZC`). Residual 2 reads `xres1` (same commitment) and `z16`; under (S) `z16` is on the same commitment too, under (E) it arrives by one seam | **Recommended.** It is the only placement in which `xres1` is read by all three of its consumers — residual 1 produces it, `norm_m` consumes it, residual 2 adds it (`private-block-kernel/src/lib.rs:610-651`) — from a single commitment opened once. That is G5, the gap inventory's "central" decision, answered |
| **(b) feed-forward-side** | The feed-forward `A` has no norm planes, no isqrt limbs, no `[-127,127]` lookup and no int16 limb planes; its table set is `table_specs_v3` (`zk.rs:2014`), not the attention module's single U8 table. `norm_m` there would need `xres1` across a seam **and** a whole norm apparatus built from nothing, and would still owe the int8 proof of D12 item 4 | **Rejected.** It moves the work to the side that has none of the machinery and adds a seam on `xres1` — the exact value section 4 of the gap inventory shows must not cross a caller-fixed root (S1) |
| **(c) a thin block layer** (a third commitment holding `nm`, `xres2` and the residual-2 relation) | Three or four seams instead of one or two, its own mask rows, its own proximity pair, its own slots, and a third `A` in the joint analysis | **Rejected.** It multiplies U-2 (the uncovered joint-rank question) by the number of seams and buys nothing: the thin layer has no arithmetic of its own that the attention-side component cannot host |

**Decision:** `norm_m` and residual 2 both live in the attention-side
component's commitments. Under form (S) that component *is* the block.

## C. The grown layout

Everything in §C.1–§C.4 is **Tier 1**: the attention component plus `norm_m`
plus residual 2. Every number in Tier 1 is derived from
`hashline/src/private_attention/layout.rs` and `argument.rs` by the same
arithmetic those files use, and each derivation is shown. **Tier 2** (§C.5) is
the feed-forward half under form (S) and is marked `[ESTIMATE]` throughout,
because designing the feed-forward's plane and slot encoding is a separate
piece of work that §C does not claim to have done.

Plane indices below are the module's own and will renumber when planes are
inserted; that is expected and harmless, because every count the verifier uses
is rebuilt from `Layout` and the whole description is bound by
`Layout::schedule_digest` (`layout.rs:502-510`).

### C.1 `norm_m`: planes, helper planes, range lookups, pointwise checks, claimed sums

**What it must prove** (`private-block-kernel/src/lib.rs:618` calling
`rms_norm` `:382-411`, constants `calib::NORM_*` at `:61-64`). Per row `t` of
`xres1`:

```
ss   = Ceps + Σ_i xres1[t,i]²                       (Ceps = 1)
D    = isqrt(ss),  pinned by  Dsq = D·D,  a1 = ss − Dsq ≥ 0,  a2 = 2D − a1 ≥ 0
per i:  2·Cn·gamma_m[i]·xres1[t,i] + D·2^tn  =  nm[t,i]·D·2^(tn+1) + ρ
        σ = D·2^(tn+1) − 1 − ρ,   ρ, σ ∈ [0, 2^29),   nm[t,i] ∈ [−127, 127]
```

with `tn = 11`, `Cn = 1024`, `wrho = 29`. This is the *identical* relation the
component already proves for `norm_a`, with `gamma_m` for `gamma_a` and
`xres1` (plane `A_X1`) for `x_in` (plane `A_X`).

**The planes `norm_a` uses today, named, and their `norm_m` mirrors.** The
left column is what is built; the right column is what §C adds.

| `norm_a` plane (`layout.rs`) | domain | rows | `norm_m` mirror | rows |
|---|---|---:|---|---:|
| `A_D` `:90` — the isqrt `D` per row | `Dom::T` (5 vars, 32) | 1 | `A_DM` | 1 |
| `A_DSQ` `:91` — `D²` | `Dom::T` | 1 | `A_DSQM` | 1 |
| `A_LIMB` `:95` — 16 packed 32-entry sub-planes; `0..3` the byte limbs of `D`, `3..6` of `a1`, `6..9` of `a2` (`N_LIMBS = 9`, `:139`) | `Dom::L` (9 vars, 512) | 2 | `A_LIMBM` | 2 |
| `A_Y` `:99` — the norm output, int8 class | `Dom::D` (9 vars, 512) | 2 | `A_YM` (this is `nm`) | 2 |
| `A_NR0..A_NR0+3` `:100` — the four byte limbs of `ρ` | `Dom::D` | 8 | `A_MR0..A_MR0+3` | 8 |
| `A_NS0..A_NS0+3` `:101` — the four byte limbs of `σ` | `Dom::D` | 8 | `A_MS0..A_MS0+3` | 8 |
| `A_X` `:96` — the norm *input* | `Dom::D` | 2 | `A_X1` `:106`, already present | 0 |

**Twelve new planes, 22 new `A` data rows** (`rows_of(log) = ⌈2^log / 256⌉`:
`Dom::T` → 1, `Dom::L` → 2, `Dom::D` → 2; `layout.rs:399-401`):
`1 + 1 + 2 + 2 + 4·2 + 4·2 = 22`.

Why a second `Dom::L` plane rather than repacking: `A_LIMB` holds sixteen
32-entry sub-planes of which nine are used and **seven are free**
(`layout.rs:94`), and `norm_m` needs nine. Repacking is not possible without
widening the domain, so `A_LIMBM` is the faithful mirror. Its price is priced
below (`SC_LZC`'s degree).

**Helper planes.** LogUp helpers live on `H`, one Fp2 column per *pair* of
lookups (`layout.rs:197-198`, "helper `k` covers lookups `(2k, 2k+1)`"). Two
domains change.

- `Dom::D` today declares **20** lookups (`layout.rs:225-233`: 2 int16 byte
  limbs of `x_in`, `sym(A_Y)` = 2, four `ρ` limbs + one scaled top limb = 5,
  five for `σ`, six for `ao`/`rao`/`xres1`), hence
  `⌈20/2⌉ = 10` helpers `H_D0..H_D0+9` (`layout.rs:156`, `:265`). §C.1 and
  §C.2 append **14** lookups (below), giving **34** and `⌈34/2⌉ = 17` helpers,
  i.e. **+7 `H` planes** `H_D0..H_D0+16`. The append is clean because 20 is
  even: no existing helper's pair changes.
- `Dom::L` today declares **1** lookup and has 1 helper `H_L` in the
  *single-lookup* branch (`argument.rs:460-466`, relation `h·d1 − 1`, degree 2).
  Adding `byte(A_LIMBM)` makes it 2 lookups, still 1 helper, but in the
  *two-lookup* branch (`h·d1·d2 − (d1 + d2)`, degree 3). Multiplied by
  `eq(τ)` the `SC_LZC` zero-check therefore goes from degree 3 to **degree 4**:
  `SLOTS[SC_LZC]` `(9, 1, 3)` → `(9, 1, 4)`, `L = 10·4 + 2 = 42`.
  (Alternative, recorded not proposed: give `A_LIMBM` its own slot at degree 3;
  it costs one more slot and two more `M` rows and saves 10 bytes of proof. Not
  worth it.)

**Range lookups added, including D12 item 4.** All into the single 256-entry
U8 table, in the `Dom::D` list (`layout.rs:225-233`), appended in this order:

| Lookup | Form (`layout.rs:185-195`) | What it enforces |
|---|---|---|
| `sym(A_YM)` (2 lookups) | `A_YM + 127 ∈ U8`, `127 − A_YM ∈ U8` | **`nm ∈ [−127, 127]`, the int8 class of the feed-forward's input — D12 item 4.** Byte-for-byte the shape used for `norm_a`'s output at `layout.rs:227` |
| `byte(A_MR0+k)`, `k = 0..3` (4) | each limb `< 256` | `ρ` decomposes into four bytes |
| `scaled(A_MR0+3, 1 << (32 − NORM_WRHO))` = `scaled(·, 8)` (1) | `8·limb₃ ∈ U8`, i.e. `limb₃ < 32` | `ρ < 2^29` **exactly** (mirrors `layout.rs:229`) |
| `byte(A_MS0+k)`, `k = 0..3` (4) | | `σ` byte limbs |
| `scaled(A_MS0+3, 8)` (1) | | `σ < 2^29` exactly (mirrors `:231`) |
| `byte(A_X2L0)`, `byte(A_X2L1)` (2) | | residual 2's int16 limbs — §C.2 |

Fourteen lookups. `Dom::D`'s lookup count 20 → 34; the U8 lookup total rises
from 47,104 to **54,784** (see §C.3).

**Pointwise checks, as zero-check terms.** Nothing is compared in the clear.
`norm_m`'s per-element relation is a μ-batched degree-≤2 term of the **same**
`Dom::D` zero-check that already carries `norm_a`'s
(`argument.rs:611-646`, slot `SC_DZC`, `(9, 1, 4)`). The existing terms are
`c0 … c5`; `norm_m` and residual 2 append `c6 … c9`:

```
c0 = 2·Cn·gamma_a(i)·x   + 2^tn·D  − 2^(tn+1)·y ·D  − ρ           (built, :632)
c1 = σ  + ρ  + 1 − 2^(tn+1)·D                                      (built, :633)
c2 = x    + 32768 − (XL0   + 256·XL1)                              (built, :634)
c3 = ao   + 32768 − (AL0   + 256·AL1)                              (built, :635)
c4 = x1   + 32768 − (X1L0  + 256·X1L1)                             (built, :636)
c5 = x1 − x − ao                                                   (built, :637)
c6 = 2·Cn·gamma_m(i)·x1  + 2^tn·Dm − 2^(tn+1)·nm·Dm − ρm           (NEW)
c7 = σm + ρm + 1 − 2^(tn+1)·Dm                                     (NEW)
c8 = x2   + 32768 − (X2L0  + 256·X2L1)                             (NEW, §C.2)
c9 = x2 − x1 − z16                                                 (NEW, §C.2)
```

`gamma_m` enters as a second public broadcast table beside `gamma_a`
(`argument.rs:617`). `Dm` enters as a second `a_slice` of `A_DM` at `log 5`
broadcast over the `Dom::D` cube, exactly as `A_D` does at `:619`. The μ vector
grows from `6 + helpers(Dom::D).1` to `10 + 17` (`:613`). **The slot's shape
does not change**: the highest-degree monomials are still `nm·Dm` (2) and the
two-lookup helper relation (3), times `eq(τ)` → degree 4, and the domain is
still `Dom::D`, 9 variables + 1 extension. `SLOTS[SC_DZC]` stays `(9, 1, 4)`
and `L = (9 + 1)·4 + 2 = 42`, unchanged.

**The SS row sums, and their mask slots.** `norm_a`'s `ss` is a **private
claimed sum**: slot `SC_SS` (`argument.rs:516-521`) sums
`eq(r_t, x)·A_X(x)²` over the `Dom::D` cube and publishes one masked scalar
`s + c·G`; the value it stands for is reconstructed inside its host, the
`Dom::T` zero-check `SC_TZC`, as `ν·eq(r_t, x)·(Dsq + a1 − Ceps)(x)`
(`argument.rs:537`). `norm_m` needs its own:

- **New slot `SC_SSM`**, `Private`, shape `(9, 1, 3)` exactly like `SC_SS`,
  tables `eq(r_t2, 0)` and `A_X1`, polynomial `v[0]·v[1]·v[1]`. One `A` site
  (`A_X1` at the new point `r_t2 ‖ ρ_SSM`) with its own reserved pair. `A_X1`
  is thereby opened at four points in the block (`SC_DZC`'s `ρ_D`, `SC_SSM`'s
  point, `SC_IO_OUT`'s old site is gone, and residual 2 reads it inside
  `SC_DZC`) — permitted, and each point gets its own pair
  (`layout.rs:9-10`).
- **Its host is `SC_TZC`, extended, not a new slot.** `Dsq_m` and `a1_m` live
  on `Dom::T`, the same domain `SC_TZC` already runs over, so the second norm's
  T-domain relations and second host term fold in:

```
SC_TZC grows from  μ(3), ν(1), hosted = [(SC_SS, ν)]
                to μ(6), ν(2), hosted = [(SC_SS, ν0), (SC_SSM, ν1)]
new zero-check terms:  μ3·(Dsqm − Dm·Dm),  μ4·(Dm − dlm),  μ5·(2·Dm − a1m − a2m)
new host term:         ν1·eq(r_t2, x)·(Dsqm + a1m − Ceps)(x)
new A sites:           A_DM, A_DSQM, and the nine 32-entry sub-slices of A_LIMBM   (+11)
shape unchanged:       (5, 1, 3), L = 6·3 + 2 = 20
```

Recommending one host rather than two is a real choice (Decision 6 in §H): it
keeps the slot count and `M` rows down, at the price of `SC_TZC` hosting two
private slots instead of one, i.e. `k` going 1 → 2 and its CFS host-group rank
expectation changing from `ΣL − 2 = 50` to `ΣL − 3 = 81` (§G).

**Claimed sums and their mask slots, summarised.** Two private claimed sums for
the two norms (`SC_SS`, `SC_SSM`), each publishing one masked scalar
`claim_s = s_s + c_s·G_s` absorbed before the slot's first round challenge
(`argument.rs:270`, `:274`), each hosted exactly once, each contributing only
inside its host's batched `Γ_host = c_h·G_h − Σ ν_s κ_s c_s·G_s`
(`argument.rs:350-357`). No standalone `Σ` functional exists for a hosted slot
or for a host — publishing one would reveal `s_s = claim_s − c_s·G_s`, which is
the negative control `nc_sigma_functional_for_private_slot` (§G).

### C.2 Residual 2: `xres2 = xres1 + z16`

**What it must prove** (`private-block-kernel/src/lib.rs:647-651`, with
`SH_X2 = SH_Z2 = 0` and `SH_R2 = 0` at `:85-87`, so `requant` is the identity
and the whole step is an integer addition followed by an int16 refusal):

```
xres2[i] = xres1[i] + z16[i]        exactly
xres2[i] ∈ [−32768, 32767]          refuse otherwise
```

This is byte-for-byte the shape of residual 1
(`private-block-kernel/src/lib.rs:610-614`; proved at
`argument.rs:636-637` as `c4` and `c5`, with the int16 limbs `A_X1L0`/`A_X1L1`
at `layout.rs:107-108` and their byte lookups at `layout.rs:232`).

**New planes** (all `Dom::D`, 2 rows each, 8 rows total):

| Plane | Contents |
|---|---|
| `A_Z16` | the feed-forward output `z16`. Under form (S) this is the feed-forward's own output plane, counted once; under form (E) it is the seam-bound copy |
| `A_X2` | `xres2`, the block output |
| `A_X2L0`, `A_X2L1` | the two byte limbs of `xres2 + 32768` |

**Class proof.** `x2 + 32768 = X2L0 + 256·X2L1` (term `c8`) with
`byte(A_X2L0)` and `byte(A_X2L1)` in the U8 table forces
`xres2 + 32768 ∈ [0, 65536)`, i.e. `xres2 ∈ [−32768, 32767]` exactly — the
kernel's refusal window, and the same two-limb-offset-32768 argument the module
states for `x_in`, `ao` and `xres1` in the wraparound premise at
`layout.rs:204-206`.

**Relation.** `c9 = x2 − x1 − z16`, a degree-1 term of `SC_DZC` under its own
μ, exactly as `c5` is for residual 1.

**Endpoint.** `SC_IO_OUT` (`argument.rs:754-760`) changes the plane it binds
from `A_X1` to `A_X2`. Nothing else about the slot changes: same shape
`(9, 1, 2)`, same `eq(τ)·(plane − endpoint)` polynomial, same one `A` site and
one endpoint terminal, same `check_endpoint_opening` shape test
(`protocol.rs:186-198`). `z16` never becomes an external endpoint (D12 item 3).

**`z16`'s own class.** Residual 2 does **not** prove `z16 ∈ int16`; the
feed-forward half does, as the kernel does
(`private-block-kernel/src/lib.rs:645`, `requant_all(&mut z, SH_Z, I16)`), and
as the existing feed-forward prover does through its `z`/`rd` LogUp helper
(`zk.rs:2690`). Under form (S) that obligation moves into Tier 2 (§C.5) and
must be discharged there — it is listed as an open item, not as done.

### C.3 The counts, next to the accepted ones

The accepted component's numbers are
`ZK60_PRIVATE_ATTENTION_NATIVE.md:85-96` and
`layout.rs:523-555` (the self-consistency test), re-derived here before growing
them so the arithmetic is checkable.

**`A` data rows.** `Σ_planes rows_of(a_dom(p).log())`:

```
accepted:  A_D,A_DSQ (T)          2×1 =  2
           A_MX,A_SUM (Ht, 64)    2×1 =  2   → 4
           A_LIMB (L, 512)        1×2 =  2   → 6
           A_X..A_X1L1 (D, 512)  19×2 = 38   → 44
           A_Q8..A_RO1 (Q, 512)   7×2 = 14   → 58
           A_K8..A_RKRL (Kv,256)  6×1 =  6   → 64
           A_S8..A_SG1 (S, 2048) 11×8 = 88   → 152
           A_MU8,A_MEXP (Tab)     2×1 =  2   → 154   ✓ layout.rs:527
grown:     + A_DM, A_DSQM (T)     2×1 =  2
           + A_LIMBM (L)          1×2 =  2
           + A_YM, A_MR0..3, A_MS0..3 (D)  9×2 = 18
           + A_Z16, A_X2, A_X2L0, A_X2L1 (D) 4×2 = 8
           = 154 + 30 = 184
```

**`A` claim sites.** `A_SITES` today is
`[1, 11, 1, 2, 1, 1, 1, 2, 2, 1, 20, 8, 7, 13, 2, 0, 1, 1]`, summing to 75
(`layout.rs:381`, `:525`). The block changes four entries and adds one:

| Slot | today | grown | why |
|---|---:|---:|---|
| `SC_SSM` (new, index 1) | — | **1** | `A_X1` at the SS_m point |
| `SC_TZC` | 11 | **22** | `+ A_DM, A_DSQM`, `+ 9` sub-slices of `A_LIMBM` |
| `SC_LZC` | 1 | **2** | `+ A_LIMBM` on `Dom::L` |
| `SC_DZC` | 20 | **34** | `+ 13` new `Dom::D` planes at `ρ_D` (`A_YM`, `A_MR0..3`, `A_MS0..3`, `A_Z16`, `A_X2`, `A_X2L0`, `A_X2L1`), `+ 1` broadcast slice of `A_DM` |
| `SC_IO_OUT` | 1 | 1 | plane changes `A_X1` → `A_X2`, count unchanged |
| all others | | unchanged | |

`75 + 1 + 11 + 1 + 14 = 102`.

**`H` claim sites.** `H_SITES` today
`[0,0,1,0,0,0,0,0,0,0,10,7,6,8,2,1,0,0]` = 35 (`layout.rs:382`, `:526`). Only
`SC_DZC` changes, 10 → 17 (its `b.h()` calls equal `helpers(Dom::D).1`,
`argument.rs:620-623`). `35 + 7 = 42`.

**`H` data rows.** Each `H` plane is Fp2 — a `re` slice and an `im` slice, so
`2 × rows_of(log)` (`layout.rs:438-445`):

```
accepted:  H_L (L)         2×2 =   4
           H_D0..+9 (D)   10×4 =  40  →  44
           H_Q0..+6 (Q)    7×4 =  28  →  72
           H_KV0..+5 (Kv)  6×2 =  12  →  84
           H_S0..H_SEXP(S) 8×16 = 128 → 212
           H_GU8,H_GEXP,H_U (Tab) 3×2 = 6 → 218   ✓ layout.rs:528
grown:     + 7 helpers on Dom::D  7×4 = 28  →  246
```

**Totals.**

| Quantity | accepted | grown (Tier 1) | arithmetic |
|---|---:|---:|---|
| `A` data rows | 154 | **184** | 154 + 30 |
| `A` site-pair rows | 150 | **204** | 2 × 102 |
| `A` proximity pair | 2 | 2 | |
| **`A` rows** | **306** | **390** | 184 + 204 + 2 |
| `H` data rows | 218 | **246** | 218 + 28 |
| `H` site-pair rows | 70 | **84** | 2 × 42 |
| `H` proximity pair | 2 | 2 | |
| **`H` rows** | **290** | **332** | 246 + 84 + 2 |
| `A` sites | 75 | **102** | above |
| `H` sites | 35 | **42** | above |
| CFS slots | 18 | **19** | `+ SC_SSM` |
| slot kinds | 8 private / 5 standalone / 5 host | **9 / 5 / 5** | `SC_SSM` is private |
| host groups | 5 | **5** | `SC_TZC` now hosts 2 |
| **`M` rows** | **40** | **42** | `2·19 + 4` (`layout.rs:388`) |
| **`M` functionals** | **28** | **29** | `19 + 5 + 5` (`layout.rs:533`) |
| largest CFS slot `L` | 50 (`SC_SZC`) | **50** (`SC_SZC`) | `L_s + 256 = 306 ≤ 512`, headroom 206 |
| `A` opening groups | 30 | **31** `[ESTIMATE]` | see below |
| `H` opening groups | 8 | **8** `[ESTIMATE]` | see below |
| U8 lookups | 47,104 | **54,784** | `2·512 + 34·512 + 13·512 + 12·256 + 13·2048` |
| exp lookups | 2,048 | 2,048 | unchanged |
| main + extension rounds | 129 + 20 | **138 + 21** | `+ (9, 1)` for `SC_SSM` |

The U8 total check, since it is easy to get wrong: today
`1·512 (L) + 20·512 (D) + 13·512 (Q) + 12·256 (Kv) + 13·2048 (S) =
512 + 10,240 + 6,656 + 3,072 + 26,624 = 47,104` ✓, matching
`ZK60_PRIVATE_ATTENTION_NATIVE.md:93`. Grown: `1,024 + 17,408 + 6,656 + 3,072 +
26,624 = 54,784`.

**Why the opening-group counts are `[ESTIMATE]`.** A group is a set of claims
with the same PCS column key `(point tail, c0, len)`
(`protocol.rs:62-67`; `zkp-core/src/pcs.rs` `zpart_weights`). The new sites mostly
*join* existing groups, because they carry the same challenge tail as sites
already in their slot: the 13 new full-row `Dom::D` sites in `SC_DZC` share
`ρ_D[1..9]` with the 19 existing ones; `A_LIMBM` in `SC_LZC` shares
`ρ_LZC[1..9]`; and the 11 new `SC_TZC` sub-row sites reuse the eight column
windows `c0 ∈ {0, 32, …, 224}` that `A_D`, `A_DSQ` and the nine `A_LIMB`
sub-slices already occupy **provided `A_DM`, `A_DSQM` and `A_LIMBM` are laid
out row-aligned in the same pattern** — which the row arithmetic of
`Layout::new` does automatically. Only `SC_SSM` draws a fresh challenge vector
and therefore a fresh tail: `+1` group. Hence 31. I have **not** re-derived the
grouping exhaustively by hand; `scripts/zk60_attention_native_inventory.py`
does it from the source and is the authority (§G). The same reasoning gives
`H` unchanged at 8 (7 evaluation groups + the sum group; the 7 new `Dom::D`
helpers share `ρ_D`'s tail).

### C.4 Receipt bytes

The published frame is 2,245,800 bytes = "136 envelope + roots, 11,296
arguments, 223,232 M, 980,992 A, 768,000 H, 262,144 endpoints"
(`ZK60_PRIVATE_ATTENTION_NATIVE.md:94`). Reverse-deriving a model that
reproduces all four large figures exactly makes the grown frame computable
rather than guessed. The model:

```
opening(groups, rows) = (groups + 1)·512·16 + 256·(8 + rows·8 + 32 + 11·32)
mask_open(M_ROWS)     = 512·16 + 256·(8 + M_ROWS·8 + 32 + 15·32)
arguments             = 16·( N_SLOTS + Σ_s (main+ext)·(degree+1) + terminals )
```

Checks against the published numbers: `A` = `31·8192 + 256·2840 = 980,992` ✓;
`H` = `9·8192 + 256·2712 = 768,000` ✓; each endpoint
`2·512·16 + 256·(8 + 7·8 + 32 + 11·32) = 131,072`, two of them `262,144` ✓
(the same constant the feed-forward profile hard-codes,
`zk_ffn_fresh_io.rs:15`); `M` = `8,192 + 256·840 = 223,232` ✓;
arguments: `Σ (main+ext)(degree+1)` over `SLOTS` (`layout.rs:319-338`) is
**576**, terminals are `75 + 35 + 2 = 112`, so
`16·(18 + 576 + 112) = 11,296` ✓; envelope `40` (`wire::HEADER`) + three
32-byte roots = `136` ✓.

Grown:

| Part | accepted | grown | arithmetic |
|---|---:|---:|---|
| envelope + roots | 136 | 136 | unchanged |
| arguments | 11,296 | **12,656** | `Σ(main+ext)(deg+1)` = 576 + 40 (`SC_SSM`: 10·4) + 10 (`SC_LZC` 10·4 → 10·5) = **626**; terminals `102 + 42 + 2 = 146`; `16·(19 + 626 + 146)` |
| `M` opening | 223,232 | **227,328** | `8,192 + 256·(8 + 42·8 + 32 + 480)` |
| `A` opening | 980,992 | **1,161,216** | `32·8,192 + 256·(8 + 390·8 + 32 + 352)`, at 31 groups `[ESTIMATE]`; each further group costs 8,192 |
| `H` opening | 768,000 | **854,016** | `9·8,192 + 256·(8 + 332·8 + 32 + 352)` |
| endpoints | 262,144 | 262,144 | unchanged |
| **total** | **2,245,800** | **2,517,496** | **+12.1 %** |

The model itself is reverse-derived from four published figures and is not read
out of `pcs.rs`; treat the *grown* total as derived-modulo-that-model, and the
group count as `[ESTIMATE]`.

### C.5 Tier 2: the feed-forward half under form (S) — `[ESTIMATE]`

Everything in this subsection is an estimate. It is here so the security owner
can see the whole block's shape, not because the encoding has been designed.

What the feed-forward must prove, from the kernel
(`private-block-kernel/src/lib.rs:627-645`): `g = nm·Wg` requantized at
`SH_G = 7` into `[−128, 127]`; `u = nm·Wu` at `SH_U = 0` into int16;
`a = act[g + 128]` from the public 256-entry activation table;
`h = a·u` requantized at `SH_H = 14` into int16; `z = h·Wd` at `SH_Z = 6` into
int16. At this geometry `F = D = 16`, so the `f` axis is the same 512-entry,
9-variable cube as `Dom::D` and **no new domain is needed** — that is a
property of the tiny geometry and will not hold at 125M or 8B.

| Item | `[ESTIMATE]` | Reasoning |
|---|---:|---|
| new `A` planes | ~20 | `g8`, `rg` (2 limbs), `a16` + 2 int16 limbs, `u16` + 2 limbs, `ru` limbs, `h16` + 2 limbs, `rh` limbs, `rd` limbs, one activation-table multiplicity row (`z16` already counted in §C.2) |
| new `A` data rows | ~40 | ~20 planes × 2 rows |
| new lookups | ~16 on the `f`/`d` cube | int8/int16 classes and the biased remainder limbs, in the same U8 table |
| new `H` helper planes | ~8 + 1 | `⌈16/2⌉` on the cube, plus the activation-table helper |
| new `A` sites | ~30 | three matmul slots (1 site each), one zero-check over the `f` cube (~20 sites), the `TAB` extension (2) |
| new `H` sites | ~9 | one per helper in the zero-check, one in `TAB` |
| new slots | 5 | `SC_GMM`, `SC_UMM`, `SC_DMM` (private matmuls) + `SC_FZC` (their host, plus the activation/product relations and the `f`-cube LogUp helpers); the down matmul is hosted by `SC_DZC`, which already hosts `SC_WO` |
| `A` rows, whole block | ~510 | 390 + 40 data + 2·30 pairs |
| `H` rows, whole block | ~410 | 332 + 9·4 data + 2·9 pairs |
| slots / `M` rows / functionals | 24 / 52 / 37 | 19 + 5 slots |
| receipt | ~3.1 MB | the model of §C.4 at those rows and ~33 `A` groups |

The two structural questions Tier 2 must answer and this memo does not: (i)
whether the activation table joins the `SC_TAB` zero-check as a third
`(multiplicity, helper, public values)` triple — almost certainly yes, it is
the same 256-entry shape as the exp table (`argument.rs:732-748`) — and (ii)
whether `SH_U = 0` leaves the "up" remainder plane empty, in which case `ru`
and its lookups vanish. Neither was checked.

## D. The joint transcript order, label by label

**Profile string.** The existing pattern is
`hashline-zk-mr1/<what>-<geometry>-poc/<version>`:
`hashline-zk-mr1/private-attention-t32-poc/1`
(`hashline/src/private_attention.rs:59`) and
`hashline-zk-mr1/ffn-v3-mr1-fresh-io-poc/2`
(`hashline/src/zk_ffn_fresh_io.rs:12`). Proposed:

```
hashline-zk-mr1/private-block-t32-poc/1
```

A new string, not a new version of either existing one: this is a different
statement (a whole block, two different external endpoints), and reusing
either profile's Fiat–Shamir domain would let a receipt for one be considered
against the other's statement.

**The order.** Written in the style of
`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md:104-112`, but at the granularity of the
actual absorb calls, because that is what the transcript-order gate compares
(`acc.order`, `argument.rs:255`, `:328`, `:335`; returned as
`ProveStats.transcript_order`, `private_attention.rs:264`).

```
  1  Transcript::new("hashline-zk-mr1/private-block-t32-poc/1")        NEW string
  2  absorb  "expected-IO"        <- ExpectedIo::to_bytes()            label reused, NEW payload
                                     magic "HBLKEXP1", context digest,
                                     input_scale, output_scale, input root, output root
  3  absorb  "public-statement"   <- BlockPublic::digest()             label reused, NEW payload
                                     domain "hashline/private-block-public/1";
                                     Wq,Wk,Wv,Wo,gamma_a, gamma_m, Wg,Wu,Wd,
                                     rope_cos, rope_sin, exp, act
  4  absorb  "parameters"         <- b"T32/d16/f16/H2/KV1/dh8/log_cols8/inv_rate8/
                                       Q256/P1/two-private-endpoints/one-proof-one-transcript"
                                                                        label reused, NEW payload
  5  absorb  "calibration"        <- the calibration identity digest    NEW label  (see F)
  6  absorb  "schedule"           <- Layout::schedule_digest()          label reused, NEW payload
                                     domain "hashline/private-block-schedule/1"
  7  absorb  "A"    <- a_root ; absorb_u64 "rows" <- a_rows (390) ; "log-cols" <- 8
  8  absorb  "M"    <- mask_root
  9  challenge beta ; challenge gamma ; challenge alpha
 10  absorb  "H"    <- h_root ; "rows" <- h_rows (332) ; "log-cols" <- 8
 11  the nineteen slots, in this order; for EACH slot s:
        (a) `define(s)` draws the slot's own challenge vectors
            (tau, the mu vector, the nu vector, and the point vectors it publishes
             into `Points` for later slots)
        (b) absorb_u64 "pb-slot" <- s                                   NEW label (was "pa-slot")
        (c) challenge c_s            (refused if zero)
        (d) absorb_fp2 "pb-scalar" <- the ONE published scalar          NEW label (was "pa-scalar")
              private slot : claim_s = s_s + c_s·G_s
              standalone   : Gamma_s = c_s·G_s
              host         : Gamma_host = c_h·G_h − sum_i nu_i·kappa_i·c_i·G_i
        (e) main sumcheck rounds (each round message absorbed, each round challenge drawn)
        (f) one extension round per private factor family (two for the bilinear slots)
        (g) absorb_fp2 "pb-term" <- the masked terminals, in table order NEW label (was "pa-term")

        slot order (module index : name : kind):
           00  SS_a           private  -> hosted by 02
           01  SS_m           private  -> hosted by 02          NEW SLOT
           02  T zero-check   host     [00, 01]                 EXTENDED (both norms)
           03  limb zero-ck   standalone                        EXTENDED (A_LIMB + A_LIMBM), degree 3 -> 4
           04  row sums+sel   private  -> 14
           05  09Q matmul     private  -> 12
           06  09K matmul     private  -> 13
           07  09V matmul     private  -> 13
           08  score          private  -> 14
           09  PV             private  -> 12
           10  Wo             private  -> 11
          [10a gate matmul    private  -> F zero-check ]        TIER 2
          [10b up matmul      private  -> F zero-check ]        TIER 2
          [10c down matmul    private  -> 11           ]        TIER 2
           11  D zero-check   host     [10 (+10c)]              EXTENDED (norm_m c6,c7; residual 2 c8,c9)
           12  Q zero-check   host     [05, 09]
           13  KV zero-check  host     [06, 07]
           14  softmax zc     host     [04, 08]
          [14a F zero-check   host     [10a, 10b]   ]           TIER 2
           15  TAB            standalone                        TIER 2: + the activation table
           16  ZS             standalone
           17  IO-in          standalone   A_X    <-> input endpoint
           18  IO-out         standalone   A_X2   <-> output endpoint   CHANGED (was A_X1)
 12  ONE M opening        zk::mask_open(mc, fs, ntt, tr)         29 functionals, one theta
 13  check_opening(A) ; ONE pcs::open_zk(A)  ; drop A
 14  check_opening(H) ; ONE pcs::open_zk(H)  ; drop H     (H's claim list ends with the
                                                           value-0 LogUp sum claim)
 15  check_endpoint_opening(In)  ; ONE pcs::open_zk(In)  ; drop In
 16  check_endpoint_opening(Out) ; ONE pcs::open_zk(Out) ; drop Out
```

Steps 1, 7–10 and 12–16 are byte-for-byte the built component's
(`protocol.rs:26-33`, `:300`, `:306`, `:310-312`, `:350`, `:365-381`); the
verifier's mirror at `:407-429` is unchanged in shape.

**Reused unchanged.** The labels `"expected-IO"`, `"public-statement"`,
`"parameters"`, `"schedule"`, `"A"`, `"M"`, `"H"`, `"rows"`, `"log-cols"`, the
three challenge draws `β, γ, α` in that order, and the whole opening block
(`"opening"`-free: the openings are positional, each preceded by its
challenge-refusal replay from a cloned transcript, `protocol.rs:168-169`,
`:196-197`). Their *payloads* change where noted; the labels do not.

**New.** `"calibration"` (step 5, §F) and the three per-slot labels renamed
`pb-slot` / `pb-scalar` / `pb-term`. The rename is cosmetic — the profile
string at step 1 already separates the domains — but it makes a captured
transcript self-describing and stops a copy-paste of the attention module's
slot loop from silently producing attention-labelled block material.

**Host-after-hosted is preserved.** `layout.rs:540` asserts `s < host` for
every hosted slot, and a host's claimed sum consumes the hosted slots' masked
scalars (`argument.rs:272`, `:306`). Inserting `SS_m` at index 1 keeps both
`SS_a` and `SS_m` before their host at index 2; the three Tier-2 matmuls sit
before their hosts at 11 and 14a.

**Domain separation between attention-side and feed-forward-side material,
inside one transcript.** Four mechanisms, none of them new:

1. **One profile, one statement digest.** Step 1 and step 3 bind the whole
   block. There is no cross-component replay to prevent because there is no
   second component.
2. **Slot index absorption.** Step 11(b) absorbs the slot index before the
   slot's mask challenge, so the feed-forward slots' challenges occupy
   different Fiat–Shamir positions from the attention slots'; two slots with
   identical polynomials still get independent `c_s`.
3. **LogUp table tags.** The single `(β, γ, α)` draw at step 9 serves every
   table, and tables are separated by a public tag folded into the
   denominator: `g_u8 = γ·TAG_U8`, `g_exp = γ·TAG_EXP`
   (`protocol.rs:313-314`, `crate::tables_attn::{TAG_U8, TAG_EXP}`). The
   feed-forward's activation table needs a **third tag, `TAG_ACT`, distinct
   from both** — this is the mechanism that keeps the feed-forward's activation
   lookups from colliding with the attention's U8 lookups in the one zero-sum
   identity, and it must be allocated explicitly (Decision 10).
4. **The schedule digest.** Step 6 binds every plane, site, slot, host and
   count (`layout.rs:482-510`). A receipt built for a different split of work
   between the two halves does not verify against a verifier that rebuilds the
   layout from its own source.

**If form (E) is built instead** (not recommended), domain separation becomes a
real obligation rather than a property: a component tag must be absorbed before
each root (`"A-attn"`, `"M-attn"`, `"A-ffn"`, `"M-ffn"`), the seam slots need a
third index namespace, and the seam challenge must be drawn only after all four
roots are absorbed (`ZK60_OPUS_SEAM_REVIEW.md:236-243`). None of that exists.

## E. The pending / manifest role list (G8)

**A correction to G8 first.** The gap inventory records the reserve-before-
commit lifecycle as "absent" on both sides, citing
`ZK60_OPUS_SEAM_REVIEW.md:531`. That verdict is right about `zk.rs` and
`attention.rs`, which is what the seam review audited; it is **not** right
about the native private-attention module, which does enforce
consumed-exactly-once on every reserved mask pair, on both sides, today:

> `protocol.rs:84-127`, `audit_claims`: "every reserved pair row is touched by
> exactly ONE claim with a nonzero coefficient; every evaluation claim touches
> exactly one pair (its own, two adjacent rows); only the sum claim may be
> pairless, and it must cover the zero-sum rows; nothing but the proximity
> combination touches the proximity pair" — refusing with
> `"a reserved pair is unused or shared between claims"` at `:124-126` and
> `"a claim does not carry exactly its own reserved pair"` at `:114-116`.

It runs inside `check_opening` (`:150-170`), which the prover calls at `:369`
and `:372` and the verifier at `:422` and `:424`. So "a role never consumed"
and "a role consumed twice" are already hard refusals for the 150 `A` and 70
`H` mask rows. What is missing is that the check is **positional, not named**:
it knows a pair index is unused, not *which role* was skipped, and it has no
list to compare against. That is exactly the property a future seam role needs,
and it is why the manifest is still worth building.

**The role list.** Every role below must be fixed before the commitment that
carries it exists, and consumed exactly once. The two cuts are
`protocol.rs:296` (`commit_zk_owned` moves the `A` buffer; after it no row can
be written) and `protocol.rs:304` (`mask_commit`; after it no slot can be
added) — the same two cuts the seam review measures for the feed-forward at
`zk.rs:2467` and `:2477-2478` (`ZK60_OPUS_SEAM_REVIEW.md:449-470`).

| Role | Reserved (rows / slot) | Declared before | Consumed by, exactly once | Refusal today |
|---|---|---|---|---|
| `ASite{slot, k}`, one per claim site — **102** in the grown Tier-1 layout | `A` rows `a_mask_base + 2·(prefix[slot] + k)` and `+1` (`layout.rs:453-458`) | the `A` commit, `protocol.rs:293-296` | the one terminal claim `build_claim` emits for that site (`argument.rs:341`) | `audit_claims`, positional |
| `AProx` | `A` rows `a_prox`, `a_prox + 1` (`layout.rs:436-437`) | the `A` commit | the single `A` opening's proximity vector | `audit_claims` ("a claim reaches the proximity pair") + `check_opening_challenges`' determinant test (`protocol.rs:143-145`) |
| `HSite{slot, k}` — **42** | `H` rows `h_mask_base + 2·(prefix + k)` (`layout.rs:459-464`) | the `H` commit, `protocol.rs:334-346` | that site's terminal claim | `audit_claims`, positional |
| `HZeroSum` (the `u` pair) | `H` rows `lay.h_u_rows()` (`layout.rs:473-476`), filled to sum to zero at `protocol.rs:337-345` | the `H` commit | the ONE value-0 LogUp sum claim (`protocol.rs:47-57`) | `audit_claims`'s sum branch (`:106-112`): the sum claim must be last, must be pairless, and must cover both `u` rows |
| `HUPrime` (the fresh pair `u′`) | the `SC_ZS` `H` site pair | the `H` commit | the evaluation claim on `H_U` inside `SC_ZS` (`argument.rs:749-753`) | `audit_claims` |
| `HProx` | `h_prox`, `+1` | the `H` commit | `H`'s proximity vector | as `AProx` |
| `CfsSlot{s}` — **19** | `M` rows `2s`, `2s+1` of `mask_specs()` (`layout.rs:395-397`, committed at `protocol.rs:304`) | the `M` commit | exactly one `eval_s` functional, plus one `Γ_s` if standalone, plus appearance inside exactly one host's batched `Γ_host` if private (`argument.rs:348-360`) | the functional count gate, `argument.rs:775-777` |
| `EndpointIn`, `EndpointOut` | rows 2,3 (terminal pair) and 4,5,6 (proximity) of each 7-row `private_seam` commitment (`private_seam.rs:106-111`, `:215-217`) | `private_seam::prepare`, i.e. **before the prover is called at all** | the one IO slot claim on that endpoint (`argument.rs:754-760`) | `check_endpoint_opening` (`protocol.rs:186-198`): exactly one claim, exactly three parts, rows `(0..2)`, `(2..3)`, `(3..4)`, all coefficients nonzero |
| *(form E only)* `SeamNm`, `SeamZ16` on each side | two fresh `A` pairs per seam, per side | both `A` commits | one seam sumcheck each | **nothing** — U-3 |

**What `finalize` must refuse.** Turn the three requirements into named
refusals in the same commit that grows the layout:

1. **A role never consumed.** Today: `uses[r] != 1` for a reserved pair row
   (`protocol.rs:124`), a functional count mismatch
   (`argument.rs:775`), an endpoint with no claim. To add: a `RoleSet` built
   from `Layout` and compared by name at the end of `argument()`, so the error
   says *which* role — `"private block: role ASite{SC_DZC, 27} (A_YM at rho_D)
   was never consumed"` rather than `"a reserved pair is unused"`.
2. **A role consumed twice.** Today: the same `uses[r] != 1` catches a shared
   pair; a second opening of any commitment is structurally impossible because
   every owner is moved in and dropped inside `prove_inner`
   (`protocol.rs:370-380`, and `PreparedPlane` has no `Clone` and no data
   getter, `private_seam.rs:142-161`). To add: the named form, and — the one
   real hole — a refusal when the **same slot** contributes two `eval`
   functionals or a standalone `Γ` *and* appears in a host's batched `Γ`; the
   count gate catches the arity but not the assignment.
3. **A late mask insertion.** Today: impossible by move semantics, not by
   type. `a_data` is moved into `commit_zk_owned` (`protocol.rs:296`) and
   `mask_specs()` is a fixed-length vector consumed by `mask_commit`
   (`:304`). To add: make it impossible by type — `prove_inner` should build
   an immutable `Manifest` from `Layout` *before* either commit, pass it to the
   argument, and have `finalize` take the manifest and the consumed set by
   value. A future seam role is then either in the manifest before the `A`
   root exists or it cannot be claimed at all, which is the property
   `ZK60_FABLE_MASK_REPAIR.md` §4.2 asks for and
   `ZK60_OPUS_SEAM_REVIEW.md:501-518` summarises.

## F. Endpoint scale binding (G11) and the slot-tag namespace (G12)

### F.1 What a declared scale is today, and what it must become (G11, D12 item 5)

**What is bound.** A `SeamSpec` carries `scale` and folds it into its digest
together with the context, the shape, the two slot ids and the PCS constants
(`private_seam.rs:44-52`, `:115-133`). That digest is checked when the owner is
consumed (`into_ffn_endpoint`, `:156-161`), and the two scales travel in
`ExpectedIo::to_bytes` (`private_attention.rs:181-190`), which is absorbed as
`"expected-IO"` before any challenge (`protocol.rs:28`). So the declared scale
**is** transcript-bound and **is** part of the statement.

**What is not.** Nothing compares the tag to anything. The module says so:
"Equality here is field-word equality: range/representation facts are owed by
the enclosing arguments, even though their declared scale is transcript-bound"
(`private_seam.rs:41-42`). `IoSpec::new` validates only `−31..=31` and slot
distinctness (`private_attention.rs:150-158` → `private_seam.rs:63-85`). And
the attention fixtures declare the wrong tags:
`IoSpec::new(ctx, -3, -3)` at `hashline/tests/zk60_private_attention.rs:17`
and `hashline/examples/zk60_private_attention.rs:36`, where the approved
calibration has `e_r = 0` for `x_in` (`causal_oracle.rs:116`) and `e_r1 = 0`
for `xres1` (`:118`).

**What the block must do.** Three things, in the order they bite:

1. **Pin the block's two endpoint exponents to the calibration, in the
   constructor.** The block's endpoints are `x_in` (Int16, `e_r = 0`,
   `causal_oracle.rs:115-116`) and `xres2` (Int16, `e_r2 = 0`, `:145-146`).
   `IoSpec::new` for this profile takes no exponents at all, or takes them and
   refuses anything but `(0, 0)`. This is legitimate because the profile is
   pinned to one calibration exactly as the kernel is — "Deliberately not
   configurable: a different calibration is a different kernel (and a different
   trusted image)" (`private-block-kernel/src/lib.rs:57-59`).
2. **Absorb the calibration identity with the statement** (step 5 of §D). The
   source of truth exists: `causal_oracle.rs:194` fixes
   `calibration_identity`, and `private_block_contract.rs` already digests the
   whole exponent vector including `e_r`, `e_r1`, `e_xm`, `f.e_r2`, `f.e_z16`
   (`:481-485`) and validates the scale equations that connect them
   (`:320-335`, "first residual scales", "second residual scales", "FFN
   internal boundary scales"). The block profile should absorb that digest, so
   a receipt cannot be replayed under a different approved calibration.
3. **Compare represented values, not tags, wherever two quantities meet.**
   Under form (S) there is nothing to compare: `nm` and `z16` are one plane
   each, so no scale can differ between "two copies". This is a second
   structural argument for form (S) and it is why G11 shrinks to items 1 and 2.
   Under form (E) the rule stands as the gap inventory states it (C3): a seam
   must compare `e_xm` against `e_x` and `e_z16` against `e_z16` *through the
   approved contract*, not by tag equality, because tag equality would pass on
   the `2^3` mismatch the current fixtures exhibit.

**The test that would fail today.** A test asserting that the endpoint policy's
declared exponents equal the approved calibration's:

```
assert!(IoSpec::new(ctx, -3, -3).is_err());     // fails today: it is Ok
assert_eq!(spec.input_scale(),  registration.attention.e_r);   // 0
assert_eq!(spec.output_scale(), registration.residual.e_r2);   // 0
```

The first line is the one that matters: today
`hashline/tests/zk60_private_attention.rs:17` constructs exactly that value and
the whole integration suite passes. There is no accessor for the scales on
`IoSpec` either, so the second and third lines need one.

### F.2 The slot-tag namespace (G12)

**What a slot tag is.** `SeamSpec` distinguishes two endpoints of one context
only by the pair of `u64` slot ids folded into its digest
(`private_seam.rs:63`, `:122-123`). Disjointness across profiles is
load-bearing and deliberate: it is why a feed-forward IO endpoint cannot be
presented to the attention prover (`private_attention.rs:155`,
`into_ffn_endpoint` refusal at `private_seam.rs:156-161`). Nothing enumerates
the allocation anywhere.

**Proposed allocation**, to be written down in one place (a `SLOT_TAGS` table
in `private_seam.rs` plus this memo) and owned by the security owner:

| Slots | Profile / role | Status |
|---|---|---|
| 1 / 2, 3 / 4 | `hashline-zk-mr1/ffn-v3-mr1-fresh-io-poc/2` input, output (`zk_ffn_fresh_io.rs:40-42`) | allocated, in use |
| 21 / 22, 23 / 24 | `hashline-zk-mr1/private-attention-t32-poc/1` input `x_in`, output `xres1` (`private_attention.rs:157`) | allocated, in use |
| **41 / 42** | **block input endpoint `x_in`** | proposed |
| **43 / 44** | **block output endpoint `xres2`** | proposed |
| 45 / 46, 47 / 48 | reserved for form-(E) internal seams (`nm`, `z16`) | reserved, unused under form (S) |
| 61 / 62 | reserved for the block-to-block residual seam (A4 / S5) | reserved, out of scope |

**Why the block needs its own pair rather than reusing 21–24.** If the block
reused the attention profile's tags, the only thing separating a block endpoint
from an attention-half endpoint would be the *scale* field of the digest —
`(0, 0)` for the block versus `(−3, −3)` for today's attention fixtures. That
is separation by accident, and it evaporates the moment the attention fixtures
are corrected to `(0, 0)` per §F.1, at which point a block input endpoint and
an attention input endpoint over the same context would have **identical
digests** and either prover would accept the other's owner. A distinct
allocation makes the separation structural.

**The test that would fail today.** There is no list, so the test cannot be
written. Once the table exists:

```
// every allocated slot id appears in exactly one profile's pair
assert!(SLOT_TAGS.iter().flat_map(pair).all_unique());
// an endpoint prepared for one profile is refused by the other
assert!(block::prove(.., attention_endpoints).is_err());   // digest mismatch
```

## G. What the checking tools must show on the grown layout (G10)

The accepted verdict does **not** transfer. It was computed against 75 `A`
sites, 35 `H` sites, 18 slots, an 18-slot `M` and specific group counts
(`ZK60_PRIVATE_ATTENTION_NATIVE_DISPOSITION.md:12`); the grown layout changes
every one of those. This section states the pass criteria the re-run must
produce, so a run can be judged rather than admired. **Nothing here was run.**

### G.1 `scripts/zk60_attention_native_inventory.py` — the driver

It parses `layout.rs`, `argument.rs::define` and `protocol.rs::logup_sum_claim`
statically, builds the inventory, and calls the other two tools by file path
(`:15-45`). Pass criteria:

- **It must parse.** `_run_arm` raises when a site-creating call is not
  consumed (`:568-570`, `"{consumed} of {expected_calls} site calls
  consumed"`), and `DefineParser` understands only the Rust subset the current
  `define` uses: `b.a`, `b.a_at`, `b.a_slice`, `b.a_range`, `b.h`,
  `b.endpoint`; `rho(0..k)`, `fixed(&v)`, `cat(&[..])`, `Coord::Flip`;
  `tr.challenge_fp2*`; one `for lo..hi` loop; `match slot` and `if cond` tuple
  lets (`:615-740`). **Engineering constraint, and it is load-bearing: write
  the new slot arms inside that subset**, or extend the parser in the same
  commit. Otherwise the only executable check of the schedule stops working
  exactly when the schedule grows.
- **The cross-checks must be updated and must pass.** `NOTE_EXPECT`
  (`:1085-1100`) currently pins `A_rows 306, A_data_rows 154,
  A_site_pair_rows 150, H_rows 290, H_data_rows 218, H_site_pair_rows 70,
  A_sites 75, H_sites 35, A_GROUPS 30, H_GROUPS 8, M_ROWS 40,
  N_FUNCTIONALS 28, largest_L 50, U8_lookups 47104, exp_lookups 2048,
  main_rounds_total 129, ext_rounds_total 20`, the eighteen `SLOTS` triples and
  `hosts_by_index {1:[0], 10:[9], 11:[4,8], 12:[5,6], 13:[3,7]}`. The grown
  values from §C.3 replace them: `390 / 184 / 204`, `332 / 246 / 84`,
  `102 / 42`, `31 [ESTIMATE] / 8 [ESTIMATE]`, `42 / 29`, `largest_L 50`,
  `54784 / 2048`, `138 / 21`, nineteen triples, and
  `hosts_by_index {2:[0,1], 11:[10], 12:[5,9], 13:[6,7], 14:[4,8]}`.
- **`A_GROUPS` / `H_GROUPS` are the tool's answer, not the memo's.** It
  re-derives them from `define` and the PCS key rule (`:830-848`) and the
  prover and verifier independently refuse a mismatch
  (`protocol.rs:164-166`). If the tool says 32 rather than 31, the layout
  constant is wrong, not the tool.

### G.2 `scripts/zk60_attention_pair_schedule.py` — the rank verdict

Every one of these must read `disclosed_dim = 0`, `verdict = PASS`:

| Verdict key | Expected | Note |
|---|---:|---|
| `whole_A_per_column` | 0 | all ~31 groups plus the proximity pair, jointly, per column |
| `whole_A_with_values_n4` | 0 | the same with the terminal values |
| `whole_H_per_column` | 0 | |
| `group_A_g0 … g30` | 0 each | every opening group alone |
| `group_H_h0 … h5` | 0 each | the six evaluation groups the tool models. The code declares `H_GROUPS = 8` (seven evaluation groups plus the sum group); the tool sees one fewer because it builds the `(u, u′)` zero-sum pair itself and does not emit the `SC_ZS` `H` site (the inventory script's adaptation R-4). Keep that adaptation, or the count check will disagree with `layout.rs` for the wrong reason |
| `endpoint_In_with_values_n4`, `endpoint_Out_with_values_n4` | 0 | each 7-row endpoint commitment alone |
| `whole_H_with_values_n4`, `…_n8` | **exactly 2**, with `residual_is_exactly_the_public_identity = true` (`rank_F = rank_I = rank(F ∪ I) = 2`) | the surviving functional is the public LogUp identity and nothing else, now over `1 + 17 + 7 + 6 + 7 + 1 = 39` witness helper columns and 2 table helpers instead of 32 + 2 |

`rank_mask` on an all-pair group of `m` members must still satisfy FA2 14.3's
formula `2m + 2n − 2 + 2n` (the tool checks it,
`zk60_attention_pair_schedule.py:1117-1119`).

**Negative controls that must still fire.** Accepted values in brackets; the
ones marked *grows* will report a larger number on the grown layout, and a
larger number is a pass — a *smaller or zero* number is a stop.

| Control | accepted | grown expectation |
|---|---:|---|
| `no_mask_A_per_column` | 37 | grows |
| `no_mask_A_with_values_n4` | 208 | grows |
| `single_base_row_per_claim_A_per_column` | 15 | grows |
| `single_prox_row_singleton_pair_claim_per_column` | 1 | 1 |
| `prox_pair_singleton_pair_claim_per_column` *(positive control)* | 0 | 0 |
| `helper_sums_published_n4` | 70 | grows (~82 `[ESTIMATE]`, two per published helper sum) |
| `zero_sum_row_without_fresh_pair_n4` | 8 | ≥ 8 |
| `flipped_rope_SC_QZC_sharing_pair_with_values_n4` | 2 | 2 |
| `flipped_rope_SC_KVZC_sharing_pair_with_values_n4` | 2 | 2 |
| `flipped_rope_SC_QZC_own_pair…`, `…SC_KVZC_own_pair…` *(positive controls)* | 0 | 0 |

**One new control the grown layout should add** (not in the accepted set):
*`norm_m` sharing `norm_a`'s pairs.* Give `A_YM`'s site in `SC_DZC` the same
reserved pair as `A_Y`'s and require the disclosed dimension to rise. The two
norms are structurally identical relations on the same domain, so this is the
most likely implementation slip, and no existing control covers it.

### G.3 `scripts/zk60_attention_cfs_slots.py` — the CFS verdict

- **Row budget.** `L_s + 256 ≤ 512` on every one of the 19 slots
  (`zk60_attention_cfs_slots.py:161`, `:910`), largest `SC_SZC` at `L = 50`,
  headroom 206. Two slots change `L`: `SC_LZC` 32 → **42** (degree 3 → 4),
  `SC_SSM` new at **32**.
- **Standalone, every slot.** FA6's criterion: `rank = dim S = N·d + 1`,
  image inside `S`, `leaked_dim_fp2 = 0`, `kernel_dim_fp2 = 1`
  (`:313-318`). Grown expectations for the two that change:
  `SC_LZC` `dim S = 10·4 + 1 = 41`; `SC_SSM` `dim S = 10·3 + 1 = 31`.
  The other seventeen keep their accepted values (`SC_DZC` 41, `SC_QZC` 41,
  `SC_KVZC` 37, `SC_SZC` 49, `SC_TZC` 19, `SC_SS` 31, `SC_RS` 37, `SC_TAB` 28,
  `SC_ZS` 19, `SC_IO_IN`/`SC_IO_OUT` 21, the four matmuls 11, `SC_SCORE` 11,
  `SC_PV` 15).
- **Host groups.** `rank = dim S = ΣL − (k + 1)`, `kernel = k + 1`,
  `leaked = 0`, plus the relabelling and round-0 f-part checks
  (`:461-473`). Only `SC_TZC` changes:

| Host | hosted | ΣL accepted | rank / kernel accepted | ΣL grown | rank / kernel grown |
|---|---|---:|---|---:|---|
| `SC_TZC` | `SC_SS` → `SC_SS, SC_SSM` | 52 | 50 / 2 | **84** = 20 + 32 + 32 | **81 / 3** |
| `SC_DZC` | `SC_WO` | 54 | 52 / 2 | 54 | 52 / 2 |
| `SC_QZC` | `SC_QMM, SC_PV` | 70 | 67 / 3 | 70 | 67 / 3 |
| `SC_KVZC` | `SC_KMM, SC_VMM` | 62 | 59 / 3 | 62 | 59 / 3 |
| `SC_SZC` | `SC_RS, SC_SCORE` | 100 | 97 / 3 | 100 | 97 / 3 |

- **`M` layout.** 42 rows, 29 functionals, in the order
  `[Γ_s if standalone] eval_s …` then the five batched `Γ_host`; **no
  standalone `Σ` functional for any hosted slot or for any host**
  (`:932`, and the two controls below).
- **Negative controls that must still fire**, all seven:
  `nc_hosted_c_zero`, `nc_host_nu_zero`, `nc_extension_degree_exceeds_mask`,
  `nc_qkv_unsplit`, `nc_row_budget_exceeded`,
  `nc_sigma_functional_for_private_slot`, `nc_sigma_functional_for_host_slot`.
  `nc_sigma_functional_for_private_slot` should be run against **`SC_SSM` as
  well as `SC_SS`**: publishing `Σ_SSM` standalone would reveal
  `s_SSM = claim_SSM − c·G`, i.e. the second norm's row sums, i.e. the row
  energies of `xres1`.

### G.4 The input these tools need, and its shape

The tools do not read Rust; `zk60_attention_native_inventory.py` writes the
JSON they eat. A **grown schedule JSON** is the same document with the grown
contents. Its shape, as produced today
(`results/zk60_private_attention_native_evidence/rank_cfs/zk60_attention_native_inventory.json`):

```
{ "task", "tool", "profile": {"name", "geometry": {T,D,H,DH,KV,LOG_N,N}, "privacy"},
  "source": {"layout.rs","argument.rs","protocol.rs","pcs.rs"}, "source_sha256": {...},
  "layout": { "cols_log": 8, "n_cols": 256,
              "a_rows": 390, "a_data_rows": 184, "a_mask_base": 184, "a_prox": 388,
              "h_rows": 332, "h_data_rows": 246, "h_mask_base": 246, "h_prox": 330,
              "h_u_rows": [.,.], "n_a_planes", "n_h_planes",
              "a_plane_offsets": {"A_D": 0, ...}, "a_plane_domains": {"A_D": "T", ...},
              "h_plane_offsets": {"H_L": [re, im], ...}, "h_plane_domains": {...},
              "dom_logs": {"T":5,"Ht":6,"L":9,"D":9,"Q":9,"Kv":8,"S":11,"Tab":8},
              "lookup_counts_per_domain": {"L":2,"D":34,"Q":13,"Kv":12,"S":13},
              "helpers_per_domain": {"L":["H_L",1],"D":["H_D0",17], ...},
              "a_sites_per_slot": [...19 ints...], "h_sites_per_slot": [...19...],
              "A_GROUPS_declared", "H_GROUPS_declared", "M_ROWS": 42, "N_FUNCTIONALS": 29 },
  "A1_schedule": {
     "claims": [ { "index", "commitment": "A"|"H"|"In"|"Out", "site", "slot",
                   "slot_const", "site_index_in_slot", "group_key": [...8 tail symbols...],
                   "point": [...], "log_size", "data_rows", "offset", "parts",
                   "role", "section", "sum_claim": false, "source",
                   "mask_rows": [r, r+1], "ext_round", "plane",
                   "sub_row": {"true_log_size","c0","len","true_point",
                               "element_offset","note"}   // sub-row slices only
                 }, ... ,
                 { ..., "sum_claim": true, "point": [], "mask_rows": h_u_rows,
                   "sum_parts": [{"plane","sign","re_offset","im_offset",
                                  "log_size","rows"}, ...] } ],
     "logup_tables": [ {"table":"U8"|"exp"|"act", "table_rows":256, "required_total",
                        "multiplicity_plane", "helper_plane", ...}, ... ],
     "claim_counts": {"A":102, "H_eval":42, "H_sum":1, "total":145},
     "opening_groups": {"A":[{"group","key","c0","len","members","m"},...],
                        "H":[..., {"sum_group": true, ...}]},
     "group_counts": {"A":31, "H":8},
     "endpoint_commitments": [ {"slot","slot_const","commitment":"In"|"Out","log_size":9,
                                "point","data_rows":2,"mask_rows":[2,3],
                                "prox_rows":[4,5,6],"rows":7,"source"} ],
     "zero_sum_construction": {"u_plane","u_rows","fresh_pair_u_prime_rows","zsum_claim"} },
  "A2_cfs_slots": {
     "P1": [ {"slot":"SC_SS","slot_index":0,"name","main_rounds":9,"ext_rounds":1,
              "n_vars":10,"degree":3,"cfs_len":32,"kind":"Private"|"Host"|"Standalone",
              "claimed_sum_form","claimed_sum","A_sites","H_sites","ext_rationale",
              "section","source"}, ... 19 entries ... ],
     "P3": null,
     "hosts": {"SC_TZC":["SC_SS","SC_SSM"], "SC_DZC":["SC_WO"],
               "SC_QZC":["SC_QMM","SC_PV"], "SC_KVZC":["SC_KMM","SC_VMM"],
               "SC_SZC":["SC_RS","SC_SCORE"]},
     "transcript_order": ["SC_SS","SC_SSM","SC_TZC", ... ],
     "m_rows": 42, "n_functionals": 29 } }
```

plus the separate host map the CFS tool takes,
`{"SC_TZC": ["SC_SS", "SC_SSM"], ...}` (written by `--dump-hosts`). The rank
tool's CLI is `--inventory --out --schedule-out --seed [--n-values]
[--no-brute-force]` (`zk60_attention_pair_schedule.py:1564-1571`); the CFS
tool's is `--inventory --out [--hosts] [--alt-hosts] [--seed]`
(`zk60_attention_cfs_slots.py:985-992`). **Not run here.**

## H. Open obligations, and DECISIONS FOR THE SECURITY OWNER

### H.1 What this memo does not establish

- **D8 and D11 remain open for the block's two external endpoints.** `x_in` and
  `xres2` are caller-fixed roots. D8's obligation — simulatability for such a
  root with the distinguisher keeping prior public history — is not discharged
  by anything here, and D11 says one-use consumption of the owner does not
  reduce it to the empty-history case (`ZK60_DECISIONS.md`, D8 and D11;
  `ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md:34-42`). Form (S) does not make
  this better or worse than it is for the attention component today: same two
  caller-fixed roots, same one opening each, same geometry.
- **The joint analysis for the seam groups (U-2) has never been done, and form
  (S) does not do it either — it avoids needing it.** Under form (S) there are
  no seam groups, so U-2 as stated does not arise; what *does* arise, and is
  equally uncovered, is that the grown layout has more opening groups on the
  same commitments and the rank model is per-column and linear. The model's own
  exclusions stand: sampled columns, salted Merkle paths, the CFS channel,
  transcript conditioning and `A ↔ H` correlation are outside it
  (`ZK60_PRIVATE_ATTENTION_NATIVE.md:79`,
  `ZK60_PRIVATE_ATTENTION_NATIVE_DISPOSITION.md:35`).
- **Nothing here is a privacy acceptance.** The construction's acceptance gate
  is unchanged and unmet: on captured real receipts, a zero-witness preimage
  with the same free dimension as the real witness on every channel, plus the
  zero-witness acceptance test (`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md:135`).
  That needs the schema-3 capture writer, which does not exist (G6), and it has
  not been run even for the attention component alone.
- **Nothing here is a speed claim.** The tiny geometry's 0.09 s says nothing
  about 8B (`…_DISPOSITION.md:36`), and the ~12 % receipt growth of §C.4 is a
  byte count, not a time.
- **D9** (`fp()` reduction bias) applies unchanged.
- **The no-wraparound premise grows.** R-2 re-derived every constrained
  integer expression for the attention half
  (`ZK60_PRIVATE_ATTENTION_NATIVE_REVIEW_R2.md`). `norm_m`'s bounds are
  *structurally* the same as `norm_a`'s but its input is `xres1`, an int16
  value that can be twice as large as `x_in` at the extremes, so
  `ss_m = Ceps + Σ xres1²` and `D_m² + a1_m` must be re-bounded, not assumed.
  This is an R-2-shaped obligation on the grown layout and it is not done here.

### H.2 Things found in the code or the documents that bear on D12 or the gap inventory

1. **G8's "absent" verdict is too strong for the native module.**
   `protocol.rs:84-127` already refuses an unconsumed or shared reserved mask
   pair, on both prover and verifier. The inventory's G8 quotes
   `ZK60_OPUS_SEAM_REVIEW.md:531`, which was written about `zk.rs` and
   `attention.rs`. What is genuinely missing is a *named* role list and a
   `finalize` that reports which role was skipped (§E).
2. **The built attention component, used as a block half, would violate D12
   item 3.** Its output endpoint is a caller-fixed root committing `xres1`
   (`argument.rs:757`, `private_attention.rs:220-231`) — a hidden intermediate
   of a block. The same for the feed-forward IO profile, whose output endpoint
   commits `z16` (`zk_ffn_fresh_io.rs:284`, `:346`). Both are fine as
   standalone experiments and neither is a defect *in itself*; the point is
   that "compose the two existing profiles as they are" is not an option under
   D12, whichever seam form is chosen.
3. **D12 item 5's factual claim re-checks exactly.** `IoSpec::new(ctx, -3, -3)`
   at `hashline/tests/zk60_private_attention.rs:17` and
   `hashline/examples/zk60_private_attention.rs:36`; the calibration has
   `e_r = 0` (`causal_oracle.rs:116`) and `e_r1 = 0` (`:118`). Also: the
   separation between the attention and block endpoint namespaces would rest
   on that *error* if the block reused slots 21–24, which is §F.2's reason for
   a fresh allocation.
4. **D12 item 4's factual claim re-checks exactly.** The feed-forward's LogUp
   helper specs are `g8`/`a16`, `u16`, `h16`, `z`/`rd` and nothing else
   (`zk.rs:2685-2690`; GPU mirror `layer.rs:1395-1400`); `lay.x[c]` appears
   only in evaluation claims (`zk.rs:3350`, `:3360`).
5. **Finding C6 dissolves under form (S), and only under form (S).** The
   attention verifier verifies endpoint openings with `NttTables::new(12)`
   (`protocol.rs:263`, used `:428`) while the feed-forward verifier uses
   `new(16)` for the same 7-row endpoint geometry (`zk_ffn_fresh_io.rs:436`,
   used `:469`). One component, one table, no question. Under form (E) the
   question must still be resolved.
6. **The gap inventory's suggested order (its §5) assumes the other form.** It
   says so itself ("the ordering below assumes the construction's own answer …
   seams as A-to-A equalities"). Under this memo's recommendation its step 7
   (a pending/manifest lifecycle *for a seam*) and step 8 (one seam end to end,
   with the "two different endpoint roots are rejected" headline test) have no
   subject, and step 9 reduces to "`SC_IO_OUT` carries `xres2`". Steps 0–6 and
   10–11 are unaffected, and steps 2 (the schema-3 capture writer) and 3 (the
   scale fixtures) remain the right first two build items because neither
   depends on the seam ruling.
7. **A negative test the gap inventory's step 8 was carrying, that must not be
   lost.** Under form (S) there is no seam to break, but the equivalent
   must-reject test exists and should replace it: build the block honestly,
   then present the receipt against an **output endpoint committing `xres1`
   instead of `xres2`**, and require the *verifier* to reject — not a prover
   assertion (`ZK60_PRIVATE_BLOCK.md:242-243` states that rule). This is the
   direct test of D12 item 3 at the block boundary.

### H.3 DECISIONS FOR THE SECURITY OWNER

Each is a choice I made in this draft that the security owner must confirm or
overturn. Recommendation first, then one sentence of reason.

1. **Seam form: build (S), the single shared layout, first; document (E) and
   do not build it yet.** (S) satisfies D12 with no seam relation, no second
   `M`, no second transcript, no pending/manifest for a seam role and no
   composed wire frame, all of which (E) needs *in addition to* everything (S)
   needs.
2. **`norm_m` lives in the attention-side component's `A`, mirroring
   `norm_a`.** Its input `xres1` is already plane `A_X1` there, and the norm
   apparatus (isqrt limbs, the `[-127,127]` lookup, the `ρ/σ` windows) exists
   there and nowhere else.
3. **Residual 2 lives in the same component, as terms `c8`/`c9` of the `D`
   zero-check, exactly like residual 1.** Both addends are then planes of one
   commitment opened once, which is G5 answered the only way D12 permits.
4. **The block's output endpoint carries `xres2`; `z16` and `nm` are never
   external endpoints.** D12 item 2 fixes the block's boundary at two external
   endpoints and item 3 forbids a caller-fixed root for a hidden intermediate.
5. **Profile string `hashline-zk-mr1/private-block-t32-poc/1`, a new
   `"parameters"` payload, and per-slot labels renamed `pb-slot` /
   `pb-scalar` / `pb-term`.** A different statement must not share a
   Fiat–Shamir domain with the attention-half component.
6. **Extend `SC_TZC` to host both SS slots rather than adding a second
   `Dom::T` zero-check.** The second norm's `T`-domain planes live on the same
   32-entry domain, so one host keeps the slot count at 19 and `M` at 42 rows;
   the price is `SC_TZC`'s `k` going 1 → 2 (ΣL 84, rank 81, kernel 3).
7. **Add a second `Dom::L` plane `A_LIMBM` rather than repacking `A_LIMB`, and
   accept `SC_LZC` going from degree 3 to degree 4.** `A_LIMB` has seven free
   32-entry sub-planes and `norm_m` needs nine, so repacking is not available;
   the degree rise costs `L` 32 → 42 and ten proof bytes.
8. **Insert `SC_SSM` at slot index 1, renumbering the rest.** The host-runs-
   after-hosted invariant (`layout.rs:540`) requires both SS slots before
   `SC_TZC`, and keeping them adjacent makes the two norms read as one pattern.
9. **Pin the block's `IoSpec` exponents to the calibration's `(e_r, e_r2) =
   (0, 0)` with a constructor refusal, and absorb the calibration identity
   digest as a new `"calibration"` transcript label.** D12 item 5; today the
   tag proves nothing and the attention fixtures declare `(-3, -3)`.
10. **Allocate endpoint slot tags 41/42 and 43/44 to the block, reserve 45–48
    for form-(E) seams and 61/62 for the block-to-block seam, and enumerate
    the whole namespace in one table; allocate a third LogUp table tag
    `TAG_ACT` for the activation table.** Nothing enumerates either namespace
    today, and under form (S) the activation table shares one `(β, γ, α)` draw
    with the U8 and exp tables.
11. **Build the named manifest (`RoleSet` from `Layout`, `finalize` naming a
    missing or doubled role) even though `audit_claims` already refuses both
    positionally.** The positional check cannot say which role was skipped,
    which is exactly what a later seam role or a Tier-2 feed-forward role
    needs.
12. **Re-run all three tools and update `NOTE_EXPECT` before the component is
    called a block; the accepted R-1 / R-2 verdicts do not transfer.** Every
    count they asserted changes, and the transfer is the thing G10 says must
    not be assumed.
13. **Accept, for the tiny block only, that form (S) re-derives the
    feed-forward on the host and does not inherit the GPU prover; record the
    8B revisit with the two measurements of §B.3.** Simplest-first: the tiny
    block is a correctness and privacy milestone, not a throughput one, and
    the measurement that would overturn this is named rather than assumed.
14. **Write the new `define` arms inside the Rust subset
    `zk60_attention_native_inventory.py` parses, or extend the parser in the
    same commit.** Otherwise the only executable check of the schedule breaks
    in the commit that grows the schedule.

## I. What I did not check

This was a paper pass. Nothing below was done, and no claim above should be
read as covering it.

**Not run.** No `cargo` of any kind — no build, no `cargo check`, no test, no
example, no proof, no benchmark. No Python: the three checking tools of §G were
**read, not executed**, and the accepted numbers quoted from
`results/zk60_private_attention_native_evidence/rank_cfs/` are read out of the
committed records, not regenerated. No git write of any kind. Every statement
about code is from reading the source at the state of
`/home/victor/wt-zk60-attention-compile` on 2026-09-19.

**Not read in full.** `hashline/src/zk.rs` (227 KB), `hashline/src/layer.rs`
(113 KB) and `hashline/src/attention.rs` (152 KB) were searched, not read. In
particular I did not audit `prove_layer_zk_v3` / `verify_layer_zk_v3`, the
feed-forward's claim assembly, `pcs::open_zk` / `verify_zk`, or
`zk::mask_commit` / `mask_open`. I also did not read
`hashline/src/private_attention/{witness.rs, wire.rs, tests.rs}` beyond their
openings, or `zkp-core/src/pcs.rs` at all — the PCS column-key rule I use in
§C.3 is taken from the native module's own re-implementation of it
(`protocol.rs:62-67`) and from the inventory tool's (`:830-834`).

**Not derived.** (a) The grown `A_GROUPS` / `H_GROUPS`: I argued that only
`SC_SSM` contributes a fresh column tail, and did not enumerate the grouping.
(b) The whole of §C.5 (Tier 2, the feed-forward half): plane counts, site
counts, slot shapes, rows and bytes are estimates, and the feed-forward's
encoding has not been designed. (c) Whether `SH_U = 0` leaves the "up"
remainder plane and its lookups empty. (d) The byte model of §C.4 is
reverse-derived from four published figures; it reproduces all four exactly but
is not read out of the PCS source. (e) The exact grown value of the
`helper_sums_published` control. (f) Whether `SC_DZC`'s μ vector growing from
`6 + 10` to `10 + 17` has any effect I have not foreseen on the extension-round
premise — I checked the *degree* argument, not the full monomial expansion that
R-2 did for the accepted layout.

**Not verified.** (a) Whether `pcs::verify_zk`'s behaviour depends on
`NttTables::max_log` — finding C6 is argued away for form (S) by there being
one table, not by resolving the underlying question. (b) The no-wraparound
bounds for `norm_m` over `xres1` (see H.1). (c) That the `Dom::F` axis really
coincides with `Dom::D` at every geometry — it does at `F = D = 16`, and
explicitly will not at 125M (768 → 2048) or 8B. (d) The VRAM claim in §B.1
rests on the prover's own comments and the OOM string they record
(`zk.rs:2388-2394`, `:2576-2580`), not on a measurement I took.

**Not analysed.** No privacy analysis of any kind. No simulator. I did not
evaluate whether form (S) or form (E) is zero knowledge, did not extend the
rank or CFS models, and did not assess the composition-scope acceptance gate
beyond stating that it is unmet. Section §G states what a *re-run* must show;
it does not predict that it will show it.

**Out of scope by instruction.** No fix was implemented, no code was written,
no ruling was reopened (D1, D3, D4, D5 and D12 stand as recorded), nothing
under `/home/victor/IntelligenceRegulation` was touched, and no file other than
this one was created or edited. The zkVM route (D7) is a separate profile and
was not compared against this construction.
