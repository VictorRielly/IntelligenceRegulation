# Research handoff: FlashProve's read descriptor and the recombined lookup key (2026-11-24 UTC, claude tick 51, queue items 82 and 83; H155, H157, H156c)

From Claude, the background researcher. One bounded cycle: reading only, 2 fetches (the two raw pages), 0 searches. No run, no build, no Git. Clock at writing 2026-11-24T00:08Z. **Triage material, not a work order.** Any change to what is committed alters proof bytes and the verifier and needs the owner's ruling, a new profile string (D17) and re-proved Lean (D63). The owner shelved proof-size work on 2026-11-09; this concerns candidate B's committed volume under D80.

**The questions.** Item 82 (H155/H157): is the `M` term of the smallness test's tie one evaluation per packed matrix, and may one read's row weights span two cell-row blocks (a low limb and 256 times a high limb) with one `U3` entry? Item 83 (H156c): may a lookup key be the recombination `lo + 256 hi` of two committed planes of one domain, with the same multiplicity planes and helper count as a single-plane key?

**Read, and how.** Raw files of the public FlashProve repository, main branch, downloaded whole (the same byte counts as tick 5's: 112,280 and 83,202 characters): `docs/format/11-1-machinery.md` lines 262-300 (parts and reads), 445-520 (forms and the one equation), 864-930 (planes' parts, the join and key forms), 1109-1165 (arrays and `U3`), 1240-1360 (equations, claims, weights), 1388-1425; `11-2-feed-forward-segment.md` lines 387-412 (tensors and limbs), 478-524 (parts and reads), 578-640 and 733-760 (the keys). Local, in the retained tree `results/zk60_sol_20261105_w16r3/b3/source-d78-437/hashline/src/private_block/`: `argument.rs` 2111-2160, `accuracy_layout.rs` 298-356, `range16.rs` 133-175, `shape.rs` 2557-2612, `layout.rs` 769-790. Not read: FlashProve's verifier source (`vf_*.inc`) and the Lean sources; the queue's line numbers (`shape.rs:2563-2578`, `argument.rs:1749-1765`) are for another tree and were not found there, so the lines below are this tree's. Labels: **COUNTED** (file:line), **[AUTHORS]** (the pages), **ASSUMED**.

## 0. Headline

- **Item 82, first half: yes.** The array term of the tie is `M_mu{rw_mu}[c]` weighted by `colw_mu(c)`: one combined row of the packed matrix per matrix, with one row-weight vector `rw_mu` (the powers of chi^tauP, a product over the bits). The `mp_mu x tau` equations EP are folded by powers of chi into that one claim. [AUTHORS 11-1:1285, 1320, 1348]
- **Item 82, second half: not forbidden, not used, and the layout is against it.** A read is a pair (part, block); a part has one matrix and one public weight vector `phi_f` of `len(f)` entries; entry (c, b) is the weighted sum over the `len(f)` consecutive cell rows of block b in column c. No entry spans two blocks. FlashProve combines limbs in the claim's form, not in `U3`: `RS = sum over lb of 256^lb U3[...]` takes one `U3` entry per limb. [AUTHORS 11-1:262-275, 1121-1125; 11-2:514-518]
- **Item 83: pass, from the local code and the text.** A key is already an affine form over committed planes with public coefficients, in both. The local helper relation reads `alpha - (cst + sum of coef x v[plane])` over any number of terms, and an existing lookup already has a two-plane key. The helper count depends on the number of lookups, not terms. FlashProve's own key table has `g0 + 256 gh` and `g0 + 256 gc`. So tick 6's "+480 helper rows" is not forced by the lookup machinery.

## 1. Item 82 in detail [AUTHORS]

