# What the repaired private feed-forward costs at model width — how to get that number safely, and what blocks it

**Status: DRAFT — delegated scoping, no run performed.** Nothing in this
document was executed: no build, no proof, no benchmark, no GPU. Every
number is labelled `[MEASURED]` (with source path and shape),
`[COUNTED]` (read off the source, exact), or `[MODEL]` (an estimate,
with its arithmetic shown). No privacy property is claimed anywhere on
this page.

Scope: the question named as the most valuable one in the project by
`ZK60_FIVE_SECOND_PLAN.md` §5 ("The single largest uncertainty") and by
`ZK60_MVP_COMPLETION_PLAN.md` §2.6 — **what does the repaired private
feed-forward cost at one Mistral-width layer?** This page works out how
to get that number and what stands in the way. It does not get it.

## 0. The answer in one page

**Can the repaired private feed-forward be driven at 125M or at one
Mistral-width layer today? No — not through any binary, subcommand,
example or test.** Every entry point refuses anything but T32/d16/f16,
and the only two drivers that exist also refuse the GPU outright.

**But the thing called "the repaired private feed-forward" is two
separable layers, and they are very unequally blocked:**

* **The repaired mask schedule (`mr1`)** — paired mask rows, refusal
  instead of resampling, a rank check before every opening — is
  **already shape-general in the code**. `ZkLayoutV3::with_masks` takes
  the shape as a parameter; the CFS specification derives its variable
  counts from the shape; every refusal is written against `rows`,
  `log_n`, `mask_rows`, `prox`. It has **no caller** at a general
  shape, and that is the only thing wrong with it. One public entry
  pair plus a CLI flag — **~25 to 45 lines, no new cryptography** —
  makes it runnable at 125M and at one Mistral layer, on CPU and on
  GPU, today's export directories and all.
* **The hiding-endpoint profile (`io`)** — the part that actually
  hides the input and the output — has **eleven** shape pins, one of
  which is a hard refusal **512× away** from Mistral width:
  `private_seam.rs:31` caps an endpoint plane at 4,096 words, and a
  Mistral plane is 2,097,152. A second, `MAX_WIRE_BYTES = 32 MiB`, is
  already smaller than one Mistral layer's proof **before** endpoints
  are added (36.9 MiB public, 38.3 MiB private, both measured).

**And the structural answer, counted from the layout constructors, is
reassuring.** At one Mistral layer, T = 512, the repaired profile adds
**70 rows to a 3,599-row activation commitment (+1.94%)**, one row to
the helper commitment, **nothing at all to the weights** (P1 keeps them
public and plain), two small endpoint commitments (~128 MB encoded
each, against ~1.8 GB for A) and two extra sumchecks. It is
structurally **the legacy private profile plus a few per cent** — not
3× and not 30×. What is *not* settled is time on a machine that pages,
which is why the measurement still has to be taken.

**The memory verdicts on this box** (15 GB, 13 GB available; RTX 4070
Laptop, 8,188 MiB, idle), all [MODEL] and calibrated against three
recorded runs to within 12–25%:

| | safe here | needs the box to itself | must wait for bigger hardware |
|---|---|---|---|
| **125M, 12×512** | CPU (~1.1 GB) and GPU (~3.1 GB VRAM) | — | — |
| **1 Mistral layer, GPU** | T ≤ 512: 2.1–5.6 GB VRAM, with the standing GPU discipline | — | — |
| **1 Mistral layer, CPU** | T = 16 (7.7 GB), T = 64 (8.5 GB) with `MemoryMax=10G` | T = 256 (10.7 GB) | **T = 512 (13.8 GB vs 13 available)** |
| **32-layer Mistral, private** | — | — | **both arms** — the legacy version of this run peaked at 8,585 MB on an 8,188 MiB card and froze the box three times in one day. A 16 GB+ card |

**The recommendation.** Do tier 1 (§5.1), then run the ladder R1 → R4
(§3.5): 125M GPU three arms, 125M CPU three arms, one Mistral layer CPU
at 16 tokens, one Mistral layer GPU at 512 tokens. That yields the
repaired-vs-legacy and repaired-vs-public ratios at real geometry
within one session's compute, on hardware that already exists, without
ever approaching the freeze. The endpoint half (tier 2/3) can follow;
it is the smaller cost and the larger build.

**And do not run a 32-layer private pass to get the 32-layer number.**
32 × the measured one-layer private GPU clock is 132.5 s against the
ledger's independently-derived ~140 s prediction for a non-paging card
— 5% apart. Measure one layer and multiply (§4.3).

## 1. What the repaired profile is, in code

### 1.1 Two separable things wear the same name

"The repaired private feed-forward" is not one object. It is **two
layers that can be measured independently**, and separating them is the
single most useful thing in this document, because one of them is
already shape-general and the other is not.

**Layer 1 — the repaired mask schedule, `mr1`.** A boolean that runs
through the whole v3 prover and verifier
(`hashline/src/zk.rs:2283`, `:2337`, `:3467`, `:3471`). When it is on:

* every A / W mask row becomes a **pair** of rows, so that one Fp2-valued
  mask sits where a single base-field row used to
  (`zk.rs:2003` `let width = if mr1 { 2 } else { 1 };`);
* single-row table-multiplicity slots also get a pair
  (`zk.rs:2025` `let a_mask = next(if mr1 && rows == 1 { 2 } else { rows });`);
* every mask challenge is redrawn through a refusal instead of a
  resample (`zk.rs:2736`, `:2825`, `:2897`, `:2994`, `:3079`, `:3172`,
  implemented at `hashline/src/zk_ffn_fresh_poc.rs:221-233` — a zero
  challenge **discards the attempt**);
* before each of the three openings the prover and the verifier replay
  the PCS challenge prefix and refuse unless the mask coefficients span
  Fp2 (`zk.rs:2317`, `:2323`, `:2328` and `:3752`, `:3768`, `:3775`,
  implemented at `zk_ffn_fresh_poc.rs:253-341`);
* degenerate table-mask coordinates are refused
  (`zk.rs:3153`, `:3671`, `zk_ffn_fresh_poc.rs:235-248`).

**Nothing in layer 1 is tied to a shape.** `ZkLayoutV3::with_masks`
takes `(t_rows, d, f, params, shifts, pred, mr1)` and computes every
count from `nb_d` / `nb_f` (`zk.rs:2002-2054`); the CFS mask
specification derives its variable counts from `lay.log_db`,
`lay.log_fb`, `lay.log_t`, `zl.log_n`, `zl.log_s`
(`zk.rs:2149-2174`). [COUNTED]

**Layer 2 — the hiding-endpoint profile, `io`.** `zk_ffn_fresh_io.rs`
wraps layer 1 and adds the thing P1 actually needs: the input and the
output are **committed by an independent owner before proving**, and the
FFN proves equality to those commitments without opening them.
Everything in layer 2 is pinned to T32/d16/f16 (§2.2).

### 1.2 Entry points and owner types

All of these live in `hashline/src/zk_ffn_fresh_io.rs` unless stated.

| Entry point | Line | What it is |
|---|---|---|
| `IoSpec::new(context, input_scale, output_scale)` | `:29-37` | Trusted request metadata; validates by building the two `SeamSpec`s |
| `IoSpec::seams()` | `:38-43` | **Hard-codes the plane shape**: `SeamSpec::new(ctx, 32, 16, scale, …)` twice |
| `prepare_endpoints(spec, input, output) -> (ExpectedIo, Endpoints)` | `:109-120` | The endpoint owner commits both planes; returns the **public policy** and the **private owner** |
| `ExpectedIo::from_roots / to_bytes / from_bytes` | `:55-100` | The public policy the verifier is given out of band; `Commitment { rows: 7, log_cols: 8 }` is baked in at `:60-68` |
| `Endpoints` | `:104-107` | The private owner. **No `Clone`, no `Debug`, no serialization, no value getter** |
| `prepare(w, privacy, expected) -> PendingProof` | `:148-181` | Runs the whole v3 prover up to, but not including, the openings |
| `PendingProof` | `:132-136` | The pending owner. The doc-comment at `:125-131` is a `compile_fail` test that a second `finish` will not type-check |
| `PendingProof::finish(self, endpoints) -> Receipt` | `:276-368` | **Consumes both owners** (by value) on success *and* on failure; runs the two endpoint arguments, then the FFN openings, then the two endpoint openings |
| `Receipt` / `to_bytes` / `from_bytes` | `:191-196`, `:513-591` | Opaque receipt; `to_bytes` re-decodes its own output at `:549` before returning |
| `verify(st, weights, expected, receipt)` | `:412-481` | Statement + weight policy + **caller-supplied** expected policy + receipt |
| `verify_bytes(...)` | `:593-607` | The same from bytes only |

