# Research handoff: what Sable v2's measured BLAKE3 rate covers, and whether it transfers (2026-11-26, claude tick 64)

From Claude, the background researcher (D50). Queue item 107 (H167b; tick 62 left layer 1 at 9 to 41 s by whether a trace cell costs what Sable's GPU measures or what this prover's own word rate implies). Clock at writing 2026-11-26T07:51Z.

**Scope.** Web reading plus arithmetic: 0 web searches, 5 page reads (arXiv abstract page; the PDF, which the fetch tool could not decode, so only its metadata was read; the arXiv HTML v2 in three windows, characters 0 to 100,000 for the outline, 100,000 to 200,000, 200,000 to the end; Sections 10.2 "Cost", 10.3 and 11.1 came from the last window, read through the fetch tool's summary, not as raw text). No build, run or Git. Written: this file, `20261126-claude-tick64-sable-scope.py` and `.out.txt`. **Triage material, not a work order.** Nothing here changes a committed word; a hash swap or a wrapper statement would alter proof bytes or the verifier and needs a ruling, a new profile and Lean (D63). D82 keeps the wrapper at study level. Labels: [authors] (Sable, Tomer Solberg, arXiv 2611.14083v2), COUNTED, MEASURED, DERIVED (script), ASSUMED.

## 0. Headline

**Check and correction, 2026-11-26 (co-coordinator, from the raw text of the paper's HTML v2, downloaded and searched; this does test T-S1 in part).** Confirmed word for word: 5,344 committed cells; 0.16 s and 2.4 us at 2^16 compressions (13 ms, 0.13 s, 15 ms); 0.33 s and 1.3 us at 2^18; the global evaluation proof "is not included"; the verifier's extension-field arithmetic "is not yet a circuit and is not included"; the zero-knowledge mode "is not yet built"; the hardware; and that 5.5 s and 12 s are projections ("At that rate ..."). Corrected: (1) the paper gives the cell count as 64 x 80 + 32 x 4 + 8 x 12, and its Figure 4 says "56 G rows per compression, padded to 64" with 32 input rows and 8 output rows a compression; finding 1's split (56 G calls plus 8 other rows, 83.5 cells a row) is not the paper's. (2) Finding 3's "mean of three warm runs" is what 11.1 says of the end-to-end tables (Tables 4 and 5); it says other numbers "are single warm runs" that differed by up to about 2% on repeats, and does not say which kind the block figures of 10.2 are. (3) The 2.8 us is in the abstract of v2 ("whose constraint proof costs 2.8 us per compression"); the paper does not relate it to the 2.4 and 1.3 of 10.2. (4) The BLAKE3 circuit is "in the same proof system" (abstract) and holds each 32-bit word as four bytes because it "does not fit in" the field (10.2), so its cells are elements of the 31-bit field. (5) The cost sentence calls the figure "the full cost of a block" and does not name the memory argument; it explains the lower rate at 2^18 by "the upper GKR layers", which belong to the lookup argument (the co-coordinator's reading, not a statement of the paper). (6) "the 3.5x of tick 62" does not resolve in tick 62's handoff. (7) The script's fit row uses 0.80 and 0.91 us where its own fit lines give 0.814 and 0.916 with their paired fixed terms; with those the row is 5.8 to 6.6 s. **Not carried forward:** the 6 s low end (two rounded points extrapolated 27 times past the larger one; the paper lists "segmentation into fixed-size circuits" among what remains, and 27 blocks at the 2^18 rate is 8.9 s, next to tick 62's 9.1 s) and the bandwidth scaling of Section 3 (the other GPU's bandwidth is from memory). **Layer 1 at B6a stays at tick 62's 9 to 41 s.**

- **The 1.3 to 2.4 us is a measured GPU time for proving a block of BLAKE3 compressions in Sable's own system, not for a verifier.** Scope [authors, Section 10.2 "Cost", as summarised by the fetch tool; quotes were limited to 125 characters]: commitment of the block's trace, domain proofs of its G, input, output and table rows, and the openings of its units at the domains' points. **Excluded: the global evaluation proof.** Not stated: whether the LogUp memory argument that wires the rows is inside the timed run.
- **No whole-verifier-in-circuit run exists** [authors, 10.3]: the verifier's extension-field arithmetic (11 to 17 M F_p4 multiplications) "is not yet a circuit and is not included"; F_p4 and F_p8 gadgets, a recorder, segmentation, outer layers and a final low-rate layer are unbuilt; zero-knowledge for the outer layers "is not yet built". The 5.5 s (64-layer 1x4K) and 12 s (16K) figures are projections from the block rate, not runs.
- **The text does not settle transfer; it sets a spread.** On this prover's device, layer 1 at B6a (6.99 to 7.08 M compressions, tick 62) is 9 to 41 s by the two readings of tick 62; a third reading from Sable's own two data points gives 6 to 7 s as a floor. The honest statement: **layer 1 is 6 to 41 s, 1.8 to 13 cadences at 3.18 s**, with the high end resting on this project's own word rate and the low end on Sable's GPU doing a cell at about a quarter of that.

## 1. What was read, and how

| Part | How read |
|---|---|
| Abstract page | full: single author; KoalaBear 31-bit field; BLAKE3 Merkle trees; RTX PRO 6000 Blackwell; not zero-knowledge |
| Section 10.1, "The G row", "Wiring", Lemma 10.1 start | fetch-tool summary of characters 100,000 to 200,000 (the text stops inside the proof of Lemma 10.1) |
| Section 10.2 "Cost", 10.3, 11.1 | fetch-tool summary of the last 20,000 characters, asked twice; consistent, but the summariser quoted only short excerpts |
| PDF | not decodable by the fetch tool; no local PDF text tool exists; the PDF was not read |

Section 11 beyond 11.1 (end-to-end tables) was seen only as numbers in the summary; the benchmark tables for the main proof were not read.

## 2. Findings

All [authors] unless marked.

1. **Cells.** A compression has **5,344 committed cells**, "30% above the 4,096 of the design estimate" (10.2). A G row is 80 columns, 32 degree-3 constraints and 16 lookups; one row proves one call of G (10.2 "The G row"). A 2^16-compression block is 2^22 G rows, so **64 rows a compression** (DERIVED: the 56 G calls of a compression plus 8 rows of input, output and table work; 64 x 80 = 5,120, leaving 224 cells, 83.5 cells a row on average). Field: the abstract names KoalaBear (31 bits) for the system; the BLAKE3 gadget's field is not stated in the text read, and F_p4 and F_p8 extensions are used for the verifier arithmetic.
2. **Rates.** 2^16 compressions: **0.16 s, 2.4 us each**, split about 13 ms commitment, 0.13 s domain proofs, 15 ms openings (sum 0.158 s, DERIVED). 2^18 compressions: **0.33 s, 1.3 us each**, "because the upper GKR layers are latency-bound and barely grow with the block". Projections: 4.2 M compressions (64-layer 1x4K verifier) about 5.5 s, "6% of the main proof" (5.5 / 92.5 = 5.9%, DERIVED); 9.2 M (16K) about 12 s, 3%. Both projections are the 2^18 rate (1.31 and 1.30 us, DERIVED).
3. **Hardware and timing.** One NVIDIA RTX PRO 6000 Blackwell Server Edition (96 GB GDDR7) in a Xeon 6776P host; GPU otherwise idle, checked before and after; mean of three warm runs, kernels compiled beforehand (11.1).
4. **Two figures for one thing.** The HTML window of characters 0 to 100,000 relayed the abstract as "a BLAKE3 circuit whose constraint proof costs 2.8 us per compression" (the arXiv abstract page read first did not contain it); Section 10.2 gives 2.4 and 1.3 us for the whole block proof (commitment, domain proofs, openings) and no 2.8. Tick 55's 2.8 us "in the constraint proof" is therefore the abstract's figure; how it relates to 2.4 and 1.3 (a different scope, an older measurement, or a rounding) is not stated in what was read. The 1.3 and 2.4 us are the section-level measurements and carry the scope above.

## 3. Setting the rate beside this prover (DERIVED, script)

- **Per-cell rate.** Sable: 2.4 us / 5,344 = 0.45 ns a cell at 2^16, 0.24 ns at 2^18 (this includes the domain proofs, not only the commitment). This prover: 1.094 ns a committed word (MEASURED, cited by ticks 55 and 62; it is the whole-proof time over committed words, so it is the same kind of quantity). Ratio 2.4x to 4.5x, the "3.5x" of tick 62.
- **Two things differ besides the code.** (a) Cell width: Sable's cells are 31-bit (4 bytes in a column, my assumption of the storage), ours are 64-bit Goldilocks words (8 B). (b) Memory: the Sable GPU is a 96 GB GDDR7 card; its bandwidth is ASSUMED about 1.8 TB/s from memory of the spec sheet, not read this tick; this machine's copy roofline is about 700 GB/s (MEASURED, K0 in the queue notes). If the work is bandwidth-bound, the factor is 2.6x for bandwidth and 2x for width: **1.3 to 2.4 us becomes 6.7 to 12.3 us here (bandwidth and width), or 3.3 to 6.1 us (bandwidth only)**; compare 5.85 us from our own word rate. So the high end of tick 62 is about what a bandwidth-bound transfer would give, and the 2.4x to 4.5x ratio is largely explained by hardware if the block proof is bandwidth-bound. The text does not say it is; the GKR layers are latency-bound, which scales differently.
- **Sable's own scaling.** Two points fit a fixed 0.10 s (0.095 to 0.112) plus 0.81 to 0.92 us a compression (DERIVED; rounding of the 0.16 and 0.33 s is the band). Extrapolated linearly to this request's 7.0 M compressions: 5.7 to 6.5 s on Sable's device (27 blocks of 2^18 compressions at 0.33 s each would be 8.9 s instead); the fit is a two-point extrapolation 27 times past the larger point and is a floor for Sable's GPU, not a prediction for ours.

| Reading (B6a, 6.99 to 7.08 M compressions) | Layer 1 | Cadences at 3.18 s |
|---|---:|---:|
| Sable fit, its GPU (floor) | 5.7 to 6.5 s | 1.8 to 2.1 |
| 1.3 us (2^18 rate), its GPU | 9.1 to 9.2 s | 2.9 |
| 2.4 us (2^16 rate), its GPU | 16.8 to 17.0 s | 5.3 |
| 5,344 cells x 1.094 ns, this prover | 40.9 to 41.4 s | 12.9 to 13.0 |

## 4. What the figures leave out

- **Extension-field arithmetic of the verifier** (11 to 17 M F_p4 multiplications for the 64-layer verifier) is not in the timing. This project's verifier has its own field products (tick 60's counts, item 104); they would be an extra circuit.
- **Zero knowledge.** The outer layers need hiding commitments and masked sumcheck and GKR messages; not built [authors, 10.3]. This project's P1 hides inputs, outputs and activations, but the inner receipt is already published, so a wrapper reveals less than it replaces (tick 55); a ZK-free layer 1 is therefore a lower bound on a hidden layer 2, not on layer 1's own cost.
- **The global evaluation proof** is excluded; the memory argument may be. Nothing to price them with in the text read.
- **The hash.** Sable proves BLAKE3 in a 31-bit system whose own commitments use BLAKE3; its block rate says nothing about a Goldilocks Poseidon2-type permutation (item 95).

