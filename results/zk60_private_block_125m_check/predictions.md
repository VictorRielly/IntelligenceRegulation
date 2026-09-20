# Predictions recorded BEFORE running any arithmetic

Independent adversarial check of `ZK60_PRIVATE_BLOCK_125M_LAYOUT.md`.
Written before `recompute.py` was run. Kept verbatim; the outcomes are in
`recompute.out` and in the check document.

| # | claim under test | my prediction |
|---|---|---|
| P1 | A data rows 5,435 at 125M | will reproduce (35 D planes x 32 + 13 S x 256 + ...) |
| P2 | A rows 5,681 | will reproduce (5,435 + 2*122 + 2) |
| P3 | H data rows 7,082 / H rows 7,186 | will NOT reproduce: the draft drops only 2 of the 4 `scaled(rho_top, 1<<(32-WRHO))` lookups, so its Dom::D helper count is one too high; expect 7,018 / 7,120 |
| P4 | A_GROUPS stays 35 | will NOT: the nine limb sub-slices no longer collide at c0 (32*8 = 256 = N at the toy, 512*8 = 4096 != 16384 at 125M), so expect 36 |
| P5 | H_GROUPS stays 9 | structurally blocked: the LogUp sum claim's parts straddle LOG_N = 14, so `check_opening` refuses before any count matters |
| P6 | per-opening soundness 2^-106.25 -> 2^-105.61 | expected this to be WRONG by ~21 bits (inv_rate 8 -> 4); must check whether the hiding pad already sets the rate |
| P7 | norm window: Dmax 908,065, den 2^31.79, margin 0.208 bits | expect to reproduce |
| P8 | decision 2: class 2^12 -> wrho 27, 5 bits margin, D two limbs | expect WRONG; my back-of-envelope says wrho 29, ~3 bits, D three limbs |
| P9 | 8B "unreachable" | expect the ceiling to be the 4-limb + `1<<(32-wrho)` idiom, not the arithmetic; a 5th limb on rho/sigma reaches |
| P10 | lookups 99,631,104 | expect lower: 4 dropped D lookups, not 2 |
| P11 | receipt 40.6 MB | expect ~40.6 MB +- 0.3 MB per group correction |
| P12 | peak 12.0 GB | expect 11.7-12.0 GB; expect NO hidden transpose copy in the commit path |
| P13 | form E ceiling 17.8% | expect the row-share model to be optimistic for form E: sumcheck table-points put attention higher still |
| P14 | `argument.rs:626` is a soundness hole | expect PANIC instead: `fold_rows_i8` asserts `w.len() == rows` |
| P15 | support indicator is a sound pad fix | expect NOT sufficient: SC_SS / SC_SSM sum x^2 over the padded Dom::D with no indicator |
| P16 | `priv_table` broadcast is suspect at pads | expect it is FINE (p.log is the padded log; the witness is required to be the padded length) |
