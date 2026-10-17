# Owner handoff — exact typed readers / lazy lookup preparation

Run `20261003T230146Z-65ad9aeb`, 2026-10-03. Research only; main/Claude reviews
and integrates. No production patch applied, native build or GPU run.

The current `Witness::planes: Vec<Vec<i64>>` expands every plane before
`prove_core`, which also materializes looked columns and exp/act index arrays.
Avoiding those arrays could reduce the host payload live during H construction.
The smaller first rung uses the existing i64 witness with lazy indexed Lk
reads; the next rung consumes typed cache entries without expanding them.

The [experiment](../experiments/typed-witness-readers-20261003/README.md) passes
66 vectors, 1,952 field words, 25 preparation cases, 65,816 helper limbs and
20 zero-denominator refusals, with 99 total negative checks. Final 2.432 s,
23,200 KiB RSS, one CPU thread. Source/result pins and initial failure retained.
It validates arithmetic and representative lookup forms, not native Layout,
full witness building, commitments, masks/RNG, receipts or trained privacy.

Interface and patch locations in the inspected **sonnet-hardening** source:

- `hashline/src/private_block/protocol.rs:384` lookup_values_at:
  retain Layout's Lk order/extent, but supply `read_lookup(column,index)`.
  Histogram and H passes independently read these values. Keep the existing
  byte bucket fallback for invalid signed words and wrapping i64 arithmetic.
- Lines454/460 `act_indices`/`exp_deltas`: replace full arrays with indexed
  reads while preserving native add/overflow mode and masked future scores,
  padded head/token stride and all exp/act bucket comparisons.
- Lines798–802 `prove_core` A population: use `Fp::from_i64(reader.read(i))`
  at unchanged offsets. Exclude the same three empty multiplicity planes.
- Lines889–912 helpers: retain pairing, existing helper_one and inversion
  implementation, per-helper Vec + write_h transaction, and full public-table
  denominators. Do not import the separately reviewed direct-H writer here.
- `witness.rs::Witness` / `mvp_driver.rs::StackSource` signatures need an
  owned typed alternative for cached witnesses. Keep output/chain reads exact,
  fallback to i64 for every value that fails narrowing; no new range refusal.

[reader-seam.rs](../experiments/typed-witness-readers-20261003/reader-seam.rs)
is a small uncompiled/unapplied read-interface sketch, not an integration patch.
It can remain CPU indexed reads before any CUDA adapter is designed. Resolve
public variants/terms outside hot loops without leaking private width metadata.

Counted m125 T512 witness+lookup+index payload **1470.641 ->678.391 MiB**
for raw lazy, **->122.363 MiB** for typed lazy. Combined removed1348.277MiB;
raw-only removed792.25MiB. Unregistered8B T512/1024/2048 combined removed
4503.582/12382.695/38269.391MiB; these are not actual peaks or device results.
All common A/H/weights/proof buffers remain. Source-counted U8 source/temporary
traffic32->16B/value raw, or2B/value for admitted byte/int8 typed values; the
second affine evaluation adds98,598,912 term operations per m125 layer.
These byte counts do not establish a timing ratio.

Risks and native acceptance gates:

1. **Refusal/privacy:** retain all used/unused denominator refusals, arbitrary
   invalid witness paths, overflow behavior and same public challenge/draw/
   absorb sequence. Cache/width/digest/hit/occupancy/build metadata stays private.
   No proof state or masks/openings reused. D22 is only the CPU toy; no wider
   privacy/soundness ruling is supplied. The zero-tag case requires table kind
   to be selected by schema, never equality of gamma-derived tags.
2. **Memory/lifetimes:** all required witnesses remain through H denominators
   at S2. Packing from an existing i64 builder overlaps both representations
   (m125800.754MiB; 8B T5122681.699MiB). A smaller later payload can still
   leave/increase the true maximum. Cached other layers, A/H stores, helper
   Vecs, weights, copies and allocation pools need an enclosing live-byte trace.
   Five norm limbs at4096 width remain unsupported by the inspected builder.
3. **Native correctness:** current generic byte/IR/native full receipt and
   fresh-process independent verification gates, mask/RNG observers and bad
   witness/refusal controls. Compare typed only, raw lazy, combined and original
   at toy/padded/m125 before changing defaults; preserve Rayon indexed ordering.
4. **Performance:** owner-run common guarded phase A/B with materialization,
   pack/scan, affine recompute, A/H commitment, transfer, helper and complete
   workload clocks. Smaller peak and improved enclosing readiness are required;
   report verification, startup fraction, drain/lag and exact workload/device.
   Nothing is requested to launch from this research lane.

Ceiling N/(T-M+C), where M is removed measured preparation, C added packing/
recomputation. No trained8B phase attribution; no numerical rate forecast.
This removes neither forward work nor H commitment rows. It cannot establish
>=50 proved tokens/s by memory counts. Large context retains quadratic scores.

Next CPU-light experiment: derive public per-plane last-read sets from actual
Lk/IDs. Drop A-only planes after A; drop lookup-only planes after their helper
domain; retain S8/MX/E and G8/A16 until the final reads. Independent trace must
reject early release, read reordering or skipped denominator checks. Count the
peak over phases including raw-to-typed pack overlap before asking owner review.
