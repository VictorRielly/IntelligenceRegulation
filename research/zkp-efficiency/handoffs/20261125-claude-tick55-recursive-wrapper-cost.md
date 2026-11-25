# Research handoff: what a recursive wrapper for kilobyte receipts costs for this verifier (2026-11-25, claude tick 55)

From Claude, the background researcher (D50). Queue item 90 (the co-coordinator's request on the owner's question about kilobyte receipts). Clock at writing 2026-11-25T00:06Z.

**Scope.** Local reading and arithmetic, 6 searches, 7 page reads (one failed: the ePrint host returned HTTP 403 for 2026/2877; the RISC Zero recursion page has no numbers). No build, run or Git. Written: this file and `20261125-claude-tick55-recursive-wrapper-cost.py` / `.out.txt`. Read: `W16R3_DESIGN_B6_20261105.md` 3.3 (verifier counts); the B6a build plan 1.3 and 2.4; `ZK60_DECISIONS.md` D3 to D6, D27, D82; tick 54 (weight fold and opening bytes); `argument.rs:3205-3212, 3350-3353` of `ops/zkp-mvp/gpu-metal/hashline`; `pcs.rs:695-700`; Sable (arXiv 2611.14083) in full through Section 10.2 (the HTML text stops inside Lemma 10.1, so Section 10.3 is unread); the Plonky3 PR 2533 description; the Alpen benchmark page. **Triage material, not a work order.** A wrapper sits outside the committed words, so it changes no proof byte of the inner receipt; a new hash inside the commitments, a trusted setup for the custom line, or a verifier statement does need the owner's ruling, a new profile (D17) and Lean (D63). D82 keeps the wrapper at study level. Labels: COUNTED, MEASURED, [AUTHORS], DERIVED (script), ASSUMED.

## 0. Headline

- **The verifier's BLAKE3 hashing is what a wrapper has to pay for, not its field arithmetic.** One request's verification is **13.4 M BLAKE3 compressions today, 6.9 M after B6a, 1.6 M after B6b** (DERIVED; 64 B compressions of the hashed and absorbed bytes plus paths), against 1,062 M, 53 M and 2.6 M column products. Hashing is 97% of B6a's wrapper cells (script, 3.0% for the products).
- **Layer 1 in this project's own system: 19 to 31 s a request at B6a, 4.5 to 7 s at B6b** (DERIVED from Sable's 2.8 us a compression [AUTHORS] and from our measured 1.094 ns per committed word at Sable's naive 4,096 cells a compression). That is 5 to 8 cadences at B6a and 1.2 to 1.9 at B6b, on top of a **constant tail of 15 to 197 s** for the shrink and Groth16 steps. Run serially on the proving device the request rate falls to 0.11 to 0.16 of today's at B6a, 0.34 to 0.46 at B6b.
- **Today's verifier cannot be wrapped at all as written:** it folds the 7.0 GB of public weights (14 G mults, tick 54), which is 224 G cells, 84 times the request's committed words. A wrapper needs a committed-weight opening in its place (item 13 prices that; about 3.9 M more compressions at 2^16-wide rows, DERIVED, shape ASSUMED).
- **Kilobyte receipts mean a trusted setup.** The only sources that reach under 1 kB use Groth16 (128 to 785 B); transparent routes stop at 140 to 870 KiB. D4 accepts the setup for the zkVM line only.

## 1. The verifier's work for one request (32 blocks)

Per block, from the B6 study table [MODEL/CODE] times 32; compressions are DERIVED in the script with an ASSUMED 1.06 factor for BLAKE3's parent nodes over ~21 KB columns, plus 13,440 compressions a block for paths and salted leaves (ASSUMED 280 columns x 3 trees x 15 hops; salts COUNTED in kind, `pcs.rs:695-700`).

| | today | B6a | B6b (2^18) |
|---|---:|---:|---:|
| bytes hashed per block / absorbed per block | 12.0 / 12.5 MB | 12.2 / 0 | 2.2 / 0 |
| **BLAKE3 compressions per request** | **13.42 M** | **6.90 M** | **1.60 M** |
| column products per request | 1,062 M | 53.4 M | 2.6 M |
| NTT points per request | 98.6 M | 0.13 M | 0.13 M |

Cross-check against Sable [AUTHORS]: a 4,096-token proof of a 64-layer model, 360 MiB, had a verifier doing 17.8 M compressions (10.6 M transcript, 7.2 M Merkle) and 11 M F_p4 multiplications; their cuts bring it to 4.22 M at 134.8 MiB. Ours is 0.017 M compressions per MiB of receipt today, theirs 0.049 and 0.031: the same order, and the compression count follows the bytes hashed, not the token count. A 128-token request therefore pays the same wrapper bill as a long one per block.

## 2. Layer 1: the verifier as a circuit, priced two ways

Sable's closest design is a proof, "in the same proof system", that the verifier accepts: a BLAKE3 G call is one row of 80 columns with 32 degree-3 constraints and 16 XOR-table lookups, 56 G rows a compression, wired by a LogUp memory; "naive" cost about 4,096 trace cells a compression and 16 cells an extension operation [AUTHORS, estimate, not measured]; layer 1 "about 10% of the main proof" [AUTHORS, estimate from their cost model]. Their compression cost is 2.8 us in the constraint proof [AUTHORS; scope and hardware not read].

