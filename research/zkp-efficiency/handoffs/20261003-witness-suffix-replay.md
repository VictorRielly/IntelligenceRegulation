# Candidate handoff — lossless bounded in-memory witness replay

Cycle 0016 / 20261003T220146Z-cf20886e. Research-only, unintegrated.
No native proof or measured end-to-end improvement; native owner reviews/promotes.
[Experiment and limits](../experiments/witness-suffix-replay-20261003/README.md),
[result](../experiments/witness-suffix-replay-20261003/result.json).

## Interface and patch location

Inspected source: `ops/zkp-mvp/sonnet-hardening/hashline/src/private_block/`
(six Rust source hashes/snapshots retained). `mvp_driver.rs` lines 758–855:
`StackSource::prepass/restart/advance`, and its `RunWitnessSource` implementation.
Baseline builds L witnesses, drops them, restarts and rebuilds L. Existing
`cached` only bridges `boundary_plane(k)` to `witness(k)`. Preserve that order.

An additive attempt-local `ReplayCache` would own optional suffix entries:
`PackedWitness { attempt_context, model_identity, layer_index, plane_lengths,
private_integrity_pin, planes: Vec<PackedPlane> }`, where `PackedPlane` is an
exact I8/U8/I16/U16/I32/U32/I64 representation or empty. Pack owned deterministic
integer planes during the sealing pass; no proof or endpoint randomness stored.
`take(k)` widens to the exact Witness, checks current input plane and consumes
entry once. Keep final sealing-output check. Same run/input/public calibration
only; no cache reuse across attempts or proof windows. Public worst-case cache
budget, skip/evict/recompute if space is unavailable. No private disk storage.

## Evidence and eliminated work

110 independent struct-byte comparisons; 670 plane comparisons over 13
reduced forward schedules, 20 control categories pass. Final 0.097 s,
18,556 KiB RSS, one Core Ultra 9 185H thread, seed 2026100316. Four cache-budget
schedules fall back without refusing. Exact signed-extrema/fallback, empty
histograms, nonzero padding, order/context/chain/tamper and late refusal tested.
The forward model omits native norm/RoPE/nonlinear tables; no native proof-byte
or RNG parity is established. Mock fresh-state digests are not transcripts.

Removes K second-pass witness BUILDS for K cached layers. Adds private retained
RAM, scan/pack/unpack/checksum/copies and at least 2(B_i64+B_packed) logical
read/write bytes per retained witness. Costs remain recurring per independent
run. Entire first sealing pass, commitments, masks, helpers and proof remain.
No end-to-end estimate without measured avoided witness clocks.

Counted m125 i64/typed payload 678.39/122.36 MiB per layer (12 layers typed
1.43 GiB), independent raw count agrees with retained native probe.
Unregistered Llama-3 geometry: T512/1024/2048 typed 385.18/1106.34/3556.67 MiB
per layer and complete stack 12.04/34.57/111.15 GiB. 1 GiB payload retains
2/0/0 layers of 32; no allocator/proof overlap included. Full replay is not
a small-memory fix. Five norm limbs needed at width4096; current builder
refuses it, owned trained-profile repair remains separate.

## Privacy/refusal and integration gates

- Optional budget exhaustion must recompute, never introduce an input-dependent
  refusal. The retained intermediate budget-refusal design is REJECTED.
- Cache metadata, digests, dtype widths, occupancy, hits and data-dependent
  actual build counts remain private. Current driver publishes build counts;
  retain public logical request totals or public worst-case admission, and
  do not expose new cache-derived metrics for real hidden inputs. Synthetic
  diagnostics can measure them privately for the authorized owner. D20's
  timing/memory exclusion does not authorize publishing derived witness facts.
- Preserve all i64 values, padded strides and exponential padding; histograms
  stay empty until prover derivation. No lossy compression or output-only cache.
- Keep one run transcript, fresh OS endpoint and run randomness; no RNG clone,
  masks, salts, openings or proof transcript in cache. No commitment shared
  across completed proofs. D12a/b, H-1 and publish-after-whole-verification stay.
- Bounded native toy/ragged/admissible and late-refusal plane equality first.
  Then fixed-test-seed native full proof-byte/RNG-continuation equality and
  independent verification/tamper controls. Whole-stack privacy remains open.
- Pin existing `chain_prepass`, `witness_build_recurring`, proof+serialization,
  stage IO and verification clocks, exact RSS/VRAM peaks and pack overlap.
  Pure serialization is not currently isolated. Owner runs only under shared
  resource guard; this handoff does not launch a build/GPU benchmark.

Falsify if native value/refusal/bytes/RNG mismatch, added cache-dependent
leakage, peak overflow, or P+U >= avoided Wc. Workload ceiling is
N/(T-Wc+P+U); Wc and enclosing private-8B T are unknown. Even free full replay
removes at most half of the equal-cost two-pass witness subtotal.

## Next narrow seam

`protocol.rs` lines 798–802 converts every `wit.planes` i64 value into
`a_data: Vec<Fp>`. Last witness reads are exp/activation helper denominators
around 908–910; do not drop the witness early. A typed plane reader feeding
these consumers can avoid reexpansion and reduce active per-layer payload
even when suffix caching is too expensive. Next CPU-light test: exact field
conversion, all indexed lookup/denominator reads and signed/pad/empty controls
against i64 independent reference, plus a live-byte ledger. Not yet tested.