The ownership discipline is the point of the design and it is real:
`finish` takes `self` and `endpoints` by value, so a `PendingProof`
cannot be finished twice and an `Endpoints` cannot be reused; the
failure paths drop both. `check_endpoints` (`:258-271`) refuses if the
recomputed roots do not match the policy, and the code deliberately
refuses to pre-check value equality — "unequal committed values must
fail the verifier's polynomial identity" (`:274-275`).

The sibling wrapper `hashline/src/zk_ffn_fresh_poc.rs` exposes the same
repaired masks **without** endpoints: `prove(w, privacy, context)`
(`:92-115`) and `verify(st, weights, proof, context)` (`:155-201`).
That is the cheapest existing handle on layer 1.

### 1.3 What it reuses from zk.rs and layer.rs

`io::prepare` calls `prepare_layer_zk_v3_inner(w, 32, &parameters(),
&NttTables::new(16), &cfg, &mut tr, /*mr1*/ true, /*io*/ true, rng)`
(`zk_ffn_fresh_io.rs:165-175`). That is **the same prover body the
public and the legacy `--zk` passes use** — `zk.rs:2337`, the function
the public `prove_layer_zk_v3` (`zk.rs:2279-2281`) and the legacy
`--zk` CLI path reach with `mr1 = false`.

Concretely the repaired profile inherits, unchanged:

* the whole witness pack, the W / A / H commitments, the LogUp helper
  construction, the two matmul sumchecks, the F / D / table zero-checks,
  the zero-sum and the CFS mask commitment (`zk.rs:2337-3466`);
* `LayoutV3` from `zkp-core/src/ffn_v3/statement.rs:148-179`, re-exported
  through `hashline/src/layer.rs:52`, which is where `a_len`, `h_len`,
  `w_len`, `nb_d`, `nb_f` come from;
* `pcs::commit_zk` / `open_zk` / `verify_zk`, i.e.
  `zkp-core/src/pcs.rs` through the adapter `hashline/src/pcs.rs`;
* `PendingV3::finish` (`zk.rs:2305-2334`) for the three openings.

It adds, on top: `ZkLayoutV3::with_io` (`zk.rs:2057-2063`), the two
extra CFS slots (`zk.rs:2172`), the two endpoint arguments
(`zk_ffn_fresh_io.rs:276-355`), and the two endpoint openings
(`:357-362`).

`layer.rs` itself is *not* on this path — it holds the public (non-ZK)
prover. This matters for §4: **lane AL's 1.687× host fix was applied to
`layer.rs` only, and `zk.rs` was deliberately not touched**
(`ZK60_FIVE_SECOND_PLAN.md:288-293`), so every private arm in the
repository is missing the largest speedup the project has found.

### 1.4 What runs on the GPU, and what is host-only

This is the most important structural fact about the repaired FFN, and
it is the opposite of the private *block*:

> **The repaired FFN keeps the GPU prover.** Because it goes through
> `prepare_layer_zk_v3_inner`, every device dispatch in `zk.rs` is on
> the same `mr1`/`io` code path. By contrast the private **block**
> (`hashline/src/private_block.rs`, form (S)) *gives it up*: "for the
> tiny block the feed-forward is re-derived on the host and does not
> inherit the GPU prover" (`ZK60_MVP_COMPLETION_PLAN.md:284-296`,
> quoting `ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md:45-47`). The
> two are different routes to P1 and they have different cost models.

The device is reached only when `gpu::enabled()` is true, which is
`cfg!(feature = "gpu-cuda")` **and** `HL_GPU=1` **and** a device that
initialised (`hashline/src/gpu/cuda.rs:484-487`, `:599-606`). Without
the feature, `gpu::enabled()` is a compile-time `false`
(`hashline/src/gpu/mod.rs:265-270`) and the binary cannot touch the
device at all.

On the repaired path, device-eligible:

| Work | Dispatch site | Gate |
|---|---|---|
| Hiding commitment of A (coset encode + Merkle leaves) | `gpu/mod.rs:230-243` `try_commit_zk` | `enabled()`; declines to CPU with a printed message |
| Hiding commitment of H from a device-resident buffer | `hashline/src/pcs.rs:70-84` `commit_zk_device` | as above |
| Public W commitment / weight-cache encode | `hashline/src/wcache.rs:274-275` | `enabled()` |
| LogUp helper columns | `zk.rs:2593-2606`, `:2680-2695` | `enabled()` **and** `dev_shape` **and** a hard reservation |
| Zero-checks F and D (blocked form) | `zk.rs:2920-2950`, `:3010-3033` | `enabled()` **and** `dev_shape` |
| Table zero-check | `zk.rs:3101-3117` | `enabled()` |
| Row folds and column reads inside every opening | `gpu/mod.rs:216-226` (`EncodedStore`) | device store present |
| Multi-point evaluation | `zk.rs:943-951` | `enabled()` + device store |

**The "device shape" gate** is `zk.rs:2570`:

```
let dev_shape = nb_f >= 1 && nb_d >= 1 && 17 + 14 * nb_f <= 384 && 7 + 6 * nb_d <= 384;
```

