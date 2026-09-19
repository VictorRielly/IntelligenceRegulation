# The hiding endpoints at model scale: what the construction is, what its eleven size pins protect, and what it would cost

**DRAFT for the security owner's review — NOT ACCEPTED. Delegated Opus
draft, 2026-09-19. Paper only.**

| | |
|---|---|
| Author | delegated cryptographic-construction drafter (Claude Opus 5), 2026-09-19 |
| Scope | the `io` half of the repaired private feed-forward: `hashline/src/zk_ffn_fresh_io.rs`, `hashline/src/private_seam.rs`, `hashline/src/zk_ffn_fresh_wire.rs`, `hashline/src/zk_ffn_fresh_poc.rs` and what they use in `hashline/src/zk.rs` and `zkp-core/src/pcs.rs` |
| Method | paper only. Read-only on all code; no build, no run, no test, no benchmark |
| Rulings that bind it | D1 (P1 scope), **D8 / D11 (OPEN)**, D12, D13, D15, D16 |
| **Status** | **No privacy property is claimed. D8 / D11 is not closed and is not touched.** |

## 0. What this page is, and what it is not

**Nothing here was executed.** No build, no proof, no test, no benchmark,
no GPU. Every number is labelled `[MEASURED]` (with its path),
`[COUNTED]` (with the arithmetic shown) or `[MODEL]` (an estimate, with
its arithmetic and with the measurement that would test it named). No
privacy property is claimed anywhere on this page, and the
caller-fixed-endpoint-root obligation of **D8/D11 is not touched and
stays OPEN**.

The question. The repaired private feed-forward has two halves
(`ZK60_PRIVATE_FFN_COST_PROBE.md` §1.1). The **repaired masks** (`mr1`)
were measured at a real shape for the first time today and cost the
legacy profile plus 1–6% (`ZK60_FSP_MR1_PROGRESS.md` on branch
`fsp-mr1`). The **hiding endpoints** (`io`) — the half that actually
hides the input and the output — run only at T32/d16/f16 and carry
eleven size pins. The scoping memo left one question open that decides
whether the half can be widened at all:

> Is lifting the plane cap SOUND and still HIDING, given that the seam's
> mask slot grows with the plane?

**The short answers.**

1. **The slot grows logarithmically, and the worry is not real.** The
   seam's masking slot is `L = 2·(log2 N + 1) + 2 = 2·log2 N + 4`
   coefficients, and `mask_commit` asserts `L + 256 <= 512`, i.e.
   `L <= 256` (`hashline/src/zk.rs:442`). That binds at
   `log2 N <= 126`. A Mistral endpoint plane is `log2 N = 21`, giving
   `L = 46` and `46 + 256 = 302 <= 512`, with the layer's own largest
   slot (`SC_ZC17`, `L = 90`) still far inside. **[COUNTED, §3.4.]**
2. **Nothing in the soundness argument depended on the plane being
   small.** The seam's error is `(m + 2(m+1))/|Fp2|`, which moves from
   `2^-123.1` at the tiny shape to `2^-122.0` at Mistral width.
   **[COUNTED, §4.1.]**
3. **Nothing in the hiding argument depends on the plane length or on
   the number of data rows** — with one exception that is a real design
   constraint, not a size pin: the joint view's H-pair hypothesis needs
   **one reserved mask pair per claim site**, and a naive widening
   creates `nb_d` claim sites per endpoint where the tiny shape has one
   (§5.1). §3.3 gives the fix that keeps it at one.
4. **But a naive widening is UNSOUND at the 125M shape**, for a reason
   the scoping memo did not find: the seam argument binds a single
   `log_t + log_db` slice at `lay.x[0]`, which is the **first d-block
   only**. Mistral has `nb_d = 1` and is unaffected; 125M has
   `nb_d = 3`, so two thirds of the input plane would be unbound. §2.3.
5. **And the cost ordering is the reverse of the mask half's.** At
   Mistral width the endpoints add **+6.1%** of proof bytes and about
   **+1.5%** of committed rows; at 125M the same construction adds
   **+27%** (batched) or **+57%** (unbatched) of proof bytes, because
   125M's `d = 768` is three d-blocks and its per-layer proof is six
   times smaller. **125M is therefore a bad proxy for the endpoint
   half**, exactly as T = 16 is a bad proxy for the mask half
   (`ZK60_PRIVATE_FFN_COST_PROBE.md` §1.6 caveat 1). **[COUNTED, §3.5.]**

**What this page does not do.** It does not close D8/D11; it does not
establish that the widened endpoint hides anything; it takes no position
on whether the repaired profile is a repair; and every cost in §3.5 is a
count or a model, never a measurement. Today three counted speed
estimates in this project shrank three- to seven-fold when measured
(`ZK60_FIVE_SECOND_PLAN.md`, the 2026-09-19 correction), so §3.5 names,
for every cost it counts, the run that would test it.

## 1. The endpoint construction as built, at the tiny shape

Everything in §1 is read off `hashline/src/private_seam.rs`,
`hashline/src/zk_ffn_fresh_io.rs`, `hashline/src/zk_ffn_fresh_wire.rs`,
`hashline/src/zk_ffn_fresh_poc.rs`, `hashline/src/zk.rs` and
`zkp-core/src/pcs.rs`, at the 2026-09-19 working tree. The tiny shape is
T = 32 tokens, d = 16, f = 16, so one endpoint plane is
`T·d = 512` field words.

### 1.1 The commitment's geometry

One endpoint is an ordinary hiding Ligero-class commitment
(`pcs::commit_zk_owned`, `zkp-core/src/pcs.rs:653`) built by
`private_seam::prepare_with_rng` (`private_seam.rs:200-223`) under the
module's four fixed parameters (`private_seam.rs:28-36`):

| constant | value | line |
|---|---:|---|
| `LOG_COLS` | 8 → `n = 256` message positions per row | `:28` |
| `CHECKS` | 256 opened columns | `:29` |
| `INV_RATE` | 8 → `nn = 2048` encoded positions per row | `:30` |
| `MASK_ROWS` | 5 | `:36` |
| `DEGREE` | 2 | `:32` |
| `MAX_LOG_LEN` | 12 → a plane of at most 4,096 words | `:31` |

and `ZkOpts::standard` gives `q_pad = num_col_checks = 256` uniform pad
symbols per row (`zkp-core/src/pcs.rs:542-544`), which
`commit_zk_owned_with` refuses to let fall below the column-check count
(`:670`).

The row layout (`private_seam.rs:106-111`, `:207-217`):

```
data_rows        = ceil(len / 256)                 :106-108
commitment_rows  = data_rows + MASK_ROWS           :109-111
```

At `len = 512`: `data_rows = 2`, `commitment_rows = 7`. Rows are

| row | content | set at |
|---|---|---|
| 0, 1 | the 512 plane words, row-major over 256 columns | `:210` |
| 2, 3 | **the terminal mask pair** — `committed.mask_rows = [2, 3]` | `:216` |
| 4 | **the proximity mask row** — `prox_mask_row = Some(4)` | `:217` |
| 5, 6 | two further uniform rows, used only by the proximity combination | `:211-213` (every row from `data_rows` on is `rng.fp()`) |

Rows 2–6 are all uniform; the pair (2, 3) carries one Fp2-valued mask as
`R_re + U·R_im`, which is why it is a *pair* and not a row
(`ZK60_PRIVATE_SEAM.md`, "Local masking and encoding budget"). Each of
the 7 rows additionally carries `Q = 256` uniform pad symbols outside
the message (`commit_zk_owned_with`, `pcs.rs:673`), and each of the
`nn = 2048` encoded columns carries its own 32-byte leaf salt
(`pcs.rs:674`, `:689`).

Encoding rate. The hiding code is `RS(n + Q, nn) = RS(512, 2048)`, so
the **effective rate is 1/4, not 1/8** — `pcs.rs:525-528` and
`ZK60_PRIVATE_SEAM.md` say this explicitly. That matters in §4.2: it is
the same effective rate the model-scale A commitment runs at.

Encoded size at the tiny shape: `7 × 256 × 8 × 8 = 114,688 B` of
encoded data, `14,336 B` of systematic data, a Merkle tree over 2,048
salted leaves (depth 11). **[COUNTED]**

### 1.2 The owner lifecycle, and what makes it one-use

`io::prepare_endpoints(spec, input, output)`
(`zk_ffn_fresh_io.rs:109-120`) is called by the **endpoint owner**,
before and independently of proving. It returns two objects:

* `ExpectedIo` — the **public policy**: the context digest, the two
  declared scales and the two roots (`:49-53`). 112 bytes on the wire
  (`EXPECTED_BYTES = 8 + 32 + 4 + 4 + 2·32`, `:18`). The commitment
  shape `rows: 7, log_cols: 8` is **baked into** `from_roots`
  (`:58-68`).
* `Endpoints` — the **private owner**: two `PreparedPlane`s (`:104-107`).
  `PreparedPlane` has no `Clone`, no `Debug`, no serialization, no value
  getter and no arbitrary-opening method (`private_seam.rs:142-162`);
  the only way out of it is `into_ffn_endpoint`, which takes `self` by
  value and checks the spec digest and the side (`:156-161`).

One-use is enforced by Rust's move semantics, not by a counter:

* `PendingProof::finish(self, endpoints)` takes **both** owners by value
  (`zk_ffn_fresh_io.rs:276`), so both are dropped on success *and* on
  every error path. A second `finish` does not type-check, and that is
  pinned by a `compile_fail` doctest at `:125-131`.
* `check_endpoints` (`:258-271`) recomputes both roots from the owners
  and refuses if they differ from the policy. It deliberately does
  **not** compare the secret values: "unequal committed values must fail
  the verifier's polynomial identity" (`:274-275`).
* Fresh OS entropy on every attempt, no seed anywhere:
  `ZkRng::from_os` at `private_seam.rs:196` and
  `zk_ffn_fresh_io.rs:164`. Two runs of this profile therefore produce
  different bytes by design — it cannot be byte-gated (§7).

Why one-use is load-bearing rather than tidy: **two openings of one
endpoint commitment at this geometry recover all 512 hidden words**, by
cancelling the fixed terminal mask between the two published group
vectors (`ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md`; D11). D12 rule 1
forbids the configuration outright.

### 1.3 The seam relation actually proved

Inside `finish`, for each side `i ∈ {0, 1}` (`:290-355`):

1. absorb `io-side = i`, draw `tau = challenge_fp2_vec(9)` (`:292`) —
   9 = `log_t + log_db = 5 + 4`, the plane's bit width;