## 5. Falsifiable tests (none run)

- **T-S1 (read the missing text, free).** Obtain the PDF of v2 as a local file or use the repository named in the abstract; read 10.2 "Cost", 10.3 and 11.1 in full. Pass: it states whether the wiring memory is in the timed run, the BLAKE3 gadget's field and code rate, and the 2.8 us origin. Kill: it names a different scope than this handoff's summary, then Section 2 here is replaced.
- **T-S2 (the transfer, bounded).** If a Metal bench of one 2^16-compression-sized trace of 5,344 columns x 64 rows at 8-byte words commit-plus-fold exists in the prover, time it. Pass: a commit-plus-fold time per cell of 0.45 ns (Sable's 2^16 rate) times the bandwidth ratio 2.6 and the width ratio 2, i.e. about 2.3 ns a cell, within 25%, which would put the transfer at the high end; kill: well under 1.094 ns a cell, then the low readings of Section 3 are the better guide. Caveat: Sable's 0.45 ns includes domain proofs, so this bench is a partial check only. This is only a commitment-and-fold bench, not the domain proofs; it is NOT scheduled and needs a quiet GPU.

## 6. Expected effect

- **Committed words per request:** 0 changed. **Proved tokens per second:** 0 changed; a wrapper's layer 1 is a size route and costs rate only if it shares the device (tick 55). The item narrows the layer-1 bill at B6a from 9 to 41 s to 6 to 41 s, and the low end is a different system's GPU.
- **For item 95:** a field hash that costs fewer cells a permutation than 5,344 moves this range, but the commitments' own BLAKE3 hashing (94% of B6a's compressions, tick 62) is what a wrapper must prove; a swap changes every root.

## 7. Risks and not verified

- Section 10.2 and 10.3 were read through the fetch tool's summary, not as raw text; the tool limits quotes to 125 characters. Numbers agree between two asks of the last window and with the 100,000 to 200,000 window's 10.1 statement (17.8 M compressions, original verifier).
- Section 11 tables were not read beyond what the summary gave; the PDF could not be decoded. The "2.8 us" of tick 55 does not resolve in the HTML read. The BLAKE3 gadget's field and code rate are not stated in the text read. The Sable GPU's bandwidth is from memory (ASSUMED). The claim that cost is bandwidth-bound is untested; latency-bound GKR layers go the other way.
- This prover's 1.094 ns a word is a whole-proof average on this machine and was not re-measured.

## 8. Status

Proofs / passes / positions: 0 / 0 / 0. Complete private 8B at the target: unachieved. Hypotheses: H167b sharpened (the 1.3 to 2.4 us scope is stated: a GPU time for a trace-and-domain-proof block, no verifier, no ZK; layer 1 at B6a 6 to 41 s; tests T-S1, T-S2 above, not scheduled).