It is a bound on the kernels' shared parameter array (`gpu::SCG_MAX_PRM
= 384`, noted at `zk.rs:2569`): at most 26 f-blocks and 62 d-blocks.
Mistral is `nb_d = 1`, `nb_f = 7` → `17 + 98 = 115` and `7 + 6 = 13`,
both far inside. 125M is `nb_d = 3`, `nb_f = 1` → `31` and `25`. Neither
shape is excluded. [COUNTED]

Host-only on this path, at every shape: the witness pack, the
multiplicity histograms, the mask-row generation, the CFS mask
commitment and `mask_open`, `check_masks`' transcript replay, the claim
construction, the proof serialization — **and both endpoint arguments in
`finish`**, which build their three sumcheck tables in host memory
(`zk_ffn_fresh_io.rs:299-311`) and call `masked_prove` on them. The
endpoint *commitments* themselves go through `pcs::commit_zk`
(`private_seam.rs:186-220`), so they would be offered to the device like
any other commitment.

### 1.5 The endpoint planes, and how they scale

An "endpoint plane" is one of the two hiding commitments that the
*caller* makes before proving: the FFN's input X and its output Z,
committed by their owner so that the FFN can be tied to them without
either being opened.

The construction is `hashline/src/private_seam.rs`. Its fixed
parameters are `LOG_COLS = 8`, `INV_RATE = 8`, `CHECKS = 256`,
`MASK_ROWS = 5` (`:28-36`). Size, exactly:

* `data_rows = ceil(rows * cols / 256)` (`:106-108`)
* `commitment_rows = data_rows + 5` (`:109-111`)
* encoded width `256 * 8 = 2048` columns

So a plane of `T * d` words costs `ceil(T*d/256) + 5` committed rows of
2048 encoded columns. At the tiny shape `32 * 16 = 512` words → 2 data
rows + 5 = **7 rows**, which is exactly the `rows: 7, log_cols: 8`
hard-coded into the policy object at `zk_ffn_fresh_io.rs:60-68` and
re-checked in the wire format at `:543` (`c.len() != 7`). [COUNTED]

| shape | plane words | commit rows | encoded bytes | within the seam's cap? |
|---|---:|---:|---:|---|
| T32 / d16 (today) | 512 | 7 | 0.11 MB | **yes** |
| T512 / d768 (125M) | 393,216 | 1,541 | 24.1 MB | **no** |
| T16 / d4096 | 65,536 | 261 | 4.1 MB | **no** |
| T64 / d4096 | 262,144 | 1,029 | 16.1 MB | **no** |
| T256 / d4096 | 1,048,576 | 4,101 | 64.1 MB | **no** |
| T512 / d4096 (Mistral) | 2,097,152 | 8,197 | 128.1 MB | **no** |

[COUNTED, arithmetic in §3.2]. "Within the cap" refers to
`private_seam.rs:31` `const MAX_LOG_LEN: u32 = 12;` and the refusal at
`:66-71`: *"seam: supported plane has 2..4096 values and power-of-two
axes"*. **A Mistral endpoint plane is 512× over that cap.** See §2.2.

The good news in that table is the sizes: even at Mistral width the two
endpoint commitments are ~128 MB each of encoded data, against ~1.8 GB
for the A commitment. Endpoints are not where the cost is.

### 1.6 What it adds over the public path and over the legacy `--zk` path

All counts below are from the layout constructors, computed exactly.
The model that produces them reproduces two independent recorded facts:
the tiny legacy row counts **A 681 / H 1325** (`ZK60_PENDING_FFN.md:204-208`)
**exactly**, and the Mistral H row count **3029** against the
**3033** recorded in the source comment at `zk.rs:2378-2383` (0.13%
apart; the comment's extra rows are one layer's larger remainder
window). [COUNTED, validated]

**Three privacy rungs, at one Mistral FFN layer, T = 512, `log_cols 14`,
`inv_rate 4` (the CLI defaults, `hashline/src/bin/hashline.rs:59`):**

| | public (no `--zk`) | legacy `--zk` P1 | repaired `mr1` + `io` P1 |
|---|---:|---:|---:|
| A rows: data | 3,520 | 3,520 | 3,520 |
| A rows: masks | 0 | 61 | **122** |
| A rows: table slots + their masks | 0 (see below) | 9 + 9 | 9 + **14** |
| A rows: endpoint mask pairs | 0 | 0 | **+4** |
| **A rows total** | **3,520** | **3,599** | **3,669** (+70, +1.94%) |
| **H rows total** | 2,944 | 3,029 | 3,030 (+1) |
| **W rows (P1: public, plain)** | 10,752 | 10,752 | 10,752 (unchanged) |
| hiding commitments | 0 | 2 (A, H) | 2 + **2 endpoints** = 4 |
| CFS mask slots | 0 | 6 | **8** (`zk.rs:2172`) |
| PCS openings | 3 plain | 1 plain + 2 hiding + `mask_open` | + **2 hiding endpoint openings** |
| extra sumchecks | — | — | **2**, each `log2(T·d)+1 = 22` rounds |
| extra mask functionals | — | — | **4** (2 per side, `zk_ffn_fresh_io.rs:236-253`) |

[COUNTED]

The public column is a genuinely different object, not the private one
with the masks removed: the public v3 prover commits `a_data` of exactly
`lay.a_len` and `h_data` of exactly `lay.h_len`
(`hashline/src/layer.rs:1330`, `:548`, `:1402`) and sends the six
multiplicity histograms **in the clear** as `proof.mults`
(`layer.rs:1366-1367`). The ZK prover commits those histograms inside A
(the 9 table rows) and masks them. So part of what the private arms pay
is hiding the multiplicities, and that part is already inside the legacy
`--zk` column — the repair does not add it.

**Read that table carefully, because it is the headline of this
document.** The repaired profile adds **70 rows out of 3,599** to the
largest hiding commitment, one row to the second, nothing at all to the
weights, two small extra commitments and two extra sumchecks. It is
*structurally* a few-per-cent change on top of the legacy private
profile — **not** a different order of magnitude.

Two caveats that keep this honest:

1. The mask-row count **does not depend on T** (it depends only on
   `nb_d`, `nb_f`), while the data rows scale with T. So the *relative*
   overhead of the repair is 1.94% at T = 512, 3.81% at T = 256, 13.5%
   at T = 64 and **37.0% at T = 16**. A cheap 16-token probe would
   therefore *overstate* the repair's cost by roughly 19×. Anyone who
   measures at T = 16 must convert with this table, not extrapolate the
   percentage.
2. Rows are not seconds. The added rows land in the phases that the
   recorded runs show are *not* linear in rows on this box — the hiding
   commitment and the openings — and at T = 512 the legacy private pass
   is already over the card's memory (§3). The structural count bounds
   the *work*; it does not bound the *time* on a machine that pages.

## 2. Is it shape-general? What can be driven today

### 2.1 The verdict

**No. Neither the 125M shape nor one Mistral-width layer can be driven
through the repaired profile today, through any binary, subcommand,
example or test.** There is no partial path: every entry point into the
repaired code refuses anything but T32/d16/f16, and the two examples
that exist additionally refuse the GPU.

But the two layers of §1.1 are very unequally blocked, and that is the
useful part of the answer:

| | drivable at 125M? | drivable at one Mistral layer? | what stands in the way |
|---|---|---|---|
| **Layer 1 — the `mr1` repaired masks** | **no caller**, but the code is shape-general | same | 1 blocker: no public entry point (§2.2 B1). The layout, the CFS specs and every refusal already take the shape as a parameter |
| **Layer 2 — the `io` hiding endpoints** | no | no | 11 blockers, one of them a hard refusal 512× away (§2.2 A) |

So the cheapest real number in the project is **not** "the repaired
private feed-forward at Mistral width". It is **the `mr1` half of it**,
which needs one small caller and then runs at any shape the public pass
runs at. §5 makes that concrete.

### 2.2 Every blocker, with file:line and the size of the change

#### A. Shape pins in the endpoint (`io`) profile

| # | Blocker | file:line | Size of the change |
|---|---|---|---|
| A1 | `preflight` refuses anything but (32, 16, 16) | `hashline/src/zk_ffn_fresh_poc.rs:72-78` | 1 line to relax, but it is the guard everything below assumes |
| A2 | `check_witness` requires every activation plane to be exactly 512 words and every weight block exactly 256 | `zk_ffn_fresh_poc.rs:117-145` | ~15 lines: the lengths become `t_rows*d`, `t_rows*f`, `d*f` |
| A3 | `parameters()` fixes `log_cols 8, inv_rate 8, Q 256` against the CLI's `14 / 4 / 256` | `zk_ffn_fresh_poc.rs:51-57`; CLI default `hashline/src/bin/hashline.rs:59` | ~5 lines, but see the warning below — this one changes the answer, not just the plumbing |
| A4 | The transcript absorbs the literal parameter string `T32/d16/f16/log_cols8/inv_rate8/Q256/two-private-seams` | `zk_ffn_fresh_io.rs:138-146`; sibling at `zk_ffn_fresh_poc.rs:80-88` | ~3 lines, **and every existing proof byte of this profile moves** → new profile tag + regenerated fixtures |
| A5 | **`SeamSpec` refuses any plane above 4096 words**: `const MAX_LOG_LEN: u32 = 12` and *"seam: supported plane has 2..4096 values"* | `hashline/src/private_seam.rs:31`, refusal `:66-71` | The hard one. A Mistral plane is 2,097,152 words = **512× the cap**; 125M is 96× over. `MAX_LOG_LEN` also sizes the seam's own CFS slot (`:107 mask_spec`) and its wire format (`:608`), so raising it is a construction change, not a constant bump |
| A6 | The endpoint plane shape is literally `32, 16` | `zk_ffn_fresh_io.rs:40-41` | ~2 lines; must come from the statement |
| A7 | The public policy hard-codes the endpoint commitment shape `rows: 7, log_cols: 8` | `zk_ffn_fresh_io.rs:60-68` | ~5 lines; `rows` becomes `ceil(T*d/256)+5` |
| A8 | `ENDPOINT_OPEN_BYTES` is a closed-form constant built from 512 / 7 / 11 / 256 | `zk_ffn_fresh_io.rs:15`, used by `encoded_len` `:505-511` | ~5 lines, but see the wire bound A11 |
| A9 | The receipt shape check pins `group_vecs[0].len()==512`, `prox_vec.len()==512`, `columns.len()==256`, `j < 2048`, `c.len()==7`, `p.len()==11` | `zk_ffn_fresh_io.rs:536-548` | ~10 lines |
| A10 | The two endpoint arguments are written against 512-word slices: `a.data[off..off+512]` and `endpoints[i].data[..512]`; `claim(..)` with `log_size: 9` and `row*256`; `mask_value(.., 256)`; `challenge_fp2_vec(9)`; mask row index `2`; `sumcheck::verify(.., 10, ..)`; `rounds.len() != 10`; `check_masks(claims, 7, 8, &[2,3], 4, ..)` | `zk_ffn_fresh_io.rs:201-203`, `:204-235`, `:293`, `:301`, `:308`, `:324`, `:360`, `:389`, `:459`, `:526` | ~60 lines of careful derivation from `(T, d, log_cols)`. The CFS side is **already** general (`zk.rs:2172` derives the slot from `log_t + log_db + 1`), so this is bookkeeping, not new cryptography |
| A11 | **`MAX_WIRE_BYTES = 32 MiB`**, enforced by `encoded_len` | `hashline/src/zk_ffn_fresh_wire.rs:11`; refusal `zk_ffn_fresh_io.rs:507-510` and `zk_ffn_fresh_wire.rs:69` | One constant — but **one Mistral FFN layer's proof already exceeds it before any endpoint bytes are added**: 38,688,700 B = 36.9 MiB public [MEASURED, `results/hashline_hostwall_r4.log:291`] and 40,186,228 B = 38.3 MiB legacy private [MEASURED, `ZK60_CLAUDE_GPU.md:262-265`]. It is a denial-of-service bound on a decoder, so raising it is a ruling, not an edit |
| A12 | `with_io` takes `t_rows` from `w.t_rows` while the caller passes `t_rows = 32` separately to the same function | `zk.rs:2354` against `zk_ffn_fresh_io.rs:166` | Latent: at the tiny shape A2 forces the two to agree. At any other shape they can silently disagree. Fix while generalizing (~3 lines) |

**The warning about A3.** Do not simply relax the shape pin and leave
`log_cols = 8`. At Mistral width with 256-column rows the A commitment
would be `112,640 * 512 / 256 = 225,280` data rows instead of 3,520
[COUNTED] — 64× the rows, 64× the Merkle leaves per opened column, and
a proof far past any bound in the tree. Any measurement taken at
`log_cols 8` would be an artefact of the tiny profile's parameters, not
the cost of the repair. **The probe must run at the same
`log_cols 14 / inv_rate 4 / Q 256` as the public arm, or the comparison
is meaningless.**

#### B. Missing drivers

| # | Blocker | file:line | Size of the change |
|---|---|---|---|
| B1 | **No caller reaches `mr1 = true` at a general shape.** `prove_layer_zk_v3` hard-codes `false`; `prove_layer_zk_v3_inner` / `verify_layer_zk_v3_inner` are private `fn`, not `pub` | `zk.rs:2279-2281`, `:2283`, `:3467` | ~20-40 lines: one `pub` entry pair plus a CLI flag. **This is the whole of tier 1 in §5** |
| B2 | The CLI has no repaired mode. `--zk` sets the legacy P1, `--p3` the legacy P3 | `hashline/src/bin/hashline.rs:81`, `:84` | ~5 lines once B1 exists |
| B3 | **Both repaired examples refuse the GPU outright** — `if cfg!(feature = "gpu-cuda") || HL_GPU is set { return Err(...) }` | `hashline/examples/zk60_fresh_ffn.rs:87-89`; `hashline/examples/zk60_bound_ffn.rs:67-69` | ~3 lines each — but the refusal is deliberate (CPU/GPU parity for this profile has never been gated), so removing it needs the parity gate first |
| B4 | Both examples build their witness from `public_synthetic_fixture()`; there is no export-directory reader on the repaired path | `zk60_fresh_ffn.rs:26-34`, `zk60_bound_ffn.rs:73`, `:83-89` | ~30 lines, or avoided entirely by routing tier 1 through the CLI's existing `--export` reader |

#### What is *not* a blocker — checked and clear

* The **device shape gate** admits both shapes with room to spare
  (`zk.rs:2570`; §1.4). [COUNTED]
* The **CFS mask specification** is already shape-general, including
  the two endpoint slots (`zk.rs:2149-2174`). [COUNTED]
* Every `mr1` refusal (`check_masks`, `check_opening_challenges`,
  `check_table_point`, `draw_mask_challenge`) is written against
  `rows`, `log_n`, `mask_rows`, `prox` as parameters
  (`zk_ffn_fresh_poc.rs:221-341`). [COUNTED]
* `Layout::check` accepts both shapes: `d`, `f` need only be multiples
  of `2^min(log2, 12)` with `16 | d, f`, and `t_rows` a power of two
  (`zkp-core/src/ffn_v3/statement.rs:132-146`). [COUNTED]
* The **weight cache** is available to the repaired profile, because it
  is P1 (public weights): the refusal is `--p3` + `--wcache`
  (`hashline/src/bin/hashline.rs:136-172`), and the fresh profile
  carries the same rule at `zk_ffn_fresh_poc.rs:120-122`.

**One caveat on "not a blocker": `mr1 = true` has never been executed at
any shape but the tiny one.** The refusals above are shape-general in
form; whether they *fire* at a new shape is exactly what a tier-1 run
would find out. A `discard attempt` refusal at 125M would be a real
finding (see §3.6), not a flake.

### 2.3 The witness at real shapes: the exports, confirmed on disk

Checked with `ls`/`du` on 2026-09-19, after the restart:

| Export | Path | Size | Shape (from its `manifest.json`) |
|---|---|---:|---|
| Mistral-7B v3 | `/home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export` | **6.8 G** | `t 512, d 4096, f 14336, layers 32`; checkpoint `/home/victor/models/Mistral-7B-v0.1`; `profile v3-widened`; `range_violations 0` |
| 125M v3 | `/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export` | **140 M** | `t 512, d 768, f 2048, layers 12`; checkpoint `frugal-125m` |

Both are **present and complete** (32 × 8 per-layer `.bin` files plus
`digests.txt` and `manifest.json` in the Mistral case). Copies under
`/home/victor/IntelligenceRegulation/results/m8b_test`,
`/home/victor/wt-uperf3-vv/...` and ~20 sibling worktrees are
**sidecar-only** — the `.bin` files are gitignored and absent, so a run
pointed at those directories would fail on the first read. Point every
command at the `wt-uperf3-aa` paths above.

## 3. What a safe measurement looks like on this box

### 3.1 The machine, and the rules that are not negotiable

**The machine, read on 2026-09-19:** 15 GB of RAM total, **13 GB
available**, 4 GB of swap free; an RTX 4070 Laptop with **8,188 MiB**,
currently **0 MiB used** and no compute processes. Another agent's test
suites share the host.

**The four rules, each with its incident:**

1. **Running out of video memory freezes the whole box, not the
   process.** The legacy private 8B pass spilled to **8,585 MB on an
   8,188 MiB card**, paged continuously for about six minutes, and the
   box froze **three times** on the day it was run
   (`ZK60_FIVE_SECOND_PLAN.md:832-835`; VRAM figure
   [MEASURED] `results/hashline_zk_8b_pass_gpu.log:77`). Under WSL an
   over-budget allocation is served from host memory instead of
   failing, so the run does not crash — it pages, and the display
   driver dies with it.
2. **WSL does not return video memory promptly.** *"Never chain a
   second GPU pass behind it inside one script … run the tiers as
   SEPARATE detached jobs with `nvidia-smi` verified idle between
   them"* (`TASK_BOARD.md:656-660`; same rule at
   `PROGRESS_UPERF3.md:13439-13443` and
   `scripts/hashline_cl_5090_preflight.py:659`). The idle gate is
   **≤ 1,024 MiB used and no compute processes**
   (`ZK60_CLAUDE_5090.md:45`, `:95-96`).
3. **The public pass is safe; the private pass is the one that
   spills.** Public 8B peaks at **5,249 MB** [MEASURED,
   `results/hashline_convert_r3.log:538`]; legacy private at
   **8,585 MB** [MEASURED, same log family].
4. **With `HL_GPU` unset the binary cannot touch the device at all**
   (`gpu/cuda.rs:484-487`), and the CPU-only build (`target/release`)
   has no device arm compiled in at all
   (`gpu/mod.rs:265-270`). The GPU build is a *separate* target
   directory: `hashline/target-gpu/release/hashline`
   (`hashline/Cargo.toml:24-25`). Both binaries exist on this box
   today.

Every run below is therefore launched **detached**, under the heavy
lock, with a `.done` marker, per `CLAUDE.md:78`:

```
setsid nohup bash -c 'flock /tmp/zk-heavy.lock <cmd> >> <log> 2>&1; echo $? > <log-stem>.done' >/dev/null 2>&1 &
```

and the host-memory rungs additionally inside
`systemd-run --user --scope -p MemoryMax=<N>G`, which is this project's
standing wrapper for one heavy process per agent
(`PROGRESS_US.md:8`, `PROGRESS_UZ.md:11`, `PROGRESS_UR.md:7`).

### 3.2 The memory model, and its calibration against measured runs

*(Units: every byte size on this page is binary — `GB = 2^30`,
`MB = 2^20` — which is how the project's logs and `nvidia-smi` report
them, even where the logs write "MB".)*

**The model.** For one commitment of `R` rows over `n = 2^log_cols`
columns at inverse rate `ir`, with `Q = 256` pads:

```
data      = R * n * 8 bytes            (kept by CommittedZk, zkp-core/src/pcs.rs:691)
encoded   = R * n * ir * 8 bytes       (host array, or device-resident under HL_GPU=1)
pads      = R * 256 * 8 bytes          (hiding only, pcs.rs:673)
salts     = n * ir * 32 bytes          (hiding only, pcs.rs:674)
tree      = ~2 * n * ir * 32 bytes     (MerkleTree over the encoded columns)
```

Row counts come from `LayoutV3::new`
(`zkp-core/src/ffn_v3/statement.rs:148-179`) and
`ZkLayoutV3::with_masks` / `with_io` (`zk.rs:2002-2063`), exactly as in
§1.6. For Mistral (`d 4096, f 14336`): `nb_d = 1`, `nb_f = 7`,
`a_len = 112,640·T`, `h_len = 94,208·T`, `w_len = 176,160,768`
(T-independent — **the weights dominate and do not shrink with fewer
tokens**).

**Calibration — this model is not free-floating.** It reproduces:

| Recorded fact | Source | Model |
|---|---|---|
| tiny legacy A / H rows = **681 / 1325** | `ZK60_PENDING_FFN.md:204-208` | **681 / 1325** — exact |
| Mistral H rows at layer 0 = **3033** | source comment `zk.rs:2378-2383` | **3029** (0.13% low; the comment's layer has one larger remainder window) |
| public 1 Mistral layer, CPU, T = 16: **7.5 GB** resident | [MEASURED] `START_HERE.md:241` | 6.70 GB → factor **1.12** |
| public 1 Mistral layer, CPU, T = 256: **10.3 GB** | [MEASURED] `START_HERE.md:241` | 8.54 GB → factor **1.21** |
| legacy `--zk` 1 Mistral layer, CPU, T = 512: **13.29 GB** | [MEASURED] `PROVING_CHANNEL_OPTIONS.md:173` | 10.64 GB → factor **1.25** |

The factor is the witness, the helper/sumcheck temporaries and the
allocator, all of which scale with T while the weights do not — hence
its rise from 1.12 to 1.25. I use `f(T) = 1.12 / 1.17 / 1.21 / 1.25` at
T = 16 / 64 / 256 / 512. Every host number in §3.3 is
`model × f(T) + endpoints + the io sumcheck tables`, and is therefore
**[MODEL]**, not a measurement.

### 3.3 Estimated peak memory, per configuration

**One Mistral-width FFN layer (d 4096, f 14336), repaired private P1,
`log_cols 14 / inv_rate 4 / Q 256`.**

Host, CPU path (all three commitments plus their encodings resident;
the endpoints and the two io sumcheck tables added on top):

| T | A rows | H rows | model host | × f(T) | + endpoints | + io tables | **[MODEL] peak host** |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 16 | 259 | 178 | 6.85 GB | 1.12 | 0.010 | 0.003 | **7.7 GB** |
| 64 | 589 | 454 | 7.22 GB | 1.17 | 0.038 | 0.013 | **8.5 GB** |
| 256 | 1,909 | 1,558 | 8.70 GB | 1.21 | 0.151 | 0.050 | **10.7 GB** |
| 512 | 3,669 | 3,030 | 10.68 GB | 1.25 | 0.302 | 0.100 | **13.8 GB** |

Of every row above, **6.57 GB is the weight commitment alone**
(`W data 1.312 GB + W encoded 5.250 GB`, T-independent) [COUNTED].
Fewer tokens buy much less than they look like they should.

Video memory, GPU path. Here I do **not** sum the model, because the
recorded single-layer peak is far below the sum (the W commitment is
chunked — `HL_GPU_CHUNK_BYTES` 1 GiB / `HL_GPU_CHUNK_ROWS` 1024 by
default, `gpu/cuda.rs:1809-1825`). I anchor on the measurement and add
the repaired delta:

```
anchor  legacy P1, 1 Mistral layer, T=512, GPU: 5,282 MB  [MEASURED, ZK60_CLAUDE_GPU.md:262-265]
        legacy P3, same:                        5,182 MB at HL_GPU_CHUNK_ROWS=128
                                                5,349 MB at 256, 5,651 MB at 512
                                                [MEASURED, ZK60_CLAUDE_CHUNK.md:20-22]
