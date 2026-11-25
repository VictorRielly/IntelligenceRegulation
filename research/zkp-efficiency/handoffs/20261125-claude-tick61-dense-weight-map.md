# Research handoff: can a dense (true-words) weight commitment answer claims at padded-domain points (2026-11-25, claude tick 61)

From Claude, the background researcher (D50). Queue item 102 (added by tick 59; test T-C2). Clock at writing 2026-11-25T20:34Z.

**Scope.** Local reading and a toy computation only: 0 searches, 0 fetches. No build, run or Git. Written: this file and `20261125-claude-tick61-dense-weight-map.py` / `.out.txt`. Read (tree that runs): `ops/zkp-mvp/gpu-metal/zkp-core/src/pcs.rs:832-973` (ZPart, ZClaim, `zpart_weights`, `group_zclaims`, `zk_rhos`) and `:233, :718-806` (commit shape rules); `ops/zkp-mvp/gpu-metal/zkp-core/src/mle.rs:120-180`; `hashline/src/private_block/argument.rs:3181-3222, 3330-3363` (the weight sites); `slot_ir.rs:95-111, 1085-1157`; `shape.rs:1036-1050, 2294-2330, 258-262, 297-302`; `grow_tests.rs:766-812` and `trained_block.rs:1507-1533` (`q_axis_index`, `pad_matrix`); `trained_statement.rs:580-616`; tick 59's handoff and script. **Triage material, not a work order:** committing weights changes what the proof commits, so it needs the owner's ruling, a new profile and Lean re-proving (D63); P3 stays at study level (D82). Labels: COUNTED (file:line), DERIVED (script), ASSUMED.

## 0. Headline

- **Pass: a map exists, inside the grammar that exists.** Pad columns inside a row cannot be skipped by a flat row-major dense layout, but they can by a layout that puts each axis's odd factor (3, 9 or 7) on the commitment's ROW axis. Then the weight claim is a sum of claim parts, one per odd-factor combination; every part is an ordinary power-of-two slice and all parts share one column key. Nothing new is needed in `ZPart`/`ZClaim` or in the opening.
- **Rows left at n = 2^16 (COUNTED/DERIVED, script section B):** 8B **3,328 a block** (padded 3,712, x1.115); Shieldstral (installed W16R2) **1,776 a block** (padded 3,712, x2.090). Receipt bytes at tick 54's best row (n = 2^16, rate 1/4, k = 16, Q' = 172, one group a block, wire formula `wire.rs:106-108` as in tick 59): 8B **219.9 MB** dense against **236.8 MB** padded (x0.929); Shieldstral **123.1 MB** against **192.4 MB** (x0.640); the latter is 18.4% and 28.7% of today's 669.6 MB.
- **Correction to tick 59's test line:** it wrote "the 8B blocks 245 MB, not 220 MB" for the padded case. The script gives 236.8 MB (3,712 rows x 32 blocks); 245.3 MB is not a figure of that formula.

## 1. Why a flat dense layout fails

The weight claim has the form W~_pad(r_j, rho) on the PADDED matrix: the verifier folds the public padded matrix against `eq(r_j)` (`argument.rs:3205-3213, 3346-3354`; `fold_rows_i8`/`fold_cols_i8`) and the sumcheck then ends on a point rho over the padded inner axis (the table is `public_chal`, `slot_ir.rs:1097, 1149`). The padded entries are zero (`pad_matrix` fills `vec![0i8; po*pi]`, `trained_block.rs:1514`, and the statement refuses a nonzero entry off the support), so W~_pad(r_j, rho) = sum over TRUE (o, i) of eq(o; r_j) eq(i; rho) W[o][i]. A dense commitment holding only the true words can hold that sum; the question is only whether the opening can express its weights.

An opening weights a claim by (row weights) x (column weights) (`zpart_weights`, `pcs.rs:869-909`): for a slice of at least one row the row weights are `coef * eq(point[..lr])` over the slice's rows and the column weights `eq(point[lr..])` over the n columns. A flat row-major dense matrix (true rows of 14,336 or 9,216 words laid end to end, cut into rows of 65,536) gives the weight of flat word f = o*ti + i as eq(o) eq(i), which does not factor as (function of f / 65,536) x (function of f mod 65,536): each commitment row would need its own column weights, and the opened row combination `rho^T M` tests only one. So a flat layout fails; keeping all columns inside a row with a power-of-two stride is the padded layout.

## 2. The map that works (COUNTED grammar, DERIVED check)

