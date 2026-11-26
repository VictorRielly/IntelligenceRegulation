# Research handoff: which hash makes a wrapper cheap, and what it costs the commitments (2026-11-26, claude tick 67)

From Claude, the background researcher (D50). Queue item 95 (H167b). Clock at writing 2026-11-26T19:52Z.

**Scope.** Web reading and arithmetic: 5 searches, 9 page fetches attempted (3 refused: ePrint 2026/1931 and 2023/107 HTTP 403, the ToSC Monolith PDF an access-denied page; 6 read). No build, run or Git. Written: this file, `20261126-claude-tick67-field-hash-wrapper.py` and `.out.txt`. Read: `zkp-core/src/pcs.rs:158-198, 695-720`, `hashtag.rs:120-160`; tick 55, 62 and 64 handoffs; Plonky3 `poseidon2-air/src/columns.rs` (full); Plonky3 issue 476; the zeknox README; the QEDProtocol WebGPU demo page; a HackMD analysis of Monolith (secondary); the arXiv abstract 2608.08722 (not relevant). **Triage material, not a work order.** A new hash inside the commitments changes every root, the verifier and Lean's model (D63) and needs the owner's ruling and a new profile; D82 keeps the wrapper at study level. Labels: [authors], COUNTED, MEASURED, DERIVED (script), ASSUMED.

## 0. Headline

- **A field hash shrinks the wrapper's hashing by 16 to 41 times per permutation, and the wrapper bill at B6a from 9-41 s to about 0.4 to 2.7 s.** Cells a permutation (Plonky3 formula, COUNTED in `columns.rs`; Goldilocks width 12, 8 full and 22 partial rounds [two libraries' docs]): **248** at constraint degree 3, **130** at degree 7, against Sable's 4,096 (estimate) and 5,344 (measured) a BLAKE3 compression [authors]. Both absorb 64 bytes (rate 8 words).
- **The same swap makes the prover's commitment hash 8 to 50 times slower and costs the cadence 0.9 to 5.4 s a request at full pass-through** (DERIVED, section 3), because the prover hashes every encoded column, and a Goldilocks hash is about 740 multiplications a permutation where BLAKE3 is bit operations. It also makes the verifier's CPU hashing slower (section 4).
- **So the hash swap is a trade, not a free lever:** the wrapper, if built, gets cheaper by seconds; every request pays more device time. The constant tail of 15 to 197 s (tick 55 s3) is untouched, so a per-request kilobyte receipt stays out of reach either way. The salted-leaf and node rules carry over (section 5). Nothing is recommended.

## 1. Cells a permutation

`columns.rs` [COUNTED]: columns = WIDTH + (2 x HALF_FULL x WIDTH + PARTIAL) x (SBOX_REGISTERS + 1). With 12, 4, 22: 12 + 118 x (R + 1) = **248 at R = 1** (x^3 kept in a register, constraint degree 3) and **130 at R = 0** (degree 7). The pairing of degree and registers is ASSUMED from the struct names. Sable's BLAKE3 gadget is 4,096 cells a compression (design estimate) or 5,344 (measured, tick 64 check) [authors]. Ratio: 16.5 to 41.1 times fewer cells for the same 64 bytes. Hash alternatives read only through secondaries: Monolith-64 is 210.5 ns natively against Poseidon2's 1,291.5 ns (Goldilocks, t = 12, variable-time) and has degree-2 nonlinear constraints, but no AIR width was found; Tip5 uses lookups. Their cell counts are **not verified**, so they are not priced.

## 2. Permutations in one verification (DERIVED from tick 62's counted rules, rate 8)

An opened column of 2,501 or 2,602 words is 313 or 326 permutations (BLAKE3: 332 compressions with parents); salted leaf and each node are one permutation (4 + 4 words, exactly the 64 bytes BLAKE3 takes). Result: A column 329 (BLAKE3 348), H 342 (362), M 20 (20); absorbed vectors 196,314 (208,615). **Block today 389,567 to 392,198 permutations (BLAKE3 412,788 to 415,419); B6a block 200,702 (212,438 to 215,069); request at B6a 6.63 M (6.99 to 7.08 M).** The count falls 5 to 7%, no more: 94% of B6a's hashing is the columns' own bytes, which a different hash absorbs at the same 64 bytes a step.

## 3. Wrapper and commitments, in cells and seconds

**Wrapper layer 1 at B6a** (DERIVED): hash cells 1.64 G (R = 1) or 0.86 G (R = 0), plus the verifier's extension products 53.4 M x 16 cells [authors' estimate] = 0.85 G. Total 1.72 to 2.50 G cells. At this prover's measured 1.094 ns a word: **1.9 to 2.7 s** (0.6 to 0.9 cadences at 3.18 s). At Sable's measured per-cell rates (0.24 to 0.45 ns): 0.4 to 0.7 s. The same method on BLAKE3 gives 32 to 42 s here, which agrees with tick 62's 9 to 41 s upper end. So the honest range for a field-hash wrapper is **0.4 to 2.7 s**. The 0.85 G of extension products now equals the hash part, so the ext-op cell count (16, an estimate) becomes the next unknown.

