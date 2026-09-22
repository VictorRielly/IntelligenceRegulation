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

Counted by `results/zk60_device_commit/device_residency.py` from the
allocation sites in `hashline/src/gpu/cuda.rs` on main at `78531ea`; output
in `device_residency.log` and `residency.json`.

### 3.1 What the two kernels need, and why the chunking axis is rows

`k_hash_cols` and `k_hash_cols_stream` both run **one thread per column**
and read that column down the encoded matrix at stride `nn`
(`kernels.cu:547`, `:1470`). So the hash pass needs *whole columns*; the
encode pass (`encode_rows_view_zk`, an inverse NTT, `k_zk_pad_scale` and an
expand NTT) needs *whole rows*. Chunking by columns would force the encode
to run `nn/chunk` times over every row; chunking by rows forces the hash to
be resumable. **CL1 chose rows and made the hash resumable**, which is the
right choice and the reason `k_hash_cols_stream` exists: it keeps each
column's BLAKE3 chaining-value stack in global memory —
`state[(8s + i)·nn + j]`, 193 `u32` per column (`kernels.cu:1418-1427`,
`cuda.rs:2130`) — so a launch can absorb a slice of rows and the launch
holding the last row emits the leaf. The encode pass and the hash pass then
walk *the same* `chunk_plan` in one loop (`cuda.rs:1834-1842`).

The load-bearing constraint is that **every chunk but the last is a
multiple of 128 rows** (`chunk_plan`, `cuda.rs:2116-2129`): 128 rows × 8 B
is 1,024 bytes, exactly one BLAKE3 chunk of a column's byte string, so an
interior chunk boundary is always a chunk boundary of the hash. The default
is `HL_GPU_CHUNK_ROWS = 128` with a floor of 128 (`cuda.rs:2105-2113`); the
source records the tuning — a 1,024-row chunk's encoded scratch is 537 MB,
"far past the 32 MB L2", against 67 MB for 128 rows.

### 3.2 The resident-set table [COUNTED]

`W = 8` bytes per field element; `n = 2^14`, `nn = 2^16`, `Q = 256` at both
shapes. The source's own peak formula for the resident arm is
`[rows·(n + Q + 2·nn) + nn] · 8` (`cuda.rs:3619-3621`) — both `rows × nn`
buffers (`d_coef2` and `d_enc`) are live across the expand NTT. The figures
below add the two buffers that formula omits: the leaf array (`nn × 8`
`u32`) and the twiddle tables.

| 125M | `A` (5,681 rows) | `H` (7,120) | endpoint (37, ×2) |
|---|---:|---:|---:|
| `rows·nn·8` vs the 1 GiB threshold | 2,978,480,128 → **chunks** | 3,732,930,560 → **chunks** | 19,398,656 → resident |
| resident-arm peak | 6,716,884,976 B (6.26 GiB) | 8,417,345,520 B (7.84 GiB) | 47,392,752 B |
| **chunked-arm peak** | **961,513,456 B (0.90 GiB)** | **1,153,073,136 B (1.07 GiB)** | — |
| survives to the opening | 756,779,008 B | 948,338,688 B | 24,248,320 B |

The chunked peak decomposes as persistent (`d_data` + `d_pads` + `d_pows`)
+ 150,994,944 B of scratch (`d_coef`, `d_coef2`, `d_enc` at 128 rows each)
+ 50,593,792 B of BLAKE3 state + 2,097,152 B of leaves + 1,048,560 B of
twiddles. **The scratch, the state, the leaves and the twiddles are the
same 204,734,448 B at every shape** — they depend on `nn` and the chunk
size, not on the rows.

| rung-W14 | `A` (527) | `H` (436) | endpoint (9, ×2) |
|---|---:|---:|---:|
| `rows·nn·8` | 276,299,776 → resident | 228,589,568 → resident | 4,718,592 → resident |
| resident-arm peak | 626,423,792 B | 518,889,456 B | 14,305,264 B |
| survives to the opening | 345,374,720 B | 285,736,960 B | 5,898,240 B |

