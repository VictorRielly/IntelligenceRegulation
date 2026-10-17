# Review handoff: guarded direct H helper writer

Research cycle 0011, `20260927T025233Z-f22c1025`. This is a **synthetic
exactness and payload** candidate, not a native patch or measured proof speed.
No production file was edited or merged. The prototype and source pins live
under `experiments/direct-helper-planes-20260927/`.

## Interface and patch location

Target only the six U8 lookup domains at
`/tmp/zk60-groups-20260926/hashline/src/private_block/protocol.rs:884-907`.
The current call returns `Result<Vec<Fp2>, String>` through
`helper_inverses_u8_at` / `helper_pair_inverses_u8_at` at lines 565/588,
then `write_h` at 633 splits it into `(c0,c1)` planes. A new internal
`write_u8_helper_into_h(h: &mut [Fp], off: (usize,usize), a: &[i64],
b: Option<&[i64]>, alpha: Fp2, g_u8: Fp2, tbl: &[Option<Fp2>],
par_min: usize) -> Result<(),String>` can replace **only** the call site;
keep old functions for tests/other callers. Check paired lengths before
writing. `off.0..off.0+len` and `off.1..off.1+len` must be disjoint,
in-bounds, and refer to the exact layout H plane. Split the mutable H slice
at `off.1` before constructing disjoint limb slices; preserve the indexed
Rayon threshold and deterministic output placement.

The writer may skip refusal preflight only if `alpha.c1 != g_u8.c1` **and**
`tbl` was built internally by `u8_denominator_inverses(alpha,g_u8)`. Every
signed looked value embeds into the base field, so its denominator then has
nonzero extension coefficient; `helper_one` cannot refuse. On equality,
evaluate both columns in source order in a read-only pass, returning the
current refusal string before modifying H. Then write directly, evaluating
the same helper values again. This preserves the old atomic helper write
behavior even for invalid signed witnesses. Do not relax any later whole-
table inverse/refusal path. Do not move the H root absorb, RNG calls, mask
rows or `drop(looked)`; no rejected H buffer or refusal detail is publishable.

## Validation and expected impact

The standard-library Python oracle passes 63 cases, 7,932 output words and
eight controls. It explicitly catches a plain direct writer's partial H on
late zero refusal, and shows the guarded variant has no such partial write.
Run the script and `validate.py` per README. Native review must then test
serial and Rayon branches at empty/single/paired/ragged lengths, duplicate
values, all signed bounds, used/unused zero denominators, invalid values,
disjoint planes, full-table refusal order, and the existing masked receipt/
randomness/extension and cross-version verification gates. Build and large
benchmarks belong to main under shared locks; none were run here.

At the 125M development shape this removes 1.555 GiB of counted temporary
write/read traffic and a 64-MiB largest modeled temporary payload. Successful rare
equality-branch proofs add 752.25 MiB of logical input reads; normal branch
adds no payload scan. The most optimistic CPU known-readiness ceiling from
the latest owner old arm is 2.87–3.04%, and actual savings are likely much
smaller. Main should stop this lead if native A/B shows no improvement in
the helper phase **and** witness+prove+serialization, or if peak RSS/VRAM
does not improve where it matters. No 8B, GPU, privacy or soundness extension
is implied by the synthetic oracle.

Unresolved: exact Rust borrow/Rayon implementation, table-construction
invariant at the new interface, byte-identical receipts and refusal order,
all mask/transcript draws, memory allocator reuse, CPU/GPU traffic and
enclosing readiness. Preserve D22's toy-only CPU privacy boundary and the
pending larger-profile rulings.
