# Gate round 26: block-level pin readings (frozen-r19b → HEAD 8b78aabd)

Block-level reader, 2026-11-02. **Not a privacy acceptance.** P1 is not reopened. The run-level, wire, capture
and I/O pins belong to the other reader (`READINGS_R26_RUN.json`, commit 49c2914c). This file covers the block
prover and verifier files and the moved zkp-core and gpu pins. The record is `READINGS_R26_BLOCK.json`, laid out
like the run-level one: `readings`, `wiring_w16_readings_style`, `trees`, `capture_pins`, `diffs` and `summary`.

## In plain words

* **21 moved capture pins were read, and all 21 are safe. No leak was found.** Each one was compared hunk by hunk
  against the frozen r19b tree, and each new file was read in full. Of the 122 hunks and sections, 12 are
  test-only, 69 are production code that cannot change what is revealed, and 41 are privacy-relevant. Each of the
  41 is argued safe with HEAD line numbers.
* **One Low finding (F-B1): the Metal GPU backend is not pinned.** The files are `src/gpu/metal.rs` and
  `src/gpu/metal_kernels.metal`. When a run uses the GPU (`HL_GPU=1`), these two files compute receipt bytes, and
  no capture pins them. I read their privacy-relevant paths and found no leak. Also, a receipt that verifies
  cannot depend on them for hiding, because the host draws the pads and salts, computes the pad half of every
  clear vector, salts the leaves and masks every round message. The D60 bundles were made without the GPU
  (`HL_GPU` unset), so this finding does not affect them. It does matter for any future GPU-made bundle.
* **Three Info notes, all text only:** a stale module doc in `slot_ir.rs` (F-B2); the refusal message names "the
  byte table" when a range-family lookup misses (F-B3); and the existing W16 reading's diff stat for
  `gpu/mod.rs` is wrong (F-B4).

## The files, and the HEAD digests read against

The working tree equals 8b78aabd for every file. The branch tip later moved to 49c2914c, but that commit only
adds records and changes no source file. All four D60 bundles pin these files at the digests below. The W16R2
re-check bundles also pin them at these digests, except `shape.rs`, which they pin at `3b78b725`. That version
was also read; it differs from HEAD only in one comment block.

| pin | r19b | HEAD | hunks / sections: test / neutral / relevant-safe | result |
|---|---|---|---|---|
| `protocol.rs` | `10114414` | `6f4d60f5` | 21: 3 / 11 / 7 | safe; F-B3 (Info) |
| `argument.rs` (outside `define`) | `bc0332e3` | `86c9941d` | 18: 1 / 12 / 5 | safe |
| `layout.rs` | `8519a514` | `171656f8` | 8: 0 / 5 / 3 | safe |
| `shape.rs` | `8e00a144` | `dce667f9` | 15: 1 / 5 / 9 | safe (`3b78b725` too) |
| `pad.rs` | `91141ea0` | `9a28b306` | 2: 0 / 2 / 0 | safe |
| `argument_accuracy.rs` | `a5e02391` | `29a501d0` | 2: 0 / 0 / 2 | safe |
| `accuracy_act.rs` | `7ef5fe26` | `08b88855` | 2: 1 / 1 / 0 | safe |
| `accuracy_fold.rs` | `53e2b572` | `d260dd26` | 1: 0 / 1 / 0 | safe |
| `accuracy_layout.rs` | `37a3e345` | `ad5214de` | 8: 0 / 6 / 2 | safe |
| `witness_accuracy.rs` | `8b03abad` | `9c66f762` | 1: 0 / 1 / 0 | safe |
| `range16.rs` (new) | — | `62061f62` | 8: 2 / 3 / 3 | safe |
| `slot_ir.rs` (test-only at r19b; production in GPU builds now) | `e0746ff1` | `8f9e2831` | 6: 0 / 5 / 1 | safe; F-B2 (Info) |
| `slot_ir_accuracy.rs` (new) | — | `25c08bb4` | 5: 1 / 3 / 1 | safe |
| `metal_slot.rs` (new) | — | `5ced3891` | 4: 0 / 2 / 2 | safe |
| zkp-core `merkle.rs` | `6e7817bd` | `6b66c0bc` | 4: 1 / 3 / 0 | safe |
| zkp-core `mle.rs` | `b20c8b75` | `ed7f8849` | 5: 1 / 4 / 0 | safe |
| zkp-core `pcs.rs` | `5c9cfc4e` | `856929b3` | 1: 0 / 0 / 1 | safe |
| zkp-core `pcs/backend.rs` | `ff2cb5c1` | `4f03047a` | 1: 0 / 1 / 0 | safe |
| zkp-core `rng.rs` | `0d4a99ab` | `f6728bd2` | 4: 1 / 0 / 3 | safe |
| zkp-core `transcript.rs` | `cc9752d0` | `e766e9e1` | 1: 0 / 1 / 0 | safe |
| `gpu/mod.rs` | `d651be2c` | `d7812f7d` | 5: 0 / 3 / 2 | safe; F-B1 (Low), F-B4 (Info) |