**Prover commitment hash** (DERIVED): `hash_columns` hashes every column of every encoded matrix. A + H: 5,103 rows x 2^15 = 167.2 M words (1.34 GB), 20.9 M permutations a block. Today's kernel: 3.4 to 3.9 ms (tick 42; the share is 3.4% of device work). Multiplications: about 736 a permutation (x^7 as 4 products in 118 S-boxes, plus 12 diagonal products in 22 partial rounds; ASSUMED), 15.4 G a block. Device mulmod rate, two bounds: **89.6 G/s** implied by the forward NTT (1.25 G butterflies in 14.0 ms, a lower bound since the NTT is partly traffic-bound; row pairing ASSUMED) gives **172 ms** a block; an ASSUMED hardware ceiling of 478 G/s (80 cores x 128 lanes x 1.4 GHz / 30 operations) gives **32 ms**. Extra over BLAKE3: **+28 to +168 ms a block, +31% to +184% of block GPU 91.46 ms, +0.9 to +5.4 s a request** at full pass-through against a 3.18 s cadence (tick 22 rule a: the stream is not GPU-paced, so some may be hidden; I do not claim how much). The one published Apple-GPU point is a browser WebGPU demo on an M1 Max: 2^16 leaves in 177.2 ms and 2^20 in 2,119.3 ms (leaf width and permutation width unstated); at one permutation a leaf and a node that is 1.0 to 1.35 us a permutation, 21 to 28 s a block here, an upper bound from an unoptimised path, and 100 times the NTT-implied figure, which shows the real rate is not settled by reading. zeknox (CUDA, NVIDIA L4): 8,192-leaf Poseidon2 Merkle 8.4 ms with GPU, leaf width unstated.

## 4. Verifier CPU

Plonky3 issue 476 [authors, unoptimised dev build, width 16, 2^13-leaf Merkle]: Poseidon2 is about 2.4 times slower than Keccak and **9 times slower than Blake3** on Goldilocks. At 1,291.5 ns a permutation (secondary, Monolith page) the B6a request's 6.63 M permutations are **8.6 s on one thread**, against tick 58's whole B6a verifier of 1.46 to 2.93 s one-thread; no retained BLAKE3 time for the hashing part alone exists, so the increase is not netted out. Wrapper or not, the verifier slows by seconds on a CPU.

## 5. What carries over (COUNTED)

- **Salted leaf** (`pcs.rs:695-707`): H(leaf || salt) of 32 + 32 bytes is 4 + 4 words, one permutation; a 32-byte salt becomes four sampled field words (255.99 bits, still above the 128 needed for the leaf).
- **Keys** (`hashtag.rs:127-160`): the four keys (transcript, column, leaf, node) of 32 bytes map to the 4 capacity words, which keeps the leaf/node separation of ruling T-1; each key must be re-derived as four canonical field elements.
- **Digest** 4 words = 255.99 bits, capacity 4 words; instance security (rounds 8 and 22) is as stated by two libraries, **not verified** here, and a field hash needs its own Lean model and security claim (D63).

## 6. Falsifiable tests (none run; T-P2 and T-P3 are CPU-light)

- **T-P1 (device).** A standalone Metal kernel hashing the A + H encoded matrix (167.2 M words, column sponges of 2,501 and 2,602 words, rate 8) beside the shipped kernel, quiet GPU, guarded. Pass for the swap to be considered: at most 10 ms (extra 7 ms, 0.22 s a request); kill: at least 30 ms (extra +26 ms, +0.8 s a request).
- **T-P2 (count).** Instantiate Plonky3's Poseidon2 AIR for Goldilocks width 12 and read its width. Pass: 248 (or 130) exactly; kill: more than 20% off, and section 1 moves.
- **T-P3 (CPU).** Time one width-12 Goldilocks permutation, one thread. Pass: at most 400 ns (verifier hashing at most 2.7 s); kill: at least 1.3 us.

## 7. Expected effect

**Committed words per request:** 0 changed by the hash itself (it hashes the words; it does not add words). **Proved tokens per second:** negative at full pass-through, a cadence of 4.1 to 8.6 s (rate x0.37 to x0.78) if the whole extra device time lands on the stream; zero for the wrapper's benefit unless a wrapper is built. This is a size route's trade, not a speed lever; do not schedule beyond T-P1 to T-P3.

## 8. Risks and what was not verified

Not verified: the pairing of degree and register count; Poseidon2's round numbers and security for this use; the extension-op cell count (16, Sable's estimate); my 736-multiplication count and the 30-operation mulmod; the rows pairing behind 89.6 G/s; the width and leaf shape of the WebGPU and zeknox figures; the Monolith and Tip5 cell counts (ePrint pages refused); the 1,291.5 ns figure (a secondary page, not the paper). The prover's hash cost also includes memory traffic and the Merkle levels, not modelled.

## 9. Status

