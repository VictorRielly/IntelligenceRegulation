# Gate round 26: the wiring's own reading (SELF-READ)

The round-26 wiring agent, 2026-11-02. **Not a privacy acceptance.** P1 is not reopened. **This reading is
self-read**: the agent that wrote the `run_capture.rs` change read it. It is owed an independent check at the v25
freeze review, and every gate record that relies on it names it (`PINS.self_read_pending_independent_check`).

## In plain words

* **Why this file exists.** Closing finding F-B1 changes `run_capture.rs`, so its digest moves from `cbb78dc0`
  (the run-level reader's HEAD) to `10b6d3be`. A fresh bundle also pins two new files, `src/gpu/metal.rs` and
  `src/gpu/metal_kernels.metal`. Without a reading of those three digests, every fresh bundle would stay
  DEV-PASS.
* **The `run_capture.rs` diff is small and safe.** It has 6 hunks (+20 / -5); 4 of them are privacy-relevant, and
  all 4 are argued in the JSON:
  * two pins are appended to `SHARED_SOURCE_FILES`;
  * both manifest writers record `"proved_on_gpu"`, whose value is `gpu::enabled()`;
  * that key is added to `ALLOWED_KEYS`.
  * The other two hunks are an array length and a corrected comment.
  * No transcript, frame, stage file, tail or `run.json` byte moves. Nothing on `not_in_a_capture` is written.
  * The new field says only how the prover ran, which the bundle's README already states.
* **The two Metal files are read for the CPU path only.** When `gpu::enabled()` is false:
  * `metal.rs` is reached only through `enabled()` and `label()`. Both return before touching the device unless
    `HL_GPU=1`.
  * Every device entry is gated by `gpu::enabled()` at its caller.
  * The kernel source is only compiled inside the device context, so on the CPU it is never compiled or run.
* **This is not a full reading.** The device paths are F-B1's: the block reader read only their privacy-relevant
  code. So the gate refuses any bundle that proved on the GPU.

## The digests

| file | from | to | scope | basis |
|---|---|---|---|---|
| `run_capture.rs` (test-only module) | `cbb78dc0` (run-level reader, r19b → HEAD) | `10b6d3be` | full | this diff, 6 hunks |
| `gpu/metal.rs` (new pin) | — | `a96882bc` (92,982 B) | CPU path | F-B1 (block reader), re-checked |
| `gpu/metal_kernels.metal` (new pin) | — | `be968236` (39,117 B) | CPU path | F-B1, re-checked |

The Metal blobs are equal at 8b78aabd (the block reader's tree), at 6d06b8b0 and at 23199feb.

## Records

* `READINGS_R26_WIRING.json`: per hunk, its class and its argument with line numbers; the CPU-path readings; the
  wiring table.
* The diff: `readings_wiring/wiring-head-r26w-run_capture.rs.diff`.
* The generator: `readings_wiring.py`, which checks the base digest, the hunk count and the Metal sizes.
* Wired in `ops/zkp-mvp/gate-tinyllama/staging_v25/scripts/zk60_native_rg_r26readings.py` (`R26_READINGS`, the
  three `SELF_READ` entries).
