# The eq table's order, and how a public table is evaluated: Lean model against the Rust verifier

2026-11-27, by Claude (co-coordinator). A reading, with a script that asserts every cited line and re-computes the
loops in plain integers. Nothing was proved and nothing of the prover was run.

## What was asked

Two comparisons left open after the five readings of 27 November:

- does Lean's `eqTableMsb` list its entries in the same order as Rust's `eq_table_msb`?
- row B21 of the fourth reading (`results/zk60_claude_review_20261116/W16R2_LAYOUT_CONSUME_READ_20261127.md`, line
  188), the value of a public table, which that reading left NOT DETERMINED with the note "A26 path not read".

## What was found

1. **The order is the same.** The Lean definition follows the Rust loop line for line (`ExecMle.lean:399-412`,
   `zkp-core/src/mle.rs:17-58`), and Lean proves the order: entry `idx` is the eq polynomial with variable `j` at bit
   `n - 1 - j` of `idx` (`toK_eqTableMsb`, `ExecMle.lean:563`).
2. **Row B21: the model follows the branch the code takes only with a switch off.** For a public table of a block's
   slot, the Lean model of the verifier arm takes the sum against the full eq table (`evalMleExt`,
   `ExecBlockVerify.lean:251`). The Rust verifier arm takes that form only when the switch `HL_A26_MLE` is set to
   `0`. By default (since a commit of 2026-11-07; the Lean file is of 2026-11-06) it takes a split form: two half eq
   tables, one product an entry (`argument.rs:2262-2268`, `mle.rs:99-116`). The fourth reading named the split path
   as taken "when A26 is on"; it is the default. The switch is named nowhere else in the app, the prover source in
   use or the scripts, so a verifier started by them takes the default.
3. **The two forms give the same value.** The eq weight of an index is the product of the weights of its two halves,
   so the split sum is the full sum; Rust field words are reduced, so equal field elements are equal words. A Rust
   test compares the two at nine sizes and three kinds of table (`mle.rs:440-449`). The script here compares a
   transliteration at thirteen sizes. Neither is a proof, and no Lean file names the split form.
4. **Not affected:** the stage slots outside the blocks use the full form in the code (`token_io.rs:1106`) and in
   Lean (`StageCheckDefs.lean:156`).

## What it means

The Lean statements about a block's verifier describe the verifier with the switch off. For the default path one link
(split sum = full sum) rests on a test and a short argument instead of Lean. It is a gap in the correspondence between
the model and the code, of the same kind as the items the status page lists under "Limits"; it is not a known weakness
of the system. Closing it takes one Lean lemma and a verifier model that follows the default branch.

## Not read

- The second switch of the same change, `HL_A26_PCS_SPARSE` in the opening check (`zkp-core/src/pcs.rs:1175`), against
  Lean's opening model.
- The other environment switches read in `argument.rs`, one by one, against the model.
- What environment a verifier process inherits on a given machine.

## Files

- `check_split_eval.py`: 25 checks. Run from anywhere: `python3 -I check_split_eval.py`.
- `check_split_eval.out.txt`: its output on 2026-11-27.