### 3.3 (a) The 8 GB card — the peak, and the free order as a condition

**The whole commit phase of a 125M block peaks at 1,909,852,144 B
(1.78 GiB) and holds 1,753,614,336 B (1.63 GiB) from the last commit to the
openings — 22.2% and 20.4% of the laptop's 8,188 MiB.** [COUNTED] That is
the commitments alone, and it is comfortable.

The all-resident counterfactual is what CL1 bought: cumulative peak
**12,140,445,680 B (11.31 GiB), 1.41× the card**, because `A`'s own peak
(6.26 GiB) fits alone but `H`'s (7.84 GiB) does not once `A`'s encoding is
still held. The chunked arm's peak is **6.4× smaller**. This is the counted
twin of CL1's measured result — one Mistral layer's hiding commit 15.82 →
4.142 s, "3.82× purely by fitting", VRAM 5,182 MB flat with 37% headroom
[MEASURED, one layer, `ZK60_FIVE_SECOND_PLAN.md` §3.B row CL1].

**Add the round loop and the sentence changes.** The IR memo's
round-loop-only figure is 4.83 GiB (all 23 slots' sumcheck tables as `Fp2`,
with `A` and `H` counted as raw data) [COUNTED,
`ZK60_SLOT_EXPRESSION_IR_DESIGN_CHECK.md` §10]. 1.63 + 4.83 = **6.46 GiB,
80.8% of the card.** Under this project's VRAM rule — running out of VRAM
freezes the whole WSL box, not just the process — the only sentence I am
willing to write is:

> **The hiding commitments of a 125M block fit an 8 GB card at a counted
> peak of 1.78 GiB, provided the chunked arm is taken (it is, by default, at
> this shape) and provided each commitment's scratch is returned to the pool
> before the next commitment's is taken. Commitments *plus* the round loop
> reach 6.46 GiB, 81% of 8,188 MiB, and that is a counted figure with no
> measurement behind it and no margin for a fragmented pool.**

The free order is the condition, not a note. Concretely: `d_coef` must drop
before `d_enc` is taken (it does today, `cuda.rs:3695`); the chunk scratch
must return to the pool between commitments; and the pool's best-fit
`pool_take_min` (`cuda.rs:461-483`) must not be left holding four
commitment-sized buffers. Note also that this same rule is what makes the
resident arm's `HL_ZK_CHUNK=off` mode dangerous on the laptop: it is a
strict reference mode that *refuses* to fall back, and at 125M it would ask
for 7.84 GiB in one take.

### 3.3 (b) The 32 GB card