2. draw the masking coefficient `c` through the **refusal**
   `draw_mask_challenge(.., repaired = true)` (`:293`), which discards
   the attempt on `c = 0` rather than resampling
   (`zk_ffn_fresh_poc.rs:221-233`);
3. publish `gamma = c · g_s.total()` for the **already committed** CFS
   mask of slot `FIRST_IO_SLOT + i = 6 + i` (`:295`, `:14`). The two
   slots were reserved before M was committed (`zk.rs:2172`), so no new
   randomness or commitment can enter at finalization (`:279-280`);
4. run a masked sumcheck over three tables — `eq_table_msb(tau)`, the A
   commitment's plane slice `a.data[off .. off+512]`, and the endpoint's
   `data[..512]` (`:299-311`) — with
   `poly(v) = v[0]·(v[1] − v[2])` (`:198-200`), degree 2, **9 rounds**;
5. add one **extension round** (`extension`, `:325-335`) that replaces
   each plane's terminal by its reserved mask, giving **10 rounds
   total**; refuse on a zero extension challenge `e` (`:336-338`);
6. publish the two masked terminals
   `masked_terminal(finals[k], exts[k], e)` (`:339-342`) and the mask
   evaluation `g_s(rho, e)` (`:348`), and append two mask functionals to
   the FFN's own list (`:351-353`, `functionals` at `:236-253`).

The verifier's final identity (`verify_arguments`, `:389-401`) is

```
fin  ==  (1 − e)·eq(tau, rho[..9])·(terminals[0] − terminals[1])  +  c·mask_eval
```

So the statement proved is "the multilinear extension of (A-plane −
endpoint-plane) vanishes at the random point `tau`", masked throughout.
No raw plane evaluation is ever sent: both terminals are blinded by
their own reserved pair.

**The mask polynomial.** Slot `6 + i` is specified by
`mask_specs_v3` as `(lay.log_t + lay.log_db + 1, 2) = (10, 2)`
(`zk.rs:2172`), and `CfsMask::len(n_vars, degree) = n_vars·degree + 2`
(`zkp-core/src/sumcheck.rs:197-199`), so

```
L = 10·2 + 2 = 22 coefficients
```

It lives in the layer's single masking commitment M, one row pair of the
512-position message, with 256 pads beside it — `mask_commit` asserts
`L + MASK_Q <= 512` (`zk.rs:442`, `MASK_LOG_MSG = 9` at `:373`,
`MASK_Q = 256` at `:375`). The two io slots take M's base row count from
`2·6 + 4 = 16` to `2·8 + 4 = 20` (`zk_ffn_fresh_wire.rs:41`, `:233`).

**The A-side mask rows the seam consumes.** `ZkLayoutV3::with_io`
(`zk.rs:2057-2063`) appends **two mask pairs, 4 rows**, after every
existing A row: `a_io = Some([first, first + 2])` and
`a_len += 4·a_n`. They join `a_mask_rows()` (`zk.rs:2090`), so the
repaired `check_masks` rank test covers them.

### 1.4 What is opened, at which points, in which groups

| commitment | claims added by the seam | where | groups |
|---|---|---|---|
| **A** (the FFN's activation commitment) | **2** — one per side, `claim(offsets[i], rows[i], rho, e, terminals[0])` (`:345`), with `offsets = [lay.x[0], lay.z[0]]` (`:284`) | inside the FFN's own single `open_zk` (`zk.rs:2323-2325`) | **2 new** column-weight groups (each side's `rho` tail differs), taking A from 5 to 7 (`zk_ffn_fresh_wire.rs:232`) |
| **endpoint i** | **1** — `claim(0, 2, rho, e, terminals[1])` (`:346`) | its own `pcs::open_zk` after the FFN's openings (`:357-362`) | **1** |

Each claim has three parts (`claim`, `:204-235`):

```
part 0: slice { offset, log_size: 9 }, coef (1 − e), point rho        (the data plane)
part 1: slice { offset: row·256, log_size: 8 }, coef e,     point rho[1..9]
part 2: slice { offset: (row+1)·256, log_size: 8 }, coef e·U, point rho[1..9]
```

Parts 1 and 2 are the reserved pair. Their coefficients are `e` and
`e·U` with `e ≠ 0` refused, which is exactly an Fp-basis of Fp2 — the
H-pair hypothesis of the joint view. Both `open_zk` sites are preceded
by the repaired rank refusal
`check_masks(claims, 7, 8, &[2, 3], 4, tr)` — prover at `:360`,
verifier at `:459` — which replays the PCS challenge prefix without
advancing the transcript and refuses unless the claim's mask
coefficients span Fp2 and the proximity pair `(rho[4], rho[5])` is
independent (`zk_ffn_fresh_poc.rs:253-341`).

Opening order across the whole receipt: M, then W, A, H (inside
`PendingV3::finish`, `zk.rs:2306-2333`), then the two endpoints
(`:357-362`). Each opening has its own transcript label.

### 1.5 What the wire frame carries

The receipt is `ffn ‖ 2 arguments ‖ 2 endpoint openings`
(`Receipt::to_bytes`, `:513-551`), inside a frame whose length is
computed from the **checked statement only**:

```
EXPECTED_BYTES      = 8 + 32 + 4 + 4 + 2·32                              = 112 B      :18
ARGUMENT_BYTES      = 16 + 10·3·16 + 2·16 + 16                           = 544 B      :16
ENDPOINT_OPEN_BYTES = 2·512·16 + 256·(8 + 7·8 + 32 + 11·32)              = 131,072 B  :15
EXTRA_BYTES         = 8 + 32 + 2·544 + 2·131,072                         = 263,272 B  :17
```

`2·512·16` is the group vector plus the proximity vector, each of
`n + q = 256 + 256 = 512` Fp2 entries (`pcs.rs:568`, `:973`); `7` is the
commitment's rows; `11` is the Merkle depth of a 2,048-column tree; `8`
is the column index. The whole frame is bounded by
`MAX_WIRE_BYTES = 32 MiB` (`zk_ffn_fresh_wire.rs:11`), enforced at
`zk_ffn_fresh_io.rs:507-510`. The io payload reuses the legacy FFN
frame with three deltas: `rows[1] += 4`, `a_groups = 7`,
`mask_rows += 4` (`zk_ffn_fresh_wire.rs:228-234`).

The receipt's own shape check (`:536-548`) re-pins every one of those
numbers: `group_vecs.len() == 1`, `group_vecs[0].len() == 512`,
`prox_vec.len() == 512`, `columns.len() == 256`, `j < 2048`,
`c.len() == 7`, `p.len() == 11`.

### 1.6 The tiny numbers, reproduced from source

I rebuilt the layout arithmetic from `LayoutV3::new`
(`zkp-core/src/ffn_v3/statement.rs:148-179`) and
`ZkLayoutV3::with_masks` / `with_io` (`zk.rs:2000-2063`) and checked it
against the numbers the committed tests assert. **It reproduces every
one of them exactly.** [COUNTED, validated]

| quantity | my count | source of truth |
|---|---:|---|
| endpoint data rows / commitment rows | 2 / **7** | `rows: 7, log_cols: 8` at `zk_ffn_fresh_io.rs:58-68`, re-pinned at `:543` |
| endpoint mask pair / prox row | **(2, 3) / 4** | `private_seam.rs:220-221`; `check_masks(.., &[2,3], 4, ..)` at `:360`, `:459` |
| A data rows | 20 | `(7·1·512 + 3·1·512)/256` |
| A mask rows (`mr1`, width 2) | 26 | `2·(7·nb_f + 3·nb_d + nb_d + nb_f + 1)` |
| A table rows + their masks | 324 + 328 | six slots, `1 / 256 / 1 / 1 / 64 / 1` (`ZK60_OPUS_SEAM_REVIEW.md` §"Counted tiny memory") |
| A rows before io | 698 | — |
| **`a_io` pair rows** | **[698, 700]** | `assert_eq!(rows, [698, 700])`, `zk_ffn_fresh_io_tests.rs:41` |
| **A commitment rows** | **702** | `assert_eq!(.., 702)`, `:77` |
| **H commitment rows** | **1326** | `assert_eq!(.., 1326)`, `:78` (legacy 1325, `ZK60_PENDING_FFN.md:204-208`) |
| **A opening groups** | **7** | `assert_eq!(receipt.ffn.a_open.group_vecs.len(), 7)`, `:83` |
| **M base rows** | **20** | `assert_eq!(held.mc.encoded.len(), 20·4096)`, `:52` |
| **io CFS slots** | **(10, 2) × 2**, `L = 22` | `assert_eq!(&held.mc.specs[6..], &[(10, 2); 2])`, `:51` |
| A claims | 18 | `assert_eq!(pending.pending.ac.len(), 18)`, `:47` |

The same arithmetic reproduces the legacy tiny pair **A 681 / H 1325**
and, at 12 × 512 on the 125M export, the **measured** row counts
`A 520 / 559 / 585` and `H 432 / 485 / 486` for the public, legacy and
repaired arms (`ZK60_FSP_MR1_PROGRESS.md` stage 4 table, branch
`fsp-mr1`) [MEASURED], and at Mistral width `A 3,520 data / 3,599
legacy / 3,665 repaired / 3,669 with io` and `H 2,944 / 3,029 / 3,030`.
Nothing downstream of §1.6 rests on a number I could not reproduce.

## 2. The eleven pins, classified

### 2.1 The classification rule

* **(a) CAPACITY** — an allocation bound, a loop bound, a wire-size
  sanity cap, a hard-coded length that is a *consequence* of the shape.
  Lifting it changes no statement and no security argument. It still
  needs a test, because a decoder bound is a denial-of-service defence.
* **(b) PROTOCOL** — the constant is inside the transcript, a
  domain-separation string, a digest or the statement. Changing it moves
  every existing proof byte of the profile. Lifting it is legitimate but
  requires a **new profile tag** and regenerated fixtures, never an edit
  in place.
* **(c) SECURITY** — a soundness or hiding argument depends on it: a pad
  budget, a mask-row count, a slot-length bound, a field-size or
  no-wraparound bound, a Merkle depth, a claim/pair correspondence.
  Lifting it needs the argument re-derived at the new size, not a
  bigger number.

A pin can be in two classes; the table gives the binding one first.

### 2.2 The table

The eleven are A1–A11 of `ZK60_PRIVATE_FFN_COST_PROBE.md` §2.2 A; A12 of
that table is a latent bug rather than a blocker, and is kept here as
the twelfth row because it becomes load-bearing the moment A1 is
relaxed.

| # | pin | file:line | class | what it protects, and the evidence |
|---|---|---|---|---|
| **A1** | `preflight` refuses anything but `(32, 16, 16)` | `zk_ffn_fresh_poc.rs:72-78` | **(c)** | Not a capacity bound: it is the *guard that makes every other constant true*. A2, A6–A10 are all written assuming it. Evidence: each of those sites hard-codes a number that `(32,16,16)` implies (512, 7, 9, 8, 256, 10). Removing A1 alone turns all of them into silent misreads. |
| **A2** | every activation plane exactly 512 words, every weight block exactly 256 | `zk_ffn_fresh_poc.rs:117-145` | **(a)** | A witness-length sanity check; the correct general forms are `t_rows·d`, `t_rows·f`, `d·f` (`Layout::new`, `statement.rs:148-179`). No argument uses the literal 512 for anything but slicing. |
| **A3** | `parameters()` fixes `log_cols 8 / inv_rate 8 / Q 256` against the CLI's `14 / 4 / 256` | `zk_ffn_fresh_poc.rs:51-57`; CLI default `hashline/src/bin/hashline.rs:59` | **(c)** then (b) | The encoding rate is the soundness parameter: `(n+Q)/nn` is 1/4 here and 0.2539 at `14/4`, giving `2^-106.25` and `2^-105.61` per opening (§4.2). It is also absorbed (A4), so changing it moves bytes. And at `log_cols 8` a Mistral A commitment would be 225,280 data rows instead of 3,520 — a measurement taken there would be an artefact, not a cost. |
| **A4** | the transcript absorbs the literal `T32/d16/f16/log_cols8/inv_rate8/Q256/two-private-seams` | `zk_ffn_fresh_io.rs:138-146`; sibling `zk_ffn_fresh_poc.rs:80-88` | **(b)** | It is a domain separator inside `Transcript::new(PROFILE)`. This is the pin that is *working correctly*: a widened profile must not be able to masquerade as the tiny one. The change is a new literal plus a new `PROFILE` tag, not an edit. |
| **A5** | `MAX_LOG_LEN = 12`; refusal "supported plane has 2..4096 values and power-of-two axes"; the same constant sizes `mask_spec` and `encoded_len` | `private_seam.rs:31`, refusal `:66-72`, `mask_spec :112-114`, frame `:600-609` | **split: (a) for the 4,096; (c) for what it stands in front of** | The numeric cap is pure capacity — nothing reads `MAX_LOG_LEN` except the refusal. What is genuinely security-relevant is what the memo pointed at: the slot `[(log_len + 1, DEGREE)]` grows with the plane, against `mask_commit`'s assert `L + 256 <= 512` (`zk.rs:442`). §3.4 works that out: `L = 2·log2 N + 4`, binding only at `log2 N > 126`. **The memo's worry is real in form and empty in magnitude.** Two other things hide behind this constant and are class (c): `MASK_ROWS = 5` (exactly one reserved pair — §5.1) and the power-of-two axis rule (§2.3, P13). |
| **A6** | the plane shape is literally `32, 16` | `zk_ffn_fresh_io.rs:38-43` (`:40-41`) | **(a)** | Two arguments to `SeamSpec::new`; they must come from the statement. |
| **A7** | the policy hard-codes `rows: 7, log_cols: 8` | `zk_ffn_fresh_io.rs:55-69` (`:58-68`) | **(b)** then (a) | The policy is **absorbed** (`:140`), so the shape is part of the statement the verifier commits to — correctly, since a verifier that accepted any `rows` would accept an endpoint of a different geometry. `rows` becomes `ceil(T·d/n) + MASK_ROWS`. |
| **A8** | `ENDPOINT_OPEN_BYTES` is a closed form built from 512 / 7 / 11 / 256 | `zk_ffn_fresh_io.rs:15`, used at `:505-511` | **(a)** | Exact-frame arithmetic. Every term is derivable: `n+q`, `rows`, `log2(nn)`, `num_col_checks`. |
| **A9** | the receipt shape check pins `512 / 512 / 256 / j < 2048 / c.len()==7 / p.len()==11` | `zk_ffn_fresh_io.rs:536-548` | **(c)** | This one deserves care. It is the "no attacker-supplied length controls an allocation" defence *and* the check that the opening is the one the claims were built for. Generalising it means deriving each bound from the checked statement — which is exactly what `private_seam.rs:511-569` and `zk_ffn_fresh_wire.rs:75-142` already do for their own frames. A generalisation that replaces a constant with a value read from the frame would be a real vulnerability. |
| **A10** | the two arguments are written against 512-word slices: `a.data[off..off+512]`, `endpoints[i].data[..512]`, `log_size: 9`, `row·256`, `MaskPoint(.., 256)`, `rho[len-8..]`, `challenge_fp2_vec(9)`, `sum_weights(10, 2)`, `claim(0, 2, ..)`, `check_masks(.., 7, 8, &[2,3], 4, ..)`, `sumcheck::verify(.., 2, 10, ..)`, `rounds.len() != 10`, `r.argument((10,2), 2)`, `r.hiding(1, 7)` | `zk_ffn_fresh_io.rs:201-235`, `:236-253`, `:292`, `:301`, `:306`, `:346`, `:360`, `:389`, `:459`, `:526`, `:573`, `:581` | **mostly (a), with one (c)** | Almost all of these are `log_t + log_db`, `log_n`, `a_n`, `data_rows` under other names, and the CFS side is already general (`zk.rs:2172` derives the slot). The **(c)** item is `a.data[off..off+512]` / `endpoints[i].data[..512]`: 512 is `tdb`, *one d-block*, and the argument binds only `lay.x[0]`. See P14 — this is the one place where a mechanical widening is unsound. |
| **A11** | `MAX_WIRE_BYTES = 32 MiB` | `zk_ffn_fresh_wire.rs:11`; refusals `zk_ffn_fresh_io.rs:507-510`, `zk_ffn_fresh_wire.rs:69-71` | **(a), but it is a ruling** | It is a decoder denial-of-service bound, not a protocol parameter: nothing absorbs it. But one Mistral layer's proof already exceeds it **before** endpoints exist — 38,688,700 B public [MEASURED, `results/hashline_hostwall_r4.log:291`] and 40,186,228 B legacy private [MEASURED, `ZK60_CLAUDE_GPU.md:262-265`]. Any fixed number is a shape pin in disguise; §7 C2 proposes the statement-derived form. |
| **A12** | `with_io` takes `t_rows` from `w.t_rows` while the caller passes `t_rows = 32` separately | `zk.rs:2354` (prover), `:3493` (verifier) against `zk_ffn_fresh_io.rs:165-175` | **(c)** | Latent today because A2 forces the two to agree. At any other shape the layout would be built for the witness's token count while the prover proves a different one — the committed slice offsets and the proven rows would disagree, which is a soundness bug, not a size pin. Fix it **before** A1 is relaxed, not after. |

**Counts: 3 capacity, 2 protocol, 6 security-relevant, 1 split
(A5).** Naming the security-relevant ones explicitly: **A1** (the guard
every other constant assumes), **A3** (the encoding rate is the
soundness parameter), **A5's non-numeric half** (the slot bound, the
mask-row count, the axis rule), **A9** (the frame's
no-attacker-controlled-length defence), **A10's plane slice** (one
d-block), **A12** (the token-count mismatch). Protocol: **A4**, **A7**.
Capacity: **A2**, **A6**, **A8**, **A11** (a ruling, not an edit).

