# Fused grouped-equality rounds, isolated native candidate (2026-09-27)

**Disposition: demote; leave the production grouped evaluator unchanged.** The
candidate is algebraically and byte equivalent on the retained differential and
native gates, but its whole dense 125M diagnostic is slower on this shared
two-thread CPU. It is not a complete private 8B proof or a GPU result.

The source copy is `/tmp/zk60-sol-fusion-20260927`, copied from the validated
`/tmp/zk60-groups-20260926` without Git metadata or build artifacts. The
retained [patch](fusion.patch) changes only `grouped.rs`, its tests, and the
private-block call site. [Source hashes](source-pins.json) identify both sides.
`GroupedEqRounds::with_fusion(true)` selects the new path; the native copy
selects it only with `ZK60_FUSED_ROUNDS=1`. The default remains the grouped
baseline. The first round uses the old evaluator. Each fold uses the actual
prior *unmasked* group polynomial at the unchanged driver challenge, updates
equality prefixes, folds four disjoint quarters per table, and prepares the
next round. Rayon recursively splits disjoint mutable quarter slices. It
retains zero-factor explicit evaluation and the terminal two-row fold.

## Validation

The final [validation record](validation-final/validation.json) and its
`run.done=0` cover 74 core unit tests plus two integration tests in both debug
and release, a release native test build, **512 native library tests passed,
17 ignored**, a fresh-process proof and verification, old-verifier/new-receipt
and new-verifier/old-receipt checks, and nine corruption refusals. All source,
binary and log hashes are retained in the record. The final source did not
change during validation. An independent [hash audit](validation-final/hash-audit.json)
rechecked 197 source, binary, log, runner and marker values with no mismatch.
The earlier [validation run](validation-1/validation.json)
also passed before the extra middle-offset support test was added.

The core differential tests compare the original scalar closure, grouped
baseline and fused mode on masked proof bytes, challenges, transcript state,
folded tables, finals and extension rounds. They cover zero factors, empty and
short equality support, starts beyond one, support ending before the terminal
variable, `n=0/1/2`, a nontrivial `n=2` challenge, and the one-/two-thread
parallel path above the old cutoff. Release tests cover recovery when the
explicit sample at one is skipped. The native test build compares bounded
actual slots to the original scalar oracle. The large 125M test independently
verifies receipts from bytes but does not pin their exact bytes across runs;
fresh privacy randomness prevents treating receipt length as byte identity.

## Complete dense-block A/B

The [audited six-run record](dense-ab-1/measured-summary.json) uses one pinned
release test binary in separate processes with fusion off/on. Each run builds
the witness, proves a dense synthetic-public-weight 125M-geometry private
block, serializes its 40,783,352-byte receipt and verifies it. Two warmups
precede two non-warm samples per arm, order reversed in the last pair. All
six passed. The [benchmark runner](benchmark.py) requires final validation,
checks source and binary hashes, and holds `/tmp/zk-heavy.lock`.

| Non-warm mean, two samples/arm | Baseline | Fused | Fused time change |
|---|---:|---:|---:|
| Prover phase | 35.0665 s | 35.6490 s | +1.66% |
| Complete softmax slot | 8.332 s | 9.197 s | +10.38% |
| Enclosing test process | 42.297 s | 43.350 s | +2.49% |
| Witness + prove + serialization | 41.276 s | 42.311 s | +2.51% |

The fusion reduced logical synthetic table traffic in the research sketch,
but this native parallel implementation adds tile setup and reductions and
does not win at the measured whole slot. The test binary includes bounded
small-slot oracles in both modes. The machine was shared, so two non-warm
samples per arm do not establish a stable performance regression or p95.
There is no trained checkpoint, full transformer stack, 8B workload, RTX 5090
measurement, or new D19b/D22 privacy acceptance in this result.