Proofs / passes / positions: 0 / 0 / 0. Complete private 8B at the target: unachieved. Hypotheses: H167b (a field hash cuts the wrapper's layer 1 by 16 to 41 times a permutation, 9-41 s to 0.4-2.7 s, and costs the commitments 28 to 168 ms of device time a block; tests above).

## Coordinator's check (2026-11-26)

The script was re-run by the co-coordinator with the heavy lock free: the output is identical. My cross-check (`20261126-claude-tick67-field-hash-wrapper-crosscheck.py`, output beside it; 80 checks, all passed) does three things without importing the tick's script: it finds the quoted rows and sentences in my own downloads of the public pages, it finds the figures taken from ticks 21, 42, 55, 58, 62 and 64 and the cited code lines where they stand, and it recomputes every derived figure of sections 0 to 5 from the inputs.

**Read by me in my own copies:** the proving library's column layout (`poseidon2-air/src/columns.rs`) and constraint function (`poseidon2-air/src/air.rs`); the round numbers in that library's Goldilocks file and in the hash designers' reference instance (width 12, S-box degree 7, 8 full and 22 partial rounds in both); the issue the 9-times ratio comes from, with its eight comments; the GPU library's page (8,192 leaves: 30.9 ms on the CPU, 8.4 ms with one NVIDIA L4; leaf width not stated); the browser demo's page (Chrome on a 2021 M1 Max, 177.2 ms and 2,119.3 ms); the secondary page on Monolith (table "Native speed (Goldilocks prime, t=12)": 210.5 and 1,291.5 ns in its variable-time column).

**Carried forward [reading and arithmetic; nothing built or run]:**

- 248 cells a permutation at constraint degree 3 and 130 at degree 7. The pairing of degree and registers, which section 1 marks ASSUMED, is in `air.rs` (`eval_sbox`): with one register the AIR commits x^3, asserts that it equals the cube and returns its square times x; with none it returns x^7.
- The permutation counts of section 2, and that the count of hash steps falls only 5 to 7%.
- The direction: cheaper hashing inside a wrapper, dearer hashing in the commitments, a slower checker; and that a swap changes every root, the verifier and the Lean model.

**Carried only as assumption-bounded ranges, not as measurements:** the 32 to 172 ms a block for the commitment hash (an assumed 736 multiplications a permutation, an assumed 30 operations a multiplication, two assumed device rates) and the +0.9 to +5.4 s a request that follows from it; the wrapper's seconds (the per-cell rates are another system's, measured on a different gadget, and this prover's time per committed word, which is not the rate of an AIR prover).

**Corrections.**

1. **Like for like, the cell ratio is 16.5 to 21.5 times and layer 1 is 0.6 to 2.7 s.** The 41 times and the 0.4 s use the 130-cell form, whose constraints are of degree 7. The BLAKE3 gadget it is compared with has degree-3 constraints (tick 64), and a prover's work per cell grows with the constraint degree. The handoff does not price that, so the 130-cell figures are a floor, not an estimate.
2. **Section 3's "0.4 to 0.7 s" does not match the rates it names.** At the faster rate alone (0.24 ns) the script gives 0.42 to 0.61 s; over both rates (0.24 to 0.45 ns) the range is 0.4 to 1.1 s. The overall 0.4 to 2.7 s does not change.
3. **Paths.** The lines cited as `zkp-core/src/pcs.rs:695-707` and `hashtag.rs:127-160` are in the GPU prover's tree, `ops/zkp-mvp/gpu-metal/zkp-core/src/`. The root `zkp-core/src/pcs.rs` has the salted leaf at line 640 and no `hashtag.rs` beside it.
4. **Monolith is not free of lookups.** The same secondary page says its Bars layer becomes small lookup tables inside a circuit, so section 1's contrast with Tip5 is too sharp. Neither hash is priced, so no figure moves.
5. **The 9-times ratio is weaker than it reads.** In the issue each leaf is one field element, the run is on one core in a `dev` build, and a maintainer replies that the Poseidon2 code was "rather unoptimized" at the time. The measured row gives 9.4 and the estimated row 11.7. It supports "several times slower on a CPU", not a number.

**Not carried:** the 8.6 s for the checker's hashing as more than a secondary figure (the 1,291.5 ns is from a summary page; the paper was refused to the tick and to me: the journal's address returned a bot check and the preprint server HTTP 403); any cell count for Monolith or Tip5; the 21 to 28 s from the browser demo as more than the handoff calls it, an upper bound from other hardware.

**My own remarks, counted and not tested.**

- *The trade cannot be split by tree level.* The cited issue proposes a fast hash at the leaves and a field hash above. That would not help here: 88 to 89% of the hashing a wrapper must re-do at B6a is the opened columns' own words (the leaf digests), and 99.4% of the prover's hashing is the same kind. Whichever hash digests the columns carries both costs.
- *A third figure for the commitment side.* Counting word operations (about 800 for a BLAKE3 compression: 7 rounds of 8 G functions of 14 operations, and 16 closing XORs; 22,080 for a permutation at the handoff's 30 operations a multiplication, additions left out) and applying the rate the shipped BLAKE3 kernel already reaches gives 27.6 times, 94 to 108 ms a block. It lies inside the handoff's 32 to 172 ms and rests on assumed counts too; test T-P1 is what would settle it.
