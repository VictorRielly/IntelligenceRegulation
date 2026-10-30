# Shieldstral storage inventory — 2026-10-30

Read-only inventory for coordinator D46. No files were removed. GiB below are allocated Linux blocks; shared hard links make directory totals overlap. Removing Linux files makes blocks reusable but does not itself shrink the WSL disk on C:.

| Directory | Unique allocated GiB | Current disposition |
|---|---:|---|
| fidelity_full_fix1 | 32.138 | KEEP: live full benchmark; all past residuals required by the current final audit. |
| stats_t256 | 15.246 | PARTIAL PRUNE CANDIDATE: float residual caches only; retain every statistics/manifest file. |
| calibration_full_fix1 | 7.595 | KEEP: accepted numerical calibration evidence; current full audit rereads all residuals. |
| dg_r12b_t256 | 3.961 | KEEP: tied integer embedding/head and final numerical scoring. |
| native_low_h24_t128-verifier | 3.958 | KEEP: independent public verifier and all published receipts rely on this path. |
| native_low_h24_t128 | 3.958 | KEEP: r16b prover profile and arrays; shared links do not imply an expendable path. |
| s2_evaluation_t256 | 2.841 | KEEP: active integer replay loads these layer arrays. |
| dg_base_t256 | 2.834 | KEEP pending dependency review: base-export lineage and numerical rebuild input. |
| fidelity_smoke8_gpu | 0.159 | REGENERABLE but retain until parity/audit owners acknowledge: GPU parity gate. |
| fidelity_smoke8_fix1 | 0.159 | REGENERABLE but retain until parity/audit owners acknowledge: CPU byte-parity baseline. |
| fidelity_smoke8_cached | 0.159 | REGENERABLE but retain until parity/audit owners acknowledge: cached CPU diagnostic. |
| layer25_probe | 0.042 | KEEP small failure/fix diagnosis and its source pins. |
| layer25_fix_candidate | 0.028 | KEEP: active numerical amendment and provenance pins. |
| evaluation_inputs | 0.007 | KEEP: small inputs, provenance, source or diagnostic records. |
| (top-level) | 0.001 | KEEP: small inputs, provenance, source or diagnostic records. |
| calibration_replay_inputs | 0.000 | KEEP: small inputs, provenance, source or diagnostic records. |
| calibration_t256 | 0.000 | KEEP: small inputs, provenance, source or diagnostic records. |
| vendor | 0.000 | KEEP: small inputs, provenance, source or diagnostic records. |
| __pycache__ | 0.000 | KEEP: small inputs, provenance, source or diagnostic records. |
| upstream | 0.000 | KEEP: small inputs, provenance, source or diagnostic records. |
| gpu_probe | 0.000 | KEEP: small inputs, provenance, source or diagnostic records. |
| cache_probe1 | 0.000 | KEEP: small inputs, provenance, source or diagnostic records. |

## Concrete candidate for coordinator scheduling

The 25 float residual caches total **14.063 GiB**: `stats_t256/input_rotated.npy` plus `stats_t256/layer_00..23/residual.npy`. The exact paths and retained expected hashes are in `export_storage_inventory_20261030.json`. They are regenerable with `collect_stats.py` and the pinned checkpoint/calibration inputs. They are not native proof receipts.

Code inspection: `build_export.py` reads `stats.pkl`, `complete.json` and `run.json`; `evaluation_export.py` reads that same aggregate and checks its build pin. Neither reads float residuals. The aggregate and plan hashes were freshly checked. `collect_stats.py` does read every residual when resuming, so after pruning a new float-statistics run needs a new output directory; never silently reuse missing caches. **Keep layer_24/residual.npy** for `probe_layer25.py`, and **keep layer_25/residual.npy** for `build_token_io.py` / `build_token_io_r12b.py` final-norm calibration.

Retain `stats.pkl`, all `statistics.pkl`, `ready.json`, `input.ready.json`, `run.json`, `complete.json`, the calibration inputs and model/source pins. Payload hashes should be checked before deleting the listed caches. Other lanes must first have the opportunity to identify a residual dependency. No deletion authorization is inferred for a native export, accepted receipt or another lane’s artifacts.

## Remaining benchmark growth

Each full residual stage is 4,313,124,864 bytes (4.017 GiB). Input plus 26 layers reaches 108.457 GiB of residuals alone. Each individually guarded layer writes less than 10 GB, but the whole remaining campaign is much larger. The current final audit needs every stage’s bytes, so a rolling deletion scheme must change and validate that audit contract first. No benchmark residual pruning was performed.

Incomplete-name candidates found: 0. These are inventory entries only; live ownership must be checked before cleanup.