The 5090 is **not installed and the machine does not exist yet**
(`ZK60_5090_LINUX_BRINGUP.md:3-8, 1270-1275`; the five-second plan's "could
not find" item 7: "Any RTX 5090 measurement. The card is not installed"),
and the 32 GB figure is `BLACKWELL_5090_RUNBOOK.md:21`. So everything here
is a counted budget against a card nobody has measured.

| what | bytes | % of 32 GB |
|---|---:|---:|
| the four commitments, chunked, commit-phase peak | 1,909,852,144 | 6.0% |
| held to the openings, chunked | 1,753,614,336 | 5.5% |
| the all-resident arm's peak (both encodings live) | 12,140,445,680 | 38% |
| held to the openings, all-resident | 8,460,904,432 | 26% |
| chunked holdings + the round loop's 4.83 GiB | 6,938,713,604 | 21.7% |
| all-resident holdings + the round loop's 4.83 GiB | 13,646,003,700 | 43% |

**So the interesting question on a 32 GB card is not "does it fit" but
"should it chunk at all".** With 32 GB, both encodings can stay resident
through the round loop for 26%, and the opening then reads its 256 columns
straight out of `d_enc` instead of re-encoding from `d_data` + pads + coset
powers. That is a real saving the chunked arm gives up — the lane already
measured the CPU cost of the re-encode phase once (CL7 trimmed it 0.575 →
0.470 s on one Mistral layer [MEASURED there]) — and on a 32 GB card the
default `HL_GPU_CHUNK_BYTES = 1 GiB` threshold is simply the wrong number.
I would not hard-code a new one: the threshold should be a fraction of
*free* VRAM read at startup, and the resident arm should keep its
allocation-failure fallback. **Even at 32 GB the peak must be named**, and
the all-resident peak of 11.31 GiB plus the round loop's 4.83 GiB is
16.14 GiB — half the card, before anything else in the pass.

## 4. The keyed kernels

### 4.1 What the two kernels compute today

Both are in `hashline/src/gpu/kernels.cu` on main at `78531ea`, over a
shared `__device__` core.

* **Flags** (`kernels.cu:455-459`): `B3_CHUNK_START 1`, `B3_CHUNK_END 2`,
  `B3_PARENT 4`, `B3_ROOT 8`, `B3_MAX_DEPTH 24`. **There is no
  `KEYED_HASH` constant and no `DERIVE_KEY_*` constant.**
* **`b3_compress(cv, block, counter, block_len, flags, out)`**
  (`:480-509`): `s[0..8] = cv`; `s[8..12]` = the first four IV words,
  written inline; `s[12..14]` = the counter; `s[14] = block_len`;
  `s[15] = flags`; 7 rounds; output `out[i] = s[i] ^ s[i+8]` — the
  truncated 32-byte form, which is what `blake3::hash` returns.
* **`b3_iv(cv)`** (`:474-477`) is the standard IV and is used at **three**
  logical places: the chaining value each chunk starts from (`:538`,
  `:1459`), the chaining value of a lazy-merge parent (`:529-531`,
  `:1451-1453`) and the chaining value of a root-fold parent (`:565-567`,
  `:1481-1483`).
* **`k_hash_cols`** (`:582-590`): one thread per column, the whole column,
  a private 24-level CV stack in local memory; multi-chunk by the standard
  popcount rule. `leaves[j·8 + w]` is the `w`-th output word.
* **`k_hash_cols_stream`** (`:1429-1498`): the same code with the CV stack
  moved to global memory and the row range rebased by `row0`; the launch
  holding the last row writes the leaf. Its flag lines are textually
  identical to the resident kernel's (`:1463-1464` vs `:541-542`).
* Launch: `LaunchConfig::for_num_elems(nn)` — 1,024 threads per block,
  `ceil(nn/1024)` blocks, no shared memory.

### 4.2 The minimal change to a keyed mode, checked against the crate

The CPU path uses **blake3 1.8.7** (`zkp-core/Cargo.lock:12-15` and
`hashline/Cargo.lock:22-25`, same checksum
`6d9e454f…27ae`; the lane's locks are identical). I read the crate rather
than repeating the lane's comment, and the comment is right but *incomplete
in a way that matters*:

* `KEYED_HASH = 1 << 4` = **16** (`blake3-1.8.7/src/lib.rs:200`).
* `Hasher::new_keyed(key)` decodes the 32 key bytes as **eight
  little-endian `u32`** (`platform.rs:477-488`) and calls
  `new_internal(&key_words, KEYED_HASH)` (`lib.rs:1097-1099`) — so the key
  words are the initial chaining value *and* `KEYED_HASH` is in the flags
  of every compression.
* `parent_node_output(left, right, key, flags)` sets
  `input_chaining_value: *key` (`lib.rs:1022`), `counter: 0`,
  `block_len: 64`, `flags: PARENT | flags`. **In keyed mode a parent node's
  chaining value is the KEY, not the IV.**

So the change is:

1. add `#define B3_KEYED_HASH 16u`;
2. pass the eight key words in (a kernel parameter or `__constant__`
   memory, uploaded once) and use them **at all three `b3_iv` sites** —
   chunk start, lazy-merge parent, root-fold parent;
3. OR `B3_KEYED_HASH` into the flags of **every** compression, the chunk
   blocks and the parents alike;
4. leave `s[8..12]` alone: those stay the first four IV words in both modes.

**The trap, stated plainly.** The lane's own instruction is "load the key
words in place of `b3_iv` and OR in `KEYED_HASH`" (`pcs.rs:766-768`). There
are three `b3_iv` sites per kernel, not one. A kernel that keys only the
chunk-start site produces **the correct digest for every column short
enough to be one BLAKE3 chunk** — at 8 bytes per row, any commitment of
**128 rows or fewer** — and a wrong root for everything larger. A probe run
only at small row counts would pass it. The existing `dev_hash_check`
sweeps `rows = 1..=300` plus both sides of every chunk boundary up to 8,192
(`hashline.rs:503-504`), so it *would* catch this — provided the keyed probe
inherits that sweep rather than a new short one.

### 4.3 Which keys the device needs — only one of the four

This is the part that makes the change small. Of the three keyed hashes in
§1, **only the column digest happens on the device**: the leaves are salted
on the host (`pcs.rs:797`) and the tree is built on the host
(`pcs.rs:798`), and the device returns unsalted column digests — the source
says so in as many words, `cuda.rs:3598`: "column hashes (unsalted: the host
salts the leaves as on the CPU path)". So the device needs
`tag.column_key()` and nothing else; `tag.leaf_key()` and `tag.node_key()`
never leave the host, and the transcript key never comes near the GPU.

One key, 32 bytes, derived on the host by `blake3::derive_key(CTX_COLUMN,
profile)` and uploaded once per process. The kernel must decode it as eight
little-endian `u32`, the same way `platform::words_from_le_bytes_32` does.

### 4.4 The probe, extended

`dev_hash_check` is at `cuda.rs:2930-2945` (not 2783 — 2780 is
`dev_commit_zk_from_probe`, the end-to-end hiding-commit probe). It hashes
64 columns of LCG data at a caller-given row count on the device and
compares against `zkp_core::pcs::hash_columns`, returning the mismatch
count; the `hashline gpu-probe` subcommand (`hashline.rs:499-513`,
`#[cfg(feature = "gpu-cuda")]`) sweeps the row counts, prints "blake3 checks
RED" and `exit(1)` on any failure. **It exercises `k_hash_cols` only.**

The keyed extension is a second comparison in the same shape: hash the same
64 columns under a fixed key and compare against
`zkp_core::pcs::hash_columns_keyed(&enc, rows, 64, Some(&key))`, over the
same row sweep, with two negative controls that are as important as the
positive one — the keyed device digest must **differ** from the unkeyed CPU
digest, and a device digest under key `K1` must differ from the CPU digest
under key `K2`. Without those, a kernel that silently ignored its key
argument would pass a test that only compared keyed-to-keyed if the host
also ignored it.

`k_hash_cols_stream` has no dedicated probe of its own (it is covered
indirectly by `dev_commit_check_chunked`, `cuda.rs:2522`). Given §4.2's
trap, the keyed probe should cover it directly.

### 4.5 Every launch site

| kernel | lookup | launch | enclosing function | what it commits |
|---|---|---|---|---|
| `k_hash_cols` | `cuda.rs:2911` | `cuda.rs:2915` | `Gpu::hash_cols` | — (the one entry) |
| | | called at `cuda.rs:2888` | `dev_commit_from` | plain resident commit |
| | | called at `cuda.rs:2942` | `dev_hash_check` | the probe |
| | | called at `cuda.rs:3744` | `dev_commit_zk_from` | **hiding resident commit** |
| `k_hash_cols_stream` | `cuda.rs:1832` | `cuda.rs:1841` | `Gpu::commit_zk_chunked` | **hiding chunked commit (CL1)** |
| | `cuda.rs:2267` | `cuda.rs:2279` | `Gpu::commit_chunked` | plain chunked commit |
| | `cuda.rs:2319` | `cuda.rs:2377` | `Gpu::commit_chunked_upload` | plain chunked + pinned upload |

Six launch sites, four of which are on a non-hiding path. A keyed mode must
be *opt-in per call*, not a global switch: the non-hiding commits
(`wcache`, the weight planes) are not tagged and must keep producing exactly
the bytes they produce today.

### 4.6 One thing the integrator should know before starting

**The tagged path does not exist on main.** `zkp-core/src/hashtag.rs`,
`commit_zk_owned_with_tag`, `hash_columns_keyed`, `salt_leaf_keyed`,
`MerkleTree::build_keyed` and `verify_zk_tagged` are all in the lane
worktree at `a8e4939` and none of them is in main's `zkp-core/src` at
`78531ea`. So there is no "tagged commit declines the accelerator" site in
main's tree to point a reviewer at; the decline is `pcs.rs:782-785` **in the
lane**, and it arrives with the D19 integration. A keyed kernel written
before that integration would have nothing to serve.

## 5. Blinding material on the device

**This is the section the toy privacy statement scoped out, and nothing in
it is a safety claim.** The statement's note of 2026-09-21 03:23 says
exactly what is missing (`ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md`, quoted
verbatim):

> **(1) This statement covers the profile on the CPU path.** At this
> untagged profile the commitment code still offers its column hashing to
> the accelerator: **a build with the `gpu-cuda` feature and `HL_GPU=1` at
> run time sends it to two hand-written CUDA BLAKE3 kernels, and blinding
> rows and pads to device and pinned host memory.** … **That configuration
> is not covered until the kernels' agreement with the CPU function is cited
> to a gate by name and the lifetime of those buffers has been read.**

Two obligations, then: *a named gate* (§6) and *a read of the buffers*
(below). I have done neither — I have read the allocation sites and can say
what the read must establish.

### 5.1 What private bytes reach device memory, and for how long

| bytes | private? | where | lifetime |
|---|---|---|---|
| the witness rows (`d_data`, `rows × n`) | **yes** — the block's activations | `Pooled`, uploaded by `dev_commit_zk` (`cuda.rs:3761`) | held in `DevCommit.data` **until the commitment is dropped**, i.e. past the openings |
| the pad rows (`d_pads`, `rows × Q`) | **yes** — this is the blinding | raw `htod_sync_copy` (`cuda.rs:3634`), **not pooled** | on the chunked arm, **retained in `ZkReenc` until the opening** (`cuda.rs:1595-1602`) |
| the coset powers (`d_pows`, `nn`) | no — public | raw (`cuda.rs:3636`) | retained with the pads |
| the mask and proximity rows | **yes** | *inside* `d_data` — they are rows of `A`/`H` (`protocol.rs`, the `a_mask_base` loop) | as `d_data` |
| `d_coef`, `d_coef2`, `d_enc` | **yes** — the encoding of private rows | `Pooled::take` / `take_min` | returned to the pool, **unscrubbed** |
| the BLAKE3 CV state (`d_state`) | derived from private bytes | `Pooled`, zeroed on acquisition (`cuda.rs:1829`) | returned unscrubbed |
| the salts | **NO — they never reach the device** | drawn on the host (`pcs.rs:778`), applied on the host (`pcs.rs:797`) | — |

**Copied back to the host?** On the production commit path, only the
`nn × 32` bytes of column digests and, at opening time, the sampled columns
(`cuda.rs:1843`, `:2916`, `:1928`, `:2489`, `:2984`). Both are receipt
material anyway. **One exception exists and must be named:** under
`HL_GPU_HOST_HASH=1` (`cuda.rs:2878-2886`) the *whole* encoded matrix —
`rows × nn × 8` bytes of private encoding — is copied back to the host with
`dtoh_sync_copy` at `cuda.rs:2880`. That is an A/B switch on the non-hiding
path, but it is the kind of thing the buffer review exists to find.

**Zeroed on free?** No. `Pooled`'s `Drop` (`cuda.rs:503-509`) hands the
slice back to a 64-entry free list (`pool_put`, `cuda.rs:451-458`) with no
memset; allocation is a raw `cuMemAlloc` with no initialisation
(`cuda.rs:446`, `:479`); and `pool_take_min` best-fits, so a later, smaller
request gets a buffer **whose tail still holds the previous tenant's field
elements** ("the extra tail is inert", `cuda.rs:459-461`). There are exactly
three `memset_zeros` calls on the commit path and all three are on
*acquisition* of the BLAKE3 state buffer, never on release. The codebase
states its own invariant, twice (`cuda.rs:3113-3114`, `:3147-3149`):
"Draining is value-neutral: a pooled buffer holds nothing live (every
element a kernel reads is written first)". **That is a write-before-read
argument, not an erasure argument**, and it is the right argument for
*correctness*. Whether it is the right argument for this project's privacy
statement is exactly what the integrator's buffer review must decide, and I
am not deciding it here.

