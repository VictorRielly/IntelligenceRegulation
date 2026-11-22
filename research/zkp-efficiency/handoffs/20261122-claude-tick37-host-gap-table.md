# Research handoff: which host gaps the composed bundle removed, and which remain (2026-11-22 UTC, claude-tick 37, queue item 61)

From Claude, the background researcher. One bounded cycle; local reading and arithmetic only (no web, no run, no build, no Git). **Triage material, not a work order.** Every candidate below is host-side and keeps the committed words; any that changes what the prover draws or commits needs the owner's ruling, a new profile and re-proving in Lean.

**Read, and how.** In full: `results/zk60_composed_app_20261122/README.md` and `composed_summary.py`; the four traces (`raw/traces/cm_trace_leg1` arm A, `cm_trace_leg2` arm C, `cm_smoke_leg1` arm C, `cm_smoke_leg2` arm B, all `.tsv.xz`, read by the script); `classify_run.rs:185-330` (the block loop); `protocol.rs:2350-2548` (before-challenge part); `boundary.rs:340-352`; `zk.rs:502-539`; the Batch 6 one-block 8B log (PB-TIMING rows); ticks 24, 31, 33. Script `20261122-claude-tick37-host-gap-table.py` (standard library, `-I -B`, takes the `raw` directory) prints every number. Labels: MEASURED (a trace or record), COUNTED (code line), DERIVED (my arithmetic), ARGUED (reasoning, not tested).

## 0. Headline

1. **The 53 ms is one thing: the sparse fold.** The gap table sums to the arms' host times and the cut is 53.4 ms a block (A 284.3 to C 230.9). **40.2 ms of it is the opening region** (slot 22 to gather 38: 59.5 to 19.3 ms), which is where the host store fold ran before. The always-on host changes show **about 5 ms** in the gap table, not 20. The rest of the cut is small items inside noise.
2. **Only a third of the cut reached the block period.** Period 542.3 to 524.8 ms (-17.5): gap -53.4, but buffer execution +21.1 (spfold buffers 9.5; commits -8.9 per the README; the zero-check slots about +20 under more crowding), queue wait +14.6. The opening region's wall fell 29.7, not 40.2 ms.
3. **Remaining host gap in C is 230.9 ms a block (44% of the period). Four gaps are 75% of it** (174 ms): A to H commit 54, slots 4 to 14 45, boundary commit to A commit 39, gather 38 to boundary commit 36. One new candidate came out of the code reading: the lookup histograms are computed twice per block (item (b)3).

## 1. Method and the pass check

Request thread = thread with over 1,000 buffers (six; no other thread holds a prover buffer in the window, so nothing is lost off these). A block runs from one A commit (`rows=2504`) to the next on the same thread; 1,200 blocks per arm (25 per request, 48 requests), kept when the first A commit begins inside [completion 6, completion 54] (README rule). Gap = begin of the next buffer minus done of the previous one; no gap is negative (0 of about 22,000 an arm). The period telescopes: encode 0.5 + queue + execution + wait + gap = period, exact by construction.

| arm | period | encode+gap = host | README host | difference |
|---|---:|---:|---:|---:|
| A (pushed head) | 542.3 | 284.8 | 295.7 | -3.7% |
| C (both switches) | 524.8 | 231.4 | 242.5 | -4.6% |

**Pass (within 5% in both arms), narrowly.** The README divides the whole prove call by 26; my table has 25 block periods. The prove call also holds 0.39 s before the first A commit (stage IN-C, first block load; 0.390 A, 0.388 C) and a last block of 0.495 / 0.476 s: (0.390 + 0.495 - 0.542)/26 = 13 ms, against the 11 ms difference. That head, 0.39 s a request (2.3% of the lane period), is not in the table.

## 2. (a) The gap table, by code phase (ms a block; MEASURED)