### 2.3 Four pins the scoping memo did not find

**P12 — two sources of truth for the endpoint's PCS parameters.** The
prover's endpoint commitment uses `SeamSpec::params()`
(`private_seam.rs:99-105`), which reads `private_seam`'s own
`LOG_COLS / INV_RATE / CHECKS`. The verifier's endpoint check uses
`parameters().pcs_for(8)` (`zk_ffn_fresh_io.rs:456`), which reads the
**FFN's** `LayerParams` clamped to 8 (`statement.rs:29-31`). The two
agree today only because both happen to be `8 / 8 / 256`. Move the FFN
to `log_cols 14 / inv_rate 4` and the verifier would check a
`14/4/256` commitment the prover built at `8/8/256`. Class **(c)**;
the fix is to give `SeamSpec` the enclosing `LayerParams` and delete
the module constants.

**P13 — the endpoint plane must have power-of-two axes.**
`SeamSpec::new` refuses unless `rows` and `cols` are each a power of two
(`private_seam.rs:67-68`). The 125M shape is `T = 512, d = 768`, and
768 is not a power of two, so **the 125M endpoint plane is not
expressible at all**, independently of `MAX_LOG_LEN`. Mistral's
`d = 4096` is fine. Class **(c)**: the underlying requirement is that
the plane be a hypercube for the sumcheck, and the correct general form
is per-d-block (`tdb = T·2^log_db`, always a power of two), not
per-plane.

**P14 — a mechanical widening of A10 is UNSOUND when `nb_d > 1`.** The
argument's offsets are `[zl.lay.x[0], zl.lay.z[0]]`
(`zk_ffn_fresh_io.rs:284`) and its tables are
`a.data[off .. off + 512]` and `endpoints[i].data[..512]`
(`:301`, `:306`). In the layout, `x` is **`nb_d` blocks** of `tdb`
words each (`statement.rs:163`: `let x = vecn(nb_d, tdb)`), so
`x[0]` is only the first block. At the tiny shape and at Mistral width
`nb_d = 1` and the slice is the whole plane. At 125M `nb_d = 3` and the
seam would bind **one third of the input and one third of the output**,
while the endpoint commitment and the policy would claim the whole
plane. A prover could put anything in blocks 1 and 2. Class **(c)**,
and it is the finding of this section: §3.3 gives the fix (a
transcript-drawn `mu` batching the blocks into one claim) and §7 C6 the
test that would have caught it.

**P15 — `check_ntt` pins the NTT table to exactly `NttTables::new(12)`.**
`private_seam::prepare` refuses any other table — `max_log == 12`, 13
roots, 2,048-entry twiddles, and every root re-derived
(`private_seam.rs:164-181`) — and `prepare_endpoints` duly builds
`NttTables::new(12)` (`zk_ffn_fresh_io.rs:115`) while the FFN itself
uses `NttTables::new(16)` (`:172`, `:278`). At `log_cols 8 / inv_rate 8`
the encoded domain is 2,048 and a 12-table suffices. At
`log_cols 14 / inv_rate 4` it is **65,536**, so a 16-table is required
and `check_ntt` refuses it. Class **(b)/(c)**: the check is doing real
work (it keeps caller-supplied or malformed root tables out of the
verifier boundary), so it must be parameterised by the encoded domain,
not deleted.

## 3. The scaled geometry

### 3.1 The standing parameters, confirmed from the code