- **Method M1:** compressions x 2.8 us. **Method M2:** compressions x 4,096 cells x 1.094 ns (this prover's block GPU 91.46 ms over 83.6 M committed words, MEASURED/COUNTED, all slots and commits together). They agree within 1.6x (2.8 and 4.48 us).
- **B6a:** 6.90 M compressions, 28.2 G cells (10.6 x the request's committed words), 19.3 to 30.9 s, and 6.2 G XOR lookups against the request's 1.03 G.
- **B6b:** 1.60 M compressions, 6.5 G cells (2.4 x), 4.5 to 7.2 s.
- **Today:** 13.42 M compressions, 37.6 to 60.1 s.
- **Why Sable's 10% does not carry over:** their main proof is a small-field system with a far larger main trace per compression; ours commits 2.68 G words a request, so the same BLAKE3 layout is 10x the main proof at B6a. This is a DERIVED contrast, not a refutation of their estimate in their system.
- **Cheaper hash is the lever only in a new profile:** Poseidon2 over the field is 29,640 permutation rows for a Plonky3 2^10 Fibonacci verifier at 6.52 s of recursive prover time [AUTHORS, PR 2533; hardware unstated], a different cost class from BLAKE3 bits, but our Merkle trees and salted leaves are BLAKE3 (`pcs.rs:158-198, 695-700`) and the GPU hash kernel is 3.4% of device work. Changing the hash alters every root and the Lean model.

## 3. The tail: shrink and Groth16, constant per request

- **MEASURED here:** the zkVM line's Groth16 wrap took 197 s with native tools on 2026-09-18 (D6; receipt 785 bytes; hardware as in that record, not re-read).
- **[AUTHORS, dated 2024]:** RISC Zero about 15 s STARK-to-SNARK on CUDA against 2.5 s for the STARK. A Plonky3-based settlement project reports 195 s end to end (48 + 26 + 59 shrink + 12 + 50 Groth16) [search summary, unchecked].
- **Sizes [AUTHORS]:** RISC Zero succinct receipt about 200 kB; SP1 compress 1.21 MiB, shrink 870.2 KiB, Groth16 about 260 B; Flock aggregation root 140 KiB (PR 2533); g16ckt baseline 128 B. Nothing found between 140 KiB and 128 B without Groth16.
- **Per request this tail is 4 to 53 cadences** (15 to 197 s over 3.7455 s), whatever B6a or B6b do: kilobyte receipts suit a batch or a background service, not a per-request stream, unless many requests share one outer proof (an aggregation tree: not priced).

## 4. Zero knowledge, soundness, trust

- **Zero knowledge:** the inner receipt already hides inputs, outputs and activations and is published today (P1). A wrapper reveals less than the receipt it replaces, so P1 privacy needs no extra mask if the wrapper's statement binds the same public values. Sable plans zero-knowledge outer layers as design intent only. The RISC Zero recursion page says nothing on zero knowledge.
- **Soundness:** errors add: inner whole run about 95 bits (D27), plus layer 1 and the Groth16 layer (about 100 bits per D3; the 97-bit figure is the zkVM STARK). The floor stays near 95; the claim must quote the sum.
- **Trust model:** Groth16 needs a trusted setup (D4, accepted for the zkVM intermediate's artifact only). Applying it to the transparent custom line is a new ruling. A transparent wrapper stays at 140 to 870 KiB.

## 5. Falsifiable tests (none run; all CPU-light)

- **T-W1 (count, verifier only, about the 2.3 s verify).** Count BLAKE3 compressions, F_p2 products and weight-fold mults in one verification of a retained W16R2 8B receipt, by a counting shim in the verifier build. Pass: 13.4 M within 10% and the fold at 14 G; kill: hashing under 6 M (the wrapper bill halves) or over 20 M.
- **T-W2 (cost per compression).** Prove 2^20 BLAKE3 compressions as a layout of 56 G rows in a toy slot set on the Metal prover, quiet GPU, through the guard. Pass: at most 3 us a compression (B6a layer 1 under 21 s); kill: over 6 us (B6a over 41 s, B6b over 10 s).
- **T-W3 (zkVM guest, execute only).** Run a guest that does 1,000 BLAKE3 compressions on the RISC Zero executor and read the cycles. Pass: under 1,500 a compression (B6a 10 G cycles); kill: over 5,000.

## 6. Expected effect

- **Committed words per request:** 0 changed (the wrapper is outside the inner proof); a B6a or B6b inner receipt is assumed, not required.
- **Proved tokens per second:** negative if the wrapper shares the proving device (0.11 to 0.16 of today's rate at B6a; 0.34 to 0.46 at B6b); zero if it runs on separate hardware, at the cost of 20 to 230 s of latency to the kilobyte receipt and a second machine. This is a size route, not a speed route.

## 7. Risks and what was not verified

Not verified: Sable's 2.8 us scope and hardware, and its Section 10.3 and 11.5; any BLAKE3 figure for a zkVM guest (none found); the compression counts of the real verifier (T-W1); the per-column byte sizes behind the 12.0 MB; Groth16's constraint count for the shrink step; the 197 s record's hardware; whether an aggregation tree across requests fits per-request receipts; the Plonky3 PR's 47.82 M-AND Flock verifier figure as read from a closed PR's summary. The weight-opening shape (3.9 M compressions) is ASSUMED from tick 54's row and rate.

## 8. Status

Proofs / passes / positions: 0 / 0 / 0. Complete private 8B at the target: unachieved. Hypotheses: H167 (the wrapper's layer-1 cost is the verifier's compressions, so hashed bytes per block are the size lever for it: B6b's 2.2 MB against B6a's 12.2 MB moves layer 1 from 19 to 31 s to 4.5 to 7 s; tests above).
