# Direct-plane host optimization review — 2026-09-19

**Review correction status:** `04894c7` on isolated branch
`integrate/zk60-host-review-20260919`, based on final delivery `06a3df9`,
resolves all three findings below. Five tiling and three cache tests pass
in CPU and GPU-feature binaries; three upload host tests include exact
pre-device refusal under both strategy settings. All source/binary/log pins
rechecked. Actual-device and proof-byte validation on combined main remains
required. The final delivered measurement is 1.405x for the weight commit
at 125M and 2.23 seconds COUNTED at 8B; it supersedes the initial nine-second
estimate discussed below.

Reviewed Claude's code commit `d7cc938d5e149715be81050f69cf955f93ab5273`
(lane tip `df745e1`). This is an integration review of the proposed speed
change, not a merged change or a new timing result. The lane remains with
Claude; findings were sent through the shared coordination file.

The intended improvement is useful: stage the three signed-byte weight
planes directly, removing the expanded host field buffer and its subsequent
packing pass. The row/block mapping agrees with the existing layout. The
host tests compare both the old layout's field image and the actual narrow
packer's byte image, including pieces that cross row/block boundaries.
Device and proof-byte checks are still required on the final source.

## Findings to resolve before integration

1. **The streamed path bypasses the narrow-upload rollback switch.**
   `gpu/cuda.rs:1969` attempts `commit_chunked_upload` before the resident
   `upload_planes` path. The latter checks `narrow_on()`, while the former
   uses `UpSrc::Planes::width() == 1` unconditionally. Consequently
   `HL_GPU_NARROW=0` does not restore the inherited path for a sufficiently
   large or forced-chunked plane commitment. Check the switch before either
   device strategy. Exercise resident and forced-chunked cases, asserting
   which source path ran as well as equality of commitment/proof bytes.

2. **A warm weight-cache hit reads and hashes every plane twice.**
   `wcache.rs:357` computes `WKey::digest` and returns `None` on a hit. The
   layer's fallback constructs a new `WKey` and calls `commit_w`, which
   computes the same digest again. That digest hashes all three planes;
   this is a full extra weight pass. Cache-configured CPU/disabled-device
   paths can also pay the duplicate work because the device decline occurs
   after the first digest. Carry a prepared key through the fallback, or
   decline before hashing when the direct path will not serve that mode.
   Retain cache corruption rejection and compare warm and cold cases
   separately. The claimed nine-second saving remains a cold-path estimate.

3. **Validated tiling invariants are externally mutable and can overflow.**
   `gpu/mod.rs` exposes all `PlaneTiling` fields publicly. Its constructor
   uses unchecked `nb_d * db`, `nb_f * fb` and `d * f`; its length and range
   checks also multiply/add without overflow checks. Wrapped metadata can
   bypass the intended validation in release mode. Keep the geometry
   private, validate lengths/products with checked arithmetic, and use an
   overflow-safe range check. Test zero dimensions, inconsistent counts,
   short planes and `usize` overflow without allocating huge buffers.
   Honest `Layout` geometry is consistent; this review has not demonstrated
   an accepted false proof or an unsafe device access from malformed input.

## Other integration conditions

The private host-pool port is a separate delivery (`a25c544` / `fb850b8`).
Its returned buffers are retired after their last opening readers, and
clearing the non-tiled tail is necessary: private mask/predicate/endpoint
rows have partial writes. Do not replace that helper with the public pool
without preserving the tail rule. Include dirty-buffer shrink/grow and
changed-boundary controls, plus repaired P1/P3 private-IO checks with both
pool/fold switches on and off. Legacy frozen receipts do not exercise the
entire repaired schedule.

The native joint-view and norm-range work remains independent of these
byte-preserving host changes. Model-scale private-block coverage,
whole-proof privacy, proof-size requirements and five-second proving are
still open.