The CLI's defaults, which every model-scale run in the repository uses,
are **`log_cols 14`, `col_checks 256`, `inv_rate 4`**
(`hashline/src/bin/hashline.rs:59`). `LayerParams::pcs_for(k)` clamps
the column count to a slice's size, `log_cols.min(k)`
(`zkp-core/src/ffn_v3/statement.rs:29-31`), and the v3 layer takes
`log_n = params.log_cols.min(lay.log_a_min)` (`zk.rs:2005`). So at both
model shapes the A and H commitments run at **`n = 2^14 = 16,384`
columns, `nn = 65,536` encoded, Merkle depth 16, `Q = 256` pads**.
[COUNTED]

**Recommendation, and it is the first decision of §8: the endpoint
commitment should use the enclosing layer's parameters, not
`private_seam`'s own `8 / 8 / 256`.** Three reasons, all counted:

* it removes P12 (two sources of truth for the same commitment's
  parameters);
* it is far cheaper on the wire. At Mistral width an endpoint opening
  costs **0.90 MiB at `14/4`** against **16.1 MiB at `8/8`** — the
  `8/8` form needs 8,197 rows in each of 256 opened columns
  (`256 × 8197 × 8 B = 16.8 MB` of column data alone). [COUNTED]
* it is cheaper to commit: `69.7 MB` encoded at `14/4` against
  `134.3 MB` at `8/8`, and 65,536 columns of 133 rows hashed against
  2,048 columns of 8,197 rows. [COUNTED]

A byte sweep over `log_cols` puts the true optimum at 13 (0.895 MiB) —
within 0.8% of 14 — so matching the layer costs nothing at Mistral
width. At 125M the optimum is 12 (0.59 MiB) against 1.22 MiB at 14;
matching the layer costs ~0.6 MiB per endpoint there. [COUNTED]
*Measurement that would test this: rung R5 of
`ZK60_PRIVATE_FFN_COST_PROBE.md` §3.5 reports the exact frame length,
which is binary-independent and exact — the mr1 lane's 30 runs all
produced identical byte counts.*

The rest of §3 assumes `log_cols 14 / inv_rate 4 / Q 256` for the
endpoints. Every figure with the seam's own `8/8/256` is given where it
differs.

### 3.2 One Mistral-width layer (T 512, d 4096)

`LayoutV3::new(512, 4096, 14336)` gives `log_t = 9`, `log_db = 12`
(`nb_d = 1`), `log_fb = 11` (`nb_f = 7`), `log_a_min = 20`,
`log_n = 14`. One endpoint plane is `T·d = 2^21 = 2,097,152` words.
[COUNTED]

| | value | arithmetic |
|---|---:|---|
| plane words `N` | 2,097,152 | `512 × 4096 = 2^21` |
| endpoint **data rows** | **128** | `2^21 / 2^14` |
| endpoint mask rows | 5 | `MASK_ROWS`; one pair + prox + 2 (`nb_d = 1`, so one claim site) |
| endpoint **commitment rows** | **133** | `128 + 5` |
| encoded columns / Merkle depth | 65,536 / 16 | `2^14 × 4` |
| endpoint data / encoded bytes | 17.4 MB / **69.7 MB** | `133 × 16384 × 8` and `× 4` |
| seam sumcheck variables | **21 + 1 = 22** | `log_t + log_db = 21`, plus the extension round |
| seam sumcheck degree | 2 | `poly(v) = v0·(v1 − v2)` |
| **`L`** | **46** | `CfsMask::len(22, 2) = 22·2 + 2` |
| **`L + 256`** | **302 ≤ 512** ✓ | `mask_commit`'s assert, `zk.rs:442` |
| claims added: A / endpoint | 2 / 1 each | one per side |
| opening groups: A / endpoint | 5 → **7** / **1** each | `zk_ffn_fresh_wire.rs:43` → `:231`; the two sides' `rho` tails differ |
| A rows | 3,665 → **3,669** | `+4` (`with_io`, `zk.rs:2057-2063`) |
| M base rows | 16 → **20** | `2·slots + 4`, slots 6 → 8 |
| endpoint opening bytes | **946,176 B each** | `2·16640·16 + 256·(8 + 133·8 + 32 + 16·32)` |

All [COUNTED]. The A/H/W row counts this arithmetic produces at Mistral
width — `A 3,520 data / 3,599 legacy / 3,665 repaired`, `H 2,944 /
3,029 / 3,030`, `W 10,752` — are the same ones
`ZK60_PRIVATE_FFN_COST_PROBE.md` §1.6 reports, and the same generator
reproduces the tiny pair (681/1325) and the **measured** 125M triple
(520/559/585) exactly (§1.6).

### 3.3 The 125M shape (T 512, d 768) — and why it is the harder one

`LayoutV3::new(512, 768, 2048)` gives `log_t = 9`, `log_db = 8` with
**`nb_d = 3`**, `log_fb = 11` (`nb_f = 1`), `log_n = 14`. The input
plane is three contiguous blocks of `tdb = 512 × 256 = 2^17` words,
393,216 in total — **not a power of two**, so `SeamSpec::new` refuses
it outright (P13), and the single-slice argument would bind only the
first block (P14).

**Two general forms, and the one to build.**

*Form 1 — one seam argument per d-block.* `nb_d` arguments per side,
hence `nb_d` claim sites, `nb_d` reserved mask pairs
(`MASK_ROWS = 2·nb_d + 3`), `nb_d` CFS slots per side and `nb_d` group
vectors per endpoint opening. Correct, mechanical, and expensive: at
125M it is 6 arguments, 12 extra A rows, M base rows 16 → 28, A groups
5 → 11, and **4.01 MiB per layer** of extra proof — **+57.0%** of the
measured 125M repaired per-layer proof (7,363,039 B = 88,356,464 / 12
[MEASURED, `ZK60_FSP_MR1_PROGRESS.md` stage 4]). [COUNTED]

*Form 2 — one seam argument per side, with the blocks batched by a
transcript challenge.* After both roots are absorbed, draw
`mu = challenge_fp2_vec(nb_d)` and run the same 3-table sumcheck over
`2^(log_t+log_db)` variables on the combined tables
`Σ_c mu_c · A_c` and `Σ_c mu_c · B_c`. The A-side claim then has
`nb_d` data parts plus the same two mask parts; all `nb_d + 2` parts
share one column-weight key, which `group_zclaims` already supports
(`zkp-core/src/pcs.rs:809-831`, `zpart_weights:752-792`), so it is
**one** claim, **one** group, **one** reserved pair, **one** CFS slot
per side — identical to the tiny shape's shape at every width.

Soundness cost of form 2: if any block differs, pick a point where some
`delta_c ≠ 0`; then `Σ mu_c delta_c(x) = 0` with probability
`1/|Fp2| ≈ 2^-128` over a uniform `mu`. One extra term of `2^-128` per
side per layer, i.e. `64 · 2^-128 = 2^-122` over a 32-layer pass —
below every other term in §4. [COUNTED]

Hiding cost of form 2: none that I can see. The claim's coefficients on
the non-data rows are still exactly `(e, e·U)` on one reserved pair, so
H-pair is unchanged; the data parts only add columns to the data
rectangle, which the reduction already quotients out (§5.1).

**Recommendation: form 2.** It is the only form that keeps
`MASK_ROWS = 5`, keeps H-pair's one-pair-per-claim-site invariant
trivially true at every width, and keeps the CFS slot count at 8. At
125M it costs **1.92 MiB per layer, +27.4%** instead of +57.0%; at
Mistral width (`nb_d = 1`) it is bit-for-bit the same construction as
form 1. [COUNTED]

**The 125M geometry under form 2**, for the record:

| | value |
|---|---:|
| plane words | 393,216 = 3 × 2^17 |
| endpoint data / commitment rows | 24 / **29** |
| seam variables / degree / `L` | 17 + 1 = 18 / 2 / **38** (`38 + 256 = 294 ≤ 512` ✓) |
| A rows | 585 → **589** |
| A groups / M base rows | 5 → **7** / 16 → **20** |
| endpoint opening bytes | **733,184 B each** |

**The warning this section exists for.** The endpoint half's relative
cost runs the *opposite* way from the mask half's. The repaired masks
are 37% of A at T = 16 and 1.9% at T = 512, so a small probe overstates
them. The endpoints are **+27%** of the proof at 125M and **+6%** at
Mistral width, so a 125M probe would *overstate* them by 4.5×. Anyone
quoting an endpoint cost must quote its shape.

### 3.4 The CFS slot: L + 256 <= 512, and whether the memo's worry is real

The memo's open question was whether raising the plane cap is safe
"given that the seam's mask slot grows with the plane"
(`ZK60_PRIVATE_FFN_COST_PROBE.md` §6, could-not-determine 5). It does
grow. It grows **logarithmically**:

```
slot spec  = (log2 N + 1, 2)                zk.rs:2172  /  private_seam.rs:112-114
L          = CfsMask::len(n_vars, degree)
           = (log2 N + 1)·2 + 2
           = 2·log2 N + 4                   zkp-core/src/sumcheck.rs:197-199
constraint = L + MASK_Q <= 2^MASK_LOG_MSG
           = L + 256 <= 512,  i.e.  L <= 256    zk.rs:373, :375, :442
=>           2·log2 N + 4 <= 256   <=>   log2 N <= 126
```

| shape | `log2 N` | `L` | `L + 256` | headroom to 512 |
|---|---:|---:|---:|---:|
| tiny T32/d16 | 9 | 22 | 278 | 234 |
| 125M block (form 2) | 17 | 38 | 294 | 218 |
| **Mistral T512/d4096** | **21** | **46** | **302** | **210** |
| a hypothetical 2^40-word plane | 40 | 84 | 340 | 172 |
| the binding case | **126** | **256** | **512** | **0** |

[COUNTED]

**So the worry is real in form and empty in magnitude.** A plane would
have to hold `2^126` words — about `10^38` — before the seam slot
touched its bound. And the seam is not the binding slot anyway: at
Mistral width the layer's largest slot is `SC_ZC17`
`(log_t + log_db + 1, 4) = (22, 4)`, `L = 90`, and `SC_ZC20`
`(21, 4)`, `L = 86` — both already present in the legacy private
profile, both far inside 256. The existing gate
`tests/test_zk60_fable_cfs_channel.py:153-156` already asserts
`len + 256 <= 512` for every slot of every profile in its report; §7 C4
adds the T = 512 Mistral row to that report rather than inventing a new
check.

One caveat that is not about size: `CfsMask::sum_weights` computes
`1u64 << n_vars` (`sumcheck.rs:222-228`), which overflows above
`n_vars = 63`, i.e. `log2 N = 62`. That is a much tighter real bound
than 126, and it is a silent one. §7 C4 adds the assert.