| phase (code, from `classify_run.rs`, `protocol.rs`) | A | C | smoke B | smoke C |
|---|---:|---:|---:|---:|
| G1 openings tail: slot 22 to gather 38 (`open M`, schedule audit, store fold, open A, H, B_(k-1)) | 59.5 | 19.3 | 57.5 | 19.0 |
| G2 gather 38 to boundary commit (opening tail, `encode_segment`, sink, next block's load and statement check, `boundary_plane`, `boundary::prepare` host part) | 34.4 | 36.0 | 40.1 | 33.9 |
| G3 boundary commit to A commit (`src.witness`, A rows, lookup histograms, mask draw) | 46.3 | 38.6 | 40.1 | 41.3 |
| G4 A commit to H commit (M commit, absorbs, challenges, helper inverses, H masks) | 58.6 | 54.4 | 57.2 | 56.3 |
| G5 slots 4 to 14 (nine matmul slots, host) | 49.0 | 47.4 | 48.7 | 46.9 |
| G6 all other slot-to-slot gaps, H commit to slot 0 | 36.4 | 35.1 | 35.6 | 35.3 |
| sum | 284.3 | 230.9 | 279.4 | 232.7 |

The gap keys with the largest A-minus-C: slot 22 to gather 2504 29.25 and gather 2504 to gather 2606 28.39 (both gone in C; replaced by spfold keys slot 22 to spfold 6.97, spfold to gather 6.11, gather to spfold 3.15, 1.73, 0.79, 0.54, together 19.3), boundary commit to A commit +7.78, A to H commit +4.17. C larger: gather 38 to boundary commit -1.62. Sum of all differences 53.4; positive ones 74.7.

**Not all of G1 is removed time.** Wall from slot 22 done to the boundary commit's begin: A 105.4, C 75.6 ms: 29.7 saved, because C puts 9 ms of fold execution (and the fold's queue wait) into the region. The 10.5 ms is a device cost the host cut bought.

**Where the stage's cut went:** about 40 ms G1 (the sparse switch, since smoke B has G1 57.5 and smoke C 19.0), about 6 ms G3 (A 46.3, B 40.1, C 38.6), 2 to 4 ms G4, others under 2.

## 3. (c) Can the arm-B smoke split the cut?

**For the host gaps, yes, roughly; for the rate, no.** The smoke legs hold 150 blocks (one request per lane, window of 6 completions). Noise check: smoke C against the traced C agrees per group within 2.7 ms (sum 232.7 against 230.9), so the window is steady enough for gaps. Then B against A: G1 -2.0 (noise), G3 -6.2, G4 -1.4, G2 **+5.7 (larger in B)**, total -4.9 ms. So the sparse fold carries about 38 to 40 of the 53 ms; the always-on part and the fused encoder together at most about 5 ms of gap, with a G2 term that goes the other way. But the timed set measured B over A at +4.2% and +5.1%, half of the bundle's gain, which 5 ms (0.9% of the period, about 0.3% of the lane period at the 33% pass-through of section 0.2) does not explain. Two locations to look: `w16_histograms_cols` (always on) is also called in the sealing pass, `scan_lookup_misses` (`protocol.rs:643-661`) from `check_lookup_misses`, which `classify_run.rs` runs per block in `seal_check`; the sealing window is 2.779 s (A) and 2.671 s (C): -0.108 s, 0.6% of the lane period, from 45 requests each. That does not explain it either. **I do not split the rate gain between the parts**; smoke B has no matching arm A smoke (the A trace is another run, with exec 202 against B's 226 ms, a window effect), and only a traced A, B, C triple in one set would. Not scheduled.

## 4. (b) The ten largest remaining gaps in C (MEASURED the gap; ARGUED what could remove it)

