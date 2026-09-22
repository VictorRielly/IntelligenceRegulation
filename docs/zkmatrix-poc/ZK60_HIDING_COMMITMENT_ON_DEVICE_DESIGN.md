# The hiding commitment on the device — a design offer to the integrator

By a delegated Claude Fable 5.1 design drafter for the security owner,
2026-09-22. **This memo changes no production code and ran nothing on a
GPU.** It is the security owner's OFFER to the work item the integrator owns
("keyed CUDA and device-buffer review"): what a device version of the hiding
commitment must compute byte for byte, what it costs in bytes, how it fits
the two cards, what must be read before the toy privacy statement's argument
can be said to cover the device path, and how byte identity would be proved.
It is not a patch, not a schedule, and not a performance claim.

Every number carries a label: **[MEASURED]** only from a committed log, with
its path; **[COUNTED]** from the code or the shape, by the script committed
under `results/zk60_device_commit/`; **[MODEL]** anything estimated. No
number in this memo is a prediction of a proving time.

## Sections

1. The byte-level contract — what `commit_zk_owned_with_tag` computes, in order
2. The counts at 125M and at rung-W14
3. Device memory: the 8 GB card and the 32 GB card
4. The keyed kernels: what changes, and where
5. Blinding material on the device — what must be read before the statement extends
6. Proving byte identity without deterministic receipts
7. What it does not buy
8. A staged plan, with owners and risks
9. What this memo is not

## 1. The byte-level contract

**Read this section as the acceptance list for a kernel.** A device
implementation of the hiding commitment is byte-identical if and only if it
reproduces every step below in this order, and a reviewer can check a kernel
against it line by line. Everything here is [COUNTED] — read out of the
source text, not measured. The text is `zkp-core/src/pcs.rs` in the lane
worktree `/home/victor/wt-zk60-block125m` at `a8e4939`; the function is
`commit_zk_owned_with_tag` (`:769-808`), and the legacy rule is its
untagged twin `commit_zk_owned_with` (`:716-751`), which keeps its own body.

The parameters: `n = 2^log_cols` (the message width), `nn = n · inv_rate`
(the encoded width), `rows`, `Q = zk.q_pad`, `h = zk.coset`. At 125M and at
rung-W14: `n = 2^14`, `inv_rate = 4`, `nn = 2^16`, `Q = 256`,
`num_col_checks = 256`, `h = Fp(7)`.

### Step 0 — the preconditions

`data.len() % n == 0`, `data` non-empty, `Q >= num_col_checks`;
`rows = data.len() / n` (`:773-775`). The field is Goldilocks
`p = 2^64 - 2^32 + 1` (`field.rs:10`), and **every value is stored in
canonical form, always `< p`** (`field.rs:8`), which is what makes the byte
image of a column well defined at all.

### Step 1 — the pads (the FIRST draw, before any branch)

`pads = rng.fp_vec(rows · Q)` (`:777`). `rows · Q` successive `fp()` draws
in row-major order: `pads[i·Q + k]` is pad symbol `k` of row `i`. One `fp()`
is **two** `next_u64()` calls — 16 little-endian stream bytes — reduced as
`((hi as u128) << 64) | lo` mod `p` (`rng.rs:73-77`).

### Step 2 — the salts (the SECOND draw)

`salts = (0..nn).map(|_| rng.bytes32())` (`:778`). `nn` successive
`bytes32()` draws in increasing column order; one `bytes32()` is **four**
`next_u64()` calls written little-endian into the 32 bytes in order
(`rng.rs:93-99`). `salts[j]` belongs to encoded column `j`.

