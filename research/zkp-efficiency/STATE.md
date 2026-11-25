# ZKP efficiency explorer — durable state

**Deferred levers:** read `DEFERRED.md` before proposing a new profile. Coefficient-form rows (H117b) were deferred by Victor on 2026-11-03: not in W16R2; a candidate for a later profile.

## 2026-11-25: Claude researcher tick 58, the verifier's side of the size step, per request (claude-cycle, queue item 98)

**COMPLETE, local reading and arithmetic only** (0 searches, 0 fetches); no run, no build, no Git. Triage material (no ruling). Clock at writing 2026-11-25T07:55Z.
[Handoff](handoffs/20261125-claude-tick58-verifier-side-b6a.md), script `20261125-claude-tick58-verifier-side-b6a.py`, output `...verifier-side-b6a.out.txt`.
- **Pass, and the study's verifier figure is too low a cost:** the spike's one-thread verifier is BAT 14.4 to 16.1 ms plus tower 24.9 / 28.9 / 43.2 ms a block (MEASURED, rates 1/8, 1/4, 1/2); the tower decomposes into switch step 17.4 / 21.3 / 35.3, fold replay 5.2 and 2.6 left (DERIVED). At six threads, BAT + tower alone is 0.21 to 0.31 s at an ideal six-fold, above W16R3 study 3.3's 0.15 s for the whole PCS part (x5 to x15, ESTIMATE). That study's calibration (2.31 s x 6 / 32 = 433 ms CPU a block) is x3.05 above the one-thread record (4.54 s / 32 = 142 ms, `a12merge_d55_ab.log:227`; D12a vs D55 verifiers).
- **Per request, 32 blocks, one thread:** 1.46 to 2.93 s as built against today's 4.54 s (x1.6 to x3.1); 1.11 to 2.04 s with tick 56's rational switch row, which reaches the verifier unchanged (BAT + tower flat at about 28 to 29 ms a block over the rate); six threads 0.27 s (perfect scaling) to 1.50 s (today's observed x1.96). Classifier (26 blocks): BAT + tower alone 1.02 to 1.49 s one thread; no classifier verify time is retained. Tick 56's fold items, device routes and tick 57's NTT removal are prover-only.
- **Outside the spike's timers:** the 12 MB column hashing (about 6.4 ms), the boundary openings (31 + 2, serial in the tail, `run_fork.rs:2929-2973`, unchanged under B6a), and the public-weight fold (14 G multiplications, 11 to 20 s one thread; the diagonal-weight records exclude it). Tests T-V1 (D55 verifier at 1, 2, 3, 6 workers with phase marks), T-V2 (spike timer on column authentication, rational row in the verifier), T-V3 (dense weights) stated, not scheduled. 0 committed words changed; verification is after the stream's clock, so no proved-tokens-per-second effect.

## 2026-11-25: Claude researcher tick 57, why the size-step spike's bridge runs a forward NTT and whether the device has the kernel (claude-cycle, queue item 97)

**COMPLETE, local reading and arithmetic only** (0 searches, 0 fetches); no run, no build, no Git. Triage material (no ruling). Clock at writing 2026-11-25T03:53Z.
[Handoff](handoffs/20261125-claude-tick57-bridge-ntt-basis.md), script `20261125-claude-tick57-bridge-ntt-basis.py`, output `...bridge-ntt-basis.out.txt`.
- **Pass: removable by committing in the other basis.** The tower's W code is coefficient-basis (`CoefficientRs::encode`: coefficient i times 7^i, zero pad, one forward NTT); `metal_commit_zk` takes evaluations and inverts them first (`metal.rs:2866`, then the coset head and forward NTT, `:2870`), so the spike's forward NTT of 96 rows (11.0 M butterflies, 5.88 ms MEASURED at 1/4) is undone on the device. Toy-size identity checked (n = 16): same codeword, q = 1 zero pad.
- **Existing kernels suffice:** the default path is the two-stage one (fused RS is off by default), so a coefficient-input entry skips the `MODE_COPY` pass and feeds the upload buffer to the `MODE_ZK` head; no new kernel. The device sheds 0.16 to 0.22 ms of its 1.18 ms (13 to 19% inverse share, TinyLlama staged logs, upper reading). 0 committed words changed; a source change in the prover's Metal file, so a ruling and the byte gates apply.
- **Host effect: -5.9 ms of the +99 ms at 1/4**; stacked with tick 56's list the remainder falls from about 29 to about 23 ms, still above the +15 ms line. Test T-B1 stated, not scheduled. Not checked: `pack`'s buffer layout, and whether any store fold or column call reads the stored rows as evaluations (new item 99).

## 2026-11-25: Claude researcher tick 56, where the size step's per-block host time goes, counted from Sol's pinned sources (claude-cycle, queue item 96)

**COMPLETE, local reading and arithmetic only** (0 searches, 0 fetches); no run, no build, no Git. Triage material (no ruling). Clock at writing 2026-11-25T02:13Z.
[Handoff](handoffs/20261125-claude-tick56-size-step-host-time.md), script `20261125-claude-tick56-size-step-host-time.py`, output `...size-step-host-time.out.txt`.
- **Pass: counts account for 86.9 of the 90.8 ms (96%) of BAT 16.95 + tower 73.84 ms at rate 1/4** (rates calibrated on the same record, so a consistency check). Largest phase: the first fold, 29.8 ms (5,963,776 Fp2 multiplications, confirmed, no parallel loop); then the switch step 21.3 ms (2.77 M entries at 7.7 ns, serial), the W2 commitment 20.8 ms (32 serial NTTs of 32,768 plus hash and tree), BAT 17.0 ms (1.64 M Fp2 multiplications, serial; it already uses the rational generator, dense 46 ms is a diagnostic).
- **Savings with identical bytes (DERIVED):** the switch step has a rational form (N/Z series, 11 NTTs, about 6 to 7 ms against 17 to 35) and `mul_base` alone halves it (c1 = 0); the fold repeats one claim (self-check 3.9 ms) and computes `dot(m1, c1)` that the target already fixes (5.2 ms). Device product sumcheck over 2^20 pairs, six rounds: 0.35 / 0.72 / 2.1 ms from the K5 ladders, so W plus fold is 1.4 / 2.4 / 4.8 ms against pass 3.0 and kill 6.0.
- **Stacking all of it leaves about 29 ms of host time at rate 1/4 against the +15 ms line** (bridge 5.9, tree 7.2, W2 tree 3.7, switch 6.3, BAT remainder); 0 committed words changed. Tests T-R1, T-F1, T-D1 stated, not scheduled. Items 97 and 98 added.

## 2026-11-25: Claude researcher tick 55, what a recursive wrapper for kilobyte receipts costs for this verifier (claude-cycle, queue item 90, H167)

**COMPLETE, local reading and arithmetic plus 6 searches and 7 page reads** (ePrint 2026/2877 refused, HTTP 403; Sable's Section 10.3 unread); no run, no build, no Git. Triage material (no ruling; D82 keeps the wrapper at study level). Clock at writing 2026-11-25T00:06Z.
[Handoff](handoffs/20261125-claude-tick55-recursive-wrapper-cost.md), script `20261125-claude-tick55-recursive-wrapper-cost.py`, output `...recursive-wrapper-cost.out.txt`.
- **The wrapper pays for the verifier's BLAKE3 hashing (DERIVED):** one request's verification is 13.4 M compressions today, 6.9 M after B6a, 1.6 M after B6b (column products 1,062 M, 53 M, 2.6 M; hashing is 97% of B6a's wrapper cells). Same order per MiB as Sable's verifier (17.8 M compressions at 360 MiB [authors]).
- **Layer 1 in our own system:** 19 to 31 s a request at B6a, 4.5 to 7 s at B6b (Sable's 2.8 us a compression [authors], and our measured 1.094 ns per committed word at their naive 4,096 cells); 5 to 8 and 1.2 to 1.9 cadences. Constant tail for shrink and Groth16: 15 s [authors, 2024, CUDA] to 197 s (MEASURED here, 2026-09-18, D6). Serial on the proving device the request rate falls to 0.11 to 0.16 (B6a) or 0.34 to 0.46 (B6b) of today's.
- **Today's verifier cannot be wrapped as is:** it folds 7.0 GB of public weights (14 G mults, 84 x the request's committed words); a committed-weight opening must replace it (item 13; about 3.9 M compressions more, shape ASSUMED).
- **Kilobytes mean Groth16 and a trusted setup** (128 to 785 B); transparent routes found stop at 140 to 870 KiB. Inner privacy needs no extra mask; soundness errors add (95-bit inner floor, D27). No BLAKE3-in-zkVM cycle figure found.
- Tests T-W1 (count compressions in one verification), T-W2 (2^20 compressions on the Metal prover; pass at most 3 us) and T-W3 (execute-only zkVM cycles) stated, not scheduled. 0 committed words changed. Items 94 and 95 added.

## 2026-11-24: Claude researcher tick 54, hidden weights (P3) priced on the W16R2 8B prover (claude-cycle, queue item 91)

**COMPLETE, local reading and arithmetic plus 3 searches and 4 fetches** (the zkLLM PDF did not extract); no run, no build, no Git. Triage material (no ruling; D82 keeps P3 at study level). Clock at writing 2026-11-24T15:55Z.
[Handoff](handoffs/20261124-claude-tick54-hidden-weights-price.md), script `20261124-claude-tick54-hidden-weights-price.py`, output `...hidden-weights-price.out.txt`.
- **Bytes are the main price (DERIVED from the wire formula):** a stable hidden-weight commitment adds 220 to 1,250 MB to the 818.7 MB 8B receipt (x1.27 to x2.5); best row 220 MB at 2^16-wide rows, rate 1/4, budget 16, one batched group (430 MB with seven groups); 146 MB once B6a removes clear vectors (ASSUMED tower).
- **Time unbounded by measurement:** row combination 0.09 to 2.5 s a request (2.5 to 66% of the 3.7455 s cadence; kernel rate 300 to 45 G mults/s); a fresh commit per proof 2.42 s (+65%, from the measured 46 GB/s commit rate); range proof once per model 3.3 to 4.6 s (ASSUMED). Verifier work falls about seven-fold (unmeasured; it stops folding 7.0 GB of weights).
- **Reuse budget:** k proofs need q_pad = k Q' and push the rate: rate 1/2 has no solution at k >= 16; rate 1/4 gives k = 16 at Q' = 182; stored matrix 223 GB at 1/4. Slot journal exists, nothing consumes it.
- **Lean:** T2's R <= 2^64 cannot hold for a stable commitment; the reuse simulator is unwritten; model identity is outside the two approved statements (owner's ruling). Tests T-P3a (kernel), T-P3b (bytes, 1/64 scale), T-P3c (claim merge) stated, not scheduled. Hypothesis H166 added.

## 2026-11-24: Claude researcher tick 53, device time of a masked LogUp-GKR lookup tree on Metal bounded from measured kernels (claude-cycle, queue item 87, H136b)

**COMPLETE, local reading and arithmetic only** (0 searches, 0 fetches); no run, no build, no Git. Triage material (no ruling). Clock at writing 2026-11-24T07:56:56Z.
[Handoff](handoffs/20261124-claude-tick53-lookup-tree-device-bound.md), script `20261124-claude-tick53-lookup-tree-device-bound.py`, output `...lookup-tree-device-bound.out.txt`.
- **The tree (COUNTED, prototype):** 2^25 leaves, 24 sumcheck layers, 300 rounds, 13 extension products a pair (DERIVED), 349 M products and 6.0 GB a block; layers 24 and 23 hold 67% of the top-down products; 66 (2^13 line) to 105 (2^10 line) device rounds, 24 layer hand-offs. Masked rounds add only transcript-step work (CFS mask, one degree-7 round a layer), not bulk work.
- **Bounds (device ms a block):** low 21.9 (15.7 without two ASSUMED terms), absolute floor 12.1 / 14.6 / 16.0 (K4 product rate, loads hidden, round cost 0.057 / 0.10 / 0.123 ms), stacked high 92.6. Rates MEASURED from K5 (slot 18: 29 to 53 ps a product; slot 14: 62 to 78), K0 (700 GB/s), K9 (transcript step 123 us, fast 57 to 85).
- **Against tick 52's saving of 11.47 to 12.06 ms a block (9.8 to 10.3% of cadence by the tick 22 rule; cross-check from tick 40 slot times 12.05 to 12.65): pass line (high under 5.74 ms) not met; kill line (low above the saving) fires.** The floor equals the kill line only at the most favourable corner.
- **Correction to tick 52's basis:** A also removes the 24 helper tables of slots 14 to 18, slot 19 and H's opening fold, 1.4 to 20.7 ms a block left out; gross saving 13.4 to 33.3 ms, net of the low tree and 6a's 9.4 ms leaf-claim term -17.9 to +2.0 ms (best case 1.7% of cadence). The 2026-11-01 helper-path 0.110 s (6a, projection.json) is stale: 18 to 33 ms today.
- Tests T-GKR (one layer-23-shaped kernel, go under 6 ms for layers 24 and 23) and T-H (drop the helper tables in the K5 harness) stated, not scheduled. 0 committed words changed.

## 2026-11-24: Claude researcher tick 52, net block volume of candidate B with helper-free lookups (claude-cycle, queue item 18, H152)

**COMPLETE, local reading and arithmetic only** (0 searches, 0 fetches); no run, no build, no Git. Triage material (no ruling). Clock at writing 2026-11-24T03:57:06Z.
[Handoff](handoffs/20261124-claude-tick52-ab-net-volume.md), script `20261124-claude-tick52-ab-net-volume.py`, output `...ab-net-volume.out.txt`.
- **B alone is 0.81 to 0.91 of today's block with helpers kept** (not 0.78 to 0.88): the digit lookup needs its own helpers while helpers are committed, 142 / 159 / 191 rows for C / C+M / C+M+W (DERIVED; tick 7's third commitment, left out of tick 49). With two byte lookups 0.90 to 1.00.
- **A alone (all lookups in the tree) is 0.49 to 0.52** (cycle 6a: 0.508 and 0.492; the spread is the claim sites the lookups' terminal claims put back on the block, 0 to 62). **A + B: 0.27 to 0.31 (C), 0.30 to 0.34 (C+M), 0.36 to 0.41 (C+M+W)** with field multiplicities; with tick 3's multiplicity bit planes 0.29 to 0.48 (+285 to +360 rows, or +85 to +110 packed: the two A routes differ by 11 to 14% of A alone). 22.8 to 25.9 M words per block for C against 83.6 M today. B is worth 145 to 193 rows more beside A than alone, exactly the digit helpers; with helpers gone 91% of the block is A data.
- **New cost where A meets B:** lookup terminals on the 45 cell-plane key planes become U reads (45 to 53 rows with a pair per tree, 144 to 202 with a pair per plane, 0 if a claim-merging sumcheck moves them); digit leaves add 7.2 to 9.7% to the block's 32.28 M lookups (20 to 21 levels).
- **Speed ceiling is far below the volume cut:** commits are 25.5% of device work, so at full pass-through B alone is at most 1.8 to 3.8% of cadence, A alone 9.8 to 10.3%, A+B 10.5 to 14.7%, before tree work (6a's unverified estimate 0.040 to 0.105 s a block on Metal against 0.0915 s block GPU). No rate figure above 6a's x1.07 to x1.25. Tests H152b (A+B C at most 1,800 rows), H158 (terminals merge onto existing end points), H159 (summed multiplicity bits under 150 rows). 0 committed words changed.

## 2026-11-24: Claude researcher tick 51, FlashProve's read descriptor and whether a lookup key may be a recombination of two planes (claude-cycle, queue items 82 and 83, H155/H157/H156c)

**COMPLETE, reading only** (2 raw page fetches of the public FlashProve docs, 0 searches); no run, no build, no Git. Triage material (no ruling). Clock at writing 2026-11-24T00:07:56Z.
[Handoff](handoffs/20261124-claude-tick51-read-descriptor-key-recombination.md).
- **Item 82:** the array term of the smallness tie is one combined row of the packed matrix per matrix (`M_mu{rw_mu}`, product-shape row weights), so H155's one tie claim per matrix holds. A read is (part, block): one `phi_f` per part, entry (c, b) over one block of `len(f)` rows; FlashProve combines limbs in the form (`sum 256^lb U3[...]`), so its own use is **one U3 entry per limb** and its layout puts limbs far apart. A spanning `phi_f` (1 and 256 in one block and column) is not forbidden by the grammar and not used (verifier source unread); the fail line is not met but tick 8's two-U count stands for FlashProve's layout; tick 49's class-W figure stays conditional.
- **Item 83 passes:** a local key is already `alpha - (cst + sum coef x plane)` with any number of terms (`argument.rs:2143-2160`; `word24` is a two-plane key, `range16.rs:162-164`); helpers = ceil(lookups/2) (`shape.rs:2610`), so a recombined byte key adds no helper rows and tick 6's +480 is not forced; FlashProve's key table has `g0 + 256 gh`. One constraint: planes in the lookup's domain. Cost left: two reads per key unless limbs are adjacent in a block. H156c closed; H156d (toy) and H157b (layout read) added. 0 committed words changed; no rate claim.

## 2026-11-23: Claude researcher tick 50, what the smallness test's 2^18 cells do to the block's no-wrap arguments (claude-cycle, queue item 23, H156)

**COMPLETE, local reading and arithmetic only** (0 searches, 0 fetches); no run, no build, no Git. Triage material (no ruling). Clock at writing 2026-11-23T19:53:47Z.
[Handoff](handoffs/20261123-claude-tick50-relaxed-cell-wrap.md), script `20261123-claude-tick50-relaxed-cell-wrap.py`, output `...relaxed-cell-wrap.out.txt`.
- **No no-wrap argument uses the byte bound; each uses the class of a combined word** (int16, 24-bit product word, 13-bit quotient), so the word-class lookups must stay, keyed on the recombined `lo + 256 hi`. Words rebuilt from relaxed cells reach 2^26.0 (two cells) or 2^34.0 (three): at the Lean class bounds **five sites exceed 2^62 and p/2** (down 2^69, scores 2^64, PV 2^76, sum of squares 2^64, norm division 2^67 at tn = 16); Q, K, V, O, gate, up, RoPE, the SiLU product stay under with 3 or more bits. At the 8B shape as built only the sum of squares wraps (2^64.01); down, norm division, scores and PV sit within 1 to 3 bits. TOY: 4,096 legal relaxed words with sum of squares p + 16,503,937 (hosted value looks honest).
- **Cells at 2^18 as every operand never wrap** (largest 2^60, PV at the class bound); recombination is what costs the 2^8. Packing at radix 2^20 stays injective (2^58 < p/2). Remainders need their exact range for exactness (floor identity), not for wrap.
- **Costing:** tick 6's "+480 helper rows" is not forced if a lookup key may be the recombined limb (ASSUMED; test H156c, a read of the helper clause); bracket whole block 0.78 to 0.85 against 0.86. B needs no new wrap lemma beyond `noWrap_class_bounds`; one extraction-layer statement (cells to words without wrap). H156b (Lean `norm_num` negations) added. 0 committed words changed; no rate claim.

## 2026-11-23: Claude researcher tick 49, the claims the Theta tie leaves on packed A (claude-cycle, queue item 21, H155)

**COMPLETE, local reading and arithmetic only** (0 searches, 0 fetches); no run, no build, no Git. Triage material (no ruling). Clock at writing 2026-11-23T16:41:00Z.
[Handoff](handoffs/20261123-claude-tick49-tie-claims.md), script `20261123-claude-tick49-tie-claims.py`, output `...tie-claims.out.txt`.
- **H155 holds:** one tie claim per packed cell matrix (NM = 3 to 6 by row width), none from the digit lookup (the digits sit in a commitment made after Theta, ASSUMED from tick 7's order). The audit allows one pair per claim (`protocol.rs:70-140`), so **102 to 128 of the 134 cell-site mask rows on A are released** (DERIVED); tick 8's bracket was 38 to 114. Up to 17 claims if S stays unpacked (11 S sites remain); the kill line (48) is far.
- **U's net cost falls:** tick 8's 17.0 / 20.3 / 34.1% of the saved A rows (C / C+M / C+M+W) become 6.3-6.7 / 8.6-9.0 / 18.8-19.3% after the credit; Z's own pairs add about 8 to 14 rows. Whole block about 0.78 to 0.88 before helpers (tick 8: 0.80 to 0.90).
- **A split limb needs one U where only the combined value is read (12 W claims, 9 vectors) and two at its own zero-check or lookup site** (ASSUMED from the helper relation, not read in `argument.rs`; needs the source's read descriptor to allow spanning row weights, unverified). Only class W moves (24 extra reads to about 15, U 286 to about 264 rows); full C+M+W 16.2-16.7% against tick 8's 34.1%. Local gap: `ZKey` supports only eq-table or all-ones column weights, so the tie claim needs the sumcheck route or a new key kind. H157 (toy) added. 0 committed words changed; no rate claim; B still needs item 17 (class W) and item 20.

## 2026-11-23: Claude researcher tick 48, the zero-check round kernels' footprint per thread against the occupancy ladders (claude-cycle)

**COMPLETE, local reading and arithmetic plus one web search and two page reads**; no run, no build, no Git. Triage material (no ruling). Clock at writing 2026-11-23T12:24:03Z.
[Handoff](handoffs/20261123-claude-tick48-round-footprint.md), script `20261123-claude-tick48-round-footprint.py`, output `...round-footprint.out.txt`.
- **Footprint per thread (COUNTED over the generated 8B shaders, written order; fixed part ASSUMED):** slot 14 39 loaded tables, 45 nodes, peak live 39 fp2 (624 B) as written or 20 (320 B) with loads sunk, so 416 to 784 B (104 to 196 registers); slot 18 22 tables, 23 nodes, 20 or 14 fp2, so 320 to 480 B (80 to 120 registers). Agrees with tick 15's word counts within 15%.
- **Models fitted to the ten ladder points:** one shared pool (A, B) does NOT fit with the counted footprints (slot 18 would need negative registers; B puts r at 80 B); thread-group-allocation-only (C) fits slot 14 (sse 0.0008) and slot 18 loosely (0.02), pool size not identified (32 to 65 KiB all fit one slot). Knee at about 128 to 512 threads per core. Slot 18 has the smaller footprint and the larger penalty, with K1's load share 0.19 against 0.11: latency hiding, not store capacity (one pair of kernels). [Apple talk and a forum answer, read.]
- **No step below the shipped footprint is shown.** K5's four-way split (MEASURED, tick 15) already cut footprint 3 to 4 times for 0.914 and 0.967 of v13 at 8B; gain tracks footprint above about 100 to 130 words. Ladder downward points: slot 14 round 1 -9.2% at 8,192 B, total -2.0% (inside the base IQR), 0.15 ms a block. Ceiling of the K5 class 2.0 ms of block GPU = 0.6 to 1.8% of rate, under the 5% rule. Bench Z-down (G = 1, 2, 3, 4, 6 split) written with its line, NOT scheduled. 0 committed words, no rate claim.

## 2026-11-23: Claude researcher tick 47, what a lane's host time per block consists of at six lanes (claude-cycle)

**COMPLETE, local reading and arithmetic** (no web); no run, no build, no Git. Triage material (no ruling). Clock at writing 2026-11-23T12:10:31Z.
[Handoff](handoffs/20261123-claude-tick47-host-time-six-lanes.md), script `20261123-claude-tick47-host-time-six-lanes.py`, output `...six-lanes.out.txt`; pass and fail lines written in the script before the first run (two supplements, d and e, added later with their lines fixed before they ran, labelled so).
- **(a) passes:** arm A's device execution per kind is within 2.8% of tick 40's six-lane column for all ten named kinds, sum 219.70 against 217.88 ms (+0.8%); the re-implementation reproduces tick 38's periods exactly. The README's 241.6 ms host is 230.5 ms of loop host plus about 10 ms of head and last block.
- **(b) host grows 37.5 ms from one lane to six** (187.3 to 224.8, x1.20; older binary pair +55.6): 18% of the lane's added 202.7 ms (execution +119.4, queue +46.5). A uniform x1.1 to x1.3 stretch; six keys grow by 1 ms or more in both pairs and hold 82% and 70%: A to H commit +9.8, gather 38 to boundary commit +8.0, boundary commit to A commit +5.4, slot 4 to 14 +3.3, slot 17 to 18 +2.85 (x1.57, the largest stretch), commit H to slot 0 +1.2. The bundle's whole host saving (-4.0 ms) is in the opening tail plus gather (54.4 to 50.5); G3 to G6 unchanged.
- **(c) cores:** 32 logical = 24 P + 8 E (sysctl); 30 pool threads; mean lanes in host code 3.1; the thread demand exceeds the 24 P-cores only if every lane in host code used its whole pool (28% of the time, upper bound; 5% above 32). The literal coupling line is met for G5 only (zero bin 10 to 32 gaps) and a time-shift control calls it common-mode; G2's gap rises with other lanes in G2 (+8.1, +8.9, +13.8 ms) but the written control line is NOT met (controls swing -5.5 to +5.4): suggestive only.
- **Two candidates, lines written first, not scheduled:** K-4L (a 4 x 5 traced leg: host 197 ms or less = core-count threshold, 203 to 217 = smooth shared resource; linear prediction 209.8) and K-G2 (the sink on a memory-backed volume: six-lane minus one-lane G2 under +2 ms from +8.0). Ceiling of the whole stretch 7.4% of the period at full pass-through, about 2.5% at one third; under the 5% rule. 0 committed words, no rate claim.

## 2026-11-23: Claude researcher tick 46, thread-group memory of the kernels behind the device-demand top ten, and two allocation-ladder tests (claude-cycle)

**COMPLETE, local reading and arithmetic plus one web search (summary only)**; no run, no build, no Git. Triage material (no ruling). Clock at writing 2026-11-23T10:59:45Z.
[Handoff](handoffs/20261123-claude-tick46-tg-memory.md), script `20261123-claude-tick46-tg-memory.py`; pass and fail lines written before any count.
- **The zero-check slots hold NO thread-group memory** (COUNTED, `metal_slot.rs:364, 446`: generated `k_sc_round0` / `k_sc_round` take only the grid position, no `threadgroup` array, no barrier; groups of 64). Slots 14 to 18 (54% of demand) cannot be limited by an allocation as the sparse fold was; what they hold per thread is registers, never read from the device. Also none: `k_sc_part_reduce`, fold, `k_hash_cols`.
- **Table by bytes per group (COUNTED):** sparse fold A 18,944 B per 32 threads (592 B/thread), H 5,120 (160); NTT head, tail and the production fused kernel 16,384 B per 512 threads (32 B/thread; 22.3 ms of a block = 22.6% of D1, tick 21's split); transcript step 4,224 B, one group, 40 to 60 barriers per round (the barrier part of item 35 only). T-occ elasticity DERIVED 0.90 (time x3.255 for allocation x3.700).
- **Two tests stated, not scheduled, for Antigravity:** N-occ (fused NTT, unused dynamic argument, 16 to 32 KiB; go at r >= 1.30 = ceiling 5.1 ms = 5.2% of D1; stop at <= 1.15) and Z-occ (round kernels, ladder 0 to 32 KiB per 64-thread group; group-count limited at r(16 KiB) >= 1.25, not limited at r(32 KiB) <= 1.05). Not known: the resident-group limit and pool size; M3 Dynamic Caching shares registers and thread-group memory in one store [search summary, pages not read]. No rewrite proposed. 0 committed words, no rate claim.

## 2026-11-23: Claude researcher tick 45, what ends the long waits that do not end at a buffer end, and a convoy test (claude-cycle)

**COMPLETE, local reading and arithmetic** (no web); no run, no build, no Git. Triage material (no ruling). Clock at writing 2026-11-23T07:50:53Z.
[Handoff](handoffs/20261123-claude-tick45-convoy-coincidence.md), script `20261123-claude-tick45-convoy-coincidence.py`; pass and fail lines written in the script before the first count.
- **Convoy REJECTED by its pre-registered line (B3).** Buffers committed in the 5 ms after a nothing-in-flight stretch are long waiters 1.9% (six lanes) and 2.5% (eight) against 15.2% and 31.0% (x0.12, x0.08; same as a shifted-queue null) and hold 3.7% and 2.2% of the long waiters; B1 (a cluster of ends before the stretch) x1.06 and x1.14 of the null. The stretches themselves are real (16.1% and 19.6% of the window against 4.1% and 0.6% null; median 2.7 to 2.9 ms), agreeing with tick 34, but they are not where the waits form. B2 passes only because its band is wide.
- **Kind of coincidence for waits over 5 ms:** another queue's commit is below the control (2.3% against 5.3%; 4.5% against 6.8%), host done under the line; another queue's device START within +-0.5 ms is real (19.8% and 33.6% against 4.6% and 3.8%). With the end kinds 63.0% and 75.6% of long waiters coincide with an end or a start; 32.2% and 17.3% with nothing. Part A's written rule is met at eight lanes and NOT at six (56.6% of the no-end starts have nothing).
- **Supplement (not pre-registered):** 69.5% and 80.7% of the buffers that start beside such a long waiter wait over 5 ms themselves (all: 15.2%, 30.7%): a gang release of queued buffers on several queues, device-side, not a host convoy. Test G-leg3 stated (item 74). 0 committed words, no rate claim; nothing proposed for the prover.

## 2026-11-23: Claude researcher tick 44, cross-lane hand-off starts against the replay (claude-cycle)

**COMPLETE, local reading and arithmetic** (no web); no run, no build, no Git. Triage material (no ruling). Clock at writing 2026-11-23T03:51:12Z.
[Handoff](handoffs/20261123-claude-tick44-handoff-starts.md), script `20261123-claude-tick44-handoff-starts.py`.
- **Item 60, first rule met as written, with a control that shrinks it.** Prover starts 0 to 0.5 ms after another lane's end: 21.1% (leg 2, six lanes) and 32.6% (leg 5, eight) against 9.4% and 10.0% in tick 36's replay (x2.24, x3.27; pass at x2). The mirror (an end 0 to 0.5 ms after the start) is also x2.1 and x3.3 the replay's, so most of the raw gap is end density. The specific peak over the flat level at lags 0.5 to 3 ms is x1.75 and x1.94 measured, x1.00 in the replay: about 10% and 19% of starts are hand-offs beyond background (DERIVED).
- **It is a property of waiting buffers:** 37.6% (six lanes) and 35.2% (eight) of prover buffers with a committed-to-start wait over 5 ms start at another lane's buffer end beyond background; none of the quick ones at six lanes. About 60% of the long waiters do not.
- **Stage 2 fails, the replay line stops** (item 60's rule): releasing waiting buffers at buffer ends, no refit, leaves six-lane level 2 off by +8.0 points at best (levels off -2.4, +2.3, +8.0, -2.4) and eight lanes at rate +7%, empty -32%, variance -22%. The coupling is not shown to be an admission at buffer ends; host-side or join coupling remain, decided only by a measurement under one change (stagger test stated, not scheduled). Item 73 (what ends the other long waits) added. Nothing proposed for the prover; 0 committed words, no rate claim.

## 2026-11-22: Claude researcher tick 43, which host work fills the head's gaps and whether any of it repeats the sealing pass (claude-cycle)

**COMPLETE, local reading and arithmetic** (no web); no run, no build, no Git. Triage material (no ruling).
[Handoff](handoffs/20261122-claude-tick43-head-gap-code-map.md), script `20261122-claude-tick43-head-gap-code-map.py`.
- **Item 66: tick 39's reading of the head was wrong in two places.** In the app the run's "sealing pass" runs no histograms (`CliSource::seal_check` is a no-op, `classify_cli.rs:552-558`) and, with `HL_A26_KEPT=1` (the fixture's and `deploy.json`'s setting), the 26 `stage_block_kept` calls read startup records, not scans. The 176 ms gap follows the input-endpoint commit (rows=6), not "the first IN-C commit".
- **The 176 ms gap (1.09% of the C lane period) is two full BLAKE3 digests of the 805 MB embedding table** (`ClassifierProfile::new` in `new_chunk`, and `check_tables`); a third pass sits on the start side (about 85 of its 100 ms). DERIVED: 2 x 805 MB at 5 lane threads x 1.89 GB/s (A21's measure) = 170 ms against 176.1 MEASURED (equal across arms, p10 to p90 173 to 179); consistency, not a passed prediction. The 98 ms gap (0.61%) is the challenge-dependent embedding fold (1.61 G i64 madds, about 80 ms at 5 threads, ASSUMED rate); not a repeat.
- **H1 does not take the head**; only the last gap (block 0's G3, 49.7 against steady 38.6 ms) is H1's site. **New H2: keep the embedding digest with the bound tables** (A26 §6 item 3 named it), same bytes, a D72-type ruling for the security owner: up to 255 ms a request, 1.6% of the lane period at full pass-through, about 0.5% at tick 37's one third. Fold to the device up to 0.5%. Under the 5% rule, not scheduled. Tests T-dig, T-fold (CPU, about 0.1 s of five cores) stated.

## 2026-11-22: Claude researcher tick 42, which device work per request could come off the device (claude-cycle)

**COMPLETE, local reading and arithmetic** (no web); no run, no build, no Git. Triage material (no ruling).
[Handoff](handoffs/20261122-claude-tick42-device-work-ranked.md), script `20261122-claude-tick42-device-work-ranked.py`.
- **Item 58 (a): the request's 2.968 s of device work is 58.8% zero-check slots, 25.5% commits A and H, 15.1% sealing products, 0.5% the rest** (leg 1, MEASURED; the sum matches the README to 0.01%). Slots 18 and 14 are 33.1%; the two big gathers are 0.07% each in device time (they are a host-gap item). At six lanes the shares are 71.7 / 20.7 / 6.2%: sealing is 13.55 ms a block there, not 17.28.
- **(b) No sealing product can go back to the CPU at a profit.** At A4's measured CPU speed (about 10 to 11.4 G MAC/s per thread, DERIVED from 85 ms for the 8B seven) the seven products need 62 thread-s a request, 67% of the machine's cores at the six-lane rate; CPU wall at five threads is 11 to 36 times the device ms against a break-even of about 10 (tick 40's R over tick 37's pass-through). K and V alone net -2.1% to +0.2%.
- **New: the one-lane gate/up sealing buffer is bimodal** (3.4 ms, 44%; 5.8 ms, 56%; six lanes 95% fast, median 2.6 ms). Not a property of the layer (0 of 26 block positions always slow); cause not shown, opposite of a clock ramp-up. It makes the one-lane sealing unit about a fifth too high for the stream.
- **(c)/(d)** The trace cannot split transform from hash; from tick 21's diag split: forward NTT 13.9%, inverse 8.2%, hash 3.4% of the request. Rates per candidate at R = 5.12 / 3.4 / 0: NTT traffic-floor kernel +2.4 / +1.6 / 0, small sealing products' kernel time +1.9 / +1.3 / 0, hash +1.6 / +1.0 / 0. Under the 5% rule, none scheduled; effect on committed words 0.

## 2026-11-22: Claude researcher tick 41, the spfold kernel against its floors (claude-cycle)

**COMPLETE, local reading and arithmetic** (no web); no run, no build, no Git. Triage material (no ruling).
[Handoff](handoffs/20261122-claude-tick41-spfold-kernel.md), script `20261122-claude-tick41-spfold-kernel.py`.
- **Item 67: the same kernel meets its floors on H and misses them on A.** H (k = 10, 5 KB threadgroup memory per 32-thread group) runs 1.85 ms against a 1.79 ms floor sum (1.03x; 139 G `gl_mul`/s, 63% of K4); A (k = 37, 18.9 KB per group, 6,773 groups, 13 row blocks) runs 4.18 ms against 1.71 ms (2.44x; 45 G/s, 21%; reads 80 GB/s). Shapes COUNTED from the trace strings.
- **Reading (ASSUMED, the GPU's resident-group limit is not known to me):** A's threadgroup memory limits resident groups, so the serial dependent-load row loop (about three loads a row, 256 ns a row at one group a core) is not hidden. Test T-occ needs no kernel change: run H with A's 18,944 B allocation; about 4.3 ms if occupancy is the cause (confirm at 3.0 or more, refute at 2.2 or less).
- **Layout B** (one thread per column and vector, terms by vector, registers, no partials or reduce): floor 1.35 ms; at H's efficiency A saves 2.8 ms of 4.18, worth 0.8 to 2.3% of rate on tick 40's exchange range; per-vector term spread is unknown (tail risk). Splitting the vectors over calls of the old kernel re-reads 334 MB each time and is a diagnostic only. Same bytes out; effect on committed words 0; under the 5% rule, not scheduled.

## 2026-11-22: Claude researcher tick 40, the device demand table at the app profile and what a device ms is worth at six lanes (claude-cycle)

**COMPLETE, local reading and arithmetic** (no web); no run, no build, no Git. Triage material (no ruling).
[Handoff](handoffs/20261122-claude-tick40-device-demand.md), script `20261122-claude-tick40-device-demand.py`.
- **Item 65 (a) passes:** execution per block by buffer kind sums to 98.541 ms (one lane) and 217.883 ms (six lanes), +0.04% and -0.01% against tick 38. Slots 14 to 18 are 54.1 and 133.5 ms, 67% of the 119.3 ms added; slot 18 alone 21.4 to 52.7 ms (x2.46), slot 17 x3.30, slot 0 (a 25 MB slot) x4.43, the two big commits x1.37. Small-table slots stretch x2.89, big-table slots x2.45.
- **(c) A one-lane device ms is worth about 3 ms of block period at six lanes (2.0 to 5.1 in the estimates; structural ceiling 5.12), i.e. about 0.3 to 0.9% of the rate**: E1 fused encoder (untraced +2.95% over a 4.1 to 7.9 ms demand cut) 2.0 to 3.9; E2 from tick 37's third pass-through 3.4; E3 tick 33's calibration 3.5 to 5.6. They agree within a factor of two. R is not constant: the composed bundle changed one-lane demand by about zero yet six-lane execution plus queue rose 35 ms, because the host cut put more lanes on the device at once.
- **(d) Three cuts that keep the committed words, not scheduled:** (1) `HL_METAL_BATCH_TAIL_US` 25 to 250, a setting, 7.1 ms of device a block at 8B solo, test A,B,B,A at six lanes; (2) tick 17's transcript-step kernel (K9, 11.3 ms equal-round gap); (3) the spfold kernel, 6.0 ms against floors of about 1.7 ms (334 MB read, 189 M `gl_mul`), kernel-alone test. The spfold kernel is covered by no earlier tick. Effect on committed words 0.

## 2026-11-22: Claude researcher tick 39, the tail between a request's last run buffer and the next request's first sealing buffer (claude-cycle)

**COMPLETE, local reading and arithmetic** (no web); no run, no build, no Git. Triage material (no ruling).
[Handoff](handoffs/20261122-claude-tick39-after-run-tail.md), scripts `20261122-claude-tick39-after-run-tail.py`, `-stagger-check.py`, `-startup-share.py`, `-head-buffers.py`.
- **Item 63: the tail is not where the A-to-C gain is.** Measured per request and thread in the three traced arms of one run (37 requests an arm): tail mean 189 / 218 / 190 ms (A / B / C), median 128 / 140 / 129; **A minus C -0.001 s [-0.049, +0.051]**; 1.1% of the lane period. Pieces sum to the lane period by identity; the rate implied by the lane period matches the measured rate within 0.5%, 1.4%, 0.4%.
- **Tick 37's 0.305 s "remainder" was a sample-set artifact** (lane period from 39 pairs, other pieces from 45 requests). On one set the same pair gives tail +0.047 [-0.001, +0.097]; the A-to-C cut of 0.865 s is run 0.708, sealing 0.106, tail 0.047, hand-over 0.005.
- **Tail = floor of about 126 ms + the A28 start stagger.** About 100 ms is the start side (first-wave set-up before the first sealing buffer), about 25 ms the end side. All 56 tails above 0.2 s sit 0.29 to 0.32 s after another lane's start; stagger excess 62 / 92 / 64 ms a request (0.4 to 0.5% of the lane period). Neither always-on change is in the tail.
- **The always-on part is not located:** in this traced triple B is 0.495 s slower than A (untraced: +4.2/+5.1% faster); between-leg spread exceeds the effect. The head (0.384 s) is 25 ms of buffers and 359 ms of host gaps, 176 ms before the first IN-C commit (the run's own sealing pass; relevant to H1). Effect on committed words 0; all candidates under the 5% rule, none scheduled.

## 2026-11-22: Claude researcher tick 38, which host phases shrink with a fifth thread, and the one-lane gap table at the app profile (claude-cycle)

**COMPLETE, local reading and arithmetic** (no web); no run, no build, no Git. Triage material (no ruling).
[Handoff](handoffs/20261122-claude-tick38-thread-gap-tables.md), script `20261122-claude-tick38-thread-gap-tables.py`.
- **Item 64 passes its check:** phases (each buffer assigned to the transition after it) sum to the block period exactly in all three legs (504.96, 528.95, 302.31 ms; 1,200 / 1,200 / 200 blocks).
- **The loss at four threads is all host gap:** period +24.0 ms (6x5 to 6x4), gap +24.5, execution +0.4, queue -0.9; slots 5-13 +9.5, A to H commit +6.6, boundary commit to A commit +5.2. The tables account for the untraced -3.3% / -6.1%.
- **About half the host gap is serial:** a two-point fit (gap = s + p/T) gives 126 ms serial and 98 ms thread-scaled of 224 ms. Flat phases: opening tail (ratio 1.000, 19.3 ms), gather 38 to boundary commit (1.045, 28 ms serial), other slot gaps (1.045, 28 ms); code locations in the handoff (`argument.rs:1213-1289`, `classify_run.rs:269-308`, `protocol.rs:2509, 2824, 2863-2877`).
- **One lane to six: period x1.670 (302.3 to 505.0); gap only +37 of +203 ms** (execution +119, queue +47). Per-phase gap stretch x1.10 to x1.30: tick 37's x2.2 / x1.7 stand-ins were mostly profile. Tick 37's G5 test reads 42 ms at one lane: the solo log's 26 ms is not this phase.
- **Beyond five threads:** the fit holds to six (-3.2% against measured +2.2%) and overpredicts at eight (-7.3% against +3.3%) and twelve (-11.3% against -0.4%); the extra threads cost elsewhere (cores, device crowding). Test T1 (one traced 6x8 leg) stated, not scheduled. Effect on committed words 0; a 10 ms cut of a serial phase is about 0.7% of the period.

## 2026-11-22: Claude researcher tick 37, which host gaps the composed bundle removed and which remain (claude-cycle)

**COMPLETE, local reading and arithmetic** (no web); no run, no build, no Git. Triage material (no ruling).
[Handoff](handoffs/20261122-claude-tick37-host-gap-table.md), script `20261122-claude-tick37-host-gap-table.py`.
- **Item 61 passes its check** (gap table plus encode within 3.7% and 4.6% of the README's host time in arms A and C; the rest is the 0.39 s head of a prove call). Host gap 284.3 to 230.9 ms a block; **40.2 ms is the opening region** (slot 22 to gather 38, the sparse fold), about 6 ms the A build, 2 to 4 ms A-to-H. The arm-B smoke puts the always-on part at about 5 ms of gap (G1 57.5 against A's 59.5), so the +4.2/+5.1% of B over A is NOT visible in block gaps or the sealing window; no split of the rate gain is made.
- **Pass-through is a third:** period -17.5 ms for a -53.4 ms gap cut; execution +21.1 and queue +14.6 ms; the opening region's wall fell 29.7, not 40.2.
- **Remaining 231 ms a block; four gaps are 75%:** A to H commit 54, slots 4 to 14 45 (8.7% of the app block period, so item 40's 1.7% does not carry over), boundary commit to A commit 39, gather 38 to boundary commit 36. New candidate H1: `w16_histograms_cols` runs in the sealing pass and again in the A build; a cache is 10 to 20 ms a block (0.5 to 3%), under the 5% rule, not scheduled; CPU count test stated. Effect on committed words 0.

## 2026-11-22: Claude researcher tick 36, a launch-wait rule for the six-lane replay, fitted on leg 2 and tested on leg 5 (claude-cycle)

**COMPLETE, local reading and a standard-library simulation** (no web); no run, no build, no Git. Triage material (no ruling).
[Handoff](handoffs/20261122-claude-tick36-launch-wait.md), scripts `20261122-claude-tick36-launch-wait.py` and `20261122-claude-tick36-feature-check.py`.
- **Item 59 FAILS its pass condition.** The rule (committed-to-start q drawn from leg 2 by class, buffers executing and buffers committed-not-started) gives q 51.1 ms a block (leg 2: 51.9) and rate 47.2 (+7%), but empty 18.5% (-19%), three or more at once 31.4% (-22%), variance 2.16 (-19%). Out of sample on leg 5: rate +13%, empty -40%, variance -44%, q 82.5 against 130.8 ms.
- **q is mostly not state:** bins of (executing, pending) explain 35% of its variance; work-weighted state 0.50 at best (0.37 to 0.46 out of sample); the leg-2 table under-predicts legs 4 and 5 by x0.70; q per prover buffer 0.66, 2.8, 4.3, 7.0 ms at one lane, six, shared queue, eight lanes. A table fitted on leg 5 itself still leaves the replay x1.10 fast with empty -37%, so the wait is not the missing piece.
- **Missing: synchrony.** The replay (max level 8 and 9, no more artefact levels up to 13) puts 7 to 11 points too much time at one buffer executing and 5 to 10 points too little at zero: lanes in step (tick 34), not delay. Candidates (a) admission in groups, (b) host-side coupling, (c) the sealing-to-prover join; none shown. Test (item 60, reading only): cross-lane hand-off starts, measured against the replay. The replay cannot rank tick 35's candidates (i) to (v). Effect on committed words 0; proofs / passes / positions 0 / 0 / 0.

## 2026-11-21: Claude researcher tick 35, a replay of the six-lane stream from the one-lane trace (claude-cycle)

**COMPLETE, local reading and a standard-library simulation** (no web); no run, no build, no Git. Triage material (no ruling).
[Handoff](handoffs/20261121-claude-tick35-replay.md) and its script `20261121-claude-tick35-replay.py`.
- **The replay does NOT reproduce leg 2; stopped by the item's rule.** Leg 1's buffer sequence (dependency and gap per buffer), tick 34's work rate per level and the measured host stretch (x1.215) give 49.9 tok/s, empty 16.7%, three or more at once 40.3%, none in flight 18.5%, variance ratio 1.88, against leg 2's 44.05, 22.7%, 40.2%, 20.9%, 2.66 (rate +13%, empty -26%, variance -29%; eight lanes worse: 51.6 against 42.9). No candidate (i) to (v) is answered.
- **Bunching mostly comes from the device loop alone:** the replay's independent-start lanes reach none-in-flight 18.5% against 8.2% independent and variance 1.9, about half to two thirds of the measured excess.
- **Missing: a device-side wait after commit** (leg 2's committed-to-start 51.9 ms a block against 12.2 at one lane; replay 12.3). +4 ms per launch fits rate and empty but not the three-or-more share (29.1%) or the variance (1.85). Not the host stretch (MEASURED: gap x1.11 with no other lane in a gap to x1.24 with five; leg 5 x1.34 to x1.64), not a serial sealing queue, not a cap of four to five. Test (item 59): fit the launch wait on leg 2, test out of sample on leg 5. Effect on committed words 0; proofs / passes / positions 0 / 0 / 0.

## 2026-11-21: Claude researcher tick 34, the empty device at full lanes and what the lanes are doing in it (claude-cycle)

**COMPLETE, local reading and arithmetic** (no web); no run, no build, no Git. Triage material (no ruling).
[Handoff](handoffs/20261121-claude-tick34-empty-device.md) and its script `20261121-claude-tick34-empty-device.py` (reads the five compressed traces of `results/zk60_lanes_trace_20261121/`; reproduces the co-coordinator's level shares).
- **Six lanes, off, thread queues:** 9,421 empty stretches in 139.5 s, median 1.6 ms, none over 50 ms; 62% of the empty time in stretches over 5 ms, 19% over 20 ms. Eight lanes: 7.8% of the empty time over 50 ms. Stretches of 5 to 20 ms are largely sealing (a sealing buffer borders 37%); over 20 ms they are block host gaps (slot 22 to the next gathers, slots 5 to 13, the commit encodes), with no lane having a buffer encoded.
- **The lanes are on the host together:** 3.6 of 6 (6.1 of 8) lanes share one host gap at a stretch's midpoint; the count of lanes with a prover buffer in flight has x2.66 (six) and x4.67 (eight) the independent variance; none in flight 20.9% against 5.4% independent (eight lanes 25.9% against 1.0%). About 17 of 22.7 points are correlation, not load; more lanes raise bunching faster than load. Host gaps per block stretch 219 / 266 / 351 ms at one, six, eight lanes.
- **Work rate keeps rising with overlap:** 0.95, 1.33, 1.37, 1.63 solo-seconds per second at one, two, three, four or more executing (eight lanes 1.09, 1.32, 1.21, 1.51); two at once is already 1.3, no fall at four or more. Prover buffers take 1.61, 2.33, 2.81 times solo at two, three, four or more. Sealing buffers run faster at six lanes than the one-lane unit (0.6 to 0.9), so prover-only rows are the clean ones.
- **Ceiling:** empty share 22.7% to 5% at 1.31 per busy second is x1.23; at the level-one rate x0.89. What couples the lanes is not shown (ARGUED: buffers at high overlap finish together). Item 57's replay is the test; stated, not scheduled. Effect on committed words 0; proofs / passes / positions 0 / 0 / 0.

## 2026-11-21: Claude researcher tick 33, why A36 helped at one lane and slowed the lanes-full stream (claude-cycle)

**COMPLETE, local reading and arithmetic** (no web); no run, no build, no Git; owner-private logs not read. Triage material (no ruling).
[Handoff](handoffs/20261121-claude-tick33-a36-six-lane.md) and its script `20261121-claude-tick33-a36-six-lane.py` (reads A36's retained T1 and T2 json).
- **The retained records cannot split device waits from host phases at six lanes** (no trace or `HL_PB_TIMING` on any six-lane leg). They show a **cross-lane effect:** the unchanged sealing pass is x1.069 slower with A36 on at both six and eight lanes (x1.01 at one lane), so the lane's own pool is not the whole story. The ioreg meter is pinned at 85 to 90% in all eight legs and reads about 65% at one lane (solo GPU 22%): no inference from it (an earlier reading of +0.4 s busy a request is withdrawn in the handoff).
- **From solo block GPU (94.679 ms x 26) the off stream runs at 83% (six lanes) and 87% (eight) of a no-overlap device bound** (52.0 tok/s); A36 on is 74%. A36 moved about 60 ms a block, hid 16.7 ms at one lane (28%) and cost 79.8 ms at six: 139 ms beyond perfect overlap, 2.3 times the moved work. Closed-queue MODEL: adding 80 ms of host gap gives x0.904 against the measured x0.885.
- **One measurement decides:** the Metal buffer trace (`HL_A27_GPU_TRACE`) on one off and one on six-lane leg under T2's `HL_METAL_QUEUES=thread` (tick 30's trace is shared-queue); readings stated; NOT scheduled. Leading suspect, untested: per-thread queues letting the first half's NTT buffers run beside the second half's zero-check buffers in every lane.
- **For other candidates:** one-lane gains do not transfer; repeated-check removal 1.7 to 2.7% of the period (no new concurrency); a writer thread moving only the write and fsync wait 1.5% at the ceiling; seal-ahead must be tested at six lanes. Device time is the lever: 1 ms of block GPU is 0.7 to 1.1% of the six-lane period, 3 to 4.5 ms buys the 3% line. Effect on committed words: 0. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-21: Claude researcher tick 32, whether the app's CS-3 repeat sits under A33's precondition (claude-cycle)

**COMPLETE, local reading and arithmetic** (no web); no run, no build, no Git; owner-private logs not read. Triage material (no ruling).
[Handoff](handoffs/20261121-claude-tick32-cs3-repeat-precondition.md).
- **Yes, and more simply than in the trained path:** `classify_cli.rs:585` builds at `&ssh` and `:591` checks at the same `&ssh` and `&blk`, build first; `build_for_block` runs the public check in both branches (`witness.rs:84, 88`); W16R2 profiles are `LowH24`, not Legacy (`shape.rs:300-302`); the check reads only the block and the shape, and `BlockPublic` has no interior mutability. A33's `build_checked` rule is not needed (no derived shape). No refusal or text moves: the build refuses first today.
- **Tests to repeat:** none of A33's gates reads `classify_cli.rs`; a text gate on `seal_chain_keeping` (build before scan, same arguments) plus classifier analogues of the refusal-text and before/after-identity tests are needed (table in the handoff).
- **Value:** A33 measured 8.59 ms a block (0.275 s of 2.181 s over 32 blocks); at 26 blocks 0.223 to 0.358 s a request, **x1.012 to x1.019 on the lane period**, under the 5% rule, not scheduled. Unverified wider lead: a memo of the build's own check for resident blocks would double it (x1.038 ceiling); soundness not argued. Effect on committed words: 0. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-21: Claude researcher tick 31, what is in the 42.8 ms host gap between the boundary opening and the next boundary commit (claude-cycle)

**COMPLETE, local reading, arithmetic and one small timing check** (no web); no prover run, no build, no Git; owner-private logs not read. Triage material (no ruling).
[Handoff](handoffs/20261121-claude-tick31-boundary-gap-split.md), scripts `20261121-claude-tick31-boundary-gap-split.py` (reads A24's retained phase records) and `20261121-claude-tick31-sinkbench.py` (a 32 MB write, flush, rename and SHA-256 timing).
- **No W16R2 record of `sink`, `encode segment` or `B_(k-1) opening` is retained**; the phases exist only at R13 (A24: baseline 26 blocks, stream 78 blocks). R13 solo per block: sink 25 ms, encode 3, opening 2, boundary B_k phase 9 (includes its commit wait), block load and check 15 to 61 (skipped at the app by `HL_A26_KEPT=1`, `deploy.json`).
- **The disk sink is host-only on final bytes (create, write, F_FULLFSYNC, rename, SHA-256, `run_sink.rs:385-392`) and so independent of the transcript;** tick 30 had filed it as not independent. Check on this Mac: 32 MB alone 21.4 ms (digest 11.1, flush 7.3), six writers at once 59.6 ms; reproduces A24's 25 ms. At W16R2 (ASSUMED 1.8x smaller segments) 12 to 33 ms of the 42.8 ms gap.
- **A writer-thread hand-off, same bytes out, is worth x1.013 to x1.035 on the lane period at the ceiling** (tick 30's closed-queue model, about 0.1% per ms); under the 5% rule, not scheduled; overlaps tick 30's before-part-ahead set and A36. Tests S1 (`HL_PB_TIMING` phases from one app stream: pass sink at least 12 ms, kill under 6) and S2 stated, NOT scheduled. Effect on committed words: 0. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-21: Claude researcher tick 30, what a lane does on the host at the W16R2 classifier and what seal-ahead would buy (claude-cycle)

**COMPLETE, local reading and arithmetic** (no web); no run, no build, no Git; owner-private logs not read. Triage material (no ruling).
[Handoff](handoffs/20261121-claude-tick30-lane-host-phases.md) and its script `20261121-claude-tick30-lane-host-phases.py` (reads Astra's retained buffer trace, timings only).
- **A request thread's block is 611 ms: 307 ms waiting on command buffers, 303 ms with none outstanding** (DERIVED, 600 blocks of 24 requests); a lane's request is 19.405 s = 26 blocks 15.96 s + 3.44 s outside, sealing window 2.88 s (range 2.60 to 3.59), of which product buffers are 18.5%.
- **The installed app has no A33, A35 or seal-ahead:** `classify_cli.rs:591` still calls the repeating CS-3 check. The harness rule "sealing savings do not reach the stream" is a two-lane prove-paced result; the app runs six lanes with the device 72.7% busy.
- **Host work independent of the transcript and of block k's device results: 59 to 101 ms of the 303 ms a block** (A rows and masks 48.6 ms, M commit, next boundary prepare; the split of the 42.8 ms gap is not retained). `prove_core_before_with` already reads no transcript but the classifier calls it inline; four of five pool workers idle while the request thread waits. Closed-queue MODEL: x1.03 to x1.11 on the lane period (ceilings, no memory contention). A33's dedup carried to the app: at most x1.019. Seal-ahead: x1.039 on R13's 25% pass-through (ceiling x1.178), +43 GiB at six lanes (about 157 GiB against 220).
- **Cores:** 14.1 of 32 busy on average (batch 2, arm B); no per-thread record at W16R2. Tests (one-lane before-part ahead; HL_PB_TIMING phases in the app for the 42.8 ms split) stated, NOT scheduled. Effect on committed words: 0. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-20: Claude researcher tick 29, which lane settings were measured at the app's W16R2 classifier, and the lane-count test (claude-cycle)

**COMPLETE, local reading and arithmetic** (no web); no run, no build, no Git; the owner-private event logs were not read. Triage material (no ruling).
[Handoff](handoffs/20261120-claude-tick29-app-lanes.md) and its script `20261120-claude-tick29-app-lanes.py` (reads the retained `served` lines).
- **Only 6 x 5 (stream) and 3 x 10 (one post) were ever run at W16R2**, both on the shared Metal queue (coordinator's reading of `run_batch2.py`, not the app's `thread`). Every 8-lane, 6 x 8, 6 x 10, 8 x 6 and two-process figure is R13. The app's 6 x 5 was inherited from A24's R13 stream (shared queue, n = 1 each) and kept by A26 to A28.
- **MEASURED request medians (retained `served` lines):** W16R2 13.10 s at 3 x 10 and 20.47 s at 6 x 5 (x1.56); R13 24.13 s and 41.57 s (x1.72). DERIVED two-point model: 8 lanes x1.075 over 6 at W16R2, x1.042 predicted against x1.001 measured at R13, so about x1.035 bias-corrected: at the 3% pass line. Lane count is a small lever.
- **One request on its lane (CODE-READ):** seal chain of 26 serial blocks, then IN-C, 26 serial blocks on one transcript, OUT-C; one thread of control per request (rayon sections use the lane's 5 threads, the device waits spin 200 microseconds). Candidate causes of lockstep: equal requests with a start-only stagger (five steps of 300 ms = 1.50 s equals Astra's 1.37 to 1.60 s group width, DERIVED), the shared queue (Antigravity's measurement, not re-derived), process-global pool and cache mutexes (not measured); no lock held across a device wait found.
- **Test S-L (8 x 4 beside 6 x 5, 48 requests, queue A/B first) and a driver-only first-wave spacing of 3.2 s stated, NOT scheduled;** a constant stagger of 3.2 s through the environment caps the rate at 40.0 tok/s. Effect on committed words: 0; on proved tokens/s: 8 lanes 0 to +7.5% (central +3.5%), spacing up to about +10% (ceiling), unvalidated. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-20: Claude researcher tick 28, the Shieldstral shares re-paired to the app's profile W16R2_SHIELD (claude-cycle)

**COMPLETE, local reading and arithmetic** (no web: a re-pairing item); no run, no build, no Git. Triage material (no ruling).
[Handoff](handoffs/20261120-claude-tick28-shield-repair.md) and its script `20261120-claude-tick28-shield-repair.py` (reads the coordinator's four GPU traces).
- **The app's block has the 8B block's costs:** commit diag split inverse / forward / hash equals the 8B control's to 0.1 ms (f = 0.867, R13 0.855), slots 15 to 19 equal to under 0.1 ms. The only differences are the D-pad gate table: slot 14 +1.57 ms (37 tables against 36), slots 0 and 1 +0.34 and +0.40 ms (3 against 2), total +2.31 ms (MEASURED difference; tick 11's gate-table model predicted exactly those slots). Row totals from the commit records: 2,504 + 2,606 at both W16R2 profiles, 4,577 + 4,390 at R13_SHIELD.
- **Re-paired shares (cadence 4.381 s, 26 blocks, full pass-through):** commit 30.6% of block GPU (not 43.7%); free NTT x1.36 (14.9%), traffic-floor kernel x1.14 (6.9%), H117b x1.09 (4.8%), padded-pair skip 5.5 to 10.2 ms = 5.8 to 10.8% of block, 3.3 to 6.1% of cadence (phase split ASSUMED from the 8B arm B), tail 5.9 / 13.5 / 25.6% (8B ms), K5 about 1.7%, plain two-table 2.9% batched, padded commit 4.6%, pad rule at most 1.4%. No decision flips; the R13 values must be labelled R13_SHIELD.
- **Flag sharpened:** block GPU is 56% of the app's cadence (168.5 ms per block) against 78% at the 8B harness; unexplained from retained records; test S2 (a stream run on the current binary) stated, NOT scheduled. Other tests (arm B phase split at this profile, plane lists P2c') stated, NOT scheduled. Effect on committed words: 0; on proved tokens/s: none from this tick. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-20: Claude researcher tick 27, Shieldstral stream value of dropping committed padding, and a profile-pairing correction to tick 26 (claude-cycle)

**COMPLETE, local reading and arithmetic** (no web: a local item); no run, no build, no Git. Triage material (no ruling).
[Handoff](handoffs/20261120-claude-tick27-shieldstral-padding-stream.md) and its script `20261120-claude-tick27-shieldstral-padding-stream.py`.
- **Correction to tick 26 (and the Shieldstral shares of ticks 11, 21, 22):** the 174.25 ms block GPU and the 76.2 ms commit are the R13_SHIELD profile; the padded fraction 26.96% is the W16R2 one; the installed app has been W16R2 since 2026-11-13. Tick 26's 20.5 ms / 11.8% is a cross-profile product. R13's own fraction is 26.50% (R13_8B lists assumed at Shieldstral padding): 20.2 ms, 11.6% of 174.25, 6.6% of R13's cadence (7.948 s).
- **At the app's profile (W16R2 Shieldstral):** measured cadence 4.381 s per T128 request (A30/A31 benchmark, 29.22 tok/s, binary of 2026-11-12, two samples per arm). Same row total as the 8B block, so commit about 27.9 ms (31.9 upper); padded part 7.5 to 8.6 ms per block = **4.5 to 5.1% of the cadence at full pass-through**, at the 5% line: not scheduled. W16R2_SHIELD block GPU is unmeasured (about 88 to 95 ms from older wall-phase sums, weak).
- No retained record has Shieldstral plane lists (P2c open). Tests P2c' (census at both Shieldstral profiles), S1 (slot census at W16R2_SHIELD, decides whether the padded-pair-skip share of 5.7 to 10.5% survives the re-pairing), B1 (one quiet solo block at W16R2 Shieldstral) stated, NOT scheduled. Effect on committed words: none; on proved tokens/s: a compact layout at most x1.05 (ceiling). Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-20: Claude researcher tick 26, committed padding words and the pad rule's cost (claude-cycle)

**COMPLETE, local counting plus a short web screen** (2 searches, 2 fetches: ePrint 2025/917 abstract page and an explainer); no run, no build, no Git. Triage material (no ruling).
[Handoff](handoffs/20261120-claude-tick26-padding-words.md) and its script `20261120-claude-tick26-padding-words.py`.
- **Committed padding per block (DERIVED from COUNTED plane lists):** 304 of 5,103 rows (5.96%) at W16R2_8B (only F pads, 12.5%), 1,376 rows (26.96%) at the Shieldstral profile (D 25%, F 43.75%); 79.7 MB and 360.7 MB per block, 2.55 GB and 9.38 GB per request. Both profiles commit the same 1.338 GB per block (identical row totals), so the 3B block carries 27% fewer live words. 5.7% / 27.6% of the counted lookups sit on padded positions.
- **Value:** commit-time bound (cost linear in rows) 1.66 ms per 8B block, at most 1.4% of the cadence: not a speed item at 8B; 20.5 ms (11.8% of production block GPU) at Shieldstral, which needs a compact commitment (jagged, ePrint 2025/917, abstract level only; zero knowledge and PCS fit unread) and a new profile.
- **Pad rule cost:** one 9-plane group in slot 18 at 8B (19 planes in slot 14 at Shieldstral); in the kernel it is 2 of 25 `f2_mul` and 1 of 21 tables. New observation: the term is identically 0 in rounds 0 to 6, and the batch is linear in the planes, so it can be built after round 6 (H165, prover-only, same words out): 0.44 to 1.30 ms per 8B block, at most 1.1% of cadence; dropped at 8B, overlaps the padded-pair skip at Shieldstral.
- Tests P2c (census at the Shieldstral profile), P3 (pad term zero in rounds 0 to 6, CPU) stated, NOT scheduled. Effect on committed words: 0 for the lazy node, up to -5.9% / -26.7% for a compact layout; on proved tokens/s: x1.00 to x1.01. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-20: Claude researcher tick 25, GPU witness generation against the sealing pass (claude-cycle)

**COMPLETE, web reading plus local counting** (6 searches, 6 fetches; ZKPoG, MegaZK, ZK-Tracer at abstract level, the cost survey 2611.17042 first 100,000 characters, EmuGEMM summary); no run, no build, no Git. Triage material (no ruling).
[Handoff](handoffs/20261120-claude-tick25-gpu-witness.md) and its script `20261120-claude-tick25-gpu-witness.py`.
- **Queue item 5's pointer was a misread:** EmuGEMM (arXiv 2606.25453) emulates FP32/FP64 GEMM on INT8 tensor cores (GH200 and B200 only); it has no witness or ZK content. No published GPU witness design maps onto the sealing chain (ZKPoG: Plonkish on an RTX 4090, 22.8x end to end [AUTHORS], no witness-stage figure; MegaZK's "more than 25%" is witness plus commit, quotient and FRI combined).
- **Local count (Batch 8, MEASURED, DERIVED):** products are already on the GPU and are 17% of the 2.183 s solo sealing pass; 79.8% is host work. 5090 floors for the products are 0.067 ms (arithmetic) and 0.122 ms (weights) per block, 3.9 ms per request [third-party spec figures], so a GPU does not help by speeding the products. What is left to move: histograms and limb planes, 0.667 s (30.6% of the pass, 20.8 ms per block), exact, same words out; 1.135 s with attention and requant. PCIe upload of host-built A planes on a discrete GPU would be 9.6 GB per request (0.17 to 0.24 s, DERIVED, overlappable).
- **Lead:** `check_accuracy_for_shape` takes no request input and scans 218 MB per block per request (group b, 0.128 s, 5.9% of the pass); a per-block memo would remove it (startup-load overlap and the H-1 refusal order not checked).
- Test W1 (Metal micro-bench of histograms and limbs; pass at most 6 ms per block, kill above 11) stated, NOT scheduled; no stream gain while the prove call paces the stream (A33). Effect on committed words: 0; on proved tokens/s: 0 now, up to about x1.2 to x1.3 on the sealing side once the prove call is near 2.5 to 3.0 s (MODEL). H164 added. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-20: Claude researcher tick 24, inventory of the host-only time of a prove call (claude-cycle)

**COMPLETE, local reading and arithmetic** (no web; `STREAM_GPU_PHASES.md` and its saved gap output, A33 and A34 records, Batch 6 one-block log, efficiency plan, `MVP_STATUS.md`, coordination file by grep); no run, no build, no Git. Triage material (no ruling).
[Handoff](handoffs/20261120-claude-tick24-host-only-inventory.md) and its script `20261120-claude-tick24-host-only-inventory.py`.
- **Union wall time by class** (serve4 beside, P 3.809 s, host-only 1.109 s, COUNTED from the saved output): opening host work 277 ms (7.3% of P), serial small-commit loop 202 (5.3%), next block's A build 97, join gathers 70 (strict transcript chain, cannot change), between small slots 68, slots to slot 14 63, hand-over 59, A to H commit 52. No host class has changed since the Batch 7 reference: A33 touched the sealing pass only, A34 stopped at the investigation (needs `pcs.rs`), A9 not taken. Item 40 closed: the class is 63 ms (1.7% of P) in wall time, 105 ms solo (2.9%).
- **All ten rows together are 888 ms: with every one gone P would still be about 2.92 s (upper bound, not additive), above the 2.56 s target.** The host-only pool cannot reach the target alone.
- **Leads found by setting A33 beside the inventory** (DERIVED from the two-lane model, fit untested for shifts): A33 turned 0.28 s of sealing time into waiting, so about 0.22 s of host work can move from the prove call into the sealing turn before the sealing side paces again. L1: commit the boundary planes in the sealing turn (C1 + C7 = 261 ms; F4 wording and pins change; owner ruling). L2: re-measure A13's window (`HL_D55_AHEAD=16`, no code, never measured on a prover-paced stream); pass at least 3% cadence in 6 of 6 pairs, kill within 1%. L1 and L2 share the budget.
- Caveats: reference binary predates A33 and the trace was on; slots 5 to 13 host time differs by up to x2 between two Batch 6 logs and tick 20 (item 44). Effect on committed words: 0; on proved tokens/s: ceiling about x1.06 on cadence from moving work, none claimed. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-19: Claude researcher tick 23, specification of the NTT-only bench for the commit kernels (claude-cycle)

**COMPLETE, local reading and arithmetic** (no web; `metal_kernels.metal`, `metal.rs`, K0/K1/K4 record, tick 21); no run, no build, no Git. Specification only, not scheduled. Triage material (no ruling).
[Handoff](handoffs/20261119-claude-tick23-ntt-bench-spec.md) and its script `20261119-claude-tick23-ntt-bench-spec.py`.
- **Two-term model:** K4-rate arithmetic plus tick 21's traffic floor with no overlap gives 0.92 to 1.02 of measured NTT times at four shapes (e.g. 4.0 to 4.4 ms against 4.110, 8B A inverse); either term alone is 0.45 to 0.60. The kernels look serial in load, compute, store; the bench must test overlap. A prediction to falsify, not a finding (shift multiply never timed).
- **Reading findings:** the head's input read is a bit-reversed gather (about 1/8 line efficiency per group, index map only, line size assumed); production 8B forward in ZK mode is NOT pruned (extent 2^14 + q > 2^14) while the plain diag is, plus a `gl_mul` by `pows` per word: about 0.4 to 0.5 ms per A commit, against 1.32 ms unexplained between commit and diag parts.
- Ceiling of a shift-only 2^6 x 2^6 x 2^k split (general multiplications 0.40 to 0.50 of today's): 2.7 to 3.2% of 8B block GPU (at most 2.5% of cadence), 4.6 to 5.5% at Shieldstral, before the extra pass; no commitment change. Bench N0 to N5 and pre-stated readings in the handoff. Effect on committed words: 0; on proved tokens/s: none proposed. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-19: Claude researcher tick 22, recheck of every thresholded decision against the production denominator (claude-cycle)

**COMPLETE, local reading and arithmetic** (no web; ticks 11 to 21, the slot breakdown README, `STREAM_GPU_PHASES.md`); no run, no build, no Git. Triage material (no ruling).
[Handoff](handoffs/20261119-claude-tick22-denominator-recheck.md) and its script `20261119-claude-tick22-denominator-recheck.py`.
- **No decision flips.** G1 (plain two-table slots 2.47% / 0.87% of production block GPU at 8B), the padded-pair skip (dropped at 8B: 1.3 to 2.3%; kept at Shieldstral: 5.7 to 10.5%, tick 21 wrote 10.0), the tail (6.1 / 13.8 / 26.3% solo, cadence 2.5 to 3.9% if free), H133/H161/H134 (superseded by K1's 0.11 to 0.19 loads share) and the batch gap (12.4%) all stand; the K5 split at Shieldstral is 3.4% of block GPU, the nearest to the 5% line.
- **Second error found:** "stream GPU-paced, cadence 3.7455 s against 3.753 s solo sum" was an accident of the inflated denominator (cadence / 32 = 117.05 ms). Production solo sum is 2.927 s (78% of cadence); the prove call is 68 to 72% GPU-busy; the Batch 6 one-block log (93.48 ms) agrees with 91.462 within 2.2%. Old 8B shares equal cadence shares numerically (upper bounds at full pass-through); new shares must not go into 1/(1-s). Tick 21's x1.10 / x1.36 / x1.15 are x1.076 / x1.261 / x1.112 on 8B cadence at most.
- **Lead:** tick 20's host matmul claims (0.38 to 0.48 thread-s per request) match the "slots to slot 14" host gap (1.06 thread-s, 0.40 s exposed, 10.5% of a prove call); tick 20's "hidden" premise is withdrawn. Test T1 (reading) and item 40 queued. Effect on committed words: 0; on proved tokens/s: none from this tick. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-19: Claude researcher tick 21, NTT / hash split of commit_A + commit_H and a denominator error in the slot breakdown (claude-cycle)

**COMPLETE, local reading and arithmetic** (no web; the externalized GPU traces of the slot breakdown, `metal.rs`, analyzer and run scripts); no run, no build, no Git. Triage material (no ruling).
[Handoff](handoffs/20261119-claude-tick21-commit-split.md) and its script `20261119-claude-tick21-commit-split.py`.
- **f = 0.868 (W16R2_8B) and 0.855 (Shieldstral)**: the `HL_METAL_TIMING=1` diag records re-run each commit as inverse NTT, forward NTT and hash (8B: inverse 8.3 ms, forward 14.0, hash 3.4 per block; Shieldstral 14.5, 49.3, 10.8). The diag sum is 0.91 to 1.00 of the commit.
- **Denominator error:** those same diag records are what the breakdown README calls "store fold with pads" (`other_diag_ms`, 21.9% and 30.0% of the "block GPU"). Production does not run them (`HL_METAL_TIMING=0` in the stream). Production block GPU is 91.46 ms (8B) and 174.25 ms (Shieldstral), not 117.285 and 248.899; every block-GPU share in ticks 11 to 20 is low by x1.28 (8B) or x1.43 (Shieldstral). The G1 drop (tick 20, 2.47% corrected) stands; thresholded statements need a recheck (queue item 38).
- Commit_A + H is 30.5% / 43.7% of production block GPU, its NTT 26.5% / 37.4%; free-NTT ceilings x1.36 / x1.60 (not estimates). NTT kernels run 2.1 to 2.3x over a 700 GB/s traffic floor (DERIVED); at the floor x1.15 / x1.25. H117b (drop the inverse NTT) is 9.1% / 8.3% of block GPU (x1.10 / x1.09), consistent with the deferral note. G3 dense GEMM: about 2,000x the arithmetic per row on a kernel already 2x off its floor; stays unscheduled.
- Caveats: diag forward is the plain mode and diag hash the old form, so f is of re-run parts; production-mode commit trace (T1) not available. Effect on committed words: 0; on proved tokens/s: none proposed. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-19: Claude researcher tick 20, which device sumcheck slots are plain two-table sums (claude-cycle)

**COMPLETE, local reading and arithmetic** (no web; slot breakdown `summary.json`, two raw logs, layout and timing sources); no run, no build, no Git. Triage material (no ruling).
[Handoff](handoffs/20261119-claude-tick20-two-table-slots.md) and its script `20261119-claude-tick20-two-table-slots.py`.
- **G1 has no target among the sumcheck slots.** The plain two-table degree-2 device slots are 21 and 22 (endpoint equalities; slot 20 at Shieldstral): 1.93% batched / 0.68% unbatched of block GPU at W16R2_8B, 1.12% / 0.33% at Shieldstral (DERIVED from MEASURED). Under the 5% rule: G1 dropped as a sumcheck-kernel project; tick 19's T1 not scheduled. The generous reading (all device slots with at most 4 tables and degree at most 3) is 5.93% / 1.85% at 8B, 3.26% / 0.98% at Shieldstral.
- **The matmul claims are host work on small cubes** (slots 5 to 13, 2^10 to 2^14, 12 to 15 ms per block together in the logs, 0 GPU ms). Round 0 of slot 21 (0.043 ms) is already at the copy roofline; later rounds sit on the 0.02 ms dispatch floor.
- Caveats: `summary.json` census is profile R13_8B (big-slot table counts differ from the timed W16R2_8B); slot 20 has no unbatched figure; slot 21/22 shape read from the census, not the kernel. Effect on committed words: 0; on proved tokens/s: none (at most 0.68% of block GPU). Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-19: Claude researcher tick 19, TensorZKP (ePrint 2026/1250) full read against the G1 and G3 tracks (claude-cycle)

**COMPLETE, web reading** (2 searches, 5 fetches; USENIX Security 2026 PDF read in full from locally extracted text, the ePrint PDF 403 and `ia.cr` 404, the Zenodo artifact listed but not downloaded); no run, no build, no Git. Triage material (no ruling).
[Handoff](handoffs/20261119-claude-tick19-tensorzkp.md) and its script `20261119-claude-tick19-tensorzkp.py`.
- **What it is:** H100, BabyBear degree-8 extension (32 B per element; section 4.1 says a 32-bit prime with k = 4, section 7.1 says k = 8), HyperPlonk plus Brakedown, INT8 limb matrix products with INT32 accumulators (N < 33,025 per chunk), Spielman encoder as a gathered batched inner product [paper]. 2^25: inner product 0.85 ms, degree-2 sumcheck 4.04 ms, encoder 11.58 ms, end to end 215.28 ms (955x CPU, 36.2x SIMT GPU) [AUTHORS]. Table 1 breakdown: permutation check 62%, encoder 23%, zero-check 8%, Merkle 4% (sums to 216.49, DERIVED). **No zero knowledge anywhere in the text**; rate, distance and queries of the code are not stated.
- **Finding:** the primitives run at 70 to 80% of H100 bandwidth (DERIVED), so tensor cores moved a compute-bound kernel to the memory limit; degree 3 is not tensorized (elementwise product on ordinary cores). Not a sound form of G3 (the authors keep the sparse linear code and reject the dense matrix-NTT route; no measurement of G3's premise). For G1 it evidences only two-table inner products and folds; the project's zero-check body is not that shape and its fold is already at the copy roofline (K0). Metal has no integer `simdgroup_matrix` found: half inputs with float accumulators give N <= 258 per accumulator, not 33,025. If the G1 note's 1,500 TOPS counts two operations per multiply-accumulate its roof ratios halve (24.5x to 98x).
- Effect on committed words: 0 (G1), unmeasured (a Spielman code changes openings). On proved tokens/s: none on the evidence. Test T1 (one small Metal bench against the copy roofline) and local items 36 and 37 proposed, NOT scheduled. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-19: Claude researcher tick 18, incremental proofs and KV or proof-state reuse for autoregressive decoding, published since 2026-09-26 (claude-cycle)

**COMPLETE, web reading** (7 searches, 8 fetches; ZK-DeepSeek and SLP read in full from extracted PDF text, DeepProve and VeriAttn abstract only; DeepProve PDF 403); no run, no build, no Git. Triage material (no ruling).
[Handoff](handoffs/20261119-claude-tick18-incremental-decode.md) and its script `20261119-claude-tick18-incremental-decode.py`.
- **No cross-token proof state for hidden activations found** [searches]. ZK-DeepSeek (arXiv 2511.19902) keeps kv/pe caches as plain files per layer, no commitment or binding; its "incremental" is a softmax input split in segments of 32; CPU o1js, hours per component [AUTHORS]. SLP (arXiv 2609.27367) proves a whole trace; context 8 to 16 costs +4.4% [AUTHORS], consistent with weights dominating. VeriAttn (arXiv 2606.16352) is TEE-based, not a proof system.
- DeepProve's abstract certifies "the output sequence" without in-circuit RAM, which reads as a teacher-forced single pass (body NOT read). Self-reported 174 / 86 tokens/min (2.9 / 1.43 tok/s) [AUTHORS]; its README and abstract disagree.
- Prefix re-proving is 256.5x one pass at N = 512 [DERIVED] but the window proof already avoids it; carried state buys latency only. H163 (counting test of the carried-state words, pass under 10%, kill over 25%) is not proposed as a speed item. Effect on committed words: 0; on proved tokens/s: none. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-18: Claude researcher tick 17, where the batched-minus-unbatched GPU gap per slot sits (claude-cycle)

**COMPLETE, local reading and arithmetic only** (slot 18/14 breakdown `summary.json`, `knob_probe.json`, `metal.rs` batched and unbatched paths, `k_sc_fs_step`); no web, no run, no build, no Git. Triage material (scheduling and kernel latency, no ruling).
[Handoff](handoffs/20261118-claude-tick17-batch-gap.md) and its script `20261118-claude-tick17-batch-gap.py`.
- **What the arms measure** [COUNTED]: A's one command buffer holds the transcript step (`k_sc_fs_step`, one threadgroup, serial hashing by thread 0) and `k_sc_part_reduce`; B sums partials and runs Fiat-Shamir on the host, outside its GPU intervals. So the gap is device work B does elsewhere, not dead time, plus A's extra rounds. Wall check [MEASURED]: device-round wall per block A 72 ms against B 89 ms (8B), prove core 0.327 against 0.360 s.
- **Split, W16R2_8B** [DERIVED]: gap 18.5 ms = 7.1 ms extra rounds (knob 250, measured) + 11.3 ms at equal rounds (9.6% of block GPU, 0.94 ms per slot). Not constant per batch: residual per A round 0.10 to 0.12 ms at degree 3 to 4 slots, 0.06 to 0.07 at degree 2, 0.14 at degree 5; negative intercept in a line fit. Shieldstral about 12.4 ms (5.0%, extrapolated).
- **Not settled:** slots 21 and 22 (same shape, one round apart) differ by 0.013 ms, and the knob probe's first three rounds cost 0.27 to 0.35 ms each but the fourth 0.09; no kernel timing exists. Tests: K9 (micro-benchmark of `k_sc_fs_step` and `k_sc_part_reduce`, pass >= 0.06 ms at 4,096 partials, d1 = 5) and T1 extended. Fix R1 (concurrent per-point reductions, in-kernel partial reduction) is protocol-neutral. Effect: x1.01 to x1.02 on cadence (2.2 to 3.5% ceiling if the stream hides it like the tail). Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-18: Claude researcher tick 16, size of the tail sumcheck rounds in the real prover over all slots, and their encoding (claude-cycle)

**COMPLETE, local reading and arithmetic only** (slot 18/14 breakdown `summary.json` and `knob_probe.json`, `metal.rs` batched path); no web, no run, no build, no Git. Triage material (scheduling only, no ruling).
[Handoff](handoffs/20261118-claude-tick16-tail-size.md) and its script `20261118-claude-tick16-tail-size.py`.
- **Tail = rounds j >= 5, all 12 device slots, W16R2_8B** [MEASURED sums]: Arm B 5.54 ms (4.7% of 117.3 ms block GPU); production runs 36 more batched rounds (3 per slot) that cost 7.12 ms solo (knob 250). Central 12.7 ms = 10.8% of block GPU (0.41 s per request), range 4.7 to 20.5% (upper end charges the whole batch gap to the tail). Shieldstral: Arm B 8.84 ms (3.6%), central about 15 ms (6.1%, extrapolated), upper 11.3%. Corrects tick 15's "about 1%" (slot 18 only) upward for the solo block.
- **Encoding** [COUNTED]: one command buffer and one serial encoder per slot; per round fold, xfold (m > 0), round kernel, part-reduce (only above 4,096 threads), one-threadgroup `k_sc_fs_step`; the host finish already exists (25 microsecond budget, knob to 250). No split kernels ship, so K6 does not apply.
- **The stream hides most of it** [DERIVED]: the 3 trailing rounds are 228 ms per request solo but 52 to 82 ms in the two-lane stream (64 to 77% hidden). Whole central tail if free: 2.5 to 3.9% of cadence; a persistent-kernel project is bounded by the same 52 to 82 ms (1.4 to 2.2%) and fits threadgroup memory only for rounds the host already takes. Realistic x1.01 to x1.02. About 0.8 ms per batch of A-minus-B gap is unexplained and not tail (about 9 to 10 ms per block, DERIVED).
- Tests: T1 (sweep `HL_METAL_BATCH_TAIL_US` over 25 to 2500, fit marginal cost per round; pass floor >= 0.09 ms beyond round 10, also removes the Shieldstral extrapolation), T2 (the per-batch fixed 0.8 ms). Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-18: Claude researcher tick 15, census of the shipped later-round body and where its time over the product floor sits (claude-cycle)

**COMPLETE, local counting and reading** (generated `k_v13` at four shapes parsed in full, the K0 to K5 bench folder and raw K5 per-round timings re-summed) plus 4 searches and 3 page reads on Apple GPU registers; **no measured improvement by me**, no build, proof, GPU run or Git. Triage material (kernel scheduling only, no ruling).
[Handoff](handoffs/20261118-claude-tick15-body-census.md) and its script `20261118-claude-tick15-body-census.py`.
- **Census** [COUNTED]: Shield slot 14 has 67 extension products (22 with a coefficient), 48 extension-by-base, 67 line values, 431 base multiplications per point; slot 18 213; 8B slots 260 and 143. Zero duplicate products, so common-subproduct sharing (c) is empty; fewer points (d) is already in (np 4).
- **The "4 to 8x over the floor" was mostly the tail** [MEASURED rounds, DERIVED floor]: rounds 6 on are 36% (Shield 14), 20%, 41% (8B 14), 23% of v13's total and do not move with the split. The bulk (rounds 1 to 5) is 2.6 / 1.6 / 2.1 / 1.4x above a floor that now includes additions and line values, and 1.6 / 1.3 / 1.6 / 1.3x after G=4: the split already took half to two thirds of the gap.
- **Tail law** [DERIVED fit]: tail per round = 0.91 microseconds x base multiplications per point at all four shapes (within 1.2%), against 0.015 to 0.041 ms for loads alone; about 14x K4's dependent gl_mul latency. Candidates: instruction fetch (12 KB instruction cache published for M1/M2 only), spills, clock state. Not a throughput floor.
- **Registers** [published, M1 family]: 128 words per thread, 104 half-words for full occupancy; M3 allocates dynamically (Apple talk) with no stated limit. Live data words with all loads first: 272 / 132 / 160 / 92; loads at first use: 112 / 76 / 80 / 56 [COUNTED, heuristic].
- **Delayed reduction** at most 3% of bulk time; production tail only about 1% of block GPU (135 to 240 microseconds per round), so x1.00 to x1.02. Tests K6 (concurrent dispatch of the split kernels, tail per round at most 0.20 ms against 0.41), K7 (same work in small code, at most 0.10 ms), K8 (loads at first use). Hypotheses 162 (as recorded by the coordinator). Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-18: Claude researcher tick 14, per-slot table traffic model for H133 and H134 from counts (claude-cycle)

**COMPLETE, local counting** (A27 slot libraries for both profiles parsed in full, `metal_slot.rs`, `metal.rs`, `metal_kernels.metal`, the slot 18/14 breakdown `summary.json`) plus 2 searches for hardware figures; **no measured improvement by me**, no build, proof, GPU run or Git. Triage material (kernel and buffer layout only, no ruling).
[Handoff](handoffs/20261118-claude-tick14-slot-table-traffic.md) and its script `20261118-claude-tick14-slot-table-traffic.py`.
- **H134 is nearly empty** [COUNTED]: after A27's materialization, 0 to 1 original table per slot is not read by the later-round kernel (W16R2_8B slot 18: 1 of 19; slot 14: 0 of 36; Shieldstral slots 14 and 18: 1 each). Skipping those folds is worth 0.1 to 0.2% of block GPU [DERIVED].
- **Fold is 76% of window 1's distinct bytes in slot 18** (1,107 of 1,460 MB); windows 0 to 4 of slots 14 to 19 are 33.6 ms, 28.6% of the 8B block GPU (24.7% Shieldstral), the ceiling for any traffic cut [DERIVED from MEASURED ms].
- **Correction to tick 13:** fused fold-eval alone is not 17 to 22%; a fused kernel reads the unfolded table, so it pays only if re-reads are cache hits and is negative (-3.8% of block) if they reach DRAM. Single fetch carries the gain; both together: 4.3% of block GPU if re-reads are cache hits, 12.7 to 15.6% if all reach DRAM (upper bounds, 8B; about x1.04 to x1.19 if GPU-paced). Antigravity's 6.7 to 10.7% sits between.
- **New H161:** base tables held at 8 B until the first fold (stored at 16 B stride today): at most 4.5% of block GPU [DERIVED upper bound, line-granular traffic ASSUMED]; larger code change.
- **Tests:** K0 (fold kernel alone and a copy roofline at slot 18's window-1 shape: B near 500 GB/s means the DRAM scenario saturates), F3 with the predicted 1.46 against 2.3 GB, H161 packed-base kbench. Hypotheses 161. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-18: Claude researcher tick 13, published GPU sumcheck designs that cut table re-reads, against H133 (claude-cycle)

**COMPLETE, literature screen plus local reading:** 6 searches, 10 page requests (3 refused; Chimera, PipeSC and SumCATS read at abstract level only, others through a fetch tool's summary); **no measured improvement by me**, no build, proof, GPU run or Git. Triage material (a kernel-only change needs no ruling).
[Handoff](handoffs/20261118-claude-tick13-gpu-sumcheck-table-traffic.md).
- **Nothing published matches our case:** no GPU sumcheck with 30 to 70 table bodies, no measured gain for evaluate-all-points-per-thread or shared-memory tiling on a prime field. "zkDuel" (queue item 28) did not resolve in two searches. H133's 50 to 70% traffic cut has no outside measurement.
- **ICICLE already fuses** the previous round's fold with the next evaluation [vendor description, no number]; its Nsight profile (L4, 4 tables of 2^25) says memory-bound in early rounds [authors' profile]. Chimera: 2.94x over ICICLE at N = 2^22, quadratic body, cause not stated in the abstract [authors' number].
- **H133 arithmetic** [DERIVED]: with e table fetches per evaluation, today (e + 1.5)N bytes per round; fused fold alone cuts 17 to 22%, single fetch alone 44 to 58%, both 67 to 75% (e = 3 from tick 12's load ratio, 4.5 from Antigravity). The 50 to 70% needs both halves and real DRAM re-reads, not shown (breakdown README's "saturation" has no counter reading; distinct rates are 52 to 95 GB/s).
- **Tests:** F1 fused fold-eval alone (pass 15% below two passes, identical buffers), F2 = tick 12's K2, F3 a DRAM-byte counter read of one round. Hypotheses 160. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-18: Claude researcher tick 12, what A27 had already timed for line values, and what to time next (claude-cycle)

**COMPLETE, local reading only** (A27 README and `kb1.log`, `kbench/` sources, the slot 18/14 breakdown README, `metal.rs`, `metal_kernels.metal`) plus `gen.py` counts on the two dumps and one arithmetic script: 0 searches, 0 fetches; **no measured improvement by me**, no build, proof, GPU run or Git. Triage material (a kernel-only change needs no ruling).
[Handoff](handoffs/20261118-claude-tick12-kbench-spec.md).
- **Correction to tick 10:** A27 had already timed line values by additions (`gen.py` `k_v2`, `kb1.log`): -30% (slot 14) and -14% (slot 18) on the old kernel, **+0.7% and -0.7% on top of the materialization** (v13 against v123: 14.1 against 14.0 ms, 14.3 against 14.4 ms). H158's 12 to 21% after A27 is withdrawn; tick 10's x1.04 to x1.14 for H158 + H159 falls to about x1.00 [MEASURED, A27 `kb1.log`; my tick 10 had not read `README.md:167-169`].
- **Why:** line values are 18% of multiplications in the shipped kernel [DERIVED], so a 0.7% effect means the body's product count is not what the later rounds wait on. First-round logical loads are 204 and 291 GB/s (distinct data 68 and 97 GB/s) [DERIVED]: not clearly a DRAM ceiling either, against the breakdown README's "100% saturation" (an inference there, no counter reading).
- **H159 (delayed reduction):** downgraded from 5 to 15% to about 0 to a few % by the same analogy [ASSUMED].
- **Spec for an owner or Sol lane:** K1 roofline (v13's loads with a trivial body; within 20% means every arithmetic idea is dead), K2 loads once per pair (H133 in miniature), K3 occupancy, K4 `gl_mul` against `gl_add` micro-benchmark (skip if K1 passes the first branch).
- No new hypothesis. Hypotheses 160. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-17: Claude researcher tick 11, which zero-check pairs are dead because of padding (claude-cycle)

**COMPLETE, local code reading only** (`slot_ir.rs`, `slot_ir_accuracy.rs`, `pad.rs`, `shape.rs`, `accuracy_act.rs`, `argument_accuracy.rs`, `metal_slot.rs`, `metal_kernels.metal`, the slot 18/14 breakdown README) plus one arithmetic script: 0 searches, 0 fetches; **no measured improvement**, no build, proof, GPU run or Git. Triage material (a kernel-only change if the test passes; no ruling).
[Handoff](handoffs/20261117-claude-tick11-gate-coverage.md).
- **Tick 10's kill condition was the wrong test:** two of the four families inside `zc` (LogUp helper relations, `fa`) carry no gate. The skip does not need the gate; it needs lo == hi constants on both ends of a pair, which makes the term the relation at an honest padded point, 0. Honest planes, the `group` column and the helpers are column-constant at padding (COUNTED / DERIVED).
- **At W16R2_8B only F pads** (14,336 of 16,384): slots 14, 15, 16, 17 have no gate. Pairs bind t first (`i, i + nhalf`, flat `t * f_pad + j`), so a pair is dead exactly when its column is, 12.5% in rounds 0 to 6, none after. Saving 1.2 to 2.1 ms of slot 18's 21.3 ms per block, 1.0 to 1.8% of block GPU, about x1.01 to x1.02 on the 8B stream [DERIVED].
- **At the Shieldstral profile** (width 3,072 to 4,096, hidden 9,216 to 16,384) the gate-zero fractions are 25% (D) and 43.75% (F): slots 14 + 18 save 10 to 18 ms of 249 ms per block, 4 to 7%, 0.26 to 0.47 s of 6.47 s per request [DERIVED, assumes 60 to 100% of the gate-zero fraction realised]. In-place fold means padded cells need no fold work for non-eq tables.
- **Test:** P1, CPU, evaluate the IR at padded round-0 pairs, all zero; P2, per-round bit-identity on both profiles and at least 1.0 ms on 8B slot 18. Not run.
- New: H160 (skip padded pairs). Hypotheses 160. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-17: Claude researcher tick 10, prover-side speedups of the zero-check sumchecks, transcript unchanged (claude-cycle)

**COMPLETE, local kernel reading (`metal.rs`, `metal_slot.rs`, `slot_ir.rs`, A27 README, kept stream phases) plus the small-value sumcheck paper (full text), zkDuel and tessera issue 391:** 4 searches, 5 reads (ePrint PDFs refused), a small arithmetic script; **no measured improvement**, no build, proof, GPU run or Git. Triage material (a kernel-only change needs no ruling; a univariate skip would).
[Handoff](handoffs/20261117-claude-tick10-zerocheck-prover.md).
- **H157 not supported at its central estimate:** base-field round 0, affine parts as tables and attained-degree evaluation are already in the kernels (A27). Small-value sumcheck beyond round 0 gains 4 to 7% at degree 4 to 5 in the paper's own cost model with today's multiplication costs (no degree above 3 measured by the authors) [DERIVED]. eq factoring saves at most a point on a slot that is three terms with three eqs. The univariate skip changes the protocol.
- **H158 (new):** every table's line value `lo + d (hi - lo)` costs a full `gl_mul` (two for Fp2) per point (`metal.rs:2247-2260`); additions would do (zkDuel's specialised interpolation). Derived share of the later-round kernel about 34% of multiplications after A27 (assumed scaling), saving 12 to 21% of the kernel; 6 to 10% before A27.
- **H159 (new):** delayed reduction in the body's sums (tessera, CPU, Goldilocks: 20 to 31%); GPU value unknown, guessed 5 to 15%.
- **Effect:** committed words none; central 15 to 25% of the slot kernels, ceiling about 35%, about x1.08 on P (x1.04 to x1.14) if GPU-bound, about half that on the two-lane cadence. Test: kbench bit-identity plus 10% on slot 14.
- Support skipping of padded columns: up to 12.5% of slot 18 at the 8B shape, only if every term carries the gate (the LogUp terms may not). Hypotheses 159. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-17: Claude researcher tick 9, the smallness test against knowledge soundness T1b (claude-cycle)

**COMPLETE, direct reading of FlashProve `rng.h` (the comment that is the source's argument) and `11-1` limits, plus the local T1b text and formal README:** 2 fetches, 0 searches, one exhaustive toy script; **no measured improvement**, no build, proof, GPU run or Git. Triage material (ruling, profile string, re-proved Lean).
[Handoff](handoffs/20261117-claude-tick9-smallness-knowledge.md).
- **H154 answered, B stays alive conditionally:** the authors' 2^-N argument fixes the object (packed cells, reads, weights) before Theta, so the error is a round-by-round event on a decoded object; no rewind past Theta is needed. The "no knowledge error" caveat belongs to their printed union-bound line (my reading). The local framework (straight-line extractor, log-reading state, `RbrWide`) fits it as one more round. The step is argued on paper, unrefereed [AUTHORS].
- **TOY:** exhaustive check of the neighbouring-values step (D = 2, two lanes, p = 59, packing plus one read, five weight pairs): worst Pr[pass] is exactly 0.5 with (1/4, 1/2, 1/4); 5/9 with uniform trits.
- **Conditions:** Lean round plus lemma; `circuit_iff` for cells in (-2^18, 2^18), not bytes; tick 7's order. Union bound `tau - log2(columns)` is conservative; N >= 100 meets lambda1 >= 100.
- **New number:** at T1a's `eps_c <= 2^-40` the honest RMS cap is about 311 (k = 4,096) and 235 (k = 7,168), not 453 / 342 (1% failure, tick 5) [DERIVED].
- New: H156. Hypotheses 157. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-17: Claude researcher tick 8, cell-plane claim sites and k per read (claude-cycle)

**COMPLETE, local code reading only:** `shape.rs` (`claim_sites`, `totals`), `layout.rs`, `argument.rs` slot bodies, census.log plane counts; one standard-library script. 0 searches, 0 fetches; **no measured improvement**, no build, proof, GPU run or Git. Triage material (ruling, profile string, re-proved Lean).
[Handoff](handoffs/20261117-claude-tick8-cell-read-count.md).
- **Correction to tick 7:** 120 A sites is the toy's table (`layout.rs:1118`); the 8B profile W16R2_8B has **110** (reproduces the census's 2,501 A rows), R13_8B 146. **67 of the 110 are cell-plane reads** (D 28, Q 9, Kv 9, S 11, F 10); 43 are not (T, L, Ht slices, table planes).
- **H153 passes conditionally:** U (2k words per read) plus 2 mask rows per read plus the proximity pair is 179-204 rows with the class-C split only, 17.0-18.7% of the A data rows B saves; 20.3% with class M split; 34-37% if the int16 word planes (class W, unmeasured) must split. Whole block about 0.80-0.90 (tick 7: 0.79-0.94).
- **Several parts:** different planes at one point need one U each; QMM/KMM/VMM share one (64 distinct vectors for 67 claims); a split limb probably needs two. Untaken credit: today's 134 A mask rows at the cell sites may be released if the Theta tie leaves few claims on packed A (38-114 rows).
- **Open:** tie claim count (H155); class W RMS (item 17); item 20 (knowledge soundness) can still stop B.
- New: H155. Hypotheses 156. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-17: Claude researcher tick 7, can the local schedule commit a contraction vector after the points (claude-cycle)

**COMPLETE, local code reading only:** `protocol.rs` (current and R13 frozen), `shape.rs`, `layout.rs`, `zkp-core/src/pcs.rs` (`open_zk`, `zpart_weights`), D55 design, T1b/T2 statements; one standard-library script. 0 searches, 0 fetches; **no measured improvement**, no build, proof, GPU run or Git. Triage material (ruling, profile string, re-proved Lean).
[Handoff](handoffs/20261117-claude-tick7-commit-after-point.md).
- **Order is satisfiable, but the local combined row is not `U3`:** it contracts packed rows (three lanes weighted 1, 2^20, 2^40, inseparable), is a lambda mixture per column-weight group, and is an uncommitted masked message. A `U3` needs its own hiding commitment, then Theta, then the digit planes and lookup: 2 (product tree) or 3 (committed helpers) extra commit-then-challenge alternations after slot 23; M must be sized for the new slots up front.
- **New cost:** the local one-reserved-pair-per-claim rule makes U mostly mask rows: at most 120 reads (A_SITES) gives 302-452 rows per block, 25-61% of candidate B's saved A rows (747-1,202); whole block 0.79-0.94 of today's (tick 6: 0.76-0.85). Read count not yet counted (H153).
- **Open:** the source's "no knowledge error" against the local T1b (H154); mask-pair sharing is a privacy ruling. Smallness union bound 103.6-105.4 bits, negligible on 2^-97.3.
- New: H153, H154. Hypotheses 155. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-17: Claude researcher tick 6, columns per cell matrix and honest cell size per A plane (claude-cycle)

**COMPLETE, local counting only:** `accuracy_layout.rs` plane and lookup lists, `range16.rs`, `accuracy_precision.rs`, census.log; one standard-library script. 0 searches, 0 fetches; **no measured improvement**, no build, proof, GPU run or Git. Triage material (ruling, profile string, re-proved Lean).
[Handoff](handoffs/20261117-claude-tick6-cell-width.md).
- **H151 killed as written, by count:** 480 of 2,256 A cell rows (21.1% of 2,279) are 16-bit lookup limbs (low limbs of two-limb remainders, RH), uniform RMS about 18,900 against a cap of about 453 / 342. Byte re-expression is mandatory and reverses D54's widening in A.
- **k per matrix:** D and Q 4,096; Kv 1,024; F 14,336 so 7,168 after a split (cap 8,191); S 128 per head or 4,096 with heads in columns. Row-weighted mean k 5,149-5,599, harmonic 939-4,847. H150 holds for D, Q, F (0.40-0.37 per cell), fails for Kv (0.58) and S at k = 128.
- **Cost:** A data rows 1,077-1,532 of today's 2,279 (0.47-0.67); whole block 0.76-0.85, **about 0.86 if helpers stay committed** (each split limb adds a lookup, about +480 H rows). B's volume gain needs helper-free lookups.
- **Unmeasured:** 672 int16-word rows and 272 conditional-remainder rows (calibration windows 9-16 bits); no per-plane RMS record exists in the files searched.
- New: H152 (post-split volume), H151b (int16 word RMS from a witness capture). Hypotheses 153. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-16: Claude researcher tick 5, how FlashProve serves a claim on one cell from packed words (claude-cycle)

**COMPLETE, direct full-text reading:** raw `11-1-machinery.md` (key parts) and `11-2` (parts of `U3`); `11-3` downloaded, unread. 3 fetches, 0 searches, one small toy script; **no measured improvement**, no build, proof, GPU run or Git. Triage material (ruling, profile string, re-proved Lean).
[Handoff](handoffs/20261116-claude-tick5-flashprove-packed-claims.md).
- **Mechanism exists, and is not an opening:** sumcheck end values land on a committed contraction vector `U3` (cell tensor summed along rows with a public weight vector); a random ternary column-compression ties `U3` and the packed M, its results committed as 10+8-bit digits and range-checked by lookup; the radix powers sit only on the digit side, where unpacking is unique (f1 checked). Answers 6b's premise, not its saving.
- **Cost:** digits `2 tau mz` words, so cell part = `1/3 + 2 tau / k` of unpacked (0.40 at k = 4,096, 0.365 at 8,191, tau = 128); k capped at 8,191; 27 + 11 lookup levels, no extra round for the equations. Statistical, error 2^-tau per column, no knowledge error per the authors' own comment.
- **New gate for B:** honest combinations must stay in +-2^17: max RMS cell about 453 (k = 4,096), 12-bit cells fail about 1.4% of combinations, 16-bit cells 88% [DERIVED]. Byte re-expression is mandatory.
- New: H150 (ratio by count of k per A matrix), H151 (honest RMS per plane). Hypotheses 151. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-16: Claude researcher tick 4, what FlashProve's cost owes to hiding the weights (claude-cycle)

**COMPLETE, partly through a summarizer:** local upstream copy read directly (performance, weight-hiding, protocol 1-7, architecture, figures.tsv); format pages 10, 11-5 and FORMAT.md
(first 100,000 characters) via the fetch tool's summary. 0 searches, 6 fetches; **no measured improvement**, no build, proof, GPU run or Git. Triage material (ruling, profile string, re-proved Lean).
[Handoff](handoffs/20261116-claude-tick4-flashprove-hiding-cost.md).
- **No separable price for hiding the weights is published.** No phase split of prover seconds anywhere; `-public-weights` runs the same protocol with a public seed (no cheaper mode, no timing).
- **Batch-size sweep fits a line:** 7.5-7.8 s per request + 34-47 s per batch (fixed part 16-21% of a 24-request batch) [DERIVED from figures.tsv]; the fixed part is an upper bound on batch-level
  weight work (two table-opening passes among other things).
- **Weight-only committed words per request are tiny:** request vector w = 2^18 words (256 per token), about 2-4 x 10^-5 of the trace [AUTHORS via summarizer; layers 48 ASSUMED]. A committed-M opening per batch survives in any public-weights variant.
- **No authors' statement on hiding prompt or output.** **Pointer correction for queue 2b:** format 13.9 is the weight-matrix / second-chain claim, not the cell packing (that is 11-1).
- New: H148 (batch time linear in requests; kill on n = 8 refit), H149 (public-weights switch gives no speed-up; needs a GPU). Hypotheses 149. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-16: Claude researcher tick 3, what FlashProve commits per activation (claude-cycle)

**COMPLETE, partly through a summarizer:** paper text read directly; repository format pages (11-1 to 11-3, 08) read via the fetch tool's summary, 11-1 only to
character 100,000. 0 searches, 13 fetches; **no measured improvement**, no build, proof, GPU run or Git. Triage material (ruling, profile string, re-proved Lean).
[Handoff](handoffs/20261116-claude-tick3-flashprove-commits.md).
- **FlashProve commits no lookup helper columns.** Its Lookup is a product-tree argument with masked sumchecks; only multiplicities are committed, as 32 bit-planes per
  table entry. **Corrects tick 1** (no published ZK GKR-style lookup found): this one hides intermediates, with Lean-checked ZK per request; it was not read then.
- **Cells packed 3 per field word** (radix 2^20, relaxed bound 2^18). Smallness test: random {-1,0,1} combinations (128), two digits (10+8 bits) per combination and
  cell row, only to prevent wraparound; exact ranges use 2^8 / 2^16 lookups with virtual keys. Programs' own union bound is 113.44 bits (misses 128).
- **Committed words per token per layer about 0.14-0.25 M against our 0.653 M (2.6x-4.6x fewer)** [DERIVED, layer grouping and flags unread]. Their cell count
  (312-338 k) matches our A values (289 k); the gap is packing plus no helpers, i.e. cycle 4's "helpers not committed and A packed" scenario. Codeword bytes not compared (trace code rate unread).
- **New:** H145 (pack small cells 3 per word; kill if under 40% of A rows qualify), H146 (smallness test for wraparound-only lookups; kill if under 10% of 2,162 range-helper rows),
  H147 (compare FlashProve's committed-mask sumcheck to the local blinding design). Hypotheses 147. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-16: Claude researcher tick 2, Celer lookup argument (claude-cycle)

**COMPLETE, but not a full read:** the paper PDF returns HTTP 403 to the fetch tool, so I read the full abstract, one search summary and the
authors' public C++ prototype. 4 searches, 12 page reads; **no measured improvement**, no build, proof, GPU run or Git. Triage material
(ruling, profile string, re-proved Lean). [Handoff](handoffs/20261116-claude-tick2-celer.md).
- **Celer's prototype is BN254 plus Dory (pairing-based)**, not hash-based; its saving is stated in group operations [code, summary]. It fails the
  cycle 6a screen ("kill if pairing or EC PCS"): **H137 closed, not a drop-in.**
- **No zero knowledge** in abstract or code (fixed-seed Mersenne Twister, no blinding). The 25.9x / 9.4x speed-ups are against plookup and plain
  LogUp [authors], hardware and field unread; the driver excludes committing the query vector from prover time.
- **Idea that may port (unverified):** LogUp-style columns over two base-sqrt(m) digits, so committed domains are about 2^14 for m = 2^28 [code,
  DERIVED]; it cannot beat the volume floor of 6a (49-51% of today's block rows).
- **New:** H144 (port the digit PIOP to Ligero-style evaluation; kill if more than 24 evaluation claims per instance or more than 600 rows per block).
  Needs the PDF read from a local file. Hypotheses 144. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-16: Claude researcher tick 1, zero knowledge for GKR-based lookups (claude-cycle)

**COMPLETE.** 7 searches, 11 page reads; **no measured improvement**, no build, proof, GPU run or Git. Triage material (ruling, profile
string, re-proved Lean). [Handoff](handoffs/20261116-claude-tick1-gkr-zk-masking.md).
- **No published ZK LogUp-GKR for hidden-activation transformers found.** Papini-Haboeck and Celer pages are silent on ZK [abstracts].
  Only tessera RFC-0032 (PR #325) works LogUp-specific masking; unimplemented, simulator pending; it **rejects** blinding leaves, which
  the local design uses (reconcile before review).
- **Mask bytes are not the problem:** local design 2,148 Fp2 coefficients per block (0.41-1.24% of a G1 block as allocated); Longfellow-style
  one-time pads 1,275 Fp2; hash-based HVZK sumcheck (ePrint 2026/391) O(k*ell_zk); full-size CFS masks 281% of a G1 block [DERIVED].
- **Closest published hash/RS analogue:** Longfellow ZK (pads plus deferred constraints inside Ligero; draft read to section 6.6 only).
  A different design in kind, not a drop-in.
- **New:** H142 (write the masked-layer simulator; kill on a degrees-of-freedom count), H143 (cost the one-time-pad route in zero-check
  terms). Hypotheses 143. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-16: Claude researcher cycle 6c, linear chains without committed intermediates, and the cycle 6 ranking (claude-cycle)

**COMPLETE.** Code reading plus 2 searches, 3 fetches (cycle 6 total 19 / 22); **no measured improvement**, no build, proof, GPU run
or Git. Triage material (ruling, profile string, re-proved Lean). [Handoff](handoffs/20261116-claude-cycle6c-linear-chains.md), script
`handoffs/20261116-claude-cycle6c-linear-chains.py`.
- **Cycle 4's "chaining is near zero" confirmed:** only X1 = X + AO and X2 = X1 + Z are linear images of committed planes (64 rows per
  block, 1.25%; `slot_ir_accuracy.rs:485,488`); rope remainders RQRL, RKRL are linear with public tables (40 rows). Matmul outputs are
  already virtual (carried as word + remainder via `host_*` terms), so word and remainder cannot be dropped.
- **New class, not in the Lean-found C1-C13:** remainder planes a relation determines pointwise need not be committed (the lookup
  queries the expression). Per block 424 of 2,279 A data rows: L1 104 (linear/public-table), L2 192 (single-limb degree-2: SR, SG, RH),
  L3 128 (top limbs of norm remainders). Request codewords 43.19 to 39.6 GB (-8.3%); worth about 8 ms of a 470 ms warm block (1.7%).
- **Published practice:** FlashProve commits the trace per segment; zkLLM leaves Z' uncommitted but hides weights only; zkGPT, DeepProve,
  TensorZKP read as abstracts. No published construction found that leaves an activation intermediate uncommitted and proves it hidden.
- **Ranking across 6a-6c (DERIVED, per request, 43.19 GB today):** (1) LogUp-GKR for all lookups -49 to -51%, risk: GKR ZK unpublished and
  unreviewed; (2) 31-bit base field for small and mask rows -25.5%, risk: small-field soundness (Fenzi-Sanso) and exactness above 2^31;
  (3) derived planes -8.3%, risk: higher-degree queries, re-stated Lean. All three together 9.4 GB (22%), write floor 1.05-1.2x plain int8.
  Ideal 4x packing (-34%) has no mechanism; binary tower (-38%) breaks integer arithmetic.
- **New:** H140 (derived planes; kill if A rows do not fall 2,501 to 2,077, or extra zero-check time exceeds 8 ms per block), H141 (residual
  sums only). Hypotheses 141. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-16: Claude researcher cycle 6b, packing small values (claude-cycle)

**COMPLETE.** 8 searches, 5 fetches; **no measured improvement**, no build, proof, GPU run or Git. Triage material (a ruling, profile
string and re-proved Lean needed). [Handoff](handoffs/20261116-claude-cycle6b-small-value-packing.md), script
`handoffs/20261116-claude-cycle6b-small-value-packing.py`.
- **No mechanism found to pack several small values per prime-field word** of a Merkle/RS commitment and use them separately. Published
  packing (FRI-Binius ring-switching, Blaze) is an embedding in extensions of a *small base field*; Goldilocks has none. One opening
  of a packed word gives one linear combination of k unknown values [DERIVED]. No ZK variant of FRI-Binius, Blaze or Ligerito found.
- **Ceilings on 43.19 GB of codewords** [DERIVED]: ideal 4x on small rows (no mechanism) 28.6 GB (66%); 31-bit base field + degree-4
  extension (parked H116) 32.2 GB (74.5%); binary tower 26.7 GB (62%, breaks exact integer arithmetic). With 6a's G2 (helpers retired):
  7.5 / 11.1 / 5.6 GB (17 / 26 / 13%), about 0.8-1.4x plain int8 bytes. Helpers (full-field) and masks (uniform) cannot pack.
- **Masking:** pad count is Q = 280 per row regardless of field or packing; only the pad share per value changes (1.7% to 6.8% at k = 4
  if rows shrink). **Soundness cautions for small-field codes:** Fenzi-Sanso (ePrint 2025/2197) attacks on small-base extension codes in
  practical regimes; Dao-Kominers-Thaler-Zheng (2026, summary) beyond-Johnson proximity gaps fail over binary fields.
- **FlashProve** (Goldilocks, hash-based): whether digits share a field element is not stated in the pages read; settle by reading its source.
- **New:** H138 (31-bit base field: kill if over 5% of small rows or any asserted relation exceeds 2^31), H139 (prime-field proof-of-packing;
  kill-by-citation). Corrects cycle 3's "8x on activation planes". Hypotheses 139. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-16: Claude researcher cycle 6a, lookup arguments that commit less (claude-cycle)

**COMPLETE.** 9 searches, 14 fetches (ePrint PDFs refused: abstracts only); **no measured improvement**, no build, proof, GPU run
or Git. Triage material: any change needs a ruling, a new profile string and re-proved Lean. [Handoff](handoffs/20261116-claude-cycle6a-lookup-volume.md),
script `handoffs/20261116-claude-cycle6a-lookup-volume.py`.
- **Per lookup today:** one extra committed word (Fp2 helper per two lookups). Of the 2,514 H rows per block: 2,162 range
  helpers, 30 table helpers, 320 exp/act, 2 `u` [DERIVED from plane lists].
- **Only LogUp-GKR removes it** (multiplicities only). Lasso, Shout (dense Merkle commit of one-hot: 64-65,536 words per lookup),
  Logup* (small-table gain needs tuples) and zkLLM's tlookup (one inverse word per lookup, ZK for weights only) do not beat today.
  Celer (ePrint 2026/1453, m = 2^28, n = 2^16, Llama; 9.4x over LogUp [AUTHORS]) is the same regime but read as an abstract only.
- **Derived volume per block (5,103 rows today):** G1 range+table helpers retired 2,911 (57%), G2 all lookups 2,591 (51%), G3 with
  H site masks 2,509 (49%); per request 24.9 / 22.2 / 21.5 GB of codewords (43.2 today). Write floor vs plain int8 5.1x to 2.5-2.9x:
  halves volume, does not reach 2x.
- **Soundness:** LogUp (N+T)/|Fp2| about 2^-103 per block (2^-98 over 32), unchanged from helper LogUp; GKR sumchecks 2^-118.
  **ZK is the open problem:** no source found publishes a benchmarked hidden-activation LogUp-GKR transformer (search summaries,
  unverified); the local masked design is unreviewed.
- **New hypotheses:** H136 (LogUp-GKR over all lookups; kill if allocated rows > 2,700 per block or GKR > 0.11 s per block on
  Metal), H137 (read Celer in full; kill if it needs EC/pairing PCS). Hypotheses 137. Proofs / passes / positions: 0 / 0 / 0.

## 2026-11-16: Claude researcher cycle 5, verification of relayed figures (claude-cycle)

**COMPLETE.** Re-check of cycles 1-3 figures against primary pages; no new research, no build, proof, GPU run or Git.
[Handoff](handoffs/20261116-claude-cycle5-verification.md).
- **13 of 14 items confirmed** (FlashProve batch curve, 18.78 MB, 220.7-225.9 s, 94.0 s check, 71.4-93.0x; TensorZKP, EmuGEMM,
  ePrint 2026/2681; WHIR 63 KiB; Ligerito 255 KiB; Thaler Table 5). No identifier wrong; none withdrawn.
- **Corrected:** ePrint 2026/2481 is "Polygero" (new RS proximity test and a Ligero-inspired IOP, Lean-checked), not an
  improved analysis of Ligero; only 2026/2681 is that. Thaler's overhead is 0.3-1.4% (Table 5), not "1-2%".
- **Quote with caveats:** 71-93x is a best case against a vLLM FP8 baseline on eight H100s, start-up and commitment excluded;
  18.78 MB is an average per proof at a 1,024-token window. WHIR and Ligerito abstracts make no zero-knowledge claim.

## 2026-11-16: Claude researcher cycle 4, committed-volume census and memory floor (claude-cycle)

**COMPLETE.** Local counting only (H133 from cycle 3); **no measured improvement**, no build, proof, GPU run, web search or
Git. [Handoff](handoffs/20261116-claude-cycle4-committed-volume-census.md), script `handoffs/20261116-claude-cycle4-census.py`.
- **Committed per request (8B, T128, 32 blocks, W16R2):** 164,548 regular rows of 2^14 words = **2.696e9 message words
  (21.6 GB), 5.398e9 codeword words (43.2 GB)**, 43.6 GB hashed [COUNTED rows from `census.log`, tied to the measured
  A/H/M/endpoint opening bytes; DERIVED words]. Cycle 3's 2.7e9 holds to 0.15%; its "40 GB" is 43.2 GB.
- **Composition of a block's 5,103 rows:** activation words 19.3%, limb and remainder planes 24.9%, Fp2 LogUp helpers 49.3%,
  masks 6.1%, tables 0.5%. 74.5% is lookup machinery.
- **Plain pass:** int8 7.9-9.0 GB (7.5 GB weights), fp16 15.4-16.5 GB; 1.80 T ops [DERIVED; 5090 figures ASSUMED].
- **Floor, 5090 at an assumed 1.792 TB/s, batch 1:** write codewords 24 ms, write and hash 48 ms, against plain int8 4.4-5.0
  ms and fp16 8.6-9.2 ms: **4.8-5.5x / 9.6-11x vs int8; 2.6-2.8x / 5.3-5.6x vs fp16**. M3 Ultra (measured 640 GB/s): 67 / 136 ms,
  same ratios. Floors are 1-2.5% of today's measured request, so volume limits the 2x aspiration, not D64.
- **H133 kill condition triggered** (floor above 4x plain int8); batching raises the ratio (5.6-11x), never lowers it. The "2x"
  planning number is unsupported for a commit-everything design. Reaching 1x added needs about 20% of today's volume, roughly
  the activation words alone.
- **H134 narrowed:** packable share 44.7% (passes its 40% gate narrowly) but a 4x packing leaves 66.8% of rows (3.4x floor);
  chaining linear layers counts to near zero (every matmul output feeds a requantization and a range lookup); the 49% helper
  rows are the big lever (B5), unpackable. Hypotheses stay 135. Proofs / passes / positions: 0 / 0 / 0.
- **Not counted:** token I/O stages (no W16R2 profile; estimated 0.1-0.4%). **Unverified inputs:** 5090 bandwidth and int8/fp16
  peaks.

## 2026-11-16: Claude researcher cycle 3, receipt size and prover cost near the computation (claude-cycle)

**COMPLETE.** 15 searches, 14 reads; **no measured improvement**, no build, proof, GPU run or Git. Triage material only:
the owner shelved size work on 2026-11-09. [Handoff](handoffs/20261116-claude-cycle3-receipt-size-and-overhead.md).
- **Size:** the only published precedent in our family for MB-scale receipts with hidden intermediates is FlashProve
  (18.8 MB per 1,024-token request) [AUTHORS]. 372 of our 819 MB is opened column data, so batching or claim reduction
  does not shrink it; wide rows plus a code-switch tower does (the local B6b study: about 40-52 MB, +13 to +42 ms GPU per
  block). WHIR (63 KiB at 2^22), Ligerito (255 KiB at 2^24), recursion and Groth16 wrap give small sizes only without ZK or
  not at this witness size. Nothing supports "< 1-5 MB for 8B".
- **Overhead:** matmul sumchecks are about 1-2% of the matmul (Thaler 2013, no commitment, no ZK); full proofs with hidden
  intermediates are 71-93x (FlashProve) and about 80-190x here. My counting floor: about 2.7e9 committed words per request
  [DERIVED, recount] puts codeword traffic alone at about 3-4x plain on a 5090. **2x is not plausible** for 8B with this
  design or any published one.
- **Ranked:** H133 committed-volume census plus a plain-int8 denominator (kill the 2x number if the memory floor exceeds
  4x plain); H134 shrink committed volume by packing and chaining linear layers (kill if packable fraction under 40%);
  H135 B6b wide rows and tower (its own kill rule, +25 ms per block). Hypotheses now 135. Proofs / passes / positions: 0 / 0 / 0.
- **Correction to cycle 1 R14:** TensorZKP (ePrint 2026/1250) does tensor-core sumcheck and encoding; field and hiding unread.

## 2026-11-16: Claude researcher cycle 2, how FlashProve's throughput scales with batch size (claude-cycle)

**COMPLETE.** Paper, repository pages and two source headers read; **no measured improvement**, no build, proof, GPU run or Git.
[Handoff](handoffs/20261116-claude-cycle2-flashprove-batching.md).
- **The batch curve is weight streaming** [AUTHORS]: weights (about 200 GB, hidden) sit in pinned host memory and stream to
  the GPU per layer group; a batch pays for two opening passes over all of them, and up to 6 requests share each further
  pass. My fit of their four points: batch time about **52 s fixed + 7 s per request** [DERIVED]; fixed is 88% of a
  one-request batch and 23% at 24. Each request still gets its own trace commitments and proof; **no one-commitment-over-
  many-requests** (that is SLP, a different paper, no zero knowledge).
- **Latency at 24:** 221 to 226 s from batch start to release, plus about 94 s for the provider's check of 24 proofs
  (not in the rate) [AUTHORS]. Their forward pass runs on the GPU inside the timed interval, one request's turn per
  layer group. Zero knowledge and completeness are proved for one request per proof, not batches; a joint claim for B
  proofs costs log2(B) bits.
- **Transfer to P1 is small.** No weight table to open and weights resident, so the curve does not transfer (the
  fold is under 0.1% of readiness [MEASURED, 125M]). Cycle 1's H127 table-sharing is **not** what FlashProve does.
- **Ranked:** (1) measure the request-independent share of one request's proof time, **kill the batch-transcript line
  if under 10%**; (2) H132 K-request batched exact forward (kill if K = 4 per-request wall above 0.8x K = 1); (3) H131
  chained fork seeds for single-request latency (kill if under 15%; changes bytes). Gain on stream throughput x1.00 to
  x1.15 at best. Hypotheses now 132. Proofs / passes / positions: 0 / 0 / 0.
- **Not read:** the prover's forward, attention and memory-plan sources; the repository pages are tool summaries, the paper
  was read directly.

## 2026-11-16: Claude researcher cycle, literature scan (claude-cycle)

**COMPLETE.** Web search and reads only; **no measured improvement**, no build, proof, GPU run or Git.
[Handoff](handoffs/20261116-claude-cycle-literature-scan.md).
- **FlashProve's 110 tok/s is a batch figure** (its own repository): 17.4 at one request, 76.3 at 8, 111.2 at 24,
  123.3 at 64, one H100, 1,024-token windows, weights hidden, prompt and reply public [AUTHORS]. Quote the batch size
  when claiming parity.
- **Top three:** H128 exact int8 tensor-core witness forward (kill: over 9 ms per 8B block on the 5090); H127 one batch
  transcript so shared LogUp tables are built once (kill: table-build share under 5%); H130 improved Ligero analysis
  (ePrint 2026/2681, 2026/2481) as part of a W16R3 profile. H129 (grinding bits) is capped by the LogUp bound.
- **Rejected:** Bolt, Blaze, Quasar, ReedWeave (field or structure mismatch), GPU sumcheck libraries (other fields,
  memory-bound), CUDA carry-less multiply (binary fields). Hypotheses now 130.
- No literature result changes the 5090 limiter (host path and witness chain). Proofs / passes / positions: 0 / 0 / 0.

**2026-11-04 (coordinator), H124 partly landed, byte-identical:**
- **Witness:** the weight products are tiled and use an exact i16 path. One 8B block's witness went from 0.438 to
  0.249 s, its products from 0.361 to 0.085 s [MEASURED].
- **One request:** the witness went from about 8.6 to 3.1 s, giving 9.0 → 15.3 tok/s on the target's clock
  [INFERRED]. Proof-only is 24.25 tok/s.
- **What's left in the witness** is the builder's poorly parallel remainder (about 0.16 s per block at 32 threads)
  and the serial forward chain.
- **The target is now D64:** meet or exceed FlashProve (about 110 tok/s; see `AGENDA.md`). Re-project the RTX 5090
  case against ≥ 110, with request batching.
- Details: `results/zk60_h124_witness_20261104/README.md`.

**2026-11-04 (night, coordinator), H124c measured; it corrects the 15.3 above.**
- The 15.3 built the 32 witnesses in parallel from known block inputs. A real request's forward chain is serial, and
  it was outside every clock.
- Measured on the clock (one W16R2 8B T128 request, forks N = 6):
  - the sealing pass (32 serial full builds) 8.22 s;
  - forks with every witness built just in time 7.35 s (prebuilt: 5.63 s);
  - **one request end to end 15.57 s = 8.2 tok/s.** Keeping the sealing pass's witnesses would give about 9.2
    [INFERRED].
- **The critical path is the serial chain, 0.257 s per block.** Building and proving compete for the CPU: on-the-clock
  builds cost the forks 1.7 s.
- **For the researcher:** the H124 entry's "target clock ×2" is spent. The levers now:
  - the builder's remainder (it shortens the chain);
  - keeping the sealing pass's witnesses;
  - pipelining requests (one's chain during the previous one's forks);
  - GPU products (H124b).
  Any 5090 re-projection for D64 must carry the serial chain per request.

## 2026-11-03: Claude researcher cycle (D50): the RTX 5090 projection and the levers re-ranked

**COMPLETE.** **No measured proving improvement.** Only `research/zkp-efficiency/` was written. There was no build,
proof, GPU run or Git write; the one micro-benchmark was a 0.03 s byte scan.
[Experiment](experiments/rtx5090-projection-20261103/README.md) ·
[Handoff](handoffs/20261103-rtx5090-projection.md) ·
[Dated report](progress/20261103-claude-rtx5090-projection.md).

**The 5090 projection** (W16R2 at Q = 280 + D55, one request, 8B T128) [MODEL on ESTIMATE ranges]:
- **Proof only** (the Mac's 22.9 clock):
  - p10–p90 **54–82 tok/s** with today's serial head;
  - **69–117** with the H122/H123 head fixes;
  - about **40** for a pessimistic straight port.
- **Limiter in the central case:** the per-fork host path (about 0.21 s per block, mostly one thread), with VRAM capping
  the fork count near 8. Not the GPU (26.5 ms per block).

**The witness: the main finding** [INFERRED].
- **What the harness shows.** The D55 A/B harness spends 8.48–8.71 s per call building the 32 witnesses outside the
  timer, in all five logs. That is about 0.27 s per 8B block, against 0.17 s per block of proving.
- **Why it adds directly.** D55's phase 1 needs every boundary plane before any fork, so the forward chain is a serial
  prefix of one request.
- **Under the target's clock** (witness work included):
  - the Mac's one request is about **9 tok/s**;
  - a 5090 with today's witness code is **6–11**;
  - with an exact GPU int8 forward it is **48–76**, P(≥ 50) ≈ 0.86.

**Levers re-ranked** (×, Mac one request / 5090 central):
1. H124 witness: target clock ×2 / 6–11 → 48–76.
2. H122 preflight: ×1.06 / ×1.22.
3. H125 host path on the device: ×1.00 / ×1.05–1.19.
4. H121 per-fork queues: ×1.0–1.25 / built into the streams regime.
5. H123 boundary commits in parallel: ×1.03 / ×1.10.
6. Coefficient-form rows: ×1.09 / ×1.01. Changes bytes; needs a ruling.
7. #2 zero-check kernels: ×1.02–1.11 / ×1.00–1.01.
8. #3 equal-size batching: ×1.03–1.08 / ×1.02–1.03, with −28% core bytes. Ruling.
9. #4 non-power-of-two F: ×1.04 / ×1.01. Ruling.
10. H114: ×1.00 / ×1.01–1.02.
11. #5 pruned NTT: ×1.01. Drop it: at rate 1/2 it is −0.7 ms.

**Mac totals:** byte-preserving levers 26–28 tok/s; with the byte-changing ones 31–37.

**Hypothesis bookkeeping** (126 in total):
- **Adopted from `handoffs/20261101-gpu-work-per-block.md`:**
  - H117 (rate 1/2 + coefficient form): rate 1/2 is **done** as W16R2 (D59, measured ×1.11 core); **H117b**,
    coefficient form, stays open.
  - H118 (δ/2 accounting): **adopted** (D59).
  - H119 (point at infinity): **narrowed**. After M13, shared per-point loads come first.
  - H120 (equal-size batching).
  - H121 (per-fork queues + GPU-busy attribution): **H113's remainder merged here**.
- **H112 retired:** subsumed by D55 while GPU-bound.
- **New:**
  - H122: per-request serial preflight. 0.377 s; 7 GB of i8 scanned with `contains`.
  - H123: serial D55 commit phase. 0.226 s for 31 boundaries.
  - H124: the witness forward chain.
  - H125: the 5090's host path against VRAM-capped forks. M5a's Mac negative does not transfer to it.
  - H126: on the 5090 one request prefers T128 (T256: 65.6 against 107.9 tok/s); many requests are bounded by the GPU
    and the host cores.

**Top three now:** H124, H122, H125.

**For Victor.** Coefficient-form rows change every byte, so they must either join W16R2 before registration (sharing
the open Q = 280 branch's gate cycle) or wait for a W16R3 string. Hiding and the δ/2 lemma hold in form. **#3 and #4**
need rulings too.

**Next** (Mac, after the heavy lock frees; all small):
1. a direct `witness::build_accuracy` clock on one W16 8B T128 block, split into matmul and the rest;
2. a preflight sub-step timer;
3. getrusage CPU-s over a D55 forks phase;
4. per-fork MTLCommandBuffer timestamps.

New full-stack proofs, passes and proved positions: **0 / 0 / 0**. The complete private 8B at ≥ 50 proved tokens/s on
an RTX 5090 remains **unachieved**.

## 2026-11-01: Claude researcher cycle (D50; the Codex explorer cannot run on the Mac)

**COMPLETE.** **No measured proving improvement.** Only `research/zkp-efficiency/` was written. There was no native
build, proof or GPU run, and no Git.

**LogUp-GKR measured (H107 → H111).**
- **What ran.** A streamed W16 LogUp-GKR prover and verifier on zkp-core's field, CPU, rayon.
  - 112 checks pass, including an independent reference prover and 9 negative controls. An out-of-table leaf breaks
    the identity, and a `(0,0)` leaf is caught only by the root-denominator check.
- **Time at 2^25 leaves** (32 threads, shared M3 Ultra, medians, n = 5): **GKR 0.160 s against helper commit
  0.180 s**, plus 0.003 s of helper writes.
- **Counted per leaf:** 10.4 Fp2-eq multiplications, 180 B of traffic, 16.1 B of heap. Proof 20.8 KB unmasked.
- **Kill rule: NOT KILLED.**
  - The ratio is 0.32–0.60 under the full accounting (ESTIMATE: the helper zero-check share is attributed by table
    count); on measured parts only it is 0.91.
  - The bytes clause holds: 187 against 132 B/lookup.
- **Metal (ESTIMATE):** range-only ×1.00–1.15; all lookups with `H` retired ×1.07–1.25.
- **ZK note:**
  - Libra's `Z` vanishes at the Boolean child bit, so take it over the parent coordinates only.
  - Layer 1 gets two independent-scale blinding leaves.
  - The leaf claim enters the domain zero-checks as one linear term each, with no new openings.
  - +48 to 144 `M` rows; receipt about −5.1 MB per block.
- [Experiment](experiments/logup-gkr-20261101/README.md) ·
  [ZK note](experiments/logup-gkr-20261101/ZK_DESIGN_NOTE.md) ·
  [Handoff](handoffs/20261101-logup-gkr-w16.md).

**New hypotheses H111–H116** (116 in total). Top three:
1. **H112, cross-block host/device pipelining.** Host phases are about 0.21 s of the 0.578 s instrumented block, so
   overlapping them gives ×1.3–1.6 throughput. Byte-identical; no ruling.
2. **H113, the device round-latency floor.** About 0.3 ms per round over about 190 rounds, about 0.057 s per block.
3. **H114, exp/act helper inverses by public-table gather.** Byte-identical; −0.015 to −0.02 s.

Then H115 (small-value zero-check rounds) and H111 (GKR, all lookups). H116 (small-field rebase) is parked.

**Next.** The native owner should measure H112 (two concurrent W16 blocks on Metal) and H113 (GPU timestamps for slots
00, 01 and 21). If H111 is pursued: a fan-in-4 bottom layer and a minimal Metal kernel for the two bottom layers.

New full-stack proofs, passes and proved positions: **0 / 0 / 0**. The complete private 8B at ≥ 50 proved tokens/s
on an RTX 5090 remains **unachieved**.

## Previous state (cycle 0173, Codex explorer)

Cycle0173 COMPLETE: 20261030T214123Z-4c34fc82.
Start21:41:23Z; checkpoint2026-10-30T21:55:58.569107+00:00; deadline22:01:23Z.
Next cycle no earlier2026-10-30T22:41:23Z. Read AGENDA.md EVERY cycle.

**No measured proving improvement.** Coordinator DeepProve mandate/study read.
H107streamedLogUp-GKR prerequisite:16synthetic byte-lookup casesN1024..65536,
10tiny roots, every layer,131072pairentries and query/table identities match
independent arithmetic. Main247337checks/13controls; standaloneaudit179checks
plus3controls. Bottom-up root construction only, NOT a GKR proof. Discarded
layers still need recomputation/storage during top-down proving.

NewH109: equal-denominator cancelling leaves(s,r),(-s,r) yield(0,r²) and leak
quadratic character of privateD. F121two valid equal-length cases have disjoint
60element supports(TV1); GLFp2withcomplete256byte table confirms values0/1
oppositecharacters. This rejects one sketch realization, not native code.
Candidate(s,1),(-s*r,r) with fresh r uniform nonzeroFp2 and s uniformFp2 yields
(0,r), so D*r is uniform Fp2* only. Root marginal is NOT joint-view privacy.
Base-field-only scales, disclosed/reused scales,unconstrained false-statement
cancellation and zero denominators remain negatives. Keep all roots/layers
private pending simulator/versioned construction. No native RNG change.

NewH110: public pairtable finite differences use1Fp2multiply+65535subtracts
instead of65536multiplies;196608entries/12roots/4controls pass.1MiBtable and
8logicalB/lookup gathers remain. Rebuild for fresh effectivealpha(alpha-
gamma*TAG_U8); only public shape/index plans reusable. Final all-inroot slower
11/12diagnostic cases; initial11/12 retained. No wall/proof gain claim.
Main2.131s/19992KiB;audit0.167s/15400KiB;recurrence1.730s/20716KiB,
one nice19CPU/256MiBAS. Every experiment<60s/512MiB. No native build/GPU.

All108prior hypotheses preserved,110total. Top3: ownerverifiedhighendGPU
resident1/2/4/8;admittedcontext/DD/fidelity;exclusivenativeclocks/capacity.
H107architecture priority4,H109/H110components4.1/4.2;H103priornativegates5;
H108pathsizeexplanation remainsnegative8. HistoricalH30.03/152.2s is phase
attribution only;54ns/lookup16-thread and170B/lookupGPU areownercostlaws.
All-inGKR/privatebindings unknown; owner1.37..1.57roofline remainsmodel.

Next local experiment: adapt the existing cycle0109 tiny top-down fraction
layer consumer to an explicit hidden-root/leaf-mask contract. Enumerate every
new layer message, original-A/histogram leaf claim, CFS/Libra mask and opening
group; test its joint-view distribution/rank in a toy field before larger
arrays. Preserve the prior mask-row capacity negative. Main/Claude and the
security owner review the construction; the native owner handles matched
masked receipts and exclusive whole-workload GPU clocks under shared locks.
Do not duplicate D53's Claude GPU-classifier lane or the R14 review.

New independently verified full-stack proofs / complete-model passes /
proved positions: **0 / 0 / 0**. Actual model context: **none**; passes: **0**.
Device: Intel Core Ultra9 185H, one low-priority CPU affinity, **no GPU**.
Witness, proof, serialization, verification, startup and initial-prefill
clocks, startup fraction, proof latency/bytes, steady-state and total-workload
proved-token rates: **unmeasured**. No long-context prefill, resident-model
proof series or decode ran. Synthetic lookup count is not context length.
Complete private8B **>=50 proved tokens/s on RTX5090 or another named high-end
GPU remains unachieved**. Larger workloads remain allowed; attention can
grow quadratically. No mask, pad or private-opening reuse is proposed.

Historicalolder8BCPUT128/L32 one16-threadGPU-offpass478.737s(0.267370/s),
prove393.785s includeswitness98.348s/load17.595s;seal84.824soverlapswitness
80.897s/load27.151s;receipt922711264B;verify42.709s+load13.681s carriedonly,
notrerun/reverified/newlycounted. Do notsum nestedclocks. R18one-loadbatch
2.407%saving andloadshare3.193% arecarry-only;loadshareisnotstartupfraction.

EightLIVErecords1168->1176. LogUp-GKR/Libra/Logup*refresh;DeepProve
lookupdocs/release/license;Oct26zkDuel;newolderfinite-differenceassessment
viaNISTDLMF(siteversion1.2.8Sep15,2026,notchapterrevision). PDF403/raw/commit
Cachemisses recorded; no inspected externalcommit or foreign execution.
Onlyresearchoutside runtimewritten;no production/Git/receipts/calibration/
gates/instructions/reviewer/build/GPU/install/externalwrite/message/purchase/
escalation/merge/restart/liveness action. Main/Claude reviews and integrates.

[Experiment](experiments/streamed-logup-root-blinding-20261030/README.md) ·
[Handoff](handoffs/20261030-streamed-logup-root-blinding.md) ·
[Dated report](progress/20261030T214123Z-4c34fc82.md).