### 5.2 What the buffer review must establish for the hash-layer argument to extend

The hash-layer argument's conditions are C-H1…C-H8 (+C-H4′) in
`ZK60_HASH_LAYER_AND_FS_LIFT.md` §2.5 — **not** in the run disposition,
which carries the run-level rulings H-1…H-8 instead. Three of them bear
directly on a device path, and one of them is already written as a gap:

* **C-H8** — "no external/device commit path produces different leaves".
  Status today: "**TRUE**: the block calls `commit_zk_owned` → the `Cpu`
  backend … is never offered a device on this path", with the required
  action "assert the store is `Store::Host` in the block profile's own test,
  so a future device backend has to re-open this question deliberately.
  **GAP for any future device path**." That sentence is about this memo. A
  device hiding commitment *is* the future device path, and C-H8 is the
  condition it must re-establish — by byte identity, not by inspection.
* **C-H3** — "the salt is 32 bytes", true at the type level
  (`salts: Vec<[u8; 32]>`). Unaffected: the salts never reach the device
  (§5.1). This is the one condition a device path cannot break, and it is
  worth saying, because it means the leaf-level blinding argument is
  entirely host-side.
* **C-H5** — "no salt or blinding value is reused across commitments or
  proofs". A device path does not draw anything, so the draws are
  unaffected; but the *pool* reuses buffers, and a review has to say that
  reuse of a buffer is not reuse of a value. The write-before-read invariant
  is what carries that, and it is asserted in comments rather than enforced.