1. **The tie.** `TIE_mu = sum_i cellw_mu(i) (ZZ{pw}[off+i] + 2^10 ZZ{pw}[mz+off+i]) - 2^17 spw sum cellw_mu(i) - sum_c colw_mu(c) M_mu{rw_mu}[c]` (11-1:1285). `cellw_mu(i) = rw_mu(floor(i/3)) 2^(20 (i mod 3))` (1075): the packing's radix weights are inside the tie, three cell rows per packed row. The frame sees `M_mu` once, as one combined row with weights `rw_mu` (1320). So **one array evaluation per packed matrix per segment**, which supports H155's "one tie claim per matrix" (tick 49). A matrix committed in an earlier segment is tied again in each segment that lists it, with its own sampled `Theta` and digits (1300).
2. **A read.** `READ_q`, q = (f, b), has `ER(f, b, u)`: `sum over r < len(f) of phi_f[r] val(u, crow + r)` against `sum over c of Theta[c][u] U3[at(f) + c nb(f) + b]`, `crow = off(mu) + b len(f)` (1246-1249). The entry is `U3[at(f) + c nb(f) + b]`: column c, **one** block b. The same `phi_f` applies to every block. No entry has weights that run over two blocks.
3. **Where limbs combine.** A tensor's limb lb is the feature `OFF + (lb cnt + ix) J + j`: lb is the **slowest** index, so the limbs of one value are `cnt J` features apart, in different columns or different row groups (11-2:395-406). The value is `sum_lb 256^lb cell(feat(lb))` and is read as `sum over lb of 256^lb U3[...]` (11-2:514-518): **FlashProve's own use of two limbs is two `U3` entries**, combined with the public 256 in the claim's form.
4. **What the grammar permits.** `phi_f` is "a public weight vector" fixed before round `RNG` (11-1:1399-1402); the column weight the test puts on `ZZ` is `phi_f[i mod len(f)]` taken as given (1313), and only the **row** weights of arrays are restricted to the three shapes (1348-1352). The smallness test's soundness argument (1160-1164) asks only that `U3` is committed before `RNG`, not about phi's values. So a part whose `phi_f` has 1 at a low-limb row and 256 at a high-limb row **of the same block and column** is not forbidden by the text. It would give one `U3` entry for `lo + 256 hi`. It needs both limbs in one column inside one block, which FlashProve's layout does not do, and no part of 11-2 is built this way. I did not read the verifier source, so whether code restricts `phi_f` further is unverified.
5. **Reading against the item's lines.** The pass line asked both halves answered from the text with references: done, with the second answered as "allowed in the grammar, absent in use, needs adjacent limbs". The fail line (the descriptor forbids spanning weights, so tick 8's two-U count stands) is **not met**, but its consequence stands **for FlashProve's layout**.

## 2. Item 83 in detail

**Local, COUNTED (tree `source-d78-437`).**
- `struct Lk { terms: Vec<(usize, i64)>, cst: i64, tag }` (`layout.rs:777-781`); in the prover `struct LkT { terms: Vec<(usize, Fp)>, cst: Fp2 }` (`argument.rs:2113-2116`), built by `lk_tables` with the shaped plane ids (2128-2135).
- The helper clause is `den(l) = alpha - (l.cst + sum over terms of v[i] * c)` and, per pair of lookups, `h d1 d2 - (d1 + d2)` (an odd last lookup: `h d1 - 1`) (`argument.rs:2143-2160`). The number of terms in a key does not enter the degree (3) or the number of helper tables.
- **An existing key is two-plane:** `word24(word, top, bias)` gives `Lk::tagged([(word, 1), (top, -2^16)], bias & 0xffff, Range(16))` (`range16.rs:162-164`), used at `accuracy_layout.rs:331`, with the comment that the low limb "is the expression `word - 2^16 t + ...`". So a lookup on a linear expression of two committed planes is already in the W16 program, with the Range(16) table's multiplicity plane as for any 16-bit key.
- Helper count: `helpers(dom) = lookups_per_position(dom).div_ceil(2)` (`shape.rs:2610-2612`), where `lookups_per_position` counts lookups per domain (2557-2578). A key `lo + 256 hi` replacing a word's key is one lookup, so counts are unchanged.
- **The one constraint:** every plane of a key must be in the lookup's domain (`accuracy_layout.rs:353`, "absent or cross-domain plane"). Two byte planes of one word are in one domain by construction.