**Steps 1 and 2 happen before the accelerator is offered anything, on every
path, under both rules.** The function's own doc comment says why: "so the
generator's byte order is the same under both rules and a tag never moves a
random draw" (`:756-758`). A device version inherits that obligation
unchanged — the pads and salts are drawn on the HOST, in this order, and
then whatever is uploaded is uploaded. **Which receipt bytes depend on which
draw:** the salts reach the transcript-facing bytes twice — as the 32-byte
salt of each of the 256 opened columns, in the clear, and through every
salted leaf and therefore the root; the pads reach them only through the
encoded columns (the 256 opened columns' entries) and through the `Q` pad
entries of each clear vector. No other receipt byte depends on either draw.

### Step 3 — the coset powers

`pows[i] = h^i` for `i < nn`, built by repeated multiplication from `Fp::ONE`
(`coset_powers`, `:642-651`), with the assertion `h^nn != 1` — the coset
must not meet the subgroup.

### Step 4 — the accelerator offer, and today's decline

`tag.column_key()` is consulted: `None` (legacy) offers
`backend.try_commit_zk(params, data, &pads, &pows, ntt)`; `Some(_)`
(tagged) passes `None` and runs the CPU body (`:782-785`). This is D19
ruling T-8. The reason is in the code: the device kernel "is a hand-written
BLAKE3 with the IV hard-coded and no key input, so it can only produce
UNKEYED column digests; offering the work to it would silently return the
wrong leaves. This is a **TEMPORARY CPU FALLBACK, recorded as such** — not
accelerator support, and not a performance result" (`:760-768`).

### Step 5 — the row encoding (`encode_row_zk`, `:655-674`)

Per row `i`, with `msg = data[i·n .. (i+1)·n]` and `pad = pads[i·Q ..
(i+1)·Q]`, into an `nn`-long output:

| # | operation | source |
|---|---|---|
| 5a | `coeffs = msg.to_vec()` | `:660` |
| 5b | `ntt.inverse(&mut coeffs)` — size-`n` inverse NTT | `:661` |
| 5c | `out[..n] = coeffs`; `out[n..] = 0` | `:662-665` |
| 5d | for `i < Q`: `out[i] -= pad[i]`; `out[n+i] = pad[i]` | `:666-669` |
| 5e | for `i < n+Q`: `out[i] *= pows[i]` | `:670-672` |
| 5f | `ntt.forward(out)` — size-`nn` forward NTT | `:673` |

5d is `f = f_data + Z_n · g_pad` with `Z_n(x) = x^n − 1`: the pad
coefficients appear negated at degrees `0..Q` and positively at degrees
`n..n+Q`. 5e is the coset shift, so 5f evaluates `f` on `h · G_nn`, which is
disjoint from `G_n` — **no evaluation position is systematic**, and that is
the whole hiding property of the encoding.

**The four ways a device NTT gets this wrong while still looking right.**
This is the part of the contract I would flag hardest to the integrator.

1. **Output ordering.** `transform` (`ntt.rs:69-108`) applies the
   bit-reversal permutation to the **input** and leaves the output in
   **natural order**. A device NTT that returns a bit-reversed (decimation-
   in-frequency) output permutes the columns. Every column digest is then a
   digest of the right bytes at the wrong index, the tree is over a permuted
   leaf array, the root differs, and nothing about the *values* is wrong.
2. **The root of unity.** `Fp::two_adic_root(k)` is
   `(7^((p−1)/2^32))^(2^(32−k))` (`field.rs`, `two_adic_root`). Another
   primitive root of the same order is an equally valid RS code and a
   different codeword.
3. **The twiddle indexing.** `tw[k · (max_n / len)]` where `max_n =
   2^max_log` is the size of the **shared** table, not of this transform
   (`ntt.rs:93,98`). A device that precomputes per-size tables must land on
   the same values.
4. **The inverse scaling.** `inverse` multiplies every entry by
   `Fp::new(n).inv()` **after** the transform (`ntt.rs:60-67`) — `n`, the
   size of *that* transform, not `nn`.

All four are caught by the CPU verifier (§6), and none is caught by "the
kernel ran and produced a root".

### Step 6 — the column digest

For each column `j < nn`, the message is the concatenation over
`i = 0 .. rows` **in increasing row order** of `encoded[i·nn + j]`'s eight
little-endian bytes (`Fp::to_bytes` is `u64::to_le_bytes`, `field.rs:88`):
`rows · 8` bytes, hashed in **one** BLAKE3 call.

* legacy: unkeyed. `hash_columns` (`:157-175`) tiles 64 columns at a time
  and uses the one-shot `blake3::hash`; the verifier's `hash_column`
  (`:138-144`) builds a `Hasher` and does one `update`. Same bytes, same
  digest.
* tagged: BLAKE3 **keyed mode** under `tag.column_key()`
  (`hash_columns_keyed`, `:182-202`). The keyed body builds a hasher per
  column because "keyed mode has no equivalent" of the one-shot fast path
  (`:177-181`).

### Step 7 — the salted leaf

`leaf[j] = H(column_digest[j] ‖ salts[j])` — 64 bytes, as two 32-byte
updates in that order (`salt_leaf`, `:677-682`; `salt_leaf_keyed`,
`:691-696`, under `tag.leaf_key()`).

### Step 8 — the tree

`MerkleTree::build_keyed(salted, tag.node_key())` (`merkle.rs:52-65`):
`levels[0]` is the `nn` salted leaves **in column order**; each next level is
`H(left ‖ right)` over consecutive pairs — 64 bytes again — until one
element remains. The root is `levels.last()[0]`. Depth is `log2(nn)` = 16 at
both 125M and rung-W14. Legacy uses `MerkleTree::build` and the unkeyed
`hash_pair` (`:34-48`, `:14-19`).

### Step 9 — what the commitment keeps

`CommittedZk { cm: Committed { params, rows, store, tree }, zk, data, pads,
salts, mask_rows: [], prox_mask_row: None }` (`:799-807`). `store` is either
`Store::Host { encoded }` — the whole `rows × nn` encoded matrix, row-major —
or `Store::Device(dc)`, the backend's own resident form (`:81-84`). **The
encoding stays resident until the opening**, because `open_zk` gathers its
256 columns out of it.

### Step 10 — the opening (`open_zk`, `:1023-1052`)

Transcript order: group lambdas → the clear vectors absorbed under
`b"pcs-vec"` → the proximity rho → the prox vector absorbed under
`b"pcs-prox"` → `tr.challenge_indices(num_col_checks, nn)`, the 256 column
indices, **drawn with replacement**. For each sampled `j`, in sampled order,
the opening carries `(j, col, salts[j], tree.path(j))` where `col` is
`encoded[i·nn + j]` for `i = 0..rows` and `path(j)` is the sibling digests
from the leaf level up — `levels[l][i ^ 1]`, `i >>= 1` (`merkle.rs:76-84`) —
`depth` of them.

The wire image (`OpeningZk::write_bytes`, `:619-638`): every group vector's
`Fp2` entries (16 B each, `c0` then `c1`, little-endian), then the prox
vector, then per opened column `(j as u64).to_le_bytes()` (8 B), the `rows`
column entries (8 B each), the 32-byte salt, then the `depth` path digests.

### The legacy rule beside the tagged one — exactly what differs

I checked this claim rather than repeating it. **Only the hash functions
differ**, at three sites:

| site | legacy | tagged |
|---|---|---|
| column digest | unkeyed BLAKE3 | keyed under `tag.column_key()` |
| salted leaf | unkeyed BLAKE3 | keyed under `tag.leaf_key()` |
| Merkle inner node | unkeyed BLAKE3 | keyed under `tag.node_key()` |

Everything else is the same text: the draw order (steps 1-2), the encoding
(step 5), the byte layouts (steps 6-8), the tree shape, the opening and the
wire format. Two things that are **not** part of `commit_*` but travel with
the rule: the Fiat–Shamir transcript has its own fourth key
(`tag.transcript_key()`, `hashtag.rs:117-123`), and `verify_zk_tagged`
additionally checks that every Merkle path has exactly `log2(nn)` entries
(`:1188-1195`) — the length check `verify_zk` does not make. The keys
themselves are `blake3::derive_key(<context>, profile)` for the four fixed
context strings (`hashtag.rs:46-53, 92-101`), derived by the caller from the
profile it trusts and **never read out of a receipt** (ruling T-7).

Under the legacy rule a salted leaf and an inner node are *the same BLAKE3
call on the same 64 bytes*. That is the ambiguity D19 exists to remove, and
it is a fact a device implementation must not reintroduce by, say, hashing
leaves and nodes with one shared kernel entry point that takes no key.

## 2. The counts at 125M and at rung-W14

Everything in this section is [COUNTED] by
`results/zk60_device_commit/count_hiding_commit.py`, whose output is
committed beside it (`count_hiding_commit.log`, `counts.json`). The script
derives the counts from the contract in §1 and the shapes in the lane's own
layout models (`results/zk60_block125m_lane/model_{m125,rung_w14,toy}.json`
in the lane worktree), then **rebuilds each shape's receipt from them and
compares with the model's total** — the number `grow_tests.rs:708-727`
asserts part by part and the proof logs report. All three shapes reconcile
digit for digit:

| shape | counted receipt | model / asserted |
|---|---:|---:|
| 125M | 40,783,352 | 40,783,352 |
| rung-W14 | 16,421,048 | 16,421,048 |
| toy | 2,816,472 | 2,816,472 |

and so do all six parts of each (`a_opening`, `h_opening`,
`endpoint_openings`, `mask_opening`, header, slots). That reconciliation is
the evidence that §1 describes the commitment the prover actually makes.

**First correction to the framing of this memo's own brief: a private block
makes FIVE hiding commitments, not two.** `A`, `H`, two endpoint
commitments (37 rows each at 125M, 9 at rung-W14, at the same `n` and rate)
and the fixed-shape mask commitment `M` (50 rows over `2^12` columns,
`wire.rs:17-19`). `A` and `H` are 99.4% of the committed bytes at 125M, so
the memo is about them — but a device path that serves only `A` and `H`
leaves three commitments on the CPU, and that is an Amdahl term (§7).

### 2.1 Per commitment, at 125M

| | `A` | `H` | endpoint (each) |
|---|---:|---:|---:|
| rows | 5,681 | 7,120 | 37 |
| claim groups | 36 | 9 | 1 |
| systematic data held (rows × n × 8) | 744,620,032 B | 933,232,640 B | 4,849,664 B |
| pad rows held (rows × Q × 8) | 11,634,688 B | 14,581,760 B | 75,776 B |
| **encoded matrix (rows × nn × 8)** | **2,978,480,128 B** (2,840.5 MiB) | **3,732,930,560 B** (3,560.0 MiB) | 19,398,656 B |
| **column bytes hashed** | **2,978,480,128 B** | **3,732,930,560 B** | 19,398,656 B |
| leaf hash input (nn × 64) | 4,194,304 B | 4,194,304 B | 4,194,304 B |
| inner nodes | 65,535 | 65,535 | 65,535 |
| salts (nn × 32) | 2,097,152 B | 2,097,152 B | 2,097,152 B |
| whole tree (2·nn−1 digests) | 4,194,272 B | 4,194,272 B | 4,194,272 B |
| random stream bytes (pads + salts) | 25,366,528 B | 31,260,672 B | 2,248,704 B |
| **sent: opened columns** | **11,776,000 B** | **14,723,072 B** | 217,088 B |
| sent: clear vectors | 9,850,880 B | 2,662,400 B | 532,480 B |
| **sent: total** | **21,626,880 B** | **17,385,472 B** | 749,568 B |

The four commitments together at 125M: **6,750,208,000 B (6.29 GiB) of
encoded matrix, every byte of which is hashed exactly once** into a column
digest, and 61,124,608 B of random stream.

**That 6.29 GiB is the counted twin of the measured 6.4 GiB.** The lane's
measured figure is the prover's resident-set growth across the two hiding
commitments [MEASURED, `results/zk60_block125m_lane/q28-m125-final-dense.log`
in the lane worktree]; `A` and `H`'s encoded matrices alone count to
6,711,410,688 B = 6.25 GiB. The resident set the hiding commitment buys is
the encoded matrices and essentially nothing else.

### 2.2 Where the hashing work actually is

BLAKE3 makes one compression per 64-byte block plus one per parent node of
its chunk tree (`chunks − 1`). A 125M `A` column is 45,448 bytes: 711 blocks
in 45 chunks, so 755 compressions, times 65,536 columns.

| | column digests | salted leaves | inner nodes |
|---|---:|---:|---:|
| `A` at 125M | 49,479,680 | 65,536 | 65,535 |
| `H` at 125M | 61,931,520 | 65,536 | 65,535 |
| all four, 125M | 112,197,120 | 262,144 | 262,140 |

**The hiding commitment is column hashing. The Merkle tree is 0.23% of its
compressions and the salted leaves another 0.23%.** Any device design that
accelerates the tree and leaves the columns on the host has accelerated
nothing; any design that accelerates the columns can leave the tree on the
host and lose almost nothing. That is a counted fact and it should decide
the scope of the first kernel change.

### 2.3 Rung-W14 — the shape a device change is validated on first

Same `n`, same rate, same `Q`, same tree depth; `A` 527 rows and `H` 436,
so 1/10.8 and 1/16.3 of the bytes.

| | `A` | `H` | endpoint (each) |
|---|---:|---:|---:|
| rows | 527 | 436 | 9 |
| encoded matrix | 276,299,776 B | 228,589,568 B | 4,718,592 B |
| column bytes hashed | 276,299,776 B | 228,589,568 B | 4,718,592 B |
| column-digest compressions | 4,587,520 | 3,801,088 | 131,072 |
| random stream bytes | 4,255,744 B | 3,883,008 B | 2,134,016 B |
| sent: opened columns | 1,220,608 B | 1,034,240 B | 159,744 B |
| sent: total | 11,071,488 B | 3,696,640 B | 692,224 B |

All four together: 514,326,528 B (0.48 GiB) of encoded matrix, 9,175,036
compressions, 12,406,784 B of random stream. **The whole rung-W14 block's
committed material is under half a gigabyte** — it fits an 8 GB card whole,
several times over, which is exactly why it is the right first target.

Two things are worth noticing in that table. `A`'s clear vectors
(9,850,880 B, 37 vectors of `n + Q = 16,640` `Fp2` entries) are **unchanged
between the two shapes** — they scale with the row width and the group
count, not with the rows — so they are 89% of rung-W14's `A` opening and
46% of 125M's. And the endpoint commitments consume 2,097,152 B of salt
randomness each to commit 37 rows: the salt count is `nn`, not `rows`.

### 2.4 The randomness, per commitment

The memo's brief asks whether the lane's stage-36 census splits its total
per commitment. From the code the split is exact and needs no census: a
commitment draws `rows · Q` `fp()`s at 16 stream bytes each and `nn`
`bytes32()`s at 32, in that order, and nothing else. At 125M that is
23,269,376 + 2,097,152 for `A` and 29,163,520 + 2,097,152 for `H`. **A
device path must not change either number or their order**, because the
generator's position after the commitment is an input to everything drawn
after it.

## 3. Device memory: the 8 GB card and the 32 GB card

*pending*

## 4. The keyed kernels

*pending*

## 5. Blinding material on the device

*pending*

## 6. Proving byte identity without deterministic receipts

*pending*

## 7. What it does not buy

*pending*

## 8. A staged plan

*pending*

## 9. What this memo is not

*pending*
