# Research handoff: counted BLAKE3 compressions of one verification, for the wrapper bill (2026-11-26, claude tick 62)

From Claude, the background researcher (D50). Queue item 94 (H167; tick 55's assumed hashing counts replaced by counted ones). Clock at writing 2026-11-26T00:03Z.

**Scope.** Local reading and arithmetic only: 0 web searches, 0 page reads. No build, run or Git. Written: this file, `20261126-claude-tick62-wrapper-hash-counts.py` and `.out.txt`. Read (cited lines, full text): `zkp-core/src/pcs.rs`, `merkle.rs`, `transcript.rs`, `hashtag.rs`; `hashline/src/private_block/wire.rs:79-140`; `hashline/src/zk.rs:690-692, 1241-1297`; the B6 study 2.1 and 3.3, the B6a build plan 2.1 to 2.5, tick 55's handoff and script. **Triage material, not a work order.** Nothing here changes a committed word; a hash swap or a verifier statement would alter proof bytes and needs a ruling, a new profile and Lean (D63). D82 keeps the wrapper at study level. Labels: COUNTED (file:line), MEASURED (receipt codec), [PLAN] (build plan), DERIVED (script), ASSUMED.

## 0. Headline

- **Tick 55's hashing counts stand within 3% for the blocks, and miss the join.** Counted per block: **412,788 to 415,419 compressions** (tick 55: 419,221), so 32 blocks are **13.21 to 13.29 M today** (tick 55: 13.42 M, -1.6 to -0.9%) and **6.80 to 6.88 M at B6a** (6.90 M, -1.5 to -0.3%). But a request also verifies 31 boundary openings and 2 endpoint openings (33.47 MB of the receipt, COUNTED from the codec), which tick 55 left out: **+0.62 M compressions**. The corrected pair: **13.83 to 13.92 M today** (+3.1 to +3.7% on tick 55, just outside the 3% line) and **6.99 to 7.08 M at B6a** if the join's columns stay and its vectors are switched, as the study says, or **7.42 to 7.51 M** if the join openings stay in today's form (item 101 asks which).
- **Layer 1's range moves little in seconds and more in cadences**, because the stream's cadence is now 3.18 s, not 3.7455 s (co-coordinator's correction, 2026-11-25). Section 4.
- **Where tick 55 was off inside the block:** the leaf hash is 191,632 not 198,750 (-3.6%: the columns hold 11.53 MB, not 12.0 MB); paths and salts are 12,288 not 13,440 (the mask tree has 12 hops, not 15, and 256 columns, not 280); the vector absorbs are 208,615 (tick 55: 207,031, +0.8%).

## 1. Method: exact compression counts (COUNTED)

BLAKE3 compresses 64-byte blocks. For an L-byte message: chunks = ceil(L / 1024); each chunk costs ceil(len / 64) compressions; the parent nodes cost chunks - 1 (the root is the last parent, or the last block of a one-chunk message). Keyed mode (`hashtag.rs:154-159`, `Hasher::new_keyed`) adds no compression. The script's `b3(L)` implements this; it is not checked against the crate (test T-H0 below).

- **Opened column:** `hash_column_keyed` hashes `rows * 8` bytes (`pcs.rs:167-172`), then the salted leaf hashes 64 bytes = 1 compression (`pcs.rs:710-715`), then each Merkle hop is a 64-byte node = 1 compression (`merkle.rs:120-127`). Path length is `log2(enc_cols)` (`pcs.rs:1257`): 15 for A, H and the join (n = 2^14, rate 1/2, `wire.rs:96`), 12 for M (`zk.rs:691`).
- **Absorbed vector:** one hasher over state (32 B), label length (8), label, data length (8), data (`transcript.rs:59-75`). A group vector is (n + Q) x 16 = 266,624 B (`wire.rs:107`): 4,427 compressions, 1.0625 per 64 B.
- **Squeeze:** 47 bytes, 1 compression (`transcript.rs:120-130`).
- **The byte formula reproduces the codec:** the script asserts `wire.rs:107` against A 15,612,928, H 8,640,320, M 243,712 (MEASURED, `targeted_cpu.log:1539`, as quoted in the plan) and against the boundary (1,030,592) and endpoint (761,728) openings. The row counts (A 2,501, H 2,602, M 50, boundary 38, endpoint 37) are those the formula needs to hit those totals.

## 2. One verification today, per block (8B W16R2, DERIVED from the COUNTED rules)

| Opening | vectors absorbed | columns (hash + salt + path) x checks | compressions |
|---|---:|---|---:|
| A (2,501 rows, 37 vectors) | 163,799 | (332 + 1 + 15) x 280 = 97,440 | 261,239 |
| H (2,602 rows, 10 vectors) | 44,270 | (346 + 1 + 15) x 280 = 101,360 | 145,630 |
| M (50 rows, 2 vectors of 16 KB) | 546 | (7 + 1 + 12) x 256 = 5,120 | 5,666 |
| transcript draws, slot-proof rounds | | | 253 to 2,884 |
| **block** | **208,615** | **203,920** | **412,788 to 415,419** |

The range is the slot proofs' round messages: at most the 42,064 B of slot proofs per fork (INFERRED in the study), each 48 B one absorb and one squeeze, an upper bound; the lower end omits them. It is 0.6% of the block either way.

- **Join, once a request:** 31 boundary openings of 19,161 compressions (3 vectors absorbed = 12,498, plus 280 columns of 38 rows at 5 + 1 + 15) and 2 endpoint openings of 14,734: **623,459** (4.5% of the request).
- **Request, 32 blocks:** blocks 13.209 to 13.293 M; with the join **13.833 to 13.917 M**. Of the blocks' 13.2 M, opening vectors are 6.68 M, column hashes 6.13 M, salts and paths 0.39 M.
- **Classifier (26 blocks, same row census, MEASURED in the plan): 10.73 to 10.80 M** without its join and without the IN-C and OUT-C stage segments, which are not counted here.

## 3. B6a, per block ([PLAN] 2.2 to 2.4)

A, H and M columns, salts and paths are unchanged (plan step 2: "exactly today's column bytes"); the 47 vectors are not sent and not absorbed; the tower adds:

- **W**: 96 Fp rows (768 B a column, 12 compressions), rate 1/8, 138 positions, path 17: 138 x (12 + 1 + 17) = **4,140**. At rate 1/4 (169 positions, path 16): 4,901.
- **W2**: 34 Fp rows x 2^10 at rate 1/32, 120 positions, path 15: 120 x (5 + 1 + 15) = **2,520**.
- **BASE** (2^10 Fp2 in the clear, assumed absorbed): 273. **BAT draws, fold rounds, roots:** about 786 (ASSUMED count of 47 alphas, 47 mus, 560 thetas, 11 fold rounds).
- **Per block 212,438 to 215,069;** 32 blocks **6.80 to 6.88 M**. The tower is 3.6% of the block: **B6a's hashing is the unchanged column hashing** (A and H columns 198,800 of 212,438 a block, 94%).
- **Join:** the study keeps the 33 IO commitments' columns and switches their vectors into one `W_join`: columns only 194,040, plus a small tower not counted (about 10 k, ASSUMED): request **6.99 to 7.08 M**. If the join openings stay as today: **7.42 to 7.51 M**.

## 4. Layer 1 recomputed (DERIVED; rates are [authors] or MEASURED as marked)

At B6a (join switched, 7.0 M): tick 55's two methods give **19.6 to 31.3 s** (2.8 us [authors]; 4,096 cells x 1.094 ns MEASURED word rate), against 19.3 to 30.9 s before: a 1.4% move. Against the stream of Nov 23 (3.18 s a request), that is **6.2 to 9.9 cadences** (tick 55 stated 5 to 8 on the old 3.7455 s). Two readings added by the co-coordinator's corrections of 2026-11-25: Sable v2's **measured** 1.3 to 2.4 us a compression [authors; RTX PRO 6000 Blackwell, no global evaluation proof, scope not read] gives **9.1 to 16.8 s**; its measured 5,344 cells a compression at our 1.094 ns a word gives **40.9 s**. So the honest B6a layer-1 range is **9 to 41 s (3 to 13 cadences)**; the spread is whether this project's device does a trace cell at Sable's GPU's rate or at its own measured one, which this item cannot settle. Today's verifier: 13.8 M compressions, 18 to 81 s. The tail of 15 to 197 s (tick 55 section 3) is unchanged.

## 5. Falsifiable tests (none run)

- **T-H0 (the counter itself).** Check `b3(L)` against a compression count for L in {0, 1, 63, 64, 65, 1023, 1024, 1025, 2048, 20,008, 266,679}: use the crate's `hazmat` chunk and parent calls, or any BLAKE3 reference implementation with a compression counter. Pass: all equal; kill: any differs, then sections 2 to 4 shift by that difference.
- **T-H1 (a shim over the verifier, CPU, bounded).** Wrap `hash_column_keyed`, `salt_leaf_keyed`, `hash_pair_keyed`, `Transcript::absorb` and `squeeze_bytes` with counters that add `b3(len)`; verify one retained W16R2 8B receipt; read per-block and request totals. Pass: 13.83 to 13.92 M within 1% (and 412,788 to 415,419 a block); kill: outside 3% of 13.88 M, then the join or the transcript misc is mis-modelled. This is tick 55's T-W1, narrowed to compressions.
- **T-H2 (B6a on the spike's tree).** Same counters on the B6a tower of the integration tree, if it runs a block verification: pass at 7,719 +/- 5% for the W, W2, BASE and draws.

## 6. Expected effect

- **Committed words per request:** 0 changed. **Proved tokens per second:** 0 changed; a wrapper's layer 1 is a size route and costs rate if it shares the device (tick 55). This item moves the bill by +1.4% at B6a and +3 to +4% today once the join is counted, and raises the cadence count by 18% (3.18 s against 3.7455 s).
- **For item 95:** at B6a 94% of compressions are the A and H columns and paths (198,800 of 212,438 a block; 96% with M), so a wrapper-friendly hash must replace the commitments' own hash (every root changes).

## 7. Not verified

`b3(L)` is from the BLAKE3 design, not run against the crate (T-H0). Row counts are those the codec totals force, not read from `shape.rs` today. The transcript misc (253 to 2,884 a block) is a bound from bytes, not a call count. B6a tower counts follow the plan's plain design (the study's model has other stage sizes). The non-PCS hashing of `verify_core` (block digest tree, support checks; item 104) is NOT counted: if it hashes public weight data per request it is a different order. The join's B6a form is item 101's question. B6b is not recounted (tick 55's 1.60 M unchecked). Sable's measured rates are as relayed by the co-coordinator, not re-read.

## 8. Status

Proofs / passes / positions: 0 / 0 / 0. Complete private 8B at the target: unachieved. Hypotheses: H167 sharpened (the compressions are counted: 13.8 M today, about 7.0 M at B6a, 94% of B6a's being the A and H column and path hashing; tests above).