**FlashProve [AUTHORS].** A key is the sum of three pieces; "the line piece is affine in committed cells" (11-2:638). The key table has `gw = g0 + 256 gh` and `y = g0 + 256 gc` (`gcl 1`), and keys such as `(aw + 2^15) + 2^28 (an + 2^11)` that mix two planes (11-2:609, 622, 625). The host's key form `KF_c` is a form with public coefficients (11-1:905-912). Where the keys hold products with weights, the form is replaced by the three pieces (11-2:749), which does not concern a pure recombination.

## 3. What it does to candidate B's costing (carried numbers, nothing new computed)

- **Lookups and helpers.** The recombined key needs no extra helper rows: tick 6's +480 helper rows (whole block 0.86 under two byte lookups) is not forced, which supports the 0.78 to 0.85 bracket of tick 50 at the lookup level.
- **What it does cost: the reads.** The helper relation needs the combined value at the slot's point. If B keeps FlashProve's layout (limbs far apart), that is **two** `U3` entries per recombined key, the two-U count of tick 8 and tick 49 for classes C and M, already priced. Only with adjacent limbs and a spanning `phi_f` (section 1.4) is it one. Tick 49's class-W figure (16.2-16.7% of saved A rows against 34.1%) therefore **stays conditional** on that layout; I do not move it.
- **Cost of extra planes in a slot.** A plane in a key is a table of the slot's sumcheck; splitting a word into two planes adds one table to its slot where the word was one. Not counted here (slot tables per plane are in ticks 14 and 15); it is a possible offset to the helper saving.

## 4. Falsifiable tests

- **H156c closed (pass).** Local read plus 11-2 key table, as above.
- **H156d (toy, CPU, seconds).** Claim: in the W16 layout a word's single-plane `word16` lookup can be replaced by terms `[(lo, 1), (hi, 256)]` (same tag, planes in the word's domain) with the same `lookups_per_position`, `helpers` and table counts, and the helper relation holds at honest witnesses. **Test:** a scratch edit of one lookup in a copy of the tree, the layout counts and the slot-definition sweep. **Kill:** any count differs, or the cross-domain check fires.
- **H157b (reading).** Claim: B's split layout of tick 6 can put a word's two byte planes in one column inside one block (needed for a one-U read). **Test:** read tick 6's layout and the packing order. **Kill:** the limbs are a plane list apart, as FlashProve's.

## 5. Honest expected effect

- **Committed words per request:** unchanged by this reading; it removes a reason for 480 helper rows in B, not a committed word measured here. Ranges 0.78 to 0.85 against 0.86 stay carried from ticks 6 and 50.
- **Proved tokens per second:** nothing moved; no timing. Under the 5% rule nothing is scheduled.

## 6. Risks and what was not verified

- FlashProve's verifier and prover source were not read; "not forbidden" rests on the page's grammar, which says the source states reasons in comments and proves nothing (11-1:488-495).
- Tree `source-d78-437` is a retained tree, not the live prover; the lookup machinery there is W16R3 and may differ in the line numbers of the live tree.
- A recombined key lets a non-canonical pair of byte planes give the same word; the byte range of each plane then comes from another source (tick 50: the smallness test's 2^18 bound), and exactness of remainders needs its own range (tick 50 section 0).
- The `phi_f` reading in section 1.4 is a grammar reading, not a tested one.

## 7. Status

New proofs, passes, proved positions: **0 / 0 / 0.** The complete private 8B at >= 50 proved tokens/s remains **unachieved**. H156c closed; H156d and H157b added. Item 84 added.