**On leaf/node domain separation, do not overclaim.** Under the legacy rule
there is **no** domain separation between a salted leaf and an inner node —
both are 64 untagged bytes, recorded as finding L-7 in
`ZK60_HASH_LAYER_AND_FS_LIFT.md`: for hiding the missing bad event is priced
at ≈2^-484.8; for **binding** it is "declared outside this memo … and
**checked by nobody** — FLAGGED AND NOT CHASED". D19's tag is what removes
it for tagged profiles (`salt_leaf_keyed`'s doc comment, `pcs.rs:686-690`,
says so). A device path does not touch either hash, so it neither creates
nor fixes this — but a memo about the device must not be read as saying the
separation exists.

### 5.3 What would REOPEN the toy statement

The toy profile is CPU-only and legacy-ruled, and §1 of the statement lists
the 125M and rung profiles as already out of scope. What would reopen the
*toy statement itself*:

1. **A toy proof produced with `HL_GPU=1`.** The statement's evidence — four
   captures and both gates — was produced on the CPU, and the capture runner
   strips every `HL_*` variable. A toy capture made on the device is outside
   the statement until §6's gate exists.
2. **Any change that lets the device see a salt.** Today it cannot; the
   leaf-level argument rests on that.
3. **Any change to the number or length of the salts**, including a
   byte-saving lever: C-H3 is priced in §2.4 of the hash-layer memo at 16
   and 8 bytes and may not be moved without redoing it.
4. **A device path that returns *permuted* leaves** — see §1 step 5's
   ordering trap. It would not be caught by "the proof verifies" if the
   verifier were also changed, and it changes which salt lands on which
   column.
5. **Scrubbing, or not scrubbing, becoming load-bearing** — i.e. any claim
   in the statement that rests on device buffers being erased. There is no
   such claim today and none should be added without `cuMemsetD8` on
   release and a test for it.
6. **Enabling `HL_GPU_HOST_HASH=1` on a private path**, which copies the
   whole private encoding back to the host (§5.1).

None of the above is a finding that anything is unsafe. Each is a thing that
has to be read.

## 6. Proving byte identity without deterministic receipts

*pending*

## 7. What it does not buy

*pending*

## 8. A staged plan

*pending*

## 9. What this memo is not

*pending*