implied A+H device encodings at T=512 = (1.757 + 1.479) GB = 3,314 MB
implied W-chunk residency at peak      = 5,282 - 3,314      = 1,968 MB   [MODEL]
repaired delta: A +70 rows x 65,536 x 8 B                   =    36.7 MB
                H  +1 row                                   =     0.5 MB
                2 endpoints, 8,197 rows x 2,048 x 8 B each   =   268.6 MB
```

| T | A+H device encodings | + W chunks | + repaired delta | **[MODEL] peak VRAM** |
|---:|---:|---:|---:|---:|
| 16 | 104 MB | 1,968 | 10 | **~2.1 GB** |
| 64 | 414 MB | 1,968 | 39 | **~2.4 GB** |
| 256 | 1,657 MB | 1,968 | 152 | **~3.8 GB** |
| 512 | 3,314 MB | 1,968 | 306 | **~5.6 GB** |

Host RSS on the GPU path is bounded by the recorded **4.30 GB** of the
whole 32-layer legacy private GPU pass [MEASURED,
`results/hashline_zk_8b_pass_gpu.log:94`]; one layer is less.

**The 125M shape (d 768, f 2048), 12 layers × 512 tokens.** Measured
VRAM today: P0 **2,430** / P1 **3,068** / P3 **3,235 MB**; prove P0
2.235 s / P1 5.476 s / P3 5.824 s [MEASURED,
`ZK60_CLAUDE_PROFILE.md:25-29`]. Repaired delta per layer: A + 30 rows
= 15.7 MB, H + 1 row, two 1,541-row endpoints = 50.5 MB →
**≈ 3,135 MB [MODEL]**. Host: model 0.85 GB × 1.25 ≈ **~1.1 GB
[MODEL]**.

### 3.4 What is safe here, what needs the box to itself, what must wait for a bigger card

| Configuration | [MODEL] peak | Verdict |
|---|---|---|
| **125M, 12×512, CPU, any arm** | ~1.1 GB host | **Safe**, can share the box |
| **125M, 12×512, GPU, any arm** | ~3.1 GB VRAM, ~1.1 GB host | **Safe** — 5 GB of headroom on the card. Still: card verified idle first, one job at a time |
| **1 Mistral layer, GPU, T ≤ 512** | 2.1–5.6 GB VRAM, < 4.3 GB host | **Safe with the standing GPU discipline**: exactly one layer, `nvidia-smi` idle first, `HL_GPU_CHUNK_ROWS=128`, detached, never chained |
| **1 Mistral layer, CPU, T = 16** | 7.7 GB host | Safe with `MemoryMax=10G`; better with the other agent's suites paused |
| **1 Mistral layer, CPU, T = 64** | 8.5 GB host | Safe with `MemoryMax=10G`, other agent's suites **paused** |
| **1 Mistral layer, CPU, T = 256** | 10.7 GB host | **Needs the box to itself.** `MemoryMax=12G` |
| **1 Mistral layer, CPU, T = 512** | **13.8 GB host** vs 13 GB available | **Do not run here.** It will either OOM or drive the box into 4 GB of swap. Needs a ≥ 24 GB host |
| **32-layer Mistral pass, GPU, private** | ~8.9 GB VRAM on an 8,188 MiB card | **Forbidden on this box.** The legacy version of exactly this run froze the machine three times. Needs a **16 GB+ card** |
| **32-layer Mistral pass, CPU, private** | > 13.3 GB (legacy measured 13.27–13.97 GB) | **Do not run here** |

The one that deserves emphasis: **one Mistral layer on the GPU is a
different animal from the 32-layer pass.** The 8,585 MB peak that froze
the box is a *32-layer* number — it comes from device-pool retention
across layers, which is why `HL_ZK_DRAIN` exists and is load-bearing
(`zk.rs:2388-2405`; with it off, layer 1 dies at
`cuMemAlloc(1514 MB)`). A single layer was measured at **5,182 MB**
[MEASURED] and stayed flat across four consecutive layers
(`ZK60_CLAUDE_GPU.md:416`). The probe should never run more than a few
layers.

### 3.5 The ladder of runs

Ordered safest-first. **Rungs R1–R2 need tier 1 of §5 (one small
caller); R4–R5 need tier 2/3.** Everything writes under
`/home/victor/IntelligenceRegulation/results/pffn_probe/`, never `/tmp`
(`env-tmp-evidence-loss`: proof captures in `/tmp` die on reboot and
are unreproducible).

---

**R0 — the anchor that costs nothing (today, no source change).**
Time the repaired profile at the only shape it runs at, which the
repository has never done: the only recorded figure is an *upper
bound* of ~0.35 s for P1+P3 together, inferred from a 31.64 s wall of
which 31.29 s was the compiler
(`results/zk60_round16_evidence/fresh_demo.log:72-75`). CPU only, 69 MB
RSS measured. Its value is the per-row cost constant that everything in
§1.6 multiplies.

```
setsid nohup bash -c 'flock /tmp/zk-heavy.lock /usr/bin/time -v /home/victor/IntelligenceRegulation/hashline/target/release/examples/zk60_bound_ffn prove p1 0000000000000000000000000000000000000000000000000000000000000001 /home/victor/IntelligenceRegulation/results/pffn_probe/r0_policy.bin /home/victor/IntelligenceRegulation/results/pffn_probe/r0_receipt.bin >> /home/victor/IntelligenceRegulation/results/pffn_probe/r0.log 2>&1; echo $? > /home/victor/IntelligenceRegulation/results/pffn_probe/r0.done' >/dev/null 2>&1 &
```

Writes: `r0.log`, `r0.done`, and two artefacts the example creates with
`create_new` (so the paths must not already exist —
`zk60_bound_ffn.rs:54-60`). Repeat three times with different output
paths; the profile draws fresh OS randomness every time
(`zk_ffn_fresh_io.rs:164`), so there is no seed and no byte gate here.

---

**R1 — 125M, 12×512, GPU, three arms in one session (the first real
number).** Public, legacy `--zk`, repaired. Small, fast (≈ 2.2 / 5.5 /
? s prove), ~3.1 GB VRAM. This is the rung that first says whether the
repair is +2% or +200%.

Arm (a), public — **runs today**:

```
setsid nohup bash -c 'flock /tmp/zk-heavy.lock env HL_GPU=1 HL_GPU_VERBOSE=1 LD_LIBRARY_PATH=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib /usr/bin/time -v /home/victor/IntelligenceRegulation/hashline/target-gpu/release/hashline pass 12 512 --threads 8 --profile v3 --export /home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export --proof-out /home/victor/IntelligenceRegulation/results/pffn_probe/r1a_public.proof >> /home/victor/IntelligenceRegulation/results/pffn_probe/r1a_public.log 2>&1; echo $? > /home/victor/IntelligenceRegulation/results/pffn_probe/r1a_public.done' >/dev/null 2>&1 &
```

Arm (b), legacy private — **runs today**: the same line with
`--zk --seed 1` added and `r1b_legacy` in place of `r1a_public`.

Arm (c), repaired — **needs tier 1**: the same line with
`--zk --mr1` (the flag proposed in §5.1) and `r1c_repaired`. No
`--seed`: the repaired profile refuses one.

Enqueue all three with the same wrapper immediately; they block on the
lock and self-start in order. **Do not** put two GPU arms in one
`bash -c` — that is the chaining the standing rule forbids; three
separate detached jobs on the same lock is the compliant form, with a
`nvidia-smi` idle check between them.

---

**R2 — 125M, 12×512, CPU, the same three arms.** Same commands against
`hashline/target/release/hashline` with `HL_GPU` unset, wrapped in
`systemd-run --user --scope -p MemoryMax=4G`. Value: it removes the
card from the comparison entirely, which is the trap §4.1 describes.
Also add `--phase-profile` here — it **refuses on GPU**
(`hashline/src/bin/hashline.rs:444-445`) and is the only way to get the
fine-grained phase split.

---

**R3 — one Mistral layer, CPU, T = 16, three arms.** The first
real-geometry rung. `MemoryMax=10G`, other agent's suites paused.

```
setsid nohup bash -c 'flock /tmp/zk-heavy.lock systemd-run --user --scope -p MemoryMax=10G /usr/bin/time -v /home/victor/IntelligenceRegulation/hashline/target/release/hashline layer 0 16 --profile v3 --export /home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export --threads 8 >> /home/victor/IntelligenceRegulation/results/pffn_probe/r3a_public.log 2>&1; echo $? > /home/victor/IntelligenceRegulation/results/pffn_probe/r3a_public.done' >/dev/null 2>&1 &
```

then `--zk --seed 1`, then `--zk --mr1`. Expect ≈ 10.5 s public
[MEASURED, `START_HERE.md:241`], 7.7 GB [MODEL] for the repaired arm.
(Use `pass 1 16` rather than `layer 0 16` if you also want
`--phase-profile`: it is accepted *"exactly once on pass --profile v3
only"* and refuses on GPU, `hashline/src/bin/hashline.rs:440-446`.)
**Remember the §1.6 correction: at T = 16 the repaired mask rows are
37% of A, against 1.9% at T = 512.** This rung measures the repair's
*mechanism*, not its cost at the real shape.

---

**R4 — one Mistral layer, GPU, T = 512, three arms (the number we
actually want).** `pass 1 512` is the existing idiom for exactly one
layer (`results/cl6_chunk_sweep.sh:82`). **Card verified idle
(`nvidia-smi --query-gpu=memory.used --format=csv` reads ≤ 1,024 MiB
and no compute processes) immediately before each arm; the three arms
are three separate detached jobs; nothing else touches the card.**

```
setsid nohup bash -c 'flock /tmp/zk-heavy.lock env HL_GPU=1 HL_GPU_VERBOSE=1 HL_GPU_CHUNK_ROWS=128 LD_LIBRARY_PATH=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib /usr/bin/time -v /home/victor/IntelligenceRegulation/hashline/target-gpu/release/hashline pass 1 512 --threads 8 --profile v3 --export /home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export --proof-out /home/victor/IntelligenceRegulation/results/pffn_probe/r4a_public.proof >> /home/victor/IntelligenceRegulation/results/pffn_probe/r4a_public.log 2>&1; echo $? > /home/victor/IntelligenceRegulation/results/pffn_probe/r4a_public.done' >/dev/null 2>&1 &
```

then `--zk --seed 1` (anchor: 3.453 s, 5,282 MB [MEASURED]), then
`--zk --mr1` (estimate: ~5.6 GB VRAM [MODEL]). `HL_GPU_VERBOSE=1`
prints the per-phase VRAM notes (`zk.rs:2372-2381`) — **watch that log
live**; see §3.6.

---

**R5 — one Mistral layer with the endpoint arguments on (needs tier
2/3).** Same as R4 with the `io` profile. This is the only rung that
measures the *complete* repaired construction. It is last because it is
the only one that needs the seam cap lifted and the wire bound ruled
on.

---

**Not on the ladder, deliberately:** any 32-layer private Mistral pass,
on the GPU or the CPU. §4.3 explains how to get the 32-layer number
without running it.

### 3.6 What would make me abort

* **Before any GPU rung:** `nvidia-smi` not reading ≤ 1,024 MiB used
  with no compute processes. Wait, do not start.
* **During a GPU rung:** any `OUT_OF_MEMORY`, any
  `gpu commit declined`, or any `[UPERF3-AI] vram` line above
  **7,000 MiB**. Kill the job, stop the whole GPU ladder for the
  session, and do not retry on the same card until it reads idle again
  — WSL returns VRAM late, so a retry is how the three freezes
  happened.
* **During a CPU rung:** `MemoryMax` killing the scope is the designed
  outcome, not a failure to work around by raising the cap. Re-plan at
  a smaller T instead.
* **A moved digest on a public or legacy arm.** The public 8B pass must
  stay at `dc980e81…4536c` / 1,234,936,956 B and the legacy private at
  `930ce9a0…c982e` / 1,285,578,368 B. A changed digest means the tree
  is broken; stop and report, do not chase seconds.
* **A `discard attempt` refusal from the repaired path at a new
  shape** (`check_masks`, `check_opening_challenges`,
  `check_table_point`, `draw_mask_challenge` —
  `zk_ffn_fresh_poc.rs:221-341`). **Record it and stop. Never
  re-run to get past it** — these refusals are load-bearing and a
  second attempt with fresh randomness is exactly the resampling the
  design forbids (`ZK60_PENDING_FFN.md:186-189`).
* **The other agent starting a heavy suite** during a CPU rung at
  T ≥ 64. The seconds are then worthless (this box has ~2× documented
  run-to-run variance when shared); the memory peak may also collide.

## 4. What the number means once it exists

### 4.1 The fair public arm for each private run

**The rule.** Same binary, same box, same session, same export, same
layer count and token count, same `--threads`, same
`log_cols / inv_rate / col-checks`, same device state. **Only the
privacy flag changes.** Two arms proved by two binaries, or one on the
card and one not, are not a comparison.

**Each private arm has two fair partners, and they answer different
questions:**

| Private arm | Partner | The question it answers |
|---|---|---|
| repaired (`--mr1`) | legacy (`--zk --seed 1`) | **What does fixing the leak cost?** This is the new information — the repaired-vs-legacy ratio is the thing nobody has |
| repaired (`--mr1`) | public (no flag) | **What does P1 cost against the 58.40 s headline?** This is the product number, and the one that goes in `MVP_STATUS.md` |
| legacy (`--zk`) | public | already known; run it anyway, as the sanity check that the session reproduces the recorded ratio |

**The trap the project fell into twice, with both numbers.** The
repository contains two figures that are both called "the privacy
surcharge" and differ by 38×:

| figure | arm | source |
|---|---|---|
| **+4.7%** (15.73 s zk vs 15.02 s clear, p50) | **one** Mistral layer, T = 512, **CPU 8 threads** | [MEASURED] `PROVING_CHANNEL_OPTIONS.md:173`, `START_HERE.md:243` |
| **+178%** (265.34 s vs 95.5 s) | **32** layers, T = 512, **GPU** | [MEASURED] `PROVING_CHANNEL_OPTIONS.md:176` |
| **+2.82%** (485.33 → 499.04 s) | 32 layers, T = 512, CPU — and this one is **P1 → P3**, i.e. the cost of hiding the *weights*, not the activations | [MEASURED] `results/am_r3_8b_p1_scan_cpu.log:76`, `results/am_r3_8b_p3_cpu.log:83` |
| **+20.0%** (3.453 → 4.142 s) | one Mistral layer, T = 512, GPU, also P1 → P3 | [MEASURED] `ZK60_CLAUDE_GPU.md:262-265` |

They are not contradictory. The CPU has no 8 GB cliff, so on the CPU
privacy costs a few per cent; on the card the private arm spills past
8,188 MiB and the public arm does not, so the same "surcharge" is
+178%. **Quoting any of these without its arm is the error.** The probe
must report a matrix, not a percentage.

**A confound that is live today and must be stated with any
private-vs-public ratio.** The 58.40 s public headline includes lane
AL's host fix, which was applied to `layer.rs` only; `zk.rs` carries
its own prover body and **was deliberately not touched**
(`ZK60_FIVE_SECOND_PLAN.md:288-293`). So a private-GPU vs public-GPU
ratio measured today charges privacy for a speedup the private path has
simply not received yet — up to 1.687× on the public side
(98.54 → 58.40 s [MEASURED]). Two honest ways out: compare against the
public arm with lane AL's switches off (98.54 s), or port AL to `zk.rs`
first (that is lane 3 of `ZK60_FIVE_SECOND_PLAN.md` §6). Say which one
was done.

### 4.2 Which phases to break out

The prover already emits named phases; these are the exact strings in
the logs, and the probe should table all of them per arm:

`commit W` · `commit A (zk)` · `mask commit` ·
`LogUp helpers + commit H (zk)` · `matmul sumcheck g/u` ·
`matmul sumcheck d` · `zero-check F` · `zero-check D` ·
`table zero-check` · `zsum + mask open` · `pcs openings (zk)`
(`zk.rs:2305-2334` and the lap sites through
`prepare_layer_zk_v3_inner`).

Device side, under `HL_GPU_VERBOSE=1` / `dev_stats`
(`gpu/mod.rs:290-300`): `secs_h2d`, `bytes_h2d`, `secs_ntt`,
`secs_hash`, `secs_sumcheck`, `secs_fold`, `secs_helpers`, `secs_d2h`,
**`vram_peak`**.

**Three phase lines that do not exist and should be added by the change
in §5**, because without them the repaired arm's extra cost is
invisible in the aggregate:

1. `endpoint commit` — the caller's `prepare_endpoints`
   (`zk_ffn_fresh_io.rs:109-120`), which is *outside* the prover's own
   clock today.
2. `io endpoint argument 0 / 1` — the two masked sumchecks inside
   `finish` (`:299-355`), host-only.
3. `endpoint openings` — the two hiding opens at `:357-362`.

**Predictions worth writing down before the run, so the result can
falsify them** [MODEL, from §1.6]:

| phase | prediction at one Mistral layer, T = 512 |
|---|---|
| `commit W` | **unchanged** — P1 keeps public plain weights. If it moves, something is wrong with the change, not with privacy |
| `commit A (zk)` | **+2%** (3,599 → 3,669 rows) |
| `LogUp helpers + commit H (zk)` | **flat** (+1 row of 3,029). In the 32-layer legacy GPU pass this phase was 146 s of 265 — if it moves there, that is paging, not the repair |
| `mask commit` | **grows** — 6 → 8 CFS slots, the two new ones of 22 variables (`zk.rs:2172`) |
| `pcs openings (zk)` | **the largest relative growth** — two extra hiding openings plus the `check_masks` transcript replay, which redraws `rows` coefficients per opening site (`zk_ffn_fresh_poc.rs:314-321`, i.e. 3,669 Fp2 draws for A alone) |
| the three new lines | pure addition; the endpoint sumchecks are over 2^21-entry tables and are host-only today |

### 4.3 From one layer to thirty-two

**Split the clock three ways.**

| class | phases | how it scales |
|---|---|---|
| **per model** | `commit W` | once per model, not per proof — the contract explicitly carves it out (`ZK60_FIVE_SECOND_PLAN.md` §2). **19.823 s of the public 58.40 s** [MEASURED] |
| **per proof** | witness inference (today: 134.50 s of *disk load*, which is not inference), the final serialization | once per request |
| **per layer** | `commit A`, `helpers + commit H`, both matmuls, F / D / table zero-checks, `zsum + mask open`, `pcs openings` — **and the two endpoint arguments and openings** | ×32 |

**The extrapolation rule, and the evidence that it holds.**
`proof_32 ≈ W_once + 32 × per_layer + per_proof`, **valid only on a
card that does not page**:

```
32 x the measured one-layer P3 GPU clock:  32 x 4.142 s = 132.5 s   [MEASURED x 32]
the measured 32-layer legacy GPU pass:                    265.34 s  [MEASURED]
the ledger's prediction for a 16 GB+ board:               ~140 s    [PREDICTION]
```

132.5 s against the independently-derived ~140 s is **5% apart**. The
2.0× gap to the measured 265.34 s is the 8,585 MB spill and nothing
else. So: **measure one layer and multiply; do not run 32.** And when
the multiplied number is quoted, say "on a card that does not page" —
on *this* card it is a lower bound by about 2×.

**What the weight cache changes.** The repaired profile is P1, so the
weight cache is permitted (the refusal is `--p3 --wcache`,
`hashline/src/bin/hashline.rs:136-172`). Warm, `commit W` collapses to
load + verify + re-encode with a measured ceiling of about **2.6%** of
the prove (`ZK60_CLAUDE_CACHE.md:66-73`,
`ZK60_CLAUDE_PROFILE.md:55-64`). **No 8B run has ever been made with a
warm cache** (`ZK60_FIVE_SECOND_PLAN.md` §6, lane 1). Report both cold
and warm, because the difference is ~20 s of a ~58 s public clock and
it moves the private number by the same absolute amount.

**One modelling choice the current code does not make.** In a chained
32-layer proof, layer k's *output* endpoint is layer k+1's *input*
endpoint, so a chain needs **33 endpoint commitments, not 64**.
`io::prepare_endpoints` commits both planes on every call
(`zk_ffn_fresh_io.rs:109-120`), so a naive ×32 double-counts the
endpoint commitment cost by ~2×. Endpoints are small (§1.5), so this is
a correction of a few per cent, not a headline — but state which
convention the reported number uses.

## 5. What would have to be built first

### 5.1 The smallest change, in three tiers

**Tier 1 — reach `mr1` at a general shape. ~25–45 lines. No new
cryptography. This is the whole recommendation of this document.**

1. Add a public entry pair next to the existing ones in
   `hashline/src/zk.rs`: a `prove_layer_zk_v3_mr1` /
   `verify_layer_zk_v3_mr1` that call
   `prepare_layer_zk_v3_inner(..., mr1= true, io = false, ...)` and
   `verify_layer_zk_v3_with_seams(..., mr1 = true, io = false, ...)`
   (the private functions at `:2337` and `:3471`). ~20 lines.
2. Add a `--mr1` flag to the CLI's v3 `layer` / `pass` paths
   (`hashline/src/bin/hashline.rs:81-84`, and add it to the
   `privacy_flags` guard at `:448`). ~10 lines.
3. Gate: §5.3.

That is enough to run **the repaired mask schedule at 125M and at one
Mistral-width layer, on CPU and on GPU, against the public and legacy
arms in one session** — rungs R1 to R4. It measures everything in the
§1.6 table except the endpoint arguments, which are the small part.

**Expect the first attempt to fail, and treat that as the deliverable.**
`mr1 = true` has never executed above T32/d16/f16. The refusals in
`zk_ffn_fresh_poc.rs:221-341` are shape-general in form; whether they
*fire* at `nb_f = 7` with a 4-row INT16 table is exactly the unknown.
Budget a session for it and record each refusal rather than working
around it.

**Tier 2 — the endpoints at the 125M shape. ~200–300 lines.**
Blockers A2, A3, A4, A5, A6, A7, A8, A9, A10, A12 from §2.2. Two
things make it more than mechanical:

* **A5 is a construction change, not a constant bump.** The seam's own
  CFS mask spec is `[(log_len + 1, DEGREE)]`
  (`private_seam.rs:107`), so the mask slot grows with the plane;
  raising `MAX_LOG_LEN` from 12 changes what is being proved about the
  endpoint, not just how big it is. This needs the same owner who
  approved the seam.
* **A4 moves every proof byte of this profile** (the transcript absorbs
  the literal parameter string), so it needs a new profile tag and
  regenerated fixtures — by design, not by accident.

**Tier 3 — the endpoints at Mistral width.** Tier 2 plus a ruling on
A11: `MAX_WIRE_BYTES = 32 MiB` is smaller than one Mistral layer's
proof before any endpoint bytes exist (36.9 MiB public, 38.3 MiB legacy
private, both [MEASURED]). Raising a decoder's denial-of-service bound
is an owner ruling for `ZK60_DECISIONS.md`, not an edit. The
alternative — a streaming/chunked frame — is more work but does not
need the bound raised.

### 5.2 Whose files these are

Checked with `git --no-pager status --short` at the time of writing:

* **Codex's live uncommitted work** moved twice during the two hours
  this page took to write — first `scripts/zk60_zkvm_demo.py`,
  `tests/test_zk60_zkvm_demo.py`, `zkvm-block/**` and three docs, then
  `hashline/src/private_attention*`, `hashline/src/private_block*` and
  a new `hashline/src/native_capture.rs`. Throughout, **`zk.rs`,
  `zk_ffn_fresh_poc.rs`, `zk_ffn_fresh_io.rs`, `zk_ffn_fresh_wire.rs`,
  `private_seam.rs`, `pcs.rs`, `layer.rs`, `gpu/*` and
  `bin/hashline.rs` were all clean.** Re-check immediately before
  starting and never edit a file Codex has uncommitted.
* **The speed lane (fsp-l9) owns `hashline/src/gpu/*` and `ntt.rs`.**
  Tier 1 needs no change in either.
* **`Cargo.toml` / `Cargo.lock` are contended** (Codex had them
  modified at the start of this session). Work in a sibling worktree,
  `../wt-pffn-probe`.
* **Do not touch** `codex-audit-*`, `scripts/logup_*_spike.py`,
  `src/manifest.rs` (`CLAUDE.md`, protocol invariants).

### 5.3 The gate that protects existing proof bytes

**First, the thing that surprises people: the repaired profile cannot
be byte-gated at all.** It refuses a seed and draws fresh OS randomness
on every attempt (`zk_ffn_fresh_io.rs:158-164`,
`zk_ffn_fresh_poc.rs:95-103`), so two runs of the repaired arm produce
different bytes by design. The gate therefore protects the *other*
arms — it proves the change did not leak into them:

1. **The public 8B digest is unchanged:**
   `dc980e810085b2ddf4688eb4a6cf4dd931c209bf7c5a9a7692d57ec14bc4536c`
   at **1,234,936,956 B**, checked with `sha256sum` by hand and not
   only by the binary.
2. **The legacy private 8B digest is unchanged:** `930ce9a0…c982e` at
   **1,285,578,368 B**.
3. **The twelve byte gates stay green** — four fixtures × CPU / GPU /
   GPU with `HL_GPU_CHUNK_BYTES` forced small
   (`ZK60_FIVE_SECOND_PLAN.md` §6, lane 1).
4. `cargo test --test zk60_pending_layout` (4 layout tests, no proof
   generated) plus the `zk_ffn_fresh_io` / `zk_ffn_fresh_poc` unit
   tests.
5. `python3 -m unittest discover -s tests` plus freeze-check
   (`CLAUDE.md`, protocol invariants).

**Why the gate should hold structurally, and what it means if it does
not.** Tier 1 adds a new entry point and changes no existing call's
`mr1` argument — every call site today passes `false`
(`zk.rs:2280`, `:3468`). A moved byte would mean the change leaked into
the legacy path, which is a bug in the change, not a cost of privacy.

## 6. What I did not read, and what I could not determine

### Read in full

`hashline/src/zk_ffn_fresh_io.rs` (608 lines),
`hashline/src/zk_ffn_fresh_poc.rs` (342),
`hashline/src/pcs.rs`, `hashline/examples/zk60_bound_ffn.rs`,
`hashline/examples/zk60_fresh_ffn.rs`,
`docs/zkmatrix-poc/ZK60_PENDING_FFN.md`,
`ZK60_FFN_MASK_INVENTORY.md`, `ZK60_FIVE_SECOND_PLAN.md` §§1.2–1.5 and
§5, `ZK60_MVP_COMPLETION_PLAN.md` §2.1.

### Read in part, by targeted reading

`hashline/src/zk.rs` — about 600 of its 5,000+ lines: the layout
constructors (`:1930-2148`), `mask_specs_v3` (`:2149-2174`), the
pending lifecycle (`:2279-2420`), every `gpu::` dispatch site and every
`mr1` site. **I did not read the arguments themselves** (the matmul
sumchecks, the zero-checks, the LogUp construction).
`zkp-core/src/pcs.rs` and `zkp-core/src/ffn_v3/statement.rs` — the
commitment and layout bodies only. `hashline/src/private_seam.rs` —
the spec, sizes and bounds, not the argument.
`hashline/src/bin/hashline.rs` — the option parser and the guards.

### Not read

`hashline/src/layer.rs` beyond the public v3 array construction and the
device gates; `attention.rs`; `private_block.rs` and the whole
private-block family (I took §2.1 of the completion plan as the
authority on it); `ZK60_FABLE_MASK_REPAIR.md` (739 lines) and the Fable
privacy reviews; `ZK60_ROUND16.md`–`ZK60_ROUND25.md` (a delegated
search reports they carry command lines and hashes but **no wall-clock
timings at all**); the CL-lane documents beyond the rows a delegated
search returned with file:line.

**I take no position on whether the repair is a repair.** This page is
about cost, not about privacy. Nothing here should be read as a privacy
claim, and the 2026-09-08 correction still governs every private figure
quoted from the legacy profile.

### Could not determine

1. **The repaired profile's prove clock at any shape.** The repository
   has only an upper bound: ~0.35 s for P1 and P3 together at
   T32/d16/f16, inferred from a 31.64 s wall of which 31.29 s was the
   compiler (`results/zk60_round16_evidence/fresh_demo.log:72-75`).
   That is rung R0's whole purpose.
2. **Whether `mr1 = true` actually runs at a shape other than the tiny
   one.** Nobody has tried. My "shape-general" finding is from reading
   the constructors and the refusals, not from execution. If it fails,
   it fails in `check_masks` or `check_table_point` at a shape with
   multi-row tables and `nb_f = 7`.
3. **The exact VRAM split at the measured 5,282 MB single-layer peak.**
   I inferred 1,968 MB of weight-chunk residency by subtracting the
   counted A + H encodings [MODEL]. `HL_GPU_VERBOSE=1` prints the real
   split (`zk.rs:2372-2381`) and would settle it in one run.
4. **Whether the endpoint commitments would reach the device.**
   `private_seam::prepare` calls `pcs::commit_zk`, which offers the
   backend like any other commitment — but that path has never run
   with `HL_GPU=1`, because both examples refuse the GPU (blocker B3).
5. **Whether raising `MAX_LOG_LEN` is sound.** The seam's CFS mask spec
   is `[(log_len + 1, DEGREE)]` (`private_seam.rs:107`): the slot grows
   with the plane. That is the shape of a construction change. It needs
   the owner who approved the seam, not me.
6. **Host RSS for the 125M GPU arms** — not in any record I read; only
   VRAM (2,430 / 3,068 / 3,235 MB) and seconds were kept.
7. **Whether the 33-vs-64 endpoint convention (§4.3) is the intended
   chain model.** The code re-commits both planes per FFN.
8. **The contract clock.** No number in this repository is the contract
   clock as written (`ZK60_FIVE_SECOND_PLAN.md:153-161`): the 58.40 s
   is prover arithmetic and the 134.50 s beside it is disk I/O for a
   witness the contract says should be *computed*. Everything this page
   proposes measures prover arithmetic only, and should be labelled
   that way when it lands in `MVP_STATUS.md`.
9. **Whether the box will be quiet.** I did not coordinate with the
   other agent. Every second in §3.5 is worthless if its suites run
   during a rung; the memory peaks may also collide. Rungs R1 and R2
   are small enough not to care; R3 upward are not.

---

*(draft complete)*
