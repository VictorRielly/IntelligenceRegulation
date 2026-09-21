# Combined host/private integration — 2026-09-20

The validated candidate `3d5c60c`, based on accepted row-fold `4bf1fa0`,
combines corrected host delivery `04894c7`, private host/probe `a328dea`,
and native norm-alias controls `ad0b55c`. Its exact ten-file source delta
is applied to main. Main's separate rebuild and receipt checks also pass
under `results/zk60_host_private_20260920/main-gate/`: 23 steps, two fresh
receipts, fourteen old/new CPU/GPU-feature verifications with 42 corruption
refusals, and 24 GPU-feature private-IO tests over all pool/fold settings.
Its independent audit matches 132 source hashes, nine binaries and 23 logs.

## Behavior and scope

Public v3 weight commitments can upload the original int8 planes directly,
avoiding the intermediate field-element matrix on supported device paths.
Checked private tiling geometry prevents malformed dimensions/offsets from
reaching the uploader. `HL_GPU_NARROW=0` declines both resident and streamed
plane routes. Cache keys compute their weight digest lazily at most once;
warm fallback keeps the existing cache format and identity.

The separate FFN prover reuses host allocations and folds the int8 source
planes directly. Every non-tiled tail is cleared before partial writes.
The new regression reuses the same dirty allocation through shrinking and
growing geometries, including empty and almost-complete tiled prefixes;
it checks the retained prefix, partial writes and zero tail. `HL_FSP_POOL=0`
and `HL_FSP_I8FOLD=0` retain the rollback paths. Public weight column folds
also defer exact integer reduction, with `HL_FSP4_I128FOLD=0` as rollback.

The repaired-mask cost probe has an explicit separate profile and public
endpoints. Its three arms compare public, legacy-masked and repaired-masked
FFN execution. It is diagnostic infrastructure, not P1 privacy evidence.
The five native norm controls exercise invalid denominators/remainders and
field aliases against actual verification.

## Evidence

The detached candidate run passed all 43 steps. A separate audit rehashed
132 sources, twelve candidate binaries, the runner and all 43 logs; it also
confirmed the four main baseline binaries were unchanged before rebuilding.

| Check | Result |
|---|---|
| Complete storage-feature suite, including doctests | 307 pass, 0 fail; 2 explicit capture writers ignored |
| P1/P3 private-IO and repaired-probe tests | 6 + 6 tests in each of four pool/fold configurations |
| Dirty reuse, geometry, cache, norm controls | 1 + 5 + 3 + 5 pass |
| Device-feature upload host oracles | 3 pass |
| Required-device oracle and commitment suite | 189 actual device cases; 34 tests pass |
| Device cache suite | 12 pass |
| Frozen proof comparisons | All 12 CPU/GPU/forced-chunked gates pass |
| Additional frozen v3 comparisons | Resident/streamed × default/planes rollback/narrow rollback: 6 pass |
| Cold/warm plane-cache proofs | 2 pass; 12 misses cold, 12 hits warm |
| Full diagnostic probe | All three arms accept on CPU and GPU |
| Floors v11 tooling | 89 tests pass; versions 1–10 preserved |
| Main rebuild and receipt integration | 23 steps pass; source/binary/log pins rechecked |

The twenty proof comparisons require ACCEPT, exact byte length and the
frozen SHA-256. Device logs must establish the actual selected routes;
the plane markers disappear when either rollback is selected. The pinned
runner hashes each scratch proof before deleting only that checked file.
The later audit rechecks those recorded expectations and logs, not deleted
proof files. All retained logs and source pins are under
[`results/zk60_host_private_20260920/`](../../results/zk60_host_private_20260920/).

## Privacy and performance boundaries

Removing just the newly added public entry from candidate `pcs.rs` yields
the inherited file byte for byte. The private PCS masks, openings, salt
generation, row checks and transcript are unchanged. Native block production
code is unchanged; its module adds only the norm test registration.
This does not extend D22's toy-only acceptance to the diagnostic FFN probe,
the larger shaped block or a multi-block run. Fable has the source-change
notice and owns the affected privacy statement/gate pins.

The earlier measured host result was a 1.405x weight-commit improvement at
the 125M FFN fixture; the 2.23-second saving at 8B was counted, not measured.
This integration supplies correctness and route evidence, not a new speed
comparison. The private model's measured costs are dominated by its softmax
slot, hiding commitments and lookup helpers; those are the next targets.
The private model, proof-size requirement and five-second proving goal
remain unfinished.