The full 64-hex digests are in the JSON. The zkp-core and `gpu/mod.rs` digests are the ones that
`W16_READINGS` already holds. They were re-read here independently and agree, apart from F-B4.

## The points the task asked about

* **W16 tagged range lookups.**
  * The only new public tables are `range16::table_column` (value + γ·tag(w)) and `support_column` (a function
    of the shape only). They are pushed in SC_TAB (`argument_accuracy.rs:752, :767`).
  * The new 16-bit histograms are private planes of A. They are written only at `protocol.rs:1642-1652`, and
    each is claimed once in SC_TAB with its own reserved mask pair.
  * Their table helpers are private planes of H, included in the single LogUp sum claim, whose value is 0.
  * No multiplicity is exported.
  * Folding a range tag needs no new transcript draw.
* **W16R2 at rate 1/2.**
  * The profile fixes Q = pads = 260 at a row width of 2^14 for A, H, every boundary B_k and both endpoints. Any
    other geometry is refused (`shape.rs:1023-1033`).
  * Q reaches the pad count through `pcs_params_at` and then `ZkOpts::standard`. Both functions are
    byte-identical to r19b's.
  * The hiding coset encoder is unchanged, n + Q ≤ N, and M is untouched.
* **The Metal seam.**
  * The slot IR is built on a copy of the transcript, so the real transcript is untouched.
  * The runtime guard draws its test points from a local random stream, never from the proof's randomness.
  * The GPU returns unmasked round sums. The host masks them with zkp-core's `CfsMasker` on the real transcript
    and checks every challenge the GPU computed against its own.
  * Witness tables stay in the prover's own memory.
  * The generated kernel source contains no table or coefficient value; the values travel in a separate buffer.
    So `HL_METAL_DUMP`, which writes that source to disk, writes no data.
* **The masking in the masked sumcheck is unchanged.**
  * The value that masks each terminal (`mask_eval_eq`) is computed exactly as r19b's `mask_eval` was.
  * `masked_terminal`, `audit_claims` and `check_opening_challenges` are unchanged.
  * The mask rows of A and H and the zero-sum rows of H come from the same random stream in the same order. The
    new `fill_fp` routine was checked against the old one-at-a-time draw loop.

## Findings

| id | severity | what | fix |
|---|---|---|---|
| F-B1 | Low | `gpu/metal.rs` and `gpu/metal_kernels.metal` compute receipt bytes when `HL_GPU=1` and are not source pins; the M26 comment (`run_capture.rs:306-315`) says a Metal-built bundle is tied to its Metal sources only through `slot_ir*.rs` and `metal_slot.rs`. No leak found on reading. | Pin both files. Alternatively, record `HL_GPU` / `gpu::label()` in the manifest and refuse GPU-made bundles until both are pinned. |
| F-B2 | Info | The module doc at `slot_ir.rs:16-22` still says the module is test-only. | Correct the doc. |
| F-B3 | Info | At W16, a range-family miss is reported as "the byte table", and `ProveStats.u8_lookups` counts range lookups too. Only the class is reported, never a count. | Optional wording change. |
| F-B4 | Info | `W16_READINGS['src/gpu/mod.rs']` gives "+111 / -?"; the actual stat is +106 / -5 in 5 hunks. | Correct it when the readings are wired in. |

## Evidence

* `round26/READINGS_R26_BLOCK.json`: every hunk, with its class, its argument and HEAD line numbers.
* `round26/readings_block/blk-r19b-head-*.diff`: one diff per modified file, plus
  `blk-2196592d-head-shape.rs.diff`. The JSON records the SHA-256 of each diff. The three new files are their own
  evidence, as git blobs at 8b78aabd.
* Also checked:
  * The r19b files read re-hash to `manifest_final_r19b` (list `cfae2d1e…`).
  * `define` is byte-identical: its function text has SHA-256 `8164dd26…` at both r19b and HEAD.
  * The D60 bundle writer ran without `HL_GPU` (`privacy_gate/logs/write.cmd`).
  * No cargo run was needed. Nothing was committed, and no source or gate script was edited.
