# Research handoff: committed-volume census of one 8B request, and the memory floor against a plain pass (2026-11-16, claude-cycle 4)

From Claude, the standing researcher (D50).

**Scope.**
- **Local counting only.** No web search, no build, no prover run, no GPU run, no Git write. Read source, logs and notes;
  ran one pure-Python script (`20261116-claude-cycle4-census.py`, standard library, under a second, reads no file).
  Only this file, that script and a dated STATE.md entry were written.
- **Carries out H133** (cycle 3's top-ranked test, `20261116-claude-cycle3-receipt-size-and-overhead.md`), part (a), the
  census, plus the arithmetic half of part (b), the plain baseline. The plain baseline here is **bytes and a roofline, not a
  timing**: no plain pass was run (the Mac's GPU is shared; `ZK60_RESOURCE_PROTOCOL.md`).
- **Triage material, not a work order.** The owner shelved size work on 2026-11-09 and the 2x goal file
  (`docs/zkmatrix-poc/ZK60_ULTIMATE_GOAL_2X_OVERHEAD.md`) is unreviewed; this note puts honest counts under its
  denominator. It asks for no change to the prover.
- **The two Python inventories were read, not run.** `scripts/zk60_private_block_inventory.py:312-313` pins the T32 rung
  (A 455 rows, H 384 rows) and `scripts/zk60_attention_native_inventory.py:1112-1113` pins the attention note's shape
  (A 306, H 290). Neither covers the 8B W16R2 shape, so they cannot give this census. The authority used is the Rust
  census test and its recorded output (§1), tied to measured receipt bytes.

Labels: **COUNTED** (from code or a recorded census output, file:line), **MEASURED** (a recorded run in this repository),
**DERIVED** (my arithmetic, shown or in the script), **ASSUMED** (a number I chose or took from an unverified source; stated).

## 0. Headline

- **Committed per request (8B, T = 128, 32 blocks, W16R2): 164,548 rows of 2^14 words = 2.696 x 10^9 message words
  (21.6 GB at 8 B each), encoded to 5.398 x 10^9 codeword words (43.2 GB) at rate 1/2.** BLAKE3 then hashes **43.6 GB**
  (columns 43.1 GB plus salted-leaf and node input 0.47 GB). [COUNTED rows, DERIVED words and bytes; row counts reproduce
  the measured per-block opening bytes exactly, §1.] The 2.7 x 10^9 of cycle 3 was right to 0.15%; its "about 40 GB" of
  codewords is 43.2 GB (§3).
- **What the words are.** Of one block's 5,103 committed rows, **activation words are 19.3%, range and remainder limb planes
  24.9%, LogUp helpers (Fp2, two rows each) 49.3%, masks and blinding 6.1%, tables and per-token aggregates 0.5%** [COUNTED].
  Three quarters of the volume is lookup machinery, not model values.
- **Plain pass for the same request** (weights public, read once per batch): **int8 about 7.5 GB of weights plus 0.4-1.5 GB
  of activations = 7.9-9.0 GB; fp16 15.4-16.5 GB**; 898 G multiply-adds (1.80 T ops) [DERIVED, ASSUMED activation range].
  The committed codewords alone are **4.8-5.5x the plain int8 bytes and 2.6-2.8x the plain fp16 bytes**.
- **Floor, RTX 5090 at an assumed 1.792 TB/s peak, one request:** write the codewords once **24.1 ms**; write and hash
  once **48.4 ms**. Plain: int8 **4.4-5.0 ms**, fp16 **8.6-9.2 ms** (memory-bound at batch 1). Ratio floor/plain:
  **write-only 4.8-5.5x (int8), 2.6-2.8x (fp16); write and hash 9.6-11.0x (int8), 5.3-5.6x (fp16)** [DERIVED, ASSUMED
  bandwidth and peaks]. On the M3 Ultra at the measured 640 GB/s the same bytes give 67 ms and 136 ms; the ratio is the same
  while both sides are memory-bound.
- **Verdict on H133's kill condition: triggered.** Against the project's own integer baseline the floor the question defined
  (write once, hash once) is **above 4x plain** (9.6-11x), and so is the weakest variant (write only, 4.8-5.5x) at batch 1, and **batching makes it worse, 5.6x to 11x** (the proof's traffic per request does not fall;
  the plain pass's does). Against fp16, the denominator the goal file names, the weakest floor is **between 2x and 4x**
  (2.6-2.8x) at batch 1, and falls to 1.4x only if the fp16 baseline is assumed to run at 50% of an unverified tensor peak.
  All of this is volume alone, before sumchecks, lookups or witness arithmetic. **The "2x total" planning number is not
  supported for a design that commits this volume.** What would change that is a count, §6: to fit a "added cost no more than
  one plain pass" budget the write floor needs at most about 20% of today's rows, which is about the activation words alone.
- **H133's second test** (are activations under 10% or over 50% of committed volume?): **19.3%, in between.** H134's
  packing gate (kill if the packable share is under 40%) is passed narrowly, 44.7%, but a 4x packing cuts rows only to 66.8%.

## 1. What was counted, and how it ties to measured bytes

The profile is `W16R2_8B_T128_H24` (`shape.rs:302`: tokens 128, width 4096, hidden 14336, 32 query heads of 128, 8 KV heads,
`log_cols` 14), at inverse rate 2 (`shape.rs:306`), 280 opened columns and 280 pads per row (`shape.rs:320`), row width 2^14
(`shape.rs:323`). It is the current design: **the last commit touching `shape.rs`, `layout.rs` or `accuracy_layout.rs` is `7670cbb1`
of 2026-11-04, and the three files have no uncommitted change**, so the 2026-11-05 census still describes the code.

**Authority.** The ignored Rust test `effplan_census_of_the_committed_rows_by_domain` (`range16_tests.rs:209-246`) prints the
planes and rows per domain from the layout code itself; its recorded output is `results/zk60_effplan_20261105/census.log:218-237`.
Row geometry: `layout.rs:1318-1353` (A rows = planes x rows per plane; **an H plane is Fp2 and takes two rows**,
`layout.rs:1345-1349`; one reserved mask pair per claim site; one proximity pair). Domain sizes and padding:
`shape.rs:2420-2425` and `2455-2457`; plane lists: `shape.rs:2466-2489` (A), `2568-2589` (H); plane roles:
`accuracy_layout.rs:113-160`.

**The tie to bytes.** The block A opening is `(groups + 1)(n + Q) 16 + Q(8 + 8 rows + 32 + 32 path)` bytes
(`wire.rs:96-117`, as `results/zk60_effplan_20261105/b6/model.py:52-53`). With A = 2,501 rows and H = 2,602 rows the script
asserts **A 15,612,928 B, H 8,640,320 B, M 243,712 B and the endpoint 761,728 B**, each equal to the logged block codec
(`results/zk60_w16r2_q280_20261103/logs/targeted_cpu.log:1539`, quoted at `model.py:48`) [MEASURED]. The whole receipt of
818,728,672 B (`a12merge_d55.log:233`) is reproduced by `model.py` with the slot proofs as a multiple-of-16 residual. So the
column data of **371,864,320 B** that cycle 3 called "372 MB" is exactly Q x rows x 8 B over the counts below.

### 1.1 One block, by commitment and domain [COUNTED]

Row width 2^14. Planes per domain, from `census.log:218-237`; rows per plane from the domain size.

| Domain | Words per plane | Rows per plane | A planes | H planes (Fp2) | A rows | H rows (2 per plane) |
|---|---:|---:|---:|---:|---:|---:|
| D (T x d) | 2^19 | 32 | 19 | 10 | 608 | 640 |
| F (T x 16,384 padded FFN) | 2^21 | 128 | 9 | 5 | 1,152 | 1,280 |
| Q (T x heads x head) | 2^19 | 32 | 6 | 3 | 192 | 192 |
| S (heads x T x T) | 2^19 | 32 | 8 | 5 | 256 | 320 |
| Kv (T x KV heads x head) | 2^17 | 8 | 6 | 3 | 48 | 48 |
| T, Ht, L (per-token) | lifted to 1 row | 1 | 8 | 1 | 8 | 2 |
| Tab (tables, multiplicities, range sub-planes) | lifted to 1 row | 1 | 15 | 16 | 15 | 32 |
| **Data rows** | | | **69** | **43** | **2,279** | **2,514** |
| Site mask pairs (2 rows per claim site: 110 A sites, 43 H sites) | | | | | 220 | 86 |
| Proximity pair | | | | | 2 | 2 |
| **Committed rows** | | | | | **2,501** | **2,602** |

A + H = **5,103 rows** per block (`model.py:35-36`; "5,103 rows of 2^14" at `model.py:362`). The masking table M is a separate
commitment: **50 rows, 512 message words each, a 4,096-position codeword (rate 1/8), 256 opened columns**
(`zk.rs:391-393`, `model.py:41`).

### 1.2 The groups the question asked for [COUNTED]

The word/limb split reads the plane list in `accuracy_layout.rs:113-160` (`new_w16`): the words are D: X, Y, AO, X1, YM, Z, X2
(7); Q: Q, QR, O (3); Kv: K, V, KR (3); S: S, ZSEL, E, P (4); F: G, A_SCALED, U, H (4). Every other A plane in those domains
is a remainder or limb plane for a requantization, a norm or the softmax division.

| Group (one block) | Rows | Message words | Codeword words | Codeword bytes | Share of 5,103 |
|---|---:|---:|---:|---:|---:|
| A **words** (activations the integer model defines) | 984 | 16.12 M | 32.24 M | 258 MB | 19.3% |
| A **limb and remainder planes** (small, range-checked) | 1,272 | 20.84 M | 41.68 M | 333 MB | 24.9% |
| A per-token aggregates (T, Ht, L) | 8 | 0.13 M | 0.26 M | 2 MB | 0.2% |
| A table planes (multiplicities, range sub-planes) | 15 | 0.25 M | 0.49 M | 4 MB | 0.3% |
| **H helpers** (Fp2 LogUp helpers, table helpers, zero-sum row u) | 2,514 | 41.19 M | 82.38 M | 659 MB | 49.3% |
| **Masks and blinding**: A site and proximity rows | 222 | 3.64 M | 7.27 M | 58 MB | 4.4% |
| **Masks and blinding**: H site and proximity rows | 88 | 1.44 M | 2.88 M | 23 MB | 1.7% |
| **A + H, per block** | **5,103** | **83.61 M** | **167.22 M** | **1,338 MB** | 100% |
| (A alone 2,501 rows: 41.0 M message, 655.6 MB codeword; H alone 2,602 rows: 42.6 M message, 682.1 MB codeword) | | | | | |

"Lookup-related columns" in the question's sense are the limb planes, the table planes and the helpers: **3,801 rows, 74.5%.**
Message words per row are 2^14; each row also carries 280 random pad symbols inside the coset code
(`pcs.rs:674-693`, K = n + Q = 16,664 coefficients encoded to 2^15 points), which are randomness, not extra message.

### 1.3 One request [COUNTED rows; DERIVED words and bytes]

| Item | Rows | Message words | Codeword words | Codeword bytes |
|---|---:|---:|---:|---:|
| 32 blocks, A + H (32 x 5,103) | 163,296 | 2,675.4 M | 5,350.9 M | 42.81 GB |
| 31 internal boundaries (38 rows each: 32 data + 2 x 2 site rows + 2 proximity, `boundary.rs:186`) | 1,178 | 19.3 M | 38.6 M | 0.309 GB |
| 2 endpoints (37 rows each: 32 data + 5 mask rows, `shape.rs:1776-1777`; **MEASURED-consistent**, 761,728 B opening) | 74 | 1.2 M | 2.4 M | 0.019 GB |
| 32 masking tables M (50 rows, 512 message, 4,096 codeword) | 1,600 | 0.8 M | 6.6 M | 0.052 GB |
| **Total** | **164,548 regular rows** | **2,696.8 M** | **5,398.5 M** | **43.19 GB** |

- **Message bytes** 21.57 GB. **Random pad symbols** 46 M words (1.7% of the message words), extra to it and not counted in
  it. **Salts** 106 MB (32 B per leaf, 129 commitments).
- **Merkle-hashed bytes: 43.61 GB** [DERIVED from `pcs.rs:584, 759, 806`: leaf = BLAKE3(BLAKE3(column) || salt), tree of 64-byte
  nodes]. That is 43.14 GB of column bytes (each codeword word hashed once), 0.05 GB for M's, and 0.42 GB of leaf-salt and
  inner-node input. The Merkle tree is 129 trees of 2^15 leaves (M: 4,096).
- **Opened column data in the receipt: 371.9 MB** (Q x rows x 8 B), matching cycle 3 and the B6 note.
- **Token I/O stages are not in this total.** `MVP_STATUS.md` (the 2026-11-0x entry "A gap the Lean work exposed") says W16R2
  has no token-I/O run profile yet, so no committed-row count exists for the embedding and head stages at W16R2. [ESTIMATE, not
  computed from code: at the older token tier (stage row width 2^12, `token_io.rs:190`) a vocabulary-sized domain is
  V_pad = 131,072 words = 32 rows per plane; with order ten such planes in A and a few Fp2 planes in H the two stages are
  about 2-10 M words, 0.1-0.4% of the total. The head product is a public-weight sumcheck, not a committed 128,256 x 4,096
  matrix.] The conclusion does not move for any plausible value.
- **What W16R3 would change** (not applied): the B1-B3 rows are 2,397 A and 2,462 H (`model.py:246`), 4,859 per block, 4.8%
  fewer; the Lean-found C1-C3, C5 trim about 11.7% (`MVP_STATUS.md`, "the proofs found slack"). Neither shifts any ratio below
  by more than that.

## 2. Against cycle 3's 2.7 x 10^9

Cycle 3 derived it backwards: 372 MB opened data / (280 x 8 B) = 166,000 rows, times 2^14. The count is **164,548 regular
rows and 2.696 x 10^9 message words: cycle 3 was right to 0.15%.** The 1,460 rows of difference are the 1,600 M-table rows,
opened at 256 not 280 columns (1,600 x 256/280 = 1,463). The first-principles cross-check in cycle 3 ("about 8 M activations
per block times a factor of 5-10") landed in range by luck: the activation words are **16.1 M per block (padded)**, not 8 M,
and the block commits 83.6 M words, a factor of **5.2** on them. **The one number to correct: cycle 3's "about 40 GB written" is 43.2 GB**
(it rounded 2 x 2.7 x 10^9 x 8 B = 43.2 GB down). The conclusion of §1.5 there is unchanged and slightly strengthened.

## 3. The plain baseline

Assumptions, all stated: batch of one request of 128 tokens unless said; the model is read once per request at batch 1, once
per batch of B at batch B (weights are public, so the same read serves the whole batch); the LM head is read in full for the
last position only (the project's per-row int8 head, `MVP_STATUS.md` "first private proof of a trained Llama-3-8B's next
token"); the embedding gather reads 128 rows (1 MB, ignored).

| Quantity | Value | Label |
|---|---:|---|
| Parameters per block: q 16.78 M, k 4.19 M, v 4.19 M, o 16.78 M, gate/up/down 3 x 58.72 M | 218,103,808 | DERIVED (the H124 note's "about 218 M int8 weights", `results/zk60_h124_witness_20261104/README.md:73`; 27.92 G MACs per block at T128, same file) |
| 32 blocks | 6,979,321,856 | DERIVED |
| LM head 128,256 x 4,096 (last position only) | 525,336,576 | DERIVED |
| **Weights read, int8 (1 B)** | **7.505 GB** | DERIVED |
| **Weights read, fp16 (2 B)** | **15.01 GB** | DERIVED |
| Multiply-adds: 32 x 218.1 M x 128, plus the head row, plus QK^T and PV on the full square | 898 G (1.80 T ops) | DERIVED |
| Activation traffic, unfused, every intermediate written and read once at 2 B (11.67 M elements per block: y1 q qr o ao x1 y2 z x2, k v kr, scores and probabilities, gate up h) | 1.49 GB | DERIVED |
| Activation traffic, lower end (fused attention and MLP, int8 lanes) | 0.4 GB | ASSUMED |
| **Plain int8, total** | **7.9-9.0 GB** | DERIVED |
| **Plain fp16, total** | **15.4-16.5 GB** | DERIVED |

Time (roofline: the larger of bytes / bandwidth and ops / peak). Bandwidth: **RTX 5090 1.792 TB/s peak** [ASSUMED, published
spec, not verified here; the independent review's own literal, `GPU_FRIENDLY_REVIEW.md:247-248`, which also uses 1,450 GB/s as
an effective streaming rate]. **M3 Ultra 0.64 TB/s** [MEASURED by the coordinator's T2 benchmark, 637 and 642 GB/s,
`GPU_FRIENDLY_REVIEW.md:115`; the review calls T2 the only fully clean result in the file]. Peaks: **int8 838 TOPS dense**
[ASSUMED, the review's recollection of NVIDIA's figure, unverified, `GPU_FRIENDLY_REVIEW.md:239-241`] and **fp16 tensor 210-420
TFLOPS dense** [ASSUMED, unverified].

| Pass, batch 1 | Bytes | Memory time, 5090 peak | Compute time at peak | Roofline |
|---|---:|---:|---:|---:|
| int8 | 7.9-9.0 GB | 4.4-5.0 ms | 2.1 ms | **4.4-5.0 ms** (memory-bound) |
| fp16 | 15.4-16.5 GB | 8.6-9.2 ms | 4.3-8.6 ms | **8.6-9.2 ms** (memory and compute close) |
| int8, M3 Ultra 0.64 TB/s | 7.9-9.0 GB | 12.4-14.1 ms | not assumed | at least 12.4 ms |

Cycle 3 guessed 5-8 ms for plain int8; this is 4.4-5.0 ms memory-bound at peak bandwidth, 5.5-6.2 ms at 1.45 TB/s. At batch B
the weight bytes per request divide by B: the plain int8 pass turns compute-bound at about B = 3-4 (peak utilisation) and
stays near 2.1 ms (4.3 ms at 50% utilisation) per request.

## 4. The floor

**What is bounded.** The prover must write every committed word's codeword once (it needs those columns to answer the 280
column openings after the challenges, and 43 GB does not fit in a 32 GB card, so it streams block by block: 1.34 GB per block),
and hash it once. Two versions, nothing else counted:

- **Floor W (write once, hash fused into the write):** 43.19 GB.
- **Floor WH (write once, read back once to hash, as the question states):** 43.19 + 43.61 = **86.8 GB** [DERIVED].

| Floor time | RTX 5090 1.792 TB/s [ASSUMED] | 5090 at 1.45 TB/s [ASSUMED] | M3 Ultra 0.64 TB/s [MEASURED] |
|---|---:|---:|---:|
| W (43.2 GB) | **24.1 ms** | 29.8 ms | 67.5 ms |
| WH (86.8 GB) | **48.4 ms** | 59.9 ms | 135.6 ms |

**Ratio to the plain pass** (floor time over plain roofline time, one request, batch 1, 5090 at peak bandwidth). The range
covers the activation-traffic range of §3 and, for fp16, the compute-peak range. The ratio does not change with bandwidth
while both sides are memory-bound (the same ratios hold at 1.45 TB/s and on the M3 Ultra).

| | Floor W | Floor WH |
|---|---:|---:|
| vs plain int8 | **4.8-5.5x** | **9.6-11.0x** |
| vs plain fp16, tensor-peak utilisation 100% | **2.6-2.8x** | **5.3-5.6x** |
| vs plain fp16, tensor-peak utilisation 50% (a slow baseline) | 1.4-2.8x | 2.8-5.6x |

Read on the 2x goal: "total at most 2x plain" allows an **added** cost of at most 1x plain if the forward pass is separate
from the proof, or at most 2x if the proof's work wholly overlaps it. The weakest floor in the table (W against fp16, batch 1,
peak utilisation) is 2.6x: above both readings.

**Against what is measured.** Recorded proofs take seconds per request: the harness 5.4 s and production 8.0 s on the M3
Ultra (`MVP_STATUS.md` A19, A20; older binaries), and the D64 target is 1.16 s on the 5090. The floors are **1.2-2.5% of the
measured Mac request** (67-136 ms of 5.4 s) and **2-4% of the D64 budget** (24-48 ms of 1.16 s). So the committed-volume floor
is not what limits today's throughput, nor D64; it limits the *2x aspiration*. This agrees with cycle 3's "about 180x at D64"
and the local 80-100x measured against plain 8-bit inference at 128 tokens (`MVP_STATUS.md`, 2026-10-19 entry).

## 5. What the floor leaves out, and what could lower it

**Left out** (each adds to the cost, none can reduce the floor): the witness itself (the seven weight products are 82% of the
M3 witness wall time and 95% of its CPU time, `results/zk60_h124_witness_20261104/README.md`; the integer forward in 64-bit
words, plus limbs and inverses); the NTT arithmetic (about 1.2 x 10^9 butterflies per block, 4 x 10^10 per request) and its
extra passes if not fused; the BLAKE3 arithmetic; every read of the message words by the folds (the clear vectors are
row combinations over all rows, 37 groups for A and 10 for H per block, `model.py:387`, so at least one more full 21.6 GB read
per request and up to dozens if not batched); the sumchecks and their table folds; the LogUp helper construction; the column
gather for the openings; the host path and launch overhead. Every one of these only raises the ratio.

**What lowers the volume, counted only (not a design).** Rows per block that fall in each category:

| Category | Rows | Share | Nature of the values | Could a count reduce it? |
|---|---:|---:|---|---|
| H helpers | 2,514 | 49.3% | full-field Fp2 values (sums of inverses); not small | not by packing; only by not committing them (the LogUp-GKR line, `20261101-logup-gkr-w16.md`, B5 in `MVP_STATUS.md`, needs a ruling) |
| A limb and remainder planes | 1,272 | 24.9% | 16-bit window values, many with 8 or fewer live bits | by packing, up to about 4 per 64-bit word for 16-bit windows |
| A words | 984 | 19.3% | int8 to 24-bit values | by packing, same 4 to 8 per word; but they are the volume the plain pass also has, at 2 B |
| Masks and blinding | 310 | 6.1% | uniform field elements | no (hiding needs them); compact masks, B6b, trim at most the 310 |
| Tables, per-token aggregates | 23 | 0.5% | small | negligible |
| Padding inside rows | 304 row-equivalents | 6.0% | F stripes carry 2,048 pad words in each 16,384-word row (12.5% of the F domain) [DERIVED]; S above the diagonal up to 288 row-equivalents, 5.6%, if those words are not needed [UPPER BOUND, not checked] | not by dropping rows (padding is inside each row); the ragged-row test of `GPU_FRIENDLY_REVIEW.md` T2 priced it |
| Boundaries and endpoints (per request) | 1,252 | 0.76% | duplicate of the block-output plane X2 | negligible |

Packable fraction (small-value A planes): **A data rows are 2,279 of 5,103 = 44.7%** (words plus limbs 2,256 = 44.2%).

**Chaining linear layers without committing the intermediate** (H134 part b), as a count: the words that are a weight-matmul
input or output are Y, YM, O, H (inputs) and Q, K, V, AO, G, U, Z (outputs), **592 rows, 11.6% of a block** [DERIVED from the
plane roles]. But every one of these outputs is followed, before the next matmul, by a requantization with remainder planes and
a range lookup, a norm, RoPE, a softmax or SiLU. So no word sits between two purely linear operations; the 11.6% is the
ceiling and the expected cut by chaining alone is near zero. The accumulators before the requantization are already not
committed.

**The floor under category scenarios** (write floor W, batch 1, 5090 at peak, plain int8 at its mid-range 4.72 ms; count only,
every other cost ignored):

| Scenario (rows kept per block) | Rows | Share of today | Floor W / plain int8 |
|---|---:|---:|---:|
| Today | 5,103 | 100% | **5.11x** |
| Helpers and their masks not committed | 2,501 | 49.0% | 2.50x |
| A words and limbs packed 4 per word | 3,411 | 66.8% | 3.42x |
| A limbs only packed 4 per word | 4,149 | 81.3% | 4.15x |
| Helpers not committed and A packed 4 per word | 809 | 15.9% | 0.81x |
| Activation words alone | 984 | 19.3% | 0.99x |

To bring the write floor to 2x plain the volume must fall to **39% of today (about 2,000 rows)**; to 1x, to **20% (about 1,000
rows)**, which is the activation words alone, with nothing else committed. Only the combination "no helper columns and packed
small values" gets there on volume, and the scenario ignores the sumchecks and lookups that replace the helpers.

## 6. Verdict on H133's kill condition, and batch sensitivity

**Kill condition** (cycle 3): kill the 2x planning number if (floor bytes / bandwidth) > 4 x plain time; paper form, committed
bytes per request above about 15 GB at 1.8 TB/s. The floor the question defines is **WH** (write once, hash once); W is the
weakest variant, shown as a margin check.
- **Paper form: 43.2 GB of codewords against 15 GB (2.9x over); even the 21.6 GB of message words alone is over.**
- **Against plain int8** (the project's own model): floor WH is **9.6-11.0x**, floor W **4.8-5.5x**. **Above 4x on both: kill.**
  These compare two bounds at the same bandwidth. Against a *measured* plain engine at 60-90% of peak bandwidth the ratios
  scale by that efficiency: W becomes 3.1-4.6x (so between 2x and 4x for an engine under about 78% efficient), WH stays
  5.8-9.9x, above 4x in every case.
- **Against plain fp16** (the goal file's baseline): floor W is **2.6-2.8x**, **between 2x and 4x**; floor WH 5.3-5.6x,
  above 4x. Even the weakest case exceeds the 2x total budget.
- "After a 3x kernel gain" does not lower a bytes floor: a better kernel approaches the floor, it does not pass it. A fused
  prover that never writes the codewords (stores the 21.6 GB message and re-encodes at opening time) trades one 43 GB write for
  a 21.6 GB write plus at least one more 21.6 GB read, 43 GB in all [DERIVED]; it moves no ratio below 4x either.
- **Below 2x is not reached in any variant at batch 1**, except in the corner "fp16 baseline at 50% utilisation of an
  unverified tensor peak, floor W", 1.4x. That compares against a deliberately slow plain pass.

**Sensitivity to batch** (weights public and read once per batch; the proof's volume per request is fixed because each request
has its own commitments, cycle 2). Floor W ratio, 5090, peak bandwidth:

| Batch | Plain int8, peak tensor use | Plain int8, 50% tensor use | Plain fp16, peak | Plain fp16, 50% |
|---:|---:|---:|---:|---:|
| 1 | 4.8-5.5x | 4.8-5.5x | 2.6-2.8x | 1.4-2.8x |
| 2 | 8.2-10.4x | 5.6x | 2.8-5.5x | 1.4-2.8x |
| 4 and above | 11.2x | 5.6x | 2.8-5.6x | 1.4-2.8x |

**Batching never helps the ratio.** At batch 1 the plain pass is memory-bound on weights and the proof's 43 GB is 5x those
bytes. As the batch grows the plain pass becomes compute-bound at 2.1-4.3 ms per request while the proof stays at 24 ms, so the
ratio rises to 5.6-11x (int8). The ratio at batch 1, 4.8-5.5x, is its minimum over batch sizes, and it is set by one number,
**43.2 GB of codewords against 7.9-9.0 GB of plain int8 bytes.** It is insensitive to the bandwidth assumption (cancels) and
moderately sensitive to the plain activation traffic (the 4.8-5.5 range) and, for fp16, to the unverified tensor peak.

## 7. Candidates and triage update

No new hypothesis (count stays 135).

- **H133: resolved for (a), and for (b) on paper.** Verdict §6. The remaining measured half, a quiet-box plain int8 timing of
  128 tokens on a mature engine, would replace §3's roofline with a clock. It cannot flip the verdict on floor WH (48 ms
  against 4 x plain would need plain over 12 ms, an engine at 40% of peak bandwidth). It could move floor W, the weakest
  variant, from above 4x to between 2x and 4x if plain int8 takes over 6 ms (an engine under about 78% of peak bandwidth).
- **H134 (shrink committed volume), narrowed by this count.**
  - **(a) packing:** its gate "kill if the packable share is under 40%" **passes narrowly (44.7%)**, but the ceiling of a 4x
    packing is 66.8% of today's rows and a floor of 3.4x plain. It cannot reach 2x by itself.
  - **(b) chaining linear layers:** counts to near zero (every matmul output feeds a requantization and a range lookup); the
    11.6% of rows that are matmul inputs and outputs is a ceiling, not an estimate. **Drop (b) unless a design shows a chain
    that skips the requantization.**
  - **The largest category is neither:** the 2,514 helper rows (49.3%) are full-field and unpackable; only removing them
    (the B5 / LogUp-GKR line, measured at W16 on 2026-11-01 for a leaf, not yet for a whole block) halves the volume. A
    realistic route to 2x on volume needs that **and** packing.
- **H135 (B6b):** unaffected; it shrinks the receipt, not the committed codeword volume (+13 to +42 ms per block of added work).

## 8. Corrections and cautions

- **Cycle 3:** its "about 40 GB" of codewords is 43.2 GB; its "about 166,000 rows" is 164,548 regular rows plus 1,600 M rows.
  Its "plain is about 5-8 ms" is 4.4-5.0 ms memory-bound at peak bandwidth (an assumption, below).
- **Assumptions that carry the result and are not verified here:** the 5090's 1.792 TB/s peak and its dense int8 (838 TOPS)
  and fp16 (210-420 TFLOPS) peaks. The int8 verdict (4.8-5.5x) holds for any bandwidth and any compute peak that leaves the
  plain pass memory-bound at batch 1; for floor W it drops below 4x only if plain int8 at batch 1 is slower than about 6 ms. The fp16 verdict
  (2.6-2.8x) depends on the fp16 peak being 210 TFLOPS or more.
- **The plain baseline here is a roofline, not a clock.** A real engine reaches 60-90% of peak bandwidth; that lowers every
  ratio by that factor: floor W against a plain int8 engine at 60-90% of peak is 3.1-4.6x (between 2x and 4x below about 78%
  efficiency), floor WH 5.8-9.9x. [DERIVED]
- **The floor treats a codeword word as 8 bytes.** That is the code's own word (`pcs.rs`), not an assumption.
- **Boundary rows (38) are COUNTED from the formula** (`boundary.rs:186`) and only checked by the total receipt's integer
  fit; endpoint rows (37) are tied to a measured 761,728 B opening.
- **Token I/O stages are an estimate** (§1.3) and absent at W16R2.
- **Activation words as "required outputs":** I classed all 984 word rows as activations; the S-domain ZSEL, E and P planes are
  softmax intermediates and could be argued as helpers. Moving them (96 rows, 1.9%) changes no conclusion.

## 9. Status

- New full-stack proofs, passes and proved positions: **0 / 0 / 0.** The complete private 8B at >= 50 proved tokens/s on an
  RTX 5090 (D64 target about 110) remains **unachieved**.
- Hypotheses: **135** (none added). No `progress/` entry or `PROGRESS.md` refresh was written.

## 10. Next concrete actions (each needs no new permission to prepare)

1. Owner decision, or the other coordinator's: keep or drop "2x" as a planning number for the committed-everything design;
   this note's counts are the evidence. If kept, restate it against fp16 with the floor above, not against a plain pass
   it cannot approach.
2. H133(b) timing when the Mac's GPU is quiet, and when the 5090 is up: plain int8 and fp16 prefill of 128 tokens on a mature
   engine at batch 1 and 8. It replaces §3's roofline and the three unverified 5090 figures.
3. Re-run the row census when W16R3 lands (B1-B3 are 4,859 rows per block, `model.py:246`) and when a W16R2 token-I/O profile
   is registered, to replace §1.3's estimate. The script's constants are the only edit.
4. Measure the share of the prover's time that scales with committed rows (the encode, commit and fold phases) on a block
   fork, to turn the floor into a bound on speed-up from any volume cut. Not needed for the verdict.