- Write each true axis as odd x power of two: 8B hidden 14,336 = 7 x 2^11; Shieldstral width 3,072 = 3 x 2^10 and hidden 9,216 = 9 x 2^10; the other axes (4,096 width at 8B; the 4,096 query and 1,024 key-value axes at both) are powers of two (`shape.rs:1036-1037`; profile lines `:301-302`). In the padded bit space an axis of size odd x 2^b is a prefix box: its top bits take only the values 0..odd-1, its low b bits are free. So eq of a true index factors exactly: eq(i; r) = eq_hi(i_hi; r[..h]) x eq_lo(i_lo; r[h..]).
- Lay the commitment out in blocks, one per combination (i_hi, j_hi), each block holding the 2^(b_i + b_j) words of the low coordinates, row-major, blocks consecutive and row-aligned. Claim: one `ZClaim` with one part per block, `coef = eq_hi(i_hi) eq_hi(j_hi)`, slice = the block, point = the claim point's low bits (the same bits for every part). All parts then have the same tail (the last 16 coordinates), so `group_zclaims` keeps the claim in one group (its assertion `key2 == key`, `pcs.rs:934`) and tick 54's seven groups per block stay seven. The row-axis weights are general vectors anyway (`zk_rhos`, `pcs.rs:957-964`), so a non-power-of-two number of rows is allowed (commit asserts only `data.len() % n == 0`, `pcs.rs:233`).
- **Check (script A):** a Goldilocks-prime toy at n = 2^3 with four odd-factor shapes (12 x 36, 6 x 28, 4 x 20, 24 x 18) computes the padded multilinear value directly and through the `zpart_weights` rule on the dense layout: equal in all four (27, 21, 5 and 27 parts). The toy uses the base field; the real points are in the extension, where the same factorisation holds coordinate-wise. I did not run the Rust.
- **Parts a block (COUNTED shapes):** 8B 25 (FFN matrices 7 each, attention 1 each); Shieldstral 93 (attention matrices 3 each, FFN 27 each). The smallest part is 64 rows (8B) and 16 rows (Shieldstral), so every part is a whole number of rows and the slice offsets are multiples of n (`pcs.rs:892`). The extra host work is building about 93 small eq tables of at most 2^7 rows per block: negligible beside the 2^16-column weights.
- **Other side effects.** The pad columns are not committed, so there is no pad to keep zero: the "weights vanish off support" check (`weights_vanish_off_support` as named in the queue) has nothing to check for these matrices. Wq and Wo have a head permutation (`q_axis_index`, `grow_tests.rs:767`); at both installed profiles `q_heads` = 32 is a power of two, so it is the identity (`shape.rs:2322-2325`); a profile with 12 heads over 4 groups would have an odd factor 3 inside the head-slot bits, still a box in the bits and still separable, but I did not test that.

## 3. Effect

Committed words per request: dense 6.979 G (8B) and 3.026 G (Shieldstral) against padded 7.784 G and 6.325 G (DERIVED: words a block x blocks), i.e. -10.3% and -52.2% of the padded count. Proved tokens per second: nothing (P3 receipt bytes and the commitment's size only; the commitment is made once per model, not per request, under a stable commitment). The decision that matters is for Shieldstral: P3 blocks 123.1 MB or 192.4 MB.

## 4. Falsifiable tests (not run)

- **T-D1 (Rust).** Build a small `Shape` with an odd width (the 125M-style 12 x 4 case also covers the head permutation), commit the dense layout with `commit_zk`, open one multi-part `ZClaim` for each matrix at a random point, and compare the claimed value with `eval_mle` of the padded matrix. Pass: equal for all seven matrices; fail: any mismatch, then the point permutation is wrong.
- **T-D2 (bytes).** `open_zk` wire length at 1/64 scale with the dense row counts (tick 59's T-C1 test, same harness). Pass: within 1% of the table of section 0.

## 5. Risks and what was not verified

- The toy proves the algebra; it does not test the Rust opening. `zpart_weights` was read, not run.
- The claim point's bit order (which low bits go to the part's point, which to the high weights) must match the sumcheck's variable order: `slot_ir.rs` and `argument.rs` give `r_j` first and `rho` over the inner axis, but where a P3 prover would take the point is not designed anywhere (D82 sizes the receipt only).
- The embedding, head, gains and multipliers (tick 59) were not reread; only block matrices. The embedding at Shieldstral is 131,072 x 3,072 (odd factor 3) and the 8B tables have V = 128,256 = 501 x 2^8, an odd factor 501 (rows allowed, parts 501 per claim): not computed.
- Pad columns are zero for the statement hashes today; under P3 a commitment to true words in a new layout is a different object from the nine padded SHA-256s. A new statement, profile and Lean model are needed (D63).

## 6. Status

Proofs / passes / positions: 0 / 0 / 0. Complete private 8B at the target: unachieved. Hypotheses: H169 (a dense, odd-factor-on-rows layout answers padded-domain weight claims inside today's opening grammar; P3 blocks are 219.9 MB at 8B and 123.1 MB at Shieldstral, not 236.8 and 192.4; T-D1, T-D2).