| ms a block | key | what runs there (code) | ARGUED removal |
|---|---:|---|---|
| 54.4 | A commit to H commit | `mask_commit_tagged` (host CPU NTT and keyed hashing, `zk.rs:502`), the root absorbs, helper inverses (six domains, exp and act), table helpers, H mask rows; solo 8B rows: M 5, inverses 8 + 9, tables 1, masks 2 = 25 ms (Batch 6 log); six lanes x2.2 | M commit reads no transcript (`protocol.rs`, comment at the A root), so it can overlap A's device wait: at most 5 ms solo. Inverses on the device: I found no record of it in the files read; untested (work moved host to device raised the rate in this very test, but the device also crowded). |
| 45.4 | slot 4 to slot 14 | slots 5 to 13, the nine matmul claims, no buffers; solo 8B 26 ms (PB-TIMING) or 11 (SLOTSTEP) | hide behind another lane's device time only if lanes unbunch; no code idea. **At the app this is 8.7% of the block period**, not tick 24's 1.7% of an 8B fork call (63 ms was a union over six overlapping forks per call, here it is per request thread, 1.18 s a request). Item 40's closure should not carry over to the app profile. |
| 38.6 | boundary commit to A commit | `src.witness`, A planes 13, lookup values and byte histogram 10, exp/act 2, mask draw 3 = 28 ms solo (Batch 6) | see 3 below; the rest reads no transcript, but tick 33's before-part-ahead (A36) lost 80 ms a block at six lanes. |
| 36.0 | gather 38 to boundary commit | `encode_segment`, sink (tick 31: 21 to 25 ms: SHA-256 about 11, write, F_FULLFSYNC, rename), block load plus the repeated statement check (tick 32: 8.6 ms), boundary host part | writer hand-off x1.013 to x1.035 and repeat-check removal x1.012 to x1.019, both at their ceilings (ticks 31, 32); both under 5%. |
| 8.05 | slot 17 to 18 | table build and claimed sum of slot 18 | none identified |
| 6.97 | slot 22 to spfold | `open M` (3 ms solo) and the schedule audit, new in C | none |
| 6.22 | H commit to slot 0 | transcript absorbs, slot 0 setup | none |
| 6.11 | spfold to gather 2504 | open A host work after the fold | none |
| 5.14 / 4.67 | slot 3 to 4 / slot 0 to 1 | slot setup | none |

Top ten 211.5 of 230.9 ms.

**New candidate H1: the lookup histograms run twice per block.** `w16_histograms_cols` is called from `scan_lookup_misses` in the sealing pass and again in `prove_core_before_with` (`protocol.rs:2407`); `CoreHints` carries only the statement check (`classify_run.rs`), not the histograms. The second call is part of the 10 ms "lookup values + byte histogram" row solo (Batch 6) and of G3's 38.6 ms. A cache keyed by block object and shape (as A33's check precondition) would remove it; same bytes, same refusal order (the CS-3 refusal must still precede the first draw). Cost: the histograms held per block from the sealing pass to the block (size not counted; A33 already holds 7.2 GiB of planes per request).

## 5. Falsifiable tests

- **H1 (CPU, no run of the GPU):** a counter around `w16_histograms_cols` in a one-block Shieldstral-profile CPU test: calls per block, and equality of the two outputs. Expect 2 calls, equal outputs. If 1 or unequal, H1 dies.
- **H1 effect (needs a traced six-lane leg, not scheduled):** G3 at least 8 ms lower against C's 38.6 with the cache on (noise about +-3 ms from smoke C against traced C), receipts equal under the previous verifier. Predicted 10 to 20 ms (solo 10 ms x1 to x2 stretch); pass 8; kill under 4.
- **G5 (reading plus one traced one-lane leg):** if G5 at one lane is near 26 ms the x1.7 is six-lane stretch; if near 45 ms the solo log's 26 is not this phase.

## 6. Honest expected effect

Committed words: 0. Proved tokens/s: a ms off the gaps a block is 26 ms a request = 0.15% of the 17 s lane period at full pass-through; this pair passed 33% to the block period (17.5 of 53.4), which would be 0.05% a ms. H1 at 10 to 20 ms: **0.5% to 3%**, under the 5% rule at its ceiling: not scheduled. The big lump left is the host inside the prove call as a whole (231 ms a block plus the 0.39 s head), but the pair also says device execution rose 21 ms as the host cut shrank gaps: the lanes' host time and device crowding trade against each other, and the table cannot price a cut without a trace of it.

## 7. Risks and what was not verified

One traced pair (A then C), one run each; the traces carry the diagnostic trace overhead. The smoke window is 150 blocks with noise of about 3 ms a group (one comparison). The 38-row commit is identified from the code order (`classify_run.rs`: `boundary::prepare`, then `prove_core_with`, then the previous boundary's opening), not from a label in the trace. Solo 8B figures (Batch 6) stand in for six-lane app phases; the x2.2 and x1.7 are my ratios to them, and the profile differs (8B against W16R2 Shieldstral). The lane-period figures (17.645 against 16.780 s, -4.9%) are from 39 pairs and are not the README's traced rate (+4.1%); do not mix them. The lane remainder (period minus sealing, hand-over and run: 0.354 s in A, 0.049 in C) is unexplained and untouched here.