### 3.5 Extra committed rows, proof bytes and prover cost

**Per layer at Mistral width, form 2, `log_cols 14 / inv_rate 4`:**

| what | rows | bytes | arithmetic |
|---|---:|---:|---|
| 2 endpoint commitments | **266** | — | `2 × 133` |
| A's two mask pairs | 4 | 8,192 | `256 opened cols × 4 rows × 8 B` |
| M's two extra slot row pairs | 4 | 8,192 | same |
| 2 endpoint openings | — | **1,892,352** | `2 × 946,176` |
| A's 2 extra group vectors | — | **532,480** | `2 × (16384+256) × 16 B` |
| 2 seam arguments | — | 2,240 | `2 × (1 + 22·3 + 2 + 1) × 16 B` |
| **total** | **274** | **2,443,456 B = 2.33 MiB** | |

Against the layer's existing objects: **266 / 3,669 = 7.25% of the A
commitment's rows**, **274 / 17,451 = 1.57% of all committed rows**
(`W 10,752 + A 3,669 + H 3,030`), and **+6.08% of proof bytes** against
the measured legacy private per-layer 40,174,324 B
(`1,285,578,368 / 32`, the frozen 8B private digest). All [COUNTED].

Over a 32-layer pass: **+78.2 MB of proof** (1.20 GiB → 1.28 GiB) and
**+8,768 committed rows**.

**Prover seconds — [MODEL], and this is the number most likely to move.**

1. *Endpoint commitments.* Same `n` and `inv_rate` as A, so the
   per-row cost transfers. The 125M GPU arm measured `commit A` at
   1.278 s over 12 layers of 585 rows → **1.82 × 10^-4 s/row**
   [MEASURED-derived, `ZK60_FSP_MR1_PROGRESS.md` stage 4 GPU table].
   266 rows/layer → **≈ 0.048 s/layer**, i.e. **+1.4%** of the measured
   single-Mistral-layer legacy private GPU prove of 3.453 s [MEASURED,
   `ZK60_CLAUDE_GPU.md:262-265`]. This understates the fixed part: two
   extra Merkle trees of 65,536 leaves each per layer are not
   row-proportional.
2. *The two seam sumchecks — host-only today.* 22 rounds, 3 tables of
   `2^21` Fp2, degree 2 → about `6 × 2^21 ≈ 1.26 × 10^7` Fp2
   multiply-adds per argument (`≈ 3.8 × 10^7` Fp multiplications), plus
   `eq_table_msb(tau)` of `2^21` Fp2 and ~200 MiB of table traffic.
   Two arguments ≈ **0.1 s/layer, ±2×** — **+3%** of 3.453 s. These
   are built in host memory (`zk_ffn_fresh_io.rs:299-311`) and are the
   **only large host arithmetic left in a GPU layer**, so they are the
   term that could surprise.
3. *Two extra `open_zk` passes.* 133 rows folded against
   `n + Q = 16,640`, 256 columns gathered from a 65,536-column tree.
   Small; `pcs openings` for the whole layer measured 0.361 s over 12
   layers at 125M.
4. *Transient memory.* `3 × 2^21 × 16 B = 100.7 MiB` per argument,
   matching the cost probe's `+0.100 GB` io-table term.

**[MODEL] total: about +0.15 s on a 3.453 s Mistral layer, +4.3%; about
+4.8 s on a 32-layer pass on a card that does not page.** Every part of
that is a count multiplied by a transferred constant, not a
measurement.

**What would test it.** Rung R5 of
`ZK60_PRIVATE_FFN_COST_PROBE.md` §3.5 — one Mistral layer,
`pass 1 512`, GPU, three arms (public / `--zk` / the widened io
profile) — with the three phase lines that do not exist yet and that
§7 C9 adds: `endpoint commit`, `io endpoint argument 0/1`,
`endpoint openings`. Without those three lines the endpoint half's cost
is invisible inside the aggregate. The rows and the bytes need no
quiesced box (the mr1 lane's 30 runs produced identical rows and bytes
under heavy load); only the seconds do.

## 4. Soundness at scale

### 4.1 The seam relation

The challenge field is the quadratic extension of 64-bit Goldilocks:
`p = 0xFFFF_FFFF_0000_0001 = 2^64 − 2^32 + 1`
(`zkp-core/src/field.rs:10`), `U^2 = 7` (`:15`), so
`|Fp2| = p^2 ≈ 2^127.99999999995`. Challenges are drawn by
`Transcript::challenge_fp2`, subject to the D9 reduction bias (a
**privacy** term, not a soundness one, per D9's wording correction).

Writing `m = log2 N` for the plane's bit width, the argument has two
error terms:

* **the random evaluation point.** `tau = challenge_fp2_vec(m)` is
  drawn before the sumcheck, and the claimed sum is
  `Σ_x eq(tau, x)·(A − B)(x)`, which is the multilinear extension of
  `A − B` at `tau`. If the two planes differ anywhere on the cube, that
  extension is a nonzero multilinear polynomial of total degree `≤ m`,
  so Schwartz–Zippel gives `≤ m/|Fp2|`.
* **the sumcheck itself.** `m + 1` rounds of degree 2 give
  `≤ 2(m+1)/|Fp2|` (`sumcheck::verify`, called at
  `zk_ffn_fresh_io.rs:389` with `degree = 2`, `rounds = m+1 = 10`).

| shape | `m` | `(m + 2(m+1))/|Fp2|` |
|---|---:|---:|
| tiny, T32/d16 | 9 | **2^-123.1** |
| 125M block | 17 | 2^-122.4 |
| **Mistral, T512/d4096** | **21** | **2^-122.0** |
| all 64 seams of a 32-layer pass at Mistral width | — | **2^-116.0** |

[COUNTED]. Form 2 of §3.3 adds one `2^-128` term per side per layer,
`2^-122` over the pass. **The seam's soundness is field-limited and
grows logarithmically; it is nowhere near the binding term.**

Two refusals sit inside the argument and are load-bearing rather than
cosmetic: `c = 0` discards the attempt
(`draw_mask_challenge(.., true)`, `zk_ffn_fresh_poc.rs:221-233`, called
at `zk_ffn_fresh_io.rs:293` and `:387`) and `e = 0` is rejected
(`:336-338`, `:392-394`). Both are *hiding* conditions (a zero mask
coefficient publishes an unmasked value), and both are shape-free.

### 4.2 The commitment, per opening and whole proof (D15)

Per opening, the code's own conservative Brakedown bound is
`(1 − delta/3)^Q` with `delta = 1 − (message length)/nn`
(`zkp-core/src/pcs.rs:17-19`). For a **hiding** commitment the message
length is `n + Q`, not `n` (`pcs.rs:525-528`;
`ZK60_PRIVATE_SEAM.md`, "the relevant rate is at most 1/4, not 1/8"):

| commitment | `n` | `nn` | `(n+Q)/nn` | per opening |
|---|---:|---:|---:|---:|
| the tiny endpoint, `8 / 8 / 256` | 256 | 2,048 | exactly 1/4 | **2^-106.25** |
| A, H at model scale, `14 / 4 / 256` | 16,384 | 65,536 | 0.25391 | **2^-105.61** |
| **the scaled endpoint, `14 / 4 / 256`** | 16,384 | 65,536 | 0.25391 | **2^-105.61** |

[COUNTED]. This reproduces D15's "about `2^-106`, from 256 opened
columns at encoding rate 1/4" and shows the scaled endpoint inherits it
to within 0.6 bits. **Per D15 this figure must never be quoted as the
proof's security.**

**The whole-proof figure.** D15's projection for a 32-layer 8B pass is
a commitment term near `2^-98.7` and a lookup term near `2^-94.2`,
combining to **`2^-94.14` — "about 94 bits"**
(`ZK60_FABLE_SECURITY_OBLIGATIONS.md` §5, a PROJECTION). The io profile
adds **2 commitments and 2 openings per layer, 64 openings over the
pass**:

```
64 endpoint openings      = 2^6 · 2^-105.61                     = 2^-99.61
new commitment term       = 2^-98.7  +  2^-99.61                = 2^-98.08
new whole-proof total     = 2^-98.08 +  2^-94.2                 = 2^-94.105
loss against D15's figure = 94.138 − 94.105                     = 0.03 bits
```

[COUNTED]. Adding the 64 seam sumchecks (`2^-116`) and 64 `mu` terms
(`2^-128`) changes nothing at this precision.

**So, quoted as D15 requires: the widened private feed-forward pass is
about 94 bits whole-proof (projected), the same as the legacy private
pass to within 0.03 bits; each of its ~256 openings is about
`2^-105.6`.** The endpoints are not where the security budget goes. The
open question D15 leaves — whether the product's target is per-opening
or whole-proof, and at how many bits — is unchanged by this page.

### 4.3 What relied on the plane being small

I looked for the three failure modes the brief names — a
Schwartz–Zippel term over 9 variables quoted as a constant, an
exhaustive check, a table indexed by position — and for anything else
that stops being true at `2^21`.

**Nothing of the first kind.** Every "9" and "10" in
`zk_ffn_fresh_io.rs` is `log_t + log_db` or that plus one
(`challenge_fp2_vec(9)` `:292`, `log_size: 9` `:209`,
`sumcheck::verify(.., 10, ..)` `:389`, `sum_weights(10, 2)` `:241`,
`rounds.len() != 10` `:526`, `r.argument((10,2), 2)` `:573`), and every
"8" / "256" is `log_n` / `a_n`. They are hard-coded *instances*, not
constants the argument relies on. There is no exhaustive check and no
position-indexed table anywhere on the path.

**Four things that do change with size, and their status:**

1. **The d-block assumption (P14) — a real soundness gap at
   `nb_d > 1`.** `a.data[off .. off + 512]` is one block of
   `tdb` words; the plane is `nb_d` blocks. Mechanically widening the
   512 to `T·d` would read past `x[0]` into `z[0]` and `rd[0]`; widening
   it to `tdb` would bind one third of a 125M plane. **This is the one
   place where the memo's "bookkeeping, not new cryptography" is
   wrong.** §3.3 form 2 and §7 C6.
2. **`CfsMask::sum_weights`'s `1u64 << n_vars`** overflows above
   `n_vars = 63`, i.e. `log2 N > 62` (`sumcheck.rs:222-228`). Silent.
   Add the assert (§7 C4).
3. **`MASK_ROWS = 5` gives exactly one reserved pair**, and the hiding
   argument needs one per claim site (§5.1). Under form 2 that stays
   one at every width; under form 1 it must become `2·nb_d + 3`.
4. **The Merkle depth and the column bound** (`p.len() != 11`,
   `j >= 2048`, `zk_ffn_fresh_io.rs:543`) are `log2(nn)` and `nn`.
   Capacity, but they are also the decoder's
   no-attacker-supplied-length defence, so they must be **derived from
   the checked statement** and never read from the frame (A9).

**What I could not rule out.** I did not read the bodies of
`masked_prove`, `extension`, `mask_open` / `mask_verify` or
`sumcheck::verify`; I read their call sites and their contracts. If one
of them carries its own size assumption, this section would miss it.
The natural check is `zk60_pending_layout`-style: instantiate the
widened layout and the widened specs and assert every derived count,
with no proof generated (§7).

## 5. Hiding at scale

The reference is today's joint-view report,
`ZK60_NATIVE_JOINT_VIEW.md` on branch `zk60-native-jointview`. It is a
**linear model** of the verifier's view at **two receipts' real
challenges** and it establishes **no privacy property**. Its endpoint
rows are the same construction analysed here: `private_block` builds
its endpoints through `private_seam::prepare`
(`hashline/src/private_block.rs:80`, `:375-383`), so the report's
"Input / Output" row — `rows 7, data rows 2, groups 1, rank(rho) 4,
k0 0, disclosed 0 Fp` — is this object at the tiny geometry
[MEASURED, `ZK60_NATIVE_JOINT_VIEW.md` §2.3].

### 5.1 The three hypotheses, walked at the scaled endpoint

The scaled endpoint (Mistral width, form 2, `14 / 4 / 256`): 133 rows,
128 data rows, one claim, one group, one reserved pair at rows
(128, 129), the prox row at 130, rows 131–132 uniform, `Q = 256` pads
per row, 256 opened columns of a 65,536-column coset, Merkle depth 16.

**H-pad** — *the `d` distinct sampled columns satisfy `d ≤ Q = 256`,
the nodes `x_j` are distinct and `x_j^n − 1 ≠ 0`, so the pad block is a
Vandermonde of rank `d` and the opened columns contribute nothing to
`F ∩ T`.*

`q_pad = num_col_checks = 256` by `ZkOpts::standard`
(`pcs.rs:542-544`), and exactly `num_col_checks = 256` columns are
sampled (`open_zk:928`), so `d ≤ 256 = Q` **by construction, at every
width**. The hypothesis does not mention the number of rows or the
plane length, and neither does its proof: the pad half of `E_j` is
`(x_j^n − 1)·x_j^k`, a Vandermonde in the distinct nodes, full **row**
rank for every `d ≤ q_pad` including `d = q_pad`
(`ZK60_NATIVE_JOINT_VIEW.md` §9b).

One thing *does* change, and it is worth stating because it looks
alarming and is not. At the tiny endpoint the 256 draws come from
`nn = 2,048`, so birthday collisions leave 231–246 distinct positions
and a surplus of 9–25 pads. At the scaled endpoint they come from
`nn = 65,536`, so the expected distinct count is ≈ 255.5 and the
surplus is typically **0 to 2**. That is exactly the regime the
security owner's answer 2 and the owed measurement of §9b addressed:
`q_pad = distinct = 256` was run at the receipts' own geometry and the
pad block's exact Gaussian rank was **256 of 256**, disclosing 0.
**A zero margin is sufficient; the widening removes a surplus that was
never doing work.** [MEASURED, `ZK60_NATIVE_JOINT_VIEW.md` §9b]

**H-pair** — *every claim's row weights, restricted to the non-data
rows, sit on exactly one adjacent reserved pair; that pair is used by
no other claim; its two coefficients are an Fp-basis of Fp2; and no
claim touches the proximity pair.*

The endpoint's one claim has parts at rows (128, 129) with coefficients
`e` and `e·U`, `e ≠ 0` refused (`zk_ffn_fresh_io.rs:336-338, 392-394`);
`{e, e·U}` is an Fp-basis of Fp2 for every `e ≠ 0`. The prox rows
130–132 carry no claim part. `check_masks(claims, rows, log_n,
&[128, 129], 130, tr)` re-checks the span before the opening
(`zk_ffn_fresh_poc.rs:298-306`).

**This hypothesis is the only one with a size-shaped dependency, and it
is a dependency on the number of CLAIM SITES, not on the plane.**
`MASK_ROWS = 5` provides exactly one pair. Form 1 of §3.3 would create
`nb_d` claim sites per endpoint and would need `MASK_ROWS = 2·nb_d + 3`
— and if that were forgotten, two claims would share one pair, which is
precisely the joint-view control "two claims sharing one mask pair",
brute-force disclosed **8** (`§6`). Form 2 keeps one site, one pair, at
every width. Nothing here depends on 128 data rows rather than 2.

**H-prox** — *`det(rho_prox[prox], rho_prox[prox+1]) ≠ 0`.*

`check_opening_challenges` refuses otherwise and requires
`prox + 1 < rows` (`zk_ffn_fresh_poc.rs:336-339`); at the scaled
endpoint that is `131 < 133` ✓. Shape-free.

### 5.2 What the disclosed dimension should be, and what would check it

The reduction is `disclosed = n·k0 + (u-row term)` with

```
k0 = dim { p in rowspace(rho) : p vanishes on every non-data row }
```

`rowspace(rho)` at the endpoint is spanned by the single group vector
`rho_g` and the proximity vector `rho_prox`. Take
`a·rho_g + b·rho_prox` vanishing on rows 128–132. `rho_g` is zero on
rows 130–132, and `rho_prox` is uniform there, so `b = 0` except with
probability `~3/|Fp2|`; then `a·(e, e·U) = 0` on rows 128–129 forces
`a = 0` because `e ≠ 0`. **So `k0 = 0`, and the expected disclosed
dimension at the scaled endpoint is `0` Fp — the same as measured at
the tiny geometry, for a reason that does not mention 2 or 128.**
[COUNTED, under the joint view's linear model]

On the A side the seam adds 2 claims and 2 groups, so that role's
`rank(rho)` rises from `2·5 + 2 = 12` to `2·7 + 2 = 16`; the claim
parts land on the two new reserved pairs
(`zk.rs:2090` puts `a_io`'s rows into `a_mask_rows()`), so `k0` on A
should stay 0 and the joint figure should stay "A 0, H 2 (the public
LogUp identity), Input 0, Output 0" with the CFS channel's 2 Fp
alongside — **4 Fp of public identity**, the headline of
`ZK60_NATIVE_JOINT_VIEW.md` §4 under the accepted accounting (answer 1:
a derived mask evaluation is not an independent observation).

**What the existing gate would need to check that at the scaled
geometry.** `scripts/zk60_native_joint_view.py` reads capture bundles
in the `native-all-slots-v1` schema written by
`hashline/src/native_capture.rs`, which today serves the
`private-block-t32-poc/1` and `private-attention-t32-poc/1` profiles.
Three things are needed, none of them large:

1. **A capture emitter on the io path in that schema.** The io profile
   has a capture today (`hashline/src/zk_ffn_io_diagnostic.rs`) but it
   is "a separate schema from the archived FFN captures" and
   unit-test-only (`:1-3`). Unifying it is the work.
2. **A run at the target shape.** The capture must come from an
   accepted receipt, so this is gated on the whole of §7 and on a box
   that can hold one Mistral layer — which the GPU can (§3.5 of the
   cost probe: 2.1–5.6 GB VRAM for one layer; the 32-layer pass is
   forbidden on this card).
3. **No new analysis cost.** The gate's stage-2 reduction is a rank
   over `rows` (133 for an endpoint, 3,669 for A) and a 256 × 256
   Vandermonde — both trivial. The expensive part is the Python
   transcript replay over a ~42 MiB receipt instead of a small one; the
   tiny four-capture run takes 23 s.

The capture must keep its rule of exporting **no witness plane, private
pad, mask coefficient or RNG state**, and a widened capture is an
addition to that rule's scope, not an exception to it.

### 5.3 What stays open at every size

**D8 / D11 — the caller-fixed endpoint-root obligation — is OPEN, and
the endpoints of a feed-forward-only private statement are exactly
caller-fixed roots.** That is not an analogy: `ExpectedIo` is built by
the endpoint owner *before* proving (`prepare_endpoints`,
`zk_ffn_fresh_io.rs:109-120`) and handed to the verifier out of band
(`verify(st, weights, expected, receipt)`, `:412-417`); the proof is
simulatable only if it is simulatable for roots the distinguisher may
have seen before, with its prior public history in scope. D8's proposed
closure by "two programmed points" is **retracted for any root with a
prior public opening**, and D11 records that one-use ownership does not
reduce the experiment to unopened roots, because an ordinary
authentication path or a root-child hash query can precede the sole
accepted `finish`. **Nothing on this page closes any part of that, and
widening changes nothing about it except the number of times it
applies (§6).**

Also open at every size, unchanged by this page and listed so that no
reader mistakes §5.1–§5.2 for more than it is:

* the **hash layer** — the roots, the 256 leaf salts per opening and
  the depth-16 paths are hash objects that linear algebra does not
  cover (`ZK60_NATIVE_JOINT_VIEW.md` §5);
* the **adaptive lift** — the sequential-kernel lemma's **joint**
  hypothesis stays with obligation U-3 (§9a answer 5);
* the **nonlinear link** between the PCS and CFS channels (degree up to
  4);
* **integer-range side information** — the planes are small integers
  embedded in Fp and the model treats them as free Fp values;
* **timing and every other side channel**, and the PRG assumption on
  `ZkRng`, plus D9's accepted `2^-72`-class privacy residual;
* **P3** — hidden weights — which this profile supports
  (`WeightStatement::FreshPrivate`) but which no figure here covers.

## 6. What a feed-forward-only private statement is

*Written for a reader who is not reading the code. This is the section
that decides what the widened endpoints would actually buy.*

**What one layer's proof says.** The project's feed-forward prover
proves one thing: that a specific arithmetic function was applied
correctly. Take a plane of numbers `x` — 512 tokens by 4,096 numbers
each — multiply it by two fixed weight matrices, apply the activation,
multiply the two results together, multiply by a third weight matrix,
and you get an output plane `z`. The proof says "I did that correctly",
without revealing `x`, `z`, or any of the numbers in between. The
weights are public (that is P1, D1). The witness carries exactly that:
an input plane `x`, three weight blocks, the intermediates, and an
output plane `z16` (`hashline/src/export_v3.rs:323-348`) — no norm, no
attention, no residual, nothing else.

**How the hidden planes are tied to the proof.** Before proving, an
*endpoint owner* takes `x`, commits it (a hiding commitment — a
fingerprint that reveals nothing), and does the same for `z`. The two
fingerprints, called **roots**, go to the verifier by a separate
channel as the "expected policy". The proof then shows, by the masked
sumcheck of §1.3, that the plane inside its own commitment is the same
plane as the one behind each root — without opening either. That is
what "hiding endpoints" means.

**What a 32-layer pass binds: 64 roots, not a chain.** Each of the 32
feed-forward layers has its own hidden input and its own hidden output,
and each gets its own root. So the statement of a 32-layer
feed-forward-only pass is **64 independent roots, all fixed by the
caller**, plus 32 independent proofs. There is nothing in it that says
layer 3's output has anything to do with layer 4's input.

**Why consecutive feed-forward layers do not chain.** A transformer
block is not "feed-forward, feed-forward, feed-forward". It is:
normalise, **attention**, add the input back (residual 1), normalise
again, **feed-forward**, add again (residual 2). So between layer `k`'s
feed-forward output and layer `k+1`'s feed-forward input sit *three*
operations this proof does not cover — the second residual add, the
next block's attention, and the next block's normalisations. Layer
`k`'s `z` is simply not layer `k+1`'s `x`, and no arrangement of
endpoint commitments can make it so.

> **Correction to a note in the scoping memo.**
> `ZK60_PRIVATE_FFN_COST_PROBE.md` §4.3 records, as a modelling choice,
> that "layer k's output endpoint is layer k+1's input endpoint, so a
> chain needs 33 endpoint commitments, not 64", and warns that a naive
> ×32 double-counts. **That is not true of a transformer**, for the
> reason above. The count is **64**, the naive ×32 is right, and the
> costs in §3.5 use 64. (It would also have collided with D12 rule 1
> if it were true: sharing one root between two proofs is the
> double-opening configuration D11 shows recovers the hidden words.)

**Who fixes each root, and why that is the whole problem.** The
verifier cannot compute a root itself — computing it needs the hidden
plane. So every one of the 64 roots arrives from outside the proof: the
prover's side, the requester, or a third party. The proof says "the
plane behind this root went through the feed-forward correctly". It
says nothing about *where that root came from*. The seam module states
this plainly about itself: "recommitting a copy of an existing FFN
output without proving consistency does not connect this gadget to that
FFN" (`hashline/src/private_seam.rs`, module doc, and
`ZK60_PRIVATE_SEAM.md`). Authenticating the roots is the enclosing
application's job, and it is exactly the job nothing in the repository
does yet.

**How much of the D8/D11 obligation such a statement carries: all of
it, 64 times.** D8's standing obligation is that a proof must be
simulatable for endpoint roots the caller fixed, with the
distinguisher's prior public history in scope; D11 records that the
one-use owner does not reduce this to the easy case of an unopened
root. Every one of the 64 roots of a feed-forward-only pass is a
caller-fixed root of exactly that kind. Nothing about widening the
planes touches the obligation — it multiplies the number of instances
and leaves the argument where it is. **A widened feed-forward pass with
hiding endpoints would be an engineering milestone and a cost
measurement; it would not be a privacy acceptance, and no page should
describe it as P1 without D8/D11 beside it.**

**Where this sits against D12 and D13.**

* Under **D12**, a *block* is one proof, one transcript, exactly two
  external endpoints (its hidden input `x_in` and its hidden output
  `xres2`), with every hidden intermediate living on commitments that
  one proof generates itself. A 32-layer feed-forward-only pass is the
  opposite shape: 32 proofs, 32 transcripts, 64 external endpoints.
  **It is not a block and must not be called one.** It does satisfy
  D12's hard rules trivially — no commitment is opened twice, and no
  hidden intermediate gets a root shared between two proofs — because
  nothing is shared at all.
* Under **D13**, the first MVP is the *hidden transformer blocks*. The
  block is the MVP object; the feed-forward pass is the **throughput**
  object, because the target contract's clock covers the feed-forward
  blocks. So the right description of this work is: *the feed-forward
  pass is what we speed up and measure; the composed block is what we
  claim privacy for.* Widening the endpoints serves the first, and is
  a prerequisite for the second only in the sense that the block will
  need the same machinery at real widths.
* **Two D12 conditions bite this statement directly.** Rule 4: the
  feed-forward prover proves **no range on its own input plane** (its
  lookups cover the activation, the two int16 planes and the output,
  never the input). With a *public* input that is harmless — the
  verifier can look. With a **hidden** input it is not: the statement
  admits an out-of-class input plane. Rule 5: the declared endpoint
  scales (`IoSpec`'s `input_scale`, `output_scale`) are
  transcript-bound but prove nothing about calibration, so a
  scale-equality check would pass on a factor-of-8 mismatch.

**In one sentence.** A feed-forward-only private pass would prove
*"thirty-two feed-forward computations were each done correctly on some
hidden plane somebody committed to"* — which is worth measuring and
worth building toward, but is neither one inference, nor a block under
D12, nor a discharge of D8/D11.

## 7. The change list, smallest first

**The standing condition governs the whole list: the tiny private-IO
entry points stay pinned.** `PROFILE = b"hashline-zk-mr1/ffn-v3-mr1-fresh-io-poc/2"`
(`zk_ffn_fresh_io.rs:12`), its absorbed parameter literal (`:141-144`),
`IoSpec::seams`'s `(32, 16)` (`:40-41`) and `ExpectedIo`'s
`rows: 7, log_cols: 8` (`:58-68`) are not edited. Everything general is
a **new entry pair beside them**, the way the mask half did it with
`prove_layer_zk_v3_mr1` / `verify_layer_zk_v3_mr1`
(`ZK60_FSP_MR1_PROGRESS.md` stage 2: 265 tests, 12 of 12 byte gates,
**no digest moved**).

| # | change | pins | class | file(s) | moves a proof byte or a frozen digest? | test that must accompany it |
|---|---|---|---|---|---|---|
| **C1** | pass the prover's `t_rows` into `with_io` instead of reading it from the witness | A12 | (c) | `hashline/src/zk.rs:2354`, `:3493` | **No.** At the tiny shape A2 forces the two equal, so every byte is identical | a layout test (no proof generated) that a witness with `w.t_rows != t_rows` is refused at both the prover and the verifier entry |
| **C2** | replace `MAX_WIRE_BYTES`'s fixed 32 MiB with the **statement-derived exact length** plus one absolute ceiling | A11 | (a), **and a ruling** | `hashline/src/zk_ffn_fresh_wire.rs:11`, `:69-71`; `zk_ffn_fresh_io.rs:507-510` | **No** — the constant is nowhere absorbed | `fixed_wire_bounds_cover_all_allowed_table_sizes` (`zk_ffn_fresh_wire.rs:418-473`) stays green unchanged; new: a statement above the ceiling is refused, and a frame one byte off the derived length is refused |
| **C3** | derive the witness plane lengths (`T·d`, `T·f`, `d·f`) and the endpoint plane shape from the statement | A2, A6 | (a) | new module beside `zk_ffn_fresh_poc.rs` / `zk_ffn_fresh_io.rs` | **No** (new entry points only) | witness-length negatives at the new shape: short plane, long plane, non-canonical word — the tiny analogues are `zk_ffn_fresh_io_tests.rs:160-161` |
| **C4** | `SeamSpecG`: plane bound becomes the two real ones — `L + 256 <= 512` (assert it, `zk.rs:442`) and `log2 N <= 62` (`sum_weights`'s `1u64 << n_vars`, `sumcheck.rs:222-228`) — and `MASK_ROWS` becomes `2·claim_sites + 3` with an assert | A5 | (a) for the 4,096; **(c)** for the slot, the mask rows and the axis rule | new type beside `hashline/src/private_seam.rs`'s `SeamSpec` | **No** (the existing `SeamSpec` is untouched) | extend `tests/test_zk60_fable_cfs_channel.py` (its `len + 256 <= 512` loop at `:153-156`) with the **T = 512 Mistral** row; a unit test that `log2 N = 63` is refused |
| **C5** | the endpoint takes the **enclosing `LayerParams`** and the matching `NttTables`, deleting the module's private `LOG_COLS / INV_RATE / CHECKS` for the general path | P12, P15, A3 | **(c)** | `private_seam.rs:28-36`, `:99-105`, `:164-181`; `zk_ffn_fresh_io.rs:115`, `:456` | **No** for existing paths; the general path is a new profile | a test that prover and verifier derive the *same* `PcsParams` from one source; a negative where they are made to differ and the opening is refused; `check_ntt` accepts the 2^16 table and still refuses a tampered root table |
| **C6** | the **`mu`-batched multi-block seam** (§3.3 form 2): draw `mu` after both roots are absorbed, batch the `nb_d` d-blocks into one claim with `nb_d` data parts | **P14**, A10's slice | **(c)** — this one is a soundness fix, not plumbing | the new io module | **No** (new profile) | **the test that would have caught P14**: at a shape with `nb_d = 3`, tamper one word in block 0, then block 1, then block 2, and require rejection in all three. A naive widening passes 1 and 2 |
| **C7** | derive the policy shape, `ENDPOINT_OPEN_BYTES`, the frame lengths and every receipt shape check from the checked statement | A7, A8, A9, A10 | (b) for the policy, (a) for the lengths, **(c) for A9** | the new io module and its wire | **No** (new profile) | every A9 bound re-pinned as a *derived* value and never read from the frame: the truncation, extension, bit-flip, out-of-bounds-index and non-canonical-word batteries of `zk_ffn_fresh_io_tests.rs:187-314`, re-run at the new shape |
| **C8** | the new entry pair and the new domain: `PROFILE .../3`, a parameter literal carrying `(T, d, f, log_cols, inv_rate, Q, nb_d)`, `prepare_endpoints_general`, `prepare_general`, `verify_general`, `verify_bytes_general` | A1, A4 | **(b)** | new module | **No for existing bytes, by construction** — a new tag means the widened profile cannot be confused with `/2` | the `compile_fail` doctest that a second `finish` does not type-check, copied to the new `PendingProof`; a test that a `/2` receipt is refused by the `/3` verifier and vice versa (the tiny analogue is `zk_ffn_fresh_io_tests.rs:301-303`) |
| **C9** | three new phase lines: `endpoint commit`, `io endpoint argument 0/1`, `endpoint openings` | — | (a) | the new io module, `hashline/src/phase_profile.rs` | **No** | the probe driver prints all three and they sum into the total, as the mr1 lane's eleven-phase attribution did (it closed to 0.000 s) |
| **C10** | offer the endpoint commitments to the device, and lift the examples' blanket GPU refusal behind a CPU/GPU parity gate | B3 of the memo | (a) | `private_seam.rs:215` already calls `pcs::commit_zk`; `hashline/examples/zk60_fresh_ffn.rs:87-89`, `zk60_bound_ffn.rs:67-69` | **No** (the profile draws fresh randomness, so there is no byte to move) | CPU/GPU parity at the **tiny** shape first: same statement, same policy, both binaries accept each other's receipts |

**Verifier-side tamper tests the brief names, and where they stand.**

| requirement | at the tiny shape today | owed at the new shape |
|---|---|---|
| an endpoint committing a **different plane** must be rejected | **exists** — `bound_ffn_refuses_recommitted_wrong_input` / `_output` (`zk_ffn_fresh_io_tests.rs:108-138`), which recommits the wrong plane and uses its **real** root, so no stale hash explains the refusal | re-run at the new shape, **once per d-block** (C6) |
| a proof against a **different root** must be rejected | **exists** — the six relabelled policies at `:284-300` (input root, output root, context, both scales, swapped roles) | re-run; add a policy whose `rows`/`log_cols` differ from the statement's derived shape (new, because the shape stops being a constant) |
| a **second use of an owner** must be refused | **exists** — `finish` consumes both owners by value (`:276`), pinned by the `compile_fail` doctest (`:125-131`), plus the runtime mismatch test `bound_ffn_consumes_mismatched_owner_and_checks_slot` (`:170-184`) | copy both to the new entry points |
| a **duplicated or role-swapped** endpoint opening must be rejected | **exists** — `:216-228` | re-run |
| the repaired **refusals** (`check_masks`, `check_opening_challenges`, `check_table_point`, `draw_mask_challenge`) | exist and are shape-general in form (`zk_ffn_fresh_poc.rs:221-341`) | **record any refusal that fires and stop; never re-run for fresh randomness** — that is the resampling the design forbids |

**The acceptance check at 12 × 512, before anything wider is
attempted.** This is the gate, in order:

1. `python3 -m unittest discover -s tests` plus freeze-check, green.
2. The **four frozen digests at 12 × 512 unmoved** — `v2 50cf7bdf..`
   66,844,928 B, `v3 5f368db6..` 70,758,084 B, `zk 021485e4..`
   87,228,528 B, `zk-v3 40eb5479..` 87,697,008 B — and the **twelve
   byte gates** (four fixtures × CPU / GPU / GPU force-chunked) green,
   exactly the floor the mr1 lane held (`ZK60_FSP_MR1_PROGRESS.md`
   stage 1–2). **A moved digest is a bug in the change, not a cost of
   privacy: revert and record.**
3. The 8B digests unmoved: public
   `dc980e81…4536c` / 1,234,936,956 B and legacy private
   `930ce9a0…c982e` / 1,285,578,368 B.
4. An **honest accept** of the widened io profile at 12 × 512 with
   `nb_d = 3`, with its counted geometry reproduced exactly: endpoint
   rows **29**, A rows **589**, A groups **7**, M base rows **20**,
   seam slot **(18, 2)** with `L = 38`, and the per-layer byte delta
   **2,017,088 B**. Rows and bytes are exact and load-independent — the
   mr1 lane's 30 runs under heavy load produced identical ones — so
   this rung does **not** need a quiesced box.
5. Every tamper test above, green, including the three per-block
   tampers of C6.
6. A **joint-view capture at that shape**, run through
   `scripts/zk60_native_joint_view.py`, reporting `Input 0 / Output 0`
   and `k0 = 0` with every negative control firing (§5.2). This is the
   check that the widening did not quietly break H-pair.
7. Only then the Mistral-width rung (R5 of the cost probe), GPU, one
   layer, card verified idle, detached, never chained.

## 8. Decisions, open obligations, and what I did not check

### 8.1 Decisions for the security owner

**1. Should the widened endpoint commitment use the enclosing layer's
`LayerParams` (`log_cols 14 / inv_rate 4 / Q 256`) instead of
`private_seam`'s own `8 / 8 / 256`?**
*Recommend yes.* It removes P12's two sources of truth for one
commitment's parameters, cuts a Mistral endpoint opening from 16.1 MiB
to 0.90 MiB, and costs 0.6 bits per opening (`2^-106.25` → `2^-105.61`).

**2. Form 1 (one seam argument per d-block) or form 2 (one argument per
side, blocks batched by a transcript-drawn `mu`)?**
*Recommend form 2.* It keeps `MASK_ROWS = 5`, one reserved pair and one
CFS slot per side at every width — so H-pair's one-pair-per-claim-site
invariant cannot be broken by a later widening — and halves the 125M
byte cost (+27.4% against +57.0%) for one `2^-128` term.

**3. `MAX_WIRE_BYTES`: raise the constant, or make the bound
statement-derived with one absolute ceiling?**
*Recommend statement-derived plus a ceiling.* Any fixed number is a
shape pin in disguise — the present 32 MiB is already smaller than one
Mistral layer's **existing** proof (38.3 MiB legacy private,
[MEASURED]), before an endpoint byte exists.

**4. Does a 32-layer feed-forward-only pass with hiding endpoints get
to be described as P1?**
*Recommend no, and that the phrase be fixed now rather than after the
build.* Its 64 caller-fixed roots are exactly D8/D11's open case, and
§6 shows the pass is not one inference and not a block under D12. The
honest label is "feed-forward blocks only, endpoints caller-fixed,
D8/D11 open".

**5. Is the widened endpoint half worth building at all before the
composed block lands?**
*Recommend building it as the cost and machinery vehicle, on the
explicit understanding of decision 4.* The block (D12, D13) will need
exactly this machinery at real widths, and today nothing in the
repository has ever run a hiding endpoint above 512 words.

**6. Should a joint-view capture at the widened geometry be a hard
acceptance gate for C3–C8?**
*Recommend yes.* It is cheap (the analysis is a rank over 133 rows and
a 256 × 256 Vandermonde) and it is the only mechanical check that the
widening did not break H-pair — which is the one hypothesis with a
structural dependency (§5.1).

**7. At the widened endpoint should `q_pad` be `num_col_checks + 1`
rather than `num_col_checks`?** The reason given for declining this on
2026-09-19 was that `ZkOpts::standard` is shared with frozen paths; a
**new** profile would not be. *Recommend still no.* §9b measured that a
zero margin suffices (rank 256 of 256 at the receipts' real geometry),
so the extra pad buys nothing and would create a second `ZkOpts`
variant to keep straight.

**8. May the endpoint commitments be offered to the GPU?** They never
have been — both repaired examples refuse the device outright
(`zk60_fresh_ffn.rs:87-89`, `zk60_bound_ffn.rs:67-69`).
*Recommend yes, behind a CPU/GPU parity gate at the tiny shape first*
(C10); otherwise the two 133-row commitments are host work inside an
otherwise device-resident layer.

**9. A11 aside, is anything here a ruling for Victor rather than for
the security owner?** *Recommend one:* the D15 question of whether the
product's soundness target is per-opening or whole-proof is now
slightly *more* pressing, because the io profile adds 64 openings to an
8B pass for 0.03 bits — a decision framework that quotes per-opening
figures would call that free, and one that quotes whole-proof figures
would call it 0.03 bits. Neither is wrong; only one is the product's.

### 8.2 Open obligations

1. **D8 / D11 — caller-fixed endpoint roots. OPEN**, and a
   feed-forward-only pass carries the full obligation 64 times (§6).
   Nothing on this page reduces it.
2. **U-3 — the sequential-kernel lemma's joint hypothesis.** Fixed
   challenges do not lift to the adaptive view without it
   (`ZK60_NATIVE_JOINT_VIEW.md` §9a answer 5).
3. **The hash layer** — roots, salts, depth-11/16 paths — assumed
   (salted-leaf hiding), not shown.
4. **D12 rule 4** — the feed-forward prover proves no range on its own
   input plane, so a *hidden*-input feed-forward statement admits an
   out-of-class input. This is owed by the widened profile, not by the
   endpoints.
5. **D12 rule 5** — the declared endpoint scales are transcript-bound
   but prove nothing about the approved calibration.
6. **D15** — the whole-proof target itself (how many bits, and whether
   the figure is per-opening or whole-proof) is still Victor's ruling.
7. **P14 is a live soundness gap in any mechanical widening.** It is
   not a gap in the code as it stands, because A1 refuses every shape
   with `nb_d > 1`. It becomes one the moment A1 is relaxed without
   C6.
8. **The endpoint half has never been executed above 512 words**, so
   every refusal in §2 is shape-general *in form* only — the mask
   half's analogous claim was only settled when it was run
   (`ZK60_FSP_MR1_PROGRESS.md`: "it does").

### 8.3 What I did not check

* **I ran nothing.** No build, no cargo, no proof, no test, no
  benchmark, no GPU. Every count is arithmetic over the source; every
  second is a model.
* **Bodies I did not read**: `masked_prove`, `extension`,
  `mask_open` / `mask_verify`, `sumcheck::verify`,
  `Transcript::challenge_*`, `MerkleTree`, `hashline/src/layer.rs`,
  `private_block/*` and `private_attention/*` beyond the greps quoted.
  I read their call sites and contracts. A size assumption inside one
  of them would be missed by §4.3.
* **The tiny row counts are reproduced arithmetically**, not by running
  `zk60_pending_layout`; they are cross-checked against the committed
  assertions (702 / 1326 / 20 / 7 groups / `[(10,2); 2]`,
  `zk_ffn_fresh_io_tests.rs:41-83`) and against the mr1 lane's measured
  125M rows, and they agree exactly.
* **I did not verify D15's projection** (`2^-98.7` commitment,
  `2^-94.2` lookup); I reused it and added the endpoint term to it.
* **The `mu`-batched seam (form 2) is a paper proposal.** No code, no
  test, no independent check; its soundness sketch is three lines long
  and its hiding claim is an argument by inspection of the claim's
  coefficients. It is the first thing an independent check should
  attack.
* **I did not check the device path** for endpoint commitments, nor
  whether `pcs::commit_zk` at 133 rows × 16,384 columns behaves on the
  4070's kernel-shape gate.
* **I did not check the proof-byte model against a real widened
  receipt** — it reproduces one Mistral layer's measured 38.3 MiB to
  about 2%, which is reassurance, not verification.
* **I did not coordinate with Codex's live tree.** `git status --short`
  showed `zk.rs`, `private_seam.rs`, `zk_ffn_fresh_*.rs`, `pcs.rs`,
  `layer.rs` and `bin/hashline.rs` all clean at the time of writing;
  re-check immediately before any of §7 is started, and check the
  tranche ledger for `zk.rs`'s current lane owner (it was
  `fsp-mr1`'s).
* **I did not price the alternative** of leaving the endpoints at the
  tiny shape and reaching P1 by the composed private block
  (D12/D13) instead. That comparison belongs in the block construction
  memo, and it may well be the cheaper road.

---

*(draft complete)*
